// ═══════════════════════════════════════════════════════════════
// GobbletMenu.mc — Gobblet Mini's wiring into the shared menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class GobbletHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new GameView();
        WatchUi.pushView(v, new GameDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a big piece gobbling a smaller one (nested circles).
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 12, cy, 8);
        dc.setColor(0x06060E, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 12, cy, 3);
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 10, cy, 15);
        dc.setColor(0x06060E, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 10, cy, 6);
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 10, cy, 4);
    }

    // Variant = current AI difficulty (matches _lbVariant() on submit — lowercase).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("gob_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "easy"; }
        if (d == 2) { return "hard"; }
        return "med";
    }
}

function buildGobbletMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "gobblet_mini",
        :title1  => "GOBBLET",
        :title2  => "MINI",
        :col1    => 0xFFAA00,
        :col2    => 0xFFAA00,
        :bg      => 0x080808,
        :circle  => 0x0C0C0C,
        :accent  => 0x34D399,
        :lbTitle => "GOBBLET",
        :hooks   => new GobbletHooks(),
        :options => [
            new GmOption("gob_mode", "Mode",     ["P vs AI", "P vs P", "AI vs AI"], 0),
            new GmOption("gob_diff", "AI level",  ["EASY", "MED", "HARD"], 1),
            new GmOption("gob_side", "You play",  ["LIGHT", "DARK"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
