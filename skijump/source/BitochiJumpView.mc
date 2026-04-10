using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum { JS_MENU, JS_INRUN, JS_FLIGHT, JS_LANDING, JS_RESULT, JS_STANDINGS, JS_FINAL }

const NUM_JUMPERS = 6;
const HILL_PTS    = 100;

class BitochiJumpView extends WatchUi.View {

    var gameState;
    var accelX;
    var accelY;

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;

    // Hill geometry
    hidden var _hillX; hidden var _hillY;
    hidden var _hillTableIdx;  // where table (flat) starts
    hidden var _hillLaunchIdx; // last point of table = launch
    hidden var _hillKIdx; hidden var _hillHSIdx;
    hidden var _hillKDist; hidden var _hillHSDist;
    hidden var _inrunLen;
    hidden var _maxSpeed;
    hidden var _kmhMax;       // realistic top-speed display for each venue
    hidden var _venue;
    hidden var _venueNames;

    // Jumpers
    hidden var _jumperIdx;
    hidden var _jumperNames; hidden var _jumperNat;
    hidden var _jumperColors; hidden var _jumperAccents;

    // Physics state
    hidden var _posX; hidden var _posY;
    hidden var _velX; hidden var _velY;
    hidden var _speed;
    hidden var _bodyAngle; hidden var _skiAngle;
    hidden var _onHill;

    // Takeoff
    hidden var _inTakeoffZone;
    hidden var _takeoffQuality;
    hidden var _takeoffFlash;

    // Flight
    hidden var _distance;
    hidden var _windBase; hidden var _windCurrent; hidden var _windPhase;
    hidden var _passedK;

    // Landing
    hidden var _landTick;
    hidden var _landGood; hidden var _landCrash;
    hidden var _landReady; hidden var _landReadyTick; hidden var _landTapDone;
    hidden var _landQuality;
    hidden var _slideSpeed;
    // Advanced landing states
    hidden var _preparingLanding; // tapped at right moment, gentle descent phase
    hidden var _preparingTick;
    hidden var _earlyTap;        // tapped too early → de-balance stumble
    hidden var _earlyTapTick;
    hidden var _spinningOut;     // lost control (angle/wind) → spinning tumble

    // Tournament
    hidden var _currentRound; hidden var _jumpSlot; hidden var _startJumper;
    hidden var _jumpNum;
    hidden var _scores; hidden var _dists;
    hidden var _cumScores; hidden var _cumDists;
    hidden var _lastDist; hidden var _lastScore; hidden var _bestDist;
    hidden var _bestPerVenue;   // per-venue personal bests [4]
    hidden var _newHillRecord;  // set in finishJump, shown in drawResult
    hidden var _judgeScores;
    hidden var _showStandings;

    // Camera
    hidden var _camX; hidden var _camY;
    hidden var _zoom;  // world-to-screen zoom, scales with screen size

    // Effects
    hidden var _shakeX; hidden var _shakeY; hidden var _shakeTick;
    hidden var _crowdCheer;

    // Snow
    hidden const SNOW_N = 8;
    hidden var _snowX; hidden var _snowY;

    // Trail
    hidden const TRAIL_N = 6;
    hidden var _trailX; hidden var _trailY; hidden var _trailLife;

    // Crowd
    hidden const CROWD_N = 5;
    hidden var _crowdX; hidden var _crowdC; hidden var _crowdJump;
    // Pre-cached world-Y for trees and crowd (computed once in buildHill, reused every frame)
    hidden var _treeWorldY;   // [7] tree Y positions in world coords
    hidden var _crowdWorldY;  // [CROWD_N] crowd Y positions in world coords

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _zoom = 2.2 * (_h.toFloat() / 260.0);
        _tick = 0; accelX = 0; accelY = 0;

        _venueNames   = ["Zakopane", "Innsbruck", "Oberstdorf", "Vikersund"];
        _venue = 0;
        _jumperNames  = ["Stoch",   "Kraft",   "Lindvik",  "Kobayas", "Prevc",   "Granerud"];
        _jumperNat    = ["POL",     "AUT",     "NOR",      "JPN",     "SLO",     "NOR"];
        _jumperColors  = [0xFFCC22, 0xFF4444,  0x2266DD,   0xDD2222,  0x22BB55,  0x4488FF];
        _jumperAccents = [0xFF8822, 0xFF8866,  0x88BBFF,   0xFF6666,  0x66DD88,  0x88CCFF];

        _hillX = new [HILL_PTS]; _hillY = new [HILL_PTS];

        // Must be initialised before buildHill() which writes to _crowdX
        _crowdX = new [CROWD_N]; _crowdC = new [CROWD_N]; _crowdJump = new [CROWD_N];
        _crowdWorldY = new [CROWD_N]; _treeWorldY = new [7];
        var cc = [0xDD4444, 0x4488DD, 0xFFCC22, 0x44BB44, 0xFF8844];
        for (var i = 0; i < CROWD_N; i++) { _crowdX[i] = 0.0; _crowdC[i] = cc[i]; _crowdJump[i] = 0; _crowdWorldY[i] = 0.0; }
        for (var i = 0; i < 7; i++) { _treeWorldY[i] = 0.0; }

        buildHill();

        _scores    = new [NUM_JUMPERS]; _dists     = new [NUM_JUMPERS];
        _cumScores = new [NUM_JUMPERS]; _cumDists  = new [NUM_JUMPERS];
        _judgeScores = new [5];
        for (var i = 0; i < NUM_JUMPERS; i++) { _scores[i] = 0.0; _dists[i] = 0.0; _cumScores[i] = 0.0; _cumDists[i] = 0.0; }
        for (var i = 0; i < 5; i++) { _judgeScores[i] = 0.0; }

        _snowX = new [SNOW_N]; _snowY = new [SNOW_N];
        for (var i = 0; i < SNOW_N; i++) { _snowX[i] = (Math.rand().abs() % _w).toFloat(); _snowY[i] = (Math.rand().abs() % _h).toFloat(); }

        _trailX = new [TRAIL_N]; _trailY = new [TRAIL_N]; _trailLife = new [TRAIL_N];
        for (var i = 0; i < TRAIL_N; i++) { _trailX[i] = 0.0; _trailY[i] = 0.0; _trailLife[i] = 0; }

        initJumpVars();
        _currentRound = 1; _jumpSlot = 0; _startJumper = 0; _jumpNum = 0;
        _lastDist = 0.0; _lastScore = 0.0; _newHillRecord = false;
        var jbd = Application.Storage.getValue("jumpBest");
        _bestDist = (jbd != null) ? jbd : 0.0;
        _bestPerVenue = new [4];
        for (var i = 0; i < 4; i++) {
            var v = Application.Storage.getValue("jumpBest" + i);
            _bestPerVenue[i] = (v != null) ? v : 0.0;
        }
        _showStandings = false; _jumperIdx = 0;
        _shakeX = 0; _shakeY = 0; _shakeTick = 0; _crowdCheer = 0;
        gameState = JS_MENU;
    }

    hidden function buildHill() {
        var sx = 0.0; var sy = 0.0;
        var inA; var inStep; var tA; var lA;
        if (_venue == 0) {
            _inrunLen = 26; inA = 33.0; inStep = 2.8; tA = 10.0; lA = 33.0;
            _hillKDist = 90.0; _hillHSDist = 99.0; _maxSpeed = 3.0; _kmhMax = 87.0;
        } else if (_venue == 1) {
            _inrunLen = 34; inA = 35.0; inStep = 3.0; tA = 10.5; lA = 34.5;
            _hillKDist = 120.0; _hillHSDist = 130.0; _maxSpeed = 3.6; _kmhMax = 92.0;
        } else if (_venue == 2) {
            _inrunLen = 44; inA = 37.0; inStep = 3.2; tA = 11.0; lA = 35.5;
            _hillKDist = 137.0; _hillHSDist = 147.0; _maxSpeed = 4.1; _kmhMax = 97.0;
        } else {
            _inrunLen = 60; inA = 39.5; inStep = 3.6; tA = 11.5; lA = 38.0;
            _hillKDist = 200.0; _hillHSDist = 243.0; _maxSpeed = 5.2; _kmhMax = 104.0;
        }
        _hillTableIdx = _inrunLen;
        var inR = inA * 3.14159 / 180.0;
        for (var i = 0; i < _inrunLen; i++) {
            _hillX[i] = sx; _hillY[i] = sy;
            sx += inStep * Math.cos(inR); sy += inStep * Math.sin(inR);
        }
        var tLen = 5; var tR = tA * 3.14159 / 180.0;
        for (var i = 0; i < tLen; i++) {
            _hillX[_hillTableIdx + i] = sx; _hillY[_hillTableIdx + i] = sy;
            sx += 2.8 * Math.cos(tR); sy += 2.8 * Math.sin(tR);
        }
        _hillLaunchIdx = _hillTableIdx + tLen - 1;
        var lS = _hillTableIdx + tLen; var lL = HILL_PTS - lS;
        var kPt = (_hillKDist / 3.0).toNumber(); if (kPt + lS >= HILL_PTS) { kPt = HILL_PTS - lS - 5; }
        var hsPt = (_hillHSDist / 3.0).toNumber(); if (hsPt + lS >= HILL_PTS) { hsPt = HILL_PTS - lS - 2; }
        _hillKIdx = lS + kPt; _hillHSIdx = lS + hsPt;
        var landStep = (_venue >= 3) ? 3.4 : 3.0;
        for (var i = 0; i < lL; i++) {
            var idx = lS + i; if (idx >= HILL_PTS) { break; }
            var prog = i.toFloat() / lL.toFloat();
            var cA = lA * (1.0 - prog * prog * 0.86);
            var cR = cA * 3.14159 / 180.0;
            _hillX[idx] = sx; _hillY[idx] = sy;
            sx += landStep * Math.cos(cR); sy += landStep * Math.sin(cR);
        }
        for (var i = 0; i < CROWD_N; i++) {
            var ci = lS + 8 + i * 6; if (ci >= HILL_PTS) { ci = HILL_PTS - 1; }
            _crowdX[i] = _hillX[ci] + 12.0 + (i % 3) * 5.0;
        }
        // Pre-cache Y positions for trees and crowd — avoids hillYAtX() every render frame
        for (var i = 0; i < 7; i++) {
            _treeWorldY[i] = hillYAtX(14.0 + i.toFloat() * 46.0);
        }
        for (var i = 0; i < CROWD_N; i++) {
            _crowdWorldY[i] = hillYAtX(_crowdX[i]) - 2.5;
        }
    }

    hidden function hillYAtX(wx) {
        for (var i = 1; i < HILL_PTS; i++) {
            if (_hillX[i] >= wx) {
                var t = (wx - _hillX[i-1]) / (_hillX[i] - _hillX[i-1] + 0.001);
                return _hillY[i-1] + t * (_hillY[i] - _hillY[i-1]);
            }
        }
        return _hillY[HILL_PTS - 1];
    }
    hidden function hillAngleAtX(wx) {
        for (var i = 1; i < HILL_PTS; i++) {
            if (_hillX[i] >= wx) { return Math.atan2(_hillY[i] - _hillY[i-1], _hillX[i] - _hillX[i-1]) * 180.0 / 3.14159; }
        }
        return 5.0;
    }
    hidden function distMeters(wx) {
        var dx = wx - _hillX[_hillLaunchIdx];
        if (dx < 0.0) { return 0.0; }
        return dx * 0.7;
    }

    hidden function initJumpVars() {
        _posX = _hillX[0]; _posY = _hillY[0];
        _velX = 0.0; _velY = 0.0; _speed = 0.4; _onHill = true;
        _bodyAngle = hillAngleAtX(_posX); _skiAngle = _bodyAngle;
        _inTakeoffZone = false; _takeoffQuality = 0.0; _takeoffFlash = 0;
        _distance = 0.0; _landTick = 0;
        _landGood = false; _landCrash = false;
        _landReady = false; _landReadyTick = 0; _landTapDone = false;
        _landQuality = 0.0; _slideSpeed = 0.0;
        _preparingLanding = false; _preparingTick = 0;
        _earlyTap = false; _earlyTapTick = 0; _spinningOut = false;
        _newHillRecord = false;
        _windBase = 0.0; _windCurrent = 0.0; _windPhase = 0.0;
        _passedK = false;
        _camX = _posX; _camY = _posY;
        _shakeTick = 0; _crowdCheer = 0;
        for (var i = 0; i < TRAIL_N; i++) { _trailLife[i] = 0; }
    }

    function onShow() { _timer = new Timer.Timer(); _timer.start(method(:onTick), 50, true); }
    function onHide() { if (_timer != null) { _timer.stop(); _timer = null; } }

    function onTick() as Void {
        _tick++;
        // Snow drift
        for (var i = 0; i < SNOW_N; i++) {
            _snowY[i] += 0.65 + (i % 3).toFloat() * 0.18;
            _snowX[i] += _windCurrent * 0.22;
            if (_snowY[i] > _h.toFloat()) { _snowY[i] = 0.0; _snowX[i] = (Math.rand().abs() % _w).toFloat(); }
            if (_snowX[i] < 0.0) { _snowX[i] += _w.toFloat(); } if (_snowX[i] > _w.toFloat()) { _snowX[i] -= _w.toFloat(); }
        }
        for (var i = 0; i < TRAIL_N; i++) { if (_trailLife[i] > 0) { _trailLife[i]--; } }
        if (_shakeTick > 0) { _shakeX = (Math.rand().abs() % 5) - 2; _shakeY = (Math.rand().abs() % 3) - 1; _shakeTick--; } else { _shakeX = 0; _shakeY = 0; }
        if (_takeoffFlash > 0) { _takeoffFlash--; }
        if (_crowdCheer > 0) { _crowdCheer--; for (var i = 0; i < CROWD_N; i++) { _crowdJump[i] = ((_tick + i * 3) % 6 < 3) ? 1 : 0; } }
        else { for (var i = 0; i < CROWD_N; i++) { _crowdJump[i] = 0; } }

        // Smooth camera follow
        var cs = 0.13;
        _camX = _camX * (1.0 - cs) + (_posX + _velX * 3.0) * cs;
        _camY = _camY * (1.0 - cs) + (_posY + _velY * 1.5) * cs;

        if (gameState == JS_INRUN)   { updateInrun(); }
        else if (gameState == JS_FLIGHT) { updateFlight(); }
        else if (gameState == JS_LANDING) {
            _landTick++;
            if (_slideSpeed > 0.12) {
                _posX += _slideSpeed; _posY = hillYAtX(_posX);
                _slideSpeed *= 0.91; _bodyAngle = hillAngleAtX(_posX);
            }
            if (_landTick > 65) { finishJump(); }
        }
        WatchUi.requestUpdate();
    }

    hidden function updateInrun() {
        var hA = hillAngleAtX(_posX);
        var grav = 9.8 * Math.sin(hA * 3.14159 / 180.0);
        _speed += grav * 0.033 - 0.009 - 0.00022 * _speed * _speed;
        if (_speed < 0.4) { _speed = 0.4; } if (_speed > _maxSpeed) { _speed = _maxSpeed; }
        var ang = hA * 3.14159 / 180.0;
        _posX += _speed * Math.cos(ang); _posY = hillYAtX(_posX);
        _bodyAngle = hA; _skiAngle = hA;
        if (_posX >= _hillX[_hillTableIdx]) { _inTakeoffZone = true; }
        if (_posX >= _hillX[_hillLaunchIdx]) { executeTakeoff(false); }
    }

    hidden function executeTakeoff(manual) {
        if (gameState != JS_INRUN) { return; }
        if (manual && _inTakeoffZone) {
            var edgeX = _hillX[_hillLaunchIdx]; var zoneX = _hillX[_hillTableIdx];
            var dist = edgeX - _posX; var zoneL = edgeX - zoneX + 0.01;
            var ratio = dist / zoneL;
            if      (ratio < 0.10) { _takeoffQuality = 1.00; _takeoffFlash = 8; }
            else if (ratio < 0.25) { _takeoffQuality = 0.88; _takeoffFlash = 5; }
            else if (ratio < 0.45) { _takeoffQuality = 0.72; }
            else if (ratio < 0.65) { _takeoffQuality = 0.55; }
            else                   { _takeoffQuality = 0.38; }
        } else if (!manual) {
            // Missed takeoff — no button press, skier naturally leaves the ramp edge.
            // No quality bonus, but still a proper flight (player can still correct in air).
            _takeoffQuality = 0.20;
        } else {
            _takeoffQuality = 0.22;  // tapped before zone — below-average but still a jump
        }
        // Flatter launch angle (10-20°) so good takeoff sends jumper FORWARD, not upward.
        // fwdBoost >> upBoost: horizontal carry dominates — realistic ski-jump trajectory.
        var launchA = 10.0 + _takeoffQuality * 10.0;  // 10° (poor) → 20° (perfect)
        var lr = launchA * 3.14159 / 180.0;
        var fwdBoost = 0.88 + _takeoffQuality * 0.68;  // horizontal: 0.88 → 1.56
        var upBoost  = 0.50 + _takeoffQuality * 0.38;  // vertical:   0.50 → 0.88 (smaller)
        _velX = _speed * fwdBoost * Math.cos(lr);
        _velY = -_speed * upBoost  * Math.sin(lr);
        // Start well outside sweet spot — player must lean to correct toward 18°
        // Perfect takeoff = 34°, poor = 40°. Sweet spot is ~16-25°.
        _bodyAngle = 34.0 + (1.0 - _takeoffQuality) * 6.0;
        _skiAngle  = _bodyAngle + 2.0;
        _onHill = false;
        _windBase = -0.9 + (Math.rand().abs() % 20).toFloat() / 11.0;
        _windPhase = (Math.rand().abs() % 628).toFloat() / 100.0;
        if (_takeoffQuality >= 0.95) { doVibe(80, 150); } else if (_takeoffQuality > 0.2) { doVibe(50, 100); }
        gameState = JS_FLIGHT;
    }

    hidden function updateFlight() {
        // Always update wind for HUD/snow even in special states
        _windPhase += 0.052;
        var wAmp = 0.26 + _venue.toFloat() * 0.07;
        _windCurrent = _windBase + Math.sin(_windPhase) * wAmp + Math.sin(_windPhase * 2.4) * 0.09;

        // --- PATH 1: Early tap — jumper stumbled and de-balancing ---
        if (_earlyTap) {
            _earlyTapTick++;
            _bodyAngle += 3.5;           // rapidly tipping over
            _skiAngle  += 2.0;
            _velY += 0.20;               // gravity pulling down harder
            _posX += _velX * 0.88; _posY += _velY;
            _distance = distMeters(_posX);
            if (_tick % 2 == 0) { pushTrail(_posX, _posY); }
            var hillYE = hillYAtX(_posX);
            if (_posY >= hillYE - 1.5 || _bodyAngle > 62.0) {
                _landCrash = true; _posY = hillYE; doLanding();
            }
            return;
        }

        // --- PATH 2: Spinning out of control (wind/angle overdone) ---
        if (_spinningOut) {
            _bodyAngle += 5.2;
            _velY += 0.28;
            _posX += _velX * 0.82; _posY += _velY;
            _distance = distMeters(_posX);
            if (_tick % 2 == 0) { pushTrail(_posX, _posY); }
            var hillYS = hillYAtX(_posX);
            if (_posY >= hillYS - 1.5) {
                _landCrash = true; _posY = hillYS; doLanding();
            }
            return;
        }

        // --- PATH 3: Tap landed correctly — gentle curved descent into landing pose ---
        if (_preparingLanding) {
            _preparingTick++;
            _velY += 0.08;          // soft, gentle gravity arc
            _velX *= 0.988;
            // Smoothly rotate body toward landing angle (upright, legs ready)
            var landTargetAngle = 10.0 + _landQuality * 7.0;
            _bodyAngle = _bodyAngle * 0.91 + landTargetAngle * 0.09;
            _skiAngle  = _skiAngle  * 0.93 + _bodyAngle * 0.07;
            _posX += _velX; _posY += _velY;
            _distance = distMeters(_posX);
            if (_tick % 2 == 0) { pushTrail(_posX, _posY); }
            var hillYP = hillYAtX(_posX);
            if (_posY >= hillYP - 1.0) { _posY = hillYP; doLanding(); }
            return;
        }

        // --- PATH 4: Normal flight ---
        // Accelerometer input — Parachute-style: small dead zone, smooth and direct
        var ax = accelX.toFloat();
        var dead = 40.0;
        var input = 0.0;
        if (ax >  dead) { input =  (ax - dead) / 280.0; }
        else if (ax < -dead) { input = (ax + dead) / 280.0; }
        if (input >  1.3) { input =  1.3; }
        if (input < -1.3) { input = -1.3; }

        // Wind nudge — stronger when body is misaligned (fighting or drifting)
        var misalign = _bodyAngle - 18.0; if (misalign < 0.0) { misalign = -misalign; }
        var windMult = 1.8 + (misalign > 14.0 ? (misalign - 14.0) * 0.12 : 0.0);
        var windNudge = _windCurrent * windMult;
        var targetAngle = 18.0 + input * 16.0 + windNudge;
        if (targetAngle < -10.0) { targetAngle = -10.0; }
        if (targetAngle >  56.0) { targetAngle =  56.0; }

        // Smooth lerp — responsive like Parachute, not sluggish
        _bodyAngle = _bodyAngle * 0.84 + targetAngle * 0.16;
        _skiAngle  = _skiAngle  * 0.92 + _bodyAngle  * 0.08;

        // Lose control: smooth transition to spinning tumble (not instant crash)
        if (_bodyAngle > 46.0 || _bodyAngle < -8.0) { _spinningOut = true; return; }

        // Aerodynamics: lift from optimal angle (18°), drag from deviation
        var optDev = _bodyAngle - 18.0; if (optDev < 0.0) { optDev = -optDev; }
        var liftFactor = 1.0 - optDev / 18.0;
        if (liftFactor < 0.0) { liftFactor = 0.0; }
        var tqBoost = 0.58 + _takeoffQuality * 0.76;
        var lift = liftFactor * 0.21 * tqBoost;
        var drag = 0.007 + (1.0 - liftFactor) * 0.004;
        var speed = Math.sqrt(_velX * _velX + _velY * _velY);

        // cos(atan2(-vy,vx)+pi/2) = vy/speed, sin(atan2(-vy,vx)+pi/2) = vx/speed
        // eliminates atan2 + cos + sin entirely
        var invSpd = 1.0 / speed;
        var ax2 = -drag * speed * _velX + lift * _velY * invSpd + _windCurrent * 0.011;
        var ay2 = 0.23  - lift * _velX * invSpd;
        if (ay2 < 0.052) { ay2 = 0.052; } // gravity floor — always falls, even perfectly positioned

        _velX += ax2; _velY += ay2;
        if (_velX < 0.7) { _velX = 0.7; }
        _posX += _velX; _posY += _velY;
        _distance = distMeters(_posX);

        if (!_passedK && _distance > _hillKDist) { _passedK = true; _crowdCheer = 55; doVibe(28, 60); }
        if (_tick % 2 == 0) { pushTrail(_posX, _posY); }

        // Landing zone detection
        var hillY = hillYAtX(_posX);
        var heightAbove = hillY - _posY;
        if (!_landReady && heightAbove < 30.0 && _distance > 8.0) { _landReady = true; _landReadyTick = 0; }
        if (_landReady) { _landReadyTick++; }

        // Auto-land: touches ground without tap → poor quality; strong wind = crash
        if (_posY >= hillY - 1.5 && _posX > _hillX[_hillLaunchIdx]) {
            _posY = hillY;
            if (!_landTapDone) {
                _landQuality = 0.15;
                var wAbsA = _windCurrent; if (wAbsA < 0.0) { wAbsA = -wAbsA; }
                if (_distance < 6.0 || wAbsA > 0.45) { _landCrash = true; }
            }
            doLanding();
        }
    }

    hidden function doLanding() {
        _distance = distMeters(_posX);
        if (!_landCrash) {
            // Wind penalty: crosswind destabilises the landing
            var wAbs = _windCurrent; if (wAbs < 0.0) { wAbs = -wAbs; }
            var windPenalty = 0.0;
            if      (wAbs > 0.55) { windPenalty = 0.22; }
            else if (wAbs > 0.30) { windPenalty = 0.10; }

            // Distance penalty: longer jump = faster approach = harder to stick
            var distPenalty = 0.0;
            if      (_distance > _hillHSDist)  { distPenalty = 0.14; }
            else if (_distance > _hillKDist)   { distPenalty = 0.06; }

            var finalQ = _landQuality - windPenalty - distPenalty;
            if (finalQ < 0.0) { finalQ = 0.0; }

            // Crash when landing quality is too poor or body angle is wrong
            if (finalQ < 0.14 || _bodyAngle > 44.0 || _bodyAngle < 3.0) {
                _landCrash = true;
            } else {
                _landGood = (finalQ > 0.65 && _bodyAngle > 7.0 && _bodyAngle < 40.0);
            }
        }
        if (_landCrash) {
            _landGood = false; _shakeTick = 14; doVibe(100, 280);
            _crowdCheer = 8; _slideSpeed = 0.0;
        } else {
            _shakeTick = _landGood ? 4 : 7;
            doVibe(_landGood ? 40 : 70, _landGood ? 100 : 180);
            _crowdCheer = _landGood ? 55 : 22;
            _slideSpeed = _velX * 0.30;
            if (_slideSpeed < 0.0) { _slideSpeed = 0.0; } if (_slideSpeed > 3.2) { _slideSpeed = 3.2; }
        }
        gameState = JS_LANDING; _landTick = 0;
    }

    hidden function doLandingTap() {
        if (_landTapDone || _earlyTap || _spinningOut || _preparingLanding) { return; }
        _landTapDone = true;

        if (!_landReady) {
            // Tapped too early — de-balance, stumble, graceful fall
            if (_distance > 10.0) {
                _earlyTap = true;
                doVibe(70, 160);
            } else {
                _landTapDone = false; // too close to takeoff, ignore
            }
            return;
        }

        // In landing zone — quality depends on height above hill
        var hillY = hillYAtX(_posX);
        var ha = hillY - _posY; if (ha < 0.0) { ha = 0.0; }

        if (ha < 2.5) {
            // Tapped way too late — nearly on the hill already → crash
            _landQuality = 0.0; _landCrash = true;
            _preparingLanding = true;
            doVibe(90, 220); return;
        }
        if      (ha <  7.0) { _landQuality = 1.00; }   // nearly touching: perfect
        else if (ha < 14.0) { _landQuality = 0.84; }   // very close: telemark
        else if (ha < 23.0) { _landQuality = 0.62; }   // ok: two-foot
        else if (ha < 33.0) { _landQuality = 0.38; }   // high: weak two-foot
        else                { _landQuality = 0.22; }   // very high: early/awkward

        // Start graceful preparation descent — don't snap to ground
        _preparingLanding = true;
        doVibe(30, 80);
    }

    hidden function finishJump() {
        var dist = _distance; if (dist < 0.0) { dist = 0.0; }
        var sPts = 0.0;
        for (var j = 0; j < 5; j++) {
            var base = 16.0 + _takeoffQuality * 2.2 + _landQuality * 1.8;
            if (_landGood)  { base += 1.8; }
            if (_landCrash) { base -= 7.0; }
            base -= (Math.rand().abs() % 12).toFloat() / 12.0;
            if (_bodyAngle > 42.0 || _bodyAngle < 5.0) { base -= 1.8; }
            if (base <  5.0) { base =  5.0; } if (base > 20.0) { base = 20.0; }
            _judgeScores[j] = base; sPts += base;
        }
        sPts -= maxJ(); sPts -= minJ();
        var total = dist + sPts;
        if (_landCrash) { total = total * 0.38; }
        _lastDist = dist; _lastScore = total;
        _dists[_jumperIdx] = dist; _scores[_jumperIdx] = total;
        _cumDists[_jumperIdx] += dist; _cumScores[_jumperIdx] += total;
        if (dist > _bestDist && !_landCrash) { _bestDist = dist; Application.Storage.setValue("jumpBest", _bestDist); }
        if (dist > _bestPerVenue[_venue] && !_landCrash) {
            _bestPerVenue[_venue] = dist;
            Application.Storage.setValue("jumpBest" + _venue, dist);
            _newHillRecord = true;
        }
        gameState = JS_RESULT;
    }

    hidden function maxJ() { var m = _judgeScores[0]; for (var i = 1; i < 5; i++) { if (_judgeScores[i] > m) { m = _judgeScores[i]; } } return m; }
    hidden function minJ() { var m = _judgeScores[0]; for (var i = 1; i < 5; i++) { if (_judgeScores[i] < m) { m = _judgeScores[i]; } } return m; }

    hidden function pushTrail(px, py) {
        for (var i = TRAIL_N - 1; i > 0; i--) { _trailX[i] = _trailX[i-1]; _trailY[i] = _trailY[i-1]; _trailLife[i] = _trailLife[i-1]; }
        _trailX[0] = px; _trailY[0] = py; _trailLife[0] = 30;
    }

    // World to screen: scale 2.2, anchor at screen center / 44% height
    hidden function wsx(wx) { return (_w / 2 + ((wx - _camX) * _zoom).toNumber()); }
    hidden function wsy(wy) { return (_h * 44 / 100 + ((wy - _camY) * _zoom).toNumber()); }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) { if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
        } }
    }

    function doAction() {
        if (gameState == JS_MENU)    { startCompetition(); }
        else if (gameState == JS_INRUN) { executeTakeoff(true); }
        else if (gameState == JS_FLIGHT) { doLandingTap(); }
        else if (gameState == JS_RESULT) { advanceAfterResult(); }
        else if (gameState == JS_STANDINGS) { advanceFromStandings(); }
        else if (gameState == JS_FINAL) { gameState = JS_MENU; }
    }
    function cycleJumper(dir) { if (gameState == JS_MENU) { _jumperIdx = (_jumperIdx + dir + NUM_JUMPERS) % NUM_JUMPERS; } }

    hidden function startCompetition() {
        _venue = 0; buildHill();
        _startJumper = _jumperIdx; _jumpSlot = 0; _currentRound = 1; _jumpNum = 0;
        for (var i = 0; i < NUM_JUMPERS; i++) { _scores[i] = 0.0; _dists[i] = 0.0; _cumScores[i] = 0.0; _cumDists[i] = 0.0; }
        _jumperIdx = _startJumper; beginJump();
    }
    hidden function beginJump() { _jumpNum++; initJumpVars(); gameState = JS_INRUN; }

    hidden function advanceAfterResult() {
        _jumpSlot++;
        if (_jumpSlot >= NUM_JUMPERS) {
            if (_currentRound == 1) { gameState = JS_STANDINGS; return; }
            if (_venue < 3) {
                _venue++; buildHill(); _currentRound = 1; _jumpSlot = 0;
                _jumperIdx = _startJumper; beginJump();
            } else { gameState = JS_FINAL; }
            return;
        }
        _jumperIdx = (_startJumper + _jumpSlot) % NUM_JUMPERS; beginJump();
    }
    hidden function advanceFromStandings() { _currentRound = 2; _jumpSlot = 0; _jumperIdx = _startJumper; beginJump(); }

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        if (gameState == JS_MENU)       { drawMenu(dc); return; }
        if (gameState == JS_RESULT)     { drawResult(dc); return; }
        if (gameState == JS_STANDINGS)  { drawStandings(dc); return; }
        if (gameState == JS_FINAL)      { drawFinal(dc); return; }
        drawScene(dc);
    }

    hidden function drawScene(dc) {
        var ox = _shakeX; var oy = _shakeY;
        drawSky(dc);
        drawMountains(dc, ox, oy);
        drawHillSnow(dc, ox, oy);
        drawFence(dc, ox, oy);
        drawKHS(dc, ox, oy);
        drawTrees(dc, ox, oy);
        drawCrowd(dc, ox, oy);
        if (gameState == JS_FLIGHT || gameState == JS_LANDING) { drawTrail(dc, ox, oy); }
        drawJumper(dc, ox, oy);
        drawSnow(dc);
        drawHUD(dc);
        if (_takeoffFlash > 4) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(0, 0, _w, _h); dc.drawRectangle(1, 1, _w - 2, _h - 2);
        }
    }

    hidden function drawSky(dc) {
        // Daytime sky — light blue/gray like DSJ
        var skyTop = [0xBBCCDD, 0xC4D0E0, 0xB0C4D8, 0xC0CAD8];
        var skyBot = [0xD8E4EE, 0xDCE4EE, 0xCCDAE8, 0xD4DCE8];
        dc.setColor(skyTop[_venue], skyTop[_venue]); dc.clear();
        dc.setColor(skyBot[_venue], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h * 48 / 100);
    }

    hidden function drawMountains(dc, ox, oy) {
        var par = (_camX * 0.1).toNumber();
        // Background mountains
        dc.setColor(0xE0ECF4, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [0, _h * 54 / 100 + oy],
            [_w * 16 / 100 - par + ox, _h * 25 / 100 + oy],
            [_w * 36 / 100 - par + ox, _h * 31 / 100 + oy],
            [_w * 52 / 100 - par + ox, _h * 18 / 100 + oy],
            [_w * 70 / 100 - par + ox, _h * 28 / 100 + oy],
            [_w * 88 / 100 - par + ox, _h * 22 / 100 + oy],
            [_w + ox, _h * 38 / 100 + oy],
            [_w + ox, _h + oy], [0, _h + oy]
        ]);
        // Snow ridge lines
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 16 / 100 - par + ox, _h * 25 / 100 + oy, _w * 36 / 100 - par + ox, _h * 31 / 100 + oy);
        dc.drawLine(_w * 36 / 100 - par + ox, _h * 31 / 100 + oy, _w * 52 / 100 - par + ox, _h * 18 / 100 + oy);
        dc.drawLine(_w * 52 / 100 - par + ox, _h * 18 / 100 + oy, _w * 70 / 100 - par + ox, _h * 28 / 100 + oy);
        dc.drawLine(_w * 70 / 100 - par + ox, _h * 28 / 100 + oy, _w * 88 / 100 - par + ox, _h * 22 / 100 + oy);
    }

    hidden function drawHillSnow(dc, ox, oy) {
        // Draw snow slope as vertical strips (fast, no polygon allocation)
        // Each strip: from hill Y down to bottom of screen
        var prevSx = -999; var prevSy = _h;
        for (var i = 0; i < HILL_PTS; i += 2) {
            var sx = wsx(_hillX[i]) + ox;
            var sy = wsy(_hillY[i]) + oy;
            if (sx < -8 || sx > _w + 8) { prevSx = sx; prevSy = sy; continue; }
            var stripW = (prevSx >= 0 && prevSx < _w + 8) ? sx - prevSx + 2 : 5;
            if (stripW < 2) { stripW = 2; }
            dc.setColor(0xDDE8F0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, sy, stripW, _h - sy + 4);
            prevSx = sx; prevSy = sy;
        }
        // Snow surface line (white on top)
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i < HILL_PTS; i += 2) {
            var sx1 = wsx(_hillX[i-1]) + ox; var sy1 = wsy(_hillY[i-1]) + oy;
            var sx2 = wsx(_hillX[i])   + ox; var sy2 = wsy(_hillY[i])   + oy;
            if (sx2 < -5 || sx1 > _w + 5) { continue; }
            dc.drawLine(sx1, sy1, sx2, sy2);
        }
        // Light blue-gray shadow just below surface
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i < HILL_PTS; i += 3) {
            var sx1 = wsx(_hillX[i-1]) + ox; var sy1 = wsy(_hillY[i-1]) + oy + 2;
            var sx2 = wsx(_hillX[i])   + ox; var sy2 = wsy(_hillY[i])   + oy + 2;
            if (sx2 < -5 || sx1 > _w + 5) { continue; }
            dc.drawLine(sx1, sy1, sx2, sy2);
        }
    }

    hidden function drawFence(dc, ox, oy) {
        // Yellow fence along the slope (like DSJ screenshot)
        var lS = _hillTableIdx + 5;
        dc.setColor(0xDDAA00, Graphics.COLOR_TRANSPARENT);
        for (var i = lS + 2; i < HILL_PTS; i += 2) {
            var sx1 = wsx(_hillX[i-2]) + ox; var sy1 = wsy(_hillY[i-2] - 2.5) + oy;
            var sx2 = wsx(_hillX[i])   + ox; var sy2 = wsy(_hillY[i]   - 2.5) + oy;
            if (sx2 < -5 || sx1 > _w + 5) { continue; }
            dc.drawLine(sx1, sy1, sx2, sy2);
            dc.drawLine(sx1, sy1 + 2, sx2, sy2 + 2);
        }
        // Fence posts (dark yellow)
        dc.setColor(0x886600, Graphics.COLOR_TRANSPARENT);
        for (var i = lS; i < HILL_PTS; i += 8) {
            var px = wsx(_hillX[i]) + ox;
            var py = wsy(_hillY[i] - 4.5) + oy;
            if (px < 0 || px > _w) { continue; }
            dc.fillRectangle(px - 1, py, 2, 7);
        }
    }

    hidden function drawKHS(dc, ox, oy) {
        if (_hillKIdx < HILL_PTS) {
            var kx = wsx(_hillX[_hillKIdx]) + ox;
            var ky = wsy(_hillY[_hillKIdx]) + oy;
            if (kx > 2 && kx < _w - 2) {
                dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(kx - 1, ky - 10, 3, 10);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(kx, ky - 20, Graphics.FONT_XTINY, "K" + _hillKDist.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
        if (_hillHSIdx < HILL_PTS) {
            var hx = wsx(_hillX[_hillHSIdx]) + ox;
            var hy = wsy(_hillY[_hillHSIdx]) + oy;
            if (hx > 2 && hx < _w - 2) {
                dc.setColor(0x33DD33, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(hx - 1, hy - 10, 3, 10);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(hx, hy - 20, Graphics.FONT_XTINY, "HS" + _hillHSDist.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden function drawTrees(dc, ox, oy) {
        for (var i = 0; i < 7; i++) {
            var tWx = 14.0 + i.toFloat() * 46.0;
            var tWy = _treeWorldY[i] - 1.5;   // use pre-cached Y
            var tx = wsx(tWx) + ox + 12; var ty = wsy(tWy) + oy;
            if (tx < -12 || tx > _w + 12) { continue; }
            var th = 10 + (i % 3) * 2;
            // Trunk
            dc.setColor(0x3A2010, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tx - 1, ty, 2, 4);
            // Pine tiers using fillRectangle (replaces 2 fillPolygon — much faster)
            dc.setColor(0x194A22, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - 1, ty - th,           2,      th / 3);
            dc.fillRectangle(tx - 3, ty - th * 2 / 3,   6,  th / 3);
            dc.fillRectangle(tx - 5, ty - th / 3,       10, th / 3);
            dc.setColor(0xEEF4FF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(tx, ty - th + 1, 1, 1);
        }
    }

    hidden function drawCrowd(dc, ox, oy) {
        for (var i = 0; i < CROWD_N; i++) {
            var cx = wsx(_crowdX[i]) + ox; var cy = wsy(_crowdWorldY[i]) + oy;  // cached Y
            if (cx < -5 || cx > _w + 5) { continue; }
            var jmp = _crowdJump[i] * 3;
            dc.setColor(_crowdC[i], Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx - 1, cy - 5 - jmp, 3, 4);
            dc.setColor(0xCCAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cx - 2, cy - 9 - jmp, 4, 4);
        }
    }

    hidden function drawTrail(dc, ox, oy) {
        for (var i = 0; i < TRAIL_N; i++) {
            if (_trailLife[i] <= 0) { continue; }
            var sx = wsx(_trailX[i]) + ox; var sy = wsy(_trailY[i]) + oy;
            dc.setColor((_trailLife[i] > 18) ? 0x88BBDD : 0x4477AA, Graphics.COLOR_TRANSPARENT);
            if (_trailLife[i] > 20) { dc.fillRectangle(sx - 2, sy - 2, 4, 4); }
            else                    { dc.fillRectangle(sx - 1, sy - 1, 2, 2); }
        }
    }

    hidden function drawJumper(dc, ox, oy) {
        var jx = wsx(_posX) + ox; var jy = wsy(_posY) + oy;
        var col = _jumperColors[_jumperIdx]; var acc = _jumperAccents[_jumperIdx];
        // Pre-compute angle trig once — reused across all pose branches
        var baR = _bodyAngle * 3.14159 / 180.0;
        var cBa = Math.cos(baR); var sBa = Math.sin(baR);
        var saR = _skiAngle  * 3.14159 / 180.0;
        var cSa = Math.cos(saR); var sSa = Math.sin(saR);

        if (gameState == JS_LANDING && _landCrash) {
            var tR = (_landTick * 22).toFloat() * 3.14159 / 180.0;
            var tdx = (Math.cos(tR) * 5.0).toNumber(); var tdy = (Math.sin(tR) * 5.0).toNumber();
            dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 3 + tdx, jy - 4 + tdy, 6, 8);
            dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + tdx - 3, jy - 8 + tdy, 6, 5);
            dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT); dc.drawLine(jx - 5, jy + 1, jx + 6, jy + 2);
            if (_landTick % 4 < 2) { dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 3, jy - 3, 4, 3); }
        } else if (gameState == JS_LANDING) {
            var bdx = (cBa * 8.0).toNumber(); var bdy = -(sBa * 8.0).toNumber();
            if (_slideSpeed > 0.3) {
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(jx, jy, jx + bdx, jy + bdy); dc.drawLine(jx + 1, jy, jx + bdx + 1, jy + bdy); dc.drawLine(jx, jy + 1, jx + bdx, jy + bdy + 1);
                dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + bdx - 3, jy + bdy - 3, 6, 5);
                dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + bdx - 2, jy + bdy - 4, 5, 3);
                dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT); dc.drawLine(jx - 3, jy + 2, jx - 3 + bdx, jy + 2 + bdy); dc.drawLine(jx + 3, jy + 2, jx + 3 + bdx, jy + 2 + bdy);
            } else if (_landGood) {
                // Telemark — one ski forward
                dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 3, jy - 15, 6, 5);
                dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 4, jy - 14, 8, 3);
                dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 3, jy - 9, 6, 9);
                dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 7, jy, 4, 1); dc.fillRectangle(jx + 1, jy, 7, 1);
            } else {
                // Two-footed
                dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 3, jy - 13, 6, 5);
                dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 4, jy - 12, 8, 3);
                dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 3, jy - 7, 6, 7);
                dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 5, jy, 10, 1);
            }
        } else if (gameState == JS_FLIGHT) {
            if (_earlyTap || _spinningOut) {
                // Tumbling: body rotating rapidly, arms/skis flailing
                var tdx = (cBa * 7.0).toNumber(); var tdy = -(sBa * 7.0).toNumber();
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(jx, jy, jx + tdx, jy + tdy);
                dc.drawLine(jx + 1, jy, jx + tdx + 1, jy + tdy);
                dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + tdx - 3, jy + tdy - 3, 6, 5);
                dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + tdx - 3, jy + tdy - 4, 6, 3);
                // Skis flailing perpendicular — cos(tR+pi/2)=sin(tR)=(-tdy/7), sin(tR+pi/2)=cos(tR)=(tdx/7)
                var sdx = (tdy * 9 / 7).toNumber(); var sdy = (tdx * 9 / 7).toNumber();
                dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(jx - 2, jy, jx - 2 + sdx, jy + sdy);
                dc.drawLine(jx + 2, jy, jx + 2 - sdx, jy - sdy);
            } else if (_preparingLanding) {
                // Transitioning to landing: body upright, legs bending
                var prep = _preparingTick.toFloat() / 14.0; if (prep > 1.0) { prep = 1.0; }
                var bLen = (11.0 - prep * 3.5).toNumber();
                var bdx2 = (cBa * bLen).toNumber(); var bdy2 = -(sBa * bLen).toNumber();
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(jx, jy, jx + bdx2, jy + bdy2);
                dc.drawLine(jx + 1, jy, jx + bdx2 + 1, jy + bdy2);
                dc.drawLine(jx, jy + 1, jx + bdx2, jy + bdy2 + 1);
                dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + bdx2 - 3, jy + bdy2 - 3, 6, 5);
                dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + bdx2 - 3, jy + bdy2 - 4, 6, 3);
                // Legs bending forward (skis spreading into telemark prep)
                var legOut = (prep * 5.0).toNumber();
                dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(jx - 3, jy + 2, jx - 3 + legOut, jy + 8 + legOut);
                dc.drawLine(jx + 3, jy + 2, jx + 3, jy + 9);
            } else {
                // Normal V-style flight pose
                var bdx2 = (cBa * 11.0).toNumber(); var bdy2 = -(sBa * 11.0).toNumber();
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(jx, jy, jx + bdx2, jy + bdy2);
                dc.drawLine(jx + 1, jy, jx + bdx2 + 1, jy + bdy2);
                dc.drawLine(jx, jy + 1, jx + bdx2, jy + bdy2 + 1);
                dc.drawLine(jx, jy - 1, jx + bdx2, jy + bdy2 - 1);
                dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + bdx2 - 3, jy + bdy2 - 3, 6, 5);
                dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + bdx2 - 3, jy + bdy2 - 4, 6, 3);
                var sdx = (cSa * 10.0).toNumber(); var sdy = -(sSa * 10.0).toNumber();
                dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(jx - 4, jy + 2, jx - 4 + sdx, jy + 2 + sdy);
                dc.drawLine(jx + 4, jy + 2, jx + 4 + sdx, jy + 2 + sdy);
            }
        } else {
            // Inrun: crouched
            var dx = (cBa * 5.0).toNumber(); var dy = (sBa * 5.0).toNumber();
            dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + dx - 3, jy - 11 + dy, 6, 5);
            dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx + dx - 3, jy - 10 + dy, 6, 3);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 2 + dx, jy - 5 + dy, 5, 6);
            dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT); dc.drawLine(jx - 3, jy + 1, jx + 4, jy + 1);
        }
    }

    hidden function drawSnow(dc) {
        for (var i = 0; i < SNOW_N; i++) {
            dc.setColor((i % 3 == 0) ? 0xFFFFFF : 0xCCDDEE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_snowX[i].toNumber(), _snowY[i].toNumber(), (i % 5 == 0) ? 2 : 1, 1);
        }
    }

    hidden function drawWindBox(dc) {
        var bx = _w - 40; var by = _h * 38 / 100;
        var wAbs = _windCurrent; if (wAbs < 0.0) { wAbs = -wAbs; }
        var arrowTxt = (_windCurrent > 0.15) ? ">>" : ((_windCurrent < -0.15) ? "<<" : "--");
        var wInt = (wAbs * 10.0).toNumber();
        var wDec = (wAbs * 100.0).toNumber() % 10;
        // Shadow for readability, then red text — no background rectangle
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bx + 18, by + 2,  Graphics.FONT_XTINY, arrowTxt,              Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(bx + 18, by + 12, Graphics.FONT_XTINY, wInt + "." + wDec,     Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(bx + 17, by + 1,  Graphics.FONT_XTINY, arrowTxt,              Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(bx + 17, by + 11, Graphics.FONT_XTINY, wInt + "." + wDec,     Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawHUD(dc) {
        // Wind box always visible during jump
        drawWindBox(dc);

        if (gameState == JS_INRUN) {
            // Speed shown as realistic km/h for this venue's inrun length/angle
            var kmh = (55.0 + (_speed / _maxSpeed) * (_kmhMax - 55.0)).toNumber();
            var spC = (_inTakeoffZone && kmh >= (_kmhMax * 0.97).toNumber()) ? 0x44FF88 : 0x88AACC;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(6, 4, Graphics.FONT_XTINY, kmh + " km/h", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(spC, Graphics.COLOR_TRANSPARENT); dc.drawText(5, 3, Graphics.FONT_XTINY, kmh + " km/h", Graphics.TEXT_JUSTIFY_LEFT);
            if (!_inTakeoffZone) {
                // Before takeoff zone: show venue info + hill record on dark pill for contrast
                var hrStr = (_bestPerVenue[_venue] > 0.0) ? ("PR:" + _bestPerVenue[_venue].toNumber() + "m") : ("HS:" + _hillHSDist.toNumber() + "m");
                var infoTxt = _venueNames[_venue] + "  " + hrStr;
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_w / 2 - 52, _h - 20, 104, 14);
                dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h - 20, Graphics.FONT_XTINY, infoTxt, Graphics.TEXT_JUSTIFY_CENTER);
            }
            if (_inTakeoffZone) {
                var edgeX = _hillX[_hillLaunchIdx]; var zoneX = _hillX[_hillTableIdx];
                var ratio = (edgeX - _posX) / (edgeX - zoneX + 0.01);
                if (ratio < 0.0) { ratio = 0.0; } if (ratio > 1.0) { ratio = 1.0; }
                var bW = _w * 44 / 100; var bX = (_w - bW) / 2; var bY = _h - 22;
                // Bar background zones: blue=early, green=ok, bright=perfect
                dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX, bY, bW, 10);
                dc.setColor(0x1A4422, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX + bW * 50 / 100, bY, bW * 25 / 100, 10);
                dc.setColor(0x226633, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX + bW * 75 / 100, bY, bW * 14 / 100, 10);
                dc.setColor(0x33AA44, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX + bW * 89 / 100, bY, bW - bW * 89 / 100, 10);
                var markerX = bX + ((1.0 - ratio) * bW.toFloat()).toNumber();
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(markerX - 1, bY - 4, 3, 18);
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, bY - 16, Graphics.FONT_SMALL, "JUMP!", Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor((_tick % 4 < 2) ? 0xFF3333 : 0xFF8800, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, bY - 17, Graphics.FONT_SMALL, "JUMP!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (gameState == JS_FLIGHT) {
            var distN = _distance.toNumber();
            var distC = 0xFFFFFF;
            if (distN > _hillHSDist.toNumber()) { distC = 0xFFDD22; }
            else if (distN > _hillKDist.toNumber()) { distC = 0x44FF88; }
            var df = (distN > _hillKDist.toNumber()) ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, 4, df, distN + "m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(distC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, 3, df, distN + "m", Graphics.TEXT_JUSTIFY_CENTER);

            var aI = _bodyAngle.toNumber();
            var inSweet = (aI > 10 && aI < 28);
            var angleOk = (aI > 4 && aI < 44);

            // State-specific messages in the upper-middle area
            if (_earlyTap) {
                dc.setColor((_tick % 3 < 2) ? 0xFF2222 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 40 / 100, Graphics.FONT_SMALL, "TOO EARLY!", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (_spinningOut) {
                dc.setColor((_tick % 3 < 2) ? 0xFF4422 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 40 / 100, Graphics.FONT_SMALL, "OUT!", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (_preparingLanding) {
                dc.setColor((_tick % 4 < 2) ? 0x44FFAA : 0x22DD88, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 40 / 100, Graphics.FONT_SMALL, "LANDING...", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (_landReady && !_landTapDone) {
                // LAND! — shown in TOP area so it never covers the skier
                var hillY2 = hillYAtX(_posX); var hAb = hillY2 - _posY;
                if (hAb < 0.0) { hAb = 0.0; }
                var closeR = 1.0 - hAb / 30.0;
                if (closeR < 0.0) { closeR = 0.0; } if (closeR > 1.0) { closeR = 1.0; }
                var landC;
                if (closeR > 0.80) { landC = (_tick % 2 == 0) ? 0xFF2222 : 0xFF8800; }
                else if (closeR > 0.55) { landC = (_tick % 4 < 2) ? 0xFFFF44 : 0xFFAA22; }
                else { landC = 0x44FF44; }
                // LAND! — shadow only, no background rectangle
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 14 / 100 + 1, Graphics.FONT_SMALL, "LAND!", Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(landC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 14 / 100, Graphics.FONT_SMALL, "LAND!", Graphics.TEXT_JUSTIFY_CENTER);
                // Proximity bar just below the LAND! text
                var bW2 = _w * 36 / 100; var bX2 = (_w - bW2) / 2; var bY2 = _h * 22 / 100;
                dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX2, bY2, bW2, 5);
                dc.setColor(landC, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX2, bY2, (closeR * bW2.toFloat()).toNumber(), 5);
            } else if (!_landReady && !_preparingLanding && !_earlyTap && !_spinningOut) {
                // Sweet spot / balance cue
                if (inSweet) {
                    dc.setColor((_tick % 6 < 3) ? 0x44FFAA : 0x22DD88, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(_w / 2, _h * 19 / 100, Graphics.FONT_XTINY, "SWEET SPOT!", Graphics.TEXT_JUSTIFY_CENTER);
                } else if (!angleOk) {
                    dc.setColor((_tick % 4 < 2) ? 0xFF3333 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(_w / 2, _h * 19 / 100, Graphics.FONT_XTINY, "BALANCE!", Graphics.TEXT_JUSTIFY_CENTER);
                }
            }

            // ── Balance bar — ALWAYS visible during flight (not buried by bottom strip) ──
            // Shown in all states except crash/early-tap where player can do nothing
            if (!_earlyTap && !_spinningOut) {
                var bW = _w * 44 / 100; var bX = (_w - bW) / 2; var bY = _h * 71 / 100;
                // Background
                dc.setColor(0x111B28, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(bX - 1, bY - 1, bW + 2, 12);
                // Green zone (good angle range)
                var gL = bX + bW * 12 / 100; var gR = bX + bW * 65 / 100;
                dc.setColor(inSweet ? 0x22AA55 : 0x1A5522, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(gL, bY, gR - gL, 10);
                // Sweet spot (brighter center)
                var cL = bX + bW * 28 / 100; var cR = bX + bW * 48 / 100;
                dc.setColor(inSweet ? 0x44FF88 : 0x228844, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(cL, bY + 2, cR - cL, 6);
                // Body angle cursor (white bar)
                var bPct = (_bodyAngle - 3.0) / 46.0; if (bPct < 0.0) { bPct = 0.0; } if (bPct > 1.0) { bPct = 1.0; }
                var mP = bX + (bPct * bW.toFloat()).toNumber();
                dc.setColor(inSweet ? 0x88FFCC : 0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(mP - 2, bY - 3, 4, 16);
                // Accelerometer input indicator (blue — shows current tilt direction)
                var accelPct = 0.5 + accelX.toFloat() / 1600.0;
                if (accelPct < 0.0) { accelPct = 0.0; } if (accelPct > 1.0) { accelPct = 1.0; }
                var aP = bX + (accelPct * bW.toFloat()).toNumber();
                dc.setColor(0x3388FF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(aP - 1, bY + 1, 2, 8);
            }
        }

        if (gameState == JS_LANDING) {
            // Distance — black shadow on white snow
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, 4, Graphics.FONT_MEDIUM, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, 3, Graphics.FONT_MEDIUM, _distance.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);
            // Landing result — shadow only, no background rectangle
            var lMsg; var lC;
            if (_landCrash)     { lMsg = "CRASH!";    lC = 0xFF2222; }
            else if (_landGood) { lMsg = "TELEMARK!"; lC = 0x44FF88; }
            else                { lMsg = "TWO-FOOT";  lC = 0xFFAA44; }
            var lY = _h * 66 / 100;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, lY + 1, Graphics.FONT_SMALL, lMsg, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(lC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, lY, Graphics.FONT_SMALL, lMsg, Graphics.TEXT_JUSTIFY_CENTER);
            // Hill record / K-point — full-width dark strip for guaranteed contrast
            if (_distance > _hillKDist && !_landCrash) {
                var hrMsg = (_distance > _hillHSDist) ? "\u2605 HILL RECORD! \u2605" : "Beyond K!";
                var hrC2  = (_distance > _hillHSDist) ? ((_tick % 4 < 2) ? 0xFFDD22 : 0xFF8800) : 0x44FF88;
                var hrY   = _h * 80 / 100;
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, hrY + 1, Graphics.FONT_XTINY, hrMsg, Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(hrC2, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, hrY, Graphics.FONT_XTINY, hrMsg, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // Venue + jumper name + round (bottom) — dark strip for contrast on slope
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, _h - 15, _w, 15);
        dc.setColor(0x6677AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, _h - 14, Graphics.FONT_XTINY, _venueNames[_venue], Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_w - 4, _h - 14, Graphics.FONT_XTINY, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(_w / 2, _h - 14, Graphics.FONT_XTINY, "R" + _currentRound, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawMenu(dc) {
        dc.setColor(0xBBCCDD, 0xBBCCDD); dc.clear();
        dc.setColor(0xD8E8F2, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, 0, _w, _h / 2);
        // Snowy hill background
        dc.setColor(0xEEF4F8, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, _h * 48 / 100], [_w * 28 / 100, _h * 26 / 100], [_w * 52 / 100, _h * 34 / 100], [_w, _h * 48 / 100], [_w, _h], [0, _h]]);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[0, _h * 54 / 100], [_w * 22 / 100, _h * 38 / 100], [_w * 56 / 100, _h * 46 / 100], [_w, _h * 54 / 100], [_w, _h], [0, _h]]);
        // Yellow fence in menu
        dc.setColor(0xCC9900, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, _h * 55 / 100, _w, _h * 57 / 100);
        dc.drawLine(0, _h * 57 / 100, _w, _h * 59 / 100);

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 4 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 14 < 7) ? 0x2244BB : 0x1133AA, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 4 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x111122, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 17 / 100, Graphics.FONT_LARGE, "SKI JUMP", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 30 / 100, Graphics.FONT_XTINY, "4-Hills Tournament", Graphics.TEXT_JUSTIFY_CENTER);

        // Jumper selector
        var col = _jumperColors[_jumperIdx]; var acc = _jumperAccents[_jumperIdx];
        var jx = _w / 2; var jy = _h * 48 / 100;
        dc.setColor(0xDDAA77, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 4, jy - 16, 8, 7);
        dc.setColor(acc, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 4, jy - 14, 8, 3);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 4, jy - 9, 8, 11);
        dc.setColor(0x444455, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(jx - 7, jy + 2, 14, 2);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.drawText(jx, jy + 8, Graphics.FONT_XTINY, _jumperNames[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT); dc.drawText(jx, jy + 18, Graphics.FONT_XTINY, _jumperNat[_jumperIdx], Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(jx - 28, jy - 4, Graphics.FONT_XTINY, "<", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(jx + 28, jy - 4, Graphics.FONT_XTINY, ">", Graphics.TEXT_JUSTIFY_CENTER);

        if (_bestDist > 0.0) { dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 74 / 100, Graphics.FONT_XTINY, "BEST " + _bestDist.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER); }
        dc.setColor((_tick % 10 < 5) ? 0x2244BB : 0x1133AA, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 84 / 100, Graphics.FONT_XTINY, "Tap to start", Graphics.TEXT_JUSTIFY_CENTER);

        for (var i = 0; i < SNOW_N; i++) { dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(_snowX[i].toNumber(), _snowY[i].toNumber(), 1, 1); }
    }

    hidden function drawResult(dc) {
        dc.setColor(0x0A1422, 0x0A1422); dc.clear();
        var col = _jumperColors[_jumperIdx];
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 2 / 100, Graphics.FONT_XTINY, _jumperNames[_jumperIdx] + " [" + _jumperNat[_jumperIdx] + "]", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 12 / 100, Graphics.FONT_LARGE, _lastDist.toNumber() + " m", Graphics.TEXT_JUSTIFY_CENTER);

        var lMsg; var lC;
        if (_landCrash)     { lMsg = "CRASH!";    lC = 0xFF2222; }
        else if (_landGood) { lMsg = "TELEMARK!"; lC = 0x44FF88; }
        else                { lMsg = "TWO-FOOT";  lC = 0xFF8844; }
        dc.setColor(lC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_XTINY, lMsg, Graphics.TEXT_JUSTIFY_CENTER);

        // 5 judge scores — grayed if max/min (discarded)
        var jy = _h * 40 / 100;
        for (var j = 0; j < 5; j++) {
            var jvx = _w * (10 + j * 18) / 100;
            var jVal = _judgeScores[j];
            dc.setColor((jVal == maxJ() || jVal == minJ()) ? 0x444455 : 0xCCCCDD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(jvx, jy, Graphics.FONT_XTINY, jVal.toNumber() + "", Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x666677, Graphics.COLOR_TRANSPARENT); dc.drawLine(_w * 8 / 100, jy + 12, _w * 92 / 100, jy + 12);

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_SMALL, _lastScore.toNumber() + " pts", Graphics.TEXT_JUSTIFY_CENTER);

        var tqMsg;
        if      (_takeoffQuality >= 0.95) { tqMsg = "PERFECT takeoff!"; }
        else if (_takeoffQuality >= 0.70) { tqMsg = "Great takeoff"; }
        else if (_takeoffQuality >= 0.40) { tqMsg = "Good"; }
        else                               { tqMsg = "Early takeoff!"; }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 63 / 100, Graphics.FONT_XTINY, tqMsg, Graphics.TEXT_JUSTIFY_CENTER);
        if (_newHillRecord) {
            var hrC = (_tick % 4 < 2) ? 0xFFDD22 : 0xFF8800;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2 + 1, _h * 73 / 100 + 1, Graphics.FONT_XTINY, "★ HILL RECORD! ★", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(hrC, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 73 / 100, Graphics.FONT_XTINY, "★ HILL RECORD! ★", Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 83 / 100, Graphics.FONT_XTINY, _venueNames[_venue] + "  R" + _currentRound + " [" + (_jumpSlot + 1) + "/" + NUM_JUMPERS + "]", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor((_tick % 10 < 5) ? 0x44AAFF : 0x3388DD, Graphics.COLOR_TRANSPARENT); dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "Tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawStandings(dc) {
        dc.setColor(0x0A1422, 0x0A1422); dc.clear();
        var order = rankByCumScore();
        var rowH  = 13;
        var totalH = 14 + 5 + NUM_JUMPERS * rowH + 5 + 13;
        var sy = (_h - totalH) / 2;
        if (sy < 4) { sy = 4; }
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, sy, Graphics.FONT_XTINY, _venueNames[_venue] + "  PO R1", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(18, sy + 13, _w - 18, sy + 13);
        var rowsY = sy + 19;
        for (var r = 0; r < NUM_JUMPERS; r++) {
            var idx = order[r];
            var ry = rowsY + r * rowH;
            var isPlayer = (idx == _jumperIdx);
            var medal = (r == 0) ? 0xFFDD44 : ((r == 1) ? 0xCCCCCC : ((r == 2) ? 0xCC8844 : 0x445566));
            if (isPlayer) {
                dc.setColor(0x1A3A1A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(18, ry - 1, _w - 36, rowH - 1);
            }
            dc.setColor(medal, Graphics.COLOR_TRANSPARENT);
            dc.drawText(18, ry, Graphics.FONT_XTINY, (r + 1) + ".", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(isPlayer ? 0x44FF88 : _jumperColors[idx], Graphics.COLOR_TRANSPARENT);
            dc.drawText(34, ry, Graphics.FONT_XTINY, _jumperNames[idx], Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0xBBBBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w - 18, ry, Graphics.FONT_XTINY, _cumScores[idx].toNumber() + "p", Graphics.TEXT_JUSTIFY_RIGHT);
        }
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(18, rowsY + NUM_JUMPERS * rowH, _w - 18, rowsY + NUM_JUMPERS * rowH);
        dc.setColor((_tick % 10 < 5) ? 0x44AAFF : 0x3388DD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, rowsY + NUM_JUMPERS * rowH + 4, Graphics.FONT_XTINY, "Tap \u2192 Round 2", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawFinal(dc) {
        dc.setColor(0x0A1422, 0x0A1422); dc.clear();
        var order = rankByCumScore();
        var rowH  = 13;
        var totalH = 14 + 5 + NUM_JUMPERS * rowH + 5 + 13;
        var sy = (_h - totalH) / 2;
        if (sy < 4) { sy = 4; }
        var winC = _jumperColors[order[0]];
        dc.setColor(winC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, sy, Graphics.FONT_XTINY, "\u2605 " + _jumperNames[order[0]] + " WINS! \u2605", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(18, sy + 13, _w - 18, sy + 13);
        var rowsY = sy + 19;
        for (var r = 0; r < NUM_JUMPERS; r++) {
            var idx = order[r];
            var ry = rowsY + r * rowH;
            var isPlayer = (idx == _jumperIdx);
            var medal = (r == 0) ? 0xFFDD44 : ((r == 1) ? 0xCCCCCC : ((r == 2) ? 0xCC8844 : 0x445566));
            if (isPlayer) {
                dc.setColor(0x1A3A1A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(18, ry - 1, _w - 36, rowH - 1);
            }
            dc.setColor(medal, Graphics.COLOR_TRANSPARENT);
            dc.drawText(18, ry, Graphics.FONT_XTINY, (r + 1) + ".", Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(isPlayer ? 0x44FF88 : _jumperColors[idx], Graphics.COLOR_TRANSPARENT);
            dc.drawText(34, ry, Graphics.FONT_XTINY, _jumperNames[idx], Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0xBBBBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w - 18, ry, Graphics.FONT_XTINY, _cumScores[idx].toNumber() + "p", Graphics.TEXT_JUSTIFY_RIGHT);
        }
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(18, rowsY + NUM_JUMPERS * rowH, _w - 18, rowsY + NUM_JUMPERS * rowH);
        dc.setColor((_tick % 10 < 5) ? 0x44AAFF : 0x3388DD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, rowsY + NUM_JUMPERS * rowH + 4, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function rankByCumScore() {
        var order = new [NUM_JUMPERS];
        for (var i = 0; i < NUM_JUMPERS; i++) { order[i] = i; }
        for (var i = 0; i < NUM_JUMPERS - 1; i++) {
            for (var j = i + 1; j < NUM_JUMPERS; j++) {
                if (_cumScores[order[j]] > _cumScores[order[i]]) { var tmp = order[i]; order[i] = order[j]; order[j] = tmp; }
            }
        }
        return order;
    }
}
