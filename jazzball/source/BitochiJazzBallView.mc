using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;

// ── Leaderboard ────────────────────────────────────────────────────────────────
const LB_GAME_ID = "jazzball";

// ── Game states ───────────────────────────────────────────────────────────────
const JB_MENU      = 0;
const JB_PLAY      = 1;
const JB_LEVEL_WIN = 2;
const JB_DEAD      = 3;   // lost a life — brief flash
const JB_GAMEOVER  = 4;

// ── Cell types (grid) ─────────────────────────────────────────────────────────
const CELL_OPEN   = 0;   // open space, balls can travel here
const CELL_WALL   = 1;   // permanent wall / filled area
const CELL_GROW_H = 2;   // growing wall segment — horizontal (active)
const CELL_GROW_V = 3;   // growing wall segment — vertical (active)
const CELL_TEMP   = 4;   // temporary flood-fill marker (never drawn, never persisted)

// ── Grid size ─────────────────────────────────────────────────────────────────
// We use a 40×40 logical grid.  Each cell is drawn as a small square.
// On a 260×260 watch the safe square region is about 220px → 5.5px per cell.
const GCOLS = 40;
const GROWS = 40;

class BitochiJazzBallView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    // Level state
    hidden var _level;
    hidden var _lives;
    hidden var _targetPct;   // % needed to advance (starts 75)

    // Score: accumulated across levels (filledPct * level per level cleared,
    // plus the partial fill of the level you died on). HIGHER is better.
    hidden var _score;
    hidden var _finalScore;

    // Menu selection (0 = PLAY, 1 = LEADERBOARD) and tap hit-test rects
    hidden var _menuSel;
    hidden var _menuRowX; hidden var _menuRowW; hidden var _menuRowH;
    hidden var _playRowY; hidden var _lbRowY;

    // Grid: flat GCOLS×GROWS array of cell type
    hidden var _grid;

    // Open-cell count (recalculated after each wall completes)
    hidden var _openCount;
    hidden var _totalCells;   // GCOLS * GROWS

    // Balls: each ball = [x10, y10, vx10, vy10, colour]
    // position in *10 fixed-point grid coords (0..GCOLS*10, 0..GROWS*10)
    hidden var _balls;

    // Active growing wall: [col, row, dirH(bool), headA, headB, alive]
    // dirH=true → horizontal growth;  headA grows left, headB grows right
    // headA/B are column or row positions (integers)
    // alive=false means the wall was killed this tick (flashing)
    hidden var _wall;         // null if none

    hidden var _wallAcc;      // fractional wall-growth accumulator (x10)

    // Cursor (for button navigation)
    hidden var _curCol; hidden var _curRow;
    hidden var _curHoriz;   // preferred orientation (true=H, false=V)
    hidden var _nextHoriz;  // alternates between H and V
    hidden var _swipeTick;  // tick when last swipe occurred (for key suppression)

    // Viewport geometry
    hidden var _ox; hidden var _oy; hidden var _cs;  // cell size in pixels

    // Dead flash counter
    hidden var _deadFlash;

    // Ball colours per level
    hidden var _ballColors;

    // Pre-allocated BFS helpers — avoids per-tick allocations in floodFill
    hidden var _floodQueue;   // int[GCOLS*GROWS]

    // Difficulty (0=Easy 1=Normal 2=Hard) from the shared OPTIONS screen
    // (jb_diff). Drives ball count and ball speed; segments the leaderboard.
    hidden var _diff;

    // ── Initialize ────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _w = 0; _h = 0; _tick = 0;
        _gs = JB_MENU;
        _level = 1; _lives = 3;
        _targetPct = 75;
        _score = 0; _finalScore = 0;
        _menuSel = 0;
        _menuRowX = 0; _menuRowW = 0; _menuRowH = 0; _playRowY = 0; _lbRowY = 0;
        _totalCells = GCOLS * GROWS;
        _openCount  = _totalCells;
        _grid = new [_totalCells];
        _balls = new [0];
        _wall = null;
        _wallAcc = 0;
        _curCol = GCOLS / 2; _curRow = GROWS / 2; _curHoriz = true; _nextHoriz = true; _swipeTick = -10;
        _deadFlash = 0;
        _ballColors = [0xFF4422, 0xFF8800, 0xFFCC00, 0x44FF88, 0x44AAFF, 0xFF44AA];
        _floodQueue = new [_totalCells];

        // Difficulty from the shared OPTIONS screen (jb_diff: 0/1/2). Default
        // NORMAL(1) matches the previous single-difficulty behaviour.
        _diff = 1;
        var jd = Application.Storage.getValue("jb_diff");
        if (jd instanceof Number && jd >= 0 && jd <= 2) { _diff = jd; }

        _timer = null;
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupGeo();
    }

    // Start the game-loop timer only while the view is on screen, and
    // stop it whenever the view is hidden (e.g. the leaderboard is
    // pushed on top, or the app is backgrounded) so we never leave a
    // 40 ms callback firing requestUpdate() after teardown.
    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 40, true);
        // The main menu is the shared root view; drop straight into a game.
        // Only auto-start from a fresh launch (JB_MENU) so returning from the
        // post-game leaderboard card doesn't restart the game.
        if (_gs == JB_MENU) { startGame(); }
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    hidden function setupGeo() {
        // Safe inscribed square for a round watch — use 88% of screen
        var safeW = _w * 88 / 100;
        _cs = safeW / GCOLS;
        if (_cs < 2) { _cs = 2; }
        _ox = (_w  - _cs * GCOLS) / 2;
        _oy = (_h  - _cs * GROWS) / 2;
    }

    // ── Timer ─────────────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        if (_gs == JB_PLAY) {
            stepGame();
        } else if (_gs == JB_DEAD) {
            _deadFlash--;
            if (_deadFlash <= 0) {
                if (_lives <= 0) { gameOver(); }
                else { resetWall(); _gs = JB_PLAY; }
            }
        }
        WatchUi.requestUpdate();
    }

    hidden function stepGame() {
        moveBalls();
        if (_wall != null) {
            _wallAcc += 23;
            while (_wallAcc >= 10 && _wall != null) {
                stepWall();
                _wallAcc -= 10;
            }
        }
    }

    // ── Ball movement ─────────────────────────────────────────────────────────
    hidden function moveBalls() {
        for (var i = 0; i < _balls.size(); i++) {
            var b = _balls[i];
            var bx = b[0]; var by = b[1];
            var vx = b[2]; var vy = b[3];

            bx += vx; by += vy;

            // Grid boundary
            var maxX = GCOLS * 10 - 1; var maxY = GROWS * 10 - 1;

            // Check wall/boundary collisions
            var col = bx / 10; var row = by / 10;
            if (col < 0)  { col = 0; }
            if (col >= GCOLS) { col = GCOLS - 1; }
            if (row < 0)  { row = 0; }
            if (row >= GROWS) { row = GROWS - 1; }

            // Reflect off permanent walls or grid edges
            var nx = bx + vx; var ny = by + vy;
            var ncol = nx / 10; var nrow = ny / 10;
            if (ncol < 0) { ncol = 0; }
            if (ncol >= GCOLS) { ncol = GCOLS - 1; }
            if (nrow < 0) { nrow = 0; }
            if (nrow >= GROWS) { nrow = GROWS - 1; }

            var hitX = false; var hitY = false;

            if (bx <= 0 || bx >= maxX) { hitX = true; }
            if (by <= 0 || by >= maxY) { hitY = true; }

            // Check solid cell at next position
            if (!hitX && ncol != col) {
                if (_grid[row * GCOLS + ncol] == CELL_WALL) { hitX = true; }
            }
            if (!hitY && nrow != row) {
                if (_grid[nrow * GCOLS + col] == CELL_WALL) { hitY = true; }
            }

            if (hitX) { vx = -vx; bx = bx - (bx <= 0 ? -1 : 1); }
            if (hitY) { vy = -vy; by = by - (by <= 0 ? -1 : 1); }

            // Clamp
            if (bx < 0) { bx = 0; }
            if (bx > maxX) { bx = maxX; }
            if (by < 0) { by = 0; }
            if (by > maxY) { by = maxY; }

            b[0] = bx; b[1] = by; b[2] = vx; b[3] = vy;
            _balls[i] = b;

            // Check collision with growing wall
            if (_wall != null && _wall[5]) {
                checkBallWallCollision(i);
            }
        }
    }

    hidden function checkBallWallCollision(ballIdx) {
        var b = _balls[ballIdx];
        var bCol = b[0] / 10; var bRow = b[1] / 10;
        var dirH = _wall[2];
        var fixedCoord = dirH ? _wall[1] : _wall[0]; // row for H, col for V
        var headA = _wall[3]; var headB = _wall[4];

        if (dirH) {
            // Horizontal wall at row=fixedCoord, spanning cols headA..headB
            if (bRow == fixedCoord && bCol >= headA && bCol <= headB) {
                killWall(); return;
            }
        } else {
            // Vertical wall at col=fixedCoord, spanning rows headA..headB
            if (bCol == fixedCoord && bRow >= headA && bRow <= headB) {
                killWall(); return;
            }
        }
    }

    // ── Wall growth ───────────────────────────────────────────────────────────
    hidden function stepWall() {
        if (_wall == null || !_wall[5]) { return; }

        var dirH = _wall[2];
        var headA = _wall[3]; var headB = _wall[4];
        var fixedCoord = dirH ? _wall[1] : _wall[0];

        var doneA = false; var doneB = false;

        if (dirH) {
            // Grow left (headA--)
            if (headA > 0) {
                headA--;
                if (_grid[fixedCoord * GCOLS + headA] == CELL_WALL) { doneA = true; headA++; }
                else { _grid[fixedCoord * GCOLS + headA] = CELL_GROW_H; }
            } else { doneA = true; }

            // Grow right (headB++)
            if (headB < GCOLS - 1) {
                headB++;
                if (_grid[fixedCoord * GCOLS + headB] == CELL_WALL) { doneB = true; headB--; }
                else { _grid[fixedCoord * GCOLS + headB] = CELL_GROW_H; }
            } else { doneB = true; }
        } else {
            // Grow up (headA--)
            if (headA > 0) {
                headA--;
                if (_grid[headA * GCOLS + fixedCoord] == CELL_WALL) { doneA = true; headA++; }
                else { _grid[headA * GCOLS + fixedCoord] = CELL_GROW_V; }
            } else { doneA = true; }

            // Grow down (headB++)
            if (headB < GROWS - 1) {
                headB++;
                if (_grid[headB * GCOLS + fixedCoord] == CELL_WALL) { doneB = true; headB--; }
                else { _grid[headB * GCOLS + fixedCoord] = CELL_GROW_V; }
            } else { doneB = true; }
        }

        _wall[3] = headA; _wall[4] = headB;

        if (doneA && doneB) {
            // Wall completed — fill the smaller enclosed area
            solidifyWall();
            _wall = null;
            checkLevelWin();
        }
    }

    hidden function solidifyWall() {
        var dirH = _wall[2];
        var fixedCoord = dirH ? _wall[1] : _wall[0];
        var headA = _wall[3]; var headB = _wall[4];

        // Convert growing cells to permanent wall
        if (dirH) {
            for (var c = headA; c <= headB; c++) {
                _grid[fixedCoord * GCOLS + c] = CELL_WALL;
            }
        } else {
            for (var r = headA; r <= headB; r++) {
                _grid[r * GCOLS + fixedCoord] = CELL_WALL;
            }
        }

        // Flood-fill to find which side has no balls — fill that side
        fillEmptySide();
        recountOpen();

        centerCursor();
    }

    // Place cursor at the center of the grid, or the nearest open cell to center.
    hidden function centerCursor() {
        _curCol = GCOLS / 2; _curRow = GROWS / 2;
        if (_grid[_curRow * GCOLS + _curCol] == CELL_OPEN) { return; }
        var maxD = GCOLS > GROWS ? GCOLS : GROWS;
        for (var d = 1; d < maxD; d++) {
            for (var dr = -d; dr <= d; dr++) {
                var absdr = dr < 0 ? -dr : dr;
                var dc2 = d - absdr;
                var r = _curRow + dr;
                if (r < 1 || r >= GROWS - 1) { continue; }
                var c1 = _curCol + dc2; var c2 = _curCol - dc2;
                if (c1 >= 1 && c1 < GCOLS - 1 && _grid[r * GCOLS + c1] == CELL_OPEN) {
                    _curRow = r; _curCol = c1; return;
                }
                if (dc2 != 0 && c2 >= 1 && c2 < GCOLS - 1 && _grid[r * GCOLS + c2] == CELL_OPEN) {
                    _curRow = r; _curCol = c2; return;
                }
            }
        }
    }

    // Fill the region on each side of the completed wall that contains no balls.
    // Uses in-place CELL_TEMP marking to avoid ANY dynamic array allocation.
    hidden function fillEmptySide() {
        var dirH = _wall[2];
        var fixedCoord = dirH ? _wall[1] : _wall[0];

        // Two seed points, one on each side of the wall
        var seed0; var seed1;
        if (dirH) {
            var r1 = fixedCoord - 1; var r2 = fixedCoord + 1;
            if (r1 < 0)      { r1 = 0; }
            if (r2 >= GROWS) { r2 = GROWS - 1; }
            seed0 = r1 * GCOLS + _wall[3];
            seed1 = r2 * GCOLS + _wall[3];
        } else {
            var c1 = fixedCoord - 1; var c2 = fixedCoord + 1;
            if (c1 < 0)      { c1 = 0; }
            if (c2 >= GCOLS) { c2 = GCOLS - 1; }
            seed0 = _wall[3] * GCOLS + c1;
            seed1 = _wall[3] * GCOLS + c2;
        }

        floodFillSide(seed0);
        floodFillSide(seed1);
    }

    // BFS flood fill from startIdx.
    // Marks the connected CELL_OPEN region as CELL_TEMP, then:
    //   • if no ball found inside → converts CELL_TEMP → CELL_WALL (filled)
    //   • otherwise             → restores CELL_TEMP → CELL_OPEN
    // Uses pre-allocated _floodQueue — zero heap allocations.
    hidden function floodFillSide(startIdx) {
        if (_grid[startIdx] != CELL_OPEN) { return; }

        // BFS — mark visited cells with CELL_TEMP immediately on enqueue
        var qHead = 0; var qTail = 0;
        _grid[startIdx] = CELL_TEMP;
        _floodQueue[qTail] = startIdx; qTail++;

        while (qHead < qTail) {
            var idx = _floodQueue[qHead]; qHead++;
            var r = idx / GCOLS;
            var c = idx % GCOLS;

            // 4-neighbours (inline to avoid allocating a temp array)
            if (r > 0) {
                var n = (r - 1) * GCOLS + c;
                if (_grid[n] == CELL_OPEN) { _grid[n] = CELL_TEMP; _floodQueue[qTail] = n; qTail++; }
            }
            if (r < GROWS - 1) {
                var n = (r + 1) * GCOLS + c;
                if (_grid[n] == CELL_OPEN) { _grid[n] = CELL_TEMP; _floodQueue[qTail] = n; qTail++; }
            }
            if (c > 0) {
                var n = r * GCOLS + (c - 1);
                if (_grid[n] == CELL_OPEN) { _grid[n] = CELL_TEMP; _floodQueue[qTail] = n; qTail++; }
            }
            if (c < GCOLS - 1) {
                var n = r * GCOLS + (c + 1);
                if (_grid[n] == CELL_OPEN) { _grid[n] = CELL_TEMP; _floodQueue[qTail] = n; qTail++; }
            }
        }

        // Check whether any ball landed inside the marked region
        var hasBall = false;
        var bCount = _balls.size();
        for (var bi = 0; bi < bCount && !hasBall; bi++) {
            var bc = _balls[bi][0] / 10;
            var br = _balls[bi][1] / 10;
            if (_grid[br * GCOLS + bc] == CELL_TEMP) { hasBall = true; }
        }

        // Convert CELL_TEMP to final state (single pass over marked cells only)
        var finalCell = hasBall ? CELL_OPEN : CELL_WALL;
        for (var qi = 0; qi < qTail; qi++) {
            _grid[_floodQueue[qi]] = finalCell;
        }
    }

    hidden function recountOpen() {
        _openCount = 0;
        for (var i = 0; i < _totalCells; i++) {
            if (_grid[i] == CELL_OPEN) { _openCount++; }
        }
    }

    hidden function killWall() {
        if (_wall == null) { return; }
        // Remove growing cells from grid
        var dirH = _wall[2];
        var fixedCoord = dirH ? _wall[1] : _wall[0];
        var headA = _wall[3]; var headB = _wall[4];
        if (dirH) {
            for (var c = headA; c <= headB; c++) {
                if (_grid[fixedCoord * GCOLS + c] == CELL_GROW_H) {
                    _grid[fixedCoord * GCOLS + c] = CELL_OPEN;
                }
            }
        } else {
            for (var r = headA; r <= headB; r++) {
                if (_grid[r * GCOLS + fixedCoord] == CELL_GROW_V) {
                    _grid[r * GCOLS + fixedCoord] = CELL_OPEN;
                }
            }
        }
        _wall = null;
        _lives--;
        _deadFlash = 8;
        _gs = JB_DEAD;
        centerCursor();
    }

    hidden function resetWall() { _wall = null; }

    hidden function checkLevelWin() {
        var filledPct = (_totalCells - _openCount) * 100 / _totalCells;
        if (filledPct >= _targetPct) {
            // Reward clearing this level: fill % weighted by level reached.
            _score += filledPct * _level;
            _gs = JB_LEVEL_WIN;
        }
    }

    // ── Game over: accumulate the partial fill of the failed level, then
    // submit the final accumulated score to the global leaderboard (DESC, no
    // variant) and show the game-over screen.
    hidden function gameOver() {
        var filledPct = (_totalCells - _openCount) * 100 / _totalCells;
        _finalScore = _score + filledPct;
        _gs = JB_GAMEOVER;
        Leaderboard.submitScore(LB_GAME_ID, _finalScore, _diffVariant());
        Leaderboard.showPostGame(LB_GAME_ID, _diffVariant(), "JAZZBALL");
    }

    // Leaderboard variant = difficulty, so Easy/Normal/Hard rank separately.
    hidden function _diffVariant() {
        return ["easy", "normal", "hard"][_diff];
    }

    // ── Input ─────────────────────────────────────────────────────────────────

    function doUp() {
        if (_gs == JB_MENU)     { _menuSel = (_menuSel + 1) % 2; return; }
        if (_gs == JB_LEVEL_WIN){ nextLevel(); return; }
        if (_gs == JB_GAMEOVER) { _gs = JB_MENU; _menuSel = 0; return; }
        if (_gs != JB_PLAY || _wall != null) { return; }
        if (_tick - _swipeTick < 3) { return; }
        if (_nextHoriz) { _tryMove(0, -1); }
        else            { _tryMove(-1, 0); }
    }

    function doDown() {
        if (_gs == JB_MENU)     { _menuSel = (_menuSel + 1) % 2; return; }
        if (_gs == JB_LEVEL_WIN){ nextLevel(); return; }
        if (_gs == JB_GAMEOVER) { _gs = JB_MENU; _menuSel = 0; return; }
        if (_gs != JB_PLAY || _wall != null) { return; }
        if (_tick - _swipeTick < 3) { return; }
        if (_nextHoriz) { _tryMove(0, 1); }
        else            { _tryMove(1, 0); }
    }

    function doSelect() {
        if (_gs == JB_MENU)     { activateMenu(); return; }
        if (_gs == JB_LEVEL_WIN){ nextLevel(); return; }
        if (_gs == JB_GAMEOVER) { _gs = JB_MENU; _menuSel = 0; return; }
        if (_gs != JB_PLAY || _wall != null) { return; }
        _fireLine();
    }

    // BACK returns to the shared menu (framework pops this pushed view).
    function doBack() {
        return false;
    }

    function doToggleDir() {
        if (_gs != JB_PLAY) { return; }
        if (_wall != null)  { return; }
        _nextHoriz = !_nextHoriz;
        _swipeTick = _tick;
    }

    function doTap(tx, ty) {
        if (_gs == JB_MENU) {
            // Hit-test the LEADERBOARD row; anything else starts the game.
            if (tx >= _menuRowX && tx <= _menuRowX + _menuRowW
                && ty >= _lbRowY && ty <= _lbRowY + _menuRowH) {
                _menuSel = 1; openLeaderboard();
            } else {
                _menuSel = 0; startGame();
            }
            return;
        }
        if (_gs == JB_LEVEL_WIN){ nextLevel(); return; }
        if (_gs == JB_GAMEOVER) { _gs = JB_MENU; _menuSel = 0; return; }
        if (_gs != JB_PLAY || _wall != null) { return; }
        _fireLine();
    }

    // Move cursor exactly 1 cell. Stays in place if target is not CELL_OPEN.
    hidden function _tryMove(dRow, dCol) {
        var nr = _curRow + dRow;
        var nc = _curCol + dCol;
        if (nr < 1 || nr >= GROWS - 1 || nc < 1 || nc >= GCOLS - 1) { return; }
        if (_grid[nr * GCOLS + nc] == CELL_OPEN) {
            _curRow = nr; _curCol = nc;
        }
    }

    // Fire line from EXACTLY (_curCol, _curRow). No other source of coordinates.
    hidden function _fireLine() {
        var c = _curCol; var r = _curRow;
        if (_grid[r * GCOLS + c] != CELL_OPEN) { return; }
        _curHoriz = _nextHoriz;
        var fixedCoord = _curHoriz ? r : c;
        var startPos   = _curHoriz ? c : r;
        _wall = [c, r, _curHoriz, startPos, startPos, true];
        _wallAcc = 0;
        _grid[r * GCOLS + c] = _curHoriz ? CELL_GROW_H : CELL_GROW_V;
    }

    // ── Game setup ────────────────────────────────────────────────────────────
    hidden function startGame() {
        _level = 1; _lives = 5; _targetPct = 75;
        _score = 0; _finalScore = 0;
        loadLevel();
        _gs = JB_PLAY;
    }

    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _diffVariant(), "JAZZBALL");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    hidden function activateMenu() {
        if (_menuSel == 1) { openLeaderboard(); }
        else { startGame(); }
    }

    hidden function nextLevel() {
        _level++;
        _targetPct = 75;
        loadLevel();
        _gs = JB_PLAY;
    }

    hidden function loadLevel() {
        // Clear grid — border walls only
        for (var i = 0; i < _totalCells; i++) { _grid[i] = CELL_OPEN; }
        // Top/bottom border rows
        for (var c = 0; c < GCOLS; c++) {
            _grid[0 * GCOLS + c] = CELL_WALL;
            _grid[(GROWS - 1) * GCOLS + c] = CELL_WALL;
        }
        // Left/right border cols
        for (var r = 0; r < GROWS; r++) {
            _grid[r * GCOLS + 0] = CELL_WALL;
            _grid[r * GCOLS + (GCOLS - 1)] = CELL_WALL;
        }
        _openCount = 0;
        for (var i = 0; i < _totalCells; i++) { if (_grid[i] == CELL_OPEN) { _openCount++; } }

        _wall = null;
        _curCol = GCOLS / 2; _curRow = GROWS / 2;
        _nextHoriz = true;

        // Level 1 starts with 1 ball, +1 per level. Difficulty shifts the
        // count: Easy one fewer (and a lower cap), Hard one more.
        var ballAdd = [-1, 0, 1][_diff];
        var numBalls = _level + ballAdd;
        if (numBalls < 1) { numBalls = 1; }
        var ballCap = [6, 8, 8][_diff];
        if (numBalls > ballCap) { numBalls = ballCap; }
        _balls = new [numBalls];

        // Balls are faster at higher levels; difficulty scales the base speed
        // and its cap: Easy slower, Hard faster.
        var speedBase = 5 + _level * 2;
        var spdMul = [70, 100, 132][_diff];
        speedBase = speedBase * spdMul / 100;
        if (speedBase < 3) { speedBase = 3; }
        var spdCap = [12, 14, 18][_diff];
        if (speedBase > spdCap) { speedBase = spdCap; }

        for (var i = 0; i < numBalls; i++) {
            var bx = (4 + Math.rand().abs() % (GCOLS - 8)) * 10;
            var by = (4 + Math.rand().abs() % (GROWS - 8)) * 10;
            var vx = (Math.rand().abs() % 2 == 0) ? speedBase : -speedBase;
            var vy = (Math.rand().abs() % 2 == 0) ? speedBase : -speedBase;
            _balls[i] = [bx, by, vx, vy, _ballColors[i % _ballColors.size()]];
        }

    }

    // ── Rendering ─────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeo(); }
        // Never render an in-game menu — the shared menu is the root view.
        if (_gs == JB_MENU)    { startGame(); }
        drawBoard(dc);
        drawBalls(dc);
        drawCursor(dc);
        drawHUD(dc);
        if (_gs == JB_DEAD)    { drawDeadFlash(dc); }
        if (_gs == JB_LEVEL_WIN){ drawLevelWin(dc); }
        if (_gs == JB_GAMEOVER){ drawGameOver(dc); }
    }

    // ── Menu ─────────────────────────────────────────────────────────────────
    hidden function drawMenu(dc) {
        dc.setColor(0x060810, 0x060810); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0C1220, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);
        dc.setColor(0x101A30, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 14);

        // Decorative bouncing dots — pulled up/compacted to clear the menu rows.
        var dotColors = [0xFF4422, 0xFF8800, 0x44FF88, 0x44AAFF, 0xFF44AA];
        var dotX = [75, 102, 138, 165, 120];
        var dotY = [52,  71,  52,  71,  82];
        for (var i = 0; i < 5; i++) {
            dc.setColor(dotColors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dotX[i] * _w / 240, dotY[i] * _h / 240, 5);
        }

        // Title block (~18% more compact than before so the rows never overlap
        // the text on round watches).
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 25 / 100, Graphics.FONT_MEDIUM, "JAZZBALL", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 37 / 100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 44 / 100, Graphics.FONT_XTINY, "Trap the balls!", Graphics.TEXT_JUSTIFY_CENTER);

        // ── Menu rows (space-aware) ──────────────────────────────────────────
        var rowW = _w * 54 / 100;
        var rowH = _h * 12 / 100;
        if (rowH < 20) { rowH = 20; }
        var rowX = (_w - rowW) / 2;
        var gap  = _h * 3 / 100;
        var playY = _h * 55 / 100;
        var lbY   = playY + rowH + gap;

        _menuRowX = rowX; _menuRowW = rowW; _menuRowH = rowH;
        _playRowY = playY; _lbRowY = lbY;

        // PLAY row
        var playSel = (_menuSel == 0);
        dc.setColor(playSel ? 0x123A1E : 0x0E2014, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rowX, playY, rowW, rowH, 5);
        dc.setColor(playSel ? 0x44FF88 : 0x2A8050, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rowX, playY, rowW, rowH, 5);
        if (playSel) {
            var ay = playY + rowH / 2;
            dc.fillPolygon([[rowX + 6, ay - 4], [rowX + 6, ay + 4], [rowX + 12, ay]]);
        }
        dc.setColor(playSel ? 0xBFFFD0 : 0x6FBF90, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rowX + rowW / 2 + 6, playY + (rowH - 14) / 2, Graphics.FONT_XTINY,
                    "PLAY", Graphics.TEXT_JUSTIFY_CENTER);

        // LEADERBOARD row (shared gold badge)
        LbBadge.drawRow(dc, rowX, lbY, rowW, rowH, _menuSel == 1);
    }

    hidden function drawBoard(dc) {
        dc.setColor(0x080C18, 0x080C18); dc.clear();

        var blink = (_tick % 4 < 2);
        var growHC = blink ? 0x88DDFF : 0x4499CC;
        var growVC = blink ? 0xFFDD88 : 0xCC9944;

        dc.setColor(0x2A3D66, Graphics.COLOR_TRANSPARENT);
        for (var row = 0; row < GROWS; row++) {
            var base = row * GCOLS;
            var py = _oy + row * _cs;
            var spanS = -1;
            for (var col = 0; col <= GCOLS; col++) {
                var c = (col < GCOLS) ? _grid[base + col] : CELL_OPEN;
                if (c == CELL_WALL) {
                    if (spanS < 0) { spanS = col; }
                } else {
                    if (spanS >= 0) {
                        dc.fillRectangle(_ox + spanS * _cs, py, (col - spanS) * _cs, _cs);
                        spanS = -1;
                    }
                    if (c == CELL_GROW_H) {
                        dc.setColor(growHC, Graphics.COLOR_TRANSPARENT);
                        dc.fillRectangle(_ox + col * _cs, py, _cs, _cs);
                        dc.setColor(0x2A3D66, Graphics.COLOR_TRANSPARENT);
                    } else if (c == CELL_GROW_V) {
                        dc.setColor(growVC, Graphics.COLOR_TRANSPARENT);
                        dc.fillRectangle(_ox + col * _cs, py, _cs, _cs);
                        dc.setColor(0x2A3D66, Graphics.COLOR_TRANSPARENT);
                    }
                }
            }
        }

        dc.setColor(0x1A2A44, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_ox - 1, _oy - 1, _cs * GCOLS + 2, _cs * GROWS + 2);
    }

    // ── Balls ─────────────────────────────────────────────────────────────────
    hidden function drawBalls(dc) {
        var br = _cs + 1;   // ball radius in pixels (slightly larger than a cell)
        if (br < 3) { br = 3; }
        for (var i = 0; i < _balls.size(); i++) {
            var b = _balls[i];
            var px = _ox + b[0] * _cs / 10;
            var py = _oy + b[1] * _cs / 10;
            // Glow shadow
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + 1, py + 1, br);
            // Ball body
            dc.setColor(b[4], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, br);
            // Highlight
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - br/3, py - br/3, br/3 + 1);
        }
    }

    // ── Cursor ────────────────────────────────────────────────────────────────
    hidden function drawCursor(dc) {
        if (_gs != JB_PLAY || _wall != null) { return; }
        var px = _ox + _curCol * _cs;
        var py = _oy + _curRow * _cs;
        var mid = _cs / 2;

        // Crosshair at exact fire position
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px, py, _cs, _cs);

        // Direction preview line
        dc.setColor((_tick % 6 < 3) ? 0xFFFF44 : 0xAA9900, Graphics.COLOR_TRANSPARENT);
        if (_nextHoriz) {
            dc.drawLine(_ox, py + mid, _ox + _cs * GCOLS, py + mid);
        } else {
            dc.drawLine(px + mid, _oy, px + mid, _oy + _cs * GROWS);
        }
    }

    // ── HUD ───────────────────────────────────────────────────────────────────
    hidden function drawHUD(dc) {
        var filledPct = (_totalCells - _openCount) * 100 / _totalCells;

        // Top: level and lives
        var hudY = _oy - 14;
        if (hudY < 2) { hudY = 2; }
        dc.setColor(0x7799CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_ox, hudY, Graphics.FONT_XTINY, "Lv" + _level, Graphics.TEXT_JUSTIFY_LEFT);
        // Lives as dots
        var livesStr = "";
        for (var i = 0; i < _lives; i++) { livesStr = livesStr + "O"; }
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_ox + _cs * GCOLS / 2, hudY, Graphics.FONT_XTINY, livesStr, Graphics.TEXT_JUSTIFY_CENTER);
        // Target %
        dc.setColor(filledPct >= _targetPct ? 0x44FF88 : 0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_ox + _cs * GCOLS, hudY, Graphics.FONT_XTINY,
            "" + filledPct + "%", Graphics.TEXT_JUSTIFY_RIGHT);

        // Progress bar at bottom
        var barY = _oy + _cs * GROWS + 3;
        if (barY + 6 > _h) { barY = _oy - 8; }
        var barW = _cs * GCOLS;
        dc.setColor(0x1A2A44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_ox, barY, barW, 5);
        var filled = barW * filledPct / 100;
        dc.setColor(filledPct >= _targetPct ? 0x44FF88 : 0x4488CC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_ox, barY, filled, 5);
        // Target marker
        var tgtX = _ox + barW * _targetPct / 100;
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tgtX, barY - 1, tgtX, barY + 6);
    }

    // ── Overlays ─────────────────────────────────────────────────────────────
    hidden function drawDeadFlash(dc) {
        if (_deadFlash % 2 == 0) {
            dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(_ox, _oy, _cs * GCOLS, _cs * GROWS);
            dc.drawRectangle(_ox + 1, _oy + 1, _cs * GCOLS - 2, _cs * GROWS - 2);
        }
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h / 2 - 8, Graphics.FONT_XTINY, "WALL BROKEN!", Graphics.TEXT_JUSTIFY_CENTER);
        var livesStr = "";
        for (var i = 0; i < _lives; i++) { livesStr = livesStr + "O"; }
        dc.setColor(0xFF9966, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h / 2 + 8, Graphics.FONT_XTINY, livesStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawLevelWin(dc) {
        var filledPct = (_totalCells - _openCount) * 100 / _totalCells;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w/2 - 68, _h/2 - 32, 136, 64, 8);
        dc.setColor(0x224488, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_w/2 - 68, _h/2 - 32, 136, 64, 8);
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 28, Graphics.FONT_MEDIUM, "LEVEL " + _level + "!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 6, Graphics.FONT_XTINY, "Filled: " + filledPct + "%", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 8 < 4) ? 0x88CCFF : 0x4488CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 + 12, Graphics.FONT_XTINY, "Tap > next level", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x060810, 0x060810); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0C1220, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);

        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 25 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 42 / 100, Graphics.FONT_XTINY, "Reached level " + _level, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 54 / 100, Graphics.FONT_SMALL, "Score " + _finalScore, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 10 < 5) ? 0x44AAFF : 0x2266AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 76 / 100, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
