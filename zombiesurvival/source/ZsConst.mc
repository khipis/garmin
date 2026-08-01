// ═══════════════════════════════════════════════════════════════════════════
// ZsConst.mc — Tuning tables for Zombie Survival: Last Stand (module `Zs`).
//
// The game is an idle base defence. You never run a character: you spend the
// day earning scrap from real steps, you buy walls and turrets, and once a
// night the horde arrives on its own and the defences fight it without you.
// Being present is worth something — you may fire your own rifle at whatever
// is closest — but the outcome is decided by what you built, not by reflexes.
//
// Everything the simulation, the renderer and the screens need lives here as
// pure data so they cannot drift apart.
//
// Units: world X is fixed point (100 = one screen "depth unit"), so a zombie
// at WX_SPAWN walks down to 0 = the wall. Speeds are world units per tick at
// TICK_MS. Damage is plain HP.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;

module Zs {

    const GAME_ID = "zombiesurvival";

    // Leaderboard boards (Title Case — matches site IDLE_VARIANTS)
    const LB_DAY   = "Day";     // furthest night survived
    const LB_FORT  = "Fort";    // total defence rating
    const LB_KILLS = "Kills";   // lifetime kills
    const LB_WAVES = "Waves";   // lifetime nights held

    // ── Loop timing ─────────────────────────────────────────────────────────
    const TICK_MS   = 55;       // engine + render tick
    const WX_SPAWN  = 10000;    // world X where zombies enter
    const WX_WALL   = 0;        // world X of the wall line
    const LANES     = 3;        // 0 = near / 1 = mid / 2 = far

    // ── The daily clock ─────────────────────────────────────────────────────
    // One wave per calendar day, after dark, whether or not the watch is being
    // looked at. The hour is local: the countdown is the game's main hook and
    // it has to line up with the player's own evening.
    const WAVE_HOUR   = 21;     // 21:00 local
    // A night that would otherwise run for minutes is fast-forwarded once the
    // outcome is no longer in doubt, and hard-stopped here regardless. The cap
    // also bounds the offline resolve, which runs the very same loop headless.
    const SIM_MAX_TICKS = 5400;

    // ── Palette ─────────────────────────────────────────────────────────────
    // Garmin displays quantise every channel to 00/55/AA/FF, so every colour
    // here is picked straight from that 64-entry cube. Anything in between
    // gets rounded on-device and the art drifts hue — greens turn acid, greys
    // turn olive — so do not "improve" these into arbitrary hex values.
    const BG      = 0x000000;
    const CIRCLE  = 0x000000;
    const ACCENT  = 0x55FF55;   // toxic green
    const COL1    = 0x55FF55;
    const COL2    = 0xFF5500;
    const FIRE    = 0xFF5500;
    const FIRE2   = 0xFFAA00;
    const BLOOD   = 0xAA0000;
    const BLOOD2  = 0xFF0000;
    const WOOD    = 0xAA5500;
    const WOOD_D  = 0x550000;
    const STEEL   = 0xAAAAAA;
    const STEEL_D = 0x555555;
    const DANGER  = 0xFF0000;
    const WARN    = 0xFFAA00;
    const INK     = 0x000000;
    const CLOTH   = 0x005555;   // survivor coat
    const SKIN    = 0xFFAA55;

    // ── Zombies ─────────────────────────────────────────────────────────────
    const Z_WALKER   = 0;
    const Z_RUNNER   = 1;
    const Z_BRUTE    = 2;
    const Z_CRAWLER  = 3;
    const Z_SPITTER  = 4;
    const Z_SCREAMER = 5;
    const Z_BOSS     = 6;
    const Z_N        = 7;

    function zName(t) {
        var a = ["WALKER", "RUNNER", "BRUTE", "CRAWLER", "SPITTER", "SCREAMER", "ABOMINATION"];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zHp(t) {
        var a = [34, 22, 150, 16, 44, 60, 520];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zSpeed(t) {                   // world units per tick
        var a = [46, 104, 27, 74, 38, 52, 22];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zDmg(t) {                     // damage per bite on the wall
        var a = [7, 5, 26, 4, 9, 8, 44];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zBite(t) {                    // ticks between bites
        var a = [14, 10, 22, 9, 16, 14, 20];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zArmor(t) {                   // flat damage reduction
        var a = [0, 0, 6, 0, 0, 2, 12];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zScrap(t) {
        var a = [3, 4, 14, 2, 7, 9, 90];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zHeightPct(t) {               // sprite height vs lane base height
        var a = [100, 92, 140, 52, 104, 106, 168];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zColor(t) {
        var a = [0x55AA55, 0xAAFF55, 0x55AA00, 0x55AA55, 0xAAFF00, 0xAAFFAA, 0x55AA00];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zDark(t) {
        var a = [0x005500, 0x55AA00, 0x005500, 0x005500, 0x55AA00, 0x55AA55, 0x005500];
        return a[_c(t, 0, Z_N - 1)];
    }
    // Moon-side rim light. One step brighter than the body so the silhouette
    // separates from the black street even at 20 px tall.
    function zRim(t) {
        var a = [0xAAFFAA, 0xFFFFAA, 0xAAFF55, 0xAAFFAA, 0xFFFF55, 0xFFFFFF, 0xAAFF55];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zCloth(t) {
        var a = [0x555555, 0x550000, 0x555555, 0x550055, 0x005555, 0x550055, 0x550000];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zEye(t) {
        var a = [0xFF0000, 0xFFAA00, 0xFF0000, 0xFF5500, 0xFFFF55, 0xFF00AA, 0xFF0000];
        return a[_c(t, 0, Z_N - 1)];
    }
    function zIsBoss(t) { return t == Z_BOSS; }

    // ── Night modifiers ─────────────────────────────────────────────────────
    const MOD_NONE  = 0;
    const MOD_FOG   = 1;   // turrets acquire late, so less time on target
    const MOD_RAGE  = 2;   // +30% zombie speed
    const MOD_HORDE = 3;   // +50% count, weaker individuals
    const MOD_BLOOD = 4;   // blood moon: +hp, +scrap
    const MOD_N     = 5;

    function modName(m) {
        var a = ["CLEAR NIGHT", "DENSE FOG", "RAGE NIGHT", "HORDE NIGHT", "BLOOD MOON"];
        return a[_c(m, 0, MOD_N - 1)];
    }
    function modDesc(m) {
        var a = ["Nothing unusual. Yet.", "Turrets see them late.",
                 "Everything runs tonight.", "Twice the bodies.",
                 "Tougher dead, richer scrap."];
        return a[_c(m, 0, MOD_N - 1)];
    }
    function modColor(m) {
        var a = [0xAAAAAA, 0xAAAAFF, 0xFF5500, 0xAAFF55, 0xFF0055];
        return a[_c(m, 0, MOD_N - 1)];
    }

    // ── Defences ────────────────────────────────────────────────────────────
    // The whole shop, in one list, because everything you can buy is a level on
    // one of these and the base screen is a single scrolling column.
    //
    // Three families, and the order below is the order they appear:
    //   structure  what the horde has to chew through
    //   turrets    what shoots back while you are asleep
    //   passive    what compounds overnight
    // RIFLE is last and is the odd one out: it does nothing at all unless you
    // are actually watching the wave, which is the point of it.
    const D_WALL    = 0;
    const D_GATE    = 1;
    const D_MG      = 2;
    const D_MORTAR  = 3;
    const D_TESLA   = 4;
    const D_SPIKES  = 5;
    const D_WIRE    = 6;
    const D_REPAIR  = 7;
    const D_PLATING = 8;
    const D_SALVAGE = 9;
    const D_RIFLE   = 10;
    const D_N       = 11;
    const D_LVL_MAX = 15;

    function dName(i) {
        var a = ["WALLS", "GATE", "MG NEST", "MORTAR", "TESLA COIL",
                 "SPIKE PIT", "RAZOR WIRE", "AUTO-REPAIR", "PLATING",
                 "SALVAGE", "YOUR RIFLE"];
        return a[_c(i, 0, D_N - 1)];
    }
    // Kept short on purpose: this line renders low on a round screen, where
    // the readable chord is a good deal narrower than the display width.
    function dDesc(i) {
        var a = ["Thicker walls",
                 "Holds them longer",
                 "Steady auto fire",
                 "Heavy slow shells",
                 "Arcs through crowds",
                 "Hurts all who close",
                 "Slows them down",
                 "Rebuilds by dawn",
                 "Blunts every bite",
                 "+9% scrap earned",
                 "Fires while you watch"];
        return a[_c(i, 0, D_N - 1)];
    }
    function dColor(i) {
        var a = [0xAAAAAA, 0xAA5500, 0xFFAA00, 0xFF5500, 0x55AAFF,
                 0xFF0055, 0xAAAAAA, 0x55FFAA, 0x55AAAA, 0xFFFF00,
                 0x55FF55];
        return a[_c(i, 0, D_N - 1)];
    }
    // Family tag, used by the base screen to group the list.
    const F_STRUCT = 0;
    const F_TURRET = 1;
    const F_PASSIVE= 2;
    function dFamily(i) {
        var a = [F_STRUCT, F_STRUCT, F_TURRET, F_TURRET, F_TURRET,
                 F_TURRET, F_TURRET, F_PASSIVE, F_PASSIVE, F_PASSIVE,
                 F_TURRET];
        return a[_c(i, 0, D_N - 1)];
    }
    function famName(f) {
        var a = ["STRUCTURE", "DEFENCES", "SYSTEMS"];
        return a[_c(f, 0, 2)];
    }
    // Steeply quadratic on purpose. Income is close to flat — a day's walking
    // is a day's walking however far into the game you are — so anything
    // gentler and a committed player runs out of things to buy inside three
    // months and the daily loop loses its point.
    function dCost(i, lvl) {
        var base = [60, 90, 80, 150, 190, 70, 65, 130, 110, 85, 100];
        var b = base[_c(i, 0, D_N - 1)];
        var l = lvl < 0 ? 0 : lvl;
        return b + b * l * 9 / 10 + l * l * 22;
    }

    // ── Derived defence stats ───────────────────────────────────────────────
    // Everything the night simulation needs, as a function of a level. Level 0
    // must always be survivable-but-thin: night 1 has to be winnable with
    // nothing bought, or the first evening is a wall of text about failure.
    function wallHp(lvl)      { return 260 + lvl * 47; }   // per lane segment
    function gateHp(lvl)      { return lvl <= 0 ? 0 : 120 + lvl * 90; }
    // Turret damage per shot and the gap between shots, in ticks.
    function mgDmg(lvl)       { return lvl <= 0 ? 0 : 9 + lvl * 4; }
    function mgRate(lvl)      { var r = 11 - lvl / 3; return r < 4 ? 4 : r; }
    function mortarDmg(lvl)   { return lvl <= 0 ? 0 : 40 + lvl * 26; }
    function mortarRate(lvl)  { var r = 46 - lvl * 2; return r < 24 ? 24 : r; }
    function teslaDmg(lvl)    { return lvl <= 0 ? 0 : 12 + lvl * 9; }
    function teslaRate(lvl)   { var r = 34 - lvl; return r < 18 ? 18 : r; }
    function teslaChain(lvl)  { var n = 1 + lvl / 3; return n > 4 ? 4 : n; }
    // Spikes bite once, as a zombie crosses into the last stretch of street.
    function spikeDmg(lvl)    { return lvl <= 0 ? 0 : 14 + lvl * 11; }
    // Wire scales the speed of anything in the near stretch, as a percentage.
    function wireSlowPct(lvl) { var p = 100 - lvl * 5; return p < 45 ? 45 : p; }
    function repairPct(lvl)   { var p = lvl * 8; return p > 90 ? 90 : p; }
    function platingCut(lvl)  { return lvl; }              // flat HP off each bite
    function salvagePct(lvl)  { return 100 + lvl * 9; }
    function rifleDmg(lvl)    { return 30 + lvl * 16; }
    function rifleRate(lvl)   { var r = 9 - lvl / 3; return r < 3 ? 3 : r; }

    // A single number for the "Fort" board and the base header. Levels are
    // weighted by what they cost, so a mortar reads as worth more than a wire.
    function fortRating(levels) {
        var w = [3, 4, 4, 7, 8, 3, 3, 6, 5, 3, 4];
        var s = 0;
        for (var i = 0; i < D_N; i++) { s += levels[i] * w[i]; }
        return s;
    }

    // ── Wave shape ──────────────────────────────────────────────────────────
    const BOSS_EVERY   = 5;
    // Where the traps sit, in world X. Spikes are the last thing before the
    // wall; wire covers the stretch behind them.
    const WX_SPIKES    = 1500;
    const WX_WIRE      = 3800;

    // Steps → scrap
    const STEPS_PER_SCRAP = 30;
    const ACT_MIN_BONUS   = 4;
    const DAILY_CAP       = 400;

    // ── Salvage: the things you find ────────────────────────────────────────
    // Twelve one-off finds, held as a bitmask, each worth exactly one modest
    // percentage somewhere in the simulation. Keeping every item to a single
    // number is what stops a lucky week from breaking the difficulty curve —
    // the whole set is worth roughly two or three levels of a good turret.
    //
    // Ids are append-only: the mask is persisted and renumbering would hand
    // players somebody else's shelf.
    const IT_CROWBAR   = 0;
    const IT_TOOLBOX   = 1;
    const IT_SANDBAGS  = 2;
    const IT_SCOPE     = 3;
    const IT_WELDER    = 4;
    const IT_AMMOBOX   = 5;
    const IT_GENERATOR = 6;
    const IT_PLATE     = 7;
    const IT_RADIO     = 8;
    const IT_MANUAL    = 9;
    const IT_ARMOURY   = 10;
    const IT_SERUM     = 11;
    const IT_N         = 12;

    function itName(i) {
        var a = ["CROWBAR", "TOOLBOX", "SANDBAGS", "RIFLE SCOPE", "ARC WELDER",
                 "AMMO CRATE", "GENERATOR", "STEEL PLATE", "HAM RADIO",
                 "FIELD MANUAL", "ARMOURY KEY", "THE SERUM"];
        return a[_c(i, 0, IT_N - 1)];
    }
    // Where it came from. This is the only story most of these get, so it does
    // the work of telling you what the world outside the wall looks like.
    function itLore(i) {
        var a = ["Left in a jammed fire door.",
                 "Under the seat of a dead van.",
                 "Flood defences, never used.",
                 "Still boxed. Still zeroed.",
                 "The garage had one good bench.",
                 "A patrol never came back for it.",
                 "Hospital basement, still fuelled.",
                 "Cut from an armoured car.",
                 "Someone was calling for weeks.",
                 "Annotated in two hands.",
                 "The barracks kept one spare.",
                 "One vial. No label. No lab."];
        return a[_c(i, 0, IT_N - 1)];
    }
    function itEffect(i) {
        var a = ["+8% salvage", "+4% repair", "+6% wall HP", "+20% rifle",
                 "+7% repair", "+8% turrets", "+10% turrets", "+2 plating",
                 "+12% salvage", "-7% upgrade cost", "+14% turrets",
                 "+18% wall HP"];
        return a[_c(i, 0, IT_N - 1)];
    }
    const R_COMMON = 0;
    const R_UNCOMMON = 1;
    const R_RARE = 2;
    const R_RELIC = 3;
    function itRarity(i) {
        var a = [0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 3, 3];
        return a[_c(i, 0, IT_N - 1)];
    }
    function rarityName(r) {
        var a = ["COMMON", "UNCOMMON", "RARE", "RELIC"];
        return a[_c(r, 0, 3)];
    }
    function rarityColor(r) {
        var a = [0xAAAAAA, 0x55FF55, 0x55AAFF, 0xFFAA00];
        return a[_c(r, 0, 3)];
    }
    // Which bonus this item feeds, and by how much. Kept as two parallel
    // lookups so the model can total a category without a table per effect.
    const EF_SALVAGE = 0;
    const EF_REPAIR  = 1;
    const EF_WALL    = 2;
    const EF_RIFLE   = 3;
    const EF_TURRET  = 4;
    const EF_PLATING = 5;
    const EF_COST    = 6;
    function itEffectKind(i) {
        var a = [EF_SALVAGE, EF_REPAIR, EF_WALL, EF_RIFLE, EF_REPAIR,
                 EF_TURRET, EF_TURRET, EF_PLATING, EF_SALVAGE, EF_COST,
                 EF_TURRET, EF_WALL];
        return a[_c(i, 0, IT_N - 1)];
    }
    function itEffectAmt(i) {
        var a = [8, 4, 6, 20, 7, 8, 10, 2, 12, 7, 14, 18];
        return a[_c(i, 0, IT_N - 1)];
    }

    // ── Chapters ────────────────────────────────────────────────────────────
    // The night counter is the only clock the story has. Each band renames the
    // world and gives the compound screen one line to say about it.
    const CH_N = 7;
    function chapterAt(night) {
        if (night >= 80) { return 6; }
        if (night >= 55) { return 5; }
        if (night >= 35) { return 4; }
        if (night >= 20) { return 3; }
        if (night >= 10) { return 2; }
        if (night >= 5)  { return 1; }
        return 0;
    }
    function chapterName(c) {
        var a = ["THE FIRST WEEK", "QUIET STREETS", "WINTER CAME EARLY",
                 "THEY LEARN", "NO MORE BROADCASTS", "THE LONG DARK",
                 "LAST STAND"];
        return a[_c(c, 0, CH_N - 1)];
    }
    function chapterLine(c) {
        var a = ["The radio still played music.",
                 "Nobody has driven past in days.",
                 "Frost on the wire by four.",
                 "They come at the gate now. Only the gate.",
                 "The emergency band went to static.",
                 "Six hours of light. If that.",
                 "Whatever is left of the city is here."];
        return a[_c(c, 0, CH_N - 1)];
    }

    // ── Daytime events ──────────────────────────────────────────────────────
    // Rolled when the app has been shut for a while. Two of them ask a
    // question; the rest simply happened and are reported at dawn.
    const EV_NONE     = -1;
    const EV_STRANGER = 0;   // choice
    const EV_CACHE    = 1;
    const EV_RATS     = 2;
    const EV_SIGNAL   = 3;   // choice
    const EV_SCAV     = 4;
    const EV_N        = 5;

    function evTitle(i) {
        var a = ["SOMEONE AT THE GATE", "A CACHE UNDER THE FLOOR",
                 "RATS IN THE STORES", "A VOICE ON THE BAND",
                 "THE CREW WENT OUT"];
        return a[_c(i, 0, EV_N - 1)];
    }
    function evBody(i) {
        var a = ["A survivor. Thin. Armed. Says he can work.",
                 "The old owner hid more than tinned food.",
                 "They got into the sacks before anyone woke.",
                 "A woman, three streets over, reading co-ordinates.",
                 "They went out past the wire while it was light."];
        return a[_c(i, 0, EV_N - 1)];
    }
    function evChoiceA(i) {
        var a = ["LET HIM IN", "", "", "GO TO HER", ""];
        return a[_c(i, 0, EV_N - 1)];
    }
    function evChoiceB(i) {
        var a = ["TURN HIM AWAY", "", "", "STAY BEHIND THE WALL", ""];
        return a[_c(i, 0, EV_N - 1)];
    }
    function evHasChoice(i) { return i == EV_STRANGER || i == EV_SIGNAL; }

    function _c(i, lo, hi) {
        if (i < lo) { return lo; }
        if (i > hi) { return hi; }
        return i;
    }
}
