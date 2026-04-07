using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum {
    GS_MENU,
    GS_PLAY,
    GS_BETWEEN,
    GS_GAMEOVER
}

class BitochiBombView extends WatchUi.View {

    var accelX;
    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;
    hidden var _timer;
    hidden var _tick;
    hidden var _groundY;
    hidden var _planeX;
    hidden var _planeY;
    hidden var _planeDir;
    hidden var _planeSpeed;

    hidden const MAX_BOMBS = 8;
    hidden var _bombX;
    hidden var _bombY;
    hidden var _bombVx;
    hidden var _bombVy;
    hidden var _bombAlive;
    hidden var _bombTrailX;
    hidden var _bombTrailY;

    hidden const MAX_ENEMIES = 16;
    hidden var _enemX;
    hidden var _enemY;
    hidden var _enemVx;
    hidden var _enemType;
    hidden var _enemAlive;
    hidden var _enemSize;

    hidden const MAX_BLDG = 22;
    hidden var _bldgX;
    hidden var _bldgW;
    hidden var _bldgH;
    hidden var _bldgHp;
    hidden var _bldgMaxHp;
    hidden var _bldgColor;

    hidden const MAX_PARTS = 180;
    hidden var _partX;
    hidden var _partY;
    hidden var _partVx;
    hidden var _partVy;
    hidden var _partLife;
    hidden var _partColor;
    hidden var _partSize;

    hidden const MAX_EXPL = 30;
    hidden var _explX;
    hidden var _explY;
    hidden var _explR;
    hidden var _explLife;
    hidden var _explMax;

    hidden const MAX_CRATERS = 28;
    hidden var _craterX;
    hidden var _craterR;
    hidden var _craterLife;

    hidden const MAX_DEBRIS = 55;
    hidden var _debX;
    hidden var _debY;
    hidden var _debVx;
    hidden var _debVy;
    hidden var _debLife;
    hidden var _debColor;
    hidden var _debRot;

    hidden var _wave;
    hidden var _score;
    hidden var _bestScore;
    hidden var _bombsLeft;
    hidden var _killCount;
    hidden var _totalKills;
    hidden var _totalSpawns;
    hidden var _spawnCount;
    hidden var _spawnTimer;
    hidden var _shakeTimer;
    hidden var _shakeOx;
    hidden var _shakeOy;
    hidden var _chainCount;
    hidden var _chainMax;
    hidden var _combo;
    hidden var _maxCombo;
    hidden var _wind;
    hidden var _windDir;
    hidden var _windPhase;
    hidden var _betweenTick;
    hidden var _resultTick;
    hidden var _hitMsg;
    hidden var _hitMsgTick;
    hidden var _perfectStreak;
    hidden var _cloudX;
    hidden var _cloudY;
    hidden var _waveTheme;
    hidden var _nightMode;
    hidden var _hasAirstrike;
    hidden var _airstrikeTimer;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _cx = _w / 2;
        _cy = _h / 2;
        accelX = 0;
        _tick = 0;
        _wave = 0;
        _score = 0;
        var bs = Application.Storage.getValue("bombBest");
        _bestScore = (bs != null) ? bs : 0;
        _totalKills = 0;
        _groundY = _h * 82 / 100;
        _planeY = _h * 12 / 100;
        _planeX = (_w / 2).toFloat();
        _planeDir = 1;
        _planeSpeed = 1.6;

        _bombX = new [MAX_BOMBS];
        _bombY = new [MAX_BOMBS];
        _bombVx = new [MAX_BOMBS];
        _bombVy = new [MAX_BOMBS];
        _bombAlive = new [MAX_BOMBS];
        _bombTrailX = new [MAX_BOMBS * 6];
        _bombTrailY = new [MAX_BOMBS * 6];
        for (var i = 0; i < MAX_BOMBS; i++) {
            _bombAlive[i] = false;
            _bombX[i] = 0.0; _bombY[i] = 0.0;
            _bombVx[i] = 0.0; _bombVy[i] = 0.0;
        }
        for (var i = 0; i < MAX_BOMBS * 6; i++) {
            _bombTrailX[i] = 0.0; _bombTrailY[i] = 0.0;
        }

        _enemX = new [MAX_ENEMIES];
        _enemY = new [MAX_ENEMIES];
        _enemVx = new [MAX_ENEMIES];
        _enemType = new [MAX_ENEMIES];
        _enemAlive = new [MAX_ENEMIES];
        _enemSize = new [MAX_ENEMIES];
        for (var i = 0; i < MAX_ENEMIES; i++) { _enemAlive[i] = false; _enemX[i] = 0.0; _enemVx[i] = 0.0; _enemY[i] = 0; _enemType[i] = 0; _enemSize[i] = 6; }

        _bldgX = new [MAX_BLDG];
        _bldgW = new [MAX_BLDG];
        _bldgH = new [MAX_BLDG];
        _bldgHp = new [MAX_BLDG];
        _bldgMaxHp = new [MAX_BLDG];
        _bldgColor = new [MAX_BLDG];
        for (var i = 0; i < MAX_BLDG; i++) { _bldgHp[i] = 0; _bldgX[i] = 0; _bldgW[i] = 0; _bldgH[i] = 0; _bldgMaxHp[i] = 0; _bldgColor[i] = 0; }

        _partX = new [MAX_PARTS];
        _partY = new [MAX_PARTS];
        _partVx = new [MAX_PARTS];
        _partVy = new [MAX_PARTS];
        _partLife = new [MAX_PARTS];
        _partColor = new [MAX_PARTS];
        _partSize = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) { _partLife[i] = 0; _partX[i] = 0.0; _partY[i] = 0.0; _partVx[i] = 0.0; _partVy[i] = 0.0; _partColor[i] = 0; _partSize[i] = 1; }

        _explX = new [MAX_EXPL];
        _explY = new [MAX_EXPL];
        _explR = new [MAX_EXPL];
        _explLife = new [MAX_EXPL];
        _explMax = new [MAX_EXPL];
        for (var i = 0; i < MAX_EXPL; i++) { _explLife[i] = 0; _explX[i] = 0; _explY[i] = 0; _explR[i] = 0.0; _explMax[i] = 0; }

        _craterX = new [MAX_CRATERS];
        _craterR = new [MAX_CRATERS];
        _craterLife = new [MAX_CRATERS];
        for (var i = 0; i < MAX_CRATERS; i++) { _craterLife[i] = 0; _craterX[i] = 0; _craterR[i] = 0; }

        _debX = new [MAX_DEBRIS];
        _debY = new [MAX_DEBRIS];
        _debVx = new [MAX_DEBRIS];
        _debVy = new [MAX_DEBRIS];
        _debLife = new [MAX_DEBRIS];
        _debColor = new [MAX_DEBRIS];
        _debRot = new [MAX_DEBRIS];
        for (var i = 0; i < MAX_DEBRIS; i++) { _debLife[i] = 0; _debX[i] = 0.0; _debY[i] = 0.0; _debVx[i] = 0.0; _debVy[i] = 0.0; _debColor[i] = 0; _debRot[i] = 0; }

        _cloudX = new [5];
        _cloudY = new [5];
        for (var i = 0; i < 5; i++) { _cloudX[i] = (Math.rand().abs() % _w).toFloat(); _cloudY[i] = 8 + Math.rand().abs() % 25; }

        _shakeTimer = 0; _shakeOx = 0; _shakeOy = 0;
        _chainCount = 0; _chainMax = 0;
        _combo = 0; _maxCombo = 0;
        _betweenTick = 0; _resultTick = 0;
        _wind = 0.0; _windDir = 0; _windPhase = 0;
        _bombsLeft = 0; _killCount = 0;
        _spawnTimer = 0; _spawnCount = 0; _totalSpawns = 0;
        _hitMsg = ""; _hitMsgTick = 0;
        _perfectStreak = 0;
        _waveTheme = 0;
        _nightMode = false;
        _hasAirstrike = false;
        _airstrikeTimer = 0;
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
        if (_shakeTimer > 0) {
            _shakeOx = (Math.rand().abs() % 11) - 5;
            _shakeOy = (Math.rand().abs() % 9) - 4;
            _shakeTimer--;
        } else { _shakeOx = 0; _shakeOy = 0; }
        if (_hitMsgTick > 0) { _hitMsgTick--; }

        for (var i = 0; i < 5; i++) {
            _cloudX[i] += 0.2 + i * 0.1 + _wind * 0.5;
            if (_cloudX[i] > (_w + 40).toFloat()) { _cloudX[i] = -40.0; }
            if (_cloudX[i] < -40.0) { _cloudX[i] = (_w + 40).toFloat(); }
        }

        if (gameState == GS_PLAY) {
            _windPhase++;
            if (_windPhase % 90 == 0) {
                _wind += ((Math.rand().abs() % 5) - 2).toFloat() * 0.04;
                if (_wind > 0.8) { _wind = 0.8; }
                if (_wind < -0.8) { _wind = -0.8; }
            }
            if (_hasAirstrike) {
                _airstrikeTimer++;
                if (_airstrikeTimer % 80 == 0) {
                    var ax = Math.rand().abs() % _w;
                    doExplosion(ax, _groundY, 1);
                }
            }
            updatePlane();
            updateBombs();
            updateEnemies();
            updateBuildings();
            updateExplosions();
            updateParticles();
            updateDebris();
            updateCraters();
            spawnWaveEnemy();
            checkWaveEnd();
        } else if (gameState == GS_BETWEEN) {
            _betweenTick++;
            updateParticles();
            updateDebris();
        } else if (gameState == GS_GAMEOVER) {
            _resultTick++;
            updateParticles();
            updateDebris();
        }

        WatchUi.requestUpdate();
    }

    hidden function updatePlane() {
        _planeX += _planeDir.toFloat() * _planeSpeed;
        if (_planeX > (_w - 20).toFloat()) { _planeDir = -1; }
        if (_planeX < 20.0) { _planeDir = 1; }
        var steer = accelX.toFloat() / 150.0;
        if (steer > 3.5) { steer = 3.5; }
        if (steer < -3.5) { steer = -3.5; }
        _planeX += steer;
        if (_planeX < 16.0) { _planeX = 16.0; }
        if (_planeX > (_w - 16).toFloat()) { _planeX = (_w - 16).toFloat(); }
    }

    hidden function updateBombs() {
        for (var i = 0; i < MAX_BOMBS; i++) {
            if (!_bombAlive[i]) { continue; }
            var base = i * 6;
            for (var t = 5; t > 0; t--) {
                _bombTrailX[base + t] = _bombTrailX[base + t - 1];
                _bombTrailY[base + t] = _bombTrailY[base + t - 1];
            }
            _bombTrailX[base] = _bombX[i];
            _bombTrailY[base] = _bombY[i];
            _bombVy[i] += 0.28;
            _bombVx[i] += _wind * 0.035;
            _bombX[i] += _bombVx[i];
            _bombY[i] += _bombVy[i];

            var hit = false;
            for (var b = 0; b < MAX_BLDG; b++) {
                if (_bldgHp[b] <= 0) { continue; }
                var bTop = _groundY - _bldgH[b];
                if (_bombY[i] >= bTop.toFloat() && _bombX[i] > (_bldgX[b] - _bldgW[b] / 2).toFloat() && _bombX[i] < (_bldgX[b] + _bldgW[b] / 2).toFloat()) {
                    _bombAlive[i] = false;
                    hitBuilding(b, _bombX[i].toNumber(), bTop);
                    hit = true;
                    break;
                }
            }
            if (!hit && _bombY[i] >= _groundY.toFloat()) {
                _bombAlive[i] = false;
                doExplosion(_bombX[i].toNumber(), _groundY, 0);
            }
        }
    }

    hidden function updateEnemies() {
        for (var i = 0; i < MAX_ENEMIES; i++) {
            if (!_enemAlive[i]) { continue; }
            _enemX[i] += _enemVx[i];
            if (_enemType[i] == 4 && _tick % 8 < 3) {
                _enemX[i] += ((Math.rand().abs() % 3) - 1).toFloat() * 0.4;
            }
            if (_enemVx[i] > 0 && _enemX[i] > (_w + 20).toFloat()) { _enemAlive[i] = false; }
            else if (_enemVx[i] < 0 && _enemX[i] < -20.0) { _enemAlive[i] = false; }
        }
    }

    hidden function updateBuildings() {
        for (var b = 0; b < MAX_BLDG; b++) {
            if (_bldgHp[b] <= 0) { continue; }
            if (_bldgHp[b] < _bldgMaxHp[b] / 3) {
                if (_tick % 8 == 0) {
                    spawnSmoke(_bldgX[b], _groundY - _bldgH[b]);
                }
            }
        }
    }

    hidden function updateExplosions() {
        for (var i = 0; i < MAX_EXPL; i++) {
            if (_explLife[i] <= 0) { continue; }
            _explLife[i]--;
            _explR[i] += 1.8;
            for (var j = 0; j < MAX_ENEMIES; j++) {
                if (!_enemAlive[j]) { continue; }
                var dx = _explX[i].toFloat() - _enemX[j];
                var dy = (_explY[i] - _enemY[j]).toFloat();
                var dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < _explR[i] + _enemSize[j].toFloat()) {
                    killEnemy(j, true);
                }
            }
            for (var b = 0; b < MAX_BLDG; b++) {
                if (_bldgHp[b] <= 0) { continue; }
                var dx = (_explX[i] - _bldgX[b]).abs();
                if (dx < _explR[i].toNumber() + _bldgW[b] / 2) {
                    var bTop = _groundY - _bldgH[b];
                    if (_explY[i] > bTop - _explR[i].toNumber()) {
                        _bldgHp[b] -= 2;
                        if (_bldgHp[b] <= 0) {
                            destroyBuilding(b);
                        }
                    }
                }
            }
        }
    }

    hidden function updateParticles() {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            _partVy[i] += 0.14;
            _partX[i] += _partVx[i];
            _partY[i] += _partVy[i];
            _partLife[i]--;
        }
    }

    hidden function updateDebris() {
        for (var i = 0; i < MAX_DEBRIS; i++) {
            if (_debLife[i] <= 0) { continue; }
            _debVy[i] += 0.22;
            _debX[i] += _debVx[i];
            _debY[i] += _debVy[i];
            _debRot[i] += 5;
            _debLife[i]--;
            if (_debY[i] > _groundY.toFloat() + 5.0) {
                _debLife[i] = 0;
            }
        }
    }

    hidden function updateCraters() {
        for (var i = 0; i < MAX_CRATERS; i++) {
            if (_craterLife[i] > 0) { _craterLife[i]--; }
        }
    }

    hidden function bombsForWave(w) {
        var b = 10 + w * 3;
        if (b > 40) { b = 40; }
        return b;
    }

    hidden function spawnsForWave(w) {
        var s = 6 + w * 3;
        if (s > 55) { s = 55; }
        return s;
    }

    hidden function spawnWaveEnemy() {
        if (_spawnCount >= _totalSpawns) { return; }
        _spawnTimer--;
        if (_spawnTimer > 0) { return; }
        var baseInterval = 28 - (_wave * 12) / 10;
        if (baseInterval < 10) { baseInterval = 10; }
        _spawnTimer = baseInterval + Math.rand().abs() % 12;

        var toSpawn = 1;
        if (_wave > 5 && Math.rand().abs() % 3 == 0) { toSpawn = 2; }
        if (_wave > 10 && Math.rand().abs() % 4 == 0) { toSpawn = 3; }

        for (var s = 0; s < toSpawn && _spawnCount < _totalSpawns; s++) {
            for (var i = 0; i < MAX_ENEMIES; i++) {
                if (_enemAlive[i]) { continue; }
                var fromLeft = (Math.rand().abs() % 2 == 0);
                _enemX[i] = fromLeft ? -12.0 : (_w + 12).toFloat();
                var baseSpd = 0.55 + _wave.toFloat() * 0.052;
                if (baseSpd > 2.35) { baseSpd = 2.35; }
                var t = Math.rand().abs() % 10;
                _enemType[i] = t;
                if (t == 0) { _enemSize[i] = 6; _enemVx[i] = (baseSpd + 0.3) * (fromLeft ? 1.0 : -1.0); }
                else if (t == 1) { _enemSize[i] = 10; _enemVx[i] = (baseSpd * 0.45) * (fromLeft ? 1.0 : -1.0); }
                else if (t == 2) { _enemSize[i] = 4; _enemVx[i] = (baseSpd + 1.4) * (fromLeft ? 1.0 : -1.0); }
                else if (t == 3) { _enemSize[i] = 8; _enemVx[i] = (baseSpd * 0.55) * (fromLeft ? 1.0 : -1.0); }
                else if (t == 4) { _enemSize[i] = 5; _enemVx[i] = (baseSpd + 0.2) * (fromLeft ? 1.0 : -1.0); }
                else if (t == 5) { _enemSize[i] = 13; _enemVx[i] = (baseSpd * 0.28) * (fromLeft ? 1.0 : -1.0); }
                else if (t == 6) { _enemSize[i] = 7; _enemVx[i] = baseSpd * (fromLeft ? 1.0 : -1.0); }
                else if (t == 7) { _enemSize[i] = 3; _enemVx[i] = (baseSpd + 1.8) * (fromLeft ? 1.0 : -1.0); }
                else if (t == 8) { _enemSize[i] = 9; _enemVx[i] = (baseSpd * 0.6) * (fromLeft ? 1.0 : -1.0); }
                else { _enemSize[i] = 6; _enemVx[i] = (baseSpd + 0.5) * (fromLeft ? 1.0 : -1.0); }
                _enemY[i] = _groundY - _enemSize[i];
                _enemAlive[i] = true;
                _spawnCount++;
                break;
            }
        }
    }

    hidden function checkWaveEnd() {
        if (_spawnCount < _totalSpawns) { return; }
        var anyAlive = false;
        for (var i = 0; i < MAX_ENEMIES; i++) { if (_enemAlive[i]) { anyAlive = true; break; } }
        var anyBombs = false;
        for (var i = 0; i < MAX_BOMBS; i++) { if (_bombAlive[i]) { anyBombs = true; break; } }
        var anyExpl = false;
        for (var i = 0; i < MAX_EXPL; i++) { if (_explLife[i] > 0) { anyExpl = true; break; } }
        var anyBldg = false;
        for (var b = 0; b < MAX_BLDG; b++) { if (_bldgHp[b] > 0) { anyBldg = true; break; } }
        if (!anyAlive && !anyBombs && !anyExpl && !anyBldg) {
            gameState = GS_BETWEEN;
            _betweenTick = 0;
        } else if (_bombsLeft <= 0 && !anyBombs && !anyExpl) {
            if (!anyAlive && !anyBldg) {
                gameState = GS_BETWEEN;
                _betweenTick = 0;
            } else {
                if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("bombBest", _bestScore); }
                gameState = GS_GAMEOVER;
                _resultTick = 0;
            }
        }
    }

    hidden function startWave() {
        _bombsLeft = bombsForWave(_wave);
        _killCount = 0;
        _totalSpawns = spawnsForWave(_wave);
        _spawnCount = 0;
        _spawnTimer = 10;
        _chainCount = 0; _chainMax = 0;
        _combo = 0; _maxCombo = 0;
        _perfectStreak = 0;
        _planeSpeed = 1.5 + _wave * 0.14;
        if (_planeSpeed > 3.5) { _planeSpeed = 3.5; }
        _windDir = (Math.rand().abs() % 21) - 10;
        _wind = _windDir.toFloat() * 0.06;
        _waveTheme = _wave % 6;
        _nightMode = (_wave % 4 == 3);
        _hasAirstrike = (_wave >= 5 && _wave % 3 == 0);
        _airstrikeTimer = 0;
        for (var i = 0; i < MAX_ENEMIES; i++) { _enemAlive[i] = false; }
        for (var i = 0; i < MAX_BOMBS; i++) { _bombAlive[i] = false; }
        for (var i = 0; i < MAX_EXPL; i++) { _explLife[i] = 0; }
        for (var i = 0; i < MAX_CRATERS; i++) { _craterLife[i] = 0; }
        for (var i = 0; i < MAX_PARTS; i++) { _partLife[i] = 0; }
        for (var i = 0; i < MAX_DEBRIS; i++) { _debLife[i] = 0; }
        _planeX = (_w / 2).toFloat();
        _planeDir = 1;

        spawnBuildings();
        gameState = GS_PLAY;
    }

    hidden function spawnBuildings() {
        var numBldg = 6 + _wave * 2;
        if (numBldg > MAX_BLDG) { numBldg = MAX_BLDG; }
        var bColors;
        if (_waveTheme == 0) {
            bColors = [0x665544, 0x556655, 0x554455, 0x555566, 0x666644, 0x664444, 0x446666, 0x556644, 0x776655, 0x557766, 0x665577, 0x667755, 0x555544, 0x445566, 0x665566, 0x556666, 0x664455, 0x554466, 0x667744, 0x556633, 0x775544, 0x446655];
        } else if (_waveTheme == 1) {
            bColors = [0x445577, 0x556688, 0x334466, 0x446677, 0x557799, 0x3A5577, 0x4A6688, 0x3A4A66, 0x5577AA, 0x4466AA, 0x3A5588, 0x5588AA, 0x446688, 0x556699, 0x3A4477, 0x4A5588, 0x3355AA, 0x4466BB, 0x5577CC, 0x334488, 0x445599, 0x5566AA];
        } else if (_waveTheme == 2) {
            bColors = [0x886644, 0x997755, 0x775533, 0xAA8855, 0x996644, 0x887744, 0x776644, 0x998866, 0x887755, 0xAA9966, 0x886655, 0x997766, 0x775544, 0x886633, 0x997744, 0xAA8844, 0x776633, 0x887744, 0x998855, 0x886644, 0x775533, 0x997755];
        } else if (_waveTheme == 3) {
            bColors = [0x555555, 0x666666, 0x444444, 0x777777, 0x333333, 0x888888, 0x505050, 0x606060, 0x707070, 0x404040, 0x585858, 0x686868, 0x484848, 0x787878, 0x383838, 0x989898, 0x525252, 0x626262, 0x727272, 0x424242, 0x565656, 0x676767];
        } else if (_waveTheme == 4) {
            bColors = [0x664444, 0x774444, 0x553333, 0x885555, 0x663333, 0x884444, 0x773333, 0x993333, 0x884444, 0x774444, 0x663333, 0x885555, 0x553333, 0x994444, 0x773333, 0x884444, 0x663333, 0x775555, 0x884455, 0x664444, 0x553344, 0x773344];
        } else {
            bColors = [0x446655, 0x557755, 0x338844, 0x449955, 0x557744, 0x336644, 0x448855, 0x559955, 0x337744, 0x446644, 0x558855, 0x339944, 0x447755, 0x556644, 0x448844, 0x557744, 0x336655, 0x449955, 0x558844, 0x447744, 0x336655, 0x559944];
        }
        var curX = 8 + Math.rand().abs() % 6;
        for (var i = 0; i < MAX_BLDG; i++) {
            if (i < numBldg && curX < _w - 8) {
                var bw = 8 + Math.rand().abs() % 10;
                _bldgW[i] = bw;
                _bldgX[i] = curX + bw / 2;
                var baseH = 18 + Math.rand().abs() % 30 + _wave * 3;
                if (_waveTheme == 1 || _waveTheme == 3) { baseH += 10 + Math.rand().abs() % 15; }
                if (i % 4 == 0) { baseH += 15 + Math.rand().abs() % 10; }
                if (baseH > 80) { baseH = 80; }
                _bldgH[i] = baseH;
                _bldgMaxHp[i] = 2 + _wave / 2;
                if (_bldgMaxHp[i] > 8) { _bldgMaxHp[i] = 8; }
                _bldgHp[i] = _bldgMaxHp[i];
                _bldgColor[i] = bColors[i % bColors.size()];
                curX += bw + 1 + Math.rand().abs() % 3;
            } else {
                _bldgHp[i] = 0;
            }
        }
    }

    function doAction() {
        if (gameState == GS_MENU) {
            _wave = 1; _score = 0; _totalKills = 0;
            startWave();
            return;
        }
        if (gameState == GS_GAMEOVER) {
            _wave = 1; _score = 0; _totalKills = 0;
            startWave();
            return;
        }
        if (gameState == GS_BETWEEN) {
            _wave++;
            startWave();
            return;
        }
        if (gameState == GS_PLAY) {
            dropBomb();
        }
    }

    hidden function dropBomb() {
        if (_bombsLeft <= 0) { return; }
        for (var i = 0; i < MAX_BOMBS; i++) {
            if (_bombAlive[i]) { continue; }
            _bombX[i] = _planeX;
            _bombY[i] = (_planeY + 6).toFloat();
            _bombVx[i] = _planeDir.toFloat() * _planeSpeed * 0.3 + _wind * 0.3;
            _bombVy[i] = 0.8;
            _bombAlive[i] = true;
            var base = i * 6;
            for (var t = 0; t < 6; t++) { _bombTrailX[base + t] = _bombX[i]; _bombTrailY[base + t] = _bombY[i]; }
            _bombsLeft--;
            doVibe(25, 30);
            break;
        }
    }

    hidden function hitBuilding(bIdx, bx, by) {
        _bldgHp[bIdx] -= 2;
        _shakeTimer = 14;
        doVibe(80, 200);
        spawnBuildingDebris(bx, by, _bldgColor[bIdx]);
        spawnBuildingDebris(bx, by + 8, _bldgColor[bIdx]);
        spawnFireParticles(bx, by, 3);
        spawnDirtEruption(bx, by);
        spawnGroundDebris(bx);
        _score += 60;

        if (_bldgHp[bIdx] <= 0) {
            destroyBuilding(bIdx);
        }

        for (var s = 0; s < 2; s++) {
            for (var i = 0; i < MAX_EXPL; i++) {
                if (_explLife[i] > 0) { continue; }
                _explX[i] = bx + ((Math.rand().abs() % 12) - 6);
                _explY[i] = by + s * 8;
                _explR[i] = 10.0 + s.toFloat() * 3.0;
                _explLife[i] = 18;
                _explMax[i] = 18;
                break;
            }
        }

        for (var nb = 0; nb < MAX_BLDG; nb++) {
            if (nb == bIdx || _bldgHp[nb] <= 0) { continue; }
            var ndx = (_bldgX[bIdx] - _bldgX[nb]).abs();
            if (ndx < _bldgW[bIdx] / 2 + _bldgW[nb] / 2 + 10) {
                _bldgHp[nb] -= 1;
                if (_bldgHp[nb] <= 0) { destroyBuilding(nb); }
            }
        }
    }

    hidden function destroyBuilding(bIdx) {
        _bldgHp[bIdx] = 0;
        var bx = _bldgX[bIdx];
        var bh = _bldgH[bIdx];
        var bw = _bldgW[bIdx];
        var by = _groundY - bh;
        _score += 300;
        _shakeTimer = 22;
        doVibe(100, 450);
        _hitMsg = "DESTROYED!";
        _hitMsgTick = 45;

        for (var s = 0; s < 4; s++) {
            spawnBuildingDebris(bx + ((Math.rand().abs() % 8) - 4), by + s * bh / 4, _bldgColor[bIdx]);
        }
        spawnFireParticles(bx, by, 4);
        spawnFireParticles(bx, by + bh / 3, 3);
        spawnFireParticles(bx, by + bh * 2 / 3, 2);
        spawnFireParticles(bx, _groundY, 2);
        spawnGroundDebris(bx);
        spawnGroundDebris(bx + ((Math.rand().abs() % 10) - 5));
        spawnDirtEruption(bx, _groundY);
        spawnDirtEruption(bx, by + bh / 2);

        for (var i = 0; i < MAX_CRATERS; i++) {
            if (_craterLife[i] > 0) { continue; }
            _craterX[i] = bx;
            _craterR[i] = bw / 2 + 8;
            _craterLife[i] = 600;
            break;
        }

        for (var e = 0; e < 3; e++) {
            for (var i = 0; i < MAX_EXPL; i++) {
                if (_explLife[i] > 0) { continue; }
                _explX[i] = bx + ((Math.rand().abs() % 14) - 7);
                _explY[i] = by + e * bh / 3 + ((Math.rand().abs() % 6) - 3);
                _explR[i] = 14.0 - e.toFloat() * 2.0;
                _explLife[i] = 24 - e * 3;
                _explMax[i] = _explLife[i];
                break;
            }
        }

        for (var j = 0; j < MAX_ENEMIES; j++) {
            if (!_enemAlive[j]) { continue; }
            var edx = (bx - _enemX[j].toNumber()).abs();
            if (edx < bw / 2 + 15) {
                killEnemy(j, true);
            }
        }
    }

    hidden function doExplosion(ex, ey, chainLevel) {
        _shakeTimer = 12 + chainLevel * 8;
        _chainCount = chainLevel;
        if (_chainCount > _chainMax) { _chainMax = _chainCount; }
        doVibe(80 + chainLevel * 40, 180 + chainLevel * 80);

        for (var i = 0; i < MAX_EXPL; i++) {
            if (_explLife[i] > 0) { continue; }
            _explX[i] = ex;
            _explY[i] = ey;
            _explR[i] = 12.0 + chainLevel.toFloat() * 6.0;
            _explLife[i] = 24 + chainLevel * 6;
            _explMax[i] = _explLife[i];
            break;
        }

        for (var s = 0; s < 2; s++) {
            var offX = ((Math.rand().abs() % 22) - 11);
            var offY = -((Math.rand().abs() % 12));
            for (var i = 0; i < MAX_EXPL; i++) {
                if (_explLife[i] > 0) { continue; }
                _explX[i] = ex + offX;
                _explY[i] = ey + offY;
                _explR[i] = 6.0 + chainLevel.toFloat() * 3.0;
                _explLife[i] = 16 + chainLevel * 4;
                _explMax[i] = _explLife[i];
                break;
            }
        }

        for (var i = 0; i < MAX_CRATERS; i++) {
            if (_craterLife[i] > 0) { continue; }
            _craterX[i] = ex;
            _craterR[i] = 10 + chainLevel * 5;
            _craterLife[i] = 500;
            break;
        }

        spawnFireParticles(ex, ey, chainLevel + 1);
        spawnGroundDebris(ex);
        spawnDirtEruption(ex, ey);
        spawnDirtEruption(ex + ((Math.rand().abs() % 10) - 5), ey);
        spawnWaterParticles(ex, ey - 5);

        var hitAny = false;
        for (var j = 0; j < MAX_ENEMIES; j++) {
            if (!_enemAlive[j]) { continue; }
            var dx = ex - _enemX[j].toNumber();
            var dy = ey - _enemY[j];
            var dist = Math.sqrt((dx * dx + dy * dy).toFloat());
            var hitR = 26.0 + chainLevel.toFloat() * 7.0 + _enemSize[j].toFloat();
            if (dist < hitR) {
                killEnemy(j, chainLevel > 0);
                hitAny = true;
            }
        }

        for (var b = 0; b < MAX_BLDG; b++) {
            if (_bldgHp[b] <= 0) { continue; }
            var bdx = (ex - _bldgX[b]).abs();
            if (bdx < 18 + chainLevel * 6 + _bldgW[b] / 2) {
                var bTop = _groundY - _bldgH[b];
                if (ey > bTop - 12) {
                    _bldgHp[b] -= 1 + chainLevel;
                    if (_bldgHp[b] <= 0) { destroyBuilding(b); }
                    else { spawnBuildingDebris(_bldgX[b], bTop, _bldgColor[b]); }
                }
            }
        }

        if (hitAny && chainLevel == 0) {
            _combo++;
            if (_combo > _maxCombo) { _maxCombo = _combo; }
        } else if (!hitAny && chainLevel == 0) {
            _combo = 0;
            _perfectStreak = 0;
            _hitMsg = "MISS";
            _hitMsgTick = 22;
        }
    }

    hidden function killEnemy(idx, isChain) {
        _enemAlive[idx] = false;
        _killCount++;
        _totalKills++;

        var pts = 50;
        var t = _enemType[idx];
        if (t == 1) { pts = 100; }
        else if (t == 3) { pts = 150; }
        else if (t == 5) { pts = 250; }
        else if (t == 6) { pts = 80; }
        else if (t == 8) { pts = 120; }
        else if (t == 9) { pts = 60; }

        if (isChain) {
            pts = pts * 2;
            _chainCount++;
            if (_chainCount > _chainMax) { _chainMax = _chainCount; }
            _perfectStreak = 0;
            _bombsLeft++;
            if (_chainCount >= 3 && _chainCount % 2 == 1) {
                _bombsLeft++;
            }
            _hitMsg = "CHAIN x" + _chainCount;
            _hitMsgTick = 30;
        } else {
            var dist = Math.sqrt((_planeX - _enemX[idx]) * (_planeX - _enemX[idx])).toNumber();
            if (dist < 6) {
                pts = pts * 3;
                _perfectStreak++;
                _hitMsg = "PERFECT!";
                _hitMsgTick = 35;
                if (_perfectStreak >= 3) {
                    _bombsLeft++;
                    _perfectStreak = 0;
                    _hitMsg = "PERFECT +1";
                    _hitMsgTick = 38;
                    doVibe(55, 80);
                }
            } else {
                _perfectStreak = 0;
                _hitMsg = "HIT!";
                _hitMsgTick = 20;
            }
        }

        if (_combo > 2) { pts += _combo * 20; }
        _score += pts;

        spawnBloodParticles(_enemX[idx].toNumber(), _enemY[idx]);

        for (var k = 0; k < MAX_EXPL; k++) {
            if (_explLife[k] > 0) { continue; }
            _explX[k] = _enemX[idx].toNumber();
            _explY[k] = _enemY[idx];
            _explR[k] = 4.0;
            _explLife[k] = 12;
            _explMax[k] = 12;
            break;
        }
        _shakeTimer += 3;
    }

    hidden function spawnFireParticles(ex, ey, chain) {
        var pal = [0xFF6622, 0xFFAA22, 0xFFFF44, 0xFF4400, 0xFFCC00, 0xFF8800, 0xFFFFAA, 0xFF2200, 0xFF3300, 0xFFDD00];
        var fireN = 24 + chain * 10;
        if (fireN > 50) { fireN = 50; }
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= fireN) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat() + ((Math.rand().abs() % 16) - 8).toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 2.8 + (Math.rand().abs() % 60).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a);
            _partVy[i] = -spd * Math.sin(a) - 2.5;
            _partLife[i] = 14 + Math.rand().abs() % 22;
            _partColor[i] = pal[Math.rand().abs() % 10];
            _partSize[i] = 1 + Math.rand().abs() % 4;
            spawned++;
        }
        var smokeN = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (smokeN >= 12) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat() + ((Math.rand().abs() % 22) - 11).toFloat();
            _partY[i] = ey.toFloat();
            _partVx[i] = ((Math.rand().abs() % 16) - 8).toFloat() * 0.18 + _wind * 0.5;
            _partVy[i] = -1.2 - (Math.rand().abs() % 18).toFloat() * 0.1;
            _partLife[i] = 32 + Math.rand().abs() % 26;
            _partColor[i] = (Math.rand().abs() % 3 == 0) ? 0x555555 : 0x333333;
            _partSize[i] = 2 + Math.rand().abs() % 4;
            smokeN++;
        }
    }

    hidden function spawnBloodParticles(ex, ey) {
        var bc = [0xFF0000, 0xDD0000, 0x990000, 0xFF3333, 0xBB0000, 0xEE2222, 0x770000, 0xFF4444];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 12) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 180).toFloat() * 3.14159 / 180.0;
            var spd = 1.5 + (Math.rand().abs() % 35).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a) * ((Math.rand().abs() % 2 == 0) ? 1.0 : -1.0);
            _partVy[i] = -spd * Math.sin(a) - 1.0;
            _partLife[i] = 14 + Math.rand().abs() % 14;
            _partColor[i] = bc[Math.rand().abs() % 8];
            _partSize[i] = 1 + Math.rand().abs() % 2;
            spawned++;
        }
    }

    hidden function spawnWaterParticles(ex, ey) {
        var wc = [0x4488FF, 0x66AAFF, 0x88CCFF, 0x2266DD, 0xAADDFF];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 8) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat();
            _partY[i] = ey.toFloat();
            _partVx[i] = ((Math.rand().abs() % 24) - 12).toFloat() * 0.18;
            _partVy[i] = -3.0 - (Math.rand().abs() % 25).toFloat() * 0.12;
            _partLife[i] = 18 + Math.rand().abs() % 12;
            _partColor[i] = wc[Math.rand().abs() % 5];
            _partSize[i] = 1 + Math.rand().abs() % 2;
            spawned++;
        }
    }

    hidden function spawnSmoke(sx, sy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] > 0) { continue; }
            _partX[i] = sx.toFloat() + ((Math.rand().abs() % 8) - 4).toFloat();
            _partY[i] = sy.toFloat();
            _partVx[i] = ((Math.rand().abs() % 6) - 3).toFloat() * 0.08 + _wind * 0.3;
            _partVy[i] = -0.5 - (Math.rand().abs() % 8).toFloat() * 0.04;
            _partLife[i] = 18 + Math.rand().abs() % 12;
            _partColor[i] = 0x333333;
            _partSize[i] = 2;
            break;
        }
    }

    hidden function spawnBuildingDebris(bx, by, color) {
        var spawned = 0;
        for (var i = 0; i < MAX_DEBRIS; i++) {
            if (spawned >= 8) { break; }
            if (_debLife[i] > 0) { continue; }
            _debX[i] = bx.toFloat() + ((Math.rand().abs() % 18) - 9).toFloat();
            _debY[i] = by.toFloat() + ((Math.rand().abs() % 10) - 5).toFloat();
            _debVx[i] = ((Math.rand().abs() % 14) - 7).toFloat() * 0.7;
            _debVy[i] = -(Math.rand().abs() % 12).toFloat() * 0.6 - 2.0;
            _debLife[i] = 22 + Math.rand().abs() % 18;
            var shade = Math.rand().abs() % 3;
            if (shade == 0) { _debColor[i] = color; }
            else if (shade == 1) {
                var r2 = ((color >> 16) & 0xFF) * 7 / 10;
                var g2 = ((color >> 8) & 0xFF) * 7 / 10;
                var b2 = (color & 0xFF) * 7 / 10;
                _debColor[i] = (r2 << 16) | (g2 << 8) | b2;
            } else { _debColor[i] = 0x444444; }
            _debRot[i] = Math.rand().abs() % 360;
            spawned++;
        }
    }

    hidden function spawnGroundDebris(gx) {
        var gc = [0x3A5A28, 0x4A7A30, 0x2A4A1A, 0x5A8A38, 0x3A6A20, 0x5A7A35, 0x2A3A18];
        var spawned = 0;
        for (var i = 0; i < MAX_DEBRIS; i++) {
            if (spawned >= 8) { break; }
            if (_debLife[i] > 0) { continue; }
            _debX[i] = gx.toFloat() + ((Math.rand().abs() % 24) - 12).toFloat();
            _debY[i] = _groundY.toFloat();
            _debVx[i] = ((Math.rand().abs() % 16) - 8).toFloat() * 0.6;
            _debVy[i] = -(Math.rand().abs() % 14).toFloat() * 0.7 - 2.5;
            _debLife[i] = 18 + Math.rand().abs() % 16;
            _debColor[i] = gc[Math.rand().abs() % 7];
            _debRot[i] = Math.rand().abs() % 360;
            spawned++;
        }
    }

    hidden function spawnDirtEruption(ex, ey) {
        var dc = [0x4A3A1A, 0x6A5A2A, 0x3A2A0A, 0x5A4A1A, 0x7A6A3A, 0x2A1A08, 0x8A7A4A, 0x3A3A1A];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 16) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat() + ((Math.rand().abs() % 20) - 10).toFloat();
            _partY[i] = ey.toFloat() + ((Math.rand().abs() % 4)).toFloat();
            var a = (60 + Math.rand().abs() % 60).toFloat() * 3.14159 / 180.0;
            var spd = 2.0 + (Math.rand().abs() % 35).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a) * ((Math.rand().abs() % 2 == 0) ? 1.0 : -1.0);
            _partVy[i] = -spd * Math.sin(a) - 1.0;
            _partLife[i] = 16 + Math.rand().abs() % 18;
            _partColor[i] = dc[Math.rand().abs() % 8];
            _partSize[i] = 2 + Math.rand().abs() % 3;
            spawned++;
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }

    // =========== RENDERING ===========

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _groundY = _h * 82 / 100;

        if (gameState == GS_MENU) { drawMenu(dc); return; }
        if (gameState == GS_GAMEOVER) { drawGameOver(dc); return; }
        if (gameState == GS_BETWEEN) { drawBetween(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeOx;
        var oy = _shakeOy;
        var w = _w;
        var h = _h;
        var gy = _groundY;

        var skyTop; var skyMid; var skyBot; var bgCol;
        if (_nightMode) {
            bgCol = 0x060610; skyTop = 0x0A0A1A; skyMid = 0x101028; skyBot = 0x181838;
        } else if (_waveTheme == 1) {
            bgCol = 0x182040; skyTop = 0x203060; skyMid = 0x2A4078; skyBot = 0x3A5090;
        } else if (_waveTheme == 2) {
            bgCol = 0x201008; skyTop = 0x301810; skyMid = 0x4A2818; skyBot = 0x5A3828;
        } else if (_waveTheme == 4) {
            bgCol = 0x180808; skyTop = 0x281010; skyMid = 0x381818; skyBot = 0x482020;
        } else if (_waveTheme == 5) {
            bgCol = 0x081810; skyTop = 0x102818; skyMid = 0x183828; skyBot = 0x204830;
        } else {
            bgCol = 0x101830; skyTop = 0x182040; skyMid = 0x203058; skyBot = 0x2A4070;
        }
        dc.setColor(bgCol, bgCol);
        dc.clear();
        dc.setColor(skyTop, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, gy * 35 / 100 + oy);
        dc.setColor(skyMid, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy * 35 / 100 + oy, w, gy * 25 / 100);
        dc.setColor(skyBot, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy * 60 / 100 + oy, w, gy - gy * 60 / 100);

        if (_nightMode) {
            for (var st = 0; st < 18; st++) {
                var stx = ((st * 47 + 13) % w);
                var sty = ((st * 31 + 7) % (gy * 60 / 100));
                var bright = ((_tick + st * 5) % 12 < 6) ? 0xBBBBCC : 0x777788;
                dc.setColor(bright, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(stx + ox, sty + oy, 1);
            }
        }

        for (var i = 0; i < 5; i++) {
            var ccx = _cloudX[i].toNumber() + ox;
            var ccy = _cloudY[i] + oy;
            dc.setColor((i % 2 == 0) ? 0x2A3A55 : 0x3A4A66, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx, ccy, 10 + i * 2);
            dc.fillCircle(ccx + 13, ccy + 1, 7 + i);
            dc.fillCircle(ccx - 11, ccy + 2, 6 + i);
            dc.setColor(0x354A6A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx + 5, ccy - 3, 5 + i);
        }

        var silC = _nightMode ? 0x0A0A18 : (_waveTheme == 2 ? 0x3A2818 : (_waveTheme == 4 ? 0x2A1818 : 0x2A3052));
        dc.setColor(silC, Graphics.COLOR_TRANSPARENT);
        for (var hx = 0; hx < w; hx += 3) {
            var mh = 10 + ((hx * 7 + 13) % 20) + _wave;
            if (mh > 35) { mh = 35; }
            dc.fillRectangle(hx + ox, gy - mh + oy, 3, mh);
        }
        if (_nightMode) {
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            for (var wx = 5; wx < w; wx += 11) {
                if ((wx * 3 + _tick) % 13 < 5) {
                    dc.fillRectangle(wx + ox, gy - 8 - ((wx * 7 + 13) % 20) + oy, 1, 1);
                }
            }
        }

        var gndC1; var gndC2; var gndC3; var grsC1; var grsC2;
        if (_waveTheme == 2) {
            gndC1 = 0x5A4A28; gndC2 = 0x6A5A30; gndC3 = 0x5A4A2A; grsC1 = 0x7A6A38; grsC2 = 0x5A4A20;
        } else if (_waveTheme == 3 || _nightMode) {
            gndC1 = 0x2A2A28; gndC2 = 0x3A3A30; gndC3 = 0x2A2A2A; grsC1 = 0x3A3A38; grsC2 = 0x2A2A20;
        } else if (_waveTheme == 4) {
            gndC1 = 0x3A2A18; gndC2 = 0x4A3A20; gndC3 = 0x3A2A1A; grsC1 = 0x5A3A28; grsC2 = 0x3A2A10;
        } else {
            gndC1 = 0x3A5A28; gndC2 = 0x4A7A30; gndC3 = 0x4A6A2A; grsC1 = 0x5A8A38; grsC2 = 0x3A5A20;
        }
        dc.setColor(gndC1, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy + oy, w, h - gy);
        dc.setColor(gndC2, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy + oy, w, 2);
        dc.setColor(gndC3, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy + 2 + oy, w, 2);
        for (var g = 0; g < w; g += 5) {
            dc.setColor((g % 3 == 0) ? grsC1 : grsC2, Graphics.COLOR_TRANSPARENT);
            var gh = 2 + (g % 7);
            dc.drawLine(g + ox, gy + oy, g + ((g % 2 == 0) ? 1 : -1) + ox, gy - gh + oy);
        }

        for (var i = 0; i < MAX_CRATERS; i++) {
            if (_craterLife[i] <= 0) { continue; }
            var cr = _craterR[i];
            var ccx = _craterX[i] + ox;
            var ccy = gy + 2 + oy;
            dc.setColor(0x1A2A0A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx, ccy, cr + 1);
            dc.setColor(0x0A1A05, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx, ccy + 1, cr);
            if (_craterLife[i] > 250) {
                dc.setColor(0x332200, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ccx, ccy, cr - 1);
                dc.setColor(0x221100, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ccx + 1, ccy + 1, cr - 3);
            }
            dc.setColor(0x4A5A28, Graphics.COLOR_TRANSPARENT);
            for (var e = 0; e < 6; e++) {
                var ea = (e * 60 + i * 30).toFloat() * 3.14159 / 180.0;
                var ex2 = ccx + ((cr + 1).toFloat() * Math.cos(ea)).toNumber();
                var ey2 = ccy + ((cr + 1).toFloat() * Math.sin(ea) * 0.4).toNumber();
                dc.fillRectangle(ex2 - 1, ey2 - 1, 2, 2);
            }
        }

        drawBuildings(dc, ox, oy);
        drawEnemies(dc, ox, oy);
        drawBombs(dc, ox, oy);
        drawExplosions(dc, ox, oy);
        drawDebrisParticles(dc, ox, oy);
        drawParticles(dc, ox, oy);
        drawPlane(dc, _planeX.toNumber() + ox, _planeY + oy, _planeDir);

        dc.setColor(0x1A3018, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_planeX.toNumber() + ox, gy + 5 + oy, 7);

        drawWindArrow(dc);
        drawHUD(dc);
    }

    hidden function drawBuildings(dc, ox, oy) {
        for (var b = 0; b < MAX_BLDG; b++) {
            if (_bldgHp[b] <= 0) { continue; }
            var bx = _bldgX[b] + ox;
            var bw = _bldgW[b];
            var bh = _bldgH[b];
            var by = _groundY - bh + oy;

            var baseC = _bldgColor[b];
            var dmgPct = _bldgHp[b].toFloat() / _bldgMaxHp[b].toFloat();

            if (dmgPct < 0.5) {
                var darkR = ((baseC >> 16) & 0xFF) * 6 / 10;
                var darkG = ((baseC >> 8) & 0xFF) * 6 / 10;
                var darkB = (baseC & 0xFF) * 6 / 10;
                baseC = (darkR << 16) | (darkG << 8) | darkB;
            }

            dc.setColor(baseC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - bw / 2, by, bw, bh);

            var darker = ((((baseC >> 16) & 0xFF) * 8 / 10) << 16) | ((((baseC >> 8) & 0xFF) * 8 / 10) << 8) | ((baseC & 0xFF) * 8 / 10);
            dc.setColor(darker, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - bw / 2, by, 2, bh);
            dc.fillRectangle(bx + bw / 2 - 2, by, 2, bh);

            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            var winRows = bh / 8;
            for (var r = 0; r < winRows; r++) {
                var wy = by + 4 + r * 8;
                for (var c = 0; c < bw / 6; c++) {
                    var wx = bx - bw / 2 + 3 + c * 6;
                    if (dmgPct < 0.5 && Math.rand().abs() % 3 == 0) {
                        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
                    } else {
                        var lit = (_tick + r * 3 + c * 7) % 20 < 14;
                        dc.setColor(lit ? 0xFFDD88 : 0x556677, Graphics.COLOR_TRANSPARENT);
                    }
                    dc.fillRectangle(wx, wy, 3, 4);
                }
            }

            if (dmgPct < 0.7) {
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
                for (var cr = 0; cr < (3.0 - dmgPct * 3.0).toNumber(); cr++) {
                    var cx2 = bx - bw / 3 + (cr * bw / 2);
                    var cy2 = by + bh / 4 + cr * bh / 3;
                    dc.drawLine(cx2, cy2, cx2 + 4, cy2 + 6);
                    dc.drawLine(cx2 + 4, cy2 + 6, cx2 + 1, cy2 + 10);
                }
            }

            dc.setColor(darker, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - bw / 2 - 1, by - 2, bw + 2, 3);

            if (bh > 40) {
                dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by - 6, 1, 6);
                if ((_tick + b * 7) % 20 < 10) {
                    dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(0x882222, Graphics.COLOR_TRANSPARENT);
                }
                dc.fillCircle(bx, by - 7, 1);
            }
        }
    }

    hidden function drawPlane(dc, px, py, dir) {
        if (dir < 0) {
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 16, py - 1, 32, 3);
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 14, py - 1, 28, 1);
            dc.setColor(0x3A4A5A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 11, py - 3, 20, 6);
            dc.setColor(0x4A5A6A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 9, py - 2, 16, 4);
            dc.setColor(0x3A4A5A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + 7, py - 7, 4, 5);
            dc.setColor(0x2A3A4A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + 6, py - 8, 6, 2);
            dc.setColor(0x88BBDD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - 7, py - 1, 2);
            dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - 7, py - 2, 1);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 13, py - 2, 4, 4);
            dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
            if (_tick % 3 == 0) { dc.fillRectangle(px - 14, py - 4, 1, 8); }
            else if (_tick % 3 == 1) { dc.fillRectangle(px - 14, py - 3, 1, 6); }
            else { dc.fillRectangle(px - 14, py - 1, 1, 2); }
            dc.setColor(0xDD3333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 14, py + 1, 2, 1);
            dc.fillRectangle(px + 12, py + 1, 2, 1);
        } else {
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 16, py - 1, 32, 3);
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 14, py - 1, 28, 1);
            dc.setColor(0x3A4A5A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 9, py - 3, 20, 6);
            dc.setColor(0x4A5A6A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 7, py - 2, 16, 4);
            dc.setColor(0x3A4A5A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 11, py - 7, 4, 5);
            dc.setColor(0x2A3A4A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 12, py - 8, 6, 2);
            dc.setColor(0x88BBDD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + 7, py - 1, 2);
            dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + 7, py - 2, 1);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + 9, py - 2, 4, 4);
            dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
            if (_tick % 3 == 0) { dc.fillRectangle(px + 13, py - 4, 1, 8); }
            else if (_tick % 3 == 1) { dc.fillRectangle(px + 13, py - 3, 1, 6); }
            else { dc.fillRectangle(px + 13, py - 1, 1, 2); }
            dc.setColor(0xDD3333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 14, py + 1, 2, 1);
            dc.fillRectangle(px + 12, py + 1, 2, 1);
        }
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 2, py + 3, 4, 2);
    }

    hidden function drawEnemies(dc, ox, oy) {
        for (var i = 0; i < MAX_ENEMIES; i++) {
            if (!_enemAlive[i]) { continue; }
            var ex = _enemX[i].toNumber() + ox;
            var ey = _enemY[i] + oy;
            var leg = (_tick % 6 < 3) ? 1 : -1;
            var dir = (_enemVx[i] > 0) ? 1 : -1;

            if (_enemType[i] == 0) {
                dc.setColor(0x44BB44, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 2, ey - 5, 5, 6);
                dc.fillCircle(ex, ey - 7, 3);
                dc.setColor(0x338833, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 2, ey + 1, 2, 3 + leg);
                dc.fillRectangle(ex + 1, ey + 1, 2, 3 - leg);
                dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 1 + dir, ey - 8, 1, 1);
                dc.fillRectangle(ex + 1 + dir, ey - 8, 1, 1);
                dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex + dir * 3, ey - 4, dir * 5, 1);
            } else if (_enemType[i] == 1) {
                dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 5, ey - 9, 11, 10);
                dc.fillCircle(ex, ey - 12, 4);
                dc.setColor(0xAA2222, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 5, ey + 1, 4, 5 + leg);
                dc.fillRectangle(ex + 2, ey + 1, 4, 5 - leg);
                dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 2, ey - 14, 2, 2);
                dc.fillRectangle(ex + 1, ey - 14, 2, 2);
                dc.setColor(0x993333, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 7, ey - 6, 3, 3);
                dc.fillRectangle(ex + 5, ey - 6, 3, 3);
            } else if (_enemType[i] == 2) {
                dc.setColor(0xDDCC33, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 1, ey - 4, 3, 5);
                dc.fillCircle(ex, ey - 6, 2);
                dc.setColor(0xBBAA22, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(ex, ey + 1, ex - 2 + leg * 2, ey + 5);
                dc.drawLine(ex, ey + 1, ex + 2 - leg * 2, ey + 5);
            } else if (_enemType[i] == 3) {
                dc.setColor(0x778888, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 7, ey - 4, 15, 5);
                dc.setColor(0x889999, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 3, ey - 8, 7, 4);
                dc.fillRectangle(ex + 3 * dir, ey - 7, 7 * dir, 2);
                dc.setColor(0x556666, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 7, ey + 1, 15, 3);
                dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
                for (var tr = 0; tr < 7; tr++) { dc.fillCircle(ex - 6 + tr * 2, ey + 3, 1); }
                dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 4, ey - 5, 2, 1);
            } else if (_enemType[i] == 4) {
                dc.setColor(0x8844AA, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ex, ey - 3, 4);
                dc.setColor(0x7733AA, Graphics.COLOR_TRANSPARENT);
                var sleg = (_tick % 4 < 2) ? 1 : 0;
                dc.drawLine(ex - 3, ey - 2, ex - 7, ey + 2 + sleg);
                dc.drawLine(ex + 3, ey - 2, ex + 7, ey + 2 - sleg);
                dc.drawLine(ex - 2, ey, ex - 6, ey + 3 - sleg);
                dc.drawLine(ex + 2, ey, ex + 6, ey + 3 + sleg);
                dc.setColor(0xFF44FF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ex - 1, ey - 4, 1);
                dc.fillCircle(ex + 1, ey - 4, 1);
            } else if (_enemType[i] == 5) {
                dc.setColor(0x882222, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ex, ey - 6, 9);
                dc.setColor(0xAA3333, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ex, ey - 6, 7);
                dc.fillCircle(ex, ey - 15, 4);
                dc.setColor(0x661111, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 6, ey + 3, 5, 6 + leg);
                dc.fillRectangle(ex + 2, ey + 3, 5, 6 - leg);
                dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 2, ey - 17, 2, 2);
                dc.fillRectangle(ex + 1, ey - 17, 2, 2);
                dc.setColor(0x993333, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 11, ey - 5, 5, 4);
                dc.fillRectangle(ex + 7, ey - 5, 5, 4);
            } else if (_enemType[i] == 6) {
                var ghostC = (_tick % 6 < 3) ? 0x446688 : 0x556699;
                dc.setColor(ghostC, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(ex, ey - 4, 5);
                dc.drawCircle(ex, ey - 4, 6);
                dc.setColor(0x6699BB, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ex - 2, ey - 5, 1);
                dc.fillCircle(ex + 2, ey - 5, 1);
                dc.setColor(ghostC, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(ex - 4, ey + 1, ex - 3, ey + 4);
                dc.drawLine(ex, ey + 1, ex + 1, ey + 4);
                dc.drawLine(ex + 4, ey + 1, ex + 3, ey + 4);
            } else if (_enemType[i] == 7) {
                dc.setColor(0xBB8833, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ex - 2, ey - 2, 2);
                dc.fillCircle(ex + 2, ey - 1, 2);
                dc.fillCircle(ex, ey - 4, 2);
            } else if (_enemType[i] == 8) {
                dc.setColor(0x44AADD, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 4, ey - 8, 9, 9);
                dc.fillCircle(ex, ey - 10, 4);
                dc.setColor(0x3388BB, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 4, ey + 1, 3, 4 + leg);
                dc.fillRectangle(ex + 2, ey + 1, 3, 4 - leg);
                dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex + dir * 4, ey - 6, dir * 8, 2);
                dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 1 + dir, ey - 11, 1, 1);
                dc.fillRectangle(ex + 1 + dir, ey - 11, 1, 1);
            } else {
                dc.setColor(0x33AA33, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 3, ey - 6, 7, 7);
                dc.fillCircle(ex, ey - 8, 3);
                dc.setColor(0x228822, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 3, ey + 1, 2, 4 + leg);
                dc.fillRectangle(ex + 2, ey + 1, 2, 4 - leg);
                dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 1, ey - 9, 1, 1);
                dc.fillRectangle(ex + 1, ey - 9, 1, 1);
            }
        }
    }

    hidden function drawBombs(dc, ox, oy) {
        for (var i = 0; i < MAX_BOMBS; i++) {
            if (!_bombAlive[i]) { continue; }
            var bx = _bombX[i].toNumber() + ox;
            var by = _bombY[i].toNumber() + oy;
            var base = i * 6;

            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            for (var t = 0; t < 6; t++) {
                var tx = _bombTrailX[base + t].toNumber() + ox;
                var ty = _bombTrailY[base + t].toNumber() + oy;
                dc.fillCircle(tx, ty, 1);
            }

            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, 4);
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, 3);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx - 1, by - 1, 1);
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 2, by - 5, 5, 2);
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 1, by - 6, 3, 1);

            var distG = _groundY - by + oy;
            if (distG < 40 && distG > 0) {
                dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(bx, by + 1, 1);
                if (distG < 20) {
                    dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(bx, by, 2);
                }
            }
        }
    }

    hidden function drawExplosions(dc, ox, oy) {
        for (var i = 0; i < MAX_EXPL; i++) {
            if (_explLife[i] <= 0) { continue; }
            var exx = _explX[i] + ox;
            var exy = _explY[i] + oy;
            var r = _explR[i].toNumber();
            var maxL = _explMax[i];
            var phase = maxL - _explLife[i];

            if (phase < 3) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r + 2);
                dc.setColor(0xFFFF66, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r);
                dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 50 / 100);
            } else if (phase < 7) {
                dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r + 1);
                dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 75 / 100);
                dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 40 / 100);
                dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx + ((Math.rand().abs() % 5) - 2), exy - ((Math.rand().abs() % 4)), r * 55 / 100);
            } else if (phase < 14) {
                dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 85 / 100);
                dc.setColor(0xCC2200, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 50 / 100);
                dc.setColor(0xFF6600, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx + ((Math.rand().abs() % 7) - 3), exy - ((Math.rand().abs() % 5)), r * 35 / 100);
            } else {
                dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 60 / 100);
                dc.setColor(0x332211, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 30 / 100);
            }

            if (phase < 6) {
                var ringR = r + 3 + phase * 3;
                dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(exx, exy, ringR);
                if (phase < 4) {
                    dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
                    dc.drawCircle(exx, exy, ringR - 1);
                }
            }

            if (phase < 5) {
                dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
                for (var sp = 0; sp < 10; sp++) {
                    var sa = (sp * 36 + _tick * 12).toFloat() * 3.14159 / 180.0;
                    var sr = r + 5 + phase * 2;
                    var spx = exx + (sr.toFloat() * Math.cos(sa)).toNumber();
                    var spy = exy + (sr.toFloat() * Math.sin(sa)).toNumber();
                    dc.fillCircle(spx, spy, (phase < 3) ? 2 : 1);
                }
            }
        }
    }

    hidden function drawDebrisParticles(dc, ox, oy) {
        for (var i = 0; i < MAX_DEBRIS; i++) {
            if (_debLife[i] <= 0) { continue; }
            var dx = _debX[i].toNumber() + ox;
            var dy = _debY[i].toNumber() + oy;
            dc.setColor(_debColor[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dx - 1, dy - 1, 3, 3);
            if (_debLife[i] > 10) {
                dc.fillRectangle(dx, dy - 2, 2, 4);
            }
        }
    }

    hidden function drawParticles(dc, ox, oy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            var px = _partX[i].toNumber() + ox;
            var py = _partY[i].toNumber() + oy;
            dc.setColor(_partColor[i], Graphics.COLOR_TRANSPARENT);
            var sz = _partSize[i];
            if (_partLife[i] < 4) { sz = 1; }
            dc.fillRectangle(px, py, sz, sz);
        }
    }

    hidden function drawWindArrow(dc) {
        if (_wind > -0.05 && _wind < 0.05) { return; }
        var wy = _planeY + 18;
        var arrowDir = (_wind > 0) ? 1 : -1;
        var strength = _wind;
        if (strength < 0) { strength = -strength; }
        var len = (strength * 25).toNumber();
        if (len < 3) { len = 3; }
        if (len > 18) { len = 18; }
        var ax = _cx;
        dc.setColor(0x5588AA, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ax - len * arrowDir, wy, ax + len * arrowDir, wy);
        dc.drawLine(ax + len * arrowDir, wy, ax + (len - 4) * arrowDir, wy - 3);
        dc.drawLine(ax + len * arrowDir, wy, ax + (len - 4) * arrowDir, wy + 3);
        if (strength > 0.3) {
            dc.drawLine(ax - len * arrowDir + 4 * arrowDir, wy + 5, ax + len * arrowDir + 4 * arrowDir, wy + 5);
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 5, 4, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(0x7799BB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 3, Graphics.FONT_XTINY, "W" + _wave, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        var bombsToDraw = _bombsLeft;
        if (bombsToDraw > 20) { bombsToDraw = 20; }
        for (var i = 0; i < bombsToDraw; i++) {
            dc.fillCircle(7 + i * 5, _h - 8, 2);
        }

        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(5, 4, Graphics.FONT_XTINY, "" + _killCount, Graphics.TEXT_JUSTIFY_LEFT);

        if (_hitMsgTick > 0 && !_hitMsg.equals("")) {
            var msgC = 0xFFFF44;
            if (_hitMsg.equals("MISS")) { msgC = 0x888888; }
            else if (_hitMsg.find("CHAIN") != null) { msgC = 0xFF6622; }
            else if (_hitMsg.find("PERFECT") != null) { msgC = 0x44FF44; }
            else if (_hitMsg.equals("DESTROYED!")) { msgC = 0xFF4444; }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx + 1, _cy - 9, Graphics.FONT_SMALL, _hitMsg, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(msgC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy - 10, Graphics.FONT_SMALL, _hitMsg, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_combo > 2) {
            dc.setColor(0xFF9922, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy + 10, Graphics.FONT_XTINY, "STREAK x" + _combo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_hasAirstrike && _airstrikeTimer % 80 > 60) {
            var warn = (_tick % 4 < 2) ? 0xFF2222 : 0xCC0000;
            dc.setColor(warn, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 70 / 100, Graphics.FONT_XTINY, "AIRSTRIKE!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x080818, 0x080818);
        dc.clear();

        for (var i = 0; i < 25; i++) {
            var sx = ((i * 53 + 17) % _w);
            var sy = ((i * 41 + _tick / 2 + 11) % _h);
            dc.setColor((i % 3 == 0) ? 0x445566 : 0x2A3A4A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, 1);
        }

        dc.setColor(0x1A2A44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 75 / 100, _w, _h * 25 / 100);
        dc.setColor(0x2A4A28, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 78 / 100, _w, _h * 22 / 100);
        for (var g = 0; g < _w; g += 4) {
            dc.setColor(0x3A6A30, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(g, _h * 78 / 100, g + ((g % 3 == 0) ? 1 : -1), _h * 78 / 100 - 2 - (g % 5));
        }

        dc.setColor(0x555544, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx - 15, _h * 68 / 100, 12, 18);
        dc.fillRectangle(_cx - 17, _h * 66 / 100, 16, 3);
        dc.setColor(0x665544, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx + 8, _h * 60 / 100, 18, 28);
        dc.fillPolygon([[_cx + 6, _h * 60 / 100], [_cx + 17, _h * 53 / 100], [_cx + 28, _h * 60 / 100]]);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx + 11, _h * 64 / 100, 3, 3);
        dc.fillRectangle(_cx + 18, _h * 64 / 100, 3, 3);

        var pulse = (_tick % 16 < 8) ? 0xFF4422 : 0xDD3311;
        dc.setColor(0x331100, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, _h * 8 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 8 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 22 / 100, Graphics.FONT_LARGE, "BOMB", Graphics.TEXT_JUSTIFY_CENTER);

        var px = (_cx + Math.sin((_tick * 5).toFloat() * 3.14159 / 180.0) * 30).toNumber();
        var pdir = ((_tick * 5) % 360 > 180) ? -1 : 1;
        drawPlane(dc, px, _h * 38 / 100, pdir);

        var exTick = _tick % 40;
        if (exTick < 20) {
            var er = 3 + exTick;
            if (exTick < 5) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_cx, _h * 50 / 100, er / 2);
            }
            dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cx, _h * 50 / 100, er);
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cx, _h * 50 / 100, er * 60 / 100);
        }

        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 58 / 100, Graphics.FONT_XTINY, "Destroy everything!", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestScore > 0) {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 80 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0xFF4422 : 0xCC2211, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 89 / 100, Graphics.FONT_XTINY, "Tap to start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawBetween(dc) {
        dc.setColor(0x080818, 0x080818);
        dc.clear();

        for (var i = 0; i < 15; i++) {
            dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((i * 53 + 17) % _w, (i * 41 + 11) % _h, 1);
        }

        var flash = (_betweenTick % 8 < 4) ? 0x44FF44 : 0x22CC22;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 10 / 100, Graphics.FONT_MEDIUM, "WAVE CLEAR", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 28 / 100, Graphics.FONT_SMALL, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x7799AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 24 / 100, Graphics.FONT_XTINY, "SCORE", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 40 / 100, Graphics.FONT_XTINY, "KILLS " + _killCount + " / " + _totalSpawns, Graphics.TEXT_JUSTIFY_CENTER);

        if (_chainMax > 0) {
            dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 48 / 100, Graphics.FONT_XTINY, "CHAIN x" + _chainMax, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_maxCombo > 2) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 56 / 100, Graphics.FONT_XTINY, "STREAK x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 66 / 100, Graphics.FONT_XTINY, "BOMBS +" + bombsForWave(_wave + 1), Graphics.TEXT_JUSTIFY_CENTER);

        var msgs = ["Arming payload...", "Urban zone ahead!", "Desert sector!", "Industrial district!", "Warzone detected!", "Green zone!", "Night assault!", "Massive structures!", "Reinforcements!", "Total annihilation!"];
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 72 / 100, Graphics.FONT_XTINY, msgs[_wave % msgs.size()], Graphics.TEXT_JUSTIFY_CENTER);
        if (_wave >= 5 && (_wave + 1) % 3 == 0) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 79 / 100, Graphics.FONT_XTINY, "AIRSTRIKE INCOMING", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_betweenTick > 30) {
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to go", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x100000, 0x100000);
        dc.clear();

        if (_resultTick < 10) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, _w, _h);
            dc.setColor(0x100000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cx, _cy, _w / 2 - _resultTick * 2);
        }

        for (var i = 0; i < 8; i++) {
            dc.setColor((i % 2 == 0) ? 0x331111 : 0x220000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((i * 53 + 17 + _resultTick) % _w, (i * 41 + 11) % _h, 2);
        }

        var flash = (_resultTick % 6 < 3) ? 0xFF2222 : 0xCC0000;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 10 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 26 / 100, Graphics.FONT_LARGE, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 42 / 100, Graphics.FONT_XTINY, "TOTAL KILLS " + _totalKills, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 50 / 100, Graphics.FONT_XTINY, "WAVE " + _wave, Graphics.TEXT_JUSTIFY_CENTER);

        if (_chainMax > 0) {
            dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 58 / 100, Graphics.FONT_XTINY, "CHAIN x" + _chainMax, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_maxCombo > 2) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 66 / 100, Graphics.FONT_XTINY, "STREAK x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 76 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);

        if (_resultTick > 30) {
            dc.setColor((_resultTick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
