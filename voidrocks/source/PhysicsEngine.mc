// ═══════════════════════════════════════════════════════════════
// PhysicsEngine.mc — Pure-function vector helpers for VoidRocks.
//
// The "physics" here is intentionally trivial: every entity has
// (x, y, vx, vy) and we Euler-integrate once per tick.  No real
// physics library, no rigid bodies, just toroidal wrap-around and
// circle-vs-circle hit tests.
//
// All distances are in pixels.  Screen wrap is non-negotiable —
// asteroids roll off one edge and reappear on the opposite one,
// just like the 1979 cabinet.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class PhysicsEngine {

    // Advance (x, y) by (vx, vy) and wrap to [0,sw) × [0,sh).
    // Returns [x, y] (new values; vx/vy are unchanged).
    static function step(x, y, vx, vy, sw, sh) {
        var nx = x + vx;
        var ny = y + vy;
        if (nx < 0)        { nx = nx + sw; }
        else if (nx >= sw) { nx = nx - sw; }
        if (ny < 0)        { ny = ny + sh; }
        else if (ny >= sh) { ny = ny - sh; }
        return [nx, ny];
    }

    // Clamp a velocity vector to MAX magnitude (avoid runaway ship).
    static function capV(vx, vy, maxMag) {
        var v2 = vx * vx + vy * vy;
        var m2 = maxMag * maxMag;
        if (v2 <= m2) { return [vx, vy]; }
        var inv = maxMag / Math.sqrt(v2);
        return [vx * inv, vy * inv];
    }

    // Toroidal squared distance — accounts for wrap-around.
    static function distSq(x1, y1, x2, y2, sw, sh) {
        var dx = x1 - x2; if (dx < 0) { dx = -dx; }
        var dy = y1 - y2; if (dy < 0) { dy = -dy; }
        if (dx > sw / 2) { dx = sw - dx; }
        if (dy > sh / 2) { dy = sh - dy; }
        return dx * dx + dy * dy;
    }

    // Two circles overlap test (with wrap).
    static function circlesHit(cx1, cy1, r1, cx2, cy2, r2, sw, sh) {
        var d2 = distSq(cx1, cy1, cx2, cy2, sw, sh);
        var rs = r1 + r2;
        return d2 < (rs * rs);
    }
}
