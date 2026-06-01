// ═══════════════════════════════════════════════════════════════
// UIManager.mc — All StarCombat drawing.
//
// Layers (back to front):
//   • Deep-space background fill
//   • Star field (projected world points, slightly twinkly)
//   • Star Destroyers (wedge + bridge + engine glow)
//   • Incoming enemy bolts (green Empire lasers)
//   • Player laser flash (red)
//   • Explosion rings
//   • Reticle (fixed centre, turns green on lock)
//   • HUD (score / wave / shields)
//   • Hit-flash vignette
//   • Menu / Game-Over overlays
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

class UIManager {

    // ── Menu geometry (helper for tap hit-testing) ───────────
    // The title block (STAR / COMBAT / "by Bitochi") spans the
    // top ~36 % of the screen.  We anchor the first menu row at
    // 40 % so the tagline is never overlapped.
    static function rowGeom(sw, sh) {
        var rowH = (sh * 10) / 100; if (rowH < 22) { rowH = 22; } if (rowH > 28) { rowH = 28; }
        var rowW = (sw * 64) / 100; if (rowW < 130) { rowW = 130; }
        var rowX = (sw - rowW) / 2;
        var gap  = (sh * 2) / 100;  if (gap < 4) { gap = 4; }
        var rowY0 = (sh * 40) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // ── Master draw ──────────────────────────────────────────
    static function draw(dc, ctrl) {
        // Background.
        dc.setColor(0x000308, 0x000308); dc.clear();

        if (ctrl.state == SC_MENU) {
            drawMenu(dc, ctrl); return;
        }

        var sh = ctrl.shakeOff();
        var ox = sh[0]; var oy = sh[1];

        drawStars(dc, ctrl, ox, oy);
        drawEnemies(dc, ctrl, ox, oy);
        drawBolts(dc, ctrl, ox, oy);
        drawLaser(dc, ctrl, ox, oy);
        drawExplosions(dc, ctrl, ox, oy);
        drawReticle(dc, ctrl);
        drawHUD(dc, ctrl);
        if (ctrl.hitT > 0) { drawHitFlash(dc, ctrl); }
        if (ctrl.state == SC_OVER) { drawGameOver(dc, ctrl); }
    }

    // ── Star field ───────────────────────────────────────────
    static function drawStars(dc, ctrl, ox, oy) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < SC_NSTARS; i++) {
            var dy = ctrl.sYaw[i]   - ctrl.gazeYaw;
            var dp = ctrl.sPitch[i] - ctrl.gazePitch;
            var sx = (ctrl.cx + dy * SC_FOV).toNumber() + ox;
            var sy = (ctrl.cy + dp * SC_FOV).toNumber() + oy;
            if (sx < 0 || sx >= ctrl.sw || sy < 0 || sy >= ctrl.sh) { continue; }
            var d2 = dy * dy + dp * dp;
            var col;
            if (d2 < 0.20)      { col = 0xFFFFFF; }
            else if (d2 < 0.80) { col = 0xCCCCCC; }
            else                 { col = 0x888888; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawPoint(sx, sy);
            if (d2 < 0.10) { dc.drawPoint(sx + 1, sy); }
        }
    }

    // ── Enemies (dispatch by type) ───────────────────────────
    // Three silhouettes:
    //   SC_ET_DESTROYER  pointed wedge + bridge + 1 engine pair
    //   SC_ET_TIE        hex cockpit + two flat side panels
    //   SC_ET_CRUISER    bigger wedge + extra bridge + 2 engine pairs
    static function drawEnemies(dc, ctrl, ox, oy) {
        for (var i = 0; i < SC_MAX_ENEMIES; i++) {
            if (ctrl.eLive[i] == 0) { continue; }
            var ex = ctrl.eSx[i] + ox;
            var ey = ctrl.eSy[i] + oy;
            var s  = ctrl.eSz[i];
            var fa = Math.atan2((ctrl.cy - ey).toFloat(),
                                (ctrl.cx - ex).toFloat());
            fa = fa + Math.sin(ctrl.eHead[i]) * 0.10;
            var ca = Math.cos(fa);
            var sa = Math.sin(fa);

            // Brightness scales with proximity (closer = brighter grey).
            var t = ctrl.eDist[i] / SC_SPAWN_D.toFloat();
            if (t < 0.0) { t = 0.0; }
            if (t > 1.0) { t = 1.0; }
            var br = 220 - (t * 140).toNumber();
            if (br < 80)  { br = 80;  }
            if (br > 230) { br = 230; }
            // Hit flash: pure white briefly after a non-killing hit.
            var flash = (ctrl.eFlashT[i] > 0);

            if      (ctrl.eType[i] == SC_ET_TIE)     { _drawTie(dc, ex, ey, s, ca, sa, br, flash); }
            else if (ctrl.eType[i] == SC_ET_CRUISER) { _drawCruiser(dc, ex, ey, s, ca, sa, br, flash); }
            else                                      { _drawDestroyer(dc, ex, ey, s, ca, sa, br, flash); }
        }
    }

    hidden static function _drawDestroyer(dc, ex, ey, s, ca, sa, br, flash) {
        var hull    = flash ? 0xFFFFFF : (br * 0x010101);
        var hullHi  = flash ? 0xFFFFFF : (((br + 30 > 255) ? 255 : br + 30) * 0x010101);
        var outline = (br * 3 / 5) * 0x010101;
        var lx = [ s,       s * 0.4,  -s * 0.95, -s * 0.95,  s * 0.4 ];
        var ly = [ 0,      -s * 0.45, -s * 0.5,   s * 0.5,   s * 0.45 ];
        var pts = new [5];
        for (var k = 0; k < 5; k++) {
            var px = (lx[k] * ca - ly[k] * sa).toNumber();
            var py = (lx[k] * sa + ly[k] * ca).toNumber();
            pts[k] = [ex + px, ey + py];
        }
        dc.setColor(hull, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
        dc.setColor(outline, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(pts[0][0], pts[0][1], pts[1][0], pts[1][1]);
        dc.drawLine(pts[0][0], pts[0][1], pts[4][0], pts[4][1]);

        if (s >= 9) {
            var bx = [-s * 0.05, -s * 0.45, -s * 0.45, -s * 0.05];
            var by = [-s * 0.12, -s * 0.12,  s * 0.12,  s * 0.12];
            var bpts = new [4];
            for (var k = 0; k < 4; k++) {
                var px = (bx[k] * ca - by[k] * sa).toNumber();
                var py = (bx[k] * sa + by[k] * ca).toNumber();
                bpts[k] = [ex + px, ey + py];
            }
            dc.setColor(hullHi, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(bpts);
        }
        _drawEnginePair(dc, ex, ey, s, ca, sa, -0.95, 0.28);
    }

    // ── Heavy Cruiser: longer hull, double bridge, twin engines ──
    hidden static function _drawCruiser(dc, ex, ey, s, ca, sa, br, flash) {
        var bigS = s * 1.30;
        var hull    = flash ? 0xFFFFFF : (br * 0x010101);
        var hullHi  = flash ? 0xFFFFFF : (((br + 40 > 255) ? 255 : br + 40) * 0x010101);
        var outline = 0xCCAA66;     // amber accent
        var lx = [ bigS,    bigS * 0.4, -bigS * 0.95, -bigS * 0.95, bigS * 0.4 ];
        var ly = [ 0,      -bigS * 0.50, -bigS * 0.55,  bigS * 0.55, bigS * 0.50 ];
        var pts = new [5];
        for (var k = 0; k < 5; k++) {
            var px = (lx[k] * ca - ly[k] * sa).toNumber();
            var py = (lx[k] * sa + ly[k] * ca).toNumber();
            pts[k] = [ex + px, ey + py];
        }
        dc.setColor(hull, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
        // Amber edge highlight to distinguish from regular destroyer.
        dc.setColor(outline, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(pts[0][0], pts[0][1], pts[1][0], pts[1][1]);
        dc.drawLine(pts[0][0], pts[0][1], pts[4][0], pts[4][1]);
        dc.drawLine(pts[1][0], pts[1][1], pts[2][0], pts[2][1]);
        dc.drawLine(pts[4][0], pts[4][1], pts[3][0], pts[3][1]);

        if (bigS >= 10) {
            // Twin bridge: two stacked rectangles dorsal.
            var bx = [ 0.10, -0.30, -0.30,  0.10 ];
            var by = [-0.14, -0.14,  0.14,  0.14 ];
            var bpts = new [4];
            for (var k = 0; k < 4; k++) {
                var px = (bx[k] * bigS * ca - by[k] * bigS * sa).toNumber();
                var py = (bx[k] * bigS * sa + by[k] * bigS * ca).toNumber();
                bpts[k] = [ex + px, ey + py];
            }
            dc.setColor(hullHi, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(bpts);
            // Secondary, smaller bridge further aft.
            var b2x = [-0.40, -0.60, -0.60, -0.40 ];
            var b2y = [-0.10, -0.10,  0.10,  0.10 ];
            var b2pts = new [4];
            for (var k = 0; k < 4; k++) {
                var px = (b2x[k] * bigS * ca - b2y[k] * bigS * sa).toNumber();
                var py = (b2x[k] * bigS * sa + b2y[k] * bigS * ca).toNumber();
                b2pts[k] = [ex + px, ey + py];
            }
            dc.fillPolygon(b2pts);
        }
        _drawEnginePair(dc, ex, ey, bigS, ca, sa, -0.95, 0.22);
        _drawEnginePair(dc, ex, ey, bigS, ca, sa, -0.95, 0.45);
    }

    // ── TIE Fighter: small hex cockpit + two flat side panels ──
    hidden static function _drawTie(dc, ex, ey, s, ca, sa, br, flash) {
        var sz = s * 0.85;
        var hull  = flash ? 0xFFFFFF : ((br - 20 > 60 ? br - 20 : 60) * 0x010101);
        var panel = flash ? 0xFFFFFF : ((br - 50 > 50 ? br - 50 : 50) * 0x010101);
        var edge  = 0x99CCEE;
        // Cockpit hexagon (radius ~0.4*sz).
        var cr = sz * 0.40;
        var hexPts = new [6];
        for (var k = 0; k < 6; k++) {
            var ang = k.toFloat() * Math.PI / 3.0;
            var lx = (Math.cos(ang) * cr);
            var ly = (Math.sin(ang) * cr);
            var px = (lx * ca - ly * sa).toNumber();
            var py = (lx * sa + ly * ca).toNumber();
            hexPts[k] = [ex + px, ey + py];
        }
        dc.setColor(hull, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(hexPts);
        dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
        for (var k = 0; k < 6; k++) {
            var p1 = hexPts[k]; var p2 = hexPts[(k + 1) % 6];
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
        // Centre dot (eye).
        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex, ey, (sz / 8) > 1 ? sz / 8 : 1);

        // Two side panels — long thin rectangles perpendicular to facing.
        // Local axes: forward = (ca, sa), side = (-sa, ca).
        // Each panel is a tall rectangle along the SIDE axis, drawn left
        // and right of the cockpit.
        var pw = sz * 0.18;     // panel thickness (half-width along forward)
        var ph = sz * 0.95;     // panel height (along side)
        var offs = sz * 0.55;   // panel centre offset from cockpit
        _drawTiePanel(dc, ex, ey, ca, sa, -offs, pw, ph, panel, edge);
        _drawTiePanel(dc, ex, ey, ca, sa, +offs, pw, ph, panel, edge);

        // Struts: connect cockpit edge (along side axis) to panel centres.
        // side axis = (-sa, ca);  forward axis = (ca, sa).
        dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
        var lEdgeX = ex + (-sa *  cr).toNumber();
        var lEdgeY = ey + ( ca *  cr).toNumber();
        var lPanX  = ex + (-sa *  offs).toNumber();
        var lPanY  = ey + ( ca *  offs).toNumber();
        var rEdgeX = ex + (-sa * -cr).toNumber();
        var rEdgeY = ey + ( ca * -cr).toNumber();
        var rPanX  = ex + (-sa * -offs).toNumber();
        var rPanY  = ey + ( ca * -offs).toNumber();
        dc.drawLine(lEdgeX, lEdgeY, lPanX, lPanY);
        dc.drawLine(rEdgeX, rEdgeY, rPanX, rPanY);
    }

    hidden static function _drawTiePanel(dc, ex, ey, ca, sa, sideOff,
                                         pw, ph, fill, edge) {
        // side axis = (-sa, ca); forward axis = (ca, sa).
        // Rectangle vertices in local (forward, side):
        //   (-pw, sideOff - ph/2)
        //   (+pw, sideOff - ph/2)
        //   (+pw, sideOff + ph/2)
        //   (-pw, sideOff + ph/2)
        var lx = [-pw,  pw,  pw, -pw];
        var ly = [sideOff - ph/2, sideOff - ph/2,
                  sideOff + ph/2, sideOff + ph/2];
        var pts = new [4];
        for (var k = 0; k < 4; k++) {
            var px = (lx[k] * ca - ly[k] * sa).toNumber();
            var py = (lx[k] * sa + ly[k] * ca).toNumber();
            pts[k] = [ex + px, ey + py];
        }
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
        dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
        for (var k = 0; k < 4; k++) {
            var p1 = pts[k]; var p2 = pts[(k + 1) % 4];
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
    }

    hidden static function _drawEnginePair(dc, ex, ey, s, ca, sa,
                                           sternX, halfY) {
        if (s < 6) { return; }
        var gs = (s / 6).toNumber(); if (gs < 1) { gs = 1; }
        var lx1 =  s * sternX; var ly1 = -s * halfY;
        var lx2 =  s * sternX; var ly2 =  s * halfY;
        var e1x = ex + (lx1 * ca - ly1 * sa).toNumber();
        var e1y = ey + (lx1 * sa + ly1 * ca).toNumber();
        var e2x = ex + (lx2 * ca - ly2 * sa).toNumber();
        var e2y = ey + (lx2 * sa + ly2 * ca).toNumber();
        dc.setColor(0x002B66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(e1x, e1y, gs + 1); dc.fillCircle(e2x, e2y, gs + 1);
        dc.setColor(0x77BBFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(e1x, e1y, gs);     dc.fillCircle(e2x, e2y, gs);
    }

    // ── Enemy bolts (green) ─────────────────────────────────
    static function drawBolts(dc, ctrl, ox, oy) {
        for (var i = 0; i < SC_MAX_BOLTS; i++) {
            if (ctrl.bLive[i] == 0) { continue; }
            // Bolts live in the FIRE-TIME gaze frame, so we project
            // to the current view here.  This is what enables the
            // player to dodge: rotating the watch shifts the bolt's
            // apparent path across the screen.
            var px = ctrl.boltScreenX(i);
            var py = ctrl.boltScreenY(i);
            var x0 = px.toNumber() + ox;
            var y0 = py.toNumber() + oy;
            var d = Math.sqrt(ctrl.bVx[i] * ctrl.bVx[i] +
                              ctrl.bVy[i] * ctrl.bVy[i]);
            if (d < 0.001) { continue; }
            var x1 = x0 - (ctrl.bVx[i] / d * 10.0).toNumber();
            var y1 = y0 - (ctrl.bVy[i] / d * 10.0).toNumber();
            dc.setColor(0x004422, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x0 - 1, y0, x1 - 1, y1);
            dc.drawLine(x0, y0 - 1, x1, y1 - 1);
            dc.setColor(0x33FF66, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x0, y0, x1, y1);
        }
    }

    // ── Player laser (red) ──────────────────────────────────
    static function drawLaser(dc, ctrl, ox, oy) {
        if (ctrl.laserAge <= 0) { return; }
        var tx = ctrl.laserTx + ox;
        var ty = ctrl.laserTy + oy;
        dc.setColor(0x660000, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ctrl.cx - 1, ctrl.cy, tx - 1, ty);
        dc.drawLine(ctrl.cx, ctrl.cy - 1, tx, ty - 1);
        dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ctrl.cx, ctrl.cy, tx, ty);
        dc.setColor(0xFFAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ctrl.cx, ctrl.cy, (ctrl.cx + tx) / 2, (ctrl.cy + ty) / 2);
    }

    // ── Explosions ─────────────────────────────────────────
    static function drawExplosions(dc, ctrl, ox, oy) {
        for (var i = 0; i < SC_MAX_EXP; i++) {
            if (ctrl.xLive[i] == 0) { continue; }
            var age = ctrl.xAge[i];
            var x   = ctrl.xX[i] + ox;
            var y   = ctrl.xY[i] + oy;
            var r0  = age * 5 + 4;
            dc.setColor(0xFF7722, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, r0);
            if (age < 3) {
                dc.setColor(0xFFDD55, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, (r0 / 2) > 1 ? r0 / 2 : 1);
            }
        }
    }

    // ── Reticle ────────────────────────────────────────────
    static function drawReticle(dc, ctrl) {
        // Lock check — any enemy near centre?
        var locked = false;
        var r2 = SC_LOCK_R * SC_LOCK_R;
        for (var i = 0; i < SC_MAX_ENEMIES; i++) {
            if (ctrl.eLive[i] == 0) { continue; }
            var dx = ctrl.eSx[i] - ctrl.cx;
            var dy = ctrl.eSy[i] - ctrl.cy;
            if (dx * dx + dy * dy < r2) { locked = true; break; }
        }
        var ring = locked ? 0x33FF44 : 0x66CCEE;
        var line = locked ? 0x99FFAA : 0xAADDFF;
        var outerR = (ctrl.sw < ctrl.sh ? ctrl.sw : ctrl.sh) / 12;
        if (outerR < 16) { outerR = 16; }
        if (outerR > 26) { outerR = 26; }
        var innerR = outerR / 3;
        var gap    = outerR / 3;
        dc.setColor(ring, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ctrl.cx, ctrl.cy, outerR);
        if (locked) {
            var pulse = ((ctrl.tick & 3) < 2) ? innerR + 2 : innerR;
            dc.drawCircle(ctrl.cx, ctrl.cy, pulse);
        }
        dc.setColor(line, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ctrl.cx - outerR + 2, ctrl.cy, ctrl.cx - gap, ctrl.cy);
        dc.drawLine(ctrl.cx + gap, ctrl.cy, ctrl.cx + outerR - 2, ctrl.cy);
        dc.drawLine(ctrl.cx, ctrl.cy - outerR + 2, ctrl.cx, ctrl.cy - gap);
        dc.drawLine(ctrl.cx, ctrl.cy + gap, ctrl.cx, ctrl.cy + outerR - 2);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawPoint(ctrl.cx, ctrl.cy);
    }

    // ── HUD ──────────────────────────────────────────────
    // All HUD elements are intentionally placed inside the safe
    // arc of round screens (vertical 14 %–86 %) and kept very
    // small (FONT_XTINY) so they don't crowd the playfield.
    //
    //   TOP    centred   → "L1  3/5"     (level + kill progress)
    //   BELOW  centred   → score (yellow)
    //   BOTTOM centred row →  ●●● [shields]   A12 [ammo]
    static function drawHUD(dc, ctrl) {
        var cx = ctrl.cx;
        var sh = ctrl.sh;

        // Top: level + progress.
        var tyTop = (sh * 14) / 100; if (tyTop < 6) { tyTop = 6; }
        var progress = "L" + ctrl.level.format("%d") + "  " +
                       ctrl.kills.format("%d") + "/" +
                       ctrl.killTarget.format("%d");
        var lvlCol = (ctrl.levelUpT > 0) ? 0xFFEE66 : 0x99DDFF;
        dc.setColor(lvlCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, tyTop, Graphics.FONT_XTINY, progress,
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Below: score.
        var tyScore = (sh * 22) / 100;
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, tyScore, Graphics.FONT_XTINY,
                    ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Bottom row: shields (left of centre) + ammo (right of centre).
        var tyBot = (sh * 80) / 100;

        // Shields — small filled circles.
        var sxStart = cx - 30;
        for (var i = 0; i < ctrl.maxShields; i++) {
            var px = sxStart - i * 8;
            var py = tyBot + 6;
            if (i < ctrl.shields) {
                dc.setColor(0x33CCFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 3);
            } else {
                dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(px, py, 3);
            }
        }

        // Ammo.
        var ammoCol;
        if      (ctrl.noAmmoT > 0)             { ammoCol = 0xFF3344; }
        else if (ctrl.ammo <= 3)               { ammoCol = 0xFF6666; }
        else if (ctrl.ammo <= ctrl.maxAmmo/3)  { ammoCol = 0xFFAA22; }
        else                                    { ammoCol = 0xFFEE66; }
        dc.setColor(ammoCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 14, tyBot, Graphics.FONT_XTINY,
                    "A" + ctrl.ammo.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);

        // Level-up flash overlay (centred just under reticle).
        if (ctrl.levelUpT > 0) {
            dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ctrl.cy + 30, Graphics.FONT_XTINY,
                        "LEVEL UP!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    static function drawHitFlash(dc, ctrl) {
        dc.setColor(0xFF1133, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        var r = (ctrl.sw < ctrl.sh ? ctrl.sw : ctrl.sh) / 2 - 2;
        dc.drawCircle(ctrl.cx, ctrl.cy, r);
        dc.setPenWidth(1);
    }

    // ── Menu ──────────────────────────────────────────────
    static function drawMenu(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var cx = ctrl.cx;
        // Faint star scatter.
        dc.setColor(0x6688AA, Graphics.COLOR_TRANSPARENT);
        var seed = 314159;
        for (var i = 0; i < 24; i++) {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var sx = seed % sw;
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var sy = seed % sh;
            dc.drawPoint(sx, sy);
        }

        // Title.
        dc.setColor(0xFFCC33, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 12 / 100, Graphics.FONT_MEDIUM,
                    "STAR", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF8833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 22 / 100, Graphics.FONT_SMALL,
                    "COMBAT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 32 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = [
            "Sens:  " + ctrl.sensName(),
            "Diff:  " + ctrl.diffName(),
            "START"
        ];
        for (var i = 0; i < SC_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == SC_ROW_START);
            var bg, bd, fg;
            if (sel && isStart)       { bg = 0x223300; bd = 0xFFEE66; fg = 0xFFEE66; }
            else if (sel)             { bg = 0x102030; bd = 0x66CCEE; fg = 0xCCEEFF; }
            else if (isStart)         { bg = 0x081020; bd = 0x335544; fg = 0xAACCBB; }
            else                       { bg = 0x081020; bd = 0x223344; fg = 0x99AABB; }
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

        // Footer + best.
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        if (ctrl.bestScore > 0) {
            dc.drawText(cx, sh - 28, Graphics.FONT_XTINY,
                        "BEST " + ctrl.bestScore.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN row  tap = act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game Over ─────────────────────────────────────────
    static function drawGameOver(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var cx = ctrl.cx;
        var bw = sw * 72 / 100; if (bw < 160) { bw = 160; }
        var bh = sh * 44 / 100; if (bh < 120) { bh = 120; }
        var bx = (sw - bw) / 2; var by = (sh - bh) / 2;
        dc.setColor(0x000308, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    "DESTROYED", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 38, Graphics.FONT_XTINY,
                    "Score  " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 56, Graphics.FONT_XTINY,
                    "Level  " + ctrl.level.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 74, Graphics.FONT_XTINY,
                    "Best   " + ctrl.bestScore.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap = retry", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
