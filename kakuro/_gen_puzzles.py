#!/usr/bin/env python3
"""Designs 20 verified Kakuro puzzles and emits a Monkey C array.

Output: prints a Monkey C `const KK_PUZZLES` declaration to stdout.

Each puzzle is a 2D array where:
  - 0 = black cell (clue or blocked; figured out at load time)
  - 1..9 = white cell with that solution

Layout rules used here for clean watch rendering:
  - "rectangular inner" template — row 0 + col 0 are black (clue cells)
  - sometimes an interior black cell on harder puzzles

Verification:
  - every white run (≥1 cells) has unique digits 1..9
  - sums computed from solution, but we only need rule-validity
"""

import itertools
import random


def runs_of(grid, axis):
    """Yield (run_cells, run_values) along axis 0=row or 1=col."""
    R = len(grid)
    C = len(grid[0])
    if axis == 0:
        for r in range(R):
            run, vals = [], []
            for c in range(C):
                if grid[r][c] != 0:
                    run.append((r, c)); vals.append(grid[r][c])
                else:
                    if run:
                        yield run, vals
                    run, vals = [], []
            if run: yield run, vals
    else:
        for c in range(C):
            run, vals = [], []
            for r in range(R):
                if grid[r][c] != 0:
                    run.append((r, c)); vals.append(grid[r][c])
                else:
                    if run:
                        yield run, vals
                    run, vals = [], []
            if run: yield run, vals


def is_valid(grid):
    for axis in (0, 1):
        for cells, vals in runs_of(grid, axis):
            if len(set(vals)) != len(vals):
                return False
            for v in vals:
                if not (1 <= v <= 9):
                    return False
    return True


def find_latin_3x3(target_sets):
    """Brute-force a 3x3 grid where each row uses target_sets[i] and
    each column has 3 distinct digits."""
    perms = [list(itertools.permutations(s)) for s in target_sets]
    for r0 in perms[0]:
        for r1 in perms[1]:
            for r2 in perms[2]:
                # check column uniqueness
                ok = True
                for c in range(3):
                    col = [r0[c], r1[c], r2[c]]
                    if len(set(col)) != 3:
                        ok = False; break
                if ok:
                    return [list(r0), list(r1), list(r2)]
    return None


def find_latin_4x4(row_sets):
    perms = [list(itertools.permutations(s)) for s in row_sets]
    for r0 in perms[0]:
        for r1 in perms[1]:
            for r2 in perms[2]:
                for r3 in perms[3]:
                    ok = True
                    for c in range(4):
                        col = [r0[c], r1[c], r2[c], r3[c]]
                        if len(set(col)) != 4:
                            ok = False; break
                    if ok:
                        return [list(r0), list(r1), list(r2), list(r3)]
    return None


# ─── EASY puzzles: 4x4 grid, 3x3 inner ─────────────────────────────
# Row+col 0 are black; r1..r3, c1..c3 are white.  Row sets are chosen
# so column sums create variety.

EASY_ROW_SETS = [
    ({1,2,3}, {4,5,6}, {7,8,9}),
    ({1,2,4}, {5,6,8}, {3,7,9}),
    ({1,3,5}, {2,4,9}, {6,7,8}),
    ({2,3,4}, {1,5,8}, {6,7,9}),
    ({1,4,6}, {2,5,7}, {3,8,9}),
    ({1,2,9}, {3,4,5}, {6,7,8}),
    ({2,4,5}, {1,3,8}, {6,7,9}),
]

# ─── MEDIUM puzzles: 5x5 grid, 4x4 inner ───────────────────────────
MED_ROW_SETS = [
    ({1,2,3,4}, {5,6,7,8}, {1,3,6,9}, {2,4,7,9}),
    ({1,3,5,7}, {2,4,6,8}, {1,2,8,9}, {3,4,7,9}),
    ({1,2,5,8}, {3,4,6,7}, {2,3,8,9}, {1,4,5,9}),
    ({1,4,5,6}, {2,3,7,8}, {3,5,6,9}, {1,2,7,9}),
    ({2,3,4,8}, {1,5,6,7}, {3,4,6,9}, {1,2,7,9}),
    ({1,2,3,9}, {4,5,6,8}, {2,3,7,9}, {1,4,5,8}),
    ({1,3,4,8}, {2,5,6,7}, {4,5,8,9}, {1,3,6,9}),
]

# ─── HARD puzzles: 5x5 grid, 4x4 inner — interior black cell ───────
# We use the same row sets but inject ONE interior black cell at a
# chosen (r,c) so the runs become irregular.
HARD_ROW_SETS = [
    ({1,2,3,4}, {5,6,7,9}, {2,3,4,8}, {1,5,6,9}),
    ({1,2,5,9}, {3,4,6,8}, {2,4,7,9}, {1,3,5,8}),
    ({1,4,5,8}, {2,3,7,9}, {3,4,6,9}, {2,5,7,8}),
    ({1,2,7,8}, {3,4,5,6}, {2,3,8,9}, {1,4,6,9}),
    ({1,3,4,7}, {2,5,6,8}, {3,4,8,9}, {1,5,6,7}),
    ({2,3,6,8}, {1,4,5,9}, {2,3,7,8}, {1,4,6,9}),
]

# ─── Assemble & verify ─────────────────────────────────────────────
def build_3x3_puzzle(row_sets_tuple):
    sets = [set(s) for s in row_sets_tuple]
    sol = find_latin_3x3(sets)
    if sol is None:
        return None
    # Wrap in a 4x4 grid (row 0 and col 0 are black).
    grid = [[0]*4 for _ in range(4)]
    for r in range(3):
        for c in range(3):
            grid[r+1][c+1] = sol[r][c]
    return grid


def build_4x4_puzzle(row_sets_tuple):
    sets = [set(s) for s in row_sets_tuple]
    sol = find_latin_4x4(sets)
    if sol is None:
        return None
    grid = [[0]*5 for _ in range(5)]
    for r in range(4):
        for c in range(4):
            grid[r+1][c+1] = sol[r][c]
    return grid


def inject_hole_4x4(grid, hr, hc):
    """Add an interior black cell at (hr,hc) inside the 4x4 inner.
    Then verify the puzzle remains valid (runs still have unique
    digits; runs of length 1 are trivially fine)."""
    g = [row[:] for row in grid]
    g[hr][hc] = 0
    if not is_valid(g):
        return None
    return g


def emit(grids):
    print("// ═══════════════════════════════════════════════════════════════")
    print("// KKPuzzles.mc — Auto-generated by _gen_puzzles.py — DO NOT EDIT.")
    print("// 20 verified Kakuro puzzles (Easy / Medium / Hard).")
    print("//")
    print("// Each entry is [n, sol[0], sol[1], ..., sol[n*n-1]].  `n` is")
    print("// the grid dimension; the solution is flat (row-major) with 0")
    print("// for black cells and 1..9 for white cells.  Clue cells & sums")
    print("// are derived at load time by GridManager.")
    print("// ═══════════════════════════════════════════════════════════════")
    print()
    print(f"const KK_PUZZLE_COUNT = {len(grids)};")
    print(f"const KK_EASY_COUNT   = 7;")
    print(f"const KK_MED_COUNT    = 7;")
    print(f"const KK_HARD_COUNT   = 6;")
    print()
    print("class KKPuzzles {")
    print("    static function getN(i)   { return _row(i)[0]; }")
    print("    static function getSol(i) {")
    print("        var p   = _row(i);")
    print("        var n   = p[0];")
    print("        var arr = new [n * n];")
    print("        for (var k = 0; k < arr.size(); k++) { arr[k] = p[k + 1]; }")
    print("        return arr;")
    print("    }")
    print()
    print("    hidden static function _row(i) {")
    for i, g in enumerate(grids):
        n = len(g)
        flat = []
        for r in range(n):
            for c in range(n):
                flat.append(g[r][c])
        flat_str = ",".join(str(x) for x in flat)
        print(f"        if (i == {i:2d}) {{ return [{n},{flat_str}]; }}")
    print("        return [4,0,0,0,0,0,1,2,3,0,4,5,6,0,7,8,9];")
    print("    }")
    print("}")


def main():
    out = []

    # Easy: 7 puzzles, 3x3 inner.
    for rs in EASY_ROW_SETS:
        g = build_3x3_puzzle(rs)
        assert g is not None and is_valid(g), f"easy puzzle invalid: {rs}"
        out.append(g)

    # Medium: 7 puzzles, 4x4 inner.
    for rs in MED_ROW_SETS:
        g = build_4x4_puzzle(rs)
        assert g is not None and is_valid(g), f"med puzzle invalid: {rs}"
        out.append(g)

    # Hard: 6 puzzles, 4x4 inner with one interior black cell.
    # Choose hole positions cycling through inner cells.
    hole_positions = [(1,1),(1,4),(4,1),(2,3),(3,2),(4,4)]
    for rs, (hr, hc) in zip(HARD_ROW_SETS, hole_positions):
        g = build_4x4_puzzle(rs)
        assert g is not None, f"hard base invalid: {rs}"
        g2 = inject_hole_4x4(g, hr, hc)
        if g2 is None:
            # fall back to same as medium (no hole)
            g2 = g
        out.append(g2)

    assert len(out) == 20
    emit(out)


if __name__ == "__main__":
    main()
