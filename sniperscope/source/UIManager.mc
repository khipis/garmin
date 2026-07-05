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
    // Space-aware: the four rows are packed into the strip between the
    // title block and a reserved bottom margin (footer + best/long
    // ribbon), so the extra LEADERBOARD row never overlaps the footer
    // or each other on small round watches.  Sizing is ~15-18 % smaller
    // than the old 3-row menu (height/gap) to make room for row 4.
    static function rowGeom(sw, sh) {
        var topZone      = (sh * 39) / 100;            // rows live below "by Bitochi"
        var bottomMargin = (sh * 19) / 100; if (bottomMargin < 36) { bottomMargin = 36; }
        var gap          = (sh * 2)  / 100; if (gap < 3) { gap = 3; }
        var avail        = (sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (SS_MENU_ROWS - 1)) / SS_MENU_ROWS;
        if (rowH > 22) { rowH = 22; }                  // was 28 → ~15 % smaller
        if (rowH < 13) { rowH = 13; }
        var rowW = (sw * 56) / 100; if (rowW < 115) { rowW = 115; }
        var rowX = (sw - rowW) / 2;
        var used  = SS_MENU_ROWS * rowH + (SS_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
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
        ScopeRenderer.drawMuzzleFlash(dc, ctrl);

        _drawHUD(dc, ctrl);
        if (ctrl.state == SS_RESULT) { _drawResult(dc, ctrl); }
        if (ctrl.state == SS_OVER)   { _drawOver(dc, ctrl);   }
    }

    // ── Targets (silhouettes) ────────────────────────────────
    hidden static function _drawTargets(dc, ctrl, ox, oy) {
        var sc = ScopeRenderer.scopeCircle(ctrl);
        var ccx = sc[0]; var ccy = sc[1]; var rr = sc[2];
        for (var i = 0; i < SS_TGT_MAX; i++) {
            if (ctrl.targets.live[i] == 0) { continue; }
            var sp = ctrl.targetScreen(i);
            var sx = sp[0] + ox;
            var sy = sp[1] + oy;
            if (sx < ccx - rr - 30 || sx > ccx + rr + 30) { continue; }
            if (sy < ccy - rr - 30 || sy > ccy + rr + 30) { continue; }
            var s = ctrl.targetSize(i);
            _drawSilhouette(dc, sx, sy, s,
                            ctrl.targets.cover[i],
                            ctrl.targets.primary[i] == 1,
                            ctrl.diff,
                            i);
        }
    }

    // Stick-figure silhouette.  Anchor (sx, sy) = top of head.
    //
    // ── HOSTILE vs DECOY identification ───────────────────────────
    // Prior revisions only changed the body grey from 0x1A → 0x3A,
    // which on a watch screen at 6-15 px silhouette size looked
    // identical.  The player had no way to tell them apart and the
    // game punished them for shooting civilians they couldn't see.
    //
    // Now: hostiles carry a visible RIFLE held across their chest
    // (a horizontal black bar with a small stock + barrel detail).
    // Decoys carry NOTHING — empty hands.  This is the kind of cue
    // a real sniper would scan for through the scope: "weapon? if
    // yes, take the shot; if no, hold fire."
    //
    // Difficulty scales the cue visibility:
    //   Easy   — rifle is full length, bright contrast
    //   Normal — rifle is shorter, lower contrast
    //   Hard   — rifle is just a small dark stub; decoys may also
    //            carry a similar-shaped bag, so the player has to
    //            look extra carefully
    //
    // Cover layers (unchanged):
    //   0 = full body visible
    //   1 = legs hidden by low cover
    //   2 = chest + legs hidden (only head/shoulders peek above)
    hidden static function _drawSilhouette(dc, sx, sy, s, cover, isPrimary, diff, idx) {
        var body = isPrimary ? 0x222226 : 0x4A4A52;
        var trim = isPrimary ? 0x4A2A2A : 0x6A6A72;

        var headR = s * 35 / 100; if (headR < 4) { headR = 4; }
        var headY = sy + headR;
        var chestY = sy + (s *  9 / 10);
        var legY   = sy + (s * 17 / 10);
        var chestW = s * 80 / 100;
        var legW   = s * 70 / 100;

        if (cover < 1) {
            dc.setColor(body, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - legW / 2, chestY + s / 5,
                             legW, s * 9 / 10);
            dc.setColor(trim, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx, chestY + s / 5, sx, legY + s / 2);
        }
        if (cover < 2) {
            dc.setColor(body, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - chestW / 2, sy + 2 * headR,
                             chestW, s * 7 / 10);
            dc.setColor(trim, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(sx - chestW / 2, sy + 2 * headR,
                             chestW, s * 7 / 10);
        }
        dc.setColor(body, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, headY, headR);
        dc.setColor(trim, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sx, headY, headR);

        // ── HOSTILE WEAPON ────────────────────────────────────
        // Drawn AFTER the body so it sits on top of the chest.  We
        // anchor it just below the head, centred on the chest, and
        // extend it horizontally to one side (deterministic by
        // target index so identical rounds look the same and the
        // player can predict orientation).
        if (isPrimary && cover < 2) {
            // Rifle length tapers as difficulty rises.
            var rifleLen;
            if      (diff == SS_DIFF_EASY)   { rifleLen = s * 110 / 100; }
            else if (diff == SS_DIFF_NORMAL) { rifleLen = s *  80 / 100; }
            else                              { rifleLen = s *  55 / 100; }
            if (rifleLen < 6) { rifleLen = 6; }
            // Side: alternate left/right by target slot.
            var sign = ((idx & 1) == 0) ? 1 : -1;
            var ry   = sy + 2 * headR + s * 25 / 100;   // shoulder level
            var rx0  = sx;
            var rx1  = sx + sign * rifleLen;
            // Barrel (dark line, thicker on Easy).
            var pw = (diff == SS_DIFF_EASY) ? 3 : 2;
            dc.setPenWidth(pw);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(rx0, ry, rx1, ry);
            dc.setPenWidth(1);
            // Stock — short stub on the opposite side of the muzzle.
            var stockW = s * 25 / 100; if (stockW < 3) { stockW = 3; }
            var stockH = (diff == SS_DIFF_EASY) ? 3 : 2;
            dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx0 - stockW / 2, ry - stockH / 2,
                             stockW, stockH);
            // Muzzle dot — gives the rifle a clear "front end".
            if (diff != SS_DIFF_HARD) {
                dc.setColor(0x554433, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(rx1 - sign, ry - 1, 2, 3);
            }
        }

        // ── DECOY ACCESSORY (Hard only) ────────────────────────
        // To keep Hard genuinely hard, decoys also carry a SMALL
        // bag/satchel that vaguely resembles a stock from far
        // away — the player must focus on the absence of a barrel
        // to distinguish them.
        if (!isPrimary && diff == SS_DIFF_HARD && cover < 2) {
            var bsign = ((idx & 1) == 0) ? 1 : -1;
            var by    = sy + 2 * headR + s * 35 / 100;
            dc.setColor(0x2A2A30, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx + bsign * (chestW / 2 - 1),
                              by, 3, 4);
        }

        // Cover drawing (low wall / window frame).
        if (cover == 1) {
            dc.setColor(0x3A4032, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - chestW, chestY + s / 5,
                             chestW * 2, s);
            dc.setColor(0x6A7050, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(sx - chestW, chestY + s / 5,
                             chestW * 2, s);
        } else if (cover == 2) {
            var wx = sx - chestW; var wy = sy - headR / 2;
            var ww = chestW * 2;  var wh = s * 22 / 10;
            dc.setColor(0x232A38, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(wx, wy + headR * 2, ww, wh - headR * 2);
            dc.setColor(0x4A506A, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(wx, wy, ww, wh);
            dc.drawLine(wx, wy + headR * 2, wx + ww, wy + headR * 2);
        }
    }

    // ── HUD (round / score / range / wind / steady) ─────────
    //
    // Layout:
    //   • top-centre   :  R k/N  +  score
    //   • right column :  est. range (m), est. wind (m/s)
    //                     — Easy/Normal only.  Hard hides both so
    //                       the player has to gauge by eye.
    //   • bottom-cent. :  STEADY / BREATHE coach text
    //
    // The readouts are deliberately "estimated":
    //   range  rounds to the nearest 20 m on Normal, exact on Easy
    //   wind   shows m/s with 1 decimal; sign as arrow
    hidden static function _drawHUD(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var ccx = ctrl.cx;

        var topY = sh * 6 / 100; if (topY < 4) { topY = 4; }
        var rl = "R" + (ctrl.round + 1).format("%d") + "/" + ctrl.totalRounds.format("%d");
        dc.setColor(0xDDF2C8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, topY, Graphics.FONT_XTINY, rl,
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, topY + 16, Graphics.FONT_XTINY,
                    ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Map/scene name — tiny, dim, top-left corner. Purely flavour
        // (tells the player which of the 3 rotating maps they landed
        // on this mission) so it stays out of the way of the score.
        dc.setColor(0x5A7A66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(6, topY, Graphics.FONT_XTINY, ctrl.sceneName(),
                    Graphics.TEXT_JUSTIFY_LEFT);

        // Headshot streak indicator — stays up while the streak is
        // alive so the player feels the tension of "don't miss now".
        if (ctrl.headStreak >= 2) {
            var pulse = ((ctrl.tick & 7) < 4);
            dc.setColor(pulse ? 0xFF8833 : 0xFFCC66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ccx, topY + 30, Graphics.FONT_XTINY,
                        "STREAK x" + ctrl.headStreak.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── RIGHT-COLUMN ASSISTS (Easy / Normal only) ─────────
        if (ctrl.diff != SS_DIFF_HARD) {
            var rightX = sw - 6;
            var rangeY = sh * 38 / 100;
            var windY  = sh * 50 / 100;

            // Range estimate of the target closest to the reticle.
            var rangeStr = _rangeEstimate(ctrl);
            if (rangeStr != null) {
                dc.setColor(0xC8E0F0, Graphics.COLOR_TRANSPARENT);
                dc.drawText(rightX, rangeY, Graphics.FONT_XTINY,
                            rangeStr, Graphics.TEXT_JUSTIFY_RIGHT);
                dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
                dc.drawText(rightX, rangeY + 12, Graphics.FONT_XTINY,
                            "RNG", Graphics.TEXT_JUSTIFY_RIGHT);
            }

            // Wind estimate.
            var windStr = _windEstimate(ctrl);
            dc.setColor(0xD8C898, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightX, windY, Graphics.FONT_XTINY,
                        windStr, Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rightX, windY + 12, Graphics.FONT_XTINY,
                        "WND", Graphics.TEXT_JUSTIFY_RIGHT);
        }

        var bottomY = sh * 84 / 100;
        if (ctrl.breath.steady == 1) {
            dc.setColor(0x88FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ccx, bottomY, Graphics.FONT_XTINY,
                        "STEADY", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (ctrl.breath.fatigue > 1.6) {
            dc.setColor(0xFF9955, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ccx, bottomY, Graphics.FONT_XTINY,
                        "BREATHE", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Range to the alive target nearest the reticle, formatted.
    // Easy: exact metres.  Normal: rounded to the nearest 20 m
    // (an "estimate" the spotter calls out, not a perfect lase).
    hidden static function _rangeEstimate(ctrl) {
        var best = -1;
        var bestD2 = 99999999;
        for (var i = 0; i < SS_TGT_MAX; i++) {
            if (ctrl.targets.live[i] == 0) { continue; }
            var sp = ctrl.targetScreen(i);
            var dx = sp[0] - ctrl.cx;
            var dy = sp[1] - ctrl.cy;
            var d2 = dx * dx + dy * dy;
            // Allow a generous proximity window so the assist is
            // useful while scanning, not only when perfectly on.
            if (d2 < 95 * 95 && d2 < bestD2) {
                bestD2 = d2; best = i;
            }
        }
        if (best < 0) { return null; }
        var z = ctrl.targets.z[best];
        if (ctrl.diff == SS_DIFF_EASY) {
            return z.format("%d") + "m";
        }
        // Normal: nearest 20 m.
        var r = ((z + 10) / 20) * 20;
        return "~" + r.format("%d") + "m";
    }

    // Wind estimate in m/s with arrow.  We map the abstract
    // strength scale to a plausible-feeling m/s number; the value
    // shown is a rough estimate, not exact.
    hidden static function _windEstimate(ctrl) {
        var w  = ctrl.wind.strength;
        var aw = (w < 0.0) ? -w : w;
        // 1.0 strength ≈ 2.5 m/s — light breeze.  Hard caps at 3.0
        // strength → 7.5 m/s.
        var ms = aw * 2.5;
        var arrow;
        if      (w >  0.05) { arrow = ">"; }
        else if (w < -0.05) { arrow = "<"; }
        else                 { arrow = "·"; }
        if (ctrl.diff == SS_DIFF_EASY) {
            return arrow + " " + ms.format("%.1f");
        }
        // Normal: round to nearest 0.5 to keep it "estimate"-y.
        var rounded = ((ms * 2.0 + 0.5).toNumber()).toFloat() / 2.0;
        return arrow + " ~" + rounded.format("%.1f");
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

        // Streak callout — multi-headshot combo, classic FPS-style
        // announcement + the flat bonus it earned.
        if (ctrl.streakMsg != null && !ctrl.streakMsg.equals("")) {
            var spulse = ((ctrl.resultT & 5) < 3);
            dc.setColor(spulse ? 0xFFDD33 : 0xFF9922, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ccx, sh * 48 / 100, Graphics.FONT_SMALL,
                        ctrl.streakMsg, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFFEE99, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ccx, sh * 58 / 100, Graphics.FONT_XTINY,
                        "+" + ctrl.streakBonus.format("%d") + " streak bonus",
                        Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ccx, sh * 68 / 100, Graphics.FONT_XTINY,
                        "tap = next", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Hint.
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 58 / 100, Graphics.FONT_XTINY,
                    "tap = next", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── OVER (mission recap) ────────────────────────────────
    // Two columns: this mission on the left, lifetime bests on the
    // right.  Highlights the spectacular shots — longest one-shot
    // kill in metres + lifetime kill count.
    hidden static function _drawOver(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var ccx = ctrl.cx;
        var bw = sw * 82 / 100; if (bw < 180) { bw = 180; }
        var bh = sh * 70 / 100; if (bh < 186) { bh = 186; }
        var bx = (sw - bw) / 2; var by = (sh - bh) / 2;

        var newRecord = ctrl.hasNewRecord();
        dc.setColor(0x00080A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 10);
        dc.setColor(newRecord ? 0xFFDD33 : 0xCCFF99, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 10);

        dc.drawText(ccx, by + 6, Graphics.FONT_SMALL,
                    "MISSION END", Graphics.TEXT_JUSTIFY_CENTER);

        // This mission.
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 32, Graphics.FONT_XTINY,
                    "Score   " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 48, Graphics.FONT_XTINY,
                    "Heads   " + ctrl.headshots.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Divider.
        dc.setColor(0x335544, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(bx + 14, by + 70, bx + bw - 14, by + 70);

        dc.setColor(0xAACC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 76, Graphics.FONT_XTINY,
                    "— ALL-TIME —", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 92, Graphics.FONT_XTINY,
                    "Best   " + ctrl.bestScore.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFB066, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 108, Graphics.FONT_XTINY,
                    "Long   " + ctrl.bestDistance.format("%d") + "m",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF99CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 124, Graphics.FONT_XTINY,
                    "Shot   " + ctrl.bestShotPts.format("%d") + "pt",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + 140, Graphics.FONT_XTINY,
                    "Kills  " + ctrl.lifetimeKills.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Banner — only shown when this mission actually broke a
        // personal best (also drives the gold border above).
        if (newRecord) {
            var pulse = ((ctrl.tick & 7) < 4);
            dc.setColor(pulse ? 0xFFDD33 : 0xFF9922, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ccx, by + 158, Graphics.FONT_XTINY,
                        "*** NEW RECORD! ***", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, by + bh - 14, Graphics.FONT_XTINY,
                    "tap = restart", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── MENU (chess-style) ──────────────────────────────────
    hidden static function _drawMenu(dc, ctrl) {
        var sw = ctrl.sw; var sh = ctrl.sh; var ccx = ctrl.cx;

        // Dark gradient backdrop with subtle scope vignette.
        dc.setColor(0x000406, 0x000406); dc.clear();
        // Faint reticle shadow on the title block.
        dc.setColor(0x102014, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ccx, sh * 23 / 100, sh * 12 / 100);
        dc.setColor(0x1A2A1F, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ccx, sh * 23 / 100, sh * 12 / 100);

        // Title.
        dc.setColor(0xCCFF99, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 16 / 100, Graphics.FONT_MEDIUM,
                    "SNIPER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 26 / 100, Graphics.FONT_SMALL,
                    "SCOPE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh * 35 / 100, Graphics.FONT_XTINY,
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

            if (i == SS_ROW_LB) {
                // Hype-y gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

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
        // Footer — best score + spectacular-shot stat ribbon.
        // Two rows: top is best score, bottom is longest shot ever.
        if (ctrl.bestScore > 0 || ctrl.bestDistance > 0) {
            dc.setColor(0x88AA9A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ccx, sh - 36, Graphics.FONT_XTINY,
                        "BEST " + ctrl.bestScore.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
            if (ctrl.bestDistance > 0) {
                dc.setColor(0xC8A878, Graphics.COLOR_TRANSPARENT);
                dc.drawText(ccx, sh - 24, Graphics.FONT_XTINY,
                            "LONG " + ctrl.bestDistance.format("%d") + "m",
                            Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ccx, sh - 12, Graphics.FONT_XTINY,
                    "UP/DN  TAP = act", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
