// ═══════════════════════════════════════════════════════════════
// MoonMenu.mc — Moon Lander's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class MoonHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiMoonView();
        WatchUi.pushView(v, new BitochiMoonDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: the lander hovering over a lit landing pad amid stars.
    function drawArt(dc, cx, cy, w, h) as Void {
        // stars
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 34, cy - 14, 2, 2);
        dc.fillRectangle(cx + 28, cy - 10, 2, 2);
        dc.fillRectangle(cx - 10, cy - 16, 1, 1);
        dc.fillRectangle(cx + 12, cy + 2, 1, 1);
        // landing pad
        dc.setColor(0x556655, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx - 16, cy + 14, 34, 4);
        dc.setColor(0x88FF88, Graphics.COLOR_TRANSPARENT); dc.drawLine(cx - 16, cy + 14, cx + 18, cy + 14);
        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 16, cy + 8, cx - 16, cy + 14);
        dc.drawLine(cx + 18, cy + 8, cx + 18, cy + 14);
        // lander
        var lx = cx; var ly = cy - 8;
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(lx - 7, ly, 14, 8);
        dc.setColor(0x1144AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(lx - 3, ly + 1, 6, 5);
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(lx - 5, ly + 8, lx - 10, ly + 14);
        dc.drawLine(lx + 5, ly + 8, lx + 10, ly + 14);
        dc.setColor(0xFF6600, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[lx - 3, ly + 8], [lx + 3, ly + 8], [lx, ly + 13]]);
    }

    // Leaderboard variant = difficulty (easy/normal/hard), matching submit.
    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("moon_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("moonBest");
            if (v instanceof Lang.Number && v > 0) { return "BEST LV " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildMoonMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "moon",
        :title1  => "MOON",
        :title2  => "LANDER",
        :col1    => 0xFFDD22,
        :col2    => 0x88CCEE,
        :bg      => 0x000814,
        :circle  => 0x030A14,
        :accent  => 0x4AFF8A,
        :lbTitle => "MOON LANDER",
        :hooks   => new MoonHooks(),
        :options => [
            new GmOption("moon_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            // Cosmetic lander hull skin — unlocked by rank, shop-ready. A locked
            // pick simply renders as the classic hull until it's owned.
            new GmOption("moon_hull", "Hull", ["CLASSIC", "NEON", "GOLD"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
