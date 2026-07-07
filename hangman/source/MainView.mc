// ═══════════════════════════════════════════════════════════════
// MainView.mc — Renders the current GameController state.
//
// Stateless w.r.t. layout — every frame asks UIManager to draw and
// caches the keyboard layout returned by drawGame() so input taps
// can be mapped back to a letter index.
//
// No game loop / timer needed: redraws happen on demand whenever
// InputHandler calls WatchUi.requestUpdate().
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;

class MainView extends WatchUi.View {
    var ctrl;
    var _kb;       // cached KbLayout from last draw (for tap routing)
    var _w;
    var _h;
    hidden var _started;   // auto-start a round on first layout

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _kb = null;
        _w = 0;
        _h = 0;
        _started = false;
    }

    function onShow() {}
    function onHide() {}

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        // Menu lives in the shared root view — drop straight into a round and
        // never render an in-game menu here.
        if (!_started || ctrl.state == GS_MENU) {
            ctrl.startGame();
            _started = true;
        }
        if (ctrl.state == GS_PLAY) {
            _kb = UIManager.drawGame(dc, ctrl, _w, _h);
        } else {
            UIManager.drawOverlay(dc, ctrl, _w, _h);
            _kb = null;
        }
    }

    // InputHandler.onTap() calls this to translate (px, py) → letter idx.
    // If the keyboard layout hasn't been cached yet (e.g. the very
    // first tap after entering GS_PLAY arrives before onUpdate has run),
    // build a fresh layout on the fly so the tap is still resolved.
    function letterAtTap(coords) {
        if (coords == null) { return -1; }
        var kb = _kb;
        if (kb == null) {
            if (_w <= 0 || _h <= 0) {
                // Worst-case fallback for absolute first-tap before any
                // draw has ever happened — use the system info screen
                // dimensions so we still resolve to a letter.
                var dev = System.getDeviceSettings();
                _w = dev.screenWidth;
                _h = dev.screenHeight;
            }
            kb = UIManager.layoutKeyboard(_w, _h);
        }
        return kb.indexAt(coords[0], coords[1]);
    }
}
