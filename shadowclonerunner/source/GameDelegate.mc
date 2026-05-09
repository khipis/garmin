using Toybox.WatchUi;

class GameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    function initialize(view) { BehaviorDelegate.initialize(); _v = view; }

    function onSelect()       { _v.doJump();   WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.doJump();   WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.doDuck();   WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doJump();   WatchUi.requestUpdate(); return true; }

    function onKey(evt) {
        if (evt.getKey() == WatchUi.KEY_DOWN) { _v.doDuck(); }
        else { _v.doJump(); }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_v.doBack()) { WatchUi.requestUpdate(); return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
