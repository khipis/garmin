// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine, round/menu wiring, spin
// sequencing, leaderboard submission.
//
// SLOT BANDIT is a "skill slot": every spin is stop-it-yourself.
// One button/tap starts the reels; the SAME input then stops
// whichever reel is still spinning next (or a tapped reel column
// directly). The exact tick you press determines — via SpinLogic's
// pull-in window — whether a near-miss becomes a match. There is no
// pure-RNG "auto-resolve"; the player always makes the final call.
// ═══════════════════════════════════════════════════════════════
using Toybox.System;
using Toybox.Application;
using Toybox.Attention;

const GS_MENU = 0;
const GS_PLAY = 1;
const GS_OVER = 2;

// In-round sub-state.
const SS_IDLE     = 0;
const SS_SPINNING = 1;
const SS_RESULT   = 2;

// Chess-style menu rows: Round length | START | LEADERBOARD.
const SB_MENU_ROWS = 3;
const SB_ROW_ROUND = 0;
const SB_ROW_START = 1;
const SB_ROW_LB    = 2;

const LB_GAME_ID = "slotbandit";

const SB_ROUND_QUICK     = 0;
const SB_ROUND_NORMAL    = 1;
const SB_ROUND_MARATHON  = 2;
const SB_ROUND_COUNT     = 3;
const SB_ROUND_SPINS     = [10, 20, 35];
const SB_ROUND_NAMES     = ["Quick", "Normal", "Marathon"];
const SB_ROUND_KEY       = "sb_round";

const TICK_MS = 50;

// Reel tuning — see SpinLogic for how the pull-in window creates the
// "skill" in skill-stop.
const SLOT_SPIN_SPEED   = 0.55;   // strip symbols advanced per tick
const SLOT_PULLIN_MAX   = 3;      // max forward symbols the stop can "grab"
const SLOT_DECEL_TICKS  = 6;      // ticks to ease from spin speed to a dead stop
const SLOT_RESULT_TICKS = 18;     // ticks the result stays on screen (~900 ms)
const AUTO_DELAY_TICKS  = 9;      // auto-play's per-reel "thinking" delay
const LEVER_FRAMES      = 7;      // cosmetic one-armed-bandit lever pull

class GameController {
    var state;
    var spinState;
    var reels;
    var scoreSys;

    // Menu
    var menuRow;
    var menuRound;

    // Round runtime
    var resultT;
    var lastResult;   // dict from SpinLogic.evaluate(), or null
    var autoPlay;
    var leverT;      // cosmetic lever-pull countdown, consumed by RenderSystem
    hidden var _autoT;
    hidden var _newBest;

    function initialize() {
        state      = GS_MENU;
        spinState  = SS_IDLE;
        reels      = new ReelSystem();
        scoreSys   = new ScoreSystem();
        menuRow    = SB_ROW_START;
        menuRound  = _loadRound();
        resultT    = 0;
        lastResult = null;
        autoPlay   = false;
        leverT     = 0;
        _autoT     = 0;
        _newBest   = false;
    }

    hidden function _loadRound() {
        try {
            var v = Application.Storage.getValue(SB_ROUND_KEY);
            if (v != null && v instanceof Number && v >= 0 && v < SB_ROUND_COUNT) { return v; }
        } catch (e) { }
        return SB_ROUND_NORMAL;
    }
    hidden function _saveRound() {
        try { Application.Storage.setValue(SB_ROUND_KEY, menuRound); } catch (e) { }
    }
    hidden function _hiKey() { return "sb_hi" + menuRound.toString(); }

    function roundName()  { return SB_ROUND_NAMES[menuRound]; }
    function roundSpins() { return SB_ROUND_SPINS[menuRound]; }

    // ── Menu nav ────────────────────────────────────────────
    function menuPrev()    { menuRow = (menuRow + SB_MENU_ROWS - 1) % SB_MENU_ROWS; }
    function menuNext()    { menuRow = (menuRow + 1) % SB_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < SB_MENU_ROWS) { menuRow = i; } }
    function menuActivate() {
        if (menuRow == SB_ROW_ROUND) {
            menuRound = (menuRound + 1) % SB_ROUND_COUNT;
            _saveRound();
        } else if (menuRow == SB_ROW_START) {
            startGame();
        }
        // SB_ROW_LB handled by MainView (it can push views).
    }

    function gotoMenu() { state = GS_MENU; }

    // ── Lifecycle ───────────────────────────────────────────
    function startGame() {
        reels.reset();
        scoreSys.reset(roundSpins());
        scoreSys.loadHi(_hiKey());
        spinState  = SS_IDLE;
        resultT    = 0;
        lastResult = null;
        autoPlay   = false;
        leverT     = 0;
        _autoT     = 0;
        _newBest   = false;
        state      = GS_PLAY;
    }

    // ── Primary action — context-sensitive spin / stop-next / dismiss ──
    function primaryAction() {
        if (state == GS_OVER) { startGame(); return; }
        if (state != GS_PLAY) { return; }

        if (spinState == SS_IDLE) {
            _beginSpin();
        } else if (spinState == SS_SPINNING) {
            var idx = reels.nextSpinningIndex();
            if (idx >= 0) { SpinLogic.requestStop(reels, idx); }
        } else if (spinState == SS_RESULT) {
            _advanceFromResult();
        }
    }

    // Tap a specific reel column directly — lets touch players choose
    // stop ORDER themselves instead of strictly left-to-right.
    function stopReelAt(idx) {
        if (state != GS_PLAY || spinState != SS_SPINNING) { return; }
        if (idx < 0 || idx > 2) { return; }
        if (reels.reels[idx].state == REEL_SPINNING) {
            SpinLogic.requestStop(reels, idx);
        }
    }

    function toggleAuto() {
        if (state != GS_PLAY) { return; }
        autoPlay = !autoPlay;
        if (autoPlay && spinState == SS_IDLE && !scoreSys.roundOver()) {
            _beginSpin();
        }
    }

    hidden function _beginSpin() {
        if (scoreSys.roundOver()) { return; }
        reels.spinAll();
        spinState = SS_SPINNING;
        _autoT  = AUTO_DELAY_TICKS;
        leverT  = LEVER_FRAMES;
    }

    function step() {
        if (state != GS_PLAY) { return; }
        reels.step();
        if (leverT > 0) { leverT = leverT - 1; }

        if (spinState == SS_SPINNING) {
            if (autoPlay) {
                _autoT = _autoT - 1;
                if (_autoT <= 0) {
                    var idx = reels.nextSpinningIndex();
                    if (idx >= 0) { SpinLogic.requestStop(reels, idx); }
                    _autoT = AUTO_DELAY_TICKS;
                }
            }
            if (reels.allStopped()) { _resolveSpin(); }
        } else if (spinState == SS_RESULT) {
            resultT = resultT - 1;
            if (resultT <= 0) { _advanceFromResult(); }
        }
    }

    hidden function _resolveSpin() {
        var syms = reels.paylineSymbols();
        var result = SpinLogic.evaluate(syms);
        scoreSys.registerResult(result);
        lastResult = result;
        spinState  = SS_RESULT;
        resultT    = SLOT_RESULT_TICKS;
        if (result["kind"] == "JACKPOT") { _vibe(100, 400); }
        else if (result["kind"] == "TRIPLE") { _vibe(70, 220); }
        else if (result["kind"] == "PAIR") { _vibe(35, 100); }
    }

    hidden function _advanceFromResult() {
        spinState  = SS_IDLE;
        lastResult = null;
        if (scoreSys.roundOver()) {
            _endRound();
        } else if (autoPlay) {
            _beginSpin();
        }
    }

    hidden function _endRound() {
        _newBest = false;
        if (scoreSys.score > scoreSys.hi) {
            scoreSys.hi = scoreSys.score;
            scoreSys.saveHi(_hiKey());
            _newBest = true;
        }
        state = GS_OVER;
        Leaderboard.submitScore(LB_GAME_ID, scoreSys.score, roundName());
        if (scoreSys.jackpots > 0) {
            Leaderboard.submitScore(LB_GAME_ID, scoreSys.jackpots, "jackpots");
        }
        Leaderboard.showPostGame(LB_GAME_ID, roundName(), "SLOT BANDIT");
    }

    function hasNewBest() { return _newBest; }

    hidden function _vibe(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }
}
