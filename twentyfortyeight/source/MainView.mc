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

class MainView extends WatchUi.View {
    var ctrl;

    function initialize() {
        View.initialize();
        ctrl = new GameController();
    }

    function onShow() {}
    function onHide() {}

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
