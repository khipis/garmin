// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Render helpers (menu / HUD / grid / player).
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

const GM_MENU_ROWS = 3;

class UIManager {

    static function rowGeom(sw, sh) {
        var rowH = (sh * 10) / 100; if (rowH < 20) { rowH = 20; } if (rowH > 27) { rowH = 27; }
        var rowW = (sw * 70) / 100; if (rowW < 126) { rowW = 126; }
        var rowX = (sw - rowW) / 2;
        var gap  = (sh * 2)  / 100; if (gap  < 4)  { gap  = 4;  }
        var total = GM_MENU_ROWS * rowH + (GM_MENU_ROWS - 1) * gap;
        var rowY0 = (sh - total) / 2 + (sh * 5) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x080614, 0x080614); dc.clear();
        if (sw == sh) {
            dc.setColor(0x110A22, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 10 / 100, Graphics.FONT_SMALL,
                    "GRAVITY", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 19 / 100, Graphics.FONT_SMALL,
                    "MINER", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var diffs = ["Easy", "Normal", "Tough"];
        var labels = [
            "Depth: "  + diffs[ctrl.menuDiff],
            "Lives: "  + ctrl.menuLives.format("%d"),
            "START"
        ];
        for (var i = 0; i < GM_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == GM_MENU_ROWS - 1);
            dc.setColor(sel ? (isStart ? 0x223010 : 0x102240) : 0x0C0C20, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFCC22 : 0x44CCFF) : 0x223344, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xFFEE99 : 0xCCEEFF) : 0x8899AA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 28, Graphics.FONT_XTINY,
                    "UP/DN row  tap = act", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "Gravity Miner by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);
    }

    static function drawHUD(dc, sw, sh, ctrl) {
        var ty = (sh * 3) / 100; if (ty < 3) { ty = 3; }
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, ty, Graphics.FONT_XTINY,
                    "L" + ctrl.res.level.format("%d") + "  $" + ctrl.res.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw - 8, ty, Graphics.FONT_XTINY,
                    "Hp " + ctrl.lives.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
    }

    static function drawGrid(dc, ox, oy, cell, grid) {
        for (var r = 0; r < grid.h; r++) {
            for (var c = 0; c < grid.w; c++) {
                var t = grid.get(r, c);
                var x = ox + c * cell;
                var y = oy + r * cell;
                if (t == GM_WALL) {
                    dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(x, y, cell, cell);
                } else if (t == GM_DIRT) {
                    dc.setColor(0x4A3018, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                } else if (t == GM_ROCK) {
                    dc.setColor(0x3A2A1C, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
                    var r2 = cell * 4 / 10; if (r2 < 2) { r2 = 2; }
                    dc.fillCircle(x + cell / 2, y + cell / 2, r2);
                } else if (t == GM_ORE) {
                    dc.setColor(0x2A1810, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
                    var r3 = cell / 3; if (r3 < 2) { r3 = 2; }
                    dc.fillCircle(x + cell / 2, y + cell / 2, r3);
                    dc.setColor(0xFFEE99, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(x + cell / 2 - 1, y + cell / 2 - 1, 1);
                } else if (t == GM_GEM) {
                    dc.setColor(0x1A1024, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0xCC44FF, Graphics.COLOR_TRANSPARENT);
                    var mx = x + cell / 2; var my = y + cell / 2;
                    var d3 = cell / 3; if (d3 < 2) { d3 = 2; }
                    dc.fillPolygon([[mx, my - d3],
                                    [mx + d3, my],
                                    [mx, my + d3],
                                    [mx - d3, my]]);
                    dc.setColor(0xEEAAFF, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(mx - 1, my - 1, 1);
                } else {
                    dc.setColor(0x0A0612, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                }
            }
        }
    }

    static function drawPlayer(dc, ox, oy, cell, p) {
        var x = ox + p.c * cell;
        var y = oy + p.r * cell;
        dc.setColor(p.alive ? 0xFFCC22 : 0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 2, y + 2, cell - 4, cell - 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var dx = (p.facing == GM_DIR_L) ? -1 : (p.facing == GM_DIR_R ? 1 : 0);
        var dy = (p.facing == GM_DIR_D) ?  1 :  0;
        dc.fillCircle(x + cell / 2 + dx * (cell / 4),
                      y + cell / 2 + dy * (cell / 4),
                      cell >= 12 ? 2 : 1);
    }

    static function drawDirIndicator(dc, sw, sh, dir) {
        var x = 12;
        var y = sh - 26;
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 7);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        var lbl = "L";
        if (dir == GM_DIR_R) { lbl = "R"; }
        if (dir == GM_DIR_D) { lbl = "D"; }
        dc.drawText(x, y - 8, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
    }

    static function drawResult(dc, sw, sh, won, ctrl) {
        var bw = sw * 70 / 100; if (bw < 160) { bw = 160; }
        var bh = sh * 40 / 100; if (bh < 110) { bh = 110; }
        var bx = (sw - bw) / 2;
        var by = (sh - bh) / 2;
        var cx = sw / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(won ? 0x44FF88 : 0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    won ? "EXTRACTED!" : "CRUSHED", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 36, Graphics.FONT_XTINY,
                    "Score " + ctrl.res.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 56, Graphics.FONT_XTINY,
                    "Best  " + ctrl.res.bestScore.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
