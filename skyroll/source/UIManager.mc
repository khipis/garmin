// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Frame composition + HUD + chess-style menu.
//
// Layers (back → front):
//   • Sky gradient
//   • Path tiles (back → front)
//   • Ball (shadow + body)
//   • HUD (distance / best)
//   • OVER card / MENU overlay
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

class UIManager {

    // ── Menu geometry (for tap hit-testing). ────────────────
    // Space-aware: the four rows are packed into the strip between the
    // title block and the reserved bottom footer, so the extra
    // LEADERBOARD row never overlaps the footer or each other on small
    // round watches.  Height/width/gaps are ~15 % tighter than the old
    // 3-row menu to make room for the new row.
    static function rowGeom(sw, sh) {
        var topZone      = (sh * 38) / 100;            // rows live below "by Bitochi"
        var bottomMargin = (sh * 11) / 100; if (bottomMargin < 30) { bottomMargin = 30; }
        var gap          = (sh * 2)  / 100; if (gap < 3) { gap = 3; }
        var avail        = (sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (SR_MENU_ROWS - 1)) / SR_MENU_ROWS;
        if (rowH > 25) { rowH = 25; }                  // was 28 → ~15 % smaller
        if (rowH < 13) { rowH = 13; }
        var rowW = (sw * 60) / 100; if (rowW < 122) { rowW = 122; }  // was 64 %
        var rowX = (sw - rowW) / 2;
        var used  = SR_MENU_ROWS * rowH + (SR_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function draw(dc, ctrl) {
        if (ctrl.state == SR_MENU) { _drawMenu(dc, ctrl); return; }

        RenderSystem.drawSky(dc, ctrl);
        RenderSystem.drawPath(dc, ctrl);
        RenderSystem.drawBall(dc, ctrl);

        _drawHUD(dc, ctrl);
        if (ctrl.state == SR_OVER) { _drawOver(dc, ctrl); }
    }

    // ── HUD ─────────────────────────────────────────────────
    hidden static function _drawHUD(dc, ctrl) {
        var sh = ctrl.sh; var ccx = ctrl.cx;
        // Top: distance score.
        var topY = sh * 6 / 100;
        if (topY < 4) { topY = 4; }
        var d = ctrl.distance.format("%d");
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, topY, Graphics.FONT_XTINY, d,
                    Graphics.TEXT_JUSTIFY_CENTER);
        // Just below: small "M" suffix and difficulty hint.
        dc.setColor(0xAACCDD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, topY + 14, Graphics.FONT_XTINY,
                    "m  D " + (ctrl.path.difficulty() * 100.0).toNumber().format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Bottom-right: best.
        if (ctrl.bestScore > 0) {
            dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ctrl.sw - 6, sh * 84 / 100,
                        Graphics.FONT_XTINY,
                        "B " + ctrl.bestScore.format("%d"),
                        Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Bottom-left: boost flash.
        if (ctrl.boostFlash > 0) {
            dc.setColor(0xFF8833, Graphics.COLOR_TRANSPARENT);
            dc.drawText(6, sh * 84 / 100, Graphics.FONT_XTINY,
                        "BOOST", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ── OVER card ───────────────────────────────────────────
    hidden static function _drawOver(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var ccx = ctrl.cx;
        var bw = sw * 78 / 100; if (bw < 170) { bw = 170; }
        var bh = sh * 50 / 100; if (bh < 140) { bh = 140; }
        var bx = (sw - bw) / 2; var by = (sh - bh) / 2;
        dc.setColor(0x000814, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(0xFFCC55, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawText(ccx, by + 6, Graphics.FONT_SMALL,
                    "FELL", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 38, Graphics.FONT_XTINY,
                    "Dist  " + ctrl.distance.format("%d") + " m",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(ccx, by + 56, Graphics.FONT_XTINY,
                    "Best  " + ctrl.bestScore.format("%d") + " m",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + bh - 16, Graphics.FONT_XTINY,
                    "tap = retry", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Chess-style MENU ────────────────────────────────────
    hidden static function _drawMenu(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var ccx = ctrl.cx;
        // Sky backdrop (same gradient as in-game).
        RenderSystem.drawSky(dc, ctrl);

        // Floating-tile decoration under the title.
        _drawTitleTile(dc, ctrl);

        // Title.
        dc.setColor(0xFFE066, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 11 / 100, Graphics.FONT_MEDIUM,
                    "SKY", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 22 / 100, Graphics.FONT_SMALL,
                    "ROLL", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 33 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = [
            "Sens:  " + ctrl.sensName(),
            "Diff:  " + ctrl.diffName(),
            "START"
        ];
        for (var i = 0; i < SR_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);

            if (i == SR_ROW_LB) {
                // Hype-y gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == SR_ROW_START);
            var bg; var bd; var fg;
            if (sel && isStart)  { bg = 0x223300; bd = 0xFFEE66; fg = 0xFFEE66; }
            else if (sel)         { bg = 0x102444; bd = 0x66B6FF; fg = 0xDCEEFF; }
            else if (isStart)     { bg = 0x081020; bd = 0x335544; fg = 0xAACCBB; }
            else                   { bg = 0x081020; bd = 0x223344; fg = 0x99AABB; }
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
            dc.drawText(ccx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Best score footer.
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        if (ctrl.bestScore > 0) {
            dc.drawText(ccx, sh - 28, Graphics.FONT_XTINY,
                        "BEST " + ctrl.bestScore.format("%d") + " m",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(ccx, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN  TAP = act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _drawTitleTile(dc, ctrl) {
        // Decorative single iso tile + a ball, just under the title.
        var ccx = ctrl.cx;
        var cy0 = ctrl.sh * 17 / 100;
        var hw  = SR_TILE_HW; var hh = SR_TILE_HH;
        var top    = [ccx,        cy0 - hh];
        var right  = [ccx + hw,   cy0     ];
        var bottom = [ccx,        cy0 + hh];
        var left   = [ccx - hw,   cy0     ];
        // Skirt.
        dc.setColor(0x0F1830, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([bottom, left,  [ccx - hw, cy0 + 4], [ccx, cy0 + hh + 4]]);
        dc.setColor(0x182338, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([bottom, right, [ccx + hw, cy0 + 4], [ccx, cy0 + hh + 4]]);
        // Top.
        dc.setColor(0xC8D4DC, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([top, right, bottom, left]);
        dc.setColor(0x7A8898, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(top[0],   top[1],   right[0],  right[1]);
        dc.drawLine(right[0], right[1], bottom[0], bottom[1]);
        dc.drawLine(bottom[0],bottom[1],left[0],   left[1]);
        dc.drawLine(left[0],  left[1],  top[0],    top[1]);
        // Ball on top.
        dc.setColor(0x0A0F18, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ccx - 5, cy0 - 1, 11, 3);
        dc.setColor(0x223044, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ccx, cy0 - 6, 7);
        dc.setColor(0xDCE6F8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ccx, cy0 - 6, 6);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ccx - 2, cy0 - 9, 2, 2);
    }
}
