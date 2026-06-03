// ═══════════════════════════════════════════════════════════════
// BreathingSystem.mc — Idle sway + hold-fatigue + steady window.
//
// Output (per tick):
//   swayYaw, swayPitch     — small angular jitter added to gaze
//   steady                 — 1 inside the steady-aim window, 0 otherwise
//   holdT                  — current "aim held" tick counter
//
// Model:
//   • Two superimposed slow sines drive the natural breathing
//     sway.  Period A ≈ 5.4 s (the macro inhale/exhale), period
//     B ≈ 2.5 s (small heartbeat-ish ripple).
//   • If the player keeps the scope very still (low frame-to-frame
//     gaze delta) for SS_STEADY_HOLD ticks, a brief "steady aim"
//     window opens — sway shrinks to SS_BR_STEADY_GAIN % for
//     SS_STEADY_WINDOW ticks, then fatigue ramps back up.
//   • After SS_HOLD_DECAY ticks of continuous holding, fatigue
//     multiplies the sway by SS_BR_HOLD_PENALTY — the longer
//     you hold, the worse the shake gets, just like a real
//     marksman who's about to lose the line.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class BreathingSystem {

    var swayYaw;
    var swayPitch;
    var steady;        // 1 / 0 — true during the calm window
    var holdT;         // ticks held nearly still
    var fatigue;       // 1.0 .. SS_BR_HOLD_PENALTY

    hidden var _t;                  // local phase tick counter
    hidden var _steadyRemain;
    hidden var _lastYaw;
    hidden var _lastPitch;

    function initialize() {
        swayYaw   = 0.0;
        swayPitch = 0.0;
        steady    = 0;
        holdT     = 0;
        fatigue   = 1.0;
        _t            = 0;
        _steadyRemain = 0;
        _lastYaw      = 0.0;
        _lastPitch    = 0.0;
    }

    function reset() {
        steady = 0; holdT = 0; fatigue = 1.0;
        _t = 0; _steadyRemain = 0;
    }

    // Inter-round reset: zero the fatigue / hold counters but keep
    // the breathing PHASE counter `_t` rolling.  This way the scope
    // sway doesn't visibly snap to a different oscillation phase
    // when a new round begins — the world feels continuous.
    function softReset() {
        steady = 0; holdT = 0; fatigue = 1.0;
        _steadyRemain = 0;
    }

    // Called once per tick.  `gy, gp` are the CURRENT smoothed
    // gaze angles AFTER the AimSystem update — we use the
    // frame-to-frame delta to detect "is the player holding still".
    function tick(gy, gp) {
        _t++;

        var dy = gy - _lastYaw;
        var dp = gp - _lastPitch;
        _lastYaw = gy; _lastPitch = gp;
        var motion = (dy < 0 ? -dy : dy) + (dp < 0 ? -dp : dp);

        // Below this threshold of frame-to-frame gaze motion the
        // player is considered "holding aim".  Tuned to allow
        // natural breathing wobble through without resetting.
        var STILL = 0.012;
        if (motion < STILL) {
            holdT++;
        } else {
            holdT = 0;
            _steadyRemain = 0;
        }

        // Open a steady-aim window after a long enough hold.  Don't
        // re-open it during the same hold — the player has to
        // re-settle.
        if (holdT == SS_STEADY_HOLD) {
            _steadyRemain = SS_STEADY_WINDOW;
        }

        if (_steadyRemain > 0) {
            _steadyRemain--;
            steady = 1;
        } else {
            steady = 0;
        }

        // Fatigue ramps up as the hold drags on past STEADY_HOLD.
        if (holdT > SS_HOLD_DECAY) {
            // Linear ramp from 1.0 → SS_BR_HOLD_PENALTY over 60 ticks.
            var over = holdT - SS_HOLD_DECAY;
            var ramp = (over > 60) ? 1.0 : over.toFloat() / 60.0;
            fatigue = 1.0 + (SS_BR_HOLD_PENALTY - 1.0) * ramp;
        } else {
            fatigue = 1.0;
        }

        // Base sway — two sines.  Math.sin takes radians, so map
        // ticks to a phase via 2π / period.
        var phA = _t.toFloat() * 6.2832 / SS_BR_PER_A_TICKS.toFloat();
        var phB = _t.toFloat() * 6.2832 / SS_BR_PER_B_TICKS.toFloat();
        var sY  = Math.sin(phA)         + Math.sin(phB + 1.31) * 0.45;
        var sP  = Math.cos(phA * 0.95)  + Math.sin(phB * 1.07 + 0.7) * 0.55;

        // Steady window dampens the sway dramatically.
        var damp = 1.0;
        if (steady == 1) {
            damp = SS_BR_STEADY_GAIN.toFloat() / 100.0;
        }

        swayYaw   = sY * SS_BR_AMP_YAW   * fatigue * damp;
        swayPitch = sP * SS_BR_AMP_PITCH * fatigue * damp;
    }
}
