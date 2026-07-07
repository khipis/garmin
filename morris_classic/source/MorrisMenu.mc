// ═══════════════════════════════════════════════════════════════
// MorrisMenu.mc — Nine Men's Morris' wiring into the shared menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class MorrisHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new GameView();
        WatchUi.pushView(v, new GameDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: the three concentric-squares Morris board with 2 stones.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(cx - 18, cy - 18, 36, 36);
        dc.drawRectangle(cx - 12, cy - 12, 24, 24);
        dc.drawRectangle(cx - 6,  cy - 6,  12, 12);
        dc.drawLine(cx, cy - 18, cx, cy - 6);
        dc.drawLine(cx, cy + 6,  cx, cy + 18);
        dc.drawLine(cx - 18, cy, cx - 6, cy);
        dc.drawLine(cx + 6,  cy, cx + 18, cy);
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 18, cy - 18, 3);
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 18, cy + 18, 3);
    }

    // Variant = current AI difficulty (matches _lbVariant() on submit — lowercase).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("mor_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "easy"; }
        if (d == 2) { return "hard"; }
        return "med";
    }
}

function buildMorrisMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "morris_classic",
        :title1  => "MORRIS",
        :col1    => 0xFF6622,
        :bg      => 0x080810,
        :circle  => 0x0A0A18,
        :accent  => 0x34D399,
        :lbTitle => "MORRIS",
        :hooks   => new MorrisHooks(),
        :options => [
            new GmOption("mor_mode", "Mode",     ["P vs AI", "P vs P", "AI vs AI"], 0),
            new GmOption("mor_diff", "AI level",  ["EASY", "MED", "HARD"], 1),
            new GmOption("mor_side", "You play",  ["1ST", "2ND"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
