// ═══════════════════════════════════════════════════════════════
// PlayerSystem.mc — Lumberjack side + swing/shake animation state.
//
// The player is always attached to the trunk; the only thing that
// changes is which side they stand on. Side changes are instant
// (snap, no tween) — `swingT` / `shakeT` are purely cosmetic
// countdowns consumed by RenderSystem and never affect gameplay.
// ═══════════════════════════════════════════════════════════════
class PlayerSystem {
    var side;    // SIDE_LEFT or SIDE_RIGHT
    var swingT;  // frames left of the axe-swing pose
    var shakeT;  // frames left of the death shake

    function initialize() { reset(); }

    function reset() {
        side   = SIDE_RIGHT;
        swingT = 0;
        shakeT = 0;
    }

    function setSide(s) { side = s; }

    // Instant chop feedback — never gates or delays the next input.
    function swing() { swingT = SWING_FRAMES; }

    function die() { shakeT = DEAD_SHAKE_FRAMES; }

    function step() {
        if (swingT > 0) { swingT = swingT - 1; }
        if (shakeT > 0) { shakeT = shakeT - 1; }
    }
}
