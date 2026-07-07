// ═══════════════════════════════════════════════════════════════
// DrwalMenu.mc — Drwal's wiring into the shared unified menu.
//
// Builds the MenuConfig (title, forest palette, signature axe art,
// OPTIONS list) and the GameHooks that launch a run, expose the
// leaderboard variant (difficulty) and a BEST-score footer.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class DrwalHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a live run.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a lumberjack axe.
    function drawArt(dc, cx, cy, w, h) as Void {
        // Handle.
        dc.setColor(0x8A5A2E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 2, cy - 12, 4, 26);
        // Axe head.
        dc.setColor(0xC0C0C8, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx + 2, cy - 13], [cx + 18, cy - 16],
                        [cx + 18, cy - 2], [cx + 2, cy - 5]]);
        dc.setColor(0xE8E8F0, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx + 18, cy - 16, cx + 18, cy - 2);
    }

    // Leaderboard is split by difficulty (mirrors GameController.diffName()).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("dr_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "Easy"; }
        if (d == 2) { return "Hard"; }
        return "Normal";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("dr_hi");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildDrwalMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "drwal",
        :title1  => "DRWAL",
        :col1    => 0xFFCC22,
        :bg      => 0x0B1418,
        :circle  => 0x101A14,
        :accent  => 0x44BB22,
        :lbTitle => "DRWAL",
        :hooks   => new DrwalHooks(),
        :options => [
            new GmOption("dr_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
