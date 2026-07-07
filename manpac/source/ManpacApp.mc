using Toybox.Application;
using Toybox.WatchUi;

class ManpacApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("manpac"); }
    function onStop(state)  {}

    function getInitialView() {
        return buildManpacMenu();
    }
}
