using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum {
    PS_MENU,
    PS_JUMP,
    PS_FREEFALL,
    PS_CHUTE,
    PS_LANDED,
    PS_CRASH
}

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
    hidden var _playerY;
    hidden var _playerVx;
    hidden var _playerVy;
    hidden var _altitude;
    hidden var _maxAlt;
    hidden var _fallSpeed;
    hidden var _chuteOpen;

    hidden var _ringX;
    hidden var _ringY;
    hidden var _ringR;
    hidden var _ringHit;
    hidden var _ringCount;

    hidden var _landX;
    hidden var _landY;
    hidden var _landR;

    hidden var _cloudX;
    hidden var _cloudY;
    hidden var _cloudW;

    hidden var _windX;
    hidden var _windPhase;

    hidden var _score;
    hidden var _ringsHit;
    hidden var _level;
    hidden var _bestScore;

    hidden var _trailX;
    hidden var _trailY;
    hidden var _trailLife;

    hidden var _sparkX;
    hidden var _sparkY;
    hidden var _sparkLife;

    hidden var _landDist;
    hidden var _landGrade;

    hidden var _jumpTick;
    hidden var _crashTick;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());

        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;

        accelX = 0;
        accelY = 0;
        accelZ = 0;
        _tick = 0;
        _level = 1;
        _bestScore = 0;
        _score = 0;

        _cloudX = new [8];
        _cloudY = new [8];
        _cloudW = new [8];
        for (var i = 0; i < 8; i++) {
            _cloudX[i] = Math.rand().abs() % _w;
            _cloudY[i] = Math.rand().abs() % _h;
            _cloudW[i] = 12 + Math.rand().abs() % 20;
        }

        _trailX = new [16];
        _trailY = new [16];
        _trailLife = new [16];
        for (var i = 0; i < 16; i++) {
            _trailX[i] = 0; _trailY[i] = 0; _trailLife[i] = 0;
        }

        _sparkX = new [12];
        _sparkY = new [12];
        _sparkLife = new [12];
        for (var i = 0; i < 12; i++) {
            _sparkX[i] = 0; _sparkY[i] = 0; _sparkLife[i] = 0;
        }

        _altitude = 3000.0;
        _maxAlt = 3000.0;
        _fallSpeed = 0.0;
        _chuteOpen = false;
        _playerX = 0.0;
        _playerY = 0.0;
        _playerVx = 0.0;
        _playerVy = 0.0;
        _landDist = 0.0;
        _landGrade = "";
        _jumpTick = 0;
        _crashTick = 0;

        _ringCount = 0;
        _ringX = new [20];
        _ringY = new [20];
        _ringR = new [20];
        _ringHit = new [20];
        for (var i = 0; i < 20; i++) {
            _ringX[i] = 0; _ringY[i] = 0; _ringR[i] = 0; _ringHit[i] = false;
        }

        gameState = PS_MENU;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 45, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _tick++;
        updateClouds();

        if (gameState == PS_JUMP) {
            _jumpTick++;
            if (_jumpTick >= 40) {
                gameState = PS_FREEFALL;
            }
        } else if (gameState == PS_FREEFALL) {
            updateFreefall();
        } else if (gameState == PS_CHUTE) {
            updateChute();
        } else if (gameState == PS_CRASH) {
            _crashTick++;
        }

        WatchUi.requestUpdate();
    }

    hidden function updateClouds() {
        for (var i = 0; i < 8; i++) {
            var spd = 1 + (i % 3);
            if (gameState == PS_FREEFALL || gameState == PS_CHUTE) {
                _cloudY[i] = _cloudY[i] - spd - (_fallSpeed * 0.3).toNumber();
            } else {
                _cloudY[i] = _cloudY[i] - 1;
            }
            if (_cloudY[i] < -30) {
                _cloudY[i] = _h + 10 + Math.rand().abs() % 40;
                _cloudX[i] = Math.rand().abs() % _w;
                _cloudW[i] = 12 + Math.rand().abs() % 20;
            }
        }
    }

    hidden function startLevel() {
        _playerX = (_w / 2).toFloat();
        _playerY = (_h * 20 / 100).toFloat();
        _playerVx = 0.0;
        _playerVy = 0.0;
        _altitude = 3000.0 + _level * 500.0;
        _maxAlt = _altitude;
        _fallSpeed = 0.0;
        _chuteOpen = false;
        _ringsHit = 0;
        _windPhase = 0.0;
        _windX = 0.0;
        _jumpTick = 0;
        _crashTick = 0;
        _landDist = 0.0;

        _landX = _w / 2 + (Math.rand().abs() % 40) - 20;
        _landY = _h * 80 / 100;
        _landR = 22 - _level;
        if (_landR < 10) { _landR = 10; }

        _ringCount = 5 + _level * 2;
        if (_ringCount > 20) { _ringCount = 20; }

        for (var i = 0; i < _ringCount; i++) {
            _ringX[i] = 20 + Math.rand().abs() % (_w - 40);
            _ringY[i] = _h * 25 / 100 + (i * (_h * 55 / 100)) / _ringCount + Math.rand().abs() % 15;
            _ringR[i] = 14 + Math.rand().abs() % 8;
            _ringHit[i] = false;
        }

        for (var i = 0; i < 16; i++) { _trailLife[i] = 0; }
        for (var i = 0; i < 12; i++) { _sparkLife[i] = 0; }

        gameState = PS_JUMP;
    }

    hidden function updateFreefall() {
        _fallSpeed = _fallSpeed + 0.15;
        if (_fallSpeed > 8.0) { _fallSpeed = 8.0; }

        _windPhase += 0.07;
        _windX = Math.sin(_windPhase) * (1.0 + _level.toFloat() * 0.3);

        var steerX = accelX.toFloat() / 350.0;
        var steerY = accelY.toFloat() / 500.0;
        if (steerX > 3.0) { steerX = 3.0; }
        if (steerX < -3.0) { steerX = -3.0; }
        if (steerY > 2.0) { steerY = 2.0; }
        if (steerY < -2.0) { steerY = -2.0; }

        _playerVx = _playerVx * 0.88 + steerX + _windX * 0.08;
        _playerVy = _playerVy * 0.90 + steerY;

        _playerX += _playerVx;
        _playerY += _playerVy * 0.3;

        if (_playerX < 8.0) { _playerX = 8.0; _playerVx = 0.0; }
        if (_playerX > (_w - 8).toFloat()) { _playerX = (_w - 8).toFloat(); _playerVx = 0.0; }
        if (_playerY < 10.0) { _playerY = 10.0; }
        if (_playerY > (_h - 20).toFloat()) { _playerY = (_h - 20).toFloat(); }

        _altitude = _altitude - _fallSpeed;
        if (_altitude < 0.0) { _altitude = 0.0; }

        checkRings();
        updateTrail();
        updateSparks();

        if (_altitude <= 0.0) {
            gameState = PS_CRASH;
            _crashTick = 0;
            _landGrade = "SPLAT!";
            doVibe(100, 600);
            finalScore(false);
        }
    }

    hidden function updateChute() {
        _fallSpeed = _fallSpeed * 0.92;
        if (_fallSpeed < 1.2) { _fallSpeed = 1.2; }

        _windPhase += 0.05;
        _windX = Math.sin(_windPhase) * (0.8 + _level.toFloat() * 0.2);

        var steerX = accelX.toFloat() / 250.0;
        var steerY = accelY.toFloat() / 400.0;
        if (steerX > 2.5) { steerX = 2.5; }
        if (steerX < -2.5) { steerX = -2.5; }
        if (steerY > 1.5) { steerY = 1.5; }
        if (steerY < -1.5) { steerY = -1.5; }

        _playerVx = _playerVx * 0.90 + steerX * 0.7 + _windX * 0.1;
        _playerVy = _playerVy * 0.90 + steerY * 0.5;

        _playerX += _playerVx;
        _playerY += _playerVy * 0.2;

        if (_playerX < 8.0) { _playerX = 8.0; _playerVx = 0.0; }
        if (_playerX > (_w - 8).toFloat()) { _playerX = (_w - 8).toFloat(); _playerVx = 0.0; }
        if (_playerY < 10.0) { _playerY = 10.0; }
        if (_playerY > (_h - 20).toFloat()) { _playerY = (_h - 20).toFloat(); }

        _altitude -= _fallSpeed;
        if (_altitude < 0.0) { _altitude = 0.0; }

        checkRings();
        updateTrail();

        if (_altitude <= 0.0) {
            var dx = _playerX - _landX.toFloat();
            var dy = _playerY - _landY.toFloat();
            _landDist = Math.sqrt(dx * dx + dy * dy);

            if (_landDist < _landR.toFloat()) {
                _landGrade = "BULLSEYE!";
            } else if (_landDist < _landR.toFloat() * 2.0) {
                _landGrade = "GREAT!";
            } else if (_landDist < _landR.toFloat() * 3.5) {
                _landGrade = "GOOD";
            } else {
                _landGrade = "OFF TARGET";
            }

            gameState = PS_LANDED;
            doVibe(50, 200);
            finalScore(true);
        }
    }

    hidden function checkRings() {
        for (var i = 0; i < _ringCount; i++) {
            if (_ringHit[i]) { continue; }
            var altPct = _altitude / _maxAlt;
            var ringAltPct = 1.0 - ((_ringY[i] - _h * 20 / 100).toFloat() / (_h * 60 / 100).toFloat());
            var altDiff = (altPct - ringAltPct);
            if (altDiff < 0.0) { altDiff = -altDiff; }
            if (altDiff > 0.08) { continue; }

            var dx = _playerX - _ringX[i].toFloat();
            var dy = _playerY - _ringY[i].toFloat();
            var dist = Math.sqrt(dx * dx + dy * dy);
            if (dist < _ringR[i].toFloat()) {
                _ringHit[i] = true;
                _ringsHit++;
                spawnRingSparks(_ringX[i], _ringY[i]);
                doVibe(40, 80);
            }
        }
    }

    hidden function spawnRingSparks(rx, ry) {
        for (var i = 0; i < 12; i++) {
            if (_sparkLife[i] <= 0) {
                _sparkX[i] = rx + (Math.rand().abs() % 12) - 6;
                _sparkY[i] = ry + (Math.rand().abs() % 12) - 6;
                _sparkLife[i] = 10 + Math.rand().abs() % 8;
                if (i >= 5) { break; }
            }
        }
    }

    hidden function updateTrail() {
        for (var i = 0; i < 16; i++) {
            if (_trailLife[i] > 0) { _trailLife[i]--; }
        }
        if (_tick % 2 == 0) {
            for (var i = 15; i > 0; i--) {
                _trailX[i] = _trailX[i - 1];
                _trailY[i] = _trailY[i - 1];
                _trailLife[i] = _trailLife[i - 1];
            }
            _trailX[0] = _playerX.toNumber();
            _trailY[0] = _playerY.toNumber();
            _trailLife[0] = 14;
        }
    }

    hidden function updateSparks() {
        for (var i = 0; i < 12; i++) {
            if (_sparkLife[i] > 0) { _sparkLife[i]--; }
        }
    }

    hidden function finalScore(landed) {
        var ringPts = _ringsHit * 100;
        var landPts = 0;
        if (landed) {
            if (_landDist < _landR.toFloat()) { landPts = 500; }
            else if (_landDist < _landR.toFloat() * 2.0) { landPts = 300; }
            else if (_landDist < _landR.toFloat() * 3.5) { landPts = 150; }
            else { landPts = 50; }
        }
        _score = ringPts + landPts;
        if (_score > _bestScore) { _bestScore = _score; }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }

    function doAction() {
        if (gameState == PS_MENU) {
            _level = 1;
            startLevel();
        } else if (gameState == PS_FREEFALL) {
            _chuteOpen = true;
            gameState = PS_CHUTE;
            doVibe(60, 150);
        } else if (gameState == PS_LANDED) {
            _level++;
            startLevel();
        } else if (gameState == PS_CRASH) {
            _level = 1;
            if (_score > _bestScore) { _bestScore = _score; }
            gameState = PS_MENU;
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();

        if (gameState == PS_MENU) { drawMenu(dc); return; }

        drawSkyGradient(dc);
        drawClouds(dc);

        if (gameState == PS_JUMP) { drawJumpScene(dc); }
        else if (gameState == PS_FREEFALL) { drawFreefallScene(dc); }
        else if (gameState == PS_CHUTE) { drawChuteScene(dc); }
        else if (gameState == PS_LANDED) { drawLandedScene(dc); }
        else if (gameState == PS_CRASH) { drawCrashScene(dc); }
    }

    hidden function drawSkyGradient(dc) {
        var altPct = 1.0;
        if (gameState != PS_JUMP && _maxAlt != null && _maxAlt > 0.0 && _altitude != null) {
            altPct = _altitude / _maxAlt;
        }
        if (altPct > 1.0) { altPct = 1.0; }
        if (altPct < 0.0) { altPct = 0.0; }

        var topR = (0x08 + (1.0 - altPct) * 0x40).toNumber();
        var topG = (0x15 + (1.0 - altPct) * 0x60).toNumber();
        var topB = (0x45 + (1.0 - altPct) * 0x50).toNumber();
        if (topR > 0xFF) { topR = 0xFF; }
        if (topG > 0xFF) { topG = 0xFF; }
        if (topB > 0xFF) { topB = 0xFF; }
        var topC = (topR << 16) | (topG << 8) | topB;
        dc.setColor(topC, topC);
        dc.clear();

        var gPct = (1.0 - altPct) * 0.72 + 0.10;
        if (gPct > 0.82) { gPct = 0.82; }
        var gH = (_h.toFloat() * gPct).toNumber();
        var gTop = _h - gH;

        dc.setColor(0x336633, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gTop, _w, gH);

        var pSz = (2 + (1.0 - altPct) * 12.0).toNumber();
        var i;
        var px;
        var py;
        dc.setColor(0x448844, Graphics.COLOR_TRANSPARENT);
        for (i = 0; i < 7; i++) {
            px = (i * 41 + 15) % _w;
            py = gTop + 4 + (i * 29 + 3) % (gH > 10 ? gH : 10);
            dc.fillRectangle(px, py, pSz + i * 3, pSz + i);
        }
        dc.setColor(0x225522, Graphics.COLOR_TRANSPARENT);
        for (i = 0; i < 5; i++) {
            px = (i * 53 + 30) % _w;
            py = gTop + 6 + (i * 37 + 5) % (gH > 10 ? gH : 10);
            dc.fillRectangle(px, py, pSz + i * 2, pSz);
        }

        if (altPct < 0.7) {
            dc.setColor(0x667744, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) {
                px = (i * 67 + 50) % _w;
                py = gTop + 10 + (i * 43 + 8) % (gH > 15 ? gH : 15);
                dc.fillRectangle(px, py, pSz * 2, pSz);
            }
        }

        var vx = _w / 2;
        dc.setColor(0x2D5D2D, Graphics.COLOR_TRANSPARENT);
        for (i = -3; i <= 3; i++) {
            dc.drawLine(vx, gTop, vx + i * _w / 4, _h);
        }
        var by = gTop + 5;
        var step = 3;
        for (i = 0; i < 6; i++) {
            if (by >= _h) { break; }
            dc.drawLine(0, by, _w, by);
            step = step + 2 + i * 2;
            by = by + step;
        }

        if (altPct < 0.55) {
            var rW = (1 + (0.55 - altPct) * 5.0).toNumber();
            dc.setColor(0x555544, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_w * 30 / 100, gTop, rW, gH);
            dc.fillRectangle(0, gTop + gH * 45 / 100, _w, rW);
        }

        if (altPct < 0.35) {
            var tSz = (1 + (0.35 - altPct) * 10.0).toNumber();
            dc.setColor(0x1A5C1A, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 8; i++) {
                px = (i * 31 + 8) % _w;
                py = gTop + 10 + (i * 23 + 4) % (gH > 15 ? gH : 15);
                dc.fillCircle(px, py, tSz);
            }
        }

        if (altPct < 0.55) {
            var tScale = (0.55 - altPct) / 0.55;
            var tR = (_landR.toFloat() * tScale * 2.5 + 1.0).toNumber();
            dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_landX, _landY, tR + 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_landX, _landY, tR);
            if (tR > 4) {
                dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_landX, _landY, tR * 2 / 3);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_landX, _landY, tR / 3);
            }
        }

        dc.setColor(0x88BB88, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gTop, _w, 2);
    }

    hidden function drawClouds(dc) {
        var maxA = (_maxAlt != null && _maxAlt > 0.0) ? _maxAlt : 1.0;
        var curA = (_altitude != null) ? _altitude : maxA;
        for (var i = 0; i < 8; i++) {
            if (_cloudY[i] < -25 || _cloudY[i] > _h + 25) { continue; }
            var cw = _cloudW[i];
            var altPct = curA / maxA;
            if (altPct > 1.0) { altPct = 1.0; }
            var shadow = (altPct > 0.5) ? 0xBBCCDD : 0x99AABB;
            dc.setColor(shadow, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cloudX[i] + 2, _cloudY[i] + 3, cw / 2);
            dc.fillCircle(_cloudX[i] - cw / 3 + 2, _cloudY[i] + 5, cw / 3);
            dc.fillCircle(_cloudX[i] + cw / 3 + 2, _cloudY[i] + 4, cw * 2 / 5);

            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cloudX[i], _cloudY[i], cw / 2);
            dc.fillCircle(_cloudX[i] - cw / 3, _cloudY[i] + 2, cw / 3);
            dc.fillCircle(_cloudX[i] + cw / 3, _cloudY[i] + 1, cw * 2 / 5);
            dc.setColor(0xEEF4FF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cloudX[i] - cw / 5, _cloudY[i] - cw / 6, cw / 3);
            dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cloudX[i] + cw / 5, _cloudY[i] + cw / 4, cw / 4);
        }
    }

    hidden function drawRings(dc) {
        var maxA = (_maxAlt != null && _maxAlt > 0.0) ? _maxAlt : 1.0;
        var altPct = ((_altitude != null) ? _altitude : maxA) / maxA;

        for (var i = 0; i < _ringCount; i++) {
            var ringAltPct = 1.0 - ((_ringY[i] - _h * 20 / 100).toFloat() / (_h * 60 / 100).toFloat());
            var altDiff = (altPct - ringAltPct);
            if (altDiff < 0.0) { altDiff = -altDiff; }
            if (altDiff > 0.25) { continue; }

            var proximity = 1.0 - altDiff / 0.25;
            var rx = _ringX[i];
            var ry = _ringY[i];
            var rr = _ringR[i];

            if (_ringHit[i]) {
                dc.setColor(0x22BB44, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(rx, ry, rr + 2);
                dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(rx, ry, rr);
                dc.drawCircle(rx, ry, rr + 1);
                dc.setColor(0x88FFAA, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(rx - rr + 3, ry, 2);
                dc.fillCircle(rx + rr - 3, ry, 2);
            } else {
                var pulse = (_tick % 12 < 6) ? 2 : 0;

                if (altDiff < 0.06) {
                    dc.setColor(0xFFFF22, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(rx, ry, rr + 4 + pulse);
                    dc.drawCircle(rx, ry, rr + 5 + pulse);
                    dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(rx, ry, rr + 3 + pulse);
                }

                var ringC = 0xFF5511;
                if (proximity > 0.7) { ringC = 0xFFAA22; }
                if (proximity > 0.9) { ringC = 0xFFCC44; }
                dc.setColor(ringC, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(rx, ry, rr);
                dc.drawCircle(rx, ry, rr + 1);
                dc.drawCircle(rx, ry, rr + 2);

                dc.setColor(0xFFEE88, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(rx - rr + 2, ry, 2);
                dc.fillCircle(rx + rr - 2, ry, 2);
                dc.fillCircle(rx, ry - rr + 2, 2);
                dc.fillCircle(rx, ry + rr - 2, 2);

                if (proximity > 0.5) {
                    dc.setColor(0xFFCC66, Graphics.COLOR_TRANSPARENT);
                    var sparkOff = (_tick * 3 + i * 5) % 12;
                    var sa = sparkOff.toFloat() * 3.14159 / 6.0;
                    var spx = rx + ((rr + 4) * Math.cos(sa)).toNumber();
                    var spy = ry + ((rr + 4) * Math.sin(sa)).toNumber();
                    dc.fillRectangle(spx, spy, 2, 2);
                }
            }
        }
    }

    hidden function drawTrail(dc) {
        for (var i = 0; i < 16; i++) {
            if (_trailLife[i] <= 0) { continue; }
            var life = _trailLife[i];
            var c = 0xAABBDD;
            if (life > 10) { c = 0xDDEEFF; }
            else if (life > 5) { c = 0x8899BB; }
            else { c = 0x556688; }
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            var sz = (life > 8) ? 2 : 1;
            dc.fillCircle(_trailX[i], _trailY[i], sz);
        }
    }

    hidden function drawSparks(dc) {
        for (var i = 0; i < 12; i++) {
            if (_sparkLife[i] <= 0) { continue; }
            var c = 0xFFFF44;
            if (_sparkLife[i] < 5) { c = 0xFF8822; }
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_sparkX[i], _sparkY[i], 2, 2);
        }
    }

    hidden function drawPlayer(dc, px, py, chuteOpen) {
        if (chuteOpen) {
            var cw = (_tick % 8 < 4) ? 1 : -1;

            dc.setColor(0xAA1818, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, py - 34, 25);
            dc.setColor(0xDD3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, py - 34, 22);
            dc.setColor(0xFF5544, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, py - 34, 16);

            dc.setColor(0xFFAA44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 2 + cw, py - 52, 4, 22);
            dc.setColor(0xFFDD88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 12 + cw, py - 46, 4, 14);
            dc.fillRectangle(px + 8 + cw, py - 46, 4, 14);

            dc.setColor(0x991515, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 23 + cw, py - 13, 46, 3);

            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px - 22 + cw, py - 13, px - 6, py - 2);
            dc.drawLine(px + 22 + cw, py - 13, px + 6, py - 2);
            dc.drawLine(px - 14 + cw, py - 15, px - 3, py - 1);
            dc.drawLine(px + 14 + cw, py - 15, px + 3, py - 1);
            dc.drawLine(px + cw, py - 18, px, py - 4);
        }

        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, py - 5, 5);
        dc.setColor(0x442211, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 4, py - 9, 8, 3);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 5, py - 6, 10, 1);

        dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 7, py, 14, 9);
        dc.setColor(0x3355CC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 6, py + 1, 12, 7);

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 4, py, 2, 8);
        dc.fillRectangle(px + 2, py, 2, 8);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 3, py + 2, 6, 4);

        if (chuteOpen) {
            dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 9, py - 2, 2, 5);
            dc.fillRectangle(px + 7, py - 2, 2, 5);
            dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 9, py - 3, 2, 2);
            dc.fillRectangle(px + 7, py - 3, 2, 2);

            dc.setColor(0x222266, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 3, py + 9, 3, 6);
            dc.fillRectangle(px, py + 9, 3, 6);
            dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 3, py + 15, 3, 2);
            dc.fillRectangle(px, py + 15, 3, 2);
        } else {
            var aw = (_tick % 6 < 3) ? 1 : -1;

            dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 14, py + 1 + aw, 7, 3);
            dc.fillRectangle(px + 7, py + 1 - aw, 7, 3);
            dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 16, py + 1 + aw, 2, 3);
            dc.fillRectangle(px + 14, py + 1 - aw, 2, 3);

            dc.setColor(0x222266, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 7, py + 9, 3, 5);
            dc.fillRectangle(px + 4, py + 9, 3, 5);
            dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 8, py + 14, 4, 2);
            dc.fillRectangle(px + 4, py + 14, 4, 2);
        }

        if (!chuteOpen && _fallSpeed > 3.0) {
            var lc = ((_fallSpeed - 3.0) * 2.0).toNumber();
            if (lc > 8) { lc = 8; }
            dc.setColor(0xAABBDD, Graphics.COLOR_TRANSPARENT);
            for (var li = 0; li < lc; li++) {
                var lx = px - 18 + (li * 36 / (lc > 0 ? lc : 1));
                dc.drawLine(lx, py - 12, lx, py - 18 - Math.rand().abs() % 5);
            }
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, 4, Graphics.FONT_XTINY, _altitude.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        var altBarW = _w * 8 / 100;
        var altBarH = _h * 50 / 100;
        var altBarX = _w - altBarW - 4;
        var altBarY = (_h - altBarH) / 2;
        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(altBarX, altBarY, altBarW, altBarH);
        var altPct = _altitude / _maxAlt;
        if (altPct > 1.0) { altPct = 1.0; }
        var fillH = (altBarH * altPct).toNumber();
        dc.setColor(altPct > 0.3 ? 0x44AAFF : (altPct > 0.1 ? 0xFFCC22 : 0xFF4444), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(altBarX, altBarY + altBarH - fillH, altBarW, fillH);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 4, Graphics.FONT_XTINY, _ringsHit + "/" + _ringCount, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 16, Graphics.FONT_XTINY, "L" + _level, Graphics.TEXT_JUSTIFY_LEFT);

        if (_altitude < 600.0 && !_chuteOpen) {
            var warn = (_tick % 8 < 4) ? 0xFF0000 : 0xFF8800;
            dc.setColor(warn, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 85 / 100, Graphics.FONT_SMALL, "DEPLOY!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_chuteOpen) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 90 / 100, Graphics.FONT_XTINY, "CHUTE OPEN", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var speedPct = _fallSpeed / 8.0;
            if (speedPct > 1.0) { speedPct = 1.0; }
            var spdBarW = _w * 40 / 100;
            var spdBarX = (_w - spdBarW) / 2;
            var spdBarY = _h * 92 / 100;
            dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(spdBarX, spdBarY, spdBarW, 4);
            var spdC = speedPct > 0.7 ? 0xFF4444 : (speedPct > 0.4 ? 0xFFCC22 : 0x44FF44);
            dc.setColor(spdC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(spdBarX, spdBarY, (spdBarW * speedPct).toNumber(), 4);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, spdBarY - 10, Graphics.FONT_XTINY, "SPEED", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var wx = _windX;
        if (wx < 0.0) { wx = -wx; }
        if (wx > 0.3) {
            var windDir = _windX > 0.0 ? ">>>" : "<<<";
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, 16, Graphics.FONT_XTINY, windDir, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x081530, 0x081530);
        dc.clear();

        dc.setColor(0x0A1E3A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 30 / 100, _w, _h * 30 / 100);
        dc.setColor(0x152848, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 60 / 100, _w, _h * 18 / 100);

        dc.setColor(0x336633, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 78 / 100, _w, _h * 22 / 100);
        dc.setColor(0x448844, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 78 / 100, _w, 2);
        dc.setColor(0x225522, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 18 / 100, _h * 83 / 100, _w * 25 / 100, _h * 6 / 100);
        dc.setColor(0x448844, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 55 / 100, _h * 85 / 100, _w * 18 / 100, _h * 5 / 100);
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w / 2, _h * 88 / 100, 5);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w / 2, _h * 88 / 100, 3);
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w / 2, _h * 88 / 100, 1);

        drawClouds(dc);

        dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 15 / 100, _h * 8 / 100, 1);
        dc.fillCircle(_w * 45 / 100, _h * 5 / 100, 1);
        dc.fillCircle(_w * 75 / 100, _h * 10 / 100, 2);

        var pulse = (_tick % 30 < 15) ? 0x44AAFF : 0x2288DD;
        dc.setColor(0x113355, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, _h * 10 / 100 + 1, Graphics.FONT_SMALL, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 10 / 100, Graphics.FONT_SMALL, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 22 / 100, Graphics.FONT_SMALL, "PARACHUTE", Graphics.TEXT_JUSTIFY_CENTER);

        drawPlayer(dc, _w / 2, _h * 46 / 100, true);

        dc.setColor(0x7799BB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 62 / 100, Graphics.FONT_XTINY, "Fly through rings!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 69 / 100, Graphics.FONT_XTINY, "Tilt to steer", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 76 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 83 / 100, Graphics.FONT_XTINY, "Tap to jump", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawJumpScene(dc) {
        var progress = _jumpTick.toFloat() / 40.0;
        var py = (_h * 12 / 100 + progress * _h * 18 / 100).toNumber();

        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h * 6 / 100);
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 6 / 100, _w, 3);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w / 2 - 25, 0, 50, _h * 6 / 100 + 3);

        var shake = (_jumpTick % 4 < 2) ? 2 : -2;
        drawPlayer(dc, _w / 2 + shake, py, false);

        var flash = (_jumpTick % 8 < 4) ? 0xFFFF44 : 0xFFAA22;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 50 / 100, Graphics.FONT_MEDIUM, "JUMP!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 65 / 100, Graphics.FONT_XTINY, _altitude.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFreefallScene(dc) {
        drawRings(dc);
        drawTrail(dc);
        drawSparks(dc);

        var sway = (Math.sin(_tick.toFloat() / 3.0) * 2.0).toNumber();
        drawPlayer(dc, _playerX.toNumber() + sway, _playerY.toNumber(), false);

        drawHUD(dc);
    }

    hidden function drawChuteScene(dc) {
        drawRings(dc);
        drawTrail(dc);
        drawSparks(dc);

        drawPlayer(dc, _playerX.toNumber(), _playerY.toNumber(), true);

        drawHUD(dc);
    }

    hidden function drawLandedScene(dc) {
        drawPlayer(dc, _playerX.toNumber(), _playerY.toNumber(), true);

        var gradeC = 0x44FF44;
        if (_landDist > _landR.toFloat() * 2.0) { gradeC = 0xFFCC22; }
        if (_landDist > _landR.toFloat() * 3.5) { gradeC = 0xFF6644; }
        dc.setColor(gradeC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 12 / 100, Graphics.FONT_SMALL, _landGrade, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 26 / 100, Graphics.FONT_XTINY, "RINGS " + _ringsHit + "/" + _ringCount, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 36 / 100, Graphics.FONT_SMALL, _score + " PTS", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 58 / 100, Graphics.FONT_XTINY, "Tap: level " + (_level + 1), Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawCrashScene(dc) {
        var flashBg = (_crashTick % 4 < 2) ? 0x220800 : 0x110400;
        dc.setColor(flashBg, flashBg);
        dc.clear();

        dc.setColor(0x334422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 50 / 100, _w, _h * 50 / 100);

        dc.setColor(0x221100, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w / 2, _h * 55 / 100, 18);
        dc.setColor(0x443311, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w / 2, _h * 55 / 100, 12);

        dc.setColor(0x886644, Graphics.COLOR_TRANSPARENT);
        for (var di = 0; di < 10; di++) {
            var sx = _w / 2 + (Math.rand().abs() % 50) - 25;
            var sy = _h * 55 / 100 + (Math.rand().abs() % 30) - 15;
            dc.fillRectangle(sx, sy, 2 + Math.rand().abs() % 4, 2 + Math.rand().abs() % 3);
        }

        var flash = (_crashTick % 6 < 3) ? 0xFF2222 : 0xCC0000;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 18 / 100, Graphics.FONT_SMALL, "SPLAT!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 32 / 100, Graphics.FONT_XTINY, "No chute!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 42 / 100, Graphics.FONT_XTINY, "RINGS " + _ringsHit + "/" + _ringCount, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 68 / 100, Graphics.FONT_XTINY, "" + _score + " pts", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 76 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 84 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
