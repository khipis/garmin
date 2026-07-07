// ═══════════════════════════════════════════════════════════════
// ArcadeMenu.mc — Axe Arcade's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Math;

class ArcadeHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiAxeArcadeView();
        WatchUi.pushView(v, new BitochiAxeArcadeDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: the spinning target log with a couple of stuck axes and
    // the little green/red apple — the game's iconic mini-scene.
    function drawArt(dc, cx, cy, w, h) as Void {
        var r = 15;
        // Wooden target log rings.
        dc.setColor(0x6B4226, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r);
        dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r - 3);
        dc.setColor(0xA0723C, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r - 6);
        dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r - 9);
        dc.setColor(0xA0723C, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, 3);
        dc.setColor(0x4A2A11, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, r);

        // Two stuck axes at fixed angles.
        _axe(dc, cx, cy, r, 40.0);
        _axe(dc, cx, cy, r, 200.0);

        // Apple on the rim.
        var ar = 300.0 * 3.14159 / 180.0;
        var apx = cx + (Math.sin(ar) * (r + 3).toFloat()).toNumber();
        var apy = cy - (Math.cos(ar) * (r + 3).toFloat()).toNumber();
        dc.setColor(0x44CC44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(apx, apy, 4);
        dc.setColor(0xDD3333, Graphics.COLOR_TRANSPARENT); dc.fillCircle(apx + 1, apy - 2, 2);
    }

    hidden function _axe(dc, cx, cy, r, deg) as Void {
        var rad = deg * 3.14159 / 180.0;
        var ex = cx + (Math.sin(rad) * r.toFloat()).toNumber();
        var ey = cy - (Math.cos(rad) * r.toFloat()).toNumber();
        var hx = cx + (Math.sin(rad) * (r + 12).toFloat()).toNumber();
        var hy = cy - (Math.cos(rad) * (r + 12).toFloat()).toNumber();
        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT); dc.drawLine(ex, ey, hx, hy);
        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        var eex = cx + (Math.sin(rad) * (r + 20).toFloat()).toNumber();
        var eey = cy - (Math.cos(rad) * (r + 20).toFloat()).toNumber();
        dc.drawLine(hx, hy, eex, eey);
        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT); dc.fillCircle(eex, eey, 2);
    }

    // Leaderboard variant = axe count per level (ax3/ax5/ax7), matching submit.
    function lbVariant() as Lang.String {
        var names = ["ax3", "ax5", "ax7"];
        var i = 1;
        try {
            var v = Application.Storage.getValue("arc_axes");
            if (v instanceof Lang.Number && v >= 0 && v < names.size()) { i = v; }
        } catch (e) {}
        return names[i];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("arcBest");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildArcadeMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "arcade",
        :title1  => "AXE ARCADE",
        :col1    => 0xFF8844,
        :bg      => 0x0E0E1A,
        :circle  => 0x14182A,
        :accent  => 0x34D399,
        :lbTitle => "AXE ARCADE",
        :hooks   => new ArcadeHooks(),
        :options => [
            new GmOption("arc_axes", "Axes", ["3", "5", "7"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
