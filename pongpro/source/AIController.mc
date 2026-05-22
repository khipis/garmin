// ═══════════════════════════════════════════════════════════════
// AIController.mc — Difficulty-aware steering for the CPU paddle.
//
// Difficulty levels:
//   DIFF_EASY   — slow, reacts only when the ball is in CPU half,
//                 always misses by an "error" margin.
//   DIFF_MEDIUM — full-time tracking with mild latency + error.
//   DIFF_HARD   — predicts ball y at impact (with wall bounces),
//                 fast paddle, no error margin.
//
// All three drive the same Paddle.vy field; the controller never
// touches Paddle.y directly so collision and bound-clamping stay
// inside Paddle.step().
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const DIFF_EASY   = 0;
const DIFF_MEDIUM = 1;
const DIFF_HARD   = 2;

class AIController {
    var difficulty;
    var error;          // current vertical error (recomputed per serve)
    var maxSpeed;       // px/tick paddle can move
    var deadband;       // px tolerance — closer than this → no move
    var reactCounter;   // ticks the AI "freezes" before reacting
    var reactDelay;     // baseline freeze on each new serve

    function initialize() {
        difficulty   = DIFF_MEDIUM;
        error        = 0;
        maxSpeed     = 3.0;
        deadband     = 2;
        reactCounter = 0;
        reactDelay   = 0;
    }

    function setDifficulty(d) {
        difficulty = d;
        if (d == DIFF_EASY) {
            maxSpeed   = 2.4;
            deadband   = 4;
            reactDelay = 6;
        } else if (d == DIFF_MEDIUM) {
            maxSpeed   = 3.4;
            deadband   = 2;
            reactDelay = 3;
        } else {
            maxSpeed   = 4.6;
            deadband   = 1;
            reactDelay = 0;
        }
    }

    // Called once per serve. Resets latency and bakes in a fresh
    // random error so each rally feels different.
    function onServe(maxError) {
        reactCounter = reactDelay;
        if (difficulty == DIFF_HARD) {
            error = 0;
        } else {
            // Easy ±maxError, medium ±maxError/2
            var range = maxError;
            if (difficulty == DIFF_MEDIUM) { range = maxError / 2; }
            error = (Math.rand() % (range * 2 + 1)) - range;
        }
    }

    // Step the AI paddle one tick.
    function step(paddle, ball, playX0, playY0, playX1, playY1) {
        if (reactCounter > 0) {
            reactCounter = reactCounter - 1;
            paddle.vy = 0.0;
            return;
        }

        var targetY = _computeTargetY(paddle, ball, playX0, playY0, playX1, playY1);
        targetY = targetY + error;

        var dy = targetY - paddle.centerY();
        if (dy >  deadband) {
            paddle.vy =  maxSpeed;
        } else if (dy < -deadband) {
            paddle.vy = -maxSpeed;
        } else {
            paddle.vy = 0.0;
        }
    }

    // ── Target picking by difficulty ─────────────────────────────────
    hidden function _computeTargetY(paddle, ball, playX0, playY0, playX1, playY1) {
        if (difficulty == DIFF_EASY) {
            // Only track when ball is on AI side AND moving toward AI.
            var midX = (playX0 + playX1) / 2;
            if (ball.vx <= 0 || ball.x < midX) {
                return (playY0 + playY1) / 2;       // recenter
            }
            return ball.y;
        }
        if (difficulty == DIFF_MEDIUM) {
            // Track ball y always, but no bounce prediction.
            return ball.y;
        }
        // DIFF_HARD — predict y at paddle x with wall bounces.
        // Only run prediction if ball is moving toward us. Otherwise recenter.
        if (ball.vx <= 0) {
            return (playY0 + playY1) / 2;
        }
        return _predictImpactY(ball, playY0, playY1, paddle.x);
    }

    // Closed-form trajectory prediction with vertical bounces.
    // Walks the ball forward analytically along x → finds y(impact x).
    hidden function _predictImpactY(ball, playY0, playY1, targetX) {
        var height = playY1 - playY0;
        if (height <= 0) { return ball.y; }
        if (ball.vx == 0) { return ball.y; }

        // Time to reach targetX (in ticks).
        var t = (targetX - ball.x) * 1.0 / ball.vx;
        if (t < 0) { return ball.y; }

        // Total y travel ignoring walls.
        var yRaw = ball.y - playY0 + ball.vy * t;

        // Mirror-fold into [0..height] using a triangle-wave trick.
        var period = 2 * height;
        var m = yRaw;
        // Wrap into [0..period). Use modulo for floats — emulate.
        while (m < 0)       { m = m + period; }
        while (m >= period) { m = m - period; }
        if (m > height)     { m = period - m; }
        return playY0 + m;
    }
}
