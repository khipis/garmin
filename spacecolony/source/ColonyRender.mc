// ═══════════════════════════════════════════════════════════════════════════
// ColonyRender.mc — Procedural planet + colony skyline.
//
// The whole scene is drawn from primitives (no sprites): a layered starfield, a
// distant sun + moon, the curved planet horizon with surface detail, and a
// skyline of structures — one per built building. Each structure has a distinct
// silhouette (reactor with a pulsing core, launch pad with animated exhaust,
// satellite dish, space elevator, lit domes) and small level pips so the player
// can SEE exactly what they built and how far it has grown. Cheap to render,
// scales to any watch, and visibly evolves as the colony expands.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;

module ColonyArt {

    // Draw the full scene within the box centred at (cx,cy) with radius r.
    function drawScene(dc, m, cx, cy, r, phase) {
        var top = cy - r;
        var ground = cy + r * 55 / 100;

        // ── Layered starfield (deterministic twinkle) ────────────────────────
        for (var i = 0; i < 22; i++) {
            var sx = cx - r + ((i * 8419) % (r * 2));
            var sy = top + ((i * 5237) % (r * 3 / 2));
            var tw = ((phase / 6 + i) % 9);
            if (tw == 0) { continue; }                       // brief blink out
            var bright = (i % 5 == 0);
            dc.setColor(bright ? 0xFFFFFF : (tw < 3 ? 0x4A5A70 : 0xA9BACE), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, bright ? 2 : 1);
        }

        // ── Distant moon ─────────────────────────────────────────────────────
        dc.setColor(0x3A4658, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r * 66 / 100, top + r * 16 / 100, r / 12 + 1);

        // ── Distant sun with soft glow ───────────────────────────────────────
        var sunx = cx + r * 60 / 100; var suny = top + r * 20 / 100;
        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunx, suny, r / 6 + 2);
        dc.setColor(0xFFB35A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunx, suny, r / 8);
        dc.setColor(0xFFE7A0, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunx - r / 40, suny - r / 40, r / 16 + 1);

        // ── Planet ground (big arc below the horizon) ────────────────────────
        dc.setColor(0x241019, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, ground + r * 3, r * 3 + r);
        dc.setColor(0x3A1A22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, ground + r * 3, r * 3);
        dc.setColor(0x4A2530, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, ground + r * 3, r * 3 - 2);
        // Surface craters / speckles.
        dc.setColor(0x2E141C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r * 55 / 100, ground + r * 22 / 100, r / 12 + 1);
        dc.fillCircle(cx + r * 40 / 100, ground + r * 38 / 100, r / 10 + 1);
        // Horizon glow line.
        dc.setColor(Sc.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, ground + r * 3, r * 3, Graphics.ARC_COUNTER_CLOCKWISE, 66, 114);

        // Shimmering aurora that grows richer with civilisation level.
        var civ = 1; try { civ = m.civLevel(); } catch (e) {}
        try { _pxAurora(dc, cx, ground + r * 3, r * 3, civ, phase); } catch (e) {}

        _drawSkyline(dc, m, cx, ground, r, phase);
    }

    function _drawSkyline(dc, m, cx, ground, r, phase) {
        // Draw order = left-to-right layout of the mini skyline. MUST list every
        // building id exactly once; ids are only ever appended.
        var order = [Sc.B_REACTOR, Sc.B_GEO, Sc.B_MINE, Sc.B_REFINERY, Sc.B_HABITAT,
                     Sc.B_FARM, Sc.B_ICE, Sc.B_LAB, Sc.B_SAT, Sc.B_TRADE,
                     Sc.B_LAUNCH, Sc.B_ALIEN, Sc.B_QUANTUM, Sc.B_ELEVATOR, Sc.B_DEFENSE];
        var built = [];
        for (var i = 0; i < order.size(); i++) {
            var oid = order[i];
            if (oid < 0 || oid >= Sc.B_N) { continue; }
            if (m.bLevel[oid] > 0) { built.add(oid); }
        }
        // The preview band is tiny — past a dozen slots the silhouettes turn to
        // mush, so cap what we draw rather than shrink to sub-pixel widths.
        if (built.size() > 12) { built = built.slice(0, 12); }
        if (built.size() == 0) {
            _pod(dc, cx, ground, r, phase);
            return;
        }

        var span = r * 175 / 100;
        var x0 = cx - span / 2;
        var slot = span / built.size();

        // Connecting ground path between structures.
        dc.setColor(0x22333F, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 + slot / 2, ground - 1, span - slot, 3);

        for (var b = 0; b < built.size(); b++) {
            var id = built[b];
            var bx = x0 + slot * b + slot / 2;
            // Base node on the path.
            dc.setColor(0x33445A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, ground, 2);
            _structure(dc, id, m.bLevel[id], bx, ground, slot, r, phase);
        }
    }

    // Emergency landing pod (colony start) with a soft beacon blink.
    function _pod(dc, cx, ground, r, phase) {
        dc.setColor(0x8A98A8, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - r / 5, ground - r / 4, r * 2 / 5, r / 4, 4);
        dc.setColor(0xC9D6E6, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - r / 6, ground - r / 5, r / 3, r / 6, 3);
        // Landing legs.
        dc.setColor(0x5A6675, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - r / 6, ground - r / 20, cx - r / 4, ground);
        dc.drawLine(cx + r / 6, ground - r / 20, cx + r / 4, ground);
        // Blinking beacon.
        var on = ((phase / 6) % 2) == 0;
        dc.setColor(on ? 0xFF5A5A : 0x662222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, ground - r / 4, r / 12 + 1);
    }

    function _structure(dc, id, lvl, bx, ground, slot, r, phase) {
        var col = Sc.bColor(id);
        var w = slot * 58 / 100; if (w < 6) { w = 6; }
        var h = r * (20 + lvl * 6) / 100; if (h > r * 95 / 100) { h = r * 95 / 100; }
        var x = bx - w / 2;
        var y = ground - h;

        if (id == Sc.B_ELEVATOR) {
            dc.setColor(0x445A70, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 1, ground - r * 2, 3, r * 2);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            // Climbing car.
            var carY = ground - r - ((phase / 3) % (r + 1));
            dc.fillRectangle(bx - 3, carY, 6, 5);
            dc.fillCircle(bx, ground - r * 2, 3);
            _pips(dc, id, lvl, bx, ground - r * 2 - 8);
            return;
        }
        if (id == Sc.B_QUANTUM) {
            // Levitating core ring — the endgame landmark.
            dc.setColor(Sc.bColorDark(id), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, ground - h / 4, w, h / 4);
            var qy = y + h / 3 - ((phase / 7) % 3);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, qy, w / 3);
            dc.drawCircle(bx, qy, w / 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, qy, w / 8 + 1);
            _pips(dc, id, lvl, bx, y - 5);
            return;
        }
        if (id == Sc.B_REACTOR || id == Sc.B_GEO) {
            dc.setColor(Sc.bColorDark(id), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, w, h);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, w, 3);
            // Pulsing core + glow ring.
            var lit = ((phase / 5) % 10) < 5;
            dc.setColor(lit ? 0xFFF0A0 : 0xC9922A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, y + h / 2, w / 4);
            if (lit) { dc.setColor(0xFFF0A0, Graphics.COLOR_TRANSPARENT); dc.drawCircle(bx, y + h / 2, w / 4 + 3); }
            _pips(dc, id, lvl, bx, y - 5);
            return;
        }
        if (id == Sc.B_LAUNCH) {
            // Launch pad + rocket with animated exhaust.
            dc.setColor(0x445A70, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, ground - 4, w, 4);
            dc.setColor(0xE0E6EC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx - w / 6, y, w / 3, h - 4, 3);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[bx - w / 6, y], [bx + w / 6, y], [bx, y - h / 4]]);
            var flame = ((phase / 3) % 2) == 0;
            dc.setColor(flame ? 0xFF9A3A : 0xFFE45A, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[bx - w / 8, ground - 4], [bx + w / 8, ground - 4], [bx, ground + h / 6]]);
            _pips(dc, id, lvl, bx, y - h / 4 - 6);
            return;
        }
        if (id == Sc.B_SAT || id == Sc.B_TRADE) {
            // Mast + dish (arc).
            dc.setColor(0x445A70, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 1, y, 3, h);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, y, w / 3);
            dc.setColor(Sc.bColorDark(id), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, y, w / 6);
            var blip = ((phase / 4) % 2) == 0;
            dc.setColor(blip ? 0xFFFFFF : col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, y - w / 3 - 2, 1);
            _pips(dc, id, lvl, bx, y - w / 3 - 8);
            return;
        }
        if (id == Sc.B_DEFENSE) {
            // Turret dome + barrel.
            dc.setColor(Sc.bColorDark(id), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y + h / 2, w, h / 2);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, y + h / 2, w / 2);
            dc.fillRectangle(bx, y + h / 3, w / 2 + 3, 3);
            _pips(dc, id, lvl, bx, y - 5);
            return;
        }

        // Default: lit dome + body (habitat / mine / farm / lab / alien /
        // refinery / ice works) — retinted per building colour.
        dc.setColor(Sc.bColorDark(id), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y + h / 3, w, h * 2 / 3);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, y + h / 3, w / 2);
        // Lit windows grid (grows with size).
        dc.setColor(0xFFE7A0, Graphics.COLOR_TRANSPARENT);
        var wy = y + h / 2;
        var rows = h * 2 / 3 / 7;
        if (rows > 3) { rows = 3; }
        for (var ry = 0; ry < rows; ry++) {
            dc.fillRectangle(bx - w / 4, wy + ry * 6, w / 6, 3);
            dc.fillRectangle(bx + w / 12, wy + ry * 6, w / 6, 3);
        }
        _pips(dc, id, lvl, bx, y + h / 3 - w / 2 - 6);
    }

    // Small level pips above a structure (up to 5, then "+").
    function _pips(dc, id, lvl, cx, py) {
        if (lvl <= 0) { return; }
        var n = lvl > 5 ? 5 : lvl;
        var col = Sc.bColor(id);
        var x0 = cx - (n - 1) * 3 / 2;
        for (var i = 0; i < n; i++) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0 + i * 3 - 1, py, 2, 2);
        }
    }

    // Small teal upgrade chevrons stacked above a structure — shown when a
    // researched TECH is actively boosting THIS building, so tech levels are
    // visibly reflected on the skyline (up to 3 ticks, then it just caps out).
    function _techBadge(dc, cx, py, lvl) {
        if (lvl == null || lvl <= 0) { return; }
        var n = lvl > 3 ? 3 : lvl;
        dc.setColor(0x4CE0C0, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < n; i++) {
            var tx = cx - (n - 1) * 3 + i * 6;
            dc.fillPolygon([[tx - 2, py + 2], [tx + 2, py + 2], [tx, py - 2]]);
        }
    }
    // Safe tech-level lookup (never throws into the render path).
    function _techLvl(m, t) {
        try { return m.tech[t]; } catch (e) { return 0; }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PIXEL-ART COLONY — the HOME diorama.
    //
    // A layered, chunky pixel-art view of YOUR whole base on planet X-01: a
    // starfield sky, a ringed gas giant + sun, the curved planet horizon, and a
    // ground diorama of every structure you've built (glass domes, solar arrays,
    // mine rig, lab dish, satellite, alien relic, space elevator, defense turret,
    // landing pad + rocket, hydro-farm). Structures appear as they're built and
    // visibly grow richer with level; colonists + a rover move around; region
    // discoveries plant survey markers on the far hills. Everything is guarded so
    // it can never crash the UI.  Cell counts are kept to a few hundred fills.
    // ═══════════════════════════════════════════════════════════════════════
    function drawPixelScene(dc, m, x0, y0, w, h, phase) {
        try { _pxScene(dc, m, x0, y0, w, h, phase); } catch (e) {}
    }

    function _pxPal() {
        return {
            "W" => 0xF2F6FF, "b" => 0x7FC8FF, "B" => 0x2A4A66, "y" => 0xFFE79A,
            "g" => 0xAEBECE, "G" => 0x3E4A5C, "o" => 0xFFA33A, "O" => 0xC24A1A,
            "r" => 0xFF5A6E, "R" => 0x8A2A38, "p" => 0xC48CFF, "P" => 0x4A2A7A,
            "c" => 0x5CE6D0, "C" => 0x1E7A6E, "n" => 0x6CE07A, "N" => 0x256E30,
            "s" => 0x6E4A32, "m" => 0xE0E6EC, "l" => 0x8CD0FF, "k" => 0x33445A,
            "M" => 0xB0BCC8
        };
    }

    // Place a sprite standing ON groundY, centred at fxPct (percent of width).
    function _place(dc, rows, pal, fxPct, groundY, px, x0, w, flip) {
        var cw = rows[0].length();
        var ch = rows.size();
        var ox = x0 + fxPct * w / 100 - (cw * px) / 2;
        var oy = groundY - ch * px;
        Px.spr(dc, rows, pal, ox, oy, px, flip);
        return oy;
    }

    // Place a dome sprite (habitat + annexes) and overlay its window cells
    // with an independent lit/dim blink per cell, phase-offset by `seed` so
    // every module twinkles out of sync with its neighbours — makes the base
    // read as a living, inhabited colony rather than a static painting.
    function _pxDomeBlink(dc, pal, rows, winRow, winCols, x0, w, groundY, px, fxPct, phase, seed, flip) {
        var oy = _place(dc, rows, pal, fxPct, groundY, px, x0, w, flip);
        var cw = rows[0].length();
        var ox = x0 + fxPct * w / 100 - (cw * px) / 2;
        for (var i = 0; i < winCols.size(); i++) {
            var c = flip ? (cw - 1 - winCols[i]) : winCols[i];
            var lit = (((phase / 7) + seed + i * 2) % 5) < 3;
            dc.setColor(lit ? 0xFFE79A : 0x3A2E12, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ox + c * px, oy + winRow * px, px, px);
        }
        return oy;
    }

    function _pxScene(dc, m, x0, y0, w, h, phase) {
        // Several helpers take `% w` / `% h`; a degenerate box would divide by
        // zero, so bail out before anything touches the modulo.
        if (w < 16 || h < 16) { return; }
        var clipped = false;
        try { dc.setClip(x0, y0, w, h); clipped = true; } catch (e) {}

        var S = (w < h) ? w : h;
        var px = S / 40;
        if (px < 3) { px = 3; }
        var pxB = px * 82 / 100; if (pxB < 2) { pxB = 2; }
        var pal = _pxPal();

        var civ = 1; try { civ = m.civLevel(); } catch (e) {}
        var tier = _civTier(civ);

        // Composition is tuned to fill the WHOLE watch (the diorama is now the
        // star of the overview): a tall deep-space sky over the upper half, then
        // a deep two-row planet foreground so the colony reads big and layered.
        var horizon = y0 + h * 52 / 100;
        var gB = y0 + h * 64 / 100;    // back-row ground (distant structures)
        var gF = y0 + h * 82 / 100;    // front-row ground (main structures)
        var cx = x0 + w / 2;

        // ── Sky: deep-space vertical gradient, warming/brightening a notch per
        // civilisation tier so a thriving colony visibly looks more alive. ────
        Px.vgrad(dc, x0, y0, w, horizon - y0, _skyTopCol(tier), _skyBotCol(tier), 12);

        // ── Faint nebula clouds (depth behind the stars) ─────────────────────
        try { _pxNebula(dc, x0, y0, w, horizon - y0); } catch (e) {}

        // ── Far parallax star layer (slow drift, dim) + a rare shooting star ──
        try { _pxFarStars(dc, x0, y0, w, horizon - y0, phase); } catch (e) {}

        // ── Near starfield (deterministic twinkle) — denser now the sky fills
        // the whole upper half of the watch. ─────────────────────────────────
        var skyH = horizon - y0; if (skyH < 1) { skyH = 1; }
        for (var i = 0; i < 34; i++) {
            var stx = x0 + ((i * 8419) % w);
            var sty = y0 + ((i * 5237) % skyH);
            var tw = ((phase / 6 + i) % 9);
            if (tw == 0) { continue; }
            var big = (i % 6 == 0);
            dc.setColor(big ? 0xFFFFFF : (tw < 3 ? 0x5A6A88 : 0xA9BAD8), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(stx, sty, big ? 2 : 1, big ? 2 : 1);
        }

        // ── Distant ringed gas giant ─────────────────────────────────────────
        var ggx = x0 + w * 75 / 100; var ggy = y0 + h * 17 / 100; var ggr = S * 9 / 100;
        dc.setColor(0x3A2A5A, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ggx, ggy, ggr + 2);
        dc.setColor(0x8A6ACF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ggx, ggy, ggr);
        dc.setColor(0xB49AE0, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ggx, ggy, ggr * 70 / 100);
        dc.setColor(0xE0D0FF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ggx - ggr / 3, ggy - ggr / 3, ggr / 3);
        dc.setColor(0xC9B4F0, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(ggx, ggy, ggr + 5, Graphics.ARC_CLOCKWISE, 25, 150);
        dc.drawArc(ggx, ggy, ggr + 7, Graphics.ARC_CLOCKWISE, 30, 145);

        // ── Sun with soft glow ───────────────────────────────────────────────
        var sunx = x0 + w * 20 / 100; var suny = y0 + h * 13 / 100;
        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sunx, suny, S * 7 / 100);
        dc.setColor(0xFF9A3A, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sunx, suny, S * 5 / 100);
        dc.setColor(0xFFE7A0, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sunx - 1, suny - 1, S * 3 / 100);

        // ── Ambient drifting debris/satellites (cheap: a couple of tiny pixels
        // wrapping slowly across the sky band at different speeds/depths) ─────
        try { _pxDebris(dc, x0, y0, w, horizon - y0, phase); } catch (e) {}

        // ── Orbital traffic: freighters on the shipping lanes + a waypoint
        // station, so the sky reads as a settled system rather than a backdrop.
        try { _pxTraffic(dc, x0, y0, w, horizon - y0, phase); } catch (e) {}

        // ── Planet ground: big curved horizon ────────────────────────────────
        var prad = h * 3;
        var pcy = horizon + prad;
        dc.setColor(_terrainCol(tier, 0), Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, pcy, prad + 5);
        dc.setColor(_terrainCol(tier, 1), Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, pcy, prad);
        dc.setColor(_terrainCol(tier, 2), Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, pcy, prad - 3);
        // Horizon glow line brightens/cools a tier at a time as civilisation grows.
        dc.setColor(_horizonCol(tier), Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, pcy, prad, Graphics.ARC_COUNTER_CLOCKWISE, 68, 112);
        dc.drawArc(cx, pcy, prad - 1, Graphics.ARC_COUNTER_CLOCKWISE, 72, 108);

        // Shimmering aurora over the horizon — grows in bands + brightness as
        // the civilisation advances (a visible reward for progress).
        try { _pxAurora(dc, cx, pcy, prad, civ, phase); } catch (e) {}

        // Surface texture: craters + rock outcrops speckled along the visible rim.
        try { _pxSurface(dc, m, x0, w, horizon, px, phase); } catch (e) {}

        // Region survey markers on the far hills (one per discovered region).
        // Spacing is COMPUTED from RG_N and the flags alternate between two
        // rows, so any number of regions stays on-screen and legible.
        try {
            var span = 78;
            var divs = (Sc.RG_N > 1) ? (Sc.RG_N - 1) : 1;
            for (var rg = 0; rg < Sc.RG_N; rg++) {
                if (!m.isDiscovered(rg)) { continue; }
                var mkx = x0 + w * (11 + rg * span / divs) / 100;
                var mky = horizon - 2 - ((rg % 2) * (px + 1));
                dc.setColor(0x2A2028, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(mkx, mky - px, 1, px + 2);
                dc.setColor(Sc.rgColor(rg), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(mkx, mky - px, px * 2 / 3 + 1, px / 2 + 1);
            }
        } catch (e) {}

        _pxColony(dc, m, x0, y0, w, h, px, pxB, gF, gB, cx, pal, phase, tier);

        if (clipped) { try { dc.clearClip(); } catch (e) {} }
    }

    // A couple of tiny debris chips / a blinking satellite drifting slowly
    // across the sky band and wrapping around — cheap ambient motion behind
    // the twinkling stars.
    function _pxDebris(dc, x0, y0, w, skyH, phase) {
        if (skyH < 4) { return; }
        for (var d = 0; d < 3; d++) {
            var speed = 1 + d;
            var span = w + 16;
            var dx = x0 - 8 + ((d * 4001 + phase * speed) % span);
            var dy = y0 + skyH * (10 + d * 15) / 100;
            if (d == 0) {
                dc.setColor(0x5A6A80, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx - 2, dy, 6, 2);
                dc.fillRectangle(dx - 3, dy, 1, 2);
                dc.fillRectangle(dx + 4, dy, 1, 2);
                var blink = ((phase / 9) % 3) == 0;
                dc.setColor(blink ? 0xFF6A6A : 0x5A6A80, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx, dy, 1, 1);
            } else {
                dc.setColor(0x7A8AA0, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx, dy, d, d);
            }
        }
    }

    // Shallow dune ridges rippling along the rim — a cheap zig-zag polyline
    // that reads as wind-carved terrain under the craters/rocks.
    function _pxDunes(dc, x0, w, horizon, px) {
        var n = 6;
        var span = w * 74 / 100;
        var startX = x0 + w * 13 / 100;
        var stepX = span / n;
        var amp = px / 3; if (amp < 1) { amp = 1; }
        var px0 = startX; var py0 = horizon + amp;
        dc.setColor(0xAA0000, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i <= n; i++) {
            var nx = startX + i * stepX;
            var ny = horizon + ((i % 2) == 0 ? amp : -amp) + amp / 2;
            dc.drawLine(px0, py0, nx, ny);
            px0 = nx; py0 = ny;
        }
    }

    // Surface craters/rock outcrops along the visible rim, plus a mineral
    // vein glint tied to the Minerals resource (brighter once the Mine is up).
    function _pxSurface(dc, m, x0, w, horizon, px, phase) {
        try { _pxDunes(dc, x0, w, horizon, px); } catch (e) {}
        var craterX = [8, 24, 39, 58, 71, 86];
        var craterR = [2, 3, 2, 3, 2, 2];
        for (var ci = 0; ci < craterX.size(); ci++) {
            var kx = x0 + w * craterX[ci] / 100;
            var ky = horizon + px / 2 + (ci % 2) * px / 2;
            dc.setColor(0xFFAA55, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(kx, ky, craterR[ci] + 1);
            dc.setColor(0x550000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(kx, ky, craterR[ci]);
        }
        // A jagged rock outcrop or two for extra texture.
        dc.setColor(0x550000, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x0 + w * 4 / 100, horizon + px], [x0 + w * 10 / 100, horizon - px / 2], [x0 + w * 16 / 100, horizon + px]]);
        dc.fillPolygon([[x0 + w * 80 / 100, horizon + px], [x0 + w * 90 / 100, horizon - px * 2 / 3], [x0 + w * 96 / 100, horizon + px]]);
        try { _pxRockField(dc, x0, w, horizon, px); } catch (e) {}
        try { _pxDust(dc, x0, w, horizon, px, phase); } catch (e) {}

        // Mineral vein glint — ties the planet's crust to the Minerals stat.
        var mined = 0; try { mined = m.bLevel[Sc.B_MINE]; } catch (e) {}
        var veinCol = Sc.resColor(Sc.R_MIN);
        var vx = x0 + w * 47 / 100; var vy = horizon + px * 2 / 3;
        dc.setColor(veinCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(vx - 4, vy + 1, 3, 1);
        dc.fillRectangle(vx + 3, vy - 1, 3, 1);
        var glint = mined > 0 && (((phase / 6) % 8) < 3);
        dc.setColor(glint ? 0xFFFFFF : veinCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(vx - 1, vy, 2, 2);
    }

    // Faint nebula clouds — a few dim overlapping blobs give the sky depth
    // behind the twinkling stars. Purely decorative and very cheap.
    // MIP watches quantise every channel to 00/55/AA/FF, so a "faint" dark
    // cloud collapses to pure black and punches a hole in the sky. The wisps
    // therefore sit ABOVE the sky tone and stay clear of the title band.
    function _pxNebula(dc, x0, y0, w, skyH) {
        if (skyH < 6) { return; }
        dc.setColor(0x550055, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + w * 33 / 100, y0 + skyH * 26 / 100, skyH * 20 / 100);
        dc.fillCircle(x0 + w * 44 / 100, y0 + skyH * 18 / 100, skyH * 13 / 100);
        dc.fillCircle(x0 + w * 24 / 100, y0 + skyH * 34 / 100, skyH * 11 / 100);
        dc.setColor(0x5500AA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + w * 36 / 100, y0 + skyH * 24 / 100, skyH * 11 / 100);
        dc.setColor(0x5555AA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + w * 38 / 100, y0 + skyH * 21 / 100, skyH * 5 / 100);
    }

    // Far parallax star layer: dim stars drifting slowly across the sky (a
    // different rate to the near field for depth) plus a rare shooting star.
    function _pxFarStars(dc, x0, y0, w, skyH, phase) {
        if (skyH < 4 || w < 4) { return; }
        var drift = (phase / 3) % w;
        for (var i = 0; i < 16; i++) {
            var sx = x0 + ((i * 6367 + drift) % w);
            var sy = y0 + ((i * 3911) % skyH);
            var tw = ((phase / 10 + i) % 7);
            if (tw == 0) { continue; }
            dc.setColor(tw < 2 ? 0x3A4660 : 0x6A7A98, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, sy, 1, 1);
        }
        var cycle = phase % 220;
        if (cycle < 12) {
            var hx = x0 + w * 10 / 100 + cycle * w / 100;
            var hy = y0 + skyH * 18 / 100 + cycle * skyH / 200;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(hx, hy, 2, 2);
            dc.setColor(0x9FB6D8, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(hx - 4, hy - 2, 3, 1);
            dc.fillRectangle(hx - 8, hy - 4, 3, 1);
        }
    }

    // Civilisation "tier" (0..3) drives the whole scene's colour grading, so a
    // late-game colony visibly reads as more advanced/spectacular than a new
    // one — richer sky, warmer crust, a cooler/brighter horizon glow.
    function _civTier(civ) {
        if (civ >= 10) { return 3; }
        if (civ >= 6) { return 2; }
        if (civ >= 3) { return 1; }
        return 0;
    }
    // On palette, like the terrain: the old near-black/plum pair rounded to two
    // arbitrary steps, so the sky banded by accident rather than by design.
    function _skyTopCol(tier) {
        var a = [0x000000, 0x000000, 0x000055, 0x000055];
        return a[Sc._c(tier, 0, 3)];
    }
    function _skyBotCol(tier) {
        var a = [0x550055, 0x550055, 0x550055, 0xAA0055];
        return a[Sc._c(tier, 0, 3)];
    }
    // Chosen straight from the 64-colour MIP palette (channels 00/55/AA/FF):
    // the old mid-tone maroons all rounded to 0x555555 and the crust rendered
    // as flat grey instead of red dust.
    function _terrainCol(tier, layer) {
        var deep = [0x550000, 0x550000, 0x550000, 0x550000];
        var mid  = [0xAA0000, 0xAA0000, 0xFFAA55, 0xFFAA55];
        var top  = [0xAA5555, 0xAA5555, 0xAA5500, 0xAA5500];
        var t = Sc._c(tier, 0, 3);
        if (layer == 0) { return deep[t]; }
        if (layer == 1) { return mid[t]; }
        return top[t];
    }
    function _horizonCol(tier) {
        var a = [Sc.ACCENT, Sc.ACCENT, 0x6FE0C0, 0xC9A2FF];
        return a[Sc._c(tier, 0, 3)];
    }

    // Shimmering aurora arcs hugging the horizon. Band count + brightness climb
    // with civilisation level, so a thriving colony gets a richer sky.
    function _pxAurora(dc, cx, pcy, prad, civ, phase) {
        var bands = civ / 2;
        if (bands < 1) { bands = 1; }
        if (bands > 4) { bands = 4; }
        // The planet circle is enormous, so a wide angular sweep flattens into a
        // wire stretched across the display. Short, offset ribbons instead.
        for (var i = 0; i < bands; i++) {
            var r = prad + 3 + i * 4;
            var shimmer = ((phase / 4 + i) % 3);
            var col = (shimmer == 0) ? 0x005555 : ((shimmer == 1) ? 0x00AAAA : 0x55FFAA);
            if (civ < 6) { col = (shimmer == 2) ? 0x00AAAA : 0x005555; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var a0 = 74 + i * 7 + ((phase / 7 + i * 5) % 5);
            dc.drawArc(cx, pcy, r, Graphics.ARC_COUNTER_CLOCKWISE, a0, a0 + 9);
        }
    }

    // A compact bank of tilted solar panels at the reactor base. Panel count
    // grows with reactor level (up to 4) and one panel catches a moving glint.
    function _pxSolar(dc, cxp, gF, px, bw, lvl, phase) {
        var n = lvl; if (n > 4) { n = 4; } if (n < 1) { n = 1; }
        var pw = px + px / 2; if (pw < 3) { pw = 3; }
        var gap = pw + px / 2;
        var totw = gap * (n - 1) + pw + px / 2;
        var sx = cxp - totw / 2;
        var ty = gF - px;
        var glint = (phase / 5) % (n + 1);
        for (var i = 0; i < n; i++) {
            var bx = sx + i * gap;
            dc.setColor(0x33445A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx + pw / 2, gF - px / 2, 1, px / 2);
            dc.setColor(0x1E3A6E, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[bx, gF], [bx + pw, gF], [bx + pw + px / 2, ty], [bx + px / 2, ty]]);
            dc.setColor(0x3A6ACF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx + px / 2, ty, pw - 1, 1);
            if (i == glint) {
                dc.setColor(0xCFE8FF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx + pw / 2, ty, 2, px);
            }
        }
    }

    // Safe building-level read: any id past the end of a legacy save's array
    // reads as 0 instead of throwing out of the render path.
    function _lv(bl, id) {
        if (bl == null || id < 0 || id >= bl.size()) { return 0; }
        var v = bl[id];
        return (v == null || v < 0) ? 0 : v;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // COLONY LAYOUT
    //
    // Three terraces, one fixed plot per building. The BACK row runs the full
    // 8..91% of the box because it sits close to the vertical middle of a round
    // display, where the inscribed circle is at its widest. The MID row keeps
    // 11..86%. The FRONT row stands low enough that the circle cuts in hard, so
    // its four plots are pulled into 22..78% — at max sprite growth that still
    // leaves every pixel inside the 13..87% chord available at that height.
    // Each plot also carries a small vertical stagger, so no terrace reads as a
    // ruled straight line.
    // ═══════════════════════════════════════════════════════════════════════
    function _fxOf(id) {
        var a = [43, 22, 76, 62, 78, 41, 26, 8, 58, 71, 11, 56, 26, 86, 91];
        return a[Sc._c(id, 0, Sc.B_N - 1)];
    }
    function _rowOf(id) {
        var a = [2, 2, 0, 2, 2, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0];
        return a[Sc._c(id, 0, Sc.B_N - 1)];
    }
    function _jitOf(id) {
        var a = [0, 2, -2, 1, -1, 2, -1, 1, 0, -2, 1, -1, 2, -2, 0];
        return a[Sc._c(id, 0, Sc.B_N - 1)];
    }
    // Plots visited left-to-right per terrace — used to string walkways between
    // neighbouring modules. MUST list every building id exactly once overall.
    function _rowOrder(r) {
        if (r == 0) { return [Sc.B_ALIEN, Sc.B_SAT, Sc.B_ELEVATOR, Sc.B_MINE, Sc.B_QUANTUM]; }
        if (r == 1) { return [Sc.B_GEO, Sc.B_REFINERY, Sc.B_LAUNCH, Sc.B_TRADE, Sc.B_DEFENSE, Sc.B_ICE]; }
        return [Sc.B_REACTOR, Sc.B_HABITAT, Sc.B_FARM, Sc.B_LAB];
    }
    function _plotX(id, x0, w) { return x0 + _fxOf(id) * w / 100; }
    function _plotY(id, gB, gM, gF, px) {
        var r = _rowOf(id);
        var base = (r == 0) ? gB : ((r == 1) ? gM : gF);
        return base + _jitOf(id) * px / 4;
    }
    // Sprite scale for a plot: distant terraces render smaller, and a structure
    // swells up to +16% as its level climbs so growth is legible at a glance.
    function _plotPx(id, lvl, px) {
        var r = _rowOf(id);
        var base = px;
        if (r == 0) { base = px * 82 / 100; }
        else if (r == 1) { base = px * 90 / 100; }
        var g = lvl; if (g > 4) { g = 4; }
        if (g < 0) { g = 0; }
        base = base * (100 + g * 4) / 100;
        if (base < 2) { base = 2; }
        return base;
    }

    // A pressurised walkway between two neighbouring modules: a shaded tube on
    // support struts with a maintenance light running along it. Drawn before
    // the structures so the modules always sit on top of their own plumbing.
    function _pxPipe(dc, xa, ya, xb, yb, px, phase, seed) {
        var span = xb - xa;
        if (span < px * 2) { return; }
        var th = px / 2; if (th < 2) { th = 2; }
        var my = (ya + yb) / 2;
        var ty = my - th - px / 2;
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xa, ty, span, th);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xa, ty, span, 1);
        var struts = span / (px * 4);
        if (struts > 4) { struts = 4; }
        for (var i = 1; i <= struts; i++) {
            var sx = xa + span * i / (struts + 1);
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, ty + th, 1, my - ty - th);
        }
        var lx = xa + ((phase * 2 + seed * 17) % span);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx, ty, 2, th);
    }
    // Only neighbours on the two near terraces get plumbing, and only when they
    // are close enough that a tube reads as a connection instead of a wire
    // stretched across the whole scene.
    function _pxWalkways(dc, bl, x0, w, gB, gM, gF, px, phase) {
        var maxSpan = w * 26 / 100;
        for (var r = 1; r < 3; r++) {
            var ord = _rowOrder(r);
            var prevX = -1; var prevY = 0;
            for (var i = 0; i < ord.size(); i++) {
                var id = ord[i];
                if (_lv(bl, id) <= 0) { continue; }
                var cxp = _plotX(id, x0, w);
                var gy = _plotY(id, gB, gM, gF, px);
                if (prevX >= 0 && cxp - prevX <= maxSpan) {
                    _pxPipe(dc, prevX, prevY, cxp, gy, px, phase, r * 3 + i);
                }
                prevX = cxp; prevY = gy;
            }
        }
    }

    // Landing lights: a sequenced amber chase along a terrace edge, the way a
    // real pad marks its approach. `n` lights spread between two fx marks.
    function _pxLandingLights(dc, x0, w, y, px, phase, n, fxA, fxB) {
        if (n < 2) { n = 2; }
        var lit = (phase / 4) % n;
        var sz = px / 3; if (sz < 1) { sz = 1; }
        for (var i = 0; i < n; i++) {
            var lx = x0 + w * (fxA + (fxB - fxA) * i / (n - 1)) / 100;
            var on = (i == lit) || (i == ((lit + n / 2) % n));
            dc.setColor(on ? 0xFFD98A : 0x6A4A18, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lx, y, sz + 1, sz + 1);
        }
    }

    // Distant orbital traffic: freighters crossing the sky on their own tracks
    // with a short engine trail, plus a slowly drifting waypoint station.
    function _pxTraffic(dc, x0, y0, w, skyH, phase) {
        if (skyH < 8 || w < 8) { return; }
        for (var s = 0; s < 2; s++) {
            var speed = 3 + s * 2;
            var span = w + 24;
            var sx = x0 - 12 + ((s * 3557 + phase * speed) % span);
            var sy = y0 + skyH * (26 + s * 34) / 100;
            var flip = (s % 2) == 1;
            dc.setColor(0xC9D6E6, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, sy, 4, 2);
            dc.setColor(0x8CA0B8, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(flip ? (sx + 4) : (sx - 1), sy - 1, 1, 4);
            var tx = flip ? (sx + 5) : (sx - 3);
            dc.setColor(((phase / 3) % 2) == 0 ? 0xFFB35A : 0xFF7A3A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx, sy, 3, 1);
        }
        // Waypoint station: a ring with a blinking nav beacon.
        var stx = x0 + w * 46 / 100 + (((phase / 12) % 12) - 6);
        var sty = y0 + skyH * 12 / 100;
        dc.setColor(0x6A7A94, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(stx, sty, 3);
        dc.fillRectangle(stx - 5, sty, 3, 1);
        dc.fillRectangle(stx + 3, sty, 3, 1);
        dc.setColor(((phase / 7) % 4) < 2 ? 0xFF6A6A : 0x40202A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(stx, sty - 1, 1, 1);
    }

    // Scattered boulder field — a handful of shaded chips that break up the
    // flat crust between the craters.
    function _pxRockField(dc, x0, w, horizon, px) {
        var rx = [18, 33, 52, 65, 82, 92];
        var ry = [2, 1, 3, 1, 2, 1];
        for (var i = 0; i < rx.size(); i++) {
            var bx = x0 + w * rx[i] / 100;
            var by = horizon + px * ry[i] / 3;
            var sz = px / 2 + (i % 2);
            if (sz < 2) { sz = 2; }
            dc.setColor(0x550000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, by, sz + 1, sz);
            dc.setColor(0xFFAA55, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, by, sz, 1);
        }
    }

    // Wind-blown dust drifts creeping along the crust — slow horizontal
    // streaks that wrap, so the ground never looks frozen.
    function _pxDust(dc, x0, w, horizon, px, phase) {
        for (var d = 0; d < 3; d++) {
            var span = w + 20;
            var dx = x0 - 10 + ((d * 2777 + phase * (1 + d)) % span);
            var dy = horizon + px * (2 + d) / 2;
            var len = px * (2 + d);
            dc.setColor(d == 0 ? 0xFFAA55 : 0xAA5500, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dx, dy, len, 1);
        }
    }

    // Draw the colony structures + inhabitants (all bLevel-driven).
    function _pxColony(dc, m, x0, y0, w, h, px, pxB, gF, gB, cx, pal, phase, tier) {
        var bl;
        try { bl = m.bLevel; } catch (e) { bl = null; }
        if (bl == null) { return; }

        // A third, mid-depth terrace holds the late-game industry so the base
        // grows *backwards* into the scene instead of overlapping the front row.
        var gM = (gB + gF) / 2;

        var built = 0;
        try { built = m.buildingsBuilt(); } catch (e) {}

        // Terrace decks. The front deck is the only one the player walks on, so
        // Efficiency gives it a golden power-hum pulse — a cheap global glow.
        dc.setColor(0x550000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 + w * 18 / 100, gM - 1, w * 64 / 100, 2);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 + w * 22 / 100, gF - 2, w * 56 / 100, 3);
        if (_techLvl(m, Sc.T_EFF) > 0) {
            var effOn = ((phase / 6) % 6) < 3;
            dc.setColor(effOn ? 0xFFAA55 : 0xAA5500, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0 + w * 22 / 100, gF - 2, w * 56 / 100, 1);
        }
        // ── No buildings yet → the emergency landing pod ─────────────────────
        if (built == 0) {
            _pxPod(dc, pal, cx, gF, px, phase);
            _pxColonists(dc, pal, m, x0, w, gF, px, phase);
            return;
        }

        // Perimeter approach lights sit just above the deck and BEHIND the
        // structures, keeping the bottom band clear for the HUD ribbon.
        try { _pxLandingLights(dc, x0, w, gF - px / 2 - 2, px, phase, 7, 20, 80); } catch (e) {}

        // Walkways run under everything so each module sits on its own plumbing.
        try { _pxWalkways(dc, bl, x0, w, gB, gM, gF, px, phase); } catch (e) {}

        // The tiers are separate functions on purpose: the interpreter stack is
        // sized per frame, and one function holding every structure's locals
        // overflows it before the first sprite lands.
        try { _pxTierOrbit(dc, m, bl, x0, y0, w, h, px, pxB, gB, gM, gF, pal, phase); } catch (e) {}
        try { _pxTierSky(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase); } catch (e) {}
        try { _pxTierWorks(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase); } catch (e) {}
        try { _pxTierPort(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase); } catch (e) {}
        try { _pxTierGuard(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase); } catch (e) {}
        try { _pxTierCore(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase, tier); } catch (e) {}
        try { _pxTierHome(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase); } catch (e) {}

        // The rover and the colonists who actually live here.
        _pxRover(dc, pal, x0, w, gF, px, phase);
        _pxColonists(dc, pal, m, x0, w, gF, px, phase);
    }

    // ── BACK ROW — orbital tier, spread across the full 8..91% ───────────────
    function _pxTierOrbit(dc, m, bl, x0, y0, w, h, px, pxB, gB, gM, gF, pal, phase) {
        var elvL = _lv(bl, Sc.B_ELEVATOR);
        if (elvL > 0) {
            _pxElevator(dc, pal, _plotX(Sc.B_ELEVATOR, x0, w),
                        _plotY(Sc.B_ELEVATOR, gB, gM, gF, px), y0, h, pxB, elvL, phase);
        }
        // Alien relic: a shard ring around a pulsing containment core.
        var aliL = _lv(bl, Sc.B_ALIEN);
        if (aliL > 0) {
            var apx = _plotPx(Sc.B_ALIEN, aliL, px);
            var acx = _plotX(Sc.B_ALIEN, x0, w);
            var agy = _plotY(Sc.B_ALIEN, gB, gM, gF, px);
            var ap = ["..p..", ".pCp.", "p.c.p", ".pcp.", ".ppp.", "PPPPP"];
            var oy = _place(dc, ap, pal, _fxOf(Sc.B_ALIEN), agy, apx, x0, w, false);
            var glow = ((phase / 5) % 6) < 3;
            dc.setColor(glow ? 0x8CFFE0 : 0x2E9A86, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(acx - apx / 2, oy + 2 * apx, apx, apx);
            if (aliL >= 3) {   // outrigger pylons appear once the site is dug out
                dc.setColor(0x4A2A7A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(acx - apx * 3, agy - apx * 2, apx / 2 + 1, apx * 2);
                dc.fillRectangle(acx + apx * 5 / 2, agy - apx * 2, apx / 2 + 1, apx * 2);
            }
            _pips(dc, Sc.B_ALIEN, aliL, acx, oy - 4);
            _techBadge(dc, acx, oy - 10, _techLvl(m, Sc.T_RES));
        }
        // Satellite station: dish on a mast with a blinking uplink.
        var satL = _lv(bl, Sc.B_SAT);
        if (satL > 0) {
            var spx = _plotPx(Sc.B_SAT, satL, px);
            var scx = _plotX(Sc.B_SAT, x0, w);
            var sgy = _plotY(Sc.B_SAT, gB, gM, gF, px);
            var sp = [".cc..", "ccGc.", "..g..", "..g..", ".kgk."];
            var oy2 = _place(dc, sp, pal, _fxOf(Sc.B_SAT), sgy, spx, x0, w, ((phase / 20) % 2) == 0);
            var up = ((phase / 4) % 2) == 0;
            dc.setColor(up ? 0xFFFFFF : 0x2A4A66, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(scx - spx, oy2 - spx, spx / 2 + 1, spx / 2 + 1);
            _pips(dc, Sc.B_SAT, satL, scx, oy2 - spx - 4);
        }
    }

    // Skyline landmarks: the deepest structures that break the horizon line.
    function _pxTierSky(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase) {
        // Mine rig: headframe, growing ore pile, second shaft at higher levels.
        var mnL = _lv(bl, Sc.B_MINE);
        if (mnL > 0) {
            var mpx = _plotPx(Sc.B_MINE, mnL, px);
            var mcx = _plotX(Sc.B_MINE, x0, w);
            var mgy = _plotY(Sc.B_MINE, gB, gM, gF, px);
            var mp = ["..o..", ".ooo.", ".G.G.", ".G.G.", "GGGGG", "sMMMs"];
            var oy3 = _place(dc, mp, pal, _fxOf(Sc.B_MINE), mgy, mpx, x0, w, false);
            if (mnL >= 4) {
                var mp2 = ["..o.", ".G.G", "GGGG"];
                _place(dc, mp2, pal, _fxOf(Sc.B_MINE) + 8, mgy, mpx * 80 / 100, x0, w, true);
            }
            var ore = mnL; if (ore > 5) { ore = 5; }
            dc.setColor(0xB0BCC8, Graphics.COLOR_TRANSPARENT);
            for (var oi = 0; oi < ore; oi++) {
                dc.fillRectangle(mcx - mpx * 4 + oi * mpx / 2, mgy - mpx / 2, mpx / 2 + 1, mpx / 2 + 1);
            }
            _pips(dc, Sc.B_MINE, mnL, mcx, oy3 - 4);
            _techBadge(dc, mcx, oy3 - 10, _techLvl(m, Sc.T_EXTR));
        }
        // Quantum core: a hovering, pulsing singularity ring — the endgame
        // landmark, so the very last unlock is unmistakable on the skyline.
        var qL = _lv(bl, Sc.B_QUANTUM);
        if (qL > 0) {
            var qpx = _plotPx(Sc.B_QUANTUM, qL, px);
            var qx = _plotX(Sc.B_QUANTUM, x0, w);
            var qgy = _plotY(Sc.B_QUANTUM, gB, gM, gF, px);
            var qr = qpx + qpx / 2; if (qr < 3) { qr = 3; }
            var qy = qgy - qpx * 4 - ((phase / 9) % 3);
            dc.setColor(0x2A1440, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(qx - qpx * 2, qgy - qpx, qpx * 4, qpx);
            dc.setColor(Sc.bColor(Sc.B_QUANTUM), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(qx, qy, qr + 2);
            dc.fillCircle(qx, qy, qr);
            var qlit = ((phase / 5) % 6) < 3;
            dc.setColor(qlit ? 0xFFFFFF : 0xE0D0FF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(qx, qy, qr / 2 + 1);
            dc.setColor(0x8C6ACF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(qx, qy + qr, qx, qgy - qpx);
            _pips(dc, Sc.B_QUANTUM, qL, qx, qy - qr - 6);
            _techBadge(dc, qx, qy - qr - 12, _techLvl(m, Sc.T_EFF));
        }

    }

    // ── MID ROW — industry terrace, 11..86% ─────────────────────────────────
    function _pxTierWorks(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase) {
        // Geothermal plant: vent housing over a magma glow, steam plume above,
        // a second stack once the field has been widened.
        var geoL = _lv(bl, Sc.B_GEO);
        if (geoL > 0) {
            var gpx = _plotPx(Sc.B_GEO, geoL, px);
            var gcx = _plotX(Sc.B_GEO, x0, w);
            var ggy = _plotY(Sc.B_GEO, gB, gM, gF, px);
            var geo = ["GGGGG", "GoooG", "GGGGG", "kkkkk"];
            var gy2 = _place(dc, geo, pal, _fxOf(Sc.B_GEO), ggy, gpx, x0, w, false);
            var hot = ((phase / 4) % 8) < 4;
            dc.setColor(hot ? 0xFFD24A : 0xC24A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(gcx - gpx, gy2 + gpx, gpx * 2, gpx);
            var puff = (phase / 6) % 3;
            dc.setColor(0x6E7A88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(gcx - gpx / 2, gy2 - gpx * (1 + puff), gpx, gpx);
            if (geoL >= 3) {
                var geo2 = ["Go.", "GGG", "kkk"];
                _place(dc, geo2, pal, _fxOf(Sc.B_GEO) + 6, ggy, gpx * 80 / 100, x0, w, false);
            }
            _pips(dc, Sc.B_GEO, geoL, gcx, gy2 - gpx * 4 - 2);
            _techBadge(dc, gcx, gy2 - gpx * 4 - 8, _techLvl(m, Sc.T_POWER));
        }
        // Refinery: smelter stack, ingot stack at the foot, silo at high levels.
        var refL = _lv(bl, Sc.B_REFINERY);
        if (refL > 0) {
            var rpx = _plotPx(Sc.B_REFINERY, refL, px);
            var fcx = _plotX(Sc.B_REFINERY, x0, w);
            var rgy = _plotY(Sc.B_REFINERY, gB, gM, gF, px);
            var rfn = ["..s..", ".sMs.", "sMMMs", "GGGGG", "kkkkk"];
            var fy2 = _place(dc, rfn, pal, _fxOf(Sc.B_REFINERY), rgy, rpx, x0, w, false);
            if (refL >= 4) {
                var silo = [".M.", "MMM", "MMM", "kkk"];
                _place(dc, silo, pal, _fxOf(Sc.B_REFINERY) + 6, rgy, rpx * 75 / 100, x0, w, false);
            }
            var ing = refL; if (ing > 4) { ing = 4; }
            dc.setColor(0xE0E6EC, Graphics.COLOR_TRANSPARENT);
            for (var ii = 0; ii < ing; ii++) {
                dc.fillRectangle(fcx - rpx * 4 + ii * rpx / 2, rgy - rpx / 2, rpx / 2 + 1, rpx / 2 + 1);
            }
            var smoke = (phase / 7) % 3;
            dc.setColor(0x5A4636, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fcx - rpx / 2, fy2 - rpx * (1 + smoke), rpx, rpx);
            _pips(dc, Sc.B_REFINERY, refL, fcx, fy2 - rpx * 4 - 2);
            _techBadge(dc, fcx, fy2 - rpx * 4 - 8, _techLvl(m, Sc.T_EXTR));
        }
    }

    // The traffic half of the industry terrace: everything that ships cargo.
    function _pxTierPort(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase) {
        // Landing pad + rocket, ringed by a sequenced approach light chase.
        var lauL = _lv(bl, Sc.B_LAUNCH);
        if (lauL > 0) {
            var lpx = _plotPx(Sc.B_LAUNCH, lauL, px);
            var padx = _plotX(Sc.B_LAUNCH, x0, w);
            var lgy = _plotY(Sc.B_LAUNCH, gB, gM, gF, px);
            dc.setColor(0x445A70, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(padx - lpx * 3, lgy - 2, lpx * 6, 3);
            try {
                _pxLandingLights(dc, x0, w, lgy - 1, lpx, phase, 5,
                                 _fxOf(Sc.B_LAUNCH) - 6, _fxOf(Sc.B_LAUNCH) + 6);
            } catch (e) {}
            var rocket = ["..W..", ".WWW.", ".WrW.", ".WWW.", ".WWW.", "r.W.r"];
            var ry2 = _place(dc, rocket, pal, _fxOf(Sc.B_LAUNCH), lgy, lpx, x0, w, false);
            if (lauL >= 3) {   // a service gantry rises alongside the stack
                dc.setColor(0x6A7A88, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(padx - lpx * 3, ry2 + lpx, 1, lgy - ry2 - lpx);
                dc.fillRectangle(padx - lpx * 3, ry2 + lpx * 2, lpx * 2, 1);
            }
            var flame = ((phase / 3) % 3);
            if (flame > 0) {
                dc.setColor(flame == 1 ? 0xFFE45A : 0xFF9A3A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(padx - lpx, lgy, lpx * 2, lpx + flame);
                dc.setColor(0xFFF0C0, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(padx - lpx / 2, lgy, lpx, lpx / 2 + 1);
            }
            _pips(dc, Sc.B_LAUNCH, lauL, padx, ry2 - 4);
        }
        // Trade hub: market ring under a blinking beacon; a parked shuttle and
        // a second pad appear once the lane is busy enough to need them.
        var trdL = _lv(bl, Sc.B_TRADE);
        if (trdL > 0) {
            var tpx = _plotPx(Sc.B_TRADE, trdL, px);
            var tcx = _plotX(Sc.B_TRADE, x0, w);
            var tgy = _plotY(Sc.B_TRADE, gB, gM, gF, px);
            var trd = [".nnn.", "nnnnn", "GyGyG", "kkkkk"];
            var ty2 = _place(dc, trd, pal, _fxOf(Sc.B_TRADE), tgy, tpx, x0, w, false);
            var beac = ((phase / 5) % 4) < 2;
            dc.setColor(beac ? 0xEAFFD8 : 0x2E6E30, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tcx - tpx / 2, ty2 - tpx, tpx, tpx);
            if (trdL >= 3) {
                var shut = [".mm.", "mmmm", "o..o"];
                _place(dc, shut, pal, _fxOf(Sc.B_TRADE) + 6, tgy, tpx * 70 / 100, x0, w, false);
                try {
                    _pxLandingLights(dc, x0, w, tgy - 1, tpx, phase, 3,
                                     _fxOf(Sc.B_TRADE) + 4, _fxOf(Sc.B_TRADE) + 8);
                } catch (e) {}
            }
            _pips(dc, Sc.B_TRADE, trdL, tcx, ty2 - tpx - 5);
            _techBadge(dc, tcx, ty2 - tpx - 11, _techLvl(m, Sc.T_TRADE));
        }
    }

    // Perimeter services on the outer flanks of the industry terrace.
    function _pxTierGuard(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase) {
        // Defense grid: rail turret with a sweeping scan blip.
        var defL = _lv(bl, Sc.B_DEFENSE);
        if (defL > 0) {
            var dpx = _plotPx(Sc.B_DEFENSE, defL, px);
            var dcx = _plotX(Sc.B_DEFENSE, x0, w);
            var dgy = _plotY(Sc.B_DEFENSE, gB, gM, gF, px);
            var def = ["....B", ".rrBB", "rrrr.", "GGGGG"];
            var dy = _place(dc, def, pal, _fxOf(Sc.B_DEFENSE), dgy, dpx, x0, w, ((phase / 24) % 2) == 0);
            var scan = ((phase / 6) % 4);
            dc.setColor(scan < 2 ? 0xFFB0C0 : 0x6A2A38, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dcx - dpx + scan * dpx / 2, dy - dpx, dpx / 2 + 1, dpx / 2 + 1);
            _pips(dc, Sc.B_DEFENSE, defL, dcx, dy - dpx - 5);
        }
        // Ice works: melt tank with a shimmering waterline and a second tank.
        var iceL = _lv(bl, Sc.B_ICE);
        if (iceL > 0) {
            var ipx = _plotPx(Sc.B_ICE, iceL, px);
            var icx = _plotX(Sc.B_ICE, x0, w);
            var igy = _plotY(Sc.B_ICE, gB, gM, gF, px);
            var ice = [".lll.", "lWWWl", "GlllG", "kkkkk"];
            var iy2 = _place(dc, ice, pal, _fxOf(Sc.B_ICE), igy, ipx, x0, w, false);
            var shim = ((phase / 6) % 4);
            dc.setColor(shim < 2 ? 0xCFF4FF : 0x33AEE0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(icx - ipx + shim, iy2 + ipx, ipx, ipx / 2 + 1);
            if (iceL >= 3) {
                var ice2 = [".ll", "lWl", "kkk"];
                _place(dc, ice2, pal, _fxOf(Sc.B_ICE) - 6, igy, ipx * 75 / 100, x0, w, false);
            }
            _pips(dc, Sc.B_ICE, iceL, icx, iy2 - 5);
            _techBadge(dc, icx, iy2 - 11, _techLvl(m, Sc.T_HYDRO));
        }

    }

    // ── FRONT ROW — the lived-in tier, pulled into 22..78% so nothing
    // crosses the inscribed circle at this height ───────────────────────────
    function _pxTierCore(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase, tier) {
        var rlvl = _lv(bl, Sc.B_REACTOR);
        if (rlvl > 0) {
            var rpx2 = _plotPx(Sc.B_REACTOR, rlvl, px);
            var baseX = _plotX(Sc.B_REACTOR, x0, w);
            var rgy2 = _plotY(Sc.B_REACTOR, gB, gM, gF, px);
            var body = ["kGGGGGk", "kGGGGGk", "kGGGGGk", "kkkkkkk"];
            var ry = _place(dc, body, pal, _fxOf(Sc.B_REACTOR), rgy2, rpx2, x0, w, false);
            var bw = body[0].length() * rpx2;
            var bh = body.size() * rpx2;
            var coreY = ry + bh * 55 / 100;
            var lit = ((phase / 5) % 10) < 5;
            var coreR = rpx2 * 90 / 100 + (rlvl >= 3 ? rpx2 / 3 : 0);
            if (coreR < 2) { coreR = 2; }
            // Soft outer vignette/halo behind the housing — two faint rings
            // that widen at higher civ tiers, so the reactor visibly reads as
            // more powerful once the colony has matured.
            try {
                var haloR = coreR + rpx2 + tier * rpx2 / 2;
                dc.setColor(tier >= 2 ? 0xAAAA00 : 0xAA5500, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(baseX, coreY, haloR);
            } catch (e) {}
            dc.setColor(0x0C1420, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(baseX, coreY, coreR + 2);
            dc.setColor(lit ? (tier >= 3 ? 0xFFF6C8 : 0xFFF0A0) : 0xC9922A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(baseX, coreY, coreR);
            if (lit) {
                dc.setColor(tier >= 3 ? 0xFFE7A0 : 0xFFF0A0, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(baseX, coreY, coreR + 2);
            }
            // Cooling fins on each flank grow in count with reactor level.
            var fins = rlvl; if (fins > 3) { fins = 3; }
            dc.setColor(Sc.bColorDark(Sc.B_REACTOR), Graphics.COLOR_TRANSPARENT);
            var finH = bh - rpx2 * 2; if (finH < rpx2) { finH = rpx2; }
            for (var fi = 0; fi < fins; fi++) {
                dc.fillRectangle(baseX - bw / 2 - rpx2 / 2 - fi * rpx2 * 3 / 4, ry + rpx2, rpx2 / 2 + 1, finH);
                dc.fillRectangle(baseX + bw / 2 - rpx2 / 4 + fi * rpx2 * 3 / 4, ry + rpx2, rpx2 / 2 + 1, finH);
            }
            if (rlvl >= 4) {   // a second, smaller drum joins the plant
                var drum = ["kGGk", "kGGk", "kkkk"];
                _place(dc, drum, pal, _fxOf(Sc.B_REACTOR) + 6, rgy2, rpx2 * 70 / 100, x0, w, false);
            }
            _pips(dc, Sc.B_REACTOR, rlvl, baseX, ry - 5);
            _techBadge(dc, baseX, ry - 11, _techLvl(m, Sc.T_POWER));
            try { _pxSolar(dc, baseX, rgy2, rpx2, bw, rlvl, phase); } catch (e) {}
        }
    }

    // The buildings the colonists actually occupy, front and centre.
    function _pxTierHome(dc, m, bl, x0, w, px, gB, gM, gF, pal, phase) {
        // Habitat: glass dome plus annex domes as level grows. Every module's
        // windows blink independently so the base reads as inhabited.
        var habL = _lv(bl, Sc.B_HABITAT);
        if (habL > 0) {
            var hpx = _plotPx(Sc.B_HABITAT, habL, px);
            var hgy = _plotY(Sc.B_HABITAT, gB, gM, gF, px);
            var hfx = _fxOf(Sc.B_HABITAT);
            var dome = ["..bbb..", ".bWbbb.", "bbbbbbb", "GyGyGyG", "GGGGGGG"];
            var mini = [".bbb.", "bbbbb", "GyGyG"];
            var hy;
            try { hy = _pxDomeBlink(dc, pal, dome, 3, [1, 3, 5], x0, w, hgy, hpx, hfx, phase, 0, false); }
            catch (e) { hy = _place(dc, dome, pal, hfx, hgy, hpx, x0, w, false); }
            if (habL >= 3) {
                try { _pxDomeBlink(dc, pal, mini, 2, [1, 3], x0, w, hgy, hpx, hfx + 7, phase, 3, false); } catch (e) {}
            }
            if (habL >= 5) {
                try { _pxDomeBlink(dc, pal, mini, 2, [1, 3], x0, w, hgy, hpx, hfx - 7, phase, 6, true); } catch (e) {}
            }
            _pips(dc, Sc.B_HABITAT, habL, _plotX(Sc.B_HABITAT, x0, w), hy - 4);
        }
        // Hydro-farm: green biodome, extra grow pods bolted on as it scales.
        var frmL = _lv(bl, Sc.B_FARM);
        if (frmL > 0) {
            var fpx = _plotPx(Sc.B_FARM, frmL, px);
            var fgy = _plotY(Sc.B_FARM, gB, gM, gF, px);
            var ffx = _fxOf(Sc.B_FARM);
            var farm = [".nnnn.", "nnnnnn", "GnGnnG", "GGGGGG"];
            var fy = _place(dc, farm, pal, ffx, fgy, fpx, x0, w, false);
            var pod = [".nn.", "nnnn", "GGGG"];
            if (frmL >= 3) { _place(dc, pod, pal, ffx + 6, fgy, fpx * 70 / 100, x0, w, false); }
            if (frmL >= 5) { _place(dc, pod, pal, ffx - 6, fgy, fpx * 70 / 100, x0, w, true); }
            // Grow-lamp glow inside the canopy, brighter as the farm scales.
            var lampOn = ((phase / 7) % 5) < 3;
            dc.setColor(lampOn ? 0xCFF6C0 : 0x2E7A38, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_plotX(Sc.B_FARM, x0, w) - fpx, fy + fpx, fpx * 2, 1);
            _pips(dc, Sc.B_FARM, frmL, _plotX(Sc.B_FARM, x0, w), fy - 4);
            _techBadge(dc, _plotX(Sc.B_FARM, x0, w), fy - 10, _techLvl(m, Sc.T_HYDRO));
        }
        // Laboratory: sweeping dish over a lit block, second array at high level.
        var labL = _lv(bl, Sc.B_LAB);
        if (labL > 0) {
            var lpx2 = _plotPx(Sc.B_LAB, labL, px);
            var lcx = _plotX(Sc.B_LAB, x0, w);
            var lgy2 = _plotY(Sc.B_LAB, gB, gM, gF, px);
            var lab = ["...c...", "..ccc..", ".bbbbb.", "GyGyGyG", "GGGGGGG"];
            var ly = _place(dc, lab, pal, _fxOf(Sc.B_LAB), lgy2, lpx2, x0, w, false);
            var dishx = lcx + (((phase / 8) % 3) - 1) * lpx2;
            dc.setColor(0xCFFFF4, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dishx - lpx2 / 2, ly - lpx2, lpx2 / 2 + 1, lpx2 / 2 + 1);
            if (labL >= 3) {
                var annex = ["cc.", "bbb", "GGG"];
                _place(dc, annex, pal, _fxOf(Sc.B_LAB) - 6, lgy2, lpx2 * 70 / 100, x0, w, true);
            }
            if (labL >= 5) {
                dc.setColor(0x5CE6D0, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(lcx - lpx2 * 2, ly - lpx2 * 2, 1, lpx2 * 2);
                dc.fillRectangle(lcx + lpx2 * 2, ly - lpx2 * 2, 1, lpx2 * 2);
            }
            _pips(dc, Sc.B_LAB, labL, lcx, ly - 5);
            _techBadge(dc, lcx, ly - 11, _techLvl(m, Sc.T_RES));
        }
    }

    // Emergency landing pod (colony start) with a blinking beacon.
    function _pxPod(dc, pal, cx, gF, px, phase) {
        var pod = ["..mmm..", ".mWWWm.", "mWWWWWm", "GkyykG.", "G.G.G.G"];
        Px.spr(dc, pod, pal, cx - pod[0].length() * px / 2, gF - pod.size() * px, px, false);
        var on = ((phase / 6) % 2) == 0;
        dc.setColor(on ? 0xFF5A5A : 0x662222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - px / 2, gF - pod.size() * px - px, px, px);
    }

    // Space elevator: ground anchor, a tall ribbon to the sky, a climbing car.
    // The ribbon stops below the tab strip band so the top of the watch stays
    // reserved for chrome instead of being bisected by a cable.
    function _pxElevator(dc, pal, ex, gB, y0, h, px, lvl, phase) {
        // Below the milestone caption, so the ribbon never runs through the text.
        var topY = y0 + h * 27 / 100;
        if (topY >= gB - px) { topY = gB - px * 2; }
        dc.setColor(0x445A70, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 1, topY, 3, gB - topY);
        // A lit edge and cross-braces every few pixels: a bare grey line read as
        // a scratch on the screen rather than a structure.
        dc.setColor(0x6A7A94, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 1, topY, 1, gB - topY);
        dc.setColor(0x33445A, Graphics.COLOR_TRANSPARENT);
        var rung = topY + px;
        while (rung < gB - px) {
            dc.fillRectangle(ex - 2, rung, 5, 1);
            rung += px * 2;
        }
        dc.setColor(0x8CD0FF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 2, gB - px * 2, 5, px * 2);          // base
        var span = gB - topY - px;
        if (span < 1) { span = 1; }
        var carY = topY + ((phase * 2) % span);
        dc.setColor(0xCDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 3, carY, 7, px);                     // climbing car
        // Counterweight anchor where the ribbon leaves the frame.
        var blink = ((phase / 5) % 2) == 0;
        dc.setColor(0x6A7A94, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 3, topY, 7, 2);
        dc.setColor(blink ? 0xFFFFFF : 0x33445A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 1, topY - 2, 3, 2);
        _pips(dc, Sc.B_ELEVATOR, lvl, ex, gB - px * 3);
    }

    // A little rover trundling back and forth on the front path, kicking up a
    // faint dust puff behind it in the direction it came from.
    function _pxRover(dc, pal, x0, w, gF, px, phase) {
        // Runs the width of the front deck only, which the round-display safe
        // area pins to 20..80% of the box.
        var span = w * 60 / 100;
        var t = (phase * 2) % (span * 2);
        var rel = (t < span) ? t : (span * 2 - t);
        var flip = (t >= span);
        var rx = x0 + w * 20 / 100 + rel;
        try {
            var dustX = flip ? rx + px : rx - px;
            var dustOn = ((phase / 2) % 3) != 0;
            if (dustOn) {
                dc.setColor(0x5A4636, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dustX, gF - px / 2, px / 2 + 1, px / 2 + 1);
            }
        } catch (e) {}
        var rover = [".ggg.", "gMMMg", "o...o"];
        Px.spr(dc, rover, pal, rx - rover[0].length() * px / 2, gF - rover.size() * px, px, flip);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DETAIL-CARD ARTWORK
    //
    // Chunky pixel portraits behind every detail card: a structure, a research
    // programme, a region survey or a recovered artifact, drawn large enough to
    // read as an object. Every entry gets its own silhouette so two cards are
    // never confusable at a glance.
    // ═══════════════════════════════════════════════════════════════════════
    function _sprC(dc, rows, pal, cx, cy, px) {
        var cols = rows[0].length();
        Px.spr(dc, rows, pal, cx - cols * px / 2, cy - rows.size() * px / 2, px, false);
    }

    // 7x6 portrait per building id (0..Sc.B_N-1).
    function bldArt(dc, id, cx, cy, px) {
        var rows; var pal;
        if (id == Sc.B_HABITAT) {
            pal = { "b" => 0x6FB3FF, "W" => 0xD8ECFF, "y" => 0xFFE79A, "G" => 0x3E4A5C, "K" => 0x2A3442 };
            rows = ["..bbb..", ".bWWWb.", "bbWWWbb", "bybybyb", "GGGGGGG", "K.K.K.K"];
        } else if (id == Sc.B_REACTOR) {
            pal = { "K" => 0x33445A, "G" => 0x4A5A6E, "o" => 0xFFB35A, "Y" => 0xFFF6C8 };
            rows = ["K.....K", "KGGGGGK", "KGoYoGK", "KGoooGK", "KGGGGGK", "KKKKKKK"];
        } else if (id == Sc.B_MINE) {
            pal = { "M" => 0x9FB0C0, "K" => 0x2E2A30, "s" => 0xC0A070 };
            rows = ["..M.M..", "..MMM..", ".M.M.M.", "KKMMMKK", "KsssssK", "KKKKKKK"];
        } else if (id == Sc.B_FARM) {
            pal = { "n" => 0x4CC85A, "W" => 0xCFF6C0, "N" => 0x2E7A38, "G" => 0x3E4A5C, "K" => 0x2A3442 };
            rows = [".nnnnn.", "nWnnnWn", "nNnNnNn", "nnnnnnn", "GGGGGGG", "K.K.K.K"];
        } else if (id == Sc.B_LAB) {
            pal = { "c" => 0x4CE0C0, "b" => 0x2A4A66, "W" => 0xCFFFF4, "G" => 0x3E4A5C };
            rows = ["...c...", "..ccc..", ".c...c.", ".bbbbb.", ".bWbWb.", "GGGGGGG"];
        } else if (id == Sc.B_LAUNCH) {
            pal = { "W" => 0xE0E6EC, "r" => 0xFF7A4A, "K" => 0x445A70, "o" => 0xFFA33A };
            rows = ["...W...", "..WWW..", "..WrW..", "..WWW..", "K.WWW.K", "KKoKoKK"];
        } else if (id == Sc.B_SAT) {
            pal = { "p" => 0xB46CFF, "c" => 0xC9D6E6, "W" => 0xFFFFFF, "g" => 0x5A6675, "k" => 0x33445A };
            rows = ["p.ccc.p", "p.cWc.p", "ppcccpp", "...g...", "...g...", ".kkkkk."];
        } else if (id == Sc.B_ALIEN) {
            pal = { "p" => 0x9A6CFF, "P" => 0x4A2A7A, "C" => 0x5CE6D0, "c" => 0xCFFFF4 };
            rows = ["..ppp..", ".p...p.", "p.CcC.p", "p.ccc.p", ".ppppp.", "PPPPPPP"];
        } else if (id == Sc.B_ELEVATOR) {
            pal = { "l" => 0x8CD0FF, "W" => 0xCDEEFF, "b" => 0x445A70, "K" => 0x2A3442 };
            rows = ["...l...", "...l...", "..WlW..", "...l...", ".bbbbb.", "KKKKKKK"];
        } else if (id == Sc.B_DEFENSE) {
            pal = { "r" => 0xFF5A7A, "B" => 0x8A2A38, "G" => 0x3E4A5C, "K" => 0x2A3442 };
            rows = [".....BB", "...rBB.", ".rrrB..", "rrrrr..", "GGGGGGG", "K.K.K.K"];
        } else if (id == Sc.B_GEO) {
            pal = { "s" => 0x6E7A88, "G" => 0x3E4A5C, "o" => 0xFFD24A, "O" => 0xC24A1A, "K" => 0x33445A };
            rows = ["..s.s..", ".G...G.", "GGGGGGG", "GoOoOoG", "GGGGGGG", "KKKKKKK"];
        } else if (id == Sc.B_TRADE) {
            pal = { "n" => 0x8CFF6A, "Y" => 0xFFC24A, "h" => 0xEAFFD8 };
            rows = [".nnnnn.", "n.....n", "n.YYY.n", "n.YhY.n", "n.YYY.n", ".nnnnn."];
        } else if (id == Sc.B_REFINERY) {
            pal = { "s" => 0x6E7A88, "M" => 0xD0A070, "G" => 0x5A4636, "m" => 0xE0E6EC, "K" => 0x33445A };
            rows = ["..s....", ".sMs...", "sMMMs..", "GGGGG..", "GGGGGmm", "KKKKKmm"];
        } else if (id == Sc.B_ICE) {
            pal = { "l" => 0x7FE8FF, "W" => 0xCFF4FF, "b" => 0x33AEE0, "G" => 0x3E4A5C, "K" => 0x33445A };
            rows = ["..lll..", ".lWWWl.", "lWWWWWl", "lllllll", "GbbbbbG", "KKKKKKK"];
        } else {
            pal = { "E" => 0xE06CFF, "W" => 0xFFFFFF };
            rows = ["..EEE..", ".E...E.", "E.WWW.E", "E.WWW.E", ".E...E.", "..EEE.."];
        }
        _sprC(dc, rows, pal, cx, cy, px);
    }

    // 6x6 emblem per technology id (0..Sc.T_N-1).
    function techArt(dc, id, cx, cy, px) {
        var rows; var pal;
        if (id == Sc.T_EFF) {
            pal = { "c" => 0x4CE0C0, "W" => 0xCFFFF4 };
            rows = [".c.c..", "cccccc", ".cWWc.", ".cWWc.", "cccccc", ".c.c.."];
        } else if (id == Sc.T_EXTR) {
            pal = { "M" => 0x9FB0C0, "o" => 0xFFC24A };
            rows = ["..MM..", "..MM..", ".MMMM.", ".MooM.", "..MM..", "...M.."];
        } else if (id == Sc.T_POWER) {
            pal = { "y" => 0xFFC24A };
            rows = ["...yy.", "..yy..", ".yyyy.", "..yy..", ".yy...", "yy...."];
        } else if (id == Sc.T_RES) {
            pal = { "c" => 0x4CE0C0, "W" => 0x0A1A18, "k" => 0x9FB0C0 };
            rows = [".k.k..", "cccccc", "cWccWc", "cccWcc", "cccccc", ".k.k.."];
        } else if (id == Sc.T_HYDRO) {
            pal = { "b" => 0x33AEE0, "W" => 0xCFF4FF };
            rows = ["..b...", "..bb..", ".bbbb.", "bbWbbb", "bbbbbb", ".bbbb."];
        } else if (id == Sc.T_TRADE) {
            pal = { "Y" => 0x8CFF6A, "h" => 0xEAFFD8 };
            rows = ["..YY..", ".YhhY.", "YhYYhY", "YhYYhY", ".YhhY.", "..YY.."];
        } else {
            pal = { "n" => 0x6CE07A };
            rows = ["n...n.", ".nnn..", "..n...", ".nnn..", "n...n.", ".nnn.."];
        }
        _sprC(dc, rows, pal, cx, cy, px);
    }

    // 7x6 survey vignette per region id (0..Sc.RG_N-1).
    function regionArt(dc, id, cx, cy, px) {
        var rows; var pal;
        if (id == Sc.RG_DESERT) {
            pal = { "o" => 0xFFC24A, "R" => 0xE0663A, "r" => 0x8A3A20 };
            rows = [".......", "..o....", ".......", "..RRRR.", "RRRRRRR", "rrrrrrr"];
        } else if (id == Sc.RG_FROZEN) {
            pal = { "l" => 0x8CD0FF, "W" => 0xF2F6FF, "b" => 0x3A6A9A };
            rows = ["...l...", "..lWl..", ".lWWWl.", "lWlWlWl", "lllllll", "bbbbbbb"];
        } else if (id == Sc.RG_CRYSTAL) {
            pal = { "p" => 0xB46CFF, "W" => 0xE0D0FF, "P" => 0x4A2A7A, "K" => 0x2A2038 };
            rows = ["..p.p..", ".pWpWp.", ".pWpWp.", "pPWpWPp", "PPPPPPP", "KKKKKKK"];
        } else if (id == Sc.RG_FOREST) {
            pal = { "n" => 0x4CC85A, "N" => 0x2E7A38, "s" => 0x6E4A32 };
            rows = ["..n.n..", ".nnnnn.", "nnnNnnn", "..s.s..", "..s.s..", "NNNNNNN"];
        } else if (id == Sc.RG_RUINS) {
            pal = { "C" => 0xC9A24A, "K" => 0x4A3A20 };
            rows = ["CCCCCCC", "C.....C", "CKCCCKC", "CKC.CKC", "CKC.CKC", "CCCCCCC"];
        } else if (id == Sc.RG_STORM) {
            pal = { "k" => 0x3A3A4A, "y" => 0xFFE45A, "O" => 0xFF8A2A, "R" => 0x8A3A10 };
            rows = ["kkkkkkk", "k.y.y.k", "..yy...", ".y.....", "OOOOOOO", "RRRRRRR"];
        } else if (id == Sc.RG_CAVERN) {
            pal = { "K" => 0x2A3018, "n" => 0x8CFF6A };
            rows = ["KKKKKKK", "K.K.K.K", "K..n..K", "K.nnn.K", "KnnnnnK", "KKKKKKK"];
        } else if (id == Sc.RG_OCEAN) {
            pal = { "W" => 0xF2F6FF, "l" => 0x7FE8FF, "b" => 0x33AEE0, "B" => 0x1E4A6E };
            rows = [".......", "..WW...", ".WWWWW.", "lllllll", "bbbbbbb", "BBBBBBB"];
        } else {
            pal = { "K" => 0x3A1A2A, "E" => 0xE06CFF, "W" => 0xFFE0FF };
            rows = ["KK...KK", "K.EEE.K", ".EWWWE.", ".EWWWE.", "K.EEE.K", "KK...KK"];
        }
        _sprC(dc, rows, pal, cx, cy, px);
    }

    // 6x6 portrait per alien artifact id (0..Sc.A_N-1).
    function artArt(dc, id, cx, cy, px) {
        var rows; var pal;
        if (id == Sc.A_GLASS) {
            pal = { "o" => 0xE0A050, "W" => 0xFFE9C0 };
            rows = ["...o..", "..oW..", ".oWWo.", ".oWo..", "..oo..", "...o.."];
        } else if (id == Sc.A_CHART) {
            pal = { "m" => 0x9FB0C0, "W" => 0xFFFFFF };
            rows = [".mmmm.", "m.W..m", "mW.W.m", "m..W.m", "m.W..m", ".mmmm."];
        } else if (id == Sc.A_LENS) {
            pal = { "l" => 0x7FE8FF, "W" => 0xF2F6FF };
            rows = ["..ll..", ".lWWl.", "lWWWWl", "lWWWWl", ".lWWl.", "..ll.."];
        } else if (id == Sc.A_SEED) {
            pal = { "p" => 0xB46CFF, "W" => 0xE0D0FF, "P" => 0x4A2A7A };
            rows = ["..p...", ".pWp..", ".pWp..", "pPWPp.", ".PPP..", "..P..."];
        } else if (id == Sc.A_SPORE) {
            pal = { "n" => 0x6CE07A, "N" => 0x2E7A38, "g" => 0xEAFFD8 };
            rows = ["..n...", ".nNn..", "nNNNn.", "nNgNn.", "nNNNn.", ".nnn.."];
        } else if (id == Sc.A_KEY) {
            pal = { "C" => 0xC9A24A };
            rows = [".CC...", "C..C..", "C..C..", ".CC...", "..C.CC", "..CCC."];
        } else if (id == Sc.A_COIL) {
            pal = { "y" => 0xFFC24A, "k" => 0x33445A };
            rows = [".yyy..", "y...y.", ".yyy..", "y...y.", ".yyy..", "..k..."];
        } else if (id == Sc.A_SIGIL) {
            pal = { "M" => 0x9FB0C0, "o" => 0xD0A070 };
            rows = ["MMMMMM", "M.oo.M", "Mo..oM", "Mo..oM", "M.oo.M", "MMMMMM"];
        } else if (id == Sc.A_TIDE) {
            pal = { "b" => 0x33AEE0, "W" => 0xCFF4FF };
            rows = ["..bb..", ".bWWb.", "bWbbWb", "bbWWbb", ".bbbb.", "..bb.."];
        } else if (id == Sc.A_EMBER) {
            pal = { "O" => 0xC24A1A, "Y" => 0xFFA33A, "W" => 0xFFF6C8 };
            rows = ["..OO..", ".OYYO.", "OYWWYO", "OYWWYO", ".OYYO.", "..OO.."];
        } else if (id == Sc.A_MASK) {
            pal = { "p" => 0x9A6CFF, "W" => 0xE0D0FF };
            rows = ["pppppp", "p.WW.p", "pW..Wp", "p.pp.p", "p.pp.p", ".pppp."];
        } else if (id == Sc.A_COMP) {
            pal = { "G" => 0xFFC24A, "W" => 0xFFFFFF };
            rows = [".GGGG.", "G..W.G", "G.WW.G", "G.W..G", "G....G", ".GGGG."];
        } else if (id == Sc.A_ECHO) {
            pal = { "M" => 0xC9D6E6, "p" => 0xE06CFF, "W" => 0xFFFFFF, "k" => 0x33445A };
            rows = [".MMMM.", "M.pp.M", "MpWWpM", "MpWWpM", "M.pp.M", "kMMMMk"];
        } else {
            pal = { "W" => 0xFFFFFF, "y" => 0xFFE9A0, "Y" => 0xFF5AC0 };
            rows = ["..W.W.", ".WyyW.", "WyYYyW", "WyYYyW", ".WyyW.", "..W.W."];
        }
        _sprC(dc, rows, pal, cx, cy, px);
    }

    // Colonists milling near the habitats (count scales with population).
    function _pxColonists(dc, pal, m, x0, w, gF, px, phase) {
        var pop = 1;
        try { pop = m.population; } catch (e) { pop = 1; }
        var n = pop; if (n > 6) { n = 6; }
        if (n < 1) { n = 1; }
        var cpx = px * 60 / 100; if (cpx < 2) { cpx = 2; }
        var person = [".y.", "bbb", ".b."];
        for (var i = 0; i < n; i++) {
            var baseX = x0 + w * (28 + i * 8) / 100;
            var wob = (((phase / 7) + i * 3) % 4) - 2;      // gentle shuffle
            var flip = (((phase / 13) + i) % 2) == 0;
            Px.spr(dc, person, pal, baseX + wob, gF - person.size() * cpx, cpx, flip);
        }
    }
}
