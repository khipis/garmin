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

    // ── Buildings (4 categories × 4) ─────────────────────────────────────────
    const B_N        = 16;
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

    function bCat(i) { return _c(i, 0, B_N - 1) / 4; }   // 0=house 1=nature 2=fun 3=special
    function catName(c) {
        var a = ["HOUSING", "NATURE", "ENTERTAINMENT", "SPECIAL"];
        return a[_c(c, 0, 3)];
    }

    function bName(i) {
        var a = ["Tent", "House", "Villa", "Castle",
                 "Forest", "Garden", "Lake", "Mountain Trail",
                 "Beach", "Arena", "Festival Area", "Resort",
                 "Ancient Temple", "Crystal Tower", "Dragon Statue", "Sky Palace"];
        return a[_c(i, 0, B_N - 1)];
    }
    function bColor(i) {
        var a = [0xC9B08A, 0xE0A860, 0xFFD27A, 0xE6C24A,
                 0x4CC85A, 0x6FD06A, 0x33AEE0, 0x9FB0C0,
                 0xFFD98A, 0xFF9A5A, 0xFF6FA0, 0xB46CFF,
                 0xE0C24A, 0x8CE0FF, 0xFF5A5A, 0xB8A0FF];
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
            "Boosts ALL production."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Resource produced, or -1 (utility: housing / multipliers).
    function bProdRes(i) {
        var a = [-1, -1, -1, -1,
                 R_WOOD, R_FOOD, R_COIN, R_STONE,
                 R_COIN, R_COIN, R_COIN, R_COIN,
                 R_COIN, -1, R_COIN, -1];
        return a[_c(i, 0, B_N - 1)];
    }
    function bBaseProd(i) {
        var a = [0, 0, 0, 0,
                 10, 8, 12, 8,
                 15, 22, 30, 45,
                 60, 0, 80, 0];
        return a[_c(i, 0, B_N - 1)];
    }
    // Population capacity added per level (housing only).
    function bPopPer(i) {
        var a = [2, 4, 8, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        return a[_c(i, 0, B_N - 1)];
    }
    // Attraction weight per level (drives visitors).
    function bAttract(i) {
        var a = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 2, 0, 3, 1];
        return a[_c(i, 0, B_N - 1)];
    }
    // Discovery area required to build this, or -1.
    function bUnlockArea(i) {
        var a = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                 AR_JUNGLE, AR_CAVE, AR_VOLCANO, AR_WATER];
        return a[_c(i, 0, B_N - 1)];
    }

    // Production at level: 10 -> 25 -> 40 (base*(3L-1)/2).
    function prodAt(i, lvl) {
        if (lvl <= 0) { return 0; }
        return bBaseProd(i) * (3 * lvl - 1) / 2;
    }
    // Cost for the next level -> [coins, wood, stone].
    function costAt(i, lvl) {
        if (lvl < 1) { lvl = 1; }
        var coin = 30 + i * 18;
        var wood = 12 + i * 6;
        var stone = (i >= 4) ? (8 + i * 4) : 0;
        for (var k = 1; k < lvl; k++) { coin = coin * 16 / 10; wood = wood * 16 / 10; stone = stone * 16 / 10; }
        return [coin, wood, stone];
    }

    // ── Discovery areas ────────────────────────────────────────────────────────
    const AR_N       = 5;
    const AR_JUNGLE  = 0;
    const AR_CAVE    = 1;
    const AR_VOLCANO = 2;
    const AR_WATER   = 3;   // Waterfall
    const AR_RUINS   = 4;

    function arName(i) {
        var a = ["Jungle", "Cave", "Volcano", "Waterfall", "Ancient Ruins"];
        return a[_c(i, 0, AR_N - 1)];
    }
    function arColor(i) {
        var a = [0x4CC85A, 0x8C7B5A, 0xFF6A3A, 0x33C0FF, 0xC9A24A];
        return a[_c(i, 0, AR_N - 1)];
    }
    function arDiscovery(i) {
        var a = ["Overgrown Idol", "Crystal Cavern", "Obsidian Forge", "Hidden Lagoon", "The Old Kingdom"];
        return a[_c(i, 0, AR_N - 1)];
    }
    // Building unlocked (or -1 -> grants a collectible instead).
    function arUnlockBuilding(i) {
        var a = [B_TEMPLE, B_CRYSTAL, B_DRAGON, B_SKY, -1];
        return a[_c(i, 0, AR_N - 1)];
    }

    // ── Collection (decorations) ───────────────────────────────────────────────
    const C_N = 9;
    function cName(i) {
        var a = ["Palm Grove", "Seashell Set", "Tiki Totem", "Golden Tree",
                 "Coral Reef", "Crystal Waterfall", "Stone Idol",
                 "Ancient Monument", "Rainbow Fountain"];
        return a[_c(i, 0, C_N - 1)];
    }
    function cRare(i) {
        // Golden Tree, Crystal Waterfall, Ancient Monument, Rainbow Fountain
        return i == 3 || i == 5 || i == 7 || i == 8;
    }
    function cColor(i) {
        var a = [0x4CC85A, 0xFFB6C1, 0xC9A24A, 0xFFD24A,
                 0xFF7FA0, 0x8CE0FF, 0x9FB0C0, 0xE0C24A, 0x9AE0FF];
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
    const EXPLORE_STEP      = 18;          // % progress per expedition
    const STEPS_PER_AREA    = 5000;

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
