// EnemyPool — fixed-size pool, no allocations in game loop.
//
// Per-slot fields (flat int arrays):
//   _type   — enemy type (ET_BULLET / ET_ARCWALL / ET_LASER / ET_RING)
//   _angle  — primary angle in degrees 0–359
//   _radius — for bullets/walls/rings: current distance from centre (px)
//             for lasers: lifetime countdown (ticks)
//   _speed  — pixels/tick (outward) or degrees/tick (laser rotation)
//   _extra  — bullet: unused
//              arcwall / ring: gap half-width in degrees
//              laser: rotation direction (+1 / -1)
//   _alive  — 1 = active slot, 0 = free
//
// Constants used (GameView.mc):
//   ET_BULLET, ET_ARCWALL, ET_LASER, ET_RING
//   MAX_ENEMIES
//   BULLET_HIT_ANG, LASER_HIT_ANG, ARCWALL_TRIGGER, RING_TRIGGER

class EnemyPool {
    hidden var _type;
    hidden var _angle;
    hidden var _radius;
    hidden var _speed;
    hidden var _extra;
    hidden var _alive;

    function initialize() {
        _type   = new [MAX_ENEMIES]; _angle  = new [MAX_ENEMIES];
        _radius = new [MAX_ENEMIES]; _speed  = new [MAX_ENEMIES];
        _extra  = new [MAX_ENEMIES]; _alive  = new [MAX_ENEMIES];
        reset();
    }

    function reset() {
        for (var i = 0; i < MAX_ENEMIES; i++) { _alive[i] = 0; }
    }

    // Allocate a free slot. Silently drops spawn if pool is full.
    function spawn(type, angle, radius, speed, extra) {
        for (var i = 0; i < MAX_ENEMIES; i++) {
            if (_alive[i] != 0) { continue; }
            _type[i]   = type;
            _angle[i]  = angle;
            _radius[i] = radius;
            _speed[i]  = speed;
            _extra[i]  = extra;
            _alive[i]  = 1;
            return;
        }
    }

    // Update all active enemies.
    function update(edgeRadius) {
        for (var i = 0; i < MAX_ENEMIES; i++) {
            if (_alive[i] == 0) { continue; }
            var t = _type[i];
            if (t == ET_BULLET || t == ET_ARCWALL || t == ET_RING) {
                _radius[i] = _radius[i] + _speed[i];
                if (_radius[i] > edgeRadius + 18) { _alive[i] = 0; }
            } else if (t == ET_LASER) {
                // _angle rotates; _radius counts down lifetime
                _angle[i]  = (_angle[i] + _speed[i] * _extra[i] + 360) % 360;
                _radius[i] = _radius[i] - 1;
                if (_radius[i] <= 0) { _alive[i] = 0; }
            }
        }
    }

    // Returns true if any active enemy overlaps the player.
    function checkCollision(playerAngle, edgeR) {
        for (var i = 0; i < MAX_ENEMIES; i++) {
            if (_alive[i] == 0) { continue; }
            var t = _type[i];

            if (t == ET_BULLET) {
                var dr = _radius[i] - edgeR;
                if (dr >= -ARCWALL_TRIGGER && dr <= 10) {
                    if (_adiff(playerAngle, _angle[i]) < BULLET_HIT_ANG) { return true; }
                }
            } else if (t == ET_ARCWALL) {
                var dr2 = _radius[i] - edgeR;
                if (dr2 >= -ARCWALL_TRIGGER && dr2 <= 10) {
                    // player must be in gap; if outside gap → collision
                    if (_adiff(playerAngle, _angle[i]) > _extra[i]) { return true; }
                }
            } else if (t == ET_LASER) {
                if (_adiff(playerAngle, _angle[i]) < LASER_HIT_ANG) { return true; }
            } else if (t == ET_RING) {
                var dr3 = _radius[i] - edgeR;
                if (dr3 >= -RING_TRIGGER && dr3 <= 10) {
                    if (_adiff(playerAngle, _angle[i]) > _extra[i]) { return true; }
                }
            }
        }
        return false;
    }

    // ── accessors for GameView rendering ──────────────────────────────────────
    function isAlive(i)  { return _alive[i];  }
    function getType(i)  { return _type[i];   }
    function getAngle(i) { return _angle[i];  }
    function getRadius(i){ return _radius[i]; }
    function getExtra(i) { return _extra[i];  }

    // Symmetric angle difference, 0–180.
    hidden function _adiff(a, b) {
        var d = (a - b + 360) % 360;
        if (d > 180) { d = 360 - d; }
        return d;
    }
}
