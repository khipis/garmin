using Toybox.WatchUi;
using Toybox.Graphics;

// ── Module-level constants ─────────────────────────────────────────────────
const STONE_BLACK = 1;
const STONE_WHITE = 2;
const GS_PLAY     = 0;
const GS_OVER     = 1;
const GS_MENU     = 10;
const MODE_PVAI   = 0;
const MODE_PVP    = 1;
const DIFF_EASY   = 0;
const DIFF_MED    = 1;
const DIFF_HARD   = 2;

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

    // ── view state and pre-game menu ──────────────────────────────────────
    hidden var _state;
    hidden var _mode, _diff, _menuSel;
    hidden var _playerFirst;

    function initialize() {
        View.initialize();
        _ctrl         = new GameController();
        _curX         = 4;
        _curY         = 4;
        _illegalFlash = 0;
        _mode         = MODE_PVAI;
        _diff         = DIFF_MED;
        _menuSel      = 0;
        _playerFirst  = true;
        _state        = GS_MENU;
    }

    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();

        // 7 % per cell — board background spans 63 % of screen (fits round watches).
        _cell    = _sw * 6 / 100;
        if (_cell < 24) { _cell = 24; }

        var span = 8 * _cell;                              // corner-to-corner distance
        _boardX  = (_sw - span) / 2;
        _boardY  = (_sh - span) / 2 + _sh * 4 / 100;     // slight downward shift for HUD

        _bgSz    = 9 * _cell;
        _bgX     = _boardX - _cell / 2;
        _bgY     = _boardY - _cell / 2;

        _sr = _cell * 43 / 100;
        if (_sr < 9) { _sr = 9; }
    }

    // ── public input API (called by GameDelegate) ─────────────────────────

    // KEY_UP (dy=-1) / KEY_DOWN (dy=1): row movement with wrapping.
    // In menu state: navigates rows forward / backward.
    function moveCursor(dx, dy) {
        if (_state == GS_MENU) {
            if (dy < 0) { _menuSel = (_menuSel + 3) % 4; }
            else if (dy > 0) { _menuSel = (_menuSel + 1) % 4; }
            return;
        }
        if (_ctrl.gameOver != 0) { return; }
        _curX = _curX + dx;
        if (_curX < 0) { _curX = 0; }
        if (_curX > 8) { _curX = 8; }
        _curY = _curY + dy;
        if (_curY < 0) { _curY = 8; }   // wrap top → bottom
        if (_curY > 8) { _curY = 0; }   // wrap bottom → top
    }

    // onNextPage (DOWN button): reading-order advance col+1, wrap rows.
    // In menu state: navigate forward.
    // onNextPage: move RIGHT in current row, wrap to col=0
    function advanceCursor() {
        if (_state == GS_MENU) {
            _menuSel = (_menuSel + 1) % 4;
            return;
        }
        if (_ctrl.gameOver != 0) { return; }
        _curX = (_curX + 1) % 9;
    }

    // onPreviousPage: move DOWN in current column, wrap to row=0
    function retreatCursor() {
        if (_state == GS_MENU) {
            _menuSel = (_menuSel + 3) % 4;
            return;
        }
        if (_ctrl.gameOver != 0) { return; }
        _curY = (_curY + 1) % 9;
    }

    // SELECT: cycle menu option / place stone / return to menu after game over.
    // BACK: menu → pop app, in-game → return to menu
    function doBack() {
        if (_state == GS_MENU) { return false; }
        _state = GS_MENU; _menuSel = 0;
        return true;
    }

    function doAction() {
        if (_state == GS_MENU) {
            if (_menuSel == 0) {
                _mode = (_mode + 1) % 2;
            } else if (_menuSel == 1) {
                if (_mode != MODE_PVP) { _diff = (_diff + 1) % 3; }
            } else if (_menuSel == 2) {
                if (_mode == MODE_PVAI) { _playerFirst = !_playerFirst; }
            } else {
                _ctrl.newGame();
                _ctrl.ai.setDiff(_diff);
                _curX = 4; _curY = 4;
                _illegalFlash = 0;
                _state = GS_PLAY;
                if (_mode == MODE_PVAI && !_playerFirst) { _ctrl.aiFirstMove(); }
            }
            return;
        }
        if (_ctrl.gameOver != 0) {
            _state = GS_MENU;
            _menuSel = 0;
            _illegalFlash = 0;
            return;
        }
        if (!_ctrl.playerMove(_curX, _curY)) {
            _illegalFlash = 6;
        }
    }

    // BACK: pass during play; returns false (→ pop view) in menu.
    function doPass() {
        if (_state == GS_MENU) { return false; }
        if (_ctrl.gameOver != 0) {
            _state = GS_MENU;
            _menuSel = 0;
            _illegalFlash = 0;
            return true;
        }
        _ctrl.playerPass();
        return true;
    }

    // ── rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_state == GS_MENU) { _drawMenu(dc); return; }

        if (_illegalFlash > 0) { _illegalFlash = _illegalFlash - 1; }

        dc.setColor(0x1A1208, 0x1A1208);
        dc.clear();

        _drawBoard(dc);
        _drawHUD(dc);

        if (_ctrl.gameOver != 0) { _drawGameOver(dc); }
    }

    // ── pre-game menu ─────────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        dc.setColor(0x080810, 0x080810);
        dc.clear();
        var hw = _sw / 2;
        dc.setColor(0x0A0A18, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, _sh / 2, _sw / 2 - 1);

        dc.setColor(0xC8A040, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 11 / 100, Graphics.FONT_SMALL, "MINI GO 9x9", Graphics.TEXT_JUSTIFY_CENTER);

        var modeStr = (_mode == MODE_PVAI) ? "P vs AI" : "P vs P";
        var diffStr = (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
        var sideStr = _playerFirst ? "Side: Blk" : "Side: Wht";
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, sideStr, "START"];
        var nR   = 4;
        var rowH = _sh * 10 / 100;
        if (rowH < 22) { rowH = 22; }
        if (rowH > 30) { rowH = 30; }
        var rowW = _sw * 74 / 100;
        var rowX = (_sw - rowW) / 2;
        var gap  = 6;
        var tot  = nR * rowH + (nR - 1) * gap;
        var rowY0 = (_sh - tot) / 2 + rowH;
        var i = 0;
        while (i < nR) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == _menuSel);
            var isStart = (i == nR - 1);
            dc.setColor(sel ? (isStart ? 0x3A1800 : 0x0A2030) : 0x0A0A18,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xC8A040 : 0x4488CC) : 0x1A2030,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                dc.setColor(isStart ? 0xC8A040 : 0x4488CC, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }
            var dimmed = (i == 1 && _mode == MODE_PVP) || (i == 2 && _mode != MODE_PVAI);
            dc.setColor(dimmed ? 0x445566
                        : (sel ? (isStart ? 0xFFCC88 : 0xAADDFF) : 0x556677),
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2,
                        Graphics.FONT_XTINY, rows[i], Graphics.TEXT_JUSTIFY_CENTER);
            i = i + 1;
        }
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh - 14, Graphics.FONT_XTINY,
                    "UP/DN sel  SELECT set/start", Graphics.TEXT_JUSTIFY_CENTER);
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

        // Star points (hoshi) at cols/rows 2, 4, 6
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
            dc.setColor(0x404040, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - _sr / 3, py - _sr / 3, _sr / 4);
        } else {
            dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, _sr);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(px, py, _sr);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - _sr / 3, py - _sr / 3, _sr / 5);
        }
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
        var col = (_illegalFlash > 0) ? 0xFF3300 : 0x00FF44;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(px - hs, py - hs, hs * 2, hs * 2);
        dc.drawRectangle(px - hs + 1, py - hs + 1, hs * 2 - 2, hs * 2 - 2);
    }

    // ── HUD ───────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var hudY = _bgY - _cell * 2 / 3;
        if (hudY < 5) { hudY = 5; }

        if (_ctrl.gameOver == 0) {
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, hudY, Graphics.FONT_XTINY,
                "YOUR TURN (BLACK)", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var capY = hudY + 14;
        if (capY > _bgY - 4) { capY = _bgY - 4; }
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw * 22 / 100, capY, Graphics.FONT_XTINY,
            "B cap " + _ctrl.board.capWhite.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_sw * 78 / 100, capY, Graphics.FONT_XTINY,
            "W cap " + _ctrl.board.capBlack.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);

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
        dc.setColor(0xC8A040, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 5, Graphics.FONT_XTINY, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 22, Graphics.FONT_XTINY,
            "Black: " + bs.format("%d") + "  White: " + ws.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);

        var wMsg = "";
        if (bs > ws) { wMsg = "BLACK WINS!"; dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT); }
        else if (ws > bs) { wMsg = "WHITE WINS!"; dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT); }
        else { wMsg = "DRAW!"; dc.setColor(0xAAAA44, Graphics.COLOR_TRANSPARENT); }
        dc.drawText(cx, by + 42, Graphics.FONT_SMALL, wMsg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x444433, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 64, Graphics.FONT_XTINY,
            "(White +7 komi)", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x333322, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 13, Graphics.FONT_XTINY,
            "SELECT = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
