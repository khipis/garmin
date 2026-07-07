// ═══════════════════════════════════════════════════════════════
// RunMenu.mc — Monster Run's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class RunHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiRunView();
        WatchUi.pushView(v, new BitochiRunDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a lurking monster's glowing eyes and gnashing teeth in
    // the dark doorway — the horror-chase vibe.
    function drawArt(dc, cx, cy, w, h) as Void {
        // dark maw
        dc.setColor(0x140A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 20, cy - 16, 40, 34);
        // glowing eyes
        dc.setColor(0x660000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 9, cy - 3, 7); dc.fillCircle(cx + 9, cy - 3, 7);
        dc.setColor(0xFFFF33, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 9, cy - 3, 5); dc.fillCircle(cx + 9, cy - 3, 5);
        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 10, cy - 5, 2, 4); dc.fillRectangle(cx + 8, cy - 5, 2, 4);
        // jagged teeth
        dc.setColor(0xDDDDCC, Graphics.COLOR_TRANSPARENT);
        for (var i = -3; i <= 3; i++) {
            var tx = cx + i * 5;
            dc.fillPolygon([[tx - 2, cy + 9], [tx + 2, cy + 9], [tx, cy + 15]]);
        }
    }

    // Leaderboard variant = chase speed (s0/s1/s2), matching submit.
    function lbVariant() as Lang.String {
        var names = ["s0", "s1", "s2"];
        var i = 0;
        try {
            var v = Application.Storage.getValue("run_spd");
            if (v instanceof Lang.Number && v >= 0 && v < names.size()) { i = v; }
        } catch (e) {}
        return names[i];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("br_hs");
            if (v instanceof Lang.Number && v > 0) { return "HI " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildRunMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "run",
        :title1  => "RUN",
        :title2  => null,
        :col1    => 0xFF2222,
        :bg      => 0x080706,
        :circle  => 0x0D0B09,
        :accent  => 0xFF4444,
        :lbTitle => "MONSTER ESC",
        :hooks   => new RunHooks(),
        :options => [
            new GmOption("run_spd", "Speed", ["NORMAL", "FAST", "INSANE"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
