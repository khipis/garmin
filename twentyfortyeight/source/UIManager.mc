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

        // Title "2048" as a single colored tile (kept compact so the
        // attribution, best line and the two rows all clear each other).
        var tileSide = h * 17 / 100; if (tileSide < 44) { tileSide = 44; } if (tileSide > 66) { tileSide = 66; }
        var tx = cx - tileSide / 2;
        var ty = h * 6 / 100;
        dc.setColor(COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(tx, ty, tileSide, tileSide, 8);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var titleFont = (tileSide >= 70) ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
        var thT = dc.getFontHeight(titleFont);
        dc.drawText(cx, ty + tileSide / 2 - thT / 2, titleFont,
                    "2048", Graphics.TEXT_JUSTIFY_CENTER);

        var tileBottom = ty + tileSide;
        var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);

        // Bitochi attribution
        var attrY = tileBottom + 8;
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, attrY, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Best score, one full line below the attribution so they never touch
        var bestY = attrY + xtinyH + 2;
        var bestLine = "Best " + ctrl.best.toString();
        if (ctrl.bestExp > 0) {
            bestLine = bestLine + "  -  Max " + Tile.valueOf(ctrl.bestExp).toString();
        }
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, bestY, Graphics.FONT_XTINY,
                    bestLine, Graphics.TEXT_JUSTIFY_CENTER);

        // Three chess-style rows below everything. Layout is space-aware:
        // the row height shrinks to whatever fits between the best line and
        // the bottom margin, so adding the LEADERBOARD row never overlaps.
        var labels = ["START", "", "Reset Best"];   // [1] = LEADERBOARD (special)
        var rowW = (w * 72) / 100; if (rowW < 130) { rowW = 130; }
        var rowX = (w - rowW) / 2;
        var rowY0 = bestY + xtinyH + 8;
        var bottomMargin = (h * 4) / 100;
        var gap  = (h * 2) / 100; if (gap < 5) { gap = 5; }
        var avail = h - rowY0 - bottomMargin;
        var rowH = (avail - gap * (MI_ITEMS - 1)) / MI_ITEMS;
        if (rowH > 34) { rowH = 34; }
        if (rowH < 20) { rowH = 20; }

        for (var i = 0; i < MI_ITEMS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (ctrl.menuCursor == i);

            if (i == MI_LEADERBOARD) {
                // Hype-y gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

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
        var boardSide = w * 74 / 100;     // 78% → 74% (−5%)
        var maxByH    = h * 62 / 100;     // 65% → 62% (−5%)
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
