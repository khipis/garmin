// ═══════════════════════════════════════════════════════════════
// ArcheryMenu.mc — Archery's wiring into the shared unified menu.
//
// Builds the MenuConfig (title, dusk palette, signature target art,
// OPTIONS list) and the GameHooks that launch the tournament, expose
// the leaderboard variant (difficulty) and a BEST-score footer.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class ArcheryHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a live tournament.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a target roundel with an arrow.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0xE0C054, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 12);
        dc.setColor(0xC03030, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 8);
        dc.setColor(0xF4F0E0, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 4);
        dc.setColor(0xC03030, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 2);
        // Arrow through the bullseye (from lower-left).
        dc.setColor(0xA86430, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx - 28, cy + 18, cx, cy);
        dc.setPenWidth(1);
        dc.setColor(0xE8E8E8, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, cy], [cx - 6, cy + 1], [cx - 3, cy + 6]]);
        dc.setColor(0xD03020, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 28, cy + 18], [cx - 24, cy + 12], [cx - 22, cy + 20]]);
    }

    // Leaderboard is split by difficulty (mirrors GameController.diffName()).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("ar_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "Easy"; }
        if (d == 2) { return "Hard"; }
        return "Norm";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("ar_best");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildArcheryMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "archery",
        :title1  => "ARCHERY",
        :title2  => "TOURNAMENT",
        :col1    => 0xE6B45A,
        :col2    => 0xC09030,
        :bg      => 0x2B1E2E,
        :circle  => 0x241826,
        :accent  => 0xE0B040,
        :lbTitle => "ARCHERY",
        :hooks   => new ArcheryHooks(),
        :options => [
            new GmOption("ar_sens", "Sensitivity", ["LOW", "NORM", "HIGH"], 1),
            new GmOption("ar_diff", "Difficulty", ["EASY", "NORM", "HARD"], 1),
            new GmOption("ar_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
