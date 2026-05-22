// ═══════════════════════════════════════════════════════════════
// GridManager.mc — One 8×8 battle grid (cells + ship-id parallel array).
//
// Storage strategy
// ----------------
// Each cell is a bitmask kept in a flat Array<Number> of length 64.
// Bits:
//   CELL_SHIP  (1)  — a ship occupies this cell
//   CELL_SHOT  (2)  — opponent has fired at this cell
// Combinations:
//   0  EMPTY UNFIRED — water, never shot
//   1  SHIP  UNFIRED — secret ship cell
//   2  EMPTY FIRED   — missed shot (visible "O")
//   3  SHIP  FIRED   — hit ship cell (visible "X")
//
// Sink tracking
// -------------
// A parallel `shipId` array (length 64) holds -1 on water, otherwise
// the index of the ship occupying the cell. Sinking is detected by
// `ShipManager.applyHit(id)` decrementing the ship's HP — `GridManager`
// itself is just a fast typed store.
//
// Both the player's board AND the enemy's board are instances of
// this class. From the player's perspective, the enemy grid hides
// its `CELL_SHIP` flags until those cells have been fired on, so
// the renderer only consults the SHOT bit when drawing the enemy
// grid.
// ═══════════════════════════════════════════════════════════════

const GRID_SIZE  = 10;
const NUM_CELLS  = 100;

// Cell flag bits
const CELL_SHIP = 1;
const CELL_SHOT = 2;

class GridManager {
    var cells;       // Array<Number> length NUM_CELLS — bitmask flags
    var shipId;      // Array<Number> length NUM_CELLS — ship index or -1

    function initialize() {
        cells  = new [NUM_CELLS];
        shipId = new [NUM_CELLS];
        clear();
    }

    function clear() {
        for (var i = 0; i < NUM_CELLS; i++) {
            cells[i]  = 0;
            shipId[i] = -1;
        }
    }

    // ── Coordinate helpers ──────────────────────────────────────────
    static function inBoundsRC(r, c) {
        return r >= 0 && c >= 0 && r < GRID_SIZE && c < GRID_SIZE;
    }
    function inBounds(r, c) { return GridManager.inBoundsRC(r, c); }

    function get(r, c)             { return cells[r * GRID_SIZE + c]; }
    function set(r, c, v)          { cells[r * GRID_SIZE + c] = v; }
    function getShipId(r, c)       { return shipId[r * GRID_SIZE + c]; }
    function setShipId(r, c, id)   { shipId[r * GRID_SIZE + c] = id; }

    function hasShip(r, c) { return (get(r, c) & CELL_SHIP) != 0; }
    function isShot(r, c)  { return (get(r, c) & CELL_SHOT) != 0; }
    function isHit(r, c)   {
        var v = get(r, c);
        return (v & CELL_SHIP) != 0 && (v & CELL_SHOT) != 0;
    }
    function isMiss(r, c)  {
        var v = get(r, c);
        return (v & CELL_SHIP) == 0 && (v & CELL_SHOT) != 0;
    }

    // Mark a shot. Caller is responsible for checking `isShot()` first
    // to avoid double-counting.
    function markShot(r, c) {
        cells[r * GRID_SIZE + c] = cells[r * GRID_SIZE + c] | CELL_SHOT;
    }

    // ── Ship placement helpers ─────────────────────────────────────
    // `horizontal` true → ship grows in +c direction; else +r.
    //
    // Russian/Soviet ruleset: ships may not touch — neither side- nor
    // corner-adjacent. We enforce this by checking every cell of the
    // candidate ship AND each of its 8 neighbours for an existing
    // ship occupant. The new ship's own cells aren't placed yet so
    // they're guaranteed empty.
    function canPlace(r, c, len, horizontal) {
        for (var i = 0; i < len; i++) {
            var rr = horizontal ? r : r + i;
            var cc = horizontal ? c + i : c;
            if (!inBounds(rr, cc)) { return false; }
            for (var dr = -1; dr <= 1; dr++) {
                for (var dc = -1; dc <= 1; dc++) {
                    var nr = rr + dr;
                    var nc = cc + dc;
                    if (!inBounds(nr, nc)) { continue; }
                    if (hasShip(nr, nc))   { return false; }
                }
            }
        }
        return true;
    }

    function placeShip(r, c, len, horizontal, id) {
        for (var i = 0; i < len; i++) {
            var rr = horizontal ? r : r + i;
            var cc = horizontal ? c + i : c;
            cells[rr * GRID_SIZE + cc] = cells[rr * GRID_SIZE + cc] | CELL_SHIP;
            shipId[rr * GRID_SIZE + cc] = id;
        }
    }

    // Returns array of [r, c] pairs occupied by ship `id`. Useful
    // when revealing sunk ships or feeding the AI's TARGET pruning.
    function cellsForShip(id) {
        var out = [];
        for (var i = 0; i < NUM_CELLS; i++) {
            if (shipId[i] == id) {
                out.add([i / GRID_SIZE, i % GRID_SIZE]);
            }
        }
        return out;
    }
}
