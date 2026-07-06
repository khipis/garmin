// ═══════════════════════════════════════════════════════════════════════════
// ActivityBoardApp.mc — Application entry point for Bitochi Activity Board.
//
// Read your REAL watch stats (steps, active minutes, floors, distance,
// calories), get one signature FLEX SCORE, then slam any of them onto the
// global bitochi.com leaderboard and race the world — daily, weekly, all-time.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.WatchUi;

// Leaderboard game id — matches the id in bitochi.com's GAMES table.
const LB_GAME_ID = "activityboard";

class ActivityBoardApp extends Application.AppBase {
    function initialize()   { AppBase.initialize(); }

    // logLaunch pings the backend AND powers the shared communications system
    // (launch / one-shot 'once' payment call-to-action / reset messages).
    function onStart(state) { Leaderboard.logLaunch(LB_GAME_ID); }
    function onStop(state)  { }

    function getInitialView() {
        var v = new MainView();
        return [v, new InputHandler(v)];
    }
}
