// ═══════════════════════════════════════════════════════════════
// MainView.mc — Bomber view + game-loop timer.
//
// The game runs at 80 ms ticks (≈12.5 Hz).  That's well below the
// flame-decay step (320 ms) and the slowest enemy step (500 ms),
// so movement looks smooth and the watchdog is never close.  We
// always pass the constant `_DT_MS = 80` to the controller's tick
// rather than measuring wall clock — the simulation is fully
// deterministic, which is also useful if we ever want to add a
// recorded-replay mode.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

const _DT_MS = 80;

class MainView extends WatchUi.View {
    var ctrl;
    hidden var _timer;
    hidden var _sw;
    hidden var _sh;

    function initialize() {
        View.initialize();
        ctrl   = new GameController();
        _timer = null;
        _sw = 0; _sh = 0;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), _DT_MS, true);
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() {
        ctrl.tick(_DT_MS);
        if (ctrl.dirty) {
            ctrl.dirty = false;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        if (ctrl.state == BS_MENU) { UIManager.drawMenu(dc, _sw, _sh, ctrl); return; }
        if (ctrl.state == BS_WIN || ctrl.state == BS_OVER) {
            UIManager.drawEnd(dc, _sw, _sh, ctrl);
            return;
        }
        UIManager.drawPlay(dc, _sw, _sh, ctrl);
    }

    // ── Intents ───────────────────────────────────────────────
    function navUp() {
        if (ctrl.state == BS_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == BS_WIN)  { ctrl.nextLevel(); return; }
        if (ctrl.state == BS_OVER) { ctrl.restart(); return; }
        ctrl.move(-1, 0);
    }
    function navDown() {
        if (ctrl.state == BS_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == BS_WIN)  { ctrl.nextLevel(); return; }
        if (ctrl.state == BS_OVER) { ctrl.restart(); return; }
        ctrl.move(1, 0);
    }
    function navSelect() {
        if (ctrl.state == BS_MENU) { ctrl.menuActivate(); return; }
        if (ctrl.state == BS_WIN)  { ctrl.nextLevel(); return; }
        if (ctrl.state == BS_OVER) { ctrl.restart(); return; }
        ctrl.placeBomb();
    }
    function navBack() {
        if (ctrl.state == BS_MENU) { return false; }
        ctrl.gotoMenu();
        return true;
    }

    function handleTap(x, y) {
        if (ctrl.state == BS_MENU) { _menuTap(x, y); return; }
        if (ctrl.state == BS_WIN)  { ctrl.nextLevel(); return; }
        if (ctrl.state == BS_OVER) { ctrl.restart(); return; }
        var rc = UIManager.tapToCell(x, y);
        if (rc[0] < 0) { return; }
        var r = rc[0]; var c = rc[1];
        if (r == ctrl.py && c == ctrl.px) {
            ctrl.placeBomb();
            return;
        }
        var dr = 0; var dc = 0;
        if (r == ctrl.py - 1 && c == ctrl.px) { dr = -1; }
        else if (r == ctrl.py + 1 && c == ctrl.px) { dr =  1; }
        else if (c == ctrl.px - 1 && r == ctrl.py) { dc = -1; }
        else if (c == ctrl.px + 1 && r == ctrl.py) { dc =  1; }
        if (dr != 0 || dc != 0) { ctrl.move(dr, dc); }
    }

    function handleHold(x, y) {
        if (ctrl.state == BS_MENU) { return; }
        ctrl.restart();
    }

    function handleSwipe(dr, dc) {
        if (ctrl.state != BS_PLAY) { return; }
        ctrl.move(dr, dc);
    }

    hidden function _menuTap(x, y) {
        var rg = UIManager.rowGeom(_sw, _sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < BM_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                ctrl.setMenuRow(i); ctrl.menuActivate(); return;
            }
        }
    }
}
