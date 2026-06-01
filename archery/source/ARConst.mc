// ═══════════════════════════════════════════════════════════════
// ARConst.mc — Archery game constants.
//
// CONCEPT
//   First-person medieval archery tournament.  The watch face is
//   the archer's viewport: tilt to aim (gyroscope), hold any
//   button (or touch) to draw the bow, release to fire.
//
//   The world is parameterised in angular coordinates (yaw, pitch)
//   identical to the StarCombat model.  Enemies live in world
//   angles, the player's gaze tracks accelerometer tilt, and a
//   field-of-view factor projects world → screen pixels.
//
//   Arrows are simulated in SCREEN space once fired; they're a
//   visual+timing system overlaid on top of the projected world.
//   A hit lands when the arrow's final position is inside an
//   enemy's silhouette at impact time.  The arrow follows a
//   parabolic arc (gravity drop) — low-power shots fall short.
// ═══════════════════════════════════════════════════════════════

// ── States ────────────────────────────────────────────────────
const AR_MENU = 0;
const AR_PLAY = 1;
const AR_WIN  = 2;       // tournament won
const AR_OVER = 3;
const AR_INTERMISSION = 4;   // brief banner between rounds
const AR_DEMO = 5;            // highlights reel (auto-plays cinematics)

// ── Menu rows (chess-style) ───────────────────────────────────
const AR_MENU_ROWS = 4;
const AR_ROW_SENS  = 0;
const AR_ROW_DIFF  = 1;
const AR_ROW_DEMO  = 2;
const AR_ROW_START = 3;

// ── Sensitivity ───────────────────────────────────────────────
const AR_SENS_LOW    = 0;
const AR_SENS_NORMAL = 1;
const AR_SENS_HIGH   = 2;

// ── Difficulty ────────────────────────────────────────────────
const AR_DIFF_EASY   = 0;
const AR_DIFF_NORMAL = 1;
const AR_DIFF_HARD   = 2;

// ── Tournament rounds ─────────────────────────────────────────
const AR_NUM_ROUNDS = 3;
const AR_RD_QF = 0;   // Quarter-final: Shield Knights
const AR_RD_SF = 1;   // Semifinal:     Horse Riders
const AR_RD_F  = 2;   // Final:         Archer Mirror

// ── Enemy types ───────────────────────────────────────────────
const AR_ET_IDLE    = 0;   // stationary peasant target
const AR_ET_SHIELD  = 1;   // shield knight (timed openings)
const AR_ET_RIDER   = 2;   // horse rider strafing horizontally
const AR_ET_HEAVY   = 3;   // heavy armour — only head shots count
const AR_ET_ARCHER  = 4;   // archer mirror — shoots back

// ── Pool sizes ────────────────────────────────────────────────
const AR_MAX_ENEMIES = 5;
const AR_MAX_ARROWS  = 3;   // simultaneous arrows in flight
const AR_MAX_INCOMING = 4;  // incoming arrows from archer mirror
const AR_MAX_VFX     = 6;   // hit sparks pool

// ── Hit zones (proportions of enemy sprite) ──────────────────
// All measured from the enemy's center y. Body height = 100 %.
//   head  : [-65 %, -45 %]
//   chest : [-45 %, -10 %]
//   legs  : [-10 %, +25 %]
// Hit width: ±35 % horizontal.
const AR_HZ_HEAD   = 0;
const AR_HZ_CHEST  = 1;
const AR_HZ_LEGS   = 2;

// ── Tick (game loop) ──────────────────────────────────────────
const AR_TICK_MS = 60;     // 16-17 fps — smooth enough, easy on battery

// ── Bow mechanics ─────────────────────────────────────────────
const AR_DRAW_TICKS_FULL = 18;   // ticks to reach full draw (~1.1 s)
const AR_RELEASE_FLY_TICKS = 14; // arrow flight duration (~0.85 s)
const AR_MIN_DRAW = 25;          // below this, shot is too weak

// ── Projection ────────────────────────────────────────────────
const AR_FOV = 180;   // px per radian (sensitive aim)

// ── Stars (sky) ───────────────────────────────────────────────
const AR_NSTARS = 14;     // little forest sparkles / lanterns

// ── Persistence keys ──────────────────────────────────────────
const AR_K_SENS     = "ar_sens";
const AR_K_DIFF     = "ar_diff";
const AR_K_BEST     = "ar_best";        // best score across runs
const AR_K_BESTROUND = "ar_bestround";  // best round reached
