// ═══════════════════════════════════════════════════════════════
// GemMatchMenu.mc — GemMatch's wiring into the shared unified menu.
//
// Builds the MenuConfig (title, colours, signature gem-cluster art,
// OPTIONS list — mode + the per-mode presets) and the GameHooks that
// launch a game and expose a BEST-score footer. The leaderboard main
// board uses no variant (matches submit "").
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class GemMatchHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a live game.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a little cluster of gems.
    function drawArt(dc, cx, cy, w, h) as Void {
        // Left gem — red diamond.
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 15, cy - 8], [cx - 7, cy], [cx - 15, cy + 8], [cx - 23, cy]]);
        // Right gem — green diamond.
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx + 15, cy - 8], [cx + 23, cy], [cx + 15, cy + 8], [cx + 7, cy]]);
        // Centre gem — blue round.
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 8);
        dc.setColor(0xCCF4FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 2, cy - 2, 2);
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("hi_t");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildGemMatchMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "gemmatch",
        :title1  => "GEM MATCH",
        :col1    => 0xFFCC22,
        :bg      => 0x080808,
        :circle  => 0x101418,
        :accent  => 0x44BB22,
        :lbTitle => "GEM MATCH",
        :hooks   => new GemMatchHooks(),
        :options => [
            new GmOption("gm_mode", "Mode", ["TIME", "ZEN", "MOVES"], 0),
            new GmOption("gm_tidx", "Time", ["30s", "1min", "90s", "2min", "3min"], 2),
            new GmOption("gm_midx", "Moves", ["10", "15", "20", "30"], 2),
            new GmOption("gm_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
