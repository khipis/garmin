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
    // Ten layers. The first five keep their original thresholds so live saves
    // land in exactly the zone they were already in; five deep layers extend the
    // world out to 50km.
    const Z_N = 10;
    function zoneMin(i) {
        var a = [0, 100, 300, 700, 1500, 3000, 6000, 12000, 25000, 50000];
        return a[_c(i, 0, Z_N - 1)];
    }
    function zoneOf(depth) {
        for (var i = Z_N - 1; i > 0; i--) {
            if (depth >= zoneMin(i)) { return i; }
        }
        return 0;
    }
    function zName(i) {
        var a = ["Surface Mine", "Deep Caverns", "Ancient Underground", "Unknown World", "The Abyss",
                 "Magma Depths", "Crystal Void", "The Hollow", "Titan Core", "Worlds End"];
        return a[_c(i, 0, Z_N - 1)];
    }
    function zColor(i) {
        // Anchored on the watch's 64-colour palette (channels 00/55/AA/FF):
        // anything in between snapped to a muddy neighbour and the strata read
        // as a stack of saturated stripes instead of rock.
        var a = [0xAA5500, 0xAA5555, 0xAAAAAA, 0x555555, 0x550000,
                 0x555500, 0x005555, 0x005500, 0x550055, 0x000055];
        return a[_c(i, 0, Z_N - 1)];
    }
    // Relative resource yield weights per zone [stone, iron, gold, gem].
    function zWeight(i, r) {
        var a = [
            [12, 5, 0, 0],
            [7, 7, 4, 1],
            [4, 7, 7, 2],
            [2, 5, 9, 5],
            [1, 4, 9, 9],
            [1, 3, 9, 12],
            [1, 2, 8, 15],
            [1, 2, 7, 18],
            [1, 1, 6, 22],
            [1, 1, 5, 28]
            // Stone stays at 1 (not 0) in the last three layers on purpose:
            // every building and equipment tier is priced in stone, so a zero
            // weight there starves the whole upgrade tree and strands the
            // deepest content behind a resource the player can no longer earn.
        ];
        return a[_c(i, 0, Z_N - 1)][_c(r, 0, R_N - 1)];
    }

    // ── Buildings ────────────────────────────────────────────────────────────
    // Ids 0..6 are shipped and must never move. 7/8 are appended deep-tier
    // buildings; old saves simply read level 0 for them.
    const B_N        = 9;
    const B_SHAFT    = 0;  // digging speed
    const B_FORGE    = 1;  // mining power (ore yield)
    const B_ELEVATOR = 2;  // depth travel speed
    const B_CAMP     = 3;  // workers
    const B_LAB      = 4;  // research: global multiplier
    const B_GEMWS    = 5;  // gem workshop: gem yield
    const B_SCANNER  = 6;  // deep scanner: discovery/collectible chance
    const B_RIG      = 7;  // hydraulic rig: +25% depth-pressure resistance / lvl
    const B_BORE     = 8;  // quantum bore: +12 m/h flat before multipliers

    function bName(i) {
        var a = ["Mine Shaft", "Forge", "Elevator", "Miner Camp", "Laboratory", "Gem Workshop", "Deep Scanner",
                 "Hydraulic Rig", "Quantum Bore"];
        return a[_c(i, 0, B_N - 1)];
    }
    function bColor(i) {
        var a = [0xC98A4A, 0xFF7A3A, 0x8CC0FF, 0x7AD07A, 0x4CE0C0, 0x4CE6E0, 0xB46CFF,
                 0xE05A3A, 0x7AF0FF];
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
            "Finds hidden areas & collectibles.",
            "Beats depth pressure (+25%/lvl).",
            "Flat +12 m/h per level."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Depth required before this can be built (surface set = 0).
    function bUnlockDepth(i) {
        var a = [0, 0, 0, 0, 250, 100, 500, 1500, 6000];
        return a[_c(i, 0, B_N - 1)];
    }
    // Story flavour shown on the building info card — two short sentences that
    // place the structure inside the mine and hint at why it matters.
    function bLore(i) {
        var a = [
            "The first hole your grandfather sank. Every metre below starts here.",
            "Coal-fired and never cold. Bad ore goes in, clean metal comes out.",
            "A rattling cage on frayed cable. It turns a long climb into a short drop.",
            "Bunks, stew and lanterns. Rested miners swing harder for longer.",
            "Chalkboards full of rock maths. Someone finally read the geology.",
            "Cutting wheels sing all night. Rough stones leave here as jewels.",
            "It listens to the rock and paints what it hears on a cracked screen.",
            "Pistons thicker than a man. It holds the deep dark open by force.",
            "Nobody at the camp understands it. It simply eats the stone away."
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Exact mechanical effect per level, in plain words.
    function bEffectText(i) {
        var a = [
            "+4 m/h dig speed per level",
            "+15% ore yield per level",
            "+depth travel speed per level",
            "+2 workers per level (+8% output each)",
            "+12% to ALL output per level",
            "+20% gem yield per level",
            "+0.8% find chance per dig, per level",
            "+25% pressure resistance per level",
            "+12 m/h flat dig speed per level"
        ];
        return a[_c(i, 0, B_N - 1)];
    }
    // Upgrade cost for next level -> [stone, iron, gold, gem].
    // Generic in i; the deep tier (7,8) starts far steeper and always costs gems
    // so it stays an end-game sink. The growth loop is bounded and value-capped
    // so a corrupt/huge stored level can never overflow into a negative cost.
    function bCostAt(i, lvl) {
        if (lvl < 1) { lvl = 1; }
        if (lvl > 200) { lvl = 200; }
        var stone = 50 + i * 30;
        var iron  = 8 + i * 8;
        var gold  = (i >= 4) ? (8 + i * 4) : 0;
        var gem   = (i == B_GEMWS || i == B_SCANNER) ? (3 + i) : 0;
        if (i >= B_RIG) {
            stone = stone * 6; iron = iron * 6; gold = gold * 8;
            gem = 12 + (i - B_RIG) * 10;
        }
        for (var k = 1; k < lvl; k++) {
            if (stone > 400000000) { break; }
            stone = stone * 16 / 10; iron = iron * 16 / 10;
            gold = gold * 16 / 10;   gem = gem * 16 / 10;
        }
        return [stone, iron, gold, gem];
    }

    // ── Equipment: Pickaxes ─────────────────────────────────────────────────
    const PICK_N = 9;
    function pickName(t) {
        var a = ["Wood Pickaxe", "Iron Pickaxe", "Diamond Pickaxe", "Crystal Drill", "Quantum Drill",
                 "Plasma Bore", "Singularity Drill", "Void Ripper", "Worldbreaker"];
        return a[_c(t, 0, PICK_N - 1)];
    }
    function pickPowerPct(t) {
        var a = [100, 150, 220, 320, 460, 650, 900, 1250, 1700];
        return a[_c(t, 0, PICK_N - 1)];
    }
    function pickLore(t) {
        var a = [
            "Splintered handle, chipped head. It still opened this whole mine.",
            "Forge-hammered and balanced. Iron bites where wood only bruised.",
            "A gem edge that never dulls. Rock parts like old bread.",
            "Runs hot and hums. The crystal head cuts a tunnel a shift wide.",
            "The bit is somewhere and nowhere. Stone gives up arguing.",
            "A lance of contained star-fire. Walls glow orange behind it.",
            "It borrows a little gravity from the rock and the rock collapses.",
            "It opens a seam in the dark itself. Miners look away when it fires.",
            "The mountain remembers this tool. That is why the mountain moves."
        ];
        return a[_c(t, 0, PICK_N - 1)];
    }
    // Cost to upgrade FROM tier t to t+1 -> [stone, iron, gold, gem].
    function pickCost(t) {
        var a = [
            [300, 20, 0, 0],
            [400, 120, 15, 0],
            [500, 200, 90, 5],
            [800, 300, 300, 40],
            [2400, 1000, 1100, 150],
            [7000, 3000, 3600, 520],
            [21000, 9000, 11000, 1700],
            [64000, 27000, 34000, 5400]
        ];
        if (t < 0 || t >= PICK_N - 1) { return [0, 0, 0, 0]; }
        return a[t];
    }

    // ── Equipment: Carts ─────────────────────────────────────────────────────
    const CART_N = 6;
    function cartName(t) {
        var a = ["Small Cart", "Mining Wagon", "Auto Transport",
                 "Maglev Line", "Gravity Lift", "Wormhole Chute"];
        return a[_c(t, 0, CART_N - 1)];
    }
    function cartMultPct(t) {
        var a = [100, 145, 200, 280, 400, 560];
        return a[_c(t, 0, CART_N - 1)];
    }
    function cartLore(t) {
        var a = [
            "One squeaky wheel and a rope. Half the haul falls out on the bends.",
            "Oak sides, iron rails. Two shifts of ore in a single push.",
            "It rolls back down on its own and waits at the face for you.",
            "Floats a finger above the rail. Nothing is lost to friction now.",
            "The load simply refuses to weigh anything on the way up.",
            "Ore leaves the seam here and lands at the surface. No journey between."
        ];
        return a[_c(t, 0, CART_N - 1)];
    }
    function cartCost(t) {
        var a = [
            [450, 40, 0, 0],
            [700, 150, 120, 10],
            [2600, 900, 850, 110],
            [8200, 3000, 2900, 380],
            [26000, 9500, 9200, 1300]
        ];
        if (t < 0 || t >= CART_N - 1) { return [0, 0, 0, 0]; }
        return a[t];
    }

    // ── Collection (rarity) ────────────────────────────────────────────────────
    const C_N = 20;
    // rarity: 0 common, 1 rare, 2 epic, 3 legendary, 4 mythic
    function cName(i) {
        var a = ["Coal", "Fossil", "Gold Nugget", "Crystal", "Meteorite",
                 "Ancient Tool", "Diamond", "Lost Machine", "Rare Relic",
                 "Golden Skull", "Ancient Core", "Unknown Crystal",
                 "Magma Heart", "Obsidian Idol", "Void Shard", "Hollow Egg",
                 "Titan Bone", "Star Fragment", "Chrono Prism", "World Seed"];
        return a[_c(i, 0, C_N - 1)];
    }
    function cRarity(i) {
        var a = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 4,
                 2, 2, 3, 3, 3, 4, 4, 4];
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
        var a = [1, 1, 2, 4, 6, 10, 15, 25, 25, 60, 60, 150,
                 40, 45, 90, 100, 110, 220, 260, 400];
        return a[_c(i, 0, C_N - 1)];
    }
    function cLegendary(i) { return cRarity(i) >= 3; }
    // Museum text for the collection cards: what the find actually is, told as
    // a line from the mine's own logbook.
    function cLore(i) {
        var a = [
            "Black bread of the shallow seams. Burns hot, pays little, always there.",
            "A creature pressed flat by a hundred million winters of rock.",
            "Bright enough to make a whole shift stop and stare at one hand.",
            "It grew in a hollow with no light, and still came out shining.",
            "It fell before there was a mine here. It was waiting for you.",
            "Some miner cut this handle by fire. His seam is still on the map.",
            "The hardest thing anyone here has ever held. It cuts the cutters.",
            "Gears the size of doors, half swallowed by stone, still faintly warm.",
            "Not made by the camp. Not made by anyone the camp knows about.",
            "Gold poured into bone. Somebody down here was worshipped, or feared.",
            "It ticks. Bring it near the Laboratory and the instruments panic.",
            "It answers questions nobody asked and hums the same note as the Abyss.",
            "A pocket of the world's furnace, cooled just enough to carry.",
            "Carved from frozen lava, faceless, and heavier than it should be.",
            "A piece of the gap between the layers. Light goes in and does not leave.",
            "Warm, patient, and slowly cracking. Whatever is inside is not finished.",
            "One rib of something that walked when the mountains were young.",
            "It still remembers the sky it fell out of and glows when you sleep.",
            "Hold it and yesterday's shift feels like it happened twice.",
            "The bottom of the mine holds a seed. Every world above grew out of one."
        ];
        return a[_c(i, 0, C_N - 1)];
    }
    // Where the find turns up — sets the player a concrete next goal.
    function cOrigin(i) {
        var a = [
            "Surface seams", "Surface seams", "Surface seams",
            "Crystal Cave, 100m", "Meteor pockets", "Ancient Ruins, 250m",
            "Deep digs past 700m", "Lost Vault, 500m", "Rare deep strikes",
            "Legendary strike", "The Abyss Gate, 1500m", "Unknown Signal, 1000m",
            "Magma Vents, 2500m", "Obsidian Halls, 4000m", "Void Resonator, 7000m",
            "Hollow Sea, 11000m", "Titan Ribcage, 18000m", "World Engine, 30000m",
            "Deepest strikes", "The Last Door, 50000m"
        ];
        return a[_c(i, 0, C_N - 1)];
    }
    // Why the player should care: the collection feeds two leaderboards.
    function cValueText(i) {
        return "+" + cWeight(i) + " collection score"
             + (cLegendary(i) ? " · counts as a legendary find" : "");
    }

    // ── Depth discoveries ──────────────────────────────────────────────────────
    // Marks the depth thresholds that reveal a discovery (name + collectible).
    const D_N = 12;
    function dDepth(i) {
        var a = [100, 250, 500, 1000, 1500, 2500, 4000, 7000, 11000, 18000, 30000, 50000];
        return a[_c(i, 0, D_N - 1)];
    }
    function dName(i) {
        var a = ["Crystal Cave", "Ancient Ruins", "Lost Vault", "Unknown Signal", "The Abyss Gate",
                 "Magma Vents", "Obsidian Halls", "Void Resonator", "Hollow Sea",
                 "Titan Ribcage", "World Engine", "The Last Door"];
        return a[_c(i, 0, D_N - 1)];
    }
    function dUnlockText(i) {
        var a = ["Crystal Mining", "Ancient Artifacts", "Deep Scanning", "Mystery Research", "Abyssal Secrets",
                 "Heat Shielding", "Obsidian Cutting", "Void Resonance", "Hollow Mapping",
                 "Titan Salvage", "Engine Tuning", "Final Secrets"];
        return a[_c(i, 0, D_N - 1)];
    }
    // Field notes for the ATLAS cards: what the crew found down there.
    function dLore(i) {
        var a = [
            "A cavern roofed in blue spines. The lamps were barely needed.",
            "Cut steps, a doorway, and dust that nobody in camp had walked in.",
            "Sealed from the inside. Whatever locked it wanted to stay in.",
            "A repeating pulse from below. It got louder the deeper we went.",
            "The floor simply stops. Dropped stones are never heard landing.",
            "Rock runs like syrup here. The rig glows red between shifts.",
            "Halls of black glass that show you a shift that never happened.",
            "The whole seam rings at one note. Tools shiver in your hands.",
            "A dry ocean bed a kilometre under the ocean bed.",
            "We walked the length of one bone for two hours.",
            "It is still turning. Something built this and left it running.",
            "There is a door at the bottom of the world. Now it is open."
        ];
        return a[_c(i, 0, D_N - 1)];
    }
    // What crossing that depth actually gives the player.
    function dEffectText(i) {
        return "Unlocks " + dUnlockText(i) + " · grants " + cName(dColl(i));
    }
    // Collectible granted by this discovery. Every entry must stay < C_N.
    function dColl(i) {
        var a = [3, 5, 7, 11, 10,   // Crystal, Ancient Tool, Lost Machine, Unknown Crystal, Ancient Core
                 12, 13, 14, 15, 16, 17, 19];
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
