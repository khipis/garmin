// ═══════════════════════════════════════════════════════════════
// MinigolfMenu.mc — Minigolf's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class MinigolfHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiMinigolfView();
        WatchUi.pushView(v, new BitochiMinigolfDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a fairway strip with a golf ball, a cup and its flag.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0x1A6030, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 38, cy - 10, 76, 26, 6);
        // cup
        dc.setColor(0x050A04, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 20, cy + 6, 5);
        // flag pole + flag
        dc.setColor(0x886633, Graphics.COLOR_TRANSPARENT); dc.drawLine(cx + 20, cy + 6, cx + 20, cy - 14);
        dc.setColor(0xFF3311, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx + 20, cy - 14, 12, 8);
        // ball
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 18, cy + 9, 5);
        dc.setColor(0xF8F8F8, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 19, cy + 8, 5);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 21, cy + 6, 2);
    }

    // Leaderboard variant = difficulty (easy/normal/hard), matching submit.
    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("golf_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }
}

function buildMinigolfMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "minigolf",
        :title1  => "MINIGOLF",
        :title2  => null,
        :col1    => 0x44FF88,
        :bg      => 0x0A1A08,
        :circle  => 0x144820,
        :accent  => 0x44FF88,
        :lbTitle => "MINIGOLF",
        :hooks   => new MinigolfHooks(),
        :options => [
            new GmOption("golf_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
