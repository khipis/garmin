// ═══════════════════════════════════════════════════════════════
// ManpacMenu.mc — Manpac's wiring into the shared unified menu.
//
// Builds the MenuConfig (title, colours, Pac-Man emblem, OPTIONS =
// Start Level / Lives / Speed) and the GameHooks that launch a run.
// The leaderboard runs without a variant.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class ManpacHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a run.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature emblem: Pac-Man chomping a couple of pellets.
    function drawArt(dc, cx, cy, w, h) as Void {
        var rad = 13;
        var px  = cx - 8;
        dc.setColor(0xFFE100, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, cy, rad);
        // Bite wedge (background colour) opening toward the pellets.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[px, cy], [px + rad, cy - rad / 2], [px + rad, cy + rad / 2]]);
        // Pellets.
        dc.setColor(0xFFE680, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 11, cy, 2);
        dc.fillCircle(cx + 19, cy, 2);
    }
}

// Factory used by the App's getInitialView().
function buildManpacMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "manpac",
        :title1  => "MANPAC",
        :col1    => 0xFFE100,
        :bg      => 0x000000,
        :circle  => 0x000814,
        :accent  => 0xFFE100,
        :lbTitle => "MANPAC",
        :hooks   => new ManpacHooks(),
        :options => [
            new GmOption("mp_slvl", "Start Level",
                ["1", "2", "3", "4", "5", "6", "7", "8", "9"], 0),
            new GmOption("mp_lives", "Lives", ["1", "2", "3", "4", "5"], 2),
            new GmOption("mp_speed", "Speed", ["SLOW", "NORM", "FAST"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
