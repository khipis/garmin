// ═══════════════════════════════════════════════════════════════
// UIManager.mc — HUD, chess-style menu, and game-over chrome.
// ═══════════════════════════════════════════════════════════════
using Toybox.Graphics;

class UIManager {

    static function drawHUD(dc, ctrl, sw, hudTop, energyBarY) {
        var cx = sw / 2;

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, hudTop, Graphics.FONT_NUMBER_MILD,
                    ctrl.scoreSys.score.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        if (ctrl.scoreSys.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sw - 6, hudTop + 2, Graphics.FONT_XTINY,
                        "B " + ctrl.scoreSys.hi.format("%d"), Graphics.TEXT_JUSTIFY_RIGHT);
        }
        if (ctrl.scoreSys.combo >= 2) {
            var combo = ctrl.scoreSys.combo;
            var cc; var cf;
            if (combo >= 5) { cc = 0xFF7A2A; cf = Graphics.FONT_TINY; }   // on fire
            else            { cc = 0x66DDFF; cf = Graphics.FONT_XTINY; }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(7, hudTop + 3, cf, "x" + (combo + 1).format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(cc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(6, hudTop + 2, cf, "x" + (combo + 1).format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Energy bar — depletes over time, refills on chop; colour
        // shifts green -> yellow -> red as the pressure ramps up.
        var barW = sw * 60 / 100; if (barW < 90) { barW = 90; }
        var barX = cx - barW / 2;
        var barH = 8;
        var pct  = ctrl.energy * 100 / ENERGY_MAX;
        var fillW = barW * pct / 100;
        var col;
        if (pct > 55)      { col = 0x33CC44; }
        else if (pct > 25) { col = 0xFFCC22; }
        else               { col = 0xFF3333; }

        dc.setColor(0x0E0E12, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX - 1, energyBarY - 1, barW + 2, barH + 2, 4);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, energyBarY, fillW, barH, 4);
        // Glossy highlight on the filled portion.
        if (fillW > 4) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX + 2, energyBarY + 1, fillW - 4, 1);
        }
        // Low-energy pulse: flash the frame when the run is about to end.
        var frameC = 0x445566;
        if (pct <= 25 && (ctrl.frame % 6 < 3)) { frameC = 0xFF5555; }
        dc.setColor(frameC, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(barX, energyBarY, barW, barH, 4);
    }

    // ── Milestone banner — a gold pill toast on chop/combo milestones ──
    static function drawMilestone(dc, ctrl, sw, sh) {
        var cx = sw / 2;
        var y  = sh * 36 / 100;
        var w  = sw * 50 / 100; if (w < 116) { w = 116; }
        var x  = cx - w / 2;
        dc.setColor(0x2A2200, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, 24, 7);
        dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, 24, 7);
        dc.drawText(cx, y + 3, Graphics.FONT_XTINY,
                    ctrl.milestoneText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Daily-login toast — a green pill under the HUD on the first frame ──
    static function drawDailyToast(dc, ctrl, sw, sh) {
        if (ctrl.dailyText == null) { return; }
        var cx = sw / 2;
        var y  = sh * 22 / 100;
        var w  = sw * 66 / 100; if (w < 132) { w = 132; }
        var x  = cx - w / 2;
        dc.setColor(0x0C2A12, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, 22, 7);
        dc.setColor(0x44BB22, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, 22, 7);
        dc.setColor(0xCFF0C0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + 2, Graphics.FONT_XTINY,
                    ctrl.dailyText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Themed lumberjack rank ladder derived from the shared XP level.
    hidden static function _axeRank(lvl) {
        if (lvl >= 25) { return "Legend"; }
        if (lvl >= 15) { return "Timber Boss"; }
        if (lvl >= 10) { return "Lumberjack"; }
        if (lvl >= 6)  { return "Woodsman"; }
        if (lvl >= 3)  { return "Splitter"; }
        return "Rookie";
    }

    // ── Chess-style menu — title, decorative axe-in-log, three rows:
    // Diff / START / LEADERBOARD. ──────────────────────────────────
    static function drawMenu(dc, ctrl, sw, sh) {
        var cx = sw / 2;
        dc.setColor(0x0B1418, 0x0B1418); dc.clear();
        if (sw == sh) {
            dc.setColor(0x101A14, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 8 / 100, Graphics.FONT_LARGE,
                    "DRWAL", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88AA88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 20 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var iy = sh * 32 / 100;
        dc.setColor(0x8A5A2E, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 16, iy, 32, 14, 3);
        dc.setColor(0xE8D8B8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, iy + 7, 5);
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 2, iy - 10, 4, 12);
        dc.fillRectangle(cx - 8, iy - 14, 8, 8);

        if (ctrl.scoreSys.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, sh * 42 / 100, Graphics.FONT_XTINY,
                        "BEST " + ctrl.scoreSys.hi.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        var g = _menuRowGeom(sw, sh);
        var rowH = g[0]; var rowW = g[1]; var rowX = g[2]; var rowY0 = g[3]; var gap = g[4];
        var labels = new [DR_MENU_ROWS];
        labels[DR_ROW_DIFF]  = "Diff: " + ctrl.diffName();
        labels[DR_ROW_START] = "START";

        for (var i = 0; i < DR_MENU_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == ctrl.menuRow);

            if (i == DR_ROW_LB) {
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == DR_ROW_START);
            var bg; var bd; var fg;
            if      (sel && isStart) { bg = 0x1A4400; bd = 0x44BB22; fg = 0xAAFF66; }
            else if (sel)             { bg = 0x1A2E00; bd = 0x88CC22; fg = 0xEEFFCC; }
            else if (isStart)         { bg = 0x102010; bd = 0x224422; fg = 0x88AA88; }
            else                       { bg = 0x1A1610; bd = 0x33291A; fg = 0xAA9977; }
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(bd, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x557755, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN move  SEL act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _menuRowGeom(sw, sh) {
        var topZone      = (sh * 48) / 100;
        var bottomMargin = (sh * 12) / 100; if (bottomMargin < 12) { bottomMargin = 12; }
        var gap          = (sh * 3) / 100;  if (gap < 4) { gap = 4; }
        var avail = (sh - bottomMargin) - topZone;
        var rowH  = (avail - gap * (DR_MENU_ROWS - 1)) / DR_MENU_ROWS;
        if (rowH > 26) { rowH = 26; }
        if (rowH < 15) { rowH = 15; }
        var rowW = (sw * 62) / 100; if (rowW < 110) { rowW = 110; }
        var rowX = (sw - rowW) / 2;
        var used = DR_MENU_ROWS * rowH + (DR_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // ── Game-over overlay — quick freeze + instant-restart hint ─────
    static function drawOver(dc, ctrl, sw, sh) {
        var title = (ctrl.deathReason == "TIMEOUT") ? "TOO SLOW!" : "TIMBERRR!";
        var lines = [
            ["Score " + ctrl.scoreSys.score.format("%d"), 0xFFFFFF]
        ];
        if (ctrl.hasNewBest()) {
            lines.add(["NEW BEST!", 0x44FF66]);
        } else if (ctrl.scoreSys.hi > 0) {
            lines.add(["Best " + ctrl.scoreSys.hi.format("%d"), 0x88AABB]);
        }
        if (ctrl.maxCombo >= 2) {
            lines.add(["Max combo x" + (ctrl.maxCombo + 1).format("%d"), 0xFFAA44]);
        }

        // ── Shared meta-progression summary (level/rank + coin balance) ──
        // Fully guarded — Progress never throws, but keep the whole block safe.
        try {
            var lvl = Progress.level();
            lines.add(["Lv " + lvl.format("%d") + " " + _axeRank(lvl)
                       + " - " + Progress.coins().format("%d") + "c", 0xBFD8C4]);
            var stk = Progress.currentStreak();
            if (stk >= 2) {
                lines.add(["Day streak " + stk.format("%d"), 0x9AD0EC]);
            }
            // One-shot axe-unlock banner (gold), cleared at the next run start.
            if (ctrl.pgUnlockMsg != null) {
                lines.add([ctrl.pgUnlockMsg, 0xFFD24A]);
            }
        } catch (e) {}

        GameOverCard.draw(dc, sw, sh, title, 0xFF6633,
            lines, "tap = again  BACK = menu", 0xFF6633);
    }
}
