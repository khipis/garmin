using Toybox.WatchUi;

class DinosaurDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;
    function initialize(view) { BehaviorDelegate.initialize(); _v = view; }

    function onSelect()       { _v.doAction(); WatchUi.requestUpdate(); return true; }
    function onNextPage()     { _v.doAction(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _v.doAction(); WatchUi.requestUpdate(); return true; }
    function onBack()         { if (_v.doBack()) { WatchUi.requestUpdate(); return true; } WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onKey(evt)       { _v.doAction(); WatchUi.requestUpdate(); return true; }
    function onTap(evt)       { _v.doAction(); WatchUi.requestUpdate(); return true; }
}
