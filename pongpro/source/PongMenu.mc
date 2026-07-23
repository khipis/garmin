// ═══════════════════════════════════════════════════════════════
// PongMenu.mc — Pong Pro's wiring into the shared unified menu.
//
// Builds the MenuConfig (title, colours, signature court art, OPTIONS list)
// and the GameHooks that launch the match, expose the leaderboard variant and
// the WINS footer. The main menu itself is the shared GameMenuView.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class PongHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a live match.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-court: two paddles + a ball, matching the in-game palette.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 40, cy - 6, 3, 14);
        dc.setColor(0xFF44AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx + 37, cy - 2, 3, 14);
        dc.setColor(0x00EEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 2, cy - 1, 4, 4);
    }

    // Leaderboard is split by AI difficulty (mirrors GameController.diffName()).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("pp_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "Easy"; }
        if (d == 2) { return "Hard"; }
        return "Medium";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("wins");
            if (v instanceof Lang.Number && v > 0) { return "WINS " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

// Factory used by the App's getInitialView().
function buildPongMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "pongpro",
        :title1  => "PONG",
        :title2  => "PRO",
        :col1    => 0x00EEFF,
        :col2    => 0xFF44AA,
        :bg      => 0x080808,
        :circle  => 0x101418,
        :accent  => 0x34D399,
        :lbTitle => "PONG PRO",
        :hooks   => new PongHooks(),
        :options => [
            new GmOption("pp_diff", "Difficulty", ["EASY", "MEDIUM", "HARD"], 1),
            new GmOption("pp_tilt", "Tilt steer", ["OFF", "ON"], 0),
            new GmOption("pp_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
