// ═══════════════════════════════════════════════════════════════
// GameController.mc — Archery game state + tournament logic.
//
// PER-ROUND FLOW
//   QF:  Shield Knights — kill killTarget enemies in killTime sec
//   SF:  Horse Riders   — fast strafing targets, mostly chest hits
//   F:   Archer Mirror  — 1 boss with 3 HP, shoots back; survive
//
//   Each round:  killTarget kills in killTime seconds wins it.
//   Time runs out → game over.  Lose all shields → game over.
//   Archer mirror final: kill the archer to win the tournament.
//
// SCORING
//   Head  = 100  Chest = 50  Legs = 20
//   Combo multiplier: every consecutive hit doubles bonus
//     (combo 0→1: +0,  1→2: ×1.2,  2→3: ×1.4,  3+: ×1.6)
//
// PERSISTENCE (Application.Storage):
//   ar_sens, ar_diff, ar_best, ar_bestround
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

class GameController {
    // ── Public state ──────────────────────────────────────────
    var state;
    var menuRow;
    var sens;
    var diff;

    // Modules.
    var gyro;
    var bow;
    var enemies;

    // Game vars.
    var score;
    var bestScore;
    var bestRound;
    var combo;
    var maxCombo;
    var shields;
    var maxShields;

    // Tournament.
    var roundIdx;          // 0..2
    var roundKillTarget;
    var roundKills;
    var roundTime;         // seconds remaining
    var roundTickAcc;      // accumulator for second timer
    var roundTotalSec;
    var roundTargetActive;

    // Misc effects.
    var tick;
    var shakeT;
    var hitFlashT;
    var headshotT;
    var dirty;
    var bannerT;
    var bannerText;
    var lastZone;       // last scored zone (for HUD popup)
    var lastZonePts;
    var lastZoneT;

    // ── Killer-feature hit focus overlay ─────────────────────
    // Triggered on every successful hit.  While `hitFocusT > 0`
    // we render an animated zoom-in on the impact point with
    // expanding rings, a big zone callout and the arrow stuck
    // in the enemy.  Does NOT freeze game time — just a visual
    // emphasis layer on top of everything.
    var hitFocusT;       // ticks remaining (0 = inactive)
    var hitFocusX;
    var hitFocusY;
    var hitFocusZone;
    var hitFocusPts;
    var hitFocusSz;      // sprite half-height of the enemy at impact
    var hitFocusType;    // enemy type, to draw a zoomed silhouette

    // ── Demo / highlights reel ──────────────────────────────
    // demoT counts up from 0 each demo tick.  Specific tick
    // numbers fire pre-canned cinematic hits using hitFocus*.
    var demoT;
    var demoCaption;     // current centered headline ("HIGHLIGHTS")

    // Incoming arrows (only archer mirror).
    var inLive;
    var inX;
    var inY;
    var inVx;
    var inVy;
    var inAge;

    // VFX (impact sparks).
    var vfxLive;
    var vfxX;
    var vfxY;
    var vfxAge;
    var vfxZone;

    // Screen metrics (refreshed each frame).
    var sw;
    var sh;
    var cx;
    var cy;

    // Accel snapshot (filled by MainView each tick).
    var lastAx;
    var lastAy;

    // ── Init ──────────────────────────────────────────────────
    function initialize() {
        sw = 260; sh = 260; cx = 130; cy = 130;
        gyro    = new GyroAim();
        bow     = new BowSystem();
        enemies = new EnemyManager();

        inLive = new [AR_MAX_INCOMING];
        inX    = new [AR_MAX_INCOMING];
        inY    = new [AR_MAX_INCOMING];
        inVx   = new [AR_MAX_INCOMING];
        inVy   = new [AR_MAX_INCOMING];
        inAge  = new [AR_MAX_INCOMING];
        for (var i = 0; i < AR_MAX_INCOMING; i++) { inLive[i] = 0; }

        vfxLive = new [AR_MAX_VFX];
        vfxX    = new [AR_MAX_VFX];
        vfxY    = new [AR_MAX_VFX];
        vfxAge  = new [AR_MAX_VFX];
        vfxZone = new [AR_MAX_VFX];
        for (var i = 0; i < AR_MAX_VFX; i++) { vfxLive[i] = 0; }

        state     = AR_MENU;
        menuRow   = AR_ROW_SENS;
        sens      = AR_SENS_NORMAL;
        diff      = AR_DIFF_NORMAL;
        score     = 0;
        bestScore = 0;
        bestRound = 0;
        combo     = 0;
        maxCombo  = 0;
        shields   = 3;
        maxShields= 3;
        roundIdx  = 0;
        roundKillTarget = 5;
        roundKills      = 0;
        roundTime       = 60;
        roundTickAcc    = 0;
        roundTotalSec   = 60;
        roundTargetActive = 3;
        tick      = 0;
        shakeT    = 0;
        hitFlashT = 0;
        headshotT = 0;
        dirty     = true;
        bannerT   = 0;
        bannerText = "";
        lastZone  = -1;
        lastZonePts = 0;
        lastZoneT = 0;
        hitFocusT    = 0;
        hitFocusX    = 0;
        hitFocusY    = 0;
        hitFocusZone = 0;
        hitFocusPts  = 0;
        hitFocusSz   = 18;
        hitFocusType = AR_ET_IDLE;
        demoT        = 0;
        demoCaption  = "";
        lastAx = 0; lastAy = 0;

        _loadPrefs();
        gyro.setSensitivity(sens);
    }

    // ── Screen sync ───────────────────────────────────────────
    function syncDims(w, h) {
        sw = w; sh = h; cx = w / 2; cy = h / 2;
    }

    // ── Persistence ───────────────────────────────────────────
    hidden function _li(k, d) {
        try {
            var v = Application.Storage.getValue(k);
            if (v != null && v instanceof Number) { return v; }
        } catch (e) {}
        return d;
    }
    hidden function _sv(k, v) { try { Application.Storage.setValue(k, v); } catch (e) {} }
    hidden function _loadPrefs() {
        sens      = _li(AR_K_SENS, AR_SENS_NORMAL); if (sens < 0 || sens > 2) { sens = AR_SENS_NORMAL; }
        diff      = _li(AR_K_DIFF, AR_DIFF_NORMAL); if (diff < 0 || diff > 2) { diff = AR_DIFF_NORMAL; }
        bestScore = _li(AR_K_BEST, 0);
        bestRound = _li(AR_K_BESTROUND, 0);
    }
    function savePrefs() {
        _sv(AR_K_SENS, sens);
        _sv(AR_K_DIFF, diff);
        _sv(AR_K_BEST, bestScore);
        _sv(AR_K_BESTROUND, bestRound);
    }

    // ── Menu ──────────────────────────────────────────────────
    function menuNext()        { menuRow = (menuRow + 1) % AR_MENU_ROWS; dirty = true; }
    function menuPrev()        { menuRow = (menuRow + AR_MENU_ROWS - 1) % AR_MENU_ROWS; dirty = true; }
    function setMenuRow(r)     { if (r >= 0 && r < AR_MENU_ROWS) { menuRow = r; dirty = true; } }
    function menuActivate() {
        if (menuRow == AR_ROW_SENS) { sens = (sens + 1) % 3; gyro.setSensitivity(sens); savePrefs(); }
        else if (menuRow == AR_ROW_DIFF) { diff = (diff + 1) % 3; savePrefs(); }
        else if (menuRow == AR_ROW_DEMO) { _startDemo(); }
        else if (menuRow == AR_ROW_START) { _startTournament(); }
        dirty = true;
    }
    function gotoMenu()  {
        savePrefs();
        state = AR_MENU;
        hitFocusT = 0;
        dirty = true;
    }

    // ── Demo / highlights reel ──────────────────────────────
    // Six scripted cinematic hits over ~10 seconds.  Any input
    // (button / tap / back) returns to the menu immediately.
    hidden function _startDemo() {
        state       = AR_DEMO;
        demoT       = 0;
        demoCaption = "HIGHLIGHTS REEL";
        hitFocusT   = 0;
    }
    hidden function _demoFireHit(zone, etype, pts) {
        hitFocusT    = 22;
        hitFocusZone = zone;
        hitFocusType = etype;
        hitFocusPts  = pts;
        hitFocusX    = cx;
        hitFocusY    = cy;
        hitFocusSz   = 36;
    }
    hidden function _tickDemo() {
        demoT++;
        if (hitFocusT > 0) { hitFocusT--; }

        // Phase 0 — intro banner.
        if (demoT == 1)   { demoCaption = "HIGHLIGHTS REEL"; }
        // Phase 1 — head shot on a shield knight.
        if (demoT == 22)  { demoCaption = "PERFECT HEADSHOT"; _demoFireHit(AR_HZ_HEAD,  AR_ET_SHIELD, 250); }
        // Phase 2 — chest hit on a rider.
        if (demoT == 56)  { demoCaption = "RIDER DOWN";       _demoFireHit(AR_HZ_CHEST, AR_ET_RIDER,   120); }
        // Phase 3 — leg shot on a heavy knight (bypass armour).
        if (demoT == 90)  { demoCaption = "CRIPPLING SHOT";   _demoFireHit(AR_HZ_LEGS,  AR_ET_HEAVY,    60); }
        // Phase 4 — boss kill on the archer.
        if (demoT == 124) { demoCaption = "FINAL BOSS";       _demoFireHit(AR_HZ_HEAD,  AR_ET_ARCHER,  400); }
        // Outro.
        if (demoT == 158) { demoCaption = "TAP / BACK TO EXIT"; }
        if (demoT > 220)  { gotoMenu(); return; }
        dirty = true;
    }
    function sensName()  { return (sens == AR_SENS_LOW) ? "Low" : ((sens == AR_SENS_HIGH) ? "High" : "Norm"); }
    function diffName()  { return (diff == AR_DIFF_EASY) ? "Easy" : ((diff == AR_DIFF_HARD) ? "Hard" : "Norm"); }
    function roundName(idx) {
        if (idx == AR_RD_QF) { return "QUARTER"; }
        if (idx == AR_RD_SF) { return "SEMI"; }
        return "FINAL";
    }

    // ── Tournament ────────────────────────────────────────────
    hidden function _startTournament() {
        score    = 0;
        combo    = 0;
        maxCombo = 0;
        if      (diff == AR_DIFF_EASY) { maxShields = 4; }
        else if (diff == AR_DIFF_HARD) { maxShields = 1; }
        else                            { maxShields = 3; }
        shields = maxShields;
        roundIdx = 0;
        bow.reset();
        gyro.recalibrate();
        _beginRound();
        state = AR_PLAY;
    }

    hidden function _beginRound() {
        enemies.beginRound(roundIdx, diff);
        roundKills = 0;
        // Per-round configuration.
        if (roundIdx == AR_RD_QF) {
            roundKillTarget   = (diff == AR_DIFF_EASY) ? 4 : ((diff == AR_DIFF_HARD) ? 7 : 5);
            roundTotalSec     = 70;
            roundTargetActive = 2 + diff;
        } else if (roundIdx == AR_RD_SF) {
            roundKillTarget   = (diff == AR_DIFF_EASY) ? 4 : ((diff == AR_DIFF_HARD) ? 7 : 5);
            roundTotalSec     = 65;
            roundTargetActive = 2 + diff;
        } else {
            // Final: archer mirror — single boss with 3 HP.
            roundKillTarget   = 1;
            roundTotalSec     = 90;
            roundTargetActive = 1;
        }
        roundTime    = roundTotalSec;
        roundTickAcc = 0;
        bannerText = "ROUND " + (roundIdx + 1).format("%d") + ": " + roundName(roundIdx);
        bannerT    = 30;
        state = AR_INTERMISSION;
    }

    // Called by MainView once per tick with current accel reading.
    function tickGame() {
        tick++;

        // Demo mode runs its own scripted timeline.
        if (state == AR_DEMO) { _tickDemo(); return; }

        // Slow-mo freeze: the first ~4 ticks of the hit-focus
        // overlay pause the whole game so the impact really lands.
        // Gyro keeps updating so the camera doesn't snap when the
        // freeze ends, but enemies, timer and bow are paused.
        var freeze = (state == AR_PLAY && hitFocusT > 18);

        if (hitFocusT > 0) { hitFocusT--; }

        if (freeze) {
            var tens0 = bow.draw.toFloat() * 0.01;
            gyro.update(lastAx, lastAy, tens0);
            dirty = true;
            return;
        }

        if (lastZoneT > 0) { lastZoneT--; }
        if (shakeT    > 0) { shakeT--; }
        if (hitFlashT > 0) { hitFlashT--; }
        if (headshotT > 0) { headshotT--; }
        if (bannerT   > 0) { bannerT--; }
        // VFX age.
        for (var i = 0; i < AR_MAX_VFX; i++) {
            if (vfxLive[i] != 0) {
                vfxAge[i]++;
                if (vfxAge[i] > 9) { vfxLive[i] = 0; }
            }
        }

        // Always update gyro so the menu/play view is responsive.
        var tension = bow.draw.toFloat() * 0.01;
        gyro.update(lastAx, lastAy, tension);

        if (state == AR_INTERMISSION) {
            if (bannerT <= 0) { state = AR_PLAY; }
            return;
        }
        if (state != AR_PLAY) { return; }

        // Round timer.
        roundTickAcc = roundTickAcc + AR_TICK_MS;
        if (roundTickAcc >= 1000) {
            roundTickAcc = roundTickAcc - 1000;
            roundTime    = roundTime - 1;
            if (roundTime <= 0) { _gameOver(); return; }
        }

        // Enemies tick + project.
        enemies.tick(roundIdx, diff, roundTargetActive);
        enemies.project(gyro.aimYaw, gyro.aimPitch, cx, cy);

        // Incoming arrows from archer mirror.
        if (roundIdx == AR_RD_F) { _archerFireTick(); }
        _advanceIncomingArrows();

        // Bow + arrows.
        var hits = bow.tick(enemies, cx, cy, sw, sh);
        for (var i = 0; i < hits.size(); i++) {
            var h = hits[i];
            _handleHit(h[0], h[1], h[2], h[3]);
        }

        dirty = true;
    }

    hidden function _handleHit(eIdx, zone, lx, ly) {
        // Score.
        var pts;
        if      (zone == AR_HZ_HEAD)  { pts = 100; }
        else if (zone == AR_HZ_CHEST) { pts = 50;  }
        else                           { pts = 20;  }
        // Combo multiplier.
        combo++;
        if (combo > maxCombo) { maxCombo = combo; }
        var mult;
        if      (combo >= 4) { mult = 16; }     // ×1.6
        else if (combo == 3) { mult = 14; }
        else if (combo == 2) { mult = 12; }
        else                  { mult = 10; }
        pts = pts * mult / 10;
        score = score + pts;
        lastZone   = zone;
        lastZonePts = pts;
        lastZoneT  = 14;

        // VFX.
        _addVfx(lx, ly, zone);

        // Killer-feature hit-focus overlay (full-screen close-up
        // of the arrow penetrating the knight).  hitFocusT counts
        // down from 22; while it's > 18 the game freezes for a
        // slow-motion impact moment.
        hitFocusT    = 22;
        hitFocusX    = lx;
        hitFocusY    = ly;
        hitFocusZone = zone;
        hitFocusPts  = pts;
        hitFocusSz   = enemies.sz[eIdx];
        if (hitFocusSz < 12) { hitFocusSz = 12; }
        hitFocusType = enemies.type[eIdx];

        // Headshot stinger.
        if (zone == AR_HZ_HEAD) {
            headshotT = 8;
            shakeT    = 4;
        } else {
            shakeT    = 2;
        }

        // Damage enemy.
        var t = enemies.type[eIdx];
        var killed;
        if (t == AR_ET_ARCHER) { killed = enemies.damage(eIdx, 1); }
        else                    { killed = enemies.damage(eIdx, 99); }
        if (killed) {
            roundKills++;
            if (roundKills >= roundKillTarget) { _roundComplete(); }
        }
    }

    hidden function _addVfx(x, y, zone) {
        for (var i = 0; i < AR_MAX_VFX; i++) {
            if (vfxLive[i] == 0) {
                vfxLive[i] = 1; vfxX[i] = x; vfxY[i] = y;
                vfxAge[i] = 0;  vfxZone[i] = zone;
                return;
            }
        }
    }

    hidden function _roundComplete() {
        // Time-bonus + rebuild combo state.
        score = score + 50 * roundTime;
        if (roundIdx == AR_NUM_ROUNDS - 1) {
            // Tournament won!
            if (score > bestScore) { bestScore = score; }
            if (roundIdx + 1 > bestRound) { bestRound = roundIdx + 1; }
            savePrefs();
            state = AR_WIN;
            return;
        }
        // Advance.
        if (roundIdx + 1 > bestRound) { bestRound = roundIdx + 1; }
        roundIdx++;
        combo = 0;
        _beginRound();
    }

    hidden function _gameOver() {
        if (score > bestScore) { bestScore = score; }
        savePrefs();
        state = AR_OVER;
    }

    // Called by InputHandler / MainView when button or touch is down.
    function startDraw() {
        if (state == AR_DEMO) { gotoMenu(); return; }
        if (state == AR_OVER || state == AR_WIN) { restart(); return; }
        if (state != AR_PLAY) { return; }
        bow.startDraw();
    }
    // Called when button released.  bowY/cx are the bow tip position.
    function releaseDraw() {
        if (state != AR_PLAY) { return; }
        var bx = cx;
        var by = (sh * 88) / 100;
        bow.release(bx, by, cx, cy);
    }
    function restart() { _startTournament(); }
    function recalibrate() { gyro.recalibrate(); }

    function shakeOff() {
        if (shakeT <= 0) { return [0, 0]; }
        var s = (headshotT > 0) ? 3 : 2;
        var ox = ((tick & 1) == 0) ? s : -s;
        var oy = ((tick & 2) == 0) ? s : -s;
        return [ox, oy];
    }

    // ── Archer-mirror incoming arrows ─────────────────────────
    hidden function _archerFireTick() {
        var i = enemies.archerReadyToFire();
        if (i < 0) { return; }
        var sxA = enemies.sx[i];
        var syA = enemies.sy[i];
        if (sxA < -200 || sxA > sw + 200) { return; }
        // Aim slightly above player centre so the arc visually arcs.
        var dx = (cx - sxA).toFloat();
        var dy = (cy - syA).toFloat();
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < 1.0) { return; }
        var spd = 4.5;
        var vx  = dx / dist * spd;
        var vy  = dy / dist * spd - 0.6;     // small upward bias
        for (var k = 0; k < AR_MAX_INCOMING; k++) {
            if (inLive[k] == 0) {
                inLive[k] = 1;
                inX[k]    = sxA.toFloat();
                inY[k]    = syA.toFloat();
                inVx[k]   = vx;
                inVy[k]   = vy;
                inAge[k]  = 0;
                return;
            }
        }
    }
    hidden function _advanceIncomingArrows() {
        for (var i = 0; i < AR_MAX_INCOMING; i++) {
            if (inLive[i] == 0) { continue; }
            inAge[i]++;
            // Gravity.
            inVy[i] = inVy[i] + 0.15;
            inX[i]  = inX[i] + inVx[i];
            inY[i]  = inY[i] + inVy[i];
            // Hit player (within ~14 px of centre)?
            var dx = inX[i] - cx;
            var dy = inY[i] - cy;
            if (dx * dx + dy * dy < 200) {
                inLive[i] = 0;
                _takeDamage();
                continue;
            }
            // Off-screen.
            if (inAge[i] > 50 || inY[i] > sh + 30 ||
                inX[i] < -40 || inX[i] > sw + 40) {
                inLive[i] = 0;
            }
        }
    }
    hidden function _takeDamage() {
        hitFlashT = 8;
        shakeT    = 6;
        combo     = 0;
        shields--;
        if (shields <= 0) { _gameOver(); }
    }
}
