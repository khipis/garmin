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
//   Probe 5 points (centre + 4 cardinal samples at 0.45 tile
//   radius).  Radius was raised from 0.30 → 0.45 because:
//     • Monkey C toNumber() truncates toward zero, not floor.
//       At px = -1.29, (px + 0.30) = -0.99 → toNumber() = 0
//       which IS a tile, but at px = -1.31 it's -1.01 → -1,
//       missing the tile by one truncation step.
//     • With MAX_VX = 0.26 t/tick the ball can jump ~0.26
//       tiles in a single tick — more than the old 0.30 margin
//       on turn segments where centerX shifts laterally.
//     • 0.45 gives ~0.45-tile forgiveness margin past each
//       edge tile, while being well within the 3-tile-wide
//       minimum path width introduced in the previous release.
//
//  Additionally, the north/south probes now use the actual px
//  (not the floored ctrTX) so they cover lateral edge cases
//  across the y-axis too.
//
// GRACE PERIOD
//   See GameController._missStreak.  A single missed probe is
//   tolerated for 1 tick before the fall state is entered.
//   This absorbs numerical edge-of-tile artefacts on turns
//   without giving the player a genuine extra life.
//
// FRAGILE / BOOST
//   Unchanged — see original comments.
// ═══════════════════════════════════════════════════════════════

class CollisionSystem {

    // Reusable return array — sample() is called from a single
    // controller path so it's safe to recycle.
    hidden static var _ret;

    // Returns [fell, tile, boosted, tileX, tileY].
    static function sample(px, py, path, physics) {
        var ctrTX = px.toNumber();
        var ctrTY = py.toNumber();
        var ctrTile = path.tileAt(ctrTX, ctrTY);
        var anySolid = (ctrTile != SR_T_NONE);

        // Probe radius 0.45 tiles — covers edge-of-tile transitions
        // that the old 0.30 radius missed on turn segments and at
        // high lateral speed (MAX_VX 0.26 t/tick).
        if (!anySolid) {
            var t1 = path.tileAt((px + 0.45).toNumber(), ctrTY);
            if (t1 != SR_T_NONE) { anySolid = true; }
        }
        if (!anySolid) {
            var t2 = path.tileAt((px - 0.45).toNumber(), ctrTY);
            if (t2 != SR_T_NONE) { anySolid = true; }
        }
        // North/south probes use the actual (non-floored) px so a
        // ball near the lateral edge also gets caught by these.
        if (!anySolid) {
            var t3 = path.tileAt((px).toNumber(), (py + 0.45).toNumber());
            if (t3 != SR_T_NONE) { anySolid = true; }
        }
        if (!anySolid) {
            var t4 = path.tileAt((px).toNumber(), (py - 0.45).toNumber());
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
