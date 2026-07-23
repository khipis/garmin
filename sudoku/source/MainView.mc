// ═══════════════════════════════════════════════════════════════
// MainView.mc — WatchUi.View glue.
//
// Owns the GameController and UIManager. Receives high-level input
// intents from InputHandler and dispatches them based on the active
// game state. A 500 ms timer ticks the play-clock; redraws are only
// requested when the controller marks itself dirty (or on input).
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.System;

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _ui;
    hidden var _timer;
    hidden var _started;   // auto-start the puzzle on first frame

    function initialize() {
        View.initialize();
        _ctrl  = new GameController();
        _ui    = new UIManager();
        _timer = null;
        _started = false;
    }

    function onLayout(dc) {
        _ui.layout(dc, _ctrl.grid.n, _ctrl.state);
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 500, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() {
        // While playing, update the elapsed clock and ask for a redraw
        // so the HUD time stays accurate.
        if (_ctrl.state == GS_PLAY) {
            _ctrl.tickTimer();
            _ctrl.dirty = true;
        }
        if (_ctrl.dirty) {
            _ctrl.dirty = false;
            WatchUi.requestUpdate();
        }
    }

    // ── Drawing ──────────────────────────────────────────────────────
    function onUpdate(dc) {
        // Menu lives in the shared root view — drop straight into a puzzle and
        // never render an in-game menu here.
        if (!_started || _ctrl.state == GS_MENU) {
            _ctrl.startGame();
            _started = true;
        }
        _ui.drawBoard(dc, _ctrl);
        _ui.drawHUD(dc, _ctrl);
        _ui.drawFooter(dc, _ctrl);
        if (_ctrl.state == GS_PAUSED)   { _ui.drawPaused(dc);          }
        if (_ctrl.state == GS_COMPLETE) { _ui.drawComplete(dc, _ctrl); }
        if (_ctrl.state == GS_FAILED)   { _ui.drawFailed(dc, _ctrl);   }
    }

    // ── Public intents (called from InputHandler) ────────────────────
    function navUp() {
        if (_ctrl.state == GS_PLAY)    { _ctrl.cycleCell(true); return; }
        if (_ctrl.state == GS_PAUSED)  { _ctrl.resume();        return; }
        if (_ctrl.state == GS_COMPLETE) { _ctrl.startGame();       return; }
        if (_ctrl.state == GS_FAILED)   { _ctrl.resumeFromFailed(); return; }
    }

    function navDown() {
        if (_ctrl.state == GS_PLAY)    { _ctrl.cycleCell(false); return; }
        if (_ctrl.state == GS_PAUSED)  { _ctrl.resume();         return; }
        if (_ctrl.state == GS_COMPLETE) { _ctrl.startGame();       return; }
        if (_ctrl.state == GS_FAILED)   { _ctrl.resumeFromFailed(); return; }
    }

    function navSelect() {
        if (_ctrl.state == GS_PLAY) {
            // Move cursor right → next row when wrapping. Quick way to
            // step through cells with a single button on non-touch
            // watches.
            var n = _ctrl.grid.n;
            var nc = _ctrl.curC + 1;
            var nr = _ctrl.curR;
            if (nc >= n) { nc = 0; nr = (nr + 1) % n; }
            _ctrl.curR = nr; _ctrl.curC = nc;
            _ctrl.dirty = true;
            return;
        }
        if (_ctrl.state == GS_PAUSED)   { _ctrl.resume();          return; }
        if (_ctrl.state == GS_COMPLETE) { _ctrl.startGame();       return; }
        if (_ctrl.state == GS_FAILED)   { _ctrl.resumeFromFailed(); return; }
    }

    // BACK semantics depend on state:
    //   play      → strict: submit board; relaxed: pop to shared menu
    //   failed    → resume to play (so user can fix)
    //   paused / complete → pop to shared menu
    function navBack() {
        if (_ctrl.state == GS_PLAY) {
            if (_ctrl.valMode == VAL_STRICT) {
                _ctrl.submit();
                return true;
            }
            return false;   // pop back to the shared unified menu
        }
        if (_ctrl.state == GS_FAILED) {
            // Drop back into play so the player can fix mistakes.
            _ctrl.resumeFromFailed();
            return true;
        }
        // PAUSED / COMPLETE / anything else → let the framework pop the view.
        return false;
    }

    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _ctrl.lbVariant(), "SUDOKU");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function handleTap(x, y) {
        if (_ctrl.state == GS_PAUSED)   { _ctrl.resume();          return; }
        if (_ctrl.state == GS_COMPLETE) { _ctrl.startGame();       return; }
        if (_ctrl.state == GS_FAILED)   { _ctrl.resumeFromFailed(); return; }
        if (_ctrl.state != GS_PLAY) { return; }
        // Pick the cell under the tap.
        var rc = _ui.tapToCell(x, y, _ctrl.grid.n);
        if (rc[0] < 0) {
            // Tap outside the board cycles the current cell's digit
            // (handy on tiny screens where it's tricky to hit a cell).
            _ctrl.cycleCell(true);
            return;
        }
        if (_ctrl.curR == rc[0] && _ctrl.curC == rc[1]) {
            // Tapping the already-selected cell cycles its digit.
            _ctrl.cycleCell(true);
        } else {
            _ctrl.curR = rc[0]; _ctrl.curC = rc[1];
            _ctrl.dirty = true;
        }
    }

    function handleHold(x, y) {
        if (_ctrl.state != GS_PLAY) { return; }
        var rc = _ui.tapToCell(x, y, _ctrl.grid.n);
        if (rc[0] < 0) { return; }
        _ctrl.curR = rc[0]; _ctrl.curC = rc[1];
        _ctrl.clearCell();
    }

    function handleSwipe(dir) {
        if (_ctrl.state != GS_PLAY) { return; }
        if      (dir == WatchUi.SWIPE_UP)    { _ctrl.moveCursor(-1, 0); }
        else if (dir == WatchUi.SWIPE_DOWN)  { _ctrl.moveCursor( 1, 0); }
        else if (dir == WatchUi.SWIPE_LEFT)  { _ctrl.moveCursor( 0,-1); }
        else if (dir == WatchUi.SWIPE_RIGHT) { _ctrl.moveCursor( 0, 1); }
    }
}
