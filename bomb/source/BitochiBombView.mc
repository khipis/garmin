using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

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

    hidden const MAX_BOMBS = 6;
    hidden var _bombX;
    hidden var _bombY;
    hidden var _bombVx;
    hidden var _bombVy;
    hidden var _bombAlive;
    hidden var _bombTrailX;
    hidden var _bombTrailY;

    hidden const MAX_ENEMIES = 12;
    hidden var _enemX;
    hidden var _enemY;
    hidden var _enemVx;
    hidden var _enemType;
    hidden var _enemAlive;
    hidden var _enemSize;

    hidden const MAX_PARTS = 60;
    hidden var _partX;
    hidden var _partY;
    hidden var _partVx;
    hidden var _partVy;
    hidden var _partLife;
    hidden var _partColor;
    hidden var _partSize;

    hidden const MAX_EXPL = 8;
    hidden var _explX;
    hidden var _explY;
    hidden var _explR;
    hidden var _explLife;
    hidden var _explMax;

    hidden const MAX_CRATERS = 10;
    hidden var _craterX;
    hidden var _craterR;
    hidden var _craterLife;

    hidden var _wave;
    hidden var _score;
    hidden var _bestScore;
    hidden var _bombsLeft;
    hidden var _killCount;
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
    hidden var _betweenTick;
    hidden var _resultTick;
    hidden var _hitMsg;
    hidden var _hitMsgTick;
    hidden var _cloudX;

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
        _bestScore = 0;
        _groundY = _h * 82 / 100;
        _planeY = _h * 13 / 100;
        _planeX = (_w / 2).toFloat();
        _planeDir = 1;

        _bombX = new [MAX_BOMBS];
        _bombY = new [MAX_BOMBS];
        _bombVx = new [MAX_BOMBS];
        _bombVy = new [MAX_BOMBS];
        _bombAlive = new [MAX_BOMBS];
        _bombTrailX = new [MAX_BOMBS * 5];
        _bombTrailY = new [MAX_BOMBS * 5];
        for (var i = 0; i < MAX_BOMBS; i++) {
            _bombAlive[i] = false;
            _bombX[i] = 0.0; _bombY[i] = 0.0;
            _bombVx[i] = 0.0; _bombVy[i] = 0.0;
        }
        for (var i = 0; i < MAX_BOMBS * 5; i++) {
            _bombTrailX[i] = 0.0; _bombTrailY[i] = 0.0;
        }

        _enemX = new [MAX_ENEMIES];
        _enemY = new [MAX_ENEMIES];
        _enemVx = new [MAX_ENEMIES];
        _enemType = new [MAX_ENEMIES];
        _enemAlive = new [MAX_ENEMIES];
        _enemSize = new [MAX_ENEMIES];
        for (var i = 0; i < MAX_ENEMIES; i++) { _enemAlive[i] = false; _enemX[i] = 0.0; _enemVx[i] = 0.0; _enemY[i] = 0; _enemType[i] = 0; _enemSize[i] = 6; }

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

        _cloudX = new [4];
        for (var i = 0; i < 4; i++) { _cloudX[i] = (Math.rand().abs() % _w).toFloat(); }

        _shakeTimer = 0; _shakeOx = 0; _shakeOy = 0;
        _chainCount = 0; _chainMax = 0;
        _combo = 0; _maxCombo = 0;
        _betweenTick = 0; _resultTick = 0;
        _wind = 0.0; _windDir = 0;
        _bombsLeft = 0; _killCount = 0;
        _spawnTimer = 0; _spawnCount = 0; _totalSpawns = 0;
        _hitMsg = ""; _hitMsgTick = 0;
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

        for (var i = 0; i < 4; i++) {
            _cloudX[i] += 0.15 + i.toFloat() * 0.08;
            if (_cloudX[i] > (_w + 40).toFloat()) { _cloudX[i] = -40.0; }
        }

        if (gameState == GS_PLAY) {
            updatePlane();
            updateBombs();
            updateEnemies();
            updateExplosions();
            updateParticles();
            updateCraters();
            spawnWaveEnemy();
            checkWaveEnd();
        } else if (gameState == GS_BETWEEN) {
            _betweenTick++;
            updateParticles();
        } else if (gameState == GS_GAMEOVER) {
            _resultTick++;
            updateParticles();
        }

        WatchUi.requestUpdate();
    }

    hidden function updatePlane() {
        _planeX += _planeDir.toFloat() * 0.7;
        if (_planeX > (_w - 22).toFloat()) { _planeDir = -1; }
        if (_planeX < 22.0) { _planeDir = 1; }
        var steer = accelX.toFloat() / 280.0;
        if (steer > 2.5) { steer = 2.5; }
        if (steer < -2.5) { steer = -2.5; }
        _planeX += steer;
        if (_planeX < 18.0) { _planeX = 18.0; }
        if (_planeX > (_w - 18).toFloat()) { _planeX = (_w - 18).toFloat(); }
    }

    hidden function updateBombs() {
        for (var i = 0; i < MAX_BOMBS; i++) {
            if (!_bombAlive[i]) { continue; }
            var base = i * 5;
            for (var t = 4; t > 0; t--) {
                _bombTrailX[base + t] = _bombTrailX[base + t - 1];
                _bombTrailY[base + t] = _bombTrailY[base + t - 1];
            }
            _bombTrailX[base] = _bombX[i];
            _bombTrailY[base] = _bombY[i];
            _bombVy[i] += 0.26;
            _bombVx[i] += _wind * 0.018;
            _bombX[i] += _bombVx[i];
            _bombY[i] += _bombVy[i];
            if (_bombY[i] >= _groundY.toFloat()) {
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
                _enemX[i] += ((Math.rand().abs() % 3) - 1).toFloat() * 0.3;
            }
            if (_enemVx[i] > 0 && _enemX[i] > (_w + 20).toFloat()) { _enemAlive[i] = false; }
            else if (_enemVx[i] < 0 && _enemX[i] < -20.0) { _enemAlive[i] = false; }
        }
    }

    hidden function updateExplosions() {
        for (var i = 0; i < MAX_EXPL; i++) {
            if (_explLife[i] <= 0) { continue; }
            _explLife[i]--;
            _explR[i] += 1.2;
            for (var j = 0; j < MAX_ENEMIES; j++) {
                if (!_enemAlive[j]) { continue; }
                var dx = _explX[i].toFloat() - _enemX[j];
                var dy = (_explY[i] - _enemY[j]).toFloat();
                var dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < _explR[i] + _enemSize[j].toFloat()) {
                    killEnemy(j, true);
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

    hidden function updateCraters() {
        for (var i = 0; i < MAX_CRATERS; i++) {
            if (_craterLife[i] > 0) { _craterLife[i]--; }
        }
    }

    hidden function spawnWaveEnemy() {
        if (_spawnCount >= _totalSpawns) { return; }
        _spawnTimer--;
        if (_spawnTimer > 0) { return; }
        _spawnTimer = 35 - _wave * 2;
        if (_spawnTimer < 12) { _spawnTimer = 12; }
        _spawnTimer += Math.rand().abs() % 15;
        for (var i = 0; i < MAX_ENEMIES; i++) {
            if (_enemAlive[i]) { continue; }
            var fromLeft = (Math.rand().abs() % 2 == 0);
            _enemX[i] = fromLeft ? -12.0 : (_w + 12).toFloat();
            var baseSpd = 0.5 + _wave.toFloat() * 0.07;
            if (baseSpd > 2.2) { baseSpd = 2.2; }
            var t = Math.rand().abs() % 8;
            _enemType[i] = t;
            if (t == 0) { _enemSize[i] = 6; _enemVx[i] = (baseSpd + 0.3) * (fromLeft ? 1.0 : -1.0); }
            else if (t == 1) { _enemSize[i] = 10; _enemVx[i] = (baseSpd * 0.45) * (fromLeft ? 1.0 : -1.0); }
            else if (t == 2) { _enemSize[i] = 4; _enemVx[i] = (baseSpd + 1.2) * (fromLeft ? 1.0 : -1.0); }
            else if (t == 3) { _enemSize[i] = 8; _enemVx[i] = (baseSpd * 0.55) * (fromLeft ? 1.0 : -1.0); }
            else if (t == 4) { _enemSize[i] = 5; _enemVx[i] = (baseSpd + 0.15) * (fromLeft ? 1.0 : -1.0); }
            else if (t == 5) { _enemSize[i] = 13; _enemVx[i] = (baseSpd * 0.28) * (fromLeft ? 1.0 : -1.0); }
            else if (t == 6) { _enemSize[i] = 7; _enemVx[i] = baseSpd * (fromLeft ? 1.0 : -1.0); }
            else { _enemSize[i] = 3; _enemVx[i] = (baseSpd + 1.6) * (fromLeft ? 1.0 : -1.0); }
            _enemY[i] = _groundY - _enemSize[i];
            _enemAlive[i] = true;
            _spawnCount++;
            break;
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
        if (!anyAlive && !anyBombs && !anyExpl) {
            gameState = GS_BETWEEN;
            _betweenTick = 0;
        } else if (_bombsLeft <= 0 && !anyBombs && !anyExpl && anyAlive) {
            if (_score > _bestScore) { _bestScore = _score; }
            gameState = GS_GAMEOVER;
            _resultTick = 0;
        }
    }

    hidden function startWave() {
        _bombsLeft = 5 + _wave * 2;
        if (_bombsLeft > 18) { _bombsLeft = 18; }
        _killCount = 0;
        _totalSpawns = 3 + _wave * 2;
        if (_totalSpawns > MAX_ENEMIES) { _totalSpawns = MAX_ENEMIES; }
        _spawnCount = 0;
        _spawnTimer = 15;
        _chainCount = 0; _chainMax = 0;
        _combo = 0; _maxCombo = 0;
        _windDir = (Math.rand().abs() % 15) - 7;
        _wind = _windDir.toFloat() * 0.07;
        for (var i = 0; i < MAX_ENEMIES; i++) { _enemAlive[i] = false; }
        for (var i = 0; i < MAX_BOMBS; i++) { _bombAlive[i] = false; }
        for (var i = 0; i < MAX_EXPL; i++) { _explLife[i] = 0; }
        for (var i = 0; i < MAX_CRATERS; i++) { _craterLife[i] = 0; }
        for (var i = 0; i < MAX_PARTS; i++) { _partLife[i] = 0; }
        _planeX = (_w / 2).toFloat();
        _planeDir = 1;
        gameState = GS_PLAY;
    }

    function doAction() {
        if (gameState == GS_MENU) {
            _wave = 1; _score = 0;
            startWave();
            return;
        }
        if (gameState == GS_GAMEOVER) {
            gameState = GS_MENU;
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
            _bombVx[i] = _wind * 0.25 + ((Math.rand().abs() % 7) - 3).toFloat() * 0.04;
            _bombVy[i] = 0.6;
            _bombAlive[i] = true;
            var base = i * 5;
            for (var t = 0; t < 5; t++) { _bombTrailX[base + t] = _bombX[i]; _bombTrailY[base + t] = _bombY[i]; }
            _bombsLeft--;
            doVibe(25, 30);
            break;
        }
    }

    hidden function doExplosion(ex, ey, chainLevel) {
        _shakeTimer = 6 + chainLevel * 4;
        _chainCount = chainLevel;
        if (_chainCount > _chainMax) { _chainMax = _chainCount; }
        doVibe(50 + chainLevel * 25, 80 + chainLevel * 40);

        for (var i = 0; i < MAX_EXPL; i++) {
            if (_explLife[i] > 0) { continue; }
            _explX[i] = ex;
            _explY[i] = ey;
            _explR[i] = 4.0 + chainLevel.toFloat() * 2.5;
            _explLife[i] = 14 + chainLevel * 3;
            _explMax[i] = _explLife[i];
            break;
        }

        for (var i = 0; i < MAX_CRATERS; i++) {
            if (_craterLife[i] > 0) { continue; }
            _craterX[i] = ex;
            _craterR[i] = 5 + chainLevel * 2;
            _craterLife[i] = 250;
            break;
        }

        spawnFireParticles(ex, ey, chainLevel);
        if (Math.rand().abs() % 3 == 0) { spawnWaterParticles(ex, ey - 5); }

        var hitAny = false;
        for (var j = 0; j < MAX_ENEMIES; j++) {
            if (!_enemAlive[j]) { continue; }
            var dx = ex - _enemX[j].toNumber();
            var dy = ey - _enemY[j];
            var dist = Math.sqrt((dx * dx + dy * dy).toFloat());
            var hitR = 14.0 + chainLevel.toFloat() * 3.0 + _enemSize[j].toFloat();
            if (dist < hitR) {
                killEnemy(j, chainLevel > 0);
                hitAny = true;
            }
        }

        if (hitAny && chainLevel == 0) {
            _combo++;
            if (_combo > _maxCombo) { _maxCombo = _combo; }
        } else if (!hitAny && chainLevel == 0) {
            _combo = 0;
            _hitMsg = "MISS";
            _hitMsgTick = 22;
        }
    }

    hidden function killEnemy(idx, isChain) {
        _enemAlive[idx] = false;
        _killCount++;

        var pts = 50;
        var t = _enemType[idx];
        if (t == 1) { pts = 100; }
        else if (t == 3) { pts = 150; }
        else if (t == 5) { pts = 250; }
        else if (t == 6) { pts = 80; }

        if (isChain) {
            pts = pts * 2;
            _chainCount++;
            if (_chainCount > _chainMax) { _chainMax = _chainCount; }
            _bombsLeft++;
            _hitMsg = "CHAIN x" + _chainCount;
            _hitMsgTick = 30;
        } else {
            var dist = Math.sqrt((_planeX - _enemX[idx]) * (_planeX - _enemX[idx])).toNumber();
            if (dist < 6) {
                pts = pts * 3;
                _hitMsg = "PERFECT!";
                _hitMsgTick = 35;
            } else {
                _hitMsg = "HIT!";
                _hitMsgTick = 20;
            }
        }

        if (_combo > 2) { pts += _combo * 15; }
        _score += pts;

        spawnBloodParticles(_enemX[idx].toNumber(), _enemY[idx]);

        for (var k = 0; k < MAX_EXPL; k++) {
            if (_explLife[k] > 0) { continue; }
            _explX[k] = _enemX[idx].toNumber();
            _explY[k] = _enemY[idx];
            _explR[k] = 3.0;
            _explLife[k] = 11;
            _explMax[k] = 11;
            break;
        }
        _shakeTimer += 2;
    }

    hidden function spawnFireParticles(ex, ey, chain) {
        var pal = [0xFF6622, 0xFFAA22, 0xFFFF44, 0xFF4400, 0xFFCC00, 0xFF8800, 0xFFFFAA, 0xFF2200];
        var fireN = 12 + chain * 4;
        if (fireN > 20) { fireN = 20; }
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= fireN) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat() + ((Math.rand().abs() % 5) - 2).toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.5 + (Math.rand().abs() % 35).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a);
            _partVy[i] = -spd * Math.sin(a) - 1.2;
            _partLife[i] = 10 + Math.rand().abs() % 14;
            _partColor[i] = pal[Math.rand().abs() % 8];
            _partSize[i] = 1 + Math.rand().abs() % 2;
            spawned++;
        }
        var smokeN = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (smokeN >= 5) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat() + ((Math.rand().abs() % 12) - 6).toFloat();
            _partY[i] = ey.toFloat();
            _partVx[i] = ((Math.rand().abs() % 10) - 5).toFloat() * 0.12;
            _partVy[i] = -0.6 - (Math.rand().abs() % 10).toFloat() * 0.06;
            _partLife[i] = 22 + Math.rand().abs() % 18;
            _partColor[i] = (Math.rand().abs() % 3 == 0) ? 0x444444 : 0x333333;
            _partSize[i] = 2;
            smokeN++;
        }
    }

    hidden function spawnBloodParticles(ex, ey) {
        var bc = [0xFF0000, 0xDD0000, 0x990000, 0xFF3333, 0xBB0000, 0xEE2222, 0x770000, 0xFF4444];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 10) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 180).toFloat() * 3.14159 / 180.0;
            var spd = 1.2 + (Math.rand().abs() % 30).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a) * ((Math.rand().abs() % 2 == 0) ? 1.0 : -1.0);
            _partVy[i] = -spd * Math.sin(a) - 0.8;
            _partLife[i] = 12 + Math.rand().abs() % 12;
            _partColor[i] = bc[Math.rand().abs() % 8];
            _partSize[i] = 1 + Math.rand().abs() % 2;
            spawned++;
        }
    }

    hidden function spawnWaterParticles(ex, ey) {
        var wc = [0x4488FF, 0x66AAFF, 0x88CCFF, 0x2266DD, 0xAADDFF];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 6) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat();
            _partY[i] = ey.toFloat();
            _partVx[i] = ((Math.rand().abs() % 20) - 10).toFloat() * 0.15;
            _partVy[i] = -2.5 - (Math.rand().abs() % 20).toFloat() * 0.1;
            _partLife[i] = 16 + Math.rand().abs() % 10;
            _partColor[i] = wc[Math.rand().abs() % 5];
            _partSize[i] = 1;
            spawned++;
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            var vp = new Attention.VibeProfile(intensity, duration);
            Attention.vibrate([vp]);
        }
    }

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

        dc.setColor(0x101830, 0x101830);
        dc.clear();
        dc.setColor(0x182040, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, gy * 35 / 100 + oy);
        dc.setColor(0x203058, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy * 35 / 100 + oy, w, gy * 25 / 100);
        dc.setColor(0x2A4070, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy * 60 / 100 + oy, w, gy - gy * 60 / 100);

        for (var i = 0; i < 4; i++) {
            var ccx = _cloudX[i].toNumber() + ox;
            var ccy = 12 + i * 16 + oy;
            dc.setColor((i % 2 == 0) ? 0x2A3A55 : 0x3A4A66, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx, ccy, 9 + i * 2);
            dc.fillCircle(ccx + 12, ccy + 1, 7 + i);
            dc.fillCircle(ccx - 10, ccy + 2, 6 + i);
            dc.setColor(0x354A6A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx + 5, ccy - 2, 5 + i);
        }

        var hx = 0;
        dc.setColor(0x2A3052, Graphics.COLOR_TRANSPARENT);
        for (hx = 0; hx < w; hx += 3) {
            var mh = 8 + ((hx * 7 + 13) % 15);
            dc.fillRectangle(hx + ox, gy - mh + oy, 3, mh);
        }

        dc.setColor(0x3A5A28, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy + oy, w, h - gy);
        dc.setColor(0x4A7A30, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy + oy, w, 2);
        dc.setColor(0x4A6A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy + 2 + oy, w, 2);
        for (var g = 0; g < w; g += 5) {
            dc.setColor((g % 3 == 0) ? 0x5A8A38 : 0x3A5A20, Graphics.COLOR_TRANSPARENT);
            var gh = 2 + (g % 7);
            dc.drawLine(g + ox, gy + oy, g + ((g % 2 == 0) ? 1 : -1) + ox, gy - gh + oy);
        }

        for (var i = 0; i < MAX_CRATERS; i++) {
            if (_craterLife[i] <= 0) { continue; }
            var cr = _craterR[i];
            dc.setColor(0x2A3A15, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_craterX[i] + ox, gy + 2 + oy, cr);
            dc.setColor(0x1A2A0A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_craterX[i] + ox, gy + 3 + oy, cr - 1);
            if (_craterLife[i] > 200) {
                dc.setColor(0x332200, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_craterX[i] + ox, gy + 1 + oy, cr - 2);
            }
        }

        drawGroundDecor(dc, ox, oy, w, gy);
        drawEnemies(dc, ox, oy);
        drawBombs(dc, ox, oy);
        drawExplosions(dc, ox, oy);
        drawParticles(dc, ox, oy);
        drawPlane(dc, _planeX.toNumber() + ox, _planeY + oy);

        dc.setColor(0x1A3018, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_planeX.toNumber() + ox, gy + 5 + oy, 6);

        drawWindArrow(dc);

        if (_wind.abs() > 0.15) {
            for (var i = 0; i < 3; i++) {
                var wx = ((_tick * 2 + i * 90) % (w + 30)) - 15;
                var wy = gy * 40 / 100 + i * 20 + oy;
                dc.setColor(0x2A3A55, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(wx, wy, wx + (_wind > 0 ? 8 : -8), wy);
            }
        }

        drawHUD(dc);
    }

    hidden function drawGroundDecor(dc, ox, oy, w, gy) {
        for (var d = 0; d < 5; d++) {
            var dx = ((d * 57 + 23) % (w - 20)) + 10 + ox;
            var dy = gy + oy;
            if (d % 3 == 0) {
                dc.setColor(0x555544, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx - 5, dy - 12, 10, 12);
                dc.fillRectangle(dx - 7, dy - 14, 14, 3);
                dc.setColor(0x444433, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx - 4, dy - 10, 3, 5);
                dc.setColor(0x222211, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx - 3, dy - 9, 2, 3);
                dc.setColor(0x666655, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx + 2, dy - 8, 2, 2);
            } else if (d % 3 == 1) {
                dc.setColor(0x444433, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx, dy - 16, 2, 16);
                dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
                if (_tick % 8 < 5) { dc.fillCircle(dx + 1, dy - 18, 2); }
                dc.setColor(0x444433, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx - 3, dy - 8, 8, 1);
            } else {
                dc.setColor(0x665544, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx - 8, dy - 18, 16, 18);
                dc.setColor(0x554433, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[dx - 10, dy - 18], [dx, dy - 26], [dx + 10, dy - 18]]);
                dc.setColor(0x222211, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx - 2, dy - 8, 4, 8);
                dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx - 6, dy - 15, 3, 3);
                dc.fillRectangle(dx + 3, dy - 15, 3, 3);
                if (_tick % 12 < 4) {
                    dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(dx - 5, dy - 14, 1, 1);
                }
            }
        }

        if (_tick % 4 < 3) {
            var fx = ((_w * 30 / 100 + _tick / 3) % _w) + ox;
            var fy = gy + oy;
            dc.setColor(0x4488FF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(fx, fy, fx, fy - 6 - (_tick % 6));
            dc.drawLine(fx, fy - 6 - (_tick % 6), fx - 2, fy - 3);
            dc.drawLine(fx, fy - 6 - (_tick % 6), fx + 2, fy - 3);
            dc.setColor(0x66AAFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fx, fy - 4 - (_tick % 4), 1);
        }
    }

    hidden function drawPlane(dc, px, py) {
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
                dc.setColor(0xFFEE55, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - 1, ey - 7, 1, 1);
                dc.fillRectangle(ex + 1, ey - 7, 1, 1);
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
                if (_tick % 10 < 3) {
                    dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(ex, ey - 14, 1);
                }
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
            } else {
                dc.setColor(0xBB8833, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ex - 2, ey - 2, 2);
                dc.fillCircle(ex + 2, ey - 1, 2);
                dc.fillCircle(ex, ey - 4, 2);
                dc.setColor(0xDD9944, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ex + 3, ey - 3, 1);
                dc.fillCircle(ex - 1, ey, 1);
            }
        }
    }

    hidden function drawBombs(dc, ox, oy) {
        for (var i = 0; i < MAX_BOMBS; i++) {
            if (!_bombAlive[i]) { continue; }
            var bx = _bombX[i].toNumber() + ox;
            var by = _bombY[i].toNumber() + oy;
            var base = i * 5;

            dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
            for (var t = 0; t < 5; t++) {
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
                var glow = (40 - distG) * 6;
                if (glow > 255) { glow = 255; }
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
            var life = _explLife[i];
            var maxL = _explMax[i];
            var phase = maxL - life;

            if (phase < 3) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r);
                dc.setColor(0xFFFF66, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 80 / 100);
            } else if (phase < 7) {
                dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r);
                dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 70 / 100);
                dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 35 / 100);
            } else if (phase < 11) {
                dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 85 / 100);
                dc.setColor(0xCC2200, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 50 / 100);
            } else {
                dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 60 / 100);
                dc.setColor(0x332211, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(exx, exy, r * 30 / 100);
            }

            if (phase < 5) {
                dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
                for (var sp = 0; sp < 6; sp++) {
                    var sa = (sp * 60 + _tick * 8).toFloat() * 3.14159 / 180.0;
                    var sr = r + 3 + phase;
                    var spx = exx + (sr.toFloat() * Math.cos(sa)).toNumber();
                    var spy = exy + (sr.toFloat() * Math.sin(sa)).toNumber();
                    dc.fillCircle(spx, spy, 1);
                }
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
        if (_windDir == 0) { return; }
        var wy = _planeY + 18;
        var arrowDir = (_wind > 0) ? 1 : -1;
        var strength = _windDir.abs();
        var ax = _cx;
        dc.setColor(0x5588AA, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ax - 10 * arrowDir, wy, ax + 10 * arrowDir, wy);
        dc.drawLine(ax + 10 * arrowDir, wy, ax + 6 * arrowDir, wy - 3);
        dc.drawLine(ax + 10 * arrowDir, wy, ax + 6 * arrowDir, wy + 3);
        if (strength > 3) {
            dc.drawLine(ax - 10 * arrowDir + 5 * arrowDir, wy + 5, ax + 10 * arrowDir + 5 * arrowDir, wy + 5);
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 5, 4, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(0x7799BB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 3, Graphics.FONT_XTINY, "W" + _wave, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        var bombsToDraw = _bombsLeft;
        if (bombsToDraw > 18) { bombsToDraw = 18; }
        for (var i = 0; i < bombsToDraw; i++) {
            dc.fillCircle(7 + i * 6, _h - 8, 2);
        }

        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(5, 4, Graphics.FONT_XTINY, "" + _killCount, Graphics.TEXT_JUSTIFY_LEFT);

        if (_hitMsgTick > 0 && !_hitMsg.equals("")) {
            var msgC = 0xFFFF44;
            if (_hitMsg.equals("MISS")) { msgC = 0x888888; }
            else if (_hitMsg.find("CHAIN") != null) { msgC = 0xFF6622; }
            else if (_hitMsg.equals("PERFECT!")) { msgC = 0x44FF44; }
            dc.setColor(msgC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy - 10, Graphics.FONT_SMALL, _hitMsg, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_combo > 2) {
            dc.setColor(0xFF9922, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy + 10, Graphics.FONT_XTINY, "STREAK x" + _combo, Graphics.TEXT_JUSTIFY_CENTER);
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

        var pulse = (_tick % 16 < 8) ? 0xFF4422 : 0xDD3311;
        dc.setColor(0x331100, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, _h * 8 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 8 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 22 / 100, Graphics.FONT_LARGE, "BOMB", Graphics.TEXT_JUSTIFY_CENTER);

        var px = (_cx + Math.sin((_tick * 4).toFloat() * 3.14159 / 180.0) * 30).toNumber();
        drawPlane(dc, px, _h * 38 / 100);

        var exTick = _tick % 40;
        if (exTick < 20) {
            var er = 3 + exTick;
            if (exTick < 5) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_cx, _h * 55 / 100, er / 2);
            }
            dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cx, _h * 55 / 100, er);
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cx, _h * 55 / 100, er * 60 / 100);
            if (exTick < 8) {
                dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_cx, _h * 55 / 100, er * 30 / 100);
            }
        }

        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 64 / 100, Graphics.FONT_XTINY, "Tilt to aim", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, _h * 70 / 100, Graphics.FONT_XTINY, "Tap to drop", Graphics.TEXT_JUSTIFY_CENTER);

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
        dc.drawText(_cx, _h * 42 / 100, Graphics.FONT_XTINY, "KILLS " + _killCount, Graphics.TEXT_JUSTIFY_CENTER);

        if (_chainMax > 0) {
            dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 50 / 100, Graphics.FONT_XTINY, "CHAIN x" + _chainMax, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_maxCombo > 2) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 58 / 100, Graphics.FONT_XTINY, "STREAK x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 68 / 100, Graphics.FONT_XTINY, "BOMBS +" + (5 + (_wave + 1) * 2), Graphics.TEXT_JUSTIFY_CENTER);

        var msgs = ["Arming payload...", "Targets incoming...", "Wind shifting...", "New zone ahead..."];
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 78 / 100, Graphics.FONT_XTINY, msgs[_wave % msgs.size()], Graphics.TEXT_JUSTIFY_CENTER);

        if (_betweenTick > 40) {
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to go", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x100000, 0x100000);
        dc.clear();

        if (_resultTick < 10) {
            var flashI = (10 - _resultTick) * 25;
            if (flashI > 200) { flashI = 200; }
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
        dc.drawText(_cx, _h * 28 / 100, Graphics.FONT_LARGE, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 43 / 100, Graphics.FONT_XTINY, "KILLS " + _killCount, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 51 / 100, Graphics.FONT_XTINY, "WAVE " + _wave, Graphics.TEXT_JUSTIFY_CENTER);

        if (_chainMax > 0) {
            dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 59 / 100, Graphics.FONT_XTINY, "CHAIN x" + _chainMax, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_maxCombo > 2) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 67 / 100, Graphics.FONT_XTINY, "STREAK x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 77 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);

        if (_resultTick > 30) {
            dc.setColor((_resultTick % 10 < 5) ? 0x666666 : 0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
