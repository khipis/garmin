// ═══════════════════════════════════════════════════════════════════════════
// IslandMenu.mc — Wires ISLAND into the shared unified menu.
//
// Builds the MenuConfig (title, colours, OPTIONS, signature art) and the
// GameHooks: START launches the island view, the art band shows a live mini
// render of YOUR island, and LEADERBOARD opens a four-category picker
// (Level · Beauty · Population · Collection) instead of a single board.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

class IslandHooks extends GameHooks {
    hidden var _preview;
    hidden var _tick;

    function initialize() {
        GameHooks.initialize();
        _tick = 0;
        try { _preview = new IslandModel(); } catch (e) { _preview = null; }
    }

    function startGame() as Void {
        try {
            var v = new IslandView();
            WatchUi.pushView(v, new IslandDelegate(v), WatchUi.SLIDE_UP);
        } catch (e) {}
    }

    function drawArt(dc, cx, cy, w, h) as Void {
        if (_preview == null) { return; }
        _tick += 1;
        var r = h * 26 / 100;
        if (r < 16) { r = 16; }
        try { IslandArt.drawScene(dc, _preview, cx, cy, r, _tick); } catch (e) {}
    }

    function footerText() as Lang.String or Null {
        try {
            if (_preview == null) { return null; }
            if (!_preview.started) { return "New island paradise"; }
            return "Lv " + _preview.islandLevel() + " · Pop " + _preview.population
                 + " · " + _preview.ageDayLabel();
        } catch (e) { return null; }
    }

    function openBoard() as Lang.Boolean {
        try {
            var m = new IsBoardMenu();
            WatchUi.pushView(m, new IsBoardDelegate(), WatchUi.SLIDE_LEFT);
            return true;
        } catch (e) { return false; }
    }

    function hasReset() as Lang.Boolean { return true; }
    function resetLabel() as Lang.String { return "Reset island"; }
    function resetProgress() as Void {
        try {
            var m = (_preview != null) ? _preview : new IslandModel();
            m.resetAll();
            _preview = m;
        } catch (e) {}
    }
}

// ── Leaderboard category picker ──────────────────────────────────────────────
class IsBoardMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "LEADERBOARD" });
        addItem(new WatchUi.MenuItem("Island Level", "Highest level", Is.LB_LEVEL, null));
        addItem(new WatchUi.MenuItem("Most Beautiful", "Beauty score", Is.LB_BEAUTY, null));
        addItem(new WatchUi.MenuItem("Population", "Largest colony", Is.LB_POP, null));
        addItem(new WatchUi.MenuItem("Collection", "Rarest set", Is.LB_COLLECT, null));
    }
}

class IsBoardDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        var variant = item.getId();
        var title = item.getLabel();
        try {
            var v = new LbScoresView(Is.GAME_ID, variant, title);
            WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }
}

// ── Build the MenuConfig ─────────────────────────────────────────────────────
function buildIslandMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => Is.GAME_ID,
        :title1  => "ISLAND",
        :title2  => "PARADISE",
        :col1    => 0x37D0C0,
        :col2    => 0xFFC24A,
        :bg      => Is.BG,
        :circle  => Is.CIRCLE,
        :accent  => Is.ACCENT,
        :lbTitle => "ISLAND",
        :hooks   => new IslandHooks(),
        :options => [
            new GmOption("is_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
