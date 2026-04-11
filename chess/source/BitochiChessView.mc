using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Piece constants ───────────────────────────────────────────────────────────
// Positive = White, Negative = Black, 0 = Empty
const PC_EMPTY  = 0;
const PC_PAWN   = 1;
const PC_KNIGHT = 2;
const PC_BISHOP = 3;
const PC_ROOK   = 4;
const PC_QUEEN  = 5;
const PC_KING   = 6;

// ── Game states ───────────────────────────────────────────────────────────────
const CS_MENU       = 0;
const CS_PLAY       = 1;
const CS_AI_THINK   = 2;
const CS_CHECKMATE  = 3;
const CS_STALEMATE  = 4;
const CS_PROMOTE    = 5;

class BitochiChessView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    // Board: 64 cells, rank 0 = rank-1 (white side), file 0 = a-file
    // board[rank*8 + file]
    hidden var _board;

    // Game metadata
    hidden var _whiteToMove;     // true = player's turn (white)
    hidden var _castleRights;    // bits: 0=WK, 1=WQ, 2=BK, 3=BQ
    hidden var _enPassant;       // target square index or -1
    hidden var _halfMove;        // for 50-move rule
    hidden var _moveCount;
    hidden var _inCheck;

    // Selection / cursor
    hidden var _selSq;   // selected square (-1 = none)
    hidden var _curSq;   // cursor square
    hidden var _legalMoves; // array of [from,to,flags] for selected piece

    // Promotion
    hidden var _promSq;   // square where promotion happens
    hidden var _promPick; // 0=Q,1=R,2=B,3=N

    // Geometry
    hidden var _ox; hidden var _oy;  // board top-left offset
    hidden var _sq;                   // square size in pixels

    // AI
    hidden var _aiDepth;
    hidden var _aiMove;   // [from,to,flags] or null
    hidden var _aiTimer;  // frames before AI moves

    // Status message
    hidden var _statusMsg;
    hidden var _statusTick;

    // Difficulty + color choice
    hidden var _difficulty; // 0=Easy(d2) 1=Normal(d3) 2=Hard(d4)
    hidden var _playerIsWhite; // true = player plays white (default)

    // ── Piece value table for evaluation ─────────────────────────────────────
    hidden var _pieceVal;

    // ── Initialize ────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _w = 0; _h = 0; _tick = 0;
        _gs = CS_MENU;
        _difficulty = 1;
        _playerIsWhite = true;
        _selSq = -1; _curSq = 36; // e4 area
        _legalMoves = new [0];
        _promSq = -1; _promPick = 0;
        _aiMove = null; _aiTimer = 0;
        _statusMsg = ""; _statusTick = 0;
        _ox = 0; _oy = 0; _sq = 0;

        _pieceVal = [0, 100, 320, 330, 500, 900, 20000];

        _board = new [64];
        setupBoard();

        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 200, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupGeometry();
    }

    hidden function setupGeometry() {
        // Square: fit 8 columns in ~90% of smaller dimension
        _sq = _w * 88 / 100 / 8;
        if (_sq > _h * 88 / 100 / 8) { _sq = _h * 88 / 100 / 8; }
        _ox = (_w - _sq * 8) / 2;
        _oy = (_h - _sq * 8) / 2;
    }

    // ── Board setup ───────────────────────────────────────────────────────────
    hidden function setupBoard() {
        for (var i = 0; i < 64; i++) { _board[i] = PC_EMPTY; }
        // White pieces — rank 0 (index 0-7)
        _board[0]  =  PC_ROOK;   _board[1]  =  PC_KNIGHT; _board[2]  =  PC_BISHOP;
        _board[3]  =  PC_QUEEN;  _board[4]  =  PC_KING;   _board[5]  =  PC_BISHOP;
        _board[6]  =  PC_KNIGHT; _board[7]  =  PC_ROOK;
        for (var f = 0; f < 8; f++) { _board[8 + f]  =  PC_PAWN; }
        // Black pieces — rank 7 (index 56-63)
        _board[56] = -PC_ROOK;   _board[57] = -PC_KNIGHT; _board[58] = -PC_BISHOP;
        _board[59] = -PC_QUEEN;  _board[60] = -PC_KING;   _board[61] = -PC_BISHOP;
        _board[62] = -PC_KNIGHT; _board[63] = -PC_ROOK;
        for (var f = 0; f < 8; f++) { _board[48 + f] = -PC_PAWN; }

        _whiteToMove = true;
        _castleRights = 0xF; // all rights
        _enPassant = -1;
        _halfMove = 0; _moveCount = 1;
        _inCheck = false;
        _selSq = -1; _legalMoves = new [0];
    }

    // ── Timer ─────────────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        if (_statusTick > 0) { _statusTick--; }
        if (_gs == CS_AI_THINK) {
            _aiTimer--;
            if (_aiTimer <= 0) { doAiMove(); }
        }
        WatchUi.requestUpdate();
    }

    // ── Input ─────────────────────────────────────────────────────────────────
    function doUp() {
        if (_gs == CS_MENU) { _difficulty = (_difficulty + 2) % 3; return; }
        if (_gs == CS_PROMOTE) { _promPick = (_promPick + 3) % 4; return; }
        if (_gs != CS_PLAY) { return; }
        var r = _curSq / 8; var f = _curSq % 8;
        if (_playerIsWhite) { if (r < 7) { _curSq = (r + 1) * 8 + f; } }
        else                { if (r > 0) { _curSq = (r - 1) * 8 + f; } }
    }

    function doDown() {
        if (_gs == CS_MENU) { _difficulty = (_difficulty + 1) % 3; return; }
        if (_gs == CS_PROMOTE) { _promPick = (_promPick + 1) % 4; return; }
        if (_gs != CS_PLAY) { return; }
        var r = _curSq / 8; var f = _curSq % 8;
        if (_playerIsWhite) { if (r > 0) { _curSq = (r - 1) * 8 + f; } }
        else                { if (r < 7) { _curSq = (r + 1) * 8 + f; } }
    }

    function doSelect() {
        if (_gs == CS_MENU) { startGame(); return; }
        if (_gs == CS_CHECKMATE || _gs == CS_STALEMATE) { _gs = CS_MENU; return; }
        if (_gs == CS_PROMOTE)  { confirmPromotion(); return; }
        if (_gs != CS_PLAY) { return; }
        handleSquare(_curSq);
    }

    function doBack() {
        if (_gs == CS_PLAY || _gs == CS_CHECKMATE || _gs == CS_STALEMATE) {
            _gs = CS_MENU; _selSq = -1; _legalMoves = new [0];
        }
    }

    function doMenu() { doBack(); }

    function doTap(tx, ty) {
        if (_gs == CS_MENU) {
            // Check if tapping the color toggle buttons
            var btnY = _h * 65 / 100; var btnH = 22; var btnW = 56;
            var wBtnX = _w / 2 - btnW - 4;
            var bBtnX = _w / 2 + 4;
            if (ty >= btnY && ty < btnY + btnH) {
                if (tx >= wBtnX && tx < wBtnX + btnW) { _playerIsWhite = true; return; }
                if (tx >= bBtnX && tx < bBtnX + btnW) { _playerIsWhite = false; return; }
            }
            startGame(); return;
        }
        if (_gs == CS_CHECKMATE || _gs == CS_STALEMATE) { _gs = CS_MENU; return; }
        if (_gs == CS_AI_THINK) { return; }

        if (_gs == CS_PROMOTE) {
            var bw = _sq * 2; var bh = _sq;
            var px = _w / 2 - bw;
            for (var i = 0; i < 4; i++) {
                var bx = px + i * bw / 2;
                if (tx >= bx && tx < bx + bw/2 && ty >= _h/2 - bh/2 && ty < _h/2 + bh/2) {
                    _promPick = i; confirmPromotion(); return;
                }
            }
            return;
        }

        if (_gs != CS_PLAY) { return; }
        if (_sq <= 0) { return; }
        var sq = tapToSq(tx, ty);
        if (sq >= 0) { _curSq = sq; handleSquare(sq); }
    }

    hidden function tapToSq(tx, ty) {
        if (tx < _ox || tx >= _ox + _sq * 8) { return -1; }
        if (ty < _oy || ty >= _oy + _sq * 8) { return -1; }
        var f = (tx - _ox) / _sq;
        var rInv = (ty - _oy) / _sq;
        if (f < 0 || f >= 8 || rInv < 0 || rInv >= 8) { return -1; }
        // When playing white: rank 7 at top; when playing black: rank 0 at top (board flipped)
        var r = _playerIsWhite ? (7 - rInv) : rInv;
        // File also flips when playing black
        var fl = _playerIsWhite ? f : (7 - f);
        return r * 8 + fl;
    }

    // ── Core game logic ───────────────────────────────────────────────────────
    hidden function handleSquare(sq) {
        // Only allow input when it's the player's turn
        if (_whiteToMove != _playerIsWhite) { return; }

        var piece = _board[sq];
        var isOwnPiece = _playerIsWhite ? (piece > 0) : (piece < 0);

        if (_selSq < 0) {
            // Select own piece
            if (isOwnPiece) {
                var moves = genLegalMovesFor(sq);
                if (moves.size() > 0) { _selSq = sq; _legalMoves = moves; }
            }
        } else {
            // Try to execute a move from _selSq to sq
            var moved = false;
            for (var i = 0; i < _legalMoves.size(); i++) {
                var mv = _legalMoves[i];
                if (mv[1] == sq) {
                    executeMove(mv);
                    moved = true;
                    break;
                }
            }
            if (!moved) {
                // Maybe select a different own piece
                _selSq = -1; _legalMoves = new [0];
                if (isOwnPiece) {
                    var moves2 = genLegalMovesFor(sq);
                    if (moves2.size() > 0) { _selSq = sq; _legalMoves = moves2; }
                }
            }
        }
    }

    hidden function startGame() {
        setupBoard();
        _gs = CS_PLAY;
        _aiDepth = 2 + _difficulty;
        _selSq = -1;
        _curSq = _playerIsWhite ? 4 : 60; // start cursor on king
        _statusMsg = "";
        // If player plays black, AI (white) goes first
        if (!_playerIsWhite) {
            _gs = CS_AI_THINK;
            _aiTimer = 2;
        }
    }

    // ── Move execution ────────────────────────────────────────────────────────
    // Flags: 0=normal, 1=double pawn push, 2=en-passant capture,
    //        3=castle-K, 4=castle-Q, 5=promotion(stored piece in [2])
    hidden function executeMove(mv) {
        var from = mv[0]; var to = mv[1]; var flags = mv[2];
        var piece = _board[from];
        var captured = _board[to];
        var absPiece = piece > 0 ? piece : -piece;

        _board[to] = piece; _board[from] = PC_EMPTY;

        // En-passant capture
        if (flags == 2) {
            var epFile = to % 8; var epRank = from / 8;
            _board[epRank * 8 + epFile] = PC_EMPTY;
        }

        // Double pawn push — set en passant target
        _enPassant = -1;
        if (flags == 1) {
            _enPassant = (from + to) / 2; // square between from and to
        }

        // Castling
        if (flags == 3) { // king-side
            var rank = from / 8;
            _board[rank * 8 + 5] = _board[rank * 8 + 7]; _board[rank * 8 + 7] = PC_EMPTY;
        }
        if (flags == 4) { // queen-side
            var rank = from / 8;
            _board[rank * 8 + 3] = _board[rank * 8 + 0]; _board[rank * 8 + 0] = PC_EMPTY;
        }

        // Promotion
        if (flags == 5) {
            var promPiece = mv[3];
            _board[to] = (piece > 0) ? promPiece : -promPiece;
        }

        // Update castle rights
        if (absPiece == PC_KING) {
            if (piece > 0) { _castleRights = _castleRights & ~3; }
            else           { _castleRights = _castleRights & ~12; }
        }
        if (from == 0  || to == 0)  { _castleRights = _castleRights & ~2; }
        if (from == 7  || to == 7)  { _castleRights = _castleRights & ~1; }
        if (from == 56 || to == 56) { _castleRights = _castleRights & ~8; }
        if (from == 63 || to == 63) { _castleRights = _castleRights & ~4; }

        // Half-move clock
        if (absPiece == PC_PAWN || captured != PC_EMPTY) { _halfMove = 0; } else { _halfMove++; }

        _whiteToMove = !_whiteToMove;
        if (!_whiteToMove) { _moveCount++; }

        _selSq = -1; _legalMoves = new [0];

        // Check for promotion (flags==5 handled above; pawn on back rank without flag)
        if (flags != 5 && absPiece == PC_PAWN) {
            var toRank = to / 8;
            if ((piece > 0 && toRank == 7) || (piece < 0 && toRank == 0)) {
                _promSq = to;
                _gs = CS_PROMOTE;
                return;
            }
        }

        _inCheck = isInCheck(_whiteToMove);
        afterMove();
    }

    hidden function afterMove() {
        // Check game over for current player
        var allMoves = genAllLegalMoves(_whiteToMove);
        if (allMoves.size() == 0) {
            if (_inCheck) { _gs = CS_CHECKMATE; }
            else          { _gs = CS_STALEMATE; }
            return;
        }
        // Is it the player's turn or AI's?
        if (_whiteToMove == _playerIsWhite) {
            _gs = CS_PLAY; // player's turn
        } else {
            _gs = CS_AI_THINK;
            _aiTimer = 2;
        }
    }

    hidden function confirmPromotion() {
        var promPieces = [PC_QUEEN, PC_ROOK, PC_BISHOP, PC_KNIGHT];
        var pp = promPieces[_promPick];
        var piece = _board[_promSq];
        _board[_promSq] = (piece > 0) ? pp : -pp;
        _promSq = -1;
        _gs = CS_PLAY;
        _inCheck = isInCheck(_whiteToMove);
        afterMove();
    }

    // ── AI ────────────────────────────────────────────────────────────────────
    hidden function doAiMove() {
        var aiIsWhite = !_playerIsWhite; // AI plays opposite color
        var moves = genAllLegalMoves(aiIsWhite);
        if (moves.size() == 0) {
            _inCheck = isInCheck(aiIsWhite);
            if (_inCheck) { _gs = CS_CHECKMATE; } else { _gs = CS_STALEMATE; }
            return;
        }

        var bestScore = aiIsWhite ? -999999 : 999999;
        var bestMv = moves[0];

        for (var i = 0; i < moves.size(); i++) {
            var mv = moves[i];
            var saved = saveBoardState();
            applyMove(mv);
            var score = minimax(_aiDepth - 1, -999999, 999999, !aiIsWhite);
            restoreBoardState(saved);
            if (aiIsWhite && score > bestScore) { bestScore = score; bestMv = mv; }
            if (!aiIsWhite && score < bestScore) { bestScore = score; bestMv = mv; }
        }

        applyMove(bestMv);
        _whiteToMove = _playerIsWhite; // back to player

        // Handle pawn promotion for AI — auto-queen
        var to = bestMv[1];
        var piece = _board[to];
        if (aiIsWhite && piece == PC_PAWN  && to / 8 == 7) { _board[to] =  PC_QUEEN; }
        if (!aiIsWhite && piece == -PC_PAWN && to / 8 == 0) { _board[to] = -PC_QUEEN; }

        _inCheck = isInCheck(_playerIsWhite);
        _gs = CS_PLAY;

        var allPlayerMoves = genAllLegalMoves(_playerIsWhite);
        if (allPlayerMoves.size() == 0) {
            if (_inCheck) { _gs = CS_CHECKMATE; } else { _gs = CS_STALEMATE; }
        }
    }

    hidden function minimax(depth, alpha, beta, maximizing) {
        if (depth == 0) { return evaluate(); }

        var moves = genAllLegalMoves(maximizing);
        if (moves.size() == 0) {
            if (isInCheck(maximizing)) {
                return maximizing ? -30000 + depth : 30000 - depth;
            }
            return 0; // stalemate
        }

        if (maximizing) {
            var best = -999999;
            for (var i = 0; i < moves.size(); i++) {
                var saved = saveBoardState();
                applyMove(moves[i]);
                var s = minimax(depth - 1, alpha, beta, false);
                restoreBoardState(saved);
                if (s > best) { best = s; }
                if (s > alpha) { alpha = s; }
                if (beta <= alpha) { break; }
            }
            return best;
        } else {
            var best = 999999;
            for (var i = 0; i < moves.size(); i++) {
                var saved = saveBoardState();
                applyMove(moves[i]);
                var s = minimax(depth - 1, alpha, beta, true);
                restoreBoardState(saved);
                if (s < best) { best = s; }
                if (s < beta) { beta = s; }
                if (beta <= alpha) { break; }
            }
            return best;
        }
    }

    // Evaluation: positive = good for white
    hidden function evaluate() {
        var score = 0;
        for (var sq = 0; sq < 64; sq++) {
            var p = _board[sq];
            if (p == PC_EMPTY) { continue; }
            var abs = p > 0 ? p : -p;
            var val = _pieceVal[abs];
            // Piece-square bonus (simplified — encourage center control)
            var r = sq / 8; var f = sq % 8;
            var centerBonus = 0;
            if (f >= 2 && f <= 5 && r >= 2 && r <= 5) { centerBonus = 5; }
            if (f >= 3 && f <= 4 && r >= 3 && r <= 4) { centerBonus = 10; }
            if (p > 0) { score += val + centerBonus; }
            else       { score -= val + centerBonus; }
        }
        return score;
    }

    // Fast board apply/restore for minimax (no castling rights tracking needed internally)
    hidden function applyMove(mv) {
        var from = mv[0]; var to = mv[1]; var flags = mv[2];
        var piece = _board[from];
        _board[to] = piece; _board[from] = PC_EMPTY;
        if (flags == 2) { // en-passant
            var epFile = to % 8; var epRank = from / 8;
            _board[epRank * 8 + epFile] = PC_EMPTY;
        }
        if (flags == 3) { var rk = from/8; _board[rk*8+5]=_board[rk*8+7]; _board[rk*8+7]=PC_EMPTY; }
        if (flags == 4) { var rk = from/8; _board[rk*8+3]=_board[rk*8+0]; _board[rk*8+0]=PC_EMPTY; }
        if (flags == 5 && mv.size() > 3) { var pp = mv[3]; _board[to] = (piece>0)?pp:-pp; }
        // Auto-queen for search promotions
        var abs = piece > 0 ? piece : -piece;
        if (abs == PC_PAWN) {
            var tr = to / 8;
            if ((piece > 0 && tr == 7) || (piece < 0 && tr == 0)) {
                _board[to] = (piece > 0) ? PC_QUEEN : -PC_QUEEN;
            }
        }
        _enPassant = (flags == 1) ? (from + to) / 2 : -1;
        _whiteToMove = !_whiteToMove;
    }

    hidden function saveBoardState() {
        var s = new [68];
        for (var i = 0; i < 64; i++) { s[i] = _board[i]; }
        s[64] = _castleRights;
        s[65] = _enPassant;
        s[66] = _whiteToMove ? 1 : 0;
        s[67] = _halfMove;
        return s;
    }

    hidden function restoreBoardState(s) {
        for (var i = 0; i < 64; i++) { _board[i] = s[i]; }
        _castleRights = s[64];
        _enPassant    = s[65];
        _whiteToMove  = (s[66] == 1);
        _halfMove     = s[67];
    }

    // ── Move generation ───────────────────────────────────────────────────────
    hidden function genAllLegalMoves(white) {
        var result = new [0];
        for (var sq = 0; sq < 64; sq++) {
            var p = _board[sq];
            if (white && p > 0) {
                var moves = genLegalMovesFor(sq);
                for (var i = 0; i < moves.size(); i++) {
                    var nm = new [result.size() + 1];
                    for (var j = 0; j < result.size(); j++) { nm[j] = result[j]; }
                    nm[result.size()] = moves[i];
                    result = nm;
                }
            } else if (!white && p < 0) {
                var moves = genLegalMovesFor(sq);
                for (var i = 0; i < moves.size(); i++) {
                    var nm = new [result.size() + 1];
                    for (var j = 0; j < result.size(); j++) { nm[j] = result[j]; }
                    nm[result.size()] = moves[i];
                    result = nm;
                }
            }
        }
        return result;
    }

    hidden function genLegalMovesFor(sq) {
        var pseudo = genPseudoMoves(sq);
        var legal  = new [0];
        var piece  = _board[sq];
        var white  = (piece > 0);
        for (var i = 0; i < pseudo.size(); i++) {
            var mv = pseudo[i];
            var saved = saveBoardState();
            applyMove(mv);
            if (!isInCheck(white)) {
                var nm = new [legal.size() + 1];
                for (var j = 0; j < legal.size(); j++) { nm[j] = legal[j]; }
                nm[legal.size()] = mv;
                legal = nm;
            }
            restoreBoardState(saved);
        }
        return legal;
    }

    hidden function genPseudoMoves(sq) {
        var piece  = _board[sq];
        if (piece == PC_EMPTY) { return new [0]; }
        var white  = (piece > 0);
        var abs    = white ? piece : -piece;
        var moves  = new [0];

        if (abs == PC_PAWN)   { moves = pawnMoves(sq, white); }
        if (abs == PC_KNIGHT) { moves = knightMoves(sq, white); }
        if (abs == PC_BISHOP) { moves = slideMoves(sq, white, true,  false); }
        if (abs == PC_ROOK)   { moves = slideMoves(sq, white, false, true); }
        if (abs == PC_QUEEN)  { moves = slideMoves(sq, white, true,  true); }
        if (abs == PC_KING)   { moves = kingMoves(sq, white); }
        return moves;
    }

    hidden function addMove(moves, from, to, flags) {
        var mv = [from, to, flags];
        var nm = new [moves.size() + 1];
        for (var i = 0; i < moves.size(); i++) { nm[i] = moves[i]; }
        nm[moves.size()] = mv;
        return nm;
    }

    hidden function addPromoMoves(moves, from, to) {
        var pieces = [PC_QUEEN, PC_ROOK, PC_BISHOP, PC_KNIGHT];
        for (var i = 0; i < 4; i++) {
            var mv = [from, to, 5, pieces[i]];
            var nm = new [moves.size() + 1];
            for (var j = 0; j < moves.size(); j++) { nm[j] = moves[j]; }
            nm[moves.size()] = mv;
            moves = nm;
        }
        return moves;
    }

    hidden function pawnMoves(sq, white) {
        var moves = new [0];
        var r = sq / 8; var f = sq % 8;
        var dir = white ? 1 : -1;
        var startRank = white ? 1 : 6;
        var promoRank = white ? 6 : 1; // rank from which promotion happens next move

        // Push one forward
        var to = (r + dir) * 8 + f;
        if (to >= 0 && to < 64 && _board[to] == PC_EMPTY) {
            if (r + dir == (white ? 7 : 0)) {
                moves = addPromoMoves(moves, sq, to);
            } else {
                moves = addMove(moves, sq, to, 0);
                // Double push from start
                if (r == startRank) {
                    var to2 = (r + dir * 2) * 8 + f;
                    if (_board[to2] == PC_EMPTY) { moves = addMove(moves, sq, to2, 1); }
                }
            }
        }

        // Captures
        var capFiles = new [0];
        if (f > 0) { capFiles = addIntArr(capFiles, f - 1); }
        if (f < 7) { capFiles = addIntArr(capFiles, f + 1); }
        for (var ci = 0; ci < capFiles.size(); ci++) {
            var cf = capFiles[ci];
            var capTo = (r + dir) * 8 + cf;
            if (capTo < 0 || capTo >= 64) { continue; }
            var target = _board[capTo];
            if (target != PC_EMPTY && ((white && target < 0) || (!white && target > 0))) {
                if (r + dir == (white ? 7 : 0)) {
                    moves = addPromoMoves(moves, sq, capTo);
                } else {
                    moves = addMove(moves, sq, capTo, 0);
                }
            }
            // En-passant
            if (capTo == _enPassant) { moves = addMove(moves, sq, capTo, 2); }
        }
        return moves;
    }

    hidden function addIntArr(arr, v) {
        var n = new [arr.size() + 1];
        for (var i = 0; i < arr.size(); i++) { n[i] = arr[i]; }
        n[arr.size()] = v;
        return n;
    }

    hidden function knightMoves(sq, white) {
        var moves = new [0];
        var r = sq / 8; var f = sq % 8;
        var deltas = [[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]];
        for (var i = 0; i < deltas.size(); i++) {
            var nr = r + deltas[i][0]; var nf = f + deltas[i][1];
            if (nr < 0 || nr >= 8 || nf < 0 || nf >= 8) { continue; }
            var to = nr * 8 + nf;
            var t = _board[to];
            if (t == PC_EMPTY || (white && t < 0) || (!white && t > 0)) {
                moves = addMove(moves, sq, to, 0);
            }
        }
        return moves;
    }

    hidden function slideMoves(sq, white, diag, straight) {
        var moves = new [0];
        var r = sq / 8; var f = sq % 8;
        var dirs = new [0];
        if (straight) {
            dirs = addArrOfPairs(dirs, [0,1]); dirs = addArrOfPairs(dirs, [0,-1]);
            dirs = addArrOfPairs(dirs, [1,0]); dirs = addArrOfPairs(dirs, [-1,0]);
        }
        if (diag) {
            dirs = addArrOfPairs(dirs, [1,1]);  dirs = addArrOfPairs(dirs, [1,-1]);
            dirs = addArrOfPairs(dirs, [-1,1]); dirs = addArrOfPairs(dirs, [-1,-1]);
        }
        for (var di = 0; di < dirs.size(); di++) {
            var dr = dirs[di][0]; var df = dirs[di][1];
            var nr = r + dr; var nf = f + df;
            while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
                var to = nr * 8 + nf;
                var t = _board[to];
                if (t == PC_EMPTY) {
                    moves = addMove(moves, sq, to, 0);
                } else if ((white && t < 0) || (!white && t > 0)) {
                    moves = addMove(moves, sq, to, 0); break;
                } else { break; }
                nr += dr; nf += df;
            }
        }
        return moves;
    }

    hidden function addArrOfPairs(arr, pair) {
        var n = new [arr.size() + 1];
        for (var i = 0; i < arr.size(); i++) { n[i] = arr[i]; }
        n[arr.size()] = pair;
        return n;
    }

    hidden function kingMoves(sq, white) {
        var moves = new [0];
        var r = sq / 8; var f = sq % 8;
        for (var dr = -1; dr <= 1; dr++) {
            for (var df = -1; df <= 1; df++) {
                if (dr == 0 && df == 0) { continue; }
                var nr = r + dr; var nf = f + df;
                if (nr < 0 || nr >= 8 || nf < 0 || nf >= 8) { continue; }
                var to = nr * 8 + nf;
                var t = _board[to];
                if (t == PC_EMPTY || (white && t < 0) || (!white && t > 0)) {
                    moves = addMove(moves, sq, to, 0);
                }
            }
        }
        // Castling
        if (white && r == 0) {
            // King-side: rights bit 0, squares f1 g1 empty, not in check, not passing through
            if ((_castleRights & 1) != 0 && _board[5] == PC_EMPTY && _board[6] == PC_EMPTY) {
                if (!isInCheck(true) && !sqAttacked(5, false) && !sqAttacked(6, false)) {
                    moves = addMove(moves, sq, sq + 2, 3);
                }
            }
            // Queen-side: rights bit 1
            if ((_castleRights & 2) != 0 && _board[1] == PC_EMPTY && _board[2] == PC_EMPTY && _board[3] == PC_EMPTY) {
                if (!isInCheck(true) && !sqAttacked(3, false) && !sqAttacked(2, false)) {
                    moves = addMove(moves, sq, sq - 2, 4);
                }
            }
        }
        if (!white && r == 7) {
            if ((_castleRights & 4) != 0 && _board[61] == PC_EMPTY && _board[62] == PC_EMPTY) {
                if (!isInCheck(false) && !sqAttacked(61, true) && !sqAttacked(62, true)) {
                    moves = addMove(moves, sq, sq + 2, 3);
                }
            }
            if ((_castleRights & 8) != 0 && _board[57] == PC_EMPTY && _board[58] == PC_EMPTY && _board[59] == PC_EMPTY) {
                if (!isInCheck(false) && !sqAttacked(59, true) && !sqAttacked(58, true)) {
                    moves = addMove(moves, sq, sq - 2, 4);
                }
            }
        }
        return moves;
    }

    // Is the current player (white/black) in check?
    hidden function isInCheck(white) {
        // Find king
        var kingPiece = white ? PC_KING : -PC_KING;
        var kingSq = -1;
        for (var i = 0; i < 64; i++) { if (_board[i] == kingPiece) { kingSq = i; break; } }
        if (kingSq < 0) { return true; } // king captured (shouldn't happen in legal play)
        return sqAttacked(kingSq, !white); // attacked by opponent?
    }

    // Is square attacked by the given color?
    hidden function sqAttacked(sq, byWhite) {
        var r = sq / 8; var f = sq % 8;

        // Check pawn attacks
        var dir = byWhite ? -1 : 1;
        var pawnPiece = byWhite ? PC_PAWN : -PC_PAWN;
        if (f > 0) {
            var ps = (r + dir) * 8 + (f - 1);
            if (ps >= 0 && ps < 64 && _board[ps] == pawnPiece) { return true; }
        }
        if (f < 7) {
            var ps = (r + dir) * 8 + (f + 1);
            if (ps >= 0 && ps < 64 && _board[ps] == pawnPiece) { return true; }
        }

        // Knight attacks
        var knightPiece = byWhite ? PC_KNIGHT : -PC_KNIGHT;
        var kDeltas = [[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]];
        for (var i = 0; i < kDeltas.size(); i++) {
            var nr = r + kDeltas[i][0]; var nf = f + kDeltas[i][1];
            if (nr >= 0 && nr < 8 && nf >= 0 && nf < 8 && _board[nr*8+nf] == knightPiece) { return true; }
        }

        // Sliding: bishop/queen (diagonals)
        var bqW = byWhite ? PC_BISHOP : -PC_BISHOP;
        var qW  = byWhite ? PC_QUEEN  : -PC_QUEEN;
        var diagDirs = [[1,1],[1,-1],[-1,1],[-1,-1]];
        for (var di = 0; di < diagDirs.size(); di++) {
            var nr = r + diagDirs[di][0]; var nf = f + diagDirs[di][1];
            while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
                var t = _board[nr*8+nf];
                if (t != PC_EMPTY) {
                    if (t == bqW || t == qW) { return true; }
                    break;
                }
                nr += diagDirs[di][0]; nf += diagDirs[di][1];
            }
        }

        // Sliding: rook/queen (straights)
        var rqW = byWhite ? PC_ROOK : -PC_ROOK;
        var strDirs = [[0,1],[0,-1],[1,0],[-1,0]];
        for (var di = 0; di < strDirs.size(); di++) {
            var nr = r + strDirs[di][0]; var nf = f + strDirs[di][1];
            while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
                var t = _board[nr*8+nf];
                if (t != PC_EMPTY) {
                    if (t == rqW || t == qW) { return true; }
                    break;
                }
                nr += strDirs[di][0]; nf += strDirs[di][1];
            }
        }

        // King proximity
        var kingPiece2 = byWhite ? PC_KING : -PC_KING;
        for (var dr = -1; dr <= 1; dr++) {
            for (var df = -1; df <= 1; df++) {
                if (dr == 0 && df == 0) { continue; }
                var kr = r + dr; var kf = f + df;
                if (kr >= 0 && kr < 8 && kf >= 0 && kf < 8 && _board[kr*8+kf] == kingPiece2) { return true; }
            }
        }
        return false;
    }

    // ── Rendering ─────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeometry(); }
        if (_gs == CS_MENU)  { drawMenu(dc); return; }
        drawGame(dc);
        if (_gs == CS_PROMOTE)   { drawPromoOverlay(dc); }
        if (_gs == CS_AI_THINK)  { drawThinkingBadge(dc); }
        if (_gs == CS_CHECKMATE) { drawEndOverlay(dc, _whiteToMove ? "CHECKMATE\nBlack wins" : "CHECKMATE\nYou lose"); }
        if (_gs == CS_STALEMATE) { drawEndOverlay(dc, "STALEMATE\nDraw"); }
    }

    // ── Menu ─────────────────────────────────────────────────────────────────
    hidden function drawMenu(dc) {
        dc.setColor(0x080808, 0x080808); dc.clear();
        var r = _w / 2;

        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);
        for (var row = 0; row < 8; row++) {
            for (var col = 0; col < 8; col++) {
                var light = ((row + col) % 2 == 0);
                dc.setColor(light ? 0x1A1208 : 0x0E0A05, Graphics.COLOR_TRANSPARENT);
                var bx = _ox + col * _sq; var by = _oy + (7 - row) * _sq;
                if (_sq > 0) { dc.fillRectangle(bx, by, _sq, _sq); }
            }
        }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w/2 - 72, _h/2 - 68, 144, 140, 10);
        dc.setColor(0x885522, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_w/2 - 72, _h/2 - 68, 144, 140, 10);

        dc.setColor(0xFFDD88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 62, Graphics.FONT_MEDIUM, "CHESS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x887766, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 38, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        var diffLabels = ["Easy", "Normal", "Hard"];
        dc.setColor(0xCCBB88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 20, Graphics.FONT_XTINY, "Diff: " + diffLabels[_difficulty], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x886655, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 6, Graphics.FONT_XTINY, "^ v = change", Graphics.TEXT_JUSTIFY_CENTER);

        // Color selection buttons
        var btnY  = _h * 65 / 100; var btnH = 22; var btnW = 56;
        var wBtnX = _w / 2 - btnW - 4;
        var bBtnX = _w / 2 + 4;

        dc.setColor(_playerIsWhite ? 0x55AAFF : 0x223344, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(wBtnX, btnY, btnW, btnH, 4);
        dc.setColor(_playerIsWhite ? 0x88CCFF : 0x446688, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(wBtnX, btnY, btnW, btnH, 4);
        dc.setColor(_playerIsWhite ? 0x000000 : 0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(wBtnX + btnW/2, btnY + 5, Graphics.FONT_XTINY, "WHITE", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(!_playerIsWhite ? 0x55AAFF : 0x223344, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bBtnX, btnY, btnW, btnH, 4);
        dc.setColor(!_playerIsWhite ? 0x88CCFF : 0x446688, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bBtnX, btnY, btnW, btnH, 4);
        dc.setColor(!_playerIsWhite ? 0x000000 : 0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bBtnX + btnW/2, btnY + 5, Graphics.FONT_XTINY, "BLACK", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0xFFCC55 : 0xAA8833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 85 / 100, Graphics.FONT_XTINY, "Tap to play!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game board ────────────────────────────────────────────────────────────
    hidden function sqToScreen(sq) {
        // Returns [bx, by] top-left pixel of square
        var r = sq / 8; var f = sq % 8;
        var screenRow = _playerIsWhite ? (7 - r) : r;
        var screenCol = _playerIsWhite ? f       : (7 - f);
        return [_ox + screenCol * _sq, _oy + screenRow * _sq];
    }

    hidden function drawGame(dc) {
        dc.setColor(0x080808, 0x080808); dc.clear();

        // Draw board squares
        for (var row = 0; row < 8; row++) {
            for (var col = 0; col < 8; col++) {
                var light = ((row + col) % 2 == 0);
                var sq = row * 8 + col;
                var xy = sqToScreen(sq);
                var bx = xy[0]; var by = xy[1];

                var sqColor = light ? 0xD4B077 : 0x8B5E2C;

                // Highlight: legal move targets
                var isLegal = false;
                for (var mi = 0; mi < _legalMoves.size(); mi++) {
                    if (_legalMoves[mi][1] == sq) { isLegal = true; break; }
                }
                if (isLegal) { sqColor = light ? 0xAADD88 : 0x558833; }
                if (sq == _selSq)  { sqColor = 0x3377EE; }
                if (sq == _curSq && _gs == CS_PLAY) { sqColor = light ? 0xFFEE77 : 0xCCAA44; }

                dc.setColor(sqColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, _sq, _sq);

                // Check highlight on king
                if (_inCheck) {
                    var kPiece = _whiteToMove ? PC_KING : -PC_KING;
                    if (_board[sq] == kPiece) {
                        dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
                        dc.fillRectangle(bx, by, _sq, _sq);
                    }
                }

                // Destination dot on legal empty squares
                if (isLegal && _board[sq] == PC_EMPTY) {
                    dc.setColor(0x226600, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(bx + _sq/2, by + _sq/2, _sq/5);
                }

                drawPiece(dc, bx, by, _board[sq]);
            }
        }

        // Board border
        dc.setColor(0x44301A, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_ox - 1, _oy - 1, _sq * 8 + 2, _sq * 8 + 2);

        // HUD
        drawHUD(dc);
    }

    hidden function drawHUD(dc) {
        var hy = _oy + _sq * 8 + 3;
        if (hy + 14 > _h) { hy = _oy - 14; }
        var isPlayerTurn = (_whiteToMove == _playerIsWhite) && (_gs == CS_PLAY);
        var colorStr = _playerIsWhite ? "White" : "Black";
        var turnStr = isPlayerTurn ? "Your turn (" + colorStr + ")" : "AI thinking...";
        if (_inCheck && isPlayerTurn) { turnStr = "CHECK!"; }
        dc.setColor(_inCheck && isPlayerTurn ? 0xFF4444 : 0xAA9977, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, hy, Graphics.FONT_XTINY, turnStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Piece rendering — all drawn, no Unicode ───────────────────────────────
    hidden function drawPiece(dc, bx, by, piece) {
        if (piece == PC_EMPTY) { return; }
        var white = (piece > 0);
        var abs   = white ? piece : -piece;

        var cx  = bx + _sq / 2;
        var bot = by + _sq - 1;
        var s   = _sq;

        // Colors: white pieces = cream/ivory; black pieces = dark brown
        var bodyC = white ? 0xF0E8D0 : 0x1E0E06;
        var rimC  = white ? 0x6B4A28 : 0xC09050;
        var markC = white ? 0x4A2E10 : 0xE8C070;

        if (abs == PC_PAWN) {
            // Base
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s*3/8, bot - s*22/100, s*3/4, s*22/100, 2);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s*3/8 + 1, bot - s*22/100 + 1, s*3/4 - 2, s*22/100 - 1, 1);
            // Stem
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s/10, bot - s*65/100, s/5, s*43/100, 1);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s/10 + 1, bot - s*65/100 + 1, s/5 - 2, s*43/100 - 1, 0);
            // Head
            var hr = s * 18 / 100;
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, bot - s*65/100 - hr + 1, hr);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, bot - s*65/100 - hr + 1, hr - 2);

        } else if (abs == PC_ROOK) {
            var bw = s * 56 / 100;
            // Body
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw/2, bot - s*72/100, bw, s*72/100, 2);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw/2 + 1, bot - s*72/100 + 1, bw - 2, s*72/100 - 2, 1);
            // Battlements (3 merlons)
            var tw = bw / 4; var th = s / 6;
            var tops = [cx - bw/2, cx - bw/2 + bw/2, cx - bw/2 + bw*3/4];
            for (var ti = 0; ti < 3; ti += 2) {
                dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cx - bw/2 + ti * bw/4, bot - s*72/100 - th, tw, th + 2);
                dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cx - bw/2 + ti * bw/4 + 1, bot - s*72/100 - th, tw - 2, th);
            }
            // R label
            dc.setColor(markC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, bot - s*55/100, Graphics.FONT_XTINY, "R", Graphics.TEXT_JUSTIFY_CENTER);

        } else if (abs == PC_KNIGHT) {
            var bw = s * 50 / 100;
            // Body
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw/2, bot - s*72/100, bw, s*72/100, 2);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw/2 + 1, bot - s*72/100 + 1, bw - 2, s*72/100 - 2, 1);
            // Horse head bump
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 2, bot - s*88/100, bw * 6/10, s * 26/100, 3);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 1, bot - s*87/100, bw * 6/10 - 2, s * 25/100 - 2, 2);
            // N label
            dc.setColor(markC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, bot - s*55/100, Graphics.FONT_XTINY, "N", Graphics.TEXT_JUSTIFY_CENTER);

        } else if (abs == PC_BISHOP) {
            var bw = s * 46 / 100;
            // Body
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw/2, bot - s*72/100, bw, s*72/100, 3);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw/2 + 1, bot - s*72/100 + 1, bw - 2, s*72/100 - 2, 2);
            // Pointed top
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, bot - s*78/100, s / 10);
            // Collar
            dc.setColor(markC, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - bw/2 + 2, bot - s*40/100, cx + bw/2 - 2, bot - s*40/100);
            dc.drawText(cx, bot - s*65/100, Graphics.FONT_XTINY, "B", Graphics.TEXT_JUSTIFY_CENTER);

        } else if (abs == PC_QUEEN) {
            var bw = s * 62 / 100;
            // Body
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw/2, bot - s*72/100, bw, s*72/100, 3);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw/2 + 1, bot - s*72/100 + 1, bw - 2, s*72/100 - 2, 2);
            // Crown: 3 balls
            var cy2 = bot - s*72/100;
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx,        cy2 - s*12/100, s*10/100);
            dc.fillCircle(cx - bw/3, cy2 - s*8/100,  s*8/100);
            dc.fillCircle(cx + bw/3, cy2 - s*8/100,  s*8/100);
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx,        cy2 - s*12/100, s*7/100);
            dc.fillCircle(cx - bw/3, cy2 - s*8/100,  s*5/100);
            dc.fillCircle(cx + bw/3, cy2 - s*8/100,  s*5/100);
            // Q label
            dc.setColor(markC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, bot - s*58/100, Graphics.FONT_XTINY, "Q", Graphics.TEXT_JUSTIFY_CENTER);

        } else if (abs == PC_KING) {
            var bw = s * 62 / 100;
            // Body
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw/2, bot - s*72/100, bw, s*72/100, 3);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw/2 + 1, bot - s*72/100 + 1, bw - 2, s*72/100 - 2, 2);
            // Cross (gold)
            var cy2 = bot - s*72/100;
            dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 1, cy2 - s*22/100, 3, s*22/100 + 2);   // vertical
            dc.fillRectangle(cx - s/7, cy2 - s*15/100, s*2/7, 3);        // horizontal
        }
    }

    // Helper to draw a piece by type (for promotion overlay, not full piece)
    hidden function drawPieceType(dc, cx, cy, abs, s, white) {
        var bodyC = white ? 0xF0E8D0 : 0x1E0E06;
        var rimC  = white ? 0x6B4A28 : 0xC09050;
        var markC = white ? 0x4A2E10 : 0xE8C070;
        var labels = ["", "P", "N", "B", "R", "Q", "K"];
        if (abs >= 1 && abs <= 6) {
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s*3/8, cy - s*3/8, s*3/4, s*3/4, 3);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s*3/8 + 1, cy - s*3/8 + 1, s*3/4 - 2, s*3/4 - 2, 2);
            dc.setColor(markC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - s/5, Graphics.FONT_XTINY, labels[abs], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Overlays ─────────────────────────────────────────────────────────────
    hidden function drawPromoOverlay(dc) {
        var bw = _sq * 4 + 16; var bh = _sq + 28;
        var px = (_w - bw) / 2; var py = _h/2 - bh/2;
        dc.setColor(0x1A1008, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, bw, bh, 6);
        dc.setColor(0xAA8844, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, bw, bh, 6);

        var pieces = [PC_QUEEN, PC_ROOK, PC_BISHOP, PC_KNIGHT];
        var isWhitePromo = (_board[_promSq] > 0 || (_promSq >= 0 && _board[_promSq] > 0));
        // Check if the promoting pawn was white or black
        // (After executeMove, promotion square might have the pawn still or the new piece)
        var promWhite = _playerIsWhite; // promotion always happens for the moving player

        for (var i = 0; i < 4; i++) {
            var ix = px + 4 + i * (_sq + 3);
            var iy = py + 4;
            if (i == _promPick) {
                dc.setColor(0x3388FF, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(ix, iy, _sq, _sq, 3);
            } else {
                dc.setColor(0x2A1A08, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(ix, iy, _sq, _sq, 3);
            }
            drawPieceType(dc, ix + _sq/2, iy + _sq/2, pieces[i], _sq, promWhite);
        }
        dc.setColor(0xCCBB99, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, py + _sq + 10, Graphics.FONT_XTINY, "Promote! Tap piece", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawThinkingBadge(dc) {
        var dots = "";
        var d = _tick % 4;
        for (var i = 0; i <= d; i++) { dots = dots + "."; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w/2 - 44, _h - 22, 88, 18, 4);
        dc.setColor(0x66BBFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h - 20, Graphics.FONT_XTINY, "AI thinking" + dots, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawEndOverlay(dc, msg) {
        var blink = (_tick % 8 < 5);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w/2 - 70, _h/2 - 30, 140, 60, 8);
        dc.setColor(0xAA7733, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_w/2 - 70, _h/2 - 30, 140, 60, 8);
        dc.setColor(0xFFDD55, Graphics.COLOR_TRANSPARENT);

        // Split msg on \n
        var lines = splitMsg(msg);
        var startY = _h/2 - (lines.size() * 14) / 2;
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(_w/2, startY + i * 14, Graphics.FONT_XTINY, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (blink) {
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _h/2 + 18, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function splitMsg(msg) {
        var result = new [0];
        var cur = "";
        for (var i = 0; i < msg.length(); i++) {
            var c = msg.substring(i, i + 1);
            if (c.equals("\n")) {
                result = addStrArr(result, cur); cur = "";
            } else { cur = cur + c; }
        }
        if (!cur.equals("")) { result = addStrArr(result, cur); }
        return result;
    }

    hidden function addStrArr(arr, s) {
        var n = new [arr.size() + 1];
        for (var i = 0; i < arr.size(); i++) { n[i] = arr[i]; }
        n[arr.size()] = s;
        return n;
    }
}
