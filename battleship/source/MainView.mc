// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renders the current GameController state.
//
// Stateless w.r.t. layout. Every frame asks UIManager to draw the
// screen appropriate for the current state. Caches the GridLayout
// returned by the most recent draw call so InputHandler.onTap can
// translate (px, py) → (r, c) without re-running layout math.
//
// No timer / game loop. Battleship is fully turn-based, so we only
// redraw when InputHandler calls `WatchUi.requestUpdate()`.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

// Animation tick rate.  ~22 fps is plenty for a brief overlay and
// keeps the rest of the (otherwise idle) battery cost negligible.
const ANIM_TICK_MS = 45;

class MainView extends WatchUi.View {
    var ctrl;
    var _layout;   // last GridLayout returned by drawSetup/drawAim/drawInfo
    hidden var _animTimer;
    hidden var _animTimerActive;

    function initialize() {
        View.initialize();
        ctrl              = new GameController();
        _layout           = null;
        _animTimer        = null;
        _animTimerActive  = false;
    }

    function onShow() {}
    function onHide() {
        if (_animTimer != null && _animTimerActive) {
            _animTimer.stop();
            _animTimerActive = false;
        }
    }

    // Timer callback — advance the fire animation and request a
    // redraw.  Stops automatically when the controller exits the
    // animation states (handled by `_syncAnimTimer`).
    function onAnimTick() {
        if (ctrl == null) { return; }
        ctrl.animAdvance();
        _syncAnimTimer();
        WatchUi.requestUpdate();
    }

    // Start / stop the animation timer so it only runs while the
    // controller is actually playing a fire animation.
    hidden function _syncAnimTimer() {
        var need = ctrl.isFiring();
        if (need && !_animTimerActive) {
            if (_animTimer == null) { _animTimer = new Timer.Timer(); }
            _animTimer.start(method(:onAnimTick), ANIM_TICK_MS, true);
            _animTimerActive = true;
        } else if (!need && _animTimerActive) {
            _animTimer.stop();
            _animTimerActive = false;
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (ctrl.state == GS_MENU) {
            UIManager.drawMenu(dc, ctrl, w, h);
            _layout = null;
        } else if (ctrl.state == GS_SETUP) {
            _layout = UIManager.drawSetup(dc, ctrl, w, h);
        } else if (ctrl.state == GS_AIM) {
            _layout = UIManager.drawAim(dc, ctrl, w, h);
        } else if (ctrl.state == GS_FIRE_PLAYER) {
            _layout = UIManager.drawFirePlayer(dc, ctrl, w, h);
        } else if (ctrl.state == GS_FIRE_AI) {
            _layout = UIManager.drawFireAI(dc, ctrl, w, h);
        } else if (ctrl.state == GS_INFO) {
            _layout = UIManager.drawInfo(dc, ctrl, w, h);
        } else {
            UIManager.drawOverlay(dc, ctrl, w, h);
            _layout = null;
        }
        _syncAnimTimer();
    }

    // Push the shared global-leaderboard panel for the current AI
    // difficulty.  Same variant the controller submits scores under, so
    // the player sees the board they are competing on.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, ctrl.lbVariant(), "BATTLESHIP");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Used by InputHandler.onTap to convert tap coords → (r, c).
    // Returns null if no grid is currently rendered or the tap was
    // outside the board.
    function cellAt(px, py) {
        if (_layout == null) { return null; }
        return _layout.cellAt(px, py);
    }
}
