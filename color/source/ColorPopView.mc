using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;

// ─────────────────────────────────────────────────────────────────────────────
//  ColorPopView  –  rendering + input coordination
//
//  UI states:
//    VS_MENU     – title screen
//    VS_PLAY     – active gameplay
//    VS_SWAP_SEL – gem selected, choose swap direction
//    VS_POP_ANIM – brief pop animation before cascade
//    VS_LEVEL_UP – level clear banner
//    VS_OVER     – game over
// ─────────────────────────────────────────────────────────────────────────────

const VS_MENU     = 0;
const VS_PLAY     = 1;
const VS_SWAP_SEL = 2;  // gem A selected
const VS_LEVEL_UP = 3;
const VS_OVER     = 4;

class ColorPopView extends WatchUi.View {

    hidden var _game;
    hidden var _timer;
    hidden var _tick;
    hidden var _vs;       // view state

    // Cursor position on grid
    hidden var _curR; hidden var _curC;

    // Selected gem for swap
    hidden var _selR; hidden var _selC;

    // Animation
    hidden var _flashTick;    // countdown for swap-fail flash
    hidden var _msgTick;      // countdown for small floating message
    hidden var _msg;          // floating message text
    hidden var _bannerTick;   // countdown for level-up / combo banner
    hidden var _wobble;       // menu animation

    // Board pixel geometry (computed in onUpdate once _w/_h known)
    hidden var _bX; hidden var _bY;   // top-left of board in pixels
    hidden var _cellW; hidden var _cellH;
    hidden var _w; hidden var _h;

    // Gem color palette
    hidden var _gemColors;     // normal gem fill colors [1-5]
    hidden var _gemBright;     // bright variant for highlight

    function initialize() {
        View.initialize();
        _game  = new ColorPopGame();
        _tick  = 0; _vs = VS_MENU;
        _curR  = 2; _curC  = 2;
        _selR  = -1; _selC = -1;
        _flashTick = 0; _msgTick = 0; _msg = "";
        _bannerTick = 0; _wobble = 0.0;
        _w = 0; _h = 0;

        // Colors: RED, ORANGE, GREEN, BLUE, PURPLE
        _gemColors = [0xDD2222, 0xFF7700, 0x22BB33, 0x2255EE, 0xAA22CC];
        _gemBright = [0xFF5555, 0xFFAA44, 0x44FF66, 0x55AAFF, 0xCC55FF];
    }

    function onLayout(dc) {}

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 120, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() as Void {
        _tick++;
        _wobble += 0.10;
        if (_flashTick > 0)  { _flashTick--; }
        if (_msgTick > 0)    { _msgTick--; }
        if (_bannerTick > 0) { _bannerTick--; }

        // Check if game advanced level
        if (_game.levelClear && _vs == VS_PLAY) {
            _vs = VS_LEVEL_UP; _bannerTick = 20;
        }
        if (_game.gameOver && _vs == VS_PLAY) {
            _vs = VS_OVER;
        }

        // After level-up banner expires, auto-advance
        if (_vs == VS_LEVEL_UP && _bannerTick == 0) {
            _game.advanceLevel();
            _vs = VS_PLAY;
            _curR = 2; _curC = 2;
        }

        WatchUi.requestUpdate();
    }

    // ── Input handlers ────────────────────────────────────────────────────────

    // ── Controls ──────────────────────────────────────────────────────────────
    //
    //  MOVE mode  (navigating the grid):
    //    UP / DOWN   → move cursor row
    //    TAP (SELECT)→ move cursor column RIGHT (wraps 0→4→0)
    //    MENU        → pick gem → enter SWAP mode
    //    BACK        → exit to menu
    //
    //  SWAP mode  (gem selected, choosing direction):
    //    UP          → swap with gem above
    //    DOWN        → swap with gem below
    //    TAP (SELECT)→ swap with gem to the RIGHT
    //    MENU        → swap with gem to the LEFT
    //    BACK        → cancel, return to MOVE mode

    function onSelect() {
        if (_vs == VS_MENU)     { _game.initialize(); _vs = VS_PLAY; return; }
        if (_vs == VS_OVER)     { _game.initialize(); _vs = VS_MENU; return; }
        if (_vs == VS_LEVEL_UP) { return; }

        if (_vs == VS_PLAY) {
            // TAP cycles column right — the main way to reach any gem
            _curC = (_curC + 1) % CP_COLS;
        } else if (_vs == VS_SWAP_SEL) {
            doSwap(_selR, _selC, _selR, _selC + 1);
        }
    }

    function onMenu() {
        if (_vs == VS_PLAY) {
            // MENU picks the current gem for swapping
            _selR = _curR; _selC = _curC;
            _vs = VS_SWAP_SEL;
        } else if (_vs == VS_SWAP_SEL) {
            doSwap(_selR, _selC, _selR, _selC - 1);
        }
    }

    function onUp() {
        if (_vs == VS_PLAY || _vs == VS_MENU) {
            _curR = (_curR + CP_ROWS - 1) % CP_ROWS;  // wrap top
        } else if (_vs == VS_SWAP_SEL) {
            doSwap(_selR, _selC, _selR - 1, _selC);
        }
    }

    function onDown() {
        if (_vs == VS_PLAY || _vs == VS_MENU) {
            _curR = (_curR + 1) % CP_ROWS;  // wrap bottom
        } else if (_vs == VS_SWAP_SEL) {
            doSwap(_selR, _selC, _selR + 1, _selC);
        }
    }

    function onBack() {
        if (_vs == VS_SWAP_SEL) {
            _vs = VS_PLAY; _selR = -1; _selC = -1; return true;
        }
        if (_vs == VS_PLAY || _vs == VS_OVER || _vs == VS_LEVEL_UP) {
            _vs = VS_MENU; return true;
        }
        return false;
    }

    hidden function doSwap(r1, c1, r2, c2) {
        var ok = _game.trySwap(r1, c1, r2, c2);
        if (ok) {
            _vs = VS_PLAY;
            _selR = -1; _selC = -1;
            if (_game.totalCombo > 1) {
                showMsg("COMBO x" + _game.totalCombo + "!");
            }
        } else {
            _flashTick = 4;
            showMsg("No match");
            _vs = VS_PLAY;
            _selR = -1; _selC = -1;
        }
    }

    function isPlaying() { return _vs == VS_PLAY || _vs == VS_SWAP_SEL; }

    hidden function showMsg(txt) {
        _msg = txt; _msgTick = 6;
    }

    // ── Board geometry setup ──────────────────────────────────────────────────

    hidden function setupGeometry() {
        var hudH = 20;   // top HUD
        var botH = 18;   // bottom hint bar
        var padH = 2;
        var availH = _h - hudH - botH - padH * 2;
        var availW = _w - 4;

        _cellW = availW / CP_COLS;
        _cellH = availH / CP_ROWS;
        if (_cellW > _cellH) { _cellW = _cellH; }
        if (_cellH > _cellW) { _cellH = _cellW; }
        if (_cellW < 10) { _cellW = 10; }
        if (_cellW > 34) { _cellW = 34; }

        _bX = (_w - CP_COLS * _cellW) / 2;
        _bY = hudH + padH;
    }

    // ── Main render ───────────────────────────────────────────────────────────

    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeometry(); }

        dc.setColor(0x060C18, 0x060C18); dc.clear();

        if (_vs == VS_MENU)                  { drawMenu(dc); }
        else if (_vs == VS_OVER)             { drawOver(dc); }
        else if (_vs == VS_LEVEL_UP)         { drawLevelUp(dc); }
        else                                 { drawPlay(dc); }
    }

    // ── Menu ─────────────────────────────────────────────────────────────────

    hidden function drawMenu(dc) {
        var w = _w; var h = _h;

        // Animated gem row
        var gColors = [0xDD2222, 0xFF7700, 0x22BB33, 0x2255EE, 0xAA22CC];
        var gemY = h * 25 / 100;
        var gemSpacing = w / 6;
        for (var i = 0; i < 5; i++) {
            var gx = gemSpacing + i * gemSpacing;
            var gy = gemY + (Math.sin(_wobble + i.toFloat() * 1.2) * 8.0).toNumber();
            dc.setColor(gColors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(gx - 9, gy - 9, 18, 18, 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(gx - 4, gy - 4, 4, 4);
        }

        dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 43 / 100, Graphics.FONT_MEDIUM, "COLOR POP", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x335577, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 57 / 100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        if (_game.best > 0) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 67 / 100, Graphics.FONT_XTINY, "BEST: " + _game.fmt(_game.best), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Mini how-to-play
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 71 / 100, Graphics.FONT_XTINY, "Match 3+ gems of same color", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x224433, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 79 / 100, Graphics.FONT_XTINY, "UP/DN row  TAP col  MENU pick", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 12 < 6) ? 0xFFEE44 : 0xBBAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 91 / 100, Graphics.FONT_XTINY, "Tap to play!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Gameplay ─────────────────────────────────────────────────────────────

    hidden function drawPlay(dc) {
        drawHUD(dc);
        drawBoard(dc);
        drawBottomBar(dc);
        if (_msgTick > 0) { drawFloatingMsg(dc); }
    }

    hidden function drawHUD(dc) {
        var w = _w;
        dc.setColor(0x0A1A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 20);

        // Score / target  e.g.  "320 / 800"
        var levelScore = _game.score - _game.levelBase;
        dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 2, Graphics.FONT_XTINY,
            _game.fmt(levelScore) + "/" + _game.fmt(_game.levelTarget),
            Graphics.TEXT_JUSTIFY_LEFT);

        // Level (center)
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 2, Graphics.FONT_XTINY, "LV" + _game.level, Graphics.TEXT_JUSTIFY_CENTER);

        // Moves left (right) — red when running low
        var mc = (_game.movesLeft <= 5) ? 0xFF4444 : 0xAABBCC;
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 4, 2, Graphics.FONT_XTINY, _game.movesLeft + "mv", Graphics.TEXT_JUSTIFY_RIGHT);

        // Level progress bar (yellow fill = score toward target)
        var pct = levelScore.toFloat() / _game.levelTarget.toFloat();
        if (pct > 1.0) { pct = 1.0; }
        var barW = (w.toFloat() * pct).toNumber();
        dc.setColor(0x1A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 17, w, 3);
        dc.setColor(pct >= 1.0 ? 0x44FF88 : 0xFFEE44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 17, barW, 3);
    }

    hidden function drawBoard(dc) {
        var bx = _bX; var by = _bY;
        var cw = _cellW; var ch = _cellH;

        // Board background
        dc.setColor(0x0A1620, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx - 1, by - 1, CP_COLS * cw + 2, CP_ROWS * ch + 2);

        for (var r = 0; r < CP_ROWS; r++) {
            for (var c = 0; c < CP_COLS; c++) {
                var px = bx + c * cw; var py = by + r * ch;
                var v  = _game.grid[r * CP_COLS + c];

                // Cell background (checkerboard)
                var chk = ((r + c) % 2 == 0) ? 0x0D1E2E : 0x0A1828;
                dc.setColor(chk, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(px, py, cw, ch);

                if (v == GEM_EMPTY) { continue; }

                drawGem(dc, px, py, cw, ch, v, r, c);
            }
        }

        // Grid lines
        dc.setColor(0x152535, Graphics.COLOR_TRANSPARENT);
        for (var cc = 0; cc <= CP_COLS; cc++) {
            dc.drawLine(bx + cc * cw, by, bx + cc * cw, by + CP_ROWS * ch);
        }
        for (var rr = 0; rr <= CP_ROWS; rr++) {
            dc.drawLine(bx, by + rr * ch, bx + CP_COLS * cw, by + rr * ch);
        }

        // Cursor or selection highlight
        drawCursor(dc);
    }

    hidden function drawGem(dc, px, py, cw, ch, v, r, c) {
        var gType = _game.gemType(v);
        var gCol  = _game.gemColor(v);
        var fillC;
        var brightC;

        if (gCol >= 1 && gCol <= 5) {
            fillC   = _gemColors[gCol - 1];
            brightC = _gemBright[gCol - 1];
        } else {
            fillC   = 0xFFFFFF; brightC = 0xFFFFFF;
        }

        if (gType == 1) {
            // Normal gem: rounded square with highlight dot
            dc.setColor(fillC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(px + 2, py + 2, cw - 4, ch - 4, 3);
            dc.setColor(brightC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + 4, py + 4, 4, 3);

        } else if (gType == 2) {
            // BOMB gem: darker fill, ★ symbol
            dc.setColor(fillC & 0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(px + 2, py + 2, cw - 4, ch - 4, 3);
            dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + 2, py + 2, cw - 4, ch - 4);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(px + cw / 2, py + ch / 2 - 6, Graphics.FONT_XTINY, "B", Graphics.TEXT_JUSTIFY_CENTER);
            // Color dot
            dc.setColor(fillC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw - 4, py + 3, 2);

        } else if (gType == 3) {
            // STAR gem: bright outline, ✦ symbol
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(px + 2, py + 2, cw - 4, ch - 4, 3);
            dc.setColor(fillC, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(px + 2, py + 2, cw - 4, ch - 4, 3);
            dc.drawText(px + cw / 2, py + ch / 2 - 6, Graphics.FONT_XTINY, "*", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(brightC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(px + cw / 2, py + ch / 2 - 6, Graphics.FONT_XTINY, "*", Graphics.TEXT_JUSTIFY_CENTER);

        } else if (gType == 4) {
            // CROSS gem: gradient lines (T-shape)
            dc.setColor(fillC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(px + 2, py + 2, cw - 4, ch - 4, 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px + cw / 2, py + 2, px + cw / 2, py + ch - 3);
            dc.drawLine(px + 2, py + ch / 2, px + cw - 3, py + ch / 2);

        } else if (gType == 5) {
            // RAINBOW gem: animated multi-color ring
            var rc = (_tick % 5 < 1) ? 0xFF2222 :
                     (_tick % 5 < 2) ? 0xFF8800 :
                     (_tick % 5 < 3) ? 0x22FF44 :
                     (_tick % 5 < 4) ? 0x2255FF : 0xAA22FF;
            dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw / 2, py + ch / 2, cw / 2 - 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw / 2, py + ch / 2, cw / 4);
        }
    }

    hidden function drawCursor(dc) {
        var bx = _bX; var by = _bY;
        var cw = _cellW; var ch = _cellH;

        if (_vs == VS_SWAP_SEL && _selR >= 0) {
            // Selected gem: bright thick pulsing border — very visible
            var sc = (_tick % 4 < 2) ? 0xFFFFFF : 0xFFDD44;
            dc.setColor(sc, Graphics.COLOR_TRANSPARENT);
            var sx = bx + _selC * cw; var sy = by + _selR * ch;
            dc.drawRectangle(sx,     sy,     cw,     ch);
            dc.drawRectangle(sx + 1, sy + 1, cw - 2, ch - 2);
            dc.drawRectangle(sx + 2, sy + 2, cw - 4, ch - 4);
        } else {
            // Normal cursor: solid white rectangle outline
            var cx = bx + _curC * cw; var cy = by + _curR * ch;
            var cc = (_flashTick > 0) ? 0xFF4444 : 0xFFFFFF;
            dc.setColor(cc, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(cx, cy, cw, ch);
            dc.drawRectangle(cx + 1, cy + 1, cw - 2, ch - 2);

            // Column indicator dots below the board (show current column)
            var dotY = by + CP_ROWS * ch + 3;
            for (var ci = 0; ci < CP_COLS; ci++) {
                var dotX = bx + ci * cw + cw / 2;
                if (ci == _curC) {
                    dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(dotX, dotY, 3);
                } else {
                    dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(dotX, dotY, 2);
                }
            }
        }
    }

    hidden function drawBottomBar(dc) {
        var w = _w; var h = _h;
        dc.setColor(0x0A1A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h - 18, w, 18);

        if (_vs == VS_SWAP_SEL) {
            // Swap mode: show directional swap options
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 17, Graphics.FONT_XTINY,
                "UP/DN swap  TAP right  MENU left", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // Move mode: show navigation controls
            dc.setColor(0x446688, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 17, Graphics.FONT_XTINY,
                "UP/DN row  TAP column  MENU pick", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawFloatingMsg(dc) {
        var mc = (_msg.find("COMBO") != null) ? 0xFFEE44 : 0xFF8888;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h / 2 - 8, _w, 16);
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h / 2 - 7, Graphics.FONT_XTINY, _msg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Level-up banner ───────────────────────────────────────────────────────

    hidden function drawLevelUp(dc) {
        var w = _w; var h = _h;

        // Show board faded behind
        drawBoard(dc);

        // Dark overlay
        dc.setColor(0x00000088, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 28 / 100, w, h * 44 / 100);

        var pulse = (_tick % 4 < 2) ? 0xFFEE44 : 0xFF8800;
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 30 / 100, Graphics.FONT_MEDIUM, "LEVEL UP!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 47 / 100, Graphics.FONT_SMALL,
            "Level " + (_game.level + 1), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 60 / 100, Graphics.FONT_XTINY,
            "Score: " + _game.fmt(_game.score), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game over ─────────────────────────────────────────────────────────────

    hidden function drawOver(dc) {
        var w = _w; var h = _h;
        dc.setColor(0x060C18, 0x060C18); dc.clear();

        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 10 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 28 / 100, Graphics.FONT_LARGE,
            _game.fmt(_game.score), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x446677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 46 / 100, Graphics.FONT_XTINY, "SCORE", Graphics.TEXT_JUSTIFY_CENTER);

        if (_game.score >= _game.best && _game.score > 0) {
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, h * 54 / 100 - 1, w, 18);
            dc.setColor((_tick % 8 < 4) ? 0xFFDD22 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 54 / 100, Graphics.FONT_XTINY, "★ NEW BEST! ★", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_game.best > 0) {
            dc.setColor(0x446677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 54 / 100, Graphics.FONT_XTINY, "Best: " + _game.fmt(_game.best), Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 63 / 100, Graphics.FONT_XTINY,
            "Level " + _game.level, Graphics.TEXT_JUSTIFY_CENTER);
        if (_game.totalCombo > 1) {
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 73 / 100, Graphics.FONT_XTINY,
                "Best combo x" + _game.totalCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 12 < 6) ? 0x44AAFF : 0x2277CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 87 / 100, Graphics.FONT_XTINY, "Tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
