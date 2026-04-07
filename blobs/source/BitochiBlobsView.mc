using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum {
    GS_MENU,
    GS_INTRO,
    GS_AIM,
    GS_FLY,
    GS_BOOM,
    GS_TURN,
    GS_AI,
    GS_WIN,
    GS_OVER
}

enum { WPN_ROCKET, WPN_GRENADE, WPN_MEGA }

class BitochiBlobsView extends WatchUi.View {

    var gameState;
    var accelX;

    hidden var _w;
    hidden var _h;
    hidden var _timer;
    hidden var _tick;

    hidden const TERR_N = 140;
    hidden var _terrH;

    hidden var _pX;
    hidden var _pY;
    hidden var _pHp;
    hidden var _aX;
    hidden var _aY;
    hidden var _aHp;
    hidden var _aMaxHp;
    hidden const MAX_HP = 3;

    hidden var _weapon;
    hidden var _wpnNames;

    hidden var _aimAngle;
    hidden var _powerPhase;
    hidden var _power;
    hidden var _playerTurn;

    hidden var _projX;
    hidden var _projY;
    hidden var _projVx;
    hidden var _projVy;
    hidden var _projBounces;
    hidden var _projAlive;
    hidden var _projWeapon;

    hidden var _wind;

    hidden var _boomX;
    hidden var _boomY;
    hidden var _boomR;
    hidden var _boomTick;
    hidden var _boomMaxR;
    hidden var _hitDmg;
    hidden var _hitMsg;
    hidden var _hitMsgTick;

    hidden const MAX_PARTS = 50;
    hidden var _partX;
    hidden var _partY;
    hidden var _partVx;
    hidden var _partVy;
    hidden var _partLife;
    hidden var _partCol;

    hidden var _round;
    hidden var _bestStreak;
    hidden var _newBest;
    hidden var _introTick;
    hidden var _resultTick;
    hidden var _turnTick;

    hidden var _shakeT;
    hidden var _shakeOx;
    hidden var _shakeOy;

    hidden var _aiAimTick;
    hidden var _aiTargetAngle;
    hidden var _aiTargetPower;
    hidden var _aiWpnDisplay;

    hidden var _dmgFloatY;
    hidden var _dmgFloatTick;
    hidden var _dmgFloatVal;
    hidden var _dmgFloatX;

    hidden var _cloudX;
    hidden var _cloudW;
    hidden var _cloudSpeed;

    hidden var _wobblePhase;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _tick = 0;
        accelX = 0;
        gameState = GS_MENU;

        _terrH = new [TERR_N];
        for (var i = 0; i < TERR_N; i++) { _terrH[i] = _h / 2; }

        _pX = 0; _pY = 0; _pHp = MAX_HP;
        _aX = 0; _aY = 0; _aHp = MAX_HP; _aMaxHp = MAX_HP;

        _weapon = WPN_ROCKET;
        _wpnNames = ["ROCKET", "GRENADE", "MEGA BOMB"];

        _aimAngle = 45.0;
        _powerPhase = 0.0;
        _power = 60.0;
        _playerTurn = true;

        _projX = 0.0; _projY = 0.0;
        _projVx = 0.0; _projVy = 0.0;
        _projBounces = 0; _projAlive = false; _projWeapon = 0;

        _wind = 0.0;

        _boomX = 0.0; _boomY = 0.0; _boomR = 0; _boomTick = 0; _boomMaxR = 20;
        _hitDmg = 0; _hitMsg = ""; _hitMsgTick = 0;

        _partX = new [MAX_PARTS]; _partY = new [MAX_PARTS];
        _partVx = new [MAX_PARTS]; _partVy = new [MAX_PARTS];
        _partLife = new [MAX_PARTS]; _partCol = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) {
            _partX[i] = 0.0; _partY[i] = 0.0; _partVx[i] = 0.0; _partVy[i] = 0.0;
            _partLife[i] = 0; _partCol[i] = 0;
        }

        _round = 0;
        var bs = Application.Storage.getValue("blobBest");
        _bestStreak = (bs != null) ? bs : 0;
        _newBest = false;
        _introTick = 0; _resultTick = 0; _turnTick = 0;
        _shakeT = 0; _shakeOx = 0; _shakeOy = 0;
        _aiAimTick = 0; _aiTargetAngle = 45.0; _aiTargetPower = 60.0;
        _aiWpnDisplay = WPN_ROCKET;

        _dmgFloatY = 0.0; _dmgFloatTick = 0; _dmgFloatVal = 0; _dmgFloatX = 0.0;

        _cloudX = new [6]; _cloudW = new [6]; _cloudSpeed = new [6];
        for (var i = 0; i < 6; i++) {
            _cloudX[i] = (Math.rand().abs() % _w).toFloat();
            _cloudW[i] = 12 + Math.rand().abs() % 16;
            _cloudSpeed[i] = 0.1 + (Math.rand().abs() % 8).toFloat() / 20.0;
        }

        _wobblePhase = 0.0;
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
        _wobblePhase += 0.12;

        for (var i = 0; i < 6; i++) {
            _cloudX[i] += _cloudSpeed[i];
            if (_cloudX[i] > _w + 20) { _cloudX[i] = -20.0; }
        }

        if (_shakeT > 0) {
            _shakeOx = (Math.rand().abs() % 9) - 4;
            _shakeOy = (Math.rand().abs() % 7) - 3;
            _shakeT--;
        } else { _shakeOx = 0; _shakeOy = 0; }

        if (_hitMsgTick > 0) { _hitMsgTick--; }
        if (_dmgFloatTick > 0) { _dmgFloatTick--; _dmgFloatY -= 0.8; }

        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            _partVy[i] += 0.18;
            _partX[i] += _partVx[i];
            _partY[i] += _partVy[i];
            _partLife[i]--;
        }

        if (gameState == GS_INTRO) {
            _introTick++;
            if (_introTick > 50) {
                gameState = GS_TURN;
                _turnTick = 0;
                _playerTurn = true;
            }
        } else if (gameState == GS_TURN) {
            _turnTick++;
            if (_turnTick > 28) {
                if (_playerTurn) {
                    gameState = GS_AIM;
                    _powerPhase = 0.0;
                } else {
                    startAiCalc();
                }
            }
        } else if (gameState == GS_AIM) {
            var pSpeed = 0.09;
            if (_weapon == WPN_MEGA) { pSpeed = 0.14; }
            _powerPhase += pSpeed;
            _power = 55.0 + 40.0 * Math.sin(_powerPhase);
            var steer = accelX.toFloat() / 250.0;
            if (steer > 2.5) { steer = 2.5; }
            if (steer < -2.5) { steer = -2.5; }
            _aimAngle += steer;
            if (_aimAngle < 10.0) { _aimAngle = 10.0; }
            if (_aimAngle > 80.0) { _aimAngle = 80.0; }
        } else if (gameState == GS_AI) {
            _aiAimTick++;
            if (_aiAimTick >= 35) { aiFireProjectile(); }
        } else if (gameState == GS_FLY) {
            updateProjectile();
        } else if (gameState == GS_BOOM) {
            _boomTick++;
            _boomR = (_boomTick * _boomMaxR / 12);
            if (_boomR > _boomMaxR) { _boomR = _boomMaxR; }
            if (_boomTick > 22) { afterExplosion(); }
        } else if (gameState == GS_WIN || gameState == GS_OVER) {
            _resultTick++;
        }

        WatchUi.requestUpdate();
    }

    hidden function generateTerrain() {
        var baseH = _h * 38 / 100;
        var freq1 = 0.04 + (Math.rand().abs() % 25).toFloat() / 1000.0;
        var freq2 = 0.09 + (Math.rand().abs() % 35).toFloat() / 1000.0;
        var amp1 = 12.0 + (Math.rand().abs() % 18).toFloat();
        var amp2 = 5.0 + (Math.rand().abs() % 10).toFloat();
        var ph1 = (Math.rand().abs() % 628).toFloat() / 100.0;
        var ph2 = (Math.rand().abs() % 628).toFloat() / 100.0;

        for (var i = 0; i < TERR_N; i++) {
            var x = i.toFloat();
            _terrH[i] = baseH + (Math.sin(x * freq1 + ph1) * amp1).toNumber()
                               + (Math.sin(x * freq2 + ph2) * amp2).toNumber()
                               + (Math.rand().abs() % 4) - 2;
            if (_terrH[i] < 25) { _terrH[i] = 25; }
            if (_terrH[i] > _h * 60 / 100) { _terrH[i] = _h * 60 / 100; }
        }

        var flatL = TERR_N * 15 / 100;
        var flatR = TERR_N * 22 / 100;
        var avgL = 0;
        for (var i = flatL; i <= flatR; i++) { avgL += _terrH[i]; }
        avgL = avgL / (flatR - flatL + 1);
        for (var i = flatL; i <= flatR; i++) { _terrH[i] = avgL; }

        var flatL2 = TERR_N * 78 / 100;
        var flatR2 = TERR_N * 85 / 100;
        var avgR = 0;
        for (var i = flatL2; i <= flatR2; i++) { avgR += _terrH[i]; }
        avgR = avgR / (flatR2 - flatL2 + 1);
        for (var i = flatL2; i <= flatR2; i++) { _terrH[i] = avgR; }
    }

    hidden function terrainYAt(col) {
        if (col < 0) { col = 0; }
        if (col >= TERR_N) { col = TERR_N - 1; }
        return _h - _terrH[col];
    }

    hidden function pixelTerrainY(px) {
        if (_w <= 0) { return _h; }
        var col = px * TERR_N / _w;
        if (col < 0) { col = 0; }
        if (col >= TERR_N) { col = TERR_N - 1; }
        return terrainYAt(col);
    }

    hidden function startRound() {
        _round++;
        generateTerrain();

        var pCol = TERR_N * 18 / 100 + Math.rand().abs() % (TERR_N * 5 / 100);
        var aCol = TERR_N * 78 / 100 + Math.rand().abs() % (TERR_N * 7 / 100);
        _pX = pCol * _w / TERR_N;
        _pY = terrainYAt(pCol);
        _aX = aCol * _w / TERR_N;
        _aY = terrainYAt(aCol);

        _pHp = MAX_HP;
        _aMaxHp = MAX_HP + (_round / 3);
        if (_aMaxHp > 6) { _aMaxHp = 6; }
        _aHp = _aMaxHp;
        _weapon = WPN_ROCKET;
        _aimAngle = 45.0;
        _powerPhase = 0.0;
        _playerTurn = true;
        _projAlive = false;
        _newBest = false;
        _wind = -1.2 + (Math.rand().abs() % 24).toFloat() / 10.0;
        _hitMsg = ""; _hitMsgTick = 0;
        _dmgFloatTick = 0;

        for (var i = 0; i < MAX_PARTS; i++) { _partLife[i] = 0; }
        for (var i = 0; i < 6; i++) {
            _cloudX[i] = (Math.rand().abs() % _w).toFloat();
        }

        gameState = GS_INTRO;
        _introTick = 0;
    }

    hidden function fireProjectile() {
        var rad = _aimAngle * 3.14159 / 180.0;
        var spdMul = wpnSpeed(_weapon);
        var pwr = _power / 100.0 * spdMul;

        _projX = _pX.toFloat();
        _projY = _pY.toFloat() - 8.0;
        _projVx = pwr * Math.cos(rad);
        _projVy = -pwr * Math.sin(rad);
        _projBounces = 0;
        _projAlive = true;
        _projWeapon = _weapon;
        gameState = GS_FLY;
        doVibe(30, 50);
    }

    hidden function wpnSpeed(w) {
        if (w == WPN_ROCKET) { return 5.2; }
        if (w == WPN_GRENADE) { return 4.2; }
        return 3.6;
    }

    hidden function wpnGrav(w) {
        if (w == WPN_ROCKET) { return 0.14; }
        if (w == WPN_GRENADE) { return 0.17; }
        return 0.19;
    }

    hidden function aiFireProjectile() {
        var aiWpn = _aiWpnDisplay;
        var rad = _aiTargetAngle * 3.14159 / 180.0;
        var spdMul = wpnSpeed(aiWpn);
        var pwr = _aiTargetPower / 100.0 * spdMul;

        _projX = _aX.toFloat();
        _projY = _aY.toFloat() - 8.0;
        _projVx = -pwr * Math.cos(rad);
        _projVy = -pwr * Math.sin(rad);
        _projBounces = 0;
        _projAlive = true;
        _projWeapon = aiWpn;
        gameState = GS_FLY;
        doVibe(30, 50);
    }

    hidden function pickAiWeapon() {
        var r = Math.rand().abs() % 100;
        if (_pHp == 1 && _round >= 3) {
            if (r < 35) { return WPN_MEGA; }
            if (r < 70) { return WPN_ROCKET; }
            return WPN_GRENADE;
        }
        if (r < 50) { return WPN_ROCKET; }
        if (r < 80) { return WPN_GRENADE; }
        return WPN_MEGA;
    }

    hidden function startAiCalc() {
        _playerTurn = false;
        _aiAimTick = 0;
        _aiWpnDisplay = pickAiWeapon();

        var dx = (_pX - _aX).toFloat();
        var dy = (_pY - _aY).toFloat();
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < 1.0) { dist = 1.0; }

        var idealAngle = Math.atan2(-dy, -dx) * 180.0 / 3.14159;
        if (idealAngle < 0.0) { idealAngle = -idealAngle; }
        if (idealAngle < 20.0) { idealAngle = 20.0; }
        if (idealAngle > 75.0) { idealAngle = 75.0; }

        var windAdj = _wind * dist * 0.003;
        idealAngle += windAdj;

        var errScale = 22.0 - _round.toFloat() * 1.4;
        if (errScale < 4.0) { errScale = 4.0; }
        var errN = errScale.toNumber();
        if (errN < 1) { errN = 1; }
        var angleErr = (Math.rand().abs() % (errN * 2 + 1)) - errN;
        _aiTargetAngle = idealAngle + angleErr.toFloat();
        if (_aiTargetAngle < 15.0) { _aiTargetAngle = 15.0; }
        if (_aiTargetAngle > 78.0) { _aiTargetAngle = 78.0; }

        var idealPower = 38.0 + dist * 0.28;
        if (idealPower > 92.0) { idealPower = 92.0; }
        var pwrErrN = errN / 2;
        if (pwrErrN < 1) { pwrErrN = 1; }
        var pwrErr = (Math.rand().abs() % (pwrErrN * 2 + 1)) - pwrErrN;
        _aiTargetPower = idealPower + pwrErr.toFloat();
        if (_aiTargetPower < 30.0) { _aiTargetPower = 30.0; }
        if (_aiTargetPower > 95.0) { _aiTargetPower = 95.0; }

        gameState = GS_AI;
    }

    hidden function updateProjectile() {
        var grav = wpnGrav(_projWeapon);

        _projVy += grav;
        _projVx += _wind * 0.004;
        _projX += _projVx;
        _projY += _projVy;

        if (_tick % 2 == 0) { spawnSmokeTrail(_projX, _projY); }

        if (_projX < -10.0 || _projX > (_w + 10).toFloat() || _projY > (_h + 30).toFloat()) {
            doMiss();
            return;
        }

        var tY = pixelTerrainY(_projX.toNumber());
        if (_projY >= tY.toFloat()) {
            if (_projWeapon == WPN_GRENADE && _projBounces < 2) {
                _projVy = -_projVy * 0.55;
                _projVx = _projVx * 0.7;
                _projY = tY.toFloat() - 2.0;
                _projBounces++;
                doVibe(20, 30);
                spawnDirtParticles(_projX.toNumber(), tY);
                return;
            }
            doExplosion(_projX, tY.toFloat());
            return;
        }

        var pDist = Math.sqrt((_projX - _pX.toFloat()) * (_projX - _pX.toFloat()) +
                              (_projY - (_pY.toFloat() - 6.0)) * (_projY - (_pY.toFloat() - 6.0)));
        if (pDist < 10.0 && !_playerTurn) {
            doExplosion(_projX, _projY);
            return;
        }
        var aDist = Math.sqrt((_projX - _aX.toFloat()) * (_projX - _aX.toFloat()) +
                              (_projY - (_aY.toFloat() - 6.0)) * (_projY - (_aY.toFloat() - 6.0)));
        if (aDist < 10.0 && _playerTurn) {
            doExplosion(_projX, _projY);
            return;
        }
    }

    hidden function doExplosion(ex, ey) {
        _boomX = ex; _boomY = ey; _boomTick = 0;
        if (_projWeapon == WPN_ROCKET) { _boomMaxR = 20; }
        else if (_projWeapon == WPN_GRENADE) { _boomMaxR = 26; }
        else { _boomMaxR = 36; }
        _projAlive = false;
        gameState = GS_BOOM;
        _shakeT = (_projWeapon == WPN_MEGA) ? 14 : 8;
        doVibe((_projWeapon == WPN_MEGA) ? 100 : 60, (_projWeapon == WPN_MEGA) ? 250 : 120);
        spawnExplosionParticles(ex.toNumber(), ey.toNumber());

        carveCrater(ex.toNumber(), _boomMaxR);

        var dmg;
        if (_projWeapon == WPN_MEGA) { dmg = 2; }
        else { dmg = 1; }

        _hitDmg = 0;
        var pDist = Math.sqrt((ex - _pX.toFloat()) * (ex - _pX.toFloat()) +
                              (ey - (_pY.toFloat() - 6.0)) * (ey - (_pY.toFloat() - 6.0)));
        var aDist = Math.sqrt((ex - _aX.toFloat()) * (ex - _aX.toFloat()) +
                              (ey - (_aY.toFloat() - 6.0)) * (ey - (_aY.toFloat() - 6.0)));

        if (_playerTurn) {
            if (aDist < _boomMaxR.toFloat()) {
                var actualDmg = dmg;
                if (aDist > _boomMaxR.toFloat() * 0.7 && dmg > 1) { actualDmg = 1; }
                _aHp -= actualDmg;
                if (_aHp < 0) { _aHp = 0; }
                _hitDmg = actualDmg;
                _hitMsg = (aDist < 8.0) ? "DIRECT HIT!" : "HIT!";
                _dmgFloatX = _aX.toFloat(); _dmgFloatY = _aY.toFloat() - 22.0;
                _dmgFloatVal = actualDmg; _dmgFloatTick = 35;
            }
            if (pDist < _boomMaxR.toFloat() * 0.5) {
                _pHp -= 1;
                if (_pHp < 0) { _pHp = 0; }
                if (_hitDmg == 0) { _hitMsg = "SELF HIT!"; }
            }
        } else {
            if (pDist < _boomMaxR.toFloat()) {
                var actualDmg = dmg;
                if (pDist > _boomMaxR.toFloat() * 0.7 && dmg > 1) { actualDmg = 1; }
                _pHp -= actualDmg;
                if (_pHp < 0) { _pHp = 0; }
                _hitDmg = actualDmg;
                _hitMsg = (pDist < 8.0) ? "CRITICAL!" : "OUCH!";
                _dmgFloatX = _pX.toFloat(); _dmgFloatY = _pY.toFloat() - 22.0;
                _dmgFloatVal = actualDmg; _dmgFloatTick = 35;
            }
            if (aDist < _boomMaxR.toFloat() * 0.5) {
                _aHp -= 1;
                if (_aHp < 0) { _aHp = 0; }
            }
        }
        if (_hitDmg > 0) { _hitMsgTick = 40; }
        else if (_hitMsg.equals("")) { _hitMsg = _playerTurn ? "MISS!" : "DODGED!"; _hitMsgTick = 25; }

        applyBlobGravity();
    }

    hidden function carveCrater(centerPx, radius) {
        if (_w <= 0) { return; }
        var centerCol = centerPx * TERR_N / _w;
        var radiusCols = radius * TERR_N / _w + 1;
        for (var i = centerCol - radiusCols; i <= centerCol + radiusCols; i++) {
            if (i < 0 || i >= TERR_N) { continue; }
            var dist = (i - centerCol).abs();
            var frac = 1.0 - dist.toFloat() / (radiusCols + 1).toFloat();
            if (frac <= 0.0) { continue; }
            var dig = (frac * frac * radius * 0.6).toNumber();
            _terrH[i] -= dig;
            if (_terrH[i] < 8) { _terrH[i] = 8; }
        }
    }

    hidden function applyBlobGravity() {
        if (_w <= 0) { return; }
        var pCol = _pX * TERR_N / _w;
        if (pCol < 0) { pCol = 0; }
        if (pCol >= TERR_N) { pCol = TERR_N - 1; }
        _pY = terrainYAt(pCol);
        var aCol = _aX * TERR_N / _w;
        if (aCol < 0) { aCol = 0; }
        if (aCol >= TERR_N) { aCol = TERR_N - 1; }
        _aY = terrainYAt(aCol);
    }

    hidden function doMiss() {
        _projAlive = false;
        _hitMsg = _playerTurn ? "MISS!" : "DODGED!";
        _hitMsgTick = 25;
        afterExplosion();
    }

    hidden function afterExplosion() {
        if (_aHp <= 0) {
            gameState = GS_WIN;
            _resultTick = 0;
            if (_round > _bestStreak) {
                _bestStreak = _round;
                _newBest = true;
                Application.Storage.setValue("blobBest", _bestStreak);
            }
            doVibe(80, 200);
            spawnVictoryParticles();
            return;
        }
        if (_pHp <= 0) {
            gameState = GS_OVER;
            _resultTick = 0;
            var streak = _round - 1;
            if (streak > _bestStreak) {
                _bestStreak = streak;
                _newBest = true;
                Application.Storage.setValue("blobBest", _bestStreak);
            }
            doVibe(100, 300);
            return;
        }

        if (_playerTurn) {
            _playerTurn = false;
            _wind = _wind * 0.65 + (-0.8 + (Math.rand().abs() % 16).toFloat() / 10.0) * 0.35;
            gameState = GS_TURN;
            _turnTick = 0;
        } else {
            _playerTurn = true;
            _wind = _wind * 0.65 + (-0.8 + (Math.rand().abs() % 16).toFloat() / 10.0) * 0.35;
            gameState = GS_TURN;
            _turnTick = 0;
        }
    }

    hidden function spawnExplosionParticles(ex, ey) {
        var colors = [0xFF4422, 0xFFAA22, 0xFFDD44, 0xFF6622, 0xFFFFAA, 0xFF2211, 0xDD4411, 0xFFCC66];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 30) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat() + ((Math.rand().abs() % 7) - 3).toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.5 + (Math.rand().abs() % 40).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a);
            _partVy[i] = spd * Math.sin(a) - 2.5;
            _partLife[i] = 10 + Math.rand().abs() % 16;
            _partCol[i] = colors[Math.rand().abs() % 8];
            spawned++;
        }
    }

    hidden function spawnDirtParticles(ex, ey) {
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 5) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat();
            _partY[i] = ey.toFloat();
            _partVx[i] = ((Math.rand().abs() % 20) - 10).toFloat() / 10.0;
            _partVy[i] = -1.5 - (Math.rand().abs() % 15).toFloat() / 10.0;
            _partLife[i] = 6 + Math.rand().abs() % 6;
            _partCol[i] = 0x7A5A2A;
            spawned++;
        }
    }

    hidden function spawnSmokeTrail(sx, sy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] > 0) { continue; }
            _partX[i] = sx;
            _partY[i] = sy;
            _partVx[i] = ((Math.rand().abs() % 10) - 5).toFloat() / 10.0;
            _partVy[i] = -0.3 - (Math.rand().abs() % 5).toFloat() / 10.0;
            _partLife[i] = 5 + Math.rand().abs() % 4;
            _partCol[i] = 0x666666;
            return;
        }
    }

    hidden function spawnVictoryParticles() {
        var colors = [0x44FF44, 0xFFCC44, 0xFF6644, 0x44CCFF, 0xFFFFFF, 0xFF44FF];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 20) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = (_w / 4 + Math.rand().abs() % (_w / 2)).toFloat();
            _partY[i] = (_h / 2).toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 2.0 + (Math.rand().abs() % 30).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a);
            _partVy[i] = -spd * 1.5 - 1.0;
            _partLife[i] = 18 + Math.rand().abs() % 18;
            _partCol[i] = colors[Math.rand().abs() % 6];
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

    function doAction() {
        if (gameState == GS_MENU) {
            startRound();
        } else if (gameState == GS_AIM) {
            fireProjectile();
        } else if (gameState == GS_WIN) {
            if (_resultTick > 30) { startRound(); }
        } else if (gameState == GS_OVER) {
            if (_resultTick > 30) { _round = 0; _newBest = false; startRound(); }
        }
    }

    function doWeapon(dir) {
        if (gameState == GS_AIM) {
            _weapon = (_weapon + dir + 3) % 3;
            doVibe(15, 30);
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        if (gameState == GS_MENU) { drawMenu(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeOx;
        var oy = _shakeOy;

        drawSky(dc, ox, oy);
        drawTerrain(dc, ox, oy);

        var pWob = (Math.sin(_wobblePhase) * 1.2).toNumber();
        var aWob = (Math.sin(_wobblePhase + 1.5) * 1.2).toNumber();
        drawBlob(dc, _pX + ox, _pY + oy + pWob, _pHp, 0x4488FF, 0x2266DD, true);
        var eCols = [0xFF4444, 0xFF8844, 0xAA44FF, 0x44CCCC, 0xFFCC22];
        var eDark = [0xCC2222, 0xCC6622, 0x7722CC, 0x228888, 0xCC9911];
        var ei = _round % 5;
        drawBlob(dc, _aX + ox, _aY + oy + aWob, _aHp, eCols[ei], eDark[ei], false);
        drawParticles(dc, ox, oy);

        if (_projAlive) { drawProjectile(dc, ox, oy); }
        if (gameState == GS_BOOM && _boomTick <= 22) { drawExplosion(dc, ox, oy); }

        if (gameState == GS_AIM) {
            drawAimLine(dc, ox, oy);
            drawPowerBar(dc);
        }
        if (gameState == GS_AI) {
            drawAiThinking(dc);
        }
        if (gameState == GS_TURN) {
            drawTurnIndicator(dc);
        }

        drawHUD(dc);

        if (_hitMsgTick > 0) { drawHitMsg(dc); }
        if (_dmgFloatTick > 0) { drawDmgFloat(dc, ox, oy); }

        if (gameState == GS_INTRO) { drawIntro(dc); }
        if (gameState == GS_WIN) { drawWin(dc); }
        if (gameState == GS_OVER) { drawGameOver(dc); }
    }

    hidden function drawSky(dc, ox, oy) {
        var theme = _round % 5;
        var skyTop; var skyBot; var skyMid;
        if (theme == 0) { skyTop = 0x1A2844; skyBot = 0x3A5588; skyMid = 0x2A3A66; }
        else if (theme == 1) { skyTop = 0x441A2A; skyBot = 0x883A55; skyMid = 0x662A3A; }
        else if (theme == 2) { skyTop = 0x0A1A0A; skyBot = 0x2A4A2A; skyMid = 0x1A3A1A; }
        else if (theme == 3) { skyTop = 0x2A1A44; skyBot = 0x5A3A88; skyMid = 0x3A2A66; }
        else { skyTop = 0x332211; skyBot = 0x664422; skyMid = 0x553322; }
        dc.setColor(skyTop, skyTop);
        dc.clear();
        dc.setColor(skyBot, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 40 / 100, _w, _h * 60 / 100);
        dc.setColor(skyMid, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 28 / 100, _w, _h * 16 / 100);

        for (var i = 0; i < 6; i++) {
            var ca = 0.4 + 0.2 * Math.sin(_wobblePhase * 0.3 + i.toFloat());
            var cc = (ca > 0.5) ? 0x99BBCC : 0x7799AA;
            dc.setColor(cc, Graphics.COLOR_TRANSPARENT);
            var cy = _h * 13 / 100 + (i * 6);
            dc.fillCircle(_cloudX[i].toNumber() + ox, cy + oy, _cloudW[i] / 2);
            dc.fillCircle(_cloudX[i].toNumber() + _cloudW[i] / 3 + ox, cy - 2 + oy, _cloudW[i] / 3);
            dc.fillCircle(_cloudX[i].toNumber() - _cloudW[i] / 4 + ox, cy + 1 + oy, _cloudW[i] / 3);
        }

        dc.setColor(0xFFFFDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 82 / 100, _h * 7 / 100, 2);
        dc.fillCircle(_w * 15 / 100, _h * 4 / 100, 1);
        dc.fillCircle(_w * 45 / 100, _h * 9 / 100, 1);
        dc.fillCircle(_w * 68 / 100, _h * 3 / 100, 1);
        dc.fillCircle(_w * 55 / 100, _h * 6 / 100, 1);
    }

    hidden function drawTerrain(dc, ox, oy) {
        var colW = _w / TERR_N + 1;
        var theme = _round % 5;
        var grassCol;
        var dirtCol;
        var grassHi;
        if (theme == 0) { grassCol = 0x44AA44; dirtCol = 0x5A3A1A; grassHi = 0x55CC55; }
        else if (theme == 1) { grassCol = 0x888844; dirtCol = 0x5A4422; grassHi = 0xAAAA55; }
        else if (theme == 2) { grassCol = 0x228844; dirtCol = 0x3A2A10; grassHi = 0x44BB55; }
        else if (theme == 3) { grassCol = 0x667788; dirtCol = 0x3A3A4A; grassHi = 0x88AABB; }
        else { grassCol = 0xBB8844; dirtCol = 0x6A4A2A; grassHi = 0xDDAA55; }

        for (var i = 0; i < TERR_N; i++) {
            var x = i * _w / TERR_N + ox;
            var tY = _h - _terrH[i] + oy;

            dc.setColor(grassCol, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, tY, colW + 1, 3);

            dc.setColor(dirtCol, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, tY + 3, colW + 1, _h - tY + 5);

            if (i % 5 == 0) {
                dc.setColor(0x3A2210, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(x, tY + 6, x, _h + oy);
            }

            dc.setColor(grassHi, Graphics.COLOR_TRANSPARENT);
            if (i % 3 == 0) { dc.fillRectangle(x, tY - 1, 1, 2); }
            if (i % 7 == 0) { dc.fillRectangle(x + 1, tY - 2, 1, 3); }

            if (i % 21 == 7 && _terrH[i] > 35) {
                dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + 1, tY - 8, 2, 8);
                dc.setColor(0x228822, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x + 2, tY - 10, 4);
                dc.setColor(0x33AA33, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x + 1, tY - 11, 2);
            }
        }
    }

    hidden function drawBlob(dc, bx, by, hp, col, darkCol, isPlayer) {
        var blobR = 8;
        if (hp <= 0) { blobR = 6; }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx + 1, by - blobR + 1, blobR);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by - blobR, blobR);
        dc.setColor(darkCol, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by - blobR + 2, blobR - 2);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx - 2, by - blobR - 2, blobR / 2);

        if (hp <= 0) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bx - 4, by - blobR - 2, bx - 2, by - blobR);
            dc.drawLine(bx - 2, by - blobR - 2, bx - 4, by - blobR);
            dc.drawLine(bx + 2, by - blobR - 2, bx + 4, by - blobR);
            dc.drawLine(bx + 4, by - blobR - 2, bx + 2, by - blobR);
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 2, by - blobR + 4, 4, 2);
        } else {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            var eyeDir = isPlayer ? 2 : -2;
            if (gameState == GS_FLY && !_playerTurn && isPlayer) { eyeDir = -3; }
            if (gameState == GS_FLY && _playerTurn && !isPlayer) { eyeDir = 3; }
            dc.fillCircle(bx - 3, by - blobR - 1, 2);
            dc.fillCircle(bx + 3, by - blobR - 1, 2);
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx - 3 + eyeDir / 2, by - blobR - 1, 1);
            dc.fillCircle(bx + 3 + eyeDir / 2, by - blobR - 1, 1);

            if (hp == 1) {
                dc.setColor(0x66BBFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(bx + (isPlayer ? 6 : -6), by - blobR - 3, 2);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(bx - 2, by - blobR + 4, bx, by - blobR + 3);
                dc.drawLine(bx, by - blobR + 3, bx + 2, by - blobR + 4);
            } else {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx - 2, by - blobR + 3, 4, 1);
            }
        }

        var maxHpForBar = isPlayer ? MAX_HP : _aMaxHp;
        if (maxHpForBar < 1) { maxHpForBar = 1; }
        var barW = 20;
        var barX = bx - barW / 2;
        var barY = by - blobR * 2 - 7;
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX - 1, barY - 1, barW + 2, 5);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, 3);
        var fill = hp * barW / maxHpForBar;
        if (fill > barW) { fill = barW; }
        if (fill < 0) { fill = 0; }
        var bc = (hp > 2) ? 0x44FF44 : ((hp > 1) ? 0xFFCC44 : 0xFF4444);
        dc.setColor(bc, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, fill, 3);
    }

    hidden function drawAimLine(dc, ox, oy) {
        var rad = _aimAngle * 3.14159 / 180.0;
        var spdMul = wpnSpeed(_weapon);
        var pwr = _power / 100.0 * spdMul;
        var vx = pwr * Math.cos(rad);
        var vy = -pwr * Math.sin(rad);
        var px = _pX.toFloat();
        var py = _pY.toFloat() - 8.0;
        var grav = wpnGrav(_weapon);

        for (var t = 0; t < 20; t++) {
            var tx = px + vx * t.toFloat() * 0.7;
            var ty = py + vy * t.toFloat() * 0.7 + 0.5 * grav * t.toFloat() * t.toFloat() * 0.49;
            if (tx < 0.0 || tx > _w.toFloat() || ty > _h.toFloat()) { break; }
            if (t % 2 == 0) {
                var ac = (t < 6) ? 0xFFFFFF : 0xAAAABB;
                dc.setColor(ac, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(tx.toNumber() + ox, ty.toNumber() + oy, 2, 2);
            }
        }
    }

    hidden function drawPowerBar(dc) {
        var barW = _w * 30 / 100;
        var barX = (_w - barW) / 2;
        var barY = _h - 18;

        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX - 1, barY - 1, barW + 2, 7);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, 5);

        var fill = (_power / 100.0 * barW.toFloat()).toNumber();
        if (fill < 0) { fill = 0; }
        var bc = (_power > 80.0) ? 0xFF4444 : ((_power > 50.0) ? 0xFFCC44 : 0x44FF44);
        dc.setColor(bc, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, fill, 5);

        dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(barX + barW + 4, barY - 2, Graphics.FONT_XTINY, _power.toNumber() + "%", Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function drawProjectile(dc, ox, oy) {
        var px = _projX.toNumber() + ox;
        var py = _projY.toNumber() + oy;
        if (_projWeapon == WPN_ROCKET) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 3);
            dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 2);
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            var trail = (_projVx > 0.0) ? -2 : 2;
            dc.fillCircle(px + trail, py + 1, 2);
        } else if (_projWeapon == WPN_GRENADE) {
            dc.setColor(0x44AA44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 3);
            dc.setColor(0x55CC55, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - 1, py - 1, 2);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 1, py - 5, 2, 3);
        } else {
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 5);
            dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 4);
            dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 2);
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 1, py - 7, 2, 3);
            if (_tick % 4 < 2) {
                dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py - 7, 2);
            }
        }
    }

    hidden function drawExplosion(dc, ox, oy) {
        var ex = _boomX.toNumber() + ox;
        var ey = _boomY.toNumber() + oy;
        var r = _boomR;

        if (_boomTick < 5) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex, ey, r + 5);
        }
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex, ey, r);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex, ey, r * 3 / 4);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex, ey, r / 2);
        if (r > 2) {
            dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex, ey, r / 4);
        }
        if (_boomTick > 10) {
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex + 3, ey - 5, r / 3);
            dc.fillCircle(ex - 3, ey - 7, r / 4);
        }
    }

    hidden function drawParticles(dc, ox, oy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            dc.setColor(_partCol[i], Graphics.COLOR_TRANSPARENT);
            var sz = (_partLife[i] > 10) ? 3 : ((_partLife[i] > 5) ? 2 : 1);
            dc.fillRectangle(_partX[i].toNumber() + ox, _partY[i].toNumber() + oy, sz, sz);
        }
    }

    hidden function drawAiThinking(dc) {
        var dots = (_aiAimTick / 8) % 4;
        var wpnName = _wpnNames[_aiWpnDisplay];
        var msg = wpnName;
        for (var d = 0; d < dots; d++) { msg = msg + "."; }
        var ac = (_aiAimTick % 6 < 3) ? 0xFF6644 : 0xDD4422;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_aX + 1, _aY - 32, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(ac, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_aX, _aY - 33, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawTurnIndicator(dc) {
        var msg = _playerTurn ? "YOUR TURN!" : "ENEMY TURN";
        var mc = _playerTurn ? 0x44DDFF : 0xFF6644;
        var flash = (_turnTick % 6 < 3);
        if (!flash) { mc = _playerTurn ? 0x2299BB : 0xCC4422; }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 20 / 100, _h * 38 / 100, _w * 60 / 100, _h * 12 / 100);
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 38 / 100, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawHitMsg(dc) {
        var mc = 0xFFCC44;
        if (_hitMsg.find("DIRECT") != null || _hitMsg.find("CRITICAL") != null) { mc = 0xFF2222; }
        else if (_hitMsg.find("MISS") != null) { mc = 0x888888; }
        else if (_hitMsg.find("DODGED") != null) { mc = 0x44FF44; }
        else if (_hitMsg.find("SELF") != null) { mc = 0xFF8844; }
        else if (_hitMsg.find("OUCH") != null) { mc = 0xFF4444; }

        var scale = 1.0;
        if (_hitMsgTick > 35) { scale = 1.3; }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, _h * 28 / 100 + 1, Graphics.FONT_SMALL, _hitMsg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_SMALL, _hitMsg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawDmgFloat(dc, ox, oy) {
        var fc = (_dmgFloatVal >= 2) ? 0xFF2222 : 0xFFAA44;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_dmgFloatX.toNumber() + ox + 1, _dmgFloatY.toNumber() + oy + 1, Graphics.FONT_SMALL, "-" + _dmgFloatVal, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_dmgFloatX.toNumber() + ox, _dmgFloatY.toNumber() + oy, Graphics.FONT_SMALL, "-" + _dmgFloatVal, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawHUD(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(2, 2, 30, 14);
        dc.fillRectangle(_w - 32, 2, 30, 14);
        dc.fillRectangle(_w / 2 - 20, 1, 40, 12);

        dc.setColor(0x4488FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(8, 8, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(16, 2, Graphics.FONT_XTINY, "" + _pHp + "/" + MAX_HP, Graphics.TEXT_JUSTIFY_LEFT);

        var eCols = [0xFF4444, 0xFF8844, 0xAA44FF, 0x44CCCC, 0xFFCC22];
        var ei = _round % 5;
        dc.setColor(eCols[ei], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w - 8, 8, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 16, 2, Graphics.FONT_XTINY, "" + _aHp + "/" + _aMaxHp, Graphics.TEXT_JUSTIFY_RIGHT);

        var wStr;
        if (_wind > 0.6) { wStr = ">>>"; }
        else if (_wind > 0.25) { wStr = ">>"; }
        else if (_wind > 0.08) { wStr = ">"; }
        else if (_wind < -0.6) { wStr = "<<<"; }
        else if (_wind < -0.25) { wStr = "<<"; }
        else if (_wind < -0.08) { wStr = "<"; }
        else { wStr = "--"; }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, 2, Graphics.FONT_XTINY, wStr, Graphics.TEXT_JUSTIFY_CENTER);

        if (gameState == GS_AIM) {
            var wpnC;
            if (_weapon == WPN_ROCKET) { wpnC = 0xFF8844; }
            else if (_weapon == WPN_GRENADE) { wpnC = 0x44CC44; }
            else { wpnC = 0xFF2222; }

            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_w / 2 - 40, 14, 80, 12);
            dc.setColor(wpnC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, 14, Graphics.FONT_XTINY, "< " + _wpnNames[_weapon] + " >", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h - 28, Graphics.FONT_XTINY, _aimAngle.toNumber() + "\u00B0", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h - 8, Graphics.FONT_XTINY, "R" + _round, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawIntro(dc) {
        var bw = _w * 72 / 100;
        var bh = _h * 30 / 100;
        var bx = (_w - bw) / 2;
        var by = _h * 28 / 100;

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, by, bw, bh);
        dc.setColor(0x333355, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(bx, by, bw, bh);
        dc.drawRectangle(bx + 1, by + 1, bw - 2, bh - 2);

        var fc = (_introTick % 8 < 4) ? 0xFFCC44 : 0xFFAA22;
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by + 4, Graphics.FONT_MEDIUM, "ROUND " + _round, Graphics.TEXT_JUSTIFY_CENTER);

        if (_aMaxHp > MAX_HP) {
            dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, by + bh - 26, Graphics.FONT_XTINY, "Enemy HP: " + _aMaxHp, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by + bh - 14, Graphics.FONT_XTINY, "FIGHT!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawWin(dc) {
        var bw = _w * 82 / 100;
        var bh = _h * 50 / 100;
        var bx = (_w - bw) / 2;
        var by = _h * 18 / 100;

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, by, bw, bh);
        dc.setColor(0x225533, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(bx, by, bw, bh);
        dc.drawRectangle(bx + 1, by + 1, bw - 2, bh - 2);

        var fc = (_resultTick % 6 < 3) ? 0x44FF44 : 0x22DD22;
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by + 4, Graphics.FONT_MEDIUM, "VICTORY!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by + bh * 38 / 100, Graphics.FONT_XTINY, "Win streak: " + _round, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by + bh * 50 / 100, Graphics.FONT_XTINY, "Best: " + _bestStreak, Graphics.TEXT_JUSTIFY_CENTER);

        if (_newBest) {
            var nbc = (_resultTick % 4 < 2) ? 0xFFDD44 : 0xFF8822;
            dc.setColor(nbc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, by + bh * 62 / 100, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_resultTick > 30) {
            dc.setColor((_resultTick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, by + bh * 78 / 100, Graphics.FONT_XTINY, "Tap for next round", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawGameOver(dc) {
        var bw = _w * 82 / 100;
        var bh = _h * 52 / 100;
        var bx = (_w - bw) / 2;
        var by = _h * 18 / 100;

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, by, bw, bh);
        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(bx, by, bw, bh);
        dc.drawRectangle(bx + 1, by + 1, bw - 2, bh - 2);

        var fc = (_resultTick % 6 < 3) ? 0xFF4444 : 0xCC2222;
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by + 4, Graphics.FONT_MEDIUM, "DEFEATED", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var surv = _round - 1;
        if (surv < 0) { surv = 0; }
        dc.drawText(_w / 2, by + bh * 35 / 100, Graphics.FONT_XTINY, "Rounds won: " + surv, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by + bh * 47 / 100, Graphics.FONT_XTINY, "Best streak: " + _bestStreak, Graphics.TEXT_JUSTIFY_CENTER);

        if (_newBest && surv > 0) {
            var nbc = (_resultTick % 4 < 2) ? 0xFFDD44 : 0xFF8822;
            dc.setColor(nbc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, by + bh * 59 / 100, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_resultTick > 30) {
            dc.setColor((_resultTick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, by + bh * 75 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x1A2844, 0x1A2844);
        dc.clear();

        dc.setColor(0x3A5588, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 40 / 100, _w, _h);
        dc.setColor(0x44AA44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 58 / 100, _w, 3);
        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 61 / 100, _w, _h);

        dc.setColor(0xFFFFDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 82 / 100, _h * 8 / 100, 2);
        dc.fillCircle(_w * 15 / 100, _h * 12 / 100, 1);
        dc.fillCircle(_w * 50 / 100, _h * 5 / 100, 1);

        var tc = (_tick % 14 < 7) ? 0xFF6644 : 0xFF8866;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, _h * 5 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 5 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 18 / 100, Graphics.FONT_LARGE, "BLOBS", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 31 / 100, Graphics.FONT_XTINY, "Artillery Deathmatch", Graphics.TEXT_JUSTIFY_CENTER);

        var bx1 = _w * 30 / 100;
        var bx2 = _w * 70 / 100;
        var by = _h * 50 / 100;
        var mWob = (Math.sin(_wobblePhase * 0.8) * 2.0).toNumber();
        var mWob2 = (Math.sin(_wobblePhase * 0.8 + 2.0) * 2.0).toNumber();

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx1 + 1, by + mWob + 1, 8);
        dc.setColor(0x4488FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx1, by + mWob, 8);
        dc.setColor(0x2266DD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx1, by + mWob + 2, 6);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx1 - 2, by + mWob - 1, 2);
        dc.fillCircle(bx1 + 3, by + mWob - 1, 2);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx1, by + mWob - 1, 1);
        dc.fillCircle(bx1 + 4, by + mWob - 1, 1);

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx2 + 1, by + mWob2 + 1, 8);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx2, by + mWob2, 8);
        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx2, by + mWob2 + 2, 6);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx2 - 3, by + mWob2 - 1, 2);
        dc.fillCircle(bx2 + 2, by + mWob2 - 1, 2);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx2 - 4, by + mWob2 - 1, 1);
        dc.fillCircle(bx2 + 1, by + mWob2 - 1, 1);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by - 7, Graphics.FONT_SMALL, "VS", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x7799AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 62 / 100, Graphics.FONT_XTINY, "Tilt=aim  Tap=fire", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 69 / 100, Graphics.FONT_XTINY, "Up/Down = weapon", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestStreak > 0) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 78 / 100, Graphics.FONT_XTINY, "BEST STREAK: " + _bestStreak, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0xFF6644 : 0xFF8866, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to fight!", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
