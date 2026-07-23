// ═══════════════════════════════════════════════════════════════
// MainView.mc — Camera, tower → screen projection, render loop.
//
// Rendering modes (menuView):
//   2D — flat blocks with bevel highlight + shadow strip.
//   3D — isometric prisms: lit top face + shaded right face,
//        DEPTH_3D = 7 px for dramatic depth.
//
// Visual extras:
//   • Retrowave perspective grid in menu backdrop.
//   • Sparkle burst on perfect block placement.
//   • Pulsing neon outline on the active (moving) block.
//   • Neon-bordered score panel in HUD.
//   • Animated title border on menu screen.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

const BLOCK_H  = 11;
const TICK_MS  = 40;
const DEPTH_3D = 7;          // isometric depth in pixels

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _timer;

    // Cached layout
    hidden var _sw;
    hidden var _sh;
    hidden var _floorY;
    hidden var _camRow;
    hidden var _hudTop;
    hidden var _laidOut;
    hidden var _frame;
    hidden var _started;   // auto-start the run on first frame

    // Starfield — pre-generated once in _doLayout.
    hidden var _starX;
    hidden var _starY;
    hidden var _starPhase;
    hidden const _STAR_N = 28;

    // Retrowave grid — pre-computed horizontal line Y positions.
    hidden var _gridY;
    hidden var _gridHorizonY;
    hidden const _GRID_LINES  = 7;
    hidden const _GRID_VLINES = 9;

    // Perfect-placement sparkle burst.
    hidden var _sparkT;      // countdown frames (0 = inactive)
    hidden var _sparkRow;    // which tower row
    hidden var _sparkX;      // world-x left of block
    hidden var _sparkW;      // world width of block

    function initialize() {
        View.initialize();
        _ctrl   = new GameController();
        _timer  = null;
        _sw = 0; _sh = 0; _floorY = 0;
        _camRow = 0.0;
        _hudTop = 0;
        _laidOut = false;
        _frame   = 0;
        _started = false;
        _starX = null; _starY = null; _starPhase = null;
        _gridY = null; _gridHorizonY = 0;
        _sparkT = 0; _sparkRow = 0; _sparkX = 0; _sparkW = 0;
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
        if (_sparkT > 0) { _sparkT = _sparkT - 1; }
        WatchUi.requestUpdate();
    }

    // ── Update / render ─────────────────────────────────────────────
    function onUpdate(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();
        if (!_laidOut) { _doLayout(); _laidOut = true; }

        // Menu lives in the shared root view — drop straight into a run and
        // never render an in-game menu here.
        if (!_started || _ctrl.state == GS_MENU) {
            _ctrl.startGame();
            _started = true;
        }

        // Smooth camera follow — keep tower top at ~30% from top.
        var top = _ctrl.tower.topBlock();
        if (top != null) {
            var targetTopY = _sh * 30 / 100;
            var desired = top.row - (_floorY - targetTopY) * 1.0 / BLOCK_H;
            if (desired < 0) { desired = 0; }
            _camRow = _camRow + (desired - _camRow) * 0.18;
        }

        var shx = 0;
        if (_ctrl.lastShake > 0) {
            shx = ((Math.rand() % 7) - 3);
        }

        _drawSky(dc);
        // Keep the signature retrowave grid as the in-game backdrop.
        _drawRetrowaveGrid(dc);

        _drawGround(dc, shx);
        _drawTower(dc, shx);
        _drawFalling(dc, shx);
        _drawMoving(dc, shx);
        if (_sparkT > 0) { _drawSparkle(dc, shx); }
        _drawHUD(dc);
        if (_ctrl.dailyT > 0 && _ctrl.dailyMsg != null) { _drawDailyToast(dc); }
        if (_ctrl.state == GS_OVER) { _drawOver(dc); }
    }

    // One-shot daily-bonus toast (queued by the App on the day's first
    // launch). A lightweight banner over the run — no new blocking view.
    hidden function _drawDailyToast(dc) {
        var cx = _sw / 2;
        var cy = _sh * 32 / 100;
        var bw = _sw * 92 / 100;
        var bh = 20;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - bw / 2, cy - bh / 2, bw, bh, 6);
        dc.setColor(0xFFD21A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx - bw / 2, cy - bh / 2, bw, bh, 6);
        dc.drawText(cx, cy - 7, Graphics.FONT_XTINY,
                    _ctrl.dailyMsg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _doLayout() {
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

        // Starfield — spread over top 65% so it stays above the floor.
        _starX     = new [_STAR_N];
        _starY     = new [_STAR_N];
        _starPhase = new [_STAR_N];
        for (var i = 0; i < _STAR_N; i++) {
            _starX[i]     = Math.rand() % _sw;
            _starY[i]     = Math.rand() % ((_sh * 65) / 100);
            _starPhase[i] = Math.rand() % 40;
        }

        // Retrowave grid — horizontal lines from near the floor down.
        _gridHorizonY = _floorY - 14;
        if (_gridHorizonY < _sh / 2) { _gridHorizonY = _sh / 2; }
        _gridY = new [_GRID_LINES];
        var span = _sh - _gridHorizonY;
        for (var i = 0; i < _GRID_LINES; i++) {
            _gridY[i] = _gridHorizonY + (span * (i + 1)) / (_GRID_LINES + 1);
        }
    }

    // World-row → screen-y of block bottom edge.
    hidden function _rowBottomY(row) {
        var y = _floorY - (row - _camRow) * BLOCK_H;
        return y.toNumber();
    }

    // ── Sky: deep-space gradient + twinkling coloured stars + moon ──
    hidden function _drawSky(dc) {
        var topR = 1;  var topG = 2;  var topB = 10;
        var botR = 18; var botG = 6;  var botB = 44;
        var bands = 16;
        var bh = (_sh / bands) + 1;
        for (var i = 0; i < bands; i++) {
            var t = i * 100 / (bands - 1);
            var r = topR + ((botR - topR) * t) / 100;
            var g = topG + ((botG - topG) * t) / 100;
            var b = topB + ((botB - topB) * t) / 100;
            dc.setColor((r << 16) | (g << 8) | b, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, i * bh, _sw, bh + 1);
        }

        // Glowing moon with halo rings.
        var mx = _sw - _sw * 16 / 100;
        var my = _sh * 11 / 100;
        var mr = _sw * 7 / 100;
        dc.setColor(0x100718, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, mr + 8);
        dc.setColor(0x1C1236, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, mr + 5);
        dc.setColor(0x2E1E50, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, mr + 2);
        dc.setColor(0xEAEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, mr);
        // Crescent shadow.
        dc.setColor(0x181830, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx - mr / 3, my - mr / 4, (mr * 78) / 100);

        if (_starX == null) { return; }
        for (var s = 0; s < _STAR_N; s++) {
            var ph = (_frame / 4 + _starPhase[s]) % 40;
            var bright = (ph < 20) ? ph : (40 - ph);    // 0..20 triangle
            if (bright < 5) { continue; }
            var v = 0x55 + bright * 9; if (v > 0xFF) { v = 0xFF; }
            var col;
            var kind = _starPhase[s] % 3;
            if      (kind == 0) { col = (v << 16) | (v << 8) | 0xFF; }   // blue-white
            else if (kind == 1) { col = 0xFF0000 | (v << 8) | (v / 2); } // warm amber
            else                { col = (v << 16) | (v << 8) | v; }       // pure white
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var sz = (bright > 14) ? 2 : 1;
            dc.fillRectangle(_starX[s], _starY[s], sz, sz);
        }
    }

    // ── Retrowave perspective grid (used in menu backdrop) ──────────
    hidden function _drawRetrowaveGrid(dc) {
        if (_gridY == null) { return; }
        var cx       = _sw / 2;
        var horizonY = _gridHorizonY;
        var bottomY  = _sh;
        var span     = bottomY - horizonY;
        if (span <= 0) { return; }

        // Horizontal lines: brighter and wider toward the bottom.
        for (var i = 0; i < _GRID_LINES; i++) {
            var ly = _gridY[i];
            var t  = ((ly - horizonY) * 100) / span;   // 0..100
            var r  = (t * 60) / 100;
            var g  = (t * 10) / 100;
            var b  = 30 + (t * 70) / 100; if (b > 0xFF) { b = 0xFF; }
            dc.setColor((r << 16) | (g << 8) | b, Graphics.COLOR_TRANSPARENT);
            var lx = cx - (cx * t) / 100;
            var rx = cx + ((_sw - cx) * t) / 100;
            dc.drawLine(lx, ly, rx, ly);
        }

        // Vertical spokes converging to the horizon point.
        dc.setColor(0x1A0830, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i <= _GRID_VLINES; i++) {
            var bx = (i * _sw) / _GRID_VLINES;
            dc.drawLine(bx, bottomY, cx, horizonY);
        }
    }

    // ── Ground platform beneath the tower ───────────────────────────
    hidden function _drawGround(dc, shx) {
        var w  = (_ctrl.worldMaxX - _ctrl.worldMinX) + 34;
        var cx = (_ctrl.worldMinX + _ctrl.worldMaxX) / 2 + shx;
        if (_ctrl.menuView == ST_VIEW_3D) {
            var depth = DEPTH_3D * 2;
            dc.setColor(0x121E34, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - w/2, _floorY],
                            [cx - w/2 + depth, _floorY - depth],
                            [cx + w/2 + depth, _floorY - depth],
                            [cx + w/2, _floorY]]);
            dc.setColor(0x28406A, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - w/2, _floorY, cx - w/2 + depth, _floorY - depth);
            dc.drawLine(cx - w/2 + depth, _floorY - depth, cx + w/2 + depth, _floorY - depth);
            dc.drawLine(cx + w/2 + depth, _floorY - depth, cx + w/2, _floorY);
        }
        // Neon horizon — three lines for bloom.
        dc.setColor(0x00D4FF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - w/2, _floorY, cx + w/2, _floorY);
        dc.setColor(0x007090, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - w/2, _floorY + 1, cx + w/2, _floorY + 1);
        dc.setColor(0x003040, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - w/2, _floorY - 1, cx + w/2, _floorY - 1);
    }

    // ── Tower drawing ────────────────────────────────────────────────
    hidden function _drawTower(dc, shx) {
        var blocks = _ctrl.tower.blocks;
        var is3d = (_ctrl.menuView == ST_VIEW_3D);
        var lastIdx = blocks.size() - 1;
        for (var i = 0; i < blocks.size(); i++) {
            var b = blocks[i];
            var by = _rowBottomY(b.row);
            if (by < -BLOCK_H || by - BLOCK_H > _sh) { continue; }
            var bx = b.leftWX + shx;
            var byy = by - BLOCK_H + 1;
            _drawBlockAny(dc, is3d, bx, byy, b.widthWX, BLOCK_H - 2, b.color, false);
            if (b.special == 1) { _goldSheen(dc, bx, byy, b.widthWX, BLOCK_H - 2); }
            // Landing pop — bright fading border on the freshly placed top block.
            if (i == lastIdx && _ctrl.placeFlash > 0) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(bx - 1, byy - 1, b.widthWX + 2, BLOCK_H);
            }
        }
    }

    // Animated golden sheen for bonus blocks: pulsing border + sweeping glint.
    // Block widths/positions are world-pixel Floats; coerce to Number before any
    // modulo — Monkey C's `%` throws on Float operands (that was the crash the
    // first gold block triggered).
    hidden function _goldSheen(dc, x, y, w, h) {
        var wi = w.toNumber();
        var xi = x.toNumber();
        if (wi <= 1 || h <= 1) { return; }
        var ph = (_frame / 2) % 10;
        var g  = (ph < 5) ? ph : (10 - ph);          // 0..5
        var v  = 0xCC + g * 6; if (v > 0xFF) { v = 0xFF; }
        dc.setColor((v << 16) | (v << 8) | 0x33, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(xi, y, wi, h);
        var period = wi + 6;
        var sweep  = (_frame % period) - 3;
        var sx     = xi + sweep;
        if (sx >= xi && sx < xi + wi) {
            dc.setColor(0xFFFFEE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, y + 1, 2, h - 2);
        }
    }

    hidden function _drawMoving(dc, shx) {
        var m = _ctrl.tower.moving;
        if (m == null) { return; }
        var by = _rowBottomY(m.row);

        // Target line — shows where the top block ends. Pulses red when
        // the tower gets dangerously narrow to ratchet up the tension.
        var top = _ctrl.tower.topBlock();
        if (top != null) {
            var tby = _rowBottomY(top.row);
            var tcol = 0x33FFCC;
            if (top.widthWX <= 16) {
                tcol = (((_frame / 2) % 2) == 0) ? 0xFF3355 : 0xFFAA55;
            }
            dc.setColor(tcol, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(top.leftWX + shx, tby - 2,
                        top.leftWX + top.widthWX + shx, tby - 2);
        }

        // Pulsing glow — on for 5 frames out of every 8.
        var glowOn = ((_frame / 2) % 8) < 5;
        var mx = m.leftWX + shx;
        var myy = by - BLOCK_H + 1;
        _drawBlockAny(dc, _ctrl.menuView == ST_VIEW_3D,
                      mx, myy, m.widthWX, BLOCK_H - 2, m.color, glowOn);
        if (m.special == 1) { _goldSheen(dc, mx, myy, m.widthWX, BLOCK_H - 2); }
    }

    hidden function _drawFalling(dc, shx) {
        var fp = _ctrl.tower.falling;
        for (var i = 0; i < fp.size(); i++) {
            var f = fp[i];
            var by = _rowBottomY(f.row);
            if (by - BLOCK_H > _sh + 20) { continue; }
            _drawTumble(dc, f.leftWX + shx, by - BLOCK_H + 1,
                        f.widthWX, BLOCK_H - 2, f.color, f.spin);
        }
    }

    // Rotate a corner (px,py) about (cx,cy) and return integer [x,y].
    hidden function _rot(px, py, ca, sa, cx, cy) {
        var rx = px * ca - py * sa + cx;
        var ry = px * sa + py * ca + cy;
        return [rx.toNumber(), ry.toNumber()];
    }

    // A tumbling overhang slice — rotated quad with a shaded lower edge.
    hidden function _drawTumble(dc, x, y, w, h, col, spinDeg) {
        if (w <= 0 || h <= 0) { return; }
        var ang = spinDeg * 0.0174533;
        var ca  = Math.cos(ang);
        var sa  = Math.sin(ang);
        var hw  = w / 2.0;
        var hh  = h / 2.0;
        var cxp = x + hw;
        var cyp = y + hh;
        var p0 = _rot(-hw, -hh, ca, sa, cxp, cyp);
        var p1 = _rot( hw, -hh, ca, sa, cxp, cyp);
        var p2 = _rot( hw,  hh, ca, sa, cxp, cyp);
        var p3 = _rot(-hw,  hh, ca, sa, cxp, cyp);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([p0, p1, p2, p3]);
        var r0 = (col >> 16) & 0xFF; var g0 = (col >> 8) & 0xFF; var b0 = col & 0xFF;
        dc.setColor(((r0 * 45) / 100 << 16) | ((g0 * 45) / 100 << 8) | ((b0 * 45) / 100),
                    Graphics.COLOR_TRANSPARENT);
        dc.drawLine(p2[0], p2[1], p3[0], p3[1]);
        dc.drawLine(p3[0], p3[1], p0[0], p0[1]);
    }

    // ── Perfect-placement sparkle burst ─────────────────────────────
    // 8 radiating points expand outward then fade. No per-call allocs.
    hidden function _drawSparkle(dc, shx) {
        var by = _rowBottomY(_sparkRow);
        var cy = by - BLOCK_H / 2;
        var bcx = _sparkX + _sparkW / 2 + shx;
        // Radius expands from 0 to 18 px over 10 frames.
        var r = (10 - _sparkT) * 2;
        if (r <= 0) { return; }

        // Outer ring — white sparkles.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var dx; var dy;
        for (var i = 0; i < 8; i++) {
            if      (i == 0) { dx =  r; dy =  0; }
            else if (i == 1) { dx =  r; dy =  r; }
            else if (i == 2) { dx =  0; dy =  r; }
            else if (i == 3) { dx = -r; dy =  r; }
            else if (i == 4) { dx = -r; dy =  0; }
            else if (i == 5) { dx = -r; dy = -r; }
            else if (i == 6) { dx =  0; dy = -r; }
            else             { dx =  r; dy = -r; }
            dc.fillRectangle(bcx + dx - 1, cy + dy - 1, 2, 2);
        }
        // Inner ring — golden.
        var ir = (r * 6) / 10; if (ir < 1) { ir = 1; }
        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 8; i++) {
            if      (i == 0) { dx =  ir; dy =   0; }
            else if (i == 1) { dx =  ir; dy =  ir; }
            else if (i == 2) { dx =   0; dy =  ir; }
            else if (i == 3) { dx = -ir; dy =  ir; }
            else if (i == 4) { dx = -ir; dy =   0; }
            else if (i == 5) { dx = -ir; dy = -ir; }
            else if (i == 6) { dx =   0; dy = -ir; }
            else             { dx =  ir; dy = -ir; }
            dc.fillRectangle(bcx + dx - 1, cy + dy - 1, 2, 2);
        }
    }

    hidden function _drawBlockAny(dc, is3d, x, y, w, h, col, glow) {
        if (is3d) { _drawBlock3D(dc, x, y, w, h, col, glow); }
        else      { _drawBlock(dc, x, y, w, h, col, glow); }
    }

    // ── 2D block: bevel highlight + shadow strip ─────────────────────
    hidden function _drawBlock(dc, x, y, w, h, col, glow) {
        if (w <= 0 || h <= 0) { return; }
        var r0 = (col >> 16) & 0xFF;
        var g0 = (col >> 8)  & 0xFF;
        var b0 =  col        & 0xFF;

        // Bottom shadow strip (darker 50%).
        var shH = (h > 3) ? h / 3 : 1;
        var sr = (r0 * 50) / 100; var sg = (g0 * 50) / 100; var sb = (b0 * 50) / 100;
        dc.setColor((sr << 16) | (sg << 8) | sb, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y + h - shH, w, shH);

        // Main body.
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h - shH);

        // Top highlight bevel (brighten 65%).
        var hlH = (h > 4) ? 3 : 1;
        var hr = r0 + ((255 - r0) * 65) / 100;
        var hg = g0 + ((255 - g0) * 65) / 100;
        var hb = b0 + ((255 - b0) * 65) / 100;
        dc.setColor((hr << 16) | (hg << 8) | hb, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, hlH);
        // Left edge highlight (1 px).
        dc.fillRectangle(x, y, 1, h - shH);

        if (glow) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x - 1, y - 1, w + 2, h + 2);
            dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x, y, w, h);
        }
    }

    // ── 3D isometric prism: top + right + front face ─────────────────
    hidden function _drawBlock3D(dc, x, y, w, h, col, glow) {
        if (w <= 0 || h <= 0) { return; }
        var d  = DEPTH_3D;
        var r0 = (col >> 16) & 0xFF; var g0 = (col >> 8) & 0xFF; var b0 = col & 0xFF;

        // Right side face — darkened (42%).
        var sr = (r0 * 42) / 100; var sg = (g0 * 42) / 100; var sb = (b0 * 42) / 100;
        dc.setColor((sr << 16) | (sg << 8) | sb, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x + w,     y],
                        [x + w + d, y - d],
                        [x + w + d, y + h - d],
                        [x + w,     y + h]]);

        // Top face — lightened (62%).
        var tr = r0 + ((255 - r0) * 62) / 100;
        var tg = g0 + ((255 - g0) * 62) / 100;
        var tb = b0 + ((255 - b0) * 62) / 100;
        dc.setColor((tr << 16) | (tg << 8) | tb, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x,         y],
                        [x + d,     y - d],
                        [x + w + d, y - d],
                        [x + w,     y]]);

        // Front face — base colour with subtle bottom shadow.
        var shadowH = (h > 3) ? h / 3 : 0;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h - shadowH);
        if (shadowH > 0) {
            var dr = (r0 * 68) / 100; var dg = (g0 * 68) / 100; var db = (b0 * 68) / 100;
            dc.setColor((dr << 16) | (dg << 8) | db, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y + h - shadowH, w, shadowH);
        }

        // Black seam edges for crisp face separation.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + w, y, x + w, y + h);
        dc.drawLine(x, y, x + w, y);

        // Neon top-edge highlight line.
        var er = r0 + ((255 - r0) * 82) / 100;
        var eg = g0 + ((255 - g0) * 82) / 100;
        var eb = b0 + ((255 - b0) * 82) / 100;
        dc.setColor((er << 16) | (eg << 8) | eb, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x + d, y - d, x + w + d, y - d);

        if (glow) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x - 1, y - 1, w + 2, h + 2);
            dc.drawLine(x + d - 1, y - d - 1, x + w + d + 1, y - d - 1);
            dc.drawLine(x + w + d, y - d, x + w + d, y + h - d);
        }
    }

    // ── HUD ─────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var cx = _sw / 2;

        // Neon score panel.
        var pw = 72; var ph = 22;
        dc.setColor(0x040610, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - pw/2, _hudTop - 3, pw, ph, 7);
        dc.setColor(0x00D4FF, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx - pw/2, _hudTop - 3, pw, ph, 7);
        dc.setColor(0x003D50, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx - pw/2 + 1, _hudTop - 2, pw - 2, ph - 2, 6);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _hudTop, Graphics.FONT_MEDIUM,
                    _ctrl.score.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x22FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(6, _hudTop + 2, Graphics.FONT_XTINY,
                    "H " + _ctrl.tower.height().format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw - 6, _hudTop + 2, Graphics.FONT_XTINY,
                        "B " + _ctrl.hi.format("%d"),
                        Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Live combo counter under the score panel.
        if (_ctrl.combo >= 2) {
            var ccol = (((_frame / 3) % 2) == 0) ? 0xFFCC22 : 0xFFFFAA;
            dc.setColor(ccol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _hudTop + 20, Graphics.FONT_XTINY,
                        "COMBO x" + _ctrl.combo.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_ctrl.lastPerfect > 0) {
            var pcol = ((_frame % 6) < 3) ? 0x22FF88 : 0xAAFFCC;
            dc.setColor(pcol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh - 22, Graphics.FONT_XTINY,
                        "PERFECT  +" + _ctrl.lastBonus.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_ctrl.goldFlash > 0) {
            dc.setColor(0xFFD21A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh - 40, Graphics.FONT_XTINY,
                        "GOLD  +" + ST_GOLD_BONUS.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Big height-milestone banner.
        if (_ctrl.milestoneT > 0) {
            var my = _sh / 2 - 14;
            dc.setColor(0x02040C, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 46, my - 2, 92, 44, 8);
            dc.setColor(0x22FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(cx - 46, my - 2, 92, 44, 8);
            dc.drawText(cx, my, Graphics.FONT_MEDIUM,
                        _ctrl.milestoneN.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xAAFFCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, my + 24, Graphics.FONT_XTINY,
                        "FLOORS!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Menu geometry ────────────────────────────────────────────────
    function menuRowGeom() {
        var topZone      = (_sh * 44) / 100;   // was 50 — rows start earlier
        var bottomMargin = (_sh * 8) / 100; if (bottomMargin < 10) { bottomMargin = 10; }
        var gap          = (_sh * 2) / 100;  if (gap < 3) { gap = 3; }
        var avail        = (_sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (ST_MENU_ROWS - 1)) / ST_MENU_ROWS;
        if (rowH > 20) { rowH = 20; }
        if (rowH < 12) { rowH = 12; }
        var rowW = (_sw * 60) / 100; if (rowW < 110) { rowW = 110; }
        var rowX = (_sw - rowW) / 2;
        var used = ST_MENU_ROWS * rowH + (ST_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _ctrl.diffName(), "STACK TOWER");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // ── Chess-style menu with retrowave backdrop + animated title ────
    hidden function _drawMenu(dc) {
        var cx = _sw / 2;

        // Retrowave grid as menu backdrop (drawn on top of sky).
        _drawRetrowaveGrid(dc);

        // Pulsing title border — slow sine-like pulse via frame counter.
        var pulse = (_frame / 3) % 20;
        var gI    = (pulse < 10) ? pulse : (20 - pulse);   // 0..10
        var glowG = 0x88 + gI * 8; if (glowG > 0xFF) { glowG = 0xFF; }

        var titleX = cx - _sw * 30 / 100;
        var titleW = _sw * 60 / 100;
        var titleY = _sh * 4 / 100;      // was 6%
        var titleH = _sh * 17 / 100;     // was 20%
        dc.setColor(0x1C0800, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(titleX, titleY, titleW, titleH, 10);
        dc.setColor((0xFF << 16) | (glowG << 8) | 0, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(titleX, titleY, titleW, titleH, 10);
        dc.setColor(0x330E00, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(titleX + 1, titleY + 1, titleW - 2, titleH - 2, 9);

        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 6 / 100, Graphics.FONT_SMALL,       // was 9%
                    "STACK", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x22DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 13 / 100, Graphics.FONT_SMALL,      // was 18%
                    "TOWER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 22 / 100, Graphics.FONT_XTINY,      // was 28%
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Decorative mini-tower — mirrors the selected view mode.
        var is3d = (_ctrl.menuView == ST_VIEW_3D);
        var towerX = cx - 12;
        var palette = [0xFF2244, 0xFFCC00, 0x22FF88, 0x00CCFF, 0xAA44FF];
        for (var i = 0; i < 5; i++) {
            var off = (i % 2 == 0) ? -3 : 3;
            _drawBlockAny(dc, is3d, towerX + off, _sh * 35 / 100 - i * 6,  // was 41%, i*7
                          26, 5, palette[i], false);                          // was 30×6
        }

        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh * 40 / 100, Graphics.FONT_XTINY,  // was 47%
                        "BEST " + _ctrl.hi.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Interactive rows.
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
            else                      { bg = 0x0D1420; bd = 0x1E2F44; fg = 0x7A9AB0; }
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

        dc.setColor(0x5A6888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh - 14, Graphics.FONT_XTINY,
                    "UP/DN  tap = act",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game-over overlay ────────────────────────────────────────────
    hidden function _drawOver(dc) {
        var lines = [
            ["Score " + _ctrl.score.format("%d"), 0xFFFFFF],
            ["Height " + _ctrl.tower.height().format("%d"), 0xFFFFFF]
        ];
        if (_ctrl.bestCombo >= 2) {
            lines.add(["Combo x" + _ctrl.bestCombo.format("%d"), 0xFFCC22]);
        }
        if (_ctrl.score > 0 && _ctrl.score == _ctrl.hi) {
            lines.add(["NEW BEST!", 0x22FF88]);
        } else if (_ctrl.hi > 0) {
            lines.add(["Best " + _ctrl.hi.format("%d"), 0x88AABB]);
        }
        // Shared meta-progression summary line: level + rank + coin balance.
        lines.add(["Lv " + Progress.level().format("%d") + " " + _ctrl.rankName()
                   + " - " + Progress.coins().format("%d") + "c", 0xBFD8C4]);
        if (Progress.currentStreak() > 1) {
            lines.add(["Streak " + Progress.currentStreak().format("%d"), 0x22DDFF]);
        }
        if (_ctrl.pgUnlockMsg != null) {
            lines.add([_ctrl.pgUnlockMsg, 0xFFD21A]);
        }
        GameOverCard.draw(dc, _sw, _sh, "MISS", 0xFF2244, lines,
                          "Tap to restart", 0xFF2244);
    }

    // ── Input intents ────────────────────────────────────────────────
    function inMenu()     { return _ctrl.state == GS_MENU; }
    function handleDrop() { _ctrl.dropAction(); _checkSparkle(); }

    function navUp() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuPrev(); return; }
        _ctrl.dropAction(); _checkSparkle();
    }
    function navDown() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuNext(); return; }
        _ctrl.dropAction(); _checkSparkle();
    }
    function navSelect() {
        if (_ctrl.state == GS_MENU) {
            if (_ctrl.menuRow == ST_ROW_LB) { openLeaderboard(); return; }
            _ctrl.menuActivate();
            return;
        }
        _ctrl.dropAction(); _checkSparkle();
    }
    function handleTap(x, y) {
        if (_ctrl.state == GS_MENU) {
            var rg   = menuRowGeom();
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
        _ctrl.dropAction(); _checkSparkle();
    }
    function handleBack() {
        // Always pop back to the shared menu.
        return false;
    }

    // Trigger sparkle burst if the last drop was perfect.
    hidden function _checkSparkle() {
        if (_ctrl.lastPerfect > 0) {
            var top = _ctrl.tower.topBlock();
            if (top != null) {
                _sparkT   = 10;
                _sparkRow = top.row;
                _sparkX   = top.leftWX;
                _sparkW   = top.widthWX;
            }
        }
    }
}
