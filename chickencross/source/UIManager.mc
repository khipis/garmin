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

    // Space-aware geometry for the menu rows.  Rows live below the
    // "by Bitochi" subtitle and shrink to fit between there and the
    // bottom hint so all CC_MENU_ROWS fit without overlap on small
    // round watches.  Returns [rowH, rowW, rowX, rowY0, gap].
    static function rowGeom(sw, sh) {
        var topZone      = (sh * 36) / 100;            // rows start under the subtitle
        var bottomMargin = (sh * 11) / 100; if (bottomMargin < 16) { bottomMargin = 16; }
        var gap          = (sh * 2)  / 100; if (gap < 3) { gap = 3; }
        var avail        = (sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (CC_MENU_ROWS - 1)) / CC_MENU_ROWS;
        if (rowH > 25) { rowH = 25; }
        if (rowH < 14) { rowH = 14; }
        var rowW = (sw * 70) / 100; if (rowW < 118) { rowW = 118; }
        var rowX = (sw - rowW) / 2;
        var used  = CC_MENU_ROWS * rowH + (CC_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
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
        dc.drawText(cx, sh *  9 / 100, Graphics.FONT_MEDIUM,
                    "CHICKEN", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF7733, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 19 / 100, Graphics.FONT_SMALL,
                    "CROSS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDDAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 30 / 100, Graphics.FONT_XTINY,
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
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == ctrl.menuRow);

            if (i == CC_ROW_LB) {
                // Gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == CC_ROW_START);
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
        var titleColor = won ? 0xFFEE66 : 0xFF4466;
        var lines = [
            ["Score " + ctrl.score.format("%d"), 0xFFFFFF],
            ["Level " + ctrl.level.format("%d"), 0xFFFFFF],
            ["Best  " + ctrl.bestScore.format("%d"), 0xFFFFFF]
        ];
        GameOverCard.draw(dc, sw, sh, won ? "HOME!" : "SQUASHED",
                          titleColor, lines, "Tap = menu", titleColor);
    }
}
