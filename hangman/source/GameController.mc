// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine + game logic.
//
// States:
//   GS_MENU   pick category + difficulty
//   GS_PLAY   live game — guess letters via on-screen keyboard
//   GS_WIN    word revealed — show full word + best wins
//   GS_LOSE   stick figure complete — show word
//
// Keyboard model:
//   26 letters laid out in a 4×7 grid (last row has fewer slots).
//   Cursor = letter index (0..25). UP/DOWN move by ROW; SELECT moves
//   to the NEXT letter (column right, wrap); HOLD/long-press =
//   guess current letter. Touch tap on a letter = guess directly.
//
// Persistence: total wins counter via Application.Storage.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.System;

const LB_GAME_ID = "hangman";

const GS_MENU = 0;
const GS_PLAY = 1;
const GS_WIN  = 2;
const GS_LOSE = 3;

// Keyboard layout — 7 letters per row, 4 rows (26 total + 2 unused
// slots which we never address).
const KB_COLS = 7;
const KB_ROWS = 4;

// Menu cursor positions
const MENU_CAT    = 0;
const MENU_DIFF   = 1;
const MENU_START  = 2;
const MENU_LB     = 3;
const MENU_ITEMS  = 4;

class GameController {
    var state;

    // Round
    var word;            // String — the secret word
    var revealed;        // 26-bit mask of guessed letters that hit
    var usedMask;        // 26-bit mask of every guessed letter
    var misses;          // count of wrong guesses

    // Settings
    var category;        // CAT_*
    var difficulty;      // DIFF_*

    // Cursor
    var cursor;          // 0..25
    var menuCursor;      // 0..MENU_ITEMS-1

    // Persistent stats
    var totalWins;
    var streak;          // consecutive words solved without a loss

    function initialize() {
        state       = GS_MENU;
        word        = "";
        revealed    = 0;
        usedMask    = 0;
        misses      = 0;
        category    = CAT_ANIMALS;
        difficulty  = DIFF_EASY;
        cursor      = 0;
        menuCursor  = MENU_START;
        totalWins   = _loadWins();
        streak      = _loadStreak();
        _loadSettings();
    }

    hidden function _loadWins() {
        try {
            var v = Application.Storage.getValue("wins");
            if (v != null && v instanceof Number && v > 0) { return v; }
        } catch (e) { }
        return 0;
    }
    hidden function _saveWins() {
        try { Application.Storage.setValue("wins", totalWins); } catch (e) { }
    }
    hidden function _loadStreak() {
        try {
            var v = Application.Storage.getValue("hangman_streak");
            if (v != null && v instanceof Number && v > 0) { return v; }
        } catch (e) { }
        return 0;
    }
    hidden function _saveStreak() {
        try { Application.Storage.setValue("hangman_streak", streak); } catch (e) { }
    }

    // Variant = category+difficulty string, e.g. "animals-hard".
    function variant() {
        return WordList.categoryName(category).toLower() + "-"
             + WordList.difficultyName(difficulty).toLower();
    }
    hidden function _loadSettings() {
        try {
            var c = Application.Storage.getValue("hm_cat");
            if (c instanceof Number && c >= 0 && c < NUM_CATEGORIES) { category = c; }
        } catch (e) {}
        try {
            var d = Application.Storage.getValue("hm_diff");
            if (d instanceof Number && d >= 0 && d < NUM_DIFFICULTIES) { difficulty = d; }
        } catch (e) {}
    }
    hidden function _saveSettings() {
        try { Application.Storage.setValue("hm_cat",  category);   } catch (e) {}
        try { Application.Storage.setValue("hm_diff", difficulty); } catch (e) {}
    }

    // ── Menu actions ────────────────────────────────────────────────
    function cycleCategory()   {
        category = (category + 1) % NUM_CATEGORIES;
        _saveSettings();
    }
    function cycleDifficulty() {
        difficulty = (difficulty + 1) % NUM_DIFFICULTIES;
        _saveSettings();
    }

    function startGame() {
        word     = WordList.randomWord(category, difficulty);
        revealed = 0;
        usedMask = 0;
        misses   = 0;
        cursor   = _firstLetterIndex();    // start cursor on a fresh letter
        state    = GS_PLAY;
    }

    hidden function _firstLetterIndex() {
        // Land on a vowel that's actually in the word if possible —
        // saves the player a few cursor moves on the very first turn.
        var vowels = [0, 4, 8, 14, 20];   // A, E, I, O, U
        for (var i = 0; i < vowels.size(); i++) {
            if (_wordContainsLetter(vowels[i])) { return vowels[i]; }
        }
        return 0;
    }

    function gotoMenu() {
        state = GS_MENU;
    }

    // ── Gameplay ────────────────────────────────────────────────────
    // Move cursor up (dir=-1) or down (dir=+1) by one row.
    // The column stays the same; wraps from row 0 to the last row and
    // vice versa. Clamps to Z on the short last row (only 5 letters).
    function moveCursorVert(dir) {
        var r = cursor / KB_COLS;
        var c = cursor % KB_COLS;
        r = (r + dir + KB_ROWS) % KB_ROWS;
        var idx = r * KB_COLS + c;
        if (idx >= 26) { idx = 25; }
        cursor = idx;
    }

    // Move cursor left (dir=-1) or right (dir=+1) by one letter through
    // the linear A…Z sequence. Wraps: Z → A (right) and A → Z (left).
    function moveCursorHoriz(dir) {
        var next = cursor + dir;
        if (next < 0)   { next = 25; }
        if (next >= 26) { next = 0;  }
        cursor = next;
    }

    // Legacy — kept so existing call sites in the codebase still compile.
    function moveCursor(dr, dc) {
        if (dr != 0) { moveCursorVert(dr); }
        else         { moveCursorHoriz(dc); }
    }

    // Set cursor directly to a letter index (touch tap → letter).
    function setCursor(idx) {
        if (idx < 0 || idx >= 26) { return; }
        cursor = idx;
    }

    function guessCurrent() { _guessIndex(cursor); }
    function guessLetter(idx) { _guessIndex(idx); }

    hidden function _guessIndex(idx) {
        if (state != GS_PLAY) { return; }
        if (idx < 0 || idx >= 26) { return; }
        var bit = 1 << idx;
        if ((usedMask & bit) != 0) { return; }   // already guessed
        usedMask = usedMask | bit;
        if (_wordContainsLetter(idx)) {
            revealed = revealed | bit;
            if (_isFullyRevealed()) {
                state = GS_WIN;
                totalWins = totalWins + 1;
                _saveWins();
                // Win streak: increment, persist, then submit to leaderboard.
                streak = streak + 1;
                _saveStreak();
                Leaderboard.submitScore(LB_GAME_ID, streak, variant());
            }
        } else {
            misses = misses + 1;
            if (misses >= MAX_MISSES) {
                state = GS_LOSE;
                // Failed word breaks the streak.
                streak = 0;
                _saveStreak();
            }
        }
    }

    // ── Helpers exposed to the renderer ─────────────────────────────
    // Returns the masked display string, e.g. "_ A _ T E _".
    function maskedWord() {
        var out = "";
        for (var i = 0; i < word.length(); i++) {
            var ch = word.substring(i, i + 1);
            var idx = _letterIndex(ch);
            if (idx >= 0 && (revealed & (1 << idx)) != 0) {
                if (i > 0) { out = out + " "; }
                out = out + ch;
            } else {
                if (i > 0) { out = out + " "; }
                out = out + "_";
            }
        }
        return out;
    }

    function isGuessed(idx) {
        return (usedMask & (1 << idx)) != 0;
    }
    function isCorrect(idx) {
        return (revealed & (1 << idx)) != 0;
    }

    function attemptsLeft() {
        var n = MAX_MISSES - misses;
        if (n < 0) { n = 0; }
        return n;
    }

    // ── Internals ───────────────────────────────────────────────────
    hidden function _wordContainsLetter(idx) {
        var target = _letterChar(idx);
        for (var i = 0; i < word.length(); i++) {
            if (word.substring(i, i + 1).equals(target)) { return true; }
        }
        return false;
    }

    hidden function _isFullyRevealed() {
        for (var i = 0; i < word.length(); i++) {
            var idx = _letterIndex(word.substring(i, i + 1));
            if (idx < 0) { continue; }
            if ((revealed & (1 << idx)) == 0) { return false; }
        }
        return true;
    }

    // Map "A"..."Z" → 0..25 (or -1 if not a letter)
    static function _letterIndex(ch) {
        if (ch == null || ch.length() == 0) { return -1; }
        var c = ch.toCharArray()[0].toNumber();
        if (c >= 65 && c <= 90) { return c - 65; }
        if (c >= 97 && c <= 122) { return c - 97; }
        return -1;
    }

    // 0..25 → "A".."Z"
    static function _letterChar(i) {
        var arr = ['A','B','C','D','E','F','G','H','I','J',
                   'K','L','M','N','O','P','Q','R','S','T',
                   'U','V','W','X','Y','Z'];
        if (i < 0 || i >= 26) { return "?"; }
        return arr[i].toString();
    }
}
