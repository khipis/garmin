using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum { GS_MENU, GS_IDLE, GS_POWER, GS_CAST, GS_WAIT, GS_BITE, GS_FIGHT, GS_REEL, GS_CAUGHT, GS_LOST, GS_SNAP, GS_GAMEOVER }

class BitochiFishView extends WatchUi.View {

    var accelX;
    var accelY;
    var gameState;

    hidden var _w; hidden var _h; hidden var _cx; hidden var _cy;
    hidden var _timer; hidden var _tick;
    hidden var _power; hidden var _powerDir; hidden var _castDist;
    hidden var _bobX; hidden var _bobY; hidden var _bobVy;
    hidden var _waterY; hidden var _rodTipX; hidden var _rodTipY;
    hidden var _waitTick; hidden var _waitMax; hidden var _biteTick;
    hidden var _approachX; hidden var _approachY; hidden var _approachPhase;

    hidden var _fishX; hidden var _fishY; hidden var _fishVx; hidden var _fishVy;
    hidden var _fishType; hidden var _fishSize; hidden var _fishStr; hidden var _fishWeight;
    hidden var _fishPullDir; hidden var _fishPullTimer;
    hidden var _fishHP; hidden var _fishMaxHP;

    hidden var _fightCursor;    // -100..+100 tug-of-war position

    hidden var _tension; hidden var _maxTension;
    hidden var _reelProg; hidden var _reelTarget; hidden var _lineLen;
    hidden var _score; hidden var _bestScore;
    hidden var _fishCaught; hidden var _combo; hidden var _level;
    hidden var _resultTick; hidden var _resultMsg; hidden var _lastPts;
    hidden var _fishLives; hidden var _levelCatches; hidden var _levelGotSpecial;
    hidden var _goalCount; hidden var _goalMinType;
    hidden var _lineTensionBonus;

    hidden var _shakeTimer; hidden var _shakeOx; hidden var _shakeOy; hidden var _emotion;
    hidden const MAX_PARTS = 28;
    hidden var _partX; hidden var _partY; hidden var _partVx; hidden var _partVy;
    hidden var _partLife; hidden var _partColor;
    hidden const RIPPLE_N = 5;
    hidden var _ripX; hidden var _ripR; hidden var _ripLife;

    hidden var _waveOff; hidden var _envType;
    hidden var _cloudX; hidden var _cloudY;
    hidden var _birdX; hidden var _birdY;
    hidden const RAIN_N = 7;
    hidden var _rainX; hidden var _rainY;

    hidden const MAX_AMB = 5;
    hidden var _ambX; hidden var _ambY; hidden var _ambVx;
    hidden var _ambType; hidden var _ambDir; hidden var _ambActive;
    hidden var _nearAmbIdx;

    hidden var _fishNames;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _cx = _w / 2; _cy = _h / 2;
        accelX = 0; accelY = 0; _tick = 0;
        _waterY = _h * 51 / 100;
        _rodTipX = _w * 70 / 100; _rodTipY = _waterY - 18;
        _power = 0.0; _powerDir = 1; _castDist = 0.0;
        _bobX = 0.0; _bobY = 0.0; _bobVy = 0.0;
        _waitTick = 0; _waitMax = 60; _biteTick = 0;
        _approachX = 0.0; _approachY = 0.0; _approachPhase = 0;
        _fishX = 0.0; _fishY = 0.0; _fishVx = 0.0; _fishVy = 0.0;
        _fishType = 0; _fishSize = 8; _fishStr = 1.0; _fishWeight = 0;
        _fishPullDir = 30.0; _fishPullTimer = 0;
        _fishHP = 100.0; _fishMaxHP = 100.0;
        _fightCursor = 0.0;
        _tension = 0.0; _maxTension = 100.0;
        _reelProg = 0.0; _reelTarget = 100.0; _lineLen = 0.0;
        _score = 0;
        var bs = Application.Storage.getValue("fishBest");
        _bestScore = (bs != null) ? bs : 0;
        _fishCaught = 0; _combo = 0; _level = 1;
        _fishLives = 3; _levelCatches = 0; _levelGotSpecial = false;
        _goalCount = 1; _goalMinType = 0;
        _resultTick = 0; _resultMsg = ""; _lastPts = 0;
        _shakeTimer = 0; _shakeOx = 0; _shakeOy = 0; _emotion = 0;
        _lineTensionBonus = 0.0; _nearAmbIdx = -1; _envType = 0;

        _partX = new [MAX_PARTS]; _partY = new [MAX_PARTS];
        _partVx = new [MAX_PARTS]; _partVy = new [MAX_PARTS];
        _partLife = new [MAX_PARTS]; _partColor = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) { _partLife[i] = 0; _partX[i] = 0.0; _partY[i] = 0.0; _partVx[i] = 0.0; _partVy[i] = 0.0; _partColor[i] = 0; }
        _ripX = new [RIPPLE_N]; _ripR = new [RIPPLE_N]; _ripLife = new [RIPPLE_N];
        for (var i = 0; i < RIPPLE_N; i++) { _ripX[i] = 0; _ripR[i] = 0.0; _ripLife[i] = 0; }

        _waveOff = 0.0;
        _cloudX = new [3]; _cloudY = new [3];
        for (var i = 0; i < 3; i++) { _cloudX[i] = (Math.rand().abs() % _w).toFloat(); _cloudY[i] = 8 + Math.rand().abs() % 16; }
        _birdX = -20.0; _birdY = 16;
        _rainX = new [RAIN_N]; _rainY = new [RAIN_N];
        for (var i = 0; i < RAIN_N; i++) { _rainX[i] = Math.rand().abs() % _w; _rainY[i] = (Math.rand().abs() % _h).toFloat(); }

        _ambX = new [MAX_AMB]; _ambY = new [MAX_AMB]; _ambVx = new [MAX_AMB];
        _ambType = new [MAX_AMB]; _ambDir = new [MAX_AMB]; _ambActive = new [MAX_AMB];
        for (var i = 0; i < MAX_AMB; i++) { _ambActive[i] = false; _ambX[i] = 0.0; _ambY[i] = 0.0; _ambVx[i] = 0.0; _ambType[i] = 0; _ambDir[i] = 1; }

        _fishNames = ["Minnow", "Shrimp", "Perch", "Roach", "Bass", "Carp", "Trout", "Pike", "Catfish", "Tuna"];
        setLevelGoal();
        spawnAmbPool();
        gameState = GS_MENU;
    }

    function onShow() { _timer = new Timer.Timer(); _timer.start(method(:onTick), 50, true); }
    function onHide() { if (_timer != null) { _timer.stop(); _timer = null; } }

    function onTick() as Void {
        _tick++;
        _waveOff += 0.06;
        _birdX += 0.32;
        if (_birdX > (_w + 28).toFloat()) { _birdX = -28.0; _birdY = 8 + Math.rand().abs() % 18; }
        if (_shakeTimer > 0) { _shakeOx = (Math.rand().abs() % 5) - 2; _shakeOy = (Math.rand().abs() % 3) - 1; _shakeTimer--; } else { _shakeOx = 0; _shakeOy = 0; }
        for (var i = 0; i < 3; i++) { _cloudX[i] += 0.07 + i * 0.025; if (_cloudX[i] > (_w + 32).toFloat()) { _cloudX[i] = -32.0; } }
        for (var i = 0; i < MAX_PARTS; i++) { if (_partLife[i] <= 0) { continue; } _partVy[i] += 0.1; _partX[i] += _partVx[i]; _partY[i] += _partVy[i]; _partLife[i]--; }
        for (var i = 0; i < RIPPLE_N; i++) { if (_ripLife[i] <= 0) { continue; } _ripR[i] += 0.4; _ripLife[i]--; }
        if (_envType == 2) {
            for (var ri = 0; ri < RAIN_N; ri++) {
                _rainY[ri] += 5.0;
                if (_rainY[ri] > _waterY.toFloat()) { _rainY[ri] = -8.0; _rainX[ri] = Math.rand().abs() % _w; }
            }
        }
        updateAmbFish();

        if (gameState == GS_POWER) {
            _power += _powerDir.toFloat() * 5.0;
            if (_power >= 100.0) { _power = 100.0; _powerDir = -1; }
            if (_power <= 0.0) { _power = 0.0; _powerDir = 1; }
        } else if (gameState == GS_CAST) {
            _bobVy += 0.30; _bobX -= _castDist * 0.044; if (_bobX < 8.0) { _bobX = 8.0; } _bobY += _bobVy;
            if (_bobY >= _waterY.toFloat()) {
                _bobY = _waterY.toFloat(); addRipple(_bobX.toNumber());
                spawnSplash(_bobX.toNumber(), _waterY);
                gameState = GS_WAIT;
                _waitMax = 38 + Math.rand().abs() % 44;
                _waitTick = _waitMax;
                _nearAmbIdx = -1;
                var nearDist = 85.0;
                for (var ai = 0; ai < MAX_AMB; ai++) {
                    if (!_ambActive[ai]) { continue; }
                    var adx = _bobX - _ambX[ai]; if (adx < 0.0) { adx = -adx; }
                    if (adx < nearDist) { nearDist = adx; _nearAmbIdx = ai; }
                }
                if (_nearAmbIdx >= 0) {
                    _approachX = _ambX[_nearAmbIdx]; _approachY = _ambY[_nearAmbIdx];
                } else {
                    _approachX = _bobX + ((Math.rand().abs() % 2 == 0) ? -50.0 : 50.0);
                    _approachY = _waterY.toFloat() + 20.0 + (Math.rand().abs() % 16).toFloat();
                }
                _approachPhase = 0; _emotion = 0; doVibe(20, 30);
            }
        } else if (gameState == GS_WAIT) {
            _waitTick--;
            _bobY = _waterY.toFloat() + Math.sin(_tick.toFloat() * 0.14) * 1.5;
            _approachPhase++;
            _approachX = _approachX + (_bobX - _approachX) * 0.022;
            _approachY = _approachY + (_waterY.toFloat() + 14.0 - _approachY) * 0.016;
            var pct = 1.0 - _waitTick.toFloat() / _waitMax.toFloat();
            if (pct > 0.7 && _tick % 22 == 0) { addRipple((_approachX + (Math.rand().abs() % 10) - 5).toNumber()); }
            if (_waitTick <= 0) { gameState = GS_BITE; _biteTick = 0; spawnFish(); doVibe(50, 60); _emotion = 1; }
        } else if (gameState == GS_BITE) {
            _biteTick++;
            _bobY = _waterY.toFloat() + Math.sin(_tick.toFloat() * 0.55) * 4.5;
            if (_biteTick % 7 == 0) { addRipple(_bobX.toNumber()); }
            if (_biteTick > 90) {
                _fishLives--; if (_fishLives < 0) { _fishLives = 0; }
                gameState = GS_LOST; _resultMsg = "TOO SLOW!"; _resultTick = 0; _combo = 0; _emotion = 3;
            }
        } else if (gameState == GS_FIGHT) {
            updateFight();
        } else if (gameState == GS_REEL) {
            _reelProg += 2.2;
            _fishX = _fishX * 0.92 + _rodTipX.toFloat() * 0.08;
            _fishY = _fishY * 0.92 + (_waterY - 10).toFloat() * 0.08;
            if (_reelProg >= _reelTarget) {
                gameState = GS_CAUGHT; _resultTick = 0;
                var pts = 60 + _fishType * 50 + _combo * 30;
                _fishCaught++; _levelCatches++;
                if (_fishType >= _goalMinType && _goalMinType > 0) { _levelGotSpecial = true; }
                if (_goalMinType == 0) { _levelGotSpecial = true; }
                if (_fishCaught % 5 == 0 && _lineTensionBonus < 28.0) { _lineTensionBonus += 7.0; pts += 80; }
                _score += pts; _lastPts = pts; _combo++;
                if (_score > _bestScore) { _bestScore = _score; Application.Storage.setValue("fishBest", _bestScore); }
                _resultMsg = _fishNames[_fishType] + "!";
                var wBase = [50, 12, 180, 100, 700, 1800, 550, 2200, 1100, 7500];
                var wRng  = [60, 14, 350, 180, 1800, 4500, 1400, 5500, 2800, 18000];
                _fishWeight = wBase[_fishType] + Math.rand().abs() % wRng[_fishType];
                if (_levelCatches >= _goalCount && _levelGotSpecial) {
                    _level++; if (_level > 15) { _level = 15; }
                    setLevelGoal(); _envType = getEnvType(); spawnAmbPool();
                }
                spawnCatchParts(_fishX.toNumber(), _fishY.toNumber());
                doVibe(80, 120); _shakeTimer = 5; _emotion = 2;
            }
        } else if (gameState == GS_CAUGHT || gameState == GS_LOST || gameState == GS_SNAP) {
            _resultTick++;
            if (_resultTick > 70) {
                if (_fishLives <= 0) { gameState = GS_GAMEOVER; _resultTick = 0; }
                else { gameState = GS_IDLE; _emotion = 0; }
            }
        } else if (gameState == GS_GAMEOVER) {
            _resultTick++;
        }
        WatchUi.requestUpdate();
    }

    hidden function updateAmbFish() {
        for (var i = 0; i < MAX_AMB; i++) {
            if (!_ambActive[i]) { continue; }
            _ambX[i] += _ambVx[i];
            if (_ambX[i] < 8.0) { _ambX[i] = 8.0; _ambVx[i] = -_ambVx[i]; _ambDir[i] = 1; }
            if (_ambX[i] > (_w * 64 / 100).toFloat()) { _ambX[i] = (_w * 64 / 100).toFloat(); _ambVx[i] = -_ambVx[i]; _ambDir[i] = -1; }
            if (_tick % 53 == i * 11 % 53) {
                _ambY[i] += (Math.rand().abs() % 5 - 2).toFloat();
                var minY = (_waterY + 14).toFloat(); var maxY = (_h - 24).toFloat();
                if (_ambY[i] < minY) { _ambY[i] = minY; } if (_ambY[i] > maxY) { _ambY[i] = maxY; }
            }
        }
    }

    hidden function spawnAmbPool() {
        var maxT = 1 + _level / 2; if (maxT > 8) { maxT = 8; }
        for (var i = 0; i < MAX_AMB; i++) {
            _ambType[i] = Math.rand().abs() % (maxT + 1);
            _ambX[i] = (12 + Math.rand().abs() % (_w * 60 / 100 - 12)).toFloat();
            _ambY[i] = (_waterY + 18 + Math.rand().abs() % 38).toFloat();
            var spd = 0.32 + (Math.rand().abs() % 6).toFloat() * 0.1;
            _ambDir[i] = (Math.rand().abs() % 2 == 0) ? 1 : -1;
            _ambVx[i] = spd * _ambDir[i].toFloat();
            _ambActive[i] = true;
        }
    }

    hidden function getEnvType() {
        if (_level <= 2) { return 0; }   // sunny
        if (_level <= 4) { return 1; }   // cloudy
        if (_level <= 6) { return 2; }   // rainy
        if (_level <= 8) { return 3; }   // golden sunset
        if (_level <= 10) { return 4; }  // rainbow
        return 5;                         // night
    }

    hidden function setLevelGoal() {
        _levelCatches = 0; _levelGotSpecial = false;
        if (_level == 1)       { _goalCount = 1; _goalMinType = 0; }
        else if (_level == 2)  { _goalCount = 1; _goalMinType = 1; }
        else if (_level == 3)  { _goalCount = 2; _goalMinType = 0; }
        else if (_level == 4)  { _goalCount = 1; _goalMinType = 2; }
        else if (_level == 5)  { _goalCount = 2; _goalMinType = 3; }
        else if (_level == 6)  { _goalCount = 1; _goalMinType = 4; }
        else if (_level == 7)  { _goalCount = 2; _goalMinType = 5; }
        else if (_level == 8)  { _goalCount = 1; _goalMinType = 6; }
        else if (_level == 9)  { _goalCount = 3; _goalMinType = 7; }
        else if (_level == 10) { _goalCount = 1; _goalMinType = 8; }
        else if (_level == 11) { _goalCount = 2; _goalMinType = 8; }
        else if (_level == 12) { _goalCount = 1; _goalMinType = 9; }
        else                   { _goalCount = 3; _goalMinType = 9; }
        if (_goalMinType == 0) { _levelGotSpecial = true; }
    }

    hidden function spawnFish() {
        if (_nearAmbIdx >= 0 && _nearAmbIdx < MAX_AMB && _ambActive[_nearAmbIdx]) {
            _fishType = _ambType[_nearAmbIdx];
            _ambActive[_nearAmbIdx] = false;
            _nearAmbIdx = -1;
        } else {
            var maxType = 1 + _level / 2; if (maxType > 9) { maxType = 9; }
            var minType = 0; if (_level >= 5) { minType = 1; } if (_level >= 8) { minType = 2; }
            if (minType > maxType) { minType = maxType; }
            _fishType = minType + Math.rand().abs() % (maxType - minType + 1);
        }
        if (_goalMinType > 0 && !_levelGotSpecial && _levelCatches >= _goalCount - 1 && _fishType < _goalMinType) {
            _fishType = _goalMinType;
        }
        var fishSizes = [5, 6, 7, 8, 9, 11, 12, 14, 16, 18];
        _fishSize = fishSizes[_fishType];
        var lvlF = _level.toFloat();
        _fishStr = 0.42 + _fishType.toFloat() * 0.14 + lvlF * 0.035;
        if (_fishStr > 1.9) { _fishStr = 1.9; }
        _fishHP = 38.0 + _fishType.toFloat() * 11.0 + lvlF * 2.8;
        _fishMaxHP = _fishHP;
        _fishX = _bobX + ((Math.rand().abs() % 2 == 0) ? -28.0 : 28.0);
        _fishY = _bobY + 48.0 + (Math.rand().abs() % 22).toFloat();
        _fishVx = 0.0; _fishVy = 0.0;
        _fishPullDir = (Math.rand().abs() % 2 == 0) ? 28.0 : 208.0;
        _fishPullTimer = 25 + Math.rand().abs() % 20;
        _maxTension = 100.0 + _lineTensionBonus;
        _tension = 24.0 + _lineTensionBonus * 0.18; _reelProg = 0.0;
        _reelTarget = 44.0 + _fishType.toFloat() * 10.0 - _lineTensionBonus * 0.18;
        if (_reelTarget < 34.0) { _reelTarget = 34.0; }
        _fightCursor = 0.0;
    }

    hidden function updateFight() {
        _fishPullTimer--;
        if (_fishPullTimer <= 0) {
            _fishPullDir = (_fishPullDir < 100.0) ? 208.0 : 28.0;
            _fishPullTimer = 22 + Math.rand().abs() % 28;
            if (Math.rand().abs() % 5 == 0) { _fishStr *= 1.08; if (_fishStr > 2.0) { _fishStr = 2.0; } doVibe(45, 60); }
        }

        var pullForce = _fishStr * (0.55 + Math.sin(_tick.toFloat() * 0.18) * 0.22);
        var fishDir = (_fishPullDir < 100.0) ? 1.0 : -1.0;

        // Fish pushes fight cursor toward its escape direction.
        // Player counters with Parachute-style direct accelerometer control:
        //   fish goes right (fishDir=+1) → cursor drifts right
        //   tilt left (accelX<0)         → cursor pushed left back to center
        _fightCursor += pullForce * fishDir * 1.8;
        _fightCursor += accelX.toFloat() * 0.095;
        if (_fightCursor >  100.0) { _fightCursor =  100.0; }
        if (_fightCursor < -100.0) { _fightCursor = -100.0; }

        // Move fish visually under water
        var pullRad = _fishPullDir * 3.14159265 / 180.0;
        _fishVx = pullForce * Math.cos(pullRad) * 0.55;
        _fishVy = pullForce * Math.sin(pullRad) * 0.18;
        _fishX += _fishVx; _fishY += _fishVy;
        if (_fishX < 10.0) { _fishX = 10.0; }
        if (_fishX > (_w - 10).toFloat()) { _fishX = (_w - 10).toFloat(); }
        if (_fishY < (_waterY + 8).toFloat()) { _fishY = (_waterY + 8).toFloat(); }
        if (_fishY > (_h - 12).toFloat()) { _fishY = (_h - 12).toFloat(); }

        // Tension + HP outcome based on cursor position
        var absCursor = _fightCursor; if (absCursor < 0.0) { absCursor = -absCursor; }
        var tensionDelta;
        if (absCursor < 28.0) {
            // Safe zone: fish tires quickly, tension eases
            tensionDelta = -1.4 - _lineTensionBonus * 0.004;
            _fishHP -= 1.6 + pullForce * 0.35;
            _reelProg += 0.65 + pullForce * 0.25;
        } else if (absCursor < 62.0) {
            // Yellow zone: slight tension rise, slow drain
            tensionDelta = 0.4 + (absCursor - 28.0) / 34.0 * 0.8;
            _fishHP -= 0.35;
            _reelProg += 0.12;
        } else {
            // Danger zone: tension spikes fast
            tensionDelta = 1.2 + (absCursor - 62.0) * 0.06;
        }
        _tension += tensionDelta;
        if (_tension < 0.0) { _tension = 0.0; }
        if (_tension > _maxTension) { _tension = _maxTension; }

        _emotion = (_tension > 70.0) ? 3 : ((_tension > 42.0) ? 1 : 0);
        if (_fishHP <= 0.0) { gameState = GS_REEL; doVibe(60, 80); _emotion = 2; }
        if (_tension >= _maxTension) {
            _fishLives--; if (_fishLives < 0) { _fishLives = 0; }
            gameState = GS_SNAP; _resultTick = 0; _resultMsg = "LINE SNAPPED!";
            _combo = 0; spawnSnapParts(_bobX.toNumber(), _waterY);
            doVibe(100, 150); _shakeTimer = 8; _emotion = 3;
        }
        if (_tick % 14 == 0 && pullForce > 0.5) { addRipple(_fishX.toNumber()); }
        if (_tension > 72.0) { doVibe((((_tension - 72.0) / 28.0 * 28.0)).toNumber() + 10, 20); }
        _bobX = _bobX * 0.88 + _fishX * 0.12;
        _bobY = _waterY.toFloat() + Math.sin(_tick.toFloat() * 0.27) * 2.0;
    }

    function doAction() {
        if (gameState == GS_GAMEOVER) {
            if (_resultTick > 15) {
                _score = 0; _fishCaught = 0; _combo = 0; _level = 1;
                _fishLives = 3; _lineTensionBonus = 0.0;
                setLevelGoal(); _envType = 0; spawnAmbPool(); gameState = GS_IDLE;
            }
            return;
        }
        if (gameState == GS_MENU) {
            _score = 0; _fishCaught = 0; _combo = 0; _level = 1;
            _fishLives = 3; _lineTensionBonus = 0.0;
            setLevelGoal(); _envType = 0; spawnAmbPool(); gameState = GS_IDLE; return;
        }
        if (gameState == GS_IDLE) { _power = 0.0; _powerDir = 1; gameState = GS_POWER; return; }
        if (gameState == GS_POWER) {
            _castDist = _power; _bobX = _rodTipX.toFloat(); _bobY = _rodTipY.toFloat();
            _bobVy = -3.8 - _power * 0.026; gameState = GS_CAST; doVibe(30, 40); return;
        }
        if (gameState == GS_BITE) { gameState = GS_FIGHT; _resultMsg = "FIGHT!"; _resultTick = 0; doVibe(40, 50); _emotion = 1; return; }
        if (gameState == GS_FIGHT) {
            _reelProg += 1.1; _fishHP -= 1.1;
            if (_fishHP <= 0.0) { gameState = GS_REEL; doVibe(60, 80); _emotion = 2; }
            return;
        }
        if (gameState == GS_CAUGHT) { if (_resultTick > 15) { gameState = GS_IDLE; } return; }
        if (gameState == GS_LOST || gameState == GS_SNAP) { if (_resultTick > 15) { gameState = GS_IDLE; _emotion = 0; } return; }
    }

    hidden function addRipple(rx) { for (var i = 0; i < RIPPLE_N; i++) { if (_ripLife[i] > 0) { continue; } _ripX[i] = rx; _ripR[i] = 2.0; _ripLife[i] = 18; break; } }

    hidden function spawnSplash(ex, ey) {
        var wc = [0x66AADD, 0x88CCEE, 0xAADDFF, 0x4488BB];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) { if (spawned >= 8) { break; } if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat(); _partY[i] = ey.toFloat();
            _partVx[i] = ((Math.rand().abs() % 18) - 9).toFloat() * 0.14;
            _partVy[i] = -1.4 - (Math.rand().abs() % 14).toFloat() * 0.12;
            _partLife[i] = 10 + Math.rand().abs() % 8; _partColor[i] = wc[Math.rand().abs() % 4]; spawned++;
        }
    }

    hidden function spawnCatchParts(ex, ey) {
        var cc = [0xFFFF44, 0xFFCC22, 0x88FF88, 0xFFFFAA, 0x44FFAA, 0xFFDD66];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) { if (spawned >= 12) { break; } if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat(); _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.0 + (Math.rand().abs() % 26).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a); _partVy[i] = spd * Math.sin(a) - 1.0;
            _partLife[i] = 13 + Math.rand().abs() % 11; _partColor[i] = cc[Math.rand().abs() % 6]; spawned++;
        }
    }

    hidden function spawnSnapParts(ex, ey) {
        var sc = [0xFF4444, 0xFFAA44, 0xFFFF88, 0xFF6644];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) { if (spawned >= 9) { break; } if (_partLife[i] > 0) { continue; }
            _partX[i] = ex.toFloat(); _partY[i] = ey.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var spd = 1.5 + (Math.rand().abs() % 20).toFloat() / 10.0;
            _partVx[i] = spd * Math.cos(a); _partVy[i] = spd * Math.sin(a);
            _partLife[i] = 9 + Math.rand().abs() % 9; _partColor[i] = sc[Math.rand().abs() % 4]; spawned++;
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) { if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
        } }
    }

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight(); _cx = _w / 2; _cy = _h / 2;
        _waterY = _h * 51 / 100;
        _rodTipX = _w * 70 / 100; _rodTipY = _waterY - 18;
        if (gameState == GS_MENU) { drawMenu(dc); return; }
        if (gameState == GS_GAMEOVER) { drawGameOver(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeOx; var oy = _shakeOy;
        drawSky(dc, ox, oy);
        drawWater(dc, ox, oy);
        drawAmbFish(dc, ox, oy);
        drawRipples(dc, ox, oy);
        if (gameState == GS_WAIT) { drawApproachFish(dc, ox, oy); }
        if (gameState == GS_FIGHT || gameState == GS_REEL || gameState == GS_BITE) { drawFishUnder(dc, ox, oy); }
        drawBob(dc, ox, oy);
        drawFisherman(dc, ox, oy);
        drawLine(dc, ox, oy);
        drawParticles(dc, ox, oy);
        if (gameState == GS_POWER) { drawPowerBar(dc); }
        if (gameState == GS_WAIT) { drawWaitInd(dc); }
        if (gameState == GS_BITE) { drawBiteAlert(dc); }
        if (gameState == GS_FIGHT) { drawFightHUD(dc); }
        if (gameState == GS_REEL) { drawReelAnim(dc); }
        drawHUD(dc);
        if ((gameState == GS_CAUGHT || gameState == GS_LOST || gameState == GS_SNAP) && _resultTick < 65) { drawResultMsg(dc); }
        if (gameState == GS_CAUGHT && _resultTick < 58) { drawCaughtFish(dc, ox, oy); }
    }

    hidden function drawSky(dc, ox, oy) {
        var skyTop; var skyMid; var skyBot;
        if (_envType == 0)      { skyTop = 0x1E6FAA; skyMid = 0x3399CC; skyBot = 0x55BBDD; }
        else if (_envType == 1) { skyTop = 0x3A5568; skyMid = 0x4A7088; skyBot = 0x5A8899; }
        else if (_envType == 2) { skyTop = 0x283844; skyMid = 0x364858; skyBot = 0x446070; }
        else if (_envType == 3) { skyTop = 0x7A4418; skyMid = 0xAA6628; skyBot = 0xCC8840; }
        else if (_envType == 4) { skyTop = 0x1E6FAA; skyMid = 0x44AACC; skyBot = 0x66CCDD; }
        else                    { skyTop = 0x06101A; skyMid = 0x0A1826; skyBot = 0x0E2030; }
        dc.setColor(skyTop, skyTop); dc.clear();
        dc.setColor(skyMid, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _waterY * 32 / 100, _w, _waterY * 32 / 100);
        dc.setColor(skyBot, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _waterY * 64 / 100, _w, _waterY - _waterY * 64 / 100 + 2);

        if (_envType == 5) {
            dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
            for (var s = 0; s < 16; s += 2) {  // every other star — same visual, half the calls
                var sx = (s * 41 + 9) % _w; var sy = (s * 27 + 5) % (_waterY * 70 / 100);
                if ((s + _tick / 25) % 5 < 4) { dc.fillRectangle(sx, sy, 1, 1); }
            }
            dc.setColor(0xDDEECC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(18 + ox, 14 + oy, 20, 14);
        } else if (_envType == 3) {
            dc.setColor(0xFF7733, Graphics.COLOR_TRANSPARENT); dc.fillCircle(28 + ox, _waterY - 20 + oy, 14);
        } else if (_envType == 0 || _envType == 4) {
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(26 + ox, 22 + oy, 12);
            for (var r = 0; r < 5; r++) {
                var ra = (r * 72 + _tick * 2).toFloat() * 3.14159 / 180.0;
                dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(26 + ox + (13.0 * Math.cos(ra)).toNumber(), 22 + oy + (13.0 * Math.sin(ra)).toNumber(),
                            26 + ox + (17.0 * Math.cos(ra)).toNumber(), 22 + oy + (17.0 * Math.sin(ra)).toNumber());
            }
        }
        if (_envType == 4) {
            var rainbowC = [0xFF4444, 0xFF8800, 0xFFEE00, 0x44CC44, 0x4477FF];
            for (var ri2 = 0; ri2 < 5; ri2++) {
                dc.setColor(rainbowC[ri2], Graphics.COLOR_TRANSPARENT);
                var rr2 = _w * 44 / 100 - ri2 * 5;
                if (rr2 > 5) { dc.drawArc(_cx + ox, _waterY + oy, rr2, Graphics.ARC_CLOCKWISE, 30, 150); dc.drawArc(_cx + ox, _waterY + oy, rr2 - 1, Graphics.ARC_CLOCKWISE, 30, 150); }
            }
        }
        if (_envType == 2) {
            dc.setColor(0x7AA0BB, Graphics.COLOR_TRANSPARENT);
            for (var ri3 = 0; ri3 < RAIN_N; ri3++) {
                var ry3 = _rainY[ri3].toNumber() + oy;
                if (ry3 >= 0 && ry3 < _waterY + oy) { dc.drawLine(_rainX[ri3] + ox, ry3, _rainX[ri3] + ox, ry3 + 7); }
            }
        }
        var ccW  = (_envType == 2) ? 0x3A5060 : ((_envType == 3) ? 0x996622 : 0xBBCCDD);
        var ccW2 = (_envType == 2) ? 0x4A6070 : ((_envType == 3) ? 0xAA7733 : 0xCCDDEE);
        for (var i = 0; i < 3; i++) {
            var ccx = _cloudX[i].toNumber() + ox; var ccy = _cloudY[i] + oy;
            var cs = 8 + i * 3 + (_envType >= 1 && _envType <= 2 ? 5 : 0);
            dc.setColor(ccW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx, ccy, cs); dc.fillCircle(ccx + cs * 13 / 10, ccy + 1, cs * 85 / 100); dc.fillCircle(ccx - cs, ccy + 2, cs * 75 / 100);
            dc.setColor(ccW2, Graphics.COLOR_TRANSPARENT); dc.fillCircle(ccx + 4, ccy - 3, cs * 6 / 10);
        }
        var bx2 = _birdX.toNumber() + ox;
        dc.setColor((_envType == 5) ? 0x446688 : 0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(bx2 - 4, _birdY + oy, bx2, _birdY - 2 + oy); dc.drawLine(bx2, _birdY - 2 + oy, bx2 + 4, _birdY + oy);
        var gy = _waterY + oy;
        var gC  = (_envType == 5) ? 0x1A2E1A : ((_envType == 3) ? 0x5A4818 : 0x327018);
        var gC2 = (_envType == 5) ? 0x243624 : ((_envType == 3) ? 0x6A5820 : 0x44992C);
        dc.setColor(gC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w * 60 / 100, gy - 26, _w * 40 / 100, 26);
        dc.setColor(gC2, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w * 60 / 100, gy - 26, _w * 40 / 100, 3);
        for (var g2 = _w * 60 / 100; g2 < _w; g2 += 5) { dc.setColor(gC2, Graphics.COLOR_TRANSPARENT); dc.drawLine(g2 + ox, gy - 26, g2 + 1 + ox, gy - 29 - (g2 % 4)); }
        dc.setColor(0x5A3A1A, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w * 77 / 100 + ox, gy - 50, 4, 24);
        var tC = (_envType == 3) ? 0x7A5018 : ((_envType == 5) ? 0x1A3018 : 0x289030);
        dc.setColor(tC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 79 / 100 + ox, gy - 52, 13); dc.fillCircle(_w * 74 / 100 + ox, gy - 46, 9); dc.fillCircle(_w * 84 / 100 + ox, gy - 46, 10);
    }

    hidden function drawWater(dc, ox, oy) {
        var wy = _waterY + oy;
        var wC    = (_envType == 2) ? 0x184460 : ((_envType == 3) ? 0x5A3A18 : ((_envType == 5) ? 0x081A28 : 0x165688));
        var wavC  = (_envType == 2) ? 0x205570 : ((_envType == 3) ? 0x6A4A28 : ((_envType == 5) ? 0x0A2030 : 0x2475AA));
        var deepC = (_envType == 5) ? 0x040C16 : 0x0C3660;
        dc.setColor(wC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, wy, _w, _h - wy);
        for (var x = 0; x < _w; x += 6) {
            var wh = (Math.sin((x.toFloat() + _waveOff * 16.0) * 0.09) * 2.2).toNumber();
            dc.setColor(wavC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(x + ox, wy + wh, 6, 3);
        }
        dc.setColor(deepC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, wy + 5, _w, _h - wy - 5);
        for (var d = 0; d < 3; d++) {
            var dy = wy + 12 + d * 17;
            var shC = (_envType == 5) ? 0x08182A : (d % 2 == 0 ? 0x103A70 : 0x184880);
            dc.setColor(shC, Graphics.COLOR_TRANSPARENT);
            for (var x = 0; x < _w; x += 15) { dc.fillRectangle((x + (_tick / 2 + d * 5) % 15 - 7) + ox, dy, 8, 1); }
        }
        dc.setColor(0x1A6030, Graphics.COLOR_TRANSPARENT);
        for (var lp = 0; lp < 2; lp++) {
            var lpx = (_w * 11 / 100 + lp * _w * 26 / 100) + ox;
            dc.fillCircle(lpx, wy + 2, 6); dc.fillCircle(lpx + 5, wy + 1, 4);
            dc.setColor(0x28AA44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lpx + 1, wy, 3);
            dc.setColor(0x1A6030, Graphics.COLOR_TRANSPARENT);
        }
        dc.setColor(0x7A6644, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h - 9, _w, 9);
        dc.setColor(0x8A7755, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h - 6, _w, 4);
        for (var r2 = 0; r2 < _w; r2 += 12) { dc.setColor(0x6A5533, Graphics.COLOR_TRANSPARENT); dc.fillCircle(r2 + 6, _h - 3, 2); }
    }

    hidden function getFishColorType(t) {
        if (t == 0) { return 0x88BB88; }
        if (t == 1) { return 0xFFBB99; }
        if (t == 2) { return 0x44CC55; }
        if (t == 3) { return 0x33AA44; }
        if (t == 4) { return 0xDD9966; }
        if (t == 5) { return 0x7788AA; }
        if (t == 6) { return 0xEE8855; }
        if (t == 7) { return 0x4466CC; }
        if (t == 8) { return 0x997744; }
        return 0xFF6644;
    }
    hidden function getFishBellyType(t) {
        if (t == 0) { return 0xAADDAA; } if (t == 1) { return 0xFFCCBB; }
        if (t == 2) { return 0x88EE99; } if (t == 3) { return 0x55BB66; }
        if (t == 4) { return 0xEEBB99; } if (t == 5) { return 0xAABBCC; }
        if (t == 6) { return 0xFFAA88; } if (t == 7) { return 0x77AADD; }
        if (t == 8) { return 0xBBAA77; } return 0xFF9977;
    }
    hidden function getFishColor() { return getFishColorType(_fishType); }

    hidden function drawAmbFish(dc, ox, oy) {
        for (var i = 0; i < MAX_AMB; i++) {
            if (!_ambActive[i]) { continue; }
            var fx = _ambX[i].toNumber() + ox; var fy = _ambY[i].toNumber() + oy;
            if (fy <= _waterY + oy + 2) { continue; }
            var t = _ambType[i]; var sz = 4 + t; if (sz > 13) { sz = 13; }
            var dir = (_ambVx[i] >= 0.0) ? 1 : -1;
            var bodyC = getFishColorType(t); var bellyC = getFishBellyType(t);
            // subtle wave movement
            var wv = (Math.sin((_tick.toFloat() * 0.12 + i.toFloat() * 1.1)) * 1.5).toNumber();
            fy += wv;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + 2, fy + 2, sz - 1);
            dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fx, fy, sz);
            dc.fillCircle(fx + dir * sz * 6 / 10, fy, sz * 7 / 10);
            dc.fillCircle(fx - dir * (sz + 2), fy - sz / 3, sz / 3);
            dc.fillCircle(fx - dir * (sz + 2), fy + sz / 3, sz / 3);
            dc.setColor(bellyC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx, fy + sz / 3, sz / 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + dir * (sz - 2), fy - 1, 2);
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + dir * (sz - 1), fy - 1, 1);
            if (t >= 5 && _tick % 14 < 5) { dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + dir * 3, fy - sz / 2, 1); }
        }
    }

    hidden function drawRipples(dc, ox, oy) {
        for (var i = 0; i < RIPPLE_N; i++) {
            if (_ripLife[i] <= 0) { continue; }
            var rx = _ripX[i] + ox; var ry = _waterY + oy;
            dc.setColor((_ripLife[i] > 10) ? 0x5599BB : 0x3377AA, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(rx, ry, _ripR[i].toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 155, 25);
        }
    }

    hidden function drawApproachFish(dc, ox, oy) {
        var pct = 1.0 - _waitTick.toFloat() / _waitMax.toFloat();
        if (pct < 0.14) { return; }
        var fx = _approachX.toNumber() + ox; var fy = _approachY.toNumber() + oy;
        if (fy <= _waterY + oy + 4) { fy = _waterY + oy + 10; }
        var sz = 5 + (pct * 5.0).toNumber();
        var t = (_nearAmbIdx >= 0 && _nearAmbIdx < MAX_AMB) ? _ambType[_nearAmbIdx] : 1;
        var bodyC = getFishColorType(t);
        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        var dir = (_approachX < _bobX) ? 1 : -1;
        dc.fillCircle(fx, fy, sz); dc.fillCircle(fx + dir * sz / 2, fy, sz * 3 / 4);
        dc.fillCircle(fx - dir * (sz + 2), fy - sz / 3, sz / 3); dc.fillCircle(fx - dir * (sz + 2), fy + sz / 3, sz / 3);
        if (pct > 0.5) { dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + dir * (sz - 2), fy - 1, 1); }
        if (pct > 0.72 && _nearAmbIdx >= 0) {
            dc.setColor(0xFFDD77, Graphics.COLOR_TRANSPARENT);
            dc.drawText(fx, fy - sz - 9, Graphics.FONT_XTINY, _fishNames[t], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawBob(dc, ox, oy) {
        if (gameState == GS_IDLE || gameState == GS_POWER || gameState == GS_CAUGHT || gameState == GS_LOST || gameState == GS_SNAP || gameState == GS_GAMEOVER) { return; }
        var bx = _bobX.toNumber() + ox; var by = _bobY.toNumber() + oy;
        dc.setColor(0xCC1111, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bx, by, 5);
        dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bx, by, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bx - 1, by - 2, 2);
    }

    hidden function drawFisherman(dc, ox, oy) {
        var gy = _waterY + oy; var fx = _w - 14 + ox; var fy = gy - 3;
        dc.setColor(0x3A5A22, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - 8, fy - 3, 16, 3);
        dc.setColor(0xCCA066, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx, fy - 18, 7);
        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx, fy - 18, 6);
        dc.setColor(0x7A4A18, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - 8, fy - 27, 16, 5); dc.fillRectangle(fx - 5, fy - 25, 10, 3);
        var lex = fx - 2; var rex = fx + 3; var eey = fy - 19;
        if (_emotion == 0) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lex, eey, 1); dc.fillCircle(rex, eey, 1); dc.fillRectangle(fx - 2, fy - 14, 4, 1);
        } else if (_emotion == 1) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lex, eey, 2); dc.fillCircle(rex, eey, 2);
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lex, eey, 1); dc.fillCircle(rex, eey, 1); dc.fillRectangle(fx - 2, fy - 13, 4, 2);
        } else if (_emotion == 2) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(lex - 1, eey - 1, lex + 1, eey + 1); dc.drawLine(rex - 1, eey - 1, rex + 1, eey + 1);
            dc.drawLine(fx - 3, fy - 15, fx + 3, fy - 14);
        } else {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lex, eey, 2); dc.fillCircle(rex, eey, 2);
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lex, eey, 1); dc.fillCircle(rex, eey, 1); dc.fillCircle(fx, fy - 13, 2);
        }
        dc.setColor(0x3366AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - 5, fy - 10, 10, 12);
        dc.setColor(0x2255AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - 5, fy - 10, 2, 12);
        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - 7, fy - 8, 3, 3); dc.fillRectangle(fx + 5, fy - 7, 3, 3);
        dc.setColor(0x444466, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - 4, fy + 2, 4, 6); dc.fillRectangle(fx + 1, fy + 2, 4, 6);
        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - 5, fy + 7, 5, 2); dc.fillRectangle(fx + 1, fy + 7, 5, 2);
        var tipX = _rodTipX + ox; var tipY = _rodTipY + oy;
        var handX = fx - 7; var handY = fy - 7;
        dc.setColor(0x8A6A3A, Graphics.COLOR_TRANSPARENT); dc.drawLine(handX, handY, tipX, tipY); dc.drawLine(handX, handY - 1, tipX, tipY - 1);
        dc.setColor(0x6A4A1A, Graphics.COLOR_TRANSPARENT); dc.drawLine(handX + 1, handY, tipX + 1, tipY);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT); dc.fillCircle(tipX, tipY, 2);
    }

    hidden function drawLine(dc, ox, oy) {
        if (gameState == GS_IDLE || gameState == GS_POWER || gameState == GS_CAUGHT || gameState == GS_LOST || gameState == GS_SNAP || gameState == GS_GAMEOVER) { return; }
        var tipX = _rodTipX + ox; var tipY = _rodTipY + oy;
        var bx = _bobX.toNumber() + ox; var by = _bobY.toNumber() + oy;
        var lineC = 0xBBBBBB;
        if (gameState == GS_FIGHT && _tension > 70.0) { lineC = (_tick % 4 < 2) ? 0xFF4444 : 0xCC2222; }
        else if (gameState == GS_FIGHT && _tension > 45.0) { lineC = 0xDDAA33; }
        dc.setColor(lineC, Graphics.COLOR_TRANSPARENT);
        if (gameState == GS_FIGHT) {
            var sag = (_tension / _maxTension * 8.0).toNumber();
            var mx = (tipX + bx) / 2; var my = (tipY + by) / 2 + sag;
            dc.drawLine(tipX, tipY, mx, my); dc.drawLine(mx, my, bx, by);
        } else { dc.drawLine(tipX, tipY, bx, by); }
    }

    hidden function drawFishUnder(dc, ox, oy) {
        var fx = _fishX.toNumber() + ox; var fy = _fishY.toNumber() + oy;
        var sz = _fishSize; var dir = (_fishVx >= 0) ? 1 : -1;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + 2, fy + 2, sz + 1);
        var bodyC = getFishColor(); var bellyC = getFishBellyType(_fishType);
        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx, fy, sz); dc.fillCircle(fx + dir * sz / 2, fy, sz * 80 / 100);
        dc.fillCircle(fx - dir * sz / 2, fy, sz * 70 / 100);
        dc.fillCircle(fx - dir * (sz + 2), fy - sz / 3, sz / 3 + 1);
        dc.fillCircle(fx - dir * (sz + 2), fy + sz / 3, sz / 3 + 1);
        dc.setColor(bellyC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx, fy + sz / 3, sz * 50 / 100);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + dir * (sz - 3), fy - 2, 3);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + dir * (sz - 2), fy - 2, 1);
        if (_fishType >= 4) { dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[fx, fy - sz + 1], [fx - 4, fy - sz - 5], [fx + 4, fy - sz - 5]]); }
        if (_fishType >= 7) {
            dc.setColor((_fishType == 9) ? 0xFF9966 : 0x5577CC, Graphics.COLOR_TRANSPARENT);
            var swordX = (dir >= 0) ? fx + sz : fx - sz - 11;
            dc.fillRectangle(swordX, fy - 1, (_fishType == 9) ? 12 : 8, 2);
        }
        if (gameState == GS_FIGHT && _fishHP > 0) {
            var hpW = sz * 2; var hpFill = (_fishHP / _fishMaxHP * hpW.toFloat()).toNumber(); if (hpFill < 0) { hpFill = 0; }
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - sz, fy - sz - 6, hpW, 3);
            dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fx - sz, fy - sz - 6, hpFill, 3);
        }
    }

    hidden function drawPowerBar(dc) {
        var bW = _w * 42 / 100; var bH = 10; var bX = (_w - bW) / 2; var bY = _h * 74 / 100;
        dc.setColor(0x1A1A2A, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX - 1, bY - 1, bW + 2, bH + 2);
        dc.setColor(0x2A2A3A, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX, bY, bW, bH);
        var fill = (_power / 100.0 * bW.toFloat()).toNumber();
        var fc = (_power > 76.0) ? 0xFF4444 : ((_power > 46.0) ? 0xFFAA44 : 0x44CC44);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX, bY, fill, bH);
        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, bY - 14, Graphics.FONT_XTINY, "CAST POWER", Graphics.TEXT_JUSTIFY_CENTER);

        // Landing preview dot on water line using arc physics (gravity=0.30)
        var vy0 = -3.8 - _power * 0.026;
        var disc = vy0 * vy0 + 4.0 * 0.15 * 18.0;
        var ft = (-vy0 + Math.sqrt(disc)) / (2.0 * 0.15);
        var prevX = _rodTipX.toFloat() - _power * 0.044 * ft;
        if (prevX < 8.0) { prevX = 8.0; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(prevX.toNumber(), _waterY - 3, 5);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT); dc.fillCircle(prevX.toNumber(), _waterY - 3, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(prevX.toNumber() - 1, _waterY - 5, 1);

        // Fish markers on power bar – show which power level reaches each fish
        var maxTravel = _rodTipX - 8;
        var nearName = ""; var nearDist2 = 9999.0;
        for (var ai = 0; ai < MAX_AMB; ai++) {
            if (!_ambActive[ai]) { continue; }
            var fx2 = _ambX[ai];
            if (fx2 >= _rodTipX.toFloat()) { continue; }
            var fp = (_rodTipX.toFloat() - fx2) / maxTravel.toFloat() * 100.0;
            if (fp < 2.0 || fp > 100.0) { continue; }
            var mrkX = bX + (fp / 100.0 * bW.toFloat()).toNumber();
            dc.setColor(getFishColorType(_ambType[ai]), Graphics.COLOR_TRANSPARENT); dc.fillCircle(mrkX, bY + bH + 4, 3);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(mrkX, bY + bH + 4, 1);
            var fdx = prevX - fx2; if (fdx < 0.0) { fdx = -fdx; }
            if (fdx < nearDist2) { nearDist2 = fdx; nearName = _fishNames[_ambType[ai]]; }
        }
        if (nearDist2 < 28.0 && nearName.length() > 0) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, bY - 28, Graphics.FONT_XTINY, nearName + "!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawWaitInd(dc) {
        var dots = (_tick / 7) % 4; var txt = "Waiting";
        for (var d = 0; d < dots; d++) { txt += "."; }
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 84 / 100, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
        if (_nearAmbIdx >= 0 && _nearAmbIdx < MAX_AMB) {
            dc.setColor(0xFFCC66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h * 76 / 100, Graphics.FONT_XTINY, "Target: " + _fishNames[_ambType[_nearAmbIdx]], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawBiteAlert(dc) {
        var fc = (_tick % 3 < 2) ? 0xFF4444 : 0xFFAA22;
        var biteY = _h * 18 / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 1, biteY + 1, Graphics.FONT_SMALL, "BITE!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, biteY, Graphics.FONT_SMALL, "BITE!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 82 / 100, Graphics.FONT_XTINY, "TAP NOW!", Graphics.TEXT_JUSTIFY_CENTER);
        var tlW = _w * 42 / 100; var tlX = (_w - tlW) / 2; var tlY = _h * 88 / 100;
        dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tlX, tlY, tlW, 5);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tlX, tlY, (90 - _biteTick) * tlW / 90, 5);
    }

    hidden function drawFightHUD(dc) {
        // ── Tension bar (top) ─────────────────────────────────────────────
        var tBarY = _h * 8 / 100; var tBW = _w * 65 / 100; var tBX = (_w - tBW) / 2;
        dc.setColor(0x181828, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tBX - 1, tBarY - 1, tBW + 2, 12);
        dc.setColor(0x282838, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tBX, tBarY, tBW, 10);
        var tf = (_tension / _maxTension * tBW.toFloat()).toNumber();
        var tc = 0x33CC44;
        if (_tension > 80.0)      { tc = (_tick % 4 < 2) ? 0xFF2222 : 0xCC0000; }
        else if (_tension > 62.0) { tc = 0xFF8822; }
        else if (_tension > 42.0) { tc = 0xFFCC44; }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tBX, tBarY, tf, 10);
        if (_tension > 80.0) {
            dc.setColor((_tick % 3 < 2) ? 0xFF2222 : 0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(tBX + tBW + 4, tBarY - 2, Graphics.FONT_XTINY, "!", Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(4, tBarY + 12, Graphics.FONT_XTINY, _fishNames[_fishType], Graphics.TEXT_JUSTIFY_LEFT);
        var hpW = _w * 26 / 100; var hpFill = (_fishHP / _fishMaxHP * hpW.toFloat()).toNumber(); if (hpFill < 0) { hpFill = 0; }
        dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w - 4 - hpW, tBarY + 12, hpW, 4);
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w - 4 - hpW, tBarY + 12, hpFill, 4);

        // ── Tug-of-war fight bar (center) ────────────────────────────────
        // _fightCursor: -100 (far left) to +100 (far right)
        // Fish pushes it toward its escape direction; player tilts opposite to fight back.
        var fBH = 16; var fBW = _w * 82 / 100; var fBX = (_w - fBW) / 2;
        var fBarY = _h * 43 / 100;

        // Background shell
        dc.setColor(0x050A14, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(fBX - 2, fBarY - 2, fBW + 4, fBH + 4);

        // Red danger zones (outer 20% each side)
        dc.setColor(0x2A0808, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fBX, fBarY, fBW * 20 / 100, fBH);
        dc.fillRectangle(fBX + fBW * 80 / 100, fBarY, fBW * 20 / 100, fBH);

        // Yellow warning zones (next 15% each side)
        dc.setColor(0x201800, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fBX + fBW * 20 / 100, fBarY, fBW * 15 / 100, fBH);
        dc.fillRectangle(fBX + fBW * 65 / 100, fBarY, fBW * 15 / 100, fBH);

        // Green safe zone (center 30%)
        dc.setColor(0x081808, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(fBX + fBW * 35 / 100, fBarY, fBW * 30 / 100, fBH);

        // Zone separators
        dc.setColor(0x224422, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(fBX + fBW * 35 / 100, fBarY, fBX + fBW * 35 / 100, fBarY + fBH);
        dc.drawLine(fBX + fBW * 65 / 100, fBarY, fBX + fBW * 65 / 100, fBarY + fBH);

        // Fight cursor  (_fightCursor in -100..+100 → 0..fBW)
        var cursorX = fBX + ((_fightCursor + 100.0) / 200.0 * fBW.toFloat()).toNumber();
        if (cursorX < fBX + 4) { cursorX = fBX + 4; }
        if (cursorX > fBX + fBW - 4) { cursorX = fBX + fBW - 4; }
        var absCursor = _fightCursor; if (absCursor < 0.0) { absCursor = -absCursor; }
        var cc;
        if (absCursor < 28.0)      { cc = 0x44FF66; }
        else if (absCursor < 62.0) { cc = 0xFFCC44; }
        else                       { cc = (_tick % 4 < 2) ? 0xFF3333 : 0xFF8844; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cursorX - 4, fBarY - 2, 8, fBH + 4);
        dc.setColor(cc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cursorX - 3, fBarY - 1, 6, fBH + 2);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cursorX - 1, fBarY + 2, 2, fBH - 4);

        // ── Accelerometer indicator (below fight bar) ─────────────────────
        // Shows current tilt direction so player knows their input
        var aBarY = fBarY + fBH + 6; var aBarW = _w * 55 / 100; var aBarX = (_w - aBarW) / 2;
        dc.setColor(0x0C1422, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(aBarX, aBarY, aBarW, 5);
        // Centre tick
        dc.setColor(0x1C2840, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(aBarX + aBarW / 2 - 1, aBarY - 1, 2, 7);
        var aPos = aBarX + aBarW / 2 + (accelX.toFloat() * aBarW.toFloat() / 2200.0).toNumber();
        if (aPos < aBarX + 2) { aPos = aBarX + 2; }
        if (aPos > aBarX + aBarW - 2) { aPos = aBarX + aBarW - 2; }
        dc.setColor(0x4488FF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(aPos - 3, aBarY - 1, 6, 7);

        // ── Fish direction + counter-tilt hint ────────────────────────────
        var fishGoesRight = (_fishPullDir < 100.0);
        var dirTxt    = fishGoesRight ? "FISH >>>" : "<<< FISH";
        var counterTxt = fishGoesRight ? "<< TILT" : "TILT >>";
        var hintY = _h * 66 / 100;
        dc.setColor((_tick % 8 < 5) ? 0xFF8844 : 0xFF5500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, hintY, Graphics.FONT_XTINY, dirTxt, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 6 < 3) ? 0x66FF88 : 0x44CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, hintY + 14, Graphics.FONT_XTINY, counterTxt, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x4477AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h * 84 / 100, Graphics.FONT_XTINY, "Tap = reel boost", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawReelAnim(dc) {
        var ry = _h * 20 / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 1, ry + 1, Graphics.FONT_SMALL, "REELING!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 6 < 3) ? 0x44FF88 : 0x22CC66, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, ry, Graphics.FONT_SMALL, "REELING!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawResultMsg(dc) {
        if (gameState == GS_CAUGHT) {
            var msgY = _h * 20 / 100;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 1, msgY + 1, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, msgY, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 68 / 100, Graphics.FONT_XTINY, "+" + _lastPts + " pts", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 78 / 100, Graphics.FONT_XTINY, _levelCatches + "/" + _goalCount + " this level", Graphics.TEXT_JUSTIFY_CENTER);
            if (_combo > 1) { dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 87 / 100, Graphics.FONT_XTINY, "COMBO x" + _combo, Graphics.TEXT_JUSTIFY_CENTER); }
        } else {
            var mc = (gameState == GS_SNAP) ? 0xFF4444 : 0xFF8844;
            var msgY2 = _h * 26 / 100;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 1, msgY2 + 1, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(mc, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, msgY2, Graphics.FONT_SMALL, _resultMsg, Graphics.TEXT_JUSTIFY_CENTER);
            var heartStr = ""; for (var li = 0; li < _fishLives; li++) { heartStr = heartStr + "*"; }
            dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 46 / 100, Graphics.FONT_XTINY, _fishLives > 0 ? heartStr : "GAME OVER!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawCaughtFish(dc, ox, oy) {
        var animY = _waterY - 35 + oy - _resultTick * 2 / 3;
        var minY = _h * 38 / 100 + oy;
        if (animY < minY) { animY = minY; }
        var fx2 = _cx + ox; var fy2 = animY;
        var sz = _fishSize + 8;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx2 + 4, fy2 + 4, sz + 1);
        var bodyC = getFishColor(); var bellyC = getFishBellyType(_fishType);
        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(fx2, fy2, sz); dc.fillCircle(fx2 + sz * 6 / 10, fy2, sz * 8 / 10);
        dc.fillCircle(fx2 - sz * 4 / 10, fy2, sz * 7 / 10);
        dc.fillCircle(fx2 - (sz + 3), fy2 - sz / 3, sz / 3 + 2); dc.fillCircle(fx2 - (sz + 3), fy2 + sz / 3, sz / 3 + 2);
        dc.setColor(bellyC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx2, fy2 + sz / 3, sz / 2);
        if (_fishType >= 4) { dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[fx2, fy2 - sz + 2], [fx2 - 5, fy2 - sz - 7], [fx2 + 5, fy2 - sz - 7]]); }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx2 + sz - 4, fy2 - 3, 5);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx2 + sz - 3, fy2 - 3, 3);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx2 + sz - 1, fy2 - 5, 1);
        if (_resultTick < 22) {
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 4; sp++) {
                var sa = sp * 90 + _resultTick * 9;
                var srad = sa.toFloat() * 3.14159 / 180.0;
                dc.fillCircle(fx2 + ((sz + 7).toFloat() * Math.cos(srad)).toNumber(), fy2 + ((sz + 7).toFloat() * Math.sin(srad)).toNumber(), 2);
            }
        }
        var wTxt;
        if (_fishWeight >= 1000) {
            var kg = _fishWeight / 1000; var dg = (_fishWeight % 1000) / 100;
            wTxt = "" + kg + "." + dg + " kg";
        } else { wTxt = "" + _fishWeight + " g"; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(fx2 + 1, fy2 + sz + 5, Graphics.FONT_SMALL, wTxt, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT); dc.drawText(fx2, fy2 + sz + 4, Graphics.FONT_SMALL, wTxt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawParticles(dc, ox, oy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            dc.setColor(_partColor[i], Graphics.COLOR_TRANSPARENT);
            var ps = (_partLife[i] > 6) ? 2 : 1;
            dc.fillRectangle(_partX[i].toNumber() + ox, _partY[i].toNumber() + oy, ps, ps);
        }
    }

    hidden function drawHUD(dc) {
        dc.setColor(0xEEFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w - 4, 2, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);
        var heartStr = ""; for (var li = 0; li < _fishLives; li++) { heartStr = heartStr + "*"; }
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT); dc.drawText(_w - 4, 14, Graphics.FONT_XTINY, heartStr, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.drawText(4, 2, Graphics.FONT_XTINY, "Lv" + _level, Graphics.TEXT_JUSTIFY_LEFT);
        var goalTxt = _levelCatches + "/" + _goalCount;
        if (_goalMinType > 0 && !_levelGotSpecial) { goalTxt = goalTxt + " +" + _fishNames[_goalMinType]; }
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT); dc.drawText(4, 14, Graphics.FONT_XTINY, goalTxt, Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function drawGameOver(dc) {
        dc.setColor(0x060E18, 0x060E18); dc.clear();
        dc.setColor(0x2A0808, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 36 / 100, _w, _h * 28 / 100);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 2, _h * 12 / 100 + 2, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_resultTick % 8 < 4) ? 0xFF4444 : 0xCC2222, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 12 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 34 / 100, Graphics.FONT_SMALL, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 50 / 100, Graphics.FONT_XTINY, "Fish: " + _fishCaught + "  Lv: " + _level, Graphics.TEXT_JUSTIFY_CENTER);
        if (_score >= _bestScore && _score > 0) { dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 62 / 100, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER); }
        else if (_bestScore > 0) { dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 62 / 100, Graphics.FONT_XTINY, "Best: " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor((_tick % 10 < 5) ? 0x44CCFF : 0x33AADD, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 82 / 100, Graphics.FONT_XTINY, "Tap to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x1E6FAA, 0x1E6FAA); dc.clear();
        dc.setColor(0x3399CC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, 0, _w, _waterY);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT); dc.fillCircle(26, 22, 12); dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT); dc.fillCircle(26, 22, 7);
        for (var i = 0; i < 3; i++) {
            dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cloudX[i].toNumber(), _cloudY[i], 9 + i * 2); dc.fillCircle(_cloudX[i].toNumber() + 10, _cloudY[i] + 1, 7 + i);
        }
        dc.setColor(0x165688, 0x165688); dc.fillRectangle(0, _waterY, _w, _h - _waterY);
        for (var x = 0; x < _w; x += 5) {
            var wh = (Math.sin((x.toFloat() + _waveOff * 15.0) * 0.09) * 2.0).toNumber();
            dc.setColor(0x2475AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(x, _waterY + wh, 5, 2);
        }
        dc.setColor(0x0C3660, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _waterY + 4, _w, _h - _waterY - 4);
        for (var i = 0; i < MAX_AMB; i++) {
            if (!_ambActive[i]) { continue; }
            var fx = _ambX[i].toNumber(); var fy = _ambY[i].toNumber();
            if (fy <= _waterY + 2) { continue; }
            var t = _ambType[i]; var sz = 4 + t; if (sz > 11) { sz = 11; }
            var dir = (_ambVx[i] >= 0.0) ? 1 : -1;
            var wv2 = (Math.sin((_tick.toFloat() * 0.12 + i.toFloat() * 1.1)) * 1.5).toNumber();
            fy += wv2;
            dc.setColor(getFishColorType(t), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fx, fy, sz); dc.fillCircle(fx + dir * sz * 6 / 10, fy, sz * 7 / 10);
            dc.fillCircle(fx - dir * (sz + 2), fy - sz / 3, sz / 3); dc.fillCircle(fx - dir * (sz + 2), fy + sz / 3, sz / 3);
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT); dc.fillCircle(fx + dir * (sz - 1), fy - 1, 1);
        }
        dc.setColor(0x0A1E30, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx + 1, _h * 4 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 14 < 7) ? 0x55DDFF : 0x33BBDD, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 4 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 18 / 100, Graphics.FONT_LARGE, "FISH", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCEE, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 30 / 100, Graphics.FONT_XTINY, "Cast near the fish!", Graphics.TEXT_JUSTIFY_CENTER);
        if (_bestScore > 0) { dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 78 / 100, Graphics.FONT_XTINY, "BEST " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor((_tick % 10 < 5) ? 0x55DDFF : 0x33BBDD, Graphics.COLOR_TRANSPARENT); dc.drawText(_cx, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to fish", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
