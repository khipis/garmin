using Toybox.Application;
using Toybox.WatchUi;

class MemoApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("memo"); }
    function onStop(state) {}
    function getInitialView() {
        var view = new MemoView();
        return [view, new MemoDelegate(view)];
    }
}
