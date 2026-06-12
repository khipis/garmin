// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Menu / HUD / board / actors renderer.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

const HG_MENU_ROWS = 4;

class UIManager {

    // Space-aware geometry: the four rows (Start L / Lives / START /
    // LEADERBOARD) are packed into the strip between the title block
    // and a reserved bottom margin, so the extra LEADERBOARD row never
    // overlaps the footer or each other on small round watches.
    // Rows are ~15-18 % smaller than the old 3-row menu.
    static function rowGeom(sw, sh) {
        var topZone      = (sh * 32) / 100;             // rows live below "by Bitochi"
        var bottomMargin = (sh * 9)  / 100; if (bottomMargin < 16) { bottomMargin = 16; }
        var gap          = (sh * 2)  / 100; if (gap < 3) { gap = 3; }
        var avail        = (sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (HG_MENU_ROWS - 1)) / HG_MENU_ROWS;
        if (rowH > 22) { rowH = 22; }                   // ~10 % more compact
        if (rowH < 13) { rowH = 13; }
        var rowW = (sw * 59) / 100; if (rowW < 108) { rowW = 108; }  // ~10 % narrower
        var rowX = (sw - rowW) / 2;
        var used  = HG_MENU_ROWS * rowH + (HG_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x040A14, 0x040A14); dc.clear();
        if (sw == sh) {
            dc.setColor(0x081428, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        // Soft cyan grid backdrop
        dc.setColor(0x102240, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < sh; i = i + 8) {
            dc.drawLine(0, i, sw, i);
        }
        for (var j = 0; j < sw; j = j + 8) {
            dc.drawLine(j, 0, j, sh);
        }
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 10 / 100, Graphics.FONT_SMALL,
                    "HOLOGRID", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 19 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = [
            "Start L: " + ctrl.menuStartLevel.format("%d"),
            "Lives: "   + ctrl.menuLives.format("%d"),
            "START"
        ];
        for (var i2 = 0; i2 < HG_MENU_ROWS; i2++) {
            var ry      = rowY0 + i2 * (rowH + gap);
            var sel     = (i2 == ctrl.menuRow);

            if (i2 == HG_ROW_LB) {
                // Gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i2 == HG_ROW_START);
            dc.setColor(sel ? (isStart ? 0x103030 : 0x102240) : 0x081428, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x33FFEE : 0x44CCFF) : 0x224466, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xAAFFEE : 0xCCEEFF) : 0x88AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i2], Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN row  tap = act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    static function drawHUD(dc, sw, sh, ctrl) {
        var ty = (sh * 3) / 100; if (ty < 3) { ty = 3; }
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, ty, Graphics.FONT_XTINY,
                    "L" + ctrl.level.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, ty, Graphics.FONT_XTINY,
                    "$" + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw - 8, ty, Graphics.FONT_XTINY,
                    "Hp " + ctrl.lives.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
    }

    static function drawGrid(dc, ox, oy, cell, grid) {
        for (var r = 0; r < grid.n; r++) {
            for (var c = 0; c < grid.n; c++) {
                var t = grid.get(r, c);
                var x = ox + c * cell;
                var y = oy + r * cell;
                if (t == HG_WALL) {
                    dc.setColor(0x102240, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0x3366AA, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(x, y, cell, cell);
                } else if (t == HG_EXIT) {
                    dc.setColor(0x002211, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(x, y, cell, cell);
                    if (cell >= 10) {
                        dc.drawText(x + cell / 2, y - 1, Graphics.FONT_XTINY,
                                    "E", Graphics.TEXT_JUSTIFY_CENTER);
                    }
                } else {
                    dc.setColor(0x040810, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    if (cell >= 8) {
                        dc.setColor(0x0A1428, Graphics.COLOR_TRANSPARENT);
                        dc.drawRectangle(x, y, cell, cell);
                    }
                }
            }
        }
    }

    static function drawBlockers(dc, ox, oy, cell, blockers) {
        var colors = [0xFF4466, 0xFFAA22, 0xAA66FF];
        for (var i = 0; i < blockers.size(); i++) {
            var b = blockers[i];
            var x = ox + b.c * cell;
            var y = oy + b.r * cell;
            var col = colors[b.type % 3];
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 2, y + 2, cell - 4, cell - 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            // Mini-indicator: dot = static, ring = moving, X = predict
            if (b.type == HG_BL_STATIC) {
                dc.fillCircle(x + cell / 2, y + cell / 2, 1);
            } else if (b.type == HG_BL_MOVING) {
                dc.drawCircle(x + cell / 2, y + cell / 2, cell / 4);
            } else {
                dc.drawLine(x + 3, y + 3, x + cell - 4, y + cell - 4);
                dc.drawLine(x + cell - 4, y + 3, x + 3, y + cell - 4);
            }
        }
    }

    static function drawPlayer(dc, ox, oy, cell, p) {
        var x = ox + p.c * cell;
        var y = oy + p.r * cell;
        // Cyan halo
        dc.setColor(0x0A2A40, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, cell, cell);
        dc.setColor(0x55EEFF, Graphics.COLOR_TRANSPARENT);
        var rr = cell * 4 / 10; if (rr < 2) { rr = 2; }
        dc.fillCircle(x + cell / 2, y + cell / 2, rr);
        dc.setColor(0xCCFFFF, Graphics.COLOR_TRANSPARENT);
        var d = GridSystem.dirDelta(p.facing);
        dc.fillCircle(x + cell / 2 + d[1] * (cell / 4),
                      y + cell / 2 + d[0] * (cell / 4),
                      cell >= 12 ? 2 : 1);
    }

    // Big, high-contrast direction indicator that sits in the bottom
    // band of the screen (below the board).  `boardBottomY` is the
    // last y-coordinate occupied by the board so we can centre the
    // indicator in the leftover space above the footer hint.
    //
    // Drawing: a chunky ring (filled disc + outline) with a bold
    // arrow head pointing along the current direction, plus a short
    // text label ("UP" / "DN" / "LEFT" / "RIGHT") right next to it
    // so even a glance is enough to read the state.
    static function drawDirIndicator(dc, sw, sh, dir, boardBottomY) {
        // Available band — between the board and the footer (last
        // 18 px reserved for the "swipe = move" hint).
        var bandTop  = boardBottomY + 4;
        var bandBot  = sh - 18;
        var bandH    = bandBot - bandTop;
        if (bandH < 28) { bandH = 28; }
        var cy = bandTop + bandH / 2;

        // Centre the ring + label inside the screen width.
        var ringR = bandH / 2 - 2;
        if (ringR < 14) { ringR = 14; }
        if (ringR > 28) { ringR = 28; }

        var label;
        if      (dir == HG_DIR_U) { label = "UP";    }
        else if (dir == HG_DIR_D) { label = "DOWN";  }
        else if (dir == HG_DIR_L) { label = "LEFT";  }
        else                       { label = "RIGHT"; }

        // Estimate label width (FONT_XTINY ≈ 7 px / char).
        var labelPx = label.length() * 7;
        var totalW  = ringR * 2 + 8 + labelPx;
        var ringCx  = (sw - totalW) / 2 + ringR;
        var labelX  = ringCx + ringR + 8;

        // Filled disc + outline.
        dc.setColor(0x102240, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ringCx, cy, ringR);
        dc.setColor(0x55EEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ringCx, cy, ringR);
        dc.drawCircle(ringCx, cy, ringR - 1);

        // Arrow head — a chunky triangle whose tip sits ~80 % toward
        // the ring edge along `dir`, with a stub tail centred on cy.
        var d  = GridSystem.dirDelta(dir);
        var ar = ringR * 7 / 10;        // arrow half-length
        var aw = ringR * 4 / 10;        // arrow half-width
        if (ar < 6) { ar = 6; }
        if (aw < 4) { aw = 4; }
        var tipX  = ringCx + d[1] * ar;
        var tipY  = cy     + d[0] * ar;
        var tailX = ringCx - d[1] * (ar / 2);
        var tailY = cy     - d[0] * (ar / 2);
        // Side vector perpendicular to (d[1], d[0]).
        var perpX = -d[0];
        var perpY =  d[1];
        var lX    = tailX + perpX * aw;
        var lY    = tailY + perpY * aw;
        var rX    = tailX - perpX * aw;
        var rY    = tailY - perpY * aw;
        dc.setColor(0x55EEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[tipX, tipY], [lX, lY], [rX, rY]]);

        // Direction label.
        dc.setColor(0x55EEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(labelX, cy - 9, Graphics.FONT_XTINY,
                    label, Graphics.TEXT_JUSTIFY_LEFT);
    }

    static function drawResult(dc, sw, sh, won, ctrl) {
        var bw = sw * 70 / 100; if (bw < 160) { bw = 160; }
        var bh = sh * 40 / 100; if (bh < 110) { bh = 110; }
        var bx = (sw - bw) / 2;
        var by = (sh - bh) / 2;
        var cx = sw / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(won ? 0x44FF88 : 0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    won ? "ESCAPED!" : "TRAPPED", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 36, Graphics.FONT_XTINY,
                    "Level " + ctrl.level.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 56, Graphics.FONT_XTINY,
                    "Score " + ctrl.score.format("%d") + "  Best " + ctrl.bestScore.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
