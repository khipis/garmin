// ═══════════════════════════════════════════════════════════════
// DiveAI.mc — Parametric dive trajectories.
//
// Each diving enemy stores a small bag of parameters and a single
// `t` (0.0 → 1.0).  `pointFor(enemy, t)` returns the (col, row)
// the enemy should be drawn at this tick.
//
// The dive is the classic Galaga "S-swoop":
//   • The enemy leaves its formation slot.
//   • It curls outward to one side (`curlSide`).
//   • It then sweeps back across the screen toward the player's
//     last-known column.
//   • It passes BELOW the playfield at t = 1.0 (off-screen) — that
//     is where the controller removes it from play.
//
// We use Math.sin for the lateral curl, scaled by `curlAmp`.  The
// vertical descent is purely linear so the enemy speeds up the
// further it goes (visual acceleration without floating-point
// quadratics in the hot loop).
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const PI_F = 3.14159;

class DiveAI {

    // Compute the (col, row) for an enemy at progress t∈[0,1].
    // `startC, startR`  — formation slot
    // `targetC`         — player's column at dive start
    // `curlSide`        — -1 or +1, which side to curl out
    // `curlAmp`         — outward arc magnitude in cells
    static function pointFor(t, startC, startR, targetC, curlSide, curlAmp) {
        var endR = SS_BOARD_ROWS + 1.0;     // below the screen
        var endC = targetC;
        // Lateral: linear toward endC + sin-curl
        var lerp = startC + (endC - startC) * t;
        var curl = curlAmp * curlSide * Math.sin(t * PI_F);
        var c = lerp + curl;
        var r = startR + (endR - startR) * t;
        return [c, r];
    }
}
