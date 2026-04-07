using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum {
    GS_MENU,
    GS_READY,
    GS_THROW,
    GS_STICK,
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

    hidden const MAX_STUCK = 40;
    hidden var _stuckAngles;
    hidden var _stuckCount;

    hidden var _axeY;
    hidden var _axeVy;
    hidden var _axeFlying;
    hidden var _axeAngle;
    hidden var _axeSpin;

    hidden var _score;
    hidden var _bestScore;
    hidden var _level;
    hidden var _axesThisLevel;
    hidden var _axesPerLevel;

    hidden var _stickAnim;
    hidden var _failAnim;
    hidden var _failAngle;

    hidden var _failAxeX;
    hidden var _failAxeY;
    hidden var _failAxeVx;
    hidden var _failAxeVy;
    hidden var _failAxeRot;

    hidden var _shakeTimer;
    hidden var _shakeOx;
    hidden var _shakeOy;

    hidden const MAX_SPARKS = 20;
    hidden var _spkX;
    hidden var _spkY;
    hidden var _spkVx;
    hidden var _spkVy;
    hidden var _spkLife;
    hidden var _spkColor;

    hidden var _chipX;
    hidden var _chipY;
    hidden var _chipVx;
    hidden var _chipVy;
    hidden var _chipLife;

    hidden const CHIP_N = 12;

    hidden var _comboMsg;
    hidden var _comboTimer;

    hidden var _bgStars;

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

        _logR = _w * 18 / 100;
        _logAngle = 0.0;
        _logSpeed = 1.2;
        _logDir = 1;

        _stuckAngles = new [MAX_STUCK];
        for (var i = 0; i < MAX_STUCK; i++) { _stuckAngles[i] = 0.0; }
        _stuckCount = 0;

        _axeY = 0.0;
        _axeVy = 0.0;
        _axeFlying = false;
        _axeAngle = 0.0;
        _axeSpin = 0.0;

        _score = 0; _bestScore = 0; _level = 1;
        _axesThisLevel = 0; _axesPerLevel = 5;

        _stickAnim = 0; _failAnim = 0; _failAngle = 0.0;
        _failAxeX = 0.0; _failAxeY = 0.0;
        _failAxeVx = 0.0; _failAxeVy = 0.0; _failAxeRot = 0.0;

        _shakeTimer = 0; _shakeOx = 0; _shakeOy = 0;

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

        _bgStars = new [20];
        for (var i = 0; i < 20; i++) {
            _bgStars[i] = [Math.rand().abs() % _w, Math.rand().abs() % _h, 1 + Math.rand().abs() % 3];
        }
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
        if (_comboTimer > 0) { _comboTimer--; }

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

        if (gameState == GS_READY || gameState == GS_THROW || gameState == GS_STICK) {
            _logAngle += _logSpeed * _logDir.toFloat();
            if (_logAngle >= 360.0) { _logAngle -= 360.0; }
            if (_logAngle < 0.0) { _logAngle += 360.0; }
        }

        if (gameState == GS_THROW) {
            _axeVy -= 0.6;
            _axeY += _axeVy;
            _axeSpin += 12.0;

            var targetY = _cy.toFloat();
            if (_axeY <= targetY + _logR.toFloat() + 4.0) {
                var hitAngle = normAngle(180.0 - _logAngle);
                var collision = false;
                for (var i = 0; i < _stuckCount; i++) {
                    var diff = angleDiff(hitAngle, _stuckAngles[i]);
                    if (diff < 14.0) {
                        collision = true;
                        _failAngle = _stuckAngles[i];
                        break;
                    }
                }

                if (collision) {
                    gameState = GS_FAIL;
                    _failAnim = 0;
                    var rad = (180.0 - _logAngle) * 3.14159 / 180.0;
                    _failAxeX = _cx.toFloat() + Math.sin(rad) * (_logR.toFloat() + 12.0);
                    _failAxeY = _cy.toFloat() - Math.cos(rad) * (_logR.toFloat() + 12.0);
                    _failAxeVx = ((Math.rand().abs() % 2 == 0) ? 1.0 : -1.0) * (1.5 + (Math.rand().abs() % 15).toFloat() / 10.0);
                    _failAxeVy = -3.0 - (Math.rand().abs() % 15).toFloat() / 10.0;
                    _failAxeRot = ((Math.rand().abs() % 2 == 0) ? 1.0 : -1.0) * 8.0;
                    spawnSparks(_failAxeX.toNumber(), _failAxeY.toNumber(), 0xFF4444);
                    doVibe(100, 200);
                    _shakeTimer = 12;
                } else {
                    if (_stuckCount < MAX_STUCK) {
                        _stuckAngles[_stuckCount] = hitAngle;
                        _stuckCount++;
                    }
                    _score++;
                    _axesThisLevel++;
                    _stickAnim = 10;

                    var rad = hitAngle * 3.14159 / 180.0;
                    var sx = _cx + (Math.sin(rad) * _logR.toFloat()).toNumber();
                    var sy = _cy - (Math.cos(rad) * _logR.toFloat()).toNumber();
                    spawnChips(sx, sy);
                    spawnSparks(sx, sy, 0xFFCC44);
                    doVibe(40, 60);
                    _shakeTimer = 3;

                    if (_axesThisLevel >= _axesPerLevel) {
                        advanceLevel();
                    }

                    gameState = GS_READY;
                    resetAxe();

                    if (_score % 5 == 0) {
                        _comboMsg = "x" + _score;
                        _comboTimer = 30;
                    }
                }
            }
        }

        if (gameState == GS_FAIL) {
            _failAnim++;
            _failAxeVy += 0.2;
            _failAxeX += _failAxeVx;
            _failAxeY += _failAxeVy;
            _failAxeRot += ((Math.rand().abs() % 2 == 0) ? 1.0 : -1.0) * 2.0;
            if (_failAnim > 50) {
                gameState = GS_OVER;
                if (_score > _bestScore) { _bestScore = _score; }
            }
        }

        if (_stickAnim > 0) { _stickAnim--; }

        WatchUi.requestUpdate();
    }

    hidden function advanceLevel() {
        _level++;
        _axesThisLevel = 0;
        _stuckCount = 0;
        _logSpeed += 0.3;
        if (_logSpeed > 5.0) { _logSpeed = 5.0; }
        if (Math.rand().abs() % 3 == 0) { _logDir = -_logDir; }
        _comboMsg = "LEVEL " + _level;
        _comboTimer = 40;
        doVibe(60, 100);
    }

    hidden function resetAxe() {
        _axeY = _h.toFloat() - 25.0;
        _axeVy = 0.0;
        _axeFlying = false;
        _axeAngle = 0.0;
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

    hidden function spawnSparks(ex, ey, baseColor) {
        var spawned = 0;
        for (var i = 0; i < MAX_SPARKS; i++) {
            if (spawned >= 8) { break; }
            if (_spkLife[i] > 0) { continue; }
            _spkX[i] = ex.toFloat();
            _spkY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.0 + (Math.rand().abs() % 25).toFloat() / 10.0;
            _spkVx[i] = spd * Math.cos(a);
            _spkVy[i] = spd * Math.sin(a) - 1.5;
            _spkLife[i] = 8 + Math.rand().abs() % 10;
            _spkColor[i] = baseColor;
            spawned++;
        }
    }

    hidden function spawnChips(ex, ey) {
        var spawned = 0;
        for (var i = 0; i < CHIP_N; i++) {
            if (spawned >= 5) { break; }
            if (_chipLife[i] > 0) { continue; }
            _chipX[i] = ex.toFloat();
            _chipY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 0.8 + (Math.rand().abs() % 20).toFloat() / 10.0;
            _chipVx[i] = spd * Math.cos(a);
            _chipVy[i] = spd * Math.sin(a) - 1.0;
            _chipLife[i] = 10 + Math.rand().abs() % 8;
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
            startGame();
            return;
        }
        if (gameState == GS_READY) {
            _axeFlying = true;
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
        _axesThisLevel = 0;
        _stuckCount = 0;
        _logAngle = 0.0;
        _logSpeed = 1.2;
        _logDir = 1;
        _failAnim = 0; _stickAnim = 0;
        _comboMsg = ""; _comboTimer = 0;
        resetAxe();
        gameState = GS_READY;
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h * 40 / 100;
        _logR = _w * 18 / 100;

        if (gameState == GS_MENU) { drawMenu(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeOx;
        var oy = _shakeOy;

        drawBg(dc, ox, oy);
        drawLog(dc, ox, oy);
        drawStuckAxes(dc, ox, oy);

        if (gameState == GS_READY || gameState == GS_THROW) {
            drawFlyingAxe(dc, ox, oy);
        }
        if (gameState == GS_FAIL || gameState == GS_OVER) {
            drawBouncingAxe(dc, ox, oy);
        }
        drawParticles(dc, ox, oy);
        drawHUD(dc);

        if (_comboTimer > 0) {
            drawCombo(dc);
        }
        if (_stickAnim > 0) {
            drawStickFlash(dc);
        }

        if (gameState == GS_OVER) {
            drawGameOver(dc);
        }
    }

    hidden function drawBg(dc, ox, oy) {
        dc.setColor(0x1A1A2E, 0x1A1A2E);
        dc.clear();
        dc.setColor(0x16213E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h / 3);
        dc.setColor(0x0F3460, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h / 3, _w, _h / 3);

        for (var i = 0; i < 20; i++) {
            var st = _bgStars[i];
            var blink = ((_tick + i * 7) % 20 < 2) ? 0x555577 : 0x8888AA;
            dc.setColor(blink, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(st[0] + ox, st[1] + oy, st[2], st[2]);
        }

        dc.setColor(0x2A1A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0 + ox, _h - 18 + oy, _w, 18);
        dc.setColor(0x3A2A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0 + ox, _h - 18 + oy, _w, 3);
        dc.setColor(0x4A3A2A, Graphics.COLOR_TRANSPARENT);
        for (var x = 0; x < _w; x += 8) {
            dc.fillRectangle(x + ox, _h - 15 + oy, 1, 12);
        }

        var torchY = _h - 18 + oy;
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

        dc.setColor(0x3A2211, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx + 1, lcy + 1, r + 2);

        dc.setColor(0x6B4226, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r);

        dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r - 3);

        dc.setColor(0xA0723C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r - 7);

        dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r - 11);

        dc.setColor(0x6B4226, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r - 15);

        dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, r - 18);

        dc.setColor(0xA0723C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, 4);

        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, 2);

        var grainOff = _logAngle * 3.14159 / 180.0;
        for (var g = 0; g < 6; g++) {
            var ga = grainOff + g.toFloat() * 1.047;
            var gx = lcx + (Math.cos(ga) * (r - 5).toFloat()).toNumber();
            var gy = lcy + (Math.sin(ga) * (r - 5).toFloat()).toNumber();
            var gx2 = lcx + (Math.cos(ga) * (r - 10).toFloat()).toNumber();
            var gy2 = lcy + (Math.sin(ga) * (r - 10).toFloat()).toNumber();
            dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(gx, gy, gx2, gy2);
        }

        dc.setColor(0x4A2A11, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(lcx, lcy, r);
        dc.drawCircle(lcx, lcy, r - 1);
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

            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(edgeX, edgeY, tipX, tipY);
            dc.drawLine(edgeX + 1, edgeY, tipX + 1, tipY);
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(edgeX, edgeY, tipX, tipY);

            dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tipX, tipY, handleX, handleY);
            dc.drawLine(tipX + 1, tipY, handleX + 1, handleY);

            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(handleX, handleY, 2);

            var perpX = (Math.cos(rad) * 3.0).toNumber();
            var perpY = (Math.sin(rad) * 3.0).toNumber();
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tipX - perpX, tipY + perpY, tipX + perpX, tipY - perpY);
        }
    }

    hidden function drawFlyingAxe(dc, ox, oy) {
        var ax = _cx + ox;
        var ay = _axeY.toNumber() + oy;

        if (gameState == GS_THROW) {
            var spin = _axeSpin;
            var bladeOff = (Math.sin(spin * 3.14159 / 180.0) * 6.0).toNumber();
            dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 1, ay - 6 + bladeOff, 3, 8);
            dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax, ay - 6 + bladeOff, 1, 8);
            dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 1, ay + 2, 3, 10);
            dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax, ay + 2, 1, 10);
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax, ay + 12, 2);
        } else {
            dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 3, ay - 6, 7, 4);
            dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 2, ay - 5, 5, 2);
            dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 1, ay - 2, 3, 12);
            dc.setColor(0x7A5A33, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax, ay - 2, 1, 12);
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax, ay + 10, 2);

            if (_tick % 6 < 3) {
                dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
                dc.drawText(ax, ay - 16, Graphics.FONT_XTINY, "^", Graphics.TEXT_JUSTIFY_CENTER);
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

    hidden function drawHUD(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 2, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(5, 2, Graphics.FONT_XTINY, "Lv" + _level, Graphics.TEXT_JUSTIFY_LEFT);

        var remain = _axesPerLevel - _axesThisLevel;
        if (remain > 0 && gameState != GS_OVER && gameState != GS_FAIL) {
            var dotY = _h - 35;
            for (var d = 0; d < remain && d < 8; d++) {
                dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_cx - (remain * 4) + d * 8 + 4, dotY, 2);
                dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_cx - (remain * 4) + d * 8 + 4, dotY, 1);
            }
        }

        var speedPct = ((_logSpeed - 1.2) / 3.8 * 100.0).toNumber();
        if (speedPct > 100) { speedPct = 100; }
        if (speedPct > 0) {
            var barW = _w * 30 / 100;
            var barX = _w - barW - 5;
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, 3, barW, 4);
            var fill = speedPct * barW / 100;
            var bc = (speedPct > 70) ? 0xFF4444 : ((speedPct > 40) ? 0xFFAA44 : 0x44AA44);
            dc.setColor(bc, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, 3, fill, 4);
        }
    }

    hidden function drawCombo(dc) {
        var alpha = _comboTimer.toFloat() / 40.0;
        var cy = _h * 25 / 100 - ((40 - _comboTimer) / 2);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, cy + 1, Graphics.FONT_SMALL, _comboMsg, Graphics.TEXT_JUSTIFY_CENTER);
        var mc = (_comboMsg.find("LEVEL") != null) ? 0x44FFAA : 0xFFCC44;
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, cy, Graphics.FONT_SMALL, _comboMsg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawStickFlash(dc) {
        if (_stickAnim > 7) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, _w, _h);
        }
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx - _w * 35 / 100, _cy + _logR + 10, _w * 70 / 100, _h * 40 / 100);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_cx - _w * 35 / 100, _cy + _logR + 10, _w * 70 / 100, _h * 40 / 100);

        var ty = _cy + _logR + 15;
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, ty, Graphics.FONT_SMALL, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        ty += 22;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, ty, Graphics.FONT_XTINY, "Score: " + _score, Graphics.TEXT_JUSTIFY_CENTER);
        ty += 16;
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, ty, Graphics.FONT_XTINY, "Best: " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        ty += 18;
        if (_tick % 10 < 5) {
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, ty, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x1A1A2E, 0x1A1A2E);
        dc.clear();
        dc.setColor(0x16213E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h / 2);

        for (var i = 0; i < 20; i++) {
            var st = _bgStars[i];
            var blink = ((_tick + i * 7) % 20 < 3) ? 0x555577 : 0x8888AA;
            dc.setColor(blink, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(st[0], st[1], st[2], st[2]);
        }

        var lcx = _cx;
        var lcy = _cy;
        var lr = _logR - 4;
        var menuAngle = _tick.toFloat() * 1.5;
        dc.setColor(0x6B4226, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, lr);
        dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, lr - 3);
        dc.setColor(0xA0723C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, lr - 7);
        dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, lr - 10);
        dc.setColor(0xA0723C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lcx, lcy, 3);

        for (var a = 0; a < 3; a++) {
            var demoAngle = menuAngle + a.toFloat() * 120.0;
            var rad = demoAngle * 3.14159 / 180.0;
            var ex = lcx + (Math.sin(rad) * lr.toFloat()).toNumber();
            var ey = lcy - (Math.cos(rad) * lr.toFloat()).toNumber();
            var hx = lcx + (Math.sin(rad) * (lr.toFloat() + 16.0)).toNumber();
            var hy = lcy - (Math.cos(rad) * (lr.toFloat() + 16.0)).toNumber();
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(ex, ey, hx, hy);
            dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
            var eex = lcx + (Math.sin(rad) * (lr.toFloat() + 20.0)).toNumber();
            var eey = lcy - (Math.cos(rad) * (lr.toFloat() + 20.0)).toNumber();
            dc.drawLine(hx, hy, eex, eey);
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(eex, eey, 2);
        }

        dc.setColor(0x4A2A11, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(lcx, lcy, lr);

        var titleC = (_tick % 14 < 7) ? 0xFF8844 : 0xFFAA66;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, _h * 4 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(titleC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 4 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 17 / 100, Graphics.FONT_SMALL, "AXE ARCADE", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x2A1A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - 18, _w, 18);
        dc.setColor(0x3A2A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - 18, _w, 3);
        drawTorch(dc, 8, _h - 18);
        drawTorch(dc, _w - 14, _h - 18);

        if (_bestScore > 0) {
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 72 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0xFF8844 : 0xFFAA66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 82 / 100, Graphics.FONT_XTINY, "Tap to play", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
