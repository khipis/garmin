// ═══════════════════════════════════════════════════════════════════════════
// CrConst.mc — Shared constants for BITOCHI CREATURES.
//
// An idle evolution game: hatch an egg, raise a procedurally-generated creature
// that becomes uniquely yours based on how you play and your Garmin activity.
// Everything here is data-only so every module reads the same tables/keys.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;

module Cr {

    // Showcase-only DEMO fast-track. Kept in code for capturing promo footage,
    // but the on-screen toggle is HIDDEN from users in shipped builds. Flip to
    // true to expose the DEMO pill again when recording.
    const SHOW_DEMO = false;

    // ── Leaderboard ──────────────────────────────────────────────────────────
    const GAME_ID = "creatures";

    // Leaderboard categories (variant strings sent to the shared backend).
    // Not "just highest level" — four ways to be the best.
    const LB_RARITY  = "Rarity";   // rarest creature (rarity score)
    const LB_AGE     = "Age";      // longest-living creature (days alive)
    const LB_EVO     = "Evolution";// highest evolution reached
    const LB_TRAINER = "Trainer";  // most active trainer (lifetime actions)

    // ── Species ──────────────────────────────────────────────────────────────
    const SPECIES_N = 5;
    const SP_FLAME  = 0;   // Flameborn
    const SP_AQUA   = 1;   // Aquarian
    const SP_VOLT   = 2;   // Voltling
    const SP_FOREST = 3;   // Forestkin
    const SP_SHADOW = 4;   // Shadowborn

    function speciesName(i) {
        var a = ["Flameborn", "Aquarian", "Voltling", "Forestkin", "Shadowborn"];
        return a[_clamp(i, 0, SPECIES_N - 1)];
    }

    // Primary + accent colours per species (used for art + rarity glow).
    function speciesColor(i) {
        var a = [0xFF5A2A, 0x33AEE0, 0xFFD24A, 0x4CC85A, 0x9A6CFF];
        return a[_clamp(i, 0, SPECIES_N - 1)];
    }
    function speciesDark(i) {
        var a = [0x7A2410, 0x134A66, 0x7A5E10, 0x1E5A28, 0x442E7A];
        return a[_clamp(i, 0, SPECIES_N - 1)];
    }
    function speciesElement(i) {
        var a = ["Fire", "Water", "Electric", "Nature", "Shadow"];
        return a[_clamp(i, 0, SPECIES_N - 1)];
    }

    // ── Traits ───────────────────────────────────────────────────────────────
    const TR_N   = 5;
    // Per-trait cap. Every place that grows a trait clamps to this, and every
    // trait bar scales to it — raise it here only, never inline.
    const TRAIT_MAX = 20;
    const TR_SPD = 0;  // Speed
    const TR_STR = 1;  // Strength
    const TR_INT = 2;  // Intelligence
    const TR_NRG = 3;  // Energy
    const TR_LCK = 4;  // Luck

    function traitAbbr(i) {
        var a = ["SPD", "STR", "INT", "NRG", "LCK"];
        return a[_clamp(i, 0, TR_N - 1)];
    }
    function traitName(i) {
        var a = ["Speed", "Strength", "Intelligence", "Energy", "Luck"];
        return a[_clamp(i, 0, TR_N - 1)];
    }
    // Short flavour tag for a dominant trait (shown on the home card).
    function traitTag(i) {
        var a = ["Fast", "Mighty", "Clever", "Charged", "Lucky"];
        return a[_clamp(i, 0, TR_N - 1)];
    }

    // ── Rarity ───────────────────────────────────────────────────────────────
    const RA_N     = 5;
    const RA_COMMON = 0;
    const RA_RARE   = 1;
    const RA_EPIC   = 2;
    const RA_LEGEND = 3;
    const RA_MYTHIC = 4;

    function rarityName(i) {
        var a = ["Common", "Rare", "Epic", "Legendary", "Mythic"];
        return a[_clamp(i, 0, RA_N - 1)];
    }
    function rarityColor(i) {
        var a = [0xAAB4C0, 0x4CA8FF, 0xB46CFF, 0xFFC24A, 0xFF4C7A];
        return a[_clamp(i, 0, RA_N - 1)];
    }
    // Approx global ownership % per rarity (flavour for the collection index).
    function rarityPct(i) {
        var a = ["61%", "24%", "9%", "3%", "0.4%"];
        return a[_clamp(i, 0, RA_N - 1)];
    }

    // ── Evolution stages ─────────────────────────────────────────────────────
    // APPEND ONLY — these ids are persisted in saves and shipped to the web
    // avatar renderer as the numeric "ev" field. Never renumber.
    const EV_EGG   = 0;
    const EV_HATCH = 1;   // Hatchling
    const EV_JUV   = 2;   // Juvenile
    const EV_ADULT = 3;   // Adult
    const EV_APEX  = 4;   // Apex     (was the old end of the game)
    const EV_MYTH    = 5; // Mythic
    const EV_ETERNAL = 6; // Eternal
    const EV_COSMIC  = 7; // Cosmic   — final stage
    const EV_N   = 8;     // table size: grow with EVERY parallel stage array
    const EV_MAX = 7;     // last stage id (must equal EV_COSMIC)

    function stageName(i) {
        var a = ["Egg", "Hatchling", "Juvenile", "Adult", "Apex",
                 "Mythic", "Eternal", "Cosmic"];
        return a[_clamp(i, 0, EV_N - 1)];
    }
    // Title prefix earned at higher stages.
    function stageTitle(i) {
        if (i >= EV_COSMIC)  { return "Cosmic";  }
        if (i >= EV_ETERNAL) { return "Eternal"; }
        if (i >= EV_MYTH)    { return "Mythic";  }
        if (i >= EV_APEX)    { return "Ancient"; }
        if (i >= EV_ADULT)   { return "Elder";   }
        return "";
    }

    // Evolution gates: the (daysAlive, level) needed to REACH stage i. Two
    // parallel EV_N-sized tables — grow both together with EV_N/EV_MAX. Egg and
    // Hatchling have no gate (0/0); hatching is driven by the incubation timer.
    function evoDays(i) {
        var a = [0, 0, 1, 7, 30, 70, 140, 260];
        return a[_clamp(i, 0, EV_N - 1)];
    }
    function evoLevel(i) {
        var a = [0, 0, 5, 12, 25, 45, 70, 100];
        return a[_clamp(i, 0, EV_N - 1)];
    }

    // ── Ascension (the replay layer) ──────────────────────────────────────────
    // At Apex or beyond a player may ascend into a brand new egg and keep a
    // permanent legacy that makes every subsequent creature stronger.
    const ASC_XP_PCT    = 15;  // +15% XP gain per ascension
    const ASC_BONUS_CAP = 20;  // legacy bonuses stop scaling past this many
    const ASC_TRAIT_CAP = 8;   // max +N to the MINIMUM starting trait roll
    const ASC_RARITY    = 80;  // rarity score granted per ascension

    // ── Evolution paths (driven by behaviour + Garmin data) ──────────────────
    const PATH_NONE   = 0;
    const PATH_RUNNER = 1;  // high steps  → Runner / Speed
    const PATH_WARRIOR= 2;  // high training
    const PATH_DREAM  = 3;  // high sleep
    const PATH_ENERGY = 4;  // high heart-rate activity

    function pathName(i) {
        var a = ["Wild", "Runner", "Warrior", "Dreamer", "Dynamo"];
        return a[_clamp(i, 0, 4)];
    }
    function pathTrait(i) {
        // Which trait a path favours.
        var a = [TR_LCK, TR_SPD, TR_STR, TR_INT, TR_NRG];
        return a[_clamp(i, 0, 4)];
    }

    // ── Progression tuning ───────────────────────────────────────────────────
    const HATCH_SECONDS = 6 * 3600;   // real time for an egg to hatch
    const BOOST_SECONDS = 30 * 60;    // each BOOST shaves 30 min off the timer
    const OFFLINE_CAP   = 24 * 3600;  // max idle window rewarded
    const ENERGY_MAX    = 100;
    const MOOD_MAX      = 100;
    const FEED_COST     = 3;          // food per feed
    const TRAIN_ENERGY  = 12;         // energy per training
    const EXPLORE_ENERGY= 8;          // energy per explore

    // Level curve. The linear term keeps levels 1-10 almost exactly where they
    // were; the quadratic term is what turns levels 70-100 into a long haul.
    function xpForLevel(lvl) { return 125 * lvl + 4 * lvl * lvl; }

    // Idle XP earned per real hour. Identical to the original (5 + lvl) up to
    // level 4 and only mildly richer through the teens, but it keeps growing so
    // the level 45/70/100 evolution gates stay reachable in real days instead of
    // stalling out at ~20 days per level. Capped so elapsed * rate can never
    // overflow a 32-bit int even with a corrupt level.
    function idleXpPerHour(lvl) {
        var l = lvl;
        if (!(l instanceof Lang.Number) || l < 1) { l = 1; }
        var r = 5 + l + l * l / 20;
        if (r > 4000) { r = 4000; }
        return r;
    }

    // ── Palette ──────────────────────────────────────────────────────────────
    const BG      = 0x070A0F;
    const CIRCLE  = 0x0E141C;
    const ACCENT  = 0x34D399;
    const TEXT    = 0xE6F0F7;
    const MUTED   = 0x7C8BA0;
    const PANEL   = 0x121A24;
    const PANEL_HI= 0x1B2634;
    const GOLD    = 0xFFC24A;

    function _clamp(v, lo, hi) {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }
}
