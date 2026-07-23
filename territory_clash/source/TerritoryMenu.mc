// ═══════════════════════════════════════════════════════════════
// TerritoryMenu.mc — Territory Clash wiring into the shared menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class TerritoryHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new GameView();
        WatchUi.pushView(v, new GameDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a small wooden Go board with black + white stones.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0xC8904C, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 18, cy - 18, 36, 36, 4);
        dc.setColor(0x7A4510, Graphics.COLOR_TRANSPARENT);
        var i = -1;
        while (i <= 1) {
            dc.drawLine(cx + i * 10, cy - 14, cx + i * 10, cy + 14);
            dc.drawLine(cx - 14, cy + i * 10, cx + 14, cy + i * 10);
            i += 1;
        }
        dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 10, cy - 10, 4);
        dc.fillCircle(cx,      cy,      4);
        dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 10, cy - 10, 4);
        dc.fillCircle(cx - 10, cy + 10, 4);
    }

    // Variant = AI difficulty (matches _lbVariant() on submit).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("tc_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "easy"; }
        if (d == 2) { return "hard"; }
        return "med";
    }

    // Footer: current win streak vs AI (0 = hidden).
    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("tclash_streak");
            if (v instanceof Lang.Number && v > 0) { return "STREAK " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildTerritoryMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "territory_clash",
        :title1  => "TERRITORY",
        :title2  => "CLASH",
        :col1    => 0x44BB44,
        :col2    => 0x44BB44,
        :bg      => 0x050D05,
        :circle  => 0x0A180A,
        :accent  => 0x44BB44,
        :lbTitle => "TERRITORY",
        :hooks   => new TerritoryHooks(),
        :options => [
            new GmOption("tc_mode", "Mode",    ["P vs AI", "P vs P", "AI vs AI"], 0),
            new GmOption("tc_diff", "AI level", ["EASY", "MED", "HARD"], 1),
            new GmOption("tc_side", "You play", ["BLACK", "WHITE"], 0),
            new GmOption("tc_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
