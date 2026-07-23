// ═══════════════════════════════════════════════════════════════
// RenderSystem.mc — Iso-tile drawing helpers (perf-tuned).
//
// Earlier revisions drew, per tile:
//   2 skirt polygons + 1 top polygon + 4 rim lines  ≈ 7 draws/tile
// plus optional boost-arrow and fragile-crack decorations.  On a
// path with ~60 visible tiles that meant 420+ draw calls per frame
// just for the world — the watch couldn't keep up at 50 ms tick
// and the ball felt unresponsive.
//
// This revision draws 1 polygon per tile (the diamond top) and
// nothing else — colour alone reads the tile type.  Combined with
// PathGenerator's rowMinX/rowMaxX bounds and a smaller visible y
// window, the per-frame draw budget drops by roughly an order of
// magnitude.  Vertex arrays are pre-allocated and reused between
// tiles to avoid 4 fresh array allocations every iteration.
//
// Sky is similarly compressed to 1 clear + 2 fillRectangle bands
// + a precomputed star list.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;

class RenderSystem {

    // Halve each channel for a cheap "darker skirt" shade.
    hidden static function _dark(col) {
        return (((col >> 17) & 0x7F) << 16)
             | (((col >>  9) & 0x7F) << 8)
             |  ((col >>  1) & 0x7F);
    }

    // ── Pre-allocated polygon vertex storage ────────────────────
    // The four corners of a tile diamond.  `_polyVerts` is the
    // outer array passed to fillPolygon; the inner [x,y] arrays
    // are mutated in-place for each tile so we don't allocate
    // anything inside the hot loop.
    hidden static var _vTop;
    hidden static var _vRight;
    hidden static var _vBottom;
    hidden static var _vLeft;
    hidden static var _polyVerts;

    // ── Cached starfield (built lazily on first draw) ───────────
    // Stored as a single flat int array [x0, y0, x1, y1, ...].
    // Drawing replays a tight loop of drawPoint calls with zero
    // math — far cheaper than re-running the LCG every frame.
    hidden static var _starsXY;
    hidden static var _starsW;
    hidden static var _starsH;

    hidden static function _ensureBuffers() {
        if (_polyVerts == null) {
            _vTop    = [0, 0];
            _vRight  = [0, 0];
            _vBottom = [0, 0];
            _vLeft   = [0, 0];
            _polyVerts = [_vTop, _vRight, _vBottom, _vLeft];
        }
    }

    hidden static function _ensureStars(w, h) {
        if (_starsXY != null && _starsW == w && _starsH == h) { return; }
        var count = 12;          // was 18 — fewer points = less work
        var arr = new [count * 2];
        var seed = 7793;
        for (var k = 0; k < count; k++) {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            arr[k * 2]     = seed % w;
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            arr[k * 2 + 1] = seed % (h * 25 / 100);
        }
        _starsXY = arr;
        _starsW  = w;
        _starsH  = h;
    }

    // ── Sky background ──────────────────────────────────────────
    // Two solid bands plus a cached star list.  The earlier
    // 7-band lerped gradient is gone — at this watch size the
    // extra bands were barely distinguishable but cost a fillRect
    // and a 3× float lerp per band per frame.
    static function drawSky(dc, ctrl) {
        var w = ctrl.sw; var h = ctrl.sh;
        // Upper sky.
        dc.setColor(0x0A1830, 0x0A1830); dc.clear();
        // Lower horizon band — softer cool blue.
        dc.setColor(0x335C90, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 38 / 100, w, h * 18 / 100);

        // Cached stars (top quarter only).
        _ensureStars(w, h);
        dc.setColor(0xE8F0FF, Graphics.COLOR_TRANSPARENT);
        var n = _starsXY.size() / 2;
        for (var k = 0; k < n; k++) {
            dc.drawPoint(_starsXY[k * 2], _starsXY[k * 2 + 1]);
        }

        // Parallax clouds — three soft puffs drifting slowly with the
        // run distance so the sky reads as moving without much cost.
        var d = ctrl.distance;
        dc.setColor(0x4E75A8, Graphics.COLOR_TRANSPARENT);
        for (var c = 0; c < 3; c++) {
            var span = w + 60;
            var cxp  = ((c * 4703 + d * (c + 1)) % span) - 30;
            var cyp  = h * (14 + c * 8) / 100;
            var r    = (w * 7 / 100) + c * 3;
            dc.fillCircle(cxp - r, cyp, r);
            dc.fillCircle(cxp + r, cyp, r);
            dc.fillCircle(cxp, cyp - r / 2, r + 2);
        }
    }

    // Faint radial speed lines at high forward speed — sells velocity.
    static function drawSpeedLines(dc, ctrl) {
        var mul = ctrl.path.speedMul();
        if (mul < 1.5) { return; }
        var cxp = ctrl.cx; var cyp = ctrl.cy + SR_BALL_Y_OFFSET;
        var t   = System.getTimer() / 60;
        dc.setColor(0x8FB8E0, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 6; i++) {
            var ang = ((i * 60) + (t * 13)) % 360;
            var rad = ang * 0.01745;
            var r0  = 30 + (t % 20);
            var r1  = r0 + 14;
            var dx  = Math.cos(rad); var dy = Math.sin(rad);
            dc.drawLine(cxp + (dx * r0).toNumber(), cyp + (dy * r0).toNumber(),
                        cxp + (dx * r1).toNumber(), cyp + (dy * r1).toNumber());
        }
    }

    // ── Visible-tile painter ────────────────────────────────────
    static function drawPath(dc, ctrl) {
        _ensureBuffers();

        var path = ctrl.path;
        // Smaller window: enough rows behind to avoid pop-in, enough
        // ahead to telegraph turns.  Visible iso area only covers
        // about 12-14 rows anyway on a watch face.
        var by   = ctrl.physics.py.toNumber();
        var yLo  = by - 2;
        var yHi  = by + 14;
        if (yLo < 0)              { yLo = 0; }
        if (yHi > path.nextY - 1) { yHi = path.nextY - 1; }

        var rowMinX = path.rowMinX;
        var rowMaxX = path.rowMaxX;
        var tileBuf = path.tile;
        var brkBuf  = path.breakT;
        var gemBuf  = path.gem;

        for (var y = yHi; y >= yLo; y--) {
            // y is guaranteed >= 0 here so the modulo never needs
            // negative correction; inline saves a function call per
            // row.
            var yi = y % SR_BUF_Y;
            var lo = rowMinX[yi];
            var hi = rowMaxX[yi];
            if (lo > hi) { continue; }              // empty row
            var rowT = tileBuf[yi];
            var rowB = brkBuf[yi];
            var rowG = gemBuf[yi];
            for (var x = lo; x <= hi; x++) {
                var xi = x + SR_X_HALF;
                var t = rowT[xi];
                if (t == SR_T_NONE) { continue; }
                var br = (t == SR_T_BREAK) ? rowB[xi] : 0;
                _drawTile(dc, ctrl, x, y, t, br, rowG[xi]);
            }
        }
    }

    // Tile = a darker skirt (pseudo-height) + the diamond top + any
    // boost/gem marker. Skirt is one hexagon poly so it stays cheap.
    hidden static function _drawTile(dc, ctrl, wx, wy, t, breakRem, hasGem) {
        var cam = ctrl.cam;
        var hwF = SR_TILE_HW.toFloat();
        var hhF = SR_TILE_HH.toFloat();
        var ix  = (wx - wy) * hwF;
        var iy  = -(wx + wy) * hhF;
        var bx0 = (ix - cam.camIX).toNumber() + ctrl.cx;
        var by0 = (iy - cam.camIY).toNumber() + ctrl.cy + SR_BALL_Y_OFFSET;

        var hw = SR_TILE_HW; var hh = SR_TILE_HH;
        _vTop[0]    = bx0;       _vTop[1]    = by0 - 2 * hh;
        _vRight[0]  = bx0 + hw;  _vRight[1]  = by0 - hh;
        _vBottom[0] = bx0;       _vBottom[1] = by0;
        _vLeft[0]   = bx0 - hw;  _vLeft[1]   = by0 - hh;

        var col;
        if      (t == SR_T_NORMAL)  { col = 0xC8D4DC; }
        else if (t == SR_T_SOFT)    { col = 0x9ED8A4; }
        else if (t == SR_T_BOOST)   { col = 0xFFD24A; }
        else if (t == SR_T_FRAGILE) { col = 0xE0945A; }
        else if (t == SR_T_BREAK)   {
            // Darken as it collapses so the player can see it dying.
            var k = breakRem * 80 / SR_BREAK_TICKS;
            if (k < 0) { k = 0; } if (k > 80) { k = 80; }
            col = 0x6A2A18 + (k << 16);
        }
        else                        { col = 0xC8D4DC; }

        // Skirt — one hexagon under the front rim gives the floating
        // slab a sense of thickness/height. ~4 px deep.
        var sk = 4;
        dc.setColor(_dark(col), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[bx0 - hw, by0 - hh],
                        [bx0,      by0],
                        [bx0 + hw, by0 - hh],
                        [bx0 + hw, by0 - hh + sk],
                        [bx0,      by0 + sk],
                        [bx0 - hw, by0 - hh + sk]]);

        // Top face.
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(_polyVerts);

        // Boost chevron — a gold up-arrow on the tile.
        if (t == SR_T_BOOST) {
            var my = by0 - hh;
            dc.setColor(0xFFF3B0, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[bx0, my - 6], [bx0 - 5, my], [bx0 + 5, my]]);
        }

        // Floating collectible gem — a small spinning cyan/gold diamond
        // hovering above the tile top.
        if (hasGem) {
            var gy = by0 - hh - 8;
            var t2 = (System.getTimer() / 120) % 2;
            var gw = (t2 == 0) ? 4 : 2;
            dc.setColor(0x33E0FF, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[bx0, gy - 5], [bx0 + gw, gy], [bx0, gy + 5], [bx0 - gw, gy]]);
            dc.setColor(0xEAFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx0 - 1, gy - 2, 2, 2);
        }
    }

    // ── Ball (shadow + body + fall animation). ──────────────────
    static function drawBall(dc, ctrl) {
        var p   = ctrl.cam.worldToScreen(ctrl.physics.px,
                                          ctrl.physics.py,
                                          ctrl.cx, ctrl.cy);
        var bx  = p[0]; var by = p[1];

        var dropY = 0;
        if (ctrl.state == SR_FALL) {
            var t = ctrl.fallT.toFloat();
            dropY = ((SR_FALL_GRAV.toFloat() / 100.0) * t * t).toNumber();
        }

        if (ctrl.state == SR_PLAY) {
            dc.setColor(0x0A0F18, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 5, by - 1, 11, 3);
        }

        var ballR = 6;
        if (ctrl.state == SR_FALL && ctrl.fallT > SR_FALL_TICKS - 6) {
            ballR = ballR - (SR_FALL_TICKS - ctrl.fallT) / 2;
            if (ballR < 2) { ballR = 2; }
        }
        var by2 = by - 6 + dropY;
        dc.setColor(0x223044, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by2, ballR + 1);
        dc.setColor(0xDCE6F8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by2, ballR);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx - 2, by2 - 3, 2, 2);
    }
}
