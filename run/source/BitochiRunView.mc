using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application as App;
using Toybox.Application.Storage as BrStore;

enum {
    RS_MENU,
    RS_INTRO,
    RS_SCAN,
    RS_FOUND,
    RS_RUN,
    RS_CAUGHT,
    RS_ESCAPE,
    RS_LEVELS
}

class BitochiRunView extends WatchUi.View {

    var gameState;
    var accelX;
    var accelY;
    var accelZ;
    var shakeMag;

    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;

    hidden var _timer;
    hidden var _tick;

    hidden var _level;
    hidden var _maxLevels;

    // scan
    hidden var _exitAngle;
    hidden var _scanAngle;
    hidden var _scanRadius;
    hidden var _scanFound;
    hidden var _scanTimer;
    hidden var _scanHintTick;
    hidden var _scanPhaseTicks;
    hidden var _scanMaxTicks;
    hidden var _footstepPhase;
    hidden var _jumpScareLife;
    hidden var _jumpScareX;
    hidden var _jumpScareY;
    hidden var _trapFocusTicks;
    hidden var _trapAngleIdx;

    hidden var _decoyAngles;
    hidden var _trapAngles;
    hidden var _decoyCount;
    hidden var _trapCount;
    hidden var _lightCount;
    hidden var _lightAngles;
    hidden var _lightIsTrap;

    // run
    hidden var _playerDist;
    hidden var _exitDist;
    hidden var _monsterDist;
    hidden var _monsterSpeed;
    hidden var _monsterBaseSpeed;
    hidden var _playerSpeed;
    hidden var _runShake;
    hidden var _heartbeatTick;
    hidden var _vibeInterval;
    hidden var _lastVibeTick;
    hidden var _runTicks;
    hidden var _stamina;
    hidden var _shieldActive;
    hidden var _boostTicks;
    hidden var _scratchVibeTick;
    hidden var _lungeWarn;
    hidden var _lungeBurst;
    hidden var _monsterWobble;
    hidden var _tauntFreeze;
    hidden var _dzikkoBurst;
    hidden var _emilkaSpike;

    hidden var _dodgeLane;
    hidden var _nextObstacleDist;
    hidden var _obstacleOpenLane;
    hidden var _obstacleWidth;

    hidden var _footprintsX;
    hidden var _footprintsY;
    hidden var _footprintLife;

    hidden var _eyeTrailX;
    hidden var _eyeTrailY;
    hidden var _eyeTrailAge;

    hidden var _dripX;
    hidden var _dripY;
    hidden var _dripSpd;

    hidden var _particles;
    hidden var _flashAlpha;
    hidden var _introTick;
    hidden var _introMsg;

    hidden var _monsterNames;
    hidden var _monsterColors;
    hidden var _monsterIdx;

    hidden var _survived;
    hidden var _totalDist;
    hidden var _levelRunScore;
    hidden var _sessionScore;
    hidden var _highScore;

    hidden var _betweenLevelLines;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());

        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _cx = _w / 2;
        _cy = _h / 2;

        _monsterNames = ["SKINWALKER", "THE HIVE", "GRINDER", "CRAWLMOUTH", "EYEFATHER", "BONEWIDOW", "GUTSPILL"];
        _monsterColors = [0xCC1111, 0x66AA22, 0x992222, 0x886644, 0xAA33FF, 0xCCBB88, 0x881133];

        _particles = new [40];
        for (var i = 0; i < 40; i++) {
            _particles[i] = [
                Math.rand().abs() % _w,
                Math.rand().abs() % _h,
                1 + Math.rand().abs() % 3
            ];
        }

        _dripX = new [24];
        _dripY = new [24];
        _dripSpd = new [24];
        for (var di = 0; di < 24; di++) {
            _dripX[di] = Math.rand().abs() % _w;
            _dripY[di] = -(Math.rand().abs() % _h);
            _dripSpd[di] = 1 + Math.rand().abs() % 5;
        }

        _footprintsX = new [10];
        _footprintsY = new [10];
        _footprintLife = new [10];
        for (var fi = 0; fi < 10; fi++) {
            _footprintsX[fi] = 0;
            _footprintsY[fi] = 0;
            _footprintLife[fi] = 0;
        }

        _eyeTrailX = new [5];
        _eyeTrailY = new [5];
        _eyeTrailAge = new [5];
        for (var ei = 0; ei < 5; ei++) {
            _eyeTrailX[ei] = 0;
            _eyeTrailY[ei] = 0;
            _eyeTrailAge[ei] = 0;
        }

        _betweenLevelLines = [
            "Something wears skin",
            "Walls are pulsating",
            "It eats from inside",
            "A mouth in the dark",
            "Eyes. Everywhere.",
            "Bones snap behind you",
            "The floor is warm..."
        ];

        _tick = 0;
        _level = 0;
        _maxLevels = 12;
        _survived = 0;
        _totalDist = 0.0;
        _sessionScore = 0;
        _highScore = loadHighScore();

        accelX = 0;
        accelY = 0;
        accelZ = 0;
        shakeMag = 0;
        _dodgeLane = 1;

        gameState = RS_MENU;
    }

    hidden function loadHighScore() {
        var v = BrStore.getValue("br_hs");
        if (v != null) { return v; }
        return 0;
    }

    hidden function saveHighScore(sc) {
        if (sc <= _highScore) { return; }
        _highScore = sc;
        BrStore.setValue("br_hs", sc);
    }

    function inRunPhase() {
        return gameState == RS_RUN;
    }

    function nudgeDodge(dir) {
        if (gameState != RS_RUN) { return; }
        _dodgeLane = _dodgeLane + dir;
        if (_dodgeLane < 0) { _dodgeLane = 0; }
        if (_dodgeLane > 2) { _dodgeLane = 2; }
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
        updateParticles();
        updateDrips();

        if (gameState == RS_INTRO) {
            _introTick++;
            if (_introTick >= 60) {
                startScan();
            }
        } else if (gameState == RS_SCAN) {
            updateScan();
        } else if (gameState == RS_FOUND) {
            _scanTimer++;
            if (_scanTimer >= 30) {
                startRun();
            }
        } else if (gameState == RS_RUN) {
            updateRun();
        } else if (gameState == RS_CAUGHT) {
            _introTick++;
        } else if (gameState == RS_ESCAPE) {
            _introTick++;
        }

        WatchUi.requestUpdate();
    }

    hidden function updateParticles() {
        for (var i = 0; i < 40; i++) {
            var p = _particles[i];
            p[1] = p[1] + p[2];
            if (gameState == RS_RUN || gameState == RS_SCAN) {
                p[0] = p[0] + ((i % 2 == 0) ? 1 : -1);
            }
            if (p[1] > _h) { p[1] = 0; p[0] = Math.rand().abs() % _w; }
            if (p[0] < 0) { p[0] = _w - 1; }
            if (p[0] >= _w) { p[0] = 0; }
        }
    }

    hidden function updateDrips() {
        for (var i = 0; i < 24; i++) {
            _dripY[i] = _dripY[i] + _dripSpd[i];
            if (_dripY[i] > _h + 10) {
                _dripY[i] = -(Math.rand().abs() % 40);
                _dripX[i] = Math.rand().abs() % _w;
                _dripSpd[i] = 1 + Math.rand().abs() % 5;
            }
        }
    }

    hidden function drawBlood(dc, w, h, intensity) {
        var topDrips = 8 + intensity * 3;
        if (topDrips > 24) { topDrips = 24; }
        for (var i = 0; i < topDrips; i++) {
            if (_dripY[i] < 0) { continue; }
            var dw = 2 + (i % 3);
            var dh = 5 + _dripSpd[i] * 3 + intensity;
            var r = 0x550000 + (_dripSpd[i] * 0x110000);
            if (r > 0xBB0000) { r = 0xBB0000; }
            dc.setColor(r, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_dripX[i], _dripY[i], dw, dh);
            dc.setColor(0xDD0000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_dripX[i], _dripY[i] + dh - 3, dw + 1, 4);
            dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_dripX[i] + dw / 2, _dripY[i] + dh + 1, dw);
            if (i % 3 == 0 && intensity > 2) {
                dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_dripX[i] + dw / 2 + 2, _dripY[i] + dh + 3, 1);
            }
        }

        dc.setColor(0x440000, Graphics.COLOR_TRANSPARENT);
        for (var p = 0; p < 8 + intensity * 2; p++) {
            var px = ((_tick * 7 + p * 47) % w);
            var py = h - 2 - (p % 5);
            dc.fillRectangle(px, py, 3 + p % 6, 2 + p % 3);
        }
        if (intensity > 3) {
            dc.setColor(0x330000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w, 2);
            dc.fillRectangle(0, h - 2, w, 2);
        }
    }

    function startLevel() {
        _level++;
        _monsterIdx = (_level - 1) % _monsterNames.size();
        gameState = RS_INTRO;
        _introTick = 0;
        _introMsg = _betweenLevelLines[(_level - 1) % _betweenLevelLines.size()];
        _dodgeLane = 1;
    }

    hidden function buildScanLights() {
        _decoyCount = 2 + _level / 3;
        if (_decoyCount > 6) { _decoyCount = 6; }
        _trapCount = 1 + _level / 4;
        if (_trapCount > 4) { _trapCount = 4; }
        _lightCount = 1 + _decoyCount + _trapCount;

        _decoyAngles = new [_decoyCount];
        _trapAngles = new [_trapCount];
        _lightAngles = new [_lightCount];
        _lightIsTrap = new [_lightCount];

        var k;
        _lightAngles[0] = _exitAngle;
        _lightIsTrap[0] = false;

        for (k = 0; k < _decoyCount; k++) {
            var da = _exitAngle + 40.0 + (Math.rand().abs() % 280).toFloat();
            if (da >= 360.0) { da -= 360.0; }
            _decoyAngles[k] = da;
            _lightAngles[1 + k] = da;
            _lightIsTrap[1 + k] = false;
        }

        for (k = 0; k < _trapCount; k++) {
            var ta = _exitAngle + 100.0 + (Math.rand().abs() % 160).toFloat() + (k * 70.0).toFloat();
            if (ta >= 360.0) { ta -= 360.0; }
            _trapAngles[k] = ta;
            _lightAngles[1 + _decoyCount + k] = ta;
            _lightIsTrap[1 + _decoyCount + k] = true;
        }
    }

    hidden function startScan() {
        gameState = RS_SCAN;
        _exitAngle = (Math.rand().abs() % 360).toFloat();
        _scanAngle = 0.0;
        _scanRadius = 0.0;
        _scanFound = false;
        _scanTimer = 0;
        _scanHintTick = 0;
        _scanPhaseTicks = 0;
        _scanMaxTicks = 550 - _level * 12;
        if (_scanMaxTicks < 300) { _scanMaxTicks = 300; }
        _footstepPhase = 0;
        _jumpScareLife = 0;
        _trapFocusTicks = 0;
        _trapAngleIdx = -1;
        _flashAlpha = 0;

        buildScanLights();
    }

    hidden function angleDiff(a, b) {
        var d = a - b;
        if (d < 0.0) { d = -d; }
        if (d > 180.0) { d = 360.0 - d; }
        return d;
    }

    hidden function updateScan() {
        _scanPhaseTicks++;
        if (_scanPhaseTicks >= _scanMaxTicks) {
            gameState = RS_CAUGHT;
            _introTick = 0;
            doVibe(100, 800);
            return;
        }

        var rawAngle = Math.atan2(accelX.toFloat(), accelY.toFloat());
        _scanAngle = rawAngle * 180.0 / 3.14159;
        if (_scanAngle < 0.0) { _scanAngle += 360.0; }

        var diffExit = angleDiff(_scanAngle, _exitAngle);
        _scanRadius = diffExit;

        var onTrap = false;
        var bestTrapDiff = 999.0;
        var ti;
        for (ti = 0; ti < _trapCount; ti++) {
            var td = angleDiff(_scanAngle, _trapAngles[ti]);
            if (td < bestTrapDiff) { bestTrapDiff = td; }
            if (td < 18.0) {
                onTrap = true;
                _trapAngleIdx = ti;
            }
        }

        if (onTrap && bestTrapDiff < 18.0) {
            _trapFocusTicks++;
            if (_trapFocusTicks > 14 && _trapFocusTicks % 16 == 0) {
                _scanPhaseTicks = _scanPhaseTicks + 25;
                doVibe(50, 120);
            }
        } else {
            _trapFocusTicks = 0;
        }

        if (diffExit < 20.0 && !onTrap) {
            _scanHintTick++;
            if (_scanHintTick >= 15) {
                _scanFound = true;
                gameState = RS_FOUND;
                _scanTimer = 0;
                doVibe(80, 400);
            }
        } else {
            if (onTrap) {
            } else {
                _scanHintTick = 0;
            }
        }

        if (diffExit < 40.0 && _tick % 20 == 0 && !onTrap) {
            doVibe(30, 100);
        }

        _footstepPhase++;
        var urgency = _scanPhaseTicks.toFloat() / _scanMaxTicks.toFloat();
        if (urgency > 1.0) { urgency = 1.0; }
        var footInterval = (45.0 - urgency * 28.0).toNumber();
        if (footInterval < 12) { footInterval = 12; }
        if (_footstepPhase % footInterval == 0) {
            var fi = 40 + (urgency * 55.0).toNumber();
            if (fi > 100) { fi = 100; }
            doVibe(fi, 90 + (urgency * 60.0).toNumber());
        }

        if (_jumpScareLife > 0) {
            _jumpScareLife--;
        } else if (Math.rand().abs() % 170 == 0) {
            _jumpScareLife = 8;
            _jumpScareX = 20 + Math.rand().abs() % (_w - 40);
            _jumpScareY = 25 + Math.rand().abs() % (_h - 50);
            doVibe(90, 50);
        }

        if (Math.rand().abs() % 260 == 0) {
            var st = 15 + Math.rand().abs() % 35;
            doVibe(st, 25);
        }
    }

    hidden function startRun() {
        gameState = RS_RUN;
        _playerDist = 0.0;
        _exitDist = 62.0 + (_level * 10).toFloat() + (_level / 3 * 6).toFloat();
        _monsterDist = -24.0 - (_level * 4).toFloat();
        _monsterBaseSpeed = 0.48 + _level.toFloat() * 0.075 + (_level / 5).toFloat() * 0.04;
        if (_monsterBaseSpeed > 1.8) { _monsterBaseSpeed = 1.8; }
        _monsterSpeed = _monsterBaseSpeed;
        _playerSpeed = 0.0;
        _runShake = 0;
        _heartbeatTick = 0;
        _vibeInterval = 25;
        _lastVibeTick = 0;
        _runTicks = 0;
        _stamina = 100.0;
        _shieldActive = false;
        _boostTicks = 0;
        _scratchVibeTick = 0;
        _lungeWarn = 0;
        _lungeBurst = 0;
        _monsterWobble = 0.0;
        _tauntFreeze = 0;
        _dzikkoBurst = 0;
        _emilkaSpike = 0;
        _dodgeLane = 1;
        _nextObstacleDist = 12.0 + (Math.rand().abs() % 8).toFloat();
        _obstacleOpenLane = Math.rand().abs() % 3;
        _obstacleWidth = 10.0;
        _levelRunScore = 0;

        for (var ei = 0; ei < 5; ei++) {
            _eyeTrailAge[ei] = 0;
        }
        for (var fi = 0; fi < 10; fi++) {
            _footprintLife[fi] = 0;
        }
    }

    hidden function pushFootprint(px, py) {
        var i;
        for (i = 9; i > 0; i--) {
            _footprintsX[i] = _footprintsX[i - 1];
            _footprintsY[i] = _footprintsY[i - 1];
            _footprintLife[i] = _footprintLife[i - 1];
        }
        _footprintsX[0] = px;
        _footprintsY[0] = py;
        _footprintLife[0] = 18;
    }

    hidden function decayFootprints() {
        var i;
        for (i = 0; i < 10; i++) {
            if (_footprintLife[i] > 0) {
                _footprintLife[i] = _footprintLife[i] - 1;
            }
        }
    }

    hidden function pushEyeTrail(ex, ey) {
        var i;
        for (i = 4; i > 0; i--) {
            _eyeTrailX[i] = _eyeTrailX[i - 1];
            _eyeTrailY[i] = _eyeTrailY[i - 1];
            _eyeTrailAge[i] = _eyeTrailAge[i - 1];
        }
        _eyeTrailX[0] = ex;
        _eyeTrailY[0] = ey;
        _eyeTrailAge[0] = 6;
    }

    hidden function decayEyeTrail() {
        var i;
        for (i = 0; i < 5; i++) {
            if (_eyeTrailAge[i] > 0) {
                _eyeTrailAge[i] = _eyeTrailAge[i] - 1;
            }
        }
    }

    hidden function spawnPowerupNearObstacle() {
        var r = Math.rand().abs() % 100;
        if (r >= 22) { return; }
        if (r < 11) {
            _shieldActive = true;
        } else {
            _boostTicks = 80 + Math.rand().abs() % 50;
        }
    }

    hidden function applyMonsterBehavior() {
        var mi = _monsterIdx;

        if (mi == 0) {
            if (_tauntFreeze > 0) {
                _tauntFreeze--;
            } else if (Math.rand().abs() % 90 == 0) {
                _tauntFreeze = 22;
            }
        } else if (mi == 4) {
            _monsterWobble = (Math.rand().abs() % 7 - 3).toFloat() * 0.12;
        } else if (mi == 2) {
            if (_dzikkoBurst > 0) {
                _dzikkoBurst--;
            } else if (Math.rand().abs() % 70 == 0) {
                _dzikkoBurst = 18;
            }
        } else if (mi == 5) {
            if (_emilkaSpike > 0) {
                _emilkaSpike--;
            } else if (Math.rand().abs() % 100 == 0) {
                _emilkaSpike = 14;
            }
        } else if (mi == 6) {
            _monsterBaseSpeed = _monsterBaseSpeed + 0.0035;
        }

        if (mi == 3) {
            _monsterBaseSpeed = _monsterBaseSpeed + 0.002;
        }

        if (_monsterBaseSpeed > 2.0) {
            _monsterBaseSpeed = 2.0;
        }
    }

    hidden function monsterSpeedMultiplier() {
        var mi = _monsterIdx;
        var m = 1.0;

        if (mi == 0 && _tauntFreeze > 0) {
            return 0.0;
        }
        if (mi == 2 && _dzikkoBurst > 0) {
            m = m * 1.55;
        }
        if (mi == 3) {
            m = m * (0.75 + (_playerDist / _exitDist) * 0.5);
            if (m > 1.35) { m = 1.35; }
        }
        if (mi == 4) {
            m = m * (0.85 + (Math.rand().abs() % 40).toFloat() / 100.0);
        }
        if (mi == 5) {
            if (_emilkaSpike > 0) {
                m = m * 1.65;
            } else {
                m = m * 0.72;
            }
        }
        if (mi == 6) {
            m = m * 0.82;
        }

        if (_lungeBurst > 0) {
            m = m * 2.1;
        }

        return m;
    }

    hidden function updateRun() {
        _runTicks++;
        applyMonsterBehavior();

        if (_boostTicks > 0) {
            _boostTicks--;
        }

        var shakeBoost = shakeMag.toFloat() / 3000.0;
        if (shakeBoost > 2.8) { shakeBoost = 2.8; }

        var canSprint = _stamina > 4.0;
        if (!canSprint) {
            shakeBoost = 0.0;
        }

        _playerSpeed = _playerSpeed * 0.86;
        if (canSprint) {
            _playerSpeed += shakeBoost;
            _stamina = _stamina - (shakeBoost * 4.5 + 0.35);
        } else {
            _stamina = _stamina + 1.8;
        }

        if (_stamina < 0.0) { _stamina = 0.0; }
        if (_stamina > 100.0) { _stamina = 100.0; }

        var spdMult = 1.0;
        if (_boostTicks > 0) {
            spdMult = 1.45;
        }
        _playerSpeed = _playerSpeed * spdMult;

        if (_playerSpeed < 0.08) { _playerSpeed = 0.08; }

        _playerDist += _playerSpeed;

        var msm = monsterSpeedMultiplier();
        var monStep = _monsterBaseSpeed * msm;
        _monsterDist = _monsterDist + monStep + _monsterWobble;

        if (_monsterIdx != 6 && _monsterIdx != 3) {
            if (_monsterBaseSpeed < 1.65 + _level.toFloat() * 0.09) {
                _monsterBaseSpeed += 0.0045;
            }
        }

        if (_lungeWarn > 0) {
            _lungeWarn--;
            if (_lungeWarn == 0) {
                _lungeBurst = 14;
            }
        } else if (_lungeBurst > 0) {
            _lungeBurst--;
        } else if (Math.rand().abs() % 130 == 0 && _playerDist > 8.0) {
            _lungeWarn = 8;
            doVibeDouble();
        }

        if (_playerDist >= _nextObstacleDist) {
            if (_dodgeLane != _obstacleOpenLane) {
                if (_shieldActive) {
                    _shieldActive = false;
                    doVibe(60, 200);
                } else {
                    gameState = RS_CAUGHT;
                    _introTick = 0;
                    doVibe(100, 1000);
                    finalizeScore(false);
                    return;
                }
            }
            _nextObstacleDist = _playerDist + 14.0 + (Math.rand().abs() % 10).toFloat();
            _obstacleOpenLane = Math.rand().abs() % 3;
            spawnPowerupNearObstacle();
        }

        var gap = _playerDist - _monsterDist;
        if (gap < 60.0) {
            _vibeInterval = (gap * 0.42).toNumber();
            if (_vibeInterval < 3) { _vibeInterval = 3; }
        } else {
            _vibeInterval = 30;
        }

        _heartbeatTick++;
        if (_heartbeatTick >= _vibeInterval) {
            _heartbeatTick = 0;
            var intensity = 100 - (gap * 1.15).toNumber();
            if (intensity < 22) { intensity = 22; }
            if (intensity > 100) { intensity = 100; }
            doVibe(intensity, 150);
        }

        _scratchVibeTick++;
        if (_scratchVibeTick > 10 + Math.rand().abs() % 14) {
            _scratchVibeTick = 0;
            if (Math.rand().abs() % 2 == 0) {
                doVibe(25 + Math.rand().abs() % 30, 18);
            }
        }

        if (_monsterDist >= _playerDist) {
            if (_shieldActive) {
                _shieldActive = false;
                _monsterDist = _monsterDist - 8.0;
                doVibe(70, 250);
            } else {
                gameState = RS_CAUGHT;
                _introTick = 0;
                doVibe(100, 1000);
                finalizeScore(false);
                return;
            }
        }

        if (_playerDist >= _exitDist) {
            gameState = RS_ESCAPE;
            _introTick = 0;
            _survived++;
            _totalDist = _totalDist + _exitDist;
            finalizeScore(true);
            doVibe(60, 300);
        }

        var pyBase = _h * 55 / 100;
        var laneOff = (_dodgeLane - 1) * 14;
        pushFootprint(_w / 2 + (Math.rand().abs() % 5 - 2), pyBase + laneOff + (_tick % 4));
        decayFootprints();

        var gapy = _h * 55 / 100 + (gap * 0.45).toNumber();
        pushEyeTrail(_w / 2, gapy + 8);
        decayEyeTrail();
    }

    hidden function finalizeScore(escaped) {
        var timePts = _runTicks / 5;
        var distPts = _playerDist.toNumber() * 2;
        _levelRunScore = timePts + distPts;
        if (escaped) {
            _levelRunScore = _levelRunScore + 200;
        }
        _sessionScore = _sessionScore + _levelRunScore;
        saveHighScore(_sessionScore);
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }

    hidden function doVibeDouble() as Void {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([
                    new Toybox.Attention.VibeProfile(100, 45),
                    new Toybox.Attention.VibeProfile(100, 45)
                ]);
            }
        }
    }

    function doAction() {
        if (gameState == RS_MENU) {
            _sessionScore = 0;
            startLevel();
        } else if (gameState == RS_SCAN) {
        } else if (gameState == RS_CAUGHT) {
            _level = 0;
            _survived = 0;
            _totalDist = 0.0;
            _sessionScore = 0;
            startLevel();
        } else if (gameState == RS_ESCAPE) {
            if (_level >= _maxLevels) {
                gameState = RS_LEVELS;
                _introTick = 0;
            } else {
                startLevel();
            }
        } else if (gameState == RS_LEVELS) {
            _level = 0;
            _survived = 0;
            _totalDist = 0.0;
            _sessionScore = 0;
            gameState = RS_MENU;
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x000000, 0x000000);
        dc.clear();

        if (gameState == RS_MENU) { drawMenu(dc, w, h); return; }
        if (gameState == RS_INTRO) { drawIntro(dc, w, h); return; }
        if (gameState == RS_SCAN) { drawScanScene(dc, w, h); return; }
        if (gameState == RS_FOUND) { drawFoundScene(dc, w, h); return; }
        if (gameState == RS_RUN) { drawRunScene(dc, w, h); return; }
        if (gameState == RS_CAUGHT) { drawCaughtScene(dc, w, h); return; }
        if (gameState == RS_ESCAPE) { drawEscapeScene(dc, w, h); return; }
        if (gameState == RS_LEVELS) { drawFinalScene(dc, w, h); return; }
    }

    hidden function drawDust(dc, w, h, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 40; i++) {
            var p = _particles[i];
            dc.fillRectangle(p[0], p[1], p[2], p[2]);
        }
    }

    hidden function drawPulsingDarkness(dc, w, h, alphaScale) {
        var pulse = ((_tick / 3) % 20);
        if (pulse > 10) { pulse = 20 - pulse; }
        var margin = 8 + pulse + alphaScale;
        dc.setColor(0x020208, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, margin);
        dc.fillRectangle(0, h - margin, w, margin);
        dc.fillRectangle(0, 0, margin, h);
        dc.fillRectangle(w - margin, 0, margin, h);
    }

    hidden function drawWallScratches(dc, w, h) {
        dc.setColor(0x1A1010, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var sx;
        for (sx = 0; sx < 5; sx++) {
            var x0 = 3 + sx * 7;
            var y0 = h * 20 / 100 + (sx * 13) % (h / 2);
            dc.drawLine(x0, y0, x0 + 4, y0 + 10);
            dc.drawLine(w - x0, y0 + 5, w - x0 - 3, y0 + 14);
        }
        dc.setPenWidth(1);
    }

    hidden function drawBrokenBits(dc, w, h) {
        dc.setColor(0x332222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w * 8 / 100, h * 70 / 100, 5, 3);
        dc.fillRectangle(w * 88 / 100, h * 62 / 100, 4, 6);
        dc.setColor(0x221818, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(w * 10 / 100, h * 72 / 100, w * 14 / 100, h * 74 / 100);
    }

    hidden function drawStoneBg(dc, w, h) {
        dc.setColor(0x080706, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h);
        dc.setColor(0x0D0B09, Graphics.COLOR_TRANSPARENT);
        var r;
        var bx;
        var by;
        for (r = 0; r < 12; r++) {
            bx = (r * 31 + 7) % (w - 16);
            by = (r * 41 + 15) % (h - 12);
            dc.drawRectangle(bx, by, 12 + r % 6, 7 + r % 4);
        }
        dc.setColor(0x100E0C, Graphics.COLOR_TRANSPARENT);
        for (r = 0; r < 8; r++) {
            bx = (r * 43 + 20) % (w - 12);
            by = (r * 37 + 5) % (h - 10);
            dc.fillRectangle(bx, by, 10 + r % 5, 6 + r % 3);
        }
        dc.setColor(0x060504, Graphics.COLOR_TRANSPARENT);
        var c;
        for (c = 0; c < 6; c++) {
            bx = (c * 47 + 12) % w;
            by = (c * 59 + 8) % h;
            dc.drawLine(bx, by, bx + 5 + c, by + 2 + c % 3);
        }
    }

    hidden function drawCorridorBg(dc, w, h) {
        var vx = w / 2;
        var vy = h * 22 / 100;
        dc.setColor(0x040305, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, vy + 5);
        var y;
        var t;
        var wallW;
        for (y = vy; y < h; y += 6) {
            t = (y - vy).toFloat() / (h - vy).toFloat();
            wallW = (t * w * 15 / 100).toNumber() + 1;
            dc.setColor(0x0C0A09 + ((y / 12) % 3) * 0x010101, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, y, wallW, 6);
        }
        for (y = vy; y < h; y += 6) {
            t = (y - vy).toFloat() / (h - vy).toFloat();
            wallW = (t * w * 15 / 100).toNumber() + 1;
            dc.setColor(0x0C0A09 + ((y / 12) % 3) * 0x010101, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(w - wallW, y, wallW, 6);
        }
        dc.setColor(0x1A1510, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(0, h, vx - 2, vy);
        dc.drawLine(w, h, vx + 2, vy);
        dc.setPenWidth(1);
        dc.setColor(0x0F0D0B, Graphics.COLOR_TRANSPARENT);
        var i;
        for (i = -3; i <= 3; i++) {
            dc.drawLine(vx, vy, vx + i * w / 4, h);
        }
        dc.setColor(0x0B0908, Graphics.COLOR_TRANSPARENT);
        var by = vy + 12;
        var step = 5;
        var b;
        var prog;
        var lx;
        for (b = 0; b < 7; b++) {
            if (by >= h) { break; }
            prog = (by - vy).toFloat() / (h - vy).toFloat();
            lx = ((1.0 - prog) * vx * 0.9).toNumber();
            dc.drawLine(lx, by, w - lx, by);
            step = step + 3 + b * 2;
            by = by + step;
        }
        dc.setColor(0x161310, Graphics.COLOR_TRANSPARENT);
        var s;
        var sy;
        var sx;
        for (s = 0; s < 4; s++) {
            sy = vy + 20 + s * (h - vy) / 4;
            sx = 2 + s * 3;
            dc.drawRectangle(sx, sy, 8 + s * 2, 5 + s);
            dc.drawRectangle(w - sx - 10 - s * 2, sy + 10, 8 + s * 2, 5 + s);
        }
    }

    hidden function drawTorch(dc, x, y) {
        dc.setColor(0x443322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 1, y + 3, 3, 6);
        dc.fillRectangle(x - 3, y + 8, 7, 2);
        var fOff = (_tick % 3) - 1;
        dc.setColor(0x1A0C00, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 10 + (_tick % 2));
        dc.setColor(0xFF6600, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + fOff, y + 1, 3);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + fOff, y, 2);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + fOff, y - 1, 1, 2);
    }

    hidden function drawFogWisps(dc, w, h) {
        var f;
        var fy;
        var fx;
        var fw;
        for (f = 0; f < 5; f++) {
            fy = h * 65 / 100 + f * h * 6 / 100;
            fx = (_tick * (f + 1) / 2 + f * 43) % (w + 60) - 30;
            fw = 20 + f * 14;
            dc.setColor(0x0D0F11 + f * 0x010101, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx, fy, fw, 2 + f / 2);
            dc.fillRectangle(fx + 8, fy - 1, fw / 2, 1);
        }
    }

    hidden function drawStarSky(dc, w, h) {
        dc.setColor(0x000208, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h * 40 / 100);
        dc.setColor(0x000510, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 40 / 100, w, h * 20 / 100);
        dc.setColor(0x000308, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 60 / 100, w, h * 10 / 100);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var s;
        var stx;
        var sty;
        for (s = 0; s < 15; s++) {
            stx = (s * 37 + 13) % w;
            sty = (s * 23 + 7) % (h * 55 / 100);
            dc.fillRectangle(stx, sty, 1, 1);
        }
        dc.setColor(0xCCDDFF, Graphics.COLOR_TRANSPARENT);
        for (s = 0; s < 4; s++) {
            stx = (s * 53 + 25) % w;
            sty = (s * 31 + 10) % (h * 40 / 100);
            dc.fillRectangle(stx, sty, 2, 2);
        }
        var twinkle = (_tick % 8);
        if (twinkle < 3) {
            stx = (twinkle * 71 + 40) % w;
            sty = (twinkle * 43 + 15) % (h * 40 / 100);
            dc.setColor(0xFFFFDD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(stx - 1, sty, 3, 1);
            dc.fillRectangle(stx, sty - 1, 1, 3);
        }
        dc.setColor(0xDDDDAA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 75 / 100, h * 15 / 100, 12);
        dc.setColor(0xBBBB88, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 75 / 100 + 3, h * 15 / 100 - 2, 10);
        dc.setColor(0x000208, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 75 / 100 + 6, h * 15 / 100 - 3, 10);
        dc.setColor(0x050505, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 68 / 100, w, h * 32 / 100);
        var tt;
        var tx;
        for (tt = 0; tt < 6; tt++) {
            tx = tt * w / 5;
            dc.fillCircle(tx, h * 68 / 100 + 1 - (tt * 3 + 2) % 8, 5 + tt % 3);
        }
        dc.setColor(0x040404, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w * 20 / 100, h * 58 / 100, 3, h * 10 / 100);
        dc.fillCircle(w * 20 / 100 + 1, h * 56 / 100, 6);
        dc.fillRectangle(w * 60 / 100, h * 60 / 100, 3, h * 8 / 100);
        dc.fillCircle(w * 60 / 100 + 1, h * 58 / 100, 5);
    }

    hidden function drawMenu(dc, w, h) {
        drawStoneBg(dc, w, h);
        drawDust(dc, w, h, 0x0A0006);

        var aw = w * 38 / 100;
        var ah = h * 36 / 100;
        var ax = (w - aw) / 2;
        var ay = h * 28 / 100;

        dc.setColor(0x1A1614, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ax - 5, ay - 4, aw + 10, 5);
        dc.fillRectangle(ax - 5, ay, 5, ah);
        dc.fillRectangle(ax + aw, ay, 5, ah);
        dc.setColor(0x141210, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ax - 3, ay + 2, 3, ah - 4);
        dc.fillRectangle(ax + aw, ay + 2, 3, ah - 4);
        dc.setColor(0x020102, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ax, ay, aw, ah);

        drawTorch(dc, ax - 14, ay + ah / 3);
        drawTorch(dc, ax + aw + 14, ay + ah / 3);

        drawFogWisps(dc, w, h);
        drawBlood(dc, w, h, 3);
        drawPulsingDarkness(dc, w, h, 6);

        var pulse = (_tick % 40 < 20) ? 0xFF0000 : 0xAA0000;
        dc.setColor(0x550000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + 1, h * 12 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + 1, h * 22 / 100 + 1, Graphics.FONT_MEDIUM, "RUN", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 22 / 100, Graphics.FONT_MEDIUM, "RUN", Graphics.TEXT_JUSTIFY_CENTER);

        drawMonsterEyes(dc, w / 2, ay + ah / 2, 0xFF0000, true);
        drawMonsterEyes(dc, ax + 10, ay + ah - 10, 0x880000, false);
        drawMonsterEyes(dc, ax + aw - 10, ay + ah - 10, 0x880000, false);

        dc.setColor(0x886655, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 68 / 100, Graphics.FONT_XTINY, "They hunger.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 75 / 100, Graphics.FONT_XTINY, "Find the exit.", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 83 / 100, Graphics.FONT_XTINY, "HI " + _highScore, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 89 / 100, Graphics.FONT_XTINY, "Tap to start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawIntro(dc, w, h) {
        drawStoneBg(dc, w, h);
        drawDust(dc, w, h, 0x0A0008);
        drawFogWisps(dc, w, h);
        drawPulsingDarkness(dc, w, h, 3);
        drawBlood(dc, w, h, _level);

        drawTorch(dc, w * 12 / 100, h * 38 / 100);
        drawTorch(dc, w * 88 / 100, h * 38 / 100);

        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_SMALL, "LEVEL " + _level, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x887766, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 26 / 100, Graphics.FONT_XTINY, _introMsg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_monsterColors[_monsterIdx], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 40 / 100, Graphics.FONT_SMALL, _monsterNames[_monsterIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x775544, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 54 / 100, Graphics.FONT_XTINY, "hungers for you...", Graphics.TEXT_JUSTIFY_CENTER);

        if (_introTick > 20) {
            drawMonsterSprite(dc, w / 2, h * 72 / 100, 16 + _introTick / 4);
            drawMonsterEyes(dc, w / 2, h * 68 / 100, _monsterColors[_monsterIdx], true);
        }
    }

    hidden function drawScanScene(dc, w, h) {
        drawStoneBg(dc, w, h);
        drawDarkness(dc, w, h);
        drawDust(dc, w, h, 0x0A0A12);
        drawPulsingDarkness(dc, w, h, 6);
        drawWallScratches(dc, w, h);
        var scanUrgency = _scanPhaseTicks * 4 / _scanMaxTicks;
        drawBlood(dc, w, h, scanUrgency);
        drawTorch(dc, w * 8 / 100, h * 20 / 100);
        drawTorch(dc, w * 92 / 100, h * 20 / 100);

        var flicker = (_tick % 7 < 5) ? 1 : 0;
        var dim = 0;
        if (Math.rand().abs() % 11 == 0) { dim = 1; }

        var diff = angleDiff(_scanAngle, _exitAngle);

        var radarR = w * 38 / 100;
        dc.setColor(0x0A1010, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, radarR);
        var ringC = 0x112211;
        if (diff < 25.0) { ringC = 0x113322; }
        else if (diff < 55.0) { ringC = 0x222211; }
        else { ringC = 0x221111; }
        dc.setColor(ringC, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, radarR);
        dc.drawCircle(_cx, _cy, radarR * 2 / 3);
        dc.drawCircle(_cx, _cy, radarR / 3);

        dc.setColor(0x0A1510, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx - radarR, _cy, _cx + radarR, _cy);
        dc.drawLine(_cx, _cy - radarR, _cx, _cy + radarR);

        var rawAngle = _scanAngle * 3.14159 / 180.0;
        var sweepFade = 0x0A1A0A;
        if (diff < 30.0) { sweepFade = 0x0A2A0A; }
        dc.setColor(sweepFade, Graphics.COLOR_TRANSPARENT);
        for (var sw = 1; sw <= 6; sw++) {
            var swA = rawAngle - sw.toFloat() * 0.08;
            var swx = _cx + (radarR * Math.sin(swA)).toNumber();
            var swy = _cy - (radarR * Math.cos(swA)).toNumber();
            dc.drawLine(_cx, _cy, swx, swy);
        }

        var jitter = (Math.rand().abs() % 9 - 4).toFloat() * 0.03;
        var beamAngle = rawAngle + jitter;
        var beamLen = radarR;
        if (dim == 1) { beamLen = beamLen * 3 / 4; }

        var bx = _cx + (beamLen * Math.sin(beamAngle)).toNumber();
        var by = _cy - (beamLen * Math.cos(beamAngle)).toNumber();

        var beamCol = (flicker == 1) ? 0x225533 : 0x1A3822;
        dc.setColor(beamCol, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(dim == 1 ? 2 : 4);
        dc.drawLine(_cx, _cy, bx, by);
        dc.setPenWidth(1);

        dc.setColor(0x33AA55, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx, _cy, bx, by);

        var glowCol = (flicker == 1) ? 0x44BB66 : 0x338844;
        dc.setColor(glowCol, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, dim == 1 ? 6 : 10);
        dc.setColor(0x55DD77, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, dim == 1 ? 3 : 5);

        var li;
        for (li = 0; li < _lightCount; li++) {
            var ang = _lightAngles[li];
            var isT = _lightIsTrap[li];
            var isReal = (li == 0);
            if (isReal) {
                var df = angleDiff(_scanAngle, _exitAngle);
                var br = df < 40.0;
                drawDoorIcon(dc, w, h, ang, br ? 0x44FF44 : 0x226622, true, false);
            } else if (isT) {
                drawDoorIcon(dc, w, h, ang, 0x662244, false, true);
            } else {
                drawDoorIcon(dc, w, h, ang, 0x442222, false, false);
            }
        }

        var pulse = (_tick % 10 < 5) ? 3 : 2;
        dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, pulse);
        dc.setColor(0xAAFFBB, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 1);

        var warmth = 0;
        if (diff < 40.0) {
            warmth = ((40.0 - diff) / 40.0 * 100.0).toNumber();
        }

        if (diff < 40.0) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_XTINY, "WARM " + warmth + "%", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (diff < 80.0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_XTINY, "COLD", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_XTINY, "FREEZING", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var remain = ((_scanMaxTicks - _scanPhaseTicks) / 20);
        if (remain < 0) { remain = 0; }
        dc.setColor(0xAA6666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 20 / 100, Graphics.FONT_XTINY, remain + "s", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x556655, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_XTINY, "Tilt to scan", Graphics.TEXT_JUSTIFY_CENTER);

        if (_jumpScareLife > 0) {
            drawMonsterEyes(dc, _jumpScareX, _jumpScareY, 0xFF0000, true);
        }
    }

    hidden function drawDoorIcon(dc, w, h, angle, color, real, trap) {
        var rad = angle * 3.14159 / 180.0;
        var doorR = w * 30 / 100;
        var dx = _cx + (doorR * Math.sin(rad)).toNumber();
        var dy = _cy - (doorR * Math.cos(rad)).toNumber();

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (real) {
            dc.fillRectangle(dx - 4, dy - 6, 8, 12);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dx - 2, dy - 4, 4, 8);
        } else if (trap) {
            dc.fillRectangle(dx - 4, dy - 6, 8, 12);
            dc.setColor(0xFF2266, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dx - 2, dy - 4, 4, 8);
        } else {
            dc.fillRectangle(dx - 3, dy - 5, 6, 10);
            dc.setColor(0x221111, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dx - 1, dy - 3, 2, 6);
        }
    }

    hidden function drawDarkness(dc, w, h) {
        dc.setColor(0x050510, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h * 8 / 100);
        dc.fillRectangle(0, h * 92 / 100, w, h * 8 / 100);
        dc.fillRectangle(0, 0, w * 5 / 100, h);
        dc.fillRectangle(w * 95 / 100, 0, w * 5 / 100, h);
    }

    hidden function drawFoundScene(dc, w, h) {
        drawStoneBg(dc, w, h);
        drawDust(dc, w, h, 0x0A0A12);
        drawFogWisps(dc, w, h);

        var doorX = w / 2;
        var doorY = h * 42 / 100;

        dc.setColor(0x0A2A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(doorX, doorY, 32);
        dc.setColor(0x061A06, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(doorX, doorY, 38);

        dc.setColor(0x113311, Graphics.COLOR_TRANSPARENT);
        var r;
        var ra;
        var rx;
        var ry;
        for (r = 0; r < 8; r++) {
            ra = (r * 45 + _scanTimer * 12).toFloat() * 3.14159 / 180.0;
            rx = doorX + (42 * Math.sin(ra)).toNumber();
            ry = doorY + (42 * Math.cos(ra)).toNumber();
            dc.drawLine(doorX, doorY, rx, ry);
        }

        dc.setColor(0x1A1614, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(doorX - 13, doorY - 17, 26, 34);
        dc.drawRectangle(doorX - 14, doorY - 18, 28, 36);
        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(doorX - 11, doorY - 15, 22, 30);
        dc.setColor(0xAAFFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(doorX - 7, doorY - 11, 14, 22);
        dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(doorX - 3, doorY - 5, 6, 10);

        drawTorch(dc, doorX - 28, doorY);
        drawTorch(dc, doorX + 28, doorY);

        var flash = (_scanTimer % 6 < 3) ? 0x44FF44 : 0x228822;
        dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 18 / 100, Graphics.FONT_SMALL, "EXIT FOUND!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_SMALL, "NOW RUN!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_XTINY, "Shake to run!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawRunScene(dc, w, h) {
        var tilt = (Math.sin(_tick.toFloat() / 4.8) * 3.0).toNumber();

        drawCorridorBg(dc, w, h);

        var gap = _playerDist - _monsterDist;
        var dangerLevel = 1.0 - (gap / 60.0);
        if (dangerLevel < 0.0) { dangerLevel = 0.0; }
        if (dangerLevel > 1.0) { dangerLevel = 1.0; }

        drawTorch(dc, w * 8 / 100 + tilt, h * 34 / 100);
        drawTorch(dc, w * 92 / 100 + tilt, h * 34 / 100);
        if (dangerLevel < 0.7) {
            drawTorch(dc, w * 5 / 100 + tilt, h * 58 / 100);
            drawTorch(dc, w * 95 / 100 + tilt, h * 58 / 100);
        }

        drawFogWisps(dc, w, h);
        drawDust(dc, w, h, 0x0A0A15);

        var edgeR = (dangerLevel * 95.0).toNumber();
        var redAmt = edgeR * 2;
        if (redAmt > 51) { redAmt = 51; }
        var redDeep = 0x220000 + redAmt * 0x10000;
        dc.setColor(redDeep, Graphics.COLOR_TRANSPARENT);
        var v;
        for (v = 0; v < 4; v++) {
            dc.drawRectangle(v, v, w - v * 2, h - v * 2);
        }

        drawPulsingDarkness(dc, w, h, 4 + (dangerLevel * 10.0).toNumber());
        drawBlood(dc, w, h, (dangerLevel * 6.0).toNumber());

        var progressPct = _playerDist / _exitDist;
        if (progressPct > 1.0) { progressPct = 1.0; }

        var doorSize = 4 + (progressPct * 22.0).toNumber();
        var doorY = h * 26 / 100 - (progressPct * h * 8 / 100).toNumber();
        if (progressPct > 0.3) {
            dc.setColor(0x0A1A0A, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(w / 2 + tilt, doorY + doorSize * 3 / 4, doorSize + 5);
        }
        dc.setColor(0x1A1614, Graphics.COLOR_TRANSPARENT);
        if (doorSize > 8) {
            dc.drawRectangle(w / 2 - doorSize / 2 - 1 + tilt, doorY - 1, doorSize + 2, doorSize * 3 / 2 + 2);
        }
        dc.setColor(0x226622, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - doorSize / 2 + tilt, doorY, doorSize, doorSize * 3 / 2);
        dc.setColor(0x88FF88, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w / 2 - doorSize / 4 + tilt, doorY + doorSize / 4, doorSize / 2, doorSize);

        var obsScreen = ((_nextObstacleDist - _playerDist) * 8.0).toNumber();
        if (obsScreen > -5 && obsScreen < h) {
            var ox = w / 2 + tilt;
            var oy = h * 40 / 100 - obsScreen / 2;
            var lane;
            for (lane = 0; lane < 3; lane++) {
                if (lane != _obstacleOpenLane) {
                    var ly2 = oy + lane * 12;
                    dc.setColor(0x332211, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(ox - 40, ly2, 80, 8);
                    dc.setColor(0x221808, Graphics.COLOR_TRANSPARENT);
                    dc.drawRectangle(ox - 38, ly2 + 1, 36, 6);
                    dc.drawRectangle(ox + 2, ly2 + 1, 36, 6);
                }
            }
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ox - 6, oy + _obstacleOpenLane * 12 + 2, 12, 4);
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ox - 2, oy + _obstacleOpenLane * 12 + 3, 4, 2);
        }

        var fp;
        for (fp = 0; fp < 10; fp++) {
            if (_footprintLife[fp] > 0) {
                var alpha = _footprintLife[fp];
                dc.setColor(0x223344 + alpha * 0x010101, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_footprintsX[fp], _footprintsY[fp], 2, 2);
            }
        }

        var playerY = h * 55 / 100 + (_dodgeLane - 1) * 14;
        var bounce = (_tick % 6 < 3) ? -2 : 2;
        if (_playerSpeed < 0.25) { bounce = 0; }
        drawPlayerSprite(dc, w / 2 + tilt, playerY + bounce);

        var monsterScreenY = playerY + 10;
        var monsterScreenX = w / 2 + tilt;
        if (gap < 52.0) {
            var monSize = (6.0 + (52.0 - gap) * 0.38).toNumber();
            if (monSize > 26) { monSize = 26; }
            var monY2 = monsterScreenY + (gap * 0.48).toNumber();
            drawMonsterSprite(dc, monsterScreenX, monY2, monSize);
        }

        var et;
        for (et = 4; et >= 0; et--) {
            if (_eyeTrailAge[et] > 0) {
                var tr = _eyeTrailAge[et];
                var ec = _monsterColors[_monsterIdx];
                if (tr < 3) {
                    ec = 0xFF6644;
                } else if (tr < 5) {
                    ec = 0xAA4433;
                } else {
                    ec = 0x553322;
                }
                dc.setColor(ec, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(_eyeTrailX[et], _eyeTrailY[et] - et * 3, 2 + tr / 3);
            }
        }

        drawMonsterEyes(dc, monsterScreenX, monsterScreenY + (gap * 0.4).toNumber() + 10, _monsterColors[_monsterIdx], true);

        if (_shieldActive) {
            dc.setColor(0x22FF66, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(w / 2 - 18 + tilt, playerY - 14, 36, 32);
            dc.drawRectangle(w / 2 - 17 + tilt, playerY - 13, 34, 30);
        }
        if (_boostTicks > 0) {
            dc.setColor(0x2288FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 75 / 100, h * 40 / 100, Graphics.FONT_XTINY, "BOOST", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var barW = w * 50 / 100;
        var barX = (w - barW) / 2;
        var barY = h * 12 / 100;
        dc.setColor(0x111118, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX - 1, barY - 1, barW + 2, 8);
        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, 6);
        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        var fillW = (barW * progressPct).toNumber();
        dc.fillRectangle(barX, barY, fillW, 6);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        var monPct = (_monsterDist / _exitDist);
        if (monPct < 0.0) { monPct = 0.0; }
        if (monPct > 1.0) { monPct = 1.0; }
        var monMarker = barX + (barW * monPct).toNumber();
        dc.fillRectangle(monMarker - 1, barY - 2, 3, 10);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, barY + 8, Graphics.FONT_XTINY, (_exitDist - _playerDist).toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        var stW = w * 50 / 100;
        var stX = (w - stW) / 2;
        var stY = h * 80 / 100;
        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(stX, stY, stW, 5);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(stX, stY, (stW * _stamina / 100.0).toNumber(), 5);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(stX - 2, stY - 2, Graphics.FONT_XTINY, "STA", Graphics.TEXT_JUSTIFY_RIGHT);

        var spdPct = _playerSpeed / 2.8;
        if (spdPct > 1.0) { spdPct = 1.0; }
        var spdBarW = w * 50 / 100;
        var spdBarX = (w - spdBarW) / 2;
        var spdBarY = h * 88 / 100;
        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(spdBarX, spdBarY, spdBarW, 4);
        var spdC = spdPct > 0.6 ? 0x44CCFF : (spdPct > 0.3 ? 0xFFCC22 : 0xFF4444);
        dc.setColor(spdC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(spdBarX, spdBarY, (spdBarW * spdPct).toNumber(), 4);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(spdBarX - 2, spdBarY - 2, Graphics.FONT_XTINY, "SPD", Graphics.TEXT_JUSTIFY_RIGHT);

        if (_lungeWarn > 0) {
            dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_SMALL, "!!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_vibeInterval < 8) {
            var hFlash = (_tick % 4 < 2) ? 0xFF2222 : 0x880000;
            dc.setColor(hFlash, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 88 / 100, h * 45 / 100, Graphics.FONT_XTINY, "<3", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawPlayerSprite(dc, x, y) {
        dc.setColor(0x060606, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y + 11, 5);

        dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - 7, 5);
        dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 4, y - 12, 8, 3);
        dc.fillRectangle(x - 5, y - 11, 2, 4);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 3, y - 8, 2, 2);
        dc.fillRectangle(x + 1, y - 8, 2, 2);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 2, y - 7, 1, 1);
        dc.fillRectangle(x + 2, y - 7, 1, 1);

        dc.setColor(0x3388DD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 5, y - 2, 10, 7);
        dc.setColor(0x2266BB, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 4, y - 1, 8, 5);
        dc.setColor(0xAAAA88, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y - 1, 1, 5);

        var armSwing = (_tick % 8 < 4) ? 3 : -3;
        dc.setColor(0x3388DD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 7, y - 1 + armSwing, 2, 5);
        dc.fillRectangle(x + 5, y - 1 - armSwing, 2, 5);
        dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 7, y + 4 + armSwing, 2, 2);
        dc.fillRectangle(x + 5, y + 4 - armSwing, 2, 2);

        var legOff = (_tick % 6 < 3) ? 2 : -2;
        dc.setColor(0x334466, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 3 + legOff, y + 5, 3, 5);
        dc.fillRectangle(x + legOff, y + 5, 3, 5);
        dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 4 + legOff, y + 10, 4, 2);
        dc.fillRectangle(x + legOff, y + 10, 4, 2);

        if (_playerSpeed > 1.0) {
            dc.setColor(0x446688, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 8, y - 1, 3, 1);
            dc.fillRectangle(x + 10, y + 2, 2, 1);
            dc.fillRectangle(x + 7, y + 4, 4, 1);
        }
        if (_playerSpeed > 2.0) {
            dc.setColor(0x6688AA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 12, y, 4, 1);
            dc.fillRectangle(x + 11, y + 3, 3, 1);
        }
    }

    hidden function drawMonsterSprite(dc, x, y, sz) {
        var mc = _monsterColors[_monsterIdx];
        var mi = _monsterIdx;
        var wobble = ((_tick % 6) < 3) ? 1 : -1;

        dc.setColor(0x220000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y + sz / 2, sz * 3 / 4);

        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + wobble, y, sz);

        dc.setColor(0x0A0205, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + wobble, y, sz - 2);

        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + wobble, y - sz / 4, sz * 6 / 10);

        var ts = sz / 4;
        if (ts < 2) { ts = 2; }
        dc.setColor(0xDDDDCC, Graphics.COLOR_TRANSPARENT);
        var mouthY = y + sz / 3;
        dc.fillRectangle(x - sz / 2, mouthY, ts, ts + 2);
        dc.fillRectangle(x - ts, mouthY + 1, ts, ts + 2);
        dc.fillRectangle(x + ts / 2, mouthY, ts, ts + 3);
        dc.fillRectangle(x + sz / 3, mouthY + 1, ts, ts + 1);
        if (sz > 12) {
            dc.fillRectangle(x - 1, mouthY, ts, ts + 4);
        }

        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - sz / 3, mouthY + ts, sz * 2 / 3, 2);

        var eyeOff = sz / 3;
        var eyeSz = sz / 4;
        if (eyeSz < 2) { eyeSz = 2; }
        var pupilSz = eyeSz / 2;
        if (pupilSz < 1) { pupilSz = 1; }

        dc.setColor(0xFFFF33, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - eyeOff + wobble, y - sz / 5, eyeSz);
        dc.fillCircle(x + eyeOff + wobble, y - sz / 5, eyeSz);
        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - eyeOff + wobble, y - sz / 5, pupilSz);
        dc.fillCircle(x + eyeOff + wobble, y - sz / 5, pupilSz);

        if (mi == 4 || mi == 1) {
            dc.setColor(0xFFFF33, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + wobble, y - sz / 2, eyeSz - 1);
            dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + wobble - 1, y - sz / 2 - 1, 2, 2);
            if (mi == 4) {
                dc.setColor(0xFFFF33, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x - sz / 2 + wobble, y, eyeSz - 1);
                dc.fillCircle(x + sz / 2 + wobble, y, eyeSz - 1);
            }
        }

        dc.setColor(0xCCCCBB, Graphics.COLOR_TRANSPARENT);
        var cl = sz / 2;
        if (cl < 3) { cl = 3; }
        dc.setPenWidth(2);
        dc.drawLine(x - sz - 2, y - wobble * 2, x - sz + cl, y + cl / 2);
        dc.drawLine(x + sz + 2, y + wobble * 2, x + sz - cl, y + cl / 2);
        dc.drawLine(x - sz - 4, y + 4, x - sz + cl - 2, y + cl);
        dc.drawLine(x + sz + 4, y + 4, x + sz - cl + 2, y + cl);
        dc.setPenWidth(1);

        dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - sz - 2, y - 2, 4, 4);
        dc.fillRectangle(x + sz - 1, y - 2, 4, 4);

        if (mi == 0 || mi == 2 || mi == 6) {
            var hornH = sz / 2;
            if (hornH < 3) { hornH = 3; }
            dc.setColor(0xAAAA88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - sz / 3 + wobble, y - sz - hornH, 3, hornH);
            dc.fillRectangle(x + sz / 3 + wobble - 2, y - sz - hornH + 2, 3, hornH - 2);
        }

        if (mi == 3 || mi == 5) {
            dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
            var tOff = sz + 3;
            var tLen = sz / 2 + 4;
            var tWob = (_tick % 8) - 4;
            dc.setPenWidth(2);
            dc.drawLine(x, y + sz / 2, x + tWob, y + sz / 2 + tLen);
            dc.drawLine(x - sz / 2, y + sz / 3, x - sz / 2 + tWob, y + sz / 3 + tLen - 2);
            dc.drawLine(x + sz / 2, y + sz / 3, x + sz / 2 - tWob, y + sz / 3 + tLen - 2);
            dc.setPenWidth(1);
        }

        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 1, y + sz - 1, 3, sz / 3 + 2);
        if (sz > 14) {
            dc.fillRectangle(x + sz / 4, y + sz - 2, 2, sz / 4);
            dc.fillRectangle(x - sz / 4, y + sz, 2, sz / 4);
        }
    }

    hidden function drawMonsterEyes(dc, x, y, color, trailGlow) {
        var blink = (_tick % 60 < 2);
        if (blink) { return; }

        var flicker = (_tick % 7 < 5) ? 0 : 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 7 + flicker, y, 4);
        dc.fillCircle(x + 7 - flicker, y, 4);

        dc.setColor(0xFFFF22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 7 + flicker, y, 3);
        dc.fillCircle(x + 7 - flicker, y, 3);

        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        var pup = (_tick % 20 < 10) ? 0 : 1;
        dc.fillRectangle(x - 7 + flicker - 1 + pup, y - 1, 2, 3);
        dc.fillRectangle(x + 7 - flicker - 1 - pup, y - 1, 2, 3);

        if (trailGlow) {
            var gc = (_tick % 10 < 5) ? 0x440000 : 0x660000;
            dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x - 7 + flicker, y, 6);
            dc.drawCircle(x + 7 - flicker, y, 6);
            dc.drawCircle(x - 7 + flicker, y, 7);
            dc.drawCircle(x + 7 - flicker, y, 7);
        }
    }

    hidden function drawCaughtScene(dc, w, h) {
        var flashBg = (_introTick % 4 < 2) ? 0x330000 : 0x1A0000;
        dc.setColor(flashBg, flashBg);
        dc.clear();

        drawStoneBg(dc, w, h);
        drawDust(dc, w, h, 0x220000);
        drawBlood(dc, w, h, 10);

        dc.setColor(0x550000, Graphics.COLOR_TRANSPARENT);
        var bTop = h - (_introTick * 3);
        if (bTop < h / 2) { bTop = h / 2; }
        dc.fillRectangle(0, bTop, w, h - bTop);
        dc.setColor(0x880000, Graphics.COLOR_TRANSPARENT);
        var bp;
        var bpx;
        for (bp = 0; bp < 12; bp++) {
            bpx = (bp * 23 + _tick * 3) % w;
            dc.fillCircle(bpx, bTop - 1, 2 + bp % 3);
        }

        dc.setColor(0x440000, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var cr;
        var crad;
        var cLen;
        var crx;
        var cry;
        for (cr = 0; cr < 6; cr++) {
            crad = (cr * 60 + _introTick * 2).toFloat() * 3.14159 / 180.0;
            cLen = 15 + _introTick;
            if (cLen > 50) { cLen = 50; }
            crx = w / 2 + (cLen * Math.sin(crad)).toNumber();
            cry = h * 30 / 100 + (cLen * Math.cos(crad)).toNumber();
            dc.drawLine(w / 2, h * 30 / 100, crx, cry);
        }
        dc.setPenWidth(1);

        var caughtMsgs = ["DEVOURED", "CONSUMED", "SHREDDED", "DEAD"];
        var cmi = _monsterIdx % caughtMsgs.size();

        drawMonsterSprite(dc, w / 2, h * 30 / 100, 30);
        drawMonsterEyes(dc, w / 2, h * 26 / 100, _monsterColors[_monsterIdx], true);

        var flashC = (_introTick % 6 < 3) ? 0xFF0000 : 0xCC0000;
        dc.setColor(flashC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 50 / 100, Graphics.FONT_SMALL, caughtMsgs[cmi], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_monsterColors[_monsterIdx], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_XTINY, _monsterNames[_monsterIdx], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 74 / 100, Graphics.FONT_XTINY, "" + _sessionScore + " pts", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawEscapeScene(dc, w, h) {
        drawStoneBg(dc, w, h);
        drawDust(dc, w, h, 0x0A1A0A);
        drawFogWisps(dc, w, h);

        var doorX = w / 2;
        var doorY = h * 28 / 100;

        dc.setColor(0x061A06, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(doorX, doorY, 38);
        dc.setColor(0x0A2A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(doorX, doorY, 30);

        dc.setColor(0x113311, Graphics.COLOR_TRANSPARENT);
        var r;
        var ra;
        var rx;
        var ry;
        for (r = 0; r < 8; r++) {
            ra = (r * 45 + _introTick * 4).toFloat() * 3.14159 / 180.0;
            rx = doorX + (42 * Math.sin(ra)).toNumber();
            ry = doorY + (42 * Math.cos(ra)).toNumber();
            dc.drawLine(doorX, doorY, rx, ry);
        }

        dc.setColor(0x1A1614, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(doorX - 14, doorY - 18, 28, 36);
        dc.drawRectangle(doorX - 15, doorY - 19, 30, 38);
        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(doorX - 12, doorY - 16, 24, 32);
        dc.setColor(0xAAFFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(doorX - 8, doorY - 12, 16, 24);
        dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(doorX - 3, doorY - 6, 6, 12);

        dc.setColor(0x226622, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(doorX - 6, doorY + 6, 12, 4);
        dc.setColor(0x44AA44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(doorX - 3, doorY + 2, 3);
        dc.fillCircle(doorX + 3, doorY + 4, 2);

        drawTorch(dc, doorX - 28, doorY);
        drawTorch(dc, doorX + 28, doorY);

        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 50 / 100, Graphics.FONT_SMALL, "ESCAPED!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_XTINY, "LV " + _level + "/" + _maxLevels, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 69 / 100, Graphics.FONT_XTINY, "+" + _levelRunScore + " = " + _sessionScore, Graphics.TEXT_JUSTIFY_CENTER);

        if (_level < _maxLevels) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 77 / 100, Graphics.FONT_XTINY, "Next: " + _monsterNames[_level % _monsterNames.size()], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 85 / 100, Graphics.FONT_XTINY, "Tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFinalScene(dc, w, h) {
        drawStarSky(dc, w, h);
        drawDust(dc, w, h, 0x0A0A12);

        dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_SMALL, "SURVIVED!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 26 / 100, Graphics.FONT_SMALL, _survived + "/" + _maxLevels, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 38 / 100, Graphics.FONT_XTINY, _totalDist.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 45 / 100, Graphics.FONT_XTINY, "" + _sessionScore + " pts", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 52 / 100, Graphics.FONT_XTINY, "HI " + _highScore, Graphics.TEXT_JUSTIFY_CENTER);

        var grade;
        if (_survived >= 7) { grade = "GODLIKE"; }
        else if (_survived >= 5) { grade = "NIGHTMARE"; }
        else if (_survived >= 4) { grade = "FAST LEGS"; }
        else if (_survived >= 3) { grade = "SURVIVOR"; }
        else if (_survived >= 2) { grade = "LUCKY"; }
        else { grade = "ALMOST"; }

        dc.setColor(0x44FFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_SMALL, grade, Graphics.TEXT_JUSTIFY_CENTER);

        drawPlayerSprite(dc, w / 2, h * 76 / 100);

        dc.setColor((_tick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 85 / 100, Graphics.FONT_XTINY, "Tap to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
