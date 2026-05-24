// ═══════════════════════════════════════════════════════════════
// BMConst.mc — Shared enums for the Bomber clone.
//
// Kept in one file because Monkey C lacks a way to namespace
// constants between modules; pulling them out also makes it easy
// to extend (add a tile type or power-up without hunting through
// every game module).
// ═══════════════════════════════════════════════════════════════

// Tile types stored in `GridManager.tiles[]`.
const BT_EMPTY    = 0;
const BT_WALL     = 1;     // indestructible (border / grid posts)
const BT_BLOCK    = 2;     // breakable
const BT_PU_BOMB  = 3;     // power-up: +1 max bombs
const BT_PU_RANGE = 4;     // power-up: +1 explosion range
const BT_PU_SHIELD= 5;     // power-up: 6s invincibility
const BT_PU_GHOST = 6;     // power-up: 6s walk through breakable blocks

// Game high-level state.
const BS_MENU  = 0;
const BS_PLAY  = 1;
const BS_WIN   = 2;
const BS_OVER  = 3;

// Menu rows (chess-style).
const BM_MENU_ROWS = 4;

// Speed presets (index into per-speed tick tables in GameController).
const BSP_SLOW   = 0;
const BSP_NORMAL = 1;
const BSP_FAST   = 2;
