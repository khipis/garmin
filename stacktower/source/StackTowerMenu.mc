// ═══════════════════════════════════════════════════════════════
// StackTowerMenu.mc — StackTower's wiring into the shared unified menu.
//
// MenuConfig (title, colours, signature retrowave + mini-tower art, OPTIONS
// list — Difficulty + View mode) plus the GameHooks launching a run, exposing
// the leaderboard variant and best footer. The retrowave vibe is reproduced
// in drawArt. The main menu itself is the shared GameMenuView.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class StackTowerHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: retrowave horizon + a small stacked tower.
    function drawArt(dc, cx, cy, w, h) as Void {
        var horY = cy + 14;
        // Neon horizon line (triple for bloom).
        dc.setColor(0xFF2299, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 38, horY, cx + 38, horY);
        // Converging perspective spokes below the horizon.
        dc.setColor(0x66184A, Graphics.COLOR_TRANSPARENT);
        for (var i = -3; i <= 3; i++) {
            dc.drawLine(cx + i * 13, horY + 8, cx, horY);
        }
        // Mini stacked tower rising above the horizon.
        var palette = [0xFF2244, 0xFFCC00, 0x22FF88, 0x00CCFF];
        for (var j = 0; j < 4; j++) {
            var off = (j % 2 == 0) ? -3 : 3;
            dc.setColor(palette[j], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 12 + off, horY - 6 - j * 6, 24, 5);
        }
    }

    // Leaderboard is split by difficulty (mirrors GameController.diffName()).
    function lbVariant() as Lang.String {
        var d = ST_DIFF_NORM;
        try {
            var v = Application.Storage.getValue(ST_DIFF_KEY);
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == ST_DIFF_SLOW) { return "Slow"; }
        if (d == ST_DIFF_FAST) { return "Fast"; }
        return "Norm";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("hi");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildStackTowerMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => LB_GAME_ID,
        :title1  => "STACK",
        :title2  => "TOWER",
        :col1    => 0xFFCC22,
        :col2    => 0x22DDFF,
        :bg      => 0x03020C,
        :circle  => 0x0E0630,
        :accent  => 0x22FF88,
        :lbTitle => "STACK TOWER",
        :hooks   => new StackTowerHooks(),
        :options => [
            new GmOption(ST_DIFF_KEY, "Difficulty", ["SLOW", "NORM", "FAST"], 1),
            new GmOption(ST_VIEW_KEY, "View",       ["2D", "3D"],             0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
