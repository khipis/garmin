// ═══════════════════════════════════════════════════════════════
// UIManager.mc — All rendering for DiceRoyale.
//
// Sections:
//   • drawMenu           — chess-style 3-row menu w/ Bitochi
//   • drawPlay           — top HUD, dice strip, ROLL / SCORE buttons
//   • drawScoreScreen    — 13-row scoring picker (preview per row)
//   • drawOver           — final scoreboard
//   • rowGeom            — shared chess-menu geometry
//
// All static so the controller stays pure.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;

class UIManager {

    // ── Chess-style menu geometry (shared with hit-test) ────────
    //
    // Space-aware: with the 4th LEADERBOARD row the whole menu is
    // ~18% smaller (height / width / gaps) than before, and the rows
    // are fitted into the band between the title block and the bottom
    // subtitle so nothing overlaps on small round watches.
    static function rowGeom(sw, sh) {
        var topZone      = (sh * 36) / 100;                 // rows start below "by Bitochi"
        var bottomMargin = (sh * 11) / 100; if (bottomMargin < 22) { bottomMargin = 22; } // leave room for subtitle
        var gap          = (sh *  2) / 100; if (gap < 3) { gap = 3; }
        var avail        = (sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (DR_MENU_ROWS - 1)) / DR_MENU_ROWS;
        // Cap ~10% smaller again so all four rows stay compact.
        if (rowH > 20) { rowH = 20; }
        if (rowH < 13) { rowH = 13; }
        var rowW = (sw * 50) / 100; if (rowW < 99) { rowW = 99; }
        var rowX = (sw - rowW) / 2;
        var used  = DR_MENU_ROWS * rowH + (DR_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x000308, 0x000308); dc.clear();
        if (sw == sh) {
            dc.setColor(0x081025, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        // Title — two-line stack + Bitochi subtitle.
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  9 / 100, Graphics.FONT_MEDIUM,
                    "DICE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 19 / 100, Graphics.FONT_SMALL,
                    "ROYALE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFE699, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 30 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];

        var modeLabel    = "Mode:   " + ctrl.modeName();
        var rerollsLabel = "Rolls:  " + ctrl.menuRerolls.format("%d");
        var startLabel   = "START";
        var labels = [modeLabel, rerollsLabel, startLabel, ""];

        for (var i = 0; i < DR_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);

            if (i == DR_ROW_LB) {
                // Hype-y gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == DR_ROW_START);
            dc.setColor(sel ? (isStart ? 0x223300 : 0x182030) : 0x0A1018,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0xFFCC44) : 0x223344,
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

        // Best score for selected mode (and daily streak/lock).
        var sub;
        if (ctrl.menuMode == DR_MODE_DAILY) {
            if (ctrl.dailyPlayedToday) {
                sub = "Daily done · streak " + ctrl.streak.format("%d");
            } else {
                sub = "Best " + ctrl.bestDaily.format("%d")
                    + " · streak " + ctrl.streak.format("%d");
            }
        } else {
            sub = "Best " + ctrl.bestForMode().format("%d")
                + " · played " + ctrl.gamesPlayed.format("%d");
        }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    sub, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── PHASE_ROLL: dice strip + ROLL / SCORE buttons ───────────
    //
    // We return the geometry from `_diceLayout` so the MainView can
    // forward tap hits to controller cursor positions.
    // Layout shrunk ≈10 % vs. the original (user request) — all
    // proportional sizes scaled down so the gameplay UI sits well
    // inside the round bezel of fenix/forerunner watches.
    static function diceLayout(sw, sh) {
        var s  = (sw * 12) / 100; if (s < 16) { s = 16; }
        if (s > 28) { s = 28; }
        var gap = (sw * 2) / 100; if (gap < 3) { gap = 3; }
        var totalW = 5 * s + 4 * gap;
        var x0 = (sw - totalW) / 2;
        var y  = (sh * 38) / 100;
        return [s, gap, x0, y];
    }
    static function buttonLayout(sw, sh) {
        var bw = (sw * 25) / 100; if (bw < 54) { bw = 54; }
        var bh = (sh *  9) / 100; if (bh < 16) { bh = 16; }
        var gap = (sw *  4) / 100; if (gap <  4) { gap =  4; }
        var totalW = 2 * bw + gap;
        var x0 = (sw - totalW) / 2;
        var y  = (sh * 65) / 100;
        return [bw, bh, x0, y, gap];
    }

    static function drawPlay(dc, sw, sh, ctrl) {
        dc.setColor(0x000308, 0x000308); dc.clear();
        if (sw == sh) {
            dc.setColor(0x081025, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sw / 2, sh / 2, sw / 2 - 1);
        }
        _drawTopHUD(dc, sw, sh, ctrl);
        _drawDiceStrip(dc, sw, sh, ctrl);
        _drawActionButtons(dc, sw, sh, ctrl);
    }

    hidden static function _drawTopHUD(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        var roundTxt = "Rd " + (ctrl.roundsPlayed + 1).format("%d")
                     + "/" + ctrl.maxRounds.format("%d");
        dc.drawText(cx - sw / 4, sh * 12 / 100, Graphics.FONT_XTINY,
                    roundTxt, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        var scoreTxt = "Sc " + ctrl.scores.total.format("%d");
        dc.drawText(cx + sw / 4, sh * 12 / 100, Graphics.FONT_XTINY,
                    scoreTxt, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var modeBadge = ctrl.modeName();
        if (ctrl.menuMode == DR_MODE_DAILY) { modeBadge = "DAILY"; }
        dc.drawText(cx, sh * 23 / 100, Graphics.FONT_XTINY,
                    modeBadge + "  rerolls " + ctrl.dice.rerollsLeft.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _drawDiceStrip(dc, sw, sh, ctrl) {
        var dl  = diceLayout(sw, sh);
        var s   = dl[0]; var gap = dl[1]; var x0 = dl[2]; var y = dl[3];
        var sel = ctrl.rollCursor;
        for (var i = 0; i < DR_DICE_COUNT; i++) {
            var x   = x0 + i * (s + gap);
            var dv  = ctrl.dice.dice[i];
            var hd  = ctrl.dice.held[i];
            var cur = (ctrl.phase == DR_PHASE_ROLL && sel == i);
            _drawDie(dc, x, y, s, dv, hd, cur);
        }
    }

    hidden static function _drawDie(dc, x, y, s, value, held, cursor) {
        var bg = held    ? 0xFFCC44 : 0xF5F5F5;
        var fg = held    ? 0x000000 : 0x222222;
        var bd = cursor  ? 0x66FF66 : 0x333333;

        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, s, s, 4);
        dc.setColor(bd, Graphics.COLOR_TRANSPARENT);
        for (var t = 0; t < (cursor ? 2 : 1); t++) {
            dc.drawRoundedRectangle(x + t, y + t, s - 2 * t, s - 2 * t, 4);
        }

        // Pip layout, classic-6.  Dots positioned on a 3×3 grid.
        var r = (s / 14); if (r < 1) { r = 1; }
        var x1 = x + s / 4;
        var x2 = x + s / 2;
        var x3 = x + (3 * s) / 4;
        var y1 = y + s / 4;
        var y2 = y + s / 2;
        var y3 = y + (3 * s) / 4;
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        // Center pip (1, 3, 5).
        if (value == 1 || value == 3 || value == 5) {
            dc.fillCircle(x2, y2, r);
        }
        // Diagonal TL/BR pair (2, 3, 4, 5, 6).
        if (value >= 2) {
            dc.fillCircle(x1, y1, r);
            dc.fillCircle(x3, y3, r);
        }
        // Anti-diagonal TR/BL pair (4, 5, 6).
        if (value >= 4) {
            dc.fillCircle(x3, y1, r);
            dc.fillCircle(x1, y3, r);
        }
        // Middle row sides (6 only).
        if (value == 6) {
            dc.fillCircle(x1, y2, r);
            dc.fillCircle(x3, y2, r);
        }
    }

    hidden static function _drawActionButtons(dc, sw, sh, ctrl) {
        var bl  = buttonLayout(sw, sh);
        var bw  = bl[0]; var bh  = bl[1]; var x0 = bl[2]; var y = bl[3]; var gap = bl[4];

        // ROLL pill.
        var canRoll = ctrl.dice.rerollsLeft > 0;
        var rollSel = (ctrl.phase == DR_PHASE_ROLL
                       && ctrl.rollCursor == DR_POS_ROLL);
        _drawPill(dc, x0, y, bw, bh,
                  "ROLL", rollSel, canRoll,
                  0xFFCC44, 0x222200);

        // SCORE pill.
        var scoreSel = (ctrl.phase == DR_PHASE_ROLL
                        && ctrl.rollCursor == DR_POS_SCORE);
        _drawPill(dc, x0 + bw + gap, y, bw, bh,
                  "SCORE", scoreSel, true,
                  0x66FFAA, 0x002211);

        // Footer hint.
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN move  SEL/tap act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _drawPill(dc, x, y, w, h, label, sel, enabled, accent, bgSel) {
        if (!enabled) {
            dc.setColor(0x101820, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, h, 5);
            dc.setColor(0x33424E, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, 5);
            dc.setColor(0x506070, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + w / 2, y + (h - 14) / 2, Graphics.FONT_XTINY,
                        label, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        dc.setColor(sel ? bgSel : 0x0A1018, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 5);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        for (var t = 0; t < (sel ? 2 : 1); t++) {
            dc.drawRoundedRectangle(x + t, y + t, w - 2 * t, h - 2 * t, 5);
        }
        dc.setColor(sel ? accent : 0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, y + (h - 14) / 2, Graphics.FONT_XTINY,
                    label, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── PHASE_SCORE: scrollable scoring screen ──────────────────
    //
    // We show up to 7 rows centered on the current cursor so the
    // selected row is always visible.  Each row: category name on
    // left, scored/preview points on right.  Used categories are
    // dim and skipped during navigation.
    static function scoreRowGeom(sw, sh) {
        // 10 %-shrunk variant: rows a bit shorter & narrower, list
        // starts a bit further down so the title clears the top arc
        // of the round bezel.
        var rowH = (sh * 8) / 100; if (rowH < 13) { rowH = 13; }
        var rowW = (sw * 66) / 100; if (rowW < 130) { rowW = 130; }
        var rowX = (sw - rowW) / 2;
        var listY0 = (sh * 22) / 100;
        return [rowH, rowW, rowX, listY0];
    }

    static function drawScoreScreen(dc, sw, sh, ctrl) {
        dc.setColor(0x000308, 0x000308); dc.clear();
        if (sw == sh) {
            dc.setColor(0x06121E, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sw / 2, sh / 2, sw / 2 - 1);
        }
        var cx = sw / 2;
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 7 / 100, Graphics.FONT_SMALL,
                    "Pick category", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 15 / 100, Graphics.FONT_XTINY,
                    "Sc " + ctrl.scores.total.format("%d")
                    + "  Rd " + (ctrl.roundsPlayed + 1).format("%d")
                    + "/" + ctrl.maxRounds.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        var rg = scoreRowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1]; var rowX = rg[2]; var listY0 = rg[3];

        // Show a window of 7 rows centered on the cursor.
        var window = 7;
        var first = ctrl.scoreCursor - window / 2;
        var maxFirst = DR_CAT_COUNT - window;
        if (first < 0) { first = 0; }
        if (first > maxFirst) { first = maxFirst; }
        if (first < 0) { first = 0; }
        var last = first + window;
        if (last > DR_CAT_COUNT) { last = DR_CAT_COUNT; }

        for (var i = first; i < last; i++) {
            var ry = listY0 + (i - first) * rowH;
            var sel = (i == ctrl.scoreCursor);
            var used = ctrl.scores.isUsed(i);
            var avail = ctrl.scores.isAvailable(i);

            var bg = used ? 0x0A0A12 : (sel ? 0x182030 : 0x0E141E);
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH - 2, 4);
            var bd = used ? 0x223344 : (sel ? 0xFFCC44 : 0x223344);
            dc.setColor(bd, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH - 2, 4);

            var fg = 0x99AABB;
            if (used)         { fg = 0x445566; }
            else if (sel)     { fg = 0xFFE699; }
            else if (!avail)  { fg = 0x334455; }
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rowX + 8, ry + (rowH - 14) / 2 - 1,
                        Graphics.FONT_XTINY,
                        ctrl.scores.categoryName(i),
                        Graphics.TEXT_JUSTIFY_LEFT);

            var rightTxt;
            if (used) {
                rightTxt = ctrl.scores.values[i].format("%d");
            } else if (!avail) {
                rightTxt = "—";
            } else {
                var p = ctrl.previewScore(i);
                rightTxt = "+" + p.format("%d");
            }
            dc.drawText(rowX + rowW - 8, ry + (rowH - 14) / 2 - 1,
                        Graphics.FONT_XTINY,
                        rightTxt, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN move  SEL/tap pick", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── DR_OVER: final scoreboard ──────────────────────────────
    static function drawOver(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x000308, 0x000308); dc.clear();
        if (sw == sh) {
            dc.setColor(0x082035, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  6 / 100, Graphics.FONT_MEDIUM,
                    "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFE699, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 22 / 100, Graphics.FONT_SMALL,
                    "Score " + ctrl.scores.total.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        var bestTxt;
        if (ctrl.menuMode == DR_MODE_CLASSIC) {
            bestTxt = "Best " + ctrl.bestClassic.format("%d");
        } else if (ctrl.menuMode == DR_MODE_QUICK) {
            bestTxt = "Best " + ctrl.bestQuick.format("%d");
        } else {
            bestTxt = "Best " + ctrl.bestDaily.format("%d")
                     + "  Streak " + ctrl.streak.format("%d");
        }
        dc.drawText(cx, sh * 35 / 100, Graphics.FONT_XTINY,
                    bestTxt, Graphics.TEXT_JUSTIFY_CENTER);

        // Mini breakdown: upper / 3K / 4K / FH / SS / LS / Yz.
        var lines = [
            "1-6: " + _sumRange(ctrl.scores, DR_CAT_ONES, DR_CAT_SIXES).format("%d"),
            "3K/4K: " + (ctrl.scores.values[DR_CAT_3K] + ctrl.scores.values[DR_CAT_4K]).format("%d"),
            "FH/Str: " + (ctrl.scores.values[DR_CAT_FH]
                          + ctrl.scores.values[DR_CAT_SS]
                          + ctrl.scores.values[DR_CAT_LS]).format("%d"),
            "Yz/Ch: " + (ctrl.scores.values[DR_CAT_YAHTZ]
                         + ctrl.scores.values[DR_CAT_CHANCE]).format("%d")
        ];
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        var y = sh * 47 / 100;
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, y + i * 16, Graphics.FONT_XTINY,
                        lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "tap/SEL = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _sumRange(scores, lo, hi) {
        var s = 0;
        for (var i = lo; i <= hi; i++) {
            if (scores.isUsed(i)) { s = s + scores.values[i]; }
        }
        return s;
    }
}
