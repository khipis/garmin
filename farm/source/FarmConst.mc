// ═══════════════════════════════════════════════════════════════════════════
// FarmConst.mc — Shared data + tuning for FARM (module `Fa`).
//
// A cozy idle farm builder: start with a bare paddock and slowly grow it into
// a bustling storybook ranch that keeps producing while you're away. Return
// daily to collect harvests, greet guests, raise animals (chickens, ducks,
// pigs, cows…), plant crops & orchards, explore the land for hidden treasures
// and chase the "prize ranch" dream. Data-only so every module reads the same
// tables.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;

module Fa {

    // Showcase-only DEMO fast-track — hidden from users in shipped builds.
    const SHOW_DEMO = false;

    // ── Leaderboard ──────────────────────────────────────────────────────────
    const GAME_ID = "farm";
    const LB_LEVEL   = "Level";   // highest farm level (primary)
    const LB_CHARM   = "Charm";   // prettiest / most charming farm
    const LB_HERD     = "Herd";   // largest animal herd
    const LB_COLLECT = "Collect"; // rarest collection

    // ── Resources ────────────────────────────────────────────────────────────
    const R_N     = 4;
    const R_COIN  = 0;
    const R_WOOD  = 1;
    const R_GRAIN = 2;
    const R_FEED  = 3;

    function resName(i) {
        var a = ["Coins", "Wood", "Grain", "Feed"];
        return a[_c(i, 0, R_N - 1)];
    }
    function resAbbr(i) {
        var a = ["COIN", "WOOD", "GRN", "FEED"];
        return a[_c(i, 0, R_N - 1)];
    }
    function resColor(i) {
        var a = [0xFFC24A, 0xC08A54, 0xE8C24A, 0x8CD060];
        return a[_c(i, 0, R_N - 1)];
    }

    // ── Farm structures (4 categories × 4) ───────────────────────────────────
    const B_N        = 16;
    // LIVESTOCK  (adds herd capacity)
    const B_COOP     = 0;   // Chicken Coop
    const B_DUCK     = 1;   // Duck Pond
    const B_PIG      = 2;   // Pig Pen
    const B_COW      = 3;   // Cow Barn
    // CROPS  (produce resources)
    const B_WHEAT    = 4;   // grain
    const B_CARROT   = 5;   // feed
    const B_ORCHARD  = 6;   // wood
    const B_BERRY    = 7;   // coins
    // MARKET  (coins + guests)
    const B_STAND    = 8;
    const B_WINDMILL = 9;
    const B_BAKERY   = 10;
    const B_PETZOO   = 11;
    // SPECIAL  (unlocked by exploring the land)
    const B_GOLDBARN = 12;  // big coins
    const B_GREENHSE = 13;  // global multiplier
    const B_PRIZEBULL= 14;  // coins + guests
    const B_SILO     = 15;  // global multiplier

    function bCat(i) { return _c(i, 0, B_N - 1) / 4; }   // 0=livestock 1=crops 2=market 3=special
    function catName(c) {
        var a = ["LIVESTOCK", "CROPS", "MARKET", "SPECIAL"];
        return a[_c(c, 0, 3)];
    }

    function bName(i) {
        var a = ["Chicken Coop", "Duck Pond", "Pig Pen", "Cow Barn",
                 "Wheat Field", "Carrot Patch", "Orchard", "Berry Bushes",
                 "Farm Stand", "Windmill", "Bakery", "Petting Zoo",
                 "Golden Barn", "Greenhouse", "Prize Bull", "Rainbow Silo"];
        return a[_c(i, 0, B_N - 1)];
    }
    function bColor(i) {
        var a = [0xF0D060, 0xF0A860, 0xFF9AB0, 0xE07A6A,
                 0xE8C24A, 0xFF9A4A, 0x4CC85A, 0xB46CFF,
                 0xFFD98A, 0xC8A070, 0xFFC24A, 0xFF7FA0,
                 0xFFD24A, 0x8CE0A0, 0xFF6A6A, 0x9AE0FF];
        return a[_c(i, 0, B_N - 1)];
    }
    function bDesc(i) {
        var a = [
            "Chicken coop. +herd cap.",
            "Duck pond. +herd cap.",
            "Pig pen. ++herd cap.",
            "Cow barn. +++herd cap.",
            "Grows Grain.",
            "Grows Feed.",
            "Orchard. Produces Wood.",
            "Berry bushes. Produces Coins.",
            "Farm stand. +Coins, +guests.",
            "Windmill. ++Coins.",
            "Bakery. +++Coins.",
            "Petting zoo. ++++Coins.",
            "Prize barn. Big Coins.",
            "Boosts ALL production.",
            "Star attraction. Big Coins.",
            "Boosts ALL production."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Resource produced, or -1 (utility: livestock cap / multipliers).
    function bProdRes(i) {
        var a = [-1, -1, -1, -1,
                 R_GRAIN, R_FEED, R_WOOD, R_COIN,
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
    // Herd capacity added per level (livestock only).
    function bPopPer(i) {
        var a = [2, 4, 8, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        return a[_c(i, 0, B_N - 1)];
    }
    // Attraction weight per level (drives guests).
    function bAttract(i) {
        var a = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 2, 0, 3, 1];
        return a[_c(i, 0, B_N - 1)];
    }
    // Exploration area required to build this, or -1.
    function bUnlockArea(i) {
        var a = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                 AR_MEADOW, AR_WOODS, AR_POND, AR_HILLS];
        return a[_c(i, 0, B_N - 1)];
    }

    // Production at level: base*(3L-1)/2.
    function prodAt(i, lvl) {
        if (lvl <= 0) { return 0; }
        return bBaseProd(i) * (3 * lvl - 1) / 2;
    }
    // Cost for the next level -> [coins, wood, grain].
    function costAt(i, lvl) {
        if (lvl < 1) { lvl = 1; }
        var coin = 30 + i * 18;
        var wood = 12 + i * 6;
        var grain = (i >= 4) ? (8 + i * 4) : 0;
        for (var k = 1; k < lvl; k++) { coin = coin * 16 / 10; wood = wood * 16 / 10; grain = grain * 16 / 10; }
        return [coin, wood, grain];
    }

    // ── Exploration areas ──────────────────────────────────────────────────────
    const AR_N       = 5;
    const AR_MEADOW  = 0;
    const AR_WOODS   = 1;
    const AR_POND    = 2;
    const AR_HILLS   = 3;
    const AR_HOME    = 4;   // Old Homestead

    function arName(i) {
        var a = ["Meadow", "Woods", "Pond", "Hills", "Old Homestead"];
        return a[_c(i, 0, AR_N - 1)];
    }
    function arColor(i) {
        var a = [0x6FD06A, 0x8C7B5A, 0x33C0FF, 0xC9A24A, 0xE0A860];
        return a[_c(i, 0, AR_N - 1)];
    }
    function arDiscovery(i) {
        var a = ["Wildflower Field", "Ancient Oak", "Hidden Spring", "Golden Beehive", "The Old Homestead"];
        return a[_c(i, 0, AR_N - 1)];
    }
    // Structure unlocked (or -1 -> grants a collectible instead).
    function arUnlockBuilding(i) {
        var a = [B_GOLDBARN, B_GREENHSE, B_PRIZEBULL, B_SILO, -1];
        return a[_c(i, 0, AR_N - 1)];
    }

    // ── Collection (charming farm decorations) ─────────────────────────────────
    const C_N = 9;
    function cName(i) {
        var a = ["Flower Bed", "Scarecrow", "Hay Bales", "Golden Egg",
                 "Pond Ducks", "Rainbow Cow", "Wishing Well",
                 "Prize Ribbon", "Harvest Feast"];
        return a[_c(i, 0, C_N - 1)];
    }
    function cRare(i) {
        // Golden Egg, Rainbow Cow, Prize Ribbon, Harvest Feast
        return i == 3 || i == 5 || i == 7 || i == 8;
    }
    function cColor(i) {
        var a = [0xFF9AC0, 0xC9A24A, 0xE8C24A, 0xFFD24A,
                 0x8CE0FF, 0xFF7FA0, 0x9FB0C0, 0xFF6A6A, 0xFF9A4A];
        return a[_c(i, 0, C_N - 1)];
    }
    function cWeight(i) { return cRare(i) ? 5 : 2; }

    // ── Guests ────────────────────────────────────────────────────────────────
    function visitorType(i) {
        var a = ["Tourists", "Families", "Foodies", "Farmers"];
        return a[_c(i, 0, 3)];
    }

    // ── Events ──────────────────────────────────────────────────────────────────
    const EV_NONE     = -1;
    const EV_STORM    = 0;  // auto: minor loss
    const EV_TREASURE = 1;  // choice: open crate
    const EV_ANIMAL   = 2;  // auto: stray animal -> guests / collectible
    const EV_FESTIVAL = 3;  // auto: big coins + guests
    const EV_TRAVELER = 4;  // choice: traveling merchant

    function evTitle(i) {
        var a = ["Storm", "Lucky Crate", "Stray Animal", "Harvest Festival", "Traveling Merchant"];
        return a[_c(i, 0, 4)];
    }
    function evBody(i) {
        var a = [
            "A storm rolled over the farm.",
            "A crate was left by the gate.",
            "A stray animal wandered in!",
            "The farm is throwing a festival!",
            "A merchant offers you a trade."
        ];
        return a[_c(i, 0, 4)];
    }
    function evHasChoice(i) { return i == EV_TREASURE || i == EV_TRAVELER; }

    // ── Tuning ───────────────────────────────────────────────────────────────
    const OFFLINE_CAP       = 24 * 3600;
    const POP_INTERVAL      = 3 * 3600;    // seconds per new animal
    const VISITOR_INTERVAL  = 1200;        // seconds per new guest
    const EXPLORE_COST_COIN = 40;          // coins per manual scouting trip
    const EXPLORE_STEP      = 18;          // % progress per trip
    const STEPS_PER_AREA    = 5000;

    // ── Palette (cozy storybook farm daytime) ───────────────────────────────────
    const BG      = 0x0C1E10;
    const CIRCLE  = 0x102A13;
    const ACCENT  = 0x7BC86B;
    const TEXT    = 0xF2F6EA;
    const MUTED   = 0x93A889;
    const PANEL   = 0x163218;
    const PANEL_HI= 0x27522A;
    const GOLD    = 0xFFC24A;
    const SKY     = 0x8FD3F0;
    const GRASS   = 0x5BB84E;
    const SOIL    = 0x8A5A34;

    function _c(v, lo, hi) {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }
}
