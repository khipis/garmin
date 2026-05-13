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
const GS_MENU     = 10;  // pre-game menu
const ANIM_TICKS  = 3;   // animation frames per flip (×100 ms = 300 ms total)
const MODE_PVAI   = 0;
const MODE_PVP    = 1;
const MODE_AIAI   = 2;
const DIFF_EASY   = 0;
const DIFF_MED    = 1;
const DIFF_HARD   = 2;

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

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden var _mode;
    hidden var _diff;
    hidden var _menuSel;
    hidden var _playerFirst;
    hidden var _playerColor;  // DISC_BLACK or DISC_WHITE
    hidden var _aiColor;

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
        _mode        = MODE_PVAI;
        _diff        = DIFF_MED;
        _menuSel     = 0;
        _playerFirst = true;
        _playerColor = DISC_BLACK;
        _aiColor     = DISC_WHITE;
        _gameState   = GS_MENU;
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

        _timer = new Timer.Timer();
        _timer.start(method(:gameTick), 100, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Public input API (GameDelegate) ───────────────────────────────────

    function moveCursor(dx, dy) {
        if (_gameState == GS_MENU) {
            if (dy < 0 || dx < 0) { _menuSel = (_menuSel + 3) % 4; }
            else if (dy > 0 || dx > 0) { _menuSel = (_menuSel + 1) % 4; }
            WatchUi.requestUpdate();
            return;
        }
        if (_gameState != GS_PLAYER && !(_gameState == GS_AI && _mode == MODE_PVP)) { return; }
        // dx != 0 → horizontal wrap along current row
        // dy != 0 → vertical wrap along current column
        if (dx != 0) {
            _curX = (_curX + dx + 8) % 8;
        } else if (dy != 0) {
            _curY = (_curY + dy + 8) % 8;
        }
    }

    function doBack() {
        if (_gameState == GS_MENU) { return false; }
        _gameState = GS_MENU; _menuSel = 0;
        WatchUi.requestUpdate();
        return true;
    }

    // SELECT: place disc or start new game
    function doAction() {
        if (_gameState == GS_MENU) {
            if (_menuSel == 0) { _mode = (_mode + 1) % 3; }
            else if (_menuSel == 1) { _diff = (_diff + 1) % 3; }
            else if (_menuSel == 2) { if (_mode == MODE_PVAI) { _playerFirst = !_playerFirst; } }
            else {
                _playerColor = _playerFirst ? DISC_BLACK : DISC_WHITE;
                _aiColor     = _playerFirst ? DISC_WHITE : DISC_BLACK;
                _startGame();
            }
            WatchUi.requestUpdate();
            return;
        }
        if (_gameState == GS_OVER) { _gameState = GS_MENU; _menuSel = 0; WatchUi.requestUpdate(); return; }
        // PvP: P2 also places via cursor when it's GS_AI state
        var isP2Turn = (_gameState == GS_AI && _mode == MODE_PVP);
        if (_gameState != GS_PLAYER && !isP2Turn) { return; }
        if (_validMoves[_curY * 8 + _curX] == 0) { return; }
        var col = isP2Turn ? _aiColor : _playerColor;
        if (_board.placeDisc(_curX, _curY, col)) {
            _startAnim(col);
        }
    }

    // ── 100 ms timer tick ─────────────────────────────────────────────────
    function gameTick() as Void {
        if (_gameState == GS_MENU) { return; }
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
            if (_mode != MODE_PVP) { _doAiMoveAs(_aiColor); }
            // PvP: P2 uses cursor — do nothing here
        } else if (_gameState == GS_PLAYER && _mode == MODE_AIAI) {
            _doAiMoveAs(_playerColor);
        }
        WatchUi.requestUpdate();
    }

    // ── Internal helpers ──────────────────────────────────────────────────

    hidden function _startGame() {
        _board.newGame();
        _animTick  = 0;
        _passNotif = 0;
        _curX = 3; _curY = 3;
        // Black always goes first in Othello
        if (_playerColor == DISC_BLACK || _mode == MODE_AIAI) {
            _gameState = GS_PLAYER;
            if (_mode != MODE_AIAI) { _computeValidMoves(); }
        } else {
            _gameState = GS_AI;
        }
        if (_mode == MODE_PVP) { _computeValidMoves(); }
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
        _gameState = (_animTargetCol == _playerColor) ? GS_ANIM_P : GS_ANIM_AI;
    }

    // AI makes its move for a given colour (or passes if no valid move).
    hidden function _doAiMoveAs(color) {
        var move = _ai.chooseMove(color);
        if (move >= 0) {
            var mx = move % 8; var my = move / 8;
            if (_board.placeDisc(mx, my, color)) {
                _startAnim(color);
                return;
            }
        }
        _advanceTurn();
    }

    // Decide whose turn is next; detect game-over.
    hidden function _advanceTurn() {
        var pCan = _board.hasValidMoves(_playerColor);
        var aCan = _board.hasValidMoves(_aiColor);

        if (!pCan && !aCan) {
            _gameState = GS_OVER;
            return;
        }
        if (!pCan) {
            _passNotif = 18;
            _gameState = GS_AI;
            if (_mode == MODE_PVP) { _computeValidMoves(); }  // P2 needs valid moves
            return;
        }
        _gameState = GS_PLAYER;
        if (_mode != MODE_AIAI) { _computeValidMoves(); }
    }

    // Refresh valid-move cache: for the current human's turn.
    // In PvP GS_AI = P2's turn so compute for _aiColor.
    hidden function _computeValidMoves() {
        var col = (_gameState == GS_AI && _mode == MODE_PVP) ? _aiColor : _playerColor;
        var i = 0;
        while (i < 64) {
            _validMoves[i] = (_board.isValidAt(i % 8, i / 8, col)) ? 1 : 0;
            i = i + 1;
        }
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_gameState == GS_MENU) { _drawMenu(dc); return; }
        // Dark background
        dc.setColor(0x0A120A, 0x0A120A);
        dc.clear();

        _drawBoard(dc);
        _drawHUD(dc);

        if (_passNotif > 0)          { _drawPassNotif(dc); }
        if (_gameState == GS_OVER)   { _drawGameOver(dc); }
    }

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        dc.setColor(0x080808, 0x080808); dc.clear();
        var hw = _sw / 2;
        dc.setColor(0x0A0A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, hw, hw - 1);
        dc.setColor(0x1A7A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 11 / 100, Graphics.FONT_SMALL, "OTHELLO", Graphics.TEXT_JUSTIFY_CENTER);
        var modeStr = (_mode == MODE_PVAI) ? "P vs AI" : ((_mode == MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
        var sideStr = _playerFirst ? "Side: Blk" : "Side: Wht";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, sideStr, "START"];
        var nR = 4;
        var rowH = _sh * 10 / 100; if (rowH < 20) { rowH = 20; } if (rowH > 28) { rowH = 28; }
        var rowW = _sw * 74 / 100;
        var rowX = (_sw - rowW) / 2;
        var gap  = 5;
        var tot  = nR * rowH + (nR - 1) * gap;
        var rowY0 = (_sh - tot) / 2 + rowH;
        var i = 0;
        while (i < nR) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _menuSel);
            var isStart = (i == nR - 1);
            dc.setColor(sel ? (isStart ? 0x1A3A1A : 0x0A2040) : 0x0A0A0A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x44CC44 : 0x4499FF) : 0x1A3A1A, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                dc.setColor(isStart ? 0x44CC44 : 0x4499FF, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }
            var dimmed = (i == 1 && _mode == MODE_PVP) || (i == 2 && _mode != MODE_PVAI);
            dc.setColor(dimmed ? 0x445566 : (sel ? (isStart ? 0xAAFFAA : 0xAADDFF) : 0x556677),
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2, Graphics.FONT_XTINY, rows[i], Graphics.TEXT_JUSTIFY_CENTER);
            i++;
        }
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh - 14, Graphics.FONT_XTINY, "UP/DN sel  SELECT set/start", Graphics.TEXT_JUSTIFY_CENTER);
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
        if (_gameState == GS_PLAYER || _gameState == GS_ANIM_P) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            var lbl = (_mode == MODE_PVP) ? "P1" : ((_mode == MODE_AIAI) ? "B" : "YOU");
            dc.drawText(_sw / 2 - 4, txtY, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_gameState == GS_AI || _gameState == GS_ANIM_AI) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            var lbl2 = (_mode == MODE_PVP) ? "P2" : ((_mode == MODE_AIAI) ? "W" : "AI");
            dc.drawText(_sw / 2 - 4, txtY, Graphics.FONT_XTINY, lbl2, Graphics.TEXT_JUSTIFY_CENTER);
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
        var playerWins = (_playerColor == DISC_BLACK) ? (bc > wc) : (wc > bc);
        var aiWins     = (_playerColor == DISC_BLACK) ? (wc > bc) : (bc > wc);
        if      (playerWins) { msg = "YOU WIN!";   msgCol = 0x44FF44; }
        else if (aiWins)     { msg = "AI WINS!";   msgCol = 0xAAAAAA; }
        else                 { msg = "DRAW!";       msgCol = 0xBBBB44; }
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

    function doTap(tx, ty) {
        if (_gameState == GS_MENU) {
            var nR = 4;
            var rowH = _sh * 10 / 100; if (rowH < 20) { rowH = 20; } if (rowH > 28) { rowH = 28; }
            var rowW = _sw * 74 / 100;
            var rowX = (_sw - rowW) / 2;
            var gap  = 5;
            var tot  = nR * rowH + (nR - 1) * gap;
            var rowY0 = (_sh - tot) / 2 + rowH;
            for (var i = 0; i < nR; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (tx >= rowX && tx < rowX + rowW && ty >= ry && ty < ry + rowH) {
                    _menuSel = i; doAction(); return;
                }
            }
            return;
        }
        if (_gameState == GS_OVER) { _gameState = GS_MENU; _menuSel = 0; return; }
        if (_gameState != GS_PLAYER && !(_gameState == GS_AI && _mode == MODE_PVP)) { return; }
        if (_cell <= 0) { return; }
        var col = (tx - _boardX) / _cell;
        var row = (ty - _boardY) / _cell;
        if (col < 0 || col >= 8 || row < 0 || row >= 8) { return; }
        _curX = col; _curY = row;
        doAction();
    }
}
