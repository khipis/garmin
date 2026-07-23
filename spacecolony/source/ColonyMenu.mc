// ═══════════════════════════════════════════════════════════════════════════
// ColonyMenu.mc — Wires SPACE COLONY into the shared unified menu.
//
// Builds the MenuConfig (title, colours, OPTIONS, signature art) and the
// GameHooks: START launches the colony view, the art band shows a live mini
// render of YOUR colony skyline, and LEADERBOARD opens a five-category picker
// (Civ · Colony · Tech · Age · Explore) instead of a single board.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

class ColonyHooks extends GameHooks {
    hidden var _preview;
    hidden var _tick;

    function initialize() {
        GameHooks.initialize();
        _tick = 0;
        try { _preview = new ColonyModel(); } catch (e) { _preview = null; }
    }

    function startGame() as Void {
        try {
            var v = new ColonyView();
            WatchUi.pushView(v, new ColonyDelegate(v), WatchUi.SLIDE_UP);
        } catch (e) {}
    }

    // Signature art: a live mini render of your colony skyline.
    function drawArt(dc, cx, cy, w, h) as Void {
        if (_preview == null) { return; }
        _tick += 1;
        var r = h * 26 / 100;
        if (r < 16) { r = 16; }
        try { ColonyArt.drawScene(dc, _preview, cx, cy, r, _tick); } catch (e) {}
    }

    function footerText() as Lang.String or Null {
        try {
            if (_preview == null) { return null; }
            if (!_preview.started) { return "New colony · Planet X-01"; }
            return "Civ " + _preview.civLevel() + " · Pop " + _preview.population
                 + " · " + _preview.ageDayLabel();
        } catch (e) { return null; }
    }

    function openBoard() as Lang.Boolean {
        try {
            var m = new ScBoardMenu();
            WatchUi.pushView(m, new ScBoardDelegate(), WatchUi.SLIDE_LEFT);
            return true;
        } catch (e) { return false; }
    }

    function hasReset() as Lang.Boolean { return true; }
    function resetLabel() as Lang.String { return "Reset colony"; }
    function resetProgress() as Void {
        try {
            var m = (_preview != null) ? _preview : new ColonyModel();
            m.resetAll();
            _preview = m;
        } catch (e) {}
    }
}

// ── Leaderboard category picker ──────────────────────────────────────────────
class ScBoardMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "LEADERBOARD" });
        addItem(new WatchUi.MenuItem("Civilization", "Highest civ level", Sc.LB_CIV, null));
        addItem(new WatchUi.MenuItem("Largest Colony", "Population", Sc.LB_COLONY, null));
        addItem(new WatchUi.MenuItem("Technology", "Most advanced", Sc.LB_TECH, null));
        addItem(new WatchUi.MenuItem("Oldest Colony", "Days alive", Sc.LB_AGE, null));
        addItem(new WatchUi.MenuItem("Explorer", "Planet mapped", Sc.LB_EXPLORE, null));
    }
}

class ScBoardDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        var variant = item.getId();
        var title = item.getLabel();
        try {
            var v = new LbScoresView(Sc.GAME_ID, variant, title);
            WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }
}

// ── Build the MenuConfig ─────────────────────────────────────────────────────
function buildColonyMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => Sc.GAME_ID,
        :title1  => "SPACE",
        :title2  => "COLONY",
        :col1    => 0x33C0FF,
        :col2    => 0xFFC24A,
        :bg      => Sc.BG,
        :circle  => Sc.CIRCLE,
        :accent  => Sc.ACCENT,
        :lbTitle => "SPACE COLONY",
        :hooks   => new ColonyHooks(),
        :options => [
            new GmOption("sc_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
