// ═══════════════════════════════════════════════════════════════
// BallisticsSystem.mc — Simplified bullet trajectory.
//
// The bullet is parameterised in TWO halves:
//
//   • Muzzle direction in WORLD angular coords
//     (aimYawAtFire, aimPitchAtFire) — locked at fire time.
//     The renderer projects this through the CURRENT gaze each
//     frame, so moving the reticle after the shot makes the
//     world-anchored trace SLIDE on the scope (correct), instead
//     of the trace following the reticle (the old bug).
//
//   • Drift in SCREEN pixel units from that muzzle direction
//     (dx, dy) — accumulated each tick from gravity (vy) and wind
//     (vx).  This is independent of the player's gaze post-fire.
//
//   bullet_screen = project(aimYawAtFire, aimPitchAtFire,
//                            current_gaze)  +  (dx, dy)
//
// Hit resolution happens once maxTtl elapses.  GameController
// pulls the projected bullet position via screenAt(), passes the
// CURRENT-frame target screens to CollisionSystem, and the impact
// lands in the same frame the player sees on the RESULT screen.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class BallisticsSystem {

    var live;        // 0 / 1
    var dx;          // drift x (px, from muzzle direction)
    var dy;          // drift y (px, from muzzle direction)
    var vx;
    var vy;
    var ttl;         // ticks lived so far
    var maxTtl;      // expected travel ticks for the target distance
    var targetIdx;   // which TargetManager slot we're shooting at
    var aimYawAtFire;
    var aimPitchAtFire;

    function initialize() {
        live = 0; dx = 0.0; dy = 0.0; vx = 0.0; vy = 0.0;
        ttl  = 0; maxTtl = 0; targetIdx = -1;
        aimYawAtFire = 0.0; aimPitchAtFire = 0.0;
    }

    // Fire a shot.
    //   aimYaw, aimPitch — player's final aim direction at fire time
    //                       (gaze + sway), in WORLD radians.  Locked
    //                       in for the rest of the bullet's life.
    //   targetZ           — abstract "metres" — sets expected flight
    //                       time so longer shots drop more.
    //   tIdx              — TargetManager slot we pre-picked for the
    //                       distance estimate (CollisionSystem still
    //                       does the final zone/decoy resolve).
    function fire(aimYaw, aimPitch, targetZ, tIdx) {
        live = 1;
        dx   = 0.0;
        dy   = 0.0;
        vx   = 0.0;
        vy   = 0.0;
        ttl  = 0;
        // Expected travel ticks: linear in distance.  Tuned so
        // SS_TARGET_NEAR ≈ 14 ticks (~0.8 s), FAR ≈ 32 ticks (~1.9 s).
        maxTtl = (targetZ * 60 / 1000) + 4;
        if (maxTtl < 8)  { maxTtl = 8;  }
        if (maxTtl > 36) { maxTtl = 36; }
        targetIdx       = tIdx;
        aimYawAtFire    = aimYaw;
        aimPitchAtFire  = aimPitch;
    }

    function clear() { live = 0; targetIdx = -1; }

    // Advance the bullet by one tick.  `wind` is the active wind
    // strength.  Only DRIFT is integrated here — the muzzle
    // direction is constant by construction.  Returns true when
    // the bullet has finished its flight (caller resolves the hit).
    function tick(wind) {
        if (live == 0) { return false; }
        ttl++;
        vy = vy + SS_GRAVITY;
        vx = vx + wind * SS_WIND_PER_TICK;
        dx = dx + vx;
        dy = dy + vy;
        return (ttl >= maxTtl);
    }

    // Project the bullet's current world-anchored screen position
    // for a given scope frame.  All callers (renderer + collision)
    // go through here so they all see the same numbers.
    //   cx, cy           — current scope centre in screen pixels
    //   gazeYaw, gazePitch — current filtered gaze (no sway)
    // Returns [bx, by, originX, originY] — bullet head and the
    // current screen position of the muzzle direction (for the
    // tracer line's far end).
    function screenAt(cx, cy, gazeYaw, gazePitch) {
        var originX = (cx + (aimYawAtFire   - gazeYaw)   * SS_FOV).toNumber();
        var originY = (cy + (aimPitchAtFire - gazePitch) * SS_FOV).toNumber();
        var bx = originX + dx.toNumber();
        var by = originY + dy.toNumber();
        return [bx, by, originX, originY];
    }
}
