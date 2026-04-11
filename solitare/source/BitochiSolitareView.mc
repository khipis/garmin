using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;

// ── Game states ───────────────────────────────────────────────────────────────
const SS_MENU   = 0;
const SS_PLAY   = 1;
const SS_WIN    = 2;

// Card encoding: card = rank*4 + suit
// rank: 0=A,1=2,...,12=K   suit: 0=♠,1=♥,2=♦,3=♣
// -1 = empty slot,  face-down cards stored as -(card+2)  → decode: -(v+2)

// Pile indices
const STOCK     = 0;   // draw pile (face-down)
const WASTE     = 1;   // flipped cards
// FOUNDATION 0-3  → piles 2-5   (Ace→King per suit)
// TABLEAU   0-6  → piles 6-12

const FOUND_OFF = 2;
const TAB_OFF   = 6;
const NUM_PILES = 13;  // stock + waste + 4 found + 7 tableau

class BitochiSolitareView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    // Setup
    hidden var _drawMode;  // 1 or 3 cards at a time

    // Game piles: each is a variable-size array stored in a flat layout
    // _pile[p] = array of card values (face-down stored negative)
    hidden var _pile;      // [NUM_PILES] arrays

    // Selection state
    hidden var _selPile;   // selected pile index (-1 = none)
    hidden var _selCard;   // index in pile of bottom of selection
    hidden var _cursor;    // navigation cursor position (pile 0-12)

    // Waste offset (for draw-3: which of the 3 shown is "active")
    hidden var _wasteOff;  // how many waste cards currently fanned (0-2 for draw3)

    // Geometry
    hidden var _cw; hidden var _ch;   // card width / height
    hidden var _colX;                  // [7] x positions of tableau columns
    hidden var _colY;                  // base y of tableau
    hidden var _foundY;                // y of foundation row
    hidden var _stockX; hidden var _wasteX;
    hidden var _topRowY;
    hidden var _fanOff;                // pixels between fanned cards in tableau

    // Win animation
    hidden var _winTick;

    // String tables
    hidden var _rankStr; hidden var _suitStr;

    // ── Initialize ────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _w = 0; _h = 0; _tick = 0;
        _gs = SS_MENU; _drawMode = 1;
        _selPile = -1; _selCard = 0; _cursor = 6; _wasteOff = 0;
        _winTick = 0;

        _rankStr = ["A","2","3","4","5","6","7","8","9","T","J","Q","K"];
        _suitStr = ["\u2660","\u2665","\u2666","\u2663"];

        _pile = new [NUM_PILES];
        for (var i = 0; i < NUM_PILES; i++) { _pile[i] = new [0]; }

        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 150, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupGeometry();
    }

    hidden function setupGeometry() {
        var r    = _w / 2;
        var gap  = 1;

        // Push the top row down until it's inside the round-screen safe zone.
        // safeHalf(y) = sqrt(r² – (r–y)²)  — half the usable width at row y.
        // We need:  safeHalf * 2  ≥  7*cw + 8*gap + 4px margin
        // Try topRowY = 26; solve for max cw that fits.
        _topRowY = 26;
        var dy       = r - _topRowY;
        var safeHalf = Math.sqrt((r * r - dy * dy).toFloat()).toNumber();
        var usableW  = safeHalf * 2 - 4;          // leave 2px margin each side
        _cw = (usableW - gap * 8) / 7;
        if (_cw > 22) { _cw = 22; }
        if (_cw < 14) { _cw = 14; }
        _ch = _cw * 15 / 10;                      // card height = 1.5× width

        // Centre the 7 columns on screen
        var totalW = _cw * 7 + gap * 8;
        var startX = (_w - totalW) / 2;
        _colX = new [7];
        for (var c = 0; c < 7; c++) {
            _colX[c] = startX + gap + c * (_cw + gap);
        }

        _stockX = _colX[0];
        _wasteX = _colX[1];
        _foundY = _topRowY;
        _colY   = _topRowY + _ch + 3;

        // Fan offset: fixed 11px — shows rank + suit line of each fanned card
        _fanOff = 11;
    }

    // ── Timer ─────────────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        if (_gs == SS_WIN) { _winTick++; }
        WatchUi.requestUpdate();
    }

    // ── Input ─────────────────────────────────────────────────────────────────
    // Cursor layout:  0=stock  1=waste  2-5=foundations  6-12=tableau cols
    function doUp() {
        if (_gs == SS_MENU) { _drawMode = (_drawMode == 1) ? 3 : 1; return; }
        if (_gs == SS_WIN)  { newGame(); return; }
        if (_selPile >= 0)  { cancelSel(); return; }
        // Move cursor up (to top row) or down (to tableau)
        if (_cursor >= TAB_OFF) { _cursor = _cursor - TAB_OFF; if (_cursor > 5) { _cursor = 5; } }
        else { _cursor = TAB_OFF + (_cursor < 2 ? _cursor : _cursor - 2); }
    }

    function doDown() {
        if (_gs == SS_MENU) { _drawMode = (_drawMode == 1) ? 3 : 1; return; }
        if (_gs == SS_WIN)  { newGame(); return; }
        if (_selPile >= 0)  { cancelSel(); return; }
        if (_cursor < TAB_OFF) { _cursor = TAB_OFF + (_cursor < 2 ? _cursor : _cursor - 2 + 2); if (_cursor >= NUM_PILES) { _cursor = NUM_PILES - 1; } }
        else { _cursor = _cursor - TAB_OFF; if (_cursor > 5) { _cursor = 5; } }
    }

    function doSelect() {
        if (_gs == SS_MENU) { startGame(); return; }
        if (_gs == SS_WIN)  { newGame(); return; }
        handleSelect(_cursor);
    }

    function doBack() {
        if (_gs == SS_PLAY) { _gs = SS_MENU; return; }
        if (_gs == SS_WIN)  { _gs = SS_MENU; return; }
    }

    function doMenu() {
        if (_gs == SS_PLAY) { _gs = SS_MENU; }
    }

    function doTap(tx, ty) {
        if (_gs == SS_MENU) { startGame(); return; }
        if (_gs == SS_WIN)  { newGame(); return; }

        // Find which pile was tapped
        var hit = hitTest(tx, ty);
        if (hit >= 0) {
            _cursor = hit;
            handleSelect(hit);
        }
    }

    hidden function hitTest(tx, ty) {
        var gap = 2;
        // Stock
        if (tx >= _stockX && tx < _stockX + _cw &&
            ty >= _topRowY && ty < _topRowY + _ch) { return STOCK; }
        // Waste
        if (tx >= _wasteX && tx < _wasteX + _cw + _cw / 2 &&
            ty >= _topRowY && ty < _topRowY + _ch) { return WASTE; }
        // Foundations
        for (var f = 0; f < 4; f++) {
            var fx = _colX[3 + f];
            if (tx >= fx && tx < fx + _cw &&
                ty >= _foundY && ty < _foundY + _ch) { return FOUND_OFF + f; }
        }
        // Tableau columns
        for (var c = 0; c < 7; c++) {
            var cx = _colX[c];
            if (tx < cx || tx >= cx + _cw) { continue; }
            var pileIdx = TAB_OFF + c;
            var sz = _pile[pileIdx].size();
            if (sz == 0) {
                if (ty >= _colY && ty < _colY + _ch) { return pileIdx; }
            } else {
                var topY = _colY + (sz - 1) * _fanOff;
                if (ty >= _colY && ty < topY + _ch) { return pileIdx; }
            }
        }
        return -1;
    }

    hidden function cancelSel() {
        _selPile = -1; _selCard = 0;
    }

    // ── Core selection / move logic ───────────────────────────────────────────
    hidden function handleSelect(pile) {
        if (pile == STOCK) {
            drawStock(); return;
        }

        if (_selPile < 0) {
            // Pick up cards
            tryPickup(pile);
        } else {
            // Try to place
            if (!tryPlace(pile)) {
                // Tap same pile → deselect; tap different → try again
                if (pile == _selPile) { cancelSel(); }
                else { cancelSel(); tryPickup(pile); }
            }
        }
        checkWin();
    }

    hidden function drawStock() {
        var stock = _pile[STOCK];
        var waste = _pile[WASTE];
        if (stock.size() == 0) {
            // Recycle waste back to stock (face-down)
            if (waste.size() == 0) { return; }
            var ns = waste.size();
            var newStock = new [ns];
            for (var i = 0; i < ns; i++) {
                var c = waste[ns - 1 - i];
                newStock[i] = -(c + 2); // flip face-down
            }
            _pile[STOCK] = newStock;
            _pile[WASTE] = new [0];
            _wasteOff = 0;
        } else {
            // Draw 1 or 3 cards from stock to waste
            var n = (_drawMode == 3) ? 3 : 1;
            if (n > stock.size()) { n = stock.size(); }
            var newWaste = new [waste.size() + n];
            for (var i = 0; i < waste.size(); i++) { newWaste[i] = waste[i]; }
            for (var i = 0; i < n; i++) {
                var card = stock[stock.size() - 1 - i];
                newWaste[waste.size() + i] = (card < 0) ? -(card + 2) : card; // flip up
            }
            var newStock = new [stock.size() - n];
            for (var i = 0; i < newStock.size(); i++) { newStock[i] = stock[i]; }
            _pile[STOCK] = newStock;
            _pile[WASTE] = newWaste;
            _wasteOff = 0;
        }
        cancelSel();
    }

    hidden function tryPickup(pile) {
        if (pile == WASTE) {
            var waste = _pile[WASTE];
            if (waste.size() == 0) { return; }
            var top = waste[waste.size() - 1];
            if (top < 0) { return; } // face-down — shouldn't happen in waste
            _selPile = pile; _selCard = waste.size() - 1;
            return;
        }
        if (pile >= FOUND_OFF && pile < TAB_OFF) {
            var found = _pile[pile];
            if (found.size() == 0) { return; }
            _selPile = pile; _selCard = found.size() - 1;
            return;
        }
        if (pile >= TAB_OFF) {
            var tab = _pile[pile];
            if (tab.size() == 0) { return; }
            // Find topmost face-up card the player tapped
            // For button control: pick up from the first face-up card (natural stack)
            var firstFaceUp = tab.size();
            for (var i = 0; i < tab.size(); i++) {
                if (tab[i] >= 0) { firstFaceUp = i; break; }
            }
            if (firstFaceUp >= tab.size()) {
                // Flip top face-down card
                var top = tab[tab.size() - 1];
                if (top < 0) {
                    tab[tab.size() - 1] = -(top + 2);
                    _pile[pile] = tab;
                }
                return;
            }
            _selPile = pile; _selCard = firstFaceUp;
        }
    }

    hidden function tryPlace(dest) {
        if (_selPile < 0) { return false; }

        var srcPile  = _pile[_selPile];
        var numCards = srcPile.size() - _selCard;
        if (numCards <= 0) { return false; }

        var bottomCard = srcPile[_selCard]; // bottom card of the moving stack
        if (bottomCard < 0) { return false; } // face-down, can't move

        // Foundation?
        if (dest >= FOUND_OFF && dest < TAB_OFF) {
            if (numCards != 1) { return false; } // only single cards to foundation
            var suit  = bottomCard % 4;
            var rank  = bottomCard / 4;
            if (dest - FOUND_OFF != suit) { return false; } // must match suit slot
            var found = _pile[dest];
            if (found.size() == 0) {
                if (rank != 0) { return false; } // only Ace starts
            } else {
                var topF = found[found.size() - 1];
                if (topF / 4 != rank - 1) { return false; } // must be rank-1
            }
            // Do the move
            execMove(dest, numCards);
            return true;
        }

        // Tableau?
        if (dest >= TAB_OFF) {
            var tab = _pile[dest];
            if (tab.size() == 0) {
                // Only King (rank 12) on empty column
                if (bottomCard / 4 != 12) { return false; }
            } else {
                var topT = tab[tab.size() - 1];
                if (topT < 0) { return false; } // top face-down
                var topRank = topT / 4; var topSuit = topT % 4;
                var botRank = bottomCard / 4; var botSuit = bottomCard % 4;
                // Must be one less rank and alternating color
                if (botRank != topRank - 1) { return false; }
                var topRed = (topSuit == 1 || topSuit == 2);
                var botRed = (botSuit == 1 || botSuit == 2);
                if (topRed == botRed) { return false; } // same color
            }
            execMove(dest, numCards);
            return true;
        }

        return false;
    }

    hidden function execMove(dest, numCards) {
        var srcPile = _pile[_selPile];
        var dstPile = _pile[dest];

        var newDst = new [dstPile.size() + numCards];
        for (var i = 0; i < dstPile.size(); i++) { newDst[i] = dstPile[i]; }
        for (var i = 0; i < numCards; i++) { newDst[dstPile.size() + i] = srcPile[_selCard + i]; }
        _pile[dest] = newDst;

        var newSrc = new [srcPile.size() - numCards];
        for (var i = 0; i < newSrc.size(); i++) { newSrc[i] = srcPile[i]; }
        _pile[_selPile] = newSrc;

        // Auto-flip top of source if face-down
        var src2 = _pile[_selPile];
        if (src2.size() > 0) {
            var top = src2[src2.size() - 1];
            if (top < 0) { src2[src2.size() - 1] = -(top + 2); _pile[_selPile] = src2; }
        }

        cancelSel();
    }

    hidden function checkWin() {
        var total = 0;
        for (var f = 0; f < 4; f++) { total += _pile[FOUND_OFF + f].size(); }
        if (total == 52) { _gs = SS_WIN; _winTick = 0; }
    }

    // ── Auto-move to foundation ───────────────────────────────────────────────
    // Called after each draw/move — move safe cards automatically
    hidden function autoFoundation() {
        var moved = true;
        while (moved) {
            moved = false;
            // Check waste top and all tableau tops
            var sources = new [8];
            sources[0] = WASTE;
            for (var c = 0; c < 7; c++) { sources[c+1] = TAB_OFF + c; }
            for (var si = 0; si < 8; si++) {
                var sp = sources[si];
                var pile = _pile[sp];
                if (pile.size() == 0) { continue; }
                var top = pile[pile.size() - 1];
                if (top < 0) { continue; }
                var rank = top / 4; var suit = top % 4;
                var fp = FOUND_OFF + suit;
                var found = _pile[fp];
                var canAuto = false;
                if (found.size() == 0 && rank == 0) { canAuto = true; }
                else if (found.size() > 0 && found[found.size()-1] / 4 == rank - 1) {
                    // Only auto-move if safe (rank <= 2 always safe;
                    // higher ranks only when both colors of rank-1 are on foundations)
                    if (rank <= 1) { canAuto = true; }
                    else {
                        // Safe if the two opposite-color foundations both have rank>=rank-2
                        var opp1 = (suit == 0 || suit == 3) ? 1 : 0; // red if black
                        var opp2 = (suit == 0 || suit == 3) ? 2 : 3;
                        var f1 = _pile[FOUND_OFF + opp1];
                        var f2 = _pile[FOUND_OFF + opp2];
                        var r1 = (f1.size() > 0) ? f1[f1.size()-1] / 4 : -1;
                        var r2 = (f2.size() > 0) ? f2[f2.size()-1] / 4 : -1;
                        if (r1 >= rank - 2 && r2 >= rank - 2) { canAuto = true; }
                    }
                }
                if (canAuto) {
                    _selPile = sp; _selCard = pile.size() - 1;
                    execMove(fp, 1);
                    moved = true;
                }
            }
        }
        checkWin();
    }

    // ── Game setup ────────────────────────────────────────────────────────────
    hidden function startGame() {
        _gs = SS_PLAY;
        newGame();
    }

    hidden function newGame() {
        _gs = SS_PLAY;
        _selPile = -1; _cursor = TAB_OFF; _wasteOff = 0;

        // Build and shuffle deck
        var deck = new [52];
        for (var i = 0; i < 52; i++) { deck[i] = i; }
        for (var i = 51; i > 0; i--) {
            var j = Math.rand().abs() % (i + 1);
            var t = deck[i]; deck[i] = deck[j]; deck[j] = t;
        }

        // Reset all piles
        for (var i = 0; i < NUM_PILES; i++) { _pile[i] = new [0]; }

        // Deal tableau: col c gets c+1 cards; last card face-up rest face-down
        var di = 0;
        for (var c = 0; c < 7; c++) {
            var tab = new [c + 1];
            for (var r = 0; r < c; r++) {
                tab[r] = -(deck[di] + 2); // face-down
                di++;
            }
            tab[c] = deck[di]; // face-up
            di++;
            _pile[TAB_OFF + c] = tab;
        }

        // Remaining cards go to stock (face-down)
        var stockSize = 52 - di;
        var stock = new [stockSize];
        for (var i = 0; i < stockSize; i++) {
            stock[i] = -(deck[di + i] + 2);
        }
        _pile[STOCK] = stock;
    }

    // ── Rendering ─────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeometry(); }
        if (_gs == SS_MENU) { drawMenu(dc); return; }
        drawGame(dc);
        if (_gs == SS_WIN)  { drawWinOverlay(dc); }
    }

    // ── Menu ─────────────────────────────────────────────────────────────────
    hidden function drawMenu(dc) {
        dc.setColor(0x0A1508, 0x0A1508); dc.clear();

        // Green felt circle
        var r = _w / 2;
        dc.setColor(0x0D3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);
        dc.setColor(0x114422, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 16);

        // Decorative card fans top
        var fanCards = [0, 14, 27, 40]; // A♠ A♥ A♦ A♣
        var sclr = [0xCCCCCC, 0xFF5555, 0xFF7733, 0xCCCCCC];
        for (var i = 0; i < 4; i++) {
            var fx = _w * (18 + i * 21) / 100;
            var fy = _h * 8 / 100;
            dc.setColor(0xDDDDBB, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(fx - 6, fy, 13, 18, 2);
            dc.setColor(sclr[i], Graphics.COLOR_TRANSPARENT);
            dc.drawText(fx - 4, fy + 1, Graphics.FONT_XTINY, _rankStr[fanCards[i] / 4], Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(fx - 5, fy + 9, Graphics.FONT_XTINY, _suitStr[fanCards[i] % 4], Graphics.TEXT_JUSTIFY_LEFT);
        }

        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 32 / 100, Graphics.FONT_MEDIUM, "SOLITAIRE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x1E3D5A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 44 / 100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 56 / 100, Graphics.FONT_XTINY,
            "Draw: " + _drawMode + " card" + (_drawMode > 1 ? "s" : ""),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x336655, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 66 / 100, Graphics.FONT_XTINY,
            "\u25B2\u25BC toggle  1 / 3", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 12 < 6) ? 0x44AAFF : 0x2277CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 83 / 100, Graphics.FONT_XTINY, "Tap to deal!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game board ────────────────────────────────────────────────────────────
    hidden function drawGame(dc) {
        // Background
        dc.setColor(0x0A1508, 0x0A1508); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0D3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 1);
        dc.setColor(0x114422, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 14);

        drawTopRow(dc);
        drawTableau(dc);
        drawHint(dc);
    }

    hidden function drawTopRow(dc) {
        var gap = 2;

        // Stock pile
        if (_pile[STOCK].size() > 0) {
            drawCardBack(dc, _stockX, _topRowY, _cw, _ch);
            if (_pile[STOCK].size() > 1) {
                // Show depth by drawing a second back slightly offset
                drawCardBack(dc, _stockX + 1, _topRowY + 1, _cw, _ch);
                drawCardBack(dc, _stockX, _topRowY, _cw, _ch);
            }
        } else {
            // Empty stock — recycle icon
            dc.setColor(0x0D3A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(_stockX, _topRowY, _cw, _ch, 3);
            dc.setColor(0x1A6030, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(_stockX, _topRowY, _cw, _ch, 3);
            dc.setColor(0x44AA66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_stockX + _cw/2, _topRowY + _ch/2 - 7,
                Graphics.FONT_XTINY, "\u21BA", Graphics.TEXT_JUSTIFY_CENTER);
        }
        // Cursor
        if (_cursor == STOCK && _selPile < 0) {
            drawCursor(dc, _stockX, _topRowY, _cw, _ch);
        }

        // Waste pile — show up to 3 fanned cards for draw-3, top card for draw-1
        var waste = _pile[WASTE];
        if (waste.size() == 0) {
            dc.setColor(0x0D3A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(_wasteX, _topRowY, _cw, _ch, 3);
            dc.setColor(0x1A6030, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(_wasteX, _topRowY, _cw, _ch, 3);
        } else {
            var show = (_drawMode == 3) ? 3 : 1;
            if (show > waste.size()) { show = waste.size(); }
            for (var i = show - 1; i >= 0; i--) {
                var card = waste[waste.size() - 1 - i];
                var wx = _wasteX + (_cw / 5) * (show - 1 - i);
                if (card >= 0) {
                    drawCardFace(dc, wx, _topRowY, _cw, _ch, card,
                        (i == 0)); // only top is fully drawn
                }
            }
        }
        // Selected waste highlight
        var wasteSel = (_selPile == WASTE);
        if (_cursor == WASTE && _selPile < 0) {
            drawCursor(dc, _wasteX, _topRowY, _cw, _ch);
        } else if (wasteSel) {
            drawSelected(dc, _wasteX, _topRowY, _cw, _ch);
        }

        // Foundations (4 suits, right-aligned over cols 3-6)
        for (var f = 0; f < 4; f++) {
            var fx = _colX[3 + f];
            var found = _pile[FOUND_OFF + f];
            if (found.size() == 0) {
                // Empty foundation — show suit placeholder
                dc.setColor(0x0D3A1A, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(fx, _foundY, _cw, _ch, 3);
                dc.setColor(0x226644, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(fx, _foundY, _cw, _ch, 3);
                var isRed = (f == 1 || f == 2);
                dc.setColor(isRed ? 0x993333 : 0x777799, Graphics.COLOR_TRANSPARENT);
                dc.drawText(fx + _cw / 2, _foundY + _ch / 2 - 6,
                    Graphics.FONT_XTINY, _suitStr[f], Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                drawCardFace(dc, fx, _foundY, _cw, _ch, found[found.size()-1], true);
            }
            if (_cursor == FOUND_OFF + f && _selPile < 0) {
                drawCursor(dc, fx, _foundY, _cw, _ch);
            } else if (_selPile == FOUND_OFF + f) {
                drawSelected(dc, fx, _foundY, _cw, _ch);
            }
        }
    }

    hidden function drawTableau(dc) {
        for (var c = 0; c < 7; c++) {
            var cx  = _colX[c];
            var tab = _pile[TAB_OFF + c];
            var sel = (TAB_OFF + c == _selPile);
            var cur = (TAB_OFF + c == _cursor);

            if (tab.size() == 0) {
                // Empty column placeholder
                dc.setColor(0x0D3A1A, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx, _colY, _cw, _ch, 3);
                dc.setColor(0x1A5030, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(cx, _colY, _cw, _ch, 3);
                if (cur && _selPile < 0) { drawCursor(dc, cx, _colY, _cw, _ch); }
                continue;
            }

            for (var i = 0; i < tab.size(); i++) {
                var card = tab[i];
                var cy   = _colY + i * _fanOff;
                var isSel = sel && (i >= _selCard);
                var isLast = (i == tab.size() - 1);
                var cardH = isLast ? _ch : _fanOff + 2;

                if (card < 0) {
                    drawCardBackH(dc, cx, cy, _cw, cardH);
                } else {
                    drawCardFaceH(dc, cx, cy, _cw, cardH, card, isLast);
                }
                if (isSel) {
                    dc.setColor(0x88FFCC, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(cx, cy, _cw, cardH);
                }
            }
            // Cursor on column
            if (cur && !sel) {
                var topY = _colY + (tab.size() > 0 ? (tab.size()-1) * _fanOff : 0);
                drawCursor(dc, cx, topY, _cw, _ch);
            }
        }
    }

    hidden function drawHint(dc) {
        // Place hint safely above the bottom clip zone of the round screen
        var hintY = _h - 18;
        var moveLabel = (_selPile >= 0) ? "tap dest / \u2190cancel" : "tap card \u25B2\u25BC sel";
        dc.setColor(0x2A6040, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, hintY, Graphics.FONT_XTINY, moveLabel, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawWinOverlay(dc) {
        // Pulsing "YOU WIN" banner
        var blink = (_winTick % 8 < 4);
        if (!blink) { return; }
        var bw = _w * 78 / 100;
        dc.setColor(0x0A1508, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle((_w - bw)/2, _h/2 - 26, bw, 52, 8);
        dc.setColor(0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle((_w - bw)/2, _h/2 - 26, bw, 52, 8);
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 22, Graphics.FONT_MEDIUM, "YOU WIN!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_winTick % 12 < 6) ? 0x44AAFF : 0x2277CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 + 4, Graphics.FONT_XTINY, "Tap for new game", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Card drawing primitives ───────────────────────────────────────────────

    // Full face-down card (stock / unflipped tableau)
    hidden function drawCardBack(dc, x, y, w, h) {
        // Navy body
        dc.setColor(0x1C2F9A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 2);
        // Diagonal line pattern
        dc.setColor(0x2A44C0, Graphics.COLOR_TRANSPARENT);
        var step = (w > 12) ? 4 : 3;
        for (var d = -h; d < w + h; d += step) {
            dc.drawLine(x + d, y, x + d + h, y + h);
        }
        // Border
        dc.setColor(0x4A64D8, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 2);
    }

    // Partial (fanned) face-down card — only top strip drawn
    hidden function drawCardBackH(dc, x, y, w, h) {
        dc.setColor(0x1C2F9A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);
        dc.setColor(0x2A44C0, Graphics.COLOR_TRANSPARENT);
        var step = (w > 12) ? 4 : 3;
        for (var d = -h; d < w + h; d += step) {
            dc.drawLine(x + d, y, x + d + h, y + h);
        }
        dc.setColor(0x4A64D8, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y, x + w, y);
        dc.drawLine(x, y, x, y + h);
        dc.drawLine(x + w - 1, y, x + w - 1, y + h);
    }

    // Full face-up card
    hidden function drawCardFace(dc, x, y, w, h, card, full) {
        var rank  = card / 4;
        var suit  = card % 4;
        var isRed = (suit == 1 || suit == 2);

        // Card body — bright white, visible on green felt
        dc.setColor(0xF8F8F4, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 2);
        // Subtle border
        dc.setColor(isRed ? 0xBB4444 : 0x445588, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 2);

        var tc = isRed ? 0xCC0000 : 0x111122;
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        // Rank — top-left, 1px from edges
        dc.drawText(x + 2, y + 1, Graphics.FONT_XTINY, _rankStr[rank], Graphics.TEXT_JUSTIFY_LEFT);
        // Suit — just below rank
        dc.drawText(x + 2, y + 9, Graphics.FONT_XTINY, _suitStr[suit], Graphics.TEXT_JUSTIFY_LEFT);
        // Large centre suit on full (last) card when tall enough
        if (full && h >= 26) {
            dc.drawText(x + w / 2, y + h / 2 - 6, Graphics.FONT_XTINY, _suitStr[suit], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Partial (fanned) face-up card — shows rank + suit in top strip
    hidden function drawCardFaceH(dc, x, y, w, h, card, full) {
        if (full) { drawCardFace(dc, x, y, w, h, card, true); return; }
        var rank  = card / 4;
        var suit  = card % 4;
        var isRed = (suit == 1 || suit == 2);

        dc.setColor(0xF8F8F4, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);

        var tc = isRed ? 0xCC0000 : 0x111122;
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 2, y + 1, Graphics.FONT_XTINY, _rankStr[rank], Graphics.TEXT_JUSTIFY_LEFT);
        if (h >= 12) {
            dc.drawText(x + 2, y + 9, Graphics.FONT_XTINY, _suitStr[suit], Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Top / left / right borders only (bottom is hidden by next card)
        dc.setColor(isRed ? 0xBB4444 : 0x445588, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y, x + w, y);
        dc.drawLine(x, y, x, y + h);
        dc.drawLine(x + w - 1, y, x + w - 1, y + h);
    }

    hidden function drawCursor(dc, x, y, w, h) {
        dc.setColor(0xFFEE33, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x - 1, y - 1, w + 2, h + 2, 3);
        dc.drawRoundedRectangle(x - 2, y - 2, w + 4, h + 4, 4);
    }

    hidden function drawSelected(dc, x, y, w, h) {
        dc.setColor(0x33FFCC, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x - 1, y - 1, w + 2, h + 2, 3);
        dc.drawRoundedRectangle(x - 2, y - 2, w + 4, h + 4, 4);
    }
}
