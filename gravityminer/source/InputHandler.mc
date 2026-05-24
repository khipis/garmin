using Toybox.WatchUi;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if      (k == WatchUi.KEY_DOWN) { _v.navHoriz(); }
        else if (k == WatchUi.KEY_UP)   { _v.navVert();  }
        else if (k == WatchUi.KEY_ESC)  { return onBack(); }
        WatchUi.requestUpdate();
        return true;
    }
    function onNextPage()     { _v.navHoriz(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.navVert();  WatchUi.requestUpdate(); return true; }
    function onSelect()       { _v.navSelect(); WatchUi.requestUpdate(); return true; }
    function onTap(evt) {
        var xy = evt.getCoordinates();
        _v.handleTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
    function onBack() {
        if (_v.navBack()) { WatchUi.requestUpdate(); return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
