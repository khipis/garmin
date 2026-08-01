// ═══════════════════════════════════════════════════════════════════════════
// ChallengeManager.mc — One worldwide challenge per day.
//
// The challenge is derived purely from the day ordinal (days since the unix
// epoch), so every watch on the planet generates exactly the same sport,
// objective, distance, height and target — with no server round-trip and no
// randomness. That is what makes the daily leaderboard fair offline.
//
// Two axes rotate independently. The sport comes from DsSports.indexForDay,
// which walks a fresh permutation of the roster every six days; the objective
// comes from the day hash. A day is therefore a pair — ARCHERY STREAK,
// GOLF SPRINT — and the leaderboard variant carries both, so nobody is ever
// ranked against people who played something else.
//
// The shared backend Daily Challenge (LbDaily.mc) still runs on top of this
// for its own streak card; the two are independent by design, so the game is
// fully playable with the phone out of range.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

// Challenge objectives. Each one reads the same outcomes differently, so they
// apply unchanged to whichever sport the day landed on.
const DS_CH_SPRINT  = 0;   // most scores before the clock runs out
const DS_CH_PERFECT = 1;   // only the perfect result counts
const DS_CH_STREAK  = 2;   // longest unbroken run of scores
const DS_CH_TARGET  = 3;   // most points against a moving target

// A fully-described day. Everything the engine and the UI need.
class DsChallenge {
    var day;        // Number  — day ordinal, the seed and the challenge id
    var dayKey;     // String  — "YYYYMMDD"
    var type;       // Number  — DS_CH_*
    var sportId;    // String  — which sport the world is playing today
    var timeMs;     // Number  — length of the run
    var target;     // Number  — score that counts as "challenge beaten"
    var dist;       // Float   — target distance as a fraction of screen width
    var height;     // Float   — target height as a fraction of screen height
    var sway;       // Float   — how much the day moves, or tightens, the target

    function initialize() {
        day = 0; dayKey = ""; type = DS_CH_SPRINT; sportId = "basketball";
        timeMs = 45000; target = 6;
        dist = 0.73; height = 0.34; sway = 0.0;
    }

    function objectiveName() as Lang.String {
        if (type == DS_CH_PERFECT) { return "PERFECT"; }
        if (type == DS_CH_STREAK)  { return "STREAK"; }
        if (type == DS_CH_TARGET)  { return "TARGET"; }
        return "SPRINT";
    }

    function sportName() as Lang.String {
        return DsSports.nouns(sportId)["name"];
    }

    // What the day is called, in the two words that fit a watch: the sport
    // first, because that is what changed since yesterday.
    function shortName() as Lang.String {
        return sportName() + " " + objectiveName();
    }

    // Leaderboard variant. Boards stay comparable because every player who
    // sees this variant on a given day played the identical sport AND the
    // identical objective.
    function variant() as Lang.String {
        var obj = "sprint";
        if (type == DS_CH_PERFECT) { obj = "perfect"; }
        if (type == DS_CH_STREAK)  { obj = "streak"; }
        if (type == DS_CH_TARGET)  { obj = "target"; }
        return sportId + "-" + obj;
    }

    function unit() as Lang.String {
        var n = DsSports.nouns(sportId);
        if (type == DS_CH_PERFECT) { return n["perfect"]; }
        if (type == DS_CH_STREAK)  { return "in a row"; }
        if (type == DS_CH_TARGET)  { return "points"; }
        return n["scored"];
    }

    // Full briefing text, wrapped by the UI.
    function label() as Lang.String {
        var secs = (timeMs / 1000).toString();
        var n    = DsSports.nouns(sportId);
        if (type == DS_CH_PERFECT) {
            return "Only " + n["perfect"] + " count. As many as you can in " +
                   secs + "s. Target " + target.toString() + ".";
        }
        if (type == DS_CH_STREAK) {
            return "Longest run of " + n["scored"] + " without a miss in " +
                   secs + "s. Target " + target.toString() + " in a row.";
        }
        if (type == DS_CH_TARGET) {
            return "Tight target. Beat " + target.toString() + " points in " +
                   secs + "s. Perfect 3, anything else 2.";
        }
        return n["verb"] + " as many " + n["scored"] + " as you can in " +
               secs + "s. Target " + target.toString() + ".";
    }
}

module ChallengeManager {

    var _cache = null;    // DsChallenge for _cacheDay
    var _cacheDay = -1;

    // Today's challenge (cached — it only changes at midnight).
    function today() as DsChallenge {
        var dn = DsUtil.dayNumber();
        if (_cache != null && _cacheDay == dn) { return _cache; }
        _cache = at(dn);
        _cache.dayKey = DsUtil.todayKey();
        _cacheDay = dn;
        return _cache;
    }

    // The challenge for any day ordinal. Pure function of `dn`.
    function at(dn as Lang.Number) as DsChallenge {
        var c = new DsChallenge();
        c.day     = dn;
        c.type    = DsUtil.hash(dn, 11) % 4;
        c.sportId = DsSports.idForDay(dn);

        // The field drifts day to day so the muscle memory has to adapt, but
        // stays inside a range every screen size and every sport can present.
        c.dist   = 0.68 + (DsUtil.hash(dn, 23) % 7)  * 0.02;
        c.height = 0.32 + (DsUtil.hash(dn, 37) % 5)  * 0.015;

        if (c.type == DS_CH_PERFECT) {
            c.timeMs = 60000;
            c.target = 3 + DsUtil.hash(dn, 53) % 3;
        } else if (c.type == DS_CH_STREAK) {
            c.timeMs = 60000;
            c.target = 3 + DsUtil.hash(dn, 59) % 3;
        } else if (c.type == DS_CH_TARGET) {
            c.timeMs = 45000;
            c.target = 14 + (DsUtil.hash(dn, 61) % 5) * 2;
            c.sway   = 0.045 + (DsUtil.hash(dn, 67) % 3) * 0.015;
        } else {
            c.timeMs = 45000;
            c.target = 6 + DsUtil.hash(dn, 71) % 4;
        }
        return c;
    }

    // What drops at midnight — the reason to come back tomorrow. It is the
    // sport that changes, so the sport is what gets named.
    function tomorrowName() as Lang.String {
        return DsSports.nameForDay(DsUtil.dayNumber() + 1);
    }

    // Score a resolved shot for this objective. STREAK is handled by the
    // engine (it tracks run length), everything else is a plain increment.
    function pointsFor(c as DsChallenge, outcome as Lang.Number) as Lang.Number {
        if (c.type == DS_CH_PERFECT) {
            return (outcome == DS_OUT_SWISH) ? 1 : 0;
        }
        if (c.type == DS_CH_TARGET) {
            if (outcome == DS_OUT_SWISH) { return 3; }
            if (outcome == DS_OUT_BANK)  { return 2; }
            if (outcome == DS_OUT_RIM)   { return 2; }
            return 0;
        }
        // SPRINT (and the streak run counter): anything that scored counts
        // once, whichever of the two lesser ways it went in.
        if (outcome == DS_OUT_SWISH || outcome == DS_OUT_RIM ||
            outcome == DS_OUT_BANK) { return 1; }
        return 0;
    }
}
