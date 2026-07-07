// ═══════════════════════════════════════════════════════════════
// DiceRoyaleMenu.mc — DiceRoyale's wiring into the shared menu.
//
// Builds the MenuConfig (title, colours, signature die art, OPTIONS
// list) and the GameHooks that launch a game, expose the leaderboard
// variant (mode) and a BEST-score footer.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class DiceRoyaleHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a live game.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a die showing five pips.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0xF0E8D0, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 12, cy - 12, 24, 24, 5);
        dc.setColor(0xC08030, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx - 12, cy - 12, 24, 24, 5);
        dc.setColor(0x22160A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 6, cy - 6, 2);
        dc.fillCircle(cx + 6, cy - 6, 2);
        dc.fillCircle(cx,     cy,     2);
        dc.fillCircle(cx - 6, cy + 6, 2);
        dc.fillCircle(cx + 6, cy + 6, 2);
    }

    // Leaderboard is split by mode (mirrors GameController.variantName()).
    function lbVariant() as Lang.String {
        var m = 0;
        try {
            var v = Application.Storage.getValue("dr_mode");
            if (v instanceof Lang.Number) { m = v; }
        } catch (e) {}
        if (m == 1) { return "quick"; }
        if (m == 2) { return "daily"; }
        return "classic";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("dr_best_classic");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildDiceRoyaleMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "diceroyale",
        :title1  => "DICE",
        :title2  => "ROYALE",
        :col1    => 0xFFCC44,
        :col2    => 0xFF6644,
        :bg      => 0x000308,
        :circle  => 0x081025,
        :accent  => 0xFFEE66,
        :lbTitle => "DICE ROYALE",
        :hooks   => new DiceRoyaleHooks(),
        :options => [
            new GmOption("dr_mode", "Mode", ["CLASSIC", "QUICK", "DAILY"], 0),
            new GmOption("dr_rerolls", "Rerolls", ["1", "2", "3"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
