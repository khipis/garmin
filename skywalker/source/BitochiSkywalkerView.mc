using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum {
    SS_MENU,
    SS_HUNT,
    SS_BETWEEN,
    SS_GAMEOVER
}

class BitochiSkywalkerView extends WatchUi.View {

    var accelX;
    var accelY;
    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;
    hidden var _timer;
    hidden var _tick;

    hidden var _aimX;
    hidden var _aimY;
    hidden var _swayPhase;
    hidden var _swayAmp;
    hidden var _driftPhase;

    hidden var _worldW;
    hidden var _worldH;

    hidden var _shipX;
    hidden var _shipY;
    hidden var _shipVx;
    hidden var _shipVy;
    hidden var _shipType;
    hidden var _shipAlive;
    hidden var _shipSize;
    hidden var _shipFlee;
    hidden var _shipCount;

    hidden var _level;
    hidden var _score;
    hidden var _bestScore;
    hidden var _kills;
    hidden var _killTarget;
    hidden var _ammo;
    hidden var _maxAmmo;
    hidden var _timeLeft;
    hidden var _combo;
    hidden var _maxCombo;
    hidden var _shield;
    hidden var _maxShield;

    hidden var _shotFlash;
    hidden var _hitX;
    hidden var _hitY;
    hidden var _hitShow;
    hidden var _recoilTick;
    hidden var _laserSX;
    hidden var _laserSY;
    hidden var _laserShow;

    hidden var _enemyFireShow;
    hidden var _enemyFireIdx;

    hidden var _starX;
    hidden var _starY;
    hidden var _starB;
    hidden var _starPhase;

    hidden var _cometActive;
    hidden var _cometX;
    hidden var _cometY;
    hidden var _cometVx;
    hidden var _cometVy;
    hidden var _cometLife;

    hidden var _betweenTick;
    hidden var _shotMsg;

    hidden const SHIP_MAX = 8;
    hidden const STAR_COUNT = 40;

    hidden var _enemyNames;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());

        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _cx = _w / 2;
        _cy = _h / 2;

        accelX = 0;
        accelY = 0;
        _tick = 0;
        _level = 1;
        _score = 0;
        var bs = Application.Storage.getValue("skyBest");
        _bestScore = (bs != null) ? bs : 0;
        _combo = 0;
        _maxCombo = 0;
        _shield = 100;
        _maxShield = 100;

        _worldW = _w * 5;
        _worldH = _h * 5;

        _aimX = (_worldW / 2).toFloat();
        _aimY = (_worldH / 2).toFloat();
        _swayPhase = 0.0;
        _swayAmp = 2.0;
        _driftPhase = 0.0;

        _shipX = new [SHIP_MAX];
        _shipY = new [SHIP_MAX];
        _shipVx = new [SHIP_MAX];
        _shipVy = new [SHIP_MAX];
        _shipType = new [SHIP_MAX];
        _shipAlive = new [SHIP_MAX];
        _shipSize = new [SHIP_MAX];
        _shipFlee = new [SHIP_MAX];
        _shipCount = 0;

        for (var i = 0; i < SHIP_MAX; i++) {
            _shipX[i] = 0.0; _shipY[i] = 0.0;
            _shipVx[i] = 0.0; _shipVy[i] = 0.0;
            _shipType[i] = 0; _shipAlive[i] = false;
            _shipSize[i] = 8; _shipFlee[i] = 0;
        }

        _starX = new [STAR_COUNT];
        _starY = new [STAR_COUNT];
        _starB = new [STAR_COUNT];
        _starPhase = new [STAR_COUNT];
        for (var i = 0; i < STAR_COUNT; i++) {
            _starX[i] = Math.rand().abs() % _worldW;
            _starY[i] = Math.rand().abs() % _worldH;
            _starB[i] = Math.rand().abs() % 4;
            _starPhase[i] = (Math.rand().abs() % 628).toFloat() / 100.0;
        }
        _cometActive = false;
        _cometX = 0.0; _cometY = 0.0;
        _cometVx = 0.0; _cometVy = 0.0;
        _cometLife = 0;

        _shotFlash = 0;
        _hitX = 0.0; _hitY = 0.0; _hitShow = 0;
        _recoilTick = 0;
        _laserSX = 0; _laserSY = 0; _laserShow = 0;
        _enemyFireShow = 0; _enemyFireIdx = 0;
        _betweenTick = 0;
        _shotMsg = "";
        _ammo = 6;
        _maxAmmo = 6;
        _killTarget = 3;
        _kills = 0;
        _timeLeft = 0;

        _enemyNames = [
            "SCOUT",
            "RAPTOR",
            "CRUSHER",
            "PHANTOM",
            "VIPER",
            "SENTINEL",
            "JUGGERNAUT",
            "OVERLORD"
        ];

        gameState = SS_MENU;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 50, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _tick++;
        _swayPhase += 0.1;
        _driftPhase += 0.03;

        for (var si = 0; si < STAR_COUNT; si++) {
            _starPhase[si] += 0.04 + (si % 5).toFloat() * 0.015;
        }

        if (_cometActive) {
            _cometX += _cometVx;
            _cometY += _cometVy;
            _cometLife--;
            if (_cometLife <= 0) { _cometActive = false; }
        } else if (_tick % 180 == 0 && Math.rand().abs() % 3 == 0) {
            _cometActive = true;
            _cometX = (Math.rand().abs() % _worldW).toFloat();
            _cometY = (Math.rand().abs() % (_worldH / 3)).toFloat();
            _cometVx = 3.0 + (Math.rand().abs() % 30).toFloat() / 10.0;
            _cometVy = 1.0 + (Math.rand().abs() % 15).toFloat() / 10.0;
            if (Math.rand().abs() % 2 == 0) { _cometVx = -_cometVx; }
            _cometLife = 40 + Math.rand().abs() % 30;
        }

        if (gameState == SS_HUNT) {
            updateAim();
            updateShips();
            _timeLeft--;
            if (_timeLeft <= 0) {
                if (_kills >= _killTarget) {
                    gameState = SS_BETWEEN;
                    _betweenTick = 0;
                } else {
                    gameState = SS_GAMEOVER;
                    if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("skyBest", _bestScore); }
                }
            }
            if (_shotFlash > 0) { _shotFlash--; }
            if (_hitShow > 0) { _hitShow--; }
            if (_recoilTick > 0) { _recoilTick--; }
            if (_laserShow > 0) { _laserShow--; }
            if (_enemyFireShow > 0) { _enemyFireShow--; }
        } else if (gameState == SS_BETWEEN) {
            _betweenTick++;
            if (_betweenTick > 80) {
                _level++;
                startLevel();
            }
        }

        WatchUi.requestUpdate();
    }

    hidden function updateAim() {
        var steerX = accelX.toFloat() / 200.0;
        var steerY = accelY.toFloat() / 280.0;
        if (steerX > 4.5) { steerX = 4.5; }
        if (steerX < -4.5) { steerX = -4.5; }
        if (steerY > 3.5) { steerY = 3.5; }
        if (steerY < -3.5) { steerY = -3.5; }

        _aimX += steerX;
        _aimY += steerY;

        var sway = Math.sin(_swayPhase) * _swayAmp;
        var drift = Math.sin(_driftPhase) * (_swayAmp * 0.5);
        _aimX += sway * 0.3;
        _aimY += drift * 0.25;

        if (_aimX < 20.0) { _aimX = 20.0; }
        if (_aimX > (_worldW - 20).toFloat()) { _aimX = (_worldW - 20).toFloat(); }
        if (_aimY < 20.0) { _aimY = 20.0; }
        if (_aimY > (_worldH - 20).toFloat()) { _aimY = (_worldH - 20).toFloat(); }
    }

    hidden function startLevel() {
        _aimX = (_worldW / 2).toFloat();
        _aimY = (_worldH / 2).toFloat();
        _swayAmp = 1.8 + _level.toFloat() * 0.35;
        if (_swayAmp > 5.5) { _swayAmp = 5.5; }
        _ammo = 7 + (_level / 2) + (_level / 4);
        if (_ammo > 16) { _ammo = 16; }
        _maxAmmo = _ammo;
        _killTarget = 3 + (_level - 1) / 2;
        if (_killTarget > SHIP_MAX) { _killTarget = SHIP_MAX; }
        _kills = 0;
        _combo = 0;
        _shotFlash = 0;
        _hitShow = 0;
        _recoilTick = 0;
        _laserShow = 0;
        _enemyFireShow = 0;
        _timeLeft = 620 + _level * 95 + (_level / 3) * 40;
        if (_timeLeft > 2000) { _timeLeft = 2000; }

        var shieldRegen = 15 + _level * 4 + (_level / 3) * 3;
        _shield += shieldRegen;
        if (_shield > _maxShield) { _shield = _maxShield; }
        if (_level % 4 == 0) {
            _shield += 18;
            if (_shield > _maxShield) { _shield = _maxShield; }
        }

        _shipCount = _killTarget;
        if (_shipCount > SHIP_MAX) { _shipCount = SHIP_MAX; }
        for (var i = 0; i < _shipCount; i++) {
            spawnShip(i);
        }
        for (var i = _shipCount; i < SHIP_MAX; i++) { _shipAlive[i] = false; }

        gameState = SS_HUNT;
    }

    hidden function spawnShip(idx) {
        _shipX[idx] = (120 + Math.rand().abs() % (_worldW - 240)).toFloat();
        _shipY[idx] = (120 + Math.rand().abs() % (_worldH - 240)).toFloat();
        _shipVx[idx] = ((Math.rand().abs() % 40) - 20).toFloat() / 10.0;
        _shipVy[idx] = ((Math.rand().abs() % 40) - 20).toFloat() / 10.0;
        var eliteRoll = Math.rand().abs() % 100;
        var maxType = 4;
        if (_level >= 5) { maxType = 6; }
        if (_level >= 9) { maxType = 8; }
        if (_level >= 12 && eliteRoll < 22) {
            _shipType[idx] = 6 + Math.rand().abs() % 2;
        } else {
            _shipType[idx] = Math.rand().abs() % maxType;
        }
        _shipAlive[idx] = true;
        _shipSize[idx] = 7 + Math.rand().abs() % 5;
        if (_level >= 10 && Math.rand().abs() % 5 == 0) { _shipSize[idx] += 1; }
        if (_shipSize[idx] > 12) { _shipSize[idx] = 12; }
        _shipFlee[idx] = 0;
    }

    hidden function updateShips() {
        for (var i = 0; i < _shipCount; i++) {
            if (!_shipAlive[i]) { continue; }

            if (_shipFlee[i] > 0) {
                _shipFlee[i]--;
                _shipVx[i] = _shipVx[i] * 1.03;
                _shipVy[i] = _shipVy[i] * 1.03;
            } else {
                if (_tick % 25 == (i * 7) % 25) {
                    _shipVx[i] = ((Math.rand().abs() % 50) - 25).toFloat() / 10.0;
                    _shipVy[i] = ((Math.rand().abs() % 50) - 25).toFloat() / 10.0;
                }
                var speed = _shipVx[i] * _shipVx[i] + _shipVy[i] * _shipVy[i];
                var maxSpd = 1.15 + _level.toFloat() * 0.22 + (_level / 5).toFloat() * 0.08;
                if (maxSpd > 3.15) { maxSpd = 3.15; }
                if (speed > maxSpd * maxSpd) {
                    _shipVx[i] = _shipVx[i] * 0.82;
                    _shipVy[i] = _shipVy[i] * 0.82;
                }

                var fireEvery = 62 + (_level / 2) * 4;
                if (fireEvery > 88) { fireEvery = 88; }
                if (_tick % fireEvery == (i * 13) % fireEvery && _level >= 2) {
                    var dmg = 4 + (_level * 3) / 2;
                    if (dmg > 16) { dmg = 16; }
                    _shield -= dmg;
                    _enemyFireShow = 6;
                    _enemyFireIdx = i;
                    doVibe(35, 50);
                    if (_shield <= 0) {
                        _shield = 0;
                        gameState = SS_GAMEOVER;
                        if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("skyBest", _bestScore); }
                    }
                }
            }

            _shipX[i] += _shipVx[i];
            _shipY[i] += _shipVy[i];

            if (_shipX[i] < 40.0) { _shipX[i] = 40.0; _shipVx[i] = -_shipVx[i]; }
            if (_shipX[i] > (_worldW - 40).toFloat()) { _shipX[i] = (_worldW - 40).toFloat(); _shipVx[i] = -_shipVx[i]; }
            if (_shipY[i] < 40.0) { _shipY[i] = 40.0; _shipVy[i] = -_shipVy[i]; }
            if (_shipY[i] > (_worldH - 40).toFloat()) { _shipY[i] = (_worldH - 40).toFloat(); _shipVy[i] = -_shipVy[i]; }
        }
    }

    function doShoot() {
        if (gameState == SS_MENU) {
            _level = 1;
            _score = 0;
            _combo = 0;
            _maxCombo = 0;
            _shield = _maxShield;
            startLevel();
            return;
        }
        if (gameState == SS_GAMEOVER) {
            _level = 1;
            _score = 0;
            _combo = 0;
            _maxCombo = 0;
            _shield = _maxShield;
            startLevel();
            return;
        }
        if (gameState == SS_BETWEEN) {
            _level++;
            startLevel();
            return;
        }
        if (gameState != SS_HUNT) { return; }
        if (_ammo <= 0) { return; }

        _ammo--;
        _shotFlash = 5;
        _recoilTick = 4;
        _laserShow = 5;
        doVibe(60, 70);

        var hit = false;
        var bestDist = 9999.0;
        var bestIdx = -1;

        for (var i = 0; i < _shipCount; i++) {
            if (!_shipAlive[i]) { continue; }
            var dx = _aimX - _shipX[i];
            var dy = _aimY - _shipY[i];
            var dist = Math.sqrt(dx * dx + dy * dy);
            var hitR = _shipSize[i].toFloat() + 5.0;
            if (dist < hitR && dist < bestDist) {
                bestDist = dist;
                bestIdx = i;
                hit = true;
            }
        }

        if (hit && bestIdx >= 0) {
            _shipAlive[bestIdx] = false;
            _kills++;
            _combo++;
            if (_combo > _maxCombo) { _maxCombo = _combo; }

            var pts = 100 + (_combo - 1) * 50;
            if (bestDist < 3.0) { pts = pts + 250; _shotMsg = "CRITICAL!"; }
            else if (bestDist < _shipSize[bestIdx].toFloat() * 0.5) { pts = pts + 120; _shotMsg = "DIRECT!"; }
            else { _shotMsg = "DESTROYED!"; }
            _score += pts;

            _hitX = _shipX[bestIdx]; _hitY = _shipY[bestIdx];
            _hitShow = 22;
            _laserSX = (_hitX - _aimX).toNumber() + _cx;
            _laserSY = (_hitY - _aimY).toNumber() + _cy;
            doVibe(90, 130);

            for (var j = 0; j < _shipCount; j++) {
                if (_shipAlive[j] && j != bestIdx) {
                    var fx = _shipX[j] - _shipX[bestIdx];
                    var fy = _shipY[j] - _shipY[bestIdx];
                    var fd = Math.sqrt(fx * fx + fy * fy);
                    if (fd < 180.0 && fd > 0.1) {
                        _shipVx[j] = (fx / fd) * 3.5;
                        _shipVy[j] = (fy / fd) * 3.5;
                        _shipFlee[j] = 35 + Math.rand().abs() % 25;
                    }
                }
            }

            if (_kills >= _killTarget) {
                gameState = SS_BETWEEN;
                _betweenTick = 0;
            }
        } else {
            _combo = 0;
            _shotMsg = "MISS";
            _hitShow = 10;
            _hitX = _aimX; _hitY = _aimY;
            _laserSX = _cx;
            _laserSY = _cy;

            for (var j = 0; j < _shipCount; j++) {
                if (_shipAlive[j]) {
                    var fx = _shipX[j] - _aimX;
                    var fy = _shipY[j] - _aimY;
                    var fd = Math.sqrt(fx * fx + fy * fy);
                    if (fd < 130.0 && fd > 0.1) {
                        _shipVx[j] = (fx / fd) * 2.8;
                        _shipVy[j] = (fy / fd) * 2.8;
                        _shipFlee[j] = 25 + Math.rand().abs() % 20;
                    }
                }
            }
        }

        if (_ammo <= 0 && _kills < _killTarget) {
            var anyAlive = false;
            for (var i = 0; i < _shipCount; i++) {
                if (_shipAlive[i]) { anyAlive = true; }
            }
            if (anyAlive) {
                gameState = SS_GAMEOVER;
                if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("skyBest", _bestScore); }
            }
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;

        if (gameState == SS_MENU) { drawMenu(dc); return; }
        if (gameState == SS_GAMEOVER) { drawGameOver(dc); return; }
        if (gameState == SS_BETWEEN) { drawBetween(dc); return; }

        drawCombatView(dc);
    }

    hidden function drawCombatView(dc) {
        dc.setColor(0x020208, 0x020208);
        dc.clear();

        var rcX = 0;
        var rcY = 0;
        if (_recoilTick > 0) {
            rcY = -_recoilTick;
            rcX = (_recoilTick % 2 == 0) ? 1 : -1;
        }

        drawStarfield(dc, rcX, rcY);
        drawShipsInView(dc, rcX, rcY);
        drawHitFx(dc, rcX, rcY);
        drawEnemyFire(dc, rcX, rcY);
        drawLaserBeam(dc);
        drawCockpitOverlay(dc);
        drawLaserFlash(dc);
        drawHUD(dc);
    }

    hidden function drawStarfield(dc, offX, offY) {
        var i;
        var sx;
        var sy;

        for (i = 0; i < 25; i++) {
            sx = (i * 53 + 17) % _w;
            sy = (i * 41 + 11) % _h;
            var bc = (i % 7 == 0) ? 0x6688AA : ((i % 5 == 0) ? 0xAA8866 : 0x555566);
            dc.setColor(bc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx + offX / 3, sy + offY / 3, 1);
        }

        for (i = 0; i < STAR_COUNT; i++) {
            var parallax = 0.3 + _starB[i].toFloat() * 0.2;
            sx = (_starX[i].toFloat() - _aimX * parallax).toNumber() + _cx + offX;
            sy = (_starY[i].toFloat() - _aimY * parallax).toNumber() + _cy + offY;
            if (sx < -10 || sx > _w + 10 || sy < -10 || sy > _h + 10) { continue; }

            var twinkle = Math.sin(_starPhase[i]);
            var sc;
            if (twinkle < -0.3) {
                if (_starB[i] >= 2) { sc = 0x667788; } else { sc = 0x333344; }
            } else if (twinkle < 0.3) {
                if (_starB[i] == 0) { sc = 0x444455; }
                else if (_starB[i] == 1) { sc = 0x7788AA; }
                else if (_starB[i] == 2) { sc = 0xAABBDD; }
                else { sc = 0xDDEEFF; }
            } else {
                if (_starB[i] <= 1) { sc = 0x99AACC; }
                else { sc = 0xFFFFFF; }
            }
            dc.setColor(sc, Graphics.COLOR_TRANSPARENT);
            var sr = (_starB[i] > 2) ? 2 : 1;
            if (twinkle > 0.7 && _starB[i] >= 2) { sr = 3; }
            dc.fillCircle(sx, sy, sr);

            if (twinkle > 0.85 && _starB[i] == 3) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(sx - 3, sy, sx + 3, sy);
                dc.drawLine(sx, sy - 3, sx, sy + 3);
            }
        }

        if (_cometActive) {
            var cp = 0.5;
            var ccx = (_cometX - _aimX * cp).toNumber() + _cx + offX;
            var ccy = (_cometY - _aimY * cp).toNumber() + _cy + offY;
            if (ccx > -50 && ccx < _w + 50 && ccy > -50 && ccy < _h + 50) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ccx, ccy, 2);
                dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ccx, ccy, 1);
                var tailLen = 5;
                if (tailLen > _cometLife) { tailLen = _cometLife; }
                for (var ct = 1; ct <= tailLen; ct++) {
                    var tx = ccx - (_cometVx * ct.toFloat() * 0.7).toNumber();
                    var ty = ccy - (_cometVy * ct.toFloat() * 0.7).toNumber();
                    var ta;
                    if (ct <= 2) { ta = 0xAABBDD; }
                    else if (ct <= 4) { ta = 0x667788; }
                    else { ta = 0x334455; }
                    dc.setColor(ta, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(tx, ty, 1);
                }
            }
        }

        for (i = 0; i < 3; i++) {
            var np = 0.12;
            var nx = ((i * 631 + 211) % (_worldW * 2) - (_aimX * np).toNumber() + _cx + offX) % (_w + 100) - 50;
            var ny = ((i * 437 + 127) % (_worldH * 2) - (_aimY * np).toNumber() + _cy + offY) % (_h + 100) - 50;
            var nc;
            if (i == 0) { nc = 0x110022; }
            else if (i == 1) { nc = 0x001122; }
            else { nc = 0x1A0808; }
            dc.setColor(nc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(nx, ny, 30 + i * 10);
            if (i == 0) { dc.setColor(0x180030, Graphics.COLOR_TRANSPARENT); }
            else if (i == 1) { dc.setColor(0x002233, Graphics.COLOR_TRANSPARENT); }
            else { dc.setColor(0x220A0A, Graphics.COLOR_TRANSPARENT); }
            dc.fillCircle(nx, ny, 18 + i * 6);
        }

        for (i = 0; i < 6; i++) {
            var ax = ((i * 397 + 71) % _worldW - _aimX.toNumber()) + _cx + offX;
            var ay = ((i * 563 + 113) % _worldH - _aimY.toNumber()) + _cy + offY;
            if (ax < -20 || ax > _w + 20 || ay < -20 || ay > _h + 20) { continue; }
            var asz = 3 + i % 4;
            dc.setColor(0x444433, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax, ay, asz);
            dc.setColor(0x555544, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax - 1, ay - 1, asz - 1);
            dc.setColor(0x666655, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - 1, ay - asz + 1, 2, 1);
        }
    }

    hidden function drawShipsInView(dc, offX, offY) {
        for (var i = 0; i < _shipCount; i++) {
            if (!_shipAlive[i]) { continue; }
            var sx = (_shipX[i] - _aimX).toNumber() + _cx + offX;
            var sy = (_shipY[i] - _aimY).toNumber() + _cy + offY;
            if (sx < -40 || sx > _w + 40 || sy < -40 || sy > _h + 40) { continue; }
            drawShipSprite(dc, sx, sy, _shipType[i], _shipSize[i], _shipVx[i], _shipFlee[i] > 0);
        }
    }

    hidden function drawShipSprite(dc, sx, sy, stype, ssize, vx, fleeing) {
        var sz = ssize;
        var hullC = 0x667788;
        var wingC = 0x445566;
        var engineC = 0xFF4400;
        var accentC = 0x556677;

        if (stype == 0) {
            hullC = 0x778899; wingC = 0x556677; engineC = 0xFF4400;
        } else if (stype == 1) {
            hullC = 0x4455AA; wingC = 0x334488; engineC = 0x4488FF;
        } else if (stype == 2) {
            hullC = 0x557755; wingC = 0x446644; engineC = 0xFF8800;
        } else if (stype == 3) {
            hullC = 0x333344; wingC = 0x222233; engineC = 0x8844FF;
        } else if (stype == 4) {
            hullC = 0xAA8844; wingC = 0x886633; engineC = 0x44FF44;
        } else if (stype == 5) {
            hullC = 0x99AAAA; wingC = 0x778888; engineC = 0xCCDDFF;
        } else if (stype == 6) {
            hullC = 0x994444; wingC = 0x773333; engineC = 0xFF2200;
        } else if (stype == 7) {
            hullC = 0x665577; wingC = 0x443355; engineC = 0xFF44FF;
        }

        if (fleeing) { sz = sz + (_tick % 2); }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx + 1, sy + 1, sz / 2);

        if (stype == 0) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, sz * 40 / 100);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz - 1, sy - sz + 3, 3, sz * 2 - 6);
            dc.fillRectangle(sx + sz - 1, sy - sz + 3, 3, sz * 2 - 6);
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx - sz * 40 / 100, sy, sx - sz, sy);
            dc.drawLine(sx + sz * 40 / 100, sy, sx + sz - 1, sy);
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, sz * 20 / 100);
        } else if (stype == 1) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - sz / 3], [sx + sz / 3, sy + sz / 3], [sx - sz / 3, sy + sz / 3]]);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx - sz / 3, sy], [sx - sz, sy - sz + 2], [sx - sz - 2, sy - sz / 2]]);
            dc.fillPolygon([[sx + sz / 3, sy], [sx + sz, sy - sz + 2], [sx + sz + 2, sy - sz / 2]]);
            dc.setColor(0x6688BB, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, sz / 4);
        } else if (stype == 2) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx - sz / 2, sy, sz * 40 / 100);
            dc.fillCircle(sx + sz / 2, sy, sz * 40 / 100);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz / 2, sy - 2, sz, 4);
            dc.setColor(0x668866, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 2, sy + sz * 40 / 100, 4, 3);
        } else if (stype == 3) {
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - sz], [sx + sz, sy + sz / 2], [sx - sz, sy + sz / 2]]);
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy - sz / 4, sz / 3);
            dc.setColor(0x444466, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy - sz / 4, sz / 5);
        } else if (stype == 4) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - sz], [sx + sz / 2, sy], [sx, sy + sz / 2], [sx - sz / 2, sy]]);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz - 2, sy - sz / 4, sz / 2, 3);
            dc.fillRectangle(sx + sz / 2 + 2, sy - sz / 4, sz / 2, 3);
            dc.setColor(0xCCAA66, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy - sz / 3, sz / 4);
        } else if (stype == 5) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz / 3, sy - sz, sz * 2 / 3, sz * 2);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx - sz / 3, sy - sz / 3], [sx - sz, sy + sz], [sx - sz / 3, sy + sz]]);
            dc.fillPolygon([[sx + sz / 3, sy - sz / 3], [sx + sz, sy + sz], [sx + sz / 3, sy + sz]]);
            dc.setColor(0xAABBBB, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 2, sy - sz + 1, 4, 3);
        } else if (stype == 6) {
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz, sy - sz / 2, sz * 2, sz);
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz / 3, sy - sz / 2 - sz / 4, sz * 2 / 3, sz / 4);
            dc.setColor(0xAA5555, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz - 2, sy + sz / 4, 3, 4);
            dc.fillRectangle(sx + sz, sy + sz / 4, 3, 4);
            dc.setColor(0xCC6666, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx - sz / 2, sy, 2);
            dc.fillCircle(sx + sz / 2, sy, 2);
        } else {
            dc.setColor(wingC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - sz * 3 / 2], [sx + sz, sy + sz / 2], [sx - sz, sy + sz / 2]]);
            dc.setColor(hullC, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx, sy - sz], [sx + sz * 2 / 3, sy + sz / 3], [sx - sz * 2 / 3, sy + sz / 3]]);
            dc.setColor(0x776688, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz / 4, sy - sz / 4, sz / 2, sz / 4);
            dc.setColor(0xFF44FF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz / 3, sy + sz / 2, sz * 2 / 3, 3);
        }

        dc.setColor(engineC, Graphics.COLOR_TRANSPARENT);
        if (stype == 2) {
            dc.fillCircle(sx - sz / 2, sy + sz * 40 / 100 + 2, 2);
            dc.fillCircle(sx + sz / 2, sy + sz * 40 / 100 + 2, 2);
        } else if (stype == 6) {
            dc.fillCircle(sx - sz - 1, sy + sz / 4 + 5, 2);
            dc.fillCircle(sx + sz + 1, sy + sz / 4 + 5, 2);
        } else if (stype == 7) {
            dc.fillRectangle(sx - sz / 4, sy + sz / 2 + 3, sz / 2, 2);
        } else {
            dc.fillCircle(sx, sy + sz / 2 + 2, 2);
        }

        if (fleeing) {
            dc.setColor(engineC, Graphics.COLOR_TRANSPARENT);
            var trailLen = 4 + _tick % 4;
            dc.fillRectangle(sx - 1, sy + sz / 2 + 3, 2, trailLen);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, sy + sz / 2 + 3, 1, trailLen / 2);
        }
    }

    hidden function drawHitFx(dc, offX, offY) {
        if (_hitShow <= 0) { return; }
        var hx = (_hitX - _aimX).toNumber() + _cx + offX;
        var hy = (_hitY - _aimY).toNumber() + _cy + offY;

        if (_shotMsg.equals("MISS")) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hx, hy, 2);
        } else {
            var flashC = (_hitShow % 4 < 2) ? 0xFF6622 : 0xFFCC22;
            dc.setColor(flashC, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 8; i++) {
                var px = hx + (Math.rand().abs() % 20) - 10;
                var py = hy + (Math.rand().abs() % 20) - 10;
                dc.fillRectangle(px, py, 3, 3);
            }
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hx, hy, 5 + _hitShow / 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hx, hy, 3);
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hx, hy, 4 + _hitShow / 3);

            if (_hitShow > 12) {
                dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
                for (var i = 0; i < 6; i++) {
                    var a = (i * 60 + _tick * 15).toFloat() * 3.14159 / 180.0;
                    var dr = 8 + _hitShow / 2;
                    var dx = hx + (dr * Math.cos(a)).toNumber();
                    var dy = hy + (dr * Math.sin(a)).toNumber();
                    dc.fillRectangle(dx, dy, 2, 2);
                }
            }

            if (_hitShow > 5 && _hitShow < 18) {
                dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
                for (var i = 0; i < 4; i++) {
                    var px = hx + (Math.rand().abs() % 24) - 12;
                    var py = hy + (Math.rand().abs() % 24) - 12;
                    dc.fillRectangle(px, py, 2, 3);
                }
            }
        }
    }

    hidden function drawEnemyFire(dc, offX, offY) {
        if (_enemyFireShow <= 0) { return; }
        if (_enemyFireIdx >= _shipCount) { return; }
        var esx = (_shipX[_enemyFireIdx] - _aimX).toNumber() + _cx + offX;
        var esy = (_shipY[_enemyFireIdx] - _aimY).toNumber() + _cy + offY;
        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(esx, esy, _cx, _cy);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(esx + 1, esy, _cx + 1, _cy);
        dc.drawLine(esx - 1, esy, _cx - 1, _cy);

        dc.setColor(0x4488FF, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, 8 + _enemyFireShow * 2);
        dc.drawCircle(_cx, _cy, 6 + _enemyFireShow * 2);
        dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, 10 + _enemyFireShow * 2);
    }

    hidden function drawLaserBeam(dc) {
        if (_laserShow <= 0) { return; }
        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx, _h, _laserSX, _laserSY);
        dc.setColor(0x88FFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - 1, _h, _laserSX - 1, _laserSY);
        dc.drawLine(_cx + 1, _h, _laserSX + 1, _laserSY);
        dc.setColor(0x22AA44, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - 2, _h, _laserSX - 2, _laserSY);
        dc.drawLine(_cx + 2, _h, _laserSX + 2, _laserSY);

        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_laserSX, _laserSY, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_laserSX, _laserSY, 2);
    }

    hidden function drawCockpitOverlay(dc) {
        var r = _cx;
        if (_cy < r) { r = _cy; }
        r = r - 2;

        dc.setColor(0x0A0A14, Graphics.COLOR_TRANSPARENT);
        for (var ring = r; ring < r + 35; ring++) {
            dc.drawCircle(_cx, _cy, ring);
        }

        dc.setColor(0x111122, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r);
        dc.drawCircle(_cx, _cy, r - 1);
        dc.setColor(0x1A1A2A, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r - 2);
        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r - 3);
        dc.setColor(0x182838, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r - 4);

        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - 16, _cy - 20, _cx - 16, _cy - 12);
        dc.drawLine(_cx - 16, _cy - 20, _cx - 8, _cy - 20);
        dc.drawLine(_cx + 16, _cy - 20, _cx + 16, _cy - 12);
        dc.drawLine(_cx + 16, _cy - 20, _cx + 8, _cy - 20);
        dc.drawLine(_cx - 16, _cy + 20, _cx - 16, _cy + 12);
        dc.drawLine(_cx - 16, _cy + 20, _cx - 8, _cy + 20);
        dc.drawLine(_cx + 16, _cy + 20, _cx + 16, _cy + 12);
        dc.drawLine(_cx + 16, _cy + 20, _cx + 8, _cy + 20);

        dc.setColor(0x22CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - 7, _cy, _cx - 2, _cy);
        dc.drawLine(_cx + 2, _cy, _cx + 7, _cy);
        dc.drawLine(_cx, _cy - 7, _cx, _cy - 2);
        dc.drawLine(_cx, _cy + 2, _cx, _cy + 7);

        dc.setColor(0x44FFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 1);

        dc.setColor(0x113322, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i <= 3; i++) {
            var d = r * i * 20 / 100;
            dc.fillRectangle(_cx - 2, _cy - d, 4, 1);
            dc.fillRectangle(_cx - 2, _cy + d, 4, 1);
            dc.fillRectangle(_cx - d, _cy - 1, 1, 2);
            dc.fillRectangle(_cx + d, _cy - 1, 1, 2);
        }

        dc.setColor(0x112222, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r * 50 / 100);
        dc.setColor(0x0A1818, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r * 28 / 100);

        dc.setColor(0x111118, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r - 6);

        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - r + 10, _cy + r * 60 / 100, _cx - r * 30 / 100, _h - 4);
        dc.drawLine(_cx + r - 10, _cy + r * 60 / 100, _cx + r * 30 / 100, _h - 4);
        dc.setColor(0x1A2A3A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx - r * 30 / 100, _h - 6, r * 60 / 100, 6);
    }

    hidden function drawLaserFlash(dc) {
        if (_shotFlash <= 0) { return; }
        var fa = _shotFlash * 40;
        if (fa > 0xFF) { fa = 0xFF; }
        dc.setColor((fa / 3) << 16 | fa << 8 | (fa / 3), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _h, _shotFlash * 10);
    }

    hidden function drawHUD(dc) {
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _maxAmmo; i++) {
            var bx = 8 + i * 6;
            var by = _h - 16;
            if (bx > _w * 40 / 100) { break; }
            if (i < _ammo) {
                dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, 3, 8);
                dc.setColor(0x22AA22, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, 3, 3);
            } else {
                dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, 3, 8);
            }
        }

        dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 4, 4, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 4, Graphics.FONT_XTINY, _kills + "/" + _killTarget, Graphics.TEXT_JUSTIFY_LEFT);

        var sec = _timeLeft / 20;
        var tC = sec > 10 ? 0x88AACC : ((_tick % 6 < 3) ? 0xFF4444 : 0xFF8844);
        dc.setColor(tC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h - 18, Graphics.FONT_XTINY, "" + sec + "s", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x556688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 4, Graphics.FONT_XTINY, "W" + _level, Graphics.TEXT_JUSTIFY_CENTER);

        var shieldW = _w * 30 / 100;
        var shieldX = _w - shieldW - 6;
        var shieldY = _h - 14;
        dc.setColor(0x112233, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(shieldX, shieldY, shieldW, 5);
        var sw = shieldW * _shield / _maxShield;
        var shieldColor = (_shield > 60) ? 0x4488FF : ((_shield > 30) ? 0xFFAA22 : 0xFF2222);
        dc.setColor(shieldColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(shieldX, shieldY, sw, 5);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(shieldX - 2, shieldY - 2, Graphics.FONT_XTINY, "S", Graphics.TEXT_JUSTIFY_RIGHT);

        if (_hitShow > 0) {
            var msgC = 0xFFFFFF;
            if (_shotMsg.equals("CRITICAL!")) { msgC = 0xFF4444; }
            else if (_shotMsg.equals("DIRECT!")) { msgC = 0xFFCC44; }
            else if (_shotMsg.equals("DESTROYED!")) { msgC = 0x44FF44; }
            else if (_shotMsg.equals("MISS")) { msgC = 0x666666; }
            dc.setColor(msgC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy + _cy * 45 / 100, Graphics.FONT_SMALL, _shotMsg, Graphics.TEXT_JUSTIFY_CENTER);

            if (_combo >= 2) {
                dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_cx, _cy + _cy * 62 / 100, Graphics.FONT_XTINY, "x" + _combo + " STREAK", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (_enemyFireShow > 3) {
            var warnFlash = (_tick % 4 < 2) ? 0xFF2222 : 0xFF6644;
            dc.setColor(warnFlash, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, 16, Graphics.FONT_XTINY, "!! INCOMING !!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x020208, 0x020208);
        dc.clear();

        var i;
        for (i = 0; i < 30; i++) {
            var sx = (i * 53 + 17) % _w;
            var sy = (i * 41 + 11) % _h;
            var sc = (i % 6 == 0) ? 0x7799BB : ((i % 4 == 0) ? 0x556688 : 0x334455);
            dc.setColor(sc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy, (i % 8 == 0) ? 2 : 1);
        }

        dc.setColor(0x0A0A22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx + 30, _cy - 20, 25);
        dc.setColor(0x111133, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx + 30, _cy - 20, 18);

        drawCockpitOverlay(dc);

        var pulse = (_tick % 20 < 10) ? 0x44FF88 : 0x22CC66;
        dc.setColor(0x114422, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, _h * 10 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 10 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 25 / 100, Graphics.FONT_MEDIUM, "SKYWALKER", Graphics.TEXT_JUSTIFY_CENTER);

        drawShipSprite(dc, _cx - 22, _cy + 5, (_tick / 40) % 8, 8, 1.0, false);
        drawShipSprite(dc, _cx + 22, _cy + 5, ((_tick / 40) + 4) % 8, 7, -1.0, false);

        dc.setColor(0x7799AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 58 / 100, Graphics.FONT_XTINY, "Hunt Imperial fighters!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, _h * 65 / 100, Graphics.FONT_XTINY, "Tilt to aim", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, _h * 72 / 100, Graphics.FONT_XTINY, "Tap to fire laser", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestScore > 0) {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 82 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 91 / 100, Graphics.FONT_XTINY, "Press to launch", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawBetween(dc) {
        dc.setColor(0x020208, 0x020208);
        dc.clear();

        for (var i = 0; i < 15; i++) {
            dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((i * 53 + 17) % _w, (i * 41 + 11) % _h, 1);
        }

        var flash = (_betweenTick % 8 < 4) ? 0x44FF88 : 0x22CC66;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 15 / 100, Graphics.FONT_MEDIUM, "WAVE CLEAR", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 33 / 100, Graphics.FONT_SMALL, "SCORE " + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 48 / 100, Graphics.FONT_XTINY, "KILLS " + _kills + "/" + _killTarget, Graphics.TEXT_JUSTIFY_CENTER);

        if (_maxCombo >= 2) {
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 56 / 100, Graphics.FONT_XTINY, "BEST STREAK x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x4488FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 65 / 100, Graphics.FONT_XTINY, "SHIELD " + _shield + "%", Graphics.TEXT_JUSTIFY_CENTER);

        var msgs = ["Charging weapons...", "Entering sector...", "Scanning area..."];
        var mi = _level % msgs.size();
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 78 / 100, Graphics.FONT_XTINY, msgs[mi], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x556688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_XTINY, "AMMO LEFT " + _ammo, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x080008, 0x080008);
        dc.clear();

        for (var i = 0; i < 10; i++) {
            dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((i * 53 + 17) % _w, (i * 41 + 11) % _h, 1);
        }

        var flash = (_tick % 6 < 3) ? 0xFF2222 : 0xCC0000;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 12 / 100, Graphics.FONT_MEDIUM, "DESTROYED", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 30 / 100, Graphics.FONT_SMALL, "SCORE " + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 44 / 100, Graphics.FONT_XTINY, "KILLS " + _kills, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x556688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 52 / 100, Graphics.FONT_XTINY, "WAVE " + _level, Graphics.TEXT_JUSTIFY_CENTER);

        if (_maxCombo >= 2) {
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 60 / 100, Graphics.FONT_XTINY, "BEST STREAK x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 70 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 84 / 100, Graphics.FONT_XTINY, "Press to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
