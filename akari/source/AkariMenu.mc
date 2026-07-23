// ═══════════════════════════════════════════════════════════════
// AkariMenu.mc — Akari's wiring into the shared unified menu.
//
// Builds the MenuConfig (title, amber palette, signature bulb art,
// OPTIONS list) and the GameHooks that launch the puzzle, expose the
// leaderboard variant (board size) and a lifetime "SOLVED" footer.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class AkariHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a live puzzle.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a warm light bulb with a few rays.
    function drawArt(dc, cx, cy, w, h) as Void {
        var r = 10;
        // rays
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, cy - r - 8, cx, cy - r - 3);
        dc.drawLine(cx - r - 8, cy - 2, cx - r - 3, cy - 2);
        dc.drawLine(cx + r + 3, cy - 2, cx + r + 8, cy - 2);
        dc.drawLine(cx - r - 5, cy - r - 5, cx - r - 2, cy - r - 2);
        dc.drawLine(cx + r + 2, cy - r - 5, cx + r + 5, cy - r - 2);
        // bulb body
        dc.setColor(0xFFEE99, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - 2, r);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy - 2, r);
        // screw base
        dc.fillRectangle(cx - 5, cy + r - 3, 10, 6);
    }

    // Leaderboard is split by board size (mirrors GameController.lbVariant()).
    function lbVariant() as Lang.String {
        var d = 0;
        try {
            var v = Application.Storage.getValue("ak_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        return (d == 0) ? "6x6" : "7x7";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("ak_solved_total");
            if (v instanceof Lang.Number && v > 0) { return "SOLVED " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildAkariMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "akari",
        :title1  => "AKARI",
        :title2  => "Light Up",
        :col1    => 0xFFCC22,
        :col2    => 0xFFEE88,
        :bg      => 0x10080A,
        :circle  => 0x1A1015,
        :accent  => 0x34D399,
        :lbTitle => "AKARI",
        :hooks   => new AkariHooks(),
        :options => [
            new GmOption("ak_diff", "Difficulty", ["EASY 6x6", "HARD 7x7"], 0),
            new GmOption("ak_mode", "Mode", ["LEVELS", "DAILY"], 0),
            new GmOption("ak_errs", "Errors", ["OFF", "ON"], 0),
            new GmOption("ak_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
