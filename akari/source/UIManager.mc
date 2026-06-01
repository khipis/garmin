// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Akari rendering.
//
// Screens:
//   drawMenu     chess-style menu + "by Bitochi" subtitle
//   drawPlay     HUD + grid + footer
//   drawWin      solved splash
//
// Cells:
//   White lit       cream-yellow background
//   White dark      cream/grey "off" background
//   Bulb            yellow bulb-glyph (red glyph if error)
//   X mark          small red ×
//   Wall (no num)   solid black
//   Wall (num k)    solid black with white digit centred
//                   (red digit if the number is currently exceeded)
//   Cursor          2-pixel yellow frame, drawn on top of any state
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;

class UIManager {

    hidden static var _bx;
    hidden static var _by;
    hidden static var _bcell;
    hidden static var _bn;

    // ── Menu ────────────────────────────────────────────────────
    // Menu dimensions scaled down by 5% from the original 9%/70%
    // layout — keeps the rows compact on small watch faces while
    // leaving more breathing room around the chess-style stack.
    static function rowGeom(sw, sh) {
        var rowH = (sh *  855) / 10000; if (rowH < 16) { rowH = 16; }  // 9% × 0.95
        var gap  = (sh *  1) / 100;     if (gap  <  2) { gap  =  2; }
        var rowW = (sw * 665) / 1000;   if (rowW < 130) { rowW = 130; } // 70% × 0.95
        var rowX = (sw - rowW) / 2;
        var rowY0 = (sh * 38) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x10080A, 0x10080A); dc.clear();
        if (sw == sh) {
            dc.setColor(0x1A1015, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 5 / 100, Graphics.FONT_MEDIUM,
                    "AKARI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFEE88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 18 / 100, Graphics.FONT_XTINY,
                    "Light Up", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFE699, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 28 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];

        var levelLabel;
        if (ctrl.mode == AK_MODE_DAILY) {
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
        for (var i = 0; i < AK_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == AK_MENU_ROWS - 1);
            dc.setColor(sel ? (isStart ? 0x332200 : 0x1F1A10) : 0x100A0A,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFCC22 : 0xFFEE88) : 0x443322,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xFFEE88 : 0xFFEECC) : 0x99887B,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        var sub;
        if (ctrl.mode == AK_MODE_DAILY) {
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
        dc.setColor(0x10080A, 0x10080A); dc.clear();
        if (sw == sh) {
            dc.setColor(0x1A1015, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sw / 2, sh / 2, sw / 2 - 1);
        }
        _drawHUD(dc, sw, sh, ctrl);
        _layoutAndDrawBoard(dc, sw, sh, ctrl);
        _drawFooter(dc, sw, sh);
    }

    hidden static function _drawHUD(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        var slotLabel;
        if (ctrl.mode == AK_MODE_DAILY) {
            slotLabel = "DAILY";
        } else {
            slotLabel = "P " + (ctrl.slot + 1).format("%d");
        }
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
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

        var topPad = (sh * 13) / 100;
        var botPad = (sh *  9) / 100;
        var inset  = (sw == sh) ? ((sw * 4) / 100) : 3;
        var availW = sw - inset * 2;
        var availH = sh - topPad - botPad;
        // Compute the natural cell size that would fully fill the
        // available area, then shrink the board by 10% so the grid
        // sits more comfortably inside the round bezel.
        var cell   = (availW < availH ? availW : availH) / n;
        cell = (cell * 9) / 10;
        if (cell < 10) { cell = 10; }
        var boardSize = cell * n;
        _bx    = (sw - boardSize) / 2;
        _by    = topPad + (availH - boardSize) / 2;
        _bcell = cell;
        _bn    = n;

        // Outer board frame.
        dc.setColor(0x665533, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_bx - 1, _by - 1, boardSize + 2, boardSize + 2);

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
        var v  = ctrl.grid.cells[ctrl.grid.idx(r, c)];

        if (v == 0) {
            _drawWhiteCell(dc, ctrl, r, c, x, y, s);
        } else {
            _drawWallCell(dc, ctrl, r, c, x, y, s, v);
        }

        if (ctrl.curR == r && ctrl.curC == c) {
            // High-contrast cursor: dark outer ring + saturated red-
            // orange band.  The previous light-yellow frame blended
            // into the warm-cream lit-cell background; this version
            // pops against BOTH light (white/lit) and dark (wall)
            // cells because the dark ring guarantees edge contrast
            // and the bright band guarantees fill contrast.
            dc.setColor(0x331100, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x,     y,     s,     s);
            dc.drawRectangle(x + 3, y + 3, s - 6, s - 6);
            dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x + 1, y + 1, s - 2, s - 2);
            dc.drawRectangle(x + 2, y + 2, s - 4, s - 4);
        }
    }

    hidden static function _drawWhiteCell(dc, ctrl, r, c, x, y, s) {
        var i  = ctrl.grid.idx(r, c);
        var mk = ctrl.grid.marks[i];
        var lit = (ctrl.lit.size() > 0) ? ctrl.lit[i] : 0;

        // Background: lit = warm cream, dark = pale grey.
        if (lit != 0) {
            dc.setColor(0xFFF1A0, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0xF8F4E6, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRectangle(x, y, s, s);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, s, s);

        if (mk == AK_BULB) {
            var err = ctrl.showErrs
                      && ValidationEngine.bulbError(ctrl.grid, r, c);
            _drawBulb(dc, x, y, s, err);
        } else if (mk == AK_X) {
            _drawX(dc, x, y, s);
        }
    }

    hidden static function _drawBulb(dc, x, y, s, err) {
        var cx = x + s / 2;
        var cy = y + s / 2;
        var r  = (s * 7) / 20;        // bulb radius
        if (r < 3) { r = 3; }

        var glyphCol = err ? 0xCC2233 : 0x111111;
        var bodyCol  = err ? 0xFFCCCC : 0xFFEE99;

        // Bulb body (filled).
        dc.setColor(bodyCol, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - 1, r);

        // Bulb body outline.
        dc.setColor(glyphCol, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy - 1, r);

        // Screw base — small rectangle below the bulb.
        var bw = (r * 3) / 2;
        var bh = (r * 2) / 3;
        if (bw < 3) { bw = 3; }
        if (bh < 2) { bh = 2; }
        dc.fillRectangle(cx - bw / 2, cy + r - 1, bw, bh);
    }

    hidden static function _drawX(dc, x, y, s) {
        dc.setColor(0xCC2233, Graphics.COLOR_TRANSPARENT);
        var pad = s / 4;
        dc.drawLine(x + pad,     y + pad,     x + s - pad, y + s - pad);
        dc.drawLine(x + s - pad, y + pad,     x + pad,     y + s - pad);
        dc.drawLine(x + pad + 1, y + pad,     x + s - pad, y + s - pad - 1);
        dc.drawLine(x + s - pad - 1, y + pad, x + pad,     y + s - pad - 1);
    }

    hidden static function _drawWallCell(dc, ctrl, r, c, x, y, s, v) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, s, s);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, s, s);
        if (v >= 2) {
            var n = v - 2;
            var err = ctrl.showErrs
                      && ValidationEngine.wallError(ctrl.grid, r, c);
            dc.setColor(err ? 0xFF4455 : 0xFFFFFF,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + s / 2, y + (s - 14) / 2, Graphics.FONT_XTINY,
                        n.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
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
        dc.setColor(0x1A0E18, 0x1A0E18); dc.clear();
        if (sw == sh) {
            dc.setColor(0x2A1830, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  8 / 100, Graphics.FONT_MEDIUM,
                    "SOLVED!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 24 / 100, Graphics.FONT_SMALL,
                    _mmss(ctrl.elapsed), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        var line;
        if (ctrl.mode == AK_MODE_DAILY) {
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

        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        var hint = (ctrl.mode == AK_MODE_LEVELS)
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
