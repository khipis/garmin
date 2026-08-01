// ═══════════════════════════════════════════════════════════════════════════
// TdConst.mc — Enums, pool sizes and every balance table in one place.
//
// All balance lives in TdUtil as plain if/else lookups rather than tables of
// array literals: Monkey C cannot index an inline literal, and keeping the
// numbers next to each other makes retuning a single-file job. Ranges are
// expressed in PERCENT OF THE PLAYFIELD SIDE, never pixels, so a 208px fr235
// and a 454px fenix play exactly the same game.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;

// Game phases
enum {
    TD_BUILD,
    TD_WAVE,
    TD_SUMMARY,
    TD_OVER
}

// UI modes — one shallow state machine so a button-only watch can reach
// every action with UP / DOWN / SELECT / MENU alone.
enum {
    TDUI_MAP,      // cursor walks the build pads (+ START slot between waves)
    TDUI_BUY,      // tower shop for the selected empty pad
    TDUI_TOWER,    // upgrade / targeting / sell for the selected tower
    TDUI_ABILITY   // airstrike / deep freeze picker
}

// Tower types
enum {
    TW_GUN    = 0,
    TW_CANNON = 1,
    TW_ARCHER = 2,
    TW_FROST  = 3,
    TW_TESLA  = 4,
    TW_FLAME  = 5,
    TW_SNIPER = 6,
    TW_COUNT  = 7
}

// Enemy types
enum {
    EN_GRUNT  = 0,
    EN_RUNNER = 1,
    EN_TANK   = 2,
    EN_FLYER  = 3,
    EN_SHIELD = 4,
    EN_HEALER = 5,
    EN_BOSS   = 6,
    EN_COUNT  = 7
}

// Wave modifiers, announced on the build screen before the wave starts.
enum {
    TDW_NONE    = 0,
    TDW_SWARM   = 1,
    TDW_ARMORED = 2,
    TDW_SPEED   = 3,
    TDW_FLYING  = 4,
    TDW_BOSS    = 5
}

// Per-tower targeting priority
enum {
    TDT_FIRST  = 0,
    TDT_STRONG = 1,
    TDT_CLOSE  = 2,
    TDT_COUNT  = 3
}

// Player abilities
enum {
    TDA_STRIKE = 0,
    TDA_FREEZE = 1,
    TDA_COUNT  = 2
}

// FX kinds (one pooled particle array serves all of them)
enum {
    TDFX_TEXT   = 0,   // floating damage / reward number
    TDFX_SPARK  = 1,   // small hit spark that drifts
    TDFX_RING   = 2,   // expanding shockwave ring
    TDFX_SMOKE  = 3,   // rising smoke puff
    TDFX_COIN   = 4,   // coin popping out of a kill
    TDFX_BOLT   = 5,   // jagged lightning between two points
    TDFX_TRACER = 6,   // instant sniper tracer line
    TDFX_FLAME  = 7,   // flamethrower tongue
    TDFX_MUZZLE = 8,   // muzzle flash at a tower
    TDFX_BOOM   = 9    // cannon explosion (ring + core)
}

const TD_LB_ID       = "towerdefense";
const TD_MAX_WAVES   = 30;
const TD_TICK_MS     = 70;

const TD_MAX_TOWERS  = 14;
const TD_MAX_ENEMIES = 40;
const TD_MAX_SHOTS   = 24;
const TD_MAX_FX      = 24;
const TD_MAX_PADS    = 14;
const TD_MAX_PATH    = 20;
const TD_MAX_DECO    = 44;   // cached grass tufts / pebbles
const TD_MAX_PROP    = 12;   // cached trees and boulders
const TD_MAX_STONE   = 96;   // cached cobbles along the path
const TD_STRIKE_HITS = 5;    // enemies hit by one airstrike

const TD_BASE_HP_EASY   = 25;
const TD_BASE_HP_NORMAL = 18;
const TD_BASE_HP_HARD   = 12;

// Palette. No alpha blending exists on Dc, so every "transparent" tint is a
// pre-darkened constant picked against the TD_C_BG background.
const TD_C_BG      = 0x060A12;
const TD_C_VIGN    = 0x0A1220;
const TD_C_GRASS   = 0x1E4028;
const TD_C_GRASS2  = 0x265030;
const TD_C_GRASS3  = 0x17321F;
const TD_C_DIRT    = 0x6A5436;
const TD_C_DIRT_D  = 0x3E301E;
const TD_C_STONE   = 0x8A8272;
const TD_C_STONE_D = 0x5A5448;
const TD_C_TEXT    = 0xE8EEF4;
const TD_C_MUTED   = 0x7C93A8;
const TD_C_GOLD    = 0xFFD24A;
const TD_C_HP      = 0x4CD07A;
const TD_C_DANGER  = 0xFF4444;

module TdUtil {

    // ── Storage / options ────────────────────────────────────────────────────

    function storageInt(key as Lang.String, def as Lang.Number) as Lang.Number {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number) { return v; }
        } catch (e) {}
        return def;
    }

    function isDaily() as Lang.Boolean {
        return storageInt("td_map", 0) == 4;
    }

    function mapIndex() as Lang.Number {
        var m = storageInt("td_map", 0);
        if (m == 4) { return dailySeed() % 4; }   // daily rotates the layout
        if (m < 0) { m = 0; }
        if (m > 3) { m = 3; }
        return m;
    }

    function difficulty() as Lang.Number {
        if (isDaily()) { return 1; }              // daily is always NORMAL for fairness
        var d = storageInt("td_diff", 1);
        if (d < 0) { d = 0; }
        if (d > 2) { d = 2; }
        return d;
    }

    // 10 = normal, 13 = fast. Applied to enemy travel and projectile speed so
    // "fast" shortens a run without re-tuning every cooldown.
    function pace() as Lang.Number {
        if (storageInt("td_pace", 0) == 1) { return 13; }
        return 10;
    }

    function hintsOn() as Lang.Boolean {
        return storageInt("td_hints", 0) == 0;
    }

    // Board naming is append-only: map 0/1/2 keep the names the existing
    // boards were seeded with so old scores stay comparable.
    function lbVariant() as Lang.String {
        if (isDaily()) { return "daily"; }
        var m = mapIndex();
        var mn = "bend";
        if (m == 1) { mn = "snake"; }
        else if (m == 2) { mn = "ring"; }
        else if (m == 3) { mn = "gate"; }
        var d = difficulty();
        var dn = "normal";
        if (d == 0) { dn = "easy"; }
        else if (d == 2) { dn = "hard"; }
        return mn + "-" + dn;
    }

    function dayOfYear() as Lang.Number {
        try {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var mdays = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
            var mo = info.month;
            var dy = info.day;
            if (mo < 1) { mo = 1; }
            if (mo > 12) { mo = 12; }
            return mdays[mo - 1] + dy;
        } catch (e) {}
        return 1;
    }

    // Same number for every player on a given calendar day — that's the whole
    // point of the DAILY board. Kept small so hash3() can never overflow.
    function dailySeed() as Lang.Number {
        var yr = 26;
        try {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            yr = info.year % 100;
        } catch (e) {}
        return yr * 400 + dayOfYear();
    }

    // ── Deterministic hashing ────────────────────────────────────────────────
    // Multipliers are deliberately small: a,b,c stay under a few thousand in
    // this game, so the products never leave 32-bit range.

    function hash3(a as Lang.Number, b as Lang.Number, c as Lang.Number) as Lang.Number {
        var h = (a * 37409 + b * 12379 + c * 6151 + 911) % 1000003;
        if (h < 0) { h = -h; }
        return h;
    }

    function clamp(v as Lang.Number, lo as Lang.Number, hi as Lang.Number) as Lang.Number {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    function dist2(ax, ay, bx, by) {
        var dx = ax - bx;
        var dy = ay - by;
        return dx * dx + dy * dy;
    }

    // ── Colour helpers ───────────────────────────────────────────────────────

    function shade(c as Lang.Number, pct as Lang.Number) as Lang.Number {
        var p = pct;
        if (p < 0) { p = 0; }
        var r = ((c >> 16) & 0xFF) * p / 100; if (r > 255) { r = 255; }
        var g = ((c >> 8) & 0xFF) * p / 100;  if (g > 255) { g = 255; }
        var b = (c & 0xFF) * p / 100;         if (b > 255) { b = 255; }
        return (r << 16) | (g << 8) | b;
    }

    function mix(c0 as Lang.Number, c1 as Lang.Number, t as Lang.Number) as Lang.Number {
        var k = t;
        if (k < 0) { k = 0; }
        if (k > 100) { k = 100; }
        var r = (((c0 >> 16) & 0xFF) * (100 - k) + ((c1 >> 16) & 0xFF) * k) / 100;
        var g = (((c0 >> 8) & 0xFF) * (100 - k) + ((c1 >> 8) & 0xFF) * k) / 100;
        var b = ((c0 & 0xFF) * (100 - k) + (c1 & 0xFF) * k) / 100;
        return (r << 16) | (g << 8) | b;
    }

    // ── Towers ───────────────────────────────────────────────────────────────

    function towerName(t as Lang.Number) as Lang.String {
        if (t == TW_GUN)    { return "TURRET"; }
        if (t == TW_CANNON) { return "CANNON"; }
        if (t == TW_ARCHER) { return "ARCHER"; }
        if (t == TW_FROST)  { return "FROST"; }
        if (t == TW_TESLA)  { return "TESLA"; }
        if (t == TW_FLAME)  { return "FLAME"; }
        if (t == TW_SNIPER) { return "SNIPER"; }
        return "?";
    }

    function towerBlurb(t as Lang.Number) as Lang.String {
        if (t == TW_GUN)    { return "cheap all-rounder"; }
        if (t == TW_CANNON) { return "splash, ground only"; }
        if (t == TW_ARCHER) { return "fast, long, hits air"; }
        if (t == TW_FROST)  { return "slows a whole pack"; }
        if (t == TW_TESLA)  { return "chains between foes"; }
        if (t == TW_FLAME)  { return "shreds swarms up close"; }
        if (t == TW_SNIPER) { return "huge dmg, ignores armor"; }
        return "";
    }

    function towerCost(t as Lang.Number) as Lang.Number {
        if (t == TW_GUN)    { return 45; }
        if (t == TW_CANNON) { return 95; }
        if (t == TW_ARCHER) { return 75; }
        if (t == TW_FROST)  { return 70; }
        if (t == TW_TESLA)  { return 130; }
        if (t == TW_FLAME)  { return 85; }
        if (t == TW_SNIPER) { return 150; }
        return 99;
    }

    // Cost of stepping from `tier` to tier+1 (tiers run 1..4).
    function upgradeCost(t as Lang.Number, tier as Lang.Number) as Lang.Number {
        if (tier >= 4) { return 0; }
        return (towerCost(t) * (80 + 45 * tier)) / 100;
    }

    function towerColor(t as Lang.Number) as Lang.Number {
        if (t == TW_GUN)    { return 0x74A8E8; }
        if (t == TW_CANNON) { return 0xE8843C; }
        if (t == TW_ARCHER) { return 0x8CD867; }
        if (t == TW_FROST)  { return 0x66DCEE; }
        if (t == TW_TESLA)  { return 0xC98CFF; }
        if (t == TW_FLAME)  { return 0xFF6A3A; }
        if (t == TW_SNIPER) { return 0xE8D26A; }
        return 0xFFFFFF;
    }

    function towerDmg(t as Lang.Number, tier as Lang.Number) as Lang.Number {
        var base = 7;
        if (t == TW_CANNON)      { base = 26; }
        else if (t == TW_ARCHER) { base = 6; }
        else if (t == TW_FROST)  { base = 3; }
        else if (t == TW_TESLA)  { base = 13; }
        else if (t == TW_FLAME)  { base = 4; }
        else if (t == TW_SNIPER) { base = 46; }
        var lv = tier - 1;
        if (lv < 0) { lv = 0; }
        return (base * (100 + 55 * lv)) / 100;
    }

    // Percent of the playfield side.
    function towerRangePct(t as Lang.Number, tier as Lang.Number) as Lang.Number {
        var base = 26;
        if (t == TW_CANNON)      { base = 24; }
        else if (t == TW_ARCHER) { base = 34; }
        else if (t == TW_FROST)  { base = 24; }
        else if (t == TW_TESLA)  { base = 28; }
        else if (t == TW_FLAME)  { base = 16; }
        else if (t == TW_SNIPER) { base = 48; }
        var lv = tier - 1;
        if (lv < 0) { lv = 0; }
        return base + lv * 4;
    }

    function towerCooldown(t as Lang.Number, tier as Lang.Number) as Lang.Number {
        var base = 8;
        if (t == TW_CANNON)      { base = 20; }
        else if (t == TW_ARCHER) { base = 5; }
        else if (t == TW_FROST)  { base = 14; }
        else if (t == TW_TESLA)  { base = 13; }
        else if (t == TW_FLAME)  { base = 3; }
        else if (t == TW_SNIPER) { base = 26; }
        var lv = tier - 1;
        if (lv < 0) { lv = 0; }
        var cd = (base * (100 - 12 * lv)) / 100;
        if (cd < 2) { cd = 2; }
        return cd;
    }

    function towerHitsAir(t as Lang.Number) as Lang.Boolean {
        return t != TW_CANNON && t != TW_FLAME;
    }

    // Armor-piercing towers are the answer to SHIELD enemies.
    function towerPierces(t as Lang.Number) as Lang.Boolean {
        return t == TW_SNIPER || t == TW_TESLA;
    }

    // What tier 4 unlocks, shown in the shop / upgrade card.
    function towerSpecial(t as Lang.Number) as Lang.String {
        if (t == TW_GUN)    { return "twin barrel"; }
        if (t == TW_CANNON) { return "wide blast"; }
        if (t == TW_ARCHER) { return "double shot"; }
        if (t == TW_FROST)  { return "deep chill"; }
        if (t == TW_TESLA)  { return "4x chain"; }
        if (t == TW_FLAME)  { return "burn stacks"; }
        if (t == TW_SNIPER) { return "crit x2"; }
        return "";
    }

    function targetName(m as Lang.Number) as Lang.String {
        if (m == TDT_STRONG) { return "STRONGEST"; }
        if (m == TDT_CLOSE)  { return "CLOSEST"; }
        return "FIRST";
    }

    // ── Enemies ──────────────────────────────────────────────────────────────

    function enemyName(t as Lang.Number) as Lang.String {
        if (t == EN_GRUNT)  { return "GRUNT"; }
        if (t == EN_RUNNER) { return "RUNNER"; }
        if (t == EN_TANK)   { return "TANK"; }
        if (t == EN_FLYER)  { return "FLYER"; }
        if (t == EN_SHIELD) { return "SHIELD"; }
        if (t == EN_HEALER) { return "HEALER"; }
        if (t == EN_BOSS)   { return "BOSS"; }
        return "?";
    }

    function enemyColor(t as Lang.Number) as Lang.Number {
        if (t == EN_GRUNT)  { return 0xD9553F; }
        if (t == EN_RUNNER) { return 0xF2B33D; }
        if (t == EN_TANK)   { return 0x9A6A46; }
        if (t == EN_FLYER)  { return 0xA9CCF5; }
        if (t == EN_SHIELD) { return 0xB0B8C4; }
        if (t == EN_HEALER) { return 0x6FE3A6; }
        if (t == EN_BOSS)   { return 0xFF3D77; }
        return 0xFF0000;
    }

    // Wave HP curve: linear early, quadratic late so tier-4 towers stay
    // meaningful right through wave 30 without trivialising wave 5.
    function enemyHp(t as Lang.Number, wave as Lang.Number, diff as Lang.Number) as Lang.Number {
        var mult = 10 + wave * 4 + (wave * wave) / 6 + diff * 4;
        if (t == EN_RUNNER) { return (mult * 55) / 100; }
        if (t == EN_TANK)   { return (mult * 300) / 100; }
        if (t == EN_FLYER)  { return (mult * 80) / 100; }
        if (t == EN_SHIELD) { return (mult * 150) / 100; }
        if (t == EN_HEALER) { return (mult * 120) / 100; }
        if (t == EN_BOSS)   { return mult * 10; }
        return mult;
    }

    // Flat damage soaked per hit. SHIELD is deliberately immune to chip damage.
    function enemyArmor(t as Lang.Number, wave as Lang.Number) as Lang.Number {
        var bonus = wave / 12;
        if (t == EN_TANK)   { return 3 + bonus; }
        if (t == EN_SHIELD) { return 12 + bonus * 2; }
        if (t == EN_HEALER) { return 1; }
        if (t == EN_BOSS)   { return 6 + bonus; }
        return 0;
    }

    // Path units per tick, before wave / pace / slow scaling.
    function enemySpeed(t as Lang.Number) as Lang.Float {
        if (t == EN_RUNNER) { return 1.75; }
        if (t == EN_TANK)   { return 0.60; }
        if (t == EN_FLYER)  { return 1.20; }
        if (t == EN_SHIELD) { return 0.80; }
        if (t == EN_HEALER) { return 0.85; }
        if (t == EN_BOSS)   { return 0.55; }
        return 1.0;
    }

    function enemyReward(t as Lang.Number) as Lang.Number {
        if (t == EN_RUNNER) { return 7; }
        if (t == EN_TANK)   { return 13; }
        if (t == EN_FLYER)  { return 9; }
        if (t == EN_SHIELD) { return 14; }
        if (t == EN_HEALER) { return 12; }
        if (t == EN_BOSS)   { return 70; }
        return 5;
    }

    function enemyLeakDmg(t as Lang.Number) as Lang.Number {
        if (t == EN_TANK)   { return 2; }
        if (t == EN_SHIELD) { return 2; }
        if (t == EN_BOSS)   { return 5; }
        return 1;
    }

    function enemyRadius(t as Lang.Number, u as Lang.Number) as Lang.Number {
        var r = u;
        if (t == EN_RUNNER)     { r = (u * 75) / 100; }
        else if (t == EN_TANK)  { r = (u * 145) / 100; }
        else if (t == EN_SHIELD){ r = (u * 125) / 100; }
        else if (t == EN_BOSS)  { r = (u * 195) / 100; }
        else if (t == EN_FLYER) { r = (u * 105) / 100; }
        if (r < 2) { r = 2; }
        return r;
    }

    function isFlying(t as Lang.Number) as Lang.Boolean {
        return t == EN_FLYER;
    }

    // ── Waves ────────────────────────────────────────────────────────────────

    function waveMod(seed as Lang.Number, wave as Lang.Number) as Lang.Number {
        if (wave % 5 == 0) { return TDW_BOSS; }
        if (wave < 4) { return TDW_NONE; }
        var r = hash3(seed, wave, 77) % 100;
        if (r < 42) { return TDW_NONE; }
        if (r < 58) { return TDW_SWARM; }
        if (r < 72) { return TDW_ARMORED; }
        if (r < 86) { return TDW_SPEED; }
        return TDW_FLYING;
    }

    function modName(m as Lang.Number) as Lang.String {
        if (m == TDW_SWARM)   { return "SWARM"; }
        if (m == TDW_ARMORED) { return "ARMORED"; }
        if (m == TDW_SPEED)   { return "BLITZ"; }
        if (m == TDW_FLYING)  { return "AIR RAID"; }
        if (m == TDW_BOSS)    { return "BOSS"; }
        return "STANDARD";
    }

    function modHint(m as Lang.Number) as Lang.String {
        if (m == TDW_SWARM)   { return "many, weak - use splash"; }
        if (m == TDW_ARMORED) { return "armored - need big hits"; }
        if (m == TDW_SPEED)   { return "fast - slow them down"; }
        if (m == TDW_FLYING)  { return "air - cannons cannot hit"; }
        if (m == TDW_BOSS)    { return "one huge threat"; }
        return "mixed pack";
    }

    function modColor(m as Lang.Number) as Lang.Number {
        if (m == TDW_SWARM)   { return 0xF2B33D; }
        if (m == TDW_ARMORED) { return 0xB0B8C4; }
        if (m == TDW_SPEED)   { return 0x66DCEE; }
        if (m == TDW_FLYING)  { return 0xA9CCF5; }
        if (m == TDW_BOSS)    { return 0xFF3D77; }
        return TD_C_MUTED;
    }

    function waveCount(seed as Lang.Number, wave as Lang.Number, diff as Lang.Number) as Lang.Number {
        var m = waveMod(seed, wave);
        var n = 7 + wave + wave / 3;
        if (m == TDW_SWARM) { n = (n * 175) / 100; }
        if (m == TDW_BOSS)  { n = n / 2 + 1; }
        if (diff == 0)      { n = (n * 80) / 100; }
        if (diff == 2)      { n = (n * 118) / 100; }
        if (n > 34) { n = 34; }
        if (n < 4)  { n = 4; }
        return n;
    }

    // Deterministic roster: the same seed+wave always yields the same pack, so
    // the DAILY board is a genuinely identical challenge for everyone.
    function waveEnemy(seed as Lang.Number, wave as Lang.Number, idx as Lang.Number,
                       mod as Lang.Number, count as Lang.Number) as Lang.Number {
        if (mod == TDW_BOSS && idx == count - 1) { return EN_BOSS; }
        if (mod == TDW_FLYING) {
            if (hash3(seed, wave, idx) % 100 < 78) { return EN_FLYER; }
        }
        if (mod == TDW_SWARM) {
            var rs = hash3(seed, wave, idx * 3) % 100;
            if (rs < 70) { return EN_GRUNT; }
            if (rs < 95) { return EN_RUNNER; }
            return EN_TANK;
        }
        var r = hash3(seed, wave, idx * 7) % 100;
        if (wave >= 12 && r < 8)  { return EN_HEALER; }
        if (wave >= 8  && r < 20) { return EN_SHIELD; }
        if (wave >= 4  && r < 34) { return EN_FLYER; }
        if (wave >= 6  && r < 52) { return EN_TANK; }
        if (wave >= 2  && r < 72) { return EN_RUNNER; }
        return EN_GRUNT;
    }

    // Boss ability, rotating so every boss fight asks a different question.
    function bossAbility(wave as Lang.Number) as Lang.Number {
        return (wave / 5) % 4;   // 0 rage · 1 ward · 2 summon · 3 regen
    }

    function bossAbilityName(a as Lang.Number) as Lang.String {
        if (a == 1) { return "WARD"; }
        if (a == 2) { return "SUMMON"; }
        if (a == 3) { return "REGEN"; }
        return "RAGE";
    }

    // ── Abilities ────────────────────────────────────────────────────────────

    function abilityName(a as Lang.Number) as Lang.String {
        if (a == TDA_FREEZE) { return "DEEP FREEZE"; }
        return "AIRSTRIKE";
    }

    function abilityShort(a as Lang.Number) as Lang.String {
        if (a == TDA_FREEZE) { return "FRZ"; }
        return "STR";
    }

    function abilityCost(a as Lang.Number) as Lang.Number {
        if (a == TDA_FREEZE) { return 40; }
        return 65;
    }

    // Cooldown in ticks (~70ms each).
    function abilityCd(a as Lang.Number) as Lang.Number {
        if (a == TDA_FREEZE) { return 250; }
        return 330;
    }

    function abilityColor(a as Lang.Number) as Lang.Number {
        if (a == TDA_FREEZE) { return 0x66DCEE; }
        return 0xFF8A3A;
    }

    function abilityBlurb(a as Lang.Number) as Lang.String {
        if (a == TDA_FREEZE) { return "chill every enemy"; }
        return "bomb the lead pack";
    }
}
