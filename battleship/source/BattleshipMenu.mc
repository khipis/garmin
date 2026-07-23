// ═══════════════════════════════════════════════════════════════
// BattleshipMenu.mc — Battleship's wiring into the shared unified menu.
//
// Builds the MenuConfig (title, naval palette, signature ship art,
// OPTIONS list) and the GameHooks that launch the match, expose the
// leaderboard variant (difficulty) and a WINS footer.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class BattleshipHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into ship setup / a live match.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a warship on the water with a hit marker.
    function drawArt(dc, cx, cy, w, h) as Void {
        // Water line.
        dc.setColor(0x143A6D, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 30, cy + 9, 60, 4);
        // Hull.
        dc.setColor(0x4FA0E6, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 24, cy + 2], [cx + 24, cy + 2],
                        [cx + 17, cy + 9], [cx - 17, cy + 9]]);
        // Superstructure + funnel.
        dc.setColor(0x2D6BAF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 6, cy - 7, 12, 9);
        dc.fillRectangle(cx - 2, cy - 12, 4, 5);
        // Gun barrel.
        dc.drawLine(cx + 6, cy - 3, cx + 17, cy - 8);
        // Hit splash.
        dc.setColor(0xFF3B47, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 20, cy - 6, 3);
    }

    // Leaderboard is split by AI difficulty (mirrors GameController.lbVariant()).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("bs_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "easy"; }
        if (d == 2) { return "hard"; }
        return "medium";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("winsTotal");
            if (v instanceof Lang.Number && v > 0) { return "WINS " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildBattleshipMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "battleship",
        :title1  => "BATTLESHIP",
        :col1    => 0x32D4FF,
        :bg      => 0x080808,
        :circle  => 0x101418,
        :accent  => 0x44BB22,
        :lbTitle => "BATTLESHIP",
        :hooks   => new BattleshipHooks(),
        :options => [
            new GmOption("bs_diff", "Difficulty", ["EASY", "MEDIUM", "HARD"], 1),
            new GmOption("bs_shots", "Shots", ["SINGLE", "BURST x3"], 0),
            new GmOption("bs_fx", "Sound & Haptics", ["ON", "OFF"], 0),
            // Cosmetic fleet skin — unlocked by naval rank, shop-ready. A
            // locked pick simply renders as the classic hull until owned.
            new GmOption("bs_skin", "Fleet", ["CLASSIC", "NEON", "GOLD"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
