// ═══════════════════════════════════════════════════════════════
// FlappyMenu.mc — Flappy Pidgeon's wiring into the shared menu.
//
// Builds the MenuConfig (title, colours, signature bird art) and the
// GameHooks that launch a run and expose a BEST-score footer. The
// game has no settings, so OPTIONS only shows the unlock row.
// Leaderboard uses no variant (matches submit "").
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class FlappyHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into the ready-to-flap run.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: the pidgeon itself (reuse the Bird art).
    function drawArt(dc, cx, cy, w, h) as Void {
        var b = new Bird();
        b.reset(cx, cy, 9);
        b.vy = -1.0;
        b.draw(dc);
    }

    // Leaderboard variant = gap size (wide/normal/tight), matching submit.
    function lbVariant() as Lang.String {
        var names = ["wide", "normal", "tight"];
        var i = 1;
        try {
            var v = Application.Storage.getValue("fp_gap");
            if (v instanceof Lang.Number && v >= 0 && v < names.size()) { i = v; }
        } catch (e) {}
        return names[i];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("hi");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildFlappyMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "flappypidgeon",
        :title1  => "FLAPPY",
        :title2  => "PIDGEON",
        :col1    => 0xFFFFFF,
        :col2    => 0xFFCC22,
        :bg      => 0x080808,
        :circle  => 0x101418,
        :accent  => 0x44BB22,
        :lbTitle => "FLAPPY",
        :hooks   => new FlappyHooks(),
        :options => [
            new GmOption("fp_gap", "Gap", ["WIDE", "NORMAL", "TIGHT"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
