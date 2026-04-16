// DiveDelegate.mc  (InputHandler)
// ─────────────────────────────────────────────────────────────────────────────
// Maps physical buttons and touch events to DiveView actions.
// ─────────────────────────────────────────────────────────────────────────────

using Toybox.WatchUi;
using Toybox.System;

class DiveDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // SELECT / START — advance field or confirm
    function onSelect() {
        _view.doSelect();
        WatchUi.requestUpdate();
        return true;
    }

    // BACK / LAP — go back to previous field or main menu
    function onBack() {
        var consumed = _view.doBack();
        WatchUi.requestUpdate();
        return consumed;
    }

    // UP button / PREV PAGE
    function onPreviousPage() {
        _view.doUp();
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN button / NEXT PAGE
    function onNextPage() {
        _view.doDown();
        WatchUi.requestUpdate();
        return true;
    }

    // Physical key presses (devices without touch / dedicated buttons)
    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)   { _view.doUp();     WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN) { _view.doDown();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_ENTER){ _view.doSelect(); WatchUi.requestUpdate(); return true; }
        return false;
    }

    // Tap / touch
    function onTap(evt) {
        var coords = evt.getCoordinates();
        _view.doTap(coords[0], coords[1]);
        WatchUi.requestUpdate();
        return true;
    }

    // MENU long-press — back to main menu from anywhere
    function onMenu() {
        if (_view._state != DV_MENU && _view._state != DV_DISC) {
            _view._state = DV_MENU;
            _view._field = 0;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}
