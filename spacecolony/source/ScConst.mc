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
    const LB_RELIC   = "Relic";   // richest alien artifact collection
    const LB_WAR     = "War";     // war rating points (raid record)

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
    // Story flavour for the building detail card — two short sentences that put
    // the structure on planet X-01 and hint at why the colony needs it.
    function bLore(i) {
        var a = [
            "Pressurised glass over red dust. Every colonist sleeps here.",
            "A caged star. No lamp in the domes flickers while it burns.",
            "A headframe over the first ore seam the survey drones ever tagged.",
            "Racked greens under grow-lamps. It drinks ice, returns water.",
            "Where the planet gets taken apart and written down.",
            "Scorched apron, fuelled rocket. From here the maps get bigger.",
            "A dish that talks to the shipping lanes and sells them our ore.",
            "Salvaged xeno tech nobody fully understands, wired into our grid.",
            "A ribbon to orbit. Cargo leaves the gravity well for pennies.",
            "Rail guns pointed at the sky - and at raiders drawn to a rich colony.",
            "A shaft sunk into magma. The ground itself powers the base.",
            "An orbital market. What the colony lacks arrives by tonight.",
            "Raw rock in one end, clean structural alloy out the other.",
            "It swallows glacier and returns drinking water by the tank.",
            "A caged singularity that bends the numbers. Nobody stands close."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Exact mechanical effect per level, in plain words.
    function bEffectText(i) {
        var a = [
            "+4 population cap per level",
            "+12 Energy/h base per level",
            "+10 Minerals/h base per level",
            "+8 Water/h base per level",
            "+4 Science/h base per level",
            "+6% expedition ground and +1 sortie per 2 levels",
            "+6 Credits/h base per level",
            "+12% Science output per level",
            "+10% to ALL production per level",
            "+15% disaster shield per level (max 90%)",
            "+40 Energy/h base per level",
            "+14 Credits/h base and +180 supply drop per level",
            "+34 Minerals/h base per level",
            "+30 Water/h base per level",
            "+18% to ALL production per level"
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
    // Credits gate every late structure, and a Satellite at 3/h could never
    // fund one before the Trade Hub existed; Science gates the whole tech tree
    // in the same way, so both starting taps run a notch richer.
    function bBaseProd(i) {
        var a = [0, 12, 10, 8, 5, 0, 6, 0, 0, 0,
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

    // Production at a given level. The linear term alone (base*(3L-1)/2) fell
    // ever further behind the geometric price, so a mild compounding factor
    // rides on top: +4% of base output per level, capped at +800%. Both terms
    // are bounded well inside 32-bit range at LVL_CAP.
    function prodAt(i, lvl) {
        if (lvl <= 0) { return 0; }
        if (lvl > LVL_CAP) { lvl = LVL_CAP; }
        var base = bBaseProd(i);
        var v = base * (3 * lvl - 1) / 2;
        var scale = 100 + lvl * 4;
        if (scale > 900) { scale = 900; }
        return v * scale / 100;
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
        // 1.70x/level outran the production curve within a dozen levels and
        // stranded every structure behind a wall no daily player could clear;
        // the softer slope keeps at least one upgrade in reach every session.
        var m = escalate(40 + i * 20, steps, 138, 152);
        var e = escalate(25 + i * 12, steps, 138, 152);
        var s = 0;
        if (bAdvanced(i)) { s = escalate(30 + (i - B_LAUNCH) * 25, steps, 134, 148); }
        var cr = 0;
        if (bCredit(i)) { cr = escalate(150 + (i - B_GEO) * 110, steps, 140, 154); }
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
    // Survey notes for the region detail card — what the crew walked into.
    function rgLore(i) {
        var a = [
            "Iron sand to the horizon. The rovers came back orange and loaded.",
            "A valley that never thaws. Our lamps threw blue shadows.",
            "Spires taller than the mast, ringing softly when the wind turns.",
            "Growth that leans toward the lamps and closes when we walk away.",
            "Cut stone, sealed doors, and a stair built for something taller.",
            "Lightning walks the basin all day. The magma below never cools.",
            "Galleries under galleries. The survey drones ran out of power.",
            "A frozen sea clear to the seabed. Nothing moves down there.",
            "The planet has a heartbeat, and at this depth you can hear it."
        ];
        return a[_c(i, 0, RG_N - 1)];
    }
    // What mapping the region actually gives the player.
    function rgEffectText(i) {
        return "Unlocks " + bName(rgUnlockBuilding(i)) + " and " + aName(rgArtifact(i));
    }
    // Alien artifact recovered when the region is fully mapped.
    function rgArtifact(i) {
        var a = [A_GLASS, A_LENS, A_SEED, A_SPORE, A_KEY, A_COIL, A_SIGIL, A_TIDE, A_EMBER];
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
    // Story flavour for the technology detail card.
    function tLore(i) {
        var a = [
            "A thousand small fixes nobody logged. The base runs quieter.",
            "Charge patterns that shatter rock along its own grain. No waste.",
            "The grid stopped browning out the night this went live.",
            "An assistant that reads every sensor at once and never gets bored.",
            "We map the ice like a river system, then tap it where it runs.",
            "Better contracts, better lanes, better prices. And it pays.",
            "Gene work so colonists thrive under a sun that is not ours."
        ];
        return a[_c(i, 0, T_N - 1)];
    }
    // Exact mechanical effect per researched level.
    function tEffectText(i) {
        var a = [
            "+8% to ALL production per level",
            "+15% Minerals output per level",
            "+15% Energy output per level",
            "+15% Science output per level",
            "+15% Water output per level",
            "+15% Credits output per level",
            "+20% faster colonist arrivals per level"
        ];
        return a[_c(i, 0, T_N - 1)];
    }

    // ── Alien artifacts (the collection set) ─────────────────────────────────
    // IDs are bits in the sc_art mask — append only, never renumber.
    const A_N     = 14;
    const A_GLASS = 0;   // Desert Glass
    const A_CHART = 1;   // Star Chart Disc
    const A_LENS  = 2;   // Frost Lens
    const A_SEED  = 3;   // Crystal Seed
    const A_SPORE = 4;   // Spore Pod
    const A_KEY   = 5;   // Vault Key
    const A_COIL  = 6;   // Storm Coil
    const A_SIGIL = 7;   // Ore Sigil
    const A_TIDE  = 8;   // Tide Sphere
    const A_EMBER = 9;   // Core Ember
    const A_MASK  = 10;  // First Ones Mask
    const A_COMP  = 11;  // Null Compass
    const A_ECHO  = 12;  // Echo Engine
    const A_SPARK = 13;  // Origin Spark

    function aName(i) {
        var a = ["Desert Glass", "Star Chart Disc", "Frost Lens", "Crystal Seed",
                 "Spore Pod", "Vault Key", "Storm Coil", "Ore Sigil", "Tide Sphere",
                 "Core Ember", "First Ones Mask", "Null Compass", "Echo Engine",
                 "Origin Spark"];
        return a[_c(i, 0, A_N - 1)];
    }
    // 0 common, 1 rare, 2 epic, 3 legendary, 4 mythic.
    function aRarity(i) {
        var a = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4];
        return a[_c(i, 0, A_N - 1)];
    }
    function aRarityName(r) {
        var a = ["Common", "Rare", "Epic", "Legendary", "Mythic"];
        return a[_c(r, 0, 4)];
    }
    function aRarityColor(r) {
        var a = [0x9FB0C0, 0x4CC85A, 0x8C6CFF, 0xFFC24A, 0xFF5AC0];
        return a[_c(r, 0, 4)];
    }
    function aColor(i) { return aRarityColor(aRarity(i)); }
    function aWeight(i) {
        var a = [5, 5, 5, 15, 15, 15, 40, 40, 40, 100, 100, 100, 250, 250];
        return a[_c(i, 0, A_N - 1)];
    }
    function aLegendary(i) { return aRarity(i) >= 3; }
    function aLore(i) {
        var a = [
            "Fused by something far hotter than this sun ever was.",
            "A disc of stars nobody recognises, cut before humans had maps.",
            "Ice that never melts and shows you the valley as it was.",
            "It grew a second spire overnight, inside a sealed sample case.",
            "Sealed, warm, and patient. The biologists refuse to open it.",
            "It fits a door we have found and cannot yet move.",
            "Wound by hand, still holding the charge of an ancient storm.",
            "A miner's mark from a crew that worked this rock before us.",
            "A sphere of liquid that keeps the tide of a moon that is not here.",
            "A splinter of the planet's heart, warm through containment.",
            "It was made for a face, and the face was not a human one.",
            "The needle ignores every pole and points somewhere off the map.",
            "Play it back and the room hears a conversation nobody in it had.",
            "One bright grain. Everything here grew out of one of these."
        ];
        return a[_c(i, 0, A_N - 1)];
    }
    function aOrigin(i) {
        var a = ["Red Desert survey", "Deep space salvage", "Frozen Valley survey",
                 "Crystal Mountains survey", "Alien Forest survey", "Ancient Ruins survey",
                 "Storm Basin survey", "Deep Caverns survey", "Ice Ocean survey",
                 "Planet Core survey", "Civ level 12 milestone", "Rare colony event",
                 "Civ level 25 milestone", "Streak day 30 reward"];
        return a[_c(i, 0, A_N - 1)];
    }
    function aValueText(i) {
        return "+" + aWeight(i) + " relic score"
             + (aLegendary(i) ? " - counts as a legendary find" : "");
    }
    // Science cost to research the next level (steepens past SOFT_LVL).
    function tCost(i, lvl) {
        if (lvl < 0) { lvl = 0; }
        return escalate(60 + i * 20, lvl, 152, 168);
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

    // ── Daily loop ───────────────────────────────────────────────────────────
    // Eight mission varieties so a week-plus of visits never repeats. Ids 0..3
    // keep their original meaning, so a live save's rotation only ever grows.
    const DAILY_N       = 8;
    const STREAK_STEP   = 10;   // % extra daily reward per consecutive day
    const STREAK_CAP    = 100;  // % ceiling on that bonus (2x reward)
    const STREAK_M1     = 3;    // milestone streak lengths
    const STREAK_M2     = 7;    // ... grants an artifact
    const STREAK_M3     = 14;
    const STREAK_M4     = 30;   // ... grants an artifact
    // Civilisation levels that hand over an artifact (one each, once).
    const CIV_RELIC_1   = 12;
    const CIV_RELIC_2   = 25;

    // ── War (military economy + raids) ──────────────────────────────────────
    // Marines are trained from Minerals+Energy; capacity rides on Habitat
    // (housing for the militia) and Defense Grid (command capacity).
    const MARINE_CAP_BASE = 4;
    const MARINE_CAP_HAB  = 2;    // +2 marine cap per Habitat level
    const MARINE_CAP_DEF  = 1;    // +1 marine cap per Defense Grid level
    const MARINE_CAP_MAX  = 60;
    const MARINE_COST_MIN = 50;   // base minerals for the next marine
    const MARINE_COST_NRG = 35;   // base energy for the next marine
    const MARINE_COST_PCT = 106;  // +6% per marine already enlisted

    // Turrets are a separate purchase from the Defense Grid building itself —
    // the Grid raises the *ceiling*, turrets are what you actually buy.
    const TURRET_CAP_BASE  = 3;
    const TURRET_CAP_DEF   = 2;   // +2 turret cap per Defense Grid level
    const TURRET_CAP_MAX   = 40;
    const DEFENSE_COST_MIN = 90;  // base minerals for the next turret
    const DEFENSE_COST_SCI = 45;  // base science for the next turret
    const DEFENSE_COST_PCT = 108; // +8% per turret already installed

    // Raiding: a small energy toll to launch a sortie (never buildings/pop),
    // rationed per day like expeditions so it can't be farmed in one sitting.
    const RAID_COST_NRG    = 25;
    const RAID_CAP_PER_DAY = 5;
    const RAID_BAND_FAIR   = 0;   // favourable odds, modest payout
    const RAID_BAND_RISK   = 1;   // harder odds, richer payout
    // Odds window per band, as a percentage of this colony's attack power.
    function raidBandLo(band) { return (band == RAID_BAND_RISK) ? 85 : 55; }
    function raidBandHi(band) { return (band == RAID_BAND_RISK) ? 145 : 95; }

    // Rival roster — REAL colonies read off the shared War board, cached so
    // raiding behaves identically offline. Eight names keep the persisted blob
    // small; the fetch is a once-a-day luxury, never a dependency.
    const RIV_MAX      = 8;
    // Counted in view frames (the 66 ms animation tick) rather than held on a
    // Timer of their own: the leaderboard pipeline already sits at the device
    // timer budget and one more allocation crashed the app on launch.
    const RIV_DELAY_TICKS = 150;  // ~10 s — wait out launch ping -> msgs -> daily
    const RIV_WAIT_TICKS  = 14;   // ~0.9 s — re-check while the request slot is busy
    const RIV_WAIT_MAX = 12;      // ... then give up rather than poll forever
    const RIV_NAME_MAX = 12;
    // A rival's board score is a cumulative rating, not a defense stat, so it
    // is compressed 2/5 into the range colony power lives in — a 500-pt
    // Overlord should read as a hard fight, not an impossible one.
    const RIV_PWR_BASE = 18;
    const RIV_PWR_NUM  = 2;
    const RIV_PWR_DEN  = 5;
    function rivalPower(pts) {
        var p = pts;
        if (p < 0) { p = 0; }
        if (p > 1000000) { p = 1000000; }
        return RIV_PWR_BASE + p * RIV_PWR_NUM / RIV_PWR_DEN;
    }

    // Incoming attacks. There is no server-side PvP, so rival raids that
    // happened while the player was away are rolled on return — the only
    // moment they can be experienced anyway. Deliberately low-stakes:
    // buildings, population and the garrison beyond a single casualty are
    // never at risk, and a loss can never take a stockpile below zero.
    const DEF_ROLL_HOURS = 8;     // one attempt per 8h of absence
    const DEF_MAX_ROLLS  = 3;     // ... capped, however long the absence was
    const DEF_CHANCE_PCT = 45;
    const DEF_HELD_PTS   = 4;
    const DEF_LOST_PTS   = 5;
    const DEF_SKIM_PCT   = 3;     // % of the mineral stockpile a loss costs
    const DEF_SKIM_CAP   = 500;   // hard ceiling — a raid must never gut a save,
                                  // so late on this is pocket change by design
    const DEF_MARINE_MIN = 2;     // garrison size a casualty is only taken above
    const DEF_MARINE_PCT = 35;
    const DEF_BAND_LO    = 60;    // attacker strength window, as a % of this
    const DEF_BAND_HI    = 140;   // ... colony's own defense power
    const DLOG_MAX       = 8;     // persisted defence-log entries

    // Raid stance — a flat trade-off between this colony's own attack and
    // defense power, picked before a raid and left in place until changed.
    const STANCE_ASSAULT  = 0;
    const STANCE_BALANCED = 1;
    const STANCE_FORTIFY  = 2;
    function stanceName(i) {
        var a = ["Assault", "Balanced", "Fortify"];
        return a[_c(i, 0, 2)];
    }
    function stanceAtkBonus(i) {
        var a = [24, 10, 0];
        return a[_c(i, 0, 2)];
    }
    function stanceDefBonus(i) {
        var a = [0, 10, 24];
        return a[_c(i, 0, 2)];
    }

    // Rival colonies for the war layer — flavour names only, generated
    // locally so raiding always works offline. Never renumber; append only.
    const WAR_FOE_N = 10;
    function warFoeName(i) {
        var a = ["Outpost Krell", "Vega-9", "Iron Reach", "New Meridian",
                 "Ashfall Station", "Dust Hollow", "Zenith Colony",
                 "Blackrock Base", "Halcyon Drift", "Ember Vault"];
        return a[_c(i, 0, WAR_FOE_N - 1)];
    }
    // Cosmetic rank ladder climbed with cumulative war points.
    function warRankName(pts) {
        if (pts >= 500) { return "Overlord"; }
        if (pts >= 260) { return "Warlord"; }
        if (pts >= 140) { return "Vanguard"; }
        if (pts >= 60)  { return "Sentinel"; }
        if (pts >= 20)  { return "Guard"; }
        return "Militia";
    }

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
