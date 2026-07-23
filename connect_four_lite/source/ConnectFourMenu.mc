// ═══════════════════════════════════════════════════════════════
// ConnectFourMenu.mc — Connect Four's wiring into the shared menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class ConnectFourHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new GameView();
        WatchUi.pushView(v, new GameDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a mini board slab with red + yellow discs.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0x0A1850, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 21, cy - 14, 42, 28, 4);
        var r = 5;
        dc.setColor(0x101028, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 12, cy - 6, r);
        dc.fillCircle(cx,      cy - 6, r);
        dc.fillCircle(cx + 12, cy - 6, r);
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 12, cy + 6, r);
        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx,      cy + 6, r);
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 12, cy + 6, r);
    }

    // Variant = current AI difficulty (matches _variant() on submit).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("cf_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "Easy"; }
        if (d == 2) { return "Hard"; }
        return "Med";
    }
}

function buildConnectFourMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "connectfour",
        :title1  => "CONNECT",
        :title2  => "FOUR",
        :col1    => 0xFF2200,
        :col2    => 0xFF2200,
        :bg      => 0x060610,
        :circle  => 0x06060E,
        :accent  => 0x34D399,
        :lbTitle => "CONNECT FOUR",
        :hooks   => new ConnectFourHooks(),
        :options => [
            new GmOption("cf_mode", "Mode",     ["P vs AI", "P vs P", "AI vs AI"], 0),
            new GmOption("cf_diff", "AI level",  ["EASY", "MED", "HARD"], 1),
            new GmOption("cf_side", "You play",  ["RED", "YELLOW"], 0),
            new GmOption("cf_fx",   "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
