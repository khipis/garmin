using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Makao Lite ────────────────────────────────────────────────────────────
//
// Card encoding:  v = suit * 13 + rank  (0..51)
//   suit: 0=H(Hearts)  1=D(Diamonds)  2=C(Clubs)  3=S(Spades)
//   rank: 0=2  1=3  2=4  3=5  4=6  5=7  6=8  7=9  8=10  9=J  10=Q  11=K  12=A
//
// Special cards:
//   2  (rank 0)  → opponent draws 2 (stackable: 2+2=4, 2+3=5, etc.)
//   3  (rank 1)  → opponent draws 3 (stackable)
//   J  (rank 9)  → opponent skips next turn
//   A  (rank 12) → player chooses active suit for the next card

const MK_DECK  = 52;
const MK_SUITS = 4;
const MK_RANKS = 13;

const MK_R2 = 0;    // rank index for "2"
const MK_R3 = 1;    // rank index for "3"
const MK_RJ = 9;    // rank index for "J"
const MK_RA = 12;   // rank index for "A"

// Game states
const MKS_PLAY = 0;  // player's turn
const MKS_SUIT = 1;  // player played Ace — picking suit
const MKS_AI   = 2;  // AI's turn (timer-driven)
const MKS_OVER = 3;

// Pre-game menu
const GS_MENU   = 10;
const MODE_PVAI = 0;
const MODE_PVP  = 1;
const MODE_AIAI = 2;
const DIFF_EASY = 0;
const DIFF_MED  = 1;
const DIFF_HARD = 2;

const MKO_PWIN  = 1;
const MKO_AIWIN = 2;

// ── GameView ──────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // ── Layout ────────────────────────────────────────────────────────────
    hidden var _sw, _sh;
    hidden var _cardW, _cardH;   // small card in hand strip
    hidden var _bigW,  _bigH;    // large top card in play area
    hidden var _handY;           // y-start of the hand strip
    hidden var _visCrds;         // max scrollable cards visible (excl. DRAW btn)

    // ── Deck / hands — pre-allocated, zero runtime allocation ─────────────
    // _deck[52]:   shuffled card values
    // _pHand[52]:  player's hand  (_pCount cards valid)
    // _aiHand[52]: AI's hand      (_aiCount cards valid)
    hidden var _deck;
    hidden var _pHand;
    hidden var _aiHand;
    hidden var _pCount;
    hidden var _aiCount;
    hidden var _deckTop;         // index of next card to deal from _deck
    hidden var _tmpSuits;        // int[4]  scratch for AI suit counting

    // ── Game state ────────────────────────────────────────────────────────
    hidden var _topCard;         // current top of discard pile
    hidden var _activeSuit;      // 0-3  required suit (may differ from _topCard's suit after Ace)
    hidden var _pendingDraw;     // accumulated forced-draw count (from 2/3 chain)
    hidden var _skipNext;        // true = whoever moves next is skipped

    // ── UI state ──────────────────────────────────────────────────────────
    hidden var _state;
    hidden var _suitPick;        // 0-3  highlighted in suit picker
    hidden var _cursorPos;       // 0.._pCount  (inclusive; _pCount = DRAW button)
    hidden var _scrollOff;       // first visible card index in hand strip

    // ── Menu state ────────────────────────────────────────────────────────
    hidden var _mode;
    hidden var _diff;
    hidden var _menuSel;

    // ── Session ───────────────────────────────────────────────────────────
    hidden var _overWho;
    hidden var _sP, _sAI;
    hidden var _timer;

    // ─────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _deck     = new [MK_DECK];
        _pHand    = new [MK_DECK];
        _aiHand   = new [MK_DECK];
        _tmpSuits = new [MK_SUITS];
        _sP  = 0;
        _sAI = 0;
        _timer = null;
        _startGame();
        _state   = GS_MENU;
        _mode    = MODE_PVAI;
        _diff    = DIFF_MED;
        _menuSel = 0;
    }

    function onLayout(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();

        // ── Play area cards — further 10% reduction ───────────────────────
        _bigH = _sh * 23 / 100;
        if (_bigH < 47) { _bigH = 47; }
        if (_bigH > 61) { _bigH = 61; }
        _bigW = _bigH * 65 / 100;

        // ── Hand strip — centered at 62%, giving room to turn label above ────
        _handY = _sh * 62 / 100;
        _cardH = _sh * 16 / 100;
        if (_cardH < 30) { _cardH = 30; }
        if (_cardH > 42) { _cardH = 42; }
        _cardW = _cardH * 65 / 100;
        if (_cardW < 20) { _cardW = 20; }
        if (_cardW > 28) { _cardW = 28; }

        // Show all cards without scrolling (dynamic width computed per draw)
        _visCrds = 20;

        _timer = new Timer.Timer();
        _timer.start(method(:gameTick), 650, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Public input API ──────────────────────────────────────────────────
    // dir: 0=UP  1=DOWN  2=LEFT  3=RIGHT
    function navigate(dir) {
        if (_state == GS_MENU) {
            if (dir == 0 || dir == 2) { _menuSel = (_menuSel + 2) % 3; }
            else if (dir == 1 || dir == 3) { _menuSel = (_menuSel + 1) % 3; }
            WatchUi.requestUpdate();
            return;
        }
        if (_state == MKS_AI || _state == MKS_OVER) { return; }
        if (_skipNext) { return; }
        if (_state == MKS_SUIT) {
            if      (dir == 2) { _suitPick = (_suitPick + 3) % MK_SUITS; }
            else if (dir == 3) { _suitPick = (_suitPick + 1) % MK_SUITS; }
            return;
        }
        // Wrapping navigation: left/right cycle through all cards + DRAW button
        if (dir == 2) {
            _cursorPos = (_cursorPos > 0) ? _cursorPos - 1 : _pCount;
        } else if (dir == 3) {
            _cursorPos = (_cursorPos < _pCount) ? _cursorPos + 1 : 0;
        }
    }

    // BACK: menu → pop app, in-game → return to menu
    function doBack() {
        if (_state == GS_MENU) { return false; }
        _state = GS_MENU; _menuSel = 0;
        return true;
    }

    function doAction() {
        if (_state == GS_MENU) {
            if (_menuSel == 0) { _mode = (_mode + 1) % 3; }
            else if (_menuSel == 1 && _mode != MODE_PVP) { _diff = (_diff + 1) % 3; }
            else if (_menuSel == 2) {
                _startGame();
                if (_mode == MODE_AIAI) { _state = MKS_AI; }
            }
            WatchUi.requestUpdate();
            return;
        }
        if (_state == MKS_OVER) { _state = GS_MENU; _menuSel = 0; WatchUi.requestUpdate(); return; }
        if (_state == MKS_AI && _mode != MODE_PVP) { return; }
        if (_skipNext) { return; }
        if (_state == MKS_SUIT) {
            _activeSuit = _suitPick;
            _state = MKS_AI;
            return;
        }
        // MKS_PLAY
        if (_cursorPos == _pCount) {
            _playerDraw();
        } else {
            var card = _pHand[_cursorPos];
            if (_isValid(card)) { _playerPlay(_cursorPos); }
        }
    }

    // ── Timer ─────────────────────────────────────────────────────────────
    function gameTick() as Void {
        if (_state == MKS_AI) {
            if (_mode == MODE_PVP) {
                // PvP: P2 auto-plays (practical on a watch — same AI logic, P2 label)
                if (_skipNext) { _skipNext = false; _state = MKS_PLAY; }
                else { _aiDoTurn(); }
            } else if (_skipNext) {
                _skipNext = false;
                _state = MKS_PLAY;
            } else {
                _aiDoTurn();
            }
            WatchUi.requestUpdate();
        } else if (_state == MKS_PLAY && _skipNext) {
            _skipNext = false;
            _state = MKS_AI;
            WatchUi.requestUpdate();
        } else if (_state == MKS_PLAY && _mode == MODE_AIAI) {
            _aiPlayForPlayer();
            WatchUi.requestUpdate();
        }
    }

    // ── Game management ───────────────────────────────────────────────────
    hidden function _startGame() {
        _shuffle();
        _deckTop = 0;
        // Deal 5 cards to each player
        var i = 0;
        while (i < 5) { _pHand[i]  = _deck[_deckTop]; _deckTop++; i++; }
        _pCount = 5;
        i = 0;
        while (i < 5) { _aiHand[i] = _deck[_deckTop]; _deckTop++; i++; }
        _aiCount = 5;
        // Starting top card
        _topCard    = _deck[_deckTop]; _deckTop++;
        _activeSuit = _topCard / MK_RANKS;
        _pendingDraw = 0;
        _skipNext    = false;
        // Handle special starting cards
        var r = _topCard % MK_RANKS;
        if (r == MK_R2) { _pendingDraw = 2; }
        if (r == MK_R3) { _pendingDraw = 3; }
        if (r == MK_RJ) { _skipNext = true; }
        if (r == MK_RA) { _activeSuit = Math.rand() % MK_SUITS; }
        _state     = MKS_PLAY;
        _cursorPos = 0;
        _scrollOff = 0;
        _suitPick  = 0;
        _overWho   = 0;
    }

    // Fisher-Yates shuffle in-place on _deck.
    hidden function _shuffle() {
        var i = 0;
        while (i < MK_DECK) { _deck[i] = i; i++; }
        i = MK_DECK - 1;
        while (i > 0) {
            var j = Math.rand() % (i + 1);
            var t = _deck[i]; _deck[i] = _deck[j]; _deck[j] = t;
            i--;
        }
    }

    // ── Card helpers ──────────────────────────────────────────────────────
    // A card is valid when:
    //   - pendingDraw > 0 → only another 2 or 3 (counter to chain)
    //   - otherwise      → same rank as top card OR same suit as _activeSuit
    hidden function _isValid(card) {
        var rank = card % MK_RANKS;
        if (_pendingDraw > 0) { return (rank == MK_R2 || rank == MK_R3); }
        return (rank == (_topCard % MK_RANKS)) || ((card / MK_RANKS) == _activeSuit);
    }

    // Draw n cards for owner 1=player or 2=AI from the deck.
    hidden function _drawN(who, n) {
        var i = 0;
        while (i < n && _deckTop < MK_DECK) {
            var card = _deck[_deckTop]; _deckTop++;
            if (who == 1 && _pCount  < MK_DECK) { _pHand [_pCount ] = card; _pCount++;  }
            if (who == 2 && _aiCount < MK_DECK) { _aiHand[_aiCount] = card; _aiCount++; }
            i++;
        }
    }

    // Core card-play: remove card at idx from hand (shift left), update game state.
    // Caller MUST decrement the relevant hand count after calling.
    // Returns rank of the played card.
    hidden function _doPlay(hand, count, idx) {
        var card = hand[idx];
        var rank = card % MK_RANKS;
        var suit = card / MK_RANKS;
        var i = idx;
        while (i < count - 1) { hand[i] = hand[i + 1]; i++; }
        // Update board
        _topCard = card;
        var oldPend  = _pendingDraw;
        _pendingDraw = 0;
        _skipNext    = false;
        _activeSuit  = suit;
        if (rank == MK_R2) { _pendingDraw = oldPend + 2; }
        if (rank == MK_R3) { _pendingDraw = oldPend + 3; }
        if (rank == MK_RJ) { _skipNext = true; }
        // Ace: _activeSuit will be overwritten by caller (suit picker / aiBestSuit)
        return rank;
    }

    // ── Player actions ────────────────────────────────────────────────────
    hidden function _playerPlay(idx) {
        var rank = _doPlay(_pHand, _pCount, idx);
        _pCount--;
        // Win check first
        if (_pCount == 0) { _overWho = MKO_PWIN; _sP = _sP + 1; _state = MKS_OVER; return; }
        // Cursor / scroll bounds
        if (_cursorPos > _pCount) { _cursorPos = _pCount; }
        if (_scrollOff > 0 && _scrollOff >= _pCount) { _scrollOff = _pCount - 1; }
        if (_scrollOff < 0) { _scrollOff = 0; }
        // Ace → suit picker
        if (rank == MK_RA) { _suitPick = _activeSuit; _state = MKS_SUIT; return; }
        _state = MKS_AI;
    }

    // Player draws card(s) — always ends player turn.
    hidden function _playerDraw() {
        if (_pendingDraw > 0) {
            _drawN(1, _pendingDraw);
            _pendingDraw = 0;
        } else {
            _drawN(1, 1);
        }
        _state = MKS_AI;
    }

    // ── AI logic ──────────────────────────────────────────────────────────
    //
    // Priority order: Jack (skip) > 2 (draw 2) > 3 (draw 3) > Ace > regular.
    // When forced draw is active, counter with 2 or 3 if available, else draw all.
    // After drawing 1 card, play it immediately if valid.

    hidden function _aiDoTurn() {
        // Forced draw?
        if (_pendingDraw > 0) {
            var ci = _aiFindCounter();
            if (ci >= 0) {
                var rank = _doPlay(_aiHand, _aiCount, ci);
                _aiCount--;
                if (_aiCount == 0) { _overWho = MKO_AIWIN; _sAI = _sAI + 1; _state = MKS_OVER; return; }
                // _pendingDraw now higher; player's turn (may be skipped if J somehow)
                _state = MKS_PLAY;
            } else {
                _drawN(2, _pendingDraw);
                _pendingDraw = 0;
                _state = MKS_PLAY;
            }
            return;
        }

        // Normal play
        var ci = _aiPickCard();
        if (ci >= 0) {
            var rank = _doPlay(_aiHand, _aiCount, ci);
            _aiCount--;
            if (_aiCount == 0) { _overWho = MKO_AIWIN; _sAI = _sAI + 1; _state = MKS_OVER; return; }
            if (rank == MK_RA) { _activeSuit = _aiBestSuit(); }
            // _skipNext set by _doPlay for Jack; timer handles player skip
            _state = MKS_PLAY;
        } else {
            // Draw 1 card, then play it if valid
            if (_deckTop < MK_DECK) {
                _drawN(2, 1);
                var drawn = _aiHand[_aiCount - 1];
                if (_isValid(drawn)) {
                    var rank = _doPlay(_aiHand, _aiCount, _aiCount - 1);
                    _aiCount--;
                    if (_aiCount == 0) { _overWho = MKO_AIWIN; _sAI = _sAI + 1; _state = MKS_OVER; return; }
                    if (rank == MK_RA) { _activeSuit = _aiBestSuit(); }
                }
            }
            _state = MKS_PLAY;
        }
    }

    // Return index of any 2 or 3 in AI hand, or −1.
    hidden function _aiFindCounter() {
        var i = 0;
        while (i < _aiCount) {
            var r = _aiHand[i] % MK_RANKS;
            if (r == MK_R2 || r == MK_R3) { return i; }
            i++;
        }
        return -1;
    }

    // Return index of best card for AI to play, or −1.
    hidden function _aiPickCard() {
        if (_diff == DIFF_EASY && Math.rand() % 3 == 0) {
            var j = 0;
            while (j < _aiCount) { if (_isValid(_aiHand[j])) { return j; } j++; }
            return -1;
        }
        var bestIdx = -1; var bestPri = -1;
        var topRank = _topCard % MK_RANKS;
        var i = 0;
        while (i < _aiCount) {
            if (_isValid(_aiHand[i])) {
                var r   = _aiHand[i] % MK_RANKS;
                var pri = 0;
                if (r == MK_RJ) {
                    // Scale priority by endgame state (Med/Hard)
                    if (_diff >= DIFF_MED) {
                        pri = 40 - _aiCount * 2;
                        if (pri < 5)  { pri = 5; }
                        if (pri > 40) { pri = 40; }
                    } else {
                        pri = 40;
                    }
                    // Hard: if 1 card left, prefer winning outright over skipping
                    if (_diff == DIFF_HARD && _aiCount == 1) { pri = 5; }
                } else if (r == MK_R2) {
                    pri = 30;
                    // Endgame defence: force opponent to draw when they're close to winning
                    if (_diff >= DIFF_MED && _pCount <= 2) { pri = 45; }
                } else if (r == MK_R3) {
                    pri = 25;
                    if (_diff >= DIFF_MED && _pCount <= 2) { pri = 42; }
                } else if (r == MK_RA) {
                    pri = 20;
                } else {
                    // Regular card: prefer rank match (keeps suit pressure) over suit-only
                    if (r == topRank) { pri = 15; }
                    else              { pri = 10; }
                    // Endgame: boost regular cards when AI is close to winning
                    if (_diff == DIFF_HARD && _aiCount <= 2) { pri = pri + 15; }
                }
                if (_diff == DIFF_EASY) { pri = pri + Math.rand() % 50; }
                if (pri > bestPri) { bestPri = pri; bestIdx = i; }
            }
            i++;
        }
        return bestIdx;
    }

    // Return the best suit for AI to declare when playing an Ace.
    // Picks the suit AI holds most of, with a penalty for the opponent's
    // previously-declared suit (if top card is an Ace, opponent changed to
    // _activeSuit — they likely have cards of that suit, so avoid it).
    hidden function _aiBestSuit() {
        var i = 0;
        while (i < MK_SUITS) { _tmpSuits[i] = 0; i++; }
        i = 0;
        while (i < _aiCount) {
            var s = _aiHand[i] / MK_RANKS;
            _tmpSuits[s] = _tmpSuits[s] + 1;
            i++;
        }
        // If the top card was an Ace (opponent chose _activeSuit), penalise that
        // suit so we change away from what the opponent wants us to play.
        var avoidSuit = -1;
        if (_diff >= DIFF_MED && (_topCard % MK_RANKS) == MK_RA) {
            avoidSuit = _activeSuit;
        }
        var best = 0; var bestC = -999;
        i = 0;
        while (i < MK_SUITS) {
            var cnt = _tmpSuits[i];
            if (i == avoidSuit) { cnt = cnt - 3; }
            if (cnt > bestC) { bestC = cnt; best = i; }
            i++;
        }
        return best;
    }

    // ── Rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_state == GS_MENU) { _drawMenu(dc); return; }
        dc.setColor(0x0B1E0F, 0x0B1E0F);   // dark card-table green
        dc.clear();
        _drawAIArea(dc);
        _drawPlayArea(dc);
        _drawHand(dc);
        if (_state == MKS_SUIT) { _drawSuitPicker(dc); }
        if (_state == MKS_OVER) { _drawOver(dc); }
    }

    // ── Top strip: AI info + card fan ────────────────────────────────────
    hidden function _drawAIArea(dc) {
        // Session wins at top corners
        dc.setColor(0xFF3300, Graphics.COLOR_TRANSPARENT);
        dc.drawText(6, 2, Graphics.FONT_XTINY, "W:" + _sP.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x2299FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw - 6, 2, Graphics.FONT_XTINY, _sAI.format("%d") + ":W",
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // AI hand fan — overlapping mini card backs, centered
        var n    = _aiCount;
        var mw   = 17;   // mini card width
        var mh   = 25;   // mini card height
        var fanY = 16;
        if (n > 0) {
            var shift = mw - 8;                        // 5 px per extra card
            var fanW  = mw + (n - 1) * shift;
            if (fanW > 100) {                          // compress if too wide
                shift = (100 - mw) / (n - 1);
                if (shift < 2) { shift = 2; }
                fanW  = mw + (n - 1) * shift;
            }
            var fx = _sw / 2 - fanW / 2;
            var i  = 0;
            while (i < n) {
                var cx = fx + i * shift;
                dc.setColor(0x1A3A7A, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx, fanY, mw, mh, 2);
                dc.setColor(0x3A6ACA, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(cx, fanY, mw, mh, 2);
                i++;
            }
        }

        // Card count label to the right of (or below) the fan
        var oppLbl = (_mode == MODE_PVP) ? "P2" : "AI";
        var cntTxt = oppLbl + ":" + _aiCount.format("%d");
        if (_state == MKS_AI) { cntTxt = cntTxt + ".."; }
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, fanY + mh + 1, Graphics.FONT_XTINY,
                    cntTxt, Graphics.TEXT_JUSTIFY_CENTER);

        // Skip banner
        if (_state == MKS_PLAY && _skipNext) {
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, fanY + mh + 13, Graphics.FONT_XTINY,
                        "SKIPPED!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Main play area: deck + top card ───────────────────────────────────
    hidden function _drawPlayArea(dc) {
        // Start below AI fan area (fan bottom ≈ 35px + count label ≈ 48px)
        var bigY = _sh * 23 / 100;
        if (bigY < 48) { bigY = 48; }

        // Deck (card back) — left of center
        var deckX = _sw / 2 - _bigW - 6;
        if (deckX < 4) { deckX = 4; }
        _drawBack(dc, deckX, bigY, _bigW, _bigH);
        var rem = MK_DECK - _deckTop;
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(deckX - 3, bigY + _bigH / 2,
                    Graphics.FONT_XTINY, rem.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Top card (face up) — right of center
        var tcX = _sw / 2 + 6;
        if (tcX + _bigW > _sw - 2) { tcX = _sw - _bigW - 2; }
        _drCard(dc, tcX, bigY, _bigW, _bigH, _topCard, true);
        // Active suit or skip indicator — to the RIGHT of the discard pile
        var infoX = tcX + _bigW + 3;
        if ((_topCard % MK_RANKS) == MK_RA) {
            dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(infoX, bigY + _bigH / 2,
                        Graphics.FONT_XTINY, _suitStr(_activeSuit),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (_skipNext) {
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(infoX, bigY + _bigH / 2,
                        Graphics.FONT_XTINY, "SKP",
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Pending-draw warning — center between the two cards
        if (_pendingDraw > 0) {
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, bigY + _bigH / 2 - 4, Graphics.FONT_XTINY,
                        "+" + _pendingDraw.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Turn label — fixed at midpoint between play area bottom and hand strip
        // Drawn with a dark pill background so it's always readable
        var lblY = bigY + _bigH + (_handY - bigY - _bigH) / 2 - 8;
        var lbl  = "";
        var lblC = 0x55FF77;
        if (_state == MKS_PLAY && !_skipNext) {
            lbl  = (_mode == MODE_PVP) ? "YOUR TURN  P1" : "YOUR TURN";
            lblC = 0x55FF77;
        } else if (_state == MKS_AI) {
            lbl  = (_mode == MODE_PVP) ? "P2 TURN" : "AI TURN";
            lblC = 0x5599EE;
        }
        if (lbl.length() > 0) {
            // Dark pill background for contrast
            var pw = lbl.length() * 5 + 14;
            var ph = 14;
            dc.setColor(0x060F06, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(_sw / 2 - pw / 2, lblY - 1, pw, ph, 4);
            dc.setColor(lblC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, lblY, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Card back ─────────────────────────────────────────────────────────
    hidden function _drawBack(dc, x, y, w, h) {
        dc.setColor(0x1A3A7A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 4);
        dc.setColor(0x2A5ABB, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x + 2, y + 2, w - 4, h - 4, 3);
        dc.setColor(0x3A6ACA, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x + 5, y + 5, w - 10, h - 10, 2);
        dc.setColor(0x1A3A7A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 4);
    }

    // ── Graphical card face (ported from Solitaire) ───────────────────────
    // valid=false → grey background to indicate unplayable card
    hidden function _drCard(dc, x, y, cw, ch, card, valid) {
        var rank  = card % MK_RANKS;
        var suit  = card / MK_RANKS;
        var isRed = (suit == 0 || suit == 1);
        var tc    = isRed ? 0xCC1111 : 0x111111;

        // Background
        var bg = valid ? 0xFCFAF6 : 0x888888;
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, cw, ch, 2);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, cw, ch, 2);

        // Rank label top-left
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 2, y + 1, Graphics.FONT_XTINY, _rankStr(rank), Graphics.TEXT_JUSTIFY_LEFT);

        // Small suit symbol top-right
        var miniS = cw * 15 / 100; if (miniS < 3) { miniS = 3; }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        _drSuit(dc, x + cw - miniS - 3, y + miniS + 3, suit, miniS);

        // Large suit symbol in centre
        var ss = cw * 3 / 10; if (ss < 3) { ss = 3; }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        _drSuit(dc, x + cw / 2, y + ch / 2 + 2, suit, ss);
    }

    // ── Suit symbol (graphical polygons/circles) ──────────────────────────
    // Makao suit encoding: 0=Hearts  1=Diamonds  2=Clubs  3=Spades
    hidden function _drSuit(dc, cx, cy, suit, s) {
        if (s < 2) { s = 2; }
        var r = s * 5 / 10; if (r < 2) { r = 2; }
        if (suit == 0) {
            // Hearts: two circles + downward triangle
            dc.fillCircle(cx - r + 1, cy - s / 4, r);
            dc.fillCircle(cx + r - 1, cy - s / 4, r);
            dc.fillPolygon([[cx - s, cy - s / 6], [cx, cy + s], [cx + s, cy - s / 6]]);
        } else if (suit == 1) {
            // Diamonds: rotated square
            dc.fillPolygon([[cx, cy - s], [cx + s * 6 / 10, cy],
                            [cx, cy + s], [cx - s * 6 / 10, cy]]);
        } else if (suit == 2) {
            // Clubs: three circles + stem
            dc.fillCircle(cx, cy - s * 4 / 10, r);
            dc.fillCircle(cx - s * 4 / 10, cy + s / 5, r);
            dc.fillCircle(cx + s * 4 / 10, cy + s / 5, r);
            dc.fillRectangle(cx - 1, cy + s / 3, 3, s * 4 / 10);
        } else {
            // Spades: inverted triangle + two side circles + stem
            dc.fillPolygon([[cx, cy - s], [cx - s, cy + s / 4], [cx + s, cy + s / 4]]);
            dc.fillCircle(cx - r + 1, cy + s / 6, r);
            dc.fillCircle(cx + r - 1, cy + s / 6, r);
            dc.fillRectangle(cx - 1, cy + s / 3, 3, s * 4 / 10);
        }
    }

    // ── Player hand strip — all cards visible, dynamic width ─────────────
    hidden function _drawHand(dc) {
        var slots  = _pCount + 1;
        var gap    = 3;
        var safeW  = _sw * 86 / 100;
        var cw     = (safeW - (slots - 1) * gap) / slots;
        if (cw > _cardW) { cw = _cardW; }
        if (cw < 10)     { cw = 10; }
        var ch = cw * 150 / 100;

        var totalW = slots * cw + (slots - 1) * gap;
        var startX = (_sw - totalW) / 2;
        if (startX < 2) { startX = 2; }

        // When cards are small (many in hand), selected card also grows.
        // Enlarge by ~30% when more than 5 cards in hand.
        var selCw = cw;
        var selCh = ch;
        if (_pCount > 5) {
            selCw = cw * 130 / 100;
            selCh = ch * 130 / 100;
        }

        // Pass 1 — draw all non-selected cards so selected card renders on top.
        var x   = startX;
        var idx = 0;
        while (idx < _pCount) {
            if (idx != _cursorPos) {
                var card  = _pHand[idx];
                var valid = _isValid(card);
                _drCard(dc, x, _handY, cw, ch, card, valid);
                if (valid) {
                    dc.setColor(0x22EE55, Graphics.COLOR_TRANSPARENT);
                    dc.drawRoundedRectangle(x - 1, _handY - 1, cw + 2, ch + 2, 3);
                }
            }
            x  += cw + gap;
            idx++;
        }

        // Pass 2 — draw selected card (enlarged, lifted) on top.
        if (_cursorPos < _pCount) {
            var selX = startX + _cursorPos * (cw + gap);
            // Centre the enlarged card over its slot
            var offX = (selCw - cw) / 2;
            var liftY = 6 + (selCh - ch) / 2;
            var sx = selX - offX;
            var sy = _handY - liftY;
            _drCard(dc, sx, sy, selCw, selCh, _pHand[_cursorPos], _isValid(_pHand[_cursorPos]));
            dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(sx - 2, sy - 2, selCw + 4, selCh + 4, 4);
            dc.drawRoundedRectangle(sx - 1, sy - 1, selCw + 2, selCh + 2, 3);
        }

        // DRAW button — last slot
        var drawX   = startX + _pCount * (cw + gap);
        var drawSel = (_cursorPos == _pCount);
        dc.setColor(drawSel ? 0x225522 : 0x162614, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(drawX, _handY, cw, ch, 3);
        dc.setColor(drawSel ? 0x44FF44 : 0x336633, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(drawX, _handY, cw, ch, 3);
        if (drawSel) {
            dc.drawRoundedRectangle(drawX - 1, _handY - 1, cw + 2, ch + 2, 3);
        }
        dc.setColor(drawSel ? 0xAAFFAA : 0x55AA55, Graphics.COLOR_TRANSPARENT);
        var dlbl = (_pendingDraw > 0) ? ("+" + _pendingDraw.format("%d")) : "DR";
        dc.drawText(drawX + cw / 2, _handY + ch / 2 - 7,
                    Graphics.FONT_XTINY, dlbl, Graphics.TEXT_JUSTIFY_CENTER);

        // Card description label below hand strip.
        var descY = _handY + ch + 4;
        if (descY < _sh - 10) {
            var desc = "";
            if (_cursorPos < _pCount) {
                desc = _cardDesc(_pHand[_cursorPos]);
            } else {
                desc = (_pendingDraw > 0) ? "draw +" + _pendingDraw.format("%d") : "draw card";
            }
            dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, descY, Graphics.FONT_XTINY, desc, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Short description string for a card (rank+suit + effect hint).
    hidden function _cardDesc(card) {
        var rank = card % MK_RANKS;
        var suit = card / MK_RANKS;
        var rs   = _rankStr(rank) + _suitStr(suit);
        if (rank == MK_R2) { return rs + " +2"; }
        if (rank == MK_R3) { return rs + " +3"; }
        if (rank == MK_RJ) { return rs + " skip"; }
        if (rank == MK_RA) { return rs + " suit"; }
        return rs;
    }

    // ── Suit picker overlay ───────────────────────────────────────────────
    hidden function _drawSuitPicker(dc) {
        var bw = _sw * 72 / 100; var bh = 58;
        var ox = (_sw - bw) / 2;  var oy = _sh / 2 - 29;
        dc.setColor(0x0A1A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ox, oy, bw, bh, 8);
        dc.setColor(0x336633, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(ox, oy, bw, bh, 8);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, oy + 2, Graphics.FONT_XTINY,
                    "CHOOSE SUIT", Graphics.TEXT_JUSTIFY_CENTER);
        var slotW = bw / 4;
        var i = 0;
        while (i < 4) {
            var sx  = ox + i * slotW;
            var sel = (i == _suitPick);
            if (sel) {
                dc.setColor(0xFFEE00, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(sx + 2, oy + 16, slotW - 4, 28, 4);
            }
            dc.setColor((i < 2) ? 0xDD1100 : 0xBBBBBB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx + slotW / 2, oy + 22, Graphics.FONT_XTINY,
                        _suitStr(i), Graphics.TEXT_JUSTIFY_CENTER);
            i++;
        }
        dc.setColor(0x446644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, oy + bh - 11, Graphics.FONT_XTINY,
                    "◀ ▶ choose  SELECT ok", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game-over overlay ─────────────────────────────────────────────────
    hidden function _drawOver(dc) {
        var bw = _sw * 56 / 100; var bh = _sh * 30 / 100;
        if (bw < 150) { bw = 150; } if (bh < 90) { bh = 90; }
        var ox = _sw / 2 - bw / 2; var oy = _sh / 2 - bh / 2;
        dc.setColor(0x040408, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ox, oy, bw, bh, 10);
        dc.setColor(0x3A5A3A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(ox, oy, bw, bh, 10);
        var cx = _sw / 2;
        var msg = ""; var mc = 0xCCCCCC;
        if      (_overWho == MKO_PWIN)  { msg = (_mode == MODE_PVP) ? "P1 WIN!" : "YOU WIN!";  mc = 0xFF2200; }
        else if (_overWho == MKO_AIWIN) { msg = (_mode == MODE_PVP) ? "P2 WIN!" : "AI WINS!";  mc = 0x0099FF; }
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 8, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x556655, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + 38, Graphics.FONT_XTINY,
                    "W:" + _sP.format("%d") + "   " + _sAI.format("%d") + ":W",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x2A442A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, oy + bh - 14, Graphics.FONT_XTINY,
                    "SELECT = new game", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── String helpers ────────────────────────────────────────────────────
    hidden function _rankStr(r) {
        if (r == 0)  { return "2"; }
        if (r == 1)  { return "3"; }
        if (r == 2)  { return "4"; }
        if (r == 3)  { return "5"; }
        if (r == 4)  { return "6"; }
        if (r == 5)  { return "7"; }
        if (r == 6)  { return "8"; }
        if (r == 7)  { return "9"; }
        if (r == 8)  { return "10"; }
        if (r == 9)  { return "J"; }
        if (r == 10) { return "Q"; }
        if (r == 11) { return "K"; }
        return "A";
    }

    hidden function _suitStr(s) {
        if (s == 0) { return "H"; }
        if (s == 1) { return "D"; }
        if (s == 2) { return "C"; }
        return "S";
    }

    // ── Pre-game menu ─────────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        dc.setColor(0x050D05, 0x050D05); dc.clear();
        var hw = _sw / 2;
        dc.setColor(0x0A180A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hw, hw, hw - 1);
        dc.setColor(0x33AA33, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh * 11 / 100, Graphics.FONT_SMALL, "MAKAO LITE", Graphics.TEXT_JUSTIFY_CENTER);
        var modeStr = (_mode == MODE_PVAI) ? "P vs AI" : ((_mode == MODE_PVP) ? "P vs P" : "AI vs AI");
        var diffStr = (_diff == DIFF_EASY) ? "Easy" : ((_diff == DIFF_MED) ? "Med" : "Hard");
        var rows = ["Mode: " + modeStr, "Diff: " + diffStr, "START"];
        var nR = 3;
        var rowH = _sh * 10 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
        var rowW = _sw * 74 / 100; var rowX = (_sw - rowW) / 2;
        var gap = 6; var tot = nR * rowH + (nR - 1) * gap; var rowY0 = (_sh - tot) / 2 + rowH;
        var i = 0;
        while (i < nR) {
            var ry = rowY0 + i * (rowH + gap); var sel = (i == _menuSel); var isStart = (i == nR - 1);
            dc.setColor(sel ? (isStart ? 0x0A2A0A : 0x0A2040) : 0x050D05, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x33AA33 : 0x4499FF) : 0x1A2A1A, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                dc.setColor(isStart ? 0x33AA33 : 0x4499FF, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }
            var dimmed = (i == 1 && _mode == MODE_PVP);
            dc.setColor(dimmed ? 0x445566 : (sel ? (isStart ? 0xAAFFAA : 0xAADDFF) : 0x556677), Graphics.COLOR_TRANSPARENT);
            dc.drawText(hw, ry + (rowH - 14) / 2, Graphics.FONT_XTINY, rows[i], Graphics.TEXT_JUSTIFY_CENTER);
            i++;
        }
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hw, _sh - 14, Graphics.FONT_XTINY, "UP/DN sel  SELECT set/start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── AIvAI: AI plays as player (uses _pHand / _pCount) ────────────────
    hidden function _aiPlayForPlayer() {
        if (_pendingDraw > 0) {
            var i = 0;
            while (i < _pCount) {
                var r = _pHand[i] % MK_RANKS;
                if (r == MK_R2 || r == MK_R3) { _playerPlay(i); return; }
                i++;
            }
            _playerDraw();
            return;
        }
        if (_diff == DIFF_EASY && Math.rand() % 3 == 0) {
            var j = 0;
            while (j < _pCount) { if (_isValid(_pHand[j])) { _playerPlay(j); return; } j++; }
            _playerDraw();
            return;
        }
        var bestIdx = -1; var bestPri = -1;
        var i = 0;
        while (i < _pCount) {
            if (_isValid(_pHand[i])) {
                var r = _pHand[i] % MK_RANKS;
                var pri = 0;
                if      (r == MK_RJ) { pri = 40; }
                else if (r == MK_R2) { pri = 30; }
                else if (r == MK_R3) { pri = 25; }
                else if (r == MK_RA) { pri = 20; }
                else                 { pri = 10; }
                if (_diff == DIFF_HARD) { pri = pri * 2; }
                if (pri > bestPri) { bestPri = pri; bestIdx = i; }
            }
            i++;
        }
        if (bestIdx >= 0) {
            var rank = _pHand[bestIdx] % MK_RANKS;
            _playerPlay(bestIdx);
            if (rank == MK_RA && _state == MKS_SUIT) {
                _activeSuit = Math.rand() % MK_SUITS;
                _state = MKS_AI;
            }
        } else {
            _playerDraw();
        }
    }

    function doTap(tx, ty) {
        if (_state == GS_MENU) {
            var nR = 3;
            var rowH = _sh * 10 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
            var rowW = _sw * 74 / 100; var rowX = (_sw - rowW) / 2;
            var gap = 6; var tot = nR * rowH + (nR - 1) * gap; var rowY0 = (_sh - tot) / 2 + rowH;
            for (var i = 0; i < nR; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (tx >= rowX && tx < rowX + rowW && ty >= ry && ty < ry + rowH) {
                    _menuSel = i; doAction(); return;
                }
            }
            return;
        }
        if (_state == MKS_OVER) { _state = GS_MENU; _menuSel = 0; return; }
        if (_state == MKS_AI)   { return; }
        // Suit picker overlay — tap on a suit slot
        if (_state == MKS_SUIT) {
            var bw = _sw * 72 / 100;
            var ox = (_sw - bw) / 2; var oy = _sh / 2 - 29;
            var slotW = bw / 4;
            if (ty >= oy + 16 && ty <= oy + 44) {
                var slot = (tx - ox) / slotW;
                if (slot >= 0 && slot < 4) { _suitPick = slot; doAction(); return; }
            }
            return;
        }
        // Hand strip — tap on card or DRAW button
        if (_state == MKS_PLAY) {
            var slots = _pCount + 1;
            var gap2  = 3;
            var safeW = _sw * 86 / 100;
            var cw    = (safeW - (slots - 1) * gap2) / slots;
            if (cw > _cardW) { cw = _cardW; }
            if (cw < 10)     { cw = 10; }
            var ch    = cw * 150 / 100;
            var totalW = slots * cw + (slots - 1) * gap2;
            var startX = (_sw - totalW) / 2;
            if (startX < 2) { startX = 2; }
            if (ty >= _handY - 10 && ty <= _handY + ch + 10) {
                var idx = (tx - startX + gap2 / 2) / (cw + gap2);
                if (idx < 0) { idx = 0; }
                if (idx > _pCount) { idx = _pCount; }
                _cursorPos = idx;
                doAction();
                return;
            }
        }
    }
}
