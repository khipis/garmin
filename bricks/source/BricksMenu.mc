// ═══════════════════════════════════════════════════════════════
// BricksMenu.mc — Bricks' wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class BricksHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiBricksView();
        WatchUi.pushView(v, new BitochiBricksDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a row of coloured bricks, a ball, and the paddle below.
    function drawArt(dc, cx, cy, w, h) as Void {
        var cols = [0x22DDFF, 0x44FF88, 0xFFFF44, 0xFF9944, 0xFF44AA];
        var bw = 9; var bh = 5;
        var x0 = cx - (cols.size() * bw) / 2;
        for (var i = 0; i < cols.size(); i++) {
            dc.setColor(cols[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0 + i * bw + 1, cy - 12, bw - 2, bh);
        }
        // Ball
        dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 4, cy + 2, 3);
        // Paddle
        dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 12, cy + 10, 24, 4, 2);
    }

    // Leaderboard variant = difficulty (easy/normal/hard), matching submit.
    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("br_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("bricksBest");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildBricksMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "bricks",
        :title1  => "BRICKS",
        :col1    => 0x44AAFF,
        :bg      => 0x060C18,
        :circle  => 0x0C1828,
        :accent  => 0x44AAFF,
        :lbTitle => "BRICKS",
        :hooks   => new BricksHooks(),
        :options => [
            new GmOption("br_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
