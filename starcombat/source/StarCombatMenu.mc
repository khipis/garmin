// ═══════════════════════════════════════════════════════════════
// StarCombatMenu.mc — StarCombat's wiring into the shared unified menu.
//
// MenuConfig (title, colours, signature Star-Destroyer art, OPTIONS list) plus
// the GameHooks launching a run, exposing the leaderboard variant and best
// footer. The main menu itself is the shared GameMenuView.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class StarCombatHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a Star-Destroyer wedge + engine glow.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx + 22, cy], [cx - 16, cy - 10], [cx - 16, cy + 10]]);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 13, cy - 3, 8, 6);   // bridge
        dc.setColor(0x002B66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 15, cy - 5, 3);
        dc.fillCircle(cx - 15, cy + 5, 3);
        dc.setColor(0x77BBFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 15, cy - 5, 2);
        dc.fillCircle(cx - 15, cy + 5, 2);
    }

    // Leaderboard is split by difficulty (mirrors GameController.diffName()).
    function lbVariant() as Lang.String {
        var d = SC_DIFF_NORMAL;
        try {
            var v = Application.Storage.getValue(SC_K_DIFF);
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == SC_DIFF_EASY) { return "Easy"; }
        if (d == SC_DIFF_HARD) { return "Hard"; }
        return "Norm";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue(SC_K_BEST);
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildStarCombatMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => LB_GAME_ID,
        :title1  => "STAR",
        :title2  => "COMBAT",
        :col1    => 0xFFCC33,
        :col2    => 0xFF8833,
        :bg      => 0x000308,
        :circle  => 0x06121E,
        :accent  => 0x66CCEE,
        :lbTitle => "STAR COMBAT",
        :hooks   => new StarCombatHooks(),
        :options => [
            new GmOption(SC_K_SENS, "Sensitivity", ["LOW", "NORM", "HIGH"], 1),
            new GmOption(SC_K_DIFF, "Difficulty",  ["EASY", "NORM", "HARD"], 1),
            new GmOption("sc_fx", "Sound & Haptics", ["ON", "OFF"], 0),
            // Cosmetic ship skin — unlocked by rank, shop-ready. A locked
            // pick simply renders as the classic hull until it's owned.
            new GmOption(SC_K_SKIN, "Ship", ["CLASSIC", "NEON", "GOLD"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
