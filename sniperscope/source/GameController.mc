// ═══════════════════════════════════════════════════════════════
// GameController.mc — Top-level state machine + per-tick wiring.
//
// Owns one instance of every subsystem and drives them in the
// right order each tick:
//
//   1. GyroInput.feed(ax, ay)                 (called from MainView)
//   2. BreathingSystem.tick(gaze)
//   3. AimSystem.tick(gyro, sway)
//   4. TargetManager.tick()
//   5. (if bullet alive) BallisticsSystem.tick(wind)
//
// Game flow:
//
//   MENU
//     ↓ start
//   PLAY (round k of N)        — scan + aim + breathe, single shot
//     ↓ shoot
//   FIRED                      — bullet travels (tick loop continues)
//     ↓ bullet arrives
//   RESULT (hit/miss reveal)   — ~28 ticks of feedback overlay
//     ↓ auto-advance
//   if (round == N-1) → OVER (recap)
//   else              → next PLAY
//
// Persistence (Application.Storage):
//   SS_K_SENS, SS_K_DIFF, SS_K_BEST, SS_K_HS
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Math;
using Toybox.System;

class GameController {

    // ── Subsystems ───────────────────────────────────────────
    var gyro;
    var aim;
    var breath;
    var wind;
    var targets;
    var bullet;

    // ── Top-level state ──────────────────────────────────────
    var state;
    var menuRow;
    var sens;
    var diff;

    // ── Mission ──────────────────────────────────────────────
    var round;          // 0-based current round
    var totalRounds;
    var score;
    var bestScore;
    var headshots;
    var bestHeadshots;
    var roundTimer;     // ticks remaining before auto-miss

    // ── Last shot result (for the RESULT screen) ─────────────
    var lastZone;       // SS_ZONE_*
    var lastWasPrimary;
    var lastImpactX;
    var lastImpactY;
    var lastTargetX;
    var lastTargetY;

    // ── Animation timers ─────────────────────────────────────
    var resultT;
    var recoilT;
    var shakeT;
    var slowmoT;        // > 0 → render scope in slow-mo glow

    // ── Screen dims ──────────────────────────────────────────
    var sw; var sh; var cx; var cy;

    // ── Internal scratch ─────────────────────────────────────
    var tick;
    hidden var _spawnSeed;     // bumped each round for variety

    function initialize() {
        sw = 260; sh = 260; cx = 130; cy = 130;
        gyro    = new GyroInput();
        aim     = new AimSystem();
        breath  = new BreathingSystem();
        wind    = new WindSystem();
        targets = new TargetManager();
        bullet  = new BallisticsSystem();

        state         = SS_MENU;
        menuRow       = SS_ROW_START;
        sens          = SS_SENS_NORMAL;
        diff          = SS_DIFF_NORMAL;
        round         = 0;
        totalRounds   = SS_ROUNDS_DEFAULT;
        score         = 0;
        bestScore     = 0;
        headshots     = 0;
        bestHeadshots = 0;
        roundTimer    = 0;

        lastZone        = SS_ZONE_MISS;
        lastWasPrimary  = false;
        lastImpactX     = 0;
        lastImpactY     = 0;
        lastTargetX     = 0;
        lastTargetY     = 0;

        resultT = 0; recoilT = 0; shakeT = 0; slowmoT = 0;
        tick    = 0;
        _spawnSeed = 1729;

        _loadPrefs();
        gyro.setSensitivity(sens);
        aim.setSensitivity(sens);
        targets.setDifficulty(diff);
    }

    function syncDims(w, h) { sw = w; sh = h; cx = w / 2; cy = h / 2; }

    // ── Persistence ──────────────────────────────────────────
    hidden function _li(k, d) {
        try {
            var v = Application.Storage.getValue(k);
            if (v != null && v instanceof Number) { return v; }
        } catch (e) {}
        return d;
    }
    hidden function _sv(k, v) { try { Application.Storage.setValue(k, v); } catch (e) {} }
    hidden function _loadPrefs() {
        sens = _li(SS_K_SENS, SS_SENS_NORMAL);
        if (sens < 0 || sens > 2) { sens = SS_SENS_NORMAL; }
        diff = _li(SS_K_DIFF, SS_DIFF_NORMAL);
        if (diff < 0 || diff > 2) { diff = SS_DIFF_NORMAL; }
        bestScore     = _li(SS_K_BEST, 0);
        bestHeadshots = _li(SS_K_HS, 0);
    }
    function savePrefs() {
        _sv(SS_K_SENS, sens);
        _sv(SS_K_DIFF, diff);
        _sv(SS_K_BEST, bestScore);
        _sv(SS_K_HS,   bestHeadshots);
    }

    // ── Menu ─────────────────────────────────────────────────
    function menuNext()    { menuRow = (menuRow + 1) % SS_MENU_ROWS; }
    function menuPrev()    { menuRow = (menuRow + SS_MENU_ROWS - 1) % SS_MENU_ROWS; }
    function setMenuRow(r) { if (r >= 0 && r < SS_MENU_ROWS) { menuRow = r; } }
    function menuActivate() {
        if (menuRow == SS_ROW_SENS) {
            sens = (sens + 1) % 3;
            gyro.setSensitivity(sens);
            aim.setSensitivity(sens);
            savePrefs();
            return;
        }
        if (menuRow == SS_ROW_DIFF) {
            diff = (diff + 1) % 3;
            targets.setDifficulty(diff);
            savePrefs();
            return;
        }
        if (menuRow == SS_ROW_START) { _startMission(); }
    }
    function gotoMenu() { state = SS_MENU; savePrefs(); }

    function sensName() {
        if (sens == SS_SENS_LOW)  { return "Low"; }
        if (sens == SS_SENS_HIGH) { return "High"; }
        return "Norm";
    }
    function diffName() {
        if (diff == SS_DIFF_EASY) { return "Easy"; }
        if (diff == SS_DIFF_HARD) { return "Hard"; }
        return "Norm";
    }

    // ── Mission lifecycle ────────────────────────────────────
    hidden function _startMission() {
        round     = 0;
        score     = 0;
        headshots = 0;
        resultT = 0; recoilT = 0; shakeT = 0; slowmoT = 0;
        aim.reset();
        breath.reset();
        gyro.recalibrate();
        _spawnSeed = (_spawnSeed * 1664525 + 1013904223) & 0x7FFFFFFF;
        targets.setSeed(_spawnSeed + 7);
        wind.setSeed(_spawnSeed + 13);
        _beginRound();
        state = SS_PLAY;
    }
    hidden function _beginRound() {
        targets.spawnRound(round);
        wind.roll(diff);
        bullet.clear();
        breath.reset();
        resultT = 0; recoilT = 0; slowmoT = 0;
        roundTimer = SS_ROUND_TIMEOUT;
        state = SS_PLAY;
    }
    hidden function _endMission() {
        if (score > bestScore)         { bestScore = score; }
        if (headshots > bestHeadshots) { bestHeadshots = headshots; }
        savePrefs();
        state = SS_OVER;
    }
    function restart() { _startMission(); }
    function nextRoundOrFinish() {
        round++;
        if (round >= totalRounds) { _endMission(); return; }
        _beginRound();
    }

    // ── Input wiring (from MainView) ────────────────────────
    function handleTilt(ax, ay) { gyro.feed(ax, ay); }
    function recalibrate() {
        gyro.recalibrate();
        aim.reset();
        breath.reset();
    }

    // Fire button — only legal in SS_PLAY when no bullet in flight.
    function shoot() {
        if (state == SS_OVER || state == SS_RESULT) {
            if (state == SS_OVER) { restart(); return; }
            nextRoundOrFinish(); return;
        }
        if (state != SS_PLAY) { return; }
        if (bullet.live != 0) { return; }
        // Aim direction = AimSystem.aim* (gaze + sway).  We snapshot
        // it for the trajectory and for the impact reveal.
        var ay = aim.aimYaw;
        var ap = aim.aimPitch;
        // Pick the slot to score against = closest alive target to
        // the centre of the scope along the current aim line.
        // CollisionSystem resolves zone/decoy afterwards, so this
        // pre-pick is just to fix `maxTtl` (distance) for the trace.
        var bestI = -1;
        var bestD2 = 99999999;
        for (var i = 0; i < SS_TGT_MAX; i++) {
            if (targets.live[i] == 0) { continue; }
            var dy = targets.yaw[i]   - ay;
            var dp = targets.pitch[i] - ap;
            var d2 = (dy * dy * 10000).toNumber() + (dp * dp * 10000).toNumber();
            if (d2 < bestD2) { bestD2 = d2; bestI = i; }
        }
        var zRef;
        if (bestI >= 0) { zRef = targets.z[bestI]; }
        else             { zRef = SS_TARGET_MED; }
        bullet.fire(ay, ap, zRef, bestI);
        recoilT = SS_RECOIL_TICKS;
        shakeT  = 2;
        state   = SS_FIRED;
    }

    // ── Main per-tick update ─────────────────────────────────
    function tickGame() {
        tick++;
        if (resultT > 0) { resultT--; }
        if (recoilT > 0) { recoilT--; }
        if (shakeT  > 0) { shakeT--;  }
        if (slowmoT > 0) { slowmoT--; }

        if (state != SS_PLAY && state != SS_FIRED) { return; }

        // Breath uses the gaze AFTER aim filter, NOT the raw target,
        // so motion is measured in scope-frame ticks (clean & stable).
        breath.tick(aim.gazeYaw, aim.gazePitch);
        aim.tick(gyro.tYaw, gyro.tPitch,
                 breath.swayYaw, breath.swayPitch);

        targets.tick();

        if (state == SS_PLAY) {
            roundTimer--;
            if (roundTimer <= 0) {
                _registerMiss(true);
            }
            return;
        }

        // state == SS_FIRED — drive the bullet
        var arrived = bullet.tick(wind.strength);
        if (arrived) {
            _resolveShot();
        }
    }

    // Convert one target's world (yaw, pitch) to current scope-frame
    // screen position.  Used by the renderer and the collision step.
    function targetScreen(i) {
        var dy = targets.yaw[i]   - aim.gazeYaw;
        var dp = targets.pitch[i] - aim.gazePitch;
        var sx = (cx + dy * SS_FOV).toNumber();
        var sy = (cy + dp * SS_FOV).toNumber();
        return [sx, sy];
    }
    // Silhouette size in px for target `i` — bigger when closer.
    function targetSize(i) {
        var zRef = SS_TARGET_NEAR.toFloat();
        var s    = 22.0 * zRef / targets.z[i].toFloat();
        if (s < 6.0)  { s = 6.0;  }
        if (s > 40.0) { s = 40.0; }
        return s.toNumber();
    }

    // Build a [[sx,sy], ...] list of all current target screen
    // positions (for CollisionSystem.resolve).
    hidden function _allScreens() {
        var pos = new [SS_TGT_MAX];
        var sz  = new [SS_TGT_MAX];
        for (var i = 0; i < SS_TGT_MAX; i++) {
            pos[i] = targetScreen(i);
            sz[i]  = targetSize(i);
        }
        return [pos, sz];
    }

    hidden function _resolveShot() {
        // Where did the bullet end up in the CURRENT scope frame?
        // BallisticsSystem.screenAt projects the world-locked
        // muzzle direction through the current gaze + adds drift,
        // so this matches exactly what the player is seeing.
        var ba = bullet.screenAt(cx, cy, aim.gazeYaw, aim.gazePitch);
        var bx = ba[0];
        var by = ba[1];
        // Pull current screen positions and sizes for all targets.
        var bag = _allScreens();
        var pos = bag[0]; var sizes = bag[1];

        var res    = CollisionSystem.resolve(bx, by, targets, pos, sizes);
        var zone   = res[0]; var tIdx = res[1];
        lastZone        = zone;
        lastImpactX     = bx;
        lastImpactY     = by;
        lastWasPrimary  = false;
        lastTargetX     = bx;
        lastTargetY     = by;

        if (zone != SS_ZONE_MISS && tIdx >= 0) {
            var sp = pos[tIdx];
            lastTargetX    = sp[0];
            lastTargetY    = sp[1];
            lastWasPrimary = (targets.primary[tIdx] == 1);
            if (lastWasPrimary) {
                _registerHit(zone);
            } else {
                _registerDecoyHit();
            }
            targets.kill(tIdx);
        } else {
            _registerMiss(false);
        }
        bullet.clear();
        state   = SS_RESULT;
        resultT = SS_RESULT_TICKS;
        slowmoT = (zone == SS_ZONE_HEAD) ? SS_SLOWMO_TICKS * 2
                : (zone != SS_ZONE_MISS ? SS_SLOWMO_TICKS : 0);
        shakeT  = (zone == SS_ZONE_HEAD) ? 5
                : (zone != SS_ZONE_MISS ? 3 : 1);
    }

    hidden function _registerHit(zone) {
        var pts;
        if      (zone == SS_ZONE_HEAD)  { pts = 250; headshots++; }
        else if (zone == SS_ZONE_CHEST) { pts = 120; }
        else                              { pts =  60; }
        // Difficulty bonus.
        pts = pts + diff * 20;
        // Distance bonus (further → more points).
        // (Handled implicitly via the target spawn distance — far
        // targets are smaller and harder to hit, so getting them at
        // all already feels like more reward.)
        score = score + pts;
    }
    hidden function _registerDecoyHit() {
        score = score - 100;
        if (score < 0) { score = 0; }
    }
    hidden function _registerMiss(timeout) {
        if (timeout) {
            lastZone = SS_ZONE_MISS;
            lastWasPrimary = false;
        }
        state   = SS_RESULT;
        resultT = SS_RESULT_TICKS;
    }

    // Screen-shake offset for renderer.
    function shakeOff() {
        if (shakeT <= 0) { return [0, 0]; }
        var s = 2;
        var ox = ((tick & 1) == 0) ? s : -s;
        var oy = ((tick & 2) == 0) ? s : -s;
        return [ox, oy];
    }

    // True while a bullet is mid-flight (used by InputHandler to
    // ignore further shots).
    function isFiring() { return state == SS_FIRED; }
}
