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

    // ── Farm structures (4 categories, 16 core + 6 late-game) ────────────────
    const B_N        = 22;
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
    // LATE GAME (appended — never renumber)
    const B_ALPACA   = 16;  // livestock: huge herd cap
    const B_SUNFLR   = 17;  // crops: lots of feed
    const B_CREAMRY  = 18;  // market: big coins
    const B_CIDER    = 19;  // legendary market
    const B_MOONBARN = 20;  // legendary special: coins + herd
    const B_HARVMOON = 21;  // legendary special: global multiplier

    // 0=livestock 1=crops 2=market 3=special
    function bCat(i) {
        i = _c(i, 0, B_N - 1);
        if (i < 16) { return i / 4; }
        var a = [0, 1, 2, 2, 3, 3];
        return a[i - 16];
    }
    function catName(c) {
        var a = ["LIVESTOCK", "CROPS", "MARKET", "SPECIAL"];
        return a[_c(c, 0, 3)];
    }

    function bName(i) {
        var a = ["Chicken Coop", "Duck Pond", "Pig Pen", "Cow Barn",
                 "Wheat Field", "Carrot Patch", "Orchard", "Berry Bushes",
                 "Farm Stand", "Windmill", "Bakery", "Petting Zoo",
                 "Golden Barn", "Greenhouse", "Prize Bull", "Rainbow Silo",
                 "Alpaca Herd", "Sunflowers", "Creamery",
                 "Cider Mill", "Moonlit Barn", "Harvest Moon"];
        return a[_c(i, 0, B_N - 1)];
    }
    function bColor(i) {
        var a = [0xF0D060, 0xF0A860, 0xFF9AB0, 0xE07A6A,
                 0xE8C24A, 0xFF9A4A, 0x4CC85A, 0xB46CFF,
                 0xFFD98A, 0xC8A070, 0xFFC24A, 0xFF7FA0,
                 0xFFD24A, 0x8CE0A0, 0xFF6A6A, 0x9AE0FF,
                 0xE8D8B0, 0xFFD24A, 0xEAF2F0,
                 0xC86A3A, 0x9AB0FF, 0xFFE07A];
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
            "Boosts ALL production.",
            "Alpacas. Huge herd cap.",
            "Sunflowers. Lots of Feed.",
            "Creamery. Big Coins.",
            "Cider mill. Huge Coins.",
            "Moon barn. Coins + herd.",
            "Harvest Moon. Boosts ALL."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Resource produced, or -1 (utility: livestock cap / multipliers).
    function bProdRes(i) {
        var a = [-1, -1, -1, -1,
                 R_GRAIN, R_FEED, R_WOOD, R_COIN,
                 R_COIN, R_COIN, R_COIN, R_COIN,
                 R_COIN, -1, R_COIN, -1,
                 -1, R_FEED, R_COIN,
                 R_COIN, R_COIN, -1];
        return a[_c(i, 0, B_N - 1)];
    }
    function bBaseProd(i) {
        var a = [0, 0, 0, 0,
                 10, 8, 12, 8,
                 15, 22, 30, 45,
                 60, 0, 80, 0,
                 0, 70, 110,
                 200, 320, 0];
        return a[_c(i, 0, B_N - 1)];
    }
    // Herd capacity added per level (livestock only).
    function bPopPer(i) {
        var a = [2, 4, 8, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 28, 0, 0, 0, 24, 0];
        return a[_c(i, 0, B_N - 1)];
    }
    // Attraction weight per level (drives guests).
    function bAttract(i) {
        var a = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 2, 0, 3, 1,
                 2, 1, 5, 7, 6, 10];
        return a[_c(i, 0, B_N - 1)];
    }
    // Exploration area required to build this, or -1.
    function bUnlockArea(i) {
        var a = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                 AR_MEADOW, AR_WOODS, AR_POND, AR_HILLS,
                 -1, AR_VALE, -1, AR_MILL, AR_HOME, AR_RIDGE];
        return a[_c(i, 0, B_N - 1)];
    }

    // Production at level: base*(3L-1)/2.
    function prodAt(i, lvl) {
        if (lvl <= 0) { return 0; }
        if (lvl > LVL_MAX) { lvl = LVL_MAX; }
        return bBaseProd(i) * (3 * lvl - 1) / 2;
    }
    // Cost for the next level -> [coins, wood, grain].
    // x1.6 per level up to level 12, then a steeper x1.75 so the late game stays
    // a real climb. The escalation runs in 64-bit and is capped at COST_MAX:
    // in 32-bit maths it wraps negative around level 30, which would hand out
    // free upgrades forever.
    function costAt(i, lvl) {
        i = _c(i, 0, B_N - 1);
        if (lvl < 1) { lvl = 1; }
        if (lvl > LVL_MAX) { lvl = LVL_MAX; }
        var coin = (30 + i * 18).toLong();
        var wood = (12 + i * 6).toLong();
        // The Wheat Field is the only grain source, so it must never cost grain.
        var grain = ((i >= 4 && i != B_WHEAT) ? (8 + i * 4) : 0).toLong();
        var cap = COST_MAX.toLong();
        for (var k = 1; k < lvl; k++) {
            var n = (k < COST_SOFT_LVL) ? 16l  : 175l;
            var d = (k < COST_SOFT_LVL) ? 10l  : 100l;
            coin  = coin  * n / d;
            wood  = wood  * n / d;
            grain = grain * n / d;
            if (coin > cap)  { coin = cap; }
            if (wood > cap)  { wood = cap; }
            if (grain > cap) { grain = cap; }
            if (coin >= cap) { break; }
        }
        return [coin.toNumber(), wood.toNumber(), grain.toNumber()];
    }

    // ── Exploration areas ──────────────────────────────────────────────────────
    const AR_N       = 9;
    const AR_MEADOW  = 0;
    const AR_WOODS   = 1;
    const AR_POND    = 2;
    const AR_HILLS   = 3;
    const AR_HOME    = 4;   // Old Homestead
    // LATE GAME (appended — never renumber)
    const AR_VALE    = 5;
    const AR_MILL    = 6;
    const AR_MARSH   = 7;
    const AR_RIDGE   = 8;

    function arName(i) {
        var a = ["Meadow", "Woods", "Pond", "Hills", "Old Homestead",
                 "Sun Vale", "Cider Mill", "Foggy Marsh", "Moon Ridge"];
        return a[_c(i, 0, AR_N - 1)];
    }
    function arColor(i) {
        var a = [0x6FD06A, 0x8C7B5A, 0x33C0FF, 0xC9A24A, 0xE0A860,
                 0xFFD24A, 0xC86A3A, 0x7FA8A0, 0x9AB0FF];
        return a[_c(i, 0, AR_N - 1)];
    }
    function arDiscovery(i) {
        var a = ["Wildflower Field", "Ancient Oak", "Hidden Spring", "Golden Beehive", "The Old Homestead",
                 "Sunflower Vale", "The Cider Mill", "Marsh Lantern", "Harvest Moon Ridge"];
        return a[_c(i, 0, AR_N - 1)];
    }
    // Structure unlocked (or -1 -> grants a charm instead, see arGrantColl).
    function arUnlockBuilding(i) {
        var a = [B_GOLDBARN, B_GREENHSE, B_PRIZEBULL, B_SILO, -1,
                 B_SUNFLR, B_CIDER, -1, B_HARVMOON];
        return a[_c(i, 0, AR_N - 1)];
    }
    // Charm granted by areas that unlock no structure, or -1.
    function arGrantColl(i) {
        var a = [-1, -1, -1, -1, C_RIBBON, -1, -1, C_LANTERN, -1];
        return a[_c(i, 0, AR_N - 1)];
    }
    // Steps needed to walk an area open — later areas take several days.
    function stepsForArea(i) {
        return STEPS_PER_AREA + _c(i, 0, AR_N - 1) * STEPS_PER_AREA_INC;
    }
    // Exploration % earned by a given number of (real or scouted) steps.
    function pctForSteps(i, steps) {
        if (steps == null || steps <= 0) { return 0; }
        if (steps > 1000000) { steps = 1000000; }
        var need = stepsForArea(i);
        if (need < 1) { need = 1; }
        return steps * 100 / need;
    }
    // Coins per manual scouting trip — scales with the area so a trip always
    // buys the same amount of ground.
    function exploreCost(i) {
        return EXPLORE_COST_COIN * stepsForArea(i) / STEPS_PER_AREA;
    }

    // ── Collection (charming farm decorations) ─────────────────────────────────
    const C_N = 15;
    const C_RIBBON  = 7;
    const C_LANTERN = 11;
    function cName(i) {
        var a = ["Flower Bed", "Scarecrow", "Hay Bales", "Golden Egg",
                 "Pond Ducks", "Rainbow Cow", "Wishing Well",
                 "Prize Ribbon", "Harvest Feast",
                 "Bee Hive", "Stone Bridge", "Marsh Lantern",
                 "Sun Crown", "Moon Cart", "Golden Plow"];
        return a[_c(i, 0, C_N - 1)];
    }
    function cRare(i) {
        // Golden Egg, Rainbow Cow, Prize Ribbon, Harvest Feast + the late set.
        return i == 3 || i == 5 || i == 7 || i == 8 || i >= 10;
    }
    function cColor(i) {
        var a = [0xFF9AC0, 0xC9A24A, 0xE8C24A, 0xFFD24A,
                 0x8CE0FF, 0xFF7FA0, 0x9FB0C0, 0xFF6A6A, 0xFF9A4A,
                 0xFFD86A, 0x9FB0C0, 0x8CE0FF,
                 0xFFE24A, 0xB46CFF, 0xFFD24A];
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
    const EXPLORE_COST_COIN = 40;          // coins per manual scouting trip (area 0)
    const STEPS_PER_AREA    = 5000;        // steps for the first area
    const STEPS_PER_AREA_INC= 3500;        // added per later area
    const EXPLORE_TRIP_STEPS= 900;         // step-equivalent of one manual trip
    const FEED_PER_ANIMAL   = 4;           // feed eaten by each new animal
    const COST_SOFT_LVL     = 12;          // x1.6 below this level, x1.75 above
    const COST_MAX          = 2000000000;  // upgrade-cost ceiling (32-bit safe)
    const RES_MAX           = 2000000000;  // resource ceiling (32-bit safe)
    const LVL_MAX           = 400;         // bounds cost/production loops

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
