// ═══════════════════════════════════════════════════════════════
// PhysicsEngine.mc — Ball physics in cell-unit space.
//
// Positions bx, by are Floats in [0.0 .. n].  This completely
// decouples physics from screen resolution: the UIManager simply
// multiplies by cellPx to get pixel coordinates.
//
// Collision model:
//   Walls sit at integer boundaries (x = 0, 1, 2 … n).  When the
//   ball's *edge* (bx ± ballR) crosses an integer boundary we look
//   up the corresponding wall bit in walls[].  If the wall is
//   present we push the ball back to just inside the boundary and
//   zero the velocity component.  X and Y are resolved separately
//   (standard axis-projection approach).
//
// Biome physics tables (tuned for an 80 ms tick):
//   NORMAL  friction=0.87  maxSpd=0.26  accelScale=0.00030
//   ICE     friction=0.97  maxSpd=0.36  accelScale=0.00025
//   TRAP    friction=0.86  maxSpd=0.26  accelScale=0.00032
//   SPEED   friction=0.82  maxSpd=0.44  accelScale=0.00050
//   CHAOS   friction=0.89  maxSpd=0.32  accelScale=0.00038
// ═══════════════════════════════════════════════════════════════

class PhysicsEngine {
    var bx;          // ball centre x  (cell-units, Float)
    var by;          // ball centre y
    var vx;          // velocity x     (cell-units/tick)
    var vy;
    var ballR;       // ball radius    (cell-units, Float)

    var friction;
    var maxSpeed;
    var accelScale;

    function initialize() {
        bx = 0.0; by = 0.0;
        vx = 0.0; vy = 0.0;
        ballR    = 0.25;
        friction = 0.87;
        maxSpeed = 0.26;
        accelScale = 0.00030;
    }

    function setBiome(biome) {
        if (biome == GM_BIOME_ICE) {
            friction = 0.97; maxSpeed = 0.36; accelScale = 0.00025;
        } else if (biome == GM_BIOME_TRAP) {
            friction = 0.86; maxSpeed = 0.26; accelScale = 0.00032;
        } else if (biome == GM_BIOME_SPEED) {
            friction = 0.82; maxSpeed = 0.44; accelScale = 0.00050;
        } else if (biome == GM_BIOME_CHAOS) {
            friction = 0.89; maxSpeed = 0.32; accelScale = 0.00038;
        } else {
            friction = 0.87; maxSpeed = 0.26; accelScale = 0.00030;
        }
    }

    // Reset to a specific cell (+ biome physics).
    function place(cellCol, cellRow) {
        bx = cellCol.toFloat() + 0.5;
        by = cellRow.toFloat() + 0.5;
        vx = 0.0; vy = 0.0;
    }

    // Apply raw accelerometer input (milli-g, calibrated).
    // Note the negative ay: screen Y increases downward but sensor
    // Y increases toward the top of the watch.
    function applyAccel(ax, ay) {
        vx = vx + ax * accelScale;
        vy = vy - ay * accelScale;
        if (vx >  maxSpeed) { vx =  maxSpeed; }
        if (vx < -maxSpeed) { vx = -maxSpeed; }
        if (vy >  maxSpeed) { vy =  maxSpeed; }
        if (vy < -maxSpeed) { vy = -maxSpeed; }
    }

    // Apply button-based fallback acceleration (already in cell-units/tick²).
    function applyButtonAccel(ax, ay) {
        vx = vx + ax;
        vy = vy + ay;
        if (vx >  maxSpeed) { vx =  maxSpeed; }
        if (vx < -maxSpeed) { vx = -maxSpeed; }
        if (vy >  maxSpeed) { vy =  maxSpeed; }
        if (vy < -maxSpeed) { vy = -maxSpeed; }
    }

    // Modify velocity based on special tile.
    function applyTile(extra) {
        if (extra == GM_TILE_SLOW) {
            vx = vx * 0.5; vy = vy * 0.5;
        } else if (extra == GM_TILE_BOOST) {
            vx = vx * 1.4; vy = vy * 1.4;
            var ms15 = maxSpeed * 1.5;
            if (vx >  ms15) { vx =  ms15; }
            if (vx < -ms15) { vx = -ms15; }
            if (vy >  ms15) { vy =  ms15; }
            if (vy < -ms15) { vy = -ms15; }
        }
    }

    // Move one tick, resolving wall collisions.
    function step(walls, n) {
        var nbx = bx + vx;
        var nby = by + vy;

        nbx = _resolveX(walls, n, nbx, nby);
        nby = _resolveY(walls, n, nbx, nby);

        // Hard boundary clamp (outer maze walls should handle this,
        // but this is a safety net for floating-point edge cases).
        var lo = ballR + 0.01;
        var hi = n.toFloat() - ballR - 0.01;
        if (nbx < lo) { nbx = lo; vx = 0.0; }
        if (nbx > hi) { nbx = hi; vx = 0.0; }
        if (nby < lo) { nby = lo; vy = 0.0; }
        if (nby > hi) { nby = hi; vy = 0.0; }

        bx = nbx; by = nby;

        vx = vx * friction;
        vy = vy * friction;
        if (vx < 0.002 && vx > -0.002) { vx = 0.0; }
        if (vy < 0.002 && vy > -0.002) { vy = 0.0; }
    }

    // ── X axis collision ───────────────────────────────────────
    hidden function _resolveX(walls, n, nbx, nby) {
        var row = by.toNumber();       // integer row of ball centre
        if (row < 0) { row = 0; }
        if (row >= n) { row = n - 1; }

        if (vx > 0.0) {
            var oldC = (bx    + ballR).toNumber(); // column of right edge before
            var newC = (nbx   + ballR).toNumber(); // column of right edge after
            if (newC > oldC && oldC < n) {
                if ((walls[row*n + oldC] & GM_WALL_E) != 0) {
                    nbx = newC.toFloat() - ballR - 0.01;
                    vx  = 0.0;
                }
            }
        } else if (vx < 0.0) {
            var oldC = (bx    - ballR).toNumber();
            var newC = (nbx   - ballR).toNumber();
            if (newC < oldC && oldC >= 0 && oldC < n) {
                if ((walls[row*n + oldC] & GM_WALL_W) != 0) {
                    nbx = oldC.toFloat() + ballR + 0.01;
                    vx  = 0.0;
                }
            }
        }
        return nbx;
    }

    // ── Y axis collision ───────────────────────────────────────
    hidden function _resolveY(walls, n, nbx, nby) {
        var col = nbx.toNumber();
        if (col < 0) { col = 0; }
        if (col >= n) { col = n - 1; }

        if (vy > 0.0) {
            var oldR = (by    + ballR).toNumber();
            var newR = (nby   + ballR).toNumber();
            if (newR > oldR && oldR < n) {
                if ((walls[oldR*n + col] & GM_WALL_S) != 0) {
                    nby = newR.toFloat() - ballR - 0.01;
                    vy  = 0.0;
                }
            }
        } else if (vy < 0.0) {
            var oldR = (by    - ballR).toNumber();
            var newR = (nby   - ballR).toNumber();
            if (newR < oldR && oldR >= 0 && oldR < n) {
                if ((walls[oldR*n + col] & GM_WALL_N) != 0) {
                    nby = oldR.toFloat() + ballR + 0.01;
                    vy  = 0.0;
                }
            }
        }
        return nby;
    }

    // Current cell index the ball centre is in.
    function curCell(n) {
        var r = by.toNumber();
        var c = bx.toNumber();
        if (r < 0) { r = 0; } if (r >= n) { r = n - 1; }
        if (c < 0) { c = 0; } if (c >= n) { c = n - 1; }
        return r * n + c;
    }

    // True when the ball centre is within half a cell of the exit
    // cell's centre (used for win detection).
    function atCell(cellIdx, n) {
        var r  = cellIdx / n;
        var c  = cellIdx % n;
        var cx = c.toFloat() + 0.5;
        var cy = r.toFloat() + 0.5;
        var dx = bx - cx; var dy = by - cy;
        return (dx*dx + dy*dy) < 0.25; // (0.5)²
    }
}
