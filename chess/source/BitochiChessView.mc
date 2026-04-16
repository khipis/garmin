using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.System;

const PC_EMPTY  = 0;
const PC_PAWN   = 1;
const PC_KNIGHT = 2;
const PC_BISHOP = 3;
const PC_ROOK   = 4;
const PC_QUEEN  = 5;
const PC_KING   = 6;

const CS_MENU      = 0;
const CS_PLAY      = 1;
const CS_AI_THINK  = 2;
const CS_CHECKMATE = 3;
const CS_STALEMATE = 4;
const CS_PROMOTE   = 5;
const CS_AI_FINISH = 6;
const CS_AI_EVAL   = 7;

class BitochiChessView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    hidden var _board;
    hidden var _whiteToMove;
    hidden var _castleRights;
    hidden var _enPassant;
    hidden var _halfMove;
    hidden var _moveCount;
    hidden var _inCheck;

    hidden var _selSq;
    hidden var _curSq;
    hidden var _legalMoves;

    hidden var _promSq;
    hidden var _promPick;

    hidden var _ox; hidden var _oy; hidden var _sq;

    hidden var _aiMove;
    hidden var _aiTimer;
    hidden var _aiCount;
    hidden var _aiIdx;
    hidden var _aiBestScore;
    hidden var _aiBestIdx;
    hidden var _aiIsWhite;
    hidden var _mmN; hidden var _mmLimit;
    hidden var _wPF; hidden var _bPF;

    hidden var _difficulty;
    hidden var _playerIsWhite;
    hidden var _aiVsAi;
    hidden var _pieceVal;
    hidden var _menuRow;

    // Pre-allocated direction arrays — created once, shared by sqAttacked / knightMovesPool / slideMovesPool.
    // Without this, sqAttacked alone creates 6 local arrays per call → hundreds of allocs per AI turn.
    hidden var _kDR; hidden var _kDF;
    hidden var _diagDR; hidden var _diagDF;
    hidden var _straightDR; hidden var _straightDF;
    hidden var _queenDR; hidden var _queenDF;

    hidden const MAX_DEPTH = 4;
    hidden const MV_POOL   = 600;
    hidden const LVL_MOVES = 96;

    hidden var _mvFrom; hidden var _mvTo; hidden var _mvFlags; hidden var _mvPromo;
    hidden var _mvTop;
    hidden var _dFrom; hidden var _dTo; hidden var _dFlags; hidden var _dPromo; hidden var _dCount;

    // ═══════════════════════════════════════════════════════════════════════════
    //  INITIALIZE
    // ═══════════════════════════════════════════════════════════════════════════

    function initialize() {
        View.initialize();
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _tick = 0;
        _gs = CS_MENU;
        _difficulty = 1;
        _playerIsWhite = true;
        _aiVsAi = false;
        _menuRow = 0;
        _selSq = -1; _curSq = 36;
        _legalMoves = new [0];
        _promSq = -1; _promPick = 0;
        _aiMove = null; _aiTimer = 0;
        _ox = 0; _oy = 0; _sq = 0;

        _pieceVal = [0, 100, 320, 330, 500, 900, 20000];
        _board = new [64];

        _kDR = [-2,-2,-1,-1,1,1,2,2]; _kDF = [-1,1,-2,2,-2,2,-1,1];
        _diagDR = [1,1,-1,-1]; _diagDF = [1,-1,1,-1];
        _straightDR = [0,0,1,-1]; _straightDF = [1,-1,0,0];
        _queenDR = [0,0,1,-1,1,1,-1,-1]; _queenDF = [1,-1,0,0,1,-1,1,-1];

        _mvFrom  = new [MV_POOL]; _mvTo    = new [MV_POOL];
        _mvFlags = new [MV_POOL]; _mvPromo = new [MV_POOL];
        _mvTop   = 0;

        _dFrom  = new [MAX_DEPTH]; _dTo    = new [MAX_DEPTH];
        _dFlags = new [MAX_DEPTH]; _dPromo = new [MAX_DEPTH];
        _dCount = new [MAX_DEPTH];
        for (var d = 0; d < MAX_DEPTH; d++) {
            _dFrom[d]  = new [LVL_MOVES]; _dTo[d]    = new [LVL_MOVES];
            _dFlags[d] = new [LVL_MOVES]; _dPromo[d] = new [LVL_MOVES];
            _dCount[d] = 0;
        }

        _wPF = new [8]; _bPF = new [8];

        setupBoard();
        setupGeometry();
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 200, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupGeometry();
    }

    hidden function setupGeometry() {
        _sq = _w * 74 / 100 / 8;
        if (_sq > _h * 74 / 100 / 8) { _sq = _h * 74 / 100 / 8; }
        // On round/square screens ensure board corners fit inside the circular display
        if (_w == _h) {
            var sqMax = _w / 12;
            if (_sq > sqMax) { _sq = sqMax; }
        }
        if (_sq < 1) { _sq = 1; }
        _ox = (_w - _sq * 8) / 2;
        _oy = (_h - _sq * 8) / 2 + 2;
    }

    hidden function setupBoard() {
        for (var i = 0; i < 64; i++) { _board[i] = PC_EMPTY; }
        _board[0]  =  PC_ROOK;   _board[1]  =  PC_KNIGHT; _board[2]  =  PC_BISHOP;
        _board[3]  =  PC_QUEEN;  _board[4]  =  PC_KING;   _board[5]  =  PC_BISHOP;
        _board[6]  =  PC_KNIGHT; _board[7]  =  PC_ROOK;
        for (var f = 0; f < 8; f++) { _board[8 + f]  =  PC_PAWN; }
        _board[56] = -PC_ROOK;   _board[57] = -PC_KNIGHT; _board[58] = -PC_BISHOP;
        _board[59] = -PC_QUEEN;  _board[60] = -PC_KING;   _board[61] = -PC_BISHOP;
        _board[62] = -PC_KNIGHT; _board[63] = -PC_ROOK;
        for (var f = 0; f < 8; f++) { _board[48 + f] = -PC_PAWN; }
        _whiteToMove = true;
        _castleRights = 0xF;
        _enPassant = -1;
        _halfMove = 0; _moveCount = 1;
        _inCheck = false;
        _selSq = -1; _legalMoves = new [0];
    }

    function onTick() as Void {
        _tick++;
        if (_gs == CS_AI_THINK) {
            _aiTimer--;
            if (_aiTimer <= 0) { _doAiGen(); }
        } else if (_gs == CS_AI_EVAL) {
            _doAiEval();
        } else if (_gs == CS_AI_FINISH) {
            _doAiFinish();
        }
        WatchUi.requestUpdate();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  SMART CURSOR INPUT
    //  Buttons cycle through own pieces (no selection) or legal targets
    //  (piece selected). No need for 4-directional navigation.
    // ═══════════════════════════════════════════════════════════════════════════

    function doNext() {
        if (_gs == CS_MENU) { _menuRow = (_menuRow + 1) % 4; return; }
        if (_gs == CS_PROMOTE) { _promPick = (_promPick + 1) % 4; return; }
        if (_gs == CS_CHECKMATE || _gs == CS_STALEMATE) { return; }
        if (_gs != CS_PLAY) { return; }
        if (_whiteToMove != _playerIsWhite) { return; }
        if (_selSq >= 0) { cycleTarget(1); }
        else { cyclePiece(1); }
    }

    function doPrev() {
        if (_gs == CS_MENU) { _menuRow = (_menuRow + 3) % 4; return; }
        if (_gs == CS_PROMOTE) { _promPick = (_promPick + 3) % 4; return; }
        if (_gs == CS_CHECKMATE || _gs == CS_STALEMATE) { return; }
        if (_gs != CS_PLAY) { return; }
        if (_whiteToMove != _playerIsWhite) { return; }
        if (_selSq >= 0) { cycleTarget(-1); }
        else { cyclePiece(-1); }
    }

    hidden function cyclePiece(dir) {
        var d = _playerIsWhite ? -dir : dir;
        for (var i = 1; i <= 64; i++) {
            var sq = (_curSq + i * d + 64) % 64;
            var p = _board[sq];
            var own = _playerIsWhite ? (p > 0) : (p < 0);
            if (own && _hasLegalMoveForSq(sq)) { _curSq = sq; return; }
        }
    }

    hidden function cycleTarget(dir) {
        if (_legalMoves.size() == 0) { return; }
        var curIdx = -1;
        for (var i = 0; i < _legalMoves.size(); i++) {
            if (_legalMoves[i][1] == _curSq) { curIdx = i; break; }
        }
        if (curIdx < 0) { curIdx = 0; }
        else { curIdx = (curIdx + dir + _legalMoves.size()) % _legalMoves.size(); }
        _curSq = _legalMoves[curIdx][1];
    }

    function doSelect() {
        if (_gs == CS_MENU) {
            if (_menuRow == 0) { _playerIsWhite = !_playerIsWhite; }
            else if (_menuRow == 1) { _difficulty = (_difficulty + 1) % 3; }
            else if (_menuRow == 2) { _aiVsAi = !_aiVsAi; }
            else { startGame(); }
            return;
        }
        if (_gs == CS_CHECKMATE || _gs == CS_STALEMATE) { _gs = CS_MENU; return; }
        if (_aiVsAi) { return; }
        if (_gs == CS_PROMOTE) { confirmPromotion(); return; }
        if (_gs != CS_PLAY) { return; }
        if (_whiteToMove != _playerIsWhite) { return; }

        if (_selSq < 0) {
            var p = _board[_curSq];
            var own = _playerIsWhite ? (p > 0) : (p < 0);
            if (own) {
                var moves = genLegalMovesFor(_curSq);
                if (moves.size() > 0) {
                    _selSq = _curSq; _legalMoves = moves;
                    _curSq = moves[0][1];
                }
            }
        } else {
            var moved = false;
            for (var i = 0; i < _legalMoves.size(); i++) {
                if (_legalMoves[i][1] == _curSq) {
                    executeMove(_legalMoves[i]);
                    moved = true; break;
                }
            }
            if (!moved) {
                _selSq = -1; _legalMoves = new [0];
            }
        }
    }

    function doDeselect() {
        if (_gs == CS_PLAY && _selSq >= 0) {
            var prev = _selSq;
            _selSq = -1; _legalMoves = new [0];
            _curSq = prev;
        }
    }

    function doBack() {
        if (_gs == CS_PLAY && _selSq >= 0) {
            doDeselect();
            return true;
        }
        if (_gs != CS_MENU) {
            _gs = CS_MENU; _selSq = -1; _legalMoves = new [0];
            return true;
        }
        return false;
    }

    function doTap(tx, ty) {
        if (_gs == CS_MENU) {
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
                    else if (i == 2) { _aiVsAi = !_aiVsAi; }
                    else { startGame(); }
                    return;
                }
            }
            return;
        }
        if (_gs == CS_CHECKMATE || _gs == CS_STALEMATE) { _gs = CS_MENU; return; }
        if (_gs == CS_AI_THINK || _gs == CS_AI_EVAL || _gs == CS_AI_FINISH) { return; }
        if (_gs == CS_PROMOTE) {
            var bw = _sq * 2; var bh = _sq;
            var px = _w / 2 - bw;
            for (var i = 0; i < 4; i++) {
                var bx = px + i * bw / 2;
                if (tx >= bx && tx < bx + bw / 2 && ty >= _h / 2 - bh / 2 && ty < _h / 2 + bh / 2) {
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
        var r = _playerIsWhite ? (7 - rInv) : rInv;
        var fl = _playerIsWhite ? f : (7 - f);
        return r * 8 + fl;
    }

    hidden function handleSquare(sq) {
        if (_whiteToMove != _playerIsWhite) { return; }
        var piece = _board[sq];
        var isOwnPiece = _playerIsWhite ? (piece > 0) : (piece < 0);

        if (_selSq < 0) {
            if (isOwnPiece) {
                var moves = genLegalMovesFor(sq);
                if (moves.size() > 0) { _selSq = sq; _legalMoves = moves; }
            }
        } else {
            var moved = false;
            for (var i = 0; i < _legalMoves.size(); i++) {
                if (_legalMoves[i][1] == sq) {
                    executeMove(_legalMoves[i]);
                    moved = true; break;
                }
            }
            if (!moved) {
                _selSq = -1; _legalMoves = new [0];
                if (isOwnPiece) {
                    var moves2 = genLegalMovesFor(sq);
                    if (moves2.size() > 0) { _selSq = sq; _legalMoves = moves2; }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  GAME FLOW
    // ═══════════════════════════════════════════════════════════════════════════

    hidden function startGame() {
        setupBoard();
        _gs = CS_PLAY;
        _menuRow = 0;
        _selSq = -1;
        if (_aiVsAi) {
            _playerIsWhite = true;
            _curSq = 4;
            _gs = CS_AI_THINK; _aiTimer = 1;
        } else if (_playerIsWhite) {
            _curSq = 4;
        } else {
            _curSq = 60;
            _gs = CS_AI_THINK; _aiTimer = 1;
        }
    }


    hidden function _hasLegalMoveForSq(sq) {
        var piece = _board[sq];
        if (piece == PC_EMPTY) { return false; }
        var white = (piece > 0);
        var kingPiece = white ? PC_KING : -PC_KING;
        var kingSq = -1;
        for (var k = 0; k < 64; k++) { if (_board[k] == kingPiece) { kingSq = k; break; } }
        if (kingSq < 0) { return false; }
        return _hasLegalCached(sq, white, kingSq);
    }

    hidden function _hasLegalCached(sq, white, kingSq) {
        var saveTop = _mvTop;
        genPseudoIntoPool(sq, white);
        var pseudoEnd = _mvTop;
        _mvTop = saveTop;
        var isKM = (sq == kingSq);
        for (var i = saveTop; i < pseudoEnd; i++) {
            var mf = _mvFrom[i]; var mt = _mvTo[i]; var fl = _mvFlags[i]; var mp = _mvPromo[i];
            var pF = _board[mf]; var pT = _board[mt];
            var svEP = _enPassant; var svWtm = _whiteToMove;
            var xSq1 = -1; var xPc1 = PC_EMPTY;
            var xSq2 = -1; var xPc2 = PC_EMPTY;
            var rk = mf / 8;
            if (fl == 2) { xSq1 = rk * 8 + (mt % 8); xPc1 = _board[xSq1]; }
            else if (fl == 3) { xSq1 = rk * 8 + 7; xPc1 = _board[xSq1]; xSq2 = rk * 8 + 5; xPc2 = _board[xSq2]; }
            else if (fl == 4) { xSq1 = rk * 8 + 0; xPc1 = _board[xSq1]; xSq2 = rk * 8 + 3; xPc2 = _board[xSq2]; }
            applyMoveRaw(mf, mt, fl, mp);
            var checkSq = isKM ? mt : kingSq;
            var legal = !sqAttacked(checkSq, !white);
            _board[mf] = pF; _board[mt] = pT;
            if (xSq1 >= 0) { _board[xSq1] = xPc1; }
            if (xSq2 >= 0) { _board[xSq2] = xPc2; }
            _enPassant = svEP; _whiteToMove = svWtm;
            if (legal) { return true; }
        }
        return false;
    }

    hidden function _anyLegalMoveExists(white) {
        var kingPiece = white ? PC_KING : -PC_KING;
        var kingSq = -1;
        for (var k = 0; k < 64; k++) { if (_board[k] == kingPiece) { kingSq = k; break; } }
        if (kingSq < 0) { return false; }
        for (var sq = 0; sq < 64; sq++) {
            var p = _board[sq];
            if ((white && p > 0) || (!white && p < 0)) {
                if (_hasLegalCached(sq, white, kingSq)) { return true; }
            }
        }
        return false;
    }

    hidden function _snapCursorToAnyValid() {
        var white = _playerIsWhite;
        var kingPiece = white ? PC_KING : -PC_KING;
        var kingSq = -1;
        for (var k = 0; k < 64; k++) { if (_board[k] == kingPiece) { kingSq = k; break; } }
        if (kingSq < 0) { return; }
        var p0 = _board[_curSq];
        var own0 = white ? (p0 > 0) : (p0 < 0);
        if (own0 && _hasLegalCached(_curSq, white, kingSq)) { return; }
        for (var sq = 0; sq < 64; sq++) {
            var p = _board[sq];
            var own = white ? (p > 0) : (p < 0);
            if (own && _hasLegalCached(sq, white, kingSq)) { _curSq = sq; return; }
        }
    }

    hidden function executeMove(mv) {
        var from = mv[0]; var to = mv[1]; var flags = mv[2];
        var piece = _board[from];
        var captured = _board[to];
        var absPiece = piece > 0 ? piece : -piece;

        _board[to] = piece; _board[from] = PC_EMPTY;

        if (flags == 2) {
            _board[(from / 8) * 8 + (to % 8)] = PC_EMPTY;
        }

        _enPassant = -1;
        if (flags == 1) { _enPassant = (from + to) / 2; }

        if (flags == 3) {
            var rank = from / 8;
            _board[rank * 8 + 5] = _board[rank * 8 + 7]; _board[rank * 8 + 7] = PC_EMPTY;
        }
        if (flags == 4) {
            var rank = from / 8;
            _board[rank * 8 + 3] = _board[rank * 8 + 0]; _board[rank * 8 + 0] = PC_EMPTY;
        }

        if (flags == 5) {
            var promPiece = mv[3];
            _board[to] = (piece > 0) ? promPiece : -promPiece;
        }

        if (absPiece == PC_KING) {
            if (piece > 0) { _castleRights = _castleRights & ~3; }
            else           { _castleRights = _castleRights & ~12; }
        }
        if (from == 0  || to == 0)  { _castleRights = _castleRights & ~2; }
        if (from == 7  || to == 7)  { _castleRights = _castleRights & ~1; }
        if (from == 56 || to == 56) { _castleRights = _castleRights & ~8; }
        if (from == 63 || to == 63) { _castleRights = _castleRights & ~4; }

        if (absPiece == PC_PAWN || captured != PC_EMPTY) { _halfMove = 0; } else { _halfMove++; }

        _whiteToMove = !_whiteToMove;
        if (!_whiteToMove) { _moveCount++; }

        _selSq = -1; _legalMoves = new [0];

        if (flags != 5 && absPiece == PC_PAWN) {
            var toRank = to / 8;
            if ((piece > 0 && toRank == 7) || (piece < 0 && toRank == 0)) {
                _promSq = to; _gs = CS_PROMOTE; return;
            }
        }

        _inCheck = isInCheck(_whiteToMove);
        afterMove();
    }

    hidden function afterMove() {
        if (_anyLegalMoveExists(_whiteToMove)) {
            if (_aiVsAi) {
                _gs = CS_AI_THINK; _aiTimer = 1;
            } else if (_whiteToMove == _playerIsWhite) {
                _gs = CS_PLAY;
            } else {
                _gs = CS_AI_THINK; _aiTimer = 1;
            }
        } else {
            if (_inCheck) { _gs = CS_CHECKMATE; } else { _gs = CS_STALEMATE; }
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

    // ═══════════════════════════════════════════════════════════════════════════
    //  AI
    // ═══════════════════════════════════════════════════════════════════════════

    hidden function genMovesForLevel(level, white) {
        _mvTop = 0;
        var start = genAllLegalPool(white);
        var count = _mvTop - start;
        if (count > LVL_MOVES) { count = LVL_MOVES; }
        var df = _dFrom[level]; var dt = _dTo[level];
        var dfl = _dFlags[level]; var dp = _dPromo[level];
        for (var i = 0; i < count; i++) {
            df[i]  = _mvFrom[start + i]; dt[i]  = _mvTo[start + i];
            dfl[i] = _mvFlags[start + i]; dp[i]  = _mvPromo[start + i];
        }
        _dCount[level] = count;
        return count;
    }

    hidden function _doAiGen() {
        _aiIsWhite = _aiVsAi ? _whiteToMove : !_playerIsWhite;

        var count = genMovesForLevel(0, _aiIsWhite);
        if (count == 0) {
            _inCheck = isInCheck(_aiIsWhite);
            if (_inCheck) { _gs = CS_CHECKMATE; } else { _gs = CS_STALEMATE; }
            return;
        }

        _aiCount = count;
        _aiIdx = 0;
        _aiBestScore = -999999;
        _aiBestIdx = 0;
        _gs = CS_AI_EVAL;
    }

    hidden function _doAiEval() {
        var batch = 6;
        if (_difficulty == 0) { batch = 10; }
        else if (_difficulty == 2) { batch = 4; }
        var end = _aiIdx + batch;
        if (end > _aiCount) { end = _aiCount; }

        var df = _dFrom[0]; var dt = _dTo[0];
        var dfl = _dFlags[0]; var dp = _dPromo[0];

        for (var i = _aiIdx; i < end; i++) {
            var from = df[i]; var to = dt[i]; var fl = dfl[i]; var promo = dp[i];
            var pF = _board[from]; var pT = _board[to];
            var svEP = _enPassant; var svWtm = _whiteToMove; var svCR = _castleRights;
            var xSq1 = -1; var xPc1 = PC_EMPTY; var xSq2 = -1; var xPc2 = PC_EMPTY;
            var rk = from / 8;
            if (fl == 2) { xSq1 = rk * 8 + (to % 8); xPc1 = _board[xSq1]; }
            else if (fl == 3) { xSq1 = rk * 8 + 7; xPc1 = _board[xSq1]; xSq2 = rk * 8 + 5; xPc2 = _board[xSq2]; }
            else if (fl == 4) { xSq1 = rk * 8 + 0; xPc1 = _board[xSq1]; xSq2 = rk * 8 + 3; xPc2 = _board[xSq2]; }
            applyMoveRaw(from, to, fl, promo);
            _updateCR(pF, from, to);

            var raw = evaluate();
            var score = _aiIsWhite ? raw : -raw;

            var absPF = pF > 0 ? pF : -pF;
            var movedVal = _pieceVal[absPF];

            if (pT != PC_EMPTY) {
                var absPT = pT > 0 ? pT : -pT;
                var capVal = _pieceVal[absPT];
                score += capVal - movedVal / 4;
                if (sqAttacked(to, !_aiIsWhite) && !sqAttacked(to, _aiIsWhite)) {
                    score -= movedVal;
                }
            }

            if (fl == 2) { score += 80; }

            if (fl == 5) { score += 700; }
            if (absPF == PC_PAWN) {
                var toR = to / 8;
                if ((pF > 0 && toR == 7) || (pF < 0 && toR == 0)) { score += 700; }
            }

            if (fl == 3 || fl == 4) { score += 60; }

            if (isInCheck(!_aiIsWhite)) { score += 40; }

            if (_difficulty >= 1) {
                if (pT == PC_EMPTY && absPF != PC_KING) {
                    if (sqAttacked(to, !_aiIsWhite)) {
                        if (!sqAttacked(to, _aiIsWhite)) {
                            score -= movedVal;
                        } else if (absPF >= PC_ROOK) {
                            score -= 40;
                        }
                    }
                }
            }

            if (_difficulty == 2) {
                var fromR = from / 8; var toR2 = to / 8;
                if (absPF == PC_KNIGHT || absPF == PC_BISHOP) {
                    if ((pF > 0 && fromR == 0) || (pF < 0 && fromR == 7)) { score += 20; }
                    var toF = to % 8;
                    if (toF >= 2 && toF <= 5 && toR2 >= 2 && toR2 <= 5) { score += 8; }
                }

                if (absPF == PC_QUEEN && _moveCount <= 8) { score -= 25; }

                if (absPF == PC_PAWN) {
                    var toF2 = to % 8;
                    if (toF2 >= 3 && toF2 <= 4 && toR2 >= 3 && toR2 <= 4) { score += 12; }
                }

                if (absPF == PC_ROOK) {
                    var toF3 = to % 8;
                    var hasFP = false; var hasEP = false;
                    for (var rr = 0; rr < 8; rr++) {
                        var pp = _board[rr * 8 + toF3];
                        if (pp == PC_EMPTY) { continue; }
                        var ap = pp > 0 ? pp : -pp;
                        if (ap == PC_PAWN) {
                            if ((_aiIsWhite && pp > 0) || (!_aiIsWhite && pp < 0)) { hasFP = true; }
                            else { hasEP = true; }
                        }
                    }
                    if (!hasFP && !hasEP) { score += 15; }
                    else if (!hasFP) { score += 8; }
                    if ((_aiIsWhite && toR2 == 6) || (!_aiIsWhite && toR2 == 1)) { score += 20; }
                }

                if (absPF == PC_KING && fl != 3 && fl != 4 && _moveCount <= 15) { score -= 25; }

                if (pT != PC_EMPTY) {
                    var mat = 0;
                    for (var sq = 0; sq < 64; sq++) {
                        var pp = _board[sq];
                        if (pp != PC_EMPTY) {
                            var ap = pp > 0 ? pp : -pp;
                            if (ap != PC_KING) {
                                if (pp > 0) { mat += _pieceVal[ap]; } else { mat -= _pieceVal[ap]; }
                            }
                        }
                    }
                    if (_aiIsWhite ? (mat > 200) : (mat < -200)) { score += 25; }
                }

                if (absPF != PC_KING && from != to) {
                    var oldOcc = _board[from];
                    if (oldOcc == PC_EMPTY) {
                        var fromR2 = from / 8; var fromF2 = from % 8;
                        for (var dd = 0; dd < 8; dd++) {
                            var nr = fromR2 + _queenDR[dd]; var nf = fromF2 + _queenDF[dd];
                            if (nr < 0 || nr >= 8 || nf < 0 || nf >= 8) { continue; }
                            var adj = _board[nr * 8 + nf];
                            if (adj == PC_EMPTY) { continue; }
                            var adjOurs = _aiIsWhite ? (adj > 0) : (adj < 0);
                            if (!adjOurs) { continue; }
                            var adjA = adj > 0 ? adj : -adj;
                            if (adjA < PC_ROOK || adjA == PC_KING) { continue; }
                            if (sqAttacked(nr * 8 + nf, !_aiIsWhite) && !sqAttacked(nr * 8 + nf, _aiIsWhite)) {
                                score -= _pieceVal[adjA] / 3;
                            }
                            break;
                        }
                    }
                }
            }

            if (_difficulty == 0) {
                var noise = (Math.rand() % 80).toNumber();
                if (noise < 0) { noise = -noise; }
                score = score + noise - 40;
            } else if (_difficulty == 1) {
                var noise = (Math.rand() % 20).toNumber();
                if (noise < 0) { noise = -noise; }
                score = score + noise - 10;
            }

            _board[from] = pF; _board[to] = pT;
            if (xSq1 >= 0) { _board[xSq1] = xPc1; }
            if (xSq2 >= 0) { _board[xSq2] = xPc2; }
            _enPassant = svEP; _whiteToMove = svWtm; _castleRights = svCR;

            if (score > _aiBestScore) { _aiBestScore = score; _aiBestIdx = i; }
        }

        _aiIdx = end;
        if (_aiIdx >= _aiCount) {
            var bFrom = df[_aiBestIdx]; var bTo = dt[_aiBestIdx];
            var bFl = dfl[_aiBestIdx]; var bPr = dp[_aiBestIdx];
            var movingPiece = _board[bFrom];
            applyMoveRaw(bFrom, bTo, bFl, bPr);
            _updateCR(movingPiece, bFrom, bTo);
            if (!_aiVsAi) { _whiteToMove = _playerIsWhite; }

            var piece = _board[bTo];
            if (_aiIsWhite  && piece == PC_PAWN  && bTo / 8 == 7) { _board[bTo] =  PC_QUEEN; }
            if (!_aiIsWhite && piece == -PC_PAWN && bTo / 8 == 0) { _board[bTo] = -PC_QUEEN; }

            _inCheck = isInCheck(_whiteToMove);
            _gs = CS_AI_FINISH;
        }
    }

    // Phase 2 (next tick): check player legal moves for checkmate/stalemate, snap cursor.
    hidden function _doAiFinish() {
        if (_anyLegalMoveExists(_whiteToMove)) {
            if (_aiVsAi) {
                _gs = CS_AI_THINK; _aiTimer = 1;
            } else {
                _gs = CS_PLAY;
                _snapCursorToAnyValid();
            }
        } else {
            if (_inCheck) { _gs = CS_CHECKMATE; } else { _gs = CS_STALEMATE; }
        }
    }

    hidden function _updateCR(pF, from, to) {
        var abs = pF > 0 ? pF : -pF;
        if (abs == PC_KING) {
            if (pF > 0) { _castleRights = _castleRights & ~3; }
            else { _castleRights = _castleRights & ~12; }
        }
        if (from == 0  || to == 0)  { _castleRights = _castleRights & ~2; }
        if (from == 7  || to == 7)  { _castleRights = _castleRights & ~1; }
        if (from == 56 || to == 56) { _castleRights = _castleRights & ~8; }
        if (from == 63 || to == 63) { _castleRights = _castleRights & ~4; }
    }

    hidden function evaluate() {
        var score = 0;
        var totalMat = 0;
        var wKsq = -1; var bKsq = -1;
        var wBish = 0; var bBish = 0;
        for (var fi = 0; fi < 8; fi++) { _wPF[fi] = 0; _bPF[fi] = 0; }

        for (var sq = 0; sq < 64; sq++) {
            var p = _board[sq];
            if (p == PC_EMPTY) { continue; }
            var abs = p > 0 ? p : -p;
            var val = _pieceVal[abs];
            var r = sq / 8; var f = sq % 8;
            var bonus = 0;
            if (abs == PC_PAWN) {
                bonus = p > 0 ? r * 8 : (7 - r) * 8;
                if (f >= 3 && f <= 4) { bonus += 12; }
                if (f >= 2 && f <= 5) { bonus += 5; }
                if (p > 0) { _wPF[f]++; } else { _bPF[f]++; }
            } else if (abs == PC_KNIGHT) {
                if (f >= 2 && f <= 5 && r >= 2 && r <= 5) { bonus = 12; }
                if (f >= 3 && f <= 4 && r >= 3 && r <= 4) { bonus = 22; }
                if (f == 0 || f == 7) { bonus = -15; }
                if (r == 0 || r == 7) { bonus -= 5; }
            } else if (abs == PC_BISHOP) {
                if (f >= 2 && f <= 5 && r >= 2 && r <= 5) { bonus = 12; }
                if (f >= 3 && f <= 4 && r >= 3 && r <= 4) { bonus = 18; }
                if (p > 0) { wBish++; } else { bBish++; }
            } else if (abs == PC_ROOK) {
                if ((p > 0 && r == 6) || (p < 0 && r == 1)) { bonus = 25; }
            } else if (abs == PC_QUEEN) {
                if (f >= 2 && f <= 5 && r >= 2 && r <= 5) { bonus = 5; }
            } else if (abs == PC_KING) {
                if (p > 0) { wKsq = sq; } else { bKsq = sq; }
            }
            if (abs != PC_KING) { totalMat += val; }
            if (p > 0) { score += val + bonus; } else { score -= val + bonus; }
        }

        for (var fi2 = 0; fi2 < 8; fi2++) {
            if (_wPF[fi2] > 1) { score -= (_wPF[fi2] - 1) * 15; }
            if (_bPF[fi2] > 1) { score += (_bPF[fi2] - 1) * 15; }
            var wL = (fi2 > 0) ? _wPF[fi2 - 1] : 0;
            var wR = (fi2 < 7) ? _wPF[fi2 + 1] : 0;
            if (_wPF[fi2] > 0 && wL == 0 && wR == 0) { score -= 12; }
            var bL = (fi2 > 0) ? _bPF[fi2 - 1] : 0;
            var bR = (fi2 < 7) ? _bPF[fi2 + 1] : 0;
            if (_bPF[fi2] > 0 && bL == 0 && bR == 0) { score += 12; }
            if (_wPF[fi2] > 0 && _bPF[fi2] == 0) {
                var pass = true;
                if (fi2 > 0 && _bPF[fi2 - 1] > 0) { pass = false; }
                if (fi2 < 7 && _bPF[fi2 + 1] > 0) { pass = false; }
                if (pass) { score += 20; }
            }
            if (_bPF[fi2] > 0 && _wPF[fi2] == 0) {
                var pass = true;
                if (fi2 > 0 && _wPF[fi2 - 1] > 0) { pass = false; }
                if (fi2 < 7 && _wPF[fi2 + 1] > 0) { pass = false; }
                if (pass) { score -= 20; }
            }
        }

        if (wBish >= 2) { score += 35; }
        if (bBish >= 2) { score -= 35; }

        var endgame = (totalMat < 2600);
        if (wKsq >= 0) {
            var kr = wKsq / 8; var kf = wKsq % 8;
            if (endgame) {
                var cd = 0;
                if (kf < 3) { cd += 3 - kf; } else if (kf > 4) { cd += kf - 4; }
                if (kr < 3) { cd += 3 - kr; } else if (kr > 4) { cd += kr - 4; }
                score += 15 - cd * 4;
            } else {
                if (kr == 0 && (kf <= 2 || kf >= 5)) {
                    score += 30;
                    if (kf <= 2) {
                        for (var sf = 0; sf <= 2; sf++) {
                            if (sf < 8 && _board[8 + sf] > 0) { var ap = _board[8 + sf]; if (ap == PC_PAWN) { score += 8; } }
                        }
                    } else {
                        for (var sf = 5; sf <= 7; sf++) {
                            if (sf < 8 && _board[8 + sf] > 0) { var ap2 = _board[8 + sf]; if (ap2 == PC_PAWN) { score += 8; } }
                        }
                    }
                }
                else if (kr == 0) { score += 10; }
                else { score -= kr * 10; }
            }
        }
        if (bKsq >= 0) {
            var kr = bKsq / 8; var kf = bKsq % 8;
            if (endgame) {
                var cd = 0;
                if (kf < 3) { cd += 3 - kf; } else if (kf > 4) { cd += kf - 4; }
                if (kr < 3) { cd += 3 - kr; } else if (kr > 4) { cd += kr - 4; }
                score -= 15 - cd * 4;
            } else {
                if (kr == 7 && (kf <= 2 || kf >= 5)) {
                    score -= 30;
                    if (kf <= 2) {
                        for (var sf = 0; sf <= 2; sf++) {
                            if (sf < 8 && _board[48 + sf] < 0) { var ap3 = _board[48 + sf]; if (ap3 == -PC_PAWN) { score -= 8; } }
                        }
                    } else {
                        for (var sf = 5; sf <= 7; sf++) {
                            if (sf < 8 && _board[48 + sf] < 0) { var ap4 = _board[48 + sf]; if (ap4 == -PC_PAWN) { score -= 8; } }
                        }
                    }
                }
                else if (kr == 7) { score -= 10; }
                else { score += (7 - kr) * 10; }
            }
        }
        return score;
    }

    hidden function applyMoveRaw(from, to, flags, promo) {
        var piece = _board[from];
        _board[to] = piece; _board[from] = PC_EMPTY;
        if (flags == 2) { _board[(from / 8) * 8 + (to % 8)] = PC_EMPTY; }
        if (flags == 3) { var rk = from / 8; _board[rk * 8 + 5] = _board[rk * 8 + 7]; _board[rk * 8 + 7] = PC_EMPTY; }
        if (flags == 4) { var rk = from / 8; _board[rk * 8 + 3] = _board[rk * 8 + 0]; _board[rk * 8 + 0] = PC_EMPTY; }
        if (flags == 5 && promo != 0) { _board[to] = (piece > 0) ? promo : -promo; }
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


    // ═══════════════════════════════════════════════════════════════════════════
    //  MOVE GENERATION
    // ═══════════════════════════════════════════════════════════════════════════

    hidden function genAllLegalPool(white) {
        var outStart = _mvTop;
        var kingPiece = white ? PC_KING : -PC_KING;
        var kingSq = -1;
        for (var k = 0; k < 64; k++) { if (_board[k] == kingPiece) { kingSq = k; break; } }
        for (var sq = 0; sq < 64; sq++) {
            var p = _board[sq];
            if ((white && p > 0) || (!white && p < 0)) { _genLegalCached(sq, white, kingSq); }
        }
        return outStart;
    }

    hidden function _genLegalCached(sq, white, kingSq) {
        var pseudoStart = _mvTop;
        genPseudoIntoPool(sq, white);
        var pseudoEnd = _mvTop;
        _mvTop = pseudoStart;
        var isKingMove = (sq == kingSq);
        for (var i = pseudoStart; i < pseudoEnd; i++) {
            var mf = _mvFrom[i]; var mt = _mvTo[i]; var fl = _mvFlags[i]; var mp = _mvPromo[i];
            var pF = _board[mf]; var pT = _board[mt];
            var svEP = _enPassant; var svWtm = _whiteToMove;
            var xSq1 = -1; var xPc1 = PC_EMPTY;
            var xSq2 = -1; var xPc2 = PC_EMPTY;
            var rk = mf / 8;
            if (fl == 2) { xSq1 = rk * 8 + (mt % 8); xPc1 = _board[xSq1]; }
            else if (fl == 3) { xSq1 = rk * 8 + 7; xPc1 = _board[xSq1]; xSq2 = rk * 8 + 5; xPc2 = _board[xSq2]; }
            else if (fl == 4) { xSq1 = rk * 8 + 0; xPc1 = _board[xSq1]; xSq2 = rk * 8 + 3; xPc2 = _board[xSq2]; }
            applyMoveRaw(mf, mt, fl, mp);
            var checkSq = isKingMove ? mt : kingSq;
            var legal = !sqAttacked(checkSq, !white);
            _board[mf] = pF; _board[mt] = pT;
            if (xSq1 >= 0) { _board[xSq1] = xPc1; }
            if (xSq2 >= 0) { _board[xSq2] = xPc2; }
            _enPassant = svEP; _whiteToMove = svWtm;
            if (legal) {
                _mvFrom[_mvTop] = mf; _mvTo[_mvTop] = mt;
                _mvFlags[_mvTop] = fl; _mvPromo[_mvTop] = mp;
                _mvTop++;
            }
        }
    }

    hidden function genLegalMovesFor(sq) {
        var saveTop = _mvTop;
        var piece = _board[sq];
        var white = (piece > 0);
        var kingPiece = white ? PC_KING : -PC_KING;
        var kingSq = -1;
        for (var k = 0; k < 64; k++) { if (_board[k] == kingPiece) { kingSq = k; break; } }
        var start = _mvTop;
        _genLegalCached(sq, white, kingSq);
        var count = _mvTop - start;
        var result = new [count];
        for (var i = 0; i < count; i++) {
            if (_mvPromo[start + i] != 0) {
                result[i] = [_mvFrom[start + i], _mvTo[start + i], _mvFlags[start + i], _mvPromo[start + i]];
            } else {
                result[i] = [_mvFrom[start + i], _mvTo[start + i], _mvFlags[start + i]];
            }
        }
        _mvTop = saveTop;
        return result;
    }

    hidden function genAllLegalMoves(white) {
        var saveTop = _mvTop;
        var start = genAllLegalPool(white);
        var count = _mvTop - start;
        var result = new [count];
        for (var i = 0; i < count; i++) {
            result[i] = [_mvFrom[start + i], _mvTo[start + i], _mvFlags[start + i]];
        }
        _mvTop = saveTop;
        return result;
    }

    hidden function emitMove(from, to, flags, promo) {
        if (_mvTop < MV_POOL) {
            _mvFrom[_mvTop] = from; _mvTo[_mvTop] = to;
            _mvFlags[_mvTop] = flags; _mvPromo[_mvTop] = promo;
            _mvTop++;
        }
    }

    hidden function genPseudoIntoPool(sq, white) {
        var piece = _board[sq];
        if (piece == PC_EMPTY) { return; }
        var abs = white ? piece : -piece;
        if (abs == PC_PAWN)        { pawnMovesPool(sq, white); }
        else if (abs == PC_KNIGHT) { knightMovesPool(sq, white); }
        else if (abs == PC_BISHOP) { slideMovesPool(sq, white, true,  false); }
        else if (abs == PC_ROOK)   { slideMovesPool(sq, white, false, true); }
        else if (abs == PC_QUEEN)  { slideMovesPool(sq, white, true,  true); }
        else if (abs == PC_KING)   { kingMovesPool(sq, white); }
    }

    hidden function pawnMovesPool(sq, white) {
        var r = sq / 8; var f = sq % 8;
        var dir = white ? 1 : -1;
        var startRank = white ? 1 : 6;
        var promoRow = white ? 7 : 0;
        var to = (r + dir) * 8 + f;
        if (to >= 0 && to < 64 && _board[to] == PC_EMPTY) {
            if (r + dir == promoRow) {
                emitMove(sq, to, 5, PC_QUEEN); emitMove(sq, to, 5, PC_ROOK);
                emitMove(sq, to, 5, PC_BISHOP); emitMove(sq, to, 5, PC_KNIGHT);
            } else {
                emitMove(sq, to, 0, 0);
                if (r == startRank) {
                    var to2 = (r + dir * 2) * 8 + f;
                    if (_board[to2] == PC_EMPTY) { emitMove(sq, to2, 1, 0); }
                }
            }
        }
        for (var df = -1; df <= 1; df += 2) {
            var cf = f + df;
            if (cf < 0 || cf > 7) { continue; }
            var capTo = (r + dir) * 8 + cf;
            if (capTo < 0 || capTo >= 64) { continue; }
            var target = _board[capTo];
            if (target != PC_EMPTY && ((white && target < 0) || (!white && target > 0))) {
                if (r + dir == promoRow) {
                    emitMove(sq, capTo, 5, PC_QUEEN); emitMove(sq, capTo, 5, PC_ROOK);
                    emitMove(sq, capTo, 5, PC_BISHOP); emitMove(sq, capTo, 5, PC_KNIGHT);
                } else {
                    emitMove(sq, capTo, 0, 0);
                }
            }
            if (capTo == _enPassant) { emitMove(sq, capTo, 2, 0); }
        }
    }

    hidden function knightMovesPool(sq, white) {
        var r = sq / 8; var f = sq % 8;
        var dr8 = _kDR; var df8 = _kDF;
        for (var i = 0; i < 8; i++) {
            var nr = r + dr8[i]; var nf = f + df8[i];
            if (nr < 0 || nr >= 8 || nf < 0 || nf >= 8) { continue; }
            var t = _board[nr * 8 + nf];
            if (t == PC_EMPTY || (white && t < 0) || (!white && t > 0)) {
                emitMove(sq, nr * 8 + nf, 0, 0);
            }
        }
    }

    hidden function slideMovesPool(sq, white, diag, straight) {
        var r = sq / 8; var f = sq % 8;
        var drs; var dfs; var nd = 0;
        if (diag && straight) {
            drs = _queenDR; dfs = _queenDF; nd = 8;
        } else if (diag) {
            drs = _diagDR; dfs = _diagDF; nd = 4;
        } else {
            drs = _straightDR; dfs = _straightDF; nd = 4;
        }
        for (var di = 0; di < nd; di++) {
            var dr = drs[di]; var df = dfs[di];
            var nr = r + dr; var nf = f + df;
            while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
                var to = nr * 8 + nf;
                var t = _board[to];
                if (t == PC_EMPTY) { emitMove(sq, to, 0, 0); }
                else if ((white && t < 0) || (!white && t > 0)) { emitMove(sq, to, 0, 0); break; }
                else { break; }
                nr += dr; nf += df;
            }
        }
    }

    hidden function kingMovesPool(sq, white) {
        var r = sq / 8; var f = sq % 8;
        for (var dr = -1; dr <= 1; dr++) {
            for (var df = -1; df <= 1; df++) {
                if (dr == 0 && df == 0) { continue; }
                var nr = r + dr; var nf = f + df;
                if (nr < 0 || nr >= 8 || nf < 0 || nf >= 8) { continue; }
                var to = nr * 8 + nf;
                var t = _board[to];
                if (t == PC_EMPTY || (white && t < 0) || (!white && t > 0)) {
                    emitMove(sq, to, 0, 0);
                }
            }
        }
        if (white && r == 0) {
            if ((_castleRights & 1) != 0 && _board[5] == PC_EMPTY && _board[6] == PC_EMPTY) {
                if (!isInCheck(true) && !sqAttacked(5, false) && !sqAttacked(6, false)) {
                    emitMove(sq, sq + 2, 3, 0);
                }
            }
            if ((_castleRights & 2) != 0 && _board[1] == PC_EMPTY && _board[2] == PC_EMPTY && _board[3] == PC_EMPTY) {
                if (!isInCheck(true) && !sqAttacked(3, false) && !sqAttacked(2, false)) {
                    emitMove(sq, sq - 2, 4, 0);
                }
            }
        }
        if (!white && r == 7) {
            if ((_castleRights & 4) != 0 && _board[61] == PC_EMPTY && _board[62] == PC_EMPTY) {
                if (!isInCheck(false) && !sqAttacked(61, true) && !sqAttacked(62, true)) {
                    emitMove(sq, sq + 2, 3, 0);
                }
            }
            if ((_castleRights & 8) != 0 && _board[57] == PC_EMPTY && _board[58] == PC_EMPTY && _board[59] == PC_EMPTY) {
                if (!isInCheck(false) && !sqAttacked(59, true) && !sqAttacked(58, true)) {
                    emitMove(sq, sq - 2, 4, 0);
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  ATTACK DETECTION
    // ═══════════════════════════════════════════════════════════════════════════

    hidden function isInCheck(white) {
        var kingPiece = white ? PC_KING : -PC_KING;
        var kingSq = -1;
        for (var i = 0; i < 64; i++) { if (_board[i] == kingPiece) { kingSq = i; break; } }
        if (kingSq < 0) { return true; }
        return sqAttacked(kingSq, !white);
    }

    hidden function sqAttacked(sq, byWhite) {
        var r = sq / 8; var f = sq % 8;

        var dir = byWhite ? -1 : 1;
        var pawnPiece = byWhite ? PC_PAWN : -PC_PAWN;
        if (f > 0) { var ps = (r + dir) * 8 + (f - 1); if (ps >= 0 && ps < 64 && _board[ps] == pawnPiece) { return true; } }
        if (f < 7) { var ps = (r + dir) * 8 + (f + 1); if (ps >= 0 && ps < 64 && _board[ps] == pawnPiece) { return true; } }

        var knightPiece = byWhite ? PC_KNIGHT : -PC_KNIGHT;
        var kdr = _kDR; var kdf = _kDF;
        for (var i = 0; i < 8; i++) {
            var nr = r + kdr[i]; var nf = f + kdf[i];
            if (nr >= 0 && nr < 8 && nf >= 0 && nf < 8 && _board[nr * 8 + nf] == knightPiece) { return true; }
        }

        var bq = byWhite ? PC_BISHOP : -PC_BISHOP;
        var qp = byWhite ? PC_QUEEN  : -PC_QUEEN;
        var ddr = _diagDR; var ddf = _diagDF;
        for (var di = 0; di < 4; di++) {
            var nr = r + ddr[di]; var nf = f + ddf[di];
            while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
                var t = _board[nr * 8 + nf];
                if (t != PC_EMPTY) { if (t == bq || t == qp) { return true; } break; }
                nr += ddr[di]; nf += ddf[di];
            }
        }

        var rq = byWhite ? PC_ROOK : -PC_ROOK;
        var sdr = _straightDR; var sdf = _straightDF;
        for (var di = 0; di < 4; di++) {
            var nr = r + sdr[di]; var nf = f + sdf[di];
            while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
                var t = _board[nr * 8 + nf];
                if (t != PC_EMPTY) { if (t == rq || t == qp) { return true; } break; }
                nr += sdr[di]; nf += sdf[di];
            }
        }

        var kp = byWhite ? PC_KING : -PC_KING;
        for (var dr = -1; dr <= 1; dr++) {
            for (var df = -1; df <= 1; df++) {
                if (dr == 0 && df == 0) { continue; }
                var kr = r + dr; var kf = f + df;
                if (kr >= 0 && kr < 8 && kf >= 0 && kf < 8 && _board[kr * 8 + kf] == kp) { return true; }
            }
        }
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  RENDERING
    // ═══════════════════════════════════════════════════════════════════════════

    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeometry(); }
        if (_gs == CS_MENU) { drawMenu(dc); return; }
        drawGame(dc);
        if (_gs == CS_PROMOTE)   { drawPromoOverlay(dc); }
        if (_gs == CS_CHECKMATE) {
            if (_aiVsAi) { drawEndOverlay(dc, "CHECKMATE", _whiteToMove ? "Black wins" : "White wins"); }
            else { drawEndOverlay(dc, (_whiteToMove == _playerIsWhite) ? "CHECKMATE" : "YOU WIN!", (_whiteToMove == _playerIsWhite) ? "You lose" : "Congratulations!"); }
        }
        if (_gs == CS_STALEMATE) { drawEndOverlay(dc, "STALEMATE", "Draw"); }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x080808, 0x080808); dc.clear();
        var hw = _w / 2;
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, hw, hw - 1);

        // Title
        dc.setColor(0xFFDD88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _h * 6 / 100, Graphics.FONT_MEDIUM, "CHESS", Graphics.TEXT_JUSTIFY_CENTER);

        var rowLabels = [
            _playerIsWhite ? "Color: WHITE" : "Color: BLACK",
            "Diff: " + (["Easy","Normal","Hard"][_difficulty]),
            _aiVsAi ? "Mode: AI vs AI" : "Mode: Player",
            "START"
        ];
        var nRows = 4;
        var rowH  = _h * 12 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 34) { rowH = 34; }
        var rowW  = _w * 78 / 100;
        var rowX  = (_w - rowW) / 2;
        var gap   = _h * 1 / 100; if (gap < 2) { gap = 2; }
        var total = nRows * rowH + (nRows - 1) * gap;
        var rowY0 = (_h - total) / 2 + rowH;

        for (var i = 0; i < nRows; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _menuRow);
            var isStart = (i == nRows - 1);

            dc.setColor(sel ? (isStart ? 0x1A4400 : 0x1A3A6A) : 0x111820, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x44BB22 : 0x55AAFF) : 0x2A3A4A, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);

            if (sel) {
                dc.setColor(isStart ? 0x44BB22 : 0x55AAFF, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }

            dc.setColor(sel ? (isStart ? 0xAAFF66 : 0xCCEEFF) : 0x778899, Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        rowLabels[i], Graphics.TEXT_JUSTIFY_CENTER);

            if (i == 0) {
                var dotX = rowX + rowW - 14;
                var dotY = ry + rowH / 2;
                dc.setColor(_playerIsWhite ? 0xFAF4E8 : 0x1A0A04, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dotX, dotY, 7);
                dc.setColor(_playerIsWhite ? 0x8B6030 : 0xD0A060, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(dotX, dotY, 7);
            }
        }

        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _h - 14, Graphics.FONT_XTINY,
                    "UP/DN move  SELECT act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function sqToScreen(sq) {
        var r = sq / 8; var f = sq % 8;
        var screenRow = _playerIsWhite ? (7 - r) : r;
        var screenCol = _playerIsWhite ? f : (7 - f);
        return [_ox + screenCol * _sq, _oy + screenRow * _sq];
    }

    hidden function drawGame(dc) {
        dc.setColor(0x080808, 0x080808); dc.clear();

        // Pass 1: squares + pieces
        for (var row = 0; row < 8; row++) {
            for (var col = 0; col < 8; col++) {
                var sq = row * 8 + col;
                var xy = sqToScreen(sq);
                var bx = xy[0]; var by = xy[1];
                var light = ((row + col) % 2 == 0);

                // Base square color
                var sqColor = light ? 0xF0D9A0 : 0x7A6048;

                var isLegal = false;
                for (var mi = 0; mi < _legalMoves.size(); mi++) {
                    if (_legalMoves[mi][1] == sq) { isLegal = true; break; }
                }

                // Destination highlight (keep subtle — ring will reinforce)
                if (isLegal) { sqColor = light ? 0xCCEE88 : 0x2A7730; }

                // King in check: red square
                if (_inCheck) {
                    var kPiece = _whiteToMove ? PC_KING : -PC_KING;
                    if (_board[sq] == kPiece) { sqColor = 0xAA2222; }
                }

                dc.setColor(sqColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, _sq, _sq);

                // Cursor: black outer + white separator + pulsing inner
                // Visible on every square color; pulses orange (piece selected) or cyan (browsing)
                if (sq == _curSq && (_gs == CS_PLAY || _gs == CS_PROMOTE)) {
                    var selMode = (_selSq >= 0);
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

                // Destination dot on empty squares
                if (isLegal && _board[sq] == PC_EMPTY) {
                    var dotR = _sq * 28 / 100; if (dotR < 3) { dotR = 3; }
                    dc.setColor(0x00DD44, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(bx + _sq / 2, by + _sq / 2, dotR);
                    dc.setColor(0x99FF88, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(bx + _sq / 2, by + _sq / 2, dotR * 5 / 10);
                }

                drawPiece(dc, bx, by, _board[sq]);
            }
        }

        // Pass 2: overlays drawn ON TOP of pieces — always visible regardless of piece color
        for (var row2 = 0; row2 < 8; row2++) {
            for (var col2 = 0; col2 < 8; col2++) {
                var sq2 = row2 * 8 + col2;
                var xy2 = sqToScreen(sq2);
                var bx2 = xy2[0]; var by2 = xy2[1];
                var cx2 = bx2 + _sq / 2; var cy2 = by2 + _sq / 2;

                // Selection ring — red for maximum visibility on any square colour
                if (sq2 == _selSq) {
                    var ringR = _sq * 38 / 100; if (ringR < 5) { ringR = 5; }
                    dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(cx2, cy2, ringR);
                    dc.drawCircle(cx2, cy2, ringR + 1);
                    dc.setColor(0xAA0000, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(cx2, cy2, ringR + 2);
                }

                // Destination ring on occupied squares
                var isLegal2 = false;
                for (var mi2 = 0; mi2 < _legalMoves.size(); mi2++) {
                    if (_legalMoves[mi2][1] == sq2) { isLegal2 = true; break; }
                }
                if (isLegal2 && _board[sq2] != PC_EMPTY) {
                    var capR = _sq * 40 / 100; if (capR < 5) { capR = 5; }
                    dc.setColor(0x00DD44, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(cx2, cy2, capR);
                    dc.drawCircle(cx2, cy2, capR - 1);
                }
            }
        }

        dc.setColor(0x3A2810, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_ox - 1, _oy - 1, _sq * 8 + 2, _sq * 8 + 2);
        dc.drawRectangle(_ox - 2, _oy - 2, _sq * 8 + 4, _sq * 8 + 4);

        drawHUD(dc);
    }

    hidden function drawHUD(dc) {
        var hy = _oy + _sq * 8 + 3;
        if (hy + 14 > _h) { hy = _oy - 14; }
        var isPlayerTurn = (_whiteToMove == _playerIsWhite) && (_gs == CS_PLAY);
        var turnStr = "";
        var hClr = 0xAA9977;
        if (_gs == CS_AI_THINK || _gs == CS_AI_EVAL || _gs == CS_AI_FINISH) {
            var dots = "";
            for (var i = 0; i < (_tick % 4); i++) { dots = dots + "."; }
            turnStr = "AI" + dots;
        } else if (_inCheck && isPlayerTurn) {
            turnStr = "CHECK! Move king"; hClr = 0xFF4444;
        } else if (isPlayerTurn) {
            if (_selSq >= 0) {
                turnStr = _legalMoves.size() > 1 ? "UP/DN switch  SEL move" : "SEL to move";
            } else {
                turnStr = _playerIsWhite ? "White to move" : "Black to move";
            }
        }
        dc.setColor(hClr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, hy, Graphics.FONT_XTINY, turnStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawPiece(dc, bx, by, piece) {
        if (piece == PC_EMPTY) { return; }
        var white = (piece > 0);
        var abs = white ? piece : -piece;
        var cx  = bx + _sq / 2;
        var bot = by + _sq - 1;
        var s   = _sq;

        var bodyC = white ? 0xFAF4E8 : 0x282010;
        var rimC  = white ? 0x8B6030 : 0xD0A060;
        var markC = white ? 0x3A2010 : 0xF0D080;

        if (abs == PC_PAWN) {
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s * 3 / 8, bot - s * 22 / 100, s * 3 / 4, s * 22 / 100, 2);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s * 3 / 8 + 1, bot - s * 22 / 100 + 1, s * 3 / 4 - 2, s * 22 / 100 - 1, 1);
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s / 10, bot - s * 65 / 100, s / 5, s * 43 / 100, 1);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s / 10 + 1, bot - s * 65 / 100 + 1, s / 5 - 2, s * 43 / 100 - 1, 0);
            var hr = s * 18 / 100;
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, bot - s * 65 / 100 - hr + 1, hr);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, bot - s * 65 / 100 - hr + 1, hr - 2);
        } else if (abs == PC_ROOK) {
            var bw = s * 56 / 100;
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2, bot - s * 72 / 100, bw, s * 72 / 100, 2);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2 + 1, bot - s * 72 / 100 + 1, bw - 2, s * 72 / 100 - 2, 1);
            var tw = bw / 4; var th = s / 6;
            for (var ti = 0; ti < 3; ti += 2) {
                dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cx - bw / 2 + ti * bw / 4, bot - s * 72 / 100 - th, tw, th + 2);
                dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cx - bw / 2 + ti * bw / 4 + 1, bot - s * 72 / 100 - th, tw - 2, th);
            }
        } else if (abs == PC_KNIGHT) {
            var bw = s * 50 / 100;
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2, bot - s * 72 / 100, bw, s * 72 / 100, 2);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2 + 1, bot - s * 72 / 100 + 1, bw - 2, s * 72 / 100 - 2, 1);
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 2, bot - s * 88 / 100, bw * 6 / 10, s * 26 / 100, 3);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 1, bot - s * 87 / 100, bw * 6 / 10 - 2, s * 25 / 100 - 2, 2);
        } else if (abs == PC_BISHOP) {
            var bw = s * 46 / 100;
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2, bot - s * 72 / 100, bw, s * 72 / 100, 3);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2 + 1, bot - s * 72 / 100 + 1, bw - 2, s * 72 / 100 - 2, 2);
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, bot - s * 78 / 100, s / 10);
            dc.setColor(markC, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - bw / 2 + 2, bot - s * 40 / 100, cx + bw / 2 - 2, bot - s * 40 / 100);
        } else if (abs == PC_QUEEN) {
            var bw = s * 62 / 100;
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2, bot - s * 72 / 100, bw, s * 72 / 100, 3);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2 + 1, bot - s * 72 / 100 + 1, bw - 2, s * 72 / 100 - 2, 2);
            var cy2 = bot - s * 72 / 100;
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy2 - s * 12 / 100, s * 10 / 100);
            dc.fillCircle(cx - bw / 3, cy2 - s * 8 / 100, s * 8 / 100);
            dc.fillCircle(cx + bw / 3, cy2 - s * 8 / 100, s * 8 / 100);
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy2 - s * 12 / 100, s * 7 / 100);
            dc.fillCircle(cx - bw / 3, cy2 - s * 8 / 100, s * 5 / 100);
            dc.fillCircle(cx + bw / 3, cy2 - s * 8 / 100, s * 5 / 100);
        } else if (abs == PC_KING) {
            var bw = s * 62 / 100;
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2, bot - s * 72 / 100, bw, s * 72 / 100, 3);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - bw / 2 + 1, bot - s * 72 / 100 + 1, bw - 2, s * 72 / 100 - 2, 2);
            var cy2 = bot - s * 72 / 100;
            dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 1, cy2 - s * 22 / 100, 3, s * 22 / 100 + 2);
            dc.fillRectangle(cx - s / 7, cy2 - s * 15 / 100, s * 2 / 7, 3);
        }
    }

    hidden function drawPieceType(dc, cx, cy, abs, s, white) {
        var bodyC = white ? 0xF0E8D0 : 0x1E0E06;
        var rimC  = white ? 0x6B4A28 : 0xC09050;
        if (abs >= 1 && abs <= 6) {
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s * 3 / 8, cy - s * 3 / 8, s * 3 / 4, s * 3 / 4, 3);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - s * 3 / 8 + 1, cy - s * 3 / 8 + 1, s * 3 / 4 - 2, s * 3 / 4 - 2, 2);
        }
    }

    hidden function drawPromoOverlay(dc) {
        var bw = _sq * 4 + 16; var bh = _sq + 28;
        var px = (_w - bw) / 2; var py = _h / 2 - bh / 2;
        dc.setColor(0x1A1008, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, bw, bh, 6);
        dc.setColor(0xAA8844, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, bw, bh, 6);

        var pieces = [PC_QUEEN, PC_ROOK, PC_BISHOP, PC_KNIGHT];
        var promWhite = _playerIsWhite;
        for (var i = 0; i < 4; i++) {
            var ix = px + 4 + i * (_sq + 3);
            var iy = py + 4;
            dc.setColor(i == _promPick ? 0x3388FF : 0x2A1A08, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(ix, iy, _sq, _sq, 3);
            drawPieceType(dc, ix + _sq / 2, iy + _sq / 2, pieces[i], _sq, promWhite);
        }
        dc.setColor(0xCCBB99, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, py + _sq + 10, Graphics.FONT_XTINY, "Promote! Tap/Select", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawThinkingBadge(dc) {
        var dots = "";
        var d = _tick % 4;
        for (var i = 0; i <= d; i++) { dots = dots + "."; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w / 2 - 44, _h - 22, 88, 18, 4);
        dc.setColor(0x66BBFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h - 20, Graphics.FONT_XTINY, "AI thinking" + dots, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawEndOverlay(dc, title, sub) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w / 2 - 70, _h / 2 - 30, 140, 60, 8);
        dc.setColor(0xAA7733, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_w / 2 - 70, _h / 2 - 30, 140, 60, 8);
        dc.setColor(0xFFDD55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h / 2 - 26, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h / 2 - 10, Graphics.FONT_XTINY, sub, Graphics.TEXT_JUSTIFY_CENTER);
        if (_tick % 8 < 5) {
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h / 2 + 12, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
