// ═══════════════════════════════════════════════════════════════════════════
// GameEngine.mc — Clock, objective and the three-beat shot loop.
//
// Every shot is the same rhythm, and every beat is a decision:
//
//   AIM      an angle marker sweeps 24°..76°   → press to lock the angle
//   POWER    a power meter sweeps 0..100%      → press to lock the power
//   RELEASE  a window closes over 0.72 s       → press on the beat
//
// The release is where "timing" lives. Pressing early sends the shot low and
// short, pressing late sends it high and long, and the deviation is a pure
// linear function of how far off the beat you were — never a dice roll. A
// small dead zone in the middle is a true perfect release, so a swish is
// something you can repeat once you have found it.
//
// The engine is sport-agnostic: it hands (angle, power) to a DsSport and asks
// it to resolve the flight.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;
using Toybox.Math;

class GameEngine {

    // ── Run configuration ───────────────────────────────────────────────────
    var ch;            // DsChallenge — today's objective
    var sport;         // DsSport
    var ranked;        // Boolean — counts for the leaderboard
    var laidOut;       // Boolean — geometry has been built for this screen

    // ── State machine ───────────────────────────────────────────────────────
    var state;         // DS_ST_*
    var stateMs;       // ms spent in the current state
    var runMs;         // ms of play elapsed
    var timeLeft;      // ms remaining on the challenge clock

    // ── Shot in progress ────────────────────────────────────────────────────
    var angle;         // Float, degrees — live during AIM, locked afterwards
    var power;         // Float 0..1     — live during POWER, locked afterwards
    var relT;          // Float 0..1     — position inside the release window
    var relDev;        // Float -1..1    — signed release error of the last shot

    var shotAngle;     // Float — angle the current shot actually launched at
    var shotPower;     // Float — power the current shot actually launched at

    // The last settings that actually went in. The meters ghost these back as
    // faint marks, which is what turns "I got one" into a repeatable shot.
    var goodAngle;     // Float, degrees, < 0 until the first make
    var goodPower;     // Float 0..1,    < 0 until the first make

    // ── Run tally ───────────────────────────────────────────────────────────
    var score;
    var made;
    var swished;
    var attempts;
    var streakNow;
    var streakBest;
    var lastOutcome;

    // ── Result ──────────────────────────────────────────────────────────────
    var completed;     // ran the clock out rather than backing out
    var result;        // Dictionary from ProgressionManager.recordRun
    var submitted;     // Boolean — the score reached the global board

    function initialize(wantRanked as Lang.Boolean) {
        ch      = ChallengeManager.today();
        sport   = DsSports.create(_sportId(wantRanked));
        ranked  = wantRanked;
        laidOut = false;

        state = DS_ST_BRIEF; stateMs = 0; runMs = 0; timeLeft = ch.timeMs;
        angle = sport.aimMin(); power = 0.0; relT = 0.0; relDev = 0.0;
        shotAngle = 0.0; shotPower = 0.0;
        goodAngle = -1.0; goodPower = -1.0;

        score = 0; made = 0; swished = 0; attempts = 0;
        streakNow = 0; streakBest = 0; lastOutcome = DS_OUT_NONE;

        completed = false; result = null; submitted = false;
    }

    // A ranked run is always today's sport — that is the whole premise of the
    // board. Practice is free to be anything, so the player can learn the one
    // they keep losing on, or get a head start on tomorrow's.
    hidden function _sportId(wantRanked as Lang.Boolean) as Lang.String {
        if (wantRanked) { return ch.sportId; }
        var pick = DsUtil.optIndex(DS_K_SPORT, 0, DsSports.count() + 1);
        return (pick > 0) ? DsSports.IDS[pick - 1] : ch.sportId;
    }

    // Called from the view once the real screen size is known.
    function layout(w as Lang.Number, h as Lang.Number) as Void {
        sport.layout(self, w, h);
        laidOut = true;
    }

    function playing() as Lang.Boolean {
        return state >= DS_ST_AIM && state <= DS_ST_FEEDBACK;
    }

    // ── Starting a run ──────────────────────────────────────────────────────
    function beginRun() as Void {
        // Out of energy means the ranked attempt is not available — the game
        // never blocks play, it just stops counting. Energy is charged when the
        // run ends, so opening the app and walking away costs nothing.
        if (ranked && ProgressionManager.energyLeft() <= 0) { ranked = false; }

        runMs = 0;
        timeLeft = ranked ? ch.timeMs : 0;   // practice runs on an open clock
        score = 0; made = 0; swished = 0; attempts = 0;
        streakNow = 0; streakBest = 0; lastOutcome = DS_OUT_NONE;
        completed = false; result = null; submitted = false;
        _beginShot();
    }

    function _beginShot() as Void {
        sport.beginShot(self);
        angle = sport.aimMin();
        power = 0.0;
        relT  = 0.0;
        _enter(DS_ST_AIM);
    }

    function _enter(s as Lang.Number) as Void {
        state = s;
        stateMs = 0;
    }

    // ── Frame ───────────────────────────────────────────────────────────────
    function tick() as Void {
        var dt = DS_TICK_MS;
        stateMs = stateMs + dt;

        if (state == DS_ST_BRIEF || state == DS_ST_RESULT) { return; }

        runMs = runMs + dt;
        if (ranked) {
            timeLeft = timeLeft - dt;
            if (timeLeft < 0) { timeLeft = 0; }
        }
        sport.updateField(runMs);

        if (state == DS_ST_AIM) {
            // Out of time between shots — no half-finished attempt hanging on.
            if (_timeUp()) { finishRun(true); return; }
            angle = sport.aimMin() + _tri(stateMs, 800) * aimSpan();
            return;
        }

        if (state == DS_ST_POWER) {
            if (_timeUp()) { finishRun(true); return; }
            power = _tri(stateMs, 1300);
            return;
        }

        if (state == DS_ST_RELEASE) {
            relT = stateMs.toFloat() / DS_RELEASE_MS;
            if (relT >= 1.0) {
                // Missed the window entirely: the worst legal release.
                relT = 1.0;
                _fire(1.0);
            }
            return;
        }

        if (state == DS_ST_FLIGHT) {
            var out = sport.stepFlight(self, dt / 1000.0);
            if (out != DS_OUT_NONE) { _resolve(out); }
            return;
        }

        if (state == DS_ST_FEEDBACK) {
            if (stateMs >= DS_FEEDBACK_MS) { _nextShot(); }
            return;
        }
    }

    function _timeUp() as Lang.Boolean {
        return ranked && timeLeft <= 0;
    }

    function aimSpan() as Lang.Float {
        var s = sport.aimMax() - sport.aimMin();
        return (s < 1.0) ? 1.0 : s;
    }

    // Triangle wave in 0..1 with `halfMs` per traverse.
    function _tri(ms as Lang.Number, halfMs as Lang.Number) as Lang.Float {
        var t = (ms % (halfMs * 2)).toFloat() / halfMs;
        if (t > 1.0) { t = 2.0 - t; }
        return t;
    }

    // ── Player input ────────────────────────────────────────────────────────
    // One button drives the whole game: lock, lock, release.
    function action() as Void {
        if (state == DS_ST_BRIEF)  { beginRun(); return; }
        if (state == DS_ST_RESULT) { return; }

        if (state == DS_ST_AIM) {
            DsFx.buzz(30, 20);
            _enter(DS_ST_POWER);
            return;
        }
        if (state == DS_ST_POWER) {
            DsFx.buzz(30, 25);
            relT = 0.0;
            _enter(DS_ST_RELEASE);
            return;
        }
        if (state == DS_ST_RELEASE) {
            _fire((relT - 0.5) * 2.0);
            return;
        }
        if (state == DS_ST_FEEDBACK) {
            // Impatient players get to shoot again immediately.
            _nextShot();
            return;
        }
    }

    // `dev` is the signed release error in -1..1. A small band around zero is
    // treated as perfect so a well-timed shot is reproducible.
    function _fire(dev as Lang.Float) as Void {
        dev = DsUtil.clampF(dev, -1.0, 1.0);
        if (DsUtil.absF(dev) < DS_RELEASE_DEAD) { dev = 0.0; }
        relDev = dev;

        // Early = flat, late = high. The penalty is a fraction of the sport's
        // own aim band, so a flat sport played across 30° is not punished
        // three times as hard as basketball for the same slip of the thumb.
        var a = angle + dev * 4.5 * aimSpan() / (DS_AIM_MAX - DS_AIM_MIN);
        var p = power * (1.0 + dev * 0.05);
        p = DsUtil.clampF(p, 0.0, 1.0);

        attempts = attempts + 1;
        shotAngle = a;
        shotPower = p;
        sport.fire(self, a, p);
        DsFx.buzz(40, 35);
        _enter(DS_ST_FLIGHT);
    }

    function _resolve(out as Lang.Number) as Void {
        lastOutcome = out;
        var scored = (out == DS_OUT_SWISH || out == DS_OUT_RIM || out == DS_OUT_BANK);

        if (scored) {
            made = made + 1;
            if (out == DS_OUT_SWISH) { swished = swished + 1; }
            streakNow = streakNow + 1;
            if (streakNow > streakBest) { streakBest = streakNow; }
            goodAngle = shotAngle;
            goodPower = shotPower;
            DsFx.buzz(out == DS_OUT_SWISH ? 120 : 70, out == DS_OUT_SWISH ? 75 : 45);
        } else {
            streakNow = 0;
        }

        var before = score;
        if (ch.type == DS_CH_STREAK) {
            score = streakBest;
        } else {
            score = score + ChallengeManager.pointsFor(ch, out);
        }
        sport.onResolved(self, out, score - before);
        _enter(DS_ST_FEEDBACK);
    }

    function _nextShot() as Void {
        if (_timeUp()) { finishRun(true); return; }
        _beginShot();
    }

    // ── Ending a run ────────────────────────────────────────────────────────
    // `natural` is false when the player walked away mid-run: the score is
    // still shown and still trains the profile, but it never reaches the board.
    function finishRun(natural as Lang.Boolean) as Void {
        if (state == DS_ST_RESULT) { return; }
        completed = natural && ranked;
        if (ranked && attempts > 0) { ProgressionManager.spendEnergy(); }
        result = ProgressionManager.recordRun(ch, score, made, swished, ranked);
        submitted = LeaderboardManager.submitRun(ch, score, ranked, completed);
        _enter(DS_ST_RESULT);
    }

    // BACK: consume it while a run is live (ending the run into the result
    // card), let it pop the view otherwise.
    function back() as Lang.Boolean {
        if (playing() && attempts > 0) {
            finishRun(false);
            return true;
        }
        return false;
    }

    // ── Read-outs for the UI ────────────────────────────────────────────────
    function secondsLeft() as Lang.Number {
        if (!ranked) { return runMs / 1000; }
        return (timeLeft + 999) / 1000;
    }

    function beatTarget() as Lang.Boolean { return ranked && score >= ch.target; }

    function outcomeText() as Lang.String {
        return sport.outcomeText(lastOutcome);
    }

    // Why the last shot went the way it did, phrased so the player knows what
    // to change. The sport gets first say — it knows the ball hit the post or
    // the keeper, which the release timing cannot tell you — and the engine
    // falls back to its own reading of the beat.
    function outcomeHint() as Lang.String {
        var s = sport.outcomeHint();
        if (s.length() > 0) { return s; }
        if (lastOutcome != DS_OUT_MISS) {
            if (relDev == 0.0) { return "perfect release"; }
            return (relDev < 0.0) ? "released early" : "released late";
        }
        if (relDev < 0.0) { return "early: flat and short"; }
        if (relDev > 0.0) { return "late: high and long"; }
        return "angle or power off";
    }

    function outcomeColor() as Lang.Number {
        if (lastOutcome == DS_OUT_SWISH) { return DS_GOLD; }
        if (lastOutcome == DS_OUT_MISS)  { return DS_RED; }
        return DS_GREEN;
    }
}
