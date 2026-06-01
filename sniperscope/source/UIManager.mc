// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Top-level frame composition + menu/HUD/overlays.
//
// Layers (back → front):
//   • Scene (sky + skyline + grass)
//   • Wind streaks
//   • Targets (silhouettes + cover)
//   • Bullet trace
//   • Impact splash
//   • Scope mask (dark vignette + lens ring)
//   • Reticle (crosshair + breathing-coloured)
//   • HUD (round / score / wind / steady)
//   • RESULT / OVER / MENU overlays
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

class UIManager {

    // ── Menu row geometry (for tap hit-testing). ────────────
    static function rowGeom(sw, sh) {
        var rowH = (sh * 10) / 100; if (rowH < 22) { rowH = 22; } if (rowH > 28) { rowH = 28; }
        var rowW = (sw * 64) / 100; if (rowW < 130) { rowW = 130; }
        var rowX = (sw - rowW) / 2;
        var gap  = (sh * 2) / 100;  if (gap < 4) { gap = 4; }
        var rowY0 = (sh * 40) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function draw(dc, ctrl) {
        if (ctrl.state == SS_MENU) {
            _drawMenu(dc, ctrl); return;
        }
        var sh = ctrl.shakeOff();
        var ox = sh[0]; var oy = sh[1];

        ScopeRenderer.drawScene(dc, ctrl, ox, oy);
        ScopeRenderer.drawWindStreaks(dc, ctrl, ox, oy);
        _drawTargets(dc, ctrl, ox, oy);
        ScopeRenderer.drawBullet(dc, ctrl, ox, oy);
        ScopeRenderer.drawImpact(dc, ctrl);
        ScopeRenderer.drawScopeMask(dc, ctrl);
        ScopeRenderer.drawReticle(dc, ctrl);

        _drawHUD(dc, ctrl);
        if (ctrl.state == SS_RESULT) { _drawResult(dc, ctrl); }
        if (ctrl.state == SS_OVER)   { _drawOver(dc, ctrl);   }
    }

    // ── Targets (silhouettes) ────────────────────────────────
    hidden static function _drawTargets(dc, ctrl, ox, oy) {
        var sc = ScopeRenderer.scopeCircle(ctrl);
        var ccx = sc[0]; var ccy = sc[1]; var rr = sc[2];
        var r2  = rr * rr;
        for (var i = 0; i < SS_TGT_MAX; i++) {
            if (ctrl.targets.live[i] == 0) { continue; }
            var sp = ctrl.targetScreen(i);
            var sx = sp[0] + ox;
            var sy = sp[1] + oy;
            // Cull anything that's clearly off the scope.  (We still
            // allow generous overflow so silhouettes that are
            // partially in-view aren't suddenly cropped.)
            if (sx < ccx - rr - 30 || sx > ccx + rr + 30) { continue; }
            if (sy < ccy - rr - 30 || sy > ccy + rr + 30) { continue; }
            var s = ctrl.targetSize(i);
            _drawSilhouette(dc, sx, sy, s,
                            ctrl.targets.cover[i],
                            ctrl.targets.primary[i] == 1);
        }
    }

    // Stick-figure silhouette.  Anchor (sx, sy) = top of head.
    // Cover layers:
    //   0 = full body visible
    //   1 = legs hidden by low cover (grey box draws over legs)
    //   2 = chest + legs hidden (only head/shoulders peek above)
    hidden static function _drawSilhouette(dc, sx, sy, s, cover, isPrimary) {
        // Visual contrast: primaries are slightly darker (hostile
        // body armour) vs the decoys (lighter civvy clothing).  The
        // shape is the same — the player has to look CAREFULLY.
        var body = isPrimary ? 0x1A1A1A : 0x3A3A3A;
        var trim = isPrimary ? 0x2A1A1A : 0x4A4A4A;

        var headR = s * 35 / 100; if (headR < 4) { headR = 4; }
        var headY = sy + headR;
        var chestY = sy + (s *  9 / 10);
        var legY   = sy + (s * 17 / 10);
        var chestW = s * 80 / 100;
        var legW   = s * 70 / 100;

        // Legs.
        if (cover < 1) {
            dc.setColor(body, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - legW / 2, chestY + s / 5,
                             legW, s * 9 / 10);
            dc.setColor(trim, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx, chestY + s / 5, sx, legY + s / 2);
        }
        // Chest.
        if (cover < 2) {
            dc.setColor(body, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - chestW / 2, sy + 2 * headR,
                             chestW, s * 7 / 10);
            dc.setColor(trim, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(sx - chestW / 2, sy + 2 * headR,
                             chestW, s * 7 / 10);
        }
        // Head (always visible).
        dc.setColor(body, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, headY, headR);
        dc.setColor(trim, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sx, headY, headR);

        // Cover drawing (low wall / window frame).
        if (cover == 1) {
            dc.setColor(0x2A2C28, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - chestW, chestY + s / 5,
                             chestW * 2, s);
            dc.setColor(0x4A4C42, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(sx - chestW, chestY + s / 5,
                             chestW * 2, s);
        } else if (cover == 2) {
            // Window frame — only head exposed.
            var wx = sx - chestW; var wy = sy - headR / 2;
            var ww = chestW * 2;  var wh = s * 22 / 10;
            dc.setColor(0x1A1F2A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(wx, wy + headR * 2, ww, wh - headR * 2);
            dc.setColor(0x3A405A, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(wx, wy, ww, wh);
            // Horizontal frame split.
            dc.drawLine(wx, wy + headR * 2, wx + ww, wy + headR * 2);
        }
    }

    // ── HUD (round / score / wind / steady / breath) ────────
    hidden static function _drawHUD(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var ccx = ctrl.cx;

        // Round counter (top).
        var topY = sh * 6 / 100; if (topY < 4) { topY = 4; }
        var rl = "R" + (ctrl.round + 1).format("%d") + "/" + ctrl.totalRounds.format("%d");
        dc.setColor(0xCCEEBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, topY, Graphics.FONT_XTINY, rl,
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Score just below.
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, topY + 16, Graphics.FONT_XTINY,
                    ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Wind indicator (right side of upper hud).
        dc.setColor(0xAACCDD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw - 6, topY, Graphics.FONT_XTINY,
                    "W:" + ctrl.wind.label(),
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // Distance hint of the locked-on target (if any near centre).
        var distHint = _nearestDistanceHint(ctrl);
        if (distHint != null) {
            dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(6, topY, Graphics.FONT_XTINY,
                        "D:" + distHint + "m",
                        Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Steady-aim indicator (bottom centre).
        var bottomY = sh * 84 / 100;
        if (ctrl.breath.steady == 1) {
            dc.setColor(0x66FF66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ccx, bottomY, Graphics.FONT_XTINY,
                        "STEADY", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (ctrl.breath.fatigue > 1.6) {
            dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ccx, bottomY, Graphics.FONT_XTINY,
                        "BREATHE", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden static function _nearestDistanceHint(ctrl) {
        // Show the distance of the target closest to the scope centre.
        var best = -1;
        var bestD2 = 99999999;
        for (var i = 0; i < SS_TGT_MAX; i++) {
            if (ctrl.targets.live[i] == 0) { continue; }
            var sp = ctrl.targetScreen(i);
            var dx = sp[0] - ctrl.cx;
            var dy = sp[1] - ctrl.cy;
            var d2 = dx * dx + dy * dy;
            if (d2 < 70 * 70 && d2 < bestD2) { bestD2 = d2; best = i; }
        }
        if (best < 0) { return null; }
        return ctrl.targets.z[best].format("%d");
    }

    // ── RESULT overlay ──────────────────────────────────────
    hidden static function _drawResult(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var ccx = ctrl.cx;
        var label; var col;
        if (!ctrl.lastWasPrimary && ctrl.lastZone != SS_ZONE_MISS) {
            label = "CIVILIAN!"; col = 0xFF3344;
        } else if (ctrl.lastZone == SS_ZONE_HEAD) {
            label = "HEADSHOT"; col = 0xFFEE66;
        } else if (ctrl.lastZone == SS_ZONE_CHEST) {
            label = "CHEST HIT"; col = 0xFF9933;
        } else if (ctrl.lastZone == SS_ZONE_LIMB) {
            label = "LIMB HIT"; col = 0xCC8844;
        } else {
            label = "MISS"; col = 0x99AAAA;
        }
        // Pulsing text.
        var pulse = ((ctrl.resultT & 3) < 2);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var fontY = sh * 36 / 100;
        dc.drawText(ccx, fontY, pulse ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL,
                    label, Graphics.TEXT_JUSTIFY_CENTER);
        // Hint.
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 58 / 100, Graphics.FONT_XTINY,
                    "tap = next", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── OVER (mission recap) ────────────────────────────────
    hidden static function _drawOver(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var ccx = ctrl.cx;
        // Card backing.
        var bw = sw * 78 / 100; if (bw < 170) { bw = 170; }
        var bh = sh * 56 / 100; if (bh < 150) { bh = 150; }
        var bx = (sw - bw) / 2; var by = (sh - bh) / 2;
        dc.setColor(0x000406, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 10);
        dc.setColor(0xCCFF99, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 10);
        dc.drawText(ccx, by + 6, Graphics.FONT_SMALL,
                    "MISSION END", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 40, Graphics.FONT_XTINY,
                    "Score   " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 58, Graphics.FONT_XTINY,
                    "Heads   " + ctrl.headshots.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(ccx, by + 76, Graphics.FONT_XTINY,
                    "Best    " + ctrl.bestScore.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + bh - 16, Graphics.FONT_XTINY,
                    "tap = restart", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── MENU (chess-style) ──────────────────────────────────
    hidden static function _drawMenu(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var ccx = ctrl.cx;

        // Dark gradient backdrop with subtle scope vignette.
        dc.setColor(0x000406, 0x000406); dc.clear();
        // Faint reticle shadow on the title block.
        dc.setColor(0x102014, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ccx, sh * 20 / 100, sh * 13 / 100);
        dc.setColor(0x1A2A1F, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ccx, sh * 20 / 100, sh * 13 / 100);

        // Title.
        dc.setColor(0xCCFF99, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 12 / 100, Graphics.FONT_MEDIUM,
                    "SNIPER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 23 / 100, Graphics.FONT_SMALL,
                    "SCOPE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 33 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var labels = [
            "Sens:  " + ctrl.sensName(),
            "Diff:  " + ctrl.diffName(),
            "START"
        ];
        for (var i = 0; i < SS_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == SS_ROW_START);
            var bg; var bd; var fg;
            if (sel && isStart)  { bg = 0x223300; bd = 0xFFEE66; fg = 0xFFEE66; }
            else if (sel)         { bg = 0x142a14; bd = 0x66CC66; fg = 0xCCFF99; }
            else if (isStart)     { bg = 0x081008; bd = 0x335544; fg = 0xAACCBB; }
            else                   { bg = 0x081008; bd = 0x223322; fg = 0x99AABB; }
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
            dc.drawText(ccx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        // Best score footer.
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        if (ctrl.bestScore > 0) {
            dc.drawText(ccx, sh - 28, Graphics.FONT_XTINY,
                        "BEST " + ctrl.bestScore.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(ccx, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN  TAP = act", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
