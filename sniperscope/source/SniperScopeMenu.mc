// ═══════════════════════════════════════════════════════════════
// SniperScopeMenu.mc — SniperScope's wiring into the shared unified menu.
//
// MenuConfig (title, colours, signature scope-reticle art, OPTIONS list) plus
// the GameHooks launching a mission, exposing the leaderboard variant and best
// footer. The main menu itself is the shared GameMenuView.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class SniperScopeHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a scope reticle (rings + crosshair + dot).
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0x88CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, 16);
        dc.drawCircle(cx, cy, 6);
        dc.drawLine(cx - 22, cy, cx - 8, cy);
        dc.drawLine(cx + 8, cy, cx + 22, cy);
        dc.drawLine(cx, cy - 22, cx, cy - 8);
        dc.drawLine(cx, cy + 8, cx, cy + 22);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 1, cy - 1, 2, 2);
    }

    // Leaderboard is split by difficulty (mirrors GameController.diffName()).
    function lbVariant() as Lang.String {
        var d = SS_DIFF_NORMAL;
        try {
            var v = Application.Storage.getValue(SS_K_DIFF);
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == SS_DIFF_EASY) { return "Easy"; }
        if (d == SS_DIFF_HARD) { return "Hard"; }
        return "Norm";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue(SS_K_BEST);
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildSniperScopeMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => SS_LB_GAME_ID,
        :title1  => "SNIPER",
        :title2  => "SCOPE",
        :col1    => 0xCCFF99,
        :col2    => 0x88CC66,
        :bg      => 0x000406,
        :circle  => 0x08140C,
        :accent  => 0x66CC66,
        :lbTitle => "SNIPER",
        :hooks   => new SniperScopeHooks(),
        :options => [
            new GmOption(SS_K_SENS, "Sensitivity", ["LOW", "NORM", "HIGH"], 1),
            new GmOption(SS_K_DIFF, "Difficulty",  ["EASY", "NORM", "HARD"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
