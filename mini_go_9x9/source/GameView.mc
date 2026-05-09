using Toybox.WatchUi;
using Toybox.Graphics;

// ── Module-level constants ─────────────────────────────────────────────────
const STONE_BLACK = 1;
const STONE_WHITE = 2;
const GS_PLAY     = 0;
const GS_OVER     = 1;

// 9×9 star-point positions (0-indexed, as grid indices)
// hoshi at (2,2) (4,2) (6,2) (2,4) (4,4) (6,4) (2,6) (4,6) (6,6)
// stored as [col0,row0, col1,row1, ...]

// ── GameView ───────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // ── layout ────────────────────────────────────────────────────────────
    hidden var _sw, _sh;
    hidden var _boardX, _boardY;  // top-left pixel of the first intersection
    hidden var _cell;             // pixels per grid step
    hidden var _sr;               // stone radius
    hidden var _bgX, _bgY;        // top-left pixel of wood background rectangle
    hidden var _bgSz;             // side length of wood background

    // ── game objects ──────────────────────────────────────────────────────
    hidden var _ctrl;

    // ── cursor position ───────────────────────────────────────────────────
    hidden var _curX, _curY;

    // ── flash for illegal-move feedback ───────────────────────────────────
    hidden var _illegalFlash;

    function initialize() {
        View.initialize();
        _ctrl        = new GameController();
        _curX        = 4;
        _curY        = 4;
        _illegalFlash = 0;
    }

    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();

        // Use 7% of screen width per cell so the board fits within the bezel.
        // 8 cells × cell + margin = 9 × cell ≤ inscribed-square side.
        _cell    = _sw * 7 / 100;
        if (_cell < 24) { _cell = 24; }

        var span = 8 * _cell;                    // distance from corner to corner
        _boardX  = (_sw - span) / 2;
        _boardY  = (_sh - span) / 2 + _sh * 4 / 100;  // slight downward shift for HUD

        _bgSz    = 9 * _cell;
        _bgX     = _boardX - _cell / 2;
        _bgY     = _boardY - _cell / 2;

        _sr = _cell * 43 / 100;
        if (_sr < 9) { _sr = 9; }
    }

    // ── public input API (called by GameDelegate) ─────────────────────────
    function moveCursor(dx, dy) {
        _curX = _curX + dx;
        _curY = _curY + dy;
        if (_curX < 0) { _curX = 0; }
        if (_curX > 8) { _curX = 8; }
        if (_curY < 0) { _curY = 0; }
        if (_curY > 8) { _curY = 8; }
    }

    // SELECT: place stone (during play) or start new game (after game over)
    function doAction() {
        if (_ctrl.gameOver != 0) {
            _ctrl.newGame();
            _curX = 4; _curY = 4;
            _illegalFlash = 0;
            return;
        }
        if (!_ctrl.playerMove(_curX, _curY)) {
            _illegalFlash = 6;  // brief red blink on illegal move
        }
    }

    // BACK: pass (or new game)
    function doPass() {
        if (_ctrl.gameOver != 0) {
            _ctrl.newGame();
            _curX = 4; _curY = 4;
            _illegalFlash = 0;
            return true;
        }
        _ctrl.playerPass();
        return true;
    }

    // ── rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_illegalFlash > 0) { _illegalFlash = _illegalFlash - 1; }

        // Background
        dc.setColor(0x1A1208, 0x1A1208);
        dc.clear();

        _drawBoard(dc);
        _drawHUD(dc);

        if (_ctrl.gameOver != 0) { _drawGameOver(dc); }
    }

    // ── board drawing ──────────────────────────────────────────────────────
    hidden function _drawBoard(dc) {
        // Wood background
        dc.setColor(0xC8A040, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_bgX, _bgY, _bgSz, _bgSz, 4);

        // Grid lines
        dc.setColor(0x7B4F1C, Graphics.COLOR_TRANSPARENT);
        var li = 0;
        while (li < 9) {
            var lx = _boardX + li * _cell;
            var ly = _boardY + li * _cell;
            dc.drawLine(lx, _boardY, lx, _boardY + 8 * _cell);
            dc.drawLine(_boardX, ly, _boardX + 8 * _cell, ly);
            li = li + 1;
        }

        // Star points (hoshi) — 9 positions at columns/rows 2, 4, 6
        dc.setColor(0x5C3317, Graphics.COLOR_TRANSPARENT);
        var hoshi = [2, 4, 6];
        var hi = 0;
        while (hi < 3) {
            var hj = 0;
            while (hj < 3) {
                var hx = _boardX + hoshi[hi] * _cell;
                var hy = _boardY + hoshi[hj] * _cell;
                dc.fillCircle(hx, hy, _cell * 10 / 100 + 1);
                hj = hj + 1;
            }
            hi = hi + 1;
        }

        // Stones
        var si = 0;
        while (si < 81) {
            var sv = _ctrl.board.grid[si];
            if (sv != 0) {
                var sx = _boardX + (si % 9) * _cell;
                var sy = _boardY + (si / 9) * _cell;
                _drawStone(dc, sx, sy, sv, si == _ctrl.lastMoveIdx);
            }
            si = si + 1;
        }

        // Cursor — only during active play
        if (_ctrl.gameOver == 0) {
            _drawCursor(dc);
        }
    }

    hidden function _drawStone(dc, px, py, color, isLast) {
        if (color == STONE_BLACK) {
            dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, _sr);
            // subtle highlight
            dc.setColor(0x404040, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - _sr / 3, py - _sr / 3, _sr / 4);
        } else {
            dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, _sr);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(px, py, _sr);
            // highlight
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - _sr / 3, py - _sr / 3, _sr / 5);
        }
        // Last-move marker: small contrasting dot
        if (isLast) {
            var mc = (color == STONE_BLACK) ? 0xCCCCCC : 0x333333;
            dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, _sr * 25 / 100);
        }
    }

    hidden function _drawCursor(dc) {
        var px = _boardX + _curX * _cell;
        var py = _boardY + _curY * _cell;
        var hs = _sr + 3;

        // Colour: green normally, red when last move was illegal
        var col = (_illegalFlash > 0) ? 0xFF3300 : 0x00FF44;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(px - hs, py - hs, hs * 2, hs * 2);
        dc.drawRectangle(px - hs + 1, py - hs + 1, hs * 2 - 2, hs * 2 - 2);
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var hudY = _bgY - _cell * 2 / 3;
        if (hudY < 5) { hudY = 5; }

        // Turn indicator
        if (_ctrl.gameOver == 0) {
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, hudY, Graphics.FONT_XTINY,
                "YOUR TURN (BLACK)", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Captured stone counts
        var capY = hudY + 14;
        if (capY > _bgY - 4) { capY = _bgY - 4; }
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw * 22 / 100, capY, Graphics.FONT_XTINY,
            "B cap " + _ctrl.board.capWhite.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_sw * 78 / 100, capY, Graphics.FONT_XTINY,
            "W cap " + _ctrl.board.capBlack.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);

        // Pass hint below board
        var hintY = _bgY + _bgSz + 6;
        if (hintY < _sh - 20) {
            dc.setColor(0x3a3a3a, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, hintY, Graphics.FONT_XTINY,
                "BACK = pass", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── game-over overlay ─────────────────────────────────────────────────
    hidden function _drawGameOver(dc) {
        var bs = _ctrl.board.scoreBlack;
        var ws = _ctrl.board.scoreWhite;

        var bw = _sw * 44 / 100;
        var bh = _sh * 30 / 100;
        if (bw < 120) { bw = 120; }
        if (bh < 96)  { bh = 96; }
        var bx = _sw / 2 - bw / 2;
        var by = _sh / 2 - bh / 2;

        dc.setColor(0x0A0A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 8);
        dc.setColor(0x3A2A08, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 8);

        var cx = _sw / 2;
        // Title
        dc.setColor(0xC8A040, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 5, Graphics.FONT_XTINY, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        // Scores
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 22, Graphics.FONT_XTINY,
            "Black: " + bs.format("%d") + "  White: " + ws.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);

        // Winner
        var wMsg = "";
        if (bs > ws) { wMsg = "BLACK WINS!"; dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT); }
        else if (ws > bs) { wMsg = "WHITE WINS!"; dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT); }
        else { wMsg = "DRAW!"; dc.setColor(0xAAAA44, Graphics.COLOR_TRANSPARENT); }
        dc.drawText(cx, by + 42, Graphics.FONT_SMALL, wMsg, Graphics.TEXT_JUSTIFY_CENTER);

        // Komi note
        dc.setColor(0x444433, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 64, Graphics.FONT_XTINY,
            "(White +7 komi)", Graphics.TEXT_JUSTIFY_CENTER);

        // Instruction
        dc.setColor(0x333322, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 13, Graphics.FONT_XTINY,
            "SELECT = new game", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
