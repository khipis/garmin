// ═══════════════════════════════════════════════════════════════
// MinesweeperMenu.mc — Minesweeper's wiring into the shared menu.
//
// Builds the MenuConfig (two-line title, colours, mine emblem, OPTIONS
// = Size + Bombs) and the GameHooks that launch a board, expose the
// board-size leaderboard variant and a best-time footer.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class MinesweeperHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a board.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature emblem: a classic spiky mine with a glint.
    function drawArt(dc, cx, cy, w, h) as Void {
        var rad = 11;
        dc.setColor(0x8890A0, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx - rad - 4, cy, cx + rad + 4, cy);
        dc.drawLine(cx, cy - rad - 4, cx, cy + rad + 4);
        dc.drawLine(cx - rad, cy - rad, cx + rad, cy + rad);
        dc.drawLine(cx - rad, cy + rad, cx + rad, cy - rad);
        dc.setPenWidth(1);
        dc.setColor(0x303840, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, rad);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - rad / 3, cy - rad / 3, 2);
    }

    // Leaderboard variant = board size ("16x16"), mirroring
    // GameController.variantStr().
    function lbVariant() as Lang.String {
        var d = _read("lDiff", 3, DIFF_COUNT);
        var s = GameController.SIZES[d];
        return s.toString() + "x" + s.toString();
    }

    // Best solve time for the current size, if any.
    function footerText() as Lang.String or Null {
        var d = _read("lDiff", 3, DIFF_COUNT);
        try {
            var ms = Application.Storage.getValue(GameController.SKEYS[d]);
            if (ms instanceof Lang.Number && ms > 0) {
                return "BEST " + (ms / 1000).format("%d") + "s";
            }
        } catch (e) {}
        return null;
    }

    hidden function _read(key, defv, cap) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number && v >= 0 && v < cap) { return v; }
        } catch (e) {}
        return defv;
    }
}

// Factory used by the App's getInitialView().
function buildMinesweeperMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "minesweeper",
        :title1  => "MINE",
        :title2  => "SWEEPER",
        :col1    => 0xCC2222,
        :col2    => 0xFFCC22,
        :bg      => 0x080808,
        :circle  => 0x101418,
        :accent  => 0x44BB22,
        :lbTitle => "MINESWEEPER",
        :hooks   => new MinesweeperHooks(),
        :options => [
            new GmOption("lDiff", "Size",
                ["8x8", "10x10", "12x12", "16x16", "24x24", "32x32"], 3),
            new GmOption("lDens", "Bombs",
                ["10%", "15%", "20%", "25%", "30%"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
