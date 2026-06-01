// ═══════════════════════════════════════════════════════════════
// MazeGenerator.mc — Iterative DFS perfect-maze generator.
//
// Produces a *perfect maze* (exactly one path between any two
// cells) using iterative depth-first search so that we never hit
// Monkey C's call-stack limits, even for 11×11.
//
// walls[i]  bitmask of present walls for cell i = r*n+c:
//   bit 0 (GM_WALL_N): north wall
//   bit 1 (GM_WALL_S): south wall
//   bit 2 (GM_WALL_E): east  wall
//   bit 3 (GM_WALL_W): west  wall
//
// extras[i] = tile type (GM_TILE_*) applied post-generation based
//             on the active biome.
//
// The exit cell is the dead-end furthest from the start (0,0),
// found by a single BFS traversal of the maze.
// ═══════════════════════════════════════════════════════════════

class MazeGenerator {
    hidden var _rng;

    function initialize() { _rng = 1; }

    hidden function _lcg() {
        _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
        return _rng;
    }
    hidden function _rand(n_) {
        if (n_ <= 1) { return 0; }
        return _lcg() % n_;
    }

    // Returns [walls, extras, exitCellIndex].
    function generate(n, biome, seed) {
        _rng = seed;
        if (_rng == 0) { _rng = 1; }

        var sz  = n * n;
        var walls   = new [sz];
        var extras  = new [sz];
        var visited = new [sz];
        var stack   = new [sz];
        for (var i = 0; i < sz; i++) {
            walls[i]   = GM_WALL_N | GM_WALL_S | GM_WALL_E | GM_WALL_W;
            extras[i]  = GM_TILE_FLOOR;
            visited[i] = 0;
        }

        // ── Iterative DFS ──────────────────────────────────────
        var stackTop = 1;
        stack[0]    = 0;
        visited[0]  = 1;
        var ndirs = new [4];

        while (stackTop > 0) {
            var cur = stack[stackTop - 1];
            var r   = cur / n;
            var c   = cur % n;
            var nd  = 0;

            if (r > 0     && visited[(r-1)*n+c]   == 0) { ndirs[nd] = 0; nd++; }
            if (r < n - 1 && visited[(r+1)*n+c]   == 0) { ndirs[nd] = 1; nd++; }
            if (c < n - 1 && visited[r*n+(c+1)]   == 0) { ndirs[nd] = 2; nd++; }
            if (c > 0     && visited[r*n+(c-1)]   == 0) { ndirs[nd] = 3; nd++; }

            if (nd == 0) { stackTop--; continue; }

            var dir = ndirs[_rand(nd)];
            var nr  = r; var nc = c;
            if      (dir == 0) { nr = r - 1; }
            else if (dir == 1) { nr = r + 1; }
            else if (dir == 2) { nc = c + 1; }
            else               { nc = c - 1; }

            // Carve wall between cur ↔ neighbour.
            if (dir == 0) { walls[cur] &= ~GM_WALL_N; walls[nr*n+nc] &= ~GM_WALL_S; }
            else if (dir == 1) { walls[cur] &= ~GM_WALL_S; walls[nr*n+nc] &= ~GM_WALL_N; }
            else if (dir == 2) { walls[cur] &= ~GM_WALL_E; walls[nr*n+nc] &= ~GM_WALL_W; }
            else               { walls[cur] &= ~GM_WALL_W; walls[nr*n+nc] &= ~GM_WALL_E; }

            visited[nr*n+nc]   = 1;
            stack[stackTop]    = nr*n+nc;
            stackTop++;
        }

        // ── BFS to find furthest exit ──────────────────────────
        var exitCell = _findExit(walls, n, sz);

        // ── Apply biome tile extras ────────────────────────────
        _applyBiome(walls, extras, n, biome, exitCell, sz);

        return [walls, extras, exitCell];
    }

    hidden function _findExit(walls, n, sz) {
        var dist  = new [sz];
        var queue = new [sz];
        for (var i = 0; i < sz; i++) { dist[i] = -1; }
        var qH = 0; var qT = 0;
        queue[qT] = 0; qT++;
        dist[0]   = 0;
        var best  = 0; var exitCell = sz - 1;

        while (qH < qT) {
            var cur = queue[qH]; qH++;
            var r   = cur / n;
            var c   = cur % n;
            var d   = dist[cur];
            if (d > best) { best = d; exitCell = cur; }

            if (r > 0     && (walls[cur] & GM_WALL_N) == 0 && dist[(r-1)*n+c] < 0) {
                dist[(r-1)*n+c] = d+1; queue[qT] = (r-1)*n+c; qT++;
            }
            if (r < n-1   && (walls[cur] & GM_WALL_S) == 0 && dist[(r+1)*n+c] < 0) {
                dist[(r+1)*n+c] = d+1; queue[qT] = (r+1)*n+c; qT++;
            }
            if (c < n-1   && (walls[cur] & GM_WALL_E) == 0 && dist[r*n+(c+1)] < 0) {
                dist[r*n+(c+1)] = d+1; queue[qT] = r*n+(c+1); qT++;
            }
            if (c > 0     && (walls[cur] & GM_WALL_W) == 0 && dist[r*n+(c-1)] < 0) {
                dist[r*n+(c-1)] = d+1; queue[qT] = r*n+(c-1); qT++;
            }
        }
        return exitCell;
    }

    hidden function _applyBiome(walls, extras, n, biome, exitCell, sz) {
        // Resolve CHAOS to a mix.
        var b = biome;
        if (b == GM_BIOME_CHAOS) { b = -1; } // use mixed rules below

        for (var i = 1; i < sz; i++) {
            if (i == exitCell) { continue; }
            var wallCnt = _wallBits(walls[i]);

            if (b == GM_BIOME_TRAP || b == -1) {
                // Spike on dead-ends (3 walls = 1 opening).
                if (wallCnt == 3 && _rand(5) == 0) {
                    extras[i] = GM_TILE_SPIKE;
                    continue;
                }
            }
            if (b == GM_BIOME_SPEED || b == -1) {
                if (_rand(10) == 0) { extras[i] = GM_TILE_BOOST; continue; }
            }
            if (b == GM_BIOME_NORMAL) {
                if (_rand(8) == 0) { extras[i] = GM_TILE_SLOW; }
            }
        }
    }

    hidden function _wallBits(v) {
        var k = 0;
        if ((v & GM_WALL_N) != 0) { k++; }
        if ((v & GM_WALL_S) != 0) { k++; }
        if ((v & GM_WALL_E) != 0) { k++; }
        if ((v & GM_WALL_W) != 0) { k++; }
        return k;
    }
}
