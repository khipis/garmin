using Toybox.WatchUi;

class BreathTrainingDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    function initialize(view) { BehaviorDelegate.initialize(); _v = view; }
    function onSelect()       { _v.doSelect(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.doUp();     WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.doDown();   WatchUi.requestUpdate(); return true; }
    function onBack() {
        var h = _v.doBack();
        if (h) { WatchUi.requestUpdate(); return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT); return true;
    }
    function onMenu() { var h = _v.doBack(); WatchUi.requestUpdate(); return h; }
    function onTap(evt) {
        var xy = evt.getCoordinates();
        _v.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate(); return true;
    }
    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)    { _v.doUp();     WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN)  { _v.doDown();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_ENTER) { _v.doSelect(); WatchUi.requestUpdate(); return true; }
        return false;
    }
}
