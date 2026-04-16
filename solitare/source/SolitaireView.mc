using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.System;

const SOL_MENU    = 0;
const SOL_PLAY    = 1;
const SOL_WINANIM = 2;
const SOL_WON     = 3;

class SolitaireView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick; hidden var _gs;

    hidden var _rkS;

    // Layout
    hidden var _cw; hidden var _ch; hidden var _gap;
    hidden var _topY; hidden var _tabY;
    hidden var _colX;

    // Stock & Waste
    hidden var _stk; hidden var _stkN;
    hidden var _wst; hidden var _wstN;

    // Foundations
    hidden var _fnd;

    // Tableau
    hidden var _tab; hidden var _tN; hidden var _tU;

    // Cursor / Selection
    hidden var _cur;
    hidden var _sel; hidden var _sIdx;
    hidden var _sCards; hidden var _sN;

    hidden var _moves;

    // Double-tap (touch + button)
    hidden var _lastTapP; hidden var _lastTapT;
    hidden var _lastSelT;

    // Auto-foundation queue (one card per tick for visible delay)
    hidden var _autoFndQ;

    // Win animation
    hidden var _winTick;
    hidden var _winParts;

    // Draw mode: 1 or 3
    hidden var _drawCount;
    hidden var _menuSel;

    function initialize() {
        View.initialize();
        _tick = 0; _gs = SOL_MENU;
        _w = 240; _h = 240; _moves = 0;
        _drawCount = 1; _menuSel = 0;
        _rkS = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"];
        _stk = new [24]; _stkN = 0;
        _wst = new [24]; _wstN = 0;
        _fnd = new [4];
        _tab = new [140]; _tN = new [7]; _tU = new [7];
        _colX = new [7];
        _sCards = new [20]; _sN = 0;
        _sel = -1; _cur = 0; _sIdx = 0;
        _lastTapP = -1; _lastTapT = 0; _lastSelT = 0;
        _autoFndQ = false;
        _winTick = 0;
        _winParts = null;
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 150, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        _layOut();
    }

    hidden function _layOut() {
        var usableW = _w * 75 / 100;
        _gap = usableW * 1 / 100; if (_gap < 2) { _gap = 2; }
        _cw = (usableW - 6 * _gap) / 7;
        if (_cw < 12) { _cw = 12; }
        _ch = _cw * 13 / 10;
        var tw = 7 * _cw + 6 * _gap;
        var sx = (_w - tw) / 2;
        for (var i = 0; i < 7; i++) {
            _colX[i] = sx + i * (_cw + _gap);
        }
        _topY = _h * 21 / 100;
        _tabY = _topY + _ch + _gap;
    }

    function onTick() as Void {
        _tick++;

        if (_gs == SOL_PLAY && _autoFndQ) {
            _doOneAutoFnd();
        }

        if (_gs == SOL_WINANIM) {
            _winTick++;
            _updateWinParts();
            if (_winTick > 30) { _gs = SOL_WON; }
        }

        WatchUi.requestUpdate();
    }

    // ─── Input ────────────────────────────────────────────────────────────────────

    function doUp() {
        if (_gs == SOL_MENU) { _menuSel = (_menuSel + 1) % 2; return; }
        if (_gs != SOL_PLAY || _autoFndQ) { return; }
        _cur = (_cur + 12) % 13;
    }

    function doDown() {
        if (_gs == SOL_MENU) { _menuSel = (_menuSel + 1) % 2; return; }
        if (_gs != SOL_PLAY || _autoFndQ) { return; }
        _cur = (_cur + 1) % 13;
    }

    function doSelect() {
        if (_gs == SOL_MENU) { _drawCount = (_menuSel == 0) ? 1 : 3; _deal(); return; }
        if (_gs == SOL_WON) { _gs = SOL_MENU; return; }
        if (_gs != SOL_PLAY || _autoFndQ) { return; }
        var now = System.getTimer();
        if ((now - _lastSelT) < 500 && (now - _lastSelT) > 0) {
            _lastSelT = 0;
            if (_sel >= 0) {
                var saveSel = _sel;
                _cancel();
                _autoMove(saveSel);
            } else {
                _autoMove(_cur);
            }
            return;
        }
        _lastSelT = now;
        _interact(_cur);
    }

    function doTap(tx, ty) {
        if (_gs == SOL_MENU) {
            var y1 = _h * 52 / 100;
            var y3 = _h * 64 / 100;
            var rowH = _h * 10 / 100;
            if (ty >= y1 && ty < y1 + rowH) { _menuSel = 0; }
            else if (ty >= y3 && ty < y3 + rowH) { _menuSel = 1; }
            else {
                _drawCount = (_menuSel == 0) ? 1 : 3;
                _deal();
            }
            return;
        }
        if (_gs == SOL_WON) { _gs = SOL_MENU; return; }
        if (_gs != SOL_PLAY || _autoFndQ) { return; }
        var p = _hitTest(tx, ty);
        if (p < 0) { return; }
        var now = System.getTimer();
        if (p == _lastTapP && (now - _lastTapT) < 500 && (now - _lastTapT) > 0) {
            _lastTapP = -1; _lastTapT = 0;
            _cur = p;
            if (_sel >= 0) {
                var saveSel = _sel;
                _cancel();
                _autoMove(saveSel);
            } else {
                _autoMove(p);
            }
            return;
        }
        _lastTapP = p; _lastTapT = now;
        _cur = p; _interact(p);
    }

    function doBack() {
        if (_gs == SOL_PLAY) {
            if (_autoFndQ) { return true; }
            if (_sel >= 0) { _cancel(); return true; }
            _gs = SOL_MENU; return true;
        }
        if (_gs == SOL_WON || _gs == SOL_WINANIM) { _gs = SOL_MENU; return true; }
        return false;
    }

    // ─── Hit Test ─────────────────────────────────────────────────────────────────

    hidden function _hitTest(tx, ty) {
        if (ty >= _topY && ty < _tabY) {
            if (tx >= _colX[0] && tx < _colX[0] + _cw) { return 0; }
            var wstW = _cw;
            if (_drawCount == 3 && _wstN >= 2) {
                var fan = _wstN >= 3 ? 3 : _wstN;
                var off = _cw * 38 / 100; if (off < 5) { off = 5; }
                wstW = (fan - 1) * off + _cw;
            }
            if (tx >= _colX[1] && tx < _colX[1] + wstW) { return 1; }
            for (var i = 0; i < 4; i++) {
                if (tx >= _colX[i + 3] && tx < _colX[i + 3] + _cw) { return i + 2; }
            }
        }
        if (ty >= _tabY) {
            for (var i = 0; i < 7; i++) {
                if (tx >= _colX[i] && tx < _colX[i] + _cw) { return i + 6; }
            }
        }
        return -1;
    }

    // ─── Interaction ──────────────────────────────────────────────────────────────

    hidden function _interact(p) {
        if (p == 0) {
            _cancel();
            _flipStock();
            return;
        }
        if (_sel < 0) {
            if (_tryFnd(p)) { return; }
            _pickUp(p);
        } else if (_sel == p) {
            _cancel();
        } else {
            _placeAt(p);
        }
    }

    hidden function _tryFnd(p) {
        var card = -1;
        if (p == 1 && _wstN > 0) {
            card = _wst[_wstN - 1];
        } else if (p >= 6) {
            var c = p - 6;
            if (_tN[c] > 0 && _tU[c] < _tN[c]) {
                card = _tab[c * 20 + _tN[c] - 1];
            }
        }
        if (card < 0) { return false; }
        var rank = card / 4;
        var suit = card % 4;
        if (rank != _fnd[suit]) { return false; }
        _fnd[suit]++;
        if (p == 1) { _wstN--; }
        else { _tN[p - 6]--; }
        _moves++;
        _autoFlip();
        _autoFndQ = true;
        return true;
    }

    hidden function _pickUp(p) {
        if (p == 1) {
            if (_wstN <= 0) { return; }
            _sel = 1; _sN = 1;
            _sCards[0] = _wst[_wstN - 1];
            _sIdx = _wstN - 1;
            return;
        }
        if (p >= 2 && p <= 5) {
            var s = p - 2;
            if (_fnd[s] <= 0) { return; }
            _sel = p; _sN = 1;
            _sCards[0] = (_fnd[s] - 1) * 4 + s;
            _sIdx = 0;
            return;
        }
        if (p >= 6) {
            var c = p - 6;
            var n = _tN[c];
            if (n <= 0) { return; }
            var u = _tU[c];
            _sel = p; _sIdx = u;
            _sN = n - u;
            for (var i = 0; i < _sN; i++) {
                _sCards[i] = _tab[c * 20 + u + i];
            }
        }
    }

    hidden function _placeAt(p) {
        if (_sN <= 0) { _cancel(); return; }
        var card = _sCards[0];
        var rank = card / 4;
        var suit = card % 4;

        if (p >= 2 && p <= 5) {
            if (_sN != 1) { return; }
            var fs = p - 2;
            if (suit != fs) { return; }
            if (rank != _fnd[fs]) { return; }
            _fnd[fs]++;
            _removeSrc();
            _moves++;
            _cancel();
            _autoFlip();
            _autoFndQ = true;
            return;
        }

        if (p >= 6) {
            var c = p - 6;
            var n = _tN[c];
            if (n == 0) {
                if (rank != 12) { return; }
            } else {
                var top = _tab[c * 20 + n - 1];
                var tR = top / 4;
                var tS = top % 4;
                var tRed = (tS == 1 || tS == 2);
                var sRed = (suit == 1 || suit == 2);
                if (tRed == sRed) { return; }
                if (rank != tR - 1) { return; }
            }
            for (var i = 0; i < _sN; i++) {
                _tab[c * 20 + n + i] = _sCards[i];
            }
            _tN[c] = n + _sN;
            _removeSrc();
            _moves++;
            _cancel();
            _autoFlip();
            _autoFndQ = true;
            return;
        }
    }

    hidden function _removeSrc() {
        if (_sel == 1) { _wstN--; }
        else if (_sel >= 2 && _sel <= 5) { _fnd[_sel - 2]--; }
        else if (_sel >= 6) { _tN[_sel - 6] = _sIdx; }
    }

    hidden function _cancel() { _sel = -1; _sN = 0; }

    hidden function _autoMove(p) {
        if (p == 0) { _flipStock(); return; }

        var card = -1;
        var fromW = false;
        var fromF = -1;
        var fromC = -1;
        var seqStart = 0;
        var seqLen   = 0;

        if (p == 1 && _wstN > 0) {
            card = _wst[_wstN - 1]; fromW = true; seqLen = 1;
        } else if (p >= 2 && p <= 5) {
            var s = p - 2;
            if (_fnd[s] <= 0) { return; }
            card = (_fnd[s] - 1) * 4 + s; fromF = s; seqLen = 1;
        } else if (p >= 6) {
            fromC = p - 6;
            if (_tN[fromC] <= 0 || _tU[fromC] >= _tN[fromC]) { return; }
            card = _tab[fromC * 20 + _tN[fromC] - 1];
            seqStart = _tU[fromC];
            seqLen = _tN[fromC] - seqStart;
        } else {
            return;
        }

        // Priority 1: move top card to foundation
        if (fromF < 0) {
            var topCard = -1;
            if (fromW) { topCard = card; }
            else if (fromC >= 0) { topCard = _tab[fromC * 20 + _tN[fromC] - 1]; }
            if (topCard >= 0) {
                var tRk = topCard / 4;
                var tSt = topCard % 4;
                if (tRk == _fnd[tSt]) {
                    _fnd[tSt]++;
                    if (fromW) { _wstN--; }
                    else { _tN[fromC]--; }
                    _moves++; _autoFlip(); _autoFndQ = true;
                    return;
                }
            }
        }

        // Priority 2: best tableau move (score each valid destination)
        var firstCard = -1;
        if (fromW || fromF >= 0) { firstCard = card; }
        else { firstCard = _tab[fromC * 20 + seqStart]; }
        var fRk = firstCard / 4;
        var fSt = firstCard % 4;
        var fRed = (fSt == 1 || fSt == 2);

        var bestCol = -1;
        var bestScore = -999;
        for (var c = 0; c < 7; c++) {
            if (c == fromC) { continue; }
            var n = _tN[c];
            var ok = false;
            if (n == 0) {
                if (fRk == 12) { ok = true; }
            } else {
                var dst = _tab[c * 20 + n - 1];
                var dR = dst / 4; var dS = dst % 4;
                var dRed = (dS == 1 || dS == 2);
                if (dRed != fRed && fRk == dR - 1) { ok = true; }
            }
            if (!ok) { continue; }
            var sc = 0;
            // Prefer placing on non-empty columns (King on empty = low priority)
            if (n > 0) { sc += 20; }
            // Prefer moves that reveal face-down cards
            if (fromC >= 0 && _tU[fromC] > 0 && seqStart == _tU[fromC]) { sc += 30; }
            // Prefer columns with more face-down cards (build on longer columns)
            sc += _tU[c];
            // Avoid moving King from tableau to empty if it won't reveal a card
            if (n == 0 && fromC >= 0 && _tU[fromC] == 0) { sc -= 50; }
            if (sc > bestScore) { bestScore = sc; bestCol = c; }
        }
        if (bestCol >= 0) {
            var n = _tN[bestCol];
            if (fromW) {
                _tab[bestCol * 20 + n] = card;
                _tN[bestCol] = n + 1;
                _wstN--;
            } else if (fromF >= 0) {
                _tab[bestCol * 20 + n] = card;
                _tN[bestCol] = n + 1;
                _fnd[fromF]--;
            } else {
                for (var i = 0; i < seqLen; i++) {
                    _tab[bestCol * 20 + n + i] = _tab[fromC * 20 + seqStart + i];
                }
                _tN[bestCol] = n + seqLen;
                _tN[fromC] = seqStart;
            }
            _moves++; _autoFlip(); _autoFndQ = true;
            return;
        }
    }

    // ─── Game Logic ───────────────────────────────────────────────────────────────

    hidden function _deal() {
        var dk = new [52];
        for (var i = 0; i < 52; i++) { dk[i] = i; }
        for (var i = 51; i > 0; i--) {
            var j = (Math.rand() % (i + 1)).toNumber();
            if (j < 0) { j = -j; }
            var t = dk[i]; dk[i] = dk[j]; dk[j] = t;
        }
        var idx = 0;
        for (var c = 0; c < 7; c++) {
            _tN[c] = c + 1;
            _tU[c] = c;
            for (var r = 0; r <= c; r++) {
                _tab[c * 20 + r] = dk[idx]; idx++;
            }
        }
        _stkN = 52 - idx;
        for (var i = 0; i < _stkN; i++) { _stk[i] = dk[idx]; idx++; }
        _wstN = 0;
        for (var i = 0; i < 4; i++) { _fnd[i] = 0; }
        _sel = -1; _sN = 0; _cur = 0; _moves = 0;
        _autoFndQ = false; _winTick = 0; _winParts = null;
        _gs = SOL_PLAY;
        _autoFndQ = true;
    }

    hidden function _flipStock() {
        if (_stkN > 0) {
            var cnt = _drawCount;
            if (cnt > _stkN) { cnt = _stkN; }
            for (var i = 0; i < cnt; i++) {
                _stkN--;
                _wst[_wstN] = _stk[_stkN];
                _wstN++;
            }
        } else if (_wstN > 0) {
            for (var i = 0; i < _wstN; i++) {
                _stk[i] = _wst[_wstN - 1 - i];
            }
            _stkN = _wstN; _wstN = 0;
        }
        _moves++;
        _autoFndQ = true;
    }

    hidden function _autoFlip() {
        for (var c = 0; c < 7; c++) {
            if (_tN[c] > 0 && _tU[c] >= _tN[c]) {
                _tU[c] = _tN[c] - 1;
            }
        }
    }

    hidden function _doOneAutoFnd() {
        if (_wstN > 0 && _canAutoFnd(_wst[_wstN - 1])) {
            _fnd[_wst[_wstN - 1] % 4]++;
            _wstN--;
            _autoFlip();
            _checkWin();
            return;
        }
        for (var c = 0; c < 7; c++) {
            if (_tN[c] > 0 && _tU[c] < _tN[c]) {
                var cd = _tab[c * 20 + _tN[c] - 1];
                if (_canAutoFnd(cd)) {
                    _fnd[cd % 4]++;
                    _tN[c]--;
                    _autoFlip();
                    _checkWin();
                    return;
                }
            }
        }
        _autoFndQ = false;
        _checkWin();
    }

    hidden function _canAutoFnd(card) {
        var rank = card / 4;
        var suit = card % 4;
        if (rank != _fnd[suit]) { return false; }
        if (rank <= 1) { return true; }
        var isRed = (suit == 1 || suit == 2);
        if (isRed) {
            return (_fnd[0] >= rank - 1 && _fnd[3] >= rank - 1);
        }
        return (_fnd[1] >= rank - 1 && _fnd[2] >= rank - 1);
    }

    hidden function _checkWin() {
        if (_fnd[0] == 13 && _fnd[1] == 13 && _fnd[2] == 13 && _fnd[3] == 13) {
            _autoFndQ = false;
            _gs = SOL_WINANIM;
            _winTick = 0;
            _initWinParts();
        }
    }

    // ─── Win Animation ────────────────────────────────────────────────────────────

    hidden function _initWinParts() {
        _winParts = new [24];
        for (var i = 0; i < 24; i++) {
            _winParts[i] = new [5];
            _winParts[i][0] = (Math.rand() % _w).toNumber().abs();
            _winParts[i][1] = -((Math.rand() % (_h / 2)).toNumber().abs()) - 10;
            _winParts[i][2] = ((Math.rand() % 5).toNumber().abs()) + 2;
            _winParts[i][3] = (Math.rand() % 4).toNumber().abs();
            _winParts[i][4] = ((Math.rand() % 3).toNumber().abs()) + 1;
        }
    }

    hidden function _updateWinParts() {
        if (_winParts == null) { return; }
        for (var i = 0; i < 24; i++) {
            _winParts[i][1] = _winParts[i][1] + _winParts[i][2];
            if (_winParts[i][1] > _h + 20) {
                _winParts[i][0] = (Math.rand() % _w).toNumber().abs();
                _winParts[i][1] = -20;
            }
        }
    }

    // ─── Overlap Calculation Helper ───────────────────────────────────────────────

    hidden var _oFd; hidden var _oFu;

    hidden function _calcOvl(c) {
        var safeBot = _h * 88 / 100;
        var availH = safeBot - _tabY;
        var n = _tN[c]; var u = _tU[c];
        _oFd = _ch * 15 / 100; if (_oFd < 3) { _oFd = 3; }
        _oFu = _ch * 42 / 100; if (_oFu < 12) { _oFu = 12; }
        var nFd = u;
        var nFu = (n - u > 1) ? n - u - 1 : 0;
        var budget = availH - _ch;
        var need = nFd * _oFd + nFu * _oFu;
        if (need > budget && (nFd + nFu) > 0) {
            var wt = nFd + nFu * 3;
            if (wt > 0) {
                var un = budget / wt;
                _oFd = un; if (_oFd < 2) { _oFd = 2; }
                _oFu = un * 3; if (_oFu < 6) { _oFu = 6; }
            }
        }
    }

    // ─── Rendering ────────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        if (_w != dc.getWidth() || _h != dc.getHeight()) {
            _w = dc.getWidth(); _h = dc.getHeight(); _layOut();
        }
        dc.setColor(0x0A2818, 0x0A2818);
        dc.clear();
        if (_gs == SOL_MENU)    { _drMenu(dc); return; }
        if (_gs == SOL_WINANIM) { _drTop(dc); _drTab(dc); _drWinAnim(dc); return; }
        if (_gs == SOL_WON)     { _drWin(dc); return; }
        _drTop(dc);
        _drTab(dc);
        _drSel(dc);
        _drCur(dc);
    }

    hidden function _drMenu(dc) {
        dc.setColor(0x33AA55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 14 / 100, Graphics.FONT_LARGE,
            "SOLITAIRE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x77CC99, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 32 / 100, Graphics.FONT_SMALL,
            "Klondike", Graphics.TEXT_JUSTIFY_CENTER);

        var sy = _h * 44 / 100;
        var ss = _w * 3 / 100; if (ss < 5) { ss = 5; }
        var sp = ss * 3;
        dc.setColor(0x335544, Graphics.COLOR_TRANSPARENT);
        _drSuit(dc, _w / 2 - sp - sp / 2, sy, 0, ss);
        dc.setColor(0x553344, Graphics.COLOR_TRANSPARENT);
        _drSuit(dc, _w / 2 - sp / 2, sy, 1, ss);
        _drSuit(dc, _w / 2 + sp / 2, sy, 2, ss);
        dc.setColor(0x335544, Graphics.COLOR_TRANSPARENT);
        _drSuit(dc, _w / 2 + sp + sp / 2, sy, 3, ss);

        var y1 = _h * 53 / 100;
        var y3 = _h * 64 / 100;
        dc.setColor((_menuSel == 0) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y1, Graphics.FONT_SMALL,
            "1 DRAW", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_menuSel == 1) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y3, Graphics.FONT_SMALL,
            "3 DRAW", Graphics.TEXT_JUSTIFY_CENTER);

        var pc = (_tick % 20 < 10) ? 0xFFCC44 : 0xAA8822;
        dc.setColor(pc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 79 / 100, Graphics.FONT_XTINY,
            "SELECT TO DEAL", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drWinAnim(dc) {
        if (_winParts == null) { return; }
        for (var i = 0; i < 24; i++) {
            var px = _winParts[i][0];
            var py = _winParts[i][1];
            var s  = _winParts[i][4];
            var suit = _winParts[i][3];
            var sc = (suit == 1 || suit == 2) ? 0xCC1111 : 0x22CC44;
            var alpha = 255 - _winTick * 4;
            if (alpha < 80) { alpha = 80; }
            dc.setColor(sc, Graphics.COLOR_TRANSPARENT);
            var sz = _cw * 4 / 10 * s / 2; if (sz < 4) { sz = 4; }
            _drSuit(dc, px, py, suit, sz);
        }

        var flash = (_winTick % 6 < 3) ? 0x44FF88 : 0x22CC66;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 42 / 100, Graphics.FONT_LARGE,
            "YOU WIN!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drWin(dc) {
        var gc = (_tick % 20 < 10) ? 0x44FF88 : 0x22CC66;
        dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 22 / 100, Graphics.FONT_LARGE,
            "YOU WIN!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_SMALL,
            "Moves: " + _moves, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x446644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 66 / 100, Graphics.FONT_XTINY,
            "Tap to play again", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drTop(dc) {
        if (_stkN > 0) {
            _drBack(dc, _colX[0], _topY);
        } else {
            _drEmpty(dc, _colX[0], _topY);
            if (_wstN > 0) {
                dc.setColor(0x337733, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(_colX[0] + _cw / 2, _topY + _ch / 2, _cw / 4);
            }
        }

        if (_wstN > 0) {
            if (_drawCount == 3 && _wstN >= 2) {
                var fan = _wstN >= 3 ? 3 : _wstN;
                var off = _cw * 38 / 100; if (off < 5) { off = 5; }
                for (var fi = 0; fi < fan; fi++) {
                    _drCard(dc, _colX[1] + fi * off, _topY, _wst[_wstN - fan + fi]);
                }
            } else {
                _drCard(dc, _colX[1], _topY, _wst[_wstN - 1]);
            }
        } else {
            _drEmpty(dc, _colX[1], _topY);
        }

        for (var i = 0; i < 4; i++) {
            var fx = _colX[i + 3];
            if (_fnd[i] > 0) {
                _drCard(dc, fx, _topY, (_fnd[i] - 1) * 4 + i);
            } else {
                _drFndE(dc, fx, _topY, i);
            }
        }
    }

    hidden function _drTab(dc) {
        for (var c = 0; c < 7; c++) {
            var x = _colX[c];
            var n = _tN[c];
            var u = _tU[c];
            if (n == 0) { _drEmpty(dc, x, _tabY); continue; }

            _calcOvl(c);
            var fdH = _oFd; var fuH = _oFu;

            var cy = _tabY;
            for (var i = 0; i < n; i++) {
                if (i < u) {
                    _drBack(dc, x, cy);
                    cy += fdH;
                } else {
                    var isSel = (_sel == c + 6 && i >= _sIdx && _sN > 0);
                    _drCard(dc, x, cy, _tab[c * 20 + i]);
                    if (isSel) {
                        dc.setColor(0x00FF44, Graphics.COLOR_TRANSPARENT);
                        dc.drawRectangle(x, cy, _cw, _ch);
                    }
                    if (i < n - 1) { cy += fuH; }
                }
            }
        }
    }

    hidden function _wstTopX() {
        if (_drawCount == 3 && _wstN >= 2) {
            var fan = _wstN >= 3 ? 3 : _wstN;
            var off = _cw * 38 / 100; if (off < 5) { off = 5; }
            return _colX[1] + (fan - 1) * off;
        }
        return _colX[1];
    }

    hidden function _drSel(dc) {
        if (_sel < 0) { return; }
        dc.setColor(0x00FF44, Graphics.COLOR_TRANSPARENT);
        if (_sel <= 5) {
            var sx; var sy;
            if (_sel == 0) { sx = _colX[0]; sy = _topY; }
            else if (_sel == 1) { sx = _wstTopX(); sy = _topY; }
            else { sx = _colX[_sel + 1]; sy = _topY; }
            dc.drawRoundedRectangle(sx - 2, sy - 2, _cw + 4, _ch + 4, 4);
        } else {
            var col = _sel - 6;
            var x = _colX[col];
            _calcOvl(col);
            var nFd = _tU[col];
            var selTopY = _tabY + nFd * _oFd + (_sIdx - _tU[col]) * _oFu;
            var selBotY = selTopY + (_sN - 1) * _oFu + _ch;
            dc.drawRoundedRectangle(x - 2, selTopY - 2, _cw + 4, selBotY - selTopY + 4, 4);
        }
    }

    hidden function _drCur(dc) {
        if (_cur <= 5) {
            var cx; var cy;
            if (_cur == 0) { cx = _colX[0]; cy = _topY; }
            else if (_cur == 1) { cx = _wstTopX(); cy = _topY; }
            else { cx = _colX[_cur + 1]; cy = _topY; }
            var hc = (_sel >= 0) ? 0xFFAA00 : 0x00CCFF;
            if (_sel == _cur) { hc = 0x00FF66; }
            dc.setColor(hc, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(cx - 2, cy - 2, _cw + 4, _ch + 4, 3);
            dc.drawRoundedRectangle(cx - 1, cy - 1, _cw + 2, _ch + 2, 3);
        } else {
            var col = _cur - 6;
            var x = _colX[col];
            var n = _tN[col]; var u = _tU[col];
            var hc = (_sel >= 0) ? 0xFFAA00 : 0x00CCFF;
            if (_sel == _cur) { hc = 0x00FF66; }
            dc.setColor(hc, Graphics.COLOR_TRANSPARENT);
            if (n <= 0) {
                dc.drawRoundedRectangle(x - 2, _tabY - 2, _cw + 4, _ch + 4, 3);
                dc.drawRoundedRectangle(x - 1, _tabY - 1, _cw + 2, _ch + 2, 3);
            } else {
                _calcOvl(col);
                var nFd = u;
                var nFu = (n - u > 1) ? n - u - 1 : 0;
                var stkH = nFd * _oFd + nFu * _oFu + _ch;
                dc.drawRoundedRectangle(x - 2, _tabY - 2, _cw + 4, stkH + 4, 3);
                dc.drawRoundedRectangle(x - 1, _tabY - 1, _cw + 2, stkH + 2, 3);
            }
        }
    }

    // ─── Card Drawing ─────────────────────────────────────────────────────────────

    hidden function _drCard(dc, x, y, card) {
        var rank = card / 4;
        var suit = card % 4;
        var isRed = (suit == 1 || suit == 2);
        var tc = isRed ? 0xCC1111 : 0x111111;

        dc.setColor(0xFCFAF6, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, _cw, _ch, 2);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, _cw, _ch, 2);

        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 2, y + 1, Graphics.FONT_XTINY,
            _rkS[rank], Graphics.TEXT_JUSTIFY_LEFT);

        var miniS = _cw * 15 / 100; if (miniS < 3) { miniS = 3; }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        _drSuit(dc, x + _cw - miniS - 3, y + miniS + 3, suit, miniS);

        var ss = _cw * 3 / 10; if (ss < 3) { ss = 3; }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        _drSuit(dc, x + _cw / 2, y + _ch / 2 + 2, suit, ss);
    }

    hidden function _drSuit(dc, cx, cy, suit, s) {
        if (s < 2) { s = 2; }
        var r = s * 5 / 10; if (r < 2) { r = 2; }
        if (suit == 0) {
            dc.fillPolygon([[cx, cy - s], [cx - s, cy + s / 4], [cx + s, cy + s / 4]]);
            dc.fillCircle(cx - r + 1, cy + s / 6, r);
            dc.fillCircle(cx + r - 1, cy + s / 6, r);
            dc.fillRectangle(cx - 1, cy + s / 3, 3, s * 4 / 10);
        } else if (suit == 1) {
            dc.fillCircle(cx - r + 1, cy - s / 4, r);
            dc.fillCircle(cx + r - 1, cy - s / 4, r);
            dc.fillPolygon([[cx - s, cy - s / 6], [cx, cy + s], [cx + s, cy - s / 6]]);
        } else if (suit == 2) {
            dc.fillPolygon([[cx, cy - s], [cx + s * 6 / 10, cy],
                            [cx, cy + s], [cx - s * 6 / 10, cy]]);
        } else {
            dc.fillCircle(cx, cy - s * 4 / 10, r);
            dc.fillCircle(cx - s * 4 / 10, cy + s / 5, r);
            dc.fillCircle(cx + s * 4 / 10, cy + s / 5, r);
            dc.fillRectangle(cx - 1, cy + s / 3, 3, s * 4 / 10);
        }
    }

    hidden function _drBack(dc, x, y) {
        dc.setColor(0x1A2E5A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, _cw, _ch, 2);
        dc.setColor(0x3A5A8A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, _cw, _ch, 2);
        dc.setColor(0x243A72, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x + 2, y + 2, _cw - 4, _ch - 4, 1);
        var mx = x + _cw / 2; var my = y + _ch / 2;
        var ds = _cw / 5; if (ds < 3) { ds = 3; }
        dc.setColor(0x4A6AAA, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[mx, my - ds], [mx + ds, my], [mx, my + ds], [mx - ds, my]]);
    }

    hidden function _drEmpty(dc, x, y) {
        dc.setColor(0x1A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, _cw, _ch, 2);
    }

    hidden function _drFndE(dc, x, y, suit) {
        _drEmpty(dc, x, y);
        var sc = (suit == 1 || suit == 2) ? 0x3A1A1A : 0x1A2A1A;
        dc.setColor(sc, Graphics.COLOR_TRANSPARENT);
        var ss = _cw * 3 / 10; if (ss < 3) { ss = 3; }
        _drSuit(dc, x + _cw / 2, y + _ch / 2, suit, ss);
    }
}
