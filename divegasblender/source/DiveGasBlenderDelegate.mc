using Toybox.WatchUi;

class DiveGasBlenderDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.doSelect();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_view.doBack()) {
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onPreviousPage() {
        _view.doUp();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.doDown();
        WatchUi.requestUpdate();
        return true;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)   { _view.doUp();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN) { _view.doDown(); WatchUi.requestUpdate(); return true; }
        return false;
    }

    function onTap(evt) {
        var coords = evt.getCoordinates();
        _view.doTap(coords[0], coords[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP)   { _view.doDown(); WatchUi.requestUpdate(); return true; }
        if (dir == WatchUi.SWIPE_DOWN) { _view.doUp();   WatchUi.requestUpdate(); return true; }
        return false;
    }
}
