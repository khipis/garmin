using Toybox.WatchUi;

// ─────────────────────────────────────────────────────────────────────────────
//  ColonyDelegate  –  button input routing
//
//  Navigation:  UP / DOWN cycle through menu pages
//  SELECT:      confirm / build / boost on current selection
//  MENU:        open prestige confirm screen (if available)
//  BACK:        exit game (saves first)
// ─────────────────────────────────────────────────────────────────────────────

class ColonyDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;
    hidden var _game;

    function initialize(view, game) {
        BehaviorDelegate.initialize();
        _view = view;
        _game = game;
    }

    // SELECT — perform action on current selection
    function onSelect() {
        _view.onSelect();
        WatchUi.requestUpdate();
        return true;
    }

    // MENU — prestige confirm (if eligible) or toggle info page
    function onMenu() {
        _view.onMenu();
        WatchUi.requestUpdate();
        return true;
    }

    // UP — scroll selection up / previous page
    function onPreviousPage() {
        _view.scrollUp();
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN — scroll selection down / next page
    function onNextPage() {
        _view.scrollDown();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        _game.save();
        return false;  // allow normal exit
    }
}
