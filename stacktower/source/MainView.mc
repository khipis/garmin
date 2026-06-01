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
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

const BLOCK_H = 11;        // world/screen pixels per block layer
const TICK_MS = 40;

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

    function initialize() {
        View.initialize();
        _ctrl   = new GameController();
        _timer  = null;
        _sw = 0; _sh = 0; _floorY = 0;
        _camRow = 0.0;
        _hudTop = 0;
        _laidOut = false;
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
            // Convert: we want screenY(topRow) = targetTopY
            //   targetTopY = _floorY - (topRow - camRow) * BLOCK_H
            //   camRow     = topRow - (_floorY - targetTopY) / BLOCK_H
            var desired = top.row - (_floorY - targetTopY) * 1.0 / BLOCK_H;
            if (desired < 0) { desired = 0; }
            // Lerp camera (faster when far, slower when close).
            _camRow = _camRow + (desired - _camRow) * 0.18;
        }

        // Shake offset for game-over feedback
        var shx = 0;
        if (_ctrl.lastShake > 0) {
            shx = ((Math.rand() % 7) - 3);
        }

        // ── Sky / background ────────────────────────────────────────
        dc.setColor(0x000814, 0x000814); dc.clear();

        if (_ctrl.state == GS_MENU) { _drawMenu(dc); return; }

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
        // For round watches narrow the strip further so blocks
        // don't clip on the curve.
        if (_sw == _sh) {
            // round-ish — assume circle. Use 78% of width.
            var inset = _sw * 11 / 100;
            minX = inset; maxX = _sw - inset;
        }
        _ctrl.setWorldBounds(minX, maxX);

        // HUD line + floor placement.
        _hudTop = _sh * 4 / 100; if (_hudTop < 3) { _hudTop = 3; }
        _floorY = _sh - (_sh * 8 / 100);
        if (_floorY > _sh - 12) { _floorY = _sh - 12; }
        _camRow = 0.0;
    }

    // Convert world-y row to screen-y for the BOTTOM of that block.
    hidden function _rowBottomY(row) {
        var y = _floorY - (row - _camRow) * BLOCK_H;
        return y.toNumber();
    }

    // ── Drawing helpers ─────────────────────────────────────────────
    hidden function _drawTower(dc, shx) {
        var blocks = _ctrl.tower.blocks;
        for (var i = 0; i < blocks.size(); i++) {
            var b = blocks[i];
            var by = _rowBottomY(b.row);
            // Skip if off-screen (above or below).
            if (by < -BLOCK_H || by - BLOCK_H > _sh) { continue; }
            _drawBlock(dc, b.leftWX + shx, by - BLOCK_H + 1,
                       b.widthWX, BLOCK_H - 2, b.color, false);
        }
    }

    hidden function _drawMoving(dc, shx) {
        var m = _ctrl.tower.moving;
        if (m == null) { return; }
        var by = _rowBottomY(m.row);
        // Slight cyan glow line under the block to mark the drop target.
        var top = _ctrl.tower.topBlock();
        if (top != null) {
            var tby = _rowBottomY(top.row);
            dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(top.leftWX + shx, tby,
                        top.leftWX + top.widthWX + shx, tby);
        }
        _drawBlock(dc, m.leftWX + shx, by - BLOCK_H + 1,
                   m.widthWX, BLOCK_H - 2, m.color, true);
    }

    hidden function _drawFalling(dc, shx) {
        var fp = _ctrl.tower.falling;
        for (var i = 0; i < fp.size(); i++) {
            var f = fp[i];
            var by = _rowBottomY(f.row);
            if (by - BLOCK_H > _sh + 20) { continue; }
            _drawBlock(dc, f.leftWX + shx, by - BLOCK_H + 1,
                       f.widthWX, BLOCK_H - 2, f.color, false);
        }
    }

    // Filled block with a brighter top edge for fake-3D look.
    hidden function _drawBlock(dc, x, y, w, h, col, glow) {
        if (w <= 0 || h <= 0) { return; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);
        // Top highlight
        var hl = ((col & 0xFEFEFE) >> 1) | 0x808080;
        dc.setColor(hl, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, 2);
        // Bottom shadow
        var sh = (col >> 2) & 0x3F3F3F;
        dc.setColor(sh, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y + h - 1, w, 1);
        if (glow) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x, y, w, h);
        }
    }

    // ── HUD ─────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var cx = _sw / 2;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _hudTop, Graphics.FONT_MEDIUM,
                    _ctrl.score.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        // Height (left)
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
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
            dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh - 18, Graphics.FONT_XTINY,
                        "PERFECT  +50", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Geometry for the 2-row chess-style menu.  Returns
    //   [ rowH, rowW, rowX, rowY0, gap ]
    function menuRowGeom() {
        var rowH = (_sh * 11) / 100; if (rowH < 24) { rowH = 24; } if (rowH > 30) { rowH = 30; }
        var rowW = (_sw * 78) / 100; if (rowW < 140) { rowW = 140; }
        var rowX = (_sw - rowW) / 2;
        var gap  = (_sh * 25) / 1000; if (gap < 5) { gap = 5; }
        var total = ST_MENU_ROWS * rowH + (ST_MENU_ROWS - 1) * gap;
        var rowY0 = _sh - 22 - total;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // Chess-style menu — dark base, "by Bitochi" attribution,
    // decorative mini-tower, two interactive rows (Diff + START).
    hidden function _drawMenu(dc) {
        var cx = _sw / 2;
        dc.setColor(0x080808, 0x080808); dc.clear();
        if (_sw == _sh) {
            dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _sh / 2, _sw / 2 - 1);
        }

        // Title
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 7 / 100, Graphics.FONT_SMALL,
                    "STACK", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 17 / 100, Graphics.FONT_SMALL,
                    "TOWER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 28 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Decorative mini-tower (smaller to leave room for two rows)
        var towerX = cx - 14;
        var palette = [0xFF3344, 0xFFCC22, 0x44FF55, 0x44CCFF, 0x8866FF];
        for (var i = 0; i < 5; i++) {
            var off = (i % 2 == 0) ? -3 : 3;
            _drawBlock(dc, towerX + off, _sh * 52 / 100 - i * 6,
                       30, 5, palette[i], false);
        }

        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh * 57 / 100, Graphics.FONT_XTINY,
                        "BEST " + _ctrl.hi.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Two chess-style rows: Diff + START.
        var rg   = menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = ["Diff:  " + _ctrl.diffName(), "START"];
        for (var i = 0; i < ST_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == _ctrl.menuRow);
            var isStart = (i == ST_ROW_START);
            var bg; var bd; var fg;
            if      (sel && isStart) { bg = 0x1A4400; bd = 0x44BB22; fg = 0xAAFF66; }
            else if (sel)             { bg = 0x002244; bd = 0x44CCFF; fg = 0xCCEEFF; }
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

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(0x0A0A14, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        var cx = _sw / 2;
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT);
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
            dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
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
        // In play / over, treat as drop / dismiss like before.
        _ctrl.dropAction();
    }
    function navDown() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuNext(); return; }
        _ctrl.dropAction();
    }
    function navSelect() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuActivate(); return; }
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
                    _ctrl.menuActivate();
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
