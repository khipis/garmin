using Toybox.WatchUi;

class AngryPomodoroDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect()  { _view.doSelect(); WatchUi.requestUpdate(); return true; }

    function onBack() {
        var handled = _view.doBack();
        WatchUi.requestUpdate();
        return handled;
    }

    function onMenu() {
        var handled = _view.doBack();
        WatchUi.requestUpdate();
        return handled;
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            _view.doSelect(); return true;
        }
        if (key == WatchUi.KEY_UP)   { _view.doUp();   return true; }
        if (key == WatchUi.KEY_DOWN) { _view.doDown(); return true; }
        return false;
    }

    function onTap(clickEvent) { _view.doSelect(); return true; }

    function onPreviousPage() { _view.doUp();   return true; }
    function onNextPage()     { _view.doDown(); return true; }

    function onSwipe(swipeEvent) {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_DOWN) { _view.doBack();   }
        else                           { _view.doSelect(); }
        return true;
    }
}
