using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum { SS_MENU, SS_HUNT, SS_WAVECLEAR, SS_GAMEOVER }

// Ship AI modes
const AI_PATROL = 0;
const AI_CHASE  = 1;
const AI_STRAFE = 2;
const AI_FLEE   = 3;

class BitochiSkywalkerView extends WatchUi.View {

    var accelX;
    var accelY;
    var gameState;

    hidden var _w; hidden var _h; hidden var _cx; hidden var _cy;
    hidden var _timer; hidden var _tick;

    // World + camera
    hidden var _worldW; hidden var _worldH;
    hidden var _aimX; hidden var _aimY;
    hidden var _aimVx; hidden var _aimVy;       // smooth velocity for aim
    hidden var _swayPhase; hidden var _driftPhase;

    // Ships
    hidden const SHIP_MAX = 9;
    hidden var _shipX; hidden var _shipY;
    hidden var _shipVx; hidden var _shipVy;
    hidden var _shipType; hidden var _shipAlive;
    hidden var _shipSize; hidden var _shipFlee;
    hidden var _shipHealth; hidden var _shipMaxHealth;
    hidden var _shipAI;
    hidden var _shipCount;

    // Enemy bolts
    hidden const BOLT_MAX = 6;
    hidden var _boltX; hidden var _boltY;
    hidden var _boltVx; hidden var _boltVy;
    hidden var _boltLife; hidden var _boltType;

    // Stars
    hidden const STAR_N = 28;
    hidden var _starX; hidden var _starY;
    hidden var _starB; hidden var _starPhase;

    // Comet
    hidden var _cometActive;
    hidden var _cometX; hidden var _cometY;
    hidden var _cometVx; hidden var _cometVy;
    hidden var _cometLife;

    // Score / progression
    hidden var _level; hidden var _score; hidden var _bestScore;
    hidden var _kills; hidden var _killTarget;
    hidden var _ammo; hidden var _maxAmmo;
    hidden var _timeLeft;
    hidden var _combo; hidden var _maxCombo;
    hidden var _shield; hidden var _maxShield;

    // Effects
    hidden var _shotFlash; hidden var _recoilTick;
    hidden var _hitX; hidden var _hitY; hidden var _hitShow;
    hidden var _laserSX; hidden var _laserSY; hidden var _laserShow;
    hidden var _shieldFlash;
    hidden var _lockOnIdx;       // index of ship in crosshair (-1 = none)
    hidden var _waveTick;        // wave clear / hyperspace transition
    hidden var _shotMsg;
    hidden var _dmgFlash;        // screen flash when taking damage

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _cx = _w / 2; _cy = _h / 2;
        accelX = 0; accelY = 0; _tick = 0;

        _worldW = _w * 5; _worldH = _h * 5;

        _shipX = new [SHIP_MAX]; _shipY = new [SHIP_MAX];
        _shipVx = new [SHIP_MAX]; _shipVy = new [SHIP_MAX];
        _shipType = new [SHIP_MAX]; _shipAlive = new [SHIP_MAX];
        _shipSize = new [SHIP_MAX]; _shipFlee = new [SHIP_MAX];
        _shipHealth = new [SHIP_MAX]; _shipMaxHealth = new [SHIP_MAX];
        _shipAI = new [SHIP_MAX];
        for (var i = 0; i < SHIP_MAX; i++) {
            _shipX[i] = 0.0; _shipY[i] = 0.0; _shipVx[i] = 0.0; _shipVy[i] = 0.0;
            _shipType[i] = 0; _shipAlive[i] = false; _shipSize[i] = 8;
            _shipFlee[i] = 0; _shipHealth[i] = 1; _shipMaxHealth[i] = 1; _shipAI[i] = AI_PATROL;
        }

        _boltX = new [BOLT_MAX]; _boltY = new [BOLT_MAX];
        _boltVx = new [BOLT_MAX]; _boltVy = new [BOLT_MAX];
        _boltLife = new [BOLT_MAX]; _boltType = new [BOLT_MAX];
        for (var i = 0; i < BOLT_MAX; i++) { _boltLife[i] = 0; }

        _starX = new [STAR_N]; _starY = new [STAR_N];
        _starB = new [STAR_N]; _starPhase = new [STAR_N];
        for (var i = 0; i < STAR_N; i++) {
            _starX[i] = Math.rand().abs() % _worldW;
            _starY[i] = Math.rand().abs() % _worldH;
            _starB[i] = Math.rand().abs() % 4;
            _starPhase[i] = (Math.rand().abs() % 628).toFloat() / 100.0;
        }

        _cometActive = false; _cometX = 0.0; _cometY = 0.0;
        _cometVx = 0.0; _cometVy = 0.0; _cometLife = 0;

        _level = 1; _score = 0; _combo = 0; _maxCombo = 0;
        _shield = 100; _maxShield = 100;
        var bs = Application.Storage.getValue("skyBest");
        _bestScore = (bs != null) ? bs : 0;

        _aimX = (_worldW / 2).toFloat(); _aimY = (_worldH / 2).toFloat();
        _aimVx = 0.0; _aimVy = 0.0;
        _swayPhase = 0.0; _driftPhase = 0.0;

        _shotFlash = 0; _recoilTick = 0; _hitX = 0.0; _hitY = 0.0; _hitShow = 0;
        _laserSX = 0; _laserSY = 0; _laserShow = 0;
        _shieldFlash = 0; _lockOnIdx = -1; _waveTick = 0; _shotMsg = ""; _dmgFlash = 0;
        _ammo = 6; _maxAmmo = 6; _killTarget = 3; _kills = 0; _timeLeft = 0;
        _shipCount = 0;

        gameState = SS_MENU;
    }

    function onShow() { _timer = new Timer.Timer(); _timer.start(method(:onTick), 33, true); }
    function onHide() { if (_timer != null) { _timer.stop(); _timer = null; } }

    function onTick() as Void {
        _tick++;
        _swayPhase += 0.08;
        _driftPhase += 0.025;
        for (var i = 0; i < STAR_N; i++) { _starPhase[i] += 0.035 + (i % 5).toFloat() * 0.012; }

        // Comet
        if (_cometActive) {
            _cometX += _cometVx; _cometY += _cometVy; _cometLife--;
            if (_cometLife <= 0) { _cometActive = false; }
        } else if (_tick % 200 == 0 && Math.rand().abs() % 3 == 0) {
            _cometActive = true;
            _cometX = (Math.rand().abs() % _worldW).toFloat();
            _cometY = (Math.rand().abs() % (_worldH / 3)).toFloat();
            _cometVx = 3.5 + (Math.rand().abs() % 25).toFloat() / 10.0;
            _cometVy = 1.0 + (Math.rand().abs() % 12).toFloat() / 10.0;
            if (Math.rand().abs() % 2 == 0) { _cometVx = -_cometVx; }
            _cometLife = 45 + Math.rand().abs() % 30;
        }

        if (gameState == SS_HUNT) {
            updateAim();
            updateShips();
            updateBolts();
            checkLockOn();
            _timeLeft--;
            if (_timeLeft <= 0 && _kills < _killTarget) {
                endGame();
            }
            if (_shotFlash > 0) { _shotFlash--; }
            if (_hitShow > 0) { _hitShow--; }
            if (_recoilTick > 0) { _recoilTick--; }
            if (_laserShow > 0) { _laserShow--; }
            if (_shieldFlash > 0) { _shieldFlash--; }
            if (_dmgFlash > 0) { _dmgFlash--; }
        } else if (gameState == SS_WAVECLEAR) {
            _waveTick++;
            // Auto-advance after 90 ticks
            if (_waveTick > 90) { _level++; startLevel(); }
        }

        WatchUi.requestUpdate();
    }

    hidden function updateAim() {
        // Smooth velocity-based aiming — inertia like Fish/Parachute
        var ax = accelX.toFloat();
        var ay = accelY.toFloat();
        var dead = 55.0;
        var scale = 370.0;
        var inX = 0.0; var inY = 0.0;
        if (ax >  dead) { inX =  (ax - dead) / scale; }
        else if (ax < -dead) { inX = (ax + dead) / scale; }
        if (ay >  dead) { inY =  (ay - dead) / scale; }
        else if (ay < -dead) { inY = (ay + dead) / scale; }
        if (inX >  2.8) { inX =  2.8; } if (inX < -2.8) { inX = -2.8; }
        if (inY >  2.2) { inY =  2.2; } if (inY < -2.2) { inY = -2.2; }

        // Lerp toward target velocity — smooth, weighted inertia
        _aimVx = _aimVx * 0.80 + inX * 0.20;
        _aimVy = _aimVy * 0.80 + inY * 0.20;
        if (_aimVx >  4.5) { _aimVx =  4.5; } if (_aimVx < -4.5) { _aimVx = -4.5; }
        if (_aimVy >  3.8) { _aimVy =  3.8; } if (_aimVy < -3.8) { _aimVy = -3.8; }

        _aimX += _aimVx;
        _aimY += _aimVy;

        // Gentle cockpit drift
        _aimX += Math.sin(_swayPhase) * 0.06;
        _aimY += Math.sin(_driftPhase) * 0.04;

        if (_aimX < 25.0)               { _aimX = 25.0;               _aimVx = 0.0; }
        if (_aimX > _worldW - 25.0)     { _aimX = _worldW - 25.0;     _aimVx = 0.0; }
        if (_aimY < 25.0)               { _aimY = 25.0;               _aimVy = 0.0; }
        if (_aimY > _worldH - 25.0)     { _aimY = _worldH - 25.0;     _aimVy = 0.0; }
    }

    hidden function startLevel() {
        _aimX = (_worldW / 2).toFloat(); _aimY = (_worldH / 2).toFloat();
        _aimVx = 0.0; _aimVy = 0.0;
        _killTarget = 3 + (_level - 1);
        if (_killTarget > SHIP_MAX) { _killTarget = SHIP_MAX; }
        _kills = 0; _combo = 0; _waveTick = 0;
        _ammo = 8 + _level + (_level / 3);
        if (_ammo > 18) { _ammo = 18; }
        _maxAmmo = _ammo;
        _timeLeft = 700 + _level * 80;
        if (_timeLeft > 2200) { _timeLeft = 2200; }

        // Shield regen each wave
        var regen = 12 + _level * 3;
        _shield += regen; if (_shield > _maxShield) { _shield = _maxShield; }

        _shotFlash = 0; _hitShow = 0; _recoilTick = 0; _laserShow = 0;
        _shieldFlash = 0; _dmgFlash = 0; _lockOnIdx = -1;
        for (var i = 0; i < BOLT_MAX; i++) { _boltLife[i] = 0; }

        _shipCount = _killTarget;
        if (_shipCount > SHIP_MAX) { _shipCount = SHIP_MAX; }
        for (var i = 0; i < _shipCount; i++) { spawnShip(i); }
        for (var i = _shipCount; i < SHIP_MAX; i++) { _shipAlive[i] = false; }

        gameState = SS_HUNT;
    }

    hidden function spawnShip(idx) {
        // Spawn in a ring around the player (not too close, not too far)
        var minD = 180; var range = _worldW / 3;
        var angle = (Math.rand().abs() % 628).toFloat() / 100.0;
        var dist = (minD + Math.rand().abs() % range).toFloat();
        _shipX[idx] = _aimX + dist * Math.cos(angle);
        _shipY[idx] = _aimY + dist * Math.sin(angle);
        // Clamp to world
        if (_shipX[idx] < 50.0) { _shipX[idx] = 50.0; }
        if (_shipX[idx] > _worldW - 50.0) { _shipX[idx] = _worldW - 50.0; }
        if (_shipY[idx] < 50.0) { _shipY[idx] = 50.0; }
        if (_shipY[idx] > _worldH - 50.0) { _shipY[idx] = _worldH - 50.0; }

        _shipVx[idx] = ((Math.rand().abs() % 40) - 20).toFloat() / 10.0;
        _shipVy[idx] = ((Math.rand().abs() % 40) - 20).toFloat() / 10.0;
        _shipFlee[idx] = 0;

        // Ship type based on level
        var roll = Math.rand().abs() % 10;
        if (_level <= 2) {
            _shipType[idx] = 0; // Scout only
        } else if (_level <= 4) {
            _shipType[idx] = (roll < 6) ? 0 : 1; // Scout + Raptor
        } else if (_level <= 6) {
            if (roll < 4) { _shipType[idx] = 0; }
            else if (roll < 7) { _shipType[idx] = 1; }
            else { _shipType[idx] = 2; } // Crusher
        } else if (_level <= 9) {
            if (roll < 2) { _shipType[idx] = 0; }
            else if (roll < 5) { _shipType[idx] = 1; }
            else if (roll < 7) { _shipType[idx] = 2; }
            else if (roll < 9) { _shipType[idx] = 3; } // Phantom
            else { _shipType[idx] = 4; }
        } else {
            _shipType[idx] = Math.rand().abs() % 8;
        }

        // Health based on type + level
        var hp = 1;
        if (_shipType[idx] >= 2 && _level >= 5) { hp = 2; }
        if (_shipType[idx] >= 5 && _level >= 8) { hp = 3; }
        if (_level >= 12 && Math.rand().abs() % 5 == 0) { hp++; }
        _shipHealth[idx] = hp; _shipMaxHealth[idx] = hp;

        _shipSize[idx] = 7 + _shipType[idx] * 2 + Math.rand().abs() % 4;
        if (_shipSize[idx] > 20) { _shipSize[idx] = 20; }
        _shipAlive[idx] = true;

        // AI mode based on level
        if (_level <= 2) { _shipAI[idx] = AI_PATROL; }
        else if (_level <= 4) { _shipAI[idx] = (Math.rand().abs() % 3 == 0) ? AI_CHASE : AI_PATROL; }
        else { _shipAI[idx] = Math.rand().abs() % 3; } // all modes
    }

    hidden function updateShips() {
        for (var i = 0; i < _shipCount; i++) {
            if (!_shipAlive[i]) { continue; }

            var dx = _aimX - _shipX[i];
            var dy = _aimY - _shipY[i];
            var distSq = dx * dx + dy * dy;
            var dist = Math.sqrt(distSq);

            if (_shipFlee[i] > 0) {
                // Flee: boost away from player
                _shipFlee[i]--;
                _shipVx[i] *= 1.035;
                _shipVy[i] *= 1.035;
                var spd2 = _shipVx[i] * _shipVx[i] + _shipVy[i] * _shipVy[i];
                if (spd2 > 25.0) { var sc = 5.0 / Math.sqrt(spd2); _shipVx[i] *= sc; _shipVy[i] *= sc; }
            } else {
                // Update AI mode periodically
                if (_tick % 30 == (i * 11) % 30) {
                    var r2 = Math.rand().abs() % 10;
                    if (dist < 400.0 && _level >= 3 && r2 < _level) {
                        _shipAI[i] = (Math.rand().abs() % 2 == 0) ? AI_CHASE : AI_STRAFE;
                    } else if (dist < 600.0 && _level >= 6 && r2 < 4) {
                        _shipAI[i] = AI_CHASE;
                    } else {
                        _shipAI[i] = AI_PATROL;
                    }
                }

                var maxSpd = 1.0 + _level.toFloat() * 0.18;
                if (maxSpd > 3.5) { maxSpd = 3.5; }

                if (_shipAI[i] == AI_CHASE) {
                    if (dist > 0.1) {
                        var ndx = dx / dist; var ndy = dy / dist;
                        _shipVx[i] = _shipVx[i] * 0.78 + ndx * maxSpd * 0.22;
                        _shipVy[i] = _shipVy[i] * 0.78 + ndy * maxSpd * 0.22;
                    }
                } else if (_shipAI[i] == AI_STRAFE) {
                    if (dist > 0.1) {
                        var perpX = -dy / dist; var perpY = dx / dist;
                        var sDir = (i % 2 == 0) ? 1.0 : -1.0;
                        _shipVx[i] = _shipVx[i] * 0.82 + perpX * sDir * maxSpd * 0.18;
                        _shipVy[i] = _shipVy[i] * 0.82 + perpY * sDir * maxSpd * 0.18;
                    }
                } else {
                    // Patrol: random direction change
                    if (_tick % 22 == (i * 7) % 22) {
                        _shipVx[i] = ((Math.rand().abs() % 40) - 20).toFloat() / 10.0;
                        _shipVy[i] = ((Math.rand().abs() % 40) - 20).toFloat() / 10.0;
                    }
                }

                // Cap speed
                var spd2 = _shipVx[i] * _shipVx[i] + _shipVy[i] * _shipVy[i];
                if (spd2 > maxSpd * maxSpd) { var sc = maxSpd / Math.sqrt(spd2); _shipVx[i] *= sc; _shipVy[i] *= sc; }

                // Enemy fires at player — bullet timing
                var fireRate = 90 - _level * 4;
                if (fireRate < 28) { fireRate = 28; }
                if (_level >= 2 && _tick % fireRate == (i * 13) % fireRate && dist < 600.0) {
                    spawnBolt(i, dx, dy, dist);
                }
            }

            _shipX[i] += _shipVx[i]; _shipY[i] += _shipVy[i];
            if (_shipX[i] < 45.0) { _shipX[i] = 45.0; _shipVx[i] = -_shipVx[i]; }
            if (_shipX[i] > _worldW - 45.0) { _shipX[i] = _worldW - 45.0; _shipVx[i] = -_shipVx[i]; }
            if (_shipY[i] < 45.0) { _shipY[i] = 45.0; _shipVy[i] = -_shipVy[i]; }
            if (_shipY[i] > _worldH - 45.0) { _shipY[i] = _worldH - 45.0; _shipVy[i] = -_shipVy[i]; }
        }
    }

    hidden function spawnBolt(shipIdx, dx, dy, dist) {
        // Find free bolt slot
        var b = -1;
        for (var j = 0; j < BOLT_MAX; j++) { if (_boltLife[j] <= 0) { b = j; break; } }
        if (b < 0) { return; }

        var spd = 5.5 + _level.toFloat() * 0.35;
        if (spd > 12.0) { spd = 12.0; }
        if (dist < 0.1) { return; }
        var ndx = dx / dist; var ndy = dy / dist;

        // Inaccuracy decreases with level
        var inaccMax = 0.45 - _level.toFloat() * 0.03;
        if (inaccMax < 0.04) { inaccMax = 0.04; }
        var inacc = ((Math.rand().abs() % 100).toFloat() / 100.0 - 0.5) * inaccMax;

        _boltX[b] = _shipX[shipIdx]; _boltY[b] = _shipY[shipIdx];
        _boltVx[b] = (ndx + inacc) * spd;
        _boltVy[b] = (ndy + inacc) * spd;
        _boltLife[b] = 55;
        _boltType[b] = _shipType[shipIdx];
    }

    hidden function updateBolts() {
        var hitRadius = 32.0 * 32.0; // squared
        for (var b = 0; b < BOLT_MAX; b++) {
            if (_boltLife[b] <= 0) { continue; }
            _boltX[b] += _boltVx[b]; _boltY[b] += _boltVy[b];
            _boltLife[b]--;

            // Hit check (squared distance to avoid sqrt)
            var dx = _boltX[b] - _aimX;
            var dy = _boltY[b] - _aimY;
            if (dx * dx + dy * dy < hitRadius) {
                _boltLife[b] = 0;
                var dmg = 6 + (_level * 2);
                if (dmg > 20) { dmg = 20; }
                _shield -= dmg;
                _shieldFlash = 8;
                _dmgFlash = 5;
                doVibe(50, 80);
                if (_shield <= 0) { _shield = 0; endGame(); }
            }
        }
    }

    hidden function checkLockOn() {
        _lockOnIdx = -1;
        var bestDistSq = 55.0 * 55.0; // lock on within 55 world units
        for (var i = 0; i < _shipCount; i++) {
            if (!_shipAlive[i]) { continue; }
            var dx = _shipX[i] - _aimX;
            var dy = _shipY[i] - _aimY;
            var dSq = dx * dx + dy * dy;
            if (dSq < bestDistSq) { bestDistSq = dSq; _lockOnIdx = i; }
        }
    }

    hidden function endGame() {
        if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("skyBest", _bestScore); }
        gameState = SS_GAMEOVER;
    }

    function doShoot() {
        if (gameState == SS_MENU) {
            _level = 1; _score = 0; _combo = 0; _maxCombo = 0; _shield = _maxShield;
            startLevel(); return;
        }
        if (gameState == SS_GAMEOVER) {
            _level = 1; _score = 0; _combo = 0; _maxCombo = 0; _shield = _maxShield;
            startLevel(); return;
        }
        if (gameState == SS_WAVECLEAR) { _level++; startLevel(); return; }
        if (gameState != SS_HUNT || _ammo <= 0) { return; }

        _ammo--; _shotFlash = 5; _recoilTick = 4; _laserShow = 5;
        doVibe(60, 70);

        var hit = false; var bestDistSq = 9999999.0; var bestIdx = -1;
        for (var i = 0; i < _shipCount; i++) {
            if (!_shipAlive[i]) { continue; }
            var dx = _aimX - _shipX[i]; var dy = _aimY - _shipY[i];
            var dSq = dx * dx + dy * dy;
            var hitR = (_shipSize[i].toFloat() + 6.0);
            if (dSq < hitR * hitR && dSq < bestDistSq) { bestDistSq = dSq; bestIdx = i; hit = true; }
        }

        if (hit && bestIdx >= 0) {
            _shipHealth[bestIdx]--;
            if (_shipHealth[bestIdx] <= 0) {
                // Kill
                _shipAlive[bestIdx] = false;
                _kills++;
                _combo++;
                if (_combo > _maxCombo) { _maxCombo = _combo; }
                var pts = 120 + (_combo - 1) * 60 + _level * 20;
                var sqrtDist = Math.sqrt(bestDistSq);
                if (sqrtDist < _shipSize[bestIdx].toFloat() * 0.25) { pts += 300; _shotMsg = "CRITICAL!"; }
                else if (sqrtDist < _shipSize[bestIdx].toFloat() * 0.6) { pts += 150; _shotMsg = "DIRECT HIT!"; }
                else { _shotMsg = "DESTROYED!"; }
                _score += pts;
                _hitX = _shipX[bestIdx]; _hitY = _shipY[bestIdx];
                _hitShow = 24;
                _laserSX = (_hitX - _aimX).toNumber() + _cx;
                _laserSY = (_hitY - _aimY).toNumber() + _cy;
                doVibe(95, 140);

                // Nearby ships flee
                for (var j = 0; j < _shipCount; j++) {
                    if (_shipAlive[j] && j != bestIdx) {
                        var fx = _shipX[j] - _shipX[bestIdx]; var fy = _shipY[j] - _shipY[bestIdx];
                        var fd = Math.sqrt(fx * fx + fy * fy);
                        if (fd < 200.0 && fd > 0.1) {
                            _shipVx[j] = (fx / fd) * 3.8; _shipVy[j] = (fy / fd) * 3.8;
                            _shipFlee[j] = 30 + Math.rand().abs() % 20;
                        }
                    }
                }

                if (_kills >= _killTarget) { gameState = SS_WAVECLEAR; _waveTick = 0; }
            } else {
                // Damaged but alive
                _shipFlee[bestIdx] = 15;
                _shipVx[bestIdx] = -_shipVx[bestIdx] * 1.5; _shipVy[bestIdx] = -_shipVy[bestIdx] * 1.5;
                _hitX = _shipX[bestIdx]; _hitY = _shipY[bestIdx]; _hitShow = 12;
                _laserSX = (_hitX - _aimX).toNumber() + _cx;
                _laserSY = (_hitY - _aimY).toNumber() + _cy;
                _shotMsg = "HIT!";
                _score += 40 + _level * 10;
                doVibe(70, 90);
            }
        } else {
            _combo = 0; _shotMsg = "MISS"; _hitShow = 8;
            _hitX = _aimX; _hitY = _aimY;
            _laserSX = _cx; _laserSY = _cy;
            // Near-miss scare nearby ships
            for (var j = 0; j < _shipCount; j++) {
                if (_shipAlive[j]) {
                    var fx = _shipX[j] - _aimX; var fy = _shipY[j] - _aimY;
                    var fd = Math.sqrt(fx * fx + fy * fy);
                    if (fd < 140.0 && fd > 0.1) {
                        _shipVx[j] = (fx / fd) * 3.0; _shipVy[j] = (fy / fd) * 3.0;
                        _shipFlee[j] = 20 + Math.rand().abs() % 15;
                    }
                }
            }
        }

        if (_ammo <= 0) {
            var anyAlive = false;
            for (var i = 0; i < _shipCount; i++) { if (_shipAlive[i]) { anyAlive = true; } }
            if (anyAlive && _kills < _killTarget) { endGame(); }
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) { if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
        } }
    }

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight(); _cx = _w / 2; _cy = _h / 2;
        if (gameState == SS_MENU)      { drawMenu(dc); return; }
        if (gameState == SS_GAMEOVER)  { drawGameOver(dc); return; }
        if (gameState == SS_WAVECLEAR) { drawWaveClear(dc); return; }
        drawCombatView(dc);
    }

    hidden function drawCombatView(dc) {
        dc.setColor(0x020208, 0x020208); dc.clear();
        var rcX = 0; var rcY = 0;
        if (_recoilTick > 0) { rcY = -_recoilTick; rcX = (_recoilTick % 2 == 0) ? 1 : -1; }
        drawStarfield(dc, rcX, rcY);
        drawBoltsInView(dc, rcX, rcY);
        drawShipsInView(dc, rcX, rcY);
        drawThreatArrows(dc);
        drawHitFx(dc, rcX, rcY);
        drawLaserBeam(dc);
        drawCockpitOverlay(dc);
        drawLaserFlash(dc);
        if (_dmgFlash > 0) {
            dc.setColor(0x440000, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(0, 0, _w, _h); dc.drawRectangle(1, 1, _w - 2, _h - 2);
            dc.drawRectangle(2, 2, _w - 4, _h - 4);
        }
        drawHUD(dc);
    }

    hidden function drawStarfield(dc, offX, offY) {
        // Static background stars (no parallax, fast)
        for (var i = 0; i < 22; i++) {
            var sx = (i * 53 + 17) % _w;
            var sy = (i * 41 + 11) % _h;
            var bc = (i % 7 == 0) ? 0x5577AA : ((i % 5 == 0) ? 0x886644 : 0x444455);
            dc.setColor(bc, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sx + offX / 4, sy + offY / 4, 1);
        }
        // Parallax stars with twinkle
        for (var i = 0; i < STAR_N; i++) {
            var par = 0.25 + _starB[i].toFloat() * 0.18;
            var sx = (_starX[i].toFloat() - _aimX * par).toNumber() + _cx + offX;
            var sy = (_starY[i].toFloat() - _aimY * par).toNumber() + _cy + offY;
            if (sx < -8 || sx > _w + 8 || sy < -8 || sy > _h + 8) { continue; }
            var twinkle = Math.sin(_starPhase[i]);
            var sc;
            if (twinkle < -0.3) { sc = (_starB[i] >= 2) ? 0x556677 : 0x222233; }
            else if (twinkle < 0.4) {
                if (_starB[i] == 0) { sc = 0x333344; }
                else if (_starB[i] == 1) { sc = 0x6677AA; }
                else if (_starB[i] == 2) { sc = 0x99AACC; }
                else { sc = 0xCCDDFF; }
            } else { sc = (_starB[i] <= 1) ? 0x88AACC : 0xFFFFFF; }
            dc.setColor(sc, Graphics.COLOR_TRANSPARENT);
            var sr = (_starB[i] > 2) ? 2 : 1;
            if (twinkle > 0.75 && _starB[i] >= 3) { sr = 3; }
            dc.fillCircle(sx, sy, sr);
            if (twinkle > 0.88 && _starB[i] == 3) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(sx - 3, sy, sx + 3, sy); dc.drawLine(sx, sy - 3, sx, sy + 3);
            }
        }
        // Nebula clouds
        for (var i = 0; i < 3; i++) {
            var np = 0.1;
            var nx = ((i * 631 + 211) % (_worldW * 2)).toFloat() - _aimX * np + _cx + offX;
            var ny = ((i * 437 + 127) % (_worldH * 2)).toFloat() - _aimY * np + _cy + offY;
            var nc = (i == 0) ? 0x110022 : ((i == 1) ? 0x001122 : 0x180A08);
            dc.setColor(nc, Graphics.COLOR_TRANSPARENT); dc.fillCircle(nx.toNumber(), ny.toNumber(), 28 + i * 10);
            var nc2 = (i == 0) ? 0x1A0030 : ((i == 1) ? 0x002233 : 0x220A08);
            dc.setColor(nc2, Graphics.COLOR_TRANSPARENT); dc.fillCircle(nx.toNumber(), ny.toNumber(), 16 + i * 6);
        }
        // Comet
        if (_cometActive) {
            var cp = 0.45;
            var ccx = (_cometX - _aimX * cp).toNumber() + _cx + offX;
            var ccy = (_cometY - _aimY * cp).toNumber() + _cy + offY;
            if (ccx > -40 && ccx < _w + 40 && ccy > -40 && ccy < _h + 40) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ccx, ccy, 2);
                var tl = 6; if (tl > _cometLife) { tl = _cometLife; }
                for (var ct = 1; ct <= tl; ct++) {
                    var tx = ccx - (_cometVx * ct.toFloat() * 0.65).toNumber();
                    var ty = ccy - (_cometVy * ct.toFloat() * 0.65).toNumber();
                    dc.setColor((ct <= 2) ? 0xAABBDD : ((ct <= 4) ? 0x557788 : 0x334455), Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(tx, ty, 1);
                }
            }
        }
    }

    hidden function drawBoltsInView(dc, offX, offY) {
        for (var b = 0; b < BOLT_MAX; b++) {
            if (_boltLife[b] <= 0) { continue; }
            var bsx = (_boltX[b] - _aimX).toNumber() + _cx + offX;
            var bsy = (_boltY[b] - _aimY).toNumber() + _cy + offY;
            if (bsx < -20 || bsx > _w + 20 || bsy < -20 || bsy > _h + 20) { continue; }
            // Bolt color by ship type
            var bColor = 0xFF4444;
            var coreColor = 0xFF8888;
            if (_boltType[b] == 1) { bColor = 0x4444FF; coreColor = 0x8888FF; }
            else if (_boltType[b] == 3) { bColor = 0xAA44FF; coreColor = 0xCC88FF; }
            else if (_boltType[b] == 6 || _boltType[b] == 7) { bColor = 0xFF8800; coreColor = 0xFFCC44; }
            // Tail
            var tailX = bsx - (_boltVx[b] * 2.2).toNumber();
            var tailY = bsy - (_boltVy[b] * 2.2).toNumber();
            dc.setColor(bColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bsx, bsy, tailX, tailY);
            dc.drawLine(bsx - 1, bsy, tailX - 1, tailY);
            // Head (bright)
            dc.setColor(coreColor, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bsx, bsy, 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bsx, bsy, 1);
        }
    }

    hidden function drawShipsInView(dc, offX, offY) {
        for (var i = 0; i < _shipCount; i++) {
            if (!_shipAlive[i]) { continue; }
            var sx = (_shipX[i] - _aimX).toNumber() + _cx + offX;
            var sy = (_shipY[i] - _aimY).toNumber() + _cy + offY;
            if (sx < -40 || sx > _w + 40 || sy < -40 || sy > _h + 40) { continue; }

            // Damage flash
            var isFlashing = (_shipFlee[i] > 0 && _shipHealth[i] < _shipMaxHealth[i] && _tick % 4 < 2);

            drawShipSprite(dc, sx, sy, _shipType[i], _shipSize[i], _shipVx[i], _shipFlee[i] > 0 && _shipHealth[i] == _shipMaxHealth[i]);

            // Lock-on indicator
            if (i == _lockOnIdx) {
                var lc = (_tick % 4 < 2) ? 0x44FF88 : 0x22CC66;
                dc.setColor(lc, Graphics.COLOR_TRANSPARENT);
                var hs = _shipSize[i] + 4;
                dc.drawLine(sx - hs, sy - hs, sx - hs + 4, sy - hs);
                dc.drawLine(sx - hs, sy - hs, sx - hs, sy - hs + 4);
                dc.drawLine(sx + hs, sy - hs, sx + hs - 4, sy - hs);
                dc.drawLine(sx + hs, sy - hs, sx + hs, sy - hs + 4);
                dc.drawLine(sx - hs, sy + hs, sx - hs + 4, sy + hs);
                dc.drawLine(sx - hs, sy + hs, sx - hs, sy + hs - 4);
                dc.drawLine(sx + hs, sy + hs, sx + hs - 4, sy + hs);
                dc.drawLine(sx + hs, sy + hs, sx + hs, sy + hs - 4);
            }

            // Health pips below ship
            if (_shipMaxHealth[i] > 1) {
                for (var h = 0; h < _shipMaxHealth[i]; h++) {
                    var hc = (h < _shipHealth[i]) ? 0x44FF44 : 0x333333;
                    dc.setColor(hc, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(sx - _shipMaxHealth[i] * 3 + h * 6, sy + _shipSize[i] + 3, 4, 3);
                }
            }
        }
    }

    hidden function drawThreatArrows(dc) {
        // Show arrows at screen edge pointing to off-screen enemies
        var margin = 14;
        for (var i = 0; i < _shipCount; i++) {
            if (!_shipAlive[i]) { continue; }
            var sx = (_shipX[i] - _aimX).toNumber() + _cx;
            var sy = (_shipY[i] - _aimY).toNumber() + _cy;
            if (sx >= 0 && sx < _w && sy >= 0 && sy < _h) { continue; }
            // Clamp arrow to screen edge
            var ax = sx; var ay = sy;
            if (ax < margin) { ax = margin; } if (ax > _w - margin) { ax = _w - margin; }
            if (ay < margin) { ay = margin; } if (ay > _h - margin) { ay = _h - margin; }
            // Color by threat (AI_CHASE = red, others = orange)
            var ac = (_shipAI[i] == AI_CHASE) ? 0xFF2222 : 0xFF8844;
            dc.setColor(ac, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 2, ay - 2, 5, 5);
            // Arrow tip pointing toward enemy
            var ddx = sx - ax; var ddy = sy - ay;
            var ddlen = Math.sqrt(ddx.toFloat() * ddx.toFloat() + ddy.toFloat() * ddy.toFloat());
            if (ddlen > 1.0) {
                var arx = ax + (ddx.toFloat() / ddlen * 5.0).toNumber();
                var ary = ay + (ddy.toFloat() / ddlen * 5.0).toNumber();
                dc.drawLine(ax, ay, arx, ary);
            }
        }
    }

    hidden function drawShipSprite(dc, sx, sy, stype, ssize, vx, fleeing) {
        var sz = ssize;
        var hullC; var wingC; var engineC;
        if (stype == 0)      { hullC = 0x667788; wingC = 0x445566; engineC = 0xFF4400; }
        else if (stype == 1) { hullC = 0x4455AA; wingC = 0x334488; engineC = 0x4488FF; }
        else if (stype == 2) { hullC = 0x557755; wingC = 0x446644; engineC = 0xFF8800; }
        else if (stype == 3) { hullC = 0x303340; wingC = 0x202230; engineC = 0x8844FF; }
        else if (stype == 4) { hullC = 0xAA8844; wingC = 0x886633; engineC = 0x44FF44; }
        else if (stype == 5) { hullC = 0x99AAAA; wingC = 0x778888; engineC = 0xCCDDFF; }
        else if (stype == 6) { hullC = 0x994444; wingC = 0x773333; engineC = 0xFF2200; }
        else                 { hullC = 0x665577; wingC = 0x443355; engineC = 0xFF44FF; }

        if (fleeing) { sz = sz + (_tick % 2); }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sx + 1, sy + 1, sz * 40 / 100);

        if (stype == 0) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sx, sy, sz * 40 / 100);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz - 1, sy - sz + 3, 3, sz * 2 - 6);
            dc.fillRectangle(sx + sz - 1, sy - sz + 3, 3, sz * 2 - 6);
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx - sz * 40 / 100, sy, sx - sz, sy);
            dc.drawLine(sx + sz * 40 / 100, sy, sx + sz - 1, sy);
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sx, sy, sz * 20 / 100);
        } else if (stype == 1) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - sz / 3], [sx + sz / 3, sy + sz / 3], [sx - sz / 3, sy + sz / 3]]);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx - sz / 3, sy], [sx - sz, sy - sz + 2], [sx - sz - 2, sy - sz / 2]]);
            dc.fillPolygon([[sx + sz / 3, sy], [sx + sz, sy - sz + 2], [sx + sz + 2, sy - sz / 2]]);
            dc.setColor(0x6688BB, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sx, sy, sz / 4);
        } else if (stype == 2) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx - sz / 2, sy, sz * 40 / 100); dc.fillCircle(sx + sz / 2, sy, sz * 40 / 100);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sx - sz / 2, sy - 2, sz, 4);
            dc.setColor(0x668866, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sx - 2, sy + sz * 40 / 100, 4, 3);
        } else if (stype == 3) {
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - sz], [sx + sz, sy + sz / 2], [sx - sz, sy + sz / 2]]);
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sx, sy - sz / 4, sz / 3);
            dc.setColor(0x444466, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sx, sy - sz / 4, sz / 5);
        } else if (stype == 4) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - sz], [sx + sz / 2, sy], [sx, sy + sz / 2], [sx - sz / 2, sy]]);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz - 2, sy - sz / 4, sz / 2, 3);
            dc.fillRectangle(sx + sz / 2 + 2, sy - sz / 4, sz / 2, 3);
            dc.setColor(0xCCAA66, Graphics.COLOR_TRANSPARENT); dc.fillCircle(sx, sy - sz / 3, sz / 4);
        } else if (stype == 5) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sx - sz / 3, sy - sz, sz * 2 / 3, sz * 2);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx - sz / 3, sy - sz / 3], [sx - sz, sy + sz], [sx - sz / 3, sy + sz]]);
            dc.fillPolygon([[sx + sz / 3, sy - sz / 3], [sx + sz, sy + sz], [sx + sz / 3, sy + sz]]);
            dc.setColor(0xAABBBB, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sx - 2, sy - sz + 1, 4, 3);
        } else if (stype == 6) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sx - sz, sy - sz / 2, sz * 2, sz);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sx - sz / 3, sy - sz / 2 - sz / 4, sz * 2 / 3, sz / 4);
            dc.setColor(0xAA5555, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz - 2, sy + sz / 4, 3, 4); dc.fillRectangle(sx + sz, sy + sz / 4, 3, 4);
            dc.setColor(0xCC6666, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx - sz / 2, sy, 2); dc.fillCircle(sx + sz / 2, sy, 2);
        } else {
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - sz * 3 / 2], [sx + sz, sy + sz / 2], [sx - sz, sy + sz / 2]]);
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - sz], [sx + sz * 2 / 3, sy + sz / 3], [sx - sz * 2 / 3, sy + sz / 3]]);
            dc.setColor(0x776688, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sx - sz / 4, sy - sz / 4, sz / 2, sz / 4);
            dc.setColor(0xFF44FF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sx - sz / 3, sy + sz / 2, sz * 2 / 3, 3);
        }

        dc.setColor(engineC, Graphics.COLOR_TRANSPARENT);
        if (stype == 2) {
            dc.fillCircle(sx - sz / 2, sy + sz * 40 / 100 + 2, 2); dc.fillCircle(sx + sz / 2, sy + sz * 40 / 100 + 2, 2);
        } else if (stype == 6) {
            dc.fillCircle(sx - sz - 1, sy + sz / 4 + 5, 2); dc.fillCircle(sx + sz + 1, sy + sz / 4 + 5, 2);
        } else if (stype == 7) {
            dc.fillRectangle(sx - sz / 4, sy + sz / 2 + 3, sz / 2, 2);
        } else { dc.fillCircle(sx, sy + sz / 2 + 2, 2); }

        if (fleeing) {
            dc.setColor(engineC, Graphics.COLOR_TRANSPARENT);
            var tl = 5 + _tick % 4;
            dc.fillRectangle(sx - 1, sy + sz / 2 + 3, 2, tl);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sx, sy + sz / 2 + 3, 1, tl / 2);
        }
    }

    hidden function drawHitFx(dc, offX, offY) {
        if (_hitShow <= 0) { return; }
        var hx = (_hitX - _aimX).toNumber() + _cx + offX;
        var hy = (_hitY - _aimY).toNumber() + _cy + offY;
        if (_shotMsg.equals("MISS")) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(hx, hy, 2);
        } else {
            var flashC = (_hitShow % 4 < 2) ? 0xFF6622 : 0xFFCC22;
            dc.setColor(flashC, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 7; i++) { dc.fillRectangle(hx + (Math.rand().abs() % 20) - 10, hy + (Math.rand().abs() % 20) - 10, 3, 3); }
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(hx, hy, 5 + _hitShow / 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(hx, hy, 3);
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT); dc.fillCircle(hx, hy, 4 + _hitShow / 3);
            if (_hitShow > 12) {
                dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
                for (var i = 0; i < 6; i++) {
                    var a = (i * 60 + _tick * 18).toFloat() * 3.14159 / 180.0;
                    var dr = 8 + _hitShow / 2;
                    dc.fillRectangle(hx + (dr * Math.cos(a)).toNumber(), hy + (dr * Math.sin(a)).toNumber(), 2, 2);
                }
            }
        }
    }

    hidden function drawLaserBeam(dc) {
        if (_laserShow <= 0) { return; }
        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT); dc.drawLine(_cx, _h, _laserSX, _laserSY);
        dc.setColor(0x88FFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - 1, _h, _laserSX - 1, _laserSY); dc.drawLine(_cx + 1, _h, _laserSX + 1, _laserSY);
        dc.setColor(0x22AA44, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - 2, _h, _laserSX - 2, _laserSY); dc.drawLine(_cx + 2, _h, _laserSX + 2, _laserSY);
        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_laserSX, _laserSY, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_laserSX, _laserSY, 2);
    }

    hidden function drawCockpitOverlay(dc) {
        var r = _cx; if (_cy < r) { r = _cy; }
        r -= 2;
        // Dark vignette frame
        dc.setColor(0x08080F, Graphics.COLOR_TRANSPARENT);
        for (var ring = r; ring < r + 20; ring++) { dc.drawCircle(_cx, _cy, ring); }
        dc.setColor(0x111122, Graphics.COLOR_TRANSPARENT); dc.drawCircle(_cx, _cy, r);
        dc.drawCircle(_cx, _cy, r - 1);
        dc.setColor(0x1A1A2E, Graphics.COLOR_TRANSPARENT); dc.drawCircle(_cx, _cy, r - 2);
        dc.setColor(0x222234, Graphics.COLOR_TRANSPARENT); dc.drawCircle(_cx, _cy, r - 3);
        dc.setColor(0x18283A, Graphics.COLOR_TRANSPARENT); dc.drawCircle(_cx, _cy, r - 4);

        // Targeting reticle — green with lock-on flash
        var retC = (_lockOnIdx >= 0 && _tick % 3 < 2) ? 0x88FFAA : 0x44FF88;
        dc.setColor(retC, Graphics.COLOR_TRANSPARENT);
        var rOff = 16; var rLen = 8;
        dc.drawLine(_cx - rOff, _cy - rOff, _cx - rOff + rLen, _cy - rOff);
        dc.drawLine(_cx - rOff, _cy - rOff, _cx - rOff, _cy - rOff + rLen);
        dc.drawLine(_cx + rOff, _cy - rOff, _cx + rOff - rLen, _cy - rOff);
        dc.drawLine(_cx + rOff, _cy - rOff, _cx + rOff, _cy - rOff + rLen);
        dc.drawLine(_cx - rOff, _cy + rOff, _cx - rOff + rLen, _cy + rOff);
        dc.drawLine(_cx - rOff, _cy + rOff, _cx - rOff, _cy + rOff - rLen);
        dc.drawLine(_cx + rOff, _cy + rOff, _cx + rOff - rLen, _cy + rOff);
        dc.drawLine(_cx + rOff, _cy + rOff, _cx + rOff, _cy + rOff - rLen);

        // Crosshair
        dc.setColor(0x33CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - 8, _cy, _cx - 3, _cy); dc.drawLine(_cx + 3, _cy, _cx + 8, _cy);
        dc.drawLine(_cx, _cy - 8, _cx, _cy - 3); dc.drawLine(_cx, _cy + 3, _cx, _cy + 8);

        // Shield flash ring
        if (_shieldFlash > 0) {
            var sf = (_shieldFlash % 4 < 2) ? 0xFF4444 : 0xFF8888;
            dc.setColor(sf, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(_cx, _cy, r - 5); dc.drawCircle(_cx, _cy, r - 6);
        }

        // Range rings (subtle)
        dc.setColor(0x0A1818, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r * 50 / 100);
        dc.drawCircle(_cx, _cy, r * 28 / 100);
        dc.setColor(0x44FFAA, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_cx, _cy, 1);

        // Cockpit frame bottom
        dc.setColor(0x1A2840, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - r + 8, _cy + r * 60 / 100, _cx - r * 28 / 100, _h - 4);
        dc.drawLine(_cx + r - 8, _cy + r * 60 / 100, _cx + r * 28 / 100, _h - 4);
        dc.setColor(0x152230, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx - r * 28 / 100, _h - 7, r * 56 / 100, 7);
    }

    hidden function drawLaserFlash(dc) {
        if (_shotFlash <= 0) { return; }
        var fa = _shotFlash * 38; if (fa > 0xCC) { fa = 0xCC; }
        dc.setColor((fa / 3) << 16 | fa << 8 | (fa / 3), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _h, _shotFlash * 9);
    }

    hidden function drawHUD(dc) {
        // Ammo pips (bottom left)
        for (var i = 0; i < _maxAmmo; i++) {
            var bx = 7 + i * 6; if (bx > _w * 38 / 100) { break; }
            var by = _h - 17;
            if (i < _ammo) {
                dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx, by, 3, 8);
                dc.setColor(0x22AA22, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx, by, 3, 3);
            } else {
                dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bx, by, 3, 8);
            }
        }

        // Score top-right
        dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 4, 4, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);

        // Kill counter top-left
        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 4, Graphics.FONT_XTINY, _kills + "/" + _killTarget, Graphics.TEXT_JUSTIFY_LEFT);

        // Timer bottom-center
        var sec = _timeLeft / 30;
        var tC = (sec > 12) ? 0x88AACC : ((_tick % 6 < 3) ? 0xFF4444 : 0xFF8844);
        dc.setColor(tC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h - 19, Graphics.FONT_XTINY, sec + "s", Graphics.TEXT_JUSTIFY_CENTER);

        // Wave number top-center
        dc.setColor(0x4466AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 4, Graphics.FONT_XTINY, "W" + _level + " " + getWaveName(), Graphics.TEXT_JUSTIFY_CENTER);

        // Shield bar (bottom-right)
        var shW = _w * 28 / 100; var shX = _w - shW - 6; var shY = _h - 14;
        dc.setColor(0x0A1822, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(shX, shY, shW, 5);
        var shFill = shW * _shield / _maxShield;
        var shC = (_shield > 60) ? 0x4488FF : ((_shield > 30) ? 0xFFAA22 : 0xFF2222);
        dc.setColor(shC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(shX, shY, shFill, 5);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(shX - 2, shY - 2, Graphics.FONT_XTINY, "S", Graphics.TEXT_JUSTIFY_RIGHT);

        // Shot message
        if (_hitShow > 0) {
            var msgC = 0xFFFFFF;
            if (_shotMsg.equals("CRITICAL!"))     { msgC = 0xFF4444; }
            else if (_shotMsg.equals("DIRECT HIT!")) { msgC = 0xFFCC44; }
            else if (_shotMsg.equals("DESTROYED!")) { msgC = 0x44FF44; }
            else if (_shotMsg.equals("HIT!"))      { msgC = 0x88FFAA; }
            else if (_shotMsg.equals("MISS"))      { msgC = 0x555566; }
            dc.setColor(msgC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy + _cy * 42 / 100, Graphics.FONT_SMALL, _shotMsg, Graphics.TEXT_JUSTIFY_CENTER);
            if (_combo >= 2) {
                dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_cx, _cy + _cy * 60 / 100, Graphics.FONT_XTINY, "x" + _combo + " COMBO", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // Lock-on pulse text
        if (_lockOnIdx >= 0 && _tick % 8 < 4) {
            dc.setColor(0x44FFAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy - _cy * 52 / 100, Graphics.FONT_XTINY, "LOCK ON", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Incoming bolt warning
        var boltWarn = false;
        for (var b = 0; b < BOLT_MAX; b++) {
            if (_boltLife[b] > 0) {
                var dx = _boltX[b] - _aimX; var dy = _boltY[b] - _aimY;
                if (dx * dx + dy * dy < 150.0 * 150.0) { boltWarn = true; break; }
            }
        }
        if (boltWarn || _shieldFlash > 3) {
            dc.setColor((_tick % 4 < 2) ? 0xFF2222 : 0xFF6644, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, 18, Graphics.FONT_XTINY, "!! INCOMING !!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function getWaveName() {
        if (_level <= 2)  { return "PATROL"; }
        if (_level <= 4)  { return "CONTACT"; }
        if (_level <= 6)  { return "DANGER"; }
        if (_level <= 8)  { return "ASSAULT"; }
        if (_level <= 10) { return "ELITE"; }
        if (_level <= 12) { return "DEATH SQ"; }
        return "DARK SIDE";
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x020208, 0x020208); dc.clear();
        for (var i = 0; i < 30; i++) {
            dc.setColor((i % 6 == 0) ? 0x7799BB : ((i % 4 == 0) ? 0x556688 : 0x334455), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((i * 53 + 17) % _w, (i * 41 + 11) % _h, (i % 8 == 0) ? 2 : 1);
        }
        // Planet
        dc.setColor(0x0A0A22, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_cx + 32, _cy - 22, 26);
        dc.setColor(0x111133, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_cx + 32, _cy - 22, 19);
        dc.setColor(0x141428, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_cx + 32, _cy - 22, 12);
        drawCockpitOverlay(dc);

        var pulse = (_tick % 20 < 10) ? 0x44FF88 : 0x22CC66;
        dc.setColor(0x0A2A14, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 1, _h * 8 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 8 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 22 / 100, Graphics.FONT_MEDIUM, "SKYWALKER", Graphics.TEXT_JUSTIFY_CENTER);

        drawShipSprite(dc, _cx - 24, _cy + 4, (_tick / 38) % 8, 9, 1.0, false);
        drawShipSprite(dc, _cx + 24, _cy + 4, ((_tick / 38) + 4) % 8, 8, -1.0, false);

        dc.setColor(0x7799AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 56 / 100, Graphics.FONT_XTINY, "Destroy Imperial fighters!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, _h * 64 / 100, Graphics.FONT_XTINY, "Tilt to scan space", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, _h * 71 / 100, Graphics.FONT_XTINY, "Tap to fire", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, _h * 78 / 100, Graphics.FONT_XTINY, "They WILL shoot back!", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestScore > 0) { dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 86 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor((_tick % 10 < 5) ? 0x44FF44 : 0x22CC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 93 / 100, Graphics.FONT_XTINY, "Tap to launch", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawWaveClear(dc) {
        dc.setColor(0x020208, 0x020208); dc.clear();
        for (var i = 0; i < 18; i++) { dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT); dc.fillCircle((i * 53 + 17) % _w, (i * 41 + 11) % _h, 1); }

        // Hyperspace streak effect if _waveTick < 30
        if (_waveTick < 35) {
            for (var i = 0; i < 18; i++) {
                var sx = (i * 53 + 17) % _w;
                var sy = (i * 41 + 11) % _h;
                var streakLen = (_waveTick * 3) + 4;
                dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(sx, sy, sx + streakLen, sy);
            }
        }

        var flash = (_waveTick % 8 < 4) ? 0x44FF88 : 0x22CC66;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 12 / 100, Graphics.FONT_MEDIUM, "WAVE CLEAR!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x4488FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 28 / 100, Graphics.FONT_SMALL, "SECTOR " + _level, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 42 / 100, Graphics.FONT_SMALL, "" + _score + " pts", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF5544, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 54 / 100, Graphics.FONT_XTINY, "KILLS " + _kills + "/" + _killTarget, Graphics.TEXT_JUSTIFY_CENTER);
        if (_maxCombo >= 2) {
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 62 / 100, Graphics.FONT_XTINY, "COMBO x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x4488FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 70 / 100, Graphics.FONT_XTINY, "SHIELD " + _shield + "%", Graphics.TEXT_JUSTIFY_CENTER);

        var nxt = _level + 1;
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 80 / 100, Graphics.FONT_XTINY, "Next: WAVE " + nxt + " – " + getWaveNameForLevel(nxt), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0x44AAFF : 0x3388DD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 90 / 100, Graphics.FONT_XTINY, "Tap to jump in", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x080008, 0x080008); dc.clear();
        for (var i = 0; i < 12; i++) { dc.setColor(0x221122, Graphics.COLOR_TRANSPARENT); dc.fillCircle((i * 53 + 17) % _w, (i * 41 + 11) % _h, 1); }

        var flash = (_tick % 6 < 3) ? 0xFF2222 : 0xCC0000;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 10 / 100, Graphics.FONT_MEDIUM, "DESTROYED", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 26 / 100, Graphics.FONT_SMALL, "" + _score + " pts", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF5544, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 40 / 100, Graphics.FONT_XTINY, "KILLS " + _kills, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x4466AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 49 / 100, Graphics.FONT_XTINY, "WAVE " + _level, Graphics.TEXT_JUSTIFY_CENTER);
        if (_maxCombo >= 2) {
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 58 / 100, Graphics.FONT_XTINY, "BEST COMBO x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_score >= _bestScore && _score > 0) {
            dc.setColor((_tick % 8 < 4) ? 0xFFDD44 : 0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 68 / 100, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_bestScore > 0) {
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 68 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0x44FF44 : 0x22CC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 84 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function getWaveNameForLevel(lvl) {
        if (lvl <= 2)  { return "PATROL"; }
        if (lvl <= 4)  { return "CONTACT"; }
        if (lvl <= 6)  { return "DANGER"; }
        if (lvl <= 8)  { return "ASSAULT"; }
        if (lvl <= 10) { return "ELITE"; }
        return "DEATH SQ";
    }
}
