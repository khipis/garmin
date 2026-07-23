// ═══════════════════════════════════════════════════════════════
// VoidRocksMenu.mc — VoidRocks' wiring into the shared unified menu.
//
// MenuConfig (two-line VOID / ROCKS branding, signature ship+asteroid art,
// OPTIONS for Difficulty and starting Lives) plus the GameHooks that launch
// the game and expose the difficulty-split leaderboard variant.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class VoidRocksHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a cyan ship + a grey asteroid + a shot.
    function drawArt(dc, cx, cy, w, h) as Void {
        // Asteroid (grey rock).
        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 10, cy + 2, 7);
        dc.setColor(0x66778A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 12, cy, 2);
        dc.fillCircle(cx + 8,  cy + 5, 2);
        // Ship (cyan triangle pointing up-left toward the rock).
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 6, cy - 9], [cx - 12, cy + 8], [cx, cy + 8]]);
        // Shot.
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 2, cy - 4, 1);
    }

    // Leaderboard variant = difficulty name (matches submitScore in
    // GameController._onPlayerHit: "Easy" / "Normal" / "Hard").
    function lbVariant() as Lang.String {
        var d = VR_DIFF_NORMAL;
        try {
            var v = Application.Storage.getValue(VR_DIFF_KEY);
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        if (d == VR_DIFF_EASY)   { return "Easy";   }
        if (d == VR_DIFF_NORMAL) { return "Normal"; }
        return "Hard";
    }

    // Footer: high score, or null if none yet.
    function footerText() as Lang.String or Null {
        try {
            var b = Application.Storage.getValue(VR_BEST_KEY);
            if (b instanceof Lang.Number && b > 0) { return "BEST " + b.toString(); }
        } catch (e) {}
        return null;
    }
}

function buildVoidRocksMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => VR_LB_GAME_ID,
        :title1  => "VOID",
        :title2  => "ROCKS",
        :col1    => 0x99DDFF,
        :col2    => 0xFFAA22,
        :bg      => 0x000510,
        :circle  => 0x081025,
        :accent  => 0xFFEE66,
        :lbTitle => "VOID ROCKS",
        :hooks   => new VoidRocksHooks(),
        :options => [
            new GmOption(VR_DIFF_KEY,  "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            new GmOption(VR_LIVES_KEY, "Lives", ["1", "2", "3", "4", "5"], 2),
            new GmOption(VR_FX_KEY, "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
