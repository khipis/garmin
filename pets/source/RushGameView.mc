using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;

class RushGameView extends WatchUi.View {

    hidden var _pet;
    hidden var _timer;
    hidden var _taps;
    hidden var _ticksLeft;
    hidden var _state;
    hidden var _countdown;
    hidden var _countdownTicks;
    hidden var _doneTicks;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        _taps = 0;
        _ticksLeft = 62;
        _state = 0;
        _countdown = 3;
        _countdownTicks = 0;
        _doneTicks = 0;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onGameTimer), 80, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onGameTimer() {
        if (_state == 0) {
            _countdownTicks++;
            if (_countdownTicks >= 12) {
                _countdownTicks = 0;
                _countdown--;
                if (_countdown <= 0) {
                    _state = 1;
                    if (Toybox.Attention has :vibrate) {
                        Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(60, 100)]);
                    }
                }
            }
        } else if (_state == 1) {
            _ticksLeft--;
            if (_ticksLeft <= 0) {
                _state = 2;
                _doneTicks = 0;
                var score;
                if (_taps >= 15) { score = 3; }
                else if (_taps >= 10) { score = 2; }
                else if (_taps >= 5) { score = 1; }
                else { score = 0; }
                _pet.playResult(score);
            }
        } else if (_state == 2) {
            _doneTicks++;
            if (_doneTicks >= 25) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return;
            }
        }
        WatchUi.requestUpdate();
    }

    function tap() {
        if (_state == 1) {
            _taps++;
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(30, 40)]);
            }
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x0F0F23, 0x0F0F23);
        dc.clear();

        var petColors = _pet.getColors(_pet.petType);

        dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_SMALL, "Rush!", Graphics.TEXT_JUSTIFY_CENTER);

        if (_state == 0) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 38 / 100, Graphics.FONT_LARGE, "" + _countdown, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 60 / 100, Graphics.FONT_XTINY, "Get ready to tap!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == 1) {
            var barW = w * 60 / 100;
            var barH = h * 4 / 100;
            if (barH < 4) { barH = 4; }
            var barX = (w - barW) / 2;
            var barY = h * 20 / 100;
            dc.setColor(0x1A1A2E, 0x1A1A2E);
            dc.fillRectangle(barX, barY, barW, barH);
            dc.setColor(petColors[1], petColors[1]);
            dc.fillRectangle(barX, barY, barW * _ticksLeft / 62, barH);

            dc.setColor(petColors[3], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 32 / 100, Graphics.FONT_LARGE, "" + _taps, Graphics.TEXT_JUSTIFY_CENTER);

            var wobble = (_taps % 2 == 0) ? 2 : -2;
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2 + wobble, h * 55 / 100, Graphics.FONT_MEDIUM, "TAP!", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(0x555577, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_XTINY, "Mash SELECT!", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var msg;
            if (_taps >= 15) { msg = "INCREDIBLE!"; }
            else if (_taps >= 10) { msg = "Great speed!"; }
            else if (_taps >= 5) { msg = "Not bad!"; }
            else { msg = "Keep trying!"; }
            dc.setColor(petColors[3], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 35 / 100, Graphics.FONT_MEDIUM, "" + _taps + " taps", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 55 / 100, Graphics.FONT_TINY, msg, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class RushGameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.tap();
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
