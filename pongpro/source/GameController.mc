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
const MI_START      = 1;
const MI_ITEMS      = 2;

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
        // Continuous paddle-hold flags must be primed so the first
        // onKeyPressed call doesn't dereference a null in the
        // boolean expressions inside _recomputePlayerVy().
        _holdUp = false; _holdDown = false;
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
    }

    function startMatch() {
        scoreP = 0; scoreCpu = 0;
        lastWinner = -1;
        setDifficulty(difficulty);  // reapply
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
                ball.reset((playX0 + playX1) / 2,
                           (playY0 + playY1) / 2,
                           baseBallSpeed, toLeft);
                state = GS_PLAY;
            }
            // Paddles still respond to player input even during serve.
            pPlayer.step();
            return;
        }
        // GS_PLAY
        pPlayer.step();
        ai.step(pCpu, ball, playX0, playY0, playX1, playY1);
        pCpu.step();

        var res = ball.step(playX0, playY0, playX1, playY1);

        // Paddle collisions
        ball.tryPaddleBounce(pPlayer.x, pPlayer.y, pPlayer.w, pPlayer.h, -1);
        ball.tryPaddleBounce(pCpu.x,    pCpu.y,    pCpu.w,    pCpu.h,    +1);

        if (res == -1) {
            // ball passed left wall — CPU scored
            scoreCpu = scoreCpu + 1;
            lastWinner = 1;
            _afterPoint();
        } else if (res == 1) {
            scoreP = scoreP + 1;
            lastWinner = 0;
            _afterPoint();
        }
    }

    hidden function _afterPoint() {
        if (scoreP >= MATCH_POINTS || scoreCpu >= MATCH_POINTS) {
            if (scoreP > scoreCpu) {
                hiPlayerWins = hiPlayerWins + 1;
                _saveStat();
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
        // Recentre AI paddle a bit and let it pick a fresh random error.
        ai.onServe(paddleH / 2);
        state = GS_SERVE;
    }
}

// Player paddle movement speed — defined at module scope so both
// GameController (computing vy) and tests can reference it.
const PLAYER_SPEED = 4.4;
