// ═══════════════════════════════════════════════════════════════
// GameController.mc — Game state machine + persistence.
//
// States:
//   GS_MENU    title screen — START / How to play / Reset best
//   GS_PLAY    live 4×4 game; reacts to swipe directions
//   GS_WIN     2048 reached for the first time this run — player may
//              continue playing for a higher score
//   GS_OVER    no more moves possible
//
// Score:
//   `score`         resets each new run, +sum of merged tile values
//   `best`          highest score ever, persisted via Application.Storage
//   `bestExp`       largest tile reached ever, persisted similarly
//
// Win condition:
//   The first move that creates a 2048 tile transitions to GS_WIN.
//   The player can then return to GS_PLAY to keep going for a
//   higher score. After GS_WIN, further 2048 tiles do not retrigger.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

const GS_MENU = 0;
const GS_PLAY = 1;
const GS_WIN  = 2;
const GS_OVER = 3;

// Menu items
const MI_START       = 0;
const MI_LEADERBOARD = 1;
const MI_RESET_BEST  = 2;
const MI_ITEMS       = 3;

// Leaderboard game id (matches _LOGOS / web id)
const LB_GAME_ID = "twentyfortyeight";

class GameController {
    var state;
    var grid;
    var score;
    var best;
    var bestExp;
    var hasWonThisRun;     // true once player has hit 2048 in current run
    var menuCursor;

    function initialize() {
        state          = GS_MENU;
        grid           = new GridManager();
        score          = 0;
        best           = _loadInt("best",    0);
        bestExp        = _loadInt("bestExp", 0);
        hasWonThisRun  = false;
        menuCursor     = MI_START;
    }

    hidden function _loadInt(key, dflt) {
        try {
            var v = Application.Storage.getValue(key);
            if (v != null && v instanceof Number && v >= 0) { return v; }
        } catch (e) {}
        return dflt;
    }
    hidden function _saveInt(key, v) {
        try { Application.Storage.setValue(key, v); } catch (e) {}
    }

    // ── Menu actions ────────────────────────────────────────────────
    function menuPrev() {
        menuCursor = (menuCursor + MI_ITEMS - 1) % MI_ITEMS;
    }
    function menuNext() {
        menuCursor = (menuCursor + 1) % MI_ITEMS;
    }
    function menuActivate() {
        if (menuCursor == MI_START) {
            newGame();
        } else if (menuCursor == MI_RESET_BEST) {
            best = 0;
            bestExp = 0;
            _saveInt("best",    0);
            _saveInt("bestExp", 0);
        }
    }

    // ── Game flow ───────────────────────────────────────────────────
    function newGame() {
        grid.clear();
        grid.spawnRandom();
        grid.spawnRandom();
        score = 0;
        hasWonThisRun = false;
        state = GS_PLAY;
    }

    function gotoMenu() { state = GS_MENU; }

    // Continue playing after hitting 2048 (one-shot toggle).
    function continueAfterWin() {
        if (state == GS_WIN) { state = GS_PLAY; }
    }

    // ── Swipe handler ───────────────────────────────────────────────
    // Called by InputHandler with one of DIR_*. Applies the move,
    // updates score/best, spawns a tile, and transitions state if a
    // win/loss happened.
    function tryMove(dir) {
        if (state != GS_PLAY) { return; }
        var r = MergeEngine.applyMove(grid, dir);
        if (!r.moved) { return; }

        if (r.gained > 0) {
            score = score + r.gained;
            if (score > best) {
                best = score;
                _saveInt("best", best);
            }
        }

        var top = grid.maxExp();
        if (top > bestExp) {
            bestExp = top;
            _saveInt("bestExp", bestExp);
        }

        // Spawn first, then check for game-over so the player sees
        // the freshly-placed tile on the over screen.
        grid.spawnRandom();

        if (r.reached2048 && !hasWonThisRun) {
            hasWonThisRun = true;
            state = GS_WIN;
            return;
        }

        if (!grid.hasAnyMove()) {
            state = GS_OVER;
            // Submit final score to the global leaderboard (fire-and-forget).
            Leaderboard.submitScore(LB_GAME_ID, score, "");
        }
    }
}
