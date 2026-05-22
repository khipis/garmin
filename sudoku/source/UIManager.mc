// ═══════════════════════════════════════════════════════════════
// UIManager.mc — All rendering helpers.
//
// Stateless drawing functions called from MainView.onUpdate. Layout
// is recomputed each frame from current screen dimensions so the same
// code works on every form factor (round Fenix, square Vivoactive,
// small Forerunner, etc.).
//
// Colour palette (kept dark / high contrast for OLED legibility):
//   bg            0x000000
//   gridLine      0x445566  (thin) / 0x88AACC (thick box edges)
//   fixedDigit    0xFFFFFF
//   userDigit     0x44CCFF  (cyan)
//   errorDigit    0xFF4444  (red)
//   selBg         0xFFCC00  (gold) — selected cell background tint
//   rowColHL      0x102030  (dark blue) — selected row/column tint
//   completeFlash 0x44FF44  (green)
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.WatchUi;

class UIManager {

    // Cached layout (recomputed on each draw — cheap so no need to memo).
    var sw;
    var sh;
    var cellPx;       // pixel size of one grid cell
    var boardX;       // top-left X of the grid
    var boardY;       // top-left Y of the grid

    function initialize() {
        sw = 0; sh = 0; cellPx = 0; boardX = 0; boardY = 0;
    }

    // Compute layout for a given grid side n and the active state.
    // Grid is centred horizontally, biased a little upward so the
    // bottom area can host the HUD / number picker without clipping.
    function layout(dc, n, state) {
        sw = dc.getWidth();
        sh = dc.getHeight();
        var minDim = (sw < sh) ? sw : sh;
        // Reserve room above (HUD) and below (controls / time).
        var topPad = sh * 12 / 100;
        var botPad = sh * 14 / 100;
        var avail  = sh - topPad - botPad;
        if (avail > sw) { avail = sw; }
        // Cell size derived from grid n; keep board square.
        cellPx = avail / n;
        if (cellPx < 8) { cellPx = 8; }
        var boardSide = cellPx * n;
        boardX = (sw - boardSide) / 2;
        boardY = topPad + (avail - boardSide) / 2;
        if (boardY < topPad) { boardY = topPad; }
    }

    // ── Menu ─────────────────────────────────────────────────────────
    function drawMenu(dc, ctrl) {
        dc.setColor(0x000000, 0x000000); dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 5 / 100, Graphics.FONT_SMALL,
                    "SUDOKU", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 16 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rows = [
            "Mode: "   + ((ctrl.mode == MODE_QUICK)   ? "QUICK 4x4"     : "CLASSIC 9x9"),
            "Diff: "   + _diffLabel(ctrl.diff),
            "Errors: " + ((ctrl.valMode == VAL_RELAXED) ? "RELAX" : "STRICT"),
            "START"
        ];
        var rowH = h * 11 / 100; if (rowH < 22) { rowH = 22; }
        var rowW = w * 78 / 100;
        var rowX = (w - rowW) / 2;
        var gap  = h * 2 / 100;  if (gap < 3)  { gap  = 3;  }
        var startY = h * 24 / 100;

        for (var i = 0; i < 4; i++) {
            var ry = startY + i * (rowH + gap);
            var sel = (i == ctrl.menuSel);
            var isStart = (i == 3);
            // Row background
            dc.setColor(sel ? (isStart ? 0x002A0A : 0x0A1A2E) : 0x080810,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            // Row border
            dc.setColor(sel ? (isStart ? 0x44FF66 : 0x44CCFF) : 0x1A2A3A,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            // Cursor arrow
            if (sel) {
                dc.setColor(isStart ? 0x44FF66 : 0x44CCFF, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            // Row label
            dc.setColor(sel ? (isStart ? 0xAAFFBB : 0xFFFFFF) : 0x99AABB,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        rows[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Hint footer
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 14, Graphics.FONT_XTINY,
                    "UP/DN navigate  SEL act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _diffLabel(d) {
        if (d == DIFF_EASY) { return "EASY"; }
        if (d == DIFF_MED)  { return "MED";  }
        return "HARD";
    }

    // ── Board ────────────────────────────────────────────────────────
    function drawBoard(dc, ctrl) {
        dc.setColor(0x000000, 0x000000); dc.clear();

        var grid = ctrl.grid;
        var n    = grid.n;
        var box  = grid.box;
        layout(dc, n, ctrl.state);

        // ── Row / column highlight under the selected cell ───────────
        if (ctrl.state == GS_PLAY) {
            dc.setColor(0x101824, Graphics.COLOR_TRANSPARENT);
            // Full row
            dc.fillRectangle(boardX,
                             boardY + ctrl.curR * cellPx,
                             cellPx * n, cellPx);
            // Full column
            dc.fillRectangle(boardX + ctrl.curC * cellPx,
                             boardY,
                             cellPx, cellPx * n);
            // Box (the 2x2 / 3x3 containing the cursor)
            var br = (ctrl.curR / box) * box;
            var bc = (ctrl.curC / box) * box;
            dc.setColor(0x141C30, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(boardX + bc * cellPx, boardY + br * cellPx,
                             cellPx * box, cellPx * box);
        }

        // ── Selected cell background (drawn under digits) ────────────
        if (ctrl.state == GS_PLAY) {
            dc.setColor(0x2A2A12, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(boardX + ctrl.curC * cellPx,
                             boardY + ctrl.curR * cellPx,
                             cellPx, cellPx);
        }

        // ── Digits ───────────────────────────────────────────────────
        var font = _pickFont(cellPx);
        var textOff = (cellPx - 16) / 2;
        if (textOff < 0) { textOff = 0; }
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                var v = grid.getValue(r, c);
                if (v == 0) { continue; }
                var px = boardX + c * cellPx + cellPx / 2;
                var py = boardY + r * cellPx + (cellPx - _fontH(font)) / 2;
                var col = 0xFFFFFF;
                if      (grid.isError(r, c)) { col = 0xFF4444; }
                else if (grid.isFixed(r, c)) { col = 0xFFFFFF; }
                else                          { col = 0x44CCFF; }
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.drawText(px, py, font,
                            v.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // ── Grid lines (thin internal, thick box edges) ──────────────
        // Thin lines first
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i <= n; i++) {
            dc.drawLine(boardX,             boardY + i * cellPx,
                        boardX + n*cellPx,  boardY + i * cellPx);
            dc.drawLine(boardX + i * cellPx, boardY,
                        boardX + i * cellPx, boardY + n*cellPx);
        }
        // Thick lines on box boundaries
        dc.setColor(0x88BBDD, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i <= n; i += box) {
            var lx = boardX + i * cellPx;
            var ly = boardY + i * cellPx;
            // 2-pixel "thick" line
            dc.drawLine(boardX,             ly,                 boardX + n*cellPx, ly);
            dc.drawLine(boardX,             ly + 1,             boardX + n*cellPx, ly + 1);
            dc.drawLine(lx,                 boardY,             lx,                boardY + n*cellPx);
            dc.drawLine(lx + 1,             boardY,             lx + 1,            boardY + n*cellPx);
        }
    }

    // ── Top HUD: time + best ─────────────────────────────────────────
    function drawHUD(dc, ctrl) {
        var cx = dc.getWidth() / 2;
        var ty = dc.getHeight() * 3 / 100;
        if (ty < 4) { ty = 4; }
        // Time
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ty, Graphics.FONT_XTINY,
                    ctrl.fmtMs(ctrl.elapsedMs), Graphics.TEXT_JUSTIFY_CENTER);
        // Best (left)
        if (ctrl.bestMs > 0) {
            dc.setColor(0x66BBFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(6, ty, Graphics.FONT_XTINY,
                        "B " + ctrl.fmtMs(ctrl.bestMs),
                        Graphics.TEXT_JUSTIFY_LEFT);
        }
        // Mode/difficulty (right)
        dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
        var diff = (ctrl.diff == DIFF_EASY) ? "E"
                 : (ctrl.diff == DIFF_MED)  ? "M" : "H";
        var lbl = ((ctrl.mode == MODE_QUICK) ? "4x4" : "9x9") + " " + diff;
        dc.drawText(dc.getWidth() - 6, ty, Graphics.FONT_XTINY,
                    lbl, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ── Bottom hint bar ──────────────────────────────────────────────
    function drawFooter(dc, ctrl) {
        var cx = dc.getWidth() / 2;
        var fy = dc.getHeight() - 14;
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        var msg;
        if (ctrl.state == GS_PLAY) {
            msg = (ctrl.valMode == VAL_STRICT) ? "SEL cycle  BACK submit"
                                               : "SEL cycle  BACK menu";
        } else if (ctrl.state == GS_PAUSED) {
            msg = "Tap or any key to resume";
        } else {
            msg = "";
        }
        if (msg.length() > 0) {
            dc.drawText(cx, fy, Graphics.FONT_XTINY, msg,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Overlays ─────────────────────────────────────────────────────
    function drawPaused(dc) {
        var w = dc.getWidth(); var h = dc.getHeight();
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        // Semi-tint via a stripe band so the board partly shows through.
        var bh = h * 18 / 100;
        var by = (h - bh) / 2;
        dc.fillRectangle(0, by, w, bh);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(0, by, w, bh);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, by + bh / 2 - 8, Graphics.FONT_SMALL,
                    "PAUSED", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawComplete(dc, ctrl) {
        var w = dc.getWidth(); var h = dc.getHeight();
        var bw = w * 60 / 100; if (bw < 140) { bw = 140; }
        var bh = h * 32 / 100; if (bh < 96)  { bh = 96;  }
        var bx = (w - bw) / 2;
        var by = (h - bh) / 2;
        dc.setColor(0x041204, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);

        var cx = w / 2;
        dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    "SOLVED!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 28, Graphics.FONT_XTINY,
                    "Time " + ctrl.fmtMs(ctrl.lastTimeMs),
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (ctrl.bestMs > 0 && ctrl.lastTimeMs == ctrl.bestMs) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 44, Graphics.FONT_XTINY,
                        "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (ctrl.bestMs > 0) {
            dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 44, Graphics.FONT_XTINY,
                        "Best " + ctrl.fmtMs(ctrl.bestMs),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Any key for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawFailed(dc, ctrl) {
        var w = dc.getWidth(); var h = dc.getHeight();
        var bw = w * 60 / 100; if (bw < 140) { bw = 140; }
        var bh = h * 28 / 100; if (bh < 86)  { bh = 86;  }
        var bx = (w - bw) / 2;
        var by = (h - bh) / 2;
        dc.setColor(0x120404, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        var cx = w / 2;
        dc.setColor(0xFF6666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    "INVALID", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 30, Graphics.FONT_XTINY,
                    "Check conflicts", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Any key to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Font picker — smaller font for the dense 9x9 grid ────────────
    hidden function _pickFont(cell) {
        if (cell >= 26) { return Graphics.FONT_SMALL;  }
        if (cell >= 18) { return Graphics.FONT_XTINY;  }
        return Graphics.FONT_XTINY;
    }

    hidden function _fontH(f) {
        if (f == Graphics.FONT_SMALL) { return 18; }
        return 12;
    }

    // ── Tap helpers ──────────────────────────────────────────────────
    // Convert screen tap → (row, col) or [-1,-1] if outside the board.
    function tapToCell(tx, ty, n) {
        if (cellPx <= 0)               { return [-1, -1]; }
        if (tx < boardX || ty < boardY) { return [-1, -1]; }
        var dx = tx - boardX;
        var dy = ty - boardY;
        var c = dx / cellPx;
        var r = dy / cellPx;
        if (c < 0 || c >= n || r < 0 || r >= n) { return [-1, -1]; }
        return [r, c];
    }
}
