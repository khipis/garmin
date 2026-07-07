// ═══════════════════════════════════════════════════════════════
// GameController.mc — Top-level state machine + game flow.
//
// States
// ------
//   GS_MENU       Title screen — pick difficulty, START
//   GS_SETUP      Ship placement on the player's board
//                 (manual or auto-place via BACK)
//   GS_AIM        Player aims a shot on the enemy board
//   GS_INFO       Between-turn summary — shows the AI's response
//                 to the player's shot on the player's board. Press
//                 any key to return to GS_AIM.
//   GS_WIN        All enemy ships sunk
//   GS_LOSE       All player ships sunk
//
// Turn execution (single atomic call to `playerFire()`)
//   1. Resolve the player's shot on `enemyGrid`.
//   2. If all enemy ships are sunk → GS_WIN, return.
//   3. Resolve the AI's shot on `playerGrid` (`ai.pickShot` →
//      `BattleLogic.fire` → `ai.onShotResult`).
//   4. If all player ships are sunk → GS_LOSE, return.
//   5. Otherwise transition to GS_INFO so the player can see what
//      just happened on both boards.
//
// Persistence
//   `wins` — total games won, keyed per-difficulty in dictionary
//   `winsTotal` — overall games won across all difficulties
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Math;

const GS_MENU         = 0;
const GS_SETUP        = 1;
const GS_AIM          = 2;
const GS_INFO         = 3;
const GS_WIN          = 4;
const GS_LOSE         = 5;
// Transient animation states.  Driven by a 45 ms timer in MainView
// — the controller's `animAdvance()` counts ticks and chains to the
// next state when the animation completes.
//   GS_FIRE_PLAYER  → render the enemy board with a hit/splash
//                     overlay on the player's shot cell
//   GS_FIRE_AI      → switch to the player board and render the
//                     same overlay on the AI's shot cell
// After GS_FIRE_AI we fall through to GS_INFO (or GS_WIN/LOSE).
const GS_FIRE_PLAYER  = 6;
const GS_FIRE_AI      = 7;

// Total ticks per animation phase.  At 45 ms per tick this is ~630 ms,
// kept deliberately short so the round still feels snappy.  Split into
// three sub-phases: CHARGE (0..4), IMPACT (5..7), SETTLE (8..13).
const ANIM_TICKS = 14;

// Global leaderboard game id — MUST match the backend key exactly.
const LB_GAME_ID = "battleship";

// Menu items
const MI_DIFFICULTY = 0;
const MI_SHOTS      = 1;
const MI_START      = 2;
const MI_LEADERBOARD = 3;
const MI_ITEMS      = 4;

// Shots-per-turn presets (the menu toggles between just these two —
// classic 1-shot rules vs "salvo" rules with three shots per side
// before turns swap).
const SHOTS_SINGLE = 1;
const SHOTS_BURST  = 3;

class GameController {
    var state;

    var playerGrid;       // GridManager — player's ships + AI shots
    var enemyGrid;        // GridManager — enemy ships + player shots
    var playerShips;
    var enemyShips;
    var ai;
    var difficulty;

    // Salvo rules — both sides fire `shotsPerTurn` shots before
    // turns swap.  `playerShotsLeft` and `aiShotsLeft` are counters
    // for the CURRENT burst; reset to `shotsPerTurn` at the start
    // of each side's turn.
    var shotsPerTurn;
    var playerShotsLeft;
    var aiShotsLeft;

    // Cursor on the active grid (board-cell coords)
    var cursor;           // [r, c]
    var menuCursor;

    // Setup state — which ship index we're placing + orientation
    var setupIdx;
    var setupHoriz;       // true → ship extends in +c, false → +r

    // Last-shot bookkeeping (used by UIManager + GS_INFO)
    var lastPlayerShot;   // [r, c, hit, sunkId]
    var lastAIShot;
    var lastSinkText;     // brief flash text e.g. "You sank a Cruiser!"

    // Animation bookkeeping.  `animTick` runs 0..ANIM_TICKS in the
    // two transient fire-states; UIManager reads it to render the
    // charge → impact → settle overlay on the shot cell.
    var animTick;

    // Persisted stats
    var winsTotal;

    // Leaderboard metric — number of player shots taken this match.
    // Counts EVERY player shot (hit or miss); lower is better. Reset at
    // the start of each match (beginSetup) and submitted on a player win.
    var shotCount;

    function initialize() {
        playerGrid   = new GridManager();
        enemyGrid    = new GridManager();
        playerShips  = new ShipManager();
        enemyShips   = new ShipManager();
        ai           = new AIController();
        difficulty   = AI_MEDIUM;
        ai.setDifficulty(difficulty);

        cursor       = [0, 0];
        menuCursor   = MI_START;
        setupIdx     = 0;
        setupHoriz   = true;
        lastPlayerShot = null;
        lastAIShot     = null;
        lastSinkText   = "";
        animTick       = 0;
        shotCount      = 0;

        winsTotal    = _loadInt("winsTotal", 0);
        difficulty   = _loadInt("bs_diff", AI_MEDIUM);
        if (difficulty < 0 || difficulty > 2) { difficulty = AI_MEDIUM; }
        ai.setDifficulty(difficulty);

        // Shots preset is stored by the shared OPTIONS screen as an index
        // (0 = single, 1 = burst) — map it to the raw shots-per-turn count.
        var shotsIdx = _loadInt("bs_shots", 0);
        shotsPerTurn = (shotsIdx == 1) ? SHOTS_BURST : SHOTS_SINGLE;
        playerShotsLeft = shotsPerTurn;
        aiShotsLeft     = 0;

        state        = GS_MENU;
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
    // Returns true when the activated row needs the view layer to open
    // the leaderboard panel (the controller can't push WatchUi views).
    function menuActivate() {
        if (menuCursor == MI_DIFFICULTY) {
            difficulty = (difficulty + 1) % 3;
            ai.setDifficulty(difficulty);
            _saveInt("bs_diff", difficulty);
        } else if (menuCursor == MI_SHOTS) {
            shotsPerTurn = (shotsPerTurn == SHOTS_SINGLE)
                            ? SHOTS_BURST : SHOTS_SINGLE;
            _saveInt("bs_shots", shotsPerTurn);
        } else if (menuCursor == MI_START) {
            beginSetup();
        } else if (menuCursor == MI_LEADERBOARD) {
            return true;
        }
        return false;
    }
    function difficultyName() {
        if (difficulty == AI_EASY) { return "Easy"; }
        if (difficulty == AI_MEDIUM){ return "Medium"; }
        return "Hard";
    }
    function shotsName() {
        return (shotsPerTurn == SHOTS_BURST) ? "Burst x3" : "Single";
    }
    // Leaderboard variant — AI difficulty as a lowercase string so each
    // difficulty keeps its own ranking. MUST be identical in submitScore
    // and the LbScoresView opened from the menu.
    function lbVariant() {
        if (difficulty == AI_EASY)   { return "easy"; }
        if (difficulty == AI_MEDIUM) { return "medium"; }
        return "hard";
    }

    // ── Setup phase ─────────────────────────────────────────────────
    function beginSetup() {
        playerGrid.clear();
        enemyGrid.clear();
        playerShips.reset();
        enemyShips.reset();
        ai.reset();
        // AI's ships are auto-placed at game start; player places by hand.
        BattleLogic.autoPlace(enemyGrid, enemyShips);
        setupIdx   = 0;
        setupHoriz = true;
        cursor     = [0, 0];
        lastPlayerShot   = null;
        lastAIShot       = null;
        lastSinkText     = "";
        playerShotsLeft  = shotsPerTurn;
        aiShotsLeft      = 0;
        shotCount        = 0;          // fresh move counter for this match
        state      = GS_SETUP;
    }

    function setupMoveCursor(dr, dc) {
        var r = cursor[0] + dr;
        var c = cursor[1] + dc;
        if (r < 0) { r = 0; }
        if (c < 0) { c = 0; }
        if (r >= GRID_SIZE) { r = GRID_SIZE - 1; }
        if (c >= GRID_SIZE) { c = GRID_SIZE - 1; }
        cursor = [r, c];
    }

    function setupRotate() {
        setupHoriz = !setupHoriz;
        _clampCursorForShip();
    }

    // Swipe gestures set the orientation explicitly + snap the cursor
    // so the ship always fits.
    function setupOrientHoriz() {
        setupHoriz = true;
        _clampCursorForShip();
    }
    function setupOrientVert() {
        setupHoriz = false;
        _clampCursorForShip();
    }

    // DOWN button — walk the cursor one row downward, wrapping within
    // the current orientation's valid range so the ship always fits.
    //   Vertical  : r wraps 0..(8-len)
    //   Horizontal: r wraps 0..7
    function setupStepDown() {
        var len  = SHIP_LENS[setupIdx];
        var maxR = setupHoriz ? (GRID_SIZE - 1) : (GRID_SIZE - len);
        if (maxR < 0) { maxR = 0; }
        var r = cursor[0] + 1;
        if (r > maxR) { r = 0; }
        cursor = [r, cursor[1]];
    }

    // UP / middle-left button — walk the cursor one column rightward,
    // wrapping within the current orientation's valid range.
    //   Horizontal: c wraps 0..(8-len)
    //   Vertical  : c wraps 0..7
    function setupStepRight() {
        var len  = SHIP_LENS[setupIdx];
        var maxC = setupHoriz ? (GRID_SIZE - len) : (GRID_SIZE - 1);
        if (maxC < 0) { maxC = 0; }
        var c = cursor[1] + 1;
        if (c > maxC) { c = 0; }
        cursor = [cursor[0], c];
    }

    // Public setter used by tap-to-place. Snaps the tap position so
    // the ship will fit on the grid in its current orientation.
    function setupSetCursor(r, c) {
        if (r < 0) { r = 0; }
        if (c < 0) { c = 0; }
        if (r >= GRID_SIZE) { r = GRID_SIZE - 1; }
        if (c >= GRID_SIZE) { c = GRID_SIZE - 1; }
        cursor = [r, c];
        _clampCursorForShip();
    }

    // Ensure the cursor + current ship still fit inside the grid
    // after an orientation change. Called from rotate / step helpers.
    hidden function _clampCursorForShip() {
        var len = SHIP_LENS[setupIdx];
        var r = cursor[0];
        var c = cursor[1];
        if (setupHoriz) {
            var maxC = GRID_SIZE - len; if (maxC < 0) { maxC = 0; }
            if (c > maxC) { c = maxC; }
        } else {
            var maxR = GRID_SIZE - len; if (maxR < 0) { maxR = 0; }
            if (r > maxR) { r = maxR; }
        }
        cursor = [r, c];
    }

    // Returns true if the current ship fits at the cursor in the
    // current orientation — used by UIManager to ghost-tint preview.
    function setupCanPlace() {
        var len = SHIP_LENS[setupIdx];
        return playerGrid.canPlace(cursor[0], cursor[1], len, setupHoriz);
    }

    // SELECT in setup → place ship; on last ship → transition to AIM.
    function setupConfirm() {
        if (!setupCanPlace()) { return false; }
        playerGrid.placeShip(cursor[0], cursor[1],
                             SHIP_LENS[setupIdx], setupHoriz, setupIdx);
        setupIdx = setupIdx + 1;
        if (setupIdx >= NUM_SHIPS) {
            cursor = [GRID_SIZE / 2, GRID_SIZE / 2];
            state  = GS_AIM;
        }
        return true;
    }

    // BACK in setup → auto-place EVERYTHING and skip to AIM.
    function setupAuto() {
        BattleLogic.autoPlace(playerGrid, playerShips);
        setupIdx = NUM_SHIPS;
        cursor   = [GRID_SIZE / 2, GRID_SIZE / 2];
        state    = GS_AIM;
    }

    // ── Battle phase ────────────────────────────────────────────────
    function aimMoveCursor(dr, dc) {
        var r = cursor[0] + dr;
        var c = cursor[1] + dc;
        if (r < 0) { r = 0; }
        if (c < 0) { c = 0; }
        if (r >= GRID_SIZE) { r = GRID_SIZE - 1; }
        if (c >= GRID_SIZE) { c = GRID_SIZE - 1; }
        cursor = [r, c];
    }

    // Mirror of setupStepVertical / setupStepHorizontal — single-axis
    // wrap-around cursor walk for the aim grid.
    function aimStepDown() {
        var r = cursor[0] + 1;
        if (r >= GRID_SIZE) { r = 0; }
        cursor = [r, cursor[1]];
    }
    function aimStepRight() {
        var c = cursor[1] + 1;
        if (c >= GRID_SIZE) { c = 0; }
        cursor = [cursor[0], c];
    }

    // Set cursor directly (touch).
    function aimSetCursor(r, c) {
        if (r < 0 || c < 0 || r >= GRID_SIZE || c >= GRID_SIZE) { return; }
        cursor = [r, c];
    }

    // Fire the player's shot.  Resolves the player's hit/miss
    // immediately and enters the GS_FIRE_PLAYER animation state.
    //
    // Salvo handling:
    //   • At the START of a new burst (playerShotsLeft == shotsPerTurn)
    //     we wipe lastSinkText so it summarises only this turn.
    //   • Mid-burst we APPEND sink notifications so the eventual
    //     GS_INFO screen shows everything the player did before the
    //     AI's response — e.g. "Sank Cruiser! Sank Sub!".
    //   • playerShotsLeft is decremented here.  animAdvance() decides
    //     whether to loop back into GS_AIM (more shots in the burst)
    //     or hand turn to the AI (burst spent).
    function playerFire() {
        if (state != GS_AIM) { return; }
        if (playerShotsLeft <= 0) { return; }
        var r = cursor[0];
        var c = cursor[1];
        if (enemyGrid.isShot(r, c)) { return; }   // refuse double-shot

        var pres = BattleLogic.fire(enemyGrid, enemyShips, r, c);
        lastPlayerShot = [r, c, pres.hit, pres.sunkId];
        shotCount = shotCount + 1;     // leaderboard metric (lower = better)

        if (playerShotsLeft == shotsPerTurn) {
            // First shot of a fresh player burst — clear residue from
            // last turn's sink log.
            lastSinkText = "";
        }
        if (pres.sunkId >= 0) {
            var msg = "Sank " + SHIP_NAMES[pres.sunkId] + "!";
            lastSinkText = (lastSinkText.length() == 0)
                            ? msg
                            : (lastSinkText + " " + msg);
        }
        playerShotsLeft = playerShotsLeft - 1;
        animTick = 0;
        state    = GS_FIRE_PLAYER;
    }

    // Animation driver — called every 45 ms by MainView's timer
    // while we're in GS_FIRE_PLAYER or GS_FIRE_AI.  When a phase
    // finishes we chain into the next state.  This is what makes
    // the player see the enemy board light up, then the player
    // board light up, before the GS_INFO summary appears.
    function animAdvance() {
        if (state != GS_FIRE_PLAYER && state != GS_FIRE_AI) { return; }
        animTick++;
        if (animTick < ANIM_TICKS) { return; }

        if (state == GS_FIRE_PLAYER) {
            // Player shot just finished animating on the enemy board.
            //
            // Order matters:
            //   1. Did this shot sink the last enemy ship? → WIN.
            //   2. Is the player still in the middle of a burst? →
            //      loop back to GS_AIM so they can fire the next
            //      shot.  (No AI yet — that's the point of "salvo".)
            //   3. Burst spent → seed AI burst counter to (shots-1),
            //      resolve its first shot, kick off GS_FIRE_AI anim.
            if (enemyShips.allSunk()) {
                winsTotal = winsTotal + 1;
                _saveInt("winsTotal", winsTotal);
                // Player WIN — submit raw positive move count. Backend
                // sorts this game ASCENDING (fewer shots = better), so we
                // do NOT negate. Variant = AI difficulty.
                Leaderboard.submitScore(LB_GAME_ID, shotCount, lbVariant());
                Leaderboard.showPostGame(LB_GAME_ID, lbVariant(), "BATTLESHIP");
                playerShotsLeft = shotsPerTurn;   // for next game
                state = GS_WIN;
                return;
            }
            if (playerShotsLeft > 0) {
                state = GS_AIM;
                return;
            }
            // Player burst is spent — AI's turn.
            aiShotsLeft = shotsPerTurn - 1;       // remaining after this one
            _resolveAITurn();
            animTick = 0;
            state    = GS_FIRE_AI;
            return;
        }

        // GS_FIRE_AI just finished animating on the player board.
        if (playerShips.allSunk()) {
            playerShotsLeft = shotsPerTurn;       // for next game
            state = GS_LOSE;
            return;
        }
        if (aiShotsLeft > 0) {
            // AI still has shots in this burst — fire the next one,
            // restart the anim on the player board.
            aiShotsLeft = aiShotsLeft - 1;
            _resolveAITurn();
            animTick = 0;
            state    = GS_FIRE_AI;
            return;
        }
        // Both sides have fired their bursts — refill player counter
        // and surface the round summary.
        playerShotsLeft = shotsPerTurn;
        state = GS_INFO;
    }

    // True while a fire animation is playing — used by MainView to
    // decide whether to keep the 45 ms timer alive.
    function isFiring() {
        return (state == GS_FIRE_PLAYER || state == GS_FIRE_AI);
    }

    // Player presses any key on the GS_INFO screen → back to aiming.
    function infoContinue() {
        if (state == GS_INFO) { state = GS_AIM; }
    }

    // Win/Lose → back to menu.
    function gotoMenu() {
        state = GS_MENU;
    }

    // ── AI turn ─────────────────────────────────────────────────────
    hidden function _resolveAITurn() {
        var shot = ai.pickShot(playerGrid);
        var r = shot[0];
        var c = shot[1];
        var ares = BattleLogic.fire(playerGrid, playerShips, r, c);

        // Build the sunk-ship cell list if applicable so the AI can
        // prune its hit memory.
        var sunkCells = null;
        if (ares.sunkId >= 0) {
            sunkCells = playerGrid.cellsForShip(ares.sunkId);
        }
        ai.onShotResult(r, c, ares, sunkCells);

        lastAIShot = [r, c, ares.hit, ares.sunkId];
        if (ares.sunkId >= 0) {
            var msg = "Enemy sank " + SHIP_NAMES[ares.sunkId] + "!";
            lastSinkText = (lastSinkText.length() == 0)
                            ? msg
                            : (lastSinkText + " " + msg);
        }
    }
}
