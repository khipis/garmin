// ═══════════════════════════════════════════════════════════════
// GridManager.mc — Board data + mine placement + chunked BFS.
//
// Board sizes: max 32×32 (1024 cells).
//
// Mine placement: partial Fisher-Yates on eligible cells.
//   No integer division or modulo in hot paths (row/col counters).
//
// Flood-fill: iterative BFS split across Timer ticks.
//   _startFlood(r,c) kicks off the BFS for one cell.
//   bfsStep() continues it — call every timer tick until
//   floodPending is false.
//   MAX_FLOOD_PER_STEP cells are processed per call so the
//   Garmin watchdog is never approached.
//   The queue stores (row,col) pairs → no division anywhere.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const REV_OK   = 0;
const REV_BOOM = 1;
const REV_NOOP = 2;

// Max BFS cells processed per timer tick.
// 30 cells × ~300 ops ≈ 9 000 ops → ~9 ms at 1 MHz — well under
// the Garmin watchdog on every supported device.
const MAX_FLOOD_PER_STEP = 30;

class GridManager {
    var n;
    var total;
    var mineCount;

    var mines;      // ByteArray[total]  0/1
    var state;      // ByteArray[total]  bit0=revealed, bit1=flagged
    var numbers;    // ByteArray[total]  0-8, valid only for revealed cells

    var revealedCount;
    var flagCount;
    var minesPlaced;

    // BFS queue: (row,col) pairs — no division/modulo needed
    hidden var _queueR;
    hidden var _queueC;
    hidden var _qHead;
    hidden var _qTail;

    // true while the flood-fill BFS has remaining work
    var floodPending;

    function initialize() { configure(8, 10); }

    function configure(size, mines_) {
        n             = size;
        total         = size * size;
        mineCount     = mines_;
        mines         = new [total]b;
        state         = new [total]b;
        numbers       = new [total]b;
        revealedCount = 0;
        flagCount     = 0;
        minesPlaced   = false;
        floodPending  = false;
        _queueR = new [total];
        _queueC = new [total];
        _qHead  = 0;
        _qTail  = 0;
    }

    function idx(r, c) { return r * n + c; }

    // ── Flag toggle ──────────────────────────────────────────────
    function toggleFlag(r, c) {
        var i = idx(r, c);
        if ((state[i] & ST_REVEALED) != 0) { return false; }
        if ((state[i] & ST_FLAGGED)  != 0) {
            state[i] = state[i] & ~ST_FLAGGED;
            flagCount = flagCount - 1;
        } else {
            state[i] = state[i] | ST_FLAGGED;
            flagCount = flagCount + 1;
        }
        return true;
    }

    // ── Reveal ───────────────────────────────────────────────────
    // Returns REV_BOOM (mine), REV_NOOP (already open/flagged),
    // or REV_OK (success; check isWon() after the BFS drains).
    function reveal(r, c) {
        var i = idx(r, c);
        if ((state[i] & ST_REVEALED) != 0) { return REV_NOOP; }
        if ((state[i] & ST_FLAGGED)  != 0) { return REV_NOOP; }

        if (!minesPlaced) { _placeMines(r, c); minesPlaced = true; }

        if (mines[i] == 1) {
            state[i] = state[i] | ST_REVEALED;
            return REV_BOOM;
        }
        _startFlood(r, c);
        return REV_OK;
        // Win is checked by the caller after floodPending goes false.
    }

    // ── BFS (chunked) ────────────────────────────────────────────
    // Kick off a new flood from (startR, startC).
    hidden function _startFlood(startR, startC) {
        _qHead = 0; _qTail = 0;
        floodPending = false;

        var si  = startR * n + startC;
        var cnt = _countAround(startR, startC);
        numbers[si] = cnt;
        state[si]   = state[si] | ST_REVEALED;
        revealedCount = revealedCount + 1;

        if (cnt != 0) { return; }   // numbered cell — no cascade

        _queueR[0] = startR;
        _queueC[0] = startC;
        _qTail = 1;
        floodPending = true;
        _bfsChunk();                // process first batch immediately
    }

    // Continue the BFS — called from the timer tick.
    function bfsStep() {
        if (!floodPending) { return; }
        _bfsChunk();
    }

    // Process up to MAX_FLOOD_PER_STEP cells from the queue.
    hidden function _bfsChunk() {
        var steps = 0;
        while (_qHead < _qTail && steps < MAX_FLOOD_PER_STEP) {
            var qr = _queueR[_qHead];
            var qc = _queueC[_qHead];
            _qHead = _qHead + 1;
            steps  = steps  + 1;

            for (var dr = -1; dr <= 1; dr++) {
                for (var dc = -1; dc <= 1; dc++) {
                    if (dr == 0 && dc == 0) { continue; }
                    var nr = qr + dr;
                    var nc = qc + dc;
                    if (nr < 0 || nr >= n || nc < 0 || nc >= n) { continue; }
                    var ni = nr * n + nc;
                    if (mines[ni] == 1)                 { continue; }
                    if ((state[ni] & ST_REVEALED) != 0) { continue; }
                    if ((state[ni] & ST_FLAGGED)  != 0) { continue; }

                    var cnt = _countAround(nr, nc);
                    numbers[ni] = cnt;
                    state[ni]   = state[ni] | ST_REVEALED;
                    revealedCount = revealedCount + 1;

                    if (cnt == 0 && _qTail < total) {
                        _queueR[_qTail] = nr;
                        _queueC[_qTail] = nc;
                        _qTail = _qTail + 1;
                    }
                }
            }
        }
        floodPending = (_qHead < _qTail);
    }

    // Count mines in the 8 neighbours of (r,c) — multiplication only.
    hidden function _countAround(r, c) {
        var cnt = 0;
        for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
                if (dr == 0 && dc == 0) { continue; }
                var nr = r + dr; var nc = c + dc;
                if (nr < 0 || nr >= n || nc < 0 || nc >= n) { continue; }
                if (mines[nr * n + nc] == 1) { cnt = cnt + 1; }
            }
        }
        return cnt;
    }

    // ── Mine placement (Fisher-Yates, no division) ───────────────
    hidden function _placeMines(sr, sc) {
        var pool = new [total];
        var pN   = 0;
        var r    = 0; var c = 0;
        for (var i = 0; i < total; i++) {
            var dr = r - sr; if (dr < 0) { dr = -dr; }
            var dc = c - sc; if (dc < 0) { dc = -dc; }
            if (dr > 1 || dc > 1) { pool[pN] = i; pN = pN + 1; }
            c = c + 1;
            if (c >= n) { c = 0; r = r + 1; }
        }
        var goal = mineCount; if (goal > pN) { goal = pN; }
        for (var k = 0; k < goal; k++) {
            var j = k + (Math.rand() % (pN - k));
            if (j < k) { j = k; }
            var tmp = pool[k]; pool[k] = pool[j]; pool[j] = tmp;
            mines[pool[k]] = 1;
        }
        mineCount = goal;
    }

    // ── Helpers ──────────────────────────────────────────────────
    function isRevealed(r, c) { return (state[idx(r,c)] & ST_REVEALED) != 0; }
    function isFlagged (r, c) { return (state[idx(r,c)] & ST_FLAGGED)  != 0; }
    function getNumber (r, c) { return numbers[idx(r,c)]; }
    function isMine    (r, c) { return mines[idx(r,c)] == 1; }
    function inBounds  (r, c) { return r >= 0 && r < n && c >= 0 && c < n; }

    // Win condition A: all safe cells revealed.
    // Win condition B: all mines correctly flagged (flagCount == mineCount
    //                  AND every flagged cell is a mine, no wrong flags).
    //                  Guards against false-win before mines are placed.
    function isWon() {
        if (!minesPlaced) { return false; }
        if (revealedCount == total - mineCount) { return true; }
        if (flagCount == mineCount) {
            for (var i = 0; i < total; i++) {
                if ((state[i] & ST_FLAGGED) != 0 && mines[i] != 1) { return false; }
            }
            return true;
        }
        return false;
    }

    function revealAllMines() {
        for (var i = 0; i < total; i++) {
            if (mines[i] == 1) { state[i] = state[i] | ST_REVEALED; }
        }
    }
}
