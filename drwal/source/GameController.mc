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
        state       = GS_PLAY;
    }

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
        if (state == GS_OVER) { startGame(); return; }
        if (state != GS_PLAY) { return; }

        player.setSide(s);
        player.swing();

        if (CollisionSystem.hits(tree.current(), s)) {
            _die("HIT");
            return;
        }

        tree.setBranchChance(_branchChancePct());
        tree.advance();
        scoreSys.registerChop(System.getTimer());
        energy = energy + _refillPerChop();
        if (energy > ENERGY_MAX) { energy = ENERGY_MAX; }
        scrollT = SCROLL_FRAMES;
    }

    function step() {
        player.step();
        if (scrollT > 0) { scrollT = scrollT - 1; }
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
        Leaderboard.submitScore(LB_GAME_ID, scoreSys.score, diffName());
        Leaderboard.showPostGame(LB_GAME_ID, diffName(), "DRWAL");
    }

    function hasNewBest() { return _newBest; }
}
