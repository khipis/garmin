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

    // Exit (✕) button hit-box, recomputed each frame in drawHUD.
    var exitX;
    var exitY;
    var exitR;

    function initialize() {
        sw = 0; sh = 0; cellPx = 0; boardX = 0; boardY = 0;
        exitX = 0; exitY = 0; exitR = 0;
    }

    // Compute layout for a given grid side n and the active state.
    // Grid is centred horizontally, biased a little upward so the
    // bottom area can host the HUD / number picker without clipping.
    function layout(dc, n, state) {
        sw = dc.getWidth();
        sh = dc.getHeight();
        var minDim = (sw < sh) ? sw : sh;
        // Reserve room above (HUD) and below (controls / time). The 9x9 grid
        // is dense, so give it a little more vertical room than the 4x4.
        var topPad = (n >= 9) ? (sh * 13 / 100) : (sh * 14 / 100);
        var botPad = (n >= 9) ? (sh * 15 / 100) : (sh * 16 / 100);
        var avail  = sh - topPad - botPad;
        // Keep the whole square inside the screen width — critical on round
        // watches so digit cells near the edges are never clipped.
        var widthCap = sw * 92 / 100;
        if (avail > widthCap) { avail = widthCap; }
        // Snap the board side to an exact multiple of n so every cell is the
        // same integer width and grid lines land on clean pixels.
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
        dc.drawText(cx, h * 10 / 100, Graphics.FONT_SMALL,
                    "SUDOKU", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 19 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rows = [
            "Mode: "   + ((ctrl.mode == MODE_QUICK)   ? "QUICK 4x4"     : "CLASSIC 9x9"),
            "Diff: "   + _diffLabel(ctrl.diff),
            "Errors: " + ((ctrl.valMode == VAL_RELAXED) ? "RELAX" : "STRICT"),
            "START"
        ];
        // Layout kept ~18% more compact (and space-aware) so all five rows
        // — including the LEADERBOARD badge — never overlap on round watches.
        var rowH = h * 8 / 100; if (rowH < 16) { rowH = 16; }
        var rowW = w * 70 / 100;
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

        // LEADERBOARD badge row (index 4) — drawn by the shared library.
        var lbY = startY + 4 * (rowH + gap);
        LbBadge.drawRow(dc, rowX, lbY, rowW, rowH, (ctrl.menuSel == 4));

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

        var bside = cellPx * n;

        // ── Highlights: peer row / column / box, then the selected cell ──
        if (ctrl.state == GS_PLAY) {
            // Peer row + column (soft blue so the eye instantly follows the
            // active line even on a busy 9x9 board).
            dc.setColor(0x16283C, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(boardX, boardY + ctrl.curR * cellPx, bside, cellPx);
            dc.fillRectangle(boardX + ctrl.curC * cellPx, boardY, cellPx, bside);
            // Box containing the cursor — a touch brighter than the lines.
            var br = (ctrl.curR / box) * box;
            var bc = (ctrl.curC / box) * box;
            dc.setColor(0x1E3350, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(boardX + bc * cellPx, boardY + br * cellPx,
                             cellPx * box, cellPx * box);
            // Selected cell — vivid gold fill so it's unmistakable.
            dc.setColor(0x5A4A00, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(boardX + ctrl.curC * cellPx,
                             boardY + ctrl.curR * cellPx,
                             cellPx, cellPx);
        }

        // ── Digits ───────────────────────────────────────────────────
        var font = _pickFont(dc, cellPx);
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                var v = grid.getValue(r, c);
                if (v == 0) { continue; }
                var px = boardX + c * cellPx + cellPx / 2;
                var py = boardY + r * cellPx + cellPx / 2;
                var col = 0xFFFFFF;
                if      (grid.isError(r, c)) { col = 0xFF4444; }
                else if (grid.isFixed(r, c)) { col = 0xFFFFFF; }
                else                          { col = 0x44CCFF; }
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.drawText(px, py, font, v.format("%d"),
                            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // ── Grid lines (thin internal, thick box edges) ──────────────
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i <= n; i++) {
            dc.drawLine(boardX,          boardY + i * cellPx,
                        boardX + bside,  boardY + i * cellPx);
            dc.drawLine(boardX + i * cellPx, boardY,
                        boardX + i * cellPx, boardY + bside);
        }
        // Thick lines on box boundaries
        dc.setColor(0x88BBDD, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i <= n; i += box) {
            var lx = boardX + i * cellPx;
            var ly = boardY + i * cellPx;
            dc.drawLine(boardX,     ly,     boardX + bside, ly);
            dc.drawLine(boardX,     ly + 1, boardX + bside, ly + 1);
            dc.drawLine(lx,         boardY, lx,             boardY + bside);
            dc.drawLine(lx + 1,     boardY, lx + 1,         boardY + bside);
        }

        // ── Selected-cell outline drawn LAST so it sits crisp on top ──
        if (ctrl.state == GS_PLAY) {
            var selX = boardX + ctrl.curC * cellPx;
            var selY = boardY + ctrl.curR * cellPx;
            dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(selX,     selY,     cellPx,     cellPx);
            dc.drawRectangle(selX + 1, selY + 1, cellPx - 2, cellPx - 2);
        }
    }

    // ── Top HUD: exit button + time + mode ───────────────────────────
    function drawHUD(dc, ctrl) {
        var w  = dc.getWidth();
        var cx = w / 2;
        var ty = dc.getHeight() * 3 / 100;
        if (ty < 4) { ty = 4; }

        // Vertical centre of the clock text — used to align the HUD row.
        var midY = ty + dc.getFontHeight(Graphics.FONT_XTINY) / 2;

        // Exit (✕) button — sits just LEFT of the clock, inside the round
        // safe zone so it's never clipped, giving touch-only watches a
        // clear, always-visible way out.
        if (ctrl.state == GS_PLAY || ctrl.state == GS_PAUSED) {
            exitR = 11;
            exitX = w * 30 / 100;
            exitY = midY;
            dc.setColor(0x2A1010, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(exitX, exitY, exitR);
            dc.setColor(0xFF6666, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(exitX, exitY, exitR);
            dc.drawCircle(exitX, exitY, exitR - 1);
            var d = exitR / 2;
            dc.drawLine(exitX - d, exitY - d, exitX + d, exitY + d);
            dc.drawLine(exitX - d, exitY + d, exitX + d, exitY - d);
        } else {
            exitR = 0;
        }

        // Time (centre). Mode/difficulty is intentionally NOT shown here —
        // the round safe zone is too narrow for ✕ + clock + mode without
        // crowding. It lives in the footer and on the results screen.
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ty, Graphics.FONT_XTINY,
                    ctrl.fmtMs(ctrl.elapsedMs), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Hit-test the exit (✕) button. Returns true if (x,y) lands on it.
    // The hit-box is deliberately generous (fat-finger friendly) and biased
    // downward so a tap that lands slightly below the small glyph still
    // counts — the whole top-left corner above the board is "exit".
    function tapInExit(x, y) {
        if (exitR <= 0) { return false; }
        // Everything in the top-left quadrant above the board and left of
        // the clock is treated as the exit zone.
        if (y <= boardY && x <= exitX + exitR + 14) { return true; }
        var dx = x - exitX;
        var dy = y - exitY;
        var pad = exitR + 16;
        return (dx > -pad && dx < pad && dy > -pad && dy < pad);
    }

    // ── Bottom hint bar ──────────────────────────────────────────────
    // Kept inside the round safe zone (centred, pulled up from the very
    // bottom) so text is never clipped by the display bezel.
    function drawFooter(dc, ctrl) {
        var w  = dc.getWidth();
        var cx = w / 2;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var fy = dc.getHeight() - dc.getHeight() * 8 / 100 - fh / 2;
        if (ctrl.state == GS_PLAY) {
            var hasBest = (ctrl.bestMs > 0);
            if (hasBest) {
                dc.setColor(0x66BBFF, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, fy - fh, Graphics.FONT_XTINY,
                            "Best " + ctrl.fmtMs(ctrl.bestMs),
                            Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            var msg = (ctrl.valMode == VAL_STRICT) ? "tap X to submit"
                                                   : "tap X to exit";
            // Fold mode+difficulty into the hint so it stays visible without
            // crowding the top HUD.
            if (!hasBest) {
                var diff = (ctrl.diff == DIFF_EASY) ? "E"
                         : (ctrl.diff == DIFF_MED)  ? "M" : "H";
                var mLbl = ((ctrl.mode == MODE_QUICK) ? "4x4" : "9x9") + " " + diff;
                dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, fy - fh, Graphics.FONT_XTINY, mLbl,
                            Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx, fy, Graphics.FONT_XTINY, msg,
                        Graphics.TEXT_JUSTIFY_CENTER);
        } else if (ctrl.state == GS_PAUSED) {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, fy, Graphics.FONT_XTINY,
                        "Tap or any key to resume", Graphics.TEXT_JUSTIFY_CENTER);
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
        var lines = [ ["Time " + ctrl.fmtMs(ctrl.lastTimeMs), 0xFFFFFF] ];
        if (ctrl.bestMs > 0 && ctrl.lastTimeMs == ctrl.bestMs) {
            lines.add(["NEW BEST!", 0xFFCC44]);
        } else if (ctrl.bestMs > 0) {
            lines.add(["Best " + ctrl.fmtMs(ctrl.bestMs), 0x88AABB]);
        }
        GameOverCard.draw(dc, dc.getWidth(), dc.getHeight(), "SOLVED!", 0x44FF66,
                          lines, "Any key for menu", 0x44FF66);
    }

    function drawFailed(dc, ctrl) {
        var lines = [ ["Check conflicts", 0xCCCCCC] ];
        GameOverCard.draw(dc, dc.getWidth(), dc.getHeight(), "INVALID", 0xFF6666,
                          lines, "Any key to retry", 0xFF4444);
    }

    // ── Font picker — largest built-in font whose digit fits the cell ──
    // Measures the real glyph box on this device (getFontHeight varies a
    // lot across watches) so digits never spill out of their cell.
    hidden function _pickFont(dc, cell) {
        var cands = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL,
                     Graphics.FONT_TINY,   Graphics.FONT_XTINY];
        var fit = cell - 3;   // leave a hair of padding on every side
        for (var i = 0; i < cands.size(); i++) {
            var f = cands[i];
            var h = dc.getFontHeight(f);
            var w = dc.getTextWidthInPixels("8", f);
            if (h <= fit && w <= fit) { return f; }
        }
        return Graphics.FONT_XTINY;   // smallest available fallback
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
