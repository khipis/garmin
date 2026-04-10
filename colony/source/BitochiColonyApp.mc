using Toybox.Application;
using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  Bitochi: Star Colony  –  Idle/clicker game for Garmin watches
//  Entry point: initialises game state, wires view + delegate
// ─────────────────────────────────────────────────────────────────────────────

class BitochiColonyApp extends Application.AppBase {

    hidden var _game;

    function initialize() {
        AppBase.initialize();
        _game = new ColonyGame();
    }

    function onStart(state) {
        // Calculate offline earnings when app is resumed
        _game.onResume();
    }

    function onStop(state) {
        // Persist everything before closing
        _game.save();
    }

    function getInitialView() {
        var view     = new ColonyView(_game);
        var delegate = new ColonyDelegate(view, _game);
        return [view, delegate];
    }
}
