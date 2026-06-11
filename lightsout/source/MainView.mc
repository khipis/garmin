// ═══════════════════════════════════════════════════════════════
// MainView.mc — LightsOut view + 200 ms redraw timer.
//
// We don't have a continuous simulation, but a tiny timer keeps
// `dirty` flushes happening quickly so the UI feels responsive
// even on firmware that batches input events.
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
        ctrl   = new GameController();
        _timer = null;
        _sw    = 0; _sh = 0;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 200, true);
    }
    function onHide() { if (_timer != null) { _timer.stop(); } }

    function onTick() {
        if (ctrl.dirty) {
            ctrl.dirty = false;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        if (ctrl.state == LS_MENU) { UIManager.drawMenu(dc, _sw, _sh, ctrl); return; }
        if (ctrl.state == LS_WIN)  { UIManager.drawWin(dc, _sw, _sh, ctrl);  return; }
        UIManager.drawPlay(dc, _sw, _sh, ctrl);
    }

    // ── Intents ─────────────────────────────────────────────────
    function navUp() {
        if (ctrl.state == LS_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == LS_WIN)  { ctrl.nextLevel(); return; }
        // PLAY: scan-prev cursor.
        var n = ctrl.grid.n;
        var i = ctrl.curR * n + ctrl.curC;
        i = (i - 1 + n * n) % (n * n);
        ctrl.setCursor(i / n, i % n);
    }
    function navDown() {
        if (ctrl.state == LS_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == LS_WIN)  { ctrl.restart(); return; }
        var n = ctrl.grid.n;
        var i = ctrl.curR * n + ctrl.curC;
        i = (i + 1) % (n * n);
        ctrl.setCursor(i / n, i % n);
    }
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, ctrl.boardVariant(), "LIGHTS OUT");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function navSelect() {
        if (ctrl.state == LS_MENU) {
            if (ctrl.menuRow == LO_ROW_LEADERBOARD) { openLeaderboard(); return; }
            ctrl.menuActivate();
            return;
        }
        if (ctrl.state == LS_WIN)  {
            if (ctrl.mode == LO_MODE_LEVELS && ctrl.level < LO_TOTAL_LEVELS) {
                ctrl.nextLevel();
            } else {
                ctrl.gotoMenu();
            }
            return;
        }
        ctrl.pressCursor();
    }
    function navBack() {
        if (ctrl.state == LS_MENU) { return false; }
        ctrl.gotoMenu();
        return true;
    }

    function handleTap(x, y) {
        if (ctrl.state == LS_MENU) { _menuTap(x, y); return; }
        if (ctrl.state == LS_WIN) {
            if (ctrl.mode == LO_MODE_LEVELS && ctrl.level < LO_TOTAL_LEVELS) {
                ctrl.nextLevel();
            } else {
                ctrl.gotoMenu();
            }
            return;
        }
        var rc = UIManager.tapToCell(x, y);
        if (rc[0] < 0) { return; }
        ctrl.pressAt(rc[0], rc[1]);
    }

    function handleHold(x, y) {
        if (ctrl.state != LS_PLAY) { return; }
        // Long-hold anywhere = restart current level.
        ctrl.restart();
    }

    function handleSwipe(dr, dc) {
        if (ctrl.state != LS_PLAY) { return; }
        ctrl.moveCursor(dr, dc);
    }

    hidden function _menuTap(x, y) {
        var rg = UIManager.rowGeom(_sw, _sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < LO_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                ctrl.setMenuRow(i);
                if (i == LO_ROW_LEADERBOARD) { openLeaderboard(); return; }
                ctrl.menuActivate();
                return;
            }
        }
    }
}
