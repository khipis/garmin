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

    // Signature mini-graphic: an axe buried in a chopping log, chips flying.
    function drawArt(dc, cx, cy, w, h) as Void {
        // Log lying on its side.
        dc.setColor(0x7A4A24, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 22, cy + 4, 44, 13, 3);
        dc.setColor(0x9A6636, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 22, cy + 4, 44, 3);
        dc.setColor(0xB98A54, Graphics.COLOR_TRANSPARENT);   // end-grain rings
        dc.fillCircle(cx - 20, cy + 10, 4);
        dc.setColor(0x7A4A24, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 20, cy + 10, 2);

        // Axe handle at an angle, head bitten into the log.
        dc.setColor(0x8A5A2E, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx + 16, cy - 18], [cx + 20, cy - 16],
                        [cx + 4, cy + 5], [cx, cy + 3]]);
        dc.setColor(0xC8C8D0, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 6, cy - 2], [cx + 6, cy - 8],
                        [cx + 9, cy + 2], [cx - 2, cy + 6]]);
        dc.setColor(0xEDEDF4, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 6, cy - 2, cx - 2, cy + 6);

        // Wood chips.
        dc.setColor(0xE0C070, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 26, cy - 6, 3, 3);
        dc.fillRectangle(cx + 22, cy - 10, 3, 3);
        dc.fillRectangle(cx - 14, cy - 12, 2, 2);
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
            new GmOption("dr_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            new GmOption("dr_fx", "Sound & Haptics", ["ON", "OFF"], 0),
            // Cosmetic axe skin — escalates the chop FX only. Unlocked by rank
            // (Iron @ Lv3, Golden @ Lv6), shop-ready. A locked pick simply
            // renders as the default Oak axe until it's owned.
            new GmOption("dr_axe", "Axe", ["OAK", "IRON", "GOLD"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
