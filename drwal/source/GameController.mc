// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine, chop resolution, energy /
// difficulty curve, menu + leaderboard wiring.
//
// DRWAL is deliberately turn-free: every chop is a single, instant
// state mutation (side snap + hit test + tree advance). Any visual
// smoothing (tree slide, axe swing, shake) lives purely in the view
// layer (MainView/RenderSystem) and never delays or gates the next
// input — a chop always registers on the very frame it happens.
// ═══════════════════════════════════════════════════════════════

using Toybox.System;
using Toybox.Application;
using Toybox.Attention;

const GS_MENU = 0;
const GS_PLAY = 1;
const GS_OVER = 2;

// Chess-style menu rows: Diff | START | LEADERBOARD.
const DR_MENU_ROWS = 3;
const DR_ROW_DIFF  = 0;
const DR_ROW_START = 1;
const DR_ROW_LB    = 2;

// Global leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "drwal";

const DR_DIFF_EASY   = 0;
const DR_DIFF_NORMAL = 1;
const DR_DIFF_HARD   = 2;
const DR_DIFF_KEY    = "dr_diff";
const DR_HI_KEY      = "dr_hi";
const DR_FX_KEY      = "dr_fx";   // 0 = sound+haptics ON, 1 = OFF

const SIDE_LEFT  = -1;
const SIDE_RIGHT = 1;

// A segment carries a branch on AT MOST one side (or none) — the
// opposite side is therefore always a guaranteed-safe escape, so the
// generator can never paint the player into an unavoidable death.
const SEG_NONE  = 0;
const SEG_LEFT  = 1;
const SEG_RIGHT = 2;
const TG_VISIBLE = 7;

const ENERGY_MAX = 1000;

const SWING_FRAMES      = 5;   // axe-swing pose,        5 * 50 ms = 250 ms
const SCROLL_FRAMES     = 5;   // tree slide-down tween,  5 * 50 ms = 250 ms
const DEAD_SHAKE_FRAMES = 10;  // screen shake on death
const POP_FRAMES        = 12;  // "+N" score popup rise/fade on each chop

const COMBO_WINDOW_MS = 480;   // chops inside this window keep the combo alive
const COMBO_CAP       = 6;     // max bonus points per chop from combo

const TICK_MS = 50;

class GameController {
    var state;
    var player;
    var tree;
    var scoreSys;

    // Menu
    var menuRow;
    var menuDiff;

    // Run state
    var energy;
    var scrollT;        // frames left of the tree slide-down tween
    var deathReason;     // "" | "HIT" | "TIMEOUT" — drives the over-screen text
    hidden var _newBest;

    // Cosmetic-only clocks read by the renderer.
    var frame;           // free-running animation tick (stars twinkle, etc.)
    var popPts;          // points from the last chop (drives the "+N" popup)
    var popT;            // frames left of the "+N" popup
    var popSide;         // side the last chop landed on (popup offset)
    hidden var _fxOn;    // sound + haptics master switch (OPTIONS: dr_fx)

    // Juice + engagement (all cosmetic — never affects the submitted score).
    var fx;              // particle pool (chips, leaves, death burst, weather)
    var chopShakeT;      // brief screen shake on each chop
    var maxCombo;        // best combo (0-based) this run — shown on game-over
    var milestoneText;   // milestone banner text ("50 CHOPS!")
    var milestoneT;      // milestone banner ticks remaining
    hidden var _lastMile;
    // One-shot events consumed by MainView (which owns the layout coords
    // needed to place bursts): side of a fresh chop / dodged branch / death.
    var evChopSide;      // 0 = none, else SIDE_LEFT/RIGHT
    var evNearMiss;      // 0 = none, else side of the branch just dodged
    var evDie;           // true on the frame a run ends

    // ── Shared meta-progression (shop-ready via Progress module) ──────────────
    // pgUnlockMsg  — one-shot "UNLOCKED: <axe>" banner for the game-over card.
    // dailyText/T  — lightweight daily-login toast, surfaced on the first frame.
    // axeTierCached— selected-AND-owned axe tier (0=Oak, 1=Iron, 2=Golden),
    //                clamped to ownership so a locked pick renders as Oak. Cached
    //                once per run so hot render paths never touch Storage.
    var pgUnlockMsg;
    var dailyText;
    var dailyT;
    var axeTierCached;
    hidden var _overSince;   // ms timestamp when GS_OVER was entered (restart debounce)

    function initialize() {
        state       = GS_MENU;
        player      = new PlayerSystem();
        tree        = new TreeGenerator();
        scoreSys    = new ScoreSystem();
        menuRow     = DR_ROW_START;
        menuDiff    = _loadDiff();
        energy      = ENERGY_MAX;
        scrollT     = 0;
        deathReason = "";
        _newBest    = false;
        frame       = 0;
        popPts      = 0;
        popT        = 0;
        popSide     = SIDE_RIGHT;
        _fxOn       = _loadFx();
        fx          = new DrParticles();
        chopShakeT  = 0;
        maxCombo    = 0;
        milestoneText = "";
        milestoneT  = 0;
        _lastMile   = 0;
        evChopSide  = 0;
        evNearMiss  = 0;
        evDie       = false;
        pgUnlockMsg = null;
        dailyText   = null;
        dailyT      = 0;
        axeTierCached = 0;
        _overSince    = 0;
        _computeAxeTier();
    }

    // Debounced restart from the game-over screen. Rapid button mashing right
    // after death (before the post-game leaderboard view arms) previously let
    // several inputs pile onto the restart/leaderboard path; ignore restart
    // requests for a short window so a run can't be re-entered mid-teardown.
    function requestRestart() {
        if (state != GS_OVER) { return; }
        try {
            if (System.getTimer() - _overSince < 550) { return; }
        } catch (e) { }
        startGame();
    }

    hidden function _loadFx() {
        try {
            var v = Application.Storage.getValue(DR_FX_KEY);
            if (v instanceof Number && v == 1) { return false; }
        } catch (e) { }
        return true;
    }

    hidden function _loadDiff() {
        try {
            var v = Application.Storage.getValue(DR_DIFF_KEY);
            if (v != null && v instanceof Number && v >= 0 && v <= 2) { return v; }
        } catch (e) { }
        return DR_DIFF_NORMAL;
    }
    hidden function _saveDiff() {
        try { Application.Storage.setValue(DR_DIFF_KEY, menuDiff); } catch (e) { }
    }

    function diffName() {
        if (menuDiff == DR_DIFF_EASY) { return "Easy";   }
        if (menuDiff == DR_DIFF_HARD) { return "Hard";   }
        return "Normal";
    }

    // ── Menu nav ────────────────────────────────────────────
    function menuPrev()    { menuRow = (menuRow + DR_MENU_ROWS - 1) % DR_MENU_ROWS; }
    function menuNext()    { menuRow = (menuRow + 1) % DR_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < DR_MENU_ROWS) { menuRow = i; } }
    // START launches a run; LEADERBOARD is handled by MainView (it can
    // push views, the controller can't).
    function menuActivate() {
        if (menuRow == DR_ROW_DIFF) {
            menuDiff = (menuDiff + 1) % 3;
            _saveDiff();
        } else if (menuRow == DR_ROW_START) {
            startGame();
        }
    }

    function gotoMenu() { state = GS_MENU; }

    // ── Lifecycle ───────────────────────────────────────────
    function startGame() {
        player.reset();
        tree.reset();
        scoreSys.reset();
        energy      = ENERGY_MAX;
        scrollT     = 0;
        deathReason = "";
        _newBest    = false;
        popPts      = 0;
        popT        = 0;
        _fxOn       = _loadFx();
        chopShakeT  = 0;
        maxCombo    = 0;
        milestoneText = "";
        milestoneT  = 0;
        _lastMile   = 0;
        evChopSide  = 0;
        evNearMiss  = 0;
        evDie       = false;
        pgUnlockMsg = null;      // cleared each run; set again only on a fresh unlock
        _computeAxeTier();       // refresh selected-and-owned axe once per run
        // NOTE: dailyText/dailyT intentionally NOT reset here — the login toast
        // is queued after this auto-start so it survives into the first frame.
        fx.clear();
        state       = GS_PLAY;
    }

    // ── Meta-progression: axe cosmetic tier (visual FX escalation only) ───────
    // Reads the "dr_axe" selection (0=OAK,1=IRON,2=GOLD) and clamps it to
    // ownership. A locked pick falls back to Oak. Never affects scoring/timing.
    function axeTier() { return axeTierCached; }

    hidden function _computeAxeTier() {
        var sel = 0;
        try {
            var v = Application.Storage.getValue("dr_axe");
            if (v instanceof Number) { sel = v; }
        } catch (e) { }
        var t = 0;
        if (sel >= 2 && Progress.owns("axe_gold"))      { t = 2; }
        else if (sel >= 1 && Progress.owns("axe_iron")) { t = 1; }
        axeTierCached = t;
    }

    // Queue the daily-login toast (called by the view right after the run
    // auto-starts, so it shows over the first game frame instead of a modal).
    function queueDaily(text) { dailyText = text; dailyT = 60; }

    // ── Difficulty curve — scales continuously with the live score ──
    hidden function _drainPerTick() {
        var base;
        if (menuDiff == DR_DIFF_EASY)      { base = 8;  }
        else if (menuDiff == DR_DIFF_HARD) { base = 16; }
        else                                { base = 11; }
        var d = base + scoreSys.score / 25;
        var cap = base * 3;
        if (d > cap) { d = cap; }
        return d;
    }
    hidden function _refillPerChop() {
        if (menuDiff == DR_DIFF_EASY) { return 190; }
        if (menuDiff == DR_DIFF_HARD) { return 140; }
        return 165;
    }
    hidden function _branchChancePct() {
        var base;
        if (menuDiff == DR_DIFF_EASY)      { base = 14; }
        else if (menuDiff == DR_DIFF_HARD) { base = 26; }
        else                                { base = 19; }
        var pct = base + scoreSys.score / 6;
        if (pct > 74) { pct = 74; }
        return pct;
    }

    // ── Core action — one instant, unblockable chop ─────────────────
    function chopSide(s) {
        if (state == GS_OVER) { requestRestart(); return; }
        if (state != GS_PLAY) { return; }

        player.setSide(s);
        player.swing();

        var cur = tree.current();
        if (CollisionSystem.hits(cur, s)) {
            _die("HIT");
            return;
        }

        // Near-miss: the row we just cleared carried a branch on the
        // opposite (safe) side — worth a leaf shower.
        if (cur == SEG_LEFT)       { evNearMiss = SIDE_LEFT; }
        else if (cur == SEG_RIGHT) { evNearMiss = SIDE_RIGHT; }

        tree.setBranchChance(_branchChancePct());
        tree.advance();
        var pts = scoreSys.registerChop(System.getTimer());
        energy = energy + _refillPerChop();
        if (energy > ENERGY_MAX) { energy = ENERGY_MAX; }
        scrollT = SCROLL_FRAMES;
        chopShakeT = 2;
        if (scoreSys.combo > maxCombo) { maxCombo = scoreSys.combo; }

        // Chop juice: floating "+N", a snappy tick tone and a small vibe
        // pulse each time the combo crosses a 5-step milestone.
        popPts  = pts;
        popT    = POP_FRAMES;
        popSide = s;
        evChopSide = s;
        _tone(0);
        if (scoreSys.combo > 0 && ((scoreSys.combo + 1) % 5 == 0)) {
            _tone(1);
            _vibe(35, 45);
            milestoneText = "COMBO x" + (scoreSys.combo + 1).format("%d");
            milestoneT = 18;
        }

        // Score milestone banner every 25 chops-worth of points.
        var mile = scoreSys.score / 25;
        if (mile > _lastMile) {
            _lastMile = mile;
            milestoneText = (mile * 25).format("%d") + "!";
            milestoneT = 20;
            _tone(1);
            _vibe(40, 60);
        }
    }

    function step() {
        player.step();
        fx.step();
        frame = frame + 1;
        if (scrollT > 0)    { scrollT = scrollT - 1; }
        if (popT > 0)       { popT = popT - 1; }
        if (chopShakeT > 0) { chopShakeT = chopShakeT - 1; }
        if (milestoneT > 0) { milestoneT = milestoneT - 1; }
        if (dailyT > 0)     { dailyT = dailyT - 1; }
        if (state != GS_PLAY) { return; }

        energy = energy - _drainPerTick();
        if (energy <= 0) {
            energy = 0;
            _die("TIMEOUT");
        }
    }

    hidden function _die(reason) {
        deathReason = reason;
        player.die();
        scoreSys.saveHi();
        _newBest = (scoreSys.score > 0 && scoreSys.score == scoreSys.hi);
        state = GS_OVER;
        popT = 0;
        evDie = true;
        try { _overSince = System.getTimer(); } catch (e) { _overSince = 0; }
        _tone(2);
        _vibe(100, 200);
        try { Leaderboard.submitScore(LB_GAME_ID, scoreSys.score, diffName()); } catch (e) { }
        try { Leaderboard.showPostGame(LB_GAME_ID, diffName(), "DRWAL"); } catch (e) { }
        try { _awardProgress(); } catch (e) { }
    }

    // Grant coins + XP for a completed run (proportional to logs chopped) and
    // unlock the two cosmetic axe tiers at rank milestones. Coins are the future
    // shop's currency; axe ownership is the exact set a shop purchase grants, so
    // nothing here blocks monetising axes later. Fully guarded by the Progress
    // module (every call is internally try/catch'd).
    hidden function _awardProgress() {
        var sc = scoreSys.score;
        if (sc <= 0) { return; }
        // ~20-40 for a good run: a solid ~40-chop run lands near the cap.
        var xpGain   = 8 + sc / 2; if (xpGain   > 40) { xpGain   = 40; }
        var coinGain = 6 + sc / 2; if (coinGain > 40) { coinGain = 40; }
        Progress.addCoins(coinGain);
        Progress.addXp(xpGain);
        var lvl = Progress.level();
        // EXACTLY 2 unlockable axes beyond the default Oak (shop planned later).
        var uGold = Progress.unlockIfReached("axe_gold", lvl, 6);
        var uIron = Progress.unlockIfReached("axe_iron", lvl, 3);
        if (uGold)      { pgUnlockMsg = "UNLOCKED: Golden Axe"; }
        else if (uIron) { pgUnlockMsg = "UNLOCKED: Iron Axe"; }
    }

    function hasNewBest() { return _newBest; }

    // Day→dusk→night phase (0..3) derived from the live score, so the world
    // visibly darkens the further you get — a free sense of progression.
    function dayPhase() {
        var s = scoreSys.score;
        if (s < 15) { return 0; }   // bright day
        if (s < 45) { return 1; }   // golden sunset
        if (s < 90) { return 2; }   // purple dusk
        return 3;                    // starry night
    }

    // ── Best-effort feedback (silent/absent hardware is fine) ──────────────
    // kind: 0 chop · 1 combo milestone · 2 death.
    hidden function _tone(kind) {
        if (!_fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :playTone)) { return; }
        var t;
        if      (kind == 0) { t = Attention.TONE_KEY; }
        else if (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
        else                { t = Attention.TONE_ALERT_LO; }
        try { Attention.playTone(t); } catch (e) {}
    }
    hidden function _vibe(intensity, duration) {
        if (!_fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :vibrate)) { return; }
        try { Attention.vibrate([new Attention.VibeProfile(intensity, duration)]); } catch (e) {}
    }
}
