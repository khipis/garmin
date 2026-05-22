// ═══════════════════════════════════════════════════════════════
// Physics.mc — Tunable constants + small kinematic helpers.
//
// One global tuning surface for the whole game. Numbers are in
// "screen pixels per tick" — ticks are fixed at 40 ms (~25 Hz) so
// a value of 1.0 translates to 25 px/sec.
//
// The values were hand-tuned for a 240×240 watch and scaled
// proportionally inside the controller for larger / smaller
// screens, so the feel stays constant across the device fleet.
// ═══════════════════════════════════════════════════════════════

class Physics {
    // Vertical motion
    static var GRAVITY      = 0.55;   // accel per tick²
    static var FLAP_VY      = -4.0;   // instantaneous vy on a flap
    static var MAX_FALL_VY  = 6.5;    // terminal fall velocity

    // Horizontal scroll of obstacles
    static var BASE_SCROLL  = 2.0;    // start scroll speed (px/tick)
    static var SCROLL_GAIN  = 0.04;   // added per point of score
    static var MAX_SCROLL   = 4.5;    // capped at this speed

    // Obstacle gap shrinks slowly as the player scores
    static var GAP_BASE     = 78;     // starting pixel gap on a 240 px screen
    static var GAP_MIN      = 52;     // never narrower than this
    static var GAP_SHRINK   = 1.2;    // px reduction per +5 score

    // Integrate vy with gravity, clamp to terminal velocity. Returns
    // new vy. Branchless on the common case.
    static function applyGravity(vy) {
        var v = vy + GRAVITY;
        if (v > MAX_FALL_VY) { v = MAX_FALL_VY; }
        return v;
    }
}
