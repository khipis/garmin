using Toybox.WatchUi;

class MemoryGameDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.inputDirection(0);
        return true;
    }

    function onMenu() {
        _view.inputDirection(1);
        return true;
    }

    function onPreviousPage() {
        _view.inputDirection(2);
        return true;
    }

    function onNextPage() {
        _view.inputDirection(3);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
