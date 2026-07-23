// ═══════════════════════════════════════════════════════════════
// HexMenu.mc — Hex Mini's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class HexHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new GameView();
        WatchUi.pushView(v, new GameDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a small parallelogram of red/blue hex stones.
    function drawArt(dc, cx, cy, w, h) as Void {
        var ox = cx - 16; var oy = cy - 12;
        for (var r = 0; r < 3; r++) {
            for (var c = 0; c < 3; c++) {
                var px = ox + c * 12 + r * 6;
                var py = oy + r * 12;
                var col = ((r + c) % 2 == 0) ? 0xFF2200 : 0x0099FF;
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 4);
            }
        }
    }

    // Variant = current AI difficulty (matches _variantName() on submit — uppercase).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("hex_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "EASY"; }
        if (d == 2) { return "HARD"; }
        return "MED";
    }
}

function buildHexMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "hex_mini",
        :title1  => "HEX",
        :title2  => "MINI",
        :col1    => 0xFF4422,
        :col2    => 0xFF4422,
        :bg      => 0x080810,
        :circle  => 0x0A0A18,
        :accent  => 0x34D399,
        :lbTitle => "HEX MINI",
        :hooks   => new HexHooks(),
        :options => [
            new GmOption("hex_mode", "Mode",     ["P vs AI", "P vs P", "AI vs AI"], 0),
            new GmOption("hex_diff", "AI level",  ["EASY", "MED", "HARD"], 1),
            new GmOption("hex_side", "You play",  ["RED", "BLUE"], 0),
            new GmOption("hex_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
