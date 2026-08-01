// ═══════════════════════════════════════════════════════════════════════════
// DmConst.mc — Constants, RPG tables and the seeded RNG.
//
// Everything the other systems read: tile codes, monster/item/spell tables,
// the XP curve, the per-zone palette and the deterministic LCG that makes a
// dungeon reproducible from (seed, floor) — which is what lets the save system
// store a seed instead of a whole map, and what makes the daily dungeon
// identical for everyone.
//
// Tables are if/else chains rather than array literals on purpose: Monkey C
// cannot index an inline array, and chains cost no RAM at all.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

const DM_LB_ID = "dungeonmaster";

// Dungeon grid
const DM_W = 16;
const DM_H = 16;
const DM_MAX_FLOOR = 15;

// Tile codes
const T_WALL      = 0;
const T_FLOOR     = 1;
const T_DOOR      = 2;   // closed — primary action opens
const T_DOOR_OPEN = 3;
const T_STAIRS    = 4;
const T_SECRET    = 5;   // renders as wall, searching reveals
const T_LOCKED    = 6;   // wants a key, can always be forced for HP
const T_PILLAR    = 7;   // decorative solid block inside pillared halls

// Entity pool caps (per floor). Pre-sized once; the generator never exceeds.
const DM_MAX_MON  = 10;
const DM_MAX_LOOT = 8;
const DM_MAX_TRAP = 6;
const DM_MAX_SEC  = 3;
const DM_MAX_FEAT = 3;
const DM_MAX_ROOM = 6;

// Facing (grid based, cardinal only)
const DIR_N = 0;
const DIR_E = 1;
const DIR_S = 2;
const DIR_W = 3;

// Game phases
enum {
    DM_EXPLORE,
    DM_COMBAT,
    DM_LOOT,
    DM_LEVELUP,
    DM_PACK,
    DM_DEAD,
    DM_DESCEND,
    DM_FEATURE,
    DM_SHOP
}

// Combat actions
enum {
    ACT_ATTACK,
    ACT_POWER,
    ACT_SPELL,
    ACT_GUARD,
    ACT_ITEM,
    ACT_COUNT
}

// Combat sub-menu state (spell / item pickers reachable with UP-DOWN-SELECT)
const CS_ACTIONS = 0;
const CS_SPELLS  = 1;
const CS_ITEMS   = 2;

// ── Monsters ───────────────────────────────────────────────────────────────
const MON_RAT      = 0;
const MON_GOBLIN   = 1;
const MON_SKELETON = 2;
const MON_SPIDER   = 3;
const MON_CULTIST  = 4;
const MON_KNIGHT   = 5;
const MON_WRAITH   = 6;
const MON_OGRE     = 7;
const MON_DEMON    = 8;
const MON_KING     = 9;    // boss, floor 5
const MON_GUARDIAN = 10;   // boss, floor 10
const MON_BEAST    = 11;   // boss, floor 15
const MON_COUNT    = 12;

// Elite modifiers — a normal monster wearing a nasty hat.
const EL_NONE    = 0;
const EL_SAVAGE  = 1;   // hits harder
const EL_ARMORED = 2;   // soaks more
const EL_VENOM   = 3;   // always poisons
const EL_ARCANE  = 4;   // burns mana, bites through armour
const EL_COUNT   = 5;

// ── Loot kinds ─────────────────────────────────────────────────────────────
const LOOT_GOLD   = 0;
const LOOT_POTION = 1;
const LOOT_ETHER  = 2;
const LOOT_SCROLL = 3;
const LOOT_KEY    = 4;
const LOOT_WEAPON = 5;
const LOOT_ARMOR  = 6;
const LOOT_RING   = 7;
const LOOT_AMULET = 8;
const LOOT_BOMB   = 9;

// Rarity drives the loot card presentation (rare drops must feel rare).
const RAR_COMMON = 0;
const RAR_RARE   = 1;
const RAR_EPIC   = 2;

// ── Traps ──────────────────────────────────────────────────────────────────
const TRAP_SPIKE = 0;
const TRAP_DART  = 1;   // poisons
const TRAP_PIT   = 2;   // heavy, but drops you past the room
const TRAP_RUNE  = 3;   // drains mana and burns

// ── Dungeon features ───────────────────────────────────────────────────────
const FEAT_SHRINE   = 0;
const FEAT_FOUNTAIN = 1;
const FEAT_MERCHANT = 2;

// ── Secret types ───────────────────────────────────────────────────────────
const SEC_STASH   = 0;   // hidden item
const SEC_VAULT   = 1;   // pile of gold
const SEC_PASSAGE = 2;   // shortcut only — but XP and a shorter route

// ── Room archetypes ────────────────────────────────────────────────────────
const RM_PLAIN    = 0;
const RM_CRYPT    = 1;
const RM_LIBRARY  = 2;
const RM_TREASURY = 3;
const RM_ARENA    = 4;
const RM_PILLARED = 5;

// ── Spells ─────────────────────────────────────────────────────────────────
const SP_FIRE  = 0;
const SP_FROST = 1;
const SP_HEAL  = 2;
const SP_WARD  = 3;
const SP_COUNT = 4;

// ── Character classes ──────────────────────────────────────────────────────
const CLS_WARRIOR = 0;
const CLS_ROGUE   = 1;
const CLS_MAGE    = 2;
const CLS_PALADIN = 3;

// Level-up choices
const UP_HP    = 0;
const UP_STR   = 1;
const UP_DEF   = 2;
const UP_MAGIC = 3;
const UP_LUCK  = 4;
const UP_COUNT = 5;

module DmConst {

    // ── Monster identity ────────────────────────────────────────────────────
    function monName(t as Lang.Number) as Lang.String {
        if (t == MON_RAT)      { return "RAT SWARM"; }
        if (t == MON_GOBLIN)   { return "GOBLIN"; }
        if (t == MON_SKELETON) { return "SKELETON"; }
        if (t == MON_SPIDER)   { return "SPIDER"; }
        if (t == MON_CULTIST)  { return "CULTIST"; }
        if (t == MON_KNIGHT)   { return "DEAD KNIGHT"; }
        if (t == MON_WRAITH)   { return "WRAITH"; }
        if (t == MON_OGRE)     { return "OGRE"; }
        if (t == MON_DEMON)    { return "DEMON"; }
        if (t == MON_KING)     { return "SKELETON KING"; }
        if (t == MON_GUARDIAN) { return "ANCIENT GUARDIAN"; }
        if (t == MON_BEAST)    { return "DUNGEON BEAST"; }
        return "THING";
    }

    function isBossType(t as Lang.Number) as Lang.Boolean {
        return t >= MON_KING;
    }

    // The guardian that owns a given boss floor.
    function bossFor(floor as Lang.Number) as Lang.Number {
        if (floor >= 15) { return MON_BEAST; }
        if (floor >= 10) { return MON_GUARDIAN; }
        return MON_KING;
    }

    function monColor(t as Lang.Number) as Lang.Number {
        if (t == MON_RAT)      { return 0x9A8A6E; }
        if (t == MON_GOBLIN)   { return 0x6FB04A; }
        if (t == MON_SKELETON) { return 0xDCD8C4; }
        if (t == MON_SPIDER)   { return 0x9C4CB4; }
        if (t == MON_CULTIST)  { return 0xB44A66; }
        if (t == MON_KNIGHT)   { return 0x8E9EB2; }
        if (t == MON_WRAITH)   { return 0x7ACCE0; }
        if (t == MON_OGRE)     { return 0xB07A44; }
        if (t == MON_DEMON)    { return 0xE84028; }
        if (t == MON_KING)     { return 0xF0E8CC; }
        if (t == MON_GUARDIAN) { return 0x8CB0D0; }
        if (t == MON_BEAST)    { return 0xD03A5A; }
        return 0xFFFFFF;
    }

    // ── Monster stats (floor + difficulty scaled) ───────────────────────────
    function monHp(t as Lang.Number, floor as Lang.Number, diff as Lang.Number) as Lang.Number {
        var base = 12;
        if (t == MON_RAT)      { base = 7; }
        if (t == MON_GOBLIN)   { base = 10; }
        if (t == MON_SKELETON) { base = 16; }
        if (t == MON_SPIDER)   { base = 12; }
        if (t == MON_CULTIST)  { base = 15; }
        if (t == MON_KNIGHT)   { base = 24; }
        if (t == MON_WRAITH)   { base = 19; }
        if (t == MON_OGRE)     { base = 34; }
        if (t == MON_DEMON)    { base = 30; }
        if (t == MON_KING)     { base = 70; }
        if (t == MON_GUARDIAN) { base = 100; }
        if (t == MON_BEAST)    { base = 140; }
        return base + floor * (3 + diff);
    }

    function monAtk(t as Lang.Number, floor as Lang.Number, diff as Lang.Number) as Lang.Number {
        var base = 4;
        if (t == MON_RAT)      { base = 3; }
        if (t == MON_GOBLIN)   { base = 4; }
        if (t == MON_SKELETON) { base = 6; }
        if (t == MON_SPIDER)   { base = 5; }
        if (t == MON_CULTIST)  { base = 5; }
        if (t == MON_KNIGHT)   { base = 7; }
        if (t == MON_WRAITH)   { base = 8; }
        if (t == MON_OGRE)     { base = 10; }
        if (t == MON_DEMON)    { base = 11; }
        if (t == MON_KING)     { base = 12; }
        if (t == MON_GUARDIAN) { base = 14; }
        if (t == MON_BEAST)    { base = 17; }
        return base + (floor * 2) / 3 + diff;
    }

    function monDef(t as Lang.Number, floor as Lang.Number) as Lang.Number {
        var base = 1;
        if (t == MON_RAT)      { base = 0; }
        if (t == MON_SKELETON) { base = 2; }
        if (t == MON_CULTIST)  { base = 2; }
        if (t == MON_KNIGHT)   { base = 6; }
        if (t == MON_WRAITH)   { base = 3; }
        if (t == MON_OGRE)     { base = 4; }
        if (t == MON_DEMON)    { base = 5; }
        if (t == MON_KING)     { base = 6; }
        if (t == MON_GUARDIAN) { base = 9; }
        if (t == MON_BEAST)    { base = 8; }
        return base + floor / 3;
    }

    function monXp(t as Lang.Number, floor as Lang.Number) as Lang.Number {
        var base = 6;
        if (t == MON_RAT)      { base = 4; }
        if (t == MON_SKELETON) { base = 9; }
        if (t == MON_SPIDER)   { base = 8; }
        if (t == MON_CULTIST)  { base = 11; }
        if (t == MON_KNIGHT)   { base = 15; }
        if (t == MON_WRAITH)   { base = 18; }
        if (t == MON_OGRE)     { base = 22; }
        if (t == MON_DEMON)    { base = 26; }
        if (t == MON_KING)     { base = 90; }
        if (t == MON_GUARDIAN) { base = 140; }
        if (t == MON_BEAST)    { base = 200; }
        return base + floor * 2;
    }

    function monGold(t as Lang.Number, floor as Lang.Number) as Lang.Number {
        var base = 5;
        if (t == MON_RAT)      { base = 2; }
        if (t == MON_CULTIST)  { base = 12; }
        if (t == MON_KNIGHT)   { base = 18; }
        if (t == MON_WRAITH)   { base = 14; }
        if (t == MON_OGRE)     { base = 22; }
        if (t == MON_DEMON)    { base = 30; }
        if (t == MON_KING)     { base = 120; }
        if (t == MON_GUARDIAN) { base = 180; }
        if (t == MON_BEAST)    { base = 260; }
        return base + floor * 3;
    }

    // One-line tell shown under the health bar so a new monster is never a
    // total mystery — knowing the pattern is what makes the fight tactical.
    function monTell(t as Lang.Number) as Lang.String {
        if (t == MON_RAT)      { return "swarms - many small bites"; }
        if (t == MON_GOBLIN)   { return "erratic - may swing twice"; }
        if (t == MON_SKELETON) { return "winds up, then hits hard"; }
        if (t == MON_SPIDER)   { return "venomous fangs"; }
        if (t == MON_CULTIST)  { return "drains life and mana"; }
        if (t == MON_KNIGHT)   { return "heavy plate - blunt it down"; }
        if (t == MON_WRAITH)   { return "half-real - blows pass through"; }
        if (t == MON_OGRE)     { return "slow slam - can stun"; }
        if (t == MON_DEMON)    { return "hellfire ignores armour"; }
        if (t == MON_KING)     { return "raises bone armour"; }
        if (t == MON_GUARDIAN) { return "stone form, then a quake"; }
        if (t == MON_BEAST)    { return "enrages when wounded"; }
        return "unknown";
    }

    // ── Elites ──────────────────────────────────────────────────────────────
    function eliteName(e as Lang.Number) as Lang.String {
        if (e == EL_SAVAGE)  { return "SAVAGE "; }
        if (e == EL_ARMORED) { return "IRONHIDE "; }
        if (e == EL_VENOM)   { return "VENOMOUS "; }
        if (e == EL_ARCANE)  { return "ARCANE "; }
        return "";
    }

    function eliteColor(e as Lang.Number) as Lang.Number {
        if (e == EL_SAVAGE)  { return 0xFF6633; }
        if (e == EL_ARMORED) { return 0xBBCCDD; }
        if (e == EL_VENOM)   { return 0x66DD44; }
        if (e == EL_ARCANE)  { return 0xAA77FF; }
        return 0x000000;
    }

    // ── Equipment ───────────────────────────────────────────────────────────
    // Six tiers each so an upgrade always reads as a real jump on the sheet.
    function weaponName(tier as Lang.Number) as Lang.String {
        if (tier <= 0) { return "RUSTED BLADE"; }
        if (tier == 1) { return "IRON SWORD"; }
        if (tier == 2) { return "STEEL FALCHION"; }
        if (tier == 3) { return "CRYSTAL BLADE"; }
        if (tier == 4) { return "RUNE AXE"; }
        return "DEMON EDGE";
    }

    function weaponDmg(tier as Lang.Number) as Lang.Number {
        if (tier <= 0) { return 3; }
        if (tier == 1) { return 6; }
        if (tier == 2) { return 10; }
        if (tier == 3) { return 15; }
        if (tier == 4) { return 21; }
        return 28;
    }

    function armorName(tier as Lang.Number) as Lang.String {
        if (tier <= 0) { return "RAGS"; }
        if (tier == 1) { return "PADDED COAT"; }
        if (tier == 2) { return "LEATHER MAIL"; }
        if (tier == 3) { return "CHAIN HAUBERK"; }
        if (tier == 4) { return "KNIGHT PLATE"; }
        return "GUARDIAN PLATE";
    }

    function armorDef(tier as Lang.Number) as Lang.Number {
        if (tier <= 0) { return 0; }
        if (tier == 1) { return 2; }
        if (tier == 2) { return 4; }
        if (tier == 3) { return 7; }
        if (tier == 4) { return 10; }
        return 14;
    }

    function ringName(r as Lang.Number) as Lang.String {
        if (r == 1) { return "RING OF POWER"; }
        if (r == 2) { return "RING OF WARDING"; }
        if (r == 3) { return "RING OF THE WELL"; }
        if (r == 4) { return "RING OF FORTUNE"; }
        return "NO RING";
    }

    function ringEffect(r as Lang.Number) as Lang.String {
        if (r == 1) { return "+4 STR"; }
        if (r == 2) { return "+3 DEF"; }
        if (r == 3) { return "+12 MANA"; }
        if (r == 4) { return "+4 LUCK"; }
        return "-";
    }

    function amuletName(a as Lang.Number) as Lang.String {
        if (a == 1) { return "AMULET OF LIFE"; }
        if (a == 2) { return "AMULET OF FOCUS"; }
        if (a == 3) { return "AMULET OF SHADOW"; }
        return "NO AMULET";
    }

    function amuletEffect(a as Lang.Number) as Lang.String {
        if (a == 1) { return "+25 MAX HP"; }
        if (a == 2) { return "spells cost 2 less"; }
        if (a == 3) { return "+3 MAG, crits bleed"; }
        return "-";
    }

    // ── Loot presentation ───────────────────────────────────────────────────
    function lootName(kind as Lang.Number) as Lang.String {
        if (kind == LOOT_GOLD)   { return "GOLD"; }
        if (kind == LOOT_POTION) { return "HEALTH POTION"; }
        if (kind == LOOT_ETHER)  { return "ETHER VIAL"; }
        if (kind == LOOT_SCROLL) { return "SCROLL OF SIGHT"; }
        if (kind == LOOT_KEY)    { return "IRON KEY"; }
        if (kind == LOOT_WEAPON) { return "WEAPON"; }
        if (kind == LOOT_ARMOR)  { return "ARMOR"; }
        if (kind == LOOT_RING)   { return "RING"; }
        if (kind == LOOT_AMULET) { return "AMULET"; }
        if (kind == LOOT_BOMB)   { return "FIRE BOMB"; }
        return "?";
    }

    function lootColor(kind as Lang.Number) as Lang.Number {
        if (kind == LOOT_GOLD)   { return 0xFFCC44; }
        if (kind == LOOT_POTION) { return 0xEE4466; }
        if (kind == LOOT_ETHER)  { return 0x5588EE; }
        if (kind == LOOT_SCROLL) { return 0xCCBB88; }
        if (kind == LOOT_KEY)    { return 0xDDBB66; }
        if (kind == LOOT_WEAPON) { return 0xCCDDEE; }
        if (kind == LOOT_ARMOR)  { return 0x99AABB; }
        if (kind == LOOT_RING)   { return 0xFFAA33; }
        if (kind == LOOT_AMULET) { return 0xCC66FF; }
        if (kind == LOOT_BOMB)   { return 0xFF7733; }
        return 0xFFFFFF;
    }

    // Rings and amulets are always a moment; gear scales with its tier.
    function lootRarity(kind as Lang.Number, val as Lang.Number) as Lang.Number {
        if (kind == LOOT_RING || kind == LOOT_AMULET) { return RAR_EPIC; }
        if (kind == LOOT_WEAPON || kind == LOOT_ARMOR) {
            if (val >= 4) { return RAR_EPIC; }
            return RAR_RARE;
        }
        return RAR_COMMON;
    }

    function rarityName(r as Lang.Number) as Lang.String {
        if (r == RAR_EPIC) { return "LEGENDARY FIND"; }
        if (r == RAR_RARE) { return "RARE FIND"; }
        return "YOU FOUND";
    }

    function rarityColor(r as Lang.Number) as Lang.Number {
        if (r == RAR_EPIC) { return 0xCC66FF; }
        if (r == RAR_RARE) { return 0x55CCFF; }
        return 0xFFCC44;
    }

    // ── Traps ───────────────────────────────────────────────────────────────
    function trapName(k as Lang.Number) as Lang.String {
        if (k == TRAP_DART) { return "DART TRAP"; }
        if (k == TRAP_PIT)  { return "PIT"; }
        if (k == TRAP_RUNE) { return "GLYPH"; }
        return "SPIKES";
    }

    // ── Features ────────────────────────────────────────────────────────────
    function featName(k as Lang.Number) as Lang.String {
        if (k == FEAT_FOUNTAIN) { return "FOUNTAIN"; }
        if (k == FEAT_MERCHANT) { return "WANDERING TRADER"; }
        return "OLD SHRINE";
    }

    // ── Spells ──────────────────────────────────────────────────────────────
    function spellName(s as Lang.Number) as Lang.String {
        if (s == SP_FIRE)  { return "FIREBALL"; }
        if (s == SP_FROST) { return "FROST NOVA"; }
        if (s == SP_HEAL)  { return "MEND"; }
        return "WARD";
    }

    function spellBaseCost(s as Lang.Number) as Lang.Number {
        if (s == SP_FIRE)  { return 7; }
        if (s == SP_FROST) { return 5; }
        if (s == SP_HEAL)  { return 6; }
        return 5;
    }

    function spellColor(s as Lang.Number) as Lang.Number {
        if (s == SP_FIRE)  { return 0xFF7722; }
        if (s == SP_FROST) { return 0x66CCFF; }
        if (s == SP_HEAL)  { return 0x66EE99; }
        return 0xFFDD55;
    }

    function spellHint(s as Lang.Number) as Lang.String {
        if (s == SP_FIRE)  { return "burns through armour"; }
        if (s == SP_FROST) { return "freezes the next turn"; }
        if (s == SP_HEAL)  { return "restores health"; }
        return "absorbs the next blows";
    }

    // ── Progression ─────────────────────────────────────────────────────────
    function xpForLevel(level as Lang.Number) as Lang.Number {
        return 24 + (level - 1) * 22;
    }

    function className(c as Lang.Number) as Lang.String {
        if (c == CLS_ROGUE)   { return "ROGUE"; }
        if (c == CLS_MAGE)    { return "MAGE"; }
        if (c == CLS_PALADIN) { return "PALADIN"; }
        return "WARRIOR";
    }

    // ── Zones: the dungeon changes character as you go down ─────────────────
    function zoneOf(floor as Lang.Number) as Lang.Number {
        if (floor <= 3)  { return 0; }
        if (floor <= 6)  { return 1; }
        if (floor <= 9)  { return 2; }
        if (floor <= 12) { return 3; }
        return 4;
    }

    function zoneName(floor as Lang.Number) as Lang.String {
        var z = zoneOf(floor);
        if (z == 0) { return "THE OLD KEEP"; }
        if (z == 1) { return "THE CATACOMBS"; }
        if (z == 2) { return "THE FLOODED HALLS"; }
        if (z == 3) { return "OBSIDIAN DEPTHS"; }
        return "THE INFERNAL VAULT";
    }

    // ── Zone light ramps ───────────────────────────────────────────────────
    //
    // Masonry does not shade arithmetically: each zone carries a hand-picked
    // six-step ramp from swallowed-by-the-dark up to torch-lit, and the
    // renderer picks a rung by light level. Stepping a whole ramp keeps the
    // hue locked, so a receding wall reads as "same stone, further away"
    // instead of drifting through tints as its channels fade unevenly.
    //
    // The top rung is a mid-tone, never near-white: a dungeon lit by one
    // torch should never have a bright surface in it, and the flame, the
    // sprites and the HUD need to stay the brightest things on screen.
    //
    // Walls sample the ramp directly, floors one rung down, ceilings two, and
    // mortar one — so surfaces stay separated no matter how bright the torch.
    function zoneRamp(floor as Lang.Number, i as Lang.Number) as Lang.Number {
        if (i < 0) { i = 0; }
        if (i > 5) { i = 5; }
        var z = zoneOf(floor);
        if (z == 0) {                       // the old keep: warm sandstone
            if (i == 0) { return 0x0A0806; }
            if (i == 1) { return 0x1A140E; }
            if (i == 2) { return 0x2E241A; }
            if (i == 3) { return 0x483828; }
            if (i == 4) { return 0x63503A; }
            return 0x8A7052;
        }
        if (z == 1) {                       // catacombs: mossed grey-green
            if (i == 0) { return 0x080A08; }
            if (i == 1) { return 0x141A16; }
            if (i == 2) { return 0x223028; }
            if (i == 3) { return 0x36463A; }
            if (i == 4) { return 0x4E624F; }
            return 0x6E8670;
        }
        if (z == 2) {                       // flooded halls: cold and wet
            if (i == 0) { return 0x06080A; }
            if (i == 1) { return 0x101820; }
            if (i == 2) { return 0x1C2A36; }
            if (i == 3) { return 0x2C4050; }
            if (i == 4) { return 0x3E5A6E; }
            return 0x5C7E92;
        }
        if (z == 3) {                       // obsidian depths: arcane violet
            if (i == 0) { return 0x070608; }
            if (i == 1) { return 0x141018; }
            if (i == 2) { return 0x241C30; }
            if (i == 3) { return 0x382C48; }
            if (i == 4) { return 0x4E3E62; }
            return 0x6E5A86;
        }
        if (i == 0) { return 0x0A0604; }    // infernal vault: ember and ash
        if (i == 1) { return 0x1E0E08; }
        if (i == 2) { return 0x341410; }
        if (i == 3) { return 0x4E1E14; }
        if (i == 4) { return 0x6E2C18; }
        return 0x94441F;
    }

    // Torch colour warms up as the dungeon turns hellish. Palette-exact too,
    // so the flame does not shimmer between hues on a MIP screen.
    function torchColor(floor as Lang.Number) as Lang.Number {
        var z = zoneOf(floor);
        if (z == 2) { return 0x9AE8FF; }   // cold blue lanterns in the flooded halls
        if (z == 3) { return 0xC88AFF; }   // arcane braziers
        if (z == 4) { return 0xFF7A2A; }
        return 0xFFC24A;
    }

    // ── Options (persisted by the shared OPTIONS screen) ────────────────────
    function optInt(key as Lang.String, def as Lang.Number, hi as Lang.Number) as Lang.Number {
        var v = def;
        try {
            var s = Application.Storage.getValue(key);
            if (s instanceof Lang.Number && s >= 0 && s <= hi) { v = s; }
        } catch (e) {}
        return v;
    }

    function difficulty() as Lang.Number  { return optInt("dm_diff", 1, 2); }
    function heroClass() as Lang.Number   { return optInt("dm_class", 0, 3); }
    function isDaily() as Lang.Boolean    { return optInt("dm_mode", 0, 1) == 1; }
    function hapticOn() as Lang.Boolean   { return optInt("dm_haptic", 0, 1) == 0; }
    function shakeOn() as Lang.Boolean    { return optInt("dm_shake", 0, 1) == 0; }

    function lbVariant() as Lang.String {
        if (isDaily()) { return "daily"; }
        var d = difficulty();
        if (d == 0) { return "easy"; }
        if (d == 2) { return "hard"; }
        return "normal";
    }

    // Day index — the shared daily dungeon seed. Everyone playing on the same
    // calendar day generates the identical dungeon.
    function dayIndex() as Lang.Number {
        try {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            return info.year * 1000 + info.month * 40 + info.day;
        } catch (e) {}
        return 20260101;
    }
}

// ── Seeded RNG (LCG) ───────────────────────────────────────────────────────
// Deterministic per (seed, floor) so a dungeon can be rebuilt from a saved
// seed instead of persisting the whole map.
class DmRng {
    hidden var _s;

    function initialize(seed as Lang.Number) {
        _s = seed;
        if (_s < 0) { _s = -_s; }
        _s = _s % 2147483647;
        if (_s == 0) { _s = 12345; }
    }

    // Park-Miller style step, kept inside 31-bit range.
    function next() as Lang.Number {
        _s = (_s * 48271) % 2147483647;
        if (_s < 0) { _s = -_s; }
        return _s;
    }

    // 0 .. n-1
    function range(n as Lang.Number) as Lang.Number {
        if (n <= 1) { return 0; }
        return next() % n;
    }

    // lo .. hi inclusive
    function between(lo as Lang.Number, hi as Lang.Number) as Lang.Number {
        if (hi <= lo) { return lo; }
        return lo + range(hi - lo + 1);
    }
}
