// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Every input is a "flap" (single action game).
//
// BACK gives the player a way out of the game / overlay loop.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;

class InputHandler extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ESC) { return onBack(); }
        _v.handleFlap();
        WatchUi.requestUpdate();
        return true;
    }
    function onSelect()       { _v.handleFlap(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.handleFlap(); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.handleFlap(); WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.handleFlap(); WatchUi.requestUpdate(); return true; }
    function onSwipe(evt)     { _v.handleFlap(); WatchUi.requestUpdate(); return true; }
    function onHold(evt)      { _v.handleFlap(); WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (_v.handleBack()) {
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
