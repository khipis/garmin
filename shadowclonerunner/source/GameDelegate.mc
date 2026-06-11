using Toybox.WatchUi;

class GameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    function initialize(view) { BehaviorDelegate.initialize(); _v = view; }

    function onSelect() {
        if (_v.inTitle()) { _v.menuActivate(); }
        else { _v.doJump(); }
        WatchUi.requestUpdate();
        return true;
    }
    function onPreviousPage() {
        if (_v.inTitle()) { _v.menuUp(); }
        else { _v.doJump(); }
        WatchUi.requestUpdate();
        return true;
    }
    function onNextPage() {
        if (_v.inTitle()) { _v.menuDown(); }
        else { _v.doDuck(); }
        WatchUi.requestUpdate();
        return true;
    }
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

    function onKey(evt) {
        var k = evt.getKey();
        if (_v.inTitle()) {
            if      (k == WatchUi.KEY_UP)    { _v.menuUp(); }
            else if (k == WatchUi.KEY_DOWN)  { _v.menuDown(); }
            else if (k == WatchUi.KEY_ENTER) { _v.menuActivate(); }
            WatchUi.requestUpdate();
            return true;
        }
        if (k == WatchUi.KEY_DOWN) { _v.doDuck(); }
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
