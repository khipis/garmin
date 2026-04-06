using Toybox.WatchUi;

class DodgeGameDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        return true;
    }

    function onPreviousPage() {
        _view.moveLeft();
        return true;
    }

    function onNextPage() {
        _view.moveRight();
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
