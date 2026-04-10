using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  ColorPopDelegate  –  all button routing
//
//  Controls (two modes: MOVE cursor, SELECT first gem for swap):
//
//  MOVE mode:
//    UP    → move cursor up
//    DOWN  → move cursor down
//    SELECT→ enter SELECT mode (highlight this gem for swapping)
//    MENU  → quick-rotate cursor right (shortcut)
//    BACK  → exit game
//
//  SELECT mode (gem chosen, pick direction):
//    UP    → swap up
//    DOWN  → swap down
//    SELECT→ swap right  (most frequent swap direction)
//    MENU  → swap left
//    BACK  → cancel selection
// ─────────────────────────────────────────────────────────────────────────────

class ColorPopDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.onSelect();
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() {
        _view.onMenu();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        _view.onUp();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.onDown();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_view.onBack()) {
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}
