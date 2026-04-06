using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;

class MiniGameView extends WatchUi.View {

    hidden var _pet;
    hidden var _timer;
    hidden var _barPos;
    hidden var _barDir;
    hidden var _barSpeed;
    hidden var _round;
    hidden var _score;
    hidden var _state;
    hidden var _stateTimer;
    hidden var _zoneStart;
    hidden var _zoneEnd;
    hidden var _sparkles;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        _barPos = 0;
        _barDir = 1;
        _barSpeed = 3;
        _round = 0;
        _score = 0;
        _state = 0;
        _stateTimer = 0;
        _sparkles = 0;
        setupRound();
    }

    hidden function setupRound() {
        _barPos = 0;
        _barDir = 1;
        _barSpeed = 3;

        if (_round == 0) { _zoneStart = 35; _zoneEnd = 65; }
        else if (_round == 1) { _zoneStart = 38; _zoneEnd = 62; }
        else { _zoneStart = 42; _zoneEnd = 58; }

        if (_pet.hasTrait(TRAIT_PLAYFUL)) { _zoneStart -= 5; _zoneEnd += 5; }
        if (_pet.hasTrait(TRAIT_HYPER)) { _barSpeed = 4; _zoneStart -= 3; _zoneEnd += 3; }
        if (_pet.hasTrait(TRAIT_LAZY)) { _barSpeed = 2; }
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onGameTimer), 80, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onGameTimer() as Void {
        _sparkles = (_sparkles + 1) % 8;
        if (_state == 0) {
            _barPos = _barPos + _barDir * _barSpeed;
            if (_barPos >= 100) { _barPos = 100; _barDir = -1; }
            if (_barPos <= 0) { _barPos = 0; _barDir = 1; }
        } else {
            _stateTimer += 1;
            if (_stateTimer > 15) {
                if (_state == 1 || _state == 2) {
                    _round += 1;
                    if (_round >= 3) { _state = 3; _stateTimer = 0; }
                    else { setupRound(); _state = 0; }
                } else if (_state == 3) {
                    _pet.playResult(_score);
                    WatchUi.popView(WatchUi.SLIDE_DOWN);
                    return;
                }
            }
        }
        WatchUi.requestUpdate();
    }

    function checkHit() {
        if (_state != 0) { return; }
        if (_barPos >= _zoneStart && _barPos <= _zoneEnd) {
            _score += 1; _state = 1;
            if (Toybox.Attention has :vibrate) { Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(50, 80)]); }
        } else {
            _state = 2;
            if (Toybox.Attention has :vibrate) { Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(20, 200)]); }
        }
        _stateTimer = 0;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x0F0F23, 0x0F0F23);
        dc.clear();

        var petColors = _pet.getColors(_pet.petType);

        dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 8 / 100, Graphics.FONT_SMALL, "Catch!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 20 / 100, Graphics.FONT_XTINY,
            "Round " + (_round + 1) + "/3", Graphics.TEXT_JUSTIFY_CENTER);

        drawBar(dc, w, h, petColors);
        drawFeedback(dc, w, h, petColors);
        drawScore(dc, w, h, petColors);
        drawDecorations(dc, w, h);
    }

    hidden function drawBar(dc, w, h, petColors) {
        var barW = w * 60 / 100;
        var barH = h * 6 / 100;
        if (barH < 8) { barH = 8; }
        var barX = (w - barW) / 2;
        var barY = h * 42 / 100;

        dc.setColor(0x1A1A2E, 0x1A1A2E);
        dc.fillRectangle(barX, barY, barW, barH);

        var zoneX = barX + barW * _zoneStart / 100;
        var zoneW = barW * (_zoneEnd - _zoneStart) / 100;

        if (_state == 1) { dc.setColor(0x4CAF50, 0x4CAF50); }
        else if (_state == 2) { dc.setColor(0x661111, 0x661111); }
        else { dc.setColor(petColors[0], petColors[0]); }
        dc.fillRectangle(zoneX, barY, zoneW, barH);

        dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(barX, barY, barW, barH);

        var indX = barX + barW * _barPos / 100;
        var indW = w * 2 / 100;
        if (indW < 3) { indW = 3; }

        if (_state == 1) { dc.setColor(0x66FF66, 0x66FF66); }
        else if (_state == 2) { dc.setColor(0xFF4444, 0xFF4444); }
        else { dc.setColor(petColors[3], petColors[3]); }
        dc.fillRectangle(indX - indW / 2, barY - 3, indW, barH + 6);

        if (_state == 0) {
            dc.setColor(petColors[2], petColors[2]);
            dc.fillRectangle(indX - 1, barY - 6, 3, 3);
            dc.fillRectangle(indX - 1, barY + barH + 3, 3, 3);
        }
    }

    hidden function drawFeedback(dc, w, h, petColors) {
        var fy = h * 55 / 100;
        if (_state == 1) {
            dc.setColor(0x4CAF50, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, fy, Graphics.FONT_MEDIUM, "HIT!", Graphics.TEXT_JUSTIFY_CENTER);
            drawHitSparkles(dc, w, h, petColors);
        } else if (_state == 2) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, fy, Graphics.FONT_MEDIUM, "MISS", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == 3) {
            dc.setColor(petColors[3], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 50 / 100, Graphics.FONT_MEDIUM, "Done!", Graphics.TEXT_JUSTIFY_CENTER);
            var msg;
            if (_score >= 3) { msg = "Perfect!"; }
            else if (_score >= 2) { msg = "Great!"; }
            else if (_score >= 1) { msg = "Not bad!"; }
            else { msg = "Fun times!"; }
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_TINY, msg, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x555577, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, fy, Graphics.FONT_XTINY, "Press SELECT!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawHitSparkles(dc, w, h, petColors) {
        dc.setColor(petColors[3], petColors[3]);
        var f = _sparkles;
        var cx = w / 2;
        var cy = h * 55 / 100;
        var d = (f + 2) * 4;
        dc.fillRectangle(cx - d, cy - d / 3, 3, 3);
        dc.fillRectangle(cx + d, cy - d / 3, 3, 3);
        dc.fillRectangle(cx, cy - d, 2, 2);
        dc.fillRectangle(cx - d / 2, cy + d / 2, 2, 2);
        dc.fillRectangle(cx + d / 2, cy + d / 2, 2, 2);
    }

    hidden function drawScore(dc, w, h, petColors) {
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        var dots = "";
        for (var i = 0; i < 3; i++) {
            if (i < _score) { dots = dots + "* "; }
            else if (i < _round) { dots = dots + "- "; }
            else { dots = dots + "o "; }
        }
        dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_TINY, dots, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawDecorations(dc, w, h) {
        var f = _sparkles;
        dc.setColor(0x222244, 0x222244);
        var topY = h * 30 / 100;
        dc.drawLine(w * 15 / 100, topY, w * 85 / 100, topY);
        dc.drawLine(w * 15 / 100, topY + h * 32 / 100, w * 85 / 100, topY + h * 32 / 100);
        dc.setColor(0x333355, 0x333355);
        if (f % 4 < 2) {
            dc.fillRectangle(w * 20 / 100, topY - 5, 2, 2);
            dc.fillRectangle(w * 80 / 100, topY - 5, 2, 2);
        }
    }
}

class MiniGameDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.checkHit();
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
