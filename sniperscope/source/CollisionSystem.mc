// ═══════════════════════════════════════════════════════════════
// CollisionSystem.mc — Hit zone resolution.
//
// At the moment the bullet reaches its target distance, we
// project the bullet's drifted screen position against EVERY
// alive target's current silhouette.  The best (closest) hit wins.
//
// Silhouette layout (centred on the target's screen position):
//
//                    o   ← head    (zone 0)
//                   / \              chest = zone 1
//                  | 1 |              limbs = zone 2
//                  |   |
//                  /   \
//                 /     \   ← legs    (zone 2)
//
// Zone radii (pixels) scale with the on-screen silhouette size
// `s` (derived from distance).  A bullet may still hit COVER
// instead of the body — covered zones aren't counted.
//
// API:
//   resolve(...)  → returns a 3-tuple [zone, tIdx, impactX, impactY]
//                   where zone = SS_ZONE_HEAD / CHEST / LIMB / MISS
// ═══════════════════════════════════════════════════════════════

class CollisionSystem {

    static function resolve(bx, by, tgts, screenPositions, sizes) {
        var bestZone = SS_ZONE_MISS;
        var bestI    = -1;
        // Track squared distance to nearest body part — only used to
        // disambiguate when multiple targets overlap the bullet.
        var bestD2   = 99999999;
        for (var i = 0; i < SS_TGT_MAX; i++) {
            if (tgts.live[i] == 0) { continue; }
            var sp = screenPositions[i];
            var sz = sizes[i];
            var sx = sp[0];
            var sy = sp[1];
            // Body anchor: chest is at (sx, sy + sz * 60%).
            var headY  = sy + (sz *  6 / 10);
            var headR  = sz * 35 / 100;     if (headR < 4) { headR = 4; }
            var chestY = sy + (sz * 12 / 10);
            var chestR = sz * 60 / 100;     if (chestR < 6) { chestR = 6; }
            var legY   = sy + (sz * 22 / 10);
            var legR   = sz * 60 / 100;     if (legR < 6) { legR = 6; }

            var dxH = bx - sx;     var dyH = by - headY;
            var dxC = bx - sx;     var dyC = by - chestY;
            var dxL = bx - sx;     var dyL = by - legY;
            var d2H = dxH * dxH + dyH * dyH;
            var d2C = dxC * dxC + dyC * dyC;
            var d2L = dxL * dxL + dyL * dyL;

            // Cover masks lower body parts.
            var cov = tgts.cover[i];

            if (d2H < headR * headR) {
                // Head always exposed (cover hides BELOW the
                // shoulders; the head/upper body is visible even
                // through a window).
                if (d2H < bestD2) {
                    bestZone = SS_ZONE_HEAD; bestI = i; bestD2 = d2H;
                }
            } else if (d2C < chestR * chestR) {
                if (cov < 2) {                // cover=2 hides chest too
                    if (d2C < bestD2) {
                        bestZone = SS_ZONE_CHEST; bestI = i; bestD2 = d2C;
                    }
                }
            } else if (d2L < legR * legR) {
                if (cov < 1) {                // cover=1 hides legs
                    if (d2L < bestD2) {
                        bestZone = SS_ZONE_LIMB; bestI = i; bestD2 = d2L;
                    }
                }
            }
        }
        return [bestZone, bestI];
    }
}
