// ═══════════════════════════════════════════════════════════════
// LightsOutMenu.mc — Lights Out's wiring into the shared unified menu.
//
// Builds the MenuConfig (two-line title, colours, bulb-grid emblem,
// OPTIONS = Difficulty + Mode) and the GameHooks that launch a puzzle,
// expose the board-size leaderboard variant and a best/streak footer.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class LightsOutHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a puzzle.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature emblem: a mini 3×3 lights-out grid, some bulbs lit.
    function drawArt(dc, cx, cy, w, h) as Void {
        var s = 13;
        var gx = cx - s * 3 / 2;
        var gy = cy - s * 3 / 2;
        // Fixed lit pattern (a small plus) for a recognisable look.
        var lit = [0, 1, 0, 1, 1, 1, 0, 1, 0];
        for (var r = 0; r < 3; r++) {
            for (var c = 0; c < 3; c++) {
                var ccx = gx + c * s + s / 2;
                var ccy = gy + r * s + s / 2;
                if (lit[r * 3 + c] == 1) {
                    dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(ccx, ccy, s / 2 - 2);
                } else {
                    dc.setColor(0x33455A, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(ccx, ccy, s / 2 - 2);
                }
            }
        }
    }

    // Leaderboard variant = board size ("3x3"/"4x4"/"5x5"), mirroring
    // GameController.boardVariant().
    function lbVariant() as Lang.String {
        var mode = _read("lo_mode", 0);
        var n;
        if (mode == LO_MODE_DAILY) {
            n = LevelGenerator.gridSizeForDiff(_read("lo_diff", 1));
        } else {
            var lvl = _read("lo_level", 1);
            if (lvl < 1) { lvl = 1; }
            n = LevelGenerator.gridSizeForLevel(lvl);
        }
        return n.format("%d") + "x" + n.format("%d");
    }

    // Best-of-level / daily-best footer — mirrors the old menu subtitle.
    function footerText() as Lang.String or Null {
        var mode = _read("lo_mode", 0);
        if (mode == LO_MODE_DAILY) {
            var bd = _read("lo_daily_best", -1);
            if (bd >= 0) { return "DAILY BEST " + bd.format("%d") + " mv"; }
            var st = _read("lo_streak", 0);
            return (st > 0) ? ("DAILY STREAK " + st.format("%d")) : null;
        }
        var lvl = _read("lo_level", 1);
        var b = _read("lo_best_lvl_" + lvl.format("%d"), -1);
        if (b >= 0) { return "LVL BEST " + b.format("%d") + " mv"; }
        var solved = _read("lo_solved_total", 0);
        return (solved > 0) ? ("SOLVED " + solved.format("%d")) : null;
    }

    hidden function _read(key, defv) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number) { return v; }
        } catch (e) {}
        return defv;
    }
}

// Factory used by the App's getInitialView().
function buildLightsOutMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "lightsout",
        :title1  => "LIGHTS",
        :title2  => "OUT",
        :col1    => 0xFFCC22,
        :col2    => 0xFFEE66,
        :bg      => 0x000308,
        :circle  => 0x081020,
        :accent  => 0xFFEE66,
        :lbTitle => "LIGHTS OUT",
        :hooks   => new LightsOutHooks(),
        :options => [
            new GmOption("lo_diff", "Difficulty",
                ["EASY 3x3", "MED 4x4", "HARD 5x5"], 1),
            new GmOption("lo_mode", "Mode", ["LEVELS", "DAILY"], 0),
            new GmOption("lo_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
