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
const SB_FX_KEY          = "sb_fx";   // 0 = sound + haptics ON, 1 = OFF
const SB_SKIN_KEY        = "slot_skin"; // 0 = CLASSIC, 1 = GOLD (needs unlock)

// Cosmetic machine skin unlock (shared, shop-ready via Progress ownership).
const SB_SKIN_GOLD_ID    = "machine_gold";
const SB_SKIN_GOLD_LEVEL = 4;         // Progress.level() milestone for GOLD

// Combo streak: each consecutive winning spin bumps the multiplier applied
// to the next payout, up to SB_MULT_MAX. A losing spin resets it.
const SB_MULT_MAX        = 5;
// Free-spin bonuses added to the budget on big hits.
const SB_BONUS_TRIPLE    = 2;
const SB_BONUS_JACKPOT   = 5;

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

    // Juice + engagement runtime (all consumed by Render/UI).
    var fxOn;         // sound + haptics master switch (OPTIONS: sb_fx)
    var combo;        // consecutive winning spins
    var bestCombo;    // best streak this round
    var mult;         // current payout multiplier (1..SB_MULT_MAX)
    var lastGain;     // points added by the most recent spin (post-multiplier)
    var bonusFlash;   // countdown frames for the free-spin banner
    var bonusText;    // free-spin banner text
    var shakeT;       // screen-shake countdown frames
    var winPulseT;    // payline win-pulse countdown frames
    var anticIdx;     // reel index under near-miss anticipation, or -1
    hidden var _anticOn; // whether the drumroll cue already fired this near-miss

    // One-shot "UNLOCKED: <name>" banner for the round-over screen. Set by the
    // progression layer when a round crosses a cosmetic milestone; cleared at
    // the start of each round.
    var pgUnlockMsg;

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
        fxOn       = _loadFx();
        combo      = 0;
        bestCombo  = 0;
        mult       = 1;
        lastGain   = 0;
        bonusFlash = 0;
        bonusText  = "";
        shakeT     = 0;
        winPulseT  = 0;
        anticIdx   = -1;
        _anticOn   = false;
        pgUnlockMsg = null;
    }

    hidden function _loadFx() {
        try {
            var v = Application.Storage.getValue(SB_FX_KEY);
            if (v instanceof Number && v == 1) { return false; }
        } catch (e) { }
        return true;
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
        fxOn       = _loadFx();
        combo      = 0;
        bestCombo  = 0;
        mult       = 1;
        lastGain   = 0;
        bonusFlash = 0;
        bonusText  = "";
        shakeT     = 0;
        winPulseT  = 0;
        anticIdx   = -1;
        _anticOn   = false;
        pgUnlockMsg = null;
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
            if (idx >= 0) { SpinLogic.requestStop(reels, idx); _tone("stop"); _vibe(20, 40); }
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
            _tone("stop"); _vibe(20, 40);
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
        _autoT    = AUTO_DELAY_TICKS;
        leverT    = LEVER_FRAMES;
        anticIdx  = -1;
        _anticOn  = false;
        _tone("spin");
        _vibe(15, 30);
    }

    function step() {
        if (state != GS_PLAY) { return; }

        // Cosmetic countdowns tick regardless of spin state.
        if (leverT     > 0) { leverT     = leverT - 1; }
        if (shakeT     > 0) { shakeT     = shakeT - 1; }
        if (winPulseT  > 0) { winPulseT  = winPulseT - 1; }
        if (bonusFlash > 0) { bonusFlash = bonusFlash - 1; }

        if (spinState == SS_SPINNING) {
            // Near-miss anticipation: two matching reels locked, one to go —
            // crawl the last reel + fire a one-shot drumroll cue.
            anticIdx = reels.anticIndex();
            if (anticIdx >= 0) {
                if (!_anticOn) {
                    _anticOn = true;
                    _tone("antic");
                    _vibe(45, 90);
                }
                reels.stepWith(anticIdx);
            } else {
                _anticOn = false;
                reels.step();
            }

            if (autoPlay) {
                _autoT = _autoT - 1;
                if (_autoT <= 0) {
                    var idx = reels.nextSpinningIndex();
                    if (idx >= 0) { SpinLogic.requestStop(reels, idx); _tone("stop"); }
                    _autoT = AUTO_DELAY_TICKS;
                }
            }
            if (reels.allStopped()) { _resolveSpin(); }
        } else {
            reels.step();
            if (spinState == SS_RESULT) {
                resultT = resultT - 1;
                if (resultT <= 0) { _advanceFromResult(); }
            }
        }
    }

    hidden function _resolveSpin() {
        anticIdx = -1;
        _anticOn = false;

        var syms   = reels.paylineSymbols();

        // Collectible symbols: persist every DISTINCT reel symbol the player
        // has ever landed on the payline. Progress.unlock is idempotent and
        // internally guarded; wrap defensively so a bad Storage state can never
        // break a spin resolution.
        try {
            for (var si = 0; si < syms.size(); si++) {
                Progress.unlock("sym_" + syms[si].toString());
            }
        } catch (e) {}

        var result = SpinLogic.evaluate(syms);
        var kind   = result["kind"];

        // ── Combo streak → payout multiplier ──
        if (kind == "NONE") {
            combo = 0;
            mult  = 1;
        } else {
            combo = combo + 1;
            if (combo > bestCombo) { bestCombo = combo; }
            mult = combo;
            if (mult > SB_MULT_MAX) { mult = SB_MULT_MAX; }
            if (mult < 1) { mult = 1; }
        }

        var gain = result["payout"] * mult;
        result["mult"] = mult;
        result["gain"] = gain;
        lastGain = gain;
        scoreSys.registerResultGain(result, gain);

        lastResult = result;
        spinState  = SS_RESULT;
        resultT    = SLOT_RESULT_TICKS;

        // ── Free-spin bonuses on big hits ──
        if (kind == "JACKPOT") {
            scoreSys.addSpins(SB_BONUS_JACKPOT);
            bonusText  = "+" + SB_BONUS_JACKPOT.toString() + " FREE SPINS";
            bonusFlash = SLOT_RESULT_TICKS + 8;
        } else if (kind == "TRIPLE") {
            scoreSys.addSpins(SB_BONUS_TRIPLE);
            bonusText  = "+" + SB_BONUS_TRIPLE.toString() + " FREE SPINS";
            bonusFlash = SLOT_RESULT_TICKS + 8;
        }

        // ── Feedback: haptics, tones, shake, payline pulse ──
        if (kind == "JACKPOT") {
            _vibe(100, 400); _tone("jackpot");
            shakeT = 14; winPulseT = SLOT_RESULT_TICKS;
        } else if (kind == "TRIPLE") {
            _vibe(70, 220); _tone("triple");
            shakeT = 8; winPulseT = SLOT_RESULT_TICKS;
        } else if (kind == "PAIR") {
            _vibe(35, 100); _tone("pair");
            winPulseT = SLOT_RESULT_TICKS;
        }
        // A hot streak gets its own extra sting.
        if (kind != "NONE" && mult >= 3) { _tone("combo"); _vibe(30, 70); }
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
        _awardProgress();
        if (_newBest) { _tone("jackpot"); _vibe(90, 300); }
        else          { _tone("over");    _vibe(40, 120); }
        Leaderboard.submitScore(LB_GAME_ID, scoreSys.score, roundName());
        if (scoreSys.jackpots > 0) {
            Leaderboard.submitScore(LB_GAME_ID, scoreSys.jackpots, "jackpots");
        }
        Leaderboard.showPostGame(LB_GAME_ID, roundName(), "SLOT BANDIT");
    }

    function hasNewBest() { return _newBest; }

    // ── Meta-progression (shared, shop-ready via Progress module) ────────────
    // Grants coins + XP proportional to the round's score/jackpots and unlocks
    // the GOLD machine skin at a rank milestone. Coins are the future shop's
    // currency; skin ownership is the exact set a shop purchase would grant, so
    // nothing here blocks monetising more skins later.
    hidden function _awardProgress() {
        try {
            var sc = scoreSys.score;
            if (sc < 0) { sc = 0; }
            // ~1 coin per 20 points, plus a chunky bonus per jackpot landed.
            var coinsGain = sc / 20 + scoreSys.jackpots * 10;
            if (coinsGain > 150) { coinsGain = 150; }
            // XP: a flat completion reward + score/jackpot scaling.
            var xpGain = 8 + sc / 40 + scoreSys.jackpots * 15;
            if (coinsGain > 0) { Progress.addCoins(coinsGain); }
            if (xpGain    > 0) { Progress.addXp(xpGain); }
            var lvl = Progress.level();
            if (Progress.unlockIfReached(SB_SKIN_GOLD_ID, lvl, SB_SKIN_GOLD_LEVEL)) {
                pgUnlockMsg = "UNLOCKED: GOLD";
            }
        } catch (e) {}
    }

    // Selected-and-owned machine skin. Returns true only when GOLD is picked
    // AND owned — a locked pick falls back to the classic brass cabinet, keeping
    // selection safe pre-shop and post-shop alike.
    function skinGold() {
        var sel = 0;
        try {
            var v = Application.Storage.getValue(SB_SKIN_KEY);
            if (v instanceof Number) { sel = v; }
        } catch (e) {}
        if (sel == 1) {
            try { return Progress.owns(SB_SKIN_GOLD_ID); } catch (e) {}
        }
        return false;
    }

    // ── Game-over progression summary accessors (read by UIManager) ──────────
    function metaLevel() { try { return Progress.level(); } catch (e) {} return 1; }
    function metaCoins() { try { return Progress.coins(); } catch (e) {} return 0; }
    function metaStreak() { try { return Progress.currentStreak(); } catch (e) {} return 0; }

    // Themed rank ladder derived from the shared XP level.
    function metaRank() {
        var l = metaLevel();
        if (l >= 25) { return "Legend"; }
        if (l >= 15) { return "Whale"; }
        if (l >= 10) { return "High Roller"; }
        if (l >= 6)  { return "Gambler"; }
        if (l >= 3)  { return "Player"; }
        return "Rookie";
    }

    // Collectible-symbol counts for the "Symbols owned/total" summary.
    function symbolsTotal() { return SYM_COUNT; }
    function symbolsOwned() {
        try {
            var ids = new [SYM_COUNT];
            for (var i = 0; i < SYM_COUNT; i++) { ids[i] = "sym_" + i.toString(); }
            return Progress.ownedIn(ids);
        } catch (e) {}
        return 0;
    }

    // ── Sound & haptics (gated by the sb_fx OPTION) ─────────────────
    hidden function _tone(kind) {
        if (!fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :playTone)) { return; }
        var t = null;
        if (kind.equals("jackpot")) {
            t = Attention.TONE_SUCCESS;
        } else if (kind.equals("triple")) {
            t = Attention.TONE_LOUD_BEEP;
        } else if (kind.equals("pair")) {
            t = Attention.TONE_KEY;
        } else if (kind.equals("combo")) {
            t = Attention.TONE_LAP;
        } else if (kind.equals("spin")) {
            t = Attention.TONE_KEY;
        } else if (kind.equals("stop")) {
            t = Attention.TONE_KEY;
        } else if (kind.equals("antic")) {
            t = Attention.TONE_ALERT_HI;
        } else if (kind.equals("over")) {
            t = Attention.TONE_RESET;
        }
        if (t == null) { t = Attention.TONE_KEY; }
        try { Attention.playTone(t); } catch (e) { }
    }

    hidden function _vibe(intensity, duration) {
        if (!fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :vibrate)) { return; }
        try {
            Attention.vibrate([new Attention.VibeProfile(intensity, duration)]);
        } catch (e) { }
    }
}
