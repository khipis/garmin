using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum {
    GS_MENU, GS_INTRO, GS_TURN, GS_MOVE,
    GS_AIM, GS_POWER, GS_FLY, GS_BOOM, GS_WIN, GS_OVER
}
enum { WPN_ROCKET, WPN_GRENADE, WPN_MEGA, WPN_SNIPER, WPN_MIRV, WPN_QUAKE, WPN_CLUSTER, WPN_PLASMA, WPN_NAPALM, WPN_NUKE, WPN_DRILL }
const WPN_COUNT = 11;

class BitochiBlobsView extends WatchUi.View {

    var gameState;
    var accelX;

    hidden var _w;
    hidden var _h;
    hidden var _timer;
    hidden var _tick;

    // TERR_N=130, each col = 4px world, mapW=520
    const TERR_N = 130;
    hidden var _terrH;
    hidden var _mapW;

    const MAX_BLOBS = 5;
    hidden var _blobCount;
    hidden var _bX;
    hidden var _bY;
    hidden var _bHp;
    hidden var _bMaxHp;
    hidden var _bAlive;
    hidden var _bCol;
    hidden var _bDark;
    hidden var _activeIdx;
    hidden var _kills;

    hidden var _weapon;
    hidden var _wpnNames;
    hidden var _wpnSpd;
    hidden var _wpnGrv;
    hidden var _wpnRad;
    hidden var _wpnDmg;
    hidden var _wpnWind;
    hidden var _wpnBounce;
    // -1 = unlimited (basic), >= 0 = uses remaining this round (special)
    hidden var _wpnAmmo;

    // Aim: phase 0 = angle oscillates (tap to lock), phase 1 = power oscillates (tap to fire)
    hidden var _aimPhase;
    hidden var _aimAngle;
    hidden var _aimAnglePhase;
    hidden var _power;
    hidden var _powerPhase;

    hidden var _projX;
    hidden var _projY;
    hidden var _projVx;
    hidden var _projVy;
    hidden var _projBounces;
    hidden var _projAlive;
    hidden var _projWeapon;
    hidden var _projBurrowing;

    hidden var _wind;

    hidden var _boomXs;
    hidden var _boomYs;
    hidden var _boomCount;
    hidden var _boomTick;
    hidden var _boomMaxR;
    hidden var _boomWeapon;
    hidden var _hitMsg;
    hidden var _hitMsgTick;

    const MAX_PARTS = 28;
    hidden var _partX;
    hidden var _partY;
    hidden var _partVx;
    hidden var _partVy;
    hidden var _partLife;
    hidden var _partCol;

    hidden var _round;
    hidden var _bestStreak;
    hidden var _newBest;
    hidden var _winnerPlayer; // -1=all won, 0=P1, 1=P2 (meaningful in 2P mode)
    hidden var _introTick;
    hidden var _resultTick;
    hidden var _turnTick;

    hidden var _shakeT;
    hidden var _shakeOx;
    hidden var _shakeOy;

    hidden var _camX;
    hidden var _camTarget;

    hidden var _moveDist;
    hidden const MOVE_MAX = 40.0;
    hidden var _moveTick;
    hidden var _hopCount;
    hidden var _hopCooldown;
    hidden var _aiMoveTarget;

    hidden var _aiTick;
    hidden var _aiAngle;
    hidden var _aiPower;
    hidden var _aiTarget;
    hidden var _aiWpn;

    hidden var _dmgFloatX;
    hidden var _dmgFloatY;
    hidden var _dmgFloatV;
    hidden var _dmgFloatT;

    hidden var _wobble;
    hidden var _cloudX;
    hidden var _cloudS;

    hidden var _twoPlayer;
    hidden var _menuSel;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _tick = 0;
        accelX = 0;
        gameState = GS_MENU;

        _mapW = TERR_N * 4;
        _terrH = new [TERR_N];
        for (var i = 0; i < TERR_N; i++) { _terrH[i] = _h / 2; }

        _bX = new [MAX_BLOBS]; _bY = new [MAX_BLOBS];
        _bHp = new [MAX_BLOBS]; _bMaxHp = new [MAX_BLOBS];
        _bAlive = new [MAX_BLOBS];
        _bCol  = [0x44AAFF, 0xFF3333, 0xFFAA22, 0xCC44FF, 0x44EEDD];
        _bDark = [0x2277DD, 0xDD1111, 0xDD7700, 0x9922DD, 0x22AABB];
        for (var i = 0; i < MAX_BLOBS; i++) {
            _bX[i] = 0.0; _bY[i] = 0.0; _bHp[i] = 0; _bMaxHp[i] = 0; _bAlive[i] = false;
        }
        _blobCount = 3; _activeIdx = 0; _kills = 0;

        _wpnNames  = ["ROCKET", "GRENADE", "MEGA", "SNIPER", "MIRV", "QUAKE", "CLUSTER", "PLASMA", "NAPALM", "NUKE", "DRILL"];
        _wpnSpd    = [8.5,  7.0,  6.0, 13.0,  7.0, 7.5,  7.0, 14.0,  6.5, 5.0, 12.0];
        _wpnGrv    = [0.10, 0.12, 0.14, 0.06, 0.11, 0.15, 0.09, 0.03, 0.13, 0.08, 0.04];
        _wpnRad    = [20,   26,   36,   12,   16,   50,   12,   7,    14,   55,   24];
        _wpnDmg    = [1,    1,    2,    1,    1,    1,    1,    3,    1,    2,    2];
        _wpnWind   = [1.0,  1.0,  1.0,  0.2,  1.0,  0.8,  0.9,  0.1,  1.2,  0.5,  0.3];
        _wpnBounce = [0,    2,    0,    0,    0,    0,    0,    0,    0,    0,    0];
        // -1=unlimited (basic): ROCKET,GRENADE,SNIPER,CLUSTER; 1=one use/round (special): MEGA,MIRV,QUAKE,PLASMA,NAPALM,NUKE,DRILL
        // Per-player ammo: _wpnAmmo[playerIdx][weaponIdx]; -1 = unlimited
        _wpnAmmo = [[-1, -1, 1, -1, 1, 1, -1, 1, 1, 1, 1],
                    [-1, -1, 1, -1, 1, 1, -1, 1, 1, 1, 1]];
        _weapon = WPN_ROCKET;

        _aimPhase = 0; _aimAnglePhase = 0.0;
        _aimAngle = 45.0; _powerPhase = 0.0; _power = 60.0;
        _projX = 0.0; _projY = 0.0; _projVx = 0.0; _projVy = 0.0;
        _projBounces = 0; _projAlive = false; _projWeapon = 0; _projBurrowing = false;
        _wind = 0.0;

        _boomXs = new [5]; _boomYs = new [5];
        for (var i = 0; i < 5; i++) { _boomXs[i] = 0.0; _boomYs[i] = 0.0; }
        _boomCount = 1; _boomTick = 0; _boomMaxR = 20; _boomWeapon = 0;
        _hitMsg = ""; _hitMsgTick = 0;

        _partX = new [MAX_PARTS]; _partY = new [MAX_PARTS];
        _partVx = new [MAX_PARTS]; _partVy = new [MAX_PARTS];
        _partLife = new [MAX_PARTS]; _partCol = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) {
            _partX[i] = 0.0; _partY[i] = 0.0; _partVx[i] = 0.0; _partVy[i] = 0.0;
            _partLife[i] = 0; _partCol[i] = 0;
        }

        _round = 0; _winnerPlayer = -1;
        var bs = Application.Storage.getValue("blobBest");
        _bestStreak = (bs != null) ? bs : 0;
        _newBest = false;
        _introTick = 0; _resultTick = 0; _turnTick = 0;
        _shakeT = 0; _shakeOx = 0; _shakeOy = 0;
        _camX = 0.0; _camTarget = 0.0;
        _moveDist = 0.0; _moveTick = 0;
        _hopCount = 0; _hopCooldown = 0; _aiMoveTarget = 0.0;
        _aiTick = 0; _aiAngle = 45.0; _aiPower = 60.0; _aiTarget = 1; _aiWpn = 0;
        _dmgFloatX = 0.0; _dmgFloatY = 0.0; _dmgFloatV = 0; _dmgFloatT = 0;
        _wobble = 0.0;

        _cloudX = new [4]; _cloudS = new [4];
        for (var i = 0; i < 4; i++) {
            _cloudX[i] = (Math.rand().abs() % _w).toFloat();
            _cloudS[i] = 0.1 + (Math.rand().abs() % 8).toFloat() / 20.0;
        }

        _twoPlayer = false;
        _menuSel = 0;
    }

    hidden function isHumanTurn() {
        return (_activeIdx == 0 || (_twoPlayer && _activeIdx == 1));
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 50, true);
    }
    function onHide() { if (_timer != null) { _timer.stop(); _timer = null; } }

    function onTick() as Void {
        _tick++;
        _wobble += 0.12;
        for (var i = 0; i < 4; i++) {
            _cloudX[i] += _cloudS[i];
            if (_cloudX[i] > _mapW + 20) { _cloudX[i] = -20.0; }
        }
        if (_shakeT > 0) {
            _shakeOx = (Math.rand().abs() % 9) - 4;
            _shakeOy = (Math.rand().abs() % 7) - 3;
            _shakeT--;
        } else { _shakeOx = 0; _shakeOy = 0; }
        if (_hitMsgTick > 0) { _hitMsgTick--; }
        if (_dmgFloatT > 0) { _dmgFloatT--; _dmgFloatY -= 0.8; }

        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            _partVy[i] += 0.18;
            _partX[i] += _partVx[i];
            _partY[i] += _partVy[i];
            _partLife[i]--;
        }

        _camX += (_camTarget - _camX) * 0.16;
        if (_camX < 0.0) { _camX = 0.0; }
        var maxCam = (_mapW - _w).toFloat();
        if (maxCam < 0.0) { maxCam = 0.0; }
        if (_camX > maxCam) { _camX = maxCam; }

        if (gameState == GS_INTRO) {
            _introTick++;
            if (_introTick > 28) { beginTurn(); }
        } else if (gameState == GS_TURN) {
            _turnTick++;
            _camTarget = _bX[_activeIdx] - _w.toFloat() / 2.0;
            if (_turnTick > 14) {
                gameState = GS_MOVE; _moveDist = 0.0; _moveTick = 0;
            }
        } else if (gameState == GS_MOVE) {
            _moveTick++;
            _camTarget = _bX[_activeIdx] - _w.toFloat() / 2.0;
            if (isHumanTurn()) {
                if (_hopCooldown > 0) { _hopCooldown--; }
                if (_hopCount < 2 && _hopCooldown == 0) {
                    var steer = accelX.toFloat() / 280.0;
                    if (steer > 1.8) {
                        var nx = _bX[_activeIdx] + 20.0;
                        if (nx > _mapW.toFloat() - 10.0) { nx = _mapW.toFloat() - 10.0; }
                        _bX[_activeIdx] = nx; updateBlobY(_activeIdx);
                        _hopCount++; _hopCooldown = 11; doVibe(25, 40);
                    } else if (steer < -1.8) {
                        var nx = _bX[_activeIdx] - 20.0;
                        if (nx < 10.0) { nx = 10.0; }
                        _bX[_activeIdx] = nx; updateBlobY(_activeIdx);
                        _hopCount++; _hopCooldown = 11; doVibe(25, 40);
                    }
                }
                if (_hopCount >= 2) {
                    gameState = GS_AIM; _aimPhase = 0; _aimAnglePhase = 0.0;
                }
                if (_moveTick > 55) {
                    gameState = GS_AIM; _aimPhase = 0; _aimAnglePhase = 0.0;
                }
            } else {
                if (_moveTick == 1) { aiDecideMove(); }
                var dx = _aiMoveTarget - _bX[_activeIdx];
                if (dx.abs() > 2.0 && _moveTick >= 2 && _moveTick <= 14) {
                    var step = (dx > 0.0) ? 4.0 : -4.0;
                    if (dx.abs() < 4.0) { step = dx; }
                    _bX[_activeIdx] += step;
                    updateBlobY(_activeIdx);
                }
                if (_moveTick >= 11) {
                    _bX[_activeIdx] = _aiMoveTarget;
                    updateBlobY(_activeIdx);
                    gameState = GS_AIM;
                    _aiTick = 0;
                    aiCalcShot();
                }
            }
        } else if (gameState == GS_AIM) {
            if (isHumanTurn()) {
                // Phase 0: full 360° clockwise rotation (~3.5s/rev)
                _aimAnglePhase += 0.055;
                if (_aimAnglePhase >= 6.28318) { _aimAnglePhase -= 6.28318; }
                _aimAngle = _aimAnglePhase * 180.0 / 3.14159;
            } else {
                _aiTick++;
                if (_aiTick >= 18) { aiFireShot(); }
            }
        } else if (gameState == GS_POWER) {
            if (isHumanTurn()) {
                // Phase 1: power oscillates 15–95%
                _powerPhase += 0.11;
                _power = 55.0 + 40.0 * Math.sin(_powerPhase);
            }
        } else if (gameState == GS_FLY) {
            updateProjectile();
            _camTarget = _projX - _w.toFloat() / 2.0;
        } else if (gameState == GS_BOOM) {
            _boomTick++;
            if (_boomTick > 20) { afterBoom(); }
        } else if (gameState == GS_WIN || gameState == GS_OVER) {
            _resultTick++;
        }

        WatchUi.requestUpdate();
    }

    hidden function generateTerrain() {
        var baseH = _h * 38 / 100;
        var f1 = 0.025 + (Math.rand().abs() % 20).toFloat() / 1000.0;
        var f2 = 0.06 + (Math.rand().abs() % 30).toFloat() / 1000.0;
        var a1 = 12.0 + (Math.rand().abs() % 18).toFloat();
        var a2 = 5.0 + (Math.rand().abs() % 10).toFloat();
        var p1 = (Math.rand().abs() % 628).toFloat() / 100.0;
        var p2 = (Math.rand().abs() % 628).toFloat() / 100.0;
        for (var i = 0; i < TERR_N; i++) {
            var x = i.toFloat();
            _terrH[i] = baseH + (Math.sin(x * f1 + p1) * a1).toNumber()
                               + (Math.sin(x * f2 + p2) * a2).toNumber()
                               + (Math.rand().abs() % 5) - 2;
            if (_terrH[i] < 20) { _terrH[i] = 20; }
            if (_terrH[i] > _h * 62 / 100) { _terrH[i] = _h * 62 / 100; }
        }
        for (var b = 0; b < _blobCount; b++) {
            var center = blobSpawnCol(b);
            var avg = 0; var cnt = 0;
            for (var i = center - 3; i <= center + 3; i++) {
                if (i >= 0 && i < TERR_N) { avg += _terrH[i]; cnt++; }
            }
            if (cnt > 0) { avg = avg / cnt; }
            for (var i = center - 3; i <= center + 3; i++) {
                if (i >= 0 && i < TERR_N) { _terrH[i] = avg; }
            }
        }
    }

    hidden function blobSpawnCol(idx) {
        var spacing = TERR_N / (_blobCount + 1);
        return spacing * (idx + 1);
    }

    hidden function terrYAtCol(col) {
        if (col < 0) { col = 0; }
        if (col >= TERR_N) { col = TERR_N - 1; }
        return _h - _terrH[col];
    }

    hidden function worldXToCol(wx) {
        if (_mapW <= 0) { return 0; }
        var col = (wx * TERR_N / _mapW).toNumber();
        if (col < 0) { col = 0; }
        if (col >= TERR_N) { col = TERR_N - 1; }
        return col;
    }

    hidden function terrYAtWorld(wx) {
        return terrYAtCol(worldXToCol(wx));
    }

    hidden function updateBlobY(idx) {
        _bY[idx] = terrYAtWorld(_bX[idx]).toFloat();
    }

    hidden function startRound() {
        _round++;
        if (_round <= 2) { _blobCount = 3; }
        else if (_round <= 5) { _blobCount = 4; }
        else { _blobCount = 5; }
        if (_blobCount > MAX_BLOBS) { _blobCount = MAX_BLOBS; }

        generateTerrain();
        for (var i = 0; i < MAX_BLOBS; i++) {
            _bAlive[i] = (i < _blobCount);
            if (i < _blobCount) {
                var col = blobSpawnCol(i);
                _bX[i] = (col * _mapW / TERR_N).toFloat();
                _bY[i] = terrYAtCol(col).toFloat();
                var isPlayerBlob = (i == 0 || (_twoPlayer && i == 1));
                if (isPlayerBlob) {
                    _bHp[i] = 3; _bMaxHp[i] = 3;
                } else {
                    var ehp = 2;
                    if (_round >= 5) { ehp = 3; }
                    if (_round >= 9) { ehp = 4; }
                    _bHp[i] = ehp; _bMaxHp[i] = ehp;
                }
            } else { _bHp[i] = 0; _bMaxHp[i] = 0; }
        }
        _activeIdx = 0;
        _weapon = WPN_ROCKET;
        // Reset per-player special weapon ammo each round
        for (var p = 0; p < 2; p++) {
            for (var i = 0; i < WPN_COUNT; i++) {
                if (_wpnAmmo[p][i] != -1) { _wpnAmmo[p][i] = 1; }
            }
        }
        _aimAngle = 45.0; _aimPhase = 0; _aimAnglePhase = 0.0; _powerPhase = 0.0;
        _projAlive = false; _projBurrowing = false;
        _newBest = false; _kills = 0; _winnerPlayer = -1;
        _wind = -1.0 + (Math.rand().abs() % 20).toFloat() / 10.0;
        _hitMsg = ""; _hitMsgTick = 0; _dmgFloatT = 0;
        for (var i = 0; i < MAX_PARTS; i++) { _partLife[i] = 0; }
        _camX = _bX[0] - _w.toFloat() / 2.0;
        _camTarget = _camX;
        gameState = GS_INTRO; _introTick = 0;
    }

    hidden function beginTurn() {
        gameState = GS_TURN; _turnTick = 0;
        _hopCount = 0; _hopCooldown = 0;
        _aimPhase = 0; _aimAnglePhase = 0.0; _powerPhase = 0.0;
        _camTarget = _bX[_activeIdx] - _w.toFloat() / 2.0;
        // If this player's current weapon is depleted, switch to next available
        if (isHumanTurn()) {
            var btPIdx = (_twoPlayer && _activeIdx == 1) ? 1 : 0;
            if (_wpnAmmo[btPIdx][_weapon] == 0) {
                for (var w = 0; w < WPN_COUNT; w++) {
                    var next = (_weapon + 1 + w) % WPN_COUNT;
                    if (_wpnAmmo[btPIdx][next] != 0) { _weapon = next; break; }
                }
            }
        }
    }

    hidden function nextTurn() {
        _wind = _wind * 0.6 + (-0.8 + (Math.rand().abs() % 16).toFloat() / 10.0) * 0.4;
        var start = _activeIdx;
        for (var i = 1; i < _blobCount; i++) {
            var idx = (start + i) % _blobCount;
            if (_bAlive[idx] && _bHp[idx] > 0) { _activeIdx = idx; beginTurn(); return; }
        }
        for (var i = 0; i < _blobCount; i++) {
            if (_bAlive[i] && _bHp[i] > 0) { _activeIdx = i; beginTurn(); return; }
        }
    }

    hidden function fireShot() {
        var rad = _aimAngle * 3.14159 / 180.0;
        var spd = _wpnSpd[_weapon];
        var pwr = _power / 100.0 * spd;
        _projX = _bX[_activeIdx]; _projY = _bY[_activeIdx] - 8.0;
        _projVx = pwr * Math.cos(rad);
        _projVy = -pwr * Math.sin(rad);
        _projBounces = 0; _projAlive = true;
        _projBurrowing = false;
        _projWeapon = _weapon;
        // Consume one use from active player's ammo if it's a limited special weapon
        var fpIdx = (_twoPlayer && _activeIdx == 1) ? 1 : 0;
        if (_wpnAmmo[fpIdx][_weapon] > 0) { _wpnAmmo[fpIdx][_weapon]--; }
        gameState = GS_FLY;
        doVibe(30, 50);
    }

    hidden function aiDecideMove() {
        var numHops = Math.rand().abs() % 3;
        var dir = (_bX[0] < _bX[_activeIdx]) ? -1.0 : 1.0;
        if (Math.rand().abs() % 4 == 0) { dir = -dir; }
        var moveAmt = numHops.toFloat() * 20.0 * dir;
        _aiMoveTarget = _bX[_activeIdx] + moveAmt;
        if (_aiMoveTarget < 10.0) { _aiMoveTarget = 10.0; }
        if (_aiMoveTarget > _mapW.toFloat() - 10.0) { _aiMoveTarget = _mapW.toFloat() - 10.0; }
    }

    hidden function aiCalcShot() {
        var targets = [];
        for (var i = 0; i < _blobCount; i++) {
            if (i != _activeIdx && _bAlive[i] && _bHp[i] > 0) { targets = targets.add(i); }
        }
        if (targets.size() == 0) { return; }
        _aiTarget = targets[0];
        if (_bAlive[0] && _bHp[0] > 0 && Math.rand().abs() % 100 < 65) { _aiTarget = 0; }
        else { _aiTarget = targets[Math.rand().abs() % targets.size()]; }

        var r = Math.rand().abs() % 100;
        if (_bHp[_aiTarget] <= 1 && _round >= 4) {
            if (r < 20) { _aiWpn = WPN_PLASMA; }
            else if (r < 38) { _aiWpn = WPN_MEGA; }
            else if (r < 55) { _aiWpn = WPN_NUKE; }
            else if (r < 70) { _aiWpn = WPN_MIRV; }
            else { _aiWpn = WPN_ROCKET; }
        } else {
            if (r < 22) { _aiWpn = WPN_ROCKET; }
            else if (r < 38) { _aiWpn = WPN_GRENADE; }
            else if (r < 50) { _aiWpn = WPN_SNIPER; }
            else if (r < 60) { _aiWpn = WPN_MIRV; }
            else if (r < 68) { _aiWpn = WPN_CLUSTER; }
            else if (r < 75) { _aiWpn = WPN_QUAKE; }
            else if (r < 82) { _aiWpn = WPN_NAPALM; }
            else if (r < 90) { _aiWpn = WPN_DRILL; }
            else { _aiWpn = WPN_PLASMA; }
        }

        var dx = (_bX[_aiTarget] - _bX[_activeIdx]).toFloat();
        var dy = (_bY[_aiTarget] - _bY[_activeIdx]).toFloat();
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < 1.0) { dist = 1.0; }

        // Full directional angle: atan2(-dy, dx) gives correct angle for
        // the physics formula: vx = cos(rad), vy = -sin(rad)
        var ang = Math.atan2(-dy, dx) * 180.0 / 3.14159;
        if (ang < 0.0) { ang += 360.0; }
        // Wind adjustment (helps right-facing, hinders left-facing)
        var windAdj = _wind * dist * 0.003;
        if (dx < 0.0) { windAdj = -windAdj; }
        ang += windAdj;
        // Clamp to above-ground range (5°-175°)
        if (ang < 5.0) { ang = 5.0; }
        if (ang > 175.0) { ang = 175.0; }
        var errS = 22.0 - _round.toFloat() * 1.3;
        if (errS < 4.0) { errS = 4.0; }
        var eN = errS.toNumber(); if (eN < 1) { eN = 1; }
        _aiAngle = ang + ((Math.rand().abs() % (eN * 2 + 1)) - eN).toFloat();
        if (_aiAngle < 5.0) { _aiAngle = 5.0; }
        if (_aiAngle > 175.0) { _aiAngle = 175.0; }
        var idealP = 38.0 + dist * 0.22;
        if (idealP > 92.0) { idealP = 92.0; }
        var pE = eN / 2; if (pE < 1) { pE = 1; }
        _aiPower = idealP + ((Math.rand().abs() % (pE * 2 + 1)) - pE).toFloat();
        if (_aiPower < 30.0) { _aiPower = 30.0; }
        if (_aiPower > 95.0) { _aiPower = 95.0; }
    }

    hidden function aiFireShot() {
        var rad = _aiAngle * 3.14159 / 180.0;
        var spd = _wpnSpd[_aiWpn];
        var pwr = _aiPower / 100.0 * spd;
        _projX = _bX[_activeIdx]; _projY = _bY[_activeIdx] - 8.0;
        _projVx = pwr * Math.cos(rad);
        _projVy = -pwr * Math.sin(rad);
        _projBounces = 0; _projAlive = true; _projBurrowing = false;
        _projWeapon = _aiWpn;
        gameState = GS_FLY;
        doVibe(30, 50);
    }

    hidden function updateProjectile() {
        var grav = _wpnGrv[_projWeapon];
        var wf = _wpnWind[_projWeapon];
        _projVy += grav;
        _projVx += _wind * 0.004 * wf;
        _projX += _projVx;
        _projY += _projVy;

        // Smoke trail - spawn every 5 ticks for performance
        if (_tick % 5 == 0) { spawnSmoke(_projX, _projY); }

        if (_projX < -20.0 || _projX > (_mapW + 20).toFloat() || _projY > (_h + 40).toFloat()) {
            _projAlive = false;
            _hitMsg = (_activeIdx == 0) ? "MISS!" : "DODGED!";
            _hitMsgTick = 25;
            afterBoom();
            return;
        }

        var tY = terrYAtWorld(_projX).toFloat();
        if (_projY >= tY) {
            var bn = _wpnBounce[_projWeapon];
            if (bn > 0 && _projBounces < bn) {
                _projVy = -_projVy * 0.55; _projVx = _projVx * 0.7;
                _projY = tY - 2.0; _projBounces++;
                doVibe(20, 30); spawnDirt(_projX, tY);
                return;
            }
            // DRILL: burrow underground before exploding
            if (_projWeapon == WPN_DRILL && !_projBurrowing) {
                _projBurrowing = true;
                doHit(_projX, tY + 18.0);
                return;
            }
            doHit(_projX, tY);
            return;
        }

        for (var i = 0; i < _blobCount; i++) {
            if (!_bAlive[i] || _bHp[i] <= 0) { continue; }
            if (i == _activeIdx) { continue; }
            var d = Math.sqrt((_projX - _bX[i]) * (_projX - _bX[i]) +
                              (_projY - (_bY[i] - 6.0)) * (_projY - (_bY[i] - 6.0)));
            if (d < 10.0) { doHit(_projX, _projY); return; }
        }
    }

    hidden function doHit(hx, hy) {
        _projAlive = false;
        _boomTick = 0;
        _boomMaxR = _wpnRad[_projWeapon];
        _boomWeapon = _projWeapon;
        var dmg = _wpnDmg[_projWeapon];

        if (_projWeapon == WPN_MIRV) {
            _boomCount = 3;
            _boomXs[0] = hx - 22.0; _boomYs[0] = hy;
            _boomXs[1] = hx;         _boomYs[1] = hy;
            _boomXs[2] = hx + 22.0; _boomYs[2] = hy;
            for (var e = 0; e < 3; e++) {
                var ey = terrYAtWorld(_boomXs[e]).toFloat();
                if (_boomYs[e] > ey) { _boomYs[e] = ey; }
                carveCrater(_boomXs[e], _boomMaxR);
                spawnBoom(_boomXs[e].toNumber(), _boomYs[e].toNumber());
                applyDmgAt(_boomXs[e], _boomYs[e], _boomMaxR.toFloat(), dmg);
            }
            _shakeT = 14; doVibe(80, 200);
        } else if (_projWeapon == WPN_QUAKE) {
            _boomCount = 1;
            _boomXs[0] = hx; _boomYs[0] = hy;
            carveCrater(hx, _boomMaxR);
            spawnBoom(hx.toNumber(), hy.toNumber());
            for (var i = 0; i < _blobCount; i++) {
                if (!_bAlive[i] || _bHp[i] <= 0) { continue; }
                var hdist = (_bX[i] - hx).abs();
                if (hdist < _boomMaxR.toFloat()) {
                    _bHp[i] -= dmg; if (_bHp[i] < 0) { _bHp[i] = 0; }
                    if (i != _activeIdx) { _hitMsg = "QUAKE HIT!"; _hitMsgTick = 35; }
                }
            }
            _shakeT = 18; doVibe(100, 300);
        } else if (_projWeapon == WPN_CLUSTER) {
            _boomCount = 5;
            for (var e = 0; e < 5; e++) {
                _boomXs[e] = hx + ((e - 2) * 22).toFloat();
                _boomYs[e] = terrYAtWorld(_boomXs[e]).toFloat();
                carveCrater(_boomXs[e], _boomMaxR);
                spawnBoom(_boomXs[e].toNumber(), _boomYs[e].toNumber());
                applyDmgAt(_boomXs[e], _boomYs[e], _boomMaxR.toFloat(), dmg);
            }
            _shakeT = 14; doVibe(90, 230);
        } else if (_projWeapon == WPN_NAPALM) {
            _boomCount = 5;
            for (var e = 0; e < 5; e++) {
                _boomXs[e] = hx + ((e - 2) * 28).toFloat();
                _boomYs[e] = terrYAtWorld(_boomXs[e]).toFloat();
                carveCrater(_boomXs[e], _boomMaxR);
                spawnBoom(_boomXs[e].toNumber(), _boomYs[e].toNumber());
                applyDmgAt(_boomXs[e], _boomYs[e], _boomMaxR.toFloat(), dmg);
            }
            _shakeT = 12; doVibe(85, 200);
        } else if (_projWeapon == WPN_NUKE) {
            _boomCount = 1;
            _boomXs[0] = hx; _boomYs[0] = hy;
            carveCrater(hx, _boomMaxR);
            spawnBoom(hx.toNumber(), hy.toNumber());
            applyDmgAt(hx, hy, _boomMaxR.toFloat(), dmg);
            applyDmgAt(hx, hy, (_boomMaxR * 1.5).toFloat(), 1);
            _shakeT = 24; doVibe(100, 400);
        } else if (_projWeapon == WPN_DRILL) {
            _boomCount = 1;
            _boomXs[0] = hx; _boomYs[0] = hy;
            carveCrater(hx, _boomMaxR);
            spawnBoom(hx.toNumber(), hy.toNumber());
            applyDmgAt(hx, hy, _boomMaxR.toFloat(), dmg);
            _shakeT = 12; doVibe(80, 180);
        } else if (_projWeapon == WPN_PLASMA) {
            _boomCount = 1;
            _boomXs[0] = hx; _boomYs[0] = hy;
            carveCrater(hx, _boomMaxR);
            spawnBoom(hx.toNumber(), hy.toNumber());
            applyDmgAt(hx, hy, _boomMaxR.toFloat(), dmg);
            _shakeT = 6; doVibe(80, 140);
        } else {
            _boomCount = 1;
            _boomXs[0] = hx; _boomYs[0] = hy;
            carveCrater(hx, _boomMaxR);
            spawnBoom(hx.toNumber(), hy.toNumber());
            applyDmgAt(hx, hy, _boomMaxR.toFloat(), dmg);
            if (_projWeapon == WPN_MEGA) { _shakeT = 16; doVibe(100, 260); }
            else { _shakeT = 8; doVibe(60, 120); }
        }

        applyAllBlobGravity();
        gameState = GS_BOOM;
    }

    hidden function applyDmgAt(ex, ey, radius, dmg) {
        var anyHit = false;
        for (var i = 0; i < _blobCount; i++) {
            if (!_bAlive[i] || _bHp[i] <= 0) { continue; }
            var d = Math.sqrt((ex - _bX[i]) * (ex - _bX[i]) +
                              (ey - (_bY[i] - 6.0)) * (ey - (_bY[i] - 6.0)));
            if (d < radius) {
                var actualDmg = dmg;
                if (d > radius * 0.7 && dmg > 1) { actualDmg = 1; }
                _bHp[i] -= actualDmg; if (_bHp[i] < 0) { _bHp[i] = 0; }
                if (i != _activeIdx) {
                    anyHit = true;
                    _hitMsg = (d < 8.0) ? "DIRECT HIT!" : "HIT!";
                    _hitMsgTick = 35;
                    _dmgFloatX = _bX[i]; _dmgFloatY = _bY[i] - 22.0;
                    _dmgFloatV = actualDmg; _dmgFloatT = 30;
                } else {
                    if (!anyHit) { _hitMsg = "SELF HIT!"; _hitMsgTick = 30; }
                }
            }
        }
    }

    hidden function carveCrater(cx, radius) {
        var centerCol = worldXToCol(cx);
        var rCols = radius * TERR_N / _mapW + 1;

        // Depth based on weapon type
        var depth;
        if (_projWeapon == WPN_NUKE)    { depth = 2.4; }
        else if (_projWeapon == WPN_MEGA)  { depth = 1.6; }
        else if (_projWeapon == WPN_DRILL) { depth = 1.8; }
        else if (_projWeapon == WPN_QUAKE) { depth = 0.3; }
        else if (_projWeapon == WPN_NAPALM){ depth = 0.7; }
        else { depth = 0.9; }

        // Main crater
        for (var i = centerCol - rCols; i <= centerCol + rCols; i++) {
            if (i < 0 || i >= TERR_N) { continue; }
            var dist = (i - centerCol).abs();
            var frac = 1.0 - dist.toFloat() / (rCols + 1).toFloat();
            if (frac <= 0.0) { continue; }
            var dig = (frac * frac * radius * depth).toNumber();
            _terrH[i] -= dig;
            if (_terrH[i] < 5) { _terrH[i] = 5; }
        }

        // Secondary blast marks: roughen terrain further out
        var secR = rCols * 2 + 1;
        for (var i = centerCol - secR; i <= centerCol + secR; i++) {
            if (i < 0 || i >= TERR_N) { continue; }
            var dist2 = (i - centerCol).abs();
            if (dist2 <= rCols) { continue; }
            var frac2 = 1.0 - dist2.toFloat() / (secR + 1).toFloat();
            if (frac2 <= 0.0) { continue; }
            var roughen = (frac2 * radius * depth * 0.32).toNumber();
            if (roughen < 1) { roughen = 1; }
            var rnd = Math.rand().abs() % (roughen + 1);
            _terrH[i] -= rnd;
            if (_terrH[i] < 5) { _terrH[i] = 5; }
        }
    }

    hidden function applyAllBlobGravity() {
        for (var i = 0; i < _blobCount; i++) { if (_bAlive[i]) { updateBlobY(i); } }
    }

    hidden function afterBoom() {
        var enemyStart = _twoPlayer ? 2 : 1;
        // Mark all dead blobs
        if (_bAlive[0] && _bHp[0] <= 0) { _bAlive[0] = false; }
        if (_twoPlayer && _bAlive[1] && _bHp[1] <= 0) { _bAlive[1] = false; }
        for (var i = enemyStart; i < _blobCount; i++) {
            if (_bAlive[i] && _bHp[i] <= 0) { _bAlive[i] = false; _kills++; }
        }

        if (_twoPlayer) {
            // 2P FFA: last blob standing wins — players fight each other AND AI.
            var aliveCount = 0; var lastAlive = -1;
            for (var i = 0; i < _blobCount; i++) {
                if (_bAlive[i]) { aliveCount++; lastAlive = i; }
            }
            if (aliveCount <= 1) {
                if (lastAlive == 0 || lastAlive == 1) {
                    // A player is the last blob — they win the round
                    _winnerPlayer = lastAlive;
                    gameState = GS_WIN; _resultTick = 0;
                    if (_round > _bestStreak) { _bestStreak = _round; _newBest = true; Application.Storage.setValue("blobBest", _bestStreak); }
                    doVibe(80, 200); spawnVictory();
                } else {
                    // All player blobs eliminated (or everyone dead)
                    gameState = GS_OVER; _resultTick = 0;
                    var s = _round - 1; if (s < 0) { s = 0; }
                    if (s > _bestStreak) { _bestStreak = s; _newBest = true; Application.Storage.setValue("blobBest", _bestStreak); }
                    doVibe(100, 300);
                }
                return;
            }
            // Both players dead but AI still alive → immediate game over
            if (!_bAlive[0] && !_bAlive[1]) {
                gameState = GS_OVER; _resultTick = 0;
                var s2 = _round - 1; if (s2 < 0) { s2 = 0; }
                if (s2 > _bestStreak) { _bestStreak = s2; _newBest = true; Application.Storage.setValue("blobBest", _bestStreak); }
                doVibe(100, 300); return;
            }
            nextTurn();
        } else {
            // 1P: kill every enemy to win; player death = game over
            var anyEnemyAlive = false;
            for (var i = 1; i < _blobCount; i++) { if (_bAlive[i]) { anyEnemyAlive = true; break; } }
            if (!anyEnemyAlive && _bAlive[0]) {
                _winnerPlayer = 0;
                gameState = GS_WIN; _resultTick = 0;
                if (_round > _bestStreak) { _bestStreak = _round; _newBest = true; Application.Storage.setValue("blobBest", _bestStreak); }
                doVibe(80, 200); spawnVictory(); return;
            }
            if (!_bAlive[0]) {
                gameState = GS_OVER; _resultTick = 0;
                var streak = _round - 1; if (streak < 0) { streak = 0; }
                if (streak > _bestStreak) { _bestStreak = streak; _newBest = true; Application.Storage.setValue("blobBest", _bestStreak); }
                doVibe(100, 300); return;
            }
            nextTurn();
        }
    }

    hidden function spawnBoom(ex, ey) {
        var isNapalm = (_boomWeapon == WPN_NAPALM);
        var isNuke   = (_boomWeapon == WPN_NUKE);
        var colors;
        if (isNapalm) { colors = [0xFF6600, 0xFF8800, 0xFFCC00, 0xFF4400, 0xFFAA00]; }
        else if (isNuke) { colors = [0xFFFFAA, 0xFFFF44, 0xFF8822, 0xFF4411, 0xFFFFFF]; }
        else { colors = [0xFF4422, 0xFFAA22, 0xFFDD44, 0xFF6622, 0xFFFFAA, 0xFF2211]; }
        var nColors = (isNapalm || isNuke) ? 5 : 6;
        var nSpawn = isNuke ? 16 : 12;
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= nSpawn) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat() + ((Math.rand().abs() % 7) - 3).toFloat();
            _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.8 + (Math.rand().abs() % 40).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a);
            _partVy[i] = spd * Math.sin(a) - 2.8;
            _partLife[i] = 12 + Math.rand().abs() % 16;
            _partCol[i] = colors[Math.rand().abs() % nColors];
            spawned++;
        }
    }

    hidden function spawnDirt(dx, dy) {
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 5) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = dx; _partY[i] = dy;
            _partVx[i] = ((Math.rand().abs() % 20) - 10).toFloat() / 10.0;
            _partVy[i] = -1.6 - (Math.rand().abs() % 10).toFloat() / 10.0;
            _partLife[i] = 5 + Math.rand().abs() % 6;
            _partCol[i] = 0x7A5A2A; spawned++;
        }
    }

    hidden function spawnSmoke(sx, sy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] > 0) { continue; }
            _partX[i] = sx; _partY[i] = sy;
            _partVx[i] = ((Math.rand().abs() % 8) - 4).toFloat() / 10.0;
            _partVy[i] = -0.3;
            _partLife[i] = 4 + Math.rand().abs() % 3;
            _partCol[i] = 0x666666;
            return;
        }
    }

    hidden function spawnVictory() {
        var colors = [0x44FF44, 0xFFCC44, 0xFF6644, 0x44CCFF, 0xFFFFFF];
        var cx = _bX[0]; var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 14) { break; }
            if (_partLife[i] > 0) { continue; }
            _partX[i] = cx + ((Math.rand().abs() % 40) - 20).toFloat();
            _partY[i] = _bY[0] - 10.0;
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 2.0 + (Math.rand().abs() % 25).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a); _partVy[i] = -spd * 1.5;
            _partLife[i] = 18 + Math.rand().abs() % 16;
            _partCol[i] = colors[Math.rand().abs() % 5]; spawned++;
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) { if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
        } }
    }

    function doAction() {
        if (gameState == GS_MENU) { _twoPlayer = (_menuSel == 1); startRound(); }
        else if (gameState == GS_MOVE && isHumanTurn()) {
            gameState = GS_AIM; _aimPhase = 0; _aimAnglePhase = 0.0;
        }
        else if (gameState == GS_AIM && isHumanTurn()) {
            // Lock angle, enter power phase
            _aimPhase = 1; _powerPhase = 0.0;
            gameState = GS_POWER;
            doVibe(18, 25);
        }
        else if (gameState == GS_POWER && isHumanTurn()) {
            var apIdx = (_twoPlayer && _activeIdx == 1) ? 1 : 0;
            if (_wpnAmmo[apIdx][_weapon] != 0) { fireShot(); }
        }
        else if (gameState == GS_WIN) { if (_resultTick > 30) { startRound(); } }
        else if (gameState == GS_OVER) { if (_resultTick > 30) { _round = 0; _newBest = false; startRound(); } }
    }

    function doWeapon(dir) {
        if (gameState == GS_MENU) {
            _menuSel = (_menuSel + dir + 2) % 2;
            doVibe(15, 30);
            return;
        }
        if ((gameState == GS_AIM || gameState == GS_POWER) && isHumanTurn()) {
            // Cycle, skipping specials that are depleted for this player
            var wpIdx = (_twoPlayer && _activeIdx == 1) ? 1 : 0;
            var next = (_weapon + dir + WPN_COUNT) % WPN_COUNT;
            var tried = 0;
            while (_wpnAmmo[wpIdx][next] == 0 && tried < WPN_COUNT) {
                next = (next + dir + WPN_COUNT) % WPN_COUNT;
                tried++;
            }
            _weapon = next;
            doVibe(15, 30);
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        if (gameState == GS_MENU) { drawMenu(dc); return; }
        drawGame(dc);
    }

    hidden function sx(worldX) { return (worldX - _camX).toNumber(); }

    hidden function drawGame(dc) {
        var ox = _shakeOx; var oy = _shakeOy;
        drawSky(dc, ox, oy);
        drawTerrain(dc, ox, oy);

        for (var i = 0; i < _blobCount; i++) {
            if (!_bAlive[i] && _bHp[i] <= 0 && gameState != GS_BOOM) { continue; }
            var bsx = sx(_bX[i]) + ox;
            var wob = ((_tick / 4 + i * 3) % 5) - 2;
            drawBlob(dc, bsx, _bY[i].toNumber() + oy + wob, _bHp[i], _bMaxHp[i], _bCol[i], _bDark[i], i == _activeIdx);
        }

        drawParticles(dc, ox, oy);
        if (_projAlive) { drawProjectile(dc, ox, oy); }

        if (gameState == GS_BOOM) {
            var phase = _boomTick;
            for (var e = 0; e < _boomCount; e++) {
                var eTick = phase - e * 3;
                if (eTick > 0 && eTick < 20) {
                    var r = eTick * _boomMaxR / 12;
                    if (r > _boomMaxR) { r = _boomMaxR; }
                    drawExplosion(dc, sx(_boomXs[e]) + ox, _boomYs[e].toNumber() + oy, r, eTick);
                }
            }
        }

        if ((gameState == GS_AIM || gameState == GS_POWER) && isHumanTurn()) {
            if (gameState == GS_AIM) { drawAngleSelector(dc, ox, oy); }
            if (gameState == GS_POWER) { drawAimLine(dc, ox, oy); drawPowerBar(dc); }
        }
        if ((gameState == GS_AIM || gameState == GS_POWER) && !isHumanTurn()) { drawAiThinking(dc); }
        if (gameState == GS_MOVE && _activeIdx == 0) { drawMoveBar(dc); }
        if (gameState == GS_TURN) { drawTurnLabel(dc); }

        drawOffscreenArrows(dc);
        drawHUD(dc);
        drawMinimap(dc);

        if (_hitMsgTick > 0) { drawHitMsg(dc); }
        if (_dmgFloatT > 0) { drawDmgFloat(dc, ox, oy); }
        if (gameState == GS_INTRO) { drawIntro(dc); }
        if (gameState == GS_WIN) { drawWin(dc); }
        if (gameState == GS_OVER) { drawGameOver(dc); }
    }

    hidden function drawSky(dc, ox, oy) {
        var t = _round % 5;
        var s1; var s2; var s3;
        if (t == 0) { s1 = 0x1A2844; s2 = 0x3A5588; s3 = 0x2A3A66; }
        else if (t == 1) { s1 = 0x441A2A; s2 = 0x883A55; s3 = 0x662A3A; }
        else if (t == 2) { s1 = 0x0A1A0A; s2 = 0x2A4A2A; s3 = 0x1A3A1A; }
        else if (t == 3) { s1 = 0x2A1A44; s2 = 0x5A3A88; s3 = 0x3A2A66; }
        else { s1 = 0x332211; s2 = 0x664422; s3 = 0x553322; }
        dc.setColor(s1, s1); dc.clear();
        dc.setColor(s2, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 40 / 100, _w, _h);
        dc.setColor(s3, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 28 / 100, _w, _h * 16 / 100);

        for (var i = 0; i < 4; i++) {
            var csx = sx(_cloudX[i]).toNumber() + ox;
            if (csx < -30 || csx > _w + 30) { continue; }
            dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
            var cy = _h * 12 / 100 + (i * 7);
            dc.fillRectangle(csx - 7, cy - 5 + oy, 20, 10); dc.fillRectangle(csx - 2, cy - 9 + oy, 10, 6);
        }
    }

    hidden function drawTerrain(dc, ox, oy) {
        // TERR_N=130, 4 world px per col → startCol from camX/4
        var startCol = (_camX / 4.0).toNumber() - 1;
        if (startCol < 0) { startCol = 0; }
        var endCol = startCol + _w / 4 + 3;
        if (endCol > TERR_N) { endCol = TERR_N; }

        var theme = _round % 5;
        var gC; var dC; var gH;
        if (theme == 0) { gC = 0x44AA44; dC = 0x5A3A1A; gH = 0x55CC55; }
        else if (theme == 1) { gC = 0x888844; dC = 0x5A4422; gH = 0xAAAA55; }
        else if (theme == 2) { gC = 0x228844; dC = 0x3A2A10; gH = 0x44BB55; }
        else if (theme == 3) { gC = 0x667788; dC = 0x3A3A4A; gH = 0x88AABB; }
        else { gC = 0xBB8844; dC = 0x6A4A2A; gH = 0xDDAA55; }

        for (var i = startCol; i < endCol; i++) {
            var wx = i * 4;
            var screenX = sx(wx) + ox;
            var tY = _h - _terrH[i] + oy;
            dc.setColor(gC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(screenX, tY, 5, 3);
            dc.setColor(dC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(screenX, tY + 3, 5, _h - tY + 5);
            if (i % 4 == 0) { dc.setColor(gH, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(screenX, tY - 1, 1, 2); }
            if (i % 16 == 5 && _terrH[i] > 44) {
                dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(screenX + 1, tY - 8, 3, 8);
                dc.setColor(0x228822, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(screenX + 2, tY - 10, 4);
            }
        }
    }

    hidden function drawBlob(dc, bx, by, hp, maxHp, col, darkCol, isActive) {
        if (bx < -_w || bx > _w * 2) { return; }
        var r = (hp > 0) ? 8 : 6;
        var d = r * 2;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawRectangle(bx - r, by - d, d, d);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx - r + 1, by - d + 1, d, d);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx - r, by - d, d, d);
        dc.setColor(darkCol, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx - r + 2, by - d + 2, d - 4, d - 4);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx - r - 1, by - d - 2, r / 2 + 1, r / 2 + 1);

        if (hp <= 0) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bx - 4, by - r - 2, bx - 2, by - r); dc.drawLine(bx - 2, by - r - 2, bx - 4, by - r);
            dc.drawLine(bx + 2, by - r - 2, bx + 4, by - r); dc.drawLine(bx + 4, by - r - 2, bx + 2, by - r);
        } else {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx - 5, by - r - 3, 4, 4); dc.fillRectangle(bx + 1, by - r - 3, 4, 4);
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx - 4, by - r - 2, 2, 2); dc.fillRectangle(bx + 2, by - r - 2, 2, 2);
            if (hp == 1) { dc.setColor(0x66BBFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx + 4, by - r - 5, 4, 4); }
            if (hp >= 2) { dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx - 2, by - r + 3, 4, 1); }
        }
        if (isActive && (gameState == GS_MOVE || gameState == GS_AIM || gameState == GS_POWER || gameState == GS_TURN)) {
            var ac = (_tick % 8 < 4) ? 0xFFFFFF : 0xFFCC44;
            dc.setColor(ac, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 1, by - r * 2 - 10, 2, 4);
            dc.fillRectangle(bx - 2, by - r * 2 - 9, 4, 2);
        }
        if (maxHp < 1) { maxHp = 1; }
        var bW = 18; var bxBar = bx - bW / 2; var bY = by - r * 2 - 5;
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bxBar - 1, bY - 1, bW + 2, 4);
        var fill = hp * bW / maxHp; if (fill > bW) { fill = bW; } if (fill < 0) { fill = 0; }
        var bc = (hp > 2) ? 0x44FF44 : ((hp > 1) ? 0xFFCC44 : 0xFF4444);
        dc.setColor(bc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bxBar, bY, fill, 2);
    }

    hidden function drawProjectile(dc, ox, oy) {
        var px = sx(_projX) + ox; var py = _projY.toNumber() + oy;
        if (px < -12 || px > _w + 12) { return; }
        if (_projWeapon == WPN_SNIPER) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 2);
            dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px, py, px + (_projVx > 0.0 ? -4 : 4), py);
        } else if (_projWeapon == WPN_MIRV) {
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 3);
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px - 2, py - 2, 2); dc.fillCircle(px + 2, py - 2, 2);
        } else if (_projWeapon == WPN_QUAKE) {
            dc.setColor(0x886644, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 4);
            dc.setColor(0xAA8855, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 3);
        } else if (_projWeapon == WPN_GRENADE) {
            dc.setColor(0x44AA44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 3);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 1, py - 5, 2, 3);
        } else if (_projWeapon == WPN_MEGA) {
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 5);
            dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 2);
            if (_tick % 4 < 2) { dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py - 6, 2); }
        } else if (_projWeapon == WPN_CLUSTER) {
            dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 4);
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px - 3, py - 2, 2); dc.fillCircle(px + 3, py - 2, 2); dc.fillCircle(px, py - 4, 2);
        } else if (_projWeapon == WPN_PLASMA) {
            dc.setColor(0x001144, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 5);
            dc.setColor(0x22CCFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 4);
            dc.setColor(0xAAFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 2);
            if (_tick % 3 < 2) { dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 1); }
        } else if (_projWeapon == WPN_NAPALM) {
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 4);
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 3);
            if (_tick % 3 < 2) { dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py - 4, 2); dc.fillCircle(px - 3, py - 2, 1); dc.fillCircle(px + 3, py - 2, 1); }
        } else if (_projWeapon == WPN_NUKE) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 7);
            dc.setColor(0x882222, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 5);
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 3);
            if (_tick % 5 < 3) { dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py - 8, 3); dc.fillCircle(px - 5, py - 5, 2); dc.fillCircle(px + 5, py - 5, 2); }
        } else if (_projWeapon == WPN_DRILL) {
            // Silver elongated drill
            var ang = Math.atan2(_projVy, _projVx);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 4);
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 3);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px + (_projVx > 0 ? 4 : -4), py, 2);
            if (_tick % 2 == 0) { dc.setColor(0xFFAA44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px - (_projVx > 0 ? 2 : -2), py, 1); }
        } else {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 3);
            dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 2);
        }
    }

    hidden function drawExplosion(dc, ex, ey, r, eTick) {
        if (eTick < 4) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r + 5);
        }
        if (_boomWeapon == WPN_NAPALM) {
            dc.setColor(0xFF6600, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r);
            dc.setColor(0xFF9900, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r * 3 / 4);
            dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r / 2);
            if (eTick > 8) { dc.setColor(0xCC2200, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey - r / 2, r / 3); }
        } else if (_boomWeapon == WPN_NUKE) {
            dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r);
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r * 3 / 4);
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r / 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r / 4);
            // Shockwave ring
            if (eTick > 4 && eTick < 16) { dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT); dc.drawCircle(ex, ey, r + eTick * 2); }
            if (eTick > 10) { dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex + 4, ey - r * 3 / 4, r / 2); dc.fillCircle(ex - 6, ey - r, r / 3); }
        } else if (_boomWeapon == WPN_DRILL) {
            dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r);
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r * 3 / 4);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r / 2);
            // Upward dirt geyser
            for (var gu = 1; gu <= 3; gu++) { dc.setColor(0x7A5A2A, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex + (gu - 2) * 5, ey - r * gu / 2, 3); }
        } else {
            dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r);
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r * 3 / 4);
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex, ey, r / 2);
            if (eTick > 10) { dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ex + 3, ey - 5, r / 3); }
        }
    }

    hidden function drawParticles(dc, ox, oy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            var psx = sx(_partX[i]) + ox;
            if (psx < -5 || psx > _w + 5) { continue; }
            dc.setColor(_partCol[i], Graphics.COLOR_TRANSPARENT);
            var sz = (_partLife[i] > 8) ? 3 : ((_partLife[i] > 4) ? 2 : 1);
            dc.fillRectangle(psx, _partY[i].toNumber() + oy, sz, sz);
        }
    }

    hidden function drawAngleSelector(dc, ox, oy) {
        var bsx = sx(_bX[_activeIdx]).toNumber() + ox;
        var bsy = _bY[_activeIdx].toNumber() + oy - 8;
        var rad = _aimAngle * 3.14159 / 180.0;
        var len = 32;
        var ex = bsx + (len.toFloat() * Math.cos(rad)).toNumber();
        var ey = bsy - (len.toFloat() * Math.sin(rad)).toNumber();

        // Full circle guide (dim)
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(bsx, bsy, 28);

        // Direction line
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(bsx, bsy, ex, ey);
        // Arrow head
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex, ey, 3);

        // Angle display — show as compass: 0=R, 90=U, 180=L
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bsx + 1, bsy - 28, Graphics.FONT_SMALL, _aimAngle.toNumber() + "\u00B0", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 8 < 4) ? 0xFFDD44 : 0xFFBB22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bsx, bsy - 29, Graphics.FONT_SMALL, _aimAngle.toNumber() + "\u00B0", Graphics.TEXT_JUSTIFY_CENTER);

        // Instruction at bottom
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w / 2 - 42, _h - 28, 84, 14);
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h - 28, Graphics.FONT_XTINY, "Tap = lock angle", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawAimLine(dc, ox, oy) {
        var rad = _aimAngle * 3.14159 / 180.0;
        var spd = _wpnSpd[_weapon];
        var pwr = _power / 100.0 * spd;
        var vx = pwr * Math.cos(rad);
        var vy = -pwr * Math.sin(rad);
        var grav = _wpnGrv[_weapon];
        var px = _bX[_activeIdx]; var py = _bY[_activeIdx] - 8.0;
        for (var t = 0; t < 22; t++) {
            var tx = px + vx * t.toFloat() * 0.7;
            var ty = py + vy * t.toFloat() * 0.7 + 0.5 * grav * t.toFloat() * t.toFloat() * 0.49;
            var tsx = sx(tx) + ox;
            if (tsx < 0 || tsx > _w || ty > _h.toFloat()) { break; }
            if (t % 2 == 0) {
                dc.setColor((t < 8) ? 0xFFFFFF : 0x999999, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(tsx, ty.toNumber() + oy, 2, 2);
            }
        }
    }

    hidden function drawPowerBar(dc) {
        var bW = _w * 28 / 100; var bx = (_w - bW) / 2; var by = _h - 18;
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx - 1, by - 1, bW + 2, 7);
        var fill = (_power / 100.0 * bW.toFloat()).toNumber(); if (fill < 0) { fill = 0; }
        var bc = (_power > 80.0) ? 0xFF4444 : ((_power > 50.0) ? 0xFFCC44 : 0x44FF44);
        dc.setColor(bc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx, by, fill, 5);
        dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bx + bW + 4, by - 2, Graphics.FONT_XTINY, _power.toNumber() + "%", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w / 2 - 38, by - 12, 76, 12);
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by - 12, Graphics.FONT_XTINY, "Tap = FIRE!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawMoveBar(dc) {
        var hopsLeft = 2 - _hopCount;
        var hopStr = (hopsLeft == 2) ? "HOPS: oo  Tilt" : ((hopsLeft == 1) ? "HOP: o  Tilt" : "No hops");
        dc.setColor(0x44DDFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h - 26, Graphics.FONT_XTINY, hopStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x448888, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h - 14, Graphics.FONT_XTINY, "Tap=aim", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawAiThinking(dc) {
        var dots = (_aiTick / 8) % 4; var msg = _wpnNames[_aiWpn];
        for (var d = 0; d < dots; d++) { msg = msg + "."; }
        var bsx = sx(_bX[_activeIdx]);
        dc.setColor((_aiTick % 6 < 3) ? 0xFF6644 : 0xDD4422, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bsx, _bY[_activeIdx].toNumber() - 34, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawTurnLabel(dc) {
        var msg; var mc;
        if (_activeIdx == 0) {
            msg = _twoPlayer ? "PLAYER 1!" : "YOUR TURN!";
            mc = (_turnTick % 6 < 3) ? 0x44DDFF : 0x2299BB;
        } else if (_twoPlayer && _activeIdx == 1) {
            msg = "PLAYER 2!";
            mc = (_turnTick % 6 < 3) ? 0x44FF88 : 0x22DD66;
        } else {
            msg = "ENEMY #" + _activeIdx;
            mc = (_turnTick % 6 < 3) ? 0xFF6644 : 0xCC4422;
        }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w * 18 / 100, _h * 38 / 100, _w * 64 / 100, _h * 12 / 100);
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 38 / 100, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawHitMsg(dc) {
        var mc = 0xFFCC44;
        if (_hitMsg.find("DIRECT") != null) { mc = 0xFF2222; }
        else if (_hitMsg.find("MISS") != null) { mc = 0x888888; }
        else if (_hitMsg.find("DODGED") != null) { mc = 0x44FF44; }
        else if (_hitMsg.find("SELF") != null) { mc = 0xFF8844; }
        else if (_hitMsg.find("QUAKE") != null) { mc = 0xFFAA22; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 26 / 100 + 1, Graphics.FONT_SMALL, _hitMsg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(mc, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 26 / 100, Graphics.FONT_SMALL, _hitMsg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawDmgFloat(dc, ox, oy) {
        var fsx = sx(_dmgFloatX) + ox;
        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(fsx, _dmgFloatY.toNumber() + oy, Graphics.FONT_SMALL, "-" + _dmgFloatV, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawHUD(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, 0, _w, 14);
        dc.setColor(_bCol[0], Graphics.COLOR_TRANSPARENT); dc.fillCircle(6, 7, 4);
        var p0Label = _twoPlayer ? "P1:" + _bHp[0] : "" + _bHp[0];
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(14, 1, Graphics.FONT_XTINY, p0Label, Graphics.TEXT_JUSTIFY_LEFT);
        var xOff = _twoPlayer ? 42 : 30;
        for (var i = 1; i < _blobCount; i++) {
            if (!_bAlive[i]) { continue; }
            dc.setColor(_bCol[i], Graphics.COLOR_TRANSPARENT); dc.fillCircle(xOff, 7, 3);
            if (_twoPlayer && i == 1) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(xOff + 6, 1, Graphics.FONT_XTINY, "P2:" + _bHp[i], Graphics.TEXT_JUSTIFY_LEFT);
                xOff += 36;
            } else {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(xOff + 6, 1, Graphics.FONT_XTINY, "" + _bHp[i], Graphics.TEXT_JUSTIFY_LEFT);
                xOff += 22;
            }
        }
        var wStr;
        if (_wind > 0.4) { wStr = ">>"; } else if (_wind > 0.12) { wStr = ">"; }
        else if (_wind < -0.4) { wStr = "<<"; } else if (_wind < -0.12) { wStr = "<"; }
        else { wStr = "--"; }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w - 4, 1, Graphics.FONT_XTINY, wStr, Graphics.TEXT_JUSTIFY_RIGHT);

        if ((gameState == GS_AIM || gameState == GS_POWER) && isHumanTurn()) {
            var wpnC;
            if      (_weapon == WPN_ROCKET)  { wpnC = 0xFF8844; }
            else if (_weapon == WPN_GRENADE) { wpnC = 0x44CC44; }
            else if (_weapon == WPN_MEGA)    { wpnC = 0xFF2222; }
            else if (_weapon == WPN_SNIPER)  { wpnC = 0xCCDDFF; }
            else if (_weapon == WPN_MIRV)    { wpnC = 0xFFCC44; }
            else if (_weapon == WPN_QUAKE)   { wpnC = 0xBB8844; }
            else if (_weapon == WPN_CLUSTER) { wpnC = 0xFF8822; }
            else if (_weapon == WPN_PLASMA)  { wpnC = 0x22CCFF; }
            else if (_weapon == WPN_NAPALM)  { wpnC = 0xFF6600; }
            else if (_weapon == WPN_NUKE)    { wpnC = 0xFF4444; }
            else { wpnC = 0xCCCCCC; }  // DRILL
            var hudPIdx = (_twoPlayer && _activeIdx == 1) ? 1 : 0;
            var wpnLabel;
            if (_wpnAmmo[hudPIdx][_weapon] == -1) {
                wpnLabel = "< " + _wpnNames[_weapon] + " >";
            } else {
                wpnLabel = "< " + _wpnNames[_weapon] + " [1x] >";
            }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w / 2 - 50, 13, 100, 12);
            dc.setColor(wpnC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, 13, Graphics.FONT_XTINY, wpnLabel, Graphics.TEXT_JUSTIFY_CENTER);
            if (gameState == GS_AIM) {
                dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h - 30, Graphics.FONT_XTINY, "AIM", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w / 2 - 18, _h - 16, 36, 14);
        dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h - 16, Graphics.FONT_XTINY, "Round " + _round, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawOffscreenArrows(dc) {
        for (var i = 0; i < _blobCount; i++) {
            if (!_bAlive[i] || _bHp[i] <= 0) { continue; }
            var bsx = sx(_bX[i]);
            if (bsx >= 0 && bsx <= _w) { continue; }
            var ay = _bY[i].toNumber(); if (ay < 28) { ay = 28; } if (ay > _h - 28) { ay = _h - 28; }
            var pulse = (_tick % 6 < 3); var arrowCol = pulse ? _bCol[i] : 0xFFFFFF;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            if (bsx < 0) {
                dc.fillPolygon([[2, ay], [14, ay - 7], [14, ay + 7]]);
                dc.setColor(arrowCol, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[3, ay], [12, ay - 5], [12, ay + 5]]);
                dc.setColor(_bCol[i], Graphics.COLOR_TRANSPARENT); dc.fillCircle(18, ay, 5);
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(18, ay, 3);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(18, ay - 6, Graphics.FONT_XTINY, "" + _bHp[i], Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.fillPolygon([[_w - 2, ay], [_w - 14, ay - 7], [_w - 14, ay + 7]]);
                dc.setColor(arrowCol, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[_w - 3, ay], [_w - 12, ay - 5], [_w - 12, ay + 5]]);
                dc.setColor(_bCol[i], Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w - 18, ay, 5);
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w - 18, ay, 3);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w - 18, ay - 6, Graphics.FONT_XTINY, "" + _bHp[i], Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden function drawMinimap(dc) {
        var mW = _w * 50 / 100; var mH = 6; var mx = (_w - mW) / 2; var my = _h - 8;
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(mx - 1, my - 1, mW + 2, mH + 2);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(mx, my, mW, mH);
        var camFrac = _camX / (_mapW - _w).toFloat();
        if (camFrac < 0.0) { camFrac = 0.0; } if (camFrac > 1.0) { camFrac = 1.0; }
        var viewW = mW * _w / _mapW; if (viewW < 6) { viewW = 6; }
        var viewX = mx + (camFrac * (mW - viewW).toFloat()).toNumber();
        dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(viewX, my, viewW, mH);
        for (var i = 0; i < _blobCount; i++) {
            if (!_bAlive[i] || _bHp[i] <= 0) { continue; }
            var bFrac = _bX[i] / _mapW.toFloat();
            var dotX = mx + (bFrac * mW.toFloat()).toNumber();
            dc.setColor(_bCol[i], Graphics.COLOR_TRANSPARENT); dc.fillRectangle(dotX - 1, my, 3, mH);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(dotX, my + 1, 1, mH - 2);
        }
    }

    hidden function drawIntro(dc) {
        var bw = _w * 74 / 100; var bh = _h * 36 / 100; var bx = (_w - bw) / 2; var by = _h * 26 / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx, by, bw, bh);
        dc.setColor(0x333355, Graphics.COLOR_TRANSPARENT); dc.drawRectangle(bx, by, bw, bh);
        dc.setColor((_introTick % 8 < 4) ? 0xFFCC44 : 0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by + 4, Graphics.FONT_MEDIUM, "ROUND " + _round, Graphics.TEXT_JUSTIFY_CENTER);
        if (_twoPlayer) {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, by + bh * 36 / 100, Graphics.FONT_XTINY, "2 PLAYER MODE", Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by + bh * 58 / 100, Graphics.FONT_XTINY, _blobCount + " BLOBS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by + bh - 10, Graphics.FONT_XTINY, "FIGHT!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawWin(dc) {
        var bw = _w * 82 / 100; var bh = _h * 50 / 100; var bx = (_w - bw) / 2; var by = _h * 18 / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx, by, bw, bh);
        dc.setColor(0x225533, Graphics.COLOR_TRANSPARENT); dc.drawRectangle(bx, by, bw, bh);
        var victoryLine;
        if (_twoPlayer) {
            if (_winnerPlayer == 0)      { victoryLine = "P1 WINS!"; }
            else if (_winnerPlayer == 1) { victoryLine = "P2 WINS!"; }
            else                         { victoryLine = "VICTORY!"; }
        } else { victoryLine = "VICTORY!"; }
        dc.setColor((_resultTick % 6 < 3) ? 0x44FF44 : 0x22DD22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by + 4, Graphics.FONT_MEDIUM, victoryLine, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by + bh * 35 / 100, Graphics.FONT_XTINY, "Streak: " + _round + "  Kills: " + _kills, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by + bh * 48 / 100, Graphics.FONT_XTINY, "Best: " + _bestStreak, Graphics.TEXT_JUSTIFY_CENTER);
        if (_newBest) { dc.setColor((_resultTick % 4 < 2) ? 0xFFDD44 : 0xFF8822, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by + bh * 60 / 100, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER); }
        if (_resultTick > 30) { dc.setColor((_resultTick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by + bh * 78 / 100, Graphics.FONT_XTINY, "Tap for next round", Graphics.TEXT_JUSTIFY_CENTER); }
    }

    hidden function drawGameOver(dc) {
        var bw = _w * 82 / 100; var bh = _h * 52 / 100; var bx = (_w - bw) / 2; var by = _h * 18 / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx, by, bw, bh);
        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT); dc.drawRectangle(bx, by, bw, bh);
        dc.setColor((_resultTick % 6 < 3) ? 0xFF4444 : 0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, by + 4, Graphics.FONT_MEDIUM, "DEFEATED", Graphics.TEXT_JUSTIFY_CENTER);
        var surv = _round - 1; if (surv < 0) { surv = 0; }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by + bh * 32 / 100, Graphics.FONT_XTINY, "Rounds: " + surv + "  Kills: " + _kills, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by + bh * 45 / 100, Graphics.FONT_XTINY, "Best streak: " + _bestStreak, Graphics.TEXT_JUSTIFY_CENTER);
        if (_newBest && surv > 0) { dc.setColor((_resultTick % 4 < 2) ? 0xFFDD44 : 0xFF8822, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by + bh * 57 / 100, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER); }
        if (_resultTick > 30) { dc.setColor((_resultTick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, by + bh * 75 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER); }
    }

    hidden function drawMenu(dc) {
        // Full dark background — covers the entire screen so all UI is always legible
        dc.setColor(0x0E1828, 0x0E1828); dc.clear();

        // Landscape pushed to the bottom quarter so it never overlaps text
        dc.setColor(0x2A4A7A, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 74 / 100, _w, _h);
        dc.setColor(0x44AA44, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 86 / 100, _w, 3);
        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 89 / 100, _w, _h);

        // Title
        var tc = (_tick % 14 < 7) ? 0xFF6644 : 0xFF8866;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, _h * 3 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 3 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 15 / 100, Graphics.FONT_LARGE, "BLOBS", Graphics.TEXT_JUSTIFY_CENTER);

        // ── Dark panel covering the FULL selector + instruction area ─────
        var cardTop = _h * 27 / 100;
        var cardH   = _h * 32 / 100;   // tall enough for both rows + instruction
        var cardW   = _w * 78 / 100;
        var cardX   = (_w - cardW) / 2;
        dc.setColor(0x080F1C, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cardX, cardTop, cardW, cardH, 6);
        dc.setColor(0x1A2E4A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cardX, cardTop, cardW, cardH, 6);

        // ── Mode selector rows ───────────────────────────────────────────
        var rowH  = _h * 10 / 100;   // ~24px on 240, scales with screen
        var padV  = rowH / 4;        // vertical text padding inside row
        var selW2 = cardW - 16;
        var selX2 = cardX + 8;
        var selY0 = cardTop + 8;
        var selY1 = selY0 + rowH + 6;

        // 1 PLAYER row
        if (_menuSel == 0) {
            dc.setColor(0x22BBFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(selX2, selY0, selW2, rowH, 4);
            dc.setColor(0x00080E, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0x5577AA, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(_w / 2, selY0 + padV, Graphics.FONT_XTINY,
            (_menuSel == 0) ? "> 1 PLAYER <" : "  1 PLAYER  ", Graphics.TEXT_JUSTIFY_CENTER);

        // 2 PLAYERS row
        if (_menuSel == 1) {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(selX2, selY1, selW2, rowH, 4);
            dc.setColor(0x001408, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0x5577AA, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(_w / 2, selY1 + padV, Graphics.FONT_XTINY,
            (_menuSel == 1) ? "> 2 PLAYERS <" : "  2 PLAYERS  ", Graphics.TEXT_JUSTIFY_CENTER);

        // Instruction row (still inside the dark panel)
        dc.setColor(0x3A5577, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, selY1 + rowH + 8, Graphics.FONT_XTINY,
            "Up/Down: choose", Graphics.TEXT_JUSTIFY_CENTER);

        // ── Blobs illustration ───────────────────────────────────────────
        var by = _h * 65 / 100;
        var positions = [_w * 20 / 100, _w * 35 / 100, _w * 50 / 100, _w * 65 / 100, _w * 80 / 100];
        for (var i = 0; i < 5; i++) {
            var wob = ((_tick / 5 + i * 3) % 5) - 2;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(positions[i] - 5, by + wob - 5, 12, 12);
            dc.setColor(_bCol[i], Graphics.COLOR_TRANSPARENT); dc.fillRectangle(positions[i] - 6, by + wob - 6, 12, 12);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(positions[i] - 2, by + wob - 1, 1); dc.fillCircle(positions[i] + 2, by + wob - 1, 1);
        }

        // ── Bottom info texts — always on the dark background ────────────
        if (_bestStreak > 0) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 74 / 100, Graphics.FONT_XTINY, "BEST: " + _bestStreak, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x5577AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 81 / 100, Graphics.FONT_XTINY, "angle / power / fire", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 10 < 5) ? 0xFF6644 : 0xFF8866, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 89 / 100, Graphics.FONT_XTINY, "Tap to fight!", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
