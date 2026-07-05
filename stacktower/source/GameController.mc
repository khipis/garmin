// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine, scoring, difficulty curve.
// ═══════════════════════════════════════════════════════════════

using Toybox.System;
using Toybox.Application;
using Toybox.Math;

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

const ST_DIFF_SLOW = 0;
const ST_DIFF_NORM = 1;
const ST_DIFF_FAST = 2;

// View modes
const ST_VIEW_2D = 0;
const ST_VIEW_3D = 1;

// Block colour palette — rotates as tower grows.
const PALETTE = [
    0xFF2244, 0xFF8822, 0xFFCC00, 0x22FF88, 0x00CCFF,
    0x4488FF, 0xAA44FF, 0xFF44BB
];

const ST_DIFF_KEY = "st_diff";
const ST_VIEW_KEY = "st_view";

class GameController {
    var state;
    var tower;

    var score;
    var hi;
    var perfectStreak;
    var lastPerfect;
    var lastShake;

    var menuRow;
    var menuDiff;
    var menuView;          // ST_VIEW_2D or ST_VIEW_3D

    var worldMinX;
    var worldMaxX;
    var foundationW;

    function initialize() {
        state           = GS_MENU;
        tower           = new TowerManager();
        score           = 0;
        hi              = _loadHi();
        perfectStreak   = 0;
        lastPerfect     = 0;
        lastShake       = 0;
        menuRow         = ST_ROW_START;
        menuDiff        = _loadDiff();
        menuView        = _loadView();
        worldMinX       = 0;
        worldMaxX       = 200;
        foundationW     = 56;
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
            if (v != null && v instanceof Number && v >= 0 && v <= 2) { return v; }
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

    // ── Menu nav ────────────────────────────────────────────
    function menuPrev()    { menuRow = (menuRow + ST_MENU_ROWS - 1) % ST_MENU_ROWS; }
    function menuNext()    { menuRow = (menuRow + 1) % ST_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < ST_MENU_ROWS) { menuRow = i; } }

    function menuActivate() {
        if (menuRow == ST_ROW_DIFF) {
            menuDiff = (menuDiff + 1) % 3;
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
        if (menuDiff == ST_DIFF_SLOW) { return "Slow"; }
        if (menuDiff == ST_DIFF_FAST) { return "Fast"; }
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
        tower.placeFoundation(foundationW, PALETTE[0]);
        score         = 0;
        perfectStreak = 0;
        lastPerfect   = 0;
        lastShake     = 0;
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
            base = 2.2; coef = 0.150; cap = 7.8;
        } else {
            base = 1.7; coef = 0.120; cap = 6.5;
        }
        var s = base + h * coef;
        if (s > cap) { s = cap; }
        return s;
    }

    hidden function _spawnNextMoving() {
        var h   = tower.height();
        var col = PALETTE[(h + 1) % PALETTE.size()];
        tower.spawnMoving(col, _computeSpeed());
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
    }

    function dropAction() {
        if (state == GS_MENU) { startGame(); return; }
        if (state == GS_OVER) { gotoMenu();  return; }
        if (state != GS_PLAY) { return; }

        var res = tower.drop();
        if (res == null) { return; }

        if (res.status == 2) {
            lastShake = 8;
            if (score > hi) { hi = score; _saveHi(); }
            state = GS_OVER;
            Leaderboard.submitScore(LB_GAME_ID, score, diffName());
            Leaderboard.showPostGame(LB_GAME_ID, diffName(), "STACK TOWER");
            return;
        }

        var h = tower.height();
        score = score + 10 + h;
        if (res.status == 0) {
            score = score + 50;
            perfectStreak = perfectStreak + 1;
            lastPerfect   = 8;
            if (perfectStreak >= 5) {
                var top = tower.topBlock();
                if (top != null) {
                    var maxLeft = worldMaxX - (top.widthWX + 2);
                    if (top.leftWX > worldMinX && top.leftWX <= maxLeft) {
                        top.leftWX  = top.leftWX - 1;
                        top.widthWX = top.widthWX + 2;
                    }
                }
                perfectStreak = 0;
            }
        } else {
            perfectStreak = 0;
        }
        _spawnNextMoving();
    }
}
