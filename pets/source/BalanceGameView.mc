using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;

// "Balance!" — your pet is doing a tightrope trick. It constantly tips off
// balance (an unstable equilibrium: the further it leans, the faster it
// falls). Tap LEFT / RIGHT to counter-lean and keep it centered as long as
// possible. Distinct from Dodge (lane movement) and Catch (timing) — this is
// a continuous self-correction challenge.
const BAL_TICK_CAP = 300;   // ~24s auto-win

class BalanceGameView extends WatchUi.View {

    hidden var _pet;
    hidden var _timer;
    hidden var _state;      // 0 playing, 1 done
    hidden var _tilt;       // -100 .. +100  (0 = perfectly centred)
    hidden var _vel;        // angular velocity
    hidden var _ticks;      // survived ticks
    hidden var _doneTicks;
    hidden var _wobbleAcc;
    hidden var _lean;       // last input direction for lean animation (-1/0/1)
    hidden var _leanTtl;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        _state = 0;
        _tilt = 0;
        _vel = 0;
        _ticks = 0;
        _doneTicks = 0;
        _wobbleAcc = 0;
        _lean = 0;
        _leanTtl = 0;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onGameTimer), 80, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    hidden function scoreToPlayResult() {
        if (_ticks < 40)  { return 0; }
        if (_ticks < 90)  { return 1; }
        if (_ticks < 160) { return 2; }
        return 3;
    }

    function nudge(dir) {
        if (_state != 0) { return; }
        _vel += dir * 4;
        if (_vel > 10)  { _vel = 10; }
        if (_vel < -10) { _vel = -10; }
        _lean = dir;
        _leanTtl = 3;
    }

    function leanLeft()  { nudge(-1); }
    function leanRight() { nudge(1); }

    hidden function endRun() {
        _state = 1;
        _doneTicks = 0;
        _pet.playResult(scoreToPlayResult());
        if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(50, 200)]);
        }
    }

    function onGameTimer() as Void {
        if (_state == 0) {
            _ticks++;
            if (_leanTtl > 0) { _leanTtl--; if (_leanTtl == 0) { _lean = 0; } }

            // Gravity: unstable equilibrium — pull grows with lean magnitude.
            var g = _tilt / 12;
            _vel += g;

            // Random wobble that ramps up slowly to raise difficulty over time.
            _wobbleAcc++;
            var every = 6 - _ticks / 80;
            if (every < 2) { every = 2; }
            if (_wobbleAcc >= every) {
                _wobbleAcc = 0;
                _vel += (Math.rand().abs() % 3) - 1;
            }

            if (_vel > 10)  { _vel = 10; }
            if (_vel < -10) { _vel = -10; }
            _tilt += _vel;

            if (_tilt >= 100 || _tilt <= -100) {
                if (_tilt > 100) { _tilt = 100; }
                if (_tilt < -100) { _tilt = -100; }
                endRun();
            } else if (_ticks >= BAL_TICK_CAP) {
                endRun();
            }
        } else {
            _doneTicks++;
            if (_doneTicks >= 28) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return;
            }
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(0x0B1420, 0x0B1420);
        dc.clear();

        // Title + survived seconds
        dc.setColor(0x66FFCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 6 / 100, Graphics.FONT_SMALL, "Balance!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 16 / 100, Graphics.FONT_XTINY,
                    (_ticks / 12).toString() + "s", Graphics.TEXT_JUSTIFY_CENTER);

        // Tightrope beam
        var beamY = h * 60 / 100;
        dc.setColor(0x6D4C41, 0x6D4C41);
        dc.fillRectangle(w * 8 / 100, beamY, w * 84 / 100, 3);
        // Support pole in center
        dc.setColor(0x4E342E, 0x4E342E);
        dc.fillRectangle(cx - 2, beamY, 4, h * 22 / 100);

        // Pet: horizontal shift + vertical dip based on lean (leaning = falling)
        var ps = w / 26;
        if (ps < 3) { ps = 3; }
        var shift = _tilt * (w * 34 / 100) / 100;
        var dip = (_tilt < 0 ? -_tilt : _tilt) * (h * 6 / 100) / 100;
        var pcx = cx + shift;
        var pcy = beamY - 6 * ps + dip;
        if (_state == 0) {
            _pet.drawPreview(dc, pcx, pcy, ps, _pet.petType);
        } else {
            // fell off
            _pet.draw(dc, pcx, beamY + 6 * ps, ps);
        }

        // Balance meter at bottom: center safe, edges danger
        var mY = h * 88 / 100;
        var mX = w * 12 / 100;
        var mW = w * 76 / 100;
        dc.setColor(0x1A2A3A, 0x1A2A3A);
        dc.fillRectangle(mX, mY, mW, 6);
        // danger zones
        dc.setColor(0x663333, 0x663333);
        dc.fillRectangle(mX, mY, mW * 12 / 100, 6);
        dc.fillRectangle(mX + mW * 88 / 100, mY, mW * 12 / 100, 6);
        // center tick
        dc.setColor(0x44AA66, 0x44AA66);
        dc.fillRectangle(mX + mW / 2 - 1, mY - 2, 2, 10);
        // marker
        var mp = mX + mW / 2 + _tilt * (mW / 2) / 100;
        var mc = ((_tilt < 0 ? -_tilt : _tilt) > 75) ? 0xFF4444 : 0xFFDD55;
        dc.setColor(mc, mc);
        dc.fillRectangle(mp - 2, mY - 3, 4, 12);

        if (_state == 1) {
            var won = (_ticks >= BAL_TICK_CAP);
            dc.setColor(won ? 0x66FFAA : 0xFF6666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 40 / 100, Graphics.FONT_MEDIUM,
                        won ? "PERFECT!" : "WOBBLE!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 50 / 100, Graphics.FONT_TINY,
                        "Held " + (_ticks / 12).toString() + "s", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 74 / 100, Graphics.FONT_XTINY,
                        "< lean   lean >", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class BalanceGameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onPreviousPage() { _view.leanLeft();  return true; }
    function onNextPage()     { _view.leanRight(); return true; }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP || k == WatchUi.KEY_LEFT)   { _view.leanLeft();  return true; }
        if (k == WatchUi.KEY_DOWN || k == WatchUi.KEY_RIGHT) { _view.leanRight(); return true; }
        if (k == WatchUi.KEY_ESC) { WatchUi.popView(WatchUi.SLIDE_DOWN); return true; }
        return false;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
