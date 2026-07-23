using Toybox.WatchUi;

class DinosaurDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    function initialize(view) { BehaviorDelegate.initialize(); _v = view; }

    // SELECT → activate the highlighted title row, otherwise jump.
    function onSelect() {
        if (_v.inTitle()) { _v.menuActivate(); }
        else              { _v.doJump(); }
        WatchUi.requestUpdate();
        return true;
    }

    // UP → move menu selection on the title, otherwise jump.
    function onPreviousPage() {
        if (_v.inTitle()) { _v.menuPrev(); }
        else              { _v.doJump(); }
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN → move menu selection on the title; otherwise duck / ground-pound.
    function onNextPage() {
        if (_v.inTitle()) { _v.menuNext(); }
        else              { _v.doCrouch(); }
        WatchUi.requestUpdate();
        return true;
    }

    // Tap → hit-test the title rows; otherwise jump / start.
    function onTap(evt) {
        if (_v.inTitle()) {
            var c = evt.getCoordinates();
            _v.handleTap(c[0], c[1]);
        } else {
            _v.doJump();
        }
        WatchUi.requestUpdate();
        return true;
    }

    // physical keys: on title UP/DOWN navigate, ENTER activates; in-game
    // up = jump, down = duck. BACK/ESC (bottom-right button) always exits,
    // it must never fall through to jump.
    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_ESC) { return onBack(); }
        if (_v.inTitle()) {
            if      (key == WatchUi.KEY_UP)   { _v.menuPrev(); }
            else if (key == WatchUi.KEY_DOWN) { _v.menuNext(); }
            else                              { _v.menuActivate(); }
        } else if (key == WatchUi.KEY_DOWN) {
            _v.doCrouch();
        } else {
            _v.doJump();
        }
        WatchUi.requestUpdate();
        return true;
    }

    // BACK (bottom-right button / bezel swipe): bail out of a run (saving
    // score) or leave the demo attract-loop, otherwise pop back to the
    // shared menu. Must always be consumed here — it must never fall
    // through to a jump/duck action.
    function onBack() {
        if (_v.doBack()) {
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
