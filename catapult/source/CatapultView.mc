using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum {
    GS_READY,
    GS_ANGLE,
    GS_POWER,
    GS_FLIGHT,
    GS_HIT,
    GS_RESULT,
    GS_GAMEOVER
}

const MAX_BLOCKS = 25;
const MAX_PARTS = 12;

class CatapultView extends WatchUi.View {

    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _groundY;
    hidden var _catX;
    hidden var _pivotY;
    hidden var _armLen;
    hidden var _bw;
    hidden var _bh;

    hidden var _angle;
    hidden var _angleDir;
    hidden var _lockedAngle;

    hidden var _power;
    hidden var _powerDir;
    hidden var _lockedPower;

    hidden var _px;
    hidden var _py;
    hidden var _vx;
    hidden var _vy;
    hidden var _projAlive;
    hidden var _projColor;

    hidden var _bx;
    hidden var _by;
    hidden var _ba;
    hidden var _numBlocks;

    hidden var _enemyX;
    hidden var _enemyY;
    hidden var _enemyHp;
    hidden var _enemyMaxHp;
    hidden var _enemyColor;
    hidden var _enemyName;

    hidden var _round;
    hidden var _shots;
    hidden var _score;
    hidden var _timer;
    hidden var _tick;
    hidden var _hitTick;

    hidden var _prtX;
    hidden var _prtY;
    hidden var _prtVx;
    hidden var _prtVy;
    hidden var _prtL;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());

        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _groundY = _h * 78 / 100;
        _catX = _w * 10 / 100;
        var baseH = _w * 3 / 100;
        if (baseH < 4) { baseH = 4; }
        var suppH = _w * 7 / 100;
        if (suppH < 8) { suppH = 8; }
        _pivotY = _groundY - baseH - suppH;
        _armLen = _w * 12 / 100;
        if (_armLen < 16) { _armLen = 16; }
        _bw = _w * 5 / 100;
        if (_bw < 8) { _bw = 8; }
        _bh = _bw;

        _bx = new [MAX_BLOCKS];
        _by = new [MAX_BLOCKS];
        _ba = new [MAX_BLOCKS];
        _prtX = new [MAX_PARTS];
        _prtY = new [MAX_PARTS];
        _prtVx = new [MAX_PARTS];
        _prtVy = new [MAX_PARTS];
        _prtL = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) { _prtL[i] = 0; }

        _score = 0;
        _round = 0;
        _tick = 0;
        _numBlocks = 0;
        initRound();
    }

    hidden function initRound() {
        _round++;
        _shots = 3;
        gameState = GS_READY;

        if (_round == 1)      { _enemyName = "Blobby";  _enemyColor = 0x33DD66; _enemyMaxHp = 45; }
        else if (_round == 2) { _enemyName = "Chikko";  _enemyColor = 0xFFCC22; _enemyMaxHp = 70; }
        else if (_round == 3) { _enemyName = "Dzikko";  _enemyColor = 0x886644; _enemyMaxHp = 100; }
        else if (_round == 4) { _enemyName = "Rocky";   _enemyColor = 0x889999; _enemyMaxHp = 140; }
        else                  { _enemyName = "Vexor";   _enemyColor = 0xDD2222; _enemyMaxHp = 185; }
        _enemyHp = _enemyMaxHp;

        buildCastle();
        resetShot();
    }

    hidden function buildCastle() {
        var baseCols;
        var rows;
        if (_round <= 1)      { baseCols = 3; rows = 2; }
        else if (_round == 2) { baseCols = 4; rows = 2; }
        else if (_round == 3) { baseCols = 4; rows = 3; }
        else if (_round == 4) { baseCols = 5; rows = 3; }
        else                  { baseCols = 5; rows = 4; }

        var castleCx = _w * 73 / 100;
        _numBlocks = 0;

        for (var row = 0; row < rows; row++) {
            var rc = baseCols - row;
            if (rc <= 0) { break; }
            var sx = castleCx - (rc * _bw) / 2;
            for (var col = 0; col < rc; col++) {
                if (_numBlocks >= MAX_BLOCKS) { break; }
                _bx[_numBlocks] = sx + col * _bw;
                _by[_numBlocks] = _groundY - (row + 1) * _bh;
                _ba[_numBlocks] = 1;
                _numBlocks++;
            }
        }

        _enemyX = castleCx;
        _enemyY = _groundY - (rows * _bh) - _bw;
    }

    hidden function resetShot() {
        _angle = 45;
        _angleDir = 1;
        _power = 50;
        _powerDir = 1;
        _lockedAngle = 45;
        _lockedPower = 50;
        _projAlive = false;
        _hitTick = 0;
        _px = 0.0;
        _py = 0.0;
        _vx = 0.0;
        _vy = 0.0;
        for (var i = 0; i < MAX_PARTS; i++) { _prtL[i] = 0; }

        var colors = [0x33DD66, 0xFF4422, 0x3388FF, 0xFFCC22, 0xFF44FF, 0x44FFFF, 0xFF8833, 0xDD33FF];
        _projColor = colors[Math.rand().abs() % colors.size()];
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 40, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _tick++;

        if (gameState == GS_ANGLE) {
            _angle += _angleDir * 2;
            if (_angle >= 75) { _angle = 75; _angleDir = -1; }
            if (_angle <= 20) { _angle = 20; _angleDir = 1; }
        } else if (gameState == GS_POWER) {
            _power += _powerDir * 3;
            if (_power >= 100) { _power = 100; _powerDir = -1; }
            if (_power <= 5) { _power = 5; _powerDir = 1; }
        } else if (gameState == GS_FLIGHT) {
            updateFlight();
        } else if (gameState == GS_HIT) {
            _hitTick++;
            updateParticles();
            if (_hitTick >= 25) {
                if (_enemyHp <= 0) {
                    _score += 100 + _shots * 50;
                    gameState = (_round >= 5) ? GS_GAMEOVER : GS_RESULT;
                } else if (_shots <= 0) {
                    gameState = (_round >= 5) ? GS_GAMEOVER : GS_RESULT;
                } else {
                    resetShot();
                    gameState = GS_ANGLE;
                }
            }
        }

        WatchUi.requestUpdate();
    }

    hidden function updateFlight() {
        if (!_projAlive) { return; }

        _vy = _vy + 0.35;
        _px = _px + _vx;
        _py = _py + _vy;

        var ipx = _px.toNumber();
        var ipy = _py.toNumber();

        if (ipx > _w + 30 || ipy > _h + 30 || ipx < -30) {
            doHit(ipx, ipy);
            return;
        }

        if (ipy >= _groundY) {
            doHit(ipx, _groundY);
            return;
        }

        var pr = _bw / 3;
        for (var i = 0; i < _numBlocks; i++) {
            if (_ba[i] != 1) { continue; }
            if (ipx + pr >= _bx[i] && ipx - pr <= _bx[i] + _bw &&
                ipy + pr >= _by[i] && ipy - pr <= _by[i] + _bh) {
                doHit(ipx, ipy);
                return;
            }
        }

        if (_enemyHp > 0) {
            var er = _bw;
            var dx = ipx - _enemyX;
            var dy = ipy - _enemyY;
            if (dx * dx + dy * dy < (er + pr) * (er + pr)) {
                var spd = Math.sqrt(_vx * _vx + _vy * _vy);
                var dmg = (spd * 12.0).toNumber();
                if (dmg < 10) { dmg = 10; }
                _enemyHp -= dmg;
                _score += dmg;
                doHit(ipx, ipy);
                return;
            }
        }
    }

    hidden function doHit(hx, hy) {
        _projAlive = false;
        _shots--;
        gameState = GS_HIT;
        _hitTick = 0;

        var splR = _bw * 2;
        for (var i = 0; i < _numBlocks; i++) {
            if (_ba[i] != 1) { continue; }
            var bcx = _bx[i] + _bw / 2;
            var bcy = _by[i] + _bh / 2;
            var ddx = hx - bcx;
            var ddy = hy - bcy;
            if (ddx * ddx + ddy * ddy < splR * splR) {
                _ba[i] = 0;
                _score += 10;
            }
        }

        if (_enemyHp > 0) {
            var edx = hx - _enemyX;
            var edy = hy - _enemyY;
            if (edx * edx + edy * edy < splR * splR * 2) {
                _enemyHp -= 15;
                _score += 15;
            }
        }

        spawnParticles(hx, hy);
        doVibe();
    }

    hidden function spawnParticles(x, y) {
        for (var i = 0; i < MAX_PARTS; i++) {
            _prtX[i] = x.toFloat();
            _prtY[i] = y.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var s = 1.0 + (Math.rand().abs() % 40).toFloat() / 10.0;
            _prtVx[i] = s * Math.cos(a);
            _prtVy[i] = -s * Math.sin(a);
            _prtL[i] = 8 + Math.rand().abs() % 12;
        }
    }

    hidden function updateParticles() {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_prtL[i] <= 0) { continue; }
            _prtX[i] = _prtX[i] + _prtVx[i];
            _prtY[i] = _prtY[i] + _prtVy[i] + 0.2;
            _prtL[i] = _prtL[i] - 1;
        }
    }

    hidden function doVibe() {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(50, 200)]);
            }
        }
    }

    function doAction() {
        if (gameState == GS_READY) {
            gameState = GS_ANGLE;
        } else if (gameState == GS_ANGLE) {
            _lockedAngle = _angle;
            gameState = GS_POWER;
        } else if (gameState == GS_POWER) {
            _lockedPower = _power;
            launchProjectile();
        } else if (gameState == GS_RESULT) {
            initRound();
        } else if (gameState == GS_GAMEOVER) {
            _score = 0;
            _round = 0;
            initRound();
        }
    }

    hidden function launchProjectile() {
        gameState = GS_FLIGHT;
        _projAlive = true;

        var rad = _lockedAngle.toFloat() * 3.14159 / 180.0;
        var speed = 3.5 + _lockedPower.toFloat() * 8.5 / 100.0;
        _vx = speed * Math.cos(rad);
        _vy = -speed * Math.sin(rad);
        _px = _catX.toFloat() + _armLen.toFloat() * Math.cos(rad);
        _py = _pivotY.toFloat() - _armLen.toFloat() * Math.sin(rad);
    }

    // ===== Drawing =====

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x0A0A1A, 0x0A0A1A);
        dc.clear();

        if (gameState == GS_READY) { drawReady(dc, w, h); return; }
        if (gameState == GS_GAMEOVER) { drawGameOver(dc, w, h); return; }
        if (gameState == GS_RESULT) { drawResult(dc, w, h); return; }

        drawGround(dc, w, h);
        drawBlocks(dc, w, h);
        drawEnemySprite(dc, w, h);
        drawCatapultSprite(dc, w, h);

        if (gameState == GS_POWER) { drawTrajectory(dc, w, h); }
        if (_projAlive) { drawProj(dc); }

        drawParticlesFx(dc);
        drawHud(dc, w, h);

        if (gameState == GS_ANGLE) { drawAngleHud(dc, w, h); }
        if (gameState == GS_POWER) { drawPowerHud(dc, w, h); }
    }

    hidden function drawGround(dc, w, h) {
        dc.setColor(0x334422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _groundY, w, h - _groundY);
        dc.setColor(0x557733, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _groundY, w, 2);
    }

    hidden function drawBlocks(dc, w, h) {
        for (var i = 0; i < _numBlocks; i++) {
            if (_ba[i] != 1) { continue; }
            dc.setColor(0x667788, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_bx[i], _by[i], _bw, _bh);
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(_bx[i], _by[i], _bw, _bh);
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(_bx[i] + _bw / 3, _by[i], _bx[i] + _bw / 2, _by[i] + _bh);
        }
    }

    hidden function drawEnemySprite(dc, w, h) {
        if (_enemyHp <= 0) { return; }

        var r = _bw;
        var shake = 0;
        if (gameState == GS_HIT && _hitTick < 10) {
            shake = (_hitTick % 4 < 2) ? 2 : -2;
        }
        var ex = _enemyX + shake;

        dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex, _enemyY, r);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ex, _enemyY, r);

        var eo = r / 3;
        var ep = r > 8 ? r / 5 : 2;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex - eo, _enemyY - eo / 2, ep);
        dc.fillCircle(ex + eo, _enemyY - eo / 2, ep);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        var pp = ep > 2 ? ep / 2 : 1;
        dc.fillCircle(ex - eo, _enemyY - eo / 2, pp);
        dc.fillCircle(ex + eo, _enemyY - eo / 2, pp);

        if (r > 6) {
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ex - eo, _enemyY + eo / 2, eo * 2, 2);
        }

        var barW = r * 2;
        var barX = _enemyX - r;
        var barY2 = _enemyY - r - 6;
        dc.setColor(0x440000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY2, barW, 3);
        var hw = barW * _enemyHp / _enemyMaxHp;
        if (hw < 0) { hw = 0; }
        dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY2, hw, 3);
    }

    hidden function drawCatapultSprite(dc, w, h) {
        var baseW = _w * 8 / 100;
        if (baseW < 10) { baseW = 10; }
        var baseH = _w * 3 / 100;
        if (baseH < 4) { baseH = 4; }

        dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_catX - baseW / 2, _groundY - baseH, baseW, baseH);

        dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
        var whl = baseH / 2;
        if (whl < 2) { whl = 2; }
        dc.fillCircle(_catX - baseW / 3, _groundY, whl);
        dc.fillCircle(_catX + baseW / 3, _groundY, whl);

        var sw = _w * 2 / 100;
        if (sw < 3) { sw = 3; }
        dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_catX - sw / 2, _pivotY, sw, _groundY - baseH - _pivotY);

        var curAngle = (gameState == GS_ANGLE) ? _angle : _lockedAngle;
        if (gameState == GS_FLIGHT || gameState == GS_HIT) { curAngle = 10; }
        var rad = curAngle.toFloat() * 3.14159 / 180.0;
        var tipX = _catX + (_armLen.toFloat() * Math.cos(rad)).toNumber();
        var tipY = _pivotY - (_armLen.toFloat() * Math.sin(rad)).toNumber();

        dc.setColor(0x886644, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(_catX, _pivotY, tipX, tipY);
        dc.setPenWidth(1);

        dc.setColor(0x775533, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tipX - 3, tipY - 2, 6, 5);

        if (gameState == GS_ANGLE || gameState == GS_POWER) {
            dc.setColor(_projColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tipX, tipY - 5, 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tipX - 2, tipY - 7, 1, 1);
            dc.fillRectangle(tipX + 1, tipY - 7, 1, 1);
        }
    }

    hidden function drawTrajectory(dc, w, h) {
        var rad = _lockedAngle.toFloat() * 3.14159 / 180.0;
        var speed = 3.5 + _power.toFloat() * 8.5 / 100.0;
        var tvx = speed * Math.cos(rad);
        var tvy = -speed * Math.sin(rad);
        var tx = _catX.toFloat() + _armLen.toFloat() * Math.cos(rad);
        var ty = _pivotY.toFloat() - _armLen.toFloat() * Math.sin(rad);

        dc.setColor(0x333355, Graphics.COLOR_TRANSPARENT);
        var simVy = tvy;
        var simX = tx;
        var simY = ty;
        for (var t = 0; t < 80; t++) {
            simVy = simVy + 0.35;
            simX = simX + tvx;
            simY = simY + simVy;
            if (simY >= _groundY.toFloat() || simX >= w.toFloat() || simX < 0.0) { break; }
            if (t % 3 == 0) {
                dc.fillRectangle(simX.toNumber(), simY.toNumber(), 2, 2);
            }
        }
    }

    hidden function drawProj(dc) {
        var x = _px.toNumber();
        var y = _py.toNumber();
        dc.setColor(_projColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 2, y - 2, 1, 1);
        dc.fillRectangle(x + 1, y - 2, 1, 1);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        if (_vy < -1.0) {
            dc.fillRectangle(x, y + 4, 1, 3);
            dc.fillRectangle(x - 2, y + 3, 1, 2);
            dc.fillRectangle(x + 2, y + 3, 1, 2);
        }
    }

    hidden function drawParticlesFx(dc) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_prtL[i] <= 0) { continue; }
            var c = 0xFF8833;
            if (_prtL[i] <= 6) { c = 0xFF4422; }
            if (_prtL[i] <= 3) { c = 0x882211; }
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            var ps = (_prtL[i] > 5) ? 3 : 2;
            dc.fillRectangle(_prtX[i].toNumber(), _prtY[i].toNumber(), ps, ps);
        }
    }

    hidden function drawHud(dc, w, h) {
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 3, Graphics.FONT_XTINY, "R" + _round + " vs " + _enemyName, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 5, h * 12 / 100, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);

        for (var i = 0; i < _shots; i++) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w / 2 - (_shots - 1) * 8 / 2 + i * 8, h * 92 / 100, 3);
        }
    }

    hidden function drawAngleHud(dc, w, h) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_catX + _armLen + 5, _pivotY - _armLen, Graphics.FONT_XTINY, _angle + "d", Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(0x444466, Graphics.COLOR_TRANSPARENT);
        for (var a = 20; a <= 75; a += 5) {
            var rad = a.toFloat() * 3.14159 / 180.0;
            var ax = _catX + (20.0 * Math.cos(rad)).toNumber();
            var ay = _pivotY - (20.0 * Math.sin(rad)).toNumber();
            dc.fillRectangle(ax, ay, 2, 2);
        }

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        var crad = _angle.toFloat() * 3.14159 / 180.0;
        var mx = _catX + (22.0 * Math.cos(crad)).toNumber();
        var my = _pivotY - (22.0 * Math.sin(crad)).toNumber();
        dc.fillCircle(mx, my, 3);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 85 / 100, Graphics.FONT_XTINY, "SET ANGLE", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawPowerHud(dc, w, h) {
        var barX = 5;
        var barY = h * 25 / 100;
        var barH = h * 50 / 100;
        var barW = 8;

        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, barH);

        var fillH = barH * _power / 100;
        var c = 0x44FF44;
        if (_power > 75) { c = 0xFF4422; }
        else if (_power > 40) { c = 0xFFCC22; }
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY + barH - fillH, barW, fillH);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barX + barW / 2, barY - 14, Graphics.FONT_XTINY, "" + _power, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 85 / 100, Graphics.FONT_XTINY, "SET POWER", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawReady(dc, w, h) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_MEDIUM, "ROUND " + _round, Graphics.TEXT_JUSTIFY_CENTER);

        var r = w * 12 / 100;
        if (r < 10) { r = 10; }
        var cy = h * 45 / 100;
        dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, cy, r);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(w / 2, cy, r);

        var eo = r / 3;
        var ep = r > 8 ? r / 5 : 2;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2 - eo, cy - eo / 2, ep);
        dc.fillCircle(w / 2 + eo, cy - eo / 2, ep);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        var pp = ep > 2 ? ep / 2 : 1;
        dc.fillCircle(w / 2 - eo, cy - eo / 2, pp);
        dc.fillCircle(w / 2 + eo, cy - eo / 2, pp);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 60 / 100, Graphics.FONT_SMALL, "vs " + _enemyName, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 70 / 100, Graphics.FONT_XTINY, "HP: " + _enemyMaxHp, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_XTINY, "Press to start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawResult(dc, w, h) {
        var cleared = _enemyHp <= 0;

        dc.setColor(cleared ? 0x44FF44 : 0xFF8844, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 18 / 100, Graphics.FONT_MEDIUM, cleared ? "VICTORY!" : "ROUND OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 38 / 100, Graphics.FONT_SMALL, "Score: " + _score, Graphics.TEXT_JUSTIFY_CENTER);

        if (cleared) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 52 / 100, Graphics.FONT_XTINY, _enemyName + " defeated!", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 52 / 100, Graphics.FONT_XTINY, _enemyName + " survived...", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_round < 5) {
            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 64 / 100, Graphics.FONT_XTINY, "Next: Round " + (_round + 1), Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY, "Press to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc, w, h) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 35 / 100, Graphics.FONT_MEDIUM, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 48 / 100, Graphics.FONT_XTINY, "Final Score", Graphics.TEXT_JUSTIFY_CENTER);

        var grade;
        if (_score >= 1500) { grade = "LEGENDARY!"; }
        else if (_score >= 1000) { grade = "MASTER!"; }
        else if (_score >= 600) { grade = "GREAT!"; }
        else if (_score >= 300) { grade = "GOOD"; }
        else { grade = "TRY AGAIN"; }
        dc.setColor(0x44FFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 60 / 100, Graphics.FONT_SMALL, grade, Graphics.TEXT_JUSTIFY_CENTER);

        var defeated = 0;
        if (_round >= 1 && _score >= 145) { defeated++; }
        if (_round >= 2 && _score >= 320) { defeated++; }
        if (_round >= 3 && _score >= 520) { defeated++; }
        if (_round >= 4 && _score >= 770) { defeated++; }
        if (_round >= 5 && _score >= 1000) { defeated++; }
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_XTINY, "Bosses: " + defeated + "/5", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 84 / 100, Graphics.FONT_XTINY, "Press to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
