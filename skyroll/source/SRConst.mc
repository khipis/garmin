// ═══════════════════════════════════════════════════════════════
// SRConst.mc — SkyRoll shared constants.
//
// CONCEPT
//   Watch face is a pseudo-3D isometric scene.  A ball rolls
//   forward along a narrow floating path while the player tilts
//   the wrist to steer.  Falling off = instant fail.
//
// COORDINATES
//   World coordinates are in TILES (floats) — ball lives at
//   (px, py) where +x is right of the path centre and +y is the
//   "forward" axis along the path.
//
//   Isometric projection (camera roughly south-east of the scene):
//     sx = (px − py) · SR_TILE_HW
//     sy = −(px + py) · SR_TILE_HH
//
//   Increasing world.y     → screen up-LEFT  (forward into scene)
//   Increasing world.x     → screen up-RIGHT (right of path)
//   The camera follows the ball so the ball stays just below
//   screen centre and the path AHEAD is visible above.
//
// TICK
//   50 ms — fast enough that gyro tracking feels analog, slow
//   enough that worst-case render fits comfortably in budget.
// ═══════════════════════════════════════════════════════════════

// ── States ──────────────────────────────────────────────────────
const SR_MENU = 0;
const SR_PLAY = 1;
const SR_FALL = 2;     // ball has left the path, animating descent
const SR_OVER = 3;

// ── Menu rows (chess-style 3-row layout) ────────────────────────
const SR_MENU_ROWS = 3;
const SR_ROW_SENS  = 0;
const SR_ROW_DIFF  = 1;
const SR_ROW_START = 2;

// ── Sensitivity presets ─────────────────────────────────────────
const SR_SENS_LOW    = 0;
const SR_SENS_NORMAL = 1;
const SR_SENS_HIGH   = 2;

// ── Difficulty ──────────────────────────────────────────────────
const SR_DIFF_EASY   = 0;
const SR_DIFF_NORMAL = 1;
const SR_DIFF_HARD   = 2;

// ── Tile types ──────────────────────────────────────────────────
const SR_T_NONE     = 0;
const SR_T_NORMAL   = 1;
const SR_T_BOOST    = 2;     // forward speed-up
const SR_T_FRAGILE  = 3;     // collapses some ticks after first touch
const SR_T_BREAK    = 4;     // breaking — still solid for a few ticks
const SR_T_SOFT     = 5;     // safe rest zone (visually distinct, extra friction)

// ── Iso projection ──────────────────────────────────────────────
// Tile diamond size: 2·HW × 2·HH.  Designed for typical 260 × 260
// watch face: tiles are 30 px wide × 16 px tall — chunky enough to
// read clearly through the bezel curve, narrow enough that the path
// has room for 3-tile-wide sections without overflowing.
const SR_TILE_HW = 15;
const SR_TILE_HH = 8;

// ── Tile buffer dimensions ─────────────────────────────────────
// Rolling ring buffer along the y axis (32 rows deep) and bounded
// along x ([-8 .. +7] world coords mapped to buffer indices 0..15).
// 32 rows ≈ 18 visible rows ahead + 14 trail behind.
const SR_BUF_Y  = 32;
const SR_BUF_X  = 16;
const SR_X_HALF =  8;   // world.x range is [-SR_X_HALF .. SR_X_HALF-1]

// ── Physics (centi-tiles per tick where noted) ─────────────────
// All physics constants stored ×100 as ints so they can live in
// `const`; PhysicsSystem converts to floats inline.  The default
// values feel like a heavy steel marble on slightly-banked rails.
const SR_FWD_BASE  =  7;   // ÷100 = 0.07 t/tick base forward roll
const SR_FWD_TILT  =  3;   // ÷100 = 0.03 t/tick² pitch accel (±)
const SR_SIDE_ACC  =  9;   // ÷100 = 0.09 t/tick² side accel (was 6; snappier lateral response)
const SR_FRIC_X    = 86;   // ÷100 = 0.86 (sideways friction)
const SR_FRIC_Y    = 96;   // ÷100 = 0.96 (forward friction)
const SR_MAX_VX    = 26;   // ÷100 = 0.26 t/tick
const SR_MAX_VY    = 22;   // ÷100 = 0.22 t/tick (clamp upper)
const SR_MIN_VY    =  4;   // ÷100 = 0.04 t/tick (always rolling)

// ── Fragile-tile timing ─────────────────────────────────────────
const SR_BREAK_TICKS = 6;   // ticks between first touch and collapse

// ── Boost (impulse applied once when ball enters a boost tile) ─
const SR_BOOST_KICK  = 9;   // ÷100 = 0.09 t/tick added to vy

// ── Fall animation ──────────────────────────────────────────────
const SR_FALL_TICKS = 22;   // ticks of falling before SR_OVER
const SR_FALL_GRAV  =  6;   // ÷100 = 0.06 px / tick² (screen-space)

// ── Camera ──────────────────────────────────────────────────────
const SR_CAM_LERP   = 18;   // ÷100 = 0.18 smoothing
const SR_BALL_Y_OFFSET = 18;  // px the ball sits BELOW screen centre

// ── Tick ────────────────────────────────────────────────────────
const SR_TICK_MS = 50;

// ── Persistence ────────────────────────────────────────────────
const SR_K_SENS = "sr_sens";
const SR_K_DIFF = "sr_diff";
const SR_K_BEST = "sr_best";
