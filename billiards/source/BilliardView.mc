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

    function initialize() {
        View.initialize();
        _game = new BilliardGame();
        _tick = 0;
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 33, true);
    }

    function onLayout(dc) {
        _game.setScreenSize(dc.getWidth(), dc.getHeight());
    }

    function onTick() as Void {
        _tick++;
        _game.step();
        if (_game.gs == BS_GAMEOVER) { _game.reportResult(); }
        if (_game.lbRequested) {
            _game.lbRequested = false;
            openLeaderboard();
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
        _drawTable(dc, g);
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
    hidden function _drawMenu(dc, g) {
        var w = g.sw; var h = g.sh;
        dc.setColor(0x0A1A0A, 0x0A1A0A); dc.clear();
        // Felt background
        dc.setColor(0x0C3010, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h);
        // Mini table — compact so the five rows below have breathing room
        var tx1 = w*20/100; var tx2 = w*80/100;
        var ty1 = h*19/100; var ty2 = h*29/100;
        dc.setColor(0x5C3010, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx1-3, ty1-3, tx2-tx1+6, ty2-ty1+6);
        dc.setColor(0x0F5020, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx1, ty1, tx2-tx1, ty2-ty1);
        // Pocket dots
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx1, ty1, 3); dc.fillCircle(tx2, ty1, 3);
        dc.fillCircle(tx1, ty2, 3); dc.fillCircle(tx2, ty2, 3);
        dc.fillCircle((tx1+tx2)/2, ty1, 3); dc.fillCircle((tx1+tx2)/2, ty2, 3);
        // Decorative balls
        _drawMenuRack(dc, g, tx1, ty1, tx2, ty2);
        // Title + subtitle
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*7/100, Graphics.FONT_SMALL, "BILLIARDS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x44CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*14/100, Graphics.FONT_XTINY, "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Row positions — evenly spaced so nothing overlaps (5 rows + rules hint).
        // Row 0 spans two lines (label + rules hint), so row 1 starts after both.
        var r0y  = h*34/100;   // GAME MODE label
        var r0s  = h*40/100;   // rules hint (smaller, dimmer)
        var r1y  = h*48/100;   // VS MODE
        var r2y  = h*56/100;   // DIFFICULTY
        var rLBy = h*65/100;   // LEADERBOARD
        var r3y  = h*75/100;   // START
        var dLabels = ["EASY", "MEDIUM", "HARD"];
        var dColors = [0x44CC44, 0xFFAA00, 0xEE3322];

        // Row 0 — GAME MODE
        var sel0 = (g.menuSel == 0);
        dc.setColor(sel0 ? 0xFFFFFF : 0x88AABB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, r0y, Graphics.FONT_XTINY,
                    (sel0 ? "> " : "  ") + g.gameTypeLabel() + (sel0 ? " <" : "  "),
                    Graphics.TEXT_JUSTIFY_CENTER);
        var rules = (g.gameType == GT_3BALL)   ? "race - 3 balls"
                  : (g.gameType == GT_8BALL)   ? "groups - pot 8 to win"
                  : (g.gameType == GT_SNOOKER) ? "reds 1pt - black 7pt"
                                               : "lowest first - pot 9 wins";
        dc.setColor(0x567856, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, r0s, Graphics.FONT_XTINY, rules, Graphics.TEXT_JUSTIFY_CENTER);

        // Row 1 — VS MODE
        var sel1 = (g.menuSel == 1);
        var vsLabel = g.pvpMode ? "P vs P" : "P vs AI";
        dc.setColor(sel1 ? 0xFFFFFF : 0x88AABB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, r1y, Graphics.FONT_XTINY,
                    (sel1 ? "> " : "  ") + vsLabel + (sel1 ? " <" : "  "),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Row 2 — DIFFICULTY (dimmed/dashed when P vs P — AI is unused)
        var sel2 = (g.menuSel == 2);
        if (g.pvpMode) {
            dc.setColor(0x384838, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, r2y, Graphics.FONT_XTINY, "  Diff: —  ",
                        Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(sel2 ? 0xFFFFFF : 0x88AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2 - 2, r2y, Graphics.FONT_XTINY,
                        (sel2 ? "> " : "  ") + "Diff: ", Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(dColors[g.diff], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2 - 2, r2y, Graphics.FONT_XTINY,
                        dLabels[g.diff] + (sel2 ? " <" : "  "), Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Row 3 — LEADERBOARD (gold, slightly standout to drive hype).
        // Greyed + "N/A" on watches that can't make web requests.
        var sel3 = (g.menuSel == 3);
        if (Leaderboard.isSupported()) {
            dc.setColor(sel3 ? 0xFFD24A : 0xBB8A1A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, rLBy, Graphics.FONT_XTINY,
                        (sel3 ? "> LEADERBOARD <" : "  LEADERBOARD  "),
                        Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, rLBy, Graphics.FONT_XTINY,
                        (sel3 ? "> LEADERBOARD N/A <" : "  LEADERBOARD N/A  "),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Row 4 — START (blinking when focused)
        var sel4  = (g.menuSel == 4);
        var bright = (_tick % 14 < 7);
        var startClr = sel4 ? (bright ? 0x44FF88 : 0xFFFFFF) : 0x228855;
        dc.setColor(startClr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, r3y, Graphics.FONT_XTINY,
                    (sel4 ? "> START <" : "  START  "),
                    Graphics.TEXT_JUSTIFY_CENTER);
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
        } else if (g.gameType == GT_8BALL) {
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

    // ── BALLS ─────────────────────────────────────────────────
    hidden function _drawBalls(dc, g) {
        var br = g.csr(BALL_R); if (br < 4) { br = 4; }
        for (var i = 0; i < g.numBalls; i++) {
            if (!g.bAlive[i]) { continue; }
            var bsx = g.csx(g.bx[i]); var bsy = g.csy(g.by[i]);
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
