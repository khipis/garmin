// ═══════════════════════════════════════════════════════════════
// Physics.mc — Tunable constants + integration helper.
//
// All numbers are in "screen pixels per tick" (tick = 40 ms ≈ 25 Hz)
// for the 240 px reference height. GameController scales them at
// runtime for taller/shorter screens so the feel stays consistent
// across the device fleet (218 px Chronos → 448 px Venu X1).
// ═══════════════════════════════════════════════════════════════

class Physics {
    // Vertical
    static var GRAVITY     = 0.42;    // accel per tick²
    static var JUMP_VY     = -7.5;    // velocity applied on platform contact
    static var MAX_FALL_VY = 10.0;    // terminal velocity (downward)

    // Horizontal
    static var MOVE_VX     = 3.6;     // px/tick while holding left/right
    static var FRICTION    = 0.85;    // multiplier on tap-impulse vx each tick

    // World scroll
    // The camera follows the player upward only — it never scrolls
    // down. When the player's screen-y rises above SCROLL_LINE_PCT
    // of the screen height, the world shifts down to keep them at
    // that line. Score = total distance the world has scrolled.
    static var SCROLL_LINE_PCT = 40;  // % from top where camera locks

    // Apply gravity + clamp to terminal velocity. Branchless on hot path.
    static function applyGravity(vy) {
        var v = vy + GRAVITY;
        if (v > MAX_FALL_VY) { v = MAX_FALL_VY; }
        return v;
    }
}
