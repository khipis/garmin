// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Rendering for Kakuro.
//
// Sections:
//   drawMenu        — chess-style 3-row menu w/ Bitochi
//   drawPlay        — top HUD + board + footer
//   drawBoard       — black/white grid with clue cells split by diag
//   drawWin         — final result screen
//   rowGeom         — menu row geometry (shared with hit-test)
//   tapToCell       — convert tap → (r,c) cell index
//
// The clue cell is split by a diagonal line.  Top-right corner
// shows the vertical sum (clue going DOWN); bottom-left corner
// shows the horizontal sum (clue going RIGHT).  This matches the
// universally recognised Kakuro convention.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;

class UIManager {

    // Cached board geometry (set by drawBoard before drawing).
    hidden static var _bx;
    hidden static var _by;
    hidden static var _bcell;
    hidden static var _bn;

    // ── Menu ────────────────────────────────────────────────────
    static function rowGeom(sw, sh) {
        var rowH = (sh * 11) / 100; if (rowH < 18) { rowH = 18; }
        var gap  = (sh *  2) / 100; if (gap  <  3) { gap  =  3; }
        var rowW = (sw * 68) / 100; if (rowW < 130) { rowW = 130; }
        var rowX = (sw - rowW) / 2;
        var rowY0 = (sh * 40) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x000308, 0x000308); dc.clear();
        if (sw == sh) {
            dc.setColor(0x06121E, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        // Title — two-line stack + Bitochi subtitle.
        dc.setColor(0xFFCC55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  4 / 100, Graphics.FONT_MEDIUM,
                    "KAKURO", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 18 / 100, Graphics.FONT_SMALL,
                    "SUMS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFE699, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 30 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];

        var labels = [
            "Diff:  " + ctrl.difficultyName(),
            "Mode:  " + ctrl.modeName(),
            "START"
        ];
        for (var i = 0; i < KK_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == KK_MENU_ROWS - 1);
            dc.setColor(sel ? (isStart ? 0x223300 : 0x101830) : 0x0A1018,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0xFFCC55) : 0x223344,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0xFFE699) : 0x99AABB,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Footer: best time, streak, lock for daily.
        var sub;
        if (ctrl.mode == KK_MODE_DAILY) {
            if (ctrl.dailyDoneToday) {
                sub = "Daily done · streak " + ctrl.streak.format("%d");
            } else {
                sub = "Daily · best " + ctrl.fmtMs(ctrl.bestDailyMs);
            }
        } else {
            sub = "Best " + ctrl.fmtMs(ctrl.bestForCurrent())
                + " · solved " + ctrl.solvedTotal.format("%d");
        }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    sub, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Play ────────────────────────────────────────────────────
    static function drawPlay(dc, sw, sh, ctrl) {
        dc.setColor(0x000308, 0x000308); dc.clear();
        if (sw == sh) {
            dc.setColor(0x06121E, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sw / 2, sh / 2, sw / 2 - 1);
        }
        _drawHUD(dc, sw, sh, ctrl);
        drawBoard(dc, sw, sh, ctrl);
        _drawFooter(dc, sw, sh);
    }

    hidden static function _drawHUD(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - sw / 4, sh * 6 / 100, Graphics.FONT_XTINY,
                    ctrl.difficultyName(),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + sw / 4, sh * 6 / 100, Graphics.FONT_XTINY,
                    ctrl.fmtMs(ctrl.elapsedMs),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _drawFooter(dc, sw, sh) {
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN digit  SEL next  swipe move",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Cache board layout so MainView.handleTap can reuse it.
    static function getBoardGeom() {
        return [_bx, _by, _bcell, _bn];
    }

    static function drawBoard(dc, sw, sh, ctrl) {
        var n = ctrl.grid.n;
        // Reserve top 14%, bottom 9% for HUD/footer.
        var topPad = (sh * 14) / 100; if (topPad < 22) { topPad = 22; }
        var botPad = (sh *  9) / 100; if (botPad < 18) { botPad = 18; }
        var inset  = (sw == sh) ? ((sw * 6) / 100) : 4;
        var maxW   = sw - inset * 2;
        var maxH   = sh - topPad - botPad;
        var cell   = (maxW < maxH ? maxW : maxH) / n;
        if (cell < 8) { cell = 8; }
        var boardSize = cell * n;
        _bx    = (sw - boardSize) / 2;
        _by    = topPad + (maxH - boardSize) / 2;
        _bcell = cell;
        _bn    = n;

        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                _drawCell(dc, r, c, ctrl);
            }
        }
        // Selected-cell outline (drawn on top of grid lines).
        if (ctrl.grid.isWhite(ctrl.curR, ctrl.curC)) {
            var cx = _bx + ctrl.curC * cell;
            var cy = _by + ctrl.curR * cell;
            dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
            for (var t = 0; t < 2; t++) {
                dc.drawRectangle(cx + t, cy + t, cell - 2 * t, cell - 2 * t);
            }
        }
    }

    hidden static function _drawCell(dc, r, c, ctrl) {
        var grid  = ctrl.grid;
        var n     = grid.n;
        var x     = _bx + c * _bcell;
        var y     = _by + r * _bcell;
        var ci    = r * n + c;

        if (grid.white[ci] == 0) {
            _drawBlackCell(dc, x, y, _bcell, grid.hSum[ci], grid.vSum[ci]);
        } else {
            _drawWhiteCell(dc, x, y, _bcell,
                           grid.val[ci],
                           ctrl.err[ci] != 0);
        }
    }

    hidden static function _drawBlackCell(dc, x, y, s, hSum, vSum) {
        dc.setColor(0x101820, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, s, s);
        // Diagonal split only when this cell carries at least one clue.
        if (hSum > 0 || vSum > 0) {
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x, y, x + s, y + s);
        }
        // Vertical clue → top-right
        if (vSum > 0) {
            dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + s - 2, y - 2, Graphics.FONT_XTINY,
                        vSum.format("%d"), Graphics.TEXT_JUSTIFY_RIGHT);
        }
        // Horizontal clue → bottom-left
        if (hSum > 0) {
            dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + 1, y + s - 14, Graphics.FONT_XTINY,
                        hSum.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        }
        // Border.
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, s, s);
    }

    hidden static function _drawWhiteCell(dc, x, y, s, val, isErr) {
        dc.setColor(0xF0F0F0, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, s, s);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, s, s);
        if (val > 0) {
            var color = isErr ? 0xCC2222 : 0x111111;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            // Center digit using FONT_TINY (or SMALL if cell large).
            var f = (s >= 24) ? Graphics.FONT_SMALL : Graphics.FONT_TINY;
            var fh = (s >= 24) ? 18 : 14;
            dc.drawText(x + s / 2, y + (s - fh) / 2,
                        f, val.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Tap → cell coordinates (-1,-1 if outside the board).
    static function tapToCell(x, y) {
        if (_bcell <= 0) { return [-1, -1]; }
        var lx = x - _bx;
        var ly = y - _by;
        if (lx < 0 || ly < 0) { return [-1, -1]; }
        var c = lx / _bcell;
        var r = ly / _bcell;
        if (r < 0 || c < 0 || r >= _bn || c >= _bn) { return [-1, -1]; }
        return [r, c];
    }

    // ── Win screen ──────────────────────────────────────────────
    static function drawWin(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x041018, 0x041018); dc.clear();
        if (sw == sh) {
            dc.setColor(0x0A1830, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        dc.setColor(0xFFCC55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  8 / 100, Graphics.FONT_MEDIUM,
                    "SOLVED!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 26 / 100, Graphics.FONT_SMALL,
                    "Time " + ctrl.fmtMs(ctrl.lastTimeMs),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        var b = "Best " + ctrl.fmtMs(ctrl.bestForCurrent());
        if (ctrl.mode == KK_MODE_DAILY) {
            b = b + "  Streak " + ctrl.streak.format("%d");
        }
        dc.drawText(cx, sh * 42 / 100, Graphics.FONT_XTINY,
                    b, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 56 / 100, Graphics.FONT_XTINY,
                    "Solved " + ctrl.solvedTotal.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFE699, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "tap/SEL = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
