// ═══════════════════════════════════════════════════════════════════════════
// DsArt.mc — The look of the game: four arenas, the rig, the ball.
//
// Everything is drawn from primitives, no bitmaps, so the whole art budget is
// code. Two rules shape all of it:
//
//   1. The top fifth of the screen stays dark. The HUD lives there, and a
//      bright sky behind white numerals is unreadable on a transflective
//      display in sunlight.
//   2. Every colour is built from the 0x00 / 0x55 / 0xAA / 0xFF channel
//      levels a Garmin MIP panel can actually show, so what is composed here
//      is what appears on the wrist — no quantisation surprises.
//
// The four courts are not palette swaps: each one is a different scene with
// its own skyline, light and floor, because the court is the reward the
// streak pays out and it has to feel like one.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

const DS_CT_STREET = 0;
const DS_CT_NIGHT  = 1;
const DS_CT_BEACH  = 2;
const DS_CT_ARENA  = 3;

module DsArt {

    // ── Scene: sky, distance, floor ─────────────────────────────────────────
    // The horizon sits a quarter of a screen above the bounce plane, so the
    // court runs away from the viewer instead of standing up like a wall, and
    // the shooter and the rig both have sky behind their heads.
    function scene(dc, court as Lang.Number, w as Lang.Number, h as Lang.Number,
                   floorY as Lang.Number, t as Lang.Number) as Void {
        var hz = floorY - (h * 24) / 100;
        if      (court == DS_CT_NIGHT) { _skyNight(dc, w, h, hz, t); }
        else if (court == DS_CT_BEACH) { _skyBeach(dc, w, h, hz, floorY, t); }
        else if (court == DS_CT_ARENA) { _skyArena(dc, w, h, hz, t); }
        else                           { _skyStreet(dc, w, h, hz, t); }
        _floor(dc, court, w, h, hz, floorY);
    }

    // Weighted gradient bands from `y0` down to `y1`. The weights matter as
    // much as the colours: the sky has to stay mostly black behind the HUD and
    // only catch fire in the last stretch above the horizon.
    function _ramp(dc, y0 as Lang.Number, y1 as Lang.Number,
                   cols as Lang.Array, wts as Lang.Array,
                   w as Lang.Number) as Void {
        var span = y1 - y0;
        if (span <= 0) { return; }
        var total = 0;
        for (var i = 0; i < wts.size(); i++) { total = total + wts[i]; }
        if (total <= 0) { return; }
        var acc = 0;
        for (var i = 0; i < cols.size(); i++) {
            var a = y0 + (span * acc) / total;
            acc = acc + wts[i];
            var b = y0 + (span * acc) / total;
            dc.setColor(cols[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, a, w, b - a + 1);
        }
    }

    // One rank of towers, black against the glow. A single bold silhouette
    // beats two hazy ones: stacking ranks on top of a banded sky turns the
    // whole backdrop into stripes.
    //
    // `seed` keeps a given court identical from frame to frame — the skyline
    // is scenery, and scenery that shimmers is a bug.
    function _skyline(dc, w as Lang.Number, baseY as Lang.Number,
                      maxH as Lang.Number, body as Lang.Number,
                      lit as Lang.Number, seed as Lang.Number) as Void {
        var x = -6;
        var i = 0;
        var unit = maxH / 5; if (unit < 3) { unit = 3; }
        while (x < w) {
            var bw = 15 + ((i * 7 + seed) % 5) * 7;
            var bh = unit * (1 + ((i * 13 + seed) % 5));
            dc.setColor(body, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, baseY - bh, bw, bh);

            // Roof furniture: an antenna or a water tank on the tall ones.
            if (bh >= maxH * 4 / 5) {
                if (((i + seed) % 2) == 0) {
                    dc.fillRectangle(x + bw / 2, baseY - bh - unit, 2, unit);
                } else {
                    dc.fillRectangle(x + bw / 4, baseY - bh - unit / 2,
                                     bw / 2, unit / 2);
                }
            }

            // Lit windows, in a grid that thins out toward the top floors.
            if (bh > unit * 2) {
                dc.setColor(lit, Graphics.COLOR_TRANSPARENT);
                var step = unit * 2 / 3; if (step < 5) { step = 5; }
                var cols = (bw > 24) ? 3 : 2;
                for (var r = 0; r < 5; r++) {
                    var wy = baseY - bh + step / 2 + r * step;
                    if (wy > baseY - step) { break; }
                    for (var c = 0; c < cols; c++) {
                        if (((i * 5 + r * 3 + c * 7 + seed) % 4) == 0) { continue; }
                        dc.fillRectangle(x + 4 + c * ((bw - 6) / cols), wy, 3, 3);
                    }
                }
            }
            x = x + bw + 4;
            i = i + 1;
        }
    }

    // ── STREET: dusk over the city, chain-link at the back ──────────────────
    function _skyStreet(dc, w, h, hz, t) as Void {
        // Eight stops, not four: the 64-colour panel has enough purples and
        // reds between navy and orange to make a sunset that reads as a
        // gradient instead of as stripes.
        // Nearly two thirds of the sky is black — the HUD lives up there — and
        // all of the colour is packed into the stretch just above the roofs.
        _ramp(dc, 0, hz,
              [0x000000, 0x000055, 0x550055, 0xAA0055, 0xAA5500,
               0xFF5500, 0xFFAA00],
              [58, 10, 8, 8, 7, 6, 3], w);

        // Low sun sitting behind the towers.
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((w * 32) / 100, hz - (h * 7) / 100, (h * 6) / 100);
        dc.setColor(0xFFFF55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((w * 32) / 100, hz - (h * 7) / 100, (h * 35) / 1000);

        _skyline(dc, w, hz, (h * 26) / 100, 0x000000, 0xFFAA00, 1);
    }

    // ── NIGHT: moonlight, neon lines, floodlights ───────────────────────────
    function _skyNight(dc, w, h, hz, t) as Void {
        _ramp(dc, 0, hz,
              [0x000000, 0x000055, 0x0000AA, 0x0055AA, 0x00AAAA],
              [62, 14, 10, 9, 5], w);

        // Fixed star field — index-derived, so it never twinkles into noise.
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 14; i++) {
            var sx = (w * ((i * 37 + 11) % 100)) / 100;
            var sy = (h * ((i * 23 + 7) % 40)) / 100;
            dc.fillCircle(sx, sy, ((i % 4) == 0) ? 2 : 1);
        }

        // Moon.
        var mr = (h * 5) / 100;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((w * 20) / 100, (h * 22) / 100, mr);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((w * 20) / 100 - mr / 3, (h * 22) / 100 - mr / 4, mr / 4);
        dc.fillCircle((w * 20) / 100 + mr / 3, (h * 22) / 100 + mr / 3, mr / 5);

        // Order matters and there is no alpha on these panels: the light cone
        // is laid down first so the city occludes it, and the mast goes on
        // last because it stands on the court, in front of everything.
        var mx = (w * 10) / 100;
        var my = (h * 30) / 100;
        dc.setColor(0x0055AA, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[mx - 6, my], [mx + 8, my],
                        [(w * 62) / 100, hz], [(w * 2) / 100, hz]]);

        _skyline(dc, w, hz, (h * 24) / 100, 0x000000, 0x00AAFF, 5);

        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mx, my, 3, hz - my);
        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mx - 6, my - 5, 13, 5);
    }

    // ── BEACH: sunset over water ────────────────────────────────────────────
    function _skyBeach(dc, w, h, hz, floorY, t) as Void {
        _ramp(dc, 0, hz,
              [0x000000, 0x000055, 0x550055, 0xAA0055, 0xAA5500,
               0xFF5500, 0xFFAA00, 0xFFAA55],
              [40, 11, 10, 10, 9, 8, 7, 5], w);

        // Sun half-set on the waterline.
        var sx = (w * 62) / 100;
        var sr = (h * 7) / 100;
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, hz - sr / 2, sr);
        dc.setColor(0xFFFF55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, hz - sr / 2, sr * 3 / 5);

        // Sea: a strip of water between the horizon and the top of the sand,
        // with a glitter path drifting under the sun.
        var seaH = (h * 9) / 100;
        dc.setColor(0x0055AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, hz, w, seaH);
        dc.setColor(0x00AAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, hz, w, 2);
        dc.setColor(0xFFAA55, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var wy = hz + 3 + i * (seaH / 5);
            var off = ((t / 3 + i * 5) % 14) - 7;
            dc.fillRectangle(sx - 10 + off, wy, 9 + i * 3, 2);
        }
        // Surf line where the water meets the sand.
        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, hz + seaH - 2, w, 3);

        // Palms stand at the waterline, not in the water.
        _palm(dc, (w * 12) / 100, hz + seaH, (h * 22) / 100);
        _palm(dc, (w * 26) / 100, hz + seaH, (h * 15) / 100);
    }

    function _palm(dc, x as Lang.Number, baseY as Lang.Number,
                          ht as Lang.Number) as Void {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(x, baseY, x - ht / 6, baseY - ht);
        var tx = x - ht / 6;
        var ty = baseY - ht;
        dc.setPenWidth(2);
        dc.drawLine(tx, ty, tx - ht / 3, ty - ht / 8);
        dc.drawLine(tx, ty, tx + ht / 3, ty - ht / 7);
        dc.drawLine(tx, ty, tx - ht / 4, ty + ht / 6);
        dc.drawLine(tx, ty, tx + ht / 4, ty + ht / 5);
        dc.setPenWidth(1);
    }

    // ── ARENA: tiered crowd under the lights ────────────────────────────────
    function _skyArena(dc, w, h, hz, t) as Void {
        _ramp(dc, 0, hz,
              [0x000000, 0x000055, 0x550055, 0xAA00AA],
              [44, 22, 20, 14], w);

        // Two rigged spotlights washing down onto the floor. They start below
        // the HUD band — a solid wedge behind the score would cost more in
        // legibility than it buys in atmosphere.
        var ly = (h * 20) / 100;
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[(w * 32) / 100, ly], [(w * 43) / 100, ly],
                        [(w * 62) / 100, hz], [(w * 24) / 100, hz]]);
        dc.fillPolygon([[(w * 63) / 100, ly], [(w * 73) / 100, ly],
                        [(w * 92) / 100, hz], [(w * 58) / 100, hz]]);

        // Crowd: three tiers stacked above the boards, a couple of camera
        // flashes going off somewhere in the stands on every frame.
        var tiers = [0x5500AA, 0xAA00AA, 0x550055];
        for (var r = 0; r < 3; r++) {
            var y = hz - (h * (17 - r * 5)) / 100;
            dc.setColor(tiers[r], Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 15; i++) {
                dc.fillCircle((w * (3 + i * 7)) / 100, y, 3 - r / 2);
            }
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var f = 0; f < 2; f++) {
            var k = (t / 4 + f * 7) % 15;
            var ry = hz - (h * (17 - (k % 3) * 5)) / 100;
            dc.fillCircle((w * (3 + k * 7)) / 100, ry, 2);
        }

        // Sponsor board running along the back of the floor.
        var bh = (h * 4) / 100;
        dc.setColor(0xAA0000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, hz - bh, w, bh);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var d = 0; d < 9; d++) {
            dc.fillRectangle((w * (4 + d * 11)) / 100, hz - bh + bh / 3,
                             (w * 5) / 100, 2);
        }
    }

    // ── The court ───────────────────────────────────────────────────────────
    // Two planes: the deck behind the play, running back to the horizon, and
    // the strip in front of the bounce line. Splitting them is what gives the
    // court depth without a single perspective calculation.
    function _floor(dc, court as Lang.Number, w as Lang.Number,
                    h as Lang.Number, hz as Lang.Number,
                    floorY as Lang.Number) as Void {
        var deck = 0x555555; var line = 0xAAAAAA; var grain = 0x000000;
        if (court == DS_CT_NIGHT) { deck = 0x000055; line = 0x00AAFF; grain = 0x0055AA; }
        if (court == DS_CT_BEACH) { deck = 0xFFAA55; line = 0xFFFFAA; grain = 0xFFAA00; }
        if (court == DS_CT_ARENA) { deck = 0xAA5500; line = 0xFFAA55; grain = 0x550000; }

        var top = (court == DS_CT_BEACH) ? hz + (h * 9) / 100 : hz;

        dc.setColor(deck, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, top, w, h - top);

        // Boards fanning out from a vanishing point behind the rig. They stop
        // at the bounce line: everything in front of it is the apron, and the
        // apron stays empty because that is where the meters are drawn.
        dc.setColor(grain, Graphics.COLOR_TRANSPARENT);
        var vx = (w * 72) / 100;
        for (var i = -3; i <= 3; i++) {
            if (i == 0) { continue; }
            dc.drawLine(vx, top, vx + i * (w * 30) / 100, floorY);
        }

        // Markings: the back edge of the deck, the key arcing away toward the
        // rig, and the bounce line last so it caps the arc cleanly.
        dc.setColor(line, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, top, w, 2);
        dc.drawArc((w * 70) / 100, floorY, (w * 17) / 100,
                   Graphics.ARC_COUNTER_CLOCKWISE, 12, 168);
        dc.fillRectangle(0, floorY, w, 2);
    }

    // ── The rig: pole, backboard, ring, net ─────────────────────────────────
    // `wave` is the net's whip, 0 at rest and 1 right after a make.
    function hoopArt(dc, court as Lang.Number, hp, w as Lang.Number,
                     h as Lang.Number, floorY as Lang.Number,
                     wave as Lang.Float, flash as Lang.Boolean) as Void {
        var hx   = hp.x.toNumber();
        var hy   = hp.y.toNumber();
        var half = (hp.w / 2.0).toNumber();
        var bx   = hp.boardX().toNumber();
        var bTop = hp.boardTop().toNumber();
        var bBot = hp.boardBot().toNumber();
        var bw   = (w * 14) / 1000; if (bw < 4) { bw = 4; }

        var steel = (court == DS_CT_NIGHT) ? 0xAAAAAA : 0x555555;

        // Mast set back from the glass, with a short arm to the board.
        var poleX = bx + bw + (w * 40) / 1000;
        if (poleX > w - 5) { poleX = w - 5; }
        dc.setColor(steel, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(poleX, bTop + 4, 4, floorY - bTop - 4);
        dc.fillRectangle(bx + bw, bBot - 6, poleX - bx - bw, 4);
        dc.fillRectangle(poleX - 4, floorY - 3, 12, 3);

        // Backboard: white glass, dark frame, and the shooter's square.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, bTop, bw, bBot - bTop);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(bx, bTop, bw, bBot - bTop);
        dc.setColor(DS_ACCENT, Graphics.COLOR_TRANSPARENT);
        var sqTop = hy - (bBot - bTop) / 3;
        dc.fillRectangle(bx + 1, sqTop, 2, hy - sqTop + 2);

        _net(dc, hx, hy, half, (hp.w * 0.55).toNumber(), wave, court);

        // The ring, on top of the net so the opening always reads.
        var ring = flash ? 0xFFFFFF : DS_ACCENT;
        dc.setColor(ring, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(hx - half, hy - 2, half * 2, 5, 2);
        dc.setColor(flash ? 0xFFFFAA : 0xAA5500, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(hx - half, hy + 3, half * 2, 1);
        dc.setColor(flash ? 0xFFFFFF : 0xFFAA55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hx - half, hy, 3);
        dc.fillCircle(hx + half, hy, 3);
    }

    // Mesh: strands converging to the throat, crossed by two hoops of cord.
    // The whip pushes the throat sideways so a make visibly snaps the net.
    function _net(dc, hx as Lang.Number, hy as Lang.Number,
                         half as Lang.Number, netH as Lang.Number,
                         wave as Lang.Float, court as Lang.Number) as Void {
        var sway = (wave * half * 0.45).toNumber();
        var tw   = half / 2 + (wave * half / 4).toNumber();   // throat half-width
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i <= 4; i++) {
            var sx = hx - half + (half * 2 * i) / 4;
            var ex = hx - tw + (tw * 2 * i) / 4 + sway;
            dc.drawLine(sx, hy + 2, ex, hy + netH);
        }
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        for (var r = 1; r <= 2; r++) {
            var f  = r / 3.0;
            var y  = hy + 2 + (netH * r) / 3;
            var hw = (half + (tw - half) * f).toNumber();
            var cx = hx + (sway * f).toNumber();
            dc.drawLine(cx - hw, y, cx + hw, y);
        }
    }

    // ── The shooter ─────────────────────────────────────────────────────────
    // `crouch` 0..1 sinks the hips into the load, `arm` 0..1 extends the
    // shooting arm to the release point. The ball always hangs at (bx, by),
    // which is the physics release point — the body is posed around it.
    function shooterArt(dc, court as Lang.Number, bx as Lang.Number,
                        by as Lang.Number, floorY as Lang.Number,
                        br as Lang.Number, hr as Lang.Number,
                        crouch as Lang.Float, arm as Lang.Float,
                        t as Lang.Number) as Void {
        // The kit has to fight the deck it stands on, so light courts get a
        // dark figure and dark courts get a bright one.
        var kit  = 0xFFFFFF;
        var trim = DS_ACCENT;
        var dark = 0x000000;      // shorts and legs
        if (court == DS_CT_NIGHT) { kit = 0x00AAFF; trim = 0xFFFFFF; dark = 0xAAAAAA; }
        if (court == DS_CT_BEACH) { kit = 0x0055AA; trim = 0xFFFF55; dark = 0x000055; }
        if (court == DS_CT_ARENA) { kit = 0xFFFFFF; trim = 0xFF0000; dark = 0x000000; }
        var skin = 0xFFAA55;

        var sink   = (crouch * hr).toNumber();
        var headX  = bx - hr - 2;
        var headY  = by + br + hr + 4 + sink;
        var torsoY = headY + hr;
        var torsoH = hr * 3;
        var hipY   = torsoY + torsoH;

        // Contact shadow — grounds the figure on the deck.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(headX - hr - 2, floorY - 2, hr * 2 + 6, 4, 2);

        // Legs: knees track the load, back foot rises on the follow-through.
        var spread = hr + (crouch * hr / 2).toNumber();
        var rise   = ((1.0 - crouch) * arm * hr / 2).toNumber();
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(headX, hipY, headX - spread, floorY - rise);
        dc.drawLine(headX, hipY, headX + spread, floorY);
        dc.setPenWidth(1);

        // Shorts and vest.
        dc.setColor(kit, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(headX - hr, torsoY, hr * 2, torsoH, 3);
        dc.setColor(trim, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(headX - hr, hipY - 3, hr * 2, 3);
        dc.fillRectangle(headX - 1, torsoY + 2, 2, hr);

        // Head, then the arms: guide hand steadies, shooting hand reaches.
        dc.setColor(skin, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(headX, headY, hr);
        dc.setPenWidth(4);
        dc.drawLine(headX + hr - 1, torsoY + hr / 2, bx, by + br);
        dc.setPenWidth(3);
        dc.drawLine(headX - hr + 1, torsoY + hr / 2,
                    bx - br - 2, by + br + (hr / 2));
        dc.setPenWidth(1);
    }

    // ── The ball ────────────────────────────────────────────────────────────
    function ballBody(skin as Lang.Number) as Lang.Number {
        if (skin == 1) { return 0xFFAA00; }
        if (skin == 2) { return 0xFF5500; }
        return 0xFF5500;
    }

    function ballArt(dc, skin as Lang.Number, x as Lang.Number, y as Lang.Number,
                     r as Lang.Number, spin as Lang.Float) as Void {
        var body  = ballBody(skin);
        var seam  = (skin == 1) ? 0xAA5500 : 0xAA0000;
        var shine = (skin == 1) ? 0xFFFF55 : 0xFFAA55;
        if (skin == 2) { seam = 0xFFFF55; shine = 0xFFAA00; }

        // Flame skin burns a halo before the body is laid down.
        if (skin == 2) {
            dc.setColor(0xAA0000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r + 3);
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r + 1);
        }

        dc.setColor(body, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(shine, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - r / 3, y - r / 3, r / 2);

        // Seams rotate with the ball's spin — the cheapest possible sell of
        // backspin, and the thing that makes a slow arc look alive.
        var c = Math.cos(spin);
        var s = Math.sin(spin);
        dc.setColor(seam, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(x - (r * c).toNumber(), y - (r * s).toNumber(),
                    x + (r * c).toNumber(), y + (r * s).toNumber());
        dc.drawLine(x + (r * s).toNumber(), y - (r * c).toNumber(),
                    x - (r * s).toNumber(), y + (r * c).toNumber());
        dc.setPenWidth(1);
        dc.drawCircle(x, y, r);

        if (skin == 1) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - r / 2, y - r / 2, 1);
        }
    }

    // Fading motion trail. Oldest samples are smallest and dimmest, which is
    // what reads as speed rather than as a string of beads.
    function trailArt(dc, skin as Lang.Number, trail as Lang.Array,
                      r as Lang.Number) as Void {
        var n = trail.size();
        if (n < 2) { return; }
        var cols = (skin == 1) ? [0x555500, 0xAA5500, 0xFFAA00]
                               : [0x550000, 0xAA0000, 0xFF5500];
        for (var i = 0; i < n - 1; i++) {
            var f = i.toFloat() / (n - 1);
            var ci = (f * 3).toNumber(); if (ci > 2) { ci = 2; }
            var rr = ((r * (0.3 + f * 0.5))).toNumber(); if (rr < 1) { rr = 1; }
            dc.setColor(cols[ci], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(trail[i][0], trail[i][1], rr);
        }
    }
}
