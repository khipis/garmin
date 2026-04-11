using Toybox.WatchUi;

class BitochiSolitareDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)   { _view.doUp();     WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN) { _view.doDown();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_MENU) { _view.doMenu();   WatchUi.requestUpdate(); return true; }
        return false;
    }

    function onSelect() { _view.doSelect(); WatchUi.requestUpdate(); return true; }
    function onBack()   { _view.doBack();   WatchUi.requestUpdate(); return true; }

    function onTap(evt) {
        // Map tap position to a column / zone
        var x = evt.getCoordinates()[0];
        var y = evt.getCoordinates()[1];
        _view.doTap(x, y);
        WatchUi.requestUpdate();
        return true;
    }
}
