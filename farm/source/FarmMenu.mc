// ═══════════════════════════════════════════════════════════════════════════
// FarmMenu.mc — Wires FARM into the shared unified menu.
//
// Builds the MenuConfig (title, colours, OPTIONS, signature art) and the
// GameHooks: START launches the farm view, the art band shows a live mini
// render of YOUR farm, and LEADERBOARD opens a four-category picker
// (Level · Charm · Herd · Collection) instead of a single board.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

class FarmHooks extends GameHooks {
    hidden var _preview;
    hidden var _tick;

    function initialize() {
        GameHooks.initialize();
        _tick = 0;
        try { _preview = new FarmModel(); } catch (e) { _preview = null; }
    }

    function startGame() as Void {
        try {
            var v = new FarmView();
            WatchUi.pushView(v, new FarmDelegate(v), WatchUi.SLIDE_UP);
        } catch (e) {}
    }

    function drawArt(dc, cx, cy, w, h) as Void {
        if (_preview == null) { return; }
        _tick += 1;
        var r = h * 26 / 100;
        if (r < 16) { r = 16; }
        try { FarmArt.drawScene(dc, _preview, cx, cy, r, _tick); } catch (e) {}
    }

    function footerText() as Lang.String or Null {
        try {
            if (_preview == null) { return null; }
            if (!_preview.started) { return "Start your dream farm"; }
            return "Lv " + _preview.farmLevel() + " · Herd " + _preview.population
                 + " · " + _preview.ageDayLabel();
        } catch (e) { return null; }
    }

    function openBoard() as Lang.Boolean {
        try {
            var m = new FaBoardMenu();
            WatchUi.pushView(m, new FaBoardDelegate(), WatchUi.SLIDE_LEFT);
            return true;
        } catch (e) { return false; }
    }

    function hasReset() as Lang.Boolean { return true; }
    function resetLabel() as Lang.String { return "Reset farm"; }
    function resetProgress() as Void {
        try {
            var m = (_preview != null) ? _preview : new FarmModel();
            m.resetAll();
            _preview = m;
        } catch (e) {}
    }
}

// ── Leaderboard category picker ──────────────────────────────────────────────
class FaBoardMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "LEADERBOARD" });
        addItem(new WatchUi.MenuItem("Farm Level", "Highest level", Fa.LB_LEVEL, null));
        addItem(new WatchUi.MenuItem("Most Charming", "Charm score", Fa.LB_CHARM, null));
        addItem(new WatchUi.MenuItem("Biggest Herd", "Most animals", Fa.LB_HERD, null));
        addItem(new WatchUi.MenuItem("Collection", "Rarest set", Fa.LB_COLLECT, null));
    }
}

class FaBoardDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        var variant = item.getId();
        var title = item.getLabel();
        try {
            var v = new LbScoresView(Fa.GAME_ID, variant, title);
            WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }
}

// ── Build the MenuConfig ─────────────────────────────────────────────────────
function buildFarmMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => Fa.GAME_ID,
        :title1  => "FARM",
        :title2  => "LIFE",
        :col1    => 0x8CD060,
        :col2    => 0xFFC24A,
        :bg      => Fa.BG,
        :circle  => Fa.CIRCLE,
        :accent  => Fa.ACCENT,
        :lbTitle => "FARM",
        :hooks   => new FarmHooks(),
        :options => [
            new GmOption("fa_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
