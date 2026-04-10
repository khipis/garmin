using Toybox.Math;
using Toybox.Application;

// ─────────────────────────────────────────────────────────────────────────────
//  ColorPopGame  –  all match-3 logic
//
//  Grid cell encoding (Number):
//    0          = empty
//    1-5        = normal gem color (RED ORANGE GREEN BLUE PURPLE)
//    10-14      = BOMB gem  (color = value - 9,  4-in-a-row reward)
//    20-24      = STAR gem  (color = value - 19, 5-in-a-row reward, clears color)
//    30-34      = CROSS gem (color = value - 29, clears full row+col)
//    50         = RAINBOW gem (wildcard, matches any color, clears 3×3 on match)
//
//  Power-gem creation rules:
//    match of exactly 4  → center tile becomes BOMB (explodes 3×3)
//    match of exactly 5  → STAR (clears all tiles of same color)
//    match of 6+         → CROSS (clears entire row AND column)
//    two power gems matched together → RAINBOW bomb (3×3 + row + col wipe)
//
//  Level progression:
//    Each level has a score target; meeting it advances level.
//    Fewer colors are available on early levels (level 1-2: 4 colors,
//    level 3+: 5 colors).  Move count decreases with level.
//    Level 5+: CROSS gems can appear naturally in spawns.
//    Level 8+: RAINBOW gems can appear naturally in spawns (rare).
// ─────────────────────────────────────────────────────────────────────────────

// Grid size
const CP_COLS = 5;
const CP_ROWS = 6;
const CP_CELLS = 30;  // CP_ROWS * CP_COLS

// Gem types
const GEM_EMPTY    = 0;
// normal: 1-5
const GEM_BOMB_OFF = 9;   // bomb color = value - GEM_BOMB_OFF
const GEM_STAR_OFF = 19;  // star color = value - GEM_STAR_OFF
const GEM_CROSS_OFF = 29; // cross color = value - GEM_CROSS_OFF
const GEM_RAINBOW  = 50;

// Level config arrays (index = level-1, capped at 9)
// score targets per level
const LVL_TARGETS = [200, 450, 800, 1300, 2000, 3000, 4500, 6500, 9000, 12000];
// moves per level
const LVL_MOVES   = [20, 18, 16, 15, 14, 13, 12, 12, 12, 12];

class ColorPopGame {

    // Grid: flat array [row*CP_COLS + col]
    var grid;

    // Game state
    var score;
    var level;
    var movesLeft;
    var combo;        // current chain depth (resets each player swap)
    var totalCombo;   // highest chain this level
    var best;         // best score ever

    // Level progress
    var levelTarget;  // score needed to advance
    var levelBase;    // score at start of this level

    // Flags
    var needsFill;    // grid needs cascade fill (processing)
    var levelUp;      // just advanced (show banner)
    var gameOver;     // no moves left and target not reached
    var levelClear;   // target reached, waiting for player tap to advance
    var numColors;    // active colors for current level

    function initialize() {
        grid = new [CP_CELLS];
        score = 0; level = 1; combo = 0; totalCombo = 0;
        levelBase = 0;
        needsFill = false; levelUp = false;
        gameOver = false; levelClear = false;

        best = Application.Storage.getValue("cp_best");
        if (best == null) { best = 0; }

        startLevel(1);
    }

    function startLevel(lvl) {
        level    = lvl;
        var idx  = lvl - 1; if (idx > 9) { idx = 9; }
        movesLeft = LVL_MOVES[idx];
        levelTarget = LVL_TARGETS[idx];
        levelBase   = score;
        combo        = 0;
        gameOver     = false;
        levelClear   = false;
        levelUp      = false;

        numColors = (lvl <= 2) ? 4 : 5;

        fillBoard();
        // Guarantee no initial matches
        resolveAllMatches(false);
        fillBoard();
    }

    // ── Board filling ─────────────────────────────────────────────────────────

    function fillBoard() {
        for (var i = 0; i < CP_CELLS; i++) {
            if (grid[i] == GEM_EMPTY) {
                grid[i] = randomGem();
            }
        }
    }

    function randomGem() {
        // Normal gem spawn — occasionally spawn power gems at higher levels
        var r = (Math.rand() % 100).toNumber();
        if (level >= 8 && r < 2) { return GEM_RAINBOW; }
        if (level >= 5 && r < 4) {
            var c = 1 + (Math.rand() % numColors).toNumber();
            return GEM_CROSS_OFF + c;
        }
        if (level >= 3 && r < 6) {
            var c2 = 1 + (Math.rand() % numColors).toNumber();
            return GEM_BOMB_OFF + c2;
        }
        return 1 + (Math.rand() % numColors).toNumber();
    }

    // ── Gem color extraction ──────────────────────────────────────────────────

    function gemColor(v) {
        if (v >= 1 && v <= 5) { return v; }
        if (v >= 10 && v <= 14) { return v - GEM_BOMB_OFF; }
        if (v >= 20 && v <= 24) { return v - GEM_STAR_OFF; }
        if (v >= 30 && v <= 34) { return v - GEM_CROSS_OFF; }
        if (v == GEM_RAINBOW)   { return 0; }  // 0 = wildcard
        return -1;
    }

    function gemType(v) {
        if (v == GEM_EMPTY)             { return 0; }
        if (v >= 1 && v <= 5)           { return 1; }  // normal
        if (v >= 10 && v <= 14)         { return 2; }  // bomb
        if (v >= 20 && v <= 24)         { return 3; }  // star
        if (v >= 30 && v <= 34)         { return 4; }  // cross
        if (v == GEM_RAINBOW)           { return 5; }  // rainbow
        return 0;
    }

    function colorsMatch(a, b) {
        if (a == GEM_EMPTY || b == GEM_EMPTY) { return false; }
        var ca = gemColor(a); var cb = gemColor(b);
        if (ca == 0 || cb == 0) { return true; }  // rainbow matches anything
        return ca == cb;
    }

    // ── Swap ─────────────────────────────────────────────────────────────────

    // Attempt a swap. Returns true if valid (produced a match or power gem).
    function trySwap(r1, c1, r2, c2) {
        if (r1 < 0 || r1 >= CP_ROWS || c1 < 0 || c1 >= CP_COLS) { return false; }
        if (r2 < 0 || r2 >= CP_ROWS || c2 < 0 || c2 >= CP_COLS) { return false; }
        var i1 = r1 * CP_COLS + c1; var i2 = r2 * CP_COLS + c2;
        var tmp = grid[i1]; grid[i1] = grid[i2]; grid[i2] = tmp;

        // Check if swap creates any match
        var marked = new [CP_CELLS]; for (var i = 0; i < CP_CELLS; i++) { marked[i] = false; }
        findMatches(marked);
        var hasMatch = false;
        for (var i = 0; i < CP_CELLS; i++) { if (marked[i]) { hasMatch = true; break; } }

        if (!hasMatch) {
            // Revert
            tmp = grid[i1]; grid[i1] = grid[i2]; grid[i2] = tmp;
            return false;
        }

        movesLeft--;
        combo = 0;
        processMatches(marked, r1, c1, r2, c2);
        return true;
    }

    // ── Match finding ─────────────────────────────────────────────────────────

    // Mark all cells that are part of a match-3+ (writes true into marked[])
    function findMatches(marked) {
        // Horizontal
        for (var r = 0; r < CP_ROWS; r++) {
            for (var c = 0; c <= CP_COLS - 3; c++) {
                var v = grid[r * CP_COLS + c];
                if (v == GEM_EMPTY) { continue; }
                var len = 1;
                while (c + len < CP_COLS && colorsMatch(v, grid[r * CP_COLS + c + len])) { len++; }
                if (len >= 3) {
                    for (var k = 0; k < len; k++) { marked[r * CP_COLS + c + k] = true; }
                }
            }
        }
        // Vertical
        for (var c2 = 0; c2 < CP_COLS; c2++) {
            for (var r2 = 0; r2 <= CP_ROWS - 3; r2++) {
                var v2 = grid[r2 * CP_COLS + c2];
                if (v2 == GEM_EMPTY) { continue; }
                var len2 = 1;
                while (r2 + len2 < CP_ROWS && colorsMatch(v2, grid[(r2 + len2) * CP_COLS + c2])) { len2++; }
                if (len2 >= 3) {
                    for (var k2 = 0; k2 < len2; k2++) { marked[(r2 + k2) * CP_COLS + c2] = true; }
                }
            }
        }
    }

    // Count contiguous match length through a cell (used for power gem reward)
    function matchLenAt(r, c, horiz) {
        var v = grid[r * CP_COLS + c]; var len = 1;
        if (horiz) {
            var cc = c - 1;
            while (cc >= 0 && colorsMatch(v, grid[r * CP_COLS + cc])) { cc--; len++; }
            cc = c + 1;
            while (cc < CP_COLS && colorsMatch(v, grid[r * CP_COLS + cc])) { cc++; len++; }
        } else {
            var rr = r - 1;
            while (rr >= 0 && colorsMatch(v, grid[rr * CP_COLS + c])) { rr--; len++; }
            rr = r + 1;
            while (rr < CP_ROWS && colorsMatch(v, grid[rr * CP_COLS + c])) { rr++; len++; }
        }
        return len;
    }

    // ── Match processing ──────────────────────────────────────────────────────

    function processMatches(marked, swapR1, swapC1, swapR2, swapC2) {
        combo++;
        if (combo > totalCombo) { totalCombo = combo; }

        // Determine power gem rewards before clearing
        var reward1 = calcReward(swapR1, swapC1);
        var reward2 = calcReward(swapR2, swapC2);

        // Score: 50 pts per cleared gem, combo multiplier
        var cleared = 0;
        for (var i = 0; i < CP_CELLS; i++) { if (marked[i]) { cleared++; } }
        var pts = cleared * 50 * combo;
        score += pts;

        // Activate power gems that are being cleared
        for (var i = 0; i < CP_CELLS; i++) {
            if (marked[i]) {
                var t = gemType(grid[i]);
                if (t == 2) { activateBomb(i / CP_COLS, i % CP_COLS, marked); }
                else if (t == 3) { activateStar(gemColor(grid[i]), marked); }
                else if (t == 4) { activateCross(i / CP_COLS, i % CP_COLS, marked); }
                else if (t == 5) { activateRainbow(i / CP_COLS, i % CP_COLS, marked); }
            }
        }

        // Clear marked cells
        for (var i2 = 0; i2 < CP_CELLS; i2++) {
            if (marked[i2]) { grid[i2] = GEM_EMPTY; }
        }

        // Place power gem rewards at swap positions
        if (reward1 > 1 && grid[swapR1 * CP_COLS + swapC1] == GEM_EMPTY) {
            grid[swapR1 * CP_COLS + swapC1] = reward1;
        }
        if (reward2 > 1 && reward2 != reward1 && grid[swapR2 * CP_COLS + swapC2] == GEM_EMPTY) {
            grid[swapR2 * CP_COLS + swapC2] = reward2;
        }

        // Gravity: tiles fall down
        gravity();
        fillBoard();

        // Check for cascade
        var next = new [CP_CELLS]; for (var i3 = 0; i3 < CP_CELLS; i3++) { next[i3] = false; }
        findMatches(next);
        var hasCascade = false;
        for (var i4 = 0; i4 < CP_CELLS; i4++) { if (next[i4]) { hasCascade = true; break; } }

        if (hasCascade) {
            processMatches(next, -1, -1, -1, -1);
        } else {
            combo = 0;
            checkLevelProgress();
        }
    }

    // Determine what power gem a matched cell at (r,c) earns (0 = none)
    hidden function calcReward(r, c) {
        if (r < 0 || c < 0) { return 0; }
        var v = grid[r * CP_COLS + c];
        if (gemType(v) != 1) { return 0; }  // only normal gems earn rewards
        var col = gemColor(v);
        var hLen = matchLenAt(r, c, true);
        var vLen = matchLenAt(r, c, false);
        var maxLen = (hLen > vLen) ? hLen : vLen;

        if (maxLen >= 6) { return GEM_CROSS_OFF + col; }
        if (maxLen == 5) { return GEM_STAR_OFF  + col; }
        if (maxLen == 4) { return GEM_BOMB_OFF  + col; }
        return 0;
    }

    // ── Power gem activations ─────────────────────────────────────────────────

    hidden function activateBomb(r, c, marked) {
        for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
                var nr = r + dr; var nc = c + dc;
                if (nr >= 0 && nr < CP_ROWS && nc >= 0 && nc < CP_COLS) {
                    marked[nr * CP_COLS + nc] = true;
                }
            }
        }
    }

    hidden function activateStar(color, marked) {
        for (var i = 0; i < CP_CELLS; i++) {
            if (color == 0 || gemColor(grid[i]) == color) { marked[i] = true; }
        }
    }

    hidden function activateCross(r, c, marked) {
        for (var cc = 0; cc < CP_COLS; cc++) { marked[r * CP_COLS + cc] = true; }
        for (var rr = 0; rr < CP_ROWS; rr++) { marked[rr * CP_COLS + c]  = true; }
    }

    hidden function activateRainbow(r, c, marked) {
        activateBomb(r, c, marked);
        activateCross(r, c, marked);
    }

    // ── Resolve initial matches (called at board setup to remove pre-made matches) ──

    function resolveAllMatches(score_them) {
        var found = true;
        while (found) {
            var marked = new [CP_CELLS]; for (var i = 0; i < CP_CELLS; i++) { marked[i] = false; }
            findMatches(marked);
            found = false;
            for (var i2 = 0; i2 < CP_CELLS; i2++) {
                if (marked[i2]) { grid[i2] = GEM_EMPTY; found = true; }
            }
            if (found) { fillBoard(); }
        }
    }

    // ── Gravity ───────────────────────────────────────────────────────────────

    function gravity() {
        for (var c = 0; c < CP_COLS; c++) {
            var writeRow = CP_ROWS - 1;
            for (var r = CP_ROWS - 1; r >= 0; r--) {
                if (grid[r * CP_COLS + c] != GEM_EMPTY) {
                    grid[writeRow * CP_COLS + c] = grid[r * CP_COLS + c];
                    if (writeRow != r) { grid[r * CP_COLS + c] = GEM_EMPTY; }
                    writeRow--;
                }
            }
            while (writeRow >= 0) {
                grid[writeRow * CP_COLS + c] = GEM_EMPTY;
                writeRow--;
            }
        }
    }

    // ── Level progression ─────────────────────────────────────────────────────

    hidden function checkLevelProgress() {
        var levelScore = score - levelBase;
        if (levelScore >= levelTarget) {
            levelClear = true;
            if (score > best) {
                best = score;
                Application.Storage.setValue("cp_best", best);
            }
        } else if (movesLeft <= 0) {
            gameOver = true;
            if (score > best) {
                best = score;
                Application.Storage.setValue("cp_best", best);
            }
        }
    }

    function advanceLevel() {
        levelClear = false;
        startLevel(level + 1);
    }

    // Returns true if there are any possible moves on the board
    function hasMoves() {
        // Try all horizontal and vertical adjacent swaps
        for (var r = 0; r < CP_ROWS; r++) {
            for (var c = 0; c < CP_COLS; c++) {
                if (c + 1 < CP_COLS) {
                    var i1 = r * CP_COLS + c; var i2 = r * CP_COLS + c + 1;
                    var tmp = grid[i1]; grid[i1] = grid[i2]; grid[i2] = tmp;
                    var marked = new [CP_CELLS]; for (var i = 0; i < CP_CELLS; i++) { marked[i] = false; }
                    findMatches(marked);
                    tmp = grid[i1]; grid[i1] = grid[i2]; grid[i2] = tmp;
                    for (var i3 = 0; i3 < CP_CELLS; i3++) { if (marked[i3]) { return true; } }
                }
                if (r + 1 < CP_ROWS) {
                    var i4 = r * CP_COLS + c; var i5 = (r + 1) * CP_COLS + c;
                    var tmp2 = grid[i4]; grid[i4] = grid[i5]; grid[i5] = tmp2;
                    var marked2 = new [CP_CELLS]; for (var i6 = 0; i6 < CP_CELLS; i6++) { marked2[i6] = false; }
                    findMatches(marked2);
                    tmp2 = grid[i4]; grid[i4] = grid[i5]; grid[i5] = tmp2;
                    for (var i7 = 0; i7 < CP_CELLS; i7++) { if (marked2[i7]) { return true; } }
                }
            }
        }
        return false;
    }

    // Human-readable formatting
    function fmt(n) {
        if (n >= 1000) { return (n / 1000) + "K"; }
        return n + "";
    }
}
