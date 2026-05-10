using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.System;

const CK_EMPTY = 0;
const CK_WHITE = 1;
const CK_WKING = 2;
const CK_BLACK = 3;
const CK_BKING = 4;

const GS_MENU     = 0;
const GS_PLAY     = 1;
const GS_AI_THINK = 2;
const GS_WIN      = 3;
const GS_LOSE     = 4;
const GS_DRAW     = 5;
const GS_AI_EVAL  = 6;

class BitochiCheckersView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    hidden var _board;
    hidden var _whiteTurn;

    hidden var _selRow; hidden var _selCol;
    hidden var _curRow; hidden var _curCol;
    hidden var _validDsts;

    hidden var _mustRow; hidden var _mustCol;

    hidden var _aiDelay;
    hidden var _difficulty;

    hidden var _ox; hidden var _oy; hidden var _sq;
    hidden var _playerIsWhite;
    hidden var _aiVsAi;
    hidden var _pvp;

    hidden var _menuRow;

    hidden var _dirsKing; hidden var _dirsWhite; hidden var _dirsBlack;

    hidden const AI_MAX = 48;
    hidden var _aiW;
    hidden var _aiMvN; hidden var _aiMvI;
    hidden var _aiBestS; hidden var _aiBestI;
    hidden var _aiFR; hidden var _aiFC;
    hidden var _aiTR; hidden var _aiTC;
    hidden var _aiCR; hidden var _aiCC;
    hidden var _aiPc;
    hidden var _mmN; hidden var _mmLimit;

    // ═══════════════════════════════════════════════════════════════════════════
    //  INITIALIZE
    // ═══════════════════════════════════════════════════════════════════════════

    function initialize() {
        View.initialize();
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _tick = 0;
        _gs = GS_MENU; _difficulty = 1;
        _playerIsWhite = true; _aiVsAi = false; _pvp = false;
        _selRow = -1; _selCol = -1;
        _mustRow = -1; _mustCol = -1;
        _curRow = 2; _curCol = 1;
        _validDsts = new [0];
        _board = new [64];
        for (var i = 0; i < 64; i++) { _board[i] = CK_EMPTY; }
        _sq = 0; _ox = 0; _oy = 0;
        _menuRow = 0;

        _dirsKing  = [[-1,-1],[-1,1],[1,-1],[1,1]];
        _dirsWhite = [[1,-1],[1,1]];
        _dirsBlack = [[-1,-1],[-1,1]];

        _aiFR = new [AI_MAX]; _aiFC = new [AI_MAX];
        _aiTR = new [AI_MAX]; _aiTC = new [AI_MAX];
        _aiCR = new [AI_MAX]; _aiCC = new [AI_MAX];
        _aiPc = new [AI_MAX];

        resetBoard();
        setupGeo();
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 200, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupGeo();
    }

    hidden function setupGeo() {
        _sq = _w * 74 / 100 / 8;
        if (_sq > _h * 74 / 100 / 8) { _sq = _h * 74 / 100 / 8; }
        // On round/square screens ensure board corners fit within the circular display
        if (_w == _h) {
            var sqMax = _w / 12;
            if (_sq > sqMax) { _sq = sqMax; }
        }
        if (_sq < 1) { _sq = 1; }
        _ox = (_w - _sq * 8) / 2;
        _oy = (_h - _sq * 8) / 2 + 2;
    }

    hidden function resetBoard() {
        for (var i = 0; i < 64; i++) { _board[i] = CK_EMPTY; }
        for (var r = 5; r <= 7; r++) {
            for (var c = 0; c < 8; c++) {
                if ((r + c) % 2 == 1) { _board[r * 8 + c] = CK_BLACK; }
            }
        }
        for (var r = 0; r <= 2; r++) {
            for (var c = 0; c < 8; c++) {
                if ((r + c) % 2 == 1) { _board[r * 8 + c] = CK_WHITE; }
            }
        }
        _whiteTurn = true;
        _selRow = -1; _selCol = -1;
        _mustRow = -1; _mustCol = -1;
        _validDsts = new [0];
    }

    function onTick() as Void {
        _tick++;
        if (_gs == GS_AI_THINK) {
            _aiDelay--;
            if (_aiDelay <= 0) { _doAiGen(); }
        } else if (_gs == GS_AI_EVAL) {
            _doAiEval();
        }
        WatchUi.requestUpdate();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  SMART CURSOR INPUT
    //  Buttons cycle through own pieces (no selection) or valid destinations
    //  (piece selected). Works perfectly with 2-button Garmin watches.
    // ═══════════════════════════════════════════════════════════════════════════

    function doNext() {
        if (_gs == GS_MENU) { _menuRow = (_menuRow + 1) % 4; return; }
        if (_gs == GS_WIN || _gs == GS_LOSE || _gs == GS_DRAW) { return; }
        if (_gs != GS_PLAY) { return; }
        if (!isPlayerTurn()) { return; }
        if (_selRow >= 0) { cycleTarget(1); }
        else { cyclePiece(1); }
    }

    function doPrev() {
        if (_gs == GS_MENU) { _menuRow = (_menuRow + 3) % 4; return; }
        if (_gs == GS_WIN || _gs == GS_LOSE || _gs == GS_DRAW) { return; }
        if (_gs != GS_PLAY) { return; }
        if (!isPlayerTurn()) { return; }
        if (_selRow >= 0) { cycleTarget(-1); }
        else { cyclePiece(-1); }
    }

    hidden function isPlayerTurn() {
        return _pvp || (_playerIsWhite ? _whiteTurn : !_whiteTurn);
    }

    hidden function isPlayerPiece(p) {
        var white = _pvp ? _whiteTurn : _playerIsWhite;
        return white ? (p == CK_WHITE || p == CK_WKING)
                     : (p == CK_BLACK || p == CK_BKING);
    }

    hidden function cyclePiece(dir) {
        // For white the board is y-flipped on screen, so invert the walk direction
        // so that pressing "next/down" visually moves the cursor downward on screen.
        var d = _playerIsWhite ? -dir : dir;
        var startIdx = _curRow * 8 + _curCol;
        for (var i = 1; i <= 64; i++) {
            var idx = (startIdx + i * d + 64) % 64;
            var r = idx / 8; var c = idx % 8;
            if ((r + c) % 2 != 1) { continue; }
            var p = _board[idx];
            if (!isPlayerPiece(p)) { continue; }
            if (_mustRow >= 0 && (r != _mustRow || c != _mustCol)) { continue; }
            var moves = getMovesFor(r, c, p, _mustRow >= 0);
            if (moves.size() > 0) { _curRow = r; _curCol = c; return; }
        }
    }

    hidden function cycleTarget(dir) {
        if (_validDsts.size() == 0) { return; }
        var curIdx = -1;
        for (var i = 0; i < _validDsts.size(); i++) {
            if (_validDsts[i][0] == _curRow && _validDsts[i][1] == _curCol) { curIdx = i; break; }
        }
        if (curIdx < 0) { curIdx = 0; }
        else { curIdx = (curIdx + dir + _validDsts.size()) % _validDsts.size(); }
        _curRow = _validDsts[curIdx][0];
        _curCol = _validDsts[curIdx][1];
    }

    function doSelect() {
        if (_gs == GS_MENU) {
            if (_menuRow == 0) { _playerIsWhite = !_playerIsWhite; }
            else if (_menuRow == 1) { _difficulty = (_difficulty + 1) % 3; }
            else if (_menuRow == 2) {
                if (!_aiVsAi && !_pvp) { _pvp = true; }
                else if (_pvp) { _pvp = false; _aiVsAi = true; }
                else { _aiVsAi = false; }
            }
            else { startGame(); }
            return;
        }
        if (_gs == GS_WIN || _gs == GS_LOSE || _gs == GS_DRAW) { _gs = GS_MENU; return; }
        if (_aiVsAi) { return; }
        if (_gs != GS_PLAY) { return; }
        if (!isPlayerTurn()) { return; }

        if (_selRow < 0) {
            var p = _board[_curRow * 8 + _curCol];
            if (!isPlayerPiece(p)) { return; }
            if (_mustRow >= 0 && (_curRow != _mustRow || _curCol != _mustCol)) { return; }
            var moves = getMovesFor(_curRow, _curCol, p, _mustRow >= 0);
            if (moves.size() > 0) {
                _selRow = _curRow; _selCol = _curCol;
                _validDsts = moves;
                _curRow = moves[0][0]; _curCol = moves[0][1];
            }
        } else {
            var moved = false;
            for (var i = 0; i < _validDsts.size(); i++) {
                var mv = _validDsts[i];
                if (mv[0] == _curRow && mv[1] == _curCol) {
                    applyPlayerMove(mv);
                    moved = true; break;
                }
            }
            if (!moved) {
                _selRow = -1; _selCol = -1; _validDsts = new [0];
            }
        }
    }

    function doDeselect() {
        if (_gs == GS_PLAY && _selRow >= 0 && _mustRow < 0) {
            var prevR = _selRow; var prevC = _selCol;
            _selRow = -1; _selCol = -1; _validDsts = new [0];
            _curRow = prevR; _curCol = prevC;
        }
    }

    function doBack() {
        if (_gs == GS_PLAY && _selRow >= 0 && _mustRow < 0) {
            doDeselect();
            return true;
        }
        if (_gs != GS_MENU) {
            _gs = GS_MENU; _selRow = -1; _selCol = -1;
            _validDsts = new [0]; _mustRow = -1; _mustCol = -1;
            return true;
        }
        return false;
    }

    function doTap(tx, ty) {
        if (_gs == GS_MENU) {
            // Recalculate row positions identical to drawMenu
            var rowH  = _h * 14 / 100; if (rowH < 26) { rowH = 26; } if (rowH > 38) { rowH = 38; }
            var rowW  = _w * 78 / 100;
            var rowX  = (_w - rowW) / 2;
            var gap   = _h * 2 / 100; if (gap < 4) { gap = 4; }
            var nRows = 4;
            var total = nRows * rowH + (nRows - 1) * gap;
            var rowY0 = (_h - total) / 2 + rowH;
            for (var i = 0; i < nRows; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (tx >= rowX && tx < rowX + rowW && ty >= ry && ty < ry + rowH) {
                    _menuRow = i;
                    if (i == 0) { _playerIsWhite = !_playerIsWhite; }
                    else if (i == 1) { _difficulty = (_difficulty + 1) % 3; }
                    else if (i == 2) {
                        if (!_aiVsAi && !_pvp) { _pvp = true; }
                        else if (_pvp) { _pvp = false; _aiVsAi = true; }
                        else { _aiVsAi = false; }
                    }
                    else { startGame(); }
                    return;
                }
            }
            return;
        }
        if (_gs == GS_WIN || _gs == GS_LOSE || _gs == GS_DRAW) { _gs = GS_MENU; return; }
        if (_gs == GS_AI_THINK || _gs == GS_AI_EVAL || _gs != GS_PLAY) { return; }
        if (_sq <= 0) { return; }

        if (tx < _ox || tx >= _ox + _sq * 8) { return; }
        if (ty < _oy || ty >= _oy + _sq * 8) { return; }
        var col = (tx - _ox) / _sq;
        var rowInv = (ty - _oy) / _sq;
        if (col < 0 || col >= 8 || rowInv < 0 || rowInv >= 8) { return; }

        var row; var realCol;
        if (_playerIsWhite) { row = 7 - rowInv; realCol = col; }
        else { row = rowInv; realCol = 7 - col; }
        _curRow = row; _curCol = realCol;
        handleCell(row, realCol);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  GAME FLOW
    // ═══════════════════════════════════════════════════════════════════════════

    hidden function startGame() {
        resetBoard();
        _menuRow = 0;
        _gs = GS_PLAY;
        if (_aiVsAi) {
            _playerIsWhite = true;
            _whiteTurn = true;
            _curRow = 2; _curCol = 1;
            _gs = GS_AI_THINK; _aiDelay = 1;
        } else if (_playerIsWhite) {
            _whiteTurn = true;
            _curRow = 2; _curCol = 1;
        } else if (!_pvp) {
            _whiteTurn = true;
            _curRow = 5; _curCol = 2;
            _gs = GS_AI_THINK;
            _aiDelay = 1;
        } else {
            _whiteTurn = true;
            _curRow = 2; _curCol = 1;
        }
    }

    // After each AI turn, snap cursor to a valid player piece so it's never stuck
    hidden function snapCursorToValidPiece() {
        // Check if current position is already a valid piece
        if (_curRow >= 0 && _curRow < 8 && _curCol >= 0 && _curCol < 8) {
            var p0 = _board[_curRow * 8 + _curCol];
            if (isPlayerPiece(p0) && getMovesFor(_curRow, _curCol, p0, false).size() > 0) {
                return;
            }
        }
        // Scan for first piece with valid moves
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                if ((r + c) % 2 != 1) { continue; }
                var pp = _board[r * 8 + c];
                if (!isPlayerPiece(pp)) { continue; }
                if (getMovesFor(r, c, pp, false).size() > 0) {
                    _curRow = r; _curCol = c; return;
                }
            }
        }
    }

    hidden function handleCell(row, col) {
        if (!isPlayerTurn()) { return; }
        var piece = _board[row * 8 + col];
        var ownPiece = isPlayerPiece(piece);

        if (_selRow < 0) {
            if (!ownPiece) { return; }
            if (_mustRow >= 0 && (row != _mustRow || col != _mustCol)) { return; }
            var moves = getMovesFor(row, col, piece, _mustRow >= 0);
            if (moves.size() > 0) { _selRow = row; _selCol = col; _validDsts = moves; }
        } else {
            var moved = false;
            for (var i = 0; i < _validDsts.size(); i++) {
                var mv = _validDsts[i];
                if (mv[0] == row && mv[1] == col) {
                    applyPlayerMove(mv);
                    moved = true; break;
                }
            }
            if (!moved) {
                _selRow = -1; _selCol = -1; _validDsts = new [0];
                if (ownPiece) {
                    if (_mustRow >= 0 && (row != _mustRow || col != _mustCol)) { return; }
                    var moves2 = getMovesFor(row, col, piece, _mustRow >= 0);
                    if (moves2.size() > 0) { _selRow = row; _selCol = col; _validDsts = moves2; }
                }
            }
        }
    }

    hidden function applyPlayerMove(mv) {
        var fromR = _selRow; var fromC = _selCol;
        var toR = mv[0]; var toC = mv[1];
        var capR = mv[2]; var capC = mv[3];

        var piece = _board[fromR * 8 + fromC];
        _board[toR * 8 + toC] = piece;
        _board[fromR * 8 + fromC] = CK_EMPTY;
        if (capR >= 0) { _board[capR * 8 + capC] = CK_EMPTY; }

        if (piece == CK_WHITE && toR == 7) { _board[toR * 8 + toC] = CK_WKING; piece = CK_WKING; }
        if (piece == CK_BLACK && toR == 0) { _board[toR * 8 + toC] = CK_BKING; piece = CK_BKING; }

        _selRow = -1; _selCol = -1; _validDsts = new [0];
        _mustRow = -1; _mustCol = -1;

        if (capR >= 0) {
            var moreCaps = getCapturesFor(toR, toC, piece);
            if (moreCaps.size() > 0) {
                _mustRow = toR; _mustCol = toC;
                _selRow = toR; _selCol = toC;
                _validDsts = moreCaps;
                _curRow = moreCaps[0][0]; _curCol = moreCaps[0][1];
                return;
            }
        }

        checkGameOver();
        if (_gs == GS_PLAY) {
            _whiteTurn = !_whiteTurn;
            if (!_pvp) {
                _gs = GS_AI_THINK;
                _aiDelay = 1;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  MOVE GENERATION
    // ═══════════════════════════════════════════════════════════════════════════

    hidden function getMovesFor(row, col, piece, captureOnly) {
        var anyCap = false;
        if (!captureOnly) {
            anyCap = sideHasCapture(piece == CK_WHITE || piece == CK_WKING);
        }
        if (anyCap || captureOnly) { return getCapturesFor(row, col, piece); }
        return getSimpleMovesFor(row, col, piece);
    }

    hidden function sideHasCapture(white) {
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var p = _board[r * 8 + c];
                var mine = white ? (p == CK_WHITE || p == CK_WKING) : (p == CK_BLACK || p == CK_BKING);
                if (!mine) { continue; }
                var isK = (p == CK_WKING || p == CK_BKING);
                if (isK) {
                    for (var d = 0; d < 4; d++) {
                        var dr = _dirsKing[d][0]; var dc = _dirsKing[d][1];
                        var nr = r + dr; var nc = c + dc;
                        while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) {
                            nr += dr; nc += dc;
                        }
                        if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) { continue; }
                        var mid = _board[nr * 8 + nc];
                        var foe = white ? (mid == CK_BLACK || mid == CK_BKING) : (mid == CK_WHITE || mid == CK_WKING);
                        if (!foe) { continue; }
                        var lr = nr + dr; var lc = nc + dc;
                        if (lr >= 0 && lr < 8 && lc >= 0 && lc < 8 && _board[lr * 8 + lc] == CK_EMPTY) { return true; }
                    }
                } else {
                    for (var d = 0; d < 4; d++) {
                        var mr = r + _dirsKing[d][0]; var mc = c + _dirsKing[d][1];
                        var lr = r + _dirsKing[d][0] * 2; var lc = c + _dirsKing[d][1] * 2;
                        if (lr < 0 || lr >= 8 || lc < 0 || lc >= 8) { continue; }
                        if (_board[lr * 8 + lc] != CK_EMPTY) { continue; }
                        var mid = _board[mr * 8 + mc];
                        if (mid == CK_EMPTY) { continue; }
                        var foe = white ? (mid == CK_BLACK || mid == CK_BKING) : (mid == CK_WHITE || mid == CK_WKING);
                        if (foe) { return true; }
                    }
                }
            }
        }
        return false;
    }

    hidden function _hasMoveFor(r, c, piece) {
        var pw = (piece == CK_WHITE || piece == CK_WKING);
        var isK = (piece == CK_WKING || piece == CK_BKING);
        if (isK) {
            for (var d = 0; d < 4; d++) {
                var dr = _dirsKing[d][0]; var dc = _dirsKing[d][1];
                var nr = r + dr; var nc = c + dc;
                if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) { return true; }
                while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) { nr += dr; nc += dc; }
                if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) { continue; }
                var mid = _board[nr * 8 + nc];
                var foe = pw ? (mid == CK_BLACK || mid == CK_BKING) : (mid == CK_WHITE || mid == CK_WKING);
                if (!foe) { continue; }
                var lr = nr + dr; var lc = nc + dc;
                if (lr >= 0 && lr < 8 && lc >= 0 && lc < 8 && _board[lr * 8 + lc] == CK_EMPTY) { return true; }
            }
        } else {
            var dirs = getDirs(piece);
            for (var i = 0; i < dirs.size(); i++) {
                var nr = r + dirs[i][0]; var nc = c + dirs[i][1];
                if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) { return true; }
            }
            for (var d = 0; d < 4; d++) {
                var mr = r + _dirsKing[d][0]; var mc = c + _dirsKing[d][1];
                var lr = r + _dirsKing[d][0] * 2; var lc = c + _dirsKing[d][1] * 2;
                if (lr < 0 || lr >= 8 || lc < 0 || lc >= 8) { continue; }
                if (_board[lr * 8 + lc] != CK_EMPTY) { continue; }
                var mid = _board[mr * 8 + mc];
                if (mid == CK_EMPTY) { continue; }
                var foe = pw ? (mid == CK_BLACK || mid == CK_BKING) : (mid == CK_WHITE || mid == CK_WKING);
                if (foe) { return true; }
            }
        }
        return false;
    }

    hidden function getSimpleMovesFor(row, col, piece) {
        var moves = new [0];
        var isK = (piece == CK_WKING || piece == CK_BKING);
        if (isK) {
            for (var d = 0; d < 4; d++) {
                var dr = _dirsKing[d][0]; var dc = _dirsKing[d][1];
                var nr = row + dr; var nc = col + dc;
                while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) {
                    moves = appendMove(moves, [nr, nc, -1, -1]);
                    nr += dr; nc += dc;
                }
            }
        } else {
            var dirs = getDirs(piece);
            for (var i = 0; i < dirs.size(); i++) {
                var nr = row + dirs[i][0]; var nc = col + dirs[i][1];
                if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) { continue; }
                if (_board[nr * 8 + nc] == CK_EMPTY) {
                    moves = appendMove(moves, [nr, nc, -1, -1]);
                }
            }
        }
        return moves;
    }

    hidden function getCapturesFor(row, col, piece) {
        var moves = new [0];
        var white = (piece == CK_WHITE || piece == CK_WKING);
        var isK = (piece == CK_WKING || piece == CK_BKING);
        if (isK) {
            for (var d = 0; d < 4; d++) {
                var dr = _dirsKing[d][0]; var dc = _dirsKing[d][1];
                var nr = row + dr; var nc = col + dc;
                while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) {
                    nr += dr; nc += dc;
                }
                if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) { continue; }
                var mid = _board[nr * 8 + nc];
                var midEnemy = white ? (mid == CK_BLACK || mid == CK_BKING) : (mid == CK_WHITE || mid == CK_WKING);
                if (!midEnemy) { continue; }
                var eR = nr; var eC = nc;
                nr += dr; nc += dc;
                while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) {
                    moves = appendMove(moves, [nr, nc, eR, eC]);
                    nr += dr; nc += dc;
                }
            }
        } else {
            for (var d = 0; d < 4; d++) {
                var mr = row + _dirsKing[d][0]; var mc = col + _dirsKing[d][1];
                var lr = row + _dirsKing[d][0] * 2; var lc = col + _dirsKing[d][1] * 2;
                if (lr < 0 || lr >= 8 || lc < 0 || lc >= 8) { continue; }
                if (_board[lr * 8 + lc] != CK_EMPTY) { continue; }
                var mid = _board[mr * 8 + mc];
                if (mid == CK_EMPTY) { continue; }
                var midEnemy = white ? (mid == CK_BLACK || mid == CK_BKING) : (mid == CK_WHITE || mid == CK_WKING);
                if (midEnemy) { moves = appendMove(moves, [lr, lc, mr, mc]); }
            }
        }
        return moves;
    }

    hidden function getDirs(piece) {
        if (piece == CK_WKING || piece == CK_BKING) { return _dirsKing; }
        if (piece == CK_WHITE) { return _dirsWhite; }
        return _dirsBlack;
    }

    hidden function appendMove(arr, mv) {
        var n = new [arr.size() + 1];
        for (var i = 0; i < arr.size(); i++) { n[i] = arr[i]; }
        n[arr.size()] = mv;
        return n;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  GAME OVER CHECK
    // ═══════════════════════════════════════════════════════════════════════════

    hidden function checkGameOver() {
        var wPieces = 0; var bPieces = 0;
        var wMoves = false; var bMoves = false;
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var p = _board[r * 8 + c];
                if (p == CK_WHITE || p == CK_WKING) {
                    wPieces++;
                    if (!wMoves) { wMoves = _hasMoveFor(r, c, p); }
                } else if (p == CK_BLACK || p == CK_BKING) {
                    bPieces++;
                    if (!bMoves) { bMoves = _hasMoveFor(r, c, p); }
                }
            }
        }
        if (_playerIsWhite) {
            if (bPieces == 0 || !bMoves) { _gs = GS_WIN; }
            else if (wPieces == 0 || !wMoves) { _gs = GS_LOSE; }
        } else {
            if (wPieces == 0 || !wMoves) { _gs = GS_WIN; }
            else if (bPieces == 0 || !bMoves) { _gs = GS_LOSE; }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  AI — Multi-tick architecture
    //  Tick 1: _doAiGen  → generate all legal moves, set GS_AI_EVAL
    //  Tick 2..N: _doAiEval → evaluate a batch of moves per tick via _minimax
    //  Final: _doAiApply → apply best move, handle capture chains, switch turn
    // ═══════════════════════════════════════════════════════════════════════════

    hidden function _doAiGen() {
        _aiW = _aiVsAi ? _whiteTurn : !_playerIsWhite;
        var anyCap = sideHasCapture(_aiW);
        _aiMvN = 0;
        for (var r = 0; r < 8 && _aiMvN < AI_MAX; r++) {
            for (var c = 0; c < 8 && _aiMvN < AI_MAX; c++) {
                var p = _board[r * 8 + c];
                if (_aiW) { if (p != CK_WHITE && p != CK_WKING) { continue; } }
                else { if (p != CK_BLACK && p != CK_BKING) { continue; } }
                var moves = anyCap ? getCapturesFor(r, c, p) : getSimpleMovesFor(r, c, p);
                for (var mi = 0; mi < moves.size() && _aiMvN < AI_MAX; mi++) {
                    var mv = moves[mi];
                    _aiFR[_aiMvN] = r; _aiFC[_aiMvN] = c;
                    _aiTR[_aiMvN] = mv[0]; _aiTC[_aiMvN] = mv[1];
                    _aiCR[_aiMvN] = mv[2]; _aiCC[_aiMvN] = mv[3];
                    _aiPc[_aiMvN] = p;
                    _aiMvN++;
                }
            }
        }
        if (_aiMvN == 0) {
            _whiteTurn = !_aiW;
            _gs = GS_PLAY;
            checkGameOver();
            if (_gs == GS_PLAY) {
                if (_aiVsAi) {
                    _gs = GS_AI_THINK; _aiDelay = 1;
                }
            }
            return;
        }
        _aiMvI = 0;
        _aiBestS = -999999;
        _aiBestI = 0;
        _gs = GS_AI_EVAL;
    }

    hidden function _doAiEval() {
        var batch = 48;
        if (_difficulty == 2) { batch = 6; }
        var end = _aiMvI + batch;
        if (end > _aiMvN) { end = _aiMvN; }

        for (var i = _aiMvI; i < end; i++) {
            var r = _aiFR[i]; var c = _aiFC[i];
            var toR = _aiTR[i]; var toC = _aiTC[i];
            var capR = _aiCR[i]; var capC = _aiCC[i];
            var p = _aiPc[i];

            var svTo = _board[toR * 8 + toC];
            var svCap = (capR >= 0) ? _board[capR * 8 + capC] : CK_EMPTY;
            var np = p;
            if (p == CK_WHITE && toR == 7) { np = CK_WKING; }
            if (p == CK_BLACK && toR == 0) { np = CK_BKING; }
            _board[toR * 8 + toC] = np;
            _board[r * 8 + c] = CK_EMPTY;
            if (capR >= 0) { _board[capR * 8 + capC] = CK_EMPTY; }

            var raw = evalBoard();
            var score = _aiW ? raw : -raw;

            if (capR >= 0) {
                if (svCap == CK_WKING || svCap == CK_BKING) { score += 300; }
                else if (svCap != CK_EMPTY) { score += 120; }
            }

            if (np != p) { score += 350; }

            if (sideHasCapture(!_aiW)) {
                if (_difficulty == 2) {
                    var loss = _worstCapLoss();
                    score -= loss;
                    if (np == CK_WKING || np == CK_BKING) { score -= 120; }
                } else {
                    score -= 180;
                    if (np == CK_WKING || np == CK_BKING) { score -= 100; }
                }
            }

            if (capR >= 0) {
                if (_pHasCap(toR, toC, np, _aiW)) { score += 80; }
            }

            if (np == CK_WHITE) { score += toR * 5; }
            if (np == CK_BLACK) { score += (7 - toR) * 5; }
            if (toR >= 2 && toR <= 5 && toC >= 2 && toC <= 5) { score += 10; }
            if (toC == 0 || toC == 7) { score -= 6; }
            if (_aiW && np == CK_WHITE && r == 0 && toR > 0) { score -= 10; }
            if (!_aiW && np == CK_BLACK && r == 7 && toR < 7) { score -= 10; }
            if (np == CK_WKING || np == CK_BKING) {
                if (toR >= 2 && toR <= 5 && toC >= 1 && toC <= 6) { score += 12; }
            }
            var behR = _aiW ? (toR - 1) : (toR + 1);
            if (behR >= 0 && behR < 8) {
                if (toC > 0) {
                    var ally = _board[behR * 8 + toC - 1];
                    if (_aiW && (ally == CK_WHITE || ally == CK_WKING)) { score += 8; }
                    if (!_aiW && (ally == CK_BLACK || ally == CK_BKING)) { score += 8; }
                }
                if (toC < 7) {
                    var ally = _board[behR * 8 + toC + 1];
                    if (_aiW && (ally == CK_WHITE || ally == CK_WKING)) { score += 8; }
                    if (!_aiW && (ally == CK_BLACK || ally == CK_BKING)) { score += 8; }
                }
            }

            if (_difficulty >= 1) {
                var aheadR = _aiW ? (toR + 1) : (toR - 1);
                if (aheadR >= 0 && aheadR < 8) {
                    if (toC > 0) {
                        var fwd = _board[aheadR * 8 + toC - 1];
                        if (_aiW && (fwd == CK_WHITE || fwd == CK_WKING)) { score += 5; }
                        if (!_aiW && (fwd == CK_BLACK || fwd == CK_BKING)) { score += 5; }
                    }
                    if (toC < 7) {
                        var fwd = _board[aheadR * 8 + toC + 1];
                        if (_aiW && (fwd == CK_WHITE || fwd == CK_WKING)) { score += 5; }
                        if (!_aiW && (fwd == CK_BLACK || fwd == CK_BKING)) { score += 5; }
                    }
                }

                if (!(np == CK_WKING || np == CK_BKING)) {
                    var trapped = true;
                    var dirs = (np == CK_WHITE) ? _dirsWhite : _dirsBlack;
                    for (var di = 0; di < 2; di++) {
                        var nr = toR + dirs[di][0]; var nc = toC + dirs[di][1];
                        if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) { trapped = false; break; }
                    }
                    if (trapped) { score -= 8; }
                }
            }

            if (_difficulty == 2) {
                if (!sideHasCapture(!_aiW) && sideHasCapture(_aiW)) {
                    score += 40;
                }

                if (capR >= 0 && sideHasCapture(!_aiW)) {
                    var oppLoss = _worstCapLoss();
                    if (oppLoss <= 100 && (svCap == CK_WKING || svCap == CK_BKING)) {
                        score += 80;
                    }
                }

                var pTotal = 0;
                for (var sq = 0; sq < 64; sq++) { if (_board[sq] != CK_EMPTY) { pTotal++; } }
                if (pTotal <= 8) {
                    if (np == CK_WKING || np == CK_BKING) {
                        if (toR >= 2 && toR <= 5 && toC >= 2 && toC <= 5) { score += 20; }
                        var oppKR = -1; var oppKC = -1;
                        for (var sq2 = 0; sq2 < 64; sq2++) {
                            var pp = _board[sq2];
                            if (_aiW && (pp == CK_BKING)) { oppKR = sq2 / 8; oppKC = sq2 % 8; break; }
                            if (!_aiW && (pp == CK_WKING)) { oppKR = sq2 / 8; oppKC = sq2 % 8; break; }
                        }
                        if (oppKR >= 0) {
                            var dist = toR - oppKR; if (dist < 0) { dist = -dist; }
                            var distC = toC - oppKC; if (distC < 0) { distC = -distC; }
                            if (dist > distC) { dist = distC; }
                            score += (7 - dist) * 5;
                        }
                    }
                }
            }

            if (_difficulty == 0) {
                var noise = (Math.rand() % 10).toNumber();
                if (noise < 0) { noise = -noise; }
                score = score + noise - 5;
            }

            _board[r * 8 + c] = p;
            _board[toR * 8 + toC] = svTo;
            if (capR >= 0) { _board[capR * 8 + capC] = svCap; }

            if (score > _aiBestS) { _aiBestS = score; _aiBestI = i; }
        }

        _aiMvI = end;
        if (_aiMvI >= _aiMvN) { _doAiApply(); }
    }

    hidden function _worstCapLoss() {
        var best = 0;
        var oppW = !_aiW;
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var p = _board[r * 8 + c];
                if (oppW) { if (p != CK_WHITE && p != CK_WKING) { continue; } }
                else { if (p != CK_BLACK && p != CK_BKING) { continue; } }
                var isK = (p == CK_WKING || p == CK_BKING);
                if (isK) {
                    for (var d = 0; d < 4; d++) {
                        var dr = _dirsKing[d][0]; var dc2 = _dirsKing[d][1];
                        var nr = r + dr; var nc = c + dc2;
                        while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) { nr += dr; nc += dc2; }
                        if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) { continue; }
                        var mid = _board[nr * 8 + nc];
                        var foe = oppW ? (mid == CK_BLACK || mid == CK_BKING) : (mid == CK_WHITE || mid == CK_WKING);
                        if (!foe) { continue; }
                        var lr = nr + dr; var lc = nc + dc2;
                        while (lr >= 0 && lr < 8 && lc >= 0 && lc < 8 && _board[lr * 8 + lc] == CK_EMPTY) {
                            var vVal = (mid == CK_WKING || mid == CK_BKING) ? 350 : 100;
                            if (vVal > best) { best = vVal; }
                            break;
                        }
                    }
                } else {
                    for (var d = 0; d < 4; d++) {
                        var mr = r + _dirsKing[d][0]; var mc = c + _dirsKing[d][1];
                        var lr = r + _dirsKing[d][0] * 2; var lc = c + _dirsKing[d][1] * 2;
                        if (lr < 0 || lr >= 8 || lc < 0 || lc >= 8) { continue; }
                        if (_board[lr * 8 + lc] != CK_EMPTY) { continue; }
                        var mid = _board[mr * 8 + mc];
                        if (mid == CK_EMPTY) { continue; }
                        var foe = oppW ? (mid == CK_BLACK || mid == CK_BKING) : (mid == CK_WHITE || mid == CK_WKING);
                        if (foe) {
                            var vVal = (mid == CK_WKING || mid == CK_BKING) ? 350 : 100;
                            if (vVal > best) { best = vVal; }
                        }
                    }
                }
            }
        }
        return best;
    }

    hidden function _doAiApply() {
        var i = _aiBestI;
        var fromR = _aiFR[i]; var fromC = _aiFC[i];
        var toR = _aiTR[i]; var toC = _aiTC[i];
        var capR = _aiCR[i]; var capC = _aiCC[i];
        var p = _aiPc[i];

        _board[toR * 8 + toC] = p;
        _board[fromR * 8 + fromC] = CK_EMPTY;
        if (capR >= 0) { _board[capR * 8 + capC] = CK_EMPTY; }

        if (p == CK_WHITE && toR == 7) { _board[toR * 8 + toC] = CK_WKING; }
        if (p == CK_BLACK && toR == 0) { _board[toR * 8 + toC] = CK_BKING; }

        if (capR >= 0) {
            var piece = _board[toR * 8 + toC];
            var moreCaps = getCapturesFor(toR, toC, piece);
            while (moreCaps.size() > 0) {
                var bestCI = 0;
                if (moreCaps.size() > 1) {
                    var bestCS = -999999;
                    for (var ci = 0; ci < moreCaps.size(); ci++) {
                        var mc = moreCaps[ci];
                        var sv1 = _board[mc[0] * 8 + mc[1]];
                        var sv2 = _board[mc[2] * 8 + mc[3]];
                        _board[mc[0] * 8 + mc[1]] = piece;
                        _board[toR * 8 + toC] = CK_EMPTY;
                        _board[mc[2] * 8 + mc[3]] = CK_EMPTY;
                        var sc = _aiW ? evalBoard() : -evalBoard();
                        _board[toR * 8 + toC] = piece;
                        _board[mc[0] * 8 + mc[1]] = sv1;
                        _board[mc[2] * 8 + mc[3]] = sv2;
                        if (sc > bestCS) { bestCS = sc; bestCI = ci; }
                    }
                }
                var mc = moreCaps[bestCI];
                _board[mc[0] * 8 + mc[1]] = piece;
                _board[toR * 8 + toC] = CK_EMPTY;
                _board[mc[2] * 8 + mc[3]] = CK_EMPTY;
                if (piece == CK_WHITE && mc[0] == 7) { _board[mc[0] * 8 + mc[1]] = CK_WKING; piece = CK_WKING; }
                if (piece == CK_BLACK && mc[0] == 0) { _board[mc[0] * 8 + mc[1]] = CK_BKING; piece = CK_BKING; }
                toR = mc[0]; toC = mc[1];
                moreCaps = getCapturesFor(toR, toC, piece);
            }
        }

        _whiteTurn = !_aiW;

        var wP = 0; var bP = 0; var wM = false; var bM = false;
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var pp = _board[r * 8 + c];
                if (pp == CK_WHITE || pp == CK_WKING) {
                    wP++;
                    if (!wM) { wM = _hasMoveFor(r, c, pp); }
                } else if (pp == CK_BLACK || pp == CK_BKING) {
                    bP++;
                    if (!bM) { bM = _hasMoveFor(r, c, pp); }
                }
            }
        }

        if (_playerIsWhite) {
            if (bP == 0 || !bM) { _gs = GS_WIN; return; }
            if (wP == 0 || !wM) { _gs = GS_LOSE; return; }
        } else {
            if (wP == 0 || !wM) { _gs = GS_WIN; return; }
            if (bP == 0 || !bM) { _gs = GS_LOSE; return; }
        }

        if (_aiVsAi) {
            _gs = GS_AI_THINK; _aiDelay = 1;
        } else {
            _gs = GS_PLAY;
            _whiteTurn = _playerIsWhite;
            snapCursorToValidPiece();
        }
    }

    // Zero-allocation minimax with alpha-beta pruning.
    // Generates moves inline — no getCapturesFor/getSimpleMovesFor arrays.
    hidden function _minimax(depth, alpha, beta, wTurn, chR, chC) {
        _mmN++;
        var inCh = (chR >= 0);
        if (_mmN > _mmLimit || depth < -1 || (!inCh && depth <= 0)) { return evalBoard(); }

        var anyCap = inCh;
        if (!inCh) { anyCap = sideHasCapture(wTurn); }

        var best = wTurn ? -999999 : 999999;
        var found = false;

        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                if (inCh && (r != chR || c != chC)) { continue; }
                var p = _board[r * 8 + c];
                if (wTurn) { if (p != CK_WHITE && p != CK_WKING) { continue; } }
                else { if (p != CK_BLACK && p != CK_BKING) { continue; } }
                var isK = (p == CK_WKING || p == CK_BKING);

                if (anyCap) {
                    if (isK) {
                        for (var d = 0; d < 4; d++) {
                            var dr = _dirsKing[d][0]; var dc = _dirsKing[d][1];
                            var nr = r + dr; var nc = c + dc;
                            while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) { nr += dr; nc += dc; }
                            if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) { continue; }
                            var mid = _board[nr * 8 + nc];
                            var foe;
                            if (wTurn) { foe = (mid == CK_BLACK || mid == CK_BKING); }
                            else { foe = (mid == CK_WHITE || mid == CK_WKING); }
                            if (!foe) { continue; }
                            var eR = nr; var eC = nc; var svE = mid;
                            nr += dr; nc += dc;
                            while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) {
                                found = true;
                                _board[nr * 8 + nc] = p; _board[r * 8 + c] = CK_EMPTY; _board[eR * 8 + eC] = CK_EMPTY;
                                var sc;
                                if (_pHasCap(nr, nc, p, wTurn)) { sc = _minimax(depth - 1, alpha, beta, wTurn, nr, nc); }
                                else { sc = _minimax(depth - 1, alpha, beta, !wTurn, -1, -1); }
                                _board[r * 8 + c] = p; _board[nr * 8 + nc] = CK_EMPTY; _board[eR * 8 + eC] = svE;
                                if (wTurn) { if (sc > best) { best = sc; } if (best > alpha) { alpha = best; } }
                                else { if (sc < best) { best = sc; } if (best < beta) { beta = best; } }
                                if (alpha >= beta || _mmN > _mmLimit) { return best; }
                                nr += dr; nc += dc;
                            }
                        }
                    } else {
                        for (var d = 0; d < 4; d++) {
                            var dr = _dirsKing[d][0]; var dc = _dirsKing[d][1];
                            var mr = r + dr; var mc = c + dc;
                            var lr = r + dr * 2; var lc = c + dc * 2;
                            if (lr < 0 || lr >= 8 || lc < 0 || lc >= 8) { continue; }
                            if (_board[lr * 8 + lc] != CK_EMPTY) { continue; }
                            var mid = _board[mr * 8 + mc];
                            if (mid == CK_EMPTY) { continue; }
                            var foe;
                            if (wTurn) { foe = (mid == CK_BLACK || mid == CK_BKING); }
                            else { foe = (mid == CK_WHITE || mid == CK_WKING); }
                            if (!foe) { continue; }
                            found = true;
                            var np = p;
                            if (p == CK_WHITE && lr == 7) { np = CK_WKING; }
                            if (p == CK_BLACK && lr == 0) { np = CK_BKING; }
                            var svM = mid;
                            _board[lr * 8 + lc] = np; _board[r * 8 + c] = CK_EMPTY; _board[mr * 8 + mc] = CK_EMPTY;
                            var sc;
                            if (_pHasCap(lr, lc, np, wTurn)) { sc = _minimax(depth - 1, alpha, beta, wTurn, lr, lc); }
                            else { sc = _minimax(depth - 1, alpha, beta, !wTurn, -1, -1); }
                            _board[r * 8 + c] = p; _board[lr * 8 + lc] = CK_EMPTY; _board[mr * 8 + mc] = svM;
                            if (wTurn) { if (sc > best) { best = sc; } if (best > alpha) { alpha = best; } }
                            else { if (sc < best) { best = sc; } if (best < beta) { beta = best; } }
                            if (alpha >= beta || _mmN > _mmLimit) { return best; }
                        }
                    }
                } else {
                    if (isK) {
                        for (var d = 0; d < 4; d++) {
                            var dr = _dirsKing[d][0]; var dc = _dirsKing[d][1];
                            var nr = r + dr; var nc = c + dc;
                            while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) {
                                found = true;
                                _board[nr * 8 + nc] = p; _board[r * 8 + c] = CK_EMPTY;
                                var sc = _minimax(depth - 1, alpha, beta, !wTurn, -1, -1);
                                _board[r * 8 + c] = p; _board[nr * 8 + nc] = CK_EMPTY;
                                if (wTurn) { if (sc > best) { best = sc; } if (best > alpha) { alpha = best; } }
                                else { if (sc < best) { best = sc; } if (best < beta) { beta = best; } }
                                if (alpha >= beta || _mmN > _mmLimit) { return best; }
                                nr += dr; nc += dc;
                            }
                        }
                    } else {
                        var dirs = (p == CK_WHITE) ? _dirsWhite : _dirsBlack;
                        for (var di = 0; di < 2; di++) {
                            var nr = r + dirs[di][0]; var nc = c + dirs[di][1];
                            if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) { continue; }
                            if (_board[nr * 8 + nc] != CK_EMPTY) { continue; }
                            found = true;
                            var np = p;
                            if (p == CK_WHITE && nr == 7) { np = CK_WKING; }
                            if (p == CK_BLACK && nr == 0) { np = CK_BKING; }
                            _board[nr * 8 + nc] = np; _board[r * 8 + c] = CK_EMPTY;
                            var sc = _minimax(depth - 1, alpha, beta, !wTurn, -1, -1);
                            _board[r * 8 + c] = p; _board[nr * 8 + nc] = CK_EMPTY;
                            if (wTurn) { if (sc > best) { best = sc; } if (best > alpha) { alpha = best; } }
                            else { if (sc < best) { best = sc; } if (best < beta) { beta = best; } }
                            if (alpha >= beta || _mmN > _mmLimit) { return best; }
                        }
                    }
                }
            }
        }
        if (!found) { return wTurn ? -999990 : 999990; }
        return best;
    }

    hidden function _pHasCap(r, c, piece, wTurn) {
        var isK = (piece == CK_WKING || piece == CK_BKING);
        if (isK) {
            for (var d = 0; d < 4; d++) {
                var dr = _dirsKing[d][0]; var dc = _dirsKing[d][1];
                var nr = r + dr; var nc = c + dc;
                while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == CK_EMPTY) { nr += dr; nc += dc; }
                if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) { continue; }
                var mid = _board[nr * 8 + nc];
                var foe = wTurn ? (mid == CK_BLACK || mid == CK_BKING) : (mid == CK_WHITE || mid == CK_WKING);
                if (!foe) { continue; }
                var lr = nr + dr; var lc = nc + dc;
                if (lr >= 0 && lr < 8 && lc >= 0 && lc < 8 && _board[lr * 8 + lc] == CK_EMPTY) { return true; }
            }
        } else {
            for (var d = 0; d < 4; d++) {
                var mr = r + _dirsKing[d][0]; var mc = c + _dirsKing[d][1];
                var lr = r + _dirsKing[d][0] * 2; var lc = c + _dirsKing[d][1] * 2;
                if (lr < 0 || lr >= 8 || lc < 0 || lc >= 8) { continue; }
                if (_board[lr * 8 + lc] != CK_EMPTY) { continue; }
                var mid = _board[mr * 8 + mc];
                if (mid == CK_EMPTY) { continue; }
                var foe = wTurn ? (mid == CK_BLACK || mid == CK_BKING) : (mid == CK_WHITE || mid == CK_WKING);
                if (foe) { return true; }
            }
        }
        return false;
    }

    hidden function evalBoard() {
        var score = 0;
        var wMen = 0; var wKings = 0; var bMen = 0; var bKings = 0;
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var p = _board[r * 8 + c];
                if (p == CK_EMPTY) { continue; }
                if (p == CK_WHITE) {
                    wMen++;
                    score += 100 + r * 14;
                    if (c >= 2 && c <= 5 && r >= 2 && r <= 5) { score += 10; }
                    if (c >= 3 && c <= 4 && r >= 3 && r <= 4) { score += 6; }
                    if (r == 0) { score += 18; }
                    if (c == 0 || c == 7) { score -= 6; }
                    if (r >= 5) { score += (r - 4) * 8; }
                } else if (p == CK_WKING) {
                    wKings++;
                    score += 380;
                    if (r >= 2 && r <= 5 && c >= 2 && c <= 5) { score += 18; }
                    if (r >= 3 && r <= 4 && c >= 3 && c <= 4) { score += 8; }
                } else if (p == CK_BLACK) {
                    bMen++;
                    score -= 100 + (7 - r) * 14;
                    if (c >= 2 && c <= 5 && r >= 2 && r <= 5) { score -= 10; }
                    if (c >= 3 && c <= 4 && r >= 3 && r <= 4) { score -= 6; }
                    if (r == 7) { score -= 18; }
                    if (c == 0 || c == 7) { score += 6; }
                    if (r <= 2) { score -= (3 - r) * 8; }
                } else if (p == CK_BKING) {
                    bKings++;
                    score -= 380;
                    if (r >= 2 && r <= 5 && c >= 2 && c <= 5) { score -= 18; }
                    if (r >= 3 && r <= 4 && c >= 3 && c <= 4) { score -= 8; }
                }
            }
        }
        var wTotal = wMen + wKings;
        var bTotal = bMen + bKings;
        var total = wTotal + bTotal;
        if (wTotal == 0) { return -99990; }
        if (bTotal == 0) { return 99990; }
        var wMat = wMen * 100 + wKings * 380;
        var bMat = bMen * 100 + bKings * 380;
        if (wMat > bMat) { score += (24 - total) * 8; }
        else if (bMat > wMat) { score -= (24 - total) * 8; }
        if (wKings > 0 && bKings == 0 && bMen > 0) { score += 60; }
        if (bKings > 0 && wKings == 0 && wMen > 0) { score -= 60; }
        if (wTotal > bTotal) { score += (wTotal - bTotal) * 15; }
        if (bTotal > wTotal) { score -= (bTotal - wTotal) * 15; }
        if (total <= 6) {
            if (wMat > bMat) {
                score += 40;
                for (var sr = 0; sr < 8; sr++) {
                    for (var sc = 0; sc < 8; sc++) {
                        var pp = _board[sr * 8 + sc];
                        if (pp == CK_BLACK || pp == CK_BKING) {
                            if (sc == 0 || sc == 7) { score += 12; }
                            if (sr == 0 || sr == 7) { score += 12; }
                        }
                    }
                }
            } else if (bMat > wMat) {
                score -= 40;
                for (var sr = 0; sr < 8; sr++) {
                    for (var sc = 0; sc < 8; sc++) {
                        var pp = _board[sr * 8 + sc];
                        if (pp == CK_WHITE || pp == CK_WKING) {
                            if (sc == 0 || sc == 7) { score -= 12; }
                            if (sr == 0 || sr == 7) { score -= 12; }
                        }
                    }
                }
            }
        }
        return score;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  RENDERING
    // ═══════════════════════════════════════════════════════════════════════════

    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeo(); }
        if (_gs == GS_MENU) { drawMenu(dc); return; }
        drawBoard(dc);
        drawPieces(dc);
        drawHUD(dc);
        if (_gs == GS_WIN) {
            if (_aiVsAi) { drawEndOverlay(dc, _playerIsWhite ? "LIGHT WINS" : "DARK WINS", 0x44FF88); }
            else { drawEndOverlay(dc, "YOU WIN!", 0x44FF88); }
        }
        if (_gs == GS_LOSE) {
            if (_aiVsAi) { drawEndOverlay(dc, _playerIsWhite ? "DARK WINS" : "LIGHT WINS", 0xFF5544); }
            else { drawEndOverlay(dc, "YOU LOSE", 0xFF5544); }
        }
        if (_gs == GS_DRAW) { drawEndOverlay(dc, "DRAW", 0xCCCC55); }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x080808, 0x080808); dc.clear();
        var hw = _w / 2;
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, hw, hw - 1);

        // Title
        dc.setColor(0xFF6633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _h * 11 / 100, Graphics.FONT_SMALL, "CHECKERS", Graphics.TEXT_JUSTIFY_CENTER);

        var rowLabels = [
            _playerIsWhite ? "Color: LIGHT" : "Color: DARK",
            "Diff: " + (["Easy","Normal","Hard"][_difficulty]),
            _aiVsAi ? "Mode: AI vs AI" : (_pvp ? "Mode: P vs P" : "Mode: P vs AI"),
            "START"
        ];
        var nRows = 4;
        var rowH   = _h * 12 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 34) { rowH = 34; }
        var rowW   = _w * 78 / 100;
        var rowX   = (_w - rowW) / 2;
        var gap    = _h * 1 / 100; if (gap < 2) { gap = 2; }
        var totalRows = nRows * rowH + (nRows - 1) * gap;
        var rowY0  = (_h - totalRows) / 2 + rowH;

        for (var i = 0; i < nRows; i++) {
            var ry = rowY0 + i * (rowH + gap);
            var sel = (i == _menuRow);
            var isStart = (i == nRows - 1);

            dc.setColor(sel ? (isStart ? 0x5C2200 : 0x1A3A6A) : 0x111820, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFF8833 : 0x55AAFF) : 0x2A3A4A, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);

            if (sel) {
                dc.setColor(isStart ? 0xFF8833 : 0x55AAFF, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }

            var textClr = sel ? (isStart ? 0xFFCC88 : 0xCCEEFF) : 0x778899;
            dc.setColor(textClr, Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        rowLabels[i], Graphics.TEXT_JUSTIFY_CENTER);

            if (i == 0) {
                var dotX = rowX + rowW - 14;
                var dotY = ry + rowH / 2;
                dc.setColor(_playerIsWhite ? 0xF8F0D0 : 0x4A1808, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dotX, dotY, 7);
                dc.setColor(_playerIsWhite ? 0x888880 : 0xAA6633, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(dotX, dotY, 7);
            }
        }

        // Hint anchored to bottom edge — avoids overflow on small screens
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _h - 14, Graphics.FONT_XTINY,
                    "UP/DN move  SELECT act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function sqToScreen(row, col) {
        var screenRow = _playerIsWhite ? (7 - row) : row;
        var screenCol = _playerIsWhite ? col : (7 - col);
        return [_ox + screenCol * _sq, _oy + screenRow * _sq];
    }

    hidden function drawBoard(dc) {
        dc.setColor(0x080808, 0x080808); dc.clear();
        for (var row = 0; row < 8; row++) {
            for (var col = 0; col < 8; col++) {
                var light = ((row + col) % 2 == 0);
                var xy = sqToScreen(row, col);
                var bx = xy[0]; var by = xy[1];

                // Determine square color
                var isDst = false;
                for (var i = 0; i < _validDsts.size(); i++) {
                    if (_validDsts[i][0] == row && _validDsts[i][1] == col) { isDst = true; break; }
                }
                var sqClr;
                if (isDst) {
                    sqClr = light ? 0xBBEE66 : 0x1A7730;  // bright green destination
                } else {
                    sqClr = light ? 0xEDD8A0 : 0x7B4B2A;
                }
                dc.setColor(sqClr, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, _sq, _sq);

                // Cursor: black outer (visible on light squares) + white separator +
                // pulsing color inner (orange = piece selected, cyan = browsing)
                if (row == _curRow && col == _curCol) {
                    var selMode = (_selRow >= 0);
                    var pulse   = (_tick % 2 == 0);
                    var innerC  = selMode ? (pulse ? 0xFF6600 : 0xFFAA00)
                                         : (pulse ? 0x00CCFF : 0x0099CC);
                    dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(bx,     by,     _sq,     _sq);
                    dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(bx + 1, by + 1, _sq - 2, _sq - 2);
                    dc.setColor(innerC, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(bx + 2, by + 2, _sq - 4, _sq - 4);
                }
            }
        }
        // Board outer border
        dc.setColor(0x554433, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_ox - 1, _oy - 1, _sq * 8 + 2, _sq * 8 + 2);
        dc.drawRectangle(_ox - 2, _oy - 2, _sq * 8 + 4, _sq * 8 + 4);
    }

    hidden function drawPieces(dc) {
        var r2  = _sq * 38 / 100; if (r2 < 5) { r2 = 5; }
        var r2k = _sq * 26 / 100; if (r2k < 4) { r2k = 4; }
        for (var row = 0; row < 8; row++) {
            for (var col = 0; col < 8; col++) {
                var p = _board[row * 8 + col];
                var xy = sqToScreen(row, col);
                var bx = xy[0] + _sq / 2;
                var by = xy[1] + _sq / 2;

                if (p == CK_EMPTY) {
                    // Large bright dot for valid destination
                    var isDst2 = false;
                    for (var i = 0; i < _validDsts.size(); i++) {
                        if (_validDsts[i][0] == row && _validDsts[i][1] == col) { isDst2 = true; break; }
                    }
                    if (isDst2) {
                        var dotR = _sq * 30 / 100; if (dotR < 4) { dotR = 4; }
                        dc.setColor(0x00EE44, Graphics.COLOR_TRANSPARENT);
                        dc.fillCircle(bx, by, dotR);
                        dc.setColor(0xAAFF88, Graphics.COLOR_TRANSPARENT);
                        dc.fillCircle(bx, by, dotR * 5 / 10);
                    }
                    continue;
                }

                drawChecker(dc, bx, by, p, r2, r2k);

                // Selection ring drawn ON TOP of piece — red for maximum visibility
                if (row == _selRow && col == _selCol) {
                    dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(bx, by, r2 + 2);
                    dc.drawCircle(bx, by, r2 + 3);
                    dc.setColor(0xAA0000, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(bx, by, r2 + 4);
                }
            }
        }
    }

    hidden function drawChecker(dc, cx, cy, piece, radius, kingR) {
        var isKing = (piece == CK_WKING || piece == CK_BKING);
        var white  = (piece == CK_WHITE || piece == CK_WKING);

        // Drop shadow
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 1, cy + 2, radius);

        // Rim
        dc.setColor(white ? 0xB08030 : 0x881800, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, radius);

        // Body
        dc.setColor(white ? 0xF0E0B0 : 0xBB3010, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, radius - 2);

        if (isKing) {
            var s = radius * 45 / 100; if (s < 3) { s = 3; }
            dc.setColor(white ? 0xCC8800 : 0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - s, cy - s / 4, s * 2, s * 3 / 4);
            dc.fillPolygon([[cx - s, cy - s / 4], [cx - s * 2 / 3, cy - s], [cx - s / 3, cy - s / 4]]);
            dc.fillPolygon([[cx - s / 3, cy - s / 4], [cx, cy - s], [cx + s / 3, cy - s / 4]]);
            dc.fillPolygon([[cx + s / 3, cy - s / 4], [cx + s * 2 / 3, cy - s], [cx + s, cy - s / 4]]);
        }
    }

    hidden function drawHUD(dc) {
        var hy = _oy + _sq * 8 + 3;
        if (hy + 14 > _h) { hy = _oy - 14; }
        var lbl = "";
        if (_gs == GS_AI_THINK || _gs == GS_AI_EVAL) {
            var dots = "";
            for (var i = 0; i < (_tick % 4); i++) { dots = dots + "."; }
            lbl = "AI" + dots;
        } else if (_mustRow >= 0) {
            lbl = "Must jump!";
        } else if (isPlayerTurn()) {
            if (_selRow >= 0) {
                lbl = _validDsts.size() > 1 ? "UP/DN switch  SEL move" : "SEL to move";
            } else {
                lbl = _playerIsWhite ? "Light moves" : "Dark moves";
            }
        }
        dc.setColor(0xBB9966, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, hy, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawEndOverlay(dc, msg, clr) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w / 2 - 64, _h / 2 - 24, 128, 48, 8);
        dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_w / 2 - 64, _h / 2 - 24, 128, 48, 8);
        dc.drawText(_w / 2, _h / 2 - 20, Graphics.FONT_MEDIUM, msg, Graphics.TEXT_JUSTIFY_CENTER);
        if (_tick % 8 < 5) {
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h / 2 + 8, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

}
