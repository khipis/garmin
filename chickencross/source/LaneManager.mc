// ═══════════════════════════════════════════════════════════════
// LaneManager.mc — Layout of the crossing field.
//
// The playfield is BOARD_ROWS × BOARD_COLS tiles, drawn bottom-up
// so row 0 is at the BOTTOM of the screen (chicken's spawn) and
// row BOARD_ROWS-1 is at the TOP (the goal pasture).
//
// Each row has a `Lane` descriptor with:
//   type       LANE_GRASS / LANE_ROAD / LANE_RIVER / LANE_GOAL
//   dir        +1 (obstacles drift right) or -1 (left)
//   spawnGap   minimum tile-gap between obstacles in this lane
//   kindBias   what spawns on this lane (CAR / TRUCK / LOG)
//
// The lane *speed* is computed at runtime from a per-level base
// multiplied by per-row variance — encoded directly in the lane
// list so each row feels a little different.
//
// Layout (top → bottom):
//   row 11   GOAL (the chicken's home)
//   row 10   safe grass
//   rows 9-7 RIVER (3 lanes, logs)
//   row 6    safe median grass
//   rows 5-2 ROAD  (4 lanes, cars + a slow truck row)
//   row 1    safe grass
//   row 0    spawn grass (chicken starts centered here)
// ═══════════════════════════════════════════════════════════════

const BOARD_ROWS = 12;
const BOARD_COLS = 9;

const LANE_GRASS = 0;
const LANE_ROAD  = 1;
const LANE_RIVER = 2;
const LANE_GOAL  = 3;

const KIND_CAR   = 0;
const KIND_TRUCK = 1;
const KIND_LOG   = 2;

class Lane {
    var row;
    var type;
    var dir;          // -1 or +1
    var speedMul;     // 0.6 .. 1.4 — multiplies the global base speed
    var spawnGap;     // tiles between obstacles
    var kindBias;     // KIND_CAR / KIND_TRUCK / KIND_LOG

    function initialize(r, t, d, sm, sg, kb) {
        row = r; type = t; dir = d;
        speedMul = sm; spawnGap = sg; kindBias = kb;
    }
}

class LaneManager {

    // Returns the canonical lane list, ordered by ascending row index.
    static function buildLanes() {
        var ls = [];
        ls.add(new Lane( 0, LANE_GRASS, 0,  0.0, 0, KIND_CAR));   // start
        ls.add(new Lane( 1, LANE_GRASS, 0,  0.0, 0, KIND_CAR));
        ls.add(new Lane( 2, LANE_ROAD,  1,  0.9, 4, KIND_CAR));
        ls.add(new Lane( 3, LANE_ROAD, -1,  0.6, 6, KIND_TRUCK));
        ls.add(new Lane( 4, LANE_ROAD,  1,  1.2, 3, KIND_CAR));
        ls.add(new Lane( 5, LANE_ROAD, -1,  0.8, 4, KIND_CAR));
        ls.add(new Lane( 6, LANE_GRASS, 0,  0.0, 0, KIND_CAR));   // median
        ls.add(new Lane( 7, LANE_RIVER, 1,  0.7, 5, KIND_LOG));
        ls.add(new Lane( 8, LANE_RIVER,-1,  1.0, 4, KIND_LOG));
        ls.add(new Lane( 9, LANE_RIVER, 1,  0.5, 6, KIND_LOG));
        ls.add(new Lane(10, LANE_GRASS, 0,  0.0, 0, KIND_CAR));   // pre-goal
        ls.add(new Lane(11, LANE_GOAL,  0,  0.0, 0, KIND_CAR));
        return ls;
    }

    // Find the lane descriptor for `row`.  Returns null if outside
    // the playfield (shouldn't happen during normal play).
    static function laneAt(lanes, row) {
        for (var i = 0; i < lanes.size(); i++) {
            if (lanes[i].row == row) { return lanes[i]; }
        }
        return null;
    }
}
