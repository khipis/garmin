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

class MainView extends WatchUi.View {
    var ctrl;
    var _layout;   // last GridLayout returned by drawSetup/drawAim/drawInfo

    function initialize() {
        View.initialize();
        ctrl    = new GameController();
        _layout = null;
    }

    function onShow() {}
    function onHide() {}

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
        } else if (ctrl.state == GS_INFO) {
            _layout = UIManager.drawInfo(dc, ctrl, w, h);
        } else {
            UIManager.drawOverlay(dc, ctrl, w, h);
            _layout = null;
        }
    }

    // Used by InputHandler.onTap to convert tap coords → (r, c).
    // Returns null if no grid is currently rendered or the tap was
    // outside the board.
    function cellAt(px, py) {
        if (_layout == null) { return null; }
        return _layout.cellAt(px, py);
    }
}
