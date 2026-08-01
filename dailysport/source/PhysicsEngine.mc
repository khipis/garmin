// ═══════════════════════════════════════════════════════════════════════════
// PhysicsEngine.mc — Deterministic ball flight for DAILY SPORT CHALLENGE.
//
// There is NO randomness anywhere in this file. A given (angle, power) always
// produces the exact same trajectory, so a miss is always something the player
// can read off the screen and correct on the next shot.
//
// Model: point mass with gravity + linear air resistance, integrated with a
// fixed sub-step. The rim is two solid circles (the ends of the ring) and the
// backboard is a vertical segment, so flat shots really do clang off the front
// of the ring instead of sneaking through — the geometry, not a dice roll,
// decides the outcome.
//
// Everything is expressed in pixels and scaled by screen height, and the power
// meter is normalised against the analytically-derived reference speed for the
// current court (see refSpeed), so the game feels identical on a 208 px
// vívoactive and a 416 px fēnix.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;
using Toybox.Math;

// The ball. Flight bookkeeping (what it touched) lives here so the engine can
// tell a swish from a rattled-in shot without extra state.
class DsBall {
    var x;            // Float, px
    var y;            // Float, px
    var px;           // Float, px — position before the last sub-step
    var py;           // Float, px
    var vx;           // Float, px/s
    var vy;           // Float, px/s
    var flying;       // Boolean
    var hitRim;       // Boolean — touched the ring at any point
    var hitBoard;     // Boolean — touched the backboard
    var bounces;      // Number  — floor bounces so far
    var spin;         // Float   — visual only, drives the seam rotation
    var age;          // Float, seconds in flight

    function initialize() {
        x = 0.0; y = 0.0; px = 0.0; py = 0.0; vx = 0.0; vy = 0.0;
        flying = false; hitRim = false; hitBoard = false;
        bounces = 0; spin = 0.0; age = 0.0;
    }
}

// Rim + backboard geometry. `x` is the centre of the ring, `y` its height.
class DsHoop {
    var x;         // Float — ring centre
    var y;         // Float — ring height
    var w;         // Float — ring width (inner opening, outer ends included)
    var baseX;     // Float — resting centre, for the moving-hoop challenge
    var sway;      // Float — horizontal travel amplitude (0 = static)
    var frozen;    // Boolean — held still while a shot is in the air

    function initialize() {
        x = 0.0; y = 0.0; w = 0.0; baseX = 0.0; sway = 0.0; frozen = false;
    }

    function boardX()   as Lang.Float { return x + w / 2.0 + 3.0; }
    function boardTop() as Lang.Float { return y - w * 0.95; }
    function boardBot() as Lang.Float { return y + w * 0.10; }

    // Deterministic sway driven by the run clock, so two players with the same
    // timing face the exact same hoop position.
    function update(runMs as Lang.Number) as Void {
        if (sway <= 0.0 || frozen) { return; }
        var ph = (runMs % 3400) / 3400.0;
        x = baseX + sway * Math.sin(ph * 6.2831853);
    }
}

class PhysicsEngine {
    var g;        // Float — gravity, px/s²
    var r;        // Float — ball radius, px
    var floorY;   // Float — court surface
    var wide;     // Float — screen width, used for the out-of-bounds test

    function initialize() {
        g = DS_GRAVITY; r = 5.0; floorY = 200.0; wide = 240.0;
    }

    // Called once per run: rescale the whole simulation to this screen.
    function configure(w as Lang.Number, h as Lang.Number, fY as Lang.Float) as Void {
        var scale = h.toFloat() / DS_REF_H;
        g      = DS_GRAVITY * scale;
        r      = h * 0.030;
        if (r < 3.0) { r = 3.0; }
        floorY = fY;
        wide   = w.toFloat();
    }

    // Speed (px/s) that drops a drag-free shot at `angDeg` straight into the
    // ring, with a first-order correction for the air resistance the real
    // integrator applies. Used ONLY to normalise the power meter — the shot
    // itself is always resolved by step().
    function refSpeed(lx as Lang.Float, ly as Lang.Float,
                      rx as Lang.Float, ry as Lang.Float,
                      angDeg as Lang.Float) as Lang.Float {
        var dx = rx - lx;
        var dy = ly - ry;                      // > 0 when the ring is higher
        if (dx < 1.0) { dx = 1.0; }
        var a  = angDeg * 0.0174532925;
        var ca = Math.cos(a);
        var den = 2.0 * ca * ca * (dx * Math.tan(a) - dy);
        if (den <= 1.0) { return 400.0; }      // unreachable angle — safe value
        var v = Math.sqrt(g * dx * dx / den);
        if (v < 1.0) { v = 1.0; }
        var t = dx / (v * ca);
        var loss = 1.0 - DS_DRAG * t / 2.0;
        if (loss < 0.65) { loss = 0.65; }
        var comp = 1.0 / loss;
        if (comp > 1.6) { comp = 1.6; }
        return v * comp;
    }

    function launch(b as DsBall, lx as Lang.Float, ly as Lang.Float,
                    angDeg as Lang.Float, speed as Lang.Float) as Void {
        var a = angDeg * 0.0174532925;
        b.x = lx; b.y = ly;
        b.vx =  speed * Math.cos(a);
        b.vy = -speed * Math.sin(a);
        b.flying   = true;
        b.hitRim   = false;
        b.hitBoard = false;
        b.bounces  = 0;
        b.spin     = 0.0;
        b.age      = 0.0;
    }

    // ── Generic flight ──────────────────────────────────────────────────────
    // Gravity and drag, nothing else. The caller tests the (px,py) → (x,y)
    // segment against whatever its own target happens to be, which is what
    // lets a goal mouth, a target face and a putting green share one
    // integrator with the ring — and share its feel, because they share its
    // tuning constants too.
    function integrateFree(b as DsBall, dt as Lang.Float) as Void {
        b.px = b.x;
        b.py = b.y;
        b.vx = b.vx - b.vx * DS_DRAG * dt;
        b.vy = b.vy - b.vy * DS_DRAG * dt + g * dt;
        b.x  = b.x + b.vx * dt;
        b.y  = b.y + b.vy * dt;
        b.spin = b.spin + b.vx * dt * 0.05;
    }

    function onDeck(b as DsBall) as Lang.Boolean { return b.y + r >= floorY; }

    function offScreen(b as DsBall) as Lang.Boolean {
        return b.x - r > wide || b.x + r < 0.0;
    }

    // Advance one frame. Returns DS_OUT_NONE while the ball is still live, or
    // the resolved outcome once the shot is decided.
    function step(b as DsBall, dt as Lang.Float, hoop as DsHoop) as Lang.Number {
        if (!b.flying) { return DS_OUT_NONE; }
        var sub = dt / 2.0;
        for (var i = 0; i < 2; i++) {
            var out = _integrate(b, sub, hoop);
            if (out != DS_OUT_NONE) { b.flying = false; return out; }
        }
        b.age  = b.age + dt;
        b.spin = b.spin + b.vx * dt * 0.05;
        if (b.age > 4.5) { b.flying = false; return DS_OUT_MISS; }
        return DS_OUT_NONE;
    }

    hidden function _integrate(b as DsBall, dt as Lang.Float,
                               hoop as DsHoop) as Lang.Number {
        var prevY = b.y;

        b.vx = b.vx - b.vx * DS_DRAG * dt;
        b.vy = b.vy - b.vy * DS_DRAG * dt + g * dt;
        b.x  = b.x + b.vx * dt;
        b.y  = b.y + b.vy * dt;

        // ── Backboard: a solid vertical face just behind the ring ───────────
        var bx = hoop.boardX();
        if (b.vx > 0.0 && b.x + r >= bx && b.x - r <= bx + 4.0 &&
            b.y >= hoop.boardTop() && b.y <= hoop.boardBot()) {
            b.x  = bx - r;
            b.vx = -b.vx * DS_RESTITUTION;
            b.vy = b.vy * 0.92;
            b.hitBoard = true;
        }

        // ── Ring: the two ends are solid circles ────────────────────────────
        var half = hoop.w / 2.0;
        if (_hitRing(b, hoop.x - half, hoop.y)) { b.hitRim = true; }
        if (_hitRing(b, hoop.x + half, hoop.y)) { b.hitRim = true; }

        // ── Scoring plane: falling through the ring opening ─────────────────
        if (prevY < hoop.y && b.y >= hoop.y && b.vy > 0.0) {
            var off = b.x - hoop.x;
            if (off < 0.0) { off = -off; }
            if (off < half - r * 0.35) {
                if (b.hitBoard) { return DS_OUT_BANK; }
                if (b.hitRim)   { return DS_OUT_RIM; }
                return DS_OUT_SWISH;
            }
        }

        // ── Court surface: one bounce for feel, then the shot is dead ───────
        if (b.y + r >= floorY) {
            b.y  = floorY - r;
            b.bounces = b.bounces + 1;
            if (b.bounces > 1) { return DS_OUT_MISS; }
            b.vy = -b.vy * 0.42;
            b.vx = b.vx * 0.70;
            if (b.vy > -30.0) { return DS_OUT_MISS; }
        }

        if (b.x - r > wide || b.x + r < 0.0) { return DS_OUT_MISS; }
        return DS_OUT_NONE;
    }

    // Circle-vs-circle bounce against one end of the ring. Returns true on
    // contact so the caller can downgrade a swish to a rattled-in shot.
    hidden function _hitRing(b as DsBall, px as Lang.Float,
                             py as Lang.Float) as Lang.Boolean {
        var dx = b.x - px;
        var dy = b.y - py;
        var d2 = dx * dx + dy * dy;
        var rr = r + 1.5;
        if (d2 >= rr * rr || d2 <= 0.0001) { return false; }

        var d  = Math.sqrt(d2);
        var nx = dx / d;
        var ny = dy / d;
        // Push out of the ring end, then reflect along the contact normal.
        b.x = px + nx * rr;
        b.y = py + ny * rr;
        var vn = b.vx * nx + b.vy * ny;
        b.vx = (b.vx - 2.0 * vn * nx) * DS_RESTITUTION;
        b.vy = (b.vy - 2.0 * vn * ny) * DS_RESTITUTION;
        return true;
    }

    // Sample the *real* trajectory (minus collisions) for the on-screen aiming
    // guide, so the guide can never lie about where the ball is going.
    // `frac` trims the preview: 1.0 draws the whole arc, 0.45 only the first
    // stretch (the SHORT guide setting).
    function predict(lx as Lang.Float, ly as Lang.Float,
                     angDeg as Lang.Float, speed as Lang.Float,
                     frac as Lang.Float) as Lang.Array {
        var pts = [];
        var a  = angDeg * 0.0174532925;
        var x  = lx;
        var y  = ly;
        var vx = speed * Math.cos(a);
        var vy = -speed * Math.sin(a);
        var dt = 0.05;
        var maxPts = (18 * frac).toNumber();
        if (maxPts < 3) { maxPts = 3; }
        for (var i = 0; i < 60 && pts.size() < maxPts; i++) {
            vx = vx - vx * DS_DRAG * dt;
            vy = vy - vy * DS_DRAG * dt + g * dt;
            x  = x + vx * dt;
            y  = y + vy * dt;
            if (y + r >= floorY || x > wide) { break; }
            if (i % 2 == 1) { pts.add([x.toNumber(), y.toNumber()]); }
        }
        return pts;
    }
}
