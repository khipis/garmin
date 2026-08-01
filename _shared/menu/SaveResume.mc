// ═══════════════════════════════════════════════════════════════════════════
// SaveResume.mc — Shared mid-run save / resume for long session games.
//
// Enable in a game (~few lines):
//   1. GameHooks.hasResume()  → SaveResume.exists(GAME_ID)
//   2. GameHooks.resumeGame() → push view with resume flag / load blob
//   3. GameHooks.startGame()  → SaveResume.clear(GAME_ID) then fresh start
//   4. On BACK: return SaveResume.confirmExit(GAME_ID, method(:exportSave));
//      exportSave() returns a Dictionary (or null = nothing to save → just pop)
//   5. On win/lose/complete: SaveResume.clear(GAME_ID)
//
// Exit prompt: "SAVE PROGRESS?" → Yes (save + pop) / No (discard + pop).
// BACK on the prompt cancels (stay in game).
//
// Storage is PER-GAME (`sr_<gameId>`) so saves never collide across apps.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

module SaveResume {

    const VER = 1;

    function keyFor(gameId as Lang.String) as Lang.String {
        if (gameId == null || gameId.length() == 0) { return "sr_save"; }
        return "sr_" + gameId;
    }

    function exists(gameId as Lang.String) as Lang.Boolean {
        return load(gameId) != null;
    }

    function load(gameId as Lang.String) as Lang.Dictionary or Null {
        try {
            var v = Application.Storage.getValue(keyFor(gameId));
            if (!(v instanceof Lang.Dictionary)) { return null; }
            var ver = v["v"];
            if (!(ver instanceof Lang.Number) || ver != VER) {
                clear(gameId);
                return null;
            }
            return v;
        } catch (e) {}
        return null;
    }

    function save(gameId as Lang.String, data as Lang.Dictionary) as Void {
        if (data == null) { return; }
        try {
            data["v"] = VER;
            Application.Storage.setValue(keyFor(gameId), data);
        } catch (e) {}
    }

    function clear(gameId as Lang.String) as Void {
        try { Application.Storage.deleteValue(keyFor(gameId)); } catch (e) {}
        // Also wipe the legacy shared key if present.
        try { Application.Storage.deleteValue("sr_save"); } catch (e) {}
    }

    // Show Yes/No save prompt, then pop the gameplay view.
    // exportCb: Method that returns Dictionary (save) or null (nothing to save
    // → pop immediately without prompting).
    // Returns true if the BACK event was consumed (prompt shown or handled).
    function confirmExit(gameId as Lang.String, exportCb) as Lang.Boolean {
        var data = null;
        try { data = exportCb.invoke(); } catch (e) { data = null; }
        if (data == null) {
            try { WatchUi.popView(WatchUi.SLIDE_RIGHT); } catch (e) {}
            return true;
        }
        try {
            var m = new WatchUi.Menu2({ :title => "SAVE PROGRESS?" });
            m.addItem(new WatchUi.MenuItem("Cancel", "keep playing", :cancel, null));
            m.addItem(new WatchUi.MenuItem("Yes, save", "resume later", :yes, null));
            m.addItem(new WatchUi.MenuItem("No, quit", "discard run", :no, null));
            WatchUi.pushView(m, new SrExitConfirmDelegate(gameId, data), WatchUi.SLIDE_UP);
            return true;
        } catch (e) {
            try { WatchUi.popView(WatchUi.SLIDE_RIGHT); } catch (e2) {}
            return true;
        }
    }
}

// Confirm delegate: Yes → save + pop prompt + pop game; No → clear + pop both;
// Cancel → pop prompt only.
class SrExitConfirmDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _gameId;
    hidden var _data;

    function initialize(gameId, data) {
        Menu2InputDelegate.initialize();
        _gameId = gameId;
        _data = data;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :cancel) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }
        if (id == :yes) {
            try { SaveResume.save(_gameId, _data); } catch (e) {}
        } else if (id == :no) {
            try { SaveResume.clear(_gameId); } catch (e) {}
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        try { WatchUi.popView(WatchUi.SLIDE_RIGHT); } catch (e) {}
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
