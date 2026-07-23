// ═══════════════════════════════════════════════════════════════
// MainView.mc — Render loop + tick driver.
//
// Fixed 40 ms tick (~25 Hz). Background, pipes, bird are rendered
// each tick. Procedural pixel-art skyline keeps battery cost low
// (no bitmaps to blit) and still gives the watch a city feel.
//
// Juice: score-driven sky theme (day → sunset → night), a feather
// burst + screen shake on death, near-miss sparks, and a rich
// game-over card with a score medal + meta-progression summary.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Application;

const TICK_MS = 40;

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _timer;
    hidden var _laidOut;
    hidden var _tick;

    function initialize() {
        View.initialize();
        _ctrl    = new GameController();
        _timer   = null;
        _laidOut = false;
        _tick    = 0;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), TICK_MS, true);
        // Surface today's login-streak bonus as a one-shot toast (queued by
        // the App's checkIn on the day's first launch).
        _ctrl.pullDailyToast();
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }
    function onTick() {
        _tick++;
        _ctrl.step();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        if (!_laidOut) {
            _ctrl.setScreen(dc.getWidth(), dc.getHeight());
            _laidOut = true;
        }

        // Screen-shake offset (foreground layers only — sky stays put so no
        // gaps open at the edges).
        var sx = 0; var sy = 0;
        if (_ctrl.shake > 0) {
            var m = _ctrl.shake / 2 + 1;
            sx = ((_tick % 2) == 0) ?  m : -m;
            sy = ((_tick % 2) == 0) ? -m :  m;
        }

        _drawBackground(dc);

        // Menu lives in the shared root view — drop straight into the
        // ready-to-flap state and never render an in-game menu here.
        if (_ctrl.state == GS_MENU) { _ctrl.ready(); }

        _drawPipes(dc, sx, sy);
        _drawGround(dc, sx, sy);
        _ctrl.particles.draw(dc, sx, sy);
        _ctrl.bird.drawAt(dc, sx, sy);
        _drawHUD(dc);
        _drawToast(dc);

        if (_ctrl.deathFlash > 0) {
            var reps = _ctrl.deathFlash;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < reps; i++) {
                dc.fillRectangle(0, 0, _ctrl.screenW, _ctrl.screenH);
            }
        }

        if (_ctrl.state == GS_READY) { _drawReady(dc);  }
        if (_ctrl.state == GS_OVER)  { _drawOver(dc);   }
    }

    // ── Background (score-driven theme) ────────────────────────────
    hidden function _drawBackground(dc) {
        var W = _ctrl.screenW; var H = _ctrl.screenH;
        var th = _ctrl.theme();

        // Three-band sky gradient per theme.
        var top; var mid; var bot; var cloudC; var bldgC;
        if (th == THEME_NIGHT) {
            top = 0x0A1030; mid = 0x14204A; bot = 0x243A66;
            cloudC = 0x445577; bldgC = 0x0E1830;
        } else if (th == THEME_SUNSET) {
            top = 0x3A3A72; mid = 0xE0705A; bot = 0xFFBB66;
            cloudC = 0xFFCFAA; bldgC = 0x3A2440;
        } else {
            top = 0x4488DD; mid = 0x66AAEE; bot = 0x99CCEE;
            cloudC = 0xCCDDEE; bldgC = 0x224466;
        }
        dc.setColor(top, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, W, H / 3);
        dc.setColor(mid, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, H / 3, W, H / 3);
        dc.setColor(bot, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (H * 2) / 3, W, H / 3);

        // Night sky gets a few deterministic stars in the upper band.
        if (th == THEME_NIGHT) {
            dc.setColor(0xF0F0FF, Graphics.COLOR_TRANSPARENT);
            var starB = _ctrl.floorY - (_ctrl.screenH * 22) / 100;
            for (var s = 0; s < 14; s++) {
                var sxp = ((s * 4397) % (W - 4)) + 2;
                var syp = ((s * 7919) % (starB - 4)) + 2;
                var tw = ((s + _tick / 8) % 5 != 0);   // faint twinkle
                if (tw) { dc.fillCircle(sxp, syp, 1); }
            }
        } else {
            // Sunset gets a low sun; day/sunset share soft clouds.
            if (th == THEME_SUNSET) {
                dc.setColor(0xFFE0A0, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(W * 3 / 4, H / 3, (W * 8) / 100);
            }
            var cy1 = H / 6;
            var cy2 = H / 4;
            dc.setColor(cloudC, Graphics.COLOR_TRANSPARENT);
            var scl = _ctrl.bgScroll / 3;
            var wgap = W + 60;
            var c1 = (W * 1 / 5 - scl) % wgap; if (c1 < -40) { c1 = c1 + wgap; }
            var c2 = (W * 3 / 5 - scl) % wgap; if (c2 < -40) { c2 = c2 + wgap; }
            var c3 = (W * 4 / 5 - scl) % wgap; if (c3 < -40) { c3 = c3 + wgap; }
            dc.fillCircle(c1, cy1, 8);
            dc.fillCircle(c1 + 8, cy1 + 2, 6);
            dc.fillCircle(c2, cy2, 7);
            dc.fillCircle(c3, cy1 + 8, 9);
        }

        // Procedural city skyline strip.
        var sky = _ctrl.floorY - (_ctrl.screenH * 18) / 100;
        if (sky < 1) { sky = 1; }
        dc.setColor(bldgC, Graphics.COLOR_TRANSPARENT);
        var off = _ctrl.bgScroll / 2;
        var bxw = 18;
        var x = -((off) % bxw);
        while (x < W) {
            var bh = 10 + ((x * 1379) & 0x1F);
            dc.fillRectangle(x, _ctrl.floorY - bh, bxw - 4, bh);
            // Lit windows at night.
            if (th == THEME_NIGHT && ((x * 733) & 0x3) == 0) {
                dc.setColor(0xFFDD66, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + 3, _ctrl.floorY - bh + 4, 3, 3);
                dc.setColor(bldgC, Graphics.COLOR_TRANSPARENT);
            }
            x = x + bxw;
        }
    }

    // ── Pipes ──────────────────────────────────────────────────────
    hidden function _drawPipes(dc, sx, sy) {
        var om = _ctrl.obstacles;
        for (var i = 0; i < MAX_PIPES; i++) {
            var p = om.pipes[i];
            var px = p.x + sx;
            if (px > _ctrl.screenW + 2) { continue; }
            if (px + p.w < -2)          { continue; }
            var ct = _ctrl.ceilY + sy;
            var ft = _ctrl.floorY + sy;
            var gt = p.gapTopY + sy;
            var gb = p.gapBotY + sy;
            // Body — bright green
            dc.setColor(0x44CC44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px, ct, p.w, gt - ct);
            dc.fillRectangle(px, gb, p.w, ft - gb);
            // Lip caps
            dc.setColor(0x55EE55, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 2, gt - 6, p.w + 4, 6);
            dc.fillRectangle(px - 2, gb,     p.w + 4, 6);
            // Dark inner shading
            dc.setColor(0x227722, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + p.w - 3, ct, 3, gt - ct);
            dc.fillRectangle(px + p.w - 3, gb, 3, ft - gb);
            // Outline
            dc.setColor(0x115511, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(px, ct, p.w, gt - ct);
            dc.drawRectangle(px, gb, p.w, ft - gb);
        }
    }

    hidden function _drawGround(dc, sx, sy) {
        var H = _ctrl.screenH;
        var th = _ctrl.theme();
        var earthC; var grassC; var stripeC;
        if (th == THEME_NIGHT) {
            earthC = 0x5C4433; grassC = 0x2F5A22; stripeC = 0x4A3320;
        } else if (th == THEME_SUNSET) {
            earthC = 0xB07044; grassC = 0x4E8A2E; stripeC = 0x8A5330;
        } else {
            earthC = 0xCC8855; grassC = 0x55AA33; stripeC = 0xAA6633;
        }
        var fy = _ctrl.floorY + sy;
        dc.setColor(earthC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, fy, _ctrl.screenW, H - fy + 8);
        dc.setColor(grassC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, fy, _ctrl.screenW, 4);
        var off = _ctrl.bgScroll;
        dc.setColor(stripeC, Graphics.COLOR_TRANSPARENT);
        var gx = -((off) % 18) + sx;
        while (gx < _ctrl.screenW) {
            dc.fillRectangle(gx, fy + 6, 9, 2);
            gx = gx + 18;
        }
    }

    // ── HUD ────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var cx = _ctrl.screenW / 2;
        // Score — big bold up top with a drop shadow for readability.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, 5, Graphics.FONT_MEDIUM,
                    _ctrl.score.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 4, Graphics.FONT_MEDIUM,
                    _ctrl.score.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_ctrl.screenW - 4, 4, Graphics.FONT_XTINY,
                        "B " + _ctrl.hi.format("%d"),
                        Graphics.TEXT_JUSTIFY_RIGHT);
        }
        // Near-miss praise popup — brief, near the bird's flight line.
        if (_ctrl.nearMissT > 0 && _ctrl.state == GS_PLAY) {
            dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _ctrl.screenH * 30 / 100, Graphics.FONT_XTINY,
                        "NICE! +1", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Non-blocking daily-bonus toast ─────────────────────────────
    hidden function _drawToast(dc) {
        if (_ctrl.toastT <= 0 || _ctrl.toastMsg == null) { return; }
        var W = _ctrl.screenW; var H = _ctrl.screenH;
        var bw = W * 74 / 100;
        var bh = H * 11 / 100; if (bh < 20) { bh = 20; }
        var bx = (W - bw) / 2;
        var by = H * 16 / 100;
        dc.setColor(0x0A2A12, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 6);
        dc.setColor(0x66FFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 6);
        dc.drawText(W / 2, by + bh / 2, Graphics.FONT_XTINY, _ctrl.toastMsg,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Menu row geometry — shared by the renderer and the tap hit-test so
    // they can never drift apart.
    //   [ rowH, rowW, rowX, startY, lbY ]
    function menuRowGeom() {
        var W = _ctrl.screenW;
        var H = _ctrl.screenH;
        var rowH = (H * 10) / 100; if (rowH < 20) { rowH = 20; }
        var rowW = (W * 58) / 100; if (rowW < 104) { rowW = 104; }
        var rowX = (W - rowW) / 2;
        var gap  = (H * 3) / 100;  if (gap < 5) { gap = 5; }
        var startY = (H * 57) / 100;
        var lbY    = startY + rowH + gap;
        return [rowH, rowW, rowX, startY, lbY];
    }

    // Open the shared global leaderboard for the chosen gap-size variant.
    function openLeaderboard() {
        var v = new LbScoresView("flappypidgeon", _ctrl.variant(), "FLAPPY");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    hidden function _drawReady(dc) {
        var cx = _ctrl.screenW / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, _ctrl.screenH * 24 / 100 + 1, Graphics.FONT_XTINY,
                    "Tap to flap", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _ctrl.screenH * 24 / 100, Graphics.FONT_XTINY,
                    "Tap to flap", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── GAME OVER ───────────────────────────────────────────────────
    // Rich card: score, best, a compact meta-progression line, streak and a
    // one-shot skin-unlock banner. A score medal is stamped in the corner.
    hidden function _drawOver(dc) {
        var lines = [ ["Score " + _ctrl.score.format("%d"), 0xFFFFFF] ];
        if (_ctrl.score > 0 && _ctrl.score == _ctrl.hi) {
            lines.add(["NEW BEST!", 0x44FF66]);
        } else if (_ctrl.hi > 0) {
            lines.add(["Best " + _ctrl.hi.format("%d"), 0xFFCC22]);
        }

        // Meta-progression summary (fully guarded).
        var coins = 0; var lvl = 1; var streak = 0;
        try { coins  = Progress.coins(); }         catch (e) {}
        try { lvl    = Progress.level(); }         catch (e) {}
        try { streak = Progress.currentStreak(); } catch (e) {}
        lines.add(["Lv " + lvl + " " + _ctrl.rankName() + " - " + coins + "c", 0xBFD8C4]);
        if (streak > 0) {
            lines.add(["Streak " + streak, 0x88CCFF]);
        }
        if (_ctrl.pgUnlockMsg != null) {
            lines.add([_ctrl.pgUnlockMsg, 0xFFD24A]);
        }

        var rect = GameOverCard.draw(dc, _ctrl.screenW, _ctrl.screenH,
                          "GAME OVER", 0xFF4466, lines, "Tap to retry", 0xFF4466);

        // Score medal stamped in the card's top-left corner (bronze/silver/gold).
        var tier = _ctrl.medalTier();
        if (tier > 0 && rect != null) {
            _drawMedal(dc, rect[0] + 20, rect[1] + 20, tier);
        }
    }

    // A small procedural medal: ribbon + coin disc + rim highlight.
    hidden function _drawMedal(dc, cx, cy, tier) {
        var disc; var rim;
        if (tier == 3)      { disc = 0xFFD24A; rim = 0xB8860B; }   // gold
        else if (tier == 2) { disc = 0xC8C8D0; rim = 0x808088; }   // silver
        else                { disc = 0xCD7F32; rim = 0x8A5320; }   // bronze
        // Ribbon
        dc.setColor(0xCC3344, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 6, cy - 2], [cx - 1, cy - 2], [cx - 3, cy + 8]]);
        dc.setColor(0x3355CC, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx + 1, cy - 2], [cx + 6, cy - 2], [cx + 3, cy + 8]]);
        // Disc
        dc.setColor(rim, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 9);
        dc.setColor(disc, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 7);
        // Star highlight
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 2, cy - 2, 2);
    }

    // ── Input intents ──────────────────────────────────────────────
    function inMenu() { return _ctrl.state == GS_MENU; }
    function handleFlap() { _ctrl.flapAction(); }

    // Tap router. On the MENU screen a tap inside the LEADERBOARD row
    // opens the board; every other tap (and any tap outside the menu)
    // is a flap, preserving the all-input-is-flap feel.
    function handleTap(x, y) {
        if (_ctrl.state == GS_MENU) {
            var rg   = menuRowGeom();
            var rowH = rg[0]; var rowW = rg[1]; var rowX = rg[2];
            var lbY  = rg[4];
            if (x >= rowX && x < rowX + rowW &&
                y >= lbY  && y < lbY  + rowH) {
                openLeaderboard();
                return;
            }
        }
        _ctrl.flapAction();
    }
    function handleBack() {
        // BACK always returns to the shared menu (pop the gameplay view).
        return false;
    }
}
