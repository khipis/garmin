using Toybox.WatchUi;

class BitochiChessDelegate extends WatchUi.BehaviorDelegate {
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
        var h = _view.doBack();
        WatchUi.requestUpdate();
        return h;
    }

    function onMenu() {
        var h = _view.doBack();
        WatchUi.requestUpdate();
        return h;
    }

    function onPreviousPage() {
        _view.doPrev();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.doNext();
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        _view.doTap(xy[0], xy[1]);
        WatchUi.requestUpdate();
        return true;
    }
}
