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

const NUM_JUMPERS = 5;
const TRAIL_LEN = 14;

class BitochiJumpView extends WatchUi.View {

    var gameState;
    var accelMag;

    hidden var _w;
    hidden var _h;

    hidden var _jumperIdx;
    hidden var _jumperNames;
    hidden var _jumperColors;
    hidden var _jumperAccents;
    hidden var _jumperDescs;
    hidden var _statSpeedMul;
    hidden var _statLiftMul;
    hidden var _statTakeoffMul;
    hidden var _statLeanRate;
    hidden var _statDragLeanMul;

    hidden var _inrunX;
    hidden var _inrunSpeed;
    hidden var _inrunMaxSpeed;

    hidden var _takeoffTick;
    hidden var _takeoffQuality;
    hidden var _takeoffFlashTicks;

    hidden var _flightX;
    hidden var _flightY;
    hidden var _flightVx;
    hidden var _flightVy;
    hidden var _flightAngle;
    hidden var _flightLean;
    hidden var _leanInput;
    hidden var _windBase;
    hidden var _windCurrent;
    hidden var _windGustPhase;
    hidden var _distance;

    hidden var _landTick;
    hidden var _landGood;

    hidden var _jumpScores;
    hidden var _jumpDistances;
    hidden var _cumScores;
    hidden var _cumDistances;
    hidden var _lastJumpPoints;
    hidden var _lastJumpDist;
    hidden var _resultJumperIdx;

    hidden var _jumpNum;
    hidden var _bestDist;

    hidden var _timer;
    hidden var _tick;
    hidden var _hillProfile;
    hidden var _cameraZoom;

    hidden var _speedBarTick;
    hidden var _speedBarDir;
    hidden var _lockedSpeed;

    hidden var _snowParticles;

    hidden var _trailX;
    hidden var _trailY;
    hidden var _trailAge;

    hidden var _compStartIdx;
    hidden var _jumpOrderSlot;
    hidden var _currentRound;
    hidden var _showRoundStandings;

    hidden var _kPointDist;
    hidden var _hsDist;

    hidden var _sparkX;
    hidden var _sparkY;
    hidden var _sparkLife;
    hidden var _sparkVx;
    hidden var _sparkVy;
    hidden var _speedLineX;
    hidden var _speedLineY;
    hidden var _speedLineLen;
    hidden var _screenShakeX;
    hidden var _screenShakeY;
    hidden var _peakAlt;
    hidden var _peakFlash;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());

        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;

        _jumperNames = ["Chikko", "Foczka", "Doggo", "Vexor", "Emilka"];
        _jumperColors = [0xFFCC22, 0x88BBDD, 0xBB8844, 0xCC2222, 0xFF88CC];
        _jumperAccents = [0xFF8822, 0x6699BB, 0xFFCC66, 0xFF4444, 0xFFAAEE];
        _jumperDescs = [
            "Neurotic. Panics.",
            "Happy flopper.",
            "Loyal zoomer.",
            "Angry rocketeer.",
            "Graceful glider."
        ];

        _statSpeedMul = [1.0, 1.0, 1.08, 1.15, 0.92];
        _statLiftMul = [1.0, 1.05, 1.0, 0.9, 1.35];
        _statTakeoffMul = [1.0, 1.0, 1.0, 1.0, 0.72];
        _statLeanRate = [1.0, 1.15, 1.05, 0.62, 1.1];
        _statDragLeanMul = [1.0, 0.95, 1.0, 1.12, 0.88];

        _jumpScores = new [NUM_JUMPERS];
        _jumpDistances = new [NUM_JUMPERS];
        _cumScores = new [NUM_JUMPERS];
        _cumDistances = new [NUM_JUMPERS];
        for (var i = 0; i < NUM_JUMPERS; i++) {
            _jumpScores[i] = 0.0;
            _jumpDistances[i] = 0.0;
            _cumScores[i] = 0.0;
            _cumDistances[i] = 0.0;
        }

        _snowParticles = new [28];
        for (var i = 0; i < 28; i++) {
            _snowParticles[i] = [Math.rand().abs() % _w, Math.rand().abs() % _h];
        }

        _trailX = new [TRAIL_LEN];
        _trailY = new [TRAIL_LEN];
        _trailAge = new [TRAIL_LEN];
        for (var t = 0; t < TRAIL_LEN; t++) {
            _trailX[t] = 0.0;
            _trailY[t] = 0.0;
            _trailAge[t] = 999;
        }

        _tick = 0;
        _jumpNum = 0;
        _bestDist = 0.0;
        _jumperIdx = 0;
        accelMag = 0;

        _kPointDist = 140.0;
        _hsDist = 175.0;

        _compStartIdx = 0;
        _jumpOrderSlot = 0;
        _currentRound = 1;
        _showRoundStandings = false;
        _windBase = 0.0;
        _windCurrent = 0.0;
        _windGustPhase = 0.0;
        _takeoffFlashTicks = 0;
        _screenShakeX = 0;
        _screenShakeY = 0;
        _peakAlt = 0.0;
        _peakFlash = 0;

        _sparkX = new [20];
        _sparkY = new [20];
        _sparkLife = new [20];
        _sparkVx = new [20];
        _sparkVy = new [20];
        for (var sp = 0; sp < 20; sp++) {
            _sparkX[sp] = 0; _sparkY[sp] = 0; _sparkLife[sp] = 0;
            _sparkVx[sp] = 0; _sparkVy[sp] = 0;
        }

        _speedLineX = new [12];
        _speedLineY = new [12];
        _speedLineLen = new [12];
        for (var sl = 0; sl < 12; sl++) {
            _speedLineX[sl] = 0; _speedLineY[sl] = 0; _speedLineLen[sl] = 0;
        }

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

        if (_takeoffFlashTicks > 0) {
            _takeoffFlashTicks--;
        }

        WatchUi.requestUpdate();
    }

    hidden function updateSnow() {
        var wx = _windCurrent;
        if (gameState != JS_FLIGHT && gameState != JS_LANDING) {
            wx = _windBase;
        }
        var drift = (wx * 0.8).toNumber();
        if (drift > 3) { drift = 3; }
        if (drift < -3) { drift = -3; }

        for (var i = 0; i < 28; i++) {
            var p = _snowParticles[i];
            p[1] = p[1] + 1 + (i % 4);
            p[0] = p[0] + drift + ((i % 2 == 0) ? 1 : -1);
            if (p[1] > _h) { p[1] = 0; p[0] = Math.rand().abs() % _w; }
            if (p[0] < 0) { p[0] = _w - 1; }
            if (p[0] >= _w) { p[0] = 0; }
        }
    }

    hidden function vibrate(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
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
        var sm = _statSpeedMul[_jumperIdx];
        _inrunMaxSpeed = (85.0 + (Math.rand().abs() % 15).toFloat()) * sm;
        if (_inrunMaxSpeed > 115.0) { _inrunMaxSpeed = 115.0; }

        _takeoffTick = 0;
        _takeoffQuality = 0.0;
        _takeoffFlashTicks = 0;

        _flightX = 0.0;
        _flightY = 0.0;
        _flightVx = 0.0;
        _flightVy = 0.0;
        _flightAngle = 0.0;
        _flightLean = 0.0;
        _leanInput = 0;
        _distance = 0.0;

        _windBase = -1.2 + (Math.rand().abs() % 35).toFloat() / 10.0;
        _windCurrent = _windBase;
        _windGustPhase = (Math.rand().abs() % 628).toFloat() / 100.0;

        _landTick = 0;
        _landGood = false;
        _cameraZoom = 1.0;
        _peakAlt = 0.0;
        _peakFlash = 0;
        _screenShakeX = 0;
        _screenShakeY = 0;

        for (var sp = 0; sp < 20; sp++) { _sparkLife[sp] = 0; }
        for (var sl = 0; sl < 12; sl++) { _speedLineLen[sl] = 0; }

        for (var t = 0; t < TRAIL_LEN; t++) {
            _trailAge[t] = 999;
        }

        buildHill();
    }

    hidden function buildHill() {
        _hillProfile = new [140];
        for (var i = 0; i < 140; i++) {
            var x = i.toFloat();
            if (i < 8) {
                _hillProfile[i] = -x * 4.0;
            } else if (i < 20) {
                _hillProfile[i] = -32.0 - (x - 8.0) * 3.0;
            } else if (i < 35) {
                _hillProfile[i] = -68.0 - (x - 20.0) * 2.0;
            } else if (i < 55) {
                _hillProfile[i] = -98.0 - (x - 35.0) * 1.2;
            } else if (i < 80) {
                _hillProfile[i] = -122.0 - (x - 55.0) * 0.6;
            } else if (i < 110) {
                _hillProfile[i] = -137.0 - (x - 80.0) * 0.25;
            } else {
                _hillProfile[i] = -144.5 + (x - 110.0) * 0.3;
            }
        }
    }

    hidden function getHillY(dist) {
        var idx = (dist / 3.0).toNumber();
        if (idx < 0) { idx = 0; }
        if (idx >= 139) { return _hillProfile[139]; }
        var frac = dist / 3.0 - idx.toFloat();
        return _hillProfile[idx] * (1.0 - frac) + _hillProfile[idx + 1] * frac;
    }

    hidden function hillScreenScale() {
        var z = _cameraZoom;
        if (z < 0.3) { z = 0.3; }
        if (z > 2.0) { z = 2.0; }
        return z;
    }

    hidden function updateInrun() {
        _speedBarTick += _speedBarDir * 4;
        if (_speedBarTick >= 100) { _speedBarTick = 100; _speedBarDir = -1; }
        if (_speedBarTick <= 0) { _speedBarTick = 0; _speedBarDir = 1; }

        _inrunX += 0.82;
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

        var baseQ = 0.0;
        if (manual) {
            var timing = _takeoffTick;
            if (timing >= 6 && timing <= 10) {
                baseQ = 1.0;
            } else if (timing >= 4 && timing <= 13) {
                baseQ = 0.7;
            } else if (timing >= 2 && timing <= 16) {
                baseQ = 0.4;
            } else {
                baseQ = 0.15;
            }
        } else {
            baseQ = 0.1;
        }

        var tom = _statTakeoffMul[_jumperIdx];
        _takeoffQuality = baseQ * tom;
        if (_takeoffQuality > 1.0) { _takeoffQuality = 1.0; }

        if (manual && baseQ >= 1.0) {
            _takeoffFlashTicks = 8;
        }

        vibrate(70, 120);

        var speedFactor = _lockedSpeed.toFloat() / 100.0;
        var baseSpeed = 5.0 + speedFactor * 5.5 + _takeoffQuality * 4.0;
        var jumpAngle = 16.0 + _takeoffQuality * 20.0;
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

    hidden function updateFlightFx(jx, jy, speed) {
        for (var i = 0; i < 20; i++) {
            if (_sparkLife[i] > 0) {
                _sparkX[i] = _sparkX[i] + _sparkVx[i];
                _sparkY[i] = _sparkY[i] + _sparkVy[i];
                _sparkVy[i] = _sparkVy[i] + 1;
                _sparkLife[i] = _sparkLife[i] - 1;
            }
        }

        if (_tick % 3 == 0 && speed > 3.0) {
            for (var i = 0; i < 20; i++) {
                if (_sparkLife[i] <= 0) {
                    _sparkX[i] = jx - 4 + Math.rand().abs() % 8;
                    _sparkY[i] = jy + Math.rand().abs() % 6;
                    _sparkVx[i] = -(2 + Math.rand().abs() % 4);
                    _sparkVy[i] = -(Math.rand().abs() % 4);
                    _sparkLife[i] = 8 + Math.rand().abs() % 10;
                    break;
                }
            }
        }

        for (var i = 0; i < 12; i++) {
            _speedLineLen[i] = _speedLineLen[i] - 2;
        }
        if (speed > 2.5 && _tick % 2 == 0) {
            for (var i = 0; i < 12; i++) {
                if (_speedLineLen[i] <= 0) {
                    _speedLineX[i] = jx - 20 - Math.rand().abs() % 40;
                    _speedLineY[i] = jy - 30 + Math.rand().abs() % 60;
                    _speedLineLen[i] = 8 + (speed * 3.0).toNumber() + Math.rand().abs() % 10;
                    if (_speedLineLen[i] > 40) { _speedLineLen[i] = 40; }
                    break;
                }
            }
        }

        if (speed > 5.0) {
            _screenShakeX = (Math.rand().abs() % 3) - 1;
            _screenShakeY = (Math.rand().abs() % 3) - 1;
        } else {
            _screenShakeX = 0;
            _screenShakeY = 0;
        }

        var alt = getHillY(_distance) - _flightY;
        if (alt > _peakAlt) {
            _peakAlt = alt;
            _peakFlash = 6;
        }
        if (_peakFlash > 0) { _peakFlash--; }
    }

    hidden function drawFlightFx(dc, w, h, jx, jy, speed) {
        for (var i = 0; i < 12; i++) {
            if (_speedLineLen[i] > 0) {
                var alpha = _speedLineLen[i];
                var c = 0x88AACC;
                if (alpha > 20) { c = 0xAADDFF; }
                dc.setColor(c, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(_speedLineX[i], _speedLineY[i],
                    _speedLineX[i] + _speedLineLen[i], _speedLineY[i]);
                if (alpha > 15) {
                    dc.drawLine(_speedLineX[i], _speedLineY[i] + 1,
                        _speedLineX[i] + _speedLineLen[i], _speedLineY[i] + 1);
                }
            }
        }

        for (var i = 0; i < 20; i++) {
            if (_sparkLife[i] > 0) {
                var life = _sparkLife[i];
                var sc2 = 0xFFDD44;
                if (life < 4) { sc2 = 0xFF8822; }
                else if (life < 8) { sc2 = 0xFFCC22; }
                dc.setColor(sc2, Graphics.COLOR_TRANSPARENT);
                var sz = (life > 6) ? 3 : ((life > 3) ? 2 : 1);
                dc.fillRectangle(_sparkX[i], _sparkY[i], sz, sz);
            }
        }

        if (speed > 4.0) {
            var intensity = ((speed - 4.0) * 25.0).toNumber();
            if (intensity > 80) { intensity = 80; }
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(jx, jy, 2);
            if (intensity > 40) {
                dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(jx, jy, 10 + (_tick % 4));
            }
        }

        if (_peakFlash > 0) {
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(jx + 15, jy - 15, Graphics.FONT_XTINY, "NEW HIGH!", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    hidden function pushTrail(sx, sy) {
        for (var i = TRAIL_LEN - 1; i > 0; i--) {
            _trailX[i] = _trailX[i - 1];
            _trailY[i] = _trailY[i - 1];
            _trailAge[i] = _trailAge[i - 1] + 1;
        }
        _trailX[0] = sx;
        _trailY[0] = sy;
        _trailAge[0] = 0;
    }

    hidden function updateFlight() {
        var gravity = 0.095;
        var liftBase = 0.028;

        var lr = _statLeanRate[_jumperIdx];
        _flightLean += _leanInput * 0.42 * lr;

        var accelLift = accelMag.toFloat() / 6000.0;
        if (accelLift > 1.5) { accelLift = 1.5; }
        if (accelLift < 0.0) { accelLift = 0.0; }
        _flightLean += accelLift * 0.55 * lr;

        if (_flightLean > 45.0) { _flightLean = 45.0; }
        if (_flightLean < -25.0) { _flightLean = -25.0; }

        if (_leanInput == 0 && accelLift < 0.08) {
            var dec = 0.12 * lr;
            if (_flightLean > dec) { _flightLean -= dec; }
            else if (_flightLean < -dec) { _flightLean += dec; }
            else { _flightLean = 0.0; }
        }

        _windGustPhase += 0.12;
        var gust = Math.sin(_windGustPhase) * 0.5 + Math.sin(_windGustPhase * 2.3) * 0.2;
        if ((_tick + _jumperIdx * 7) % 17 == 0) {
            gust += ((Math.rand().abs() % 7).toFloat() - 3.0) / 10.0;
        }
        _windCurrent = _windBase + gust;
        if (_windCurrent > 2.5) { _windCurrent = 2.5; }
        if (_windCurrent < -2.5) { _windCurrent = -2.5; }

        var distZoom = 1.2 - _distance * 0.0028;
        if (distZoom < 0.3) { distZoom = 0.3; }
        if (distZoom > 1.2) { distZoom = 1.2; }
        _cameraZoom = _cameraZoom * 0.94 + distZoom * 0.06;

        var forwardLean = _flightLean;
        if (forwardLean < 0.0) { forwardLean = 0.0; }

        var lm = _statLiftMul[_jumperIdx];
        var dm = _statDragLeanMul[_jumperIdx];
        var liftFromLean = forwardLean * 0.0038 * lm;
        var accelLiftBonus = accelLift * 0.012 * lm;
        var dragFromLean = forwardLean * 0.0006 * dm;

        var liftForce = (liftBase + liftFromLean + accelLiftBonus) * lm;
        if (liftForce < 0.0) { liftForce = 0.0; }

        var speed = Math.sqrt(_flightVx * _flightVx + _flightVy * _flightVy);
        var drag = 0.0016 * speed * speed + dragFromLean * speed;
        var lift = liftForce * speed;

        _flightVy = _flightVy + gravity - lift;
        _flightVx = _flightVx - drag * 0.22 + _windCurrent * 0.006;

        var hillY = getHillY(_distance);
        var relH = hillY - _flightY;
        if (relH < 20.0 && relH > -2.0) {
            var turb = ((Math.rand().abs() % 5).toFloat() - 2.0) * 0.03 * (1.0 - relH / 22.0);
            if (turb < -0.08) { turb = -0.08; }
            if (turb > 0.08) { turb = 0.08; }
            _flightVy += turb;
        }

        if (_flightVx < 0.9) { _flightVx = 0.9; }

        _flightX += _flightVx;
        _flightY += _flightVy;

        _distance = _flightX * 0.9;

        _flightAngle = _flightAngle * 0.94 + _flightLean * 0.06;

        hillY = getHillY(_distance);

        if (_flightY >= hillY + 5.0) {
            var landingSpeed = Math.sqrt(_flightVx * _flightVx + _flightVy * _flightVy);
            _landGood = (_flightLean >= 5.0 && _flightLean <= 34.0 && landingSpeed < 13.0);

            gameState = JS_LANDING;
            _landTick = 0;

            var dist = _distance;
            if (dist < 0.0) { dist = 0.0; }

            var styleScore = _takeoffQuality * 30.0;
            if (_landGood) { styleScore += 20.0; }
            var leanBonus = _flightLean > 10.0 ? (_flightLean - 10.0) * 0.55 : 0.0;
            styleScore += leanBonus;
            if (styleScore > 65.0) { styleScore = 65.0; }

            var totalScore = dist + styleScore;
            if (totalScore > 350.0) { totalScore = 350.0; }

            _lastJumpDist = dist;
            _lastJumpPoints = totalScore;
            _resultJumperIdx = _jumperIdx;

            _jumpDistances[_jumperIdx] = dist;
            _jumpScores[_jumperIdx] = totalScore;
            _cumDistances[_jumperIdx] = _cumDistances[_jumperIdx] + dist;
            _cumScores[_jumperIdx] = _cumScores[_jumperIdx] + totalScore;

            if (dist > _bestDist) { _bestDist = dist; }

            vibrate(_landGood ? 55 : 85, _landGood ? 180 : 320);
        }
    }

    function doAction() {
        if (gameState == JS_SELECT) {
            _compStartIdx = _jumperIdx;
            _jumpOrderSlot = 0;
            _currentRound = 1;
            _showRoundStandings = false;
            for (var i = 0; i < NUM_JUMPERS; i++) {
                _cumScores[i] = 0.0;
                _cumDistances[i] = 0.0;
                _jumpScores[i] = 0.0;
                _jumpDistances[i] = 0.0;
            }
            _jumperIdx = _compStartIdx;
            startJump();
        } else if (gameState == JS_TAKEOFF) {
            executeTakeoff(true);
        } else if (gameState == JS_SCORE) {
            if (_showRoundStandings) {
                _showRoundStandings = false;
                _currentRound = 2;
                _jumpOrderSlot = 0;
                _jumperIdx = _compStartIdx;
                startJump();
            } else {
                _jumpOrderSlot++;
                if (_jumpOrderSlot >= NUM_JUMPERS) {
                    if (_currentRound == 1) {
                        _showRoundStandings = true;
                    } else {
                        gameState = JS_FINAL;
                    }
                } else {
                    _jumperIdx = (_compStartIdx + _jumpOrderSlot) % NUM_JUMPERS;
                    startJump();
                }
            }
        } else if (gameState == JS_FINAL) {
            _jumperIdx = 0;
            _jumpNum = 0;
            _bestDist = 0.0;
            _jumpOrderSlot = 0;
            _currentRound = 1;
            _showRoundStandings = false;
            for (var i = 0; i < NUM_JUMPERS; i++) {
                _jumpScores[i] = 0.0;
                _jumpDistances[i] = 0.0;
                _cumScores[i] = 0.0;
                _cumDistances[i] = 0.0;
            }
            gameState = JS_SELECT;
        }
    }

    function cycleJumper(dir) {
        if (gameState == JS_SELECT) {
            _jumperIdx = (_jumperIdx + dir + NUM_JUMPERS) % NUM_JUMPERS;
        }
    }

    hidden function worldToScreenX(cx, distMeters) {
        var sc = hillScreenScale();
        return cx + ((distMeters - _distance) * sc).toNumber();
    }

    hidden function drawMountains(dc, w, h) {
        var par1 = (_distance * 0.06).toNumber() % w;
        var par2 = (_distance * 0.12).toNumber() % w;
        var par3 = (_distance * 0.18).toNumber() % w;

        dc.setColor(0x0E1525, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, h * 58 / 100], [w * 15 / 100 - par3, h * 22 / 100], [w * 30 / 100 - par3, h * 28 / 100], [w * 55 / 100 - par3, h * 18 / 100], [w * 75 / 100 - par3, h * 26 / 100], [w, h * 50 / 100], [w, h], [0, h]]);

        dc.setColor(0x18243A, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, h * 54 / 100], [w * 22 / 100 - par2, h * 30 / 100], [w * 42 / 100 - par2, h * 25 / 100], [w * 65 / 100 - par2, h * 32 / 100], [w, h * 46 / 100], [w, h], [0, h]]);

        dc.setColor(0x1E3048, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, h * 50 / 100], [w * 28 / 100 - par1, h * 35 / 100], [w * 50 / 100 - par1, h * 30 / 100], [w * 72 / 100 - par1, h * 38 / 100], [w, h * 44 / 100], [w, h], [0, h]]);

        dc.setColor(0xFFFFDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 22 / 100 - par3 / 2, h * 16 / 100, 2);
        dc.fillCircle(w * 55 / 100 - par3 / 2, h * 14 / 100, 1);
        dc.fillCircle(w * 78 / 100 - par3 / 2, h * 10 / 100, 2);
    }

    hidden function drawTreesAlongHill(dc, w, h, cx, baseY) {
        var sc = hillScreenScale();
        var spots = [8, 18, 28, 42, 56, 72, 88, 108, 130, 155, 180, 210, 240, 270, 310];
        for (var ti = 0; ti < 15; ti++) {
            var dm = spots[ti].toFloat();
            var sx = worldToScreenX(cx, dm);
            if (sx < -12 || sx > w + 12) { continue; }
            var hy = baseY + (getHillY(dm) * sc).toNumber();
            var treeH = 6 + (ti % 3) * 2;
            dc.setColor(0x1A3520, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 1, hy - 1, 2, 4);
            dc.setColor(0x1B5528, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, hy - treeH], [sx - 4, hy], [sx + 4, hy]]);
            dc.setColor(0x22AA44, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, hy - treeH + 2], [sx - 3, hy - 2], [sx + 3, hy - 2]]);
            if (ti % 2 == 0) {
                dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(sx - 2, hy - treeH + 1, 1, 1);
                dc.fillRectangle(sx + 1, hy - treeH + 3, 1, 1);
            }
        }
    }

    hidden function drawCrowd(dc, w, h) {
        var rowY = h - 5;
        var seed = 17;
        var pal = [0x3366CC, 0xCC3333, 0xEEAA22, 0xAA44AA, 0x44AAAA, 0xDDDDDD, 0x22AA66, 0xFF6644];
        for (var r = 0; r < 4; r++) {
            for (var c = 0; c < 28; c++) {
                var px = 2 + c * w / 28 + (r * 3) % 5;
                var py = rowY - r * 3;
                seed = (seed * 13 + c + r * 7) % 200;
                dc.setColor(pal[seed % 8], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(px, py, 2, 2);
                dc.setColor(0xDDCCAA, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(px, py - 2, 2, 1);
                if ((_tick + c + r) % 12 < 3) {
                    dc.setColor(pal[(seed + 1) % 8], Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(px - 1, py - 3, 1, 2);
                    dc.fillRectangle(px + 2, py - 3, 1, 2);
                }
            }
        }
    }

    hidden function drawWindArrows(dc, w, h) {
        var cy = h * 18 / 100;
        var strength = _windCurrent;
        var dir = 1;
        if (strength < 0) { dir = -1; }
        var ax = w / 2;
        var smag = strength;
        if (smag < 0) { smag = -smag; }
        var alen = (16 + smag * 8).toNumber();
        if (alen > 28) { alen = 28; }
        if (alen < 8) { alen = 8; }

        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        var x1 = ax - dir * alen / 2;
        var x2 = ax + dir * alen / 2;
        dc.setPenWidth(2);
        dc.drawLine(x1, cy, x2, cy);
        dc.setPenWidth(1);
        var hx = x2;
        var hy = cy;
        if (dir > 0) {
            dc.fillPolygon([[hx, hy], [hx - 5, hy - 3], [hx - 5, hy + 3]]);
        } else {
            dc.fillPolygon([[hx, hy], [hx + 5, hy - 3], [hx + 5, hy + 3]]);
        }
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, cy + 8, Graphics.FONT_XTINY, "WIND", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFlightTrail(dc) {
        for (var i = TRAIL_LEN - 1; i >= 0; i--) {
            if (_trailAge[i] > 50) { continue; }
            var age = _trailAge[i];
            if (age > 35) { continue; }
            var freshness = 35 - age;
            var col = 0xAABBDD;
            if (freshness > 25) { col = 0xDDEEFF; }
            else if (freshness > 15) { col = 0xAABBDD; }
            else if (freshness > 8) { col = 0x778899; }
            else { col = 0x445566; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var sz = 1;
            if (freshness > 20) { sz = 3; }
            else if (freshness > 10) { sz = 2; }
            dc.fillCircle(_trailX[i].toNumber(), _trailY[i].toNumber(), sz);

            if (freshness > 22 && i > 0 && _trailAge[i - 1] <= 50) {
                dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(_trailX[i].toNumber(), _trailY[i].toNumber(),
                    _trailX[i - 1].toNumber(), _trailY[i - 1].toNumber());
            }
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x0C1428, 0x0C1428);
        dc.clear();

        if (gameState == JS_SELECT) { drawSelect(dc, w, h); return; }
        if (gameState == JS_SCORE) {
            if (_showRoundStandings) {
                drawRoundStandings(dc, w, h);
            } else {
                drawScoreScreen(dc, w, h);
            }
            return;
        }
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
        dc.setColor(0x080C1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h * 15 / 100);
        dc.setColor(0x101830, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 15 / 100, w, h * 12 / 100);
        dc.setColor(0x182240, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 27 / 100, w, h * 12 / 100);
        dc.setColor(0x1E3058, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 39 / 100, w, h * 61 / 100);

        dc.setColor(0xDDCCFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 82 / 100, h * 8 / 100, 8);
        dc.setColor(0xEEDDFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 82 / 100, h * 8 / 100, 6);
        dc.setColor(0xFFEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 82 / 100, h * 8 / 100, 3);

        dc.setColor(0xAABBDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 10 / 100, h * 5 / 100, 1);
        dc.fillCircle(w * 25 / 100, h * 9 / 100, 1);
        dc.fillCircle(w * 42 / 100, h * 3 / 100, 2);
        dc.fillCircle(w * 58 / 100, h * 7 / 100, 1);
        dc.fillCircle(w * 70 / 100, h * 12 / 100, 1);
        dc.fillCircle(w * 35 / 100, h * 14 / 100, 1);
        dc.fillCircle(w * 92 / 100, h * 4 / 100, 1);
    }

    hidden function drawSnow(dc, w, h) {
        dc.setColor(0xC8D8E8, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 28; i++) {
            var p = _snowParticles[i];
            var sz = (i % 4 == 0) ? 2 : 1;
            dc.fillRectangle(p[0], p[1], sz, sz);
        }
    }

    hidden function drawHillMarkers(dc, cx, w, h, baseY) {
        var sc = hillScreenScale();
        var marks = [_kPointDist, _hsDist];
        var labs = ["K", "HS"];
        var cols = [0xFFCC22, 0xFF6644];
        for (var mi = 0; mi < 2; mi++) {
            var dm = marks[mi];
            var mx = worldToScreenX(cx, dm);
            if (mx > 8 && mx < w - 8) {
                var mhy = baseY + (getHillY(dm) * sc).toNumber();
                dc.setColor(cols[mi], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(mx - 1, mhy - 10, 2, 10);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawText(mx, mhy - 22, Graphics.FONT_XTINY, labs[mi] + dm.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden function drawInrun(dc, w, h) {
        drawMountains(dc, w, h);

        var rampTopX = w * 15 / 100;
        var rampTopY = h * 12 / 100;
        var rampBotX = w * 58 / 100;
        var rampBotY = h * 68 / 100;
        var launchX = rampBotX + w * 14 / 100;
        var launchY = rampBotY - h * 10 / 100;

        dc.setColor(0xC0D8EE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [rampTopX - 20, rampTopY + 5],
            [rampBotX + 25, rampBotY],
            [w, rampBotY - 5],
            [w, h], [0, h],
            [0, rampTopY + 20]
        ]);
        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [rampTopX - 18, rampTopY],
            [rampBotX + 22, rampBotY - 3],
            [w, rampBotY - 8],
            [w, rampBotY - 5],
            [rampBotX + 25, rampBotY],
            [rampTopX - 20, rampTopY + 5]
        ]);

        dc.setColor(0x556688, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var i = 0; i < 10; i++) {
            var lx = rampTopX + (rampBotX - rampTopX) * i / 10;
            var ly = rampTopY + (rampBotY - rampTopY) * i / 10;
            dc.drawLine(lx - 12, ly + 3, lx + 12, ly + 3);
        }

        dc.setColor(0x3355AA, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(rampTopX, rampTopY, rampBotX, rampBotY);
        dc.setPenWidth(1);

        dc.setColor(0x4466BB, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(rampBotX, rampBotY, launchX, launchY);
        dc.setPenWidth(1);

        dc.setColor(0x446688, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(rampTopX - 4, rampTopY - 20, 8, 22);
        dc.setColor(0xDD3333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(rampTopX - 6, rampTopY - 22, 12, 4);

        var progress = _inrunX / 40.0;
        if (progress > 1.0) { progress = 1.0; }
        var px = rampTopX + (rampBotX - rampTopX) * progress;
        var py = rampTopY + (rampBotY - rampTopY) * progress;

        if (progress > 0.1) {
            dc.setColor(0xAABBDD, Graphics.COLOR_TRANSPARENT);
            var trailLen = (progress * 25).toNumber();
            for (var t = 0; t < trailLen; t++) {
                var tp = progress - t.toFloat() / 60.0;
                if (tp < 0.0) { break; }
                var tx = rampTopX + (rampBotX - rampTopX) * tp;
                var ty = rampTopY + (rampBotY - rampTopY) * tp;
                dc.fillRectangle(tx.toNumber(), ty.toNumber() - 8, 1, 1);
            }
        }

        drawJumperSprite(dc, px.toNumber(), py.toNumber() - 10, _jumperIdx, false, 0.0);

        drawCrowd(dc, w, h);

        var barX = w * 82 / 100;
        var barY = h * 15 / 100;
        var barH = h * 55 / 100;
        var barW = 12;
        dc.setColor(0x0A0E1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX - 2, barY - 2, barW + 4, barH + 4);
        dc.setColor(0x1A1A35, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, barH);

        var sweetT = 35;
        var sweetB = 68;
        var sy0 = barY + barH - (barH * sweetB / 100);
        var sy1 = barY + barH - (barH * sweetT / 100);
        dc.setColor(0x113322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, sy0, barW, sy1 - sy0);

        var fillH = barH * _speedBarTick / 100;
        var c = 0x22FF88;
        if (_speedBarTick > 75) { c = 0xFF4433; }
        else if (_speedBarTick > sweetB) { c = 0xFFBB22; }
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY + barH - fillH, barW, fillH);

        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(barX - 1, sy0 - 1, barW + 2, sy1 - sy0 + 2);

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barX + barW / 2, barY - 16, Graphics.FONT_XTINY, "SPD", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x667788, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 88 / 100, Graphics.FONT_XTINY, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawTakeoff(dc, w, h) {
        drawMountains(dc, w, h);

        var rampBotX = w * 58 / 100;
        var rampBotY = h * 68 / 100;
        var launchX = rampBotX + w * 14 / 100;
        var launchY = rampBotY - h * 10 / 100;

        dc.setColor(0xC0D8EE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [0, rampBotY - 5],
            [rampBotX + 25, rampBotY],
            [w, rampBotY - 5],
            [w, h], [0, h]
        ]);
        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [0, rampBotY - 10],
            [rampBotX + 22, rampBotY - 3],
            [w, rampBotY - 8],
            [w, rampBotY - 5],
            [rampBotX + 25, rampBotY],
            [0, rampBotY - 5]
        ]);

        dc.setColor(0x3355AA, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(w * 15 / 100, h * 12 / 100, rampBotX, rampBotY);
        dc.drawLine(rampBotX, rampBotY, launchX, launchY);
        dc.setPenWidth(1);

        var shake = (_takeoffTick % 3 < 2) ? 2 : -2;
        drawJumperSprite(dc, launchX + shake, launchY - 10, _jumperIdx, false, 0.0);

        for (var i = 0; i < 5; i++) {
            dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
            var px2 = launchX - 4 - i * 3 + (Math.rand().abs() % 3);
            var py2 = launchY - 5 + (Math.rand().abs() % 8);
            dc.fillCircle(px2, py2, 2);
        }

        drawCrowd(dc, w, h);

        if (_takeoffFlashTicks > 0) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w, h * _takeoffFlashTicks / 10);
        }

        var perfect = (_takeoffTick >= 6 && _takeoffTick <= 10);
        var good = (_takeoffTick >= 4 && _takeoffTick <= 13);
        dc.setColor(perfect ? 0x22FF88 : (good ? 0xFFBB22 : 0xFF4433), Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 18 / 100, Graphics.FONT_MEDIUM, "JUMP!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x667788, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 30 / 100, Graphics.FONT_XTINY, "Tilt wrist to fly!", Graphics.TEXT_JUSTIFY_CENTER);

        var barW = w * 60 / 100;
        var barX = (w - barW) / 2;
        var barY2 = h * 86 / 100;
        dc.setColor(0x0A0E1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX - 2, barY2 - 2, barW + 4, 10);
        dc.setColor(0x1A1A35, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY2, barW, 6);

        var sweetL = barX + barW * 30 / 100;
        var sweetR = barX + barW * 50 / 100;
        dc.setColor(0x113322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sweetL, barY2, sweetR - sweetL, 6);
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(sweetL - 1, barY2 - 1, sweetR - sweetL + 2, 8);

        var markerX = barX + barW * _takeoffTick / 20;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(markerX - 2, barY2 - 3, 4, 12);
    }

    hidden function drawFlightScene(dc, w, h) {
        var baseY = h * 42 / 100;
        var cx = w * 28 / 100;
        var sc = hillScreenScale();
        var speed = Math.sqrt(_flightVx * _flightVx + _flightVy * _flightVy);

        var jy = baseY + (_flightY * sc).toNumber() - 8;
        updateFlightFx(cx, jy, speed);

        var shx = _screenShakeX;
        var shy = _screenShakeY;

        drawSky(dc, w, h);
        drawMountains(dc, w, h);
        drawSnow(dc, w, h);

        if (speed > 3.5) {
            var nlines = ((speed - 3.5) * 4.0).toNumber();
            if (nlines > 10) { nlines = 10; }
            for (var sl = 0; sl < nlines; sl++) {
                var slx = (sl * 37 + _tick * 13) % w;
                var sly = h * 20 / 100 + (sl * 71 + _tick * 5) % (h * 50 / 100);
                var slen = 8 + (speed * 2.5).toNumber();
                if (slen > 35) { slen = 35; }
                var lc = (sl % 2 == 0) ? 0x4466AA : 0x556688;
                dc.setColor(lc, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(slx + shx, sly + shy, slx + slen + shx, sly + shy);
            }
        }

        var groundTopY = h;
        for (var i = 0; i < 138; i++) {
            var d1 = i.toFloat() * 3.0;
            var d2 = (i + 1).toFloat() * 3.0;
            var sx1 = cx + ((d1 - _distance) * sc).toNumber() + shx;
            var sx2 = cx + ((d2 - _distance) * sc).toNumber() + shx;
            if (sx2 < -5 || sx1 > w + 5) { continue; }

            var hy1 = baseY + (getHillY(d1) * sc).toNumber() + shy;
            var hy2 = baseY + (getHillY(d2) * sc).toNumber() + shy;

            dc.setColor(0xC0D8EE, Graphics.COLOR_TRANSPARENT);
            if (hy1 < h + 5 || hy2 < h + 5) {
                var topY = hy1 < hy2 ? hy1 : hy2;
                if (topY < groundTopY) { groundTopY = topY; }
                dc.fillRectangle(sx1, topY, sx2 - sx1 + 2, h - topY + 1);
            }

            dc.setColor(0xEEF4FF, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(sx1, hy1, sx2, hy2);
            dc.setPenWidth(1);

            dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
            if (hy1 < h && hy1 + 6 < h) {
                dc.fillRectangle(sx1, hy1 + 3, sx2 - sx1 + 1, 1);
            }
        }

        dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
        if (groundTopY < h) {
            for (var dx = 0; dx < w; dx += 6) {
                var dotY = groundTopY + 8 + (dx * 3) % 12;
                if (dotY < h) {
                    dc.fillRectangle(dx + shx, dotY + shy, 1, 1);
                }
            }
        }

        drawTreesAlongHill(dc, w, h, cx + shx, baseY + shy);

        for (var m = 20; m <= 380; m += 20) {
            var mx = cx + ((m.toFloat() - _distance) * sc).toNumber() + shx;
            if (mx > 3 && mx < w - 3) {
                var mhy = baseY + (getHillY(m.toFloat()) * sc).toNumber() + shy;
                var mc = 0xDD4444;
                if (m % 50 == 0) { mc = 0xFF6622; }
                dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
                var flagH = (m % 50 == 0) ? 12 : 8;
                dc.fillRectangle(mx, mhy - flagH, 2, flagH);
                if (m % 50 == 0) {
                    dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(mx + 1, mhy - flagH - 12, Graphics.FONT_XTINY, "" + m, Graphics.TEXT_JUSTIFY_CENTER);
                }
            }
        }

        var kx = cx + ((_kPointDist - _distance) * sc).toNumber() + shx;
        if (kx > -5 && kx < w + 5) {
            var ky = baseY + (getHillY(_kPointDist) * sc).toNumber() + shy;
            dc.setColor(0x22DD44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(kx - 1, ky - 16, 3, 16);
            dc.fillRectangle(kx - 4, ky - 16, 9, 3);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(kx, ky - 28, Graphics.FONT_XTINY, "K" + _kPointDist.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
        }
        var hsx = cx + ((_hsDist - _distance) * sc).toNumber() + shx;
        if (hsx > -5 && hsx < w + 5) {
            var hsy = baseY + (getHillY(_hsDist) * sc).toNumber() + shy;
            dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(hsx - 1, hsy - 16, 3, 16);
            dc.fillRectangle(hsx - 4, hsy - 16, 9, 3);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(hsx, hsy - 28, Graphics.FONT_XTINY, "HS" + _hsDist.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
        }

        var petScreenY = baseY + (_flightY * sc).toNumber() + shy;
        var jx2 = cx + shx;
        var jy2 = petScreenY - 8;

        pushTrail(jx2.toFloat(), jy2.toFloat());
        drawFlightTrail(dc);
        drawFlightFx(dc, w, h, jx2, jy2, speed);

        var altAboveHill = getHillY(_distance) - _flightY;
        if (altAboveHill < 0.0) { altAboveHill = 0.0; }

        if (altAboveHill > 3.0) {
            var groundSy = baseY + (getHillY(_distance) * sc).toNumber() + shy;
            dc.setColor(0x445588, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(jx2, jy2 + 14, jx2, groundSy);
            dc.setColor(0x445588, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(jx2, groundSy, 3);
        }

        drawJumperSprite(dc, jx2, jy2, _jumperIdx, true, _flightLean);

        dc.setColor(0x0A0E1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 22);
        dc.setColor(0x182030, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 22, w, 2);

        var distC = 0xDDEEFF;
        if (_distance > _hsDist) { distC = 0xFF4444; }
        else if (_distance > _kPointDist) { distC = 0x44FF88; }
        dc.setColor(distC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 2, Graphics.FONT_MEDIUM, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        if (_distance > _hsDist && _tick % 6 < 3) {
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, 1, Graphics.FONT_MEDIUM, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var accelPct = accelMag.toFloat() / 6000.0;
        if (accelPct > 1.0) { accelPct = 1.0; }
        var acBarW = 30;
        var acBarX = 4;
        var acBarY = 5;
        dc.setColor(0x1A2244, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(acBarX, acBarY, acBarW, 4);
        var acC = accelPct > 0.5 ? 0x22FFAA : (accelPct > 0.2 ? 0xFFCC22 : 0xFF5533);
        dc.setColor(acC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(acBarX, acBarY, (acBarW * accelPct).toNumber(), 4);
        dc.setColor(0x667788, Graphics.COLOR_TRANSPARENT);
        dc.drawText(acBarX + acBarW / 2, acBarY + 5, Graphics.FONT_XTINY, "LIFT", Graphics.TEXT_JUSTIFY_CENTER);

        var wStr = _windCurrent;
        if (wStr < 0) { wStr = -wStr; }
        var wDir = _windCurrent >= 0 ? ">" : "<";
        var wC = wStr > 1.5 ? 0xFF6644 : 0x66AACC;
        dc.setColor(wC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 4, 4, Graphics.FONT_XTINY, wDir + wStr.toNumber() + "." + ((wStr * 10).toNumber() % 10), Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(0x0A0E1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h - 20, w, 20);
        dc.setColor(0x182030, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h - 20, w, 2);

        var leanPct = ((_flightLean + 25.0) / 70.0 * 100.0).toNumber();
        if (leanPct < 0) { leanPct = 0; }
        if (leanPct > 100) { leanPct = 100; }
        var lBarW = w - 12;
        var lBarX = 6;
        var lBarY = h - 12;
        dc.setColor(0x1A2244, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lBarX, lBarY, lBarW, 5);
        var sweetL = lBarW * 28 / 100;
        var sweetR = lBarW * 62 / 100;
        dc.setColor(0x113322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lBarX + sweetL, lBarY, sweetR - sweetL, 5);
        var mkX = lBarX + lBarW * leanPct / 100;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mkX - 2, lBarY - 2, 4, 9);
        dc.setColor(0x667788, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lBarX, lBarY - 2, Graphics.FONT_XTINY, "LEAN", Graphics.TEXT_JUSTIFY_LEFT);

        if (speed > 6.0) {
            dc.setColor(0x22DDFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 18, Graphics.FONT_XTINY, "SOARING!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (speed > 4.5) {
            dc.setColor(0x44AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 18, Graphics.FONT_XTINY, "FLYING", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (speed > 3.0) {
            dc.setColor(0xCCBB66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 18, Graphics.FONT_XTINY, "GLIDING", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0xFF5544, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 18, Graphics.FONT_XTINY, "FALLING!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawLanding(dc, w, h) {
        var baseY = h * 42 / 100;
        var cx = w * 28 / 100;
        var sc = hillScreenScale();

        drawSky(dc, w, h);
        drawMountains(dc, w, h);

        for (var i = 0; i < 138; i++) {
            var d1 = i.toFloat() * 3.0;
            var d2 = (i + 1).toFloat() * 3.0;
            var sx1 = cx + ((d1 - _distance) * sc).toNumber();
            var sx2 = cx + ((d2 - _distance) * sc).toNumber();
            if (sx2 < -5 || sx1 > w + 5) { continue; }
            var hy1 = baseY + (getHillY(d1) * sc).toNumber();
            var hy2 = baseY + (getHillY(d2) * sc).toNumber();
            dc.setColor(0xC0D8EE, Graphics.COLOR_TRANSPARENT);
            if (hy1 < h + 5 || hy2 < h + 5) {
                var topY = hy1 < hy2 ? hy1 : hy2;
                dc.fillRectangle(sx1, topY, sx2 - sx1 + 2, h - topY + 1);
            }
            dc.setColor(0xEEF4FF, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(sx1, hy1, sx2, hy2);
            dc.setPenWidth(1);
        }

        drawTreesAlongHill(dc, w, h, cx, baseY);
        drawHillMarkers(dc, cx, w, h, baseY);

        var hillYAtDist = getHillY(_distance);
        var petY = baseY + (hillYAtDist * sc).toNumber() - 10;

        if (_landTick < 10) {
            dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 8; sp++) {
                var spx = cx - 10 + (Math.rand().abs() % 20);
                var spy = petY + 5 + (Math.rand().abs() % 8);
                dc.fillCircle(spx, spy, 2 + Math.rand().abs() % 2);
            }
        }

        var shake = (_landTick < 8) ? ((_landTick % 3 < 2) ? 3 : -3) : 0;
        drawJumperSprite(dc, cx + shake, petY, _jumperIdx, false, 0.0);

        drawCrowd(dc, w, h);
        drawSnow(dc, w, h);

        dc.setColor(0x0A0E1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 22);
        dc.setColor(_landGood ? 0x22FF88 : 0xFFBB22, Graphics.COLOR_TRANSPARENT);
        var landText = _landGood ? "TELEMARK!" : "LANDED";
        dc.drawText(w / 2, 2, Graphics.FONT_MEDIUM, landText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x0A0E1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h - 28, w, 28);
        dc.setColor(0x182030, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h - 28, w, 2);
        dc.setColor(0xFFFF66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h - 25, Graphics.FONT_MEDIUM, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawJumperSprite(dc, x, y, idx, flying, leanDeg) {
        var bodyC = _jumperColors[idx];
        var accC = _jumperAccents[idx];
        var lean = leanDeg;
        if (lean > 40.0) { lean = 40.0; }
        if (lean < -22.0) { lean = -22.0; }
        var offX = (lean * 0.18).toNumber();
        var offY = flying ? (lean * -0.06).toNumber() : 0;

        if (flying) {
            dc.setColor(accC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + offX, y + offY, 9);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + offX, y + offY, 7);

            dc.setColor(0x2A2A3A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + offX + 3, y + offY - 6, 5);
            dc.setColor(0xDDDDEE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + offX + 3, y + offY - 6, 4);
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX, y + offY - 8, 7, 2);

            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            var armLen = 12 + (lean * 0.15).toNumber();
            if (armLen < 6) { armLen = 6; }
            dc.fillRectangle(x + offX - armLen, y + offY - 2, armLen, 3);
            dc.fillRectangle(x + offX + 7, y + offY - 2, armLen, 3);
            dc.setColor(0xFFDDBB, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX - armLen - 2, y + offY - 2, 3, 3);
            dc.fillRectangle(x + offX + 7 + armLen - 1, y + offY - 2, 3, 3);

            dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX - 4, y + offY + 7, 9, 3);
            dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX - 5, y + offY + 10, 11, 2);

            dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX - 8, y + offY + 12, 17, 2);
            dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX - 9, y + offY + 13, 2, 2);
            dc.fillRectangle(x + offX + 8, y + offY + 13, 2, 2);

            var sway = (_tick % 6 < 3) ? 1 : -1;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX + 1, y + offY - 5, 2, 2);
            dc.fillRectangle(x + offX + 4, y + offY - 5, 2, 2);
            dc.setColor(0x111118, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX + 1 + sway, y + offY - 4, 1, 1);
            dc.fillRectangle(x + offX + 4 + sway, y + offY - 4, 1, 1);
        } else {
            dc.setColor(0x2A2A3A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - 8, 5);
            dc.setColor(0xDDDDEE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - 8, 4);

            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 5, y - 3, 10, 8);
            dc.setColor(accC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 4, y - 2, 8, 6);

            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 8, y - 1, 4, 3);
            dc.fillRectangle(x + 4, y - 1, 4, 3);

            dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 4, y + 5, 8, 3);
            dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 5, y + 8, 4, 2);
            dc.fillRectangle(x + 1, y + 8, 4, 2);

            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 2, y - 7, 2, 2);
            dc.fillRectangle(x + 1, y - 7, 2, 2);
            dc.setColor(0x111118, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 2, y - 6, 1, 1);
            dc.fillRectangle(x + 2, y - 6, 1, 1);
        }
    }

    hidden function drawGameHud(dc, w, h) {
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        var rtxt = "R" + _currentRound + "/2";
        dc.drawText(w / 2, 2, Graphics.FONT_XTINY, _jumperNames[_jumperIdx] + " #" + _jumpNum + "  " + rtxt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawSelect(dc, w, h) {
        dc.setColor(0x0A0E1A, 0x0A0E1A);
        dc.clear();

        dc.setColor(0x182030, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 30 / 100, w, h * 50 / 100);

        dc.setColor(0x22DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_MEDIUM, "BITOCHI JUMP", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x1188AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + 1, h * 5 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI JUMP", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 19 / 100, Graphics.FONT_XTINY, "Choose jumper", Graphics.TEXT_JUSTIFY_CENTER);

        var cy = h * 40 / 100;
        drawJumperSprite(dc, w / 2, cy, _jumperIdx, false, 0.0);

        dc.setColor(_jumperColors[_jumperIdx], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, cy + 18, Graphics.FONT_SMALL, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, cy + 36, Graphics.FONT_XTINY, _jumperDescs[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 - w * 30 / 100, cy, Graphics.FONT_SMALL, "<", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2 + w * 30 / 100, cy, Graphics.FONT_SMALL, ">", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_XTINY, "2 rounds / 5 jumpers", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x22DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 87 / 100, Graphics.FONT_XTINY, "SEL to start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function rankIndicesByScore() {
        var order = new [NUM_JUMPERS];
        for (var i = 0; i < NUM_JUMPERS; i++) {
            order[i] = i;
        }
        for (var a = 0; a < NUM_JUMPERS - 1; a++) {
            for (var b = a + 1; b < NUM_JUMPERS; b++) {
                if (_cumScores[order[b]] > _cumScores[order[a]]) {
                    var tmp = order[a];
                    order[a] = order[b];
                    order[b] = tmp;
                }
            }
        }
        return order;
    }

    hidden function drawRoundStandings(dc, w, h) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 6 / 100, Graphics.FONT_MEDIUM, "ROUND 1 STANDINGS", Graphics.TEXT_JUSTIFY_CENTER);

        var ord = rankIndicesByScore();
        for (var r = 0; r < NUM_JUMPERS; r++) {
            var idx = ord[r];
            var yy = h * (20 + r * 14) / 100;
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 10 / 100, yy, Graphics.FONT_XTINY, "" + (r + 1), Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(_jumperColors[idx], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 22 / 100, yy, Graphics.FONT_XTINY, _jumperNames[idx], Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 58 / 100, yy, Graphics.FONT_XTINY, _cumDistances[idx].toNumber() + "m", Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 78 / 100, yy, Graphics.FONT_XTINY, "" + _cumScores[idx].toNumber(), Graphics.TEXT_JUSTIFY_LEFT);
        }

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 88 / 100, Graphics.FONT_XTINY, "SEL  Round 2", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawScoreScreen(dc, w, h) {
        var idx = _resultJumperIdx;
        var dist = _lastJumpDist;
        var pts = _lastJumpPoints;
        var name = _jumperNames[idx];

        dc.setColor(_jumperColors[idx], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 8 / 100, Graphics.FONT_SMALL, name, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 22 / 100, Graphics.FONT_MEDIUM, dist.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 38 / 100, Graphics.FONT_XTINY, "This jump: " + pts.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 48 / 100, Graphics.FONT_XTINY, "Total: " + _cumScores[idx].toNumber(), Graphics.TEXT_JUSTIFY_CENTER);

        var grade;
        if (dist >= 220.0) { grade = "HILL RECORD!"; }
        else if (dist >= 175.0) { grade = "MONSTER JUMP!"; }
        else if (dist >= 140.0) { grade = "EXCELLENT!"; }
        else if (dist >= 100.0) { grade = "GREAT!"; }
        else if (dist >= 60.0) { grade = "GOOD"; }
        else { grade = "SHORT"; }
        dc.setColor(0x44FFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 60 / 100, Graphics.FONT_SMALL, grade, Graphics.TEXT_JUSTIFY_CENTER);

        if (!_showRoundStandings && _jumpOrderSlot < NUM_JUMPERS - 1) {
            var nextIdx = (_compStartIdx + _jumpOrderSlot + 1) % NUM_JUMPERS;
            dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_XTINY, "Next: " + _jumperNames[nextIdx], Graphics.TEXT_JUSTIFY_CENTER);
        } else if (!_showRoundStandings && _currentRound == 1 && _jumpOrderSlot >= NUM_JUMPERS - 1) {
            dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_XTINY, "End R1  see ranking", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (!_showRoundStandings && _currentRound == 2 && _jumpOrderSlot >= NUM_JUMPERS - 1) {
            dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_XTINY, "Final results next", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 86 / 100, Graphics.FONT_XTINY, "Press to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFinal(dc, w, h) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_MEDIUM, "FINAL (2 ROUNDS)", Graphics.TEXT_JUSTIFY_CENTER);

        var ord = rankIndicesByScore();
        for (var r = 0; r < NUM_JUMPERS; r++) {
            var idx = ord[r];
            var yy = h * (16 + r * 15) / 100;

            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 8 / 100, yy, Graphics.FONT_XTINY, "" + (r + 1), Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(_jumperColors[idx], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 18 / 100, yy, Graphics.FONT_XTINY, _jumperNames[idx], Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 52 / 100, yy, Graphics.FONT_XTINY, _cumDistances[idx].toNumber() + "m", Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 78 / 100, yy, Graphics.FONT_XTINY, "" + _cumScores[idx].toNumber(), Graphics.TEXT_JUSTIFY_LEFT);
        }

        var bestIdx = ord[0];
        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_SMALL, _jumperNames[bestIdx] + " WINS!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 90 / 100, Graphics.FONT_XTINY, "Press to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
