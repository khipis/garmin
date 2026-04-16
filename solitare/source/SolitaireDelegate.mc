using Toybox.WatchUi;
using Toybox.System;

class SolitaireDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    function initialize(view) { BehaviorDelegate.initialize(); _v = view; }
    function onSelect()       { _v.doSelect(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.doUp();     WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.doDown();   WatchUi.requestUpdate(); return true; }
    function onBack() { var h = _v.doBack(); WatchUi.requestUpdate(); return h; }
    function onTap(evt) {
        _v.doTap(evt.getCoordinates()[0], evt.getCoordinates()[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
