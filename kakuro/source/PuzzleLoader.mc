// ═══════════════════════════════════════════════════════════════
// PuzzleLoader.mc — Picks a puzzle from KKPuzzles.
//
// The 20 puzzles are divided into three difficulty buckets:
//
//   EASY  → ids 0..6                 (4×4 grid, 3×3 inner)
//   MED   → ids 7..13                (5×5 grid, 4×4 inner)
//   HARD  → ids 14..19               (5×5 grid w/ one interior black)
//
// `pick(difficulty, slot)` returns the puzzle index for the slot
// (0-based, wraps within the bucket).  For "Daily" mode we use
// today's day-of-year as the slot so two players on the same day
// face the same puzzle.
// ═══════════════════════════════════════════════════════════════

using Toybox.Time;
using Toybox.Time.Gregorian;

const KK_DIFF_EASY = 0;
const KK_DIFF_MED  = 1;
const KK_DIFF_HARD = 2;

class PuzzleLoader {

    static function bucketSize(diff) {
        if (diff == KK_DIFF_EASY) { return KK_EASY_COUNT; }
        if (diff == KK_DIFF_MED)  { return KK_MED_COUNT;  }
        return KK_HARD_COUNT;
    }

    hidden static function bucketStart(diff) {
        if (diff == KK_DIFF_EASY) { return 0; }
        if (diff == KK_DIFF_MED)  { return KK_EASY_COUNT; }
        return KK_EASY_COUNT + KK_MED_COUNT;
    }

    // 0-based slot inside the bucket, wraps with the bucket size.
    static function pick(diff, slot) {
        var size = bucketSize(diff);
        if (size <= 0) { return 0; }
        var s = slot % size;
        if (s < 0) { s = s + size; }
        return bucketStart(diff) + s;
    }

    // Today's day-of-year, used as the daily seed.
    static function todaySlot() {
        try {
            var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            return 31 * (now.month - 1) + now.day;
        } catch (e) {
            return 0;
        }
    }
}
