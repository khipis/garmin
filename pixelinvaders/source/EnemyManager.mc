// ═══════════════════════════════════════════════════════════════
// EnemyManager.mc — The descending formation.
//
// Classic SI march pattern:
//   • Every `stepInterval` ticks the whole formation steps one
//     cell horizontally in `direction`.
//   • Before stepping we check whether any alive enemy is
//     already at the screen edge in that direction; if so the
//     formation drops one row and reverses direction instead.
//   • As enemies are destroyed `stepInterval` shrinks toward the
//     minimum (kill-the-last alien = furious tempo).
//   • Each step toggles the walk-cycle phase so the sprites can
//     "wiggle" in UIManager.
//
// Formation layout (PI_FORM_ROWS × PI_FORM_COLS):
//   row 0  → EI_BOSS  (back row, 30 pts)
//   row 1  → EI_GUARD (middle, 20 pts)
//   row 2+ → EI_DRONE (front, 10 pts)
//
// `fireFromRandom()` returns the (col, row) of the lowest enemy
// in a randomly-chosen non-empty column, so enemy bullets always
// start from the front edge of the formation.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const PI_FORM_ROWS    = 4;
const PI_FORM_COLS    = 7;
const PI_FORM_TOTAL   = 28;       // 4 × 7
const PI_FORM_TOP     = 1;
const PI_FORM_LEFT    = 1;

const EI_DRONE = 0;
const EI_GUARD = 1;
const EI_BOSS  = 2;

class Enemy {
    var col;
    var row;
    var type;
    var alive;

    function initialize(c, r, t) { col = c; row = r; type = t; alive = true; }
}

class EnemyManager {
    var enemies;
    var direction;       // +1 right, -1 left
    var stepInterval;    // base tick gap between formation steps
    var stepTimer;       // counts down to next step
    var walkPhase;       // 0/1 — flipped each step
    var baseInterval;    // immutable per-wave start
    var startCount;      // total enemies at wave start

    function initialize() {
        enemies = [];
        direction = 1;
        stepInterval = 12;
        stepTimer = stepInterval;
        walkPhase = 0;
        baseInterval = 12;
        startCount = PI_FORM_TOTAL;
    }

    function reset() {
        enemies = []; direction = 1; walkPhase = 0;
    }

    function populate(wave, base) {
        reset();
        baseInterval = base;
        stepInterval = base;
        stepTimer    = base;
        startCount   = PI_FORM_TOTAL;
        direction    = 1;
        walkPhase    = 0;
        // Layout: 4 rows × 7 enemies.
        for (var r = 0; r < PI_FORM_ROWS; r++) {
            var t;
            if      (r == 0) { t = EI_BOSS;  }
            else if (r == 1) { t = EI_GUARD; }
            else              { t = EI_DRONE; }
            for (var c = 0; c < PI_FORM_COLS; c++) {
                enemies.add(new Enemy(PI_FORM_LEFT + c,
                                       PI_FORM_TOP  + r, t));
            }
        }
        // Higher waves start closer to the player.
        var drop = (wave - 1) / 2;        // +1 row every 2 waves
        if (drop > 3) { drop = 3; }
        for (var i = 0; i < enemies.size(); i++) {
            enemies[i].row = enemies[i].row + drop;
        }
    }

    // Number of alive enemies.
    function aliveCount() {
        var n = 0;
        for (var i = 0; i < enemies.size(); i++) {
            if (enemies[i].alive) { n = n + 1; }
        }
        return n;
    }

    function allDead() {
        for (var i = 0; i < enemies.size(); i++) {
            if (enemies[i].alive) { return false; }
        }
        return true;
    }

    // Lowest occupied row among alive enemies (used for game-over).
    function lowestRow() {
        var lo = -1;
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (!e.alive) { continue; }
            if (e.row > lo) { lo = e.row; }
        }
        return lo;
    }

    // Adjust stepInterval based on remaining enemies (faster as
    // fewer alive).  Min 2 ticks (~160 ms — frantic).
    hidden function _recomputeInterval() {
        var alive = aliveCount();
        if (alive <= 0) { return; }
        var iv = baseInterval * alive / startCount;
        if (iv < 2) { iv = 2; }
        stepInterval = iv;
    }

    // Advance the march timer; return true if the formation
    // stepped this tick (so the controller can possibly trigger
    // enemy fire on step boundaries).
    function tick() {
        _recomputeInterval();
        stepTimer = stepTimer - 1;
        if (stepTimer > 0) { return false; }
        stepTimer = stepInterval;
        _stepFormation();
        return true;
    }

    hidden function _stepFormation() {
        // 1. Check whether the leading edge is at the boundary.
        var hitEdge = false;
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (!e.alive) { continue; }
            if (direction > 0 && e.col >= PI_BOARD_COLS - 1) { hitEdge = true; break; }
            if (direction < 0 && e.col <= 0)                  { hitEdge = true; break; }
        }
        if (hitEdge) {
            // Drop one row + reverse.
            for (var k = 0; k < enemies.size(); k++) {
                if (enemies[k].alive) { enemies[k].row = enemies[k].row + 1; }
            }
            direction = -direction;
        } else {
            for (var m = 0; m < enemies.size(); m++) {
                if (enemies[m].alive) { enemies[m].col = enemies[m].col + direction; }
            }
        }
        walkPhase = (walkPhase == 0) ? 1 : 0;
    }

    // Pick a random non-empty column and return the *lowest*
    // alive enemy's (col, row).  Returns null if formation empty.
    function lowestInRandomColumn() {
        // Collect columns that contain at least one alive enemy.
        var cols = {};
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (!e.alive) { continue; }
            cols.put(e.col, true);
        }
        var ckeys = cols.keys();
        if (ckeys.size() == 0) { return null; }
        var c = ckeys[Math.rand() % ckeys.size()];
        var loR = -1; var loE = null;
        for (var j = 0; j < enemies.size(); j++) {
            var en = enemies[j];
            if (!en.alive)        { continue; }
            if (en.col != c)      { continue; }
            if (en.row > loR)     { loR = en.row; loE = en; }
        }
        if (loE == null) { return null; }
        return [loE.col, loE.row];
    }

    static function scoreFor(t) {
        if (t == EI_BOSS)  { return 30; }
        if (t == EI_GUARD) { return 20; }
        return 10;        // DRONE
    }
}
