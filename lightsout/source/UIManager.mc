// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Rendering for LightsOut.
//
// Sections:
//   drawMenu      — chess-style 3-row menu + Bitochi subtitle
//   drawPlay      — HUD + light-bulb grid + footer
//   drawWin       — solved screen w/ best & solved counts
//   rowGeom       — chess-menu hit geometry (shared with View)
//   tapToCell     — board hit-test
//
// Bulbs:
//   ON:   filled warm-amber circle with glow, white highlight dot
//   OFF:  thin grey ring, dim center
//   Selected: yellow square frame around the bulb
//   Hint:  pulsing cyan ring (drawn when the user taps "hint")
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;

class UIManager {

    hidden static var _bx;
    hidden static var _by;
    hidden static var _bcell;
    hidden static var _bn;

    // ── Menu ────────────────────────────────────────────────────
    static function rowGeom(sw, sh) {
        // Space-aware: fit LO_MENU_ROWS rows between the title block and the
        // footer, vertically centered. Rows are capped ~18% smaller than the
        // legacy 3-row height so the extra LEADERBOARD row never overlaps the
        // title/footer on round watches.
        var rows = LO_MENU_ROWS;
        var top  = (sh * 33) / 100;          // just below the "by Bitochi" line
        var bot  = sh - (sh * 8) / 100;       // just above the footer
        var avail = bot - top;
        var gap   = (sh * 2) / 100; if (gap < 3) { gap = 3; }

        var cap = ((sh * 11) / 100) * 82 / 100;   // ~18% smaller than before
        var rowH = (avail - gap * (rows - 1)) / rows;
        if (rowH > cap) { rowH = cap; }
        if (rowH < 16) { rowH = 16; }

        var rowW = (sw * 68) / 100; if (rowW < 130) { rowW = 130; }
        var rowX = (sw - rowW) / 2;

        var totalH = rowH * rows + gap * (rows - 1);
        var rowY0  = top + (avail - totalH) / 2;
        if (rowY0 < top) { rowY0 = top; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x000308, 0x000308); dc.clear();
        if (sw == sh) {
            dc.setColor(0x081020, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        // Title — two-line stack + Bitochi subtitle.
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  4 / 100, Graphics.FONT_MEDIUM,
                    "LIGHTS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 16 / 100, Graphics.FONT_SMALL,
                    "OUT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFE699, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 28 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];

        var levelLabel;
        if (ctrl.mode == LO_MODE_DAILY) {
            levelLabel = "DAILY";
        } else {
            levelLabel = "Lvl " + ctrl.level.format("%d")
                       + "/" + LO_TOTAL_LEVELS.format("%d");
        }
        var labels = [
            "Diff:  " + ctrl.difficultyName(),
            "Mode:  " + ctrl.modeName(),
            "START  " + levelLabel
        ];
        for (var i = 0; i < LO_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            if (i == LO_ROW_LEADERBOARD) {
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }
            var isStart = (i == LO_ROW_START);
            dc.setColor(sel ? (isStart ? 0x223300 : 0x182030) : 0x0A1018,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0xFFCC22) : 0x223344,
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

        // Footer — best-of-level or daily streak summary.
        var sub;
        if (ctrl.mode == LO_MODE_DAILY) {
            if (ctrl.dailyDoneToday) {
                sub = "Daily done · streak " + ctrl.streak.format("%d");
            } else {
                var bd = ctrl.dailyBestMoves;
                sub = (bd >= 0) ? ("Daily best " + bd.format("%d") + " mv")
                                : "Daily · streak " + ctrl.streak.format("%d");
            }
        } else {
            var b = ctrl.bestForLevel(ctrl.level);
            sub = (b >= 0) ? ("Lvl best " + b.format("%d") + " mv")
                           : ("Solved " + ctrl.solvedTotal.format("%d"));
        }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    sub, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Play ────────────────────────────────────────────────────
    static function drawPlay(dc, sw, sh, ctrl) {
        dc.setColor(0x000308, 0x000308); dc.clear();
        if (sw == sh) {
            dc.setColor(0x081020, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sw / 2, sh / 2, sw / 2 - 1);
        }
        _drawHUD(dc, sw, sh, ctrl);
        _drawBoard(dc, sw, sh, ctrl);
        _drawFooter(dc, sw, sh);
    }

    hidden static function _drawHUD(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        var label;
        if (ctrl.mode == LO_MODE_DAILY) {
            label = "DAILY";
        } else {
            label = "Lvl " + ctrl.level.format("%d");
        }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - sw / 4, sh * 11 / 100, Graphics.FONT_XTINY,
                    label, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + sw / 4, sh * 11 / 100, Graphics.FONT_XTINY,
                    "mv " + ctrl.moves.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 21 / 100, Graphics.FONT_XTINY,
                    "ON " + ctrl.grid.onCount().format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _drawFooter(dc, sw, sh) {
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN move  SEL toggle  hold restart",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _drawBoard(dc, sw, sh, ctrl) {
        var n = ctrl.grid.n;
        // Reserve top 26%, bottom 9%.
        var topPad = (sh * 26) / 100;
        var botPad = (sh *  9) / 100;
        var inset  = (sw == sh) ? ((sw * 6) / 100) : 4;
        var maxW   = sw - inset * 2;
        var maxH   = sh - topPad - botPad;
        var cell   = (maxW < maxH ? maxW : maxH) / n;
        if (cell < 10) { cell = 10; }
        var boardSize = cell * n;
        _bx    = (sw - boardSize) / 2;
        _by    = topPad + (maxH - boardSize) / 2;
        _bcell = cell;
        _bn    = n;

        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                _drawBulb(dc, r, c, ctrl);
            }
        }

        // Hint highlight: subtle cyan ring on the next-to-press cell
        // (we don't always draw it — it's drawn only when the user
        // explicitly asks for a hint, which sets ctrl.hintIndex < solvePresses.size).
        // We expose it via the helper drawHintRing() instead — left
        // unused here to keep the UI minimal.
    }

    hidden static function _drawBulb(dc, r, c, ctrl) {
        var x  = _bx + c * _bcell;
        var y  = _by + r * _bcell;
        var s  = _bcell;
        var on = ctrl.grid.isOn(r, c);

        // Tile background (dim) — distinguishes the playable area
        // from the watch-face surround.
        dc.setColor(0x10202E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, s, s);
        dc.setColor(0x1F3144, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, s, s);

        var cx = x + s / 2;
        var cy = y + s / 2;
        var rOuter = s / 2 - 3;
        if (rOuter < 4) { rOuter = 4; }

        if (on) {
            // Glow halo.
            dc.setColor(0x3A2A06, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, rOuter + 1);
            // Bulb body.
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, rOuter - 1);
            // Highlight.
            dc.setColor(0xFFFFEE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - rOuter / 3, cy - rOuter / 3, rOuter / 4);
        } else {
            // Empty ring.
            dc.setColor(0x33455A, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, rOuter - 1);
            dc.setColor(0x1A2A3A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, rOuter - 3);
        }

        // Cursor frame.
        if (ctrl.curR == r && ctrl.curC == c) {
            dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
            for (var t = 0; t < 2; t++) {
                dc.drawRectangle(x + t, y + t, s - 2 * t, s - 2 * t);
            }
        }
    }

    static function getBoardGeom() { return [_bx, _by, _bcell, _bn]; }

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

    // ── Win ─────────────────────────────────────────────────────
    static function drawWin(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x021020, 0x021020); dc.clear();
        if (sw == sh) {
            dc.setColor(0x0A2236, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  8 / 100, Graphics.FONT_MEDIUM,
                    "SOLVED!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFE699, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 24 / 100, Graphics.FONT_SMALL,
                    "Moves " + ctrl.moves.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        var line;
        if (ctrl.mode == LO_MODE_DAILY) {
            line = "Daily streak " + ctrl.streak.format("%d");
        } else {
            var b = ctrl.bestForLevel(ctrl.level);
            line = (b >= 0) ? ("Best " + b.format("%d") + " mv")
                            : "First solve!";
        }
        dc.drawText(cx, sh * 38 / 100, Graphics.FONT_XTINY,
                    line, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 50 / 100, Graphics.FONT_XTINY,
                    "Solved " + ctrl.solvedTotal.format("%d") + " total",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        var hint;
        if (ctrl.mode == LO_MODE_LEVELS && ctrl.level < LO_TOTAL_LEVELS) {
            hint = "tap/SEL = next level";
        } else {
            hint = "tap/SEL = menu";
        }
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
