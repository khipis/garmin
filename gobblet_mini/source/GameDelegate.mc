using Toybox.WatchUi;

// Controls
//   UP / DOWN               → move grid cursor row
//   Previous Page / LEFT    → move grid cursor left  OR cycle size picker left
//   Next Page / RIGHT       → move grid cursor right OR cycle size picker right
//   SELECT / tap            → pick source / confirm size / place piece / new game
//   BACK                    → cancel current selection

class GameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onKey(evt) {
        if (evt.getType() != 0) { return false; }
        var k = evt.getKey();
        if      (k == WatchUi.KEY_UP)   { _v.navigate(0); }
        else if (k == WatchUi.KEY_DOWN) { _v.navigate(1); }
        else                            { _v.doAction(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect()       { _v.doAction();  WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.navigate(2); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.navigate(3); WatchUi.requestUpdate(); return true; }
    function onTap(evt) {
        var xy = evt.getCoordinates();
        _v.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate(); return true;
    }

    function onBack() {
        if (!_v.doBack()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }
}
