// ═══════════════════════════════════════════════════════════════
// ChickenCrossMenu.mc — ChickenCross's wiring into the shared menu.
//
// Builds the MenuConfig (title, colours, signature chicken art,
// OPTIONS list) and the GameHooks that launch the run and expose a
// BEST-score footer. Leaderboard uses no variant (matches submit "").
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class ChickenCrossHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a live run.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: the chicken (white body, red comb, beak).
    function drawArt(dc, cx, cy, w, h) as Void {
        var rad = 10;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, rad);
        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - rad + 1, rad / 2);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + rad, cy, 2);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + rad / 3, cy - rad / 3, 2);
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("cc_best");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildChickenCrossMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "chickencross",
        :title1  => "CHICKEN",
        :title2  => "CROSS",
        :col1    => 0xFFEE66,
        :col2    => 0xFF7733,
        :bg      => 0x081020,
        :circle  => 0x0C1830,
        :accent  => 0xFFEE66,
        :lbTitle => "CHICKEN CROSS",
        :hooks   => new ChickenCrossHooks(),
        :options => [
            new GmOption("cc_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            new GmOption("cc_lives", "Lives", ["1", "2", "3", "4", "5"], 2),
            new GmOption("cc_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
