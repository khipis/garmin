// ═══════════════════════════════════════════════════════════════
// TowerManager.mc — Tower state, drop logic, "perfect" detection.
//
// Holds the placed blocks plus the single moving block. Drop logic
// trims the moving block to its overlap with the previous block and
// reports a `DropResult` describing what happened (perfect / partial
// / miss + size of the falling overhang for the renderer).
//
// To stay light on memory the tower keeps only the most recent
// VISIBLE_LIMIT blocks (anything older has scrolled off the bottom
// anyway). Older block records are discarded and `baseRow` is
// updated to keep row indices monotonic without wrapping.
// ═══════════════════════════════════════════════════════════════

const VISIBLE_LIMIT = 24;       // how many top blocks to keep in memory
const PERFECT_SLACK = 1;        // allow ±1 px slop for a "perfect" call

class DropResult {
    var status;          // 0 = perfect, 1 = partial, 2 = miss
    var newLeftWX;       // trimmed block left (world-x)
    var newWidthWX;      // trimmed block width
    var overhangLeftWX;  // left edge of overhang slice (for animation)
    var overhangWidthWX; // width of overhang (0 when perfect)
    var overhangOnLeft;  // 1 = overhang sliced off the left, 0 = right
    var row;             // row index at which the block landed
    var special;         // 0 = normal, 1 = gold block was placed
    function initialize() {
        status=0; newLeftWX=0; newWidthWX=0;
        overhangLeftWX=0; overhangWidthWX=0; overhangOnLeft=0; row=0; special=0;
    }
}

// One falling overhang slice — rendered as it tumbles off the tower.
class FallingPiece {
    var leftWX;
    var widthWX;
    var row;
    var yVel;         // world-y velocity (rows / tick)  positive = downward
    var xVel;         // horizontal drift (world-x / tick) — flings outward
    var color;
    var special;      // 0 = normal, 1 = gold slice
    var spin;         // current rotation (degrees, decorative)
    var spinV;        // spin velocity
    function initialize(l, w, r, c, leftSide, spec) {
        leftWX  = l; widthWX = w; row = r; color = c; special = spec;
        yVel    = 0.4;
        xVel    = leftSide ? -1.4 : 1.4;
        spin    = 0;
        spinV   = leftSide ? -9 : 9;
    }
}

class TowerManager {
    var blocks;            // last <=VISIBLE_LIMIT placed blocks (bottom..top)
    var falling;           // list of in-flight overhang pieces (max ~6)
    var moving;            // current sliding Block (or null between rounds)
    var moveDir;           // +1 right, -1 left
    var moveSpeed;         // world-x pixels per tick
    var worldMinX;         // playable left bound (set by view)
    var worldMaxX;         // playable right bound (set by view)
    var totalPlaced;       // monotonic count (drives row + colour rotation)

    function initialize() {
        blocks         = [];
        falling        = [];
        moving         = null;
        moveDir        = 1;
        moveSpeed      = 2.0;
        worldMinX      = 0;
        worldMaxX      = 100;
        totalPlaced    = 0;
    }

    function reset() {
        blocks      = [];
        falling     = [];
        moving      = null;
        moveDir     = 1;
        moveSpeed   = 2.0;
        totalPlaced = 0;
    }

    function setBounds(minX, maxX) {
        worldMinX = minX;
        worldMaxX = maxX;
    }

    function topBlock() {
        if (blocks.size() == 0) { return null; }
        return blocks[blocks.size() - 1];
    }

    // Append the foundation block (called once per game).
    function placeFoundation(width, color) {
        var left = (worldMinX + worldMaxX) / 2 - width / 2;
        blocks.add(new Block(left, width, 0, color, 0));
        totalPlaced = 1;
    }

    // Spawn a new moving block above the current top. Width matches
    // the latest placed block (tower can only shrink, never grow).
    // `spec` = 1 marks a gold bonus block.
    function spawnMoving(color, speed, spec) {
        var top = topBlock();
        if (top == null) { return; }
        var w = top.widthWX;
        // Spawn at the far left bound so it always slides into view.
        var startLeft = worldMinX;
        moving    = new Block(startLeft, w, top.row + 1, color, spec);
        moveSpeed = speed;
        moveDir   = 1;
    }

    // Per-tick movement update. Bounces off the playable bounds.
    function step() {
        if (moving == null) { return; }
        var nl = moving.leftWX + moveDir * moveSpeed;
        var maxLeft = worldMaxX - moving.widthWX;
        if (nl <= worldMinX) { nl = worldMinX; moveDir = 1;  }
        if (nl >= maxLeft)   { nl = maxLeft;   moveDir = -1; }
        moving.leftWX = nl;

        // Advance any falling overhangs (fast accelerating drop).
        var i = 0;
        while (i < falling.size()) {
            var f = falling[i];
            f.row    = f.row - f.yVel;
            f.yVel   = f.yVel + 0.18;
            f.leftWX = f.leftWX + f.xVel;
            f.spin   = f.spin + f.spinV;
            // Discard once a few rows below the latest top → off-screen.
            var topRow = (topBlock() != null) ? topBlock().row : 0;
            if (f.row < topRow - 14) {
                falling.remove(f);
            } else {
                i = i + 1;
            }
        }
    }

    // Drop the moving block onto the tower. Returns a DropResult or
    // null if there is no active moving block.
    function drop() {
        if (moving == null) { return null; }
        var top = topBlock();
        if (top == null) { return null; }

        var res = new DropResult();
        res.row = moving.row;
        res.special = moving.special;
        var mspec = moving.special;

        var movL = moving.leftWX;
        var movR = moving.leftWX + moving.widthWX;
        var topL = top.leftWX;
        var topR = top.leftWX + top.widthWX;

        // Compute overlap with the previous top block.
        var ovL = (movL > topL) ? movL : topL;
        var ovR = (movR < topR) ? movR : topR;
        var ov  = ovR - ovL;

        if (ov <= 0) {
            // Total miss — tower stays, block becomes one big falling piece.
            res.status        = 2;
            res.newLeftWX     = movL;
            res.newWidthWX    = 0;
            res.overhangLeftWX  = movL;
            res.overhangWidthWX = moving.widthWX;
            res.overhangOnLeft  = (movL + moving.widthWX/2) < (topL + top.widthWX/2) ? 1 : 0;
            falling.add(new FallingPiece(movL, moving.widthWX, moving.row,
                                         moving.color, res.overhangOnLeft == 1, mspec));
            moving = null;
            return res;
        }

        // Perfect-or-near-perfect: snap to top block, no trimming.
        var dl = movL - topL; if (dl < 0) { dl = -dl; }
        if (dl <= PERFECT_SLACK) {
            res.status     = 0;
            res.newLeftWX  = topL;
            res.newWidthWX = top.widthWX;
            blocks.add(new Block(topL, top.widthWX, moving.row, moving.color, mspec));
            _trimMemory();
            moving = null;
            totalPlaced = totalPlaced + 1;
            return res;
        }

        // Partial: trim moving block to overlap with top, slice overhang.
        res.status     = 1;
        res.newLeftWX  = ovL;
        res.newWidthWX = ov;
        // Determine overhang side
        if (movL < topL) {
            res.overhangLeftWX  = movL;
            res.overhangWidthWX = ovL - movL;
            res.overhangOnLeft  = 1;
        } else {
            res.overhangLeftWX  = ovR;
            res.overhangWidthWX = movR - ovR;
            res.overhangOnLeft  = 0;
        }
        if (res.overhangWidthWX > 0) {
            falling.add(new FallingPiece(res.overhangLeftWX,
                                         res.overhangWidthWX,
                                         moving.row, moving.color,
                                         res.overhangOnLeft == 1, mspec));
        }
        blocks.add(new Block(res.newLeftWX, res.newWidthWX,
                             moving.row, moving.color, mspec));
        _trimMemory();
        moving = null;
        totalPlaced = totalPlaced + 1;
        return res;
    }

    // Discard old blocks that have scrolled off the visible window.
    hidden function _trimMemory() {
        while (blocks.size() > VISIBLE_LIMIT) {
            blocks.remove(blocks[0]);
        }
    }

    // Number of blocks placed beyond the foundation = current "height".
    function height() {
        if (totalPlaced <= 1) { return 0; }
        return totalPlaced - 1;
    }
}
