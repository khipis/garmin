// ═══════════════════════════════════════════════════════════════════════════
// CreaturesMenu.mc — Wires BITOCHI CREATURES into the shared unified menu.
//
// Builds the MenuConfig (title, colours, OPTIONS, signature art) and the
// GameHooks: START launches the creature view, the art band shows a live
// preview of YOUR creature (or the egg), and LEADERBOARD opens a four-category
// picker (Rarity · Age · Evolution · Trainer) instead of a single board.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

class CreaturesHooks extends GameHooks {
    hidden var _preview;   // a lightweight model just for the menu art band
    hidden var _tick;

    function initialize() {
        GameHooks.initialize();
        _tick = 0;
        try { _preview = new CreatureModel(); _preview.ensureEgg(); } catch (e) { _preview = null; }
    }

    function startGame() as Void {
        try {
            var v = new CreaturesView();
            WatchUi.pushView(v, new CreaturesDelegate(v), WatchUi.SLIDE_UP);
        } catch (e) {}
    }

    // Signature art: your current creature (or its egg), gently bobbing.
    function drawArt(dc, cx, cy, w, h) as Void {
        if (_preview == null) { return; }
        _tick += 1;
        var r = h * 22 / 100;
        if (r < 14) { r = 14; }
        try {
            if (_preview.hatched) { CreatureArt.drawCreature(dc, _preview, cx, cy, r, _tick); }
            else { CreatureArt.drawEgg(dc, _preview, cx, cy, r, _tick); }
        } catch (e) {}
    }

    function footerText() as Lang.String or Null {
        try {
            if (_preview == null) { return null; }
            if (!_preview.hatched) { return "EGG " + _preview.hatchPct() + "%"; }
            return Cr.speciesName(_preview.species) + " · Lv " + _preview.level
                 + " · " + _preview.ageDayLabel();
        } catch (e) { return null; }
    }

    // Own the leaderboard entry point: show a category picker.
    function openBoard() as Lang.Boolean {
        try {
            var m = new CrBoardMenu();
            WatchUi.pushView(m, new CrBoardDelegate(), WatchUi.SLIDE_LEFT);
            return true;
        } catch (e) { return false; }
    }

    function hasReset() as Lang.Boolean { return true; }
    function resetLabel() as Lang.String { return "Reset creature"; }
    function resetProgress() as Void {
        try {
            var m = (_preview != null) ? _preview : new CreatureModel();
            m.resetAll();
            _preview = m;
        } catch (e) {}
    }
}

// ── Leaderboard category picker ──────────────────────────────────────────────
class CrBoardMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "LEADERBOARD" });
        addItem(new WatchUi.MenuItem("Rarest",      "Rarity score", Cr.LB_RARITY, null));
        addItem(new WatchUi.MenuItem("Oldest",      "Days alive",   Cr.LB_AGE, null));
        addItem(new WatchUi.MenuItem("Evolution",   "Highest form", Cr.LB_EVO, null));
        addItem(new WatchUi.MenuItem("Top Trainer", "Most active",  Cr.LB_TRAINER, null));
    }
}

class CrBoardDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        var variant = item.getId();
        var title = item.getLabel();
        try {
            var v = new LbScoresView(Cr.GAME_ID, variant, title);
            WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }
}

// ── Build the MenuConfig ─────────────────────────────────────────────────────
function buildCreaturesMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => Cr.GAME_ID,
        :title1  => "BITOCHI",
        :title2  => "CREATURES",
        :col1    => 0x34D399,
        :col2    => 0x9A6CFF,
        :bg      => Cr.BG,
        :circle  => Cr.CIRCLE,
        :accent  => Cr.ACCENT,
        :lbTitle => "CREATURES",
        :hooks   => new CreaturesHooks(),
        :options => [
            new GmOption("cr_focus", "Training Focus",
                         ["AUTO", "SPEED", "STRENGTH", "MIND", "ENERGY"], 0),
            new GmOption("cr_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
