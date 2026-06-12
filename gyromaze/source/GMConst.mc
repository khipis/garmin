// ═══════════════════════════════════════════════════════════════
// GMConst.mc — GyroMaze shared constants.
//
// Physics operates in "cell-units" (Float, range 0..n).
// The UIManager converts to pixels via cellPx for rendering.
// ═══════════════════════════════════════════════════════════════

// Special tile types stored in extras[] flat array.
const GM_TILE_FLOOR = 0;   // normal passable floor
const GM_TILE_SPIKE = 1;   // instant death → restart
const GM_TILE_SLOW  = 3;   // sticky tile — halves velocity
const GM_TILE_BOOST = 4;   // boost pad — 1.4× velocity

// Biomes — each changes physics params + tile distribution + colours.
const GM_BIOME_NORMAL = 0;
const GM_BIOME_ICE    = 1;   // high friction → slides
const GM_BIOME_TRAP   = 2;   // dead-end spikes
const GM_BIOME_SPEED  = 3;   // boost pads, fast physics
const GM_BIOME_CHAOS  = 4;   // mixed: spikes + boosts

// Game-state machine values.
const GM_MENU  = 0;
const GM_PLAY  = 1;
const GM_WIN   = 2;
const GM_OVER  = 3;
const GM_PAUSE = 4;

// Wall bitmask bits (stored per cell in walls[] flat array).
const GM_WALL_N = 1;   // north wall present
const GM_WALL_S = 2;   // south wall present
const GM_WALL_E = 4;   // east  wall present
const GM_WALL_W = 8;   // west  wall present

// Chess-style menu rows. Row 3 is the global LEADERBOARD (split by
// difficulty variant); it pushes a view from the View layer.
const GM_MENU_ROWS = 4;
const GM_ROW_DIFF  = 0;
const GM_ROW_BIOME = 1;
const GM_ROW_START = 2;
const GM_ROW_LB    = 3;

// Global leaderboard game id (matches _LOGOS / web id).
const GM_LB_GAME_ID = "gyromaze";

// Difficulty levels.
const GM_DIFF_EASY = 0;   // 7×7 maze
const GM_DIFF_MED  = 1;   // 9×9 maze
const GM_DIFF_HARD = 2;   // 11×11 maze
