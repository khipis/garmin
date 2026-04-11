using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── 5-Card Draw Poker ─────────────────────────────────────────────────────────
// States
const PS_MENU     = 0;
const PS_EXCHANGE = 1;   // player selects cards to swap (0-2)
const PS_AI_DRAW  = 2;   // brief pause while AI draws
const PS_SHOWDOWN = 3;   // both hands face-up, result shown
const PS_GAMEOVER = 4;

// Card: rank*4 + suit    rank 0=2 … 12=A    suit 0=♠ 1=♥ 2=♦ 3=♣
const ANTE       = 20;
const START_CHIPS = 500;
const MAX_DISCARD = 2;   // player may swap up to 2 cards

class BitochiPokerView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    // Deck
    hidden var _deck;    // [52]
    hidden var _deckTop;

    // Hands: [5] each
    hidden var _pHand;   // player
    hidden var _aHand;   // AI

    // Selection (exchange phase)
    hidden var _discard; // [5] boolean — marked for discard
    hidden var _curCard; // cursor index 0-4

    // Chips & pot
    hidden var _pChips;
    hidden var _aChips;
    hidden var _pot;

    // Result
    hidden var _resultMsg;
    hidden var _aiDelay;

    // Hand evaluation strings
    hidden var _rankStr;
    hidden var _suitStr;
    hidden var _handNames;

    // Geometry (computed in setupGeo)
    hidden var _cw; hidden var _ch; hidden var _gap;
    hidden var _startX;
    hidden var _pHandY;   // top of player hand
    hidden var _aHandY;   // top of AI hand

    // ── Initialize ────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _w = 0; _h = 0; _tick = 0;
        _gs = PS_MENU;
        _pChips = START_CHIPS; _aChips = START_CHIPS; _pot = 0;
        _resultMsg = ""; _aiDelay = 0;

        _deck  = new [52]; _deckTop = 0;
        _pHand = new [5];  _aHand  = new [5];
        _discard = new [5];
        for (var i = 0; i < 5; i++) { _discard[i] = false; _pHand[i] = i; _aHand[i] = i+5; }
        _curCard = 0;

        _rankStr  = ["2","3","4","5","6","7","8","9","T","J","Q","K","A"];
        _suitStr  = ["\u2660","\u2665","\u2666","\u2663"];
        _handNames = ["High Card","Pair","Two Pair","Three of a Kind",
                      "Straight","Flush","Full House","Four of a Kind",
                      "Str.Flush","Royal Flush"];

        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 150, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupGeo();
    }

    hidden function setupGeo() {
        // 5 cards across — safe zone on round screen.
        // Cards at two rows: AI near top (y≈28), player near bottom (y≈190).
        // At y=190+ch, safeHalf = sqrt(r²-(r-y-ch)²) must fit 5 cards.
        var r = _w / 2;
        _gap = 4;
        // Use card height ≈ screen height * 13/100 but cap
        _ch = _h * 14 / 100;
        if (_ch > 42) { _ch = 42; }
        if (_ch < 28) { _ch = 28; }
        _cw = _ch * 24 / 36; // width = 2/3 of height

        var totalW = _cw * 5 + _gap * 4;
        // Ensure fits at narrowest Y we'll use
        var bottomY = _h * 77 / 100 + _ch; // bottom of player hand
        var dy = bottomY > r ? bottomY - r : r - bottomY;
        var safeHalf = Math.sqrt((r * r - dy * dy).toFloat()).toNumber() - 4;
        if (totalW > safeHalf * 2) {
            _cw = (safeHalf * 2 - _gap * 4) / 5;
            _ch = _cw * 36 / 24;
        }

        _startX = (_w - (_cw * 5 + _gap * 4)) / 2;
        _aHandY = _h * 10 / 100;         // AI hand top
        _pHandY = _h * 77 / 100;         // player hand top
    }

    // ── Timer ─────────────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        if (_gs == PS_AI_DRAW) {
            _aiDelay--;
            if (_aiDelay <= 0) { doAiDraw(); }
        }
        WatchUi.requestUpdate();
    }

    // ── Input ─────────────────────────────────────────────────────────────────
    function doUp() {
        if (_gs == PS_MENU)     { return; }
        if (_gs == PS_GAMEOVER) { _gs = PS_MENU; return; }
        if (_gs == PS_SHOWDOWN) { dealNewHand(); return; }
        if (_gs == PS_EXCHANGE) {
            if (_curCard > 0) { _curCard--; }
        }
    }

    function doDown() {
        if (_gs == PS_MENU)     { return; }
        if (_gs == PS_GAMEOVER) { _gs = PS_MENU; return; }
        if (_gs == PS_SHOWDOWN) { dealNewHand(); return; }
        if (_gs == PS_EXCHANGE) {
            if (_curCard < 4) { _curCard++; }
        }
    }

    function doSelect() {
        if (_gs == PS_MENU)     { startGame(); return; }
        if (_gs == PS_GAMEOVER) { _gs = PS_MENU; return; }
        if (_gs == PS_SHOWDOWN) { dealNewHand(); return; }
        if (_gs == PS_EXCHANGE) { toggleDiscard(_curCard); }
    }

    function doBack() {
        if (_gs != PS_MENU) { _gs = PS_MENU; }
    }

    function doMenu() { doBack(); }

    function doTap(tx, ty) {
        if (_gs == PS_MENU)     { startGame(); return; }
        if (_gs == PS_GAMEOVER) { _gs = PS_MENU; return; }
        if (_gs == PS_SHOWDOWN) { dealNewHand(); return; }
        if (_gs == PS_AI_DRAW)  { return; }
        if (_gs != PS_EXCHANGE) { return; }

        // Tap on a player card → toggle discard
        for (var i = 0; i < 5; i++) {
            var cx = _startX + i * (_cw + _gap);
            if (tx >= cx && tx < cx + _cw && ty >= _pHandY && ty < _pHandY + _ch) {
                _curCard = i; toggleDiscard(i); return;
            }
        }

        // Tap on the DEAL button (centre of screen ~y=55%)
        var btnY = _h * 53 / 100; var btnH = 24;
        if (ty >= btnY && ty < btnY + btnH) {
            commitExchange(); return;
        }
    }

    hidden function toggleDiscard(i) {
        if (_discard[i]) {
            _discard[i] = false; return;
        }
        // Count how many already marked
        var cnt = 0;
        for (var j = 0; j < 5; j++) { if (_discard[j]) { cnt++; } }
        if (cnt < MAX_DISCARD) { _discard[i] = true; }
    }

    // ── Game flow ─────────────────────────────────────────────────────────────
    hidden function startGame() {
        _pChips = START_CHIPS; _aChips = START_CHIPS;
        _resultMsg = "";
        dealNewHand();
    }

    hidden function dealNewHand() {
        if (_pChips <= 0 || _aChips <= 0) { _gs = PS_GAMEOVER; return; }

        // Ante
        var ante = ANTE;
        if (ante > _pChips) { ante = _pChips; }
        if (ante > _aChips) { ante = _aChips; }
        _pChips -= ante; _aChips -= ante; _pot = ante * 2;

        // Shuffle
        for (var i = 0; i < 52; i++) { _deck[i] = i; }
        for (var i = 51; i > 0; i--) {
            var j = Math.rand().abs() % (i + 1);
            var t = _deck[i]; _deck[i] = _deck[j]; _deck[j] = t;
        }
        _deckTop = 0;

        // Deal 5 to each
        for (var i = 0; i < 5; i++) { _pHand[i] = _deck[_deckTop]; _deckTop++; }
        for (var i = 0; i < 5; i++) { _aHand[i] = _deck[_deckTop]; _deckTop++; }

        for (var i = 0; i < 5; i++) { _discard[i] = false; }
        _curCard = 0;
        _gs = PS_EXCHANGE;
    }

    hidden function commitExchange() {
        // Replace player's discarded cards
        for (var i = 0; i < 5; i++) {
            if (_discard[i]) { _pHand[i] = _deck[_deckTop]; _deckTop++; _discard[i] = false; }
        }
        _gs = PS_AI_DRAW;
        _aiDelay = 5;
    }

    hidden function doAiDraw() {
        // AI draws: discard cards not contributing to best hand
        aiExchange();
        // Showdown
        var pScore = evalHand(_pHand);
        var aScore = evalHand(_aHand);
        if (pScore > aScore)      { _resultMsg = "YOU WIN!";  _pChips += _pot; }
        else if (aScore > pScore) { _resultMsg = "YOU LOSE";  _aChips += _pot; }
        else                      { _resultMsg = "SPLIT POT"; _pChips += _pot/2; _aChips += _pot/2; }
        _pot = 0;
        _gs = PS_SHOWDOWN;
    }

    // ── AI exchange logic ─────────────────────────────────────────────────────
    hidden function aiExchange() {
        // Count ranks and suits
        var ranks = new [13];
        var suits = new [4];
        for (var i = 0; i < 13; i++) { ranks[i] = 0; }
        for (var i = 0; i < 4;  i++) { suits[i] = 0; }
        for (var i = 0; i < 5;  i++) {
            ranks[_aHand[i] / 4]++;
            suits[_aHand[i] % 4]++;
        }

        // Classify current hand strength
        var maxRank = 0; var pairs = 0; var trips = 0; var quads = 0;
        for (var i = 0; i < 13; i++) {
            if (ranks[i] > maxRank) { maxRank = ranks[i]; }
            if (ranks[i] == 2) { pairs++; }
            if (ranks[i] == 3) { trips++; }
            if (ranks[i] == 4) { quads++; }
        }
        var flushDraw = false;
        for (var i = 0; i < 4; i++) { if (suits[i] == 4) { flushDraw = true; } }

        // Decide what to keep
        // Four of a kind / full house / flush / straight → keep all
        if (quads > 0 || (pairs > 0 && trips > 0)) { return; }

        // Check flush (all same suit)
        var flushSuit = -1;
        for (var i = 0; i < 4; i++) { if (suits[i] == 5) { flushSuit = i; } }
        if (flushSuit >= 0) { return; }

        // Three of a kind → keep trips, discard 2
        if (trips > 0) {
            var cnt = 0;
            for (var i = 0; i < 5; i++) {
                if (ranks[_aHand[i] / 4] < 3 && cnt < 2) { _aHand[i] = _deck[_deckTop]; _deckTop++; cnt++; }
            }
            return;
        }

        // Two pair → keep both pairs
        if (pairs >= 2) { return; }

        // One pair → keep pair, discard worst 2 (up to MAX_DISCARD)
        if (pairs == 1) {
            var pairRank = -1;
            for (var i = 0; i < 13; i++) { if (ranks[i] == 2) { pairRank = i; } }
            var cnt = 0;
            for (var i = 0; i < 5; i++) {
                if (_aHand[i] / 4 != pairRank && cnt < MAX_DISCARD) {
                    _aHand[i] = _deck[_deckTop]; _deckTop++; cnt++;
                }
            }
            return;
        }

        // Flush draw (4 same suit) → draw 1
        if (flushDraw) {
            for (var i = 0; i < 5; i++) {
                if (_aHand[i] % 4 != suits[0] && suits[0] == 4) {
                    // find the suit with 4
                }
            }
            var oddSuit = -1; var fsIdx = -1;
            for (var s = 0; s < 4; s++) { if (suits[s] == 4) { fsIdx = s; } }
            if (fsIdx >= 0) {
                for (var i = 0; i < 5; i++) {
                    if (_aHand[i] % 4 != fsIdx) { _aHand[i] = _deck[_deckTop]; _deckTop++; break; }
                }
            }
            return;
        }

        // Nothing → discard 2 lowest-rank cards
        var swapped = 0;
        // Simple: sort indices by rank ascending, swap first 2
        var loIdx0 = 0; var loIdx1 = 1;
        var loR0 = _aHand[0] / 4; var loR1 = _aHand[1] / 4;
        if (loR0 > loR1) {
            var t = loR0; loR0 = loR1; loR1 = t;
            var ti = loIdx0; loIdx0 = loIdx1; loIdx1 = ti;
        }
        for (var i = 2; i < 5; i++) {
            var r = _aHand[i] / 4;
            if (r < loR0) { loR1 = loR0; loIdx1 = loIdx0; loR0 = r; loIdx0 = i; }
            else if (r < loR1) { loR1 = r; loIdx1 = i; }
        }
        _aHand[loIdx0] = _deck[_deckTop]; _deckTop++;
        _aHand[loIdx1] = _deck[_deckTop]; _deckTop++;
    }

    // ── Hand evaluation ───────────────────────────────────────────────────────
    // Returns integer score: higher = better hand.
    // Encodes hand type × 10^8 + kicker info.
    hidden function evalHand(hand) {
        var ranks = new [13];
        var suits = new [4];
        for (var i = 0; i < 13; i++) { ranks[i] = 0; }
        for (var i = 0; i < 4;  i++) { suits[i] = 0; }
        var rs = new [5]; // rank of each card
        for (var i = 0; i < 5; i++) {
            rs[i] = hand[i] / 4;
            ranks[rs[i]]++;
            suits[hand[i] % 4]++;
        }

        // Sort rs descending (bubble)
        for (var i = 0; i < 4; i++) {
            for (var j = i+1; j < 5; j++) {
                if (rs[j] > rs[i]) { var t = rs[i]; rs[i] = rs[j]; rs[j] = t; }
            }
        }

        var isFlush = false;
        for (var i = 0; i < 4; i++) { if (suits[i] == 5) { isFlush = true; } }

        var isStraight = false;
        if (rs[0] - rs[4] == 4 && ranks[rs[0]] == 1) { isStraight = true; }
        // Wheel: A-2-3-4-5
        if (rs[0] == 12 && rs[1] == 3 && rs[2] == 2 && rs[3] == 1 && rs[4] == 0) {
            isStraight = true; rs[0] = -1; // ace low
            for (var i = 0; i < 4; i++) { for (var j = i+1; j < 5; j++) { if (rs[j]>rs[i]){var t=rs[i];rs[i]=rs[j];rs[j]=t;} } }
        }

        var pairs = 0; var trips = 0; var quads = 0;
        for (var i = 0; i < 13; i++) {
            if (ranks[i] == 2) { pairs++; }
            if (ranks[i] == 3) { trips++; }
            if (ranks[i] == 4) { quads++; }
        }

        var handType = 0;
        if (isFlush && isStraight) {
            handType = (rs[0] == 12) ? 9 : 8; // royal or straight flush
        } else if (quads > 0)            { handType = 7; }
        else if (trips > 0 && pairs > 0) { handType = 6; }
        else if (isFlush)                { handType = 5; }
        else if (isStraight)             { handType = 4; }
        else if (trips > 0)              { handType = 3; }
        else if (pairs >= 2)             { handType = 2; }
        else if (pairs == 1)             { handType = 1; }
        else                             { handType = 0; }

        // Kicker: pack top 5 ranks into score
        var score = handType * 100000;
        score += rs[0] * 1000 + rs[1] * 100 + rs[2] * 10 + rs[3];
        return score;
    }

    hidden function handName(hand) {
        var score = evalHand(hand);
        var ht = score / 100000;
        if (ht < 0) { ht = 0; }
        if (ht >= _handNames.size()) { ht = _handNames.size() - 1; }
        return _handNames[ht];
    }

    // ── Rendering ─────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeo(); }
        if (_gs == PS_MENU) { drawMenu(dc); return; }
        drawBackground(dc);
        drawAIHand(dc);
        drawPlayerHand(dc);
        drawMiddle(dc);
        if (_gs == PS_GAMEOVER) { drawGameOver(dc); }
    }

    // ── Background ────────────────────────────────────────────────────────────
    hidden function drawBackground(dc) {
        dc.setColor(0x050C08, 0x050C08); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0B3018, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);
        dc.setColor(0x0E3C20, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 14);
    }

    // ── Menu ─────────────────────────────────────────────────────────────────
    hidden function drawMenu(dc) {
        dc.setColor(0x050C08, 0x050C08); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0B3018, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);
        dc.setColor(0x0E3C20, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 14);

        // Sample cards
        var sampleCards = [48, 35, 26, 13, 4]; // some face cards
        for (var i = 0; i < 5; i++) {
            var cx = _startX + i * (_cw + _gap);
            var cy = _h * 28 / 100;
            drawCard(dc, cx, cy, _cw, _ch, sampleCards[i % 4 + i * 3 % 5 < 52 ? i : 0], false, false);
        }

        dc.setColor(0xFFCC55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 50 / 100, Graphics.FONT_MEDIUM, "POKER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x4A8040, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 62 / 100, Graphics.FONT_XTINY, "5-Card Draw", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x336644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 72 / 100, Graphics.FONT_XTINY, "Exchange up to 2 cards", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick%10<5)?0xFFCC55:0xAA8833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 85 / 100, Graphics.FONT_XTINY, "Tap to deal!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── AI hand (top) ─────────────────────────────────────────────────────────
    hidden function drawAIHand(dc) {
        var showCards = (_gs == PS_SHOWDOWN);
        for (var i = 0; i < 5; i++) {
            var cx = _startX + i * (_cw + _gap);
            drawCard(dc, cx, _aHandY, _cw, _ch, _aHand[i], showCards, false);
        }
        // AI label / hand name
        var lbl = (_gs == PS_SHOWDOWN) ? handName(_aHand) : "Dealer";
        dc.setColor(showCards ? 0xFFDD88 : 0x558866, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _aHandY + _ch + 3, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Player hand (bottom) ──────────────────────────────────────────────────
    hidden function drawPlayerHand(dc) {
        var showCards = true; // player always sees own cards
        for (var i = 0; i < 5; i++) {
            var cx = _startX + i * (_cw + _gap);
            var isDiscard  = _discard[i];
            var isCursor   = (_gs == PS_EXCHANGE && i == _curCard);
            drawCard(dc, cx, _pHandY, _cw, _ch, _pHand[i], showCards, isDiscard);

            if (isCursor) {
                dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(cx - 2, _pHandY - 2, _cw + 4, _ch + 4, 3);
            }
            if (isDiscard) {
                // X mark
                dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(cx + 2, _pHandY + 2, cx + _cw - 2, _pHandY + _ch - 2);
                dc.drawLine(cx + _cw - 2, _pHandY + 2, cx + 2, _pHandY + _ch - 2);
            }
        }
        // Player hand name at showdown
        if (_gs == PS_SHOWDOWN) {
            dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _pHandY - 14, Graphics.FONT_XTINY, handName(_pHand), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Middle area ───────────────────────────────────────────────────────────
    hidden function drawMiddle(dc) {
        var midY = _aHandY + _ch + 18;

        // Chips + pot
        dc.setColor(0x44CC88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 15 / 100, midY, Graphics.FONT_XTINY, "\u2665 " + _pChips, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        if (_pot > 0) {
            dc.drawText(_w / 2, midY, Graphics.FONT_XTINY, "POT " + _pot, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xFF8866, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 85 / 100, midY, Graphics.FONT_XTINY, _aChips + " \u2660", Graphics.TEXT_JUSTIFY_RIGHT);

        var btnY  = _h * 53 / 100;
        var btnW  = _w * 50 / 100;
        var btnH  = 24;
        var btnX  = (_w - btnW) / 2;

        if (_gs == PS_EXCHANGE) {
            var cnt = 0;
            for (var i = 0; i < 5; i++) { if (_discard[i]) { cnt++; } }

            // Instructions
            dc.setColor(0x88BBAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, btnY - 22, Graphics.FONT_XTINY,
                "Tap card to discard (" + cnt + "/" + MAX_DISCARD + ")",
                Graphics.TEXT_JUSTIFY_CENTER);

            // DEAL button
            dc.setColor(0x112A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(btnX, btnY, btnW, btnH, 5);
            dc.setColor(0x33AA55, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(btnX, btnY, btnW, btnH, 5);
            dc.setColor(0x66FF99, Graphics.COLOR_TRANSPARENT);
            var lbl = (cnt == 0) ? "Stand Pat" : "Draw " + cnt;
            dc.drawText(_w / 2, btnY + 4, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);

        } else if (_gs == PS_AI_DRAW) {
            var dots = "";
            for (var i = 0; i < (_tick % 4); i++) { dots = dots + "."; }
            dc.setColor(0x88BBAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, btnY, Graphics.FONT_XTINY, "Dealer draws" + dots, Graphics.TEXT_JUSTIFY_CENTER);

        } else if (_gs == PS_SHOWDOWN) {
            // Result message
            var clr = 0xFFFFFF;
            if (_resultMsg.equals("YOU WIN!"))  { clr = 0x44FF88; }
            if (_resultMsg.equals("YOU LOSE"))  { clr = 0xFF5544; }
            if (_resultMsg.equals("SPLIT POT")) { clr = 0xFFDD44; }

            dc.setColor(0x081A10, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(btnX, btnY - 4, btnW, btnH + 8, 6);
            dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(btnX, btnY - 4, btnW, btnH + 8, 6);
            dc.drawText(_w / 2, btnY + 2, Graphics.FONT_XTINY, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor((_tick%10<5)?0x88CCFF:0x4488AA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, btnY + btnH + 10, Graphics.FONT_XTINY, "Tap \u25BA next hand", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Game over ─────────────────────────────────────────────────────────────
    hidden function drawGameOver(dc) {
        var bankrupt = (_pChips <= 0) ? "YOU'RE BROKE!" : "DEALER BROKE!";
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w/2 - 70, _h/2 - 32, 140, 64, 8);
        dc.setColor(0x334422, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_w/2 - 70, _h/2 - 32, 140, 64, 8);
        dc.setColor(_pChips <= 0 ? 0xFF5544 : 0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 28, Graphics.FONT_MEDIUM, bankrupt, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick%10<5)?0x88CCFF:0x4466AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 + 8, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Card drawing ─────────────────────────────────────────────────────────
    hidden function drawCard(dc, x, y, w, h, card, faceUp, dimmed) {
        if (!faceUp) {
            // Face-down: navy with diagonal pattern
            dc.setColor(dimmed ? 0x101830 : 0x1C2F9A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, h, 2);
            dc.setColor(0x2A44C0, Graphics.COLOR_TRANSPARENT);
            var step = (w > 14) ? 5 : 4;
            for (var d = -h; d < w + h; d += step) {
                dc.drawLine(x + d, y, x + d + h, y + h);
            }
            dc.setColor(0x4A64D8, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, 2);
            return;
        }

        var rank  = card / 4;
        var suit  = card % 4;
        var isRed = (suit == 1 || suit == 2);

        // Card body
        var bgClr = dimmed ? 0xCCCCBB : 0xF5F5EE;
        dc.setColor(bgClr, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 2);
        // Border — colour matches suit
        dc.setColor(isRed ? 0xBB3333 : 0x334466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 2);

        var tc = isRed ? 0xCC0000 : 0x111122;
        if (dimmed) { tc = isRed ? 0x993333 : 0x444466; }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);

        // Rank top-left
        dc.drawText(x + 2, y + 1, Graphics.FONT_XTINY, _rankStr[rank], Graphics.TEXT_JUSTIFY_LEFT);
        // Suit below rank
        dc.drawText(x + 2, y + 9, Graphics.FONT_XTINY, _suitStr[suit], Graphics.TEXT_JUSTIFY_LEFT);
        // Large suit in centre (when card is tall enough)
        if (h >= 30) {
            dc.drawText(x + w / 2, y + h / 2 - 6, Graphics.FONT_XTINY, _suitStr[suit], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
