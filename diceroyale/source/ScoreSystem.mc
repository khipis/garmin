// ═══════════════════════════════════════════════════════════════
// ScoreSystem.mc — Yahtzee-style scoring categories.
//
// 13 categories.  Each is used at most once per game; once
// committed it stays committed and contributes `values[i]` to
// `total`.  `score(cat, dice)` is pure and used for both preview
// (potential score on the current dice) and commit.
//
// Scoring rules:
//
//   0 ONES … 5 SIXES    sum of dice matching face (1..6)
//   6 THREE_OF_KIND     ≥3 of same face   → sum of ALL dice
//   7 FOUR_OF_KIND      ≥4 of same face   → sum of ALL dice
//   8 FULL_HOUSE        3+2 (different)   → 25
//   9 SMALL_STRAIGHT    4 consecutive     → 30
//  10 LARGE_STRAIGHT    5 consecutive     → 40
//  11 CHANCE            no requirement    → sum of ALL dice
//  12 YAHTZEE (5-kind)  all five equal    → 50
//
// `availableSet` is a bitmask of usable categories (defined by
// game mode — Classic = all, Quick = only ONES..SIXES).
// ═══════════════════════════════════════════════════════════════

const DR_CAT_ONES   = 0;
const DR_CAT_TWOS   = 1;
const DR_CAT_THREES = 2;
const DR_CAT_FOURS  = 3;
const DR_CAT_FIVES  = 4;
const DR_CAT_SIXES  = 5;
const DR_CAT_3K     = 6;
const DR_CAT_4K     = 7;
const DR_CAT_FH     = 8;
const DR_CAT_SS     = 9;
const DR_CAT_LS     = 10;
const DR_CAT_CHANCE = 11;
const DR_CAT_YAHTZ  = 12;
const DR_CAT_COUNT  = 13;

// Bitmasks for game modes (which categories are in play).
const DR_MODE_CLASSIC_MASK = 0x1FFF;   // 13 bits = all categories
const DR_MODE_QUICK_MASK   = 0x003F;   // 6 bits  = ones..sixes only
const DR_MODE_DAILY_MASK   = 0x1FFF;   // daily = classic ruleset

class ScoreSystem {
    var used;          // Array<13> of bool
    var values;        // Array<13> of Number (0 if not committed)
    var availableSet;  // bitmask of categories in play
    var total;

    function initialize() {
        used         = new [DR_CAT_COUNT];
        values       = new [DR_CAT_COUNT];
        availableSet = DR_MODE_CLASSIC_MASK;
        total        = 0;
        reset(DR_MODE_CLASSIC_MASK);
    }

    function reset(mask) {
        availableSet = mask;
        for (var i = 0; i < DR_CAT_COUNT; i++) {
            used[i]   = false;
            values[i] = 0;
        }
        total = 0;
    }

    function isAvailable(cat) {
        return (availableSet & (1 << cat)) != 0;
    }
    function isUsed(cat) { return used[cat]; }

    // True when every available category has been committed.
    function allDone() {
        for (var i = 0; i < DR_CAT_COUNT; i++) {
            if (isAvailable(i) && !used[i]) { return false; }
        }
        return true;
    }

    function categoryName(cat) {
        if (cat == DR_CAT_ONES)   { return "Ones";   }
        if (cat == DR_CAT_TWOS)   { return "Twos";   }
        if (cat == DR_CAT_THREES) { return "Threes"; }
        if (cat == DR_CAT_FOURS)  { return "Fours";  }
        if (cat == DR_CAT_FIVES)  { return "Fives";  }
        if (cat == DR_CAT_SIXES)  { return "Sixes";  }
        if (cat == DR_CAT_3K)     { return "3-Kind"; }
        if (cat == DR_CAT_4K)     { return "4-Kind"; }
        if (cat == DR_CAT_FH)     { return "Full H"; }
        if (cat == DR_CAT_SS)     { return "Sm Str"; }
        if (cat == DR_CAT_LS)     { return "Lg Str"; }
        if (cat == DR_CAT_CHANCE) { return "Chance"; }
        if (cat == DR_CAT_YAHTZ)  { return "5-Kind"; }
        return "?";
    }

    // Pure: compute the score for `cat` from the given dice array.
    function score(cat, dice) {
        var counts = _counts(dice);
        var sum    = _sum(dice);

        if (cat == DR_CAT_ONES)   { return counts[0] * 1; }
        if (cat == DR_CAT_TWOS)   { return counts[1] * 2; }
        if (cat == DR_CAT_THREES) { return counts[2] * 3; }
        if (cat == DR_CAT_FOURS)  { return counts[3] * 4; }
        if (cat == DR_CAT_FIVES)  { return counts[4] * 5; }
        if (cat == DR_CAT_SIXES)  { return counts[5] * 6; }

        if (cat == DR_CAT_3K) {
            return _hasN(counts, 3) ? sum : 0;
        }
        if (cat == DR_CAT_4K) {
            return _hasN(counts, 4) ? sum : 0;
        }
        if (cat == DR_CAT_FH) {
            // 3+2 of different faces.  A five-of-a-kind isn't a
            // full house in classic rules.
            var has3 = false; var has2 = false;
            for (var f = 0; f < 6; f++) {
                if (counts[f] == 3) { has3 = true; }
                else if (counts[f] == 2) { has2 = true; }
            }
            return (has3 && has2) ? 25 : 0;
        }
        if (cat == DR_CAT_SS) {
            return _hasStraight(counts, 4) ? 30 : 0;
        }
        if (cat == DR_CAT_LS) {
            return _hasStraight(counts, 5) ? 40 : 0;
        }
        if (cat == DR_CAT_CHANCE) { return sum; }
        if (cat == DR_CAT_YAHTZ)  { return _hasN(counts, 5) ? 50 : 0; }

        return 0;
    }

    function commit(cat, dice) {
        if (!isAvailable(cat) || used[cat]) { return 0; }
        var s     = score(cat, dice);
        values[cat] = s;
        used[cat]   = true;
        total       = total + s;
        return s;
    }

    // ── helpers ──────────────────────────────────────────────────

    hidden function _counts(dice) {
        var c = [0, 0, 0, 0, 0, 0];
        for (var i = 0; i < dice.size(); i++) {
            var v = dice[i];
            if (v >= 1 && v <= 6) { c[v - 1] = c[v - 1] + 1; }
        }
        return c;
    }
    hidden function _sum(dice) {
        var s = 0;
        for (var i = 0; i < dice.size(); i++) { s = s + dice[i]; }
        return s;
    }
    hidden function _hasN(counts, n) {
        for (var i = 0; i < 6; i++) { if (counts[i] >= n) { return true; } }
        return false;
    }
    // True if the dice contain a run of `len` consecutive faces.
    hidden function _hasStraight(counts, len) {
        var run = 0;
        var best = 0;
        for (var i = 0; i < 6; i++) {
            if (counts[i] > 0) {
                run = run + 1;
                if (run > best) { best = run; }
            } else {
                run = 0;
            }
        }
        return best >= len;
    }
}
