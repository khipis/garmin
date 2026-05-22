// ═══════════════════════════════════════════════════════════════
// PhysicsEngine.mc — Tunables + collision routines.
//
// Approach
//   We use a single-substep integrator (px-per-tick units) which is
//   plenty smooth for a 5-px ball at ~6 px/tick on a 240 px screen
//   — the ball moves less than its own radius per tick under normal
//   conditions, so tunnelling through any wall/bumper/flipper is
//   impossible.
//
// Collision primitives
//   • Wall AABB — clip ball position back inside, reflect the
//     perpendicular component of velocity, multiply by restitution.
//   • Bumper (circle) — distance test; if penetrating, push along
//     the radial axis and reflect with a +score and a small velocity
//     boost (classic bumper "kick").
//   • Flipper (capsule) — closest-point-on-segment test; if
//     penetrating, push out along the segment normal and reflect.
//     If the flipper is in active rotation, add an impulse
//     proportional to angular velocity × distance from pivot.
//
// All routines mutate the Ball directly and return a delta-score
// (zero unless a bumper was struck). Keeping mutation in-place
// avoids per-frame allocations.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class PhysicsEngine {
    static var GRAVITY      = 0.28;         // slightly lighter — more dwell time
    static var WALL_RESTIT  = 0.86;         // bouncier walls
    static var BUMP_RESTIT  = 0.92;
    static var BUMP_KICK    = 2.1;          // bumpers slam noticeably harder
    static var FLIP_RESTIT  = 0.86;         // paddle preserves most speed
    static var FLIP_KICK    = 1.4;          // angular impulse multiplier
    static var FLIP_BASE    = 4.5;          // minimum upward whack on active hit
    static var FLIP_PASSIVE = 1.6;          // tiny bounce when paddle is resting
    static var SLING_KICK   = 4.2;
    static var MAX_SPEED    = 14.0;
    static var MIN_BOUNCE   = 0.4;

    // Integrate one tick. Kept for backwards compat — applies forces,
    // rolls the trail and advances by the full velocity. New code
    // paths should call `applyForces()` + `advance(dtFrac)` so the
    // controller can run multiple sub-step collision passes per tick
    // (essential to stop the ball tunnelling through the flippers).
    static function integrate(ball) {
        applyForces(ball);
        ball.rollTrail();
        ball.x = ball.x + ball.vx;
        ball.y = ball.y + ball.vy;
    }

    // Apply gravity + clamp the ball to MAX_SPEED. Run once per tick.
    static function applyForces(ball) {
        ball.vy = ball.vy + GRAVITY;
        var spd = Math.sqrt(ball.vx * ball.vx + ball.vy * ball.vy);
        if (spd > MAX_SPEED) {
            var scale = MAX_SPEED / spd;
            ball.vx = ball.vx * scale;
            ball.vy = ball.vy * scale;
        }
    }

    // Advance the ball by `dtFrac` of its current velocity. Used by
    // the sub-step collision loop in GameController.
    static function advance(ball, dtFrac) {
        ball.x = ball.x + ball.vx * dtFrac;
        ball.y = ball.y + ball.vy * dtFrac;
    }

    // ── Wall collision (rectangular play area) ──────────────────────
    static function clampToWalls(ball, x0, y0, x1, y1) {
        var r = ball.radius;
        if (ball.x - r < x0) {
            ball.x = x0 + r;
            ball.vx = -ball.vx * WALL_RESTIT;
        }
        if (ball.x + r > x1) {
            ball.x = x1 - r;
            ball.vx = -ball.vx * WALL_RESTIT;
        }
        if (ball.y - r < y0) {
            ball.y = y0 + r;
            ball.vy = -ball.vy * WALL_RESTIT;
        }
        // NOTE: bottom edge is NOT a wall — that's how the ball is
        // lost between the flippers. The controller checks `ball.y > y1`.
    }

    // ── Bumper collision (filled circle) ────────────────────────────
    // Returns true if hit (controller uses this to add score + FX).
    static function collideBumper(ball, bx, by, br) {
        var dx = ball.x - bx;
        var dy = ball.y - by;
        var distSq = dx * dx + dy * dy;
        var minDist = ball.radius + br;
        if (distSq >= minDist * minDist) { return false; }

        var dist = Math.sqrt(distSq);
        if (dist < 0.001) {
            // Pathological exact-overlap: shove ball straight up.
            ball.y  = by - minDist;
            ball.vy = -BUMP_KICK;
            return true;
        }
        // Resolve penetration along normal.
        var nx = dx / dist;
        var ny = dy / dist;
        var pen = minDist - dist;
        ball.x = ball.x + nx * (pen + 0.5);
        ball.y = ball.y + ny * (pen + 0.5);

        // Reflect velocity around normal: v' = v - 2(v.n)n
        var vDotN = ball.vx * nx + ball.vy * ny;
        if (vDotN < 0) {
            ball.vx = ball.vx - 2 * vDotN * nx;
            ball.vy = ball.vy - 2 * vDotN * ny;
        }
        ball.vx = (ball.vx * BUMP_RESTIT) + nx * BUMP_KICK;
        ball.vy = (ball.vy * BUMP_RESTIT) + ny * BUMP_KICK;
        return true;
    }

    // ── Rectangle collision (axis-aligned, used by drop targets) ────
    // Returns true if the ball overlapped the rectangle this frame.
    // Velocity is reflected along the dominant separation axis with a
    // mild restitution loss (drop targets aren't springy — they take
    // a hit and fall).
    static function collideRect(ball, rx, ry, rw, rh) {
        var r  = ball.radius;
        // Closest point on rectangle to ball center.
        var closestX = ball.x;
        var closestY = ball.y;
        if (closestX < rx)         { closestX = rx; }
        if (closestX > rx + rw)    { closestX = rx + rw; }
        if (closestY < ry)         { closestY = ry; }
        if (closestY > ry + rh)    { closestY = ry + rh; }

        var dx = ball.x - closestX;
        var dy = ball.y - closestY;
        var distSq = dx * dx + dy * dy;
        if (distSq >= r * r) { return false; }
        var dist = Math.sqrt(distSq);
        var nx; var ny;
        if (dist < 0.001) {
            // Centre is inside the rectangle — push out via the
            // shallowest face. Required to recover from any tiny
            // tunnelling at low FPS.
            var leftPen   = ball.x - rx;
            var rightPen  = (rx + rw) - ball.x;
            var topPen    = ball.y - ry;
            var bottomPen = (ry + rh) - ball.y;
            var minPen = leftPen;
            nx = -1.0; ny = 0.0;
            if (rightPen  < minPen) { minPen = rightPen;  nx =  1.0; ny =  0.0; }
            if (topPen    < minPen) { minPen = topPen;    nx =  0.0; ny = -1.0; }
            if (bottomPen < minPen) { minPen = bottomPen; nx =  0.0; ny =  1.0; }
            ball.x = ball.x + nx * (r + 1.0);
            ball.y = ball.y + ny * (r + 1.0);
        } else {
            nx = dx / dist;
            ny = dy / dist;
            var pen = r - dist;
            ball.x = ball.x + nx * (pen + 0.5);
            ball.y = ball.y + ny * (pen + 0.5);
        }
        var vDotN = ball.vx * nx + ball.vy * ny;
        if (vDotN < 0) {
            ball.vx = ball.vx - 2 * vDotN * nx;
            ball.vy = ball.vy - 2 * vDotN * ny;
        }
        ball.vx = ball.vx * 0.72;
        ball.vy = ball.vy * 0.72;
        return true;
    }

    // ── Slingshot collision ─────────────────────────────────────────
    // Treats the active edge as a thin line segment with a fixed
    // outward normal (sling.nx, sling.ny). Resolves penetration AND
    // adds an extra velocity boost along the normal — that's what
    // makes slings "kick" the ball back into play.
    static function collideSlingshot(ball, sling) {
        var sx = sling.bx - sling.ax;
        var sy = sling.by - sling.ay;
        var sLen2 = sx * sx + sy * sy;
        if (sLen2 < 0.001) { return false; }

        var t = ((ball.x - sling.ax) * sx + (ball.y - sling.ay) * sy) / sLen2;
        if (t < 0) { t = 0; } if (t > 1) { t = 1; }
        var qx = sling.ax + sx * t;
        var qy = sling.ay + sy * t;
        var dx = ball.x - qx;
        var dy = ball.y - qy;
        var distSq = dx * dx + dy * dy;
        var r = ball.radius;
        if (distSq >= r * r) { return false; }

        var dist = Math.sqrt(distSq);
        // Prefer the pre-computed normal — guarantees we always push
        // the ball into the playfield (not into the back wall).
        var nx = sling.nx;
        var ny = sling.ny;
        if (dist > 0.001) {
            // If the geometric normal agrees with the slingshot's
            // intended outward direction, use it; else stick with
            // the configured normal.
            var gx = dx / dist;
            var gy = dy / dist;
            if (gx * sling.nx + gy * sling.ny > 0) {
                nx = gx; ny = gy;
            }
        }
        var pen = r - dist;
        ball.x = ball.x + nx * (pen + 1.0);
        ball.y = ball.y + ny * (pen + 1.0);

        var vDotN = ball.vx * nx + ball.vy * ny;
        if (vDotN < 0) {
            ball.vx = ball.vx - 2 * vDotN * nx;
            ball.vy = ball.vy - 2 * vDotN * ny;
        }
        // The signature slingshot KICK.
        ball.vx = ball.vx + nx * SLING_KICK;
        ball.vy = ball.vy + ny * SLING_KICK;
        return true;
    }

    // ── Flipper collision (capsule = segment + radius) ──────────────
    // Returns true if a collision was resolved.
    //
    // Physics model (rewritten for a much stronger paddle):
    //   1. Detect ball-capsule overlap.
    //   2. Reflect ball velocity around the contact normal and apply
    //      a high restitution so most speed is preserved.
    //   3. If the flipper is actively swinging UP, GUARANTEE the
    //      outward (normal) component of the post-bounce velocity is
    //      at least `FLIP_BASE + angVel * contactR * FLIP_KICK`. This
    //      makes the kick dominate the ball's vertical motion — even
    //      a falling ball gets slammed back into the playfield.
    //   4. A small `FLIP_PASSIVE` minimum is applied even when the
    //      paddle is at rest so resting-contact taps still pop.
    static function collideFlipper(ball, flipper) {
        var px = flipper.pivotX;
        var py = flipper.pivotY;
        var tx = flipper.tipX();
        var ty = flipper.tipY();
        var sx = tx - px;
        var sy = ty - py;
        var sLen2 = sx * sx + sy * sy;
        if (sLen2 < 0.001) { return false; }

        // Project ball onto segment, clamped to [0,1].
        var t = ((ball.x - px) * sx + (ball.y - py) * sy) / sLen2;
        if (t < 0) { t = 0; } if (t > 1) { t = 1; }
        var qx = px + sx * t;
        var qy = py + sy * t;
        var dx = ball.x - qx;
        var dy = ball.y - qy;
        var distSq = dx * dx + dy * dy;
        var minDist = ball.radius + flipper.radius;
        if (distSq >= minDist * minDist) { return false; }

        var dist = Math.sqrt(distSq);
        var nx; var ny;
        if (dist < 0.001) {
            nx = -sy / Math.sqrt(sLen2);
            ny =  sx / Math.sqrt(sLen2);
            dist = 0.001;
        } else {
            nx = dx / dist;
            ny = dy / dist;
        }
        var pen = minDist - dist;
        ball.x = ball.x + nx * (pen + 0.5);
        ball.y = ball.y + ny * (pen + 0.5);

        // ── Step 2: reflect with high restitution ──
        // Only reflect (and apply restitution damping) when the ball is
        // moving INTO the flipper. If it is already moving away (vDotN >= 0)
        // we skip both so we never accidentally slow a ball that grazed the
        // capsule edge while already bouncing clear.
        var vDotN = ball.vx * nx + ball.vy * ny;
        if (vDotN < 0) {
            ball.vx = ball.vx - 2 * vDotN * nx;
            ball.vy = ball.vy - 2 * vDotN * ny;
            ball.vx = ball.vx * FLIP_RESTIT;
            ball.vy = ball.vy * FLIP_RESTIT;
        }

        // ── Step 3: ensure a minimum outward velocity ──
        var angVel = flipper.angularVelocity();
        var mag = angVel < 0 ? -angVel : angVel;
        var contactR = Math.sqrt((qx - px) * (qx - px)
                               + (qy - py) * (qy - py));
        var kickImpulse;
        if (flipper.active && mag > 0.5) {
            // Strong kick proportional to angular velocity at contact
            kickImpulse = FLIP_BASE
                          + mag * (3.14159 / 180.0) * contactR * FLIP_KICK;
        } else {
            kickImpulse = FLIP_PASSIVE;
        }
        // Re-measure outward component (post-reflection) and clamp it
        // up to the kick floor so the ball never leaves the paddle
        // slower than `kickImpulse` along the contact normal.
        var outV = ball.vx * nx + ball.vy * ny;
        if (outV < kickImpulse) {
            var deltaV = kickImpulse - outV;
            ball.vx = ball.vx + nx * deltaV;
            ball.vy = ball.vy + ny * deltaV;
        }
        return true;
    }
}
