// ═══════════════════════════════════════════════════════════════
// MainView.mc — Render loop, layout, input dispatch.
//
// 25 ms tick (~40 Hz) keeps motion smooth without overrunning the
// watchdog: each tick is ~10-20 light arithmetic ops + 4 small fills.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

const TICK_MS = 25;

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _timer;
    hidden var _laidOut;
    hidden var _menuSel;     // 0 = difficulty, 1 = start

    function initialize() {
        View.initialize();
        _ctrl    = new GameController();
        _timer   = null;
        _laidOut = false;
        _menuSel = 0;
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
        // Pure black background — classic Pong feel.
        dc.setColor(0x000000, 0x000000); dc.clear();

        if (_ctrl.state == GS_MENU) { _drawMenu(dc); return; }

        _drawCourt(dc);
        if (_ctrl.state == GS_PLAY) { _ctrl.powerUp.draw(dc); }
        _ctrl.pPlayer.draw(dc);
        _ctrl.pCpu.draw(dc);
        if (_ctrl.state != GS_SERVE) {
            _ctrl.ball.draw(dc);
            if (_ctrl.ball2Active) { _ctrl.ball2.draw(dc); }
        } else {
            _drawServeCountdown(dc);
        }
        _drawHUD(dc);
        _drawPowerUpFlash(dc);

        if (_ctrl.state == GS_OVER) { _drawOver(dc); }
    }

    // Big banner + colour flash across the whole court when a power-up
    // fires, so it's unmissable no matter which paddle triggered it.
    hidden function _drawPowerUpFlash(dc) {
        if (_ctrl.puFlashT <= 0) { return; }
        var col;
        if      (_ctrl.puFlashKind == PU_MULTIBALL) { col = 0x33CCFF; }
        else if (_ctrl.puFlashKind == PU_GROW)      { col = 0x44FF66; }
        else                                          { col = 0xFF4444; }
        // Fades out over the last third of the flash window.
        if (_ctrl.puFlashT < 18 && (_ctrl.puFlashT % 6) < 3) { return; }
        dc.setPenWidth(2);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_ctrl.playX0 - 3, _ctrl.playY0 - 3,
                                (_ctrl.playX1 - _ctrl.playX0) + 6,
                                (_ctrl.playY1 - _ctrl.playY0) + 6, 6);
        dc.setPenWidth(1);
        var cx = (_ctrl.playX0 + _ctrl.playX1) / 2;
        dc.drawText(cx, _ctrl.playY0 + 6, Graphics.FONT_XTINY,
                    _ctrl.powerUpLabel(_ctrl.puFlashKind), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Court / centre line ─────────────────────────────────────────
    hidden function _drawCourt(dc) {
        // Centre dashed line
        dc.setColor(0x303040, Graphics.COLOR_TRANSPARENT);
        var cx   = (_ctrl.playX0 + _ctrl.playX1) / 2;
        var step = 8;
        var y    = _ctrl.playY0 + 2;
        while (y < _ctrl.playY1 - 2) {
            dc.fillRectangle(cx - 1, y, 2, 4);
            y = y + step;
        }
        // Subtle frame around playfield
        dc.setColor(0x101820, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_ctrl.playX0 - 1, _ctrl.playY0 - 1,
                         (_ctrl.playX1 - _ctrl.playX0) + 2,
                         (_ctrl.playY1 - _ctrl.playY0) + 2);
    }

    // ── Serve countdown (3..2..1) ───────────────────────────────────
    hidden function _drawServeCountdown(dc) {
        var rem = _ctrl.serveCounter / 8;
        if (rem < 0) { rem = 0; }
        if (rem > 3) { rem = 3; }
        var s = (rem == 0) ? "GO" : (rem + 1).format("%d");
        var cx = (_ctrl.playX0 + _ctrl.playX1) / 2;
        var cy = (_ctrl.playY0 + _ctrl.playY1) / 2 - 12;
        dc.setColor(0x00EEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_MEDIUM,
                    s, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── HUD ─────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var W = _ctrl.screenW;
        // Score row at top — large digits
        var midX = W / 2;
        var top  = (_ctrl.screenH * 3) / 100;
        if (top < 3) { top = 3; }

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(midX - 18, top, Graphics.FONT_MEDIUM,
                    _ctrl.scoreP.format("%02d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(0x666688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(midX, top, Graphics.FONT_MEDIUM,
                    ":", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF44AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(midX + 18, top, Graphics.FONT_MEDIUM,
                    _ctrl.scoreCpu.format("%02d"),
                    Graphics.TEXT_JUSTIFY_LEFT);

        // Difficulty badge bottom-centre (+ tilt marker when steering)
        dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
        var diffLabel = _diffLabel(_ctrl.difficulty);
        if (_ctrl.tiltEnabled) { diffLabel = diffLabel + " \u00B7 TILT"; }
        dc.drawText(midX, _ctrl.screenH - 16, Graphics.FONT_XTINY,
                    diffLabel, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _diffLabel(d) {
        if (d == DIFF_EASY)   { return "EASY"; }
        if (d == DIFF_MEDIUM) { return "MED";  }
        return "HARD";
    }

    // ── Menu ────────────────────────────────────────────────────────
    // Chess-style two-row menu: Difficulty (cycle) + START. UP/DN
    // navigate rows, SELECT activates focussed row.
    hidden function _drawMenu(dc) {
        var cx = _ctrl.screenW / 2;
        var W  = _ctrl.screenW;
        var H  = _ctrl.screenH;

        dc.setColor(0x080808, 0x080808); dc.clear();
        if (W == H) {
            dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, H / 2, W / 2 - 1);
        }

        // Title + Bitochi attribution
        dc.setColor(0x00EEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 12 / 100, Graphics.FONT_SMALL,
                    "PONG", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF44AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 22 / 100, Graphics.FONT_SMALL,
                    "PRO", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 32 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Mini animated demo
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 36, H * 43 / 100, 3, 12);
        dc.setColor(0xFF44AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx + 33, H * 46 / 100, 3, 12);
        dc.setColor(0x00EEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 2, H * 47 / 100, 4, 4);

        // Chess-style rows: Difficulty + Tilt + START + LEADERBOARD.
        var diffNames = ["EASY", "MED", "HARD"];
        var labels = [
            "Diff: " + diffNames[_ctrl.difficulty],
            "Tilt: " + _ctrl.tiltLabel(),
            "START",
            ""
        ];
        var rg   = menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < MI_ITEMS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            var sel = (i == _ctrl.menuRow);

            if (i == MI_LEADERBOARD) {
                // Hype-y gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == MI_START);
            dc.setColor(sel ? (isStart ? 0x1A4400 : 0x1A3A6A) : 0x111820,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x44BB22 : 0x55AAFF) : 0x2A3A4A,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                dc.setColor(isStart ? 0x44BB22 : 0x55AAFF,
                            Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xAAFF66 : 0xCCEEFF) : 0x778899,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Wins counter
        if (_ctrl.hiPlayerWins > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 90 / 100, Graphics.FONT_XTINY,
                        "WINS " + _ctrl.hiPlayerWins.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Geometry for the chess-style menu. Space-aware: the row height
    // shrinks to whatever fits between the demo zone and the bottom
    // margin (which reserves room for the WINS line), so the third
    // (LEADERBOARD) row never overlaps anything on small round watches.
    // Overall ~18% smaller than the old two-row layout.
    //   [ rowH, rowW, rowX, rowY0, gap ]
    function menuRowGeom() {
        var W = _ctrl.screenW;
        var H = _ctrl.screenH;
        var topZone      = (H * 52) / 100;            // rows live below the demo
        var bottomMargin = (H * 15) / 100; if (bottomMargin < 16) { bottomMargin = 16; }
        var gap          = (H * 2)  / 100; if (gap < 3) { gap = 3; }
        var avail        = (H - bottomMargin) - topZone;
        var rowH         = (avail - gap * (MI_ITEMS - 1)) / MI_ITEMS;
        // ~10% smaller than the previous band.
        if (rowH > 25) { rowH = 25; }
        if (rowH < 14) { rowH = 14; }
        var rowW = (W * 58) / 100; if (rowW < 104) { rowW = 104; }
        var rowX = (W - rowW) / 2;
        var used  = MI_ITEMS * rowH + (MI_ITEMS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // Open the shared global leaderboard for the current AI difficulty.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _ctrl.diffName(), "PONG PRO");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // ── Game over ───────────────────────────────────────────────────
    hidden function _drawOver(dc) {
        var bw = _ctrl.screenW * 70 / 100; if (bw < 160) { bw = 160; }
        var bh = _ctrl.screenH * 40 / 100; if (bh < 120) { bh = 120; }
        var bx = (_ctrl.screenW - bw) / 2;
        var by = (_ctrl.screenH - bh) / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        var playerWon = _ctrl.scoreP > _ctrl.scoreCpu;
        dc.setColor(playerWon ? 0x00FF88 : 0xFF44AA, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        var cx = _ctrl.screenW / 2;
        dc.setColor(playerWon ? 0x00FF88 : 0xFF44AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    playerWon ? "YOU WIN!" : "CPU WINS",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 36, Graphics.FONT_MEDIUM,
                    _ctrl.scoreP.format("%d") + " - " + _ctrl.scoreCpu.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Input intents ───────────────────────────────────────────────
    function holdUp(b)        { _ctrl.setHoldUp(b);    }
    function holdDown(b)      { _ctrl.setHoldDown(b);  }
    function impulse(dir)     { _ctrl.impulse(dir);    }

    // ── State queries (used by InputHandler) ────────────────────────
    function isMenu()    { return _ctrl.state == GS_MENU; }
    function isOver()    { return _ctrl.state == GS_OVER; }
    function isInMatch() {
        return _ctrl.state == GS_PLAY || _ctrl.state == GS_SERVE;
    }

    // ── Menu actions ────────────────────────────────────────────────
    // UP/DOWN navigate the two rows. SELECT activates the focussed
    // row — on DIFFICULTY it cycles the value, on START it begins.
    function menuPrev() {
        _ctrl.menuRow = (_ctrl.menuRow + MI_ITEMS - 1) % MI_ITEMS;
    }
    function menuNext() {
        _ctrl.menuRow = (_ctrl.menuRow + 1) % MI_ITEMS;
    }
    function menuStart() {
        if (_ctrl.menuRow == MI_DIFFICULTY) {
            _ctrl.cycleDifficulty();
            return;
        }
        if (_ctrl.menuRow == MI_TILT) {
            _ctrl.toggleTilt();
            return;
        }
        if (_ctrl.menuRow == MI_LEADERBOARD) {
            openLeaderboard();
            return;
        }
        _ctrl.startMatch();
    }
    function gotoMenu()  { _ctrl.gotoMenu();   }

    function confirmOrCycle() {
        if (_ctrl.state == GS_MENU) {
            menuStart();
            return;
        }
        _ctrl.confirm();
    }

    function handleTap(x, y) {
        if (_ctrl.state == GS_MENU) {
            // Tap on a chess-style row → focus + activate it.
            var rg = menuRowGeom();
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < MI_ITEMS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW
                 && y >= ry   && y < ry + rowH) {
                    _ctrl.menuRow = i;
                    menuStart();
                    return;
                }
            }
            return;
        }
        if (_ctrl.state == GS_OVER) { _ctrl.gotoMenu(); return; }
        // Live play — tap upper/lower half nudges paddle
        var mid = (_ctrl.playY0 + _ctrl.playY1) / 2;
        var dir = (y < mid) ? -1 : 1;
        _ctrl.impulse(dir);
    }

    function handleBack() {
        if (_ctrl.state == GS_PLAY || _ctrl.state == GS_OVER
            || _ctrl.state == GS_SERVE) {
            _ctrl.gotoMenu();
            return true;
        }
        return false;
    }
}
