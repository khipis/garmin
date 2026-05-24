// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Drawing helpers for VoidRocks.
//
// We render in classic vector-game style:
//   • Ship          → cyan triangle, rotated by ship.angle
//   • Asteroids     → outlined irregular polygons rotated by .angle
//   • Bullets       → bright yellow 2 px dots
//   • Star field    → static dim points
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

class UIManager {

    // ── Menu geometry ───────────────────────────────────────────
    static function rowGeom(sw, sh) {
        var rowH = (sh * 11) / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
        var rowW = (sw * 78) / 100; if (rowW < 140) { rowW = 140; }
        var rowX = (sw - rowW) / 2;
        var gap  = (sh * 2)  / 100; if (gap  < 4)  { gap  = 4;  }
        var total = VR_MENU_ROWS * rowH + (VR_MENU_ROWS - 1) * gap;
        var rowY0 = (sh - total) / 2 + (sh * 6) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x000510, 0x000510); dc.clear();
        if (sw == sh) {
            dc.setColor(0x081025, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }

        // Title — two-line stack + Bitochi attribution under it
        // (subtitle position; stays visible inside round bezels).
        dc.setColor(0x99DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh *  4 / 100, Graphics.FONT_MEDIUM,
                    "VOID", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 16 / 100, Graphics.FONT_SMALL,
                    "ROCKS", Graphics.TEXT_JUSTIFY_CENTER);
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
        for (var i = 0; i < VR_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == VR_MENU_ROWS - 1);
            dc.setColor(sel ? (isStart ? 0x223300 : 0x101830) : 0x0A1020,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0x99DDFF) : 0x223344,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xFFEE66 : 0xCCEEFF) : 0x99AABB,
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
        dc.setColor(0x99DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, ty, Graphics.FONT_XTINY,
                    "W" + ctrl.wave.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF6688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw - 8, ty, Graphics.FONT_XTINY,
                    "x" + ctrl.lives.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ── Sparse star field (deterministic) ───────────────────────
    static function drawStars(dc, sw, sh) {
        dc.setColor(0x223355, Graphics.COLOR_TRANSPARENT);
        var pts = [
            [12, 28], [40, 60], [72, 22], [110, 92], [140, 36],
            [165, 130], [188, 65], [205, 180], [55, 150], [95, 200],
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

    // ── Ship ────────────────────────────────────────────────────
    // The ship is a triangle: nose at (0, -r), back-left
    // (-0.7r, 0.6r), back-right (0.7r, 0.6r).  Each vertex is
    // rotated by ship.angle then translated to ship.(x,y).
    static function drawShip(dc, ship) {
        if (!ship.alive) { return; }
        // While invulnerable, flash every other frame.
        if (ship.invul > 0 && (ship.invul % 4) >= 2) { return; }

        var ca = Math.cos(ship.angle);
        var sa = Math.sin(ship.angle);
        var r  = ship.radius;

        var nx = 0.0;     var ny = -r;
        var lx = -r*0.7;  var ly = r*0.6;
        var rx =  r*0.7;  var ry = r*0.6;

        // Apply rotation.  (x' = x·cos - y·sin, y' = x·sin + y·cos)
        var n = [ship.x + nx * ca - ny * sa, ship.y + nx * sa + ny * ca];
        var l = [ship.x + lx * ca - ly * sa, ship.y + lx * sa + ly * ca];
        var rr= [ship.x + rx * ca - ry * sa, ship.y + rx * sa + ry * ca];

        // Thrust flare (drawn first so it sits under the hull).
        if (ship.thrustOn) {
            var fx = 0.0;        var fy = r * 1.1;
            var fl = -r*0.35;    var flo = r * 0.55;
            var fr =  r*0.35;    var fro = r * 0.55;
            var fp = [ship.x + fx * ca - fy * sa, ship.y + fx * sa + fy * ca];
            var fpl= [ship.x + fl * ca - flo* sa, ship.y + fl * sa + flo* ca];
            var fpr= [ship.x + fr * ca - fro* sa, ship.y + fr * sa + fro* ca];
            dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([fpl, fpr, fp]);
        }

        // Hull — filled cyan triangle + white outline.
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([n, l, rr]);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(n[0],  n[1],  l[0],  l[1]);
        dc.drawLine(l[0],  l[1],  rr[0], rr[1]);
        dc.drawLine(rr[0], rr[1], n[0],  n[1]);
    }

    // ── Asteroids ───────────────────────────────────────────────
    // For each rock: rotate its unit-circle shape by `angle`,
    // scale by radius, translate to (x,y), then fillPolygon with
    // dark grey + light grey outline.
    static function drawAsteroids(dc, rocks, sw, sh) {
        for (var i = 0; i < rocks.size(); i++) {
            var a = rocks[i];
            if (!a.alive) { continue; }
            var ca = Math.cos(a.angle);
            var sa = Math.sin(a.angle);
            var pts = [];
            for (var k = 0; k < a.shape.size(); k++) {
                var v = a.shape[k];
                var ox = v[0] * a.radius;
                var oy = v[1] * a.radius;
                var px = a.x + ox * ca - oy * sa;
                var py = a.y + ox * sa + oy * ca;
                pts.add([px, py]);
            }
            // Body (slate).
            var fill;
            if      (a.size == AST_LARGE) { fill = 0x445566; }
            else if (a.size == AST_MED)   { fill = 0x556677; }
            else                           { fill = 0x667788; }
            dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(pts);
            // Outline.
            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            for (var m = 0; m < pts.size(); m++) {
                var p1 = pts[m];
                var p2 = pts[(m + 1) % pts.size()];
                dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
            }
        }
    }

    // ── Bullets ────────────────────────────────────────────────
    static function drawBullets(dc, bullets) {
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < bullets.size(); i++) {
            var b = bullets[i];
            if (!b.alive) { continue; }
            dc.fillRectangle(b.x.toNumber() - 1, b.y.toNumber() - 1, 3, 3);
        }
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
