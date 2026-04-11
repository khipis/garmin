using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

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

    // Wall grow speed in cells per tick
    hidden var _growSpeed;    // 1 cell every N ticks; counter

    // Cursor (for button navigation)
    hidden var _curCol; hidden var _curRow;
    hidden var _curHoriz;   // preferred orientation (true=H, false=V)

    // Viewport geometry
    hidden var _ox; hidden var _oy; hidden var _cs;  // cell size in pixels

    // Dead flash counter
    hidden var _deadFlash;

    // Ball colours per level
    hidden var _ballColors;

    // ── Initialize ────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _w = 0; _h = 0; _tick = 0;
        _gs = JB_MENU;
        _level = 1; _lives = 3;
        _targetPct = 75;
        _totalCells = GCOLS * GROWS;
        _openCount  = _totalCells;
        _grid = new [_totalCells];
        _balls = new [0];
        _wall = null;
        _growSpeed = 3;
        _curCol = GCOLS / 2; _curRow = GROWS / 2; _curHoriz = true;
        _deadFlash = 0;
        _ballColors = [0xFF4422, 0xFF8800, 0xFFCC00, 0x44FF88, 0x44AAFF, 0xFF44AA];

        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 50, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupGeo();
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
                if (_lives <= 0) { _gs = JB_GAMEOVER; }
                else { resetWall(); _gs = JB_PLAY; }
            }
        }
        WatchUi.requestUpdate();
    }

    // ── Core game step ────────────────────────────────────────────────────────
    hidden function stepGame() {
        moveBalls();
        if (_wall != null) { stepWall(); }
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
        if (_tick % _growSpeed != 0)    { return; }

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
    }

    // Simple flood fill: find connected open regions on each side of the wall.
    // Fill the region that contains NO balls.
    hidden function fillEmptySide() {
        var dirH = _wall[2];
        var fixedCoord = dirH ? _wall[1] : _wall[0];

        // Get two seed points on either side of the wall
        var seeds = new [2];
        if (dirH) {
            var r1 = fixedCoord - 1; var r2 = fixedCoord + 1;
            if (r1 < 0) { r1 = 0; } if (r2 >= GROWS) { r2 = GROWS - 1; }
            seeds[0] = r1 * GCOLS + _wall[3]; // left-edge col of wall, row above
            seeds[1] = r2 * GCOLS + _wall[3]; // left-edge col, row below
        } else {
            var c1 = fixedCoord - 1; var c2 = fixedCoord + 1;
            if (c1 < 0) { c1 = 0; } if (c2 >= GCOLS) { c2 = GCOLS - 1; }
            seeds[0] = _wall[3] * GCOLS + c1; // row top of wall, col left
            seeds[1] = _wall[3] * GCOLS + c2; // row top, col right
        }

        for (var si = 0; si < 2; si++) {
            var seed = seeds[si];
            if (_grid[seed] != CELL_OPEN) { continue; }

            // Flood fill from seed — collect region
            var region = floodCollect(seed);
            if (region == null) { continue; }

            // Check if any ball is in this region
            var hasBall = false;
            for (var bi = 0; bi < _balls.size() && !hasBall; bi++) {
                var bc = _balls[bi][0] / 10;
                var br = _balls[bi][1] / 10;
                var idx = br * GCOLS + bc;
                for (var ri = 0; ri < region.size() && !hasBall; ri++) {
                    if (region[ri] == idx) { hasBall = true; }
                }
            }

            if (!hasBall) {
                // Fill this region
                for (var ri = 0; ri < region.size(); ri++) {
                    _grid[region[ri]] = CELL_WALL;
                }
            }
        }
    }

    // Flood fill collecting up to 1000 cells (limits CPU spike)
    hidden function floodCollect(startIdx) {
        var visited = new [_totalCells];
        for (var i = 0; i < _totalCells; i++) { visited[i] = false; }

        var queue = new [800];
        var qHead = 0; var qTail = 0;
        queue[qTail] = startIdx; qTail++; visited[startIdx] = true;

        var result = new [0];
        var rSize = 0;

        while (qHead < qTail && rSize < 600) {
            var idx = queue[qHead]; qHead++;
            var r = idx / GCOLS; var c = idx % GCOLS;

            // Append to result
            var newResult = new [rSize + 1];
            for (var i = 0; i < rSize; i++) { newResult[i] = result[i]; }
            newResult[rSize] = idx;
            result = newResult; rSize++;

            // 4-neighbours
            var neighbours = new [4];
            neighbours[0] = (r > 0)          ? (r-1)*GCOLS+c : -1;
            neighbours[1] = (r < GROWS-1)    ? (r+1)*GCOLS+c : -1;
            neighbours[2] = (c > 0)          ? r*GCOLS+(c-1) : -1;
            neighbours[3] = (c < GCOLS-1)    ? r*GCOLS+(c+1) : -1;

            for (var ni = 0; ni < 4; ni++) {
                var n = neighbours[ni];
                if (n < 0 || visited[n]) { continue; }
                if (_grid[n] != CELL_OPEN) { continue; }
                visited[n] = true;
                if (qTail < 800) { queue[qTail] = n; qTail++; }
            }
        }
        return result;
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
    }

    hidden function resetWall() { _wall = null; }

    hidden function checkLevelWin() {
        var filledPct = (_totalCells - _openCount) * 100 / _totalCells;
        if (filledPct >= _targetPct) {
            _gs = JB_LEVEL_WIN;
        }
    }

    // ── Input ─────────────────────────────────────────────────────────────────
    function doUp() {
        if (_gs == JB_MENU)     { return; }
        if (_gs == JB_LEVEL_WIN){ nextLevel(); return; }
        if (_gs == JB_GAMEOVER) { _gs = JB_MENU; return; }
        if (_gs != JB_PLAY)     { return; }
        if (_wall != null)      { return; }
        if (_curRow > 0) { _curRow--; }
    }

    function doDown() {
        if (_gs == JB_MENU)     { return; }
        if (_gs == JB_LEVEL_WIN){ nextLevel(); return; }
        if (_gs == JB_GAMEOVER) { _gs = JB_MENU; return; }
        if (_gs != JB_PLAY)     { return; }
        if (_wall != null)      { return; }
        if (_curRow < GROWS - 1) { _curRow++; }
    }

    function doSelect() {
        if (_gs == JB_MENU)     { startGame(); return; }
        if (_gs == JB_LEVEL_WIN){ nextLevel(); return; }
        if (_gs == JB_GAMEOVER) { _gs = JB_MENU; return; }
        if (_gs != JB_PLAY)     { return; }
        if (_wall != null)      { _curHoriz = !_curHoriz; return; } // toggle orientation
        placeWall(_curCol, _curRow, _curHoriz);
    }

    function doBack() {
        if (_gs == JB_PLAY)     { _gs = JB_MENU; _wall = null; }
        else if (_gs != JB_MENU){ _gs = JB_MENU; }
    }

    function doMenu() { doBack(); }

    function doTap(tx, ty) {
        if (_gs == JB_MENU)     { startGame(); return; }
        if (_gs == JB_LEVEL_WIN){ nextLevel(); return; }
        if (_gs == JB_GAMEOVER) { _gs = JB_MENU; return; }
        if (_gs != JB_PLAY)     { return; }

        // Convert tap to grid cell
        var col = (tx - _ox) / _cs;
        var row = (ty - _oy) / _cs;
        if (col < 0 || col >= GCOLS || row < 0 || row >= GROWS) { return; }

        if (_wall != null) {
            // Second tap toggles orientation
            _curHoriz = !_curHoriz;
            return;
        }

        _curCol = col; _curRow = row;
        placeWall(col, row, _curHoriz);
    }

    hidden function placeWall(col, row, horiz) {
        // Can't place on a wall cell
        if (_grid[row * GCOLS + col] != CELL_OPEN) { return; }

        // Initialise growing wall
        var fixedCoord = horiz ? row : col;
        var startPos   = horiz ? col : row;
        _wall = [col, row, horiz, startPos, startPos, true];
        // Mark origin cell
        _grid[row * GCOLS + col] = horiz ? CELL_GROW_H : CELL_GROW_V;
    }

    // ── Game setup ────────────────────────────────────────────────────────────
    hidden function startGame() {
        _level = 1; _lives = 3; _targetPct = 75;
        loadLevel();
        _gs = JB_PLAY;
    }

    hidden function nextLevel() {
        _level++;
        _targetPct = 75;
        loadLevel();
        _gs = JB_PLAY;
    }

    hidden function loadLevel() {
        // Clear grid
        for (var i = 0; i < _totalCells; i++) { _grid[i] = CELL_OPEN; }
        _openCount = _totalCells;
        _wall = null;
        _curCol = GCOLS / 2; _curRow = GROWS / 2;

        // Spawn balls: 2 + level
        var numBalls = 1 + _level;
        if (numBalls > 8) { numBalls = 8; }
        _balls = new [numBalls];

        var speedBase = 4 + _level;
        if (speedBase > 9) { speedBase = 9; }

        for (var i = 0; i < numBalls; i++) {
            var bx = (5 + Math.rand().abs() % (GCOLS - 10)) * 10;
            var by = (5 + Math.rand().abs() % (GROWS - 10)) * 10;
            var vx = (Math.rand().abs() % 2 == 0) ? speedBase : -speedBase;
            var vy = (Math.rand().abs() % 2 == 0) ? speedBase : -speedBase;
            _balls[i] = [bx, by, vx, vy, _ballColors[i % _ballColors.size()]];
        }

        // Wall grow speed: faster on higher levels
        _growSpeed = 4 - (_level / 3);
        if (_growSpeed < 1) { _growSpeed = 1; }
    }

    // ── Rendering ─────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeo(); }
        if (_gs == JB_MENU)    { drawMenu(dc); return; }
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

        // Decorative bouncing dots
        var dotColors = [0xFF4422, 0xFF8800, 0x44FF88, 0x44AAFF, 0xFF44AA];
        var dotX = [60, 100, 140, 180, 120];
        var dotY = [60,  90,  60,  90, 110];
        for (var i = 0; i < 5; i++) {
            dc.setColor(dotColors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dotX[i] * _w / 240, dotY[i] * _h / 240, 6);
        }

        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 30 / 100, Graphics.FONT_MEDIUM, "JAZZBALL", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 44 / 100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 56 / 100, Graphics.FONT_XTINY, "Draw walls to", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w/2, _h * 64 / 100, Graphics.FONT_XTINY, "trap the balls!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x557788, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 73 / 100, Graphics.FONT_XTINY, "Tap=place  2x=rotate", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0x44AAFF : 0x2266AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 84 / 100, Graphics.FONT_XTINY, "Tap to play!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Board ─────────────────────────────────────────────────────────────────
    hidden function drawBoard(dc) {
        dc.setColor(0x080C18, 0x080C18); dc.clear();

        // Draw grid cells
        for (var row = 0; row < GROWS; row++) {
            for (var col = 0; col < GCOLS; col++) {
                var cell = _grid[row * GCOLS + col];
                var px = _ox + col * _cs;
                var py = _oy + row * _cs;

                if (cell == CELL_WALL) {
                    dc.setColor(0x2A3D66, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(px, py, _cs, _cs);
                } else if (cell == CELL_GROW_H) {
                    var blink = (_tick % 4 < 2);
                    dc.setColor(blink ? 0x88DDFF : 0x4499CC, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(px, py, _cs, _cs);
                } else if (cell == CELL_GROW_V) {
                    var blink2 = (_tick % 4 < 2);
                    dc.setColor(blink2 ? 0xFFDD88 : 0xCC9944, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(px, py, _cs, _cs);
                }
                // CELL_OPEN: leave dark background
            }
        }

        // Grid border
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
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(px - 1, py - 1, _cs + 2, _cs + 2);

        // Direction indicator (small crosshair line)
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        if (_curHoriz) {
            dc.drawLine(px - 4, py + _cs/2, px + _cs + 4, py + _cs/2);
        } else {
            dc.drawLine(px + _cs/2, py - 4, px + _cs/2, py + _cs + 4);
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
        for (var i = 0; i < _lives; i++) { livesStr = livesStr + "\u25CF"; }
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
        for (var i = 0; i < _lives; i++) { livesStr = livesStr + "\u25CF"; }
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
        dc.drawText(_w/2, _h/2 + 12, Graphics.FONT_XTINY, "Tap \u25BA next level", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x060810, 0x060810); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0C1220, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);

        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 25 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 44 / 100, Graphics.FONT_XTINY, "Reached level " + _level, Graphics.TEXT_JUSTIFY_CENTER);
        var filledPct = (_totalCells - _openCount) * 100 / _totalCells;
        dc.drawText(_w/2, _h * 56 / 100, Graphics.FONT_XTINY, "Last fill: " + filledPct + "%", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 10 < 5) ? 0x44AAFF : 0x2266AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 76 / 100, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
