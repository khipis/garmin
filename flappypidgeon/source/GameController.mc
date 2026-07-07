// ═══════════════════════════════════════════════════════════════
// GameController.mc — Orchestrates Bird, ObstacleManager, scoring.
//
// States:
//   GS_MENU      title screen — first flap starts the round
//   GS_READY     bird hovers at centre, awaiting first flap
//   GS_PLAY      live gameplay
//   GS_OVER      death — animate fall + show score
//
// Difficulty growth is captured inside ObstacleManager via the
// `score` it's handed each tick — no per-frame branching here.
// ═══════════════════════════════════════════════════════════════

using Toybox.System;
using Toybox.Application;

const GS_MENU  = 0;
const GS_READY = 1;
const GS_PLAY  = 2;
const GS_OVER  = 3;

class GameController {
    var state;
    var bird;
    var obstacles;
    var score;
    var hi;

    // Screen-derived scaling
    var screenW;
    var screenH;
    var ceilY;
    var floorY;
    var scaleNum;        // = screenH
    var scaleDen;        // = 240 (the reference height we tuned for)
    var pipeWidth;

    // UI feedback
    var deathFlash;      // ticks remaining of white flash
    var bgScroll;        // background skyline scroll offset (px)

    // OPTIONS "Gap" (fp_gap): 0=WIDE 1=NORMAL 2=TIGHT. Adjusts the pipe gap
    // height. NORMAL (1) is today's feel so the default experience is unchanged.
    var gapSel;

    function initialize() {
        state       = GS_MENU;
        bird        = new Bird();
        obstacles   = new ObstacleManager();
        score       = 0;
        hi          = _loadHi();
        screenW = 240; screenH = 240; ceilY = 0; floorY = 240;
        scaleNum = 240; scaleDen = 240;
        pipeWidth = 22;
        deathFlash = 0;
        bgScroll = 0;

        gapSel = 1;
        try {
            var v = Application.Storage.getValue("fp_gap");
            if (v != null && v instanceof Number && v >= 0 && v <= 2) { gapSel = v; }
        } catch (e) { }
        // Wider gaps = easier; tighter = harder. Bias in 240-ref px.
        obstacles.setGapBias([16, 0, -16][gapSel]);
    }

    // Leaderboard variant = gap size, so WIDE/NORMAL/TIGHT rank separately.
    function variant() {
        return ["wide", "normal", "tight"][gapSel];
    }

    hidden function _loadHi() {
        try {
            var v = Application.Storage.getValue("hi");
            if (v != null && v instanceof Number && v > 0) { return v; }
        } catch (e) { }
        return 0;
    }
    hidden function _saveHi() {
        try { Application.Storage.setValue("hi", hi); } catch (e) { }
    }

    function setScreen(w, h) {
        screenW  = w;
        screenH  = h;
        // Reserve ~16% at top for HUD + ground stripe at bottom.
        ceilY    = 0;
        floorY   = h - (h * 10) / 100;
        scaleNum = h;
        scaleDen = 240;
        // Pipe width scales with screen — ~9% of width clamped sane.
        pipeWidth = (w * 9) / 100;
        if (pipeWidth < 14) { pipeWidth = 14; }
        if (pipeWidth > 28) { pipeWidth = 28; }
        obstacles.setBounds(w, ceilY, floorY, pipeWidth);
    }

    function ready() {
        // Place bird ~1/3 in from left, centre-y, reset velocity.
        var bx = screenW / 3;
        var by = screenH / 2;
        var br = (screenH * 4) / 100;
        if (br < 7) { br = 7; }
        bird.reset(bx, by, br);
        var startGap = obstacles.gapForScore(0, scaleNum, scaleDen);
        obstacles.reset();
        obstacles.prime(startGap);
        score      = 0;
        deathFlash = 0;
        state      = GS_READY;
    }

    function gotoMenu() {
        state = GS_MENU;
    }

    // Player tap / SELECT.
    function flapAction() {
        if (state == GS_MENU) { ready(); state = GS_READY; return; }
        if (state == GS_OVER) { gotoMenu(); return; }
        if (state == GS_READY) {
            state = GS_PLAY;
            bird.flap();
            return;
        }
        if (state == GS_PLAY) {
            bird.flap();
        }
    }

    // Fixed-tick step (called by the view at TICK_MS).
    function step() {
        if (state == GS_MENU) { bgScroll = (bgScroll + 1) % 1000; return; }
        if (state == GS_READY) {
            // Hover bobble — sinusoidal-ish without trig: triangle wave.
            // Use a private counter via bird.wingPhase repurposed.
            bird.wingPhase = (bird.wingPhase + 1) % 24;
            var phase = bird.wingPhase;
            var dy = (phase < 12) ? phase - 6 : 18 - phase;
            bird.y = (screenH / 2) + (dy / 3);
            return;
        }
        if (state == GS_PLAY) {
            bird.step();
            var dx = obstacles.scrollForScore(score);
            var added = obstacles.step(dx, bird.x, score, scaleNum, scaleDen);
            score = score + added;
            if (obstacles.collides(bird.bbox())) {
                _die();
            }
            bgScroll = (bgScroll + 1) % 1000;
            return;
        }
        if (state == GS_OVER) {
            // Death fall — bird tumbles to floor, no scroll.
            if (bird.y < floorY - bird.radius) {
                bird.step();
                if (bird.y > floorY - bird.radius) { bird.y = floorY - bird.radius; bird.vy = 0; }
            }
            if (deathFlash > 0) { deathFlash = deathFlash - 1; }
            return;
        }
    }

    hidden function _die() {
        bird.alive = false;
        deathFlash = 4;
        if (score > hi) { hi = score; _saveHi(); }
        state = GS_OVER;
        // Submit to the shared global leaderboard (fire-and-forget),
        // segmented by the chosen gap-size variant.
        Leaderboard.submitScore("flappypidgeon", score, variant());
        Leaderboard.showPostGame("flappypidgeon", variant(), "FLAPPY");
    }
}
