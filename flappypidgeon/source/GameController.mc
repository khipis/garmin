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
//
// Meta-progression (shared, shop-ready via the Progress module):
//   • Coins + XP are awarded on death, scaled by the run's score.
//   • Rank milestones unlock cosmetic bird skins (NEON at Lv 3,
//     GOLD at Lv 6). Ownership is the exact set a future shop would
//     grant, so nothing here blocks monetising skins later.
// ═══════════════════════════════════════════════════════════════

using Toybox.System;
using Toybox.Application;
using Toybox.Attention;

// Sound + haptics master switch (OPTIONS: fp_fx). 0/unset = ON, 1 = OFF.
const FP_FX_KEY = "fp_fx";

const GS_MENU  = 0;
const GS_READY = 1;
const GS_PLAY  = 2;
const GS_OVER  = 3;

// Background theme, shifting with score: day → sunset → night.
const THEME_DAY    = 0;
const THEME_SUNSET = 1;
const THEME_NIGHT  = 2;

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

    // UI feedback / juice
    var deathFlash;      // ticks remaining of white flash
    var shake;           // ticks remaining of screen shake
    var bgScroll;        // background skyline scroll offset (px)
    var particles;       // feather burst + near-miss sparks
    var nearMissT;       // ticks remaining of the "NICE!" popup

    // Meta-progression display state
    var pgUnlockMsg;     // one-shot "UNLOCKED: <skin>" banner, or null
    var toastMsg;        // daily-bonus toast text, or null
    var toastT;          // ticks remaining to show the toast

    // OPTIONS "Gap" (fp_gap): 0=WIDE 1=NORMAL 2=TIGHT. Adjusts the pipe gap
    // height. NORMAL (1) is today's feel so the default experience is unchanged.
    var gapSel;

    hidden var _fxOn;   // sound + haptics master switch (OPTIONS: fp_fx)

    function initialize() {
        state       = GS_MENU;
        bird        = new Bird();
        obstacles   = new ObstacleManager();
        particles   = new Particles();
        score       = 0;
        hi          = _loadHi();
        screenW = 240; screenH = 240; ceilY = 0; floorY = 240;
        scaleNum = 240; scaleDen = 240;
        pipeWidth = 22;
        deathFlash = 0;
        shake      = 0;
        bgScroll = 0;
        nearMissT = 0;
        pgUnlockMsg = null;
        toastMsg  = null;
        toastT    = 0;

        gapSel = 1;
        try {
            var v = Application.Storage.getValue("fp_gap");
            if (v != null && v instanceof Number && v >= 0 && v <= 2) { gapSel = v; }
        } catch (e) { }
        // Wider gaps = easier; tighter = harder. Bias in 240-ref px.
        obstacles.setGapBias([16, 0, -16][gapSel]);

        _fxOn = _loadFx();
    }

    // ── Sound + haptics (best-effort; silent hardware is fine) ────
    hidden function _loadFx() {
        try {
            var v = Application.Storage.getValue(FP_FX_KEY);
            if (v instanceof Number && v == 1) { return false; }
        } catch (e) { }
        return true;
    }
    // kind: 0 flap · 1 score · 2 near-miss · 3 death
    hidden function _tone(kind) {
        if (!_fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :playTone)) { return; }
        var t;
        if      (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
        else if (kind == 2) { t = Attention.TONE_ALERT_HI; }
        else if (kind == 3) { t = Attention.TONE_FAILURE; }
        else                { t = Attention.TONE_KEY; }
        try { Attention.playTone(t); } catch (e) {}
    }
    hidden function _vibe(intensity, duration) {
        if (!_fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :vibrate)) { return; }
        try { Attention.vibrate([new Attention.VibeProfile(intensity, duration)]); } catch (e) {}
    }

    // Leaderboard variant = gap size, so WIDE/NORMAL/TIGHT rank separately.
    function variant() {
        return ["wide", "normal", "tight"][gapSel];
    }

    // Background theme derived from the current score.
    function theme() {
        if (score >= 25) { return THEME_NIGHT; }
        if (score >= 10) { return THEME_SUNSET; }
        return THEME_DAY;
    }

    // Effective (clamped-to-owned) bird skin. A selection the player hasn't
    // unlocked yet falls back to CLASSIC — locked picks never render.
    function effectiveSkin() {
        var sel = 0;
        try {
            var v = Application.Storage.getValue("fp_skin");
            if (v instanceof Number) { sel = v; }
        } catch (e) {}
        try {
            if (sel == 2 && Progress.owns("skin_gold")) { return 2; }
            if (sel == 1 && Progress.owns("skin_neon")) { return 1; }
        } catch (e) {}
        return 0;
    }

    // Themed rank ladder from the shared XP level.
    function rankName() {
        var lvl = 1;
        try { lvl = Progress.level(); } catch (e) {}
        if (lvl >= 25) { return "Sky Legend"; }
        if (lvl >= 15) { return "Sky King"; }
        if (lvl >= 10) { return "Ace"; }
        if (lvl >= 6)  { return "Glider"; }
        if (lvl >= 3)  { return "Flyer"; }
        return "Hatchling";
    }

    // Score-medal tier for the game-over card: 0 none, 1 bronze, 2 silver, 3 gold.
    function medalTier() {
        if (score >= 40) { return 3; }
        if (score >= 20) { return 2; }
        if (score >= 8)  { return 1; }
        return 0;
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

    // Pop the queued daily-bonus toast (set by the App's checkIn) so the view
    // can show it once, non-blocking, over the sky.
    function pullDailyToast() {
        try {
            var dm = Application.Storage.getValue("fp_daily_msg");
            if (dm != null) {
                toastMsg = dm;
                toastT   = 90;
                Application.Storage.deleteValue("fp_daily_msg");
            }
        } catch (e) {}
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
        bird.skin      = effectiveSkin();
        bird.showTrail = true;
        var startGap = obstacles.gapForScore(0, scaleNum, scaleDen);
        obstacles.reset();
        obstacles.prime(startGap);
        particles.reset();
        score       = 0;
        deathFlash  = 0;
        shake       = 0;
        nearMissT   = 0;
        pgUnlockMsg = null;
        _fxOn       = _loadFx();
        state       = GS_READY;
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
            _tone(0);
            _vibe(20, 25);
            return;
        }
        if (state == GS_PLAY) {
            bird.flap();
            // Wing-beat blip + a feather-light tick (per-tap, never per-frame).
            _tone(0);
            _vibe(20, 25);
        }
    }

    // Fixed-tick step (called by the view at TICK_MS).
    function step() {
        if (toastT > 0) { toastT = toastT - 1; }
        if (nearMissT > 0) { nearMissT = nearMissT - 1; }
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
            var added = obstacles.step(dx, bird.x, bird.y, bird.radius,
                                       score, scaleNum, scaleDen);
            score = score + added;
            if (added > 0) {
                // Cleared a pipe — crisp reward beep + light kick.
                _tone(1);
                _vibe(35, 40);
            }
            // Near-miss reward: a tiny bonus point + a bright spark burst.
            if (added > 0 && obstacles.nearMiss == 1) {
                score = score + 1;
                nearMissT = 12;
                var sc = (bird.skin == 2) ? 0xFFDD66 : 0x88FFCC;
                particles.spark(bird.x, obstacles.nearMissY, sc);
                // Stylish squeak-past — extra bright chirp.
                _tone(2);
            }
            if (obstacles.collides(bird.bbox())) {
                _die();
            }
            particles.step();
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
            if (shake > 0) { shake = shake - 1; }
            particles.step();
            return;
        }
    }

    hidden function _die() {
        bird.alive = false;
        deathFlash = 4;
        shake      = 7;
        bird.showTrail = false;
        // Feather burst in the bird's own skin colour.
        var fc = 0x999999;
        if (bird.skin == 1) { fc = 0x33E0B0; }
        if (bird.skin == 2) { fc = 0xFFCC22; }
        particles.burst(bird.x, bird.y, 14, fc);
        // Splat! — harsh failure tone + a long, heavy crash rumble.
        _tone(3);
        _vibe(100, 320);
        if (score > hi) { hi = score; _saveHi(); }
        state = GS_OVER;
        // Submit to the shared global leaderboard (fire-and-forget),
        // segmented by the chosen gap-size variant.
        Leaderboard.submitScore("flappypidgeon", score, variant());
        Leaderboard.showPostGame("flappypidgeon", variant(), "FLAPPY");
        _awardProgress();
    }

    // ── Meta-progression (shared, shop-ready via Progress module) ────────────
    // Grant coins + XP scaled by the run's score, then unlock cosmetic bird
    // skins at rank milestones. Fully guarded — never throws on any device.
    hidden function _awardProgress() {
        try {
            var coinsGain = 3 + score * 2;
            var xpGain    = 6 + score * 5;
            Progress.addCoins(coinsGain);
            Progress.addXp(xpGain);
            var lvl  = Progress.level();
            var uNeon = Progress.unlockIfReached("skin_neon", lvl, 3);
            var uGold = Progress.unlockIfReached("skin_gold", lvl, 6);
            if (uGold)      { pgUnlockMsg = "UNLOCKED: GOLD"; }
            else if (uNeon) { pgUnlockMsg = "UNLOCKED: NEON"; }
        } catch (e) {}
    }
}
