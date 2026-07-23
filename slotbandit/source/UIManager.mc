// ═══════════════════════════════════════════════════════════════
// UIManager.mc — HUD, casino-marquee chess-style menu, and the
// round-over overlay. Visual language matches RenderSystem: brass
// gold, deep casino red, neon bulbs, glossy plaques.
// ═══════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.System;

class UIManager {

    // ── In-play HUD — a slim brass score plaque + spins/best chips ────
    static function drawHUD(dc, ctrl, sw, hudTop) {
        var cx = sw / 2;

        // centre score plaque
        var pw = sw * 34 / 100; if (pw < 74) { pw = 74; }
        var px = cx - pw / 2;
        GfxUtil.vGradientRounded(dc, px, hudTop, pw, 26, 0x2A1E10, 0x120C08, 5, 7);
        dc.setColor(0xB8860B, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, hudTop, pw, 26, 7);
        dc.setColor(0xFFDD55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, hudTop + 1, Graphics.FONT_NUMBER_MILD,
                    ctrl.scoreSys.score.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        // spins-left chip (left) — pulled well inward off the clipped round corners
        _chip(dc, sw * 20 / 100, hudTop + 4, "SPINS", (ctrl.scoreSys.spinsTotal - ctrl.scoreSys.spinsUsed).format("%d"),
              0x66CCFF, Graphics.TEXT_JUSTIFY_LEFT, sw);
        // best chip (right)
        if (ctrl.scoreSys.hi > 0) {
            _chip(dc, sw - sw * 20 / 100, hudTop + 4, "BEST", ctrl.scoreSys.hi.format("%d"),
                  0xFFCC33, Graphics.TEXT_JUSTIFY_RIGHT, sw);
        }

        // Combo/multiplier badge takes priority over the AUTO label — a hot
        // streak is the thing we most want the player to feel.
        if (ctrl.combo >= 2) {
            var mv = ctrl.mult;
            var flame = (System.getTimer() / 200) % 2 == 0;
            var mc = (mv >= 5) ? 0xFF3344 : (mv >= 3 ? 0xFF8822 : 0xFFCC44);
            dc.setColor(GfxUtil.shade(mc, 45), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 1, hudTop + 27, Graphics.FONT_XTINY,
                        (flame ? "\u25B2 " : "  ") + "COMBO x" + mv.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, hudTop + 26, Graphics.FONT_XTINY,
                        (flame ? "\u25B2 " : "  ") + "COMBO x" + mv.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        } else if (ctrl.autoPlay) {
            dc.setColor(0x66DDFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, hudTop + 27, Graphics.FONT_XTINY, "AUTO", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Free-spin bonus banner — flashes briefly after a triple/jackpot ──
    static function drawBonus(dc, ctrl, sw, sh) {
        if (ctrl.bonusFlash <= 0) { return; }
        var cx = sw / 2;
        var by = sh * 30 / 100;
        var on = (ctrl.bonusFlash % 6 < 3);
        var col = on ? 0x8CFF44 : 0xFFDD55;
        var bw = sw * 62 / 100; if (bw < 128) { bw = 128; }
        GfxUtil.vGradientRounded(dc, cx - bw / 2, by, bw, 22, 0x14400A, 0x081F05, 4, 6);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx - bw / 2, by, bw, 22, 6);
        dc.drawText(cx, by + 2, Graphics.FONT_XTINY, ctrl.bonusText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _chip(dc, x, y, label, val, col, justify, sw) {
        dc.setColor(GfxUtil.shade(col, 55), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, label, justify);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 12, Graphics.FONT_XTINY, val, justify);
    }

    // Result banner + action hint under the cabinet.
    static function drawBottomBar(dc, ctrl, sw, y) {
        var cx = sw / 2;
        var r = ctrl.lastResult;
        if (r != null && r["kind"] != "NONE") {
            var label = r["label"];
            var pts   = r.hasKey("gain") ? r["gain"] : r["payout"];
            var mv    = r.hasKey("mult") ? r["mult"] : 1;
            var col = 0xFFCC22;
            if (r["kind"] == "JACKPOT") { col = 0xFF44BB; }
            else if (r["kind"] == "TRIPLE") { col = 0x55DD77; }
            var txt = label.toUpper() + "  +" + pts.format("%d");
            if (mv > 1) { txt = txt + " x" + mv.format("%d"); }
            // glow shadow then text
            dc.setColor(GfxUtil.shade(col, 35), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 1, y + 1, Graphics.FONT_SMALL, txt, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_SMALL, txt, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        dc.setColor(0x99AABB, Graphics.COLOR_TRANSPARENT);
        var hint;
        if (ctrl.spinState == SS_IDLE)          { hint = "TAP TO SPIN"; }
        else if (ctrl.spinState == SS_SPINNING) { hint = "TAP TO STOP"; }
        else                                     { hint = " "; }
        dc.drawText(cx, y, Graphics.FONT_XTINY, hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Chess-style menu, casino edition ──────────────────────────────
    static function drawMenu(dc, ctrl, sw, sh) {
        var cx = sw / 2;

        // deep casino gradient backdrop + round vignette
        GfxUtil.vGradient(dc, 0, 0, sw, sh, 0x3A0A18, 0x08040E, 12);
        if (sw == sh) {
            dc.setColor(0x05030A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 + 4);
            GfxUtil.vGradient(dc, sw / 8, sh / 10, sw * 6 / 8, sh * 8 / 10, 0x4A0E1E, 0x0A0410, 10);
        }

        var phase = (System.getTimer() / 220).toNumber();

        // ── Marquee title plaque with chasing bulbs (≈10% smaller) ──
        var mw = sw * 66 / 100; if (mw > 200) { mw = 200; }
        var mh = sh * 18 / 100; if (mh < 38) { mh = 38; } if (mh > 63) { mh = 63; }
        var mx = cx - mw / 2;
        var my = sh * 7 / 100;
        GfxUtil.vGradientRounded(dc, mx, my, mw, mh, 0x8E1220, 0x4A0812, 8, 10);
        dc.setColor(0xB8860B, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(mx, my, mw, mh, 10);
        GfxUtil.bulbRing(dc, mx, my, mw, mh, 2, 16, phase, 0xFFDD55, 0x7A5A10);

        // title text with gold shadow
        dc.setColor(0x2A0206, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, my + mh / 2 - 14, Graphics.FONT_SMALL, "SLOT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, my + mh / 2 - 15, Graphics.FONT_SMALL, "SLOT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFF3B0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, my + mh / 2 - 1, Graphics.FONT_XTINY, "BANDIT", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xCC9955, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, my + mh + 1, Graphics.FONT_XTINY, "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // mini reel trio just under the title
        _miniReels(dc, cx, my + mh + sh * 8 / 100, phase);

        if (ctrl.scoreSys.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, sh * 41 / 100, Graphics.FONT_XTINY,
                        "BEST (" + ctrl.roundName() + ") " + ctrl.scoreSys.hi.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Rows ──
        var g = menuRowGeom(sw, sh);
        var rowH = g[0]; var rowW = g[1]; var rowX = g[2]; var rowY0 = g[3]; var gap = g[4];
        var labels = new [SB_MENU_ROWS];
        labels[SB_ROW_ROUND] = "Round: " + ctrl.roundName() + " (" + ctrl.roundSpins().format("%d") + ")";
        labels[SB_ROW_START] = "SPIN IN";

        for (var i = 0; i < SB_MENU_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == ctrl.menuRow);

            if (i == SB_ROW_LB) {
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == SB_ROW_START);
            _menuRow(dc, cx, rowX, ry, rowW, rowH, labels[i], sel, isStart);
        }

        dc.setColor(0xAA8866, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 13, Graphics.FONT_XTINY,
                    "UP/DN move  SEL act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _menuRow(dc, cx, rowX, ry, rowW, rowH, label, sel, isStart) {
        var top; var bot; var bd; var fg;
        if (isStart) {
            if (sel) { top = 0x2E7D18; bot = 0x14400A; bd = 0x8CFF44; fg = 0xEEFFD0; }
            else      { top = 0x1A4A0E; bot = 0x0C2606; bd = 0x3A7A22; fg = 0xAADD88; }
        } else {
            if (sel) { top = 0x5A3E10; bot = 0x2A1C06; bd = 0xFFCC44; fg = 0xFFEEBB; }
            else      { top = 0x2A2012; bot = 0x14100A; bd = 0x5A4020; fg = 0xC8B088; }
        }
        GfxUtil.vGradientRounded(dc, rowX, ry, rowW, rowH, top, bot, 5, 7);
        dc.setColor(bd, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 7);
        if (sel) {
            var ay = ry + rowH / 2;
            dc.setColor(bd, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[rowX + 6, ay - 5], [rowX + 6, ay + 5], [rowX + 13, ay]]);
        }
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ry + (rowH - 15) / 2, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _miniReels(dc, cx, cy, phase) {
        var syms = [SYM_CHERRY, SYM_SEVEN, SYM_BELL];
        var w = 24;
        var totalW = w * 3 + 8;
        var x0 = cx - totalW / 2 + w / 2;
        // brass tray behind the three windows
        GfxUtil.vGradientRounded(dc, cx - totalW / 2 - 4, cy - w / 2 - 4, totalW + 8, w + 8,
                                 0xF2C94C, 0x6E4E12, 6, 6);
        for (var i = 0; i < 3; i++) {
            var x = x0 + i * (w + 4);
            GfxUtil.vGradient(dc, x - w / 2, cy - w / 2, w, w, 0x241A22, 0x0D0910, 5);
            dc.setColor(0x5A3E0E, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x - w / 2, cy - w / 2, w, w);
            SymbolManager.draw(dc, syms[i], x, cy, w);
        }
    }

    static function menuRowGeom(sw, sh) {
        // Rows ≈10% smaller: narrower, shorter, with a slightly larger
        // bottom margin so the whole block reads as a compact panel.
        var topZone      = (sh * 48) / 100;
        var bottomMargin = (sh * 14) / 100; if (bottomMargin < 13) { bottomMargin = 13; }
        var gap          = (sh * 3) / 100;  if (gap < 4) { gap = 4; }
        var avail = (sh - bottomMargin) - topZone;
        var rowH  = (avail - gap * (SB_MENU_ROWS - 1)) / SB_MENU_ROWS;
        if (rowH > 23) { rowH = 23; }
        if (rowH < 14) { rowH = 14; }
        var rowW = (sw * 58) / 100; if (rowW < 102) { rowW = 102; }
        var rowX = (sw - rowW) / 2;
        var used = SB_MENU_ROWS * rowH + (SB_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // ── Round-over overlay ────────────────────────────────────────────
    static function drawOver(dc, ctrl, sw, sh) {
        // dim the world behind
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        for (var yy = 0; yy < sh; yy += 3) { dc.drawLine(0, yy, sw, yy); }

        var jackTitle = (ctrl.scoreSys.jackpots > 0);
        var lines = [
            [ctrl.scoreSys.score.format("%d"), 0xFFFFFF]
        ];
        if (ctrl.scoreSys.jackpots > 0) {
            lines.add([ctrl.scoreSys.jackpots.format("%d") + " jackpot" +
                       (ctrl.scoreSys.jackpots > 1 ? "s" : "") + " hit!", 0xFF66CC]);
        }
        if (ctrl.bestCombo >= 3) {
            lines.add(["Best streak x" + ctrl.bestCombo.format("%d"), 0xFFAA44]);
        }
        if (ctrl.hasNewBest()) {
            lines.add(["★ NEW BEST! ★", 0x44FF66]);
        } else if (ctrl.scoreSys.hi > 0) {
            lines.add(["Best " + ctrl.scoreSys.hi.format("%d"), 0x88AABB]);
        }

        // ── Meta-progression summary (shared, shop-ready) ──
        lines.add(["Lv " + ctrl.metaLevel().format("%d") + " " + ctrl.metaRank() +
                   " - " + ctrl.metaCoins().format("%d") + "c", 0xBFD8C4]);
        var stk = ctrl.metaStreak();
        if (stk >= 1) {
            lines.add(["Streak " + stk.format("%d"), 0x66CCFF]);
        }
        lines.add(["Symbols " + ctrl.symbolsOwned().format("%d") + "/" +
                   ctrl.symbolsTotal().format("%d"), 0xFFDD88]);
        if (ctrl.pgUnlockMsg != null) {
            lines.add([ctrl.pgUnlockMsg, 0x8CFF44]);
        }

        GameOverCard.draw(dc, sw, sh,
            jackTitle ? "JACKPOT RUN!" : "ROUND OVER",
            jackTitle ? 0xFF44BB : 0xFFCC33,
            lines, "tap = again   BACK = menu", 0xFFAA22);
    }
}
