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
    const LB_ARENA   = "Arena";    // arena rank points

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
    // Short power blurb shown when the player picks / reviews a path.
    function pathPower(i) {
        var a = [
            "Wild: luckier finds",
            "Runner: cheap quests",
            "Warrior: harder trains",
            "Dreamer: rich idle XP",
            "Dynamo: better feeds"
        ];
        return a[_clamp(i, 0, 4)];
    }

    // ── Expedition destinations (QUEST replaces flat EXPLORE) ────────────────
    const DEST_N      = 4;
    const DEST_FOREST = 0;  // food haul
    const DEST_PEAK   = 1;  // XP + trait spark
    const DEST_RUINS  = 2;  // DNA + relics
    const DEST_NIGHT  = 3;  // mood bond + rare luck (costs more)

    function destName(i) {
        var a = ["Forest", "Peak", "Ruins", "Night"];
        return a[_clamp(i, 0, DEST_N - 1)];
    }
    function destHint(i) {
        var a = ["+food", "+XP/trait", "+DNA/relic", "+bond/luck"];
        return a[_clamp(i, 0, DEST_N - 1)];
    }
    function destEnergy(i) {
        var a = [8, 10, 12, 14];
        return a[_clamp(i, 0, DEST_N - 1)];
    }

    // ── Relics (collection depth beyond the 5 species) ────────────────────────
    const RELIC_N = 8;
    function relicName(i) {
        var a = ["Ember Shard", "Tide Pearl", "Storm Core", "Root Charm",
                 "Shade Veil", "Bone Idol", "Star Map", "Dragon Scale"];
        return a[_clamp(i, 0, RELIC_N - 1)];
    }

    // ── Ascension perks (pick ONE on each rebirth — permanent) ────────────────
    const PERK_N       = 5;
    const PERK_HATCH   = 0;  // faster incubation
    const PERK_LUCK    = 1;  // +LCK floor on hatch
    const PERK_FEED    = 2;  // cheaper / stronger feeds
    const PERK_IDLE    = 3;  // richer offline XP
    const PERK_DAILY   = 4;  // double daily DNA

    function perkName(i) {
        var a = ["Swift Nest", "Lucky Blood", "Hearty Appetite",
                 "Deep Dreams", "Daily Blessing"];
        return a[_clamp(i, 0, PERK_N - 1)];
    }
    function perkHint(i) {
        var a = ["faster hatch", "+2 LCK floor", "better feeds",
                 "+25% idle XP", "2 DNA on claim"];
        return a[_clamp(i, 0, PERK_N - 1)];
    }

    // ── Bond weekly contract ─────────────────────────────────────────────────
    const BOND_N = 4;

    // ── Progression tuning ───────────────────────────────────────────────────
    const HATCH_SECONDS = 6 * 3600;   // real time for an egg to hatch
    const BOOST_SECONDS = 30 * 60;    // each BOOST shaves 30 min off the timer
    const OFFLINE_CAP   = 24 * 3600;  // max idle window rewarded
    const ENERGY_MAX    = 100;
    const MOOD_MAX      = 100;
    const FEED_COST     = 3;          // food per feed
    const TRAIN_ENERGY  = 12;         // energy per training
    const EXPLORE_ENERGY= 8;          // legacy flat explore (quests use destEnergy)
    const MOOD_SULK     = 22;         // below this: train blocked
    const MOOD_LOW      = 40;         // below this: quest rewards dented
    const MOOD_HIGH     = 78;         // at/above: bonus finds + train XP

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

    // ═══════════════════════════════════════════════════════════════════════
    // ARENA — battle strategy, rank ladder, equipment and element flavour.
    // APPEND ONLY, same rule as evolution stages: these ids are persisted.
    // ═══════════════════════════════════════════════════════════════════════

    // ── Battle strategy ───────────────────────────────────────────────────────
    const ST_AGG = 0;   // Aggressive: +ATK / -DEF
    const ST_BAL = 1;   // Balanced: no change
    const ST_DEF = 2;   // Defensive: +DEF / -ATK
    const ST_N   = 3;

    function strategyName(i) {
        var a = ["Aggressive", "Balanced", "Defensive"];
        return a[_clamp(i, 0, ST_N - 1)];
    }
    function strategyHint(i) {
        var a = ["+25% ATK  -15% DEF", "no change", "+25% DEF  -15% ATK"];
        return a[_clamp(i, 0, ST_N - 1)];
    }
    function strategyAbbr(i) {
        var a = ["AGG", "BAL", "DEF"];
        return a[_clamp(i, 0, ST_N - 1)];
    }

    // ── Arena rank ladder (derived from arenaPts, never decreases the label
    // mid-fight — only the running point total does) ─────────────────────────
    const RK_BRONZE  = 0;
    const RK_SILVER  = 1;
    const RK_GOLD    = 2;
    const RK_DIAMOND = 3;
    const RK_LEGEND  = 4;
    const RK_N       = 5;

    function rankThreshold(i) {
        var a = [0, 200, 600, 1500, 4000];
        return a[_clamp(i, 0, RK_N - 1)];
    }
    function rankName(i) {
        var a = ["Bronze", "Silver", "Gold", "Diamond", "Legend"];
        return a[_clamp(i, 0, RK_N - 1)];
    }
    function rankAbbr(i) {
        var a = ["BRZ", "SLV", "GLD", "DIA", "LGD"];
        return a[_clamp(i, 0, RK_N - 1)];
    }
    function rankColor(i) {
        var a = [0xCD7F32, 0xC0C8D0, 0xFFC24A, 0x4CC8FF, 0xFF4C7A];
        return a[_clamp(i, 0, RK_N - 1)];
    }
    // Highest rank whose threshold the given point total has reached.
    function rankOf(pts) {
        var r = 0;
        for (var i = RK_N - 1; i >= 0; i--) {
            if (pts >= rankThreshold(i)) { r = i; break; }
        }
        return r;
    }

    // ── Equipment (won from the Arena, cosmetic-adjacent combat gear) ────────
    // Three slots — 0 weapon (ATK), 1 armor (DEF), 2 artifact (SPD-leaning) —
    // four tiers each. Unlocks either from a matching relic OR an arena win
    // count (whichever the player reaches first), so both QUEST and ARENA feed
    // the same reward. Parallel arrays, APPEND ONLY.
    const EQ_N          = 12;
    const EQ_SLOT_WEAPON = 0;
    const EQ_SLOT_ARMOR  = 1;
    const EQ_SLOT_ART    = 2;

    function eqName(i) {
        var a = ["Rusty Blade", "Iron Fang", "Storm Edge", "Dragon Fang",
                 "Cloth Wrap", "Scale Mail", "Root Plate", "Shade Aegis",
                 "Lucky Charm", "Swift Idol", "Tide Band", "Star Map Ring"];
        return a[_clamp(i, 0, EQ_N - 1)];
    }
    function eqSlot(i) {
        var a = [0, 0, 0, 0,  1, 1, 1, 1,  2, 2, 2, 2];
        return a[_clamp(i, 0, EQ_N - 1)];
    }
    function eqAtkPct(i) {
        var a = [5, 10, 16, 24,  0, 0, 0, 0,  0, 0, 3, 5];
        return a[_clamp(i, 0, EQ_N - 1)];
    }
    function eqDefPct(i) {
        var a = [0, 0, 0, 0,  5, 10, 16, 24,  0, 0, 3, 0];
        return a[_clamp(i, 0, EQ_N - 1)];
    }
    function eqSpdPct(i) {
        var a = [0, 0, 0, 0,  0, 0, 0, 0,  5, 10, 3, 8];
        return a[_clamp(i, 0, EQ_N - 1)];
    }
    // Arena wins needed to unlock this item WITHOUT the matching relic.
    function eqWinReq(i) {
        var a = [0, 3, 8, 20,  0, 3, 8, 20,  0, 3, 8, 20];
        return a[_clamp(i, 0, EQ_N - 1)];
    }
    function eqSlotName(s) {
        if (s == EQ_SLOT_WEAPON) { return "WPN"; }
        if (s == EQ_SLOT_ARMOR)  { return "ARM"; }
        return "ART";
    }

    // ── Live rivals (real players read off the Arena leaderboard) ────────────
    // The roster is the only network traffic the Arena does. It is capped small
    // because it is re-read from Storage on every fight, and it is refreshed at
    // most once a calendar day: a stale rival is still a real player, and an
    // absent one simply falls back to a procedural foe.
    const ROSTER_MAX      = 8;
    // Counted in view frames (the 66 ms animation tick) rather than held on a
    // Timer of their own: the leaderboard pipeline already sits at the device
    // timer budget and one more allocation crashes the app on launch.
    const ROSTER_DELAY_TICKS = 150;  // ~10 s — lands after launch ping -> msgs -> daily
    const ROSTER_WAIT_TICKS  = 8;    // ~0.5 s — busy-channel re-check
    const ROSTER_WAIT_MAX = 30;      // deferrals before giving up for the session

    // ── Defence: rival challenges resolved on the way back in ────────────────
    // There is no server-side PvP, so the raids that happened "while you were
    // away" are rolled at collect time. Deliberately low stakes: the creature is
    // never hurt, no equipment is ever lost, only ladder points move.
    const DEF_MAX_PER_RETURN = 3;    // regardless of how long the absence was
    const DEF_HOURS_PER_TRY  = 6;
    const DEF_CHANCE_PCT     = 55;
    const DEF_ROUNDS         = 5;    // volleys an attacker lands before giving up
    const DEF_HOLD_PTS       = 5;
    const DEF_LOSS_PTS       = 7;
    const DEF_LOG_MAX        = 8;

    // ── Critical hits ────────────────────────────────────────────────────────
    const CRIT_MULT_PCT = 150;
    const CRIT_CAP_PCT  = 35;

    // ── Elements: short battle-flavour tag + the type-advantage wheel ────────
    // Fire > Nature > Shadow > Electric > Water > Fire (each beats exactly one
    // other for a clean +15% damage edge — see elementBeats()).
    function elementHint(sp) {
        var a = ["Fire burns Nature", "Water douses Fire",
                 "Electric shocks Water", "Nature chokes Shadow",
                 "Shadow drains Electric"];
        return a[_clamp(sp, 0, SPECIES_N - 1)];
    }
    // Species index this species holds an elemental edge over.
    function elementBeats(sp) {
        var a = [3, 0, 1, 4, 2];
        return a[_clamp(sp, 0, SPECIES_N - 1)];
    }
}
