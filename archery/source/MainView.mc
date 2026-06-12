// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer + game-loop timer.
//
// Each tick we:
//   1. Snapshot the accelerometer (silent fallback if unavailable).
//   2. Advance the game (`ctrl.tickGame()`).
//   3. Request a redraw.
//
// `ctrl.tickGame()` itself feeds the snapshot into the gyro system
// so that aim updates land in the same frame as physics + render.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Sensor;

class MainView extends WatchUi.View {

    var ctrl;
    hidden var _timer;

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _timer = null;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), AR_TICK_MS, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
        ctrl.savePrefs();
    }

    function onTick() {
        try {
            var info = Sensor.getInfo();
            if (info != null && (info has :accel) && info.accel != null) {
                var a = info.accel;
                if (a != null && a.size() >= 2) {
                    ctrl.lastAx = a[0];
                    ctrl.lastAy = a[1];
                }
            }
        } catch (e) {}
        ctrl.tickGame();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        ctrl.syncDims(dc.getWidth(), dc.getHeight());
        UIManager.draw(dc, ctrl);
    }

    // ── Intents from InputHandler ───────────────────────────
    function navUp() {
        if (ctrl.state == AR_DEMO) { ctrl.gotoMenu(); return; }
        if (ctrl.state == AR_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == AR_OVER || ctrl.state == AR_WIN) { ctrl.gotoMenu(); return; }
        ctrl.recalibrate();
    }
    function navDown() {
        if (ctrl.state == AR_DEMO) { ctrl.gotoMenu(); return; }
        if (ctrl.state == AR_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == AR_OVER || ctrl.state == AR_WIN) { ctrl.gotoMenu(); return; }
    }
    function navSelect() {
        if (ctrl.state == AR_DEMO) { ctrl.gotoMenu(); return; }
        if (ctrl.state == AR_MENU) {
            if (ctrl.menuRow == AR_ROW_LB) { openLeaderboard(); return; }
            ctrl.menuActivate(); return;
        }
        if (ctrl.state == AR_OVER || ctrl.state == AR_WIN) { ctrl.restart(); return; }
    }

    // Open the shared global leaderboard for the current difficulty.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, ctrl.diffName(), "ARCHERY");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }
    function navBack() {
        if (ctrl.state != AR_MENU) { ctrl.gotoMenu(); return true; }
        return false;
    }

    function startDraw()   { ctrl.startDraw(); }
    function releaseDraw() { ctrl.releaseDraw(); }

    function handleTap(x, y) {
        if (ctrl.state == AR_DEMO) { ctrl.gotoMenu(); return; }
        if (ctrl.state == AR_MENU) {
            var rg = UIManager.rowGeom(ctrl.sw, ctrl.sh);
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < AR_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    ctrl.setMenuRow(i);
                    if (i == AR_ROW_LB) { openLeaderboard(); }
                    else { ctrl.menuActivate(); }
                    return;
                }
            }
            return;
        }
        if (ctrl.state == AR_OVER || ctrl.state == AR_WIN) { ctrl.restart(); return; }
    }
}
