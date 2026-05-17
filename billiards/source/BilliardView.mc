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
        WatchUi.requestUpdate();
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
        if (g.gs == BS_AI_WAIT) { _drawAiThinking(dc, g); }
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
        // Mini table decoration
        var tx1 = w*14/100; var tx2 = w*86/100;
        var ty1 = h*28/100; var ty2 = h*55/100;
        dc.setColor(0x5C3010, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx1-4, ty1-4, tx2-tx1+8, ty2-ty1+8);
        dc.setColor(0x0F5020, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx1, ty1, tx2-tx1, ty2-ty1);
        // Pocket dots
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx1, ty1, 4); dc.fillCircle(tx2, ty1, 4);
        dc.fillCircle(tx1, ty2, 4); dc.fillCircle(tx2, ty2, 4);
        dc.fillCircle((tx1+tx2)/2, ty1, 4); dc.fillCircle((tx1+tx2)/2, ty2, 4);
        // Decorative balls — show all 9 colours including black
        var bColors = [0xFFFFFF, 0xFFDD00, 0x2255DD, 0xDD2222,
                       0x882299, 0xFF7700, 0x228833, 0xAA2200, 0x44AACC, 0x111111];
        var bpx = [w*18/100, w*28/100, w*38/100, w*48/100, w*58/100,
                   w*68/100, w*78/100, w*23/100, w*45/100, w*70/100];
        var bpy = [h*42/100, h*37/100, h*44/100, h*38/100, h*43/100,
                   h*38/100, h*43/100, h*48/100, h*49/100, h*48/100];
        for (var i = 0; i < 10; i++) {
            dc.setColor(bColors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bpx[i], bpy[i], 7);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bpx[i]-2, bpy[i]-2, 2);
        }
        // Title
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*8/100, Graphics.FONT_MEDIUM, "BILLIARDS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x44CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*20/100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);
        // Difficulty
        var dLabels = ["EASY", "MEDIUM", "HARD"];
        var dColors = [0x44CC44, 0xFFAA00, 0xEE3322];
        dc.setColor(0xAABBAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*59/100, Graphics.FONT_XTINY, "Difficulty", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(dColors[g.diff], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*67/100, Graphics.FONT_XTINY, dLabels[g.diff], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x668866, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*75/100, Graphics.FONT_XTINY, "UP/DN change", Graphics.TEXT_JUSTIFY_CENTER);
        // Blinking tap-to-play
        var bright = (_tick % 14 < 7);
        dc.setColor(bright ? 0x44FF88 : 0x228844, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*85/100, Graphics.FONT_XTINY, "TAP TO PLAY", Graphics.TEXT_JUSTIFY_CENTER);
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
        for (var i = 0; i < MAX_BALLS; i++) {
            if (!g.bAlive[i]) { continue; }
            var bsx = g.csx(g.bx[i]); var bsy = g.csy(g.by[i]);
            // Drop shadow
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bsx+1, bsy+1, br);
            // Ball body
            dc.setColor(g.bCol[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bsx, bsy, br);
            // Gloss highlight
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bsx - br*2/5, bsy - br*2/5, br/4 + 1);
            // Cue-ball rim
            if (i == 0) {
                dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(bsx, bsy, br);
            }
        }
    }

    // ── AIM LINE + GHOST-BALL PREVIEW ─────────────────────────
    hidden function _drawAimLine(dc, g) {
        var rad = g.aimAngle * Math.PI / 180.0;
        var dirx = Math.cos(rad); var diry = Math.sin(rad);
        var csx0 = g.csx(g.bx[0]); var csy0 = g.csy(g.by[0]);
        var flash = (_tick % 6 < 3);
        var lineClr = flash ? 0xEEEEEE : 0xAAAAAA;

        if (g.aimHitBall >= 0) {
            // Line from cue ball to contact point
            var hitSx = g.csx(g.bx[0] + dirx * g.aimHitT);
            var hitSy = g.csy(g.by[0] + diry * g.aimHitT);
            dc.setColor(lineClr, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(csx0, csy0, hitSx, hitSy);

            // Ghost ball outline at contact point
            var ghR = g.csr(BALL_R); if (ghR < 4) { ghR = 4; }
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(hitSx, hitSy, ghR);

            // Target ball trajectory preview
            var tbSx = g.csx(g.bx[g.aimHitBall]);
            var tbSy = g.csy(g.by[g.aimHitBall]);
            var predLen = g.csr(280);
            dc.setColor(g.bCol[g.aimHitBall], Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tbSx, tbSy,
                        tbSx + (dirx * predLen).toNumber(),
                        tbSy + (diry * predLen).toNumber());
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
    hidden function _drawPowerBar(dc, g) {
        var w = g.sw; var h = g.sh;
        var bw = w * 68 / 100;
        var bh = h * 5  / 100; if (bh < 6) { bh = 6; }
        var bx = (w - bw) / 2;
        var by = h - bh - h * 5 / 100;
        // Background track
        dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx-1, by-1, bw+2, bh+2, 3);
        // Fill colour: green → amber → red
        var filled = bw * g.power / 100;
        var clr = (g.power < 50) ? 0x44DD44 : (g.power < 80 ? 0xFFCC00 : 0xFF3311);
        dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, filled, bh, 2);
        // Border
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
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
        // HUD strip background
        dc.setColor(0x050D05, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, g.vpY);
        // Player score
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 1, Graphics.FONT_XTINY, "YOU:" + g.playerScore, Graphics.TEXT_JUSTIFY_LEFT);
        // Turn / status
        var turnStr; var tClr;
        if (g.gs == BS_ROLLING) {
            turnStr = "ROLLING..."; tClr = 0xBBBBBB;
        } else if (g.turn == TURN_PLAYER) {
            turnStr = "YOUR TURN"; tClr = 0x44FF88;
        } else {
            turnStr = "AI TURN"; tClr = 0xFF8844;
        }
        dc.setColor(tClr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, 1, Graphics.FONT_XTINY, turnStr, Graphics.TEXT_JUSTIFY_CENTER);
        // AI score
        dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w-4, 1, Graphics.FONT_XTINY, "AI:" + g.aiScore, Graphics.TEXT_JUSTIFY_RIGHT);
        // Bottom hint (only when player is aiming, not obstructed by power bar)
        if (g.gs == BS_AIM && g.turn == TURN_PLAYER) {
            dc.setColor(0x3D7755, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w/2, h - h*9/100, Graphics.FONT_XTINY,
                        "MENU/DN=aim  O=charge  tap=aim",
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

        var winner; var wClr;
        if      (g.playerScore > g.aiScore) { winner = "YOU WIN!"; wClr = 0x44FF88; }
        else if (g.aiScore > g.playerScore) { winner = "AI WINS!"; wClr = 0xFF4444; }
        else                                { winner = "DRAW!";    wClr = 0xFFCC44; }

        dc.setColor(wClr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*12/100, Graphics.FONT_MEDIUM, winner, Graphics.TEXT_JUSTIFY_CENTER);

        // Score boxes
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*32/100, Graphics.FONT_XTINY,
                    "YOU:  " + g.playerScore + " ball" + (g.playerScore == 1 ? "" : "s"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*44/100, Graphics.FONT_XTINY,
                    "AI:   " + g.aiScore   + " ball" + (g.aiScore   == 1 ? "" : "s"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Difficulty reminder
        var dLabels = ["EASY", "MEDIUM", "HARD"];
        dc.setColor(0x778877, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*58/100, Graphics.FONT_XTINY,
                    "Difficulty: " + dLabels[g.diff], Graphics.TEXT_JUSTIFY_CENTER);

        // Blinking tap to return
        var bright = (_tick % 14 < 7);
        dc.setColor(bright ? 0x44FF88 : 0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h*76/100, Graphics.FONT_XTINY, "Tap for menu",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
