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
using Toybox.Attention;

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

    // ── Spectacular-shot stats (persistent across missions) ──
    // bestDistance  — furthest hostile ever taken down in metres
    // lifetimeKills — total hostiles killed across all sessions
    // bestShotPts   — highest single-shot point value ever scored
    //                 (zone + difficulty + distance + streak bonus,
    //                 all from ONE trigger pull) — the "best shot"
    //                 leaderboard category.
    var bestDistance;
    var lifetimeKills;
    var bestShotPts;

    // ── This-mission "new record" flags (drive recap banner +
    // which extra leaderboard variants get submitted at mission end) ──
    hidden var _newDistFlag;
    hidden var _newShotFlag;
    hidden var _newHeadFlag;

    // ── Headshot streak (combo) ───────────────────────────────
    var headStreak;      // consecutive headshots, resets on any non-head result
    var streakMsg;        // callout text for the RESULT screen ("" = none)
    var streakBonus;      // bonus points awarded on the qualifying shot

    // ── Rotating mission scenery (SS_SCENE_*) ─────────────────
    var scene;

    // ── Muzzle flash (fire feedback) ──────────────────────────
    var muzzleFlashT;

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

    // Sound + haptics master switch (OPTIONS: ss_fx).
    hidden var _fxOn;

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
        bestDistance  = 0;
        lifetimeKills = 0;
        bestShotPts   = 0;
        _newDistFlag  = false;
        _newShotFlag  = false;
        _newHeadFlag  = false;
        headStreak    = 0;
        streakMsg     = "";
        streakBonus   = 0;
        scene         = SS_SCENE_FIELD;
        muzzleFlashT  = 0;

        lastZone        = SS_ZONE_MISS;
        lastWasPrimary  = false;
        lastImpactX     = 0;
        lastImpactY     = 0;
        lastTargetX     = 0;
        lastTargetY     = 0;

        resultT = 0; recoilT = 0; shakeT = 0; slowmoT = 0;
        tick    = 0;
        _spawnSeed = 1729;

        _fxOn = _loadFx();

        _loadPrefs();
        gyro.setSensitivity(sens);
        aim.setSensitivity(sens);
        targets.setDifficulty(diff);
    }

    function syncDims(w, h) { sw = w; sh = h; cx = w / 2; cy = h / 2; }

    // ── Best-effort sound + haptics (silent/absent hardware is fine) ──────
    // kind: 0 light · 1 good hit · 2 miss/penalty · 3 mission clear · 4 fail.
    hidden function _loadFx() {
        try {
            var v = Application.Storage.getValue(SS_FX_KEY);
            if (v instanceof Number && v == 1) { return false; }
        } catch (e) { }
        return true;
    }
    hidden function _tone(kind) {
        if (!_fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :playTone)) { return; }
        var t;
        if      (kind == 0) { t = Attention.TONE_KEY; }
        else if (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
        else if (kind == 2) { t = Attention.TONE_ALERT_LO; }
        else if (kind == 3) { t = Attention.TONE_SUCCESS; }
        else                { t = Attention.TONE_FAILURE; }
        try { Attention.playTone(t); } catch (e) {}
    }
    hidden function _vibe(intensity, duration) {
        if (!_fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :vibrate)) { return; }
        try { Attention.vibrate([new Attention.VibeProfile(intensity, duration)]); } catch (e) {}
    }

    // Optical-scope projection. The watch face is the glass: the reticle stays
    // at its optical centre while the complete world moves beneath it. Scale
    // comes from the real lens radius so the same angular sweep works on every
    // supported watch size.
    function scopeRadius() {
        var mn = (sw < sh) ? sw : sh;
        return mn * SS_SCOPE_PCT / 200;
    }
    function yawScale() {
        var usable = scopeRadius() - 22;
        if (usable < 32) { usable = 32; }
        return usable.toFloat() / SS_TARGET_YAW_LIM;
    }
    function pitchScale() {
        var usable = scopeRadius() - 26;
        if (usable < 28) { usable = 28; }
        return usable.toFloat() / SS_TARGET_PITCH_LIM;
    }
    function reticleScreen() {
        return [cx, cy];
    }

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
        bestDistance  = _li(SS_K_DIST, 0);
        lifetimeKills = _li(SS_K_KILL, 0);
        bestShotPts   = _li(SS_K_SHOT, 0);
    }
    function savePrefs() {
        _sv(SS_K_SENS, sens);
        _sv(SS_K_DIFF, diff);
        _sv(SS_K_BEST, bestScore);
        _sv(SS_K_HS,   bestHeadshots);
        _sv(SS_K_DIST, bestDistance);
        _sv(SS_K_KILL, lifetimeKills);
        _sv(SS_K_SHOT, bestShotPts);
    }

    // Human-readable name for the current mission's scenery.
    function sceneName() {
        if (scene == SS_SCENE_URBAN)   { return "URBAN"; }
        if (scene == SS_SCENE_ROOFTOP) { return "ROOFTOP"; }
        return "FIELD";
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
        _fxOn     = _loadFx();
        round     = 0;
        score     = 0;
        headshots = 0;
        headStreak = 0; streakMsg = ""; streakBonus = 0;
        _newDistFlag = false; _newShotFlag = false; _newHeadFlag = false;
        resultT = 0; recoilT = 0; shakeT = 0; slowmoT = 0; muzzleFlashT = 0;
        aim.reset();
        breath.reset();
        gyro.recalibrate();
        _spawnSeed = (_spawnSeed * 1664525 + 1013904223) & 0x7FFFFFFF;
        targets.setSeed(_spawnSeed + 7);
        wind.setSeed(_spawnSeed + 13);
        // Rotate the map each mission — genuinely different sky/ground/
        // silhouette treatment per scene, not just a recolour.
        scene = (_spawnSeed / 97) % SS_SCENE_COUNT;
        _beginRound();
        state = SS_PLAY;
    }
    hidden function _beginRound() {
        targets.spawnRound(round);
        // Wind continuity — earlier revisions rerolled wind every
        // single round, which made the scene "feel" like a hard
        // reset after every shot (the player had to relearn the
        // hold-over each time).  Now wind only refreshes on the
        // FIRST round and then every 2nd round after, so the
        // player gets to use what they learned for at least one
        // follow-up shot.
        if (round == 0 || (round & 1) == 0) {
            wind.roll(diff);
        }
        bullet.clear();
        // Soft-reset breath: clear the fatigue counter but keep the
        // sway phase running so the scope doesn't visibly snap to
        // a different oscillation phase between rounds.
        breath.softReset();
        resultT = 0; recoilT = 0; slowmoT = 0;
        roundTimer = SS_ROUND_TIMEOUT;
        state = SS_PLAY;
    }
    hidden function _endMission() {
        if (score > bestScore)         { bestScore = score; }
        if (headshots > bestHeadshots) { bestHeadshots = headshots; _newHeadFlag = true; }
        savePrefs();
        // Submit the session's final score to the global leaderboard,
        // split by difficulty variant.  Long-range headshots already
        // feed `score` via the per-shot distance bonus.
        Leaderboard.submitScore(SS_LB_GAME_ID, score, diffName());
        Leaderboard.showPostGame(SS_LB_GAME_ID, diffName(), "SNIPER");
        // Spectacular-shot leaderboards — only submitted when THIS
        // mission actually set a new personal best, so each board
        // fills up with genuine records instead of repeat noise.
        if (_newDistFlag) { Leaderboard.submitScore(SS_LB_GAME_ID, bestDistance, "longest-shot"); }
        if (_newShotFlag) { Leaderboard.submitScore(SS_LB_GAME_ID, bestShotPts,  "best-shot"); }
        if (_newHeadFlag) { Leaderboard.submitScore(SS_LB_GAME_ID, bestHeadshots, "headshots"); }
        // Mission-complete fanfare — bigger celebration on a new record.
        if (_newDistFlag || _newShotFlag || _newHeadFlag) {
            _tone(3);
            _vibe(100, 320);
        } else {
            _tone(3);
            _vibe(70, 160);
        }
        state = SS_OVER;
    }

    // True if this mission set at least one new all-time record —
    // drives the "NEW RECORD!" banner on the recap screen.
    function hasNewRecord() { return _newDistFlag || _newShotFlag || _newHeadFlag; }
    function restart() { _startMission(); }
    // Public entry used by the menu-less MainView (auto-start).
    function startGame() { _startMission(); }
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
        muzzleFlashT = 3;
        // Rifle report + recoil kick.
        _tone(1);
        _vibe(60, 70);
        state   = SS_FIRED;
    }

    // ── Main per-tick update ─────────────────────────────────
    function tickGame() {
        tick++;
        if (resultT > 0) { resultT--; }
        if (recoilT > 0) { recoilT--; }
        if (shakeT  > 0) { shakeT--;  }
        if (slowmoT > 0) { slowmoT--; }
        if (muzzleFlashT > 0) { muzzleFlashT--; }

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

    // Project a world-space target through the current optical axis. Subtracting
    // gaze from every world object is the essential rifle-scope model: turning
    // the watch right moves the complete scene left under a fixed crosshair.
    function targetScreen(i) {
        var sx = (cx + (targets.yaw[i]   - aim.aimYaw)   * yawScale()).toNumber();
        var sy = (cy + (targets.pitch[i] - aim.aimPitch) * pitchScale()).toNumber();
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
        var ba = bullet.screenAt(cx, cy, yawScale(), pitchScale(),
                                 aim.aimYaw, aim.aimPitch);
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
                _registerHit(zone, targets.z[tIdx]);
            } else {
                _registerDecoyHit();
            }
            targets.kill(tIdx);
        } else {
            _registerMiss(false);
        }
        // Freeze (not clear) the bullet so the renderer keeps the
        // tracer on screen for the RESULT freeze frame.  This bridges
        // the shot and the impact visually — earlier revisions made
        // the trace vanish instantly, contributing to the "this is a
        // brand new screen" reset feeling.  Cleared on round advance.
        bullet.freeze();
        state   = SS_RESULT;
        resultT = SS_RESULT_TICKS;
        slowmoT = (zone == SS_ZONE_HEAD) ? SS_SLOWMO_TICKS * 2
                : (zone != SS_ZONE_MISS ? SS_SLOWMO_TICKS : 0);
        shakeT  = (zone == SS_ZONE_HEAD) ? 5
                : (zone != SS_ZONE_MISS ? 3 : 1);
    }

    hidden function _registerHit(zone, distanceM) {
        var pts;
        if      (zone == SS_ZONE_HEAD)  { pts = 250; headshots++; }
        else if (zone == SS_ZONE_CHEST) { pts = 120; }
        else                              { pts =  60; }
        // Difficulty bonus.
        pts = pts + diff * 20;
        // Distance bonus — explicitly rewards taking the harder shot.
        // 1 pt per metre at far range adds ~480 to a far-distance kill.
        pts = pts + distanceM;

        // ── Headshot streak (combo) ──────────────────────────
        // Only headshots build/extend the streak; any other hit
        // zone breaks it (handled below) same as a miss/decoy.
        streakMsg = ""; streakBonus = 0;
        if (zone == SS_ZONE_HEAD) {
            headStreak = headStreak + 1;
            if (headStreak >= 2) {
                streakBonus = SS_STREAK_BONUS * (headStreak - 1);
                pts = pts + streakBonus;
                if      (headStreak == 2) { streakMsg = "DOUBLE HEADSHOT!"; }
                else if (headStreak == 3) { streakMsg = "TRIPLE HEADSHOT!"; }
                else if (headStreak == 4) { streakMsg = "RAMPAGE!"; }
                else                       { streakMsg = "UNSTOPPABLE!"; }
            }
        } else {
            headStreak = 0;
        }

        score = score + pts;

        // Impact feedback — the harder the zone, the meatier the kick.
        if (zone == SS_ZONE_HEAD) {
            _tone(3);
            _vibe(100, 200);
        } else if (zone == SS_ZONE_CHEST) {
            _tone(1);
            _vibe(55, 90);
        } else {
            _tone(0);
            _vibe(35, 55);
        }
        // Extra celebratory blip for a multi-headshot streak callout.
        if (streakBonus > 0) {
            _tone(1);
            _vibe(80, 120);
        }

        // Persistent spectacular-shot stats.
        lifetimeKills = lifetimeKills + 1;
        var flush = false;
        if (distanceM > bestDistance) {
            bestDistance = distanceM;
            _newDistFlag = true;
            flush = true;
        }
        if (pts > bestShotPts) {
            bestShotPts = pts;
            _newShotFlag = true;
            flush = true;
        }
        if (flush || (lifetimeKills & 7) == 0) {
            // Periodically flush so the kill count doesn't get
            // lost if the player quits mid-mission.
            savePrefs();
        }
    }
    hidden function _registerDecoyHit() {
        score = score - 100;
        if (score < 0) { score = 0; }
        headStreak = 0; streakMsg = ""; streakBonus = 0;
        // Hit a civilian/decoy — harsh penalty buzz.
        _tone(4);
        _vibe(90, 220);
    }
    hidden function _registerMiss(timeout) {
        if (timeout) {
            lastZone = SS_ZONE_MISS;
            lastWasPrimary = false;
        }
        headStreak = 0; streakMsg = ""; streakBonus = 0;
        // Clean miss — a low, disappointed thud.
        _tone(2);
        _vibe(40, 90);
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
