using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  DungeonDelegate  –  2-button input routing
//
//  SELECT = action A  (LEFT fork / top power-up / dodge / confirm)
//  MENU   = action B  (RIGHT fork / bottom power-up / attack / restart)
//  UP     = in menu: cycle class up
//  DOWN   = in menu: cycle class down
//  BACK   = return to menu from dead screen, or exit from menu
// ─────────────────────────────────────────────────────────────────────────────

class DungeonDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.onActionA();
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() {
        _view.onActionB();
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
