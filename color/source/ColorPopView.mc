using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;

// ─────────────────────────────────────────────────────────────────────────────
//  ColorPopView  –  DIAMONDS  –  Match-3 gem puzzle
//
//  Controls:
//    TAP/SELECT  → select gem under cursor; if gem already selected and
//                  cursor is adjacent → swap; otherwise move selection
//    MENU        → advance cursor right→down (navigation)
//    UP / DOWN   → move cursor up / down (navigation, clears selection)
//    BACK        → return to menu
// ─────────────────────────────────────────────────────────────────────────────

const VS_MENU     = 0;
const VS_PLAY     = 1;
const VS_LEVEL_UP = 2;
const VS_OVER     = 3;

class ColorPopView extends WatchUi.View {

    hidden var _game;
    hidden var _timer;
    hidden var _tick;
    hidden var _vs;

    // Cursor + selection
    hidden var _curR; hidden var _curC;
    hidden var _selR; hidden var _selC;   // -1 = nothing selected

    // Animation counters
    hidden var _flashTick;    // invalid-move flash
    hidden var _bannerTick;   // level-up banner duration
    hidden var _msgTick;      // combo/floating message
    hidden var _msg;

    // Board geometry (pixels)
    hidden var _bX; hidden var _bY;
    hidden var _cellW;
    hidden var _w; hidden var _h;

    // ── Gem colors ────────────────────────────────────────────────────────────

    hidden function gemFill(colorId) {
        if (colorId == 1) { return 0xFF4444; }   // Red
        if (colorId == 2) { return 0x4488FF; }   // Blue
        if (colorId == 3) { return 0x44EE66; }   // Green
        if (colorId == 4) { return 0xFFDD22; }   // Yellow
        if (colorId == 5) { return 0xCC44FF; }   // Purple
        return 0x44DDFF;
    }

    hidden function gemDark(colorId) {
        if (colorId == 1) { return 0x881818; }
        if (colorId == 2) { return 0x183A88; }
        if (colorId == 3) { return 0x187733; }
        if (colorId == 4) { return 0x886600; }
        if (colorId == 5) { return 0x661888; }
        return 0x186677;
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        _game = new ColorPopGame();
        _tick = 0; _vs = VS_MENU;
        _curR = CP_ROWS / 2; _curC = CP_COLS / 2;
        _selR = -1; _selC = -1;
        _flashTick = 0; _bannerTick = 0;
        _msgTick = 0; _msg = "";
        _w = 0; _h = 0;
    }

    function onLayout(dc) {}

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 100, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() as Void {
        _tick++;
        if (_flashTick > 0)  { _flashTick--; }
        if (_msgTick > 0)    { _msgTick--; }
        if (_bannerTick > 0) { _bannerTick--; }

        if (_game.levelClear && _vs == VS_PLAY) {
            _vs = VS_LEVEL_UP; _bannerTick = 28;
        }
        if (_game.gameOver && _vs == VS_PLAY) {
            _vs = VS_OVER;
        }
        if (_vs == VS_LEVEL_UP && _bannerTick == 0) {
            _game.advanceLevel();
            _vs = VS_PLAY;
            _selR = -1; _selC = -1;
            _curR = CP_ROWS / 2; _curC = CP_COLS / 2;
        }

        WatchUi.requestUpdate();
    }

    // ── Input handlers ────────────────────────────────────────────────────────

    function onSelect() {
        if (_vs == VS_MENU)     { _game.initialize(); _vs = VS_PLAY; return; }
        if (_vs == VS_OVER)     { _game.initialize(); _vs = VS_MENU; return; }
        if (_vs == VS_LEVEL_UP) { return; }
        if (_vs != VS_PLAY)     { return; }

        if (_selR == -1) {
            // No gem selected — select cursor gem
            if (_game.grid[_curR * CP_COLS + _curC] != GEM_EMPTY) {
                _selR = _curR; _selC = _curC;
            }
        } else if (_selR == _curR && _selC == _curC) {
            // Same gem tapped again — deselect
            _selR = -1; _selC = -1;
        } else {
            var dr = _selR - _curR; if (dr < 0) { dr = -dr; }
            var dc = _selC - _curC; if (dc < 0) { dc = -dc; }
            if (dr + dc == 1) {
                // Adjacent — do the swap
                var ok = _game.trySwap(_selR, _selC, _curR, _curC);
                _selR = -1; _selC = -1;
                if (!ok) {
                    _flashTick = 8;
                } else if (_game.totalCombo > 1) {
                    _msg = "COMBO x" + _game.totalCombo + "!";
                    _msgTick = 8;
                }
            } else {
                // Not adjacent — move selection to cursor gem
                if (_game.grid[_curR * CP_COLS + _curC] != GEM_EMPTY) {
                    _selR = _curR; _selC = _curC;
                } else {
                    _selR = -1; _selC = -1;
                }
            }
        }
    }

    // MENU: advance cursor right → down (navigation only)
    function onMenu() {
        if (_vs != VS_PLAY) { return; }
        _selR = -1; _selC = -1;
        _curC++;
        if (_curC >= CP_COLS) { _curC = 0; _curR = (_curR + 1) % CP_ROWS; }
    }

    // UP: move cursor up
    function onUp() {
        if (_vs != VS_PLAY) { return; }
        _selR = -1; _selC = -1;
        _curR = (_curR - 1 + CP_ROWS) % CP_ROWS;
    }

    // DOWN: move cursor down
    function onDown() {
        if (_vs != VS_PLAY) { return; }
        _selR = -1; _selC = -1;
        _curR = (_curR + 1) % CP_ROWS;
    }

    function onBack() {
        if (_vs == VS_PLAY || _vs == VS_OVER || _vs == VS_LEVEL_UP) {
            _vs = VS_MENU;
            _selR = -1; _selC = -1;
            return true;
        }
        return false;
    }

    function isPlaying() { return _vs == VS_PLAY; }

    // ── Geometry ──────────────────────────────────────────────────────────────

    hidden function setupGeometry() {
        var hudH  = 22;
        var botH  = 15;
        var availH = _h - hudH - botH - 2;
        var availW = _w - 8;
        var cw = availW / CP_COLS;
        var ch = availH / CP_ROWS;
        _cellW = (cw < ch) ? cw : ch;
        if (_cellW < 12) { _cellW = 12; }
        if (_cellW > 38) { _cellW = 38; }
        _bX = (_w - CP_COLS * _cellW) / 2;
        _bY = hudH + 1;
    }

    // Center pixel of cell (c,r)
    hidden function cellCx(c) { return _bX + c * _cellW + _cellW / 2; }
    hidden function cellCy(r) { return _bY + r * _cellW + _cellW / 2; }

    // ── Diamond rendering ─────────────────────────────────────────────────────
    //
    //  s = half-size of diamond (tip-to-center distance)
    //  Gem drawn as rotated square: top(cx,cy-s), right(cx+s,cy),
    //                               bottom(cx,cy+s), left(cx-s,cy)

    hidden function drawDiamond(dc, cx, cy, s, gemVal, selected) {
        var gType  = _game.gemType(gemVal);
        var gColor = _game.gemColor(gemVal);

        // Rainbow cycles through colors each tick
        var fillC;
        var darkC;
        if (gColor == 0) {
            var phase = _tick % 8;
            if      (phase < 2) { fillC = 0xFF4444; }
            else if (phase < 4) { fillC = 0xFFDD22; }
            else if (phase < 6) { fillC = 0x44EE66; }
            else                { fillC = 0x4488FF; }
            darkC = 0x222233;
        } else {
            fillC = gemFill(gColor);
            darkC = gemDark(gColor);
        }

        // Selection ring (pulsing outer diamond)
        if (selected) {
            var rs = (_tick % 6 < 3) ? s + 3 : s + 4;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx, cy - rs], [cx + rs, cy], [cx, cy + rs], [cx - rs, cy]]);
            dc.setColor(0x060C18, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx, cy - rs + 2], [cx + rs - 2, cy], [cx, cy + rs - 2], [cx - rs + 2, cy]]);
        }

        // Drop shadow (+1, +1)
        dc.setColor(darkC, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx + 1, cy - s], [cx + s + 1, cy], [cx + 1, cy + s], [cx - s + 1, cy]]);

        // Main body
        dc.setColor(fillC, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, cy - s], [cx + s, cy], [cx, cy + s], [cx - s, cy]]);

        // Top-left highlight facet (white shimmer)
        var hs = s / 3;
        if (hs > 1) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - hs, cy - s + hs], [cx, cy - s + hs * 2],
                            [cx - hs, cy - hs], [cx - s + hs, cy - hs]]);
        }

        // Power gem marker on top of diamond
        if (gType == 2) {
            // BOMB — × cross
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 3, cy - 1, 7, 2);
            dc.fillRectangle(cx - 1, cy - 3, 2, 7);
        } else if (gType == 3) {
            // STAR — diamond outline
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx, cy - 3, cx + 3, cy);
            dc.drawLine(cx + 3, cy, cx, cy + 3);
            dc.drawLine(cx, cy + 3, cx - 3, cy);
            dc.drawLine(cx - 3, cy, cx, cy - 3);
        } else if (gType == 4) {
            // CROSS — + lines
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - 3, cy, cx + 3, cy);
            dc.drawLine(cx, cy - 3, cx, cy + 3);
        } else if (gType == 5) {
            // RAINBOW — 4-ray star burst
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - 3, cy - 3, cx + 3, cy + 3);
            dc.drawLine(cx + 3, cy - 3, cx - 3, cy + 3);
            dc.drawLine(cx - 3, cy, cx + 3, cy);
            dc.drawLine(cx, cy - 3, cx, cy + 3);
        }
    }

    // ── Main render dispatch ──────────────────────────────────────────────────

    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGeometry(); }
        dc.setColor(0x060C18, 0x060C18); dc.clear();

        if      (_vs == VS_MENU)  { drawMenu(dc); }
        else if (_vs == VS_OVER)  { drawOver(dc); }
        else {
            drawPlay(dc);
            if (_vs == VS_LEVEL_UP) { drawLevelUp(dc); }
        }
    }

    // ── Gameplay screen ───────────────────────────────────────────────────────

    hidden function drawPlay(dc) {
        drawHUD(dc);
        drawBoard(dc);
        drawBottomBar(dc);
        if (_msgTick > 0) {
            dc.setColor((_tick % 4 < 2) ? 0xFFFF44 : 0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h / 2 - 6, Graphics.FONT_XTINY, _msg, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0x0A1422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, 20);

        // Score progress toward level target (left)
        var ls = _game.score - _game.levelBase;
        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 2, Graphics.FONT_XTINY,
            _game.fmt(ls) + "/" + _game.fmt(_game.levelTarget),
            Graphics.TEXT_JUSTIFY_LEFT);

        // Level (center)
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, 2, Graphics.FONT_XTINY, "Lv" + _game.level, Graphics.TEXT_JUSTIFY_CENTER);

        // Moves left (right) — red when ≤ 5
        var mc = (_game.movesLeft <= 5) ? 0xFF4444 : 0xAABBCC;
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 4, 2, Graphics.FONT_XTINY, _game.movesLeft + "\u25c6", Graphics.TEXT_JUSTIFY_RIGHT);

        // Progress bar (green when complete)
        var pct = ls.toFloat() / _game.levelTarget.toFloat();
        if (pct > 1.0) { pct = 1.0; }
        dc.setColor(0x1A2A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 18, _w, 2);
        dc.setColor(pct >= 1.0 ? 0x44FF88 : 0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 18, (_w.toFloat() * pct).toNumber(), 2);
    }

    hidden function drawBoard(dc) {
        var bx = _bX; var by = _bY; var cw = _cellW;
        var s  = cw / 2 - 2;

        // Board background
        dc.setColor(0x0A1620, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx - 2, by - 2, CP_COLS * cw + 4, CP_ROWS * cw + 4);

        // Gems
        for (var r = 0; r < CP_ROWS; r++) {
            for (var c = 0; c < CP_COLS; c++) {
                var v = _game.grid[r * CP_COLS + c];
                if (v == GEM_EMPTY) { continue; }
                var cx = bx + c * cw + cw / 2;
                var cy = by + r * cw + cw / 2;
                var isSel = (_selR == r && _selC == c);
                drawDiamond(dc, cx, cy, s, v, isSel);
            }
        }

        // Cursor (corner brackets)
        drawCursor(dc, s);

        // Invalid-swap flash — red X over cursor gem
        if (_flashTick > 0 && _flashTick % 2 == 0) {
            var fx = bx + _curC * cw + cw / 2;
            var fy = by + _curR * cw + cw / 2;
            dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(fx - s, fy - s, fx + s, fy + s);
            dc.drawLine(fx + s, fy - s, fx - s, fy + s);
        }
    }

    hidden function drawCursor(dc, s) {
        if (_selR == _curR && _selC == _curC) { return; }  // selected gem already highlighted

        var cx = cellCx(_curC);
        var cy = cellCy(_curR);
        var cc = (_tick % 8 < 4) ? 0xFFFFFF : 0x88AABB;
        dc.setColor(cc, Graphics.COLOR_TRANSPARENT);

        // Corner brackets (4 corners × 2 lines each)
        dc.fillRectangle(cx - s, cy - s, 4, 2);
        dc.fillRectangle(cx - s, cy - s, 2, 4);
        dc.fillRectangle(cx + s - 4, cy - s, 4, 2);
        dc.fillRectangle(cx + s - 2, cy - s, 2, 4);
        dc.fillRectangle(cx - s, cy + s - 2, 4, 2);
        dc.fillRectangle(cx - s, cy + s - 4, 2, 4);
        dc.fillRectangle(cx + s - 4, cy + s - 2, 4, 2);
        dc.fillRectangle(cx + s - 2, cy + s - 4, 2, 4);

        // Line from selected gem to cursor (green = adjacent, blue = not)
        if (_selR != -1) {
            var sx = cellCx(_selC); var sy = cellCy(_selR);
            var dr = _selR - _curR; if (dr < 0) { dr = -dr; }
            var dc2 = _selC - _curC; if (dc2 < 0) { dc2 = -dc2; }
            var lc = (dr + dc2 == 1) ? 0x44FF88 : 0x4466AA;
            dc.setColor(lc, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx, sy, cx, cy);
        }
    }

    hidden function drawBottomBar(dc) {
        dc.setColor(0x0A1422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - 13, _w, 13);
        if (_selR == -1) {
            dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h - 12, Graphics.FONT_XTINY,
                "TAP=pick  MENU/UP/DN=move", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x44AA66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h - 12, Graphics.FONT_XTINY,
                "Move to adj \u25c6 then TAP", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Level-up overlay (shown on top of frozen board) ───────────────────────

    hidden function drawLevelUp(dc) {
        // Semi-transparent dark overlay
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w / 4, _h * 26 / 100, _w / 2, _h * 32 / 100);

        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_MEDIUM,
            "LEVEL " + _game.level + "!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 42 / 100, Graphics.FONT_XTINY,
            levelName(_game.level), Graphics.TEXT_JUSTIFY_CENTER);

        if (_game.numColors == 5 && _game.level == 3) {
            dc.setColor(0x44EE66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 52 / 100, Graphics.FONT_XTINY,
                "+5th color!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function levelName(lv) {
        if (lv == 2)  { return "Amateur"; }
        if (lv == 3)  { return "Skilled  +5 colors"; }
        if (lv == 4)  { return "Expert"; }
        if (lv == 5)  { return "Master  +Bomb gems"; }
        if (lv == 6)  { return "Grandmaster"; }
        if (lv == 7)  { return "Champion  +Star gems"; }
        if (lv == 8)  { return "Legend"; }
        if (lv == 9)  { return "Mythic  +Cross gems"; }
        if (lv >= 10) { return "DIVINE  Lv" + lv; }
        return "Novice";
    }

    // ── Menu screen ───────────────────────────────────────────────────────────

    hidden function drawMenu(dc) {
        var w = _w; var h = _h;

        // 5 animated diamonds across top area
        var gemRowY = h * 36 / 100;
        var s = 12;  // half-size for menu diamonds
        for (var i = 0; i < 5; i++) {
            var gx = w * (10 + i * 20) / 100;
            var wob = ((_tick / 5 + i * 3) % 5) - 2;
            // Use temporary _cellW for sizing within drawDiamond
            var savedCW = _cellW;
            _cellW = s * 2 + 4;
            if (_cellW < 12) { _cellW = 28; }
            drawDiamond(dc, gx, gemRowY + wob, s, i + 1, false);
            _cellW = savedCW;
        }

        // Title
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + 1, h * 5 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 14 < 7) ? 0x4466FF : 0x2244DD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 17 / 100, Graphics.FONT_LARGE, "DIAMONDS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x557799, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 28 / 100, Graphics.FONT_XTINY, "Match-3 gem puzzle", Graphics.TEXT_JUSTIFY_CENTER);

        // Best score
        if (_game.best > 0) {
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 54 / 100, Graphics.FONT_XTINY,
                "BEST: " + _game.fmt(_game.best), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // How to play
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 63 / 100, Graphics.FONT_XTINY, "TAP gem, TAP adj gem = swap", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 71 / 100, Graphics.FONT_XTINY, "MENU / UP / DN = move cursor", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 79 / 100, Graphics.FONT_XTINY, "3+ same color = match!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0x4466FF : 0x2244DD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 90 / 100, Graphics.FONT_XTINY, "Tap to play!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game Over screen ──────────────────────────────────────────────────────

    hidden function drawOver(dc) {
        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 8 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 24 / 100, Graphics.FONT_LARGE,
            _game.fmt(_game.score), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 40 / 100, Graphics.FONT_XTINY,
            "SCORE  |  Level " + _game.level, Graphics.TEXT_JUSTIFY_CENTER);

        if (_game.score >= _game.best && _game.score > 0) {
            dc.setColor((_tick % 6 < 3) ? 0xFFDD22 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_XTINY, "\u2605 NEW BEST! \u2605", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_XTINY,
                "Best: " + _game.fmt(_game.best), Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0x4466FF : 0x2244DD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
