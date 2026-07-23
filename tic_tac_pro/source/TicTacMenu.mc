// ═══════════════════════════════════════════════════════════════
// TicTacMenu.mc — Tic-Tac Pro's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class TicTacHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new GameView();
        WatchUi.pushView(v, new GameDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a mini 3×3 grid with an X and an O.
    function drawArt(dc, cx, cy, w, h) as Void {
        var s = 12;                       // half grid size
        dc.setColor(0x2A3A55, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - s / 3, cy - s, cx - s / 3, cy + s);
        dc.drawLine(cx + s / 3, cy - s, cx + s / 3, cy + s);
        dc.drawLine(cx - s, cy - s / 3, cx + s, cy - s / 3);
        dc.drawLine(cx - s, cy + s / 3, cx + s, cy + s / 3);
        // X in the top-left cell.
        dc.setColor(0x00AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - s + 2, cy - s + 2, cx - s / 3 - 2, cy - s / 3 - 2);
        dc.drawLine(cx - s / 3 - 2, cy - s + 2, cx - s + 2, cy - s / 3 - 2);
        // O in the bottom-right cell.
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx + s * 2 / 3, cy + s * 2 / 3, s / 3);
    }

    function lbVariant() as Lang.String {
        var d = 1;
        try {
            var v = Application.Storage.getValue("ttp_diff");
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == 0) { return "Easy"; }
        if (d == 2) { return "Hard"; }
        return "Med";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("tictacpro_streak");
            if (v instanceof Lang.Number && v > 0) { return "STREAK " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildTicTacMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "tictacpro",
        :title1  => "TIC TAC",
        :title2  => "PRO",
        :col1    => 0x00AAFF,
        :col2    => 0x00AAFF,
        :bg      => 0x080810,
        :circle  => 0x0A0A18,
        :accent  => 0x34D399,
        :lbTitle => "TIC-TAC PRO",
        :hooks   => new TicTacHooks(),
        :options => [
            new GmOption("ttp_mode", "Mode",  ["P vs AI", "P vs P", "AI vs AI"], 0),
            new GmOption("ttp_diff", "AI level", ["EASY", "MED", "HARD"], 1),
            new GmOption("ttp_grid", "Board",
                ["3x3", "4x4", "5x5", "6x6", "7x7", "CUBE 2", "CUBE 3", "CUBE 4"], 2),
            new GmOption("ttp_side", "You play", ["X (1st)", "O (2nd)"], 0),
            new GmOption("ttp_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
