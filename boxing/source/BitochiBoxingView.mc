using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum {
    GS_MENU,
    GS_INTRO,
    GS_FIGHT,
    GS_KO,
    GS_WIN,
    GS_LOSE
}

enum {
    PS_IDLE,
    PS_PUNCH_JAB,
    PS_PUNCH_HOOK,
    PS_PUNCH_UPPER,
    PS_DODGE_L,
    PS_DODGE_R,
    PS_BLOCK,
    PS_HIT_STUN
}

enum {
    ES_IDLE,
    ES_WINDUP,
    ES_PUNCH,
    ES_STUNNED,
    ES_DODGE
}

class BitochiBoxingView extends WatchUi.View {

    var accelX;
    var accelY;
    var accelZ;
    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _timer;
    hidden var _tick;

    hidden var _playerHp;
    hidden var _playerMaxHp;
    hidden var _playerState;
    hidden var _playerStateTick;
    hidden var _punchCooldown;
    hidden var _comboCount;
    hidden var _comboTimer;
    hidden var _totalHits;
    hidden var _perfectHits;

    hidden var _enemyHp;
    hidden var _enemyMaxHp;
    hidden var _enemyState;
    hidden var _enemyStateTick;
    hidden var _enemyAttackTimer;
    hidden var _enemyNextAttack;
    hidden var _enemySpeed;
    hidden var _enemyDmg;
    hidden var _enemyFace;

    hidden var _round;
    hidden var _wins;
    hidden var _bestRound;
    hidden var _introTick;
    hidden var _koTick;

    hidden var _shakeX;
    hidden var _shakeY;
    hidden var _shakeLeft;
    hidden var _flashTick;
    hidden var _hitFlash;

    hidden var _prevAccelMag;
    hidden var _accelSmooth;

    hidden var _bloodX;
    hidden var _bloodY;
    hidden var _bloodVx;
    hidden var _bloodVy;
    hidden var _bloodLife;
    hidden var _bloodCount;

    hidden var _sweatX;
    hidden var _sweatY;
    hidden var _sweatVx;
    hidden var _sweatVy;
    hidden var _sweatLife;

    hidden var _starX;
    hidden var _starY;
    hidden var _starLife;

    hidden var _enemyBruise;
    hidden var _enemyCuts;
    hidden var _enemySwellL;
    hidden var _enemySwellR;
    hidden var _enemyNoseBleed;

    hidden var _playerBruise;
    hidden var _playerSwellL;
    hidden var _playerSwellR;

    hidden var _crowdPhase;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;

        accelX = 0;
        accelY = 0;
        accelZ = 0;
        _tick = 0;
        _round = 1;
        _wins = 0;
        _bestRound = 0;
        _prevAccelMag = 0;
        _accelSmooth = 0;
        _crowdPhase = 0;

        _bloodX = new [30];
        _bloodY = new [30];
        _bloodVx = new [30];
        _bloodVy = new [30];
        _bloodLife = new [30];
        _bloodCount = 0;
        for (var i = 0; i < 30; i++) {
            _bloodX[i] = 0; _bloodY[i] = 0;
            _bloodVx[i] = 0; _bloodVy[i] = 0;
            _bloodLife[i] = 0;
        }

        _sweatX = new [6];
        _sweatY = new [6];
        _sweatVx = new [6];
        _sweatVy = new [6];
        _sweatLife = new [6];
        for (var i = 0; i < 6; i++) {
            _sweatX[i] = 0; _sweatY[i] = 0;
            _sweatVx[i] = 0; _sweatVy[i] = 0;
            _sweatLife[i] = 0;
        }

        _starX = new [5];
        _starY = new [5];
        _starLife = new [5];
        for (var i = 0; i < 5; i++) {
            _starX[i] = 0; _starY[i] = 0; _starLife[i] = 0;
        }

        _playerHp = 100;
        _playerMaxHp = 100;
        _playerState = PS_IDLE;
        _playerStateTick = 0;
        _punchCooldown = 0;
        _comboCount = 0;
        _comboTimer = 0;
        _totalHits = 0;
        _perfectHits = 0;
        _playerBruise = 0;
        _playerSwellL = 0;
        _playerSwellR = 0;

        _enemyHp = 80;
        _enemyMaxHp = 80;
        _enemyState = ES_IDLE;
        _enemyStateTick = 0;
        _enemyAttackTimer = 0;
        _enemyNextAttack = 45;
        _enemySpeed = 1.0;
        _enemyDmg = 8;
        _enemyFace = 0;
        _enemyBruise = 0;
        _enemyCuts = 0;
        _enemySwellL = 0;
        _enemySwellR = 0;
        _enemyNoseBleed = 0;

        _shakeX = 0; _shakeY = 0; _shakeLeft = 0;
        _flashTick = 0;
        _hitFlash = 0;
        _introTick = 0;
        _koTick = 0;

        gameState = GS_MENU;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 33, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    hidden function initFight() {
        _enemyMaxHp = 60 + _round * 20;
        if (_enemyMaxHp > 200) { _enemyMaxHp = 200; }
        _enemyHp = _enemyMaxHp;
        _enemyDmg = 6 + _round * 2;
        if (_enemyDmg > 25) { _enemyDmg = 25; }
        _enemySpeed = 1.0 + (_round - 1) * 0.15;
        if (_enemySpeed > 2.5) { _enemySpeed = 2.5; }
        _enemyFace = (_round - 1) % 5;
        _enemyState = ES_IDLE;
        _enemyStateTick = 0;
        _enemyAttackTimer = 0;
        _enemyNextAttack = (40.0 / _enemySpeed).toNumber() + 20;
        _enemyBruise = 0;
        _enemyCuts = 0;
        _enemySwellL = 0;
        _enemySwellR = 0;
        _enemyNoseBleed = 0;

        _playerHp = _playerMaxHp;
        _playerState = PS_IDLE;
        _playerStateTick = 0;
        _punchCooldown = 0;
        _comboCount = 0;
        _comboTimer = 0;
        _totalHits = 0;
        _perfectHits = 0;
        _playerBruise = 0;
        _playerSwellL = 0;
        _playerSwellR = 0;

        _bloodCount = 0;
        for (var i = 0; i < 30; i++) { _bloodLife[i] = 0; }
        for (var i = 0; i < 6; i++) { _sweatLife[i] = 0; }
        for (var i = 0; i < 5; i++) { _starLife[i] = 0; }
    }

    function doAction() {
        if (gameState == GS_MENU) {
            _round = 1;
            _wins = 0;
            initFight();
            gameState = GS_INTRO;
            _introTick = 0;
        } else if (gameState == GS_FIGHT) {
            doPlayerPunch(PS_PUNCH_JAB);
        } else if (gameState == GS_WIN) {
            _round++;
            initFight();
            gameState = GS_INTRO;
            _introTick = 0;
        } else if (gameState == GS_LOSE) {
            gameState = GS_MENU;
        }
    }

    function onTick() as Void {
        _tick++;
        _crowdPhase = (_crowdPhase + 1) % 120;

        if (_shakeLeft > 0) {
            _shakeX = (Math.rand().abs() % 9) - 4;
            _shakeY = (Math.rand().abs() % 7) - 3;
            _shakeLeft--;
        } else { _shakeX = 0; _shakeY = 0; }
        if (_flashTick > 0) { _flashTick--; }
        if (_hitFlash > 0) { _hitFlash--; }

        if (gameState == GS_INTRO) {
            _introTick++;
            if (_introTick >= 60) {
                gameState = GS_FIGHT;
            }
        } else if (gameState == GS_FIGHT) {
            updateAccel();
            updatePlayer();
            updateEnemy();
            updateBlood();
            updateSweat();
            updateStars();
            if (_comboTimer > 0) { _comboTimer--; }
            if (_comboTimer == 0) { _comboCount = 0; }
        } else if (gameState == GS_KO) {
            _koTick++;
            updateBlood();
            if (_koTick >= 75) {
                if (_enemyHp <= 0) {
                    _wins++;
                    if (_round > _bestRound) { _bestRound = _round; }
                    gameState = GS_WIN;
                } else {
                    gameState = GS_LOSE;
                }
            }
        }

        WatchUi.requestUpdate();
    }

    hidden function updateAccel() {
        var ax = accelX;
        var ay = accelY;
        var az = accelZ;
        if (ax == null) { ax = 0; }
        if (ay == null) { ay = 0; }
        if (az == null) { az = 0; }
        var mag = Math.sqrt(ax * ax + ay * ay + az * az).toNumber();
        var delta = (mag - _accelSmooth);
        if (delta < 0) { delta = -delta; }
        _accelSmooth = _accelSmooth + (mag - _accelSmooth) * 0.3;

        if (_punchCooldown > 0) { _punchCooldown--; }

        if (_playerState == PS_IDLE || _playerState == PS_BLOCK) {
            var tiltX = ax;
            if (tiltX > 350) {
                _playerState = PS_DODGE_L;
                _playerStateTick = 0;
            } else if (tiltX < -350) {
                _playerState = PS_DODGE_R;
                _playerStateTick = 0;
            } else if (delta > 600 && _punchCooldown <= 0) {
                var pType = PS_PUNCH_JAB;
                if (delta > 1200) {
                    pType = PS_PUNCH_UPPER;
                } else if (delta > 900) {
                    pType = PS_PUNCH_HOOK;
                }
                doPlayerPunch(pType);
            } else if (tiltX > -100 && tiltX < 100 && delta < 200) {
                if (_playerState != PS_BLOCK) {
                    _playerState = PS_BLOCK;
                    _playerStateTick = 0;
                }
            }
        }

        _prevAccelMag = mag;
    }

    hidden function doPlayerPunch(pType) {
        if (_punchCooldown > 0) { return; }
        if (_playerState == PS_HIT_STUN) { return; }
        if (_playerState == PS_PUNCH_JAB || _playerState == PS_PUNCH_HOOK || _playerState == PS_PUNCH_UPPER) { return; }

        _playerState = pType;
        _playerStateTick = 0;
        _punchCooldown = 10;
        doVibe(30, 50);

        if (_enemyState == ES_DODGE) {
            spawnSweat(_w / 2, _h * 35 / 100, 3);
            return;
        }

        var dmg = 8;
        var isCounter = false;
        if (pType == PS_PUNCH_HOOK) { dmg = 12; }
        else if (pType == PS_PUNCH_UPPER) { dmg = 18; }

        if (_enemyState == ES_WINDUP || _enemyState == ES_PUNCH) {
            dmg = (dmg * 1.8).toNumber();
            isCounter = true;
            _enemyState = ES_STUNNED;
            _enemyStateTick = 0;
            _flashTick = 4;
        }

        _comboCount++;
        _comboTimer = 30;
        if (_comboCount > 2) {
            dmg = dmg + _comboCount * 2;
        }

        _enemyHp -= dmg;
        _totalHits++;
        if (isCounter) { _perfectHits++; }
        _shakeLeft = 4;

        _enemyBruise += 3;
        if (_enemyBruise > 30) { _enemyBruise = 30; }
        if (pType == PS_PUNCH_HOOK) {
            var side = Math.rand().abs() % 2;
            if (side == 0) { _enemySwellL += 4; if (_enemySwellL > 12) { _enemySwellL = 12; } }
            else { _enemySwellR += 4; if (_enemySwellR > 12) { _enemySwellR = 12; } }
        }
        if (pType == PS_PUNCH_UPPER) {
            _enemyNoseBleed += 5;
            if (_enemyNoseBleed > 20) { _enemyNoseBleed = 20; }
        }
        if (dmg > 12) {
            _enemyCuts++;
            if (_enemyCuts > 5) { _enemyCuts = 5; }
        }

        var bx = _w / 2 + (Math.rand().abs() % 20) - 10;
        var by = _h * 32 / 100 + (Math.rand().abs() % 16) - 8;
        spawnBlood(bx, by, dmg > 14 ? 8 : 4);

        if (_enemyHp <= 0) {
            _enemyHp = 0;
            _enemyState = ES_STUNNED;
            _enemyStateTick = 0;
            gameState = GS_KO;
            _koTick = 0;
            _shakeLeft = 12;
            doVibe(80, 300);
            spawnBlood(_w / 2, _h * 30 / 100, 15);
            spawnStars(_w / 2, _h * 25 / 100);
        }
    }

    hidden function updatePlayer() {
        _playerStateTick++;

        if (_playerState == PS_PUNCH_JAB || _playerState == PS_PUNCH_HOOK || _playerState == PS_PUNCH_UPPER) {
            if (_playerStateTick >= 8) {
                _playerState = PS_IDLE;
                _playerStateTick = 0;
            }
        } else if (_playerState == PS_DODGE_L || _playerState == PS_DODGE_R) {
            if (_playerStateTick >= 12) {
                _playerState = PS_IDLE;
                _playerStateTick = 0;
            }
        } else if (_playerState == PS_HIT_STUN) {
            if (_playerStateTick >= 15) {
                _playerState = PS_IDLE;
                _playerStateTick = 0;
            }
        } else if (_playerState == PS_BLOCK) {
            var ax = accelX;
            if (ax == null) { ax = 0; }
            if (ax > 150 || ax < -150) {
                _playerState = PS_IDLE;
                _playerStateTick = 0;
            }
        }
    }

    hidden function updateEnemy() {
        _enemyStateTick++;

        if (_enemyState == ES_IDLE) {
            _enemyAttackTimer++;
            if (_enemyAttackTimer >= _enemyNextAttack) {
                _enemyState = ES_WINDUP;
                _enemyStateTick = 0;
                _enemyAttackTimer = 0;
                var baseDelay = (35.0 / _enemySpeed).toNumber();
                if (baseDelay < 15) { baseDelay = 15; }
                _enemyNextAttack = baseDelay + Math.rand().abs() % 20;
            }
            if (Math.rand().abs() % 200 < 2 * _enemySpeed.toNumber()) {
                _enemyState = ES_DODGE;
                _enemyStateTick = 0;
            }
        } else if (_enemyState == ES_WINDUP) {
            var windupTime = (12.0 / _enemySpeed).toNumber();
            if (windupTime < 5) { windupTime = 5; }
            if (_enemyStateTick >= windupTime) {
                _enemyState = ES_PUNCH;
                _enemyStateTick = 0;
            }
        } else if (_enemyState == ES_PUNCH) {
            if (_enemyStateTick == 3) {
                enemyHitPlayer();
            }
            if (_enemyStateTick >= 10) {
                _enemyState = ES_IDLE;
                _enemyStateTick = 0;
            }
        } else if (_enemyState == ES_STUNNED) {
            if (_enemyStateTick >= 20) {
                _enemyState = ES_IDLE;
                _enemyStateTick = 0;
            }
        } else if (_enemyState == ES_DODGE) {
            if (_enemyStateTick >= 15) {
                _enemyState = ES_IDLE;
                _enemyStateTick = 0;
            }
        }
    }

    hidden function enemyHitPlayer() {
        if (_playerState == PS_DODGE_L || _playerState == PS_DODGE_R) {
            spawnSweat(_w / 2, _h * 60 / 100, 2);
            return;
        }

        var dmg = _enemyDmg;
        if (_playerState == PS_BLOCK) {
            dmg = (dmg * 0.3).toNumber();
            if (dmg < 1) { dmg = 1; }
            doVibe(20, 40);
            _shakeLeft = 2;
        } else {
            _playerState = PS_HIT_STUN;
            _playerStateTick = 0;
            doVibe(60, 150);
            _shakeLeft = 6;
            _hitFlash = 4;
            _playerBruise += 2;
            if (_playerBruise > 20) { _playerBruise = 20; }
            if (Math.rand().abs() % 3 == 0) {
                var side = Math.rand().abs() % 2;
                if (side == 0) { _playerSwellL += 3; if (_playerSwellL > 10) { _playerSwellL = 10; } }
                else { _playerSwellR += 3; if (_playerSwellR > 10) { _playerSwellR = 10; } }
            }
            var bx = _w / 2 + (Math.rand().abs() % 16) - 8;
            var by = _h * 62 / 100;
            spawnBlood(bx, by, 3);
        }

        _playerHp -= dmg;
        _comboCount = 0;
        _comboTimer = 0;

        if (_playerHp <= 0) {
            _playerHp = 0;
            gameState = GS_KO;
            _koTick = 0;
            _shakeLeft = 12;
            doVibe(100, 400);
            spawnBlood(_w / 2, _h * 65 / 100, 10);
            spawnStars(_w / 2, _h * 55 / 100);
        }
    }

    hidden function spawnBlood(bx, by, count) {
        for (var i = 0; i < count; i++) {
            var slot = -1;
            for (var j = 0; j < 30; j++) {
                if (_bloodLife[j] <= 0) { slot = j; break; }
            }
            if (slot < 0) { slot = _bloodCount % 30; }
            _bloodX[slot] = bx + (Math.rand().abs() % 10) - 5;
            _bloodY[slot] = by + (Math.rand().abs() % 6) - 3;
            _bloodVx[slot] = (Math.rand().abs() % 7) - 3;
            _bloodVy[slot] = -(Math.rand().abs() % 5) - 2;
            _bloodLife[slot] = 20 + Math.rand().abs() % 15;
            _bloodCount++;
        }
    }

    hidden function spawnSweat(sx, sy, count) {
        for (var i = 0; i < count && i < 6; i++) {
            _sweatX[i] = sx + (Math.rand().abs() % 20) - 10;
            _sweatY[i] = sy;
            _sweatVx[i] = (Math.rand().abs() % 5) - 2;
            _sweatVy[i] = -(Math.rand().abs() % 4) - 1;
            _sweatLife[i] = 12 + Math.rand().abs() % 8;
        }
    }

    hidden function spawnStars(sx, sy) {
        for (var i = 0; i < 5; i++) {
            var a = i * 72;
            var r = 12 + Math.rand().abs() % 8;
            _starX[i] = sx + (r * Math.cos(a * 0.01745)).toNumber();
            _starY[i] = sy + (r * Math.sin(a * 0.01745)).toNumber();
            _starLife[i] = 25 + Math.rand().abs() % 10;
        }
    }

    hidden function updateBlood() {
        for (var i = 0; i < 30; i++) {
            if (_bloodLife[i] <= 0) { continue; }
            _bloodX[i] += _bloodVx[i];
            _bloodY[i] += _bloodVy[i];
            _bloodVy[i] += 1;
            _bloodLife[i]--;
        }
    }

    hidden function updateSweat() {
        for (var i = 0; i < 6; i++) {
            if (_sweatLife[i] <= 0) { continue; }
            _sweatX[i] += _sweatVx[i];
            _sweatY[i] += _sweatVy[i];
            _sweatVy[i] += 1;
            _sweatLife[i]--;
        }
    }

    hidden function updateStars() {
        for (var i = 0; i < 5; i++) {
            if (_starLife[i] <= 0) { continue; }
            _starLife[i]--;
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

        if (gameState == GS_MENU) { drawMenu(dc); return; }
        if (gameState == GS_INTRO) { drawIntro(dc); return; }

        var ox = _shakeX;
        var oy = _shakeY;

        drawArena(dc, ox, oy);
        drawRopes(dc, ox, oy);
        drawCrowd(dc, ox, oy);
        drawEnemy(dc, ox, oy);
        drawPlayer(dc, ox, oy);
        drawBloodParticles(dc, ox, oy);
        drawSweatParticles(dc, ox, oy);
        drawStarParticles(dc, ox, oy);
        drawHUD(dc);

        if (_hitFlash > 0) {
            dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawRectangle(2, 2, _w - 4, _h - 4);
            dc.setPenWidth(1);
        }

        if (_flashTick > 0 && _flashTick % 2 == 0) {
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRectangle(4, 4, _w - 8, _h - 8);
            dc.setPenWidth(1);
        }

        if (gameState == GS_KO) { drawKO(dc); }
        else if (gameState == GS_WIN) { drawWin(dc); }
        else if (gameState == GS_LOSE) { drawLose(dc); }

        if (_comboCount >= 3 && _comboTimer > 0 && gameState == GS_FIGHT) {
            dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_SMALL,
                "" + _comboCount + "x COMBO!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x0A0A14, 0x0A0A14);
        dc.clear();

        dc.setColor(0x1A1A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 70 / 100, _w, _h * 30 / 100);

        dc.setColor(0x220808, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _w; i += 4) {
            var rh = 3 + (i * 7 + 13) % 5;
            dc.fillRectangle(i, _h * 70 / 100 - rh, 3, rh);
        }

        drawMenuBoxer(dc, _w * 25 / 100, _h * 48 / 100, 0xDD4444, true);
        drawMenuBoxer(dc, _w * 75 / 100, _h * 48 / 100, 0x4444DD, false);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 38 / 100, _h * 38 / 100, _w * 24 / 100, 2);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 40 / 100, Graphics.FONT_XTINY, "VS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 38 / 100, _h * 50 / 100, _w * 24 / 100, 2);

        var pulse = (_tick % 20 < 10) ? 0xFF4444 : 0xDD2222;
        dc.setColor(0x110000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, _h * 8 / 100 + 1, Graphics.FONT_SMALL, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 8 / 100, Graphics.FONT_SMALL, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_SMALL, "BOXING", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 60 / 100, Graphics.FONT_XTINY, "Shake to punch!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 67 / 100, Graphics.FONT_XTINY, "Tilt to dodge", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestRound > 0) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 76 / 100, Graphics.FONT_XTINY, "Best: Round " + _bestRound, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 30 < 15) ? 0x44FF44 : 0x22AA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 86 / 100, Graphics.FONT_XTINY, "Tap to fight", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawMenuBoxer(dc, cx, cy, col, leftFacing) {
        var headR = _w * 6 / 100;
        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - headR * 2, headR);

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - headR, cy, headR * 2, headR * 3);

        var dir = leftFacing ? 1 : -1;
        dc.setColor(col - 0x222200, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + dir * headR * 2, cy - headR, headR * 3 / 4);

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        var ex = leftFacing ? cx + 2 : cx - 2;
        dc.fillCircle(ex, cy - headR * 2 - 1, 2);
    }

    hidden function drawIntro(dc) {
        dc.setColor(0x0A0A14, 0x0A0A14);
        dc.clear();

        dc.setColor(0x332211, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 55 / 100, _w, _h * 45 / 100);
        dc.setColor(0x443322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 55 / 100, _w, 3);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 12 / 100, Graphics.FONT_SMALL, "ROUND " + _round, Graphics.TEXT_JUSTIFY_CENTER);

        var enemyNames = ["ROOKIE JOE", "IRON MIKE", "MAD BULL", "SHADOW", "CHAMPION"];
        var idx = _enemyFace;
        if (idx > 4) { idx = 4; }
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_XTINY, enemyNames[idx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 38 / 100, Graphics.FONT_XTINY, "HP: " + _enemyMaxHp, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 45 / 100, Graphics.FONT_XTINY, "DMG: " + _enemyDmg, Graphics.TEXT_JUSTIFY_CENTER);

        if (_introTick > 20) {
            var flash = (_introTick % 6 < 3);
            dc.setColor(flash ? 0xFF4444 : 0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 62 / 100, Graphics.FONT_MEDIUM, "FIGHT!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var barY = _h * 78 / 100;
        var barW = _w * 60 / 100;
        var barX = (_w - barW) / 2;
        var fill = (_introTick * barW / 60);
        if (fill > barW) { fill = barW; }
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, 6);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, fill, 6);
    }

    hidden function drawArena(dc, ox, oy) {
        var skyTop = 0x0A0A18;
        var skyBot = 0x151525;
        dc.setColor(skyTop, skyTop);
        dc.clear();

        dc.setColor(skyBot, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 25 / 100 + oy, _w, _h * 75 / 100);

        var floorY = _h * 75 / 100 + oy;
        dc.setColor(0x334488, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, floorY, _w, _h * 25 / 100);
        dc.setColor(0x2A3A6A, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _w; i += 8) {
            dc.fillRectangle(i + ox, floorY, 4, _h - floorY);
        }
        dc.setColor(0x445599, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, floorY, _w, 2);

        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 5 / 100 + ox, floorY + 2, _w * 90 / 100, 4);
    }

    hidden function drawRopes(dc, ox, oy) {
        var leftX = _w * 8 / 100 + ox;
        var rightX = _w * 92 / 100 + ox;
        var topY = _h * 20 / 100 + oy;
        var midY = _h * 40 / 100 + oy;
        var botY = _h * 60 / 100 + oy;

        dc.setColor(0x554433, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(leftX - 2, topY, 4, botY - topY + 4);
        dc.fillRectangle(rightX - 2, topY, 4, botY - topY + 4);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(leftX, topY, rightX, topY);
        dc.drawLine(leftX, topY + 1, rightX, topY + 1);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(leftX, midY, rightX, midY);
        dc.drawLine(leftX, midY + 1, rightX, midY + 1);
        dc.setColor(0x4444FF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(leftX, botY, rightX, botY);
        dc.drawLine(leftX, botY + 1, rightX, botY + 1);
    }

    hidden function drawCrowd(dc, ox, oy) {
        var crowdY = _h * 10 / 100 + oy;
        for (var i = 0; i < 12; i++) {
            var cx = (i * _w / 12) + _w / 24 + ox;
            var bounce = ((_crowdPhase + i * 10) % 20 < 10) ? -2 : 0;
            var headC = [0xDDAA77, 0xCC9966, 0xBB8855, 0xAA7744, 0xDD9988, 0xCCAA88];
            var ci = (i * 3 + 7) % 6;
            dc.setColor(headC[ci], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, crowdY + bounce, 4);
            var shirtC = [0xDD3333, 0x3333DD, 0x33DD33, 0xDDDD33, 0xDD33DD, 0x33DDDD];
            var si = (i * 5 + 2) % 6;
            dc.setColor(shirtC[si], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 3, crowdY + 4 + bounce, 6, 6);
        }
    }

    hidden function drawEnemy(dc, ox, oy) {
        var cx = _w / 2 + ox;
        var baseY = _h * 32 / 100 + oy;

        var dodgeOff = 0;
        if (_enemyState == ES_DODGE) {
            dodgeOff = (_enemyStateTick < 8) ? -15 : 15;
        }
        cx += dodgeOff;

        var headR = _w * 8 / 100;
        var bodyW = headR * 2;
        var bodyH = (headR * 2.5).toNumber();
        var headY = baseY - bodyH / 2 - headR;

        var bobOff = 0;
        if (_enemyState == ES_IDLE) {
            bobOff = (_tick % 16 < 8) ? -1 : 1;
        }
        headY += bobOff;

        if (_enemyState == ES_STUNNED) {
            var sway = (_enemyStateTick % 6 < 3) ? -3 : 3;
            cx += sway;
        }

        var skinBase = 0xDDAA77;
        var skinBruised = skinBase;
        if (_enemyBruise > 0) {
            var br = (0xDD - _enemyBruise * 3);
            var bg = (0xAA - _enemyBruise * 4);
            if (br < 0x88) { br = 0x88; }
            if (bg < 0x55) { bg = 0x55; }
            skinBruised = (br << 16) | (bg << 8) | 0x77;
        }

        dc.setColor(skinBruised, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, headY, headR);

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - headR, headY - headR - 2, headR * 2, headR / 2);

        var eyeY = headY - 2;
        var lEyeX = cx - headR / 3;
        var rEyeX = cx + headR / 3;

        if (_enemyState == ES_STUNNED) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(lEyeX - 2, eyeY - 2, lEyeX + 2, eyeY + 2);
            dc.drawLine(lEyeX + 2, eyeY - 2, lEyeX - 2, eyeY + 2);
            dc.drawLine(rEyeX - 2, eyeY - 2, rEyeX + 2, eyeY + 2);
            dc.drawLine(rEyeX + 2, eyeY - 2, rEyeX - 2, eyeY + 2);
        } else {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lEyeX, eyeY, 3);
            dc.fillCircle(rEyeX, eyeY, 3);
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lEyeX, eyeY, 1);
            dc.fillCircle(rEyeX, eyeY, 1);

            if (_enemySwellL > 3) {
                dc.setColor(0x884466, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(lEyeX - 1, eyeY + 2, _enemySwellL / 2);
            }
            if (_enemySwellR > 3) {
                dc.setColor(0x884466, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(rEyeX + 1, eyeY + 2, _enemySwellR / 2);
            }
        }

        if (_enemyState == ES_STUNNED || _enemyHp < _enemyMaxHp / 3) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - headR / 4, headY + headR / 2, cx + headR / 4, headY + headR / 2 + 2);
        } else if (_enemyState == ES_WINDUP) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 3, headY + headR / 3, 6, 2);
        } else {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 2, headY + headR / 3, 4, 2);
        }

        if (_enemyNoseBleed > 0) {
            dc.setColor(0xCC0000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 1, headY + headR / 4, 2, _enemyNoseBleed / 2 + 2);
            if (_enemyNoseBleed > 8) {
                dc.fillCircle(cx, headY + headR / 3 + _enemyNoseBleed / 2, 2);
            }
        }

        for (var c = 0; c < _enemyCuts && c < 5; c++) {
            var cutX = cx - headR / 2 + (c * headR / 3);
            var cutY = headY - headR / 3 + (c % 2 == 0 ? 2 : -2);
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cutX, cutY, cutX + 3, cutY + 2);
        }

        var tColor = getEnemyTrunkColor();
        dc.setColor(tColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bodyW / 2, baseY - bodyH / 2, bodyW, bodyH);
        dc.setColor(skinBruised, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bodyW / 2 + 1, baseY - bodyH / 2 + 1, bodyW - 2, bodyH / 4);

        var gloveC = getEnemyGloveColor();
        if (_enemyState == ES_WINDUP) {
            dc.setColor(gloveC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - bodyW / 2 - 5, baseY - bodyH / 4 - 5, headR * 3 / 4);
            dc.fillCircle(cx + bodyW / 2 + 5, baseY - bodyH / 4 - 5, headR * 3 / 4);
        } else if (_enemyState == ES_PUNCH) {
            var punchExt = _enemyStateTick < 5 ? _enemyStateTick * 4 : 20 - (_enemyStateTick - 5) * 4;
            var pSide = (_enemyAttackTimer + _tick) % 2 == 0 ? -1 : 1;
            dc.setColor(gloveC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + pSide * bodyW / 4, baseY + bodyH / 2 + punchExt, headR);
            dc.fillCircle(cx - pSide * bodyW / 2 - 4, baseY - bodyH / 4, headR * 3 / 4);
        } else {
            dc.setColor(gloveC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - bodyW / 2 - 4, baseY - 2 + bobOff, headR * 3 / 4);
            dc.fillCircle(cx + bodyW / 2 + 4, baseY - 2 + bobOff, headR * 3 / 4);
        }

        dc.setColor(skinBruised, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 2, headY + headR, 4, 4);
    }

    hidden function getEnemyTrunkColor() {
        var colors = [0x3344AA, 0x883322, 0x228833, 0x555555, 0xAA2244];
        var idx = _enemyFace;
        if (idx > 4) { idx = 4; }
        return colors[idx];
    }

    hidden function getEnemyGloveColor() {
        var colors = [0xCC3333, 0x3333CC, 0xCC8833, 0x33CC33, 0xCC33CC];
        var idx = _enemyFace;
        if (idx > 4) { idx = 4; }
        return colors[idx];
    }

    hidden function drawPlayer(dc, ox, oy) {
        var cx = _w / 2 + ox;
        var baseY = _h * 68 / 100 + oy;

        var dodgeOff = 0;
        if (_playerState == PS_DODGE_L) { dodgeOff = -_w * 12 / 100; }
        else if (_playerState == PS_DODGE_R) { dodgeOff = _w * 12 / 100; }
        cx += dodgeOff;

        var headR = _w * 7 / 100;
        var bodyW = headR * 2;
        var bodyH = (headR * 2.0).toNumber();

        var hitOff = 0;
        if (_playerState == PS_HIT_STUN) {
            hitOff = (_playerStateTick % 4 < 2) ? -3 : 3;
        }
        cx += hitOff;

        var skinBase = 0xDDAA77;
        if (_playerBruise > 0) {
            var pr = 0xDD - _playerBruise * 2;
            var pg = 0xAA - _playerBruise * 3;
            if (pr < 0x99) { pr = 0x99; }
            if (pg < 0x66) { pg = 0x66; }
            skinBase = (pr << 16) | (pg << 8) | 0x77;
        }

        dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bodyW / 2, baseY, bodyW, bodyH);
        dc.setColor(skinBase, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bodyW / 2 + 2, baseY + 1, bodyW - 4, bodyH / 5);

        dc.setColor(skinBase, Graphics.COLOR_TRANSPARENT);
        var headY = baseY - headR - 2;
        dc.fillCircle(cx, headY, headR);

        dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - headR + 1, headY - headR, headR * 2 - 2, headR / 2 + 2);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - headR / 4, headY - 1, 2);
        dc.fillCircle(cx + headR / 4, headY - 1, 2);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - headR / 4, headY - 1, 1);
        dc.fillCircle(cx + headR / 4, headY - 1, 1);

        if (_playerSwellL > 2) {
            dc.setColor(0x774455, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - headR / 3 - 1, headY + 1, _playerSwellL / 2);
        }
        if (_playerSwellR > 2) {
            dc.setColor(0x774455, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + headR / 3 + 1, headY + 1, _playerSwellR / 2);
        }

        if (_playerState == PS_HIT_STUN) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - 3, headY + headR / 2, cx + 3, headY + headR / 2 + 1);
        }

        dc.setColor(skinBase, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 2, headY + headR, 4, 3);

        var gloveR = (headR * 0.9).toNumber();
        if (_playerState == PS_PUNCH_JAB) {
            var ext = _playerStateTick < 4 ? _playerStateTick * 6 : 24 - (_playerStateTick - 4) * 6;
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, baseY - ext - headR, gloveR);
            dc.fillCircle(cx + bodyW / 2 + 4, baseY + 2, gloveR - 2);
        } else if (_playerState == PS_PUNCH_HOOK) {
            var ext = _playerStateTick < 4 ? _playerStateTick * 5 : 20 - (_playerStateTick - 4) * 5;
            var hookX = (_playerStateTick < 4) ? cx + ext : cx + 20 - ext;
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hookX, baseY - headR * 2 - ext / 2, gloveR);
            dc.fillCircle(cx - bodyW / 2 - 4, baseY + 2, gloveR - 2);
        } else if (_playerState == PS_PUNCH_UPPER) {
            var ext = _playerStateTick < 4 ? _playerStateTick * 8 : 32 - (_playerStateTick - 4) * 8;
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, baseY - ext - headR * 2, gloveR + 1);
            dc.fillCircle(cx + bodyW / 2 + 3, baseY + 4, gloveR - 2);
        } else if (_playerState == PS_BLOCK) {
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - bodyW / 3, headY + headR / 2, gloveR);
            dc.fillCircle(cx + bodyW / 3, headY + headR / 2, gloveR);
        } else {
            var bob = (_tick % 12 < 6) ? -2 : 2;
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - bodyW / 2 - 4, baseY - 4 + bob, gloveR);
            dc.fillCircle(cx + bodyW / 2 + 4, baseY - 4 - bob, gloveR);
        }
    }

    hidden function drawBloodParticles(dc, ox, oy) {
        for (var i = 0; i < 30; i++) {
            if (_bloodLife[i] <= 0) { continue; }
            var sz = 1;
            if (_bloodLife[i] > 15) { sz = 3; }
            else if (_bloodLife[i] > 8) { sz = 2; }
            var red = 0xAA0000 + (_bloodLife[i] * 0x050000);
            if (red > 0xFF0000) { red = 0xFF0000; }
            dc.setColor(red, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_bloodX[i] + ox, _bloodY[i] + oy, sz);
            if (sz > 1 && _bloodLife[i] < 10) {
                dc.setColor(0x660000, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_bloodX[i] + ox, _bloodY[i] + oy + sz, 1);
            }
        }
    }

    hidden function drawSweatParticles(dc, ox, oy) {
        for (var i = 0; i < 6; i++) {
            if (_sweatLife[i] <= 0) { continue; }
            dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_sweatX[i] + ox, _sweatY[i] + oy, 2);
            if (_sweatLife[i] > 5) {
                dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_sweatX[i] + ox - 1, _sweatY[i] + oy - 1, 1);
            }
        }
    }

    hidden function drawStarParticles(dc, ox, oy) {
        for (var i = 0; i < 5; i++) {
            if (_starLife[i] <= 0) { continue; }
            var bright = (_starLife[i] % 4 < 2) ? 0xFFFF44 : 0xFFDD00;
            dc.setColor(bright, Graphics.COLOR_TRANSPARENT);
            var sx = _starX[i] + ox;
            var sy = _starY[i] + oy;
            dc.fillRectangle(sx - 1, sy - 3, 2, 6);
            dc.fillRectangle(sx - 3, sy - 1, 6, 2);
        }
    }

    hidden function drawHUD(dc) {
        var barW = _w * 35 / 100;
        var barH = 8;
        var barY = _h * 3 / 100;

        var pFill = (_playerHp.toFloat() / _playerMaxHp * barW).toNumber();
        if (pFill < 0) { pFill = 0; }
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 5 / 100, barY, barW, barH);
        var pCol = 0x44CC44;
        if (_playerHp < _playerMaxHp / 4) { pCol = 0xFF2222; }
        else if (_playerHp < _playerMaxHp / 2) { pCol = 0xFFAA22; }
        dc.setColor(pCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 5 / 100, barY, pFill, barH);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_w * 5 / 100, barY, barW, barH);

        var eFill = (_enemyHp.toFloat() / _enemyMaxHp * barW).toNumber();
        if (eFill < 0) { eFill = 0; }
        var eBarX = _w * 95 / 100 - barW;
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(eBarX, barY, barW, barH);
        var eCol = 0xCC4444;
        if (_enemyHp < _enemyMaxHp / 4) { eCol = 0xFF2222; }
        dc.setColor(eCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(eBarX + barW - eFill, barY, eFill, barH);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(eBarX, barY, barW, barH);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 5 / 100, barY + barH + 1, Graphics.FONT_XTINY, "YOU", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_w * 95 / 100, barY + barH + 1, Graphics.FONT_XTINY, "CPU", Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, barY - 1, Graphics.FONT_XTINY, "R" + _round, Graphics.TEXT_JUSTIFY_CENTER);

        if (_playerState == PS_BLOCK) {
            dc.setColor(0x4488FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 92 / 100, Graphics.FONT_XTINY, "BLOCKING", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_playerState == PS_DODGE_L || _playerState == PS_DODGE_R) {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 92 / 100, Graphics.FONT_XTINY, "DODGE!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_enemyState == ES_WINDUP && _enemyStateTick > 3) {
            var warnFlash = (_tick % 4 < 2);
            if (warnFlash) {
                dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 16 / 100, Graphics.FONT_XTINY, "! INCOMING !", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden function drawKO(dc) {
        var prog = _koTick;
        if (prog > 30) { prog = 30; }
        var alpha = prog * 4;
        if (alpha > 120) { alpha = 120; }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 35 / 100, _w, _h * 30 / 100);

        var flash = (_koTick % 6 < 3);
        dc.setColor(flash ? 0xFF2222 : 0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 38 / 100, Graphics.FONT_MEDIUM, "K.O.!", Graphics.TEXT_JUSTIFY_CENTER);

        if (_koTick > 30) {
            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            var count = 10 - (_koTick - 30) / 5;
            if (count < 1) { count = 1; }
            dc.drawText(_w / 2, _h * 52 / 100, Graphics.FONT_SMALL, "" + count, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawWin(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 25 / 100, _w, _h * 55 / 100);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_MEDIUM, "YOU WIN!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 42 / 100, Graphics.FONT_SMALL, "Round " + _round + " cleared", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_XTINY, "Hits: " + _totalHits, Graphics.TEXT_JUSTIFY_CENTER);
        if (_perfectHits > 0) {
            dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 61 / 100, Graphics.FONT_XTINY, "Counters: " + _perfectHits, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 20 < 10) ? 0x44FF44 : 0x22AA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 72 / 100, Graphics.FONT_XTINY, "Tap for next round", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawLose(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 25 / 100, _w, _h * 55 / 100);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_MEDIUM, "DEFEATED", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 42 / 100, Graphics.FONT_SMALL, "Round " + _round, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_XTINY, "Hits: " + _totalHits, Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestRound > 0) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 62 / 100, Graphics.FONT_XTINY, "Best: Round " + _bestRound, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 20 < 10) ? 0xFF8844 : 0xBB6622, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 72 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
