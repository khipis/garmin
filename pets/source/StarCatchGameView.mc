using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;

// "Comet Catch" — catch falling stars with your basket, but a single
// meteor ends the run. Distinct from Dodge (pure avoidance): here you have
// to actively chase good drops into position while staying alert for the
// bad ones. Best-ever catch count is tracked for the Voidmoth unlock.
const COMET_OBS_MAX = 8;
const COMET_LANES = 5;
const COMET_BASKET_ROW = 88;
const COMET_TIME_LIMIT = 460;

class StarCatchGameView extends WatchUi.View {

    hidden var _pet;
    hidden var _timer;
    hidden var _state;
    hidden var _doneTicks;
    hidden var _ticks;
    hidden var _basketLane;
    hidden var _obsLane;
    hidden var _obsY;
    hidden var _obsOn;
    hidden var _obsKind; // 0 = star, 1 = meteor
    hidden var _spawnAcc;
    hidden var _fallSpeed;
    hidden var _caught;
    hidden var _hit;
    hidden var _sparkles;
    hidden var _catchFlash;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        _state = 0;
        _doneTicks = 0;
        _ticks = 0;
        _basketLane = COMET_LANES / 2;
        _spawnAcc = 0;
        _fallSpeed = 2;
        _caught = 0;
        _hit = false;
        _sparkles = 0;
        _catchFlash = 0;
        _obsLane = new [COMET_OBS_MAX];
        _obsY = new [COMET_OBS_MAX];
        _obsOn = new [COMET_OBS_MAX];
        _obsKind = new [COMET_OBS_MAX];
        for (var i = 0; i < COMET_OBS_MAX; i++) { _obsOn[i] = 0; }
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onGameTimer), 80, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    hidden function catchToPlayResult() {
        if (_caught < 3) { return 0; }
        else if (_caught < 6) { return 1; }
        else if (_caught < 10) { return 2; }
        return 3;
    }

    hidden function spawnObstacle() {
        var lane = Math.rand().abs() % COMET_LANES;
        var kind = (Math.rand().abs() % 4 == 0) ? 1 : 0; // 25% meteors
        for (var i = 0; i < COMET_OBS_MAX; i++) {
            if (_obsOn[i] == 0) {
                _obsLane[i] = lane;
                _obsY[i] = 0;
                _obsOn[i] = 1;
                _obsKind[i] = kind;
                return;
            }
        }
    }

    hidden function moveBasket(delta) {
        if (_state != 0) { return; }
        _basketLane += delta;
        if (_basketLane < 0) { _basketLane = 0; }
        if (_basketLane >= COMET_LANES) { _basketLane = COMET_LANES - 1; }
    }

    hidden function endRun(hit) {
        _hit = hit;
        _state = 1;
        _doneTicks = 0;
        _pet.reportCometScore(_caught);
        _pet.playResult(catchToPlayResult());
        if (Toybox.Attention has :vibrate) {
            if (hit) { Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(20, 200)]); }
            else { Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(60, 150)]); }
        }
    }

    function onGameTimer() as Void {
        if (_state == 0) {
            _sparkles = (_sparkles + 1) % 8;
            if (_catchFlash > 0) { _catchFlash--; }
            _ticks++;
            _fallSpeed = 2 + _ticks / 90;
            if (_fallSpeed > 8) { _fallSpeed = 8; }
            _spawnAcc++;
            var spawnEvery = 16 - _fallSpeed;
            if (spawnEvery < 7) { spawnEvery = 7; }
            if (_spawnAcc >= spawnEvery) { _spawnAcc = 0; spawnObstacle(); }

            for (var i = 0; i < COMET_OBS_MAX; i++) {
                if (_obsOn[i] == 0) { continue; }
                _obsY[i] += _fallSpeed;
                if (_obsY[i] >= COMET_BASKET_ROW - 6 && _obsY[i] <= COMET_BASKET_ROW + 8 && _obsLane[i] == _basketLane) {
                    if (_obsKind[i] == 1) {
                        _obsOn[i] = 0;
                        endRun(true);
                        break;
                    } else {
                        _obsOn[i] = 0;
                        _caught++;
                        _catchFlash = 6;
                        if (Toybox.Attention has :vibrate) {
                            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(40, 40)]);
                        }
                    }
                } else if (_obsY[i] > 110) {
                    _obsOn[i] = 0;
                }
            }

            if (_state == 0 && _ticks >= COMET_TIME_LIMIT) {
                endRun(false);
            }
        } else if (_state == 1) {
            _doneTicks++;
            if (_doneTicks >= 28) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return;
            }
        }
        WatchUi.requestUpdate();
    }

    function moveLeft() { moveBasket(-1); }
    function moveRight() { moveBasket(1); }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x0A0A20, 0x0A0A20);
        dc.clear();

        var petColors = _pet.getColors(_pet.petType);

        drawStarfield(dc, w, h);

        dc.setColor(0xFFDD55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_SMALL, "Comet Catch!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x9999CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 14 / 100, Graphics.FONT_XTINY, "* " + _caught, Graphics.TEXT_JUSTIFY_CENTER);

        drawObstacles(dc, w, h);
        drawBasket(dc, w, h, petColors);

        if (_state == 1) {
            if (_hit) {
                dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_MEDIUM, "METEOR!", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(0xFFDD55, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_MEDIUM, "TIME UP!", Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 55 / 100, Graphics.FONT_TINY, "Caught " + _caught, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x555577, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_XTINY, "< move  move >", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function laneToX(dc, lane) {
        var w = dc.getWidth();
        var margin = w * 12 / 100;
        var track = w - 2 * margin;
        return margin + track * (lane * 2 + 1) / (COMET_LANES * 2);
    }

    hidden function drawObstacles(dc, w, h) {
        for (var i = 0; i < COMET_OBS_MAX; i++) {
            if (_obsOn[i] == 0) { continue; }
            var cx = laneToX(dc, _obsLane[i]);
            var cy = h * _obsY[i] / 100;
            if (_obsKind[i] == 1) {
                dc.setColor(0xFF5533, 0xFF5533);
                dc.fillCircle(cx, cy, w * 3 / 100 + 2);
                dc.setColor(0x882211, 0x882211);
                dc.fillRectangle(cx - 2, cy - 2, 2, 2);
            } else {
                dc.setColor(0xFFEE88, 0xFFEE88);
                dc.fillRectangle(cx - 1, cy - 5, 2, 10);
                dc.fillRectangle(cx - 5, cy - 1, 10, 2);
                dc.setColor(0xFFFFFF, 0xFFFFFF);
                dc.fillRectangle(cx - 1, cy - 1, 2, 2);
            }
        }
    }

    hidden function drawBasket(dc, w, h, petColors) {
        var cx = laneToX(dc, _basketLane);
        var cy = h * COMET_BASKET_ROW / 100;
        var bw = w * 12 / 100;
        if (bw < 12) { bw = 12; }
        var bh = h * 5 / 100;
        if (bh < 7) { bh = 7; }
        var clr = (_catchFlash > 0) ? 0xFFEE88 : petColors[0];
        dc.setColor(clr, clr);
        dc.fillRoundedRectangle(cx - bw / 2, cy, bw, bh, 3);
        dc.setColor(petColors[3], petColors[3]);
        dc.fillRectangle(cx - bw / 2, cy, bw, 2);
    }

    hidden function drawStarfield(dc, w, h) {
        dc.setColor(0x333366, 0x333366);
        for (var i = 0; i < 12; i++) {
            var sx = (w * ((i * 41 + 7) % 97)) / 100;
            var sy = (h * ((i * 23 + 3) % 60)) / 100;
            var tw = ((_sparkles + i) % 8 < 4) ? 1 : 0;
            dc.fillRectangle(sx, sy, 1 + tw, 1 + tw);
        }
    }
}

class StarCatchGameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        return true;
    }

    function onPreviousPage() {
        _view.moveLeft();
        return true;
    }

    function onNextPage() {
        _view.moveRight();
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
