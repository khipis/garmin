using Toybox.WatchUi;

class DiverCommDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.doSelect();
        return true;
    }

    // Long press → instant HELP! from anywhere
    function onMenu() {
        _view.doEmergency();
        return true;
    }

    function onBack() {
        if (_view.doBack()) { return true; }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onPreviousPage() {
        _view.doUp();
        return true;
    }

    function onNextPage() {
        _view.doDown();
        return true;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)   { _view.doUp();   return true; }
        if (key == WatchUi.KEY_DOWN) { _view.doDown(); return true; }
        return false;
    }

    function onTap(evt) {
        var coords = evt.getCoordinates();
        _view.doTap(coords[0], coords[1]);
        return true;
    }

    function onSwipe(evt) {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP)   { _view.doDown(); return true; }
        if (dir == WatchUi.SWIPE_DOWN) { _view.doUp();   return true; }
        return false;
    }
}
