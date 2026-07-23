// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine, scoring, multi-ball, tables,
// and the premium "juice" systems layered on top of v1:
//
//   • COMBOS + MULTIPLIER  — chained hits ramp a x1..x6 multiplier
//     that scales every award; the chain decays if you stop scoring.
//   • SKILL SHOT           — releasing the plunger inside the lit
//     band on the power meter pays a big bonus.
//   • BALL SAVE            — a drain in the first few seconds after a
//     launch kicks the ball straight back into play (once per ball).
//   • MISSIONS             — a per-table 3-step objective chain; each
//     step pays out, the final step grants an EXTRA BALL, then loops.
//   • JACKPOT              — builds during multi-ball, collected by
//     clearing the drop bank while 2+ balls are live.
//   • END-OF-BALL BONUS    — banked points × a bonus multiplier that
//     grows each time you clear the drop bank, cashed on drain.
//   • NUDGE + TILT         — SELECT during play shoves the ball; over-
//     nudge and the table TILTS (flippers die briefly, bonus lost).
//   • FX                   — spark particles, floating score popups,
//     screen shake, event banners, guarded tone/vibe feedback.
//
// Persistence (unchanged keys + additive):
//   • `hi`        — global best score across every table
//   • `table`     — remembered table choice for next launch
//   • `fx`        — effects on/off option index (0 = ON)
//   • `pbCombo`   — best combo achieved (new, additive)
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.System;
using Toybox.Math;
using Toybox.Attention;

const GS_MENU   = 0;
const GS_LAUNCH = 1;
const GS_PLAY   = 2;
const GS_OVER   = 3;

const MAX_BALLS       = 3;
const STARTING_LIVES  = 3;
const EXTRA_BALL_EVERY = 10000;

// Menu items (retained for the legacy in-view menu draw path).
const MI_TABLE = 0;
const MI_START = 1;
const MI_LB    = 2;
const MI_ITEMS = 3;

// Mission types.
const MT_BUMPERS = 0;
const MT_DROPS   = 1;
const MT_SLINGS  = 2;

// Global leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "pinballpro";

class GameController {
    var state;

    // ── Balls + flippers ────────────────────────────────────────────
    var balls;
    var fLeft;
    var fRight;

    // ── Score / lives ───────────────────────────────────────────────
    var score;
    var hi;
    var lives;
    var nextExtraBallAt;

    // ── Table selection ─────────────────────────────────────────────
    var tableIdx;
    var menuCursor;

    // ── Table contents ──────────────────────────────────────────────
    var bumpers;       // [x, y, r, color, flash]
    var drops;
    var slings;

    // ── Screen / play area ──────────────────────────────────────────
    var screenW; var screenH;
    var playX0; var playY0;
    var playX1; var playY1;
    var floorY;

    // ── Launcher + power meter ──────────────────────────────────────
    var launchX; var launchY;
    var launchPower;
    var _launchDir;
    var skillLo; var skillHi;   // lit skill-shot band (percent)

    // ── Combo / multiplier ──────────────────────────────────────────
    static var COMBO_WINDOW = 80;
    var combo;
    var comboTimer;
    var multiplier;
    var bestCombo;

    // ── Missions ────────────────────────────────────────────────────
    var missionList;
    var missionIndex;
    var missionType;
    var missionTarget;
    var missionProgress;

    // ── Jackpot / bonus ─────────────────────────────────────────────
    var jackpot;
    var ballBonus;
    var bonusMult;

    // ── Ball save ───────────────────────────────────────────────────
    static var BALL_SAVE_FRAMES = 150;   // ~3.75 s at 40 Hz
    var ballSaveTimer;

    // ── Nudge / tilt ────────────────────────────────────────────────
    static var TILT_MAX      = 100;
    static var TILT_PER_NUDGE = 34;
    static var TILT_FRAMES   = 70;
    var tiltMeter;
    var tiltActive;
    var _nudgeDir;

    // ── Screen shake ────────────────────────────────────────────────
    var shakeFrames;
    var shakeMag;

    // ── Event banner ────────────────────────────────────────────────
    var bannerText;
    var bannerColor;
    var bannerTimer;

    // ── Effects ─────────────────────────────────────────────────────
    var fx;
    var fxOn;

    function initialize() {
        state    = GS_MENU;
        balls    = new [MAX_BALLS];
        for (var i = 0; i < MAX_BALLS; i++) { balls[i] = new Ball(); }
        fLeft    = new Flipper(-1);
        fRight   = new Flipper( 1);

        score    = 0;
        hi       = _loadInt("hi", 0);
        lives    = STARTING_LIVES;
        nextExtraBallAt = EXTRA_BALL_EVERY;

        tableIdx   = _loadInt("table", 0);
        if (tableIdx < 0 || tableIdx >= TableLibrary.COUNT) { tableIdx = 0; }
        menuCursor = MI_START;

        bumpers = [];
        drops   = [];
        slings  = [];

        screenW = 240; screenH = 240;
        playX0 = 0; playY0 = 0; playX1 = 240; playY1 = 240;
        floorY = 240;
        launchX = 0; launchY = 0;

        launchPower = 30;
        _launchDir  = 1;
        skillLo = 76; skillHi = 92;

        combo = 0; comboTimer = 0; multiplier = 1;
        bestCombo = _loadInt("pbCombo", 0);

        missionList = TableLibrary.missions(tableIdx);
        missionIndex = 0; missionType = 0; missionTarget = 1; missionProgress = 0;

        jackpot = 5000; ballBonus = 0; bonusMult = 1;
        ballSaveTimer = 0;
        tiltMeter = 0; tiltActive = 0; _nudgeDir = 1;
        shakeFrames = 0; shakeMag = 0;
        bannerText = ""; bannerColor = 0xFFFFFF; bannerTimer = 0;

        fx = new FxSystem();
        fxOn = (_loadInt("fx", 0) == 0);
    }

    hidden function _loadInt(key, dflt) {
        try {
            var v = Application.Storage.getValue(key);
            if (v != null && v instanceof Number && v >= 0) { return v; }
        } catch (e) { }
        return dflt;
    }
    hidden function _saveInt(key, v) {
        try { Application.Storage.setValue(key, v); } catch (e) { }
    }

    // ── Layout ──────────────────────────────────────────────────────
    function setScreen(w, h) {
        screenW = w; screenH = h;
        _buildPlayArea();
        _buildFlippers();
        _loadTable(tableIdx);
    }

    hidden function _buildPlayArea() {
        var topPad = (screenH * 13) / 100; if (topPad < 22) { topPad = 22; }
        var botPad = (screenH * 9)  / 100; if (botPad < 14) { botPad = 14; }
        var sideInset;
        if (screenW == screenH) {
            sideInset = (screenW * 18) / 100;
            if (sideInset < 22) { sideInset = 22; }
        } else {
            sideInset = (screenW * 11) / 100;
            if (sideInset < 10) { sideInset = 10; }
        }
        playX0 = sideInset;
        playX1 = screenW - sideInset;
        playY0 = topPad;
        playY1 = screenH - botPad;
        floorY = playY1 + 14;

        var pw = playX1 - playX0;
        var br = (pw * 4) / 100; if (br < 4) { br = 4; }
                                  if (br > 7) { br = 7; }
        for (var i = 0; i < MAX_BALLS; i++) { balls[i].radius = br; }

        launchX = playX1 - br - 2;
        launchY = playY1 - (playY1 - playY0) / 3;
    }

    hidden function _buildFlippers() {
        var pw = playX1 - playX0;
        var ph = playY1 - playY0;
        var br = balls[0].radius;
        var flLen   = (pw * 22) / 100; if (flLen < 24) { flLen = 24; }
        var flRad   = br;  if (flRad < 5) { flRad = 5; }
        var gap     = br * 7;
        var pivY    = playY1 - ph / 14;
        var leftPx  = playX0 + (pw - gap) / 2 - flLen + flRad;
        var rightPx = playX1 - (pw - gap) / 2 + flLen - flRad;
        if (leftPx < playX0 + 4)  { leftPx  = playX0 + 4; }
        if (rightPx > playX1 - 4) { rightPx = playX1 - 4; }
        fLeft.setGeometry(leftPx, pivY, flLen, flRad);
        fRight.setGeometry(rightPx, pivY, flLen, flRad);
        fLeft.setAngles  ( 28, -32, 28.0, 12.0);
        fRight.setAngles (152, 212, 28.0, 12.0);
    }

    // ── Table loading ───────────────────────────────────────────────
    function selectTable(idx) {
        if (idx < 0) { idx = 0; }
        if (idx >= TableLibrary.COUNT) { idx = TableLibrary.COUNT - 1; }
        tableIdx = idx;
        _saveInt("table", tableIdx);
        if (screenW > 0) { _loadTable(tableIdx); }
    }

    function cycleTable() {
        var idx = (tableIdx + 1) % TableLibrary.COUNT;
        selectTable(idx);
    }

    hidden function _loadTable(idx) {
        var data = TableLibrary.build(idx, playX0, playY0, playX1, playY1);
        setBumpers(data[:bumpers]);
        setDrops  (data[:drops]);
        setSlings (data[:slings]);
        missionList = TableLibrary.missions(idx);
    }

    // ── Table setters ───────────────────────────────────────────────
    function setBumpers(list) {
        bumpers = new [list.size()];
        for (var i = 0; i < list.size(); i++) {
            var b = list[i];
            bumpers[i] = [b[0], b[1], b[2], b[3], 0];
        }
    }
    function setDrops(list) {
        drops = new [list.size()];
        for (var i = 0; i < list.size(); i++) {
            var d = list[i];
            var t = new DropTarget();
            t.configure(d[0], d[1], d[2], d[3], d[4]);
            drops[i] = t;
        }
    }
    function setSlings(list) {
        slings = new [list.size()];
        for (var i = 0; i < list.size(); i++) {
            var s = list[i];
            var sl = new Slingshot();
            sl.configure(s[0], s[1], s[2], s[3], s[4], s[5], s[6]);
            slings[i] = sl;
        }
    }

    // ── Menu actions (legacy in-view path) ──────────────────────────
    function menuPrev() { menuCursor = (menuCursor + MI_ITEMS - 1) % MI_ITEMS; }
    function menuNext() { menuCursor = (menuCursor + 1) % MI_ITEMS; }
    function menuActivate() {
        if (menuCursor == MI_TABLE) { cycleTable();  return; }
        if (menuCursor == MI_START) { startMatch();  return; }
    }

    // ── Lifecycle ───────────────────────────────────────────────────
    function startMatch() {
        score      = 0;
        lives      = STARTING_LIVES;
        nextExtraBallAt = EXTRA_BALL_EVERY;
        combo = 0; comboTimer = 0; multiplier = 1;
        jackpot = 5000; ballBonus = 0; bonusMult = 1;
        ballSaveTimer = 0;
        tiltMeter = 0; tiltActive = 0;
        shakeFrames = 0; bannerTimer = 0;
        missionIndex = 0;
        fx.reset();
        _loadMissionStep();
        for (var i = 0; i < MAX_BALLS; i++) { balls[i].kill(); }
        for (var j = 0; j < drops.size(); j++) { drops[j].reset(); }
        _parkBallForLaunch();
        state      = GS_LAUNCH;
    }

    hidden function _loadMissionStep() {
        if (missionList == null || missionList.size() == 0) {
            missionType = 0; missionTarget = 999999; missionProgress = 0;
            return;
        }
        var m = missionList[missionIndex];
        missionType = m[0];
        missionTarget = m[1];
        missionProgress = 0;
    }

    hidden function _parkBallForLaunch() {
        balls[0].reset(launchX, launchY, balls[0].radius);
        launchPower = 20;
        _launchDir  = 1;
    }

    hidden function _tickLaunchMeter() {
        var step = 5;
        launchPower = launchPower + _launchDir * step;
        if (launchPower >= 100) { launchPower = 100; _launchDir = -1; }
        if (launchPower <=  10) { launchPower =  10; _launchDir =  1; }
    }

    function launchBall() {
        if (state != GS_LAUNCH) { return; }
        var factor = (launchPower * 1.0) / 100.0;
        if (factor < 0.42) { factor = 0.42; }
        balls[0].vy = -11.5 * factor;
        balls[0].vx = -1.8  * factor;
        state = GS_PLAY;
        ballSaveTimer = BALL_SAVE_FRAMES;

        // Skill shot — plunger released inside the lit band.
        if (launchPower >= skillLo && launchPower <= skillHi) {
            var bonus = 2500;
            score = score + bonus;
            if (score > hi) { hi = score; }
            fx.popup("SKILL +" + bonus.toString(), launchX - 30, launchY, 0x44FFEE);
            fx.burst(launchX, launchY, 0x44FFEE, 12, 3.5, true);
            setBanner("SKILL SHOT!", 0x44FFEE, 45);
            addShake(3, 8);
            _tone(3); _vibe(60, 120);
            combo = 2; comboTimer = COMBO_WINDOW; _recalcMultiplier();
        }
    }

    function gotoMenu() { state = GS_MENU; }

    // ── Input → flippers (blocked while tilted) ─────────────────────
    function pressLeft()    { if (tiltActive == 0) { fLeft.press();  } }
    function releaseLeft()  { fLeft.release(); }
    function pressRight()   { if (tiltActive == 0) { fRight.press(); } }
    function releaseRight() { fRight.release(); }
    function holdBothFlippers() {
        if (tiltActive == 0) { fLeft.press(); fRight.press(); }
    }
    function releaseBothFlippers() { fLeft.release(); fRight.release(); }
    function tapPulseFlippers(ticks) {
        if (tiltActive > 0) { return; }
        fLeft.pulse(ticks);
        fRight.pulse(ticks);
    }

    // ── Nudge ───────────────────────────────────────────────────────
    // SELECT during play shoves every live ball upward with a small
    // sideways bias. Repeated shoves fill the tilt meter; overflow =
    // TILT (flippers dead + end-of-ball bonus wiped).
    function nudge() {
        if (state != GS_PLAY || tiltActive > 0) { return; }
        var dvx = 1.4 * _nudgeDir;
        _nudgeDir = -_nudgeDir;
        for (var i = 0; i < MAX_BALLS; i++) {
            if (balls[i].alive) { PhysicsEngine.applyNudge(balls[i], dvx, -1.7); }
        }
        addShake(2, 5);
        tiltMeter = tiltMeter + TILT_PER_NUDGE;
        _vibe(30, 40);
        if (tiltMeter >= TILT_MAX) {
            tiltActive = TILT_FRAMES;
            tiltMeter = TILT_MAX;
            releaseBothFlippers();
            ballBonus = 0;
            combo = 0; multiplier = 1; comboTimer = 0;
            setBanner("TILT!", 0xFF3333, TILT_FRAMES);
            addShake(5, 12);
            _tone(2); _vibe(90, 250);
        }
    }

    function selectAction() {
        if (state == GS_MENU)   { menuActivate(); return; }
        if (state == GS_OVER)   { startMatch();   return; }
        if (state == GS_LAUNCH) { launchBall();   return; }
        if (state == GS_PLAY)   { nudge();        return; }
    }

    // ── Scoring helpers ─────────────────────────────────────────────
    hidden function _recalcMultiplier() {
        var m = 1 + (combo / 4);
        if (m > 6) { m = 6; }
        multiplier = m;
    }

    // Award `base` points scaled by the live multiplier, bank the raw
    // value toward the end-of-ball bonus, bump the combo, and float a
    // popup. Returns the scaled gain.
    hidden function _award(base, x, y, popupCol, showPopup) {
        var gain = base * multiplier;
        score = score + gain;
        ballBonus = ballBonus + base;
        if (score > hi) { hi = score; }
        combo = combo + 1;
        if (combo > bestCombo) { bestCombo = combo; }
        comboTimer = COMBO_WINDOW;
        _recalcMultiplier();
        if (showPopup) {
            fx.popup("+" + gain.toString(), x, y - 6, popupCol);
        }
        return gain;
    }

    function setBanner(text, color, frames) {
        bannerText = text; bannerColor = color; bannerTimer = frames;
    }

    function addShake(mag, frames) {
        if (frames > shakeFrames) { shakeFrames = frames; }
        if (mag > shakeMag) { shakeMag = mag; }
    }

    // Current shake offsets (0 when idle). Math.rand() may be negative,
    // so take |rand| before the (Number) modulo → symmetric ±mag.
    function shakeX() {
        if (shakeFrames <= 0) { return 0; }
        var m = shakeMag;
        var r = Math.rand(); if (r < 0) { r = -r; }
        return (r % (2 * m + 1)) - m;
    }
    function shakeY() {
        if (shakeFrames <= 0) { return 0; }
        var m = shakeMag;
        var r = Math.rand(); if (r < 0) { r = -r; }
        return (r % (2 * m + 1)) - m;
    }

    // ── Per-tick step ───────────────────────────────────────────────
    static var SUBSTEPS = 3;

    function step() {
        // Animation + timer counters.
        for (var i = 0; i < bumpers.size(); i++) {
            if (bumpers[i][4] > 0) { bumpers[i][4] = bumpers[i][4] - 1; }
        }
        for (var j = 0; j < drops.size(); j++) { drops[j].tickFlash(); }
        for (var k = 0; k < slings.size(); k++){ slings[k].tickFlash(); }

        if (bannerTimer > 0) { bannerTimer = bannerTimer - 1; }
        if (shakeFrames > 0) {
            shakeFrames = shakeFrames - 1;
            if (shakeFrames == 0) { shakeMag = 0; }
        }
        fx.step();

        fLeft.tickPulse();
        fRight.tickPulse();

        if (state == GS_LAUNCH) { _tickLaunchMeter(); }

        // Tilt cooldown.
        if (tiltActive > 0) {
            tiltActive = tiltActive - 1;
            if (tiltActive == 0) { tiltMeter = 0; }
        } else if (tiltMeter > 0) {
            tiltMeter = tiltMeter - 1;
        }

        var dtFrac = 1.0 / SUBSTEPS;

        if (state != GS_PLAY) {
            for (var sf = 0; sf < SUBSTEPS; sf++) {
                fLeft.step(dtFrac);
                fRight.step(dtFrac);
            }
            return;
        }

        // Combo decay.
        if (comboTimer > 0) {
            comboTimer = comboTimer - 1;
            if (comboTimer == 0) { combo = 0; multiplier = 1; }
        }
        // Ball-save countdown.
        if (ballSaveTimer > 0) { ballSaveTimer = ballSaveTimer - 1; }

        for (var bi0 = 0; bi0 < MAX_BALLS; bi0++) {
            if (balls[bi0].alive) { PhysicsEngine.applyForces(balls[bi0]); }
        }

        for (var s = 0; s < SUBSTEPS; s++) {
            fLeft.step(dtFrac);
            fRight.step(dtFrac);

            for (var bi = 0; bi < MAX_BALLS; bi++) {
                var b = balls[bi];
                if (!b.alive) { continue; }

                PhysicsEngine.advance(b, dtFrac);
                PhysicsEngine.clampToWalls(b, playX0, playY0, playX1, playY1);

                for (var iB = 0; iB < bumpers.size(); iB++) {
                    var bd = bumpers[iB];
                    if (PhysicsEngine.collideBumper(b, bd[0], bd[1], bd[2])) {
                        bd[4] = 8;
                        _award(100, bd[0], bd[1], 0xFFDD44, true);
                        fx.burst(bd[0], bd[1], bd[3], 6, 2.6, false);
                        addShake(1, 3);
                        if (isMultiball()) {
                            jackpot = jackpot + 100 * multiplier;
                            if (jackpot > 25000) { jackpot = 25000; }
                        }
                        if (missionType == MT_BUMPERS) { _missionTick(1); }
                    }
                }
                for (var iD = 0; iD < drops.size(); iD++) {
                    var dt = drops[iD];
                    if (dt.down) { continue; }
                    if (PhysicsEngine.collideRect(b, dt.x, dt.y, dt.w, dt.h)) {
                        dt.knockDown();
                        _award(50, dt.x + dt.w / 2, dt.y, 0x66FF88, true);
                        fx.burst(dt.x + dt.w / 2, dt.y + dt.h / 2, dt.color, 6, 2.4, false);
                        addShake(1, 3);
                    }
                }
                for (var iS = 0; iS < slings.size(); iS++) {
                    var sl = slings[iS];
                    if (PhysicsEngine.collideSlingshot(b, sl)) {
                        sl.hit();
                        _award(25, sl.ax, sl.ay, 0xFFAACC, false);
                        fx.burst((sl.ax + sl.bx) / 2, (sl.ay + sl.by) / 2,
                                 sl.color, 4, 2.2, false);
                        if (missionType == MT_SLINGS) { _missionTick(1); }
                    }
                }

                var hitL = PhysicsEngine.collideFlipper(b, fLeft);
                var hitR = PhysicsEngine.collideFlipper(b, fRight);
                if (hitL && fLeft.active) {
                    fx.spray(b.x, b.y, 0.2, -1.0, 0xFF8866, 3, 3.0);
                }
                if (hitR && fRight.active) {
                    fx.spray(b.x, b.y, -0.2, -1.0, 0xFFEE66, 3, 3.0);
                }

                if (b.y > floorY) { b.kill(); }
            }
        }

        for (var bi2 = 0; bi2 < MAX_BALLS; bi2++) {
            if (balls[bi2].alive) { balls[bi2].rollTrail(); }
        }

        _checkDropsCleared();
        _grantExtraBalls();
        _resolveDrains();
        if (score > hi) { hi = score; }
    }

    // ── Mission progress ────────────────────────────────────────────
    hidden function _missionTick(n) {
        missionProgress = missionProgress + n;
        if (missionProgress >= missionTarget) { _completeMission(); }
    }

    hidden function _completeMission() {
        var payout = 2000 * (missionIndex + 1);
        score = score + payout * multiplier;
        if (score > hi) { hi = score; }
        var last = (missionList != null) && (missionIndex >= missionList.size() - 1);
        fx.burst((playX0 + playX1) / 2, (playY0 + playY1) / 2,
                 0xFFEE44, 14, 3.6, true);
        addShake(3, 8);
        if (last) {
            setBanner("TABLE MASTER!", 0xFFEE44, 55);
            _tone(3); _vibe(80, 200);
            _spawnExtraBall();
            missionIndex = 0;
        } else {
            setBanner("MISSION CLEAR!", 0x66FF88, 45);
            _tone(3); _vibe(50, 100);
            missionIndex = missionIndex + 1;
        }
        _loadMissionStep();
    }

    // Human-readable current objective for the HUD.
    function missionLabel() {
        if (missionType == MT_DROPS) {
            return "CLEAR BANK " + missionProgress.toString() + "/"
                   + missionTarget.toString();
        }
        if (missionType == MT_SLINGS) {
            return "SLINGS " + missionProgress.toString() + "/"
                   + missionTarget.toString();
        }
        return "BUMPERS " + missionProgress.toString() + "/"
               + missionTarget.toString();
    }

    // ── Drop bank clear ─────────────────────────────────────────────
    hidden function _checkDropsCleared() {
        if (drops.size() == 0) { return; }
        for (var i = 0; i < drops.size(); i++) {
            if (!drops[i].down) { return; }
        }
        var cx = (playX0 + playX1) / 2;
        var cy = drops[0].y;
        _award(500, cx, cy, 0x66FF88, true);
        if (bonusMult < 5) { bonusMult = bonusMult + 1; }
        fx.burst(cx, cy, 0x66FF88, 12, 3.2, true);
        addShake(2, 6);

        if (isMultiball()) {
            score = score + jackpot;
            if (score > hi) { hi = score; }
            fx.popup("JACKPOT " + jackpot.toString(), cx - 20, cy - 14, 0xFFDD22);
            setBanner("JACKPOT!", 0xFFDD22, 45);
            _tone(1); _vibe(70, 160);
            jackpot = 5000;
        }

        if (missionType == MT_DROPS) { _missionTick(1); }

        for (var j = 0; j < drops.size(); j++) { drops[j].reset(); }
        _spawnExtraBall();
    }

    hidden function _spawnExtraBall() {
        var wasMulti = _aliveCount() >= 1;
        for (var i = 0; i < MAX_BALLS; i++) {
            var b = balls[i];
            if (!b.alive) {
                b.reset(launchX, launchY, b.radius);
                b.vy = -8.0;
                b.vx = -1.6;
                if (wasMulti && _aliveCount() >= 2) {
                    setBanner("MULTIBALL!", 0x44CCFF, 45);
                    fx.burst(launchX, launchY, 0x44CCFF, 12, 3.2, true);
                    _tone(1); _vibe(60, 140);
                }
                return;
            }
        }
    }

    hidden function _grantExtraBalls() {
        while (score >= nextExtraBallAt) {
            lives = lives + 1;
            nextExtraBallAt = nextExtraBallAt + EXTRA_BALL_EVERY;
            setBanner("EXTRA BALL!", 0x66FF88, 40);
            _tone(3);
        }
    }

    hidden function _resolveDrains() {
        var alive = _aliveCount();
        if (alive > 0) { return; }

        // Ball save — kick a fresh ball straight back into play.
        if (ballSaveTimer > 0) {
            ballSaveTimer = 0;
            balls[0].reset(launchX, launchY, balls[0].radius);
            balls[0].vy = -9.5;
            balls[0].vx = -1.6;
            setBanner("BALL SAVED", 0x44FFAA, 40);
            fx.burst(launchX, launchY, 0x44FFAA, 10, 3.0, false);
            _tone(0); _vibe(40, 80);
            state = GS_PLAY;
            return;
        }

        // Cash the end-of-ball bonus.
        var payout = ballBonus * bonusMult;
        if (payout > 0) {
            score = score + payout;
            if (score > hi) { hi = score; }
            setBanner("BONUS +" + payout.toString(), 0xFFCC22, 40);
        }
        ballBonus = 0; bonusMult = 1;
        combo = 0; multiplier = 1; comboTimer = 0;

        lives = lives - 1;
        if (score > hi) { hi = score; _saveInt("hi", hi); }
        if (bestCombo > _loadInt("pbCombo", 0)) { _saveInt("pbCombo", bestCombo); }

        if (lives <= 0) {
            state = GS_OVER;
            Leaderboard.submitScore(LB_GAME_ID, score, TableLibrary.NAMES[tableIdx]);
            Leaderboard.showPostGame(LB_GAME_ID, TableLibrary.NAMES[tableIdx], "PINBALL PRO");
            return;
        }
        _parkBallForLaunch();
        state = GS_LAUNCH;
    }

    function aliveBallCount() { return _aliveCount(); }
    hidden function _aliveCount() {
        var c = 0;
        for (var i = 0; i < MAX_BALLS; i++) {
            if (balls[i].alive) { c = c + 1; }
        }
        return c;
    }

    function isMultiball() { return _aliveCount() >= 2; }

    // ── Best-effort tone / vibe (silent hardware is fine) ───────────
    // kind: 0 key · 1 loud beep · 2 failure · 3 success.
    hidden function _tone(kind) {
        if (!fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :playTone)) { return; }
        var t;
        if      (kind == 0) { t = Attention.TONE_KEY; }
        else if (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
        else if (kind == 2) { t = Attention.TONE_FAILURE; }
        else                { t = Attention.TONE_SUCCESS; }
        try { Attention.playTone(t); } catch (e) {}
    }
    hidden function _vibe(intensity, duration) {
        if (!fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :vibrate)) { return; }
        try { Attention.vibrate([new Attention.VibeProfile(intensity, duration)]); } catch (e) {}
    }
}
