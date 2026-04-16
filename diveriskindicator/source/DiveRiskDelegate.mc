// DiveRiskDelegate.mc — input mapping

using Toybox.WatchUi;

class DiveRiskDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.doSelect();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        var consumed = _view.doBack();
        WatchUi.requestUpdate();
        return consumed;
    }

    function onPreviousPage() {
        _view.doUp();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.doDown();
        WatchUi.requestUpdate();
        return true;
    }

    function onKey(evt) {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP)    { _view.doUp();     WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_DOWN)  { _view.doDown();   WatchUi.requestUpdate(); return true; }
        if (key == WatchUi.KEY_ENTER) { _view.doSelect(); WatchUi.requestUpdate(); return true; }
        return false;
    }

    function onTap(evt) {
        var c = evt.getCoordinates();
        _view.doTap(c[0], c[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
