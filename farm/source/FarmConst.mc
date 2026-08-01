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

    // ── Detail-card flavour: what a structure is, and exactly what it does ────
    function bLore(i) {
        var a = [
            "A crooked little coop. The hens were here before the fence was.",
            "Rain filled a hollow and the ducks moved in the same afternoon.",
            "Mud, straw and contentment. They out-eat everything else you own.",
            "Warm, dim and smelling of hay. The heart of any working farm.",
            "Gold to the fence line. It bends in the wind like slow water.",
            "Neat green tufts hiding sweet roots. The animals know where.",
            "Grandmother planted the first row. You still prune it her way.",
            "Thorny, generous, and always picked over by somebody's children.",
            "A plank, a scale and an honesty box. Half the valley stops here.",
            "Its sails turned through four owners and never missed a harvest.",
            "The smell reaches the road. That is the entire marketing plan.",
            "Small hands, patient animals, and a queue every single weekend.",
            "Painted the colour of a good year. Visitors photograph it first.",
            "Warm glass and green light. Everything outside grows faster too.",
            "Champion three shows running. He knows it, and he poses.",
            "Painted by the whole village one summer. It stores more than grain.",
            "Curious, woolly, faintly disapproving. The children adore them.",
            "A field of faces that follow the sun and feed the whole herd.",
            "Cold rooms, copper churns, and butter with a waiting list.",
            "The old press wakes each autumn and the yard smells of apples.",
            "Silver boards that glow after dusk. The animals sleep better here.",
            "It hangs low over the ridge and refuses to set. Everything ripens."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    function bEffectText(i) {
        var a = [
            "+2 herd space per level",
            "+4 herd space per level",
            "+8 herd space per level",
            "+16 herd space per level",
            "+10 grain/h at Lv1, more every level",
            "+8 feed/h at Lv1, more every level",
            "+12 wood/h at Lv1, more every level",
            "+8 coins/h at Lv1, more every level",
            "+15 coins/h and +1 attraction per level",
            "+22 coins/h and +2 attraction per level",
            "+30 coins/h and +3 attraction per level",
            "+45 coins/h and +4 attraction per level",
            "+60 coins/h and +2 attraction per level",
            "+10% to ALL production per level",
            "+80 coins/h and +3 attraction per level",
            "+15% to ALL production per level",
            "+28 herd space and +2 attraction per level",
            "+70 feed/h and +1 attraction per level",
            "+110 coins/h and +5 attraction per level",
            "+200 coins/h and +7 attraction per level",
            "+320 coins/h, +24 herd, +6 attraction per level",
            "+25% to ALL production per level"
        ];
        return a[_c(i, 0, B_N - 1)];
    }

    // ── Scene placement: which depth lane a structure stands in, and where ────
    // The HOME diorama is a three-lane stage. Every structure owns one explicit
    // slot so the farm reads as fields receding into the distance instead of a
    // single row. Slot x runs -100..100 and is narrowed per lane by laneSpread
    // so the top and bottom lanes stay inside a round watch's inscribed circle.
    const LN_BACK  = 0;
    const LN_MID   = 1;
    const LN_FRONT = 2;
    const LN_N     = 3;

    function laneY(l)      { var a = [50, 67, 82];  return a[_c(l, 0, LN_N - 1)]; }
    function laneScale(l)  { var a = [72, 88, 106]; return a[_c(l, 0, LN_N - 1)]; }
    function laneSpread(l) { var a = [96, 92, 76];  return a[_c(l, 0, LN_N - 1)]; }

    function bLane(i) {
        var a = [1, 2, 2, 1, 1, 2, 0, 2, 2, 0, 1, 1,
                 0, 0, 0, 0, 1, 1, 2, 0, 0, 0];
        return a[_c(i, 0, B_N - 1)];
    }
    function bSlotX(i) {
        var a = [-56, 24, -42, -78, -14, -72, -84, 80, -10, 40, 26, 54,
                 -34, -8, 16, 64, 84, -96, 52, 86, -58, -66];
        return a[_c(i, 0, B_N - 1)];
    }
    function cLane(i) {
        var a = [2, 1, 2, 2, 2, 1, 1, 0, 2, 0, 2, 1, 0, 0, 2];
        return a[_c(i, 0, C_N - 1)];
    }
    function cSlotX(i) {
        var a = [-88, -30, -56, 8, 34, 8, -80, 2, 66, -72, -24, 40, 28, -46, 90];
        return a[_c(i, 0, C_N - 1)];
    }

    // Production at level: base*L*(L+3)/4 — a quadratic curve, so upgrades keep
    // pace with the exponential cost ladder instead of falling behind it.
    function prodAt(i, lvl) {
        if (lvl <= 0) { return 0; }
        if (lvl > LVL_MAX) { lvl = LVL_MAX; }
        return bBaseProd(i) * lvl * (lvl + 3) / 4;
    }
    // Cost for the next level -> [coins, wood, grain].
    // x1.6 per level up to COST_SOFT_LVL, then a steeper x1.68 so the late game
    // stays a climb without walling off. The escalation runs in 64-bit and is
    // capped at COST_MAX: in 32-bit maths it wraps negative around level 30,
    // which would hand out free upgrades forever.
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
            var n = (k < COST_SOFT_LVL) ? 16l  : 168l;
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
    // ── Detail-card flavour for the expeditions ───────────────────────────────
    function arLore(i) {
        var a = [
            "Waist-high grass and bees. Walk it once and the paths appear.",
            "Old timber, soft light, and a stump wide enough to eat lunch on.",
            "Still water at the bottom of the paddock, warmer than it should be.",
            "A long climb for a short view, and the view is worth every step.",
            "The roof is gone but the hearth is intact. Somebody farmed here.",
            "A whole valley facing south, yellow ridge to ridge by August.",
            "The press has not turned in years. The apples kept growing anyway.",
            "Reeds, mist, and one steady light that nobody can walk up to.",
            "The highest ground you own. On clear nights the moon sits on it."
        ];
        return a[_c(i, 0, AR_N - 1)];
    }
    // What the expedition finds and what finishing it opens up.
    function arEffectText(i) {
        i = _c(i, 0, AR_N - 1);
        var b = arUnlockBuilding(i);
        if (b >= 0) { return "Finds " + arDiscovery(i) + " - unlocks " + bName(b); }
        var g = arGrantColl(i);
        if (g >= 0) { return "Finds " + arDiscovery(i) + " - grants " + cName(g); }
        return "Finds " + arDiscovery(i);
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
    function cLore(i) {
        var a = [
            "Planted the spring the farm opened. It never needed any help.",
            "Stuffed with last year's straw. The crows respect him, mostly.",
            "Stacked by hand at dusk. Cats sleep on top, all of them at once.",
            "One hen, one morning, one egg that would not crack. Never sold.",
            "They arrived on their own and stayed. The pond is theirs now.",
            "She was born after a storm with a coat nobody can explain.",
            "The bucket still comes up cold. Visitors throw in coins and hope.",
            "First place at the county fair. The nail it hangs on came with it.",
            "Long table, short speeches, everything on it grown right here.",
            "The bees moved in uninvited and doubled the orchard that year.",
            "Older than the farm. The mason's initials are still under the moss.",
            "Found lit in the marsh with nobody near it. It has not gone out.",
            "Woven at midsummer from the tallest sunflowers in the whole vale.",
            "It rolls without a horse on full moons. Nobody rides it twice.",
            "Turns ground that grew nothing into a field before breakfast."
        ];
        return a[_c(i, 0, C_N - 1)];
    }
    // Where a charm turns up — every locked slot is a concrete next goal.
    function cOrigin(i) {
        var a = ["Farm level 10", "Farm events", "Farm events", "Farm level 35",
                 "Farm level 20", "Farm level 60", "Farm events",
                 "Explore the Old Homestead", "Farm level 100",
                 "Farm level 150", "Farm level 220", "Explore the Foggy Marsh",
                 "Farm level 300", "Farm level 400", "Farm level 550"];
        return a[_c(i, 0, C_N - 1)];
    }
    // Charms feed the Charm and Collection boards at x4 their weight.
    function cValueText(i) {
        i = _c(i, 0, C_N - 1);
        return "+" + (cWeight(i) * 4) + " charm score" + (cRare(i) ? " - a rare charm" : "");
    }

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
    const STEPS_PER_AREA_INC= 2500;        // added per later area
    const EXPLORE_TRIP_STEPS= 1200;        // step-equivalent of one manual trip
    const FEED_PER_ANIMAL   = 4;           // feed eaten by each new animal
    const COST_SOFT_LVL     = 15;          // x1.6 below this level, x1.68 above

    // ── Daily loop ────────────────────────────────────────────────────────────
    // The floor of the daily bundle; the real payout scales with farm level and
    // the current hourly rate on top of this, then by the streak multiplier.
    const DAILY_N          = 8;            // challenge varieties in the rotation
    const DAILY_BASE_COIN  = 250;
    const DAILY_BASE_WOOD  = 80;
    const DAILY_BASE_FEED  = 20;
    const STREAK_STEP_PCT  = 10;           // +10% per consecutive day
    const STREAK_MAX_PCT   = 200;          // capped at +100%
    const MILE_N           = 4;
    function mileDay(i)  { var a = [3, 7, 14, 30]; return a[_c(i, 0, MILE_N - 1)]; }
    function mileMult(i) { var a = [2, 4, 8, 12];  return a[_c(i, 0, MILE_N - 1)]; }
    // Milestones that hand over a guaranteed charm as well as the bundle.
    function mileCharm(i) { i = _c(i, 0, MILE_N - 1); return i == 1 || i == 3; }
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
