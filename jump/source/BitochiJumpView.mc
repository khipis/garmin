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

        _kPointDist = 88.0;
        _hsDist = 102.0;

        _compStartIdx = 0;
        _jumpOrderSlot = 0;
        _currentRound = 1;
        _showRoundStandings = false;
        _windBase = 0.0;
        _windCurrent = 0.0;
        _windGustPhase = 0.0;
        _takeoffFlashTicks = 0;

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

        for (var t = 0; t < TRAIL_LEN; t++) {
            _trailAge[t] = 999;
        }

        buildHill();
    }

    hidden function buildHill() {
        _hillProfile = new [72];
        for (var i = 0; i < 72; i++) {
            var x = i.toFloat();
            if (i < 8) {
                _hillProfile[i] = -x * 3.2;
            } else if (i < 18) {
                _hillProfile[i] = -25.6 - (x - 8.0) * 2.1;
            } else if (i < 28) {
                _hillProfile[i] = -46.6 - (x - 18.0) * 1.1;
            } else if (i < 38) {
                _hillProfile[i] = -57.6 - (x - 28.0) * 0.55;
            } else if (i < 52) {
                _hillProfile[i] = -63.1 - (x - 38.0) * 0.22;
            } else if (i < 62) {
                _hillProfile[i] = -66.18 - (x - 52.0) * 0.08;
            } else {
                _hillProfile[i] = -66.98 + (x - 62.0) * 0.12;
            }
        }
    }

    hidden function getHillY(dist) {
        var idx = (dist / 3.0).toNumber();
        if (idx < 0) { idx = 0; }
        if (idx >= 71) { return _hillProfile[71]; }
        var frac = dist / 3.0 - idx.toFloat();
        return _hillProfile[idx] * (1.0 - frac) + _hillProfile[idx + 1] * frac;
    }

    hidden function hillScreenScale() {
        var z = _cameraZoom;
        if (z < 0.85) { z = 0.85; }
        if (z > 1.45) { z = 1.45; }
        return 1.15 * z;
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
        var baseSpeed = 4.0 + speedFactor * 4.2 + _takeoffQuality * 3.2;
        var jumpAngle = 18.0 + _takeoffQuality * 18.0;
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
        var gravity = 0.118;
        var liftBase = 0.018;

        var lr = _statLeanRate[_jumperIdx];
        _flightLean += _leanInput * 0.38 * lr;
        if (_flightLean > 38.0) { _flightLean = 38.0; }
        if (_flightLean < -22.0) { _flightLean = -22.0; }

        if (_leanInput == 0) {
            var dec = 0.18 * lr;
            if (_flightLean > dec) { _flightLean -= dec; }
            else if (_flightLean < -dec) { _flightLean += dec; }
            else { _flightLean = 0.0; }
        }

        _windGustPhase += 0.14;
        var gust = Math.sin(_windGustPhase) * 0.55 + Math.sin(_windGustPhase * 2.3) * 0.22;
        if ((_tick + _jumperIdx * 7) % 17 == 0) {
            gust += ((Math.rand().abs() % 7).toFloat() - 3.0) / 10.0;
        }
        _windCurrent = _windBase + gust;
        if (_windCurrent > 2.2) { _windCurrent = 2.2; }
        if (_windCurrent < -2.2) { _windCurrent = -2.2; }

        var speed = Math.sqrt(_flightVx * _flightVx + _flightVy * _flightVy);
        _cameraZoom = 1.0 + speed * 0.038;
        if (_cameraZoom > 1.42) { _cameraZoom = 1.42; }

        var forwardLean = _flightLean;
        if (forwardLean < 0.0) { forwardLean = 0.0; }

        var lm = _statLiftMul[_jumperIdx];
        var dm = _statDragLeanMul[_jumperIdx];
        var liftFromLean = forwardLean * 0.0028 * lm;
        var dragFromLean = forwardLean * 0.0011 * dm;

        var liftForce = (liftBase + liftFromLean) * lm;
        if (liftForce < 0.0) { liftForce = 0.0; }

        var drag = 0.0026 * speed * speed + dragFromLean * speed;

        var lift = liftForce * speed;

        _flightVy = _flightVy + gravity - lift;
        _flightVx = _flightVx - drag * 0.32 + _windCurrent * 0.0062;

        var hillY = getHillY(_distance);
        var relH = hillY - _flightY;
        if (relH < 14.0 && relH > -2.0) {
            var turb = ((Math.rand().abs() % 5).toFloat() - 2.0) * 0.045 * (1.0 - relH / 16.0);
            if (turb < -0.12) { turb = -0.12; }
            if (turb > 0.12) { turb = 0.12; }
            _flightVy += turb;
            _flightVx += turb * 0.35;
        }

        if (_flightVx < 0.85) { _flightVx = 0.85; }

        _flightX += _flightVx;
        _flightY += _flightVy;

        _distance = _flightX * 0.82;

        _flightAngle = _flightAngle * 0.94 + _flightLean * 0.06;

        hillY = getHillY(_distance);
        var screenY = _flightY;

        if (screenY >= hillY + 5.0) {
            var landingSpeed = Math.sqrt(_flightVx * _flightVx + _flightVy * _flightVy);
            _landGood = (_flightLean >= 5.0 && _flightLean <= 32.0 && landingSpeed < 12.5);

            gameState = JS_LANDING;
            _landTick = 0;

            var dist = _distance;
            if (dist < 0.0) { dist = 0.0; }

            var styleScore = _takeoffQuality * 30.0;
            if (_landGood) { styleScore += 20.0; }
            var leanBonus = _flightLean > 10.0 ? (_flightLean - 10.0) * 0.52 : 0.0;
            styleScore += leanBonus;
            if (styleScore > 62.0) { styleScore = 62.0; }

            var totalScore = dist + styleScore;
            if (totalScore > 220.0) { totalScore = 220.0; }

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
        var par1 = (_distance * 0.08).toNumber();
        var par2 = (_distance * 0.15).toNumber();
        var par3 = (_distance * 0.22).toNumber();

        dc.setColor(0x1A2038, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, h * 55 / 100], [w * 20 / 100 - par3, h * 28 / 100], [w * 45 / 100 - par3, h * 32 / 100], [w, h * 50 / 100], [w, h], [0, h]]);

        dc.setColor(0x252B45, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, h * 52 / 100], [w * 25 / 100 - par2, h * 35 / 100], [w * 55 / 100 - par2, h * 30 / 100], [w, h * 48 / 100], [w, h], [0, h]]);

        dc.setColor(0x303650, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, h * 48 / 100], [w * 30 / 100 - par1, h * 38 / 100], [w * 60 / 100 - par1, h * 34 / 100], [w, h * 46 / 100], [w, h], [0, h]]);
    }

    hidden function drawTreesAlongHill(dc, w, h, cx, baseY) {
        var sc = hillScreenScale();
        var spots = [12, 22, 35, 48, 63, 78, 95, 118, 140, 165];
        for (var ti = 0; ti < 10; ti++) {
            var dm = spots[ti].toFloat();
            var sx = worldToScreenX(cx, dm);
            if (sx < -8 || sx > w + 8) { continue; }
            var hy = baseY + (getHillY(dm) * sc).toNumber();
            dc.setColor(0x2A4A2A, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, hy - 2], [sx - 3, hy + 4], [sx + 3, hy + 4]]);
            dc.setColor(0x1A351A, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, hy - 4], [sx - 2, hy], [sx + 2, hy]]);
        }
    }

    hidden function drawCrowd(dc, w, h) {
        var rowY = h - 6;
        var seed = 17;
        for (var r = 0; r < 3; r++) {
            for (var c = 0; c < 24; c++) {
                var px = 4 + c * w / 24 + (r * 3) % 5;
                var py = rowY - r * 4;
                seed = (seed * 13 + c + r * 7) % 200;
                var pal = [0x3366CC, 0xCC3333, 0xEEEE22, 0xAA44AA, 0x44AAAA, 0xFFFFFF];
                dc.setColor(pal[seed % 6], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(px, py, 2, 2);
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
            if (_trailAge[i] > 60) { continue; }
            var age = _trailAge[i];
            if (age > 40) { continue; }
            var br = 40 - age;
            var col = 0xAABBDD;
            if (br < 10) { col = 0x556688; }
            else if (br < 22) { col = 0x778899; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var tr = 1 + (i % 2);
            dc.fillCircle(_trailX[i].toNumber(), _trailY[i].toNumber(), tr);
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
        dc.setColor(0x152545, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h / 3);
        dc.setColor(0x1E3358, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h / 3, w, h / 6);
        dc.setColor(0x284060, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h / 2, w, h / 8);

        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 86 / 100, h * 9 / 100, 5);
        dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 84 / 100, h * 11 / 100, 3);

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 12 / 100, h * 7 / 100, 2);
        dc.fillCircle(w * 48 / 100, h * 5 / 100, 2);
        dc.fillCircle(w * 68 / 100, h * 14 / 100, 1);
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
        var groundY = h * 70 / 100;

        drawMountains(dc, w, h);

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, groundY, w, h - groundY);

        var rampStartX = w * 15 / 100;
        var rampEndX = w * 65 / 100;
        var rampTopY = h * 30 / 100;

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

        drawJumperSprite(dc, px.toNumber(), py.toNumber() - 10, _jumperIdx, false, 0.0);

        drawCrowd(dc, w, h);

        var barX = w * 74 / 100;
        var barY = h * 22 / 100;
        var barH = h * 52 / 100;
        var barW = 12;
        dc.setColor(0x1A1A30, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX - 1, barY - 1, barW + 2, barH + 2);
        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, barH);

        var sweetT = 35;
        var sweetB = 68;
        var sy0 = barY + barH - (barH * sweetB / 100);
        var sy1 = barY + barH - (barH * sweetT / 100);
        dc.setColor(0x224422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, sy0, barW, sy1 - sy0);

        var fillH = barH * _speedBarTick / 100;
        var c = 0x44FF44;
        if (_speedBarTick > 75) { c = 0xFF6644; }
        else if (_speedBarTick > sweetB) { c = 0xFFCC22; }
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY + barH - fillH, barW, fillH);

        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(barX - 1, sy0 - 1, barW + 2, sy1 - sy0 + 2);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barX + barW / 2, barY - 14, Graphics.FONT_XTINY, "SPD", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(barX + barW / 2, barY + barH + 4, Graphics.FONT_XTINY, "SWEET", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawTakeoff(dc, w, h) {
        var groundY = h * 70 / 100;
        drawMountains(dc, w, h);

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, groundY, w, h - groundY);

        var rampEndX = w * 65 / 100;
        var rampTopY = h * 30 / 100;
        dc.setColor(0x446688, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(w * 15 / 100, groundY, rampEndX, rampTopY);
        dc.setPenWidth(1);

        var shake = (_takeoffTick % 4 < 2) ? 2 : -2;
        drawJumperSprite(dc, rampEndX + shake, rampTopY - 10, _jumperIdx, false, 0.0);

        drawCrowd(dc, w, h);

        if (_takeoffFlashTicks > 0) {
            var fl = _takeoffFlashTicks;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w, h * fl / 10);
        }

        var perfect = (_takeoffTick >= 6 && _takeoffTick <= 10);
        var good = (_takeoffTick >= 4 && _takeoffTick <= 13);
        dc.setColor(perfect ? 0x44FF44 : (good ? 0xFFCC22 : 0xFF6644), Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_MEDIUM, "JUMP!", Graphics.TEXT_JUSTIFY_CENTER);

        var barW = w * 52 / 100;
        var barX = (w - barW) / 2;
        var barY2 = h * 88 / 100;
        dc.setColor(0x1A1A30, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX - 1, barY2 - 1, barW + 2, 8);
        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY2, barW, 6);

        var sweetL = barX + barW * 30 / 100;
        var sweetR = barX + barW * 50 / 100;
        dc.setColor(0x226622, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sweetL, barY2, sweetR - sweetL, 6);
        dc.setColor(0xAAFF66, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(sweetL - 1, barY2 - 1, sweetR - sweetL + 2, 8);

        var markerX = barX + barW * _takeoffTick / 20;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(markerX - 2, barY2 - 3, 4, 12);
    }

    hidden function drawFlightScene(dc, w, h) {
        var baseY = h * 75 / 100;
        var cx = w / 2;
        var sc = hillScreenScale();

        drawMountains(dc, w, h);

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, baseY, w, h - baseY);

        for (var i = 0; i < 70; i++) {
            var d1 = i.toFloat() * 3.0;
            var d2 = (i + 1).toFloat() * 3.0;
            var sx1 = worldToScreenX(cx, d1);
            var sx2 = worldToScreenX(cx, d2);
            var hy1 = baseY + (getHillY(d1) * sc).toNumber();
            var hy2 = baseY + (getHillY(d2) * sc).toNumber();

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

        drawTreesAlongHill(dc, w, h, cx, baseY);
        drawHillMarkers(dc, cx, w, h, baseY);

        for (var m = 20; m <= 180; m += 20) {
            var mx = worldToScreenX(cx, m.toFloat());
            if (mx > 10 && mx < w - 10) {
                var mhy = baseY + (getHillY(m.toFloat()) * sc).toNumber();
                dc.setColor(0xAA4444, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(mx - 1, mhy - 6, 2, 6);
                dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
                dc.drawText(mx, mhy - 18, Graphics.FONT_XTINY, "" + m, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        var petScreenY = baseY + (_flightY * sc).toNumber();
        var jx = cx;
        var jy = petScreenY - 6;

        pushTrail(jx.toFloat(), jy.toFloat());
        drawFlightTrail(dc);

        drawJumperSprite(dc, jx, jy, _jumperIdx, true, _flightLean);

        drawCrowd(dc, w, h);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 8 / 100, Graphics.FONT_SMALL, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        drawWindArrows(dc, w, h);

        var leanPct = ((_flightLean + 22.0) / 60.0 * 100.0).toNumber();
        if (leanPct < 0) { leanPct = 0; }
        if (leanPct > 100) { leanPct = 100; }
        var lBarY = h * 32 / 100;
        var lBarH = h * 38 / 100;
        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(5, lBarY, 8, lBarH);

        var sweetTop = lBarY + lBarH * 12 / 100;
        var sweetBot = lBarY + lBarH * 58 / 100;
        dc.setColor(0x224422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(5, sweetTop, 8, sweetBot - sweetTop);

        var markerY = lBarY + lBarH - lBarH * leanPct / 100;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(3, markerY - 1, 12, 3);
        dc.drawText(16, markerY - 8, Graphics.FONT_XTINY, "LEAN", Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function drawLanding(dc, w, h) {
        var baseY = h * 75 / 100;
        var cx = w / 2;
        var sc = hillScreenScale();

        drawMountains(dc, w, h);

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, baseY, w, h - baseY);

        for (var i = 0; i < 70; i++) {
            var d1 = i.toFloat() * 3.0;
            var d2 = (i + 1).toFloat() * 3.0;
            var sx1 = worldToScreenX(cx, d1);
            var sx2 = worldToScreenX(cx, d2);
            var hy1 = baseY + (getHillY(d1) * sc).toNumber();
            var hy2 = baseY + (getHillY(d2) * sc).toNumber();
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

        drawTreesAlongHill(dc, w, h, cx, baseY);
        drawHillMarkers(dc, cx, w, h, baseY);

        var hillYAtDist = getHillY(_distance);
        var petY = baseY + (hillYAtDist * sc).toNumber() - 10;

        var shake = (_landTick < 8) ? ((_landTick % 4 < 2) ? 3 : -3) : 0;
        drawJumperSprite(dc, cx + shake, petY, _jumperIdx, false, 0.0);

        drawCrowd(dc, w, h);

        dc.setColor(_landGood ? 0x44FF44 : 0xFFCC22, Graphics.COLOR_TRANSPARENT);
        var landText = _landGood ? "TELEMARK!" : "LANDED";
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_MEDIUM, landText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 32 / 100, Graphics.FONT_MEDIUM, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawJumperSprite(dc, x, y, idx, flying, leanDeg) {
        var bodyC = _jumperColors[idx];
        var accC = _jumperAccents[idx];
        var lean = leanDeg;
        if (lean > 35.0) { lean = 35.0; }
        if (lean < -20.0) { lean = -20.0; }
        var offX = (lean * 0.12).toNumber();

        dc.setColor(0x2A2A33, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - 7, 7);
        dc.setColor(0xE8E8F0, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - 7, 5);

        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + offX, y, 7);
        dc.setColor(accC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + offX, y, 5);

        var armAy = y - 1 + (flying ? 1 : 0);
        var armBx = 8 + (flying ? 4 : 0);
        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + offX - armBx, armAy - 2, 5, 3);
        dc.fillRectangle(x + offX + armBx - 5, armAy - 2, 5, 3);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + offX - 3, y - 3, 2, 2);
        dc.fillRectangle(x + offX + 1, y - 3, 2, 2);
        dc.setColor(0x111118, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + offX - 3, y - 2, 1, 1);
        dc.fillRectangle(x + offX + 2, y - 2, 1, 1);

        if (flying) {
            dc.setColor(0xDDDDEE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX - 10, y + 5, 20, 3);
            dc.setColor(accC, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x + offX - 9, y + 6, x + offX + 9, y + 6);

            dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX - 11, y + 9, 22, 2);
            dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX - 9, y + 10, 6, 1);
            dc.fillRectangle(x + offX + 3, y + 10, 6, 1);
        } else {
            dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX - 6, y + 8, 12, 2);
            dc.setColor(0x777788, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + offX - 4, y + 9, 3, 1);
            dc.fillRectangle(x + offX + 1, y + 9, 3, 1);
        }
    }

    hidden function drawGameHud(dc, w, h) {
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        var rtxt = "R" + _currentRound + "/2";
        dc.drawText(w / 2, 2, Graphics.FONT_XTINY, _jumperNames[_jumperIdx] + " #" + _jumpNum + "  " + rtxt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawSelect(dc, w, h) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 6 / 100, Graphics.FONT_MEDIUM, "BITOCHI JUMP", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 18 / 100, Graphics.FONT_XTINY, "Choose first jumper", Graphics.TEXT_JUSTIFY_CENTER);

        var cy = h * 42 / 100;
        drawJumperSprite(dc, w / 2, cy, _jumperIdx, false, 0.0);

        dc.setColor(_jumperColors[_jumperIdx], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, cy + 20, Graphics.FONT_SMALL, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, cy + 38, Graphics.FONT_XTINY, _jumperDescs[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 - w * 28 / 100, cy, Graphics.FONT_SMALL, "<", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2 + w * 28 / 100, cy, Graphics.FONT_SMALL, ">", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_XTINY, "2 rounds  5 jumpers", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 86 / 100, Graphics.FONT_XTINY, "SEL to start", Graphics.TEXT_JUSTIFY_CENTER);
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
        if (dist >= 130.0) { grade = "HILL RECORD!"; }
        else if (dist >= 100.0) { grade = "EXCELLENT!"; }
        else if (dist >= 70.0) { grade = "GREAT!"; }
        else if (dist >= 40.0) { grade = "GOOD"; }
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
