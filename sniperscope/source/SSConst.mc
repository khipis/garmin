// ═══════════════════════════════════════════════════════════════
// SSConst.mc — SniperScope shared constants.
//
// CONCEPT
//   The watch face is a sniper scope.  Player tilts the wrist to
//   sweep the scope across a wide angular field, hunts a partially
//   hidden hostile, and takes ONE shot per round.  Bullet has
//   travel time and is pulled by gravity (drop) and wind (drift),
//   so the player has to lead the shot — aim above and into the
//   wind, like a real long-range marksman.
//
// COORDINATES
//   Angular world (radians):
//     yaw   ±SS_WORLD_YAW   — bearing across the scene
//     pitch ±SS_WORLD_PITCH — elevation
//   World → screen:
//     sx = cx + (yaw   − gazeYaw)   · SS_FOV
//     sy = cy + (pitch − gazePitch) · SS_FOV
//
// TICK
//   60 ms — fast enough for smooth gyro tracking, slow enough that
//   the per-tick cost is comfortable on entry-level watches.
// ═══════════════════════════════════════════════════════════════

// ── States ────────────────────────────────────────────────────
const SS_MENU = 0;
const SS_PLAY = 1;           // scanning + aiming + breathing
const SS_FIRED = 2;          // bullet in flight
const SS_RESULT = 3;         // hit / miss reveal
const SS_OVER = 4;           // out of rounds — show recap

// ── Menu rows ─────────────────────────────────────────────────
// Row 3 is the global LEADERBOARD (split by difficulty variant);
// it pushes a view from the View layer.
const SS_MENU_ROWS = 4;
const SS_ROW_SENS  = 0;
const SS_ROW_DIFF  = 1;
const SS_ROW_START = 2;
const SS_ROW_LB    = 3;

// Global leaderboard game id (matches _LOGOS / web id).
const SS_LB_GAME_ID = "sniperscope";

// ── Sensitivity preset ────────────────────────────────────────
const SS_SENS_LOW    = 0;
const SS_SENS_NORMAL = 1;
const SS_SENS_HIGH   = 2;

// ── Difficulty ────────────────────────────────────────────────
const SS_DIFF_EASY   = 0;
const SS_DIFF_NORMAL = 1;
const SS_DIFF_HARD   = 2;

// ── Tick & timing ─────────────────────────────────────────────
const SS_TICK_MS         = 60;
const SS_RESULT_TICKS    = 28;   // freeze frame on hit/miss
const SS_RECOIL_TICKS    = 6;
const SS_SLOWMO_TICKS    = 10;   // hit slow-mo effect
const SS_SHAKE_TICKS     = 4;
const SS_STEADY_HOLD     = 26;   // after this many ticks of low motion,
                                 // a 14-tick "steady window" opens
const SS_STEADY_WINDOW   = 14;
const SS_HOLD_DECAY      = 90;   // ticks after which sway grows again
                                 // (long-aim fatigue)

// ── Scope geometry (proportions of min(sw,sh)) ────────────────
const SS_SCOPE_PCT       = 92;   // %% of min dim used for scope opening
const SS_FOV             = 240;  // pixels per radian (tighter than SC — feels zoomed in)
const SS_WORLD_YAW       = 1.6;  // ±yaw range player can scan
const SS_WORLD_PITCH     = 0.9;  // ±pitch range

// ── Breathing (sway) ──────────────────────────────────────────
// Two superimposed slow sines (different periods) — looks more
// organic than a single oscillator and the player learns to
// "ride" the natural lull at the zero crossings.
const SS_BR_PER_A_TICKS  = 90;   // slow inhale/exhale
const SS_BR_PER_B_TICKS  = 41;   // faster ripple
const SS_BR_AMP_YAW      = 0.018;
const SS_BR_AMP_PITCH    = 0.012;
const SS_BR_HOLD_PENALTY = 2.2;  // multiplier after fatigue kicks in
const SS_BR_STEADY_GAIN  = 25;   // % of base sway during steady window

// ── Round structure ───────────────────────────────────────────
const SS_ROUNDS_DEFAULT  = 5;   // one mission = 5 targets (~90 s)
const SS_ROUND_TIMEOUT   = 700; // ticks before auto-miss (~42 s)

// ── Target zones ──────────────────────────────────────────────
const SS_ZONE_HEAD       = 0;
const SS_ZONE_CHEST      = 1;
const SS_ZONE_LIMB       = 2;
const SS_ZONE_MISS       = 3;

// ── Ballistics ────────────────────────────────────────────────
// Distances are abstract "metres".  The bullet is stored as
// DRIFT (dx, dy) in pixels from the muzzle direction at fire
// time — the renderer projects that muzzle direction through
// the player's CURRENT gaze each frame so the trace stays
// world-anchored when the reticle moves.
//
// Tuning: drop and drift are budgeted to fit comfortably inside
// a ~120-px scope radius across the full distance range:
//
//   near  (180m, ~14 ticks):  ½·g·t²  =  ~ 6 px drop, < 1 mil-dot
//   med   (320m, ~23 ticks):              ~16 px drop, ~ 2 mil-dots
//   far   (480m, ~32 ticks):              ~31 px drop, ~ 4 mil-dots
//
// Wind drift at full strength is similarly ~5–25 px across the
// flight time — readable through the crosshair without flying
// off-screen.  The old values (g = 1.3, w = 0.45) were 20×
// too strong: a med shot would drop ~210 px (off the scope)
// and visually the bullet appeared to streak straight down.
const SS_BULLET_SPD      = 36;   // px / tick (kept for future cosmetic outward streak)
const SS_GRAVITY         = 0.06; // px / tick² (downward in screen)
const SS_WIND_PER_TICK   = 0.08; // px / tick² horizontal at wind=1
const SS_TARGET_NEAR     = 180;
const SS_TARGET_MED      = 320;
const SS_TARGET_FAR      = 480;

// ── Scenery ───────────────────────────────────────────────────
const SS_SCENE_FIELD     = 0;   // open field with grass tufts
const SS_SCENE_URBAN     = 1;   // building silhouettes + windows
const SS_SCENE_ROOFTOP   = 2;   // skyline with chimneys

// ── Persistence keys ──────────────────────────────────────────
const SS_K_SENS = "ss_sens";
const SS_K_DIFF = "ss_diff";
const SS_K_BEST = "ss_best";
const SS_K_HS   = "ss_hs";    // best headshots in a single mission
const SS_K_DIST = "ss_dist";  // longest one-shot kill (metres)
const SS_K_KILL = "ss_kill";  // lifetime hostiles eliminated
