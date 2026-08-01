using Toybox.WatchUi;

class BitochiMinigolfDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)   { _view.doUp();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN) { _view.doDown(); WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_MENU) { var h = onBack(); WatchUi.requestUpdate(); return h; }
        return false;
    }

    function onSelect()       { _view.doSelect(); WatchUi.requestUpdate(); return true; }
    function onBack()         { return SaveResume.confirmExit("minigolf", _view.method(:exportSave)); }
    function onPreviousPage() { _view.doUp();     WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _view.doDown();   WatchUi.requestUpdate(); return true; }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        _view.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
