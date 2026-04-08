using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum { PS_MENU, PS_JUMP, PS_FREE, PS_CHUTE, PS_LAND, PS_CRASH, PS_GAMEOVER }

class BitochiParachuteView extends WatchUi.View {

    var accelX;
    var accelY;
    var accelZ;
    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _timer;
    hidden var _tick;

    hidden var _playerX;
    hidden var _playerVx;
    hidden var _altitude;
    hidden var _maxAlt;
    hidden var _fallSpeed;
    hidden var _chuteOpen;

    hidden const MAX_RINGS = 24;
    hidden var _ringX;
    hidden var _ringY;
    hidden var _ringR;
    hidden var _ringType;
    hidden var _ringActive;
    hidden var _ringSpawnAcc;
    hidden var _ringsHit;
    hidden var _ringStreak;
    hidden var _ringTotal;

    hidden var _landX;
    hidden var _landR;

    hidden var _windX;
    hidden var _windPhase;

    hidden var _score;
    hidden var _totalScore;
    hidden var _bestScore;
    hidden var _level;
    hidden var _bestLevel;
    hidden var _landDist;
    hidden var _landGrade;
    hidden var _lives;
    hidden var _lifeLost;
    hidden var _gustX;
    hidden var _gustDecay;
    hidden var _gustSpawnTimer;
    hidden var _landVx;

    hidden const MAX_PARTS = 30;
    hidden var _partX;
    hidden var _partY;
    hidden var _partVx;
    hidden var _partVy;
    hidden var _partLife;
    hidden var _partColor;

    hidden const MAX_LINES = 8;
    hidden var _lineX;
    hidden var _lineY;
    hidden var _lineLen;
    hidden var _lineLife;

    hidden var _cloudX;
    hidden var _cloudY;
    hidden var _cloudW;

    hidden var _jumpTick;
    hidden var _resultTick;
    hidden var _landAnimY;
    hidden var _shakeT;
    hidden var _flashT;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        accelX = 0; accelY = 0; accelZ = 0;
        _tick = 0; _level = 1; _lives = 3; _lifeLost = false;
        var bs = Application.Storage.getValue("paraBest");
        _bestScore = (bs != null) ? bs : 0;
        var bl = Application.Storage.getValue("paraLevel");
        _bestLevel = (bl != null) ? bl : 0;
        _totalScore = 0;
        _gustX = 0.0; _gustDecay = 0; _gustSpawnTimer = 80;
        _landVx = 0.0;

        _ringX = new [MAX_RINGS]; _ringY = new [MAX_RINGS];
        _ringR = new [MAX_RINGS]; _ringType = new [MAX_RINGS]; _ringActive = new [MAX_RINGS];
        for (var i = 0; i < MAX_RINGS; i++) { _ringX[i] = 0; _ringY[i] = 0; _ringR[i] = 0; _ringType[i] = 0; _ringActive[i] = false; }

        _partX = new [MAX_PARTS]; _partY = new [MAX_PARTS];
        _partVx = new [MAX_PARTS]; _partVy = new [MAX_PARTS];
        _partLife = new [MAX_PARTS]; _partColor = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) { _partX[i] = 0.0; _partY[i] = 0.0; _partVx[i] = 0.0; _partVy[i] = 0.0; _partLife[i] = 0; _partColor[i] = 0; }

        _lineX = new [MAX_LINES]; _lineY = new [MAX_LINES];
        _lineLen = new [MAX_LINES]; _lineLife = new [MAX_LINES];
        for (var i = 0; i < MAX_LINES; i++) { _lineX[i] = 0; _lineY[i] = 0; _lineLen[i] = 0; _lineLife[i] = 0; }

        _cloudX = new [6]; _cloudY = new [6]; _cloudW = new [6];
        for (var i = 0; i < 6; i++) { _cloudX[i] = Math.rand().abs() % _w; _cloudY[i] = Math.rand().abs() % _h; _cloudW[i] = 14 + Math.rand().abs() % 18; }

        _playerX = 0.0; _playerVx = 0.0; _landAnimY = 0.0;
        _altitude = 3000.0; _maxAlt = 3000.0; _fallSpeed = 0.0; _chuteOpen = false;
        _windX = 0.0; _windPhase = 0.0;
        _score = 0; _ringsHit = 0; _ringStreak = 0; _ringTotal = 0; _ringSpawnAcc = 0.0;
        _landX = 0; _landR = 20; _landDist = 0.0; _landGrade = "";
        _jumpTick = 0; _resultTick = 0; _shakeT = 0; _flashT = 0;
        gameState = PS_MENU;
    }

    function onShow() { _timer = new Timer.Timer(); _timer.start(method(:onTick), 33, true); }
    function onHide() { if (_timer != null) { _timer.stop(); _timer = null; } }

    function onTick() as Void {
        _tick++;
        if (_shakeT > 0) { _shakeT--; }
        if (_flashT > 0) { _flashT--; }

        for (var i = 0; i < 6; i++) {
            _cloudY[i] -= 1;
            if (gameState == PS_FREE) { _cloudY[i] -= (_fallSpeed * 0.6).toNumber(); }
            else if (gameState == PS_CHUTE) { _cloudY[i] -= (_fallSpeed * 0.3).toNumber(); }
            if (_cloudY[i] < -30) { _cloudY[i] = _h + 10 + Math.rand().abs() % 30; _cloudX[i] = Math.rand().abs() % _w; _cloudW[i] = 14 + Math.rand().abs() % 18; }
        }
        for (var i = 0; i < MAX_PARTS; i++) { if (_partLife[i] <= 0) { continue; } _partX[i] += _partVx[i]; _partY[i] += _partVy[i]; _partLife[i]--; }
        for (var i = 0; i < MAX_LINES; i++) { if (_lineLife[i] > 0) { _lineLife[i]--; } }

        if (gameState == PS_JUMP) { _jumpTick++; if (_jumpTick >= 35) { gameState = PS_FREE; } }
        else if (gameState == PS_FREE) { updateFreefall(); }
        else if (gameState == PS_CHUTE) { updateChute(); }
        else if (gameState == PS_LAND || gameState == PS_CRASH || gameState == PS_GAMEOVER) { _resultTick++; }

        WatchUi.requestUpdate();
    }

    hidden function startLevel() {
        _playerX = (_w / 2).toFloat(); _playerVx = 0.0;
        _altitude = 3000.0 + _level * 380.0 + (_level / 3) * 100.0; _maxAlt = _altitude;
        _fallSpeed = 0.0; _chuteOpen = false; _lifeLost = false;
        _ringsHit = 0; _ringStreak = 0; _ringTotal = 0; _ringSpawnAcc = 0.0;
        _windPhase = 0.0; _windX = 0.0;
        _jumpTick = 0; _resultTick = 0; _score = 0;
        _gustX = 0.0; _gustDecay = 0;
        _gustSpawnTimer = 120 - _level * 4;
        if (_gustSpawnTimer < 40) { _gustSpawnTimer = 40; }

        _landX = _w / 2 + (Math.rand().abs() % 40) - 20;
        _landR = 28 - _level / 2;
        if (_landR < 10) { _landR = 10; }

        _landVx = 0.0;
        if (_level >= 6) {
            var driftSpd = 0.25 + (_level - 6).toFloat() * 0.04;
            if (driftSpd > 0.9) { driftSpd = 0.9; }
            _landVx = (Math.rand().abs() % 2 == 0) ? driftSpd : -driftSpd;
        }

        if (_level == 5 || _level == 10 || _level == 15) {
            if (_lives < 3) { _lives++; doVibe(80, 200); }
        }

        if (_level > _bestLevel) {
            _bestLevel = _level;
            Application.Storage.setValue("paraLevel", _bestLevel);
        }

        for (var i = 0; i < MAX_RINGS; i++) { _ringActive[i] = false; }
        for (var i = 0; i < MAX_PARTS; i++) { _partLife[i] = 0; }
        for (var i = 0; i < MAX_LINES; i++) { _lineLife[i] = 0; }
        gameState = PS_JUMP;
    }

    hidden function updateGusts() {
        if (_level < 4) { _gustX = 0.0; return; }
        _gustSpawnTimer--;
        if (_gustSpawnTimer <= 0) {
            var maxForce = 0.5 + (_level - 4).toFloat() * 0.12;
            if (maxForce > 2.4) { maxForce = 2.4; }
            _gustX = (Math.rand().abs() % 2 == 0 ? 1.0 : -1.0) * (0.4 + (Math.rand().abs() % 10).toFloat() / 10.0 * maxForce);
            _gustDecay = 20 + Math.rand().abs() % 35;
            _gustSpawnTimer = 50 + Math.rand().abs() % 90;
        }
        if (_gustDecay > 0) {
            _gustDecay--;
            if (_gustDecay == 0) { _gustX = 0.0; }
        }
    }

    hidden function updateFreefall() {
        var grav = 0.11 + (_level / 12).toFloat() * 0.02;
        if (grav > 0.15) { grav = 0.15; }
        _fallSpeed += grav;
        var termV = 6.5 + (_level / 8).toFloat() * 0.35;
        if (termV > 7.4) { termV = 7.4; }
        if (_fallSpeed > termV) { _fallSpeed = termV; }
        _altitude -= _fallSpeed;
        if (_altitude < 0.0) { _altitude = 0.0; }

        _windPhase += 0.06;
        var wAmp = 0.55 + _level.toFloat() * 0.14 + (_level / 4).toFloat() * 0.05;
        if (wAmp > 1.8) { wAmp = 1.8; }
        _windX = Math.sin(_windPhase) * wAmp;

        updateGusts();

        var steerX = accelX.toFloat() / 280.0;
        if (steerX > 3.5) { steerX = 3.5; } if (steerX < -3.5) { steerX = -3.5; }
        _playerVx = _playerVx * 0.85 + steerX + _windX * 0.06 + _gustX * 0.05;
        _playerX += _playerVx;
        if (_playerX < 12.0) { _playerX = 12.0; _playerVx = 0.0; }
        if (_playerX > (_w - 12).toFloat()) { _playerX = (_w - 12).toFloat(); _playerVx = 0.0; }

        spawnRings();
        moveRings(_fallSpeed);
        checkRingHits();
        spawnSpeedLines();

        if (_altitude <= 0.0) {
            _lives--;
            if (_lives < 0) { _lives = 0; }
            _landGrade = "SPLAT!";
            doVibe(100, 500); _shakeT = 15; _flashT = 8;
            finalScore(false);
            if (_lives <= 0) { gameState = PS_GAMEOVER; _resultTick = 0; }
            else { gameState = PS_CRASH; _resultTick = 0; }
        }
    }

    hidden function updateChute() {
        _fallSpeed = _fallSpeed * 0.92;
        if (_fallSpeed < 2.4) { _fallSpeed = 2.4; }
        _altitude -= _fallSpeed;
        if (_altitude < 0.0) { _altitude = 0.0; }

        _windPhase += 0.04;
        var wAmpC = 0.45 + _level.toFloat() * 0.10 + (_level / 4).toFloat() * 0.04;
        if (wAmpC > 1.4) { wAmpC = 1.4; }
        _windX = Math.sin(_windPhase) * wAmpC;

        updateGusts();

        var steerX = accelX.toFloat() / 200.0;
        if (steerX > 2.5) { steerX = 2.5; } if (steerX < -2.5) { steerX = -2.5; }
        _playerVx = _playerVx * 0.88 + steerX * 0.6 + _windX * 0.08 + _gustX * 0.06;
        _playerX += _playerVx;
        if (_playerX < 12.0) { _playerX = 12.0; _playerVx = 0.0; }
        if (_playerX > (_w - 12).toFloat()) { _playerX = (_w - 12).toFloat(); _playerVx = 0.0; }

        if (_landVx != 0.0) {
            _landX += _landVx.toNumber();
            var margin = _landR + 8;
            if (_landX < margin) { _landX = margin; _landVx = -_landVx; }
            else if (_landX > _w - margin) { _landX = _w - margin; _landVx = -_landVx; }
        }

        moveRings(_fallSpeed);
        checkRingHits();

        if (_altitude <= 0.0) {
            var dx = _playerX - _landX.toFloat();
            _landDist = dx; if (_landDist < 0.0) { _landDist = -_landDist; }
            var lr = _landR.toFloat();
            if (_landDist < lr * 0.28) { _landGrade = "PERFECT!"; }
            else if (_landDist < lr) { _landGrade = "BULLSEYE!"; }
            else if (_landDist < lr * 2.0) { _landGrade = "GREAT!"; }
            else if (_landDist < lr * 3.5) { _landGrade = "GOOD"; }
            else { _landGrade = "MISSED!"; }

            var ringsRequired = _level;
            if (_ringsHit < ringsRequired) {
                _lives--;
                if (_lives < 0) { _lives = 0; }
                _lifeLost = true;
                doVibe(90, 400); _shakeT = 10;
            } else {
                doVibe(50, 200); _shakeT = 4;
            }

            finalScore(true);
            _landAnimY = (_h * 10 / 100).toFloat();
            if (_lives <= 0) { gameState = PS_GAMEOVER; _resultTick = 0; }
            else { gameState = PS_LAND; _resultTick = 0; }
        }
    }

    hidden function spawnRings() {
        var spawnRate = 12.5 - _level.toFloat() * 0.32 - (_level / 4).toFloat() * 0.15;
        if (spawnRate < 6.0) { spawnRate = 6.0; }
        _ringSpawnAcc += 1.0;
        if (_ringSpawnAcc < spawnRate) { return; }
        _ringSpawnAcc = 0.0;
        if (_altitude < 400.0) { return; }

        for (var i = 0; i < MAX_RINGS; i++) {
            if (_ringActive[i]) { continue; }
            _ringX[i] = 20 + Math.rand().abs() % (_w - 40);
            _ringY[i] = _h + 10;
            _ringR[i] = 16 + Math.rand().abs() % 10;
            _ringType[i] = (Math.rand().abs() % 8 == 0) ? 1 : 0;
            _ringActive[i] = true;
            _ringTotal++;
            break;
        }
    }

    hidden function moveRings(speed) {
        var scrollSpeed = speed * 1.8;
        if (_chuteOpen) { scrollSpeed = speed * 1.2; }
        for (var i = 0; i < MAX_RINGS; i++) {
            if (!_ringActive[i]) { continue; }
            _ringY[i] -= scrollSpeed.toNumber();
            if (_ringY[i] < -30) { _ringActive[i] = false; }
        }
    }

    hidden function checkRingHits() {
        var py = _h * 28 / 100;
        for (var i = 0; i < MAX_RINGS; i++) {
            if (!_ringActive[i]) { continue; }
            var dy = _ringY[i] - py;
            if (dy < 0) { dy = -dy; }
            if (dy > 18) { continue; }
            var dx = _playerX - _ringX[i].toFloat();
            if (dx < 0.0) { dx = -dx; }
            if (dx < _ringR[i].toFloat()) {
                _ringActive[i] = false;
                _ringsHit++;
                _ringStreak++;
                spawnRingParts(_ringX[i], _ringY[i], _ringType[i]);
                doVibe(35, 60);
                _flashT = 3;
            }
        }
    }

    hidden function spawnRingParts(rx, ry, rType) {
        var colors = (rType == 1) ? [0xFFFF44, 0xFFDD22, 0xFFAA00] : [0x44FF88, 0x22DD66, 0x88FFAA];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 8) { break; } if (_partLife[i] > 0) { continue; }
            _partX[i] = rx.toFloat(); _partY[i] = ry.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var sp = 1.5 + (Math.rand().abs() % 20).toFloat() / 10.0;
            _partVx[i] = sp * Math.cos(a); _partVy[i] = sp * Math.sin(a);
            _partLife[i] = 12 + Math.rand().abs() % 8;
            _partColor[i] = colors[Math.rand().abs() % 3];
            spawned++;
        }
    }

    hidden function spawnSpeedLines() {
        if (_fallSpeed < 2.0) { return; }
        if (_tick % 3 != 0) { return; }
        for (var i = 0; i < MAX_LINES; i++) {
            if (_lineLife[i] > 0) { continue; }
            _lineX[i] = Math.rand().abs() % _w;
            _lineY[i] = Math.rand().abs() % (_h / 3);
            _lineLen[i] = ((_fallSpeed - 1.0) * 4.0).toNumber() + 4;
            _lineLife[i] = 6 + Math.rand().abs() % 4;
            break;
        }
    }

    hidden function finalScore(landed) {
        var ringPts = 0;
        var mult = 1;
        for (var r = 0; r < _ringsHit; r++) {
            ringPts += 100 * mult;
            if ((r + 1) % 3 == 0 && mult < 5) { mult++; }
        }
        var landPts = 0;
        var perfectExtra = 0;
        if (landed) {
            var lr = _landR.toFloat();
            if (_landDist < lr) {
                landPts = 500;
                if (_landDist < lr * 0.28) {
                    perfectExtra = 280;
                } else if (_landDist < lr * 0.5) {
                    perfectExtra = 120;
                }
            } else if (_landDist < lr * 2.0) { landPts = 300; }
            else if (_landDist < lr * 3.5) { landPts = 150; }
            else { landPts = 50; }
        }
        _score = ringPts + landPts + perfectExtra;
        _totalScore += _score;
        if (_totalScore > _bestScore) { _bestScore = _totalScore; Application.Storage.setValue("paraBest", _bestScore); }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) { if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
        } }
    }

    function doAction() {
        if (gameState == PS_MENU) { _level = 1; _totalScore = 0; _lives = 3; startLevel(); }
        else if (gameState == PS_FREE) {
            if (_altitude > 300.0) { _flashT = 6; return; }
            _chuteOpen = true; gameState = PS_CHUTE; doVibe(60, 150);
        }
        else if (gameState == PS_LAND) {
            if (_resultTick > 20) {
                if (!_lifeLost) { _level++; }
                startLevel();
            }
        }
        else if (gameState == PS_CRASH) {
            if (_resultTick > 20) { startLevel(); }
        }
        else if (gameState == PS_GAMEOVER) {
            if (_resultTick > 25) { _level = 1; _totalScore = 0; _lives = 3; startLevel(); }
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        if (gameState == PS_MENU) { drawMenu(dc); return; }

        var ox = 0; var oy = 0;
        if (_shakeT > 0) { ox = (Math.rand().abs() % 7) - 3; oy = (Math.rand().abs() % 5) - 2; }

        drawSky(dc, ox, oy);
        drawClouds(dc, ox, oy);

        if (gameState == PS_JUMP) { drawJump(dc, ox, oy); }
        else if (gameState == PS_FREE) { drawFreeScene(dc, ox, oy); }
        else if (gameState == PS_CHUTE) { drawChuteScene(dc, ox, oy); }
        else if (gameState == PS_LAND) { drawLanded(dc, ox, oy); }
        else if (gameState == PS_CRASH) { drawCrash(dc, ox, oy); }
        else if (gameState == PS_GAMEOVER) { drawGameOver(dc, ox, oy); }

        if (_flashT > 0) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(0, 0, _w, _h);
            dc.drawRectangle(1, 1, _w - 2, _h - 2);
        }
    }

    hidden function drawSky(dc, ox, oy) {
        var altPct = _altitude / _maxAlt;
        if (altPct > 1.0) { altPct = 1.0; } if (altPct < 0.0) { altPct = 0.0; }

        var r = (0x10 + (1.0 - altPct) * 0x38).toNumber();
        var g = (0x20 + (1.0 - altPct) * 0x55).toNumber();
        var b = (0x55 + (1.0 - altPct) * 0x44).toNumber();
        if (r > 0xFF) { r = 0xFF; } if (g > 0xFF) { g = 0xFF; } if (b > 0xFF) { b = 0xFF; }
        dc.setColor((r << 16) | (g << 8) | b, (r << 16) | (g << 8) | b);
        dc.clear();

        var gPct = (1.0 - altPct) * 0.7 + 0.08;
        if (gPct > 0.78) { gPct = 0.78; }
        var gH = (_h.toFloat() * gPct).toNumber();
        var gTop = _h - gH + oy;

        dc.setColor(0x336633, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gTop, _w, gH + 5);

        dc.setColor(0x448844, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 8; i++) {
            var px = (i * 37 + 12) % _w + ox;
            var py = gTop + 5 + (i * 23) % (gH > 8 ? gH - 5 : 5);
            var sz = (2 + (1.0 - altPct) * 8.0).toNumber();
            dc.fillRectangle(px, py, sz + i * 2, sz);
        }
        dc.setColor(0x225522, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            var px = (i * 53 + 28) % _w + ox;
            var py = gTop + 8 + (i * 31) % (gH > 8 ? gH - 5 : 5);
            var sz = (2 + (1.0 - altPct) * 6.0).toNumber();
            dc.fillRectangle(px, py, sz, sz + i);
        }

        dc.setColor(0x2D5D2D, Graphics.COLOR_TRANSPARENT);
        var cx = _w / 2 + ox;
        for (var i = -3; i <= 3; i++) { dc.drawLine(cx, gTop, cx + i * _w / 4, _h + 10); }
        var by = gTop + 4; var step = 3;
        for (var i = 0; i < 5; i++) { if (by >= _h) { break; } dc.drawLine(0, by, _w, by); step += 3 + i * 2; by += step; }

        if (altPct < 0.5) {
            var tSz = (1 + (0.5 - altPct) * 12.0).toNumber();
            dc.setColor(0x1A5C1A, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 6; i++) {
                var tx = (i * 41 + 18) % _w + ox;
                var ty = gTop + 12 + (i * 29) % (gH > 15 ? gH - 10 : 8);
                dc.fillCircle(tx, ty, tSz);
                dc.setColor(0x2A7A2A, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(tx - 2, ty - tSz / 2, tSz * 2 / 3);
                dc.setColor(0x1A5C1A, Graphics.COLOR_TRANSPARENT);
            }
        }

        if (altPct < 0.4) {
            var rw = (1 + (0.4 - altPct) * 6.0).toNumber();
            dc.setColor(0x555544, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_w * 30 / 100 + ox, gTop + 5, rw, gH);
            dc.fillRectangle(ox, gTop + gH * 40 / 100, _w, rw);
        }

        if (altPct < 0.45 && (gameState == PS_CHUTE || gameState == PS_FREE)) {
            var tScale = (0.45 - altPct) / 0.45;
            var tR = (_landR.toFloat() * tScale * 3.0 + 1.0).toNumber();
            var lx = _landX + ox; var ly = _h * 82 / 100 + oy;
            dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lx, ly, tR + 3);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lx, ly, tR + 1);
            if (tR > 4) {
                dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lx, ly, tR * 2 / 3);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lx, ly, tR / 3);
            }
        }

        dc.setColor(0x88BB88, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gTop, _w, 2);
    }

    hidden function drawClouds(dc, ox, oy) {
        for (var i = 0; i < 6; i++) {
            if (_cloudY[i] < -25 || _cloudY[i] > _h + 25) { continue; }
            var cw = _cloudW[i]; var ccx = _cloudX[i] + ox; var ccy = _cloudY[i] + oy;
            dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx + 2, ccy + 3, cw / 2); dc.fillCircle(ccx - cw / 3 + 2, ccy + 4, cw / 3);
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx, ccy, cw / 2); dc.fillCircle(ccx - cw / 3, ccy + 2, cw / 3); dc.fillCircle(ccx + cw / 3, ccy + 1, cw * 2 / 5);
            dc.setColor(0xEEF4FF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx - cw / 5, ccy - cw / 6, cw / 3);
        }
    }

    hidden function drawRings(dc, ox, oy) {
        for (var i = 0; i < MAX_RINGS; i++) {
            if (!_ringActive[i]) { continue; }
            var rx = _ringX[i] + ox; var ry = _ringY[i] + oy; var rr = _ringR[i];
            var isGold = (_ringType[i] == 1);

            var pulse = (_tick % 10 < 5) ? 2 : 0;
            if (isGold) {
                dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(rx, ry, rr + 3 + pulse); dc.drawCircle(rx, ry, rr + 4 + pulse);
                dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawCircle(rx, ry, rr); dc.drawCircle(rx, ry, rr + 1); dc.drawCircle(rx, ry, rr + 2);

            var dotC = isGold ? 0xFFFF88 : 0xFFCC66;
            dc.setColor(dotC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(rx - rr + 2, ry, 2); dc.fillCircle(rx + rr - 2, ry, 2);
            dc.fillCircle(rx, ry - rr + 2, 2); dc.fillCircle(rx, ry + rr - 2, 2);
        }
    }

    hidden function drawSpeedLines(dc, ox, oy) {
        for (var i = 0; i < MAX_LINES; i++) {
            if (_lineLife[i] <= 0) { continue; }
            var alpha = _lineLife[i] > 4 ? 0x99AABB : 0x556677;
            dc.setColor(alpha, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(_lineX[i] + ox, _lineY[i] + oy, _lineX[i] + ox, _lineY[i] - _lineLen[i] + oy);
        }
    }

    hidden function drawParts(dc, ox, oy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            dc.setColor(_partColor[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_partX[i].toNumber() + ox, _partY[i].toNumber() + oy, _partLife[i] > 6 ? 2 : 1, _partLife[i] > 6 ? 2 : 1);
        }
    }

    hidden function drawPlayer(dc, px, py, chuteOpen, ox, oy) {
        px += ox; py += oy;
        if (chuteOpen) {
            var cw = (_tick % 10 < 5) ? 2 : -2;
            var cy2 = py - 50;
            dc.setColor(0x880022, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, cy2, 32);
            dc.setColor(0x0A1530, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + cw - 33, cy2, 66, 34);
            dc.setColor(0xCC1133, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, cy2, 29);
            dc.setColor(0x0A1530, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + cw - 30, cy2, 60, 32);
            dc.setColor(0xFF3355, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, cy2, 22);
            dc.setColor(0x0A1530, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + cw - 23, cy2, 46, 25);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            for (var seg = 0; seg < 5; seg++) {
                var ang = (200 + seg * 28) * 3.14159 / 180.0;
                var sx2 = px + cw + (28.0 * Math.cos(ang)).toNumber();
                var sy2 = cy2 + (28.0 * Math.sin(ang)).toNumber();
                if (sy2 < cy2) { dc.fillCircle(sx2, sy2, 3); }
            }
            dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, cy2, 10);
            dc.setColor(0x0A1530, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + cw - 11, cy2, 22, 12);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, cy2, 6);
            dc.setColor(0x0A1530, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + cw - 7, cy2, 14, 8);
            dc.setColor(0x553333, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px - 28 + cw, cy2 + 14, px - 6, py - 2);
            dc.drawLine(px - 16 + cw, cy2 + 20, px - 3, py - 1);
            dc.drawLine(px + cw, cy2 + 22, px, py - 4);
            dc.drawLine(px + 16 + cw, cy2 + 20, px + 3, py - 1);
            dc.drawLine(px + 28 + cw, cy2 + 14, px + 6, py - 2);
        }

        dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py - 5, 5);
        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py - 5, 4);
        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 5, py - 10, 10, 4);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 6, py - 7, 12, 1);
        dc.fillCircle(px - 2, py - 5, 1); dc.fillCircle(px + 2, py - 5, 1);

        dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 7, py, 14, 10);
        dc.setColor(0x3355CC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 6, py + 1, 12, 8);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 4, py, 2, 9); dc.fillRectangle(px + 2, py, 2, 9);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 3, py + 3, 6, 4);

        if (chuteOpen) {
            dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 9, py - 2, 2, 5); dc.fillRectangle(px + 7, py - 2, 2, 5);
            dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 9, py - 3, 2, 2); dc.fillRectangle(px + 7, py - 3, 2, 2);
            dc.setColor(0x222266, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 3, py + 10, 3, 6); dc.fillRectangle(px, py + 10, 3, 6);
            dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 3, py + 16, 3, 2); dc.fillRectangle(px, py + 16, 3, 2);
        } else {
            var aw = (_tick % 6 < 3) ? 1 : -1;
            dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 14, py + 1 + aw, 7, 3); dc.fillRectangle(px + 7, py + 1 - aw, 7, 3);
            dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 16, py + 1 + aw, 2, 3); dc.fillRectangle(px + 14, py + 1 - aw, 2, 3);
            dc.setColor(0x222266, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 7, py + 10, 3, 5); dc.fillRectangle(px + 4, py + 10, 3, 5);
            dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 8, py + 15, 4, 2); dc.fillRectangle(px + 4, py + 15, 4, 2);

            if (_fallSpeed > 2.5) {
                var lc = ((_fallSpeed - 2.5) * 2.5).toNumber(); if (lc > 8) { lc = 8; }
                dc.setColor(0xAABBDD, Graphics.COLOR_TRANSPARENT);
                for (var li = 0; li < lc; li++) { dc.drawLine(px - 16 + li * 32 / (lc > 0 ? lc : 1), py - 12, px - 16 + li * 32 / (lc > 0 ? lc : 1), py - 18 - Math.rand().abs() % 5); }
            }
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, 3, Graphics.FONT_XTINY, _altitude.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, 2, Graphics.FONT_XTINY, _altitude.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        var abW = 6; var abH = _h * 45 / 100; var abX = _w - abW - 4; var abY = (_h - abH) / 2;
        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(abX - 1, abY - 1, abW + 2, abH + 2);
        var altPct = _altitude / _maxAlt; if (altPct > 1.0) { altPct = 1.0; }
        var fH = (abH.toFloat() * altPct).toNumber();
        var ac = (altPct > 0.3) ? 0x44AAFF : ((altPct > 0.1) ? 0xFFCC22 : 0xFF4444);
        dc.setColor(ac, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(abX, abY + abH - fH, abW, fH);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 2, Graphics.FONT_XTINY, "" + _ringsHit + "/" + _level, Graphics.TEXT_JUSTIFY_LEFT);
        if (_ringStreak >= 3) {
            dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
            dc.drawText(4, 14, Graphics.FONT_XTINY, "x" + (_ringStreak / 3 + 1), Graphics.TEXT_JUSTIFY_LEFT);
        }

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, _h - 16, Graphics.FONT_XTINY, "L" + _level, Graphics.TEXT_JUSTIFY_LEFT);

        var heartStr = "";
        for (var li = 0; li < _lives; li++) { heartStr = heartStr + "*"; }
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 5, _h - 16, Graphics.FONT_XTINY, heartStr, Graphics.TEXT_JUSTIFY_RIGHT);

        var gustAbs = _gustX; if (gustAbs < 0.0) { gustAbs = -gustAbs; }
        if (gustAbs > 0.5) {
            var gc2 = (_tick % 4 < 2) ? 0xFF8800 : 0xFFCC44;
            dc.setColor(gc2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 60 / 100, Graphics.FONT_XTINY, _gustX > 0.0 ? "GUST>>>" : "<<<GUST", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (!_chuteOpen) {
            if (_altitude > 300.0 && _altitude < 900.0) {
                dc.setColor(0x6688BB, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 82 / 100, Graphics.FONT_XTINY, "chute < 300m", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (_altitude <= 300.0) {
                var wc = (_tick % 6 < 3) ? 0xFF0000 : 0xFF8800;
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 82 / 100 + 1, Graphics.FONT_SMALL, "DEPLOY!", Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(wc, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 82 / 100, Graphics.FONT_SMALL, "DEPLOY!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (_chuteOpen) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h - 14, Graphics.FONT_XTINY, "CHUTE", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var spd = _fallSpeed / 7.0; if (spd > 1.0) { spd = 1.0; }
            var sbW = _w * 35 / 100; var sbX = (_w - sbW) / 2; var sbY = _h - 10;
            dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sbX, sbY, sbW, 4);
            dc.setColor(spd > 0.7 ? 0xFF4444 : (spd > 0.4 ? 0xFFCC22 : 0x44FF44), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sbX, sbY, (sbW.toFloat() * spd).toNumber(), 4);
        }

        var awx = _windX; if (awx < 0.0) { awx = -awx; }
        if (awx > 0.3) {
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, 14, Graphics.FONT_XTINY, _windX > 0.0 ? ">>>" : "<<<", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x0A1530, 0x0A1530); dc.clear();
        dc.setColor(0x0A1E3A, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 30 / 100, _w, _h * 30 / 100);
        dc.setColor(0x152848, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 60 / 100, _w, _h * 18 / 100);

        dc.setColor(0x336633, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 78 / 100, _w, _h * 22 / 100);
        dc.setColor(0x448844, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 78 / 100, _w, 2);
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w / 2, _h * 87 / 100, 6);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w / 2, _h * 87 / 100, 4);
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w / 2, _h * 87 / 100, 2);

        drawClouds(dc, 0, 0);

        dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 15 / 100, _h * 7 / 100, 1); dc.fillCircle(_w * 50 / 100, _h * 4 / 100, 1); dc.fillCircle(_w * 78 / 100, _h * 9 / 100, 2);

        dc.setColor(0x113355, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 8 / 100 + 1, Graphics.FONT_SMALL, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 30 < 15) ? 0x44AAFF : 0x2288DD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 8 / 100, Graphics.FONT_SMALL, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_SMALL, "PARACHUTE", Graphics.TEXT_JUSTIFY_CENTER);

        drawPlayer(dc, _w / 2, _h * 44 / 100, true, 0, 0);

        dc.setColor(0x7799BB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 58 / 100, Graphics.FONT_XTINY, "Collect rings per level!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 65 / 100, Graphics.FONT_XTINY, "Chute opens below 300m", Graphics.TEXT_JUSTIFY_CENTER);
        if (_bestScore > 0) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            var bTxt = "BEST " + _bestScore;
            if (_bestLevel > 0) { bTxt = bTxt + "  L" + _bestLevel; }
            dc.drawText(_w / 2, _h * 74 / 100, Graphics.FONT_XTINY, bTxt, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor((_tick % 10 < 5) ? 0x44AAFF : 0x33AADD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 82 / 100, Graphics.FONT_XTINY, "Tap to jump", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawJump(dc, ox, oy) {
        var progress = _jumpTick.toFloat() / 35.0;
        var py = (_h * 10 / 100 + progress * _h * 16 / 100).toNumber();

        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, 0 + oy, _w, _h * 6 / 100);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 6 / 100 + oy, _w, 3);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w / 2 - 25 + ox, oy, 50, _h * 6 / 100 + 3);

        var shake = (_jumpTick % 4 < 2) ? 2 : -2;
        drawPlayer(dc, _w / 2 + shake, py, false, ox, oy);

        var fc = (_jumpTick % 8 < 4) ? 0xFFFF44 : 0xFFAA22;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 48 / 100 + 1, Graphics.FONT_MEDIUM, "JUMP!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_MEDIUM, "JUMP!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 64 / 100, Graphics.FONT_XTINY, _altitude.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFreeScene(dc, ox, oy) {
        drawSpeedLines(dc, ox, oy);
        drawRings(dc, ox, oy);
        drawParts(dc, ox, oy);
        var sway = (Math.sin(_tick.toFloat() / 3.0) * 2.5).toNumber();
        drawPlayer(dc, _playerX.toNumber() + sway, _h * 28 / 100, false, ox, oy);
        drawHUD(dc);
    }

    hidden function drawChuteScene(dc, ox, oy) {
        drawRings(dc, ox, oy);
        drawParts(dc, ox, oy);
        drawPlayer(dc, _playerX.toNumber(), _h * 28 / 100, true, ox, oy);
        drawHUD(dc);
    }

    hidden function drawLanded(dc, ox, oy) {
        var targetY = _h * 60 / 100;
        if (_landAnimY < targetY.toFloat()) {
            _landAnimY += 6.0;
            if (_landAnimY > targetY.toFloat()) { _landAnimY = targetY.toFloat(); }
        }
        drawPlayer(dc, _playerX.toNumber(), _landAnimY.toNumber(), _resultTick < 40, ox, oy);

        var gc = 0x44FF44;
        if (_landDist > _landR.toFloat() * 2.0) { gc = 0xFFCC22; }
        if (_landDist > _landR.toFloat() * 3.5) { gc = 0xFF6644; }
        if (_lifeLost) { gc = (_resultTick % 6 < 3) ? 0xFF2222 : 0xCC0000; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 8 / 100 + 1, Graphics.FONT_SMALL, _landGrade, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(gc, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 8 / 100, Graphics.FONT_SMALL, _landGrade, Graphics.TEXT_JUSTIFY_CENTER);

        if (_lifeLost) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 18 / 100, Graphics.FONT_XTINY, "RINGS: " + _ringsHit + "/" + _level, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(_w / 2, _h * 27 / 100, Graphics.FONT_XTINY, "LIFE LOST!", Graphics.TEXT_JUSTIFY_CENTER);
            var heartStr = "";
            for (var li = 0; li < _lives; li++) { heartStr = heartStr + "*"; }
            dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 36 / 100, Graphics.FONT_XTINY, heartStr, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 22 / 100, Graphics.FONT_XTINY, "RINGS " + _ringsHit + "/" + _level, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 35 / 100, Graphics.FONT_SMALL, "+" + _score, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 46 / 100, Graphics.FONT_XTINY, "TOTAL " + _totalScore, Graphics.TEXT_JUSTIFY_CENTER);
        if (_totalScore >= _bestScore && _totalScore > 0) { dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 55 / 100, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 86 / 100, Graphics.FONT_XTINY, "Tap: level " + (_level + 1), Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc, ox, oy) {
        var fb = (_resultTick % 6 < 3) ? 0x1A0A0A : 0x0A0505;
        dc.setColor(fb, fb); dc.clear();
        dc.setColor(0x441111, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 40 / 100, _w, _h * 20 / 100);

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 2, _h * 10 / 100 + 2, Graphics.FONT_SMALL, "GAME", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_resultTick % 8 < 4) ? 0xFF2222 : 0xCC0000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 10 / 100, Graphics.FONT_SMALL, "GAME", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 2, _h * 24 / 100 + 2, Graphics.FONT_SMALL, "OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_resultTick % 8 < 4) ? 0xFF2222 : 0xCC0000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 24 / 100, Graphics.FONT_SMALL, "OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 42 / 100, Graphics.FONT_XTINY, "Level " + _level + " reached", Graphics.TEXT_JUSTIFY_CENTER);
        if (_level >= _bestLevel) {
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 50 / 100, Graphics.FONT_XTINY, "BEST LEVEL!", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 50 / 100, Graphics.FONT_XTINY, "Best L" + _bestLevel, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 60 / 100, Graphics.FONT_XTINY, "Score " + _totalScore, Graphics.TEXT_JUSTIFY_CENTER);
        if (_totalScore >= _bestScore && _totalScore > 0) { dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 68 / 100, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor((_tick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 84 / 100, Graphics.FONT_XTINY, "Tap to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawCrash(dc, ox, oy) {
        var fb = (_resultTick % 4 < 2) ? 0x220800 : 0x110400;
        dc.setColor(fb, fb); dc.clear();
        dc.setColor(0x334422, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 45 / 100, _w, _h * 55 / 100);
        dc.setColor(0x221100, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w / 2 + ox, _h * 52 / 100 + oy, 20);
        dc.setColor(0x443311, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w / 2 + ox, _h * 52 / 100 + oy, 13);

        for (var di = 0; di < 10; di++) {
            dc.setColor(0x886644, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_w / 2 + (Math.rand().abs() % 50) - 25, _h * 52 / 100 + (Math.rand().abs() % 30) - 15, 2 + Math.rand().abs() % 4, 2 + Math.rand().abs() % 3);
        }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 14 / 100 + 1, Graphics.FONT_SMALL, "SPLAT!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_resultTick % 6 < 3) ? 0xFF2222 : 0xCC0000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 14 / 100, Graphics.FONT_SMALL, "SPLAT!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_XTINY, "No chute deployed!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 36 / 100, Graphics.FONT_XTINY, "RINGS " + _ringsHit, Graphics.TEXT_JUSTIFY_CENTER);
        var heartStr = "";
        for (var li = 0; li < _lives; li++) { heartStr = heartStr + "*"; }
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 47 / 100, Graphics.FONT_XTINY, _lives > 0 ? heartStr : "---", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 58 / 100, Graphics.FONT_XTINY, _totalScore + " pts", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 82 / 100, Graphics.FONT_XTINY, "Tap: try again", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
