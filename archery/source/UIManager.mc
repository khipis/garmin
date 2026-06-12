// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Drawing for Archery.
//
// LAYERS (back → front)
//   • Sky gradient + sparse stars
//   • Distant castle silhouette
//   • Ground line + grass
//   • Enemies (pixel-art knights, riders, archer)
//   • Incoming arrows (boss fight)
//   • Player's arrows (in flight + stuck)
//   • Bow at bottom centre (animated draw)
//   • Crosshair at screen centre
//   • HUD top + bottom
//   • Banner / hit flash / game over overlays
//
// All HUD elements live inside the safe arc of round watches
// (vertical 12 %–88 %) and stay tiny (FONT_XTINY) so they never
// crowd the playfield.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

class UIManager {

    // ── Menu geometry (for tap hit-testing) ───────────────────
    // Sized for 5 rows (Sens / Diff / Demo / Start / Leaderboard).
    // Space-aware: rows are packed into the strip between the title
    // block and a reserved bottom margin (for the BEST/hint footer)
    // so the extra LEADERBOARD row never overlaps anything on small
    // round watches.  Heights/widths are ~15-18 % tighter than the
    // old 4-row menu.
    static function rowGeom(sw, sh) {
        var topZone      = (sh * 37) / 100;            // rows live below "by Bitochi"
        var bottomMargin = (sh * 17) / 100; if (bottomMargin < 27) { bottomMargin = 27; }
        var gap          = (sh * 14) / 1000; if (gap < 3) { gap = 3; }
        var avail        = (sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (AR_MENU_ROWS - 1)) / AR_MENU_ROWS;
        if (rowH > 20) { rowH = 20; }
        if (rowH < 12) { rowH = 12; }
        var rowW = (sw * 56) / 100; if (rowW < 108) { rowW = 108; }
        var rowX = (sw - rowW) / 2;
        var used  = AR_MENU_ROWS * rowH + (AR_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // ── Master draw ──────────────────────────────────────────
    static function draw(dc, ctrl) {
        if (ctrl.state == AR_MENU) { drawMenu(dc, ctrl); return; }
        if (ctrl.state == AR_DEMO) { drawDemo(dc, ctrl); return; }

        // While the cinematic close-up is playing we DROP the game
        // world entirely — pure black backdrop so the close-up
        // dominates the screen like a real cutscene.
        if (ctrl.hitFocusT > 0) {
            drawHitFocus(dc, ctrl);
            if (ctrl.state == AR_OVER) { drawGameOver(dc, ctrl); }
            if (ctrl.state == AR_WIN)  { drawVictory(dc, ctrl); }
            return;
        }

        // Game world (with shake offset).
        var sh = ctrl.shakeOff();
        var ox = sh[0]; var oy = sh[1];
        drawSky(dc, ctrl, ox, oy);
        drawCastle(dc, ctrl, ox, oy);
        drawGround(dc, ctrl, ox, oy);
        drawEnemies(dc, ctrl, ox, oy);
        drawIncomingArrows(dc, ctrl, ox, oy);
        drawPlayerArrows(dc, ctrl, ox, oy);
        drawBow(dc, ctrl);
        drawCrosshair(dc, ctrl);
        drawVfx(dc, ctrl, ox, oy);
        drawHUD(dc, ctrl);
        if (ctrl.headshotT > 0) { drawHeadshotFx(dc, ctrl); }
        if (ctrl.hitFlashT > 0) { drawHitFlash(dc, ctrl); }
        if (ctrl.state == AR_INTERMISSION || ctrl.bannerT > 0) {
            drawBanner(dc, ctrl);
        }
        if (ctrl.state == AR_OVER) { drawGameOver(dc, ctrl); }
        if (ctrl.state == AR_WIN)  { drawVictory(dc, ctrl); }
    }

    // ── SKY ─────────────────────────────────────────────────
    // Painted as a few horizontal bands of pre-mixed colours.
    // Tilting in pitch shifts the bands so it feels like you're
    // looking up/down.
    static function drawSky(dc, ctrl, ox, oy) {
        var sw = ctrl.sw; var sh = ctrl.sh;
        var horizon = sh / 2 + (ctrl.gyro.aimPitch * AR_FOV).toNumber() + oy;
        // Sky.
        dc.setColor(0x2B1E2E, 0x2B1E2E); dc.clear();
        // Bands.
        var b1 = horizon - sh / 3;
        var b2 = horizon - sh / 5;
        var b3 = horizon;
        dc.setColor(0x4A2A30, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, b1, sw, sh);
        dc.setColor(0x7B3A28, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, b2, sw, sh);
        dc.setColor(0xC4642A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, b3 - 2, sw, 4);
        // Sun blob — fixed angular position so it pans with gyro.
        var sunYaw   = -0.5;
        var sunPitch = -0.18;
        var sunX = ctrl.cx + ((sunYaw   - ctrl.gyro.aimYaw)   * AR_FOV).toNumber() + ox;
        var sunY = ctrl.cy + ((sunPitch - ctrl.gyro.aimPitch) * AR_FOV).toNumber() + oy;
        dc.setColor(0xF2A446, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunX, sunY, 18);
        dc.setColor(0xFFD060, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunX, sunY, 13);
        dc.setColor(0xFFE890, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunX, sunY, 8);
    }

    // ── DISTANT CASTLE SILHOUETTE ───────────────────────────
    static function drawCastle(dc, ctrl, ox, oy) {
        var horizon = ctrl.sh / 2 + (ctrl.gyro.aimPitch * AR_FOV).toNumber() + oy;
        // Castle anchored at yaw 0.4 so it rolls with the player's view.
        var anchorX = ctrl.cx + ((0.4 - ctrl.gyro.aimYaw) * AR_FOV).toNumber() + ox;
        dc.setColor(0x10141A, Graphics.COLOR_TRANSPARENT);
        // Curtain wall.
        dc.fillRectangle(anchorX - 38, horizon - 14, 76, 14);
        // Tower silhouettes.
        dc.fillRectangle(anchorX - 30, horizon - 30, 14, 30);
        dc.fillRectangle(anchorX +  4, horizon - 26, 12, 26);
        dc.fillRectangle(anchorX + 22, horizon - 34, 14, 34);
        // Crenellation hints on tallest tower.
        dc.fillRectangle(anchorX + 22, horizon - 38, 4, 4);
        dc.fillRectangle(anchorX + 30, horizon - 38, 4, 4);
        // Flag pole + flag.
        dc.setColor(0x4A2A30, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(anchorX + 29, horizon - 42, anchorX + 29, horizon - 52);
        dc.setColor(0xA63A30, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[anchorX + 29, horizon - 52],
                        [anchorX + 38, horizon - 48],
                        [anchorX + 29, horizon - 44]]);

        // Second castle on the LEFT for environmental variety.
        var leftX = ctrl.cx + ((-0.6 - ctrl.gyro.aimYaw) * AR_FOV).toNumber() + ox;
        dc.setColor(0x0E1218, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(leftX - 28, horizon - 10, 56, 10);
        dc.fillRectangle(leftX - 24, horizon - 22, 10, 22);
        dc.fillRectangle(leftX + 14, horizon - 24, 10, 24);
    }

    // ── GROUND ──────────────────────────────────────────────
    static function drawGround(dc, ctrl, ox, oy) {
        var sw = ctrl.sw; var sh = ctrl.sh;
        var horizon = sh / 2 + (ctrl.gyro.aimPitch * AR_FOV).toNumber() + oy;
        if (horizon < 0) { horizon = 0; }
        if (horizon > sh) { horizon = sh; }
        dc.setColor(0x183014, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizon, sw, sh - horizon);
        // Grass tufts.
        dc.setColor(0x265A1E, Graphics.COLOR_TRANSPARENT);
        var step = 14;
        var phase = (ctrl.gyro.aimYaw * 30).toNumber();
        for (var x = -8; x < sw + 8; x = x + step) {
            var jx = x + (phase % step);
            var jy = (x & 7) * 1;
            dc.fillRectangle(jx, horizon + 4 + jy, 3, 2);
            dc.fillRectangle(jx + 6, horizon + 8 + (jy / 2), 2, 2);
        }
        // Horizon line emphasis.
        dc.setColor(0x462D14, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizon - 1, sw, 2);
    }

    // ── ENEMIES ─────────────────────────────────────────────
    // Scope-zoom feel: while the player is drawing the bow we
    // magnify the world by up to ~40 % so enemies appear bigger
    // and pushed away from screen centre — exactly what looking
    // through a scope does.
    static function drawEnemies(dc, ctrl, ox, oy) {
        var cx = ctrl.cx; var cy = ctrl.cy;
        var zoom10 = 100 + ctrl.bow.draw * 40 / 100;   // 100..140
        for (var i = 0; i < AR_MAX_ENEMIES; i++) {
            if (ctrl.enemies.live[i] == 0) { continue; }
            var ex0 = ctrl.enemies.sx[i];
            var ey0 = ctrl.enemies.sy[i];
            var sz0 = ctrl.enemies.sz[i];
            // Apply scope-zoom around screen centre.
            var ex = cx + ((ex0 - cx) * zoom10) / 100 + ox;
            var ey = cy + ((ey0 - cy) * zoom10) / 100 + oy;
            var sz = (sz0 * zoom10) / 100;
            if (sz < 6)  { sz = 6;  }
            if (sz > 56) { sz = 56; }
            var t  = ctrl.enemies.type[i];
            if      (t == AR_ET_RIDER)   { _drawRider(dc, ex, ey, sz, ctrl.enemies, i); }
            else if (t == AR_ET_HEAVY)   { _drawHeavy(dc, ex, ey, sz); }
            else if (t == AR_ET_ARCHER)  { _drawArcher(dc, ex, ey, sz, ctrl.enemies, i); }
            else if (t == AR_ET_SHIELD)  { _drawShieldKnight(dc, ex, ey, sz, ctrl.enemies, i); }
            else                          { _drawPeasant(dc, ex, ey, sz); }
        }
    }

    // Standard knight body (used by several silhouettes).  Returns
    // the pixel half-height it occupies above ey.
    hidden static function _drawBody(dc, ex, ey, sz, tunicCol, headCol) {
        // Legs.
        dc.setColor(0x1C1814, Graphics.COLOR_TRANSPARENT);
        var legW = (sz * 22) / 100; if (legW < 2) { legW = 2; }
        var legH = (sz * 25) / 100; if (legH < 3) { legH = 3; }
        dc.fillRectangle(ex - legW - 1, ey - legH / 2,
                          legW, legH + sz * 25 / 100);
        dc.fillRectangle(ex + 1, ey - legH / 2,
                          legW, legH + sz * 25 / 100);
        // Tunic / chest.
        var bodyW = (sz * 60) / 100;
        var bodyH = (sz * 35) / 100;
        dc.setColor(tunicCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - bodyW / 2, ey - sz * 45 / 100,
                          bodyW, bodyH + 2);
        // Head.
        var headR = (sz * 13) / 100;
        if (headR < 3) { headR = 3; }
        dc.setColor(headCol, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex, ey - sz * 55 / 100, headR);
    }

    hidden static function _drawPeasant(dc, ex, ey, sz) {
        _drawBody(dc, ex, ey, sz, 0x6B3A1E, 0xC8A074);
        // Hat.
        dc.setColor(0x3A1F12, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - sz * 18 / 100, ey - sz * 68 / 100,
                          sz * 36 / 100, sz * 8 / 100);
    }

    hidden static function _drawShieldKnight(dc, ex, ey, sz, em, i) {
        _drawBody(dc, ex, ey, sz, 0x6A6E7A, 0xC8A074);
        // Helmet over head.
        dc.setColor(0x9AA0AC, Graphics.COLOR_TRANSPARENT);
        var hX = ex - sz * 15 / 100;
        var hY = ey - sz * 70 / 100;
        dc.fillRectangle(hX, hY, sz * 30 / 100, sz * 22 / 100);
        // Vertical visor slit.
        dc.setColor(0x0A0A12, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 1, hY + sz * 6 / 100, 2, sz * 8 / 100);

        // Shield — covers chest/legs while shutT > 0.
        if (em.shutT[i] > 0) {
            // Shield up.
            var sxL = ex - sz * 50 / 100;
            var sxR = sxL + sz * 60 / 100;
            var syT = ey - sz * 40 / 100;
            var syB = ey + sz * 30 / 100;
            dc.setColor(0x6E3022, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sxL, syT, sxR - sxL, syB - syT);
            // Shield emblem (cross).
            dc.setColor(0xE0C054, Graphics.COLOR_TRANSPARENT);
            var bcx = (sxL + sxR) / 2;
            var bcy = (syT + syB) / 2;
            dc.fillRectangle(bcx - 1, syT + 3, 3, syB - syT - 6);
            dc.fillRectangle(sxL + 4, bcy - 1, sxR - sxL - 8, 3);
        } else {
            // Shield lowered — show small one at the side.
            var ssx = ex - sz * 50 / 100;
            var ssy = ey + sz * 5 / 100;
            dc.setColor(0x4E2A22, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ssx, ssy, sz * 18 / 100, sz * 20 / 100);
        }
    }

    hidden static function _drawHeavy(dc, ex, ey, sz) {
        // Bigger body.
        _drawBody(dc, ex, ey, sz, 0x484E5A, 0xC8A074);
        // Heavy plate breast.
        dc.setColor(0x707682, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - sz * 35 / 100, ey - sz * 40 / 100,
                          sz * 70 / 100, sz * 22 / 100);
        // Helmet — full helm.
        dc.setColor(0x8A8E98, Graphics.COLOR_TRANSPARENT);
        var hX = ex - sz * 18 / 100;
        var hY = ey - sz * 72 / 100;
        dc.fillRectangle(hX, hY, sz * 36 / 100, sz * 26 / 100);
        // Plume — red on top so player knows it's heavy.
        dc.setColor(0xB23030, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - 2, hY - sz * 14 / 100, 4, sz * 14 / 100);
        // Visor.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(hX + 2, hY + sz * 10 / 100,
                          sz * 32 / 100, 2);
        // Big sword.
        dc.setColor(0xCAD0D8, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ex + sz * 35 / 100, ey - sz * 30 / 100,
                    ex + sz * 55 / 100, ey + sz * 25 / 100);
        dc.drawLine(ex + sz * 36 / 100, ey - sz * 30 / 100,
                    ex + sz * 56 / 100, ey + sz * 25 / 100);
    }

    hidden static function _drawRider(dc, ex, ey, sz, em, i) {
        // Horse first (under the rider).
        var hC = 0x6A4626;
        var hW = sz * 80 / 100;
        var hH = sz * 30 / 100;
        var hX = ex - hW / 2;
        var hY = ey + sz * 5 / 100;
        dc.setColor(hC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(hX, hY, hW, hH);
        // Horse head.
        dc.fillRectangle(hX + hW - 4, hY - sz * 14 / 100,
                          sz * 18 / 100, sz * 18 / 100);
        // Legs.
        dc.fillRectangle(hX + 3, hY + hH, sz * 10 / 100, sz * 18 / 100);
        dc.fillRectangle(hX + hW - 12, hY + hH, sz * 10 / 100, sz * 18 / 100);
        // Tail.
        dc.fillRectangle(hX - sz * 8 / 100, hY + 2, sz * 6 / 100, sz * 8 / 100);
        // Rider (sits on horse).
        var rEy = hY - sz * 5 / 100;
        _drawBody(dc, ex, rEy, sz * 90 / 100, 0x6A6E7A, 0xC8A074);
        // Helmet.
        dc.setColor(0x8A8E98, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - sz * 12 / 100, rEy - sz * 55 / 100,
                          sz * 24 / 100, sz * 18 / 100);
    }

    hidden static function _drawArcher(dc, ex, ey, sz, em, i) {
        // Cloaked archer body — hooded silhouette.
        // Robe.
        dc.setColor(0x2C3622, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[ex - sz * 45 / 100, ey + sz * 35 / 100],
                        [ex - sz * 15 / 100, ey - sz * 40 / 100],
                        [ex + sz * 15 / 100, ey - sz * 40 / 100],
                        [ex + sz * 45 / 100, ey + sz * 35 / 100]]);
        // Head + hood.
        dc.setColor(0x1A2412, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex, ey - sz * 55 / 100, sz * 18 / 100);
        dc.setColor(0xC8A074, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - sz * 6 / 100, ey - sz * 52 / 100,
                          sz * 12 / 100, sz * 8 / 100);
        // Bow held vertically on archer's left side.
        var bowX = ex - sz * 28 / 100;
        dc.setColor(0xA66B30, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(bowX, ey - sz * 40 / 100, bowX, ey + sz * 30 / 100);
        dc.drawLine(bowX - 1, ey - sz * 40 / 100, bowX - 1, ey + sz * 30 / 100);
        // Subtle "drawing" hint when about to fire (fireT < 12).
        if (em.fireT[i] < 12 && em.fireT[i] > 0) {
            dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bowX + 2, ey - sz * 4 / 100, 2);
        }
    }

    // ── INCOMING ARROWS (boss only) ─────────────────────────
    static function drawIncomingArrows(dc, ctrl, ox, oy) {
        for (var i = 0; i < AR_MAX_INCOMING; i++) {
            if (ctrl.inLive[i] == 0) { continue; }
            var x = ctrl.inX[i].toNumber() + ox;
            var y = ctrl.inY[i].toNumber() + oy;
            // Tail.
            var vx = ctrl.inVx[i]; var vy = ctrl.inVy[i];
            var d  = Math.sqrt(vx * vx + vy * vy);
            if (d < 0.001) { continue; }
            var tx = x - (vx / d * 11.0).toNumber();
            var ty = y - (vy / d * 11.0).toNumber();
            dc.setColor(0xA66B30, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tx, ty, x, y);
            // Head.
            dc.setColor(0xE0E0E8, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 1, y - 1, 3, 3);
        }
    }

    // ── PLAYER ARROWS ───────────────────────────────────────
    // CINEMATIC FLIGHT.  Each arrow now renders as a four-layer
    // composite so the player feels the whoosh:
    //   1. Faint full-arc TRACER from the bow to current pos
    //      — shows the entire parabolic trajectory in dark amber.
    //   2. Dense gradient TRAIL of the 6 most-recent positions
    //      with increasing width and brightness near the head.
    //   3. Motion DUST: 8 pseudo-random particles streaming
    //      beside the recent trail (perpendicular jitter).
    //   4. Bright ARROW itself: thick highlighted shaft, sharp
    //      steel head with bevel, and big red fletching wings.
    static function drawPlayerArrows(dc, ctrl, ox, oy) {
        var bow = ctrl.bow;
        for (var i = 0; i < AR_MAX_ARROWS; i++) {
            if (bow.aLive[i] == 0) { continue; }
            var age  = bow.aAge[i];
            var finT = bow.aFinalT[i];
            var inFlight = (age < finT);

            // ── 1) Full-arc tracer (8 samples 0..age) ────────
            if (age >= 2) {
                var samples = 8;
                if (samples > age) { samples = age; }
                var prX = -9999; var prY = -9999;
                for (var k = 0; k <= samples; k++) {
                    var sa  = (age * k) / samples;
                    var sp  = bow.arrowPosAt(i, sa);
                    var sxk = sp[0] + ox;
                    var syk = sp[1] + oy;
                    if (prX > -9000) {
                        var ratio = (k * 100) / samples;
                        var col;
                        if      (ratio < 30) { col = 0x342010; }
                        else if (ratio < 60) { col = 0x5A3418; }
                        else if (ratio < 85) { col = 0x885028; }
                        else                  { col = 0xB87040; }
                        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                        dc.drawLine(prX, prY, sxk, syk);
                    }
                    prX = sxk; prY = syk;
                }
            }

            // ── 2) Dense recent trail with widening line ────
            var trailCols  = [0x4A2E14, 0x6A4422, 0x8A5C2E, 0xB07440, 0xD49658, 0xF0B870];
            var trailWidth = [1,         1,         2,         2,         3,         3];
            var prevX = -9999; var prevY = -9999;
            for (var k = 0; k < 6; k++) {
                var pa = age - (6 - k);
                if (pa < 0) { continue; }
                var pp  = bow.arrowPosAt(i, pa);
                var ppx = pp[0] + ox;
                var ppy = pp[1] + oy;
                if (prevX > -9000) {
                    dc.setColor(trailCols[k], Graphics.COLOR_TRANSPARENT);
                    dc.setPenWidth(trailWidth[k]);
                    dc.drawLine(prevX, prevY, ppx, ppy);
                }
                prevX = ppx; prevY = ppy;
            }
            dc.setPenWidth(1);

            // ── 3) Whoosh dust ───────────────────────────────
            if (inFlight && age >= 2) {
                var seed = (age * 71 + i * 31) & 0xFFFF;
                for (var pk = 0; pk < 8; pk++) {
                    var pAge = age - 1 - (pk % 5);
                    if (pAge < 1) { continue; }
                    var p2 = bow.arrowPosAt(i, pAge);
                    var p3 = bow.arrowPosAt(i, pAge - 1);
                    var dx = (p2[0] - p3[0]).toFloat();
                    var dy = (p2[1] - p3[1]).toFloat();
                    var dd = Math.sqrt(dx * dx + dy * dy);
                    if (dd < 0.5) { continue; }
                    var ux0 = dx / dd; var uy0 = dy / dd;
                    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
                    var sgn = ((seed >> 8) & 1) == 0 ? 1 : -1;
                    var off = sgn * (3 + ((seed >> 4) & 3));
                    var dpx = p2[0] + ox - (uy0 * off).toNumber();
                    var dpy = p2[1] + oy + (ux0 * off).toNumber();
                    var dustCol = (pk < 3) ? 0xE8C898 : 0xA88458;
                    dc.setColor(dustCol, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(dpx, dpy, 2, 2);
                }
            }

            // ── 4) Current arrow body ─────────────────────────
            var pos = bow.arrowPos(i);
            var x = pos[0] + ox;
            var y = pos[1] + oy;

            // Direction = tangent of the parabola.
            var prev = bow.arrowPosAt(i, age - 1);
            var fx = (x - (prev[0] + ox)).toFloat();
            var fy = (y - (prev[1] + oy)).toFloat();
            var d  = Math.sqrt(fx * fx + fy * fy);
            if (d < 0.5) {
                fx = (x - bow.aBowX[i] - ox).toFloat();
                fy = (y - bow.aBowY[i] - oy).toFloat();
                d  = Math.sqrt(fx * fx + fy * fy);
                if (d < 0.5) { d = 1.0; }
            }
            var ux = fx / d; var uy = fy / d;

            var shaftLen = inFlight ? 26 : 20;
            var tailX = x - (ux * shaftLen).toNumber();
            var tailY = y - (uy * shaftLen).toNumber();

            // Wood shaft — fat, 3 lines thick.
            dc.setColor(0x8A5028, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(tailX, tailY, x, y);
            dc.setPenWidth(1);
            dc.setColor(0xC68A4A, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tailX, tailY, x, y);
            dc.setColor(0xF0BA70, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tailX - (uy * 1).toNumber(),
                        tailY + (ux * 1).toNumber(),
                        x     - (uy * 1).toNumber(),
                        y     + (ux * 1).toNumber());

            // Steel head — large, with bevel.
            var nx = (-uy * 3.0).toNumber();
            var ny = ( ux * 3.0).toNumber();
            dc.setColor(0xE8E8E8, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                [x + (ux * 8).toNumber(), y + (uy * 8).toNumber()],
                [x + nx, y + ny],
                [x - nx, y - ny]
            ]);
            // Bevel highlight (top edge of head).
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x + (ux * 8).toNumber() - (uy * 0).toNumber(),
                        y + (uy * 8).toNumber() + (ux * 0).toNumber(),
                        x + nx, y + ny);

            // Red fletching wings at the tail.
            var fnx = (-uy * 4.0).toNumber();
            var fny = ( ux * 4.0).toNumber();
            dc.setColor(0xD03020, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                [tailX,                              tailY],
                [tailX - (ux * 6).toNumber() + fnx,  tailY - (uy * 6).toNumber() + fny],
                [tailX - (ux * 3).toNumber(),        tailY - (uy * 3).toNumber()]
            ]);
            dc.fillPolygon([
                [tailX,                              tailY],
                [tailX - (ux * 6).toNumber() - fnx,  tailY - (uy * 6).toNumber() - fny],
                [tailX - (ux * 3).toNumber(),        tailY - (uy * 3).toNumber()]
            ]);
            // Fletching highlight (orange tip).
            dc.setColor(0xF06030, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tailX - (ux * 6).toNumber() + fnx,
                        tailY - (uy * 6).toNumber() + fny,
                        tailX - (ux * 6).toNumber() - fnx,
                        tailY - (uy * 6).toNumber() - fny);
        }
    }

    // ── BOW (at bottom centre, animates with draw) ──────────
    static function drawBow(dc, ctrl) {
        if (ctrl.state == AR_INTERMISSION || ctrl.state == AR_OVER ||
            ctrl.state == AR_WIN) { return; }
        if (ctrl.hitFocusT > 0) { return; }  // hide during cinematic
        var sw = ctrl.sw; var sh = ctrl.sh;
        var cx = ctrl.cx;
        var by = (sh * 92) / 100;
        var draw = ctrl.bow.draw;
        // Bow arc widens slightly as draw increases.
        var sp = sw * 12 / 100;        // half-span
        var topY = by - sw * 14 / 100;
        // Curvature: more drawn = bow ends pulled inward (string back).
        var bend = sp * (10 + draw / 10) / 100;
        // Bow limbs (curved by 3-segment polyline approximation).
        dc.setColor(0x8B5A28, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx - sp, by, cx - sp + bend, topY + 6);
        dc.drawLine(cx - sp + bend, topY + 6, cx, topY);
        dc.drawLine(cx, topY, cx + sp - bend, topY + 6);
        dc.drawLine(cx + sp - bend, topY + 6, cx + sp, by);
        dc.setPenWidth(1);
        // Bow highlight.
        dc.setColor(0xC58B3A, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - sp, by + 1, cx + sp, by + 1);

        // String: from tip to tip; while drawing, pulled back to bow grip.
        var pullBack = (draw * sw / 800);      // 0 .. ~draw/8 pixels back
        dc.setColor(0xE0E0E0, Graphics.COLOR_TRANSPARENT);
        var grip = (by + topY) / 2;
        dc.drawLine(cx - sp, by, cx - pullBack, grip);
        dc.drawLine(cx - pullBack, grip, cx + pullBack, grip);
        dc.drawLine(cx + pullBack, grip, cx + sp, by);

        // Arrow nocked while drawing.
        if (ctrl.bow.drawing != 0 || draw > 0) {
            var aLen = sw * 18 / 100;
            // Aim direction towards (cx, cy) from grip — for visual
            // we just draw it pointing toward crosshair.
            var dx = (ctrl.cx - cx).toFloat();
            var dy = (ctrl.cy - grip).toFloat();
            var d = Math.sqrt(dx * dx + dy * dy);
            if (d < 0.01) { d = 1.0; }
            var ux = dx / d; var uy = dy / d;
            // Nock point = (cx, grip) + pullBack along reverse-aim.
            var nx = cx - (ux * pullBack).toNumber();
            var ny = grip - (uy * pullBack).toNumber();
            var hx = nx + (ux * aLen).toNumber();
            var hy = ny + (uy * aLen).toNumber();
            dc.setColor(0x886030, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(nx, ny, hx, hy);
            dc.setColor(0xE6E6F0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(hx, hy, 3, 3);
        }
    }

    // ── CROSSHAIR ───────────────────────────────────────────
    static function drawCrosshair(dc, ctrl) {
        if (ctrl.state == AR_INTERMISSION) { return; }
        if (ctrl.hitFocusT > 0) { return; }  // hide during cinematic
        var cx = ctrl.cx; var cy = ctrl.cy;
        // Zoom: full draw shrinks crosshair so it feels "tighter".
        var pull = ctrl.bow.draw;
        var armLen = 8 - pull / 20;
        if (armLen < 3) { armLen = 3; }
        // Centre dot.
        dc.setColor(0xE0F0FF, Graphics.COLOR_TRANSPARENT);
        dc.drawPoint(cx, cy);
        // Cross with gap.
        var col = (pull > 60) ? 0x60F080 : 0xC0E0FF;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - armLen - 4, cy, cx - 2, cy);
        dc.drawLine(cx + 2, cy, cx + armLen + 4, cy);
        dc.drawLine(cx, cy - armLen - 4, cx, cy - 2);
        dc.drawLine(cx, cy + 2, cx, cy + armLen + 4);
        // Draw-power ring while drawing.
        if (pull > 0) {
            var r = 11 + pull / 12;
            dc.drawCircle(cx, cy, r);
        }
    }

    // ── VFX (impact sparks) ─────────────────────────────────
    static function drawVfx(dc, ctrl, ox, oy) {
        for (var i = 0; i < AR_MAX_VFX; i++) {
            if (ctrl.vfxLive[i] == 0) { continue; }
            var x = ctrl.vfxX[i] + ox;
            var y = ctrl.vfxY[i] + oy;
            var age = ctrl.vfxAge[i];
            var col;
            if      (ctrl.vfxZone[i] == AR_HZ_HEAD)  { col = 0xFFE060; }
            else if (ctrl.vfxZone[i] == AR_HZ_CHEST) { col = 0xFF8030; }
            else                                      { col = 0xFFAA40; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var r = age + 2;
            dc.drawCircle(x, y, r);
            if (age < 3) { dc.fillCircle(x, y, 2); }
        }
    }

    // ── HUD ─────────────────────────────────────────────────
    static function drawHUD(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh;
        var cx = ctrl.cx;

        // Top row: ROUND  ·  KILL PROGRESS  ·  TIME
        var tyTop = (sh * 16) / 100; if (tyTop < 8) { tyTop = 8; }
        var line = ctrl.roundName(ctrl.roundIdx).substring(0, 1) +
                   "   " +
                   ctrl.roundKills.format("%d") + "/" + ctrl.roundKillTarget.format("%d") +
                   "   " +
                   ctrl.roundTime.format("%d") + "s";
        var tc = (ctrl.roundTime <= 10) ? 0xFF4040 : 0xCCEEFF;
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, tyTop, Graphics.FONT_XTINY, line,
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Score line just under.
        var tyScore = (sh * 24) / 100;
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, tyScore, Graphics.FONT_XTINY,
                    ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        // Combo (next to score, smaller).
        if (ctrl.combo >= 2) {
            dc.setColor(0xFF9933, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 40, tyScore, Graphics.FONT_XTINY,
                        "x" + ctrl.combo.format("%d"),
                        Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Bottom: shields (left) + last-zone popup (right).
        var tyBot = (sh * 78) / 100;
        var sxStart = cx - 22;
        for (var i = 0; i < ctrl.maxShields; i++) {
            var px = sxStart - i * 9;
            var py = tyBot + 6;
            if (i < ctrl.shields) {
                dc.setColor(0xE03040, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 3);
            } else {
                dc.setColor(0x401010, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(px, py, 3);
            }
        }
        if (ctrl.lastZoneT > 0) {
            var col2; var lbl;
            if      (ctrl.lastZone == AR_HZ_HEAD)  { col2 = 0xFFE060; lbl = "HEAD!"; }
            else if (ctrl.lastZone == AR_HZ_CHEST) { col2 = 0xFF8030; lbl = "CHEST"; }
            else                                    { col2 = 0xFFAA40; lbl = "LEG"; }
            dc.setColor(col2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 12, tyBot, Graphics.FONT_XTINY,
                        lbl + " +" + ctrl.lastZonePts.format("%d"),
                        Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ── KILLER FEATURE: cinematic hit close-up (v2) ─────────
    // Designed as a real cutscene that DOMINATES the screen.
    // Phases driven by `T = 22 - hitFocusT` (0 → 22):
    //
    //   T 0-2  IMPACT     hard freeze, manga speed-lines erupt
    //                     from the wound, white flash, knight
    //                     in shock pose
    //   T 3-7  SHOCK      arrow sunk in, blood spray, shock-rings
    //                     start expanding, knight begins recoil
    //   T 8-13 RECOIL     pose visibly leans/buckles, blood drips
    //   T 14-22 COLLAPSE  knight tips over and falls to the ground
    //                      (full skew/tilt for HEAD shots, hard
    //                      crumple for CHEST, knee-drop for LEG)
    //
    // The whole canvas is wiped to black first so nothing from
    // the game world bleeds through.
    // Renders a full-screen replay of the arrow piercing the
    // knight at the moment of impact:
    //   • whole world dims with a black vignette
    //   • a BIG armoured knight fills the centre of the screen
    //   • the arrow is shown sunk deep into the hit zone with a
    //     long shaft sticking out behind
    //   • the knight visibly recoils / leans / falls as the
    //     animation progresses (head snap, chest push, leg buckle)
    //   • shock-wave rings + blood spray emanate from the wound
    //   • a small zone+points pill sits at the bottom of the
    //     screen — secondary, the visual is the main thing
    //
    // Lifetime: hitFocusT counts 22 → 0.  Frames 22→18 are the
    // GameController "slow-mo freeze".  Frames 18→0 are the
    // recoil + lean animation (`T = 22 - hitFocusT`, 0..22).
    static function drawHitFocus(dc, ctrl) {
        var T = 22 - ctrl.hitFocusT;
        if (T < 0) { T = 0; }
        var sw = ctrl.sw; var sh = ctrl.sh;
        var cx = ctrl.cx; var cy = ctrl.cy;
        var zone  = ctrl.hitFocusZone;
        var etype = ctrl.hitFocusType;

        var phase;
        if      (T < 3)  { phase = 0; }    // IMPACT
        else if (T < 8)  { phase = 1; }    // SHOCK
        else if (T < 14) { phase = 2; }    // RECOIL
        else              { phase = 3; }    // COLLAPSE

        var lbl; var zoneCol; var bloodCol;
        if (zone == AR_HZ_HEAD) {
            lbl = "HEADSHOT!"; zoneCol = 0xFFE060; bloodCol = 0xC83020;
        } else if (zone == AR_HZ_CHEST) {
            lbl = "CHEST HIT";  zoneCol = 0xFF8030; bloodCol = 0xC02018;
        } else {
            lbl = "LEG SHOT";   zoneCol = 0xFFAA40; bloodCol = 0xB02818;
        }

        // ── 1) Black backdrop (kills everything else) ───────
        dc.setColor(0x000000, 0x000000);
        dc.clear();

        // ── 2) Zone color wash on impact (frame 0-2 only) ───
        if (phase == 0) {
            var washCol;
            if      (zone == AR_HZ_HEAD)  { washCol = 0x281008; }
            else if (zone == AR_HZ_CHEST) { washCol = 0x220804; }
            else                           { washCol = 0x1A0A06; }
            dc.setColor(washCol, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, sw, sh);
        } else {
            // Subtle reddish wash so it stays cinematic.
            dc.setColor(0x100604, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, sw, sh);
        }

        // ── 3) Cinematic bars (thicker than before) ─────────
        var barH = (sh * 11) / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0,        sw, barH);
        dc.fillRectangle(0, sh - barH, sw, barH);
        // Thin gold strip along the bars for premium feel.
        dc.setColor(0x806020, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, barH,     sw, 1);
        dc.fillRectangle(0, sh - barH - 1, sw, 1);

        // ── 4) Knight pose + base placement ─────────────────
        var bigSz   = (sh * 36) / 100;       // half-height (bigger now)
        var kBaseX  = cx;
        var kBaseY  = cy + bigSz * 38 / 100; // feet baseline
        var leanX = 0;  var leanY = 0;
        var headDX = 0; var headDY = 0;
        var tilt   = 0;                       // % of horizontal skew per body height
        var crumple = 0;                      // legs/torso shrink ratio (%)

        if (zone == AR_HZ_HEAD) {
            // Phase 1: violent head snap back
            // Phase 2: shoulders follow, torso starts leaning back
            // Phase 3: full topple — knight falls onto his back
            if      (phase == 0) { headDX =  1; headDY = -2; }
            else if (phase == 1) { headDX = (T - 2) * 3; headDY = -(T - 2) * 3; }
            else if (phase == 2) {
                headDX = 15 + (T - 8) * 2;
                headDY = -18 + (T - 8) * 1;
                tilt   = (T - 8) * 6;
                leanX  = (T - 8) * 1;
                leanY  = (T - 8) * 1;
            } else {  // collapse
                headDX  = 27 + (T - 14) * 3;
                headDY  = -12 + (T - 14) * 3;
                tilt    = 42 + (T - 14) * 4;
                leanX   = 6 + (T - 14) * 3;
                leanY   = 8 + (T - 14) * 4;
                crumple = (T - 14) * 4;
            }
        } else if (zone == AR_HZ_CHEST) {
            // Phase 1: torso jolted back
            // Phase 2: knight stumbles back, knees soften
            // Phase 3: knight crumples to a kneel-then-fall
            if      (phase == 0) { leanX = -1; }
            else if (phase == 1) { leanX = -(T - 2) * 2; leanY = (T - 2); tilt = (T - 2) * 2; }
            else if (phase == 2) {
                leanX = -10 - (T - 8);
                leanY = 5 + (T - 8) * 2;
                tilt  = 12 + (T - 8) * 2;
                crumple = (T - 8) * 3;
                headDY = 6 + (T - 8);
            } else {
                leanX   = -16 - (T - 14);
                leanY   = 17 + (T - 14) * 3;
                tilt    = 22 + (T - 14) * 3;
                crumple = 18 + (T - 14) * 4;
                headDX  = -(T - 14) * 2;
                headDY  = 12 + (T - 14) * 3;
            }
        } else {
            // Leg shot — knight hunches forward, drops to one knee
            if      (phase == 0) { /* idle hold */ }
            else if (phase == 1) { leanX = (T - 2); leanY = (T - 2) * 2; tilt = -(T - 2) * 2;
                                   headDX = -(T - 2); headDY = (T - 2); }
            else if (phase == 2) {
                leanX   = 6 + (T - 8);
                leanY   = 12 + (T - 8) * 2;
                tilt    = -10 - (T - 8) * 2;
                crumple = 6 + (T - 8) * 3;
                headDX  = -5 - (T - 8);
                headDY  = 8 + (T - 8) * 2;
            } else {
                leanX   = 12 + (T - 14);
                leanY   = 24 + (T - 14) * 2;
                tilt    = -22 - (T - 14) * 2;
                crumple = 24 + (T - 14) * 3;
                headDX  = -11 - (T - 14);
                headDY  = 22 + (T - 14) * 2;
            }
        }

        // ── 5) Draw the close-up knight ─────────────────────
        _drawCloseupKnight(dc, kBaseX + leanX, kBaseY + leanY, bigSz,
                            etype, T, headDX, headDY, tilt, crumple);

        // ── 6) Wound point (in knight-local coords) ─────────
        var woundX; var woundY;
        if (zone == AR_HZ_HEAD) {
            woundX = kBaseX + leanX + headDX - (tilt * 60 / 100);
            woundY = kBaseY + leanY - bigSz * 75 / 100 + headDY + (crumple * 30 / 100);
        } else if (zone == AR_HZ_CHEST) {
            woundX = kBaseX + leanX - (tilt * 35 / 100);
            woundY = kBaseY + leanY - bigSz * 40 / 100 + (crumple * 25 / 100);
        } else {
            woundX = kBaseX + leanX - (tilt * 12 / 100);
            woundY = kBaseY + leanY - bigSz * 5 / 100 + (crumple * 15 / 100);
        }

        // ── 7) Manga-style speed lines on IMPACT ────────────
        if (phase < 2) {
            var lineCnt = 16;
            var rIn  = 20 + T * 3;
            var rOut = 60 + T * 6;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            for (var k = 0; k < lineCnt; k++) {
                var ang = (k * (360 / lineCnt) + T * 3) * 0.01745329;
                var x1 = woundX + (Math.cos(ang) * rIn).toNumber();
                var y1 = woundY + (Math.sin(ang) * rIn).toNumber();
                var x2 = woundX + (Math.cos(ang) * rOut).toNumber();
                var y2 = woundY + (Math.sin(ang) * rOut).toNumber();
                dc.drawLine(x1, y1, x2, y2);
            }
            dc.setPenWidth(1);
        }

        // ── 8) Arrow embedded deep ─────────────────────────
        // Tail length grows then settles.
        var tailLen = 36 + ((T < 6) ? T * 2 : 12);
        var atx = woundX + tailLen;
        var aty = woundY + tailLen * 70 / 100;
        // Thick black wood outline.
        dc.setColor(0x3A1E08, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(5);
        dc.drawLine(atx, aty, woundX + 4, woundY + 2);
        dc.setPenWidth(1);
        // Brown shaft.
        dc.setColor(0xA86430, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(atx, aty, woundX + 4, woundY + 2);
        dc.setPenWidth(1);
        // Highlight on top.
        dc.setColor(0xE6A458, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(atx, aty - 1, woundX + 4, woundY + 1);
        // Steel head poking THROUGH the body (sticking out left).
        dc.setColor(0xE8E8E8, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [woundX - 5,  woundY - 3],
            [woundX - 16, woundY + 1],
            [woundX - 5,  woundY + 5]
        ]);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(woundX - 5, woundY - 3, woundX - 16, woundY + 1);
        // Blood drip from the through-the-body head.
        dc.setColor(bloodCol, Graphics.COLOR_TRANSPARENT);
        for (var bd = 0; bd < 3; bd++) {
            dc.drawLine(woundX - 12 + bd * 2, woundY + 5,
                        woundX - 14 + bd * 2, woundY + 9 + bd);
        }
        // Red fletching at the tail.
        dc.setColor(0xD03020, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[atx, aty], [atx + 9, aty - 7], [atx + 1, aty - 2]]);
        dc.fillPolygon([[atx, aty], [atx + 9, aty + 7], [atx + 1, aty + 2]]);
        dc.fillPolygon([[atx, aty], [atx + 13, aty],    [atx + 4, aty]]);
        dc.setColor(0xF06030, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(atx, aty, atx + 9, aty - 7);
        dc.drawLine(atx, aty, atx + 9, aty + 7);

        // ── 9) Bright impact flash (phase 0 only) ──────────
        if (phase == 0) {
            var br = 18 - T * 4;
            if (br < 4) { br = 4; }
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(woundX, woundY, br);
            // Cross-shaped sparkle.
            dc.setPenWidth(3);
            dc.drawLine(woundX - 22, woundY, woundX + 22, woundY);
            dc.drawLine(woundX, woundY - 22, woundX, woundY + 22);
            dc.setPenWidth(1);
        }

        // ── 10) Shock-wave rings ───────────────────────────
        dc.setPenWidth(2);
        for (var k = 0; k < 4; k++) {
            var rr = T * 4 + k * 9;
            if (rr > 90) { continue; }
            var rcol = (k == 0) ? 0xFFFFFF : zoneCol;
            dc.setColor(rcol, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(woundX, woundY, rr);
        }
        dc.setPenWidth(1);

        // ── 11) Blood spray particles ──────────────────────
        var bursts = (phase < 2) ? 14 : 10;
        for (var k = 0; k < bursts; k++) {
            var ang2 = (k * (360 / bursts) + T * 5) * 0.01745329;
            var rad2 = 6 + T * 2 + (k & 3);
            if (rad2 > 50) { rad2 = 50; }
            var spx = woundX + (Math.cos(ang2) * rad2).toNumber();
            var spy = woundY + (Math.sin(ang2) * rad2 * 0.85).toNumber();
            var col = ((k & 1) == 0) ? bloodCol : ((zone == AR_HZ_HEAD) ? 0xFFEE66 : 0xE05030);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(spx - 1, spy - 1, 3, 3);
        }

        // ── 12) Blood pool on the ground (phase 3) ─────────
        if (phase == 3) {
            var poolGrow = (T - 14) * 3;
            if (poolGrow < 4) { poolGrow = 4; }
            if (poolGrow > 38) { poolGrow = 38; }
            dc.setColor(0x4A0808, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(kBaseX + leanX - poolGrow,
                              kBaseY + leanY + 6 + (crumple / 4),
                              poolGrow * 2,
                              4);
            dc.setColor(0x8A1010, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(kBaseX + leanX - poolGrow + 4,
                              kBaseY + leanY + 7 + (crumple / 4),
                              poolGrow * 2 - 8,
                              2);
        }

        // ── 13) Movie-style title at TOP ───────────────────
        if (T >= 2) {
            var tyTitle = barH + 4;
            dc.setColor(zoneCol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, tyTitle, Graphics.FONT_SMALL, lbl,
                        Graphics.TEXT_JUSTIFY_CENTER);
            // Underline.
            dc.setColor(0x806020, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 50, tyTitle + 22, 100, 1);
        }

        // ── 14) Points popup near impact (rises over time) ─
        if (T >= 4) {
            var ptsY = woundY - 18 - (T - 4) * 2;
            dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(woundX, ptsY, Graphics.FONT_XTINY,
                        "+" + ctrl.hitFocusPts.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── 15) "KILLED" stamp during collapse ─────────────
        if (phase == 3) {
            var ksy = sh - barH - 22;
            dc.setColor(0x10141A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 38, ksy, 76, 18, 4);
            dc.setColor(0xC02020, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(cx - 38, ksy, 76, 18, 4);
            dc.drawText(cx, ksy + 1, Graphics.FONT_XTINY, "KILLED",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Big knight (or horse rider / hooded archer) rendered for the
    // cinematic close-up.  Each body part is positioned in LOCAL
    // coordinates relative to the feet (ex, ey) and then sheared
    // by `tilt` so the entire silhouette can lean / topple smoothly:
    //
    //     drawX(localY) = ex - (tilt * localY) / 100
    //
    // `crumple` shrinks the leg+torso heights to simulate the body
    // collapsing into itself when fully killed.  Together with
    // tilt this produces a believable "topple to the ground".
    //
    //   x, y    : feet baseline center
    //   sz      : sprite half-height in px (≈90 px on a 260 px screen)
    //   etype   : enemy type — used to vary the silhouette
    //   T       : 0..22 — drives micro-wobble on impact
    //   hDX/hDY : extra translation applied to the head/helmet
    //   tilt    : horizontal skew percentage (positive = lean back)
    //   crumple : 0..100 — vertical body compression
    hidden static function _drawCloseupKnight(dc, x, y, sz, etype, T,
                                              hDX, hDY, tilt, crumple) {
        // Tiny shake on the first few frames so the silhouette
        // feels alive at impact.
        var wob = 0;
        if (T < 4) { wob = ((T & 1) == 0) ? 1 : -1; }
        var ex = x + wob;
        var ey = y;

        // Helper for shear: returns X coordinate of a point that
        // sits `yOff` pixels ABOVE the feet baseline (yOff > 0).
        // tilt is in percent — every 100 % adds `yOff` pixels of
        // horizontal lean.  We bake this inline below.

        // Shrink factors for collapse.
        if (crumple > 80) { crumple = 80; }
        var leanFactor = (100 - crumple);   // 100 = upright

        // Drop shadow on the ground (grows with tilt to suggest
        // the knight is now horizontal).
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        var shW = sz * 70 / 100 + (tilt * sz / 200);
        dc.fillRectangle(ex - shW / 2, ey + 4, shW, 4);

        // Choose a horse-saddle pre-render for RIDER.
        if (etype == AR_ET_RIDER) {
            _drawCloseupHorse(dc, ex, ey, sz, tilt);
            ey = ey - sz * 35 / 100;   // rider sits on horse
        }

        // ── Legs ───────────────────────────────────────────
        var legW = sz * 18 / 100; if (legW < 6) { legW = 6; }
        var legH = sz * 55 / 100 * leanFactor / 100;
        if (legH < 6) { legH = 6; }
        var legTopY = ey - legH;
        var legTopShear = (tilt * legH / 100);
        dc.setColor(0x2A2C32, Graphics.COLOR_TRANSPARENT);
        // Left leg trapezoid.
        dc.fillPolygon([
            [ex - legW - 2,               ey],
            [ex - 2,                      ey],
            [ex - 2 + legTopShear,        legTopY],
            [ex - legW - 2 + legTopShear, legTopY]
        ]);
        // Right leg trapezoid.
        dc.fillPolygon([
            [ex + 2,                ey],
            [ex + legW + 2,         ey],
            [ex + legW + 2 + legTopShear, legTopY],
            [ex + 2 + legTopShear,        legTopY]
        ]);
        // Greave highlights.
        dc.setColor(0x4A4E58, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - legW - 1, ey - legH + 2, 2, legH - 4);
        dc.fillRectangle(ex + 3,        ey - legH + 2, 2, legH - 4);
        // Boots.
        dc.setColor(0x18181C, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - legW - 4, ey - 4, legW + 5, 6);
        dc.fillRectangle(ex + 1,        ey - 4, legW + 5, 6);

        // ── Torso ──────────────────────────────────────────
        var bodyW = sz * 75 / 100;
        var bodyH = sz * 50 / 100 * leanFactor / 100;
        if (bodyH < 8) { bodyH = 8; }
        var bodyBottomY  = legTopY;
        var bodyTopY     = bodyBottomY - bodyH;
        var bodyBotShear = legTopShear;
        var bodyTopShear = (tilt * (legH + bodyH) / 100);
        // Pick torso colors by type.
        var torsoCol;
        var torsoHigh;
        if (etype == AR_ET_ARCHER) {
            torsoCol  = 0x2C3622;          // dark green cloak
            torsoHigh = 0x4C5E40;
        } else {
            torsoCol  = 0x5E6470;          // steel plate
            torsoHigh = 0x82889A;
        }
        dc.setColor(torsoCol, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [ex - bodyW / 2 + bodyBotShear, bodyBottomY],
            [ex + bodyW / 2 + bodyBotShear, bodyBottomY],
            [ex + bodyW * 45 / 100 + bodyTopShear, bodyTopY],
            [ex - bodyW * 45 / 100 + bodyTopShear, bodyTopY]
        ]);
        dc.setColor(torsoHigh, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ex - bodyW / 2 + bodyBotShear + 2, bodyBottomY,
                    ex - bodyW * 45 / 100 + bodyTopShear + 2, bodyTopY);
        dc.drawLine(ex + bodyW / 2 + bodyBotShear - 2, bodyBottomY,
                    ex + bodyW * 45 / 100 + bodyTopShear - 2, bodyTopY);

        // Heraldic cross only for plate-armoured types.
        if (etype != AR_ET_ARCHER) {
            dc.setColor(0xB02020, Graphics.COLOR_TRANSPARENT);
            var crossH = bodyH * 70 / 100;
            var crossY = bodyTopY + bodyH * 15 / 100;
            var crossX = ex - 3 + ((bodyTopShear + bodyBotShear) / 2);
            dc.fillRectangle(crossX, crossY, 6, crossH);
            var armW = bodyW * 50 / 100;
            dc.fillRectangle(crossX - armW / 2 + 3,
                              crossY + crossH * 30 / 100, armW, 5);
        }

        // ── Shield (only SHIELD or HEAVY knights) ─────────
        if (etype == AR_ET_SHIELD || etype == AR_ET_HEAVY) {
            var shX = ex - bodyW * 55 / 100 + bodyBotShear;
            var shY = bodyTopY + bodyH * 25 / 100;
            var shW2 = bodyW * 35 / 100;
            var shH = bodyH * 75 / 100;
            dc.setColor(0x6E3022, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(shX, shY, shW2, shH);
            dc.setColor(0xE0C054, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(shX + shW2 / 2 - 1, shY + 3, 3, shH - 6);
            dc.fillRectangle(shX + 3, shY + shH / 2 - 1, shW2 - 6, 3);
        }

        // ── Bow (ARCHER variant) ──────────────────────────
        if (etype == AR_ET_ARCHER) {
            var bX = ex - bodyW * 50 / 100 + bodyTopShear;
            dc.setColor(0xA66B30, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(bX, bodyTopY + 2, bX, bodyBottomY + 2);
            dc.setPenWidth(1);
        }

        // ── Shoulder pauldrons ────────────────────────────
        dc.setColor(0x70788A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ex - bodyW / 2 - 4 + bodyTopShear, bodyTopY - 2,
                          bodyW * 30 / 100, sz * 14 / 100);
        dc.fillRectangle(ex + bodyW / 2 - bodyW * 26 / 100 + bodyTopShear,
                          bodyTopY - 2,
                          bodyW * 30 / 100, sz * 14 / 100);

        // ── Head / helmet ────────────────────────────────
        var helmW = sz * 52 / 100;
        var helmH = sz * 30 / 100;
        var helmBaseX = ex + bodyTopShear + hDX;
        var helmY     = bodyTopY - helmH * 90 / 100 + hDY;
        var helmCol;
        var helmHigh;
        var plumeCol;
        if (etype == AR_ET_ARCHER) {
            helmCol  = 0x1A2412;       // dark hood
            helmHigh = 0x3A5430;
            plumeCol = 0;
        } else if (etype == AR_ET_HEAVY) {
            helmCol  = 0x8A8E98;
            helmHigh = 0xB0B8C8;
            plumeCol = 0xB23030;
        } else {
            helmCol  = 0x8088A0;
            helmHigh = 0xAAB0C0;
            plumeCol = 0xC02828;
        }
        dc.setColor(helmCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(helmBaseX - helmW / 2, helmY, helmW, helmH);
        // Helmet highlight.
        dc.setColor(helmHigh, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(helmBaseX - helmW / 2 + 2, helmY + 2, 4, helmH - 6);
        // Visor slit / eye.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(helmBaseX - helmW / 2 + 4,
                          helmY + helmH * 45 / 100,
                          helmW - 8, 3);
        // Plume on top (only knights).
        if (plumeCol != 0) {
            dc.setColor(plumeCol, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(helmBaseX - 4, helmY - sz * 18 / 100, 8, sz * 20 / 100);
            dc.setColor(plumeCol | 0x202020, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(helmBaseX - 2, helmY - sz * 18 / 100, 2, sz * 20 / 100);
        }
    }

    // Horse silhouette beneath a rider for the cinematic.
    hidden static function _drawCloseupHorse(dc, ex, ey, sz, tilt) {
        var hW = sz * 110 / 100;
        var hH = sz * 35 / 100;
        var hX = ex - hW / 2;
        var hY = ey;
        // Body.
        dc.setColor(0x4A2E14, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(hX, hY - hH, hW, hH);
        dc.setColor(0x6A4626, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(hX, hY - hH, hW, 3);
        // Head + neck.
        dc.setColor(0x4A2E14, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(hX + hW - 6, hY - hH - sz * 24 / 100,
                          sz * 22 / 100, sz * 24 / 100);
        // Legs.
        dc.fillRectangle(hX + 4,            hY,  sz * 12 / 100, sz * 26 / 100);
        dc.fillRectangle(hX + hW - sz * 16 / 100, hY, sz * 12 / 100, sz * 26 / 100);
        // Tail.
        dc.setColor(0x2A1A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(hX - sz * 8 / 100, hY - hH + 4, sz * 8 / 100, sz * 14 / 100);
    }

    static function drawHitFlash(dc, ctrl) {
        // Vignette ring — red.
        dc.setColor(0xFF1133, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        var r = (ctrl.sw < ctrl.sh ? ctrl.sw : ctrl.sh) / 2 - 2;
        dc.drawCircle(ctrl.cx, ctrl.cy, r);
        dc.setPenWidth(1);
    }
    static function drawHeadshotFx(dc, ctrl) {
        dc.setColor(0xFFE060, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var r = (ctrl.sw < ctrl.sh ? ctrl.sw : ctrl.sh) / 2 - 6;
        dc.drawCircle(ctrl.cx, ctrl.cy, r);
        dc.setPenWidth(1);
        dc.drawText(ctrl.cx, (ctrl.sh * 36) / 100, Graphics.FONT_XTINY,
                    "HEADSHOT!", Graphics.TEXT_JUSTIFY_CENTER);
    }
    static function drawBanner(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var cx = ctrl.cx;
        var bw = sw * 70 / 100; if (bw < 150) { bw = 150; }
        var bh = sh * 12 / 100; if (bh < 32) { bh = 32; }
        var bx = (sw - bw) / 2; var by = (sh - bh) / 2;
        dc.setColor(0x10141A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 6);
        dc.setColor(0xE0B040, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 6);
        dc.drawText(cx, by + bh / 2 - 8, Graphics.FONT_XTINY,
                    ctrl.bannerText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Menu ─────────────────────────────────────────────────
    static function drawMenu(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var cx = ctrl.cx;
        // Sky-evening backdrop.
        dc.setColor(0x2B1E2E, 0x2B1E2E); dc.clear();
        dc.setColor(0x4A2A30, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, sh * 30 / 100, sw, sh);
        dc.setColor(0x7B3A28, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, sh * 45 / 100, sw, sh);
        dc.setColor(0x183014, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, sh * 60 / 100, sw, sh);
        // Distant castle on menu too.
        dc.setColor(0x10141A, Graphics.COLOR_TRANSPARENT);
        var hy = (sh * 60) / 100;
        dc.fillRectangle(cx + 30, hy - 18, 14, 18);
        dc.fillRectangle(cx + 44, hy - 26, 14, 26);
        dc.fillRectangle(cx + 60, hy - 22, 14, 22);
        // Title.
        dc.setColor(0xE6B45A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 13 / 100, Graphics.FONT_MEDIUM,
                    "ARCHERY", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xC09030, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 24 / 100, Graphics.FONT_XTINY,
                    "TOURNAMENT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAA8050, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 31 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = [
            "Sens:  " + ctrl.sensName(),
            "Diff:  " + ctrl.diffName(),
            "DEMO",
            "ENTER",
            ""
        ];
        for (var i = 0; i < AR_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            var sel = (i == ctrl.menuRow);

            if (i == AR_ROW_LB) {
                // Gold global-leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == AR_ROW_START);
            var isDemo  = (i == AR_ROW_DEMO);
            var bg, bd, fg;
            if      (sel && isStart) { bg = 0x223300; bd = 0xFFEE66; fg = 0xFFEE66; }
            else if (sel && isDemo)  { bg = 0x222030; bd = 0xC080E0; fg = 0xE8C8FF; }
            else if (sel)             { bg = 0x18222E; bd = 0xE0B040; fg = 0xFFE0A0; }
            else if (isStart)         { bg = 0x101810; bd = 0x335544; fg = 0xAACCBB; }
            else if (isDemo)          { bg = 0x141022; bd = 0x40305A; fg = 0xA090C0; }
            else                       { bg = 0x101820; bd = 0x303A4A; fg = 0xA0A8B6; }
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(bd, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0xAA8050, Graphics.COLOR_TRANSPARENT);
        if (ctrl.bestScore > 0) {
            dc.drawText(cx, sh - 28, Graphics.FONT_XTINY,
                        "BEST " + ctrl.bestScore.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN  tap = act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Demo / highlights reel ──────────────────────────────
    static function drawDemo(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh;
        var cx = ctrl.cx;

        // If a cinematic hit is currently playing, just show that
        // on a pure-black canvas — same drawHitFocus path.
        if (ctrl.hitFocusT > 0) {
            drawHitFocus(dc, ctrl);
            // Subtle "DEMO" badge top-left so the user remembers
            // they can dismiss at any time.
            dc.setColor(0x10141A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(8, 8, 60, 16, 3);
            dc.setColor(0xC080E0, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(8, 8, 60, 16, 3);
            dc.drawText(38, 7, Graphics.FONT_XTINY, "DEMO",
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Between hits we show a moody banner with the next title.
        dc.setColor(0x080810, 0x080810);
        dc.clear();

        // Soft purple atmospheric backdrop band (anim sweeps left-right).
        var sweep = (ctrl.demoT * 4) % (sw + 80) - 40;
        dc.setColor(0x1A1230, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, sh * 30 / 100, sw, sh * 40 / 100);
        dc.setColor(0x2A1A50, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sweep, sh * 35 / 100, 80, sh * 30 / 100);
        dc.setColor(0x402870, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sweep + 24, sh * 40 / 100, 32, sh * 20 / 100);

        // Cinematic bars.
        var barH = sh * 8 / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, sw, barH);
        dc.fillRectangle(0, sh - barH, sw, barH);

        // Big "DEMO" mark.
        dc.setColor(0xC080E0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 12 / 100, Graphics.FONT_SMALL, "DEMO",
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Current caption.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 45 / 100, Graphics.FONT_MEDIUM,
                    ctrl.demoCaption, Graphics.TEXT_JUSTIFY_CENTER);

        // Hint.
        dc.setColor(0x9080A8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 72 / 100, Graphics.FONT_XTINY,
                    "tap / BACK to exit", Graphics.TEXT_JUSTIFY_CENTER);

        // Tiny progress dots showing where in the reel we are.
        var dotsY = sh - barH - 14;
        var phases = [22, 56, 90, 124];
        for (var i = 0; i < 4; i++) {
            var done = (ctrl.demoT >= phases[i]);
            var col = done ? 0xC080E0 : 0x403050;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 24 + i * 16, dotsY, 3);
        }
    }

    // ── Game Over / Victory ─────────────────────────────────
    static function drawGameOver(dc, ctrl) {
        _drawEndOverlay(dc, ctrl, "DEFEAT", 0xC03030);
    }
    static function drawVictory(dc, ctrl) {
        _drawEndOverlay(dc, ctrl, "CHAMPION!", 0xFFE060);
    }
    hidden static function _drawEndOverlay(dc, ctrl, title, titleCol) {
        var sw = ctrl.sw; var sh = ctrl.sh; var cx = ctrl.cx;
        var bw = sw * 76 / 100; if (bw < 170) { bw = 170; }
        var bh = sh * 50 / 100; if (bh < 130) { bh = 130; }
        var bx = (sw - bw) / 2; var by = (sh - bh) / 2;
        dc.setColor(0x10141A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(titleCol, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL, title,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 38, Graphics.FONT_XTINY,
                    "Score   " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 56, Graphics.FONT_XTINY,
                    "Round   " + ctrl.roundName(ctrl.roundIdx),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 74, Graphics.FONT_XTINY,
                    "Combo   " + ctrl.maxCombo.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 92, Graphics.FONT_XTINY,
                    "Best    " + ctrl.bestScore.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap = retry", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
