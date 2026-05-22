using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

const MIN_TEXT_PX = 14;

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _timer;

    hidden var _sw;
    hidden var _sh;
    hidden var _cellPx;
    hidden var _bx;
    hidden var _by;

    function initialize() {
        View.initialize();
        _ctrl = new GameController();
        _timer = null;
        _sw = 0; _sh = 0; _cellPx = 0; _bx = 0; _by = 0;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 100, true);   // 100 ms for smooth BFS animation
    }
    function onHide() { if (_timer != null) { _timer.stop(); } }
    function onTick() {
        _ctrl.tick();
        _ctrl.floodTick();   // continue BFS one chunk per tick
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();
        dc.setColor(0x9098A0, 0x9098A0); dc.clear();

        if (_ctrl.state == GS_MENU) { _drawMenu(dc); return; }

        _layoutBoard();
        _drawHUD(dc);
        _drawBoard(dc);
        _drawFooter(dc);
        if (_ctrl.state == GS_WIN)  { _drawResult(dc, true);  }
        if (_ctrl.state == GS_LOSE) { _drawResult(dc, false); }
    }

    // ── Board layout — always fit the whole board on screen ───────
    hidden function _layoutBoard() {
        var n      = _ctrl.grid.n;
        var topPad = (_sh * 13) / 100; if (topPad < 22) { topPad = 22; }
        var botPad = (_sh * 10) / 100; if (botPad < 16) { botPad = 16; }
        var inset  = (_sw == _sh) ? ((_sw * 5) / 100) : 4;
        var maxH   = _sh - topPad - botPad;
        var maxW   = _sw - inset * 2;
        var area   = ((maxW < maxH) ? maxW : maxH) * 9 / 10;
        var cell   = area / n;
        if (cell < 4) { cell = 4; }    // absolute floor — keeps board visible
        _cellPx = cell;
        var bp  = n * _cellPx;
        _bx = (_sw - bp) / 2;
        _by = topPad + (maxH - bp) / 2;
    }

    // ── Board ─────────────────────────────────────────────────────
    hidden function _drawBoard(dc) {
        var g     = _ctrl.grid;
        var n     = g.n;
        var ended = (_ctrl.state == GS_LOSE || _ctrl.state == GS_WIN);
        var txt   = (_cellPx >= MIN_TEXT_PX);
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                var x = _bx + c * _cellPx;
                var y = _by + r * _cellPx;
                var i = g.idx(r, c);
                Tile.draw(dc, x, y, _cellPx,
                          g.state[i], g.numbers[i], g.mines[i] == 1,
                          (r == _ctrl.curR && c == _ctrl.curC), ended, txt);
            }
        }
        dc.setColor(0x303040, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_bx - 1, _by - 1, n * _cellPx + 2, n * _cellPx + 2);
    }

    // ── HUD ───────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var cx = _sw / 2;
        var ty = (_sh * 3) / 100; if (ty < 3) { ty = 3; }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, ty, Graphics.FONT_XTINY,
                    "F " + _ctrl.minesLeft().format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ty, Graphics.FONT_XTINY,
                    _ctrl.fmtTime(_ctrl.elapsedMs) + "s",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Footer ────────────────────────────────────────────────────
    hidden function _drawFooter(dc) {
        var hint;
        if (_ctrl.state == GS_PLAY) {
            hint = "btn=cursor  SEL=open  hold=flag  tap=open";
        } else {
            hint = "tap = menu";
        }
        dc.setColor(0xBBBBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Menu ──────────────────────────────────────────────────────
    hidden function _menuRowGeom() {
        var rowH  = (_sh * 11) / 100;
        if (rowH < 22) { rowH = 22; } if (rowH > 28) { rowH = 28; }
        var rowW  = (_sw * 76) / 100; if (rowW < 140) { rowW = 140; }
        var rowX  = (_sw - rowW) / 2;
        var gap   = (_sh * 2) / 100; if (gap < 4) { gap = 4; }
        var total = MENU_ROW_COUNT * rowH + (MENU_ROW_COUNT - 1) * gap;
        var rowY0 = (_sh - total) / 2 + (_sh * 6) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    hidden function _drawMenu(dc) {
        var cx = _sw / 2;
        dc.setColor(0x080808, 0x080808); dc.clear();
        if (_sw == _sh) {
            dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _sh / 2, _sw / 2 - 1);
        }
        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 5 / 100, Graphics.FONT_SMALL,
                    "MINE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 16 / 100, Graphics.FONT_SMALL,
                    "SWEEPER", Graphics.TEXT_JUSTIFY_CENTER);

        var rg = _menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = [
            "Size: "  + _ctrl.currentName(),
            "Bombs: " + _ctrl.currentDensityName()
                      + " (" + _ctrl.currentMineCount().format("%d") + ")",
            "START"
        ];
        for (var i = 0; i < MENU_ROW_COUNT; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == _ctrl.menuRow);
            var isStart = (i == MENU_START);
            dc.setColor(sel ? (isStart ? 0x1A4400 : 0x1A3A6A) : 0x111820,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x44BB22 : 0x55AAFF) : 0x2A3A4A,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xAAFF66 : 0xCCEEFF) : 0x778899,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        var best = _ctrl.bestForCurrent();
        if (best > 0) {
            var by2 = rowY0 + MENU_ROW_COUNT * (rowH + gap) + 2;
            if (by2 < _sh - 36) {
                dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, by2, Graphics.FONT_XTINY,
                            "BEST " + _ctrl.fmtTime(best) + "s",
                            Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh - 28, Graphics.FONT_XTINY,
                    "UP/DN row  tap row = act", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh - 14, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Win / Lose overlay ────────────────────────────────────────
    hidden function _drawResult(dc, won) {
        var bw = _sw * 70 / 100; if (bw < 160) { bw = 160; }
        var bh = _sh * 36 / 100; if (bh < 110) { bh = 110; }
        var bx = (_sw - bw) / 2;
        var by = (_sh - bh) / 2;
        var cx = _sw / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(won ? 0x44FF88 : 0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    won ? "CLEARED!" : "BOOM!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 30, Graphics.FONT_XTINY,
                    "Size " + _ctrl.currentName(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 46, Graphics.FONT_XTINY,
                    "Time " + _ctrl.fmtTime(_ctrl.elapsedMs) + "s",
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (won && _ctrl.isNewBest()) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 64, Graphics.FONT_XTINY,
                        "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Input intents (called by InputHandler) ────────────────────

    // Bottom button / onNextPage → step cursor right (col++ wrap)
    function navHoriz() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuNext(); return; }
        if (_ctrl.state == GS_WIN || _ctrl.state == GS_LOSE) {
            _ctrl.gotoMenu(); return;
        }
        _ctrl.moveCursorHoriz();
    }

    // Upper button / onPreviousPage → step cursor down (row++ wrap)
    function navVert() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuPrev(); return; }
        if (_ctrl.state == GS_WIN || _ctrl.state == GS_LOSE) {
            _ctrl.gotoMenu(); return;
        }
        _ctrl.moveCursorVert();
    }

    // SELECT only → reveal cursor cell (or activate menu row)
    function navReveal() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuActivate(); return; }
        if (_ctrl.state == GS_WIN || _ctrl.state == GS_LOSE) {
            _ctrl.gotoMenu(); return;
        }
        _ctrl.revealCursor();
    }

    // Long press only → flag cursor cell
    function navFlag() { _ctrl.flagCursor(); }

    function navBack() {
        if (_ctrl.state == GS_PLAY || _ctrl.state == GS_WIN
                || _ctrl.state == GS_LOSE) {
            _ctrl.gotoMenu(); return true;
        }
        return false;
    }

    // Tap → in menu: activate tapped row; in play: reveal tapped cell.
    function handleTap(x, y) {
        if (_ctrl.state == GS_MENU) {
            var rg   = _menuRowGeom();
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < MENU_ROW_COUNT; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    _ctrl.setMenuRow(i); _ctrl.menuActivate(); return;
                }
            }
            return;
        }
        if (_ctrl.state == GS_WIN || _ctrl.state == GS_LOSE) {
            _ctrl.gotoMenu(); return;
        }
        if (_cellPx <= 0 || x < _bx || y < _by) { return; }
        var n  = _ctrl.grid.n;
        var dc = (x - _bx) / _cellPx;
        var dr = (y - _by) / _cellPx;
        if (dc < 0 || dc >= n || dr < 0 || dr >= n) { return; }
        if (!_ctrl.grid.inBounds(dr, dc)) { return; }
        _ctrl.revealAt(dr, dc);
    }
}
