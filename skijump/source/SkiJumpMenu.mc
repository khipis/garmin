// ═══════════════════════════════════════════════════════════════
// SkiJumpMenu.mc — Ski Jump's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class SkiJumpHooks extends GameHooks {
    hidden var _venueNames;

    function initialize() {
        GameHooks.initialize();
        _venueNames = ["Zakopane", "Innsbruck", "Oberstdorf", "Vikersund"];
    }

    function startGame() as Void {
        var v = new BitochiJumpView();
        WatchUi.pushView(v, new BitochiJumpDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: the inrun ramp, K/HS flags and a V-style jumper in flight.
    function drawArt(dc, cx, cy, w, h) as Void {
        // inrun ramp
        dc.setColor(0xEAF2F8, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 36, cy - 16], [cx - 4, cy + 4], [cx - 4, cy + 18], [cx - 36, cy + 18]]);
        dc.setColor(0xBBCEDC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 36, cy - 16, cx - 4, cy + 4);
        // landing slope
        dc.setColor(0xDCE8F0, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 4, cy + 4], [cx + 38, cy + 18], [cx + 38, cy + 20], [cx - 4, cy + 18]]);
        // K / HS flags
        dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx + 14, cy + 9, 2, 6);
        dc.setColor(0x33CC33, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx + 26, cy + 12, 2, 6);
        // V-style jumper leaping off the takeoff
        var jx = cx + 2; var jy = cy - 8;
        dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(jx - 3, jy + 3, jx + 12, jy - 4);
        dc.drawLine(jx - 3, jy + 3, jx + 12, jy + 6);
        dc.setColor(0x2266DD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(jx - 3, jy, 5, 5);
        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(jx + 1, jy - 2, 2);
    }

    // Leaderboard is split per hill; open the player's strongest hill (matches
    // the game's own openLeaderboard), defaulting to flagship Vikersund.
    function lbVariant() as Lang.String {
        var bv = 3; var bvD = 0.0;
        for (var i = 0; i < 4; i++) {
            try {
                var v = Application.Storage.getValue("jumpBest" + i);
                if (v != null && v > bvD) { bvD = v; bv = i; }
            } catch (e) {}
        }
        return _venueNames[bv];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("jumpBest");
            if (v != null && v > 0) { return "BEST " + v.toNumber().format("%d") + "m"; }
        } catch (e) {}
        return null;
    }
}

function buildSkiJumpMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "skijump",
        :title1  => "SKI JUMP",
        :title2  => null,
        :col1    => 0xFFFFFF,
        :bg      => 0x0A1420,
        :circle  => 0x0E1C2E,
        :accent  => 0x44AAFF,
        :lbTitle => "SKI JUMP",
        :hooks   => new SkiJumpHooks(),
        :options => [
            new GmOption("sjJumper", "Jumper", ["STOCH", "KRAFT", "LINDVIK", "KOBAYAS", "PREVC", "GRANERUD"], 0),
            new GmOption("sjDiff", "Difficulty", ["EASY", "MID", "HARD"], 2)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
