// ═══════════════════════════════════════════════════════════════
// SCConst.mc — StarCombat constants.
//
// CONCEPT
//   The watch face IS the player's sniper scope.  The reticle is
//   fixed at screen centre — the player flies through space and
//   tilts the watch to look around.  Imperial Star Destroyers
//   approach from deep space; aim the centre crosshair on one and
//   shoot.  Destroyers fire back (green bolts toward centre).
//
// COORDINATES
//   Each enemy lives in a 2-D angular world:
//     yaw   (radians, ±)  — horizontal world bearing
//     pitch (radians, ±)  — vertical world bearing
//     dist  (game units)  — how far away (shrinks each tick)
//
//   The player's gaze (gazeYaw, gazePitch) tracks the watch tilt:
//     tilt right    → gazeYaw increases  (look right)
//     tilt forward  → gazePitch decreases (look up)
//
//   Projection to screen:
//     sx = cx + (yaw   − gazeYaw)   * SC_FOV
//     sy = cy + (pitch − gazePitch) * SC_FOV
//     sz = SC_BASE_SZ * SC_REF_DIST / dist     (depth scale)
// ═══════════════════════════════════════════════════════════════

// ── States ────────────────────────────────────────────────────
const SC_MENU = 0;
const SC_PLAY = 1;
const SC_OVER = 2;

// ── Menu rows ─────────────────────────────────────────────────
// Row 3 is the shared global LEADERBOARD (split by difficulty
// variant); it pushes a view from the shared library.
const SC_MENU_ROWS = 4;
const SC_ROW_SENS  = 0;
const SC_ROW_DIFF  = 1;
const SC_ROW_START = 2;
const SC_ROW_LB    = 3;

// Global leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "starcombat";

// ── Sensitivity preset index ──────────────────────────────────
const SC_SENS_LOW    = 0;
const SC_SENS_NORMAL = 1;
const SC_SENS_HIGH   = 2;

// ── Difficulty index ──────────────────────────────────────────
const SC_DIFF_EASY   = 0;
const SC_DIFF_NORMAL = 1;
const SC_DIFF_HARD   = 2;

// ── Pools ─────────────────────────────────────────────────────
const SC_MAX_ENEMIES = 6;
const SC_MAX_BOLTS   = 8;
const SC_MAX_EXP     = 4;

// ── Projection ────────────────────────────────────────────────
const SC_FOV       = 180;   // pixels per radian
const SC_BASE_SZ   = 16;    // visual size at reference distance
const SC_REF_DIST  = 600;   // reference distance for SC_BASE_SZ
const SC_SPAWN_D   = 850;   // spawn distance
const SC_RAM_D     = 90;    // damage if enemy reaches this distance

// ── Locking & combat ──────────────────────────────────────────
const SC_LOCK_R    = 26;    // pixel radius for crosshair lock
const SC_BOLT_SPD  = 6;     // px / tick
const SC_LASER_T   = 2;
const SC_EXP_T     = 6;
const SC_SHAKE_T   = 4;
const SC_HIT_T     = 8;

// ── Tick ──────────────────────────────────────────────────────
const SC_TICK_MS = 80;

// ── Stars ─────────────────────────────────────────────────────
const SC_NSTARS = 36;

// ── Persistence keys ──────────────────────────────────────────
const SC_K_SENS = "sc_sens";
const SC_K_DIFF = "sc_diff";
const SC_K_BEST = "sc_best";

// ── Progression ───────────────────────────────────────────────
const SC_AMMO_MAX     = 20;
const SC_AMMO_PER_HIT = 3;    // refunded on every confirmed hit
const SC_LVL_BASE     = 4;    // killTarget = SC_LVL_BASE + level * 2

// ── Enemy types ───────────────────────────────────────────────
const SC_ET_DESTROYER = 0;    // basic wedge, available from lvl 1
const SC_ET_TIE       = 1;    // fast small panel-ship, from lvl 3
const SC_ET_CRUISER   = 2;    // tougher big wedge (HP 2), from lvl 5
