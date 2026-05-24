// ═══════════════════════════════════════════════════════════════
// MainView.mc — Nonogram view.
//
// Two timers:
//   _tickT  (1000 ms) — drives the elapsed-time counter while PLAY
//   _drawT  ( 250 ms) — flushes dirty redraws so input feels snappy
//
// The view is otherwise a thin dispatcher onto GameController.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

class MainView extends WatchUi.View {
    var ctrl;
    hidden var _tickT;
    hidden var _drawT;
    hidden var _sw;
    hidden var _sh;

    function initialize() {
        View.initialize();
        ctrl   = new GameController();
        _tickT = null;
        _drawT = null;
        _sw    = 0; _sh = 0;
    }

    function onShow() {
        if (_tickT == null) { _tickT = new Timer.Timer(); }
        _tickT.start(method(:onSecond), 1000, true);
        if (_drawT == null) { _drawT = new Timer.Timer(); }
        _drawT.start(method(:onTick), 250, true);
    }
    function onHide() {
        if (_tickT != null) { _tickT.stop(); }
        if (_drawT != null) { _drawT.stop(); }
    }

    function onSecond() {
        ctrl.tickSecond();
        WatchUi.requestUpdate();
    }
    function onTick() {
        if (ctrl.dirty) { ctrl.dirty = false; WatchUi.requestUpdate(); }
    }

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        if (ctrl.state == NS_MENU) { UIManager.drawMenu(dc, _sw, _sh, ctrl); return; }
        if (ctrl.state == NS_WIN)  { UIManager.drawWin(dc, _sw, _sh, ctrl); return; }
        UIManager.drawPlay(dc, _sw, _sh, ctrl);
    }

    // ── Intents ────────────────────────────────────────────────
    function navUp() {
        if (ctrl.state == NS_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == NS_WIN)  { ctrl.nextLevel(); return; }
        var n = ctrl.grid.n;
        var i = ctrl.curR * n + ctrl.curC;
        i = (i - 1 + n * n) % (n * n);
        ctrl.setCursor(i / n, i % n);
    }
    function navDown() {
        if (ctrl.state == NS_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == NS_WIN)  { ctrl.restart(); return; }
        var n = ctrl.grid.n;
        var i = ctrl.curR * n + ctrl.curC;
        i = (i + 1) % (n * n);
        ctrl.setCursor(i / n, i % n);
    }
    function navSelect() {
        if (ctrl.state == NS_MENU) { ctrl.menuActivate(); return; }
        if (ctrl.state == NS_WIN) {
            if (ctrl.mode == NG_MODE_LEVELS) { ctrl.nextLevel(); }
            else                              { ctrl.gotoMenu();  }
            return;
        }
        ctrl.cycleCursor();
    }
    function navBack() {
        if (ctrl.state == NS_MENU) { return false; }
        ctrl.gotoMenu();
        return true;
    }

    function handleTap(x, y) {
        if (ctrl.state == NS_MENU) { _menuTap(x, y); return; }
        if (ctrl.state == NS_WIN) {
            if (ctrl.mode == NG_MODE_LEVELS) { ctrl.nextLevel(); }
            else                              { ctrl.gotoMenu();  }
            return;
        }
        var rc = UIManager.tapToCell(x, y);
        if (rc[0] < 0) { return; }
        ctrl.cycleAt(rc[0], rc[1]);
    }

    function handleHold(x, y) {
        if (ctrl.state != NS_PLAY) { return; }
        var rc = UIManager.tapToCell(x, y);
        if (rc[0] >= 0) {
            ctrl.setCursor(rc[0], rc[1]);
        }
        ctrl.markX();
    }

    function handleSwipe(dr, dc) {
        if (ctrl.state != NS_PLAY) { return; }
        ctrl.moveCursor(dr, dc);
    }

    hidden function _menuTap(x, y) {
        var rg = UIManager.rowGeom(_sw, _sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < NG_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                ctrl.setMenuRow(i); ctrl.menuActivate(); return;
            }
        }
    }
}
