using Toybox.WatchUi;

class BitochiJazzBallDelegate extends WatchUi.InputDelegate {
    hidden var _view;

    function initialize(view) {
        InputDelegate.initialize();
        _view = view;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)   { _view.doUp();     WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN) { _view.doDown();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_ENTER){ _view.doSelect(); WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_ESC)  {
            var h = SaveResume.confirmExit("jazzball", _view.method(:exportSave));
            WatchUi.requestUpdate();
            return h;
        }
        return false;
    }

    function onBack() {
        var h = SaveResume.confirmExit("jazzball", _view.method(:exportSave));
        WatchUi.requestUpdate();
        return h;
    }

    function onSwipe(evt) {
        _view.doToggleDir();
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) {
        var c = evt.getCoordinates();
        _view.doTap(c[0], c[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
