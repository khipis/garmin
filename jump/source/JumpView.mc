using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum {
    JS_SELECT,
    JS_INRUN,
    JS_TAKEOFF,
    JS_FLIGHT,
    JS_LANDING,
    JS_SCORE,
    JS_FINAL
}

const NUM_JUMPERS = 3;

class JumpView extends WatchUi.View {

    var gameState;
    var accelMag;

    hidden var _w;
    hidden var _h;

    hidden var _jumperIdx;
    hidden var _jumperNames;
    hidden var _jumperColors;
    hidden var _jumperAccents;

    hidden var _inrunX;
    hidden var _inrunSpeed;
    hidden var _inrunMaxSpeed;

    hidden var _takeoffTick;
    hidden var _takeoffQuality;

    hidden var _flightX;
    hidden var _flightY;
    hidden var _flightVx;
    hidden var _flightVy;
    hidden var _flightAngle;
    hidden var _flightLean;
    hidden var _leanInput;
    hidden var _windSpeed;
    hidden var _distance;

    hidden var _landTick;
    hidden var _landGood;

    hidden var _jumpScores;
    hidden var _jumpDistances;
    hidden var _jumpNum;
    hidden var _bestDist;

    hidden var _timer;
    hidden var _tick;
    hidden var _hillProfile;
    hidden var _cameraX;

    hidden var _speedBarTick;
    hidden var _speedBarDir;
    hidden var _lockedSpeed;

    hidden var _snowParticles;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());

        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;

        _jumperNames = ["Chikko", "Foczka", "Doggo"];
        _jumperColors = [0xFFCC22, 0x88BBDD, 0xBB8844];
        _jumperAccents = [0xFF8822, 0x6699BB, 0xFFCC66];

        _jumpScores = new [NUM_JUMPERS];
        _jumpDistances = new [NUM_JUMPERS];
        for (var i = 0; i < NUM_JUMPERS; i++) {
            _jumpScores[i] = 0.0;
            _jumpDistances[i] = 0.0;
        }

        _snowParticles = new [20];
        for (var i = 0; i < 20; i++) {
            _snowParticles[i] = [Math.rand().abs() % _w, Math.rand().abs() % _h];
        }

        _tick = 0;
        _jumpNum = 0;
        _bestDist = 0.0;
        _jumperIdx = 0;
        accelMag = 0;

        gameState = JS_SELECT;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 40, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _tick++;
        updateSnow();

        if (gameState == JS_INRUN) {
            updateInrun();
        } else if (gameState == JS_TAKEOFF) {
            updateTakeoff();
        } else if (gameState == JS_FLIGHT) {
            updateFlight();
        } else if (gameState == JS_LANDING) {
            _landTick++;
            if (_landTick >= 40) {
                gameState = JS_SCORE;
            }
        }

        WatchUi.requestUpdate();
    }

    hidden function updateSnow() {
        for (var i = 0; i < 20; i++) {
            var p = _snowParticles[i];
            p[1] = p[1] + 1 + (i % 3);
            p[0] = p[0] + ((i % 2 == 0) ? 1 : -1);
            if (p[1] > _h) { p[1] = 0; p[0] = Math.rand().abs() % _w; }
            if (p[0] < 0) { p[0] = _w - 1; }
            if (p[0] >= _w) { p[0] = 0; }
        }
    }

    function startJump() {
        _jumpNum++;
        gameState = JS_INRUN;

        _speedBarTick = 0;
        _speedBarDir = 1;
        _lockedSpeed = 0;

        _inrunX = 0.0;
        _inrunSpeed = 0.0;
        _inrunMaxSpeed = 85.0 + (Math.rand().abs() % 15).toFloat();

        _takeoffTick = 0;
        _takeoffQuality = 0.0;

        _flightX = 0.0;
        _flightY = 0.0;
        _flightVx = 0.0;
        _flightVy = 0.0;
        _flightAngle = 0.0;
        _flightLean = 0.0;
        _leanInput = 0;
        _distance = 0.0;
        _windSpeed = -1.0 + (Math.rand().abs() % 30).toFloat() / 10.0;

        _landTick = 0;
        _landGood = false;
        _cameraX = 0.0;

        buildHill();
    }

    hidden function buildHill() {
        _hillProfile = new [60];
        for (var i = 0; i < 60; i++) {
            var x = i.toFloat();
            if (i < 10) {
                _hillProfile[i] = -x * 2.5;
            } else if (i < 20) {
                _hillProfile[i] = -25.0 - (x - 10.0) * 1.5;
            } else if (i < 30) {
                _hillProfile[i] = -40.0 - (x - 20.0) * 0.8;
            } else if (i < 45) {
                _hillProfile[i] = -48.0 - (x - 30.0) * 0.3;
            } else {
                _hillProfile[i] = -52.5 + (x - 45.0) * 0.5;
            }
        }
    }

    hidden function getHillY(dist) {
        var idx = (dist / 3.0).toNumber();
        if (idx < 0) { idx = 0; }
        if (idx >= 59) { return _hillProfile[59]; }
        var frac = dist / 3.0 - idx.toFloat();
        return _hillProfile[idx] * (1.0 - frac) + _hillProfile[idx + 1] * frac;
    }

    hidden function updateInrun() {
        _speedBarTick += _speedBarDir * 4;
        if (_speedBarTick >= 100) { _speedBarTick = 100; _speedBarDir = -1; }
        if (_speedBarTick <= 0) { _speedBarTick = 0; _speedBarDir = 1; }

        _inrunX += 0.8;
        _inrunSpeed = _inrunMaxSpeed * (_inrunX / 40.0);
        if (_inrunSpeed > _inrunMaxSpeed) { _inrunSpeed = _inrunMaxSpeed; }

        if (_inrunX >= 40.0) {
            _lockedSpeed = _speedBarTick;
            gameState = JS_TAKEOFF;
            _takeoffTick = 0;
        }
    }

    hidden function updateTakeoff() {
        _takeoffTick++;
        if (_takeoffTick >= 20) {
            executeTakeoff(false);
        }
    }

    function executeTakeoff(manual) {
        if (gameState != JS_TAKEOFF) { return; }

        if (manual) {
            var timing = _takeoffTick;
            if (timing >= 6 && timing <= 10) {
                _takeoffQuality = 1.0;
            } else if (timing >= 4 && timing <= 13) {
                _takeoffQuality = 0.7;
            } else if (timing >= 2 && timing <= 16) {
                _takeoffQuality = 0.4;
            } else {
                _takeoffQuality = 0.15;
            }
        } else {
            _takeoffQuality = 0.1;
        }

        var speedFactor = _lockedSpeed.toFloat() / 100.0;
        var baseSpeed = 4.0 + speedFactor * 4.0 + _takeoffQuality * 3.0;
        var jumpAngle = 20.0 + _takeoffQuality * 15.0;
        var rad = jumpAngle * 3.14159 / 180.0;

        _flightVx = baseSpeed * Math.cos(rad);
        _flightVy = -baseSpeed * Math.sin(rad);
        _flightX = 0.0;
        _flightY = 0.0;
        _flightAngle = jumpAngle;
        _flightLean = 0.0;

        gameState = JS_FLIGHT;
    }

    function setLean(dir) {
        _leanInput = dir;
    }

    hidden function updateFlight() {
        var gravity = 0.12;
        var liftBase = 0.02;

        _flightLean += _leanInput * 0.4;
        if (_flightLean > 35.0) { _flightLean = 35.0; }
        if (_flightLean < -20.0) { _flightLean = -20.0; }

        if (_leanInput == 0) {
            if (_flightLean > 0.5) { _flightLean -= 0.2; }
            else if (_flightLean < -0.5) { _flightLean += 0.2; }
            else { _flightLean = 0.0; }
        }

        var leanRad = _flightLean * 3.14159 / 180.0;
        var liftForce = liftBase + _flightLean * 0.0015;
        if (liftForce < 0.0) { liftForce = 0.0; }

        var speed = Math.sqrt(_flightVx * _flightVx + _flightVy * _flightVy);
        var lift = liftForce * speed;
        var drag = 0.003 * speed * speed;

        _flightVy = _flightVy + gravity - lift;
        _flightVx = _flightVx - drag * 0.3 + _windSpeed * 0.005;

        if (_flightVx < 1.0) { _flightVx = 1.0; }

        _flightX += _flightVx;
        _flightY += _flightVy;

        _distance = _flightX * 0.8;

        _flightAngle = _flightAngle * 0.95 + _flightLean * 0.05;

        var hillY = getHillY(_distance);
        var screenY = _flightY;

        if (screenY >= hillY + 5.0) {
            var landingSpeed = Math.sqrt(_flightVx * _flightVx + _flightVy * _flightVy);
            _landGood = (_flightLean >= 5.0 && _flightLean <= 30.0 && landingSpeed < 12.0);

            gameState = JS_LANDING;
            _landTick = 0;

            var dist = _distance;
            if (dist < 0.0) { dist = 0.0; }

            var styleScore = _takeoffQuality * 30.0;
            if (_landGood) { styleScore += 20.0; }
            var leanBonus = _flightLean > 10.0 ? (_flightLean - 10.0) * 0.5 : 0.0;
            styleScore += leanBonus;
            if (styleScore > 60.0) { styleScore = 60.0; }

            var totalScore = dist + styleScore;

            _jumpDistances[_jumperIdx] = dist;
            _jumpScores[_jumperIdx] = totalScore;
            if (dist > _bestDist) { _bestDist = dist; }

            doVibe();
        }
    }

    hidden function doVibe() {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(60, 250)]);
            }
        }
    }

    function doAction() {
        if (gameState == JS_SELECT) {
            startJump();
        } else if (gameState == JS_TAKEOFF) {
            executeTakeoff(true);
        } else if (gameState == JS_SCORE) {
            _jumperIdx++;
            if (_jumperIdx >= NUM_JUMPERS) {
                gameState = JS_FINAL;
            } else {
                startJump();
            }
        } else if (gameState == JS_FINAL) {
            _jumperIdx = 0;
            _jumpNum = 0;
            _bestDist = 0.0;
            for (var i = 0; i < NUM_JUMPERS; i++) {
                _jumpScores[i] = 0.0;
                _jumpDistances[i] = 0.0;
            }
            gameState = JS_SELECT;
        }
    }

    function cycleJumper(dir) {
        if (gameState == JS_SELECT) {
            _jumperIdx = (_jumperIdx + dir + NUM_JUMPERS) % NUM_JUMPERS;
        }
    }

    // ===== Drawing =====

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x0C1428, 0x0C1428);
        dc.clear();

        if (gameState == JS_SELECT) { drawSelect(dc, w, h); return; }
        if (gameState == JS_SCORE) { drawScoreScreen(dc, w, h); return; }
        if (gameState == JS_FINAL) { drawFinal(dc, w, h); return; }

        drawSky(dc, w, h);
        drawSnow(dc, w, h);

        if (gameState == JS_INRUN) {
            drawInrun(dc, w, h);
        } else if (gameState == JS_TAKEOFF) {
            drawTakeoff(dc, w, h);
        } else if (gameState == JS_FLIGHT) {
            drawFlightScene(dc, w, h);
        } else if (gameState == JS_LANDING) {
            drawLanding(dc, w, h);
        }

        drawGameHud(dc, w, h);
    }

    hidden function drawSky(dc, w, h) {
        dc.setColor(0x1A2844, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h / 3);
        dc.setColor(0x223355, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h / 3, w, h / 6);

        dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 85 / 100, h * 10 / 100, 4);
        dc.fillCircle(w * 15 / 100, h * 8 / 100, 2);
        dc.fillCircle(w * 50 / 100, h * 5 / 100, 2);
        dc.fillCircle(w * 70 / 100, h * 15 / 100, 1);
    }

    hidden function drawSnow(dc, w, h) {
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 20; i++) {
            var p = _snowParticles[i];
            var sz = (i % 3 == 0) ? 2 : 1;
            dc.fillRectangle(p[0], p[1], sz, sz);
        }
    }

    hidden function drawInrun(dc, w, h) {
        var groundY = h * 70 / 100;

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        var rampStartX = w * 15 / 100;
        var rampEndX = w * 65 / 100;
        var rampTopY = h * 30 / 100;
        dc.fillRectangle(0, groundY, w, h - groundY);

        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 6; i++) {
            var lx = rampStartX + (rampEndX - rampStartX) * i / 6;
            var ly = groundY - (groundY - rampTopY) * (6 - i) / 6;
            var lx2 = rampStartX + (rampEndX - rampStartX) * (i + 1) / 6;
            var ly2 = groundY - (groundY - rampTopY) * (5 - i) / 6;
            dc.setPenWidth(3);
            dc.drawLine(lx, ly, lx2, ly2);
            dc.setPenWidth(1);
        }

        dc.setColor(0x446688, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(rampStartX, groundY, rampEndX, rampTopY);
        dc.setPenWidth(1);

        var progress = _inrunX / 40.0;
        if (progress > 1.0) { progress = 1.0; }
        var px = rampStartX + (rampEndX - rampStartX) * progress;
        var py = groundY - (groundY - rampTopY) * progress;

        drawJumperSprite(dc, px.toNumber(), py.toNumber() - 8, _jumperIdx, false);

        var barX = w * 75 / 100;
        var barY = h * 25 / 100;
        var barH = h * 50 / 100;
        var barW = 10;
        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, barH);
        var fillH = barH * _speedBarTick / 100;
        var c = 0x44FF44;
        if (_speedBarTick > 75) { c = 0xFF4444; }
        else if (_speedBarTick > 40) { c = 0xFFCC22; }
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY + barH - fillH, barW, fillH);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barX + barW / 2, barY - 14, Graphics.FONT_XTINY, "SPD", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawTakeoff(dc, w, h) {
        var groundY = h * 70 / 100;

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, groundY, w, h - groundY);

        dc.setColor(0x446688, Graphics.COLOR_TRANSPARENT);
        var rampEndX = w * 65 / 100;
        var rampTopY = h * 30 / 100;
        dc.setPenWidth(2);
        dc.drawLine(w * 15 / 100, groundY, rampEndX, rampTopY);
        dc.setPenWidth(1);

        var shake = (_takeoffTick % 4 < 2) ? 2 : -2;
        drawJumperSprite(dc, rampEndX + shake, rampTopY - 8, _jumperIdx, false);

        var perfect = (_takeoffTick >= 6 && _takeoffTick <= 10);
        var good = (_takeoffTick >= 4 && _takeoffTick <= 13);
        dc.setColor(perfect ? 0x44FF44 : (good ? 0xFFCC22 : 0xFF4444), Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_MEDIUM, "JUMP!", Graphics.TEXT_JUSTIFY_CENTER);

        var barW = w * 50 / 100;
        var barX = (w - barW) / 2;
        var barY2 = h * 88 / 100;
        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY2, barW, 6);
        var sweetL = barX + barW * 30 / 100;
        var sweetR = barX + barW * 50 / 100;
        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sweetL, barY2, sweetR - sweetL, 6);
        var markerX = barX + barW * _takeoffTick / 20;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(markerX - 1, barY2 - 2, 3, 10);
    }

    hidden function drawFlightScene(dc, w, h) {
        var baseY = h * 75 / 100;

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, baseY, w, h - baseY);

        var cx = w / 2;
        for (var i = 0; i < 58; i++) {
            var d1 = i.toFloat() * 3.0;
            var d2 = (i + 1).toFloat() * 3.0;
            var sx1 = cx + ((d1 - _distance) * 1.2).toNumber();
            var sx2 = cx + ((d2 - _distance) * 1.2).toNumber();
            var hy1 = baseY + (getHillY(d1) * 1.2).toNumber();
            var hy2 = baseY + (getHillY(d2) * 1.2).toNumber();

            if (sx2 < 0 || sx1 > w) { continue; }

            dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(sx1, hy1, sx2, hy2);
            dc.setPenWidth(1);

            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            if (hy1 < h && hy2 < h) {
                var topY = hy1 < hy2 ? hy1 : hy2;
                dc.fillRectangle(sx1, topY, sx2 - sx1 + 1, h - topY);
            }
        }

        for (var m = 20; m <= 160; m += 20) {
            var mx = cx + ((m.toFloat() - _distance) * 1.2).toNumber();
            if (mx > 10 && mx < w - 10) {
                var mhy = baseY + (getHillY(m.toFloat()) * 1.2).toNumber();
                dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(mx - 1, mhy - 8, 2, 8);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawText(mx, mhy - 20, Graphics.FONT_XTINY, "" + m, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        var hillYAtDist = getHillY(_distance);
        var petScreenY = baseY + (_flightY * 1.2).toNumber();
        var hillScreenY = baseY + (hillYAtDist * 1.2).toNumber();
        var altAboveHill = hillScreenY - petScreenY;

        drawJumperSprite(dc, cx, petScreenY - 4, _jumperIdx, true);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 10 / 100, Graphics.FONT_SMALL, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        if (_windSpeed > 1.0) {
            dc.setColor(0x88BBFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 5, h * 25 / 100, Graphics.FONT_XTINY, "TAIL", Graphics.TEXT_JUSTIFY_RIGHT);
        } else if (_windSpeed < -0.5) {
            dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 5, h * 25 / 100, Graphics.FONT_XTINY, "HEAD", Graphics.TEXT_JUSTIFY_RIGHT);
        }

        var leanPct = ((_flightLean + 20.0) / 55.0 * 100.0).toNumber();
        if (leanPct < 0) { leanPct = 0; }
        if (leanPct > 100) { leanPct = 100; }
        var lBarY = h * 30 / 100;
        var lBarH = h * 40 / 100;
        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(5, lBarY, 8, lBarH);

        var sweetTop = lBarY + lBarH * 15 / 100;
        var sweetBot = lBarY + lBarH * 55 / 100;
        dc.setColor(0x224422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(5, sweetTop, 8, sweetBot - sweetTop);

        var markerY = lBarY + lBarH - lBarH * leanPct / 100;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(3, markerY - 1, 12, 3);
        dc.drawText(16, markerY - 8, Graphics.FONT_XTINY, "LEAN", Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function drawLanding(dc, w, h) {
        var baseY = h * 75 / 100;

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, baseY, w, h - baseY);

        var cx = w / 2;
        for (var i = 0; i < 58; i++) {
            var d1 = i.toFloat() * 3.0;
            var d2 = (i + 1).toFloat() * 3.0;
            var sx1 = cx + ((d1 - _distance) * 1.2).toNumber();
            var sx2 = cx + ((d2 - _distance) * 1.2).toNumber();
            var hy1 = baseY + (getHillY(d1) * 1.2).toNumber();
            var hy2 = baseY + (getHillY(d2) * 1.2).toNumber();
            if (sx2 < 0 || sx1 > w) { continue; }
            dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(sx1, hy1, sx2, hy2);
            dc.setPenWidth(1);
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            if (hy1 < h && hy2 < h) {
                var topY = hy1 < hy2 ? hy1 : hy2;
                dc.fillRectangle(sx1, topY, sx2 - sx1 + 1, h - topY);
            }
        }

        var hillYAtDist = getHillY(_distance);
        var petY = baseY + (hillYAtDist * 1.2).toNumber() - 8;

        var shake = (_landTick < 8) ? ((_landTick % 4 < 2) ? 3 : -3) : 0;
        drawJumperSprite(dc, cx + shake, petY, _jumperIdx, false);

        dc.setColor(_landGood ? 0x44FF44 : 0xFFCC22, Graphics.COLOR_TRANSPARENT);
        var landText = _landGood ? "TELEMARK!" : "LANDED";
        dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_MEDIUM, landText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 35 / 100, Graphics.FONT_MEDIUM, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawJumperSprite(dc, x, y, idx, flying) {
        var bodyC = _jumperColors[idx];
        var accC = _jumperAccents[idx];

        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 6);
        dc.setColor(accC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 4);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 2, y - 2, 1, 2);
        dc.fillRectangle(x + 1, y - 2, 1, 2);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 2, y - 1, 1, 1);
        dc.fillRectangle(x + 1, y - 1, 1, 1);

        if (flying) {
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 8, y + 2, 16, 3);
            dc.setColor(accC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 7, y + 3, 14, 1);

            dc.setColor(0x666688, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 10, y + 6, 20, 2);
        } else {
            dc.setColor(0x666688, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 5, y + 6, 10, 2);
        }
    }

    hidden function drawGameHud(dc, w, h) {
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 2, Graphics.FONT_XTINY, _jumperNames[_jumperIdx] + " #" + _jumpNum, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawSelect(dc, w, h) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 8 / 100, Graphics.FONT_MEDIUM, "SKI JUMP", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 22 / 100, Graphics.FONT_XTINY, "Choose jumper", Graphics.TEXT_JUSTIFY_CENTER);

        var cy = h * 45 / 100;
        drawJumperSprite(dc, w / 2, cy, _jumperIdx, false);

        dc.setColor(_jumperColors[_jumperIdx], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, cy + 18, Graphics.FONT_SMALL, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);

        var descs = ["Neurotic. Panics.", "Happy flopper.", "Loyal zoomer."];
        dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, cy + 38, Graphics.FONT_XTINY, descs[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 - w * 25 / 100, cy, Graphics.FONT_SMALL, "<", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2 + w * 25 / 100, cy, Graphics.FONT_SMALL, ">", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_XTINY, "SEL to start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawScoreScreen(dc, w, h) {
        var dist = _jumpDistances[_jumperIdx - 1];
        var score = _jumpScores[_jumperIdx - 1];
        var name = _jumperNames[_jumperIdx - 1];

        dc.setColor(_jumperColors[_jumperIdx - 1], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 10 / 100, Graphics.FONT_SMALL, name, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 25 / 100, Graphics.FONT_MEDIUM, dist.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_XTINY, "Style: " + score.toNumber() + " pts", Graphics.TEXT_JUSTIFY_CENTER);

        var grade;
        if (dist >= 130.0) { grade = "HILL RECORD!"; }
        else if (dist >= 100.0) { grade = "EXCELLENT!"; }
        else if (dist >= 70.0) { grade = "GREAT!"; }
        else if (dist >= 40.0) { grade = "GOOD"; }
        else { grade = "SHORT"; }
        dc.setColor(0x44FFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 55 / 100, Graphics.FONT_SMALL, grade, Graphics.TEXT_JUSTIFY_CENTER);

        if (_jumperIdx < NUM_JUMPERS) {
            dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 70 / 100, Graphics.FONT_XTINY, "Next: " + _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_XTINY, "Press to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFinal(dc, w, h) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 8 / 100, Graphics.FONT_MEDIUM, "RESULTS", Graphics.TEXT_JUSTIFY_CENTER);

        var bestIdx = 0;
        var bestScore = _jumpScores[0];
        for (var i = 0; i < NUM_JUMPERS; i++) {
            var yy = h * (25 + i * 18) / 100;
            var isB = (_jumpScores[i] >= bestScore);
            if (isB) { bestScore = _jumpScores[i]; bestIdx = i; }

            dc.setColor(_jumperColors[i], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 15 / 100, yy, Graphics.FONT_XTINY, _jumperNames[i], Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 60 / 100, yy, Graphics.FONT_XTINY, _jumpDistances[i].toNumber() + "m", Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 85 / 100, yy, Graphics.FONT_XTINY, "" + _jumpScores[i].toNumber(), Graphics.TEXT_JUSTIFY_LEFT);
        }

        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 75 / 100, Graphics.FONT_SMALL, _jumperNames[bestIdx] + " WINS!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 87 / 100, Graphics.FONT_XTINY, "Press to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
