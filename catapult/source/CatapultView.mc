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

const MAX_BLOCKS = 50;
const MAX_PARTS = 30;
const TRAIL_LEN = 14;

class CatapultView extends WatchUi.View {

    var gameState;

    hidden var _w;
    hidden var _h;

    // camera
    hidden var _camX;
    hidden var _camTargetX;
    hidden var _worldScale;

    // catapult (world coords)
    hidden var _catWX;
    hidden var _groundWY;

    // castle distance per round
    hidden var _castleWX;

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
    hidden var _maxAlt;

    // blocks in world coords
    hidden var _bx;
    hidden var _by;
    hidden var _bhp;
    hidden var _bkind;
    hidden var _numBlocks;
    hidden var _bw;

    hidden var _enemyWX;
    hidden var _enemyWY;
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
    hidden var _combo;

    hidden var _prtX;
    hidden var _prtY;
    hidden var _prtVx;
    hidden var _prtVy;
    hidden var _prtL;
    hidden var _prtC;

    hidden var _trailX;
    hidden var _trailY;
    hidden var _trailIdx;

    hidden var _wind;
    hidden var _windDisplay;
    hidden var _windGust;

    hidden var _shakeLeft;
    hidden var _shakeOx;
    hidden var _shakeOy;
    hidden var _hitEnemyDirect;
    hidden var _critHit;
    hidden var _beatGame;
    hidden var _resultTick;

    // debris / rubble
    hidden var _debrisX;
    hidden var _debrisY;
    hidden var _debrisVx;
    hidden var _debrisVy;
    hidden var _debrisL;
    hidden var _debrisC;

    hidden var _flashTick;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());

        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;

        _catWX = 0.0;
        _groundWY = 200.0;
        _worldScale = 1.0;

        _bw = 12;

        _bx = new [MAX_BLOCKS];
        _by = new [MAX_BLOCKS];
        _bhp = new [MAX_BLOCKS];
        _bkind = new [MAX_BLOCKS];
        _prtX = new [MAX_PARTS];
        _prtY = new [MAX_PARTS];
        _prtVx = new [MAX_PARTS];
        _prtVy = new [MAX_PARTS];
        _prtL = new [MAX_PARTS];
        _prtC = new [MAX_PARTS];
        _trailX = new [TRAIL_LEN];
        _trailY = new [TRAIL_LEN];
        _debrisX = new [16];
        _debrisY = new [16];
        _debrisVx = new [16];
        _debrisVy = new [16];
        _debrisL = new [16];
        _debrisC = new [16];
        for (var i = 0; i < MAX_PARTS; i++) { _prtL[i] = 0; }
        for (var i = 0; i < 16; i++) { _debrisL[i] = 0; }

        _score = 0;
        _round = 0;
        _tick = 0;
        _combo = 0;
        _beatGame = false;
        _resultTick = 0;
        _flashTick = 0;
        initRound();
    }

    hidden function initRound() {
        _round++;
        _shots = 3;
        gameState = GS_READY;
        _windDisplay = (Math.rand().abs() % 19) - 9;
        _wind = _windDisplay.toFloat() * 0.018;
        _windGust = 0.0;

        _castleWX = 220.0 + (_round * 50).toFloat();

        if (_round == 1)      { _enemyName = "Blobby";  _enemyColor = 0x33DD66; _enemyMaxHp = 60; }
        else if (_round == 2) { _enemyName = "Chikko";  _enemyColor = 0xFFCC22; _enemyMaxHp = 100; }
        else if (_round == 3) { _enemyName = "Dzikko";  _enemyColor = 0x886644; _enemyMaxHp = 150; }
        else if (_round == 4) { _enemyName = "Rocky";   _enemyColor = 0x889999; _enemyMaxHp = 210; }
        else if (_round == 5) { _enemyName = "Vexor";   _enemyColor = 0xDD2222; _enemyMaxHp = 280; }
        else if (_round == 6) { _enemyName = "Emilka";  _enemyColor = 0xCC66DD; _enemyMaxHp = 350; }
        else                  { _enemyName = "Batsy";   _enemyColor = 0x5533AA; _enemyMaxHp = 440; }
        _enemyHp = _enemyMaxHp;

        buildCastle();
        resetShot();
        _camX = _catWX;
        _camTargetX = _catWX;
    }

    hidden function addBlock(wx, wy, kind) {
        if (_numBlocks >= MAX_BLOCKS) { return; }
        _bx[_numBlocks] = wx;
        _by[_numBlocks] = wy;
        _bkind[_numBlocks] = kind;
        _bhp[_numBlocks] = (kind == 1) ? 2 : 1;
        _numBlocks++;
    }

    hidden function buildCastle() {
        _numBlocks = 0;
        var cx = _castleWX;
        var gy = _groundWY;
        var bw = _bw.toFloat();

        var tier = _round;
        if (tier > 7) { tier = 7; }
        var cols = 3 + tier / 2;
        if (cols > 6) { cols = 6; }
        var rows = 2 + tier / 2;
        if (rows > 5) { rows = 5; }

        var startX = cx - (cols * bw) / 2.0;

        for (var r = 0; r < rows; r++) {
            var rc = cols - r / 2;
            if (rc < 2) { rc = 2; }
            var offX = startX + (cols - rc).toFloat() * bw / 2.0;
            for (var c = 0; c < rc; c++) {
                if (r > 0 && r < rows - 1 && c > 0 && c < rc - 1 && (c + r) % 3 == 0) {
                    continue;
                }
                var rng = Math.rand().abs() % 100;
                var k = 0;
                if (rng < 10 + tier * 2) { k = 2; }
                else if (rng < 25 + tier * 3) { k = 1; }
                addBlock(offX + c.toFloat() * bw, gy - (r + 1).toFloat() * bw, k);
            }
        }

        // towers on sides
        if (tier >= 3) {
            for (var tr = 0; tr < rows + 1; tr++) {
                addBlock(startX - bw, gy - (tr + 1).toFloat() * bw, (tr % 3 == 0) ? 1 : 0);
                addBlock(startX + cols.toFloat() * bw, gy - (tr + 1).toFloat() * bw, (tr % 3 == 0) ? 1 : 0);
            }
        }

        // crest
        if (tier >= 5) {
            var cw = cols - 2;
            if (cw < 2) { cw = 2; }
            var coff = startX + bw;
            for (var c = 0; c < cw; c++) {
                addBlock(coff + c.toFloat() * bw, gy - (rows + 1).toFloat() * bw, (c % 2 == 0) ? 1 : 2);
            }
        }

        _enemyWX = cx;
        _enemyWY = gy - (rows + 1).toFloat() * bw - bw;
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
        _hitEnemyDirect = false;
        _critHit = false;
        _px = 0.0;
        _py = 0.0;
        _vx = 0.0;
        _vy = 0.0;
        _maxAlt = 0.0;
        _shakeLeft = 0;
        _shakeOx = 0;
        _shakeOy = 0;
        _trailIdx = 0;
        _flashTick = 0;
        for (var i = 0; i < TRAIL_LEN; i++) { _trailX[i] = 0.0; _trailY[i] = 0.0; }
        for (var i = 0; i < MAX_PARTS; i++) { _prtL[i] = 0; }
        for (var i = 0; i < 16; i++) { _debrisL[i] = 0; }

        var colors = [0x33DD66, 0xFF4422, 0x3388FF, 0xFFCC22, 0xFF44FF, 0x44FFFF];
        _projColor = colors[Math.rand().abs() % 6];
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

        if (_shakeLeft > 0) {
            _shakeOx = (Math.rand().abs() % 9) - 4;
            _shakeOy = (Math.rand().abs() % 7) - 3;
            _shakeLeft--;
        } else { _shakeOx = 0; _shakeOy = 0; }

        if (_flashTick > 0) { _flashTick--; }

        if (gameState == GS_ANGLE) {
            var spd = 2 + _round / 2;
            if (spd > 5) { spd = 5; }
            _angle += _angleDir * spd;
            if (_angle >= 78) { _angle = 78; _angleDir = -1; }
            if (_angle <= 15) { _angle = 15; _angleDir = 1; }
        } else if (gameState == GS_POWER) {
            var spd = 3 + _round / 2;
            if (spd > 6) { spd = 6; }
            _power += _powerDir * spd;
            if (_power >= 100) { _power = 100; _powerDir = -1; }
            if (_power <= 5) { _power = 5; _powerDir = 1; }
        } else if (gameState == GS_FLIGHT) {
            updateFlight();
            _camTargetX = _px;
        } else if (gameState == GS_HIT) {
            _hitTick++;
            updateParticles();
            updateDebris();
            if (_hitTick >= 30) {
                if (_enemyHp <= 0) {
                    _beatGame = (_round >= 7);
                    _score += 150 + _shots * 60;
                    gameState = (_round >= 7) ? GS_GAMEOVER : GS_RESULT;
                    _resultTick = 0;
                } else if (_shots <= 0) {
                    _beatGame = false;
                    gameState = (_round >= 7) ? GS_GAMEOVER : GS_RESULT;
                    _resultTick = 0;
                } else {
                    resetShot();
                    gameState = GS_ANGLE;
                    _camTargetX = _catWX;
                }
            }
        } else if (gameState == GS_RESULT || gameState == GS_GAMEOVER) {
            _resultTick++;
        }

        // smooth camera
        var diff = _camTargetX - _camX;
        _camX += diff * 0.12;

        // calc scale based on how far the projectile is
        if (gameState == GS_FLIGHT || gameState == GS_HIT) {
            var dist = _castleWX - _catWX;
            var projProgress = (_px - _catWX) / dist;
            if (projProgress < 0.0) { projProgress = 0.0; }
            if (projProgress > 1.0) { projProgress = 1.0; }
            var targetScale = 0.35 + (1.0 - projProgress) * 0.25;
            _worldScale += (targetScale - _worldScale) * 0.08;
        } else {
            var targetScale = 0.55;
            _worldScale += (targetScale - _worldScale) * 0.1;
        }

        WatchUi.requestUpdate();
    }

    hidden function w2sx(wx) {
        return (_w / 2 + ((wx - _camX) * _worldScale).toNumber());
    }

    hidden function w2sy(wy) {
        return (_h * 72 / 100 + ((wy - _groundWY) * _worldScale).toNumber());
    }

    hidden function updateFlight() {
        if (!_projAlive) { return; }

        // wind gusts
        _windGust = _windGust * 0.95 + (Math.rand().abs() % 5 - 2).toFloat() * 0.002;

        // air drag
        var speed = Math.sqrt(_vx * _vx + _vy * _vy);
        var dragCoeff = 0.0004 + _round.toFloat() * 0.00005;
        var dragX = -dragCoeff * _vx * speed;
        var dragY = -dragCoeff * _vy * speed;

        _vx += _wind + _windGust + dragX;
        _vy += 0.28 + dragY;
        _px += _vx;
        _py += _vy;

        if (_py < _maxAlt) { _maxAlt = _py; }

        // trail
        _trailX[_trailIdx] = _px;
        _trailY[_trailIdx] = _py;
        _trailIdx = (_trailIdx + 1) % TRAIL_LEN;

        // out of bounds
        if (_px > _castleWX + 200.0 || _py > _groundWY + 50.0 || _px < -100.0) {
            doHit(_px, _py);
            return;
        }

        // ground hit
        if (_py >= _groundWY) {
            doHit(_px, _groundWY);
            return;
        }

        // block collision
        var bwf = _bw.toFloat();
        for (var i = 0; i < _numBlocks; i++) {
            if (_bhp[i] <= 0) { continue; }
            if (_px >= _bx[i] - 3.0 && _px <= _bx[i] + bwf + 3.0 &&
                _py >= _by[i] - 3.0 && _py <= _by[i] + bwf + 3.0) {
                doHit(_px, _py);
                return;
            }
        }

        // enemy collision
        if (_enemyHp > 0) {
            var dx = _px - _enemyWX;
            var dy = _py - _enemyWY;
            var er = bwf * 1.2;
            if (dx * dx + dy * dy < er * er) {
                var dmg = (speed * 15.0).toNumber();
                if (dmg < 15) { dmg = 15; }
                dmg = dmg * 2;
                _enemyHp -= dmg;
                _hitEnemyDirect = true;
                _critHit = true;
                _score += dmg * 2;
                doHit(_px, _py);
                return;
            }
        }
    }

    hidden function doHit(hx, hy) {
        _projAlive = false;
        _shots--;
        gameState = GS_HIT;
        _hitTick = 0;
        _flashTick = 6;

        var splR = _bw.toFloat() * 3.0;
        var bwf = _bw.toFloat();
        var hitSomething = _hitEnemyDirect;

        // splash damage to blocks
        for (var i = 0; i < _numBlocks; i++) {
            if (_bhp[i] <= 0) { continue; }
            var bcx = _bx[i] + bwf / 2.0;
            var bcy = _by[i] + bwf / 2.0;
            var dx = hx - bcx;
            var dy = hy - bcy;
            if (dx * dx + dy * dy < splR * splR) {
                _bhp[i]--;
                hitSomething = true;
                if (_bhp[i] <= 0) {
                    _score += (_bkind[i] == 1) ? 20 : ((_bkind[i] == 2) ? 30 : 12);
                    // explosive chain
                    if (_bkind[i] == 2) {
                        chainExplosion(_bx[i] + bwf / 2.0, _by[i] + bwf / 2.0);
                    }
                    spawnDebris(_bx[i] + bwf / 2.0, _by[i] + bwf / 2.0, _bkind[i]);
                }
            }
        }

        // splash to enemy
        if (_enemyHp > 0 && !_hitEnemyDirect) {
            var edx = hx - _enemyWX;
            var edy = hy - _enemyWY;
            if (edx * edx + edy * edy < splR * splR * 2.5) {
                var dmg = 20 + _round * 3;
                _enemyHp -= dmg;
                _score += dmg;
                hitSomething = true;
            }
        }

        if (hitSomething) { _combo++; } else { _combo = 0; }

        spawnImpactParticles(hx, hy, _critHit);
        _shakeLeft = _critHit ? 14 : 8;
        doVibe(_critHit ? 80 : 50, _critHit ? 250 : 150);
    }

    hidden function chainExplosion(cx, cy) {
        var bwf = _bw.toFloat();
        var chainR = bwf * 4.0;
        for (var j = 0; j < _numBlocks; j++) {
            if (_bhp[j] <= 0) { continue; }
            var bcx = _bx[j] + bwf / 2.0;
            var bcy = _by[j] + bwf / 2.0;
            var dx = cx - bcx;
            var dy = cy - bcy;
            if (dx * dx + dy * dy < chainR * chainR) {
                _bhp[j]--;
                if (_bhp[j] <= 0) {
                    _score += 15;
                    spawnDebris(bcx, bcy, _bkind[j]);
                    if (_bkind[j] == 2) {
                        chainExplosion(bcx, bcy);
                    }
                }
            }
        }
        if (_enemyHp > 0) {
            var edx = cx - _enemyWX;
            var edy = cy - _enemyWY;
            if (edx * edx + edy * edy < chainR * chainR * 1.5) {
                _enemyHp -= 25;
                _score += 25;
            }
        }
        _shakeLeft += 4;
        spawnImpactParticles(cx, cy, false);
    }

    hidden function spawnDebris(wx, wy, kind) {
        for (var i = 0; i < 16; i++) {
            if (_debrisL[i] > 0) { continue; }
            _debrisX[i] = wx;
            _debrisY[i] = wy;
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var s = 0.8 + (Math.rand().abs() % 30).toFloat() / 10.0;
            _debrisVx[i] = s * Math.cos(a);
            _debrisVy[i] = -s * Math.sin(a) - 1.5;
            _debrisL[i] = 15 + Math.rand().abs() % 15;
            if (kind == 2) { _debrisC[i] = 0xFF4422; }
            else if (kind == 1) { _debrisC[i] = 0x7A4E2E; }
            else { _debrisC[i] = 0x778899; }
            break;
        }
    }

    hidden function updateDebris() {
        for (var i = 0; i < 16; i++) {
            if (_debrisL[i] <= 0) { continue; }
            _debrisVy[i] += 0.15;
            _debrisX[i] += _debrisVx[i];
            _debrisY[i] += _debrisVy[i];
            _debrisL[i]--;
        }
    }

    hidden function spawnImpactParticles(wx, wy, crit) {
        var palette;
        if (crit) {
            palette = [0xFFEE44, 0xFFFFFF, 0xFFCC00, 0xFFFFAA, 0xFFAA00, 0xFFDD66];
        } else {
            palette = [0xFF4422, 0xFF8833, 0xFFCC22, 0xFFFF66, 0xFF6622, 0xDD3311];
        }
        for (var i = 0; i < MAX_PARTS; i++) {
            _prtX[i] = wx;
            _prtY[i] = wy;
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var s = 1.5 + (Math.rand().abs() % 60).toFloat() / 6.0;
            _prtVx[i] = s * Math.cos(a);
            _prtVy[i] = -s * Math.sin(a);
            _prtL[i] = 16 + Math.rand().abs() % 20;
            _prtC[i] = palette[Math.rand().abs() % 6];
        }
    }

    hidden function updateParticles() {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_prtL[i] <= 0) { continue; }
            _prtVy[i] += 0.15;
            _prtX[i] += _prtVx[i];
            _prtY[i] += _prtVy[i];
            _prtL[i]--;
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
            _score = 0; _round = 0; _combo = 0; _beatGame = false;
            initRound();
        }
    }

    hidden function launchProjectile() {
        gameState = GS_FLIGHT;
        _projAlive = true;
        _hitEnemyDirect = false;
        _critHit = false;
        _trailIdx = 0;
        _maxAlt = _groundWY;

        var rad = _lockedAngle.toFloat() * 3.14159 / 180.0;
        var speed = 5.0 + _lockedPower.toFloat() * 12.0 / 100.0;
        _vx = speed * Math.cos(rad);
        _vy = -speed * Math.sin(rad);
        _px = _catWX + 30.0 * Math.cos(rad);
        _py = _groundWY - 25.0 - 30.0 * Math.sin(rad);
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

        drawScene(dc, w, h);

        if (_flashTick > 0) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            var fa = _flashTick * 40;
            if (fa > 200) { fa = 200; }
            dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(0, 0, w, h);
            dc.drawRectangle(1, 1, w - 2, h - 2);
        }
    }

    hidden function drawScene(dc, w, h) {
        var ox = _shakeOx;
        var oy = _shakeOy;
        var gsy = w2sy(_groundWY) + oy;

        // sky
        var night = _round >= 5;
        if (night) {
            dc.setColor(0x050818, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w, gsy);
            for (var i = 0; i < 15; i++) {
                var sx = (i * 31 + _tick) % w;
                var sy = (i * 17 + 5) % (gsy > 10 ? gsy - 10 : 10);
                dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(sx, sy, 1, 1);
            }
        } else {
            dc.setColor(0x1A3A6A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w, gsy * 50 / 100);
            dc.setColor(0x2A5A8A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, gsy * 50 / 100, w, gsy * 30 / 100);
            dc.setColor(0x4A7AAA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, gsy * 80 / 100, w, gsy - gsy * 80 / 100);
            // clouds
            for (var i = 0; i < 3; i++) {
                var cx = ((_tick + i * 80) * (i + 1) / 3) % (w + 60) - 30;
                var cy = 15 + i * 12;
                dc.setColor(0xDDE8F0, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx + ox, cy + oy, 8);
                dc.fillCircle(cx + 10 + ox, cy + 2 + oy, 6);
                dc.fillCircle(cx - 8 + ox, cy + 1 + oy, 5);
            }
        }

        // ground
        dc.setColor(0x2A4828, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gsy, w, h - gsy);
        dc.setColor(0x3A6835, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gsy, w, 2);

        // grass
        dc.setColor(0x335530, Graphics.COLOR_TRANSPARENT);
        for (var g = 0; g < w; g += 7) {
            var gh = 3 + (g % 5);
            dc.drawLine(g, gsy + 2, g, gsy + 2 + gh);
        }

        // distance markers on ground
        dc.setColor(0x556655, Graphics.COLOR_TRANSPARENT);
        for (var m = 100; m < _castleWX.toNumber() + 100; m += 100) {
            var mx = w2sx(m.toFloat()) + ox;
            if (mx > 5 && mx < w - 5) {
                dc.fillRectangle(mx, gsy - 3, 1, 6);
                dc.setColor(0x445544, Graphics.COLOR_TRANSPARENT);
                dc.drawText(mx, gsy + 4, Graphics.FONT_XTINY, "" + m, Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(0x556655, Graphics.COLOR_TRANSPARENT);
            }
        }

        // blocks
        var bwf = _bw.toFloat();
        for (var i = 0; i < _numBlocks; i++) {
            if (_bhp[i] <= 0) { continue; }
            var bsx = w2sx(_bx[i]) + ox;
            var bsy = w2sy(_by[i]) + oy;
            var bsw = (_bw.toFloat() * _worldScale).toNumber();
            if (bsw < 3) { bsw = 3; }
            if (bsx > w + 20 || bsx < -20) { continue; }

            var fillC;
            if (_bkind[i] == 2) { fillC = 0xCC2222; }
            else if (_bkind[i] == 1) { fillC = 0x7A4E2E; }
            else { fillC = 0x778899; }
            dc.setColor(fillC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bsx, bsy, bsw, bsw);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(bsx, bsy, bsw, bsw);
            if (_bkind[i] == 1 && _bhp[i] == 1) {
                dc.setColor(0x221100, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(bsx + 1, bsy + 1, bsx + bsw - 1, bsy + bsw - 1);
            }
            if (_bkind[i] == 2) {
                dc.setColor(0xFF6666, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bsx + bsw / 2, bsy + bsw / 2, 2, 2);
            }
        }

        // enemy
        if (_enemyHp > 0) {
            var esx = w2sx(_enemyWX) + ox;
            var esy = w2sy(_enemyWY) + oy;
            var er = (bwf * _worldScale).toNumber();
            if (er < 4) { er = 4; }

            if (gameState == GS_HIT && _hitTick < 10) {
                esx += (_hitTick % 4 < 2) ? 3 : -3;
            }

            dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx, esy, er);
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(esx, esy, er);

            // eyes
            var eo = er / 3;
            if (eo < 2) { eo = 2; }
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx - eo, esy - eo / 2, eo / 2 + 1);
            dc.fillCircle(esx + eo, esy - eo / 2, eo / 2 + 1);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx - eo, esy - eo / 2, eo / 3 + 1);
            dc.fillCircle(esx + eo, esy - eo / 2, eo / 3 + 1);

            // hp bar
            var barW = er * 2;
            dc.setColor(0x440000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - er, esy - er - 5, barW, 3);
            var hw = barW * _enemyHp / _enemyMaxHp;
            if (hw < 0) { hw = 0; }
            dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - er, esy - er - 5, hw, 3);
        }

        // catapult
        var csx = w2sx(_catWX) + ox;
        var csy = w2sy(_groundWY) + oy;
        var catScale = (_worldScale * 10.0).toNumber();
        if (catScale < 4) { catScale = 4; }
        dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(csx - catScale, csy - catScale / 2, catScale * 2, catScale / 2);
        dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(csx - catScale * 2 / 3, csy, catScale / 4);
        dc.fillCircle(csx + catScale * 2 / 3, csy, catScale / 4);

        var suppH = catScale * 2;
        dc.fillRectangle(csx - 1, csy - suppH, 3, suppH - catScale / 2);

        var curAngle = (gameState == GS_ANGLE) ? _angle : _lockedAngle;
        if (gameState == GS_FLIGHT || gameState == GS_HIT) { curAngle = 10; }
        var rad = curAngle.toFloat() * 3.14159 / 180.0;
        var armLen = catScale * 3;
        var tipX = csx + (armLen.toFloat() * Math.cos(rad)).toNumber();
        var tipY = csy - suppH + (-(armLen.toFloat()) * Math.sin(rad)).toNumber();
        dc.setColor(0x886644, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(csx, csy - suppH, tipX, tipY);
        dc.setPenWidth(1);

        if (gameState == GS_ANGLE || gameState == GS_POWER) {
            dc.setColor(_projColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tipX, tipY - 3, 3);
        }

        // trajectory preview
        if (gameState == GS_POWER) {
            var trad = _lockedAngle.toFloat() * 3.14159 / 180.0;
            var tspd = 5.0 + _power.toFloat() * 12.0 / 100.0;
            var tvx = tspd * Math.cos(trad);
            var tvy = -tspd * Math.sin(trad);
            var tx = _catWX + 30.0 * Math.cos(trad);
            var ty = _groundWY - 25.0 - 30.0 * Math.sin(trad);
            dc.setColor(0x334466, Graphics.COLOR_TRANSPARENT);
            for (var t = 0; t < 120; t++) {
                tvx += _wind;
                tvy += 0.28;
                tx += tvx;
                ty += tvy;
                if (ty >= _groundWY || tx > _castleWX + 100.0 || tx < -50.0) { break; }
                if (t % 4 == 0) {
                    dc.fillRectangle(w2sx(tx) + ox, w2sy(ty) + oy, 2, 2);
                }
            }
        }

        // fire trail
        if (_projAlive || (gameState == GS_HIT && _hitTick < 5)) {
            for (var k = 0; k < TRAIL_LEN; k++) {
                var idx = _trailIdx - 1 - k;
                if (idx < 0) { idx += TRAIL_LEN; }
                if (_trailX[idx] == 0.0 && _trailY[idx] == 0.0) { continue; }
                var tsx = w2sx(_trailX[idx]) + ox;
                var tsy = w2sy(_trailY[idx]) + oy;
                var c = (k < 2) ? 0xFFFF44 : ((k < 5) ? 0xFFAA22 : 0xFF6600);
                dc.setColor(c, Graphics.COLOR_TRANSPARENT);
                var sz = 3 - k / 5;
                if (sz < 1) { sz = 1; }
                dc.fillCircle(tsx, tsy, sz);
            }
        }

        // projectile
        if (_projAlive) {
            var psx = w2sx(_px) + ox;
            var psy = w2sy(_py) + oy;
            dc.setColor(_projColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(psx, psy, 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(psx - 1, psy - 2, 1, 1);
            dc.fillRectangle(psx + 1, psy - 2, 1, 1);
            // flame
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(psx - 1, psy + 4, 2, 3);
            dc.setColor(0xFFFF66, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(psx - 2, psy + 3, 1, 2);
            dc.fillRectangle(psx + 2, psy + 3, 1, 2);
        }

        // particles
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_prtL[i] <= 0) { continue; }
            var psx = w2sx(_prtX[i]) + ox;
            var psy = w2sy(_prtY[i]) + oy;
            dc.setColor(_prtC[i], Graphics.COLOR_TRANSPARENT);
            var ps = (_prtL[i] > 12) ? 3 : ((_prtL[i] > 5) ? 2 : 1);
            dc.fillRectangle(psx, psy, ps, ps);
        }

        // debris
        for (var i = 0; i < 16; i++) {
            if (_debrisL[i] <= 0) { continue; }
            var dsx = w2sx(_debrisX[i]) + ox;
            var dsy = w2sy(_debrisY[i]) + oy;
            dc.setColor(_debrisC[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dsx, dsy, 3, 3);
        }

        // HUD
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 3, Graphics.FONT_XTINY, "R" + _round + " " + _enemyName, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 4, 3, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);
        if (_combo > 1) {
            dc.setColor(0xFF66FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 4, 16, Graphics.FONT_XTINY, "x" + _combo, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // wind
        dc.setColor(0xAACCFF, Graphics.COLOR_TRANSPARENT);
        var wt = "W:";
        if (_windDisplay > 0) { wt += ">>"; }
        else if (_windDisplay < 0) { wt += "<<"; }
        else { wt += "--"; }
        dc.drawText(4, 3, Graphics.FONT_XTINY, wt, Graphics.TEXT_JUSTIFY_LEFT);

        // shots
        for (var i = 0; i < _shots; i++) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w / 2 - (_shots - 1) * 7 / 2 + i * 7, h - 10, 3);
        }

        // altitude indicator during flight
        if (gameState == GS_FLIGHT && _projAlive) {
            var alt = (_groundWY - _py).toNumber();
            if (alt < 0) { alt = 0; }
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(4, h - 22, Graphics.FONT_XTINY, "H:" + alt, Graphics.TEXT_JUSTIFY_LEFT);
            var dist = _px.toNumber();
            dc.drawText(4, h - 12, Graphics.FONT_XTINY, "D:" + dist, Graphics.TEXT_JUSTIFY_LEFT);
        }

        // angle/power HUD
        if (gameState == GS_ANGLE) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_SMALL, _angle + "d", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 92 / 100, Graphics.FONT_XTINY, "SET ANGLE", Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (gameState == GS_POWER) {
            var barX = w * 80 / 100;
            var barY = h * 20 / 100;
            var barH = h * 55 / 100;
            dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, 8, barH);
            var fillH = barH * _power / 100;
            var c = (_power > 75) ? 0xFF4422 : ((_power > 40) ? 0xFFCC22 : 0x44FF44);
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY + barH - fillH, 8, fillH);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(barX + 4, barY - 14, Graphics.FONT_XTINY, "" + _power, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 92 / 100, Graphics.FONT_XTINY, "SET POWER", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawReady(dc, w, h) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_MEDIUM, "ROUND " + _round, Graphics.TEXT_JUSTIFY_CENTER);

        var r = w * 12 / 100;
        if (r < 10) { r = 10; }
        var cy = h * 40 / 100;
        dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, cy, r);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var eo = r / 3;
        dc.fillCircle(w / 2 - eo, cy - eo / 2, eo / 2);
        dc.fillCircle(w / 2 + eo, cy - eo / 2, eo / 2);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2 - eo, cy - eo / 2, eo / 4);
        dc.fillCircle(w / 2 + eo, cy - eo / 2, eo / 4);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 55 / 100, Graphics.FONT_SMALL, "vs " + _enemyName, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 66 / 100, Graphics.FONT_XTINY, "HP: " + _enemyMaxHp + "  Dist: " + _castleWX.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCFF, Graphics.COLOR_TRANSPARENT);
        var wl = "Wind: " + ((_windDisplay >= 0) ? "+" : "") + _windDisplay;
        dc.drawText(w / 2, h * 74 / 100, Graphics.FONT_XTINY, wl, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 84 / 100, Graphics.FONT_XTINY, "Press to start", Graphics.TEXT_JUSTIFY_CENTER);
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
            dc.drawText(w / 2, h * 52 / 100, Graphics.FONT_XTINY, _enemyName + " survived", Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY, "Press to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc, w, h) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_MEDIUM, _beatGame ? "YOU WIN!" : "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 35 / 100, Graphics.FONT_MEDIUM, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);
        var grade;
        if (_score >= 3000) { grade = "LEGENDARY!"; }
        else if (_score >= 2000) { grade = "MASTER!"; }
        else if (_score >= 1200) { grade = "GREAT!"; }
        else if (_score >= 600) { grade = "GOOD"; }
        else { grade = "TRY AGAIN"; }
        dc.setColor(0x44FFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 55 / 100, Graphics.FONT_SMALL, grade, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY, "Press to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
