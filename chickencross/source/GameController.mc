// ═══════════════════════════════════════════════════════════════
// GameController.mc — Game flow + tick loop.
//
// States:   CS_MENU → CS_PLAY → CS_WIN | CS_OVER → CS_MENU
//
// Menu (chess-style, 3 rows):
//   0  Difficulty (Easy / Normal / Hard)
//   1  Lives (1..5)
//   2  START
//
// Tick (called by MainView's 100 ms timer):
//   1. Advance every obstacle by its lane's speed.
//   2. If the chicken stands on a RIVER row, drift her with the log.
//      Snap-clamp her column to keep the rendering on cells.
//   3. Collision check.
//        RES_DEAD → lose a life, respawn or game over.
//        RES_GOAL → +bonus, restart with chicken at bottom; level += 1.
//        RES_SAFE → nothing.
//
// Player input (queued one move per tick):
//   moveUP / moveLEFT / moveRIGHT / moveDOWN
//
// Difficulty / level scaling:
//   baseSpeed = BASE_BY_DIFF[diff] + 0.012 * (level - 1)
//     Easy   0.06, Normal 0.10, Hard 0.14
//     Capped at 0.32 tiles/tick.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Math;

const CS_MENU = 0;
const CS_PLAY = 1;
const CS_WIN  = 2;
const CS_OVER = 3;

const CC_MENU_ROWS = 4;
const CC_ROW_DIFF  = 0;
const CC_ROW_LIVES = 1;
const CC_ROW_START = 2;
const CC_ROW_LB    = 3;   // shared global leaderboard

const CC_BEST_KEY  = "cc_best";
const CC_DIFF_KEY  = "cc_diff";
const CC_LIVES_KEY = "cc_lives";

// Shared global-leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "chickencross";

const CC_DIFF_EASY   = 0;
const CC_DIFF_NORMAL = 1;
const CC_DIFF_HARD   = 2;

class GameController {
    var state;
    var menuRow;
    var menuDiff;
    var menuLives;

    var lanes;
    var obstacles;
    var player;
    var level;
    var lives;
    var score;
    var bestScore;

    // Hidden tick counter used to scale obstacle motion smoothly.
    hidden var _highestRow;   // chicken's best row this *life*
    hidden var _submitted;    // guards against a double leaderboard submit

    function initialize() {
        state = CS_MENU;
        menuRow   = 0;
        menuDiff  = CC_DIFF_NORMAL;
        menuLives = 3;

        lanes     = LaneManager.buildLanes();
        obstacles = new ObstacleSystem();
        player    = new PlayerChicken();
        level = 1; lives = 3; score = 0; bestScore = 0;
        _highestRow = 0;
        _submitted  = false;
        _loadAll();
    }

    // ── Persistence ──────────────────────────────────────────────
    hidden function _loadAll() {
        try {
            var b = Application.Storage.getValue(CC_BEST_KEY);
            if (b instanceof Number && b >= 0) { bestScore = b; }
        } catch (e) {}
        try {
            var d = Application.Storage.getValue(CC_DIFF_KEY);
            if (d instanceof Number && d >= 0 && d <= 2) { menuDiff = d; }
        } catch (e) {}
        // Lives is stored by the shared OPTIONS screen as an index (0..4);
        // map it to the raw 1..5 lives count.
        try {
            var l = Application.Storage.getValue(CC_LIVES_KEY);
            if (l instanceof Number && l >= 0 && l <= 4) { menuLives = l + 1; }
        } catch (e) {}
    }
    hidden function _saveBest() {
        try { Application.Storage.setValue(CC_BEST_KEY, bestScore); } catch (e) {}
    }
    hidden function _saveSettings() {
        try { Application.Storage.setValue(CC_DIFF_KEY,  menuDiff);  } catch (e) {}
        try { Application.Storage.setValue(CC_LIVES_KEY, menuLives); } catch (e) {}
    }

    // ── Menu actions ─────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % CC_MENU_ROWS; }
    function menuPrev() { menuRow = (menuRow + CC_MENU_ROWS - 1) % CC_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < CC_MENU_ROWS) { menuRow = i; } }
    function menuActivate() {
        if (menuRow == CC_ROW_DIFF) {
            menuDiff = (menuDiff + 1) % 3;
            _saveSettings();
        } else if (menuRow == CC_ROW_LIVES) {
            menuLives = (menuLives % 5) + 1;
            _saveSettings();
        } else if (menuRow == CC_ROW_START) {
            _startGame();
        }
        // CC_ROW_LB is opened by the view (it pushes the leaderboard view).
    }

    function gotoMenu() { state = CS_MENU; }

    // Friendly text for the menu row 0.
    function difficultyName() {
        if (menuDiff == CC_DIFF_EASY)   { return "Easy";   }
        if (menuDiff == CC_DIFF_NORMAL) { return "Normal"; }
        return "Hard";
    }

    // ── Speed scaling ────────────────────────────────────────────
    function levelSpeed() {
        var base;
        if      (menuDiff == CC_DIFF_EASY)   { base = 0.06; }
        else if (menuDiff == CC_DIFF_NORMAL) { base = 0.10; }
        else                                  { base = 0.14; }
        var s = base + 0.012 * (level - 1);
        if (s > 0.32) { s = 0.32; }
        return s;
    }

    // ── Lifecycle ────────────────────────────────────────────────
    // Public entry used by the auto-start view (settings come from Storage).
    function beginGame() { _startGame(); }

    hidden function _startGame() {
        level = 1;
        lives = menuLives;
        score = 0;
        _submitted = false;
        _spawnRound();
        state = CS_PLAY;
    }

    // Submit the final score to the shared global leaderboard exactly once
    // per run (a game ends in either CS_OVER or CS_WIN, never both).
    hidden function _submitToLeaderboard() {
        if (_submitted) { return; }
        _submitted = true;
        Leaderboard.submitScore(LB_GAME_ID, score, "");
        Leaderboard.showPostGame(LB_GAME_ID, "", "CHICKEN CROSS");
    }

    hidden function _spawnRound() {
        player.spawn();
        _highestRow = 0;
        obstacles.populate(lanes, levelSpeed());
    }

    // ── Input intents (called by MainView) ──────────────────────
    function moveUp()    { _playerStep( 1,  0); }
    function moveDown()  { _playerStep(-1,  0); }
    function moveLeft()  { _playerStep( 0, -1); }
    function moveRight() { _playerStep( 0,  1); }

    hidden function _playerStep(dr, dc) {
        if (state != CS_PLAY) { return; }
        if (!player.step(dr, dc)) { return; }
        // Distance score: +10 per new row reached.
        if (player.row > _highestRow) {
            score = score + 10 * (player.row - _highestRow);
            _highestRow = player.row;
        }
        // Resolve the move immediately so the player gets instant
        // feedback even if the next tick is a few frames away.
        _resolve();
    }

    // ── Game tick (100 ms) ──────────────────────────────────────
    function tick() {
        if (state != CS_PLAY) { return; }
        obstacles.tick(lanes);

        // Drift the chicken with the log she's standing on.
        var ln = LaneManager.laneAt(lanes, player.row);
        if (ln != null && ln.type == LANE_RIVER) {
            var dx = obstacles.logDeltaForRow(lanes, player.row);
            player.colFloat = player.colFloat + dx;
            // Update integer col (used by collision/render).
            var c = (player.colFloat + 0.5).toNumber();
            if (c < 0)             { c = 0; }
            if (c >= BOARD_COLS)   { c = BOARD_COLS - 1; }
            player.col = c;
        }
        _resolve();
    }

    hidden function _resolve() {
        if (state != CS_PLAY) { return; }
        var r = CollisionSystem.check(lanes, obstacles, player);
        if (r == RES_DEAD || CollisionSystem.offBoard(player)) { _onDeath(); return; }
        if (r == RES_GOAL) { _onCrossing(); return; }
    }

    // ── Outcomes ────────────────────────────────────────────────
    hidden function _onDeath() {
        lives = lives - 1;
        if (lives <= 0) {
            state = CS_OVER;
            if (score > bestScore) { bestScore = score; _saveBest(); }
            _submitToLeaderboard();
            return;
        }
        _spawnRound();
    }

    hidden function _onCrossing() {
        // Big bonus + speed-ramp via level increment.
        score = score + 200 + level * 50;
        if (level >= 9) {
            state = CS_WIN;
            if (score > bestScore) { bestScore = score; _saveBest(); }
            _submitToLeaderboard();
            return;
        }
        level = level + 1;
        _spawnRound();
    }
}
