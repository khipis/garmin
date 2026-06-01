// ═══════════════════════════════════════════════════════════════
// TargetManager.mc — Hostile + decoy spawning, per-tick movement.
//
// One primary target per round + 0-2 decoys (similar silhouette,
// don't count as a hit).
//
// World position:
//   yaw, pitch       — angular position in the scanning field
//   dy, dp           — drift speed (small, gives slow-walk feel)
//   z                — abstract "distance" in m (180 / 320 / 480),
//                      used by ballistics for gravity hold-over
//                      and by RenderRange-based silhouette size
//   cover            — 0-2.  0 = open, 1 = behind low cover (legs
//                      hidden), 2 = behind window (only head/upper
//                      torso visible)
//
// `primaryIdx` is the only one that scores points; everyone else
// is a decoy (civilian / friendly).  Shooting a decoy = penalty.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const SS_TGT_MAX     = 4;

class TargetManager {

    var live;            // int[SS_TGT_MAX]   1=alive
    var yaw;             // float[]
    var pitch;
    var dy;
    var dp;
    var z;               // metres
    var cover;           // 0..2
    var primary;         // int[] 1 if real hostile, 0 if decoy
    var primaryIdx;

    hidden var _rng;
    hidden var _diff;

    function initialize() {
        live    = new [SS_TGT_MAX];
        yaw     = new [SS_TGT_MAX];
        pitch   = new [SS_TGT_MAX];
        dy      = new [SS_TGT_MAX];
        dp      = new [SS_TGT_MAX];
        z       = new [SS_TGT_MAX];
        cover   = new [SS_TGT_MAX];
        primary = new [SS_TGT_MAX];
        for (var i = 0; i < SS_TGT_MAX; i++) {
            live[i] = 0; yaw[i] = 0.0; pitch[i] = 0.0;
            dy[i]   = 0.0; dp[i] = 0.0; z[i] = SS_TARGET_MED;
            cover[i] = 0;  primary[i] = 0;
        }
        primaryIdx = -1;
        _rng       = 1618033;
        _diff      = SS_DIFF_NORMAL;
    }

    function setSeed(s) { _rng = s; if (_rng == 0) { _rng = 1; } }
    function setDifficulty(d) { _diff = d; }

    hidden function _lcg()    { _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF; return _rng; }
    hidden function _rand(n)  { return (n <= 1) ? 0 : _lcg() % n; }
    hidden function _randf()  { return (_lcg() % 10000).toFloat() * 0.0001; }

    // Spawn a fresh round.  `round` (0-based) increases the
    // challenge: smaller targets, more decoys, partial cover.
    function spawnRound(round) {
        for (var i = 0; i < SS_TGT_MAX; i++) {
            live[i] = 0; primary[i] = 0;
        }

        // Pick distance bucket.
        var dist;
        var r = _rand(100);
        if (round <= 0) {
            // First round: always near to teach the mechanic.
            dist = SS_TARGET_NEAR;
        } else if (round == 1 || round == 2) {
            dist = (r < 50) ? SS_TARGET_NEAR : SS_TARGET_MED;
        } else {
            if      (r < 25) { dist = SS_TARGET_NEAR; }
            else if (r < 65) { dist = SS_TARGET_MED;  }
            else              { dist = SS_TARGET_FAR; }
        }

        // Number of decoys grows with round and difficulty.
        var decoys = round / 2 + _diff;
        if (decoys < 0) { decoys = 0; }
        if (decoys > SS_TGT_MAX - 1) { decoys = SS_TGT_MAX - 1; }

        // The primary always exists.  Place it within reachable
        // gaze (slightly biased away from the dead-centre so the
        // player has to actually scan to find it).
        var slot = 0;
        primaryIdx = slot;
        _placeSlot(slot, dist, true, round);
        slot++;

        // Decoys at slightly different distances/positions.
        for (var k = 0; k < decoys && slot < SS_TGT_MAX; k++) {
            var dd;
            var rr = _rand(3);
            if      (rr == 0) { dd = SS_TARGET_NEAR; }
            else if (rr == 1) { dd = SS_TARGET_MED;  }
            else               { dd = SS_TARGET_FAR; }
            _placeSlot(slot, dd, false, round);
            slot++;
        }
    }

    hidden function _placeSlot(i, distance, isPrimary, round) {
        live[i]    = 1;
        primary[i] = isPrimary ? 1 : 0;
        z[i]       = distance;
        // Spawn anywhere in the scannable yaw arc except the very
        // centre (so the player has to look around to find them).
        var ny = (_randf() * 1.8) - 0.9;          // [-0.9 .. +0.9]
        // Bias the primary further out as rounds progress.
        if (isPrimary) {
            var bias = (round > 2) ? 0.55 : 0.35;
            if (ny > -bias && ny < bias) {
                ny = (ny >= 0) ? ny + bias : ny - bias;
            }
            if (ny >  1.3) { ny =  1.3; }
            if (ny < -1.3) { ny = -1.3; }
        }
        yaw[i]   = ny;
        // Pitch: bias slightly downward so the target sits on the
        // visible ground line rather than floating in the sky.
        pitch[i] = (_randf() * 0.7) - 0.15;       // [-0.15 .. +0.55]

        // Slow walk drift — only some targets move.
        var moveRoll = _rand(100);
        var canMove  = (round >= 1 && isPrimary)
                    || (round >= 2 && !isPrimary);
        if (canMove && moveRoll < 50 + round * 8 + _diff * 5) {
            // Direction (left/right) and speed.
            var sign = (_rand(2) == 0) ? -1.0 : 1.0;
            var spd  = 0.0007 + _randf() * 0.0010 + round * 0.0001;
            dy[i] = sign * spd;
        } else {
            dy[i] = 0.0;
        }
        dp[i] = 0.0;

        // Cover increases with rounds and difficulty.
        var cv = 0;
        var cr = _rand(100);
        if (round >= 2 && cr < 25 + _diff * 10) { cv = 1; }
        if (round >= 4 && cr < 12 + _diff *  6) { cv = 2; }
        cover[i] = cv;
    }

    // Per-tick movement (slow walking).
    function tick() {
        for (var i = 0; i < SS_TGT_MAX; i++) {
            if (live[i] == 0) { continue; }
            yaw[i]   = yaw[i]   + dy[i];
            pitch[i] = pitch[i] + dp[i];
            // Bounce at scene edges.
            if (yaw[i] >  1.4) { yaw[i] =  1.4; dy[i] = -dy[i]; }
            if (yaw[i] < -1.4) { yaw[i] = -1.4; dy[i] = -dy[i]; }
        }
    }

    // True if all alive targets are decoys (i.e. the primary is dead).
    function primaryDown() {
        return (primaryIdx < 0 || live[primaryIdx] == 0);
    }

    // Mark slot down (after a hit).
    function kill(i) { if (i >= 0 && i < SS_TGT_MAX) { live[i] = 0; } }
}
