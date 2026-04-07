using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum {
    GS_MENU,
    GS_SWING,
    GS_FLY,
    GS_CATCH,
    GS_GAMEOVER
}

class BitochiSwingView extends WatchUi.View {

    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;
    hidden var _timer;
    hidden var _tick;

    hidden var _camX;
    hidden var _charX;
    hidden var _charY;
    hidden var _charVx;
    hidden var _charVy;

    hidden var _swingPhase;
    hidden var _swingSpeed;
    hidden var _maxAngle;
    hidden var _ropeLen;

    hidden var _curAX;
    hidden var _curAY;
    hidden var _curAType;
    hidden var _nextAX;
    hidden var _nextAY;
    hidden var _nextAType;
    hidden var _farAX;
    hidden var _farAY;
    hidden var _farAType;

    hidden var _groundY;
    hidden var _startX;
    hidden var _score;
    hidden var _bestScore;
    hidden var _distance;
    hidden var _bestDist;
    hidden var _combo;
    hidden var _maxCombo;
    hidden var _catches;
    hidden var _catchTick;
    hidden var _resultTick;
    hidden var _catchMsg;
    hidden var _catchMsgTick;

    hidden const MAX_PARTS = 20;
    hidden var _partX;
    hidden var _partY;
    hidden var _partVx;
    hidden var _partVy;
    hidden var _partLife;
    hidden var _partColor;

    hidden const FLY_N = 5;
    hidden var _flyWX;
    hidden var _flyY;
    hidden var _flyPh;

    hidden const TRAIL_N = 10;
    hidden var _trailX;
    hidden var _trailY;
    hidden var _trailLife;

    hidden var _shakeTimer;
    hidden var _shakeOx;
    hidden var _shakeOy;

    var accelX;
    var accelY;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _cx = _w / 2;
        _cy = _h / 2;
        _tick = 0;
        _camX = 0.0;
        _charX = 0.0; _charY = 0.0;
        _charVx = 0.0; _charVy = 0.0;
        _swingPhase = 0.0; _swingSpeed = 3.0;
        _maxAngle = 55.0; _ropeLen = 55.0;
        _curAX = 0.0; _curAY = 0.0; _curAType = 0;
        _nextAX = 0.0; _nextAY = 0.0; _nextAType = 0;
        _farAX = 0.0; _farAY = 0.0; _farAType = 0;
        _groundY = _h * 85 / 100;
        _startX = 0.0;
        _score = 0;
        var sbs = Application.Storage.getValue("swingBest");
        _bestScore = (sbs != null) ? sbs : 0;
        _distance = 0.0;
        var sbd = Application.Storage.getValue("swingDist");
        _bestDist = (sbd != null) ? sbd : 0.0;
        _combo = 0; _maxCombo = 0; _catches = 0;
        _catchTick = 0; _resultTick = 0;
        _catchMsg = ""; _catchMsgTick = 0;

        _partX = new [MAX_PARTS]; _partY = new [MAX_PARTS];
        _partVx = new [MAX_PARTS]; _partVy = new [MAX_PARTS];
        _partLife = new [MAX_PARTS]; _partColor = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) {
            _partLife[i] = 0; _partX[i] = 0.0; _partY[i] = 0.0;
            _partVx[i] = 0.0; _partVy[i] = 0.0; _partColor[i] = 0;
        }

        _flyWX = new [FLY_N]; _flyY = new [FLY_N]; _flyPh = new [FLY_N];
        for (var i = 0; i < FLY_N; i++) {
            _flyWX[i] = (Math.rand().abs() % (_w * 3)).toFloat();
            _flyY[i] = (_h * 25 / 100 + Math.rand().abs() % (_h * 45 / 100)).toFloat();
            _flyPh[i] = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
        }

        _trailX = new [TRAIL_N]; _trailY = new [TRAIL_N]; _trailLife = new [TRAIL_N];
        for (var i = 0; i < TRAIL_N; i++) {
            _trailX[i] = 0.0; _trailY[i] = 0.0; _trailLife[i] = 0;
        }

        _shakeTimer = 0; _shakeOx = 0; _shakeOy = 0;
        accelX = 0;
        accelY = 0;
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
            _shakeOx = (Math.rand().abs() % 7) - 3;
            _shakeOy = (Math.rand().abs() % 5) - 2;
            _shakeTimer--;
        } else { _shakeOx = 0; _shakeOy = 0; }

        if (_catchMsgTick > 0) { _catchMsgTick--; }

        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            _partVy[i] += 0.1;
            _partX[i] += _partVx[i]; _partY[i] += _partVy[i];
            _partLife[i]--;
        }

        for (var i = 0; i < FLY_N; i++) {
            _flyPh[i] += 0.04 + i.toFloat() * 0.008;
        }

        for (var i = 0; i < TRAIL_N; i++) {
            if (_trailLife[i] > 0) { _trailLife[i]--; }
        }

        if (gameState == GS_SWING) {
            updateSwing();
            updateCamera(true);
        } else if (gameState == GS_FLY) {
            updateFlight();
            updateTrail();
            updateCamera(false);
        } else if (gameState == GS_CATCH) {
            _catchTick++;
            updateCamera(true);
            if (_catchTick > 18) {
                var sv = 2.8 + _combo.toFloat() * 0.07;
                if (sv > 4.2) { sv = 4.2; }
                _swingPhase = -_maxAngle * 0.65;
                _swingSpeed = sv;
                gameState = GS_SWING;
            }
        } else if (gameState == GS_GAMEOVER) {
            _resultTick++;
        }

        recycleFireflies();
        WatchUi.requestUpdate();
    }

    hidden function updateSwing() {
        // Pendulum physics: _swingPhase = current angle (degrees from vertical)
        //                   _swingSpeed = angular velocity (degrees/tick)
        var aRad = _swingPhase * 3.14159 / 180.0;
        // Gravity restoring force
        var gravAcc = -0.28 * Math.sin(aRad);
        // Tilt input: directly adds angular acceleration (main control)
        var tilt = accelX.toFloat() / 195.0;
        if (tilt > 4.0) { tilt = 4.0; }
        if (tilt < -4.0) { tilt = -4.0; }
        _swingSpeed += gravAcc + tilt * 0.18;
        // Small damping
        _swingSpeed *= 0.994;
        // Angular velocity cap
        if (_swingSpeed > 5.5) { _swingSpeed = 5.5; }
        if (_swingSpeed < -5.5) { _swingSpeed = -5.5; }
        // Update angle
        _swingPhase += _swingSpeed;
        // Hard angle limit (prevents flipping over anchor)
        if (_swingPhase > _maxAngle) {
            _swingPhase = _maxAngle;
            if (_swingSpeed > 0.0) { _swingSpeed = -_swingSpeed * 0.3; }
        }
        if (_swingPhase < -_maxAngle) {
            _swingPhase = -_maxAngle;
            if (_swingSpeed < 0.0) { _swingSpeed = -_swingSpeed * 0.3; }
        }
        // Character position from actual angle
        aRad = _swingPhase * 3.14159 / 180.0;
        _charX = _curAX + _ropeLen * Math.sin(aRad);
        _charY = _curAY + _ropeLen * Math.cos(aRad);
        if (_charX > _distance + _startX) { _distance = _charX - _startX; }
    }

    hidden function updateCamera(onAnchor) {
        var tgt = onAnchor ? _curAX - _w.toFloat() * 0.35 : _charX - _w.toFloat() * 0.3;
        var blend = onAnchor ? 0.06 : 0.1;
        _camX = _camX * (1.0 - blend) + tgt * blend;
    }

    hidden function updateFlight() {
        var g = 0.125 + (_catches / 6).toFloat() * 0.006;
        if (g > 0.145) { g = 0.145; }
        _charVy += g;
        _charX += _charVx;
        _charY += _charVy;
        if (_charX - _startX > _distance) { _distance = _charX - _startX; }

        var dx = _charX - _nextAX;
        var dy = _charY - _nextAY.toFloat();
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < 30.0) { doCatch(); return; }

        if (_charY >= _groundY.toFloat()) { doLand(); }
        if (_charY > (_h + 30).toFloat()) { doLand(); }
    }

    hidden function updateTrail() {
        if (_tick % 2 != 0) { return; }
        for (var i = TRAIL_N - 1; i > 0; i--) {
            _trailX[i] = _trailX[i - 1];
            _trailY[i] = _trailY[i - 1];
            _trailLife[i] = _trailLife[i - 1];
        }
        _trailX[0] = _charX;
        _trailY[0] = _charY;
        _trailLife[0] = 12;
    }

    hidden function recycleFireflies() {
        for (var i = 0; i < FLY_N; i++) {
            if (_flyWX[i] < _camX - 40.0) {
                _flyWX[i] = _camX + _w.toFloat() + (Math.rand().abs() % 60).toFloat();
                _flyY[i] = (_h * 20 / 100 + Math.rand().abs() % (_h * 50 / 100)).toFloat();
            }
        }
    }

    hidden function releaseSwing() {
        // Velocity perpendicular to rope: v = ropeLen * angVel_rad
        // dX/dt = ropeLen * cos(angle) * angVel_rad
        // dY/dt = -ropeLen * sin(angle) * angVel_rad
        var aRad = _swingPhase * 3.14159 / 180.0;
        var velRad = _swingSpeed * 3.14159 / 180.0;
        _charVx = _ropeLen.toFloat() * Math.cos(aRad) * velRad;
        _charVy = -_ropeLen.toFloat() * Math.sin(aRad) * velRad;
        // Ensure minimum forward (rightward) progress
        if (_charVx < 1.0) { _charVx = 1.0; }

        for (var i = 0; i < TRAIL_N; i++) {
            _trailX[i] = _charX; _trailY[i] = _charY; _trailLife[i] = 0;
        }
        gameState = GS_FLY;
        doVibe(20, 25);
    }

    hidden function doCatch() {
        _catches++;
        _combo++;
        if (_combo > _maxCombo) { _maxCombo = _combo; }

        var dx = _charX - _nextAX;
        var dy = _charY - _nextAY.toFloat();
        var dist = Math.sqrt(dx * dx + dy * dy);
        var pts = 100 + _combo * 34 + (_catches / 4) * 8;
        if (dist < 8.0) {
            pts += 100;
            _catchMsg = "PERFECT!";
        } else if (dist < 16.0) {
            pts += 30;
            _catchMsg = "GREAT!";
        } else {
            _catchMsg = "NICE!";
        }
        if (_catches % 5 == 0) {
            pts += 220;
            _catchMsg = "MILESTONE!";
        }
        _catchMsgTick = 30;
        _score += pts;

        _curAX = _nextAX; _curAY = _nextAY; _curAType = _nextAType;
        _nextAX = _farAX; _nextAY = _farAY; _nextAType = _farAType;
        genFarAnchor();

        _ropeLen = 45.0 + (Math.rand().abs() % 25).toFloat();
        _maxAngle = 50.0 + _combo.toFloat() * 0.95 + (_combo / 4).toFloat() * 0.35;
        if (_maxAngle > 68.0) { _maxAngle = 68.0; }
        // _swingSpeed (angular velocity) is set on GS_CATCH → GS_SWING transition

        spawnMagic(_charX.toNumber(), _charY.toNumber());
        doVibe(60, 80);
        _shakeTimer = 3;
        gameState = GS_CATCH;
        _catchTick = 0;
    }

    hidden function doLand() {
        if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("swingBest", _bestScore); }
        if (_distance > _bestDist) { _bestDist = _distance; Application.Storage.setValue("swingDist", _bestDist); }
        _charY = _groundY.toFloat();
        spawnDust(_charX.toNumber(), _groundY);
        doVibe(80, 120);
        _shakeTimer = 8;
        gameState = GS_GAMEOVER;
        _resultTick = 0;
    }

    hidden function genFarAnchor() {
        var gap = 78.0 + _catches.toFloat() * 2.45 + (_catches / 3).toFloat() * 2.0;
        if (gap > 148.0) { gap = 148.0; }
        gap += (Math.rand().abs() % 32).toFloat();
        _farAX = _nextAX + gap;
        _farAY = _h * 18 / 100 + Math.rand().abs() % (_h * 22 / 100);
        _farAType = Math.rand().abs() % 3;
    }

    hidden function startGame() {
        _score = 0; _combo = 0; _maxCombo = 0; _catches = 0;
        _distance = 0.0; _catchMsg = ""; _catchMsgTick = 0;
        _startX = _w.toFloat() * 0.3;
        _curAX = _startX;
        _curAY = (_h * 28 / 100).toFloat();
        _curAType = 0;
        _nextAX = _curAX + 88.0 + (Math.rand().abs() % 28).toFloat();
        _nextAY = _h * 20 / 100 + Math.rand().abs() % (_h * 18 / 100);
        _nextAType = Math.rand().abs() % 3;
        genFarAnchor();
        _ropeLen = 55.0; _maxAngle = 55.0;
        // Start pulled to left side so the swing immediately heads toward next anchor (right)
        _swingPhase = -40.0; _swingSpeed = 2.8;
        _camX = _curAX - _w.toFloat() * 0.35;
        for (var i = 0; i < MAX_PARTS; i++) { _partLife[i] = 0; }
        for (var i = 0; i < TRAIL_N; i++) { _trailLife[i] = 0; }
        for (var i = 0; i < FLY_N; i++) {
            _flyWX[i] = _curAX + (Math.rand().abs() % (_w * 2)).toFloat() - 40.0;
            _flyY[i] = (_h * 25 / 100 + Math.rand().abs() % (_h * 45 / 100)).toFloat();
        }
        gameState = GS_SWING;
    }

    function doAction() {
        if (gameState == GS_MENU) { startGame(); return; }
        if (gameState == GS_SWING) { releaseSwing(); return; }
        if (gameState == GS_CATCH) {
            if (_catchTick > 8) {
                var sv = 2.8 + _combo.toFloat() * 0.07;
                if (sv > 4.2) { sv = 4.2; }
                _swingPhase = -_maxAngle * 0.65;
                _swingSpeed = sv;
                gameState = GS_SWING;
            }
            return;
        }
        if (gameState == GS_GAMEOVER) {
            if (_resultTick > 20) { startGame(); }
            return;
        }
    }

    hidden function spawnMagic(ex, ey) {
        var mc = [0x88FF88, 0x44FFAA, 0xAAFFCC, 0xFFFF88, 0x66FFDD, 0xCCFF66];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 8) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.0 + (Math.rand().abs() % 25).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a);
            _partVy[i] = spd * Math.sin(a) - 1.0;
            _partLife[i] = 14 + Math.rand().abs() % 14;
            _partColor[i] = mc[Math.rand().abs() % 6];
            spawned++;
        }
    }

    hidden function spawnDust(ex, ey) {
        var dc = [0x8A7755, 0xAA9966, 0x776644, 0xBBAA77, 0x665533];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 10) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat() + ((Math.rand().abs() % 10) - 5).toFloat();
            _partY[i] = ey.toFloat();
            _partVx[i] = ((Math.rand().abs() % 20) - 10).toFloat() * 0.15;
            _partVy[i] = -1.0 - (Math.rand().abs() % 15).toFloat() * 0.1;
            _partLife[i] = 12 + Math.rand().abs() % 10;
            _partColor[i] = dc[Math.rand().abs() % 5];
            spawned++;
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            var vp = new Toybox.Attention.VibeProfile(intensity, duration);
            Toybox.Attention.vibrate([vp]);
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _groundY = _h * 85 / 100;

        if (gameState == GS_MENU) { drawMenu(dc); return; }
        if (gameState == GS_GAMEOVER) { drawGameOver(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeOx;
        var oy = _shakeOy;
        var wOff = _camX.toNumber();

        drawSky(dc, ox, oy);
        drawMountains(dc, ox, oy);
        drawBgTrees(dc, ox, oy);
        drawGround(dc, ox, oy, wOff);
        drawFireflies(dc, ox, oy, wOff);

        drawAnchorSprite(dc, _farAX.toNumber() - wOff + ox, _farAY + oy, _farAType, false);
        drawAnchorSprite(dc, _nextAX.toNumber() - wOff + ox, _nextAY + oy, _nextAType, true);
        drawAnchorSprite(dc, _curAX.toNumber() - wOff + ox, _curAY.toNumber() + oy, _curAType, false);

        if (gameState == GS_SWING || gameState == GS_CATCH) {
            var csx = _charX.toNumber() - wOff + ox;
            var csy = _charY.toNumber() + oy;
            var asx = _curAX.toNumber() - wOff + ox;
            var asy = _curAY.toNumber() + oy;
            drawVine(dc, asx, asy, csx, csy);
            drawChar(dc, csx, csy, false);
        } else if (gameState == GS_FLY) {
            drawTrail(dc, wOff, ox, oy);
            var csx = _charX.toNumber() - wOff + ox;
            var csy = _charY.toNumber() + oy;
            drawChar(dc, csx, csy, true);
        }

        drawParticlesW(dc, wOff, ox, oy);
        drawHUD(dc);

        if (_catchMsgTick > 0) {
            var mc = 0x44FF88;
            if (_catchMsg.equals("PERFECT!")) { mc = 0xFFFF44; }
            else if (_catchMsg.equals("MILESTONE!")) { mc = 0xFFAA22; }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx + 1, _cy - 14, Graphics.FONT_SMALL, _catchMsg, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy - 15, Graphics.FONT_SMALL, _catchMsg, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawSky(dc, ox, oy) {
        dc.setColor(0x080820, 0x080820);
        dc.clear();
        dc.setColor(0x101035, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h * 30 / 100);
        dc.setColor(0x181845, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 30 / 100, _w, _h * 25 / 100);
        dc.setColor(0x1A2050, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 55 / 100, _w, _groundY - _h * 55 / 100);

        dc.setColor(0xEEEECC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 82 / 100 + ox, _h * 10 / 100 + oy, 11);
        dc.setColor(0x080820, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 82 / 100 + 4 + ox, _h * 10 / 100 - 3 + oy, 9);

        for (var s = 0; s < 12; s++) {
            var sx = (s * 53 + 17) % _w;
            var sy = (s * 37 + 11) % (_h * 55 / 100);
            dc.setColor((s % 4 == 0) ? 0x8888AA : 0x556688, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, 1);
        }
        if (_tick % 10 < 5) {
            dc.setColor(0xAAAACC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((_tick * 7 + 23) % _w, (_tick * 3 + 8) % (_h * 30 / 100), 1);
        }
    }

    hidden function drawMountains(dc, ox, oy) {
        var mOff = (_camX * 0.12).toNumber();
        var gy = _groundY + oy;
        for (var m = -90; m < _w + 90; m += 95) {
            var mx = m - (mOff % 75) + ox;
            var mh = 30 + ((m + mOff).abs() % 35);
            dc.setColor(0x1A1540, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[mx, gy], [mx + 38, gy - mh], [mx + 75, gy]]);
            dc.setColor(0x221A50, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[mx + 10, gy], [mx + 38, gy - mh + 6], [mx + 65, gy]]);
            dc.setColor(0xCCCCDD, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[mx + 33, gy - mh + 6], [mx + 38, gy - mh], [mx + 43, gy - mh + 6]]);
        }
    }

    hidden function drawBgTrees(dc, ox, oy) {
        var tOff = (_camX * 0.35).toNumber();
        var gy = _groundY + oy;
        for (var t = -40; t < _w + 55; t += 50) {
            var tx = t - (tOff % 38) + ox;
            var th = 22 + ((t + tOff).abs() % 20);
            dc.setColor(0x2A1A10, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - 2, gy - th, 4, th);
            dc.setColor(0x1A4020, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tx, gy - th - 5, 10);
            dc.fillCircle(tx - 6, gy - th + 1, 7);
            dc.fillCircle(tx + 6, gy - th + 1, 7);
            dc.setColor(0x225028, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tx + 2, gy - th - 3, 6);
        }
    }

    hidden function drawGround(dc, ox, oy, wOff) {
        var gy = _groundY + oy;
        dc.setColor(0x2A5A22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy, _w, _h - _groundY);
        dc.setColor(0x3A7A30, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy, _w, 3);
        dc.setColor(0x2A4A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy + 3, _w, 2);

        for (var g = 0; g < _w; g += 6) {
            var wg = g + wOff;
            dc.setColor((wg % 3 == 0) ? 0x4A9A35 : 0x3A7A28, Graphics.COLOR_TRANSPARENT);
            var gh = 3 + (wg.abs() % 6);
            dc.drawLine(g + ox, gy, g + ((wg % 2 == 0) ? 1 : -1) + ox, gy - gh);
        }

        var fStart = (wOff / 36) * 36;
        for (var fw = fStart; fw < fStart + _w + 40; fw += 36) {
            var fsx = fw - wOff + ox;
            if (fsx < -10 || fsx > _w + 10) { continue; }
            var ft = (fw / 25).abs() % 5;
            dc.setColor(0x338833, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(fsx, gy, fsx, gy - 5);
            if (ft == 0) { dc.setColor(0xFF66AA, Graphics.COLOR_TRANSPARENT); }
            else if (ft == 1) { dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT); }
            else if (ft == 2) { dc.setColor(0x66BBFF, Graphics.COLOR_TRANSPARENT); }
            else if (ft == 3) { dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT); }
            else { dc.setColor(0xDD66DD, Graphics.COLOR_TRANSPARENT); }
            dc.fillCircle(fsx, gy - 6, 2);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fsx, gy - 6, 1);
        }

        var mStart = (wOff / 60) * 60 + 10;
        for (var mw = mStart; mw < mStart + _w + 70; mw += 60) {
            var msx = mw - wOff + ox;
            if (msx < -15 || msx > _w + 15) { continue; }
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(msx, gy + 3, 5);
            dc.setColor(0xDD4444, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(msx, gy + 1, 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(msx - 2, gy, 1);
            dc.fillCircle(msx + 2, gy + 2, 1);
            dc.setColor(0xDDCCAA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(msx - 1, gy + 7, 3, 4);
        }
    }

    hidden function drawAnchorSprite(dc, sx, sy, atype, highlight) {
        if (sx < -30 || sx > _w + 30) { return; }
        var gy = _groundY + _shakeOy;

        if (atype == 0) {
            dc.setColor(0x4A2A12, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx + 4, sy, 5, gy - sy);
            dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx + 5, sy, 3, gy - sy);
            dc.setColor(0x6A4A22, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 14, sy - 2, 28, 5);
            dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 12, sy - 1, 24, 3);
            dc.setColor(0x33AA44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx - 10, sy - 5, 5);
            dc.fillCircle(sx + 8, sy - 4, 6);
            dc.fillCircle(sx - 3, sy - 7, 4);
            dc.setColor(0x44BB55, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx + 4, sy - 6, 4);
            dc.fillCircle(sx - 7, sy - 3, 3);
        } else if (atype == 1) {
            dc.setColor(0xDDCCAA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 3, sy + 5, 7, gy - sy - 5);
            dc.setColor(0xEEDDBB, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 2, sy + 5, 5, gy - sy - 5);
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, 11);
            dc.setColor(0xDD3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy - 2, 9);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx - 5, sy - 3, 2);
            dc.fillCircle(sx + 4, sy - 1, 2);
            dc.fillCircle(sx + 1, sy - 6, 2);
            dc.fillCircle(sx - 2, sy + 2, 1);
        } else {
            dc.setColor(0x2A1A44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 2, sy + 3, 5, gy - sy - 3);
            dc.setColor(0x6633AA, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - 14], [sx + 7, sy + 3], [sx - 7, sy + 3]]);
            dc.setColor(0x8855CC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - 11], [sx + 5, sy + 1], [sx - 5, sy + 1]]);
            dc.setColor(0xAA77EE, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx + 1, sy - 8], [sx + 3, sy - 1], [sx - 1, sy - 1]]);
            if (_tick % 5 < 3) {
                dc.setColor(0xBB99FF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(sx, sy - 5, 2);
            }
        }

        if (highlight) {
            var pulse = (_tick % 20 < 10) ? 3 : 2;
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(sx, sy, 14 + pulse);
            dc.drawCircle(sx, sy, 15 + pulse);
        }
    }

    hidden function drawVine(dc, ax, ay, cx, cy) {
        var midX = (ax + cx) / 2;
        var midY = (ay + cy) / 2;
        var sag = 4;
        dc.setColor(0x2A7733, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ax, ay, midX + sag, midY + sag);
        dc.drawLine(midX + sag, midY + sag, cx, cy);
        dc.setColor(0x339933, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ax + 1, ay, midX + sag + 1, midY + sag);
        dc.drawLine(midX + sag + 1, midY + sag, cx + 1, cy);
        dc.setColor(0x44BB44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(midX + 2, midY - 2, 2);
        dc.fillCircle(midX - 3, midY + (cy - ay) / 4, 2);
        dc.setColor(0x55CC55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ax + (cx - ax) / 4 + 1, ay + (cy - ay) / 4 - 1, 2);
    }

    hidden function drawChar(dc, sx, sy, flying) {
        dc.setColor(0x44AA55, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - 3, sy - 5, 6, 7);
        dc.setColor(0x55BB66, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - 2, sy - 4, 4, 5);

        dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy - 8, 3);
        dc.setColor(0xFFDDAA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy - 9, 2);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - 2, sy - 9, 1, 1);
        dc.fillRectangle(sx + 1, sy - 9, 1, 1);

        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[sx - 4, sy - 10], [sx, sy - 18], [sx + 4, sy - 10]]);
        dc.setColor(0xDD3333, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[sx - 3, sy - 10], [sx, sy - 16], [sx + 3, sy - 10]]);
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy - 17, 1);

        if (flying) {
            dc.setColor(0xAA2222, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx - 2, sy - 5], [sx - 9, sy], [sx - 7, sy + 5], [sx + 1, sy - 2]]);
            dc.setColor(0x44AA55, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx - 3, sy - 3, sx - 8, sy - 7);
            dc.drawLine(sx + 3, sy - 3, sx + 8, sy - 7);
            dc.setColor(0x335533, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx - 1, sy + 2, sx - 4, sy + 6);
            dc.drawLine(sx + 1, sy + 2, sx + 4, sy + 6);
            dc.setColor(0x5A3322, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 5, sy + 5, 3, 2);
            dc.fillRectangle(sx + 3, sy + 5, 3, 2);
        } else {
            dc.setColor(0xAA2222, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx - 2, sy - 5], [sx - 6, sy + 1], [sx + 1, sy - 2]]);
            dc.setColor(0x44AA55, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx - 3, sy - 4, sx - 1, sy - 9);
            dc.drawLine(sx + 3, sy - 4, sx + 1, sy - 9);
            dc.setColor(0x335533, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 2, sy + 2, 2, 3);
            dc.fillRectangle(sx + 1, sy + 2, 2, 3);
            dc.setColor(0x5A3322, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 3, sy + 5, 3, 2);
            dc.fillRectangle(sx + 1, sy + 5, 3, 2);
        }
    }

    hidden function drawTrail(dc, wOff, ox, oy) {
        for (var i = 0; i < TRAIL_N; i++) {
            if (_trailLife[i] <= 0) { continue; }
            var tsx = _trailX[i].toNumber() - wOff + ox;
            var tsy = _trailY[i].toNumber() + oy;
            dc.setColor((_trailLife[i] > 6) ? 0xAAFFAA : 0x66AA66, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tsx, tsy, (_trailLife[i] > 8) ? 2 : 1);
        }
    }

    hidden function drawFireflies(dc, ox, oy, wOff) {
        for (var i = 0; i < FLY_N; i++) {
            var fsx = _flyWX[i].toNumber() - wOff + ox;
            var fsy = _flyY[i].toNumber() + (Math.sin(_flyPh[i]) * 6.0).toNumber() + oy;
            if (fsx < -10 || fsx > _w + 10) { continue; }
            dc.setColor(0x889933, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fsx, fsy, 3);
            dc.setColor(0xCCFF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fsx, fsy, 2);
            dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fsx, fsy, 1);
        }
    }

    hidden function drawParticlesW(dc, wOff, ox, oy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            var psx = _partX[i].toNumber() - wOff + ox;
            var psy = _partY[i].toNumber() + oy;
            dc.setColor(_partColor[i], Graphics.COLOR_TRANSPARENT);
            var psz = (_partLife[i] > 7) ? 2 : 1;
            dc.fillRectangle(psx, psy, psz, psz);
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 5, 6, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(0x88FFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(5, 6, Graphics.FONT_XTINY, "" + _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_LEFT);

        if (_combo > 1) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h - 16, Graphics.FONT_XTINY, "x" + _combo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x77AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 5, Graphics.FONT_XTINY, "CATCH " + _catches, Graphics.TEXT_JUSTIFY_CENTER);

        // Tilt indicator during swing — helps player feel the control
        if (gameState == GS_SWING || gameState == GS_CATCH) {
            var tilt = accelX.toFloat() / 195.0;
            if (tilt > 4.0) { tilt = 4.0; }
            if (tilt < -4.0) { tilt = -4.0; }
            var bHalf = _w * 11 / 100;
            var bY = _h - 30;
            dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_cx - bHalf, bY, bHalf * 2, 4);
            var fill = (tilt / 4.0 * bHalf.toFloat()).toNumber();
            var barCol = (tilt > 0) ? 0x44FFAA : 0xFF7744;
            if (fill > 0) {
                dc.setColor(barCol, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_cx, bY, fill, 4);
            } else if (fill < 0) {
                dc.setColor(barCol, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_cx + fill, bY, -fill, 4);
            }
            dc.setColor(0x667788, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_cx - 1, bY - 1, 2, 6);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x080820, 0x080820);
        dc.clear();
        dc.setColor(0x101035, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h * 35 / 100);
        dc.setColor(0x181845, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 35 / 100, _w, _h * 30 / 100);

        dc.setColor(0xEEEECC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 80 / 100, _h * 10 / 100, 10);
        dc.setColor(0x080820, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 80 / 100 + 3, _h * 10 / 100 - 2, 8);

        for (var s = 0; s < 12; s++) {
            dc.setColor((s % 3 == 0) ? 0x7777AA : 0x445566, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((s * 53 + 17) % _w, (s * 37 + 11) % (_h * 50 / 100), 1);
        }

        dc.setColor(0x2A5A22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 72 / 100, _w, _h * 28 / 100);
        dc.setColor(0x3A7A30, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 72 / 100, _w, 3);
        for (var g = 0; g < _w; g += 5) {
            dc.setColor(0x4A9A35, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(g, _h * 72 / 100, g + 1, _h * 72 / 100 - 3 - (g % 4));
        }

        var swA = 50.0 * Math.sin(_tick.toFloat() * 0.08);
        var swRad = swA * 3.14159 / 180.0;
        var pvX = _cx;
        var pvY = _h * 22 / 100;
        var chX = pvX + (45.0 * Math.sin(swRad)).toNumber();
        var chY = pvY + (45.0 * Math.cos(swRad)).toNumber();

        drawAnchorSprite(dc, pvX, pvY, 0, false);
        drawVine(dc, pvX, pvY, chX, chY);
        drawChar(dc, chX, chY, false);

        for (var i = 0; i < 5; i++) {
            var ffx = (_tick * (i + 2) + i * 55) % _w;
            var ffy = _h * 40 / 100 + (Math.sin((_tick + i * 25).toFloat() * 0.1) * 12.0).toNumber();
            dc.setColor(0xCCFF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ffx, ffy, 2);
            dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ffx, ffy, 1);
        }

        var tc = (_tick % 14 < 7) ? 0x44EE66 : 0x33CC55;
        dc.setColor(0x112211, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, _h * 1 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 1 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 52 / 100, Graphics.FONT_LARGE, "SWING", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 64 / 100, Graphics.FONT_XTINY, "Enchanted Forest", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestScore > 0) {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 78 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0x44EE66 : 0x33CC55, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to play", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x080820, 0x080820);
        dc.clear();
        dc.setColor(0x101035, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h * 45 / 100);

        for (var s = 0; s < 8; s++) {
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((s * 53 + 17) % _w, (s * 37 + 11) % (_h * 40 / 100), 1);
        }

        dc.setColor(0x2A5A22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 72 / 100, _w, _h * 28 / 100);
        dc.setColor(0x3A7A30, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 72 / 100, _w, 2);

        var chSx = _cx;
        var chSy = _h * 72 / 100 - 3;
        dc.setColor(0x44AA55, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(chSx - 4, chSy - 1, 8, 4);
        dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(chSx + 5, chSy, 3);
        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[chSx + 7, chSy - 2], [chSx + 12, chSy - 5], [chSx + 8, chSy + 1]]);
        for (var st = 0; st < 3; st++) {
            var srad = (_resultTick * 5 + st * 120).toFloat() * 3.14159 / 180.0;
            var stx = chSx + 5 + (7.0 * Math.cos(srad)).toNumber();
            var sty = chSy - 7 + (3.0 * Math.sin(srad)).toNumber();
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(stx, sty, 1);
        }

        if (_resultTick < 8) {
            dc.setColor(0x220000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, _w, _h);
        }

        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 5 / 100, Graphics.FONT_MEDIUM, "FELL!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 20 / 100, Graphics.FONT_LARGE, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88FFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 36 / 100, Graphics.FONT_XTINY, "DIST " + _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 44 / 100, Graphics.FONT_XTINY, "CATCHES " + _catches, Graphics.TEXT_JUSTIFY_CENTER);

        if (_maxCombo > 1) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 52 / 100, Graphics.FONT_XTINY, "COMBO x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 62 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);

        if (_resultTick > 25) {
            dc.setColor((_resultTick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 85 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
