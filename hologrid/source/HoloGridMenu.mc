// ═══════════════════════════════════════════════════════════════
// HoloGridMenu.mc — HoloGrid's wiring into the shared unified menu.
//
// Builds the MenuConfig (title, colours, grid emblem, OPTIONS list) and
// the GameHooks that launch the run. The leaderboard has no variant.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class HoloGridHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a run.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature emblem: a little 3×3 grid with a cyan runner and green exit.
    function drawArt(dc, cx, cy, w, h) as Void {
        var cs = 12;
        var gx = cx - cs * 3 / 2;
        var gy = cy - cs * 3 / 2;
        for (var r = 0; r < 3; r++) {
            for (var c = 0; c < 3; c++) {
                var x = gx + c * cs;
                var y = gy + r * cs;
                dc.setColor(0x081428, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y, cs, cs);
                dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(x, y, cs, cs);
            }
        }
        // Exit (top-right).
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(gx + cs * 2 + 2, gy + 2, cs - 4, cs - 4);
        // Runner (bottom-left).
        dc.setColor(0x55EEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(gx + cs / 2, gy + cs * 2 + cs / 2, cs * 4 / 10);
    }
}

// Factory used by the App's getInitialView().
function buildHoloGridMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "hologrid",
        :title1  => "HOLOGRID",
        :col1    => 0x44CCFF,
        :bg      => 0x040A14,
        :circle  => 0x081428,
        :accent  => 0x33FFEE,
        :lbTitle => "HOLOGRID",
        :hooks   => new HoloGridHooks(),
        :options => [
            new GmOption("hg_slvl", "Start Level",
                ["1", "5", "10", "15", "20", "25", "30"], 0),
            new GmOption("hg_lives", "Lives",
                ["1", "2", "3", "4", "5"], 2)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
