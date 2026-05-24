// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Drawing helpers for PixelInvaders.
//
// Pixel-art Space Invaders aesthetic on a grid:
//   • Aliens          → small filled rectangles + 2 "eye" pixels,
//                        slightly different colour per row.
//   • Walk cycle      → tiny offset in body shape between phase 0/1.
//   • Player cannon   → flat trapezoid base + central turret.
//   • Bullets         → 1-cell-wide vertical lines.
//   • Ground line     → bright cyan rule under the playfield.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

class UIManager {

    // ── Menu geometry ───────────────────────────────────────────
    static function rowGeom(sw, sh) {
        var rowH = (sh * 11) / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
        var rowW = (sw * 78) / 100; if (rowW < 140) { rowW = 140; }
        var rowX = (sw - rowW) / 2;
        var gap  = (sh * 2)  / 100; if (gap  < 4)  { gap  = 4;  }
        var total = PI_MENU_ROWS * rowH + (PI_MENU_ROWS - 1) * gap;
        var rowY0 = (sh - total) / 2 + (sh * 6) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x000308, 0x000308); dc.clear();
        if (sw == sh) {
            dc.setColor(0x06121E, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        // Title — two-line stack + Bitochi attribution under it
        // (subtitle position; stays visible inside round bezels).
        dc.setColor(0x55FF55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  4 / 100, Graphics.FONT_MEDIUM,
                    "PIXEL", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 16 / 100, Graphics.FONT_SMALL,
                    "INVADERS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCFFCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 28 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = [
            "Diff:   " + ctrl.difficultyName(),
            "Lives:  " + ctrl.menuLives.format("%d"),
            "START"
        ];
        for (var i = 0; i < PI_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == PI_MENU_ROWS - 1);
            dc.setColor(sel ? (isStart ? 0x223300 : 0x101830) : 0x080F18,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0x55FF55) : 0x223344,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0xCCFFCC) : 0x99AABB,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN row  tap = act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── HUD ─────────────────────────────────────────────────────
    static function drawHUD(dc, sw, sh, ctrl) {
        var ty = (sh * 3) / 100; if (ty < 3) { ty = 3; }
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, ty, Graphics.FONT_XTINY,
                    "S " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x55FF55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, ty, Graphics.FONT_XTINY,
                    "W" + ctrl.wave.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF6688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw - 8, ty, Graphics.FONT_XTINY,
                    "x" + ctrl.lives.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ── Sparse star field ──────────────────────────────────────
    static function drawStars(dc, sw, sh) {
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        var pts = [
            [12, 28], [40, 65], [72, 22], [110, 92], [140, 36],
            [165, 130], [188, 55], [205, 180], [55, 150], [95, 200],
            [130, 230], [170, 260], [205, 215], [40, 270], [75, 290],
            [120, 270], [25, 200], [200, 100], [180, 32], [220, 145]
        ];
        for (var i = 0; i < pts.size(); i++) {
            var p = pts[i];
            if (p[0] < sw && p[1] < sh) {
                dc.fillRectangle(p[0], p[1], 1, 1);
            }
        }
    }

    // ── Aliens ──────────────────────────────────────────────────
    static function drawEnemies(dc, ox, oy, cell, enemies, phase) {
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (!e.alive) { continue; }
            var x = ox + e.col * cell;
            var y = oy + e.row * cell;

            var col;
            if      (e.type == EI_BOSS)  { col = 0xFF66AA; }
            else if (e.type == EI_GUARD) { col = 0xFFAA22; }
            else                          { col = 0x55FF55; }

            // Body with the walk-cycle phase tweaking the lower
            // shape (legs wide vs narrow).
            var bx = x + 2;
            var by = y + 2;
            var bw = cell - 4;
            var bh = cell - 4;
            if (bw < 3) { bw = 3; }
            if (bh < 3) { bh = 3; }

            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, by, bw, bh);

            // Eyes (dark dots) — visible from cell ≥ 7 px.
            if (cell >= 7) {
                dc.setColor(0x000510, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx + bw / 4,         by + bh / 3, 1, 1);
                dc.fillRectangle(bx + bw - bw / 4 - 1, by + bh / 3, 1, 1);
            }

            // Walk-cycle "legs" — toggled bumps under the body.
            if (cell >= 8) {
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                if (phase == 0) {
                    dc.fillRectangle(bx,             by + bh, 1, 1);
                    dc.fillRectangle(bx + bw - 1,    by + bh, 1, 1);
                } else {
                    dc.fillRectangle(bx + 1,         by + bh, 1, 1);
                    dc.fillRectangle(bx + bw - 2,    by + bh, 1, 1);
                }
            }
        }
    }

    // ── Player cannon ──────────────────────────────────────────
    static function drawPlayer(dc, ox, oy, cell, p) {
        // Flash invul: hide every other frame.
        if (p.isInvulnerable() && (p.blinkTicks % 4) >= 2) { return; }
        var x = ox + (p.colFloat * cell).toNumber();
        var y = oy + PI_PLAYER_ROW * cell;
        var cx = x + cell / 2;

        dc.setColor(0x55FFAA, Graphics.COLOR_TRANSPARENT);
        // Base (trapezoid).
        var bw = cell - 2;
        var bh = cell / 2;
        if (bw < 4) { bw = 4; }
        if (bh < 3) { bh = 3; }
        dc.fillRectangle(x + 1, y + cell - bh - 1, bw, bh);
        // Turret.
        var tw = cell / 3; if (tw < 2) { tw = 2; }
        dc.fillRectangle(cx - tw / 2, y + cell - bh - 2 - cell / 4,
                         tw, cell / 4 + 1);
    }

    // ── Bullets ────────────────────────────────────────────────
    static function drawBullets(dc, ox, oy, cell, pShots, eShots) {
        // Player bullets — yellow.
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < pShots.size(); i++) {
            var b = pShots[i];
            if (!b.alive) { continue; }
            var x = ox + b.col * cell + cell / 2 - 1;
            var y = oy + (b.row * cell).toNumber();
            if (y < oy - cell)                       { continue; }
            if (y > oy + PI_BOARD_ROWS * cell + cell) { continue; }
            var len = cell * 5 / 10; if (len < 4) { len = 4; }
            dc.fillRectangle(x, y, 2, len);
        }
        // Enemy bullets — bright pink so they pop.
        dc.setColor(0xFF4488, Graphics.COLOR_TRANSPARENT);
        for (var j = 0; j < eShots.size(); j++) {
            var b2 = eShots[j];
            if (!b2.alive) { continue; }
            var x2 = ox + b2.col * cell + cell / 2 - 1;
            var y2 = oy + (b2.row * cell).toNumber();
            if (y2 < oy - cell)                       { continue; }
            if (y2 > oy + PI_BOARD_ROWS * cell + cell) { continue; }
            var len2 = cell * 5 / 10; if (len2 < 4) { len2 = 4; }
            dc.fillRectangle(x2, y2, 2, len2);
        }
    }

    // ── Ground line ────────────────────────────────────────────
    static function drawGroundLine(dc, ox, oy, cell, sw) {
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        var y = oy + PI_BOARD_ROWS * cell + 1;
        dc.drawLine(ox - 4, y, ox + cell * PI_BOARD_COLS + 4, y);
    }

    // ── Result overlay ─────────────────────────────────────────
    static function drawResult(dc, sw, sh, ctrl) {
        var bw = sw * 72 / 100; if (bw < 160) { bw = 160; }
        var bh = sh * 44 / 100; if (bh < 120) { bh = 120; }
        var bx = (sw - bw) / 2;
        var by = (sh - bh) / 2;
        var cx = sw / 2;
        dc.setColor(0x000510, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 38, Graphics.FONT_XTINY,
                    "Score " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 56, Graphics.FONT_XTINY,
                    "Wave  " + ctrl.wave.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 74, Graphics.FONT_XTINY,
                    "Best  " + ctrl.bestScore.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
