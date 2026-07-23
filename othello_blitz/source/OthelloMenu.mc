// ═══════════════════════════════════════════════════════════════
// OthelloMenu.mc — Othello Blitz wiring into the shared menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class OthelloHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new GameView();
        WatchUi.pushView(v, new GameDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a small green board with the four opening discs.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0x1A7A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 16, cy - 16, 32, 32);
        dc.setColor(0x0D5C0D, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, cy - 16, cx, cy + 16);
        dc.drawLine(cx - 16, cy, cx + 16, cy);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 8, cy - 8, 6);
        dc.fillCircle(cx + 8, cy + 8, 6);
        dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 8, cy - 8, 6);
        dc.fillCircle(cx - 8, cy + 8, 6);
    }
    // Othello submits with no variant (disc-count score is global), so the
    // default lbVariant() ("") is correct here.
}

function buildOthelloMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "othello",
        :title1  => "OTHELLO",
        :col1    => 0x1A7A1A,
        :bg      => 0x080808,
        :circle  => 0x0A0A0A,
        :accent  => 0x44CC44,
        :lbTitle => "OTHELLO",
        :hooks   => new OthelloHooks(),
        :options => [
            new GmOption("oth_mode", "Mode",    ["P vs AI", "P vs P", "AI vs AI"], 0),
            new GmOption("oth_diff", "AI level", ["EASY", "MED", "HARD"], 1),
            new GmOption("oth_side", "You play", ["BLACK", "WHITE"], 0),
            new GmOption("oth_fx",   "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
