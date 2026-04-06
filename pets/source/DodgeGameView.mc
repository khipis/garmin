using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;

const DODGE_OBS_MAX = 8;
const DODGE_LANES = 5;
const DODGE_PET_ROW = 88;

class DodgeGameView extends WatchUi.View {

    hidden var _pet;
    hidden var _timer;
    hidden var _state;
    hidden var _doneTicks;
    hidden var _survivalTicks;
    hidden var _petLane;
    hidden var _obsLane;
    hidden var _obsY;
    hidden var _obsOn;
    hidden var _spawnAcc;
    hidden var _fallSpeed;
    hidden var _sparkles;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        _state = 0;
        _doneTicks = 0;
        _survivalTicks = 0;
        _petLane = DODGE_LANES / 2;
        _spawnAcc = 0;
        _fallSpeed = 2;
        _sparkles = 0;
        _obsLane = new [DODGE_OBS_MAX];
        _obsY = new [DODGE_OBS_MAX];
        _obsOn = new [DODGE_OBS_MAX];
        for (var i = 0; i < DODGE_OBS_MAX; i++) {
            _obsOn[i] = 0;
        }
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onGameTimer), 80, true);
    }

    function onHide() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    hidden function survivalDisplayScore() {
        return (_survivalTicks * 8) / 10;
    }

    hidden function survivalToPlayResult() {
        var s = survivalDisplayScore();
        if (s < 30) {
            return 0;
        } else if (s < 60) {
            return 1;
        } else if (s < 100) {
            return 2;
        }
        return 3;
    }

    hidden function spawnObstacle() {
        var lane = Math.rand().abs() % DODGE_LANES;
        for (var i = 0; i < DODGE_OBS_MAX; i++) {
            if (_obsOn[i] == 0) {
                _obsLane[i] = lane;
                _obsY[i] = 0;
                _obsOn[i] = 1;
                return;
            }
        }
    }

    hidden function movePet(delta) {
        if (_state != 0) {
            return;
        }
        _petLane += delta;
        if (_petLane < 0) {
            _petLane = 0;
        }
        if (_petLane >= DODGE_LANES) {
            _petLane = DODGE_LANES - 1;
        }
    }

    hidden function checkCollisions() {
        var petY = DODGE_PET_ROW;
        for (var i = 0; i < DODGE_OBS_MAX; i++) {
            if (_obsOn[i] == 0) {
                continue;
            }
            if (_obsLane[i] != _petLane) {
                continue;
            }
            if (_obsY[i] >= petY - 8 && _obsY[i] <= petY + 10) {
                return true;
            }
        }
        return false;
    }

    function onGameTimer() {
        if (_state == 0) {
            _sparkles = (_sparkles + 1) % 8;
            _survivalTicks++;
            _fallSpeed = 2 + _survivalTicks / 80;
            if (_fallSpeed > 10) {
                _fallSpeed = 10;
            }
            _spawnAcc++;
            var spawnEvery = 14 - _fallSpeed / 2;
            if (spawnEvery < 5) {
                spawnEvery = 5;
            }
            if (_spawnAcc >= spawnEvery) {
                _spawnAcc = 0;
                spawnObstacle();
            }
            for (var i = 0; i < DODGE_OBS_MAX; i++) {
                if (_obsOn[i] != 0) {
                    _obsY[i] += _fallSpeed;
                    if (_obsY[i] > 110) {
                        _obsOn[i] = 0;
                    }
                }
            }
            if (checkCollisions()) {
                _state = 1;
                _doneTicks = 0;
                var pr = survivalToPlayResult();
                _pet.playResult(pr);
                if (Toybox.Attention has :vibrate) {
                    Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(20, 200)]);
                }
            }
        } else if (_state == 1) {
            _doneTicks++;
            if (_doneTicks >= 25) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return;
            }
        }
        WatchUi.requestUpdate();
    }

    function moveLeft() {
        movePet(-1);
    }

    function moveRight() {
        movePet(1);
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x0F0F23, 0x0F0F23);
        dc.clear();

        var petColors = _pet.getColors(_pet.petType);

        dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_SMALL, "Dodge!", Graphics.TEXT_JUSTIFY_CENTER);

        var scoreStr = "" + survivalDisplayScore();
        dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 14 / 100, Graphics.FONT_XTINY, scoreStr, Graphics.TEXT_JUSTIFY_CENTER);

        drawObstacles(dc, w, h, petColors);
        drawPet(dc, w, h, petColors);

        if (_state == 1) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_MEDIUM, "HIT!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 55 / 100, Graphics.FONT_TINY, "Score " + scoreStr, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x555577, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_XTINY, "< prev  next >", Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawDecorations(dc, w, h);
    }

    hidden function laneToX(dc, lane) {
        var w = dc.getWidth();
        var margin = w * 12 / 100;
        var track = w - 2 * margin;
        return margin + track * (lane * 2 + 1) / (DODGE_LANES * 2);
    }

    hidden function drawObstacles(dc, w, h, petColors) {
        dc.setColor(0xAA3333, 0xAA3333);
        for (var i = 0; i < DODGE_OBS_MAX; i++) {
            if (_obsOn[i] == 0) {
                continue;
            }
            var cx = laneToX(dc, _obsLane[i]);
            var cy = h * _obsY[i] / 100;
            var rw = w * 7 / 100;
            if (rw < 6) {
                rw = 6;
            }
            var rh = h * 5 / 100;
            if (rh < 6) {
                rh = 6;
            }
            dc.fillRectangle(cx - rw / 2, cy - rh / 2, rw, rh);
        }
    }

    hidden function drawPet(dc, w, h, petColors) {
        var cx = laneToX(dc, _petLane);
        var cy = h * DODGE_PET_ROW / 100;
        var pw = w * 9 / 100;
        if (pw < 8) {
            pw = 8;
        }
        var ph = h * 7 / 100;
        if (ph < 8) {
            ph = 8;
        }
        if (_state == 1) {
            dc.setColor(0x662222, 0x662222);
        } else {
            dc.setColor(petColors[0], petColors[0]);
        }
        dc.fillRectangle(cx - pw / 2, cy - ph / 2, pw, ph);
        dc.setColor(petColors[3], petColors[3]);
        dc.fillRectangle(cx - 2, cy - ph / 4, 2, 2);
        dc.fillRectangle(cx + 1, cy - ph / 4, 2, 2);
    }

    hidden function drawDecorations(dc, w, h) {
        var f = _sparkles;
        dc.setColor(0x222244, 0x222244);
        var topY = h * 22 / 100;
        dc.drawLine(w * 10 / 100, topY, w * 90 / 100, topY);
        dc.setColor(0x333355, 0x333355);
        if (f % 4 < 2) {
            dc.fillRectangle(w * 15 / 100, topY - 4, 2, 2);
            dc.fillRectangle(w * 85 / 100, topY - 4, 2, 2);
        }
    }
}
