// ═══════════════════════════════════════════════════════════════
// Particles.mc — Small fixed-size particle pool for SkyRoll juice:
// boost sparks, gem pickup sparkle, the ball's speed trail, milestone
// confetti and the death burst.
//
// Particles are stored in SCREEN space in parallel arrays (no per-
// particle object churn). The pool is deliberately small (24 slots)
// so even a full burst is a handful of fills on the 50 ms tick.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

const SRP_N = 24;

class ParticlePool {
    hidden var _x;
    hidden var _y;
    hidden var _vx;
    hidden var _vy;
    hidden var _life;
    hidden var _max;
    hidden var _col;
    hidden var _sz;
    hidden var _grav;

    function initialize() {
        _x    = new [SRP_N];
        _y    = new [SRP_N];
        _vx   = new [SRP_N];
        _vy   = new [SRP_N];
        _life = new [SRP_N];
        _max  = new [SRP_N];
        _col  = new [SRP_N];
        _sz   = new [SRP_N];
        _grav = new [SRP_N];
        for (var i = 0; i < SRP_N; i++) { _life[i] = 0; }
    }

    function clear() {
        for (var i = 0; i < SRP_N; i++) { _life[i] = 0; }
    }

    hidden function _free() {
        for (var i = 0; i < SRP_N; i++) {
            if (_life[i] <= 0) { return i; }
        }
        return -1;
    }

    // Radial burst of `count` particles from (x,y).
    function burst(x, y, count, color, speed, useGrav, lifeTicks, size, biasVy) {
        for (var c = 0; c < count; c++) {
            var i = _free();
            if (i < 0) { return; }
            var ang = (Math.rand() % 360) * 0.01745;
            var sp  = speed * (0.35 + (Math.rand() % 65) / 100.0);
            _x[i]    = x;    _y[i]    = y;
            _vx[i]   = Math.cos(ang) * sp;
            _vy[i]   = Math.sin(ang) * sp + biasVy;
            _life[i] = lifeTicks; _max[i] = lifeTicks;
            _col[i]  = color; _sz[i] = size; _grav[i] = useGrav;
        }
    }

    // A single particle (used for the ball's speed trail).
    function emit(x, y, vx, vy, color, lifeTicks, size, useGrav) {
        var i = _free();
        if (i < 0) { return; }
        _x[i]    = x;    _y[i]    = y;
        _vx[i]   = vx;   _vy[i]   = vy;
        _life[i] = lifeTicks; _max[i] = lifeTicks;
        _col[i]  = color; _sz[i] = size; _grav[i] = useGrav;
    }

    function step() {
        for (var i = 0; i < SRP_N; i++) {
            if (_life[i] <= 0) { continue; }
            _x[i] = _x[i] + _vx[i];
            _y[i] = _y[i] + _vy[i];
            if (_grav[i]) { _vy[i] = _vy[i] + 0.35; }
            _life[i] = _life[i] - 1;
        }
    }

    function draw(dc, shx, shy) {
        for (var i = 0; i < SRP_N; i++) {
            if (_life[i] <= 0) { continue; }
            var s = _sz[i];
            if (_life[i] * 3 < _max[i]) { s = s - 1; }
            if (s < 1) { s = 1; }
            dc.setColor(_col[i], Graphics.COLOR_TRANSPARENT);
            var px = (_x[i] + shx).toNumber();
            var py = (_y[i] + shy).toNumber();
            if (s <= 1) { dc.fillRectangle(px, py, 2, 2); }
            else        { dc.fillCircle(px, py, s); }
        }
    }
}
