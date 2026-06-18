using Toybox.Application;
using Toybox.WatchUi;

class BitochiBlobsApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("blobs"); }
    function onStop(state) {}
    function getInitialView() {
        var view = new BitochiBlobsView();
        return [view, new BitochiBlobsDelegate(view)];
    }
}
