// ═══════════════════════════════════════════════════════════════
// SudokuGrid.mc — Flat board storage + validity checks.
//
// Cells are stored in a single flat int array (row-major, idx = r*N + c).
//   0          : empty
//   1..N       : digit
// Fixed cells (clues) are tracked in a parallel boolean array — these
// can never be edited or cleared by the player.
//
// "errors" array is recomputed by recomputeErrors(); errors[idx] = true
// when the digit at that cell duplicates another digit in its row,
// column or sub-box. Used by Relaxed mode to draw conflicts in red.
//
// Constants used (defined here, visible across the project):
//   SZ_4, SZ_9, BOX_4, BOX_9
// ═══════════════════════════════════════════════════════════════

const SZ_4  = 4;   // 4x4 grid
const SZ_9  = 9;   // 9x9 grid
const BOX_4 = 2;   // 2x2 sub-box for 4x4
const BOX_9 = 3;   // 3x3 sub-box for 9x9

class SudokuGrid {
    var n;        // 4 or 9 — grid side length
    var box;      // 2 or 3 — sub-box side length
    var cells;    // Int[n*n] — current value (0 = empty)
    var solution; // Int[n*n] — the unique completed solution
    var fixed;    // Boolean[n*n] — true for the given clues
    var errors;   // Boolean[n*n] — true for cells whose value conflicts

    function initialize() {
        n = SZ_9; box = BOX_9;
        cells    = new [81];
        solution = new [81];
        fixed    = new [81];
        errors   = new [81];
    }

    // Switch between 4x4 and 9x9. (Allocates fresh arrays sized for n.)
    function setSize(size) {
        n = size;
        box = (size == SZ_4) ? BOX_4 : BOX_9;
        var total = n * n;
        cells    = new [total];
        solution = new [total];
        fixed    = new [total];
        errors   = new [total];
        for (var i = 0; i < total; i++) {
            cells[i] = 0; solution[i] = 0; fixed[i] = false; errors[i] = false;
        }
    }

    // Load a puzzle (and its solution) into the grid.
    // 'puzzle' is an int array of length n*n where 0 = blank, non-0 = given clue.
    function loadPuzzle(puzzle, sol) {
        var total = n * n;
        for (var i = 0; i < total; i++) {
            cells[i]    = puzzle[i];
            solution[i] = sol[i];
            fixed[i]    = (puzzle[i] != 0);
            errors[i]   = false;
        }
    }

    // Place 'value' at (row, col). Returns false if cell is fixed.
    // Caller decides when to recomputeErrors().
    function setValue(row, col, value) {
        var idx = row * n + col;
        if (fixed[idx]) { return false; }
        cells[idx] = value;
        return true;
    }

    function getValue(row, col)    { return cells[row * n + col];    }
    function isFixed(row, col)     { return fixed[row * n + col];    }
    function isError(row, col)     { return errors[row * n + col];   }
    function getSolution(row, col) { return solution[row * n + col]; }

    // True when every cell matches the solution. O(n²).
    function isComplete() {
        var total = n * n;
        for (var i = 0; i < total; i++) {
            if (cells[i] != solution[i]) { return false; }
        }
        return true;
    }

    // True when every cell is filled and there are no conflicts.
    // Different from isComplete (which compares to baked solution) —
    // useful for Strict mode: a player may submit a self-consistent
    // board that happens to also equal the unique solution.
    function isFilledAndValid() {
        recomputeErrors();
        var total = n * n;
        for (var i = 0; i < total; i++) {
            if (cells[i] == 0)   { return false; }
            if (errors[i])       { return false; }
        }
        return true;
    }

    // Fill `errors[]` based on row / column / sub-box duplicates.
    // O(n²) — cheap even on lowest-end watches.
    function recomputeErrors() {
        var total = n * n;
        for (var i = 0; i < total; i++) { errors[i] = false; }

        // Row duplicates
        for (var r = 0; r < n; r++) {
            for (var c1 = 0; c1 < n; c1++) {
                var v = cells[r * n + c1];
                if (v == 0) { continue; }
                for (var c2 = c1 + 1; c2 < n; c2++) {
                    if (cells[r * n + c2] == v) {
                        errors[r * n + c1] = true;
                        errors[r * n + c2] = true;
                    }
                }
            }
        }
        // Column duplicates
        for (var c = 0; c < n; c++) {
            for (var r1 = 0; r1 < n; r1++) {
                var v = cells[r1 * n + c];
                if (v == 0) { continue; }
                for (var r2 = r1 + 1; r2 < n; r2++) {
                    if (cells[r2 * n + c] == v) {
                        errors[r1 * n + c] = true;
                        errors[r2 * n + c] = true;
                    }
                }
            }
        }
        // Box duplicates
        for (var br = 0; br < n; br += box) {
            for (var bc = 0; bc < n; bc += box) {
                // Collect cells inside this box and check pairs.
                for (var i1 = 0; i1 < box * box; i1++) {
                    var r1 = br + (i1 / box);
                    var c1 = bc + (i1 % box);
                    var v = cells[r1 * n + c1];
                    if (v == 0) { continue; }
                    for (var i2 = i1 + 1; i2 < box * box; i2++) {
                        var r2 = br + (i2 / box);
                        var c2 = bc + (i2 % box);
                        if (cells[r2 * n + c2] == v) {
                            errors[r1 * n + c1] = true;
                            errors[r2 * n + c2] = true;
                        }
                    }
                }
            }
        }
    }

    // Number of empty cells remaining.
    function emptyCount() {
        var total = n * n;
        var k = 0;
        for (var i = 0; i < total; i++) { if (cells[i] == 0) { k = k + 1; } }
        return k;
    }
}
