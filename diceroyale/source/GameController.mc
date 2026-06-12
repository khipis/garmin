// ═══════════════════════════════════════════════════════════════
// GameController.mc — DiceRoyale game flow.
//
// States:
//   DR_MENU  → chess-style menu (mode, rerolls, START)
//   DR_PLAY  → playing.  Two sub-phases:
//                PHASE_ROLL   pick which dice to hold, hit ROLL or
//                             go to scoring
//                PHASE_SCORE  pick a category to commit
//   DR_OVER  → final scoreboard
//
// Menu rows (chess-style, 3 rows):
//   0  Mode      (Classic / Quick / Daily)
//   1  Rerolls   (1 / 2 / 3)
//   2  START
//
// PHASE_ROLL cursor positions:
//   0..4   five dice (toggle hold)
//     5    ROLL  (only if rerollsLeft > 0)
//     6    SCORE (always)
//
// PHASE_SCORE cursor: 0..12, but cursor moves skip used categories
// and categories disabled by the active mode mask.
//
// Persistence keys (Application.Storage):
//   dr_mode          last selected mode
//   dr_rerolls       starting rerolls
//   dr_best_classic  high score (classic)
//   dr_best_quick    high score (quick)
//   dr_best_daily    last completed daily score
//   dr_daily_date    day-of-year of last completed daily
//   dr_games         total games played (lifetime counter)
//   dr_streak        consecutive daily completions
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.System;

const DR_MENU = 0;
const DR_PLAY = 1;
const DR_OVER = 2;

const DR_PHASE_ROLL  = 0;
const DR_PHASE_SCORE = 1;

const DR_MODE_CLASSIC = 0;
const DR_MODE_QUICK   = 1;
const DR_MODE_DAILY   = 2;

// Chess-style menu rows. A 4th LEADERBOARD row pushes the shared
// global leaderboard (split by mode via the variant string).
const DR_MENU_ROWS = 4;
const DR_ROW_MODE    = 0;
const DR_ROW_REROLLS = 1;
const DR_ROW_START   = 2;
const DR_ROW_LB      = 3;

// Global leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "diceroyale";

const DR_POS_ROLL  = 5;     // PHASE_ROLL cursor positions
const DR_POS_SCORE = 6;

// Persistence keys.
const DR_KEY_MODE         = "dr_mode";
const DR_KEY_REROLLS      = "dr_rerolls";
const DR_KEY_BEST_CLASSIC = "dr_best_classic";
const DR_KEY_BEST_QUICK   = "dr_best_quick";
const DR_KEY_BEST_DAILY   = "dr_best_daily";
const DR_KEY_DAILY_DATE   = "dr_daily_date";
const DR_KEY_GAMES        = "dr_games";
const DR_KEY_STREAK       = "dr_streak";

class GameController {
    var state;
    var menuRow;
    var menuMode;          // Classic / Quick / Daily
    var menuRerolls;       // 1 / 2 / 3

    var dice;              // DiceManager
    var scores;            // ScoreSystem

    var phase;             // DR_PHASE_ROLL or DR_PHASE_SCORE
    var rollCursor;        // 0..6
    var scoreCursor;       // 0..12

    var roundsPlayed;
    var maxRounds;         // depends on mode

    var bestClassic;
    var bestQuick;
    var bestDaily;
    var dailyDate;         // day-of-year (1..366) of last completed daily
    var dailyPlayedToday;
    var gamesPlayed;
    var streak;

    function initialize() {
        state         = DR_MENU;
        menuRow       = 0;
        menuMode      = DR_MODE_CLASSIC;
        menuRerolls   = 2;

        dice    = new DiceManager();
        scores  = new ScoreSystem();

        phase        = DR_PHASE_ROLL;
        rollCursor   = 0;
        scoreCursor  = 0;
        roundsPlayed = 0;
        maxRounds    = DR_CAT_COUNT;

        bestClassic      = 0;
        bestQuick        = 0;
        bestDaily        = 0;
        dailyDate        = 0;
        dailyPlayedToday = false;
        gamesPlayed      = 0;
        streak           = 0;

        _loadAll();
        _refreshDailyStatus();
    }

    // ── Persistence ─────────────────────────────────────────────
    hidden function _loadAll() {
        bestClassic = _loadInt(DR_KEY_BEST_CLASSIC, 0);
        bestQuick   = _loadInt(DR_KEY_BEST_QUICK,   0);
        bestDaily   = _loadInt(DR_KEY_BEST_DAILY,   0);
        dailyDate   = _loadInt(DR_KEY_DAILY_DATE,   0);
        gamesPlayed = _loadInt(DR_KEY_GAMES,        0);
        streak      = _loadInt(DR_KEY_STREAK,       0);

        var m = _loadInt(DR_KEY_MODE, DR_MODE_CLASSIC);
        if (m >= 0 && m <= 2) { menuMode = m; }
        var r = _loadInt(DR_KEY_REROLLS, 2);
        if (r >= 1 && r <= 3) { menuRerolls = r; }
    }
    hidden function _loadInt(key, defv) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Number) { return v; }
        } catch (e) {}
        return defv;
    }
    hidden function _save(key, val) {
        try { Application.Storage.setValue(key, val); } catch (e) {}
    }
    hidden function _saveSettings() {
        _save(DR_KEY_MODE,    menuMode);
        _save(DR_KEY_REROLLS, menuRerolls);
    }

    // Day-of-year (1..366) of "today".  Used to gate daily mode so
    // a player can complete the daily once per day.
    hidden function _todayDOY() {
        try {
            var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            // Approximate DOY: 31*(month-1) + day.  Doesn't need to
            // be calendar-perfect — just unique per day within a year.
            return 31 * (now.month - 1) + now.day + 1000 * (now.year % 100);
        } catch (e) {
            return 0;
        }
    }
    hidden function _refreshDailyStatus() {
        var t = _todayDOY();
        dailyPlayedToday = (t != 0 && dailyDate == t);
    }
    hidden function _todaySeed() {
        var t = _todayDOY();
        if (t < 1) { t = 1; }
        return t;
    }

    // ── Menu ───────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % DR_MENU_ROWS; }
    function menuPrev() { menuRow = (menuRow + DR_MENU_ROWS - 1) % DR_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < DR_MENU_ROWS) { menuRow = i; } }

    function menuActivate() {
        if (menuRow == DR_ROW_MODE) {
            menuMode = (menuMode + 1) % 3;
            _saveSettings();
        } else if (menuRow == DR_ROW_REROLLS) {
            menuRerolls = (menuRerolls % 3) + 1;
            _saveSettings();
        } else if (menuRow == DR_ROW_START) {
            _startGame();
        }
        // DR_ROW_LB is handled by MainView.openLeaderboard().
    }

    // Lowercased mode name used as the leaderboard variant so each
    // mode keeps its own ranking ("classic" / "quick" / "daily").
    function variantName() {
        return modeName().toLower();
    }

    function gotoMenu() {
        state = DR_MENU;
        _refreshDailyStatus();
    }

    function modeName() {
        if (menuMode == DR_MODE_CLASSIC) { return "Classic"; }
        if (menuMode == DR_MODE_QUICK)   { return "Quick";   }
        return "Daily";
    }

    // Best score for the currently selected mode (shown in menu).
    function bestForMode() {
        if (menuMode == DR_MODE_CLASSIC) { return bestClassic; }
        if (menuMode == DR_MODE_QUICK)   { return bestQuick;   }
        return bestDaily;
    }

    // ── Lifecycle ───────────────────────────────────────────────
    hidden function _startGame() {
        _refreshDailyStatus();
        var mask = DR_MODE_CLASSIC_MASK;
        if (menuMode == DR_MODE_QUICK) { mask = DR_MODE_QUICK_MASK; }
        if (menuMode == DR_MODE_DAILY) { mask = DR_MODE_DAILY_MASK; }

        // Total rounds = number of bits in the mask (= categories
        // that will be played).
        maxRounds = 0;
        for (var i = 0; i < DR_CAT_COUNT; i++) {
            if ((mask & (1 << i)) != 0) { maxRounds = maxRounds + 1; }
        }

        scores.reset(mask);
        dice.initialRolls = menuRerolls;
        if (menuMode == DR_MODE_DAILY) {
            dice.setSeed(_todaySeed());
        } else {
            dice.clearSeed();
        }
        dice.rollInitial();

        roundsPlayed = 0;
        phase        = DR_PHASE_ROLL;
        rollCursor   = 0;
        scoreCursor  = _firstAvailableCategory();
        state        = DR_PLAY;
    }

    hidden function _firstAvailableCategory() {
        for (var i = 0; i < DR_CAT_COUNT; i++) {
            if (scores.isAvailable(i) && !scores.isUsed(i)) { return i; }
        }
        return 0;
    }

    // ── PLAY navigation ─────────────────────────────────────────
    // PHASE_ROLL positions: 0..4 dice, 5 = ROLL (skipped if no rerolls), 6 = SCORE.
    function navPrev() {
        if (state != DR_PLAY) { return; }
        if (phase == DR_PHASE_ROLL) {
            var i = rollCursor;
            for (var k = 0; k < 8; k++) {
                i = (i + 6) % 7;
                if (_rollPosValid(i)) { rollCursor = i; return; }
            }
        } else {
            var c = scoreCursor;
            for (var n = 0; n < DR_CAT_COUNT; n++) {
                c = (c + DR_CAT_COUNT - 1) % DR_CAT_COUNT;
                if (scores.isAvailable(c) && !scores.isUsed(c)) {
                    scoreCursor = c; return;
                }
            }
        }
    }
    function navNext() {
        if (state != DR_PLAY) { return; }
        if (phase == DR_PHASE_ROLL) {
            var i = rollCursor;
            for (var k = 0; k < 8; k++) {
                i = (i + 1) % 7;
                if (_rollPosValid(i)) { rollCursor = i; return; }
            }
        } else {
            var c = scoreCursor;
            for (var n = 0; n < DR_CAT_COUNT; n++) {
                c = (c + 1) % DR_CAT_COUNT;
                if (scores.isAvailable(c) && !scores.isUsed(c)) {
                    scoreCursor = c; return;
                }
            }
        }
    }
    hidden function _rollPosValid(i) {
        if (i >= 0 && i < DR_DICE_COUNT) { return true; }
        if (i == DR_POS_ROLL)  { return dice.rerollsLeft > 0; }
        if (i == DR_POS_SCORE) { return true; }
        return false;
    }

    function selectAction() {
        if (state != DR_PLAY) { return; }
        if (phase == DR_PHASE_ROLL) {
            if (rollCursor < DR_DICE_COUNT) {
                dice.toggleHold(rollCursor);
            } else if (rollCursor == DR_POS_ROLL) {
                if (dice.reroll() && dice.rerollsLeft == 0
                    && rollCursor == DR_POS_ROLL) {
                    rollCursor = DR_POS_SCORE;
                }
            } else if (rollCursor == DR_POS_SCORE) {
                phase       = DR_PHASE_SCORE;
                scoreCursor = _firstAvailableCategory();
            }
        } else {
            // PHASE_SCORE: commit current category, advance round.
            if (scores.isAvailable(scoreCursor) && !scores.isUsed(scoreCursor)) {
                scores.commit(scoreCursor, dice.dice);
                _advanceRound();
            }
        }
    }

    // Direct selection from tap hit-test (used by MainView).
    function setRollCursor(i) {
        if (state == DR_PLAY && phase == DR_PHASE_ROLL && _rollPosValid(i)) {
            rollCursor = i;
        }
    }
    function setScoreCursor(i) {
        if (state == DR_PLAY && phase == DR_PHASE_SCORE
            && scores.isAvailable(i) && !scores.isUsed(i)) {
            scoreCursor = i;
        }
    }

    hidden function _advanceRound() {
        roundsPlayed = roundsPlayed + 1;
        if (scores.allDone()) {
            _onGameComplete();
            return;
        }
        dice.rollInitial();
        phase      = DR_PHASE_ROLL;
        rollCursor = 0;
    }

    hidden function _onGameComplete() {
        gamesPlayed = gamesPlayed + 1;
        _save(DR_KEY_GAMES, gamesPlayed);

        var final = scores.total;
        if (menuMode == DR_MODE_CLASSIC) {
            if (final > bestClassic) {
                bestClassic = final;
                _save(DR_KEY_BEST_CLASSIC, bestClassic);
            }
        } else if (menuMode == DR_MODE_QUICK) {
            if (final > bestQuick) {
                bestQuick = final;
                _save(DR_KEY_BEST_QUICK, bestQuick);
            }
        } else {
            // Daily completion: record date, score, streak.
            var t = _todaySeed();
            // Yesterday's DOY (rough): consecutive if dailyDate is
            // exactly t-1.  Otherwise streak resets to 1.
            if (dailyDate == t - 1) { streak = streak + 1; }
            else                     { streak = 1; }
            dailyDate = t;
            dailyPlayedToday = true;
            if (final > bestDaily) {
                bestDaily = final;
                _save(DR_KEY_BEST_DAILY, bestDaily);
            }
            _save(DR_KEY_DAILY_DATE, dailyDate);
            _save(DR_KEY_STREAK,     streak);
        }

        // Submit the final scorecard total to the global leaderboard,
        // split by mode variant.
        Leaderboard.submitScore(LB_GAME_ID, final, variantName());
        Leaderboard.showPostGame(LB_GAME_ID, variantName(), "DICE ROYALE");

        state = DR_OVER;
    }

    // ── Helpers exposed to UI ───────────────────────────────────
    // Potential score the player would earn by picking `cat` on the
    // current dice — used to render the scoring screen with previews.
    function previewScore(cat) {
        if (!scores.isAvailable(cat) || scores.isUsed(cat)) { return -1; }
        return scores.score(cat, dice.dice);
    }
}
