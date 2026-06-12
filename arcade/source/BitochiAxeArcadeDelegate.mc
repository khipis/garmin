using Toybox.WatchUi;

class BitochiAxeArcadeDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() { _view.doAction(); WatchUi.requestUpdate(); return true; }
    function onMenu() { _view.doAction(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { _view.menuOrAction(-1); WatchUi.requestUpdate(); return true; }
    function onNextPage() { _view.menuOrAction(1); WatchUi.requestUpdate(); return true; }

    function onTap(evt) {
        if (_view.inMenu()) {
            var c = evt.getCoordinates();
            _view.handleTap(c[0], c[1]);
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate();
        return true;
    }
}
