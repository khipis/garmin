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
        dc.setColor(0x351720, Graphics.COLOR_TRANSPARENT);
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
            dc.setColor(0x381620, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(kx, ky, craterR[ci] + 1);
            dc.setColor(0x281018, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(kx, ky, craterR[ci]);
        }
        // A jagged rock outcrop or two for extra texture.
        dc.setColor(0x30141C, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x0 + w * 4 / 100, horizon + px], [x0 + w * 10 / 100, horizon - px / 2], [x0 + w * 16 / 100, horizon + px]]);
        dc.fillPolygon([[x0 + w * 80 / 100, horizon + px], [x0 + w * 90 / 100, horizon - px * 2 / 3], [x0 + w * 96 / 100, horizon + px]]);

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
    function _pxNebula(dc, x0, y0, w, skyH) {
        if (skyH < 6) { return; }
        dc.setColor(0x160B28, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + w * 38 / 100, y0 + skyH * 42 / 100, skyH * 30 / 100);
        dc.fillCircle(x0 + w * 49 / 100, y0 + skyH * 32 / 100, skyH * 22 / 100);
        dc.setColor(0x221340, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + w * 42 / 100, y0 + skyH * 38 / 100, skyH * 18 / 100);
        dc.setColor(0x2E1A52, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + w * 45 / 100, y0 + skyH * 34 / 100, skyH * 10 / 100);
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
    function _skyTopCol(tier) {
        var a = [0x05070D, 0x06080F, 0x080A16, 0x0B0A1E];
        return a[Sc._c(tier, 0, 3)];
    }
    function _skyBotCol(tier) {
        var a = [0x2A123A, 0x321646, 0x3A1A56, 0x4A1E6E];
        return a[Sc._c(tier, 0, 3)];
    }
    function _terrainCol(tier, layer) {
        var deep = [0x241019, 0x261018, 0x28101A, 0x2A0F20];
        var mid  = [0x4A2530, 0x4E2732, 0x542A38, 0x5C2C42];
        var top  = [0x5E3038, 0x63333C, 0x6A3644, 0x74384E];
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
        for (var i = 0; i < bands; i++) {
            var r = prad + 3 + i * 3;
            var shimmer = ((phase / 4 + i) % 3);
            var col = (shimmer == 0) ? 0x2E7A6E : ((shimmer == 1) ? 0x3EA07A : 0x4CC89A);
            if (civ >= 6) { col = (shimmer == 0) ? 0x3A9A8A : ((shimmer == 1) ? 0x5AC8B0 : 0x8CF0C8); }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var a0 = 70 + ((phase / 5 + i * 7) % 8);
            dc.drawArc(cx, pcy, r, Graphics.ARC_COUNTER_CLOCKWISE, a0, a0 + 34);
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

    // Draw the colony structures + inhabitants (all bLevel-driven).
    function _pxColony(dc, m, x0, y0, w, h, px, pxB, gF, gB, cx, pal, phase, tier) {
        var bl;
        try { bl = m.bLevel; } catch (e) { bl = null; }
        if (bl == null) { return; }

        // A third, mid-depth terrace holds the late-game industry so the base
        // grows *backwards* into the scene instead of overlapping the front row.
        var gM = (gB + gF) / 2;
        var pxM = px * 90 / 100; if (pxM < 2) { pxM = 2; }

        var built = 0;
        try { built = m.buildingsBuilt(); } catch (e) {}

        // Ground path linking the front plots. Researching Efficiency gives it
        // a subtle golden power-hum pulse — a cheap, global tech "glow".
        dc.setColor(0x33222A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 + w * 10 / 100, gF - 2, w * 80 / 100, 3);
        if (_techLvl(m, Sc.T_EFF) > 0) {
            var effOn = ((phase / 6) % 6) < 3;
            dc.setColor(effOn ? 0xFFD98A : 0x8A6A2A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0 + w * 10 / 100, gF - 2, w * 80 / 100, 1);
        }

        // ── No buildings yet → the emergency landing pod ─────────────────────
        if (built == 0) {
            _pxPod(dc, pal, cx, gF, px, phase);
            _pxColonists(dc, pal, m, x0, w, gF, px, phase);
            return;
        }

        // ── BACK ROW (smaller, further away) ─────────────────────────────────
        // Space elevator: a tall landmark ribbon with a climbing car.
        if (bl[Sc.B_ELEVATOR] > 0) { _pxElevator(dc, pal, x0 + w * 52 / 100, gB, y0, pxB, bl[Sc.B_ELEVATOR], phase); }
        // Alien relic (glowing core pulse).
        if (bl[Sc.B_ALIEN] > 0) {
            var ap = ["..p..", ".ppp.", "p.C.p", ".pcp.", ".ppp.", "PPPPP"];
            var oy = _place(dc, ap, pal, 14, gB, pxB, x0, w, false);
            var glow = ((phase / 5) % 6) < 3;
            dc.setColor(glow ? 0x8CFFE0 : 0x2E9A86, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0 + w * 14 / 100 - pxB / 2, oy + 2 * pxB, pxB, pxB);
            _pips(dc, Sc.B_ALIEN, bl[Sc.B_ALIEN], x0 + w * 14 / 100, oy - 4);
            _techBadge(dc, x0 + w * 14 / 100, oy - 10, _techLvl(m, Sc.T_RES));
        }
        // Satellite station (dish + blinking uplink).
        if (bl[Sc.B_SAT] > 0) {
            var sp = [".cc..", "ccGc.", "..g..", "..g..", ".kgk."];
            var oy2 = _place(dc, sp, pal, 32, gB, pxB, x0, w, ((phase / 20) % 2) == 0);
            var up = ((phase / 4) % 2) == 0;
            dc.setColor(up ? 0xFFFFFF : 0x2A4A66, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0 + w * 32 / 100 - pxB, oy2 - pxB, pxB / 2 + 1, pxB / 2 + 1);
            _pips(dc, Sc.B_SAT, bl[Sc.B_SAT], x0 + w * 32 / 100, oy2 - pxB - 4);
        }
        // Mine rig (headframe + growing ore pile).
        if (bl[Sc.B_MINE] > 0) {
            var mp = ["..o..", ".ooo.", ".G.G.", ".G.G.", "GGGGG", "sMMMs"];
            var oy3 = _place(dc, mp, pal, 72, gB, pxB, x0, w, false);
            var ore = bl[Sc.B_MINE]; if (ore > 4) { ore = 4; }
            dc.setColor(0xB0BCC8, Graphics.COLOR_TRANSPARENT);
            for (var oi = 0; oi < ore; oi++) {
                dc.fillRectangle(x0 + w * 72 / 100 + pxB + oi * pxB / 2, gB - pxB, pxB / 2 + 1, pxB / 2 + 1);
            }
            _pips(dc, Sc.B_MINE, bl[Sc.B_MINE], x0 + w * 72 / 100, oy3 - 4);
            _techBadge(dc, x0 + w * 72 / 100, oy3 - 10, _techLvl(m, Sc.T_EXTR));
        }
        // Quantum core: a hovering, pulsing singularity ring — the endgame
        // landmark, so the very last unlock is unmistakable on the skyline.
        if (_lv(bl, Sc.B_QUANTUM) > 0) {
            var qx = x0 + w * 88 / 100;
            var qr = pxB + pxB / 2; if (qr < 3) { qr = 3; }
            var qy = gB - pxB * 4 - ((phase / 9) % 3);
            dc.setColor(0x2A1440, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(qx - pxB * 2, gB - pxB, pxB * 4, pxB);
            dc.setColor(Sc.bColor(Sc.B_QUANTUM), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(qx, qy, qr + 2);
            dc.fillCircle(qx, qy, qr);
            var qlit = ((phase / 5) % 6) < 3;
            dc.setColor(qlit ? 0xFFFFFF : 0xE0D0FF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(qx, qy, qr / 2 + 1);
            dc.setColor(0x8C6ACF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(qx, qy + qr, qx, gB - pxB);
            _pips(dc, Sc.B_QUANTUM, _lv(bl, Sc.B_QUANTUM), qx, qy - qr - 6);
            _techBadge(dc, qx, qy - qr - 12, _techLvl(m, Sc.T_EFF));
        }

        // ── MID ROW — late-game industry terrace ─────────────────────────────
        var midAny = _lv(bl, Sc.B_GEO) + _lv(bl, Sc.B_TRADE)
                   + _lv(bl, Sc.B_REFINERY) + _lv(bl, Sc.B_ICE);
        if (midAny > 0) {
            dc.setColor(0x2C1D24, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0 + w * 8 / 100, gM - 1, w * 84 / 100, 2);
        }
        // Geothermal plant: squat vent housing with a magma glow + steam plume.
        if (_lv(bl, Sc.B_GEO) > 0) {
            var geo = ["GGGGG", "GoooG", "GGGGG", "kkkkk"];
            var gy2 = _place(dc, geo, pal, 16, gM, pxM, x0, w, false);
            var gcx = x0 + w * 16 / 100;
            var hot = ((phase / 4) % 8) < 4;
            dc.setColor(hot ? 0xFFD24A : 0xC24A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(gcx - pxM, gy2 + pxM, pxM * 2, pxM);
            var puff = (phase / 6) % 3;
            dc.setColor(0x6E7A88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(gcx - pxM / 2, gy2 - pxM * (1 + puff), pxM, pxM);
            _pips(dc, Sc.B_GEO, _lv(bl, Sc.B_GEO), gcx, gy2 - pxM * 4 - 2);
            _techBadge(dc, gcx, gy2 - pxM * 4 - 8, _techLvl(m, Sc.T_POWER));
        }
        // Trade hub: market pad under a blinking landing beacon.
        if (_lv(bl, Sc.B_TRADE) > 0) {
            var trd = [".nnn.", "nnnnn", "GyGyG", "kkkkk"];
            var ty2 = _place(dc, trd, pal, 39, gM, pxM, x0, w, false);
            var tcx = x0 + w * 39 / 100;
            var beac = ((phase / 5) % 4) < 2;
            dc.setColor(beac ? 0xEAFFD8 : 0x2E6E30, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tcx - pxM / 2, ty2 - pxM, pxM, pxM);
            _pips(dc, Sc.B_TRADE, _lv(bl, Sc.B_TRADE), tcx, ty2 - pxM - 5);
            _techBadge(dc, tcx, ty2 - pxM - 11, _techLvl(m, Sc.T_TRADE));
        }
        // Refinery: smelter stack with a growing ingot stack at its foot.
        if (_lv(bl, Sc.B_REFINERY) > 0) {
            var rfn = ["..s..", ".sMs.", "sMMMs", "GGGGG", "kkkkk"];
            var fy2 = _place(dc, rfn, pal, 61, gM, pxM, x0, w, false);
            var fcx = x0 + w * 61 / 100;
            var ing = _lv(bl, Sc.B_REFINERY); if (ing > 4) { ing = 4; }
            dc.setColor(0xE0E6EC, Graphics.COLOR_TRANSPARENT);
            for (var ii = 0; ii < ing; ii++) {
                dc.fillRectangle(fcx + pxM * 2 + ii * pxM / 2, gM - pxM, pxM / 2 + 1, pxM / 2 + 1);
            }
            var smoke = (phase / 7) % 3;
            dc.setColor(0x5A4636, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fcx - pxM / 2, fy2 - pxM * (1 + smoke), pxM, pxM);
            _pips(dc, Sc.B_REFINERY, _lv(bl, Sc.B_REFINERY), fcx, fy2 - pxM * 4 - 2);
            _techBadge(dc, fcx, fy2 - pxM * 4 - 8, _techLvl(m, Sc.T_EXTR));
        }
        // Ice works: melt tank with a shimmering waterline.
        if (_lv(bl, Sc.B_ICE) > 0) {
            var ice = [".lll.", "lWWWl", "GlllG", "kkkkk"];
            var iy2 = _place(dc, ice, pal, 84, gM, pxM, x0, w, false);
            var icx = x0 + w * 84 / 100;
            var shim = ((phase / 6) % 4);
            dc.setColor(shim < 2 ? 0xCFF4FF : 0x33AEE0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(icx - pxM + shim, iy2 + pxM, pxM, pxM / 2 + 1);
            _pips(dc, Sc.B_ICE, _lv(bl, Sc.B_ICE), icx, iy2 - 5);
            _techBadge(dc, icx, iy2 - 11, _techLvl(m, Sc.T_HYDRO));
        }

        // ── FRONT ROW ────────────────────────────────────────────────────────
        // Fusion reactor: a squat housing with a pulsing glowing core visible
        // through its porthole, flanked by cooling fins that grow with level —
        // the signature glow of the colony's Energy source.
        if (bl[Sc.B_REACTOR] > 0) {
            var rlvl = bl[Sc.B_REACTOR];
            var body = ["kGGGGGk", "kGGGGGk", "kGGGGGk", "kkkkkkk"];
            var baseX = x0 + w * 12 / 100;
            var ry = _place(dc, body, pal, 12, gF, px, x0, w, false);
            var bw = body[0].length() * px;
            var bh = body.size() * px;
            var coreY = ry + bh * 55 / 100;
            var pulse = ((phase / 5) % 10);
            var lit = pulse < 5;
            var coreR = px * 90 / 100 + (rlvl >= 3 ? px / 3 : 0); if (coreR < 2) { coreR = 2; }
            // Soft outer vignette/halo behind the housing — two faint rings
            // that widen at higher civ tiers, so the reactor visibly reads as
            // more powerful once the colony has matured.
            try {
                var haloR = coreR + px + tier * px / 2;
                dc.setColor(tier >= 2 ? 0x3A2E12 : 0x241C0A, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(baseX, coreY, haloR);
                dc.drawCircle(baseX, coreY, haloR + 2);
            } catch (e) {}
            dc.setColor(0x0C1420, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(baseX, coreY, coreR + 2);
            dc.setColor(lit ? (tier >= 3 ? 0xFFF6C8 : 0xFFF0A0) : 0xC9922A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(baseX, coreY, coreR);
            if (lit) {
                dc.setColor(tier >= 3 ? 0xFFE7A0 : 0xFFF0A0, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(baseX, coreY, coreR + 2);
            }
            // Cooling fins on each flank grow in count with reactor level (up to 3).
            var fins = rlvl; if (fins > 3) { fins = 3; }
            dc.setColor(Sc.bColorDark(Sc.B_REACTOR), Graphics.COLOR_TRANSPARENT);
            var finH = bh - px * 2; if (finH < px) { finH = px; }
            for (var fi = 0; fi < fins; fi++) {
                dc.fillRectangle(baseX - bw / 2 - px / 2 - fi * px * 3 / 4, ry + px, px / 2 + 1, finH);
                dc.fillRectangle(baseX + bw / 2 - px / 4 + fi * px * 3 / 4, ry + px, px / 2 + 1, finH);
            }
            _pips(dc, Sc.B_REACTOR, rlvl, baseX, ry - 5);
            _techBadge(dc, baseX, ry - 11, _techLvl(m, Sc.T_POWER));
            // Solar array in front of the reactor — panels grow with level and
            // catch a slow sun-glint sweep for a little life.
            try { _pxSolar(dc, baseX, gF, px, bw, rlvl, phase); } catch (e) {}
        }
        // Habitat: glass dome, with annex domes appearing as level grows. Every
        // module's windows blink independently (phase-offset per module) so
        // the base looks properly inhabited instead of a static painting.
        if (bl[Sc.B_HABITAT] > 0) {
            var dome = ["..bbb..", ".bWbbb.", "bbbbbbb", "GyGyGyG", "GGGGGGG"];
            var lvl = bl[Sc.B_HABITAT];
            var mini = [".bbb.", "bbbbb", "GyGyG"];
            var hy;
            try { hy = _pxDomeBlink(dc, pal, dome, 3, [1, 3, 5], x0, w, gF, px, 28, phase, 0, false); }
            catch (e) { hy = _place(dc, dome, pal, 28, gF, px, x0, w, false); }
            if (lvl >= 3) {
                try { _pxDomeBlink(dc, pal, mini, 2, [1, 3], x0, w, gF, px, 34, phase, 3, false); } catch (e) {}
            }
            if (lvl >= 5) {
                try { _pxDomeBlink(dc, pal, mini, 2, [1, 3], x0, w, gF, px, 22, phase, 6, true); } catch (e) {}
            }
            _pips(dc, Sc.B_HABITAT, lvl, x0 + w * 28 / 100, hy - 4);
        }
        // Hydro-farm (green biodome).
        if (bl[Sc.B_FARM] > 0) {
            var farm = [".nnnn.", "nnnnnn", "GnGnnG", "GGGGGG"];
            var fy = _place(dc, farm, pal, 44, gF, px, x0, w, false);
            _pips(dc, Sc.B_FARM, bl[Sc.B_FARM], x0 + w * 44 / 100, fy - 4);
        }
        // Laboratory with a subtly-rotating dish.
        if (bl[Sc.B_LAB] > 0) {
            var lab = ["...c...", "..ccc..", ".bbbbb.", "GyGyGyG", "GGGGGGG"];
            var ly = _place(dc, lab, pal, 60, gF, px, x0, w, false);
            var dishx = x0 + w * 60 / 100 + (((phase / 8) % 3) - 1) * px;
            dc.setColor(0xCFFFF4, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dishx - px / 2, ly - px, px / 2 + 1, px / 2 + 1);
            _pips(dc, Sc.B_LAB, bl[Sc.B_LAB], x0 + w * 60 / 100, ly - 5);
            _techBadge(dc, x0 + w * 60 / 100, ly - 11, _techLvl(m, Sc.T_RES));
        }
        // Defense turret (rotating scan blip).
        if (bl[Sc.B_DEFENSE] > 0) {
            var def = ["....B", ".rrBB", "rrrr.", "GGGGG"];
            var dy = _place(dc, def, pal, 75, gF, px, x0, w, ((phase / 24) % 2) == 0);
            _pips(dc, Sc.B_DEFENSE, bl[Sc.B_DEFENSE], x0 + w * 75 / 100, dy - 4);
        }
        // Landing pad + rocket with flickering exhaust.
        if (bl[Sc.B_LAUNCH] > 0) {
            var padx = x0 + w * 89 / 100;
            dc.setColor(0x445A70, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(padx - px * 3, gF - 2, px * 6, 3);
            var rocket = ["..W..", ".WWW.", ".WrW.", ".WWW.", ".WWW.", "r.W.r"];
            var ry = _place(dc, rocket, pal, 89, gF, px, x0, w, false);
            var flame = ((phase / 3) % 3);
            if (flame > 0) {
                dc.setColor(flame == 1 ? 0xFFE45A : 0xFF9A3A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(padx - px, gF, px * 2, px + flame);
                dc.setColor(0xFFF0C0, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(padx - px / 2, gF, px, px / 2 + 1);
            }
            _pips(dc, Sc.B_LAUNCH, bl[Sc.B_LAUNCH], x0 + w * 89 / 100, ry - 4);
        }

        // A rover crawling along the front path + colonists milling about.
        _pxRover(dc, pal, x0, w, gF, px, phase);
        _pxColonists(dc, pal, m, x0, w, gF, px, phase);
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
    function _pxElevator(dc, pal, ex, gB, y0, px, lvl, phase) {
        var topY = y0 + 4;
        dc.setColor(0x445A70, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 1, topY, 3, gB - topY);
        dc.setColor(0x8CD0FF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 2, gB - px * 2, 5, px * 2);          // base
        var span = gB - topY - px;
        if (span < 1) { span = 1; }
        var carY = topY + ((phase * 2) % span);
        dc.setColor(0xCDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 3, carY, 7, px);                     // climbing car
        var blink = ((phase / 5) % 2) == 0;
        dc.setColor(blink ? 0xFFFFFF : 0x33445A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 1, topY, 3, 3);                      // top light
        _pips(dc, Sc.B_ELEVATOR, lvl, ex, topY - 5);
    }

    // A little rover trundling back and forth on the front path, kicking up a
    // faint dust puff behind it in the direction it came from.
    function _pxRover(dc, pal, x0, w, gF, px, phase) {
        var span = w * 74 / 100;
        var t = (phase * 2) % (span * 2);
        var rel = (t < span) ? t : (span * 2 - t);
        var flip = (t >= span);
        var rx = x0 + w * 13 / 100 + rel;
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

    // Colonists milling near the habitats (count scales with population).
    function _pxColonists(dc, pal, m, x0, w, gF, px, phase) {
        var pop = 1;
        try { pop = m.population; } catch (e) { pop = 1; }
        var n = pop; if (n > 6) { n = 6; }
        if (n < 1) { n = 1; }
        var cpx = px * 60 / 100; if (cpx < 2) { cpx = 2; }
        var person = [".y.", "bbb", ".b."];
        for (var i = 0; i < n; i++) {
            var baseX = x0 + w * (26 + i * 7) / 100;
            var wob = (((phase / 7) + i * 3) % 4) - 2;      // gentle shuffle
            var flip = (((phase / 13) + i) % 2) == 0;
            Px.spr(dc, person, pal, baseX + wob, gF - person.size() * cpx, cpx, flip);
        }
    }
}
