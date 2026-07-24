// ═══════════════════════════════════════════════════════════════════════════
// IsConst.mc — Shared data + tuning for ISLAND.
//
// A cozy idle island builder: discover an empty island and slowly grow it into
// a rare personal paradise that keeps developing while you're away. Return
// daily to collect income, greet visitors, build & upgrade structures, explore
// hidden areas and chase the "most beautiful island" dream. Data-only so every
// module reads the same tables.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;

module Is {

    // Showcase-only DEMO fast-track — hidden from users in shipped builds.
    const SHOW_DEMO = false;

    // ── Leaderboard ──────────────────────────────────────────────────────────
    const GAME_ID = "island";
    const LB_LEVEL   = "Level";   // highest island level (primary)
    const LB_BEAUTY  = "Beauty";  // most beautiful island
    const LB_POP      = "Pop";    // largest population
    const LB_COLLECT = "Collect"; // rarest collection

    // ── Resources ────────────────────────────────────────────────────────────
    const R_N     = 4;
    const R_COIN  = 0;
    const R_WOOD  = 1;
    const R_STONE = 2;
    const R_FOOD  = 3;

    function resName(i) {
        var a = ["Coins", "Wood", "Stone", "Food"];
        return a[_c(i, 0, R_N - 1)];
    }
    function resAbbr(i) {
        var a = ["COIN", "WOOD", "STONE", "FOOD"];
        return a[_c(i, 0, R_N - 1)];
    }
    function resColor(i) {
        var a = [0xFFC24A, 0xC08A54, 0x9FB0C0, 0x6FD06A];
        return a[_c(i, 0, R_N - 1)];
    }

    // ── Buildings (ids are SAVE KEYS — only ever append) ─────────────────────
    const B_N        = 22;
    // HOUSING
    const B_TENT     = 0;
    const B_HOUSE    = 1;
    const B_VILLA    = 2;
    const B_CASTLE   = 3;
    // NATURE
    const B_FOREST   = 4;   // wood
    const B_GARDEN   = 5;   // food
    const B_LAKE     = 6;   // coins
    const B_TRAIL    = 7;   // stone (Mountain Trail)
    // ENTERTAINMENT
    const B_BEACH    = 8;   // coins + attraction
    const B_ARENA    = 9;
    const B_FESTIVAL = 10;
    const B_RESORT   = 11;
    // SPECIAL
    const B_TEMPLE   = 12;  // coins
    const B_CRYSTAL  = 13;  // global multiplier
    const B_DRAGON   = 14;  // coins + attraction
    const B_SKY      = 15;  // global multiplier
    // ── Late game (appended) ──
    const B_TOWER    = 16;  // HOUSING  — huge population cap
    const B_MILL     = 17;  // NATURE   — heavy Wood
    const B_MARINA   = 18;  // FUN      — heavy Coins
    const B_OBELISK  = 19;  // MYTHIC   — heavy Stone   (needs Storm Peak)
    const B_SHRINE   = 20;  // MYTHIC   — vast Coins    (needs Sunken City)
    const B_RIFT     = 21;  // MYTHIC   — endless Coins (needs Sky Rift)

    // 0=house 1=nature 2=fun 3=special. Explicit table: the old `i / 4` rule
    // produced invalid categories 4/5 once the list grew past 16.
    function bCat(i) {
        var a = [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
                 0, 1, 2, 3, 3, 3];
        return a[_c(i, 0, B_N - 1)];
    }
    function catName(c) {
        var a = ["HOUSING", "NATURE", "ENTERTAINMENT", "SPECIAL"];
        return a[_c(c, 0, 3)];
    }

    function bName(i) {
        var a = ["Tent", "House", "Villa", "Castle",
                 "Forest", "Garden", "Lake", "Mountain Trail",
                 "Beach", "Arena", "Festival Area", "Resort",
                 "Ancient Temple", "Crystal Tower", "Dragon Statue", "Sky Palace",
                 "Sky Tower", "Timber Mill", "Grand Marina",
                 "Sun Obelisk", "Sunken Shrine", "Rift Gate"];
        return a[_c(i, 0, B_N - 1)];
    }
    function bColor(i) {
        var a = [0xC9B08A, 0xE0A860, 0xFFD27A, 0xE6C24A,
                 0x4CC85A, 0x6FD06A, 0x33AEE0, 0x9FB0C0,
                 0xFFD98A, 0xFF9A5A, 0xFF6FA0, 0xB46CFF,
                 0xE0C24A, 0x8CE0FF, 0xFF5A5A, 0xB8A0FF,
                 0xA0C8FF, 0x8A6A3A, 0x4AE0C8,
                 0xFFB03A, 0x3AE0A0, 0xD070FF];
        return a[_c(i, 0, B_N - 1)];
    }
    function bDesc(i) {
        var a = [
            "Basic shelter. +population cap.",
            "Cozy home. +population cap.",
            "Luxury villa. ++population cap.",
            "Grand castle. +++population cap.",
            "Produces Wood.",
            "Grows Food.",
            "Trade lake. Produces Coins.",
            "Quarries Stone.",
            "Draws visitors. +Coins.",
            "Events arena. ++Coins.",
            "Festival grounds. +++Coins.",
            "Luxury resort. ++++Coins.",
            "Sacred site. Big Coins.",
            "Boosts ALL production.",
            "Legendary draw. Big Coins.",
            "Boosts ALL production.",
            "Spire homes. Huge pop cap.",
            "Big Wood output.",
            "Yacht docks. Huge Coins.",
            "Mythic. Huge Stone.",
            "Mythic. Vast Coins.",
            "Mythic. Endless Coins."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Resource produced, or -1 (utility: housing / multipliers).
    function bProdRes(i) {
        var a = [-1, -1, -1, -1,
                 R_WOOD, R_FOOD, R_COIN, R_STONE,
                 R_COIN, R_COIN, R_COIN, R_COIN,
                 R_COIN, -1, R_COIN, -1,
                 -1, R_WOOD, R_COIN,
                 R_STONE, R_COIN, R_COIN];
        return a[_c(i, 0, B_N - 1)];
    }
    function bBaseProd(i) {
        var a = [0, 0, 0, 0,
                 10, 8, 12, 8,
                 15, 22, 30, 45,
                 60, 0, 80, 0,
                 0, 45, 70,
                 90, 160, 260];
        return a[_c(i, 0, B_N - 1)];
    }
    // Population capacity added per level (housing only).
    function bPopPer(i) {
        var a = [2, 4, 8, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 32, 0, 0, 0, 0, 0];
        return a[_c(i, 0, B_N - 1)];
    }
    // Attraction weight per level (drives visitors).
    function bAttract(i) {
        var a = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 2, 0, 3, 1,
                 2, 0, 5, 4, 8, 12];
        return a[_c(i, 0, B_N - 1)];
    }
    // Discovery area required to build this, or -1.
    function bUnlockArea(i) {
        var a = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                 AR_JUNGLE, AR_CAVE, AR_VOLCANO, AR_WATER,
                 -1, -1, -1,
                 AR_PEAK, AR_SUNKEN, AR_RIFT];
        return a[_c(i, 0, B_N - 1)];
    }

    // Production at level: 10 -> 25 -> 40 (base*(3L-1)/2). The level clamp keeps
    // a corrupt/legacy save value from overflowing the 32-bit result.
    function prodAt(i, lvl) {
        if (lvl <= 0) { return 0; }
        if (lvl > 4000) { lvl = 4000; }
        return bBaseProd(i) * (3 * lvl - 1) / 2;
    }

    // Growth escalates: x1.6 while levelling up to 12, x1.75 past that, so late
    // levels stay a genuine long-term goal. Single source of truth for costs.
    const COST_MAX     = 600000000;   // stop growing here — never overflow 32-bit
    const COST_LVL_CAP = 150;
    // Late-tier (id >= 16) entry premium so the new structures are an end-game
    // project rather than something a week-old island can buy outright.
    function costAt(i, lvl) {
        if (lvl < 1) { lvl = 1; }
        if (lvl > COST_LVL_CAP) { lvl = COST_LVL_CAP; }
        var coin = 30 + i * 18;
        var wood = 12 + i * 6;
        var stone = (i >= 4) ? (8 + i * 4) : 0;
        if (i >= 16) {
            var t = i - 15;
            coin  += t * t * 700;
            wood  += t * t * 220;
            stone += t * t * 90;
        }
        for (var k = 1; k < lvl; k++) {
            if (coin >= COST_MAX) { break; }
            if (k < 12) { coin = _m16(coin);  wood = _m16(wood);  stone = _m16(stone); }
            else        { coin = _m175(coin); wood = _m175(wood); stone = _m175(stone); }
        }
        return [coin, wood, stone];
    }
    // Overflow-safe growth steps: exact while the value is small, divide-first
    // once it is big enough that value*multiplier would wrap a 32-bit int.
    function _m16(v)  { return (v < 100000000) ? (v * 16 / 10)   : (v / 5 * 8); }
    function _m175(v) { return (v < 12000000)  ? (v * 175 / 100) : (v / 4 * 7); }

    // ── Discovery areas (ids are SAVE KEYS — only ever append) ────────────────
    const AR_N       = 9;
    const AR_JUNGLE  = 0;
    const AR_CAVE    = 1;
    const AR_VOLCANO = 2;
    const AR_WATER   = 3;   // Waterfall
    const AR_RUINS   = 4;
    const AR_CORAL   = 5;
    const AR_PEAK    = 6;
    const AR_SUNKEN  = 7;
    const AR_RIFT    = 8;

    function arName(i) {
        var a = ["Jungle", "Cave", "Volcano", "Waterfall", "Ancient Ruins",
                 "Coral Shelf", "Storm Peak", "Sunken City", "Sky Rift"];
        return a[_c(i, 0, AR_N - 1)];
    }
    function arColor(i) {
        var a = [0x4CC85A, 0x8C7B5A, 0xFF6A3A, 0x33C0FF, 0xC9A24A,
                 0xFF7FA0, 0x9AB0FF, 0x2A7FA8, 0xB46CFF];
        return a[_c(i, 0, AR_N - 1)];
    }
    function arDiscovery(i) {
        var a = ["Overgrown Idol", "Crystal Cavern", "Obsidian Forge", "Hidden Lagoon",
                 "The Old Kingdom", "Pearl Beds", "Thunder Spire", "Drowned Halls", "The Rift"];
        return a[_c(i, 0, AR_N - 1)];
    }
    // Building unlocked (or -1 -> grants the collectible from arGrantColl).
    function arUnlockBuilding(i) {
        var a = [B_TEMPLE, B_CRYSTAL, B_DRAGON, B_SKY, -1,
                 -1, B_OBELISK, B_SHRINE, B_RIFT];
        return a[_c(i, 0, AR_N - 1)];
    }
    // Collectible granted by a building-less area (was hardcoded to 7).
    function arGrantColl(i) {
        var a = [7, 7, 7, 7, 7, 9, 7, 7, 7];
        return a[_c(i, 0, AR_N - 1)];
    }
    // Steps needed to fully explore an area from the daily step auto-advance.
    // Scales with the area index so the late areas span several days.
    function stepsForArea(i) {
        return STEPS_PER_AREA + _c(i, 0, AR_N - 1) * 3500;
    }
    // Coins per manual expedition. The five original areas keep the flat 40 so
    // in-progress saves are unaffected; the new areas cost far more per push.
    function exploreCost(i) {
        var k = _c(i, 0, AR_N - 1);
        if (k < 5) { return EXPLORE_COST_COIN; }
        var t = k - 4;
        return EXPLORE_COST_COIN + t * t * 500;
    }
    // % progress a single manual expedition buys, scaled to the same curve.
    function exploreStep(i, bonusPct) {
        if (bonusPct < 0) { bonusPct = 0; }
        var v = (EXPLORE_STEP + bonusPct) * STEPS_PER_AREA / stepsForArea(i);
        if (v < 2) { v = 2; }
        return v;
    }

    // ── Collection (ids are SAVE BITS — only ever append) ─────────────────────
    const C_N = 15;
    function cName(i) {
        var a = ["Palm Grove", "Seashell Set", "Tiki Totem", "Golden Tree",
                 "Coral Reef", "Crystal Waterfall", "Stone Idol",
                 "Ancient Monument", "Rainbow Fountain",
                 "Pearl Crown", "Storm Bell", "Sunken Relic",
                 "Sky Shard", "Titan Pearl", "Eternal Bloom"];
        return a[_c(i, 0, C_N - 1)];
    }
    function cRare(i) {
        // Golden Tree, Crystal Waterfall, Ancient Monument, Rainbow Fountain,
        // plus every late-game piece except the Storm Bell.
        if (i >= 9) { return i != 10; }
        return i == 3 || i == 5 || i == 7 || i == 8;
    }
    function cColor(i) {
        var a = [0x4CC85A, 0xFFB6C1, 0xC9A24A, 0xFFD24A,
                 0xFF7FA0, 0x8CE0FF, 0x9FB0C0, 0xE0C24A, 0x9AE0FF,
                 0xFFE0F0, 0xBFD8E8, 0x2AB0A0,
                 0xB8A0FF, 0xEAF6F2, 0xFF6FA0];
        return a[_c(i, 0, C_N - 1)];
    }
    function cWeight(i) { return cRare(i) ? 5 : 2; }

    // ── Visitors ────────────────────────────────────────────────────────────
    function visitorType(i) {
        var a = ["Tourists", "Scientists", "Artists", "Explorers"];
        return a[_c(i, 0, 3)];
    }

    // ── Events ────────────────────────────────────────────────────────────────
    const EV_NONE     = -1;
    const EV_STORM    = 0;  // auto: minor loss
    const EV_TREASURE = 1;  // choice: open chest
    const EV_ANIMAL   = 2;  // auto: rare animal -> visitors / collectible
    const EV_FESTIVAL = 3;  // auto: big coins + visitors
    const EV_TRAVELER = 4;  // choice: ancient traveler

    function evTitle(i) {
        var a = ["Storm", "Treasure Found", "Rare Animal", "Festival", "Ancient Traveler"];
        return a[_c(i, 0, 4)];
    }
    function evBody(i) {
        var a = [
            "A storm swept across the island.",
            "A chest washed up near the beach.",
            "A rare animal wandered onto the island!",
            "The island is throwing a festival!",
            "A mysterious traveler asks to trade."
        ];
        return a[_c(i, 0, 4)];
    }
    function evHasChoice(i) { return i == EV_TREASURE || i == EV_TRAVELER; }

    // ── Tuning ───────────────────────────────────────────────────────────────
    const OFFLINE_CAP       = 24 * 3600;
    const POP_INTERVAL      = 3 * 3600;    // seconds per new resident
    const VISITOR_INTERVAL  = 1200;        // seconds per new visitor
    const EXPLORE_COST_COIN = 40;          // coins per manual expedition
    const EXPLORE_STEP      = 18;          // % progress per expedition (area 0)
    const STEPS_PER_AREA    = 5000;        // base only — see stepsForArea(i)

    // ── Palette (cozy daytime island) ──────────────────────────────────────────
    const BG      = 0x071B2A;
    const CIRCLE  = 0x0A2536;
    const ACCENT  = 0x37D0C0;
    const TEXT    = 0xEAF6F2;
    const MUTED   = 0x7FA0AC;
    const PANEL   = 0x0F2A3A;
    const PANEL_HI= 0x174257;
    const GOLD    = 0xFFC24A;
    const OCEAN   = 0x1E7FA8;
    const OCEAN2  = 0x2AA0C8;
    const SAND    = 0xE9D6A0;

    function _c(v, lo, hi) {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }
}
