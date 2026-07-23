// ═══════════════════════════════════════════════════════════════
// BoxingMenu.mc — Boxing's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class BoxingHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiBoxingView();
        WatchUi.pushView(v, new BitochiBoxingDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: the two boxers squaring off, red vs blue, with a gold "VS".
    function drawArt(dc, cx, cy, w, h) as Void {
        _boxer(dc, cx - 22, cy + 4, 0xDD4444, true);
        _boxer(dc, cx + 22, cy + 4, 0x4444DD, false);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 6, Graphics.FONT_XTINY, "VS", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _boxer(dc, cx, cy, col, left) as Void {
        var hr = 5;
        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy - hr * 2, hr);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx - hr, cy, hr * 2, hr * 2);
        var d = left ? 1 : -1;
        dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + d * hr * 2, cy - hr, 3);
    }

    // Leaderboard variant = difficulty (easy/normal/hard), matching submit.
    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var i = 1;
        try {
            var v = Application.Storage.getValue("box_diff");
            if (v instanceof Lang.Number && v >= 0 && v < names.size()) { i = v; }
        } catch (e) {}
        return names[i];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("boxBest");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildBoxingMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "boxing",
        :title1  => "BOXING",
        :col1    => 0xFF4444,
        :bg      => 0x0A0A14,
        :circle  => 0x141428,
        :accent  => 0x44FF44,
        :lbTitle => "BOXING",
        :hooks   => new BoxingHooks(),
        :options => [
            new GmOption("box_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            // Cosmetic trunk skin — unlocked at rank 3, shop-ready. A locked pick
            // simply renders as the classic blue trunks until it's owned.
            new GmOption("box_skin", "Trunks", ["CLASSIC", "NEON"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
