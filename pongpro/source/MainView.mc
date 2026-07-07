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
    hidden var _started;    // auto-start the match on first layout

    function initialize() {
        View.initialize();
        _ctrl    = new GameController();
        _timer   = null;
        _laidOut = false;
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
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        if (!_laidOut) {
            _ctrl.setScreen(dc.getWidth(), dc.getHeight());
            _laidOut = true;
        }
        // Menu lives in the shared root view — drop straight into a match and
        // never render an in-game menu here.
        if (!_started || _ctrl.state == GS_MENU) {
            _ctrl.startMatch();
            _started = true;
        }
        // Pure black background — classic Pong feel.
        dc.setColor(0x000000, 0x000000); dc.clear();

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
    function isOver()    { return _ctrl.state == GS_OVER; }
    function isInMatch() {
        return _ctrl.state == GS_PLAY || _ctrl.state == GS_SERVE;
    }

    // Rematch after a game-over (SELECT / tap / swipe).
    function restart() { _ctrl.startMatch(); }

    function handleTap(x, y) {
        if (_ctrl.state == GS_OVER) { _ctrl.startMatch(); return; }
        // Live play — tap upper/lower half nudges paddle
        var mid = (_ctrl.playY0 + _ctrl.playY1) / 2;
        var dir = (y < mid) ? -1 : 1;
        _ctrl.impulse(dir);
    }
}
