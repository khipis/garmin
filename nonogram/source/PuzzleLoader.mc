// ═══════════════════════════════════════════════════════════════
// PuzzleLoader.mc — Picks a puzzle record from NGPuzzles.
//
// Difficulty:
//   0 = Easy (5×5 set)
//   1 = Hard (6×6 set)
//
// Mode:
//   Levels — by slot index (mod bucket-size)
//   Daily  — slot = day-of-year mod bucket-size, deterministic
//
// The bucket sizes (18 easy, 12 hard) are read at runtime from
// NGPuzzles.EASY/HARD so adding more puzzles to NGPuzzles.mc is
// automatically picked up.
// ═══════════════════════════════════════════════════════════════

class PuzzleLoader {

    static function bucketSize(diff) {
        if (diff == 0) { return NGPuzzles.EASY.size(); }
        return NGPuzzles.HARD.size();
    }

    static function selectLevel(diff, slot) {
        var sz = bucketSize(diff);
        if (sz <= 0) { sz = 1; }
        var i = slot % sz;
        if (i < 0) { i = i + sz; }
        if (diff == 0) { return NGPuzzles.EASY[i]; }
        return NGPuzzles.HARD[i];
    }

    static function selectDaily(diff, dayOfYear) {
        var sz = bucketSize(diff);
        if (sz <= 0) { sz = 1; }
        return selectLevel(diff, dayOfYear % sz);
    }
}
