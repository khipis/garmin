using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;

// States
const BJ_MENU     = 0;
const BJ_PLAY     = 1;   // player's turn
const BJ_DEALER   = 2;   // dealer draws (animated)
const BJ_RESULT   = 3;

// Card: rank 0=2 .. 12=A  suit 0=S 1=H 2=D 3=C
const BJ_START_CHIPS = 500;
const BJ_BET         = 50;

// Global leaderboard
const LB_GAME_ID = "blackjack";

class BitochiBlackjackView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    hidden var _deck; hidden var _deckTop;
    hidden var _pCards; hidden var _pCount;
    hidden var _dCards; hidden var _dCount;

    // Shoe size from the shared OPTIONS screen (bj_decks: 0/1/2 = 1/2/6 decks).
    // The shoe is only reshuffled when it runs low (penetration), so more decks
    // genuinely last many more rounds and shift the odds. Segments the LB.
    hidden var _decksIdx; hidden var _numDecks; hidden var _shoeSize;

    hidden var _chips; hidden var _resultMsg;
    hidden var _dealerDelay;

    // Leaderboard: peak bankroll reached this session + session-end bookkeeping
    hidden var _peakChips; hidden var _sessionActive;
    // Menu navigation (bricks-style): 0 = PLAY, 1 = LEADERBOARD.
    hidden var _menuSel;
    hidden var _mRowX; hidden var _mRowW; hidden var _mRowH;
    hidden var _mPlayY; hidden var _mLbY;

    hidden var _rankStr; hidden var _suitStr;

    // Layout
    hidden var _cw; hidden var _ch; hidden var _gap;
    hidden var _pY; hidden var _dY;

    function initialize() {
        View.initialize();
        _tick = 0; _gs = BJ_MENU;
        _chips = BJ_START_CHIPS;
        _peakChips = BJ_START_CHIPS; _sessionActive = false;
        _menuSel = 0;
        _mRowX = 0; _mRowW = 0; _mRowH = 0; _mPlayY = 0; _mLbY = 0;
        _resultMsg = "";
        _decksIdx = 2;
        var dv = Application.Storage.getValue("bj_decks");
        if (dv instanceof Number && dv >= 0 && dv <= 2) { _decksIdx = dv; }
        _numDecks = [1, 2, 6][_decksIdx];
        _shoeSize = _numDecks * 52;
        _deck = new [_shoeSize]; _deckTop = _shoeSize;  // force a shuffle on first deal
        _pCards = new [12]; _pCount = 0;
        _dCards = new [12]; _dCount = 0;
        _dealerDelay = 0;
        _rankStr = ["2","3","4","5","6","7","8","9","10","J","Q","K","A"];
        _suitStr = ["\u2660", "\u2665", "\u2666", "\u2663"];  // ♠ ♥ ♦ ♣
        _w = 240; _h = 240;
        _timer = null;
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupLayout();
    }

    function onShow() {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 300, true);
        }
        // Root menu is the shared view; drop straight into a session. Only
        // auto-start from a fresh launch (returning from a pushed card keeps play).
        if (_gs == BJ_MENU) { startGame(); }
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    hidden function setupLayout() {
        _gap = 3;
        _cw = (_w * 70 / 100 - 4 * _gap) / 5;
        if (_cw > 36) { _cw = 36; }
        if (_cw < 14) { _cw = 14; }
        _ch = _cw * 14 / 10;
        var totalH = 2 * _ch + 70;
        var startY = (_h - totalH) / 2;
        if (startY < 4) { startY = 4; }
        _dY = startY + 26;
        _pY = _dY + _ch + 18;
    }

    function onTick() as Void {
        _tick++;
        if (_gs == BJ_DEALER) {
            _dealerDelay--;
            if (_dealerDelay <= 0) { dealerStep(); }
        }
        WatchUi.requestUpdate();
    }

    // ─── Input ─────────────────────────────────────────────────────────────────

    function doHit() {
        if (_gs == BJ_MENU) { menuActivate(); return; }
        if (_gs == BJ_RESULT) { nextRound(); return; }
        if (_gs != BJ_PLAY) { return; }
        _pCards[_pCount] = dealCard(); _pCount++;
        if (handValue(_pCards, _pCount) > 21) {
            _resultMsg = "BUST! -" + BJ_BET;
            _chips -= BJ_BET;
            if (_chips <= 0) { _chips = 0; _resultMsg = "BUST! BROKE!"; }
            _gs = BJ_RESULT;
        }
    }

    function doStand() {
        if (_gs == BJ_MENU) { menuActivate(); return; }
        if (_gs == BJ_RESULT) { nextRound(); return; }
        if (_gs != BJ_PLAY) { return; }
        _gs = BJ_DEALER;
        _dealerDelay = 2;
    }

    function doTap(tx, ty) {
        if (_gs == BJ_MENU) {
            if (tx >= _mRowX && tx <= _mRowX + _mRowW) {
                if (ty >= _mPlayY && ty <= _mPlayY + _mRowH) { _menuSel = 0; menuActivate(); return; }
                if (ty >= _mLbY   && ty <= _mLbY   + _mRowH) { _menuSel = 1; menuActivate(); return; }
            }
            _menuSel = 0; menuActivate(); return;
        }
        if (_gs == BJ_RESULT) { nextRound(); return; }
        if (_gs != BJ_PLAY) { return; }
        doHit();
    }

    function doBack() {
        // Quitting to the shared menu ends the session: submit the peak
        // bankroll, then let the framework pop us back to the root menu.
        if (_sessionActive) {
            Leaderboard.submitScore(LB_GAME_ID, _peakChips, _lbVariant());
            _sessionActive = false;
        }
        return false;
    }

    function isMenu() { return _gs == BJ_MENU; }

    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _lbVariant(), "BLACKJACK");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // ─── Game logic ────────────────────────────────────────────────────────────

    hidden function startGame() {
        if (_cw == 0 && _w > 0) { setupLayout(); }
        _chips = BJ_START_CHIPS;
        _peakChips = BJ_START_CHIPS;
        _sessionActive = true;
        nextRound();
    }

    // Submit the session's peak bankroll once, then close the session.
    hidden function endSession() {
        if (_sessionActive) {
            Leaderboard.submitScore(LB_GAME_ID, _peakChips, _lbVariant());
            Leaderboard.showPostGame(LB_GAME_ID, _lbVariant(), "BLACKJACK");
            _sessionActive = false;
        }
    }

    hidden function trackPeak() {
        if (_chips > _peakChips) { _peakChips = _chips; }
    }

    hidden function nextRound() {
        // Broke last round -> that session is over: submit it, then start fresh.
        if (_chips <= 0) {
            endSession();
            _chips = BJ_START_CHIPS;
            _peakChips = BJ_START_CHIPS;
            _sessionActive = true;
        }
        // Reshuffle only when the shoe runs low, so a bigger shoe lasts many
        // more rounds and the composition drifts between reshuffles.
        if (_deckTop > _shoeSize - 20) { shuffleDeck(); }
        _pCount = 0; _dCount = 0;
        _pCards[_pCount] = dealCard(); _pCount++;
        _dCards[_dCount] = dealCard(); _dCount++;
        _pCards[_pCount] = dealCard(); _pCount++;
        _dCards[_dCount] = dealCard(); _dCount++;
        _resultMsg = "";
        _gs = BJ_PLAY;

        // Natural blackjack — go straight to dealer reveal
        if (handValue(_pCards, _pCount) == 21) {
            _gs = BJ_DEALER; _dealerDelay = 1;
        }
    }

    hidden function dealCard() {
        if (_deckTop >= _shoeSize) { shuffleDeck(); }
        var c = _deck[_deckTop]; _deckTop++;
        return c;
    }

    hidden function dealerStep() {
        var dVal = handValue(_dCards, _dCount);
        var pVal = handValue(_pCards, _pCount);

        if (dVal < 17) {
            _dCards[_dCount] = dealCard(); _dCount++;
            _dealerDelay = 2;
        } else {
            // Dealer stands — resolve
            dVal = handValue(_dCards, _dCount);
            if (dVal > 21) {
                _resultMsg = "DEALER BUST! +" + BJ_BET;
                _chips += BJ_BET;
                trackPeak();
            } else if (pVal > dVal) {
                _resultMsg = "YOU WIN! +" + BJ_BET;
                _chips += BJ_BET;
                trackPeak();
            } else if (dVal > pVal) {
                _resultMsg = "DEALER WINS -" + BJ_BET;
                _chips -= BJ_BET;
                if (_chips < 0) { _chips = 0; }
            } else {
                _resultMsg = "PUSH — Tie";
            }
            _gs = BJ_RESULT;
        }
    }

    hidden function shuffleDeck() {
        for (var i = 0; i < _shoeSize; i++) { _deck[i] = i % 52; }
        for (var i = _shoeSize - 1; i > 0; i--) {
            var j = (Math.rand() % (i + 1)).toNumber();
            if (j < 0) { j = -j; }
            var t = _deck[i]; _deck[i] = _deck[j]; _deck[j] = t;
        }
        _deckTop = 0;
    }

    // Leaderboard variant = shoe size, so 1/2/6 decks rank separately.
    hidden function _lbVariant() {
        return ["d1", "d2", "d6"][_decksIdx];
    }

    // Returns best hand value (aces counted optimally)
    hidden function handValue(hand, count) {
        var total = 0; var aces = 0;
        for (var i = 0; i < count; i++) {
            var rank = hand[i] / 4;
            if (rank >= 9 && rank <= 11) { total += 10; }       // T/J/Q/K
            else if (rank == 12) { total += 11; aces++; }       // A
            else { total += rank + 2; }                         // 2-9
        }
        while (total > 21 && aces > 0) { total -= 10; aces--; }
        return total;
    }

    // ─── Rendering ─────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        if (_w != dc.getWidth() || _h != dc.getHeight()) {
            _w = dc.getWidth(); _h = dc.getHeight(); setupLayout();
        }
        dc.setColor(0x000000, 0x000000);
        dc.clear();

        if (_gs == BJ_MENU) { startGame(); }   // never render an in-game menu

        drawHUD(dc);
        drawDealerHand(dc);
        drawPlayerHand(dc);

        if (_gs == BJ_PLAY)   { drawActions(dc); }
        if (_gs == BJ_RESULT) { drawResult(dc); }
        if (_gs == BJ_DEALER) { drawDealerThinking(dc); }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x22AA44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 13 / 100, Graphics.FONT_LARGE, "BLACKJACK", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 31 / 100, Graphics.FONT_SMALL, "Beat the dealer!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 42 / 100, Graphics.FONT_XTINY, "Chips: $" + _chips, Graphics.TEXT_JUSTIFY_CENTER);

        // Space-aware menu rows: PLAY + LEADERBOARD, centred and ~18% smaller
        // than a full-width control so nothing clips on round watches.
        var rowW = _w * 58 / 100;
        var rowH = _h * 10 / 100; if (rowH < 18) { rowH = 18; }
        var gap  = _h * 3 / 100;  if (gap  < 4)  { gap  = 4;  }
        var rowX = (_w - rowW) / 2;
        var playY = _h * 51 / 100;
        var lbY   = playY + rowH + gap;
        _mRowX = rowX; _mRowW = rowW; _mRowH = rowH;
        _mPlayY = playY; _mLbY = lbY;

        var pSel = (_menuSel == 0);
        dc.setColor(pSel ? 0x103820 : 0x0C1C12, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rowX, playY, rowW, rowH, 5);
        dc.setColor(pSel ? 0x44CC66 : 0x227A44, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rowX, playY, rowW, rowH, 5);
        if (pSel) {
            var ay = playY + rowH / 2;
            dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
        }
        dc.setColor(pSel ? 0xFFFFFF : 0xAAD8BB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 6, playY + (rowH - 14) / 2, Graphics.FONT_XTINY, "PLAY", Graphics.TEXT_JUSTIFY_CENTER);

        LbBadge.drawRow(dc, rowX, lbY, rowW, rowH, _menuSel == 1);

        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "HIT=Sel  STAND=Down", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Cycle the menu selection (PLAY <-> LEADERBOARD).
    function menuNav(d) {
        if (_gs != BJ_MENU) { return; }
        _menuSel = (_menuSel + d + 2) % 2;
    }

    // Activate the currently selected menu row.
    function menuActivate() {
        if (_menuSel == 1) { openLeaderboard(); }
        else               { startGame(); }
    }

    hidden function drawHUD(dc) {
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var hudY = _dY - fh * 2 - 4;
        if (hudY < 2) { hudY = 2; }
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, hudY, Graphics.FONT_XTINY, "$" + _chips, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawDealerHand(dc) {
        var hideSecond   = (_gs == BJ_PLAY);
        var showFullScore = !hideSecond;
        var dVal = handValue(_dCards, _dCount);
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _dY - fh - 1, Graphics.FONT_XTINY,
            showFullScore ? ("DEALER:" + dVal) : "DEALER:?", Graphics.TEXT_JUSTIFY_CENTER);

        // Center the hand horizontally
        var totalW = _dCount * (_cw + _gap) - _gap;
        var startX = (_w - totalW) / 2;
        for (var i = 0; i < _dCount; i++) {
            var cx = startX + i * (_cw + _gap);
            if (i == 1 && hideSecond) { drawCardBack(dc, cx, _dY); }
            else                      { drawCard(dc, cx, _dY, _dCards[i]); }
        }
    }

    // Draw centered player hand with score label above it
    hidden function drawPlayerHand(dc) {
        var pVal = handValue(_pCards, _pCount);
        var pcol = 0xCCEEFF;
        if (pVal > 21)      { pcol = 0xFF5555; }
        else if (pVal == 21){ pcol = 0x55FF99; }

        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(pcol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _pY - fh - 1, Graphics.FONT_XTINY, "YOU:" + pVal, Graphics.TEXT_JUSTIFY_CENTER);

        // Center the hand horizontally
        var totalW = _pCount * (_cw + _gap) - _gap;
        var startX = (_w - totalW) / 2;
        for (var i = 0; i < _pCount; i++) {
            var cx = startX + i * (_cw + _gap);
            drawCard(dc, cx, _pY, _pCards[i]);
        }
    }

    hidden function drawCard(dc, x, y, card) {
        var rank = card / 4;
        var suit = card % 4;
        var isRed = (suit == 1 || suit == 2);
        var tc = isRed ? 0xCC1111 : 0x222222;

        var cr = 2 + _cw / 20;
        dc.setColor(0xFCFAF6, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, _cw, _ch, cr);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, _cw, _ch, cr);

        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 3, y + 2, Graphics.FONT_XTINY, _rankStr[rank], Graphics.TEXT_JUSTIFY_LEFT);

        var ss = _cw * 3 / 10; if (ss < 3) { ss = 3; }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        _drawSuit(dc, x + _cw / 2, y + _ch / 2, suit, ss);

        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        if (_ch >= fh + 20) {
            dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + _cw - 3, y + _ch - fh - 2, Graphics.FONT_XTINY,
                        _rankStr[rank], Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    hidden function _drawSuit(dc, cx, cy, suit, s) {
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
            dc.fillPolygon([[cx, cy - s], [cx + s * 6 / 10, cy], [cx, cy + s], [cx - s * 6 / 10, cy]]);
        } else {
            dc.fillCircle(cx, cy - s * 4 / 10, r);
            dc.fillCircle(cx - s * 4 / 10, cy + s / 5, r);
            dc.fillCircle(cx + s * 4 / 10, cy + s / 5, r);
            dc.fillRectangle(cx - 1, cy + s / 3, 3, s * 4 / 10);
        }
    }

    hidden function drawCardBack(dc, x, y) {
        var cr = 2 + _cw / 20;
        dc.setColor(0x1A2E5A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, _cw, _ch, cr);
        dc.setColor(0x4A6AAA, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, _cw, _ch, cr);
        // Inner border
        var m = 3;
        dc.setColor(0x243A72, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x + m, y + m, _cw - m * 2, _ch - m * 2, 2);
        // Center diamond
        var cx = x + _cw / 2; var cy = y + _ch / 2;
        var ds = _cw / 5; if (ds < 3) { ds = 3; }
        dc.setColor(0x4A6AAA, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, cy - ds], [cx + ds, cy], [cx, cy + ds], [cx - ds, cy]]);
    }

    hidden function drawActions(dc) {
        var fh   = dc.getFontHeight(Graphics.FONT_XTINY);
        var btnY = _pY + _ch + 4;
        var btnH = fh + 6; if (btnH < 18) { btnH = 18; }
        var bW   = _w * 36 / 100; if (bW < 50) { bW = 50; }
        var bX   = (_w - bW) / 2;

        dc.setColor(0x1A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bX, btnY, bW, btnH, 4);
        dc.setColor(0x44AA44, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bX, btnY, bW, btnH, 4);
        dc.setColor(0xAAFFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bX + bW / 2, btnY + (btnH - fh) / 2,
                    Graphics.FONT_XTINY, "HIT", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, btnY + btnH + 2, Graphics.FONT_XTINY,
                    "DOWN = STAND", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawResult(dc) {
        var rc = 0xFFFFFF;
        if (_resultMsg.find("WIN") != null)      { rc = 0x44FF88; }
        if (_resultMsg.find("DEALER WINS") != null
            || _resultMsg.find("BUST! -") != null) { rc = 0xFF5555; }

        var rH = _h * 16 / 100; if (rH < 32) { rH = 32; } if (rH > 44) { rH = 44; }
        var ry = _pY + _ch + 2;
        if (ry + rH > _h - 4) { ry = _h - rH - 4; }

        dc.setColor(0x080808, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w * 14 / 100, ry, _w * 72 / 100, rH, 5);
        dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, ry + 2, Graphics.FONT_XTINY, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, ry + rH / 2, Graphics.FONT_XTINY, "Tap next", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawDealerThinking(dc) {
        var dots = "";
        for (var i = 0; i < (_tick % 4); i++) { dots = dots + "."; }
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _pY + _ch + 12, Graphics.FONT_XTINY,
            "Dealer" + dots, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
