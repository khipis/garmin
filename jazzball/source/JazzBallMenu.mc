// ═══════════════════════════════════════════════════════════════
// JazzBallMenu.mc — JazzBall's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class JazzBallHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiJazzBallView();
        WatchUi.pushView(v, new BitochiJazzBallDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: colourful balls bouncing inside a partly-walled box.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0x2A3D66, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(cx - 32, cy - 16, 64, 34);
        dc.drawRectangle(cx - 31, cy - 15, 62, 32);
        // captured (walled-off) corner
        dc.fillRectangle(cx - 30, cy - 14, 18, 12);
        // bouncing balls
        _ball(dc, cx - 2, cy - 2, 0xFF4422);
        _ball(dc, cx + 15, cy + 8, 0x44FF88);
        _ball(dc, cx + 3, cy + 10, 0x44AAFF);
    }

    hidden function _ball(dc, x, y, col) as Void {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(x + 1, y + 1, 4);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillCircle(x, y, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(x - 1, y - 1, 1);
    }

    // Leaderboard variant = difficulty (easy/normal/hard), matching submit.
    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("jb_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("jb_best");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildJazzBallMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "jazzball",
        :title1  => "JAZZBALL",
        :title2  => null,
        :col1    => 0x44AAFF,
        :bg      => 0x060810,
        :circle  => 0x0C1220,
        :accent  => 0x44FF88,
        :lbTitle => "JAZZBALL",
        :hooks   => new JazzBallHooks(),
        :options => [
            new GmOption("jb_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            new GmOption("jb_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
