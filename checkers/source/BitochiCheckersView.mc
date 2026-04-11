using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Board encoding ────────────────────────────────────────────────────────────
// Standard 8×8 checkers — only dark squares used (32 playable squares).
// We use an 8×8 flat array for simplicity.
// Cell values:
const CK_EMPTY  = 0;
const CK_WHITE  = 1;   // player piece
const CK_WKING  = 2;   // player king
const CK_BLACK  = 3;   // AI piece
const CK_BKING  = 4;   // AI king

// ── Game states ───────────────────────────────────────────────────────────────
const GS_MENU     = 0;
const GS_PLAY     = 1;
const GS_AI_THINK = 2;
const GS_WIN      = 3;   // player won
const GS_LOSE     = 4;   // player lost
const GS_DRAW     = 5;

class BitochiCheckersView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    // Board: _board[row*8+col], row 0 = bottom (white side)
    hidden var _board;

    // Turn: true = white (player), false = black (AI)
    hidden var _whiteTurn;

    // Selection
    hidden var _selRow; hidden var _selCol;   // selected piece (-1 if none)
    hidden var _curRow; hidden var _curCol;   // cursor
    hidden var _validDsts;    // [[toRow,toCol,captRow,captCol]] for selected piece

    // Multi-jump: if a capture was just made, same piece must continue if can
    hidden var _mustRow; hidden var _mustCol;  // -1 = no forced continuation

    // AI
    hidden var _aiDelay;
    hidden var _difficulty;   // 0=Easy 1=Normal 2=Hard

    hidden var _ox; hidden var _oy; hidden var _sq;
    hidden var _playerIsWhite; // true = player is light pieces (moves up)

    // ── Initialize ────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _w = 0; _h = 0; _tick = 0;
        _gs = GS_MENU; _difficulty = 1;
        _playerIsWhite = true;
        _selRow = -1; _selCol = -1;
        _mustRow = -1; _mustCol = -1;
        _curRow = 4; _curCol = 1;
        _validDsts = new [0];
        _board = new [64];
        _sq = 0; _ox = 0; _oy = 0;
        resetBoard();
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 200, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupGeo();
    }

    hidden function setupGeo() {
        _sq = _w * 86 / 100 / 8;
        if (_sq > _h * 86 / 100 / 8) { _sq = _h * 86 / 100 / 8; }
        _ox = (_w - _sq * 8) / 2;
        _oy = (_h - _sq * 8) / 2;
    }

    // ── Board setup ───────────────────────────────────────────────────────────
    hidden function resetBoard() {
        for (var i = 0; i < 64; i++) { _board[i] = CK_EMPTY; }
        // Black pieces on top 3 rows (rows 5-7), only dark squares
        for (var r = 5; r <= 7; r++) {
            for (var c = 0; c < 8; c++) {
                if ((r + c) % 2 == 1) { _board[r*8+c] = CK_BLACK; }
            }
        }
        // White pieces on bottom 3 rows (rows 0-2), only dark squares
        for (var r = 0; r <= 2; r++) {
            for (var c = 0; c < 8; c++) {
                if ((r + c) % 2 == 1) { _board[r*8+c] = CK_WHITE; }
            }
        }
        _whiteTurn = true;
        _selRow = -1; _selCol = -1;
        _mustRow = -1; _mustCol = -1;
        _validDsts = new [0];
    }

    // ── Timer ─────────────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        if (_gs == GS_AI_THINK) {
            _aiDelay--;
            if (_aiDelay <= 0) { doAiTurn(); }
        }
        WatchUi.requestUpdate();
    }

    // ── Input ─────────────────────────────────────────────────────────────────
    function doUp() {
        if (_gs == GS_MENU)                           { _difficulty = (_difficulty + 2) % 3; return; }
        if (_gs == GS_WIN || _gs == GS_LOSE || _gs == GS_DRAW) { _gs = GS_MENU; return; }
        if (_gs != GS_PLAY) { return; }
        if (_curRow < 7) { _curRow++; }
    }

    function doDown() {
        if (_gs == GS_MENU)                           { _difficulty = (_difficulty + 1) % 3; return; }
        if (_gs == GS_WIN || _gs == GS_LOSE || _gs == GS_DRAW) { _gs = GS_MENU; return; }
        if (_gs != GS_PLAY) { return; }
        if (_curRow > 0) { _curRow--; }
    }

    function doSelect() {
        if (_gs == GS_MENU)                           { startGame(); return; }
        if (_gs == GS_WIN || _gs == GS_LOSE || _gs == GS_DRAW) { _gs = GS_MENU; return; }
        if (_gs != GS_PLAY) { return; }
        handleCell(_curRow, _curCol);
    }

    function doBack() {
        if (_gs != GS_MENU) { _gs = GS_MENU; _selRow = -1; _validDsts = new [0]; }
    }

    function doMenu() { doBack(); }

    function doTap(tx, ty) {
        if (_gs == GS_MENU) {
            // Check color toggle buttons
            var btnY = _h * 65 / 100; var btnH = 22; var btnW = 52;
            var wBtnX = _w / 2 - btnW - 4;
            var bBtnX = _w / 2 + 4;
            if (ty >= btnY && ty < btnY + btnH) {
                if (tx >= wBtnX && tx < wBtnX + btnW) { _playerIsWhite = true; return; }
                if (tx >= bBtnX && tx < bBtnX + btnW) { _playerIsWhite = false; return; }
            }
            startGame(); return;
        }
        if (_gs == GS_WIN || _gs == GS_LOSE || _gs == GS_DRAW)   { _gs = GS_MENU; return; }
        if (_gs == GS_AI_THINK) { return; }
        if (_gs != GS_PLAY)     { return; }
        if (_sq <= 0) { return; }

        // Map screen pixel → board square
        var col    = (tx - _ox) / _sq;
        var rowInv = (ty - _oy) / _sq;

        if (tx < _ox || tx >= _ox + _sq * 8) { return; }
        if (ty < _oy || ty >= _oy + _sq * 8) { return; }
        if (col < 0 || col >= 8 || rowInv < 0 || rowInv >= 8) { return; }

        var row; var realCol;
        if (_playerIsWhite) {
            row = 7 - rowInv;
            realCol = col;
        } else {
            row = rowInv;
            realCol = 7 - col;
        }
        _curRow = row; _curCol = realCol;
        handleCell(row, realCol);
    }

    hidden function startGame() {
        resetBoard();
        _gs = GS_PLAY;
        if (_playerIsWhite) {
            _whiteTurn = true;
            _curRow = 2; _curCol = 1;
        } else {
            _whiteTurn = false;
            _curRow = 5; _curCol = 0;
            // AI (white) moves first
            _gs = GS_AI_THINK;
            _aiDelay = 2 + _difficulty;
        }
    }

    hidden function handleCell(row, col) {
        var isPlayerTurn = _playerIsWhite ? _whiteTurn : !_whiteTurn;
        if (!isPlayerTurn) { return; }

        var piece = _board[row * 8 + col];
        var playerPiece = _playerIsWhite ? (piece == CK_WHITE || piece == CK_WKING)
                                         : (piece == CK_BLACK || piece == CK_BKING);

        if (_selRow < 0) {
            if (!playerPiece) { return; }
            if (_mustRow >= 0 && (row != _mustRow || col != _mustCol)) { return; }
            var moves = getMovesFor(row, col, piece, _mustRow >= 0);
            if (moves.size() == 0) { return; }
            _selRow = row; _selCol = col;
            _validDsts = moves;
        } else {
            var moved = false;
            for (var i = 0; i < _validDsts.size(); i++) {
                var mv = _validDsts[i];
                if (mv[0] == row && mv[1] == col) {
                    applyPlayerMove(mv);
                    moved = true;
                    break;
                }
            }
            if (!moved) {
                _selRow = -1; _selCol = -1; _validDsts = new [0];
                if (playerPiece) {
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
        var capR = mv[2]; var capC = mv[3]; // -1 if no capture

        var piece = _board[fromR*8+fromC];
        _board[toR*8+toC] = piece;
        _board[fromR*8+fromC] = CK_EMPTY;
        if (capR >= 0) { _board[capR*8+capC] = CK_EMPTY; }

        // King promotion
        if (piece == CK_WHITE && toR == 7) { _board[toR*8+toC] = CK_WKING; piece = CK_WKING; }

        _selRow = -1; _selCol = -1; _validDsts = new [0];
        _mustRow = -1; _mustCol = -1;

        // Multi-jump: if a capture was made and more captures available, force continuation
        if (capR >= 0) {
            var moreCaps = getCapturesFor(toR, toC, piece);
            if (moreCaps.size() > 0) {
                _mustRow = toR; _mustCol = toC;
                _selRow = toR; _selCol = toC;
                _validDsts = moreCaps;
                return; // stay in player's turn
            }
        }

        checkGameOver();
        if (_gs == GS_PLAY) {
            // Switch to AI's turn
            if (_playerIsWhite) { _whiteTurn = false; } else { _whiteTurn = true; }
            _gs = GS_AI_THINK;
            _aiDelay = 2 + _difficulty;
        }
    }

    // ── Move generation ───────────────────────────────────────────────────────
    // Returns [[toRow,toCol,capRow,capCol]] — capRow=-1 for non-capture moves
    hidden function getMovesFor(row, col, piece, captureOnly) {
        // Must-capture rule: if any capture exists for the player, only captures allowed
        var anyCap = false;
        if (!captureOnly) {
            anyCap = playerHasCapture(piece == CK_WHITE || piece == CK_WKING);
        }
        if (anyCap || captureOnly) {
            return getCapturesFor(row, col, piece);
        }
        return getSimpleMovesFor(row, col, piece);
    }

    hidden function playerHasCapture(white) {
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var p = _board[r*8+c];
                var mine = white ? (p == CK_WHITE || p == CK_WKING) : (p == CK_BLACK || p == CK_BKING);
                if (!mine) { continue; }
                if (getCapturesFor(r, c, p).size() > 0) { return true; }
            }
        }
        return false;
    }

    hidden function getSimpleMovesFor(row, col, piece) {
        var moves = new [0];
        var dirs = getDirs(piece);
        for (var i = 0; i < dirs.size(); i++) {
            var nr = row + dirs[i][0]; var nc = col + dirs[i][1];
            if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) { continue; }
            if (_board[nr*8+nc] == CK_EMPTY) {
                moves = appendMove(moves, [nr, nc, -1, -1]);
            }
        }
        return moves;
    }

    hidden function getCapturesFor(row, col, piece) {
        var moves = new [0];
        var dirs = getDirs(piece);
        var white = (piece == CK_WHITE || piece == CK_WKING);
        for (var i = 0; i < dirs.size(); i++) {
            var mr = row + dirs[i][0]; var mc = col + dirs[i][1]; // middle (captured)
            var lr = row + dirs[i][0]*2; var lc = col + dirs[i][1]*2; // landing
            if (lr < 0 || lr >= 8 || lc < 0 || lc >= 8) { continue; }
            if (_board[lr*8+lc] != CK_EMPTY) { continue; }
            var mid = _board[mr*8+mc];
            if (mid == CK_EMPTY) { continue; }
            var midEnemy = white ? (mid == CK_BLACK || mid == CK_BKING)
                                 : (mid == CK_WHITE || mid == CK_WKING);
            if (midEnemy) { moves = appendMove(moves, [lr, lc, mr, mc]); }
        }
        return moves;
    }

    hidden function getDirs(piece) {
        // Kings move in all 4 diagonals; regular pieces move forward only
        if (piece == CK_WKING || piece == CK_BKING) {
            return [[-1,-1],[-1,1],[1,-1],[1,1]];
        }
        if (piece == CK_WHITE) { return [[1,-1],[1,1]]; }   // white moves up (increasing row)
        return [[-1,-1],[-1,1]];                              // black moves down
    }

    hidden function appendMove(arr, mv) {
        var n = new [arr.size() + 1];
        for (var i = 0; i < arr.size(); i++) { n[i] = arr[i]; }
        n[arr.size()] = mv;
        return n;
    }

    // ── Game-over check ───────────────────────────────────────────────────────
    hidden function checkGameOver() {
        var whitePieces = 0; var blackPieces = 0;
        var whiteMoves = false; var blackMoves = false;
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var p = _board[r*8+c];
                if (p == CK_WHITE || p == CK_WKING) {
                    whitePieces++;
                    if (!whiteMoves) {
                        var ms = getMovesFor(r, c, p, false);
                        if (ms.size() > 0) { whiteMoves = true; }
                    }
                } else if (p == CK_BLACK || p == CK_BKING) {
                    blackPieces++;
                    if (!blackMoves) {
                        var ms = getMovesFor(r, c, p, false);
                        if (ms.size() > 0) { blackMoves = true; }
                    }
                }
            }
        }
        if (blackPieces == 0 || !blackMoves) { _gs = GS_WIN; }
        else if (whitePieces == 0 || !whiteMoves) { _gs = GS_LOSE; }
    }

    // ── AI ────────────────────────────────────────────────────────────────────
    hidden function doAiTurn() {
        _gs = GS_PLAY;
        var aiIsWhite = !_playerIsWhite;
        _whiteTurn = aiIsWhite;
        doAiMoves();
        if (_gs == GS_PLAY) {
            _whiteTurn = _playerIsWhite;
            checkGameOver();
            if (_gs == GS_PLAY) {
                // Check player has moves
                var playerHasMoves = false;
                for (var r = 0; r < 8 && !playerHasMoves; r++) {
                    for (var c = 0; c < 8 && !playerHasMoves; c++) {
                        var p = _board[r*8+c];
                        var isPlayerPiece = _playerIsWhite ? (p == CK_WHITE || p == CK_WKING)
                                                           : (p == CK_BLACK || p == CK_BKING);
                        if (isPlayerPiece && getMovesFor(r, c, p, false).size() > 0) {
                            playerHasMoves = true;
                        }
                    }
                }
                if (!playerHasMoves) { _gs = GS_LOSE; }
            }
        }
    }

    hidden function doAiMoves() {
        var aiIsWhite = !_playerIsWhite;
        var forced = false; var forcedRow = -1; var forcedCol = -1;
        while (true) {
            var depth = 2 + _difficulty;
            var result = aiPickMove(forced, forcedRow, forcedCol, depth, aiIsWhite);
            if (result == null) { break; }

            var fromR = result[0]; var fromC = result[1];
            var mv    = result[2];
            var toR   = mv[0];    var toC   = mv[1];
            var capR  = mv[2];    var capC  = mv[3];

            var piece = _board[fromR*8+fromC];
            _board[toR*8+toC]   = piece;
            _board[fromR*8+fromC] = CK_EMPTY;
            if (capR >= 0) { _board[capR*8+capC] = CK_EMPTY; }

            if (aiIsWhite && piece == CK_WHITE && toR == 7) { _board[toR*8+toC] = CK_WKING; piece = CK_WKING; }
            if (!aiIsWhite && piece == CK_BLACK && toR == 0) { _board[toR*8+toC] = CK_BKING; piece = CK_BKING; }

            if (capR >= 0) {
                var moreCaps = getCapturesFor(toR, toC, _board[toR*8+toC]);
                if (moreCaps.size() > 0) { forced = true; forcedRow = toR; forcedCol = toC; continue; }
            }
            break;
        }
    }

    // Returns [fromRow, fromCol, bestMove] or null if no moves
    hidden function aiPickMove(forced, forcedRow, forcedCol, depth, aiIsWhite) {
        var bestScore = -999999;
        var bestFrom = null; var bestMv = null;

        var anyCap = playerHasCapture(aiIsWhite);

        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var p = _board[r*8+c];
                var isAiPiece = aiIsWhite ? (p == CK_WHITE || p == CK_WKING)
                                          : (p == CK_BLACK || p == CK_BKING);
                if (!isAiPiece) { continue; }
                if (forced && (r != forcedRow || c != forcedCol)) { continue; }

                var moves = anyCap ? getCapturesFor(r, c, p)
                                   : getSimpleMovesFor(r, c, p);
                if (anyCap && moves.size() == 0) { continue; }
                if (!anyCap) {
                    var caps = getCapturesFor(r, c, p);
                    if (caps.size() > 0) { moves = caps; }
                }

                for (var mi = 0; mi < moves.size(); mi++) {
                    var mv = moves[mi];
                    // Save & apply
                    var saved = saveBoardArr();
                    applyAiMove(r, c, p, mv);
                    var score = (depth > 1) ? negamax(depth - 1, -999999, 999999, true)
                                            : evalBoard();
                    restoreBoardArr(saved);
                    if (score > bestScore) { bestScore = score; bestFrom = [r, c]; bestMv = mv; }
                }
            }
        }
        if (bestFrom == null) { return null; }
        return [bestFrom[0], bestFrom[1], bestMv];
    }

    hidden function applyAiMove(fromR, fromC, piece, mv) {
        var toR = mv[0]; var toC = mv[1]; var capR = mv[2]; var capC = mv[3];
        _board[toR*8+toC] = piece;
        _board[fromR*8+fromC] = CK_EMPTY;
        if (capR >= 0) { _board[capR*8+capC] = CK_EMPTY; }
        if (piece == CK_BLACK && toR == 0) { _board[toR*8+toC] = CK_BKING; }
        if (piece == CK_WHITE && toR == 7) { _board[toR*8+toC] = CK_WKING; }
    }

    // Negamax from current player's perspective (positive = good for white when maximizing)
    hidden function negamax(depth, alpha, beta, whiteMax) {
        if (depth == 0) { return evalBoard(); }

        var hasMoves = false;
        var best = whiteMax ? -999999 : 999999;
        var anyCap = playerHasCapture(whiteMax);

        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var p = _board[r*8+c];
                var mine = whiteMax ? (p == CK_WHITE || p == CK_WKING)
                                    : (p == CK_BLACK || p == CK_BKING);
                if (!mine) { continue; }

                var moves = anyCap ? getCapturesFor(r, c, p)
                                   : getSimpleMovesFor(r, c, p);
                if (anyCap && moves.size() == 0) { continue; }
                if (!anyCap) {
                    var caps = getCapturesFor(r, c, p);
                    if (caps.size() > 0) { moves = caps; }
                }

                for (var mi = 0; mi < moves.size(); mi++) {
                    hasMoves = true;
                    var saved = saveBoardArr();
                    applyAiMove(r, c, p, moves[mi]);
                    var s = negamax(depth - 1, alpha, beta, !whiteMax);
                    restoreBoardArr(saved);
                    if (whiteMax) {
                        if (s > best) { best = s; }
                        if (s > alpha) { alpha = s; }
                    } else {
                        if (s < best) { best = s; }
                        if (s < beta) { beta = s; }
                    }
                    if (beta <= alpha) { break; }
                }
            }
        }
        if (!hasMoves) { return whiteMax ? -5000 : 5000; }
        return best;
    }

    hidden function evalBoard() {
        var score = 0;
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                var p = _board[r*8+c];
                if (p == CK_WHITE)  { score += 100 + r * 5; }       // advance bonus
                else if (p == CK_WKING)  { score += 200; }
                else if (p == CK_BLACK)  { score -= 100 + (7-r)*5; }
                else if (p == CK_BKING)  { score -= 200; }
            }
        }
        return score;
    }

    hidden function saveBoardArr() {
        var s = new [64];
        for (var i = 0; i < 64; i++) { s[i] = _board[i]; }
        return s;
    }

    hidden function restoreBoardArr(s) {
        for (var i = 0; i < 64; i++) { _board[i] = s[i]; }
    }

    // ── Rendering ─────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeo(); }
        if (_gs == GS_MENU) { drawMenu(dc); return; }
        drawBoard(dc);
        drawPieces(dc);
        drawHUD(dc);
        if (_gs == GS_WIN)  { drawEndOverlay(dc, "YOU WIN!", 0x44FF88); }
        if (_gs == GS_LOSE) { drawEndOverlay(dc, "YOU LOSE", 0xFF5544); }
        if (_gs == GS_DRAW) { drawEndOverlay(dc, "DRAW", 0xCCCC55); }
        if (_gs == GS_AI_THINK) { drawThinkBadge(dc); }
    }

    // ── Menu ─────────────────────────────────────────────────────────────────
    hidden function drawMenu(dc) {
        dc.setColor(0x0A0A0A, 0x0A0A0A); dc.clear();
        var r = _w / 2;
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);
        if (_sq > 0) {
            for (var row = 0; row < 8; row++) {
                for (var col = 0; col < 8; col++) {
                    var light = ((row + col) % 2 == 0);
                    dc.setColor(light ? 0x1A1208 : 0x0E0A04, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(_ox + col * _sq, _oy + (7-row) * _sq, _sq, _sq);
                }
            }
        }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w/2 - 72, _h/2 - 68, 144, 140, 10);
        dc.setColor(0x882211, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_w/2 - 72, _h/2 - 68, 144, 140, 10);

        dc.setColor(0xFF6633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 62, Graphics.FONT_MEDIUM, "CHECKERS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x775544, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 40, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        var diffLabels = ["Easy", "Normal", "Hard"];
        dc.setColor(0xCCBB88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 23, Graphics.FONT_XTINY, "Diff: " + diffLabels[_difficulty], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x885544, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 9, Graphics.FONT_XTINY, "^ v = change", Graphics.TEXT_JUSTIFY_CENTER);

        // Color buttons
        var btnY  = _h * 63 / 100; var btnH = 22; var btnW = 52;
        var wBtnX = _w / 2 - btnW - 4;
        var bBtnX = _w / 2 + 4;

        dc.setColor(_playerIsWhite ? 0x55AAFF : 0x223344, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(wBtnX, btnY, btnW, btnH, 4);
        dc.setColor(_playerIsWhite ? 0x88CCFF : 0x446688, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(wBtnX, btnY, btnW, btnH, 4);
        dc.setColor(_playerIsWhite ? 0x000000 : 0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(wBtnX + btnW/2, btnY + 5, Graphics.FONT_XTINY, "LIGHT", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(!_playerIsWhite ? 0x55AAFF : 0x223344, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bBtnX, btnY, btnW, btnH, 4);
        dc.setColor(!_playerIsWhite ? 0x88CCFF : 0x446688, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bBtnX, btnY, btnW, btnH, 4);
        dc.setColor(!_playerIsWhite ? 0x000000 : 0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bBtnX + btnW/2, btnY + 5, Graphics.FONT_XTINY, "DARK", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0xFF9944 : 0xAA5522, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 85 / 100, Graphics.FONT_XTINY, "Tap to play!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Board ─────────────────────────────────────────────────────────────────
    hidden function sqToScreen(row, col) {
        var screenRow = _playerIsWhite ? (7 - row) : row;
        var screenCol = _playerIsWhite ? col       : (7 - col);
        return [_ox + screenCol * _sq, _oy + screenRow * _sq];
    }

    hidden function drawBoard(dc) {
        dc.setColor(0x0A0A0A, 0x0A0A0A); dc.clear();
        for (var row = 0; row < 8; row++) {
            for (var col = 0; col < 8; col++) {
                var light = ((row + col) % 2 == 0);
                var xy = sqToScreen(row, col);
                var bx = xy[0]; var by = xy[1];

                var sqClr = light ? 0xD4B077 : 0x7A4020;

                var isDst = false;
                for (var i = 0; i < _validDsts.size(); i++) {
                    if (_validDsts[i][0] == row && _validDsts[i][1] == col) { isDst = true; break; }
                }
                if (isDst) { sqClr = 0x44CC55; }

                dc.setColor(sqClr, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, _sq, _sq);

                if (row == _selRow && col == _selCol) {
                    dc.setColor(0x2266FF, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(bx, by, _sq, _sq);
                    dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(bx, by, _sq, _sq);
                }

                if (row == _curRow && col == _curCol && (row != _selRow || col != _selCol)) {
                    dc.setColor(0x887700, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(bx, by, _sq, _sq);
                }
            }
        }
        dc.setColor(0x443322, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_ox - 1, _oy - 1, _sq * 8 + 2, _sq * 8 + 2);
    }

    // ── Pieces ────────────────────────────────────────────────────────────────
    hidden function drawPieces(dc) {
        var r2 = _sq * 38 / 100;
        var r2k = _sq * 28 / 100;
        for (var row = 0; row < 8; row++) {
            for (var col = 0; col < 8; col++) {
                var p = _board[row*8+col];
                var xy = sqToScreen(row, col);
                var bx = xy[0] + _sq / 2;
                var by = xy[1] + _sq / 2;

                if (p == CK_EMPTY) {
                    var isDst = false;
                    for (var i = 0; i < _validDsts.size(); i++) {
                        if (_validDsts[i][0] == row && _validDsts[i][1] == col) { isDst = true; break; }
                    }
                    if (isDst) {
                        dc.setColor(0x00AA33, Graphics.COLOR_TRANSPARENT);
                        dc.fillCircle(bx, by, _sq / 4);
                    }
                    continue;
                }
                drawChecker(dc, bx, by, p, r2, r2k);
            }
        }
        if (_gs == GS_PLAY && _selRow < 0) {
            var xy2 = sqToScreen(_curRow, _curCol);
            var cx = xy2[0] + _sq / 2;
            var cy = xy2[1] + _sq / 2;
            dc.setColor(0x887700, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r2 + 2);
        }
    }

    hidden function drawChecker(dc, cx, cy, piece, radius, kingR) {
        var isKing = (piece == CK_WKING || piece == CK_BKING);
        var white  = (piece == CK_WHITE || piece == CK_WKING);

        // Shadow
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 1, cy + 2, radius);

        // Outer ring
        dc.setColor(white ? 0xEE9955 : 0xAA2200, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, radius);

        // Inner body
        dc.setColor(white ? 0xF5DDB0 : 0xCC3311, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, radius - 2);

        // Highlight gloss
        dc.setColor(white ? 0xFFFFEE : 0xFF7755, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - radius/4, cy - radius/4, radius/3);

        // King crown indicator
        if (isKing) {
            dc.setColor(0xFFEE00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, kingR);
            dc.setColor(white ? 0x664400 : 0x220000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - kingR + 1, Graphics.FONT_XTINY, "K", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── HUD ───────────────────────────────────────────────────────────────────
    hidden function drawHUD(dc) {
        var hy = _oy + _sq * 8 + 3;
        if (hy + 12 > _h) { hy = _oy - 12; }
        var isPlayerTurn = _playerIsWhite ? _whiteTurn : !_whiteTurn;
        var lbl = isPlayerTurn ? "Your turn" : "AI thinking...";
        if (_mustRow >= 0) { lbl = "Continue jump!"; }
        dc.setColor(0xAA8866, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, hy, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawEndOverlay(dc, msg, clr) {
        var blink = (_tick % 8 < 5);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w/2 - 64, _h/2 - 24, 128, 48, 8);
        dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_w/2 - 64, _h/2 - 24, 128, 48, 8);
        dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 20, Graphics.FONT_MEDIUM, msg, Graphics.TEXT_JUSTIFY_CENTER);
        if (blink) {
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _h/2 + 8, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawThinkBadge(dc) {
        var dots = "";
        for (var i = 0; i < (_tick % 4); i++) { dots = dots + "."; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w/2 - 44, _h - 22, 88, 18, 4);
        dc.setColor(0xFF9944, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h - 20, Graphics.FONT_XTINY, "AI" + dots, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
