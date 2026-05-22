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

const GS_MENU  = 0;
const GS_SETUP = 1;
const GS_AIM   = 2;
const GS_INFO  = 3;
const GS_WIN   = 4;
const GS_LOSE  = 5;

// Menu items
const MI_DIFFICULTY = 0;
const MI_START      = 1;
const MI_ITEMS      = 2;

class GameController {
    var state;

    var playerGrid;       // GridManager — player's ships + AI shots
    var enemyGrid;        // GridManager — enemy ships + player shots
    var playerShips;
    var enemyShips;
    var ai;
    var difficulty;

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

    // Persisted stats
    var winsTotal;

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

        winsTotal    = _loadInt("winsTotal", 0);
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
    function menuActivate() {
        if (menuCursor == MI_DIFFICULTY) {
            difficulty = (difficulty + 1) % 3;
            ai.setDifficulty(difficulty);
        } else if (menuCursor == MI_START) {
            beginSetup();
        }
    }
    function difficultyName() {
        if (difficulty == AI_EASY) { return "Easy"; }
        if (difficulty == AI_MEDIUM){ return "Medium"; }
        return "Hard";
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
        lastPlayerShot = null;
        lastAIShot     = null;
        lastSinkText   = "";
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

    // Fire the player's shot. Drives the full turn through AI response.
    // No-op if the cell was already fired on.
    function playerFire() {
        if (state != GS_AIM) { return; }
        var r = cursor[0];
        var c = cursor[1];
        if (enemyGrid.isShot(r, c)) { return; }   // refuse double-shot

        var pres = BattleLogic.fire(enemyGrid, enemyShips, r, c);
        lastPlayerShot = [r, c, pres.hit, pres.sunkId];
        lastSinkText   = "";
        if (pres.sunkId >= 0) {
            lastSinkText = "Sank " + SHIP_NAMES[pres.sunkId] + "!";
        }

        if (enemyShips.allSunk()) {
            winsTotal = winsTotal + 1;
            _saveInt("winsTotal", winsTotal);
            state = GS_WIN;
            return;
        }

        _resolveAITurn();

        if (playerShips.allSunk()) {
            state = GS_LOSE;
            return;
        }

        state = GS_INFO;
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
            if (lastSinkText.length() == 0) {
                lastSinkText = "Enemy sank " + SHIP_NAMES[ares.sunkId] + "!";
            } else {
                lastSinkText = lastSinkText + " Enemy sank " + SHIP_NAMES[ares.sunkId] + "!";
            }
        }
    }
}
