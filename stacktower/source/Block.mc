// ═══════════════════════════════════════════════════════════════
// Block.mc — Single tower block (left edge + width).
//
// World coordinates run with the y-axis pointing UP — i.e. the
// floor sits at row 0 and successive blocks have ascending row
// indices. The view converts (row, leftX, width) to screen pixels
// using a simple camera offset so older blocks scroll off the
// bottom as the tower grows.
//
// Stored as a plain class (not a flat-int slot) because a tower
// rarely exceeds a few dozen blocks before the player misses — the
// allocation cost is negligible at that scale.
// ═══════════════════════════════════════════════════════════════

class Block {
    var leftWX;   // world-x of the block's left edge (whole pixels)
    var widthWX;  // block width in world pixels (>=1)
    var row;      // 0 = base, +1 per layer
    var color;    // packed RGB

    function initialize(left, width, rowIdx, col) {
        leftWX   = left;
        widthWX  = width;
        row      = rowIdx;
        color    = col;
    }

    function rightWX() { return leftWX + widthWX; }
}
