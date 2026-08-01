// ═══════════════════════════════════════════════════════════════
// ShipManager.mc — Tracks fleet composition + per-ship HP/sunk state.
//
// Fleet (Soviet/Russian-style Battleship on a 10×10 board):
//   1 × 4-cell  Battleship
//   2 × 3-cell  Cruisers
//   3 × 2-cell  Destroyers
//   4 × 1-cell  Submarines
//   Total: 10 ships, 20 cells. Ships may NOT touch each other on any
//   side or corner (enforced by GridManager.canPlace).
//
// `applyHit(id)` decrements the ship's HP and returns true the very
// first time HP reaches zero (i.e. that hit was the sinking blow),
// so the caller can fire any "ship sunk" UI / AI bookkeeping.
//
// The class is intentionally stateless w.r.t. the grid: ship cells
// live in `GridManager.shipId`, this just tracks counts.
// ═══════════════════════════════════════════════════════════════

const NUM_SHIPS = 10;
// Lengths in placement (largest-first) order. Exposed as a global so
// the same constant can be reused by the auto-placer and the UI.
var SHIP_LENS  = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];
var SHIP_NAMES = ["Battleship",
                  "Cruiser",  "Cruiser",
                  "Destroyer","Destroyer","Destroyer",
                  "Sub",      "Sub",      "Sub",      "Sub"];

class Ship {
    var len;       // total length
    var hp;        // remaining live cells
    var sunk;      // cached flag, true when hp == 0

    function initialize(l) {
        len  = l;
        hp   = l;
        sunk = false;
    }
}

class ShipManager {
    var ships;     // Array<Ship>

    function initialize() {
        ships = new [NUM_SHIPS];
        reset();
    }

    function reset() {
        for (var i = 0; i < NUM_SHIPS; i++) {
            ships[i] = new Ship(SHIP_LENS[i]);
        }
    }

    function get(id) { return ships[id]; }

    // Returns true if this hit just sank the ship.
    function applyHit(id) {
        if (id < 0 || id >= NUM_SHIPS) { return false; }
        var s = ships[id];
        if (s.sunk) { return false; }
        s.hp = s.hp - 1;
        if (s.hp <= 0) {
            s.hp   = 0;
            s.sunk = true;
            return true;
        }
        return false;
    }

    function allSunk() {
        for (var i = 0; i < NUM_SHIPS; i++) {
            if (!ships[i].sunk) { return false; }
        }
        return true;
    }

    function sunkCount() {
        var n = 0;
        for (var i = 0; i < NUM_SHIPS; i++) {
            if (ships[i].sunk) { n++; }
        }
        return n;
    }

    // ── SaveResume (see _shared/menu/SaveResume.mc) ──────────────────
    function exportData() {
        var out = new [NUM_SHIPS];
        for (var i = 0; i < NUM_SHIPS; i++) {
            out[i] = [ships[i].len, ships[i].hp, ships[i].sunk ? 1 : 0];
        }
        return out;
    }

    function importData(arr) {
        if (!(arr instanceof Array) || arr.size() != NUM_SHIPS) { return false; }
        for (var i = 0; i < NUM_SHIPS; i++) {
            var s = arr[i];
            if (!(s instanceof Array) || s.size() < 3) { return false; }
            var l = s[0]; var hp = s[1]; var sk = s[2];
            if (!(l instanceof Number) || !(hp instanceof Number)) { return false; }
            ships[i].len  = l;
            ships[i].hp   = hp;
            ships[i].sunk = (sk instanceof Number && sk != 0);
        }
        return true;
    }
}
