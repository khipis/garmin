// ═══════════════════════════════════════════════════════════════
// CollisionSystem.mc — Resolves what the chicken is touching.
//
// Returned codes:
//   RES_SAFE   the chicken is OK
//   RES_DEAD   the chicken died (hit a car / drowned)
//   RES_GOAL   the chicken reached the goal lane
//
// On RIVER lanes the system also writes the log she's standing on
// into the controller's `drift` field via the return tuple, so the
// next tick can carry her sideways with the current.
// ═══════════════════════════════════════════════════════════════

const RES_SAFE = 0;
const RES_DEAD = 1;
const RES_GOAL = 2;

class CollisionSystem {

    // Returns RES_*.  Caller is responsible for the consequences.
    static function check(lanes, obstacles, player) {
        var ln = LaneManager.laneAt(lanes, player.row);
        if (ln == null) { return RES_DEAD; }

        if (ln.type == LANE_GOAL)  { return RES_GOAL; }
        if (ln.type == LANE_GRASS) { return RES_SAFE; }

        // Road lane: any car/truck on chicken's column → squashed.
        if (ln.type == LANE_ROAD) {
            if (obstacles.anyOnCell(player.row, player.col)) {
                return RES_DEAD;
            }
            return RES_SAFE;
        }

        // River lane: must be standing on a log, or drown.
        if (ln.type == LANE_RIVER) {
            var log = obstacles.logUnder(player.row, player.col);
            if (log == null) { return RES_DEAD; }
            return RES_SAFE;
        }

        return RES_SAFE;
    }

    // Apart from the tile collision, the river current may have
    // carried the chicken off the side of the screen.  This check
    // runs AFTER drift to detect that drowning case.
    static function offBoard(player) {
        if (player.col < 0 || player.col >= BOARD_COLS) { return true; }
        if (player.colFloat < -0.4)                        { return true; }
        if (player.colFloat > BOARD_COLS - 0.6)            { return true; }
        return false;
    }
}
