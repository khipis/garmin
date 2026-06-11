using Toybox.WatchUi;

// Routes all input to GameView.
// UP / KEY_UP   → rotate clockwise
// DOWN / KEY_DOWN → rotate counter-clockwise
// SELECT / tap  → dash  (or start/restart)
// BACK          → end run
//
// Held-key tracking: onKey fired for both KEY_PRESSED and KEY_RELEASED so
// that GameView's input flags stay live between ticks.
// onPreviousPage / onNextPage (swipe gestures) inject a short impulse.

class GameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onKey(evt) {
        var k       = evt.getKey();
        // getType() returns 0 for press, non-zero for release
        var pressed = (evt.getType() == 0) ? 1 : 0;

        // Title menu: UP/DOWN navigate rows, any other key activates.
        if (_v.inMenu()) {
            if (pressed == 1) {
                if      (k == WatchUi.KEY_UP)   { _v.menuUp(); }
                else if (k == WatchUi.KEY_DOWN) { _v.menuDown(); }
                else                            { _v.menuSelect(); }
            }
            return true;
        }

        // Game-over: any key press restarts.
        if (pressed == 1 && _v.canStart()) {
            _v.doAction();
            WatchUi.requestUpdate();
            return true;
        }

        if (k == WatchUi.KEY_UP) {
            _v.setKeyRight(pressed);
        } else if (k == WatchUi.KEY_DOWN) {
            _v.setKeyLeft(pressed);
        } else if (pressed == 1) {
            // any other key: action (dash)
            _v.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() {
        if (_v.inMenu()) { _v.menuSelect(); WatchUi.requestUpdate(); return true; }
        _v.doAction(); WatchUi.requestUpdate(); return true;
    }
    function onPreviousPage() {
        if (_v.inMenu()) { _v.menuUp(); return true; }
        _v.doPrevPage(); WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_v.inMenu()) { _v.menuDown(); return true; }
        _v.doNextPage(); WatchUi.requestUpdate(); return true;
    }
    function onTap(evt) {
        if (_v.inMenu()) {
            var c = evt.getCoordinates();
            _v.menuTap(c[0], c[1]);
            WatchUi.requestUpdate();
            return true;
        }
        _v.doAction(); WatchUi.requestUpdate(); return true;
    }

    function onBack() {
        if (_v.doBack()) { WatchUi.requestUpdate(); return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
