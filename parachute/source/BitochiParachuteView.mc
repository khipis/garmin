using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum { PS_MENU, PS_JUMP, PS_FREE, PS_CHUTE, PS_LAND, PS_CRASH, PS_GAMEOVER }

const LB_GAME_ID = "parachute";

// Module-level ref so the timer chain isn't GC'd after the run ends.
var _paraSender = null;

// ── Sequential leaderboard submitter ──────────────────────────────────────────
// Garmin permits only one pending makeWebRequest, so the primary (wind variant)
// score, the secondary "rings" variant, and the post-game card fetch must be
// spaced out. Mirrors Activity Board's FlexBatchSender pattern.
class ParaSubmitter {
    hidden var _game;
    hidden var _score;
    hidden var _ringsTot;
    hidden var _variant;
    hidden var _title;
    hidden var _idx;
    hidden var _timer;

    function initialize(game, score, ringsTot, variant, title) {
        _game = game; _score = score; _ringsTot = ringsTot;
        _variant = variant; _title = title; _idx = 0; _timer = null;
    }

    function start() as Void { _step(); }

    function _step() as Void {
        if (_idx == 0) {
            Leaderboard.submitScore(_game, _score, _variant);
            _idx = 1;
            if (_timer == null) { _timer = new Timer.Timer(); }
            _timer.start(method(:_step), 2800, false);   // let the Daily hook settle
        } else if (_idx == 1) {
            Leaderboard.submitScoreAux(_game, _ringsTot, "rings");
            _idx = 2;
            if (_timer == null) { _timer = new Timer.Timer(); }
            _timer.start(method(:_step), 1400, false);
        } else {
            if (_timer != null) { try { _timer.stop(); } catch (e) {} _timer = null; }
            Leaderboard.showPostGame(_game, _variant, _title);
            _paraSender = null;
        }
    }
}

class BitochiParachuteView extends WatchUi.View {

    var accelX;
    var accelY;
    var accelZ;
    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _timer;
    hidden var _tick;

    hidden var _playerX;
    hidden var _playerVx;
    hidden var _altitude;
    hidden var _maxAlt;
    hidden var _fallSpeed;
    hidden var _chuteOpen;

    hidden const MAX_RINGS = 24;
    hidden var _ringX;
    hidden var _ringY;
    hidden var _ringR;
    hidden var _ringType;      // 0 normal, 1 gold, 2 STAR
    hidden var _ringActive;
    hidden var _ringSpawnAcc;
    hidden var _ringsHit;
    hidden var _ringStreak;
    hidden var _ringTotal;

    hidden var _landX;
    hidden var _landR;

    hidden var _windX;
    hidden var _windPhase;

    // Wind setting from the shared OPTIONS screen (pc_wind: 0=Calm 1=Breezy
    // 2=Gusty). Scales horizontal wind + gust strength and segments the LB.
    hidden var _windSetting;   // 0/1/2 index
    hidden var _windMul;       // multiplier applied to wind amplitude/gusts

    hidden var _score;
    hidden var _totalScore;
    hidden var _bestScore;
    hidden var _level;
    hidden var _bestLevel;
    hidden var _landDist;
    hidden var _landGrade;
    hidden var _lives;
    hidden var _lifeLost;
    hidden var _gustX;
    hidden var _gustDecay;
    hidden var _gustSpawnTimer;
    hidden var _landVx;

    // ── Per-level bonus accumulators ──────────────────────────────────────────
    hidden var _starBonus;      // points from STAR pickups this level
    hidden var _styleScore;     // points from freefall spin tricks this level
    hidden var _hazardPenalty;  // points lost to bird strikes this level
    hidden var _starsHit;       // stars grabbed this level (for display)

    // ── Run totals (for secondary leaderboard + best-tricks) ─────────────────
    hidden var _ringsRunTotal;
    hidden var _tricksThisRun;
    hidden var _bestTricks;

    // ── Freefall spin/trick state ─────────────────────────────────────────────
    hidden var _spinAngle;      // visual rotation (degrees, unbounded)
    hidden var _spinSpeed;      // current spin velocity (deg/tick)
    hidden var _spinProgress;   // accumulated toward next full-spin trick

    hidden const MAX_PARTS = 40;
    hidden var _partX;
    hidden var _partY;
    hidden var _partVx;
    hidden var _partVy;
    hidden var _partLife;
    hidden var _partColor;
    hidden var _partGrav;       // per-particle gravity (0 = ring burst, >0 = confetti/feathers)

    hidden const MAX_LINES = 8;
    hidden var _lineX;
    hidden var _lineY;
    hidden var _lineLen;
    hidden var _lineLife;

    // ── Floating score popups ─────────────────────────────────────────────────
    hidden const MAX_POPS = 6;
    hidden var _popText;
    hidden var _popX;
    hidden var _popY;
    hidden var _popVy;
    hidden var _popLife;
    hidden var _popColor;
    hidden var _popBig;

    // ── Bird hazards (dodge during freefall) ──────────────────────────────────
    hidden const MAX_BIRDS = 5;
    hidden var _birdX;
    hidden var _birdY;
    hidden var _birdVx;
    hidden var _birdActive;
    hidden var _birdFlap;
    hidden var _birdWarn;
    hidden var _birdSpawnAcc;

    hidden var _cloudX;
    hidden var _cloudY;
    hidden var _cloudW;
    hidden var _cloudZ;         // parallax depth 0.3..1.0 (near = bigger/faster)

    hidden const STARS = 14;
    hidden var _starX;
    hidden var _starY;
    hidden var _starPh;

    hidden var _jumpTick;
    hidden var _resultTick;
    hidden var _landAnimY;
    hidden var _shakeT;
    hidden var _flashT;
    hidden var _hurtFlash;      // red vignette after a bird strike
    hidden var _comboFlash;     // combo/trick emphasis timer
    hidden var _perfectCelebrate; // confetti timer on a great landing
    hidden var _focus;          // slow-mo precision near the ground under chute

    hidden var _menuSel;
    hidden var _lbX;
    hidden var _lbY;
    hidden var _lbW;
    hidden var _lbH;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        accelX = 0; accelY = 0; accelZ = 0;
        _tick = 0; _level = 1; _lives = 3; _lifeLost = false;
        var bs = Application.Storage.getValue("paraBest");
        _bestScore = (bs != null) ? bs : 0;
        var bl = Application.Storage.getValue("paraLevel");
        _bestLevel = (bl != null) ? bl : 0;
        var bt = Application.Storage.getValue("paraTricks");
        _bestTricks = (bt != null) ? bt : 0;
        _totalScore = 0;
        _gustX = 0.0; _gustDecay = 0; _gustSpawnTimer = 80;
        _landVx = 0.0;

        _starBonus = 0; _styleScore = 0; _hazardPenalty = 0; _starsHit = 0;
        _ringsRunTotal = 0; _tricksThisRun = 0;
        _spinAngle = 0.0; _spinSpeed = 0.0; _spinProgress = 0.0;

        _ringX = new [MAX_RINGS]; _ringY = new [MAX_RINGS];
        _ringR = new [MAX_RINGS]; _ringType = new [MAX_RINGS]; _ringActive = new [MAX_RINGS];
        for (var i = 0; i < MAX_RINGS; i++) { _ringX[i] = 0; _ringY[i] = 0; _ringR[i] = 0; _ringType[i] = 0; _ringActive[i] = false; }

        _partX = new [MAX_PARTS]; _partY = new [MAX_PARTS];
        _partVx = new [MAX_PARTS]; _partVy = new [MAX_PARTS];
        _partLife = new [MAX_PARTS]; _partColor = new [MAX_PARTS]; _partGrav = new [MAX_PARTS];
        for (var i = 0; i < MAX_PARTS; i++) { _partX[i] = 0.0; _partY[i] = 0.0; _partVx[i] = 0.0; _partVy[i] = 0.0; _partLife[i] = 0; _partColor[i] = 0; _partGrav[i] = 0.0; }

        _lineX = new [MAX_LINES]; _lineY = new [MAX_LINES];
        _lineLen = new [MAX_LINES]; _lineLife = new [MAX_LINES];
        for (var i = 0; i < MAX_LINES; i++) { _lineX[i] = 0; _lineY[i] = 0; _lineLen[i] = 0; _lineLife[i] = 0; }

        _popText = new [MAX_POPS]; _popX = new [MAX_POPS]; _popY = new [MAX_POPS];
        _popVy = new [MAX_POPS]; _popLife = new [MAX_POPS]; _popColor = new [MAX_POPS]; _popBig = new [MAX_POPS];
        for (var i = 0; i < MAX_POPS; i++) { _popText[i] = ""; _popX[i] = 0; _popY[i] = 0.0; _popVy[i] = 0.0; _popLife[i] = 0; _popColor[i] = 0xFFFFFF; _popBig[i] = false; }

        _birdX = new [MAX_BIRDS]; _birdY = new [MAX_BIRDS]; _birdVx = new [MAX_BIRDS];
        _birdActive = new [MAX_BIRDS]; _birdFlap = new [MAX_BIRDS]; _birdWarn = new [MAX_BIRDS];
        for (var i = 0; i < MAX_BIRDS; i++) { _birdX[i] = 0.0; _birdY[i] = 0.0; _birdVx[i] = 0.0; _birdActive[i] = false; _birdFlap[i] = 0; _birdWarn[i] = 0; }
        _birdSpawnAcc = 0.0;

        _cloudX = new [6]; _cloudY = new [6]; _cloudW = new [6]; _cloudZ = new [6];
        for (var i = 0; i < 6; i++) { _cloudX[i] = Math.rand().abs() % _w; _cloudY[i] = Math.rand().abs() % _h; _cloudW[i] = 12 + Math.rand().abs() % 16; _cloudZ[i] = 0.3 + (Math.rand().abs() % 70).toFloat() / 100.0; }

        _starX = new [STARS]; _starY = new [STARS]; _starPh = new [STARS];
        for (var i = 0; i < STARS; i++) { _starX[i] = Math.rand().abs() % _w; _starY[i] = Math.rand().abs() % (_h * 3 / 4); _starPh[i] = Math.rand().abs() % 40; }

        _playerX = 0.0; _playerVx = 0.0; _landAnimY = 0.0;
        _altitude = 3000.0; _maxAlt = 3000.0; _fallSpeed = 0.0; _chuteOpen = false;
        _windX = 0.0; _windPhase = 0.0;
        _score = 0; _ringsHit = 0; _ringStreak = 0; _ringTotal = 0; _ringSpawnAcc = 0.0;
        _landX = 0; _landR = 20; _landDist = 0.0; _landGrade = "";
        _jumpTick = 0; _resultTick = 0; _shakeT = 0; _flashT = 0;
        _hurtFlash = 0; _comboFlash = 0; _perfectCelebrate = 0; _focus = false;
        _menuSel = 0; _lbX = 0; _lbY = 0; _lbW = 0; _lbH = 0;

        // Wind strength from the shared OPTIONS screen (pc_wind: 0/1/2,
        // default 1 = Breezy so the default run matches today's wind).
        _windSetting = 1;
        var pw = Application.Storage.getValue("pc_wind");
        if (pw instanceof Number && pw >= 0 && pw <= 2) { _windSetting = pw; }
        _windMul = [0.45, 1.0, 1.65][_windSetting];

        gameState = PS_MENU;
    }

    // Leaderboard variant = wind setting, so Calm/Breezy/Gusty rank separately.
    hidden function _windVariant() {
        return ["calm", "breezy", "gusty"][_windSetting];
    }

    // Time-of-day / biome cycles every level: 0 day, 1 sunset, 2 night, 3 dawn.
    hidden function _biome() {
        return (_level - 1).toNumber() % 4;
    }

    hidden function _lerpC(c1, c2, t) {
        if (t < 0.0) { t = 0.0; } if (t > 1.0) { t = 1.0; }
        var r1 = (c1 >> 16) & 0xFF; var g1 = (c1 >> 8) & 0xFF; var b1 = c1 & 0xFF;
        var r2 = (c2 >> 16) & 0xFF; var g2 = (c2 >> 8) & 0xFF; var b2 = c2 & 0xFF;
        var r = (r1 + (r2 - r1).toFloat() * t).toNumber();
        var g = (g1 + (g2 - g1).toFloat() * t).toNumber();
        var b = (b1 + (b2 - b1).toFloat() * t).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    function onShow() {
        _timer = new Timer.Timer(); _timer.start(method(:onTick), 33, true);
        // The main menu is the shared root view; drop straight into a run.
        // Only auto-start from a fresh launch (PS_MENU) so returning from the
        // post-game leaderboard card doesn't restart the run.
        if (gameState == PS_MENU) { startRun(); }
    }
    function onHide() { if (_timer != null) { _timer.stop(); _timer = null; } }

    hidden function startRun() {
        _level = 1; _totalScore = 0; _lives = 3;
        _ringsRunTotal = 0; _tricksThisRun = 0;
        startLevel();
    }

    function onTick() as Void {
        _tick++;
        if (_shakeT > 0) { _shakeT--; }
        if (_flashT > 0) { _flashT--; }
        if (_hurtFlash > 0) { _hurtFlash--; }
        if (_comboFlash > 0) { _comboFlash--; }

        for (var i = 0; i < 6; i++) {
            var drift = 1.0 + _cloudZ[i] * 1.5;
            var extra = 0.0;
            if (gameState == PS_FREE) { extra = _fallSpeed * 0.6 * _cloudZ[i]; }
            else if (gameState == PS_CHUTE) { extra = _fallSpeed * 0.3 * _cloudZ[i]; }
            _cloudY[i] -= (drift + extra).toNumber();
            if (_cloudY[i] < -30) {
                _cloudY[i] = _h + 10 + Math.rand().abs() % 30; _cloudX[i] = Math.rand().abs() % _w;
                _cloudW[i] = 12 + Math.rand().abs() % 16; _cloudZ[i] = 0.3 + (Math.rand().abs() % 70).toFloat() / 100.0;
            }
        }
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            _partVy[i] += _partGrav[i];
            _partX[i] += _partVx[i]; _partY[i] += _partVy[i]; _partLife[i]--;
        }
        for (var i = 0; i < MAX_LINES; i++) { if (_lineLife[i] > 0) { _lineLife[i]--; } }
        for (var i = 0; i < MAX_POPS; i++) { if (_popLife[i] > 0) { _popY[i] += _popVy[i]; _popLife[i]--; } }

        if (gameState == PS_JUMP) { _jumpTick++; if (_jumpTick >= 35) { gameState = PS_FREE; } }
        else if (gameState == PS_FREE) { updateFreefall(); }
        else if (gameState == PS_CHUTE) { updateChute(); }
        else if (gameState == PS_LAND || gameState == PS_CRASH || gameState == PS_GAMEOVER) {
            _resultTick++;
            if (_perfectCelebrate > 0) {
                _perfectCelebrate--;
                if (_perfectCelebrate % 7 == 0) { spawnConfetti(); }
            }
        }

        WatchUi.requestUpdate();
    }

    hidden function startLevel() {
        _playerX = (_w / 2).toFloat(); _playerVx = 0.0;
        _altitude = 3000.0 + _level * 380.0 + (_level / 3) * 100.0; _maxAlt = _altitude;
        _fallSpeed = 0.0; _chuteOpen = false; _lifeLost = false;
        _ringsHit = 0; _ringStreak = 0; _ringTotal = 0; _ringSpawnAcc = 0.0;
        _windPhase = 0.0; _windX = 0.0;
        _jumpTick = 0; _resultTick = 0; _score = 0;
        _gustX = 0.0; _gustDecay = 0;
        _gustSpawnTimer = 120 - _level * 4;
        if (_gustSpawnTimer < 40) { _gustSpawnTimer = 40; }

        _starBonus = 0; _styleScore = 0; _hazardPenalty = 0; _starsHit = 0;
        _spinAngle = 0.0; _spinSpeed = 0.0; _spinProgress = 0.0;
        _birdSpawnAcc = 0.0; _focus = false; _perfectCelebrate = 0;

        _landX = _w / 2 + (Math.rand().abs() % 40) - 20;
        _landR = 28 - _level / 2;
        if (_landR < 10) { _landR = 10; }

        _landVx = 0.0;
        if (_level >= 6) {
            var driftSpd = 0.25 + (_level - 6).toFloat() * 0.04;
            if (driftSpd > 0.9) { driftSpd = 0.9; }
            _landVx = (Math.rand().abs() % 2 == 0) ? driftSpd : -driftSpd;
        }

        if (_level == 5 || _level == 10 || _level == 15) {
            if (_lives < 3) { _lives++; doVibe(80, 200); }
        }

        if (_level > _bestLevel) {
            _bestLevel = _level;
            Application.Storage.setValue("paraLevel", _bestLevel);
        }

        for (var i = 0; i < MAX_RINGS; i++) { _ringActive[i] = false; }
        for (var i = 0; i < MAX_PARTS; i++) { _partLife[i] = 0; }
        for (var i = 0; i < MAX_LINES; i++) { _lineLife[i] = 0; }
        for (var i = 0; i < MAX_POPS; i++) { _popLife[i] = 0; }
        for (var i = 0; i < MAX_BIRDS; i++) { _birdActive[i] = false; }
        gameState = PS_JUMP;
    }

    hidden function updateGusts() {
        if (_level < 4) { _gustX = 0.0; return; }
        _gustSpawnTimer--;
        if (_gustSpawnTimer <= 0) {
            var maxForce = 0.5 + (_level - 4).toFloat() * 0.12;
            if (maxForce > 2.4) { maxForce = 2.4; }
            maxForce = maxForce * _windMul;   // Calm/Breezy/Gusty wind setting
            _gustX = (Math.rand().abs() % 2 == 0 ? 1.0 : -1.0) * (0.4 + (Math.rand().abs() % 10).toFloat() / 10.0 * maxForce);
            _gustDecay = 20 + Math.rand().abs() % 35;
            _gustSpawnTimer = 50 + Math.rand().abs() % 90;
        }
        if (_gustDecay > 0) {
            _gustDecay--;
            if (_gustDecay == 0) { _gustX = 0.0; }
        }
    }

    hidden function updateFreefall() {
        var grav = 0.11 + (_level / 12).toFloat() * 0.02;
        if (grav > 0.15) { grav = 0.15; }
        _fallSpeed += grav;
        var termV = 6.5 + (_level / 8).toFloat() * 0.35;
        if (termV > 7.4) { termV = 7.4; }
        if (_fallSpeed > termV) { _fallSpeed = termV; }
        _altitude -= _fallSpeed;
        if (_altitude < 0.0) { _altitude = 0.0; }

        _windPhase += 0.06;
        var wAmp = 0.55 + _level.toFloat() * 0.14 + (_level / 4).toFloat() * 0.05;
        if (wAmp > 1.8) { wAmp = 1.8; }
        wAmp = wAmp * _windMul;   // Calm/Breezy/Gusty wind setting
        _windX = Math.sin(_windPhase) * wAmp;

        updateGusts();

        var steerX = accelX.toFloat() / 280.0;
        if (steerX > 3.5) { steerX = 3.5; } if (steerX < -3.5) { steerX = -3.5; }
        _playerVx = _playerVx * 0.85 + steerX + _windX * 0.06 + _gustX * 0.05;
        _playerX += _playerVx;
        if (_playerX < 12.0) { _playerX = 12.0; _playerVx = 0.0; }
        if (_playerX > (_w - 12).toFloat()) { _playerX = (_w - 12).toFloat(); _playerVx = 0.0; }

        updateSpin(steerX);

        spawnRings();
        moveRings(_fallSpeed);
        checkRingHits();
        spawnBirds();
        moveBirds(_fallSpeed);
        checkBirdHits();
        spawnSpeedLines();

        if (_altitude <= 0.0) {
            _lives--;
            if (_lives < 0) { _lives = 0; }
            _landGrade = "SPLAT!";
            doVibe(100, 500); _shakeT = 15; _flashT = 8;
            finalScore(false);
            if (_lives <= 0) {
                gameState = PS_GAMEOVER; _resultTick = 0; submitAll();
            }
            else { gameState = PS_CRASH; _resultTick = 0; }
        }
    }

    // Hard tilt during high-altitude freefall spins the diver for a style bonus.
    hidden function updateSpin(steerX) {
        var absSteer = steerX; if (absSteer < 0.0) { absSteer = -absSteer; }
        if (absSteer > 1.8 && _altitude > 500.0) {
            _spinSpeed = steerX * 9.0;
            _spinAngle += _spinSpeed;
            var adv = _spinSpeed; if (adv < 0.0) { adv = -adv; }
            _spinProgress += adv;
            if (_spinProgress >= 360.0) {
                _spinProgress -= 360.0;
                _tricksThisRun++;
                _styleScore += 75;
                _comboFlash = 12;
                spawnPopup("SPIN +75", _playerX.toNumber(), _h * 20 / 100, 0xEE66FF, true);
                doVibe(45, 90);
            }
        } else {
            _spinSpeed = _spinSpeed * 0.6;
            _spinAngle += _spinSpeed;
        }
    }

    hidden function updateChute() {
        // Precision "focus" slow-mo near the ground for satisfying aiming.
        _focus = (_altitude < 260.0);
        var slow = _focus ? 0.55 : 1.0;

        _fallSpeed = _fallSpeed * 0.92;
        if (_fallSpeed < 2.4) { _fallSpeed = 2.4; }
        _altitude -= _fallSpeed * slow;
        if (_altitude < 0.0) { _altitude = 0.0; }

        _windPhase += 0.04;
        var wAmpC = 0.45 + _level.toFloat() * 0.10 + (_level / 4).toFloat() * 0.04;
        if (wAmpC > 1.4) { wAmpC = 1.4; }
        wAmpC = wAmpC * _windMul;   // Calm/Breezy/Gusty wind setting
        _windX = Math.sin(_windPhase) * wAmpC;

        updateGusts();

        var steerX = accelX.toFloat() / 200.0;
        if (steerX > 2.5) { steerX = 2.5; } if (steerX < -2.5) { steerX = -2.5; }
        _playerVx = _playerVx * 0.88 + steerX * 0.6 + _windX * 0.08 * slow + _gustX * 0.06 * slow;
        _playerX += _playerVx;
        if (_playerX < 12.0) { _playerX = 12.0; _playerVx = 0.0; }
        if (_playerX > (_w - 12).toFloat()) { _playerX = (_w - 12).toFloat(); _playerVx = 0.0; }

        if (_landVx != 0.0) {
            _landX += (_landVx * slow).toNumber();
            var margin = _landR + 8;
            if (_landX < margin) { _landX = margin; _landVx = -_landVx; }
            else if (_landX > _w - margin) { _landX = _w - margin; _landVx = -_landVx; }
        }

        moveRings(_fallSpeed);
        checkRingHits();

        if (_altitude <= 0.0) {
            var dx = _playerX - _landX.toFloat();
            _landDist = dx; if (_landDist < 0.0) { _landDist = -_landDist; }
            var lr = _landR.toFloat();
            var perfect = false;
            if (_landDist < lr * 0.28) { _landGrade = "PERFECT!"; perfect = true; }
            else if (_landDist < lr) { _landGrade = "BULLSEYE!"; perfect = true; }
            else if (_landDist < lr * 2.0) { _landGrade = "GREAT!"; }
            else if (_landDist < lr * 3.5) { _landGrade = "GOOD"; }
            else { _landGrade = "MISSED!"; }

            var ringsRequired = _level;
            if (_ringsHit < ringsRequired) {
                _lives--;
                if (_lives < 0) { _lives = 0; }
                _lifeLost = true;
                doVibe(90, 400); _shakeT = 10;
            } else {
                doVibe(50, 200); _shakeT = 4;
            }

            if (perfect && !_lifeLost) { _perfectCelebrate = 42; spawnConfetti(); doVibe(60, 250); }

            finalScore(true);
            _landAnimY = (_h * 10 / 100).toFloat();
            if (_lives <= 0) {
                gameState = PS_GAMEOVER; _resultTick = 0; submitAll();
            }
            else { gameState = PS_LAND; _resultTick = 0; }
        }
    }

    hidden function submitAll() {
        if (_tricksThisRun > _bestTricks) {
            _bestTricks = _tricksThisRun;
            Application.Storage.setValue("paraTricks", _bestTricks);
        }
        // Primary score = wind variant; secondary "rings" variant = collectibles.
        // Sequenced so the two submits + post-game card don't collide on the
        // single available web request.
        _paraSender = new ParaSubmitter(LB_GAME_ID, _totalScore, _ringsRunTotal, _windVariant(), "PARACHUTE");
        _paraSender.start();
    }

    hidden function spawnRings() {
        var spawnRate = 12.5 - _level.toFloat() * 0.32 - (_level / 4).toFloat() * 0.15;
        if (spawnRate < 6.0) { spawnRate = 6.0; }
        _ringSpawnAcc += 1.0;
        if (_ringSpawnAcc < spawnRate) { return; }
        _ringSpawnAcc = 0.0;
        if (_altitude < 400.0) { return; }

        for (var i = 0; i < MAX_RINGS; i++) {
            if (_ringActive[i]) { continue; }
            _ringX[i] = 20 + Math.rand().abs() % (_w - 40);
            _ringY[i] = _h + 10;
            _ringR[i] = 16 + Math.rand().abs() % 10;
            var roll = Math.rand().abs() % 100;
            if (roll < 4 && _level >= 2) { _ringType[i] = 2; _ringR[i] = 14; }   // rare STAR
            else if (roll % 8 == 0) { _ringType[i] = 1; }                        // gold
            else { _ringType[i] = 0; }
            _ringActive[i] = true;
            _ringTotal++;
            break;
        }
    }

    hidden function moveRings(speed) {
        var scrollSpeed = speed * 1.8;
        if (_chuteOpen) { scrollSpeed = speed * 1.2; }
        for (var i = 0; i < MAX_RINGS; i++) {
            if (!_ringActive[i]) { continue; }
            _ringY[i] -= scrollSpeed.toNumber();
            if (_ringY[i] < -30) { _ringActive[i] = false; }
        }
    }

    hidden function checkRingHits() {
        var py = _h * 28 / 100;
        for (var i = 0; i < MAX_RINGS; i++) {
            if (!_ringActive[i]) { continue; }
            var dy = _ringY[i] - py;
            if (dy < 0) { dy = -dy; }
            if (dy > 18) { continue; }
            var dx = _playerX - _ringX[i].toFloat();
            if (dx < 0.0) { dx = -dx; }
            if (dx < _ringR[i].toFloat()) {
                var t = _ringType[i];
                _ringActive[i] = false;
                _ringsHit++;
                _ringStreak++;
                _ringsRunTotal++;
                spawnRingParts(_ringX[i], _ringY[i], t);
                _flashT = 3;
                _comboFlash = 10;
                var mult = _ringStreak / 3 + 1;
                if (t == 2) {
                    _starBonus += 400; _starsHit++;
                    spawnPopup("STAR +400", _ringX[i], _ringY[i], 0xFFEE44, true);
                    doVibe(60, 140);
                } else {
                    var pts = 100 * mult;
                    var col = (t == 1) ? 0xFFDD44 : 0x66FF99;
                    spawnPopup("+" + pts, _ringX[i], _ringY[i], col, mult >= 3);
                    doVibe(35, 60);
                }
            }
        }
    }

    hidden function spawnBirds() {
        if (_level < 3) { return; }
        if (_altitude < 500.0) { return; }
        _birdSpawnAcc += 1.0;
        var rate = 95.0 - _level.toFloat() * 3.0;
        if (rate < 42.0) { rate = 42.0; }
        if (_birdSpawnAcc < rate) { return; }
        _birdSpawnAcc = 0.0;
        for (var i = 0; i < MAX_BIRDS; i++) {
            if (_birdActive[i]) { continue; }
            _birdX[i] = (10 + Math.rand().abs() % (_w - 20)).toFloat();
            _birdY[i] = (_h + 22).toFloat();
            var dir = (Math.rand().abs() % 2 == 0) ? 1.0 : -1.0;
            _birdVx[i] = dir * (0.5 + (Math.rand().abs() % 10).toFloat() / 10.0);
            _birdActive[i] = true;
            _birdFlap[i] = 0;
            _birdWarn[i] = 14;   // brief fade-in so it reads as "incoming"
            break;
        }
    }

    hidden function moveBirds(speed) {
        var sc = speed * 1.5;
        for (var i = 0; i < MAX_BIRDS; i++) {
            if (!_birdActive[i]) { continue; }
            _birdY[i] -= sc;
            _birdX[i] += _birdVx[i];
            if (_birdX[i] < 8.0) { _birdX[i] = 8.0; _birdVx[i] = -_birdVx[i]; }
            if (_birdX[i] > (_w - 8).toFloat()) { _birdX[i] = (_w - 8).toFloat(); _birdVx[i] = -_birdVx[i]; }
            _birdFlap[i] = (_birdFlap[i] + 1) % 12;
            if (_birdWarn[i] > 0) { _birdWarn[i]--; }
            if (_birdY[i] < -22.0) { _birdActive[i] = false; }
        }
    }

    hidden function checkBirdHits() {
        var py = (_h * 28 / 100).toFloat();
        for (var i = 0; i < MAX_BIRDS; i++) {
            if (!_birdActive[i]) { continue; }
            if (_birdWarn[i] > 0) { continue; }
            var dy = _birdY[i] - py; if (dy < 0.0) { dy = -dy; }
            if (dy > 14.0) { continue; }
            var dx = _playerX - _birdX[i]; if (dx < 0.0) { dx = -dx; }
            if (dx < 14.0) {
                _birdActive[i] = false;
                _hazardPenalty += 60;
                _ringStreak = 0;
                _playerVx += _birdVx[i] * 3.0;
                doVibe(80, 200); _shakeT = 10; _flashT = 4; _hurtFlash = 7;
                spawnPopup("OUCH -60", _playerX.toNumber(), _h * 20 / 100, 0xFF5544, true);
                spawnBirdFeathers(_birdX[i].toNumber(), _birdY[i].toNumber());
            }
        }
    }

    hidden function spawnRingParts(rx, ry, rType) {
        var colors = (rType == 2) ? [0xFFEE44, 0xFFFFFF, 0xFFCC00]
                   : ((rType == 1) ? [0xFFFF44, 0xFFDD22, 0xFFAA00] : [0x44FF88, 0x22DD66, 0x88FFAA]);
        var count = (rType == 2) ? 12 : 8;
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= count) { break; } if (_partLife[i] > 0) { continue; }
            _partX[i] = rx.toFloat(); _partY[i] = ry.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var sp = 1.5 + (Math.rand().abs() % 20).toFloat() / 10.0;
            _partVx[i] = sp * Math.cos(a); _partVy[i] = sp * Math.sin(a);
            _partLife[i] = 12 + Math.rand().abs() % 8;
            _partColor[i] = colors[Math.rand().abs() % 3];
            _partGrav[i] = 0.0;
            spawned++;
        }
    }

    hidden function spawnConfetti() {
        var colors = [0xFF4466, 0xFFCC22, 0x44CCFF, 0x66FF88, 0xEE66FF, 0xFFFFFF];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 14) { break; } if (_partLife[i] > 0) { continue; }
            _partX[i] = (Math.rand().abs() % _w).toFloat();
            _partY[i] = (-6 + Math.rand().abs() % 14).toFloat();
            _partVx[i] = ((Math.rand().abs() % 20).toFloat() - 10.0) / 12.0;
            _partVy[i] = 0.6 + (Math.rand().abs() % 14).toFloat() / 10.0;
            _partLife[i] = 26 + Math.rand().abs() % 14;
            _partColor[i] = colors[Math.rand().abs() % 6];
            _partGrav[i] = 0.16;
            spawned++;
        }
    }

    hidden function spawnBirdFeathers(fx, fy) {
        var colors = [0x99AAB8, 0x778899, 0xC0C8D0];
        var spawned = 0;
        for (var i = 0; i < MAX_PARTS; i++) {
            if (spawned >= 8) { break; } if (_partLife[i] > 0) { continue; }
            _partX[i] = fx.toFloat(); _partY[i] = fy.toFloat();
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var sp = 0.8 + (Math.rand().abs() % 12).toFloat() / 10.0;
            _partVx[i] = sp * Math.cos(a); _partVy[i] = sp * Math.sin(a) - 0.4;
            _partLife[i] = 16 + Math.rand().abs() % 10;
            _partColor[i] = colors[Math.rand().abs() % 3];
            _partGrav[i] = 0.12;
            spawned++;
        }
    }

    hidden function spawnPopup(txt, x, y, color, big) {
        for (var i = 0; i < MAX_POPS; i++) {
            if (_popLife[i] > 0) { continue; }
            _popText[i] = txt; _popX[i] = x; _popY[i] = y.toFloat();
            _popVy[i] = -0.9; _popLife[i] = big ? 26 : 20; _popColor[i] = color; _popBig[i] = big;
            return;
        }
    }

    hidden function spawnSpeedLines() {
        if (_fallSpeed < 2.0) { return; }
        if (_tick % 3 != 0) { return; }
        for (var i = 0; i < MAX_LINES; i++) {
            if (_lineLife[i] > 0) { continue; }
            _lineX[i] = Math.rand().abs() % _w;
            _lineY[i] = Math.rand().abs() % (_h / 3);
            _lineLen[i] = ((_fallSpeed - 1.0) * 4.0).toNumber() + 4;
            _lineLife[i] = 6 + Math.rand().abs() % 4;
            break;
        }
    }

    hidden function finalScore(landed) {
        var ringPts = 0;
        var mult = 1;
        for (var r = 0; r < _ringsHit; r++) {
            ringPts += 100 * mult;
            if ((r + 1) % 3 == 0 && mult < 5) { mult++; }
        }
        var landPts = 0;
        var perfectExtra = 0;
        if (landed) {
            var lr = _landR.toFloat();
            if (_landDist < lr) {
                landPts = 500;
                if (_landDist < lr * 0.28) {
                    perfectExtra = 280;
                } else if (_landDist < lr * 0.5) {
                    perfectExtra = 120;
                }
            } else if (_landDist < lr * 2.0) { landPts = 300; }
            else if (_landDist < lr * 3.5) { landPts = 150; }
            else { landPts = 50; }
        }
        _score = ringPts + landPts + perfectExtra + _starBonus + _styleScore - _hazardPenalty;
        if (_score < 0) { _score = 0; }
        _totalScore += _score;
        if (_totalScore > _bestScore) { _bestScore = _totalScore; Application.Storage.setValue("paraBest", _bestScore); }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) { if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
        } }
    }

    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _windVariant(), "PARACHUTE");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function menuMove(d) {
        _menuSel = (_menuSel + d) % 2;
        if (_menuSel < 0) { _menuSel = _menuSel + 2; }
    }

    function tapInLbRow(coords) {
        if (gameState != PS_MENU || _lbW <= 0) { return false; }
        if (coords == null) { return false; }
        var tx = coords[0];
        var ty = coords[1];
        return (tx >= _lbX && tx <= _lbX + _lbW && ty >= _lbY && ty <= _lbY + _lbH);
    }

    function doAction() {
        if (gameState == PS_MENU) {
            if (_menuSel == 1) { openLeaderboard(); }
            else { startRun(); }
        }
        else if (gameState == PS_FREE) {
            if (_altitude > 300.0) { _flashT = 6; return; }
            _chuteOpen = true; gameState = PS_CHUTE; doVibe(60, 150);
        }
        else if (gameState == PS_LAND) {
            if (_resultTick > 20) {
                if (!_lifeLost) { _level++; }
                startLevel();
            }
        }
        else if (gameState == PS_CRASH) {
            if (_resultTick > 20) { startLevel(); }
        }
        else if (gameState == PS_GAMEOVER) {
            if (_resultTick > 25) { _level = 1; _totalScore = 0; _lives = 3; _ringsRunTotal = 0; _tricksThisRun = 0; startLevel(); }
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        // Never render an in-game menu — the shared menu is the root view.
        if (gameState == PS_MENU) { startRun(); }

        var ox = 0; var oy = 0;
        if (_shakeT > 0) { ox = (Math.rand().abs() % 7) - 3; oy = (Math.rand().abs() % 5) - 2; }

        drawSky(dc, ox, oy);
        drawClouds(dc, ox, oy);

        if (gameState == PS_JUMP) { drawJump(dc, ox, oy); }
        else if (gameState == PS_FREE) { drawFreeScene(dc, ox, oy); }
        else if (gameState == PS_CHUTE) { drawChuteScene(dc, ox, oy); }
        else if (gameState == PS_LAND) { drawLanded(dc, ox, oy); }
        else if (gameState == PS_CRASH) { drawCrash(dc, ox, oy); }
        else if (gameState == PS_GAMEOVER) { drawGameOver(dc, ox, oy); }

        if (_flashT > 0) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(0, 0, _w, _h);
            dc.drawRectangle(1, 1, _w - 2, _h - 2);
        }
        if (_hurtFlash > 0) { drawVignette(dc, 0xFF2222, 5); }
    }

    // Layered dark/colored frame in the corners — cheap vignette effect.
    hidden function drawVignette(dc, color, layers) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < layers; i++) {
            dc.drawRectangle(i, i, _w - i * 2, _h - i * 2);
        }
    }

    hidden function drawSky(dc, ox, oy) {
        var altPct = _altitude / _maxAlt;
        if (altPct > 1.0) { altPct = 1.0; } if (altPct < 0.0) { altPct = 0.0; }

        var b = _biome();
        var skyTop; var skyHorizon; var gCol; var gDark; var treeCol; var sunCol;
        if (b == 0) { skyTop = 0x1E5C96; skyHorizon = 0x9FD4EA; gCol = 0x3A7A3A; gDark = 0x27591F; treeCol = 0x1A5C1A; sunCol = 0xFFF3B0; }
        else if (b == 1) { skyTop = 0x2A2668; skyHorizon = 0xFF9A4A; gCol = 0x5A4526; gDark = 0x3E2E18; treeCol = 0x6B4A2A; sunCol = 0xFFC24A; }
        else if (b == 2) { skyTop = 0x03040F; skyHorizon = 0x152742; gCol = 0x14281A; gDark = 0x0C1810; treeCol = 0x0E2A16; sunCol = 0xDDE6FF; }
        else { skyTop = 0x35357E; skyHorizon = 0xFFB6A6; gCol = 0x3E6640; gDark = 0x2A4A2C; treeCol = 0x24552A; sunCol = 0xFFE0C0; }

        // Vertical sky gradient (top color → horizon color), biased by altitude.
        dc.setColor(skyTop, skyTop); dc.clear();
        var bands = 12;
        var bh = _h / bands + 1;
        for (var i = 0; i < bands; i++) {
            var t = i.toFloat() / (bands - 1).toFloat();
            var tt = t * (0.55 + altPct * 0.45);
            var c = _lerpC(skyTop, skyHorizon, tt);
            dc.setColor(c, c);
            dc.fillRectangle(0, i * bh - 2, _w, bh + 3);
        }

        // Celestial body / stars.
        if (b == 2) {
            for (var i = 0; i < STARS; i++) {
                var tw = (_tick + _starPh[i]) % 40;
                if (tw >= 30) { continue; }
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                var sz = (_starPh[i] % 3 == 0) ? 2 : 1;
                dc.fillCircle(_starX[i] + ox, _starY[i] + oy, sz);
            }
            dc.setColor(0xE8ECFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_w * 74 / 100 + ox, _h * 15 / 100 + oy, 10);
            dc.setColor(skyTop, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_w * 78 / 100 + ox, _h * 12 / 100 + oy, 9);
        } else {
            var sx; var sy; var sr;
            if (b == 1) { sx = _w / 2; sy = _h * 40 / 100; sr = 22; }
            else if (b == 3) { sx = _w * 26 / 100; sy = _h * 22 / 100; sr = 14; }
            else { sx = _w * 74 / 100; sy = _h * 15 / 100; sr = 12; }
            dc.setColor(_lerpC(sunCol, skyHorizon, 0.55), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx + ox, sy + oy, sr + 6);
            dc.setColor(sunCol, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx + ox, sy + oy, sr);
        }

        // Ground.
        var gPct = (1.0 - altPct) * 0.7 + 0.08;
        if (gPct > 0.78) { gPct = 0.78; }
        var gH = (_h.toFloat() * gPct).toNumber();
        var gTop = _h - gH + oy;

        dc.setColor(gCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gTop, _w, gH + 5);

        dc.setColor(gDark, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 8; i++) {
            var px = (i * 37 + 12) % _w + ox;
            var py = gTop + 5 + (i * 23) % (gH > 8 ? gH - 5 : 5);
            var sz = (2 + (1.0 - altPct) * 8.0).toNumber();
            dc.fillRectangle(px, py, sz + i * 2, sz);
        }

        dc.setColor(_lerpC(gCol, 0x000000, 0.35), Graphics.COLOR_TRANSPARENT);
        var cx = _w / 2 + ox;
        for (var i = -3; i <= 3; i++) { dc.drawLine(cx, gTop, cx + i * _w / 4, _h + 10); }
        var by = gTop + 4; var step = 3;
        for (var i = 0; i < 5; i++) { if (by >= _h) { break; } dc.drawLine(0, by, _w, by); step += 3 + i * 2; by += step; }

        if (altPct < 0.5) {
            var tSz = (1 + (0.5 - altPct) * 12.0).toNumber();
            for (var i = 0; i < 6; i++) {
                var tx = (i * 41 + 18) % _w + ox;
                var ty = gTop + 12 + (i * 29) % (gH > 15 ? gH - 10 : 8);
                dc.setColor(treeCol, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(tx, ty, tSz);
                dc.setColor(_lerpC(treeCol, 0xFFFFFF, 0.22), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(tx - 2, ty - tSz / 2, tSz * 2 / 3);
            }
        }

        if (altPct < 0.4) {
            var rw = (1 + (0.4 - altPct) * 6.0).toNumber();
            dc.setColor(0x555544, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_w * 30 / 100 + ox, gTop + 5, rw, gH);
            dc.fillRectangle(ox, gTop + gH * 40 / 100, _w, rw);
        }

        if (altPct < 0.5 && (gameState == PS_CHUTE || gameState == PS_FREE)) {
            drawTarget(dc, ox, oy, altPct);
        }

        dc.setColor(_lerpC(gCol, 0xFFFFFF, 0.35), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gTop, _w, 2);
    }

    // Animated bullseye landing zone that grows as the ground approaches.
    hidden function drawTarget(dc, ox, oy, altPct) {
        var tScale = (0.5 - altPct) / 0.5;
        if (tScale < 0.0) { tScale = 0.0; }
        var tR = (_landR.toFloat() * tScale * 3.2 + 2.0).toNumber();
        var lx = _landX + ox; var ly = _h * 82 / 100 + oy;
        var pulse = (_tick % 20 < 10) ? 2 : 0;

        // outer expanding pulse ring
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(lx, ly, tR + 4 + pulse); dc.drawCircle(lx, ly, tR + 5 + pulse);

        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lx, ly, tR + 3);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lx, ly, tR + 1);
        if (tR > 4) {
            dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lx, ly, tR * 2 / 3);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(lx, ly, tR / 3);
        }
        // spinning marker flags for a lively target when close
        if (tR > 6) {
            var a = _tick.toFloat() / 6.0;
            for (var k = 0; k < 4; k++) {
                var aa = a + k * 1.5708;
                var fx = lx + ((tR + 7).toFloat() * Math.cos(aa)).toNumber();
                var fy = ly + ((tR + 7).toFloat() * Math.sin(aa)).toNumber();
                dc.setColor(0xFFDD33, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(fx - 1, fy - 1, 3, 3);
            }
        }
    }

    hidden function drawClouds(dc, ox, oy) {
        for (var i = 0; i < 6; i++) {
            if (_cloudY[i] < -25 || _cloudY[i] > _h + 25) { continue; }
            var z = _cloudZ[i];
            var cw = (_cloudW[i].toFloat() * (0.5 + z * 0.85)).toNumber();
            if (cw < 6) { cw = 6; }
            var ccx = _cloudX[i] + ox; var ccy = _cloudY[i] + oy;
            var shade = _lerpC(0x8FA3BC, 0xEEF4FF, z);
            var mid = _lerpC(0xAEC2DA, 0xF6FAFF, z);
            dc.setColor(shade, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx + 2, ccy + 3, cw / 2); dc.fillCircle(ccx - cw / 3 + 2, ccy + 4, cw / 3);
            dc.setColor(mid, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx, ccy, cw / 2); dc.fillCircle(ccx - cw / 3, ccy + 2, cw / 3); dc.fillCircle(ccx + cw / 3, ccy + 1, cw * 2 / 5);
            dc.setColor(_lerpC(mid, 0xFFFFFF, 0.4), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ccx - cw / 5, ccy - cw / 6, cw / 3);
        }
    }

    hidden function drawRings(dc, ox, oy) {
        for (var i = 0; i < MAX_RINGS; i++) {
            if (!_ringActive[i]) { continue; }
            var rx = _ringX[i] + ox; var ry = _ringY[i] + oy; var rr = _ringR[i];
            var t = _ringType[i];

            var pulse = (_tick % 10 < 5) ? 2 : 0;
            if (t == 2) { drawStar(dc, rx, ry, rr); continue; }
            if (t == 1) {
                dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(rx, ry, rr + 3 + pulse); dc.drawCircle(rx, ry, rr + 4 + pulse);
                dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawCircle(rx, ry, rr); dc.drawCircle(rx, ry, rr + 1); dc.drawCircle(rx, ry, rr + 2);

            var dotC = (t == 1) ? 0xFFFF88 : 0xFFCC66;
            dc.setColor(dotC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(rx - rr + 2, ry, 2); dc.fillCircle(rx + rr - 2, ry, 2);
            dc.fillCircle(rx, ry - rr + 2, 2); dc.fillCircle(rx, ry + rr - 2, 2);
        }
    }

    hidden function drawStar(dc, rx, ry, rr) {
        var twinkle = (_tick % 12 < 6) ? 3 : 0;
        // glow
        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(rx, ry, rr - 1 + twinkle);
        // 5-point star
        var pts = new [10];
        var base = _tick.toFloat() / 8.0;
        for (var k = 0; k < 5; k++) {
            var ao = base + k.toFloat() * 1.25664;         // outer point (2pi/5)
            var ai = base + k.toFloat() * 1.25664 + 0.62832;// inner point
            pts[k * 2] = [rx + (rr.toFloat() * Math.sin(ao)).toNumber(), ry - (rr.toFloat() * Math.cos(ao)).toNumber()];
            pts[k * 2 + 1] = [rx + (rr.toFloat() * 0.45 * Math.sin(ai)).toNumber(), ry - (rr.toFloat() * 0.45 * Math.cos(ai)).toNumber()];
        }
        dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
        dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(rx, ry, rr / 3);
    }

    hidden function drawSpeedLines(dc, ox, oy) {
        for (var i = 0; i < MAX_LINES; i++) {
            if (_lineLife[i] <= 0) { continue; }
            var alpha = _lineLife[i] > 4 ? 0x99AABB : 0x556677;
            dc.setColor(alpha, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(_lineX[i] + ox, _lineY[i] + oy, _lineX[i] + ox, _lineY[i] - _lineLen[i] + oy);
        }
    }

    hidden function drawParts(dc, ox, oy) {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_partLife[i] <= 0) { continue; }
            dc.setColor(_partColor[i], Graphics.COLOR_TRANSPARENT);
            var s = _partLife[i] > 6 ? 2 : 1;
            if (_partGrav[i] > 0.1) { s = _partLife[i] > 10 ? 3 : 2; }   // confetti reads bigger
            dc.fillRectangle(_partX[i].toNumber() + ox, _partY[i].toNumber() + oy, s, s);
        }
    }

    hidden function drawPopups(dc, ox, oy) {
        for (var i = 0; i < MAX_POPS; i++) {
            if (_popLife[i] <= 0) { continue; }
            var fnt = _popBig[i] ? Graphics.FONT_SMALL : Graphics.FONT_XTINY;
            var tx = _popX[i] + ox; var ty = _popY[i].toNumber() + oy;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(tx + 1, ty + 1, fnt, _popText[i], Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(_popColor[i], Graphics.COLOR_TRANSPARENT);
            dc.drawText(tx, ty, fnt, _popText[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawBirds(dc, ox, oy) {
        for (var i = 0; i < MAX_BIRDS; i++) {
            if (!_birdActive[i]) { continue; }
            var bx = _birdX[i].toNumber() + ox; var by = _birdY[i].toNumber() + oy;
            var wingUp = (_birdFlap[i] % 12) < 6;
            var wy = wingUp ? -6 : 2;
            var col = 0x223344;
            if (_birdWarn[i] > 0) { col = (_tick % 6 < 3) ? 0xFF8844 : 0x668094; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, 3);
            dc.drawLine(bx, by, bx - 8, by + wy);
            dc.drawLine(bx, by, bx + 8, by + wy);
            dc.drawLine(bx - 8, by + wy, bx - 12, by + wy + 3);
            dc.drawLine(bx + 8, by + wy, bx + 12, by + wy + 3);
            if (_birdWarn[i] > 0) {
                dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
                dc.drawText(bx, by - 20, Graphics.FONT_XTINY, "!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    // Compact spinning diver used when the player is doing a freefall trick.
    hidden function drawSpinner(dc, px, py) {
        px += 0; py += 0;
        var a = _spinAngle * 3.14159 / 180.0;
        // motion-blur ring
        dc.setColor(0x4466CC, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(px, py, 12);
        dc.setColor(0x88AAEE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(px, py, 13);
        // rotating limbs
        for (var k = 0; k < 4; k++) {
            var aa = a + k.toFloat() * 1.5708;
            var ex = px + (11.0 * Math.cos(aa)).toNumber();
            var ey = py + (11.0 * Math.sin(aa)).toNumber();
            dc.setColor((k % 2 == 0) ? 0x2244AA : 0xFFCC88, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px, py, ex, ey);
        }
        dc.setColor(0x3355CC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 6);
        dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py, 3);
    }

    hidden function drawPlayer(dc, px, py, chuteOpen, ox, oy) {
        px += ox; py += oy;
        if (chuteOpen) {
            var cw = (_tick % 10 < 5) ? 2 : -2;
            var cy2 = py - 50;
            dc.setColor(0x880022, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, cy2, 32);
            dc.setColor(0x0A1530, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + cw - 33, cy2, 66, 34);
            dc.setColor(0xCC1133, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, cy2, 29);
            dc.setColor(0x0A1530, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + cw - 30, cy2, 60, 32);
            dc.setColor(0xFF3355, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, cy2, 22);
            dc.setColor(0x0A1530, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + cw - 23, cy2, 46, 25);
            // gore panel highlights for a shapelier canopy
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            for (var seg = 0; seg < 5; seg++) {
                var ang = (200 + seg * 28) * 3.14159 / 180.0;
                var sx2 = px + cw + (28.0 * Math.cos(ang)).toNumber();
                var sy2 = cy2 + (28.0 * Math.sin(ang)).toNumber();
                if (sy2 < cy2) { dc.fillCircle(sx2, sy2, 3); }
            }
            dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, cy2, 10);
            dc.setColor(0x0A1530, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + cw - 11, cy2, 22, 12);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + cw, cy2, 6);
            dc.setColor(0x0A1530, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + cw - 7, cy2, 14, 8);
            dc.setColor(0x553333, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px - 28 + cw, cy2 + 14, px - 6, py - 2);
            dc.drawLine(px - 16 + cw, cy2 + 20, px - 3, py - 1);
            dc.drawLine(px + cw, cy2 + 22, px, py - 4);
            dc.drawLine(px + 16 + cw, cy2 + 20, px + 3, py - 1);
            dc.drawLine(px + 28 + cw, cy2 + 14, px + 6, py - 2);
        }

        dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py - 5, 5);
        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillCircle(px, py - 5, 4);
        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 5, py - 10, 10, 4);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 6, py - 7, 12, 1);
        dc.fillCircle(px - 2, py - 5, 1); dc.fillCircle(px + 2, py - 5, 1);

        dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 7, py, 14, 10);
        dc.setColor(0x3355CC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 6, py + 1, 12, 8);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 4, py, 2, 9); dc.fillRectangle(px + 2, py, 2, 9);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 3, py + 3, 6, 4);

        if (chuteOpen) {
            dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 9, py - 2, 2, 5); dc.fillRectangle(px + 7, py - 2, 2, 5);
            dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 9, py - 3, 2, 2); dc.fillRectangle(px + 7, py - 3, 2, 2);
            dc.setColor(0x222266, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 3, py + 10, 3, 6); dc.fillRectangle(px, py + 10, 3, 6);
            dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 3, py + 16, 3, 2); dc.fillRectangle(px, py + 16, 3, 2);
        } else {
            var aw = (_tick % 6 < 3) ? 1 : -1;
            dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 14, py + 1 + aw, 7, 3); dc.fillRectangle(px + 7, py + 1 - aw, 7, 3);
            dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 16, py + 1 + aw, 2, 3); dc.fillRectangle(px + 14, py + 1 - aw, 2, 3);
            dc.setColor(0x222266, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 7, py + 10, 3, 5); dc.fillRectangle(px + 4, py + 10, 3, 5);
            dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(px - 8, py + 15, 4, 2); dc.fillRectangle(px + 4, py + 15, 4, 2);

            if (_fallSpeed > 2.5) {
                var lc = ((_fallSpeed - 2.5) * 2.5).toNumber(); if (lc > 8) { lc = 8; }
                dc.setColor(0xAABBDD, Graphics.COLOR_TRANSPARENT);
                for (var li = 0; li < lc; li++) { dc.drawLine(px - 16 + li * 32 / (lc > 0 ? lc : 1), py - 12, px - 16 + li * 32 / (lc > 0 ? lc : 1), py - 18 - Math.rand().abs() % 5); }
            }
        }
    }

    hidden function drawHUD(dc) {
        // Altitude readout with a dark pill for readability.
        var aTxt = _altitude.toNumber() + "m";
        dc.setColor(0x0A1424, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w / 2 - 26, 1, 52, 16, 4);
        dc.setColor(0xCFE6FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, 2, Graphics.FONT_XTINY, aTxt, Graphics.TEXT_JUSTIFY_CENTER);

        var abW = 6; var abH = _h * 45 / 100; var abX = _w - abW - 4; var abY = (_h - abH) / 2;
        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(abX - 1, abY - 1, abW + 2, abH + 2);
        var altPct = _altitude / _maxAlt; if (altPct > 1.0) { altPct = 1.0; }
        var fH = (abH.toFloat() * altPct).toNumber();
        var ac = (altPct > 0.3) ? 0x44AAFF : ((altPct > 0.1) ? 0xFFCC22 : 0xFF4444);
        dc.setColor(ac, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(abX, abY + abH - fH, abW, fH);
        // deploy-zone marker on the altitude gauge (300m relative to max)
        var dzY = abY + abH - (abH.toFloat() * (300.0 / _maxAlt)).toNumber();
        dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(abX - 2, dzY, abW + 4, 1);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 2, Graphics.FONT_XTINY, "" + _ringsHit + "/" + _level, Graphics.TEXT_JUSTIFY_LEFT);
        if (_ringStreak >= 3) {
            var mc = (_comboFlash > 0) ? 0xFFDD44 : 0xFF8844;
            dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(4, 14, Graphics.FONT_XTINY, "x" + (_ringStreak / 3 + 1), Graphics.TEXT_JUSTIFY_LEFT);
        }

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, _h - 16, Graphics.FONT_XTINY, "L" + _level, Graphics.TEXT_JUSTIFY_LEFT);

        var heartStr = "";
        for (var li = 0; li < _lives; li++) { heartStr = heartStr + "*"; }
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 5, _h - 16, Graphics.FONT_XTINY, heartStr, Graphics.TEXT_JUSTIFY_RIGHT);

        var gustAbs = _gustX; if (gustAbs < 0.0) { gustAbs = -gustAbs; }
        if (gustAbs > 0.5) {
            var gc2 = (_tick % 4 < 2) ? 0xFF8800 : 0xFFCC44;
            dc.setColor(gc2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 60 / 100, Graphics.FONT_XTINY, _gustX > 0.0 ? "GUST>>>" : "<<<GUST", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_focus && _chuteOpen) {
            dc.setColor((_tick % 8 < 4) ? 0x66FFCC : 0x33CC99, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 66 / 100, Graphics.FONT_XTINY, "* FOCUS *", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (!_chuteOpen) {
            if (_altitude > 300.0 && _altitude < 900.0) {
                dc.setColor(0x6688BB, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 82 / 100, Graphics.FONT_XTINY, "chute < 300m", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (_altitude <= 300.0) {
                var wc = (_tick % 6 < 3) ? 0xFF0000 : 0xFF8800;
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 82 / 100 + 1, Graphics.FONT_SMALL, "DEPLOY!", Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(wc, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 82 / 100, Graphics.FONT_SMALL, "DEPLOY!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (_chuteOpen) {
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h - 14, Graphics.FONT_XTINY, "CHUTE", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var spd = _fallSpeed / 7.0; if (spd > 1.0) { spd = 1.0; }
            var sbW = _w * 35 / 100; var sbX = (_w - sbW) / 2; var sbY = _h - 10;
            dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(sbX, sbY, sbW, 4);
            dc.setColor(spd > 0.7 ? 0xFF4444 : (spd > 0.4 ? 0xFFCC22 : 0x44FF44), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sbX, sbY, (sbW.toFloat() * spd).toNumber(), 4);
        }

        var awx = _windX; if (awx < 0.0) { awx = -awx; }
        if (awx > 0.3) {
            dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, 20, Graphics.FONT_XTINY, _windX > 0.0 ? ">>>" : "<<<", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawJump(dc, ox, oy) {
        var progress = _jumpTick.toFloat() / 35.0;
        var py = (_h * 10 / 100 + progress * _h * 16 / 100).toNumber();

        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, 0 + oy, _w, _h * 6 / 100);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 6 / 100 + oy, _w, 3);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w / 2 - 25 + ox, oy, 50, _h * 6 / 100 + 3);

        var shake = (_jumpTick % 4 < 2) ? 2 : -2;
        drawPlayer(dc, _w / 2 + shake, py, false, ox, oy);

        var fc = (_jumpTick % 8 < 4) ? 0xFFFF44 : 0xFFAA22;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 48 / 100 + 1, Graphics.FONT_MEDIUM, "JUMP!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_MEDIUM, "JUMP!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 64 / 100, Graphics.FONT_XTINY, _altitude.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
        // biome name tag so the level's setting reads clearly at the start
        var names = ["DAY", "SUNSET", "NIGHT", "DAWN"];
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 72 / 100, Graphics.FONT_XTINY, "L" + _level + " - " + names[_biome()], Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFreeScene(dc, ox, oy) {
        drawSpeedLines(dc, ox, oy);
        drawRings(dc, ox, oy);
        drawBirds(dc, ox, oy);
        drawParts(dc, ox, oy);
        var spinAbs = _spinSpeed; if (spinAbs < 0.0) { spinAbs = -spinAbs; }
        if (spinAbs > 2.5) {
            drawSpinner(dc, _playerX.toNumber(), _h * 28 / 100 + oy);
        } else {
            var sway = (Math.sin(_tick.toFloat() / 3.0) * 2.5).toNumber();
            drawPlayer(dc, _playerX.toNumber() + sway, _h * 28 / 100, false, ox, oy);
        }
        drawPopups(dc, ox, oy);
        drawHUD(dc);
    }

    hidden function drawChuteScene(dc, ox, oy) {
        drawRings(dc, ox, oy);
        drawParts(dc, ox, oy);
        if (_focus) {
            // focus lens: soft ring around the diver
            dc.setColor((_tick % 8 < 4) ? 0x66FFCC : 0x44CCAA, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(_playerX.toNumber() + ox, _h * 28 / 100 + oy, 26);
        }
        drawPlayer(dc, _playerX.toNumber(), _h * 28 / 100, true, ox, oy);
        drawPopups(dc, ox, oy);
        drawHUD(dc);
    }

    hidden function drawLanded(dc, ox, oy) {
        var targetY = _h * 60 / 100;
        if (_landAnimY < targetY.toFloat()) {
            _landAnimY += 6.0;
            if (_landAnimY > targetY.toFloat()) { _landAnimY = targetY.toFloat(); }
        }
        drawPlayer(dc, _playerX.toNumber(), _landAnimY.toNumber(), _resultTick < 40, ox, oy);
        drawParts(dc, ox, oy);

        var gc = 0x44FF44;
        if (_landDist > _landR.toFloat() * 2.0) { gc = 0xFFCC22; }
        if (_landDist > _landR.toFloat() * 3.5) { gc = 0xFF6644; }
        if (_lifeLost) { gc = (_resultTick % 6 < 3) ? 0xFF2222 : 0xCC0000; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 8 / 100 + 1, Graphics.FONT_SMALL, _landGrade, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(gc, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 8 / 100, Graphics.FONT_SMALL, _landGrade, Graphics.TEXT_JUSTIFY_CENTER);

        if (_lifeLost) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 18 / 100, Graphics.FONT_XTINY, "RINGS: " + _ringsHit + "/" + _level, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(_w / 2, _h * 27 / 100, Graphics.FONT_XTINY, "LIFE LOST!", Graphics.TEXT_JUSTIFY_CENTER);
            var heartStr = "";
            for (var li = 0; li < _lives; li++) { heartStr = heartStr + "*"; }
            dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 36 / 100, Graphics.FONT_XTINY, heartStr, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_XTINY, "RINGS " + _ringsHit + "/" + _level, Graphics.TEXT_JUSTIFY_CENTER);
            var bonus = "";
            if (_starsHit > 0) { bonus = bonus + _starsHit + "* "; }
            if (_styleScore > 0) { bonus = bonus + "STYLE " + _styleScore; }
            if (!bonus.equals("")) {
                dc.setColor(0xEEAA44, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_XTINY, bonus, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 35 / 100, Graphics.FONT_SMALL, "+" + _score, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 46 / 100, Graphics.FONT_XTINY, "TOTAL " + _totalScore, Graphics.TEXT_JUSTIFY_CENTER);
        if (_totalScore >= _bestScore && _totalScore > 0) { dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 55 / 100, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 86 / 100, Graphics.FONT_XTINY, "Tap: level " + (_level + 1), Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc, ox, oy) {
        var fb = (_resultTick % 6 < 3) ? 0x1A0A0A : 0x0A0505;
        dc.setColor(fb, fb); dc.clear();
        dc.setColor(0x441111, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 40 / 100, _w, _h * 20 / 100);
        drawParts(dc, ox, oy);

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 2, _h * 10 / 100 + 2, Graphics.FONT_SMALL, "GAME", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_resultTick % 8 < 4) ? 0xFF2222 : 0xCC0000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 10 / 100, Graphics.FONT_SMALL, "GAME", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 2, _h * 24 / 100 + 2, Graphics.FONT_SMALL, "OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_resultTick % 8 < 4) ? 0xFF2222 : 0xCC0000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 24 / 100, Graphics.FONT_SMALL, "OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 40 / 100, Graphics.FONT_XTINY, "Level " + _level + " reached", Graphics.TEXT_JUSTIFY_CENTER);
        if (_level >= _bestLevel) {
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_XTINY, "BEST LEVEL!", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_XTINY, "Best L" + _bestLevel, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 57 / 100, Graphics.FONT_XTINY, "Score " + _totalScore, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x99BBAA, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 65 / 100, Graphics.FONT_XTINY, "Rings " + _ringsRunTotal + "  Tricks " + _tricksThisRun, Graphics.TEXT_JUSTIFY_CENTER);
        if (_totalScore >= _bestScore && _totalScore > 0) { dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 73 / 100, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor((_tick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 85 / 100, Graphics.FONT_XTINY, "Tap to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawCrash(dc, ox, oy) {
        var fb = (_resultTick % 4 < 2) ? 0x220800 : 0x110400;
        dc.setColor(fb, fb); dc.clear();
        dc.setColor(0x334422, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 45 / 100, _w, _h * 55 / 100);
        dc.setColor(0x221100, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w / 2 + ox, _h * 52 / 100 + oy, 20);
        dc.setColor(0x443311, Graphics.COLOR_TRANSPARENT); dc.fillCircle(_w / 2 + ox, _h * 52 / 100 + oy, 13);

        for (var di = 0; di < 10; di++) {
            dc.setColor(0x886644, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_w / 2 + (Math.rand().abs() % 50) - 25, _h * 52 / 100 + (Math.rand().abs() % 30) - 15, 2 + Math.rand().abs() % 4, 2 + Math.rand().abs() % 3);
        }

        // impact vignette
        if (_resultTick < 12) { drawVignette(dc, 0x662211, 6); }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 14 / 100 + 1, Graphics.FONT_SMALL, "SPLAT!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_resultTick % 6 < 3) ? 0xFF2222 : 0xCC0000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 14 / 100, Graphics.FONT_SMALL, "SPLAT!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_XTINY, "No chute deployed!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 36 / 100, Graphics.FONT_XTINY, "RINGS " + _ringsHit, Graphics.TEXT_JUSTIFY_CENTER);
        var heartStr = "";
        for (var li = 0; li < _lives; li++) { heartStr = heartStr + "*"; }
        dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 47 / 100, Graphics.FONT_XTINY, _lives > 0 ? heartStr : "---", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 58 / 100, Graphics.FONT_XTINY, _totalScore + " pts", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 10 < 5) ? 0xFFAA44 : 0xDD8833, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 82 / 100, Graphics.FONT_XTINY, "Tap: try again", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x0A1530, 0x0A1530); dc.clear();
        dc.setColor(0x0A1E3A, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 26 / 100, _w, _h * 26 / 100);
        dc.setColor(0x152848, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 52 / 100, _w, _h * 16 / 100);

        dc.setColor(0x336633, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 90 / 100, _w, _h * 10 / 100);
        dc.setColor(0x448844, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h * 90 / 100, _w, 2);

        drawClouds(dc, 0, 0);

        dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 15 / 100, _h * 6 / 100, 1); dc.fillCircle(_w * 50 / 100, _h * 4 / 100, 1); dc.fillCircle(_w * 78 / 100, _h * 8 / 100, 2);

        dc.setColor(0x113355, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 10 / 100 + 1, Graphics.FONT_SMALL, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 30 < 15) ? 0x44AAFF : 0x2288DD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 10 / 100, Graphics.FONT_SMALL, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 19 / 100, Graphics.FONT_SMALL, "PARACHUTE", Graphics.TEXT_JUSTIFY_CENTER);

        drawPlayer(dc, _w / 2, _h * 39 / 100, true, 0, 0);

        dc.setColor(0x7799BB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 50 / 100, Graphics.FONT_XTINY, "Collect rings per level!", Graphics.TEXT_JUSTIFY_CENTER);
        if (_bestScore > 0) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            var bTxt = "BEST " + _bestScore;
            if (_bestLevel > 0) { bTxt = bTxt + "  L" + _bestLevel; }
            dc.drawText(_w / 2, _h * 55 / 100, Graphics.FONT_XTINY, bTxt, Graphics.TEXT_JUSTIFY_CENTER);
        }

        var playSel = (_menuSel == 0);
        var pw = _w * 54 / 100;
        var ph = _h * 11 / 100; if (ph < 18) { ph = 18; }
        var px = (_w - pw) / 2;
        var py = _h * 64 / 100;
        dc.setColor(playSel ? 0x103A4A : 0x0E2436, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, 5);
        dc.setColor(playSel ? 0x44CCFF : 0x2A6A8A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, 5);
        if (playSel) {
            var ay = py + ph / 2;
            dc.fillPolygon([[px + 5, ay - 4], [px + 5, ay + 4], [px + 11, ay]]);
        }
        dc.setColor(playSel ? 0xBFEFFF : 0x7FB8D0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 6, py + (ph - 14) / 2, Graphics.FONT_XTINY, "TAP TO JUMP", Graphics.TEXT_JUSTIFY_CENTER);

        _lbW = _w * 63 / 100;
        _lbH = _h * 11 / 100; if (_lbH < 20) { _lbH = 20; }
        _lbX = (_w - _lbW) / 2;
        _lbY = _h * 77 / 100;
        LbBadge.drawRow(dc, _lbX, _lbY, _lbW, _lbH, _menuSel == 1);
    }
}
