using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum { JS_MENU, JS_INRUN, JS_TAKEOFF, JS_FLIGHT, JS_LANDING, JS_SCORE, JS_FINAL }

const NUM_JUMPERS = 6;
const HILL_PTS = 200;

class BitochiJumpView extends WatchUi.View {

    var gameState;
    var accelX;
    var accelY;

    hidden var _w;
    hidden var _h;
    hidden var _timer;
    hidden var _tick;

    hidden var _jumperIdx;
    hidden var _jumperNames;
    hidden var _jumperColors;
    hidden var _jumperAccents;
    hidden var _jumperNat;

    hidden var _hillX;
    hidden var _hillY;
    hidden var _inrunLen;
    hidden var _tableIdx;
    hidden var _kIdx;
    hidden var _hsIdx;
    hidden var _kDist;
    hidden var _hsDist;
    hidden var _venue;
    hidden var _venueNames;
    hidden var _maxSpeed;

    hidden var _posX;
    hidden var _posY;
    hidden var _vx;
    hidden var _vy;
    hidden var _onHill;
    hidden var _speed;
    hidden var _bodyAngle;
    hidden var _skiAngle;

    hidden var _inTakeoffZone;
    hidden var _takeoffWindow;
    hidden var _takeoffQuality;
    hidden var _takeoffFlash;

    hidden var _windBase;
    hidden var _windCurrent;
    hidden var _windPhase;

    hidden var _camX;
    hidden var _camY;

    hidden var _distance;
    hidden var _landTick;
    hidden var _landGood;
    hidden var _landCrash;
    hidden var _landReady;
    hidden var _landReadyTick;
    hidden var _landTapDone;
    hidden var _landQuality;
    hidden var _slideSpeed;

    hidden var _jumpNum;
    hidden var _currentRound;
    hidden var _jumpSlot;
    hidden var _startJumper;

    hidden var _scores;
    hidden var _dists;
    hidden var _cumScores;
    hidden var _cumDists;
    hidden var _lastDist;
    hidden var _lastScore;
    hidden var _bestDist;
    hidden var _showStandings;
    hidden var _judgeScores;

    hidden const SNOW_N = 30;
    hidden var _snowX;
    hidden var _snowY;

    hidden const TRAIL_N = 20;
    hidden var _trailX;
    hidden var _trailY;
    hidden var _trailLife;

    hidden var _shakeX;
    hidden var _shakeY;
    hidden var _shakeTick;

    hidden const CROWD_N = 16;
    hidden var _crowdX;
    hidden var _crowdC;
    hidden var _crowdJump;

    hidden var _crowdCheer;
    hidden var _passedK;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _tick = 0; accelX = 0; accelY = 0;

        _jumperNames = ["Stoch", "Kraft", "Lindvik", "Kobayas", "Prevc", "Granerud"];
        _jumperNat = ["POL", "AUT", "NOR", "JPN", "SLO", "NOR"];
        _jumperColors = [0xFFCC22, 0xFF4444, 0x2266DD, 0xDD2222, 0x22BB55, 0x4488FF];
        _jumperAccents = [0xFF8822, 0xFF8866, 0x88BBFF, 0xFF6666, 0x66DD88, 0x88CCFF];

        _venueNames = ["Zakopane", "Innsbruck", "Oberstdorf", "Vikersund"];
        _venue = 0;

        _crowdX = new [CROWD_N]; _crowdC = new [CROWD_N]; _crowdJump = new [CROWD_N];
        var cc = [0xDD4444, 0x4488DD, 0xFFCC22, 0x44BB44, 0xFF8844, 0xDD44DD, 0x44DDDD, 0xFFFFFF];
        for (var i = 0; i < CROWD_N; i++) { _crowdX[i] = 0.0; _crowdC[i] = cc[i % 8]; _crowdJump[i] = 0; }
        _crowdCheer = 0; _passedK = false;

        _hillX = new [HILL_PTS]; _hillY = new [HILL_PTS];
        buildHill();

        _scores = new [NUM_JUMPERS]; _dists = new [NUM_JUMPERS];
        _cumScores = new [NUM_JUMPERS]; _cumDists = new [NUM_JUMPERS];
        _judgeScores = new [5];
        for (var i = 0; i < NUM_JUMPERS; i++) { _scores[i] = 0.0; _dists[i] = 0.0; _cumScores[i] = 0.0; _cumDists[i] = 0.0; }
        for (var i = 0; i < 5; i++) { _judgeScores[i] = 0.0; }

        _snowX = new [SNOW_N]; _snowY = new [SNOW_N];
        for (var i = 0; i < SNOW_N; i++) { _snowX[i] = (Math.rand().abs() % _w).toFloat(); _snowY[i] = (Math.rand().abs() % _h).toFloat(); }

        _trailX = new [TRAIL_N]; _trailY = new [TRAIL_N]; _trailLife = new [TRAIL_N];
        for (var i = 0; i < TRAIL_N; i++) { _trailX[i] = 0.0; _trailY[i] = 0.0; _trailLife[i] = 0; }

        _posX = 0.0; _posY = 0.0; _vx = 0.0; _vy = 0.0;
        _onHill = true; _speed = 0.0; _bodyAngle = 0.0; _skiAngle = 0.0;
        _inTakeoffZone = false; _maxSpeed = 3.2;
        _takeoffWindow = 0; _takeoffQuality = 0.0; _takeoffFlash = 0;
        _windBase = 0.0; _windCurrent = 0.0; _windPhase = 0.0;
        _camX = 0.0; _camY = 0.0;
        _distance = 0.0; _landTick = 0; _landGood = false;
        _landCrash = false; _landReady = false; _landReadyTick = 0; _landTapDone = false; _landQuality = 0.0; _slideSpeed = 0.0;
        _jumpNum = 0; _currentRound = 1; _jumpSlot = 0; _startJumper = 0;
        _lastDist = 0.0; _lastScore = 0.0;
        var jbd = Application.Storage.getValue("jumpBest");
        _bestDist = (jbd != null) ? jbd : 0.0;
        _showStandings = false; _jumperIdx = 0;
        _shakeX = 0; _shakeY = 0; _shakeTick = 0;
        gameState = JS_MENU;
    }

    hidden function buildHill() {
        var sx = 0.0; var sy = 0.0;
        var inA; var inStep; var tA; var lA;
        if (_venue == 0) {
            _inrunLen = 28; inA = 34.0; inStep = 3.0; tA = 10.0; lA = 32.0;
            _kDist = 90.0; _hsDist = 100.0; _maxSpeed = 3.2;
        } else if (_venue == 1) {
            _inrunLen = 36; inA = 36.0; inStep = 3.2; tA = 11.0; lA = 34.0;
            _kDist = 105.0; _hsDist = 120.0; _maxSpeed = 3.8;
        } else if (_venue == 2) {
            _inrunLen = 46; inA = 37.5; inStep = 3.4; tA = 11.5; lA = 35.5;
            _kDist = 120.0; _hsDist = 140.0; _maxSpeed = 4.3;
        } else {
            _inrunLen = 62; inA = 40.0; inStep = 3.8; tA = 12.0; lA = 38.0;
            _kDist = 185.0; _hsDist = 225.0; _maxSpeed = 5.5;
        }
        _tableIdx = _inrunLen;
        var inR = inA * 3.14159 / 180.0;
        for (var i = 0; i < _inrunLen; i++) { _hillX[i] = sx; _hillY[i] = sy; sx += inStep * Math.cos(inR); sy += inStep * Math.sin(inR); }
        var tLen = 5; var tR = tA * 3.14159 / 180.0;
        for (var i = 0; i < tLen; i++) { _hillX[_inrunLen + i] = sx; _hillY[_inrunLen + i] = sy; sx += 3.0 * Math.cos(tR); sy += 3.0 * Math.sin(tR); }
        var lS = _inrunLen + tLen; var lL = HILL_PTS - lS;
        var kPt = (_kDist / 3.0).toNumber(); if (kPt + lS >= HILL_PTS) { kPt = HILL_PTS - lS - 5; }
        var hsPt = (_hsDist / 3.0).toNumber(); if (hsPt + lS >= HILL_PTS) { hsPt = HILL_PTS - lS - 2; }
        _kIdx = lS + kPt; _hsIdx = lS + hsPt;
        var landStep = (_venue == 3) ? 3.5 : 3.0;
        for (var i = 0; i < lL; i++) {
            var idx = lS + i; if (idx >= HILL_PTS) { break; }
            var prog = i.toFloat() / lL.toFloat();
            var cA = lA * (1.0 - prog * prog * 0.88);
            var cR = cA * 3.14159 / 180.0;
            _hillX[idx] = sx; _hillY[idx] = sy; sx += landStep * Math.cos(cR); sy += landStep * Math.sin(cR);
        }
        for (var i = 0; i < CROWD_N; i++) {
            var ci = lS + 10 + i * 5; if (ci >= HILL_PTS) { ci = HILL_PTS - 1; }
            _crowdX[i] = _hillX[ci] + 10.0 + (i % 3) * 5;
        }
    }

    hidden function hillYAtX(wx) {
        for (var i = 1; i < HILL_PTS; i++) { if (_hillX[i] >= wx) { var t = (wx - _hillX[i - 1]) / (_hillX[i] - _hillX[i - 1] + 0.001); return _hillY[i - 1] + t * (_hillY[i] - _hillY[i - 1]); } }
        return _hillY[HILL_PTS - 1];
    }
    hidden function hillAngleAtX(wx) {
        for (var i = 1; i < HILL_PTS; i++) { if (_hillX[i] >= wx) { return Math.atan2(_hillY[i] - _hillY[i - 1], _hillX[i] - _hillX[i - 1]) * 180.0 / 3.14159; } }
        return 0.0;
    }
    hidden function distFromTableEnd(wx) { var tex = _hillX[_tableIdx + 4]; var dx = wx - tex; if (dx < 0.0) { return 0.0; } return dx * 0.7; }

    function onShow() { _timer = new Timer.Timer(); _timer.start(method(:onTick), 33, true); }
    function onHide() { if (_timer != null) { _timer.stop(); _timer = null; } }

    function onTick() as Void {
        _tick++;
        for (var i = 0; i < SNOW_N; i++) {
            _snowY[i] += 0.7 + (i % 3).toFloat() * 0.3;
            _snowX[i] += _windCurrent * 0.3 + Math.sin((_tick + i * 13).toFloat() * 0.04) * 0.3;
            if (_snowY[i] > _h.toFloat()) { _snowY[i] = 0.0; _snowX[i] = (Math.rand().abs() % _w).toFloat(); }
            if (_snowX[i] < 0.0) { _snowX[i] += _w.toFloat(); } if (_snowX[i] > _w.toFloat()) { _snowX[i] -= _w.toFloat(); }
        }
        for (var i = 0; i < TRAIL_N; i++) { if (_trailLife[i] > 0) { _trailLife[i]--; } }
        if (_shakeTick > 0) { _shakeX = (Math.rand().abs() % 5) - 2; _shakeY = (Math.rand().abs() % 3) - 1; _shakeTick--; } else { _shakeX = 0; _shakeY = 0; }
        if (_takeoffFlash > 0) { _takeoffFlash--; }
        if (_crowdCheer > 0) {
            _crowdCheer--;
            for (var i = 0; i < CROWD_N; i++) { _crowdJump[i] = ((_tick + i * 3) % 6 < 3) ? 1 : 0; }
        } else { for (var i = 0; i < CROWD_N; i++) { _crowdJump[i] = 0; } }

        if (gameState == JS_INRUN) { updateInrun(); }
        else if (gameState == JS_FLIGHT) { updateFlight(); }
        else if (gameState == JS_LANDING) {
            _landTick++;
            if (_slideSpeed > 0.1) {
                _posX += _slideSpeed;
                _posY = hillYAtX(_posX);
                _slideSpeed *= 0.91;
                _bodyAngle = hillAngleAtX(_posX);
                updateCamera();
            }
            if (_landTick > 90) { finishJump(); }
        }
        WatchUi.requestUpdate();
    }

    hidden function updateInrun() {
        var hA = hillAngleAtX(_posX);
        var gravity = 9.8 * Math.sin(hA * 3.14159 / 180.0);
        _speed += (gravity * 0.033 - 0.02 - 0.0004 * _speed * _speed);
        if (_speed < 0.5) { _speed = 0.5; }
        if (_speed > _maxSpeed) { _speed = _maxSpeed; }
        var ang = hA * 3.14159 / 180.0;
        _posX += _speed * Math.cos(ang); _posY = hillYAtX(_posX);
        _bodyAngle = hA; _skiAngle = hA;
        if (_posX >= _hillX[_tableIdx]) {
            _inTakeoffZone = true;
        }
        if (_posX >= _hillX[_tableIdx + 4]) {
            executeTakeoff(false);
        }
        updateCamera();
    }

    hidden function executeTakeoff(manual) {
        if (gameState != JS_INRUN) { return; }
        if (manual && _inTakeoffZone) {
            var edgeX = _hillX[_tableIdx + 4];
            var zoneStartX = _hillX[_tableIdx];
            var dist = edgeX - _posX;
            if (dist < 0.0) { dist = 0.0; }
            var zoneLen = edgeX - zoneStartX;
            var ratio = dist / (zoneLen + 0.01);
            if (ratio < 0.12) { _takeoffQuality = 1.0; _takeoffFlash = 8; }
            else if (ratio < 0.28) { _takeoffQuality = 0.88; _takeoffFlash = 5; }
            else if (ratio < 0.48) { _takeoffQuality = 0.72; }
            else if (ratio < 0.70) { _takeoffQuality = 0.55; }
            else { _takeoffQuality = 0.38; }
        } else if (manual) {
            _takeoffQuality = 0.30;
        } else {
            _takeoffQuality = 0.30;
        }
        var la = 12.0 + _takeoffQuality * 18.0;
        var lr = la * 3.14159 / 180.0;
        var boost = 0.7 + _takeoffQuality * 1.0;
        _vx = _speed * boost * Math.cos(lr); _vy = -_speed * boost * Math.sin(lr);
        _onHill = false; _bodyAngle = la; _skiAngle = la;
        _windBase = -0.8 + (Math.rand().abs() % 20).toFloat() / 10.0;
        _windPhase = (Math.rand().abs() % 628).toFloat() / 100.0;
        if (_takeoffQuality >= 0.95) { doVibe(80, 150); }
        else if (_takeoffQuality > 0.1) { doVibe(50, 100); }
        gameState = JS_FLIGHT;
    }

    hidden function updateFlight() {
        var dt = 0.028;
        var accelInput = accelX.toFloat() / 400.0;
        if (accelInput > 1.8) { accelInput = 1.8; } if (accelInput < -1.8) { accelInput = -1.8; }

        var targetAngle = 22.0 + accelInput * 16.0;
        if (targetAngle < -8.0) { targetAngle = -8.0; } if (targetAngle > 55.0) { targetAngle = 55.0; }

        _windPhase += 0.08;
        var windAmp = 0.5 + _venue.toFloat() * 0.15;
        var gust = Math.sin(_windPhase) * windAmp + Math.sin(_windPhase * 2.7) * 0.25;
        _windCurrent = _windBase + gust;

        targetAngle += _windCurrent * 4.0;
        if (targetAngle < -8.0) { targetAngle = -8.0; } if (targetAngle > 55.0) { targetAngle = 55.0; }

        _bodyAngle = _bodyAngle * 0.88 + targetAngle * 0.12;

        if (_bodyAngle > 52.0 || _bodyAngle < -5.0) {
            _landCrash = true;
            _posY = hillYAtX(_posX);
            doLanding();
            return;
        }

        var speed = Math.sqrt(_vx * _vx + _vy * _vy);
        var fRad = Math.atan2(-_vy, _vx);
        var fDeg = fRad * 180.0 / 3.14159;
        var aoa = _bodyAngle - fDeg;
        if (aoa < -10.0) { aoa = -10.0; } if (aoa > 40.0) { aoa = 40.0; }

        var tqLift = 0.55 + _takeoffQuality * 0.7;
        var sweetSpot = 0.0;
        if (_bodyAngle > 12.0 && _bodyAngle < 32.0) {
            var optAngle = 22.0;
            var dev = _bodyAngle - optAngle; if (dev < 0.0) { dev = -dev; }
            sweetSpot = 1.0 - dev / 12.0;
            if (sweetSpot < 0.0) { sweetSpot = 0.0; }
        }
        var liftMul = 1.0 + sweetSpot * 0.6;
        var lC = 0.0;
        if (aoa > 0.0 && aoa < 30.0) { lC = (aoa * 0.020 - aoa * aoa * 0.00015) * tqLift * liftMul; }
        else if (aoa >= 30.0) { lC = 0.28 * tqLift; }
        var dC = 0.006 + aoa * aoa * 0.00006;
        if (sweetSpot > 0.3) { dC = dC * (1.0 - sweetSpot * 0.4); }

        var lift = lC * speed * speed * 0.5;
        var drag = dC * speed * speed * 0.5;
        var lDir = fRad + 3.14159 / 2.0;
        var ax = -drag * Math.cos(fRad) + lift * Math.cos(lDir) + _windCurrent * 0.14;
        var ay = 9.8 - drag * Math.sin(fRad) - lift * Math.sin(lDir);

        _vx += ax * dt; _vy += ay * dt;
        if (_vx < 0.8) { _vx = 0.8; }
        _posX += _vx * dt * 32.0; _posY += _vy * dt * 32.0;

        _skiAngle = _skiAngle * 0.9 + _bodyAngle * 0.1;
        _distance = distFromTableEnd(_posX);

        if (!_passedK && _distance > _kDist) {
            _passedK = true;
            _crowdCheer = 60;
            doVibe(30, 80);
        }

        if (_tick % 2 == 0) { pushTrail(_posX, _posY); }
        var hY = hillYAtX(_posX);
        var heightAbove = hY - _posY;

        if (!_landReady && heightAbove < 28.0 && _distance > 8.0) {
            _landReady = true;
            _landReadyTick = 0;
        }
        if (_landReady) { _landReadyTick++; }

        if (_posY >= hY - 2.0 && _posX > _hillX[_tableIdx + 4]) {
            _posY = hY;
            if (!_landTapDone) {
                if (_distance < 6.0) {
                    _landCrash = true;
                } else {
                    _landQuality = 0.35;
                }
            }
            doLanding();
        }
        updateCamera();
    }

    hidden function doLanding() {
        _distance = distFromTableEnd(_posX);
        if (_landCrash) {
            _landGood = false;
            _shakeTick = 14;
            doVibe(100, 300);
            _crowdCheer = 10;
            _slideSpeed = 0.0;
        } else {
            _landGood = (_landQuality > 0.6 && _bodyAngle > 8.0 && _bodyAngle < 42.0);
            _shakeTick = _landGood ? 4 : 7;
            doVibe(_landGood ? 40 : 70, _landGood ? 120 : 200);
            _crowdCheer = _landGood ? 50 : 25;
            _slideSpeed = _vx * 0.32;
            if (_slideSpeed < 0.0) { _slideSpeed = 0.0; }
            if (_slideSpeed > 3.5) { _slideSpeed = 3.5; }
        }
        gameState = JS_LANDING; _landTick = 0;
    }

    hidden function doLandingTap() {
        if (!_landReady || _landTapDone) { return; }
        _landTapDone = true;
        var hY = hillYAtX(_posX);
        var heightAbove = hY - _posY;
        if (heightAbove < 0.0) { heightAbove = -heightAbove; }
        if (heightAbove < 9.0) { _landQuality = 1.0; }
        else if (heightAbove < 16.0) { _landQuality = 0.82; }
        else if (heightAbove < 24.0) { _landQuality = 0.58; }
        else { _landQuality = 0.38; }
        if (_landQuality > 0.7 && (_bodyAngle < 4.0 || _bodyAngle > 46.0)) {
            if (Math.rand().abs() % 5 == 0) { _landCrash = true; }
        }
        _posY = hY;
        doLanding();
    }

    hidden function finishJump() {
        var dist = _distance; if (dist < 0.0) { dist = 0.0; }
        var dPts = dist; var sPts = 0.0;
        for (var j = 0; j < 5; j++) {
            var base = 16.0 + _takeoffQuality * 2.5 + _landQuality * 1.5;
            if (_landGood) { base += 1.5; }
            if (_landCrash) { base -= 8.0; }
            base -= (Math.rand().abs() % 10).toFloat() / 10.0;
            if (_bodyAngle > 40.0 || _bodyAngle < 5.0) { base -= 2.0; }
            if (base < 5.0) { base = 5.0; } if (base > 20.0) { base = 20.0; }
            _judgeScores[j] = base; sPts += base;
        }
        sPts -= maxJ(); sPts -= minJ();
        var total = dPts + sPts;
        if (_landCrash) { total = total * 0.4; }
        _lastDist = dist; _lastScore = total;
        _dists[_jumperIdx] = dist; _scores[_jumperIdx] = total;
        _cumDists[_jumperIdx] += dist; _cumScores[_jumperIdx] += total;
        if (dist > _bestDist && !_landCrash) { _bestDist = dist; Application.Storage.setValue("jumpBest", _bestDist); }
        gameState = JS_SCORE;
    }

    hidden function maxJ() { var m = _judgeScores[0]; for (var i = 1; i < 5; i++) { if (_judgeScores[i] > m) { m = _judgeScores[i]; } } return m; }
    hidden function minJ() { var m = _judgeScores[0]; for (var i = 1; i < 5; i++) { if (_judgeScores[i] < m) { m = _judgeScores[i]; } } return m; }

    hidden function pushTrail(px, py) {
        for (var i = TRAIL_N - 1; i > 0; i--) { _trailX[i] = _trailX[i - 1]; _trailY[i] = _trailY[i - 1]; _trailLife[i] = _trailLife[i - 1]; }
        _trailX[0] = px; _trailY[0] = py; _trailLife[0] = 35;
    }

    hidden function updateCamera() {
        var leadX = _posX + _vx * 4.0;
        var leadY = _posY + _vy * 2.0;
        _camX = _camX * 0.88 + leadX * 0.12;
        _camY = _camY * 0.88 + leadY * 0.12;
    }

    hidden function worldToScreen(wx, wy) {
        var scale = 2.2;
        return [_w / 2 + ((wx - _camX) * scale).toNumber(), _h * 42 / 100 + ((wy - _camY) * scale).toNumber()];
    }

    hidden function doVibe(intensity, duration) { if (Toybox has :Attention) { if (Toybox.Attention has :vibrate) { Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]); } } }

    function doAction() {
        if (gameState == JS_MENU) { startCompetition(); }
        else if (gameState == JS_INRUN) { executeTakeoff(true); }
        else if (gameState == JS_FLIGHT && _landReady && !_landTapDone) { doLandingTap(); }
        else if (gameState == JS_SCORE) { advanceAfterScore(); }
        else if (gameState == JS_FINAL) { gameState = JS_MENU; }
    }
    function cycleJumper(dir) { if (gameState == JS_MENU) { _jumperIdx = (_jumperIdx + dir + NUM_JUMPERS) % NUM_JUMPERS; } }

    hidden function startCompetition() {
        _venue = 0;
        buildHill();
        _startJumper = _jumperIdx; _jumpSlot = 0; _currentRound = 1; _showStandings = false; _jumpNum = 0;
        for (var i = 0; i < NUM_JUMPERS; i++) { _scores[i] = 0.0; _dists[i] = 0.0; _cumScores[i] = 0.0; _cumDists[i] = 0.0; }
        _jumperIdx = _startJumper; beginJump();
    }

    hidden function beginJump() {
        _jumpNum++; _posX = _hillX[0]; _posY = _hillY[0];
        _vx = 0.0; _vy = 0.0; _speed = 0.5; _onHill = true;
        _bodyAngle = hillAngleAtX(_posX); _skiAngle = _bodyAngle;
        _inTakeoffZone = false;
        _takeoffWindow = 0; _takeoffQuality = 0.0; _takeoffFlash = 0;
        _distance = 0.0; _landTick = 0; _landGood = false;
        _landCrash = false; _landReady = false; _landReadyTick = 0; _landTapDone = false; _landQuality = 0.0; _slideSpeed = 0.0;
        _windBase = 0.0; _windCurrent = 0.0; _windPhase = 0.0;
        _camX = _posX; _camY = _posY; _shakeTick = 0; _crowdCheer = 0; _passedK = false;
        for (var i = 0; i < TRAIL_N; i++) { _trailLife[i] = 0; }
        gameState = JS_INRUN;
    }

    hidden function advanceAfterScore() {
        if (_showStandings) {
            _showStandings = false;
            _currentRound = 2; _jumpSlot = 0; _jumperIdx = _startJumper; beginJump();
            return;
        }
        _jumpSlot++;
        if (_jumpSlot >= NUM_JUMPERS) {
            if (_currentRound == 1) {
                _showStandings = true;
            } else {
                if (_venue < 3) {
                    _venue++;
                    buildHill();
                    _currentRound = 1; _jumpSlot = 0; _showStandings = false;
                    _jumperIdx = _startJumper; beginJump();
                } else {
                    gameState = JS_FINAL;
                }
            }
        } else {
            _jumperIdx = (_startJumper + _jumpSlot) % NUM_JUMPERS; beginJump();
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        if (gameState == JS_MENU) { drawMenu(dc); return; }
        if (gameState == JS_SCORE) { if (_showStandings) { drawStandings(dc); } else { drawScore(dc); } return; }
        if (gameState == JS_FINAL) { drawFinal(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeX; var oy = _shakeY;
        drawSky(dc);
        drawMountains(dc, ox, oy);
        drawHill(dc, ox, oy);
        drawTrees(dc, ox, oy);
        drawCrowd(dc, ox, oy);
        if (gameState == JS_FLIGHT || gameState == JS_LANDING) { drawTrail(dc, ox, oy); }
        drawJumper(dc, ox, oy);
        drawSnow(dc);
        drawHUD(dc);
        if (_takeoffFlash > 0 && _takeoffFlash > 4) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(0, 0, _w, _h); dc.drawRectangle(1, 1, _w - 2, _h - 2);
        }
    }

    hidden function drawSky(dc) {
        var skyC = [0x0C1428, 0x101838, 0x0A1830, 0x0E1525];
        dc.setColor(skyC[_venue], skyC[_venue]); dc.clear();
        dc.setColor(0xFFFFDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 20 / 100, _h * 12 / 100, 2); dc.fillCircle(_w * 55 / 100, _h * 8 / 100, 1);
        dc.fillCircle(_w * 78 / 100, _h * 15 / 100, 1); dc.fillCircle(_w * 35 / 100, _h * 6 / 100, 2);
        dc.fillCircle(_w * 90 / 100, _h * 10 / 100, 1); dc.fillCircle(_w * 12 / 100, _h * 18 / 100, 1);
        if (_venue == 1 || _venue == 3) {
            dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w * 85 / 100, _h * 8 / 100, 6);
            dc.setColor(0xFFFFDD, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w * 85 / 100, _h * 8 / 100, 4);
        }
    }

    hidden function drawMountains(dc, ox, oy) {
        var par = (_camX * 0.15).toNumber();
        var mc = [0x0E1525, 0x121825, 0x0A1520, 0x101828];
        dc.setColor(mc[_venue], Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, _h * 55 / 100 + oy], [_w * 18 / 100 - par + ox, _h * 25 / 100 + oy], [_w * 45 / 100 - par + ox, _h * 20 / 100 + oy],
            [_w * 70 / 100 - par + ox, _h * 30 / 100 + oy], [_w + ox, _h * 45 / 100 + oy], [_w + ox, _h + oy], [0, _h + oy]]);
        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 18 / 100 - par + ox, _h * 25 / 100 + oy, _w * 45 / 100 - par + ox, _h * 20 / 100 + oy);
        dc.drawLine(_w * 45 / 100 - par + ox, _h * 20 / 100 + oy, _w * 70 / 100 - par + ox, _h * 30 / 100 + oy);

        var par2 = (_camX * 0.25).toNumber();
        dc.setColor(0x18243A, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, _h * 50 / 100 + oy], [_w * 25 / 100 - par2 + ox, _h * 32 / 100 + oy], [_w * 55 / 100 - par2 + ox, _h * 28 / 100 + oy],
            [_w * 80 / 100 - par2 + ox, _h * 36 / 100 + oy], [_w + ox, _h * 42 / 100 + oy], [_w + ox, _h + oy], [0, _h + oy]]);
    }

    hidden function drawHill(dc, ox, oy) {
        for (var i = 0; i < HILL_PTS - 1; i++) {
            var s1 = worldToScreen(_hillX[i], _hillY[i]); var s2 = worldToScreen(_hillX[i + 1], _hillY[i + 1]);
            var sx1 = s1[0] + ox; var sy1 = s1[1] + oy; var sx2 = s2[0] + ox; var sy2 = s2[1] + oy;
            if (sx2 < -10 || sx1 > _w + 10) { continue; }
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT); dc.drawLine(sx1, sy1, sx2, sy2); dc.drawLine(sx1, sy1 + 1, sx2, sy2 + 1);
            dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT); dc.drawLine(sx1, sy1 + 2, sx2, sy2 + 2);
            dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT); dc.drawLine(sx1, sy1 + 3, sx2, sy2 + 3);
            if (sy1 + 4 < _h) { dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT); var fH = _h - sy1 - 3; if (fH > 0 && fH < _h) { dc.fillRectangle(sx1, sy1 + 4, 4, fH); } }
        }
        if (_kIdx < HILL_PTS) { var sk = worldToScreen(_hillX[_kIdx], _hillY[_kIdx]); var ksx = sk[0] + ox; var ksy = sk[1] + oy;
            if (ksx > 0 && ksx < _w) { dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT); dc.drawLine(ksx, ksy - 8, ksx, ksy + 2); dc.drawLine(ksx + 1, ksy - 8, ksx + 1, ksy + 2);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(ksx, ksy - 16, Graphics.FONT_XTINY, "K", Graphics.TEXT_JUSTIFY_CENTER); } }
        if (_hsIdx < HILL_PTS) { var sh = worldToScreen(_hillX[_hsIdx], _hillY[_hsIdx]); var hsx = sh[0] + ox; var hsy = sh[1] + oy;
            if (hsx > 0 && hsx < _w) { dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT); dc.drawLine(hsx, hsy - 8, hsx, hsy + 2); dc.drawLine(hsx + 1, hsy - 8, hsx + 1, hsy + 2);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(hsx, hsy - 16, Graphics.FONT_XTINY, "HS", Graphics.TEXT_JUSTIFY_CENTER); } }
    }

    hidden function drawTrees(dc, ox, oy) {
        for (var i = 0; i < 14; i++) {
            var tWx = 18.0 + i.toFloat() * 32.0; var tWy = hillYAtX(tWx) - 1.0;
            var s = worldToScreen(tWx, tWy); var tx = s[0] + ox + 14; var ty = s[1] + oy;
            if (tx < -10 || tx > _w + 10) { continue; }
            dc.setColor(0x2A1A0A, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tx - 1, ty - 1, 2, 6);
            dc.setColor(0x1B5528, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[tx, ty - 10 - (i % 3) * 2], [tx - 5, ty], [tx + 5, ty]]);
            dc.setColor(0x22AA44, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[tx, ty - 8 - (i % 3) * 2], [tx - 3, ty - 2], [tx + 3, ty - 2]]);
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tx - 3, ty - 9 - (i % 3) * 2, 2, 1); dc.fillRectangle(tx + 1, ty - 7, 1, 1);
        }
    }

    hidden function drawCrowd(dc, ox, oy) {
        for (var i = 0; i < CROWD_N; i++) {
            var cWy = hillYAtX(_crowdX[i]) - 2.0;
            var s = worldToScreen(_crowdX[i], cWy); var cx = s[0] + ox; var cy = s[1] + oy;
            if (cx < -5 || cx > _w + 5 || cy < -5 || cy > _h + 5) { continue; }
            var jmp = _crowdJump[i] * 3;
            dc.setColor(_crowdC[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 1, cy - 5 - jmp, 3, 4);
            dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy - 6 - jmp, 2);
            if (_crowdCheer > 0 && _crowdJump[i] > 0) {
                dc.setColor(_crowdC[i], Graphics.COLOR_TRANSPARENT);
                dc.drawLine(cx - 2, cy - 5 - jmp, cx - 4, cy - 8 - jmp);
                dc.drawLine(cx + 2, cy - 5 - jmp, cx + 4, cy - 8 - jmp);
            }
        }
    }

    hidden function drawTrail(dc, ox, oy) {
        for (var i = 0; i < TRAIL_N; i++) {
            if (_trailLife[i] <= 0) { continue; }
            var s = worldToScreen(_trailX[i], _trailY[i]); var sx = s[0] + ox; var sy = s[1] + oy;
            dc.setColor((_trailLife[i] > 24) ? 0xAADDFF : ((_trailLife[i] > 12) ? 0x6699BB : 0x334455), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, (_trailLife[i] > 20) ? 2 : 1);
        }
    }

    hidden function drawJumper(dc, ox, oy) {
        var s = worldToScreen(_posX, _posY); var jx = s[0] + ox; var jy = s[1] + oy;
        var col = _jumperColors[_jumperIdx]; var acc = _jumperAccents[_jumperIdx];

        if (gameState == JS_LANDING && _landCrash) {
            var tumble = (_landTick * 18) % 360;
            var tR = tumble.toFloat() * 3.14159 / 180.0;
            var tdx = (Math.cos(tR) * 5.0).toNumber(); var tdy = (Math.sin(tR) * 5.0).toNumber();
            dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 3 + tdx, jy - 4 + tdy, 6, 8);
            dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(jx + tdx, jy - 6 + tdy, 3);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT); dc.drawLine(jx - 4, jy + 1, jx + 5, jy + 2);
            if (_landTick % 4 < 2) {
                dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(jx + (Math.rand().abs() % 10) - 5, jy - (Math.rand().abs() % 6), 2);
            }
        } else if (gameState == JS_LANDING) {
            var aR = _bodyAngle * 3.14159 / 180.0;
            var bdx = (Math.cos(aR) * 8.0).toNumber(); var bdy = -(Math.sin(aR) * 8.0).toNumber();
            var isSliding = (_slideSpeed > 0.3);
            if (isSliding) {
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(jx, jy, jx + bdx, jy + bdy); dc.drawLine(jx + 1, jy, jx + bdx + 1, jy + bdy);
                dc.drawLine(jx, jy + 1, jx + bdx, jy + bdy + 1);
                dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(jx + bdx, jy + bdy, 3);
                dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + bdx - 2, jy + bdy - 3, 5, 2);
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(jx - 3, jy + 2, jx - 3 + bdx, jy + 2 + bdy);
                dc.drawLine(jx + 3, jy + 2, jx + 3 + bdx, jy + 2 + bdy);
            } else if (_landGood) {
                dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(jx, jy - 11, 3);
                dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 4, jy - 13, 8, 3);
                dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 3, jy - 8, 6, 8);
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 5, jy, 4, 1); dc.fillRectangle(jx + 2, jy, 4, 1);
            } else {
                dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(jx, jy - 9, 3);
                dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 4, jy - 11, 8, 3);
                dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 3, jy - 6, 6, 6);
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 4, jy, 9, 1);
            }
        } else if (gameState == JS_FLIGHT) {
            var aR = _bodyAngle * 3.14159 / 180.0;
            var bdx = (Math.cos(aR) * 10.0).toNumber(); var bdy = -(Math.sin(aR) * 10.0).toNumber();
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(jx, jy, jx + bdx, jy + bdy); dc.drawLine(jx + 1, jy, jx + bdx + 1, jy + bdy);
            dc.drawLine(jx, jy + 1, jx + bdx, jy + bdy + 1); dc.drawLine(jx, jy - 1, jx + bdx, jy + bdy - 1);
            dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(jx + bdx, jy + bdy, 3);
            dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + bdx - 3, jy + bdy - 4, 6, 3);
            var sR = _skiAngle * 3.14159 / 180.0;
            var sdx = (Math.cos(sR) * 9.0).toNumber(); var sdy = -(Math.sin(sR) * 9.0).toNumber();
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(jx - 3, jy + 2, jx - 3 + sdx, jy + 2 + sdy); dc.drawLine(jx + 3, jy + 2, jx + 3 + sdx, jy + 2 + sdy);
        } else {
            var ang = _bodyAngle * 3.14159 / 180.0;
            var dx = (Math.cos(ang) * 5.0).toNumber(); var dy = (Math.sin(ang) * 5.0).toNumber();
            dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(jx + dx, jy - 8 + dy, 3);
            dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + dx - 3, jy - 10 + dy, 6, 3);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 2 + dx, jy - 5 + dy, 5, 6);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT); dc.drawLine(jx - 3, jy + 1, jx + 4, jy + 1);
        }
    }

    hidden function drawSnow(dc) {
        for (var i = 0; i < SNOW_N; i++) {
            dc.setColor((i % 3 == 0) ? 0xDDEEFF : 0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_snowX[i].toNumber(), _snowY[i].toNumber(), (i % 5 == 0) ? 2 : 1, 1);
        }
    }

    hidden function drawHUD(dc) {
        if (gameState == JS_INRUN) {
            var kmh = (_speed * 35.0).toNumber();
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(6, 4, Graphics.FONT_XTINY, kmh + " km/h", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(5, 3, Graphics.FONT_XTINY, kmh + " km/h", Graphics.TEXT_JUSTIFY_LEFT);
            if (_inTakeoffZone) {
                var edgeX = _hillX[_tableIdx + 4];
                var zoneX = _hillX[_tableIdx];
                var ratio = (edgeX - _posX) / (edgeX - zoneX + 0.01);
                if (ratio < 0.0) { ratio = 0.0; } if (ratio > 1.0) { ratio = 1.0; }
                var barW = _w * 40 / 100; var barX = (_w - barW) / 2; var barY = _h - 18;
                dc.setColor(0x333355, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(barX, barY, barW, 8);
                var okZone = barX + barW * 50 / 100;
                dc.setColor(0x224422, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(okZone, barY, barX + barW - okZone, 8);
                var goodZone = barX + barW * 70 / 100;
                dc.setColor(0x226622, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(goodZone, barY, barX + barW - goodZone, 8);
                var perfZone = barX + barW * 88 / 100;
                dc.setColor(0x44AA44, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(perfZone, barY, barX + barW - perfZone, 8);
                var markerPos = barX + ((1.0 - ratio) * barW.toFloat()).toNumber();
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(markerPos - 1, barY - 3, 3, 14);
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h - 31, Graphics.FONT_SMALL, "TAP!", Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor((_tick % 4 < 2) ? 0xFF4444 : 0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h - 32, Graphics.FONT_SMALL, "TAP!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        if (gameState == JS_FLIGHT) {
            var distN = _distance.toNumber();
            var bigFont = (distN > _kDist.toNumber()) ? true : false;
            var distCol = 0xFFFFFF;
            if (distN > _hsDist.toNumber()) { distCol = 0xFFDD44; }
            else if (distN > _kDist.toNumber()) { distCol = 0x44FF88; }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, 4, bigFont ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL, distN + "m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(distCol, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, 3, bigFont ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL, distN + "m", Graphics.TEXT_JUSTIFY_CENTER);

            var wStr = _windCurrent > 0.3 ? ">>" : (_windCurrent < -0.3 ? "<<" : "--");
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT); dc.drawText(5, 3, Graphics.FONT_XTINY, "W " + wStr, Graphics.TEXT_JUSTIFY_LEFT);

            var aI = _bodyAngle.toNumber();
            var inSweet = (aI > 14 && aI < 30);
            var angleOk = (aI > 12 && aI < 40);
            dc.setColor(inSweet ? 0x44FFAA : (angleOk ? 0x44FF44 : 0xFF4444), Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w - 5, 3, Graphics.FONT_XTINY, aI + "d", Graphics.TEXT_JUSTIFY_RIGHT);

            if (inSweet && _takeoffQuality > 0.7 && !_landReady) {
                dc.setColor((_tick % 6 < 3) ? 0x44FFAA : 0x22DD88, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_XTINY, "SOARING!", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (!angleOk && (_bodyAngle > 48.0 || _bodyAngle < -2.0)) {
                dc.setColor((_tick % 4 < 2) ? 0xFF2222 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_XTINY, "BALANCE!", Graphics.TEXT_JUSTIFY_CENTER);
            }

            if (_landReady && !_landTapDone) {
                var hYh = hillYAtX(_posX);
                var hAbove = hYh - _posY;
                if (hAbove < 0.0) { hAbove = 0.0; }
                var closeRatio = 1.0 - hAbove / 28.0;
                if (closeRatio < 0.0) { closeRatio = 0.0; } if (closeRatio > 1.0) { closeRatio = 1.0; }
                var tapCol = (closeRatio > 0.75) ? ((_tick % 2 == 0) ? 0xFF2222 : 0xFF8800) : (closeRatio > 0.5 ? ((_tick % 4 < 2) ? 0xFFFF44 : 0xFFAA22) : 0x44FF44);
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h - 25, Graphics.FONT_MEDIUM, "LAND!", Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(tapCol, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h - 26, Graphics.FONT_MEDIUM, "LAND!", Graphics.TEXT_JUSTIFY_CENTER);
                var bW = _w * 30 / 100; var bX = (_w - bW) / 2; var bY = _h - 10;
                dc.setColor(0x333355, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX, bY, bW, 4);
                var fillW = (closeRatio * bW.toFloat()).toNumber();
                dc.setColor(tapCol, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX, bY, fillW, 4);
            } else if (!_landReady) {
                var bW = _w * 30 / 100; var bX = (_w - bW) / 2; var bY = _h - 12;
                dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX, bY, bW, 6);
                var optL = bX + (bW * 18 / 100); var optR = bX + (bW * 60 / 100);
                dc.setColor(inSweet ? 0x33AA66 : 0x226622, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(optL, bY, optR - optL, 6);
                var balPct = (_bodyAngle - 5.0) / 45.0; if (balPct < 0.0) { balPct = 0.0; } if (balPct > 1.0) { balPct = 1.0; }
                var bPos = bX + (balPct * bW.toFloat()).toNumber();
                dc.setColor(inSweet ? 0x66FFCC : 0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bPos - 1, bY - 2, 3, 10);
            }
        }
        if (gameState == JS_LANDING) {
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, 4, Graphics.FONT_MEDIUM, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, 3, Graphics.FONT_MEDIUM, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
            var msg;
            var mc;
            if (_landCrash) {
                msg = "CRASH!";
                mc = 0xFF2222;
            } else if (_landGood) {
                msg = "TELEMARK!";
                mc = 0x44FF88;
            } else {
                msg = "TWO-FOOTED";
                mc = 0xFFAA44;
            }
            dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 68 / 100, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);
            if (_distance > _kDist && !_landCrash) {
                dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 80 / 100, Graphics.FONT_XTINY, _distance > _hsDist ? "HILL RECORD!" : "Beyond K!", Graphics.TEXT_JUSTIFY_CENTER);
            }
            if (_landCrash) {
                dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 80 / 100, Graphics.FONT_XTINY, "Score penalty!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 5, _h - 14, Graphics.FONT_XTINY, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(5, _h - 14, Graphics.FONT_XTINY, _venueNames[_venue], Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x0C1428, 0x0C1428); dc.clear();
        drawSky(dc);
        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, _h * 50 / 100], [_w * 35 / 100, _h * 28 / 100], [_w * 55 / 100, _h * 38 / 100], [_w, _h * 53 / 100], [_w, _h], [0, _h]]);
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, _h * 56 / 100], [_w * 30 / 100, _h * 43 / 100], [_w * 60 / 100, _h * 50 / 100], [_w, _h * 58 / 100], [_w, _h], [0, _h]]);

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 4 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 14 < 7) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 4 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 17 / 100, Graphics.FONT_SMALL, "SKI JUMP", Graphics.TEXT_JUSTIFY_CENTER);

        var col = _jumperColors[_jumperIdx]; var acc = _jumperAccents[_jumperIdx];
        var jx = _w / 2; var jy = _h * 48 / 100;
        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(jx, jy - 12, 4);
        dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 4, jy - 14, 8, 3);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 4, jy - 9, 8, 11);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 7, jy + 2, 14, 2);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(jx, jy + 8, Graphics.FONT_XTINY, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT); dc.drawText(jx, jy + 19, Graphics.FONT_XTINY, _jumperNat[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(jx - 30, jy - 4, Graphics.FONT_XTINY, "<", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(jx + 30, jy - 4, Graphics.FONT_XTINY, ">", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestDist > 0.0) { dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 76 / 100, Graphics.FONT_XTINY, "BEST " + _bestDist.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 85 / 100, Graphics.FONT_XTINY, "Tap to jump", Graphics.TEXT_JUSTIFY_CENTER);
        for (var i = 0; i < SNOW_N; i++) { dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_snowX[i].toNumber(), _snowY[i].toNumber(), 1, 1); }
    }

    hidden function drawScore(dc) {
        dc.setColor(0x0C1428, 0x0C1428); dc.clear();
        dc.setColor(_jumperColors[_jumperIdx], Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 2 / 100, Graphics.FONT_XTINY, _jumperNames[_jumperIdx] + " [" + _jumperNat[_jumperIdx] + "]", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 12 / 100, Graphics.FONT_LARGE, _lastDist.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
        var landMsg; var landC;
        if (_landCrash) { landMsg = "CRASH"; landC = 0xFF2222; }
        else if (_landGood) { landMsg = "TELEMARK"; landC = 0x44FF88; }
        else { landMsg = "TWO-FOOTED"; landC = 0xFF8844; }
        dc.setColor(landC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 30 / 100, Graphics.FONT_XTINY, landMsg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        var jy = _h * 42 / 100;
        for (var j = 0; j < 5; j++) {
            var jsx = _w * (12 + j * 16) / 100;
            var jVal = _judgeScores[j];
            var jC = 0xBBBBBB;
            if (jVal == maxJ() || jVal == minJ()) { jC = 0x666666; }
            dc.setColor(jC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(jsx, jy, Graphics.FONT_XTINY, jVal.toNumber() + "", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_SMALL, _lastScore.toNumber() + " pts", Graphics.TEXT_JUSTIFY_CENTER);
        var tqMsg = "";
        if (_takeoffQuality >= 0.95) { tqMsg = "PERFECT!"; }
        else if (_takeoffQuality >= 0.7) { tqMsg = "Great jump!"; }
        else if (_takeoffQuality >= 0.4) { tqMsg = "Good jump"; }
        else if (_takeoffQuality >= 0.1) { tqMsg = "Early!"; }
        else { tqMsg = "No jump!"; }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 68 / 100, Graphics.FONT_XTINY, tqMsg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 78 / 100, Graphics.FONT_XTINY, _venueNames[_venue] + " R" + _currentRound + " J" + (_jumpSlot + 1) + "/" + NUM_JUMPERS, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "Tap", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawStandings(dc) {
        dc.setColor(0x0C1428, 0x0C1428); dc.clear();
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 2 / 100, Graphics.FONT_SMALL, _venueNames[_venue] + " R1", Graphics.TEXT_JUSTIFY_CENTER);
        var order = rankByCumScore();
        for (var r = 0; r < NUM_JUMPERS; r++) {
            var idx = order[r]; var ry = _h * (16 + r * 11) / 100;
            var medal = (r == 0) ? 0xFFDD44 : ((r == 1) ? 0xCCCCCC : ((r == 2) ? 0xCC8844 : 0x888888));
            dc.setColor(medal, Graphics.COLOR_TRANSPARENT); dc.drawText(8, ry, Graphics.FONT_XTINY, (r + 1) + ".", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(_jumperColors[idx], Graphics.COLOR_TRANSPARENT); dc.drawText(25, ry, Graphics.FONT_XTINY, _jumperNames[idx], Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w - 8, ry, Graphics.FONT_XTINY, _cumScores[idx].toNumber() + "", Graphics.TEXT_JUSTIFY_RIGHT);
        }
        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "Tap for Round 2", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFinal(dc) {
        dc.setColor(0x0C1428, 0x0C1428); dc.clear();
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 2 / 100, Graphics.FONT_SMALL, "4 HILLS FINAL", Graphics.TEXT_JUSTIFY_CENTER);
        var order = rankByCumScore();
        for (var r = 0; r < NUM_JUMPERS; r++) {
            var idx = order[r]; var ry = _h * (15 + r * 10) / 100;
            var medal = (r == 0) ? 0xFFDD44 : ((r == 1) ? 0xCCCCCC : ((r == 2) ? 0xCC8844 : 0x888888));
            dc.setColor(medal, Graphics.COLOR_TRANSPARENT); dc.drawText(8, ry, Graphics.FONT_XTINY, (r + 1) + ".", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(_jumperColors[idx], Graphics.COLOR_TRANSPARENT); dc.drawText(25, ry, Graphics.FONT_XTINY, _jumperNames[idx], Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w - 8, ry, Graphics.FONT_XTINY, _cumScores[idx].toNumber() + "", Graphics.TEXT_JUSTIFY_RIGHT);
        }
        dc.setColor(_jumperColors[order[0]], Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 76 / 100, Graphics.FONT_XTINY, _jumperNames[order[0]] + " WINS!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 84 / 100, Graphics.FONT_XTINY, "BEST " + _bestDist.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 92 / 100, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function rankByCumScore() {
        var order = new [NUM_JUMPERS]; for (var i = 0; i < NUM_JUMPERS; i++) { order[i] = i; }
        for (var i = 0; i < NUM_JUMPERS - 1; i++) { for (var j = i + 1; j < NUM_JUMPERS; j++) {
            if (_cumScores[order[j]] > _cumScores[order[i]]) { var tmp = order[i]; order[i] = order[j]; order[j] = tmp; }
        } }
        return order;
    }
}
