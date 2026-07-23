using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Application;
using Toybox.Attention;

enum { SS_MENU, SS_PLAY, SS_DYING, SS_OVER }

// Power-up types
const SPU_SPEED  = 1;  // move faster for 10 steps
const SPU_SHRINK = 2;  // instantly lose 4 tail segments
const SPU_GHOST  = 3;  // walk through walls (wrap) for 8 steps
const SPU_SHIELD = 4;  // survive one self-collision
const SPU_MULTI  = 5;  // next 4 foods worth 3× score

// Chaos events
const SEV_NONE    = 0;
const SEV_REVERSE = 1;  // controls flipped for 5 steps
const SEV_PORTAL  = 2;  // two portals on the grid
const SEV_RAIN    = 3;  // 3 extra foods spawn at once
const SEV_MAGNET  = 4;  // nearest food pulled toward head each step

const SMAX_SNAKE = 180;
const SMAX_PU    = 3;
const SMAX_FOOD  = 4;
const SPART_N    = 12;

// Golden apple — a rare bonus food worth far more, but it only lives for a
// short window (SGA_LIFE ticks) before vanishing, so grabbing it is a
// risk/reward dash. Purely additive to the normal food economy.
const SGA_LIFE   = 90;   // ~7.2s of life at the 80 ms loop

// Death sequence length (ticks) — brief hit-flash + screen-shake before the
// game-over card, so a crash reads with impact instead of a hard cut.
const SDEATH_T   = 8;

// Main-menu rows (navigable like a chess-style menu):
//   row 0 = PLAY
//   row 1 = LEADERBOARD (shared global board)
const SMENU_ROWS = 2;
const SROW_PLAY  = 0;
const SROW_LB    = 1;

// Global leaderboard game id (matches _LOGOS / web id).
const SLB_GAME_ID = "serpent";

class BitochiSerpentView extends WatchUi.View {

    var accelX;

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    // Grid geometry
    hidden var _cellSize;
    hidden var _gridW; hidden var _gridH;
    hidden var _offX;  hidden var _offY;

    // Snake (ring-buffer style but simple arrays)
    hidden var _sX; hidden var _sY;
    hidden var _sLen;
    hidden var _dir; hidden var _nextDir;

    // Food
    hidden var _fX; hidden var _fY; hidden var _fCount;

    // Power-ups on the field
    hidden var _puX; hidden var _puY; hidden var _puType;
    hidden var _puCount;
    hidden var _puFlash;  // animation counter

    // Active effects (duration in steps remaining)
    hidden var _effectType; hidden var _effectSteps;
    hidden var _ghostOn; hidden var _shieldOn;
    hidden var _speedOn; hidden var _multiLeft;

    // Chaos event
    hidden var _evType; hidden var _evSteps;
    hidden var _reverseOn;
    hidden var _portalAx; hidden var _portalAy;
    hidden var _portalBx; hidden var _portalBy;
    hidden var _magnetOn;

    // Scoring
    hidden var _score; hidden var _best;
    hidden var _level; hidden var _foodEaten;
    hidden var _combo; hidden var _comboTick;

    // Step timing
    hidden var _stepBase;   // base ticks per step
    hidden var _stepCount;

    // Particles
    hidden var _prtX; hidden var _prtY;
    hidden var _prtVx; hidden var _prtVy;
    hidden var _prtLife; hidden var _prtColor;

    // Menu/UI
    hidden var _wobble;
    hidden var _flashTick;
    hidden var _menuRow;

    // Accel smoothing + auto-turn cooldown
    hidden var _smoothAx;
    hidden var _accelCooldown;

    // Snake body color palette (head→tail gradient, 6 steps). Points at the
    // active skin's gradient; head colour is cached separately.
    hidden var _snakePalette;
    hidden var _headColor;

    // Skin palettes (shop-ready cosmetics). CLASSIC is the free default; NEON
    // and GOLD unlock at rank and only render when both SELECTED and OWNED.
    hidden var _palClassic;
    hidden var _palNeon;
    hidden var _palGold;

    // OPTIONS "Speed" (sp_spd): 0=SLOW 1=NORMAL 2=FAST. Sets the base ticks per
    // step, i.e. how fast the snake moves. NORMAL (1) is today's rate so the
    // default experience is unchanged.
    hidden var _spdSel;
    // OPTIONS "Skin" (sp_skin): 0=CLASSIC 1=NEON 2=GOLD (see SerpentMenu).
    hidden var _skinSel;

    // ── Meta-progression surfacing ────────────────────────────────────────────
    // One-shot login-streak toast (queued by the App's checkIn) + one-shot
    // "skin unlocked" banner set by the game-over award pass.
    hidden var _toastMsg; hidden var _toastT;
    hidden var _pgUnlockMsg;

    // ── Golden apple (bonus food) ─────────────────────────────────────────────
    hidden var _gaX; hidden var _gaY; hidden var _gaLife;

    // ── Eat feedback (pop ring + brief flash on eating) ───────────────────────
    hidden var _eatFxX; hidden var _eatFxY; hidden var _eatFxLife;

    // ── Death feedback (flash + screen shake) ─────────────────────────────────
    hidden var _deathT;

    function initialize() {
        View.initialize();
        accelX = 0;
        _w = 0; _h = 0;
        _tick = 0; _gs = SS_MENU;
        _wobble = 0.0; _flashTick = 0;
        _menuRow = SROW_PLAY;
        _smoothAx = 0.0; _accelCooldown = 0;

        _best = Application.Storage.getValue("serpent_best");
        if (_best == null) { _best = 0; }

        _spdSel = 1;
        try {
            var sp = Application.Storage.getValue("sp_spd");
            if (sp instanceof Number && sp >= 0 && sp <= 2) { _spdSel = sp; }
        } catch (e) {}

        _skinSel = 0;
        try {
            var sk = Application.Storage.getValue("sp_skin");
            if (sk instanceof Number && sk >= 0 && sk <= 2) { _skinSel = sk; }
        } catch (e) {}

        _toastMsg = null; _toastT = 0;
        _pgUnlockMsg = null;
        _gaX = 0; _gaY = 0; _gaLife = 0;
        _eatFxX = 0; _eatFxY = 0; _eatFxLife = 0;
        _deathT = 0;

        _sX = new [SMAX_SNAKE]; _sY = new [SMAX_SNAKE];
        _fX = new [SMAX_FOOD]; _fY = new [SMAX_FOOD];
        _puX = new [SMAX_PU]; _puY = new [SMAX_PU];
        _puType = new [SMAX_PU];
        _prtX = new [SPART_N]; _prtY = new [SPART_N];
        _prtVx = new [SPART_N]; _prtVy = new [SPART_N];
        _prtLife = new [SPART_N]; _prtColor = new [SPART_N];
        for (var i = 0; i < SPART_N; i++) { _prtLife[i] = 0; }

        _fCount = 0; _puCount = 0; _puFlash = 0;
        _effectType = 0; _effectSteps = 0;
        _ghostOn = false; _shieldOn = false;
        _speedOn = false; _multiLeft = 0;
        _evType = SEV_NONE; _evSteps = 0;
        _reverseOn = false; _magnetOn = false;
        _portalAx = 0; _portalAy = 0; _portalBx = 0; _portalBy = 0;

        // Skin gradients (head→tail, 6 steps).
        //   CLASSIC — bright green head → deep teal tail (the original look)
        //   NEON    — electric cyan → magenta ribbon
        //   GOLD    — molten gold → bronze
        _palClassic = [0x44FF88, 0x33EE77, 0x22CC66, 0x1AAA55, 0x118844, 0x0A6633];
        _palNeon    = [0x33FFFF, 0x33CCFF, 0x6699FF, 0x9966FF, 0xCC66EE, 0xFF55CC];
        _palGold    = [0xFFEE66, 0xFFD24A, 0xF5B820, 0xD89818, 0xB87810, 0x9A5E0A];
        _snakePalette = _palClassic;
        _headColor = 0x44FF88;
    }

    // Resolve the active skin gradient: honour the player's selection only when
    // that skin is actually OWNED (progression- or shop-granted), otherwise
    // fall back to CLASSIC so a locked pick never renders.
    hidden function applySkin() {
        var owned = false;
        _snakePalette = _palClassic;
        _headColor = 0x44FF88;
        if (_skinSel == 1) {
            try { owned = Progress.owns("skin_neon"); } catch (e) { owned = false; }
            if (owned) { _snakePalette = _palNeon; _headColor = 0x66FFFF; }
        } else if (_skinSel == 2) {
            try { owned = Progress.owns("skin_gold"); } catch (e) { owned = false; }
            if (owned) { _snakePalette = _palGold; _headColor = 0xFFE24A; }
        }
    }

    function onLayout(dc) {}

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 80, true);
        // The main menu is the shared root view; drop straight into a game.
        // Only auto-start from a fresh launch (SS_MENU) so returning from the
        // post-game leaderboard card doesn't restart the game.
        if (_gs == SS_MENU) {
            startGame();
            // Surface today's login-streak bonus as a one-shot, non-blocking
            // toast over the board (queued by the App's checkIn on the day's
            // first launch). Guarded so a missing/old value never disrupts play.
            try {
                var dm = Application.Storage.getValue("sp_daily_msg");
                if (dm != null) {
                    _toastMsg = dm; _toastT = 90;
                    Application.Storage.deleteValue("sp_daily_msg");
                }
            } catch (e) {}
        }
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    hidden function setupGrid() {
        _cellSize = 8;
        var hudH = 18;
        // 18% margin ensures the rectangular grid clears the round bezel on all Garmin watches.
        // Square grid (equal W and H) prevents asymmetric clipping.
        var margin = _w * 18 / 100;
        var cells = (_w - margin * 2) / _cellSize;
        _gridW = cells;
        _gridH = cells;  // square grid — fits inside circle cleanly
        _offX = (_w - _gridW * _cellSize) / 2;
        var gridPx = _gridH * _cellSize;
        _offY = hudH + (_h - hudH - gridPx) / 2;
        if (_offY < hudH) { _offY = hudH; }
    }

    hidden function startGame() {
        if (_w == 0) { return; }
        setupGrid();
        applySkin();

        _pgUnlockMsg = null;
        _gaX = 0; _gaY = 0; _gaLife = 0;
        _eatFxX = 0; _eatFxY = 0; _eatFxLife = 0;
        _deathT = 0;

        _sLen = 4;
        var mx = _gridW / 2; var my = _gridH / 2;
        for (var i = 0; i < _sLen; i++) { _sX[i] = mx - i; _sY[i] = my; }
        _dir = 0; _nextDir = 0;

        _score = 0; _level = 1; _foodEaten = 0;
        _combo = 0; _comboTick = 0;
        _fCount = 0; _puCount = 0;
        _ghostOn = false; _shieldOn = false;
        _speedOn = false; _multiLeft = 0;
        _effectType = 0; _effectSteps = 0;
        _evType = SEV_NONE; _evSteps = 0;
        _reverseOn = false; _magnetOn = false;

        for (var i = 0; i < SPART_N; i++) { _prtLife[i] = 0; }

        // Base ticks per step from the OPTIONS "Speed" setting: SLOW=7,
        // NORMAL=5 (today's default), FAST=3. Lower = quicker snake.
        _stepBase = [7, 5, 3][_spdSel];
        _stepCount = 0;
        _accelCooldown = 0;

        spawnFood(); spawnFood();
        _gs = SS_PLAY;
    }

    // ── Spawning helpers ─────────────────────────────────────────────────────

    hidden function spawnFood() {
        if (_fCount >= SMAX_FOOD) { return; }
        for (var t = 0; t < 60; t++) {
            var fx = (Math.rand() % _gridW).toNumber();
            var fy = (Math.rand() % _gridH).toNumber();
            if (!isSnake(fx, fy) && !isFood(fx, fy) && !isPu(fx, fy)) {
                _fX[_fCount] = fx; _fY[_fCount] = fy; _fCount++;
                return;
            }
        }
    }

    hidden function spawnPowerup() {
        if (_puCount >= SMAX_PU) { return; }
        for (var t = 0; t < 60; t++) {
            var px = (Math.rand() % _gridW).toNumber();
            var py = (Math.rand() % _gridH).toNumber();
            if (!isSnake(px, py) && !isFood(px, py) && !isPu(px, py)) {
                _puX[_puCount] = px; _puY[_puCount] = py;
                _puType[_puCount] = 1 + (Math.rand() % 5).toNumber();
                _puCount++;
                return;
            }
        }
    }

    hidden function spawnGoldenApple() {
        for (var t = 0; t < 60; t++) {
            var gx = (Math.rand() % _gridW).toNumber();
            var gy = (Math.rand() % _gridH).toNumber();
            if (!isSnake(gx, gy) && !isFood(gx, gy) && !isPu(gx, gy)
                && !(gx == _gaX && gy == _gaY && _gaLife > 0)) {
                _gaX = gx; _gaY = gy; _gaLife = SGA_LIFE;
                return;
            }
        }
    }

    // Fire the eat feedback: a burst of particles plus a short expanding pop
    // ring centred on the eaten cell (a brief flash of impact).
    hidden function eatFx(cx, cy, col) {
        spawnParticles(cx, cy, col);
        _eatFxX = cx; _eatFxY = cy; _eatFxLife = 5;
    }

    hidden function isSnake(x, y) {
        for (var i = 0; i < _sLen; i++) {
            if (_sX[i] == x && _sY[i] == y) { return true; }
        }
        return false;
    }

    hidden function isFood(x, y) {
        for (var i = 0; i < _fCount; i++) {
            if (_fX[i] == x && _fY[i] == y) { return true; }
        }
        return false;
    }

    hidden function isPu(x, y) {
        for (var i = 0; i < _puCount; i++) {
            if (_puX[i] == x && _puY[i] == y) { return true; }
        }
        return false;
    }

    // ── Main tick ─────────────────────────────────────────────────────────────

    function onTick() as Void {
        _tick++;
        _wobble += 0.10;
        _flashTick++;
        _puFlash = (_tick % 10 < 5) ? 1 : 0;

        // Cosmetic timers tick regardless of state so flashes/toasts finish
        // gracefully across the play → death → over transitions.
        if (_toastT > 0)    { _toastT--; }
        if (_eatFxLife > 0) { _eatFxLife--; }

        // Smooth accelerometer (60/40 — responsive but not jittery)
        _smoothAx = _smoothAx * 0.60 + accelX.toFloat() * 0.40;

        // Death sequence: brief hit-flash + shake, then finalise the game over.
        if (_gs == SS_DYING) {
            updateParticles();
            _deathT--;
            if (_deathT <= 0) { finalizeGameOver(); }
            WatchUi.requestUpdate();
            return;
        }

        if (_gs == SS_PLAY) {
            updateParticles();
            if (_accelCooldown > 0) { _accelCooldown--; }

            // Golden apple: age it out, and occasionally spawn a fresh one when
            // none is on the field — a rare, short-lived, high-value target.
            if (_gaLife > 0) { _gaLife--; }
            if (_gaLife <= 0 && _tick % 260 == 130) { spawnGoldenApple(); }

            var ticksPerStep = _stepBase;
            if (_speedOn) { ticksPerStep = ticksPerStep / 2; if (ticksPerStep < 2) { ticksPerStep = 2; } }

            _stepCount++;
            if (_stepCount >= ticksPerStep) {
                _stepCount = 0;
                gameStep();
            }

            // Accelerometer tilt → turn (threshold 500 avoids spurious auto-turns from wrist motion)
            if (_accelCooldown == 0) {
                if (_smoothAx > 500.0) {
                    turnRight();
                    _accelCooldown = 10;  // at least 2 steps between accel-turns
                } else if (_smoothAx < -500.0) {
                    turnLeft();
                    _accelCooldown = 10;
                }
            }

            // Combo decay
            if (_comboTick > 0) { _comboTick--; }
            else { _combo = 0; }

            // Periodic chaos events
            if (_tick % 200 == 0 && _evType == SEV_NONE) {
                triggerEvent();
            }
            // Spawn power-up occasionally
            if (_tick % 140 == 70 && _puCount < 2) {
                spawnPowerup();
            }
        }

        WatchUi.requestUpdate();
    }

    hidden function updateParticles() {
        for (var i = 0; i < SPART_N; i++) {
            if (_prtLife[i] > 0) {
                _prtLife[i]--;
                _prtX[i] = _prtX[i] + _prtVx[i];
                _prtY[i] = _prtY[i] + _prtVy[i];
                _prtVy[i] = _prtVy[i] + 0.25;
            }
        }
    }

    hidden function spawnParticles(sx, sy, col) {
        for (var i = 0; i < SPART_N; i++) {
            if (_prtLife[i] == 0) {
                _prtX[i] = sx.toFloat();
                _prtY[i] = sy.toFloat();
                var rAngle = (Math.rand() % 628).toFloat() / 100.0;
                var spd = 0.8 + (Math.rand() % 18).toFloat() * 0.12;
                _prtVx[i] = Math.cos(rAngle) * spd;
                _prtVy[i] = Math.sin(rAngle) * spd - 1.2;
                _prtLife[i] = 8 + (Math.rand() % 7).toNumber();
                _prtColor[i] = col;
            }
        }
    }

    // ── Chaos events ─────────────────────────────────────────────────────────

    hidden function triggerEvent() {
        var e = 1 + (Math.rand() % 4).toNumber();
        _evType = e;
        if (e == SEV_REVERSE) {
            _reverseOn = true; _evSteps = 7;
            doVibe(1);
        } else if (e == SEV_PORTAL) {
            placePortals(); _evSteps = 20;
        } else if (e == SEV_RAIN) {
            for (var i = 0; i < 3; i++) { spawnFood(); }
            _evType = SEV_NONE;
        } else if (e == SEV_MAGNET) {
            _magnetOn = true; _evSteps = 12;
        }
    }

    hidden function placePortals() {
        var side = (Math.rand() % 4).toNumber();
        var opp  = (side + 2) % 4;
        var posA = edgePos(side);
        var posB = edgePos(opp);
        _portalAx = posA[0]; _portalAy = posA[1];
        _portalBx = posB[0]; _portalBy = posB[1];
    }

    hidden function edgePos(side) {
        if (side == 0) { return [(Math.rand() % _gridW).toNumber(), 0]; }
        if (side == 1) { return [_gridW - 1, (Math.rand() % _gridH).toNumber()]; }
        if (side == 2) { return [(Math.rand() % _gridW).toNumber(), _gridH - 1]; }
        return [0, (Math.rand() % _gridH).toNumber()];
    }

    hidden function tickEvent() {
        if (_evSteps > 0) {
            _evSteps--;
            if (_evSteps == 0) {
                if (_evType == SEV_REVERSE) { _reverseOn = false; }
                if (_evType == SEV_MAGNET)  { _magnetOn = false; }
                _evType = SEV_NONE;
            }
        }
        if (_effectSteps > 0) {
            _effectSteps--;
            if (_effectSteps == 0) {
                if (_effectType == SPU_SPEED) { _speedOn = false; }
                if (_effectType == SPU_GHOST) { _ghostOn = false; }
                if (_effectType == SPU_SHIELD) { _shieldOn = false; }
                _effectType = 0;
            }
        }
        if (_multiLeft > 0) { _multiLeft--; }
    }

    // ── Core step ────────────────────────────────────────────────────────────

    hidden function gameStep() {
        tickEvent();

        // Magnet: pull nearest food one step closer
        if (_magnetOn && _fCount > 0) {
            magnetPull();
        }

        // Shift body
        for (var i = _sLen - 1; i > 0; i--) {
            _sX[i] = _sX[i - 1]; _sY[i] = _sY[i - 1];
        }

        // Commit queued direction — reverseOn only flips CONTROLS (see turnLeft/Right), NOT movement
        _dir = _nextDir;
        var effectiveDir = _dir;

        var hx = _sX[0]; var hy = _sY[0];
        if (effectiveDir == 0) { hx++; }
        else if (effectiveDir == 1) { hy++; }
        else if (effectiveDir == 2) { hx--; }
        else { hy--; }

        // Portal check
        if (_evType == SEV_PORTAL) {
            if (hx == _portalAx && hy == _portalAy) {
                hx = _portalBx; hy = _portalBy; doVibe(0);
            } else if (hx == _portalBx && hy == _portalBy) {
                hx = _portalAx; hy = _portalAy; doVibe(0);
            }
        }

        // Wall collision
        if (hx < 0 || hx >= _gridW || hy < 0 || hy >= _gridH) {
            if (_ghostOn) {
                if (hx < 0)        { hx = _gridW - 1; }
                else if (hx >= _gridW) { hx = 0; }
                if (hy < 0)        { hy = _gridH - 1; }
                else if (hy >= _gridH) { hy = 0; }
            } else {
                beginDeath(); return;
            }
        }

        // Self-collision (skip very last segment — it just vacated this spot)
        for (var i = 1; i < _sLen - 1; i++) {
            if (_sX[i] == hx && _sY[i] == hy) {
                if (_shieldOn) {
                    _shieldOn = false; _effectType = 0; _effectSteps = 0;
                    doVibe(1); break;
                } else {
                    beginDeath(); return;
                }
            }
        }

        _sX[0] = hx; _sY[0] = hy;

        // Eat food?
        for (var i = 0; i < _fCount; i++) {
            if (_fX[i] == hx && _fY[i] == hy) {
                _combo++;
                _comboTick = 12;  // reset combo decay window
                var pts = (10 + _combo * 2) * _level;
                if (_multiLeft > 0) { pts = pts * 3; _multiLeft--; }
                _score += pts;
                _foodEaten++;

                // BUG FIX: copy last segment to new tail slot BEFORE incrementing
                // so drawSnake never reads an uninitialized null element
                if (_sLen < SMAX_SNAKE - 1) {
                    _sX[_sLen] = _sX[_sLen - 1];
                    _sY[_sLen] = _sY[_sLen - 1];
                    _sLen++;
                }

                eatFx(
                    _offX + hx * _cellSize + _cellSize / 2,
                    _offY + hy * _cellSize + _cellSize / 2,
                    _headColor);
                doVibe(0);

                // Remove eaten food, compact
                _fX[i] = _fX[_fCount - 1];
                _fY[i] = _fY[_fCount - 1];
                _fCount--;
                spawnFood();

                // Level up every 6 foods
                if (_foodEaten % 6 == 0) {
                    _level++;
                    if (_stepBase > 3) { _stepBase--; }
                    spawnPowerup();
                }
                break;
            }
        }

        // Eat the golden apple? Bonus food — big score, grows the snake, and
        // is only on the field briefly, so it's a rewarding risk to chase.
        if (_gaLife > 0 && _gaX == hx && _gaY == hy) {
            _combo++;
            _comboTick = 12;
            var gpts = (50 + _combo * 5) * _level;
            if (_multiLeft > 0) { gpts = gpts * 3; _multiLeft--; }
            _score += gpts;
            _foodEaten++;
            if (_sLen < SMAX_SNAKE - 1) {
                _sX[_sLen] = _sX[_sLen - 1];
                _sY[_sLen] = _sY[_sLen - 1];
                _sLen++;
            }
            eatFx(
                _offX + hx * _cellSize + _cellSize / 2,
                _offY + hy * _cellSize + _cellSize / 2,
                0xFFD24A);
            doVibe(1);
            _gaLife = 0;
            if (_foodEaten % 6 == 0) {
                _level++;
                if (_stepBase > 3) { _stepBase--; }
                spawnPowerup();
            }
        }

        // Collect power-up?
        for (var i = 0; i < _puCount; i++) {
            if (_puX[i] == hx && _puY[i] == hy) {
                activatePu(_puType[i]);
                spawnParticles(
                    _offX + hx * _cellSize + _cellSize / 2,
                    _offY + hy * _cellSize + _cellSize / 2,
                    puColor(_puType[i]));
                _puX[i] = _puX[_puCount - 1];
                _puY[i] = _puY[_puCount - 1];
                _puType[i] = _puType[_puCount - 1];
                _puCount--;
                break;
            }
        }
    }

    hidden function magnetPull() {
        // Find nearest food and move it one step closer to head
        var hx = _sX[0]; var hy = _sY[0];
        var best = -1; var bestD = 99999;
        for (var i = 0; i < _fCount; i++) {
            var dx = _fX[i] - hx; var dy = _fY[i] - hy;
            if (dx < 0) { dx = -dx; } if (dy < 0) { dy = -dy; }
            var d = dx + dy;
            if (d < bestD) { bestD = d; best = i; }
        }
        if (best < 0) { return; }
        var fx = _fX[best]; var fy = _fY[best];
        var nx = fx; var ny = fy;
        if (fx > hx) { nx--; } else if (fx < hx) { nx++; }
        else if (fy > hy) { ny--; } else if (fy < hy) { ny++; }
        if (!isSnake(nx, ny) && !isPu(nx, ny)) {
            _fX[best] = nx; _fY[best] = ny;
        }
    }

    hidden function activatePu(puType) {
        doVibe(1);
        if (puType == SPU_SPEED) {
            _speedOn = true; _effectType = SPU_SPEED; _effectSteps = 12;
        } else if (puType == SPU_SHRINK) {
            if (_sLen > 6) { _sLen -= 4; } else { _sLen = 3; }
            _score += 30;
        } else if (puType == SPU_GHOST) {
            _ghostOn = true; _effectType = SPU_GHOST; _effectSteps = 10;
        } else if (puType == SPU_SHIELD) {
            _shieldOn = true; _effectType = SPU_SHIELD; _effectSteps = 15;
        } else if (puType == SPU_MULTI) {
            _multiLeft = 4;
        }
    }

    // Kick off the short death sequence (flash + shake). The heavy lifting
    // (best/leaderboard/progress) runs in finalizeGameOver once it elapses.
    hidden function beginDeath() {
        _gs = SS_DYING;
        _deathT = SDEATH_T;
        doVibe(2);
    }

    hidden function finalizeGameOver() {
        _gs = SS_OVER;
        if (_score > _best) {
            _best = _score;
            try { Application.Storage.setValue("serpent_best", _best); } catch (e) {}
        }
        // Award shared meta-progression (coins + XP) before submitting so the
        // game-over card can show the fresh balance / any new unlock.
        awardProgress();
        // Submit the run score to the global leaderboard (fire-and-forget),
        // segmented by the chosen step-rate variant.
        Leaderboard.submitScore(SLB_GAME_ID, _score, _lbVariant());
        Leaderboard.showPostGame(SLB_GAME_ID, _lbVariant(), "SERPENT");
    }

    // ── Meta-progression (shared, shop-ready via Progress module) ─────────────
    // Grants coins + XP scaled by the run's score and snake length, then unlocks
    // cosmetic skins at rank milestones. Coins are the future shop's currency;
    // skin ownership is exactly what a shop purchase would grant, so nothing
    // here blocks monetising skins later. Fully guarded — never throws.
    hidden function awardProgress() {
        try {
            // ~1 coin per 15 points, plus a small length bonus; min 1 for a
            // non-trivial run so every game feels rewarded.
            var coinsGain = _score / 15 + _sLen / 4;
            if (coinsGain <= 0 && _score > 0) { coinsGain = 1; }
            // XP rewards both scoring and survival (length).
            var xpGain = 8 + _score / 30 + _sLen / 2;
            if (coinsGain > 0) { Progress.addCoins(coinsGain); }
            if (xpGain > 0)    { Progress.addXp(xpGain); }
            var lvl = Progress.level();
            var uNeon = Progress.unlockIfReached("skin_neon", lvl, 3);
            var uGold = Progress.unlockIfReached("skin_gold", lvl, 6);
            if (uGold)      { _pgUnlockMsg = "NEW SKIN: GOLD"; }
            else if (uNeon) { _pgUnlockMsg = "NEW SKIN: NEON"; }
        } catch (e) {}
    }

    // Themed serpent rank ladder derived from the shared XP level.
    hidden function serpentRank(lvl) {
        if (lvl >= 25) { return "Legend"; }
        if (lvl >= 15) { return "Viper"; }
        if (lvl >= 10) { return "Cobra"; }
        if (lvl >= 6)  { return "Python"; }
        if (lvl >= 3)  { return "Adder"; }
        return "Hatchling";
    }

    // ── Direction helpers ─────────────────────────────────────────────────────

    function turnLeft() {
        if (_gs != SS_PLAY) { return; }
        // REVERSE event flips controls — left button actually turns right
        if (_reverseOn) { _doTurnRight(); } else { _doTurnLeft(); }
    }

    function turnRight() {
        if (_gs != SS_PLAY) { return; }
        // REVERSE event flips controls — right button actually turns left
        if (_reverseOn) { _doTurnLeft(); } else { _doTurnRight(); }
    }

    hidden function _doTurnLeft() {
        var nd = (_nextDir + 3) % 4;
        if (nd != (_dir + 2) % 4) { _nextDir = nd; }
    }

    hidden function _doTurnRight() {
        var nd = (_nextDir + 1) % 4;
        if (nd != (_dir + 2) % 4) { _nextDir = nd; }
    }

    function doAction() {
        if (_gs == SS_MENU) { menuActivate(); }
        else if (_gs == SS_PLAY) { turnRight(); }
        else if (_gs == SS_OVER) { _gs = SS_MENU; }
    }

    // UP — navigate menu, else turn left.
    function doLeft() {
        if (_gs == SS_MENU) { menuPrev(); return; }
        turnLeft();
    }
    // DOWN — navigate menu, else turn right.
    function doRight() {
        if (_gs == SS_MENU) { menuNext(); return; }
        turnRight();
    }

    function doBack() {
        if (_gs == SS_PLAY) { turnLeft(); return true; }
        return false;
    }

    function isPlaying() { return _gs == SS_PLAY; }
    function isMenu()    { return _gs == SS_MENU; }

    // ── Menu navigation ────────────────────────────────────────────────────────

    function menuPrev() { _menuRow = (_menuRow + SMENU_ROWS - 1) % SMENU_ROWS; }
    function menuNext() { _menuRow = (_menuRow + 1) % SMENU_ROWS; }

    function menuActivate() {
        if (_menuRow == SROW_LB) { openLeaderboard(); }
        else { startGame(); }
    }

    // Leaderboard variant = step rate, so SLOW/NORMAL/FAST rank separately.
    hidden function _lbVariant() {
        return ["slow", "normal", "fast"][_spdSel];
    }

    // Open the shared global leaderboard for serpent.
    function openLeaderboard() {
        var v = new LbScoresView(SLB_GAME_ID, _lbVariant(), "SERPENT");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Geometry for the two-row main menu.  Space-aware: rows shrink to fit
    // between the BEST line and the bottom margin so nothing overlaps on
    // small round watches.  Returns [rowH, rowW, rowX, rowY0, gap].
    function menuRowGeom() {
        var topZone      = (_h * 59) / 100;            // rows live below BEST
        var bottomMargin = (_h * 12) / 100; if (bottomMargin < 13) { bottomMargin = 13; }
        var gap          = (_h * 3) / 100; if (gap < 4) { gap = 4; }
        var avail        = (_h - bottomMargin) - topZone;
        var rowH         = (avail - gap * (SMENU_ROWS - 1)) / SMENU_ROWS;
        if (rowH > 25) { rowH = 25; }
        if (rowH < 16) { rowH = 16; }
        var rowW = (_w * 56) / 100; if (rowW < 99) { rowW = 99; }
        var rowX = (_w - rowW) / 2;
        var used = SMENU_ROWS * rowH + (SMENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // ── Vibration ─────────────────────────────────────────────────────────────

    hidden function doVibe(pat) {
        if (Toybox has :Attention) {
            if (Attention has :vibrate) {
                var dur = (pat == 0) ? 25 : ((pat == 1) ? 60 : 160);
                Attention.vibrate([new Attention.VibeProfile(80, dur)]);
            }
        }
    }

    // ── Rendering ─────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupGrid(); }

        // Never render an in-game menu — the shared menu is the root view.
        if (_gs == SS_MENU)       { startGame(); }
        if (_gs == SS_PLAY)       { drawGame(dc); }
        else if (_gs == SS_DYING) { drawGame(dc); }
        else if (_gs == SS_OVER)  { drawOver(dc); }
    }

    // ── Menu screen ──────────────────────────────────────────────────────────

    hidden function drawMenu(dc) {
        dc.setColor(0x07101C, 0x07101C); dc.clear();
        var cx = _w / 2;

        // Animated snake coil decoration — ~18% smaller and moved up to
        // leave room for the two interactive rows below.
        var t = _wobble;
        var cy = _h * 25 / 100;
        for (var i = 7; i >= 0; i--) {
            var ang = t - i.toFloat() * 0.75;
            var r = 24.0 - i.toFloat() * 2.3;
            var sx = cx + (Math.cos(ang) * r).toNumber();
            var sy = cy + (Math.sin(ang) * r * 0.65).toNumber();
            var colIdx = i * _snakePalette.size() / 8;
            if (colIdx >= _snakePalette.size()) { colIdx = _snakePalette.size() - 1; }
            dc.setColor(_snakePalette[colIdx], Graphics.COLOR_TRANSPARENT);
            var sz = (i == 7) ? 6 : (4 - i / 3);
            if (sz < 2) { sz = 2; }
            dc.fillCircle(sx, sy, sz);
        }
        // Eyes on animated head
        var headAng = t;
        var hr = 24.0;
        var hsx = cx + (Math.cos(headAng) * hr).toNumber();
        var hsy = cy + (Math.sin(headAng) * hr * 0.65).toNumber();
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hsx + 2, hsy - 1, 2);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hsx + 2, hsy - 1, 1);

        // Title (~18% smaller: FONT_SMALL instead of FONT_MEDIUM)
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 37 / 100, Graphics.FONT_SMALL, "SERPENT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x226644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 47 / 100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        if (_best > 0) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 54 / 100, Graphics.FONT_XTINY, "BEST: " + _best, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Two interactive rows: PLAY + LEADERBOARD.
        var rg   = menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < SMENU_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _menuRow);

            if (i == SROW_LB) {
                // Gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            // PLAY row — green-accented to match the snake theme.
            var bg; var bd; var fg;
            if (sel) { bg = 0x1A4400; bd = 0x44BB22; fg = 0xAAFF66; }
            else     { bg = 0x102010; bd = 0x224422; fg = 0x88AA88; }
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(bd, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        "PLAY", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Game screen ──────────────────────────────────────────────────────────

    hidden function drawGame(dc) {
        dc.setColor(0x060F1A, 0x060F1A); dc.clear();

        // Screen shake on death — jitter the whole board a few pixels, decaying
        // as the sequence ends. Applied by nudging the grid offsets and restored
        // right after so nothing leaks into the next frame.
        var ox0 = _offX; var oy0 = _offY;
        if (_gs == SS_DYING && _deathT > 0) {
            var mag = _deathT; if (mag > 5) { mag = 5; }
            _offX += (Math.rand() % (mag * 2 + 1)) - mag;
            _offY += (Math.rand() % (mag * 2 + 1)) - mag;
        }

        drawGrid(dc);
        drawFood(dc);
        drawGoldenApple(dc);
        drawPowerups(dc);
        drawPortals(dc);
        drawSnake(dc);
        drawEatFx(dc);
        drawParticles(dc);

        // Chaos overlay for REVERSE event
        if (_reverseOn && _tick % 8 < 4) {
            dc.setColor(0x330000, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(_offX, _offY, _gridW * _cellSize, _gridH * _cellSize);
        }

        _offX = ox0; _offY = oy0;

        drawHUD(dc);
        if (_toastT > 0 && _toastMsg != null) { drawToast(dc); }

        // Death flash — a bright red vignette frame that pulses during the
        // brief dying window, selling the crash before the game-over card.
        if (_gs == SS_DYING) {
            var on = (_deathT % 2 == 0);
            dc.setColor(on ? 0xFF3322 : 0x882211, Graphics.COLOR_TRANSPARENT);
            for (var b = 0; b < 4; b++) {
                dc.drawRectangle(b, b, _w - b * 2, _h - b * 2);
            }
        }
    }

    // Golden apple: a pulsing gold gem with a shrinking lifetime ring so the
    // player can read how long they have to grab it.
    hidden function drawGoldenApple(dc) {
        if (_gaLife <= 0) { return; }
        var cx = _offX + _gaX * _cellSize + _cellSize / 2;
        var cy = _offY + _gaY * _cellSize + _cellSize / 2;
        var pulse = (_tick % 8 < 4) ? 1 : 0;
        var r = _cellSize / 2 + pulse;
        // Lifetime ring (fades/blinks faster as it's about to expire).
        var soon = (_gaLife < 20) && (_tick % 4 < 2);
        dc.setColor(soon ? 0xFF6600 : 0xFFF0A0, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r + 2);
        // Body
        dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(0xFFF6C0, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 1, cy - 1, 1 + pulse);
    }

    // Eat pop: a quick expanding, fading ring at the last eaten cell.
    hidden function drawEatFx(dc) {
        if (_eatFxLife <= 0) { return; }
        var age = 5 - _eatFxLife;             // 0 (new) .. 4 (old)
        var r = _cellSize / 2 + age * 2;
        var shade = 0xFF - age * 40;
        if (shade < 0) { shade = 0; }
        var clr = (shade << 16) | (shade << 8) | shade;
        dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_eatFxX, _eatFxY, r);
    }

    // One-shot non-blocking toast (e.g. daily bonus) near the top of the board.
    hidden function drawToast(dc) {
        var ty = _offY + 6;
        var tw = _w * 84 / 100;
        var tx = (_w - tw) / 2;
        dc.setColor(0x0A2418, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(tx, ty, tw, 18, 5);
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(tx, ty, tw, 18, 5);
        dc.drawText(_w / 2, ty + 1, Graphics.FONT_XTINY, _toastMsg,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGrid(dc) {
        var gw = _gridW * _cellSize;
        var gh = _gridH * _cellSize;
        // Play-area panel — a touch lighter than the page so the board reads
        // as a distinct, slightly recessed surface (subtle depth).
        dc.setColor(0x081524, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_offX, _offY, gw, gh);
        // Very faint grid lines
        dc.setColor(0x0D2135, Graphics.COLOR_TRANSPARENT);
        for (var gx = 0; gx <= _gridW; gx++) {
            var lx = _offX + gx * _cellSize;
            dc.drawLine(lx, _offY, lx, _offY + gh);
        }
        for (var gy = 0; gy <= _gridH; gy++) {
            var ly = _offY + gy * _cellSize;
            dc.drawLine(_offX, ly, _offX + gw, ly);
        }
        // Framed border (color changes with active effect) — an outer dark
        // shadow line plus the themed inner frame for a crisp, finished edge.
        var bdrC = _ghostOn  ? 0x9944FF :
                   _shieldOn ? 0x44CCFF :
                   _speedOn  ? 0xFF8800 : 0x1A3355;
        dc.setColor(0x030810, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_offX - 2, _offY - 2, gw + 4, gh + 4);
        dc.setColor(bdrC, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_offX - 1, _offY - 1, gw + 2, gh + 2);
    }

    hidden function drawFood(dc) {
        for (var i = 0; i < _fCount; i++) {
            var fx = _offX + _fX[i] * _cellSize + _cellSize / 2;
            var fy = _offY + _fY[i] * _cellSize + _cellSize / 2;
            var isGold = (_multiLeft > 0);
            var fc = isGold ? 0xFFCC00 : 0xFF3355;
            var r = _cellSize / 2 - 1 + _puFlash;
            dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fx, fy, r);
            // Highlight dot
            dc.setColor(isGold ? 0xFFFF88 : 0xFFCCDD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(fx - 1, fy - 1, 1);
        }
    }

    hidden function drawPowerups(dc) {
        for (var i = 0; i < _puCount; i++) {
            var px = _offX + _puX[i] * _cellSize;
            var py = _offY + _puY[i] * _cellSize;
            var pc = puColor(_puType[i]);
            // Animated outer glow
            dc.setColor(pc, Graphics.COLOR_TRANSPARENT);
            var sz = _cellSize - 2 + _puFlash;
            dc.fillRoundedRectangle(px + 1, py + 1, sz, sz, 2);
            // Dark icon area
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + _cellSize / 2, py + _cellSize / 2, _cellSize / 4);
            // Tiny bright center dot to hint type
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px + _cellSize / 2, py + _cellSize / 2, 1);
        }
    }

    hidden function drawPortals(dc) {
        if (_evType != SEV_PORTAL) { return; }
        var pCol = (_tick % 8 < 4) ? 0xFF44CC : 0x882266;
        dc.setColor(pCol, Graphics.COLOR_TRANSPARENT);
        var r = _cellSize / 2;
        dc.fillCircle(_offX + _portalAx * _cellSize + r, _offY + _portalAy * _cellSize + r, r);
        dc.fillCircle(_offX + _portalBx * _cellSize + r, _offY + _portalBy * _cellSize + r, r);
        // Portal label
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _offX + _portalAx * _cellSize + r, _offY + _portalAy * _cellSize + r - 5,
            Graphics.FONT_XTINY, "P", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(
            _offX + _portalBx * _cellSize + r, _offY + _portalBy * _cellSize + r - 5,
            Graphics.FONT_XTINY, "P", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawSnake(dc) {
        var r = _cellSize / 2; if (r < 2) { r = 2; }
        var ncol = _snakePalette.size();

        // Body drawn tail → neck as a continuous rounded tube: a disc at each
        // segment centre plus a connector rectangle to its predecessor fills
        // the seams (including around turns) for a smooth snake instead of a
        // chain of blocky squares. Head is drawn last so it sits on top.
        for (var i = _sLen - 1; i >= 1; i--) {
            var cx = _offX + _sX[i] * _cellSize + r;
            var cy = _offY + _sY[i] * _cellSize + r;
            var px = _offX + _sX[i - 1] * _cellSize + r;
            var py = _offY + _sY[i - 1] * _cellSize + r;

            var pctIdx = (i * (ncol - 1) / _sLen).toNumber();
            if (pctIdx >= ncol) { pctIdx = ncol - 1; }
            dc.setColor(_snakePalette[pctIdx], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r);
            // Connector toward the previous segment (adjacent cell).
            if (cy == py) {
                var lx = (cx < px) ? cx : px;
                dc.fillRectangle(lx, cy - r, (cx - px).abs(), r * 2);
            } else if (cx == px) {
                var ly = (cy < py) ? cy : py;
                dc.fillRectangle(cx - r, ly, r * 2, (cy - py).abs());
            }
        }

        // Head — bright, overridden by any active effect; base tint follows the
        // selected skin. Slightly larger disc + a gloss highlight + eyes.
        var hx = _offX + _sX[0] * _cellSize;
        var hy = _offY + _sY[0] * _cellSize;
        var hcol = _ghostOn  ? 0xBB88FF :
                   _speedOn  ? 0xFFEE22 :
                   _shieldOn ? 0x44FFFF : _headColor;
        dc.setColor(hcol, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hx + r, hy + r, r + 1);
        // Gloss
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hx + r - 1, hy + r - 1, 1);
        drawEyes(dc, hx, hy);
    }

    hidden function drawEyes(dc, sx, sy) {
        var ex = 0; var ey1 = 0; var ey2 = 0;
        var cs = _cellSize;
        if (_dir == 0) {       // right
            ex = sx + cs * 3 / 4; ey1 = sy + cs / 5; ey2 = sy + cs * 4 / 5 - 1;
        } else if (_dir == 1) { // down
            ex = sx + cs / 4;    ey1 = sy + cs * 3 / 4; ey2 = sy + cs * 3 / 4;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx + cs / 4, sy + cs * 3 / 4, 1);
            dc.fillCircle(sx + cs * 3 / 4, sy + cs * 3 / 4, 1);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx + cs / 4 + 1, sy + cs * 3 / 4, 1);
            dc.fillCircle(sx + cs * 3 / 4 + 1, sy + cs * 3 / 4, 1);
            return;
        } else if (_dir == 2) { // left
            ex = sx + cs / 4;  ey1 = sy + cs / 5; ey2 = sy + cs * 4 / 5 - 1;
        } else {               // up
            ex = sx + cs / 4;  ey1 = sy + cs / 4; ey2 = sy + cs / 4;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx + cs / 4, sy + cs / 4, 1);
            dc.fillCircle(sx + cs * 3 / 4, sy + cs / 4, 1);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx + cs / 4 + 1, sy + cs / 4, 1);
            dc.fillCircle(sx + cs * 3 / 4 + 1, sy + cs / 4, 1);
            return;
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex, ey1, 1);
        dc.fillCircle(ex, ey2, 1);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(ex + 1, ey1, 1);
        dc.fillCircle(ex + 1, ey2, 1);
    }

    hidden function drawParticles(dc) {
        for (var i = 0; i < SPART_N; i++) {
            if (_prtLife[i] > 0) {
                dc.setColor(_prtColor[i], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_prtX[i].toNumber(), _prtY[i].toNumber(), 2, 2);
            }
        }
    }

    // ── HUD ──────────────────────────────────────────────────────────────────

    hidden function drawHUD(dc) {
        var hudH = 18;
        dc.setColor(0x060F1A, 0x060F1A);
        dc.fillRectangle(0, 0, _w, hudH);
        dc.setColor(0x1A3355, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, hudH - 1, _w, hudH - 1);

        // Score (left)
        dc.setColor(0xAAFFCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 1, Graphics.FONT_XTINY, _score + "", Graphics.TEXT_JUSTIFY_LEFT);

        // Level (center)
        dc.setColor(0x446688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, 1, Graphics.FONT_XTINY, "Lv" + _level, Graphics.TEXT_JUSTIFY_CENTER);

        // Length (right)
        dc.setColor(0x557799, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 4, 1, Graphics.FONT_XTINY, _sLen + "", Graphics.TEXT_JUSTIFY_RIGHT);

        // Active effect bar (slim progress strip below top row)
        if (_effectType != 0 && _effectSteps > 0) {
            var ePct = _effectSteps.toFloat() / 15.0;
            if (ePct > 1.0) { ePct = 1.0; }
            var eW = (_w * ePct.toFloat()).toNumber();
            dc.setColor(puColor(_effectType), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, hudH - 3, eW, 2);
        }

        // Event labels — just below the grid (safe zone on round screens)
        var evY = _offY + _gridH * _cellSize + 3;
        if (_reverseOn) {
            dc.setColor((_tick % 6 < 3) ? 0xFF4444 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, evY, Graphics.FONT_XTINY, "REVERSE!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_magnetOn) {
            dc.setColor((_tick % 6 < 3) ? 0xFFCC00 : 0xAA8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, evY, Graphics.FONT_XTINY, "MAGNET!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_evType == SEV_PORTAL) {
            dc.setColor((_tick % 8 < 4) ? 0xFF44CC : 0x882266, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, evY, Graphics.FONT_XTINY, "PORTAL!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Combo flash
        if (_combo > 1 && _comboTick > 6) {
            dc.setColor((_tick % 4 < 2) ? 0xFFFF44 : 0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w * 3 / 4, _offY + 2, Graphics.FONT_XTINY, "x" + _combo + "!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Game-over screen ─────────────────────────────────────────────────────

    hidden function drawOver(dc) {
        dc.setColor(0x060F1A, 0x060F1A); dc.clear();

        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 10 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 28 / 100, Graphics.FONT_LARGE, _score + "", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 46 / 100, Graphics.FONT_XTINY, "SCORE", Graphics.TEXT_JUSTIFY_CENTER);

        if (_score >= _best && _score > 0) {
            dc.setColor((_tick % 8 < 4) ? 0xFFDD22 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, _h * 54 / 100 - 1, _w, 16);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_XTINY, "★ NEW BEST! ★", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_best > 0) {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_XTINY, "Best: " + _best, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 64 / 100, Graphics.FONT_XTINY,
            "Lv " + _level + "  |  Len " + _sLen, Graphics.TEXT_JUSTIFY_CENTER);

        drawProgressCard(dc);

        dc.setColor((_tick % 12 < 6) ? 0x44AAFF : 0x2277CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 90 / 100, Graphics.FONT_XTINY, "Tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── PROGRESSION SUMMARY (game-over) ───────────────────────────────────────
    // One compact line: rank/level + coin balance, plus the login streak and a
    // one-shot gold "new skin" banner when the last run crossed an unlock. All
    // Progress reads are internally guarded; wrapped again here for total safety.
    hidden function drawProgressCard(dc) {
        try {
            var lvl = Progress.level();
            dc.setColor(0xBFD8C4, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 72 / 100, Graphics.FONT_XTINY,
                "Lv " + lvl + " " + serpentRank(lvl) + " - " + Progress.coins() + "c",
                Graphics.TEXT_JUSTIFY_CENTER);
            var streak = Progress.currentStreak();
            if (streak > 0) {
                dc.setColor(0x6E9A6E, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 79 / 100, Graphics.FONT_XTINY,
                    "Streak " + streak, Graphics.TEXT_JUSTIFY_CENTER);
            }
        } catch (e) {}
        if (_pgUnlockMsg != null) {
            dc.setColor((_tick % 8 < 4) ? 0xFFD24A : 0xB8860B, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 85 / 100, Graphics.FONT_XTINY, _pgUnlockMsg,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Color helpers ────────────────────────────────────────────────────────

    hidden function puColor(t) {
        if (t == SPU_SPEED)  { return 0xFF4422; }  // red-orange
        if (t == SPU_SHRINK) { return 0x2288FF; }  // blue
        if (t == SPU_GHOST)  { return 0x9944FF; }  // purple
        if (t == SPU_SHIELD) { return 0x44CCFF; }  // cyan
        if (t == SPU_MULTI)  { return 0xFFCC00; }  // gold
        return 0xFFFFFF;
    }
}
