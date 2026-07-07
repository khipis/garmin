// ═══════════════════════════════════════════════════════════════
// GyroMazeMenu.mc — GyroMaze's wiring into the shared unified menu.
//
// Builds the MenuConfig (title, colours, maze emblem art, OPTIONS list)
// and the GameHooks that launch the run, expose the leaderboard variant
// (difficulty) and the best-time footer.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class GyroMazeHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a live maze run.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature emblem: a little maze cell with a ball and the green exit.
    function drawArt(dc, cx, cy, w, h) as Void {
        var s = 30;
        var x0 = cx - s / 2;
        var y0 = cy - s / 2;
        dc.setColor(0x1A2538, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0, y0, s, s, 3);
        dc.setColor(0x00CC66, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 + s - 9, y0 + s - 9, 7, 7);
        // A couple of interior walls for that maze feel.
        dc.setColor(0x0A0F18, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 + 9, y0 + 3, 2, s - 12);
        dc.fillRectangle(x0 + 9, y0 + s - 9, s - 18, 2);
        // The rolling ball.
        dc.setColor(0xFF2D55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + 5, y0 + 5, 3);
    }

    // Leaderboard is split by difficulty (mirrors GameController.lbVariant()).
    function lbVariant() as Lang.String {
        var d = 0;
        try {
            var v = Application.Storage.getValue("gm_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 1) { return "Med";  }
        if (d == 2) { return "Hard"; }
        return "Easy";
    }

    // Best time for the selected difficulty, if any.
    function footerText() as Lang.String or Null {
        try {
            var d = Application.Storage.getValue("gm_diff");
            if (!(d instanceof Lang.Number)) { d = 0; }
            var ms = Application.Storage.getValue("gm_best_" + d.format("%d"));
            if (ms instanceof Lang.Number && ms >= 0) {
                return "BEST " + (ms / 1000).format("%d") + "s";
            }
        } catch (e) {}
        return null;
    }
}

// Factory used by the App's getInitialView().
function buildGyroMazeMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "gyromaze",
        :title1  => "GYRO",
        :title2  => "MAZE",
        :col1    => 0xFFB300,
        :col2    => 0xFFB300,
        :bg      => 0x020810,
        :circle  => 0x050F20,
        :accent  => 0x00EE80,
        :lbTitle => "GYRO MAZE",
        :hooks   => new GyroMazeHooks(),
        :options => [
            new GmOption("gm_diff", "Difficulty", ["EASY", "MEDIUM", "HARD"], 0),
            new GmOption("gm_biome", "Biome",
                ["RANDOM", "NORMAL", "ICE", "TRAP", "SPEED", "CHAOS"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
