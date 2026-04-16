using Toybox.WatchUi;

class BitochiBlocksDelegate extends WatchUi.InputDelegate {

    hidden var _view;

    function initialize(view) {
        InputDelegate.initialize();
        _view = view;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ENTER) { _view.doAction();    WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_UP)    { _view.doMoveRight(); WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN)  { _view.doMoveLeft();  WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_ESC) {
            if (_view.isPlaying()) { _view.doBack(); WatchUi.requestUpdate(); return true; }
            return false;
        }
        return false;
    }

    function onSwipe(swipeEvent) {
        if (_view.isPlaying()) {
            var dir = swipeEvent.getDirection();
            if (dir == WatchUi.SWIPE_RIGHT) { _view.doMoveRight(); WatchUi.requestUpdate(); return true; }
            if (dir == WatchUi.SWIPE_LEFT)  { _view.doMoveLeft();  WatchUi.requestUpdate(); return true; }
            if (dir == WatchUi.SWIPE_DOWN)  { _view.doHardDrop();  WatchUi.requestUpdate(); return true; }
            if (dir == WatchUi.SWIPE_UP)    { _view.doRotate();    WatchUi.requestUpdate(); return true; }
        }
        return false;
    }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        _view.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
