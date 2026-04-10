using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  ColorPopDelegate  –  button routing for DIAMONDS match-3
//
//    TAP / SELECT  → select gem; if gem selected + adjacent cursor → swap
//    MENU          → advance cursor right → down (navigation)
//    UP  (prev)    → move cursor up   (clears selection)
//    DOWN (next)   → move cursor down (clears selection)
//    BACK          → return to menu
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
