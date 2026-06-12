using Toybox.WatchUi;

class BitochiBlackjackDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        if (_view.isMenu()) { _view.menuActivate(); } else { _view.doHit(); }
        WatchUi.requestUpdate(); return true;
    }
    function onMenu() {
        if (_view.isMenu()) { _view.menuActivate(); } else { _view.doStand(); }
        WatchUi.requestUpdate(); return true;
    }
    function onPreviousPage() {
        if (_view.isMenu()) { _view.menuNav(-1); } else { _view.doHit(); }
        WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_view.isMenu()) { _view.menuNav(1); } else { _view.doStand(); }
        WatchUi.requestUpdate(); return true;
    }

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
        if (key == WatchUi.KEY_UP) {
            if (_view.isMenu()) { _view.menuNav(-1); } else { _view.doHit(); }
            WatchUi.requestUpdate(); return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            if (_view.isMenu()) { _view.menuNav(1); } else { _view.doStand(); }
            WatchUi.requestUpdate(); return true;
        }
        return false;
    }
}
