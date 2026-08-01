// ═══════════════════════════════════════════════════════════════════════════
// FarmRender.mc — CHUNKY PIXEL-ART view of YOUR FARM (module `FarmArt`).
//
// The star of the HOME screen: a cosy, DEPTH-LAYERED pixel diorama of the
// player's whole homestead that visibly grows richer as they progress.
//
//   • Sky     — day/sunset/night/dawn gradient by time-of-day, sun or moon,
//               drifting puffy clouds, twinkling stars at night, birds, and the
//               Harvest Moon itself once it has been found.
//   • Stage   — THREE ground lanes (far / mid / front) receding into the
//               distance. Every structure owns an explicit (lane, slot x) seat
//               in Fa.bLane/Fa.bSlotX, is scaled by its lane and drawn
//               back-to-front so nearer buildings overlap further ones. Rail
//               fences and a winding dirt path separate the lanes.
//   • Farm    — every structure tier gets its OWN distinct pixel sprite: a red
//               Cow Barn, Chicken Coop, Duck Pond, Pig Pen for Livestock;
//               staggered wheat furrows, a Carrot Patch, an Orchard and Berry
//               Bushes for Crops; a Farm Stand, spinning Windmill, Bakery and
//               Petting Zoo for the Market; and the SPECIAL landmarks appear
//               once explored. LATE GAME adds sunflowers, a Creamery, an Alpaca
//               pen, the Cider Mill and a silver Moonlit Barn.
//   • Life    — cute animals (chickens, ducks, pigs, cows, alpacas) wander every
//               lane, their species matching what you've built, count ~ herd.
//   • Decor   — all 15 collectibles have their own pixel charm and their own
//               seat in the scene.
//   • Cards   — bldArt / areaArt / collArt draw big portraits for the detail
//               cards and the list rows, so a thing looks the same everywhere.
//
// Everything is drawn from cheap primitive fills, contained in a box, scales to
// any watch, and is fully guarded — the master render is wrapped in try/catch
// (drawBox) and every major sub-feature is ALSO individually guarded.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;

module FarmArt {

    // ── Public entry points ────────────────────────────────────────────────
    // Legacy signature kept for the shared-menu preview band: centre + radius.
    function drawScene(dc, m, cx, cy, r, phase) {
        if (r < 8) { r = 8; }
        var w = r * 36 / 10;
        var h = r * 30 / 10;
        var x = cx - w / 2;
        var y = cy - h * 42 / 100;
        drawBox(dc, m, x, y, w, h, phase, true);
    }

    // Full pixel diorama inside an explicit rectangle (used by the HOME page).
    function drawBox(dc, m, x, y, w, h, phase, mini) {
        try { _render(dc, m, x, y, w, h, phase, mini); } catch (e) {}
    }

    // ── Master render ───────────────────────────────────────────────────────
    function _render(dc, m, x, y, w, h, phase, mini) {
        var p = w / 42; if (p < 2) { p = 2; }
        var cx = x + w / 2;
        var tod = _timeBucket();

        var horizon = y + h * 37 / 100;         // where sky meets the far hills
        var bottom  = y + h;
        var fieldHalf = w * 46 / 100;

        _sky(dc, x, y, w, horizon - y, tod, phase);
        _light(dc, x, y, w, h, tod, phase);
        if (!mini) { try { _clouds(dc, x, y, w, h, tod, phase); } catch (e) {} }
        _birds(dc, cx, y, w, h, p, phase);
        _hills(dc, x, horizon, w, bottom - horizon, tod, phase);
        _pasture(dc, x, y, w, h, horizon, bottom, tod, phase);
        _estate(dc, m, x, y, w, h, cx, fieldHalf, p, phase, mini);
    }

    // ── Lane geometry ───────────────────────────────────────────────────────
    // The scene is a three-step stage. Lane 0 sits high and small, lane 2 low
    // and full size; the horizontal spread narrows on the extreme lanes so
    // nothing on a round watch is clipped by the bezel.
    function _laneBase(y, h, l) { return y + h * Fa.laneY(l) / 100; }
    function _lanePx(p, l) {
        var sp = p * Fa.laneScale(l) / 100;
        if (sp < 2) { sp = 2; }
        return sp;
    }
    function _laneX(cx, fieldHalf, l, slotX) {
        return cx + fieldHalf * Fa._c(slotX, -100, 100) * Fa.laneSpread(l) / 10000;
    }

    // ── Deterministic scatter hash (position-based, never flickers) ──────────
    function _hash(seed) {
        var h = seed.toLong() * 2654435761l;
        h = h & 0x7FFFFFFFl;
        h = h ^ (h >> 13);
        h = h & 0x7FFFFFFFl;
        return h.toNumber();
    }

    // ── Time of day: 0 dawn · 1 day · 2 sunset · 3 night ──────────────────────
    function _timeBucket() {
        var hr = 13;
        try {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            if (info != null && info.hour != null) { hr = info.hour; }
        } catch (e) {}
        if (hr < 6)  { return 3; }
        if (hr < 8)  { return 0; }
        if (hr < 17) { return 1; }
        if (hr < 20) { return 2; }
        return 3;
    }

    // ── Sky ───────────────────────────────────────────────────────────────
    function _sky(dc, x, y, w, h, tod, phase) {
        if (h < 3) { h = 3; }
        var top; var bot;
        if (tod == 3)      { top = 0x000055; bot = 0x0055AA; }   // night
        else if (tod == 2) { top = 0x5555AA; bot = 0xFFAA55; }   // sunset
        else if (tod == 0) { top = 0x5555AA; bot = 0xFFAAAA; }   // dawn
        else               { top = 0x55AAFF; bot = 0xAAFFFF; }   // day
        Px.vgrad(dc, x, y, w, h, top, bot, 14);
        if (tod == 3) { _stars(dc, x, y, w, h, phase); }
    }

    function _stars(dc, x, y, w, h, phase) {
        dc.setColor(0xEAF2FF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            var sx = x + ((i * 37 + 11) % 100) * w / 100;
            var sy = y + ((i * 53 + 7) % 70) * h / 100;
            if (((phase / 6) + i) % 5 == 0) { continue; }
            dc.fillRectangle(sx, sy, 2, 2);
        }
    }

    // ── Sun / Moon ──────────────────────────────────────────────────────────
    // Sits low and to one side: the top fifth of the page belongs to the tab
    // strip, so nothing important is drawn up there.
    function _light(dc, x, y, w, h, tod, phase) {
        var lx = x + w * 78 / 100;
        var ly = y + h * 21 / 100;
        var rr = w / 16; if (rr < 5) { rr = 5; }
        if (tod == 3) {                              // moon
            dc.setColor(0xF0F4FA, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lx, ly, rr);
            dc.setColor(0x24406A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lx + rr / 2, ly - rr / 3, rr * 8 / 10);
            return;
        }
        var glow; var core;
        if (tod == 2)      { glow = 0xFFAA55; core = 0xFF5500; }
        else if (tod == 0) { glow = 0xFFFFAA; core = 0xFFAA55; }
        else               { glow = 0xFFFFAA; core = 0xFFAA00; }
        dc.setColor(glow, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 8; i++) {
            var a = phase.toFloat() * 0.02 + i * 0.785;
            var x1 = lx + (Math.cos(a) * (rr + 3)).toNumber();
            var y1 = ly + (Math.sin(a) * (rr + 3)).toNumber();
            var x2 = lx + (Math.cos(a) * (rr + rr)).toNumber();
            var y2 = ly + (Math.sin(a) * (rr + rr)).toNumber();
            dc.drawLine(x1, y1, x2, y2);
        }
        dc.fillCircle(lx, ly, rr + 1);
        dc.setColor(core, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lx, ly, rr);
    }

    // Soft puffy clouds drifting across the sky.
    function _clouds(dc, x, y, w, h, tod, phase) {
        var col = (tod == 3) ? 0x005555 : 0xFFFFFF;
        var rows = [".ccc.", "ccccc", "ccccc"];
        var pal = { "c" => col };
        var span = w * 120 / 100;
        for (var i = 0; i < 2; i++) {
            var cxp = x - w * 10 / 100 + ((phase / 8 + i * 90) % span);
            var cyp = y + h * (16 + i * 11) / 100;
            var cp = w / 30; if (cp < 2) { cp = 2; }
            Px.spr(dc, rows, pal, cxp, cyp, cp, false);
        }
    }

    function _birds(dc, cx, y, w, h, p, phase) {
        dc.setColor(0x2A3540, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) {
            var span = w * 90 / 100;
            var bx = (cx - w * 45 / 100) + ((phase / 3 + i * 47) % span);
            var by = y + h * (24 + i * 6) / 100 + (Math.sin(phase.toFloat() * 0.1 + i) * 2).toNumber();
            var s = p < 3 ? 2 : p - 1;
            var flap = ((phase / 4 + i) % 2 == 0) ? 1 : 0;
            dc.fillRectangle(bx, by - flap, s, 1);
            dc.fillRectangle(bx + s, by - 1, s, 1);
            dc.fillRectangle(bx + s * 2, by - flap, s, 1);
        }
    }

    // ── Far rolling hills behind the farm ─────────────────────────────────────
    // Three receding bands rather than one green wall: hazy ridge, a treeline
    // of individual crowns, then the pasture edge.
    function _hills(dc, x, horizon, w, h, tod, phase) {
        var ridge = tod == 3 ? 0x000055 : 0x55AAAA;
        var mid   = tod == 3 ? 0x005555 : 0x00AA55;
        var tree  = tod == 3 ? 0x000000 : 0x005500;
        var treeHi= tod == 3 ? 0x005500 : 0x55AA55;

        // Hazy ridge just above the horizon.
        dc.setColor(ridge, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 6; i++) {
            var hx = x - w * 8 / 100 + i * w * 21 / 100;
            var hr = w * (11 + (i % 3) * 3) / 100;
            dc.fillCircle(hx, horizon - h * 1 / 100, hr);
        }
        dc.fillRectangle(x, horizon - 2, w, 4);

        // Rolling mid hills.
        dc.setColor(mid, Graphics.COLOR_TRANSPARENT);
        for (var j = 0; j < 5; j++) {
            var mx = x - w * 4 / 100 + j * w * 26 / 100;
            dc.fillCircle(mx, horizon + h * 2 / 100, w * (13 + (j % 2) * 4) / 100);
        }
        dc.fillRectangle(x, horizon, w, h * 4 / 100);

        // Treeline: individual crowns give the horizon a readable silhouette.
        var tp = w / 52; if (tp < 2) { tp = 2; }
        for (var k = 0; k < 22; k++) {
            var tx = x + w * (1 + k * 45 / 10) / 100 + (_hash(k * 7 + 3) % 5);
            var tw = tp * 2 + _hash(k * 13) % (tp * 2);
            var th = tp + tp * (_hash(k * 17) % 4);
            dc.setColor(tree, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tx, horizon - th, tw / 2);          // rounded crown
            dc.fillRectangle(tx - tw / 2, horizon - th, tw, th + tp);
            dc.setColor(treeHi, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tx - tw / 6, horizon - th - tw / 8, tw / 6);
        }
    }

    // ── Foreground pasture ─────────────────────────────────────────────────
    // Three subtly different green bands make the lanes readable as distance,
    // and a winding dirt path threads down through all of them.
    function _pasture(dc, x, y, w, h, horizon, bottom, tod, phase) {
        var g1 = tod == 3 ? 0x005500 : 0x55AA55;   // near grass
        var g2 = tod == 3 ? 0x000000 : 0x00AA00;
        var soil= tod == 3 ? 0x550000 : 0xAA5500;
        // A 64-colour MIP screen turns a smooth ramp into two hard steps, so the
        // ground is painted as three deliberate bands instead — one per lane,
        // which is also what sells the depth.
        var b0 = _laneBase(y, h, 0) + h * 4 / 100;
        var b1 = _laneBase(y, h, 1) + h * 5 / 100;
        dc.setColor(g2, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, horizon, w, b0 - horizon);
        dc.setColor(tod == 3 ? 0x005500 : 0x55AA00, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, b0, w, b1 - b0);
        dc.setColor(g1, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, b1, w, bottom - b1);

        // A slim, gently winding dirt path down the middle.
        // The country lane runs ACROSS the scene between the middle and front
        // lanes. A vertical track down the centre cut the farm in half and hid
        // the buildings behind a brown slab.
        var soilHi = tod == 3 ? 0xAA5500 : 0xFFAA55;
        var depth = bottom - horizon;
        var roadY = horizon + depth * 55 / 100;
        var roadH = depth * 7 / 100; if (roadH < 3) { roadH = 3; }
        for (var s = 0; s < w; s += 2) {
            var wob = (Math.sin(s.toFloat() / w * 3.1) * roadH * 6 / 10).toNumber();
            dc.setColor(soil, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + s, roadY + wob, 2, roadH);
            dc.setColor(soilHi, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + s, roadY + wob, 2, 1);
        }
        // Wheel ruts.
        dc.setColor(tod == 3 ? 0x000000 : 0x550000, Graphics.COLOR_TRANSPARENT);
        for (var u = 0; u < w; u += 6) {
            var wob2 = (Math.sin(u.toFloat() / w * 3.1) * roadH * 6 / 10).toNumber();
            dc.fillRectangle(x + u, roadY + wob2 + roadH / 3, 3, 1);
        }

        // Grass tufts so the open pasture is not a flat sheet of green.
        dc.setColor(tod == 3 ? 0x005555 : 0xAAFF55, Graphics.COLOR_TRANSPARENT);
        for (var g = 0; g < 26; g++) {
            var gx = x + _hash(g * 23 + 9) % w;
            var gy = horizon + depth * (10 + _hash(g * 41 + 3) % 88) / 100;
            dc.fillRectangle(gx, gy, 3, 1);
            dc.fillRectangle(gx + 1, gy - 1, 1, 1);
        }

        // Wildflowers scattered across the field.
        var fl = [0xFFFFFF, 0xFFE24A, 0xFF7FA0, 0xB46CFF];
        for (var f = 0; f < 14; f++) {
            var fx = x + _hash(f * 19 + 5) % w;
            var fy = horizon + (bottom - horizon) * (18 + _hash(f * 29 + 1) % 78) / 100;
            dc.setColor(tod == 3 ? 0x2E6E38 : 0x3E8E36, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx, fy, 1, 3);
            dc.setColor(fl[_hash(f * 31 + 2) % fl.size()], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx - 1, fy - 1, 2, 2);
        }
    }

    // Rail fence marking the boundary just behind a lane, drawn before that
    // lane's sprites so they stand in front of it.
    function _laneRail(dc, cx, ry, half, p) {
        var col = 0xC8A06A; var colHi = 0xE0BE86;
        var post = (p < 3) ? 1 : 2;
        var n = 8;
        for (var i = 0; i <= n; i++) {
            var fx = cx - half + half * 2 * i / n;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx, ry - p * 2, post, p * 2);
            dc.setColor(colHi, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx, ry - p * 2, post, 1);
        }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - half, ry - p * 3 / 2, half * 2, 1);
        dc.fillRectangle(cx - half, ry - p / 2, half * 2, 1);
    }

    // ── The homestead: structures seated in their lanes ───────────────────────
    function _estate(dc, m, x, y, w, h, cx, fieldHalf, p, phase, mini) {
        var lv = new [Fa.B_N];
        var coll = 0; var built = 0;
        // Zeroed first: a half-filled level array must never leave nulls behind.
        for (var z = 0; z < Fa.B_N; z++) { lv[z] = 0; }
        try {
            for (var i = 0; i < Fa.B_N; i++) { lv[i] = m.bLevel[i]; }
            coll = m.collMask;
            built = m.totalBuildingLevels();
        } catch (e) {}

        // The Harvest Moon hangs in the sky, behind every ground lane.
        if (lv[Fa.B_HARVMOON] > 0) {
            try { _harvestMoon(dc, lv[Fa.B_HARVMOON], _laneX(cx, fieldHalf, Fa.LN_BACK, Fa.bSlotX(Fa.B_HARVMOON)),
                              y + h * 27 / 100, p); } catch (e) {}
        }

        // Empty farm → cosy starter paddock so the scene is never bare.
        if (built == 0) {
            try { _starter(dc, cx, _laneBase(y, h, Fa.LN_MID), _lanePx(p, Fa.LN_MID)); } catch (e) {}
            return;
        }

        // Back to front: each lane's rail, then its buildings, charms, animals.
        for (var l = 0; l < Fa.LN_N; l++) {
            var by = _laneBase(y, h, l);
            var sp = _lanePx(p, l);
            var half = fieldHalf * Fa.laneSpread(l) / 100;
            if (!mini && l > 0) {
                try { _laneRail(dc, cx, by - sp * 4, half * 98 / 100, sp); } catch (e) {}
            }
            for (var i = 0; i < Fa.B_N; i++) {
                if (lv[i] <= 0 || i == Fa.B_HARVMOON) { continue; }
                if (Fa.bLane(i) != l) { continue; }
                try { _bld(dc, i, lv[i], _laneX(cx, fieldHalf, l, Fa.bSlotX(i)), by, sp, phase); } catch (e) {}
            }
            for (var c = 0; c < Fa.C_N; c++) {
                if ((coll & (1 << c)) == 0 || Fa.cLane(c) != l) { continue; }
                try { _charm(dc, c, _laneX(cx, fieldHalf, l, Fa.cSlotX(c)), by + sp, sp * 85 / 100); } catch (e) {}
            }
            if (!mini) {
                try { _animals(dc, m, l, cx, by, half, sp, phase); } catch (e) {}
            }
        }
    }

    // Grow a landmark a little with its level, but never enough to break the
    // lane's depth ordering.
    function _grow(sp, lvl) {
        var e = lvl / 4; if (e > 2) { e = 2; }
        return sp + e;
    }

    // ── One structure, seated at (sx, by) with pixel size sp ─────────────────
    function _bld(dc, id, lvl, sx, by, sp, phase) {
        if (id == Fa.B_COOP) {
            var rows = ["..a..", ".aaa.", "cwwwc", "cwdwc"];
            var pal = { "a" => 0xC85A3A, "w" => 0xF0E0C0, "d" => 0x6A3A22, "c" => 0x8A5A3A };
            _place(dc, rows, pal, sx, by, sp, false);
            return;
        }
        if (id == Fa.B_DUCK) {                       // duck pond
            dc.setColor(0x4FB0E0, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, by - sp, sp * 2);
            dc.setColor(0x7FD0F0, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx - sp / 2, by - sp - sp / 2, sp);
            dc.setColor(0x3E8E36, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sp * 3, by - sp, 2, sp * 2);
            dc.fillRectangle(sx + sp * 3, by - sp * 2, 2, sp * 2);
            return;
        }
        if (id == Fa.B_PIG) {                        // fenced mud wallow
            dc.setColor(0x8A5A34, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sp * 2, by - sp * 2, sp * 4, sp * 2);
            dc.setColor(0x6A4224, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sp, by - sp * 2, sp * 2, 1);
            dc.setColor(0xC8A06A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sp * 2, by - sp * 2, sp * 4, 1);
            dc.fillRectangle(sx - sp * 2, by - sp * 3, 1, sp * 2);
            dc.fillRectangle(sx + sp * 2, by - sp * 3, 1, sp * 2);
            return;
        }
        if (id == Fa.B_COW) {                        // classic red barn
            var r2 = [".rrrrr.", "rrrrrrr", "bwbbbwb", "bbbdbbb", "bbbdbbb"];
            var p2 = { "r" => 0x8A2A2A, "b" => 0xD24A3A, "w" => 0xF0E0C0, "d" => 0x5A2A1A };
            _place(dc, r2, p2, sx, by, _grow(sp, lvl), false);
            return;
        }
        if (id == Fa.B_WHEAT) { _furrows(dc, sx, by, sp, lvl, phase); return; }
        if (id == Fa.B_CARROT) {
            var r3 = ["g.g.g", "ooooo"];
            var p3 = { "g" => 0x6FD06A, "o" => 0xFF9A4A };
            _place(dc, r3, p3, sx, by, sp, false);
            return;
        }
        if (id == Fa.B_ORCHARD) {                    // apple trees
            var nTree = 1 + lvl; if (nTree > 3) { nTree = 3; }
            var tRows = [".fff.", "fffff", "fffff", "..t..", "..t.."];
            var tPal = { "f" => 0x3FA85A, "t" => 0x7A4A2A };
            for (var t = 0; t < nTree; t++) {
                var tx = sx + t * sp * 5;
                _place(dc, tRows, tPal, tx, by + (t % 2) * sp, sp, false);
                dc.setColor(0xFF5A5A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(tx - sp, by - sp * 4, 2, 2);
                dc.fillRectangle(tx + sp, by - sp * 3, 2, 2);
            }
            return;
        }
        if (id == Fa.B_BERRY) {
            var r4 = ["bgb", "ggg", "bgb"];
            var p4 = { "g" => 0x2E8C3C, "b" => 0xB46CFF };
            _place(dc, r4, p4, sx, by, sp, false);
            return;
        }
        if (id == Fa.B_STAND) {                      // striped market stall
            var r5 = ["rwrwr", "wwwww", "p...p", "p...p"];
            var p5 = { "r" => 0xE05A5A, "w" => 0xF4EAD0, "p" => 0x8A5A3A };
            _place(dc, r5, p5, sx, by, _grow(sp, lvl), false);
            return;
        }
        if (id == Fa.B_WINDMILL) {                   // tower with turning sails
            var tRows2 = [".www.", ".www.", ".www.", ".www."];
            var tPal2 = { "w" => 0xE8D8B0 };
            var mp = _grow(sp, lvl);
            _place(dc, tRows2, tPal2, sx, by, mp, false);
            var bl = mp * 4;
            var ang = phase.toFloat() * 0.15;
            var hubY = by - 4 * mp;
            dc.setColor(0x8A5A3A, Graphics.COLOR_TRANSPARENT);
            for (var k = 0; k < 4; k++) {
                var a = ang + k * 1.5708;
                dc.drawLine(sx, hubY, sx + (Math.cos(a) * bl).toNumber(), hubY + (Math.sin(a) * bl).toNumber());
            }
            dc.setColor(0xF0E0C0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 1, hubY - 1, 3, 3);
            return;
        }
        if (id == Fa.B_BAKERY) {                     // chimney + drifting smoke
            var r6 = ["..h..", "bbbbb", "bwbwb", "bbdbb"];
            var p6 = { "b" => 0xC88A5A, "w" => 0xFFE7C0, "d" => 0x6A3A22, "h" => 0x8A5A3A };
            _place(dc, r6, p6, sx, by, _grow(sp, lvl), false);
            if ((phase / 5) % 2 == 0) {
                dc.setColor(0xD8D8D8, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(sx, by - sp * 6, 2, 2);
            }
            return;
        }
        if (id == Fa.B_PETZOO) {                     // banner over a low pen
            dc.setColor(0xFF7FA0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sp * 2, by - sp * 4, sp * 4, sp);
            dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sp * 2, by - sp * 4, 2, sp * 4);
            dc.fillRectangle(sx + sp * 2, by - sp * 4, 2, sp * 4);
            dc.setColor(0xC8A06A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sp * 2, by - 1, sp * 4, 1);
            return;
        }
        if (id == Fa.B_GOLDBARN) {
            var r7 = [".ggggg.", "ggggggg", "GwGGGwG", "GGGdGGG", "GGGdGGG"];
            var p7 = { "g" => 0xE0A82A, "G" => 0xFFD24A, "w" => 0xFFF0B0, "d" => 0x8A5A1A };
            _place(dc, r7, p7, sx, by, _grow(sp, lvl), false);
            return;
        }
        if (id == Fa.B_GREENHSE) {
            var r8 = ["..ggg..", ".ggggg.", "GbGbGbG", "GbGbGbG", "GGGGGGG"];
            var p8 = { "g" => 0xBFF0D0, "G" => 0xCFEFE0, "b" => 0x6FD06A };
            var gp = _grow(sp, lvl);
            _place(dc, r8, p8, sx, by, gp, false);
            if ((phase / 4) % 3 == 0) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(sx - gp * 2, by - gp * 5, 2, 2);
            }
            return;
        }
        if (id == Fa.B_PRIZEBULL) {                  // statue on a plinth
            var r9 = ["h...h", "bbbbb", "bbbbb", ".b.b.", "sssss"];
            var p9 = { "b" => 0x8A5A3A, "h" => 0xD8D0C0, "s" => 0xB0A890 };
            _place(dc, r9, p9, sx, by, sp, false);
            return;
        }
        if (id == Fa.B_SILO) {                       // tall rainbow silo
            var rA = ["ccc", "rrr", "ooo", "yyy", "ggg", "bbb", "www", "www"];
            var pA = { "c" => 0xC0C6CC, "r" => 0xFF6A6A, "o" => 0xFF9A4A, "y" => 0xFFD24A,
                       "g" => 0x8CD060, "b" => 0x6FB3FF, "w" => 0xE6ECEA };
            _place(dc, rA, pA, sx, by, _grow(sp, lvl), false);
            return;
        }
        if (id == Fa.B_ALPACA) {                     // fenced alpaca paddock
            dc.setColor(0xC8A06A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sp * 3, by - 1, sp * 6, 2);
            var rB = [".ff", "fff", "ff.", "l.l"];
            var pB = { "f" => 0xE8D8B0, "l" => 0xC0A880 };
            _place(dc, rB, pB, sx, by, sp, false);
            return;
        }
        if (id == Fa.B_SUNFLR) {                     // swaying sunflower row
            var n = 3 + lvl / 2; if (n > 5) { n = 5; }
            var sway = (Math.sin(phase.toFloat() * 0.06) * 1).toNumber();
            for (var i2 = 0; i2 < n; i2++) {
                var fx2 = sx + i2 * sp * 3 + sway;
                dc.setColor(0x3E8E36, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(fx2, by - sp * 4, 2, sp * 4);
                dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(fx2 + 1, by - sp * 4, sp);
                dc.setColor(0x8A5A1A, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(fx2 + 1, by - sp * 4, sp / 3);
            }
            return;
        }
        if (id == Fa.B_CREAMRY) {
            var rC = ["..b..", "bbbbb", "wwdww", "wwdww"];
            var pC = { "b" => 0x6FA8D0, "w" => 0xEAF2F0, "d" => 0x8A9AA0 };
            _place(dc, rC, pC, sx, by, _grow(sp, lvl), false);
            return;
        }
        if (id == Fa.B_CIDER) {
            var rD = ["..r..", "rrrrr", "cwcwc", "ccdcc"];
            var pD = { "r" => 0x8A3A2A, "c" => 0xC86A3A, "w" => 0xFFD8A0, "d" => 0x5A2A1A };
            _place(dc, rD, pD, sx, by, _grow(sp, lvl), false);
            dc.setColor(0x8A5A3A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx + sp * 3, by - sp * 2, sp * 2, sp * 2);
            return;
        }
        if (id == Fa.B_MOONBARN) {
            var rE = [".sssss.", "sssssss", "bwbbbwb", "bbbdbbb", "bbbdbbb"];
            var pE = { "s" => 0x6A7AB0, "b" => 0x9AB0FF, "w" => 0xEAF0FF, "d" => 0x3A4A7A };
            _place(dc, rE, pE, sx, by, _grow(sp, lvl), false);
            return;
        }
    }

    // Wheat drawn as three STAGGERED furrows receding up the lane, so the crop
    // reads as a worked field instead of one line of stalks.
    function _furrows(dc, sx, by, sp, lvl, phase) {
        var rowsN = 3;
        var perRow = 4 + lvl / 3; if (perRow > 6) { perRow = 6; }
        var sway = (Math.sin(phase.toFloat() * 0.08) * 1).toNumber();
        for (var r = 0; r < rowsN; r++) {
            var ry = by - r * sp * 2;
            var off = (r % 2 == 0) ? 0 : sp;
            for (var i = 0; i < perRow; i++) {
                var wx = sx - perRow * sp + i * sp * 2 + off + sway;
                dc.setColor(0x8A5A34, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(wx - 1, ry, sp + 2, 1);
                dc.setColor(0xE8C24A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(wx, ry - sp * 3, sp - 1 < 1 ? 1 : sp - 1, sp * 3);
                dc.setColor(0xFFE07A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(wx - 1, ry - sp * 3 - 1, sp + 1, 2);
            }
        }
    }

    // Harvest Moon hanging over the ridge — a sky landmark, not a ground one.
    function _harvestMoon(dc, lvl, mx, my, p) {
        var mr = p * 2 + lvl; if (mr > p * 5) { mr = p * 5; }
        dc.setColor(0xF0C860, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, mr + 2);
        dc.setColor(0xFFF3C4, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, mr);
        dc.setColor(0xF0D890, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx + mr / 3, my - mr / 3, mr / 4);
    }

    // ── Collection charms — every charm has its own sprite and its own seat ───
    function _charm(dc, id, sx, by, sp) {
        if (sp < 2) { sp = 2; }
        var rows; var pal;
        if (id == 0) {          // Flower Bed
            pal = { "r" => 0xFF7FA0, "o" => 0xFFD24A, "b" => 0x6FB3FF, "y" => 0xFFE24A, "g" => 0x3E8E36 };
            rows = ["ror", "ggg", "byb"];
        } else if (id == 1) {   // Scarecrow
            pal = { "h" => 0xE8C24A, "s" => 0x8A5A3A };
            rows = [".h.", "shs", ".s.", "sss", ".s."];
        } else if (id == 2) {   // Hay Bales
            pal = { "y" => 0xE8C24A, "Y" => 0xC79A2A };
            rows = ["yyy", "yYy", "yyy"];
        } else if (id == 3) {   // Golden Egg
            pal = { "g" => 0xFFD24A, "w" => 0xFFF0B0 };
            rows = [".g.", "gwg", "ggg", ".g."];
        } else if (id == 4) {   // Pond Ducks
            pal = { "y" => 0xF4D24A, "o" => 0xFF9A4A, "w" => 0x4FB0E0 };
            rows = ["y.y.", "yoyo", "wwww"];
        } else if (id == 5) {   // Rainbow Cow
            pal = { "r" => 0xFF6A6A, "g" => 0xF0F0F0, "o" => 0xFF9A4A, "b" => 0x6FB3FF,
                    "m" => 0xB46CFF, "l" => 0x5A3A2A };
            rows = ["r.r", "ggg", "obm", ".l."];
        } else if (id == 6) {   // Wishing Well
            pal = { "r" => 0x8A2A2A, "s" => 0x9A968C, "w" => 0x6FD0E0 };
            rows = [".r.", "rrr", "sws", "sss"];
        } else if (id == 7) {   // Prize Ribbon
            pal = { "y" => 0xFFD24A, "b" => 0x6FB3FF };
            rows = [".y.", "yyy", ".y.", "b.b"];
        } else if (id == 8) {   // Harvest Feast
            pal = { "r" => 0xFF6A6A, "o" => 0xFFD24A, "w" => 0xF4EAD0, "b" => 0x8A5A3A };
            rows = ["ror", "www", "b.b"];
        } else if (id == 9) {   // Bee Hive
            pal = { "y" => 0xFFD86A, "Y" => 0xC79A2A, "d" => 0x5A3A1A };
            rows = [".yy.", "yYYy", "yYYy", ".dd."];
        } else if (id == 10) {  // Stone Bridge
            pal = { "s" => 0x9FB0C0, "d" => 0x6A7A88 };
            rows = [".sss.", "ss.ss", "d...d"];
        } else if (id == 11) {  // Marsh Lantern
            pal = { "m" => 0x7FA8A0, "w" => 0x8CE0FF, "p" => 0x4A5A58 };
            rows = [".m.", "mwm", "mwm", ".p."];
        } else if (id == 12) {  // Sun Crown
            pal = { "y" => 0xFFE24A, "o" => 0xFFA84A };
            rows = ["y.y.y", "oyoyo", ".ooo."];
        } else if (id == 13) {  // Moon Cart
            pal = { "w" => 0xEAF0FF, "p" => 0xB46CFF, "k" => 0x3A2A4A };
            rows = ["..w..", "ppppp", "p...p", "k...k"];
        } else if (id == 14) {  // Golden Plow
            pal = { "g" => 0xFFD24A, "s" => 0x8A5A3A };
            rows = ["s....", ".s...", ".ggg.", "..g.."];
        } else {
            pal = { "c" => Fa.cColor(id), "s" => 0x6A5A3A };
            rows = [".c.", "ccc", "sss"];
        }
        _place(dc, rows, pal, sx, by, sp, false);
    }

    // ── Animals wandering a lane ──────────────────────────────────────────────
    // Species match what the player has built; count ~ herd size (capped), and
    // each lane gets its own share so the herd fills the whole stage.
    function _animals(dc, m, lane, cx, by, half, sp, phase) {
        var pop = 0; var lv = null;
        try { pop = m.population; lv = m.bLevel; } catch (e) { pop = 0; }
        if (pop <= 0) { return; }
        var total = pop; if (total > 9) { total = 9; }

        var species = [];
        try {
            if (lv != null) {
                if (lv[Fa.B_COOP] > 0) { species.add(0); }
                if (lv[Fa.B_DUCK] > 0) { species.add(1); }
                if (lv[Fa.B_PIG]  > 0) { species.add(2); }
                if (lv[Fa.B_COW]  > 0) { species.add(3); }
                if (lv[Fa.B_ALPACA] > 0) { species.add(4); }
            }
        } catch (e) {}
        if (species.size() == 0) { species = [0]; }

        // Sprite table: 0 chicken, 1 duck, 2 pig, 3 cow, 4 alpaca.
        var sprites = [
            [".c.", "www", "ww.", "l.l"],   // chicken
            [".y.", "yyo", "yyy", "f.f"],   // duck
            ["...", "ppp", "ppp", "l.l"],   // pig
            ["b.b", "www", "wbw", "l.l"],   // cow
            [".ff", "fff", "ff.", "l.l"]    // alpaca
        ];
        var pals = [
            { "c" => 0xFF5A5A, "w" => 0xF4F4F4, "l" => 0xE0A020 },
            { "y" => 0xF4D24A, "o" => 0xFF9A4A, "f" => 0xE0A020 },
            { "p" => 0xFF9AB0, "l" => 0xD07A90 },
            { "w" => 0xF4F4F4, "b" => 0x2A2A2A, "l" => 0x8A6A4A },
            { "f" => 0xE8D8B0, "l" => 0xC0A880 }
        ];
        var vp = sp * 65 / 100; if (vp < 2) { vp = 2; }
        var range = half * 78 / 100;
        for (var i = 0; i < total; i++) {
            if (_hash(i * 7 + 1) % Fa.LN_N != lane) { continue; }
            var s = species[_hash(i * 13 + 3) % species.size()];
            var speedMil = 16 + (_hash(i * 11 + 7) % 26);
            var wx = cx + (Math.sin(phase.toFloat() * (0.015 + speedMil.toFloat() * 0.001) + i * 1.9) * range).toNumber();
            var wy = by + vp + (i % 2) * vp;
            _place(dc, sprites[s], pals[s], wx, wy, vp, ((phase / (6 + (i % 4)) + i) % 2 == 0));
        }
    }

    // ── Starter paddock for an empty farm ─────────────────────────────────────
    function _starter(dc, cx, groundY, p) {
        // A cosy little coop + a sprout + a hen so it's never bare.
        var coop = { "a" => 0xC85A3A, "w" => 0xF0E0C0, "d" => 0x6A3A22, "c" => 0x8A5A3A };
        var rows = ["..a..", ".aaa.", "cwwwc", "cwdwc"];
        _place(dc, rows, coop, cx, groundY, p, false);
        var hen = { "c" => 0xFF5A5A, "w" => 0xF4F4F4, "l" => 0xE0A020 };
        var henRows = [".c.", "www", "ww.", "l.l"];
        _place(dc, henRows, hen, cx + p * 4, groundY + p * 3, p * 6 / 10, false);
        var sprout = { "g" => 0x6FD06A, "t" => 0x7A4A2A };
        var sRows = ["g.g", ".g.", ".t."];
        _place(dc, sRows, sprout, cx - p * 4, groundY + p * 2, p, false);
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    // Draw a sprite bottom-centred at (cxp, baseY).
    function _place(dc, rows, pal, cxp, baseY, px, flip) {
        if (rows == null || rows.size() == 0) { return; }
        if (px < 1) { px = 1; }
        var wc = rows[0].length();
        var hc = rows.size();
        Px.spr(dc, rows, pal, cxp - wc * px / 2, baseY - hc * px, px, flip);
    }
    // Draw a sprite centred on (cx, cy) — used by the detail-card portraits.
    function _sprC(dc, rows, pal, cx, cy, px) {
        if (rows == null || rows.size() == 0) { return; }
        if (px < 1) { px = 1; }
        Px.spr(dc, rows, pal, cx - rows[0].length() * px / 2, cy - rows.size() * px / 2, px, false);
    }

    // ═══ Detail-card artwork ═════════════════════════════════════════════════
    // Chunky pixel portraits behind every detail card: a structure, an
    // expedition or a charm, drawn large enough to actually read as an object.
    // The same tables feed the list rows and the collection grid at a smaller
    // scale, so a thing looks identical wherever you meet it.

    // 7x6 portrait per structure id (0..Fa.B_N-1).
    function bldArt(dc, id, cx, cy, px) {
        var rows; var pal;
        id = Fa._c(id, 0, Fa.B_N - 1);
        if (id == Fa.B_COOP) {
            pal = { "a" => 0xC85A3A, "w" => 0xF0E0C0, "d" => 0x6A3A22, "c" => 0x8A5A3A, "y" => 0xFFD24A };
            rows = ["...y...", "..aaa..", ".aaaaa.", "cwwwwwc", "cwwdwwc", "ccwdwcc"];
        } else if (id == Fa.B_DUCK) {
            pal = { "w" => 0x4FB0E0, "l" => 0x7FD0F0, "y" => 0xF4D24A, "o" => 0xFF9A4A, "g" => 0x3E8E36 };
            rows = ["g.....g", "..y.y..", ".yoyyo.", "lwwwwwl", "wwwwwww", ".wwwww."];
        } else if (id == Fa.B_PIG) {
            pal = { "f" => 0xC8A06A, "m" => 0x8A5A34, "p" => 0xFF9AB0, "d" => 0xD07A90 };
            rows = ["f.....f", "fffffff", "..ppp..", ".ppppp.", "mdmmmdm", "mmmmmmm"];
        } else if (id == Fa.B_COW) {
            pal = { "r" => 0x8A2A2A, "b" => 0xD24A3A, "w" => 0xF0E0C0, "d" => 0x5A2A1A };
            rows = ["..rrr..", ".rrrrr.", "rrrrrrr", "bwbbbwb", "bbbdbbb", "bbbdbbb"];
        } else if (id == Fa.B_WHEAT) {
            pal = { "y" => 0xE8C24A, "h" => 0xFFE07A, "s" => 0x8A5A34 };
            rows = ["h.h.h.h", "yhyhyhy", "y.y.y.y", "y.y.y.y", "y.y.y.y", "sssssss"];
        } else if (id == Fa.B_CARROT) {
            pal = { "g" => 0x6FD06A, "o" => 0xFF9A4A, "s" => 0x8A5A34 };
            rows = ["g.g.g.g", "ggggggg", "sossoso", "sooosos", "ss.o.ss", "sssssss"];
        } else if (id == Fa.B_ORCHARD) {
            pal = { "f" => 0x3FA85A, "t" => 0x7A4A2A, "r" => 0xFF5A5A };
            rows = ["..fff..", ".fffff.", "frfffrf", ".fffff.", "...t...", "..ttt.."];
        } else if (id == Fa.B_BERRY) {
            pal = { "g" => 0x2E8C3C, "b" => 0xB46CFF };
            rows = ["b.g.g.b", ".ggggg.", "gbgggbg", "ggggggg", ".gbgbg.", "..ggg.."];
        } else if (id == Fa.B_STAND) {
            pal = { "r" => 0xE05A5A, "w" => 0xF4EAD0, "p" => 0x8A5A3A, "o" => 0xFF9A4A };
            rows = ["rwrwrwr", "wwwwwww", "p.....p", "p.ooo.p", "p.www.p", "p.....p"];
        } else if (id == Fa.B_WINDMILL) {
            pal = { "w" => 0xE8D8B0, "s" => 0x8A5A3A, "d" => 0xC8A070 };
            rows = ["s..s..s", ".s.s.s.", "..sss..", "..dwd..", "..dwd..", ".ddwdd."];
        } else if (id == Fa.B_BAKERY) {
            pal = { "b" => 0xC88A5A, "w" => 0xFFE7C0, "d" => 0x6A3A22, "h" => 0x8A5A3A, "s" => 0xD8D8D8 };
            rows = [".s.....", ".h.....", "bbbbbbb", "bwbbbwb", "bwbbbwb", "bbbdbbb"];
        } else if (id == Fa.B_PETZOO) {
            pal = { "p" => 0xFF7FA0, "y" => 0xFFD24A, "w" => 0xF4F4F4, "c" => 0x8A5A3A };
            rows = ["ypppppy", "y.....y", "y.w.w.y", "ywwwwwy", "c.....c", "ccccccc"];
        } else if (id == Fa.B_GOLDBARN) {
            pal = { "g" => 0xE0A82A, "G" => 0xFFD24A, "w" => 0xFFF0B0, "d" => 0x8A5A1A };
            rows = ["..ggg..", ".ggggg.", "ggggggg", "GwGGGwG", "GGGdGGG", "GGGdGGG"];
        } else if (id == Fa.B_GREENHSE) {
            pal = { "g" => 0xBFF0D0, "G" => 0xCFEFE0, "b" => 0x6FD06A, "w" => 0xFFFFFF };
            rows = ["..ggg..", ".ggwgg.", "GbGbGbG", "GbGbGbG", "GbGbGbG", "GGGGGGG"];
        } else if (id == Fa.B_PRIZEBULL) {
            pal = { "b" => 0x8A5A3A, "h" => 0xD8D0C0, "s" => 0xB0A890, "r" => 0xFF6A6A };
            rows = ["h.....h", ".bbbbb.", "rbbbbbr", ".bbbbb.", "..b.b..", "sssssss"];
        } else if (id == Fa.B_SILO) {
            pal = { "c" => 0xC0C6CC, "r" => 0xFF6A6A, "o" => 0xFF9A4A, "y" => 0xFFD24A,
                    "g" => 0x8CD060, "b" => 0x6FB3FF };
            rows = [".ccccc.", ".rrrrr.", ".ooooo.", ".yyyyy.", ".ggggg.", ".bbbbb."];
        } else if (id == Fa.B_ALPACA) {
            pal = { "f" => 0xE8D8B0, "l" => 0xC0A880, "e" => 0x8A6A4A, "c" => 0xC8A06A };
            rows = [".e...e.", ".fff...", "ffffff.", ".ffff..", ".l..l..", "ccccccc"];
        } else if (id == Fa.B_SUNFLR) {
            pal = { "y" => 0xFFD24A, "d" => 0x8A5A1A, "g" => 0x3E8E36 };
            rows = [".y...y.", "ydy.ydy", ".y...y.", "..ggg..", "..g.g..", "..g.g.."];
        } else if (id == Fa.B_CREAMRY) {
            pal = { "b" => 0x6FA8D0, "w" => 0xEAF2F0, "d" => 0x8A9AA0, "m" => 0xFFFFFF };
            rows = ["..bbb..", ".bbbbb.", "wwwwwww", "wmwdwmw", "wwwdwww", "wwwdwww"];
        } else if (id == Fa.B_CIDER) {
            pal = { "r" => 0x8A3A2A, "c" => 0xC86A3A, "w" => 0xFFD8A0, "d" => 0x5A2A1A, "a" => 0xFF5A5A };
            rows = ["..rrr..", ".rrrrr.", "ccwccwc", "ccccccc", "ccdccac", "cadccdc"];
        } else if (id == Fa.B_MOONBARN) {
            pal = { "s" => 0x6A7AB0, "b" => 0x9AB0FF, "w" => 0xEAF0FF, "d" => 0x3A4A7A };
            rows = ["..sss..", ".sssss.", "sssssss", "bwbbbwb", "bbbdbbb", "bbbdbbb"];
        } else if (id == Fa.B_HARVMOON) {
            pal = { "m" => 0xFFF3C4, "g" => 0xF0C860, "d" => 0xF0D890, "r" => 0x3FA85A };
            rows = ["..ggg..", ".gmmmg.", "gmmdmmg", ".gmmmg.", "..ggg..", "rrrrrrr"];
        } else {
            pal = { "w" => 0xF0E0C0, "d" => 0x8A5A3A };
            rows = ["..www..", ".wwwww.", "wwwwwww", "wwdddww", "wwdddww", "ddddddd"];
        }
        _sprC(dc, rows, pal, cx, cy, px);
    }

    // 7x6 scene per exploration area id (0..Fa.AR_N-1).
    function areaArt(dc, id, cx, cy, px) {
        var rows; var pal;
        id = Fa._c(id, 0, Fa.AR_N - 1);
        if (id == Fa.AR_MEADOW) {
            pal = { "g" => 0x6FD06A, "f" => 0xFF7FA0, "y" => 0xFFE24A, "d" => 0x3E8E36 };
            rows = ["f..y..f", ".g.g.g.", "y.g.g.y", ".g.g.g.", "ddddddd", "ddddddd"];
        } else if (id == Fa.AR_WOODS) {
            pal = { "f" => 0x2E7A3C, "t" => 0x6A4A2A, "l" => 0x3FA85A };
            rows = ["..fff..", ".fllff.", "fffffff", "..ttt..", "..ttt..", "ttttttt"];
        } else if (id == Fa.AR_POND) {
            pal = { "w" => 0x33C0FF, "l" => 0x8CE0FF, "r" => 0x3E8E36, "d" => 0x2A6A8A };
            rows = ["r.....r", "r.lll.r", ".wwwww.", "wwlwwww", "wwwwwlw", ".ddddd."];
        } else if (id == Fa.AR_HILLS) {
            pal = { "h" => 0xC9A24A, "g" => 0x6FD06A, "y" => 0xFFD24A, "s" => 0x8A6A3A };
            rows = ["...y...", "..ggg..", ".hhhhh.", "hhhhhhh", "shhhhhs", "sssssss"];
        } else if (id == Fa.AR_HOME) {
            pal = { "w" => 0xE0A860, "d" => 0x6A4A2A, "s" => 0x9A968C, "o" => 0xFF9A4A };
            rows = ["d.....d", ".ddddd.", "www.www", "wowd.ww", "wwwd.ww", "sssssss"];
        } else if (id == Fa.AR_VALE) {
            pal = { "y" => 0xFFD24A, "d" => 0x8A5A1A, "g" => 0x3E8E36, "s" => 0xFFE07A };
            rows = ["s.y.y.s", "ydyydyy", ".y.y.y.", "ggggggg", "..g.g..", "ggggggg"];
        } else if (id == Fa.AR_MILL) {
            pal = { "r" => 0x8A3A2A, "c" => 0xC86A3A, "w" => 0xFFD8A0, "a" => 0xFF5A5A };
            rows = ["..rrr..", ".rrrrr.", "ccwcwcc", "ccccccc", "a.ccc.a", "ccccccc"];
        } else if (id == Fa.AR_MARSH) {
            pal = { "m" => 0x7FA8A0, "w" => 0x8CE0FF, "r" => 0x4A6A58, "f" => 0xCFE8E4 };
            rows = ["r..w..r", "r.mwm.r", "rfmwmfr", "ffmmmff", "mmmmmmm", "rmrmrmr"];
        } else if (id == Fa.AR_RIDGE) {
            pal = { "m" => 0xFFF3C4, "b" => 0x9AB0FF, "k" => 0x3A4A7A, "s" => 0xEAF0FF };
            rows = ["s..m..s", ".mmmmm.", ".mmmmm.", "b..m..b", "kbbbbbk", "kkkkkkk"];
        } else {
            pal = { "g" => 0x6FD06A, "d" => 0x3E8E36 };
            rows = ["..ggg..", ".ggggg.", "ggggggg", "ddddddd", "ddddddd", "ddddddd"];
        }
        _sprC(dc, rows, pal, cx, cy, px);
    }

    // 6x6 portrait per charm id (0..Fa.C_N-1).
    function collArt(dc, id, cx, cy, px) {
        var rows; var pal;
        id = Fa._c(id, 0, Fa.C_N - 1);
        if (id == 0) {          // Flower Bed
            pal = { "r" => 0xFF9AC0, "y" => 0xFFE24A, "b" => 0x6FB3FF, "g" => 0x3E8E36, "s" => 0x8A5A34 };
            rows = ["r.y.b.", ".ggggg", "g.g.g.", ".ggggg", "ssssss", "ssssss"];
        } else if (id == 1) {   // Scarecrow
            pal = { "h" => 0xC9A24A, "s" => 0x8A5A3A, "k" => 0x2A2A2A };
            rows = ["..hh..", ".hkkh.", "ssssss", "..ss..", "..ss..", ".s..s."];
        } else if (id == 2) {   // Hay Bales
            pal = { "y" => 0xE8C24A, "d" => 0xC79A2A };
            rows = ["..yyy.", ".ydddy", ".ydydy", ".ydddy", "yyyy..", "ydyy.."];
        } else if (id == 3) {   // Golden Egg
            pal = { "g" => 0xFFD24A, "w" => 0xFFF6C8, "d" => 0xC79A2A };
            rows = ["..gg..", ".gwwg.", "gwggdg", "gwgggd", ".gdddg", "..gg.."];
        } else if (id == 4) {   // Pond Ducks
            pal = { "y" => 0x8CE0FF, "d" => 0xF4D24A, "o" => 0xFF9A4A, "w" => 0x33A0D0 };
            rows = [".d..d.", "ddo.dd", "yyyyyy", "wywyyw", "yywyyy", "wwwwww"];
        } else if (id == 5) {   // Rainbow Cow
            pal = { "r" => 0xFF6A6A, "w" => 0xF0F0F0, "o" => 0xFF9A4A, "b" => 0x6FB3FF,
                    "m" => 0xFF7FA0, "l" => 0x5A3A2A };
            rows = ["r....b", ".wwww.", "wowmbw", "wwwwww", ".w..w.", ".l..l."];
        } else if (id == 6) {   // Wishing Well
            pal = { "r" => 0x8A2A2A, "s" => 0x9FB0C0, "w" => 0x6FD0E0, "d" => 0x6A7A88 };
            rows = [".rrrr.", "rrrrrr", "s....s", "swwwws", "sdwwds", "ssssss"];
        } else if (id == 7) {   // Prize Ribbon
            pal = { "y" => 0xFFD24A, "r" => 0xFF6A6A, "w" => 0xFFF0B0 };
            rows = ["r....r", ".rrrr.", "rywwyr", ".ryyr.", ".y..y.", "y....y"];
        } else if (id == 8) {   // Harvest Feast
            pal = { "r" => 0xFF6A6A, "o" => 0xFF9A4A, "g" => 0x6FD06A, "w" => 0xF4EAD0, "b" => 0x8A5A3A };
            rows = [".r.o.g", "roogrr", "wwwwww", "wwwwww", ".b..b.", ".b..b."];
        } else if (id == 9) {   // Bee Hive
            pal = { "y" => 0xFFD86A, "d" => 0xC79A2A, "k" => 0x5A3A1A };
            rows = ["..yy..", ".ydddy", "yddddy", "yddkdy", ".ydddy", "..kk.."];
        } else if (id == 10) {  // Stone Bridge
            pal = { "s" => 0x9FB0C0, "d" => 0x6A7A88, "w" => 0x33C0FF };
            rows = [".ssss.", "ssddss", "sd..ds", "sd..ds", "wwwwww", "wwwwww"];
        } else if (id == 11) {  // Marsh Lantern
            pal = { "m" => 0x7FA8A0, "w" => 0x8CE0FF, "k" => 0x3A4A48, "f" => 0xEAFAFF };
            rows = ["..kk..", ".mmmm.", "mwffwm", "mwffwm", ".mmmm.", "..kk.."];
        } else if (id == 12) {  // Sun Crown
            pal = { "y" => 0xFFE24A, "o" => 0xFFA84A, "w" => 0xFFF6C8 };
            rows = ["y.y.y.", "yoyoyo", ".oooo.", "owwwwo", ".oooo.", "..oo.."];
        } else if (id == 13) {  // Moon Cart
            pal = { "w" => 0xEAF0FF, "p" => 0xB46CFF, "k" => 0x3A2A4A };
            rows = ["..ww..", ".pwwp.", "pppppp", "pkppkp", ".p..p.", "kk..kk"];
        } else {                // Golden Plow
            pal = { "g" => 0xFFD24A, "s" => 0x8A5A3A, "w" => 0xFFF0B0, "d" => 0x6A4A2A };
            rows = ["s.....", ".s....", ".sggg.", "..gwg.", "..ggg.", ".dd..."];
        }
        _sprC(dc, rows, pal, cx, cy, px);
    }
}
