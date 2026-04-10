using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  ColorPopDelegate  –  all button routing
//
//  Single mode — no sub-selection:
//    UP     → swap cursor gem with gem ABOVE   (↑)
//    DOWN   → swap cursor gem with gem BELOW   (↓)
//    SELECT → swap cursor gem with gem to RIGHT (→)
//    MENU   → advance cursor to next cell (navigate)
//    BACK   → go to menu / exit
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
