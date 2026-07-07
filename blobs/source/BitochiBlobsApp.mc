using Toybox.Application;
using Toybox.WatchUi;

class BitochiBlobsApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("blobs"); }
    function onStop(state) {}
    function getInitialView() {
        // Root view is the shared unified menu; START launches the round view.
        return buildBlobsMenu();
    }
}
