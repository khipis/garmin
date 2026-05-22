// ═══════════════════════════════════════════════════════════════
// MainView.mc — 25 ms tick driver + render loop.
//
// Render order (back → front):
//   1. Table backdrop + bezel
//   2. Drop targets (when not knocked down)
//   3. Slingshots (filled triangles + flash edges)
//   4. Bumpers
//   5. Flippers
//   6. Balls (up to MAX_BALLS in multi-ball)
//   7. HUD (score, lives, table name, MULTI-BALL indicator)
//
// All physics are amortised over a single 40 Hz tick — even with
// three balls + drops + slings, the per-tick cost is well below the
// watchdog budget on the slowest Garmin devices.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

const TICK_MS = 25;

class MainView extends WatchUi.View {

    var _ctrl;
    hidden var _timer;
    hidden var _laidOut;
    hidden var _delegate;
    // Safety: maximum frames a touch hold can keep flippers pressed
    // without a touch-up signal before we force-release them. Protects
    // against the device dropping the touch session (battery saver,
    // crashed touch driver, etc.) which would otherwise leave the
    // flippers stuck pointing skyward.
    hidden var _touchHoldFrames;
    static var TOUCH_HOLD_SAFETY_MAX = 40;  // 40 frames * 25 ms ≈ 1.0 s

    function initialize() {
        View.initialize();
        _ctrl    = new GameController();
        _timer   = null;
        _laidOut = false;
        _delegate = null;
        _touchHoldFrames = 0;
    }

    function setDelegate(d) { _delegate = d; }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), TICK_MS, true);
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() {
        _ctrl.step();
        // Safety auto-release for stuck touch holds — if the delegate
        // says we've been holding flippers via touch for too long
        // without a touch-up signal, force a release. This makes the
        // "flippers stuck up" failure mode impossible regardless of
        // how badly the device's touch driver behaves.
        if (_delegate != null && _delegate.isTouchHoldingFlippers()) {
            _delegate.tickTouch();
            _touchHoldFrames = _touchHoldFrames + 1;
            if (_touchHoldFrames >= TOUCH_HOLD_SAFETY_MAX) {
                _ctrl.releaseBothFlippers();
                _delegate.clearTouchHoldingFlippers();
                _touchHoldFrames = 0;
            }
        } else {
            _touchHoldFrames = 0;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        if (!_laidOut) {
            _ctrl.setScreen(dc.getWidth(), dc.getHeight());
            _laidOut = true;
        }
        dc.setColor(0x000814, 0x000814); dc.clear();

        if (_ctrl.state == GS_MENU) { _drawMenu(dc); return; }

        _drawTable(dc);
        _drawDrops(dc);
        _drawSlings(dc);
        _drawBumpers(dc);
        _ctrl.fLeft.draw(dc);
        _ctrl.fRight.draw(dc);
        for (var i = 0; i < MAX_BALLS; i++) { _ctrl.balls[i].draw(dc); }
        _drawHUD(dc);

        if (_ctrl.state == GS_LAUNCH) { _drawLaunchPrompt(dc); }
        if (_ctrl.state == GS_OVER)   { _drawOver(dc);         }
    }

    // ── Table backdrop ──────────────────────────────────────────────
    hidden function _drawTable(dc) {
        var theme = TableLibrary.theme(_ctrl.tableIdx);
        var bg     = theme[0];
        var accent = theme[1];

        // Body
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_ctrl.playX0, _ctrl.playY0,
                         _ctrl.playX1 - _ctrl.playX0,
                         _ctrl.playY1 - _ctrl.playY0);
        // Coloured bezel
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_ctrl.playX0 - 1, _ctrl.playY0 - 1,
                         (_ctrl.playX1 - _ctrl.playX0) + 2,
                         (_ctrl.playY1 - _ctrl.playY0) + 2);

        // Drain triangles below the flipper line — visual cue for the
        // dead zone.
        dc.setColor(0x110000, Graphics.COLOR_TRANSPARENT);
        var fy = _ctrl.fLeft.pivotY + 8;
        dc.fillPolygon([[_ctrl.playX0,     fy],
                        [_ctrl.playX0 + 8, _ctrl.playY1],
                        [_ctrl.playX0,     _ctrl.playY1]]);
        dc.fillPolygon([[_ctrl.playX1,     fy],
                        [_ctrl.playX1 - 8, _ctrl.playY1],
                        [_ctrl.playX1,     _ctrl.playY1]]);

        // Centre dashes — give the playfield depth
        dc.setColor((accent & 0xFFFFFF) / 4, Graphics.COLOR_TRANSPARENT);
        var cx = (_ctrl.playX0 + _ctrl.playX1) / 2;
        var y  = _ctrl.playY0 + 12;
        while (y < _ctrl.playY1 - 30) {
            dc.fillRectangle(cx - 1, y, 2, 4);
            y = y + 14;
        }

        // Launcher lane indicator — narrow vertical strip on the right
        dc.setColor((accent & 0xFFFFFF) / 6, Graphics.COLOR_TRANSPARENT);
        var laneX = _ctrl.playX1 - 6;
        dc.drawLine(laneX, _ctrl.playY0 + 6, laneX, _ctrl.playY1 - 12);
    }

    // ── Drop targets ────────────────────────────────────────────────
    hidden function _drawDrops(dc) {
        for (var i = 0; i < _ctrl.drops.size(); i++) {
            var d = _ctrl.drops[i];
            if (d.down) {
                // Ghost outline so the bank position is still visible
                dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(d.x, d.y, d.w, d.h);
                continue;
            }
            var col = (d.flash > 0) ? 0xFFFFFF : d.color;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(d.x, d.y, d.w, d.h);
            // White inner highlight bar — gives the target depth
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(d.x + 1, d.y + 1, d.w - 2, 1);
            // Dark base bar
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(d.x + 1, d.y + d.h - 2, d.w - 2, 1);
        }
    }

    // ── Slingshots ──────────────────────────────────────────────────
    hidden function _drawSlings(dc) {
        for (var i = 0; i < _ctrl.slings.size(); i++) {
            var s = _ctrl.slings[i];
            var fillCol = (s.flash > 0) ? 0xFFFFFF : s.color;
            dc.setColor(fillCol, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[s.ax, s.ay],
                            [s.bx, s.by],
                            [s.cx, s.cy]]);
            // Edge highlight on the active edge
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(s.ax, s.ay, s.bx, s.by);
            dc.setPenWidth(1);
        }
    }

    // ── Bumpers ─────────────────────────────────────────────────────
    hidden function _drawBumpers(dc) {
        for (var i = 0; i < _ctrl.bumpers.size(); i++) {
            var b   = _ctrl.bumpers[i];
            var bx  = b[0];
            var by  = b[1];
            var r   = b[2];
            var col = b[3];
            var flash = b[4];
            // Outer ring (flash white when struck)
            var ring = (flash > 0) ? 0xFFFFFF : ((col >> 1) & 0x7F7F7F);
            dc.setColor(ring, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, r + 2);
            // Body
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, r);
            // Inner cap
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, r / 2);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, r / 3);
        }
    }

    // ── HUD ─────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var cx = _ctrl.screenW / 2;
        var ty = (_ctrl.screenH * 3) / 100; if (ty < 3) { ty = 3; }

        // Score — centre top
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ty, Graphics.FONT_MEDIUM,
                    _formatScore(_ctrl.score),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Lives → small balls top-right
        dc.setColor(0xCCCCDD, Graphics.COLOR_TRANSPARENT);
        var lvX = _ctrl.screenW - 8;
        var maxShow = _ctrl.lives;
        if (maxShow > 5) { maxShow = 5; }
        for (var i = 0; i < maxShow; i++) {
            dc.fillCircle(lvX - i * 8, ty + 8, 3);
        }
        if (_ctrl.lives > 5) {
            dc.drawText(lvX - 5 * 8 - 4, ty + 4, Graphics.FONT_XTINY,
                        "+" + (_ctrl.lives - 5).toString(),
                        Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Best / Multi-ball banner / Table name — top-left
        var name = TableLibrary.NAMES[_ctrl.tableIdx];
        if (_ctrl.isMultiball()) {
            // "MULTI x2" flashes between cyan and yellow each tick
            dc.setColor(0xFFEE00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, ty + 4, Graphics.FONT_XTINY,
                        "MULTI x" + _ctrl.aliveBallCount().toString(),
                        Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, ty + 4, Graphics.FONT_XTINY,
                        name, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ── Launch / over overlays ──────────────────────────────────────
    // While the ball is parked we draw an oscillating power meter on
    // the launcher lane and a "TAP to launch" hint. The current bar
    // height = current power; colour shifts green→yellow→red as the
    // meter charges, so the player can time the release for a soft
    // skill shot or a full-power blast.
    hidden function _drawLaunchPrompt(dc) {
        var cx = _ctrl.screenW / 2;

        // Power meter geometry — narrow vertical bar in the launcher
        // lane, sized to the playfield.
        var ph = _ctrl.playY1 - _ctrl.playY0;
        var mH = (ph * 38) / 100; if (mH < 60) { mH = 60; }
        var mW = 6;
        var mX = _ctrl.playX1 - 12;
        var mY = _ctrl.playY1 - 18 - mH;
        // Frame
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mX - 1, mY - 1, mW + 2, mH + 2);
        dc.setColor(0x000814, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mX, mY, mW, mH);
        // Tick marks every 25%
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        for (var k = 1; k <= 3; k++) {
            var ty = mY + (mH * k) / 4;
            dc.drawLine(mX - 2, ty, mX + mW + 2, ty);
        }
        // Charge bar — grows from the bottom up.
        var p   = _ctrl.launchPower;
        if (p < 0)   { p = 0; }
        if (p > 100) { p = 100; }
        var barH = (mH * p) / 100;
        var fill;
        if (p < 40)      { fill = 0x44FF88; }
        else if (p < 75) { fill = 0xFFEE00; }
        else             { fill = 0xFF4422; }
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mX, mY + mH - barH, mW, barH);

        // Hint label
        dc.setColor(0x44FFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _ctrl.screenH - 18, Graphics.FONT_XTINY,
                    "TAP / SEL: launch  -  " + p.format("%d") + "%",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawOver(dc) {
        var bw = _ctrl.screenW * 70 / 100; if (bw < 160) { bw = 160; }
        var bh = _ctrl.screenH * 40 / 100; if (bh < 120) { bh = 120; }
        var bx = (_ctrl.screenW - bw) / 2;
        var by = (_ctrl.screenH - bh) / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        var col = (_ctrl.score >= _ctrl.hi && _ctrl.score > 0)
                  ? 0x44FF88 : 0xFF4466;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);
        var cx = _ctrl.screenW / 2;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 32, Graphics.FONT_XTINY,
                    "Score " + _formatScore(_ctrl.score),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 48, Graphics.FONT_XTINY,
                    "Table: " + TableLibrary.NAMES[_ctrl.tableIdx],
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (_ctrl.score > 0 && _ctrl.score >= _ctrl.hi) {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 66, Graphics.FONT_XTINY,
                        "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 66, Graphics.FONT_XTINY,
                        "Best " + _formatScore(_ctrl.hi),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 16, Graphics.FONT_XTINY,
                    "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Menu ────────────────────────────────────────────────────────
    // Chess-style two-row menu: TABLE (cycle) + START.
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
        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 8 / 100, Graphics.FONT_SMALL,
                    "PINBALL", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 19 / 100, Graphics.FONT_SMALL,
                    "PRO", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 30 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Mini demo bumpers
        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 28, H * 41 / 100, 6);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx,      H * 41 / 100, 6);
        dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 28, H * 41 / 100, 6);

        // Chess-style rows
        var labels = [
            "Table: " + TableLibrary.NAMES[_ctrl.tableIdx],
            "START"
        ];
        var rowH = (H * 13) / 100; if (rowH < 24) { rowH = 24; } if (rowH > 34) { rowH = 34; }
        var rowW = (W * 78) / 100; if (rowW < 140) { rowW = 140; }
        var rowX = (W - rowW) / 2;
        var gap  = (H * 2) / 100;  if (gap < 4) { gap = 4; }
        var nRows = 2;
        var rowY0 = H * 52 / 100;
        var selRow = _ctrl.menuCursor;
        for (var i = 0; i < nRows; i++) {
            var ry = rowY0 + i * (rowH + gap);
            var sel = (i == selRow);
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

        // Best score
        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 88 / 100, Graphics.FONT_XTINY,
                        "BEST " + _formatScore(_ctrl.hi),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Comma-grouped thousands.
    hidden function _formatScore(n) {
        var s = n.format("%d");
        var len = s.length();
        if (len <= 3) { return s; }
        var out = "";
        for (var i = 0; i < len; i++) {
            if (i > 0 && (len - i) % 3 == 0) { out = out + ","; }
            out = out + s.substring(i, i + 1);
        }
        return out;
    }

    // ── Input intents ───────────────────────────────────────────────
    // Unified flipper hold (used by button + touch-hold paths).
    function flipBothPress()   { _ctrl.holdBothFlippers();    }
    function flipBothRelease() { _ctrl.releaseBothFlippers(); }
    // Tap-fallback pulse (used only when onTap fires without an
    // accompanying onDrag pair — Flipper.pulse self-releases).
    function tapPulseFlippers() { _ctrl.tapPulseFlippers(16); }
    // Launch and state nav (used by both onTap and onDrag-STOP path
    // when the player taps in launch/menu/over state).
    function launchBall() { _ctrl.launchBall(); }
    function gotoMenu()   { _ctrl.gotoMenu();   }
    function confirm()    { _ctrl.selectAction(); }
    function menuPrev()   { _ctrl.menuPrev(); }
    function menuNext()   { _ctrl.menuNext(); }

    function handleBack() {
        if (_ctrl.state == GS_PLAY || _ctrl.state == GS_LAUNCH
            || _ctrl.state == GS_OVER) {
            _ctrl.gotoMenu();
            return true;
        }
        return false;
    }
}
