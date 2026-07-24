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
    // IDs are SAVE KEYS (sc_b<i>) — never renumber, only append at the end.
    const B_N        = 15;
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
    const B_GEO      = 10; // geothermal plant — heavy energy
    const B_TRADE    = 11; // trade hub — heavy credits + better supply drops
    const B_REFINERY = 12; // ore refinery — heavy minerals
    const B_ICE      = 13; // ice works — heavy water
    const B_QUANTUM  = 14; // quantum core — global mult (endgame)

    function bName(i) {
        var a = ["Habitat", "Reactor", "Mine", "Farm", "Laboratory",
                 "Launch Pad", "Satellite", "Alien Lab", "Space Elevator", "Defense Grid",
                 "Geo Plant", "Trade Hub", "Refinery", "Ice Works", "Quantum Core"];
        return a[_c(i, 0, B_N - 1)];
    }
    // ASCII glyph (device fonts render these everywhere; emoji do not).
    function bGlyph(i) {
        var a = ["H", "E", "M", "F", "L", "^", "o", "A", "I", "*",
                 "G", "$", "R", "W", "Q"];
        return a[_c(i, 0, B_N - 1)];
    }
    function bColor(i) {
        var a = [0x6FB3FF, 0xFFC24A, 0x9FB0C0, 0x4CC85A, 0x4CE0C0,
                 0xFF7A4A, 0xB46CFF, 0x9A6CFF, 0x8CD0FF, 0xFF5A7A,
                 0xFF8A2A, 0x8CFF6A, 0xD0A070, 0x7FE8FF, 0xE06CFF];
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
    // Kept SHORT on purpose — every one of these strings is resident memory.
    function bDesc(i) {
        var a = [
            "Houses colonists. Raises pop cap.",
            "Fusion core. Makes Energy.",
            "Extracts Minerals.",
            "Hydro-farm. Makes Water.",
            "Researches Science.",
            "Speeds up expeditions.",
            "Orbital relay. Makes Credits.",
            "Boosts all Science.",
            "Boosts ALL production.",
            "Shields against disasters.",
            "Magma tap. Bulk Energy.",
            "Orbital market. Bulk Credits.",
            "Smelts ore. Bulk Minerals.",
            "Melts ice. Bulk Water.",
            "Warps output. Boosts ALL."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Which resource a building produces, or -1 (utility).
    function bProdRes(i) {
        var a = [-1, R_NRG, R_MIN, R_H2O, R_SCI, -1, R_CRE, -1, -1, -1,
                 R_NRG, R_CRE, R_MIN, R_H2O, -1];
        return a[_c(i, 0, B_N - 1)];
    }
    // Base production at level 1 (per hour).
    function bBaseProd(i) {
        var a = [0, 12, 10, 8, 4, 0, 3, 0, 0, 0,
                 40, 14, 34, 30, 0];
        return a[_c(i, 0, B_N - 1)];
    }
    // Region that must be discovered before this can be built (-1 = available).
    function bUnlockRegion(i) {
        var a = [-1, -1, -1, -1, -1, RG_DESERT, RG_FROZEN, RG_FOREST, RG_CRYSTAL, RG_RUINS,
                 RG_STORM, RG_STORM, RG_CAVERN, RG_OCEAN, RG_CORE];
        return a[_c(i, 0, B_N - 1)];
    }
    function bAdvanced(i) { return i >= B_LAUNCH; }
    // Late-game structures are ALSO priced in Credits — the main credit sink.
    function bCredit(i) { return i >= B_GEO; }

    // Production at a given level: 10 -> 25 -> 40 (base*(3L-1)/2).
    function prodAt(i, lvl) {
        if (lvl <= 0) { return 0; }
        if (lvl > LVL_CAP) { lvl = LVL_CAP; }
        var base = bBaseProd(i);
        return base * (3 * lvl - 1) / 2;
    }

    // Geometric cost escalation that can never overflow a 32-bit Number: past
    // SOFT_LVL the multiplier steepens, and the running value is clamped to
    // COST_CAP (far beyond any reachable stockpile) so a corrupt/absurd level
    // can't wrap negative and hand out free upgrades.
    const SOFT_LVL  = 12;          // levels beyond this escalate harder
    const LVL_CAP   = 200;         // hard sanity cap on any level
    const COST_CAP  = 500000000;   // 5e8 — max representable cost

    function escalate(v, steps, pctEarly, pctLate) {
        if (v < 1) { v = 1; }
        if (steps > LVL_CAP) { steps = LVL_CAP; }
        for (var k = 0; k < steps; k++) {
            var p = (k < SOFT_LVL - 1) ? pctEarly : pctLate;
            // Split the multiply so the intermediate never exceeds 2^31.
            if (v > 2000000) { v = v / 100 * p; } else { v = v * p / 100; }
            if (v >= COST_CAP) { return COST_CAP; }
        }
        return v;
    }

    // Upgrade/build cost for going to `lvl` (level 1 = first build).
    // Returns [minerals, energy, science, credits].
    function costAt(i, lvl) {
        if (lvl < 1) { lvl = 1; }
        if (lvl > LVL_CAP) { lvl = LVL_CAP; }
        var steps = lvl - 1;
        var m = escalate(40 + i * 20, steps, 170, 185);
        var e = escalate(25 + i * 12, steps, 170, 185);
        var s = 0;
        if (bAdvanced(i)) { s = escalate(30 + (i - B_LAUNCH) * 25, steps, 160, 178); }
        var cr = 0;
        if (bCredit(i)) { cr = escalate(150 + (i - B_GEO) * 110, steps, 170, 185); }
        return [m, e, s, cr];
    }

    // ── Regions (planet exploration) ─────────────────────────────────────────
    // IDs are SAVE KEYS (sc_rg<i>) + discovery bitmask bits — append only.
    const RG_N       = 9;
    const RG_DESERT  = 0;  // Red Desert
    const RG_FROZEN  = 1;  // Frozen Valley
    const RG_CRYSTAL = 2;  // Crystal Mountains
    const RG_FOREST  = 3;  // Alien Forest
    const RG_RUINS   = 4;  // Ancient Ruins
    const RG_STORM   = 5;  // Storm Basin
    const RG_CAVERN  = 6;  // Deep Caverns
    const RG_OCEAN   = 7;  // Ice Ocean
    const RG_CORE    = 8;  // Planet Core

    function rgName(i) {
        var a = ["Red Desert", "Frozen Valley", "Crystal Mountains", "Alien Forest", "Ancient Ruins",
                 "Storm Basin", "Deep Caverns", "Ice Ocean", "Planet Core"];
        return a[_c(i, 0, RG_N - 1)];
    }
    function rgColor(i) {
        var a = [0xE0663A, 0x8CD0FF, 0xB46CFF, 0x4CC85A, 0xC9A24A,
                 0xFF8A2A, 0x8CFF6A, 0x7FE8FF, 0xE06CFF];
        return a[_c(i, 0, RG_N - 1)];
    }
    // Building unlocked on discovery.
    function rgUnlockBuilding(i) {
        var a = [B_LAUNCH, B_SAT, B_ELEVATOR, B_ALIEN, B_DEFENSE,
                 B_GEO, B_REFINERY, B_ICE, B_QUANTUM];
        return a[_c(i, 0, RG_N - 1)];
    }
    function rgDiscovery(i) {
        var a = ["Deep Ore Vein", "Ancient Crystal Cave", "Gravity Anomaly",
                 "Living Xeno-Flora", "The First Ones' Vault",
                 "Thunder Magma Vent", "Endless Ore Gallery",
                 "Frozen Sea of Glass", "The Living Core"];
        return a[_c(i, 0, RG_N - 1)];
    }
    // Steps needed to fully map a region — later regions take multiple days.
    // 5k for the Red Desert climbing to ~101k for the Planet Core.
    function stepsForRegion(i) {
        return 5000 + _c(i, 0, RG_N - 1) * 12000;
    }
    // Energy burnt by one manual expedition tick (scales with region).
    function exploreCostNrg(i) {
        return EXPLORE_COST_NRG + _c(i, 0, RG_N - 1) * 18;
    }
    // Percent of a region mapped by one manual expedition tick. Later regions
    // are bigger, so the same effort covers proportionally less ground.
    function exploreStepPct(i) {
        var p = EXPLORE_STEP * 5000 / stepsForRegion(i);
        return (p < 2) ? 2 : p;
    }

    // ── Technology tree ──────────────────────────────────────────────────────
    // IDs are SAVE KEYS (sc_t<i>) — append only.
    const T_N     = 7;
    const T_EFF   = 0;  // +8%/lvl ALL production
    const T_EXTR  = 1;  // +15%/lvl minerals
    const T_POWER = 2;  // +15%/lvl energy
    const T_RES   = 3;  // +15%/lvl science
    const T_HYDRO = 4;  // +15%/lvl water
    const T_TRADE = 5;  // +15%/lvl credits
    const T_GENE  = 6;  // faster colonist growth

    function tName(i) {
        var a = ["Efficiency", "Deep Extraction", "Power Grid", "Research AI",
                 "Hydrology", "Trade Routes", "Gene Therapy"];
        return a[_c(i, 0, T_N - 1)];
    }
    function tDesc(i) {
        var a = ["+8% all output / lvl", "+15% minerals / lvl", "+15% energy / lvl", "+15% science / lvl",
                 "+15% water / lvl", "+15% credits / lvl", "+20% pop growth / lvl"];
        return a[_c(i, 0, T_N - 1)];
    }
    // Science cost to research the next level (steepens past SOFT_LVL).
    function tCost(i, lvl) {
        if (lvl < 0) { lvl = 0; }
        return escalate(60 + i * 20, lvl, 180, 195);
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
    const POP_MIN_IVL  = 1800;        // floor on that interval (Gene Therapy)
    const EXPLORE_COST_NRG = 15;      // base energy per manual expedition tick
    const EXPLORE_STEP     = 18;      // base % progress per manual expedition
    const WATER_PER_POP = 25;         // water drunk by each new colonist
    const RES_CAP = 1000000000;       // stockpile ceiling (overflow guard)
    const RATE_CAP = 10000000;        // hourly-rate ceiling (overflow guard)

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
