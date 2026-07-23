// ═══════════════════════════════════════════════════════════════════════════
// MineMenu.mc — Wires BITOCHI MINES into the shared unified menu.
//
// Builds the MenuConfig (title, colours, OPTIONS, signature art) and the
// GameHooks: START launches the mine view, the art band shows a live mini
// cross-section of YOUR mine, and LEADERBOARD opens a five-category picker
// (Depth · Richest · Legendary · Level · Age) instead of a single board.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

class MineHooks extends GameHooks {
    hidden var _preview;
    hidden var _tick;

    function initialize() {
        GameHooks.initialize();
        _tick = 0;
        try { _preview = new MineModel(); } catch (e) { _preview = null; }
    }

    function startGame() as Void {
        try {
            var v = new MineView();
            WatchUi.pushView(v, new MineDelegate(v), WatchUi.SLIDE_UP);
        } catch (e) {}
    }

    function drawArt(dc, cx, cy, w, h) as Void {
        if (_preview == null) { return; }
        _tick += 1;
        var r = h * 30 / 100;
        if (r < 18) { r = 18; }
        try { MineArt.drawScene(dc, _preview, cx, cy, r, _tick); } catch (e) {}
    }

    function footerText() as Lang.String or Null {
        try {
            if (_preview == null) { return null; }
            if (!_preview.started) { return "Open Bitochi Mine #001"; }
            return _preview.depth + "m · " + Mn.zName(_preview.zone()) + " · Lv " + _preview.mineLevel();
        } catch (e) { return null; }
    }

    function openBoard() as Lang.Boolean {
        try {
            var m = new MnBoardMenu();
            WatchUi.pushView(m, new MnBoardDelegate(), WatchUi.SLIDE_LEFT);
            return true;
        } catch (e) { return false; }
    }

    function hasReset() as Lang.Boolean { return true; }
    function resetLabel() as Lang.String { return "Reset mine"; }
    function resetProgress() as Void {
        try {
            var m = (_preview != null) ? _preview : new MineModel();
            m.resetAll();
            _preview = m;
        } catch (e) {}
    }
}

// ── Leaderboard category picker ──────────────────────────────────────────────
class MnBoardMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "LEADERBOARD" });
        addItem(new WatchUi.MenuItem("Deepest Mine", "Max depth", Mn.LB_DEPTH, null));
        addItem(new WatchUi.MenuItem("Richest Miner", "Resource value", Mn.LB_RICH, null));
        addItem(new WatchUi.MenuItem("Legendary Finds", "Rare collectibles", Mn.LB_LEGEND, null));
        addItem(new WatchUi.MenuItem("Mine Level", "Highest level", Mn.LB_LEVEL, null));
        addItem(new WatchUi.MenuItem("Oldest Mine", "Days active", Mn.LB_AGE, null));
    }
}

class MnBoardDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        var variant = item.getId();
        var title = item.getLabel();
        try {
            var v = new LbScoresView(Mn.GAME_ID, variant, title);
            WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }
}

// ── Build the MenuConfig ─────────────────────────────────────────────────────
function buildMineMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => Mn.GAME_ID,
        :title1  => "BITOCHI",
        :title2  => "MINES",
        :col1    => 0xFFA33A,
        :col2    => 0x4CE6E0,
        :bg      => Mn.BG,
        :circle  => Mn.CIRCLE,
        :accent  => Mn.ACCENT,
        :lbTitle => "BITOCHI MINES",
        :hooks   => new MineHooks(),
        :options => [
            new GmOption("mn_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
