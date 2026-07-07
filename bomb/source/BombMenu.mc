// ═══════════════════════════════════════════════════════════════
// BombMenu.mc — Bomb's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class BombHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiBombView();
        WatchUi.pushView(v, new BitochiBombDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a little bomber plane, a falling bomb, and a blast on the
    // ground below — the game's core loop in one frame.
    function drawArt(dc, cx, cy, w, h) as Void {
        var px = cx - 8; var py = cy - 12;
        // Plane body + wing
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 14, py - 1, 28, 3);
        dc.setColor(0x3A4A5A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 8, py - 3, 18, 6);
        dc.setColor(0x88BBDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px + 7, py - 1, 2);
        // Falling bomb
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 2, cy + 2, 3);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx + 1, cy - 3, 3, 2);
        // Explosion below
        dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 14, cy + 12, 6);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 14, cy + 12, 4);
        dc.setColor(0xFFFF66, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 14, cy + 12, 2);
    }

    // Leaderboard variant = difficulty (easy/normal/hard), matching submit.
    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var i = 1;
        try {
            var v = Application.Storage.getValue("bomb_diff");
            if (v instanceof Lang.Number && v >= 0 && v < names.size()) { i = v; }
        } catch (e) {}
        return names[i];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("bombBest");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildBombMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "bomb",
        :title1  => "BOMB",
        :col1    => 0xFF4422,
        :bg      => 0x080818,
        :circle  => 0x101A2E,
        :accent  => 0xFF8833,
        :lbTitle => "BOMB",
        :hooks   => new BombHooks(),
        :options => [
            new GmOption("bomb_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
