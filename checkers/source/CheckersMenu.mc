// ═══════════════════════════════════════════════════════════════
// CheckersMenu.mc — Checkers' wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class CheckersHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiCheckersView();
        WatchUi.pushView(v, new BitochiCheckersDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a slice of the draughts board with a light and dark piece.
    function drawArt(dc, cx, cy, w, h) as Void {
        var sq = 7;
        var n = 4;
        var x0 = cx - (n * sq) / 2;
        var y0 = cy - (n * sq) / 2;
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                var dark = ((r + c) % 2 == 1);
                dc.setColor(dark ? 0x3A2416 : 0xC8B084, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x0 + c * sq, y0 + r * sq, sq, sq);
            }
        }
        // A dark piece (bottom-left dark square) and a light king-ish piece.
        dc.setColor(0x4A1808, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + sq / 2, y0 + 3 * sq + sq / 2, sq / 2);
        dc.setColor(0xF8F0D0, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x0 + 2 * sq + sq / 2, y0 + sq / 2, sq / 2);
    }

    // Streak leaderboard is submitted per difficulty; match the current one.
    function lbVariant() as Lang.String {
        var names = ["easy", "medium", "hard"];
        try {
            var v = Application.Storage.getValue("checkers_diff");
            if (v instanceof Lang.Number && v >= 0 && v < 3) { return names[v]; }
        } catch (e) {}
        return "medium";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("checkers_streak");
            if (v instanceof Lang.Number && v > 0) { return "STREAK " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildCheckersMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "checkers",
        :title1  => "CHECKERS",
        :col1    => 0xFF6633,
        :bg      => 0x080808,
        :circle  => 0x111111,
        :accent  => 0xFF8833,
        :lbTitle => "CHECKERS",
        :hooks   => new CheckersHooks(),
        :options => [
            new GmOption("checkers_color", "Color",      ["LIGHT", "DARK"],                 0),
            new GmOption("checkers_diff",  "Difficulty", ["EASY", "NORMAL", "HARD"],        1),
            new GmOption("checkers_mode",  "Mode",       ["P vs AI", "P vs P", "AI vs AI"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
