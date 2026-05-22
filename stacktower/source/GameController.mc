// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine, scoring, difficulty curve.
//
// States:
//   GS_MENU    main menu
//   GS_PLAY    block sliding, awaiting drop
//   GS_OVER    miss → tower frozen, score saved
//
// Scoring:
//   - Every successful drop awards (10 + height) base points.
//   - "Perfect" drops (no overhang) award a bonus of 50 and grow a
//     perfect-streak counter. After 5 perfects in a row the block
//     widens slightly (rewarding precision).
//   - Best score persists via Application.Storage.
//
// Difficulty:
//   Block move speed scales with height following a gentle log curve
//   so the early game stays approachable but tops out fast enough to
//   challenge experienced players. Speed is also capped to keep
//   collision detection deterministic.
// ═══════════════════════════════════════════════════════════════

using Toybox.System;
using Toybox.Application;
using Toybox.Math;

const GS_MENU = 0;
const GS_PLAY = 1;
const GS_OVER = 2;

// Block colour palette — colour rotates through the list as the
// tower grows to give a rainbow effect.
const PALETTE = [
    0xFF3344, 0xFF8822, 0xFFCC22, 0x44FF55, 0x22CCCC,
    0x3388FF, 0x8866FF, 0xFF44AA
];

class GameController {
    var state;
    var tower;

    var score;
    var hi;
    var perfectStreak;
    var lastPerfect;       // ticks remaining for "PERFECT!" flash
    var lastShake;         // ticks remaining for game-over screen shake

    // Visual world: defined in world-x pixels matching the screen pixels
    // 1:1 so we don't need a scaler. Bounds are set by the view.
    var worldMinX;
    var worldMaxX;

    // Starting width (in world-x). 56 is a good fit on 240 px screens
    // and scales down on smaller round watches via setBounds().
    var foundationW;

    function initialize() {
        state           = GS_MENU;
        tower           = new TowerManager();
        score           = 0;
        hi              = _loadHi();
        perfectStreak   = 0;
        lastPerfect     = 0;
        lastShake       = 0;
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

    // Called by the view once it knows screen size.
    function setWorldBounds(minX, maxX) {
        worldMinX = minX;
        worldMaxX = maxX;
        // Choose a sensible foundation width: ~40% of the playable
        // strip, clamped so very small watches still get a usable
        // tower.
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

    function gotoMenu() {
        state = GS_MENU;
    }

    // Compute speed for the upcoming block given current height.
    // ~2.0 at start → ~7.0 once you've stacked ~40 blocks.
    hidden function _computeSpeed() {
        var h = tower.height();
        // Linear early, soft logarithmic-ish curve later.
        var s = 2.0 + h * 0.15;
        if (s > 7.5) { s = 7.5; }
        return s;
    }

    hidden function _spawnNextMoving() {
        var h = tower.height();
        var col = PALETTE[(h + 1) % PALETTE.size()];
        tower.spawnMoving(col, _computeSpeed());
    }

    // Called every tick from the view.
    function step() {
        if (state != GS_PLAY) {
            if (lastShake > 0) { lastShake = lastShake - 1; }
            // Even when not playing, advance any in-flight falling
            // pieces so the death animation completes.
            if (state == GS_OVER) { tower.step(); }
            return;
        }
        tower.step();
        if (lastPerfect > 0) { lastPerfect = lastPerfect - 1; }
        if (lastShake   > 0) { lastShake   = lastShake   - 1; }
    }

    // Player taps / SELECT → drop.
    function dropAction() {
        if (state == GS_MENU) { startGame(); return; }
        if (state == GS_OVER) { gotoMenu();  return; }
        if (state != GS_PLAY) { return; }

        var res = tower.drop();
        if (res == null) { return; }

        if (res.status == 2) {
            // Miss → game over.
            lastShake = 8;
            if (score > hi) { hi = score; _saveHi(); }
            state = GS_OVER;
            return;
        }

        // Award score (height-scaled + perfect bonus).
        var h = tower.height();
        score = score + 10 + h;
        if (res.status == 0) {
            score = score + 50;
            perfectStreak = perfectStreak + 1;
            lastPerfect   = 8;
            // Reward 5 perfects in a row: widen the next block by 2 px.
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
