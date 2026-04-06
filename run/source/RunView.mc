using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum {
    RS_MENU,
    RS_INTRO,
    RS_SCAN,
    RS_FOUND,
    RS_RUN,
    RS_CAUGHT,
    RS_ESCAPE,
    RS_LEVELS
}

class RunView extends WatchUi.View {

    var gameState;
    var accelX;
    var accelY;
    var accelZ;
    var shakeMag;

    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;

    hidden var _timer;
    hidden var _tick;

    hidden var _level;
    hidden var _maxLevels;

    // scan phase
    hidden var _exitAngle;
    hidden var _scanAngle;
    hidden var _scanRadius;
    hidden var _scanFound;
    hidden var _scanTimer;
    hidden var _scanHintTick;

    // decoys
    hidden var _decoyAngles;
    hidden var _decoyCount;

    // run phase
    hidden var _playerDist;
    hidden var _exitDist;
    hidden var _monsterDist;
    hidden var _monsterSpeed;
    hidden var _playerSpeed;
    hidden var _runShake;
    hidden var _heartbeatTick;
    hidden var _vibeInterval;
    hidden var _lastVibeTick;

    // atmosphere
    hidden var _particles;
    hidden var _flashAlpha;
    hidden var _introTick;

    // monster info
    hidden var _monsterNames;
    hidden var _monsterColors;
    hidden var _monsterIdx;

    // score
    hidden var _survived;
    hidden var _totalDist;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());

        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _cx = _w / 2;
        _cy = _h / 2;

        _monsterNames = ["Vexor", "Undead", "Dzikko", "Rocky", "Batsy"];
        _monsterColors = [0xFF2222, 0x668866, 0x885522, 0x888888, 0x442266];

        _particles = new [30];
        for (var i = 0; i < 30; i++) {
            _particles[i] = [
                Math.rand().abs() % _w,
                Math.rand().abs() % _h,
                1 + Math.rand().abs() % 3
            ];
        }

        _tick = 0;
        _level = 0;
        _maxLevels = 5;
        _survived = 0;
        _totalDist = 0.0;

        accelX = 0;
        accelY = 0;
        accelZ = 0;
        shakeMag = 0;

        gameState = RS_MENU;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 50, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _tick++;
        updateParticles();

        if (gameState == RS_INTRO) {
            _introTick++;
            if (_introTick >= 60) {
                startScan();
            }
        } else if (gameState == RS_SCAN) {
            updateScan();
        } else if (gameState == RS_FOUND) {
            _scanTimer++;
            if (_scanTimer >= 30) {
                startRun();
            }
        } else if (gameState == RS_RUN) {
            updateRun();
        } else if (gameState == RS_CAUGHT) {
            _introTick++;
        } else if (gameState == RS_ESCAPE) {
            _introTick++;
        }

        WatchUi.requestUpdate();
    }

    hidden function updateParticles() {
        for (var i = 0; i < 30; i++) {
            var p = _particles[i];
            p[1] = p[1] + p[2];
            if (gameState == RS_RUN || gameState == RS_SCAN) {
                p[0] = p[0] + ((i % 2 == 0) ? 1 : -1);
            }
            if (p[1] > _h) { p[1] = 0; p[0] = Math.rand().abs() % _w; }
            if (p[0] < 0) { p[0] = _w - 1; }
            if (p[0] >= _w) { p[0] = 0; }
        }
    }

    function startLevel() {
        _level++;
        _monsterIdx = (_level - 1) % _monsterNames.size();
        gameState = RS_INTRO;
        _introTick = 0;
    }

    hidden function startScan() {
        gameState = RS_SCAN;
        _exitAngle = (Math.rand().abs() % 360).toFloat();
        _scanAngle = 0.0;
        _scanRadius = 0.0;
        _scanFound = false;
        _scanTimer = 0;
        _scanHintTick = 0;
        _flashAlpha = 0;

        _decoyCount = _level < 3 ? 1 : (_level < 5 ? 2 : 3);
        _decoyAngles = new [_decoyCount];
        for (var i = 0; i < _decoyCount; i++) {
            var da = _exitAngle + 60.0 + (Math.rand().abs() % 240).toFloat();
            if (da >= 360.0) { da -= 360.0; }
            _decoyAngles[i] = da;
        }
    }

    hidden function updateScan() {
        _scanTimer++;

        var rawAngle = Math.atan2(accelX.toFloat(), accelY.toFloat());
        _scanAngle = rawAngle * 180.0 / 3.14159;
        if (_scanAngle < 0.0) { _scanAngle += 360.0; }

        var diff = _scanAngle - _exitAngle;
        if (diff < 0.0) { diff = -diff; }
        if (diff > 180.0) { diff = 360.0 - diff; }

        _scanRadius = diff;

        if (diff < 20.0) {
            _scanHintTick++;
            if (_scanHintTick >= 15) {
                _scanFound = true;
                gameState = RS_FOUND;
                _scanTimer = 0;
                doVibe(80, 400);
            }
        } else {
            _scanHintTick = 0;
        }

        if (diff < 40.0 && _tick % 20 == 0) {
            doVibe(30, 100);
        }
    }

    hidden function startRun() {
        gameState = RS_RUN;
        _playerDist = 0.0;
        _exitDist = 60.0 + (_level * 15).toFloat();
        _monsterDist = -25.0 - (_level * 5).toFloat();
        _monsterSpeed = 0.6 + _level.toFloat() * 0.12;
        _playerSpeed = 0.0;
        _runShake = 0;
        _heartbeatTick = 0;
        _vibeInterval = 25;
        _lastVibeTick = 0;
    }

    hidden function updateRun() {
        _playerSpeed = _playerSpeed * 0.85;
        var shakeBoost = shakeMag.toFloat() / 3000.0;
        if (shakeBoost > 2.5) { shakeBoost = 2.5; }
        _playerSpeed += shakeBoost;
        if (_playerSpeed < 0.1) { _playerSpeed = 0.1; }

        _playerDist += _playerSpeed;
        _monsterDist += _monsterSpeed;

        if (_monsterSpeed < 1.8 + _level.toFloat() * 0.1) {
            _monsterSpeed += 0.005;
        }

        var gap = _playerDist - _monsterDist;
        if (gap < 60.0) {
            _vibeInterval = (gap * 0.4).toNumber();
            if (_vibeInterval < 3) { _vibeInterval = 3; }
        } else {
            _vibeInterval = 30;
        }

        _heartbeatTick++;
        if (_heartbeatTick >= _vibeInterval) {
            _heartbeatTick = 0;
            var intensity = 100 - (gap * 1.2).toNumber();
            if (intensity < 20) { intensity = 20; }
            if (intensity > 100) { intensity = 100; }
            doVibe(intensity, 150);
        }

        if (_monsterDist >= _playerDist) {
            gameState = RS_CAUGHT;
            _introTick = 0;
            doVibe(100, 1000);
        }

        if (_playerDist >= _exitDist) {
            gameState = RS_ESCAPE;
            _introTick = 0;
            _survived++;
            _totalDist = _totalDist + _exitDist;
            doVibe(60, 300);
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }

    function doAction() {
        if (gameState == RS_MENU) {
            startLevel();
        } else if (gameState == RS_SCAN) {
            // nothing - use accel
        } else if (gameState == RS_CAUGHT) {
            _level = 0;
            _survived = 0;
            _totalDist = 0.0;
            gameState = RS_MENU;
        } else if (gameState == RS_ESCAPE) {
            if (_level >= _maxLevels) {
                gameState = RS_LEVELS;
                _introTick = 0;
            } else {
                startLevel();
            }
        } else if (gameState == RS_LEVELS) {
            _level = 0;
            _survived = 0;
            _totalDist = 0.0;
            gameState = RS_MENU;
        }
    }

    // ===== Drawing =====

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x000000, 0x000000);
        dc.clear();

        if (gameState == RS_MENU) { drawMenu(dc, w, h); return; }
        if (gameState == RS_INTRO) { drawIntro(dc, w, h); return; }
        if (gameState == RS_SCAN) { drawScanScene(dc, w, h); return; }
        if (gameState == RS_FOUND) { drawFoundScene(dc, w, h); return; }
        if (gameState == RS_RUN) { drawRunScene(dc, w, h); return; }
        if (gameState == RS_CAUGHT) { drawCaughtScene(dc, w, h); return; }
        if (gameState == RS_ESCAPE) { drawEscapeScene(dc, w, h); return; }
        if (gameState == RS_LEVELS) { drawFinalScene(dc, w, h); return; }
    }

    hidden function drawDust(dc, w, h, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 30; i++) {
            var p = _particles[i];
            dc.fillRectangle(p[0], p[1], p[2], p[2]);
        }
    }

    hidden function drawMenu(dc, w, h) {
        drawDust(dc, w, h, 0x111122);

        var pulse = (_tick % 40 < 20) ? 0xFF2222 : 0xCC1111;
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 30 / 100, Graphics.FONT_MEDIUM, "RUN", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x443344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 48 / 100, Graphics.FONT_XTINY, "They are coming.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 56 / 100, Graphics.FONT_XTINY, "Find the exit.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 64 / 100, Graphics.FONT_XTINY, "Shake to run.", Graphics.TEXT_JUSTIFY_CENTER);

        drawMonsterEyes(dc, w / 2, h * 82 / 100, 0xFF2222);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 92 / 100, Graphics.FONT_XTINY, "Press to start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawIntro(dc, w, h) {
        drawDust(dc, w, h, 0x0A0A15);

        var fade = _introTick * 4;
        if (fade > 255) { fade = 255; }

        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 25 / 100, Graphics.FONT_SMALL, "LEVEL " + _level, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_monsterColors[_monsterIdx], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_MEDIUM, _monsterNames[_monsterIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x554444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 60 / 100, Graphics.FONT_XTINY, "is hunting you...", Graphics.TEXT_JUSTIFY_CENTER);

        if (_introTick > 30) {
            drawMonsterEyes(dc, w / 2, h * 78 / 100, _monsterColors[_monsterIdx]);
        }
    }

    hidden function drawScanScene(dc, w, h) {
        drawDarkness(dc, w, h);
        drawDust(dc, w, h, 0x0A0A12);

        var beamAngle = _scanAngle * 3.14159 / 180.0;
        var beamLen = w * 35 / 100;
        var bx = _cx + (beamLen * Math.sin(beamAngle)).toNumber();
        var by = _cy - (beamLen * Math.cos(beamAngle)).toNumber();

        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(6);
        dc.drawLine(_cx, _cy, bx, by);
        dc.setPenWidth(1);
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, 12);
        dc.setColor(0x667788, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, 6);

        for (var i = 0; i < _decoyCount; i++) {
            drawDoorIcon(dc, w, h, _decoyAngles[i], 0x442222, false);
        }

        var diff = _scanAngle - _exitAngle;
        if (diff < 0.0) { diff = -diff; }
        if (diff > 180.0) { diff = 360.0 - diff; }
        var doorBright = diff < 40.0;
        drawDoorIcon(dc, w, h, _exitAngle, doorBright ? 0x44FF44 : 0x226622, true);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 3);

        if (diff < 40.0) {
            var warmth = ((40.0 - diff) / 40.0 * 100.0).toNumber();
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 10 / 100, Graphics.FONT_XTINY, "WARM " + warmth + "%", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (diff < 80.0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 10 / 100, Graphics.FONT_XTINY, "COLD...", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 10 / 100, Graphics.FONT_XTINY, "FREEZING", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 88 / 100, Graphics.FONT_XTINY, "Move wrist to scan", Graphics.TEXT_JUSTIFY_CENTER);

        var monEyeX = _cx - (w * 20 / 100);
        var monEyeY = _cy + (h * 30 / 100);
        if (_tick % 60 < 15) {
            drawMonsterEyes(dc, monEyeX, monEyeY, _monsterColors[_monsterIdx]);
        }
    }

    hidden function drawDoorIcon(dc, w, h, angle, color, real) {
        var rad = angle * 3.14159 / 180.0;
        var doorR = w * 30 / 100;
        var dx = _cx + (doorR * Math.sin(rad)).toNumber();
        var dy = _cy - (doorR * Math.cos(rad)).toNumber();

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (real) {
            dc.fillRectangle(dx - 4, dy - 6, 8, 12);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dx - 2, dy - 4, 4, 8);
        } else {
            dc.fillRectangle(dx - 3, dy - 5, 6, 10);
            dc.setColor(0x221111, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dx - 1, dy - 3, 2, 6);
        }
    }

    hidden function drawDarkness(dc, w, h) {
        dc.setColor(0x050510, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h * 8 / 100);
        dc.fillRectangle(0, h * 92 / 100, w, h * 8 / 100);
        dc.fillRectangle(0, 0, w * 5 / 100, h);
        dc.fillRectangle(w * 95 / 100, 0, w * 5 / 100, h);
    }

    hidden function drawFoundScene(dc, w, h) {
        drawDust(dc, w, h, 0x0A0A12);

        var flash = (_scanTimer % 6 < 3) ? 0x44FF44 : 0x228822;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 25 / 100, Graphics.FONT_MEDIUM, "EXIT FOUND!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - 8, h * 45 / 100, 16, 24);
        dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - 4, h * 49 / 100, 8, 16);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_SMALL, "NOW RUN!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 85 / 100, Graphics.FONT_XTINY, "Shake to sprint!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawRunScene(dc, w, h) {
        drawDust(dc, w, h, 0x0A0A15);

        var gap = _playerDist - _monsterDist;
        var dangerLevel = 1.0 - (gap / 60.0);
        if (dangerLevel < 0.0) { dangerLevel = 0.0; }
        if (dangerLevel > 1.0) { dangerLevel = 1.0; }

        var edgeR = (dangerLevel * 80.0).toNumber();
        if (edgeR > 15) {
            dc.setColor(0x330000 + (edgeR * 2) * 0x10000, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(0, 0, w, h);
            if (edgeR > 40) {
                dc.drawRectangle(1, 1, w - 2, h - 2);
            }
            if (edgeR > 60) {
                dc.drawRectangle(2, 2, w - 4, h - 4);
            }
        }

        // corridor floor lines
        var corridorFlash = (_tick % 4 < 2 && _playerSpeed > 0.5) ? 1 : 0;
        dc.setColor(0x111122 + corridorFlash * 0x050505, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 8; i++) {
            var ly = h * 65 / 100 + i * 5;
            var off = (_tick * 3 + i * 7) % w;
            dc.fillRectangle((w / 2 - 30 + off) % w, ly, 4, 1);
            dc.fillRectangle((w / 2 + 20 - off + w) % w, ly + 2, 3, 1);
        }

        var progressPct = _playerDist / _exitDist;
        if (progressPct > 1.0) { progressPct = 1.0; }

        // door at the end - getting bigger as player approaches
        var doorSize = 4 + (progressPct * 20.0).toNumber();
        var doorY = h * 28 / 100 - (progressPct * h * 8 / 100).toNumber();
        dc.setColor(0x226622, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - doorSize / 2, doorY, doorSize, doorSize * 3 / 2);
        dc.setColor(0x88FF88, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - doorSize / 4, doorY + doorSize / 4, doorSize / 2, doorSize);

        // player (running sprite)
        var playerY = h * 55 / 100;
        var bounce = (_tick % 6 < 3) ? -2 : 2;
        if (_playerSpeed < 0.3) { bounce = 0; }
        drawPlayerSprite(dc, w / 2, playerY + bounce);

        // monster behind
        var monsterScreenY = playerY + 10;
        var monsterScreenX = w / 2;
        if (gap < 50.0) {
            var monSize = (6.0 + (50.0 - gap) * 0.4).toNumber();
            if (monSize > 25) { monSize = 25; }
            var monY2 = monsterScreenY + (gap * 0.5).toNumber();
            drawMonsterSprite(dc, monsterScreenX, monY2, monSize);
        }

        drawMonsterEyes(dc, monsterScreenX, monsterScreenY + (gap * 0.4).toNumber() + 10, _monsterColors[_monsterIdx]);

        // HUD
        // distance bar
        var barW = w * 60 / 100;
        var barX = (w - barW) / 2;
        var barY = h * 12 / 100;
        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, 6);
        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        var fillW = (barW * progressPct).toNumber();
        dc.fillRectangle(barX, barY, fillW, 6);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        var monPct = (_monsterDist / _exitDist);
        if (monPct < 0.0) { monPct = 0.0; }
        var monMarker = barX + (barW * monPct).toNumber();
        dc.fillRectangle(monMarker - 1, barY - 2, 3, 10);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, barY + 8, Graphics.FONT_XTINY, (_exitDist - _playerDist).toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        // speed indicator
        var spdPct = _playerSpeed / 2.5;
        if (spdPct > 1.0) { spdPct = 1.0; }
        var spdBarW = w * 30 / 100;
        var spdBarX = (w - spdBarW) / 2;
        var spdBarY = h * 90 / 100;
        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(spdBarX, spdBarY, spdBarW, 4);
        var spdC = spdPct > 0.6 ? 0x44CCFF : (spdPct > 0.3 ? 0xFFCC22 : 0xFF4444);
        dc.setColor(spdC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(spdBarX, spdBarY, (spdBarW * spdPct).toNumber(), 4);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, spdBarY - 12, Graphics.FONT_XTINY, "SHAKE!", Graphics.TEXT_JUSTIFY_CENTER);

        // heartbeat text
        if (_vibeInterval < 8) {
            var hFlash = (_tick % 4 < 2) ? 0xFF2222 : 0x880000;
            dc.setColor(hFlash, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 90 / 100, h * 45 / 100, Graphics.FONT_XTINY, "<3", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawPlayerSprite(dc, x, y) {
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 5);
        dc.setColor(0x2288DD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 3);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 2, y - 2, 1, 1);
        dc.fillRectangle(x + 1, y - 2, 1, 1);

        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        var legOff = (_tick % 6 < 3) ? 2 : -2;
        dc.fillRectangle(x - 3 + legOff, y + 5, 2, 3);
        dc.fillRectangle(x + 1 - legOff, y + 5, 2, 3);
    }

    hidden function drawMonsterSprite(dc, x, y, sz) {
        dc.setColor(_monsterColors[_monsterIdx], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, sz);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, sz - 2);
        dc.setColor(_monsterColors[_monsterIdx], Graphics.COLOR_TRANSPARENT);

        var toothSz = sz / 4;
        if (toothSz < 1) { toothSz = 1; }
        dc.fillRectangle(x - sz / 2, y + sz / 3, toothSz, toothSz);
        dc.fillRectangle(x, y + sz / 3, toothSz, toothSz);
        dc.fillRectangle(x + sz / 3, y + sz / 3, toothSz, toothSz);
    }

    hidden function drawMonsterEyes(dc, x, y, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var blink = (_tick % 50 < 3);
        if (!blink) {
            dc.fillCircle(x - 5, y, 2);
            dc.fillCircle(x + 5, y, 2);
        }
        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        if (!blink) {
            dc.fillRectangle(x - 5, y, 1, 1);
            dc.fillRectangle(x + 5, y, 1, 1);
        }
    }

    hidden function drawCaughtScene(dc, w, h) {
        var flashBg = (_introTick % 4 < 2) ? 0x220000 : 0x110000;
        dc.setColor(flashBg, flashBg);
        dc.clear();
        drawDust(dc, w, h, 0x1A0000);

        drawMonsterSprite(dc, w / 2, h * 35 / 100, 25);
        drawMonsterEyes(dc, w / 2, h * 32 / 100, _monsterColors[_monsterIdx]);

        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 55 / 100, Graphics.FONT_MEDIUM, "CAUGHT!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_monsterColors[_monsterIdx], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 68 / 100, Graphics.FONT_SMALL, _monsterNames[_monsterIdx], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x886666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_XTINY, "got you.", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 90 / 100, Graphics.FONT_XTINY, "Press to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawEscapeScene(dc, w, h) {
        drawDust(dc, w, h, 0x0A1A0A);

        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - 12, h * 20 / 100, 24, 36);
        dc.setColor(0xAAFFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - 8, h * 24 / 100, 16, 28);

        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 50 / 100, Graphics.FONT_MEDIUM, "ESCAPED!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 64 / 100, Graphics.FONT_XTINY, "Level " + _level + " / " + _maxLevels, Graphics.TEXT_JUSTIFY_CENTER);

        if (_level < _maxLevels) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 74 / 100, Graphics.FONT_XTINY, "Next: " + _monsterNames[_level % _monsterNames.size()], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 88 / 100, Graphics.FONT_XTINY, "Press to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFinalScene(dc, w, h) {
        drawDust(dc, w, h, 0x0A0A0A);

        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_MEDIUM, "SURVIVED!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 30 / 100, Graphics.FONT_SMALL, _survived + " / " + _maxLevels, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 45 / 100, Graphics.FONT_XTINY, "Total: " + _totalDist.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        var grade;
        if (_survived >= 5) { grade = "UNTOUCHABLE"; }
        else if (_survived >= 4) { grade = "FAST LEGS"; }
        else if (_survived >= 3) { grade = "SURVIVOR"; }
        else if (_survived >= 2) { grade = "LUCKY"; }
        else { grade = "ALMOST..."; }

        dc.setColor(0x44FFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 58 / 100, Graphics.FONT_MEDIUM, grade, Graphics.TEXT_JUSTIFY_CENTER);

        drawPlayerSprite(dc, w / 2, h * 76 / 100);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 90 / 100, Graphics.FONT_XTINY, "Press to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
