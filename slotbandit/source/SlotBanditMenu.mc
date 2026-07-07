// ═══════════════════════════════════════════════════════════════
// SlotBanditMenu.mc — SlotBandit's wiring into the shared unified menu.
//
// MenuConfig (title, casino colours, signature mini-reels art, OPTIONS list)
// plus the GameHooks launching a round, exposing the leaderboard variant and
// the best footer. The main menu itself is the shared GameMenuView.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class SlotBanditHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a brass tray with three reel windows.
    function drawArt(dc, cx, cy, w, h) as Void {
        var rw = 20; var totalW = rw * 3 + 6; var x0 = cx - totalW / 2 + rw / 2;
        dc.setColor(0xB8860B, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - totalW / 2 - 3, cy - rw / 2 - 3, totalW + 6, rw + 6, 4);
        var cols = [0xFF4455, 0xFFDD55, 0xFF9933];
        var glyph = ["7", "$", "B"];
        for (var i = 0; i < 3; i++) {
            var x = x0 + i * (rw + 3);
            dc.setColor(0x120C10, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - rw / 2, cy - rw / 2, rw, rw);
            dc.setColor(0x5A3E0E, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x - rw / 2, cy - rw / 2, rw, rw);
            dc.setColor(cols[i], Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, cy - 8, Graphics.FONT_XTINY, glyph[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Leaderboard is split by round length (mirrors GameController.roundName()).
    function lbVariant() as Lang.String {
        return SB_ROUND_NAMES[_round()];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("sb_hi" + _round().toString());
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }

    hidden function _round() as Lang.Number {
        try {
            var v = Application.Storage.getValue(SB_ROUND_KEY);
            if (v instanceof Lang.Number && v >= 0 && v < SB_ROUND_COUNT) { return v; }
        } catch (e) {}
        return SB_ROUND_NORMAL;
    }
}

function buildSlotBanditMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => LB_GAME_ID,
        :title1  => "SLOT",
        :title2  => "BANDIT",
        :col1    => 0xFFDD55,
        :col2    => 0xFFF3B0,
        :bg      => 0x0A0410,
        :circle  => 0x1E0812,
        :accent  => 0x8CFF44,
        :lbTitle => "SLOT BANDIT",
        :hooks   => new SlotBanditHooks(),
        :options => [
            new GmOption(SB_ROUND_KEY, "Round", ["QUICK", "NORMAL", "MARATHON"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
