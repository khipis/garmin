// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine, scoring, difficulty curve.
// ═══════════════════════════════════════════════════════════════

using Toybox.System;
using Toybox.Application;
using Toybox.Math;
using Toybox.Attention;
using Toybox.Lang;

const GS_MENU = 0;
const GS_PLAY = 1;
const GS_OVER = 2;

// Menu rows:  Diff | View | START | LEADERBOARD
const ST_MENU_ROWS = 4;
const ST_ROW_DIFF  = 0;
const ST_ROW_VIEW  = 1;
const ST_ROW_START = 2;
const ST_ROW_LB    = 3;

const LB_GAME_ID = "stacktower";

const ST_DIFF_SLOW     = 0;
const ST_DIFF_NORM     = 1;
const ST_DIFF_FAST     = 2;   // now runs at the old SUPER's pace — hyper-dynamic
const ST_DIFF_NIGHTMARE = 3;  // NIGHTMARE — 5x FAST's speed, the ultimate test

const ST_DIFF_COUNT = 4;

// View modes
const ST_VIEW_2D = 0;
const ST_VIEW_3D = 1;

// Block colour palette — rotates as tower grows. CLASSIC (default) plus two
// shop-ready alternate themes selected via the shared Progress layer.
const PALETTE = [
    0xFF2244, 0xFF8822, 0xFFCC00, 0x22FF88, 0x00CCFF,
    0x4488FF, 0xAA44FF, 0xFF44BB
];
// NEON theme — saturated cyans/magentas/limes matching the retrowave vibe.
const PALETTE_NEON = [
    0x00FFD5, 0xFF2EA6, 0x9D4BFF, 0x2EE6FF, 0x39FF14,
    0xFF6EC7, 0x00B3FF, 0xC6FF00
];
// GOLD theme — warm amber/bronze gradient for a premium look.
const PALETTE_GOLD = [
    0xFFD21A, 0xFFB300, 0xFF9500, 0xE8A23D, 0xFFC760,
    0xCf9B24, 0xFFE38A, 0xB4790F
];

// Gold bonus block colour + cadence.
const ST_GOLD_COLOR = 0xFFD21A;
const ST_GOLD_EVERY = 6;      // every 6th new block is gold
const ST_GOLD_BONUS = 40;     // extra points for landing a gold block

const ST_DIFF_KEY = "st_diff";
const ST_VIEW_KEY = "st_view";
const ST_FX_KEY   = "st_fx";   // 0 = sound + haptics ON, 1 = OFF

// Selectable block-colour theme (OPTIONS: st_skin). Index 0 = CLASSIC (always
// owned), 1 = NEON, 2 = GOLD. Higher tiers are gated on the shared Progress
// ownership set (shop-ready), unlocked by tower height OR account level.
const ST_SKIN_KEY   = "st_skin";
const ST_SKIN_NEON  = "st_neon";
const ST_SKIN_GOLD  = "st_gold";
// Unlock thresholds — reached via tower height (floors) OR account level.
const ST_NEON_LEVEL = 3;
const ST_NEON_H     = 15;
const ST_GOLD_LEVEL = 6;
const ST_GOLD_H     = 30;

class GameController {
    var state;
    var tower;

    var score;
    var hi;
    var perfectStreak;
    var lastPerfect;
    var lastShake;

    var combo;             // consecutive perfect count (drives escalating bonus)
    var bestCombo;         // best combo this run
    var lastBonus;         // points awarded on the most recent perfect
    var goldFlash;         // countdown frames for the gold-pickup flash
    var placeFlash;        // countdown frames for the block-landing pop
    var milestoneT;        // countdown frames for the height milestone banner
    var milestoneN;        // which height milestone to show
    var lastMilestone;     // last height milestone already celebrated
    var fxOn;              // sound + haptics master switch (OPTIONS: st_fx)

    var menuRow;
    var menuDiff;
    var menuView;          // ST_VIEW_2D or ST_VIEW_3D

    var worldMinX;
    var worldMaxX;
    var foundationW;

    // Shared meta-progression (coins/XP/rank/skins): one-shot game-over unlock
    // banner + the daily login toast queued by the App's checkIn.
    var pgUnlockMsg;      // "UNLOCKED: NEON" etc., or null
    var dailyMsg;         // daily-bonus toast text, or null
    var dailyT;           // frames remaining for the daily toast

    function initialize() {
        state           = GS_MENU;
        tower           = new TowerManager();
        score           = 0;
        hi              = _loadHi();
        perfectStreak   = 0;
        lastPerfect     = 0;
        lastShake       = 0;
        combo           = 0;
        bestCombo       = 0;
        lastBonus       = 0;
        goldFlash       = 0;
        placeFlash      = 0;
        milestoneT      = 0;
        milestoneN      = 0;
        lastMilestone   = 0;
        fxOn            = _loadFx();
        menuRow         = ST_ROW_START;
        menuDiff        = _loadDiff();
        menuView        = _loadView();
        worldMinX       = 0;
        worldMaxX       = 200;
        foundationW     = 56;
        pgUnlockMsg     = null;
        dailyMsg        = null;
        dailyT          = 0;
        // Pop the daily-bonus toast queued by the App on the day's first
        // launch (shown once over the first frames of the first run).
        try {
            var dm = Application.Storage.getValue("st_daily_msg");
            if (dm != null) {
                dailyMsg = dm; dailyT = 70;
                Application.Storage.deleteValue("st_daily_msg");
            }
        } catch (e) {}
    }

    // ── Shared meta-progression (shop-ready via the Progress module) ─────────
    // Selected-and-owned block theme: 0 = CLASSIC, 1 = NEON, 2 = GOLD. A locked
    // pick falls back to CLASSIC so selection is always safe.
    function selectedSkin() {
        var sel = 0;
        try {
            var v = Application.Storage.getValue(ST_SKIN_KEY);
            if (v instanceof Lang.Number) { sel = v; }
        } catch (e) {}
        if (sel == 2 && Progress.owns(ST_SKIN_GOLD)) { return 2; }
        if (sel == 1 && Progress.owns(ST_SKIN_NEON)) { return 1; }
        return 0;
    }

    // Active block palette for the selected+owned theme.
    hidden function _palette() {
        var s = selectedSkin();
        if (s == 2) { return PALETTE_GOLD; }
        if (s == 1) { return PALETTE_NEON; }
        return PALETTE;
    }

    // Rank title for the game-over progression line.
    function rankName() { return Progress.rankName(); }

    // Grant coins + XP proportional to the height reached, and unlock the
    // cosmetic themes the first time their milestone (height OR level) is met.
    // Idempotent unlock calls make the "UNLOCKED" banner fire exactly once.
    hidden function _awardProgress() {
        var h = tower.height();
        var coinsGain = 5 + h;
        var xpGain    = 10 + h * 2;
        Progress.addCoins(coinsGain);
        Progress.addXp(xpGain);
        var lvl = Progress.level();
        var uNeon = Progress.unlockIfReached(ST_SKIN_NEON, lvl, ST_NEON_LEVEL)
                 || Progress.unlockIfReached(ST_SKIN_NEON, h,   ST_NEON_H);
        var uGold = Progress.unlockIfReached(ST_SKIN_GOLD, lvl, ST_GOLD_LEVEL)
                 || Progress.unlockIfReached(ST_SKIN_GOLD, h,   ST_GOLD_H);
        if (uGold)      { pgUnlockMsg = "UNLOCKED: GOLD"; }
        else if (uNeon) { pgUnlockMsg = "UNLOCKED: NEON"; }
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
    hidden function _loadDiff() {
        try {
            var v = Application.Storage.getValue(ST_DIFF_KEY);
            if (v != null && v instanceof Number && v >= 0 && v <= ST_DIFF_NIGHTMARE) { return v; }
        } catch (e) {}
        return ST_DIFF_NORM;
    }
    hidden function _saveDiff() {
        try { Application.Storage.setValue(ST_DIFF_KEY, menuDiff); } catch (e) {}
    }
    hidden function _loadView() {
        try {
            var v = Application.Storage.getValue(ST_VIEW_KEY);
            if (v != null && v instanceof Number && (v == ST_VIEW_2D || v == ST_VIEW_3D)) { return v; }
        } catch (e) {}
        return ST_VIEW_2D;
    }
    hidden function _saveView() {
        try { Application.Storage.setValue(ST_VIEW_KEY, menuView); } catch (e) {}
    }
    hidden function _loadFx() {
        try {
            var v = Application.Storage.getValue(ST_FX_KEY);
            if (v instanceof Number && v == 1) { return false; }
        } catch (e) {}
        return true;
    }

    // ── Menu nav ────────────────────────────────────────────
    function menuPrev()    { menuRow = (menuRow + ST_MENU_ROWS - 1) % ST_MENU_ROWS; }
    function menuNext()    { menuRow = (menuRow + 1) % ST_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < ST_MENU_ROWS) { menuRow = i; } }

    function menuActivate() {
        if (menuRow == ST_ROW_DIFF) {
            menuDiff = (menuDiff + 1) % ST_DIFF_COUNT;
            _saveDiff();
        } else if (menuRow == ST_ROW_VIEW) {
            menuView = (menuView == ST_VIEW_2D) ? ST_VIEW_3D : ST_VIEW_2D;
            _saveView();
        } else if (menuRow == ST_ROW_START) {
            startGame();
        }
        // ST_ROW_LB handled by MainView.openLeaderboard().
    }

    function diffName() {
        if (menuDiff == ST_DIFF_SLOW)      { return "Slow"; }
        if (menuDiff == ST_DIFF_FAST)      { return "Fast"; }
        if (menuDiff == ST_DIFF_NIGHTMARE) { return "Nightmare"; }
        return "Norm";
    }
    function viewName() {
        return (menuView == ST_VIEW_3D) ? "3D" : "2D";
    }

    function setWorldBounds(minX, maxX) {
        worldMinX = minX;
        worldMaxX = maxX;
        var w = ((maxX - minX) * 40) / 100;
        if (w < 26) { w = 26; }
        if (w > 80) { w = 80; }
        foundationW = w;
        tower.setBounds(minX, maxX);
    }

    function startGame() {
        tower.reset();
        tower.setBounds(worldMinX, worldMaxX);
        tower.placeFoundation(foundationW, _palette()[0]);
        pgUnlockMsg   = null;
        score         = 0;
        perfectStreak = 0;
        lastPerfect   = 0;
        lastShake     = 0;
        combo         = 0;
        bestCombo     = 0;
        lastBonus     = 0;
        goldFlash     = 0;
        placeFlash    = 0;
        milestoneT    = 0;
        milestoneN    = 0;
        lastMilestone = 0;
        fxOn          = _loadFx();
        state         = GS_PLAY;
        _spawnNextMoving();
    }

    function gotoMenu() { state = GS_MENU; }

    hidden function _computeSpeed() {
        var h = tower.height();
        var base; var coef; var cap;
        if (menuDiff == ST_DIFF_SLOW) {
            base = 1.2; coef = 0.085; cap = 4.8;
        } else if (menuDiff == ST_DIFF_FAST) {
            base = 5.4; coef = 0.380; cap = 17.0;   // formerly SUPER — blistering, ramps hard
        } else if (menuDiff == ST_DIFF_NIGHTMARE) {
            base = 27.0; coef = 1.900; cap = 85.0;  // NIGHTMARE — 5x FAST, the ultimate test
        } else {
            base = 1.7; coef = 0.120; cap = 6.5;
        }
        var s = base + h * coef;
        if (s > cap) { s = cap; }
        return s;
    }

    hidden function _spawnNextMoving() {
        var h    = tower.height();
        var next = h + 1;
        // Every ST_GOLD_EVERY-th block is a gold bonus block.
        var gold = (next % ST_GOLD_EVERY == 0);
        var pal  = _palette();
        var col  = gold ? ST_GOLD_COLOR : pal[next % pal.size()];
        tower.spawnMoving(col, _computeSpeed(), gold ? 1 : 0);
    }

    function step() {
        if (state != GS_PLAY) {
            if (lastShake > 0) { lastShake = lastShake - 1; }
            if (state == GS_OVER) { tower.step(); }
            return;
        }
        tower.step();
        if (lastPerfect > 0) { lastPerfect = lastPerfect - 1; }
        if (lastShake   > 0) { lastShake   = lastShake   - 1; }
        if (goldFlash   > 0) { goldFlash   = goldFlash   - 1; }
        if (placeFlash  > 0) { placeFlash  = placeFlash  - 1; }
        if (milestoneT  > 0) { milestoneT  = milestoneT  - 1; }
        if (dailyT      > 0) { dailyT      = dailyT      - 1; }
    }

    function dropAction() {
        if (state == GS_MENU) { startGame(); return; }
        if (state == GS_OVER) { startGame(); return; }   // restart in place
        if (state != GS_PLAY) { return; }

        var res = tower.drop();
        if (res == null) { return; }

        if (res.status == 2) {
            lastShake = 8;
            combo     = 0;
            if (score > hi) { hi = score; _saveHi(); }
            // Shared meta-progression: award coins + XP and unlock themes.
            _awardProgress();
            state = GS_OVER;
            _tone(2);
            _vibe(90, 350);
            Leaderboard.submitScore(LB_GAME_ID, score, diffName());
            Leaderboard.showPostGame(LB_GAME_ID, diffName(), "STACK TOWER");
            return;
        }

        var h = tower.height();
        score = score + 10 + h;
        placeFlash = 5;

        // Gold bonus block landed successfully.
        if (res.special == 1) {
            score     = score + ST_GOLD_BONUS;
            goldFlash = 14;
            _tone(3);
            _vibe(70, 130);
        }

        if (res.status == 0) {
            // Perfect — escalating combo bonus.
            perfectStreak = perfectStreak + 1;
            combo         = combo + 1;
            if (combo > bestCombo) { bestCombo = combo; }
            var bonus = 50 + (combo - 1) * 15;
            if (bonus > 200) { bonus = 200; }
            score      = score + bonus;
            lastBonus  = bonus;
            lastPerfect = 10;
            _tone(1);
            _vibe(55, 60);
            // Every 5 perfects widens the tower slightly — a comeback aid.
            if (perfectStreak % 5 == 0) {
                var top = tower.topBlock();
                if (top != null) {
                    var maxLeft = worldMaxX - (top.widthWX + 2);
                    if (top.leftWX > worldMinX && top.leftWX <= maxLeft) {
                        top.leftWX  = top.leftWX - 1;
                        top.widthWX = top.widthWX + 2;
                    }
                }
            }
        } else {
            perfectStreak = 0;
            combo         = 0;
            if (res.special != 1) { _tone(0); }
        }

        // Height milestone celebration every 10 floors.
        if (h > 0 && (h % 10) == 0 && h != lastMilestone) {
            lastMilestone = h;
            milestoneN    = h;
            milestoneT    = 26;
            _tone(3);
            _vibe(80, 180);
        }

        _spawnNextMoving();
    }

    // ── Best-effort feedback (silent/absent hardware is fine) ──────────────
    // kind: 0 place · 1 perfect · 2 miss · 3 gold / milestone.
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
