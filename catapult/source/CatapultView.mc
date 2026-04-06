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

const MAX_BLOCKS = 40;
const MAX_PARTS = 20;
const MAX_EXP_QUEUE = 12;
const TRAIL_LEN = 10;
const MAX_CLOUDS = 4;
const MAX_STARS = 24;

// Block type in _bkind: 0 regular, 1 reinforced, 2 explosive
// _bhp: remaining hits

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
    hidden var _bhp;
    hidden var _bkind;
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
    hidden var _prtC;

    hidden var _wind;           // added to vx each flight tick (scaled)
    hidden var _windDisplay;    // -9..9 for HUD arrow

    hidden var _combo;
    hidden var _shakeLeft;
    hidden var _shakeOx;
    hidden var _shakeOy;

    hidden var _hitEnemyDirect;
    hidden var _critThisHit;

    hidden var _cloudX;
    hidden var _cloudY;
    hidden var _cloudSpd;

    hidden var _trailX;
    hidden var _trailY;
    hidden var _trailIdx;

    hidden var _starX;
    hidden var _starY;
    hidden var _starTw;

    hidden var _eqX;
    hidden var _eqY;
    hidden var _eqN;

    hidden var _resultTick;
    hidden var _victoryFanfare;
    hidden var _beatGame;

    hidden var _dmgMult;
    hidden var _shotDealtDamage;

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
        _bhp = new [MAX_BLOCKS];
        _bkind = new [MAX_BLOCKS];
        _prtX = new [MAX_PARTS];
        _prtY = new [MAX_PARTS];
        _prtVx = new [MAX_PARTS];
        _prtVy = new [MAX_PARTS];
        _prtL = new [MAX_PARTS];
        _prtC = new [MAX_PARTS];
        _eqX = new [MAX_EXP_QUEUE];
        _eqY = new [MAX_EXP_QUEUE];
        _trailX = new [TRAIL_LEN];
        _trailY = new [TRAIL_LEN];
        _cloudX = new [MAX_CLOUDS];
        _cloudY = new [MAX_CLOUDS];
        _cloudSpd = new [MAX_CLOUDS];
        _starX = new [MAX_STARS];
        _starY = new [MAX_STARS];
        _starTw = new [MAX_STARS];

        for (var i = 0; i < MAX_PARTS; i++) { _prtL[i] = 0; }

        var ci;
        for (ci = 0; ci < MAX_CLOUDS; ci++) {
            _cloudX[ci] = (Math.rand().abs() % _w).toFloat();
            _cloudY[ci] = (8 + Math.rand().abs() % (_h / 5)).toFloat();
            _cloudSpd[ci] = 0.15 + (Math.rand().abs() % 20).toFloat() / 80.0;
        }

        var si;
        for (si = 0; si < MAX_STARS; si++) {
            _starX[si] = Math.rand().abs() % _w;
            _starY[si] = Math.rand().abs() % (_groundY - 10);
            _starTw[si] = Math.rand().abs() % 40;
        }

        _score = 0;
        _round = 0;
        _tick = 0;
        _numBlocks = 0;
        _combo = 0;
        _beatGame = false;
        _resultTick = 0;
        initRound();
    }

    hidden function rollWind() as Void {
        _windDisplay = (Math.rand().abs() % 19) - 9;
        _wind = _windDisplay.toFloat() * 0.055;
    }

    hidden function initRound() as Void {
        _round++;
        _shots = 4;
        gameState = GS_READY;
        rollWind();

        if (_round == 1) {
            _enemyName = "Blobby";
            _enemyColor = 0x33DD66;
            _enemyMaxHp = 45;
        } else if (_round == 2) {
            _enemyName = "Chikko";
            _enemyColor = 0xFFCC22;
            _enemyMaxHp = 70;
        } else if (_round == 3) {
            _enemyName = "Dzikko";
            _enemyColor = 0x886644;
            _enemyMaxHp = 100;
        } else if (_round == 4) {
            _enemyName = "Rocky";
            _enemyColor = 0x889999;
            _enemyMaxHp = 140;
        } else if (_round == 5) {
            _enemyName = "Vexor";
            _enemyColor = 0xDD2222;
            _enemyMaxHp = 185;
        } else if (_round == 6) {
            _enemyName = "Emilka";
            _enemyColor = 0xCC66DD;
            _enemyMaxHp = 220;
        } else {
            _enemyName = "Batsy";
            _enemyColor = 0x5533AA;
            _enemyMaxHp = 265;
        }
        _enemyHp = _enemyMaxHp;

        buildCastle();
        resetShot();
    }

    hidden function addBlock(cx, cy, kind) as Void {
        if (_numBlocks >= MAX_BLOCKS) { return; }
        _bx[_numBlocks] = cx;
        _by[_numBlocks] = cy;
        _bkind[_numBlocks] = kind;
        if (kind == 1) {
            _bhp[_numBlocks] = 2;
        } else {
            _bhp[_numBlocks] = 1;
        }
        _numBlocks++;
    }

    hidden function buildCastle() as Void {
        var castleCx = _w * 73 / 100;
        _numBlocks = 0;

        var tier = _round;
        if (tier > 7) { tier = 7; }

        var towerW = 2 + tier / 3;
        if (towerW > 3) { towerW = 3; }
        var wallRows = 2 + (tier / 2);
        if (wallRows > 4) { wallRows = 4; }
        var archGap = 1;

        var leftX = castleCx - (_bw * (towerW + 2 + archGap + towerW)) / 2;
        var tx;
        var ty;
        var row;
        var col;
        var r;

        // Left tower
        for (col = 0; col < towerW; col++) {
            for (row = 0; row < wallRows + 1; row++) {
                tx = leftX + col * _bw;
                ty = _groundY - (row + 1) * _bh;
                r = Math.rand().abs() % 100;
                if (r < 12) {
                    addBlock(tx, ty, 2);
                } else if (r < 28) {
                    addBlock(tx, ty, 1);
                } else {
                    addBlock(tx, ty, 0);
                }
            }
        }

        // Right tower
        var rightBase = leftX + (towerW + 2 + archGap) * _bw;
        for (col = 0; col < towerW; col++) {
            for (row = 0; row < wallRows + 1; row++) {
                tx = rightBase + col * _bw;
                ty = _groundY - (row + 1) * _bh;
                r = Math.rand().abs() % 100;
                if (r < 12) {
                    addBlock(tx, ty, 2);
                } else if (r < 28) {
                    addBlock(tx, ty, 1);
                } else {
                    addBlock(tx, ty, 0);
                }
            }
        }

        // Arch / wall bridge (middle columns, skip arch row for gap)
        var midX = leftX + towerW * _bw;
        var archRow = wallRows - 1;
        if (archRow < 1) { archRow = 1; }
        for (col = 0; col < 2 + archGap; col++) {
            for (row = 0; row < wallRows; row++) {
                if (col > 0 && col < 1 + archGap && row == archRow - 1) {
                    continue;
                }
                tx = midX + col * _bw;
                ty = _groundY - (row + 1) * _bh;
                r = Math.rand().abs() % 100;
                if (r < 10) {
                    addBlock(tx, ty, 2);
                } else if (r < 35) {
                    addBlock(tx, ty, 1);
                } else {
                    addBlock(tx, ty, 0);
                }
            }
        }

        // Extra wall crest on higher rounds
        if (tier >= 4) {
            var crestW = 3 + (tier / 2);
            if (crestW > 6) { crestW = 6; }
            var crestX = castleCx - (crestW * _bw) / 2;
            var crestY = _groundY - (wallRows + 2) * _bh;
            for (col = 0; col < crestW; col++) {
                r = Math.rand().abs() % 100;
                if (r < 15) {
                    addBlock(crestX + col * _bw, crestY, 2);
                } else if (r < 40) {
                    addBlock(crestX + col * _bw, crestY, 1);
                } else {
                    addBlock(crestX + col * _bw, crestY, 0);
                }
            }
        }

        _enemyX = castleCx;
        _enemyY = _groundY - (wallRows + 2) * _bh - _bw;
    }

    hidden function resetShot() as Void {
        _angle = 45;
        _angleDir = 1;
        _power = 50;
        _powerDir = 1;
        _lockedAngle = 45;
        _lockedPower = 50;
        _projAlive = false;
        _hitTick = 0;
        _hitEnemyDirect = false;
        _critThisHit = false;
        _px = 0.0;
        _py = 0.0;
        _vx = 0.0;
        _vy = 0.0;
        _shakeLeft = 0;
        _shakeOx = 0;
        _shakeOy = 0;
        _trailIdx = 0;
        var ti;
        for (ti = 0; ti < TRAIL_LEN; ti++) {
            _trailX[ti] = 0;
            _trailY[ti] = 0;
        }

        var i;
        for (i = 0; i < MAX_PARTS; i++) { _prtL[i] = 0; }

        var colors = [0x33DD66, 0xFF4422, 0x3388FF, 0xFFCC22, 0xFF44FF, 0x44FFFF, 0xFF8833, 0xDD33FF];
        _projColor = colors[Math.rand().abs() % 8];
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 40, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    hidden function startScreenShake(frames) as Void {
        if (frames > _shakeLeft) {
            _shakeLeft = frames;
        }
    }

    hidden function updateShake() as Void {
        if (_shakeLeft > 0) {
            _shakeOx = (Math.rand().abs() % 7) - 3;
            _shakeOy = (Math.rand().abs() % 5) - 2;
            _shakeLeft--;
        } else {
            _shakeOx = 0;
            _shakeOy = 0;
        }
    }

    function onTick() as Void {
        _tick++;

        if (gameState == GS_RESULT || (gameState == GS_GAMEOVER && _beatGame)) {
            _resultTick++;
        }

        updateShake();

        if (gameState == GS_ANGLE) {
            _angle += _angleDir * 2;
            if (_angle >= 75) {
                _angle = 75;
                _angleDir = -1;
            }
            if (_angle <= 20) {
                _angle = 20;
                _angleDir = 1;
            }
        } else if (gameState == GS_POWER) {
            _power += _powerDir * 3;
            if (_power >= 100) {
                _power = 100;
                _powerDir = -1;
            }
            if (_power <= 5) {
                _power = 5;
                _powerDir = 1;
            }
        } else if (gameState == GS_FLIGHT) {
            updateFlight();
        } else if (gameState == GS_HIT) {
            _hitTick++;
            updateParticles();
            if (_hitTick >= 28) {
                if (_enemyHp <= 0) {
                    _victoryFanfare = true;
                    _beatGame = (_round >= 7);
                    _score += 100 + _shots * 40;
                    gameState = (_round >= 7) ? GS_GAMEOVER : GS_RESULT;
                    _resultTick = 0;
                } else if (_shots <= 0) {
                    _victoryFanfare = false;
                    _beatGame = false;
                    gameState = (_round >= 7) ? GS_GAMEOVER : GS_RESULT;
                    _resultTick = 0;
                } else {
                    resetShot();
                    gameState = GS_ANGLE;
                }
            }
        }

        WatchUi.requestUpdate();
    }

    hidden function pushTrail() as Void {
        _trailX[_trailIdx] = _px.toNumber();
        _trailY[_trailIdx] = _py.toNumber();
        _trailIdx++;
        if (_trailIdx >= TRAIL_LEN) {
            _trailIdx = 0;
        }
    }

    hidden function updateFlight() as Void {
        if (!_projAlive) {
            return;
        }

        _vx = _vx + _wind;
        _vy = _vy + 0.35;
        _px = _px + _vx;
        _py = _py + _vy;

        pushTrail();

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
        var i;
        for (i = 0; i < _numBlocks; i++) {
            if (_bhp[i] <= 0) {
                continue;
            }
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
                if (dmg < 10) {
                    dmg = 10;
                }
                dmg = dmg * 2;
                _enemyHp -= dmg;
                _hitEnemyDirect = true;
                _critThisHit = true;
                var mult = comboMult();
                _score += (dmg * mult) / 10;
                doHit(ipx, ipy);
                return;
            }
        }
    }

    hidden function comboMult() {
        var c = _combo;
        if (c > 8) {
            c = 8;
        }
        return 10 + c * 3;
    }

    hidden function doVibeImpulse(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }

    hidden function blocksAdjacent(i, j) {
        var ax = _bx[i] + _bw / 2;
        var ay = _by[i] + _bh / 2;
        var bx = _bx[j] + _bw / 2;
        var by = _by[j] + _bh / 2;
        var dx = ax - bx;
        if (dx < 0) {
            dx = -dx;
        }
        var dy = ay - by;
        if (dy < 0) {
            dy = -dy;
        }
        return dx < _bw * 12 / 10 && dy < _bh * 12 / 10 && i != j;
    }

    hidden function applyBlockDamage(i) {
        if (_bhp[i] <= 0) {
            return false;
        }
        _bhp[i] = _bhp[i] - 1;
        _shotDealtDamage = true;
        if (_bhp[i] > 0) {
            return false;
        }

        var basePts = 12;
        if (_bkind[i] == 1) {
            basePts = 18;
        } else if (_bkind[i] == 2) {
            basePts = 22;
        }
        _score += (basePts * _dmgMult) / 10;

        if (_bkind[i] == 2) {
            var bcx = _bx[i] + _bw / 2;
            var bcy = _by[i] + _bh / 2;
            enqueueExplosion(bcx, bcy);
        }
        return true;
    }

    hidden function enqueueExplosion(cx, cy) as Void {
        if (_eqN >= MAX_EXP_QUEUE) {
            return;
        }
        _eqX[_eqN] = cx;
        _eqY[_eqN] = cy;
        _eqN++;
    }

    hidden function splashAt(hx, hy, radius, isExplosive) as Void {
        var splR = radius;
        var i;
        for (i = 0; i < _numBlocks; i++) {
            if (_bhp[i] <= 0) {
                continue;
            }
            var bcx = _bx[i] + _bw / 2;
            var bcy = _by[i] + _bh / 2;
            var ddx = hx - bcx;
            var ddy = hy - bcy;
            if (ddx * ddx + ddy * ddy < splR * splR) {
                applyBlockDamage(i);
            }
        }

        if (_enemyHp > 0 && !_hitEnemyDirect) {
            var edx = hx - _enemyX;
            var edy = hy - _enemyY;
            var er2 = splR * splR * 2;
            if (isExplosive) {
                er2 = splR * splR * 3;
            }
            if (edx * edx + edy * edy < er2) {
                var edmg = isExplosive ? 22 : 15;
                _enemyHp -= edmg;
                _score += (edmg * _dmgMult) / 10;
                _shotDealtDamage = true;
            }
        }
    }

    hidden function chainNeighborsOfDestroyed(justDead) as Void {
        var j;
        var k;
        for (j = 0; j < _numBlocks; j++) {
            if (_bhp[j] <= 0) {
                continue;
            }
            if (!blocksAdjacent(justDead, j)) {
                continue;
            }
            var roll = Math.rand().abs() % 100;
            if (roll < 55) {
                var was = _bhp[j];
                applyBlockDamage(j);
                if (was > 0 && _bhp[j] <= 0) {
                    for (k = 0; k < _numBlocks; k++) {
                        if (_bhp[k] > 0 && blocksAdjacent(j, k)) {
                            var roll2 = Math.rand().abs() % 100;
                            if (roll2 < 40) {
                                applyBlockDamage(k);
                            }
                        }
                    }
                }
            }
        }
    }

    hidden function processExplosionWaves() as Void {
        var guard = 0;
        while (_eqN > 0 && guard < 14) {
            guard++;
            _eqN--;
            var ex = _eqX[_eqN];
            var ey = _eqY[_eqN];
            var er = (_bw * 22) / 10;
            splashAt(ex, ey, er, true);
            startScreenShake(6);
            if (guard == 1) {
                doVibeImpulse(45, 90);
            }
        }
    }

    hidden function runChainAfterSplash(hx, hy, splR) as Void {
        var pass = 0;
        var changed = true;
        while (changed && pass < 8) {
            pass++;
            changed = false;
            var i;
            var j;
            for (i = 0; i < _numBlocks; i++) {
                if (_bhp[i] > 0) {
                    continue;
                }
                for (j = 0; j < _numBlocks; j++) {
                    if (i == j || _bhp[j] <= 0) {
                        continue;
                    }
                    if (!blocksAdjacent(i, j)) {
                        continue;
                    }
                    var bcx = _bx[j] + _bw / 2;
                    var bcy = _by[j] + _bh / 2;
                    var ddx = hx - bcx;
                    var ddy = hy - bcy;
                    if (ddx * ddx + ddy * ddy < splR * splR) {
                        continue;
                    }
                    var roll = Math.rand().abs() % 100;
                    if (roll < 45) {
                        if (applyBlockDamage(j)) {
                            chainNeighborsOfDestroyed(j);
                            changed = true;
                        }
                    }
                }
            }
        }
    }

    hidden function doHit(hx, hy) as Void {
        _projAlive = false;
        _shots--;
        gameState = GS_HIT;
        _hitTick = 0;
        _eqN = 0;
        _dmgMult = comboMult();
        _shotDealtDamage = false;

        var splR = (_bw * 24) / 10;

        splashAt(hx, hy, splR, false);
        processExplosionWaves();

        runChainAfterSplash(hx, hy, splR);
        processExplosionWaves();

        var hadDamage = _hitEnemyDirect || _shotDealtDamage;

        if (hadDamage) {
            _combo++;
        } else {
            _combo = 0;
        }

        if (_critThisHit) {
            spawnCritParticles(hx, hy);
        } else {
            spawnParticles(hx, hy);
        }

        startScreenShake(10);
        if (_critThisHit) {
            doVibeImpulse(80, 160);
        } else {
            doVibeImpulse(55, 200);
        }
    }

    hidden function spawnParticles(x, y) as Void {
        var palette = [0xFF4422, 0xFF8833, 0xFFCC22, 0xFFFF66, 0xFF6622, 0xDD3311, 0xAA2200, 0xFFAA44];
        var i;
        for (i = 0; i < MAX_PARTS; i++) {
            _prtX[i] = x.toFloat();
            _prtY[i] = y.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var s = 1.2 + (Math.rand().abs() % 80).toFloat() / 8.0;
            _prtVx[i] = s * Math.cos(a);
            _prtVy[i] = -s * Math.sin(a);
            _prtL[i] = 14 + Math.rand().abs() % 18;
            _prtC[i] = palette[Math.rand().abs() % 8];
        }
    }

    hidden function spawnCritParticles(x, y) as Void {
        var palette = [0xFFEE44, 0xFFFFFF, 0xFFCC00, 0xFFFFAA, 0xFFAA00, 0xFFDD66];
        var i;
        for (i = 0; i < MAX_PARTS; i++) {
            _prtX[i] = x.toFloat();
            _prtY[i] = y.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var s = 1.8 + (Math.rand().abs() % 100).toFloat() / 7.0;
            _prtVx[i] = s * Math.cos(a);
            _prtVy[i] = -s * Math.sin(a);
            _prtL[i] = 20 + Math.rand().abs() % 22;
            _prtC[i] = palette[Math.rand().abs() % 6];
        }
    }

    hidden function updateParticles() as Void {
        var i;
        for (i = 0; i < MAX_PARTS; i++) {
            if (_prtL[i] <= 0) {
                continue;
            }
            _prtX[i] = _prtX[i] + _prtVx[i];
            _prtY[i] = _prtY[i] + _prtVy[i] + 0.22;
            _prtL[i] = _prtL[i] - 1;
        }
    }

    function doAction() as Void {
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
            _combo = 0;
            _beatGame = false;
            initRound();
        }
    }

    hidden function launchProjectile() as Void {
        gameState = GS_FLIGHT;
        _projAlive = true;
        _hitEnemyDirect = false;
        _critThisHit = false;
        _trailIdx = 0;

        var rad = _lockedAngle.toFloat() * 3.14159 / 180.0;
        var speed = 3.5 + _lockedPower.toFloat() * 8.5 / 100.0;
        _vx = speed * Math.cos(rad);
        _vy = -speed * Math.sin(rad);
        _px = _catX.toFloat() + _armLen.toFloat() * Math.cos(rad);
        _py = _pivotY.toFloat() - _armLen.toFloat() * Math.sin(rad);
    }

    hidden function drawSky(dc, w, h) as Void {
        var night = _round >= 5;
        if (night) {
            dc.setColor(0x050818, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w, _groundY);
            var si;
            for (si = 0; si < MAX_STARS; si++) {
                var tw = ((_tick + _starTw[si]) % 50);
                if (tw > 35) {
                    dc.setColor(0xE0E8FF, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(_starX[si], _starY[si], 1, 1);
                } else if (tw > 20) {
                    dc.setColor(0x8899CC, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(_starX[si], _starY[si], 1, 1);
                }
            }
        } else {
            dc.setColor(0x1A3A6A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w, _groundY * 55 / 100);
            dc.setColor(0x2A5A8A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, _groundY * 55 / 100, w, _groundY * 25 / 100);
            dc.setColor(0x4A7AAA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, _groundY * 80 / 100, w, _groundY - _groundY * 80 / 100);
        }

        var ci;
        for (ci = 0; ci < MAX_CLOUDS; ci++) {
            _cloudX[ci] = _cloudX[ci] + _cloudSpd[ci];
            if (_cloudX[ci] > w + 40) {
                _cloudX[ci] = -40.0;
            }
            var cx = _cloudX[ci].toNumber();
            var cy = _cloudY[ci].toNumber();
            if (!night) {
                dc.setColor(0xDDE8F0, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx, cy, 10);
                dc.fillCircle(cx + 12, cy + 2, 8);
                dc.fillCircle(cx - 10, cy + 2, 7);
            }
        }
    }

    hidden function drawGround(dc, w, h) as Void {
        drawSky(dc, w, h);

        dc.setColor(0x2A4828, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _groundY, w, h - _groundY);
        dc.setColor(0x3A6835, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _groundY, w, 2);

        var gx = (_tick * 2) % 7;
        var g;
        for (g = gx; g < w; g += 9) {
            dc.setColor(0x335530, Graphics.COLOR_TRANSPARENT);
            var gh = 4 + (g % 5);
            dc.drawLine(g, _groundY + 3, g, _groundY + 3 + gh);
        }
    }

    hidden function drawBlocks(dc, w, h) as Void {
        var i;
        for (i = 0; i < _numBlocks; i++) {
            if (_bhp[i] <= 0) {
                continue;
            }
            var fillC;
            var edgeC;
            if (_bkind[i] == 2) {
                fillC = 0xCC2222;
                edgeC = 0x880000;
            } else if (_bkind[i] == 1) {
                fillC = 0x7A4E2E;
                edgeC = 0x4A3018;
            } else {
                fillC = 0x778899;
                edgeC = 0x445566;
            }
            dc.setColor(fillC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_bx[i], _by[i], _bw, _bh);
            dc.setColor(edgeC, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(_bx[i], _by[i], _bw, _bh);
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(_bx[i] + _bw / 3, _by[i], _bx[i] + _bw / 2, _by[i] + _bh);
            if (_bkind[i] == 1 && _bhp[i] == 1) {
                dc.setColor(0x221100, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(_bx[i] + 2, _by[i] + 2, _bx[i] + _bw - 2, _by[i] + _bh - 2);
            }
            if (_bkind[i] == 2) {
                dc.setColor(0xFF6666, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_bx[i] + _bw / 2 - 1, _by[i] + _bh / 2 - 1, 2, 2);
            }
        }
    }

    hidden function drawEnemySprite(dc, w, h) as Void {
        if (_enemyHp <= 0) {
            return;
        }

        var r = _bw;
        var shake = 0;
        if (gameState == GS_HIT && _hitTick < 12) {
            shake = (_hitTick % 4 < 2) ? 3 : -3;
        }
        var ex = _enemyX + shake + _shakeOx;
        var ey = _enemyY + _shakeOy;

        var lowHp = (_enemyHp * 4 < _enemyMaxHp);
        var angry = (gameState == GS_HIT && _hitTick < 14);

        dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex, ey, r);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ex, ey, r);

        var eo = r / 3;
        var ep = r > 8 ? r / 5 : 2;
        if (lowHp && !angry) {
            eo = r / 4;
            ep = r > 8 ? r / 4 : 2;
        }

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex - eo, ey - eo / 2, ep);
        dc.fillCircle(ex + eo, ey - eo / 2, ep);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        var pp = ep > 2 ? ep / 2 : 1;
        var pox = angry ? 1 : 0;
        dc.fillCircle(ex - eo + pox, ey - eo / 2, pp);
        dc.fillCircle(ex + eo + pox, ey - eo / 2, pp);

        if (angry) {
            dc.setColor(0x330000, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(ex - eo - 1, ey - eo, ex - eo / 2, ey - eo - 1);
            dc.drawLine(ex + eo / 2, ey - eo - 1, ex + eo + 1, ey - eo);
        }

        if (lowHp && !angry) {
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(ex, ey + eo / 2, ep / 2);
        } else if (r > 6 && !lowHp) {
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ex - eo, ey + eo / 2, eo * 2, 2);
        }

        var barW = r * 2;
        var barX = _enemyX - r;
        var barY2 = _enemyY - r - 6;
        dc.setColor(0x440000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY2, barW, 3);
        var hw = barW * _enemyHp / _enemyMaxHp;
        if (hw < 0) {
            hw = 0;
        }
        dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY2, hw, 3);
    }

    hidden function drawCatapultSprite(dc, w, h) as Void {
        var baseW = _w * 8 / 100;
        if (baseW < 10) {
            baseW = 10;
        }
        var baseH = _w * 3 / 100;
        if (baseH < 4) {
            baseH = 4;
        }

        var ox = _shakeOx;
        var oy = _shakeOy;

        dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_catX - baseW / 2 + ox, _groundY - baseH, baseW, baseH);

        dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
        var whl = baseH / 2;
        if (whl < 2) {
            whl = 2;
        }
        dc.fillCircle(_catX - baseW / 3 + ox, _groundY, whl);
        dc.fillCircle(_catX + baseW / 3 + ox, _groundY, whl);

        var sw = _w * 2 / 100;
        if (sw < 3) {
            sw = 3;
        }
        dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_catX - sw / 2 + ox, _pivotY + oy, sw, _groundY - baseH - _pivotY);

        var curAngle = (gameState == GS_ANGLE) ? _angle : _lockedAngle;
        if (gameState == GS_FLIGHT || gameState == GS_HIT) {
            curAngle = 10;
        }
        var rad = curAngle.toFloat() * 3.14159 / 180.0;
        var tipX = _catX + (_armLen.toFloat() * Math.cos(rad)).toNumber() + ox;
        var tipY = _pivotY - (_armLen.toFloat() * Math.sin(rad)).toNumber() + oy;

        dc.setColor(0x886644, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(_catX + ox, _pivotY + oy, tipX, tipY);
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

    hidden function simTrajectoryWind(dc, tvx, tvy, tx, ty, w) as Void {
        var simVy = tvy;
        var simX = tx;
        var simY = ty;
        var wind = _wind;
        var simVx = tvx;
        var t;
        for (t = 0; t < 90; t++) {
            simVx = simVx + wind;
            simVy = simVy + 0.35;
            simX = simX + simVx;
            simY = simY + simVy;
            if (simY >= _groundY.toFloat() || simX >= w.toFloat() || simX < 0.0) {
                break;
            }
            if (t % 3 == 0) {
                dc.setColor(0x334466, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(simX.toNumber(), simY.toNumber(), 2, 2);
            }
        }
    }

    hidden function drawTrajectory(dc, w, h) as Void {
        var rad = _lockedAngle.toFloat() * 3.14159 / 180.0;
        var speed = 3.5 + _power.toFloat() * 8.5 / 100.0;
        var tvx = speed * Math.cos(rad);
        var tvy = -speed * Math.sin(rad);
        var tx = _catX.toFloat() + _armLen.toFloat() * Math.cos(rad);
        var ty = _pivotY.toFloat() - _armLen.toFloat() * Math.sin(rad);
        simTrajectoryWind(dc, tvx, tvy, tx, ty, w);
    }

    hidden function drawFireTrail(dc) as Void {
        var k;
        var count = 0;
        for (k = 0; k < TRAIL_LEN; k++) {
            var idx = _trailIdx - 1 - k;
            while (idx < 0) {
                idx = idx + TRAIL_LEN;
            }
            if (_trailX[idx] == 0 && _trailY[idx] == 0 && k > 2) {
                continue;
            }
            var alpha = TRAIL_LEN - k;
            var sz = 2 + k / 4;
            if (sz > 5) {
                sz = 5;
            }
            var c = 0xFF6600;
            if (k < 2) {
                c = 0xFFFF44;
            } else if (k < 5) {
                c = 0xFFAA22;
            }
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_trailX[idx] + _shakeOx, _trailY[idx] + _shakeOy, sz);
            count++;
            if (count > 8) {
                break;
            }
        }
    }

    hidden function drawProj(dc) as Void {
        var x = _px.toNumber() + _shakeOx;
        var y = _py.toNumber() + _shakeOy;
        drawFireTrail(dc);

        dc.setColor(_projColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 5);
        dc.setColor(0xFF3300, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 3);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 2, y - 2, 1, 1);
        dc.fillRectangle(x + 1, y - 2, 1, 1);

        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 1, y + 5, 2, 4);
        dc.setColor(0xFFFF66, Graphics.COLOR_TRANSPARENT);
        if (_vy > -0.5) {
            dc.fillRectangle(x - 3, y + 4, 2, 3);
            dc.fillRectangle(x + 2, y + 4, 2, 3);
        }
    }

    hidden function drawParticlesFx(dc) as Void {
        var i;
        for (i = 0; i < MAX_PARTS; i++) {
            if (_prtL[i] <= 0) {
                continue;
            }
            dc.setColor(_prtC[i], Graphics.COLOR_TRANSPARENT);
            var ps = 2;
            if (_prtL[i] > 12) {
                ps = 4;
            } else if (_prtL[i] > 6) {
                ps = 3;
            }
            dc.fillRectangle(_prtX[i].toNumber() + _shakeOx, _prtY[i].toNumber() + _shakeOy, ps, ps);
        }
    }

    hidden function drawWindHud(dc, w, h) as Void {
        var ty = h * 8 / 100;
        dc.setColor(0xAACCFF, Graphics.COLOR_TRANSPARENT);
        var label = "WIND ";
        if (_windDisplay == 0) {
            label += "calm";
        } else if (_windDisplay > 0) {
            label += ">>";
            var a;
            var maxa = _windDisplay;
            if (maxa > 5) {
                maxa = 5;
            }
            for (a = 0; a < maxa; a++) {
                label += ">";
            }
        } else {
            label += "<<";
            var b;
            var maxb = -_windDisplay;
            if (maxb > 5) {
                maxb = 5;
            }
            for (b = 0; b < maxb; b++) {
                label += "<";
            }
        }
        dc.drawText(4, ty, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);

        var cx = w / 2;
        var cy = ty + 8;
        dc.setColor(0x666688, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 18, cy, cx + 18, cy);
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        if (_windDisplay > 0) {
            dc.drawLine(cx + 4, cy, cx + 14, cy - 4);
            dc.drawLine(cx + 4, cy, cx + 14, cy + 4);
            dc.drawLine(cx + 14, cy - 4, cx + 14, cy + 4);
        } else if (_windDisplay < 0) {
            dc.drawLine(cx - 4, cy, cx - 14, cy - 4);
            dc.drawLine(cx - 4, cy, cx - 14, cy + 4);
            dc.drawLine(cx - 14, cy - 4, cx - 14, cy + 4);
        } else {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, 2);
        }
    }

    hidden function drawHud(dc, w, h) as Void {
        drawWindHud(dc, w, h);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 3, Graphics.FONT_XTINY, "R" + _round + " vs " + _enemyName, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 5, h * 14 / 100, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);

        if (_combo > 1) {
            dc.setColor(0xFF66FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 5, h * 20 / 100, Graphics.FONT_XTINY, "x" + _combo + " COMBO", Graphics.TEXT_JUSTIFY_RIGHT);
        }

        var i;
        for (i = 0; i < _shots; i++) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w / 2 - (_shots - 1) * 8 / 2 + i * 8, h * 92 / 100, 3);
        }
    }

    hidden function drawAngleHud(dc, w, h) as Void {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_catX + _armLen + 5, _pivotY - _armLen, Graphics.FONT_XTINY, _angle + "d", Graphics.TEXT_JUSTIFY_LEFT);

        var angMin = 20;
        var angMax = 75;
        var barX = w * 55 / 100;
        var barY = h * 72 / 100;
        var barW = w * 40 / 100;
        var segH = 4;
        var segCols = [0x22DD44, 0x33CC44, 0x55BB33, 0x88AA22, 0xBB9900, 0xDD7722, 0xEE5522, 0xFF4422, 0xFF3322, 0xFF2222, 0xFF1111, 0xEE0000];
        var s;
        for (s = 0; s < 12; s++) {
            dc.setColor(segCols[s], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX + s * barW / 12, barY, barW / 12 - 1, segH);
        }

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(barX, barY, barW, segH);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        var crad = _angle.toFloat() * 3.14159 / 180.0;
        var mx = _catX + (22.0 * Math.cos(crad)).toNumber();
        var my = _pivotY - (22.0 * Math.sin(crad)).toNumber();
        dc.fillCircle(mx, my, 3);

        dc.setColor(0x444466, Graphics.COLOR_TRANSPARENT);
        var a;
        for (a = angMin; a <= angMax; a += 5) {
            var rad = a.toFloat() * 3.14159 / 180.0;
            var ax = _catX + (20.0 * Math.cos(rad)).toNumber();
            var ay = _pivotY - (20.0 * Math.sin(rad)).toNumber();
            dc.fillRectangle(ax, ay, 2, 2);
        }

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 85 / 100, Graphics.FONT_XTINY, "SET ANGLE", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawPowerHud(dc, w, h) as Void {
        var barX = 5;
        var barY = h * 22 / 100;
        var barH = h * 52 / 100;
        var barW = 10;
        var segs = 16;
        var powCols = [0x228844, 0x339944, 0x44AA44, 0x55BB44, 0x66CC33, 0x88CC22, 0xAABB11, 0xCCAA00, 0xDD8800, 0xEE6600, 0xFF4400, 0xFF3300, 0xFF2200, 0xEE1100, 0xDD0000, 0xCC0000];
        var seg;
        for (seg = 0; seg < segs; seg++) {
            dc.setColor(powCols[seg], Graphics.COLOR_TRANSPARENT);
            var y0 = barY + barH - (seg + 1) * barH / segs;
            dc.fillRectangle(barX, y0, barW, barH / segs - 1);
        }

        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(barX - 1, barY - 1, barW + 2, barH + 2);

        var fillTop = barY + barH - barH * _power / 100;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(barX - 4, fillTop, barX + barW + 4, fillTop);
        dc.setPenWidth(1);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barX + barW / 2, barY - 14, Graphics.FONT_XTINY, "" + _power, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 85 / 100, Graphics.FONT_XTINY, "SET POWER", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawVictorySparkles(dc, w, h) as Void {
        var n = 20;
        var i;
        for (i = 0; i < n; i++) {
            var ang = (i * 360 / n + _resultTick * 6) % 360;
            var rad = ang.toFloat() * 3.14159 / 180.0;
            var rr = w / 2 - 8;
            var pulse = ((_resultTick + i * 3) % 16);
            if (pulse > 8) {
                pulse = 16 - pulse;
            }
            var radR = (rr + pulse).toFloat();
            var px = w / 2 + (radR * Math.cos(rad)).toNumber();
            var py = h / 2 + (radR * Math.sin(rad)).toNumber();
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px, py, 2, 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + 1, py - 1, 1, 1);
        }
    }

    function onUpdate(dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x0A0A1A, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        if (gameState == GS_READY) {
            drawReady(dc, w, h);
            return;
        }
        if (gameState == GS_GAMEOVER) {
            drawGameOver(dc, w, h);
            return;
        }
        if (gameState == GS_RESULT) {
            drawResult(dc, w, h);
            return;
        }

        drawGround(dc, w, h);
        drawBlocks(dc, w, h);
        drawEnemySprite(dc, w, h);
        drawCatapultSprite(dc, w, h);

        if (gameState == GS_POWER) {
            drawTrajectory(dc, w, h);
        }
        if (_projAlive) {
            drawProj(dc);
        }

        drawParticlesFx(dc);
        drawHud(dc, w, h);

        if (gameState == GS_ANGLE) {
            drawAngleHud(dc, w, h);
        }
        if (gameState == GS_POWER) {
            drawPowerHud(dc, w, h);
        }
    }

    hidden function drawReady(dc, w, h) as Void {
        drawSky(dc, w, h);
        dc.setColor(0x2A4828, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _groundY, w, h - _groundY);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_MEDIUM, "ROUND " + _round, Graphics.TEXT_JUSTIFY_CENTER);

        var r = w * 12 / 100;
        if (r < 10) {
            r = 10;
        }
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

        dc.setColor(0xAACCFF, Graphics.COLOR_TRANSPARENT);
        var wtxt = "Wind: ";
        if (_windDisplay >= 0) {
            wtxt += "+";
        }
        wtxt += _windDisplay;
        dc.drawText(w / 2, h * 76 / 100, Graphics.FONT_XTINY, wtxt, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 84 / 100, Graphics.FONT_XTINY, "Press to start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawResult(dc, w, h) as Void {
        var cleared = _enemyHp <= 0;

        dc.setColor(0x0A0A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h);

        if (cleared && _victoryFanfare) {
            drawVictorySparkles(dc, w, h);
        }

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

        if (_round < 7) {
            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 64 / 100, Graphics.FONT_XTINY, "Next: Round " + (_round + 1), Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY, "Press to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc, w, h) as Void {
        if (_beatGame) {
            drawVictorySparkles(dc, w, h);
        }

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        if (_beatGame) {
            dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_MEDIUM, "YOU WIN!", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 35 / 100, Graphics.FONT_MEDIUM, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 48 / 100, Graphics.FONT_XTINY, "Final Score", Graphics.TEXT_JUSTIFY_CENTER);

        var grade;
        if (_score >= 2200) {
            grade = "LEGENDARY!";
        } else if (_score >= 1600) {
            grade = "MASTER!";
        } else if (_score >= 1000) {
            grade = "GREAT!";
        } else if (_score >= 500) {
            grade = "GOOD";
        } else {
            grade = "TRY AGAIN";
        }
        dc.setColor(0x44FFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 60 / 100, Graphics.FONT_SMALL, grade, Graphics.TEXT_JUSTIFY_CENTER);

        var defeated = 0;
        if (_round >= 7 && _enemyHp <= 0) {
            defeated = 7;
        } else {
            defeated = _round - 1;
            if (defeated < 0) {
                defeated = 0;
            }
        }
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_XTINY, "Bosses: " + defeated + "/7", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 84 / 100, Graphics.FONT_XTINY, "Press to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
