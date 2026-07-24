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
using Toybox.Application;

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
            var asc = (_preview.asc > 0) ? (" · A" + _preview.asc) : "";
            if (!_preview.hatched) { return "EGG " + _preview.hatchPct() + "%" + asc; }
            return Cr.speciesName(_preview.species) + " · Lv " + _preview.level
                 + " · " + _preview.ageDayLabel() + asc;
        } catch (e) { return null; }
    }

    // ── Ascension (OPTIONS → Ascend) ─────────────────────────────────────────
    // Read straight from Storage rather than the art-band preview model: the
    // player may have ascended inside the game since this menu was built, and a
    // stale "ready" would be misleading.
    function canAscend() as Lang.Boolean {
        try {
            var h = Application.Storage.getValue("cr_hatch");
            if (h != true) { return false; }
            var e = Application.Storage.getValue("cr_evo");
            return (e instanceof Lang.Number) && e >= Cr.EV_APEX;
        } catch (ex) { return false; }
    }
    // Confirmed ascend. Re-reads the save first so this can never rebirth a
    // creature that was already ascended from inside the game this session.
    function doAscend() as Void {
        try {
            var m = new CreatureModel();
            if (!m.canAscend()) { return; }
            m.ascend();
            _preview = m;
        } catch (e) {}
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

// ── Ascension confirmation ───────────────────────────────────────────────────
// Mirrors the shared "Reset progress" confirm flow (GmResetConfirmDelegate): a
// two-row Menu2 where only an explicit "Yes" acts, so nobody can trade away
// their Apex creature with a stray tap. `target` is any object exposing
// doAscend() — the live game view, or the menu hooks when opened from OPTIONS.
function crOpenAscend(target) as Void {
    try {
        var m = new WatchUi.Menu2({ :title => "ASCEND?" });
        // Cancel is FIRST on purpose: this menu can be reached with SELECT from
        // the EVOLVE page, so the pre-highlighted row must be the harmless one.
        m.addItem(new WatchUi.MenuItem("Cancel", "keep this creature", :no, null));
        m.addItem(new WatchUi.MenuItem("Yes, ascend", "new egg, keep legacy", :yes, null));
        WatchUi.pushView(m, new CrAscendConfirmDelegate(target), WatchUi.SLIDE_UP);
    } catch (e) {}
}

class CrAscendConfirmDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _target;

    function initialize(target) {
        Menu2InputDelegate.initialize();
        _target = target;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :yes && _target != null) {
            try { _target.doAscend(); } catch (e) {}
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

// An OPTIONS row that fires an action instead of cycling a value. The shared
// options screen calls cycle() when a row is picked, so overriding it here adds
// an action row without touching any shared code.
class CrAscendOption extends GmOption {
    hidden var _hooks;

    function initialize(hooks) {
        GmOption.initialize("cr_ascend", "Ascend", ["READY"], 0);
        _hooks = hooks;
    }

    function valueStr() as Lang.String {
        try { if (!_hooks.canAscend()) { return "not ready"; } } catch (e) {}
        return "new egg, keep legacy";
    }

    function cycle() as Lang.Number {
        var ok = false;
        try { ok = _hooks.canAscend(); } catch (e) {}
        if (ok) { crOpenAscend(_hooks); }
        return 0;   // nothing is persisted: this row is an action, not a setting
    }
}

// ── Build the MenuConfig ─────────────────────────────────────────────────────
function buildCreaturesMenu() as Lang.Array {
    var hooks = new CreaturesHooks();
    var opts = [
        new GmOption("cr_focus", "Training Focus",
                     ["AUTO", "SPEED", "STRENGTH", "MIND", "ENERGY"], 0),
        new GmOption("cr_fx", "Sound & Haptics", ["ON", "OFF"], 0)
    ];
    // Gated: the ASCEND row only exists once the creature has reached Apex.
    var canAsc = false;
    try { canAsc = hooks.canAscend(); } catch (e) {}
    if (canAsc) { opts.add(new CrAscendOption(hooks)); }

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
        :hooks   => hooks,
        :options => opts
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
