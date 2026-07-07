// ═══════════════════════════════════════════════════════════════
// CatapultMenu.mc — Catapult's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class CatapultHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiCatapultView();
        WatchUi.pushView(v, new BitochiCatapultDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a catapult firing a boulder in an arc toward a castle.
    function drawArt(dc, cx, cy, w, h) as Void {
        var groundY = cy + 14;
        // Catapult base + arm (left)
        dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 22, groundY - 4, 10, 4);
        dc.setColor(0xA9713B, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx - 20, groundY - 4, cx - 12, groundY - 14);
        dc.setPenWidth(1);
        // Boulder arc
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 4, cy - 10, 3);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 12, cy - 4, 2);
        dc.fillCircle(cx + 4, cy - 10, 2);
        // Castle (right)
        dc.setColor(0x99AABB, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx + 12, groundY - 12, 12, 12);
        dc.fillRectangle(cx + 12, groundY - 15, 3, 4);
        dc.fillRectangle(cx + 17, groundY - 15, 3, 4);
        dc.fillRectangle(cx + 22, groundY - 15, 2, 4);
    }

    // Leaderboard variant = difficulty (easy/normal/hard), matching submit.
    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("cat_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("catBest");
            if (v instanceof Lang.Number && v > 0 && v < 99) {
                return "BEST " + v.format("%d") + " SHOTS";
            }
        } catch (e) {}
        return null;
    }
}

function buildCatapultMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "catapult",
        :title1  => "CATAPULT",
        :col1    => 0xFFAA33,
        :bg      => 0x0A1428,
        :circle  => 0x14263E,
        :accent  => 0x44BB22,
        :lbTitle => "CATAPULT",
        :hooks   => new CatapultHooks(),
        :options => [
            new GmOption("cat_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
