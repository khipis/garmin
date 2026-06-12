// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Rendering for Nonogram.
//
// Layout (PLAY):
//
//   ┌───────────────────────────────────┐
//   │      Slot N · time mm:ss          │  HUD (top ~10%)
//   ├─────┬─────────────────────────────┤
//   │     │         column clues        │  clue strip
//   │ row │  ┌─────┬─────┬─────┐        │
//   │     │  │     │     │     │  GRID  │
//   │     │  │     │     │     │        │
//   │     │  └─────┴─────┴─────┘        │
//   └─────┴─────────────────────────────┘
//
// Both clue strips are anchored to the grid so a 5×5 and a 6×6 use
// the same geometry routine.  Cell pixels are sized so the entire
// playable area fits inside the watch's circular face (with a small
// inset to avoid bezel clipping).
//
// Cells:
//   EMPTY → grey hollow tile
//   FILL  → solid amber pixel (with optional red error-overlay)
//   X     → grey hollow tile with a thin × glyph
//   CURSOR overlays a yellow 2-pixel frame over any state.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;

class UIManager {

    hidden static var _bx;       // grid origin x
    hidden static var _by;       // grid origin y
    hidden static var _bcell;    // cell pixels
    hidden static var _bn;       // grid edge
    hidden static var _stripL;   // row-clue strip width
    hidden static var _stripT;   // col-clue strip height

    // ── Menu ────────────────────────────────────────────────────
    static function rowGeom(sw, sh) {
        var rowH = (sh *  8) / 100; if (rowH < 14) { rowH = 14; }
        var gap  = (sh *  1) / 100; if (gap  <  2) { gap  =  2; }
        var rowW = (sw * 63) / 100; if (rowW < 117) { rowW = 117; }
        var rowX = (sw - rowW) / 2;
        // Start higher so all five rows (incl. the LEADERBOARD badge) fit.
        var rowY0 = (sh * 32) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x05080F, 0x05080F); dc.clear();
        if (sw == sh) {
            dc.setColor(0x0A1422, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 10 / 100, Graphics.FONT_MEDIUM,
                    "NONOGRAM", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 25 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];

        var levelLabel;
        if (ctrl.mode == NG_MODE_DAILY) {
            levelLabel = "DAILY";
        } else {
            levelLabel = "P " + (ctrl.slot + 1).format("%d")
                       + "/" + ctrl.totalSlots().format("%d");
        }
        var labels = [
            "Diff: " + ctrl.difficultyName(),
            "Mode: " + ctrl.modeName(),
            ctrl.errsName(),
            "START " + levelLabel
        ];
        for (var i = 0; i < NG_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == NG_MENU_ROWS - 1);
            dc.setColor(sel ? (isStart ? 0x002A38 : 0x142030) : 0x0A1422,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x44CCFF : 0x66DDFF) : 0x223344,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0x44CCFF : 0xCCEEFF) : 0x99AABB,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // LEADERBOARD badge row (index NG_LB_ROW) — drawn by the shared lib.
        var lbY = rowY0 + NG_LB_ROW * (rowH + gap);
        LbBadge.drawRow(dc, rowX, lbY, rowW, rowH, (ctrl.menuRow == NG_LB_ROW));

        // Footer.
        var sub;
        if (ctrl.mode == NG_MODE_DAILY) {
            sub = ctrl.dailyDoneToday
                ? ("Daily done · streak " + ctrl.streak.format("%d"))
                : ("Daily · streak " + ctrl.streak.format("%d"));
        } else {
            var b = ctrl.bestForCurrent();
            sub = (b >= 0) ? ("Best " + _mmss(b)) :
                  ("Solved " + ctrl.solvedTotal.format("%d"));
        }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    sub, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Play ────────────────────────────────────────────────────
    static function drawPlay(dc, sw, sh, ctrl) {
        dc.setColor(0x05080F, 0x05080F); dc.clear();
        if (sw == sh) {
            dc.setColor(0x0A1422, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sw / 2, sh / 2, sw / 2 - 1);
        }
        _drawHUD(dc, sw, sh, ctrl);
        _layoutAndDrawBoard(dc, sw, sh, ctrl);
        _drawFooter(dc, sw, sh);
    }

    hidden static function _drawHUD(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        var slotLabel;
        if (ctrl.mode == NG_MODE_DAILY) {
            slotLabel = "DAILY";
        } else {
            slotLabel = "P " + (ctrl.slot + 1).format("%d");
        }
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - sw / 4, sh * 7 / 100, Graphics.FONT_XTINY,
                    slotLabel, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + sw / 4, sh * 7 / 100, Graphics.FONT_XTINY,
                    _mmss(ctrl.elapsed), Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _drawFooter(dc, sw, sh) {
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, sh - 14, Graphics.FONT_XTINY,
                    "SEL cycle  hold X  ESC menu",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _layoutAndDrawBoard(dc, sw, sh, ctrl) {
        var n = ctrl.grid.n;

        // Reserve ~14% top for HUD, ~9% bottom for footer.
        var topPad = (sh * 14) / 100;
        var botPad = (sh *  9) / 100;
        var inset  = (sw == sh) ? ((sw * 5) / 100) : 4;
        var availW = sw - inset * 2;
        var availH = sh - topPad - botPad;

        // Clue strips: row strip ~22% of available width, col strip
        // ~22% of available height — tuned by hand.
        _stripL = availW * 22 / 100;
        _stripT = availH * 22 / 100;

        var gridW = availW - _stripL;
        var gridH = availH - _stripT;
        var cell  = (gridW < gridH ? gridW : gridH) / n;
        if (cell < 10) { cell = 10; }
        var boardSize = cell * n;

        // Center the full assembly within the available rectangle.
        var totalW = _stripL + boardSize;
        var totalH = _stripT + boardSize;
        var ox = inset + (availW - totalW) / 2;
        var oy = topPad + (availH - totalH) / 2;

        _bx    = ox + _stripL;
        _by    = oy + _stripT;
        _bcell = cell;
        _bn    = n;

        _drawColClues(dc, ctrl, oy);
        _drawRowClues(dc, ctrl, ox);
        _drawCells(dc, ctrl);
    }

    hidden static function _drawColClues(dc, ctrl, stripTopY) {
        var n = ctrl.grid.n;
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        for (var c = 0; c < n; c++) {
            var cnt = ctrl.grid.colClueCount(c);
            var x   = _bx + c * _bcell + _bcell / 2;
            // Bottom-align the clue stack to the grid top edge.
            var baseY = _by - 12;
            for (var k = cnt - 1; k >= 0; k--) {
                var v  = ctrl.grid.colClueAt(c, k);
                var ix = cnt - 1 - k;
                dc.drawText(x, baseY - ix * 11, Graphics.FONT_XTINY,
                            (v == 0 ? "0" : v.format("%d")),
                            Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden static function _drawRowClues(dc, ctrl, stripLeftX) {
        var n = ctrl.grid.n;
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        for (var r = 0; r < n; r++) {
            var cnt = ctrl.grid.rowClueCount(r);
            var y   = _by + r * _bcell + (_bcell - 12) / 2;
            // Right-align the clue list against the grid left edge.
            var baseX = _bx - 6;
            for (var k = cnt - 1; k >= 0; k--) {
                var v  = ctrl.grid.rowClueAt(r, k);
                var ix = cnt - 1 - k;
                dc.drawText(baseX - ix * 12, y, Graphics.FONT_XTINY,
                            (v == 0 ? "0" : v.format("%d")),
                            Graphics.TEXT_JUSTIFY_RIGHT);
            }
        }
    }

    hidden static function _drawCells(dc, ctrl) {
        var n = ctrl.grid.n;
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                _drawCell(dc, ctrl, r, c);
            }
        }
    }

    hidden static function _drawCell(dc, ctrl, r, c) {
        var x  = _bx + c * _bcell;
        var y  = _by + r * _bcell;
        var s  = _bcell;
        var v  = ctrl.grid.getCell(r, c);

        // Background.
        dc.setColor(0x12202E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, s, s);
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, s, s);

        // Slight every-5th separator (helps eye on 6×6).
        if (((r + 1) % 5) == 0 || ((c + 1) % 5) == 0) {
            // intentionally subtle; left blank for small grids
        }

        if (v == NG_FILL) {
            var isErr = ctrl.showErrs
                        && ValidationEngine.isCellError(ctrl.grid, r, c);
            if (isErr) {
                dc.setColor(0xCC2233, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            }
            dc.fillRectangle(x + 2, y + 2, s - 4, s - 4);
        } else if (v == NG_X) {
            dc.setColor(0x99AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x + 4, y + 4, x + s - 4, y + s - 4);
            dc.drawLine(x + s - 4, y + 4, x + 4, y + s - 4);
        }

        if (ctrl.curR == r && ctrl.curC == c) {
            dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
            for (var t = 0; t < 2; t++) {
                dc.drawRectangle(x + t, y + t, s - 2 * t, s - 2 * t);
            }
        }
    }

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

    // ── Win ────────────────────────────────────────────────────
    static function drawWin(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x021018, 0x021018); dc.clear();
        if (sw == sh) {
            dc.setColor(0x062236, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  8 / 100, Graphics.FONT_MEDIUM,
                    "SOLVED!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 24 / 100, Graphics.FONT_SMALL,
                    _mmss(ctrl.elapsed), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        var line;
        if (ctrl.mode == NG_MODE_DAILY) {
            line = "Daily streak " + ctrl.streak.format("%d");
        } else {
            var b = ctrl.bestForCurrent();
            line = (b >= 0) ? ("Best " + _mmss(b)) : "First solve!";
        }
        dc.drawText(cx, sh * 38 / 100, Graphics.FONT_XTINY,
                    line, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 50 / 100, Graphics.FONT_XTINY,
                    "Solved " + ctrl.solvedTotal.format("%d") + " total",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        var hint = (ctrl.mode == NG_MODE_LEVELS)
                 ? "tap/SEL = next  ESC = menu"
                 : "tap/SEL = menu";
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _mmss(secs) {
        var m = secs / 60;
        var s = secs % 60;
        return m.format("%d") + ":" + s.format("%02d");
    }
}
