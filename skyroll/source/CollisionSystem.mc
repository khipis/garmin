// ═══════════════════════════════════════════════════════════════
// CollisionSystem.mc — Ball ↔ path interaction.
//
// One static call per tick from GameController:
//   sample(ball.px, ball.py, path, physics) → returns a struct
//     { fell        : true if the ball just left the path  }
//     { tile        : tile type the ball is now standing on }
//     { boosted     : true if a BOOST tile applied its kick }
//     { tileX, tileY: integer coords of the standing tile  }
//
// SAMPLING WITH FORGIVENESS
//   A 1-tile-wide path is only 30 px wide on screen.  Demanding
//   that the ball CENTRE be perfectly inside the tile would feel
//   punitive on a 50 ms tick.  We instead probe 5 points (centre
//   + 4 cardinal samples at 0.30 tile radius).  As long as ≥1
//   sample lands on a non-empty tile, the ball is safe.
//
// FRAGILE TILES
//   First contact converts SR_T_FRAGILE → SR_T_BREAK and sets a
//   countdown (PathGenerator.setBreak).  The path's per-tick
//   maintenance pass (PathGenerator.tick) decrements the timer
//   and clears the tile when it reaches 0.  Stepping on a
//   BREAK tile that has already started its countdown is
//   harmless — until the timer expires.
//
// BOOST TILES
//   Contact triggers exactly once (boost tile is converted to a
//   normal tile so a hover doesn't compound).
// ═══════════════════════════════════════════════════════════════

class CollisionSystem {

    // Returns [fell, tile, boosted, tileX, tileY].
    static function sample(px, py, path, physics) {
        // Probe 5 points (centre + N / S / E / W at 0.30 tile).
        var probes = [
            [px,        py       ],
            [px + 0.30, py       ],
            [px - 0.30, py       ],
            [px,        py + 0.30],
            [px,        py - 0.30]
        ];
        var anySolid    = false;
        var ctrTile     = SR_T_NONE;
        var ctrTX       = px.toNumber();
        var ctrTY       = py.toNumber();
        var boostedNow  = false;

        for (var i = 0; i < probes.size(); i++) {
            var p   = probes[i];
            var tx  = p[0].toNumber();
            var ty  = p[1].toNumber();
            var t   = path.tileAt(tx, ty);
            if (t != SR_T_NONE) { anySolid = true; }
            if (i == 0) {
                ctrTile = t;
                ctrTX   = tx;
                ctrTY   = ty;
            }
        }

        var fell = !anySolid;

        // Side effects only on the CENTRE-probe tile so a glancing
        // hover near the edge of a boost doesn't fire it.
        if (!fell) {
            if (ctrTile == SR_T_FRAGILE) {
                path.setTile(ctrTX, ctrTY, SR_T_BREAK);
                path.setBreak(ctrTX, ctrTY, SR_BREAK_TICKS);
            } else if (ctrTile == SR_T_BOOST) {
                physics.impulse(0.0, SR_BOOST_KICK.toFloat() / 100.0);
                path.setTile(ctrTX, ctrTY, SR_T_NORMAL);
                boostedNow = true;
            }
        }

        return [fell, ctrTile, boostedNow, ctrTX, ctrTY];
    }
}
