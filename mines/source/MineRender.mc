// ═══════════════════════════════════════════════════════════════════════════
// MineRender.mc — Procedural underground cross-section + game icons.
//
// Everything is drawn from primitives (no sprites): a textured sky + headframe,
// stacked earth bands coloured per depth zone with embedded rock and twinkling
// ore/gems, a timbered central shaft with ladder rungs, a spinning pulley and an
// animated elevator cart positioned by your current depth. A small library of
// procedural icons (resources, buildings, pickaxe, cart, collectibles) lets the
// list/overview screens show pictures instead of bare text. Cheap to render,
// scales to any watch, and never divides by zero.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Lang;

module MineArt {

    // First zone that counts as "deep world" for the showpiece effects (the
    // old final zone, The Abyss). Keeps the aura/shimmer payoffs landing where
    // they always did now that five more zones sit below them.
    const MN_RICH_ZONE = 4;

    // ── Central mine cross-section ────────────────────────────────────────────
    function drawScene(dc, m, cx, cy, r, phase) {
        var top = cy - r;
        var bottom = cy + r;
        var w = r * 150 / 100;                 // a touch narrower than before
        var lx = cx - w / 2;
        var rx = cx + w / 2;
        var surfaceY = top + r * 20 / 100;
        var skyH = surfaceY - top;
        if (skyH < 2) { skyH = 2; }
        var clearW = r * 16 / 100;             // keep this band clear for the shaft

        // Sky (two soft bands + a couple of stars).
        dc.setColor(0x0E1A28, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx, top, w, skyH);
        dc.setColor(0x16283A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx, top + skyH / 2, w, skyH - skyH / 2);
        dc.setColor(0x4A6A88, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lx + w / 6, top + skyH / 3, 1);
        dc.fillCircle(lx + w * 5 / 6, top + skyH / 4, 1);
        // Ground line.
        dc.setColor(0x3A2E1E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx, surfaceY - 2, w, 3);

        // Earth bands per zone, with striations, embedded rock and ore.
        var reachedZone = Mn.zoneOf(m.depth);
        var bandH = (bottom - surfaceY) / Mn.Z_N;
        if (bandH < 4) { bandH = 4; }
        var span = (bandH > 3) ? (bandH - 2) : 1;
        for (var z = 0; z < Mn.Z_N; z++) {
            var by = surfaceY + z * bandH;
            if (by >= bottom) { break; }   // ten thin bands can outgrow the box
            dc.setColor(Mn.zColor(z), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lx, by, w, bandH + 1);
            dc.setColor(_darken(Mn.zColor(z)), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(lx, by, rx, by);
            // Embedded rocks.
            for (var rk = 0; rk < 3; rk++) {
                var rxp = lx + ((rk * 5197 + z * 911) % w);
                var ryp = by + ((rk * 331 + z * 137) % span) + 1;
                if (rxp > cx - clearW && rxp < cx + clearW) { continue; }
                dc.fillCircle(rxp, ryp, 1);
            }
            // Twinkling ore / gems (brighter once the zone is reached).
            if (z >= 1) {
                var sparks = z + 2; if (sparks > 5) { sparks = 5; }
                for (var s = 0; s < sparks; s++) {
                    var sx = lx + ((s * 6197 + z * 971) % w);
                    var sy = by + ((s * 3301 + z * 613) % span) + 1;
                    if (sx > cx - clearW && sx < cx + clearW) { continue; }
                    var col = (z >= 3 && (s % 2 == 0)) ? 0x5CF0EA : 0xFFC24A;
                    if (z > reachedZone) { col = _darken(col); }
                    dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                    var twinkle = ((phase / 6 + s * 3 + z * 7) % 5) != 0;
                    dc.fillCircle(sx, sy, twinkle ? ((z >= 3) ? 2 : 1) + 1 : 1);
                }
            }
        }

        // Timbered shaft with ladder rungs.
        var shaftW = r * 22 / 100;
        dc.setColor(0x080503, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - shaftW / 2, surfaceY, shaftW, bottom - surfaceY);
        dc.setColor(0x5A4428, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - shaftW / 2 - 1, surfaceY, 2, bottom - surfaceY);
        dc.fillRectangle(cx + shaftW / 2 - 1, surfaceY, 2, bottom - surfaceY);
        dc.setColor(0x3A2A1A, Graphics.COLOR_TRANSPARENT);
        var rung = surfaceY + 5;
        while (rung < bottom - 1) {
            dc.drawLine(cx - shaftW / 2 + 1, rung, cx + shaftW / 2 - 1, rung);
            rung += 6;
        }

        // Headframe (A-frame) + spinning pulley.
        var hfTop = surfaceY - r * 20 / 100;
        dc.setColor(0x9A7648, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - shaftW / 2, surfaceY, cx, hfTop);
        dc.drawLine(cx + shaftW / 2, surfaceY, cx, hfTop);
        dc.drawLine(cx - shaftW / 2, surfaceY, cx + shaftW / 2, surfaceY);
        dc.drawLine(cx - shaftW / 4, (surfaceY + hfTop) / 2, cx + shaftW / 4, (surfaceY + hfTop) / 2);
        dc.setColor(0xC8A24A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, hfTop, 3);
        dc.setColor(0x2A1E10, Graphics.COLOR_TRANSPARENT);
        var spin = (phase / 3) % 4;
        if (spin == 0) { dc.drawLine(cx - 3, hfTop, cx + 3, hfTop); }
        else if (spin == 1) { dc.drawLine(cx - 2, hfTop - 2, cx + 2, hfTop + 2); }
        else if (spin == 2) { dc.drawLine(cx, hfTop - 3, cx, hfTop + 3); }
        else { dc.drawLine(cx - 2, hfTop + 2, cx + 2, hfTop - 2); }

        // Elevator cart at current depth (gentle bob).
        var frac = depthFrac(m.depth);
        var travel = (bottom - surfaceY) - r * 16 / 100;
        if (travel < 0) { travel = 0; }
        var bob = (phase / 8) % 2;
        var cartY = surfaceY + travel * frac / 100 + 2 + bob;
        dc.setColor(0x7A6444, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, hfTop, cx, cartY);
        var cw = shaftW - 2;
        if (cw < 5) { cw = 5; }
        var chh = r * 13 / 100;
        if (chh < 6) { chh = 6; }
        dc.setColor(0xD79A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - cw / 2, cartY, cw, chh);
        dc.setColor(0x2A1E10, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(cx - cw / 2, cartY, cw, chh);
        dc.setColor(0xFFE27A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - cw / 6, cartY + 2, 1);
        dc.fillCircle(cx + cw / 6, cartY + 2, 1);
        dc.setColor(0x1A120A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - cw / 3, cartY + chh, 2);
        dc.fillCircle(cx + cw / 3, cartY + chh, 2);
    }

    // The visible shaft is not a fixed 1800m any more — it stretches to follow
    // the player, so the cart, strata and machines still read correctly at
    // 50000m. Floored at D_CAP_MIN so a fresh mine looks exactly as it always
    // did, and ceilinged so every `cap * pixels` product stays inside a Number.
    const D_CAP_MIN = 1800;
    const D_CAP_MAX = 240000;
    function depthCap(depth) {
        var c = depth;
        if (c < 0) { c = 0; }
        if (c > D_CAP_MAX) { c = D_CAP_MAX; }
        c = c * 12 / 10;
        if (c < D_CAP_MIN) { c = D_CAP_MIN; }
        if (c > D_CAP_MAX) { c = D_CAP_MAX; }
        return c;
    }

    // 0..100 fraction of the visible shaft for a given depth.
    function depthFrac(depth) {
        var d = depth;
        if (d < 0) { d = 0; }
        var cap = depthCap(d);
        if (d > cap) { d = cap; }
        return d * 100 / cap;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FULL PIXEL-ART MINE CROSS-SECTION  (the HOME/OVERVIEW star)
    //
    // Draws — from the surface down — a dusk sky, a chunky pixel HEADFRAME that
    // grows with the Elevator/Shaft, a rail with an animated ORE CART, miners,
    // then the shaft descending through zone-coloured EARTH LAYERS with embedded
    // machines, ore veins and twinkling gems. Everything is built from square
    // "pixels" so it reads as crisp retro art, and the whole scene visibly
    // deepens & fills as depth and buildings grow. Round-safe (clips to circle).
    // ═══════════════════════════════════════════════════════════════════════
    function drawMine(dc, m, sx, sy, sw, sh, phase, cx, cy, R) {
        var u = sw / 30;
        if (u < 7) { u = 7; }
        if (u > 15) { u = 15; }

        var surfaceH = sh * 32 / 100;
        var surfaceY = sy + surfaceH;
        var earthBot = sy + sh;
        var travel = earthBot - surfaceY;
        if (travel < u) { travel = u; }

        var cap = depthCap(m.depth);
        var reachedY = surfaceY + travel * depthFrac(m.depth) / 100;

        var shaftHalf = u;                     // shaft is ~2 pixels wide
        var clearW = shaftHalf + u;            // keep clear of central column

        // ── SKY (dusk gradient + stars + moon) ────────────────────────────────
        var skyN = surfaceH / u; if (skyN < 1) { skyN = 1; }
        for (var i = 0; i < skyN; i++) {
            var yy = sy + i * u;
            var col = _mix(0x101C34, 0x53324A, i * 100 / skyN);
            var lr = _clip(cx, cy, R, yy, u, sx, sw);
            if (lr[1] > lr[0]) { dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(lr[0], yy, lr[1] - lr[0], u + 1); }
        }
        // moon
        dc.setColor(0xF4E7C0, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx + sw * 30 / 100, sy + u, u, u);
        dc.fillRectangle(cx + sw * 30 / 100 + u, sy + u, u, u);
        // stars (fixed twinkle)
        var stx = [cx - sw * 34 / 100, cx - sw * 12 / 100, cx + sw * 8 / 100, cx + sw * 20 / 100];
        for (var s = 0; s < stx.size(); s++) {
            if (((phase / 8) + s) % 4 != 0) {
                dc.setColor(0xBFE0FF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(stx[s], sy + u + (s % 2) * u, u * 40 / 100 + 1, u * 40 / 100 + 1);
            }
        }

        // ── GROUND line ───────────────────────────────────────────────────────
        var gl = _clip(cx, cy, R, surfaceY - u, u, sx, sw);
        dc.setColor(0x4A6A3A, Graphics.COLOR_TRANSPARENT);
        if (gl[1] > gl[0]) { dc.fillRectangle(gl[0], surfaceY - u, gl[1] - gl[0], u); }
        var gl2 = _clip(cx, cy, R, surfaceY, u / 2 + 1, sx, sw);
        dc.setColor(0x35281A, Graphics.COLOR_TRANSPARENT);
        if (gl2[1] > gl2[0]) { dc.fillRectangle(gl2[0], surfaceY, gl2[1] - gl2[0], u / 2 + 1); }

        // ── EARTH LAYERS (chunky stripes, per-zone colour, deepen + enrich) ────
        // Each of the Mn.Z_N zones keeps its own base hue (Mn.zColor) so strata
        // read as visually distinct bands at a glance; a bright seam marks
        // every zone boundary once it's actually been dug, marbled veining
        // breaks up flat colour, and a travelling shimmer sweeps the two
        // richest zones so the deepest content is visibly the most alive.
        var rowIdx = 0;
        var prevZone = -1;
        var deepest = Mn.Z_N - 1;
        for (var yy2 = surfaceY; yy2 < earthBot; yy2 += u) {
            var mid = yy2 + u / 2;
            var dep = cap * (mid - surfaceY) / travel;
            var z = Mn.zoneOf(dep);
            var base = Mn.zColor(z);
            var col2 = _shade(base, 105 - dep * 45 / cap);   // deeper → darker
            var isReached = (yy2 < reachedY);
            if (!isReached) { col2 = _shade(col2, 48); }        // undug → muted
            else if (z >= deepest - 2) {                        // deepest three: violet pulse
                col2 = _mix(col2, 0xB46CFF, ((phase / 6) % 6 == 0) ? 26 : 9);
            }
            var lr2 = _clip(cx, cy, R, yy2, u, sx, sw);
            var newZone = (z != prevZone); prevZone = z;
            if (lr2[1] <= lr2[0]) { rowIdx++; continue; }
            dc.setColor(col2, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lr2[0], yy2, lr2[1] - lr2[0], u + 1);

            // Bright stratum seam at every dug zone boundary.
            if (newZone && isReached && rowIdx > 0) {
                dc.setColor(_mix(base, 0xFFFFFF, 40), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(lr2[0], yy2, lr2[1] - lr2[0], 1);
            }

            // rock speckle (2 per stripe), skip shaft column
            dc.setColor(_shade(col2, isReached ? 74 : 60), Graphics.COLOR_TRANSPARENT);
            for (var rk = 0; rk < 2; rk++) {
                var rxp = lr2[0] + ((rowIdx * 37 + rk * 53 + z * 17) % ((lr2[1] - lr2[0]) | 1));
                if (rxp > cx - clearW && rxp < cx + clearW) { continue; }
                dc.fillRectangle(rxp, yy2 + (rk * u / 2), u * 55 / 100 + 1, u * 55 / 100 + 1);
            }

            // Marbled mineral veining — a little tinted fleck every 3rd dug row
            // so each stratum reads as richly textured rock, not a flat fill.
            if (isReached && (rowIdx % 3 == 0)) {
                var vx = lr2[0] + ((rowIdx * 83 + z * 19) % ((lr2[1] - lr2[0]) | 1));
                if (!(vx > cx - clearW && vx < cx + clearW)) {
                    dc.setColor(_mix(col2, base, 55), Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(vx, yy2 + u / 4, u * 70 / 100 + 1, u * 35 / 100 + 1);
                }
            }

            // Travelling shimmer sweep in the rich lower half of the world — a
            // quick glinting flourish tied to the phase counter, distinct from
            // the per-nugget twinkle below.
            if (isReached && z >= MN_RICH_ZONE) {
                var sweepSpan = lr2[1] - lr2[0]; if (sweepSpan < 2) { sweepSpan = 2; }
                var sweepX = lr2[0] + ((phase * 2 + rowIdx * 13) % sweepSpan);
                if (!(sweepX > cx - clearW && sweepX < cx + clearW)) {
                    dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(sweepX, yy2 + u / 3, 1, u / 3 + 1);
                }
            }

            // Embedded ore/gem nuggets — distinct pixel sprite per resource type,
            // coloured straight from MnConst so the wall reads as real currency,
            // once that stripe has actually been dug.
            if (isReached) {
                var gx = lr2[0] + ((rowIdx * 61 + z * 29) % ((lr2[1] - lr2[0]) | 1));
                if (!(gx > cx - clearW && gx < cx + clearW)) {
                    var rId = _pickOreRes(z, rowIdx * 7 + z * 13);
                    var tw = ((phase / 5 + rowIdx * 3 + z) % 5) != 0;
                    var gpx = u * 40 / 100; if (gpx < 2) { gpx = 2; }
                    _oreSprite(dc, rId, gx - gpx, mid - gpx, gpx, tw);
                }
            }
            rowIdx++;
        }

        // ── ORE VEINS + CRYSTAL GEODES threading the dug rock ──────────────────
        try { _oreVeins(dc, m, cx, cy, R, sx, sw, surfaceY, reachedY, travel, u, clearW, phase); } catch (e) {}
        try { _crystalGeodes(dc, m, cx, cy, R, sx, sw, surfaceY, reachedY, travel, shaftHalf, u, clearW, phase); } catch (e) {}

        // ── SHAFT (dark timbered column + ladder rungs) ────────────────────────
        dc.setColor(0x0A0704, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - shaftHalf, surfaceY, shaftHalf * 2, earthBot - surfaceY);
        dc.setColor(0x5A4326, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - shaftHalf, surfaceY, u * 35 / 100 + 1, earthBot - surfaceY);
        dc.fillRectangle(cx + shaftHalf - (u * 35 / 100 + 1), surfaceY, u * 35 / 100 + 1, earthBot - surfaceY);
        dc.setColor(0x3A2A18, Graphics.COLOR_TRANSPARENT);
        var rung = surfaceY + u;
        while (rung < earthBot - 1) {
            dc.fillRectangle(cx - shaftHalf + u / 3, rung, shaftHalf * 2 - u * 2 / 3, u * 30 / 100 + 1);
            rung += u * 3 / 2;
        }

        // ── TIMBER SUPPORT BEAMS + LANTERN GLOW bracing the dug shaft ──────────
        try { _supportBeams(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase); } catch (e) {}
        try { _lanterns(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase); } catch (e) {}

        // ── ABYSS AURA — a pulsing violet glow, the biggest "wow" payoff once
        // the deepest zone has actually been reached ────────────────────────
        try { _abyssAura(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase); } catch (e) {}

        // ── EMBEDDED MACHINES on the shaft walls (appear/grow with bLevel) ────
        // Spaced by SLOT down the dug section rather than by absolute depth:
        // once the shaft covers 50km, an absolute 60m/520m placement would pile
        // every machine into the topmost pixel row.
        _machine(dc, m, Mn.B_FORGE,   0, 6, surfaceY, cx, shaftHalf, u, reachedY, phase);
        _machine(dc, m, Mn.B_GEMWS,   1, 6, surfaceY, cx, shaftHalf, u, reachedY, phase);
        _machine(dc, m, Mn.B_LAB,     2, 6, surfaceY, cx, shaftHalf, u, reachedY, phase);
        _machine(dc, m, Mn.B_SCANNER, 3, 6, surfaceY, cx, shaftHalf, u, reachedY, phase);
        _machine(dc, m, Mn.B_RIG,     4, 6, surfaceY, cx, shaftHalf, u, reachedY, phase);
        _machine(dc, m, Mn.B_BORE,    5, 6, surfaceY, cx, shaftHalf, u, reachedY, phase);

        // ── COLLECTED ITEMS glinting in the walls — the whole dig history ──────
        _collScatter(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase);

        // ── EXTRA MINERS at depth — more workers show up down the shaft too ────
        _deepMiners(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase);

        // ── FALLING DUST motes drifting down the open shaft ────────────────────
        try { _dustFall(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase); } catch (e) {}

        // ── ELEVATOR CAR riding the shaft to your current depth ────────────────
        var carY = surfaceY + (reachedY - surfaceY) - u * 2;
        if (carY < surfaceY + u) { carY = surfaceY + u; }
        if (carY > earthBot - u * 2) { carY = earthBot - u * 2; }
        var bob = (phase / 8) % 2;
        carY += bob;
        dc.setColor(0x7A6444, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 1, surfaceY, 2, carY - surfaceY);   // hoist cable
        var wheelSpin = ((phase / 3) % 2 == 0) ? 0x2A1E10 : 0x4A3620;   // spin flicker
        var carPal = { "C" => 0xD79A2A, "K" => wheelSpin, "L" => 0xFFE27A };
        var carSpr = ["CCCC", "CLLC", "CCCC", "K..K"];
        Px.spr(dc, carSpr, carPal, cx - u * 2, carY, u, false);

        // ── SURFACE STRUCTURES ─────────────────────────────────────────────────
        _headframe(dc, m, cx, sy, surfaceY, u, phase);
        _miners(dc, m, cx, surfaceY, shaftHalf, u, phase);
        _oreCart(dc, m, cx, surfaceY, sw, u, phase, cx, cy, R);
    }

    // Chunky headframe / pit-head. It literally grows taller as you upgrade the
    // Elevator + Shaft, while always fitting inside the surface strip.
    function _headframe(dc, m, cx, topY, surfaceY, u, phase) {
        var lvl = m.bLevel[Mn.B_ELEVATOR] + m.bLevel[Mn.B_SHAFT];
        if (lvl > 6) { lvl = 6; }
        var rows = 6;
        var maxH = surfaceY - topY - 2; if (maxH < rows * 3) { maxH = rows * 3; }
        var hh = maxH * (58 + lvl * 7) / 100;   // taller with progress
        var hpx = hh / rows; if (hpx < 3) { hpx = 3; }
        var pal = { "T" => 0x9A7648, "W" => 0xC8A24A, "C" => 0xFFE27A };
        var spr = [
            ".WWW.",
            "W.C.W",
            ".WWW.",
            ".T.T.",
            "T...T",
            "T...T"
        ];
        var sw2 = 5 * hpx;
        var oy = surfaceY - rows * hpx;
        Px.spr(dc, spr, pal, cx - sw2 / 2, oy, hpx, false);
        // spinning pulley marker
        dc.setColor(0x2A1E10, Graphics.COLOR_TRANSPARENT);
        var spin = (phase / 3) % 4;
        var pcy = oy + hpx + hpx / 2;
        if (spin == 0) { dc.fillRectangle(cx - hpx, pcy, hpx * 2, 1); }
        else if (spin == 2) { dc.fillRectangle(cx, pcy - hpx, 1, hpx * 2); }
        // warning beacon once the headframe is tall
        if (lvl >= 4 && (phase / 6) % 2 == 0) {
            dc.setColor(0xFF5A3A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - hpx / 2, oy - hpx, hpx, hpx);
        }
    }

    // Ore cart shuttling on a surface rail; body scales with cart tier.
    function _oreCart(dc, m, cx, surfaceY, sw, u, phase, ccx, ccy, R) {
        var railLine = surfaceY - u;
        var half = sw * 22 / 100;
        var lr = _clip(ccx, ccy, R, railLine, u, cx - half, half * 2);
        if (lr[1] <= lr[0]) { return; }
        // ties then rail
        dc.setColor(0x4A3826, Graphics.COLOR_TRANSPARENT);
        var tx = lr[0];
        while (tx < lr[1]) { dc.fillRectangle(tx, railLine, u * 25 / 100 + 1, u * 55 / 100); tx += u; }
        dc.setColor(0x6A5238, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lr[0], railLine, lr[1] - lr[0], u * 28 / 100 + 1);

        // shuttle position (ping-pong)
        var span = (lr[1] - lr[0]) - u * 5; if (span < 0) { span = 0; }
        var p = (phase / 3) % (2 * (span + 1));
        var off = (p <= span) ? p : (2 * span - p);
        var carx = lr[0] + off;
        var tier = m.cartTier;
        var body = _cartColor(tier);
        var wheelSpin = ((phase / 2) % 2 == 0) ? 0x1A120A : 0x3A2A18;   // spin flicker
        var pal = { "C" => body, "O" => 0xFFC24A, "G" => 0x5CF0EA, "K" => wheelSpin };
        var spr = (tier >= 1)
            ? ["OGO..", "CCCCC", "CCCCC", "K.K.."]
            : [".O...", "CCCC.", "CCCC.", "K.K.."];
        Px.spr(dc, spr, pal, carx, railLine - u * 3, u, false);
    }

    // A machine sprite embedded in a shaft wall, at slot `slot` of `nSlots`
    // evenly spaced down the section of shaft that has actually been dug.
    function _machine(dc, m, id, slot, nSlots, surfaceY, cx, shaftHalf, u, reachedY, phase) {
        var lvl = m.bLevel[Mn._c(id, 0, Mn.B_N - 1)];
        if (lvl <= 0) { return; }
        if (nSlots < 1) { nSlots = 1; }
        var span = reachedY - surfaceY;
        if (span < u * 4) { return; }
        var y = surfaceY + span * (slot + 1) / (nSlots + 1);
        if (y < surfaceY + u) { y = surfaceY + u; }
        var left = (slot % 2 == 1);   // alternate walls
        var mpx = u * 80 / 100; if (mpx < 5) { mpx = 5; }
        var spr; var pal;
        if (id == Mn.B_FORGE) {
            pal = { "B" => 0x8A5A3A, "F" => 0xFF7A3A, "O" => 0xFFD24A };
            spr = [".F.F.", "BBBBB", "B.O.B", "BBBBB"];
        } else if (id == Mn.B_LAB) {
            pal = { "G" => 0xCFE6F2, "L" => 0x4CE0C0 };
            spr = ["..G..", ".GGG.", ".GLG.", ".GGG."];
        } else if (id == Mn.B_GEMWS) {
            pal = { "M" => 0x4CE6E0, "W" => 0xE8FBFA };
            spr = ["..M..", ".MWM.", "MMMMM", ".MMM."];
        } else if (id == Mn.B_RIG) {         // hydraulic piston bracing the wall
            var ext = ((phase / 6) % 2 == 0);
            pal = { "S" => 0x8A6A5A, "P" => 0xE05A3A, "H" => 0xFFC0A0 };
            spr = ext ? ["SSSSS", "S.P.S", "SPPPS", "SSHSS"]
                      : ["SSSSS", "SPPPS", "S.P.S", "SSHSS"];
        } else if (id == Mn.B_BORE) {        // quantum bore: spinning drill head
            var hot = ((phase / 4) % 2 == 0) ? 0xFFFFFF : 0x7AF0FF;
            pal = { "Q" => 0x2A6A7A, "C" => 0x7AF0FF, "W" => hot };
            spr = ["QQQQ.", "QCCCW", "QQQQ.", ".W..."];
        } else {   // SCANNER: dish + sweeping beam
            var bc = ((phase / 5) % 2 == 0) ? 0xE0C0FF : 0xB46CFF;
            pal = { "D" => 0x7A5AA0, "B" => bc };
            spr = ["B....", ".B...", "..DDD", ".DDDD"];
        }
        var wpx = 5 * mpx;
        var ox = left ? (cx - shaftHalf - wpx - 1) : (cx + shaftHalf + 1);
        Px.spr(dc, spr, pal, ox, y, mpx, left);
        // level pips
        dc.setColor(0xFFE0B0, Graphics.COLOR_TRANSPARENT);
        var pips = lvl; if (pips > 4) { pips = 4; }
        for (var p = 0; p < pips; p++) {
            dc.fillRectangle(ox + p * (mpx + 1), y - mpx - 1, mpx * 70 / 100 + 1, mpx * 70 / 100 + 1);
        }
    }

    // Weighted pick of a resource to embed at this zone, using the same
    // [stone, iron, gold, gem] weights that drive actual yield — so the wall
    // visibly matches what you're really pulling out of the ground here.
    function _pickOreRes(z, seed) {
        var sumw = 0;
        for (var k = 0; k < Mn.R_N; k++) { sumw += Mn.zWeight(z, k); }
        if (sumw <= 0) { return Mn.R_STONE; }
        var t = seed % sumw; if (t < 0) { t = -t; }
        var acc = 0;
        for (var k = 0; k < Mn.R_N; k++) {
            acc += Mn.zWeight(z, k);
            if (t < acc) { return k; }
        }
        return Mn.R_STONE;
    }

    // A tiny nugget/crystal sprite for one resource, coloured straight from
    // Mn.resColor so the embedded ore always matches the HUD currency chips.
    function _oreSprite(dc, r, ox, oy, px, glint) {
        var col = Mn.resColor(r);
        var spr; var pal;
        if (r == Mn.R_STONE) {
            pal = { "S" => col, "D" => _shade(col, 65) };
            spr = [".S.", "SDS", ".S."];
        } else if (r == Mn.R_IRON) {
            pal = { "I" => col, "L" => glint ? 0xFFFFFF : 0xEDEFF3 };
            spr = ["III", "ILI", "III"];
        } else if (r == Mn.R_GOLD) {
            pal = { "G" => col, "H" => glint ? 0xFFFFFF : 0xFFF0B0 };
            spr = [".G.", "GHG", ".G."];
        } else {
            pal = { "M" => col, "W" => glint ? 0xFFFFFF : 0xE8FBFA };
            spr = ["M.M", ".W.", "M.M"];
        }
        Px.spr(dc, spr, pal, ox, oy, px, false);
    }

    // Small distinct icon per owned collectible (rough shape hints at the
    // name), used both embedded in the mine walls and could double for UI.
    function _collIcon(dc, id, ox, oy, px, glint) {
        var spr; var pal;
        var w = glint ? 0xFFFFFF : null;
        if (id == 0) {          // Coal
            pal = { "K" => 0x1A1610, "G" => (w != null) ? w : 0x4A4030 };
            spr = [".KK.", "KKKK", ".KG."];
        } else if (id == 1) {   // Fossil
            pal = { "B" => 0xD8C9A0, "S" => (w != null) ? w : 0x8A7A5A };
            spr = [".BB.", "BSSB", ".BB."];
        } else if (id == 2) {   // Gold Nugget
            pal = { "G" => 0xFFC24A, "H" => (w != null) ? w : 0xFFF0B0 };
            spr = [".GG.", "GGGH", ".GG."];
        } else if (id == 3) {   // Crystal
            pal = { "C" => 0x4CE6E0, "W" => (w != null) ? w : 0xE8FBFA };
            spr = ["..C.", ".CWC", "..C."];
        } else if (id == 4) {   // Meteorite
            pal = { "R" => 0x8A5A3A, "O" => (w != null) ? w : 0xFF7A3A };
            spr = [".RR.", "RRRO", ".RR."];
        } else if (id == 5) {   // Ancient Tool
            pal = { "T" => 0x9A8A6A, "K" => (w != null) ? w : 0x4A3A22 };
            spr = ["K...", "KTT.", ".TT."];
        } else if (id == 6) {   // Diamond
            pal = { "D" => 0xCFE9FF, "W" => (w != null) ? w : 0xFFFFFF };
            spr = ["..D.", ".DWD", "..D."];
        } else if (id == 7) {   // Lost Machine
            pal = { "M" => 0x8CC0FF, "K" => (w != null) ? w : 0x2A2A2A };
            spr = ["MKM.", "KMMK", "MKM."];
        } else if (id == 8) {   // Rare Relic
            pal = { "P" => 0x8C6CFF, "Y" => (w != null) ? w : 0xFFD24A };
            spr = [".PP.", "PYYP", ".PP."];
        } else if (id == 9) {   // Golden Skull
            pal = { "G" => 0xFFD24A, "K" => (w != null) ? w : 0x2A2010 };
            spr = [".GG.", "GKGK", ".GG."];
        } else if (id == 10) {  // Ancient Core
            pal = { "P" => 0xB46CFF, "W" => (w != null) ? w : 0xEFE0FF };
            spr = [".PP.", "PWWP", ".PP."];
        } else if (id == 11) {  // Unknown Crystal
            pal = { "M" => 0xFF5AC0, "W" => (w != null) ? w : 0xFFE0F4 };
            spr = ["..M.", ".MWM", "..M."];
        } else {
            // Generic fallback for every appended collectible: a shard tinted
            // by its rarity, so growing C_N never draws an empty hole.
            var rc = Mn.rarityColor(Mn.cRarity(id));
            pal = { "C" => rc, "W" => (w != null) ? w : 0xFFFFFF };
            spr = [".CC.", "CWWC", ".CC."];
        }
        Px.spr(dc, spr, pal, ox, oy, px, false);
    }

    // Every collectible you've ever found stays glinting in the wall so the
    // whole dig history is visible at a glance, not buried in a menu.
    function _collScatter(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase) {
        var dugRows = (reachedY - surfaceY) / u;
        if (dugRows < 1) { return; }
        var ipx = u * 55 / 100; if (ipx < 3) { ipx = 3; }
        for (var i = 0; i < Mn.C_N; i++) {
            if (!m.hasColl(i)) { continue; }
            var rowIdx = (i * 47 + 11) % dugRows;
            var y = surfaceY + rowIdx * u + u / 2;
            var side = (i % 2 == 0) ? -1 : 1;
            var slot = (i / 2) % 3;
            var x = cx + side * (shaftHalf + u * (3 + slot));
            var tw = ((phase / 6 + i * 3) % 6) == 0;
            _collIcon(dc, i, x - ipx, y - ipx, ipx, tw);
        }
    }

    // A little crew on the surface; one swings a pickaxe (dust puffs). The
    // pick's colour reflects the equipped tier so equipment upgrades read
    // visually, not just in a menu.
    // One colour per pickaxe tier — must stay Mn.PICK_N long so every tier
    // renders as its own thing instead of silently reusing the last entry.
    function _pickColor(tier) {
        var a = [0x9A7648, 0xB8B8B8, 0x8CE0FF, 0x8C6CFF, 0x5CF0EA,
                 0xFF7A3A, 0xFFFFFF, 0xB46CFF, 0xFFD24A];
        return a[Mn._c(tier, 0, a.size() - 1)];
    }
    // One colour per cart tier (Mn.CART_N long); the sprite itself is reused
    // from the highest hand-drawn body and just re-tinted.
    function _cartColor(tier) {
        var a = [0xC98A4A, 0x8CC0FF, 0x4CE0C0, 0xB46CFF, 0xFFD24A, 0xFF5AC0];
        return a[Mn._c(tier, 0, a.size() - 1)];
    }
    function _miners(dc, m, cx, surfaceY, shaftHalf, u, phase) {
        var n = m.workers(); if (n > 5) { n = 5; }
        var pal = { "H" => 0xE7B48A, "B" => 0x3A6AC0, "L" => 0x2A2018, "P" => 0xB8B8B8 };
        var miner = [".H.", "BBB", "L.L"];
        var pcol = _pickColor(m.pickTier);
        for (var k = 0; k < n; k++) {
            var side = (k % 2 == 0) ? -1 : 1;
            var slot = (k / 2) + 1;
            var mx = cx + side * (shaftHalf + slot * u * 3);
            var my = surfaceY - u * 3;
            Px.spr(dc, miner, pal, mx, my, u, side < 0);
            if (k == 0) {   // swinger + dust
                var swing = (phase / 4) % 2;
                dc.setColor(pcol, Graphics.COLOR_TRANSPARENT);
                if (swing == 0) { dc.fillRectangle(mx - u, my - u, u, u); }
                else {
                    dc.fillRectangle(mx - u, my + u, u, u);
                    dc.setColor(0xC9B79A, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(mx - u * 2, my + u * 2, u * 60 / 100 + 1, u * 60 / 100 + 1);
                }
            }
        }
    }

    // A few extra miners posted down in the already-dug shaft — count scales
    // with the Miner Camp level so a bigger crew is visible at DEPTH too, not
    // only at the surface.
    function _deepMiners(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase) {
        var crew = m.bLevel[Mn.B_CAMP]; if (crew > 4) { crew = 4; }
        if (crew <= 0) { return; }
        var span = reachedY - surfaceY; if (span < u * 3) { return; }
        var pal = { "H" => 0xE7B48A, "B" => 0x6AA03A, "L" => 0x2A2018 };
        var miner = [".H.", "BBB", "L.L"];
        var mpx = u * 75 / 100; if (mpx < 4) { mpx = 4; }
        for (var k = 0; k < crew; k++) {
            var frac = (k + 1) * 100 / (crew + 1);
            var my = surfaceY + span * frac / 100;
            var side = (k % 2 == 0) ? -1 : 1;
            var mx = cx + side * (shaftHalf + u * 2);
            var bob = ((phase / 7 + k * 3) % 4 < 2) ? 0 : 1;
            Px.spr(dc, miner, pal, mx, my + bob, mpx, side < 0);
        }
    }

    // Diagonal ORE VEINS threading through the already-dug rock. More veins and
    // richer ore appear as you reach deeper zones, so the wall visibly glitters
    // with what you actually mine there. Skips the shaft column and clips round.
    function _oreVeins(dc, m, cx, cy, R, sx, sw, surfaceY, reachedY, travel, u, clearW, phase) {
        var span = reachedY - surfaceY;
        if (span < u * 3 || travel <= 0) { return; }
        var reachedZone = Mn.zoneOf(m.depth);
        var veins = 3 + reachedZone * 2; if (veins > 12) { veins = 12; }
        var vpx = u * 45 / 100; if (vpx < 2) { vpx = 2; }
        for (var v = 0; v < veins; v++) {
            var baseY = surfaceY + ((v * 6151 + 97) % span);
            var dep = depthCap(m.depth) * (baseY - surfaceY) / travel;
            var z = Mn.zoneOf(dep);
            var col = Mn.resColor(_pickOreRes(z, v * 17 + z * 5));
            var side = (v % 2 == 0) ? -1 : 1;
            var vx = cx + side * (clearW + ((v * 53) % (sw / 3 + 1)));
            var len = 3 + (v % 4);
            var dir = (v % 3 == 0) ? 1 : -1;
            var glint = ((phase / 6 + v) % 4) == 0;
            for (var k = 0; k < len; k++) {
                var px2 = vx + dir * k * vpx;
                var py2 = baseY + k * vpx;
                if (py2 > reachedY) { break; }
                if (px2 > cx - clearW && px2 < cx + clearW) { continue; }
                var lr = _clip(cx, cy, R, py2, vpx, sx, sw);
                if (px2 < lr[0] || px2 + vpx > lr[1]) { continue; }
                dc.setColor((glint && k == 0) ? 0xFFFFFF : col, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(px2, py2, vpx + 1, vpx + 1);
            }
        }
    }

    // Big crystal GEODES embedded in the deepest reached zones — a payoff that
    // only shows up once you have actually dug into the rich lower world.
    function _crystalGeodes(dc, m, cx, cy, R, sx, sw, surfaceY, reachedY, travel, shaftHalf, u, clearW, phase) {
        var reachedZone = Mn.zoneOf(m.depth);
        if (reachedZone < 2 || travel <= 0) { return; }
        var geo = [".CWC.", "CWWWC", "CWCWC", ".CDC.", "..D.."];
        var count = reachedZone - 1; if (count > 3) { count = 3; }
        var extra = (reachedZone >= Mn.Z_N - 1) ? 1 : 0;   // the last zone earns a bonus geode
        var gpx = u * 45 / 100; if (gpx < 2) { gpx = 2; }
        var cap = depthCap(m.depth);
        for (var k = 0; k < count + extra; k++) {
            var z = (k < count) ? (2 + k) : (Mn.Z_N - 1);
            var depOff = (k < count) ? 30 : 220;   // bonus one sits deeper in its band
            var y = surfaceY + travel * (Mn.zoneMin(z) + depOff) / cap;
            if (y > reachedY - u) { continue; }
            var side = (k % 2 == 0) ? 1 : -1;
            var gx = cx + side * (clearW + u * 2);
            var lr = _clip(cx, cy, R, y, gpx * 5, sx, sw);
            if (gx < lr[0] || gx + gpx * 5 > lr[1]) { continue; }
            var tw = ((phase / 6 + k) % 3) != 0;
            var pal = tw
                ? { "C" => 0x4CE6E0, "W" => 0xE8FBFA, "D" => 0x2A6A78 }
                : { "C" => 0x3AB0AC, "W" => 0xBFE0DE, "D" => 0x225A66 };
            Px.spr(dc, geo, pal, gx, y, gpx, side < 0);
        }
    }

    // Horizontal timber SUPPORT BEAMS bracing the open shaft at intervals with
    // dark bolts, only across the section that has actually been dug.
    function _supportBeams(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase) {
        var y = surfaceY + u * 3;
        var gap = u * 4; if (gap < u) { gap = u; }
        var beamH = u * 45 / 100 + 1;
        while (y < reachedY - u) {
            dc.setColor(0x6A4E2C, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - shaftHalf - u, y, shaftHalf * 2 + u * 2, beamH);
            dc.setColor(0x3A2A16, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - shaftHalf - u, y + beamH, shaftHalf * 2 + u * 2, 1);
            dc.setColor(0x241708, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - shaftHalf, y, 1, beamH);
            dc.fillRectangle(cx + shaftHalf - 1, y, 1, beamH);
            y += gap;
        }
    }

    // Warm LANTERNS hung along the dug shaft, each with a gentle pendulum
    // swing and a soft breathing glow halo, so the tunnel reads as lived-in
    // and lit rather than a black void.
    function _lanterns(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase) {
        var span = reachedY - surfaceY;
        if (span < u * 4) { return; }
        var n = span / (u * 6); if (n < 1) { n = 1; } if (n > 5) { n = 5; }
        for (var k = 0; k < n; k++) {
            var ly = surfaceY + u * 4 + k * (u * 6);
            if (ly > reachedY - u) { break; }
            var side = (k % 2 == 0) ? -1 : 1;
            var swingPh = (phase / 6 + k * 5) % 8;
            var sway = (swingPh < 4) ? (swingPh - 2) : (6 - swingPh);   // -2..1 pendulum
            var lx = cx + side * (shaftHalf - u * 30 / 100) + sway;
            var flick = ((phase / 5 + k) % 7) != 0;
            var breathe = ((phase / 4 + k * 3) % 6) >= 3;
            if (flick) {
                var glowR = u + (breathe ? u / 3 : 0);
                dc.setColor(0x2A1C08, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(lx - glowR, ly - glowR, glowR * 2 + 1, glowR * 2 + 1);
                dc.setColor(0x4A3410, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(lx - u, ly - u, u * 2 + 1, u * 2 + 1);
            }
            dc.setColor(flick ? 0xFFD24A : 0xC88A2A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lx - u * 30 / 100, ly - u * 30 / 100, u * 60 / 100 + 1, u * 60 / 100 + 1);
            dc.setColor(flick ? 0xFFF4C0 : 0xE0A030, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lx, ly, u * 30 / 100 + 1, u * 30 / 100 + 1);
        }
    }

    // A slow pulsing violet aura along the deepest dug wall — the biggest
    // visual "wow" payoff, appearing only once the Abyss (the final zone)
    // has actually been reached, so the richest content is unmistakably the
    // most spectacular on screen.
    function _abyssAura(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase) {
        if (Mn.zoneOf(m.depth) < MN_RICH_ZONE) { return; }
        var pulse = (phase / 4) % 8;
        var amp = (pulse < 4) ? pulse : (8 - pulse);   // 0..3..0 triangle wave
        var glowR = shaftHalf + u * 2 + amp;
        var y = reachedY - u; if (y < surfaceY) { y = surfaceY; }
        dc.setColor((amp >= 2) ? 0xB46CFF : 0x7A4CB0, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - glowR, y - u / 3, glowR * 2, u / 3 + 1);
        for (var s = 0; s < 3; s++) {
            var side = (s % 2 == 0) ? -1 : 1;
            var sx2 = cx + side * (glowR - s * u);
            var sy2 = y - u * s / 2;
            dc.setColor(0xE8D0FF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx2, sy2, 1);
        }
    }

    // Falling DUST motes drifting down the open shaft, animated off the phase
    // counter so the scene always feels alive even while idle.
    function _dustFall(dc, m, cx, surfaceY, reachedY, shaftHalf, u, phase) {
        var span = reachedY - surfaceY;
        if (span < u * 2) { return; }
        var dpx = u * 22 / 100 + 1;
        for (var k = 0; k < 5; k++) {
            var fx = cx - shaftHalf + ((k * 37 + 3) % (shaftHalf * 2 - 1 > 1 ? shaftHalf * 2 - 1 : 1));
            var prog = (phase * (2 + k % 3) + k * 61) % span;
            var fy = surfaceY + prog;
            dc.setColor((k % 2 == 0) ? 0x8A7A5A : 0xC9B79A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx, fy, dpx, dpx);
        }
    }

    // ── colour helpers ────────────────────────────────────────────────────────
    function _mix(c0, c1, t) {
        if (t < 0) { t = 0; } if (t > 100) { t = 100; }
        var r0 = (c0 >> 16) & 0xFF, g0 = (c0 >> 8) & 0xFF, b0 = c0 & 0xFF;
        var r1 = (c1 >> 16) & 0xFF, g1 = (c1 >> 8) & 0xFF, b1 = c1 & 0xFF;
        var rr = (r0 * (100 - t) + r1 * t) / 100;
        var gg = (g0 * (100 - t) + g1 * t) / 100;
        var bb = (b0 * (100 - t) + b1 * t) / 100;
        return (rr << 16) | (gg << 8) | bb;
    }
    function _shade(c, pct) {
        if (pct < 0) { pct = 0; }
        var r = ((c >> 16) & 0xFF) * pct / 100; if (r > 255) { r = 255; }
        var g = ((c >> 8) & 0xFF) * pct / 100;  if (g > 255) { g = 255; }
        var b = (c & 0xFF) * pct / 100;         if (b > 255) { b = 255; }
        return (r << 16) | (g << 8) | b;
    }
    // Left/right x-bounds for a stripe, clipped to the watch circle (R>0) and
    // to the [sx, sx+sw] scene box. Never pokes outside the round bezel.
    function _clip(cx, cy, R, yy, hpx, sx, sw) {
        var l = sx; var r = sx + sw;
        if (R > 0) {
            var d1 = yy - cy; if (d1 < 0) { d1 = -d1; }
            var d2 = (yy + hpx) - cy; if (d2 < 0) { d2 = -d2; }
            var dm = (d1 > d2) ? d1 : d2;
            var v = (R - 1) * (R - 1) - dm * dm;
            if (v <= 0) { return [cx, cx]; }
            var half = Math.sqrt(v).toNumber();
            if (cx - half > l) { l = cx - half; }
            if (cx + half < r) { r = cx + half; }
        }
        return [l, r];
    }

    // ── Icons (all centred at cx,cy, roughly radius s) ────────────────────────
    // Same chunky pixel nugget used embedded in the mine walls, so the HUD
    // currency chips visually match what you actually dig up.
    function resIcon(dc, cx, cy, s, i) {
        var px = s * 2 / 3; if (px < 2) { px = 2; }
        _oreSprite(dc, i, cx - px * 3 / 2, cy - px * 3 / 2, px, false);
    }

    // Building glyph on a coloured disc.
    function buildingIcon(dc, cx, cy, s, i) {
        var col = Mn.bColor(i);
        var dim = false;
        buildingIconEx(dc, cx, cy, s, i, col, dim);
    }
    function buildingIconEx(dc, cx, cy, s, i, col, dim) {
        dc.setColor(dim ? 0x2A2216 : col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, s);
        dc.setColor(dim ? 0x5A4A36 : 0x120C06, Graphics.COLOR_TRANSPARENT);
        var q = s * 55 / 100;
        if (i == Mn.B_SHAFT) {                 // downward chevrons
            dc.drawLine(cx - q, cy - q / 2, cx, cy + q / 4);
            dc.drawLine(cx + q, cy - q / 2, cx, cy + q / 4);
        } else if (i == Mn.B_FORGE) {          // flame
            dc.fillPolygon([[cx, cy - q], [cx + q * 70 / 100, cy + q / 2], [cx - q * 70 / 100, cy + q / 2]]);
        } else if (i == Mn.B_ELEVATOR) {       // up/down arrows
            dc.fillPolygon([[cx, cy - q], [cx - q / 2, cy - q / 6], [cx + q / 2, cy - q / 6]]);
            dc.fillPolygon([[cx, cy + q], [cx - q / 2, cy + q / 6], [cx + q / 2, cy + q / 6]]);
        } else if (i == Mn.B_CAMP) {           // tent
            dc.fillPolygon([[cx, cy - q], [cx + q, cy + q * 70 / 100], [cx - q, cy + q * 70 / 100]]);
        } else if (i == Mn.B_LAB) {            // flask
            dc.drawLine(cx - q / 3, cy - q, cx - q / 3, cy);
            dc.drawLine(cx + q / 3, cy - q, cx + q / 3, cy);
            dc.fillPolygon([[cx - q / 3, cy], [cx + q / 3, cy], [cx + q, cy + q], [cx - q, cy + q]]);
        } else if (i == Mn.B_GEMWS) {          // diamond
            dc.fillPolygon([[cx, cy - q], [cx + q * 75 / 100, cy], [cx, cy + q], [cx - q * 75 / 100, cy]]);
        } else if (i == Mn.B_RIG) {            // piston: bracing bars
            dc.fillRectangle(cx - q, cy - q, q * 2, q / 3 + 1);
            dc.fillRectangle(cx - q, cy + q * 70 / 100, q * 2, q / 3 + 1);
            dc.fillRectangle(cx - q / 4, cy - q / 2, q / 2, q * 5 / 4);
        } else if (i == Mn.B_BORE) {           // drill: converging bit
            dc.fillPolygon([[cx - q, cy - q], [cx + q, cy - q], [cx, cy + q]]);
            dc.setColor(dim ? 0x2A2216 : col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - q / 2, cy - q / 3, q, q / 4 + 1);
        } else {                               // scanner: radar arcs
            dc.drawArc(cx, cy + q / 2, q, Graphics.ARC_COUNTER_CLOCKWISE, 20, 160);
            dc.drawArc(cx, cy + q / 2, q / 2, Graphics.ARC_COUNTER_CLOCKWISE, 20, 160);
            dc.fillCircle(cx, cy + q / 2, 1);
        }
    }

    // Pickaxe glyph on a disc; the head is tinted per tier so all nine tiers
    // are visually distinct in the upgrade list.
    function pickIcon(dc, cx, cy, s, tier) {
        dc.setColor(0xFF9A4A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, s);
        var q = s * 60 / 100;
        dc.setColor(0x6A4A2A, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - q, cy + q, cx + q, cy - q);          // handle
        dc.setColor(_pickColor(tier), Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx + q / 3, cy - q / 2, q, Graphics.ARC_CLOCKWISE, 300, 60);   // head
        if (tier >= 2) { dc.setColor(0x5CF0EA, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + q / 3, cy - q / 2, 1); }
        if (tier >= 5) {   // exotic tiers get a second spark
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - q / 2, cy + q / 2, 1);
        }
    }

    // Cart glyph on a disc, tinted per tier.
    function cartIcon(dc, cx, cy, s, tier) {
        dc.setColor(_cartColor(tier), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, s);
        var q = s * 62 / 100;
        dc.setColor(0x143048, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - q, cy - q / 2, q * 2, q);
        dc.setColor(0xFFE27A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - q / 6, 1);
        dc.setColor(0x0A1420, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - q / 2, cy + q / 2, 2);
        dc.fillCircle(cx + q / 2, cy + q / 2, 2);
    }

    // Small gem/relic used for owned collectibles (colour by rarity).
    function collectibleIcon(dc, cx, cy, s, rarity) {
        var col = Mn.rarityColor(rarity);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, cy - s], [cx + s * 78 / 100, cy], [cx, cy + s], [cx - s * 78 / 100, cy]]);
        if (rarity >= 3) {
            dc.setColor(0xFFF4C8, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - s * 22 / 100, cy - s * 22 / 100, 1);
        }
    }

    function _darken(c) {
        var r = (c >> 16) & 0xFF; var g = (c >> 8) & 0xFF; var b = c & 0xFF;
        r = r * 45 / 100; g = g * 45 / 100; b = b * 45 / 100;
        return (r << 16) | (g << 8) | b;
    }
}
