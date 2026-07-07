// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Pure rendering helpers for Manpac.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

class UIManager {

    // Geometry for a chess-style menu row.  Returns:
    //   [ rowH, rowW, rowX, rowY0, gap ]
    static function rowGeom(sw, sh) {
        // Space-aware layout for the 5 rows (Level, Lives, Speed, START,
        // LEADERBOARD).  The whole menu is ~18% more compact than before
        // (height, width and gaps) and the rows are packed into the band
        // between the title block and the bottom hint, so nothing ever
        // overlaps even on small round watches.
        var topZone      = (sh * 28) / 100;                  // rows start below "by Bitochi"
        var bottomMargin = (sh * 12) / 100; if (bottomMargin < 14) { bottomMargin = 14; }
        var gap          = (sh * 11) / 1000; if (gap < 3) { gap = 3; }   // ~10% < before
        var avail        = (sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (MENU_ROWS - 1)) / MENU_ROWS;
        if (rowH > 19) { rowH = 19; }                        // ~10% smaller cap
        if (rowH < 13) { rowH = 13; }
        var rowW = (sw * 58) / 100; if (rowW < 104) { rowW = 104; }      // ~10% smaller width
        var rowX = (sw - rowW) / 2;
        var used  = MENU_ROWS * rowH + (MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x000000, 0x000000); dc.clear();
        if (sw == sh) {
            dc.setColor(0x000814, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        // Title — bright yellow "MANPAC" + Bitochi attribution.
        dc.setColor(0xFFE100, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 10 / 100, Graphics.FONT_MEDIUM,
                    "MANPAC", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF55CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 22 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];

        var labels = [
            "Start L: " + ctrl.menuStartLevel.format("%d"),
            "Lives:   " + ctrl.menuLives.format("%d"),
            "Speed:   " + ctrl.speedName(),
            "START",
            ""
        ];
        for (var i = 0; i < MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);

            if (i == MP_ROW_LB) {
                // Hype-y gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == MP_ROW_START);
            dc.setColor(sel ? (isStart ? 0x332200 : 0x102040) : 0x0C1622, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFE100 : 0x55AAFF) : 0x223344, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xFFE100 : 0xCCEEFF) : 0x88AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN row  tap = act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    static function drawHUD(dc, sw, sh, ctrl) {
        var ty = (sh * 3) / 100; if (ty < 3) { ty = 3; }
        dc.setColor(0xFFE100, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, ty, Graphics.FONT_XTINY,
                    "S " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, ty, Graphics.FONT_XTINY,
                    "L" + ctrl.level.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF6688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw - 8, ty, Graphics.FONT_XTINY,
                    "x" + ctrl.lives.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
    }

    static function drawMaze(dc, ox, oy, cell, grid, n) {
        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                var t = grid[r * n + c];
                var x = ox + c * cell;
                var y = oy + r * cell;
                if (t == TILE_WALL) {
                    dc.setColor(0x002266, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, cell, cell);
                    dc.setColor(0x3366FF, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(x, y, cell, cell);
                } else if (t == TILE_PELLET) {
                    dc.setColor(0xFFE680, Graphics.COLOR_TRANSPARENT);
                    var r2 = cell / 8; if (r2 < 1) { r2 = 1; }
                    dc.fillCircle(x + cell / 2, y + cell / 2, r2);
                } else if (t == TILE_POWER) {
                    dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                    var r3 = cell / 3; if (r3 < 2) { r3 = 2; }
                    dc.fillCircle(x + cell / 2, y + cell / 2, r3);
                }
            }
        }
    }

    // Pac-Man — yellow disc with an angled bite that points along his
    // current heading.  Mouth opens/closes via player.mouthPhase 0..3.
    static function drawPlayer(dc, ox, oy, cell, player) {
        var cx = ox + player.c * cell + cell / 2;
        var cy = oy + player.r * cell + cell / 2;
        var rad = cell / 2 - 1; if (rad < 3) { rad = 3; }

        dc.setColor(0xFFE100, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, rad);

        // Closed-mouth frame: skip the bite triangle entirely.
        if (player.mouthPhase != 0) {
            // Bite triangle — black wedge pointing along player.dir.
            var open = (player.mouthPhase == 2) ? rad : (rad * 3 / 4);
            var dx = 0; var dy = 0;
            if      (player.dir == DIR_U) { dy = -open; }
            else if (player.dir == DIR_D) { dy =  open; }
            else if (player.dir == DIR_L) { dx = -open; }
            else                          { dx =  open; }
            var half = open / 2;
            // Two outer corners are perpendicular to the heading.
            var pxA; var pyA; var pxB; var pyB;
            if (player.dir == DIR_U || player.dir == DIR_D) {
                pxA = cx - half; pyA = cy + dy;
                pxB = cx + half; pyB = cy + dy;
            } else {
                pxA = cx + dx; pyA = cy - half;
                pxB = cx + dx; pyB = cy + half;
            }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx, cy], [pxA, pyA], [pxB, pyB]]);
        }
    }

    static function drawGhosts(dc, ox, oy, cell, ghosts, frightTicks) {
        var colors = [0xFF3333, 0xFF99CC, 0x33CCFF, 0xFFAA22];
        var blink  = (frightTicks > 0 && frightTicks <= 8 && (frightTicks % 2 == 0));
        for (var i = 0; i < ghosts.size(); i++) {
            var g = ghosts[i];
            if (!g.isActive()) { continue; }
            var x = ox + g.c * cell;
            var y = oy + g.r * cell;
            var cx = x + cell / 2; var cy = y + cell / 2;
            var rad = cell / 2 - 1; if (rad < 3) { rad = 3; }

            var bodyCol;
            if (g.frightened) {
                bodyCol = blink ? 0xFFFFFF : 0x3344CC;
            } else {
                bodyCol = colors[i % 4];
            }
            dc.setColor(bodyCol, Graphics.COLOR_TRANSPARENT);
            // Round top half.
            dc.fillCircle(cx, cy - 1, rad);
            // Square bottom half — covers from the equator down.
            dc.fillRectangle(cx - rad, cy - 1, rad * 2, rad);

            // Two white eyes with black pupils, pointing along g.dir.
            var eyeR = rad / 3; if (eyeR < 1) { eyeR = 1; }
            var eyeOffX = rad / 2;
            var eyeY    = cy - rad / 3;
            var leftX   = cx - eyeOffX;
            var rightX  = cx + eyeOffX;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(leftX,  eyeY, eyeR);
            dc.fillCircle(rightX, eyeY, eyeR);
            // Pupils shift along the ghost's facing.
            var pdx = 0; var pdy = 0;
            if      (g.dir == DIR_U) { pdy = -1; }
            else if (g.dir == DIR_D) { pdy =  1; }
            else if (g.dir == DIR_L) { pdx = -1; }
            else                     { pdx =  1; }
            var pupilR = eyeR / 2; if (pupilR < 1) { pupilR = 1; }
            dc.setColor(g.frightened ? 0xFFFFFF : 0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(leftX  + pdx, eyeY + pdy, pupilR);
            dc.fillCircle(rightX + pdx, eyeY + pdy, pupilR);
        }
    }

    static function drawResult(dc, sw, sh, won, ctrl) {
        var titleColor = won ? 0xFFE100 : 0xFF4466;
        var lines = [
            ["Score " + ctrl.score.format("%d"), 0xFFFFFF],
            ["Level " + ctrl.level.format("%d"), 0xFFFFFF],
            ["Best  " + ctrl.bestScore.format("%d"), 0xFFFFFF]
        ];
        GameOverCard.draw(dc, sw, sh, won ? "CLEARED!" : "GAME OVER",
                          titleColor, lines, "Tap = replay", titleColor);
    }
}
