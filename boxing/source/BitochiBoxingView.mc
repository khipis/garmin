using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum { GS_MENU, GS_INTRO, GS_FIGHT, GS_KO, GS_WIN, GS_LOSE }
enum { PS_IDLE, PS_JAB, PS_CROSS, PS_HOOK, PS_UPPER, PS_BODY, PS_DODGE_L, PS_DODGE_R, PS_BLOCK, PS_HIT_STUN, PS_SUPER, PS_EXHAUSTED }

enum { ES_IDLE, ES_WINDUP, ES_JAB, ES_HOOK, ES_UPPER, ES_COMBO, ES_STUNNED, ES_DODGE }

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
    hidden var _comboMeter;
    hidden var _totalHits;
    hidden var _perfectHits;
    hidden var _maxCombo;
    hidden var _stamina;
    hidden var _staminaMax;
    hidden var _staminaRegenDelay;
    hidden var _score;
    hidden var _bestScore;
    hidden var _roundTimer;
    hidden var _punchLabel;
    hidden var _punchLabelTick;

    hidden var _enemyHp;
    hidden var _enemyMaxHp;
    hidden var _enemyState;
    hidden var _enemyStateTick;
    hidden var _enemyAttackTimer;
    hidden var _enemyNextAttack;
    hidden var _enemySpeed;
    hidden var _enemyDmg;
    hidden var _enemyFace;
    hidden var _enemyComboLeft;
    hidden var _enemyPunchType;
    hidden var _enemyStamina;
    hidden var _enemyStaminaMax;

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
    hidden var _superFlash;

    hidden var _prevAccelMag;
    hidden var _accelSmooth;

    hidden const BLOOD_MAX = 40;
    hidden var _bloodX;
    hidden var _bloodY;
    hidden var _bloodVx;
    hidden var _bloodVy;
    hidden var _bloodLife;
    hidden var _bloodIdx;

    hidden var _sweatX;
    hidden var _sweatY;
    hidden var _sweatVx;
    hidden var _sweatVy;
    hidden var _sweatLife;

    hidden var _starX;
    hidden var _starY;
    hidden var _starLife;

    hidden var _dmgPopX;
    hidden var _dmgPopY;
    hidden var _dmgPopVal;
    hidden var _dmgPopLife;
    hidden var _dmgPopType;

    hidden var _enemyBruise;
    hidden var _enemyCuts;
    hidden var _enemySwellL;
    hidden var _enemySwellR;
    hidden var _enemyNoseBleed;
    hidden var _playerBruise;
    hidden var _playerSwellL;
    hidden var _playerSwellR;
    hidden var _crowdPhase;
    hidden var _crowdHype;

    hidden var _enemySkin;
    hidden var _enemyHairCol;
    hidden var _enemyHairStyle;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;

        accelX = 0; accelY = 0; accelZ = 0;
        _tick = 0; _round = 1; _wins = 0; _bestRound = 0;
        _prevAccelMag = 0; _accelSmooth = 0; _crowdPhase = 0; _crowdHype = 0;
        _score = 0;
        var bs = Application.Storage.getValue("boxBest");
        _bestScore = (bs != null) ? bs : 0;

        _bloodX = new [BLOOD_MAX]; _bloodY = new [BLOOD_MAX];
        _bloodVx = new [BLOOD_MAX]; _bloodVy = new [BLOOD_MAX];
        _bloodLife = new [BLOOD_MAX]; _bloodIdx = 0;
        for (var i = 0; i < BLOOD_MAX; i++) { _bloodX[i] = 0; _bloodY[i] = 0; _bloodVx[i] = 0; _bloodVy[i] = 0; _bloodLife[i] = 0; }

        _sweatX = new [8]; _sweatY = new [8]; _sweatVx = new [8]; _sweatVy = new [8]; _sweatLife = new [8];
        for (var i = 0; i < 8; i++) { _sweatX[i] = 0; _sweatY[i] = 0; _sweatVx[i] = 0; _sweatVy[i] = 0; _sweatLife[i] = 0; }

        _starX = new [6]; _starY = new [6]; _starLife = new [6];
        for (var i = 0; i < 6; i++) { _starX[i] = 0; _starY[i] = 0; _starLife[i] = 0; }

        _dmgPopX = new [6]; _dmgPopY = new [6]; _dmgPopVal = new [6]; _dmgPopLife = new [6]; _dmgPopType = new [6];
        for (var i = 0; i < 6; i++) { _dmgPopX[i] = 0; _dmgPopY[i] = 0; _dmgPopVal[i] = 0; _dmgPopLife[i] = 0; _dmgPopType[i] = 0; }

        _playerHp = 100; _playerMaxHp = 100;
        _playerState = PS_IDLE; _playerStateTick = 0; _punchCooldown = 0;
        _comboCount = 0; _comboTimer = 0; _comboMeter = 0; _totalHits = 0; _perfectHits = 0; _maxCombo = 0;
        _stamina = 100; _staminaMax = 100; _staminaRegenDelay = 0;
        _playerBruise = 0; _playerSwellL = 0; _playerSwellR = 0;
        _punchLabel = ""; _punchLabelTick = 0;
        _roundTimer = 1800;

        _enemyHp = 80; _enemyMaxHp = 80;
        _enemyState = ES_IDLE; _enemyStateTick = 0;
        _enemyAttackTimer = 0; _enemyNextAttack = 30;
        _enemySpeed = 1.0; _enemyDmg = 8; _enemyFace = 0;
        _enemyComboLeft = 0; _enemyPunchType = 0;
        _enemyStamina = 100; _enemyStaminaMax = 100;
        _enemyBruise = 0; _enemyCuts = 0; _enemySwellL = 0; _enemySwellR = 0; _enemyNoseBleed = 0;
        _enemySkin = 0xDDAA77; _enemyHairCol = 0x222222; _enemyHairStyle = 0;

        _shakeX = 0; _shakeY = 0; _shakeLeft = 0;
        _flashTick = 0; _hitFlash = 0; _superFlash = 0; _introTick = 0; _koTick = 0;
        gameState = GS_MENU;
    }

    function onShow() { _timer = new Timer.Timer(); _timer.start(method(:onTick), 33, true); }
    function onHide() { if (_timer != null) { _timer.stop(); _timer = null; } }

    hidden function initFight() {
        var r = _round;
        if (r < 1) { r = 1; }
        _enemyMaxHp = 78 + r * 14 + (r / 4) * 8;
        if (_enemyMaxHp > 410) { _enemyMaxHp = 410; }
        _enemyHp = _enemyMaxHp;
        _enemyDmg = 8 + r * 2 + r / 4;
        if (_enemyDmg > 38) { _enemyDmg = 38; }
        _enemySpeed = 1.0 + (r - 1) * 0.16 + (r / 6) * 0.08;
        if (_enemySpeed > 3.2) { _enemySpeed = 3.2; }
        _enemyStaminaMax = 80 + r * 5;
        if (_enemyStaminaMax > 160) { _enemyStaminaMax = 160; }
        _enemyStamina = _enemyStaminaMax;

        if (r > 1 && r % 3 == 1) {
            _playerMaxHp += 4;
            if (_playerMaxHp > 142) { _playerMaxHp = 142; }
        }
        _enemyFace = (_round - 1) % 8;
        _enemyState = ES_IDLE; _enemyStateTick = 0;
        _enemyAttackTimer = 0; _enemyComboLeft = 0; _enemyPunchType = 0;
        var baseDelay = (18.0 / _enemySpeed).toNumber();
        if (baseDelay < 5) { baseDelay = 5; }
        _enemyNextAttack = baseDelay + Math.rand().abs() % 10;
        _enemyBruise = 0; _enemyCuts = 0; _enemySwellL = 0; _enemySwellR = 0; _enemyNoseBleed = 0;

        var skins = [0xDDAA77, 0xBB8855, 0x8B6842, 0xE8C39E, 0xA0734A, 0xC9956B, 0xD4A574, 0x6B4226];
        _enemySkin = skins[_enemyFace % 8];
        var hairs = [0x222222, 0x553311, 0xAA6633, 0xFF4422, 0x888888, 0x111111, 0xDDBB44, 0x221100];
        _enemyHairCol = hairs[_enemyFace % 8];
        _enemyHairStyle = _enemyFace % 4;

        _playerHp = _playerMaxHp; _playerState = PS_IDLE; _playerStateTick = 0;
        _punchCooldown = 0; _comboCount = 0; _comboTimer = 0; _comboMeter = 0;
        _totalHits = 0; _perfectHits = 0; _maxCombo = 0;
        _stamina = _staminaMax; _staminaRegenDelay = 0;
        _playerBruise = 0; _playerSwellL = 0; _playerSwellR = 0;
        _punchLabel = ""; _punchLabelTick = 0;
        _roundTimer = 1800;

        _bloodIdx = 0;
        for (var i = 0; i < BLOOD_MAX; i++) { _bloodLife[i] = 0; }
        for (var i = 0; i < 8; i++) { _sweatLife[i] = 0; }
        for (var i = 0; i < 6; i++) { _starLife[i] = 0; }
        for (var i = 0; i < 6; i++) { _dmgPopLife[i] = 0; }
    }

    function doAction() {
        if (gameState == GS_MENU) {
            _round = 1; _wins = 0; _score = 0; _playerMaxHp = 100; initFight();
            gameState = GS_INTRO; _introTick = 0;
        } else if (gameState == GS_FIGHT) {
            if (_comboMeter >= 100) {
                doSuperPunch();
            } else {
                doPlayerPunch(PS_JAB);
            }
        } else if (gameState == GS_WIN) {
            _round++; initFight();
            gameState = GS_INTRO; _introTick = 0;
        } else if (gameState == GS_LOSE) {
            _round = 1; _wins = 0; _score = 0; _playerMaxHp = 100; initFight();
            gameState = GS_INTRO; _introTick = 0;
        }
    }

    hidden function doSuperPunch() {
        _playerState = PS_SUPER; _playerStateTick = 0;
        _punchCooldown = 14;
        _comboMeter = 0;
        _superFlash = 8;
        _staminaRegenDelay = 20;
        doVibe(100, 300);

        if (_enemyState == ES_DODGE) { spawnSweat(_w / 2, eBaseY(), 3); return; }

        var dmg = 45 + _comboCount * 4;
        _enemyHp -= dmg;
        _enemyState = ES_STUNNED; _enemyStateTick = 0;
        _flashTick = 8;
        _shakeLeft = 12;
        _crowdHype = 60;
        _totalHits++;

        _enemyBruise += 10; if (_enemyBruise > 35) { _enemyBruise = 35; }
        _enemyNoseBleed += 8; if (_enemyNoseBleed > 25) { _enemyNoseBleed = 25; }
        _enemyCuts += 2; if (_enemyCuts > 6) { _enemyCuts = 6; }

        var bx = _w / 2;
        var by = eBaseY();
        spawnBlood(bx, by - 10, 15);
        spawnPop(bx, by - 20, dmg, 4);
        _punchLabel = "SUPER!"; _punchLabelTick = 30;

        if (_enemyHp <= 0) {
            _enemyHp = 0; _enemyState = ES_STUNNED; _enemyStateTick = 0;
            gameState = GS_KO; _koTick = 0; _shakeLeft = 18;
            doVibe(100, 500); spawnBlood(_w / 2, eBaseY() - 10, 25);
            spawnStars(_w / 2, eBaseY() - 20);
        }
    }

    hidden function eBaseY() { return _h * 34 / 100; }
    hidden function pBaseY() { return _h * 64 / 100; }

    function onTick() as Void {
        _tick++;
        _crowdPhase = (_crowdPhase + 1) % 120;
        if (_crowdHype > 0) { _crowdHype--; }
        if (_shakeLeft > 0) { _shakeX = (Math.rand().abs() % 9) - 4; _shakeY = (Math.rand().abs() % 7) - 3; _shakeLeft--; } else { _shakeX = 0; _shakeY = 0; }
        if (_flashTick > 0) { _flashTick--; }
        if (_hitFlash > 0) { _hitFlash--; }
        if (_superFlash > 0) { _superFlash--; }
        if (_punchLabelTick > 0) { _punchLabelTick--; }

        if (gameState == GS_INTRO) {
            _introTick++;
            if (_introTick >= 50) { gameState = GS_FIGHT; }
        } else if (gameState == GS_FIGHT) {
            updateAccel(); updatePlayer(); updateEnemy();
            updateBlood(); updateSweat(); updateStars(); updatePops();
            if (_comboTimer > 0) { _comboTimer--; }
            if (_comboTimer == 0 && _comboCount > 0) { _comboCount = 0; }
            if (_comboMeter > 0 && _tick % 5 == 0) { _comboMeter--; }

            if (_staminaRegenDelay > 0) { _staminaRegenDelay--; }
            else if (_stamina < _staminaMax && _tick % 8 == 0) { _stamina++; }

            if (_enemyStamina < _enemyStaminaMax && _tick % 6 == 0) { _enemyStamina++; }

            _roundTimer--;
            if (_roundTimer <= 0) {
                var pPct = _playerHp * 100 / _playerMaxHp;
                var ePct = _enemyHp * 100 / _enemyMaxHp;
                if (pPct >= ePct) {
                    _enemyHp = 0; _wins++;
                    if (_round > _bestRound) { _bestRound = _round; }
                    gameState = GS_KO; _koTick = 0; _shakeLeft = 10;
                } else {
                    _playerHp = 0;
                    gameState = GS_KO; _koTick = 0; _shakeLeft = 10;
                }
            }
        } else if (gameState == GS_KO) {
            _koTick++; updateBlood(); updateStars(); updatePops();
            if (_koTick >= 65) {
                if (_enemyHp <= 0) {
                    _wins++;
                    if (_round > _bestRound) { _bestRound = _round; }
                    _score += 100 + _round * 50 + _perfectHits * 20 + _maxCombo * 10;
                    if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("boxBest", _bestScore); }
                    gameState = GS_WIN;
                } else { gameState = GS_LOSE; }
            }
        }
        WatchUi.requestUpdate();
    }

    hidden function updateAccel() {
        var ax = (accelX != null) ? accelX : 0;
        var ay = (accelY != null) ? accelY : 0;
        var az = (accelZ != null) ? accelZ : 0;
        var mag = Math.sqrt(ax * ax + ay * ay + az * az).toNumber();
        var delta = (mag - _accelSmooth);
        if (delta < 0) { delta = -delta; }
        _accelSmooth = _accelSmooth + (mag - _accelSmooth) * 0.3;
        if (_punchCooldown > 0) { _punchCooldown--; }

        if ((_playerState == PS_IDLE || _playerState == PS_BLOCK) && _playerState != PS_EXHAUSTED) {
            if (ax > 350) { _playerState = PS_DODGE_L; _playerStateTick = 0; _stamina -= 10; if (_stamina < 0) { _stamina = 0; } _staminaRegenDelay = 8; }
            else if (ax < -350) { _playerState = PS_DODGE_R; _playerStateTick = 0; _stamina -= 10; if (_stamina < 0) { _stamina = 0; } _staminaRegenDelay = 8; }
            else if (delta > 500 && _punchCooldown <= 0) {
                var pType = PS_JAB;
                if (delta > 1400) { pType = PS_UPPER; }
                else if (delta > 1100) { pType = PS_HOOK; }
                else if (delta > 800) { pType = PS_CROSS; }
                else if (ay < -300) { pType = PS_BODY; }
                doPlayerPunch(pType);
            } else if (ax > -80 && ax < 80 && delta < 150) {
                if (_playerState != PS_BLOCK) { _playerState = PS_BLOCK; _playerStateTick = 0; }
            }
        }
        _prevAccelMag = mag;
    }

    hidden function doPlayerPunch(pType) {
        if (_punchCooldown > 0 || _playerState == PS_HIT_STUN || _playerState == PS_EXHAUSTED) { return; }
        if (_playerState >= PS_JAB && _playerState <= PS_BODY) { return; }

        var cost = 18;
        if (pType == PS_CROSS) { cost = 24; }
        else if (pType == PS_HOOK) { cost = 32; }
        else if (pType == PS_UPPER) { cost = 40; }
        else if (pType == PS_BODY) { cost = 20; }
        if (_stamina < cost) {
            _playerState = PS_EXHAUSTED; _playerStateTick = 0;
            _punchLabel = "TIRED!"; _punchLabelTick = 18;
            return;
        }

        _playerState = pType; _playerStateTick = 0;
        _punchCooldown = 10;
        _stamina -= cost;
        _staminaRegenDelay = 12;
        if (_stamina <= 0) { _stamina = 0; _playerState = PS_EXHAUSTED; _playerStateTick = 0; _punchLabel = "TIRED!"; _punchLabelTick = 18; return; }
        doVibe(25, 40);

        if (pType == PS_JAB) { _punchLabel = "JAB!"; }
        else if (pType == PS_CROSS) { _punchLabel = "CROSS!"; }
        else if (pType == PS_HOOK) { _punchLabel = "HOOK!"; }
        else if (pType == PS_UPPER) { _punchLabel = "UPPER!"; }
        else if (pType == PS_BODY) { _punchLabel = "BODY!"; }
        _punchLabelTick = 18;

        if (_enemyState == ES_DODGE) { spawnSweat(_w / 2, eBaseY(), 3); return; }

        var dmg = 8;
        var isCounter = false;
        if (pType == PS_CROSS) { dmg = 12; }
        else if (pType == PS_HOOK) { dmg = 16; }
        else if (pType == PS_UPPER) { dmg = 22; }
        else if (pType == PS_BODY) { dmg = 10; }

        if (_stamina < 25) { dmg = (dmg * 0.6).toNumber(); if (dmg < 3) { dmg = 3; } }

        if (_enemyState == ES_WINDUP || _enemyState == ES_JAB || _enemyState == ES_HOOK || _enemyState == ES_UPPER || _enemyState == ES_COMBO) {
            dmg = (dmg * 1.8).toNumber();
            isCounter = true;
            _enemyState = ES_STUNNED; _enemyStateTick = 0;
            _flashTick = 5;
            _comboMeter += 15;
            _punchLabel = "COUNTER!"; _punchLabelTick = 22;
            _crowdHype = 40;
            _stamina += 12;
            if (_stamina > _staminaMax) { _stamina = _staminaMax; }
        }

        _comboCount++; _comboTimer = 35;
        if (_comboCount > _maxCombo) { _maxCombo = _comboCount; }
        _comboMeter += 4;
        if (_comboMeter > 100) { _comboMeter = 100; }

        if (_comboCount > 4) { dmg = dmg + _comboCount * 2; }
        if (_comboMeter >= 80) { dmg = (dmg * 1.2).toNumber(); }

        _enemyHp -= dmg; _totalHits++;
        if (isCounter) { _perfectHits++; }
        _shakeLeft = 5;

        _enemyBruise += 3; if (_enemyBruise > 35) { _enemyBruise = 35; }
        if (pType == PS_HOOK || pType == PS_CROSS) {
            var side = Math.rand().abs() % 2;
            if (side == 0) { _enemySwellL += 4; if (_enemySwellL > 14) { _enemySwellL = 14; } }
            else { _enemySwellR += 4; if (_enemySwellR > 14) { _enemySwellR = 14; } }
        }
        if (pType == PS_UPPER) { _enemyNoseBleed += 6; if (_enemyNoseBleed > 25) { _enemyNoseBleed = 25; } }
        if (dmg > 15) { _enemyCuts++; if (_enemyCuts > 6) { _enemyCuts = 6; } }

        var bx = _w / 2 + (Math.rand().abs() % 20) - 10;
        var by = eBaseY() + (Math.rand().abs() % 14) - 7;
        spawnBlood(bx, by, dmg > 16 ? 10 : 5);
        spawnPop(bx, by - 8, dmg, isCounter ? 2 : (pType == PS_UPPER ? 1 : 0));

        if (dmg >= 25) { _crowdHype = 30; }

        if (_enemyHp <= 0) {
            _enemyHp = 0; _enemyState = ES_STUNNED; _enemyStateTick = 0;
            gameState = GS_KO; _koTick = 0; _shakeLeft = 15;
            doVibe(100, 400); spawnBlood(_w / 2, eBaseY() - 5, 20);
            spawnStars(_w / 2, eBaseY() - 15);
            _crowdHype = 60;
        }
    }

    hidden function updatePlayer() {
        _playerStateTick++;
        if (_playerState == PS_SUPER) {
            if (_playerStateTick >= 10) { _playerState = PS_IDLE; _playerStateTick = 0; }
        } else if (_playerState == PS_EXHAUSTED) {
            if (_playerStateTick >= 30) { _playerState = PS_IDLE; _playerStateTick = 0; _stamina = 15; }
        } else if (_playerState >= PS_JAB && _playerState <= PS_BODY) {
            if (_playerStateTick >= 7) { _playerState = PS_IDLE; _playerStateTick = 0; }
        } else if (_playerState == PS_DODGE_L || _playerState == PS_DODGE_R) {
            if (_playerStateTick >= 10) { _playerState = PS_IDLE; _playerStateTick = 0; }
        } else if (_playerState == PS_HIT_STUN) {
            if (_playerStateTick >= 14) { _playerState = PS_IDLE; _playerStateTick = 0; }
        } else if (_playerState == PS_BLOCK) {
            var ax = (accelX != null) ? accelX : 0;
            if (ax > 150 || ax < -150) { _playerState = PS_IDLE; _playerStateTick = 0; }
            if (_tick % 4 == 0) { _stamina--; if (_stamina < 0) { _stamina = 0; } }
        }
    }

    hidden function updateEnemy() {
        _enemyStateTick++;
        if (_enemyState == ES_IDLE) {
            _enemyAttackTimer++;
            if (_enemyAttackTimer >= _enemyNextAttack && _enemyStamina > 15) {
                var atkType = Math.rand().abs() % 100;
                if (atkType < 25) { _enemyState = ES_WINDUP; _enemyPunchType = 0; _enemyStamina -= 8; }
                else if (atkType < 42) { _enemyState = ES_WINDUP; _enemyPunchType = 1; _enemyStamina -= 14; }
                else if (atkType < 56) { _enemyState = ES_WINDUP; _enemyPunchType = 2; _enemyStamina -= 18; }
                else { _enemyState = ES_WINDUP; _enemyPunchType = 3; _enemyComboLeft = 2 + Math.rand().abs() % 3; _enemyStamina -= 10 * _enemyComboLeft; }
                _enemyStateTick = 0; _enemyAttackTimer = 0;
                var bd = (14.0 / _enemySpeed).toNumber();
                if (bd < 4) { bd = 4; }
                _enemyNextAttack = bd + Math.rand().abs() % 8;
            }
            var dodgeChance = (4.0 * _enemySpeed).toNumber();
            if (dodgeChance > 12) { dodgeChance = 12; }
            if (Math.rand().abs() % 100 < dodgeChance) {
                _enemyState = ES_DODGE; _enemyStateTick = 0;
            }
        } else if (_enemyState == ES_WINDUP) {
            var wt = (7.0 / _enemySpeed).toNumber();
            if (wt < 2) { wt = 2; }
            if (_enemyStateTick >= wt) {
                if (_enemyPunchType == 0) { _enemyState = ES_JAB; }
                else if (_enemyPunchType == 1) { _enemyState = ES_HOOK; }
                else if (_enemyPunchType == 2) { _enemyState = ES_UPPER; }
                else { _enemyState = ES_COMBO; }
                _enemyStateTick = 0;
            }
        } else if (_enemyState == ES_JAB) {
            if (_enemyStateTick == 2) { enemyHitPlayer(1.0); }
            if (_enemyStateTick >= 7) { _enemyState = ES_IDLE; _enemyStateTick = 0; }
        } else if (_enemyState == ES_HOOK) {
            if (_enemyStateTick == 3) { enemyHitPlayer(1.6); }
            if (_enemyStateTick >= 9) { _enemyState = ES_IDLE; _enemyStateTick = 0; }
        } else if (_enemyState == ES_UPPER) {
            if (_enemyStateTick == 3) { enemyHitPlayer(2.2); }
            if (_enemyStateTick >= 11) { _enemyState = ES_IDLE; _enemyStateTick = 0; }
        } else if (_enemyState == ES_COMBO) {
            if (_enemyStateTick == 2) {
                var cMult = 0.9;
                if (_enemyComboLeft <= 1) { cMult = 1.4; }
                enemyHitPlayer(cMult);
            }
            var comboSpeed = (5.0 / _enemySpeed).toNumber();
            if (comboSpeed < 3) { comboSpeed = 3; }
            if (_enemyStateTick >= comboSpeed + 2) {
                _enemyComboLeft--;
                if (_enemyComboLeft > 0) { _enemyStateTick = 0; }
                else { _enemyState = ES_IDLE; _enemyStateTick = 0; }
            }
        } else if (_enemyState == ES_STUNNED) {
            if (_enemyStateTick >= 16) { _enemyState = ES_IDLE; _enemyStateTick = 0; }
        } else if (_enemyState == ES_DODGE) {
            if (_enemyStateTick >= 10) { _enemyState = ES_IDLE; _enemyStateTick = 0; }
        }
    }

    hidden function enemyHitPlayer(mult) {
        if (_playerState == PS_DODGE_L || _playerState == PS_DODGE_R) { spawnSweat(_w / 2, pBaseY(), 3); return; }
        var dmg = (_enemyDmg.toFloat() * mult).toNumber();
        if (_playerState == PS_BLOCK) {
            dmg = (dmg * 0.25).toNumber(); if (dmg < 1) { dmg = 1; }
            _stamina -= 8; if (_stamina < 0) { _stamina = 0; }
            doVibe(20, 40); _shakeLeft = 2;
        } else {
            _stamina -= 18; if (_stamina < 0) { _stamina = 0; }
            _staminaRegenDelay = 15;
            _playerState = PS_HIT_STUN; _playerStateTick = 0;
            doVibe(70, 180); _shakeLeft = 7; _hitFlash = 5;
            _playerBruise += 3; if (_playerBruise > 25) { _playerBruise = 25; }
            if (Math.rand().abs() % 3 == 0) {
                var side = Math.rand().abs() % 2;
                if (side == 0) { _playerSwellL += 3; if (_playerSwellL > 12) { _playerSwellL = 12; } }
                else { _playerSwellR += 3; if (_playerSwellR > 12) { _playerSwellR = 12; } }
            }
            spawnBlood(_w / 2 + (Math.rand().abs() % 12) - 6, pBaseY(), 4);
        }
        _playerHp -= dmg; _comboCount = 0; _comboTimer = 0;
        spawnPop(_w / 2, pBaseY() - 5, dmg, 3);

        if (_playerHp <= 0) {
            _playerHp = 0; gameState = GS_KO; _koTick = 0; _shakeLeft = 15;
            doVibe(100, 500); spawnBlood(_w / 2, pBaseY(), 15); spawnStars(_w / 2, pBaseY() - 10);
        }
    }

    hidden function spawnBlood(bx, by, count) {
        for (var i = 0; i < count; i++) {
            var s = _bloodIdx % BLOOD_MAX;
            _bloodX[s] = bx + (Math.rand().abs() % 12) - 6;
            _bloodY[s] = by + (Math.rand().abs() % 8) - 4;
            _bloodVx[s] = (Math.rand().abs() % 9) - 4;
            _bloodVy[s] = -(Math.rand().abs() % 6) - 2;
            _bloodLife[s] = 22 + Math.rand().abs() % 18;
            _bloodIdx++;
        }
    }
    hidden function spawnSweat(sx, sy, count) {
        for (var i = 0; i < count && i < 8; i++) {
            _sweatX[i] = sx + (Math.rand().abs() % 20) - 10;
            _sweatY[i] = sy; _sweatVx[i] = (Math.rand().abs() % 7) - 3;
            _sweatVy[i] = -(Math.rand().abs() % 5) - 1;
            _sweatLife[i] = 14 + Math.rand().abs() % 8;
        }
    }
    hidden function spawnStars(sx, sy) {
        for (var i = 0; i < 6; i++) {
            var a = i * 60; var r = 10 + Math.rand().abs() % 8;
            _starX[i] = sx + (r * Math.cos(a * 0.01745)).toNumber();
            _starY[i] = sy + (r * Math.sin(a * 0.01745)).toNumber();
            _starLife[i] = 30 + Math.rand().abs() % 12;
        }
    }
    hidden function spawnPop(px, py, val, type) {
        for (var i = 0; i < 6; i++) {
            if (_dmgPopLife[i] <= 0) {
                _dmgPopX[i] = px; _dmgPopY[i] = py; _dmgPopVal[i] = val; _dmgPopLife[i] = 28; _dmgPopType[i] = type;
                return;
            }
        }
        _dmgPopX[0] = px; _dmgPopY[0] = py; _dmgPopVal[0] = val; _dmgPopLife[0] = 28; _dmgPopType[0] = type;
    }

    hidden function updateBlood() { for (var i = 0; i < BLOOD_MAX; i++) { if (_bloodLife[i] <= 0) { continue; } _bloodX[i] += _bloodVx[i]; _bloodY[i] += _bloodVy[i]; _bloodVy[i] += 1; _bloodLife[i]--; } }
    hidden function updateSweat() { for (var i = 0; i < 8; i++) { if (_sweatLife[i] <= 0) { continue; } _sweatX[i] += _sweatVx[i]; _sweatY[i] += _sweatVy[i]; _sweatVy[i] += 1; _sweatLife[i]--; } }
    hidden function updateStars() { for (var i = 0; i < 6; i++) { if (_starLife[i] > 0) { _starLife[i]--; } } }
    hidden function updatePops() { for (var i = 0; i < 6; i++) { if (_dmgPopLife[i] > 0) { _dmgPopY[i]--; _dmgPopLife[i]--; } } }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) { if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
        } }
    }

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        if (gameState == GS_MENU) { drawMenu(dc); return; }
        if (gameState == GS_INTRO) { drawIntro(dc); return; }

        var ox = _shakeX; var oy = _shakeY;
        drawArena(dc, ox, oy);
        drawRopes(dc, ox, oy);
        drawCrowd(dc, ox, oy);
        drawEnemy(dc, ox, oy);
        drawPlayer(dc, ox, oy);
        drawBloodParts(dc, ox, oy);
        drawSweatParts(dc, ox, oy);
        drawStarParts(dc, ox, oy);
        drawPops(dc, ox, oy);
        drawHUD(dc);

        if (_hitFlash > 0) { dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT); dc.setPenWidth(3); dc.drawRectangle(1, 1, _w - 2, _h - 2); dc.setPenWidth(1); }
        if (_flashTick > 0 && _flashTick % 2 == 0) { dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT); dc.setPenWidth(2); dc.drawRectangle(2, 2, _w - 4, _h - 4); dc.setPenWidth(1); }
        if (_superFlash > 0) {
            var sc = (_superFlash % 2 == 0) ? 0xFFDD00 : 0xFF4400;
            dc.setColor(sc, Graphics.COLOR_TRANSPARENT); dc.setPenWidth(4); dc.drawRectangle(0, 0, _w, _h); dc.setPenWidth(1);
        }

        if (gameState == GS_KO) { drawKO(dc); }
        else if (gameState == GS_WIN) { drawWin(dc); }
        else if (gameState == GS_LOSE) { drawLose(dc); }

        if (_punchLabelTick > 0 && gameState == GS_FIGHT) {
            var lc = 0xFFFFFF;
            if (_punchLabel.equals("COUNTER!")) { lc = 0xFF4444; }
            else if (_punchLabel.equals("SUPER!")) { lc = 0xFFDD00; }
            else if (_punchLabel.equals("TIRED!")) { lc = 0xFF6622; }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2 + 1, _h * 48 / 100 + 1, Graphics.FONT_SMALL, _punchLabel, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(lc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_SMALL, _punchLabel, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_comboCount >= 3 && _comboTimer > 0 && gameState == GS_FIGHT) {
            var comboC = 0xFFDD00;
            if (_comboCount >= 8) { comboC = 0xFF2222; }
            else if (_comboCount >= 5) { comboC = 0xFF6622; }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2 + 1, _h * 43 / 100 + 1, Graphics.FONT_XTINY, "" + _comboCount + "x COMBO!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(comboC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 43 / 100, Graphics.FONT_XTINY, "" + _comboCount + "x COMBO!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawArena(dc, ox, oy) {
        dc.setColor(0x0A0A18, 0x0A0A18); dc.clear();
        dc.setColor(0x121222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 22 / 100 + oy, _w, _h * 78 / 100);
        var floorY = _h * 78 / 100 + oy;
        dc.setColor(0x334488, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, floorY, _w, _h - floorY + 10);
        dc.setColor(0x2A3A6A, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _w; i += 7) { dc.fillRectangle(i + ox, floorY, 3, _h - floorY + 10); }
        dc.setColor(0x445599, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, floorY, _w, 2);
        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 4 / 100 + ox, floorY + 2, _w * 92 / 100, 4);

        dc.setColor(0x181830, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 22 / 100 + oy, _w, 3);
    }

    hidden function drawRopes(dc, ox, oy) {
        var lx = _w * 6 / 100 + ox; var rx = _w * 94 / 100 + ox;
        var ty = _h * 20 / 100 + oy; var my = _h * 39 / 100 + oy; var by = _h * 57 / 100 + oy;
        dc.setColor(0x554433, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - 2, ty, 4, by - ty + 4);
        dc.fillRectangle(rx - 2, ty, 4, by - ty + 4);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT); dc.drawLine(lx, ty, rx, ty); dc.drawLine(lx, ty + 1, rx, ty + 1);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawLine(lx, my, rx, my); dc.drawLine(lx, my + 1, rx, my + 1);
        dc.setColor(0x4444FF, Graphics.COLOR_TRANSPARENT); dc.drawLine(lx, by, rx, by); dc.drawLine(lx, by + 1, rx, by + 1);
    }

    hidden function drawCrowd(dc, ox, oy) {
        var cy = _h * 10 / 100 + oy;
        var headC = [0xDDAA77, 0xCC9966, 0xBB8855, 0xAA7744, 0xDD9988, 0xCCAA88, 0x8B6842, 0xE8C39E];
        var shirtC = [0xDD3333, 0x3333DD, 0x33DD33, 0xDDDD33, 0xDD33DD, 0x33DDDD, 0xDD6633, 0x3366DD];
        for (var i = 0; i < 16; i++) {
            var cx = (i * _w / 16) + _w / 32 + ox;
            var bounce = 0;
            if (_crowdHype > 0) {
                bounce = ((_crowdPhase + i * 7) % 10 < 5) ? -3 : 0;
            } else {
                bounce = ((_crowdPhase + i * 9) % 24 < 12) ? -1 : 0;
            }
            dc.setColor(headC[(i * 3 + 5) % 8], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy + bounce, 3);
            dc.setColor(shirtC[(i * 5 + 1) % 8], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 2, cy + 3 + bounce, 4, 4);

            if (_crowdHype > 30 && i % 3 == 0) {
                dc.setColor(shirtC[(i * 5 + 1) % 8], Graphics.COLOR_TRANSPARENT);
                var armUp = ((_tick + i * 5) % 8 < 4) ? -5 : -3;
                dc.fillRectangle(cx - 1, cy + armUp + bounce, 2, 3);
            }
        }
    }

    hidden function drawEnemy(dc, ox, oy) {
        var cx = _w / 2 + ox;
        var baseY = eBaseY() + oy;
        var dodgeOff = 0;
        if (_enemyState == ES_DODGE) { dodgeOff = (_enemyStateTick < 5) ? -14 : 14; }
        cx += dodgeOff;

        var headR = _w * 6 / 100;
        if (headR < 7) { headR = 7; }
        var bodyW = (headR * 1.8).toNumber();
        var bodyH = (headR * 2.0).toNumber();
        var headY = baseY - bodyH / 2 - headR + 2;
        var bobOff = (_enemyState == ES_IDLE) ? ((_tick % 14 < 7) ? -1 : 1) : 0;
        headY += bobOff;

        if (_enemyState == ES_STUNNED) { cx += ((_enemyStateTick % 6 < 3) ? -3 : 3); }

        var skin = _enemySkin;
        if (_enemyBruise > 0) {
            var sr = (skin >> 16) & 0xFF; var sg = (skin >> 8) & 0xFF;
            sr = sr - _enemyBruise * 2; sg = sg - _enemyBruise * 3;
            if (sr < 0x55) { sr = 0x55; } if (sg < 0x33) { sg = 0x33; }
            skin = (sr << 16) | (sg << 8) | (skin & 0xFF);
        }

        dc.setColor(skin, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, headY, headR);

        dc.setColor(_enemyHairCol, Graphics.COLOR_TRANSPARENT);
        if (_enemyHairStyle == 0) {
            dc.fillRectangle(cx - headR + 1, headY - headR - 1, headR * 2 - 2, headR / 2);
        } else if (_enemyHairStyle == 1) {
            dc.fillCircle(cx, headY - headR + 2, headR - 1);
        } else if (_enemyHairStyle == 2) {
            dc.fillRectangle(cx - headR + 1, headY - headR, headR * 2 - 2, headR / 3);
            dc.fillRectangle(cx - 2, headY - headR - 3, 4, 4);
        } else {
            dc.fillRectangle(cx - headR + 2, headY - headR, headR * 2 - 4, headR / 2 + 2);
        }

        var eyeY = headY - 1; var leX = cx - headR / 3; var reX = cx + headR / 3;
        if (_enemyState == ES_STUNNED) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(leX - 2, eyeY - 2, leX + 2, eyeY + 2); dc.drawLine(leX + 2, eyeY - 2, leX - 2, eyeY + 2);
            dc.drawLine(reX - 2, eyeY - 2, reX + 2, eyeY + 2); dc.drawLine(reX + 2, eyeY - 2, reX - 2, eyeY + 2);
        } else {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(leX, eyeY, 3); dc.fillCircle(reX, eyeY, 3);
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillCircle(leX, eyeY, 1); dc.fillCircle(reX, eyeY, 1);
            if (_enemySwellL > 3) { dc.setColor(0x884466, Graphics.COLOR_TRANSPARENT); dc.fillCircle(leX - 1, eyeY + 2, _enemySwellL / 3); }
            if (_enemySwellR > 3) { dc.setColor(0x884466, Graphics.COLOR_TRANSPARENT); dc.fillCircle(reX + 1, eyeY + 2, _enemySwellR / 3); }
        }

        if (_enemyState == ES_STUNNED || _enemyHp < _enemyMaxHp / 4) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - headR / 4, headY + headR / 2, cx + headR / 4, headY + headR / 2 + 1);
        } else if (_enemyState == ES_WINDUP) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 3, headY + headR / 3, 6, 3);
        } else {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 2, headY + headR / 3, 4, 2);
        }

        if (_enemyNoseBleed > 0) {
            dc.setColor(0xCC0000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 1, headY + headR / 4, 2, _enemyNoseBleed / 3 + 2);
            if (_enemyNoseBleed > 10) { dc.fillCircle(cx, headY + headR / 3 + _enemyNoseBleed / 3, 2); }
        }

        for (var c = 0; c < _enemyCuts && c < 6; c++) {
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            var cutX = cx - headR / 2 + (c * headR / 3);
            dc.drawLine(cutX, headY - headR / 3 + (c % 2 == 0 ? 2 : -2), cutX + 3, headY - headR / 3 + (c % 2 == 0 ? 5 : 0));
        }

        dc.setColor(skin, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 2, headY + headR, 4, 4);

        var tColors = [0x3344AA, 0x883322, 0x228833, 0x555555, 0xAA2244, 0x886611, 0x338888, 0x663366];
        var tc = tColors[_enemyFace % 8];
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bodyW / 2, baseY - bodyH / 2, bodyW, bodyH);
        dc.setColor(skin, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bodyW / 2 + 2, baseY - bodyH / 2 + 1, bodyW - 4, bodyH / 5);

        var gColors = [0xCC3333, 0x3333CC, 0xCC8833, 0x33CC33, 0xCC33CC, 0xCCCC33, 0x33CCCC, 0xCC6633];
        var gc = gColors[_enemyFace % 8];
        var glR = (headR * 0.65).toNumber();
        if (glR < 4) { glR = 4; }

        if (_enemyState == ES_WINDUP) {
            dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - bodyW / 2 - 5, baseY - bodyH / 4 - 4, glR);
            dc.fillCircle(cx + bodyW / 2 + 5, baseY - bodyH / 4 - 4, glR);
        } else if (_enemyState == ES_JAB || _enemyState == ES_COMBO) {
            var ext = _enemyStateTick < 3 ? _enemyStateTick * 6 : 18 - (_enemyStateTick - 3) * 4;
            var side = (_tick % 2 == 0) ? -1 : 1;
            dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + side * bodyW / 4, baseY + bodyH / 2 + ext, glR + 1);
            dc.fillCircle(cx - side * bodyW / 2 - 4, baseY - bodyH / 4, glR - 1);
        } else if (_enemyState == ES_HOOK) {
            var ext = _enemyStateTick < 4 ? _enemyStateTick * 5 : 20 - (_enemyStateTick - 4) * 4;
            dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + ext, baseY + bodyH / 3, glR + 1);
            dc.fillCircle(cx - bodyW / 2 - 4, baseY - bodyH / 4, glR - 1);
        } else if (_enemyState == ES_UPPER) {
            var ext = _enemyStateTick < 4 ? _enemyStateTick * 7 : 28 - (_enemyStateTick - 4) * 4;
            dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, baseY + bodyH / 2 + ext, glR + 2);
            dc.fillCircle(cx + bodyW / 2 + 4, baseY, glR - 1);
        } else {
            dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - bodyW / 2 - 4, baseY - 1 + bobOff, glR);
            dc.fillCircle(cx + bodyW / 2 + 4, baseY - 1 + bobOff, glR);
        }
    }

    hidden function drawPlayer(dc, ox, oy) {
        var cx = _w / 2 + ox;
        var baseY = pBaseY() + oy;
        if (_playerState == PS_DODGE_L) { cx -= _w * 12 / 100; }
        else if (_playerState == PS_DODGE_R) { cx += _w * 12 / 100; }
        if (_playerState == PS_HIT_STUN) { cx += ((_playerStateTick % 4 < 2) ? -3 : 3); }

        var headR = _w * 5 / 100;
        if (headR < 6) { headR = 6; }
        var bodyW = (headR * 1.8).toNumber();
        var bodyH = (headR * 1.6).toNumber();

        var skin = 0xDDAA77;
        if (_playerBruise > 0) {
            var pr = 0xDD - _playerBruise * 2; var pg = 0xAA - _playerBruise * 3;
            if (pr < 0x88) { pr = 0x88; } if (pg < 0x55) { pg = 0x55; }
            skin = (pr << 16) | (pg << 8) | 0x77;
        }

        dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bodyW / 2, baseY, bodyW, bodyH);
        dc.setColor(skin, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - bodyW / 2 + 2, baseY + 1, bodyW - 4, bodyH / 5);

        var headY = baseY - headR - 1;
        dc.setColor(skin, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, headY, headR);
        dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - headR + 2, headY - headR, headR * 2 - 4, headR / 2 + 2);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - headR / 4, headY - 1, 2);
        dc.fillCircle(cx + headR / 4, headY - 1, 2);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - headR / 4, headY - 1, 1);
        dc.fillCircle(cx + headR / 4, headY - 1, 1);

        if (_playerSwellL > 2) { dc.setColor(0x774455, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - headR / 3 - 1, headY + 1, _playerSwellL / 3); }
        if (_playerSwellR > 2) { dc.setColor(0x774455, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + headR / 3 + 1, headY + 1, _playerSwellR / 3); }
        if (_playerState == PS_HIT_STUN) { dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.drawLine(cx - 3, headY + headR / 2, cx + 3, headY + headR / 2); }
        dc.setColor(skin, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 2, headY + headR, 4, 3);

        var glR = (headR * 0.75).toNumber();
        if (glR < 4) { glR = 4; }

        if (_playerState == PS_SUPER) {
            var ext = _playerStateTick < 4 ? _playerStateTick * 10 : 40 - (_playerStateTick - 4) * 7;
            dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, baseY - ext - headR, glR + 3);
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, baseY - ext - headR, glR + 1);
            dc.fillCircle(cx + bodyW / 2 + 4, baseY + 2, glR - 1);
        } else if (_playerState == PS_JAB) {
            var ext = _playerStateTick < 3 ? _playerStateTick * 6 : 18 - (_playerStateTick - 3) * 5;
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, baseY - ext - headR, glR);
            dc.fillCircle(cx + bodyW / 2 + 4, baseY + 2, glR - 1);
        } else if (_playerState == PS_CROSS) {
            var ext = _playerStateTick < 3 ? _playerStateTick * 7 : 21 - (_playerStateTick - 3) * 5;
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + 3, baseY - ext - headR, glR);
            dc.fillCircle(cx - bodyW / 2 - 4, baseY + 2, glR - 1);
        } else if (_playerState == PS_HOOK) {
            var ext = _playerStateTick < 3 ? _playerStateTick * 5 : 15 - (_playerStateTick - 3) * 4;
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + ext, baseY - headR * 2 - ext / 3, glR + 1);
            dc.fillCircle(cx - bodyW / 2 - 4, baseY + 2, glR - 1);
        } else if (_playerState == PS_UPPER) {
            var ext = _playerStateTick < 3 ? _playerStateTick * 8 : 24 - (_playerStateTick - 3) * 6;
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, baseY - ext - headR * 2, glR + 1);
            dc.fillCircle(cx + bodyW / 2 + 3, baseY + 3, glR - 1);
        } else if (_playerState == PS_BODY) {
            var ext = _playerStateTick < 3 ? _playerStateTick * 5 : 15 - (_playerStateTick - 3) * 4;
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 4, baseY - ext - headR / 2, glR);
            dc.fillCircle(cx + bodyW / 2 + 3, baseY - 1, glR - 1);
        } else if (_playerState == PS_BLOCK) {
            dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - bodyW / 3, headY + headR / 2, glR);
            dc.fillCircle(cx + bodyW / 3, headY + headR / 2, glR);
        } else if (_playerState == PS_EXHAUSTED) {
            dc.setColor(0x993333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - bodyW / 2 - 2, baseY + bodyH / 2, glR - 1);
            dc.fillCircle(cx + bodyW / 2 + 2, baseY + bodyH / 2, glR - 1);
            if (_playerStateTick % 8 < 4) {
                dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx - headR / 2, headY + headR + 2, 2);
                dc.fillCircle(cx + headR / 2 + 1, headY + headR + 3, 1);
            }
        } else {
            var bob = (_tick % 10 < 5) ? -1 : 1;
            dc.setColor((_stamina < 25) ? 0x993333 : 0xCC3333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - bodyW / 2 - 4, baseY - 3 + bob, glR);
            dc.fillCircle(cx + bodyW / 2 + 4, baseY - 3 - bob, glR);
        }
    }

    hidden function drawBloodParts(dc, ox, oy) {
        for (var i = 0; i < BLOOD_MAX; i++) {
            if (_bloodLife[i] <= 0) { continue; }
            var sz = (_bloodLife[i] > 16) ? 3 : ((_bloodLife[i] > 8) ? 2 : 1);
            var red = 0xAA0000 + (_bloodLife[i] * 0x050000);
            if (red > 0xFF0000) { red = 0xFF0000; }
            dc.setColor(red, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_bloodX[i] + ox, _bloodY[i] + oy, sz);
            if (sz > 1 && _bloodLife[i] < 12) { dc.setColor(0x660000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_bloodX[i] + ox, _bloodY[i] + oy + sz, 1); }
        }
    }

    hidden function drawSweatParts(dc, ox, oy) {
        for (var i = 0; i < 8; i++) {
            if (_sweatLife[i] <= 0) { continue; }
            dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_sweatX[i] + ox, _sweatY[i] + oy, 1);
        }
    }

    hidden function drawStarParts(dc, ox, oy) {
        for (var i = 0; i < 6; i++) {
            if (_starLife[i] <= 0) { continue; }
            dc.setColor((_starLife[i] % 4 < 2) ? 0xFFFF44 : 0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_starX[i] + ox - 1, _starY[i] + oy - 3, 2, 6);
            dc.fillRectangle(_starX[i] + ox - 3, _starY[i] + oy - 1, 6, 2);
        }
    }

    hidden function drawPops(dc, ox, oy) {
        for (var i = 0; i < 6; i++) {
            if (_dmgPopLife[i] <= 0) { continue; }
            var col = 0xFFFFFF;
            if (_dmgPopType[i] == 1) { col = 0xFFAA22; }
            else if (_dmgPopType[i] == 2) { col = 0xFF4444; }
            else if (_dmgPopType[i] == 3) { col = 0xFF6666; }
            else if (_dmgPopType[i] == 4) { col = 0xFFDD00; }
            var txt = "" + _dmgPopVal[i];
            if (_dmgPopType[i] == 2) { txt = txt + "!"; }
            if (_dmgPopType[i] == 4) { txt = txt + "!!"; }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_dmgPopX[i] + ox + 1, _dmgPopY[i] + oy + 1, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_dmgPopX[i] + ox, _dmgPopY[i] + oy, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawHUD(dc) {
        var barW = _w * 34 / 100;
        var barH = 10;
        var barY = 2;
        var gap = 2;

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 3 / 100, barY - 1, Graphics.FONT_XTINY, "YOU", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_w * 97 / 100, barY - 1, Graphics.FONT_XTINY, "OPP", Graphics.TEXT_JUSTIFY_RIGHT);

        var hpBarY = barY + 12;
        var pFill = (_playerHp.toFloat() / _playerMaxHp * barW).toNumber();
        if (pFill < 0) { pFill = 0; }
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 3 / 100, hpBarY, barW, barH);
        var pCol = 0x44CC44;
        if (_playerHp < _playerMaxHp / 4) { pCol = (_tick % 6 < 3) ? 0xFF2222 : 0xCC0000; }
        else if (_playerHp < _playerMaxHp / 2) { pCol = 0xFFAA22; }
        dc.setColor(pCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 3 / 100, hpBarY, pFill, barH);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_w * 3 / 100, hpBarY, barW, barH);
        dc.drawText(_w * 3 / 100 + barW / 2, hpBarY - 1, Graphics.FONT_XTINY, "" + _playerHp, Graphics.TEXT_JUSTIFY_CENTER);

        var eFill = (_enemyHp.toFloat() / _enemyMaxHp * barW).toNumber();
        if (eFill < 0) { eFill = 0; }
        var eBarX = _w * 97 / 100 - barW;
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(eBarX, hpBarY, barW, barH);
        var eCol = 0xCC4444;
        if (_enemyHp < _enemyMaxHp / 4) { eCol = (_tick % 6 < 3) ? 0xFF2222 : 0xAA0000; }
        dc.setColor(eCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(eBarX + barW - eFill, hpBarY, eFill, barH);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(eBarX, hpBarY, barW, barH);
        dc.drawText(eBarX + barW / 2, hpBarY - 1, Graphics.FONT_XTINY, "" + _enemyHp, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, hpBarY - 2, Graphics.FONT_XTINY, "R" + _round, Graphics.TEXT_JUSTIFY_CENTER);

        var sec = _roundTimer / 30;
        var timerCol = (sec <= 10) ? ((_tick % 8 < 4) ? 0xFF4444 : 0xCC2222) : 0xAABBCC;
        dc.setColor(timerCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, hpBarY + barH, Graphics.FONT_XTINY, "" + sec + "s", Graphics.TEXT_JUSTIFY_CENTER);

        var stBarY = hpBarY + barH + gap;
        var stW = _w * 34 / 100;
        var stX = _w * 3 / 100;
        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(stX, stBarY, stW, 5);
        var stFill = (_stamina * stW / _staminaMax);
        var stCol = 0x44AAFF;
        if (_stamina < 20) { stCol = (_tick % 6 < 3) ? 0xFF4422 : 0xCC3311; }
        else if (_stamina < 40) { stCol = 0xFF8844; }
        dc.setColor(stCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(stX, stBarY, stFill, 5);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(stX, stBarY, stW, 5);

        var eStW = _w * 34 / 100;
        var eStX = _w * 97 / 100 - eStW;
        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(eStX, stBarY, eStW, 5);
        var eStFill = (_enemyStamina * eStW / _enemyStaminaMax);
        var eStCol = 0xCC6644;
        if (_enemyStamina < _enemyStaminaMax / 4) { eStCol = 0xFF4422; }
        dc.setColor(eStCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(eStX + eStW - eStFill, stBarY, eStFill, 5);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(eStX, stBarY, eStW, 5);

        if (_comboMeter > 0) {
            var mW = _w * 40 / 100;
            var mX = (_w - mW) / 2;
            var mY = _h * 82 / 100;
            dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(mX, mY, mW, 4);
            var mFill = (_comboMeter * mW / 100);
            var mCol = (_comboMeter >= 100) ? ((_tick % 4 < 2) ? 0xFFDD00 : 0xFF4400) : ((_comboMeter >= 60) ? 0xFFAA22 : 0x4488FF);
            dc.setColor(mCol, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(mX, mY, mFill, 4);
            if (_comboMeter >= 100) {
                dc.setColor((_tick % 6 < 3) ? 0xFFDD00 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, mY + 4, Graphics.FONT_XTINY, "TAP: SUPER!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (_playerState == PS_EXHAUSTED) {
            dc.setColor((_tick % 6 < 3) ? 0xFF6622 : 0xCC4400, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "EXHAUSTED!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_playerState == PS_BLOCK) {
            dc.setColor(0x4488FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "BLOCK", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_playerState == PS_DODGE_L || _playerState == PS_DODGE_R) {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "DODGE!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_stamina < 25 && gameState == GS_FIGHT) {
            dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "LOW STAMINA", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_enemyState == ES_WINDUP && _enemyStateTick > 1) {
            if (_tick % 4 < 2) {
                dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 18 / 100, Graphics.FONT_XTINY, "!! WARNING !!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(5, _h - 12, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x0A0A14, 0x0A0A14); dc.clear();
        dc.setColor(0x1A1A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 72 / 100, _w, _h * 28 / 100);
        dc.setColor(0x330808, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _w; i += 4) { dc.fillRectangle(i, _h * 72 / 100 - (3 + (i * 7 + 13) % 5), 3, 3 + (i * 7 + 13) % 5); }

        drawMenuBoxer(dc, _w * 22 / 100, _h * 48 / 100, 0xDD4444, true);
        drawMenuBoxer(dc, _w * 78 / 100, _h * 48 / 100, 0x4444DD, false);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 36 / 100, _h * 40 / 100, _w * 28 / 100, 2);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 42 / 100, Graphics.FONT_XTINY, "VS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 36 / 100, _h * 50 / 100, _w * 28 / 100, 2);

        var pulse = (_tick % 16 < 8) ? 0xFF4444 : 0xDD2222;
        dc.setColor(0x110000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, _h * 8 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 8 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 22 / 100, Graphics.FONT_MEDIUM, "BOXING", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 58 / 100, Graphics.FONT_XTINY, "Shake = punch", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 64 / 100, Graphics.FONT_XTINY, "Tilt = dodge", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestScore > 0) { dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 74 / 100, Graphics.FONT_XTINY, "Best: " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER); }
        if (_bestRound > 0) { dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 80 / 100, Graphics.FONT_XTINY, "Round " + _bestRound, Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor((_tick % 24 < 12) ? 0x44FF44 : 0x22AA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to fight", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawMenuBoxer(dc, cx, cy, col, left) {
        var hr = _w * 5 / 100;
        if (hr < 5) { hr = 5; }
        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy - hr * 2, hr);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx - hr, cy, hr * 2, hr * 3);
        var d = left ? 1 : -1;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + d * hr * 2, cy - hr, hr * 3 / 4);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(left ? cx + 1 : cx - 1, cy - hr * 2 - 1, 1);
    }

    hidden function drawIntro(dc) {
        dc.setColor(0x0A0A14, 0x0A0A14); dc.clear();
        dc.setColor(0x332211, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 55 / 100, _w, _h * 45 / 100);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 8 / 100, Graphics.FONT_MEDIUM, "ROUND " + _round, Graphics.TEXT_JUSTIFY_CENTER);

        var names = ["ROOKIE JOE", "IRON MIKE", "MAD BULL", "SHADOW", "CHAMPION", "VIPER", "TITAN", "NIGHTMARE"];
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 26 / 100, Graphics.FONT_SMALL, names[_enemyFace % 8], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 38 / 100, Graphics.FONT_XTINY, "HP " + _enemyMaxHp + "  DMG " + _enemyDmg, Graphics.TEXT_JUSTIFY_CENTER);

        var spdLabel = "SLOW";
        if (_enemySpeed > 2.2) { spdLabel = "INSANE"; }
        else if (_enemySpeed > 1.6) { spdLabel = "FAST"; }
        else if (_enemySpeed > 1.0) { spdLabel = "NORMAL"; }
        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 46 / 100, Graphics.FONT_XTINY, "SPD: " + spdLabel, Graphics.TEXT_JUSTIFY_CENTER);

        if (_introTick > 15) {
            dc.setColor((_introTick % 6 < 3) ? 0xFF4444 : 0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 58 / 100, Graphics.FONT_LARGE, "FIGHT!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var barY = _h * 78 / 100; var barW = _w * 60 / 100; var barX = (_w - barW) / 2;
        var fill = (_introTick * barW / 50); if (fill > barW) { fill = barW; }
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(barX, barY, barW, 5);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(barX, barY, fill, 5);
    }

    hidden function drawKO(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 35 / 100, _w, _h * 30 / 100);
        dc.setColor((_koTick % 6 < 3) ? 0xFF2222 : 0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 38 / 100, Graphics.FONT_LARGE, "K.O.!", Graphics.TEXT_JUSTIFY_CENTER);
        if (_koTick > 25) {
            var count = 10 - (_koTick - 25) / 4; if (count < 1) { count = 1; }
            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 52 / 100, Graphics.FONT_MEDIUM, "" + count, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawWin(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 22 / 100, _w, _h * 60 / 100);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 24 / 100, Graphics.FONT_LARGE, "YOU WIN!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 38 / 100, Graphics.FONT_SMALL, "Round " + _round, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_XTINY, "Hits " + _totalHits + " Counters " + _perfectHits, Graphics.TEXT_JUSTIFY_CENTER);
        if (_maxCombo >= 3) { dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 55 / 100, Graphics.FONT_XTINY, "Combo x" + _maxCombo, Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 63 / 100, Graphics.FONT_SMALL, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 20 < 10) ? 0x44FF44 : 0x22AA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 72 / 100, Graphics.FONT_XTINY, "Tap: next round", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawLose(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 22 / 100, _w, _h * 60 / 100);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 24 / 100, Graphics.FONT_LARGE, "DEFEATED", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 38 / 100, Graphics.FONT_SMALL, "Round " + _round, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_XTINY, "Hits " + _totalHits + " Score " + _score, Graphics.TEXT_JUSTIFY_CENTER);
        if (_bestScore > 0) { dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 56 / 100, Graphics.FONT_XTINY, "Best " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER); }
        if (_bestRound > 0) { dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 63 / 100, Graphics.FONT_XTINY, "Best Round " + _bestRound, Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor((_tick % 20 < 10) ? 0xFF8844 : 0xBB6622, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 72 / 100, Graphics.FONT_XTINY, "Tap to play again", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
