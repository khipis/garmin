// ═══════════════════════════════════════════════════════════════
// FishMenu.mc — Fishing's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class FishHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiFishView();
        WatchUi.pushView(v, new BitochiFishDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a little scenic lake — low sun, a wavy waterline and a
    // couple of fish gliding beneath it, echoing the game's whole-screen scene.
    function drawArt(dc, cx, cy, w, h) as Void {
        // sun
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 30, cy - 12, 7);
        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 30, cy - 12, 4);
        // water band
        var wy = cy + 2;
        dc.setColor(0x165688, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx - 40, wy, 80, 20);
        dc.setColor(0x2475AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx - 40, wy, 80, 3);
        // two swimming fish
        _fish(dc, cx - 12, wy + 9, 6, 1, 0x44CC55);
        _fish(dc, cx + 18, wy + 14, 5, -1, 0xEE8855);
    }

    hidden function _fish(dc, x, y, sz, dir, col) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, sz);
        dc.fillCircle(x + dir * sz * 6 / 10, y, sz * 7 / 10);
        dc.fillCircle(x - dir * (sz + 2), y - sz / 3, sz / 3);
        dc.fillCircle(x - dir * (sz + 2), y + sz / 3, sz / 3);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + dir * (sz - 1), y - 1, 1);
    }

    // Leaderboard variant = difficulty (easy/normal/hard), matching submit.
    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("fish_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }

    // Fish has THREE global boards, so the LEADERBOARD row opens a small picker
    // (Top Scores · Biggest Fish · Progress) instead of a single board.
    function openBoard() as Lang.Boolean {
        try {
            var m = new FishBoardPicker(lbVariant());
            WatchUi.pushView(m, new FishBoardPickerDelegate(lbVariant()), WatchUi.SLIDE_UP);
            return true;
        } catch (e) {
            return false;
        }
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("fishBest");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

// ── Leaderboard category picker ──────────────────────────────────────────────
// Fish keeps three separate global boards. This little menu lets the player
// choose which one to view; each opens the shared LbScoresView with the right
// variant + title.
class FishBoardPicker extends WatchUi.Menu2 {
    function initialize(scoreVariant as Lang.String) {
        Menu2.initialize({:title => "LEADERBOARDS"});
        addItem(new WatchUi.MenuItem("Top Scores",   "Session points", :scores,   null));
        addItem(new WatchUi.MenuItem("Biggest Fish", "Heaviest catch", :biggest,  null));
        addItem(new WatchUi.MenuItem("Progress",     "Level reached",  :progress, null));
    }
}

class FishBoardPickerDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _scoreVariant;
    function initialize(scoreVariant as Lang.String) {
        Menu2InputDelegate.initialize();
        _scoreVariant = scoreVariant;
    }
    function onSelect(item) {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        var variant; var title;
        if (id == :biggest)       { variant = "biggest-fish"; title = "BIGGEST FISH"; }
        else if (id == :progress) { variant = "progress";     title = "PROGRESS"; }
        else                      { variant = _scoreVariant;  title = "FISHING"; }
        try {
            var v = new LbScoresView("fish", variant, title);
            WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }
}

function buildFishMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "fish",
        :title1  => "FISH",
        :title2  => null,
        :col1    => 0xFFFFFF,
        :bg      => 0x1E6FAA,
        :circle  => 0x165688,
        :accent  => 0x44CC66,
        :lbTitle => "FISHING",
        :hooks   => new FishHooks(),
        :options => [
            new GmOption("fish_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            new GmOption("fish_fx", "Sound & Haptics", ["ON", "OFF"], 0),
            // Cosmetic rod/line skin — unlocked by rank, shop-ready. A locked
            // pick simply renders as the classic wooden rod until it's owned.
            new GmOption("fish_rod", "Rod", ["BASIC", "PRO", "MASTER"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
