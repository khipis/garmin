// ═══════════════════════════════════════════════════════════════
// EnemyManager.mc — Spawning, AI and projection of enemies.
//
// Enemies live in WORLD ANGLES (yaw, pitch).  They optionally
// translate horizontally (yaw drift) — riders strafe, idle stand.
// Each tick we update positions, advance per-type AI timers,
// then project to screen for rendering and hit-checks.
//
// Hit-zone gating (`canHitZone`) implements per-type rules:
//   SHIELD : when `shutT>0` chest/legs are protected (head exposed)
//   HEAVY  : only HEAD shots count (others bounce off armour)
//   others : every zone counts
//
// HP map:
//   IDLE   = 1
//   SHIELD = 1
//   RIDER  = 1
//   HEAVY  = 1 (but only head shots score)
//   ARCHER = 3  (boss)
//
// Layout per round (see GameController._beginRound for the
// numbers).  Spawning fills the pool to a target count for the
// round; we keep the pool topped up while enemies die.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class EnemyManager {
    var live;
    var type;
    var hp;
    var yaw;
    var pitch;
    var dist;        // affects sprite scale (smaller = farther)
    var dyaw;        // angular velocity (riders)
    var pyaw;        // anchor yaw (riders sway around this)
    var phase;       // shield-cycle / archer-fire phase
    var shutT;       // shield down ticks (when SHIELD type)
    var openT;       // shield open window ticks
    var fireT;       // archer-mirror fire timer
    var sx;          // cached screen x
    var sy;          // cached screen y
    var sz;          // cached half-sprite-size

    hidden var _rng;
    hidden var _spawnT;
    hidden var _roundTypeMix;

    function initialize() {
        live   = new [AR_MAX_ENEMIES];
        type   = new [AR_MAX_ENEMIES];
        hp     = new [AR_MAX_ENEMIES];
        yaw    = new [AR_MAX_ENEMIES];
        pitch  = new [AR_MAX_ENEMIES];
        dist   = new [AR_MAX_ENEMIES];
        dyaw   = new [AR_MAX_ENEMIES];
        pyaw   = new [AR_MAX_ENEMIES];
        phase  = new [AR_MAX_ENEMIES];
        shutT  = new [AR_MAX_ENEMIES];
        openT  = new [AR_MAX_ENEMIES];
        fireT  = new [AR_MAX_ENEMIES];
        sx     = new [AR_MAX_ENEMIES];
        sy     = new [AR_MAX_ENEMIES];
        sz     = new [AR_MAX_ENEMIES];
        _rng   = 5743219;
        _spawnT = 0;
        _roundTypeMix = AR_ET_IDLE;
        clearAll();
    }

    function clearAll() {
        for (var i = 0; i < AR_MAX_ENEMIES; i++) {
            live[i] = 0; sx[i] = -9999; sy[i] = -9999; sz[i] = 8;
        }
        _spawnT = 0;
    }

    // Begin a tournament round — pre-spawns initial enemies.
    function beginRound(roundIdx, diff) {
        clearAll();
        _roundTypeMix = roundIdx;
        // Initial spawn — fill 2/3 immediately, the rest trickle in.
        var initial;
        if      (roundIdx == AR_RD_F)  { initial = 1; }   // mirror archer
        else                            { initial = 2 + diff; }
        if (initial > AR_MAX_ENEMIES)   { initial = AR_MAX_ENEMIES; }
        for (var i = 0; i < initial; i++) { _spawn(); }
        _spawnT = 30;
    }

    // Returns the number of currently alive enemies.
    function alive() {
        var c = 0;
        for (var i = 0; i < AR_MAX_ENEMIES; i++) { if (live[i] != 0) { c++; } }
        return c;
    }

    // Per-tick AI + position update.  diff in [0..2].
    // `targetCount` = how many enemies should be alive concurrently.
    function tick(roundIdx, diff, targetCount) {
        for (var i = 0; i < AR_MAX_ENEMIES; i++) {
            if (live[i] == 0) { continue; }
            phase[i]++;
            if (shutT[i] > 0) { shutT[i]--; }
            if (openT[i] > 0) { openT[i]--; }
            if (fireT[i] > 0) { fireT[i]--; }

            if (type[i] == AR_ET_RIDER) {
                // Strafe horizontally around pyaw.  Amplitude kept
                // small (~0.32 rad ≈ 58 px on screen) so the rider
                // stays within view — large excursions made enemies
                // appear to "fly" off-screen and back, especially
                // while the player was also rotating their gaze.
                yaw[i]  = yaw[i] + dyaw[i];
                var amp = 0.32;
                if (yaw[i] >  pyaw[i] + amp) { dyaw[i] = -_abs(dyaw[i]); }
                if (yaw[i] <  pyaw[i] - amp) { dyaw[i] =  _abs(dyaw[i]); }
            } else if (type[i] == AR_ET_SHIELD) {
                // Toggle shield open ↔ closed.
                if (shutT[i] == 0 && openT[i] == 0) {
                    // Open the window briefly, then close again.
                    openT[i] = 14 + _rand(8) - diff * 2;
                    if (openT[i] < 6) { openT[i] = 6; }
                }
                if (openT[i] == 1) {
                    // Re-close after window expires.
                    shutT[i] = 22 + _rand(14) + diff * 4;
                }
            } else if (type[i] == AR_ET_ARCHER) {
                // Sway gently; firing handled by GameController.
                yaw[i] = yaw[i] + Math.sin(phase[i].toFloat() * 0.06) * 0.004;
            }
        }

        // Keep the arena populated.
        if (alive() < targetCount && _spawnT <= 0) {
            _spawn();
            _spawnT = 30 - diff * 5;
            if (_spawnT < 8) { _spawnT = 8; }
        }
        if (_spawnT > 0) { _spawnT--; }
    }

    // Project enemies to screen (called after gaze updates).
    function project(gazeYaw, gazePitch, cx, cy) {
        var TPI = Math.PI * 2.0;
        for (var i = 0; i < AR_MAX_ENEMIES; i++) {
            if (live[i] == 0) { sx[i] = -9999; sy[i] = -9999; continue; }
            var dy = yaw[i]   - gazeYaw;
            var dp = pitch[i] - gazePitch;
            if (dy >  Math.PI) { dy = dy - TPI; }
            if (dy < -Math.PI) { dy = dy + TPI; }
            sx[i] = (cx + dy * AR_FOV).toNumber();
            sy[i] = (cy + dp * AR_FOV).toNumber();
            // Sprite half-size scales with apparent distance.
            // dist range: 60..260 — closer = bigger.
            var s = 24 * 120 / dist[i].toNumber();
            if (s < 6)  { s = 6;  }
            if (s > 40) { s = 40; }
            sz[i] = s;
        }
    }

    // ── Hit-zone gating ─────────────────────────────────────
    // Called by BowSystem to verify a candidate hit is legal.
    function canHitZone(i, zone) {
        var t = type[i];
        if (t == AR_ET_HEAVY) {
            return (zone == AR_HZ_HEAD);
        }
        if (t == AR_ET_SHIELD) {
            // While shield is up (shutT > 0), only HEAD is exposed.
            if (shutT[i] > 0) {
                return (zone == AR_HZ_HEAD);
            }
        }
        return true;
    }

    // Kill enemy `i` (returns the type for the caller's scoring).
    function kill(i) {
        var t = type[i];
        live[i] = 0;
        return t;
    }

    // Damage enemy `i` (for multi-HP bosses).  Returns true if killed.
    function damage(i, amount) {
        hp[i] = hp[i] - amount;
        if (hp[i] <= 0) {
            live[i] = 0;
            return true;
        }
        return false;
    }

    // ── Archer-mirror fire trigger ─────────────────────────
    // Returns idx of the archer ready to shoot at the player,
    // or −1.  Caller spawns the incoming arrow.
    function archerReadyToFire() {
        for (var i = 0; i < AR_MAX_ENEMIES; i++) {
            if (live[i] != 0 && type[i] == AR_ET_ARCHER && fireT[i] <= 0) {
                fireT[i] = 36 + _rand(16);
                return i;
            }
        }
        return -1;
    }

    // ── Spawning ──────────────────────────────────────────
    hidden function _spawn() {
        for (var i = 0; i < AR_MAX_ENEMIES; i++) {
            if (live[i] == 0) { _fillSlot(i); return; }
        }
    }

    hidden function _fillSlot(i) {
        live[i]  = 1;
        phase[i] = _rand(40);
        shutT[i] = 0;
        openT[i] = 0;
        fireT[i] = 0;

        var t;
        if (_roundTypeMix == AR_RD_QF) {
            t = (_rand(100) < 65) ? AR_ET_SHIELD : AR_ET_IDLE;
        } else if (_roundTypeMix == AR_RD_SF) {
            t = (_rand(100) < 70) ? AR_ET_RIDER  : AR_ET_HEAVY;
        } else {
            t = AR_ET_ARCHER;
        }
        type[i] = t;

        // Place around the player's forward arc, all BELOW the horizon so
        // they stand on the ground and never float:
        //   yaw   ∈ [−0.6, 0.6]  — fits on-screen at any watch size
        //   pitch ∈ [ 0.03, 0.27] — strictly positive → always on the ground
        yaw[i]   = (_randf() - 0.5) * 1.2;
        pyaw[i]  = yaw[i];
        pitch[i] = _randf() * 0.24 + 0.03;

        if (t == AR_ET_RIDER) {
            // Slightly slower strafe — combined with the narrower
            // amplitude this keeps the rider trackable while still
            // requiring a steady aim.
            dyaw[i] = (_randf() < 0.5) ? -0.014 : 0.014;
            dist[i] = 120 + _rand(50);
        } else if (t == AR_ET_HEAVY) {
            dist[i] = 110 + _rand(40);
        } else if (t == AR_ET_ARCHER) {
            dist[i] = 140;
            yaw[i]  = 0.0; pyaw[i] = 0.0;
            pitch[i] = 0.10;
            fireT[i] = 40;
        } else if (t == AR_ET_SHIELD) {
            dist[i] = 130 + _rand(50);
            shutT[i] = 18 + _rand(10);
        } else {
            dist[i] = 150 + _rand(60);
        }
        // HP.
        if (t == AR_ET_ARCHER) { hp[i] = 3; }
        else                    { hp[i] = 1; }
    }

    // ── Small helpers ─────────────────────────────────────
    hidden function _abs(v) { return (v < 0) ? -v : v; }
    hidden function _lcg() {
        _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
        return _rng;
    }
    hidden function _rand(n)  { return (n <= 1) ? 0 : _lcg() % n; }
    hidden function _randf()  { return (_lcg() % 10000).toFloat() * 0.0001; }
}
