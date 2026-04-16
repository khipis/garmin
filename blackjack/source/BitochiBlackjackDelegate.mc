using Toybox.WatchUi;

class BitochiBlackjackDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect()       { _view.doHit();      WatchUi.requestUpdate(); return true; }
    function onMenu()         { _view.doStand();    WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _view.doHit();      WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _view.doStand();    WatchUi.requestUpdate(); return true; }

    function onBack() {
        var h = _view.doBack();
        WatchUi.requestUpdate();
        return h;
    }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        _view.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)   { _view.doHit();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN) { _view.doStand(); WatchUi.requestUpdate(); return true; }
        return false;
    }
}
