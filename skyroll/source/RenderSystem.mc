// ═══════════════════════════════════════════════════════════════
// RenderSystem.mc — Iso-tile drawing helpers.
//
// Public:
//   drawSky(dc, ctrl)               — gradient backdrop
//   drawPath(dc, ctrl)              — tile diamonds in painter order
//   drawBall(dc, ctrl)              — shadow + ball + roll wobble
//
// Draws strictly back-to-front (high y rows first) so near tiles
// overpaint far ones.  A row of 16 tiles takes < 50 polygon
// fills; the visible window covers ≈ 12 rows so render is well
// under budget even on Vivoactive-class hardware.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

class RenderSystem {

    // ── Sky background (also drawn behind menu/over screens). ──
    static function drawSky(dc, ctrl) {
        var w = ctrl.sw; var h = ctrl.sh;
        // Top band — deep blue.
        dc.setColor(0x081424, 0x081424); dc.clear();
        // Soft horizon glow.
        var bands = 7;
        for (var i = 0; i < bands; i++) {
            var col = _lerpCol(0x183258, 0x6080B0, i, bands);
            var y0 = h * (28 + i * 4) / 100;
            var bh = h * 4 / 100; if (bh < 3) { bh = 3; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, y0, w, bh);
        }
        // Sparse star dots high up.
        dc.setColor(0xE8F0FF, Graphics.COLOR_TRANSPARENT);
        var seed = 7793;
        for (var k = 0; k < 18; k++) {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var sx = seed % w;
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var sy = (seed % (h * 25 / 100));
            dc.drawPoint(sx, sy);
        }
    }

    hidden static function _lerpCol(a, b, i, n) {
        var t  = i.toFloat() / (n - 1).toFloat();
        var ar = (a >> 16) & 0xFF; var ag = (a >> 8) & 0xFF; var ab = a & 0xFF;
        var br = (b >> 16) & 0xFF; var bg = (b >> 8) & 0xFF; var bb = b & 0xFF;
        var r = ar + ((br - ar).toFloat() * t).toNumber();
        var g = ag + ((bg - ag).toFloat() * t).toNumber();
        var bl= ab + ((bb - ab).toFloat() * t).toNumber();
        return (r << 16) | (g << 8) | bl;
    }

    // ── Visible-tile painter ───────────────────────────────────
    static function drawPath(dc, ctrl) {
        var path = ctrl.path;
        var cam  = ctrl.cam;
        // Visible y-range: from a couple rows behind the ball to
        // enough rows ahead that the path goes off the top of the
        // viewport.  Iterate FAR rows first (highest y).
        var by   = ctrl.physics.py.toNumber();
        var yLo  = by - 4;
        var yHi  = by + 20;
        if (yLo < 0) { yLo = 0; }
        if (yHi > path.nextY - 1) { yHi = path.nextY - 1; }

        for (var y = yHi; y >= yLo; y--) {
            // Within a row, drawing order doesn't matter much
            // (the path is at most a few tiles wide).  Iterate
            // x ascending for predictable colour banding.
            for (var x = -SR_X_HALF; x < SR_X_HALF; x++) {
                var t = path.tileAt(x, y);
                if (t == SR_T_NONE) { continue; }
                _drawTile(dc, ctrl, x, y, t,
                          path.breakAt(x, y));
            }
        }
    }

    hidden static function _drawTile(dc, ctrl, wx, wy, t, breakRem) {
        var p   = ctrl.cam.worldToScreen(wx.toFloat(), wy.toFloat(),
                                          ctrl.cx, ctrl.cy);
        var bx0 = p[0]; var by0 = p[1];
        // Diamond corners — relative to bottom corner.
        var hw  = SR_TILE_HW; var hh = SR_TILE_HH;
        var top    = [bx0,       by0 - 2 * hh];
        var right  = [bx0 + hw,  by0 - hh];
        var bottom = [bx0,       by0];
        var left   = [bx0 - hw,  by0 - hh];

        // Side / thickness faces — a small "skirt" below the
        // diamond's bottom corner, gives tiles a sense of mass.
        var skirt = 4;
        var sbot  = [bx0, by0 + skirt];
        var sleft = [bx0 - hw, by0 - hh + skirt];
        var srght = [bx0 + hw, by0 - hh + skirt];
        dc.setColor(0x0F1830, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([bottom, left,  sleft, sbot]);
        dc.setColor(0x182338, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([bottom, right, srght, sbot]);

        // Top face — colour depends on tile type.
        var col;
        var rim;
        if      (t == SR_T_NORMAL)  { col = 0xC8D4DC; rim = 0x7A8898; }
        else if (t == SR_T_SOFT)    { col = 0xA0D8A4; rim = 0x4E8458; }
        else if (t == SR_T_BOOST)   { col = 0xFFE07A; rim = 0xC8941A; }
        else if (t == SR_T_FRAGILE) { col = 0xE6A86A; rim = 0x9A5A28; }
        else if (t == SR_T_BREAK)   {
            // Pulse darker as it collapses.
            var k = breakRem * 30 / SR_BREAK_TICKS;
            if (k < 0) { k = 0; } if (k > 30) { k = 30; }
            col = 0x884420 + (k << 16); rim = 0x422010;
        }
        else                        { col = 0xC8D4DC; rim = 0x7A8898; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([top, right, bottom, left]);
        dc.setColor(rim, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(top[0],    top[1],    right[0],  right[1]);
        dc.drawLine(right[0],  right[1],  bottom[0], bottom[1]);
        dc.drawLine(bottom[0], bottom[1], left[0],   left[1]);
        dc.drawLine(left[0],   left[1],   top[0],    top[1]);

        // BOOST arrow detail.
        if (t == SR_T_BOOST) {
            dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                [bx0 - 4, by0 - hh - 2],
                [bx0 + 4, by0 - hh - 2],
                [bx0,     by0 - hh - 6]
            ]);
        }
        // FRAGILE crack mark.
        if (t == SR_T_FRAGILE) {
            dc.setColor(0x6A3010, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bx0 - 3, by0 - hh,     bx0,     by0 - hh - 2);
            dc.drawLine(bx0,     by0 - hh - 2, bx0 + 3, by0 - hh + 1);
        }
    }

    // ── Ball (shadow + body + recoil/roll wobble). ────────────
    static function drawBall(dc, ctrl) {
        var p   = ctrl.cam.worldToScreen(ctrl.physics.px,
                                          ctrl.physics.py,
                                          ctrl.cx, ctrl.cy);
        var bx  = p[0]; var by = p[1];
        // Falling state: ball drops below the path with gravity.
        var dropY = 0;
        if (ctrl.state == SR_FALL) {
            var t = ctrl.fallT.toFloat();
            dropY = ((SR_FALL_GRAV.toFloat() / 100.0) * t * t).toNumber();
        }
        // Shadow stays on the tile floor.
        if (ctrl.state == SR_PLAY) {
            dc.setColor(0x0A0F18, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 5, by - 1, 11, 3);
        }
        // Ball body.
        var ballR = 6;
        if (ctrl.state == SR_FALL && ctrl.fallT > SR_FALL_TICKS - 6) {
            ballR = ballR - (SR_FALL_TICKS - ctrl.fallT) / 2;
            if (ballR < 2) { ballR = 2; }
        }
        var by2 = by - 6 + dropY;
        // Dark outline ring.
        dc.setColor(0x223044, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by2, ballR + 1);
        // Light body.
        dc.setColor(0xDCE6F8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by2, ballR);
        // Highlight.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx - 2, by2 - 3, 2, 2);
    }
}
