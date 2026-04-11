using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Game state constants ──────────────────────────────────────────────────────
const PS_MENU     = 0;
const PS_PLAY     = 1;
const PS_SHOWDOWN = 2;
const PS_RESULT   = 3;
const PS_GAMEOVER = 4;

// Streets
const STR_PREFLOP = 0;
const STR_FLOP    = 1;
const STR_TURN    = 2;
const STR_RIVER   = 3;

// Actions
const ACT_FOLD  = 0;
const ACT_CALL  = 1;
const ACT_RAISE = 2;

// Poker config
const BB          = 20;   // big blind
const SB          = 10;   // small blind
const RAISE_BB    = 2;    // raise = RAISE_BB × BB
const START_CHIPS = 500;

class BitochiPokerView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs; hidden var _street;

    // Setup menu
    hidden var _numOpp;   // 1-3

    // Deck: card = rank*4+suit, rank 0-12 (2→A), suit 0-3 (♠♥♦♣)
    hidden var _deck;     // [52]
    hidden var _deckTop;

    // Cards: _hands flat array, player i → _hands[i*2], _hands[i*2+1]
    hidden var _hands;    // [8]
    hidden var _comm;     // [5] community cards, -1 = not dealt

    // Chips & pot
    hidden var _chips;    // [4]
    hidden var _pot;
    hidden var _sbets;    // [4] bets in current street
    hidden var _maxBet;   // highest bet this street
    hidden var _allin;    // [4] boolean

    // Round control
    hidden var _dealer;   // button position 0..numOpp
    hidden var _actIdx;   // who acts next
    hidden var _active;   // [4] still in hand
    hidden var _bust;     // [4] eliminated
    hidden var _needAct;  // [4] still needs to act this street

    // UI
    hidden var _selAct;   // player's chosen action
    hidden var _aiDelay;  // ticks before AI acts
    hidden var _showAll;  // true at showdown
    hidden var _winMsg;   // winner message
    hidden var _winIdx;   // winner index
    hidden var _handDesc; // [4] hand description at showdown

    // Geometry (set in setupGeometry)
    hidden var _hudH;
    hidden var _oppY; hidden var _oppCardW; hidden var _oppCardH;
    hidden var _commX; hidden var _commY; hidden var _commCW; hidden var _commCH;
    hidden var _handX; hidden var _handY; hidden var _handCW; hidden var _handCH;
    hidden var _actY;

    // String tables
    hidden var _rankStr;
    hidden var _suitStr;
    hidden var _streetStr;
    hidden var _handNames;

    // ── Initialize ────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _w = 0; _h = 0; _tick = 0;
        _gs = PS_MENU; _street = STR_PREFLOP;
        _numOpp = 2;
        _selAct = ACT_CALL; _aiDelay = 0; _showAll = false;
        _winMsg = ""; _winIdx = -1;
        _dealer = 0; _actIdx = 0; _pot = 0; _maxBet = 0; _deckTop = 0;

        _deck    = new [52];
        _hands   = new [8];
        _comm    = new [5];
        _chips   = new [4];
        _sbets   = new [4];
        _allin   = new [4];
        _active  = new [4];
        _bust    = new [4];
        _needAct = new [4];
        _handDesc = new [4];

        for (var i = 0; i < 5; i++) { _comm[i] = -1; }
        for (var i = 0; i < 4; i++) {
            _chips[i] = START_CHIPS; _bust[i] = false;
            _active[i] = false; _allin[i] = false;
            _needAct[i] = false; _handDesc[i] = "";
            _hands[i*2] = 0; _hands[i*2+1] = 1;
        }

        _rankStr   = ["2","3","4","5","6","7","8","9","T","J","Q","K","A"];
        _suitStr   = ["\u2660","\u2665","\u2666","\u2663"];
        _streetStr = ["Pre-Flop","Flop","Turn","River"];
        _handNames = ["High Card","Pair","Two Pair","Three of a Kind",
                      "Straight","Flush","Full House","Four of a Kind",
                      "Str.Flush","Royal Flush"];

        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 120, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupGeometry();
    }

    hidden function setupGeometry() {
        _hudH     = 26;
        _oppY     = _hudH + 4;
        _oppCardW = _w / 18;                        // ~14px
        _oppCardH = _oppCardW * 3 / 2;              // ~21px

        var oppAreaH = _oppCardH + 30;

        var commGap  = 3;
        var commTotalW = _w * 74 / 100;
        _commCW   = (commTotalW - commGap * 4) / 5;
        _commCH   = _commCW * 14 / 10;
        _commX    = (_w - commTotalW) / 2;
        _commY    = _oppY + oppAreaH + 4;

        _handCW   = _w * 21 / 100;                 // ~54px
        _handCH   = _handCW * 14 / 10;             // ~75px
        _handX    = (_w - _handCW * 2 - 10) / 2;
        _handY    = _commY + _commCH + 8;

        _actY     = _handY + _handCH + 8;
        if (_actY > _h * 88 / 100) { _actY = _h * 88 / 100; }
    }

    // ── Timer / tick ──────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        if (_gs == PS_PLAY && _actIdx != 0 && _active[_actIdx] && !_allin[_actIdx]) {
            _aiDelay--;
            if (_aiDelay <= 0) { doAiAction(); }
        }
        WatchUi.requestUpdate();
    }

    // ── Input ─────────────────────────────────────────────────────────────────
    function doUp() {
        if (_gs == PS_MENU) {
            _numOpp = (_numOpp % 3) + 1;
        } else if (_gs == PS_PLAY && _actIdx == 0 && _active[0]) {
            _selAct = (_selAct + 2) % 3;
        } else if (_gs == PS_SHOWDOWN || _gs == PS_RESULT) {
            startNewHand();
        }
    }

    function doDown() {
        if (_gs == PS_MENU) {
            _numOpp = (_numOpp % 3) + 1;
        } else if (_gs == PS_PLAY && _actIdx == 0 && _active[0]) {
            _selAct = (_selAct + 1) % 3;
        } else if (_gs == PS_SHOWDOWN || _gs == PS_RESULT) {
            startNewHand();
        }
    }

    function doSelect() {
        if (_gs == PS_MENU)     { startGame(); }
        else if (_gs == PS_PLAY && _actIdx == 0 && _active[0]) { doPlayerAction(_selAct); }
        else if (_gs == PS_SHOWDOWN || _gs == PS_RESULT) { startNewHand(); }
        else if (_gs == PS_GAMEOVER) { resetGame(); }
    }

    function doBack() {
        if (_gs != PS_MENU) { _gs = PS_MENU; }
    }

    // ── Game control ──────────────────────────────────────────────────────────
    hidden function startGame() {
        for (var i = 0; i < 4; i++) {
            _chips[i] = START_CHIPS;
            _bust[i]  = (i > _numOpp);
        }
        _dealer = 0;
        _gs = PS_PLAY;
        startNewHand();
    }

    hidden function resetGame() {
        _gs = PS_MENU;
        for (var i = 0; i < 4; i++) { _chips[i] = START_CHIPS; _bust[i] = false; }
    }

    hidden function startNewHand() {
        // Game-over checks
        if (_chips[0] <= 0) { _gs = PS_GAMEOVER; return; }
        var opp_alive = false;
        for (var i = 1; i <= _numOpp; i++) { if (_chips[i] > 0) { opp_alive = true; } }
        if (!opp_alive) { _gs = PS_GAMEOVER; return; }

        _gs = PS_PLAY;
        _street = STR_PREFLOP;
        _pot = 0; _maxBet = 0; _showAll = false;
        _winMsg = ""; _winIdx = -1;

        for (var i = 0; i < 5; i++) { _comm[i] = -1; }
        for (var i = 0; i < 4; i++) {
            _active[i]  = (i == 0 || (i <= _numOpp && _chips[i] > 0));
            _allin[i]   = false;
            _sbets[i]   = 0;
            _needAct[i] = _active[i];
            _handDesc[i] = "";
        }

        // Advance dealer past bust players
        var np = _numOpp + 1;
        _dealer = (_dealer + 1) % np;
        while (_bust[_dealer] || _chips[_dealer] <= 0) {
            _dealer = (_dealer + 1) % np;
        }

        shuffleDeck();
        for (var i = 0; i < np; i++) {
            if (_active[i]) {
                _hands[i*2]   = _deck[_deckTop];
                _hands[i*2+1] = _deck[_deckTop+1];
                _deckTop += 2;
            }
        }

        // Post blinds
        var sb_pos = nextActive((_dealer + 1) % np, -1);
        var bb_pos = nextActive((sb_pos + 1) % np, sb_pos);
        postBlind(sb_pos, SB);
        postBlind(bb_pos, BB);
        _maxBet = BB;
        _needAct[bb_pos] = true; // BB can re-raise

        // First to act: left of BB
        _actIdx  = nextActive((bb_pos + 1) % np, -1);
        _selAct  = ACT_CALL;
        _aiDelay = 5;
    }

    hidden function nextActive(start, skip) {
        var np = _numOpp + 1;
        var idx = start % np;
        for (var tries = 0; tries < np; tries++) {
            if (_active[idx] && idx != skip) { return idx; }
            idx = (idx + 1) % np;
        }
        return start % np;
    }

    hidden function postBlind(idx, amount) {
        var bet = (amount < _chips[idx]) ? amount : _chips[idx];
        if (bet >= _chips[idx]) { _allin[idx] = true; }
        _chips[idx] -= bet;
        _sbets[idx] += bet;
        _pot += bet;
        _needAct[idx] = false;
    }

    hidden function doPlayerAction(act) {
        if (_actIdx != 0) { return; }
        executeAction(0, act);
    }

    hidden function doAiAction() {
        executeAction(_actIdx, aiDecide(_actIdx));
    }

    hidden function executeAction(idx, act) {
        var toCall = _maxBet - _sbets[idx];
        if (toCall < 0) { toCall = 0; }

        if (act == ACT_FOLD) {
            _active[idx]  = false;
            _needAct[idx] = false;

        } else if (act == ACT_CALL) {
            var bet = (toCall < _chips[idx]) ? toCall : _chips[idx];
            if (bet >= _chips[idx]) { _allin[idx] = true; }
            _chips[idx]  -= bet;
            _sbets[idx]  += bet;
            _pot         += bet;
            _needAct[idx] = false;

        } else if (act == ACT_RAISE) {
            var raiseAmt  = BB * RAISE_BB;
            var newTotal  = _maxBet + raiseAmt;
            var bet       = newTotal - _sbets[idx];
            if (bet >= _chips[idx]) { bet = _chips[idx]; _allin[idx] = true; }
            _chips[idx]  -= bet;
            _sbets[idx]  += bet;
            _pot         += bet;
            if (_sbets[idx] > _maxBet) { _maxBet = _sbets[idx]; }
            for (var i = 0; i < 4; i++) {
                if (i != idx && _active[i] && !_allin[i]) { _needAct[i] = true; }
            }
            _needAct[idx] = false;
        }

        advanceRound();
    }

    hidden function advanceRound() {
        // Count active players
        var cnt = 0; var last = -1;
        for (var i = 0; i < 4; i++) { if (_active[i]) { cnt++; last = i; } }
        if (cnt <= 1) { awardPot(last); return; }

        // Find next player who needs to act
        var np = _numOpp + 1;
        var next = (_actIdx + 1) % np;
        var found = false;
        for (var tries = 0; tries < np; tries++) {
            if (_active[next] && _needAct[next] && !_allin[next]) { found = true; break; }
            next = (next + 1) % np;
        }

        if (!found) {
            advanceStreet();
        } else {
            _actIdx  = next;
            _aiDelay = 5;
        }
    }

    hidden function advanceStreet() {
        _street++;
        if (_street > STR_RIVER) { doShowdown(); return; }

        // Deal community cards
        if (_street == STR_FLOP) {
            _comm[0] = _deck[_deckTop]; _comm[1] = _deck[_deckTop+1]; _comm[2] = _deck[_deckTop+2];
            _deckTop += 3;
        } else {
            _comm[_street + 1] = _deck[_deckTop]; _deckTop++;
        }

        // Reset street bets
        _maxBet = 0;
        for (var i = 0; i < 4; i++) {
            _sbets[i]   = 0;
            _needAct[i] = _active[i] && !_allin[i];
        }

        var np = _numOpp + 1;
        _actIdx = nextActiveNeedsAct((_dealer + 1) % np);
        _selAct = ACT_CALL;
        _aiDelay = 5;
    }

    hidden function nextActiveNeedsAct(start) {
        var np = _numOpp + 1;
        var idx = start % np;
        for (var tries = 0; tries < np; tries++) {
            if (_active[idx] && _needAct[idx] && !_allin[idx]) { return idx; }
            idx = (idx + 1) % np;
        }
        return start % np;
    }

    hidden function doShowdown() {
        _showAll = true;
        _gs = PS_SHOWDOWN;

        // Evaluate all active players' best 7-card hand
        var np = _numOpp + 1;
        var bestVal = -1; var winner = -1;
        for (var i = 0; i < np; i++) {
            if (!_active[i]) { continue; }
            var cards7 = new [7];
            cards7[0] = _hands[i*2]; cards7[1] = _hands[i*2+1];
            for (var c = 0; c < 5; c++) {
                cards7[c+2] = (_comm[c] >= 0) ? _comm[c] : 0;
            }
            var hv = bestHand7(cards7);
            var ht = hv / 371293;
            if (ht < 0) { ht = 0; } if (ht > 9) { ht = 9; }
            _handDesc[i] = _handNames[ht];
            if (hv > bestVal) { bestVal = hv; winner = i; }
        }
        awardPot(winner);
    }

    hidden function awardPot(winner) {
        if (winner >= 0) {
            _chips[winner] += _pot;
            _winIdx = winner;
            _winMsg = (winner == 0) ? "You win  +" + _pot + "!" : "CPU " + winner + " wins";
        }
        _pot = 0;
        // Mark any chip-less opponents as bust
        for (var i = 0; i < 4; i++) {
            if (i <= _numOpp && _chips[i] <= 0) { _bust[i] = true; }
        }
        _gs = PS_RESULT;
    }

    // ── Deck helpers ──────────────────────────────────────────────────────────
    hidden function shuffleDeck() {
        for (var i = 0; i < 52; i++) { _deck[i] = i; }
        for (var i = 51; i > 0; i--) {
            var j = Math.rand().abs() % (i + 1);
            var t = _deck[i]; _deck[i] = _deck[j]; _deck[j] = t;
        }
        _deckTop = 0;
    }

    // ── Hand evaluation ───────────────────────────────────────────────────────
    // Best of all C(7,2)=21 five-card combinations
    hidden function bestHand7(c7) {
        var best = 0;
        var c5 = new [5];
        for (var s1 = 0; s1 < 6; s1++) {
            for (var s2 = s1 + 1; s2 < 7; s2++) {
                var ci = 0;
                for (var k = 0; k < 7; k++) {
                    if (k != s1 && k != s2) { c5[ci] = c7[k]; ci++; }
                }
                var v = evalHand5(c5);
                if (v > best) { best = v; }
            }
        }
        return best;
    }

    // Returns integer: handType*13^5 + rank_encoding (higher = better)
    hidden function evalHand5(c) {
        var r = new [5]; var s = new [5];
        for (var i = 0; i < 5; i++) { r[i] = c[i] / 4; s[i] = c[i] % 4; }

        // Sort ranks descending
        for (var i = 0; i < 4; i++) {
            for (var j = i+1; j < 5; j++) {
                if (r[j] > r[i]) { var t = r[i]; r[i] = r[j]; r[j] = t; }
            }
        }

        var flush = (s[0]==s[1] && s[1]==s[2] && s[2]==s[3] && s[3]==s[4]);
        var straight = false; var strHigh = r[0];
        if (r[0]-r[4] == 4 && r[0]!=r[1] && r[1]!=r[2] && r[2]!=r[3] && r[3]!=r[4]) {
            straight = true;
        }
        if (r[0]==12 && r[1]==3 && r[2]==2 && r[3]==1 && r[4]==0) {
            straight = true; strHigh = 3;
        }

        var cnt = new [13];
        for (var i = 0; i < 13; i++) { cnt[i] = 0; }
        for (var i = 0; i < 5; i++)  { cnt[r[i]]++; }

        var quad=-1; var trip=-1; var p0=-1; var p1=-1; var pc=0;
        for (var k = 12; k >= 0; k--) {
            if      (cnt[k] == 4) { quad = k; }
            else if (cnt[k] == 3) { trip = k; }
            else if (cnt[k] == 2) { if (pc==0){p0=k;}else if(pc==1){p1=k;} pc++; }
        }

        var B = 371293; // 13^5
        var type; var val;

        if (straight && flush) {
            type = (strHigh == 12) ? 9 : 8; val = type*B + strHigh;
        } else if (quad >= 0) {
            var kick=-1; for(var k=12;k>=0;k--){if(cnt[k]==1){kick=k;break;}}
            type = 7; val = type*B + quad*28561 + (kick>=0?kick:0);
        } else if (trip >= 0 && pc >= 1) {
            type = 6; val = type*B + trip*2197 + p0*169;
        } else if (flush) {
            type = 5; val = type*B + r[0]*28561+r[1]*2197+r[2]*169+r[3]*13+r[4];
        } else if (straight) {
            type = 4; val = type*B + strHigh;
        } else if (trip >= 0) {
            var k1=-1; var k2=-1;
            for(var k=12;k>=0;k--){if(cnt[k]==1){if(k1<0){k1=k;}else{k2=k;break;}}}
            type = 3; val = type*B + trip*28561 + (k1>=0?k1:0)*2197 + (k2>=0?k2:0)*169;
        } else if (pc >= 2) {
            var kick2=-1; for(var k=12;k>=0;k--){if(cnt[k]==1){kick2=k;break;}}
            type = 2; val = type*B + p0*2197 + p1*169 + (kick2>=0?kick2:0)*13;
        } else if (pc == 1) {
            var k1b=-1; var k2b=-1; var k3b=-1;
            for(var k=12;k>=0;k--){if(cnt[k]==1){if(k1b<0){k1b=k;}else if(k2b<0){k2b=k;}else{k3b=k;break;}}}
            type = 1; val = type*B + p0*28561 + (k1b>=0?k1b:0)*2197 + (k2b>=0?k2b:0)*169 + (k3b>=0?k3b:0)*13;
        } else {
            type = 0; val = r[0]*28561+r[1]*2197+r[2]*169+r[3]*13+r[4];
        }
        return val;
    }

    // ── AI logic ──────────────────────────────────────────────────────────────
    hidden function aiDecide(idx) {
        var toCall = _maxBet - _sbets[idx];
        if (toCall < 0) { toCall = 0; }
        var str = aiStrength(idx);
        var canRaise = (_chips[idx] > toCall + BB);

        if (str > 0.78 && canRaise) { return ACT_RAISE; }
        if (str > 0.52)             { return ACT_CALL;  }
        if (toCall == 0)            { return ACT_CALL;  } // free check
        if (str > 0.32 && toCall <= BB * 3) { return ACT_CALL; }
        return ACT_FOLD;
    }

    hidden function aiStrength(idx) {
        var c0r = _hands[idx*2]   / 4; // rank 0-12
        var c1r = _hands[idx*2+1] / 4;
        var hi  = (c0r > c1r) ? c0r : c1r;
        var lo  = (c0r < c1r) ? c0r : c1r;
        var paired  = (c0r == c1r);
        var suited  = (_hands[idx*2] % 4 == _hands[idx*2+1] % 4);

        if (_street == STR_PREFLOP) {
            var sc = (hi.toFloat() + lo.toFloat()) / 24.0;
            if (paired) { sc += 0.22; }
            if (suited)  { sc += 0.06; }
            if (sc > 1.0) { sc = 1.0; }
            return sc;
        }

        // Post-flop: use actual hand value
        var commCount = 0;
        for (var c = 0; c < 5; c++) { if (_comm[c] >= 0) { commCount++; } }
        if (commCount == 0) { return (hi.toFloat() + lo.toFloat()) / 24.0; }

        var cards7 = new [7];
        cards7[0] = _hands[idx*2]; cards7[1] = _hands[idx*2+1];
        for (var c = 0; c < 5; c++) {
            cards7[c+2] = (_comm[c] >= 0) ? _comm[c] : _deck[0];
        }
        var hv = bestHand7(cards7);
        var ht = hv / 371293;
        return (ht.toFloat() + 1.0) / 10.5;
    }

    // ── Rendering ─────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeometry(); }
        if (_gs == PS_MENU)     { drawMenu(dc); return; }
        if (_gs == PS_GAMEOVER) { drawGameOver(dc); return; }
        drawTable(dc);
    }

    // ── Menu ─────────────────────────────────────────────────────────────────
    hidden function drawMenu(dc) {
        dc.setColor(0x0B1520, 0x0B1520); dc.clear();

        // Suit decorations across the top
        var sClr = [0xBBBBBB, 0xFF5555, 0xFF7733, 0xBBBBBB];
        for (var i = 0; i < 4; i++) {
            dc.setColor(sClr[i], Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w * (15 + i * 24) / 100, _h * 7 / 100,
                Graphics.FONT_LARGE, _suitStr[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 26 / 100, Graphics.FONT_MEDIUM, "POKER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x1E3D5A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 38 / 100, Graphics.FONT_XTINY, "Texas Hold'em", Graphics.TEXT_JUSTIFY_CENTER);

        // Opponent count selector
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 52 / 100, Graphics.FONT_XTINY,
            "Opponents: " + _numOpp, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 62 / 100, Graphics.FONT_XTINY,
            "\u25B2 \u25BC  to change", Graphics.TEXT_JUSTIFY_CENTER);

        // Starting chips info
        dc.setColor(0x446677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 72 / 100, Graphics.FONT_XTINY,
            "Start: " + START_CHIPS + " chips", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 12 < 6) ? 0x44AAFF : 0x2277CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 86 / 100, Graphics.FONT_XTINY, "Tap to deal!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game table ────────────────────────────────────────────────────────────
    hidden function drawTable(dc) {
        // Dark background + circular green felt
        dc.setColor(0x050C10, 0x050C10); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0B3520, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);
        dc.setColor(0x0E4228, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 18);

        drawHUD(dc);
        drawOpponents(dc);
        drawCommunity(dc);
        drawPlayerCards(dc);

        if (_gs == PS_PLAY)     { drawActionBar(dc); }
        if (_gs == PS_SHOWDOWN) { drawShowdownBar(dc); }
        if (_gs == PS_RESULT)   { drawResultOverlay(dc); }
    }

    hidden function drawHUD(dc) {
        // Street name (top center)
        dc.setColor(0x5599AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, 4, Graphics.FONT_XTINY, _streetStr[_street], Graphics.TEXT_JUSTIFY_CENTER);
        // Pot
        if (_pot > 0) {
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, 15, Graphics.FONT_XTINY, "POT " + _pot, Graphics.TEXT_JUSTIFY_CENTER);
        }
        // Player chips (safe bottom-left)
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 15 / 100, _h - 13, Graphics.FONT_XTINY, "" + _chips[0], Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function drawOpponents(dc) {
        var oppXs = getOppXs();
        for (var i = 1; i <= _numOpp; i++) {
            var ox = oppXs[i-1];
            var oy = _oppY;
            var bust  = (_bust[i] || _chips[i] <= 0);
            var folded = (!_active[i] && !bust && _gs == PS_PLAY);
            var isAct  = (_actIdx == i && _gs == PS_PLAY);

            // Active player highlight
            if (isAct) {
                dc.setColor(0x1A4A2A, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(ox - _oppCardW - 4, oy - 2, _oppCardW * 2 + 11, _oppCardH + 26, 3);
            }

            // Cards
            var cx0 = ox - _oppCardW - 2;
            var cx1 = cx0 + _oppCardW + 3;
            if (bust) {
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
                dc.drawText(ox, oy + 8, Graphics.FONT_XTINY, "OUT", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (folded) {
                dc.setColor(0x553333, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx0, oy, _oppCardW, _oppCardH, 2);
                dc.fillRoundedRectangle(cx1, oy, _oppCardW, _oppCardH, 2);
                dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(ox, oy + 4, Graphics.FONT_XTINY, "FOLD", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                var faceUp = _showAll && _active[i];
                drawCard(dc, cx0, oy, _oppCardW, _oppCardH,
                    _hands[i*2],   faceUp);
                drawCard(dc, cx1, oy, _oppCardW, _oppCardH,
                    _hands[i*2+1], faceUp);
            }

            // Name + chips
            var nameColor = bust ? 0x444444 : (isAct ? 0xFFDD44 : 0x88AACC);
            dc.setColor(nameColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ox, oy + _oppCardH + 2, Graphics.FONT_XTINY, "CPU" + i, Graphics.TEXT_JUSTIFY_CENTER);
            if (!bust) {
                dc.setColor(0x557799, Graphics.COLOR_TRANSPARENT);
                dc.drawText(ox, oy + _oppCardH + 13, Graphics.FONT_XTINY, "" + _chips[i], Graphics.TEXT_JUSTIFY_CENTER);
            }

            // Current street bet
            if (!bust && _sbets[i] > 0 && _gs == PS_PLAY) {
                dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
                dc.drawText(ox, oy - 11, Graphics.FONT_XTINY, "+" + _sbets[i], Graphics.TEXT_JUSTIFY_CENTER);
            }

            // Hand name at showdown
            if (_showAll && _active[i] && !_handDesc[i].equals("")) {
                dc.setColor(0xAADD88, Graphics.COLOR_TRANSPARENT);
                dc.drawText(ox, oy + _oppCardH + 24, Graphics.FONT_XTINY, _handDesc[i], Graphics.TEXT_JUSTIFY_CENTER);
            }

            // Dealer button
            if (_dealer == i) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx0 - 5, oy + _oppCardH/2, 5);
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx0 - 5, oy + _oppCardH/2 - 7, Graphics.FONT_XTINY, "D", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden function getOppXs() {
        var xs = new [3];
        if (_numOpp == 1) {
            xs[0] = _w / 2;
        } else if (_numOpp == 2) {
            xs[0] = _w * 28 / 100;
            xs[1] = _w * 72 / 100;
        } else {
            xs[0] = _w * 18 / 100;
            xs[1] = _w / 2;
            xs[2] = _w * 82 / 100;
        }
        return xs;
    }

    hidden function drawCommunity(dc) {
        var gap = 3;
        var x = _commX;
        for (var i = 0; i < 5; i++) {
            if (_comm[i] >= 0) {
                drawCard(dc, x, _commY, _commCW, _commCH, _comm[i], true);
            } else {
                dc.setColor(0x0D3020, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x, _commY, _commCW, _commCH, 2);
                dc.setColor(0x1A4A30, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(x, _commY, _commCW, _commCH, 2);
            }
            x += _commCW + gap;
        }
    }

    hidden function drawPlayerCards(dc) {
        // Active indicator behind cards
        if (_actIdx == 0 && _gs == PS_PLAY && _active[0]) {
            dc.setColor(0x1A4A2A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(_handX - 6, _handY - 4, _handCW * 2 + 22, _handCH + 8, 5);
        }

        drawCard(dc, _handX,              _handY, _handCW, _handCH, _hands[0], true);
        drawCard(dc, _handX+_handCW+10,   _handY, _handCW, _handCH, _hands[1], true);

        // Hand name at showdown
        if (_showAll && !_handDesc[0].equals("")) {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _handY + _handCH + 5, Graphics.FONT_XTINY, _handDesc[0], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Current bet
        if (_sbets[0] > 0 && _gs == PS_PLAY) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _handY - 13, Graphics.FONT_XTINY, "BET " + _sbets[0], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Dealer button for player
        if (_dealer == 0) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_handX - 8, _handY + _handCH/2, 6);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_handX - 8, _handY + _handCH/2 - 7, Graphics.FONT_XTINY, "D", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawActionBar(dc) {
        // Show AI thinking indicator when it's not player's turn
        if (_actIdx != 0) {
            dc.setColor(0x336655, Graphics.COLOR_TRANSPARENT);
            var d = "";
            var n = _tick % 4;
            for (var i = 0; i < n; i++) { d = d + "."; }
            dc.drawText(_w/2, _actY, Graphics.FONT_XTINY,
                "CPU" + _actIdx + " thinking" + d, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        if (!_active[0]) { return; }

        var toCall = _maxBet - _sbets[0];
        if (toCall < 0) { toCall = 0; }

        var actLabels = new [3];
        actLabels[ACT_FOLD]  = "FOLD";
        actLabels[ACT_CALL]  = (toCall == 0) ? "CHECK" : ("CALL " + toCall);
        actLabels[ACT_RAISE] = (_chips[0] > toCall + BB) ? ("RAISE") : "ALL-IN";

        // Three buttons across the safe zone at _actY
        var slotW = _w / 3;
        for (var a = 0; a < 3; a++) {
            var ax = a * slotW + slotW / 2;
            var sel = (_selAct == a);
            var bgClr = (a == ACT_FOLD)  ? (sel ? 0x661111 : 0x2A0808)
                      : (a == ACT_CALL)  ? (sel ? 0x116611 : 0x082A08)
                      :                    (sel ? 0x665511 : 0x2A2008);
            dc.setColor(bgClr, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(ax - slotW/2 + 3, _actY - 2, slotW - 6, 20, 4);

            var txtClr = sel ? 0xFFFFFF
                       : (a == ACT_FOLD)  ? 0xAA4444
                       : (a == ACT_CALL)  ? 0x44AA66
                       :                    0xAA9933;
            dc.setColor(txtClr, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ax, _actY, Graphics.FONT_XTINY, actLabels[a], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x2A3A44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _actY + 18, Graphics.FONT_XTINY,
            "\u25B2\u25BC=switch  tap=ok", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawShowdownBar(dc) {
        dc.setColor(0x335544, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _actY, Graphics.FONT_XTINY, "Tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawResultOverlay(dc) {
        var w2 = _w * 72 / 100;
        var h2 = 44;
        dc.setColor(0x050C0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle((_w - w2)/2, _h/2 - h2/2, w2, h2, 8);
        dc.setColor(0x336655, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle((_w - w2)/2, _h/2 - h2/2, w2, h2, 8);

        var clr = (_winIdx == 0) ? 0x44FF88 : 0xFF8844;
        dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 16, Graphics.FONT_XTINY, _winMsg, Graphics.TEXT_JUSTIFY_CENTER);

        // Show player chip total
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2, Graphics.FONT_XTINY, "Chips: " + _chips[0], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0x44AAFF : 0x2277CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 + 14, Graphics.FONT_XTINY, "Tap for next hand", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x0B1520, 0x0B1520); dc.clear();
        var sClr = [0xBBBBBB, 0xFF5555, 0xFF7733, 0xBBBBBB];
        for (var i = 0; i < 4; i++) {
            dc.setColor(sClr[i], Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w * (15 + i * 24) / 100, _h * 8 / 100,
                Graphics.FONT_LARGE, _suitStr[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        var won = (_chips[0] >= START_CHIPS * _numOpp);
        dc.setColor(won ? 0xFFDD44 : 0xFF4455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 30 / 100, Graphics.FONT_MEDIUM,
            won ? "YOU WIN!" : "BUSTED!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 47 / 100, Graphics.FONT_XTINY,
            "Chips: " + _chips[0], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 58 / 100, Graphics.FONT_XTINY,
            "Start: " + START_CHIPS + "   Opp: " + _numOpp, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 12 < 6) ? 0x44AAFF : 0x2277CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 80 / 100, Graphics.FONT_XTINY, "Tap to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Card drawing ──────────────────────────────────────────────────────────
    hidden function drawCard(dc, x, y, w, h, cardIdx, faceUp) {
        if (!faceUp || cardIdx < 0) {
            // Face-down: dark blue with diagonal lines
            dc.setColor(0x1A2888, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, h, 3);
            dc.setColor(0x283AAA, Graphics.COLOR_TRANSPARENT);
            var step = (w > 14) ? 5 : 4;
            for (var d = -h; d < w; d += step) {
                dc.drawLine(x + d, y, x + d + h, y + h);
            }
            dc.setColor(0x3A4ABB, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, h, 3);
            return;
        }

        var rank = cardIdx / 4;
        var suit = cardIdx % 4;
        var isRed = (suit == 1 || suit == 2);

        // Card face — cream background
        dc.setColor(0xEEEDDD, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 3);
        dc.setColor(0x999888, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 3);

        var rankColor = isRed ? 0xCC1111 : 0x111122;
        dc.setColor(rankColor, Graphics.COLOR_TRANSPARENT);

        var font = (w >= 30) ? Graphics.FONT_TINY : Graphics.FONT_XTINY;
        // Rank top-left
        dc.drawText(x + 2, y + 1, Graphics.FONT_XTINY, _rankStr[rank], Graphics.TEXT_JUSTIFY_LEFT);

        // Suit centre
        var sFont = (w >= 30) ? Graphics.FONT_SMALL : Graphics.FONT_XTINY;
        dc.setColor(isRed ? 0xCC1111 : 0x111133, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w/2, y + h/2 - (w >= 30 ? 10 : 7), sFont,
            _suitStr[suit], Graphics.TEXT_JUSTIFY_CENTER);

        // Rank bottom-right (upside-down style: just repeat rank)
        if (w >= 25) {
            dc.setColor(rankColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + w - 2, y + h - 13, Graphics.FONT_XTINY,
                _rankStr[rank], Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }
}
