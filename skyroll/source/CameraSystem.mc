// ═══════════════════════════════════════════════════════════════
// CameraSystem.mc — Smooth isometric follow.
//
// Tracks the ball's iso position with a simple low-pass filter so
// the world doesn't jitter as the ball nudges around.  The ball is
// placed BELOW the screen centre so the player can see the path
// ahead — that's `SR_BALL_Y_OFFSET` pixels.
//
// Public outputs (consumed by RenderSystem):
//   cx, cy   — screen centre (from MainView.onUpdate)
//   camIX,   — iso X position the camera is currently pinned to
//   camIY    — iso Y position the camera is currently pinned to
// ═══════════════════════════════════════════════════════════════

class CameraSystem {

    var camIX;
    var camIY;

    hidden var _init;

    function initialize() {
        camIX = 0.0; camIY = 0.0;
        _init = false;
    }

    function reset()  { _init = false; camIX = 0.0; camIY = 0.0; }

    // Snap camera to a target without any smoothing (used at spawn).
    function snapTo(px, py) {
        var ix = (px - py) * SR_TILE_HW.toFloat();
        var iy = -(px + py) * SR_TILE_HH.toFloat();
        camIX = ix;
        camIY = iy;
        _init = true;
    }

    function tick(px, py) {
        var ix = (px - py) * SR_TILE_HW.toFloat();
        var iy = -(px + py) * SR_TILE_HH.toFloat();
        if (!_init) {
            camIX = ix; camIY = iy;
            _init = true;
            return;
        }
        var a = SR_CAM_LERP.toFloat() / 100.0;
        camIX = camIX + (ix - camIX) * a;
        camIY = camIY + (iy - camIY) * a;
    }

    // World (wx, wy) → screen pixel.  `cx`, `cy` are the screen
    // centre passed by RenderSystem.  Ball offset shifts the
    // camera so the ball sits SR_BALL_Y_OFFSET below screen mid.
    function worldToScreen(wx, wy, cx, cy) {
        var ix = (wx - wy) * SR_TILE_HW.toFloat();
        var iy = -(wx + wy) * SR_TILE_HH.toFloat();
        var sx = (ix - camIX).toNumber() + cx;
        var sy = (iy - camIY).toNumber() + cy + SR_BALL_Y_OFFSET;
        return [sx, sy];
    }
}
