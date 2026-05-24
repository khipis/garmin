// ═══════════════════════════════════════════════════════════════
// EnemyWaveSystem.mc — Formation + wave management.
//
// One `Enemy` describes a single ship.  Three life-cycle states:
//
//   E_FORMATION   waiting in formation, swaying side-to-side
//   E_DIVING      following a DiveAI path, t∈[0,1]
//   E_DEAD        destroyed or off-screen — eligible for cleanup
//
// `EnemyWaveSystem.populate(wave)` rebuilds the formation for the
// current wave.  Up to 4 rows × 6 enemies, but the actual count
// scales with the wave number (wave 1 → 12, wave 2 → 18, etc.).
//
// `tickFormation()`        — animate the formation sway.
// `tickDives(player)`      — advance every diver one step; off-board
//                            divers are flagged E_DEAD.
// `pickDivers(maxDivers, player)`  — promote idle formation enemies
//                            to E_DIVING when there's free slot.
//
// `divingCells()` returns an Array<[col,row]> of all current diver
// integer cells so the collision system can detect ship hits.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const E_FORMATION = 0;
const E_DIVING    = 1;
const E_DEAD      = 2;

const E_TYPE_DRONE = 0;   // green
const E_TYPE_GUARD = 1;   // pink
const E_TYPE_BOSS  = 2;   // gold (back row of higher waves)

const SS_FORM_ROW_TOP   = 1;   // top of formation (board coords)
const SS_FORM_ROW_COUNT = 4;   // up to 4 rows
const SS_FORM_COLS      = 6;
const SS_FORM_COL_OFF   = 1;   // left-edge column where formation starts

class Enemy {
    var state;
    var type;
    // Formation slot
    var formR;
    var formC;
    // Current rendered position (Float)
    var col;
    var row;
    // Dive params
    var diveT;
    var diveTargetC;
    var curlSide;
    var curlAmp;

    function initialize(type_, fr, fc) {
        state = E_FORMATION; type = type_;
        formR = fr; formC = fc;
        col   = fc + 0.0; row = fr + 0.0;
        diveT = 0.0; diveTargetC = 0.0;
        curlSide = 1; curlAmp = 2.0;
    }

    function intCol() {
        var c = (col + 0.5).toNumber();
        if (c < 0)                  { c = 0; }
        if (c >= SS_BOARD_COLS)     { c = SS_BOARD_COLS - 1; }
        return c;
    }
    function intRow() {
        var r = (row + 0.5).toNumber();
        if (r < 0) { r = -1; }
        return r;
    }
}

class EnemyWaveSystem {
    var enemies;
    var swayPhase;        // for formation drift animation
    var diveSpeed;        // per-tick diveT increment
    var wave;             // current wave (1-based)

    function initialize() {
        enemies   = [];
        swayPhase = 0.0;
        diveSpeed = 0.020;
        wave      = 1;
    }

    function reset() { enemies = []; swayPhase = 0.0; }

    // Number of formation slots that should be filled for `w`.
    hidden function _slotsForWave(w) {
        var n = 12 + (w - 1) * 3;
        var maxN = SS_FORM_ROW_COUNT * SS_FORM_COLS;
        if (n > maxN) { n = maxN; }
        return n;
    }

    function populate(w, baseDiveSpeed) {
        wave      = w;
        diveSpeed = baseDiveSpeed + 0.0035 * (w - 1);
        if (diveSpeed > 0.055) { diveSpeed = 0.055; }
        enemies   = [];
        swayPhase = 0.0;
        var n = _slotsForWave(w);
        var placed = 0;
        // Top-down fill so back rows hold the toughest types.
        for (var fr = 0; fr < SS_FORM_ROW_COUNT && placed < n; fr++) {
            for (var fc = 0; fc < SS_FORM_COLS && placed < n; fc++) {
                var typ;
                if (fr == 0)      { typ = E_TYPE_BOSS;  }
                else if (fr <= 1) { typ = E_TYPE_GUARD; }
                else              { typ = E_TYPE_DRONE; }
                var e = new Enemy(typ,
                                  SS_FORM_ROW_TOP + fr,
                                  SS_FORM_COL_OFF + fc);
                enemies.add(e);
                placed = placed + 1;
            }
        }
    }

    // Step the formation sway and rewrite the position of every
    // non-diving enemy from its slot.
    function tickFormation() {
        swayPhase = swayPhase + 0.06;
        if (swayPhase > 100.0) { swayPhase = swayPhase - 100.0; }
        var dx = 0.9 * Math.sin(swayPhase);
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (e.state != E_FORMATION) { continue; }
            e.col = e.formC + dx;
            e.row = e.formR + 0.0;
        }
    }

    // Advance every diver, kill those past the bottom.
    function tickDives() {
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (e.state != E_DIVING) { continue; }
            e.diveT = e.diveT + diveSpeed;
            if (e.diveT >= 1.0) {
                e.state = E_DEAD;
                continue;
            }
            var p = DiveAI.pointFor(e.diveT,
                                     e.formC, e.formR,
                                     e.diveTargetC,
                                     e.curlSide, e.curlAmp);
            e.col = p[0]; e.row = p[1];
        }
    }

    // Promote up to `maxDivers - currentDivers` formation enemies
    // to E_DIVING.  Skips frames probabilistically so dives feel
    // organic instead of clockwork.
    function pickDivers(maxDivers, playerCol) {
        var current = 0;
        var candidates = [];
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (e.state == E_DIVING)     { current = current + 1; }
            else if (e.state == E_FORMATION) { candidates.add(e); }
        }
        if (current >= maxDivers || candidates.size() == 0) { return; }
        if ((Math.rand() % 100) > 22) { return; }   // ~22 % per tick
        var pick = candidates[Math.rand() % candidates.size()];
        pick.state       = E_DIVING;
        pick.diveT       = 0.0;
        pick.diveTargetC = playerCol;
        pick.curlSide    = ((Math.rand() % 2) == 0) ? -1 : 1;
        pick.curlAmp     = 1.5 + ((Math.rand() % 20) / 10.0);  // 1.5..3.5
    }

    // True if every enemy is dead (wave cleared).
    function allDead() {
        for (var i = 0; i < enemies.size(); i++) {
            if (enemies[i].state != E_DEAD) { return false; }
        }
        return true;
    }

    // Returns a list of [col,row] cells currently occupied by any
    // diving enemy (used for player collision).
    function divingCells() {
        var out = [];
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (e.state != E_DIVING) { continue; }
            out.add([e.intCol(), e.intRow()]);
        }
        return out;
    }
}
