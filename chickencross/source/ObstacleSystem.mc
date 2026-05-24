// ═══════════════════════════════════════════════════════════════
// ObstacleSystem.mc — Cars, trucks and logs moving across lanes.
//
// Each obstacle is a tiny record:
//   row      grid row (matches its Lane)
//   col      LEFT-edge column position (float; sub-tile precision)
//   len      width in tiles (1 for cars, 2-3 for trucks, 2-4 for logs)
//   kind     KIND_CAR / KIND_TRUCK / KIND_LOG
//   dir      ±1, copied from the lane (purely a render aid)
//
// Movement: every game tick the system advances every obstacle by
// `lane.dir * lane.speedMul * baseSpeed`.  When an obstacle scrolls
// fully off-screen it wraps around to the other side (so the lane
// always has roughly the same population without us having to
// spawn-on-demand).
//
// On creation we spread obstacles evenly across each lane so the
// player gets a fair "first sight" of the traffic — not a wall of
// trucks instantly bearing down on them.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class Obstacle {
    var row;
    var col;
    var len;
    var kind;
    var dir;

    function initialize(r, c, l, k, d) {
        row = r; col = c; len = l; kind = k; dir = d;
    }
}

class ObstacleSystem {
    var items;          // Array<Obstacle>
    var baseSpeed;      // tiles per tick at speedMul=1

    function initialize() {
        items = [];
        baseSpeed = 0.08;
    }

    // Re-populate every active lane.  Called when a new level/run
    // starts.  `levelSpeed` is the global base speed (tiles/tick).
    function populate(lanes, levelSpeed) {
        baseSpeed = levelSpeed;
        items = [];
        for (var i = 0; i < lanes.size(); i++) {
            var ln = lanes[i];
            if (ln.type != LANE_ROAD && ln.type != LANE_RIVER) { continue; }
            _populateLane(ln);
        }
    }

    hidden function _populateLane(ln) {
        var l = _kindLen(ln.kindBias);
        // Distribute obstacles every (l + spawnGap) tiles so the lane
        // always looks busy but never impassable.
        var stride = l + ln.spawnGap;
        var col = (Math.rand() % stride) - stride;   // staggered start
        var endCol = BOARD_COLS + stride;
        while (col < endCol) {
            items.add(new Obstacle(ln.row, col, l, ln.kindBias, ln.dir));
            col = col + stride;
        }
    }

    hidden function _kindLen(kind) {
        if (kind == KIND_CAR)   { return 1; }
        if (kind == KIND_TRUCK) { return 3; }
        return 3;                              // logs default to 3
    }

    // Step every obstacle one tick.  Returns the floating-point
    // delta the river logs travelled this tick — handy for the
    // controller to drift a chicken that's standing on a log.
    //
    // Drift bookkeeping: we don't store per-obstacle deltas; instead
    // we recompute log delta for the player from the lane it sits on
    // (see `logDeltaForRow`).  We just advance positions here.
    function tick(lanes) {
        for (var i = 0; i < items.size(); i++) {
            var o  = items[i];
            var ln = LaneManager.laneAt(lanes, o.row);
            if (ln == null) { continue; }
            var dx = ln.dir * ln.speedMul * baseSpeed;
            o.col = o.col + dx;
            // Wrap when fully out of view on either side.
            if (o.col >= BOARD_COLS + 2) {
                o.col = -(o.len + 1);
            } else if (o.col + o.len <= -2) {
                o.col = BOARD_COLS + 1;
            }
        }
    }

    // Per-tick column-drift for the given lane (independent of any
    // particular obstacle).  Used to "ride" a log: the chicken's
    // column changes by exactly this amount each tick.
    function logDeltaForRow(lanes, row) {
        var ln = LaneManager.laneAt(lanes, row);
        if (ln == null || ln.type != LANE_RIVER) { return 0.0; }
        return ln.dir * ln.speedMul * baseSpeed;
    }

    // Chicken hitbox half-width.  The chicken occupies one whole
    // cell visually, but for collision we only count the central
    // 50% — so a car has to be visibly ON her, not just brushing
    // the cell's edge.  Without this the original test fired on a
    // 1 % overlap and the game felt punishingly twitchy.
    hidden static const HITBOX_HALF = 0.25;

    // True if any obstacle on `row` overlaps the chicken's hitbox
    // centred on cell `c`.
    function anyOnCell(row, c) {
        var hb_lo = c + 0.5 - HITBOX_HALF;
        var hb_hi = c + 0.5 + HITBOX_HALF;
        for (var i = 0; i < items.size(); i++) {
            var o = items[i];
            if (o.row != row) { continue; }
            var lo = o.col;
            var hi = o.col + o.len;
            // Interval overlap: hb_hi > lo  AND  hb_lo < hi.
            if (hb_hi > lo && hb_lo < hi) { return true; }
        }
        return false;
    }

    // For rivers: return the obstacle (LOG) that supports `c`, or
    // null if the chicken would fall in the water.  We keep the
    // log check LENIENT — any overlap with the chicken's cell
    // (full 1.0 width) counts as standing on the log; this matches
    // the classic Frogger feel where logs feel "sticky".
    function logUnder(row, c) {
        for (var i = 0; i < items.size(); i++) {
            var o = items[i];
            if (o.row != row) { continue; }
            if (o.kind != KIND_LOG) { continue; }
            var lo = o.col;
            var hi = o.col + o.len;
            if (c + 1 > lo && c < hi) { return o; }
        }
        return null;
    }
}
