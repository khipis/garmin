// ═══════════════════════════════════════════════════════════════
// BilliardView.mc  —  MainView + Rendering
// Draws the billiards table, balls, aim preview, HUD, menus.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Timer;

class BilliardView extends WatchUi.View {

    var _game;   // BilliardGame instance (game logic + physics + AI)
    var _timer;  // 33 ms game loop timer
    var _tick;   // frame counter for animations

    // Cached static table background (felt/rails/pockets/spots — none of
    // which ever change once the viewport is laid out). Redrawing all of
    // that from scratch every 33 ms tick was pure waste: it's ~20 draw
    // calls that are IDENTICAL every single frame during play. We render
    // it once into an offscreen bitmap and blit it with a single
    // drawBitmap() call per frame instead — a big constant-factor win on
    // the hottest code path (every tick, in every game state except the
    // menu/game-over screens which already draw their own background).
    hidden var _bgBmp;
    hidden var _bgBmpW;
    hidden var _bgBmpH;

    // Per-ball cumulative roll rotation (radians) — drives a small dark
    // fleck that visibly spins around a moving ball's centre, selling the
    // "rolling on felt" feel with almost zero extra render cost.
    hidden var _ballRot;

    function initialize() {
        View.initialize();
        _game = new BilliardGame();
        _tick = 0;
        _timer = null;
        _bgBmp = null;
        _bgBmpW = 0;
        _bgBmpH = 0;
        _ballRot = new [MAX_BALLS];
        for (var i = 0; i < MAX_BALLS; i++) { _ballRot[i] = 0.0; }
    }

    function onLayout(dc) {
        _game.setScreenSize(dc.getWidth(), dc.getHeight());
    }

    // Build (or rebuild, if the screen size ever changes) the cached table
    // background. Guarded with a try/catch — if bitmap creation isn't
    // available/fails for any reason we just keep drawing the table live
    // every frame like before, so this can never make things worse.
    hidden function _ensureBgBmp(g) {
        if (_bgBmp != null && _bgBmpW == g.sw && _bgBmpH == g.sh) { return; }
        _bgBmpW = g.sw; _bgBmpH = g.sh;
        _bgBmp = null;
        try {
            var ref = Graphics.createBufferedBitmap({ :width => g.sw, :height => g.sh });
            var bmp = (ref has :get) ? ref.get() : ref;
            if (bmp != null) {
                _drawTable(bmp.getDc(), g);
                _bgBmp = bmp;
            }
        } catch (e) {
            _bgBmp = null;
        }
    }

    // Run the 33 ms game loop only while the view is on screen. Stop it
    // when hidden (leaderboard pushed on top / app backgrounded) so the
    // timer can't keep stepping the game and calling requestUpdate()
    // after teardown.
    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 33, true);
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() as Void {
        _tick++;
        _game.step();
        if (_game.gs == BS_GAMEOVER) { _game.reportResult(); }
        if (_game.lbRequested) {
            _game.lbRequested = false;
            openLeaderboard();
        }
        // Advance the rolling-mark rotation for every moving ball —
        // rotation speed ∝ linear speed / radius (rolling without slip).
        for (var i = 0; i < MAX_BALLS; i++) {
            if (!_game.bAlive[i]) { continue; }
            var sp2 = _game.bvx[i]*_game.bvx[i] + _game.bvy[i]*_game.bvy[i];
            if (sp2 > 0.02) { _ballRot[i] += Math.sqrt(sp2) / BALL_R.toFloat(); }
        }
        WatchUi.requestUpdate();
    }

    // Open the shared global-leaderboard panel for the current pool game.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _game.lbVariant(), "BILLIARDS");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // ── Input passthrough ─────────────────────────────────────
    function doUp()      { _game.doUp(); }
    function doDown()    { _game.doDown(); }
    function doSelect()  { _game.doSelect(); }
    function doTap(x,y)  { _game.doTap(x, y); }
    function doBack()    { return _game.doBack(); }

    // ── Master draw dispatch ──────────────────────────────────
    function onUpdate(dc) {
        if (_game.sw == 0) { _game.setScreenSize(dc.getWidth(), dc.getHeight()); }
        var g = _game;
        if (g.gs == BS_MENU)     { _drawMenu(dc, g);     return; }
        if (g.gs == BS_GAMEOVER) { _drawGameOver(dc, g); return; }
        _ensureBgBmp(g);
        if (_bgBmp != null) { dc.drawBitmap(0, 0, _bgBmp); } else { _drawTable(dc, g); }
        _drawBounceFx(dc, g);
        _drawBalls(dc, g);
        if (g.turn == TURN_PLAYER && (g.gs == BS_AIM || g.gs == BS_POWER)) {
            _drawAimLine(dc, g);
        }
        if (!g.pvpMode && g.gs == BS_AI_WAIT) { _drawAiThinking(dc, g); }
        if (g.pvpMode && g.turn == TURN_AI && (g.gs == BS_AIM || g.gs == BS_POWER)) {
            _drawAimLine(dc, g);
        }
        if (g.gs == BS_POWER)   { _drawPowerBar(dc, g); }
        _drawHUD(dc, g);
        if (g.msgT > 0) { _drawMessage(dc, g); }
    }

    // ── MENU ──────────────────────────────────────────────────
    // Five selectable rows, each drawn as a full-width highlight bar so the
    // focused option is unmistakable. Header (title + compact ball rack) sits
    // up top; a single dim line under the rack explains the selected mode.
    hidden function _drawMenu(dc, g) {
        var w = g.sw; var h = g.sh;
        dc.setColor(0x0A1A0A, 0x0A1A0A); dc.clear();
        dc.setColor(0x0C3010, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h);

        // ── Header: title + compact decorative rack ──
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*6/100, Graphics.FONT_SMALL, "BILLIARDS", Graphics.TEXT_JUSTIFY_CENTER);

        var tx1 = w*30/100; var tx2 = w*70/100;
        var ty1 = h*18/100; var ty2 = h*25/100;
        dc.setColor(0x5C3010, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx1-3, ty1-3, tx2-tx1+6, ty2-ty1+6);
        dc.setColor(0x0F5020, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx1, ty1, tx2-tx1, ty2-ty1);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx1, ty1, 2); dc.fillCircle(tx2, ty1, 2);
        dc.fillCircle(tx1, ty2, 2); dc.fillCircle(tx2, ty2, 2);
        dc.fillCircle((tx1+tx2)/2, ty1, 2); dc.fillCircle((tx1+tx2)/2, ty2, 2);
        _drawMenuRack(dc, g, tx1, ty1, tx2, ty2);

        // Mode rules hint — always visible, tied to the current game type.
        var rules = (g.gameType == GT_3BALL)      ? "race - 3 balls"
                  : (g.gameType == GT_8BALL)      ? "groups - pot 8 to win"
                  : (g.gameType == GT_SNOOKER)    ? "reds 1pt - black 7pt"
                  : (g.gameType == GT_TIMEATTACK) ? "solo - beat the clock!"
                                                  : "lowest first - pot 9 wins";
        dc.setColor(0x6E9A6E, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*30/100, Graphics.FONT_XTINY, rules, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Selectable rows ──
        var dLabels = ["EASY", "MEDIUM", "HARD"];
        var dColors = [0x44CC44, 0xFFAA00, 0xEE3322];

        var top    = h*38/100;
        var bottom = h*94/100;
        var pitch  = (bottom - top) / 5;
        var rowH   = pitch - (pitch / 6);          // small gap between bars
        if (rowH < 16) { rowH = 16; }
        var barX   = w*9/100;
        var barW   = w - barX*2;

        // Row 0 — GAME MODE
        _menuRow(dc, g, 0, top + 0*pitch, rowH, barX, barW,
                 g.gameTypeLabel(), 0xFFFFFF);

        // Row 1 — VS MODE (irrelevant/greyed for solo TIME ATTACK)
        var isSolo = (g.gameType == GT_TIMEATTACK);
        var sel1 = (g.menuSel == 1);
        _menuBar(dc, sel1, top + 1*pitch, rowH, barX, barW);
        if (isSolo) {
            dc.setColor(sel1 ? 0x9FB39F : 0x4E664E, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, top + 1*pitch + rowH/2, Graphics.FONT_XTINY, "SOLO",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(sel1 ? 0xFFFFFF : _dim(0xFFFFFF), Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, top + 1*pitch + rowH/2, Graphics.FONT_XTINY,
                        (g.pvpMode ? "P vs P" : "P vs AI"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Row 2 — DIFFICULTY. Greyed when P vs P (AI unused); repurposed
        // as the TIME LIMIT selector in TIME ATTACK (same diff variable
        // and button, different meaning: EASY = most forgiving = longest
        // clock).
        var sel2 = (g.menuSel == 2);
        var r2y  = top + 2*pitch;
        _menuBar(dc, sel2, r2y, rowH, barX, barW);
        var r2mid = r2y + rowH/2;
        if (isSolo) {
            dc.setColor(sel2 ? 0xFFFFFF : 0xAFC6D6, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2 - 4, r2mid, Graphics.FONT_XTINY, "Time: ",
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(dColors[g.diff], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2 - 4, r2mid, Graphics.FONT_XTINY, g.timeAttackLimitSecs() + "s",
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (g.pvpMode) {
            dc.setColor(sel2 ? 0x9FB39F : 0x4E664E, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, r2mid, Graphics.FONT_XTINY, "Diff: —",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(sel2 ? 0xFFFFFF : 0xAFC6D6, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2 - 4, r2mid, Graphics.FONT_XTINY, "Diff: ",
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(dColors[g.diff], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2 - 4, r2mid, Graphics.FONT_XTINY, dLabels[g.diff],
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Row 3 — LEADERBOARD (gold). "N/A" when web isn't available.
        var sel3 = (g.menuSel == 3);
        var ok   = Leaderboard.isSupported();
        _menuRow(dc, g, 3, top + 3*pitch, rowH, barX, barW,
                 ok ? "LEADERBOARD" : "LEADERBOARD N/A",
                 ok ? (sel3 ? 0xFFD24A : 0xD8A82A) : 0x7A7A7A);

        // Row 4 — START (blinks when focused)
        var sel4   = (g.menuSel == 4);
        var bright = (_tick % 14 < 7);
        var startClr = sel4 ? (bright ? 0x66FFAA : 0xFFFFFF) : 0x6EC07E;
        _menuRow(dc, g, 4, top + 4*pitch, rowH, barX, barW, "START", startClr);
    }

    // Draws the highlight bar behind a focused menu row (no-op when not
    // selected). Bar = darker felt fill with a gold edge and a left chevron.
    hidden function _menuBar(dc, sel, y, rowH, barX, barW) {
        if (!sel) { return; }
        dc.setColor(0x14431F, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, y, barW, rowH, 6);
        dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(barX, y, barW, rowH, 6);
        // Left chevron marker
        dc.drawText(barX + 8, y + rowH/2, Graphics.FONT_XTINY, ">",
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Convenience: highlight bar + a single centered label for a menu row.
    hidden function _menuRow(dc, g, idx, y, rowH, barX, barW, label, color) {
        var sel = (g.menuSel == idx);
        _menuBar(dc, sel, y, rowH, barX, barW);
        dc.setColor(sel ? color : _dim(color), Graphics.COLOR_TRANSPARENT);
        dc.drawText(g.sw/2, y + rowH/2, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Roughly halve a colour's brightness for the unfocused state.
    hidden function _dim(color) {
        var r = (color >> 16) & 0xFF;
        var gg = (color >> 8) & 0xFF;
        var b = color & 0xFF;
        r = r * 55 / 100; gg = gg * 55 / 100; b = b * 55 / 100;
        return (r << 16) | (gg << 8) | b;
    }

    // Draws a small decorative rack of balls reflecting the current game type.
    hidden function _drawMenuRack(dc, g, tx1, ty1, tx2, ty2) {
        var cx = (tx1 + tx2) / 2;
        var cy = (ty1 + ty2) / 2;
        var step;            // horizontal pitch between balls in pixels
        var posList;         // [[dx_steps, dy_steps], ...] from rack-centre, in step units
        var palette = g.bCol;

        if (g.gameType == GT_3BALL) {
            step = 9;
            // Cue at left, then triangle of 3 to the right
            posList = [[-3, 0, 0], [1, -1, 1], [2, 0, 2], [1, 1, 3]];
        } else if (g.gameType == GT_SNOOKER) {
            step = 8;
            // Cue + 6 reds triangle + black behind
            posList = [[-5, 0, 0],
                       [-2, 0, 1],
                       [-1, -1, 2], [-1, 1, 3],
                       [0, -2, 4], [0, 0, 5], [0, 2, 6],
                       [2, 0, 7]];
        } else if (g.gameType == GT_8BALL || g.gameType == GT_TIMEATTACK) {
            step = 7;
            // Cue + condensed 5-row triangle (15 numbered).
            posList = [[-7, 0, 0],
                       [-3, 0, 1],
                       [-2, -1, 2], [-2, 1, 3],
                       [-1, -2, 4], [-1, 0, 8], [-1, 2, 5],
                       [0, -3, 9], [0, -1, 6], [0, 1, 7], [0, 3, 10],
                       [1, -4, 11], [1, -2, 12], [1, 0, 13], [1, 2, 14], [1, 4, 15]];
        } else { // GT_9BALL — cue + diamond of 9
            step = 8;
            posList = [[-5, 0, 0],
                       [-2, 0, 1],
                       [-1, -1, 2], [-1, 1, 3],
                       [0, -2, 4], [0, 0, 9], [0, 2, 6],
                       [1, -1, 7], [1, 1, 8],
                       [2, 0, 5]];
        }

        var halfStep = step / 2;
        for (var i = 0; i < posList.size(); i++) {
            var px = cx + posList[i][0] * step;
            var py = cy + posList[i][1] * halfStep;
            var bi = posList[i][2];
            if (bi >= palette.size()) { continue; }
            if (g.isStripe(bi)) {
                dc.setColor(0xF2F2F2, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 5);
                dc.setClip(px - 6, py - 2, 13, 4);
                dc.setColor(palette[bi], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 5);
                dc.clearClip();
                dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(px, py, 5);
            } else {
                dc.setColor(palette[bi], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 5);
                if (g.isSolid(bi)) {
                    dc.setColor(0xF2F2F2, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(px, py, 2);
                }
            }
            // Tiny gloss
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - 1, py - 1, 1);
        }
    }

    // ── TABLE ─────────────────────────────────────────────────
    hidden function _drawTable(dc, g) {
        dc.setColor(0x060F06, 0x060F06); dc.clear();
        // Outer rail shadow
        var ox1 = g.csx(TL-22); var oy1 = g.csy(TT-28);
        var ox2 = g.csx(TR+22); var oy2 = g.csy(TB+28);
        dc.setColor(0x3A1A06, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ox1, oy1, ox2-ox1, oy2-oy1);
        // Rail
        var rx1 = g.csx(TL); var ry1 = g.csy(TT);
        var rx2 = g.csx(TR); var ry2 = g.csy(TB);
        dc.setColor(0x6B3410, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(rx1, ry1, rx2-rx1, ry2-ry1);
        // Felt surface
        var fx1 = g.csx(WL); var fy1 = g.csy(WT);
        var fx2 = g.csx(WR); var fy2 = g.csy(WB);
        dc.setColor(0x0E5020, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fx1, fy1, fx2-fx1, fy2-fy1);
        // Centre spot & baulk spot
        dc.setColor(0x185C28, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(fx1, (fy1+fy2)/2, fx2, (fy1+fy2)/2);
        dc.fillCircle(g.csx(500), g.csy(350), 3); // centre spot
        dc.fillCircle(g.csx(250), g.csy(350), 2); // baulk spot
        // Baulk line (semicircle on left side)
        dc.setColor(0x185C28, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(g.csx(250), fy1, g.csx(250), fy2);
        // Pockets
        var pr = g.csr(POCKET_R) + 2;
        for (var p = 0; p < NUM_POCKETS; p++) {
            var psx = g.csx(g.pX[p]); var psy = g.csy(g.pY[p]);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(psx, psy, pr);
            dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(psx, psy, pr);
        }
    }

    // ── CUSHION-IMPACT FLASH ───────────────────────────────────
    // Small expanding, fading ring at each recent hard rail bounce —
    // cheap (outline circle only) and only drawn while a slot is alive.
    hidden function _drawBounceFx(dc, g) {
        for (var f = 0; f < BOUNCE_FX_MAX; f++) {
            var life = g.bounceFxLife[f];
            if (life <= 0) { continue; }
            var fsx = g.csx(g.bounceFxX[f]); var fsy = g.csy(g.bounceFxY[f]);
            var age = BOUNCE_FX_LIFE - life;              // 0 (new) .. LIFE-1 (old)
            var r = g.csr(BALL_R) * (6 + age * 3) / 10;    // ring grows outward
            var shade = 0xFF - (age * 255 / BOUNCE_FX_LIFE);
            if (shade < 0) { shade = 0; }
            var clr = (shade << 16) | (shade << 8) | shade;
            dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(fsx, fsy, r);
        }
    }

    // ── BALLS ─────────────────────────────────────────────────
    hidden function _drawBalls(dc, g) {
        var br = g.csr(BALL_R); if (br < 4) { br = 4; }
        for (var i = 0; i < g.numBalls; i++) {
            if (!g.bAlive[i]) { continue; }
            var bsx = g.csx(g.bx[i]); var bsy = g.csy(g.by[i]);
            var v2 = g.bvx[i]*g.bvx[i] + g.bvy[i]*g.bvy[i];

            // Motion trail — a short comet-tail of shrinking dots behind
            // fast-moving balls, in the ball's own colour. Drawn first so
            // the crisp ball always renders on top of its own trail.
            if (v2 > 16.0) {
                var spd = Math.sqrt(v2);
                var dxn = g.bvx[i] / spd; var dyn = g.bvy[i] / spd;
                var trailClr = g.isStripe(i) ? 0xF2F2F2 : g.bCol[i];
                for (var tI = 3; tI >= 1; tI--) {
                    var td = tI * (br * 0.85 + 1);
                    var tx = bsx - (dxn * td).toNumber();
                    var ty = bsy - (dyn * td).toNumber();
                    var trR = (br * (4 - tI)) / 6; if (trR < 1) { trR = 1; }
                    dc.setColor(trailClr, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(tx, ty, trR);
                }
            }

            // Drop shadow
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bsx+1, bsy+1, br);

            if (g.isStripe(i)) {
                // STRIPED ball — white sphere with coloured equator band.
                // Clip the coloured fill to a horizontal band through the
                // ball's centre so the result looks like a classic 8-ball
                // stripe at any radius.
                dc.setColor(0xF2F2F2, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(bsx, bsy, br);
                var bandH = br * 9 / 10; if (bandH < 3) { bandH = 3; }
                dc.setClip(bsx - br - 1, bsy - bandH/2, br*2 + 3, bandH);
                dc.setColor(g.bCol[i], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(bsx, bsy, br);
                dc.clearClip();
                // Thin outline so the white doesn't bleed into the felt
                dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(bsx, bsy, br);
            } else {
                // SOLID / cue / 8-ball — full-colour fill
                dc.setColor(g.bCol[i], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(bsx, bsy, br);
                // For SOLID numbered balls (1..7) in 8-ball, add a small
                // central white "number disc" so it visually contrasts
                // with stripes (which have white at the poles).
                if (g.isSolid(i)) {
                    var dotR = br / 3; if (dotR < 2) { dotR = 2; }
                    dc.setColor(0xF2F2F2, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(bsx, bsy, dotR);
                }
            }

            // Gloss highlight (always)
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bsx - br*2/5, bsy - br*2/5, br/4 + 1);
            // Rolling-spin mark — a small dark fleck orbiting the centre
            // as the ball rolls (rotation ∝ distance travelled). Purely
            // cosmetic; makes movement read as genuine rolling instead of
            // a flat disc sliding across the felt.
            if (v2 > 4.0) {
                var mAng = _ballRot[i];
                var mx = bsx + (Math.cos(mAng) * br * 0.55).toNumber();
                var my = bsy + (Math.sin(mAng) * br * 0.55).toNumber();
                var mr = br / 6; if (mr < 1) { mr = 1; }
                dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(mx, my, mr);
            }
            // Cue-ball rim
            if (i == 0) {
                dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(bsx, bsy, br);
            }
            // Key-ball (8 or 9) gets a subtle gold halo so the player can
            // pick it out of the crowd, especially in 8-ball mode.
            else if (g.isKeyBall(i)) {
                dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(bsx, bsy, br);
                dc.drawCircle(bsx, bsy, br + 1);
            }
        }
    }

    // ── AIM LINE + GHOST-BALL PREVIEW ─────────────────────────
    // Physically-correct preview:
    //   • Cue line  : cue ball → ghost-ball (contact point on aim ray)
    //   • Target line: target centre → along the LINE OF CENTRES
    //                  (ghost→target).  This is the actual direction
    //                  the target will fly after impact and preserves
    //                  cut angles — previously this line was drawn in
    //                  the cue's own direction, which is unphysical.
    //   • Cue-deflection line: perpendicular to the line of centres
    //                  (tangent-line rule for equal-mass elastic
    //                  collision).  Length scales with the cut angle:
    //                  a full hit ⇒ cue stops, a thin cut ⇒ cue keeps
    //                  rolling almost full speed sideways.
    hidden function _drawAimLine(dc, g) {
        var rad = g.aimAngle * Math.PI / 180.0;
        var dirx = Math.cos(rad); var diry = Math.sin(rad);
        var csx0 = g.csx(g.bx[0]); var csy0 = g.csy(g.by[0]);
        var flash = (_tick % 6 < 3);
        var lineClr = flash ? 0xEEEEEE : 0xAAAAAA;

        if (g.aimHitBall >= 0) {
            // Cue → ghost-ball line
            var ghostCx = g.bx[0] + dirx * g.aimHitT;
            var ghostCy = g.by[0] + diry * g.aimHitT;
            var hitSx = g.csx(ghostCx);
            var hitSy = g.csy(ghostCy);
            dc.setColor(lineClr, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(csx0, csy0, hitSx, hitSy);

            // Ghost ball outline at contact point
            var ghR = g.csr(BALL_R); if (ghR < 4) { ghR = 4; }
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(hitSx, hitSy, ghR);

            // Line-of-centres unit vector ghost → target
            var tdx = g.bx[g.aimHitBall] - ghostCx;
            var tdy = g.by[g.aimHitBall] - ghostCy;
            var td2 = tdx*tdx + tdy*tdy;
            if (td2 > 0.01) {
                var td = Math.sqrt(td2);
                var nx = tdx / td; var ny = tdy / td;

                // Cosine of the cut angle (1=full hit, 0=90° cut).
                var cosCut = dirx * nx + diry * ny;
                if (cosCut < 0.0) { cosCut = 0.0; }

                // Target trajectory — length proportional to the
                // normal velocity transferred to the target (cosCut).
                // Full hit ⇒ long line; thin cut ⇒ short stub.
                var tLen = 60.0 + 280.0 * cosCut;
                var teCx = g.bx[g.aimHitBall] + nx * tLen;
                var teCy = g.by[g.aimHitBall] + ny * tLen;
                dc.setColor(g.bCol[g.aimHitBall], Graphics.COLOR_TRANSPARENT);
                dc.drawLine(g.csx(g.bx[g.aimHitBall]), g.csy(g.by[g.aimHitBall]),
                            g.csx(teCx), g.csy(teCy));

                // Cue deflection — perpendicular to (nx, ny).
                // Use vector subtraction so the perpendicular has the
                // correct sign automatically.
                var perpX = dirx - cosCut * nx;
                var perpY = diry - cosCut * ny;
                var perpL = Math.sqrt(perpX*perpX + perpY*perpY);
                if (perpL > 0.05) {
                    var pnx = perpX / perpL;
                    var pny = perpY / perpL;
                    var cLen = 40.0 + 220.0 * perpL;
                    var ceCx = ghostCx + pnx * cLen;
                    var ceCy = ghostCy + pny * cLen;
                    dc.setColor(0x88BBFF, Graphics.COLOR_TRANSPARENT);
                    dc.drawLine(hitSx, hitSy,
                                g.csx(ceCx), g.csy(ceCy));
                }
            }
        } else {
            // Straight aim line into empty space (clip to ~table width)
            var lineLen = g.csr(680);
            dc.setColor(lineClr, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(csx0, csy0,
                        csx0 + (dirx * lineLen).toNumber(),
                        csy0 + (diry * lineLen).toNumber());
        }
    }

    // ── POWER BAR ─────────────────────────────────────────────
    // Drawn at the bottom of the screen.  Width was 75% of screen and
    // crept off the visible round face on small Garmin watches —
    // narrowed by 40% (75 → 45) per user request so the entire bar
    // sits comfortably inside the round face.  Also lifted up from
    // the bottom edge (was 4% margin, now 9%) so the curved chrome
    // doesn't clip the bottom row of pixels.
    hidden function _drawPowerBar(dc, g) {
        var w = g.sw; var h = g.sh;
        var bw = w * 45 / 100;
        var bh = h * 8  / 100; if (bh < 9) { bh = 9; }
        var bx = (w - bw) / 2;
        var by = h - bh - h * 9 / 100;
        // Drop shadow for contrast against table felt
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx-2, by-2, bw+4, bh+4, 4);
        // Background track
        dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx-1, by-1, bw+2, bh+2, 3);
        // Fill colour: green → amber → red
        var filled = bw * g.power / 100;
        var clr = (g.power < 50) ? 0x44DD44 : (g.power < 80 ? 0xFFCC00 : 0xFF3311);
        dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, filled, bh, 2);
        // Power % label inside bar
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bx + bw/2, by + bh/2 - 8, Graphics.FONT_XTINY,
                    "PWR " + g.power.format("%d") + "%",
                    Graphics.TEXT_JUSTIFY_CENTER);
        // Border
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 2);
        // Label
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, by - h*5/100, Graphics.FONT_XTINY, "O=shoot", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── AI THINKING OVERLAY ───────────────────────────────────
    hidden function _drawAiThinking(dc, g) {
        var dots = "";
        var n = (_tick / 5) % 4;
        for (var d = 0; d < n; d++) { dots = dots + "."; }
        dc.setColor(0x6699BB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(g.sw/2, g.sh - g.sh*11/100,
                    Graphics.FONT_XTINY, "AI thinking" + dots,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── HUD ───────────────────────────────────────────────────
    hidden function _drawHUD(dc, g) {
        var w = g.sw; var h = g.sh;
        // TIME ATTACK — bespoke solo HUD: score on the left, big countdown
        // on the right (flashes red under 10s), mode label centred.
        if (g.gameType == GT_TIMEATTACK) {
            dc.setColor(0x050D05, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w, g.vpY);
            dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(4, 1, Graphics.FONT_XTINY, "SCORE:" + g.playerScore,
                        Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, 1, Graphics.FONT_XTINY, "TIME ATTACK",
                        Graphics.TEXT_JUSTIFY_CENTER);
            var secsLeft = (g.arcadeTicks + 29) / 30; if (secsLeft < 0) { secsLeft = 0; }
            var urgent = (secsLeft <= 10) && (_tick % 10 < 5);
            dc.setColor(urgent ? 0xFF4444 : 0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w-4, 1, Graphics.FONT_XTINY, secsLeft + "s",
                        Graphics.TEXT_JUSTIFY_RIGHT);
            if (g.gs == BS_AIM) {
                dc.setColor(0xCCDDAA, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w/2, h - h*15/100, Graphics.FONT_XTINY, "pot ANY ball!",
                            Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(0x3D7755, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w/2, h - h*9/100, Graphics.FONT_XTINY,
                            "UP/DN=aim  O=charge",
                            Graphics.TEXT_JUSTIFY_CENTER);
            }
            return;
        }
        var pvp = g.pvpMode;
        var p1Label = pvp ? "P1" : "YOU";
        var p2Label = pvp ? "P2" : "AI";
        var p1Clr   = 0x44CCFF;
        var p2Clr   = pvp ? 0xFFCC44 : 0xFF8844;
        // HUD strip background
        dc.setColor(0x050D05, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, g.vpY);
        // Player score (8-ball: show group, else: count of balls)
        dc.setColor(p1Clr, Graphics.COLOR_TRANSPARENT);
        var pLabel = p1Label + ":" + g.playerScore;
        if (g.gameType == GT_8BALL && g.playerGroup[0] != 0) {
            pLabel = p1Label + " " + (g.playerGroup[0] == 1 ? "SOL" : "STR") + ":" + g.playerScore;
        }
        dc.drawText(4, 1, Graphics.FONT_XTINY, pLabel, Graphics.TEXT_JUSTIFY_LEFT);
        // Turn / status + rules hint
        var turnStr; var tClr;
        if (g.gs == BS_ROLLING) {
            turnStr = "ROLLING..."; tClr = 0xBBBBBB;
        } else if (g.turn == TURN_PLAYER) {
            turnStr = pvp ? "P1 TURN" : "YOUR TURN"; tClr = 0x44FF88;
        } else {
            turnStr = pvp ? "P2 TURN" : "AI TURN"; tClr = pvp ? 0xFFCC44 : 0xFF8844;
        }
        dc.setColor(tClr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, 1, Graphics.FONT_XTINY, turnStr, Graphics.TEXT_JUSTIFY_CENTER);
        // Opponent score (mirror of player label)
        dc.setColor(p2Clr, Graphics.COLOR_TRANSPARENT);
        var aLabel = p2Label + ":" + g.aiScore;
        if (g.gameType == GT_8BALL && g.playerGroup[1] != 0) {
            aLabel = p2Label + " " + (g.playerGroup[1] == 1 ? "SOL" : "STR") + ":" + g.aiScore;
        }
        dc.drawText(w-4, 1, Graphics.FONT_XTINY, aLabel, Graphics.TEXT_JUSTIFY_RIGHT);

        // Rules hint above the bottom edge (e.g., "hit ball 3" in 9-ball)
        if (g.gs == BS_AIM && g.turn == TURN_PLAYER) {
            var hint = null;
            if (g.gameType == GT_9BALL) {
                var low = -1;
                for (var b = 1; b < g.numBalls; b++) {
                    if (g.bAlive[b]) { low = b; break; }
                }
                if (low > 0) { hint = "hit " + low + " first"; }
            } else if (g.gameType == GT_8BALL) {
                var pg = g.playerGroup[0];
                if (pg == 1)      { hint = "pot SOLIDS (1-7)"; }
                else if (pg == 2) { hint = "pot STRIPES (9-15)"; }
                else              { hint = "open table - any group"; }
            } else if (g.gameType == GT_SNOOKER) {
                var anyRed = false;
                for (var b2 = 1; b2 <= 6; b2++) {
                    if (g.bAlive[b2]) { anyRed = true; break; }
                }
                hint = anyRed ? "hit RED first" : "pot BLACK to win";
            }
            if (hint != null) {
                dc.setColor(0xCCDDAA, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w/2, h - h*15/100, Graphics.FONT_XTINY, hint,
                            Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.setColor(0x3D7755, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h - h*9/100, Graphics.FONT_XTINY,
                        "UP/DN=aim  O=charge",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        // P2 turn hint in PvP when it's P2's turn
        if (pvp && g.gs == BS_AIM && g.turn == TURN_AI) {
            var hint2 = null;
            if (g.gameType == GT_9BALL) {
                var low2 = -1;
                for (var b3 = 1; b3 < g.numBalls; b3++) {
                    if (g.bAlive[b3]) { low2 = b3; break; }
                }
                if (low2 > 0) { hint2 = "hit " + low2 + " first"; }
            } else if (g.gameType == GT_8BALL) {
                var pg2 = g.playerGroup[1];
                if (pg2 == 1)      { hint2 = "pot SOLIDS (1-7)"; }
                else if (pg2 == 2) { hint2 = "pot STRIPES (9-15)"; }
                else               { hint2 = "open table - any group"; }
            } else if (g.gameType == GT_SNOOKER) {
                var anyRed2 = false;
                for (var b4 = 1; b4 <= 6; b4++) {
                    if (g.bAlive[b4]) { anyRed2 = true; break; }
                }
                hint2 = anyRed2 ? "hit RED first" : "pot BLACK to win";
            }
            if (hint2 != null) {
                dc.setColor(0xCCDDAA, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w/2, h - h*15/100, Graphics.FONT_XTINY, hint2,
                            Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.setColor(0x3D7755, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h - h*9/100, Graphics.FONT_XTINY,
                        "UP/DN=aim  O=charge",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── FLOATING MESSAGE ──────────────────────────────────────
    hidden function _drawMessage(dc, g) {
        dc.setColor(0xFFFF55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(g.sw/2, g.sh * 44 / 100,
                    Graphics.FONT_XTINY, g.msg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── GAME OVER ─────────────────────────────────────────────
    hidden function _drawGameOver(dc, g) {
        var w = g.sw; var h = g.sh;
        dc.setColor(0x030A03, 0x030A03); dc.clear();
        dc.setColor(0x0C3012, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h);

        // TIME ATTACK gets its own compact solo results screen — no
        // opponent to compare against, just the final score.
        if (g.gameType == GT_TIMEATTACK) {
            var taTitle = (g.winReason == 6) ? "TABLE CLEARED!" : "TIME'S UP!";
            var taClr   = (g.winReason == 6) ? 0x44FF88 : 0xFFCC44;
            dc.setColor(taClr, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h*14/100, Graphics.FONT_MEDIUM, taTitle, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h*34/100, Graphics.FONT_NUMBER_MEDIUM, g.playerScore.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x778877, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h*52/100, Graphics.FONT_XTINY,
                        "balls potted - " + g.timeAttackLimitSecs() + "s clock",
                        Graphics.TEXT_JUSTIFY_CENTER);
            var taBright = (_tick % 14 < 7);
            dc.setColor(taBright ? 0x44FF88 : 0x226633, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h*76/100, Graphics.FONT_XTINY, "Tap for menu",
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Winner from winReason (set by rules engine); fallback to score.
        var winner; var wClr; var sub = null;
        var pvp = g.pvpMode;
        if (g.winReason == 1) {
            winner = pvp ? "P1 WINS!" : "YOU WIN!"; wClr = 0x44FF88;
        } else if (g.winReason == 2) {
            winner = pvp ? "P2 WINS!" : "AI WINS!"; wClr = pvp ? 0xFFCC44 : 0xFF4444;
        } else if (g.winReason == 3) {
            winner = pvp ? "P1 WINS!" : "YOU WIN!"; wClr = 0x44FF88;
            sub = pvp ? "P2 fouled on 8-ball" : "AI fouled on 8-ball";
        } else if (g.winReason == 4) {
            winner = pvp ? "P2 WINS!" : "AI WINS!"; wClr = pvp ? 0xFFCC44 : 0xFF4444;
            sub = pvp ? "P1 fouled on 8-ball" : "You fouled on 8-ball";
        } else if (g.playerScore > g.aiScore) {
            winner = pvp ? "P1 WINS!" : "YOU WIN!"; wClr = 0x44FF88;
        } else if (g.aiScore > g.playerScore) {
            winner = pvp ? "P2 WINS!" : "AI WINS!"; wClr = pvp ? 0xFFCC44 : 0xFF4444;
        } else {
            winner = "DRAW!"; wClr = 0xFFCC44;
        }

        dc.setColor(wClr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*12/100, Graphics.FONT_MEDIUM, winner, Graphics.TEXT_JUSTIFY_CENTER);
        if (sub != null) {
            dc.setColor(0xCCBBAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h*24/100, Graphics.FONT_XTINY, sub, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Score boxes — "pts" for snooker, "balls" for the rest.
        var unit   = (g.gameType == GT_SNOOKER) ? "pts" : ("ball" + (g.playerScore == 1 ? "" : "s"));
        var aiUnit = (g.gameType == GT_SNOOKER) ? "pts" : ("ball" + (g.aiScore == 1 ? "" : "s"));
        var p1Lbl  = pvp ? "P1" : "YOU";
        var p2Lbl  = pvp ? "P2" : "AI";
        var p2Clr  = pvp ? 0xFFCC44 : 0xFF8844;
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*32/100, Graphics.FONT_XTINY,
                    p1Lbl + ":  " + g.playerScore + " " + unit,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(p2Clr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*44/100, Graphics.FONT_XTINY,
                    p2Lbl + ":  " + g.aiScore   + " " + aiUnit,
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Mode + difficulty reminder
        var dLabels = ["EASY", "MEDIUM", "HARD"];
        dc.setColor(0x778877, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*58/100, Graphics.FONT_XTINY,
                    g.gameTypeLabel() + " - " + dLabels[g.diff], Graphics.TEXT_JUSTIFY_CENTER);

        // Blinking tap to return
        var bright = (_tick % 14 < 7);
        dc.setColor(bright ? 0x44FF88 : 0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*76/100, Graphics.FONT_XTINY, "Tap for menu",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
