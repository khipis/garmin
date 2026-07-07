// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine, score, lives, multi-ball,
// table selection.
//
// States:
//   GS_MENU    main menu — pick TABLE, then START
//   GS_LAUNCH  ball parked at the launcher; tap = release
//   GS_PLAY    one or more balls in play
//   GS_OVER    out of lives, score frozen
//
// Multi-ball
//   • Up to MAX_BALLS = 3 balls can be in play simultaneously.
//   • Drop-target bank cleared → +500, all drops respawn, **extra
//     ball spawns** at the launcher with an automatic kick (no need
//     to tap to release).
//   • A drained ball costs a LIFE only when it was the last one
//     alive; losing a ball while siblings are still bouncing just
//     removes it without touching the life counter.
//   • Every 10 000 points → +1 life (classic "extra ball" rule).
//
// Tables
//   Three handcrafted layouts (CLASSIC / NOVA / DERBY) built by
//   TableLibrary based on the play-area rectangle. The same flipper
//   geometry is reused across all tables so the player's muscle
//   memory carries over.
//
// Persistence
//   • `hi`       — global best score across every table
//   • `lastTable`— remembered table choice for next launch
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.System;
using Toybox.Math;

const GS_MENU   = 0;
const GS_LAUNCH = 1;
const GS_PLAY   = 2;
const GS_OVER   = 3;

const MAX_BALLS       = 3;
const STARTING_LIVES  = 3;
const EXTRA_BALL_EVERY = 10000;

// Menu items
const MI_TABLE = 0;
const MI_START = 1;
const MI_LB    = 2;   // global leaderboard (pushed by MainView)
const MI_ITEMS = 3;

// Global leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "pinballpro";

class GameController {
    var state;

    // ── Balls + flippers ────────────────────────────────────────────
    var balls;          // Ball[MAX_BALLS] (alive flag tells if in play)
    var fLeft;
    var fRight;

    // ── Score / lives ───────────────────────────────────────────────
    var score;
    var hi;
    var lives;
    var nextExtraBallAt;   // score threshold for next +1 life

    // ── Table selection ─────────────────────────────────────────────
    var tableIdx;
    var menuCursor;

    // ── Table contents (rebuilt by _loadTable) ──────────────────────
    var bumpers;       // Array of [x, y, r, color, flash] entries
    var drops;         // Array of DropTarget
    var slings;        // Array of Slingshot

    // ── Screen / play area ──────────────────────────────────────────
    var screenW;
    var screenH;
    var playX0; var playY0;
    var playX1; var playY1;
    var floorY;        // ball below this → drained

    // ── Launcher ────────────────────────────────────────────────────
    var launchX;
    var launchY;

    // ── Launch power meter (GS_LAUNCH only) ─────────────────────────
    // Power oscillates between LAUNCH_MIN and LAUNCH_MAX every tick;
    // tap/SELECT locks in the current value and fires the ball.
    var launchPower;        // 0..100 (current charge)
    var _launchDir;         // +1 going up, -1 going down

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
        // Play area shrunk ~10 % on each axis vs the v1 layout so the
        // whole table fits comfortably inside the round-watch visible
        // region — players reported the corners of the table being
        // clipped on fenix8solar51mm. Adding ~5 % padding to each side
        // and each top/bottom margin reduces the inscribed rectangle
        // by ~10 % on width and height.
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

        // Launcher sits in a narrow lane against the right edge,
        // a bit above the right flipper.
        launchX = playX1 - br - 2;
        launchY = playY1 - (playY1 - playY0) / 3;
    }

    hidden function _buildFlippers() {
        var pw = playX1 - playX0;
        var ph = playY1 - playY0;
        var br = balls[0].radius;
        var flLen   = (pw * 22) / 100; if (flLen < 24) { flLen = 24; }
        // Collision capsule radius. Kept close to ball.r so that the
        // ball appears to actually touch the (thinly drawn) paddle on
        // contact. The substep rotation + per-tick ball substepping
        // below give us enough temporal resolution that we no longer
        // need an oversized hit-box to catch fast balls.
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
        // TableLibrary.build returns a Dictionary with bumpers/drops/slings
        // lists — keeps the library pure and avoids passing a self-reference
        // (Monkey C resolves it via the explicit setters below).
        var data = TableLibrary.build(idx, playX0, playY0, playX1, playY1);
        setBumpers(data[:bumpers]);
        setDrops  (data[:drops]);
        setSlings (data[:slings]);
    }

    // ── Table setters used by TableLibrary ──────────────────────────
    function setBumpers(list) {
        bumpers = new [list.size()];
        for (var i = 0; i < list.size(); i++) {
            var b = list[i];
            // [x, y, r, color, flash]
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

    // ── Menu actions ────────────────────────────────────────────────
    function menuPrev() {
        menuCursor = (menuCursor + MI_ITEMS - 1) % MI_ITEMS;
    }
    function menuNext() {
        menuCursor = (menuCursor + 1) % MI_ITEMS;
    }
    function menuActivate() {
        if (menuCursor == MI_TABLE) { cycleTable();  return; }
        if (menuCursor == MI_START) { startMatch();  return; }
    }

    // ── Lifecycle ───────────────────────────────────────────────────
    function startMatch() {
        score      = 0;
        lives      = STARTING_LIVES;
        nextExtraBallAt = EXTRA_BALL_EVERY;
        for (var i = 0; i < MAX_BALLS; i++) { balls[i].kill(); }
        for (var j = 0; j < drops.size(); j++) { drops[j].reset(); }
        _parkBallForLaunch();
        state      = GS_LAUNCH;
    }

    hidden function _parkBallForLaunch() {
        // First available slot (always 0 at this point).
        balls[0].reset(launchX, launchY, balls[0].radius);
        launchPower = 20;     // start near the bottom of the meter
        _launchDir  = 1;
    }

    // Push power up/down between LAUNCH_MIN and LAUNCH_MAX while the
    // ball is parked. Called from `step()` every tick during GS_LAUNCH.
    hidden function _tickLaunchMeter() {
        var step = 5;          // px/tick of meter motion
        launchPower = launchPower + _launchDir * step;
        if (launchPower >= 100) { launchPower = 100; _launchDir = -1; }
        if (launchPower <=  10) { launchPower =  10; _launchDir =  1; }
    }

    function launchBall() {
        if (state != GS_LAUNCH) { return; }
        // Map the current meter (10..100) to a velocity factor 0.42..1.0.
        var factor = (launchPower * 1.0) / 100.0;
        if (factor < 0.42) { factor = 0.42; }
        balls[0].vy = -11.5 * factor;
        balls[0].vx = -1.8  * factor;
        state = GS_PLAY;
    }

    function gotoMenu() { state = GS_MENU; }

    // ── Input → flippers ────────────────────────────────────────────
    // Held inputs (button hold, touch hold) — straight press / release.
    function pressLeft()    { fLeft.press();   }
    function releaseLeft()  { fLeft.release(); }
    function pressRight()   { fRight.press();  }
    function releaseRight() { fRight.release();}
    // Unified hold helpers (touch / button both fire BOTH flippers).
    function holdBothFlippers()    { fLeft.press();   fRight.press();   }
    function releaseBothFlippers() { fLeft.release(); fRight.release(); }
    // Shotgun pulse — for the `onTap` fallback path that has no
    // touch-up event. The flipper self-releases after `ticks` frames
    // (see Flipper.tickPulse). 16 frames @ 40 Hz ≈ 400 ms.
    function tapPulseFlippers(ticks) {
        fLeft.pulse(ticks);
        fRight.pulse(ticks);
    }

    function selectAction() {
        if (state == GS_MENU)   { menuActivate(); return; }
        if (state == GS_OVER)   { startMatch();   return; }   // replay in place
        if (state == GS_LAUNCH) { launchBall();   return; }
    }

    // ── Per-tick step ───────────────────────────────────────────────
    // Physics is integrated in `SUBSTEPS` slices per tick. Within a
    // tick we:
    //   1. Step the flippers ONCE (so angVel reflects per-tick speed).
    //   2. Apply forces (gravity + speed clamp) ONCE per ball.
    //   3. Loop SUBSTEPS times: advance ball by 1/N of its velocity,
    //      resolve walls + every primitive (bumpers / drops / slings
    //      / flippers). With SUBSTEPS=3 the max travel per slice is
    //      ~4.7 px — much smaller than the flipper capsule diameter
    //      so the ball can no longer tunnel through paddles.
    //   4. Roll the visual trail ONCE per tick (post-collision).
    static var SUBSTEPS = 3;

    function step() {
        // Tick flash counters (independent of game state)
        for (var i = 0; i < bumpers.size(); i++) {
            if (bumpers[i][4] > 0) { bumpers[i][4] = bumpers[i][4] - 1; }
        }
        for (var j = 0; j < drops.size(); j++) { drops[j].tickFlash(); }
        for (var k = 0; k < slings.size(); k++){ slings[k].tickFlash(); }

        // Drive flipper pulse self-release exactly ONCE per frame —
        // not per substep — so the auto-release timing is independent
        // of the physics sub-step count.
        fLeft.tickPulse();
        fRight.tickPulse();

        // Launch power meter — ticks only while the ball is parked.
        if (state == GS_LAUNCH) { _tickLaunchMeter(); }

        var dtFrac = 1.0 / SUBSTEPS;

        // When not playing, just animate the flippers (menu / launch /
        // game-over) so they're visible if drawn.
        if (state != GS_PLAY) {
            for (var sf = 0; sf < SUBSTEPS; sf++) {
                fLeft.step(dtFrac);
                fRight.step(dtFrac);
            }
            return;
        }

        // Apply forces once per tick.
        for (var bi0 = 0; bi0 < MAX_BALLS; bi0++) {
            if (balls[bi0].alive) { PhysicsEngine.applyForces(balls[bi0]); }
        }

        // ── Substep loop ────────────────────────────────────────────
        // We rotate the flippers AND advance every ball by 1/N of a
        // tick on each iteration. Critically the flipper sweep is
        // sampled at N intermediate angles, so a fast paddle stroke
        // can't sweep past the ball without registering contact at
        // some point along the arc.
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
                        score = score + 100;
                        bd[4] = 5;
                    }
                }
                for (var iD = 0; iD < drops.size(); iD++) {
                    var dt = drops[iD];
                    if (dt.down) { continue; }
                    if (PhysicsEngine.collideRect(b, dt.x, dt.y, dt.w, dt.h)) {
                        dt.knockDown();
                        score = score + 50;
                    }
                }
                for (var iS = 0; iS < slings.size(); iS++) {
                    var sl = slings[iS];
                    if (PhysicsEngine.collideSlingshot(b, sl)) {
                        sl.hit();
                        score = score + 25;
                    }
                }
                // Flippers — checked at every substep, at the right
                // intermediate angle.
                PhysicsEngine.collideFlipper(b, fLeft);
                PhysicsEngine.collideFlipper(b, fRight);

                if (b.y > floorY) { b.kill(); }
            }
        }

        // Roll the visual trail once per tick (post-substeps).
        for (var bi2 = 0; bi2 < MAX_BALLS; bi2++) {
            if (balls[bi2].alive) { balls[bi2].rollTrail(); }
        }

        _checkDropsCleared();
        _grantExtraBalls();
        _resolveDrains();
        if (score > hi) { hi = score; }
    }

    // If every drop target is down → award bonus, respawn all, spawn
    // an extra ball (if room).
    hidden function _checkDropsCleared() {
        if (drops.size() == 0) { return; }
        for (var i = 0; i < drops.size(); i++) {
            if (!drops[i].down) { return; }
        }
        score = score + 500;
        for (var j = 0; j < drops.size(); j++) { drops[j].reset(); }
        _spawnExtraBall();
    }

    // Find a dead ball slot and inject a new ball auto-launched from
    // the launcher lane. No-op if no slot is free.
    hidden function _spawnExtraBall() {
        for (var i = 0; i < MAX_BALLS; i++) {
            var b = balls[i];
            if (!b.alive) {
                b.reset(launchX, launchY, b.radius);
                b.vy = -8.0;
                b.vx = -1.6;
                return;
            }
        }
    }

    hidden function _grantExtraBalls() {
        while (score >= nextExtraBallAt) {
            lives = lives + 1;
            nextExtraBallAt = nextExtraBallAt + EXTRA_BALL_EVERY;
        }
    }

    hidden function _resolveDrains() {
        var alive = _aliveCount();
        if (alive > 0) { return; }     // multiball still rolling
        // Last ball drained.
        lives = lives - 1;
        if (score > hi) { hi = score; _saveInt("hi", hi); }
        if (lives <= 0) {
            state = GS_OVER;
            // Submit to the global leaderboard, split by table variant.
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
}
