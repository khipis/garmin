// ═══════════════════════════════════════════════════════════════
// MainView.mc — Render loop + tick driver + input dispatch.
//
// 40 ms tick (~25 Hz). Background, platforms, player are rendered
// each tick. Procedural tile-able starfield + horizon line keep the
// look interesting without bitmaps.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

const TICK_MS = 40;

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _timer;
    hidden var _laidOut;
    hidden var _bgFrame;            // counter for parallax animation

    function initialize() {
        View.initialize();
        _ctrl    = new GameController();
        _timer   = null;
        _laidOut = false;
        _bgFrame = 0;
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
        _bgFrame = (_bgFrame + 1) % 1000;
        WatchUi.requestUpdate();
    }

    // ── Drawing ─────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (!_laidOut) {
            _ctrl.setScreen(dc.getWidth(), dc.getHeight());
            _laidOut = true;
        }

        _drawBackground(dc);

        if (_ctrl.state == GS_MENU) { _drawMenu(dc); return; }

        var shx = 0;
        if (_ctrl.deathShake > 0) { shx = (Math.rand() % 7) - 3; }

        _drawPlatforms(dc, shx);
        // Player at its current screen-y.
        _ctrl.player.draw(dc, (_ctrl.player.x + shx).toNumber(),
                              _ctrl.player.y.toNumber());
        _drawHUD(dc);

        if (_ctrl.lastSpringFlash > 0) { _drawSpringFx(dc); }
        if (_ctrl.state == GS_READY)   { _drawReady(dc); }
        if (_ctrl.state == GS_OVER)    { _drawOver(dc); }
    }

    // Background. Previously a saturated purple brick wall with bold
    // black mortar joints — looked Doodle-Jump-y but visually competed
    // with the brown platforms, so the bricks and the platforms ran
    // into each other. Replaced with a calm dark-slate base + a faint
    // vertical gradient (deeper at the top), a barely-visible brick
    // hint (low-contrast horizontal lines only), and a handful of
    // small white snow specks for life. Platforms now have a strong
    // dark outline (see _drawPlatforms) so they pop against this.
    hidden function _drawBackground(dc) {
        var W = _ctrl.screenW; var H = _ctrl.screenH;

        // Base colour — calm dark slate-blue. Low chroma so it never
        // grabs the eye away from the action.
        dc.setColor(0x141A26, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, W, H);

        // Faint vertical gradient — a couple of darker horizontal
        // bands near the top. Cheap (just 3 fills) and adds depth.
        dc.setColor(0x0E1320, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, W, H / 5);
        dc.setColor(0x111726, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, H / 5, W, H / 10);

        // Very subtle brick hint — only the horizontal mortar lines,
        // very dim, no vertical separators, no per-brick fills. Just
        // enough texture to read as "a wall" but quiet enough to let
        // the platforms own the foreground.
        var brickH = 14;
        // _ctrl.score is a Float (accumulates physics dy). Coerce to
        // Number before the modulo — `Float % Int` raises an
        // UnexpectedTypeException on real watches even though the
        // simulator tolerates it.
        var scrollY = (_ctrl.score / 4).toNumber();
        dc.setColor(0x1A2236, Graphics.COLOR_TRANSPARENT);
        var ly = -(scrollY % brickH);
        while (ly < H) {
            dc.drawLine(0, ly, W, ly);
            ly = ly + brickH;
        }

        // A few small white snow specks drifting down — keeps the
        // scene alive without being noisy.
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            var sx = (i * 6151) % W;
            var driftY = (i * 4099 + _bgFrame * 2 / 5) % (H + 6);
            dc.fillRectangle(sx, driftY, 1, 1);
        }
    }

    hidden function _drawPlatforms(dc, shx) {
        var pm = _ctrl.platforms;
        var H = _ctrl.screenH;
        var pH = (H * 3) / 100; if (pH < 5) { pH = 5; }
        for (var i = 0; i < MAX_PLATFORMS; i++) {
            var p = pm.plats[i];
            if (!p.alive) { continue; }
            if (p.y < -pH - 6 || p.y > H + pH) { continue; }
            var x = p.x + shx;
            // Type-specific palette — saturated foreground colours so
            // each platform stands out against the calm dark slate
            // background. The dark outline below pushes them forward.
            var col   = 0x9A6630;  // warm wood
            var top   = 0xC8895A;  // lighter wood top
            var snow1 = 0xFFFFFF;  // snow cap highlight
            var snow2 = 0xCFE0FF;  // snow shadow
            if (p.type == PT_MOVING) {
                col = 0xC78938; top = 0xF0B560;
            } else if (p.type == PT_BREAKABLE) {
                col = 0xB03050; top = 0xE25075;
            } else if (p.type == PT_SPRING) {
                col = 0x2A82C8; top = 0x4FB0EF; snow2 = 0xC8F0FF;
            }

            // ── Dark outline — drawn first as a 1-px rect 1 px larger
            // on every side so the platform "pops" off the background.
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 1, p.y - 1, p.w + 2, pH + 2);
            // Plank body
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, p.y, p.w, pH);
            // Lighter face highlight
            dc.setColor(top, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 1, p.y + 1, p.w - 2, 2);
            // Two vertical grain seams
            dc.setColor(0x4A2A14, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x + p.w / 3, p.y + 1, x + p.w / 3, p.y + pH - 1);
            dc.drawLine(x + (p.w * 2) / 3, p.y + 1,
                        x + (p.w * 2) / 3, p.y + pH - 1);

            // ── SNOW CAP ────────────────────────────────────────────
            // A wavy white strip on top of every platform, with two
            // small bumps and tiny icicles dripping over the edges.
            var capH = pH - 1; if (capH < 3) { capH = 3; }
            var capY = p.y - (capH - 1);
            dc.setColor(snow2, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, p.y - 1, p.w, 2);
            dc.setColor(snow1, Graphics.COLOR_TRANSPARENT);
            // Bumpy top profile: rect + two circular caps
            dc.fillRectangle(x + 2, capY, p.w - 4, capH - 1);
            dc.fillCircle(x + 4,         capY + 1, 3);
            dc.fillCircle(x + p.w - 5,   capY + 1, 3);
            dc.fillCircle(x + p.w / 2,   capY,     4);
            // Icicles — two short downward drips at fixed positions
            dc.fillPolygon([[x + p.w / 4 - 1, p.y + pH - 1],
                            [x + p.w / 4 + 1, p.y + pH - 1],
                            [x + p.w / 4,     p.y + pH + 2]]);
            dc.fillPolygon([[x + (p.w * 3) / 4 - 1, p.y + pH - 1],
                            [x + (p.w * 3) / 4 + 1, p.y + pH - 1],
                            [x + (p.w * 3) / 4,     p.y + pH + 3]]);

            // ── Type-specific markers ───────────────────────────────
            if (p.type == PT_SPRING) {
                // Coil sticking up out of the snow
                dc.setColor(0xFFEE00, Graphics.COLOR_TRANSPARENT);
                var sx = x + p.w / 2;
                var sy = capY - 4;
                for (var k = 0; k < 3; k++) {
                    dc.drawLine(sx - 2, sy + k * 2, sx + 2, sy + k * 2);
                }
                dc.fillCircle(sx, sy - 2, 2);
            } else if (p.type == PT_BREAKABLE) {
                // Crack lines through the snow
                dc.setColor(0x550000, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(x + p.w / 3, capY,
                            x + p.w / 2, p.y + pH - 1);
                dc.drawLine(x + p.w / 2, p.y + 1,
                            x + (p.w * 2) / 3, p.y + pH - 1);
            } else if (p.type == PT_MOVING) {
                // Small directional arrow tucked into the snow cap
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
                if (p.vx > 0) {
                    dc.fillPolygon([[x + p.w - 7, capY + 1],
                                    [x + p.w - 2, capY + capH / 2],
                                    [x + p.w - 7, capY + capH - 1]]);
                } else {
                    dc.fillPolygon([[x + 6, capY + 1],
                                    [x + 1, capY + capH / 2],
                                    [x + 6, capY + capH - 1]]);
                }
            }
        }
    }

    hidden function _drawHUD(dc) {
        var cx = _ctrl.screenW / 2;
        // Score (height in metres) — big at top.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, 5, Graphics.FONT_MEDIUM,
                    _ctrl.heightMetres().format("%d") + "m",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 4, Graphics.FONT_MEDIUM,
                    _ctrl.heightMetres().format("%d") + "m",
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_ctrl.screenW - 4, 4, Graphics.FONT_XTINY,
                        "B " + (_ctrl.hi / 6).format("%d") + "m",
                        Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    hidden function _drawSpringFx(dc) {
        var cx = _ctrl.screenW / 2;
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _ctrl.screenH - 24, Graphics.FONT_XTINY,
                    "BOING!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawReady(dc) {
        var cx = _ctrl.screenW / 2;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _ctrl.screenH - 28, Graphics.FONT_XTINY,
                    "UP/DN to move", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Chess-style menu — dark base, two-line title, "by Bitochi"
    // attribution, decorative frog, single full-width START row.
    hidden function _drawMenu(dc) {
        var cx = _ctrl.screenW / 2;
        var W  = _ctrl.screenW;
        var H  = _ctrl.screenH;

        dc.setColor(0x080808, 0x080808); dc.clear();
        if (W == H) {
            dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, H / 2, W / 2 - 1);
        }

        // Title
        dc.setColor(0x44FFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 8 / 100, Graphics.FONT_SMALL,
                    "JUMP", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 19 / 100, Graphics.FONT_SMALL,
                    "TOWER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 30 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Decorative frog
        var fr = (H * 5) / 100; if (fr < 8) { fr = 8; }
        var pl = new Player();
        pl.reset(cx, H * 48 / 100, fr, fr + 2);
        pl.vy = -2.0;
        pl.draw(dc, cx, (H * 48) / 100);

        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 60 / 100, Graphics.FONT_XTINY,
                        "BEST " + (_ctrl.hi / 6).format("%d") + "m",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Chess-style START row
        var rowH = (H * 13) / 100; if (rowH < 26) { rowH = 26; }
        var rowW = (W * 78) / 100; if (rowW < 140) { rowW = 140; }
        var rowX = (W - rowW) / 2;
        var ry   = H * 70 / 100;
        dc.setColor(0x1A4400, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
        dc.setColor(0x44BB22, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
        var ay = ry + rowH / 2;
        dc.fillPolygon([[rowX + 5, ay - 4],
                        [rowX + 5, ay + 4],
                        [rowX + 11, ay]]);
        dc.setColor(0xAAFF66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                    "START", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H - 14, Graphics.FONT_XTINY,
                    "SEL / TAP to hop",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawOver(dc) {
        var bw = _ctrl.screenW * 70 / 100; if (bw < 160) { bw = 160; }
        var bh = _ctrl.screenH * 40 / 100; if (bh < 120) { bh = 120; }
        var bx = (_ctrl.screenW - bw) / 2;
        var by = (_ctrl.screenH - bh) / 2;
        dc.setColor(0x0A0A14, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        var cx = _ctrl.screenW / 2;
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    "SPLAT!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 30, Graphics.FONT_XTINY,
                    "Height " + _ctrl.heightMetres().format("%d") + "m",
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (_ctrl.score > 0 && _ctrl.score == _ctrl.hi) {
            dc.setColor(0x44FFAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 48, Graphics.FONT_XTINY,
                        "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 48, Graphics.FONT_XTINY,
                        "Best " + (_ctrl.hi / 6).format("%d") + "m",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Input intents (called from InputHandler) ────────────────────
    function holdLeft(b)   { _ctrl.setHoldLeft(b);  }
    function holdRight(b)  { _ctrl.setHoldRight(b); }
    function tap(dir)      { _ctrl.tapDir(dir);     }
    function isPassiveState() {
        return _ctrl.state == GS_MENU || _ctrl.state == GS_OVER;
    }
    function confirm() {
        if (_ctrl.state == GS_MENU) { _ctrl.ready(); _ctrl.state = GS_PLAY; }
        else if (_ctrl.state == GS_OVER) { _ctrl.gotoMenu(); }
    }
    function handleTap(x) {
        if (_ctrl.state == GS_MENU)  { _ctrl.ready(); _ctrl.state = GS_PLAY; return; }
        if (_ctrl.state == GS_OVER)  { _ctrl.gotoMenu(); return; }
        var dir = (x < _ctrl.screenW / 2) ? -1 : 1;
        _ctrl.tapDir(dir);
    }
    function handleBack() {
        if (_ctrl.state == GS_PLAY || _ctrl.state == GS_OVER
            || _ctrl.state == GS_READY) {
            _ctrl.gotoMenu();
            return true;
        }
        return false;
    }
}
