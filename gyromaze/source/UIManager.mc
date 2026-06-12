// ═══════════════════════════════════════════════════════════════
// UIManager.mc — GyroMaze rendering (v2: adaptive layout, richer palette).
//
// MAZE cell-size is computed dynamically every frame from the
// actual screen dimensions so the board always fits with an ~10%
// safety margin — no overflow on any Garmin watch.
//
//   avail = min( sw − 8,  sh − 46 )   ← 30 px HUD + 16 px footer
//   cellPx = avail × 0.90 / n         ← 90 % of available space
//
// Because PhysicsEngine works in cell-unit space (0 … n) rather
// than pixels, changing cellPx only affects rendering — the
// physics stays correct at every screen size.
//
// BIOME PALETTE  (redesigned for legibility and vibrancy)
//   NORMAL  wall #1A2538  floor #F7F5EF  ball #FF2D55
//   ICE     wall #0D3B5C  floor #DFFAFF  ball #00D2FF
//   TRAP    wall #3D0A0A  floor #FFF0F0  ball #34FF34
//   SPEED   wall #2C0A4A  floor #FFFADF  ball #FF6B00
//   CHAOS   wall #0A2B1A  floor #E8FFF4  ball #FF00CC
//
// MENU rows are 8% of screen height (was 9%) and 62% of screen
// width (was 68%), and start at 42% down the screen (was 38%) to
// avoid crowding round-face watches.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;

class UIManager {

    hidden static var _ox;    // board origin x (pixels, set in _drawMaze)
    hidden static var _oy;    // board origin y
    hidden static var _cp;    // cell size (pixels, set in _drawMaze)
    hidden static var _nn;    // maze n (set in _drawMaze)

    // ── Biome palette ──────────────────────────────────────────
    hidden static function _wallCol(b) {
        if (b == GM_BIOME_ICE)   { return 0x0D3B5C; }
        if (b == GM_BIOME_TRAP)  { return 0x3D0A0A; }
        if (b == GM_BIOME_SPEED) { return 0x2C0A4A; }
        if (b == GM_BIOME_CHAOS) { return 0x0A2B1A; }
        return 0x1A2538;
    }
    hidden static function _floorCol(b) {
        if (b == GM_BIOME_ICE)   { return 0xDFFAFF; }
        if (b == GM_BIOME_TRAP)  { return 0xFFF0F0; }
        if (b == GM_BIOME_SPEED) { return 0xFFFADF; }
        if (b == GM_BIOME_CHAOS) { return 0xE8FFF4; }
        return 0xF7F5EF;
    }
    hidden static function _ballCol(b) {
        if (b == GM_BIOME_ICE)   { return 0x00D2FF; }
        if (b == GM_BIOME_TRAP)  { return 0x34FF34; }
        if (b == GM_BIOME_SPEED) { return 0xFF6B00; }
        if (b == GM_BIOME_CHAOS) { return 0xFF00CC; }
        return 0xFF2D55;
    }
    // Accent colour used for HUD timer, START text, etc.
    hidden static function _accentCol(b) {
        if (b == GM_BIOME_ICE)   { return 0x44EEFF; }
        if (b == GM_BIOME_TRAP)  { return 0xFF5555; }
        if (b == GM_BIOME_SPEED) { return 0xFFAA00; }
        if (b == GM_BIOME_CHAOS) { return 0xFF44DD; }
        return 0x44FFB0;
    }

    // ── Menu geometry (used by view for tap-detection too) ─────
    // Returns [rowH, rowW, rowX, rowY0, gap].
    //
    // Space-aware: the four rows (Diff / Biome / START / LEADERBOARD)
    // are packed into the strip between the title block and a reserved
    // bottom margin, so the extra LEADERBOARD row never overlaps the
    // footer or each other on small round watches. Rows are ~15-18 %
    // smaller than the old 3-row menu to fit the fourth row.
    static function rowGeom(sw, sh) {
        var topZone      = (sh * 37) / 100;            // rows live below "by Bitochi" (31 %)
        var bottomMargin = (sh *  9) / 100; if (bottomMargin < 16) { bottomMargin = 16; }
        var gap          = (sh *  2) / 100; if (gap < 3) { gap = 3; }
        var avail        = (sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (GM_MENU_ROWS - 1)) / GM_MENU_ROWS;
        if (rowH > 24) { rowH = 24; }
        if (rowH < 14) { rowH = 14; }
        var rowW = (sw * 60) / 100; if (rowW < 115) { rowW = 115; }
        var rowX = (sw - rowW) / 2;
        var used  = GM_MENU_ROWS * rowH + (GM_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // ── Menu ───────────────────────────────────────────────────
    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;

        // Background.
        dc.setColor(0x020810, 0x020810); dc.clear();
        if (sw == sh) {
            dc.setColor(0x050F20, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        // Title.
        dc.setColor(0xFFB300, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 6 / 100, Graphics.FONT_MEDIUM,
                    "GYRO MAZE", Graphics.TEXT_JUSTIFY_CENTER);

        // Tagline.
        dc.setColor(0x78D4C8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 22 / 100, Graphics.FONT_XTINY,
                    "tilt  ·  roll  ·  escape",
                    Graphics.TEXT_JUSTIFY_CENTER);

        // By Bitochi.
        dc.setColor(0x5A7D96, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 31 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Rows.
        var rg    = rowGeom(sw, sh);
        var rowH  = rg[0]; var rowW = rg[1];
        var rowX  = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = [
            "Diff:  " + ctrl.diffName(),
            "Biome: " + ctrl.biomeName(),
            "START   Lvl " + (ctrl.level + 1).format("%d")
        ];
        for (var i = 0; i < GM_MENU_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == ctrl.menuRow);

            if (i == GM_ROW_LB) {
                // Hype-y gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var ist = (i == GM_ROW_START);

            // Fill.
            if (sel) {
                dc.setColor(ist ? 0x002018 : 0x081828, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x030C18, Graphics.COLOR_TRANSPARENT);
            }
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 4);

            // Border.
            if (sel) {
                dc.setColor(ist ? 0x00EE80 : 0x00A8CC, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x163048, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 4);

            // Arrow indicator.
            if (sel) {
                var ay = ry + rowH / 2;
                dc.setColor(ist ? 0x00EE80 : 0x00C8E8, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[rowX + 5, ay - 3],
                                [rowX + 5, ay + 3],
                                [rowX + 10, ay]]);
            }

            // Label text.
            if (sel) {
                dc.setColor(ist ? 0x00FF90 : 0xDDF6FF, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x4A7090, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Best time footer.
        var b   = ctrl.bestSec();
        var sub = (b >= 0) ? ("Best " + b.format("%d") + "s") : "No record yet";
        dc.setColor(0x304858, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    sub, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Play ───────────────────────────────────────────────────
    static function drawPlay(dc, sw, sh, ctrl) {
        var wc = _wallCol(ctrl.biome);
        dc.setColor(wc, wc); dc.clear();
        if (sw == sh) {
            dc.setColor(_darken(wc, 80), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sw / 2, sh / 2, sw / 2 - 1);
        }
        _drawHUD(dc, sw, sh, ctrl);
        _drawMaze(dc, sw, sh, ctrl);
        _drawFooter(dc, sw, sh);
    }

    hidden static function _drawHUD(dc, sw, sh, ctrl) {
        var cx  = sw / 2;
        var acc = _accentCol(ctrl.biome);

        // Biome label (left).
        dc.setColor(0xBBCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw * 8 / 100, sh * 7 / 100, Graphics.FONT_XTINY,
                    ctrl.curBiomeName(), Graphics.TEXT_JUSTIFY_LEFT);

        // Timer (centre, accent colour).
        dc.setColor(acc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 7 / 100, Graphics.FONT_XTINY,
                    ctrl.elapsedSec().format("%d") + "s",
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Level (right).
        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw - sw * 8 / 100, sh * 7 / 100, Graphics.FONT_XTINY,
                    "L" + (ctrl.level + 1).format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
    }

    hidden static function _drawFooter(dc, sw, sh) {
        dc.setColor(0x2A4055, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, sh - 14, Graphics.FONT_XTINY,
                    "tilt · UP/DN · SEL=restart",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _drawMaze(dc, sw, sh, ctrl) {
        var n = ctrl.n;

        // ── Dynamic cell-size (adaptive, 90 % of available space) ──
        var availW = sw - 8;
        var availH = sh - 46;     // 30 px HUD + 16 px footer
        var avail  = (availW < availH) ? availW : availH;
        var cp     = (avail * 90) / (n * 100);
        if (cp < 10) { cp = 10; }

        var wt = 2;    // wall thickness in pixels

        var boardW = n * cp;
        var boardH = n * cp;
        var ox = (sw - boardW) / 2;
        var oy = 30 + ((sh - 46 - boardH) / 2);

        _ox = ox; _oy = oy; _cp = cp; _nn = n;

        // 1. Background already filled by dc.clear() in drawPlay.

        // 2. Cell floors.
        var fc       = _floorCol(ctrl.biome);
        var walls    = ctrl.walls;
        var extras   = ctrl.extras;
        var exitCell = ctrl.exitCell;

        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                var i   = r * n + c;
                var w   = walls[i];
                var inL = (w & GM_WALL_W) != 0 ? wt : 0;
                var inR = (w & GM_WALL_E) != 0 ? wt : 0;
                var inT = (w & GM_WALL_N) != 0 ? wt : 0;
                var inB = (w & GM_WALL_S) != 0 ? wt : 0;
                var fx  = ox + c * cp + inL;
                var fy  = oy + r * cp + inT;
                var fw  = cp - inL - inR;
                var fh  = cp - inT - inB;

                var ex = extras[i];
                if (i == exitCell) {
                    dc.setColor(0x00CC66, Graphics.COLOR_TRANSPARENT);
                } else if (ex == GM_TILE_SPIKE) {
                    dc.setColor(0xFF3030, Graphics.COLOR_TRANSPARENT);
                } else if (ex == GM_TILE_BOOST) {
                    dc.setColor(0xFFD000, Graphics.COLOR_TRANSPARENT);
                } else if (ex == GM_TILE_SLOW) {
                    dc.setColor(0x5588DD, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
                }
                dc.fillRectangle(fx, fy, fw, fh);

                // Exit marker.
                if (i == exitCell) {
                    dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(fx + fw / 2, fy + (fh - 14) / 2,
                                Graphics.FONT_XTINY, "X",
                                Graphics.TEXT_JUSTIFY_CENTER);
                }
                // Spike cross.
                if (ex == GM_TILE_SPIKE && i != exitCell && fw > 4 && fh > 4) {
                    dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(fx + 2, fy + 2, fx + fw - 3, fy + fh - 3);
                    dc.drawLine(fx + fw - 3, fy + 2, fx + 2, fy + fh - 3);
                }
            }
        }

        // 3. Ball.
        var bc  = _ballCol(ctrl.biome);
        var bpx = ox + (ctrl.physics.bx * cp).toNumber();
        var bpy = oy + (ctrl.physics.by * cp).toNumber();
        var bpr = (ctrl.physics.ballR * cp).toNumber();
        if (bpr < 2) { bpr = 2; }

        // Glow ring.
        dc.setColor(_lighten(bc, 60), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(bpx, bpy, bpr + 2);
        // Body.
        dc.setColor(bc, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bpx, bpy, bpr);
        // Highlight.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bpx - bpr / 3, bpy - bpr / 3, bpr / 3);

        // 4. Pause overlay.
        if (ctrl.state == GM_PAUSE) {
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 3; i++) {
                dc.drawRectangle(ox + i, oy + i,
                                 boardW - 2*i, boardH - 2*i);
            }
            dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sw / 2, oy + boardH / 2 - 8,
                        Graphics.FONT_SMALL, "PAUSED",
                        Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x90B8D0, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sw / 2, oy + boardH / 2 + 12,
                        Graphics.FONT_XTINY, "SEL = resume",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Hit-test for tap: pixel → maze [r, c] or [-1, -1].
    static function tapToCell(x, y) {
        if (_cp <= 0) { return [-1, -1]; }
        var lx = x - _ox; var ly = y - _oy;
        if (lx < 0 || ly < 0) { return [-1, -1]; }
        var c = lx / _cp; var r = ly / _cp;
        if (r < 0 || c < 0 || r >= _nn || c >= _nn) { return [-1, -1]; }
        return [r, c];
    }

    // ── Win / Game-Over ────────────────────────────────────────
    static function drawEnd(dc, sw, sh, ctrl) {
        var cx  = sw / 2;
        var won = (ctrl.state == GM_WIN);

        dc.setColor(won ? 0x020F09 : 0x100202, won ? 0x020F09 : 0x100202);
        dc.clear();
        if (sw == sh) {
            dc.setColor(won ? 0x041A0E : 0x1C0303, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        // Big result text.
        dc.setColor(won ? 0x00EE80 : 0xFF3C3C, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 8 / 100, Graphics.FONT_MEDIUM,
                    won ? "ESCAPED!" : "SPIKED!",
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Time.
        dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 26 / 100, Graphics.FONT_SMALL,
                    ctrl.elapsedSec().format("%d") + "s",
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Best time.
        var b    = ctrl.bestSec();
        var best = (b >= 0) ? ("Best " + b.format("%d") + "s") : "First clear!";
        dc.setColor(0x90B8D0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 41 / 100, Graphics.FONT_XTINY,
                    best, Graphics.TEXT_JUSTIFY_CENTER);

        // Diff + biome.
        dc.setColor(0x4A6070, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 52 / 100, Graphics.FONT_XTINY,
                    ctrl.diffName() + " · " + ctrl.curBiomeName(),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Hint.
        dc.setColor(won ? 0x00CC70 : 0xFF8866, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    won ? "SEL = next   ESC = menu"
                        : "SEL = retry  ESC = menu",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Colour utilities ───────────────────────────────────────
    hidden static function _darken(col, pct) {
        var r = ((col >> 16) & 0xFF) * pct / 100;
        var g = ((col >> 8)  & 0xFF) * pct / 100;
        var b = ( col        & 0xFF) * pct / 100;
        return (r << 16) | (g << 8) | b;
    }
    hidden static function _lighten(col, amt) {
        var r = ((col >> 16) & 0xFF) + amt; if (r > 255) { r = 255; }
        var g = ((col >> 8)  & 0xFF) + amt; if (g > 255) { g = 255; }
        var b = ( col        & 0xFF) + amt; if (b > 255) { b = 255; }
        return (r << 16) | (g << 8) | b;
    }
}
