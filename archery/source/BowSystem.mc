// ═══════════════════════════════════════════════════════════════
// BowSystem.mc — Bow draw mechanic + arrow flight physics.
//
// THE BOW
//   draw  : 0–100  (% pulled back; 0 = relaxed, 100 = full)
//   drawing : 1 when the trigger button/touch is held
//   While `drawing`, `draw` ticks up by ~6 per tick until 100.
//   When the player releases, an arrow is fired with `power = draw`.
//
// THE ARROW (POOL of AR_MAX_ARROWS)
//   Each arrow stores at fire time:
//     targetX, targetY  : screen-space aim point (where the
//                         crosshair was on release)
//     power             : 25–100 (below AR_MIN_DRAW = no fire)
//     age               : ticks elapsed; arrow lives 9 ticks
//     hitZone           : −1 unresolved, 0/1/2 at impact
//     hitEnemyIdx       : −1 unresolved, ≥0 if it hit someone
//
//   Visual: each tick we lerp the arrow from the BOW position
//   (centre-bottom of screen) toward (targetX, targetY) with a
//   parabolic Y-arc.  Low-power shots drop below their aim point
//   so they visibly fall short.
//
//   Hit resolution happens on the LAST tick of flight by querying
//   EnemyManager.hitAt().  The exact landing point is offset down
//   by a power-shortfall — `drop = (100 − power) * 0.6 px` — so
//   weak shots physically land short of their intended Y.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class BowSystem {
    // Bow draw state.
    var draw;       // 0..100
    var drawing;    // 0 or 1

    // Arrow pool.
    var aLive;
    var aTx;
    var aTy;
    var aPwr;
    var aAge;
    var aZone;       // resolved hit zone after impact
    var aEnemy;      // resolved enemy idx after impact
    var aBowX;       // bow tip position at fire time (for visual lerp)
    var aBowY;
    var aLandX;      // computed landing pixel (cached for render)
    var aLandY;
    var aFinalT;     // total ticks the arrow lives (incl. settle)

    function initialize() {
        draw    = 0;
        drawing = 0;
        aLive   = new [AR_MAX_ARROWS];
        aTx     = new [AR_MAX_ARROWS];
        aTy     = new [AR_MAX_ARROWS];
        aPwr    = new [AR_MAX_ARROWS];
        aAge    = new [AR_MAX_ARROWS];
        aZone   = new [AR_MAX_ARROWS];
        aEnemy  = new [AR_MAX_ARROWS];
        aBowX   = new [AR_MAX_ARROWS];
        aBowY   = new [AR_MAX_ARROWS];
        aLandX  = new [AR_MAX_ARROWS];
        aLandY  = new [AR_MAX_ARROWS];
        aFinalT = new [AR_MAX_ARROWS];
        for (var i = 0; i < AR_MAX_ARROWS; i++) {
            aLive[i] = 0; aAge[i] = 0; aZone[i] = -1; aEnemy[i] = -1;
        }
    }

    function reset() {
        draw = 0; drawing = 0;
        for (var i = 0; i < AR_MAX_ARROWS; i++) {
            aLive[i] = 0; aAge[i] = 0; aZone[i] = -1; aEnemy[i] = -1;
        }
    }

    function startDraw() { drawing = 1; }

    // Returns true if an arrow was fired (call only when armed).
    // bowX/Y is the bow tip — typically (cx, sh*88/100).
    // targetX/Y is the current crosshair screen coordinates.
    function release(bowX, bowY, targetX, targetY) {
        drawing = 0;
        var p = draw;
        draw  = 0;
        if (p < AR_MIN_DRAW) { return false; }    // dry-fire, no arrow

        // Compute the landing point with vertical drop scaled by
        // how short of full-draw the player was.  100 power = no
        // drop, 25 power = ~45 px drop.
        var shortfall = 100 - p;
        var drop = shortfall * 60 / 100;   // 0..45 px
        var lx = targetX;
        var ly = targetY + drop;

        // Find a free slot.
        for (var i = 0; i < AR_MAX_ARROWS; i++) {
            if (aLive[i] == 0) {
                aLive[i]   = 1;
                aTx[i]     = targetX;
                aTy[i]     = targetY;
                aPwr[i]    = p;
                aAge[i]    = 0;
                aZone[i]   = -1;
                aEnemy[i]  = -1;
                aBowX[i]   = bowX;
                aBowY[i]   = bowY;
                aLandX[i]  = lx;
                aLandY[i]  = ly;
                aFinalT[i] = AR_RELEASE_FLY_TICKS;
                return true;
            }
        }
        return false;   // pool full — extremely unlikely
    }

    // Advance bow + arrows by one tick.
    // Returns array of [enemyIdx, zone, screenX, screenY] for each
    // hit resolved this tick (empty array if none).
    function tick(enemies, cx, cy, sw, sh) {
        // Bow draw ramp.
        if (drawing != 0) {
            draw = draw + (100 / AR_DRAW_TICKS_FULL) + 1;
            if (draw > 100) { draw = 100; }
        }

        var hits = [];
        for (var i = 0; i < AR_MAX_ARROWS; i++) {
            if (aLive[i] == 0) { continue; }
            aAge[i]++;

            // On the impact tick, resolve the hit.
            if (aAge[i] == aFinalT[i] && aZone[i] == -1) {
                var res = _resolveHit(enemies, aLandX[i], aLandY[i]);
                aEnemy[i] = res[0];
                aZone[i]  = res[1];
                if (res[0] >= 0) {
                    hits.add([res[0], res[1], aLandX[i], aLandY[i]]);
                }
            }
            // Retire arrow a few ticks after impact so the player
            // can see where it landed.
            if (aAge[i] > aFinalT[i] + 4) {
                aLive[i] = 0;
            }
        }
        return hits;
    }

    // Compute the on-screen position of arrow `i` at its current age.
    // Returns [x, y].
    function arrowPos(i) {
        if (aLive[i] == 0) { return [-999, -999]; }
        return arrowPosAt(i, aAge[i]);
    }

    // Compute the screen position of arrow `i` at an ARBITRARY age.
    // Used to render a trail of previous positions for continuous
    // visibility of the arrow as it flies.
    function arrowPosAt(i, age) {
        if (aLive[i] == 0) { return [-999, -999]; }
        if (age <= 0)               { return [aBowX[i].toNumber(),  aBowY[i].toNumber()]; }
        if (age >= aFinalT[i])      { return [aLandX[i], aLandY[i]]; }
        var t = age.toFloat() / aFinalT[i].toFloat();
        var x = aBowX[i] + (aLandX[i] - aBowX[i]) * t;
        var y = aBowY[i] + (aLandY[i] - aBowY[i]) * t;
        // Parabolic arc: subtract an upward bow (4·t·(1−t)·H px).
        var H = 30.0 + (100 - aPwr[i]) * 0.7;
        var bow = 4.0 * t * (1.0 - t) * H;
        y = y - bow;
        return [x.toNumber(), y.toNumber()];
    }

    // Hit detection — does (lx, ly) fall inside any enemy's
    // current silhouette?  Returns [enemyIdx, zone] or [-1, -1].
    hidden function _resolveHit(enemies, lx, ly) {
        var best = -1;
        var bestZ = -1;
        for (var i = 0; i < AR_MAX_ENEMIES; i++) {
            if (enemies.live[i] == 0) { continue; }
            var sx = enemies.sx[i];
            var sy = enemies.sy[i];
            var sz = enemies.sz[i];      // sprite half-height in px
            if (sz < 4) { sz = 4; }

            // Horizontal: ±35 % of sprite height.
            var halfW = sz * 70 / 100;
            if (lx < sx - halfW || lx > sx + halfW) { continue; }

            // Vertical zones (relative to sprite centre):
            //   head  : -65 % .. -45 %
            //   chest : -45 % ..  -10 %
            //   legs  : -10 % .. +25 %
            var top    = sy - sz * 65 / 100;
            var chestT = sy - sz * 45 / 100;
            var chestB = sy - sz * 10 / 100;
            var legsB  = sy + sz * 25 / 100;
            if (ly < top || ly > legsB) { continue; }

            var z;
            if      (ly < chestT) { z = AR_HZ_HEAD;  }
            else if (ly < chestB) { z = AR_HZ_CHEST; }
            else                   { z = AR_HZ_LEGS;  }

            // Shield: SHIELD enemy blocks chest/legs while window
            // closed.  EnemyManager.canHitZone() encodes this.
            if (!enemies.canHitZone(i, z)) { continue; }

            best  = i;
            bestZ = z;
            break;     // first match wins (single arrow, one target)
        }
        return [best, bestZ];
    }
}
