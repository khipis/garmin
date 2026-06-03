// ═══════════════════════════════════════════════════════════════
// PathGenerator.mc — Streaming endless path generator.
//
// MEMORY MODEL
//   `tile` is a 2-D ring buffer indexed by (y_idx, x_idx).
//   y_idx = world.y % SR_BUF_Y   (rolls every 32 rows so the
//                                 buffer never grows; old rows are
//                                 overwritten by new ones as the
//                                 ball moves forward)
//   x_idx = world.x + SR_X_HALF  (x in [-SR_X_HALF .. SR_X_HALF-1])
//
//   A tile outside the x range — or any y row not yet generated /
//   already scrolled off — reads as SR_T_NONE.
//
// SEGMENT MODEL
//   Generation runs in "segments".  Each segment has:
//     • kind     — STRAIGHT / TURN_L / TURN_R / NARROW / WIDE /
//                   ZIGZAG / FRAGILE / BOOST
//     • length   — rows
//     • current  — counter from 0..length
//     • centerX  — current centre column of the path
//     • halfW    — half-width: 0 = 1-tile, 1 = 3-tile, 2 = 5-tile
//
// DIFFICULTY RAMP
//   `difficulty()` returns a 0..1 float derived from how far the
//   ball has progressed.  As it climbs, NARROW and ZIGZAG segments
//   become more frequent, WIDE rest zones rarer, and FRAGILE /
//   BOOST patches start appearing.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const SR_SEG_STRAIGHT = 0;
const SR_SEG_TURN_L   = 1;
const SR_SEG_TURN_R   = 2;
const SR_SEG_NARROW   = 3;
const SR_SEG_WIDE     = 4;
const SR_SEG_ZIGZAG   = 5;
const SR_SEG_FRAGILE  = 6;
const SR_SEG_BOOST    = 7;

class PathGenerator {

    var tile;            // int[SR_BUF_Y][SR_BUF_X]
    var breakT;          // int[SR_BUF_Y][SR_BUF_X] — break countdown
    var nextY;           // next world.y row to fill

    // Per-row content bounds (world coords).  rowMinX[yi] is the
    // smallest world.x with a non-empty tile in row yi; rowMaxX[yi]
    // is the largest.  Empty rows store rowMinX > rowMaxX so the
    // renderer can skip them in one comparison instead of scanning
    // SR_BUF_X columns per row.  Cuts the per-frame tileAt call
    // count from ~16 × visible-rows to ~3-5 × visible-rows.
    var rowMinX;
    var rowMaxX;

    // Segment state.
    var segKind;
    var segLen;
    var segCur;
    var centerX;
    var halfW;
    var zigPhase;

    // Difficulty ramp source — bumped by GameController when ball
    // makes forward progress.  0.0 at start, ~1.0 at deep play.
    var distScore;

    hidden var _rng;
    hidden var _diff;

    function initialize() {
        tile    = new [SR_BUF_Y];
        breakT  = new [SR_BUF_Y];
        rowMinX = new [SR_BUF_Y];
        rowMaxX = new [SR_BUF_Y];
        for (var i = 0; i < SR_BUF_Y; i++) {
            tile[i]   = new [SR_BUF_X];
            breakT[i] = new [SR_BUF_X];
            for (var j = 0; j < SR_BUF_X; j++) {
                tile[i][j]   = SR_T_NONE;
                breakT[i][j] = 0;
            }
            rowMinX[i] = 1;   // empty marker: min > max
            rowMaxX[i] = -1;
        }
        nextY     = 0;
        segKind   = SR_SEG_WIDE;
        segLen    = 6;
        segCur    = 0;
        centerX   = 0;
        halfW     = 2;          // 5 tiles wide initial pad (matches WIDE)
        zigPhase  = 0;
        distScore = 0.0;
        _rng      = 9182;
        _diff     = SR_DIFF_NORMAL;
    }

    function reset(seed, diff) {
        _rng  = (seed != 0) ? seed : 31337;
        _diff = diff;
        for (var i = 0; i < SR_BUF_Y; i++) {
            for (var j = 0; j < SR_BUF_X; j++) {
                tile[i][j]   = SR_T_NONE;
                breakT[i][j] = 0;
            }
            rowMinX[i] = 1;
            rowMaxX[i] = -1;
        }
        nextY     = 0;
        segKind   = SR_SEG_WIDE;
        segLen    = 6;
        segCur    = 0;
        centerX   = 0;
        halfW     = 2;
        zigPhase  = 0;
        distScore = 0.0;
    }

    hidden function _lcg()    { _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF; return _rng; }
    hidden function _rand(n)  { return (n <= 1) ? 0 : _lcg() % n; }

    // True if (x, y) world coords are inside the live tile buffer.
    hidden function _inBuf(x, y) {
        if (x < -SR_X_HALF || x >= SR_X_HALF) { return false; }
        if (y < 0)                            { return false; }
        if (y >= nextY)                       { return false; }
        if (y < nextY - SR_BUF_Y)             { return false; }
        return true;
    }

    hidden function _yi(y) {
        var yi = y % SR_BUF_Y;
        if (yi < 0) { yi = yi + SR_BUF_Y; }
        return yi;
    }
    hidden function _xi(x) { return x + SR_X_HALF; }

    // Public tile accessors.
    function tileAt(x, y) {
        if (!_inBuf(x, y)) { return SR_T_NONE; }
        return tile[_yi(y)][_xi(x)];
    }
    function setTile(x, y, t) {
        if (!_inBuf(x, y)) { return; }
        tile[_yi(y)][_xi(x)] = t;
    }
    function breakAt(x, y) {
        if (!_inBuf(x, y)) { return 0; }
        return breakT[_yi(y)][_xi(x)];
    }
    function setBreak(x, y, v) {
        if (!_inBuf(x, y)) { return; }
        breakT[_yi(y)][_xi(x)] = v;
    }

    // Difficulty 0..1 — driven by distScore.
    function difficulty() {
        var d = distScore / 400.0;          // ramps over ~400 tiles
        if (d > 1.0) { d = 1.0; }
        if (d < 0.0) { d = 0.0; }
        // Difficulty preset adds a fixed offset.
        if      (_diff == SR_DIFF_EASY) { d = d * 0.7; }
        else if (_diff == SR_DIFF_HARD) { d = d + 0.25; }
        if (d > 1.0) { d = 1.0; }
        return d;
    }

    // Forward-speed multiplier — speeds the ball up as the run
    // progresses.  PhysicsSystem multiplies the base forward push
    // by this.
    function speedMul() {
        var d = difficulty();
        return 1.0 + d * 1.1;       // up to 2.1× base speed at max
    }

    // Generate enough rows that there are AT LEAST `ahead` rows
    // beyond `ballY`.  Called every tick by GameController.
    function ensureAhead(ballY, ahead) {
        var target = ballY.toNumber() + ahead;
        while (nextY <= target) { _generateRow(); }
    }

    // ── Segment picker ──────────────────────────────────────
    hidden function _pickNextSegment() {
        var d = difficulty();
        var roll = _rand(100);
        // Wide rest zones — more common when fresh, rare when hard.
        var pWide   = 18 - (d * 14).toNumber();
        var pNarrow = 12 + (d * 22).toNumber();
        var pTurn   = 18 + (d *  8).toNumber();
        var pZig    = (d * 18).toNumber();
        var pFrag   = (d * 12).toNumber();
        var pBoost  =  8;
        // Remainder → straight.
        var acc = 0;
        acc = acc + pWide;   if (roll < acc) { _setSeg(SR_SEG_WIDE,    4 + _rand(4));  return; }
        acc = acc + pNarrow; if (roll < acc) { _setSeg(SR_SEG_NARROW,  4 + _rand(4));  return; }
        acc = acc + pTurn;   if (roll < acc) {
            var dir = (_rand(2) == 0) ? SR_SEG_TURN_L : SR_SEG_TURN_R;
            _setSeg(dir, 2 + _rand(3)); return;
        }
        acc = acc + pZig;    if (roll < acc) { _setSeg(SR_SEG_ZIGZAG,  4 + _rand(4));  return; }
        acc = acc + pFrag;   if (roll < acc) { _setSeg(SR_SEG_FRAGILE, 3 + _rand(3));  return; }
        acc = acc + pBoost;  if (roll < acc) { _setSeg(SR_SEG_BOOST,   2 + _rand(2));  return; }
        _setSeg(SR_SEG_STRAIGHT, 4 + _rand(4));
    }
    hidden function _setSeg(kind, len) {
        segKind = kind;
        segLen  = len;
        segCur  = 0;
        // ── Width policy (v1.1) ─────────────────────────────────
        // Original release used halfW=0 (1-tile) for everything
        // except WIDE/STRAIGHT-bonus, which made narrow stretches
        // basically impossible at the higher speed-mul end of the
        // difficulty ramp (the ball moves >2 tiles/tick by then,
        // a 1-tile corridor leaves zero margin).  Player feedback
        // confirmed the 1-tile passages felt unfair, not hard.
        //
        // New floor: every segment is at least 3-tile (halfW=1).
        // WIDE rest zones bump to 5-tile (halfW=2).  Difficulty
        // ramp still tightens the run via:
        //   • segment-kind probability shift (more NARROW/ZIGZAG/
        //     FRAGILE later, fewer WIDE rests)
        //   • forward-speed multiplier (up to 2.1×)
        // — so the game keeps its identity, just stops being a
        // pixel-perfect deathtrap on harder runs.
        if      (kind == SR_SEG_WIDE)    { halfW = 2; }   // 5-wide rest
        else if (kind == SR_SEG_NARROW)  { halfW = 1; }   // 3-wide pinch
        else if (kind == SR_SEG_ZIGZAG)  { halfW = 1; }
        else if (kind == SR_SEG_FRAGILE) { halfW = 1; }
        else if (kind == SR_SEG_BOOST)   { halfW = 1; }
        else if (kind == SR_SEG_TURN_L)  { halfW = 1; }
        else if (kind == SR_SEG_TURN_R)  { halfW = 1; }
        else                              { halfW = (_rand(4) == 0) ? 2 : 1; }
    }

    // ── Row writer ──────────────────────────────────────────
    hidden function _generateRow() {
        if (segCur >= segLen) { _pickNextSegment(); }
        segCur++;

        // Update centerX & special tile placement per segment.
        var placeT = SR_T_NORMAL;
        if (segKind == SR_SEG_TURN_L) {
            if (centerX > -SR_X_HALF + 1) { centerX = centerX - 1; }
        } else if (segKind == SR_SEG_TURN_R) {
            if (centerX < SR_X_HALF - 2)  { centerX = centerX + 1; }
        } else if (segKind == SR_SEG_ZIGZAG) {
            // ±1 every other row.
            zigPhase = zigPhase + 1;
            if ((zigPhase & 1) == 1) {
                if      (zigPhase % 4 == 1 && centerX < SR_X_HALF - 2) { centerX = centerX + 1; }
                else if (zigPhase % 4 == 3 && centerX > -SR_X_HALF + 1) { centerX = centerX - 1; }
            }
        } else if (segKind == SR_SEG_WIDE)    { placeT = SR_T_SOFT; }
        else if (segKind == SR_SEG_FRAGILE)   { placeT = SR_T_FRAGILE; }
        else if (segKind == SR_SEG_BOOST) {
            // Boost segment mostly normal — single boost tile in the
            // middle row so the player has a moment to ride it.
            if (segCur == segLen / 2 + 1) { placeT = SR_T_BOOST; }
            else                            { placeT = SR_T_NORMAL; }
        }

        // Write the path tiles for this row.
        var yi = _yi(nextY);
        var rMin =  9999;
        var rMax = -9999;
        for (var i = -halfW; i <= halfW; i++) {
            var x = centerX + i;
            if (x < -SR_X_HALF || x >= SR_X_HALF) { continue; }
            tile[yi][_xi(x)] = placeT;
            breakT[yi][_xi(x)] = 0;
            if (x < rMin) { rMin = x; }
            if (x > rMax) { rMax = x; }
        }
        // Make sure rest of the row is clear (e.g. a previous turn
        // segment left tiles behind that this narrower segment
        // shouldn't keep).
        for (var x2 = -SR_X_HALF; x2 < SR_X_HALF; x2++) {
            if (x2 < centerX - halfW || x2 > centerX + halfW) {
                tile[yi][_xi(x2)] = SR_T_NONE;
            }
        }
        // Publish row bounds for the renderer's inner-loop short-cut.
        if (rMax >= rMin) {
            rowMinX[yi] = rMin;
            rowMaxX[yi] = rMax;
        } else {
            rowMinX[yi] = 1; rowMaxX[yi] = -1;   // empty marker
        }

        nextY++;
    }

    // ── Per-tick maintenance: countdown breaking tiles, etc. ─
    function tick(ballY) {
        // Decrement break timers on all tiles within the window.
        // Cheap: SR_BUF_X × small window of rows around the ball.
        var y0 = ballY.toNumber() - 4;
        var y1 = ballY.toNumber() + 4;
        for (var y = y0; y < y1; y++) {
            if (!_inBuf(0, y)) { continue; }
            var yi = _yi(y);
            var lo = rowMinX[yi];
            var hi = rowMaxX[yi];
            if (lo > hi) { continue; }      // empty row
            var newLo =  9999;
            var newHi = -9999;
            var anyContent = false;
            for (var x = lo; x <= hi; x++) {
                var xi = _xi(x);
                var t  = tile[yi][xi];
                if (t == SR_T_BREAK) {
                    breakT[yi][xi] = breakT[yi][xi] - 1;
                    if (breakT[yi][xi] <= 0) {
                        tile[yi][xi]   = SR_T_NONE;
                        breakT[yi][xi] = 0;
                        t = SR_T_NONE;
                    }
                }
                if (t != SR_T_NONE) {
                    anyContent = true;
                    if (x < newLo) { newLo = x; }
                    if (x > newHi) { newHi = x; }
                }
            }
            if (anyContent) {
                rowMinX[yi] = newLo;
                rowMaxX[yi] = newHi;
            } else {
                rowMinX[yi] = 1; rowMaxX[yi] = -1;
            }
        }
    }
}
