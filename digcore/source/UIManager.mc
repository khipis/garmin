// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Render helpers for Dig Core (Boulder-Dash clone).
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

class UIManager {

    // Geometry of one chess-style menu row.
    static function rowGeom(sw, sh) {
        var rowH = (sh * 10) / 100; if (rowH < 20) { rowH = 20; } if (rowH > 27) { rowH = 27; }
        var rowW = (sw * 70) / 100; if (rowW < 126) { rowW = 126; }
        var rowX = (sw - rowW) / 2;
        var gap  = (sh * 2)  / 100; if (gap  < 4)  { gap  = 4;  }
        var total = DC_MENU_ROWS * rowH + (DC_MENU_ROWS - 1) * gap;
        var rowY0 = (sh - total) / 2 + (sh * 5) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x10080A, 0x10080A); dc.clear();
        if (sw == sh) {
            dc.setColor(0x22140A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 10 / 100, Graphics.FONT_SMALL,
                    "DIG", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 19 / 100, Graphics.FONT_SMALL,
                    "CORE", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = [
            "Start L: " + ctrl.menuStartLevel.format("%d"),
            "Lives:   " + ctrl.menuLives.format("%d"),
            "START"
        ];
        for (var i = 0; i < DC_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == DC_MENU_ROWS - 1);
            dc.setColor(sel ? (isStart ? 0x442200 : 0x331810) : 0x1A1208, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFCC22 : 0xFF8822) : 0x553322, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xFFEE99 : 0xFFCCAA) : 0xAA8866, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x886655, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 28, Graphics.FONT_XTINY,
                    "UP/DN row  tap = act", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAA44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "Dig Core by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);
    }

    static function drawHUD(dc, sw, sh, ctrl) {
        var ty = (sh * 3) / 100; if (ty < 3) { ty = 3; }
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, ty, Graphics.FONT_XTINY,
                    "D " + ctrl.player.diamonds.format("%d")
                         + "/" + ctrl.diamondGoal.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x44DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, ty, Graphics.FONT_XTINY,
                    "L" + ctrl.level.format("%d") + "  T" + ctrl.timeLeft.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF6688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw - 8, ty, Graphics.FONT_XTINY,
                    "x" + ctrl.lives.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
        if (ctrl.exitOpen) {
            var ty2 = (sh * 3) / 100 + 14;
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sw / 2, ty2, Graphics.FONT_XTINY,
                        "EXIT OPEN", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    static function drawGrid(dc, ox, oy, cell, grid) {
        for (var r = 0; r < grid.h; r++) {
            for (var c = 0; c < grid.w; c++) {
                var t = grid.get(r, c);
                var x = ox + c * cell;
                var y = oy + r * cell;
                if (t == TC_WALL) {
                    dc.setColor(0x202020, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0x404040, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(x, y, cell, cell);
                } else if (t == TC_BRICK) {
                    dc.setColor(0x7A4422, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    if (cell >= 8) {
                        dc.setColor(0x442010, Graphics.COLOR_TRANSPARENT);
                        // brick courses
                        dc.drawLine(x, y + cell / 2, x + cell, y + cell / 2);
                        dc.drawLine(x + cell / 2, y, x + cell / 2, y + cell / 2);
                        dc.drawLine(x + cell / 4, y + cell / 2, x + cell / 4, y + cell);
                        dc.drawLine(x + cell * 3 / 4, y + cell / 2, x + cell * 3 / 4, y + cell);
                    }
                } else if (t == TC_DIRT) {
                    dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    if (cell >= 8) {
                        dc.setColor(0x402510, Graphics.COLOR_TRANSPARENT);
                        dc.fillRectangle(x + 1, y + cell - 2, cell - 2, 1);
                    }
                } else if (t == TC_ROCK) {
                    dc.setColor(0x382818, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0x999988, Graphics.COLOR_TRANSPARENT);
                    var rr = cell * 4 / 10; if (rr < 2) { rr = 2; }
                    dc.fillCircle(x + cell / 2, y + cell / 2, rr);
                    dc.setColor(0xCCBBAA, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(x + cell / 2 - cell / 6,
                                  y + cell / 2 - cell / 6, 1);
                } else if (t == TC_DIAMOND) {
                    dc.setColor(0x382818, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0x44DDFF, Graphics.COLOR_TRANSPARENT);
                    var mx = x + cell / 2; var my = y + cell / 2;
                    var d2 = cell / 3; if (d2 < 2) { d2 = 2; }
                    dc.fillPolygon([[mx, my - d2],
                                    [mx + d2, my],
                                    [mx, my + d2],
                                    [mx - d2, my]]);
                    dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(mx - 1, my - 1, 1);
                } else if (t == TC_EXIT) {
                    dc.setColor(0x114422, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(x, y, cell, cell);
                    if (cell >= 10) {
                        dc.fillRectangle(x + 2, y + 2, cell - 4, cell - 4);
                        dc.setColor(0x114422, Graphics.COLOR_TRANSPARENT);
                        dc.drawText(x + cell / 2, y - 1, Graphics.FONT_XTINY,
                                    "E", Graphics.TEXT_JUSTIFY_CENTER);
                    }
                } else {
                    dc.setColor(0x180A04, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                }
            }
        }
    }

    static function drawFireflies(dc, ox, oy, cell, flies) {
        if (flies == null) { return; }
        for (var i = 0; i < flies.size(); i++) {
            var f = flies[i];
            if (!f.alive) { continue; }
            var x = ox + f.c * cell;
            var y = oy + f.r * cell;
            var cx = x + cell / 2;
            var cy = y + cell / 2;
            var rad = cell / 2 - 1; if (rad < 3) { rad = 3; }
            // Body — vivid green with a darker outline.
            dc.setColor(0x66FF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, rad);
            dc.setColor(0x224411, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, rad);
            // Eyes pointing along facing.
            var eyeR = rad / 3; if (eyeR < 1) { eyeR = 1; }
            var eyeOffX = rad / 2;
            var eyeY    = cy - rad / 3;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - eyeOffX, eyeY, eyeR);
            dc.fillCircle(cx + eyeOffX, eyeY, eyeR);
            var pdx = 0; var pdy = 0;
            if      (f.dir == DC_DIR_U) { pdy = -1; }
            else if (f.dir == DC_DIR_D) { pdy =  1; }
            else if (f.dir == DC_DIR_L) { pdx = -1; }
            else                        { pdx =  1; }
            var pupilR = eyeR / 2; if (pupilR < 1) { pupilR = 1; }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - eyeOffX + pdx, eyeY + pdy, pupilR);
            dc.fillCircle(cx + eyeOffX + pdx, eyeY + pdy, pupilR);
        }
    }

    static function drawPlayer(dc, ox, oy, cell, p) {
        if (!p.alive) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0xFFEE88, Graphics.COLOR_TRANSPARENT);
        }
        var x = ox + p.c * cell;
        var y = oy + p.r * cell;
        var cx = x + cell / 2;
        var cy = y + cell / 2;
        dc.fillRectangle(x + 2, y + 2, cell - 4, cell - 4);
        // Helmet light direction
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var d = GridManager.dirDelta(p.facing);
        dc.fillCircle(cx + d[1] * (cell / 4),
                      cy + d[0] * (cell / 4),
                      cell >= 12 ? 2 : 1);
    }

    static function drawResult(dc, sw, sh, won, ctrl) {
        var bw = sw * 70 / 100; if (bw < 160) { bw = 160; }
        var bh = sh * 42 / 100; if (bh < 120) { bh = 120; }
        var bx = (sw - bw) / 2;
        var by = (sh - bh) / 2;
        var cx = sw / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(won ? 0x44FF88 : 0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    won ? "CLEARED!" : "CRUSHED", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 38, Graphics.FONT_XTINY,
                    "Diamonds " + ctrl.player.diamonds.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 56, Graphics.FONT_XTINY,
                    "Score " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 74, Graphics.FONT_XTINY,
                    "Best  " + ctrl.bestScore.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
