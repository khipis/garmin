// ═══════════════════════════════════════════════════════════════
// ReelSystem.mc — Reel strips, vertical scroll position, low-level
// spin/decelerate/stop mechanics. Purely mechanical: it knows how a
// reel moves and how to bring it to rest at a chosen strip offset,
// but has NO opinion about which offset is "good" — that decision
// (the skill-stop pull-in) lives in SpinLogic.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const REEL_IDLE     = 0;
const REEL_SPINNING = 1;
const REEL_DECEL    = 2;
const REEL_STOPPED  = 3;

// One reel: a shuffled symbol strip plus continuous scroll position.
// `position` is a float; the symbol currently on the payline is
// strip[floor(position) mod N].
class Reel {
    var strip;
    var position;     // float, ever-increasing while spinning
    var state;
    hidden var _decelFrom;
    hidden var _decelTo;
    hidden var _decelT;

    function initialize() {
        strip    = SymbolManager.buildStrip();
        position = 0.0;
        state    = REEL_IDLE;
        _decelFrom = 0.0; _decelTo = 0.0; _decelT = 0;
    }

    function reset() {
        strip    = SymbolManager.buildStrip();
        position = (Math.rand() % SymbolManager.STRIP_LEN).toFloat();
        state    = REEL_IDLE;
    }

    function spin() { state = REEL_SPINNING; }

    // Symbol at the payline (row 0) or an adjacent visible row
    // (-1 = above payline, +1 = below payline).
    function symbolAt(rowOffset) {
        var n = SymbolManager.STRIP_LEN;
        var idx = (position.toNumber() + rowOffset) % n;
        if (idx < 0) { idx = idx + n; }
        return strip[idx];
    }

    // Fractional scroll offset (0.0-1.0) for smooth sub-symbol drawing.
    function scrollFrac() { return position - position.toNumber(); }

    function paylineSymbol() { return symbolAt(0); }

    // Begin a decelerating stop that lands `forwardSteps` symbols ahead
    // of whatever is on the payline right now (0 = stop almost
    // immediately on the current symbol).
    function beginStop(forwardSteps, decelTicks) {
        if (state != REEL_SPINNING) { return; }
        var base = position.toNumber();
        _decelFrom = position;
        _decelTo   = (base + forwardSteps).toFloat();
        _decelT    = decelTicks;
        state      = REEL_DECEL;
    }

    function step(spinSpeed) {
        if (state == REEL_SPINNING) {
            position = position + spinSpeed;
            if (position > 100000) { position = position - 100000; }
            return;
        }
        if (state == REEL_DECEL) {
            var total = SLOT_DECEL_TICKS;
            var t = (total - _decelT).toFloat() / total;
            var eased = 1.0 - (1.0 - t) * (1.0 - t);   // ease-out quad
            position = _decelFrom + (_decelTo - _decelFrom) * eased;
            _decelT = _decelT - 1;
            if (_decelT <= 0) {
                position = _decelTo;
                state = REEL_STOPPED;
            }
        }
    }
}

// Holds the 3 reels and drives them as a group.
class ReelSystem {
    var reels;

    function initialize() {
        reels = [new Reel(), new Reel(), new Reel()];
    }

    function reset() {
        for (var i = 0; i < 3; i++) { reels[i].reset(); }
    }

    function spinAll() {
        for (var i = 0; i < 3; i++) { reels[i].spin(); }
    }

    function step() {
        for (var i = 0; i < 3; i++) { reels[i].step(SLOT_SPIN_SPEED); }
    }

    function allStopped() {
        for (var i = 0; i < 3; i++) {
            if (reels[i].state != REEL_STOPPED) { return false; }
        }
        return true;
    }

    // Index of the leftmost reel still spinning (for the single-button
    // "stop next reel" fallback), or -1 if none are spinning.
    function nextSpinningIndex() {
        for (var i = 0; i < 3; i++) {
            if (reels[i].state == REEL_SPINNING) { return i; }
        }
        return -1;
    }

    function paylineSymbols() {
        return [reels[0].paylineSymbol(), reels[1].paylineSymbol(), reels[2].paylineSymbol()];
    }
}
