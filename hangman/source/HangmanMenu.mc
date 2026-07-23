// ═══════════════════════════════════════════════════════════════
// HangmanMenu.mc — Hangman's wiring into the shared unified menu.
//
// Builds the MenuConfig (title, colours, gallows emblem, OPTIONS list)
// and the GameHooks that launch a round and expose the category+difficulty
// leaderboard variant.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class HangmanHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a fresh word.
    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature emblem: a tiny gallows with a hanging head.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0xC9B89C, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 16, cy + 14, 32, 3);   // base
        dc.fillRectangle(cx - 12, cy - 16, 3, 30);   // post
        dc.fillRectangle(cx - 12, cy - 16, 20, 3);   // beam
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx + 6, cy - 13, 2, 7);      // rope
        dc.drawCircle(cx + 7, cy - 2, 4);             // head
    }

    // Leaderboard variant = "<category>-<difficulty>" (mirrors
    // GameController.variant()).
    function lbVariant() as Lang.String {
        var c = _read("hm_cat", 0, NUM_CATEGORIES);
        var d = _read("hm_diff", 0, NUM_DIFFICULTIES);
        return WordList.categoryName(c).toLower() + "-"
             + WordList.difficultyName(d).toLower();
    }

    hidden function _read(key, defv, cap) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number && v >= 0 && v < cap) { return v; }
        } catch (e) {}
        return defv;
    }
}

// Factory used by the App's getInitialView().
function buildHangmanMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "hangman",
        :title1  => "HANGMAN",
        :col1    => 0xFFCC22,
        :bg      => 0x080808,
        :circle  => 0x101418,
        :accent  => 0x44BB22,
        :lbTitle => "HANGMAN",
        :hooks   => new HangmanHooks(),
        :options => [
            new GmOption("hm_cat", "Category",
                ["ANIMALS", "FOOD", "TECH", "SPORTS"], 0),
            new GmOption("hm_diff", "Difficulty",
                ["EASY", "MEDIUM", "HARD"], 0),
            new GmOption("hm_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
