// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Pure rendering helpers for ChickenCross.
//
// IMPORTANT: this game's board is drawn so that row 0 is at the
// BOTTOM of the screen and row BOARD_ROWS-1 is at the TOP — the
// natural "upward" direction in Frogger.  Translation:
//   screenY(row) = ox? + (BOARD_ROWS - 1 - row) * cell
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

class UIManager {

    static function rowGeom(sw, sh) {
        var rowH = (sh * 11) / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
        var rowW = (sw * 78) / 100; if (rowW < 140) { rowW = 140; }
        var rowX = (sw - rowW) / 2;
        var gap  = (sh * 2)  / 100; if (gap  < 4)  { gap  = 4;  }
        var total = CC_MENU_ROWS * rowH + (CC_MENU_ROWS - 1) * gap;
        var rowY0 = (sh - total) / 2 + (sh * 6) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x081020, 0x081020); dc.clear();
        if (sw == sh) {
            dc.setColor(0x0C1830, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        // Title + Bitochi attribution under it (subtitle position,
        // not the footer, so it stays visible inside the round face).
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  4 / 100, Graphics.FONT_MEDIUM,
                    "CHICKEN", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF7733, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 16 / 100, Graphics.FONT_SMALL,
                    "CROSS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDDAA, Graphics.COLOR_TRANSPARENT);
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
        for (var i = 0; i < CC_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == CC_MENU_ROWS - 1);
            dc.setColor(sel ? (isStart ? 0x223300 : 0x101830) : 0x0A1020, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0xFF9933) : 0x223344, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0xFFDDAA) : 0x99AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN row  tap = act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    static function drawHUD(dc, sw, sh, ctrl) {
        var ty = (sh * 3) / 100; if (ty < 3) { ty = 3; }
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, ty, Graphics.FONT_XTINY,
                    "S " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, ty, Graphics.FONT_XTINY,
                    "L" + ctrl.level.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF6688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw - 8, ty, Graphics.FONT_XTINY,
                    "x" + ctrl.lives.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Y-coordinate of a grid row.  Row 0 sits at the bottom of the
    // board area so "moving up" means "increasing row".
    static function yOfRow(oy, cell, row) {
        return oy + (BOARD_ROWS - 1 - row) * cell;
    }

    static function drawBoard(dc, ox, oy, cell, lanes) {
        for (var i = 0; i < lanes.size(); i++) {
            var ln = lanes[i];
            var y  = yOfRow(oy, cell, ln.row);
            var col;
            if      (ln.type == LANE_ROAD)  { col = 0x222222; }
            else if (ln.type == LANE_RIVER) { col = 0x1144AA; }
            else if (ln.type == LANE_GOAL)  { col = 0x224422; }
            else                             { col = 0x336622; }   // GRASS
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ox, y, cell * BOARD_COLS, cell);

            // Lane markings.
            if (ln.type == LANE_ROAD) {
                dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
                var dashLen = cell * 6 / 10; if (dashLen < 3) { dashLen = 3; }
                var stepC   = 2;  // dash every 2 tiles
                for (var c = 0; c < BOARD_COLS; c = c + stepC) {
                    var dx = ox + c * cell + (cell - dashLen) / 2;
                    dc.fillRectangle(dx, y + cell / 2, dashLen, 1);
                }
            } else if (ln.type == LANE_RIVER) {
                dc.setColor(0x2266CC, Graphics.COLOR_TRANSPARENT);
                if (cell >= 8) {
                    dc.drawLine(ox, y + 2, ox + cell * BOARD_COLS, y + 2);
                    dc.drawLine(ox, y + cell - 3, ox + cell * BOARD_COLS, y + cell - 3);
                }
            } else if (ln.type == LANE_GOAL) {
                // Soft "home" stripe at the top.
                dc.setColor(0x66FF99, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ox, y + cell - 2, cell * BOARD_COLS, 2);
                if (cell >= 10) {
                    dc.drawText(ox + cell * BOARD_COLS / 2, y - 2, Graphics.FONT_XTINY,
                                "HOME", Graphics.TEXT_JUSTIFY_CENTER);
                }
            }
        }
    }

    static function drawObstacles(dc, ox, oy, cell, obs, lanes) {
        for (var i = 0; i < obs.items.size(); i++) {
            var o  = obs.items[i];
            var ln = LaneManager.laneAt(lanes, o.row);
            if (ln == null) { continue; }
            var x = ox + (o.col * cell).toNumber();
            var y = yOfRow(oy, cell, o.row);
            var w = o.len * cell;
            if (o.kind == KIND_CAR) {
                // Bright car body with two-tone roof for legibility.
                var col = (o.row % 2 == 0) ? 0xFF3344 : 0x4477FF;
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + 1, y + 2, w - 2, cell - 4);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + w / 4, y + cell / 3,
                                 w / 2, cell / 3);
            } else if (o.kind == KIND_TRUCK) {
                // Cab + container.
                dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + 1, y + 2, w - 2, cell - 4);
                dc.setColor(0x664400, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + 1, y + 2, cell - 2, cell - 4);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                if (cell >= 8) {
                    dc.fillRectangle(x + 2, y + cell / 3, cell - 4, cell / 4);
                }
            } else if (o.kind == KIND_LOG) {
                dc.setColor(0x884422, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y + 1, w, cell - 2);
                dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
                // Bark stripes.
                if (cell >= 8) {
                    for (var s = 1; s < o.len; s++) {
                        var sx = x + s * cell;
                        dc.drawLine(sx, y + 2, sx, y + cell - 3);
                    }
                }
                dc.setColor(0x442200, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(x, y + 1, w, cell - 2);
            }
        }
    }

    static function drawChicken(dc, ox, oy, cell, p) {
        var x = ox + (p.colFloat * cell).toNumber();
        var y = yOfRow(oy, cell, p.row);
        var cx = x + cell / 2;
        var cy = y + cell / 2;
        var rad = cell * 4 / 10;
        if (rad < 3) { rad = 3; }
        // Body — white
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, rad);
        // Red comb on top
        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        var combR = rad / 2; if (combR < 1) { combR = 1; }
        dc.fillCircle(cx, cy - rad + 1, combR);
        // Beak — orange, pointing along facing
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        var bx = 0; var by = 0;
        if      (p.facing == DIR_R2) { bx =  rad; }
        else if (p.facing == DIR_L2) { bx = -rad; }
        else                          { by = -rad; }
        dc.fillCircle(cx + bx / 2, cy + by / 2, 1);
        // Eye — black
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - rad / 3, cy - rad / 3, 1);
    }

    static function drawResult(dc, sw, sh, won, ctrl) {
        var bw = sw * 70 / 100; if (bw < 160) { bw = 160; }
        var bh = sh * 42 / 100; if (bh < 120) { bh = 120; }
        var bx = (sw - bw) / 2;
        var by = (sh - bh) / 2;
        var cx = sw / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(won ? 0xFFEE66 : 0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    won ? "HOME!" : "SQUASHED", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 38, Graphics.FONT_XTINY,
                    "Score " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 56, Graphics.FONT_XTINY,
                    "Level " + ctrl.level.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, by + 74, Graphics.FONT_XTINY,
                    "Best  " + ctrl.bestScore.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
