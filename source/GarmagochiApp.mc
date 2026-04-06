using Toybox.Application;
using Toybox.WatchUi;

class GarmagochiApp extends Application.AppBase {

    hidden var _pet;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        _pet = new Pet();
        _pet.load();
    }

    function onStop(state) {
        if (_pet != null) {
            _pet.save();
        }
    }

    function getInitialView() {
        if (_pet == null) {
            _pet = new Pet();
            _pet.load();
        }
        if (!_pet.isCreated) {
            var view = new SetupView(_pet);
            return [view, new SetupDelegate(_pet, view)];
        }
        var view = new MainView(_pet);
        return [view, new MainDelegate(_pet, view)];
    }
}
