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
    hidden var _started;            // auto-start the run on first layout

    function initialize() {
        View.initialize();
        _ctrl    = new GameController();
        _timer   = null;
        _laidOut = false;
        _bgFrame = 0;
        _started = false;
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
        // Menu lives in the shared root view — drop straight into a run and
        // never render an in-game menu here.
        if (!_started || _ctrl.state == GS_MENU) {
            _ctrl.beginRun();
            _started = true;
        }

        _drawBackground(dc);

        var shx = 0;
        if (_ctrl.deathShake > 0) { shx = (Math.rand() % 7) - 3; }

        _drawPlatforms(dc, shx);
        if (_ctrl.jetpackT > 0) { _drawJetpackFlame(dc, shx); }
        // Player at its current screen-y.
        _ctrl.player.draw(dc, (_ctrl.player.x + shx).toNumber(),
                              _ctrl.player.y.toNumber());
        _drawHUD(dc);

        if (_ctrl.lastSpringFlash > 0) { _drawSpringFx(dc); }
        if (_ctrl.jetpackFlash    > 0) { _drawJetpackFx(dc); }
        if (_ctrl.coinFlash       > 0) { _drawCoinFx(dc); }
        if (_ctrl.zoneFlashT      > 0) { _drawZoneBanner(dc); }
        if (_ctrl.state == GS_READY)   { _drawReady(dc); }
        if (_ctrl.state == GS_OVER)    { _drawOver(dc); }
    }

    // Little flickering flame under the frog while the jetpack burns.
    hidden function _drawJetpackFlame(dc, shx) {
        var sx = (_ctrl.player.x + shx).toNumber();
        var sy = _ctrl.player.y.toNumber() + _ctrl.player.h;
        var flick = (_bgFrame % 3);
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[sx - 4, sy], [sx + 4, sy], [sx, sy + 8 + flick * 2]]);
        dc.setColor(0xFFEE88, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[sx - 2, sy], [sx + 2, sy], [sx, sy + 4 + flick]]);
    }

    // Background. Previously a saturated purple brick wall with bold
    // black mortar joints — looked Doodle-Jump-y but visually competed
    // with the brown platforms, so the bricks and the platforms ran
    // into each other. Replaced with a calm dark-slate base + a faint
    // vertical gradient (deeper at the top), a barely-visible brick
    // hint (low-contrast horizontal lines only), and a handful of
    // small white snow specks for life. Platforms now have a strong
    // dark outline (see _drawPlatforms) so they pop against this.
    //
    // The palette now shifts by altitude ZONE (see GameController.zone)
    // so the world visibly changes the higher you climb — ground wall,
    // then daylight sky with clouds, then a starry stratosphere, then
    // deep space. It's the single biggest "just a bit further" hook:
    // players keep climbing to see what the next zone looks like.
    hidden function _drawBackground(dc) {
        var z = _ctrl.zone;
        if      (z == 1) { _bgSky(dc);   }
        else if (z == 2) { _bgStrato(dc);}
        else if (z == 3) { _bgSpace(dc); }
        else              { _bgGround(dc);}
    }

    hidden function _bgGround(dc) {
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
        var scrollY = _bgScrollY();
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

    // Zone 1 — bright daytime sky with drifting clouds.
    hidden function _bgSky(dc) {
        var W = _ctrl.screenW; var H = _ctrl.screenH;
        dc.setColor(0x3E86D8, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, W, H);
        dc.setColor(0x62A6EE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, W, H / 4);

        var scrollY = _bgScrollY();
        dc.setColor(0xEAF5FF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var cx = (i * 5303 + W / 2) % W;
            var cy = (i * 3701 + scrollY / 2) % (H + 20) - 10;
            var r  = 7 + (i % 3) * 2;
            dc.fillCircle(cx - r, cy, r);
            dc.fillCircle(cx + r, cy, r);
            dc.fillCircle(cx, cy - r / 2, r + 2);
        }
    }

    // Zone 2 — thin, cold upper atmosphere; sky darkens, first stars.
    hidden function _bgStrato(dc) {
        var W = _ctrl.screenW; var H = _ctrl.screenH;
        dc.setColor(0x16214A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, W, H);
        dc.setColor(0x223066, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, W, H / 3);

        var scrollY = _bgScrollY();
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 10; i++) {
            var sx = (i * 4231) % W;
            var sy = (i * 6841 + scrollY / 3) % (H + 10);
            dc.fillRectangle(sx, sy, 1, 1);
        }
        // A thin violet haze band hints at the curvature of the sky.
        dc.setColor(0x4A3B7A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (H * 78) / 100, W, 2);
    }

    // Zone 3 — outer space: near-black, dense stars, a drifting moon.
    hidden function _bgSpace(dc) {
        var W = _ctrl.screenW; var H = _ctrl.screenH;
        dc.setColor(0x03040C, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, W, H);

        var scrollY = _bgScrollY();
        dc.setColor(0xCCCCEE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 16; i++) {
            var sx = (i * 3719) % W;
            var sy = (i * 5477 + scrollY / 4) % (H + 10);
            dc.fillRectangle(sx, sy, 1, 1);
        }
        // Drifting planet — a soft grey circle with one crater dimple.
        var mx = (W / 2 + (scrollY / 6) % (W + 60)) % (W + 60) - 30;
        var my = (H * 22) / 100;
        var mr = (W * 8) / 100; if (mr < 10) { mr = 10; }
        dc.setColor(0x8892A6, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, mr);
        dc.setColor(0x6B7590, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx - mr / 3, my - mr / 4, mr / 4);
    }

    // _ctrl.score is a Float (accumulates physics dy). Coerce to
    // Number before the modulo — `Float % Int` raises an
    // UnexpectedTypeException on real watches even though the
    // simulator tolerates it.
    hidden function _bgScrollY() {
        return (_ctrl.score / 4).toNumber();
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
            } else if (p.type == PT_JETPACK) {
                col = 0x707880; top = 0xC8D0D8; snow2 = 0xFFD27A;
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
            } else if (p.type == PT_JETPACK) {
                // A little rocket sitting on the platform — unmissable.
                var rx = x + p.w / 2;
                var ry = capY - 5;
                dc.setColor(0xE04030, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[rx - 3, ry + 6], [rx + 3, ry + 6],
                                [rx,     ry - 6]]);
                dc.setColor(0xFFD27A, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[rx - 4, ry + 8], [rx + 4, ry + 8],
                                [rx,     ry + 3]]);
                dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(rx, ry, 2);
            }

            if (p.coinAlive) { _drawCoin(dc, p.coinX + shx, p.coinY); }
        }
    }

    // Small spinning-looking gold coin — a slim vertical highlight
    // that widens/narrows with _bgFrame gives a cheap "flip" illusion
    // without any per-frame allocation.
    hidden function _drawCoin(dc, cx, cy) {
        var r = _ctrl.platforms.coinR;
        dc.setColor(0x8A6200, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r + 1);
        dc.setColor(0xFFD400, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        var flip = (_bgFrame / 6) % 4;
        var hw = (flip == 0 || flip == 2) ? r : ((flip == 1) ? r / 2 : 1);
        dc.setColor(0xFFF3B0, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - hw / 2, cy - r + 1, (hw < 1) ? 1 : hw, (r * 2) - 2);
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
        // Coin tally, top-left — small gold coin icon + count.
        dc.setColor(0xFFD400, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(11, 9, 5);
        dc.setColor(0x8A6200, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(11, 9, 5);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(20, 3, Graphics.FONT_XTINY,
                    _ctrl.coinsRun.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function _drawSpringFx(dc) {
        var cx = _ctrl.screenW / 2;
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _ctrl.screenH - 24, Graphics.FONT_XTINY,
                    "BOING!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawJetpackFx(dc) {
        var cx = _ctrl.screenW / 2;
        dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _ctrl.screenH - 24, Graphics.FONT_SMALL,
                    "JETPACK!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawCoinFx(dc) {
        var sy = _ctrl.player.y.toNumber() - _ctrl.player.h - 10
                 - (14 - _ctrl.coinFlash);
        dc.setColor(0xFFD400, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_ctrl.player.x.toNumber(), sy, Graphics.FONT_XTINY,
                    "+1", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawZoneBanner(dc) {
        var cx = _ctrl.screenW / 2;
        var cy = _ctrl.screenH * 38 / 100;
        var bw = _ctrl.screenW * 90 / 100;
        var bh = 20;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - bw / 2, cy - bh / 2, bw, bh, 6);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx - bw / 2, cy - bh / 2, bw, bh, 6);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 7, Graphics.FONT_XTINY,
                    _ctrl.zoneMsg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawReady(dc) {
        var cx = _ctrl.screenW / 2;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _ctrl.screenH - 28, Graphics.FONT_XTINY,
                    "UP/DN to move", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Geometry for the chess-style menu.  Space-aware: the row height
    // shrinks to whatever fits between the BEST line and the bottom
    // margin, so the LEADERBOARD row never overlaps anything on small
    // round watches.  Rows are ~18% smaller than the old single START
    // row to leave room for two rows.
    //   [ rowH, rowW, rowX, rowY0, gap ]
    function menuRowGeom() {
        var W = _ctrl.screenW;
        var H = _ctrl.screenH;
        var topZone      = (H * 56) / 100;          // rows live below BEST
        var bottomMargin = (H * 10) / 100; if (bottomMargin < 11) { bottomMargin = 11; }
        var gap          = (H * 2) / 100; if (gap < 4) { gap = 4; }
        var avail        = (H - bottomMargin) - topZone;
        var rowH         = (avail - gap * (JT_MENU_ROWS - 1)) / JT_MENU_ROWS;
        // Clamp ~18% smaller than the old 26 px row.
        if (rowH > 21) { rowH = 21; }
        if (rowH < 14) { rowH = 14; }
        var rowW = (W * 58) / 100; if (rowW < 104) { rowW = 104; }
        var rowX = (W - rowW) / 2;
        var used = JT_MENU_ROWS * rowH + (JT_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // Open the shared global leaderboard (no variant for Jump Tower).
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _ctrl.diffVariant(), "JUMP TOWER");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Chess-style menu — dark base, two-line title, "by Bitochi"
    // attribution, decorative frog, START + LEADERBOARD rows.
    // Decorations are nudged up (~18% tighter) so two rows fit.
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
        dc.drawText(cx, H * 10 / 100, Graphics.FONT_SMALL,
                    "JUMP", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 19 / 100, Graphics.FONT_SMALL,
                    "TOWER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 28 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Decorative frog (moved up to leave room for two rows) — shows
        // off whatever skin tier the player has unlocked with lifetime
        // coins, so the menu itself sells the progression hook.
        var fr = (H * 5) / 100; if (fr < 8) { fr = 8; }
        var pl = new Player();
        pl.reset(cx, H * 41 / 100, fr, fr + 2);
        pl.vy = -2.0;
        pl.skin = _ctrl.skinTier();
        pl.draw(dc, cx, (H * 41) / 100);

        // BEST height + lifetime coins share one line — the menu is too
        // tight (two chess rows below) to afford a second row of text.
        var statLine = "";
        if (_ctrl.hi > 0)        { statLine = "BEST " + (_ctrl.hi / 6).format("%d") + "m"; }
        if (_ctrl.lifeCoins > 0) {
            statLine = (statLine.length() > 0)
                ? (statLine + "  " + _ctrl.lifeCoins.format("%d") + "co")
                : (_ctrl.lifeCoins.format("%d") + " coins");
        }
        if (statLine.length() > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 50 / 100, Graphics.FONT_XTINY,
                        statLine, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Two chess-style rows: START + LEADERBOARD.
        var rg   = menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < JT_MENU_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _ctrl.menuRow);

            if (i == JT_ROW_LB) {
                // Hype-y gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            // START row.
            var bg; var bd; var fg;
            if (sel) { bg = 0x1A4400; bd = 0x44BB22; fg = 0xAAFF66; }
            else      { bg = 0x102010; bd = 0x224422; fg = 0x88AA88; }
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
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        "START", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H - 14, Graphics.FONT_XTINY,
                    "UP/DN  SEL/tap",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawOver(dc) {
        var borderC = _ctrl.hasNewCoinsRecord() ? 0xFFCC22 : 0xFF4466;
        var lines = [ ["Height " + _ctrl.heightMetres().format("%d") + "m", 0xFFFFFF] ];
        if (_ctrl.score > 0 && _ctrl.score == _ctrl.hi) {
            lines.add(["NEW BEST!", 0x44FFAA]);
        } else if (_ctrl.hi > 0) {
            lines.add(["Best " + (_ctrl.hi / 6).format("%d") + "m", 0xFFCC22]);
        }
        lines.add([_ctrl.coinsRun.format("%d") + " coins this run", 0xFFFFFF]);
        lines.add([_ctrl.lifeCoins.format("%d") + " lifetime", 0x99AABB]);
        if (_ctrl.hasNewCoinsRecord()) {
            lines.add(["*** BEST HAUL EVER! ***", 0xFFCC22]);
        }
        GameOverCard.draw(dc, _ctrl.screenW, _ctrl.screenH,
                          "SPLAT!", 0xFF4466, lines,
                          "Tap = replay  ESC = menu", borderC);
    }

    // ── Input intents (called from InputHandler) ────────────────────
    function holdLeft(b)   { _ctrl.setHoldLeft(b);  }
    function holdRight(b)  { _ctrl.setHoldRight(b); }
    function tap(dir)      { _ctrl.tapDir(dir);     }
    function isPassiveState() {
        return _ctrl.state == GS_MENU || _ctrl.state == GS_OVER;
    }
    function inMenu() { return _ctrl.state == GS_MENU; }
    function navUp()   { if (_ctrl.state == GS_MENU) { _ctrl.menuPrev(); } }
    function navDown() { if (_ctrl.state == GS_MENU) { _ctrl.menuNext(); } }
    function confirm() {
        // Game-over → restart in place (new run); menu is no longer here.
        if (_ctrl.state == GS_OVER) { _ctrl.beginRun(); }
    }
    function handleTap(x, y) {
        if (_ctrl.state == GS_OVER)  { _ctrl.beginRun(); return; }
        var dir = (x < _ctrl.screenW / 2) ? -1 : 1;
        _ctrl.tapDir(dir);
    }
    // BACK (physical ESC or right-edge exit) pops to the shared menu.
    function handleBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // ── Drag-based steering ────────────────────────────────────────
    // While the finger is on the screen we keep the character moving
    // toward whichever side the finger is currently on.  Direct,
    // intuitive, and immune to the SWIPE_LEFT / SWIPE_RIGHT direction
    // convention on whatever device the player is wearing.
    //
    //   side > 0  → finger on right half → holdRight on
    //   side < 0  → finger on left half  → holdLeft on
    //   side == 0 → finger lifted        → both holds released
    function touchSteer(side) {
        if (side > 0) {
            _ctrl.setHoldLeft(false);
            _ctrl.setHoldRight(true);
        } else if (side < 0) {
            _ctrl.setHoldLeft(true);
            _ctrl.setHoldRight(false);
        } else {
            _ctrl.setHoldLeft(false);
            _ctrl.setHoldRight(false);
        }
    }
    function screenW() { return _ctrl.screenW; }
}
