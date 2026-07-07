using Toybox.Application;
using Toybox.WatchUi;

// Shared global leaderboard identifier for this game (bitochi.com).
const LB_GAME_ID = "pets";

// The one canonical Pet instance for this app session. The unified menu's
// START launches gameplay on THIS instance, and onStop saves THIS instance,
// so the played pet and the exit-save never diverge.
var gPet = null;

// One-shot guard so the launch/support message is offered at most once per app
// session (MainView.onShow also fires when returning from pushed views).
var gPetsAnnounced = false;

class BitochiPetsApp extends Application.AppBase {

    hidden var _pet;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        Leaderboard.logLaunch(LB_GAME_ID);
        _pet = new Pet();
        _pet.load();
        gPet = _pet;
    }

    function onStop(state) {
        if (_pet != null) {
            _pet.save();
            // Report the creature-quality score on exit (save point). Only a
            // living, raised pet has a non-zero quality, so this never spams
            // a 0 during setup or after death.
            var q = _pet.getQualityScore();
            if (q > 0) {
                Leaderboard.submitScore(LB_GAME_ID, q, "");
            }
            // Good/Evil alignment board — lifetime karma across every pet
            // this player has ever raised (see Pet.reportKarma()).
            _pet.reportKarma();
        }
    }

    function getInitialView() {
        if (_pet == null) {
            _pet = new Pet();
            _pet.load();
        }
        gPet = _pet;
        return buildPetsMenu();
    }
}
