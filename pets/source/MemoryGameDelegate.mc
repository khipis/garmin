using Toybox.WatchUi;

class MemoryGameDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Physical UP button → UP direction
    function onPreviousPage() {
        _view.inputDirection(MEM_DIR_UP);
        return true;
    }

    // Physical DOWN button → DOWN direction
    function onNextPage() {
        _view.inputDirection(MEM_DIR_DOWN);
        return true;
    }

    // SELECT button → RIGHT direction
    function onSelect() {
        _view.inputDirection(MEM_DIR_RIGHT);
        return true;
    }

    // MENU button → LEFT direction
    function onMenu() {
        _view.inputDirection(MEM_DIR_LEFT);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
