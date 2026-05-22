// ═══════════════════════════════════════════════════════════════
// InputHandler.mc — Maps every input source to "drop / confirm".
//
// Stack Tower has exactly one game action — drop the moving block —
// so every key, tap or swipe routes to the same intent. BACK exits.
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
        _v.handleDrop();
        WatchUi.requestUpdate();
        return true;
    }
    function onSelect()       { _v.handleDrop(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.handleDrop(); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.handleDrop(); WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.handleDrop(); WatchUi.requestUpdate(); return true; }
    function onSwipe(evt)     { _v.handleDrop(); WatchUi.requestUpdate(); return true; }
    function onHold(evt)      { _v.handleDrop(); WatchUi.requestUpdate(); return true; }

    function onBack() {
        if (_v.handleBack()) {
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
