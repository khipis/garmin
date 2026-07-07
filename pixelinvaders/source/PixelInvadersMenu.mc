// ═══════════════════════════════════════════════════════════════
// PixelInvadersMenu.mc — PixelInvaders' wiring into the shared unified menu.
//
// Builds the MenuConfig (title, colours, signature invader art, OPTIONS list)
// and the GameHooks that launch a run, expose the leaderboard variant. The
// main menu itself is the shared GameMenuView.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class PixelInvadersHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a run.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a little green invader over its cannon.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0x55FF55, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 11, cy - 6, 22, 9);   // body
        dc.fillRectangle(cx - 13, cy - 2, 3, 5);    // left arm
        dc.fillRectangle(cx + 10, cy - 2, 3, 5);    // right arm
        dc.setColor(0x000510, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 6, cy - 3, 3, 3);     // eyes
        dc.fillRectangle(cx + 3, cy - 3, 3, 3);
        dc.setColor(0x55FF55, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 9, cy + 4, 3, 3);     // legs
        dc.fillRectangle(cx + 6, cy + 4, 3, 3);
        dc.setColor(0x55FFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 8, cy + 12, 16, 4);   // cannon base
        dc.fillRectangle(cx - 1, cy + 9, 3, 3);     // turret
    }

    // Leaderboard is split by difficulty (mirrors GameController.difficultyName()).
    function lbVariant() as Lang.String {
        var d = PI_DIFF_NORMAL;
        try {
            var v = Application.Storage.getValue(PI_DIFF_KEY);
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == PI_DIFF_EASY) { return "Easy"; }
        if (d == PI_DIFF_HARD) { return "Hard"; }
        return "Normal";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue(PI_BEST_KEY);
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

// Factory used by the App's getInitialView().
function buildPixelInvadersMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => PI_LB_GAME_ID,
        :title1  => "PIXEL",
        :title2  => "INVADERS",
        :col1    => 0x55FF55,
        :col2    => 0xFF5555,
        :bg      => 0x000308,
        :circle  => 0x06121E,
        :accent  => 0x55FF55,
        :lbTitle => "PIXEL INVADERS",
        :hooks   => new PixelInvadersHooks(),
        :options => [
            new GmOption(PI_DIFF_KEY,  "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            new GmOption(PI_LIVES_KEY, "Lives",      ["1", "2", "3", "4", "5"],  2)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
