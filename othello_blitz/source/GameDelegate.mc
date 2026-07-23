using Toybox.WatchUi;

// Input routing (portable across button-only and touch Garmin devices).
//
// We rely on the standard BehaviorDelegate translation instead of overriding
// the raw onKey (which previously swallowed UP/DOWN and made horizontal cursor
// movement impossible, and could hijack BACK). The cursor cycles through the
// current player's VALID MOVES only, so two directional inputs are enough to
// reach any playable square on every device.
//
//   UP  / swipe        → onPreviousPage → previous valid move
//   DOWN / swipe        → onNextPage     → next valid move
//   START / SELECT      → onSelect       → place disc (or new game when over)
//   TAP (touch)         → onTap          → place at tapped square
//   BACK                → onBack         → return to the shared menu

class GameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onSelect()       { _v.doAction();     WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.cycleMove( 1);  WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.cycleMove(-1);  WatchUi.requestUpdate(); return true; }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        _v.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_v.doBack()) { WatchUi.requestUpdate(); return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
