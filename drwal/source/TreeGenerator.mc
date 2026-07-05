// ═══════════════════════════════════════════════════════════════
// TreeGenerator.mc — Scrolling window of tree segments.
//
// Segments live in one fixed-size Int array that is reused for the
// whole run (no per-frame / per-chop allocation). seg[0] is always
// the segment level with the player — the one about to be chopped.
// advance() shifts every segment down one slot and rolls a fresh
// one onto the top.
//
// Fairness: a segment can carry a branch on AT MOST one side, so
// the opposite side is always a guaranteed-safe escape. Combined
// with the branch-chance cap in setBranchChance(), the tree can
// never generate an unavoidable death pattern, however fast it
// scrolls.
// ═══════════════════════════════════════════════════════════════
using Toybox.Math;

class TreeGenerator {
    var seg;               // Int[TG_VISIBLE], seg[0] = current/player level
    hidden var _branchPct;  // 0..100 chance a freshly-rolled segment has a branch

    function initialize() {
        seg = new [TG_VISIBLE];
        reset();
    }

    function reset() {
        _branchPct = 14;
        for (var i = 0; i < TG_VISIBLE; i++) {
            // The first two rows are always clear so a fresh run never
            // opens with an instant, unavoidable branch at the player's
            // face before they've even seen the tree.
            seg[i] = (i < 2) ? SEG_NONE : _roll();
        }
    }

    function current() { return seg[0]; }

    function advance() {
        for (var i = 0; i < TG_VISIBLE - 1; i++) { seg[i] = seg[i + 1]; }
        seg[TG_VISIBLE - 1] = _roll();
    }

    // Called before every advance() with the run's live difficulty so
    // the freshly-rolled segment reflects current pressure.
    function setBranchChance(pct) {
        if (pct > 76) { pct = 76; }   // always leave a comfortable safe margin
        if (pct < 0)  { pct = 0;  }
        _branchPct = pct;
    }

    hidden function _roll() {
        if ((Math.rand() % 100) >= _branchPct) { return SEG_NONE; }
        return ((Math.rand() % 2) == 0) ? SEG_LEFT : SEG_RIGHT;
    }
}
