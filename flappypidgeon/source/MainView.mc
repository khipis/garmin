// ═══════════════════════════════════════════════════════════════
// MainView.mc — Render loop + tick driver.
//
// Fixed 40 ms tick (~25 Hz). Background, pipes, bird are rendered
// each tick. Procedural pixel-art skyline keeps battery cost low
// (no bitmaps to blit) and still gives the watch a city feel.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

const TICK_MS = 40;

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _timer;
    hidden var _laidOut;

    function initialize() {
        View.initialize();
        _ctrl    = new GameController();
        _timer   = null;
        _laidOut = false;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), TICK_MS, true);
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }
    function onTick() {
        _ctrl.step();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        if (!_laidOut) {
            _ctrl.setScreen(dc.getWidth(), dc.getHeight());
            _laidOut = true;
        }

        _drawBackground(dc);

        // Menu lives in the shared root view — drop straight into the
        // ready-to-flap state and never render an in-game menu here.
        if (_ctrl.state == GS_MENU) { _ctrl.ready(); }

        _drawPipes(dc);
        _drawGround(dc);
        _ctrl.bird.draw(dc);
        _drawHUD(dc);

        if (_ctrl.deathFlash > 0) {
            // Short white flash on death — fades over 4 ticks.
            var alpha = _ctrl.deathFlash * 60;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < alpha / 60; i++) {
                // crude rectangle "flash" — overdraw a few times
                dc.fillRectangle(0, 0, _ctrl.screenW, _ctrl.screenH);
            }
        }

        if (_ctrl.state == GS_READY) { _drawReady(dc);  }
        if (_ctrl.state == GS_OVER)  { _drawOver(dc);   }
    }

    // ── Background ─────────────────────────────────────────────────
    hidden function _drawBackground(dc) {
        var W = _ctrl.screenW; var H = _ctrl.screenH;
        // Sky gradient (3 bands top→bottom).
        dc.setColor(0x4488DD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, W, H / 3);
        dc.setColor(0x66AAEE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, H / 3, W, H / 3);
        dc.setColor(0x99CCEE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (H * 2) / 3, W, H / 3);

        // Cheap "clouds" — 4 fixed positions, slowly scroll left.
        var cy1 = H / 6;
        var cy2 = H / 4;
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        var sx  = _ctrl.bgScroll / 3;
        var w   = W + 60;
        var c1 = (W * 1 / 5 - sx) % w; if (c1 < -40) { c1 = c1 + w; }
        var c2 = (W * 3 / 5 - sx) % w; if (c2 < -40) { c2 = c2 + w; }
        var c3 = (W * 4 / 5 - sx) % w; if (c3 < -40) { c3 = c3 + w; }
        dc.fillCircle(c1, cy1, 8);
        dc.fillCircle(c1 + 8, cy1 + 2, 6);
        dc.fillCircle(c2, cy2, 7);
        dc.fillCircle(c3, cy1 + 8, 9);

        // Procedural city skyline strip
        var sky = _ctrl.floorY - (_ctrl.screenH * 18) / 100;
        if (sky < 1) { sky = 1; }
        dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
        var off = _ctrl.bgScroll / 2;
        var bxw = 18;
        var x = -((off) % bxw);
        while (x < W) {
            // Building heights deterministic by x
            var h = 10 + ((x * 1379) & 0x1F);
            dc.fillRectangle(x, _ctrl.floorY - h, bxw - 4, h);
            x = x + bxw;
        }
    }

    // ── Pipes ──────────────────────────────────────────────────────
    hidden function _drawPipes(dc) {
        var om = _ctrl.obstacles;
        for (var i = 0; i < MAX_PIPES; i++) {
            var p = om.pipes[i];
            if (p.x > _ctrl.screenW + 2) { continue; }
            if (p.x + p.w < -2)          { continue; }
            // Body — bright green
            dc.setColor(0x44CC44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(p.x, _ctrl.ceilY, p.w, p.gapTopY - _ctrl.ceilY);
            dc.fillRectangle(p.x, p.gapBotY, p.w, _ctrl.floorY - p.gapBotY);
            // Lip caps
            dc.setColor(0x55EE55, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(p.x - 2, p.gapTopY - 6, p.w + 4, 6);
            dc.fillRectangle(p.x - 2, p.gapBotY,     p.w + 4, 6);
            // Dark inner shading
            dc.setColor(0x227722, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(p.x + p.w - 3, _ctrl.ceilY, 3, p.gapTopY - _ctrl.ceilY);
            dc.fillRectangle(p.x + p.w - 3, p.gapBotY, 3, _ctrl.floorY - p.gapBotY);
            // Outline
            dc.setColor(0x115511, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(p.x, _ctrl.ceilY, p.w, p.gapTopY - _ctrl.ceilY);
            dc.drawRectangle(p.x, p.gapBotY, p.w, _ctrl.floorY - p.gapBotY);
        }
    }

    hidden function _drawGround(dc) {
        var H = _ctrl.screenH;
        // Earth strip
        dc.setColor(0xCC8855, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _ctrl.floorY, _ctrl.screenW, H - _ctrl.floorY);
        // Grass line
        dc.setColor(0x55AA33, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _ctrl.floorY, _ctrl.screenW, 4);
        // Scrolling grass stripes
        var off = _ctrl.bgScroll;
        dc.setColor(0xAA6633, Graphics.COLOR_TRANSPARENT);
        var sx = -((off) % 18);
        while (sx < _ctrl.screenW) {
            dc.fillRectangle(sx, _ctrl.floorY + 6, 9, 2);
            sx = sx + 18;
        }
    }

    // ── HUD ────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var cx = _ctrl.screenW / 2;
        // Score — big bold up top
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
    }

    // Menu row geometry — shared by the renderer and the tap hit-test so
    // they can never drift apart. The whole block is scaled ~18% smaller
    // than the old single-row menu so the START + LEADERBOARD rows both
    // fit without overlapping (incl. round-watch insets).
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

    // Chess-style menu — dark base, "by Bitochi" attribution,
    // decorative bird, START row + shared LEADERBOARD row.
    hidden function _drawMenu(dc) {
        var cx = _ctrl.screenW / 2;
        var W  = _ctrl.screenW;
        var H  = _ctrl.screenH;

        dc.setColor(0x080808, 0x080808); dc.clear();
        if (W == H) {
            dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, H / 2, W / 2 - 1);
        }

        // Title (~18% more compact than before to make room for the row)
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 10 / 100, Graphics.FONT_SMALL,
                    "FLAPPY", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 19 / 100, Graphics.FONT_SMALL,
                    "PIDGEON", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 28 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Decorative bird
        var br = (H * 4) / 100; if (br < 7) { br = 7; }
        var b  = new Bird();
        b.reset(cx, H * 40 / 100, br);
        b.vy = -1.0;
        b.draw(dc);

        // Best
        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 49 / 100, Graphics.FONT_XTINY,
                        "BEST " + _ctrl.hi.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        var rg     = menuRowGeom();
        var rowH   = rg[0]; var rowW = rg[1]; var rowX = rg[2];
        var startY = rg[3]; var lbY  = rg[4];

        // Chess-style START row (primary action — also the default flap).
        dc.setColor(0x1A4400, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rowX, startY, rowW, rowH, 5);
        dc.setColor(0x44BB22, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rowX, startY, rowW, rowH, 5);
        var ay = startY + rowH / 2;
        dc.fillPolygon([[rowX + 5, ay - 4],
                        [rowX + 5, ay + 4],
                        [rowX + 11, ay]]);
        dc.setColor(0xAAFF66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, startY + (rowH - 14) / 2, Graphics.FONT_XTINY,
                    "START", Graphics.TEXT_JUSTIFY_CENTER);

        // Shared global LEADERBOARD row.
        LbBadge.drawRow(dc, rowX, lbY, rowW, rowH, false);

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H - 13, Graphics.FONT_XTINY,
                    "flap=play  UP=board",
                    Graphics.TEXT_JUSTIFY_CENTER);
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

    hidden function _drawOver(dc) {
        var lines = [ ["Score " + _ctrl.score.format("%d"), 0xFFFFFF] ];
        if (_ctrl.score > 0 && _ctrl.score == _ctrl.hi) {
            lines.add(["NEW BEST!", 0x44FF66]);
        } else if (_ctrl.hi > 0) {
            lines.add(["Best " + _ctrl.hi.format("%d"), 0xFFCC22]);
        }
        GameOverCard.draw(dc, _ctrl.screenW, _ctrl.screenH,
                          "GAME OVER", 0xFF4466, lines, "Tap to retry", 0xFF4466);
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
