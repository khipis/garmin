// BoatModeDelegate.mc
using Toybox.WatchUi;
using Toybox.System;

class BoatModeDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.doSelect();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        var consumed = _view.doBack();
        if (!consumed) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onMenu() {
        // Long-press from any mode → return to mode select
        _view._state = BM_MODE_SEL;
        _view._field = 0;
        WatchUi.requestUpdate();
        return true;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP) {
            _view.doUp();
            WatchUi.requestUpdate();
            return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            _view.doDown();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function onPreviousPage() {
        _view.doUp();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.doDown();
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) {
        var coords = evt.getCoordinates();
        _view.doTap(coords[0], coords[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            _view.doDown();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_DOWN) {
            _view.doUp();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_LEFT) {
            // Next field / select
            _view.doSelect();
            WatchUi.requestUpdate();
            return true;
        }
        if (dir == WatchUi.SWIPE_RIGHT) {
            var consumed = _view.doBack();
            if (!consumed) { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
            else { WatchUi.requestUpdate(); }
            return true;
        }
        return false;
    }
}
