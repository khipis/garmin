// ═══════════════════════════════════════════════════════════════════════════
// MnConst.mc — Shared data + tuning for BITOCHI MINES.
//
// An idle mining / underground-exploration / collection game. The core axis is
// DEPTH: your miners dig deeper while you're away, crossing depth zones that
// yield richer resources, reveal discoveries, and drop rare collectibles.
// Build an underground base, upgrade pickaxes & carts, and chase legendary
// finds. Data-only so every module reads the same tables.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;

module Mn {

    // Showcase-only DEMO fast-track — hidden from users in shipped builds.
    const SHOW_DEMO = false;

    // ── Leaderboard ──────────────────────────────────────────────────────────
    const GAME_ID = "mines";
    const LB_DEPTH  = "Depth";   // deepest mine (primary)
    const LB_RICH   = "Rich";    // richest miner
    const LB_LEGEND = "Legend";  // most legendary finds
    const LB_LEVEL  = "Level";   // highest mine level
    const LB_AGE    = "Age";     // oldest mine

    // ── Resources ────────────────────────────────────────────────────────────
    const R_N     = 4;
    const R_STONE = 0;
    const R_IRON  = 1;
    const R_GOLD  = 2;
    const R_GEM   = 3;

    function resName(i) {
        var a = ["Stone", "Iron", "Gold", "Gems"];
        return a[_c(i, 0, R_N - 1)];
    }
    function resAbbr(i) {
        var a = ["STN", "IRN", "GLD", "GEM"];
        return a[_c(i, 0, R_N - 1)];
    }
    function resColor(i) {
        var a = [0xA79A8A, 0xC6CAD2, 0xFFC24A, 0x4CE6E0];
        return a[_c(i, 0, R_N - 1)];
    }
    function resValue(i) {
        var a = [1, 4, 20, 120];   // worth for "richest miner"
        return a[_c(i, 0, R_N - 1)];
    }

    // ── Depth zones ────────────────────────────────────────────────────────────
    const Z_N = 5;
    function zoneMin(i) {
        var a = [0, 100, 300, 700, 1500];
        return a[_c(i, 0, Z_N - 1)];
    }
    function zoneOf(depth) {
        if (depth >= 1500) { return 4; }
        if (depth >= 700)  { return 3; }
        if (depth >= 300)  { return 2; }
        if (depth >= 100)  { return 1; }
        return 0;
    }
    function zName(i) {
        var a = ["Surface Mine", "Deep Caverns", "Ancient Underground", "Unknown World", "The Abyss"];
        return a[_c(i, 0, Z_N - 1)];
    }
    function zColor(i) {
        var a = [0x6E5A44, 0x4A6A78, 0x6A4A78, 0x3A5A8A, 0x2A2038];
        return a[_c(i, 0, Z_N - 1)];
    }
    // Relative resource yield weights per zone [stone, iron, gold, gem].
    function zWeight(i, r) {
        var a = [
            [12, 5, 0, 0],
            [7, 7, 4, 1],
            [4, 7, 7, 2],
            [2, 5, 9, 5],
            [1, 4, 9, 9]
        ];
        return a[_c(i, 0, Z_N - 1)][_c(r, 0, R_N - 1)];
    }

    // ── Buildings ────────────────────────────────────────────────────────────
    const B_N        = 7;
    const B_SHAFT    = 0;  // digging speed
    const B_FORGE    = 1;  // mining power (ore yield)
    const B_ELEVATOR = 2;  // depth travel speed
    const B_CAMP     = 3;  // workers
    const B_LAB      = 4;  // research: global multiplier
    const B_GEMWS    = 5;  // gem workshop: gem yield
    const B_SCANNER  = 6;  // deep scanner: discovery/collectible chance

    function bName(i) {
        var a = ["Mine Shaft", "Forge", "Elevator", "Miner Camp", "Laboratory", "Gem Workshop", "Deep Scanner"];
        return a[_c(i, 0, B_N - 1)];
    }
    function bColor(i) {
        var a = [0xC98A4A, 0xFF7A3A, 0x8CC0FF, 0x7AD07A, 0x4CE0C0, 0x4CE6E0, 0xB46CFF];
        return a[_c(i, 0, B_N - 1)];
    }
    function bDesc(i) {
        var a = [
            "Faster digging (+depth/h).",
            "Stronger tools (+ore yield).",
            "Faster depth travel (+depth/h).",
            "More workers (+everything).",
            "Research boosts ALL output.",
            "Processes rare gems (+gem yield).",
            "Finds hidden areas & collectibles."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Depth required before this can be built (surface set = 0).
    function bUnlockDepth(i) {
        var a = [0, 0, 0, 0, 250, 100, 500];
        return a[_c(i, 0, B_N - 1)];
    }
    // Upgrade cost for next level -> [stone, iron, gold, gem].
    function bCostAt(i, lvl) {
        if (lvl < 1) { lvl = 1; }
        var stone = 50 + i * 30;
        var iron  = 8 + i * 8;
        var gold  = (i >= 4) ? (8 + i * 4) : 0;
        var gem   = (i == B_GEMWS || i == B_SCANNER) ? (3 + i) : 0;
        for (var k = 1; k < lvl; k++) {
            stone = stone * 16 / 10; iron = iron * 16 / 10;
            gold = gold * 16 / 10;   gem = gem * 16 / 10;
        }
        return [stone, iron, gold, gem];
    }

    // ── Equipment: Pickaxes ─────────────────────────────────────────────────
    const PICK_N = 5;
    function pickName(t) {
        var a = ["Wood Pickaxe", "Iron Pickaxe", "Diamond Pickaxe", "Crystal Drill", "Quantum Drill"];
        return a[_c(t, 0, PICK_N - 1)];
    }
    function pickPowerPct(t) {
        var a = [100, 150, 220, 320, 460];
        return a[_c(t, 0, PICK_N - 1)];
    }
    // Cost to upgrade FROM tier t to t+1 -> [stone, iron, gold, gem].
    function pickCost(t) {
        var a = [
            [300, 20, 0, 0],
            [400, 120, 15, 0],
            [500, 200, 90, 5],
            [800, 300, 300, 40]
        ];
        if (t < 0 || t >= PICK_N - 1) { return [0, 0, 0, 0]; }
        return a[t];
    }

    // ── Equipment: Carts ─────────────────────────────────────────────────────
    const CART_N = 3;
    function cartName(t) {
        var a = ["Small Cart", "Mining Wagon", "Auto Transport"];
        return a[_c(t, 0, CART_N - 1)];
    }
    function cartMultPct(t) {
        var a = [100, 145, 200];
        return a[_c(t, 0, CART_N - 1)];
    }
    function cartCost(t) {
        var a = [
            [450, 40, 0, 0],
            [700, 150, 120, 10]
        ];
        if (t < 0 || t >= CART_N - 1) { return [0, 0, 0, 0]; }
        return a[t];
    }

    // ── Collection (rarity) ────────────────────────────────────────────────────
    const C_N = 12;
    // rarity: 0 common, 1 rare, 2 epic, 3 legendary, 4 mythic
    function cName(i) {
        var a = ["Coal", "Fossil", "Gold Nugget", "Crystal", "Meteorite",
                 "Ancient Tool", "Diamond", "Lost Machine", "Rare Relic",
                 "Golden Skull", "Ancient Core", "Unknown Crystal"];
        return a[_c(i, 0, C_N - 1)];
    }
    function cRarity(i) {
        var a = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 4];
        return a[_c(i, 0, C_N - 1)];
    }
    function rarityName(r) {
        var a = ["Common", "Rare", "Epic", "Legendary", "Mythic"];
        return a[_c(r, 0, 4)];
    }
    function rarityColor(r) {
        var a = [0x9AA0A6, 0x4CC85A, 0x8C6CFF, 0xFFC24A, 0xFF5AC0];
        return a[_c(r, 0, 4)];
    }
    function cColor(i) { return rarityColor(cRarity(i)); }
    function cWeight(i) {
        var a = [1, 1, 2, 4, 6, 10, 15, 25, 25, 60, 60, 150];
        return a[_c(i, 0, C_N - 1)];
    }
    function cLegendary(i) { return cRarity(i) >= 3; }

    // ── Depth discoveries ──────────────────────────────────────────────────────
    // Marks the depth thresholds that reveal a discovery (name + collectible).
    const D_N = 5;
    function dDepth(i) {
        var a = [100, 250, 500, 1000, 1500];
        return a[_c(i, 0, D_N - 1)];
    }
    function dName(i) {
        var a = ["Crystal Cave", "Ancient Ruins", "Lost Vault", "Unknown Signal", "The Abyss Gate"];
        return a[_c(i, 0, D_N - 1)];
    }
    function dUnlockText(i) {
        var a = ["Crystal Mining", "Ancient Artifacts", "Deep Scanning", "Mystery Research", "Abyssal Secrets"];
        return a[_c(i, 0, D_N - 1)];
    }
    // Collectible granted by this discovery.
    function dColl(i) {
        var a = [3, 5, 7, 11, 10];   // Crystal, Ancient Tool, Lost Machine, Unknown Crystal, Ancient Core
        return a[_c(i, 0, D_N - 1)];
    }

    // ── Events ────────────────────────────────────────────────────────────────
    const EV_NONE     = -1;
    const EV_QUAKE    = 0;  // choice: explore new tunnel
    const EV_CAVE     = 1;  // auto: hidden cave (+resources)
    const EV_VEIN     = 2;  // auto: rare mineral vein (+gold/gem)
    const EV_MACHINE  = 3;  // auto: ancient machine (collectible)
    const EV_CREATURE = 4;  // choice: unknown creature

    function evTitle(i) {
        var a = ["Earthquake", "Hidden Cave", "Mineral Vein", "Ancient Machine", "Unknown Creature"];
        return a[_c(i, 0, 4)];
    }
    function evBody(i) {
        var a = [
            "A tremor opened a new tunnel below.",
            "Miners broke into a hidden cave.",
            "A rich mineral vein was struck!",
            "An ancient machine hums in the dark.",
            "Something moves beyond the torchlight."
        ];
        return a[_c(i, 0, 4)];
    }
    function evHasChoice(i) { return i == EV_QUAKE || i == EV_CREATURE; }

    // ── Tuning ───────────────────────────────────────────────────────────────
    const OFFLINE_CAP = 24 * 3600;
    const ORE_BASE    = 22;      // base ore/hour at 100% mining power
    const DIG_BASE    = 6;       // base depth m/hour at level 0
    const WORKER_BONUS= 8;       // % production per extra worker

    // ── Palette (underground / amber) ──────────────────────────────────────────
    const BG      = 0x0A0806;
    const CIRCLE  = 0x12100B;
    const ACCENT  = 0xFFA33A;
    const TEXT    = 0xF1E7D8;
    const MUTED   = 0x9A8A76;
    const PANEL   = 0x1E1710;
    const PANEL_HI= 0x2E2216;
    const GOLD    = 0xFFC24A;

    function _c(v, lo, hi) {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }
}
