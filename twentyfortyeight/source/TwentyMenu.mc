// ═══════════════════════════════════════════════════════════════
// TwentyMenu.mc — 2048's wiring into the shared unified menu.
//
// MenuConfig (gold "2048" tile branding, signature 2x2 mini-board art,
// a single Mode OPTION — Classic / Time speedrun) plus the GameHooks that
// launch the board and expose the best-score footer.
//
// Note: the leaderboard has TWO backend ids (classic score vs. 2048 time).
// The shared menu's LEADERBOARD row always opens the Classic board; the
// correct per-mode board is still shown in-game via showPostGame().
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class TwentyHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a small 2x2 board of classic 2048 tiles.
    function drawArt(dc, cx, cy, w, h) as Void {
        var s = 30; var x0 = cx - 15; var y0 = cy - 15;
        var pad = 2; var cell = (s - pad * 3) / 2;
        dc.setColor(0xBBADA0, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0, y0, s, s, 4);
        var cols = [0xEEE4DA, 0xEDE0C8, 0xF2B179, 0xF59563];
        var k = 0;
        for (var r = 0; r < 2; r++) {
            for (var c = 0; c < 2; c++) {
                var tx = x0 + pad + c * (cell + pad);
                var ty = y0 + pad + r * (cell + pad);
                dc.setColor(cols[k], Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(tx, ty, cell, cell, 2);
                k++;
            }
        }
    }

    // Footer: overall best score (Classic), or null if none yet.
    function footerText() as Lang.String or Null {
        try {
            var b = Application.Storage.getValue("best");
            if (b instanceof Lang.Number && b > 0) { return "BEST " + b.toString(); }
        } catch (e) {}
        return null;
    }
}

function buildTwentyMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => LB_GAME_ID,
        :title1  => "2048",
        :col1    => 0xEDC22E,
        :bg      => 0x080808,
        :circle  => 0x101418,
        :accent  => 0xEDC22E,
        :lbTitle => "2048",
        :hooks   => new TwentyHooks(),
        :options => [
            new GmOption("tf_timemode", "Mode", ["CLASSIC", "TIME"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
