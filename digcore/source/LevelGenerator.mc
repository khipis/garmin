// ═══════════════════════════════════════════════════════════════
// LevelGenerator.mc — Hand-tuned cave layouts.
//
// Five 13x13 levels of increasing difficulty.  Each cave is
// authored as a string array so the layout is deterministic on
// every run — important when tuning a puzzle game.
//
// Tile characters:
//   #  hard wall (border)
//   :  brick (soft wall — rocks can smash through)
//   .  dirt
//   r  rock
//   d  diamond
//   x  exit
//   f  firefly spawn (cell stored as EMPTY)
//   P  player spawn  (cell stored as EMPTY)
//   (space) empty cave
//
// Each level publishes:
//   grid          – populated GridManager
//   spawn         – [r,c] for the miner
//   exitPos       – [r,c] for the (initially locked) exit
//   diamondGoal   – diamonds required to open the exit
//   timeLimit     – seconds before "time up"
//   fireflies     – array of [r,c,dir] tuples (initial direction L)
// ═══════════════════════════════════════════════════════════════

class LevelGenerator {

    static var LAYOUTS = [
        // Level 1 — "First Dig".  Lots of dirt, few rocks, no flies.
        // Goal: 4 diamonds, 90 seconds.
        [ "#############",
          "#P.....r....#",
          "#...d....d..#",
          "#..:::....::#",
          "#...........#",
          "#.r.......r.#",
          "#....d......#",
          "#..::....::.#",
          "#...........#",
          "#..d..r..d..#",
          "#...........#",
          "#..........x#",
          "#############" ],
        // Level 2 — "Falling Sky".  Vertical rock columns drop fast.
        [ "#############",
          "#P.r.r.r.r..#",
          "#...........#",
          "#:.::.::.::.#",
          "#...d...d...#",
          "#...........#",
          "#..r.r.r.r..#",
          "#...........#",
          "#.::.::.::.:#",
          "#.d..d..d.d.#",
          "#...........#",
          "#..r......r.#",
          "############x" ],
        // Level 3 — "Firefly Mine".  Two fireflies plus brick maze.
        [ "#############",
          "#P..........#",
          "#.:::::::::.#",
          "#.....d.....#",
          "#.::.....::.#",
          "#..r..f..r..#",
          "#.::.....::.#",
          "#.....d.....#",
          "#.:::::::::.#",
          "#.r...d...r.#",
          "#.....f.....#",
          "#..d.....d.x#",
          "#############" ],
        // Level 4 — "Avalanche".  Heavy rock load, 3 fireflies.
        [ "#############",
          "#P.r.r.r.r.r#",
          "#:.:.:.:.:.:#",
          "#.r.r.r.r.r.#",
          "#:.:.:.:.:.:#",
          "#.d.f.d.f.d.#",
          "#:.:.:.:.:.:#",
          "#.r.r.r.r.r.#",
          "#:.:.:.:.:.:#",
          "#.d.d.d.f.d.#",
          "#:.:.:.:.:.:#",
          "#.r.r.r.r.r.#",
          "###########x#" ],
        // Level 5 — "Heart of the Core".  Tight chambers, 4 flies,
        // many diamonds locked behind bricks.
        [ "#############",
          "#P:.d.:.d.:.#",
          "#.:.r.:.r.:.#",
          "#.f.:.d.:.f.#",
          "#:.:.:.:.:.:#",
          "#.r.r.r.r.r.#",
          "#:.:.:.:.:.:#",
          "#.f.:.d.:.f.#",
          "#:.:.:.:.:.:#",
          "#.d.:.r.:.d.#",
          "#:.:.:.:.:.:#",
          "#.r.r.d.r.r.#",
          "#############x" ]
    ];

    // Time limits & diamond goals are stored separately so they're
    // easy to tweak without touching the maps.
    static var TIME_LIMITS    = [ 90,  85,  100,  110,  120 ];
    static var DIAMOND_GOALS  = [  4,   5,    5,    7,    9 ];

    // levelIdx is 0-based.  Returns a dictionary-ish array:
    //   [ grid, spawn(r,c), exit(r,c), diamondGoal, timeLimit, flies[] ]
    static function build(levelIdx) {
        var idx = levelIdx;
        if (idx < 0) { idx = 0; }
        if (idx >= LAYOUTS.size()) { idx = LAYOUTS.size() - 1; }

        var lay = LAYOUTS[idx];
        var h = lay.size();
        var w = lay[0].length();
        var g = new GridManager(w, h);
        var spawn   = [1, 1];
        var exitPos = [h - 2, w - 2];
        var flies   = [];

        for (var r = 0; r < h; r++) {
            var row = lay[r];
            for (var c = 0; c < w; c++) {
                var ch = row.substring(c, c + 1);
                var t = TC_EMPTY;
                if      (ch.equals("#")) { t = TC_WALL;    }
                else if (ch.equals(":")) { t = TC_BRICK;   }
                else if (ch.equals(".")) { t = TC_DIRT;    }
                else if (ch.equals("r")) { t = TC_ROCK;    }
                else if (ch.equals("d")) { t = TC_DIAMOND; }
                else if (ch.equals("x")) { t = TC_WALL;    exitPos = [r, c]; }
                else if (ch.equals("P")) { t = TC_EMPTY;   spawn   = [r, c]; }
                else if (ch.equals("f")) { t = TC_EMPTY;   flies.add([r, c, DC_DIR_L]); }
                g.set(r, c, t);
            }
        }
        g.crystalTotal = g.countDiamonds();

        return [g, spawn, exitPos, DIAMOND_GOALS[idx], TIME_LIMITS[idx], flies];
    }

    static function levelCount() { return LAYOUTS.size(); }
}
