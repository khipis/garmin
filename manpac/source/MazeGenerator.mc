// ═══════════════════════════════════════════════════════════════
// MazeGenerator.mc — Three Pac-Man-style mazes that cycle as the
// player advances through levels.
//
// Tile codes:
//   0  floor (no pellet)
//   1  wall
//   2  pellet (small dot, +10)
//   3  power pellet (big dot, +50, frightens ghosts)
//
// Mazes are 13x13 and mirror-symmetric so they look correct on
// round watches.  Each one has a central "ghost house" tile that
// ghosts spawn from.
// ═══════════════════════════════════════════════════════════════

const TILE_FLOOR  = 0;
const TILE_WALL   = 1;
const TILE_PELLET = 2;
const TILE_POWER  = 3;

const MAZE_SIZE = 13;
const MAZE_COUNT = 3;

class MazeGenerator {

    // Three 13x13 maze layouts.
    //   #  wall   .  pellet    o  power pellet     (space) floor
    static var LAYOUTS = [
        // 0 — Classic loop
        [ "#############",
          "#o.........o#",
          "#.##.###.##.#",
          "#...........#",
          "#.##.#.#.##.#",
          "#....#.#....#",
          "##.#.#.#.#.##",
          "#....#.#....#",
          "#.##.#.#.##.#",
          "#...........#",
          "#.##.###.##.#",
          "#o.........o#",
          "#############" ],
        // 1 — Cross corridors
        [ "#############",
          "#.....#.....#",
          "#o###.#.###o#",
          "#...........#",
          "###.#####.###",
          "#...#...#...#",
          "#.#.#.#.#.#.#",
          "#...#...#...#",
          "###.#####.###",
          "#...........#",
          "#o###.#.###o#",
          "#.....#.....#",
          "#############" ],
        // 2 — Tight alleys
        [ "#############",
          "#o.#.....#.o#",
          "#.###.#.###.#",
          "#...........#",
          "#.#.#####.#.#",
          "#.#.......#.#",
          "#...#.#.#...#",
          "#.#.......#.#",
          "#.#.#####.#.#",
          "#...........#",
          "#.###.#.###.#",
          "#o.#.....#.o#",
          "#############" ]
    ];

    // Build a flat byte array (row-major) for the maze at `idx`.
    // idx wraps mod MAZE_COUNT so higher levels still get a valid maze.
    static function build(idx) {
        var lay = LAYOUTS[((idx % MAZE_COUNT) + MAZE_COUNT) % MAZE_COUNT];
        var n   = MAZE_SIZE;
        var g   = new [n * n]b;
        for (var r = 0; r < n; r++) {
            var row = lay[r];
            for (var c = 0; c < n; c++) {
                var ch = row.substring(c, c + 1);
                var t  = TILE_FLOOR;
                if (ch.equals("#"))      { t = TILE_WALL;   }
                else if (ch.equals(".")) { t = TILE_PELLET; }
                else if (ch.equals("o")) { t = TILE_POWER;  }
                g[r * n + c] = t;
            }
        }
        return g;
    }

    // Total pellets+powers remaining on the board (used for win check).
    static function countPellets(grid) {
        var c = 0;
        for (var i = 0; i < grid.size(); i++) {
            var t = grid[i];
            if (t == TILE_PELLET || t == TILE_POWER) { c = c + 1; }
        }
        return c;
    }

    // Pac-Man spawn — bottom-center of the maze.
    static function spawnPlayer() { return [9, 6]; }

    // Ghost spawn tiles — four corners of the inner room.
    static function spawnGhost(idx) {
        if (idx == 0) { return [1, 1];   }
        if (idx == 1) { return [1, 11];  }
        if (idx == 2) { return [11, 1];  }
        if (idx == 3) { return [11, 11]; }
        // Fallback (we never spawn more than 4, but be safe).
        return [6, 6];
    }
}
