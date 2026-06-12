// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renderer + 80 ms game-loop timer for VoidRocks.
//
// On every tick we push (sw, sh) into the controller so it knows
// the wrap-around box.  The timer keeps firing in all states; in
// non-PLAY states `ctrl.tick()` early-returns.
//
// Steering uses the watch's accelerometer: each tick we read the
// gravity vector projected onto the watch face and forward it to
// `ctrl.handleTilt(ax, ay)`.  The controller turns that into the
// ship's heading (and a thrust burst when the wrist is tilted
// hard).  If the firmware doesn't expose the accelerometer we
// silently fall back to button-only thrust + tap-to-fire — every
// call is wrapped in try/catch.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Sensor;

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
        _timer.start(method(:onTick), 80, true);
    }
    function onHide() { if (_timer != null) { _timer.stop(); } }
    function onTick() {
        // Read accel BEFORE ticking the controller so the angle
        // update lines up with this frame's render.  On modern
        // fenix/forerunner firmware `Sensor.getInfo().accel` returns
        // the latest gravity vector in milli-G as Array<Number>; on
        // devices that don't expose it the field is null and we just
        // skip — buttons still work as a thrust fallback.
        try {
            var info = Sensor.getInfo();
            if (info != null && (info has :accel) && info.accel != null) {
                var a = info.accel;
                if (a != null && a.size() >= 2) {
                    ctrl.handleTilt(a[0], a[1]);
                }
            }
        } catch (e) {}
        ctrl.tick();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        ctrl.syncDims(_sw, _sh);

        dc.setColor(0x000510, 0x000510); dc.clear();

        if (ctrl.state == VR_MENU) {
            UIManager.drawMenu(dc, _sw, _sh, ctrl); return;
        }
        UIManager.drawStars(dc, _sw, _sh);
        UIManager.drawAsteroids(dc, ctrl.rocks.rocks, _sw, _sh);
        UIManager.drawBullets(dc, ctrl.bullets.bullets);
        UIManager.drawShip(dc, ctrl.ship);
        UIManager.drawHUD(dc, _sw, _sh, ctrl);
        _drawFooter(dc);
        if (ctrl.state == VR_OVER) {
            UIManager.drawResult(dc, _sw, _sh, ctrl);
        }
    }

    hidden function _drawFooter(dc) {
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        var hint;
        if (ctrl.state == VR_PLAY) { hint = "tilt/UP turn  DN thrust  tap fire"; }
        else                        { hint = "tap = menu"; }
        dc.drawText(_sw / 2, _sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Intents from InputHandler ────────────────────────────────
    // PLAY layout (user request):
    //   tilt   → rotate ship
    //   UP     → rotate LEFT (backup for tilt)
    //   DOWN   → THRUST       (engine)
    //   SELECT → FIRE         (backup)
    //   tap    → FIRE
    function navUp() {
        if (ctrl.state == VR_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == VR_OVER) { ctrl.gotoMenu(); return; }
        ctrl.rotL();
    }
    function navDown() {
        if (ctrl.state == VR_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == VR_OVER) { ctrl.gotoMenu(); return; }
        ctrl.thrust();
    }
    function navSelect() {
        if (ctrl.state == VR_MENU) {
            if (ctrl.menuRow == VR_ROW_LB) { openLeaderboard(); return; }
            ctrl.menuActivate(); return;
        }
        if (ctrl.state == VR_OVER) { ctrl.gotoMenu(); return; }
        ctrl.fire();
    }

    // Open the shared global leaderboard for the current difficulty.
    function openLeaderboard() {
        var v = new LbScoresView(VR_LB_GAME_ID, ctrl.difficultyName(), "VOID ROCKS");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }
    function navBack() {
        if (ctrl.state != VR_MENU) { ctrl.gotoMenu(); return true; }
        return false;
    }

    function handleTap(x, y) {
        if (ctrl.state == VR_MENU) {
            var rg = UIManager.rowGeom(_sw, _sh);
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < VR_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    ctrl.setMenuRow(i);
                    if (i == VR_ROW_LB) { openLeaderboard(); }
                    else { ctrl.menuActivate(); }
                    return;
                }
            }
            return;
        }
        if (ctrl.state == VR_OVER) { ctrl.gotoMenu(); return; }
        ctrl.fire();
    }
}
