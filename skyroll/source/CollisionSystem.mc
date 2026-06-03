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

    // Reusable return array — sample() is called from a single
    // controller path so it's safe to recycle.  Saves a 5-int
    // allocation every tick.
    hidden static var _ret;

    // Returns [fell, tile, boosted, tileX, tileY].
    static function sample(px, py, path, physics) {
        // Inlined 5-point probe (centre + N / S / E / W at 0.30
        // tile).  Earlier revisions built an array of [px, py]
        // pairs and looped over it — fine for correctness but
        // wasted ~6 allocations per tick just to walk a fixed
        // sequence we can spell out directly.
        var ctrTX = px.toNumber();
        var ctrTY = py.toNumber();
        var ctrTile = path.tileAt(ctrTX, ctrTY);
        var anySolid = (ctrTile != SR_T_NONE);

        if (!anySolid) {
            var t1 = path.tileAt((px + 0.30).toNumber(), ctrTY);
            if (t1 != SR_T_NONE) { anySolid = true; }
        }
        if (!anySolid) {
            var t2 = path.tileAt((px - 0.30).toNumber(), ctrTY);
            if (t2 != SR_T_NONE) { anySolid = true; }
        }
        if (!anySolid) {
            var t3 = path.tileAt(ctrTX, (py + 0.30).toNumber());
            if (t3 != SR_T_NONE) { anySolid = true; }
        }
        if (!anySolid) {
            var t4 = path.tileAt(ctrTX, (py - 0.30).toNumber());
            if (t4 != SR_T_NONE) { anySolid = true; }
        }

        var fell       = !anySolid;
        var boostedNow = false;

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

        if (_ret == null) { _ret = new [5]; }
        _ret[0] = fell;
        _ret[1] = ctrTile;
        _ret[2] = boostedNow;
        _ret[3] = ctrTX;
        _ret[4] = ctrTY;
        return _ret;
    }
}
