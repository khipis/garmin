using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Application;
using Toybox.Attention;

enum { TBS_MENU, TBS_PLAY, TBS_OVER }

// Power-up types (appear as special falling pieces)
const TB_PU_BOMB    = 1;  // clears all cells in 3×3 area on landing
const TB_PU_LASER   = 2;  // clears the entire column on landing
const TB_PU_FREEZE  = 3;  // next 8 drops are slowed to minimum speed
const TB_PU_SMASH   = 4;  // destroys bottom 2 rows instantly
const TB_PU_COLOR   = 5;  // clears all cells of the same color

const TB_COLS  = 10;
const TB_ROWS  = 18;
const TB_PART  = 14;   // particle count

// Piece shapes: each is 4 rotations × 4 cells [col, row] offsets
// Pieces: I, O, T, S, Z, J, L
const TB_NUM_PIECES = 7;

class BitochiBlocksView extends WatchUi.View {

    var accelX;

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    // Board geometry
    hidden var _cellW; hidden var _cellH;
    hidden var _boardX; hidden var _boardY;  // top-left pixel of board
    hidden var _panelX;                      // X start of right info panel

    // Board: 0 = empty, 1-7 = piece color index, 8+ = power-up marker
    hidden var _board;   // [TB_ROWS][TB_COLS]

    // Current piece
    hidden var _pieceType;   // 0-6 = normal, 7+ = power-up type
    hidden var _pieceRot;
    hidden var _pieceX;      // col of pivot
    hidden var _pieceY;      // row of pivot
    hidden var _isPowerup;   // current piece is a power-up

    // Next piece
    hidden var _nextType;
    hidden var _nextIsPu;

    // Fall timing
    hidden var _fallInterval;  // ticks per row drop
    hidden var _fallCount;
    hidden var _softDrop;
    hidden var _freezeTicks;   // freeze power-up countdown

    // Scoring
    hidden var _score; hidden var _best;
    hidden var _level; hidden var _linesCleared;
    hidden var _combo;

    // Effects
    hidden var _shakeTick; hidden var _shakeX; hidden var _shakeY;
    hidden var _flashTick; hidden var _flashColor;
    hidden var _clearRows;  // array of rows being cleared (animation)
    hidden var _clearAnim;  // countdown

    // Particles
    hidden var _prtX; hidden var _prtY;
    hidden var _prtVx; hidden var _prtVy;
    hidden var _prtLife; hidden var _prtCol;

    // Accel
    hidden var _smoothAx;
    hidden var _accelMove;   // fractional accumulator for accel-driven movement
    hidden var _accelCd;

    // Menu animation
    hidden var _wobble;

    // Piece color palette
    hidden var _pieceColors;

    // Piece shape data: [type][rotation][cell] = [dc, dr]
    // Using flat encoding: shapes[type*16 + rot*4 + cell] = [dc, dr]
    hidden var _shapes;

    function initialize() {
        View.initialize();
        accelX = 0;
        _w = 0; _h = 0;
        _tick = 0; _gs = TBS_MENU;
        _panelX = 0;
        _wobble = 0.0;
        _smoothAx = 0.0; _accelMove = 0.0; _accelCd = 0;

        _best = Application.Storage.getValue("blocks_best");
        if (_best == null) { _best = 0; }

        // Board: flat array [row * TB_COLS + col]
        _board = new [TB_ROWS * TB_COLS];
        for (var i = 0; i < TB_ROWS * TB_COLS; i++) { _board[i] = 0; }

        _prtX = new [TB_PART]; _prtY = new [TB_PART];
        _prtVx = new [TB_PART]; _prtVy = new [TB_PART];
        _prtLife = new [TB_PART]; _prtCol = new [TB_PART];
        for (var i = 0; i < TB_PART; i++) { _prtLife[i] = 0; }

        _clearRows = new [4];
        for (var i = 0; i < 4; i++) { _clearRows[i] = -1; }
        _clearAnim = 0;

        _pieceType = 0; _pieceRot = 0; _pieceX = 0; _pieceY = 0;
        _isPowerup = false; _nextType = 0; _nextIsPu = false;
        _fallInterval = 14; _fallCount = 0; _softDrop = false; _freezeTicks = 0;
        _score = 0; _level = 1; _linesCleared = 0; _combo = 0;
        _shakeTick = 0; _shakeX = 0; _shakeY = 0;
        _flashTick = 0; _flashColor = 0;

        // Neon colors per piece type (I O T S Z J L)
        _pieceColors = [
            0x00EEFF,  // I — cyan
            0xFFDD00,  // O — yellow
            0xCC44FF,  // T — purple
            0x44FF44,  // S — green
            0xFF3333,  // Z — red
            0x4477FF,  // J — blue
            0xFF8800   // L — orange
        ];

        // Build shape tables
        buildShapes();
    }

    // ── Shape data ────────────────────────────────────────────────────────────
    // Each piece: 4 rotations, each rotation: array of 4 [dc, dr] offsets
    // Stored as flat array: _shapes[pieceIdx][rot][cell*2 + 0/1]

    hidden function buildShapes() {
        // shapes[piece][rot] = [[dc,dr],[dc,dr],[dc,dr],[dc,dr]]
        // We store as _shapes[piece * 4 * 4 * 2 + rot * 4 * 2 + cell * 2 + axis]
        // Total: 7 * 4 * 4 * 2 = 224 entries
        _shapes = new [7 * 4 * 8];

        // I-piece
        setShape(0, 0, [[-1,0],[0,0],[1,0],[2,0]]);
        setShape(0, 1, [[0,-1],[0,0],[0,1],[0,2]]);
        setShape(0, 2, [[-1,0],[0,0],[1,0],[2,0]]);
        setShape(0, 3, [[0,-1],[0,0],[0,1],[0,2]]);

        // O-piece
        setShape(1, 0, [[0,0],[1,0],[0,1],[1,1]]);
        setShape(1, 1, [[0,0],[1,0],[0,1],[1,1]]);
        setShape(1, 2, [[0,0],[1,0],[0,1],[1,1]]);
        setShape(1, 3, [[0,0],[1,0],[0,1],[1,1]]);

        // T-piece
        setShape(2, 0, [[-1,0],[0,0],[1,0],[0,1]]);
        setShape(2, 1, [[0,-1],[0,0],[1,0],[0,1]]);
        setShape(2, 2, [[-1,0],[0,0],[1,0],[0,-1]]);
        setShape(2, 3, [[0,-1],[0,0],[-1,0],[0,1]]);

        // S-piece
        setShape(3, 0, [[0,0],[1,0],[-1,1],[0,1]]);
        setShape(3, 1, [[0,-1],[0,0],[1,0],[1,1]]);
        setShape(3, 2, [[0,0],[1,0],[-1,1],[0,1]]);
        setShape(3, 3, [[0,-1],[0,0],[1,0],[1,1]]);

        // Z-piece
        setShape(4, 0, [[-1,0],[0,0],[0,1],[1,1]]);
        setShape(4, 1, [[1,-1],[0,0],[1,0],[0,1]]);
        setShape(4, 2, [[-1,0],[0,0],[0,1],[1,1]]);
        setShape(4, 3, [[1,-1],[0,0],[1,0],[0,1]]);

        // J-piece
        setShape(5, 0, [[-1,0],[0,0],[1,0],[-1,1]]);
        setShape(5, 1, [[0,-1],[0,0],[0,1],[1,1]]);
        setShape(5, 2, [[-1,0],[0,0],[1,0],[1,-1]]);
        setShape(5, 3, [[0,-1],[0,0],[0,1],[-1,-1]]);

        // L-piece
        setShape(6, 0, [[-1,0],[0,0],[1,0],[1,1]]);
        setShape(6, 1, [[0,-1],[0,0],[0,1],[1,-1]]);
        setShape(6, 2, [[-1,0],[0,0],[1,0],[-1,-1]]);
        setShape(6, 3, [[0,-1],[0,0],[0,1],[-1,1]]);
    }

    hidden function setShape(piece, rot, cells) {
        var base = (piece * 4 + rot) * 8;
        for (var i = 0; i < 4; i++) {
            _shapes[base + i * 2]     = cells[i][0];
            _shapes[base + i * 2 + 1] = cells[i][1];
        }
    }

    hidden function getCell(piece, rot, cellIdx, axis) {
        var base = (piece * 4 + rot) * 8;
        return _shapes[base + cellIdx * 2 + axis];
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    function onLayout(dc) {}

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 70, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    hidden function setupBoard() {
        if (_w == 0) { return; }
        // HUD strip height.  Text at y≈10 sits in a wide enough safe zone even on
        // the smallest round screens (dy≈120 from centre → safeHalf≈50 → zone ±50px).
        var topBar = 36;
        var botPad = 2;
        var availH = _h - topBar - botPad;

        // Cell size from height (primary driver — fill the screen vertically)
        var cellFromH = availH / TB_ROWS;

        // Cell size cap: board must not be wider than ~44% of screen so the right
        // panel (4 cells) has room alongside it without overlapping screen content.
        var cellFromW = _w * 44 / 100 / TB_COLS;

        _cellH = (cellFromH < cellFromW) ? cellFromH : cellFromW;
        if (_cellH < 5)  { _cellH = 5; }
        if (_cellH > 13) { _cellH = 13; }
        _cellW = _cellH;

        // Centre the BOARD on the screen (not the board+panel group).
        // The panel sits to the right of the board — on a round screen this is
        // in the wider mid-section where there is plenty of horizontal room.
        _boardX = (_w - TB_COLS * _cellW) / 2;
        if (_boardX < 0) { _boardX = 0; }

        _panelX = _boardX + TB_COLS * _cellW + 3;
        _boardY = topBar;
    }

    hidden function startGame() {
        if (_w == 0) { return; }
        setupBoard();

        for (var i = 0; i < TB_ROWS * TB_COLS; i++) { _board[i] = 0; }
        _score = 0; _level = 1; _linesCleared = 0; _combo = 0;
        _fallInterval = 14; _fallCount = 0; _softDrop = false; _freezeTicks = 0;
        _shakeTick = 0; _flashTick = 0; _clearAnim = 0;
        for (var i = 0; i < TB_PART; i++) { _prtLife[i] = 0; }
        for (var i = 0; i < 4; i++) { _clearRows[i] = -1; }
        _accelMove = 0.0; _accelCd = 0;

        _nextType = randPiece(); _nextIsPu = false;
        spawnPiece();
        _gs = TBS_PLAY;
    }

    hidden function randPiece() {
        return (Math.rand() % TB_NUM_PIECES).toNumber();
    }

    // ── Main tick ─────────────────────────────────────────────────────────────

    function onTick() as Void {
        _tick++;
        _wobble += 0.09;

        if (_shakeTick > 0) {
            _shakeTick--;
            _shakeX = (Math.rand() % 5).toNumber() - 2;
            _shakeY = (Math.rand() % 4).toNumber() - 2;
        } else { _shakeX = 0; _shakeY = 0; }

        if (_flashTick > 0) { _flashTick--; }

        _smoothAx = _smoothAx * 0.68 + accelX.toFloat() * 0.32;

        if (_gs == TBS_PLAY) {
            updateParticles();

            // Clear-line animation gate
            if (_clearAnim > 0) {
                _clearAnim--;
                if (_clearAnim == 0) { finishClear(); }
                WatchUi.requestUpdate();
                return;
            }

            // Accel-driven horizontal movement
            if (_accelCd > 0) { _accelCd--; }
            if (_accelCd == 0) {
                var ax = _smoothAx;
                var deadzone = 260.0;
                if (ax > deadzone) {
                    if (tryMove(1, 0)) { _accelCd = 4; }
                } else if (ax < -deadzone) {
                    if (tryMove(-1, 0)) { _accelCd = 4; }
                }
            }

            // Gravity
            if (_freezeTicks > 0) { _freezeTicks--; }
            var interval = _fallInterval;
            if (_softDrop) { interval = 2; }
            if (_freezeTicks > 0) { interval = 99; }

            _fallCount++;
            if (_fallCount >= interval) {
                _fallCount = 0;
                _softDrop = false;
                if (!tryMove(0, 1)) {
                    lockPiece();
                }
            }
        }

        WatchUi.requestUpdate();
    }

    // ── Movement + rotation ───────────────────────────────────────────────────

    hidden function tryMove(dc, dr) {
        var nx = _pieceX + dc; var ny = _pieceY + dr;
        if (collides(_pieceType, _pieceRot, nx, ny)) { return false; }
        _pieceX = nx; _pieceY = ny;
        return true;
    }

    hidden function collides(pType, pRot, px, py) {
        var realType = pType;
        if (_isPowerup) { realType = 0; }  // power-up uses I-shape single cell
        for (var i = 0; i < 4; i++) {
            var cc = px + getCell(realType, pRot, i, 0);
            var cr = py + getCell(realType, pRot, i, 1);
            if (cc < 0 || cc >= TB_COLS || cr >= TB_ROWS) { return true; }
            if (cr >= 0 && _board[cr * TB_COLS + cc] != 0) { return true; }
        }
        return false;
    }

    function doRotate() {
        if (_gs != TBS_PLAY || _isPowerup) { return; }
        var nr = (_pieceRot + 1) % 4;
        if (!collides(_pieceType, nr, _pieceX, _pieceY)) {
            _pieceRot = nr;
        } else if (!collides(_pieceType, nr, _pieceX - 1, _pieceY)) {
            _pieceX--; _pieceRot = nr;
        } else if (!collides(_pieceType, nr, _pieceX + 1, _pieceY)) {
            _pieceX++; _pieceRot = nr;
        }
    }

    function doSoftDrop() {
        if (_gs == TBS_PLAY) { _softDrop = true; }
    }

    function doHardDrop() {
        if (_gs != TBS_PLAY) { return; }
        var dropped = 0;
        while (tryMove(0, 1)) { dropped++; }
        _score += dropped * 2;
        lockPiece();
    }

    function doAction() {
        if (_gs == TBS_MENU) { startGame(); }
        else if (_gs == TBS_PLAY) { doRotate(); }
        else if (_gs == TBS_OVER) { _gs = TBS_MENU; }
    }

    function doBack() {
        if (_gs == TBS_PLAY) { _gs = TBS_MENU; }
        else if (_gs == TBS_OVER) { _gs = TBS_MENU; }
    }

    function isPlaying() { return _gs == TBS_PLAY; }

    // ── Locking + line clear ──────────────────────────────────────────────────

    hidden function lockPiece() {
        if (_isPowerup) {
            activatePowerup(_pieceType);
            spawnPiece();
            return;
        }

        var color = _pieceType + 1;
        for (var i = 0; i < 4; i++) {
            var cc = _pieceX + getCell(_pieceType, _pieceRot, i, 0);
            var cr = _pieceY + getCell(_pieceType, _pieceRot, i, 1);
            if (cr >= 0 && cr < TB_ROWS && cc >= 0 && cc < TB_COLS) {
                _board[cr * TB_COLS + cc] = color;
            }
        }

        // Check for full rows
        var numCleared = 0;
        for (var i = 0; i < 4; i++) { _clearRows[i] = -1; }
        for (var r = 0; r < TB_ROWS; r++) {
            var full = true;
            for (var c = 0; c < TB_COLS; c++) {
                if (_board[r * TB_COLS + c] == 0) { full = false; break; }
            }
            if (full && numCleared < 4) {
                _clearRows[numCleared] = r;
                numCleared++;
            }
        }

        if (numCleared > 0) {
            _combo++;
            var pts = [0, 100, 300, 500, 800][numCleared] * _level;
            if (_combo > 1) { pts = pts + _combo * 50; }
            _score += pts;
            _linesCleared += numCleared;

            // Level up every 10 lines
            var newLevel = 1 + _linesCleared / 10;
            if (newLevel > _level) {
                _level = newLevel;
                _fallInterval = 14 - _level;
                if (_fallInterval < 3) { _fallInterval = 3; }
                startShake(6);
                _flashColor = 0xFFFF44;
                _flashTick = 8;
            }

            startShake(4);
            spawnLineClearParticles(numCleared);
            _clearAnim = 6;
            doVibe(numCleared > 1 ? 1 : 0);
        } else {
            _combo = 0;
        }

        // Check game over
        for (var c = 0; c < TB_COLS; c++) {
            if (_board[c] != 0) {
                endGame(); return;
            }
        }

        spawnPiece();
    }

    hidden function finishClear() {
        // Remove cleared rows from top to bottom order
        for (var k = 0; k < 4; k++) {
            var r = _clearRows[k];
            if (r < 0) { continue; }
            // Shift everything above down
            for (var row = r; row > 0; row--) {
                for (var col = 0; col < TB_COLS; col++) {
                    _board[row * TB_COLS + col] = _board[(row - 1) * TB_COLS + col];
                }
            }
            for (var col = 0; col < TB_COLS; col++) { _board[col] = 0; }
            // Adjust remaining clear row indices
            for (var j = k + 1; j < 4; j++) {
                if (_clearRows[j] > r) { _clearRows[j]--; }
            }
        }
        for (var i = 0; i < 4; i++) { _clearRows[i] = -1; }
        spawnPiece();
    }

    // ── Power-up activation ───────────────────────────────────────────────────

    hidden function activatePowerup(puType) {
        doVibe(1);
        if (puType == TB_PU_BOMB) {
            // Clear 3×3 around landing position
            for (var dr = -1; dr <= 1; dr++) {
                for (var dc = -1; dc <= 1; dc++) {
                    var br = _pieceY + dr; var bc = _pieceX + dc;
                    if (br >= 0 && br < TB_ROWS && bc >= 0 && bc < TB_COLS) {
                        if (_board[br * TB_COLS + bc] != 0) {
                            spawnCellParticle(bc, br, 0xFF4400);
                            _board[br * TB_COLS + bc] = 0;
                        }
                    }
                }
            }
            startShake(5);
        } else if (puType == TB_PU_LASER) {
            // Clear entire column
            for (var r = 0; r < TB_ROWS; r++) {
                if (_board[r * TB_COLS + _pieceX] != 0) {
                    spawnCellParticle(_pieceX, r, 0xFF2299);
                    _board[r * TB_COLS + _pieceX] = 0;
                }
            }
            _flashColor = 0xFF44AA;
            _flashTick = 6;
        } else if (puType == TB_PU_FREEZE) {
            _freezeTicks = 80;
            _flashColor = 0x44CCFF;
            _flashTick = 5;
        } else if (puType == TB_PU_SMASH) {
            // Destroy bottom 2 rows
            for (var r = TB_ROWS - 2; r < TB_ROWS; r++) {
                for (var c = 0; c < TB_COLS; c++) {
                    if (_board[r * TB_COLS + c] != 0) {
                        spawnCellParticle(c, r, 0xFFAA00);
                        _board[r * TB_COLS + c] = 0;
                    }
                }
            }
            startShake(6);
            _score += 50 * _level;
        } else if (puType == TB_PU_COLOR) {
            // Find color at landing pos and clear all of same color
            var target = (_board[_pieceY * TB_COLS + _pieceX] > 0)
                ? _board[_pieceY * TB_COLS + _pieceX]
                : 1 + (Math.rand() % TB_NUM_PIECES).toNumber();
            var cleared = 0;
            for (var r = 0; r < TB_ROWS; r++) {
                for (var c = 0; c < TB_COLS; c++) {
                    if (_board[r * TB_COLS + c] == target) {
                        spawnCellParticle(c, r, _pieceColors[target - 1]);
                        _board[r * TB_COLS + c] = 0;
                        cleared++;
                    }
                }
            }
            _score += cleared * 20 * _level;
            startShake(4);
        }
    }

    // ── Spawn logic ───────────────────────────────────────────────────────────

    hidden function spawnPiece() {
        _pieceType = _nextType;
        _isPowerup  = _nextIsPu;
        _pieceRot  = 0;
        _pieceX    = TB_COLS / 2;
        _pieceY    = 0;
        _fallCount = 0;

        // Pick next — 15% chance of power-up after level 2
        var puChance = (_level >= 2) ? 15 : 0;
        if ((Math.rand() % 100).toNumber() < puChance) {
            _nextIsPu  = true;
            _nextType  = 1 + (Math.rand() % 5).toNumber();
        } else {
            _nextIsPu  = false;
            _nextType  = randPiece();
        }

        // Immediate game-over check
        if (collides(_isPowerup ? 0 : _pieceType, _pieceRot, _pieceX, _pieceY)) {
            endGame();
        }
    }

    hidden function endGame() {
        _gs = TBS_OVER;
        if (_score > _best) {
            _best = _score;
            Application.Storage.setValue("blocks_best", _best);
        }
        doVibe(2);
    }

    // ── Particles ─────────────────────────────────────────────────────────────

    hidden function spawnCellParticle(col, row, color) {
        var px = _boardX + col * _cellW + _cellW / 2 + _shakeX;
        var py = _boardY + row * _cellH + _cellH / 2 + _shakeY;
        for (var i = 0; i < TB_PART; i++) {
            if (_prtLife[i] == 0) {
                _prtX[i] = px.toFloat();
                _prtY[i] = py.toFloat();
                var ang = (Math.rand() % 628).toFloat() / 100.0;
                var spd = 0.6 + (Math.rand() % 16).toFloat() * 0.1;
                _prtVx[i] = Math.cos(ang) * spd;
                _prtVy[i] = Math.sin(ang) * spd - 1.0;
                _prtLife[i] = 7 + (Math.rand() % 6).toNumber();
                _prtCol[i] = color;
                return;
            }
        }
    }

    hidden function spawnLineClearParticles(numLines) {
        for (var k = 0; k < 4; k++) {
            if (_clearRows[k] < 0) { continue; }
            var r = _clearRows[k];
            var col = _pieceColors[(_tick % TB_NUM_PIECES).toNumber()];
            for (var c = 0; c < TB_COLS; c += 2) {
                spawnCellParticle(c, r, col);
            }
        }
    }

    hidden function updateParticles() {
        for (var i = 0; i < TB_PART; i++) {
            if (_prtLife[i] > 0) {
                _prtLife[i]--;
                _prtX[i] = _prtX[i] + _prtVx[i];
                _prtY[i] = _prtY[i] + _prtVy[i];
                _prtVy[i] = _prtVy[i] + 0.22;
            }
        }
    }

    hidden function startShake(dur) {
        _shakeTick = dur;
    }

    hidden function doVibe(pat) {
        if (Toybox has :Attention) {
            if (Attention has :vibrate) {
                var dur = (pat == 0) ? 20 : ((pat == 1) ? 60 : 160);
                Attention.vibrate([new Attention.VibeProfile(80, dur)]);
            }
        }
    }

    // ── Rendering ─────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupBoard(); }

        if (_gs == TBS_MENU)     { drawMenu(dc); }
        else if (_gs == TBS_PLAY){ drawGame(dc); }
        else                     { drawOver(dc); }
    }

    // ── Menu ─────────────────────────────────────────────────────────────────

    hidden function drawMenu(dc) {
        dc.setColor(0x07101C, 0x07101C); dc.clear();

        // Animated falling-blocks deco
        var t = _wobble;
        var colors = [0x00EEFF, 0xFFDD00, 0xCC44FF, 0x44FF44, 0xFF3333, 0x4477FF, 0xFF8800];
        for (var i = 0; i < 7; i++) {
            var bx = _w * (10 + i * 12) / 100;
            var by = (_h * 18 / 100 + (Math.sin(t + i.toFloat() * 0.9) * 14.0).toNumber()).toNumber();
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx - 5, by - 5, 11, 11, 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 2, by - 2, 3, 3);
        }

        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 38 / 100, Graphics.FONT_MEDIUM, "BLOCKS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 52 / 100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        // Controls hint (centered — safe on all round screens)
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 60 / 100, Graphics.FONT_XTINY, "Tilt: move  |  Tap: rotate", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 70 / 100, Graphics.FONT_XTINY, "Hold: drop", Graphics.TEXT_JUSTIFY_CENTER);

        if (_best > 0) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 79 / 100, Graphics.FONT_XTINY, "Best: " + _best, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 12 < 6) ? 0x88CCFF : 0x4488BB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 89 / 100, Graphics.FONT_XTINY, "Tap to play!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game screen ──────────────────────────────────────────────────────────

    hidden function drawGame(dc) {
        dc.setColor(0x060F1A, 0x060F1A); dc.clear();

        var ox = _shakeX; var oy = _shakeY;

        // Flash overlay
        if (_flashTick > 0) {
            dc.setColor(_flashColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, _w, _h);
            dc.setColor(0x060F1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(1, 1, _w - 2, _h - 2);
        }

        // Board background + border
        var bx = _boardX + ox; var by = _boardY + oy;
        var bw = TB_COLS * _cellW; var bh = TB_ROWS * _cellH;
        dc.setColor(0x0A1A28, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, by, bw, bh);

        // Freeze overlay
        if (_freezeTicks > 0) {
            dc.setColor(0x1A4466, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, by, bw, bh);
        }

        // Grid lines (very faint)
        dc.setColor(0x0D1E2E, Graphics.COLOR_TRANSPARENT);
        for (var c = 0; c <= TB_COLS; c++) {
            dc.drawLine(bx + c * _cellW, by, bx + c * _cellW, by + bh);
        }
        for (var r = 0; r <= TB_ROWS; r++) {
            dc.drawLine(bx, by + r * _cellH, bx + bw, by + r * _cellH);
        }

        // Draw locked cells
        for (var r = 0; r < TB_ROWS; r++) {
            // Flashing clear-row animation
            var isClearRow = false;
            if (_clearAnim > 0) {
                for (var k = 0; k < 4; k++) {
                    if (_clearRows[k] == r) { isClearRow = true; break; }
                }
            }
            if (isClearRow && _tick % 3 < 2) { continue; }

            for (var c = 0; c < TB_COLS; c++) {
                var v = _board[r * TB_COLS + c];
                if (v == 0) { continue; }
                drawCell(dc, bx + c * _cellW, by + r * _cellH, _pieceColors[v - 1]);
            }
        }

        // Ghost piece (landing preview)
        if (!_isPowerup) {
            drawGhost(dc, ox, oy);
        }

        // Active piece
        drawActivePiece(dc, ox, oy);

        // Particles
        for (var i = 0; i < TB_PART; i++) {
            if (_prtLife[i] > 0) {
                dc.setColor(_prtCol[i], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_prtX[i].toNumber(), _prtY[i].toNumber(), 2, 2);
            }
        }

        // Board border
        var borderC = _freezeTicks > 0 ? 0x44CCFF :
                      (_flashTick > 0  ? _flashColor : 0x1A3A5A);
        dc.setColor(borderC, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(bx - 1, by - 1, bw + 2, bh + 2);

        // HUD panel
        drawHUD(dc, ox, oy);
    }

    hidden function drawCell(dc, px, py, color) {
        var cw = _cellW; var ch = _cellH;
        // Fill
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px + 1, py + 1, cw - 2, ch - 2);
        // Bright top-left highlight (neon glow effect)
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(px + 1, py + 1, px + cw - 2, py + 1);
        dc.drawLine(px + 1, py + 1, px + 1, py + ch - 2);
        // Dark bottom-right shadow
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(px + 1, py + ch - 2, px + cw - 2, py + ch - 2);
        dc.drawLine(px + cw - 2, py + 1, px + cw - 2, py + ch - 2);
    }

    hidden function drawGhost(dc, ox, oy) {
        var gy = _pieceY;
        while (!collides(_pieceType, _pieceRot, _pieceX, gy + 1)) { gy++; }
        if (gy == _pieceY) { return; }
        var gc = _pieceColors[_pieceType];
        dc.setColor(gc & 0x444444, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var cc = _pieceX + getCell(_pieceType, _pieceRot, i, 0);
            var cr = gy + getCell(_pieceType, _pieceRot, i, 1);
            if (cr >= 0 && cr < TB_ROWS) {
                var px2 = _boardX + ox + cc * _cellW;
                var py2 = _boardY + oy + cr * _cellH;
                dc.drawRectangle(px2 + 1, py2 + 1, _cellW - 2, _cellH - 2);
            }
        }
    }

    hidden function drawActivePiece(dc, ox, oy) {
        var col; var pType;
        if (_isPowerup) {
            col = puColor(_pieceType);
            pType = 0;  // single-cell: use I-shape first cell
        } else {
            col = _pieceColors[_pieceType];
            pType = _pieceType;
        }

        if (_isPowerup) {
            // Power-up: animated single pulsing cell with symbol
            var blink = (_tick % 8 < 4) ? 1 : 0;
            var px2 = _boardX + ox + _pieceX * _cellW;
            var py2 = _boardY + oy + _pieceY * _cellH;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(px2, py2, _cellW + blink, _cellH + blink, 2);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(px2 + _cellW / 2, py2 + _cellH / 2 - 6, Graphics.FONT_XTINY,
                puSymbol(_pieceType), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            for (var i = 0; i < 4; i++) {
                var cc = _pieceX + getCell(pType, _pieceRot, i, 0);
                var cr = _pieceY + getCell(pType, _pieceRot, i, 1);
                if (cr >= 0 && cr < TB_ROWS && cc >= 0 && cc < TB_COLS) {
                    drawCell(dc, _boardX + ox + cc * _cellW, _boardY + oy + cr * _cellH, col);
                }
            }
        }
    }

    // ── HUD panel ─────────────────────────────────────────────────────────────
    // Top strip (22px): Score | Lv | Lines
    // Right panel (always visible, guaranteed to fit by setupBoard):
    //   NXT label → next piece preview → level progress bar → combo/freeze

    hidden function drawHUD(dc, ox, oy) {
        // ── Top bar: score + level, both centred at screen midpoint ──────────────
        // At y≈10 the safe zone is ±50px from centre — wide enough for all values.
        dc.setColor(0x0A1A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _boardY);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, 10, Graphics.FONT_XTINY, "Lv" + _level, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 3, 10, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_LEFT);

        // ── Right panel ───────────────────────────────────────────────────────────
        // Content starts at boardY+8 (y≈36) where the round screen is already wide
        // enough that even 4-cell-wide content clears the circle edge.
        var px  = _panelX;
        var pw  = 4 * _cellW;
        var py  = _boardY + oy;

        // "NXT" label
        dc.setColor(0x3A5870, Graphics.COLOR_TRANSPARENT);
        dc.drawText(px + pw / 2, py + 8, Graphics.FONT_XTINY, "NXT", Graphics.TEXT_JUSTIFY_CENTER);

        // Next piece preview (full-size cells)
        drawNextPreview(dc, px, py + 22);

        // Lines-to-next-level progress bar
        var barY     = py + 22 + _cellH * 2 + 6;
        var barW     = pw;
        var linesMod = _linesCleared % 10;
        dc.setColor(0x0E2030, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px, barY, barW, 5);
        dc.setColor(0x2288CC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px, barY, barW * linesMod / 10, 5);
        dc.setColor(0x1A4060, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(px, barY, barW, 5);

        // Lines + next-level hint
        dc.setColor(0x446677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(px + pw / 2, barY + 7, Graphics.FONT_XTINY,
            _linesCleared + "L >" + (_level + 1), Graphics.TEXT_JUSTIFY_CENTER);

        // Combo
        var extraY = barY + 21;
        if (_combo > 1) {
            dc.setColor((_tick % 6 < 3) ? 0xFFFF44 : 0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(px + pw / 2, extraY, Graphics.FONT_XTINY,
                "x" + _combo, Graphics.TEXT_JUSTIFY_CENTER);
            extraY += 13;
        }
        // Freeze
        if (_freezeTicks > 0) {
            dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(px + pw / 2, extraY, Graphics.FONT_XTINY,
                "ICE", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawNextPreview(dc, nx, ny) {
        if (_nextIsPu) {
            var pc = puColor(_nextType);
            dc.setColor(pc, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(nx, ny, _cellW, _cellH, 2);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(nx + _cellW / 2, ny + _cellH / 2 - 6, Graphics.FONT_XTINY,
                puSymbol(_nextType), Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var previewCol = _pieceColors[_nextType];
        dc.setColor(previewCol, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var dc2 = getCell(_nextType, 0, i, 0);
            var dr2 = getCell(_nextType, 0, i, 1);
            var px2 = nx + (dc2 + 1) * (_cellW - 1);
            var py2 = ny + (dr2 + 1) * (_cellH - 1);
            dc.fillRectangle(px2, py2, _cellW - 2, _cellH - 2);
        }
    }

    // ── Game over ────────────────────────────────────────────────────────────

    hidden function drawOver(dc) {
        dc.setColor(0x060F1A, 0x060F1A); dc.clear();

        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 10 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_LARGE, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x446677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 46 / 100, Graphics.FONT_XTINY, "SCORE", Graphics.TEXT_JUSTIFY_CENTER);

        if (_score >= _best && _score > 0) {
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, _h * 55 / 100 - 1, _w, 18);
            dc.setColor((_tick % 8 < 4) ? 0xFFDD22 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 55 / 100, Graphics.FONT_XTINY, "★ NEW BEST! ★", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_best > 0) {
            dc.setColor(0x446677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 55 / 100, Graphics.FONT_XTINY, "Best: " + _best, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 67 / 100, Graphics.FONT_XTINY,
            "Lv " + _level + "  |  " + _linesCleared + " lines", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 12 < 6) ? 0x44AAFF : 0x2277CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 87 / 100, Graphics.FONT_XTINY, "Tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Power-up helpers ─────────────────────────────────────────────────────

    hidden function puColor(t) {
        if (t == TB_PU_BOMB)   { return 0xFF5500; }
        if (t == TB_PU_LASER)  { return 0xFF22BB; }
        if (t == TB_PU_FREEZE) { return 0x44CCFF; }
        if (t == TB_PU_SMASH)  { return 0xFFAA00; }
        if (t == TB_PU_COLOR)  { return 0x44FF88; }
        return 0xFFFFFF;
    }

    hidden function puSymbol(t) {
        if (t == TB_PU_BOMB)   { return "B"; }
        if (t == TB_PU_LASER)  { return "L"; }
        if (t == TB_PU_FREEZE) { return "F"; }
        if (t == TB_PU_SMASH)  { return "S"; }
        if (t == TB_PU_COLOR)  { return "C"; }
        return "?";
    }
}
