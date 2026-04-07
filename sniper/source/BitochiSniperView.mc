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

class BitochiSniperView extends WatchUi.View {

    var accelX;
    var accelY;
    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;
    hidden var _timer;
    hidden var _tick;

    // scope aim position (world coords, scope looks at this point)
    hidden var _aimX;
    hidden var _aimY;
    hidden var _swayPhase;
    hidden var _swayAmp;
    hidden var _breathPhase;

    // world size (virtual field creatures move in)
    hidden var _worldW;
    hidden var _worldH;

    // creatures
    hidden var _creatX;
    hidden var _creatY;
    hidden var _creatVx;
    hidden var _creatVy;
    hidden var _creatType;
    hidden var _creatAlive;
    hidden var _creatSize;
    hidden var _creatCount;
    hidden var _creatFlee;

    // level / scoring
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

    // FX
    hidden var _shotFlash;
    hidden var _hitX;
    hidden var _hitY;
    hidden var _hitShow;
    hidden var _shellX;
    hidden var _shellY;
    hidden var _shellLife;
    hidden var _recoilTick;

    // grass tufts (background detail)
    hidden var _grassX;
    hidden var _grassY;
    hidden var _grassH;

    // wind
    hidden var _windX;
    hidden var _windPhase;

    hidden var _betweenTick;
    hidden var _shotMsg;

    hidden const CREAT_MAX = 8;
    hidden const GRASS_COUNT = 20;


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
        var bs = Application.Storage.getValue("snipBest");
        _bestScore = (bs != null) ? bs : 0;
        _combo = 0;
        _maxCombo = 0;

        _worldW = _w * 4;
        _worldH = _h * 4;

        _aimX = (_worldW / 2).toFloat();
        _aimY = (_worldH / 2).toFloat();
        _swayPhase = 0.0;
        _swayAmp = 3.0;
        _breathPhase = 0.0;

        _creatX = new [CREAT_MAX];
        _creatY = new [CREAT_MAX];
        _creatVx = new [CREAT_MAX];
        _creatVy = new [CREAT_MAX];
        _creatType = new [CREAT_MAX];
        _creatAlive = new [CREAT_MAX];
        _creatSize = new [CREAT_MAX];
        _creatFlee = new [CREAT_MAX];
        _creatCount = 0;

        for (var i = 0; i < CREAT_MAX; i++) {
            _creatX[i] = 0.0; _creatY[i] = 0.0;
            _creatVx[i] = 0.0; _creatVy[i] = 0.0;
            _creatType[i] = 0; _creatAlive[i] = false;
            _creatSize[i] = 8; _creatFlee[i] = 0;
        }

        _grassX = new [GRASS_COUNT];
        _grassY = new [GRASS_COUNT];
        _grassH = new [GRASS_COUNT];
        for (var i = 0; i < GRASS_COUNT; i++) {
            _grassX[i] = Math.rand().abs() % _worldW;
            _grassY[i] = Math.rand().abs() % _worldH;
            _grassH[i] = 3 + Math.rand().abs() % 5;
        }

        _shotFlash = 0;
        _hitX = 0; _hitY = 0; _hitShow = 0;
        _shellX = new [4]; _shellY = new [4]; _shellLife = new [4];
        for (var i = 0; i < 4; i++) { _shellX[i] = 0; _shellY[i] = 0; _shellLife[i] = 0; }
        _recoilTick = 0;
        _windPhase = 0.0;
        _windX = 0.0;
        _betweenTick = 0;
        _shotMsg = "";
        _ammo = 5;
        _maxAmmo = 5;
        _killTarget = 3;
        _kills = 0;
        _timeLeft = 0;

        gameState = SS_MENU;
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

        _swayPhase += 0.13;
        _breathPhase += 0.04;
        _windPhase += 0.02;
        var windAmp = 0.45 + _level.toFloat() * 0.11 + (_level / 4).toFloat() * 0.04;
        if (windAmp > 1.35) { windAmp = 1.35; }
        _windX = Math.sin(_windPhase) * windAmp;

        if (gameState == SS_HUNT) {
            updateAim();
            updateCreatures();
            _timeLeft--;
            if (_timeLeft <= 0) {
                if (_kills >= _killTarget) {
                    gameState = SS_BETWEEN;
                    _betweenTick = 0;
                } else {
                    gameState = SS_GAMEOVER;
                    if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("snipBest", _bestScore); }
                }
            }
            if (_shotFlash > 0) { _shotFlash--; }
            if (_hitShow > 0) { _hitShow--; }
            if (_recoilTick > 0) { _recoilTick--; }
            for (var i = 0; i < 4; i++) {
                if (_shellLife[i] > 0) {
                    _shellLife[i]--;
                    _shellY[i] = _shellY[i] + 2;
                    _shellX[i] = _shellX[i] + 1;
                }
            }
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
        var steerX = accelX.toFloat() / 100.0;
        var steerY = accelY.toFloat() / 135.0;
        if (steerX > 5.5) { steerX = 5.5; }
        if (steerX < -5.5) { steerX = -5.5; }
        if (steerY > 4.5) { steerY = 4.5; }
        if (steerY < -4.5) { steerY = -4.5; }

        _aimX += steerX;
        _aimY += steerY;

        var sway = Math.sin(_swayPhase) * _swayAmp;
        var breath = Math.sin(_breathPhase) * (_swayAmp * 0.7);
        _aimX += sway * 0.08 + _windX * 0.06;
        _aimY += breath * 0.06;

        if (_aimX < 20.0) { _aimX = 20.0; }
        if (_aimX > (_worldW - 20).toFloat()) { _aimX = (_worldW - 20).toFloat(); }
        if (_aimY < 20.0) { _aimY = 20.0; }
        if (_aimY > (_worldH - 20).toFloat()) { _aimY = (_worldH - 20).toFloat(); }
    }

    hidden function startLevel() {
        _aimX = (_worldW / 2).toFloat();
        _aimY = (_worldH / 2).toFloat();
        _swayAmp = 0.8 + _level.toFloat() * 0.14;
        if (_swayAmp > 2.8) { _swayAmp = 2.8; }
        _ammo = 6 + (_level / 2) + (_level / 3);
        if (_ammo > 14) { _ammo = 14; }
        _maxAmmo = _ammo;
        _killTarget = 3 + (_level - 1) / 2;
        if (_killTarget > CREAT_MAX) { _killTarget = CREAT_MAX; }
        _kills = 0;
        _combo = 0;
        _shotFlash = 0;
        _hitShow = 0;
        _recoilTick = 0;
        _timeLeft = 620 + _level * 78 + (_level / 3) * 35;
        if (_timeLeft > 1750) { _timeLeft = 1750; }

        _creatCount = _killTarget;
        if (_creatCount > CREAT_MAX) { _creatCount = CREAT_MAX; }
        for (var i = 0; i < _creatCount; i++) {
            spawnCreature(i);
        }
        for (var i = _creatCount; i < CREAT_MAX; i++) { _creatAlive[i] = false; }

        gameState = SS_HUNT;
    }

    hidden function spawnCreature(idx) {
        _creatX[idx] = (100 + Math.rand().abs() % (_worldW - 200)).toFloat();
        _creatY[idx] = (100 + Math.rand().abs() % (_worldH - 200)).toFloat();
        _creatVx[idx] = ((Math.rand().abs() % 30) - 15).toFloat() / 10.0;
        _creatVy[idx] = ((Math.rand().abs() % 30) - 15).toFloat() / 10.0;
        _creatType[idx] = Math.rand().abs() % 8;
        _creatAlive[idx] = true;
        _creatSize[idx] = 36 + Math.rand().abs() % 8;
        _creatFlee[idx] = 0;
    }

    hidden function updateCreatures() {
        for (var i = 0; i < _creatCount; i++) {
            if (!_creatAlive[i]) { continue; }

            if (_creatFlee[i] > 0) {
                _creatFlee[i]--;
                _creatVx[i] = _creatVx[i] * 1.02;
                _creatVy[i] = _creatVy[i] * 1.02;
            } else {
                if (_tick % 30 == (i * 7) % 30) {
                    _creatVx[i] = ((Math.rand().abs() % 40) - 20).toFloat() / 10.0;
                    _creatVy[i] = ((Math.rand().abs() % 40) - 20).toFloat() / 10.0;
                }
                var speed = _creatVx[i] * _creatVx[i] + _creatVy[i] * _creatVy[i];
                var maxSpd = 1.0 + _level.toFloat() * 0.2 + (_level / 4).toFloat() * 0.06;
                if (maxSpd > 2.65) { maxSpd = 2.65; }
                if (speed > maxSpd * maxSpd) {
                    _creatVx[i] = _creatVx[i] * 0.85;
                    _creatVy[i] = _creatVy[i] * 0.85;
                }
            }

            _creatX[i] += _creatVx[i];
            _creatY[i] += _creatVy[i];

            if (_creatX[i] < 30.0) { _creatX[i] = 30.0; _creatVx[i] = -_creatVx[i]; }
            if (_creatX[i] > (_worldW - 30).toFloat()) { _creatX[i] = (_worldW - 30).toFloat(); _creatVx[i] = -_creatVx[i]; }
            if (_creatY[i] < 30.0) { _creatY[i] = 30.0; _creatVy[i] = -_creatVy[i]; }
            if (_creatY[i] > (_worldH - 30).toFloat()) { _creatY[i] = (_worldH - 30).toFloat(); _creatVy[i] = -_creatVy[i]; }
        }
    }

    function doShoot() {
        if (gameState == SS_MENU) {
            _level = 1;
            _score = 0;
            _combo = 0;
            _maxCombo = 0;
            startLevel();
            return;
        }
        if (gameState == SS_GAMEOVER) {
            _level = 1;
            _score = 0;
            _combo = 0;
            _maxCombo = 0;
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
        _recoilTick = 6;
        doVibe(70, 80);
        spawnShell();

        var hit = false;
        var bestDist = 9999.0;
        var bestIdx = -1;

        for (var i = 0; i < _creatCount; i++) {
            if (!_creatAlive[i]) { continue; }
            var dx = _aimX - _creatX[i];
            var dy = _aimY - _creatY[i];
            var dist = Math.sqrt(dx * dx + dy * dy);
            var hitR = _creatSize[i].toFloat() + 4.0;
            if (dist < hitR && dist < bestDist) {
                bestDist = dist;
                bestIdx = i;
                hit = true;
            }
        }

        if (hit && bestIdx >= 0) {
            _creatAlive[bestIdx] = false;
            _kills++;
            _combo++;
            if (_combo > _maxCombo) { _maxCombo = _combo; }

            var pts = 100 + (_combo - 1) * 50;
            if (bestDist < _creatSize[bestIdx].toFloat() * 0.18) {
                pts = pts + 200;
                _shotMsg = "HEADSHOT!";
                _ammo++;
                if (_ammo > _maxAmmo) { _maxAmmo = _ammo; }
                if (_maxAmmo > 15) { _maxAmmo = 15; _ammo = 15; }
            } else if (bestDist < _creatSize[bestIdx].toFloat() * 0.5) {
                pts = pts + 100;
                _shotMsg = "CLEAN!";
                if (_combo >= 3) {
                    _ammo++;
                    if (_ammo > _maxAmmo) { _maxAmmo = _ammo; }
                    if (_maxAmmo > 15) { _maxAmmo = 15; _ammo = 15; }
                }
            } else { _shotMsg = "HIT!"; }
            _score += pts;

            _hitX = _creatX[bestIdx]; _hitY = _creatY[bestIdx];
            _hitShow = 20;
            doVibe(90, 120);

            for (var j = 0; j < _creatCount; j++) {
                if (_creatAlive[j] && j != bestIdx) {
                    var fx = _creatX[j] - _creatX[bestIdx];
                    var fy = _creatY[j] - _creatY[bestIdx];
                    var fd = Math.sqrt(fx * fx + fy * fy);
                    if (fd < 150.0 && fd > 0.1) {
                        _creatVx[j] = (fx / fd) * 3.0;
                        _creatVy[j] = (fy / fd) * 3.0;
                        _creatFlee[j] = 40 + Math.rand().abs() % 30;
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
            _hitShow = 12;
            _hitX = _aimX; _hitY = _aimY;

            for (var j = 0; j < _creatCount; j++) {
                if (_creatAlive[j]) {
                    var fx = _creatX[j] - _aimX;
                    var fy = _creatY[j] - _aimY;
                    var fd = Math.sqrt(fx * fx + fy * fy);
                    if (fd < 120.0 && fd > 0.1) {
                        _creatVx[j] = (fx / fd) * 2.5;
                        _creatVy[j] = (fy / fd) * 2.5;
                        _creatFlee[j] = 30 + Math.rand().abs() % 20;
                    }
                }
            }
        }

        if (_ammo <= 0 && _kills < _killTarget) {
            var anyAlive = false;
            for (var i = 0; i < _creatCount; i++) {
                if (_creatAlive[i]) { anyAlive = true; }
            }
            if (anyAlive) {
                gameState = SS_GAMEOVER;
                if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("snipBest", _bestScore); }
            }
        }
    }

    hidden function spawnShell() {
        for (var i = 0; i < 4; i++) {
            if (_shellLife[i] <= 0) {
                _shellX[i] = _cx + 8 + Math.rand().abs() % 6;
                _shellY[i] = _cy + Math.rand().abs() % 4;
                _shellLife[i] = 12;
                break;
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

        drawScopeView(dc);
    }

    hidden function drawScopeView(dc) {
        dc.setColor(0x1A3318, 0x1A3318);
        dc.clear();

        var rcX = 0;
        var rcY = 0;
        if (_recoilTick > 0) {
            rcY = -_recoilTick;
            rcX = (_recoilTick % 2 == 0) ? 1 : -1;
        }

        drawTerrain(dc, rcX, rcY);
        drawCreaturesInScope(dc, rcX, rcY);
        drawHitFx(dc, rcX, rcY);

        drawScopeOverlay(dc);
        drawShotFlash(dc);
        drawShells(dc);
        drawHUD(dc);
    }

    hidden function drawTerrain(dc, offX, offY) {
        var sway = (_tick % 12 < 6) ? 1 : 0;
        for (var i = 0; i < GRASS_COUNT; i++) {
            var sx = (_grassX[i].toFloat() - _aimX).toNumber() + _cx + offX;
            var sy = (_grassY[i].toFloat() - _aimY).toNumber() + _cy + offY;
            if (sx < -20 || sx > _w + 20 || sy < -20 || sy > _h + 20) { continue; }
            var gh = _grassH[i];
            var gc = (i % 5 == 0) ? 0x2D5A1E : ((i % 5 == 1) ? 0x3A6B2E : ((i % 5 == 2) ? 0x1E4A12 : ((i % 5 == 3) ? 0x48822E : 0x265218)));
            dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
            var sw = (gh > 5 && i % 3 == 0) ? sway : 0;
            dc.fillRectangle(sx + sw, sy, 2, gh);
            dc.fillRectangle(sx - 1 + sw, sy + 1, 1, gh - 2);
            dc.fillRectangle(sx + 2 + sw, sy + 2, 1, gh - 3);

            if (gh > 5) {
                dc.setColor(0x5AA848, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(sx + sw, sy, 1, 2);
            }
            if (gh > 7 && i % 4 == 0) {
                dc.setColor(0xCCDD44, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(sx + 1 + sw, sy - 1, 1, 1);
            }
        }

        for (var i = 0; i < 8; i++) {
            var rx = ((i * 317 + 51) % _worldW - _aimX.toNumber()) + _cx + offX;
            var ry = ((i * 523 + 97) % _worldH - _aimY.toNumber()) + _cy + offY;
            if (rx < -20 || rx > _w + 20 || ry < -20 || ry > _h + 20) { continue; }
            var rsz = 3 + i % 4;
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(rx, ry, rsz);
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(rx - 1, ry - 1, rsz - 1);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx - 1, ry - rsz + 1, 2, 1);
        }

        for (var i = 0; i < 3; i++) {
            var bx = ((i * 731 + 199) % _worldW - _aimX.toNumber()) + _cx + offX;
            var by = ((i * 439 + 311) % _worldH - _aimY.toNumber()) + _cy + offY;
            if (bx < -20 || bx > _w + 20 || by < -20 || by > _h + 20) { continue; }
            dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, by - 6, 3, 8);
            dc.setColor(0x226622, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx + 1, by - 8, 5);
            dc.setColor(0x338833, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx + 1, by - 9, 3);
        }
    }

    hidden function drawCreaturesInScope(dc, offX, offY) {
        for (var i = 0; i < _creatCount; i++) {
            if (!_creatAlive[i]) { continue; }
            var sx = (_creatX[i] - _aimX).toNumber() + _cx + offX;
            var sy = (_creatY[i] - _aimY).toNumber() + _cy + offY;
            if (sx < -30 || sx > _w + 30 || sy < -30 || sy > _h + 30) { continue; }

            drawCreatureSprite(dc, sx, sy, _creatType[i], _creatSize[i], _creatVx[i], _creatFlee[i] > 0);
        }
    }

    hidden function drawCreatureSprite(dc, sx, sy, ctype, csize, vx, fleeing) {
        var bodyC = 0xCC8844;
        var eyeC = 0x111111;
        var accentC = 0xFFAA44;
        var sz = csize;

        if (ctype == 0) {
            bodyC = 0xFFCC66; accentC = 0xFF8844;
        } else if (ctype == 1) {
            bodyC = 0xDD9955; accentC = 0xBB7733;
        } else if (ctype == 2) {
            bodyC = 0x882244; accentC = 0xAA3366; eyeC = 0xFF0000;
        } else if (ctype == 3) {
            bodyC = 0x443355; accentC = 0x665577;
        } else if (ctype == 4) {
            bodyC = 0xBB8844; accentC = 0xDD9944;
        } else if (ctype == 5) {
            bodyC = 0xCC6644; accentC = 0xAA5533;
        } else if (ctype == 6) {
            bodyC = 0x8899AA; accentC = 0xAABBCC;
        } else if (ctype == 7) {
            bodyC = 0x556655; accentC = 0x778877; eyeC = 0x44FF44;
        }

        if (fleeing) {
            sz = sz + (_tick % 2);
        }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx + 1, sy + sz / 2 + 1, sz / 2 - 1);

        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy, sz);

        dc.setColor(accentC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy - sz / 3, sz * 2 / 3);

        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy - sz - sz / 3, sz * 2 / 3);

        dc.setColor(accentC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy - sz - sz / 3, sz / 2);

        var dir = (vx >= 0.0) ? 1 : -1;
        dc.setColor(eyeC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - 2 + dir, sy - sz - sz / 3 - 1, 2, 2);
        dc.fillRectangle(sx + 2 + dir, sy - sz - sz / 3 - 1, 2, 2);

        if (fleeing && _tick % 4 < 2) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 2, sy - sz - sz / 3 + 2, 4, 1);
        }

        if (ctype == 0) {
            dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz / 2 - 2, sy - sz / 2, 3, 2);
            dc.fillRectangle(sx + sz / 2, sy - sz / 2, 3, 2);
        } else if (ctype == 1) {
            dc.setColor(0xCC9966, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy - sz - sz / 3 + sz / 2, sz / 2 + 3);
            dc.setColor(accentC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx, sy - sz - sz / 3, sz / 2);
        } else if (ctype == 3) {
            dc.setColor(0x443355, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[sx - sz, sy - sz], [sx - sz / 2, sy - sz * 2], [sx, sy - sz]]);
            dc.fillPolygon([[sx, sy - sz], [sx + sz / 2, sy - sz * 2], [sx + sz, sy - sz]]);
        } else if (ctype == 4) {
            var wagOff = (_tick % 6 < 3) ? 3 : -3;
            dc.setColor(accentC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 2, sy + sz - 1, 4, 4 + wagOff);
        } else if (ctype == 6) {
            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - sz - 3, sy - 1, sz + 3, 3);
            dc.fillRectangle(sx, sy - 1, sz + 3, 3);
        }

        var legOff = (_tick % 4 < 2) ? 1 : -1;
        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(sx - sz / 2, sy + sz - 2, 3, 4 + legOff);
        dc.fillRectangle(sx + sz / 2 - 2, sy + sz - 2, 3, 4 - legOff);
    }

    hidden function drawHitFx(dc, offX, offY) {
        if (_hitShow <= 0) { return; }
        var hx = (_hitX - _aimX).toNumber() + _cx + offX;
        var hy = (_hitY - _aimY).toNumber() + _cy + offY;

        if (_shotMsg.equals("MISS")) {
            dc.setColor(0x886644, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hx, hy, 3);
            dc.setColor(0xAA8866, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hx, hy, 2);
        } else {
            var flashC = (_hitShow % 4 < 2) ? 0xFF4422 : 0xFFAA22;
            dc.setColor(flashC, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 6; i++) {
                var px = hx + (Math.rand().abs() % 16) - 8;
                var py = hy + (Math.rand().abs() % 16) - 8;
                dc.fillRectangle(px, py, 3, 3);
            }
            dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hx, hy, 4);
            dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hx, hy, 2);

            if (_hitShow > 10) {
                dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
                for (var i = 0; i < 4; i++) {
                    var px = hx + (Math.rand().abs() % 20) - 10;
                    var py = hy + (Math.rand().abs() % 20) - 10;
                    dc.fillRectangle(px, py, 2, 2);
                }
            }
        }
    }

    hidden function drawScopeOverlay(dc) {
        var r = _cx;
        if (_cy < r) { r = _cy; }
        r = r - 2;

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        for (var ring = r; ring < r + 18; ring++) {
            dc.drawCircle(_cx, _cy, ring);
        }

        dc.setColor(0x0A0A0A, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r);
        dc.drawCircle(_cx, _cy, r - 1);
        dc.setColor(0x151515, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r - 2);
        dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r - 3);

        dc.setColor(0x0A0A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx - 1, 0, 2, _cy - 8);
        dc.fillRectangle(_cx - 1, _cy + 8, 2, _h - _cy - 8);
        dc.fillRectangle(0, _cy - 1, _cx - 8, 2);
        dc.fillRectangle(_cx + 8, _cy - 1, _w - _cx - 8, 2);

        dc.setColor(0x181818, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_cx, 0, 1, _cy - 8);
        dc.fillRectangle(_cx, _cy + 8, 1, _h - _cy - 8);
        dc.fillRectangle(0, _cy, _cx - 8, 1);
        dc.fillRectangle(_cx + 8, _cy, _w - _cx - 8, 1);

        dc.setColor(0xCC0000, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - 8, _cy, _cx - 3, _cy);
        dc.drawLine(_cx + 3, _cy, _cx + 8, _cy);
        dc.drawLine(_cx, _cy - 8, _cx, _cy - 3);
        dc.drawLine(_cx, _cy + 3, _cx, _cy + 8);

        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 1);

        dc.setColor(0x660000, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i <= 4; i++) {
            var d = r * i * 16 / 100;
            dc.fillRectangle(_cx - 1, _cy - d, 2, 2);
            dc.fillRectangle(_cx - 1, _cy + d - 1, 2, 2);
            dc.fillRectangle(_cx - d, _cy - 1, 2, 2);
            dc.fillRectangle(_cx + d - 1, _cy - 1, 2, 2);
        }

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r * 55 / 100);
        dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r * 30 / 100);

        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, r - 6);
    }

    hidden function drawShotFlash(dc) {
        if (_shotFlash <= 0) { return; }
        var flashA = _shotFlash * 50;
        if (flashA > 0xFF) { flashA = 0xFF; }
        var flashC = (flashA << 16) | (flashA << 8);
        dc.setColor(flashC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, _shotFlash * 8);
    }

    hidden function drawShells(dc) {
        for (var i = 0; i < 4; i++) {
            if (_shellLife[i] <= 0) { continue; }
            dc.setColor(0xCCAA44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_shellX[i], _shellY[i], 3, 5);
            dc.setColor(0xAA8833, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_shellX[i], _shellY[i], 3, 2);
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _maxAmmo; i++) {
            var bx = 6 + i * 7;
            var by = _h - 14;
            if (i < _ammo) {
                dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, 4, 10);
                dc.setColor(0xAA8822, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, 4, 3);
            } else {
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, by, 4, 10);
            }
        }

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 4, 4, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 4, Graphics.FONT_XTINY, _kills + "/" + _killTarget, Graphics.TEXT_JUSTIFY_LEFT);

        var sec = _timeLeft / 20;
        var tC = sec > 10 ? 0xAABBCC : ((_tick % 6 < 3) ? 0xFF4444 : 0xFF8844);
        dc.setColor(tC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h - 16, Graphics.FONT_XTINY, "" + sec + "s", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 4, Graphics.FONT_XTINY, "L" + _level, Graphics.TEXT_JUSTIFY_CENTER);

        if (_hitShow > 0) {
            var msgC = 0xFFFFFF;
            if (_shotMsg.equals("HEADSHOT!")) { msgC = 0xFF4444; }
            else if (_shotMsg.equals("CLEAN!")) { msgC = 0xFFCC44; }
            else if (_shotMsg.equals("HIT!")) { msgC = 0x44FF44; }
            else if (_shotMsg.equals("MISS")) { msgC = 0x888888; }
            dc.setColor(msgC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy + _cy * 50 / 100, Graphics.FONT_SMALL, _shotMsg, Graphics.TEXT_JUSTIFY_CENTER);

            if (_combo >= 2) {
                dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_cx, _cy + _cy * 65 / 100, Graphics.FONT_XTINY, "x" + _combo + " COMBO", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (_windX > 0.3 || _windX < -0.3) {
            var wDir = _windX > 0.0 ? ">>>" : "<<<";
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, 16, Graphics.FONT_XTINY, wDir, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x0A1408, 0x0A1408);
        dc.clear();

        dc.setColor(0x132210, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, _cx * 80 / 100);
        dc.setColor(0x1A3318, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, _cx * 60 / 100);

        drawScopeOverlay(dc);

        var pulse = (_tick % 20 < 10) ? 0xFF4422 : 0xCC2211;
        dc.setColor(0x551100, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 1, _h * 12 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 12 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 26 / 100, Graphics.FONT_MEDIUM, "SNIPER", Graphics.TEXT_JUSTIFY_CENTER);

        drawCreatureSprite(dc, _cx - 20, _cy + 4, (_tick / 40) % 8, 8, 1.0, false);
        drawCreatureSprite(dc, _cx + 20, _cy + 4, ((_tick / 40) + 3) % 8, 7, -1.0, false);

        dc.setColor(0x7799AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 60 / 100, Graphics.FONT_XTINY, "Hunt the creatures!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, _h * 67 / 100, Graphics.FONT_XTINY, "Tilt to aim", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, _h * 74 / 100, Graphics.FONT_XTINY, "Tap to shoot", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestScore > 0) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 83 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 91 / 100, Graphics.FONT_XTINY, "Press to start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawBetween(dc) {
        dc.setColor(0x0A1408, 0x0A1408);
        dc.clear();

        var flash = (_betweenTick % 8 < 4) ? 0x44FF44 : 0x22CC22;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 20 / 100, Graphics.FONT_MEDIUM, "CLEAR!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 38 / 100, Graphics.FONT_SMALL, "SCORE " + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 52 / 100, Graphics.FONT_XTINY, "KILLS " + _kills + "/" + _killTarget, Graphics.TEXT_JUSTIFY_CENTER);

        if (_maxCombo >= 2) {
            dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 60 / 100, Graphics.FONT_XTINY, "MAX COMBO x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 70 / 100, Graphics.FONT_XTINY, "AMMO LEFT " + _ammo, Graphics.TEXT_JUSTIFY_CENTER);

        var msgs = ["Reloading...", "Stalking prey...", "Next zone..."];
        var mi = _level % msgs.size();
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 82 / 100, Graphics.FONT_XTINY, msgs[mi], Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x110000, 0x110000);
        dc.clear();

        var flash = (_tick % 6 < 3) ? 0xFF2222 : 0xCC0000;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 15 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 32 / 100, Graphics.FONT_SMALL, "SCORE " + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 46 / 100, Graphics.FONT_XTINY, "KILLS " + _kills, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, _h * 54 / 100, Graphics.FONT_XTINY, "LEVEL " + _level, Graphics.TEXT_JUSTIFY_CENTER);

        if (_maxCombo >= 2) {
            dc.setColor(0xFF8822, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 62 / 100, Graphics.FONT_XTINY, "BEST COMBO x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 72 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 86 / 100, Graphics.FONT_XTINY, "Press to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
