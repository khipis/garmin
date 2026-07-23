using Toybox.WatchUi;

class CellWarsDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onSelect() {
        _v.doSelect();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        _v.doUp();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _v.doDown();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_v.doBack()) {
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        _v.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }

    // Touch speed control — essential on watches without UP/DOWN buttons
    // (e.g. vivoactive 6, which only has ENTER + BACK keys plus the screen).
    // Swipe up = faster, swipe down = slower.
    function onSwipe(evt) {
        var d = evt.getDirection();
        if      (d == WatchUi.SWIPE_UP)   { _v.doUp();   }
        else if (d == WatchUi.SWIPE_DOWN) { _v.doDown(); }
        else                              { return true; }
        WatchUi.requestUpdate();
        return true;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)    { _v.doUp();     WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN)  { _v.doDown();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_ENTER) { _v.doSelect(); WatchUi.requestUpdate(); return true; }
        return false;
    }
}
