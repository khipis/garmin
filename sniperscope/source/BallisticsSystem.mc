// ═══════════════════════════════════════════════════════════════
// BallisticsSystem.mc — Simplified bullet trajectory.
//
// The bullet is parameterised in TWO halves:
//
//   • Muzzle direction in WORLD angular coords
//     (aimYawAtFire, aimPitchAtFire) — locked at fire time.
//     The renderer projects this through the CURRENT optical axis using the
//     same dynamic scales as every world object.
//
//   • Drift in SCREEN pixel units from that muzzle direction
//     (dx, dy) — accumulated each tick from gravity (vy) and wind
//     (vx).  This is independent of the player's gaze post-fire.
//
//   bullet_screen = centre + (fireAim − currentAim) · screenScale + (dx, dy)
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

    // "Soft clear" — freeze the bullet at its current position
    // (still renderable as a static trail) but stop integrating
    // motion.  Used to keep the trace visible for a few RESULT
    // ticks so the player sees WHERE the bullet hit, then it
    // fades.  Renderer treats `live > 0` as "draw me".
    function freeze() { live = 2; }

    // Advance the bullet by one tick.  `wind` is the active wind
    // strength.  Only DRIFT is integrated here — the muzzle
    // direction is constant by construction.  Returns true when
    // the bullet has finished its flight (caller resolves the hit).
    // Frozen bullets (live == 2) do not tick; the caller never
    // calls tick() on them anyway, but we guard for safety.
    function tick(wind) {
        if (live != 1) { return false; }
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
    //   scaleX, scaleY    — dynamic angle-to-pixel projection
    // Returns [bx, by, originX, originY] — bullet head and the
    // current screen position of the muzzle direction (for the
    // tracer line's far end).
    function screenAt(cx, cy, scaleX, scaleY, currentYaw, currentPitch) {
        var originX = (cx + (aimYawAtFire   - currentYaw)   * scaleX).toNumber();
        var originY = (cy + (aimPitchAtFire - currentPitch) * scaleY).toNumber();
        var bx = originX + dx.toNumber();
        var by = originY + dy.toNumber();
        return [bx, by, originX, originY];
    }
}
