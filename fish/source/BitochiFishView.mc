using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum {
    GS_MENU,
    GS_IDLE,
    GS_POWER,
    GS_CAST,
    GS_WAIT,
    GS_BITE,
    GS_FIGHT,
    GS_REEL,
    GS_CAUGHT,
    GS_LOST,
    GS_SNAP
}

class BitochiFishView extends WatchUi.View {

    var accelX;
    var accelY;
    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;
    hidden var _timer;
    hidden var _tick;

    hidden var _power;
    hidden var _powerDir;
    hidden var _castDist;
    hidden var _bobX;
    hidden var _bobY;
    hidden var _bobVy;
    hidden var _waterY;
    hidden var _rodTipX;
    hidden var _rodTipY;

    hidden var _waitTick;
    hidden var _biteTick;

    hidden var _fishX;
    hidden var _fishY;
    hidden var _fishVx;
    hidden var _fishVy;
    hidden var _fishType;
    hidden var _fishSize;
    hidden var _fishStr;
    hidden var _fishPullDir;
    hidden var _fishPullTimer;
    hidden var _fishHP;
    hidden var _fishMaxHP;

    hidden var _tension;
    hidden var _maxTension;
    hidden var _reelProg;
    hidden var _reelTarget;
    hidden var _lineLen;

    hidden var _score;
    hidden var _bestScore;
    hidden var _fishCaught;
    hidden var _combo;
    hidden var _level;
    hidden var _resultTick;
    hidden var _resultMsg;

    hidden var _shakeTimer;
    hidden var _shakeOx;
    hidden var _shakeOy;

    hidden const MAX_PARTS = 30;
    hidden var _partX;
    hidden var _partY;
    hidden var _partVx;
    hidden var _partVy;
    hidden var _partLife;
    hidden var _partColor;

    hidden const RIPPLE_N = 5;
    hidden var _ripX;
    hidden var _ripR;
    hidden var _ripLife;

    hidden var _waveOff;
    hidden var _cloudX;

    hidden var _fishNames;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _cx = _w / 2;
        _cy = _h / 2;
        accelX = 0; accelY = 0;
        _tick = 0;
        _waterY = _h * 48 / 100;
        _rodTipX = _w * 70 / 100;
        _rodTipY = _waterY - 15;
        _power = 0.0; _powerDir = 1;
        _castDist = 0.0;
        _bobX = 0.0; _bobY = 0.0; _bobVy = 0.0;
        _waitTick = 0; _biteTick = 0;
        _fishX = 0.0; _fishY = 0.0;
        _fishVx = 0.0; _fishVy = 0.0;
        _fishType = 0; _fishSize = 8; _fishStr = 1.0;
        _fishPullDir = 0.0; _fishPullTimer = 0;
        _fishHP = 100.0; _fishMaxHP = 100.0;
        _tension = 0.0; _maxTension = 100.0;
        _reelProg = 0.0; _reelTarget = 100.0;
        _lineLen = 0.0;
        _score = 0; _bestScore = 0;
        _fishCaught = 0; _combo = 0; _level = 1;
        _resultTick = 0; _resultMsg = "";
        _shakeTimer = 0; _shakeOx = 0; _shakeOy = 0;

        _partX = new [MAX_PARTS]; _partY = new [MAX_PARTS];
        _partVx = new [MAX_PARTS]; _partVy = new [MAX_PARTS];
        _partLife = new [MAX_PARTS]; _partColor = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) {
            _partLife[i] = 0; _partX[i] = 0.0; _partY[i] = 0.0;
            _partVx[i] = 0.0; _partVy[i] = 0.0; _partColor[i] = 0;
        }

        _ripX = new [RIPPLE_N]; _ripR = new [RIPPLE_N]; _ripLife = new [RIPPLE_N];
        for (var i = 0; i < RIPPLE_N; i++) { _ripX[i] = 0; _ripR[i] = 0.0; _ripLife[i] = 0; }

        _waveOff = 0.0;
        _cloudX = new [3];
        for (var i = 0; i < 3; i++) { _cloudX[i] = (Math.rand().abs() % _w).toFloat(); }

        _fishNames = ["Minnow", "Perch", "Bass", "Trout", "Pike", "Catfish", "Salmon", "Swordfish"];
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
        _waveOff += 0.08;
        if (_shakeTimer > 0) {
            _shakeOx = (Math.rand().abs() % 7) - 3;
            _shakeOy = (Math.rand().abs() % 5) - 2;
            _shakeTimer--;
        } else { _shakeOx = 0; _shakeOy = 0; }

        for (var i = 0; i < 3; i++) {
            _cloudX[i] += 0.12 + i.toFloat() * 0.05;
            if (_cloudX[i] > (_w + 30).toFloat()) { _cloudX[i] = -30.0; }
        }

        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            _partVy[i] += 0.1;
            _partX[i] += _partVx[i]; _partY[i] += _partVy[i];
            _partLife[i]--;
        }
        for (var i = 0; i < RIPPLE_N; i++) {
            if (_ripLife[i] <= 0) { continue; }
            _ripR[i] += 0.4; _ripLife[i]--;
        }

        if (gameState == GS_POWER) {
            _power += _powerDir.toFloat() * 2.5;
            if (_power >= 100.0) { _power = 100.0; _powerDir = -1; }
            if (_power <= 0.0) { _power = 0.0; _powerDir = 1; }
        } else if (gameState == GS_CAST) {
            _bobVy += 0.4;
            _bobX -= _castDist * 0.04;
            _bobY += _bobVy;
            if (_bobY >= _waterY.toFloat()) {
                _bobY = _waterY.toFloat();
                addRipple(_bobX.toNumber());
                spawnSplash(_bobX.toNumber(), _waterY);
                gameState = GS_WAIT;
                _waitTick = 40 + Math.rand().abs() % 80;
                doVibe(20, 30);
            }
        } else if (gameState == GS_WAIT) {
            _waitTick--;
            _bobY = _waterY.toFloat() + Math.sin(_tick.toFloat() * 0.15) * 1.5;
            if (_waitTick <= 0) {
                gameState = GS_BITE;
                _biteTick = 0;
                spawnFish();
                doVibe(50, 60);
            }
        } else if (gameState == GS_BITE) {
            _biteTick++;
            _bobY = _waterY.toFloat() + Math.sin(_tick.toFloat() * 0.5) * 3.0;
            if (_biteTick > 50) {
                gameState = GS_IDLE;
                _resultMsg = "TOO SLOW!";
                _resultTick = 40;
            }
        } else if (gameState == GS_FIGHT) {
            updateFight();
        } else if (gameState == GS_REEL) {
            _reelProg += 2.0;
            _fishX = _fishX * 0.95 + _rodTipX.toFloat() * 0.05;
            _fishY = _fishY * 0.95 + (_waterY - 10).toFloat() * 0.05;
            if (_reelProg >= _reelTarget) {
                gameState = GS_CAUGHT;
                _resultTick = 0;
                var pts = 50 + _fishType * 30 + _combo * 20;
                _score += pts;
                _fishCaught++;
                _combo++;
                if (_score > _bestScore) { _bestScore = _score; }
                _resultMsg = _fishNames[_fishType] + "!";
                spawnCatchParticles(_fishX.toNumber(), _fishY.toNumber());
                doVibe(80, 120);
                _shakeTimer = 5;
            }
        } else if (gameState == GS_CAUGHT || gameState == GS_LOST || gameState == GS_SNAP) {
            _resultTick++;
            if (_resultTick > 60) { gameState = GS_IDLE; }
        }

        WatchUi.requestUpdate();
    }

    hidden function spawnFish() {
        var maxType = 2 + _level;
        if (maxType > 7) { maxType = 7; }
        _fishType = Math.rand().abs() % (maxType + 1);
        _fishSize = 6 + _fishType * 2;
        _fishStr = 0.8 + _fishType.toFloat() * 0.25;
        _fishHP = 60.0 + _fishType.toFloat() * 20.0;
        _fishMaxHP = _fishHP;
        _fishX = _bobX;
        _fishY = _bobY + 15.0 + (Math.rand().abs() % 20).toFloat();
        _fishVx = 0.0; _fishVy = 0.0;
        _fishPullDir = (Math.rand().abs() % 360).toFloat();
        _fishPullTimer = 20 + Math.rand().abs() % 20;
        _tension = 40.0;
        _reelProg = 0.0;
        _reelTarget = 60.0 + _fishType.toFloat() * 15.0;
    }

    hidden function updateFight() {
        _fishPullTimer--;
        if (_fishPullTimer <= 0) {
            _fishPullDir = (Math.rand().abs() % 360).toFloat();
            _fishPullTimer = 12 + Math.rand().abs() % 25;
            if (Math.rand().abs() % 4 == 0) {
                _fishStr *= 1.3;
                if (_fishStr > 3.0) { _fishStr = 3.0; }
                doVibe(70, 80);
            }
        }

        var pullRad = _fishPullDir * 3.14159 / 180.0;
        var pullForce = _fishStr * (0.6 + Math.sin(_tick.toFloat() * 0.2) * 0.4);
        _fishVx = pullForce * Math.cos(pullRad);
        _fishVy = pullForce * Math.sin(pullRad) * 0.5;
        _fishX += _fishVx;
        _fishY += _fishVy;

        if (_fishX < 10.0) { _fishX = 10.0; }
        if (_fishX > (_w - 10).toFloat()) { _fishX = (_w - 10).toFloat(); }
        if (_fishY < (_waterY + 10).toFloat()) { _fishY = (_waterY + 10).toFloat(); }
        if (_fishY > (_h - 15).toFloat()) { _fishY = (_h - 15).toFloat(); }

        var playerForceX = accelX.toFloat() / 350.0;
        var playerForceY = accelY.toFloat() / 400.0;
        if (playerForceX > 2.0) { playerForceX = 2.0; }
        if (playerForceX < -2.0) { playerForceX = -2.0; }
        if (playerForceY > 1.5) { playerForceY = 1.5; }
        if (playerForceY < -1.5) { playerForceY = -1.5; }

        var dx = _fishX - _rodTipX.toFloat();
        var dy = _fishY - _rodTipY.toFloat();
        _lineLen = Math.sqrt(dx * dx + dy * dy);

        var fishPullMag = Math.sqrt(_fishVx * _fishVx + _fishVy * _fishVy);
        var counterDot = -(playerForceX * _fishVx + playerForceY * _fishVy);
        var counterEff = counterDot / (fishPullMag + 0.01);
        if (counterEff > 1.0) { counterEff = 1.0; }
        if (counterEff < -0.5) { counterEff = -0.5; }

        _tension += fishPullMag * 1.8 - counterEff * 2.5;
        _tension -= 0.3;
        if (_tension < 0.0) { _tension = 0.0; }
        if (_tension > _maxTension) { _tension = _maxTension; }

        if (counterEff > 0.3) {
            _fishHP -= 0.8 + counterEff * 0.5;
            _reelProg += 0.3 + counterEff * 0.4;
        } else {
            _fishHP -= 0.15;
        }

        if (_fishHP <= 0.0) {
            gameState = GS_REEL;
            doVibe(60, 80);
        }

        if (_tension >= _maxTension) {
            gameState = GS_SNAP;
            _resultTick = 0;
            _resultMsg = "LINE SNAPPED!";
            _combo = 0;
            spawnSnapParticles(_bobX.toNumber(), _waterY);
            doVibe(100, 150);
            _shakeTimer = 10;
        }

        if (_tension <= 2.0 && _fishHP > _fishMaxHP * 0.5) {
            if (_tick % 60 == 0 && Math.rand().abs() % 3 == 0) {
                gameState = GS_LOST;
                _resultTick = 0;
                _resultMsg = "GOT AWAY!";
                _combo = 0;
                doVibe(40, 60);
            }
        }

        if (_tick % 15 == 0 && fishPullMag > 1.0) {
            addRipple(_fishX.toNumber());
        }
        if (_tension > 70.0) {
            doVibe((((_tension - 70.0) / 30.0) * 40.0).toNumber() + 20, 30);
        }

        _bobX = _bobX * 0.92 + _fishX * 0.08;
        _bobY = _waterY.toFloat() + Math.sin(_tick.toFloat() * 0.3) * 2.0;
    }

    hidden function addRipple(rx) {
        for (var i = 0; i < RIPPLE_N; i++) {
            if (_ripLife[i] > 0) { continue; }
            _ripX[i] = rx;
            _ripR[i] = 2.0;
            _ripLife[i] = 18;
            break;
        }
    }

    hidden function spawnSplash(ex, ey) {
        var wc = [0x66AADD, 0x88CCEE, 0xAADDFF, 0x4488BB, 0x77BBDD];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 8) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat();
            _partY[i] = ey.toFloat();
            _partVx[i] = ((Math.rand().abs() % 20) - 10).toFloat() * 0.15;
            _partVy[i] = -1.5 - (Math.rand().abs() % 15).toFloat() * 0.12;
            _partLife[i] = 10 + Math.rand().abs() % 8;
            _partColor[i] = wc[Math.rand().abs() % 5];
            spawned++;
        }
    }

    hidden function spawnCatchParticles(ex, ey) {
        var cc = [0xFFFF44, 0xFFCC22, 0x88FF88, 0xFFFFAA, 0x44FFAA, 0xFFDD66];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 12) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.0 + (Math.rand().abs() % 25).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a);
            _partVy[i] = spd * Math.sin(a) - 1.0;
            _partLife[i] = 14 + Math.rand().abs() % 12;
            _partColor[i] = cc[Math.rand().abs() % 6];
            spawned++;
        }
    }

    hidden function spawnSnapParticles(ex, ey) {
        var sc = [0xFF4444, 0xFFAA44, 0xFFFF88, 0xFF6644, 0xFFCC44];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 10) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.5 + (Math.rand().abs() % 20).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a);
            _partVy[i] = spd * Math.sin(a);
            _partLife[i] = 10 + Math.rand().abs() % 10;
            _partColor[i] = sc[Math.rand().abs() % 5];
            spawned++;
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            var vp = new Attention.VibeProfile(intensity, duration);
            Attention.vibrate([vp]);
        }
    }

    function doAction() {
        if (gameState == GS_MENU) {
            _score = 0; _fishCaught = 0; _combo = 0; _level = 1;
            gameState = GS_IDLE;
            return;
        }
        if (gameState == GS_IDLE) {
            _power = 0.0; _powerDir = 1;
            gameState = GS_POWER;
            return;
        }
        if (gameState == GS_POWER) {
            _castDist = _power;
            _bobX = _rodTipX.toFloat();
            _bobY = _rodTipY.toFloat();
            _bobVy = -3.0 - _power * 0.04;
            gameState = GS_CAST;
            doVibe(30, 40);
            return;
        }
        if (gameState == GS_BITE) {
            gameState = GS_FIGHT;
            _resultMsg = "FIGHT!";
            _resultTick = 0;
            doVibe(40, 50);
            return;
        }
        if (gameState == GS_CAUGHT) {
            if (_resultTick > 20) {
                _level = 1 + _fishCaught / 3;
                if (_level > 6) { _level = 6; }
                gameState = GS_IDLE;
            }
            return;
        }
        if (gameState == GS_LOST || gameState == GS_SNAP) {
            if (_resultTick > 20) { gameState = GS_IDLE; }
            return;
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _waterY = _h * 48 / 100;
        _rodTipX = _w * 72 / 100;
        _rodTipY = _waterY - 14;

        if (gameState == GS_MENU) { drawMenu(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeOx;
        var oy = _shakeOy;

        drawSky(dc, ox, oy);
        drawWater(dc, ox, oy);
        drawRipples(dc, ox, oy);

        if (gameState == GS_FIGHT || gameState == GS_REEL) {
            drawFishUnder(dc, ox, oy);
        }

        drawBob(dc, ox, oy);
        drawRod(dc, ox, oy);
        drawLine(dc, ox, oy);
        drawParticles(dc, ox, oy);

        if (gameState == GS_POWER) { drawPowerBar(dc); }
        if (gameState == GS_WAIT) { drawWaitIndicator(dc); }
        if (gameState == GS_BITE) { drawBiteAlert(dc); }
        if (gameState == GS_FIGHT) { drawFightHUD(dc); }
        if (gameState == GS_REEL) { drawReelAnim(dc); }

        drawHUD(dc);

        if ((gameState == GS_CAUGHT || gameState == GS_LOST || gameState == GS_SNAP) && _resultTick < 50) {
            drawResultMsg(dc);
        }
        if (gameState == GS_CAUGHT && _resultTick < 40) {
            drawCaughtFish(dc, ox, oy);
        }
    }

    hidden function drawSky(dc, ox, oy) {
        dc.setColor(0x4488CC, 0x4488CC);
        dc.clear();
        dc.setColor(0x55AADD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _waterY * 40 / 100);
        dc.setColor(0x66BBEE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _waterY * 40 / 100, _w, _waterY * 30 / 100);
        dc.setColor(0x77CCEE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _waterY * 70 / 100, _w, _waterY - _waterY * 70 / 100);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(35 + ox, 25 + oy, 12);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(35 + ox, 25 + oy, 9);
        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(35 + ox, 25 + oy, 5);

        for (var i = 0; i < 3; i++) {
            var ccx = _cloudX[i].toNumber() + ox;
            var ccy = 14 + i * 12 + oy;
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx, ccy, 8 + i * 2);
            dc.fillCircle(ccx + 10, ccy + 1, 6 + i);
            dc.fillCircle(ccx - 8, ccy + 1, 5 + i);
        }

        var gy = _waterY + oy;
        dc.setColor(0x3A8A22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 68 / 100, gy - 25, _w * 32 / 100, 25);
        dc.setColor(0x4A9A30, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 68 / 100, gy - 25, _w * 32 / 100, 3);
        for (var g = _w * 68 / 100; g < _w; g += 4) {
            dc.setColor(0x5AAA38, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(g + ox, gy - 25, g + 1 + ox, gy - 28 - (g % 5));
        }

        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 75 / 100 + ox, gy - 50, 4, 25);
        dc.setColor(0x33AA44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 77 / 100 + ox, gy - 55, 12);
        dc.fillCircle(_w * 73 / 100 + ox, gy - 48, 8);
        dc.fillCircle(_w * 81 / 100 + ox, gy - 48, 9);
    }

    hidden function drawWater(dc, ox, oy) {
        var wy = _waterY + oy;
        dc.setColor(0x2266AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, wy, _w, _h - wy);

        for (var x = 0; x < _w; x += 3) {
            var wh = (Math.sin((x.toFloat() + _waveOff * 20.0) * 0.08) * 2.0).toNumber();
            dc.setColor(0x3388BB, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + ox, wy + wh, 3, 2);
        }

        dc.setColor(0x1A5599, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, wy + 4, _w, _h - wy - 4);

        for (var d = 0; d < 4; d++) {
            var dy = wy + 12 + d * 18;
            dc.setColor((d % 2 == 0) ? 0x1A4488 : 0x1A5599, Graphics.COLOR_TRANSPARENT);
            for (var x = 0; x < _w; x += 20) {
                var wx = x + ((_tick / 2 + d * 7) % 20) - 10;
                dc.fillRectangle(wx + ox, dy, 12, 1);
            }
        }

        dc.setColor(0x113366, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - 15, _w, 15);
        dc.setColor(0x8A7755, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - 8, _w, 8);
        dc.setColor(0x9A8866, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - 6, _w, 4);
        for (var r = 0; r < _w; r += 12) {
            dc.setColor(0x776644, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(r + 6, _h - 5, 2);
        }
    }

    hidden function drawRipples(dc, ox, oy) {
        for (var i = 0; i < RIPPLE_N; i++) {
            if (_ripLife[i] <= 0) { continue; }
            var rx = _ripX[i] + ox;
            var ry = _waterY + oy;
            var rr = _ripR[i].toNumber();
            dc.setColor((_ripLife[i] > 10) ? 0x4499CC : 0x3388BB, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(rx, ry, rr, Graphics.ARC_COUNTER_CLOCKWISE, 160, 20);
        }
    }

    hidden function drawBob(dc, ox, oy) {
        if (gameState == GS_IDLE || gameState == GS_POWER || gameState == GS_CAUGHT ||
            gameState == GS_LOST || gameState == GS_SNAP) { return; }
        var bx = _bobX.toNumber() + ox;
        var by = _bobY.toNumber() + oy;
        dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, 3);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by - 1, 2);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, 1);
    }

    hidden function drawRod(dc, ox, oy) {
        var gy = _waterY + oy;
        var baseX = _w - 8 + ox;
        var baseY = gy - 2;
        var tipX = _rodTipX + ox;
        var tipY = _rodTipY + oy;

        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(baseX, baseY, tipX, tipY);
        dc.drawLine(baseX + 1, baseY, tipX + 1, tipY);
        dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(baseX, baseY - 1, tipX, tipY - 1);

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tipX, tipY, 2);
        dc.setColor(0xAA8855, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(baseX - 1, baseY - 3, 4, 7);
    }

    hidden function drawLine(dc, ox, oy) {
        if (gameState == GS_IDLE || gameState == GS_POWER || gameState == GS_CAUGHT ||
            gameState == GS_LOST || gameState == GS_SNAP) { return; }
        var tipX = _rodTipX + ox;
        var tipY = _rodTipY + oy;
        var bx = _bobX.toNumber() + ox;
        var by = _bobY.toNumber() + oy;

        var lineC = 0x888888;
        if (gameState == GS_FIGHT && _tension > 70.0) {
            lineC = (_tick % 4 < 2) ? 0xFF4444 : 0xCC2222;
        } else if (gameState == GS_FIGHT && _tension > 40.0) {
            lineC = 0xCCAA44;
        }
        dc.setColor(lineC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tipX, tipY, bx, by);

        if (gameState == GS_FIGHT) {
            var sag = (_tension / _maxTension * 5.0).toNumber();
            var midX = (tipX + bx) / 2;
            var midY = (tipY + by) / 2 + sag;
            dc.drawLine(tipX, tipY, midX, midY);
            dc.drawLine(midX, midY, bx, by);
        }
    }

    hidden function drawFishUnder(dc, ox, oy) {
        var fx = _fishX.toNumber() + ox;
        var fy = _fishY.toNumber() + oy;
        var sz = _fishSize;
        var dir = (_fishVx >= 0) ? 1 : -1;

        dc.setColor(0x113355, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx + 2, fy + 2, sz + 1);

        var bodyC = 0x44AA66;
        if (_fishType == 0) { bodyC = 0x88AA88; }
        else if (_fishType == 1) { bodyC = 0x66BB66; }
        else if (_fishType == 2) { bodyC = 0x448844; }
        else if (_fishType == 3) { bodyC = 0xAA7766; }
        else if (_fishType == 4) { bodyC = 0x667766; }
        else if (_fishType == 5) { bodyC = 0x777788; }
        else if (_fishType == 6) { bodyC = 0xCC6655; }
        else { bodyC = 0x5566AA; }

        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx, fy, sz);
        dc.fillCircle(fx + dir * sz / 2, fy, sz * 80 / 100);
        dc.fillCircle(fx - dir * sz / 2, fy, sz * 70 / 100);

        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [fx - dir * sz, fy - sz / 3],
            [fx - dir * (sz + sz * 60 / 100), fy],
            [fx - dir * sz, fy + sz / 3]
        ]);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx + dir * (sz - 3), fy - 2, 2);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx + dir * (sz - 2), fy - 2, 1);

        if (_fishType >= 4) {
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                [fx, fy - sz + 1],
                [fx - 3, fy - sz - 4],
                [fx + 3, fy - sz - 4]
            ]);
        }
        if (_fishType == 7) {
            dc.setColor(0x6677BB, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx + dir * sz, fy - 1, dir * 6, 2);
        }
    }

    hidden function drawPowerBar(dc) {
        var barW = _w * 60 / 100;
        var barH = 10;
        var barX = (_w - barW) / 2;
        var barY = _h - 30;
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX - 1, barY - 1, barW + 2, barH + 2);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, barH);
        var fill = (_power / 100.0 * barW.toFloat()).toNumber();
        var fc = 0x44AA44;
        if (_power > 80.0) { fc = 0xFF4444; }
        else if (_power > 50.0) { fc = 0xFFAA44; }
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, fill, barH);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, barY - 14, Graphics.FONT_XTINY, "POWER", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawWaitIndicator(dc) {
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        var dots = (_tick / 10) % 4;
        var txt = "Waiting";
        for (var d = 0; d < dots; d++) { txt += "."; }
        dc.drawText(_cx, _h - 25, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawBiteAlert(dc) {
        var fc = (_tick % 4 < 2) ? 0xFF4444 : 0xFFAA22;
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy - 20, Graphics.FONT_SMALL, "BITE!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy, Graphics.FONT_XTINY, "TAP NOW!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFightHUD(dc) {
        var barW = _w * 55 / 100;
        var barX = (_w - barW) / 2;

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX - 1, 7, barW + 2, 8);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, 8, barW, 6);
        var tf = (_tension / _maxTension * barW.toFloat()).toNumber();
        var tc = 0x44AA44;
        if (_tension > 80.0) { tc = 0xFF2222; }
        else if (_tension > 60.0) { tc = 0xFF8822; }
        else if (_tension > 40.0) { tc = 0xFFCC44; }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, 8, tf, 6);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barX - 2, 5, Graphics.FONT_XTINY, "T", Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX - 1, 17, barW + 2, 7);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, 18, barW, 5);
        var hpFill = (_fishHP / _fishMaxHP * barW.toFloat()).toNumber();
        if (hpFill < 0) { hpFill = 0; }
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, 18, hpFill, 5);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h - 20, Graphics.FONT_XTINY, _fishNames[_fishType], Graphics.TEXT_JUSTIFY_CENTER);

        if (_tension > 75.0) {
            dc.setColor((_tick % 4 < 2) ? 0xFF2222 : 0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h - 32, Graphics.FONT_XTINY, "DANGER!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var arrowRad = _fishPullDir * 3.14159 / 180.0;
        var ax = _cx + (12.0 * Math.cos(arrowRad)).toNumber();
        var ay = _cy + (12.0 * Math.sin(arrowRad)).toNumber();
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx, _cy, ax, ay);
        dc.fillCircle(ax, ay, 2);
    }

    hidden function drawReelAnim(dc) {
        var fc = (_tick % 6 < 3) ? 0x44FF88 : 0x22CC66;
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy - 15, Graphics.FONT_SMALL, "REELING!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawResultMsg(dc) {
        var mc = 0xFFFF44;
        if (gameState == GS_SNAP) { mc = 0xFF4444; }
        else if (gameState == GS_LOST) { mc = 0xFF8844; }
        else if (gameState == GS_CAUGHT) { mc = 0x44FF88; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, _cy - 14, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy - 15, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
        if (gameState == GS_CAUGHT && _combo > 1) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy + 5, Graphics.FONT_XTINY, "COMBO x" + _combo, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawCaughtFish(dc, ox, oy) {
        var fx = _cx + ox;
        var fy = _waterY - 30 - _resultTick / 2 + oy;
        var sz = _fishSize + 2;
        var bodyC = 0x44AA66;
        if (_fishType == 0) { bodyC = 0x88AA88; }
        else if (_fishType == 1) { bodyC = 0x66BB66; }
        else if (_fishType == 2) { bodyC = 0x448844; }
        else if (_fishType == 3) { bodyC = 0xAA7766; }
        else if (_fishType == 4) { bodyC = 0x667766; }
        else if (_fishType == 5) { bodyC = 0x777788; }
        else if (_fishType == 6) { bodyC = 0xCC6655; }
        else { bodyC = 0x5566AA; }
        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx, fy, sz);
        dc.fillCircle(fx + sz / 2, fy, sz * 80 / 100);
        dc.fillPolygon([[fx - sz, fy - sz / 3], [fx - sz - sz * 60 / 100, fy], [fx - sz, fy + sz / 3]]);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx + sz - 3, fy - 2, 2);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx + sz - 2, fy - 2, 1);
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
        dc.drawText(_w - 5, _waterY - 12, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);
        if (_fishCaught > 0) {
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(5, _waterY - 12, Graphics.FONT_XTINY, "" + _fishCaught, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x4488CC, 0x4488CC);
        dc.clear();
        dc.setColor(0x55AADD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _waterY);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(35, 22, 10);
        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(35, 22, 6);

        for (var i = 0; i < 3; i++) {
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cloudX[i].toNumber(), 14 + i * 10, 7 + i);
            dc.fillCircle(_cloudX[i].toNumber() + 8, 15 + i * 10, 5 + i);
        }

        dc.setColor(0x2266AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _waterY, _w, _h - _waterY);
        for (var x = 0; x < _w; x += 3) {
            var wh = (Math.sin((x.toFloat() + _waveOff * 20.0) * 0.08) * 2.0).toNumber();
            dc.setColor(0x3388BB, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, _waterY + wh, 3, 2);
        }
        dc.setColor(0x1A5599, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _waterY + 4, _w, _h - _waterY - 4);

        dc.setColor(0x44AA66, Graphics.COLOR_TRANSPARENT);
        var fishMx = _cx + (Math.sin(_tick.toFloat() * 0.06) * 25.0).toNumber();
        var fishMy = _waterY + _h * 15 / 100;
        dc.fillCircle(fishMx, fishMy, 10);
        dc.fillCircle(fishMx + 6, fishMy, 8);
        dc.fillPolygon([[fishMx - 10, fishMy - 4], [fishMx - 16, fishMy], [fishMx - 10, fishMy + 4]]);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fishMx + 8, fishMy - 2, 2);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fishMx + 9, fishMy - 2, 1);

        var tc = (_tick % 14 < 7) ? 0x44CCFF : 0x33AADD;
        dc.setColor(0x112233, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, _h * 4 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 4 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 18 / 100, Graphics.FONT_LARGE, "FISH", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88CCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 32 / 100, Graphics.FONT_XTINY, "Cast & Catch!", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestScore > 0) {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 78 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to fish", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
