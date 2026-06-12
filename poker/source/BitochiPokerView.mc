using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;

// States
const PK_MENU      = 0;
const PK_DEAL      = 1;   // brief pause while dealing
const PK_EXCHANGE  = 2;   // player selects cards to discard
const PK_AI_DRAW   = 3;   // AI draws (brief delay)
const PK_SHOWDOWN  = 4;
const PK_GAMEOVER  = 5;

// Card: rank 0=2 .. 12=A  suit 0=S 1=H 2=D 3=C
const POKER_ANTE       = 20;
const POKER_START_CHIPS = 500;

// Main-menu rows (navigable):
//   row 0 = PLAY
//   row 1 = LEADERBOARD (shared global board)
const PK_MENU_ROWS = 2;
const PK_ROW_PLAY  = 0;
const PK_ROW_LB    = 1;

// Global leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "poker";

class BitochiPokerView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    hidden var _deck;
    hidden var _deckTop;
    hidden var _pHand;   // [5] player cards
    hidden var _aHand;   // [5] AI cards
    hidden var _discard; // [5] bool — player marked for exchange

    hidden var _cursor;  // 0-4 = cards, 5 = DEAL/DRAW button
    hidden var _pChips; hidden var _aChips; hidden var _pot;
    hidden var _resultMsg;
    hidden var _aiDelay;

    hidden var _menuRow;        // selected main-menu row
    hidden var _peakChips;      // highest player stack reached this session
    hidden var _scoreSubmitted; // guard: submit leaderboard score once per session

    hidden var _rankStr;
    hidden var _suitStr;
    hidden var _handNames;

    // Layout
    hidden var _cw; hidden var _ch; hidden var _gap;
    hidden var _startX; hidden var _pY; hidden var _aY;

    function initialize() {
        View.initialize();
        _tick = 0; _gs = PK_MENU;
        _pChips = POKER_START_CHIPS; _aChips = POKER_START_CHIPS; _pot = 0;
        _resultMsg = ""; _aiDelay = 0;
        _menuRow = PK_ROW_PLAY;
        _peakChips = POKER_START_CHIPS; _scoreSubmitted = false;
        _deck = new [52]; _deckTop = 0;
        _pHand = new [5]; _aHand = new [5];
        _discard = new [5];
        for (var i = 0; i < 5; i++) { _discard[i] = false; }
        _cursor = 5;
        _rankStr  = ["2","3","4","5","6","7","8","9","10","J","Q","K","A"];
        // Unicode suit symbols: ♠ ♥ ♦ ♣
        _suitStr  = ["\u2660", "\u2665", "\u2666", "\u2663"];
        _handNames = ["High Card","One Pair","Two Pair","Three of a Kind",
                      "Straight","Flush","Full House","Four of a Kind",
                      "Straight Flush","Royal Flush"];
        _w = 240; _h = 240;
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 200, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupLayout();
    }

    hidden function setupLayout() {
        _cw = (_w * 70 / 100 - 12) / 5;
        if (_cw > 38) { _cw = 38; }
        if (_cw < 14) { _cw = 14; }
        _ch     = _cw * 14 / 10;
        _gap    = 3;
        var totalW = _cw * 5 + _gap * 4;
        _startX = (_w - totalW) / 2;
        _pY     = _h * 52 / 100;
        _aY     = _h * 18 / 100;
    }

    function onTick() as Void {
        _tick++;
        if (_gs == PK_DEAL) {
            _aiDelay--;
            if (_aiDelay <= 0) { _gs = PK_EXCHANGE; _cursor = 5; }
        } else if (_gs == PK_AI_DRAW) {
            _aiDelay--;
            if (_aiDelay <= 0) { doShowdown(); }
        }
        WatchUi.requestUpdate();
    }

    // ─── Input ─────────────────────────────────────────────────────────────────

    function doLeft() {
        if (_gs == PK_MENU) { menuPrev(); return; }
        if (_gs == PK_EXCHANGE) {
            _cursor = (_cursor + 4) % 6;  // 0-5, wrap
        }
    }

    function doRight() {
        if (_gs == PK_MENU) { menuNext(); return; }
        if (_gs == PK_EXCHANGE) {
            _cursor = (_cursor + 1) % 6;
        }
    }

    function doSelect() {
        if (_gs == PK_MENU) { menuActivate(); return; }
        if (_gs == PK_SHOWDOWN || _gs == PK_GAMEOVER) {
            if (_pChips <= 0 || _aChips <= 0) { resetGame(); }
            else { startRound(); }
            return;
        }
        if (_gs == PK_EXCHANGE) {
            if (_cursor < 5) {
                _discard[_cursor] = !_discard[_cursor];
            } else {
                playerDraw();
            }
        }
    }

    function doTap(tx, ty) {
        if (_gs == PK_MENU) { menuTap(tx, ty); return; }
        if (_gs == PK_SHOWDOWN || _gs == PK_GAMEOVER) {
            if (_pChips <= 0 || _aChips <= 0) { resetGame(); }
            else { startRound(); }
            return;
        }
        if (_gs != PK_EXCHANGE) { return; }

        // Check if tapped on a card
        for (var i = 0; i < 5; i++) {
            var cx = _startX + i * (_cw + _gap);
            if (tx >= cx && tx < cx + _cw && ty >= _pY && ty < _pY + _ch) {
                _cursor = i;
                _discard[i] = !_discard[i];
                return;
            }
        }

        var btnW = _w * 38 / 100;
        var btnX = (_w - btnW) / 2;
        var btnY = _pY + _ch + 18;
        var btnH = _h * 8 / 100; if (btnH < 18) { btnH = 18; } if (btnH > 24) { btnH = 24; }
        if (tx >= btnX && tx < btnX + btnW && ty >= btnY && ty < btnY + btnH) {
            playerDraw();
        }
    }

    function doBack() {
        if (_gs != PK_MENU) {
            // Quitting back to the menu ends the session — submit the run.
            endSession();
            _gs = PK_MENU; _menuRow = PK_ROW_PLAY; return true;
        }
        return false;
    }

    // ─── Main-menu navigation ───────────────────────────────────────────────────

    function menuPrev() { _menuRow = (_menuRow + PK_MENU_ROWS - 1) % PK_MENU_ROWS; }
    function menuNext() { _menuRow = (_menuRow + 1) % PK_MENU_ROWS; }

    function menuActivate() {
        if (_menuRow == PK_ROW_LB) { openLeaderboard(); }
        else { startGame(); }
    }

    hidden function menuTap(tx, ty) {
        var rg   = menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < PK_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (tx >= rowX && tx < rowX + rowW && ty >= ry && ty < ry + rowH) {
                _menuRow = i;
                menuActivate();
                return;
            }
        }
    }

    // Open the shared global leaderboard for poker.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, null, "POKER");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Geometry for the two-row main menu.  Space-aware: rows shrink to fit
    // between the title block and the bottom margin so nothing overlaps on
    // small round watches.  Returns [rowH, rowW, rowX, rowY0, gap].
    function menuRowGeom() {
        var topZone      = (_h * 56) / 100;            // rows live below the title block
        var bottomMargin = (_h * 8) / 100; if (bottomMargin < 14) { bottomMargin = 14; }
        var gap          = (_h * 3) / 100; if (gap < 5) { gap = 5; }
        var avail        = (_h - bottomMargin) - topZone;
        var rowH         = (avail - gap * (PK_MENU_ROWS - 1)) / PK_MENU_ROWS;
        if (rowH > 28) { rowH = 28; }
        if (rowH < 18) { rowH = 18; }
        var rowW = (_w * 62) / 100; if (rowW < 110) { rowW = 110; }
        var rowX = (_w - rowW) / 2;
        var used = PK_MENU_ROWS * rowH + (PK_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // ─── Leaderboard ────────────────────────────────────────────────────────────
    // METRIC: peak chip stack reached during the session. Chip stacks fluctuate
    // and a bust ends the session at 0, so the at-session-end value is not a
    // meaningful high score; the peak stack rewards how high the player grew
    // their chips. HIGHER is better. No variant.
    hidden function endSession() {
        if (_scoreSubmitted) { return; }
        _scoreSubmitted = true;
        Leaderboard.submitScore(LB_GAME_ID, _peakChips, null);
        Leaderboard.showPostGame(LB_GAME_ID, null, "POKER");
    }

    // ─── Game logic ────────────────────────────────────────────────────────────

    hidden function resetGame() {
        _pChips = POKER_START_CHIPS; _aChips = POKER_START_CHIPS;
        _peakChips = POKER_START_CHIPS; _scoreSubmitted = false;
        startRound();
    }

    hidden function startGame() {
        _pChips = POKER_START_CHIPS; _aChips = POKER_START_CHIPS;
        _peakChips = POKER_START_CHIPS; _scoreSubmitted = false;
        startRound();
    }

    hidden function startRound() {
        if (_cw == 0 && _w > 0) { setupLayout(); }
        shuffleDeck();
        for (var i = 0; i < 5; i++) {
            _pHand[i] = _deck[_deckTop]; _deckTop++;
            _aHand[i] = _deck[_deckTop]; _deckTop++;
            _discard[i] = false;
        }
        _pot = 0;
        var ante = POKER_ANTE;
        if (ante > _pChips) { ante = _pChips; }
        if (ante > _aChips) { ante = _aChips; }
        _pChips -= ante; _aChips -= ante; _pot = ante * 2;
        _cursor = 5; _gs = PK_DEAL; _aiDelay = 3;
    }

    hidden function shuffleDeck() {
        for (var i = 0; i < 52; i++) { _deck[i] = i; }
        for (var i = 51; i > 0; i--) {
            var j = (Math.rand() % (i + 1)).toNumber();
            if (j < 0) { j = -j; }
            var t = _deck[i]; _deck[i] = _deck[j]; _deck[j] = t;
        }
        _deckTop = 0;
    }

    hidden function playerDraw() {
        for (var i = 0; i < 5; i++) {
            if (_discard[i] && _deckTop < 52) {
                _pHand[i] = _deck[_deckTop]; _deckTop++;
                _discard[i] = false;
            }
        }
        _gs = PK_AI_DRAW; _aiDelay = 4;
        aiDiscard();
    }

    hidden function aiDiscard() {
        var score = handRank(_aHand);
        var discardCount = 0;
        if (score == 0) {
            // High card — discard 3 lowest unless pair potential
            var bestRank = -1;
            for (var i = 0; i < 5; i++) {
                var r = _aHand[i] / 4;
                if (r > bestRank) { bestRank = r; }
            }
            for (var i = 0; i < 5; i++) {
                var r = _aHand[i] / 4;
                if (r < bestRank - 2 && discardCount < 3) {
                    if (_deckTop < 52) { _aHand[i] = _deck[_deckTop]; _deckTop++; }
                    discardCount++;
                }
            }
        } else if (score == 1) {
            // One pair — discard 3 non-pair cards
            var ranks = new [13];
            for (var i = 0; i < 13; i++) { ranks[i] = 0; }
            for (var i = 0; i < 5; i++) { var ri = _aHand[i] / 4; ranks[ri] = ranks[ri] + 1; }
            var pairRank = -1;
            for (var r = 0; r < 13; r++) { if (ranks[r] == 2) { pairRank = r; break; } }
            for (var i = 0; i < 5; i++) {
                if (_aHand[i] / 4 != pairRank && discardCount < 3) {
                    if (_deckTop < 52) { _aHand[i] = _deck[_deckTop]; _deckTop++; }
                    discardCount++;
                }
            }
        }
        // Two pair or better — keep hand
    }

    hidden function doShowdown() {
        var pRank = handRank(_pHand);
        var aRank = handRank(_aHand);
        if (pRank > aRank) {
            _pChips += _pot; _resultMsg = "YOU WIN! +" + _pot;
        } else if (aRank > pRank) {
            _aChips += _pot; _resultMsg = "AI WINS  -" + POKER_ANTE;
        } else {
            var half = _pot / 2;
            _pChips += half; _aChips += _pot - half; _resultMsg = "TIE — chips returned";
        }
        _pot = 0;
        if (_pChips > _peakChips) { _peakChips = _pChips; }
        if (_pChips <= 0) { _resultMsg = "BROKE! GAME OVER"; _gs = PK_GAMEOVER; endSession(); return; }
        if (_aChips <= 0) { _resultMsg = "AI BROKE! YOU WIN!"; _gs = PK_GAMEOVER; endSession(); return; }
        _gs = PK_SHOWDOWN;
    }

    // ─── Hand evaluator ────────────────────────────────────────────────────────
    hidden function handRank(hand) {
        var ranks = new [13]; var suits = new [4];
        for (var i = 0; i < 13; i++) { ranks[i] = 0; }
        for (var i = 0; i < 4;  i++) { suits[i] = 0; }
        for (var i = 0; i < 5;  i++) {
            ranks[hand[i] / 4]++;
            suits[hand[i] % 4]++;
        }
        var pairs = 0; var threes = 0; var fours = 0;
        for (var i = 0; i < 13; i++) {
            if (ranks[i] == 2) { pairs++; }
            else if (ranks[i] == 3) { threes++; }
            else if (ranks[i] == 4) { fours++; }
        }
        var flush = false;
        for (var i = 0; i < 4; i++) { if (suits[i] == 5) { flush = true; } }
        var straight = false;
        var minR = 12; var maxR = 0;
        for (var i = 0; i < 13; i++) {
            if (ranks[i] > 0 && i < minR) { minR = i; }
            if (ranks[i] > 0 && i > maxR) { maxR = i; }
        }
        if (maxR - minR == 4 && pairs == 0 && threes == 0) { straight = true; }
        // Ace-low straight: A,2,3,4,5
        if (ranks[12] > 0 && ranks[0] > 0 && ranks[1] > 0 && ranks[2] > 0 && ranks[3] > 0) {
            straight = true;
        }
        if (straight && flush) {
            if (ranks[8] > 0 && ranks[9] > 0 && ranks[10] > 0 && ranks[11] > 0 && ranks[12] > 0) {
                return 9; // royal flush
            }
            return 8; // straight flush
        }
        if (fours > 0)          { return 7; }
        if (threes > 0 && pairs > 0) { return 6; } // full house
        if (flush)              { return 5; }
        if (straight)           { return 4; }
        if (threes > 0)         { return 3; }
        if (pairs == 2)         { return 2; }
        if (pairs == 1)         { return 1; }
        return 0;
    }

    // ─── Rendering ─────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        if (_w != dc.getWidth() || _h != dc.getHeight()) {
            _w = dc.getWidth(); _h = dc.getHeight(); setupLayout();
        }
        dc.setColor(0x000000, 0x000000);
        dc.clear();

        if (_gs == PK_MENU)     { drawMenu(dc); return; }
        if (_gs == PK_GAMEOVER) { drawGameOver(dc); return; }

        drawAIHand(dc);
        drawPlayerHand(dc);
        drawHUD(dc);

        if (_gs == PK_EXCHANGE) { drawExchangeUI(dc); }
        if (_gs == PK_SHOWDOWN) { drawShowdown(dc); }
        if (_gs == PK_AI_DRAW || _gs == PK_DEAL) { drawWaiting(dc); }
    }

    hidden function drawMenu(dc) {
        var cx = _w / 2;
        // Title block ~18% smaller (FONT_MEDIUM/XTINY) and lifted up so the two
        // interactive rows below never overlap on small round watches.
        dc.setColor(0xEE4400, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 8 / 100, Graphics.FONT_MEDIUM, "POKER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 26 / 100, Graphics.FONT_XTINY, "5-Card Draw", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 40 / 100, Graphics.FONT_XTINY, "Chips: " + _pChips + " vs " + _aChips, Graphics.TEXT_JUSTIFY_CENTER);

        // Two interactive rows: PLAY + LEADERBOARD.
        var rg   = menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < PK_MENU_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _menuRow);

            if (i == PK_ROW_LB) {
                // Gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            // PLAY row — amber-accented to match the poker theme.
            var bg; var bd; var fg;
            if (sel) { bg = 0x442200; bd = 0xEE8822; fg = 0xFFCC66; }
            else     { bg = 0x201408; bd = 0x553311; fg = 0xAA8866; }
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(bd, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        "PLAY", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 40 / 100, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 72 / 100, Graphics.FONT_MEDIUM, "TAP TO RETRY", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawAIHand(dc) {
        for (var i = 0; i < 5; i++) {
            var cx = _startX + i * (_cw + _gap);
            if (_gs == PK_SHOWDOWN || _gs == PK_GAMEOVER) {
                drawCard(dc, cx, _aY, _aHand[i], false);
            } else {
                drawCardBack(dc, cx, _aY);
            }
        }
    }

    hidden function drawPlayerHand(dc) {
        for (var i = 0; i < 5; i++) {
            var cx = _startX + i * (_cw + _gap);
            drawCard(dc, cx, _pY, _pHand[i], _discard[i]);
            if (i == _cursor && _gs == PK_EXCHANGE) {
                dc.setColor(0xFFEE00, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(cx - 1, _pY - 1, _cw + 2, _ch + 2);
                dc.drawRectangle(cx - 2, _pY - 2, _cw + 4, _ch + 4);
            }
        }
    }

    hidden function drawCard(dc, x, y, card, dimmed) {
        var rank = card / 4;
        var suit = card % 4;
        var isRed = (suit == 1 || suit == 2);

        var cr = 2 + _cw / 20;
        dc.setColor(dimmed ? 0xDDD8CC : 0xFCFAF6, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, _cw, _ch, cr);
        dc.setColor(dimmed ? 0xAA9988 : 0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, _cw, _ch, cr);

        var tc = isRed ? 0xCC1111 : 0x222222;
        if (dimmed) { tc = isRed ? 0xAA6666 : 0x888888; }

        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 3, y + 1, Graphics.FONT_XTINY, _rankStr[rank], Graphics.TEXT_JUSTIFY_LEFT);

        var ss = _cw * 3 / 10; if (ss < 3) { ss = 3; }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        _drawSuit(dc, x + _cw / 2, y + _ch / 2, suit, ss);

        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        if (_ch >= fh + 20) {
            dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + _cw - 3, y + _ch - fh - 2, Graphics.FONT_XTINY,
                _rankStr[rank], Graphics.TEXT_JUSTIFY_RIGHT);
        }

        if (dimmed) {
            dc.setColor(0xDD3333, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x + 3, y + 3, x + _cw - 3, y + _ch - 3);
            dc.drawLine(x + _cw - 3, y + 3, x + 3, y + _ch - 3);
        }
    }

    // Geometric suit drawing — no Unicode dependency, scales to any size.
    // cx,cy = center; suit: 0=spade 1=heart 2=diamond 3=club; s = half-size
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
        // Navy background
        dc.setColor(0x1A2E5A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, _cw, _ch, cr);
        // Light border
        dc.setColor(0x4A6AAA, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, _cw, _ch, cr);
        // Inner inset rectangle
        var m = 3;
        dc.setColor(0x243A72, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x + m, y + m, _cw - m * 2, _ch - m * 2, 2);
        // Small center diamond
        var cx = x + _cw / 2;
        var cy = y + _ch / 2;
        var ds = _cw / 5; if (ds < 3) { ds = 3; }
        dc.setColor(0x4A6AAA, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, cy - ds], [cx + ds, cy], [cx, cy + ds], [cx - ds, cy]]);
    }

    hidden function drawHUD(dc) {
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(0x44CC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _aY - fh - 2, Graphics.FONT_XTINY, "AI:" + _aChips, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _pY + _ch + 1, Graphics.FONT_XTINY, "YOU:" + _pChips, Graphics.TEXT_JUSTIFY_CENTER);

        if (_pot > 0) {
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, (_aY + _ch + _pY) / 2 - fh / 2, Graphics.FONT_XTINY,
                "POT:" + _pot, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawExchangeUI(dc) {
        var fh     = dc.getFontHeight(Graphics.FONT_XTINY);
        var btnW   = _w * 38 / 100;
        var btnX   = (_w - btnW) / 2;
        var btnY   = _pY + _ch + fh + 4;
        var btnH   = _h * 8 / 100; if (btnH < 18) { btnH = 18; } if (btnH > 24) { btnH = 24; }
        var active = (_cursor == 5);
        dc.setColor(active ? 0x228822 : 0x114411, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(btnX, btnY, btnW, btnH, 4);
        dc.setColor(active ? 0x55FF55 : 0x33AA33, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(btnX, btnY, btnW, btnH, 4);
        dc.setColor(active ? 0xFFFFFF : 0x88CC88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, btnY + (btnH - 16) / 2, Graphics.FONT_XTINY,
                    "DRAW / KEEP", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawShowdown(dc) {
        // Darken center strip
        dc.setColor(0x0A0A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _aY + _ch + 2, _w, _pY - _aY - _ch - 4);

        var aRank = handRank(_aHand);
        var pRank = handRank(_pHand);

        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 5 / 100, _aY + _ch + 3, Graphics.FONT_XTINY, _handNames[aRank], Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 5 / 100, _pY - _h * 9 / 100, Graphics.FONT_XTINY, _handNames[pRank], Graphics.TEXT_JUSTIFY_LEFT);

        var rc = 0xFFFFFF;
        if (_resultMsg.find("WIN") != null) { rc = 0x44FF44; }
        if (_resultMsg.find("AI WIN") != null) { rc = 0xFF4444; }
        if (_resultMsg.find("TIE") != null) { rc = 0xFFAA00; }
        dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _aY + _ch + _h * 7 / 100, Graphics.FONT_XTINY, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0x888888 : 0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _pY + _ch + 16, Graphics.FONT_XTINY, "Tap for next", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawWaiting(dc) {
        var dots = "";
        for (var i = 0; i < (_tick % 4); i++) { dots = dots + "."; }
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _pY + _ch + 16, Graphics.FONT_XTINY, "Dealing" + dots, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
