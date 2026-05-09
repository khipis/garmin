using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

// ── Module-level constants ─────────────────────────────────────────────────
const DISC_BLACK  = 1;
const DISC_WHITE  = 2;
const GS_PLAYER   = 0;   // human's turn — cursor active
const GS_ANIM_P   = 1;   // player flip animation in progress
const GS_AI       = 2;   // AI will move on next gameTick
const GS_ANIM_AI  = 3;   // AI flip animation in progress
const GS_OVER     = 4;   // game over
const ANIM_TICKS  = 3;   // animation frames per flip (×100 ms = 300 ms total)

// ── GameView ───────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // ── Layout ────────────────────────────────────────────────────────────
    hidden var _sw, _sh;
    hidden var _boardX, _boardY;  // top-left pixel of the board grid
    hidden var _cell;             // pixels per cell
    hidden var _sr;               // disc radius

    // ── Game objects ──────────────────────────────────────────────────────
    hidden var _board;
    hidden var _ai;

    // ── Cursor ────────────────────────────────────────────────────────────
    hidden var _curX, _curY;

    // ── State machine ─────────────────────────────────────────────────────
    hidden var _gameState;

    // ── Flip animation ────────────────────────────────────────────────────
    hidden var _animTick;        // counts down from ANIM_TICKS → 0
    hidden var _animTargetCol;   // colour flipping discs become
    hidden var _flippingSet;     // int[64]: 1 = this cell is mid-animation

    // ── Valid-move cache (player turn only) ───────────────────────────────
    hidden var _validMoves;      // int[64]

    // ── "PASS!" notification ──────────────────────────────────────────────
    hidden var _passNotif;       // ticks remaining to show "PASS!" text

    // ── Timer ─────────────────────────────────────────────────────────────
    hidden var _timer;

    function initialize() {
        View.initialize();
        _board       = new Board();
        _ai          = new AI(_board);
        _flippingSet = new [64];
        _validMoves  = new [64];
        _timer       = null;
        _animTick    = 0;
        _passNotif   = 0;
        _curX = 3; _curY = 3;
        _gameState = GS_PLAYER;
    }

    function onLayout(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();

        // Board sized to 68% of screen width, centred with small downward shift for HUD.
        var bsz  = _sw * 68 / 100;
        _cell    = bsz / 8;
        _boardX  = (_sw - bsz) / 2;
        _boardY  = (_sh - bsz) / 2 + _sh * 3 / 100;

        _sr = _cell * 44 / 100;
        if (_sr < 8) { _sr = 8; }

        _startGame();

        _timer = new Timer.Timer();
        _timer.start(method(:gameTick), 100, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Public input API (GameDelegate) ───────────────────────────────────

    function moveCursor(dx, dy) {
        if (_gameState != GS_PLAYER) { return; }
        _curX = _curX + dx; _curY = _curY + dy;
        if (_curX < 0) { _curX = 0; } if (_curX > 7) { _curX = 7; }
        if (_curY < 0) { _curY = 0; } if (_curY > 7) { _curY = 7; }
    }

    // SELECT: place disc or start new game
    function doAction() {
        if (_gameState == GS_OVER) { _startGame(); return; }
        if (_gameState != GS_PLAYER) { return; }
        if (_validMoves[_curY * 8 + _curX] == 0) { return; }  // not a valid cell
        if (_board.placeDisc(_curX, _curY, DISC_BLACK)) {
            _startAnim(DISC_BLACK);
        }
    }

    // ── 100 ms timer tick ─────────────────────────────────────────────────
    function gameTick() {
        // Always decrement pass notification (independent of animation state)
        if (_passNotif > 0) { _passNotif = _passNotif - 1; }

        if (_animTick > 0) {
            _animTick = _animTick - 1;
            if (_animTick == 0) {
                _board.applyFlips(_animTargetCol);
                if (_gameState == GS_ANIM_P) {
                    _gameState = GS_AI;
                } else {                  // GS_ANIM_AI
                    _advanceTurn();
                }
            }
        } else if (_gameState == GS_AI) {
            _doAiMove();
        }
        WatchUi.requestUpdate();
    }

    // ── Internal helpers ──────────────────────────────────────────────────

    hidden function _startGame() {
        _board.newGame();
        _gameState = GS_PLAYER;
        _animTick  = 0;
        _passNotif = 0;
        _curX = 3; _curY = 3;
        _computeValidMoves();
    }

    // Begin flip animation for 'targetCol' using the current board.flipBuf.
    hidden function _startAnim(targetCol) {
        _animTargetCol = targetCol;
        _animTick      = ANIM_TICKS;
        var i = 0;
        while (i < 64) { _flippingSet[i] = 0; i = i + 1; }
        i = 0;
        while (i < _board.flipCount) {
            _flippingSet[_board.flipBuf[i]] = 1;
            i = i + 1;
        }
        _gameState = (targetCol == DISC_BLACK) ? GS_ANIM_P : GS_ANIM_AI;
    }

    // AI makes its move (or passes if no valid move exists).
    hidden function _doAiMove() {
        var move = _ai.chooseMove(DISC_WHITE);
        if (move >= 0) {
            var mx = move % 8; var my = move / 8;
            if (_board.placeDisc(mx, my, DISC_WHITE)) {
                _startAnim(DISC_WHITE);
                return;
            }
        }
        // AI passes — advance turn directly
        _advanceTurn();
    }

    // Decide whose turn is next; detect game-over.
    hidden function _advanceTurn() {
        var pCan = _board.hasValidMoves(DISC_BLACK);
        var aCan = _board.hasValidMoves(DISC_WHITE);

        if (!pCan && !aCan) {
            _gameState = GS_OVER;
            return;
        }
        if (!pCan) {
            // Player has no moves — auto-pass; AI goes immediately
            _passNotif = 18;  // 1.8 s notification
            _gameState = GS_AI;
            return;
        }
        _gameState = GS_PLAYER;
        _computeValidMoves();
    }

    // Refresh valid-move cache for the human player (Black).
    hidden function _computeValidMoves() {
        var i = 0;
        while (i < 64) {
            _validMoves[i] = (_board.isValidAt(i % 8, i / 8, DISC_BLACK)) ? 1 : 0;
            i = i + 1;
        }
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        // Dark background
        dc.setColor(0x0A120A, 0x0A120A);
        dc.clear();

        _drawBoard(dc);
        _drawHUD(dc);

        if (_passNotif > 0)          { _drawPassNotif(dc); }
        if (_gameState == GS_OVER)   { _drawGameOver(dc); }
    }

    // ── Board ─────────────────────────────────────────────────────────────
    hidden function _drawBoard(dc) {
        var bsz = 8 * _cell;

        // Board background (dark green)
        dc.setColor(0x1A7A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_boardX, _boardY, bsz, bsz);

        // Grid lines (darker green, 9 lines each axis)
        dc.setColor(0x0D5C0D, Graphics.COLOR_TRANSPARENT);
        var li = 0;
        while (li <= 8) {
            var lx = _boardX + li * _cell;
            var ly = _boardY + li * _cell;
            dc.drawLine(lx, _boardY, lx, _boardY + bsz);
            dc.drawLine(_boardX, ly, _boardX + bsz, ly);
            li = li + 1;
        }

        // Valid-move dots (player turn only)
        if (_gameState == GS_PLAYER) {
            var dotR = _sr / 4;
            if (dotR < 2) { dotR = 2; }
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            var vi = 0;
            while (vi < 64) {
                if (_validMoves[vi] != 0 && _board.cells[vi] == 0) {
                    var vx = _boardX + (vi % 8) * _cell + _cell / 2;
                    var vy = _boardY + (vi / 8) * _cell + _cell / 2;
                    dc.fillCircle(vx, vy, dotR);
                }
                vi = vi + 1;
            }
        }

        // Discs (with optional squish animation for flipping ones)
        var di = 0;
        while (di < 64) {
            var dv = _board.cells[di];
            if (dv != 0) {
                var dpx = _boardX + (di % 8) * _cell + _cell / 2;
                var dpy = _boardY + (di / 8) * _cell + _cell / 2;

                if (_animTick > 0 && _flippingSet[di] != 0) {
                    // Squish: h shrinks from sr → 0 over animation ticks
                    var h = _sr * _animTick / ANIM_TICKS;
                    if (h < 2) { h = 2; }
                    // First 2 ticks: show old colour; last tick: show target colour
                    var drawCol = (_animTick >= 2) ? dv : _animTargetCol;
                    _drawDiscH(dc, dpx, dpy, drawCol, h);
                } else {
                    _drawDisc(dc, dpx, dpy, dv);
                }
            }
            di = di + 1;
        }

        // Cursor highlight
        if (_gameState == GS_PLAYER) {
            var cpx = _boardX + _curX * _cell;
            var cpy = _boardY + _curY * _cell;
            var curCol = (_validMoves[_curY * 8 + _curX] != 0) ? 0xFFFF00 : 0xFF6600;
            dc.setColor(curCol, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(cpx,     cpy,     _cell,     _cell);
            dc.drawRectangle(cpx + 1, cpy + 1, _cell - 2, _cell - 2);
        }
    }

    // Full-size disc with highlight.
    hidden function _drawDisc(dc, px, py, col) {
        if (col == DISC_BLACK) {
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, _sr);
            dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, _sr);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(px, py, _sr);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        }
        // Highlight dot (top-left quadrant)
        var hr = _sr / 4; if (hr < 2) { hr = 2; }
        dc.fillCircle(px - _sr / 3, py - _sr / 3, hr);
    }

    // Squished disc (flip animation): pill shape of half-height h.
    hidden function _drawDiscH(dc, px, py, col, h) {
        if (col == DISC_BLACK) {
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRoundedRectangle(px - _sr, py - h, _sr * 2, h * 2, h);
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var hudCY = _boardY / 2;             // vertical centre of HUD strip
        var txtY  = hudCY - 7;               // text top edge (FONT_XTINY ≈14 px tall)
        var iconR = 6;

        // Black disc icon + count (left of centre)
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_sw / 2 - 30, hudCY, iconR);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_sw / 2 - 30, hudCY, iconR);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2 - 20, txtY, Graphics.FONT_XTINY,
                    _board.blackCount.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);

        // White disc icon + count (right of centre)
        dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_sw / 2 + 22, hudCY, iconR);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_sw / 2 + 22, hudCY, iconR);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2 + 32, txtY, Graphics.FONT_XTINY,
                    _board.whiteCount.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);

        // Turn label (centred between the two disc icons)
        if (_gameState == GS_PLAYER) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2 - 4, txtY, Graphics.FONT_XTINY,
                        "YOU", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_gameState == GS_AI || _gameState == GS_ANIM_AI) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2 - 4, txtY, Graphics.FONT_XTINY,
                        "AI", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // BACK = exit hint (below board)
        var hintY = _boardY + 8 * _cell + 8;
        if (hintY < _sh - 14) {
            dc.setColor(0x2A3A2A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, hintY, Graphics.FONT_XTINY,
                        "BACK = exit", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── "YOUR TURN SKIPPED" notification ──────────────────────────────────
    hidden function _drawPassNotif(dc) {
        dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh / 2 - _sh * 12 / 100,
                    Graphics.FONT_SMALL, "PASS!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAA6600, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh / 2 - _sh * 12 / 100 + 20,
                    Graphics.FONT_XTINY, "no valid moves", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game-over overlay ─────────────────────────────────────────────────
    hidden function _drawGameOver(dc) {
        var bc = _board.blackCount; var wc = _board.whiteCount;

        var bw = _sw * 52 / 100; var bh = _sh * 30 / 100;
        if (bw < 132) { bw = 132; } if (bh < 90) { bh = 90; }
        var bx = _sw / 2 - bw / 2; var by = _sh / 2 - bh / 2;

        dc.setColor(0x080808, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 8);
        dc.setColor(0x1A6A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 8);

        var cx = _sw / 2;

        // Winner message
        var msgCol;
        var msg;
        if      (bc > wc) { msg = "BLACK WINS!"; msgCol = 0xAAAAAA; }
        else if (wc > bc) { msg = "WHITE WINS!"; msgCol = 0xEEEEEE; }
        else              { msg = "DRAW!";        msgCol = 0xBBBB44; }
        dc.setColor(msgCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 8, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);

        // Scores
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 34, Graphics.FONT_XTINY,
                    "B: " + bc.format("%d") + "   W: " + wc.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // New-game prompt
        dc.setColor(0x2A4A2A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "SELECT = new game", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
