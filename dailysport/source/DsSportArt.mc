// ═══════════════════════════════════════════════════════════════════════════
// DsSportArt.mc — The look of the sports that joined the rotation after
// basketball: a stadium, a shooting range, a court, a green and a ski hill.
//
// The same two rules the court is drawn under apply here (see DsArt): the top
// fifth of the screen stays dark because the HUD lives there, and every colour
// is built from the 0x00 / 0x55 / 0xAA / 0xFF channel levels a Garmin MIP
// panel can actually show, so nothing is quantised into a different hue on the
// way to the wrist.
//
// The venue index is the same cosmetic the player unlocks for basketball, so
// a streak earned on the court still changes what the shooting range looks
// like. Each sport reads it as its own time of day rather than as a palette
// swap of the last one.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

module DsSportArt {

    // ── Shared furniture ────────────────────────────────────────────────────

    // The aiming arrow, launched clear of the projectile so it reads as a
    // direction rather than as part of the athlete.
    function launchArrow(dc, lx as Lang.Float, ly as Lang.Float,
                         angle as Lang.Float, r0 as Lang.Float,
                         len as Lang.Float) as Void {
        var a  = angle * 0.0174532925;
        var ca = Math.cos(a);
        var sa = Math.sin(a);
        var r1 = r0 + len;
        var x0 = (lx + ca * r0).toNumber();
        var y0 = (ly - sa * r0).toNumber();
        var x1 = (lx + ca * r1).toNumber();
        var y1 = (ly - sa * r1).toNumber();
        dc.setColor(0xFFFF55, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(x0, y0, x1, y1);
        dc.setPenWidth(1);
        dc.fillPolygon([[x1, y1],
                        [(x1 - ca * 7 - sa * 4).toNumber(),
                         (y1 + sa * 7 - ca * 4).toNumber()],
                        [(x1 - ca * 7 + sa * 4).toNumber(),
                         (y1 + sa * 7 + ca * 4).toNumber()]]);
    }

    // Sky for an outdoor venue. `venue` is the cosmetic index: day, floodlit
    // night, late afternoon, stadium.
    function sky(dc, venue as Lang.Number, w as Lang.Number,
                 h as Lang.Number, hz as Lang.Number, t as Lang.Number) as Void {
        if (venue == 1) {
            DsArt._ramp(dc, 0, hz,
                        [0x000000, 0x000055, 0x0000AA, 0x0055AA],
                        [58, 18, 14, 10], w);
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 12; i++) {
                dc.fillCircle((w * ((i * 41 + 9) % 100)) / 100,
                              (h * ((i * 19 + 5) % 38)) / 100,
                              ((i % 4) == 0) ? 2 : 1);
            }
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((w * 78) / 100, (h * 18) / 100, (h * 4) / 100);
        } else if (venue == 2) {
            DsArt._ramp(dc, 0, hz,
                        [0x000000, 0x000055, 0x550055, 0xAA0055,
                         0xAA5500, 0xFF5500, 0xFFAA00],
                        [46, 12, 10, 10, 9, 8, 5], w);
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((w * 26) / 100, hz - (h * 6) / 100, (h * 5) / 100);
        } else if (venue == 3) {
            DsArt._ramp(dc, 0, hz,
                        [0x000000, 0x000055, 0x550055, 0xAA00AA],
                        [46, 22, 18, 14], w);
            _crowd(dc, w, h, hz, t);
        } else {
            DsArt._ramp(dc, 0, hz,
                        [0x000000, 0x000055, 0x0055AA, 0x00AAAA, 0xAAAAFF],
                        [50, 16, 14, 12, 8], w);
            dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((w * 80) / 100, (h * 20) / 100, (h * 5) / 100);
        }
    }

    // Tiered stands with a couple of camera flashes going off in them.
    function _crowd(dc, w as Lang.Number, h as Lang.Number,
                    hz as Lang.Number, t as Lang.Number) as Void {
        var tiers = [0x5500AA, 0xAA00AA, 0x550055];
        for (var r = 0; r < 3; r++) {
            var y = hz - (h * (15 - r * 4)) / 100;
            dc.setColor(tiers[r], Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 15; i++) {
                dc.fillCircle((w * (3 + i * 7)) / 100, y, 3 - r / 2);
            }
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var f = 0; f < 2; f++) {
            var k = (t / 4 + f * 7) % 15;
            dc.fillCircle((w * (3 + k * 7)) / 100,
                          hz - (h * (15 - (k % 3) * 4)) / 100, 2);
        }
    }

    // Turf, with mown stripes fanning toward a vanishing point so the field
    // runs away from the viewer instead of standing up like a wall.
    function turf(dc, venue as Lang.Number, w as Lang.Number,
                  h as Lang.Number, hz as Lang.Number,
                  floorY as Lang.Number) as Void {
        var grass = 0x00AA00;
        var dark  = 0x005500;
        if (venue == 1) { grass = 0x005555; dark = 0x000055; }
        if (venue == 2) { grass = 0x00AA55; dark = 0x005500; }
        if (venue == 3) { grass = 0x00AA00; dark = 0x00AA55; }

        dc.setColor(grass, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, hz, w, h - hz);
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        var vx = (w * 78) / 100;
        for (var i = -3; i <= 3; i = i + 2) {
            dc.fillPolygon([[vx, hz],
                            [vx + i * (w * 14) / 100, h],
                            [vx + (i + 1) * (w * 14) / 100, h]]);
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, floorY, w, 2);
    }

    // ── Football: goal, net, keeper ─────────────────────────────────────────
    // The mouth is drawn as a box in weak perspective, with the near post
    // brighter than the far one so the opening reads as something to shoot
    // into rather than as a flat rectangle.
    function goal(dc, gx as Lang.Number, top as Lang.Number,
                  bot as Lang.Number, depth as Lang.Number,
                  flash as Lang.Boolean) as Void {
        var post = flash ? 0xFFFFFF : 0xAAAAAA;

        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i <= 4; i++) {
            var x = gx + (depth * i) / 4;
            dc.drawLine(x, top - (i * (bot - top)) / 26, x, bot);
        }
        for (var r = 0; r <= 3; r++) {
            var y = top + ((bot - top) * r) / 3;
            dc.drawLine(gx, y, gx + depth, y - (bot - top) / 26);
        }

        dc.setColor(post, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(gx - 2, top, 4, bot - top);
        dc.fillRectangle(gx - 2, top, depth + 4, 4);
        dc.setColor(flash ? 0xFFFFAA : 0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(gx + depth, top, 3, bot - top);
    }

    // The keeper is a silhouette with arms: the player has to read the gap it
    // is not covering, so its extent has to be unambiguous at a glance.
    function keeper(dc, x as Lang.Number, y as Lang.Number,
                    hh as Lang.Number, reach as Lang.Float) as Void {
        var kw = hh / 3; if (kw < 4) { kw = 4; }
        dc.setColor(0xFFFF00, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - kw / 2, y - hh / 2, kw, hh, 3);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - hh / 2 - kw / 3, kw / 2);
        // Gloves, thrown out along the dive.
        var ax = (reach * hh / 2).toNumber();
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(x, y - hh / 4, x - kw, y - hh / 2 - ax);
        dc.drawLine(x, y - hh / 4, x - kw, y + hh / 4 + ax);
        dc.setPenWidth(1);
    }

    // ── Archery: the target face ────────────────────────────────────────────
    // World Archery colours, in the four channel levels the panel has: gold,
    // red, blue, black, white. The bands are what the scoring reads off, so
    // they are drawn at exactly the radii the verdict uses.
    function targetFace(dc, cx as Lang.Number, cy as Lang.Number,
                        r as Lang.Number, flash as Lang.Boolean) as Void {
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 2, cy, 5, r * 2);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (r * 78) / 100);
        dc.setColor(0x0055AA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (r * 55) / 100);
        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (r * 34) / 100);
        dc.setColor(flash ? 0xFFFFFF : 0xFFFF00, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (r * 22) / 100);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, (r * 22) / 100);
        dc.drawCircle(cx, cy, (r * 55) / 100);
    }

    // An arrow is a line with a head and fletching, rotated onto its own
    // velocity — an arrow that flies sideways is the one thing an archer
    // would notice immediately.
    function arrow(dc, x as Lang.Number, y as Lang.Number,
                   dirX as Lang.Float, dirY as Lang.Float,
                   len as Lang.Number) as Void {
        var m = Math.sqrt(dirX * dirX + dirY * dirY);
        if (m < 0.001) { m = 1.0; }
        var cx = dirX / m;
        var cy = dirY / m;
        var tx = (x + cx * len / 2).toNumber();
        var ty = (y + cy * len / 2).toNumber();
        var bx = (x - cx * len / 2).toNumber();
        var by = (y - cy * len / 2).toNumber();

        dc.setColor(0xAA5500, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(bx, by, tx, ty);
        dc.setPenWidth(1);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[tx, ty],
                        [(tx - cx * 5 - cy * 3).toNumber(),
                         (ty - cy * 5 + cx * 3).toNumber()],
                        [(tx - cx * 5 + cy * 3).toNumber(),
                         (ty - cy * 5 - cx * 3).toNumber()]]);
        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[bx, by],
                        [(bx + cx * 5 - cy * 3).toNumber(),
                         (by + cy * 5 + cx * 3).toNumber()],
                        [(bx + cx * 5 + cy * 3).toNumber(),
                         (by + cy * 5 - cx * 3).toNumber()]]);
    }

    // ── Tennis: net and service box ─────────────────────────────────────────
    function tennisNet(dc, x as Lang.Number, top as Lang.Number,
                       floorY as Lang.Number) as Void {
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            dc.drawLine(x - 6 + i * 3, top + 4, x - 6 + i * 3, floorY);
        }
        for (var r = 1; r < 4; r++) {
            var y = top + ((floorY - top) * r) / 4;
            dc.drawLine(x - 6, y, x + 6, y);
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 7, top, 15, 3);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 8, top, 3, floorY - top);
        dc.fillRectangle(x + 6, top, 3, floorY - top);
    }

    // The box the serve has to find, with its deep strip called out: that
    // strip is the ace, and it has to be visible from the baseline.
    function serviceBox(dc, x0 as Lang.Number, x1 as Lang.Number,
                        floorY as Lang.Number, deep as Lang.Number,
                        h as Lang.Number) as Void {
        var d = (h * 3) / 100; if (d < 3) { d = 3; }
        dc.setColor(0x0055AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0, floorY + 2, x1 - x0, d);
        dc.setColor(0x00AAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(deep, floorY + 2, x1 - deep, d);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0, floorY + 2, 2, d);
        dc.fillRectangle(x1 - 2, floorY + 2, 2, d);
        dc.fillRectangle(deep, floorY + 2, 1, d);
    }

    // ── Golf: the pin ───────────────────────────────────────────────────────
    function pin(dc, x as Lang.Number, floorY as Lang.Number,
                 hh as Lang.Number, wind as Lang.Float,
                 flash as Lang.Boolean) as Void {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, floorY - hh, 2, hh);
        var fw = hh / 3; if (fw < 5) { fw = 5; }
        var flap = (wind * fw / 3).toNumber();
        dc.setColor(flash ? 0xFFFF55 : 0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x + 2, floorY - hh],
                        [x + 2 + fw, floorY - hh + fw / 3 + flap],
                        [x + 2, floorY - hh + fw * 2 / 3]]);
    }

    function hole(dc, x as Lang.Number, floorY as Lang.Number,
                  r as Lang.Number) as Void {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, floorY + 1, r);
        dc.setColor(0x005500, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, floorY + 1, r + 1);
    }

    // Concentric proximity bands on the green: the closer ring is the one
    // worth points, and the player needs to see it from the tee.
    function greenBands(dc, hx as Lang.Number, floorY as Lang.Number,
                        near as Lang.Number, far as Lang.Number) as Void {
        dc.setColor(0x00AA55, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(hx - far, floorY + 4, hx + far, floorY + 4);
        dc.setColor(0x00FFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(hx - near, floorY + 7, hx + near, floorY + 7);
    }

    // ── Hill ride: the far ridge and the inrun ──────────────────────────────
    // Only the backdrop lives here. The landing hill itself is drawn by the
    // sport, off the same curve its verdict uses, because a jumper who lands
    // in mid-air or inside the snow is the one bug nobody would forgive.
    function skiBackdrop(dc, w as Lang.Number, h as Lang.Number,
                         takeX as Lang.Number, takeY as Lang.Number,
                         outY as Lang.Number) as Void {
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, takeY], [w / 3, takeY - h / 6],
                        [(w * 2) / 3, takeY - h / 12], [w, takeY - h / 5],
                        [w, outY], [0, outY]]);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[w / 3, takeY - h / 6], [w / 3 + w / 14, takeY - h / 11],
                        [w / 3 - w / 14, takeY - h / 11]]);
        dc.fillPolygon([[w, takeY - h / 5], [w - w / 12, takeY - h / 9],
                        [w, takeY - h / 12]]);

        // Conifers on the shoulder, so the hill has a sense of scale.
        dc.setColor(0x005500, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 7; i++) {
            var x = (w * (6 + i * 13)) / 100;
            var t = takeY - h / 40 - ((i * 7) % 3) * h / 90;
            dc.fillPolygon([[x, t], [x - h / 44, t + h / 22],
                            [x + h / 44, t + h / 22]]);
        }

    }

    // The inrun, laid over the snow once the hill itself is down.
    function skiInrun(dc, h as Lang.Number, takeX as Lang.Number,
                      takeY as Lang.Number) as Void {
        dc.setColor(0x0055AA, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, takeY - h / 8], [takeX, takeY],
                        [takeX, takeY + 6], [0, takeY - h / 8 + 6]]);
        dc.setColor(0x00AAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, takeY - h / 8], [takeX, takeY], [takeX, takeY + 2],
                        [0, takeY - h / 8 + 2]]);
    }

    // A painted line across the hill: the safe line and the K-point are the
    // only two numbers the jumper is flying at.
    function hillMark(dc, x as Lang.Number, surfaceY as Lang.Number,
                      h as Lang.Number, col as Lang.Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 1, surfaceY - h / 22, 3, h / 22);
        dc.fillRectangle(x - (h / 40), surfaceY, (h / 20), 2);
    }

    // ── Small projectiles ───────────────────────────────────────────────────
    function soccerBall(dc, x as Lang.Number, y as Lang.Number,
                        r as Lang.Number, spin as Lang.Float) as Void {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r);
        // Three panels chasing the spin — enough to read as rotation.
        for (var i = 0; i < 3; i++) {
            var a = spin + i * 2.0944;
            dc.fillCircle((x + Math.cos(a) * r * 0.5).toNumber(),
                          (y + Math.sin(a) * r * 0.5).toNumber(),
                          (r / 3 < 2) ? 2 : r / 3);
        }
    }

    function tennisBall(dc, x as Lang.Number, y as Lang.Number,
                        r as Lang.Number, spin as Lang.Float) as Void {
        dc.setColor(0xFFFF55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var c = Math.cos(spin);
        var s = Math.sin(spin);
        dc.drawLine((x - c * r).toNumber(), (y - s * r).toNumber(),
                    (x + c * r).toNumber(), (y + s * r).toNumber());
        dc.setColor(0xAAAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r);
    }

    function golfBall(dc, x as Lang.Number, y as Lang.Number,
                      r as Lang.Number) as Void {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r);
        dc.fillCircle(x + r / 3, y + r / 3, 1);
    }

    // The jumper, banked onto his own flight path with the skis held in a V.
    // The lean is the read: a jumper lying flat over the tips is carrying the
    // jump, and one sitting up has run out of it.
    function jumper(dc, x as Lang.Number, y as Lang.Number,
                    dirX as Lang.Float, dirY as Lang.Float,
                    s as Lang.Number) as Void {
        var m = Math.sqrt(dirX * dirX + dirY * dirY);
        if (m < 0.001) { m = 1.0; }
        var cx = dirX / m;
        var cy = dirY / m;

        // Skis, splayed either side of the flight line.
        dc.setColor(0xFF5500, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var k = -1; k <= 1; k = k + 2) {
            var ox = -cy * s * 0.28 * k;
            var oy =  cx * s * 0.28 * k;
            dc.drawLine((x - cx * s * 0.5).toNumber(),
                        (y - cy * s * 0.5).toNumber(),
                        (x + cx * s + ox).toNumber(),
                        (y + cy * s + oy).toNumber());
        }
        dc.setPenWidth(1);

        // Body, tipped forward over the tips.
        dc.setColor(0x0055AA, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[(x - cx * s * 0.45 - cy * s * 0.22).toNumber(),
                         (y - cy * s * 0.45 + cx * s * 0.22).toNumber()],
                        [(x - cx * s * 0.45 + cy * s * 0.22).toNumber(),
                         (y - cy * s * 0.45 - cx * s * 0.22).toNumber()],
                        [(x + cx * s * 0.35).toNumber(),
                         (y + cy * s * 0.35).toNumber()]]);
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((x + cx * s * 0.38).toNumber(),
                      (y + cy * s * 0.38).toNumber(),
                      (s / 5 < 2) ? 2 : s / 5);
    }

    // ── The athlete ─────────────────────────────────────────────────────────
    // One figure serves every sport: the pose is read off the shot state, so
    // the body is doing what the player's thumb is doing. `kit` lets each
    // sport dress it without another draw routine.
    function athlete(dc, x as Lang.Number, footY as Lang.Number,
                     hr as Lang.Number, kit as Lang.Number,
                     trim as Lang.Number, crouch as Lang.Float,
                     arm as Lang.Float) as Void {
        var sink   = (crouch * hr).toNumber();
        var headY  = footY - hr * 7 + sink;
        var torsoY = headY + hr;
        var torsoH = hr * 3;
        var hipY   = torsoY + torsoH;

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - hr - 2, footY - 2, hr * 2 + 6, 4, 2);

        var spread = hr + (crouch * hr / 2).toNumber();
        var rise   = ((1.0 - crouch) * arm * hr / 2).toNumber();
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(x, hipY, x - spread, footY - rise);
        dc.drawLine(x, hipY, x + spread, footY);
        dc.setPenWidth(1);

        dc.setColor(kit, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - hr, torsoY, hr * 2, torsoH, 3);
        dc.setColor(trim, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - hr, hipY - 3, hr * 2, 3);

        dc.setColor(0xFFAA55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, headY, hr);
        dc.setPenWidth(3);
        dc.drawLine(x + hr - 1, torsoY + hr / 2,
                    x + hr + (arm * hr * 2).toNumber(),
                    torsoY + hr / 2 - (arm * hr).toNumber());
        dc.setPenWidth(1);
    }
}
