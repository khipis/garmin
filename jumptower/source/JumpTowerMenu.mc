// ═══════════════════════════════════════════════════════════════
// JumpTowerMenu.mc — Jump Tower's wiring into the shared unified menu.
//
// Builds the MenuConfig (two-line title, colours, hopping-frog emblem,
// BEST/coins footer). Jump Tower has no settings, so OPTIONS is empty.
// The leaderboard runs without a variant.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class JumpTowerHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a run.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature emblem: the game's own hopping frog, skinned to the
    // player's lifetime-coin tier.
    function drawArt(dc, cx, cy, w, h) as Void {
        var pl = new Player();
        pl.reset(cx, cy, 9, 11);
        pl.skin = _skinTier();
        pl.draw(dc, cx, cy);
    }

    // Leaderboard variant = difficulty (easy/normal/hard), matching submit.
    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("jt_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }

    // BEST height + lifetime coins — mirrors the old menu stat line.
    function footerText() as Lang.String or Null {
        var s = "";
        var hi = _num("hi");
        if (hi > 0) { s = "BEST " + (hi / 6).format("%d") + "m"; }
        var lc = _num("lifeCoins");
        if (lc > 0) {
            s = (s.length() > 0) ? (s + "  " + lc.format("%d") + "co")
                                 : (lc.format("%d") + " coins");
        }
        return (s.length() > 0) ? s : null;
    }

    hidden function _num(key) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number && v > 0) { return v; }
        } catch (e) {}
        return 0;
    }

    hidden function _skinTier() {
        var lc = _num("lifeCoins");
        if (lc >= 1500) { return 3; }
        if (lc >= 500)  { return 2; }
        if (lc >= 150)  { return 1; }
        return 0;
    }
}

// Factory used by the App's getInitialView().
function buildJumpTowerMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "jumptower",
        :title1  => "JUMP",
        :title2  => "TOWER",
        :col1    => 0x44FFAA,
        :col2    => 0x66CCFF,
        :bg      => 0x080808,
        :circle  => 0x101418,
        :accent  => 0x44BB22,
        :lbTitle => "JUMP TOWER",
        :hooks   => new JumpTowerHooks(),
        :options => [
            new GmOption("jt_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
