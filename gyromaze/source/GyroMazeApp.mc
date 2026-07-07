// GyroMazeApp.mc — Application entry point.
using Toybox.Application;

class GyroMazeApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("gyromaze"); }
    function onStop(state)  {}

    function getInitialView() {
        return buildGyroMazeMenu();
    }
}
