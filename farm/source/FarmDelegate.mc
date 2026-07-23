// ═══════════════════════════════════════════════════════════════════════════
// FarmDelegate.mc — Input for FARM.
//
// Buttons and touch both work. SELECT/enter performs the current screen's
// action; UP/DOWN (and swipe up/down) move the cursor on list/grid screens or
// flip pages elsewhere; swipe left/right flips pages; tap hit-tests rows,
// grid cells and buttons; BACK saves and exits.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;

class FarmDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ENTER || k == WatchUi.KEY_START) { _v.activate(); return true; }
        if (k == WatchUi.KEY_UP)   { _v.cursorMove(-1); return true; }
        if (k == WatchUi.KEY_DOWN) { _v.cursorMove(1);  return true; }
        if (k == WatchUi.KEY_ESC)  { return onBack(); }
        return false;
    }

    function onSelect() { _v.activate(); return true; }
    // The up/down "page" behaviors (what the physical buttons emit on 2-button
    // touch watches, and what vertical swipes map to on many devices) move the
    // cursor through list positions — cursorMove overflow-pages at the ends, so
    // every page and row stays reachable with just up/down on ANY device.
    function onNextPage() { _v.cursorMove(1); return true; }
    function onPreviousPage() { _v.cursorMove(-1); return true; }

    function onSwipe(evt) {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_LEFT)  { _v.pageMove(1);  return true; }
        if (d == WatchUi.SWIPE_RIGHT) { _v.pageMove(-1); return true; }
        if (d == WatchUi.SWIPE_UP)    { _v.cursorMove(1);  return true; }
        if (d == WatchUi.SWIPE_DOWN)  { _v.cursorMove(-1); return true; }
        return false;
    }

    function onTap(evt) {
        var c = evt.getCoordinates();
        return _v.onTapXY(c[0], c[1]);
    }

    function onBack() {
        try { _v.model().save(); } catch (e) {}
        return false;
    }
}
