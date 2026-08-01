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

    // Production at level: base*(3L-1)/2, plus a +15% tier bonus every 5 levels.
    // The linear-only curve fell so far behind the cost curve that a building
    // stopped being worth deepening; the tier steps keep a long investment in
    // one structure competitive with starting a fresh one. The level clamp keeps
    // a corrupt/legacy save value from overflowing the 32-bit result.
    function prodAt(i, lvl) {
        if (lvl <= 0) { return 0; }
        if (lvl > 4000) { lvl = 4000; }
        var base = bBaseProd(i) * (3 * lvl - 1) / 2;
        var tier = lvl / 5;
        if (tier > 40) { tier = 40; }        // caps the multiplier at x7
        if (tier <= 0) { return base; }
        return base * (100 + tier * 15) / 100;
    }

    // Growth escalates in three bands: x1.45 through the early levels a daily
    // player actually buys, x1.6 up to level 20, x1.75 past that so late levels
    // stay a genuine long-term goal. The gentle first band is what removes the
    // multi-day dead zone where nothing on the list was affordable at all.
    // Single source of truth for costs.
    const COST_MAX     = 600000000;   // stop growing here — never overflow 32-bit
    const COST_LVL_CAP = 150;
    // Late-tier (id >= 16) entry premium so the new structures are an end-game
    // project, kept low enough that a committed island can actually reach them.
    function costAt(i, lvl) {
        if (lvl < 1) { lvl = 1; }
        if (lvl > COST_LVL_CAP) { lvl = COST_LVL_CAP; }
        var coin = 30 + i * 18;
        var wood = 12 + i * 6;
        var stone = (i >= 4) ? (8 + i * 4) : 0;
        // The quarry is the island's only source of stone, so it can never ask
        // for stone itself — otherwise a fresh island is locked out of every
        // structure above the housing tier for good.
        if (i == B_TRAIL) { stone = 0; }
        if (i >= 16) {
            var t = i - 15;
            coin  += t * t * 450;
            wood  += t * t * 140;
            stone += t * t * 60;
        }
        for (var k = 1; k < lvl; k++) {
            if (coin >= COST_MAX) { break; }
            if (k < 8)       { coin = _m145(coin); wood = _m145(wood); stone = _m145(stone); }
            else if (k < 20) { coin = _m16(coin);  wood = _m16(wood);  stone = _m16(stone); }
            else             { coin = _m175(coin); wood = _m175(wood); stone = _m175(stone); }
        }
        return [coin, wood, stone];
    }
    // Overflow-safe growth steps: exact while the value is small, divide-first
    // once it is big enough that value*multiplier would wrap a 32-bit int.
    function _m145(v) { return (v < 14000000)  ? (v * 145 / 100) : (v / 20 * 29); }
    function _m16(v)  { return (v < 100000000) ? (v * 16 / 10)   : (v / 5 * 8); }
    function _m175(v) { return (v < 12000000)  ? (v * 175 / 100) : (v / 4 * 7); }

    // ── Building detail cards ────────────────────────────────────────────────
    // Two short sentences that place the structure on the island and hint at
    // why it matters. Sized to wrap into at most two FONT_XTINY lines.
    function bLore(i) {
        var a = [
            "Canvas, rope and hope. Every island paradise started under one.",
            "Four walls and a warm window. People stay once there is a door.",
            "Wide verandas and sea views. Guests arrive and forget to leave.",
            "Stone that outlives its builders. The island finally has a skyline.",
            "Planted young, felled slowly. The grove pays for the whole village.",
            "Neat beds of sweet roots. Full bellies grow into more neighbours.",
            "Trade boats put in at the still water. Coin follows the current.",
            "Switchbacks cut into the ridge. The mountain gives up its stone.",
            "Soft sand raked every morning. Visitors pay simply to lie on it.",
            "Sand and cheering. The island discovers it enjoys a crowd.",
            "Lanterns strung between the palms. Nobody sleeps on festival week.",
            "Marble, shade and cold drinks. Wealthy guests bring wealthy friends.",
            "Older than the jungle around it. The steps were carved for someone.",
            "It hums at dawn and the whole island works a little faster.",
            "Carved from one red boulder. Sailors change course to see it.",
            "It should not float, and it does. The clouds arrange themselves.",
            "A spire of glass homes. The lift takes a full minute to climb.",
            "The saw never stops. Timber leaves faster than the forest grows.",
            "Deep-water berths for long white boats. Harbour fees do the rest.",
            "It drinks the sunrise and the quarry works twice as hard.",
            "Raised from the drowned city, still wet, still counting its treasure.",
            "A tear in the sky, held open. Wealth arrives from somewhere else."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Exact mechanical effect per level, in plain words.
    function bEffectText(i) {
        var a = [
            "+2 population cap per level",
            "+4 population cap per level",
            "+8 population cap per level",
            "+16 population cap per level",
            "Wood per hour, +50% per level",
            "Food per hour, +50% per level",
            "Coins per hour, +50% per level",
            "Stone per hour, +50% per level",
            "Coins per hour, +1 attraction per level",
            "Coins per hour, +2 attraction per level",
            "Coins per hour, +3 attraction per level",
            "Coins per hour, +4 attraction per level",
            "Big Coins per hour, +2 attraction",
            "+10% to ALL production per level",
            "Big Coins per hour, +3 attraction",
            "+15% to ALL production per level",
            "+32 population cap per level",
            "Heavy Wood per hour, +50% per level",
            "Heavy Coins per hour, +5 attraction",
            "Heavy Stone per hour, +4 attraction",
            "Vast Coins per hour, +8 attraction",
            "Endless Coins per hour, +12 attraction"
        ];
        return a[_c(i, 0, B_N - 1)];
    }

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
    // in-progress saves are unaffected; the new areas cost more per push, but
    // gently enough that the far areas are not priced out of a daily session.
    function exploreCost(i) {
        var k = _c(i, 0, AR_N - 1);
        if (k < 5) { return EXPLORE_COST_COIN; }
        var t = k - 4;
        return EXPLORE_COST_COIN + t * t * 300;
    }
    // % progress a single manual expedition buys, scaled to the same curve. The
    // floor keeps the deepest areas from needing fifty separate pushes.
    function exploreStep(i, bonusPct) {
        if (bonusPct < 0) { bonusPct = 0; }
        var v = (EXPLORE_STEP + bonusPct) * STEPS_PER_AREA / stepsForArea(i);
        if (v < 4) { v = 4; }
        return v;
    }

    // ── Discovery detail cards ───────────────────────────────────────────────
    // Field notes: what the expedition actually walked into out there.
    function arLore(i) {
        var a = [
            "Green dark, loud with birds. Something stone-faced watches the path.",
            "A crack behind the waterfall, then a room that answers your voice.",
            "The ground is warm through your boots. The summit smokes politely.",
            "Cold water falling into a pool nobody has swum in for centuries.",
            "Streets under the leaf litter. This island was somebody's kingdom.",
            "A shelf of living colour, two fathoms down and worth the swim.",
            "Above the clouds the air tastes of lightning. Nothing grows here.",
            "Roofs under the waves. The tide keeps the front doors shut.",
            "A seam of open sky that hums. Compasses point at it, not north."
        ];
        return a[_c(i, 0, AR_N - 1)];
    }
    // What finishing the expedition actually gives the player.
    function arEffectText(i) {
        var b = arUnlockBuilding(i);
        if (b >= 0) { return "Reveals " + arDiscovery(i) + " and unlocks " + bName(b); }
        return "Reveals " + arDiscovery(i) + " and grants " + cName(arGrantColl(i));
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
    function cRareName(i) { return cRare(i) ? "Rare" : "Common"; }

    // ── Collection detail cards ──────────────────────────────────────────────
    // Museum label for each decoration: what it is, told in one breath.
    function cLore(i) {
        var a = [
            "Nine palms in a ring. Shade at noon, coconuts by evening.",
            "Every shell on this beach, sorted by the patient and the small.",
            "A guardian face cut in soft wood. The village sleeps better.",
            "Its leaves really are gold. It refuses to say how.",
            "A garden of living stone that repaints itself every season.",
            "It falls in slow blue crystal instead of water, and it never runs dry.",
            "Carved before anyone counted years. Still facing the sunrise.",
            "Raised by the old kingdom to mark something they never wrote down.",
            "Seven colours in the spray, all day, in any weather.",
            "Pearls in a circle of white gold. Fit for whoever owns this island.",
            "Rung once on the peak. Storms are said to change their minds.",
            "Salvaged from a drowned hall. It is warm and nobody knows why.",
            "A splinter of the sky seam. Light bends around it politely.",
            "A pearl the size of a fist, from an oyster nobody has seen.",
            "A flower that will not close. The island grew it as a thank you."
        ];
        return a[_c(i, 0, C_N - 1)];
    }
    // Where the piece turns up — sets the player a concrete next goal.
    function cOrigin(i) {
        var a = [
            "Island level 10", "Beach visitors", "Village festivals",
            "Island level 35", "Island level 20", "Island level 60",
            "Coral Shelf expedition", "Chests and traders", "Island level 100",
            "Coral Shelf expedition", "Island level 150", "Island level 220",
            "Island level 300", "Island level 400", "Island level 550"
        ];
        return a[_c(i, 0, C_N - 1)];
    }
    // Why the player should care: the collection feeds two leaderboards.
    function cValueText(i) {
        return "+" + cWeight(i) + " collection score, +" + (cWeight(i) * 4) + " beauty"
             + (cRare(i) ? " (rare)" : "");
    }

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

    // ── Daily loop ───────────────────────────────────────────────────────────
    // Seven challenge varieties so a full week never repeats the same task.
    // The rotation is derived from the day number, never stored, so widening it
    // cannot disturb an existing save.
    const DAILY_N        = 7;
    const DAILY_COIN     = 250;   // floor payout, before level + streak scaling
    const DAILY_WOOD     = 80;
    const DAILY_STREAK_PCT = 10;  // reward bonus per consecutive day
    const DAILY_STREAK_MAX = 100; // ... capped at +100%
    // Streak milestones. Reaching one pays a lump sum worth day*30% of a daily
    // reward; 7 and 30 also guarantee a collectible so the long streaks move the
    // collection, not just the purse.
    const MS_N = 4;
    function msDay(i) {
        var a = [3, 7, 14, 30];
        return a[_c(i, 0, MS_N - 1)];
    }
    function msGrantsColl(i) {
        var d = msDay(i);
        return d == 7 || d == 30;
    }

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
