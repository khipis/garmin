// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renders the current GameController state.
//
// Stateless w.r.t. layout. Every frame asks UIManager to draw the
// appropriate screen for the current state. There is NO game loop
// or timer — redraws are demand-driven via WatchUi.requestUpdate()
// from InputHandler whenever something actually changed.
//
// This is critical for battery & watchdog safety: 2048 is purely
// turn-based, so we never paint when nothing changed.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

class MainView extends WatchUi.View {
    var ctrl;
    hidden var _timer;

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _timer = null;
    }

    // A 1 s tick drives the live stopwatch — it only does work in Time mode
    // while playing, so Classic stays the original demand-driven, no-loop game.
    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 1000, true);
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }
    function onTick() {
        if (ctrl.timeMode && ctrl.state == GS_PLAY) {
            ctrl.tickTimer();
            WatchUi.requestUpdate();
        }
    }

    // Open the shared global leaderboard view (prompts for a name first run).
    // Time mode shows the speedrun board; Classic shows the score board.
    function openLeaderboard() {
        var v;
        if (ctrl.timeMode) {
            v = new LbScoresView(LB_GAME_ID_TIME, "", "2048 TIME");
        } else {
            v = new LbScoresView(LB_GAME_ID, "", "2048");
        }
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (ctrl.state == GS_MENU) {
            UIManager.drawMenu(dc, ctrl, w, h);
        } else if (ctrl.state == GS_PLAY) {
            UIManager.drawGame(dc, ctrl, w, h);
        } else {
            UIManager.drawOverlay(dc, ctrl, w, h);
        }
    }
}
