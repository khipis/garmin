using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum { GS_MENU, GS_IDLE, GS_POWER, GS_CAST, GS_WAIT, GS_BITE, GS_FIGHT, GS_REEL, GS_CAUGHT, GS_LOST, GS_SNAP }

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
    hidden var _waitMax;
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

    hidden var _approachX;
    hidden var _approachY;
    hidden var _approachPhase;

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
    hidden var _lastPts;

    hidden var _shakeTimer;
    hidden var _shakeOx;
    hidden var _shakeOy;
    hidden var _emotion;
    hidden var _lineTensionBonus;

    hidden const MAX_PARTS = 35;
    hidden var _partX;
    hidden var _partY;
    hidden var _partVx;
    hidden var _partVy;
    hidden var _partLife;
    hidden var _partColor;

    hidden const RIPPLE_N = 6;
    hidden var _ripX;
    hidden var _ripR;
    hidden var _ripLife;

    hidden var _waveOff;
    hidden var _cloudX;
    hidden var _cloudY;
    hidden var _fishNames;
    hidden var _birdX;
    hidden var _birdY;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _cx = _w / 2; _cy = _h / 2;
        accelX = 0; accelY = 0;
        _tick = 0;
        _waterY = _h * 50 / 100;
        _rodTipX = _w * 68 / 100;
        _rodTipY = _waterY - 16;
        _power = 0.0; _powerDir = 1; _castDist = 0.0;
        _bobX = 0.0; _bobY = 0.0; _bobVy = 0.0;
        _waitTick = 0; _waitMax = 60; _biteTick = 0;
        _fishX = 0.0; _fishY = 0.0; _fishVx = 0.0; _fishVy = 0.0;
        _fishType = 0; _fishSize = 8; _fishStr = 1.0;
        _fishPullDir = 0.0; _fishPullTimer = 0;
        _fishHP = 100.0; _fishMaxHP = 100.0;
        _approachX = 0.0; _approachY = 0.0; _approachPhase = 0;
        _tension = 0.0; _maxTension = 100.0;
        _reelProg = 0.0; _reelTarget = 100.0; _lineLen = 0.0;
        _score = 0;
        var bs = Application.Storage.getValue("fishBest");
        _bestScore = (bs != null) ? bs : 0;
        _fishCaught = 0; _combo = 0; _level = 1;
        _resultTick = 0; _resultMsg = ""; _lastPts = 0;
        _shakeTimer = 0; _shakeOx = 0; _shakeOy = 0;
        _emotion = 0;
        _lineTensionBonus = 0.0;

        _partX = new [MAX_PARTS]; _partY = new [MAX_PARTS];
        _partVx = new [MAX_PARTS]; _partVy = new [MAX_PARTS];
        _partLife = new [MAX_PARTS]; _partColor = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) { _partLife[i] = 0; _partX[i] = 0.0; _partY[i] = 0.0; _partVx[i] = 0.0; _partVy[i] = 0.0; _partColor[i] = 0; }

        _ripX = new [RIPPLE_N]; _ripR = new [RIPPLE_N]; _ripLife = new [RIPPLE_N];
        for (var i = 0; i < RIPPLE_N; i++) { _ripX[i] = 0; _ripR[i] = 0.0; _ripLife[i] = 0; }

        _waveOff = 0.0;
        _cloudX = new [4]; _cloudY = new [4];
        for (var i = 0; i < 4; i++) { _cloudX[i] = (Math.rand().abs() % _w).toFloat(); _cloudY[i] = 8 + Math.rand().abs() % 18; }
        _birdX = -20.0; _birdY = 15;

        _fishNames = ["Minnow", "Perch", "Bass", "Trout", "Pike", "Catfish", "Salmon", "Swordfish"];
        gameState = GS_MENU;
    }

    function onShow() { _timer = new Timer.Timer(); _timer.start(method(:onTick), 33, true); }
    function onHide() { if (_timer != null) { _timer.stop(); _timer = null; } }

    function onTick() as Void {
        _tick++;
        _waveOff += 0.08;
        _birdX += 0.4;
        if (_birdX > (_w + 30).toFloat()) { _birdX = -30.0; _birdY = 8 + Math.rand().abs() % 20; }
        if (_shakeTimer > 0) { _shakeOx = (Math.rand().abs() % 7) - 3; _shakeOy = (Math.rand().abs() % 5) - 2; _shakeTimer--; } else { _shakeOx = 0; _shakeOy = 0; }

        for (var i = 0; i < 4; i++) { _cloudX[i] += 0.1 + i * 0.04; if (_cloudX[i] > (_w + 35).toFloat()) { _cloudX[i] = -35.0; } }
        for (var i = 0; i < MAX_PARTS; i++) { if (_partLife[i] <= 0) { continue; } _partVy[i] += 0.1; _partX[i] += _partVx[i]; _partY[i] += _partVy[i]; _partLife[i]--; }
        for (var i = 0; i < RIPPLE_N; i++) { if (_ripLife[i] <= 0) { continue; } _ripR[i] += 0.45; _ripLife[i]--; }

        if (gameState == GS_POWER) {
            _power += _powerDir.toFloat() * 2.2;
            if (_power >= 100.0) { _power = 100.0; _powerDir = -1; }
            if (_power <= 0.0) { _power = 0.0; _powerDir = 1; }
        } else if (gameState == GS_CAST) {
            _bobVy += 0.4; _bobX -= _castDist * 0.04; _bobY += _bobVy;
            if (_bobY >= _waterY.toFloat()) {
                _bobY = _waterY.toFloat(); addRipple(_bobX.toNumber());
                spawnSplash(_bobX.toNumber(), _waterY);
                gameState = GS_WAIT;
                _waitMax = 50 + Math.rand().abs() % 60;
                _waitTick = _waitMax;
                _approachX = _bobX + ((Math.rand().abs() % 2 == 0) ? -60.0 : 60.0);
                _approachY = _waterY.toFloat() + 25.0 + (Math.rand().abs() % 20).toFloat();
                _approachPhase = 0;
                _emotion = 0;
                doVibe(20, 30);
            }
        } else if (gameState == GS_WAIT) {
            _waitTick--;
            _bobY = _waterY.toFloat() + Math.sin(_tick.toFloat() * 0.15) * 1.5;
            _approachPhase++;
            var pct = 1.0 - _waitTick.toFloat() / _waitMax.toFloat();
            _approachX = _approachX + (_bobX - _approachX) * 0.03;
            _approachY = _approachY + (_waterY.toFloat() + 12.0 - _approachY) * 0.02;
            if (pct > 0.7 && _tick % 20 == 0) { addRipple((_approachX + (Math.rand().abs() % 10) - 5).toNumber()); }
            if (_waitTick <= 0) {
                gameState = GS_BITE; _biteTick = 0;
                spawnFish(); doVibe(50, 60); _emotion = 1;
            }
        } else if (gameState == GS_BITE) {
            _biteTick++;
            _bobY = _waterY.toFloat() + Math.sin(_tick.toFloat() * 0.6) * 4.0;
            if (_biteTick % 8 == 0) { addRipple(_bobX.toNumber()); }
            if (_biteTick > 60) {
                gameState = GS_LOST; _resultMsg = "TOO SLOW!"; _resultTick = 0; _combo = 0; _emotion = 3;
            }
        } else if (gameState == GS_FIGHT) {
            updateFight();
        } else if (gameState == GS_REEL) {
            _reelProg += 2.5;
            _fishX = _fishX * 0.93 + _rodTipX.toFloat() * 0.07;
            _fishY = _fishY * 0.93 + (_waterY - 12).toFloat() * 0.07;
            if (_reelProg >= _reelTarget) {
                gameState = GS_CAUGHT; _resultTick = 0;
                var pts = 50 + _fishType * 40 + _combo * 25;
                _fishCaught++;
                if (_fishCaught % 5 == 0) {
                    pts += 80;
                    if (_lineTensionBonus < 28.0) {
                        _lineTensionBonus += 7.0;
                    }
                }
                _score += pts; _lastPts = pts; _combo++;
                if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("fishBest", _bestScore); }
                _resultMsg = _fishNames[_fishType] + "!";
                spawnCatchParts(_fishX.toNumber(), _fishY.toNumber());
                doVibe(80, 120); _shakeTimer = 6; _emotion = 2;
            }
        } else if (gameState == GS_CAUGHT || gameState == GS_LOST || gameState == GS_SNAP) {
            _resultTick++;
            if (_resultTick > 70) {
                if (gameState == GS_CAUGHT) { _level = 1 + _fishCaught / 3; if (_level > 12) { _level = 12; } }
                gameState = GS_IDLE; _emotion = 0;
            }
        }
        WatchUi.requestUpdate();
    }

    hidden function spawnFish() {
        var maxType = 2 + (_level + 1) / 2;
        if (maxType > 7) { maxType = 7; }
        var minType = 0;
        if (_level >= 4) { minType = 1; }
        if (_level >= 7) { minType = 2; }
        if (_level >= 10) { minType = 3; }
        if (minType > maxType) { minType = maxType; }
        _fishType = minType + Math.rand().abs() % (maxType - minType + 1);

        var roll = Math.rand().abs() % 100;
        if (_level >= 5 && roll < 18 && _fishType < maxType) { _fishType++; }
        if (_level >= 9 && roll < 10 && _fishType < maxType) { _fishType++; }

        _fishSize = 7 + _fishType * 2;
        var lvlF = _level.toFloat();
        _fishStr = 0.52 + _fishType.toFloat() * 0.17 + lvlF * 0.045;
        if (_fishStr > 2.42) { _fishStr = 2.42; }
        _fishHP = 44.0 + _fishType.toFloat() * 13.0 + lvlF * 3.5;
        _fishMaxHP = _fishHP;
        _fishX = _bobX; _fishY = _bobY + 15.0 + (Math.rand().abs() % 15).toFloat();
        _fishVx = 0.0; _fishVy = 0.0;
        _fishPullDir = (Math.rand().abs() % 360).toFloat();
        _fishPullTimer = 20 + Math.rand().abs() % 20;
        _maxTension = 100.0 + _lineTensionBonus;
        _tension = 28.0 + _lineTensionBonus * 0.25; _reelProg = 0.0;
        var lineEase = _lineTensionBonus * 0.22;
        _reelTarget = 48.0 + _fishType.toFloat() * 11.0 - lineEase;
        if (_reelTarget < 38.0) { _reelTarget = 38.0; }
    }

    hidden function updateFight() {
        _fishPullTimer--;
        if (_fishPullTimer <= 0) {
            _fishPullDir = (Math.rand().abs() % 360).toFloat();
            _fishPullTimer = 15 + Math.rand().abs() % 25;
            if (Math.rand().abs() % 5 == 0) {
                _fishStr *= 1.14; if (_fishStr > 2.45) { _fishStr = 2.45; }
                doVibe(60, 70);
            }
        }

        var pullRad = _fishPullDir * 3.14159 / 180.0;
        var pullForce = _fishStr * (0.5 + Math.sin(_tick.toFloat() * 0.2) * 0.3);
        _fishVx = pullForce * Math.cos(pullRad);
        _fishVy = pullForce * Math.sin(pullRad) * 0.5;
        _fishX += _fishVx; _fishY += _fishVy;

        if (_fishX < 10.0) { _fishX = 10.0; }
        if (_fishX > (_w - 10).toFloat()) { _fishX = (_w - 10).toFloat(); }
        if (_fishY < (_waterY + 8).toFloat()) { _fishY = (_waterY + 8).toFloat(); }
        if (_fishY > (_h - 12).toFloat()) { _fishY = (_h - 12).toFloat(); }

        var pFx = accelX.toFloat() / 300.0;
        var pFy = accelY.toFloat() / 350.0;
        if (pFx > 2.5) { pFx = 2.5; } if (pFx < -2.5) { pFx = -2.5; }
        if (pFy > 2.0) { pFy = 2.0; } if (pFy < -2.0) { pFy = -2.0; }

        var fishPullMag = Math.sqrt(_fishVx * _fishVx + _fishVy * _fishVy);
        var counterDot = -(pFx * _fishVx + pFy * _fishVy);
        var counterEff = counterDot / (fishPullMag + 0.01);
        if (counterEff > 1.0) { counterEff = 1.0; }
        if (counterEff < -0.5) { counterEff = -0.5; }

        var pullScale = 1.12 - _lineTensionBonus * 0.004;
        if (pullScale < 0.92) { pullScale = 0.92; }
        _tension += fishPullMag * pullScale - counterEff * 2.0;
        _tension -= 0.48 + _lineTensionBonus * 0.002;
        if (_tension < 0.0) { _tension = 0.0; }
        if (_tension > _maxTension) { _tension = _maxTension; }

        if (counterEff > 0.2) {
            _fishHP -= 1.0 + counterEff * 0.8;
            _reelProg += 0.4 + counterEff * 0.5;
        } else {
            _fishHP -= 0.3;
            _reelProg += 0.08;
        }

        _emotion = (_tension > 70.0) ? 3 : ((_tension > 40.0) ? 1 : 0);

        if (_fishHP <= 0.0) { gameState = GS_REEL; doVibe(60, 80); _emotion = 2; }
        if (_tension >= _maxTension) {
            gameState = GS_SNAP; _resultTick = 0; _resultMsg = "LINE SNAPPED!";
            _combo = 0; spawnSnapParts(_bobX.toNumber(), _waterY);
            doVibe(100, 150); _shakeTimer = 10; _emotion = 3;
        }

        if (_tick % 12 == 0 && fishPullMag > 0.8) { addRipple(_fishX.toNumber()); }
        if (_tension > 70.0) { doVibe((((_tension - 70.0) / 30.0) * 35.0).toNumber() + 15, 25); }

        _bobX = _bobX * 0.9 + _fishX * 0.1;
        _bobY = _waterY.toFloat() + Math.sin(_tick.toFloat() * 0.3) * 2.5;
    }

    function doAction() {
        if (gameState == GS_MENU) { _score = 0; _fishCaught = 0; _combo = 0; _level = 1; _lineTensionBonus = 0.0; gameState = GS_IDLE; return; }
        if (gameState == GS_IDLE) { _power = 0.0; _powerDir = 1; gameState = GS_POWER; return; }
        if (gameState == GS_POWER) {
            _castDist = _power; _bobX = _rodTipX.toFloat(); _bobY = _rodTipY.toFloat();
            _bobVy = -3.0 - _power * 0.04; gameState = GS_CAST; doVibe(30, 40); return;
        }
        if (gameState == GS_BITE) { gameState = GS_FIGHT; _resultMsg = "FIGHT!"; _resultTick = 0; doVibe(40, 50); _emotion = 1; return; }
        if (gameState == GS_FIGHT) {
            _reelProg += 1.5; _fishHP -= 1.5;
            if (_fishHP <= 0.0) { gameState = GS_REEL; doVibe(60, 80); _emotion = 2; }
            return;
        }
        if (gameState == GS_CAUGHT) { if (_resultTick > 15) { _level = 1 + _fishCaught / 3; if (_level > 12) { _level = 12; } gameState = GS_IDLE; } return; }
        if (gameState == GS_LOST || gameState == GS_SNAP) { if (_resultTick > 15) { gameState = GS_IDLE; _emotion = 0; } return; }
    }

    hidden function addRipple(rx) { for (var i = 0; i < RIPPLE_N; i++) { if (_ripLife[i] > 0) { continue; } _ripX[i] = rx; _ripR[i] = 2.0; _ripLife[i] = 20; break; } }

    hidden function spawnSplash(ex, ey) {
        var wc = [0x66AADD, 0x88CCEE, 0xAADDFF, 0x4488BB, 0x77BBDD];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) { if (spawned >= 10) { break; } if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat(); _partY[i] = ey.toFloat();
            _partVx[i] = ((Math.rand().abs() % 24) - 12).toFloat() * 0.15;
            _partVy[i] = -1.8 - (Math.rand().abs() % 18).toFloat() * 0.12;
            _partLife[i] = 12 + Math.rand().abs() % 10; _partColor[i] = wc[Math.rand().abs() % 5]; spawned++;
        }
    }

    hidden function spawnCatchParts(ex, ey) {
        var cc = [0xFFFF44, 0xFFCC22, 0x88FF88, 0xFFFFAA, 0x44FFAA, 0xFFDD66];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) { if (spawned >= 14) { break; } if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat(); _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.2 + (Math.rand().abs() % 30).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a); _partVy[i] = spd * Math.sin(a) - 1.2;
            _partLife[i] = 16 + Math.rand().abs() % 14; _partColor[i] = cc[Math.rand().abs() % 6]; spawned++;
        }
    }

    hidden function spawnSnapParts(ex, ey) {
        var sc = [0xFF4444, 0xFFAA44, 0xFFFF88, 0xFF6644, 0xFFCC44];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) { if (spawned >= 12) { break; } if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat(); _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.8 + (Math.rand().abs() % 25).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a); _partVy[i] = spd * Math.sin(a);
            _partLife[i] = 12 + Math.rand().abs() % 12; _partColor[i] = sc[Math.rand().abs() % 5]; spawned++;
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) { if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
        } }
    }

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight(); _cx = _w / 2; _cy = _h / 2;
        _waterY = _h * 50 / 100;
        _rodTipX = _w * 68 / 100; _rodTipY = _waterY - 16;
        if (gameState == GS_MENU) { drawMenu(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeOx; var oy = _shakeOy;
        drawSky(dc, ox, oy);
        drawWater(dc, ox, oy);
        drawRipples(dc, ox, oy);
        if (gameState == GS_WAIT) { drawApproachFish(dc, ox, oy); }
        if (gameState == GS_FIGHT || gameState == GS_REEL || gameState == GS_BITE) { drawFishUnder(dc, ox, oy); }
        drawBob(dc, ox, oy);
        drawFisherman(dc, ox, oy);
        drawLine(dc, ox, oy);
        drawParticles(dc, ox, oy);

        if (gameState == GS_POWER) { drawPowerBar(dc); }
        if (gameState == GS_WAIT) { drawWaitInd(dc); }
        if (gameState == GS_BITE) { drawBiteAlert(dc); }
        if (gameState == GS_FIGHT) { drawFightHUD(dc); }
        if (gameState == GS_REEL) { drawReelAnim(dc); }
        drawHUD(dc);
        if ((gameState == GS_CAUGHT || gameState == GS_LOST || gameState == GS_SNAP) && _resultTick < 60) { drawResultMsg(dc); }
        if (gameState == GS_CAUGHT && _resultTick < 50) { drawCaughtFish(dc, ox, oy); }
    }

    hidden function drawSky(dc, ox, oy) {
        dc.setColor(0x3388CC, 0x3388CC); dc.clear();
        dc.setColor(0x44AADD, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, 0, _w, _waterY * 35 / 100);
        dc.setColor(0x55BBEE, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _waterY * 35 / 100, _w, _waterY * 30 / 100);
        dc.setColor(0x66CCEE, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _waterY * 65 / 100, _w, _waterY - _waterY * 65 / 100);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(30 + ox, 22 + oy, 14);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT); dc.fillCircle(30 + ox, 22 + oy, 10);
        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT); dc.fillCircle(30 + ox, 22 + oy, 6);
        for (var r = 0; r < 8; r++) {
            var ra = (r * 45 + _tick * 2) % 360;
            var rr = ra.toFloat() * 3.14159 / 180.0;
            dc.setColor(0xFFDD66, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(30 + ox + (15.0 * Math.cos(rr)).toNumber(), 22 + oy + (15.0 * Math.sin(rr)).toNumber(),
                        30 + ox + (19.0 * Math.cos(rr)).toNumber(), 22 + oy + (19.0 * Math.sin(rr)).toNumber());
        }

        for (var i = 0; i < 4; i++) {
            var ccx = _cloudX[i].toNumber() + ox; var ccy = _cloudY[i] + oy;
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx, ccy, 9 + i * 2); dc.fillCircle(ccx + 11, ccy + 1, 7 + i); dc.fillCircle(ccx - 9, ccy + 1, 6 + i);
            dc.setColor(0xEEF4FF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ccx + 4, ccy - 2, 5 + i);
        }

        var bx = _birdX.toNumber() + ox;
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(bx - 4, _birdY + oy, bx, _birdY - 2 + oy); dc.drawLine(bx, _birdY - 2 + oy, bx + 4, _birdY + oy);

        var gy = _waterY + oy;
        dc.setColor(0x3A8A22, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w * 65 / 100, gy - 28, _w * 35 / 100, 28);
        dc.setColor(0x4A9A30, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w * 65 / 100, gy - 28, _w * 35 / 100, 3);
        for (var g = _w * 65 / 100; g < _w; g += 3) {
            dc.setColor(0x5AAA38, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(g + ox, gy - 28, g + 1 + ox, gy - 31 - (g % 5));
        }
        for (var f = 0; f < 5; f++) {
            var fx = _w * 67 / 100 + f * 8; var ftop = gy - 28 - 3 - (f % 3) * 2;
            dc.setColor((f % 2 == 0) ? 0xFF4466 : 0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fx + ox, ftop, 2);
            dc.setColor(0x33AA33, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(fx + ox, ftop + 2, fx + ox, gy - 28);
        }

        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 80 / 100 + ox, gy - 55, 5, 27);
        dc.setColor(0x33AA44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 82 / 100 + ox, gy - 58, 14);
        dc.fillCircle(_w * 77 / 100 + ox, gy - 50, 10);
        dc.fillCircle(_w * 87 / 100 + ox, gy - 50, 11);
        dc.setColor(0x44BB55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 80 / 100 + ox, gy - 55, 8);

        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 94 / 100 + ox, gy - 38, 3, 10);
        dc.setColor(0x33AA44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 95 / 100 + ox, gy - 40, 7);
    }

    hidden function drawWater(dc, ox, oy) {
        var wy = _waterY + oy;
        dc.setColor(0x2266AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, wy, _w, _h - wy);
        for (var x = 0; x < _w; x += 3) {
            var wh = (Math.sin((x.toFloat() + _waveOff * 20.0) * 0.08) * 2.5).toNumber();
            dc.setColor(0x3388BB, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(x + ox, wy + wh, 3, 3);
            dc.setColor(0x44AABB, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(x + ox, wy + wh, 3, 1);
        }
        dc.setColor(0x1A5599, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, wy + 5, _w, _h - wy - 5);
        for (var d = 0; d < 5; d++) {
            var dy = wy + 14 + d * 15;
            dc.setColor((d % 2 == 0) ? 0x1A4488 : 0x1A5599, Graphics.COLOR_TRANSPARENT);
            for (var x = 0; x < _w; x += 18) { dc.fillRectangle((x + (_tick / 2 + d * 7) % 18 - 9) + ox, dy, 10, 1); }
        }

        for (var lp = 0; lp < 3; lp++) {
            var lpx = (_w * 15 / 100 + lp * _w * 22 / 100) + ox;
            var lpy = wy + 2;
            dc.setColor(0x227744, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lpx, lpy, 6); dc.fillCircle(lpx + 4, lpy - 1, 5); dc.fillCircle(lpx - 3, lpy + 1, 4);
            dc.setColor(0x33AA55, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lpx + 1, lpy - 1, 3);
        }

        dc.setColor(0x113366, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h - 14, _w, 14);
        dc.setColor(0x8A7755, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h - 8, _w, 8);
        dc.setColor(0x9A8866, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h - 6, _w, 4);
        for (var r = 0; r < _w; r += 10) { dc.setColor(0x776644, Graphics.COLOR_TRANSPARENT); dc.fillCircle(r + 5, _h - 5, 2); }

        for (var rd = 0; rd < 2; rd++) {
            var rx = _w * 8 / 100 + rd * _w * 50 / 100 + ox;
            dc.setColor(0x337722, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(rx, wy - 2, rx, wy - 14); dc.drawLine(rx + 2, wy - 1, rx + 3, wy - 12);
            dc.drawLine(rx - 1, wy - 1, rx - 2, wy - 11);
            dc.setColor(0x448833, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(rx + 4, wy - 2, rx + 5, wy - 10);
        }
    }

    hidden function drawRipples(dc, ox, oy) {
        for (var i = 0; i < RIPPLE_N; i++) {
            if (_ripLife[i] <= 0) { continue; }
            var rx = _ripX[i] + ox; var ry = _waterY + oy;
            dc.setColor((_ripLife[i] > 12) ? 0x4499CC : 0x3388BB, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(rx, ry, _ripR[i].toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 160, 20);
        }
    }

    hidden function drawApproachFish(dc, ox, oy) {
        var pct = 1.0 - _waitTick.toFloat() / _waitMax.toFloat();
        if (pct < 0.2) { return; }
        var fx = _approachX.toNumber() + ox;
        var fy = _approachY.toNumber() + oy;
        var sz = 5 + (pct * 4.0).toNumber();
        var alpha = (pct > 0.5) ? 0x448866 : 0x336655;
        dc.setColor(alpha, Graphics.COLOR_TRANSPARENT);
        var dir = (_approachX < _bobX) ? 1 : -1;
        dc.fillCircle(fx, fy, sz);
        dc.fillCircle(fx + dir * sz / 2, fy, sz * 3 / 4);
        dc.fillPolygon([[fx - dir * sz, fy - sz / 3], [fx - dir * (sz + sz / 2), fy], [fx - dir * sz, fy + sz / 3]]);
        if (pct > 0.6) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fx + dir * (sz - 2), fy - 1, 1);
        }
    }

    hidden function drawBob(dc, ox, oy) {
        if (gameState == GS_IDLE || gameState == GS_POWER || gameState == GS_CAUGHT || gameState == GS_LOST || gameState == GS_SNAP) { return; }
        var bx = _bobX.toNumber() + ox; var by = _bobY.toNumber() + oy;
        dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bx, by, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bx, by - 1, 2);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bx, by, 1);
    }

    hidden function drawFisherman(dc, ox, oy) {
        var gy = _waterY + oy;
        var fx = _w - 14 + ox;
        var fy = gy - 3;

        dc.setColor(0x3A5A28, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fx - 6, fy - 4, 14, 4);

        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx, fy - 18, 7);

        dc.setColor(0x886633, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fx - 8, fy - 27, 16, 5);
        dc.fillRectangle(fx - 6, fy - 25, 12, 3);

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        var lex = fx - 2; var rex = fx + 3; var eey = fy - 19;
        if (_emotion == 0) {
            dc.fillCircle(lex, eey, 1); dc.fillCircle(rex, eey, 1);
            dc.fillRectangle(fx - 2, fy - 14, 4, 1);
        } else if (_emotion == 1) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lex, eey, 2); dc.fillCircle(rex, eey, 2);
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lex, eey, 1); dc.fillCircle(rex, eey, 1);
            dc.fillRectangle(fx - 2, fy - 13, 4, 2);
        } else if (_emotion == 2) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(lex - 1, eey - 1, lex + 1, eey + 1);
            dc.drawLine(rex - 1, eey - 1, rex + 1, eey + 1);
            dc.drawLine(fx - 2, fy - 14, fx + 2, fy - 14);
            dc.drawLine(fx - 3, fy - 15, fx + 3, fy - 14);
        } else {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lex, eey, 2); dc.fillCircle(rex, eey, 2);
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lex, eey, 1); dc.fillCircle(rex, eey, 1);
            dc.fillCircle(fx, fy - 13, 2);
        }

        dc.setColor(0x3366AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fx - 5, fy - 10, 10, 12);
        dc.setColor(0x2255AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fx - 5, fy - 10, 2, 12);

        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fx - 7, fy - 8, 3, 3);
        dc.fillRectangle(fx + 5, fy - 7, 3, 3);

        dc.setColor(0x444466, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fx - 4, fy + 2, 4, 6);
        dc.fillRectangle(fx + 1, fy + 2, 4, 6);
        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fx - 5, fy + 7, 5, 2);
        dc.fillRectangle(fx + 1, fy + 7, 5, 2);

        var tipX = _rodTipX + ox; var tipY = _rodTipY + oy;
        var handX = fx - 7; var handY = fy - 7;
        dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(handX, handY, tipX, tipY);
        dc.drawLine(handX, handY - 1, tipX, tipY - 1);
        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(handX + 1, handY, tipX + 1, tipY);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tipX, tipY, 2);
    }

    hidden function drawLine(dc, ox, oy) {
        if (gameState == GS_IDLE || gameState == GS_POWER || gameState == GS_CAUGHT || gameState == GS_LOST || gameState == GS_SNAP) { return; }
        var tipX = _rodTipX + ox; var tipY = _rodTipY + oy;
        var bx = _bobX.toNumber() + ox; var by = _bobY.toNumber() + oy;
        var lineC = 0x999999;
        if (gameState == GS_FIGHT && _tension > 70.0) { lineC = (_tick % 4 < 2) ? 0xFF4444 : 0xCC2222; }
        else if (gameState == GS_FIGHT && _tension > 40.0) { lineC = 0xCCAA44; }
        dc.setColor(lineC, Graphics.COLOR_TRANSPARENT);
        if (gameState == GS_FIGHT) {
            var sag = (_tension / _maxTension * 6.0).toNumber();
            var mx = (tipX + bx) / 2; var my = (tipY + by) / 2 + sag;
            dc.drawLine(tipX, tipY, mx, my); dc.drawLine(mx, my, bx, by);
        } else {
            dc.drawLine(tipX, tipY, bx, by);
        }
    }

    hidden function drawFishUnder(dc, ox, oy) {
        var fx = _fishX.toNumber() + ox; var fy = _fishY.toNumber() + oy;
        var sz = _fishSize; var dir = (_fishVx >= 0) ? 1 : -1;

        dc.setColor(0x113355, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + 2, fy + 2, sz + 1);

        var bodyC = getFishColor();
        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx, fy, sz); dc.fillCircle(fx + dir * sz / 2, fy, sz * 80 / 100);
        dc.fillCircle(fx - dir * sz / 2, fy, sz * 70 / 100);
        dc.fillPolygon([[fx - dir * sz, fy - sz / 3], [fx - dir * (sz + sz * 60 / 100), fy], [fx - dir * sz, fy + sz / 3]]);

        var bellyC = bodyC + 0x222222;
        dc.setColor(bellyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx, fy + sz / 3, sz * 50 / 100);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + dir * (sz - 3), fy - 2, 3);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + dir * (sz - 2), fy - 2, 1);

        if (_fishType >= 4) {
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[fx, fy - sz + 1], [fx - 4, fy - sz - 5], [fx + 4, fy - sz - 5]]);
        }
        if (_fishType == 7) {
            dc.setColor(0x6677BB, Graphics.COLOR_TRANSPARENT);
            var swordX = (dir >= 0) ? fx + sz : fx - sz - 8;
            dc.fillRectangle(swordX, fy - 1, 8, 2);
        }

        if (gameState == GS_FIGHT && _fishHP > 0) {
            var hpW = sz * 2;
            var hpFill = (_fishHP / _fishMaxHP * hpW.toFloat()).toNumber();
            if (hpFill < 0) { hpFill = 0; }
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - sz, fy - sz - 6, hpW, 3);
            dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - sz, fy - sz - 6, hpFill, 3);
        }
    }

    hidden function getFishColor() {
        if (_fishType == 0) { return 0x88AA88; }
        if (_fishType == 1) { return 0x66BB66; }
        if (_fishType == 2) { return 0x448844; }
        if (_fishType == 3) { return 0xCC8866; }
        if (_fishType == 4) { return 0x667766; }
        if (_fishType == 5) { return 0x777799; }
        if (_fishType == 6) { return 0xDD7766; }
        return 0x5577BB;
    }

    hidden function drawPowerBar(dc) {
        var bW = _w * 55 / 100; var bH = 10; var bX = (_w - bW) / 2; var bY = _h - 28;
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX - 1, bY - 1, bW + 2, bH + 2);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX, bY, bW, bH);
        var fill = (_power / 100.0 * bW.toFloat()).toNumber();
        var fc = (_power > 80.0) ? 0xFF4444 : ((_power > 50.0) ? 0xFFAA44 : 0x44AA44);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX, bY, fill, bH);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, bY - 14, Graphics.FONT_XTINY, "POWER", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawWaitInd(dc) {
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        var dots = (_tick / 8) % 4; var txt = "Waiting";
        for (var d = 0; d < dots; d++) { txt += "."; }
        dc.drawText(_cx, 5, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawBiteAlert(dc) {
        var fc = (_tick % 3 < 2) ? 0xFF4444 : 0xFFAA22;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 1, 6, Graphics.FONT_SMALL, "BITE!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, 5, Graphics.FONT_SMALL, "BITE!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h - 22, Graphics.FONT_XTINY, "TAP NOW!", Graphics.TEXT_JUSTIFY_CENTER);
        var timeLeft = 60 - _biteTick;
        var tlW = _w * 40 / 100; var tlX = (_w - tlW) / 2;
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tlX, _h - 14, tlW, 4);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tlX, _h - 14, timeLeft * tlW / 60, 4);
    }

    hidden function drawFightHUD(dc) {
        var bW = _w * 50 / 100; var bX = (_w - bW) / 2;
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX - 1, 4, bW + 2, 9);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX, 5, bW, 7);
        var tf = (_tension / _maxTension * bW.toFloat()).toNumber();
        var tc = 0x44AA44;
        if (_tension > 80.0) { tc = (_tick % 4 < 2) ? 0xFF2222 : 0xCC0000; }
        else if (_tension > 60.0) { tc = 0xFF8822; }
        else if (_tension > 40.0) { tc = 0xFFCC44; }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX, 5, tf, 7);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(bX - 3, 3, Graphics.FONT_XTINY, "T", Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h - 20, Graphics.FONT_XTINY, _fishNames[_fishType], Graphics.TEXT_JUSTIFY_CENTER);

        if (_tension > 75.0) {
            dc.setColor((_tick % 3 < 2) ? 0xFF2222 : 0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h - 32, Graphics.FONT_XTINY, "DANGER!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h - 10, Graphics.FONT_XTINY, "Tap to reel!", Graphics.TEXT_JUSTIFY_CENTER);

        var arrowRad = _fishPullDir * 3.14159 / 180.0;
        var ax2 = _cx + (14.0 * Math.cos(arrowRad)).toNumber();
        var ay2 = _cy + 8 + (14.0 * Math.sin(arrowRad)).toNumber();
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx, _cy + 8, ax2, ay2); dc.fillCircle(ax2, ay2, 2);
    }

    hidden function drawReelAnim(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 1, 6, Graphics.FONT_SMALL, "REELING!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 6 < 3) ? 0x44FF88 : 0x22CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 5, Graphics.FONT_SMALL, "REELING!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawResultMsg(dc) {
        var mc = 0xFFFF44;
        if (gameState == GS_SNAP) { mc = 0xFF4444; }
        else if (gameState == GS_LOST) { mc = 0xFF8844; }
        else if (gameState == GS_CAUGHT) { mc = 0x44FF88; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 1, _cy - 14, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _cy - 15, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
        if (gameState == GS_CAUGHT) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy + 2, Graphics.FONT_XTINY, "+" + _lastPts + " pts", Graphics.TEXT_JUSTIFY_CENTER);
            var rowY = _cy + 14;
            if (_fishCaught > 0 && _fishCaught % 5 == 0) {
                dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_cx, rowY, Graphics.FONT_XTINY, "MILESTONE!", Graphics.TEXT_JUSTIFY_CENTER);
                rowY += 12;
            }
            if (_combo > 1) {
                dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_cx, rowY, Graphics.FONT_XTINY, "COMBO x" + _combo, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden function drawCaughtFish(dc, ox, oy) {
        var fx2 = _cx + ox; var fy2 = _waterY - 35 - _resultTick / 2 + oy;
        var sz = _fishSize + 3;
        var rot = (_resultTick * 5) % 20 - 10;
        dc.setColor(getFishColor(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx2, fy2, sz); dc.fillCircle(fx2 + sz / 2, fy2, sz * 80 / 100);
        dc.fillPolygon([[fx2 - sz, fy2 - sz / 3], [fx2 - sz - sz * 60 / 100, fy2], [fx2 - sz, fy2 + sz / 3]]);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx2 + sz - 3, fy2 - 2, 3);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx2 + sz - 2, fy2 - 2, 1);
        if (_resultTick < 15) {
            dc.setColor(0x66AADD, Graphics.COLOR_TRANSPARENT);
            for (var dr = 0; dr < 3; dr++) { dc.fillCircle(fx2 + (Math.rand().abs() % 8) - 4, fy2 + sz + dr * 3, 1); }
        }
    }

    hidden function drawParticles(dc, ox, oy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            dc.setColor(_partColor[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_partX[i].toNumber() + ox, _partY[i].toNumber() + oy, (_partLife[i] > 6) ? 2 : 1, (_partLife[i] > 6) ? 2 : 1);
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 5, _waterY - 14, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);
        if (_fishCaught > 0) {
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(5, _waterY - 14, Graphics.FONT_XTINY, "" + _fishCaught + " fish", Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _waterY - 14, Graphics.FONT_XTINY, "Lv" + _level, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x3388CC, 0x3388CC); dc.clear();
        dc.setColor(0x44AADD, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, 0, _w, _waterY);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(30, 20, 11);
        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT); dc.fillCircle(30, 20, 7);
        for (var i = 0; i < 4; i++) { dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cloudX[i].toNumber(), _cloudY[i], 8 + i); dc.fillCircle(_cloudX[i].toNumber() + 9, _cloudY[i] + 1, 6 + i);
        }

        dc.setColor(0x2266AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _waterY, _w, _h - _waterY);
        for (var x = 0; x < _w; x += 3) {
            var wh = (Math.sin((x.toFloat() + _waveOff * 20.0) * 0.08) * 2.0).toNumber();
            dc.setColor(0x3388BB, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(x, _waterY + wh, 3, 2);
        }
        dc.setColor(0x1A5599, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _waterY + 4, _w, _h - _waterY - 4);

        var fishMx = _cx + (Math.sin(_tick.toFloat() * 0.06) * 28.0).toNumber();
        var fishMy = _waterY + _h * 14 / 100;
        dc.setColor(0x44AA66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fishMx, fishMy, 11); dc.fillCircle(fishMx + 7, fishMy, 9);
        dc.fillPolygon([[fishMx - 11, fishMy - 4], [fishMx - 17, fishMy], [fishMx - 11, fishMy + 4]]);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fishMx + 9, fishMy - 2, 2);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fishMx + 10, fishMy - 2, 1);

        dc.setColor(0x112233, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 1, _h * 4 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 14 < 7) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 4 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 18 / 100, Graphics.FONT_LARGE, "FISH", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCEE, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 32 / 100, Graphics.FONT_XTINY, "Cast, fight & catch!", Graphics.TEXT_JUSTIFY_CENTER);
        if (_bestScore > 0) { dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 78 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to fish", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
