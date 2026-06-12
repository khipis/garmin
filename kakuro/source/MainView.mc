// ═══════════════════════════════════════════════════════════════
// MainView.mc — Kakuro view + 500 ms timer for the clock.
//
// Owns the GameController.  Receives high-level intents from
// InputHandler and dispatches them based on the current state.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

class MainView extends WatchUi.View {
    var ctrl;
    hidden var _timer;
    hidden var _sw;
    hidden var _sh;

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _timer = null;
        _sw = 0; _sh = 0;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 500, true);
    }
    function onHide() { if (_timer != null) { _timer.stop(); } }

    function onTick() {
        if (ctrl.state == KS_PLAY) {
            ctrl.tickTimer();
            ctrl.dirty = true;
        }
        if (ctrl.dirty) {
            ctrl.dirty = false;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        if (ctrl.state == KS_MENU) { UIManager.drawMenu(dc, _sw, _sh, ctrl); return; }
        if (ctrl.state == KS_WIN)  { UIManager.drawWin(dc, _sw, _sh, ctrl);  return; }
        UIManager.drawPlay(dc, _sw, _sh, ctrl);
    }

    // ── Intents ─────────────────────────────────────────────────
    function navUp() {
        if (ctrl.state == KS_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == KS_WIN)  { ctrl.gotoMenu(); return; }
        ctrl.cycleCell(true);
    }
    function navDown() {
        if (ctrl.state == KS_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == KS_WIN)  { ctrl.gotoMenu(); return; }
        ctrl.cycleCell(false);
    }
    function navSelect() {
        if (ctrl.state == KS_MENU) {
            if (ctrl.isLeaderboardRow()) { openLeaderboard(); return; }
            ctrl.menuActivate();
            return;
        }
        if (ctrl.state == KS_WIN)  { ctrl.gotoMenu(); return; }
        ctrl.advanceCursor();
    }

    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, ctrl.lbVariant(), "KAKURO");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }
    function navBack() {
        if (ctrl.state == KS_MENU) { return false; }
        ctrl.gotoMenu();
        return true;
    }

    function handleTap(x, y) {
        if (ctrl.state == KS_MENU) { _menuTap(x, y); return; }
        if (ctrl.state == KS_WIN)  { ctrl.gotoMenu(); return; }
        var rc = UIManager.tapToCell(x, y);
        if (rc[0] < 0) {
            // Tap outside the board → cycle current cell.
            ctrl.cycleCell(true);
            return;
        }
        if (!ctrl.grid.isWhite(rc[0], rc[1])) { return; }
        if (ctrl.curR == rc[0] && ctrl.curC == rc[1]) {
            ctrl.cycleCell(true);
        } else {
            ctrl.setCursor(rc[0], rc[1]);
        }
    }

    function handleHold(x, y) {
        if (ctrl.state != KS_PLAY) { return; }
        var rc = UIManager.tapToCell(x, y);
        if (rc[0] < 0) { return; }
        if (!ctrl.grid.isWhite(rc[0], rc[1])) { return; }
        ctrl.setCursor(rc[0], rc[1]);
        ctrl.clearCell();
    }

    function handleSwipe(dr, dc) {
        if (ctrl.state != KS_PLAY) { return; }
        ctrl.moveCursor(dr, dc);
    }

    hidden function _menuTap(x, y) {
        var rg = UIManager.rowGeom(_sw, _sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < KK_MENU_NAV; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                ctrl.setMenuRow(i);
                if (ctrl.isLeaderboardRow()) { openLeaderboard(); }
                else                          { ctrl.menuActivate(); }
                return;
            }
        }
    }
}
