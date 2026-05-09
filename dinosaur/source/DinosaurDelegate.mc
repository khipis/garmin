using Toybox.WatchUi;

class DinosaurDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    function initialize(view) { BehaviorDelegate.initialize(); _v = view; }

    // UP / SELECT / tap → jump
    function onSelect()       { _v.doJump();   WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.doJump();   WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doJump();   WatchUi.requestUpdate(); return true; }

    // DOWN → duck (phase 2+) or ground-pound while airborne
    function onNextPage()     { _v.doCrouch(); WatchUi.requestUpdate(); return true; }

    // physical keys: up = jump, down = duck
    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_DOWN) {
            _v.doCrouch();
        } else {
            _v.doJump();
        }
        WatchUi.requestUpdate();
        return true;
    }

    // BACK: pause / exit
    function onBack() {
        if (_v.doBack()) { WatchUi.requestUpdate(); return true; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
