// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Stateless drawing helpers.
//
// Three responsibilities:
//   • drawMenu     title + START / Reset best
//   • drawGame     score band + 4×4 board
//   • drawOverlay  win / game-over screen with score + best
//
// All drawing is computed each frame from (w, h) so the layout
// scales gracefully on round and square screens of any size. No
// caching or animations — `onUpdate` is only invoked when the
// controller changes state and calls `WatchUi.requestUpdate()`.
//
// Board sizing strategy:
//   The board is a square of side `boardSide = min(w * 0.78, h * 0.65)`,
//   centred horizontally and pushed down below the score band. We
//   reserve ~22% of the height for the HUD on top, and a small hint
//   line at the bottom on touch-capable screens.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.WatchUi;

// Theme — classic 2048 palette
const COL_BG          = 0xFAF8EF;      // page background
const COL_BOARD_BG    = 0xBBADA0;      // board frame
const COL_INK         = 0x776E65;      // dark text
const COL_INK_LIGHT   = 0xA39B91;      // muted text
const COL_ACCENT      = 0xEDC22E;      // 2048 yellow
const COL_DANGER      = 0xC83A3A;      // game over red
const COL_OK          = 0x2A8A3E;      // win green

class UIManager {
    // ── MENU ────────────────────────────────────────────────────────
    // Chess-style menu: bold "2048" title tile, "by Bitochi"
    // attribution, two full-width rounded rows (START / Reset Best).
    static function drawMenu(dc, ctrl, w, h) {
        var cx = w / 2;
        dc.setColor(0x080808, 0x080808); dc.clear();
        if (w == h) {
            dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, h / 2, w / 2 - 1);
        }

        // Title "2048" as a single big colored tile.
        var tileSide = h * 22 / 100; if (tileSide < 52) { tileSide = 52; }
        var tx = cx - tileSide / 2;
        var ty = h * 9 / 100;
        dc.setColor(COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(tx, ty, tileSide, tileSide, 8);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var titleFont = (tileSide >= 90) ? Graphics.FONT_LARGE
                       : (tileSide >= 70) ? Graphics.FONT_MEDIUM
                                          : Graphics.FONT_SMALL;
        var thT = dc.getFontHeight(titleFont);
        dc.drawText(cx, ty + tileSide / 2 - thT / 2, titleFont,
                    "2048", Graphics.TEXT_JUSTIFY_CENTER);

        // Bitochi attribution + best score
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ty + tileSide + 4, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);
        var bestLine = "Best " + ctrl.best.toString();
        if (ctrl.bestExp > 0) {
            bestLine = bestLine + "  -  Max " + Tile.valueOf(ctrl.bestExp).toString();
        }
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ty + tileSide + 18, Graphics.FONT_XTINY,
                    bestLine, Graphics.TEXT_JUSTIFY_CENTER);

        // Two chess-style rows
        var labels = ["START", "Reset Best"];
        var rowH = (h * 13) / 100; if (rowH < 26) { rowH = 26; } if (rowH > 36) { rowH = 36; }
        var rowW = (w * 78) / 100; if (rowW < 140) { rowW = 140; }
        var rowX = (w - rowW) / 2;
        var gap  = (h * 2) / 100;  if (gap < 4) { gap = 4; }
        var rowY0 = ty + tileSide + 36;
        for (var i = 0; i < MI_ITEMS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            var sel = (ctrl.menuCursor == i);
            var isStart = (i == MI_START);

            dc.setColor(sel ? (isStart ? 0x1A4400 : 0x1A3A6A) : 0x111820,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x44BB22 : 0x55AAFF) : 0x2A3A4A,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);

            if (sel) {
                dc.setColor(isStart ? 0x44BB22 : 0x55AAFF,
                            Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xAAFF66 : 0xCCEEFF) : 0x778899,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── GAME ────────────────────────────────────────────────────────
    static function drawGame(dc, ctrl, w, h) {
        dc.setColor(COL_BG, COL_BG);
        dc.clear();

        var grid = ctrl.grid;

        // ── HUD: score + best ───────────────────────────────────────
        _drawHud(dc, ctrl, w, h);

        // ── Board layout ────────────────────────────────────────────
        var boardSide = w * 78 / 100;
        var maxByH    = h * 65 / 100;
        if (boardSide > maxByH) { boardSide = maxByH; }
        var bx = (w - boardSide) / 2;
        var by = h * 26 / 100;
        dc.setColor(COL_BOARD_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, boardSide, boardSide, 6);

        var pad     = boardSide / 32;       // gutter between tiles
        if (pad < 2) { pad = 2; }
        var cellSide = (boardSide - pad * (GRID_SIZE + 1)) / GRID_SIZE;

        for (var r = 0; r < GRID_SIZE; r++) {
            for (var c = 0; c < GRID_SIZE; c++) {
                var x = bx + pad + c * (cellSide + pad);
                var y = by + pad + r * (cellSide + pad);
                var e = grid.get(r, c);
                Tile.draw(dc, x, y, cellSide, e, grid.isMerged(r, c));
            }
        }

        // Bottom hint — reminds the player swipes work + button map.
        dc.setColor(COL_INK_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h - 18, Graphics.FONT_XTINY,
                    "Swipe / SEL right / hold left",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _drawHud(dc, ctrl, w, h) {
        var cx = w / 2;
        var topY = h * 8 / 100;

        dc.setColor(COL_INK_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 18 / 100, topY, Graphics.FONT_XTINY,
                    "SCORE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 82 / 100, topY, Graphics.FONT_XTINY,
                    "BEST",  Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(COL_INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 18 / 100, topY + 12, Graphics.FONT_TINY,
                    ctrl.score.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 82 / 100, topY + 12, Graphics.FONT_TINY,
                    ctrl.best.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── OVERLAYS (WIN / OVER) ───────────────────────────────────────
    static function drawOverlay(dc, ctrl, w, h) {
        var win = (ctrl.state == GS_WIN);

        // Tinted full-screen background to make it obvious.
        dc.setColor(win ? 0xE8F6EC : 0xF6E5E5, COL_BG);
        dc.clear();

        var cx = w / 2;
        dc.setColor(win ? COL_OK : COL_DANGER, Graphics.COLOR_TRANSPARENT);
        var titleFont = Graphics.FONT_MEDIUM;
        var thT = dc.getFontHeight(titleFont);
        dc.drawText(cx, h * 18 / 100 - thT / 2, titleFont,
                    win ? "YOU MADE 2048!" : "GAME OVER",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(COL_INK_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 38 / 100, Graphics.FONT_XTINY,
                    "SCORE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 44 / 100, Graphics.FONT_MEDIUM,
                    ctrl.score.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(COL_INK_LIGHT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 60 / 100, Graphics.FONT_XTINY,
                    "BEST", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 66 / 100, Graphics.FONT_SMALL,
                    ctrl.best.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(COL_INK_LIGHT, Graphics.COLOR_TRANSPARENT);
        var hint = win ? "SEL: keep going" : "Any key: menu";
        dc.drawText(cx, h - 22, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
