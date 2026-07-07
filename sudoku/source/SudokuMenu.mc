// ═══════════════════════════════════════════════════════════════
// SudokuMenu.mc — Sudoku's wiring into the shared unified menu.
//
// MenuConfig (title, colours, signature mini-grid art, OPTIONS list —
// Mode / Difficulty / Errors) plus the GameHooks launching a puzzle and
// exposing the leaderboard variant (board size + difficulty). The main menu
// itself is the shared GameMenuView.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class SudokuHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a small 3x3 grid with a few filled cells.
    function drawArt(dc, cx, cy, w, h) as Void {
        var s = 27; var x0 = cx - 13; var y0 = cy - 13; var c = 9;
        dc.setColor(0x0A1A2E, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0 - 1, y0 - 1, s + 2, s + 2, 3);
        // Filled cells (cyan) suggesting solved digits.
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 + 1,      y0 + 1,      c - 2, c - 2);
        dc.fillRectangle(x0 + c * 2 + 1, y0 + 1,   c - 2, c - 2);
        dc.fillRectangle(x0 + c + 1,  y0 + c + 1,  c - 2, c - 2);
        dc.fillRectangle(x0 + 1,      y0 + c * 2 + 1, c - 2, c - 2);
        // Grid lines.
        dc.setColor(0x2A4A6A, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i <= 3; i++) {
            dc.drawLine(x0 + i * c, y0, x0 + i * c, y0 + s);
            dc.drawLine(x0, y0 + i * c, x0 + s, y0 + i * c);
        }
    }

    // Leaderboard variant = board size + difficulty (mirrors
    // GameController.lbVariant(): "9x9-hard", "4x4-easy", …).
    function lbVariant() as Lang.String {
        var mode = MODE_CLASSIC;
        var diff = DIFF_EASY;
        try {
            var m = Application.Storage.getValue("sk_mode");
            if (m instanceof Lang.Number && m >= 0 && m < 2) { mode = m; }
        } catch (e) {}
        try {
            var d = Application.Storage.getValue("sk_diff");
            if (d instanceof Lang.Number && d >= 0 && d < 3) { diff = d; }
        } catch (e) {}
        var ms = (mode == MODE_QUICK) ? "4x4" : "9x9";
        var ds = (diff == DIFF_EASY) ? "easy" : ((diff == DIFF_MED) ? "medium" : "hard");
        return ms + "-" + ds;
    }
}

function buildSudokuMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => LB_GAME_ID,
        :title1  => "SUDOKU",
        :col1    => 0x44CCFF,
        :bg      => 0x000000,
        :circle  => 0x0A1A2E,
        :accent  => 0x44FF66,
        :lbTitle => "SUDOKU",
        :hooks   => new SudokuHooks(),
        :options => [
            new GmOption("sk_mode", "Mode",   ["QUICK 4x4", "CLASSIC 9x9"], 1),
            new GmOption("sk_diff", "Difficulty", ["EASY", "MEDIUM", "HARD"], 0),
            new GmOption("sk_val",  "Errors", ["RELAX", "STRICT"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
