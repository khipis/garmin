using Toybox.WatchUi;

class BitochiPokerDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)    { _view.doLeft();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN)  { _view.doRight();  WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_ENTER) { _view.doSelect(); WatchUi.requestUpdate(); return true; }
        return false;
    }

    function onSelect()       { _view.doSelect(); WatchUi.requestUpdate(); return true; }
    function onMenu()         { var h = _view.doBack(); WatchUi.requestUpdate(); return h; }
    function onBack()         { var h = _view.doBack(); WatchUi.requestUpdate(); return h; }
    function onPreviousPage() { _view.doLeft();  WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _view.doRight(); WatchUi.requestUpdate(); return true; }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        _view.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
