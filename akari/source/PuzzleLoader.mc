// ═══════════════════════════════════════════════════════════════
// PuzzleLoader.mc — Selects a puzzle record from AKPuzzles.
//
// Difficulty:
//   0 = EASY  (6×6 set)
//   1 = HARD  (7×7 set)
//
// Slots wrap mod bucket size, so menu progression is endless.
// Daily mode seeds the slot from the day-of-year.
// ═══════════════════════════════════════════════════════════════

class PuzzleLoader {

    static function bucketSize(diff) {
        if (diff == 0) { return AKPuzzles.EASY.size(); }
        return AKPuzzles.HARD.size();
    }

    static function selectLevel(diff, slot) {
        var sz = bucketSize(diff);
        if (sz <= 0) { sz = 1; }
        var i = slot % sz;
        if (i < 0) { i = i + sz; }
        if (diff == 0) { return AKPuzzles.EASY[i]; }
        return AKPuzzles.HARD[i];
    }

    static function selectDaily(diff, dayOfYear) {
        var sz = bucketSize(diff);
        if (sz <= 0) { sz = 1; }
        return selectLevel(diff, dayOfYear % sz);
    }
}
