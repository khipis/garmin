using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;

class ReactGameView extends WatchUi.View {

    hidden var _pet;
    hidden var _timer;
    hidden var _state;
    hidden var _waitTicks;
    hidden var _targetWait;
    hidden var _reactTicks;
    hidden var _round;
    hidden var _totalReact;
    hidden var _resultTicks;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        _round = 0;
        _totalReact = 0;
        setupRound();
    }

    hidden function setupRound() {
        _state = 0;
        _waitTicks = 0;
        _reactTicks = 0;
        _resultTicks = 0;
        _targetWait = 15 + Math.rand().abs() % 25;
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
            _waitTicks++;
            if (_waitTicks >= _targetWait) {
                _state = 1;
                _reactTicks = 0;
                if (Toybox.Attention has :vibrate) {
                    Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(75, 150)]);
                }
            }
        } else if (_state == 1) {
            _reactTicks++;
            if (_reactTicks > 50) {
                _state = 2;
                _totalReact += 50;
                _resultTicks = 0;
            }
        } else if (_state == 2 || _state == 3) {
            _resultTicks++;
            if (_resultTicks >= 18) {
                _round++;
                if (_round >= 3) {
                    _state = 4;
                    _resultTicks = 0;
                    var avgTicks = _totalReact / 3;
                    var score;
                    if (avgTicks <= 4) { score = 3; }
                    else if (avgTicks <= 7) { score = 2; }
                    else if (avgTicks <= 12) { score = 1; }
                    else { score = 0; }
                    _pet.playResult(score);
                } else {
                    setupRound();
                }
            }
        } else if (_state == 4) {
            _resultTicks++;
            if (_resultTicks >= 25) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return;
            }
        }
        WatchUi.requestUpdate();
    }

    function react() {
        if (_state == 0) {
            _state = 3;
            _totalReact += 50;
            _resultTicks = 0;
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(20, 300)]);
            }
        } else if (_state == 1) {
            _state = 2;
            _totalReact += _reactTicks;
            _resultTicks = 0;
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(50, 80)]);
            }
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var petColors = _pet.getColors(_pet.petType);

        if (_state == 0) {
            dc.setColor(0x0F0F23, 0x0F0F23);
            dc.clear();
            dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_SMALL, "React!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 20 / 100, Graphics.FONT_XTINY,
                "Round " + (_round + 1) + "/3", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_MEDIUM, "WAIT...", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x555577, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_XTINY, "Don't press yet!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == 1) {
            dc.setColor(0x003300, 0x003300);
            dc.clear();
            dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_SMALL, "React!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 20 / 100, Graphics.FONT_XTINY,
                "Round " + (_round + 1) + "/3", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x00FF00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_LARGE, "NOW!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xCCFFCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_XTINY, "Press SELECT!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == 2) {
            dc.setColor(0x0F0F23, 0x0F0F23);
            dc.clear();
            dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_SMALL, "React!", Graphics.TEXT_JUSTIFY_CENTER);
            var ms = _reactTicks * 80;
            dc.setColor(0x4CAF50, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 38 / 100, Graphics.FONT_MEDIUM, ms + "ms", Graphics.TEXT_JUSTIFY_CENTER);
            var msg;
            if (ms < 300) { msg = "Lightning!"; }
            else if (ms < 500) { msg = "Fast!"; }
            else if (ms < 800) { msg = "OK!"; }
            else { msg = "Slow..."; }
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 55 / 100, Graphics.FONT_TINY, msg, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == 3) {
            dc.setColor(0x1A0000, 0x1A0000);
            dc.clear();
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_MEDIUM, "TOO EARLY!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFF8888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 60 / 100, Graphics.FONT_XTINY, "Wait for green!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == 4) {
            dc.setColor(0x0F0F23, 0x0F0F23);
            dc.clear();
            var avgMs = (_totalReact * 80) / 3;
            dc.setColor(petColors[3], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 32 / 100, Graphics.FONT_MEDIUM, "Done!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 50 / 100, Graphics.FONT_TINY, "Avg: " + avgMs + "ms", Graphics.TEXT_JUSTIFY_CENTER);
            var msg;
            if (avgMs < 300) { msg = "Superhuman!"; }
            else if (avgMs < 500) { msg = "Great reflexes!"; }
            else if (avgMs < 800) { msg = "Not bad!"; }
            else { msg = "Keep practicing!"; }
            dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 63 / 100, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        var dots = "";
        for (var i = 0; i < 3; i++) {
            if (i < _round) { dots = dots + "* "; }
            else { dots = dots + "o "; }
        }
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_TINY, dots, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class ReactGameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.react();
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
