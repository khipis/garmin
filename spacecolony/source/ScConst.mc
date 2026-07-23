// ═══════════════════════════════════════════════════════════════════════════
// ScConst.mc — Shared data + tuning for SPACE COLONY.
//
// An idle colony builder: command the first human colony on planet X-01, which
// keeps producing while you're away. Return daily to collect resources, build &
// upgrade structures, research tech, explore regions and chase civilization
// milestones. This file is data-only so every module reads the same tables.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;

module Sc {

    // Showcase-only DEMO fast-track. Kept in code for capturing promo footage,
    // but the on-screen toggle is HIDDEN from users in shipped builds. Flip to
    // true to expose the DEMO button again when recording.
    const SHOW_DEMO = false;

    // ── Leaderboard ──────────────────────────────────────────────────────────
    const GAME_ID = "spacecolony";
    const LB_CIV     = "Civ";     // highest civilization level (primary)
    const LB_COLONY  = "Colony";  // largest colony (population)
    const LB_TECH    = "Tech";    // most advanced technology
    const LB_AGE     = "Age";     // oldest colony (days)
    const LB_EXPLORE = "Explore"; // most discovered planet (regions)

    // ── Resources ────────────────────────────────────────────────────────────
    const R_N   = 5;
    const R_NRG = 0;  // Energy
    const R_MIN = 1;  // Minerals
    const R_H2O = 2;  // Water
    const R_SCI = 3;  // Science
    const R_CRE = 4;  // Credits

    function resName(i) {
        var a = ["Energy", "Minerals", "Water", "Science", "Credits"];
        return a[_c(i, 0, R_N - 1)];
    }
    function resAbbr(i) {
        var a = ["NRG", "MIN", "H2O", "SCI", "CR"];
        return a[_c(i, 0, R_N - 1)];
    }
    function resColor(i) {
        var a = [0xFFC24A, 0x9FB0C0, 0x33AEE0, 0x4CE0C0, 0x8CFF6A];
        return a[_c(i, 0, R_N - 1)];
    }

    // ── Buildings ────────────────────────────────────────────────────────────
    const B_N        = 10;
    const B_HABITAT  = 0;  // population capacity
    const B_REACTOR  = 1;  // energy
    const B_MINE     = 2;  // minerals
    const B_FARM     = 3;  // water
    const B_LAB      = 4;  // science
    const B_LAUNCH   = 5;  // launch pad — faster expeditions
    const B_SAT      = 6;  // satellite station — credits
    const B_ALIEN    = 7;  // alien research center — science mult
    const B_ELEVATOR = 8;  // space elevator — global mult
    const B_DEFENSE  = 9;  // planetary defense — event shield

    function bName(i) {
        var a = ["Habitat", "Reactor", "Mine", "Farm", "Laboratory",
                 "Launch Pad", "Satellite", "Alien Lab", "Space Elevator", "Defense Grid"];
        return a[_c(i, 0, B_N - 1)];
    }
    // ASCII glyph (device fonts render these everywhere; emoji do not).
    function bGlyph(i) {
        var a = ["H", "E", "M", "F", "L", "^", "o", "A", "I", "*"];
        return a[_c(i, 0, B_N - 1)];
    }
    function bColor(i) {
        var a = [0x6FB3FF, 0xFFC24A, 0x9FB0C0, 0x4CC85A, 0x4CE0C0,
                 0xFF7A4A, 0xB46CFF, 0x9A6CFF, 0x8CD0FF, 0xFF5A7A];
        return a[_c(i, 0, B_N - 1)];
    }
    // A darkened variant of the building colour (for shading / bodies).
    function bColorDark(i) {
        var c = bColor(i);
        var r = ((c >> 16) & 0xFF) * 52 / 100;
        var g = ((c >> 8) & 0xFF) * 52 / 100;
        var b = (c & 0xFF) * 52 / 100;
        return (r << 16) | (g << 8) | b;
    }
    function bDesc(i) {
        var a = [
            "Houses colonists. Raises population cap.",
            "Fusion core. Produces Energy.",
            "Extracts Minerals from the crust.",
            "Hydro-farm. Produces Water + food.",
            "Researches Science.",
            "Speeds up planet expeditions.",
            "Orbital relay. Produces Credits.",
            "Boosts all Science output.",
            "Boosts ALL production.",
            "Shields the colony from disasters."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Which resource a building produces, or -1 (utility).
    function bProdRes(i) {
        var a = [-1, R_NRG, R_MIN, R_H2O, R_SCI, -1, R_CRE, -1, -1, -1];
        return a[_c(i, 0, B_N - 1)];
    }
    // Base production at level 1 (per hour).
    function bBaseProd(i) {
        var a = [0, 12, 10, 8, 4, 0, 3, 0, 0, 0];
        return a[_c(i, 0, B_N - 1)];
    }
    // Region that must be discovered before this can be built (-1 = available).
    function bUnlockRegion(i) {
        var a = [-1, -1, -1, -1, -1, RG_DESERT, RG_FROZEN, RG_FOREST, RG_CRYSTAL, RG_RUINS];
        return a[_c(i, 0, B_N - 1)];
    }
    function bAdvanced(i) { return i >= B_LAUNCH; }

    // Production at a given level: 10 -> 25 -> 40 (base*(3L-1)/2).
    function prodAt(i, lvl) {
        if (lvl <= 0) { return 0; }
        var base = bBaseProd(i);
        return base * (3 * lvl - 1) / 2;
    }

    // Upgrade/build cost for going to `lvl` (level 1 = first build).
    // Returns [minerals, energy, science]. Advanced buildings also cost science.
    function costAt(i, lvl) {
        if (lvl < 1) { lvl = 1; }
        var baseMin = 40 + i * 20;
        var baseNrg = 25 + i * 12;
        var m = baseMin;
        var e = baseNrg;
        for (var k = 1; k < lvl; k++) { m = m * 17 / 10; e = e * 17 / 10; }
        var s = 0;
        if (bAdvanced(i)) { s = (30 + (i - B_LAUNCH) * 25); for (var k2 = 1; k2 < lvl; k2++) { s = s * 16 / 10; } }
        return [m, e, s];
    }

    // ── Regions (planet exploration) ─────────────────────────────────────────
    const RG_N       = 5;
    const RG_DESERT  = 0;  // Red Desert
    const RG_FROZEN  = 1;  // Frozen Valley
    const RG_CRYSTAL = 2;  // Crystal Mountains
    const RG_FOREST  = 3;  // Alien Forest
    const RG_RUINS   = 4;  // Ancient Ruins

    function rgName(i) {
        var a = ["Red Desert", "Frozen Valley", "Crystal Mountains", "Alien Forest", "Ancient Ruins"];
        return a[_c(i, 0, RG_N - 1)];
    }
    function rgColor(i) {
        var a = [0xE0663A, 0x8CD0FF, 0xB46CFF, 0x4CC85A, 0xC9A24A];
        return a[_c(i, 0, RG_N - 1)];
    }
    // Building unlocked on discovery.
    function rgUnlockBuilding(i) {
        var a = [B_LAUNCH, B_SAT, B_ELEVATOR, B_ALIEN, B_DEFENSE];
        return a[_c(i, 0, RG_N - 1)];
    }
    function rgDiscovery(i) {
        var a = ["Deep Ore Vein", "Ancient Crystal Cave", "Gravity Anomaly",
                 "Living Xeno-Flora", "The First Ones' Vault"];
        return a[_c(i, 0, RG_N - 1)];
    }

    // ── Technology tree ──────────────────────────────────────────────────────
    const T_N     = 4;
    const T_EFF   = 0;  // +8%/lvl ALL production
    const T_EXTR  = 1;  // +15%/lvl minerals
    const T_POWER = 2;  // +15%/lvl energy
    const T_RES   = 3;  // +15%/lvl science

    function tName(i) {
        var a = ["Efficiency", "Deep Extraction", "Power Grid", "Research AI"];
        return a[_c(i, 0, T_N - 1)];
    }
    function tDesc(i) {
        var a = ["+8% all output / lvl", "+15% minerals / lvl", "+15% energy / lvl", "+15% science / lvl"];
        return a[_c(i, 0, T_N - 1)];
    }
    // Science cost to research the next level.
    function tCost(i, lvl) {
        var base = 60 + i * 20;
        var c = base;
        for (var k = 0; k < lvl; k++) { c = c * 18 / 10; }
        return c;
    }

    // ── Events ────────────────────────────────────────────────────────────────
    const EV_NONE   = -1;
    const EV_METEOR = 0;  // meteor shower  (+minerals)
    const EV_SIGNAL = 1;  // alien signal   (choice)
    const EV_SOLAR  = 2;  // solar storm    (-energy, defense mitigates)
    const EV_LOST   = 3;  // lost expedition(choice)
    const EV_RARE   = 4;  // rare discovery (+resources)

    function evTitle(i) {
        var a = ["Meteor Shower", "Alien Signal", "Solar Storm", "Lost Expedition", "Rare Discovery"];
        return a[_c(i, 0, 4)];
    }
    function evBody(i) {
        var a = [
            "A meteor shower peppered the crust with raw ore.",
            "A mysterious transmission reached the array.",
            "A solar storm is battering the colony grid.",
            "A scout team went dark beyond the ridge.",
            "Surveyors struck an untapped resource seam!"
        ];
        return a[_c(i, 0, 4)];
    }
    function evHasChoice(i) { return i == EV_SIGNAL || i == EV_LOST; }

    // ── Tuning ───────────────────────────────────────────────────────────────
    const OFFLINE_CAP  = 24 * 3600;   // max idle window rewarded
    const POP_INTERVAL = 4 * 3600;    // seconds per new colonist arrival
    const EXPLORE_COST_NRG = 15;      // energy per manual expedition tick
    const EXPLORE_STEP     = 18;      // % progress per manual expedition
    const STEPS_PER_REGION = 5000;    // steps that auto-advance exploration

    // ── Palette ──────────────────────────────────────────────────────────────
    const BG      = 0x05070D;
    const CIRCLE  = 0x0B1018;
    const ACCENT  = 0x33C0FF;
    const TEXT    = 0xE6F0F7;
    const MUTED   = 0x7C8BA0;
    const PANEL   = 0x111A26;
    const PANEL_HI= 0x1A2736;
    const GOLD    = 0xFFC24A;

    function _c(v, lo, hi) {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }
}
