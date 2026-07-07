// ═══════════════════════════════════════════════════════════════
// ParachuteMenu.mc — Parachute's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class ParachuteHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiParachuteView();
        WatchUi.pushView(v, new BitochiParachuteDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a skydiver descending under a red canopy on taut lines.
    function drawArt(dc, cx, cy, w, h) as Void {
        // canopy dome
        dc.setColor(0xCC1133, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 17, cy + 2], [cx - 11, cy - 9], [cx - 4, cy - 13], [cx + 4, cy - 13], [cx + 11, cy - 9], [cx + 17, cy + 2]]);
        dc.setColor(0xFF3355, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 10, cy], [cx - 6, cy - 9], [cx, cy - 11], [cx - 2, cy]]);
        // suspension lines
        dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 15, cy + 2, cx - 2, cy + 12);
        dc.drawLine(cx + 15, cy + 2, cx + 2, cy + 12);
        dc.drawLine(cx, cy, cx, cy + 11);
        // jumper
        dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy + 12, 3);
        dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx - 3, cy + 15, 6, 6);
    }

    // Leaderboard variant = wind setting (calm/breezy/gusty), matching submit.
    function lbVariant() as Lang.String {
        var names = ["calm", "breezy", "gusty"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("pc_wind");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("paraBest");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildParachuteMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "parachute",
        :title1  => "PARACHUTE",
        :title2  => null,
        :col1    => 0xFFFFFF,
        :bg      => 0x0A1530,
        :circle  => 0x0A1E3A,
        :accent  => 0x44CCFF,
        :lbTitle => "PARACHUTE",
        :hooks   => new ParachuteHooks(),
        :options => [
            new GmOption("pc_wind", "Wind", ["CALM", "BREEZY", "GUSTY"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
