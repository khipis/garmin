// ═══════════════════════════════════════════════════════════════
// DiceManager.mc — Five dice + hold state for DiceRoyale.
//
//   • dice[i]   ∈ 1..6   current face of die i
//   • held[i]   ∈ bool   true → die is locked, won't change on reroll
//   • rerollsLeft        remaining rerolls in this round (decrements
//                        on each `reroll()`)
//   • initialRolls       how many rerolls the player starts with;
//                        set by the controller from the menu choice
//
// The manager doesn't know anything about rounds or scoring; it
// simply provides primitives that the GameController orchestrates.
//
// Daily-mode RNG: when the controller calls `setSeed(s)`, all
// subsequent rolls come from a tiny LCG instead of `Math.rand()`.
// That makes the daily challenge deterministic so two players on
// the same day get the same sequence of rolls.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const DR_DICE_COUNT = 5;

class DiceManager {
    var dice;
    var held;
    var rerollsLeft;
    var initialRolls;

    hidden var _seed;
    hidden var _useSeed;

    function initialize() {
        dice         = [1, 1, 1, 1, 1];
        held         = [false, false, false, false, false];
        rerollsLeft  = 2;
        initialRolls = 2;
        _seed        = 1;
        _useSeed     = false;
    }

    function setSeed(s) {
        if (s < 1) { s = 1; }
        _seed    = s;
        _useSeed = true;
    }
    function clearSeed() { _useSeed = false; }

    hidden function _rnd6() {
        if (_useSeed) {
            // Simple LCG (Numerical Recipes constants).  Stays in
            // the positive 31-bit range so cross-firmware portable.
            _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
            return (_seed % 6) + 1;
        }
        var v = Math.rand();
        if (v < 0) { v = -v; }
        return (v % 6) + 1;
    }

    // Roll ALL dice and clear holds — used at the start of a round.
    function rollInitial() {
        for (var i = 0; i < DR_DICE_COUNT; i++) {
            dice[i] = _rnd6();
            held[i] = false;
        }
        rerollsLeft = initialRolls;
    }

    // Re-roll the dice that aren't currently held; costs 1 reroll.
    // Returns true if the reroll happened, false if no rerolls left.
    function reroll() {
        if (rerollsLeft <= 0) { return false; }
        for (var i = 0; i < DR_DICE_COUNT; i++) {
            if (!held[i]) { dice[i] = _rnd6(); }
        }
        rerollsLeft = rerollsLeft - 1;
        return true;
    }

    function toggleHold(i) {
        if (i >= 0 && i < DR_DICE_COUNT) { held[i] = !held[i]; }
    }

    function clearHolds() {
        for (var i = 0; i < DR_DICE_COUNT; i++) { held[i] = false; }
    }
}
