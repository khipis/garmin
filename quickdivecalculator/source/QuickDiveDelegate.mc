// QuickDiveDelegate.mc — input mapping

using Toybox.WatchUi;

class QuickDiveDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // SELECT — toggle gas ↔ depth active field
    function onSelect() {
        _view.doSelect();
        WatchUi.requestUpdate();
        return true;
    }

    // BACK — return to page 1 or exit
    function onBack() {
        var consumed = _view.doBack();
        WatchUi.requestUpdate();
        return consumed;
    }

    // UP
    function onPreviousPage() {
        _view.doUp();
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN
    function onNextPage() {
        _view.doDown();
        WatchUi.requestUpdate();
        return true;
    }

    // Physical keys fallback
    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)    { _view.doUp();       WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN)  { _view.doDown();     WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_ENTER) { _view.doSelect();   WatchUi.requestUpdate(); return true; }
        return false;
    }

    // Touch
    function onTap(evt) {
        var c = evt.getCoordinates();
        _view.doTap(c[0], c[1]);
        WatchUi.requestUpdate();
        return true;
    }

    // Swipe right → Best Mix page
    function onSwipe(evt) {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_LEFT)  { _view.doNextPage(); WatchUi.requestUpdate(); return true; }
        if (dir == WatchUi.SWIPE_RIGHT) { _view.doPrevPage(); WatchUi.requestUpdate(); return true; }
        return false;
    }

    // MENU long press → switch page
    function onMenu() {
        if (_view._page == QC_CHECK) { _view.doNextPage(); }
        else                         { _view.doPrevPage(); }
        WatchUi.requestUpdate();
        return true;
    }
}
