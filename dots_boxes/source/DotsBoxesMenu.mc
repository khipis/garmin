// ═══════════════════════════════════════════════════════════════
// DotsBoxesMenu.mc — Dots & Boxes' wiring into the shared menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class DotsBoxesHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new GameView();
        WatchUi.pushView(v, new GameDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a mini dot grid with one completed box.
    function drawArt(dc, cx, cy, w, h) as Void {
        var s = 14;
        dc.setColor(0x220500, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - s, cy - s, s, s);
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - s, cy - s, cx,     cy - s);   // top
        dc.drawLine(cx - s, cy - s, cx - s, cy);       // left
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx,     cy - s, cx,     cy);        // right
        dc.drawLine(cx - s, cy,     cx,     cy);        // bottom
        dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - s / 2, cy - s / 2, 3);
        dc.setColor(0x8888A0, Graphics.COLOR_TRANSPARENT);
        for (var r = 0; r < 3; r++) {
            for (var c = 0; c < 3; c++) {
                dc.fillCircle(cx - s + c * s, cy - s + r * s, 2);
            }
        }
    }

    // Variant = current AI difficulty (matches lbVariant() on submit — lowercase).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("db_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "easy"; }
        if (d == 2) { return "hard"; }
        return "med";
    }
}

function buildDotsBoxesMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "dots_boxes",
        :title1  => "DOTS &",
        :title2  => "BOXES",
        :col1    => 0xFF3355,
        :col2    => 0xFF3355,
        :bg      => 0x080808,
        :circle  => 0x0C0C0C,
        :accent  => 0x34D399,
        :lbTitle => "DOTS & BOXES",
        :hooks   => new DotsBoxesHooks(),
        :options => [
            new GmOption("db_mode", "Mode",     ["P vs AI", "P vs P", "AI vs AI"], 0),
            new GmOption("db_diff", "AI level",  ["EASY", "MED", "HARD"], 1),
            new GmOption("db_side", "You play",  ["1ST", "2ND"], 0),
            new GmOption("db_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
