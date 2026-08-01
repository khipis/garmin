// ═══════════════════════════════════════════════════════════════════════════
// BitochiTowerDefenseDelegate.mc — Input.
//
// Two-button rule: everything in the game must be reachable with UP / DOWN /
// SELECT / MENU alone, because most fenix and Forerunner watches have no
// touchscreen. SELECT confirms, MENU opens the ability sheet from the map and
// backs out of any open sheet. Touch is a shortcut on top, never the only way.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;

class BitochiTowerDefenseDelegate extends WatchUi.BehaviorDelegate {
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
        _view.toggleMenu();
        WatchUi.requestUpdate();
        return true;
    }

    // Long press doubles as "get me out of here" on watches whose MENU is
    // awkward to reach mid-game.
    function onHold(evt) {
        _view.toggleMenu();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        _view.navigate(-1);
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.navigate(1);
        WatchUi.requestUpdate();
        return true;
    }

    function onTap(evt) {
        var c = evt.getCoordinates();
        _view.tap(c[0], c[1]);
        WatchUi.requestUpdate();
        return true;
    }

    function onSwipe(evt) {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP)         { _view.navigate(-1); }
        else if (d == WatchUi.SWIPE_DOWN)  { _view.navigate(1); }
        else if (d == WatchUi.SWIPE_LEFT)  { _view.cancel(); }
        else if (d == WatchUi.SWIPE_RIGHT) { _view.doAction(); }
        else { return true; }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        return SaveResume.confirmExit("towerdefense", _view.method(:exportSave));
    }
}
