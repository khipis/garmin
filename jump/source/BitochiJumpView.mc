using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum {
    JS_MENU,
    JS_INRUN,
    JS_TAKEOFF,
    JS_FLIGHT,
    JS_LANDING,
    JS_SCORE,
    JS_FINAL
}

const NUM_JUMPERS = 5;
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

    hidden var _hillX;
    hidden var _hillY;

    hidden var _inrunLen;
    hidden var _tableIdx;
    hidden var _kIdx;
    hidden var _hsIdx;
    hidden var _kDist;
    hidden var _hsDist;

    hidden var _posX;
    hidden var _posY;
    hidden var _vx;
    hidden var _vy;
    hidden var _onHill;
    hidden var _speed;
    hidden var _bodyAngle;
    hidden var _skiAngle;

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

    hidden const SNOW_N = 28;
    hidden var _snowX;
    hidden var _snowY;

    hidden const TRAIL_N = 16;
    hidden var _trailX;
    hidden var _trailY;
    hidden var _trailLife;

    hidden var _shakeX;
    hidden var _shakeY;
    hidden var _shakeTick;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _tick = 0;
        accelX = 0;
        accelY = 0;

        _jumperNames = ["Chikko", "Foczka", "Doggo", "Vexor", "Emilka"];
        _jumperColors = [0xFFCC22, 0x88BBDD, 0xBB8844, 0xCC2222, 0xFF88CC];
        _jumperAccents = [0xFF8822, 0x6699BB, 0xFFCC66, 0xFF4444, 0xFFAAEE];

        _hillX = new [HILL_PTS];
        _hillY = new [HILL_PTS];
        buildHill();

        _scores = new [NUM_JUMPERS];
        _dists = new [NUM_JUMPERS];
        _cumScores = new [NUM_JUMPERS];
        _cumDists = new [NUM_JUMPERS];
        _judgeScores = new [5];
        for (var i = 0; i < NUM_JUMPERS; i++) {
            _scores[i] = 0.0; _dists[i] = 0.0;
            _cumScores[i] = 0.0; _cumDists[i] = 0.0;
        }
        for (var i = 0; i < 5; i++) { _judgeScores[i] = 0.0; }

        _snowX = new [SNOW_N];
        _snowY = new [SNOW_N];
        for (var i = 0; i < SNOW_N; i++) {
            _snowX[i] = (Math.rand().abs() % _w).toFloat();
            _snowY[i] = (Math.rand().abs() % _h).toFloat();
        }

        _trailX = new [TRAIL_N];
        _trailY = new [TRAIL_N];
        _trailLife = new [TRAIL_N];
        for (var i = 0; i < TRAIL_N; i++) { _trailX[i] = 0.0; _trailY[i] = 0.0; _trailLife[i] = 0; }

        _posX = 0.0; _posY = 0.0; _vx = 0.0; _vy = 0.0;
        _onHill = true; _speed = 0.0; _bodyAngle = 0.0; _skiAngle = 0.0;
        _takeoffWindow = 0; _takeoffQuality = 0.0; _takeoffFlash = 0;
        _windBase = 0.0; _windCurrent = 0.0; _windPhase = 0.0;
        _camX = 0.0; _camY = 0.0;
        _distance = 0.0; _landTick = 0; _landGood = false;
        _jumpNum = 0; _currentRound = 1; _jumpSlot = 0; _startJumper = 0;
        _lastDist = 0.0; _lastScore = 0.0; _bestDist = 0.0;
        _showStandings = false;
        _jumperIdx = 0;
        _shakeX = 0; _shakeY = 0; _shakeTick = 0;

        gameState = JS_MENU;
    }

    hidden function buildHill() {
        var sx = 0.0;
        var sy = 0.0;

        _inrunLen = 50;
        _tableIdx = _inrunLen;
        var inrunAngle = 37.0;
        var inrunRad = inrunAngle * 3.14159 / 180.0;
        var inrunStep = 3.5;

        for (var i = 0; i < _inrunLen; i++) {
            _hillX[i] = sx;
            _hillY[i] = sy;
            sx += inrunStep * Math.cos(inrunRad);
            sy += inrunStep * Math.sin(inrunRad);
        }

        var tableLen = 5;
        var tableAngle = 11.0;
        var tableRad = tableAngle * 3.14159 / 180.0;
        for (var i = 0; i < tableLen; i++) {
            _hillX[_inrunLen + i] = sx;
            _hillY[_inrunLen + i] = sy;
            sx += 3.0 * Math.cos(tableRad);
            sy += 3.0 * Math.sin(tableRad);
        }

        var landStart = _inrunLen + tableLen;
        var landLen = HILL_PTS - landStart;
        var landAngle = 35.0;

        _kIdx = landStart + 30;
        _hsIdx = landStart + 45;
        _kDist = 120.0;
        _hsDist = 140.0;

        for (var i = 0; i < landLen; i++) {
            var idx = landStart + i;
            if (idx >= HILL_PTS) { break; }
            var prog = i.toFloat() / landLen.toFloat();
            var curAngle = landAngle * (1.0 - prog * prog * 0.9);
            var curRad = curAngle * 3.14159 / 180.0;
            var step = 3.0;
            _hillX[idx] = sx;
            _hillY[idx] = sy;
            sx += step * Math.cos(curRad);
            sy += step * Math.sin(curRad);
        }
    }

    hidden function hillYAtX(wx) {
        for (var i = 1; i < HILL_PTS; i++) {
            if (_hillX[i] >= wx) {
                var t = (wx - _hillX[i - 1]) / (_hillX[i] - _hillX[i - 1] + 0.001);
                return _hillY[i - 1] + t * (_hillY[i] - _hillY[i - 1]);
            }
        }
        return _hillY[HILL_PTS - 1];
    }

    hidden function hillAngleAtX(wx) {
        for (var i = 1; i < HILL_PTS; i++) {
            if (_hillX[i] >= wx) {
                var dx = _hillX[i] - _hillX[i - 1];
                var dy = _hillY[i] - _hillY[i - 1];
                return Math.atan2(dy, dx) * 180.0 / 3.14159;
            }
        }
        return 0.0;
    }

    hidden function distFromTableEnd(wx) {
        var tex = _hillX[_tableIdx + 4];
        var dx = wx - tex;
        if (dx < 0.0) { return 0.0; }
        return dx * 0.7;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 33, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _tick++;

        for (var i = 0; i < SNOW_N; i++) {
            _snowY[i] += 0.8 + (i % 3).toFloat() * 0.4;
            _snowX[i] += _windCurrent * 0.3 + Math.sin((_tick + i * 13).toFloat() * 0.04) * 0.3;
            if (_snowY[i] > _h.toFloat()) { _snowY[i] = 0.0; _snowX[i] = (Math.rand().abs() % _w).toFloat(); }
            if (_snowX[i] < 0.0) { _snowX[i] += _w.toFloat(); }
            if (_snowX[i] > _w.toFloat()) { _snowX[i] -= _w.toFloat(); }
        }

        for (var i = 0; i < TRAIL_N; i++) {
            if (_trailLife[i] > 0) { _trailLife[i]--; }
        }

        if (_shakeTick > 0) {
            _shakeX = (Math.rand().abs() % 5) - 2;
            _shakeY = (Math.rand().abs() % 3) - 1;
            _shakeTick--;
        } else { _shakeX = 0; _shakeY = 0; }

        if (_takeoffFlash > 0) { _takeoffFlash--; }

        if (gameState == JS_INRUN) { updateInrun(); }
        else if (gameState == JS_TAKEOFF) { updateTakeoff(); }
        else if (gameState == JS_FLIGHT) { updateFlight(); }
        else if (gameState == JS_LANDING) {
            _landTick++;
            if (_landTick > 50) { finishJump(); }
        }

        WatchUi.requestUpdate();
    }

    hidden function updateInrun() {
        var hillAng = hillAngleAtX(_posX);
        var gravity = 9.8 * Math.sin(hillAng * 3.14159 / 180.0);
        var friction = 0.02;
        var drag = 0.0004 * _speed * _speed;
        _speed += (gravity * 0.033 - friction - drag);
        if (_speed < 0.5) { _speed = 0.5; }
        if (_speed > 5.5) { _speed = 5.5; }

        var ang = hillAng * 3.14159 / 180.0;
        _posX += _speed * Math.cos(ang);
        _posY = hillYAtX(_posX);
        _bodyAngle = hillAng;
        _skiAngle = hillAng;

        if (_posX >= _hillX[_tableIdx]) {
            gameState = JS_TAKEOFF;
            _takeoffWindow = 0;
        }

        updateCamera();
    }

    hidden function updateTakeoff() {
        var hillAng = hillAngleAtX(_posX);
        var gravity = 9.8 * Math.sin(hillAng * 3.14159 / 180.0);
        var drag = 0.0004 * _speed * _speed;
        _speed += (gravity * 0.033 - 0.01 - drag);
        if (_speed < 2.0) { _speed = 2.0; }

        var ang = hillAng * 3.14159 / 180.0;
        _posX += _speed * Math.cos(ang);
        _posY = hillYAtX(_posX);
        _bodyAngle = hillAng;
        _skiAngle = hillAng;

        _takeoffWindow++;

        var endX = _hillX[_tableIdx + 4];
        if (_posX >= endX) {
            executeTakeoff(false);
        }

        updateCamera();
    }

    hidden function executeTakeoff(manual) {
        if (gameState != JS_TAKEOFF) { return; }

        if (manual) {
            var dist = _hillX[_tableIdx + 4] - _posX;
            if (dist < 0.0) { dist = -dist; }
            var maxDist = _hillX[_tableIdx + 4] - _hillX[_tableIdx];
            var ratio = dist / (maxDist + 0.01);
            if (ratio < 0.15) { _takeoffQuality = 1.0; _takeoffFlash = 10; }
            else if (ratio < 0.35) { _takeoffQuality = 0.8; }
            else if (ratio < 0.6) { _takeoffQuality = 0.55; }
            else { _takeoffQuality = 0.3; }
        } else {
            _takeoffQuality = 0.15;
        }

        var launchAngle = 12.0 + _takeoffQuality * 12.0;
        var launchRad = launchAngle * 3.14159 / 180.0;
        var jumpBoost = 1.0 + _takeoffQuality * 0.6;
        _vx = _speed * jumpBoost * Math.cos(launchRad);
        _vy = -_speed * jumpBoost * Math.sin(launchRad);
        _onHill = false;
        _bodyAngle = launchAngle;
        _skiAngle = launchAngle;

        _windBase = -0.8 + (Math.rand().abs() % 20).toFloat() / 10.0;
        _windPhase = (Math.rand().abs() % 628).toFloat() / 100.0;

        doVibe(50, 100);
        gameState = JS_FLIGHT;
    }

    hidden function updateFlight() {
        var dt = 0.033;
        var g = 9.8;

        var accelInput = accelX.toFloat() / 500.0;
        if (accelInput > 1.5) { accelInput = 1.5; }
        if (accelInput < -1.5) { accelInput = -1.5; }

        var targetAngle = 20.0 + accelInput * 15.0;
        if (targetAngle < -5.0) { targetAngle = -5.0; }
        if (targetAngle > 50.0) { targetAngle = 50.0; }
        _bodyAngle = _bodyAngle * 0.88 + targetAngle * 0.12;

        _windPhase += 0.1;
        var gust = Math.sin(_windPhase) * 0.4 + Math.sin(_windPhase * 2.7) * 0.15;
        _windCurrent = _windBase + gust;

        var speed = Math.sqrt(_vx * _vx + _vy * _vy);
        var flightRad = Math.atan2(-_vy, _vx);
        var flightDeg = flightRad * 180.0 / 3.14159;

        var aoa = _bodyAngle - flightDeg;
        if (aoa < -10.0) { aoa = -10.0; }
        if (aoa > 40.0) { aoa = 40.0; }

        var liftCoeff = 0.0;
        if (aoa > 0.0 && aoa < 30.0) {
            liftCoeff = aoa * 0.012 - aoa * aoa * 0.00015;
        } else if (aoa >= 30.0) {
            liftCoeff = 0.18;
        }
        var dragCoeff = 0.008 + aoa * aoa * 0.00008;

        var lift = liftCoeff * speed * speed * 0.5;
        var drag = dragCoeff * speed * speed * 0.5;

        var liftDir = flightRad + 3.14159 / 2.0;
        var ax = -drag * Math.cos(flightRad) + lift * Math.cos(liftDir) + _windCurrent * 0.15;
        var ay = g - drag * Math.sin(flightRad) - lift * Math.sin(liftDir);

        _vx += ax * dt;
        _vy += ay * dt;
        if (_vx < 1.0) { _vx = 1.0; }

        _posX += _vx * dt * 30.0;
        _posY += _vy * dt * 30.0;

        _skiAngle = _skiAngle * 0.9 + _bodyAngle * 0.1;

        _distance = distFromTableEnd(_posX);

        if (_tick % 2 == 0) { pushTrail(_posX, _posY); }

        var hillY = hillYAtX(_posX);
        if (_posY >= hillY - 2.0 && _distance > 5.0) {
            _posY = hillY;
            doLanding();
        }

        updateCamera();
    }

    hidden function doLanding() {
        _distance = distFromTableEnd(_posX);
        var landAngle = _bodyAngle;
        var landSpeed = Math.sqrt(_vx * _vx + _vy * _vy);
        _landGood = (landAngle > 10.0 && landAngle < 40.0 && landSpeed < 8.0);

        gameState = JS_LANDING;
        _landTick = 0;
        _shakeTick = _landGood ? 4 : 8;
        doVibe(_landGood ? 40 : 80, _landGood ? 120 : 250);
    }

    hidden function finishJump() {
        var dist = _distance;
        if (dist < 0.0) { dist = 0.0; }

        var distPts = dist;
        var stylePts = 0.0;
        for (var j = 0; j < 5; j++) {
            var base = 17.0 + _takeoffQuality * 2.0;
            if (_landGood) { base += 1.5; }
            base -= (Math.rand().abs() % 10).toFloat() / 10.0;
            if (_bodyAngle > 40.0 || _bodyAngle < 5.0) { base -= 2.0; }
            if (base < 10.0) { base = 10.0; }
            if (base > 20.0) { base = 20.0; }
            _judgeScores[j] = base;
            stylePts += base;
        }
        stylePts -= maxJudge();
        stylePts -= minJudge();

        var total = distPts + stylePts;
        _lastDist = dist;
        _lastScore = total;
        _dists[_jumperIdx] = dist;
        _scores[_jumperIdx] = total;
        _cumDists[_jumperIdx] += dist;
        _cumScores[_jumperIdx] += total;
        if (dist > _bestDist) { _bestDist = dist; }

        gameState = JS_SCORE;
    }

    hidden function maxJudge() {
        var m = _judgeScores[0];
        for (var i = 1; i < 5; i++) { if (_judgeScores[i] > m) { m = _judgeScores[i]; } }
        return m;
    }

    hidden function minJudge() {
        var m = _judgeScores[0];
        for (var i = 1; i < 5; i++) { if (_judgeScores[i] < m) { m = _judgeScores[i]; } }
        return m;
    }

    hidden function pushTrail(px, py) {
        for (var i = TRAIL_N - 1; i > 0; i--) {
            _trailX[i] = _trailX[i - 1]; _trailY[i] = _trailY[i - 1]; _trailLife[i] = _trailLife[i - 1];
        }
        _trailX[0] = px; _trailY[0] = py; _trailLife[0] = 30;
    }

    hidden function updateCamera() {
        var tx = _posX;
        var ty = _posY;
        _camX = _camX * 0.9 + tx * 0.1;
        _camY = _camY * 0.9 + ty * 0.1;
    }

    hidden function worldToScreen(wx, wy) {
        var scale = 2.0;
        var sx = _w / 2 + ((wx - _camX) * scale).toNumber();
        var sy = _h * 45 / 100 + ((wy - _camY) * scale).toNumber();
        return [sx, sy];
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }

    function doAction() {
        if (gameState == JS_MENU) {
            startCompetition();
        } else if (gameState == JS_TAKEOFF) {
            executeTakeoff(true);
        } else if (gameState == JS_SCORE) {
            advanceAfterScore();
        } else if (gameState == JS_FINAL) {
            gameState = JS_MENU;
        }
    }

    function cycleJumper(dir) {
        if (gameState == JS_MENU) {
            _jumperIdx = (_jumperIdx + dir + NUM_JUMPERS) % NUM_JUMPERS;
        }
    }

    hidden function startCompetition() {
        _startJumper = _jumperIdx;
        _jumpSlot = 0;
        _currentRound = 1;
        _showStandings = false;
        _jumpNum = 0;
        for (var i = 0; i < NUM_JUMPERS; i++) {
            _scores[i] = 0.0; _dists[i] = 0.0;
            _cumScores[i] = 0.0; _cumDists[i] = 0.0;
        }
        _jumperIdx = _startJumper;
        beginJump();
    }

    hidden function beginJump() {
        _jumpNum++;
        _posX = _hillX[0];
        _posY = _hillY[0];
        _vx = 0.0; _vy = 0.0;
        _speed = 0.5;
        _onHill = true;
        _bodyAngle = hillAngleAtX(_posX);
        _skiAngle = _bodyAngle;
        _takeoffWindow = 0;
        _takeoffQuality = 0.0;
        _takeoffFlash = 0;
        _distance = 0.0;
        _landTick = 0; _landGood = false;
        _windBase = 0.0; _windCurrent = 0.0; _windPhase = 0.0;
        _camX = _posX; _camY = _posY;
        _shakeTick = 0; _shakeX = 0; _shakeY = 0;
        for (var i = 0; i < TRAIL_N; i++) { _trailLife[i] = 0; }
        gameState = JS_INRUN;
    }

    hidden function advanceAfterScore() {
        if (_showStandings) {
            _showStandings = false;
            _currentRound = 2;
            _jumpSlot = 0;
            _jumperIdx = _startJumper;
            beginJump();
            return;
        }
        _jumpSlot++;
        if (_jumpSlot >= NUM_JUMPERS) {
            if (_currentRound == 1) {
                _showStandings = true;
            } else {
                gameState = JS_FINAL;
            }
        } else {
            _jumperIdx = (_startJumper + _jumpSlot) % NUM_JUMPERS;
            beginJump();
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();

        if (gameState == JS_MENU) { drawMenu(dc); return; }
        if (gameState == JS_SCORE) {
            if (_showStandings) { drawStandings(dc); }
            else { drawScore(dc); }
            return;
        }
        if (gameState == JS_FINAL) { drawFinal(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeX;
        var oy = _shakeY;

        drawSky(dc);
        drawMountains(dc, ox, oy);
        drawHill(dc, ox, oy);
        drawTrees(dc, ox, oy);

        if (gameState == JS_FLIGHT || gameState == JS_LANDING) {
            drawTrail(dc, ox, oy);
        }

        drawJumper(dc, ox, oy);
        drawSnow(dc);
        drawHUD(dc);

        if (_takeoffFlash > 0) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, _w, _h);
        }
    }

    hidden function drawSky(dc) {
        dc.setColor(0x0C1428, 0x0C1428);
        dc.clear();
        dc.setColor(0x101830, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h * 30 / 100);
        dc.setColor(0x182040, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 30 / 100, _w, _h * 20 / 100);

        dc.setColor(0xFFFFDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 20 / 100, _h * 12 / 100, 2);
        dc.fillCircle(_w * 55 / 100, _h * 8 / 100, 1);
        dc.fillCircle(_w * 78 / 100, _h * 15 / 100, 1);
        dc.fillCircle(_w * 35 / 100, _h * 6 / 100, 2);
        dc.fillCircle(_w * 90 / 100, _h * 10 / 100, 1);
    }

    hidden function drawMountains(dc, ox, oy) {
        var par = (_camX * 0.15).toNumber();
        dc.setColor(0x0E1525, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [0, _h * 55 / 100 + oy],
            [_w * 18 / 100 - par + ox, _h * 25 / 100 + oy],
            [_w * 45 / 100 - par + ox, _h * 20 / 100 + oy],
            [_w * 70 / 100 - par + ox, _h * 30 / 100 + oy],
            [_w + ox, _h * 45 / 100 + oy],
            [_w + ox, _h + oy], [0, _h + oy]
        ]);
        dc.setColor(0x18243A, Graphics.COLOR_TRANSPARENT);
        var par2 = (_camX * 0.25).toNumber();
        dc.fillPolygon([
            [0, _h * 50 / 100 + oy],
            [_w * 25 / 100 - par2 + ox, _h * 32 / 100 + oy],
            [_w * 55 / 100 - par2 + ox, _h * 28 / 100 + oy],
            [_w * 80 / 100 - par2 + ox, _h * 36 / 100 + oy],
            [_w + ox, _h * 42 / 100 + oy],
            [_w + ox, _h + oy], [0, _h + oy]
        ]);
    }

    hidden function drawHill(dc, ox, oy) {
        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < HILL_PTS - 1; i++) {
            var s1 = worldToScreen(_hillX[i], _hillY[i]);
            var s2 = worldToScreen(_hillX[i + 1], _hillY[i + 1]);
            var sx1 = s1[0] + ox;
            var sy1 = s1[1] + oy;
            var sx2 = s2[0] + ox;
            var sy2 = s2[1] + oy;
            if (sx2 < -10 || sx1 > _w + 10) { continue; }

            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx1, sy1, sx2, sy2);
            dc.drawLine(sx1, sy1 + 1, sx2, sy2 + 1);

            dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx1, sy1 + 2, sx2, sy2 + 2);
            dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx1, sy1 + 3, sx2, sy2 + 3);

            if (sy1 + 4 < _h) {
                dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
                var fillH = _h - sy1 - 3;
                if (fillH > 0 && fillH < _h) {
                    dc.fillRectangle(sx1, sy1 + 4, 4, fillH);
                }
            }
        }

        if (_kIdx < HILL_PTS) {
            var sk = worldToScreen(_hillX[_kIdx], _hillY[_kIdx]);
            var ksx = sk[0] + ox;
            var ksy = sk[1] + oy;
            if (ksx > 0 && ksx < _w) {
                dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(ksx, ksy - 6, ksx, ksy + 2);
                dc.drawLine(ksx + 1, ksy - 6, ksx + 1, ksy + 2);
            }
        }
        if (_hsIdx < HILL_PTS) {
            var sh = worldToScreen(_hillX[_hsIdx], _hillY[_hsIdx]);
            var hsx = sh[0] + ox;
            var hsy = sh[1] + oy;
            if (hsx > 0 && hsx < _w) {
                dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(hsx, hsy - 6, hsx, hsy + 2);
                dc.drawLine(hsx + 1, hsy - 6, hsx + 1, hsy + 2);
            }
        }
    }

    hidden function drawTrees(dc, ox, oy) {
        for (var i = 0; i < 12; i++) {
            var treeWorldX = 20.0 + i.toFloat() * 35.0;
            var treeWorldY = hillYAtX(treeWorldX) - 1.0;
            var s = worldToScreen(treeWorldX, treeWorldY);
            var tx = s[0] + ox + 12;
            var ty = s[1] + oy;
            if (tx < -10 || tx > _w + 10) { continue; }

            dc.setColor(0x2A1A0A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - 1, ty - 1, 2, 5);
            dc.setColor(0x1B5528, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[tx, ty - 9 - (i % 3) * 2], [tx - 4, ty], [tx + 4, ty]]);
            dc.setColor(0x22AA44, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[tx, ty - 7 - (i % 3) * 2], [tx - 3, ty - 2], [tx + 3, ty - 2]]);
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - 2, ty - 8 - (i % 3) * 2, 1, 1);
        }
    }

    hidden function drawTrail(dc, ox, oy) {
        for (var i = 0; i < TRAIL_N; i++) {
            if (_trailLife[i] <= 0) { continue; }
            var s = worldToScreen(_trailX[i], _trailY[i]);
            var sx = s[0] + ox;
            var sy = s[1] + oy;
            var c = (_trailLife[i] > 20) ? 0xAADDFF : ((_trailLife[i] > 10) ? 0x6699BB : 0x334455);
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            var sz = (_trailLife[i] > 20) ? 2 : 1;
            dc.fillCircle(sx, sy, sz);
        }
    }

    hidden function drawJumper(dc, ox, oy) {
        var s = worldToScreen(_posX, _posY);
        var jx = s[0] + ox;
        var jy = s[1] + oy;
        var col = _jumperColors[_jumperIdx];
        var acc = _jumperAccents[_jumperIdx];

        if (gameState == JS_LANDING && _landGood) {
            dc.setColor(0xDDCCAA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(jx - 1, jy - 8, 3, 8);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(jx - 2, jy - 6, 5, 4);
            dc.setColor(acc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(jx, jy - 9, 2);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(jx - 4, jy, 3, 1);
            dc.fillRectangle(jx + 2, jy, 3, 1);
        } else if (gameState == JS_LANDING) {
            dc.setColor(0xDDCCAA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(jx - 1, jy - 6, 3, 6);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(jx - 2, jy - 5, 5, 3);
            dc.setColor(acc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(jx, jy - 7, 2);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(jx - 3, jy, 7, 1);
        } else if (gameState == JS_FLIGHT) {
            var angRad = _bodyAngle * 3.14159 / 180.0;
            var bodyDx = (Math.cos(angRad) * 8.0).toNumber();
            var bodyDy = -(Math.sin(angRad) * 8.0).toNumber();

            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(jx, jy, jx + bodyDx, jy + bodyDy);
            dc.drawLine(jx + 1, jy, jx + bodyDx + 1, jy + bodyDy);
            dc.drawLine(jx, jy + 1, jx + bodyDx, jy + bodyDy + 1);

            dc.setColor(acc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(jx + bodyDx, jy + bodyDy, 2);

            var skiRad = _skiAngle * 3.14159 / 180.0;
            var skiDx = (Math.cos(skiRad) * 7.0).toNumber();
            var skiDy = -(Math.sin(skiRad) * 7.0).toNumber();
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(jx - 2, jy + 1, jx - 2 + skiDx, jy + 1 + skiDy);
            dc.drawLine(jx + 2, jy + 1, jx + 2 + skiDx, jy + 1 + skiDy);
        } else {
            var ang = _bodyAngle * 3.14159 / 180.0;
            var dx = (Math.cos(ang) * 5.0).toNumber();
            var dy = (Math.sin(ang) * 5.0).toNumber();

            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(jx - 1 + dx, jy - 5 + dy, 3, 5);
            dc.setColor(acc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(jx + dx, jy - 6 + dy, 2);

            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(jx - 2, jy + 1, jx + 3, jy + 1);
        }
    }

    hidden function drawSnow(dc) {
        for (var i = 0; i < SNOW_N; i++) {
            var c = (i % 3 == 0) ? 0xDDEEFF : 0xAABBCC;
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_snowX[i].toNumber(), _snowY[i].toNumber(), 1, 1);
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);

        if (gameState == JS_INRUN || gameState == JS_TAKEOFF) {
            var kmh = (_speed * 35.0).toNumber();
            dc.drawText(5, 3, Graphics.FONT_XTINY, kmh + " km/h", Graphics.TEXT_JUSTIFY_LEFT);
        }

        if (gameState == JS_TAKEOFF) {
            dc.setColor((_tick % 4 < 2) ? 0xFF4444 : 0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h - 20, Graphics.FONT_XTINY, "TAP!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (gameState == JS_FLIGHT) {
            var d = _distance.toNumber();
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, 3, Graphics.FONT_XTINY, d + "m", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(5, 3, Graphics.FONT_XTINY, "W:" + _windCurrent.toNumber(), Graphics.TEXT_JUSTIFY_LEFT);

            var angInd = _bodyAngle.toNumber();
            dc.setColor((angInd > 15 && angInd < 35) ? 0x44FF44 : 0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w - 5, 3, Graphics.FONT_XTINY, angInd + "°", Graphics.TEXT_JUSTIFY_RIGHT);
        }

        if (gameState == JS_LANDING) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, 3, Graphics.FONT_SMALL, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
            var msg = _landGood ? "TELEMARK!" : "LANDED";
            var mc = _landGood ? 0x44FF88 : 0xFFAA44;
            dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 70 / 100, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 5, _h - 14, Graphics.FONT_XTINY, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_RIGHT);
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x0C1428, 0x0C1428);
        dc.clear();

        drawSky(dc);

        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, _h * 50 / 100], [_w * 35 / 100, _h * 30 / 100], [_w * 55 / 100, _h * 40 / 100], [_w, _h * 55 / 100], [_w, _h], [0, _h]]);
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, _h * 58 / 100], [_w * 30 / 100, _h * 45 / 100], [_w * 60 / 100, _h * 52 / 100], [_w, _h * 60 / 100], [_w, _h], [0, _h]]);

        var tc = (_tick % 14 < 7) ? 0x44CCFF : 0x33AADD;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, _h * 5 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 5 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 19 / 100, Graphics.FONT_SMALL, "SKI JUMP", Graphics.TEXT_JUSTIFY_CENTER);

        var col = _jumperColors[_jumperIdx];
        var acc = _jumperAccents[_jumperIdx];
        var jx = _w / 2;
        var jy = _h * 52 / 100;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(jx - 3, jy - 8, 7, 10);
        dc.setColor(acc, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(jx, jy - 10, 4);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(jx - 6, jy + 2, 13, 2);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(jx, jy + 8, Graphics.FONT_XTINY, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(jx - 25, jy - 3, Graphics.FONT_XTINY, "<", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(jx + 25, jy - 3, Graphics.FONT_XTINY, ">", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestDist > 0.0) {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 75 / 100, Graphics.FONT_XTINY, "BEST " + _bestDist.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 85 / 100, Graphics.FONT_XTINY, "Tap to jump", Graphics.TEXT_JUSTIFY_CENTER);

        for (var i = 0; i < SNOW_N; i++) {
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_snowX[i].toNumber(), _snowY[i].toNumber(), 1, 1);
        }
    }

    hidden function drawScore(dc) {
        dc.setColor(0x0C1428, 0x0C1428);
        dc.clear();

        var col = _jumperColors[_jumperIdx];
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 3 / 100, Graphics.FONT_XTINY, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 14 / 100, Graphics.FONT_LARGE, _lastDist.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        var landMsg = _landGood ? "TELEMARK" : "TWO-FOOTED";
        dc.setColor(_landGood ? 0x44FF88 : 0xFF8844, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 32 / 100, Graphics.FONT_XTINY, landMsg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        var jy = _h * 44 / 100;
        for (var j = 0; j < 5; j++) {
            var jsx = _w * (15 + j * 16) / 100;
            dc.drawText(jsx, jy, Graphics.FONT_XTINY, _judgeScores[j].toNumber() + "", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 56 / 100, Graphics.FONT_SMALL, _lastScore.toNumber() + " pts", Graphics.TEXT_JUSTIFY_CENTER);

        var tqMsg = "";
        if (_takeoffQuality >= 0.95) { tqMsg = "PERFECT TAKEOFF!"; }
        else if (_takeoffQuality >= 0.7) { tqMsg = "Good takeoff"; }
        else if (_takeoffQuality >= 0.4) { tqMsg = "OK takeoff"; }
        else { tqMsg = "Late takeoff"; }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 70 / 100, Graphics.FONT_XTINY, tqMsg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 80 / 100, Graphics.FONT_XTINY, "R" + _currentRound + " J" + (_jumpSlot + 1) + "/" + NUM_JUMPERS, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 90 / 100, Graphics.FONT_XTINY, "Tap", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawStandings(dc) {
        dc.setColor(0x0C1428, 0x0C1428);
        dc.clear();

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 3 / 100, Graphics.FONT_SMALL, "ROUND 1", Graphics.TEXT_JUSTIFY_CENTER);

        var order = rankByCumScore();
        for (var r = 0; r < NUM_JUMPERS; r++) {
            var idx = order[r];
            var ry = _h * (18 + r * 14) / 100;
            var medal = (r == 0) ? 0xFFDD44 : ((r == 1) ? 0xCCCCCC : ((r == 2) ? 0xCC8844 : 0x888888));
            dc.setColor(medal, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, ry, Graphics.FONT_XTINY, (r + 1) + ".", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(_jumperColors[idx], Graphics.COLOR_TRANSPARENT);
            dc.drawText(25, ry, Graphics.FONT_XTINY, _jumperNames[idx], Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w - 8, ry, Graphics.FONT_XTINY, _cumScores[idx].toNumber() + "", Graphics.TEXT_JUSTIFY_RIGHT);
        }

        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 90 / 100, Graphics.FONT_XTINY, "Tap for Round 2", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFinal(dc) {
        dc.setColor(0x0C1428, 0x0C1428);
        dc.clear();

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 3 / 100, Graphics.FONT_SMALL, "FINAL", Graphics.TEXT_JUSTIFY_CENTER);

        var order = rankByCumScore();
        for (var r = 0; r < NUM_JUMPERS; r++) {
            var idx = order[r];
            var ry = _h * (18 + r * 13) / 100;
            var medal = (r == 0) ? 0xFFDD44 : ((r == 1) ? 0xCCCCCC : ((r == 2) ? 0xCC8844 : 0x888888));
            dc.setColor(medal, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, ry, Graphics.FONT_XTINY, (r + 1) + ".", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(_jumperColors[idx], Graphics.COLOR_TRANSPARENT);
            dc.drawText(25, ry, Graphics.FONT_XTINY, _jumperNames[idx], Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w - 8, ry, Graphics.FONT_XTINY, _cumScores[idx].toNumber() + "", Graphics.TEXT_JUSTIFY_RIGHT);
        }

        var winnerIdx = order[0];
        dc.setColor(_jumperColors[winnerIdx], Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 78 / 100, Graphics.FONT_XTINY, _jumperNames[winnerIdx] + " WINS!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 90 / 100, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function rankByCumScore() {
        var order = new [NUM_JUMPERS];
        for (var i = 0; i < NUM_JUMPERS; i++) { order[i] = i; }
        for (var i = 0; i < NUM_JUMPERS - 1; i++) {
            for (var j = i + 1; j < NUM_JUMPERS; j++) {
                if (_cumScores[order[j]] > _cumScores[order[i]]) {
                    var tmp = order[i]; order[i] = order[j]; order[j] = tmp;
                }
            }
        }
        return order;
    }
}
