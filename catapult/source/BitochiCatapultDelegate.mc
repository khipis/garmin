using Toybox.WatchUi;

class BitochiCatapultDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.doAction();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        return false;
    }
}
