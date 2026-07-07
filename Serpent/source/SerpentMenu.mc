// ═══════════════════════════════════════════════════════════════
// SerpentMenu.mc — Serpent's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Math;
using Toybox.Lang;

class SerpentHooks extends GameHooks {
    hidden var _phase;
    hidden var _pal;

    function initialize() {
        GameHooks.initialize();
        _phase = 0.0;
        _pal = [0x44FF88, 0x33EE77, 0x22CC66, 0x1AAA55, 0x118844, 0x0A6633];
    }

    function startGame() as Void {
        var v = new BitochiSerpentView();
        WatchUi.pushView(v, new BitochiSerpentDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: the animated coiled neon snake from the old menu.
    function drawArt(dc, cx, cy, w, h) as Void {
        _phase += 0.15;
        for (var i = 7; i >= 0; i--) {
            var ang = _phase - i.toFloat() * 0.75;
            var r = 20.0 - i.toFloat() * 1.9;
            var sx = cx + (Math.cos(ang) * r).toNumber();
            var sy = cy + (Math.sin(ang) * r * 0.65).toNumber();
            var ci = i * _pal.size() / 8;
            if (ci >= _pal.size()) { ci = _pal.size() - 1; }
            dc.setColor(_pal[ci], Graphics.COLOR_TRANSPARENT);
            var sz = (i == 7) ? 6 : (4 - i / 3);
            if (sz < 2) { sz = 2; }
            dc.fillCircle(sx, sy, sz);
        }
        // head eye
        var hsx = cx + (Math.cos(_phase) * 20.0).toNumber();
        var hsy = cy + (Math.sin(_phase) * 20.0 * 0.65).toNumber();
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(hsx + 2, hsy - 1, 2);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(hsx + 2, hsy - 1, 1);
    }

    // Leaderboard variant = step rate (slow/normal/fast), matching submit.
    function lbVariant() as Lang.String {
        var names = ["slow", "normal", "fast"];
        var i = 1;
        try {
            var v = Application.Storage.getValue("sp_spd");
            if (v instanceof Lang.Number && v >= 0 && v < names.size()) { i = v; }
        } catch (e) {}
        return names[i];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("serpent_best");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildSerpentMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "serpent",
        :title1  => "SERPENT",
        :title2  => null,
        :col1    => 0x44FF88,
        :bg      => 0x07101C,
        :circle  => 0x0D1E2E,
        :accent  => 0x44FF88,
        :lbTitle => "SERPENT",
        :hooks   => new SerpentHooks(),
        :options => [
            new GmOption("sp_spd", "Speed", ["SLOW", "NORMAL", "FAST"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
