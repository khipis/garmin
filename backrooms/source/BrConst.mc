// ═══════════════════════════════════════════════════════════════════════════
// BrConst.mc — Tuning, palette and tables for BACKROOMS RUN (module `Br`).
//
// A pseudo-3D (Wolfenstein-style raycast) horror escape game: you are lost in
// endless yellow rooms, sanity is the clock, and the exit may be lying to you.
// Data-only so every module reads the same numbers.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

module Br {

    const GAME_ID = "backrooms";

    // ── Leaderboard boards ───────────────────────────────────────────────────
    const LB_DEPTH  = "Depth";   // deepest level reached
    const LB_TIME   = "Time";    // longest single run, seconds
    const LB_ESCAPE = "Escape";  // lifetime escapes
    const LB_DAILY  = "Daily";   // today's seeded run

    // ── World ────────────────────────────────────────────────────────────────
    // Grid is stored as one bitmask Number per row, so W must stay < 31.
    const MAP_W = 24;
    const MAP_H = 24;
    const MAX_DDA = 32;          // hard cap on DDA steps per ray

    // Cell specials (sparse list, never more than a handful per level)
    const SP_EXIT  = 0;   // the real way out
    const SP_MIMIC = 1;   // looks like an exit, is not
    const SP_DOOR  = 2;   // locked, needs a key
    const SP_KEY   = 3;   // key pickup
    const SP_SANITY= 4;   // almond water — restores sanity
    const SP_RELIC = 5;   // artifact / memory — score + permanent count
    const SP_CELL  = 6;   // spare cell for the torch
    const SP_N     = 7;

    function spName(k) {
        var a = ["EXIT", "EXIT", "LOCKED DOOR", "KEY", "ALMOND WATER",
                 "ARTIFACT", "BATTERY"];
        return a[_c(k, 0, SP_N - 1)];
    }

    // ── Render ───────────────────────────────────────────────────────────────
    // Ray counts per detail setting (br_detail option index).
    function rayCount(detail) {
        var a = [24, 36, 48];
        return a[_c(detail, 0, 2)];
    }
    // How much surface texture we can afford: 0 = flat bands, 1 = grid + trim,
    // 2 = everything including grain speckle.
    function texLevel(detail) {
        var a = [0, 1, 2];
        return a[_c(detail, 0, 2)];
    }
    const FOV_PLANE   = 0.72;    // camera plane half-width (~72° FOV)
    // Wall height at one cell, as % of screen height. Under 100 so a corridor
    // always shows a band of ceiling and carpet — on a 1" round screen that
    // framing is what sells the perspective.
    const WALL_SCALE  = 102;
    // …and a hard ceiling on it. Walking into a wall is allowed to fill the
    // frame — that is what being nose-first against wallpaper looks like — but
    // not by so much that the geometry stops making sense.
    const WALL_CAP    = 128;     // % of screen height
    const FOG_START   = 1;       // cells before shading begins
    const FOG_CELLS   = 12;      // cells from lit to swallowed

    // Distance → ramp index. Extra steps are added for shadowed faces, unlit
    // zones and failing lights by the caller.
    function fogStep(perp) {
        var t = perp - FOG_START;
        if (t <= 0) { return 0; }
        var i = (t * RAMP_N / FOG_CELLS).toNumber();
        if (i > RAMP_N - 1) { i = RAMP_N - 1; }
        return i;
    }
    // Flicker/darkness converted into extra ramp steps.
    function lightStep(lightPct) {
        if (lightPct >= 90) { return 0; }
        if (lightPct >= 60) { return 1; }
        if (lightPct >= 35) { return 2; }
        if (lightPct >= 20) { return 4; }
        return 6;
    }

    // ── Palette ──────────────────────────────────────────────────────────────
    // Garmin MIP panels quantise to four levels per channel (00/55/AA/FF), and
    // anything with R≈G≈B lands on grey while R-rounds-up/G-rounds-down lands on
    // maroon. Rather than fight that with per-pixel maths, every shade below is
    // already ON the device grid: distance shading picks a ramp index instead of
    // multiplying channels, so what the simulator shows is what the watch shows
    // (and the posterised look suits the CRT mood anyway).
    const RAMP_N = 10;

    var _rw = null;
    // Wallpaper ramps: lit → fogged → gone. One set per depth band.
    function wallRamp(level) {
        if (_rw == null) {
            _rw = [
                // Levels 0-2: the classic mono-yellow
                [0xFFFF55, 0xAAAA55, 0xAAAA55, 0xAAAA00, 0xAAAA00,
                 0x555500, 0x555500, 0x555500, 0x000000, 0x000000],
                // Levels 3-5: damp, going green
                [0xAAFF55, 0x55AA55, 0x55AA55, 0x55AA00, 0x555500,
                 0x555500, 0x005500, 0x000000, 0x000000, 0x000000],
                // Levels 6+: rust and old blood
                [0xFFAA55, 0xAA5555, 0xAA5500, 0xAA5500, 0x555500,
                 0x550000, 0x550000, 0x000000, 0x000000, 0x000000]
            ];
        }
        var i = level / 3;
        if (i < 0) { i = 0; }
        if (i > 2) { i = 2; }
        return _rw[i];
    }

    var _rc = null;
    // Ceiling, from directly overhead down to the horizon. Deliberately GREY
    // rather than yellow: three warm surfaces in one frame turn to soup on a
    // four-level panel, so the tiles above you carry the cold end of the image.
    function ceilRamp() {
        if (_rc == null) {
            _rc = [0xAAAAAA, 0xAAAAAA, 0xAAAA55, 0x555555, 0x555500, 0x000000];
        }
        return _rc;
    }
    const CEIL_GRID = 0x555555;  // tile seam
    const CEIL_HOUS = 0x000000;  // light fitting housing

    var _rf = null;
    // Carpet, from the horizon down to your feet. Orange-brown, so the floor
    // never reads as the same material as the wallpaper.
    function floorRamp() {
        if (_rf == null) {
            _rf = [0x000000, 0x555500, 0x555500, 0xAA5500, 0xAA5500];
        }
        return _rf;
    }
    var _rf2 = null;
    // Second carpet tone, one notch darker than floorRamp at every index — the
    // scanlines drawn in it are what stop the near carpet being a slab.
    function floorRamp2() {
        if (_rf2 == null) {
            _rf2 = [0x000000, 0x000000, 0x550000, 0x555500, 0x555500];
        }
        return _rf2;
    }
    const FLOOR_GRID = 0x550000;  // seam between carpet tiles

    const PANEL    = 0xFFFFFF;   // fluorescent tube
    const PANEL_D  = 0xAAAA55;   // …and the same tube once the power sags
    const BG       = 0x000000;
    const CIRCLE   = 0x000000;
    const ACCENT   = 0xFFFF55;
    const COL1     = 0xFFFF55;
    const COL2     = 0xAAAA55;
    const DANGER   = 0xFF5555;
    const HURT     = 0xAA0000;
    const SANE     = 0xAAFFAA;
    const DIM      = 0xAAAA55;

    // ── Player ───────────────────────────────────────────────────────────────
    const MOVE_MAX    = 0.135;   // cells per frame at full walk
    const MOVE_ACCEL  = 0.030;
    const MOVE_DECEL  = 0.022;
    const TURN_MAX    = 0.150;   // radians per frame
    const TURN_ACCEL  = 0.055;
    const TURN_DECEL  = 0.040;
    const THROTTLE_F  = 11;      // frames of walk granted per forward input
    const SPRINT_F    = 16;      // frames of panic sprint
    const SPRINT_MULT = 175;     // % of MOVE_MAX while sprinting
    const RADIUS      = 30;      // collision padding, % of a cell

    // ── Torch ────────────────────────────────────────────────────────────────
    // The LIGHT button. Held charge is the second resource in the game: it is
    // the only way to see inside an unlit zone, and the Shadow can only be
    // pinned by a beam. Batteries are scarce on purpose.
    const TORCH_MAX   = 10000;   // hundredths of a percent
    const TORCH_DRAIN = 34;      // per frame while lit (~24s from full)
    const TORCH_CELL  = 4500;    // a spare cell gives 45%
    const TORCH_START = 5500;    // you begin a run with 55%
    const TORCH_LIGHT = 55;      // light% floor while the beam is on
    const TORCH_CONE  = 34;      // half-width of the beam, % of the screen

    // ── Stamina (panic sprint) ───────────────────────────────────────────────
    const STAM_MAX    = 10000;
    const STAM_COST   = 3400;    // one burst
    const STAM_REGEN  = 85;      // per frame while walking

    // ── Sanity (the run clock) ───────────────────────────────────────────────
    const SANITY_MAX   = 100;
    const DRAIN_BASE   = 12;     // per 100 frames in the light
    const DRAIN_DARK   = 34;     // per 100 frames with the lights out
    const DRAIN_SEEN   = 40;     // extra while an entity has line of sight
    const SANITY_PICK  = 26;     // almond water restore
    const RELIC_SANITY = 12;

    // ── Difficulty (br_diff option index) ────────────────────────────────────
    function diffName(d) {
        var a = ["CALM", "NORMAL", "NIGHTMARE"];
        return a[_c(d, 0, 2)];
    }
    function diffDrainPct(d) {         // sanity drain multiplier, %
        var a = [70, 100, 145];
        return a[_c(d, 0, 2)];
    }
    function diffEventPct(d) {         // event frequency multiplier, %
        var a = [70, 100, 150];
        return a[_c(d, 0, 2)];
    }
    function diffEntities(d, level) {  // simultaneous entities allowed
        var base = [1, 2, 3];
        var n = base[_c(d, 0, 2)] + level / 4;
        if (n > 4) { n = 4; }
        return n;
    }

    // ── Entities ─────────────────────────────────────────────────────────────
    const E_NONE    = -1;
    const E_STALKER = 0;   // watches from far, gone when you close in
    const E_SHADOW  = 1;   // only in the dark; look away or it feeds
    const E_MIMIC   = 2;   // wears an exit like a mask

    function eName(t) {
        var a = ["The Stalker", "The Shadow", "The Mimic"];
        return a[_c(t, 0, 2)];
    }
    function eColor(t) {
        var a = [0x1A1A14, 0x000000, 0x2A2018];
        return a[_c(t, 0, 2)];
    }

    // ── Horror events ────────────────────────────────────────────────────────
    const EV_NONE      = -1;
    const EV_LIGHTSOUT = 0;
    const EV_FOOTSTEPS = 1;
    const EV_WHISPER   = 2;
    const EV_SHIFT     = 3;   // the walls move
    const EV_STRETCH   = 4;   // the corridor grows
    const EV_GLIMPSE   = 5;   // something was there
    const EV_FOLLOWED  = 6;   // it is behind you
    const EV_DISTORT   = 7;   // signal breaks up
    const EV_FAKEEXIT  = 8;   // a mimic wakes up
    const EV_N         = 9;

    // Short all-caps line shown while the event runs (empty = show nothing).
    function evText(e) {
        var a = ["THE LIGHTS DIE", "FOOTSTEPS", "...", "THE WALLS MOVED",
                 "THIS HALL IS LONGER", "", "IT IS BEHIND YOU", "", ""];
        return a[_c(e, 0, EV_N - 1)];
    }
    function evFrames(e) {
        var a = [70, 22, 18, 14, 90, 8, 46, 26, 12];
        return a[_c(e, 0, EV_N - 1)];
    }

    // ── Levels ───────────────────────────────────────────────────────────────
    // Named floors; deeper = darker, denser, hungrier.
    function levelName(l) {
        var a = ["LOBBY", "HABITABLE", "PIPES", "ELECTRIC",
                 "ABANDONED", "HOTEL", "LIGHTS OUT", "UNKNOWN"];
        if (l < 0) { l = 0; }
        if (l > 7) { l = 7; }
        return a[l];
    }
    const RUN_SECS_CAP = 300;    // 5 minutes — hard cap on a single run

    // ── Daily challenge ──────────────────────────────────────────────────────
    const DAILY_GOAL_SECS = 180; // survive 3 minutes

    function _c(i, lo, hi) {
        if (i < lo) { return lo; }
        if (i > hi) { return hi; }
        return i;
    }
}
