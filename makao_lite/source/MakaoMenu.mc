// ═══════════════════════════════════════════════════════════════
// MakaoMenu.mc — Makao Lite's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class MakaoHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new GameView();
        WatchUi.pushView(v, new GameDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: two overlapping cards, the front showing a red heart.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0x2A5ABB, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 1, cy - 13, 18, 26, 3);
        dc.setColor(0xFCFAF6, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 17, cy - 11, 18, 26, 3);
        dc.setColor(0xCC1111, Graphics.COLOR_TRANSPARENT);
        var hx = cx - 8; var hy = cy + 2;
        dc.fillCircle(hx - 3, hy - 2, 3);
        dc.fillCircle(hx + 3, hy - 2, 3);
        dc.fillPolygon([[hx - 5, hy], [hx, hy + 7], [hx + 5, hy]]);
    }

    // Variant = current AI difficulty (matches _lbVariant() on submit).
    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("mk_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "Easy"; }
        if (d == 2) { return "Hard"; }
        return "Med";
    }
}

function buildMakaoMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "makao_lite",
        :title1  => "MAKAO",
        :title2  => "LITE",
        :col1    => 0x33AA33,
        :col2    => 0x33AA33,
        :bg      => 0x050D05,
        :circle  => 0x0A180A,
        :accent  => 0x34D399,
        :lbTitle => "MAKAO",
        :hooks   => new MakaoHooks(),
        :options => [
            new GmOption("mk_mode", "Mode",     ["P vs AI", "P vs P", "AI vs AI"], 0),
            new GmOption("mk_diff", "AI level",  ["EASY", "MED", "HARD"], 1),
            new GmOption("mk_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
