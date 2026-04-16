using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum {
    GS_MENU,
    GS_READY,
    GS_THROW,
    GS_FAIL,
    GS_OVER
}

class BitochiAxeArcadeView extends WatchUi.View {

    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;
    hidden var _timer;
    hidden var _tick;

    hidden var _logR;
    hidden var _logAngle;
    hidden var _logSpeed;
    hidden var _logDir;
    hidden var _logRadiusPct;

    hidden const MAX_STUCK = 40;
    hidden var _stuckAngles;
    hidden var _stuckCount;

    hidden const MAX_HAZ = 5;
    hidden var _hazAngles;
    hidden var _hazCount;
    hidden var _hazSize;

    hidden var _appleAngle;
    hidden var _appleActive;
    hidden var _appleBurst;

    hidden var _axeY;
    hidden var _axeVy;
    hidden var _axeSpin;

    hidden var _score;
    hidden var _bestScore;
    hidden var _level;
    hidden var _axesThisLevel;
    hidden var _axesPerLevel;
    hidden var _hitMinDeg;
    hidden var _isBoss;

    hidden var _lives;

    hidden var _combo;
    hidden var _comboMult;

    hidden var _stickAnim;
    hidden var _failAnim;
    hidden var _failAxeX;
    hidden var _failAxeY;
    hidden var _failAxeVx;
    hidden var _failAxeVy;
    hidden var _failAxeRot;

    hidden var _shakeTimer;
    hidden var _shakeOx;
    hidden var _shakeOy;
    hidden var _flashTimer;

    hidden var _dirChangeTimer;
    hidden var _dirWarnTimer;

    hidden const MAX_SPARKS = 10;
    hidden var _spkX;
    hidden var _spkY;
    hidden var _spkVx;
    hidden var _spkVy;
    hidden var _spkLife;
    hidden var _spkColor;

    hidden const CHIP_N = 10;
    hidden var _chipX;
    hidden var _chipY;
    hidden var _chipVx;
    hidden var _chipVy;
    hidden var _chipLife;

    hidden var _comboMsg;
    hidden var _comboTimer;

    hidden var _bgStars;

    hidden const CROWD_N = 8;
    hidden var _crowdX;
    hidden var _crowdJump;
    hidden var _crowdCol;
    hidden var _crowdHype;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _cx = _w / 2;
        _cy = _h / 2;
        _tick = 0;
        gameState = GS_MENU;

        _logRadiusPct = 18;
        _logR = _w * _logRadiusPct / 100;
        _logAngle = 0.0;
        _logSpeed = 1.2;
        _logDir = 1;

        _stuckAngles = new [MAX_STUCK];
        for (var i = 0; i < MAX_STUCK; i++) { _stuckAngles[i] = 0.0; }
        _stuckCount = 0;

        _hazAngles = new [MAX_HAZ];
        for (var i = 0; i < MAX_HAZ; i++) { _hazAngles[i] = 0.0; }
        _hazCount = 0;
        _hazSize = 16.0;

        _appleAngle = 0.0;
        _appleActive = false;
        _appleBurst = 0;

        _axeY = 0.0;
        _axeVy = 0.0;
        _axeSpin = 0.0;

        _score = 0;
        var bs = Application.Storage.getValue("arcBest");
        _bestScore = (bs != null) ? bs : 0;
        _level = 1;
        _axesThisLevel = 0;
        _axesPerLevel = 5;
        _hitMinDeg = 5.0;
        _isBoss = false;

        _lives = 3;

        _combo = 0;
        _comboMult = 1;

        _stickAnim = 0; _failAnim = 0;
        _failAxeX = 0.0; _failAxeY = 0.0;
        _failAxeVx = 0.0; _failAxeVy = 0.0; _failAxeRot = 0.0;

        _shakeTimer = 0; _shakeOx = 0; _shakeOy = 0;
        _flashTimer = 0;
        _dirChangeTimer = 0;
        _dirWarnTimer = 0;

        _spkX = new [MAX_SPARKS]; _spkY = new [MAX_SPARKS];
        _spkVx = new [MAX_SPARKS]; _spkVy = new [MAX_SPARKS];
        _spkLife = new [MAX_SPARKS]; _spkColor = new [MAX_SPARKS];
        for (var i = 0; i < MAX_SPARKS; i++) {
            _spkLife[i] = 0; _spkX[i] = 0.0; _spkY[i] = 0.0;
            _spkVx[i] = 0.0; _spkVy[i] = 0.0; _spkColor[i] = 0;
        }

        _chipX = new [CHIP_N]; _chipY = new [CHIP_N];
        _chipVx = new [CHIP_N]; _chipVy = new [CHIP_N];
        _chipLife = new [CHIP_N];
        for (var i = 0; i < CHIP_N; i++) {
            _chipLife[i] = 0; _chipX[i] = 0.0; _chipY[i] = 0.0;
            _chipVx[i] = 0.0; _chipVy[i] = 0.0;
        }

        _comboMsg = ""; _comboTimer = 0;

        _bgStars = new [16];
        for (var i = 0; i < 16; i++) {
            _bgStars[i] = [Math.rand().abs() % _w, Math.rand().abs() % _h, 1 + Math.rand().abs() % 3];
        }

        _crowdX = new [CROWD_N];
        _crowdJump = new [CROWD_N];
        _crowdCol = new [CROWD_N];
        var ccols = [0xDD6644, 0x44AADD, 0xDDDD44, 0x44DD66, 0xDD44AA, 0xAAAADD, 0xDDAA44];
        for (var i = 0; i < CROWD_N; i++) {
            _crowdX[i] = _w * 8 / 100 + (i * (_w * 84 / 100)) / CROWD_N;
            _crowdJump[i] = 0;
            _crowdCol[i] = ccols[i % 7];
        }
        _crowdHype = 0;
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
        if (_flashTimer > 0) { _flashTimer--; }
        if (_comboTimer > 0) { _comboTimer--; }
        if (_appleBurst > 0) { _appleBurst--; }
        if (_crowdHype > 0) { _crowdHype--; }

        for (var i = 0; i < MAX_SPARKS; i++) {
            if (_spkLife[i] <= 0) { continue; }
            _spkVy[i] += 0.12;
            _spkX[i] += _spkVx[i]; _spkY[i] += _spkVy[i];
            _spkLife[i]--;
        }
        for (var i = 0; i < CHIP_N; i++) {
            if (_chipLife[i] <= 0) { continue; }
            _chipVy[i] += 0.15;
            _chipX[i] += _chipVx[i]; _chipY[i] += _chipVy[i];
            _chipLife[i]--;
        }

        for (var i = 0; i < CROWD_N; i++) {
            if (_crowdJump[i] > 0) { _crowdJump[i]--; }
            if (_crowdHype > 5 && _tick % 4 == i % 4) {
                _crowdJump[i] = 3 + Math.rand().abs() % 4;
            }
        }

        if (gameState == GS_READY || gameState == GS_THROW) {
            _logAngle += _logSpeed * _logDir.toFloat();
            if (_logAngle >= 360.0) { _logAngle -= 360.0; }
            if (_logAngle < 0.0) { _logAngle += 360.0; }

            if (_dirChangeTimer > 0) {
                _dirChangeTimer--;
                if (_dirChangeTimer == 15) { _dirWarnTimer = 15; }
                if (_dirChangeTimer == 0) {
                    _logDir = -_logDir;
                    _dirWarnTimer = 0;
                }
            } else if (gameState == GS_READY && _level > 2 && Math.rand().abs() % 180 == 0) {
                _dirChangeTimer = 30;
            }
            if (_dirWarnTimer > 0) { _dirWarnTimer--; }
        }

        if (gameState == GS_THROW) {
            _axeVy -= 0.6;
            _axeY += _axeVy;
            _axeSpin += 12.0;

            var targetY = _cy.toFloat();
            if (_axeY <= targetY + _logR.toFloat() + 4.0) {
                resolveHit();
            }
        }

        if (gameState == GS_FAIL) {
            _failAnim++;
            _failAxeVy += 0.2;
            _failAxeX += _failAxeVx;
            _failAxeY += _failAxeVy;
            _failAxeRot += ((Math.rand().abs() % 2 == 0) ? 1.0 : -1.0) * 2.0;
            if (_lives > 0 && _failAnim > 26) {
                _stuckCount = 0;
                spawnApple();
                resetAxe();
                gameState = GS_READY;
            } else if (_lives <= 0 && _failAnim > 50) {
                gameState = GS_OVER;
                if (_score > _bestScore) {
                    _bestScore = _score;
                    Application.Storage.setValue("arcBest", _bestScore);
                }
            }
        }

        if (_stickAnim > 0) { _stickAnim--; }

        WatchUi.requestUpdate();
    }

    hidden function resolveHit() {
        var hitAngle = normAngle(180.0 - _logAngle);

        for (var i = 0; i < _hazCount; i++) {
            var hd = angleDiff(hitAngle, _hazAngles[i]);
            if (hd < _hazSize / 2.0) {
                doFail(hitAngle, 0xFF2222);
                return;
            }
        }

        for (var i = 0; i < _stuckCount; i++) {
            var diff = angleDiff(hitAngle, _stuckAngles[i]);
            if (diff < _hitMinDeg) {
                doFail(hitAngle, 0xFF4444);
                return;
            }
        }

        var hitApple = false;
        if (_appleActive) {
            var ad = angleDiff(hitAngle, _appleAngle);
            if (ad < 10.0) {
                hitApple = true;
                _appleActive = false;
                _appleBurst = 20;
            }
        }

        if (_stuckCount < MAX_STUCK) {
            _stuckAngles[_stuckCount] = hitAngle;
            _stuckCount++;
        }

        _combo++;
        if (_combo >= 20) { _comboMult = 5; }
        else if (_combo >= 14) { _comboMult = 4; }
        else if (_combo >= 9) { _comboMult = 3; }
        else if (_combo >= 5) { _comboMult = 2; }
        else { _comboMult = 1; }

        var pts;
        if (hitApple) {
            pts = (_isBoss ? 100 : 50) * _comboMult;
            _comboMsg = "APPLE! +" + pts;
            _comboTimer = 35;
            _shakeTimer = 6;
            _flashTimer = 4;
            doVibe(80, 120);
            _crowdHype = 25;
            var rad = (_appleAngle + _logAngle) * 3.14159 / 180.0;
            var sx = _cx + (Math.sin(rad) * _logR.toFloat()).toNumber();
            var sy = _cy - (Math.cos(rad) * _logR.toFloat()).toNumber();
            spawnSparks(sx, sy, 0x44FF44);
            spawnSparks(sx, sy, 0xFF4444);
        } else {
            pts = 10 * _comboMult;
            doVibe(40, 60);
            _shakeTimer = 3;
        }
        _score += pts;

        var rad2 = (hitAngle + _logAngle) * 3.14159 / 180.0;
        var sx2 = _cx + (Math.sin(rad2) * _logR.toFloat()).toNumber();
        var sy2 = _cy - (Math.cos(rad2) * _logR.toFloat()).toNumber();
        spawnChips(sx2, sy2);
        spawnSparks(sx2, sy2, 0xFFCC44);

        _stickAnim = 8;
        _axesThisLevel++;

        if (_combo == 5 || _combo == 10 || _combo == 15 || _combo == 20 || _combo == 30) {
            if (!hitApple) {
                _comboMsg = "x" + _comboMult + " COMBO!";
                _comboTimer = 30;
            }
            _crowdHype = 20;
        }

        for (var i = 0; i < CROWD_N; i++) {
            if (Math.rand().abs() % 3 == 0) { _crowdJump[i] = 3 + Math.rand().abs() % 3; }
        }

        if (_axesThisLevel >= _axesPerLevel) {
            advanceLevel();
        }

        gameState = GS_READY;
        resetAxe();
    }

    hidden function doFail(hitAngle, sparkCol) {
        _lives--;
        gameState = GS_FAIL;
        _failAnim = 0;
        _combo = 0;
        _comboMult = 1;
        var rad = (hitAngle + _logAngle) * 3.14159 / 180.0;
        _failAxeX = _cx.toFloat() + Math.sin(rad) * (_logR.toFloat() + 12.0);
        _failAxeY = _cy.toFloat() - Math.cos(rad) * (_logR.toFloat() + 12.0);
        _failAxeVx = ((Math.rand().abs() % 2 == 0) ? 1.0 : -1.0) * (1.5 + (Math.rand().abs() % 15).toFloat() / 10.0);
        _failAxeVy = -3.0 - (Math.rand().abs() % 15).toFloat() / 10.0;
        _failAxeRot = ((Math.rand().abs() % 2 == 0) ? 1.0 : -1.0) * 8.0;
        spawnSparks(_failAxeX.toNumber(), _failAxeY.toNumber(), sparkCol);
        if (_lives <= 0) {
            _comboMsg = "CLANG!";
            doVibe(100, 300);
            _shakeTimer = 16;
        } else if (_lives == 1) {
            _comboMsg = "LAST LIFE!";
            doVibe(100, 200);
            _shakeTimer = 14;
        } else {
            _comboMsg = _lives + " LIVES LEFT";
            doVibe(80, 150);
            _shakeTimer = 10;
        }
        _comboTimer = 38;
    }

    hidden function setupLevel() {
        _stuckCount = 0;
        _isBoss = (_level % 5 == 0);

        if (_isBoss) {
            _logRadiusPct = 22;
            _axesPerLevel = 8 + _level / 5;
            if (_axesPerLevel > 14) { _axesPerLevel = 14; }
            _hitMinDeg = 4.0;

            var preStuck = 2 + _level / 10;
            if (preStuck > 5) { preStuck = 5; }
            for (var i = 0; i < preStuck && _stuckCount < MAX_STUCK; i++) {
                _stuckAngles[_stuckCount] = (i * (360 / preStuck) + Math.rand().abs() % 30).toFloat();
                _stuckCount++;
            }

            _hazCount = 1 + _level / 10;
            if (_hazCount > MAX_HAZ) { _hazCount = MAX_HAZ; }
        } else {
            _logRadiusPct = 18;
            if (_level % 4 == 2) { _logRadiusPct = 16; }
            else if (_level % 4 == 0) { _logRadiusPct = 17; }
            _axesPerLevel = 5 + ((_level - 1) % 3);
            _hitMinDeg = 5.0 - (_level - 1).toFloat() * 0.05;
            if (_hitMinDeg < 3.0) { _hitMinDeg = 3.0; }

            _hazCount = (_level - 1) / 4;
            if (_hazCount > 3) { _hazCount = 3; }
        }

        for (var i = 0; i < _hazCount; i++) {
            _hazAngles[i] = (i * (360 / (_hazCount + 1)) + 30 + Math.rand().abs() % 60).toFloat();
            _hazAngles[i] = normAngle(_hazAngles[i]);
        }

        _axesThisLevel = 0;
        spawnApple();
    }

    hidden function spawnApple() {
        if (_level < 2) { _appleActive = false; return; }
        _appleActive = true;
        _appleAngle = (Math.rand().abs() % 360).toFloat();
        for (var attempt = 0; attempt < 20; attempt++) {
            var ok = true;
            for (var i = 0; i < _hazCount; i++) {
                if (angleDiff(_appleAngle, _hazAngles[i]) < _hazSize + 5.0) { ok = false; break; }
            }
            for (var i = 0; i < _stuckCount; i++) {
                if (angleDiff(_appleAngle, _stuckAngles[i]) < _hitMinDeg + 5.0) { ok = false; break; }
            }
            if (ok) { return; }
            _appleAngle = (Math.rand().abs() % 360).toFloat();
        }
    }

    hidden function advanceLevel() {
        _level++;
        var spdInc = 0.14 / (1.0 + (_level - 1).toFloat() * 0.06);
        _logSpeed += spdInc;
        if (_logSpeed > 3.6) { _logSpeed = 3.6; }
        if (Math.rand().abs() % 3 == 0) { _logDir = -_logDir; }

        setupLevel();

        if (_isBoss) {
            _comboMsg = "BOSS!";
            _flashTimer = 8;
            doVibe(100, 200);
            _crowdHype = 30;
        } else {
            _comboMsg = "LEVEL " + _level;
            doVibe(60, 100);
        }
        _comboTimer = 40;
    }

    hidden function resetAxe() {
        _axeY = _h.toFloat() - 25.0;
        _axeVy = 0.0;
        _axeSpin = 0.0;
    }

    hidden function normAngle(a) {
        while (a < 0.0) { a += 360.0; }
        while (a >= 360.0) { a -= 360.0; }
        return a;
    }

    hidden function angleDiff(a, b) {
        var d = a - b;
        if (d < 0.0) { d = -d; }
        if (d > 180.0) { d = 360.0 - d; }
        return d;
    }

    hidden function getTheme() {
        var t = (_level - 1) / 5;
        if (t > 4) { t = 4; }
        return t;
    }

    hidden function spawnSparks(ex, ey, baseColor) {
        var spawned = 0;
        for (var i = 0; i < MAX_SPARKS; i++) {
            if (spawned >= 10) { break; }
            if (_spkLife[i] > 0) { continue; }
            _spkX[i] = ex.toFloat();
            _spkY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.2 + (Math.rand().abs() % 30).toFloat() / 10.0;
            _spkVx[i] = spd * Math.cos(a);
            _spkVy[i] = spd * Math.sin(a) - 1.5;
            _spkLife[i] = 10 + Math.rand().abs() % 12;
            _spkColor[i] = baseColor;
            spawned++;
        }
    }

    hidden function spawnChips(ex, ey) {
        var spawned = 0;
        for (var i = 0; i < CHIP_N; i++) {
            if (spawned >= 6) { break; }
            if (_chipLife[i] > 0) { continue; }
            _chipX[i] = ex.toFloat();
            _chipY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 0.8 + (Math.rand().abs() % 22).toFloat() / 10.0;
            _chipVx[i] = spd * Math.cos(a);
            _chipVy[i] = spd * Math.sin(a) - 1.0;
            _chipLife[i] = 10 + Math.rand().abs() % 8;
            spawned++;
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            var vp = new Toybox.Attention.VibeProfile(intensity, duration);
            Toybox.Attention.vibrate([vp]);
        }
    }

    function doAction() {
        if (gameState == GS_MENU) {
            startGame();
            return;
        }
        if (gameState == GS_READY) {
            _axeVy = -8.0;
            gameState = GS_THROW;
            return;
        }
        if (gameState == GS_OVER) {
            startGame();
            return;
        }
    }

    hidden function startGame() {
        _score = 0; _level = 1;
        _lives = 3;
        _combo = 0; _comboMult = 1;
        _logAngle = 0.0;
        _logSpeed = 1.2;
        _logDir = 1;
        _dirChangeTimer = 0;
        _dirWarnTimer = 0;
        _failAnim = 0; _stickAnim = 0;
        _comboMsg = ""; _comboTimer = 0;
        setupLevel();
        resetAxe();
        gameState = GS_READY;
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h * 38 / 100;
        _logR = _w * _logRadiusPct / 100;

        if (gameState == GS_MENU) { drawMenu(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeOx;
        var oy = _shakeOy;

        drawBg(dc, ox, oy);
        drawLog(dc, ox, oy);
        drawHazards(dc, ox, oy);
        drawStuckAxes(dc, ox, oy);
        if (_appleActive) { drawApple(dc, ox, oy); }
        if (_appleBurst > 0) { drawAppleBurst(dc, ox, oy); }

        if (gameState == GS_READY || gameState == GS_THROW) {
            drawFlyingAxe(dc, ox, oy);
        }
        if (gameState == GS_FAIL || gameState == GS_OVER) {
            drawBouncingAxe(dc, ox, oy);
        }
        drawParticles(dc, ox, oy);
        drawCrowd(dc);

        if (_dirWarnTimer > 0) {
            var wc = (_dirWarnTimer % 4 < 2) ? 0xFFFF44 : 0xFF8800;
            dc.setColor(wc, Graphics.COLOR_TRANSPARENT);
            var arrow = (_logDir > 0) ? "<<<" : ">>>";
            dc.drawText(_cx, _cy - _logR - 22, Graphics.FONT_XTINY, arrow, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_flashTimer > 0) {
            var fa = _flashTimer * 30;
            if (fa > 200) { fa = 200; }
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            if (_flashTimer > 5) {
                dc.fillRectangle(0, 0, _w, _h);
            }
        }
        if (_stickAnim > 6) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, _w, _h);
        }

        drawHUD(dc);

        if (_comboTimer > 0) {
            drawCombo(dc);
        }

        if (gameState == GS_OVER) {
            drawGameOver(dc);
        }
    }

    hidden function drawBg(dc, ox, oy) {
        var theme = getTheme();
        var bgCol;
        var bg2;
        if (theme == 0) { bgCol = 0x1A1A2E; bg2 = 0x16213E; }
        else if (theme == 1) { bgCol = 0x0E1520; bg2 = 0x0A1828; }
        else if (theme == 2) { bgCol = 0x1A1A22; bg2 = 0x222230; }
        else if (theme == 3) { bgCol = 0x0A1A2A; bg2 = 0x102838; }
        else { bgCol = 0x1A1408; bg2 = 0x221A0C; }

        dc.setColor(bgCol, bgCol);
        dc.clear();
        dc.setColor(bg2, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h * 35 / 100);

        for (var i = 0; i < 16; i++) {
            var st = _bgStars[i];
            var blink = ((_tick + i * 7) % 22 < 2) ? 0x444466 : 0x7777AA;
            if (theme == 4) { blink = ((_tick + i * 7) % 22 < 2) ? 0x665522 : 0xAA9955; }
            dc.setColor(blink, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(st[0] + ox, st[1] + oy, st[2], st[2]);
        }

        var groundC = (theme == 2) ? 0x2A2A30 : ((theme == 3) ? 0x1A2A3A : ((theme == 4) ? 0x3A2A0A : 0x2A1A0A));
        dc.setColor(groundC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0 + ox, _h - 22 + oy, _w, 22);
        var groundLine = (theme == 4) ? 0x5A4A2A : 0x3A2A1A;
        dc.setColor(groundLine, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0 + ox, _h - 22 + oy, _w, 2);

        var torchY = _h - 22 + oy;
        drawTorch(dc, 8 + ox, torchY);
        drawTorch(dc, _w - 14 + ox, torchY);
    }

    hidden function drawTorch(dc, tx, ty) {
        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx, ty - 18, 4, 18);
        dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx + 1, ty - 18, 2, 18);
        var fFlicker = (_tick % 4 < 2) ? 2 : 0;
        dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx + 2, ty - 22 - fFlicker, 4);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx + 2, ty - 24 - fFlicker, 3);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tx + 2, ty - 25 - fFlicker, 2);
        dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx - 2, ty - 18, 8, 2);
    }

    hidden function drawLog(dc, ox, oy) {
        var lcx = _cx + ox;
        var lcy = _cy + oy;
        var r = _logR;
        var theme = getTheme();

        dc.setColor(0x1A1008, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx + 2, lcy + 2, r + 2);

        var c1; var c2; var c3; var c4; var c5;
        if (theme == 0) { c1 = 0x6B4226; c2 = 0x8B5A2B; c3 = 0xA0723C; c4 = 0x8B5A2B; c5 = 0x6B4226; }
        else if (theme == 1) { c1 = 0x4A3020; c2 = 0x6A4830; c3 = 0x7A5838; c4 = 0x6A4830; c5 = 0x4A3020; }
        else if (theme == 2) { c1 = 0x555560; c2 = 0x707080; c3 = 0x8A8A98; c4 = 0x707080; c5 = 0x555560; }
        else if (theme == 3) { c1 = 0x4488AA; c2 = 0x66AACC; c3 = 0x88CCEE; c4 = 0x66AACC; c5 = 0x4488AA; }
        else { c1 = 0x8A7722; c2 = 0xAA9933; c3 = 0xCCBB44; c4 = 0xAA9933; c5 = 0x8A7722; }

        dc.setColor(c1, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r);
        dc.setColor(c2, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r - 3);
        dc.setColor(c3, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r - 7);
        dc.setColor(c4, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r - 11);
        dc.setColor(c5, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r - 15);
        dc.setColor(c2, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r - 18);
        dc.setColor(c3, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, 4);
        dc.setColor(c1, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, 2);

        var grainOff = _logAngle * 3.14159 / 180.0;
        for (var g = 0; g < 4; g++) {
            var ga = grainOff + g.toFloat() * 1.571;
            var gx = lcx + (Math.cos(ga) * (r - 5).toFloat()).toNumber();
            var gy = lcy + (Math.sin(ga) * (r - 5).toFloat()).toNumber();
            var gx2 = lcx + (Math.cos(ga) * (r - 10).toFloat()).toNumber();
            var gy2 = lcy + (Math.sin(ga) * (r - 10).toFloat()).toNumber();
            dc.setColor(c5, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(gx, gy, gx2, gy2);
        }

        var edgeCol = (theme == 2) ? 0x3A3A44 : ((theme == 3) ? 0x336688 : ((theme == 4) ? 0x6A5A11 : 0x4A2A11));
        dc.setColor(edgeCol, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(lcx, lcy, r);
        dc.drawCircle(lcx, lcy, r - 1);

        if (_isBoss) {
            var pulseR = r + 3 + (_tick % 6 < 3 ? 1 : 0);
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(lcx, lcy, pulseR);
        }
    }

    hidden function drawHazards(dc, ox, oy) {
        var lcx = _cx + ox;
        var lcy = _cy + oy;
        var r = _logR;

        for (var i = 0; i < _hazCount; i++) {
            var absAngle = _hazAngles[i] + _logAngle;
            var halfSz = _hazSize / 2.0;
            for (var s = -2; s <= 2; s++) {
                var a = absAngle + s.toFloat() * (halfSz / 2.0);
                var rad = a * 3.14159 / 180.0;
                var ix = lcx + (Math.sin(rad) * (r.toFloat() - 4.0)).toNumber();
                var iy = lcy - (Math.cos(rad) * (r.toFloat() - 4.0)).toNumber();
                var oox = lcx + (Math.sin(rad) * (r.toFloat() + 3.0)).toNumber();
                var ooy = lcy - (Math.cos(rad) * (r.toFloat() + 3.0)).toNumber();
                dc.setColor((_tick % 6 < 3) ? 0xCC2222 : 0xAA1111, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(ix, iy, oox, ooy);
                dc.drawLine(ix + 1, iy, oox + 1, ooy);
            }

            var midRad = absAngle * 3.14159 / 180.0;
            var mx = lcx + (Math.sin(midRad) * (r.toFloat() + 1.0)).toNumber();
            var my = lcy - (Math.cos(midRad) * (r.toFloat() + 1.0)).toNumber();
            dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx, my, 3);
            dc.setColor(0xFFAAAA, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx, my, 1);
        }
    }

    hidden function drawApple(dc, ox, oy) {
        var lcx = _cx + ox;
        var lcy = _cy + oy;
        var r = _logR;
        var absAngle = _appleAngle + _logAngle;
        var rad = absAngle * 3.14159 / 180.0;
        var ax = lcx + (Math.sin(rad) * (r.toFloat() + 2.0)).toNumber();
        var ay = lcy - (Math.cos(rad) * (r.toFloat() + 2.0)).toNumber();

        var bob = (_tick % 10 < 5) ? 1 : 0;
        dc.setColor(0x44CC44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ax, ay - bob, 5);
        dc.setColor(0x66EE66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ax - 1, ay - 1 - bob, 3);
        dc.setColor(0xDD3333, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ax + 1, ay - 3 - bob, 2);
        dc.setColor(0x337733, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ax, ay - 6 - bob, 1, 3);
    }

    hidden function drawAppleBurst(dc, ox, oy) {
        var burstR = (20 - _appleBurst) * 2;
        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx + ox, _cy + oy, _logR + burstR);
    }

    hidden function drawStuckAxes(dc, ox, oy) {
        var lcx = _cx + ox;
        var lcy = _cy + oy;
        var r = _logR;

        for (var i = 0; i < _stuckCount; i++) {
            var absAngle = _stuckAngles[i] + _logAngle;
            var rad = absAngle * 3.14159 / 180.0;

            var edgeX = lcx + (Math.sin(rad) * r.toFloat()).toNumber();
            var edgeY = lcy - (Math.cos(rad) * r.toFloat()).toNumber();
            var tipX = lcx + (Math.sin(rad) * (r.toFloat() + 14.0)).toNumber();
            var tipY = lcy - (Math.cos(rad) * (r.toFloat() + 14.0)).toNumber();
            var handleX = lcx + (Math.sin(rad) * (r.toFloat() + 26.0)).toNumber();
            var handleY = lcy - (Math.cos(rad) * (r.toFloat() + 26.0)).toNumber();

            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(edgeX, edgeY, tipX, tipY);
            dc.drawLine(edgeX + 1, edgeY, tipX + 1, tipY);

            dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tipX, tipY, handleX, handleY);
            dc.drawLine(tipX + 1, tipY, handleX + 1, handleY);

            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(handleX, handleY, 2);

            var perpX = (Math.cos(rad) * 3.0).toNumber();
            var perpY = (Math.sin(rad) * 3.0).toNumber();
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tipX - perpX, tipY + perpY, tipX + perpX, tipY - perpY);
        }
    }

    hidden function drawFlyingAxe(dc, ox, oy) {
        var ax = _cx + ox;
        var ay = _axeY.toNumber() + oy;

        if (gameState == GS_THROW) {
            var spin = _axeSpin;
            var bladeOff = (Math.sin(spin * 3.14159 / 180.0) * 6.0).toNumber();
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 2, ay - 7 + bladeOff, 5, 9);
            dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 1, ay - 7 + bladeOff, 3, 9);
            dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 1, ay + 2, 3, 11);
            dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax, ay + 2, 1, 11);
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax, ay + 13, 2);
        } else {
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 4, ay - 7, 9, 5);
            dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 3, ay - 6, 7, 3);
            dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 1, ay - 2, 3, 13);
            dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax, ay - 2, 1, 13);
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax, ay + 11, 2);

            if (_tick % 6 < 3) {
                dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
                dc.drawText(ax, ay - 18, Graphics.FONT_XTINY, "^", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden function drawBouncingAxe(dc, ox, oy) {
        var ax = _failAxeX.toNumber() + ox;
        var ay = _failAxeY.toNumber() + oy;
        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ax - 2, ay - 4, 5, 4);
        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ax - 1, ay, 3, 10);
        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ax, ay + 10, 2);
    }

    hidden function drawParticles(dc, ox, oy) {
        for (var i = 0; i < MAX_SPARKS; i++) {
            if (_spkLife[i] <= 0) { continue; }
            dc.setColor(_spkColor[i], Graphics.COLOR_TRANSPARENT);
            var sz = (_spkLife[i] > 5) ? 2 : 1;
            dc.fillRectangle(_spkX[i].toNumber() + ox, _spkY[i].toNumber() + oy, sz, sz);
        }
        for (var i = 0; i < CHIP_N; i++) {
            if (_chipLife[i] <= 0) { continue; }
            var cc = (_chipLife[i] > 6) ? 0x8B5A2B : 0x6B4226;
            dc.setColor(cc, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_chipX[i].toNumber() + ox, _chipY[i].toNumber() + oy, 2, 2);
        }
    }

    hidden function drawCrowd(dc) {
        var baseY = _h - 10;
        for (var i = 0; i < CROWD_N; i++) {
            var cx = _crowdX[i];
            var jump = _crowdJump[i];
            var cy = baseY - jump;

            dc.setColor(_crowdCol[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy - 5, 3);
            dc.fillRectangle(cx - 2, cy - 2, 5, 6);

            if (_crowdHype > 10 && jump > 2) {
                dc.fillRectangle(cx - 5, cy - 5, 2, 3);
                dc.fillRectangle(cx + 4, cy - 5, 2, 3);
            }
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 3, Graphics.FONT_SMALL, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(8, 3, Graphics.FONT_XTINY, "Lv" + _level, Graphics.TEXT_JUSTIFY_LEFT);

        if (_isBoss) {
            dc.setColor((_tick % 8 < 4) ? 0xFF4444 : 0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, 16, Graphics.FONT_XTINY, "BOSS", Graphics.TEXT_JUSTIFY_LEFT);
        }

        if (_comboMult > 1) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w - 8, 3, Graphics.FONT_XTINY, "x" + _comboMult, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        if (_combo > 0) {
            var barW = _w * 28 / 100;
            var barX = _w - barW - 8;
            var barY = 18;
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, barW, 3);
            var nextThresh = 5;
            if (_combo >= 5) { nextThresh = 9; }
            if (_combo >= 9) { nextThresh = 14; }
            if (_combo >= 14) { nextThresh = 20; }
            if (_combo >= 20) { nextThresh = 20; }
            var fill = (_combo * barW / nextThresh);
            if (fill > barW) { fill = barW; }
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, fill, 3);
        }

        var remain = _axesPerLevel - _axesThisLevel;
        if (remain > 0 && gameState != GS_OVER && gameState != GS_FAIL) {
            var dotY = _h - 36;
            var maxShow = remain;
            if (maxShow > 10) { maxShow = 10; }
            for (var d = 0; d < maxShow; d++) {
                dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_cx - (maxShow * 4) + d * 8 + 4, dotY, 2);
                dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_cx - (maxShow * 4) + d * 8 + 4, dotY, 1);
            }
        }

        var speedPct = ((_logSpeed - 1.2) / 2.4 * 100.0).toNumber();
        if (speedPct > 100) { speedPct = 100; }
        if (speedPct < 0) { speedPct = 0; }
        if (speedPct > 0) {
            var barW = _w * 26 / 100;
            var barX = _w - barW - 8;
            var barYs = 24;
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barYs, barW, 2);
            var fill = speedPct * barW / 100;
            var bc = (speedPct > 70) ? 0xFF4444 : ((speedPct > 40) ? 0xFFAA44 : 0x44AA44);
            dc.setColor(bc, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barYs, fill, 2);
        }

        if (_logDir < 0 && (gameState == GS_READY || gameState == GS_THROW)) {
            dc.setColor(0x556688, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy + _logR + 6, Graphics.FONT_XTINY, "<", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_logDir > 0 && (gameState == GS_READY || gameState == GS_THROW)) {
            dc.setColor(0x556688, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy + _logR + 6, Graphics.FONT_XTINY, ">", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_hazCount > 0 && gameState == GS_READY) {
            dc.setColor(0x883333, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < _hazCount && i < 4; i++) {
                dc.fillCircle(_cx - (_hazCount * 5) + i * 10 + 5, _h - 30, 2);
            }
        }

        for (var l = 0; l < 3; l++) {
            var lox = 6 + l * 13;
            var loy = _h - 52;
            if (l < _lives) {
                dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(lox - 3, loy, 7, 3);
                dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(lox, loy + 3, 2, 5);
                dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(lox - 1, loy + 7, 4, 1);
            } else {
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(lox - 3, loy, 7, 3);
                dc.fillRectangle(lox, loy + 3, 2, 5);
            }
        }
    }

    hidden function drawCombo(dc) {
        var cy = _cy + _logR + 24 - ((40 - _comboTimer) / 3);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, cy + 1, Graphics.FONT_SMALL, _comboMsg, Graphics.TEXT_JUSTIFY_CENTER);
        var mc = 0xFFCC44;
        if (_comboMsg.find("APPLE") != null) { mc = 0x44FF44; }
        else if (_comboMsg.find("LEVEL") != null) { mc = 0x44FFAA; }
        else if (_comboMsg.find("BOSS") != null) { mc = 0xFF4444; }
        else if (_comboMsg.find("CLANG") != null) { mc = 0xFF2222; }
        else if (_comboMsg.find("LAST") != null) { mc = 0xFF4444; }
        else if (_comboMsg.find("LIFE") != null) { mc = 0xFF8844; }
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, cy, Graphics.FONT_SMALL, _comboMsg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx - _w * 38 / 100, _cy + _logR + 12, _w * 76 / 100, _h * 42 / 100);
        dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_cx - _w * 38 / 100, _cy + _logR + 12, _w * 76 / 100, _h * 42 / 100);

        var ty = _cy + _logR + 16;
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, ty, Graphics.FONT_SMALL, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        ty += 20;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, ty, Graphics.FONT_XTINY, "Score: " + _score + "  Lv" + _level, Graphics.TEXT_JUSTIFY_CENTER);
        ty += 14;
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, ty, Graphics.FONT_XTINY, "Best: " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        ty += 14;
        if (_combo > 4) {
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, ty, Graphics.FONT_XTINY, "Best combo: " + _combo, Graphics.TEXT_JUSTIFY_CENTER);
            ty += 14;
        }
        if (_tick % 10 < 5) {
            dc.setColor(0xDD8833, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, ty, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x0E0E1A, 0x0E0E1A);
        dc.clear();
        dc.setColor(0x14182A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h / 2);

        for (var i = 0; i < 16; i++) {
            var st = _bgStars[i];
            var blink = ((_tick + i * 7) % 20 < 3) ? 0x444466 : 0x7777AA;
            dc.setColor(blink, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(st[0], st[1], st[2], st[2]);
        }

        var lcx = _cx;
        var lcy = _h * 38 / 100;
        var lr = _w * 16 / 100;
        var menuAngle = _tick.toFloat() * 1.2;
        dc.setColor(0x6B4226, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, lr);
        dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, lr - 3);
        dc.setColor(0xA0723C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, lr - 6);
        dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, lr - 9);
        dc.setColor(0xA0723C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, 3);

        for (var a = 0; a < 4; a++) {
            var demoAngle = menuAngle + a.toFloat() * 90.0;
            var rad = demoAngle * 3.14159 / 180.0;
            var ex = lcx + (Math.sin(rad) * lr.toFloat()).toNumber();
            var ey = lcy - (Math.cos(rad) * lr.toFloat()).toNumber();
            var hx = lcx + (Math.sin(rad) * (lr.toFloat() + 14.0)).toNumber();
            var hy = lcy - (Math.cos(rad) * (lr.toFloat() + 14.0)).toNumber();
            dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(ex, ey, hx, hy);
            dc.drawLine(ex + 1, ey, hx + 1, hy);
            dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
            var eex = lcx + (Math.sin(rad) * (lr.toFloat() + 22.0)).toNumber();
            var eey = lcy - (Math.cos(rad) * (lr.toFloat() + 22.0)).toNumber();
            dc.drawLine(hx, hy, eex, eey);
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(eex, eey, 2);
        }

        var hazAngle = menuAngle * 0.7 + 45.0;
        var hazRad = hazAngle * 3.14159 / 180.0;
        var hzx = lcx + (Math.sin(hazRad) * (lr.toFloat() - 2.0)).toNumber();
        var hzy = lcy - (Math.cos(hazRad) * (lr.toFloat() - 2.0)).toNumber();
        var hzox = lcx + (Math.sin(hazRad) * (lr.toFloat() + 4.0)).toNumber();
        var hzoy = lcy - (Math.cos(hazRad) * (lr.toFloat() + 4.0)).toNumber();
        dc.setColor((_tick % 6 < 3) ? 0xCC2222 : 0xAA1111, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(hzx, hzy, hzox, hzoy);
        dc.drawLine(hzx + 1, hzy, hzox + 1, hzoy);
        dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hzox, hzoy, 2);

        var appAngle = menuAngle * 0.5 + 180.0;
        var appRad = appAngle * 3.14159 / 180.0;
        var apx = lcx + (Math.sin(appRad) * (lr.toFloat() + 3.0)).toNumber();
        var apy = lcy - (Math.cos(appRad) * (lr.toFloat() + 3.0)).toNumber();
        dc.setColor(0x44CC44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(apx, apy, 4);
        dc.setColor(0xDD3333, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(apx + 1, apy - 2, 2);

        dc.setColor(0x4A2A11, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(lcx, lcy, lr);

        var titleC = (_tick % 14 < 7) ? 0xFF8844 : 0xFFAA66;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, _h * 4 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(titleC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 4 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 15 / 100, Graphics.FONT_SMALL, "AXE ARCADE", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x2A1A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - 20, _w, 20);
        dc.setColor(0x3A2A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - 20, _w, 2);
        drawTorch(dc, 8, _h - 20);
        drawTorch(dc, _w - 14, _h - 20);

        dc.setColor(0x6688AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 62 / 100, Graphics.FONT_XTINY, "Stick axes. Dodge hazards.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, _h * 68 / 100, Graphics.FONT_XTINY, "Hit apples for bonus!", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestScore > 0) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 76 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0xFF8844 : 0xFFAA66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 84 / 100, Graphics.FONT_XTINY, "Tap to play", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
