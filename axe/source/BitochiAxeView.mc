using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum {
    GS_MENU,
    GS_AIM,
    GS_THROW,
    GS_RESULT,
    GS_BETWEEN,
    GS_GAMEOVER
}

class BitochiAxeView extends WatchUi.View {

    var accelX;
    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;
    hidden var _timer;
    hidden var _tick;

    hidden var _axeX;
    hidden var _axeY;
    hidden var _axeVy;
    hidden var _axeAngle;
    hidden var _axeAngVel;
    hidden var _aimOff;

    hidden var _targetX;
    hidden var _targetY;
    hidden var _targetR;
    hidden var _tgtDir;
    hidden var _tgtSpd;

    hidden const MAX_STUCK = 10;
    hidden var _stuckOff;
    hidden var _stuckCount;

    hidden const MAX_PARTS = 35;
    hidden var _partX;
    hidden var _partY;
    hidden var _partVx;
    hidden var _partVy;
    hidden var _partLife;
    hidden var _partColor;

    hidden const SNOW_N = 20;
    hidden var _snowX;
    hidden var _snowY;
    hidden var _snowSpd;

    hidden var _wave;
    hidden var _score;
    hidden var _bestScore;
    hidden var _lives;
    hidden var _throwsLeft;
    hidden var _throwsTotal;
    hidden var _combo;
    hidden var _maxCombo;
    hidden var _tolerance;
    hidden var _resultMsg;
    hidden var _resultTick;
    hidden var _resultType;
    hidden var _betweenTick;
    hidden var _shakeTimer;
    hidden var _shakeOx;
    hidden var _shakeOy;

    hidden var _missAxeX;
    hidden var _missAxeY;
    hidden var _missAxeVy;
    hidden var _missAxeAng;
    hidden var _showMiss;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _cx = _w / 2;
        _cy = _h / 2;
        accelX = 0;
        _tick = 0;
        _wave = 0;
        _score = 0;
        _bestScore = 0;
        _lives = 3;

        _axeX = 0.0; _axeY = 0.0; _axeVy = 0.0;
        _axeAngle = 0.0; _axeAngVel = 8.0; _aimOff = 0.0;

        _targetX = _cx;
        _targetY = _h * 20 / 100;
        _targetR = _w * 14 / 100;
        _tgtDir = 0; _tgtSpd = 0;

        _stuckOff = new [MAX_STUCK];
        _stuckCount = 0;
        for (var i = 0; i < MAX_STUCK; i++) { _stuckOff[i] = 0.0; }

        _partX = new [MAX_PARTS];
        _partY = new [MAX_PARTS];
        _partVx = new [MAX_PARTS];
        _partVy = new [MAX_PARTS];
        _partLife = new [MAX_PARTS];
        _partColor = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) {
            _partLife[i] = 0; _partX[i] = 0.0; _partY[i] = 0.0;
            _partVx[i] = 0.0; _partVy[i] = 0.0; _partColor[i] = 0;
        }

        _snowX = new [SNOW_N];
        _snowY = new [SNOW_N];
        _snowSpd = new [SNOW_N];
        for (var i = 0; i < SNOW_N; i++) {
            _snowX[i] = (Math.rand().abs() % _w).toFloat();
            _snowY[i] = (Math.rand().abs() % _h).toFloat();
            _snowSpd[i] = 0.3 + (Math.rand().abs() % 10).toFloat() / 10.0;
        }

        _throwsLeft = 0; _throwsTotal = 0;
        _combo = 0; _maxCombo = 0;
        _tolerance = 35.0;
        _resultMsg = ""; _resultTick = 0; _resultType = 0;
        _betweenTick = 0;
        _shakeTimer = 0; _shakeOx = 0; _shakeOy = 0;
        _missAxeX = 0.0; _missAxeY = 0.0; _missAxeVy = 0.0; _missAxeAng = 0.0;
        _showMiss = false;
        gameState = GS_MENU;
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

        if (_shakeTimer > 0) {
            _shakeOx = (Math.rand().abs() % 9) - 4;
            _shakeOy = (Math.rand().abs() % 7) - 3;
            _shakeTimer--;
        } else { _shakeOx = 0; _shakeOy = 0; }

        for (var i = 0; i < SNOW_N; i++) {
            _snowY[i] += _snowSpd[i];
            _snowX[i] += Math.sin((_tick + i * 20).toFloat() * 0.05) * 0.3;
            if (_snowY[i] > _h.toFloat()) {
                _snowY[i] = -2.0;
                _snowX[i] = (Math.rand().abs() % _w).toFloat();
            }
        }

        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            _partVy[i] += 0.14;
            _partX[i] += _partVx[i];
            _partY[i] += _partVy[i];
            _partLife[i]--;
        }

        if (gameState == GS_MENU || gameState == GS_GAMEOVER) {
            _axeAngle += 6.0;
            if (_axeAngle >= 360.0) { _axeAngle -= 360.0; }
        } else if (gameState == GS_AIM) {
            _axeAngle += _axeAngVel;
            if (_axeAngle >= 360.0) { _axeAngle -= 360.0; }
            updateTarget();
            var steer = accelX.toFloat() / 220.0;
            if (steer > 3.0) { steer = 3.0; }
            if (steer < -3.0) { steer = -3.0; }
            _aimOff = _aimOff * 0.88 + steer * 0.12;
        } else if (gameState == GS_THROW) {
            _axeAngle += _axeAngVel;
            if (_axeAngle >= 360.0) { _axeAngle -= 360.0; }
            _axeY += _axeVy;
            updateTarget();
            if (_axeY <= (_targetY + _targetR).toFloat()) {
                checkHit();
            }
        } else if (gameState == GS_RESULT) {
            _resultTick++;
            updateTarget();
            if (_showMiss) {
                _missAxeVy += 0.35;
                _missAxeY += _missAxeVy;
                _missAxeAng += 13.0;
            }
            if (_resultTick > 50) { advanceAfterResult(); }
        } else if (gameState == GS_BETWEEN) {
            _betweenTick++;
        }

        WatchUi.requestUpdate();
    }

    hidden function updateTarget() {
        if (_tgtSpd <= 0) { return; }
        var interval = 4 - _tgtSpd;
        if (interval < 1) { interval = 1; }
        if (_tick % interval == 0) {
            _targetX += _tgtDir;
            var maxOff = _w * 20 / 100;
            if (_targetX > _cx + maxOff) { _tgtDir = -1; }
            if (_targetX < _cx - maxOff) { _tgtDir = 1; }
        }
    }

    hidden function checkHit() {
        var normAng = ((_axeAngle % 360.0) + 360.0) % 360.0;
        var diff = normAng - 90.0;
        if (diff > 180.0) { diff -= 360.0; }
        if (diff < -180.0) { diff += 360.0; }
        var absDiff = diff;
        if (absDiff < 0.0) { absDiff = -absDiff; }

        var xRel = _axeX - _targetX.toFloat();
        var absXRel = xRel;
        if (absXRel < 0.0) { absXRel = -absXRel; }

        if (absXRel > _targetR.toFloat()) {
            doMiss("MISS!");
            return;
        }

        for (var i = 0; i < _stuckCount; i++) {
            var sd = xRel - _stuckOff[i];
            if (sd < 0.0) { sd = -sd; }
            if (sd < 10.0) {
                doMiss("BLOCKED!");
                _resultType = 3;
                return;
            }
        }

        if (absDiff > _tolerance) {
            doMiss("BAD ANGLE!");
            return;
        }

        if (_stuckCount < MAX_STUCK) {
            _stuckOff[_stuckCount] = xRel;
            _stuckCount++;
        }
        _throwsLeft--;
        _combo++;
        if (_combo > _maxCombo) { _maxCombo = _combo; }
        _showMiss = false;

        if (absDiff < 8.0 && absXRel < _targetR.toFloat() * 0.25) {
            _resultMsg = "BULLSEYE!";
            _resultType = 2;
            _score += 150 + _combo * 25;
            doVibe(100, 150);
            _shakeTimer = 10;
        } else if (absDiff < 15.0) {
            _resultMsg = "PERFECT!";
            _resultType = 2;
            _score += 100 + _combo * 20;
            doVibe(70, 100);
            _shakeTimer = 7;
        } else {
            _resultMsg = "HIT!";
            _resultType = 1;
            _score += 50 + _combo * 10;
            doVibe(50, 70);
            _shakeTimer = 5;
        }

        spawnWoodChips(_axeX.toNumber(), _targetY + _targetR);
        gameState = GS_RESULT;
        _resultTick = 0;
    }

    hidden function doMiss(msg) {
        _resultMsg = msg;
        _resultType = 0;
        _resultTick = 0;
        _throwsLeft--;
        _lives--;
        _combo = 0;
        _showMiss = true;
        _missAxeX = _axeX;
        _missAxeY = (_targetY + _targetR).toFloat();
        _missAxeVy = -1.8;
        _missAxeAng = _axeAngle;
        spawnSparks(_axeX.toNumber(), _targetY + _targetR);
        doVibe(30, 50);
        _shakeTimer = 4;
        gameState = GS_RESULT;
    }

    hidden function advanceAfterResult() {
        if (_lives <= 0) {
            if (_score > _bestScore) { _bestScore = _score; }
            gameState = GS_GAMEOVER;
            _resultTick = 0;
            return;
        }
        if (_throwsLeft <= 0) {
            gameState = GS_BETWEEN;
            _betweenTick = 0;
            return;
        }
        gameState = GS_AIM;
        resetAxePos();
    }

    hidden function resetAxePos() {
        _axeX = _cx.toFloat();
        _axeY = (_h * 82 / 100).toFloat();
        _aimOff = 0.0;
        _showMiss = false;
    }

    hidden function startRound() {
        _stuckCount = 0;
        _throwsTotal = 3 + _wave / 2;
        if (_throwsTotal > 8) { _throwsTotal = 8; }
        _throwsLeft = _throwsTotal;
        _tolerance = 36.0 - _wave.toFloat() * 2.0;
        if (_tolerance < 14.0) { _tolerance = 14.0; }
        _axeAngVel = 7.5 + _wave.toFloat() * 0.35;
        if (_axeAngVel > 12.5) { _axeAngVel = 12.5; }
        if (_wave >= 3) { _tgtDir = 1; _tgtSpd = 1; }
        else { _tgtDir = 0; _tgtSpd = 0; }
        if (_wave >= 6) { _tgtSpd = 2; }
        if (_wave >= 9) { _tgtSpd = 3; }
        _targetX = _cx;
        _combo = 0;
        resetAxePos();
        gameState = GS_AIM;
    }

    function doAction() {
        if (gameState == GS_MENU) {
            _wave = 1; _score = 0; _lives = 3;
            _combo = 0; _maxCombo = 0;
            startRound();
            return;
        }
        if (gameState == GS_AIM) {
            _axeX = _cx.toFloat() + _aimOff * 5.0;
            _axeY = (_h * 82 / 100).toFloat();
            _axeVy = -4.2;
            gameState = GS_THROW;
            doVibe(20, 25);
            return;
        }
        if (gameState == GS_RESULT) {
            if (_resultTick > 15) { advanceAfterResult(); }
            return;
        }
        if (gameState == GS_BETWEEN) {
            if (_betweenTick > 20) { _wave++; startRound(); }
            return;
        }
        if (gameState == GS_GAMEOVER) {
            if (_resultTick > 20) { gameState = GS_MENU; }
            return;
        }
    }

    hidden function spawnWoodChips(ex, ey) {
        var wc = [0x8A6644, 0xAA7744, 0x6A4422, 0xBB8855, 0x997755, 0xCC9966];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 12) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat() + ((Math.rand().abs() % 5) - 2).toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 180).toFloat() * 3.14159 / 180.0;
            var spd = 1.0 + (Math.rand().abs() % 30).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a) * ((Math.rand().abs() % 2 == 0) ? 1.0 : -1.0);
            _partVy[i] = -spd * Math.sin(a) - 0.8;
            _partLife[i] = 14 + Math.rand().abs() % 14;
            _partColor[i] = wc[Math.rand().abs() % 6];
            spawned++;
        }
    }

    hidden function spawnSparks(ex, ey) {
        var sc = [0xFFCC44, 0xFFAA22, 0xFFFFAA, 0xFFDD66, 0xEEBB33, 0xFFFF88];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 10) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 2.0 + (Math.rand().abs() % 25).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a);
            _partVy[i] = spd * Math.sin(a) - 0.5;
            _partLife[i] = 8 + Math.rand().abs() % 10;
            _partColor[i] = sc[Math.rand().abs() % 6];
            spawned++;
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            var vp = new Attention.VibeProfile(intensity, duration);
            Attention.vibrate([vp]);
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _targetY = _h * 20 / 100;
        _targetR = _w * 14 / 100;

        if (gameState == GS_MENU) { drawMenu(dc); return; }
        if (gameState == GS_GAMEOVER) { drawGameOver(dc); return; }
        if (gameState == GS_BETWEEN) { drawBetween(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeOx;
        var oy = _shakeOy;

        drawVikingBg(dc, ox, oy);
        drawSnow(dc, ox, oy);
        drawTarget(dc, ox, oy);
        drawStuckAxes(dc, ox, oy);
        drawParticles(dc, ox, oy);

        if (gameState == GS_AIM) {
            var apx = _cx + (_aimOff * 5.0).toNumber() + ox;
            var apy = _h * 82 / 100 + oy;
            drawRotAxe(dc, apx, apy, _axeAngle, 14);
            dc.setColor(0x3A3A44, Graphics.COLOR_TRANSPARENT);
            var gy = apy - 10;
            while (gy > _targetY + _targetR + oy + 4) {
                dc.fillRectangle(apx, gy, 1, 3);
                gy -= 7;
            }
            dc.setColor(0x555544, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(_targetX + (_aimOff * 5.0).toNumber() + ox, _targetY + oy, 4);
        } else if (gameState == GS_THROW) {
            drawRotAxe(dc, _axeX.toNumber() + ox, _axeY.toNumber() + oy, _axeAngle, 14);
        } else if (gameState == GS_RESULT) {
            if (_showMiss && _missAxeY < (_h + 40).toFloat()) {
                drawRotAxe(dc, _missAxeX.toNumber() + ox, _missAxeY.toNumber() + oy, _missAxeAng, 14);
            }
            if (_resultType > 0 && _resultTick < 4) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_targetX + _stuckOff[_stuckCount - 1].toNumber() + ox, _targetY + _targetR + oy, 6 - _resultTick);
            }
        }

        drawTorches(dc, ox, oy);
        drawHUD(dc);

        if (gameState == GS_RESULT && _resultTick < 42) {
            var mc = 0xFFFF44;
            if (_resultType == 0) { mc = 0xFF4444; }
            else if (_resultType == 2) { mc = 0x44FF44; }
            else if (_resultType == 3) { mc = 0xFF6644; }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx + 1, _cy - 4, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy - 5, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (gameState == GS_AIM) {
            dc.setColor(0x6A5533, Graphics.COLOR_TRANSPARENT);
            var angNorm = ((_axeAngle % 360.0) + 360.0) % 360.0;
            var angDiff = angNorm - 90.0;
            if (angDiff > 180.0) { angDiff -= 360.0; }
            if (angDiff < -180.0) { angDiff += 360.0; }
            if (angDiff < 0.0) { angDiff = -angDiff; }
            var barW = _w * 40 / 100;
            var barX = _cx - barW / 2;
            var barY = _h - 18;
            dc.fillRectangle(barX, barY, barW, 4);
            var fill = barW - (angDiff.toNumber() * barW / 180);
            if (fill < 0) { fill = 0; }
            if (fill > barW) { fill = barW; }
            var bc = 0xCC3333;
            if (angDiff < _tolerance) { bc = 0x44CC44; }
            else if (angDiff < _tolerance * 1.5) { bc = 0xCCAA33; }
            dc.setColor(bc, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, fill, 4);
        }
    }

    hidden function drawVikingBg(dc, ox, oy) {
        dc.setColor(0x1A1408, 0x1A1408);
        dc.clear();

        for (var p = 0; p < _w; p += 16) {
            dc.setColor(0x2A1A0C, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(p + ox, oy, 14, _h);
            dc.setColor(0x352215, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(p + 1 + ox, oy, 12, _h);
            dc.setColor(0x2A1A0C, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(p + 6 + ox, oy, p + 6 + ox, _h + oy);
            dc.drawLine(p + 11 + ox, oy, p + 11 + ox, _h + oy);
            if (p % 32 == 0) {
                dc.setColor(0x1E0E06, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(p + 7 + ox, _h * 40 / 100 + oy, 2);
            }
        }

        dc.setColor(0x8A6644, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ox, oy, _w, 5);
        dc.setColor(0xAA7744, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ox, 1 + oy, _w, 3);
        for (var k = 0; k < _w; k += 10) {
            dc.setColor(0xBB8855, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(k + 2 + ox, oy, 3, 5);
            dc.setColor(0x6A4422, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(k + 7 + ox, oy, 2, 5);
        }

        dc.setColor(0x8A6644, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ox, _h - 5 + oy, _w, 5);
        dc.setColor(0xAA7744, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ox, _h - 4 + oy, _w, 3);
        for (var k = 0; k < _w; k += 10) {
            dc.setColor(0xBB8855, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(k + 2 + ox, _h - 5 + oy, 3, 5);
            dc.setColor(0x6A4422, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(k + 7 + ox, _h - 5 + oy, 2, 5);
        }

        drawRune(dc, 10 + ox, _cy - 25 + oy);
        drawRune(dc, _w - 14 + ox, _cy + 20 + oy);
        drawRune(dc, 10 + ox, _cy + 30 + oy);
        drawRune(dc, _w - 14 + ox, _cy - 35 + oy);
    }

    hidden function drawRune(dc, rx, ry) {
        dc.setColor(0x4A2A12, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(rx, ry - 8, rx, ry + 8);
        dc.drawLine(rx, ry - 8, rx + 4, ry - 2);
        dc.drawLine(rx, ry + 1, rx + 4, ry + 6);
        dc.drawLine(rx, ry - 3, rx - 3, ry + 1);
    }

    hidden function drawTorches(dc, ox, oy) {
        drawTorch(dc, 20 + ox, _cy - 25 + oy);
        drawTorch(dc, _w - 20 + ox, _cy - 25 + oy);
    }

    hidden function drawTorch(dc, tx, ty) {
        dc.setColor(0x555544, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx - 2, ty, 5, 14);
        dc.setColor(0x666655, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx - 3, ty - 1, 7, 3);

        var fh = 5 + (_tick % 4);
        dc.setColor(0xFF5511, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx, ty - fh, 5);
        dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx, ty - fh - 1, 4);
        dc.setColor(0xFFBB33, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx, ty - fh, 3);
        dc.setColor(0xFFFF55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx, ty - fh + 1, 2);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx + ((_tick * 3) % 5) - 2, ty - fh - 5, 1);
        if (_tick % 6 < 3) {
            dc.setColor(0xFF9933, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tx - 2, ty - fh - 3, 1);
            dc.fillCircle(tx + 2, ty - fh - 4, 1);
        }
    }

    hidden function drawSnow(dc, ox, oy) {
        for (var i = 0; i < SNOW_N; i++) {
            dc.setColor((i % 3 == 0) ? 0xDDDDDD : 0xBBBBCC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_snowX[i].toNumber() + ox, _snowY[i].toNumber() + oy, 1);
        }
    }

    hidden function drawTarget(dc, ox, oy) {
        var tx = _targetX + ox;
        var ty = _targetY + oy;
        var r = _targetR;

        dc.setColor(0x0A0806, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx + 2, ty + 2, r);

        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx, ty, r);
        dc.setColor(0x9A7A55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx, ty, r - 3);
        dc.setColor(0x8A6A44, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(tx, ty, r - 6);
        dc.drawCircle(tx, ty, r - 9);
        dc.drawCircle(tx, ty, r - 12);
        dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(tx, ty, r - 15);
        dc.drawCircle(tx, ty, r - 18);
        if (r > 22) {
            dc.drawCircle(tx, ty, r - 21);
        }

        dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tx - r + 4, ty, tx + r - 4, ty);
        dc.drawLine(tx, ty - r + 4, tx, ty + r - 4);

        dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx, ty, 4);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx, ty, 2);

        for (var b = 0; b < 8; b++) {
            var ba = (b * 45).toFloat() * 3.14159 / 180.0;
            var bx = tx + ((r - 1).toFloat() * Math.cos(ba)).toNumber();
            var by = ty + ((r - 1).toFloat() * Math.sin(ba)).toNumber();
            dc.setColor(0x4A2A10, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 1, by - 1, 2, 2);
        }

        dc.setColor(0x3A2A14, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx - 4, ty + r, 8, 8);
        dc.fillRectangle(tx - 2, ty + r + 8, 4, _h - ty - r - 8);
        dc.setColor(0x4A3A20, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx - 3, ty + r, 6, 6);
    }

    hidden function drawStuckAxes(dc, ox, oy) {
        var tx = _targetX + ox;
        var ty = _targetY + oy;
        var tr = _targetR;
        for (var i = 0; i < _stuckCount; i++) {
            var ax = tx + _stuckOff[i].toNumber();
            var ay = ty + tr;

            dc.setColor(0x7A4422, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 1, ay - 1, 3, 16);
            dc.setColor(0x5A3311, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 1, ay + 10, 3, 5);

            dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 5, ay - 3, 11, 3);
            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 4, ay - 3, 9, 1);

            dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax, ay, 2);
        }
    }

    hidden function drawRotAxe(dc, cx, cy, ang, sz) {
        var rad = ang * 3.14159 / 180.0;
        var cs = Math.cos(rad);
        var sn = Math.sin(rad);
        var perpX = -sn;
        var perpY = cs;
        var szf = sz.toFloat();

        var hx = cx + (szf * cs).toNumber();
        var hy = cy + (szf * sn).toNumber();
        var bx = cx - (szf * cs).toNumber();
        var by = cy - (szf * sn).toNumber();

        dc.setColor(0x7A4422, Graphics.COLOR_TRANSPARENT);
        for (var t = -1; t <= 1; t++) {
            var tpx = (t.toFloat() * perpX).toNumber();
            var tpy = (t.toFloat() * perpY).toNumber();
            dc.drawLine(hx + tpx, hy + tpy, bx + tpx, by + tpy);
        }

        dc.setColor(0x5A3311, Graphics.COLOR_TRANSPARENT);
        var gx = cx + (szf * 0.6 * cs).toNumber();
        var gy = cy + (szf * 0.6 * sn).toNumber();
        for (var t = -1; t <= 1; t++) {
            var tpx = (t.toFloat() * perpX).toNumber();
            var tpy = (t.toFloat() * perpY).toNumber();
            dc.drawLine(gx + tpx, gy + tpy, hx + tpx, hy + tpy);
        }
        dc.setColor(0x8A5533, Graphics.COLOR_TRANSPARENT);
        var wrapOff = szf * 0.4;
        for (var w = 0; w < 3; w++) {
            var wx = cx + ((wrapOff + w.toFloat() * 4.0) * cs).toNumber();
            var wy = cy + ((wrapOff + w.toFloat() * 4.0) * sn).toNumber();
            dc.drawLine(wx + (2.0 * perpX).toNumber(), wy + (2.0 * perpY).toNumber(),
                        wx - (2.0 * perpX).toNumber(), wy - (2.0 * perpY).toNumber());
        }

        var bw = szf * 0.55;
        var bd = szf * 0.4;
        var b1x = bx + (bw * perpX).toNumber();
        var b1y = by + (bw * perpY).toNumber();
        var b2x = bx - (bw * 0.35 * perpX).toNumber();
        var b2y = by - (bw * 0.35 * perpY).toNumber();
        var tipX = bx - (bd * cs).toNumber();
        var tipY = by - (bd * sn).toNumber();
        var t1x = tipX + (bw * 0.5 * perpX).toNumber();
        var t1y = tipY + (bw * 0.5 * perpY).toNumber();
        var t2x = tipX - (bw * 0.15 * perpX).toNumber();
        var t2y = tipY - (bw * 0.15 * perpY).toNumber();

        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[b1x, b1y], [t1x, t1y], [t2x, t2y], [b2x, b2y]]);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(t1x, t1y, t2x, t2y);
        dc.setColor(0x99AABB, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(b1x, b1y, t1x, t1y);

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, 2);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, 1);
    }

    hidden function drawParticles(dc, ox, oy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            dc.setColor(_partColor[i], Graphics.COLOR_TRANSPARENT);
            var psz = (_partLife[i] > 6) ? 2 : 1;
            dc.fillRectangle(_partX[i].toNumber() + ox, _partY[i].toNumber() + oy, psz, psz);
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 5, 7, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 6, Graphics.FONT_XTINY, "R" + _wave, Graphics.TEXT_JUSTIFY_CENTER);

        for (var i = 0; i < _lives; i++) {
            var lx = 10 + i * 14;
            var ly = _h - 12;
            dc.setColor(0xBB8833, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lx, ly, 5);
            dc.setColor(0xDD9944, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lx, ly - 1, 4);
            dc.setColor(0xFFBB55, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lx, ly - 1, 2);
            dc.setColor(0xBB8833, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(lx, ly - 5, lx, ly - 1);
            dc.drawLine(lx - 3, ly - 3, lx + 3, ly - 3);
        }

        for (var i = 0; i < _throwsLeft; i++) {
            var tx = _w - 10 - i * 10;
            var ty = _h - 14;
            dc.setColor(0x7A4422, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx, ty, 2, 8);
            dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - 3, ty - 2, 8, 3);
        }

        if (_combo > 1 && (gameState == GS_AIM || gameState == GS_THROW)) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 72 / 100, Graphics.FONT_XTINY, "x" + _combo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_tgtSpd > 0 && gameState == GS_AIM) {
            dc.setColor(0x5588AA, Graphics.COLOR_TRANSPARENT);
            var wt = (_tgtDir > 0) ? ">>>" : "<<<";
            dc.drawText(_cx, _h * 30 / 100, Graphics.FONT_XTINY, wt, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x0E0A04, 0x0E0A04);
        dc.clear();

        for (var p = 0; p < _w; p += 18) {
            dc.setColor(0x1E140A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(p, 0, 16, _h);
            dc.setColor(0x281C10, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(p + 1, 0, 14, _h);
        }

        drawSnow(dc, 0, 0);

        dc.setColor(0x8A6644, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, 5);
        for (var k = 0; k < _w; k += 10) {
            dc.setColor(0xBB8855, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(k + 2, 1, 3, 3);
        }
        dc.setColor(0x8A6644, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - 5, _w, 5);
        for (var k = 0; k < _w; k += 10) {
            dc.setColor(0xBB8855, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(k + 2, _h - 4, 3, 3);
        }

        drawTorch(dc, 22, _h * 28 / 100);
        drawTorch(dc, _w - 22, _h * 28 / 100);

        var tc = (_tick % 16 < 8) ? 0xDD8833 : 0xBB6622;
        dc.setColor(0x221100, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, _h * 6 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 6 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 20 / 100, Graphics.FONT_LARGE, "AXE", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x7A5533, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 34 / 100, Graphics.FONT_XTINY, "VIKING THROW", Graphics.TEXT_JUSTIFY_CENTER);

        drawRotAxe(dc, _cx, _h * 48 / 100, _axeAngle, 18);

        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _h * 66 / 100, 14);
        dc.setColor(0x9A7A55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _h * 66 / 100, 12);
        dc.setColor(0x8A6A44, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _h * 66 / 100, 8);
        dc.drawCircle(_cx, _h * 66 / 100, 4);
        dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _h * 66 / 100, 2);

        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 75 / 100, Graphics.FONT_XTINY, "Tap to throw", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestScore > 0) {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 82 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0xDD8833 : 0xBB6622, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 90 / 100, Graphics.FONT_XTINY, "Tap to start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawBetween(dc) {
        dc.setColor(0x0E0A04, 0x0E0A04);
        dc.clear();
        for (var p = 0; p < _w; p += 18) {
            dc.setColor(0x1E140A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(p, 0, 16, _h);
        }
        drawSnow(dc, 0, 0);

        var fc = (_betweenTick % 8 < 4) ? 0xFFCC44 : 0xDDAA22;
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 10 / 100, Graphics.FONT_MEDIUM, "ROUND CLEAR", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 26 / 100, Graphics.FONT_XTINY, "SCORE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 30 / 100, Graphics.FONT_SMALL, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xDD8833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 44 / 100, Graphics.FONT_XTINY, "AXES STUCK " + _stuckCount + "/" + _throwsTotal, Graphics.TEXT_JUSTIFY_CENTER);

        if (_maxCombo > 1) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 52 / 100, Graphics.FONT_XTINY, "COMBO x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 62 / 100, Graphics.FONT_XTINY, "LIVES " + _lives, Graphics.TEXT_JUSTIFY_CENTER);

        if (_wave >= 2) {
            var hint = "Target moves!";
            if (_wave >= 5) { hint = "Faster target!"; }
            if (_wave >= 8) { hint = "Expert mode!"; }
            dc.setColor(0x5588AA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 72 / 100, Graphics.FONT_XTINY, hint, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_betweenTick > 25) {
            dc.setColor(0xDD8833, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 86 / 100, Graphics.FONT_XTINY, "Tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x0A0604, 0x0A0604);
        dc.clear();
        for (var p = 0; p < _w; p += 18) {
            dc.setColor(0x140E08, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(p, 0, 16, _h);
        }
        drawSnow(dc, 0, 0);

        if (_resultTick < 8) {
            dc.setColor(0x330000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, _w, _h);
        }

        var fc = (_resultTick % 6 < 3) ? 0xFF3333 : 0xCC1111;
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 8 / 100, Graphics.FONT_MEDIUM, "VALHALLA", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 21 / 100, Graphics.FONT_XTINY, "Your journey ends", Graphics.TEXT_JUSTIFY_CENTER);

        drawRotAxe(dc, _cx, _h * 34 / 100, _axeAngle, 16);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 44 / 100, Graphics.FONT_LARGE, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xDD8833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 58 / 100, Graphics.FONT_XTINY, "ROUND " + _wave, Graphics.TEXT_JUSTIFY_CENTER);

        if (_maxCombo > 1) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 66 / 100, Graphics.FONT_XTINY, "BEST COMBO x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 76 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - 5, _w, 5);
        for (var k = 0; k < _w; k += 10) {
            dc.setColor(0x8A6644, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(k + 2, _h - 4, 3, 3);
        }

        if (_resultTick > 25) {
            dc.setColor((_resultTick % 10 < 5) ? 0x777777 : 0x666666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
