// ═══════════════════════════════════════════════════════════════
// StarSwarmMenu.mc — StarSwarm's wiring into the shared unified menu.
//
// MenuConfig (title, colours, signature swarm art, OPTIONS list) plus the
// GameHooks launching a run, exposing the leaderboard variant and best footer.
// The main menu itself is the shared GameMenuView.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class StarSwarmHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: an alien row over the player ship + shot.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 15, cy - 9, 6, 5);
        dc.fillRectangle(cx - 3,  cy - 9, 6, 5);
        dc.fillRectangle(cx + 9,  cy - 9, 6, 5);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 1, cy - 2, 2, 6);
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, cy + 6], [cx - 8, cy + 14], [cx + 8, cy + 14]]);
    }

    // Leaderboard is split by difficulty (mirrors GameController.difficultyName()).
    function lbVariant() as Lang.String {
        var d = SS_DIFF_NORMAL;
        try {
            var v = Application.Storage.getValue(SS_DIFF_KEY);
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == SS_DIFF_EASY) { return "Easy"; }
        if (d == SS_DIFF_HARD) { return "Hard"; }
        return "Normal";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue(SS_BEST_KEY);
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildStarSwarmMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => SS_LB_GAME_ID,
        :title1  => "STAR",
        :title2  => "SWARM",
        :col1    => 0x66CCFF,
        :col2    => 0xFFAA22,
        :bg      => 0x000510,
        :circle  => 0x081025,
        :accent  => 0x66CCFF,
        :lbTitle => "STAR SWARM",
        :hooks   => new StarSwarmHooks(),
        :options => [
            new GmOption(SS_DIFF_KEY,  "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            new GmOption(SS_LIVES_KEY, "Lives",      ["1", "2", "3", "4", "5"],  2),
            new GmOption("ss_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
