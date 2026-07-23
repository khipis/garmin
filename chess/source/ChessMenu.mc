// ═══════════════════════════════════════════════════════════════
// ChessMenu.mc — Chess's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class ChessHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiChessView();
        WatchUi.pushView(v, new BitochiChessDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a slice of the board with a white and black piece (a pawn
    // silhouette and a knight-ish head) sitting on the light/dark squares.
    function drawArt(dc, cx, cy, w, h) as Void {
        var sq = 7;
        var n = 4;
        var x0 = cx - (n * sq) / 2;
        var y0 = cy - (n * sq) / 2;
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                var dark = ((r + c) % 2 == 1);
                dc.setColor(dark ? 0x5A3A1E : 0xD9C29A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x0 + c * sq, y0 + r * sq, sq, sq);
            }
        }
        // White pawn (top area) and black king piece (bottom area).
        var wx = x0 + 2 * sq + sq / 2;
        var wy = y0 + sq / 2;
        dc.setColor(0xFAF4E8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(wx, wy - 1, 2);
        dc.fillRectangle(wx - 2, wy + 1, 4, 3);
        var bx = x0 + sq / 2;
        var by = y0 + 3 * sq + sq / 2;
        dc.setColor(0x1A0A04, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by - 1, 2);
        dc.fillRectangle(bx - 2, by + 1, 4, 3);
        dc.drawLine(bx, by - 5, bx, by - 2);
    }

    // Streak leaderboard is submitted per difficulty; match the current one.
    function lbVariant() as Lang.String {
        var names = ["easy", "medium", "hard"];
        try {
            var v = Application.Storage.getValue("chess_diff");
            if (v instanceof Lang.Number && v >= 0 && v < 3) { return names[v]; }
        } catch (e) {}
        return "medium";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("chess_streak");
            if (v instanceof Lang.Number && v > 0) { return "STREAK " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildChessMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "chess",
        :title1  => "CHESS",
        :col1    => 0xF0C070,
        :bg      => 0x0A0806,
        :circle  => 0x161008,
        :accent  => 0xF0C070,
        :lbTitle => "CHESS",
        :hooks   => new ChessHooks(),
        :options => [
            new GmOption("chess_color", "Color",      ["WHITE", "BLACK"],                0),
            new GmOption("chess_diff",  "Difficulty", ["EASY", "NORMAL", "HARD"],        1),
            new GmOption("chess_mode",  "Mode",       ["P vs AI", "P vs P", "AI vs AI"], 0),
            new GmOption("chess_fx",    "Sound & Haptics", ["ON", "OFF"],               0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
