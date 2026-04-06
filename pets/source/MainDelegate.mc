using Toybox.WatchUi;
using Toybox.Math;

class MainDelegate extends WatchUi.BehaviorDelegate {

    hidden var _pet;
    hidden var _view;

    function initialize(pet, view) {
        BehaviorDelegate.initialize();
        _pet = pet;
        _view = view;
    }

    function onPreviousPage() {
        if (_view.confirmReset) { _view.confirmReset = false; WatchUi.requestUpdate(); return true; }
        if (_pet.dilemmaType > 0) { _pet.resolveDilemma(1); WatchUi.requestUpdate(); return true; }
        _view.cycleAction(-1);
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        if (_view.confirmReset) { _view.confirmReset = false; WatchUi.requestUpdate(); return true; }
        if (_pet.dilemmaType > 0) { _pet.resolveDilemma(2); WatchUi.requestUpdate(); return true; }
        _view.cycleAction(1);
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() {
        if (!_pet.isAlive) {
            _pet.resetPet();
            var view = new SetupView(_pet);
            WatchUi.switchToView(view, new SetupDelegate(_pet, view), WatchUi.SLIDE_UP);
            return true;
        }

        if (_view.confirmReset) {
            _pet.resetPet();
            _view.confirmReset = false;
            var sv = new SetupView(_pet);
            WatchUi.switchToView(sv, new SetupDelegate(_pet, sv), WatchUi.SLIDE_UP);
            return true;
        }

        if (_pet.dilemmaType > 0) {
            _pet.resolveDilemma(1);
            WatchUi.requestUpdate();
            return true;
        }

        var idx = _view.actionIdx;
        if (idx == 0) {
            _pet.feed();
        }
        else if (idx == 1) {
            var gt = Math.rand().abs() % 5;
            if (gt == 0) {
                var gv = new MiniGameView(_pet);
                WatchUi.pushView(gv, new MiniGameDelegate(gv), WatchUi.SLIDE_UP);
            } else if (gt == 1) {
                var gv = new RushGameView(_pet);
                WatchUi.pushView(gv, new RushGameDelegate(gv), WatchUi.SLIDE_UP);
            } else if (gt == 2) {
                var gv = new ReactGameView(_pet);
                WatchUi.pushView(gv, new ReactGameDelegate(gv), WatchUi.SLIDE_UP);
            } else if (gt == 3) {
                var gv = new DodgeGameView(_pet);
                WatchUi.pushView(gv, new DodgeGameDelegate(gv), WatchUi.SLIDE_UP);
            } else {
                var gv = new MemoryGameView(_pet);
                WatchUi.pushView(gv, new MemoryGameDelegate(gv), WatchUi.SLIDE_UP);
            }
            return true;
        }
        else if (idx == 2) { _pet.clean(); }
        else if (idx == 3) { _pet.heal(); }
        else if (idx == 4) { _pet.nap(); }
        else if (idx == 5) { _pet.hug(); }
        else if (idx == 6) { _pet.punish(); }
        else if (idx == 7) {
            _view.confirmReset = true;
            WatchUi.requestUpdate();
            return true;
        }
        else if (idx == 8) {
            _pet.toggleDebug();
        }
        else if (idx == 9) {
            _pet.debugAddHours();
        }
        else if (idx == 10) {
            _pet.toggleVibe();
        }
        else if (idx == 11) {
            _pet.debugNextEvent();
        }

        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_view.confirmReset) { _view.confirmReset = false; WatchUi.requestUpdate(); return true; }
        _pet.save();
        return false;
    }
}
