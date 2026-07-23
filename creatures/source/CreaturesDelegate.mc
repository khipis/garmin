// ═══════════════════════════════════════════════════════════════════════════
// CreaturesDelegate.mc — Input for the BITOCHI CREATURES view.
//
// Fully operable two ways:
//   • TOUCH: tap the top tab dots to jump pages, the ◀/▶ edge chevrons to page,
//     the DEMO pill to toggle the showcase, and on-screen buttons to act.
//   • BUTTONS: UP/DOWN move the cursor on list pages and overflow to the next/
//     previous page at the ends (or page directly elsewhere); SELECT/ENTER/START
//     activates the focused action; onNextPage/onPreviousPage + swipe also page.
// BACK saves and returns to the shared menu.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;

class CreaturesDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(v as CreaturesView) {
        BehaviorDelegate.initialize();
        _v = v;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ENTER || k == WatchUi.KEY_START) { _v.activate(); return true; }
        if (k == WatchUi.KEY_UP)    { _v.cursorMove(-1); return true; }
        if (k == WatchUi.KEY_DOWN)  { _v.cursorMove(1);  return true; }
        if (k == WatchUi.KEY_ESC)   { return onBack(); }
        return false;
    }

    function onSelect() { _v.activate(); return true; }

    // The up/down "page" behaviors (what the physical buttons emit on 2-button
    // touch watches, and what vertical swipes map to on many devices) move the
    // cursor through list positions — cursorMove overflow-pages at the ends, so
    // every page and row stays reachable with just up/down on ANY device.
    function onNextPage()     { _v.cursorMove(1);  return true; }
    function onPreviousPage() { _v.cursorMove(-1); return true; }

    function onSwipe(evt) {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_LEFT)  { _v.pageMove(1);  return true; }
        if (d == WatchUi.SWIPE_RIGHT) { _v.pageMove(-1); return true; }
        if (d == WatchUi.SWIPE_UP)    { _v.cursorMove(1);  return true; }
        if (d == WatchUi.SWIPE_DOWN)  { _v.cursorMove(-1); return true; }
        return true;
    }

    function onTap(evt) {
        try {
            var xy = evt.getCoordinates();
            return _v.onTapXY(xy[0], xy[1]);
        } catch (e) { return true; }
    }

    function onBack() {
        try { _v.model().save(); } catch (e) {}
        return false;   // let the framework pop back to the menu
    }
}
