// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine, scoring, layout owner.
//
// Match flow:
//   GS_MENU    → cycle difficulty + tap START
//   GS_SERVE   → ball waits at centre for 0.6 s, AI freezes for its
//                difficulty-specific reactDelay
//   GS_PLAY    → live rally
//   GS_OVER    → first to MATCH_POINTS scored
//
// Layout
//   On round watches we inset the play field to a tall rectangle in
//   the centre so paddles + ball never clip the bezel. The play
//   rectangle is [playX0, playY0 .. playX1, playY1].
// ═══════════════════════════════════════════════════════════════

using Toybox.System;
using Toybox.Application;
using Toybox.Math;

const GS_MENU  = 0;
const GS_SERVE = 1;
const GS_PLAY  = 2;
const GS_OVER  = 3;

const MATCH_POINTS = 7;

// Chess-style menu rows
const MI_DIFFICULTY = 0;
const MI_TILT       = 1;    // gyro/tilt paddle control on/off
const MI_START      = 2;
const MI_LEADERBOARD = 3;   // global; AI difficulty is used as the variant
const MI_ITEMS      = 4;

// Global leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "pongpro";

class GameController {
    var state;
    var menuRow;
    var ball;
    var pPlayer;       // left paddle (player)
    var pCpu;          // right paddle (CPU)
    var ai;

    var scoreP;
    var scoreCpu;
    var lastWinner;    // -1 = nobody yet, 0 = player, 1 = cpu (drives serve dir)
    var hiPlayerWins;  // total player match wins, persisted

    // ── power-ups / multiball ────────────────────────────────────────────
    var powerUp;
    var ball2;
    var ball2Active;
    var puSpawnTimer;
    var puLifeTimer;
    var puFlashT;       // "POWER UP!" banner countdown
    var puFlashKind;
    var lastHitSide;    // -1 none, 0 = player, 1 = cpu — who touched the ball last
    var growSide;        // -1 none, 0/1 = side with an enlarged paddle
    var growTimer;
    var shrinkSide;       // -1 none, 0/1 = side with a shrunk paddle
    var shrinkTimer;

    // Layout
    var screenW;
    var screenH;
    var playX0;
    var playY0;
    var playX1;
    var playY1;
    var paddleW;
    var paddleH;
    var ballSz;

    // Pacing
    var serveCounter;  // ticks until ball launches
    var serveDelay;    // baseline serve countdown
    var difficulty;
    var baseBallSpeed; // initial speed per serve (scales with diff)

    // ── Tilt (gyro) control ──────────────────────────────────────────────
    var tiltEnabled;   // player toggle in the menu
    var gyro;          // accelerometer reader
    hidden var _tiltSmoothY;  // EMA of the calibrated Y tilt (noise filter)
    hidden var _tiltCenter;   // smoothed paddle centre target (Float, anti-jump)

    function initialize() {
        state    = GS_MENU;
        menuRow  = MI_START;
        ball     = new Ball();
        pPlayer  = new Paddle(0xFFFFFF);
        pCpu     = new Paddle(0xFF44AA);
        ai       = new AIController();
        scoreP   = 0; scoreCpu = 0;
        lastWinner = -1;
        hiPlayerWins = _loadStat();
        screenW = 240; screenH = 240;
        playX0 = 0; playY0 = 0; playX1 = 0; playY1 = 0;
        paddleW = 4; paddleH = 30; ballSz = 6;
        serveCounter = 0; serveDelay = 24;
        difficulty = DIFF_MEDIUM;
        baseBallSpeed = 3.6;
        _holdUp = false; _holdDown = false;

        tiltEnabled  = false;
        gyro         = new GyroInput();
        _tiltSmoothY = 0.0;
        _tiltCenter  = 120.0;

        powerUp      = new PowerUp();
        ball2        = new Ball();
        ball2Active  = false;
        puSpawnTimer = _randSpawnGap();
        puLifeTimer  = 0;
        puFlashT     = 0;
        puFlashKind  = 0;
        lastHitSide  = -1;
        growSide     = -1; growTimer   = 0;
        shrinkSide   = -1; shrinkTimer = 0;

        _loadSettings();
    }

    hidden function _randSpawnGap() {
        return PU_COOLDOWN_MIN + (Math.rand() % (PU_COOLDOWN_MAX - PU_COOLDOWN_MIN));
    }

    hidden function _loadStat() {
        try {
            var v = Application.Storage.getValue("wins");
            if (v != null && v instanceof Number && v > 0) { return v; }
        } catch (e) { }
        return 0;
    }
    hidden function _saveStat() {
        try { Application.Storage.setValue("wins", hiPlayerWins); } catch (e) { }
    }
    hidden function _loadSettings() {
        try {
            var d = Application.Storage.getValue("pp_diff");
            if (d instanceof Number && d >= DIFF_EASY && d <= DIFF_HARD) { setDifficulty(d); }
        } catch (e) {}
        try {
            var t = Application.Storage.getValue("pp_tilt");
            // OPTIONS stores an index (0/1); older builds stored a Boolean.
            if (t instanceof Boolean) { tiltEnabled = t; }
            else if (t instanceof Number) { tiltEnabled = (t == 1); }
        } catch (e) {}
    }
    hidden function _saveDifficulty() {
        try { Application.Storage.setValue("pp_diff", difficulty); } catch (e) {}
    }
    hidden function _saveTilt() {
        try { Application.Storage.setValue("pp_tilt", tiltEnabled); } catch (e) {}
    }

    // Toggle tilt steering from the menu. Recalibrate on enable so the
    // wrist's current angle becomes the new neutral.
    function toggleTilt() {
        tiltEnabled = !tiltEnabled;
        if (tiltEnabled) { gyro.calibrate(); }
        _saveTilt();
    }

    function tiltLabel() { return tiltEnabled ? "ON" : "OFF"; }

    function setScreen(w, h) {
        screenW = w; screenH = h;
        // Tall-rectangle play field — leave 8% margin top/bottom for HUD
        // and ~16% margin left/right on round watches to clear the bezel.
        var topInset = (h * 14) / 100; if (topInset < 16) { topInset = 16; }
        var botInset = (h * 8)  / 100; if (botInset < 12) { botInset = 12; }
        var sideInset;
        if (w == h) {                   // assume round
            sideInset = (w * 16) / 100;
            if (sideInset < 18) { sideInset = 18; }
        } else {
            sideInset = (w * 4) / 100;
            if (sideInset < 6) { sideInset = 6; }
        }
        playX0 = sideInset;
        playX1 = w - sideInset;
        playY0 = topInset;
        playY1 = h - botInset;

        paddleW = (w * 2) / 100; if (paddleW < 3)  { paddleW = 3;  }
                                  if (paddleW > 7)  { paddleW = 7;  }
        paddleH = (h * 14) / 100; if (paddleH < 22) { paddleH = 22; }
        ballSz  = (w * 3) / 100;  if (ballSz < 5)   { ballSz = 5;   }
                                  if (ballSz > 9)   { ballSz = 9;   }
        ball.size = ballSz;

        pPlayer.setBounds(playX0 + 2, paddleW, paddleH, playY0, playY1);
        pCpu.setBounds(playX1 - 2 - paddleW, paddleW, paddleH, playY0, playY1);
        pPlayer.setCenterY((playY0 + playY1) / 2);
        pCpu.setCenterY((playY0 + playY1) / 2);
    }

    function setDifficulty(d) {
        if (d < DIFF_EASY) { d = DIFF_EASY; }
        if (d > DIFF_HARD) { d = DIFF_HARD; }
        difficulty = d;
        ai.setDifficulty(d);
        // Ball gets faster with difficulty too.
        baseBallSpeed = 3.2 + d * 0.4;
        ball.maxSpeed = 5.5 + d * 0.6;
    }

    function cycleDifficulty() {
        var d = difficulty + 1;
        if (d > DIFF_HARD) { d = DIFF_EASY; }
        setDifficulty(d);
        _saveDifficulty();
    }

    // Text for the big power-up flash banner (kind is snapshotted at the
    // moment of activation into puFlashKind, independent of whatever the
    // NEXT pickup ends up being).
    function powerUpLabel(kind) {
        if (kind == PU_MULTIBALL) { return "MULTIBALL!"; }
        if (kind == PU_GROW)      { return "PADDLE UP!"; }
        return "SHRINK RAY!";
    }

    // Difficulty name used as the leaderboard variant (split per level).
    function diffName() {
        if (difficulty == DIFF_EASY) { return "Easy"; }
        if (difficulty == DIFF_HARD) { return "Hard"; }
        return "Medium";
    }

    function startMatch() {
        scoreP = 0; scoreCpu = 0;
        lastWinner = -1;
        setDifficulty(difficulty);  // reapply
        growSide = -1; growTimer = 0;
        shrinkSide = -1; shrinkTimer = 0;
        lastHitSide = -1;
        _applyPaddleSizes();
        puSpawnTimer = _randSpawnGap();
        // Seat tilt control at the current wrist angle + centre the paddle.
        gyro.calibrate();
        _tiltSmoothY = 0.0;
        _tiltCenter  = ((playY0 + playY1) / 2).toFloat();
        _serve();
    }

    function gotoMenu() { state = GS_MENU; }

    // Continuous hold flags pushed by InputHandler.
    function setHoldUp(b)   { _holdUp   = b; _recomputePlayerVy(); }
    function setHoldDown(b) { _holdDown = b; _recomputePlayerVy(); }

    hidden var _holdUp;
    hidden var _holdDown;

    hidden function _recomputePlayerVy() {
        if (_holdUp && !_holdDown)      { pPlayer.vy = -PLAYER_SPEED; }
        else if (_holdDown && !_holdUp) { pPlayer.vy =  PLAYER_SPEED; }
        else                             { pPlayer.vy =  0.0; }
    }

    // Tilt-steer the player's paddle. Two-stage smoothing keeps it gentle
    // and jitter-free:
    //   1. EMA low-pass on the raw accelerometer Y kills sensor noise.
    //   2. The paddle centre eases toward the mapped target (lerp), so it
    //      glides rather than snapping — no jumpiness even on fast tilts.
    // A small deadzone around neutral stops the paddle drifting when the
    // wrist is held still. `_tiltCenter` is kept as a Float so the ease
    // converges smoothly regardless of pixel rounding.
    hidden function _applyTilt() {
        var ay = gyro.readY();

        // Deadzone around the calibrated resting angle.
        if (ay > -TILT_DEADZONE && ay < TILT_DEADZONE) { ay = 0; }
        else if (ay > 0) { ay = ay - TILT_DEADZONE; }
        else             { ay = ay + TILT_DEADZONE; }

        // 1) Noise filter.
        _tiltSmoothY = _tiltSmoothY + (ay - _tiltSmoothY) * TILT_SMOOTH;

        // Map tilt → normalised [-1 .. 1] across the usable range.
        var norm = _tiltSmoothY / TILT_RANGE;
        if (norm >  1.0) { norm =  1.0; }
        if (norm < -1.0) { norm = -1.0; }

        // Target paddle centre. Screen Y grows downward and sensor Y grows
        // toward the top of the watch, so we subtract to make "tilt up"
        // move the paddle up.
        var midY = ((playY0 + playY1) / 2).toFloat();
        var span = (((playY1 - playY0) - pPlayer.h) / 2).toFloat();
        if (span < 0.0) { span = 0.0; }
        var target = midY - norm * span;

        // 2) Ease toward the target.
        _tiltCenter = _tiltCenter + (target - _tiltCenter) * TILT_FOLLOW;

        pPlayer.setCenterY(_tiltCenter.toNumber());
        pPlayer.vy = 0.0;   // tilt owns the paddle — ignore stale button holds
    }

    // One-shot impulse from tap / swipe — moves paddle a chunk.
    function impulse(dir) {
        if (state == GS_MENU)  { startMatch(); return; }
        if (state == GS_OVER)  { gotoMenu();   return; }
        // Active rally — nudge paddle by half its height.
        pPlayer.setCenterY(pPlayer.centerY() + dir * (paddleH / 2));
    }

    // SELECT / confirm.
    function confirm() {
        if (state == GS_MENU)  { startMatch(); return; }
        if (state == GS_OVER)  { gotoMenu();   return; }
    }

    function step() {
        if (state == GS_MENU)  { return; }
        if (state == GS_OVER)  { return; }
        if (state == GS_SERVE) {
            serveCounter = serveCounter - 1;
            if (serveCounter <= 0) {
                var toLeft = (lastWinner == 0);    // server hits toward loser
                // Serves get a little faster as the match progresses (on
                // top of the per-hit boost already applied mid-rally), so
                // later points feel meaningfully more intense.
                var spd = baseBallSpeed + (scoreP + scoreCpu) * 0.12;
                if (spd > ball.maxSpeed) { spd = ball.maxSpeed; }
                ball.reset((playX0 + playX1) / 2,
                           (playY0 + playY1) / 2,
                           spd, toLeft);
                state = GS_PLAY;
            }
            // Paddles still respond to player input even during serve.
            if (tiltEnabled) { _applyTilt(); }
            pPlayer.step();
            return;
        }
        // GS_PLAY
        if (tiltEnabled) { _applyTilt(); }
        pPlayer.step();
        var aiTarget = (ball2Active && _ball2MoreUrgent()) ? ball2 : ball;
        ai.step(pCpu, aiTarget, playX0, playY0, playX1, playY1);
        pCpu.step();

        _stepPowerUp();

        var scored = _advanceBall(ball);
        if (ball2Active) {
            var scored2 = _advanceBall(ball2);
            if (scored == 0) { scored = scored2; }
            if (scored2 != 0) { ball2Active = false; }
        }

        if (scored == -1) {
            // ball passed left wall — CPU scored
            scoreCpu = scoreCpu + 1;
            lastWinner = 1;
            _afterPoint();
        } else if (scored == 1) {
            scoreP = scoreP + 1;
            lastWinner = 0;
            _afterPoint();
        }
    }

    // Advance one ball: physics + paddle collisions + power-up pickup.
    // Returns the same -1/0/1 scoring signal as Ball.step().
    hidden function _advanceBall(b) {
        var res = b.step(playX0, playY0, playX1, playY1);

        if (b.tryPaddleBounce(pPlayer.x, pPlayer.y, pPlayer.w, pPlayer.h, -1)) {
            lastHitSide = 0;
        }
        if (b.tryPaddleBounce(pCpu.x, pCpu.y, pCpu.w, pCpu.h, +1)) {
            lastHitSide = 1;
        }

        if (powerUp.active) {
            var bb = b.bbox();
            if (powerUp.hits(bb[0], bb[1], bb[2], bb[3])) {
                _activatePowerUp(powerUp.kind);
                powerUp.clear();
            }
        }
        return res;
    }

    // While multiball is active, point the AI at whichever ball is the
    // more immediate threat (closest to its paddle while heading that way)
    // instead of always tracking the original ball.
    hidden function _ball2MoreUrgent() {
        var d1 = (ball.vx > 0)  ? (pCpu.x - ball.x)  : 999999;
        var d2 = (ball2.vx > 0) ? (pCpu.x - ball2.x) : 999999;
        return d2 < d1;
    }

    // ── power-ups ─────────────────────────────────────────────────────────
    hidden function _stepPowerUp() {
        if (powerUp.active) {
            powerUp.step();
            puLifeTimer = puLifeTimer - 1;
            if (puLifeTimer <= 0) {
                powerUp.clear();
                puSpawnTimer = _randSpawnGap();
            }
        } else {
            puSpawnTimer = puSpawnTimer - 1;
            if (puSpawnTimer <= 0) { _trySpawnPowerUp(); }
        }

        if (growTimer > 0) {
            growTimer = growTimer - 1;
            if (growTimer <= 0) { growSide = -1; _applyPaddleSizes(); }
        }
        if (shrinkTimer > 0) {
            shrinkTimer = shrinkTimer - 1;
            if (shrinkTimer <= 0) { shrinkSide = -1; _applyPaddleSizes(); }
        }
        if (puFlashT > 0) { puFlashT = puFlashT - 1; }
    }

    hidden function _trySpawnPowerUp() {
        var margin = (playY1 - playY0) / 5;
        var rangeH = (playY1 - playY0) - margin * 2;
        if (rangeH < 4) { rangeH = 4; }
        var y = playY0 + margin + (Math.rand() % rangeH);
        var x = (playX0 + playX1) / 2;
        var kind = Math.rand() % PU_TYPES;
        powerUp.spawn(x, y, kind);
        puLifeTimer = PU_LIFE_TICKS;
    }

    hidden function _activatePowerUp(kind) {
        var side = (lastHitSide < 0) ? 0 : lastHitSide;
        if (kind == PU_MULTIBALL) {
            if (!ball2Active) {
                ball2.cloneFrom(ball);
                ball2Active = true;
            }
        } else if (kind == PU_GROW) {
            growSide = side; growTimer = PU_BUFF_TICKS;
            _applyPaddleSizes();
        } else {
            shrinkSide = 1 - side; shrinkTimer = PU_BUFF_TICKS;
            _applyPaddleSizes();
        }
        puFlashKind = kind;
        puFlashT = 55;
    }

    // Recompute both paddles' live heights from the base size + whatever
    // grow/shrink buffs are currently active, then push them to the paddles
    // (which internally re-clamp to stay on-screen and keep their centre).
    hidden function _applyPaddleSizes() {
        var playerMult = 1.0;
        var cpuMult    = 1.0;
        if (growSide   == 0) { playerMult = playerMult * 1.5;  }
        if (growSide   == 1) { cpuMult    = cpuMult    * 1.5;  }
        if (shrinkSide == 0) { playerMult = playerMult * 0.65; }
        if (shrinkSide == 1) { cpuMult    = cpuMult    * 0.65; }

        pPlayer.setHeightPreserveCenter((paddleH * playerMult).toNumber());
        pCpu.setHeightPreserveCenter((paddleH * cpuMult).toNumber());

        pPlayer.buffState = (growSide == 0) ? 1 : ((shrinkSide == 0) ? -1 : 0);
        pCpu.buffState    = (growSide == 1) ? 1 : ((shrinkSide == 1) ? -1 : 0);
    }

    hidden function _afterPoint() {
        if (scoreP >= MATCH_POINTS || scoreCpu >= MATCH_POINTS) {
            if (scoreP > scoreCpu) {
                hiPlayerWins = hiPlayerWins + 1;
                _saveStat();
                // Submit the win margin to the global leaderboard, split
                // by AI difficulty. A 7-0 sweep scores higher than a 7-6
                // nail-biter. Only single-player vs-AI wins are recorded.
                Leaderboard.submitScore(LB_GAME_ID, scoreP - scoreCpu, diffName());
                Leaderboard.showPostGame(LB_GAME_ID, diffName(), "PONG PRO");
            }
            state = GS_OVER;
            return;
        }
        _serve();
    }

    hidden function _serve() {
        serveCounter = serveDelay;
        // Park ball at centre for the countdown.
        ball.x  = (playX0 + playX1) / 2;
        ball.y  = (playY0 + playY1) / 2;
        ball.vx = 0.0;
        ball.vy = 0.0;
        // Multiball and any pending pickup don't carry across a serve.
        ball2Active = false;
        powerUp.clear();
        // Recentre AI paddle a bit and let it pick a fresh random error.
        ai.onServe(paddleH / 2);
        state = GS_SERVE;
    }
}

// Player paddle movement speed — defined at module scope so both
// GameController (computing vy) and tests can reference it.
const PLAYER_SPEED = 4.4;

// ── Tilt-steer tuning (25 ms / ~40 Hz tick) ──────────────────────────
// TILT_RANGE   — milli-g of tilt that drives the paddle fully to an edge.
//                ~320 mg ≈ a gentle ~18° wrist tilt, so small movements
//                are enough and the control never feels twitchy.
// TILT_SMOOTH  — EMA weight on the raw accel reading (higher = snappier).
// TILT_FOLLOW  — how fast the paddle eases toward the tilt target per tick
//                (lower = smoother/softer, higher = more immediate).
// TILT_DEADZONE— milli-g ignored around neutral so a steady wrist is still.
const TILT_RANGE    = 320.0;
const TILT_SMOOTH   = 0.30;
const TILT_FOLLOW   = 0.18;
const TILT_DEADZONE = 35;
