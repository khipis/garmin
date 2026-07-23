using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

// ─────────────────────────────────────────────────────────────────────────────
//  Bitochi Moon Lander — view + game logic
//
//  Physics tick: 50 ms  (20 fps)
//
//  Controls:
//    Button / tap   → main thruster (upward impulse, 7-tick burn)
//    Tilt watch L/R → side thrusters (accelerometer X-axis, gentle deadzone)
//
//  Win:  land on the bright green flat pad with low velocity
//  Lose: crash anywhere else, land too fast, or run out of fuel
// ─────────────────────────────────────────────────────────────────────────────

enum { MS_MENU, MS_PLAY, MS_WIN, MS_CRASH }

const ML_SEGS     = 12;    // terrain segments
const ML_FUEL_MAX = 1000;  // starting fuel (units)

// Particle pool size — shared by the thruster plume, side-jet puffs and the
// landing dust kick-up. Small, fixed, pre-allocated (no per-frame alloc) so
// the 20 fps loop stays cheap on every watch. Ring-buffer overwrite of the
// oldest slot means bursts never allocate.
const ML_PMAX = 30;
// Particle kinds → colour ramp.
const ML_PK_EXHAUST = 0;   // main thruster plume (yellow → orange → red)
const ML_PK_SIDE    = 1;   // side-jet puff (pale blue)
const ML_PK_DUST    = 2;   // landing dust (grey)

// Global Bitochi leaderboard — higher composite landing score is better (DESC),
// no variant. Score accumulates across all soft landings in a session and is
// submitted once the player runs out of lives (end of game).
const LB_GAME_ID  = "moon";

class BitochiMoonView extends WatchUi.View {

    // Accelerometer values — set by delegate from sensor callbacks
    var accelX;
    var accelY;
    var accelZ;

    hidden var _w;
    hidden var _h;
    hidden var _timer;
    hidden var _tick;
    hidden var _gs;             // game state

    // Physics (float)
    hidden var _posX;           // lander centre X
    hidden var _posY;           // lander top Y (Y increases downward)
    hidden var _velX;
    hidden var _velY;
    hidden var _thrustTimer;    // remaining ticks of main thruster burn
    hidden var _smoothAx;       // smoothed accelerometer X

    // Fuel
    hidden var _fuel;

    // Terrain — ML_SEGS+1 vertices
    hidden var _terrX;
    hidden var _terrY;
    hidden var _padSeg;         // index of the first flat landing-pad segment
    hidden var _padWidth;       // how many segments wide the pad is (shrinks with level)

    // Difficulty from the shared OPTIONS screen (moon_diff: 0=Easy 1=Normal
    // 2=Hard). Drives lunar gravity and starting fuel, and segments the LB.
    hidden var _diff;

    // Progress
    hidden var _level;
    hidden var _lives;          // remaining lives (3 at game start)
    hidden var _best;
    hidden var _resultTick;
    hidden var _crashFuel;      // true when crash was caused by empty fuel

    // Leaderboard scoring (composite, cumulative across landings this session)
    hidden var _score;          // total session score submitted at game over
    hidden var _lastLand;       // points awarded for the most recent landing

    // Menu selection: 0 = TAP TO LAUNCH, 1 = LEADERBOARD
    hidden var _menuSel;
    // Cached tap hit-region for the LEADERBOARD menu row
    hidden var _lbRowX;
    hidden var _lbRowY;
    hidden var _lbRowW;
    hidden var _lbRowH;

    // Starfield (fixed per session)
    hidden var _starX;
    hidden var _starY;

    // ── Particle pool (exhaust plume / side puffs / landing dust) ──────────
    hidden var _pX;     // Float — position
    hidden var _pY;
    hidden var _pVX;    // Float — velocity (px/tick)
    hidden var _pVY;
    hidden var _pLife;  // Number — remaining ticks (0 = free slot)
    hidden var _pMax;   // Number — initial life, for fade ratio
    hidden var _pKind;  // Number — ML_PK_*
    hidden var _pNext;  // ring-buffer write cursor

    // ── Horizontal wind (higher levels only, small + telegraphed) ─────────
    hidden var _wind;   // Float — per-tick horizontal accel added to _velX

    // ── Landing quality + soft-landing streak (juice + bonus) ─────────────
    hidden var _landStreak;    // consecutive soft landings this session
    hidden var _lastQuality;   // "PERFECT" / "GOOD" / "OK" (last landing), or null
    hidden var _lastQClr;      // colour for the quality label
    hidden var _lastQBonus;    // bonus points from the quality tier
    hidden var _lastStreakBonus;

    // ── Meta-progression (shared, shop-ready via Progress module) ─────────
    hidden var _pgUnlockMsg;   // one-shot "UNLOCKED …" banner, or null
    hidden var _pgAwarded;     // guard: award coins/XP only once per game over
    hidden var _pgCoinsGain;   // coins granted at the last game over (overlay)

    // ── Non-blocking toast (daily bonus) ──────────────────────────────────
    hidden var _toastMsg;      // String or null
    hidden var _toastT;        // remaining ticks

    // ── Lander geometry constants (pixels) ─────────────────────────────────
    hidden var HW;   // hull half-width
    hidden var HH;   // hull height
    hidden var LH;   // leg height below hull bottom → total lander height = HH + LH

    // ─────────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        accelX = 0; accelY = 0; accelZ = 0;
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        // Scale lander to screen: reference is 260px, 10% smaller
        var sc = _w.toFloat() / 290.0;
        HW = (8.0  * sc + 0.5).toNumber();   // hull half-width
        HH = (8.0  * sc + 0.5).toNumber();   // hull height
        LH = (5.0  * sc + 0.5).toNumber();   // leg height

        Math.srand(Time.now().value());
        _tick = 0;
        _gs = MS_MENU;
        _smoothAx = 0.0;
        _thrustTimer = 0;
        _posX = 0.0; _posY = 0.0;
        _velX = 0.0; _velY = 0.0;
        _fuel = ML_FUEL_MAX;
        _level = 1; _lives = 3; _resultTick = 0; _crashFuel = false;
        _score = 0; _lastLand = 0;
        _menuSel = 0;
        _lbRowX = 0; _lbRowY = 0; _lbRowW = 0; _lbRowH = 0;

        var bs = Application.Storage.getValue("moonBest");
        _best = (bs != null) ? bs : 0;

        // Difficulty from the shared OPTIONS screen (moon_diff: 0/1/2).
        _diff = 1;
        var md = Application.Storage.getValue("moon_diff");
        if (md instanceof Number && md >= 0 && md <= 2) { _diff = md; }

        _terrX = new [ML_SEGS + 1];
        _terrY = new [ML_SEGS + 1];
        for (var i = 0; i <= ML_SEGS; i++) { _terrX[i] = 0; _terrY[i] = 0; }
        _padSeg = 0; _padWidth = 3;

        // 20 random stars (Y within upper 60% of screen below HUD)
        _starX = new [20]; _starY = new [20];
        for (var i = 0; i < 20; i++) {
            _starX[i] = (Math.rand().abs() % _w).toNumber();
            _starY[i] = 24 + (Math.rand().abs() % (_h * 58 / 100)).toNumber();
        }

        // Particle pool
        _pX = new [ML_PMAX]; _pY = new [ML_PMAX];
        _pVX = new [ML_PMAX]; _pVY = new [ML_PMAX];
        _pLife = new [ML_PMAX]; _pMax = new [ML_PMAX]; _pKind = new [ML_PMAX];
        for (var i = 0; i < ML_PMAX; i++) {
            _pX[i] = 0.0; _pY[i] = 0.0; _pVX[i] = 0.0; _pVY[i] = 0.0;
            _pLife[i] = 0; _pMax[i] = 1; _pKind[i] = 0;
        }
        _pNext = 0;

        _wind = 0.0;
        _landStreak = 0; _lastQuality = null; _lastQClr = 0xFFFFFF;
        _lastQBonus = 0; _lastStreakBonus = 0;
        _pgUnlockMsg = null; _pgAwarded = false; _pgCoinsGain = 0;
        _toastMsg = null; _toastT = 0;
    }

    // ── Level start ──────────────────────────────────────────────────────────
    hidden function startLevel() {
        // Random horizontal start, always near top
        var xRange = _w / 2;
        _posX = (_w / 4 + (Math.rand().abs() % xRange).toNumber()).toFloat();
        _posY = 28.0;
        _velX = ((Math.rand().abs() % 5).toNumber() - 2).toFloat() * 0.12;
        _velY = 0.15;
        _thrustTimer = 0;
        _resultTick = 0; _crashFuel = false;

        // Fuel decreases gently — every 3 levels drop by 30, min 500
        var f = ML_FUEL_MAX - ((_level - 1) / 3) * 30;
        if (f < 500) { f = 500; }
        // Difficulty fuel budget: Easy is generous, Hard is lean.
        f += [300, 0, -250][_diff];
        if (f < 250) { f = 250; }
        _fuel = f;

        // ── Wind: from level 4+, a small, steady horizontal breeze that the
        // HUD telegraphs (arrow + strength) so it's a fair challenge, not a
        // gotcha. Magnitude grows very gently with level and is scaled down
        // on Easy / up on Hard. Kept tiny (|accel| ≲ 0.010 px/tick²) so it
        // nudges drift rather than yanking the lander.
        _wind = 0.0;
        if (_level >= 4) {
            var mag = 3 + (_level - 4);           // 3..~ (integer milli-units)
            if (mag > 9) { mag = 9; }
            mag = mag * [60, 100, 135][_diff] / 100;
            var dir = ((Math.rand().abs() % 2) == 0) ? 1 : -1;
            _wind = dir.toFloat() * mag.toFloat() / 1000.0;
        }
        _lastQuality = null;

        generateTerrain();
        _gs = MS_PLAY;
    }

    // ── Terrain generation ───────────────────────────────────────────────────
    hidden function generateTerrain() {
        if (_level <= 3) { _padWidth = 4; }
        else if (_level <= 6) { _padWidth = 3; }
        else if (_level <= 9) { _padWidth = 2; }
        else { _padWidth = 1; }

        // Pad start: must fit _padWidth segments, avoid edges
        var maxStart = ML_SEGS - _padWidth - 1;
        if (maxStart < 1) { maxStart = 1; }
        _padSeg = 1 + (Math.rand().abs() % maxStart).toNumber();

        var segW = _w / ML_SEGS;
        for (var i = 0; i <= ML_SEGS; i++) { _terrX[i] = i * segW; }
        _terrX[ML_SEGS] = _w;

        var playTop = _h * 50 / 100;
        var playBot = _h - 14;

        var rough = 10 + _level * 3;
        if (rough > 46) { rough = 46; }

        var curY = _h * 68 / 100;
        for (var i = 0; i <= ML_SEGS; i++) {
            var step = (Math.rand().abs() % (rough * 2 + 1)).toNumber() - rough;
            curY += step;
            if (curY < playTop) { curY = playTop; }
            if (curY > playBot) { curY = playBot; }
            _terrY[i] = curY;
        }

        // Flatten all pad segments to the same Y
        var padY = _terrY[_padSeg];
        if (padY < _h * 55 / 100) { padY = _h * 55 / 100; }
        if (padY > playBot - 5)    { padY = playBot - 5; }
        for (var p = 0; p <= _padWidth; p++) {
            _terrY[_padSeg + p] = padY;
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 50, true);
        // The main menu is the shared root view; drop straight into a game.
        // Only auto-start from a fresh launch (MS_MENU) so returning from the
        // post-game leaderboard card doesn't restart the game.
        if (_gs == MS_MENU) {
            startGame();
            // Surface today's login-streak bonus as a one-shot toast (queued
            // by the App's checkIn on the day's first launch).
            try {
                var dm = Application.Storage.getValue("moon_daily_msg");
                if (dm != null) {
                    _toastMsg = dm; _toastT = 70;
                    Application.Storage.deleteValue("moon_daily_msg");
                }
            } catch (e) {}
        }
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    // ── Game loop ─────────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        if (_gs == MS_PLAY) {
            update();
        } else {
            _resultTick++;
        }
        // Particles animate in every state so the plume trails off after a
        // burn and the crash/landing dust keeps drifting on the result card.
        _updateParticles();
        if (_toastT > 0) { _toastT--; }
        WatchUi.requestUpdate();
    }

    hidden function update() {
        // ── Accelerometer smoothing (heavy smooth = gentle response)
        _smoothAx = _smoothAx * 0.70 + accelX.toFloat() * 0.30;

        // ── Gravity (increases slightly with level)
        var grav = 0.036 + (_level - 1).toFloat() * 0.003;
        if (grav > 0.070) { grav = 0.070; }
        // Difficulty gravity scale: Easy floats, Hard drops hard.
        grav = grav * [82, 100, 122][_diff].toFloat() / 100.0;
        _velY += grav;

        // ── Main thruster (upward impulse, fuel-gated)
        if (_thrustTimer > 0) {
            _thrustTimer--;
            if (_fuel > 0) {
                _velY -= 0.105;
                _fuel -= 3;
                if (_fuel < 0) { _fuel = 0; }
                _emitExhaust();
            }
        }

        // ── Side thrusters from accelerometer X tilt
        var deadzone = 140.0;
        var ax = _smoothAx;
        if (ax > deadzone) {
            var force = (ax - deadzone) / 7000.0;
            _velX += force;
            if (_fuel > 0) { _fuel -= 1; if (_fuel < 0) { _fuel = 0; } _emitSidePuff(-1); }
        } else if (ax < -deadzone) {
            var force2 = (ax + deadzone) / 7000.0;
            _velX += force2;
            if (_fuel > 0) { _fuel -= 1; if (_fuel < 0) { _fuel = 0; } _emitSidePuff(1); }
        }

        // ── Horizontal wind (small, telegraphed; higher levels only)
        _velX += _wind;

        // ── Very slight air drag
        _velX = _velX * 0.993;

        // ── Integrate
        _posX += _velX;
        _posY += _velY;

        // ── Horizontal wrap
        if (_posX < -HW.toFloat()) { _posX = _w.toFloat() + HW.toFloat(); }
        if (_posX > _w.toFloat() + HW.toFloat()) { _posX = -HW.toFloat(); }

        // ── Top boundary
        if (_posY < 24.0) {
            _posY = 24.0;
            if (_velY < 0.0) { _velY = 0.0; }
        }

        // ── Terrain collision
        checkLanding();
    }

    hidden function checkLanding() {
        var lx   = _posX.toNumber();
        var botY = _posY.toNumber() + HH + LH;   // bottom of landing legs

        for (var i = 0; i < ML_SEGS; i++) {
            var tx1 = _terrX[i]; var tx2 = _terrX[i + 1];
            // Quick horizontal cull
            if (lx + HW < tx1 || lx - HW > tx2) { continue; }

            var ty1 = _terrY[i]; var ty2 = _terrY[i + 1];
            var sw = tx2 - tx1;
            if (sw <= 0) { continue; }

            // Interpolate terrain height under lander centre
            var frac = (lx - tx1).toFloat() / sw.toFloat();
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
            var terrH = ty1 + ((ty2 - ty1).toFloat() * frac).toNumber();

            if (botY >= terrH) {
                var vDown = _velY;
                var vSide = _velX; if (vSide < 0.0) { vSide = -vSide; }
                var onPad = (i >= _padSeg && i < _padSeg + _padWidth);

                // Allowable speeds tighten each level
                var maxV = 1.60 - (_level - 1).toFloat() * 0.08;
                if (maxV < 0.70) { maxV = 0.70; }

                if (onPad && vDown < maxV && vSide < 0.55) {
                    // ── SOFT LANDING ─────────────────────────────────────────
                    _posY = (terrH - HH - LH).toFloat();
                    // Landing quality from how gently we touched down + fuel
                    // spare, relative to this level's tolerance. Each tier
                    // carries a matching bonus.
                    _rateLanding(vDown, vSide, maxV, _fuel);
                    // Soft-landing streak: consecutive safe touchdowns pay an
                    // escalating bonus (capped) — rewards a clean run.
                    _landStreak++;
                    _lastStreakBonus = (_landStreak - 1) * 40;
                    if (_lastStreakBonus > 200) { _lastStreakBonus = 200; }
                    _lastLand = landingScore(vDown, vSide, _fuel, _level)
                              + _lastQBonus + _lastStreakBonus;
                    _score += _lastLand;
                    _velX = 0.0; _velY = 0.0;
                    _thrustTimer = 0;
                    // Dust kick-up at the feet
                    _emitDust(terrH);
                    _gs = MS_WIN;
                    if (_level > _best) {
                        _best = _level;
                        try { Application.Storage.setValue("moonBest", _best); } catch (e) {}
                    }
                    doVibe(1);
                } else {
                    // ── CRASH ─────────────────────────────────────────────────
                    _crashFuel = (_fuel <= 0);
                    _lives--;
                    if (_lives < 0) { _lives = 0; }
                    _landStreak = 0;
                    _emitDust(terrH);
                    _gs = MS_CRASH;
                    // End of game → submit cumulative session score (DESC, no variant)
                    if (_lives <= 0) {
                        Leaderboard.submitScore(LB_GAME_ID, _score, _diffVariant());
                        Leaderboard.showPostGame(LB_GAME_ID, _diffVariant(), "MOON LANDER");
                        _awardProgress();
                    }
                    doVibe(2);
                }
                return;
            }
        }
    }

    // ── Composite landing score ──────────────────────────────────────────────
    //  base success points + soft-landing bonus (gentler = more) +
    //  remaining-fuel bonus + level bonus. Higher is better.
    hidden function landingScore(vDown, vSide, fuelLeft, level) {
        var v = vDown; if (v < 0.0) { v = -v; }
        var softBonus = ((1.60 - v) * 100.0).toNumber();   // ~0..160
        if (softBonus < 0) { softBonus = 0; }
        var fuelBonus = fuelLeft / 2;                       // up to 500
        if (fuelBonus < 0) { fuelBonus = 0; }
        var levelBonus = level * 50;
        return 100 + softBonus + fuelBonus + levelBonus;
    }

    // ── Landing quality ──────────────────────────────────────────────────────
    //  Classifies a soft landing as PERFECT / GOOD / OK from how far under the
    //  level's tolerance we touched down (descent + sideways speed) plus fuel
    //  spare. Sets _lastQuality / _lastQClr / _lastQBonus.
    hidden function _rateLanding(vDown, vSide, maxV, fuelLeft) {
        var v = vDown; if (v < 0.0) { v = -v; }
        // 0.0 (right at the limit) .. 1.0 (feather-soft, zero speed)
        var vScore = 1.0 - (v / maxV);
        if (vScore < 0.0) { vScore = 0.0; }
        var sSide = vSide; if (sSide < 0.0) { sSide = -sSide; }
        var sScore = 1.0 - (sSide / 0.55);
        if (sScore < 0.0) { sScore = 0.0; }
        var fuelOk = (fuelLeft > ML_FUEL_MAX / 3);
        if (vScore > 0.72 && sScore > 0.55 && fuelOk) {
            _lastQuality = "PERFECT"; _lastQClr = 0x44FFCC; _lastQBonus = 200;
        } else if (vScore > 0.45 && sScore > 0.35) {
            _lastQuality = "GOOD";    _lastQClr = 0x88FF88; _lastQBonus = 90;
        } else {
            _lastQuality = "OK";      _lastQClr = 0xFFDD22; _lastQBonus = 0;
        }
    }

    // Leaderboard variant = difficulty, so Easy/Normal/Hard rank separately.
    hidden function _diffVariant() {
        return ["easy", "normal", "hard"][_diff];
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  PARTICLES — thruster plume, side-jet puffs, landing/crash dust
    // ═════════════════════════════════════════════════════════════════════════
    hidden function _clearParticles() {
        for (var i = 0; i < ML_PMAX; i++) { _pLife[i] = 0; }
        _pNext = 0;
    }

    hidden function _spawnParticle(x, y, vx, vy, life, kind) {
        var i = _pNext;
        _pX[i] = x; _pY[i] = y; _pVX[i] = vx; _pVY[i] = vy;
        _pLife[i] = life; _pMax[i] = life; _pKind[i] = kind;
        _pNext = (_pNext + 1) % ML_PMAX;
    }

    // Main-thruster exhaust: shoots DOWN from the nozzle with a little spread.
    hidden function _emitExhaust() {
        var nozX = _posX;
        var nozY = _posY + HH.toFloat();
        for (var k = 0; k < 2; k++) {
            var spread = ((Math.rand().abs() % 9) - 4).toFloat() * 0.10;
            var vy     = 0.9 + (Math.rand().abs() % 7).toFloat() * 0.12;
            var life   = 5 + (Math.rand().abs() % 4);
            _spawnParticle(nozX, nozY, spread + _velX * 0.3, vy, life, ML_PK_EXHAUST);
        }
    }

    // Side-jet puff: dir = -1 fires from the LEFT nozzle (pushing right),
    // dir = +1 fires from the RIGHT nozzle. Small, pale, short-lived.
    hidden function _emitSidePuff(dir) {
        var sx = _posX + dir.toFloat() * (HW.toFloat() + 1.0);
        var sy = _posY + HH.toFloat() / 2.0;
        var vx = dir.toFloat() * (0.6 + (Math.rand().abs() % 5).toFloat() * 0.1);
        var vy = ((Math.rand().abs() % 5) - 2).toFloat() * 0.08;
        _spawnParticle(sx, sy, vx, vy, 4 + (Math.rand().abs() % 3), ML_PK_SIDE);
    }

    // Landing / crash dust: a kicked-up fan of grey motes at the feet, flung
    // up-and-out then settling under gravity.
    hidden function _emitDust(terrH) {
        var baseY = terrH.toFloat() - 1.0;
        for (var k = 0; k < 10; k++) {
            var vx = ((Math.rand().abs() % 21) - 10).toFloat() * 0.14;
            var vy = -0.3 - (Math.rand().abs() % 8).toFloat() * 0.10;
            var ox = ((Math.rand().abs() % (HW * 3 + 2)) - (HW + 1)).toFloat();
            _spawnParticle(_posX + ox, baseY, vx, vy,
                           8 + (Math.rand().abs() % 6), ML_PK_DUST);
        }
    }

    hidden function _updateParticles() {
        for (var i = 0; i < ML_PMAX; i++) {
            if (_pLife[i] <= 0) { continue; }
            _pX[i] += _pVX[i];
            _pY[i] += _pVY[i];
            if (_pKind[i] == ML_PK_DUST) {
                _pVY[i] += 0.045;         // dust falls back down
                _pVX[i] *= 0.92;
            } else {
                _pVX[i] *= 0.90;          // exhaust/puff slows + drifts
            }
            _pLife[i]--;
        }
    }

    // ── Meta-progression award (shared, shop-ready via Progress module) ───────
    //  Granted once at game over. Coins (future shop currency) + XP scale with
    //  the cumulative session score. Crossing a rank milestone unlocks a hull
    //  skin — the exact ownership a shop purchase would grant.
    hidden function _awardProgress() {
        if (_pgAwarded) { return; }
        _pgAwarded = true;
        var sc = _score;
        var coinsGain = 8 + sc / 60;
        if (coinsGain > 120) { coinsGain = 120; }
        var xpGain = 12 + sc / 40;
        if (xpGain > 150) { xpGain = 150; }
        _pgCoinsGain = coinsGain;
        Progress.addCoins(coinsGain);
        Progress.addXp(xpGain);
        var lvl = Progress.level();
        var uNeon = Progress.unlockIfReached("hull_neon", lvl, 3);
        var uGold = Progress.unlockIfReached("hull_gold", lvl, 6);
        if (uGold)      { _pgUnlockMsg = "UNLOCKED: GOLD HULL"; }
        else if (uNeon) { _pgUnlockMsg = "UNLOCKED: NEON HULL"; }
    }

    // Themed Moon-Lander rank ladder derived from the shared XP level.
    hidden function _moonRank(lvl) {
        if (lvl >= 25) { return "Legend"; }
        if (lvl >= 15) { return "Commander"; }
        if (lvl >= 10) { return "Captain"; }
        if (lvl >= 6)  { return "Pilot"; }
        if (lvl >= 3)  { return "Cadet"; }
        return "Rookie";
    }

    // Selected-and-owned hull colour. Falls back to the classic hull when the
    // chosen skin isn't owned yet — a locked pick never renders.
    hidden function _hullColor() {
        var sel = 0;
        try {
            var v = Application.Storage.getValue("moon_hull");
            if (v instanceof Number) { sel = v; }
        } catch (e) {}
        if (sel == 1 && Progress.owns("hull_neon")) { return 0x33FFCC; }
        if (sel == 2 && Progress.owns("hull_gold")) { return 0xFFD24A; }
        return 0xCCDDEE;
    }

    // ── Menu / leaderboard navigation ─────────────────────────────────────────
    function isMenu() { return _gs == MS_MENU; }

    function menuMove(d) {
        if (_gs != MS_MENU) { return; }
        _menuSel = (_menuSel + d + 2) % 2;
        WatchUi.requestUpdate();
    }

    function menuActivate() {
        if (_gs != MS_MENU) { return; }
        if (_menuSel == 1) {
            openLeaderboard();
        } else {
            startGame();
        }
    }

    // Touch: route a menu tap to the LEADERBOARD row or to launching the game.
    function handleMenuTap(tx, ty) {
        if (_gs != MS_MENU) { return false; }
        if (tx >= _lbRowX && tx <= _lbRowX + _lbRowW &&
            ty >= _lbRowY && ty <= _lbRowY + _lbRowH) {
            _menuSel = 1;
            openLeaderboard();
            return true;
        }
        _menuSel = 0;
        startGame();
        return true;
    }

    hidden function startGame() {
        _level = 1; _lives = 3; _score = 0; _lastLand = 0;
        _landStreak = 0; _lastStreakBonus = 0;
        _pgAwarded = false; _pgUnlockMsg = null; _pgCoinsGain = 0;
        _clearParticles();
        startLevel();
    }

    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _diffVariant(), "MOON LANDER");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // ── Input API (called from delegate) ─────────────────────────────────────
    function doAction() {
        if (_gs == MS_MENU) {
            menuActivate();
        } else if (_gs == MS_PLAY) {
            // Each press gives ~350 ms of thrust
            if (_thrustTimer < 7) { _thrustTimer = 7; }
        } else if (_gs == MS_WIN && _resultTick > 14) {
            _level++;
            startLevel();
        } else if (_gs == MS_CRASH && _resultTick > 14) {
            if (_lives > 0) {
                startLevel();       // retry same level with remaining lives
            } else {
                _gs = MS_MENU;      // game over → back to menu
                _level = 1;
            }
        }
    }

    hidden function doVibe(pat) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(
                    80, (pat == 1) ? 50 : 220)]);
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  RENDERING
    // ═════════════════════════════════════════════════════════════════════════

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        dc.setColor(0x000814, 0x000814);
        dc.clear();

        // Never render an in-game menu — the shared menu is the root view.
        if (_gs == MS_MENU) { startGame(); }

        drawStars(dc);
        drawTerrain(dc);

        if (_gs == MS_CRASH) {
            drawExplosion(dc);
        } else {
            drawLander(dc);
        }
        drawParticles(dc);

        drawHUD(dc);

        if (_gs == MS_WIN)   { drawOverlay(dc, true); }
        if (_gs == MS_CRASH) { drawOverlay(dc, false); }

        if (_toastT > 0 && _toastMsg != null) { drawToast(dc); }
    }

    // ── Particles ──────────────────────────────────────────────────────────
    hidden function drawParticles(dc) {
        for (var i = 0; i < ML_PMAX; i++) {
            var life = _pLife[i];
            if (life <= 0) { continue; }
            var x = _pX[i].toNumber();
            var y = _pY[i].toNumber();
            var frac = life.toFloat() / _pMax[i].toFloat();  // 1 (new) .. 0 (old)
            var kind = _pKind[i];
            var clr;
            var r;
            if (kind == ML_PK_EXHAUST) {
                // Hot core → cooling: yellow → orange → dark red as it fades.
                clr = (frac > 0.66) ? 0xFFEE44 : ((frac > 0.33) ? 0xFF8811 : 0xCC3300);
                r = (frac > 0.5) ? 2 : 1;
            } else if (kind == ML_PK_SIDE) {
                clr = (frac > 0.5) ? 0xBBE0FF : 0x5588AA;
                r = 1;
            } else {
                // Dust: fades pale grey → dark grey.
                clr = (frac > 0.5) ? 0x9A9A9A : 0x555555;
                r = (frac > 0.5) ? 2 : 1;
            }
            dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r);
        }
    }

    // ── Non-blocking toast (daily login bonus) ──────────────────────────────
    hidden function drawToast(dc) {
        var tw = _w * 74 / 100;
        var th = 20;
        var tx = (_w - tw) / 2;
        var ty = _h * 30 / 100;
        dc.setColor(0x0A1A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(tx, ty, tw, th, 5);
        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(tx, ty, tw, th, 5);
        dc.drawText(_w / 2, ty + th / 2 - 7, Graphics.FONT_XTINY, _toastMsg,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Stars ─────────────────────────────────────────────────────────────────
    hidden function drawStars(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 20; i++) {
            var big = (i % 5 == _tick % 5);
            var sz  = big ? 2 : 1;
            dc.fillRectangle(_starX[i], _starY[i], sz, sz);
        }
        // Earth visible in sky from level 4+
        if (_level >= 4) {
            var er = 14 + (_level / 4);
            if (er > 22) { er = 22; }
            var ex = _w * 80 / 100;
            var ey = _h * 14 / 100;
            dc.setColor(0x1133AA, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex, ey, er);
            dc.setColor(0x2255CC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex, ey, er - 2);
            dc.setColor(0x44AA33, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ex - er * 4 / 10, ey - er / 2, er * 4 / 5, er / 3);
            dc.fillRectangle(ex + er / 4, ey + er / 5, er * 2 / 3, er / 3);
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ex - er * 2 / 3, ey - er * 2 / 3, er * 4 / 3, er / 4);
            // Thin atmosphere ring
            dc.setColor(0x4488CC, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(ex, ey, er + 1);
        }
    }

    // ── HUD ──────────────────────────────────────────────────────────────────
    hidden function drawHUD(dc) {
        dc.setColor(0x030A14, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, 22);

        // Level (left)
        dc.setColor(0x6688AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 3, Graphics.FONT_XTINY, "Lv" + _level, Graphics.TEXT_JUSTIFY_LEFT);

        // Lives — 3 small hearts to the right of level text
        for (var i = 0; i < 3; i++) {
            var hx = 30 + i * 10;
            var hy = 4;
            if (i < _lives) {
                dc.setColor(0xFF2244, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x1A1A28, Graphics.COLOR_TRANSPARENT);
            }
            // Two lobes + bottom point
            dc.fillCircle(hx - 1, hy + 2, 2);
            dc.fillCircle(hx + 2, hy + 2, 2);
            dc.fillPolygon([[hx - 3, hy + 3], [hx + 4, hy + 3], [hx, hy + 8]]);
        }

        // Fuel bar (centre)
        var pct = _fuel.toFloat() / ML_FUEL_MAX.toFloat();
        if (pct > 1.0) { pct = 1.0; }
        var bw = _w * 38 / 100;
        var bx = (_w - bw) / 2;
        dc.setColor(0x081508, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, 7, bw, 8);
        var fc = (pct > 0.4) ? 0x44FF88 : ((pct > 0.2) ? 0xFFDD22 : 0xFF4433);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, 7, (bw.toFloat() * pct).toNumber(), 8);
        dc.setColor(0x1A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(bx, 7, bw, 8);

        // Vertical speed (right) — colour-coded: green=safe, yellow=risky, red=fatal
        var vy = _velY;
        var vc = (vy < 1.2) ? 0x44FF88 : ((vy < 2.2) ? 0xFFDD22 : 0xFF4433);
        dc.setColor(vc, Graphics.COLOR_TRANSPARENT);
        var vy10 = (vy * 10.0 + 0.5).toNumber();
        if (vy10 < 0) { vy10 = 0; }
        dc.drawText(_w - 4, 3, Graphics.FONT_XTINY,
            (vy10 / 10) + "." + (vy10 % 10), Graphics.TEXT_JUSTIFY_RIGHT);

        // ── Telegraphs below the strip (play only) ──
        if (_gs == MS_PLAY) {
            // Wind: direction arrows + strength bars, colour-tiered.
            if (_wind != 0.0) {
                var right = (_wind > 0.0);
                var mag = _wind; if (mag < 0.0) { mag = -mag; }
                var bars = (mag * 1000.0 / 3.0 + 0.5).toNumber();  // ~1..3
                if (bars < 1) { bars = 1; }
                if (bars > 3) { bars = 3; }
                var arrows = right ? ">>>" : "<<<";
                dc.setColor((bars >= 3) ? 0xFF8844 : 0x66AACC, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, 24, Graphics.FONT_XTINY,
                    right ? ("WIND " + arrows.substring(0, bars))
                          : (arrows.substring(0, bars) + " WIND"),
                    Graphics.TEXT_JUSTIFY_CENTER);
            }
            // Soft-landing streak flame.
            if (_landStreak >= 2) {
                dc.setColor(0xFFAA33, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w - 4, 24, Graphics.FONT_XTINY,
                    "x" + _landStreak, Graphics.TEXT_JUSTIFY_RIGHT);
            }
        }
    }

    // ── Terrain ───────────────────────────────────────────────────────────────
    hidden function drawTerrain(dc) {
        for (var i = 0; i < ML_SEGS; i++) {
            var x1 = _terrX[i]; var y1 = _terrY[i];
            var x2 = _terrX[i + 1]; var y2 = _terrY[i + 1];

            var isPad = (i >= _padSeg && i < _padSeg + _padWidth);
            if (isPad) {
                dc.setColor(0x556655, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x363636, Graphics.COLOR_TRANSPARENT);
            }
            dc.fillPolygon([[x1, y1], [x2, y2], [x2, _h], [x1, _h]]);

            if (isPad) {
                dc.setColor(0x88FF88, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x707070, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawLine(x1, y1, x2, y2);
        }

        // Landing pad marker poles (yellow) + blinking lights
        var px1 = _terrX[_padSeg];
        var px2 = _terrX[_padSeg + _padWidth];
        var py  = _terrY[_padSeg];
        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(px1, py - 8, px1, py);
        dc.drawLine(px2, py - 8, px2, py);
        if (_tick % 8 < 4) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px1 - 1, py - 10, 3, 3);
            dc.fillRectangle(px2 - 1, py - 10, 3, 3);
        }

        drawEasterEggs(dc);
    }

    hidden function drawEasterEggs(dc) {
        var segW = _w / ML_SEGS;

        // Level 2+: American flag planted on the surface
        if (_level >= 2) {
            var fSeg = (_padSeg > 2) ? 1 : ML_SEGS - 2;
            var fx = _terrX[fSeg] + segW / 2;
            var fy = _terrY[fSeg];
            // Pole
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx, fy - 26, 2, 26);
            // Flag body
            dc.setColor(0xDD2222, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx + 2, fy - 26, 16, 10);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx + 2, fy - 24, 16, 2);
            dc.fillRectangle(fx + 2, fy - 20, 16, 2);
            dc.fillRectangle(fx + 2, fy - 17, 16, 2);
            dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx + 2, fy - 26, 6, 6);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx + 3, fy - 25, 2, 2);
            dc.fillRectangle(fx + 6, fy - 23, 2, 2);
        }

        // Level 4+: Footprints trail on surface
        if (_level >= 4) {
            var fpSeg = (_padSeg > ML_SEGS / 2) ? 2 : ML_SEGS - 3;
            var fpx = _terrX[fpSeg];
            var fpy = _terrY[fpSeg];
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            for (var f = 0; f < 6; f++) {
                var ox = f * 9;
                var oy = (f % 2 == 0) ? 0 : -2;
                dc.fillRectangle(fpx + ox, fpy + oy - 1, 4, 3);
                dc.fillRectangle(fpx + ox + 1, fpy + oy - 3, 3, 2);
            }
        }

        // Level 3+: Alien peeking from behind a large rock
        if (_level >= 3) {
            var aSeg = (_padSeg < ML_SEGS / 2) ? ML_SEGS - 3 : 2;
            var ax = _terrX[aSeg] + segW / 2;
            var ay = _terrY[aSeg];
            // Big boulder
            dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax, ay - 6, 10);
            dc.setColor(0x4A4A4A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax - 1, ay - 7, 9);
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax - 2, ay - 8, 7);
            // Alien head bobbing above rock
            var bob = (_tick % 20 < 10) ? 0 : 2;
            dc.setColor(0x33CC33, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax + 8, ay - 18 - bob, 7);
            dc.setColor(0x44EE44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax + 7, ay - 19 - bob, 6);
            // Antennae
            dc.setColor(0x44DD44, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(ax + 5, ay - 24 - bob, ax + 3, ay - 28 - bob);
            dc.drawLine(ax + 9, ay - 24 - bob, ax + 11, ay - 28 - bob);
            dc.setColor(0xFFFF22, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax + 3, ay - 29 - bob, 2);
            dc.fillCircle(ax + 11, ay - 29 - bob, 2);
            // Big black eyes with glow
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax + 5, ay - 19 - bob, 3);
            dc.fillCircle(ax + 10, ay - 19 - bob, 3);
            dc.setColor(0x66FFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax + 4, ay - 21 - bob, 2, 2);
            dc.fillRectangle(ax + 9, ay - 21 - bob, 2, 2);
            // Wave arm
            if (_tick % 16 < 8) {
                dc.setColor(0x44DD44, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(ax + 14, ay - 17 - bob, ax + 19, ay - 12 - bob);
                dc.fillCircle(ax + 19, ay - 12 - bob, 2);
            }
        }

        // Level 5+: Crashed UFO with blinking light and smoke
        if (_level >= 5) {
            var uSeg = (_padSeg > 6) ? 0 : ML_SEGS - 1;
            var ux = _terrX[uSeg] + segW * 3 / 4;
            var uy = _terrY[uSeg];
            // Saucer body (tilted, half-buried)
            dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ux - 14, uy - 4, 28, 4);
            dc.setColor(0x777788, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ux - 10, uy - 8, 20, 5);
            dc.setColor(0x9999AA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ux - 6, uy - 12, 12, 5);
            // Dome
            dc.setColor(0x44CCEE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ux - 4, uy - 15, 8, 4);
            dc.setColor(0x88EEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ux - 2, uy - 14, 4, 2);
            // Blinking warning light
            if (_tick % 8 < 4) {
                dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ux, uy - 16, 3);
            }
            // Smoke wisps
            var sp = _tick % 12;
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ux - 2, uy - 18 - sp, 2, 2);
            dc.fillRectangle(ux + 3, uy - 16 - sp, 2, 2);
            dc.fillRectangle(ux - 4, uy - 20 - sp, 2, 2);
        }

        // Level 7+: Moon buggy / rover
        if (_level >= 7) {
            var rSeg = (_padSeg > 4) ? 3 : ML_SEGS - 4;
            var rx = _terrX[rSeg] + segW / 2;
            var ry = _terrY[rSeg];
            // Body
            dc.setColor(0xAAAA88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx - 10, ry - 10, 20, 7);
            dc.setColor(0xCCCCAA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx - 8, ry - 12, 16, 3);
            // Solar panel
            dc.setColor(0x2266AA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx - 14, ry - 14, 6, 8);
            dc.fillRectangle(rx + 8, ry - 14, 6, 8);
            dc.setColor(0x4488CC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx - 13, ry - 13, 4, 6);
            dc.fillRectangle(rx + 9, ry - 13, 4, 6);
            // Wheels
            dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(rx - 7, ry - 1, 4);
            dc.fillCircle(rx + 7, ry - 1, 4);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(rx - 7, ry - 1, 2);
            dc.fillCircle(rx + 7, ry - 1, 2);
            // Antenna
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(rx + 2, ry - 12, rx + 6, ry - 18);
            dc.fillCircle(rx + 6, ry - 18, 2);
        }

        // Level 9+: "WE COME IN PEACE" sign with lights
        if (_level >= 9) {
            var sSeg = (_padSeg > ML_SEGS / 2) ? 3 : ML_SEGS - 4;
            var sx = _terrX[sSeg] + segW / 2;
            var sy = _terrY[sSeg];
            // Post
            dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, sy - 20, 2, 20);
            // Sign board
            dc.setColor(0x1A2A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx - 20, sy - 22, 42, 10);
            dc.setColor(0x33AA33, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(sx - 20, sy - 22, 42, 10);
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx + 1, sy - 23, Graphics.FONT_XTINY, "PEACE :)", Graphics.TEXT_JUSTIFY_CENTER);
            // Blinking corner lights
            if (_tick % 12 < 6) {
                dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(sx - 20, sy - 22, 3, 3);
                dc.fillRectangle(sx + 19, sy - 22, 3, 3);
            }
        }

        // Level 11+: Skeletons of previous crashed landers
        if (_level >= 11) {
            var bSeg = (_padSeg > 7) ? 5 : ML_SEGS - 6;
            var bx = _terrX[bSeg] + segW * 2 / 3;
            var by = _terrY[bSeg];
            dc.setColor(0x886655, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 8, by - 8, 16, 6);
            dc.setColor(0x775544, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(bx - 8, by - 8, bx - 14, by - 2);
            dc.drawLine(bx + 8, by - 8, bx + 14, by - 2);
            dc.fillRectangle(bx - 16, by - 3, 6, 2);
            dc.fillRectangle(bx + 10, by - 3, 6, 2);
            dc.setColor(0x555544, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx, by - 18, Graphics.FONT_XTINY, "RIP", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Lander ────────────────────────────────────────────────────────────────
    hidden function drawLander(dc) {
        var lx = _posX.toNumber();
        var ly = _posY.toNumber();
        var hull = _hullColor();

        // Hull body
        dc.setColor(hull, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - HW, ly, HW * 2, HH);
        // Top highlight
        dc.setColor(_lighten(hull), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(lx - HW, ly, lx + HW, ly);

        // Cockpit window
        dc.setColor(0x1144AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - 3, ly + 1, 6, HH - 2);
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - 2, ly + 1, 3, 2);

        // Antenna stubs on top corners
        dc.setColor(hull, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(lx - HW, ly + 2, lx - HW - 2, ly - 1);
        dc.drawLine(lx + HW, ly + 2, lx + HW + 2, ly - 1);

        // Landing legs
        var legOut = HW + 4;
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(lx - HW + 2, ly + HH, lx - legOut, ly + HH + LH - 1);
        dc.drawLine(lx + HW - 2, ly + HH, lx + legOut, ly + HH + LH - 1);
        // Feet pads
        dc.drawLine(lx - legOut - 2, ly + HH + LH, lx - legOut + 2, ly + HH + LH);
        dc.drawLine(lx + legOut - 2, ly + HH + LH, lx + legOut + 2, ly + HH + LH);

        // Main-thruster nozzle glow (the plume itself is drawn by the
        // particle system in drawParticles()).
        if (_thrustTimer > 0 && _fuel > 0) {
            dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lx - 2, ly + HH, 4, 2);
        }
    }

    // Roughly brighten a colour ~35% (clamped) for a hull top-highlight.
    hidden function _lighten(color) {
        var r = (color >> 16) & 0xFF;
        var g = (color >> 8) & 0xFF;
        var b = color & 0xFF;
        r = r + (255 - r) * 35 / 100;
        g = g + (255 - g) * 35 / 100;
        b = b + (255 - b) * 35 / 100;
        return (r << 16) | (g << 8) | b;
    }

    // ── Explosion ─────────────────────────────────────────────────────────────
    hidden function drawExplosion(dc) {
        var lx = _posX.toNumber();
        var ly = _posY.toNumber() + HH / 2;
        var r = 3 + _resultTick * 2;
        if (r > 34) { r = 34; }
        dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lx, ly, r);
        dc.setColor(0xFF9922, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lx, ly, r * 2 / 3);
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lx, ly, r / 3 + 1);
    }

    // ── Win / Crash overlay ───────────────────────────────────────────────────
    hidden function drawOverlay(dc, won) {
        if (won) {
            dc.setColor(0x33FF77, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 22 / 100, Graphics.FONT_MEDIUM,
                "LANDED!", Graphics.TEXT_JUSTIFY_CENTER);
            // Landing quality tier (PERFECT / GOOD / OK)
            if (_lastQuality != null) {
                dc.setColor(_lastQClr, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 37 / 100, Graphics.FONT_SMALL,
                    _lastQuality + (_lastQuality.equals("PERFECT") ? "!" : ""),
                    Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 49 / 100, Graphics.FONT_XTINY,
                "+" + _lastLand + "   Score " + _score, Graphics.TEXT_JUSTIFY_CENTER);
            // Fuel + streak line
            var line = "Lv " + _level + " clear  -  Fuel " + _fuel;
            if (_landStreak >= 2) { line = "Streak x" + _landStreak + "  +" + _lastStreakBonus; }
            dc.setColor(_landStreak >= 2 ? 0xFFAA33 : 0x557799, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 58 / 100, Graphics.FONT_XTINY,
                line, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var isGameOver = (_lives <= 0);
            if (!isGameOver) {
                dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 27 / 100, Graphics.FONT_MEDIUM,
                    (_crashFuel ? "NO FUEL!" : "CRASH!"),
                    Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 43 / 100, Graphics.FONT_XTINY,
                    (_crashFuel ? "Fuel exhausted" : "Too fast or off pad"),
                    Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(_w / 2, _h * 53 / 100, Graphics.FONT_XTINY,
                    "Lives left: " + _lives, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_MEDIUM,
                    "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 34 / 100, Graphics.FONT_XTINY,
                    "Reached level " + _level +
                        (_best > 0 ? "  -  Best " + _best : ""),
                    Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 43 / 100, Graphics.FONT_XTINY,
                    "Score: " + _score, Graphics.TEXT_JUSTIFY_CENTER);
                _drawProgressLine(dc);
            }
        }

        if (_resultTick > 14) {
            var isGameOver = (!won && _lives <= 0);
            var c1 = won ? 0x44AAFF : (isGameOver ? 0xFF4444 : 0xFF8844);
            var c2 = won ? 0x2277CC : (isGameOver ? 0xCC2222 : 0xCC6622);
            var py = isGameOver ? (_h * 79 / 100) : (_h * 70 / 100);
            dc.setColor((_tick % 8 < 4) ? c1 : c2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, py, Graphics.FONT_XTINY,
                won ? "Tap for next level" :
                    (isGameOver ? "Tap for menu" : "Tap to retry"),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Progression summary (game over) ──────────────────────────────────────
    //  One compact line: rank/level + coin balance (+ daily streak), plus a
    //  one-shot gold "UNLOCKED" banner when the last game crossed a milestone.
    hidden function _drawProgressLine(dc) {
        var lvl = Progress.level();
        var streak = 0;
        try { streak = Progress.currentStreak(); } catch (e) {}
        dc.setColor(0xBFD8C4, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 53 / 100, Graphics.FONT_XTINY,
            "Lv " + lvl + " " + _moonRank(lvl) + " - " + Progress.coins() + "c",
            Graphics.TEXT_JUSTIFY_CENTER);
        if (streak > 1) {
            dc.setColor(0x66AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 61 / 100, Graphics.FONT_XTINY,
                "Daily streak " + streak, Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_pgUnlockMsg != null) {
            dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 69 / 100, Graphics.FONT_XTINY,
                _pgUnlockMsg, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Menu screen ───────────────────────────────────────────────────────────
    //  Decorative art is compressed ~18% into the upper portion so the two
    //  selectable rows (TAP TO LAUNCH + gold LEADERBOARD badge) sit clear of it
    //  near the bottom without overlapping on round watches.
    hidden function drawMenu(dc) {
        // Stars
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 20; i++) {
            dc.fillRectangle(_starX[i], _starY[i], 2, 2);
        }

        // Earth (upper-right)
        dc.setColor(0x1133AA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 82 / 100, _h * 16 / 100, 20);
        dc.setColor(0x2255CC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 82 / 100, _h * 16 / 100, 18);
        dc.setColor(0x44AA33, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 76 / 100, _h * 12 / 100, 9, 6);
        dc.fillRectangle(_w * 84 / 100, _h * 19 / 100, 7, 5);
        dc.setColor(0xEEEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 78 / 100, _h * 10 / 100, 13, 3);

        // Title
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, _h * 8 / 100 + 1, Graphics.FONT_MEDIUM,
            "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 8 / 100, Graphics.FONT_MEDIUM,
            "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 18 / 100, Graphics.FONT_LARGE,
            "MOON", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_SMALL,
            "LANDER", Graphics.TEXT_JUSTIFY_CENTER);

        // Lander hovering with tiny thruster flicker
        var lx = _w * 49 / 100;
        var ly = _h * 42 / 100 + ((_tick / 5) % 3);
        drawMenuLander(dc, lx, ly);

        // Controls hint (compact)
        dc.setColor(0x3A5060, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_XTINY,
            "Tilt: jets   TAP: thrust", Graphics.TEXT_JUSTIFY_CENTER);

        // Best
        if (_best > 0) {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 61 / 100, Graphics.FONT_XTINY,
                "BEST: Level " + _best, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Selectable rows ── (~10% smaller, space-aware, no overlap)
        var rowH = _h * 10 / 100;
        if (rowH < 16) { rowH = 16; }
        if (rowH > 22) { rowH = 22; }
        var gap   = 4;
        var rowW  = _w * 58 / 100;
        var rowX  = (_w - rowW) / 2;
        var lbY   = _h * 84 / 100 - rowH;
        var playY = lbY - gap - rowH;

        // Cache the LEADERBOARD row hit-region for touch input
        _lbRowX = rowX; _lbRowY = lbY; _lbRowW = rowW; _lbRowH = rowH;

        // PLAY row
        var pSel = (_menuSel == 0);
        dc.setColor(pSel ? 0x10341A : 0x0A220F, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rowX, playY, rowW, rowH, 5);
        dc.setColor(pSel ? 0x4AFF8A : 0x1A8A3A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rowX, playY, rowW, rowH, 5);
        if (pSel) {
            var ay = playY + rowH / 2;
            dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
        }
        dc.setColor(pSel ? 0x9AFFC4 : 0x4AC07A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rowX + rowW / 2 + 6, playY + (rowH - 14) / 2, Graphics.FONT_XTINY,
            "TAP TO LAUNCH", Graphics.TEXT_JUSTIFY_CENTER);

        // LEADERBOARD badge row
        LbBadge.drawRow(dc, rowX, lbY, rowW, rowH, _menuSel == 1);
    }

    hidden function drawMenuLander(dc, lx, ly) {
        dc.setColor(_hullColor(), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - HW, ly, HW * 2, HH);
        dc.setColor(0x1144AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - 3, ly + 1, 6, HH - 2);
        var legOut = HW + 4;
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(lx - HW + 2, ly + HH, lx - legOut, ly + HH + LH - 1);
        dc.drawLine(lx + HW - 2, ly + HH, lx + legOut, ly + HH + LH - 1);
        dc.drawLine(lx - legOut - 2, ly + HH + LH, lx - legOut + 2, ly + HH + LH);
        dc.drawLine(lx + legOut - 2, ly + HH + LH, lx + legOut + 2, ly + HH + LH);
        // Gentle thruster flicker
        if (_tick % 6 < 4) {
            dc.setColor(0xFF6600, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[lx - 3, ly + HH], [lx + 3, ly + HH], [lx, ly + HH + 4]]);
            dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lx - 2, ly + HH, 4, 2);
        }
    }
}
