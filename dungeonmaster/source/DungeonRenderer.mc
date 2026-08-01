// ═══════════════════════════════════════════════════════════════════════════
// DungeonRenderer.mc — The first-person view.
//
// Everything is primitives; there are no bitmaps on Connect IQ and no alpha, so
// depth is faked entirely with pre-shaded colour maths (`shade`). The picture is
// built in four passes:
//
//   1. ceiling  — perspective bands + transverse beams
//   2. floor    — flagstones on the real tile grid, converging grout lines
//   3. walls    — masonry courses with per-brick tint, mortar seams, moss,
//                 cracks, alcoves, banners and iron sconces whose torchlight
//                 pools onto the surrounding columns
//   4. sprites  — depth-tested billboards (monsters, chests, features, stairs)
//
// Wall dressing is *derived from the hit tile coordinates*, not stored: a hash
// of (tileX, tileY, side) decides whether a face carries a torch or moss. That
// costs zero RAM, is stable as you walk around, and rebuilds identically from a
// saved seed.
//
// Every scratch buffer (sprite lists, polygon point arrays, light map) is
// allocated once in initialize() — nothing here allocates per frame.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

const DR_MAX_SPRITE = 20;
const DR_MAX_TORCH  = 6;

class DungeonRenderer {

    hidden var _rc;
    hidden var _vx;
    hidden var _vy;
    hidden var _vw;
    hidden var _vh;
    hidden var _horizon;
    hidden var _cx;

    // Zone palette, refreshed once per floor. `_ramp` is the six-rung light
    // ladder for the current zone (see DmConst.zoneRamp).
    hidden var _ramp;
    hidden var _torchCol;
    hidden var _zone;

    // Sprite gather buffers.
    hidden var _spN;
    hidden var _spRatio;
    hidden var _spDist;
    hidden var _spA;        // glyph-specific payload (monster type / loot kind)
    hidden var _spB;        // secondary payload (elite / rarity)
    hidden var _spGlyph;

    // Per-column extra light contributed by wall sconces.
    hidden var _light;

    // Torches found this frame (column, screen y, distance).
    hidden var _tcN;
    hidden var _tcCol;
    hidden var _tcY;
    hidden var _tcH;
    hidden var _tcD;

    // Reusable polygon point buffers — fillPolygon needs an array and we refuse
    // to allocate one every frame.
    hidden var _p3;
    hidden var _p4;

    // Animation tick, kept as state rather than an argument: the oldest VMs cap
    // a call at nine arguments and the sprite routines are already at the limit.
    hidden var _phase;

    function initialize(rc as Raycaster) {
        _rc = rc;
        _spRatio = new [DR_MAX_SPRITE];
        _spDist = new [DR_MAX_SPRITE];
        _spA = new [DR_MAX_SPRITE];
        _spB = new [DR_MAX_SPRITE];
        _spGlyph = new [DR_MAX_SPRITE];
        _spN = 0;
        _light = new [rc.cols];
        for (var i = 0; i < rc.cols; i++) { _light[i] = 0; }
        _tcCol = new [DR_MAX_TORCH];
        _tcY = new [DR_MAX_TORCH];
        _tcH = new [DR_MAX_TORCH];
        _tcD = new [DR_MAX_TORCH];
        _tcN = 0;
        _p3 = [[0, 0], [0, 0], [0, 0]];
        _p4 = [[0, 0], [0, 0], [0, 0], [0, 0]];
        _phase = 0;
        _ramp = new [6];
        setFloor(1);
        _vx = 0; _vy = 0; _vw = 100; _vh = 100; _horizon = 50; _cx = 50;
    }

    function setPhase(p as Lang.Number) as Void { _phase = p; }

    function setViewport(x as Lang.Number, y as Lang.Number, w as Lang.Number, h as Lang.Number) as Void {
        _vx = x; _vy = y; _vw = w; _vh = h;
        _horizon = y + h / 2;
        _cx = x + w / 2;
    }

    function setFloor(floorNo as Lang.Number) as Void {
        _zone = DmConst.zoneOf(floorNo);
        for (var i = 0; i < 6; i++) { _ramp[i] = DmConst.zoneRamp(floorNo, i); }
        _torchCol = DmConst.torchColor(floorNo);
    }

    // Light factor (roughly 0..118, as produced by the distance/torch maths)
    // to a rung on the zone ramp. `off` separates the surfaces: 0 for walls,
    // -1 for floor and mortar, -2 for the ceiling.
    function tone(f as Lang.Number, off as Lang.Number) as Lang.Number {
        return _at(rung(f) + off);
    }

    function rung(f as Lang.Number) as Lang.Number {
        if (f >= 100) { return 5; }
        if (f >= 80)  { return 4; }
        if (f >= 60)  { return 3; }
        if (f >= 40)  { return 2; }
        if (f >= 20)  { return 1; }
        return 0;
    }

    function _at(i as Lang.Number) as Lang.Number {
        if (i < 0) { i = 0; }
        if (i > 5) { i = 5; }
        return _ramp[i];
    }

    // Shade a prop colour by light factor f: 100 leaves it as authored, less
    // sinks it toward black, more pushes it toward the torch's white core.
    // Props keep continuous shading rather than the wall ramp because a sprite
    // moving toward you should brighten smoothly, and its silhouette already
    // separates it from the masonry behind.
    function shade(col as Lang.Number, f as Lang.Number) as Lang.Number {
        if (f < 0) { f = 0; }
        if (f > 150) { f = 150; }
        var r = (((col >> 16) & 0xFF) * f) / 100;
        var g = (((col >> 8) & 0xFF) * f) / 100;
        var b = ((col & 0xFF) * f) / 100;
        if (r > 255) { r = 255; }
        if (g > 255) { g = 255; }
        if (b > 255) { b = 255; }
        return (r << 16) | (g << 8) | b;
    }

    // Cheap positional hash — the whole dungeon dressing hangs off this.
    function hash(a as Lang.Number, b as Lang.Number, c as Lang.Number) as Lang.Number {
        var h = a * 3251 + b * 6151 + c * 97 + 12347;
        if (h < 0) { h = -h; }
        return h % 65536;
    }

    // hideMon: monster index the caller draws itself (the combat portrait), or -1.
    function render(dc, map as DungeonMap, cam as Camera, torch as Lang.Number,
                    hideMon as Lang.Number) as Void {
        _scanTorches(torch);
        _drawCeiling(dc);
        _drawFloor(dc);
        _drawWalls(dc, torch);
        _drawSconces(dc, torch);
        _gatherSprites(map, cam, hideMon);
        _drawSprites(dc, map, torch);
    }

    // ── Ceiling ─────────────────────────────────────────────────────────────
    // Bands between real tile boundaries, with a beam laid across each seam.
    hidden function _drawCeiling(dc) as Void {
        var half = _vh / 2;
        // Base fill covers the sliver nearest the horizon, which is effectively
        // out of torch range.
        dc.setColor(tone(0, -2), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_vx, _vy, _vw, half + 1);

        // A ceiling one half-unit above the eye, seen at distance d, projects to
        // vh/(2d) above the horizon — so the tile seam at d = 1 lands exactly on
        // the top of the screen and the rest march down toward it. Bands are
        // therefore drawn from overhead backwards, getting darker as they go.
        var prev = _vy;
        for (var d = 2; d < 8; d++) {
            var y = _horizon - _vh / (d * 2);
            if (y < _vy) { y = _vy; }
            var band = y - prev;
            if (band > 0) {
                var f = 100 - (d - 1) * 18;
                dc.setColor(tone(f, -2), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_vx, prev, _vw, band);
                // Timber beam laid across the seam, a rung darker than the vault.
                var bh = 5 - d / 2;
                if (bh < 1) { bh = 1; }
                dc.setColor(tone(f, -3), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_vx, y - bh, _vw, bh);
            }
            prev = y;
        }
    }

    // ── Floor ───────────────────────────────────────────────────────────────
    // Flagstones receding to the horizon: bands snap to the real tile grid, and
    // six converging grout lines sell the perspective for six drawLine calls.
    hidden function _drawFloor(dc) as Void {
        var half = _vh - _vh / 2;
        var bottom = _vy + _vh;
        dc.setColor(tone(0, -1), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_vx, _horizon, _vw, half);

        // Mirror of the ceiling: the seam at distance d sits vh/(2d) below the
        // horizon, so d = 1 is the bottom edge of the screen and the flagstones
        // bunch up as they recede.
        var prev = bottom;
        for (var d = 2; d < 8; d++) {
            var y = _horizon + _vh / (d * 2);
            var band = prev - y;
            if (band > 0) {
                var f = 116 - (d - 1) * 16;
                dc.setColor(tone(f, -2), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_vx, y, _vw, band);
                // Grout seam along the tile boundary.
                dc.setColor(tone(f, -3), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_vx, y, _vw, 1);
            }
            prev = y;
        }

        // Converging longitudinal seams at ±0.5 / ±1.5 / ±2.5 tiles. A lateral
        // offset u at distance d projects to cx + u*0.758*vw/d. Each seam is
        // clipped at whichever comes first walking toward the camera: the bottom
        // of the screen (d = 1) or the side of the screen — otherwise the near
        // end flies off into the bezel and the seams splay into a painted "V".
        // Distances are carried in hundredths to stay in integer maths.
        var yFar = _horizon + _vh / 12;               // d = 6
        dc.setColor(tone(100, -3), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 6; i++) {
            var u5 = (i - 3) * 10 + 5;                // -25,-15,-5,5,15,25 tenths
            var au = (u5 < 0) ? -u5 : u5;
            var nearD = au * 15;                      // d where |x-cx| = vw/2
            if (nearD < 100) { nearD = 100; }
            if (nearD >= 600) { continue; }
            var yNear = _horizon + (_vh * 50) / nearD;
            if (yNear > bottom) { yNear = bottom; }
            var xN = _cx + (u5 * 758 * _vw) / (100 * nearD);
            var xF = _cx + (u5 * 758 * _vw) / 60000;
            dc.drawLine(xF, yFar, xN, yNear);
        }
    }

    // ── Wall sconces ────────────────────────────────────────────────────────
    // Walk the columns, group them into runs that hit the same wall face, and
    // decide per face whether it carries a torch. Torch columns then seed the
    // per-column light map so the masonry actually brightens around the flame.
    hidden function _scanTorches(torch as Lang.Number) as Void {
        var cols = _rc.cols;
        for (var i = 0; i < cols; i++) { _light[i] = 0; }
        _tcN = 0;

        var runStart = 0;
        var c = 0;
        while (c <= cols) {
            var boundary = (c == cols);
            if (!boundary && c > runStart) {
                if (_rc.hitX[c] != _rc.hitX[runStart] || _rc.hitY[c] != _rc.hitY[runStart] ||
                    _rc.side[c] != _rc.side[runStart]) {
                    boundary = true;
                }
            }
            if (boundary) {
                _faceDecor(runStart, c - 1, torch);
                runStart = c;
            }
            c++;
        }
    }

    hidden function _faceDecor(a as Lang.Number, b as Lang.Number, torch as Lang.Number) as Void {
        if (b < a) { return; }
        var k = _rc.kind[a];
        if (k != T_WALL && k != T_SECRET && k != T_PILLAR) { return; }
        var d = _rc.dist[a];
        if (d >= 7.0) { return; }
        var h = hash(_rc.hitX[a], _rc.hitY[a], _rc.side[a]);
        if (h % 9 != 0) { return; }
        if (_tcN >= DR_MAX_TORCH) { return; }

        // Put the sconce on the column whose hit offset sits nearest the middle
        // of the face, so it stays glued to the wall as you sidle past.
        var best = a;
        var bestErr = 1000;
        for (var c = a; c <= b; c++) {
            var e = ((_rc.wallX[c] * 100).toNumber() - 50);
            if (e < 0) { e = -e; }
            if (e < bestErr) { bestErr = e; best = c; }
        }
        var lineH = (_vh / _rc.dist[best]).toNumber();
        if (lineH < 14) { return; }

        var i = _tcN;
        _tcCol[i] = best;
        _tcH[i] = lineH;
        _tcY[i] = _horizon - lineH / 6;
        _tcD[i] = _rc.dist[best];
        _tcN++;

        // Light pool: strongest at the flame, fading over ~10 columns, and
        // dimmer the further the torch is from the eye.
        var reach = 12 - (_rc.dist[best] * 1.2).toNumber();
        if (reach < 4) { reach = 4; }
        var peak = 34 - (_rc.dist[best] * 4).toNumber() + torch;
        if (peak < 6) { peak = 6; }
        var lo = best - reach;
        var hi = best + reach;
        if (lo < 0) { lo = 0; }
        if (hi >= _rc.cols) { hi = _rc.cols - 1; }
        for (var c2 = lo; c2 <= hi; c2++) {
            var dist = c2 - best;
            if (dist < 0) { dist = -dist; }
            var add = peak * (reach - dist) / reach;
            if (add > _light[c2]) { _light[c2] = add; }
        }
    }

    // ── Walls ───────────────────────────────────────────────────────────────
    hidden function _drawWalls(dc, torch as Lang.Number) as Void {
        var cols = _rc.cols;
        var colW = _rc.colW;
        var bottom = _vy + _vh;

        // Vertical mortar joints are drawn on the single column where the brick
        // index changes, rather than "whenever the offset is small" — otherwise
        // a joint lands on two neighbouring columns and reads as a double line.
        var lastEven = -999;
        var lastOdd = -999;
        var lastFace = -999;

        for (var c = 0; c < cols; c++) {
            var d = _rc.dist[c];
            if (d >= 90.0) { continue; }

            var lineH = (_vh / d).toNumber();
            if (lineH > _vh * 3) { lineH = _vh * 3; }
            var topU = _horizon - lineH / 2;      // unclipped, drives texture rows
            var top = topU;
            var bot = _horizon + lineH / 2;
            if (top < _vy) { top = _vy; }
            if (bot > bottom) { bot = bottom; }
            var h = bot - top;
            if (h <= 0) { continue; }

            var k = _rc.kind[c];
            var hx = _rc.hitX[c];
            var hy = _rc.hitY[c];
            var wx = _rc.wallX[c];
            var x = _vx + c * colW;

            // Distance falloff plus whatever the sconces are pouring onto this
            // column. The near-field lift is deliberately *not* the flickering
            // torch value: on a four-level panel a flicker would swing the whole
            // wall a full ramp rung every tick, which strobes. The flame itself
            // flickers instead.
            var f = 84 - (d * 11).toNumber() + _light[c];
            if (_rc.side[c] == 1) { f -= 12; }
            if (d < 1.4) { f += 8; }
            if (f < 0) { f = 0; }

            if (k == T_DOOR || k == T_LOCKED) {
                _drawDoorColumn(dc, x, top, h, lineH, wx, f, k == T_LOCKED);
                continue;
            }

            // Pillars are dressed stone: one rung brighter than the walls they
            // stand against, which is what makes them pop out of a room.
            var ri = rung(f);
            if (k == T_PILLAR) { ri++; }
            if (ri > 5) { ri = 5; }
            // Detail is drawn one rung down, but never all the way to black:
            // a mortar line or a soot-stained stone that bottoms out reads as a
            // hole punched in the wall rather than as texture.
            var lo = (ri >= 2) ? ri - 1 : ri;

            dc.setColor(_at(ri), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, top, colW, h);

            if (d > 6.5 || lineH < 14 || ri < 2) { continue; }

            // Masonry courses. Brick columns are offset every other row, so the
            // vertical seams stagger exactly like real coursed stone.
            var rows = 5;
            if (lineH < 90) { rows = 4; }
            if (lineH < 46) { rows = 3; }
            var rowH = lineH / rows;
            if (rowH < 4) { continue; }

            // Three bricks across each tile face, the odd courses shifted half
            // a brick. `bi` is the brick index; a vertical joint is drawn on the
            // one column where that index changes.
            var wxi = (wx * 300).toNumber();
            var face = hx * 64 + hy * 2 + _rc.side[c];
            var biEven = wxi / 100;
            var biOdd = (wxi + 50) / 100;
            var newFace = (face != lastFace);
            var seamEven = newFace || (biEven != lastEven);
            var seamOdd = newFace || (biOdd != lastOdd);
            lastFace = face;
            lastEven = biEven;
            lastOdd = biOdd;

            for (var r = 0; r < rows; r++) {
                var ry = topU + r * rowH;
                var rh = rowH;
                if (ry < top) { rh -= (top - ry); ry = top; }
                if (ry + rh > bot) { rh = bot - ry; }
                if (rh <= 0) { continue; }

                var odd = (r % 2) == 1;
                var bi = odd ? biOdd : biEven;
                var bh2 = hash(hx * 8 + bi, hy * 8 + r, _rc.side[c]);

                // About one stone in nine is set a rung darker, but only on a
                // face that is lit well enough for the difference to read as
                // stone rather than as a hole.
                if (ri >= 3 && (bh2 % 9) == 0) {
                    dc.setColor(_at(ri - 1), Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, ry, colW, rh);
                }

                // Vertical mortar joint at the brick edge.
                if (odd ? seamOdd : seamEven) {
                    dc.setColor(_at(lo), Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, ry, 1, rh);
                }

                // Moss creeps up from the floor.
                if (ri >= 3 && r >= rows - 2 && (bh2 % 29) == 3) {
                    var moss = 0x4A7A3A;
                    if (_zone == 2) { moss = 0x3E7A82; }
                    if (_zone == 4) { moss = 0x8A4A1E; }
                    dc.setColor(shade(moss, f + 20), Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, ry + rh / 2, colW, rh - rh / 2);
                }
                // Horizontal mortar course.
                if (r > 0) {
                    dc.setColor(_at(lo), Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, ry, colW, 1);
                }
            }

            // Alcove: a shallow recess with a skull sitting in it.
            var ah = hash(hx, hy, _rc.side[c] + 7);
            if ((ah % 19) == 4 && lineH > 46 && wx > 0.33 && wx < 0.67) {
                var aw = lineH / 5;
                var ay = _horizon - lineH / 8;
                dc.setColor(_at(ri - 3), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, ay, colW, aw);
                if (wx > 0.44 && wx < 0.56) {
                    dc.setColor(_at(ri + 2), Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(x + colW / 2, ay + aw / 2, aw / 5 + 1);
                }
            }

            // Hanging banner.
            var bnh = hash(hx, hy, _rc.side[c] + 13);
            if ((bnh % 21) == 6 && lineH > 40 && wx > 0.28 && wx < 0.72) {
                var by = topU + lineH / 8;
                var bl = lineH / 2;
                if (by < top) { bl -= (top - by); by = top; }
                if (bl > 2) {
                    dc.setColor(shade(_bannerColor(), f + 24), Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, by, colW, bl);
                    if (wx > 0.46 && wx < 0.54) {
                        dc.setColor(_at(ri + 2), Graphics.COLOR_TRANSPARENT);
                        dc.fillRectangle(x, by + bl / 3, colW, 2);
                    }
                }
            }
        }
    }

    hidden function _bannerColor() as Lang.Number {
        if (_zone == 0) { return 0x8A1F26; }
        if (_zone == 1) { return 0x1F5A32; }
        if (_zone == 2) { return 0x1F4A7A; }
        if (_zone == 3) { return 0x4A2A7A; }
        return 0x8A1F4A;
    }

    // Timber planks, two iron bands, a ring handle — and for a locked door a
    // riveted lock plate with a keyhole, so "locked" reads before the prompt.
    hidden function _drawDoorColumn(dc, x, top, h, lineH, wx, f, locked) as Void {
        var colW = _rc.colW;
        var topU = _horizon - lineH / 2;
        var wood = locked ? 0x5A4630 : 0x7A5228;
        var plank = ((wx * 100).toNumber() / 14) % 2;
        var wcol = shade(wood, (plank == 0) ? f : f - 26);
        dc.setColor(wcol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, top, colW, h);

        // Plank seams.
        if (((wx * 100).toNumber() % 14) < 3) {
            dc.setColor(shade(wood, f - 52), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, top, 1, h);
        }
        if (lineH < 14) { return; }

        // Iron bands across a third and two thirds of the leaf.
        var iron = locked ? 0x9AA2AA : 0x5A6068;
        var b1 = topU + lineH / 4;
        var b2 = topU + (lineH * 3) / 4;
        var bt = lineH / 12;
        if (bt < 2) { bt = 2; }
        dc.setColor(shade(iron, f), Graphics.COLOR_TRANSPARENT);
        if (b1 > top && b1 + bt < top + h) { dc.fillRectangle(x, b1, colW, bt); }
        if (b2 > top && b2 + bt < top + h) { dc.fillRectangle(x, b2, colW, bt); }
        // Rivets on the bands.
        if (((wx * 100).toNumber() % 20) < 4) {
            dc.setColor(shade(0xFFFFFF, f), Graphics.COLOR_TRANSPARENT);
            if (b1 > top) { dc.fillRectangle(x + 1, b1 + 1, 2, 2); }
            if (b2 > top) { dc.fillRectangle(x + 1, b2 + 1, 2, 2); }
        }

        // Handle ring / lock plate near the leading edge.
        if (lineH > 34) {
            if (wx > 0.68 && wx < 0.78) {
                dc.setColor(shade(0xFFAA55, f), Graphics.COLOR_TRANSPARENT);
                var hy2 = _horizon + lineH / 20;
                dc.fillCircle(x + colW / 2, hy2, lineH / 22 + 2);
                dc.setColor(wcol, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x + colW / 2, hy2, lineH / 34 + 1);
            }
            if (locked && wx > 0.44 && wx < 0.58) {
                var ly = _horizon;
                var lw = lineH / 8;
                if (lw < 5) { lw = 5; }
                dc.setColor(shade(0xAAAAAA, f), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, ly - lw / 2, colW, lw);
                if (wx > 0.48 && wx < 0.53) {
                    dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(x + colW / 2, ly - 1, lw / 5 + 1);
                    dc.fillRectangle(x + colW / 2 - 1, ly - 1, 2, lw / 3);
                }
            }
        }
    }

    // Iron bracket + a flame that flickers with the torch phase.
    hidden function _drawSconces(dc, torch as Lang.Number) as Void {
        for (var i = 0; i < _tcN; i++) {
            var x = _vx + _tcCol[i] * _rc.colW + _rc.colW / 2;
            var y = _tcY[i];
            var s = _tcH[i] / 9;
            if (s < 3) { s = 3; }
            if (s > 22) { s = 22; }
            var f = 100 - (_tcD[i] * 8).toNumber();
            if (f < 30) { f = 30; }

            // Bracket.
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 1, y, 3, s);
            dc.fillRectangle(x - s / 3, y + s - 2, (s * 2) / 3, 2);

            // Flame: outer body, inner core, and a spark that drifts up. Only
            // the flame flickers — the wall it lights stays put, which reads as
            // fire rather than as the whole scene strobing.
            var fl = s + (torch % 3);
            dc.setColor(shade(_torchCol, f), Graphics.COLOR_TRANSPARENT);
            _tri(dc, x, y - fl, x - s / 3 - 1, y + 1, x + s / 3 + 1, y + 1);
            dc.setColor(shade(0xFFFFFF, f), Graphics.COLOR_TRANSPARENT);
            _tri(dc, x, y - fl / 2, x - s / 6, y, x + s / 6, y);
            if (s > 6) {
                dc.setColor(shade(_torchCol, f - 30), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x + ((torch % 3) - 1), y - fl - 3, 1);
            }
        }
    }

    hidden function _tri(dc, x1, y1, x2, y2, x3, y3) as Void {
        _p3[0][0] = x1; _p3[0][1] = y1;
        _p3[1][0] = x2; _p3[1][1] = y2;
        _p3[2][0] = x3; _p3[2][1] = y3;
        dc.fillPolygon(_p3);
    }

    // Symmetric trapezoid — torsos, robes, banners and stalls are all this shape.
    hidden function _trap(dc, cx, topY, topHW, botY, botHW) as Void {
        _p4[0][0] = cx - topHW; _p4[0][1] = topY;
        _p4[1][0] = cx + topHW; _p4[1][1] = topY;
        _p4[2][0] = cx + botHW; _p4[2][1] = botY;
        _p4[3][0] = cx - botHW; _p4[3][1] = botY;
        dc.fillPolygon(_p4);
    }

    hidden function _diamond(dc, cx, cy, rx, ry) as Void {
        _p4[0][0] = cx;      _p4[0][1] = cy - ry;
        _p4[1][0] = cx + rx; _p4[1][1] = cy;
        _p4[2][0] = cx;      _p4[2][1] = cy + ry;
        _p4[3][0] = cx - rx; _p4[3][1] = cy;
        dc.fillPolygon(_p4);
    }

    // ── Sprites ─────────────────────────────────────────────────────────────
    // Glyphs: 0 monster, 1 chest, 2 stairs, 3 feature.
    hidden function _gatherSprites(map as DungeonMap, cam as Camera,
                                   hideMon as Lang.Number) as Void {
        _spN = 0;
        // Stairs first: they are the one sprite that must never be crowded out
        // of the pool by a room full of monsters.
        _push(cam, map.stairX, map.stairY, 0, 0, 2);
        for (var i = 0; i < map.monN && _spN < DR_MAX_SPRITE; i++) {
            if (!map.monAlive[i] || i == hideMon) { continue; }
            _push(cam, map.monX[i], map.monY[i], map.monType[i], map.monElite[i], 0);
        }
        for (var i = 0; i < map.lootN && _spN < DR_MAX_SPRITE; i++) {
            if (map.lootTaken[i] != 0) { continue; }
            _push(cam, map.lootX[i], map.lootY[i], map.lootKind[i], map.lootVal[i], 1);
        }
        for (var i = 0; i < map.featN && _spN < DR_MAX_SPRITE; i++) {
            _push(cam, map.featX[i], map.featY[i], map.featKind[i], map.featUsed[i], 3);
        }

        // Far-to-near ordering so nearer sprites overdraw.
        for (var i = 1; i < _spN; i++) {
            var j = i;
            while (j > 0 && _spDist[j - 1] < _spDist[j]) {
                var a = _spDist[j]; _spDist[j] = _spDist[j - 1]; _spDist[j - 1] = a;
                var b = _spRatio[j]; _spRatio[j] = _spRatio[j - 1]; _spRatio[j - 1] = b;
                var c2 = _spA[j]; _spA[j] = _spA[j - 1]; _spA[j - 1] = c2;
                var c3 = _spB[j]; _spB[j] = _spB[j - 1]; _spB[j - 1] = c3;
                var g = _spGlyph[j]; _spGlyph[j] = _spGlyph[j - 1]; _spGlyph[j - 1] = g;
                j--;
            }
        }
    }

    hidden function _push(cam as Camera, x as Lang.Number, y as Lang.Number,
                          a as Lang.Number, b as Lang.Number, glyph as Lang.Number) as Void {
        if (_spN >= DR_MAX_SPRITE) { return; }
        if (!_rc.project(cam, x, y)) { return; }
        if (_rc.projDist > 8.5) { return; }
        _spRatio[_spN] = _rc.projRatio;
        _spDist[_spN] = _rc.projDist;
        _spA[_spN] = a;
        _spB[_spN] = b;
        _spGlyph[_spN] = glyph;
        _spN++;
    }

    hidden function _drawSprites(dc, map as DungeonMap, torch as Lang.Number) as Void {
        for (var i = 0; i < _spN; i++) {
            var d = _spDist[i];
            var sx = _cx + (_spRatio[i] * _vw / 2).toNumber();
            var col = (sx - _vx) / _rc.colW;
            if (col < 0) { col = 0; }
            if (col >= _rc.cols) { col = _rc.cols - 1; }
            if (_rc.dist[col] < d) { continue; }     // hidden behind masonry

            var size = (_vh / d).toNumber();
            if (size < 5) { continue; }
            if (size > _vh) { size = _vh; }
            var f = 104 - (d * 13).toNumber() + _light[col] / 2;
            if (f < 22) { f = 22; }
            if (f > 110) { f = 110; }
            var baseY = _horizon + size / 2;
            var g = _spGlyph[i];

            if (g == 0) {
                drawMonsterArt(dc, _spA[i], _spB[i], sx, baseY, size, f, 0);
            } else if (g == 1) {
                drawChest(dc, sx, baseY, size, _spA[i], _spB[i], f);
            } else if (g == 3) {
                drawFeature(dc, sx, baseY, size, _spA[i], _spB[i], f);
            } else {
                drawStairwell(dc, sx, baseY, size, f);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Monster art. Shared by the corridor billboards and the combat portrait,
    // so a skeleton looks like the same creature at 20px and at 120px.
    //   size  = full sprite height in px
    //   baseY = ground line (feet)
    //   f     = light factor, lunge = attack offset in px (animation phase is
    //           class state — see setPhase)
    // ═══════════════════════════════════════════════════════════════════════
    function drawMonsterArt(dc, type as Lang.Number, elite as Lang.Number,
                            sx as Lang.Number, baseY as Lang.Number, size as Lang.Number,
                            f as Lang.Number, lunge as Lang.Number) as Void {
        if (size < 5) { return; }
        // Idle bob: a triangle wave so nothing needs trig.
        var phase = _phase;
        var p = phase % 8;
        var bob = (p < 4) ? p : (8 - p);
        bob = (bob - 2) * size / 90;
        var y = baseY + bob - lunge / 3;
        var x = sx + lunge;

        var body = shade(DmConst.monColor(type), f);
        if (elite != EL_NONE) {
            // Elites get an aura ring behind them — you should see it coming.
            var ac = shade(DmConst.eliteColor(elite), f * 7 / 10);
            dc.setColor(ac, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - size / 2, size / 2 + 2);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - size / 2, size / 2 - 1);
        }

        if (type == MON_RAT)           { _artRat(dc, x, y, size, body, f, phase); }
        else if (type == MON_GOBLIN)   { _artGoblin(dc, x, y, size, body, f); }
        else if (type == MON_SKELETON) { _artSkeleton(dc, x, y, size, body, f, false); }
        else if (type == MON_SPIDER)   { _artSpider(dc, x, y, size, body, f, phase); }
        else if (type == MON_CULTIST)  { _artCultist(dc, x, y, size, body, f); }
        else if (type == MON_KNIGHT)   { _artKnight(dc, x, y, size, body, f, false); }
        else if (type == MON_WRAITH)   { _artWraith(dc, x, y, size, body, f, phase); }
        else if (type == MON_OGRE)     { _artOgre(dc, x, y, size, body, f); }
        else if (type == MON_DEMON)    { _artDemon(dc, x, y, size, body, f, phase); }
        else if (type == MON_KING)     { _artSkeleton(dc, x, y, size, body, f, true); }
        else if (type == MON_GUARDIAN) { _artKnight(dc, x, y, size, body, f, true); }
        else                           { _artBeast(dc, x, y, size, body, f, phase); }
    }

    // Three scurrying bodies with tails and pinpoint eyes.
    hidden function _artRat(dc, x, y, s, col, f, phase) as Void {
        var r = s / 7;
        if (r < 2) { r = 2; }
        var wob = (phase % 4) - 1;
        for (var i = 0; i < 3; i++) {
            var ox = (i - 1) * (s / 4) + (i == 1 ? 0 : wob);
            var oy = (i == 1) ? -r : 0;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + ox, y - r + oy, r);
            dc.fillCircle(x + ox + r, y - r + oy, r * 2 / 3);
            dc.setColor(shade(0x6A5A48, f), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x + ox - r, y - r + oy, x + ox - r * 2, y + oy);
            if (s > 22) {
                dc.setColor(shade(0xFF4433, f), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + ox + r, y - r - 1 + oy, 2, 2);
            }
        }
    }

    // Pointed ears, a heavy club and a hunched stance.
    hidden function _artGoblin(dc, x, y, s, col, f) as Void {
        var bw = s / 3;
        if (bw < 4) { bw = 4; }
        var bh = s / 2;
        var by = y - bh;
        var hr = bw / 2 + 1;

        dc.setColor(shade(0x3A2A18, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - bw / 3, y - s / 7, bw / 4 + 1, s / 7);
        dc.fillRectangle(x + bw / 6, y - s / 7, bw / 4 + 1, s / 7);

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - bw / 2, by, bw, bh);
        dc.fillCircle(x, by - hr, hr);
        // Ears
        _tri(dc, x - hr, by - hr, x - hr * 2, by - hr * 2, x - hr + 1, by - hr - hr / 2);
        _tri(dc, x + hr, by - hr, x + hr * 2, by - hr * 2, x + hr - 1, by - hr - hr / 2);
        // Loincloth
        dc.setColor(shade(0x6A4A2A, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - bw / 2, y - bh / 3, bw, bh / 4 + 1);
        // Club
        dc.setColor(shade(0x7A5A32, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + bw / 2, by - s / 8, 2, bh / 2);
        dc.fillCircle(x + bw / 2 + 1, by - s / 7, bw / 4 + 1);
        if (s > 24) {
            dc.setColor(shade(0xFFDD44, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - hr / 2 - 1, by - hr - 1, 2, 2);
            dc.fillRectangle(x + hr / 2 - 1, by - hr - 1, 2, 2);
        }
    }

    // Skull with sockets and jaw, ribcage on a spine, bone limbs. `king` adds
    // the crown and cape of the floor-5 boss.
    hidden function _artSkeleton(dc, x, y, s, col, f, king) as Void {
        var hr = s / 8;
        if (hr < 3) { hr = 3; }
        var chestTop = y - s + hr * 2;
        var chestH = s / 3;

        if (king) {
            dc.setColor(shade(0x6A1024, f), Graphics.COLOR_TRANSPARENT);
            _trap(dc, x, chestTop, hr, y - 1, hr * 3);
        }

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        // Legs
        dc.fillRectangle(x - hr, y - s / 3, 2, s / 3);
        dc.fillRectangle(x + hr - 2, y - s / 3, 2, s / 3);
        // Spine
        dc.fillRectangle(x - 1, chestTop, 2, chestH + s / 8);
        // Ribs
        var ribs = 4;
        if (s < 40) { ribs = 3; }
        for (var i = 0; i < ribs; i++) {
            var ry = chestTop + i * chestH / ribs + 1;
            var rw = hr * 2 - i / 2;
            dc.fillRectangle(x - rw, ry, rw * 2, 1 + s / 90);
        }
        // Arms
        dc.fillRectangle(x - hr * 2, chestTop + 1, 2, chestH);
        dc.fillRectangle(x + hr * 2 - 2, chestTop + 1, 2, chestH);
        // Skull
        dc.fillCircle(x, y - s + hr, hr);
        dc.fillRectangle(x - hr / 2, y - s + hr + hr / 2, hr, hr / 2 + 1);
        if (s > 20) {
            dc.setColor(shade(0x120E0A, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - hr / 2 - 1, y - s + hr - 1, hr / 2 + 1, hr / 2 + 1);
            dc.fillRectangle(x + 1, y - s + hr - 1, hr / 2 + 1, hr / 2 + 1);
            dc.setColor(shade(king ? 0xFF5522 : 0xCC3311, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - hr / 2, y - s + hr, 2, 2);
            dc.fillRectangle(x + 1, y - s + hr, 2, 2);
        }
        // Rusted blade
        dc.setColor(shade(0x9AA0A6, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + hr * 2, chestTop - s / 8, 2, chestH + s / 6);
        dc.fillRectangle(x + hr * 2 - 2, chestTop + chestH / 3, 6, 2);

        if (king) {
            dc.setColor(shade(0xFFCC33, f), Graphics.COLOR_TRANSPARENT);
            var cy = y - s + hr - hr;
            dc.fillRectangle(x - hr, cy, hr * 2, 2);
            _tri(dc, x - hr, cy, x - hr / 2, cy - hr, x, cy);
            _tri(dc, x, cy, x + hr / 2, cy - hr, x + hr, cy);
        }
    }

    // Bulbous abdomen, eight jointed legs, fangs and a cluster of eyes.
    hidden function _artSpider(dc, x, y, s, col, f, phase) as Void {
        var r = s / 5;
        if (r < 3) { r = 3; }
        var cy = y - r - s / 6;
        var swing = ((phase % 4) < 2) ? 1 : -1;

        dc.setColor(shade(0x1A1018, f), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var ly = cy - r / 2 + i * r / 3;
            var reach = r + r / 2 + (i % 2) * (r / 2);
            var knee = ly - r / 2 - (i % 2) * 2;
            dc.drawLine(x - r / 2, ly, x - reach, knee);
            dc.drawLine(x - reach, knee, x - reach - r / 3, ly + r / 2 + swing);
            dc.drawLine(x + r / 2, ly, x + reach, knee);
            dc.drawLine(x + reach, knee, x + reach + r / 3, ly + r / 2 - swing);
        }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, cy + r / 3, r);                 // abdomen
        dc.fillCircle(x, cy - r / 2, r * 2 / 3);         // cephalothorax
        if (s > 18) {
            dc.setColor(shade(0x2A1030, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - r, cy + r / 4, r * 2, 1);
            dc.setColor(shade(0xFFEE44, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - r / 2 - 1, cy - r / 2 - 1, 2, 2);
            dc.fillRectangle(x + r / 2 - 1, cy - r / 2 - 1, 2, 2);
            dc.fillRectangle(x - 2, cy - r, 2, 2);
            dc.fillRectangle(x + 1, cy - r, 2, 2);
            dc.setColor(shade(0xF0F0E0, f), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x - r / 3, cy - r / 4, x - r / 4, cy + 1);
            dc.drawLine(x + r / 3, cy - r / 4, x + r / 4, cy + 1);
        }
    }

    // Hooded robe, empty face, a rune burning between raised hands.
    hidden function _artCultist(dc, x, y, s, col, f) as Void {
        var w = s / 3;
        if (w < 4) { w = 4; }
        var top = y - s;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        _trap(dc, x, top + s / 5, w / 2, y, w);
        dc.fillCircle(x, top + s / 5, w / 2 + 1);
        // Hood shadow
        dc.setColor(shade(0x0A0608, f), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, top + s / 5 + 1, w / 3 + 1);
        if (s > 20) {
            dc.setColor(shade(0xFF4466, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - w / 4, top + s / 5, 2, 2);
            dc.fillRectangle(x + w / 4 - 2, top + s / 5, 2, 2);
        }
        // Sleeves + rune
        dc.setColor(shade(0x6A2038, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - w, top + s / 3, w / 2, 2);
        dc.fillRectangle(x + w / 2, top + s / 3, w / 2, 2);
        if (s > 24) {
            dc.setColor(shade(0xCC66FF, f), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, top + s / 3 - w / 3, w / 5 + 1);
            dc.setColor(shade(0xFFFFFF, f), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, top + s / 3 - w / 3, w / 9 + 1);
        }
    }

    // Great helm with a plume, pauldrons, a kite shield and a long blade.
    // `stone` turns him into the Ancient Guardian: cracked rock with a rune core.
    hidden function _artKnight(dc, x, y, s, col, f, stone) as Void {
        var w = s / 3;
        if (w < 5) { w = 5; }
        var top = y - s;
        var helmR = w / 2 + 1;

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        // Legs / greaves
        dc.fillRectangle(x - w / 2, y - s / 3, w / 3, s / 3);
        dc.fillRectangle(x + w / 6, y - s / 3, w / 3, s / 3);
        // Cuirass
        _trap(dc, x, top + s / 4, w / 2, y - s / 3, w / 3);
        // Pauldrons
        dc.fillCircle(x - w / 2, top + s / 4 + 1, w / 4 + 1);
        dc.fillCircle(x + w / 2, top + s / 4 + 1, w / 4 + 1);
        // Helm
        dc.fillCircle(x, top + helmR + 1, helmR);
        dc.fillRectangle(x - helmR, top + helmR, helmR * 2, helmR);

        if (stone) {
            dc.setColor(shade(0x2A3440, f), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x - w / 3, top + s / 3, x + w / 6, top + s / 2);
            dc.drawLine(x + w / 4, top + s / 3, x, top + s / 2 + 2);
            dc.setColor(shade(0x66DDFF, f), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, top + s / 3 + 2, w / 6 + 1);
        } else {
            // Plume
            dc.setColor(shade(0xCC2233, f), Graphics.COLOR_TRANSPARENT);
            _tri(dc, x, top - helmR / 2, x - helmR / 2, top + helmR, x + helmR / 2, top + helmR);
        }
        // Visor slit
        dc.setColor(shade(0x0A0C10, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - helmR + 1, top + helmR + helmR / 3, helmR * 2 - 2, 2);
        if (s > 22) {
            dc.setColor(shade(stone ? 0x66DDFF : 0xFF6622, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - helmR / 2, top + helmR + helmR / 3, 2, 2);
            dc.fillRectangle(x + helmR / 2 - 2, top + helmR + helmR / 3, 2, 2);
        }
        // Shield
        dc.setColor(shade(stone ? 0x556677 : 0x44506A, f), Graphics.COLOR_TRANSPARENT);
        var shW = w * 2 / 3;
        var shY = top + s / 3;
        dc.fillRectangle(x - w - shW / 2, shY, shW, s / 4);
        _tri(dc, x - w - shW / 2, shY + s / 4, x - w + shW / 2, shY + s / 4, x - w, shY + s / 3);
        dc.setColor(shade(0xC8B060, f), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - w, shY + s / 8, shW / 5 + 1);
        // Blade
        dc.setColor(shade(0xC0C8D0, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + w, top + s / 5, 2, s / 2);
        dc.fillRectangle(x + w - 2, top + s / 3, 6, 2);
    }

    // No legs: a tattered floating shroud with two cold eyes and wisp arms.
    hidden function _artWraith(dc, x, y, s, col, f, phase) as Void {
        var w = s / 3;
        if (w < 4) { w = 4; }
        var drift = ((phase % 6) < 3) ? 1 : -1;
        var top = y - s + s / 8;
        var hem = y - s / 8;

        dc.setColor(shade(col, f * 6 / 10), Graphics.COLOR_TRANSPARENT);
        _trap(dc, x, top, w / 2, hem, w);
        // Ragged hem
        for (var i = 0; i < 4; i++) {
            var hx2 = x - w + i * (w / 2);
            _tri(dc, hx2, hem, hx2 + w / 4, hem + s / 8 + drift, hx2 + w / 2, hem);
        }
        dc.setColor(shade(col, f), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, top + w / 3, w / 2 + 1);
        dc.setColor(shade(0x040608, f), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, top + w / 3 + 1, w / 3 + 1);
        if (s > 18) {
            dc.setColor(shade(0x99FFFF, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - w / 4, top + w / 3, 2, 3);
            dc.fillRectangle(x + w / 4 - 2, top + w / 3, 2, 3);
        }
        // Wisp arms
        dc.setColor(shade(col, f * 8 / 10), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x - w / 2, top + w, x - w - 2, top + w + s / 6 + drift);
        dc.drawLine(x + w / 2, top + w, x + w + 2, top + w + s / 6 - drift);
    }

    // Slab of muscle: broad shoulders, tiny head, tusks, tree-trunk club.
    hidden function _artOgre(dc, x, y, s, col, f) as Void {
        var w = s * 2 / 5;
        if (w < 6) { w = 6; }
        var top = y - s;
        var hr = w / 4 + 1;

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - w / 2, y - s / 3, w / 3, s / 3);
        dc.fillRectangle(x + w / 6, y - s / 3, w / 3, s / 3);
        _trap(dc, x, top + s / 4, w / 2, y - s / 3, w / 2 + 1);
        dc.fillCircle(x - w / 2, top + s / 4, w / 4 + 1);
        dc.fillCircle(x + w / 2, top + s / 4, w / 4 + 1);
        dc.fillCircle(x, top + hr + s / 8, hr);
        // Belly
        dc.setColor(shade(0xC89A66, f), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - s / 3 - s / 12, w / 4 + 1);
        if (s > 22) {
            dc.setColor(shade(0x201408, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - hr / 2 - 1, top + hr + s / 8 - 1, 2, 2);
            dc.fillRectangle(x + hr / 2 - 1, top + hr + s / 8 - 1, 2, 2);
            dc.setColor(shade(0xF0E8D0, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - hr / 2, top + hr + s / 8 + hr / 2, 2, 3);
            dc.fillRectangle(x + hr / 2 - 2, top + hr + s / 8 + hr / 2, 2, 3);
        }
        // Club
        dc.setColor(shade(0x6A4A28, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + w / 2 + 1, top + s / 5, 3, s / 2);
        dc.fillCircle(x + w / 2 + 2, top + s / 5, w / 4 + 2);
    }

    // Horns, membranous wings, burning eyes, whipping tail.
    hidden function _artDemon(dc, x, y, s, col, f, phase) as Void {
        var w = s / 3;
        if (w < 5) { w = 5; }
        var top = y - s;
        var hr = w / 2;
        var flap = ((phase % 4) < 2) ? s / 12 : 0;

        // Wings behind the body
        dc.setColor(shade(0x5A1010, f), Graphics.COLOR_TRANSPARENT);
        _tri(dc, x - w / 2, top + s / 4, x - w * 2, top + s / 8 - flap, x - w / 2, y - s / 3);
        _tri(dc, x + w / 2, top + s / 4, x + w * 2, top + s / 8 - flap, x + w / 2, y - s / 3);

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - w / 2, y - s / 3, w / 3, s / 3);
        dc.fillRectangle(x + w / 6, y - s / 3, w / 3, s / 3);
        _trap(dc, x, top + s / 4, w / 2, y - s / 3, w / 3);
        dc.fillCircle(x, top + hr + 1, hr);
        // Horns
        _tri(dc, x - hr, top + hr - hr / 2, x - hr - hr / 2, top - hr / 2, x - hr / 3, top + hr / 3);
        _tri(dc, x + hr, top + hr - hr / 2, x + hr + hr / 2, top - hr / 2, x + hr / 3, top + hr / 3);
        // Tail
        dc.drawLine(x + w / 3, y - s / 4, x + w, y - s / 8);
        if (s > 20) {
            dc.setColor(shade(0xFFEE33, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - hr / 2 - 1, top + hr, 3, 3);
            dc.fillRectangle(x + hr / 2 - 2, top + hr, 3, 3);
            dc.setColor(shade(0x201010, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - hr / 2, top + hr + hr / 2, hr, 1);
        }
    }

    // The floor-15 boss: a hulking mass of jaws, claws and too many eyes.
    hidden function _artBeast(dc, x, y, s, col, f, phase) as Void {
        var w = s / 2;
        if (w < 8) { w = 8; }
        var top = y - s;
        var breathe = ((phase % 6) < 3) ? 1 : 0;

        dc.setColor(shade(0x2A0810, f), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - s / 3, w / 2 + breathe + 2);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        // Haunches and arms
        dc.fillCircle(x - w / 2, y - s / 5, w / 4 + 1);
        dc.fillCircle(x + w / 2, y - s / 5, w / 4 + 1);
        _trap(dc, x, top + s / 3, w / 2, y - s / 8, w / 2 + 2);
        // Head fused into the shoulders
        dc.fillCircle(x, top + s / 4, w / 3 + 1 + breathe);
        // Claws
        dc.setColor(shade(0xF0E0D0, f), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) {
            dc.drawLine(x - w / 2 - i * 2, y - s / 8, x - w / 2 - i * 2 - 3, y);
            dc.drawLine(x + w / 2 + i * 2, y - s / 8, x + w / 2 + i * 2 + 3, y);
        }
        // Maw
        dc.setColor(shade(0x140000, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - w / 3, top + s / 4 + w / 8, w * 2 / 3, w / 4 + breathe);
        dc.setColor(shade(0xF8F0E0, f), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var tx = x - w / 3 + i * (w / 6);
            _tri(dc, tx, top + s / 4 + w / 8, tx + w / 12, top + s / 4 + w / 8 + w / 6, tx + w / 6, top + s / 4 + w / 8);
        }
        // Eye cluster
        dc.setColor(shade(0xFFCC22, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - w / 3, top + s / 5, 3, 3);
        dc.fillRectangle(x + w / 3 - 3, top + s / 5, 3, 3);
        dc.fillRectangle(x - 2, top + s / 6, 2, 2);
        dc.fillRectangle(x + 2, top + s / 6, 2, 2);
    }

    // ── Props ───────────────────────────────────────────────────────────────
    // Banded chest with a domed lid and a lock; the glow tells you the tier.
    function drawChest(dc, sx, baseY, size, kind, val, f) as Void {
        var phase = _phase;
        var w = size / 3;
        if (w < 6) { w = 6; }
        var h = size / 4;
        if (h < 5) { h = 5; }
        var top = baseY - h;
        var rarity = DmConst.lootRarity(kind, val);

        dc.setColor(shade(0x5A3A1E, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - w / 2, top, w, h);
        dc.setColor(shade(0x6E4824, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - w / 2, top - h / 3, w, h / 3 + 1);
        // Iron bands
        dc.setColor(shade(0x8A8478, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - w / 2, top - h / 3, 2, h + h / 3);
        dc.fillRectangle(sx + w / 2 - 2, top - h / 3, 2, h + h / 3);
        dc.fillRectangle(sx - w / 2, top, w, 1);
        // Lock
        dc.setColor(shade(DmConst.rarityColor(rarity), f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - 2, top - 1, 4, h / 2 + 1);
        if (size > 24) {
            // Rare chests breathe light.
            var g = (phase % 4);
            dc.setColor(shade(DmConst.rarityColor(rarity), f - g * 6 > 20 ? f - g * 6 : 20),
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - w / 3, top - h / 3 - 2 - g, w * 2 / 3, 1);
        }
    }

    // A real hole in the floor: arch, receding steps, and green depth light.
    function drawStairwell(dc, sx, baseY, size, f) as Void {
        var w = size * 2 / 3;
        if (w < 10) { w = 10; }
        var h = size / 2;
        var top = baseY - h;

        // Dark arch cut into the far wall.
        dc.setColor(shade(0x060806, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - w / 2, top, w, h);
        dc.fillCircle(sx, top, w / 2);
        // Descending steps.
        var steps = 5;
        var sh = h / steps;
        if (sh < 2) { sh = 2; }
        for (var i = 0; i < steps; i++) {
            var ww = w - i * (w / (steps + 2));
            var c = 70 - i * 11;
            if (c < 12) { c = 12; }
            dc.setColor(shade(0x5A5448, c * f / 100), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - ww / 2, baseY - (i + 1) * sh, ww, sh - 1 > 1 ? sh - 1 : 1);
        }
        // Cold glow from below.
        dc.setColor(shade(0x2E6A50, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - w / 4, top + h / 6, w / 2, 2);
        if (size > 30) {
            dc.setColor(shade(0x66DDAA, f), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx - w / 2, top + h, sx - w / 2, top);
            dc.drawLine(sx + w / 2, top + h, sx + w / 2, top);
        }
    }

    // Shrine / fountain / merchant, dimmed once you have used it.
    function drawFeature(dc, sx, baseY, size, kind, used, f) as Void {
        var phase = _phase;
        var w = size / 3;
        if (w < 6) { w = 6; }
        var h = size / 2;
        var top = baseY - h;
        var lit = (used == 0);
        var glowF = lit ? f : f / 2;

        if (kind == FEAT_FOUNTAIN) {
            dc.setColor(shade(0x5C6470, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - w, baseY - h / 3, w * 2, h / 3);
            dc.fillRectangle(sx - w / 4, top + h / 4, w / 2, h / 2);
            dc.setColor(shade(0x3A78B0, glowF), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - w + 2, baseY - h / 3, w * 2 - 4, 3);
            if (lit && size > 22) {
                dc.setColor(shade(0x88CCFF, f), Graphics.COLOR_TRANSPARENT);
                var d = (phase % 4);
                dc.fillCircle(sx, top + h / 4 - 2 - d, 2);
                dc.fillCircle(sx - w / 3, baseY - h / 3 - d, 1);
                dc.fillCircle(sx + w / 3, baseY - h / 3 - (3 - d), 1);
            }
            return;
        }
        if (kind == FEAT_MERCHANT) {
            // Hooded trader behind a small stall.
            dc.setColor(shade(0x5A3A20, f), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - w, baseY - h / 3, w * 2, h / 3);
            dc.setColor(shade(0x3A5A80, f), Graphics.COLOR_TRANSPARENT);
            _trap(dc, sx, top + h / 5, w / 2, baseY - h / 3, w * 2 / 3);
            dc.fillCircle(sx, top + h / 5, w / 2);
            dc.setColor(shade(0x0A0A0C, f), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, top + h / 5 + 1, w / 3);
            if (size > 22) {
                dc.setColor(shade(0xFFCC44, glowF), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(sx - w / 4, top + h / 5, 2, 2);
                dc.fillRectangle(sx + w / 4 - 2, top + h / 5, 2, 2);
                dc.fillCircle(sx - w * 2 / 3, baseY - h / 3 - 2, 2);
                dc.fillCircle(sx + w * 2 / 3, baseY - h / 3 - 2, 2);
            }
            return;
        }
        // Shrine: a stone pillar crowned with a floating sigil.
        dc.setColor(shade(0x6A6458, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - w / 2, top + h / 3, w, h - h / 3);
        dc.fillRectangle(sx - w, baseY - h / 6, w * 2, h / 6);
        dc.setColor(shade(0x4A4438, f), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - w / 2, top + h / 3, w, 2);
        if (lit) {
            var p = (phase % 4);
            dc.setColor(shade(0xCC88FF, f), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, top + h / 8 - p / 2, w / 3 + 1);
            dc.setColor(shade(0xFFFFFF, f), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, top + h / 8 - p / 2, w / 6 + 1);
        } else {
            dc.setColor(shade(0x2A2430, f), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, top + h / 8, w / 4);
        }
    }

    // ── Item icons (loot cards, pack, shop) ─────────────────────────────────
    function drawItemIcon(dc, kind as Lang.Number, val as Lang.Number,
                          cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        if (r < 4) { r = 4; }
        var col = DmConst.lootColor(kind);
        if (kind == LOOT_GOLD) {
            dc.setColor(0x8A6A20, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r, cy + r / 2, r * 2, r / 2);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - r / 2, cy, r / 2);
            dc.fillCircle(cx + r / 2, cy + r / 4, r / 2);
            dc.fillCircle(cx, cy - r / 2, r / 2);
            dc.setColor(0xFFF0B0, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - r / 2, cy - r / 6, r / 6 + 1);
            return;
        }
        if (kind == LOOT_POTION || kind == LOOT_ETHER) {
            dc.setColor(0x9AA0A8, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r / 4, cy - r, r / 2, r / 3);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy + r / 4, r * 2 / 3);
            dc.fillRectangle(cx - r / 3, cy - r * 2 / 3, r * 2 / 3, r);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r / 3, cy - r / 6, 2, r / 3);
            return;
        }
        if (kind == LOOT_SCROLL) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r, cy - r * 2 / 3, r * 2, r * 4 / 3);
            dc.setColor(0x8A7A50, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r, cy - r, r * 2, r / 3);
            dc.fillRectangle(cx - r, cy + r / 2, r * 2, r / 3);
            dc.setColor(0x5A4A30, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r / 2, cy - r / 4, r, 1);
            dc.fillRectangle(cx - r / 2, cy + r / 8, r, 1);
            return;
        }
        if (kind == LOOT_KEY) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx - r / 2, cy, r / 3 + 1);
            dc.fillRectangle(cx - r / 4, cy - 1, r + r / 2, 3);
            dc.fillRectangle(cx + r / 2, cy + 1, 2, r / 2);
            dc.fillRectangle(cx + r, cy + 1, 2, r / 3);
            return;
        }
        if (kind == LOOT_WEAPON) {
            dc.setColor(0xDDE4EC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 2, cy - r, 4, r + r / 2);
            _tri(dc, cx - 2, cy - r, cx, cy - r - r / 3, cx + 2, cy - r);
            dc.setColor(0xB08030, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r / 2, cy + r / 2, r, 2);
            dc.fillRectangle(cx - 1, cy + r / 2, 2, r / 2);
            return;
        }
        if (kind == LOOT_ARMOR) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            _trap(dc, cx, cy - r, r * 2 / 3, cy + r, r / 2);
            dc.setColor(0x66727E, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r / 2, cy - r / 3, r, 1);
            dc.fillRectangle(cx - r / 2, cy + r / 6, r, 1);
            dc.fillCircle(cx, cy - r / 2, r / 5 + 1);
            return;
        }
        if (kind == LOOT_RING) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawCircle(cx, cy + r / 4, r * 2 / 3);
            dc.setPenWidth(1);
            dc.setColor(0x66DDFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy - r / 2, r / 4 + 1);
            return;
        }
        if (kind == LOOT_AMULET) {
            dc.setColor(0xAA9966, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - r / 2, cy - r, cx, cy);
            dc.drawLine(cx + r / 2, cy - r, cx, cy);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            _diamond(dc, cx, cy + r / 3, r / 2, r * 2 / 3);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy + r / 3, r / 6 + 1);
            return;
        }
        // Bomb
        dc.setColor(0x2A2A30, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy + r / 4, r * 2 / 3);
        dc.setColor(0x6A5A3A, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx + r / 3, cy - r / 3, cx + r * 2 / 3, cy - r);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + r * 2 / 3, cy - r, r / 5 + 1);
    }
}
