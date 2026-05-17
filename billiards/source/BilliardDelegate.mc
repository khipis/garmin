// ═══════════════════════════════════════════════════════════════
// BilliardDelegate.mc  —  InputHandler
// All input is forwarded to BilliardView which delegates to
// BilliardGame.  The delegate itself is state-agnostic.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;

class BilliardDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    function initialize(view) { BehaviorDelegate.initialize(); _v = view; }

    // Key layout (Fenix 8 physical buttons):
    //   KEY_UP   = top-left     → aim CCW
    //   KEY_MENU = middle-left  → aim CCW  ("środkowy lewy" button)
    //   KEY_DOWN = bottom-left  → aim CW   ("lewy dolny" button)
    //   KEY_ESC  = back/right   → go back
    //   any other (START)       → confirm shot
    function onKey(evt) {
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)   { _v.doUp();   }
        else if (k == WatchUi.KEY_MENU) { _v.doUp();   }
        else if (k == WatchUi.KEY_DOWN) { _v.doDown(); }
        else if (k == WatchUi.KEY_ESC)  { var h = _v.doBack(); WatchUi.requestUpdate(); return h; }
        else                            { _v.doSelect(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.doSelect(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.doUp();     WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.doDown();   WatchUi.requestUpdate(); return true; }
    function onBack()         { var h = _v.doBack(); WatchUi.requestUpdate(); return h; }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        _v.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
