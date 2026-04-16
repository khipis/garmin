using Toybox.WatchUi;

class FakeNotifDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect()       { _view.doSelect(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _view.doPrev();   WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _view.doNext();   WatchUi.requestUpdate(); return true; }

    function onBack() {
        var h = _view.doBack();
        WatchUi.requestUpdate();
        return h;
    }

    function onMenu() {
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
        if (key == WatchUi.KEY_UP)   { _view.doPrev();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN) { _view.doNext();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_ENTER){ _view.doSelect(); WatchUi.requestUpdate(); return true; }
        return false;
    }
}
