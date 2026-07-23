// ═══════════════════════════════════════════════════════════════
// EdgeSurvivorMenu.mc — Edge Survivor's wiring into the shared menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class EdgeSurvivorHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new GameView();
        WatchUi.pushView(v, new GameDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: the edge circle with the player dot + an inbound bullet.
    function drawArt(dc, cx, cy, w, h) as Void {
        var r = 20;
        dc.setColor(0x1A2A5A, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        dc.drawCircle(cx, cy, r - 1);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 2);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - r, 4);
        dc.setColor(0x7799FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - r, 2);
        dc.setColor(0xFF3311, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 8, cy + 6, 3);
    }

    // Leaderboard variant = difficulty (easy/normal/hard), matching submit.
    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("es_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }

    // Best score footer (matches the old title's "best NNNNN").
    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("hi");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%05d"); }
        } catch (e) {}
        return null;
    }
}

function buildEdgeSurvivorMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "edgesurvivor",
        :title1  => "EDGE",
        :title2  => "SURVIVOR",
        :col1    => 0x2255CC,
        :col2    => 0xCC2222,
        :bg      => 0x000000,
        :circle  => 0x0A0A12,
        :accent  => 0x44BB22,
        :lbTitle => "EDGE SURVIVOR",
        :hooks   => new EdgeSurvivorHooks(),
        :options => [
            new GmOption("es_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            // Cosmetic player skin — unlocked by rank, shop-ready. A locked
            // pick simply renders as the classic dot until it's owned.
            new GmOption("es_skin", "Skin", ["CLASSIC", "NEON", "GOLD"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
