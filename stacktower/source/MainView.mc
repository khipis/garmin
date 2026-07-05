// ═══════════════════════════════════════════════════════════════
// MainView.mc — Camera, tower → screen projection, render loop.
//
// The view runs a fixed ~33 ms (≈30 FPS) timer; per tick it advances
// the moving block and any falling overhangs, then requests a redraw.
// All numbers stay in plain ints for speed; the camera offset is a
// float to keep the scroll smooth as new blocks appear.
//
// Camera:
//   The screen-y for world-row R is:
//       screenY = floorY - (R - camRow) * BLOCK_H
//   where `floorY` is the bottom of the playable area and `camRow`
//   is a smoothed value that follows the latest top block once the
//   tower exceeds half-screen-height.
//
// Rendering modes (menuView):
//   2D — flat blocks with a bright top edge + dark bottom shadow.
//   3D — isometric-style prisms: lit top face + shaded right face
//        give each block real depth, like classic "stacker" games.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

const BLOCK_H  = 11;        // world/screen pixels per block layer
const TICK_MS  = 40;
const DEPTH_3D = 5;          // pseudo-3D prism depth in pixels

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _timer;

    // Cached layout
    hidden var _sw;
    hidden var _sh;
    hidden var _floorY;       // screen-y of the foundation top
    hidden var _camRow;       // smoothed camera row (float)
    hidden var _hudTop;       // y of the score HUD text
    hidden var _laidOut;
    hidden var _frame;        // free-running frame counter (twinkle/anim)

    // Starfield — fixed positions generated once per layout.
    hidden var _starX;
    hidden var _starY;
    hidden var _starPhase;
    hidden const _STAR_N = 22;

    function initialize() {
        View.initialize();
        _ctrl   = new GameController();
        _timer  = null;
        _sw = 0; _sh = 0; _floorY = 0;
        _camRow = 0.0;
        _hudTop = 0;
        _laidOut = false;
        _frame = 0;
        _starX = null; _starY = null; _starPhase = null;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), TICK_MS, true);
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() {
        _ctrl.step();
        _frame = _frame + 1;
        WatchUi.requestUpdate();
    }

    // ── Update / render ─────────────────────────────────────────────
    function onUpdate(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();
        if (!_laidOut) { _doLayout(); _laidOut = true; }

        // Smooth camera follow — keep top ~40% from the top of screen.
        var top = _ctrl.tower.topBlock();
        if (top != null) {
            var targetTopY = _sh * 30 / 100;
            var desired = top.row - (_floorY - targetTopY) * 1.0 / BLOCK_H;
            if (desired < 0) { desired = 0; }
            _camRow = _camRow + (desired - _camRow) * 0.18;
        }

        // Shake offset for game-over feedback
        var shx = 0;
        if (_ctrl.lastShake > 0) {
            shx = ((Math.rand() % 7) - 3);
        }

        _drawSky(dc);

        if (_ctrl.state == GS_MENU) { _drawMenu(dc); return; }

        _drawGround(dc, shx);
        _drawTower(dc, shx);
        _drawFalling(dc, shx);
        _drawMoving(dc, shx);
        _drawHUD(dc);
        if (_ctrl.state == GS_OVER) { _drawOver(dc); }
    }

    hidden function _doLayout() {
        // Playable horizontal strip — leave 6 px margin each side.
        var minX = 6;
        var maxX = _sw - 6;
        if (_sw == _sh) {
            var inset = _sw * 11 / 100;
            minX = inset; maxX = _sw - inset;
        }
        _ctrl.setWorldBounds(minX, maxX);

        _hudTop = _sh * 4 / 100; if (_hudTop < 3) { _hudTop = 3; }
        _floorY = _sh - (_sh * 8 / 100);
        if (_floorY > _sh - 12) { _floorY = _sh - 12; }
        _camRow = 0.0;

        // Deterministic-ish starfield spread over the top 55% of screen.
        _starX = new [_STAR_N];
        _starY = new [_STAR_N];
        _starPhase = new [_STAR_N];
        for (var i = 0; i < _STAR_N; i++) {
            _starX[i] = Math.rand() % _sw;
            _starY[i] = Math.rand() % ((_sh * 55) / 100);
            _starPhase[i] = Math.rand() % 40;
        }
    }

    // Convert world-y row to screen-y for the BOTTOM of that block.
    hidden function _rowBottomY(row) {
        var y = _floorY - (row - _camRow) * BLOCK_H;
        return y.toNumber();
    }

    // ── Background: deep-space vertical gradient + twinkling stars ───
    hidden function _drawSky(dc) {
        var topR = 2;  var topG = 4;  var topB = 14;
        var botR = 26; var botG = 16; var botB = 56;
        var bands = 12;
        var bh = (_sh / bands) + 1;
        for (var i = 0; i < bands; i++) {
            var t = i * 100 / (bands - 1);
            var r = topR + ((botR - topR) * t) / 100;
            var g = topG + ((botG - topG) * t) / 100;
            var b = topB + ((botB - topB) * t) / 100;
            var col = (r << 16) | (g << 8) | b;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, i * bh, _sw, bh + 1);
        }
        // Soft glowing moon, upper-right corner — purely decorative.
        var mx = _sw - _sw * 16 / 100;
        var my = _sh * 12 / 100;
        dc.setColor(0x1C2A44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, _sw * 8 / 100 + 4);
        dc.setColor(0xE8EEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, _sw * 7 / 100);

        if (_starX == null) { return; }
        for (var s = 0; s < _STAR_N; s++) {
            var ph = (_frame / 4 + _starPhase[s]) % 40;
            var bright = (ph < 20) ? (ph) : (40 - ph);   // 0..20 triangle wave
            if (bright < 6) { continue; }                 // mostly-dim = invisible
            var v = 0x40 + bright * 9; if (v > 0xFF) { v = 0xFF; }
            var col = (v << 16) | (v << 8) | 0xFF;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_starX[s], _starY[s], (bright > 14) ? 2 : 1, (bright > 14) ? 2 : 1);
        }
    }

    // A subtle glowing "stage" platform beneath the tower for grounding.
    hidden function _drawGround(dc, shx) {
        var w  = (_ctrl.worldMaxX - _ctrl.worldMinX) + 34;
        var cx = (_ctrl.worldMinX + _ctrl.worldMaxX) / 2 + shx;
        if (_ctrl.menuView == ST_VIEW_3D) {
            var depth = DEPTH_3D * 2;
            dc.setColor(0x15223A, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - w/2, _floorY],
                            [cx - w/2 + depth, _floorY - depth],
                            [cx + w/2 + depth, _floorY - depth],
                            [cx + w/2, _floorY]]);
            dc.setColor(0x2A4468, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - w/2, _floorY, cx - w/2 + depth, _floorY - depth);
            dc.drawLine(cx - w/2 + depth, _floorY - depth, cx + w/2 + depth, _floorY - depth);
            dc.drawLine(cx + w/2 + depth, _floorY - depth, cx + w/2, _floorY);
        }
        // Neon horizon line under the platform.
        dc.setColor(0x00D4FF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - w/2, _floorY, cx + w/2, _floorY);
        dc.setColor(0x0A2438, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - w/2, _floorY + 1, cx + w/2, _floorY + 1);
    }

    // ── Drawing helpers ─────────────────────────────────────────────
    hidden function _drawTower(dc, shx) {
        var blocks = _ctrl.tower.blocks;
        var is3d = (_ctrl.menuView == ST_VIEW_3D);
        for (var i = 0; i < blocks.size(); i++) {
            var b = blocks[i];
            var by = _rowBottomY(b.row);
            if (by < -BLOCK_H || by - BLOCK_H > _sh) { continue; }
            _drawBlockAny(dc, is3d, b.leftWX + shx, by - BLOCK_H + 1,
                          b.widthWX, BLOCK_H - 2, b.color, false);
        }
    }

    hidden function _drawMoving(dc, shx) {
        var m = _ctrl.tower.moving;
        if (m == null) { return; }
        var by = _rowBottomY(m.row);
        var top = _ctrl.tower.topBlock();
        if (top != null) {
            var tby = _rowBottomY(top.row);
            dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(top.leftWX + shx, tby,
                        top.leftWX + top.widthWX + shx, tby);
        }
        _drawBlockAny(dc, _ctrl.menuView == ST_VIEW_3D, m.leftWX + shx, by - BLOCK_H + 1,
                      m.widthWX, BLOCK_H - 2, m.color, true);
    }

    hidden function _drawFalling(dc, shx) {
        var fp = _ctrl.tower.falling;
        var is3d = (_ctrl.menuView == ST_VIEW_3D);
        for (var i = 0; i < fp.size(); i++) {
            var f = fp[i];
            var by = _rowBottomY(f.row);
            if (by - BLOCK_H > _sh + 20) { continue; }
            _drawBlockAny(dc, is3d, f.leftWX + shx, by - BLOCK_H + 1,
                          f.widthWX, BLOCK_H - 2, f.color, false);
        }
    }

    hidden function _drawBlockAny(dc, is3d, x, y, w, h, col, glow) {
        if (is3d) { _drawBlock3D(dc, x, y, w, h, col, glow); }
        else      { _drawBlock(dc, x, y, w, h, col, glow); }
    }

    // Filled block with a brighter top edge for fake-3D look (2D mode).
    hidden function _drawBlock(dc, x, y, w, h, col, glow) {
        if (w <= 0 || h <= 0) { return; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);
        var hl = ((col & 0xFEFEFE) >> 1) | 0x808080;
        dc.setColor(hl, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, 2);
        var sh = (col >> 2) & 0x3F3F3F;
        dc.setColor(sh, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y + h - 1, w, 1);
        if (glow) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x, y, w, h);
        }
    }

    // Isometric-style prism: lit top parallelogram + shaded right face
    // give the block real depth — the classic "Stack"-game look.
    hidden function _drawBlock3D(dc, x, y, w, h, col, glow) {
        if (w <= 0 || h <= 0) { return; }
        var d  = DEPTH_3D;
        var r0 = (col >> 16) & 0xFF; var g0 = (col >> 8) & 0xFF; var b0 = col & 0xFF;

        // Right side face — darkened.
        var sr = (r0 * 55) / 100; var sg = (g0 * 55) / 100; var sb = (b0 * 55) / 100;
        var sideCol = (sr << 16) | (sg << 8) | sb;
        dc.setColor(sideCol, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x + w,     y],
                        [x + w + d, y - d],
                        [x + w + d, y + h - d],
                        [x + w,     y + h]]);

        // Top face — lightened.
        var tr = r0 + ((255 - r0) * 55) / 100;
        var tg = g0 + ((255 - g0) * 55) / 100;
        var tb = b0 + ((255 - b0) * 55) / 100;
        var topCol = (tr << 16) | (tg << 8) | tb;
        dc.setColor(topCol, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x,         y],
                        [x + d,     y - d],
                        [x + w + d, y - d],
                        [x + w,     y]]);

        // Front face — base colour.
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);

        // Thin dark seams for crisp edges between faces.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + w, y, x + w, y + h);
        dc.drawLine(x, y, x + w, y);

        if (glow) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x, y, w, h);
            dc.drawLine(x + d, y - d, x + w + d, y - d);
            dc.drawLine(x + w + d, y - d, x + w + d, y + h - d);
        }
    }

    // ── HUD ─────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var cx = _sw / 2;
        // Translucent-look panel behind the score for legibility over
        // the busy sky/tower art.
        var pw = 64; var ph = 20;
        dc.setColor(0x05080F, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - pw/2, _hudTop - 3, pw, ph, 6);
        dc.setColor(0x1A3A55, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx - pw/2, _hudTop - 3, pw, ph, 6);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _hudTop, Graphics.FONT_MEDIUM,
                    _ctrl.score.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        // Height (left)
        dc.setColor(0x22FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(6, _hudTop + 2, Graphics.FONT_XTINY,
                    "H " + _ctrl.tower.height().format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        // Best (right)
        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw - 6, _hudTop + 2, Graphics.FONT_XTINY,
                        "B " + _ctrl.hi.format("%d"),
                        Graphics.TEXT_JUSTIFY_RIGHT);
        }
        if (_ctrl.lastPerfect > 0) {
            dc.setColor(0x22FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh - 18, Graphics.FONT_XTINY,
                        "PERFECT  +50", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Geometry for the chess-style menu.  Space-aware: the row height
    // shrinks to whatever fits between the BEST line and the bottom
    // margin, so all rows (Diff / View / START / LEADERBOARD) fit.
    //   [ rowH, rowW, rowX, rowY0, gap ]
    function menuRowGeom() {
        var topZone      = (_sh * 50) / 100;
        var bottomMargin = (_sh * 10) / 100; if (bottomMargin < 11) { bottomMargin = 11; }
        var gap          = (_sh * 2) / 100; if (gap < 3) { gap = 3; }
        var avail        = (_sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (ST_MENU_ROWS - 1)) / ST_MENU_ROWS;
        if (rowH > 21) { rowH = 21; }
        if (rowH < 13) { rowH = 13; }
        var rowW = (_sw * 60) / 100; if (rowW < 110) { rowW = 110; }
        var rowX = (_sw - rowW) / 2;
        var used = ST_MENU_ROWS * rowH + (ST_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // Open the shared global leaderboard for the current difficulty.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _ctrl.diffName(), "STACK TOWER");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Chess-style menu — starry sky backdrop, glowing title, decorative
    // mini-tower (rendered in the currently-selected view mode so the
    // player previews 2D vs 3D before starting), four interactive rows.
    hidden function _drawMenu(dc) {
        var cx = _sw / 2;

        // Title with a soft glow behind it.
        dc.setColor(0x2A1400, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - _sw * 30 / 100, _sh * 6 / 100,
                                 _sw * 60 / 100, _sh * 20 / 100, 10);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 9 / 100, Graphics.FONT_SMALL,
                    "STACK", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x22DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 18 / 100, Graphics.FONT_SMALL,
                    "TOWER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 28 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Decorative mini-tower — mirrors the live view mode.
        var is3d = (_ctrl.menuView == ST_VIEW_3D);
        var towerX = cx - 14;
        var palette = [0xFF2244, 0xFFCC00, 0x22FF88, 0x00CCFF, 0xAA44FF];
        for (var i = 0; i < 5; i++) {
            var off = (i % 2 == 0) ? -3 : 3;
            _drawBlockAny(dc, is3d, towerX + off, _sh * 41 / 100 - i * 7,
                          30, 6, palette[i], false);
        }

        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh * 47 / 100, Graphics.FONT_XTINY,
                        "BEST " + _ctrl.hi.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Four chess-style rows: Diff + View + START + LEADERBOARD.
        var rg   = menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = new [ST_MENU_ROWS];
        labels[ST_ROW_DIFF]  = "Diff: " + _ctrl.diffName();
        labels[ST_ROW_VIEW]  = "View: " + _ctrl.viewName();
        labels[ST_ROW_START] = "START";
        for (var i = 0; i < ST_MENU_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _ctrl.menuRow);

            if (i == ST_ROW_LB) {
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == ST_ROW_START);
            var bg; var bd; var fg;
            if      (sel && isStart) { bg = 0x1A4400; bd = 0x22FF88; fg = 0xAAFFCC; }
            else if (sel)             { bg = 0x002244; bd = 0x22DDFF; fg = 0xCCEEFF; }
            else if (isStart)         { bg = 0x102010; bd = 0x224422; fg = 0x88AA88; }
            else                       { bg = 0x101820; bd = 0x223344; fg = 0x88AABB; }
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
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x6677AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh - 14, Graphics.FONT_XTINY,
                    "UP/DN  tap = act",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game over overlay ───────────────────────────────────────────
    hidden function _drawOver(dc) {
        var bw = _sw * 64 / 100; if (bw < 150) { bw = 150; }
        var bh = _sh * 36 / 100; if (bh < 110) { bh = 110; }
        var bx = (_sw - bw) / 2;
        var by = (_sh - bh) / 2;
        dc.setColor(0x0A0A18, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(0xFF3366, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawRoundedRectangle(bx + 1, by + 1, bw - 2, bh - 2, 8);
        var cx = _sw / 2;
        dc.setColor(0xFF3366, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    "MISS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 30, Graphics.FONT_XTINY,
                    "Score " + _ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 46, Graphics.FONT_XTINY,
                    "Height " + _ctrl.tower.height().format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (_ctrl.score > 0 && _ctrl.score == _ctrl.hi) {
            dc.setColor(0x22FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 62, Graphics.FONT_XTINY,
                        "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_ctrl.hi > 0) {
            dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 62, Graphics.FONT_XTINY,
                        "Best " + _ctrl.hi.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Input intents ───────────────────────────────────────────────
    function inMenu()       { return _ctrl.state == GS_MENU; }
    function handleDrop()   { _ctrl.dropAction(); }
    function navUp() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuPrev(); return; }
        _ctrl.dropAction();
    }
    function navDown() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuNext(); return; }
        _ctrl.dropAction();
    }
    function navSelect() {
        if (_ctrl.state == GS_MENU) {
            if (_ctrl.menuRow == ST_ROW_LB) { openLeaderboard(); return; }
            _ctrl.menuActivate();
            return;
        }
        _ctrl.dropAction();
    }
    function handleTap(x, y) {
        if (_ctrl.state == GS_MENU) {
            var rg = menuRowGeom();
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < ST_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW &&
                    y >= ry    && y < ry    + rowH) {
                    _ctrl.setMenuRow(i);
                    if (i == ST_ROW_LB) { openLeaderboard(); }
                    else { _ctrl.menuActivate(); }
                    return;
                }
            }
            return;
        }
        _ctrl.dropAction();
    }
    function handleBack() {
        if (_ctrl.state == GS_PLAY) { _ctrl.gotoMenu(); return true; }
        if (_ctrl.state == GS_OVER) { _ctrl.gotoMenu(); return true; }
        return false;
    }
}
