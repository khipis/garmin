using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Application;
using Toybox.Attention;

enum { SS_MENU, SS_PLAY, SS_OVER }

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

    // Accel smoothing + auto-turn cooldown
    hidden var _smoothAx;
    hidden var _accelCooldown;

    // Snake body color palette (head→tail gradient, 6 steps)
    hidden var _snakePalette;

    function initialize() {
        View.initialize();
        accelX = 0;
        _w = 0; _h = 0;
        _tick = 0; _gs = SS_MENU;
        _wobble = 0.0; _flashTick = 0;
        _smoothAx = 0.0; _accelCooldown = 0;

        _best = Application.Storage.getValue("serpent_best");
        if (_best == null) { _best = 0; }

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

        // Neon gradient: bright green head → deep teal tail
        _snakePalette = [0x44FF88, 0x33EE77, 0x22CC66, 0x1AAA55, 0x118844, 0x0A6633];
    }

    function onLayout(dc) {}

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 80, true);
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

        _stepBase = 5;  // ticks per step (80ms each = 400ms/step at start — faster)
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

        // Smooth accelerometer (60/40 — responsive but not jittery)
        _smoothAx = _smoothAx * 0.60 + accelX.toFloat() * 0.40;

        if (_gs == SS_PLAY) {
            updateParticles();
            if (_accelCooldown > 0) { _accelCooldown--; }

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
                endGame(); return;
            }
        }

        // Self-collision (skip very last segment — it just vacated this spot)
        for (var i = 1; i < _sLen - 1; i++) {
            if (_sX[i] == hx && _sY[i] == hy) {
                if (_shieldOn) {
                    _shieldOn = false; _effectType = 0; _effectSteps = 0;
                    doVibe(1); break;
                } else {
                    endGame(); return;
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

                spawnParticles(
                    _offX + hx * _cellSize + _cellSize / 2,
                    _offY + hy * _cellSize + _cellSize / 2,
                    0x44FF88);
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

    hidden function endGame() {
        _gs = SS_OVER;
        if (_score > _best) {
            _best = _score;
            Application.Storage.setValue("serpent_best", _best);
        }
        doVibe(2);
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
        if (_gs == SS_MENU) { startGame(); }
        else if (_gs == SS_PLAY) { turnRight(); }
        else if (_gs == SS_OVER) { _gs = SS_MENU; }
    }

    function doLeft()  { turnLeft(); }
    function doRight() { turnRight(); }

    function doBack() {
        if (_gs == SS_PLAY) { turnLeft(); return true; }
        return false;
    }

    function isPlaying() { return _gs == SS_PLAY; }

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

        if (_gs == SS_MENU)     { drawMenu(dc); }
        else if (_gs == SS_PLAY){ drawGame(dc); }
        else                    { drawOver(dc); }
    }

    // ── Menu screen ──────────────────────────────────────────────────────────

    hidden function drawMenu(dc) {
        dc.setColor(0x07101C, 0x07101C); dc.clear();

        // Animated snake coil decoration
        var t = _wobble;
        var cx = _w / 2; var cy = _h * 35 / 100;
        for (var i = 7; i >= 0; i--) {
            var ang = t - i.toFloat() * 0.75;
            var r = 30.0 - i.toFloat() * 2.8;
            var sx = cx + (Math.cos(ang) * r).toNumber();
            var sy = cy + (Math.sin(ang) * r * 0.65).toNumber();
            var colIdx = i * _snakePalette.size() / 8;
            if (colIdx >= _snakePalette.size()) { colIdx = _snakePalette.size() - 1; }
            dc.setColor(_snakePalette[colIdx], Graphics.COLOR_TRANSPARENT);
            var sz = (i == 7) ? 7 : (5 - i / 3);
            if (sz < 2) { sz = 2; }
            dc.fillCircle(sx, sy, sz);
        }
        // Eyes on animated head
        var headAng = t;
        var hr = 30.0;
        var hsx = cx + (Math.cos(headAng) * hr).toNumber();
        var hsy = cy + (Math.sin(headAng) * hr * 0.65).toNumber();
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hsx + 2, hsy - 1, 2);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hsx + 2, hsy - 1, 1);

        // Title
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_MEDIUM, "SERPENT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x226644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 67 / 100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        if (_best > 0) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 76 / 100, Graphics.FONT_XTINY, "BEST: " + _best, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Blink "tap to play"
        dc.setColor((_tick % 12 < 6) ? 0xAAFFCC : 0x44BB77, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 87 / 100, Graphics.FONT_XTINY, "Tap to play!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Game screen ──────────────────────────────────────────────────────────

    hidden function drawGame(dc) {
        dc.setColor(0x060F1A, 0x060F1A); dc.clear();

        drawGrid(dc);
        drawFood(dc);
        drawPowerups(dc);
        drawPortals(dc);
        drawSnake(dc);
        drawParticles(dc);
        drawHUD(dc);

        // Chaos overlay for REVERSE event
        if (_reverseOn && _tick % 8 < 4) {
            dc.setColor(0x330000, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(_offX, _offY, _gridW * _cellSize, _gridH * _cellSize);
        }
    }

    hidden function drawGrid(dc) {
        // Very faint grid lines
        dc.setColor(0x0D1E2E, Graphics.COLOR_TRANSPARENT);
        for (var gx = 0; gx <= _gridW; gx++) {
            var lx = _offX + gx * _cellSize;
            dc.drawLine(lx, _offY, lx, _offY + _gridH * _cellSize);
        }
        for (var gy = 0; gy <= _gridH; gy++) {
            var ly = _offY + gy * _cellSize;
            dc.drawLine(_offX, ly, _offX + _gridW * _cellSize, ly);
        }
        // Border (color changes with active effect)
        var bdrC = _ghostOn  ? 0x9944FF :
                   _shieldOn ? 0x44CCFF :
                   _speedOn  ? 0xFF8800 : 0x1A3355;
        dc.setColor(bdrC, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_offX - 1, _offY - 1, _gridW * _cellSize + 2, _gridH * _cellSize + 2);
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
        for (var i = _sLen - 1; i >= 0; i--) {
            var sx = _offX + _sX[i] * _cellSize;
            var sy = _offY + _sY[i] * _cellSize;

            var col;
            if (i == 0) {
                // Head: bright, changes with active effect
                col = _ghostOn  ? 0xBB88FF :
                      _speedOn  ? 0xFFEE22 :
                      _shieldOn ? 0x44FFFF : 0x44FF88;
            } else {
                // Body: gradient from palette
                var pctIdx = (i * (_snakePalette.size() - 1) / _sLen).toNumber();
                if (pctIdx >= _snakePalette.size()) { pctIdx = _snakePalette.size() - 1; }
                col = _snakePalette[pctIdx];
            }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);

            if (i == 0) {
                // Head: full cell, rounded
                if (_cellSize >= 10) {
                    dc.fillRoundedRectangle(sx, sy, _cellSize, _cellSize, 3);
                } else {
                    dc.fillRectangle(sx, sy, _cellSize, _cellSize);
                }
                // Eyes
                drawEyes(dc, sx, sy);
            } else {
                // Body: slightly inset
                if (_cellSize >= 10) {
                    dc.fillRoundedRectangle(sx + 1, sy + 1, _cellSize - 2, _cellSize - 2, 2);
                } else {
                    dc.fillRectangle(sx + 1, sy + 1, _cellSize - 2, _cellSize - 2);
                }
            }
        }
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
        dc.drawText(_w / 2, _h * 66 / 100, Graphics.FONT_XTINY,
            "Lv " + _level + "  |  Len " + _sLen, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 12 < 6) ? 0x44AAFF : 0x2277CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 87 / 100, Graphics.FONT_XTINY, "Tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
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
