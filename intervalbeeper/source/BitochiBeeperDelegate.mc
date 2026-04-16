using Toybox.WatchUi;
using Toybox.System;

class BitochiBeeperDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.doSelect();
        return true;
    }

    function onBack() {
        return _view.doBack();
    }

    function onMenu() {
        return _view.doBack();
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
        var k = evt.getKey();
        if (k == WatchUi.KEY_ENTER) { _view.doSelect(); return true; }
        if (k == WatchUi.KEY_UP)    { _view.doUp();     return true; }
        if (k == WatchUi.KEY_DOWN)  { _view.doDown();   return true; }
        return false;
    }

    function onTap(evt) {
        _view.doTap(evt.getCoordinates()[0], evt.getCoordinates()[1]);
        return true;
    }
}
