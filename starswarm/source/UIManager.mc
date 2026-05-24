// ═══════════════════════════════════════════════════════════════
// UIManager.mc — All drawing helpers for StarSwarm.
//
// Coordinate system:
//   row 0 = TOP of the playfield (where the formation lives),
//   row SS_BOARD_ROWS-1 = BOTTOM (where the player sits).
//   screenY(row) = oy + row * cell      ← intuitive "y grows down"
//
// Chess-style menu mirrors the rest of the games in this repo:
// vertical stack of three rounded "rows" with a small arrow on
// the selected row and a tiny "StarSwarm by Bitochi" footer.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

class UIManager {

    // ── Menu geometry ────────────────────────────────────────────
    static function rowGeom(sw, sh) {
        var rowH = (sh * 11) / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
        var rowW = (sw * 78) / 100; if (rowW < 140) { rowW = 140; }
        var rowX = (sw - rowW) / 2;
        var gap  = (sh * 2)  / 100; if (gap  < 4)  { gap  = 4;  }
        var total = SS_MENU_ROWS * rowH + (SS_MENU_ROWS - 1) * gap;
        var rowY0 = (sh - total) / 2 + (sh * 6) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x000510, 0x000510); dc.clear();
        if (sw == sh) {
            // Subtle inner disc to clip to round face.
            dc.setColor(0x081025, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        // Title — two-line stack + Bitochi attribution under it
        // (subtitle position; stays visible inside round bezels).
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  4 / 100, Graphics.FONT_MEDIUM,
                    "STAR", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 16 / 100, Graphics.FONT_SMALL,
                    "SWARM", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT);
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
        for (var i = 0; i < SS_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == SS_MENU_ROWS - 1);
            dc.setColor(sel ? (isStart ? 0x223300 : 0x101830) : 0x0A1020, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0x66CCFF) : 0x223344, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0xCCEEFF) : 0x99AABB, Graphics.COLOR_TRANSPARENT);
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
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, ty, Graphics.FONT_XTINY,
                    "W" + ctrl.wave.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF6688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw - 8, ty, Graphics.FONT_XTINY,
                    "x" + ctrl.lives.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ── Sparse star field — purely cosmetic ─────────────────────
    static function drawStars(dc, sw, sh) {
        dc.setColor(0x223355, Graphics.COLOR_TRANSPARENT);
        // Pseudo-random fixed positions (deterministic so they
        // don't twinkle every frame).
        var pts = [
            [10, 30], [25, 90], [40, 200], [55, 60], [70, 150],
            [90, 20], [110, 110], [130, 180], [150, 50], [170, 130],
            [190, 80], [210, 200], [25, 250], [60, 280], [120, 260],
            [150, 290], [200, 250], [80, 220], [180, 30], [220, 100]
        ];
        for (var i = 0; i < pts.size(); i++) {
            var p = pts[i];
            if (p[0] < sw && p[1] < sh) {
                dc.fillRectangle(p[0], p[1], 1, 1);
            }
        }
    }

    // ── Enemies ─────────────────────────────────────────────────
    static function drawEnemies(dc, ox, oy, cell, enemies) {
        for (var i = 0; i < enemies.size(); i++) {
            var e = enemies[i];
            if (e.state == E_DEAD) { continue; }
            var x = ox + (e.col * cell).toNumber();
            var y = oy + (e.row * cell).toNumber();
            var cx = x + cell / 2;
            var cy = y + cell / 2;
            var rad = cell * 4 / 10; if (rad < 2) { rad = 2; }

            var body; var wing;
            if      (e.type == E_TYPE_BOSS)  { body = 0xFFEE66; wing = 0xCC8800; }
            else if (e.type == E_TYPE_GUARD) { body = 0xFF66AA; wing = 0xAA2266; }
            else                              { body = 0x55EE88; wing = 0x227755; }

            // Diving enemies tilt slightly (just a colour shift cue).
            if (e.state == E_DIVING) {
                body = 0xFF4422; wing = 0xCC1100;
            }

            // Body — small filled circle.
            dc.setColor(body, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, rad);

            // Wings — two triangles either side.
            dc.setColor(wing, Graphics.COLOR_TRANSPARENT);
            if (cell >= 6) {
                dc.fillPolygon([[cx - rad, cy],
                                [cx - rad - 2, cy - 2],
                                [cx - rad - 2, cy + 2]]);
                dc.fillPolygon([[cx + rad, cy],
                                [cx + rad + 2, cy - 2],
                                [cx + rad + 2, cy + 2]]);
            }
            // Eye specks.
            if (cell >= 8) {
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cx - 1, cy - 1, 1, 1);
                dc.fillRectangle(cx + 1, cy - 1, 1, 1);
            }
        }
    }

    // ── Player ship ─────────────────────────────────────────────
    static function drawPlayer(dc, ox, oy, cell, p) {
        var x = ox + (p.col * cell).toNumber();
        var y = oy + (p.row * cell).toNumber();
        var cx = x + cell / 2;
        var cy = y + cell / 2;
        var rad = cell * 4 / 10; if (rad < 3) { rad = 3; }
        // Hull — cyan triangle pointing up.
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx,          cy - rad],
                        [cx - rad,    cy + rad - 1],
                        [cx + rad,    cy + rad - 1]]);
        // Wing accents.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        if (cell >= 8) {
            dc.fillRectangle(cx - rad - 1, cy + rad - 3, rad / 2 + 1, 2);
            dc.fillRectangle(cx + rad / 2,  cy + rad - 3, rad / 2 + 1, 2);
        }
        // Cockpit dot.
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 1, cy - 1, 2, 2);
    }

    // ── Bullets ────────────────────────────────────────────────
    static function drawBullets(dc, ox, oy, cell, bullets) {
        dc.setColor(0xFFFF66, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < bullets.size(); i++) {
            var b = bullets[i];
            if (!b.alive) { continue; }
            var x = ox + (b.col * cell).toNumber() + cell / 2 - 1;
            var y = oy + (b.row * cell).toNumber();
            if (y < oy)                       { continue; }
            if (y > oy + cell * SS_BOARD_ROWS) { continue; }
            // 2 px wide × 4 px tall streak.
            var len = cell * 5 / 10; if (len < 4) { len = 4; }
            dc.fillRectangle(x, y, 2, len);
        }
    }

    // ── Result overlay ─────────────────────────────────────────
    static function drawResult(dc, sw, sh, won, ctrl) {
        var bw = sw * 72 / 100; if (bw < 160) { bw = 160; }
        var bh = sh * 44 / 100; if (bh < 120) { bh = 120; }
        var bx = (sw - bw) / 2;
        var by = (sh - bh) / 2;
        var cx = sw / 2;
        dc.setColor(0x000510, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(won ? 0xFFEE66 : 0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    won ? "VICTORY!" : "GAME OVER",
                    Graphics.TEXT_JUSTIFY_CENTER);
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
