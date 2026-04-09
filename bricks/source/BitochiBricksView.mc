using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

enum { BS_MENU, BS_PLAY, BS_WIN, BS_OVER }

const PU_MULTI = 1;   // spawn extra ball
const PU_WIDE  = 2;   // wider paddle
const PU_SLOW  = 3;   // slow ball
const PU_LIFE  = 4;   // extra life
const PU_LASER = 5;   // fire laser

const COLS  = 8;
const ROWS  = 6;
const N_BRK = 48;   // ROWS * COLS
const MAX_B = 3;
const MAX_PU = 6;

class BitochiBricksView extends WatchUi.View {

    var accelX;  // set by delegate

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gameState;

    // Paddle
    hidden var _padX;       // float, center X
    hidden var _padWide;    // wide power-up countdown

    // Balls (Float values stored in Object arrays)
    hidden var _bX;  hidden var _bY;
    hidden var _bVx; hidden var _bVy;
    hidden var _bOn;

    // Bricks
    hidden var _bkHp;
    hidden var _bkPu;

    // Falling power-ups
    hidden var _puX; hidden var _puY;
    hidden var _puT; hidden var _puOn;

    // Laser
    hidden var _laserReady;
    hidden var _laserX;
    hidden var _laserY;
    hidden var _laserOn;

    // Status effects
    hidden var _slowTick;

    // Screen shake
    hidden var _shakeTick; hidden var _shakeX; hidden var _shakeY;

    // Game progress
    hidden var _level;
    hidden var _score;
    hidden var _lives;
    hidden var _bestScore;
    hidden var _resultTick;

    // ── Init ─────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        accelX = 0;
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _tick = 0;
        Math.srand(Time.now().value());
        var bs = Application.Storage.getValue("bricksBest");
        _bestScore = (bs != null) ? bs : 0;
        _gameState = BS_MENU;
        // initialise arrays so they are never null
        _bX = new [MAX_B]; _bY = new [MAX_B];
        _bVx = new [MAX_B]; _bVy = new [MAX_B];
        _bOn = new [MAX_B];
        _puX = new [MAX_PU]; _puY = new [MAX_PU];
        _puT = new [MAX_PU]; _puOn = new [MAX_PU];
        _bkHp = new [N_BRK]; _bkPu = new [N_BRK];
        for (var i = 0; i < MAX_B;  i++) { _bX[i]=0.0; _bY[i]=0.0; _bVx[i]=0.0; _bVy[i]=0.0; _bOn[i]=false; }
        for (var i = 0; i < MAX_PU; i++) { _puX[i]=0.0; _puY[i]=0.0; _puT[i]=0; _puOn[i]=false; }
        for (var i = 0; i < N_BRK;  i++) { _bkHp[i]=0; _bkPu[i]=0; }
        _padX=0.0; _padWide=0;
        _laserReady=false; _laserOn=false; _laserX=0; _laserY=0.0;
        _slowTick=0; _shakeTick=0; _shakeX=0; _shakeY=0;
        _level=1; _score=0; _lives=3; _resultTick=0;
    }

    hidden function initLevel() {
        _padX       = _w / 2.0;
        _padWide    = 0;
        _laserReady = false; _laserOn = false;
        _laserX     = _w / 2; _laserY = 0.0;
        _slowTick   = 0;
        _shakeTick  = 0; _shakeX = 0; _shakeY = 0;
        _resultTick = 0;
        for (var i = 0; i < MAX_B;  i++) { _bOn[i]  = false; }
        for (var i = 0; i < MAX_PU; i++) { _puOn[i] = false; }
        spawnBall(-1);
        buildBricks();
    }

    hidden function spawnBall(fromBi) {
        var spd = 3.0 + (_level - 1) * 0.22;
        if (spd > 5.8) { spd = 5.8; }
        for (var bi = 0; bi < MAX_B; bi++) {
            if (_bOn[bi]) { continue; }
            if (fromBi >= 0 && _bOn[fromBi]) {
                _bX[bi]  = _bX[fromBi];
                _bY[bi]  = _bY[fromBi];
                var vx   = _bVx[fromBi];
                if (vx < 0.0) { vx = -vx; }
                _bVx[bi] = -vx * 0.88;
                _bVy[bi] = _bVy[fromBi];
            } else {
                _bX[bi]  = _padX;
                _bY[bi]  = (_h * 70 / 100).toFloat();
                var deg  = (Math.rand().abs() % 60) - 30;
                var ang  = deg.toFloat() * 3.14159265 / 180.0;
                _bVx[bi] = spd * Math.sin(ang);
                _bVy[bi] = -spd * Math.cos(ang);
            }
            _bOn[bi] = true;
            return;
        }
    }

    hidden function buildBricks() {
        for (var i = 0; i < N_BRK; i++) { _bkHp[i] = 0; _bkPu[i] = 0; }
        var rows = 4 + (_level - 1) / 2;
        if (rows > ROWS) { rows = ROWS; }
        for (var r = 0; r < rows; r++) {
            for (var c = 0; c < COLS; c++) {
                var idx = r * COLS + c;
                var hp;
                if (_level <= 2)      { hp = (r >= rows - 1) ? 2 : 1; }
                else if (_level <= 4) { hp = 1 + r * 2 / rows; }
                else if (_level <= 7) { hp = 1 + r * 3 / rows; }
                else                  { hp = 1 + r * 4 / rows; }
                if (hp < 1) { hp = 1; } if (hp > 4) { hp = 4; }
                _bkHp[idx] = hp;
                var chance = 12 + _level * 3; if (chance > 45) { chance = 45; }
                if (Math.rand().abs() % 100 < chance) {
                    _bkPu[idx] = 1 + Math.rand().abs() % 5;
                }
            }
        }
    }

    // ── Timer ────────────────────────────────────────────────────────────

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 33, true);
    }
    function onHide() { if (_timer != null) { _timer.stop(); _timer = null; } }

    function onTick() as Void {
        _tick++;
        if (_shakeTick > 0) {
            _shakeX = (Math.rand().abs() % 5) - 2;
            _shakeY = (Math.rand().abs() % 3) - 1;
            _shakeTick--;
        } else { _shakeX = 0; _shakeY = 0; }
        if (_gameState == BS_PLAY) { update(); }
        else if (_gameState == BS_WIN || _gameState == BS_OVER) { _resultTick++; }
        WatchUi.requestUpdate();
    }

    // ── Game logic ────────────────────────────────────────────────────────

    hidden function update() {
        if (_padWide > 0) { _padWide--; }
        if (_slowTick > 0) { _slowTick--; }

        // Smooth accelerometer paddle
        var padW = (_padWide > 0) ? (_w * 35 / 100) : (_w * 22 / 100);
        var half = padW.toFloat() / 2.0;
        var target = _w.toFloat() / 2.0 + accelX.toFloat() * _w.toFloat() / 1800.0;
        _padX = _padX * 0.74 + target * 0.26;
        if (_padX - half < 3.0) { _padX = half + 3.0; }
        if (_padX + half > _w.toFloat() - 3.0) { _padX = _w.toFloat() - 3.0 - half; }

        // Laser in flight
        if (_laserOn) {
            _laserY -= 9.0;
            if (_laserY < 34.0) {
                _laserOn = false;
            } else {
                if (checkLaserHit()) { _laserOn = false; }
            }
        }

        // Falling power-ups
        var padY = (_h - 16).toFloat();
        for (var i = 0; i < MAX_PU; i++) {
            if (!_puOn[i]) { continue; }
            _puY[i] += 1.7;
            if (_puY[i] >= padY - 7.0 && _puY[i] <= padY + 14.0) {
                var px = _puX[i];
                if (px >= _padX - half - 8.0 && px <= _padX + half + 8.0) {
                    applyPu(_puT[i]); _puOn[i] = false;
                }
            }
            if (_puY[i] > _h.toFloat() + 14.0) { _puOn[i] = false; }
        }

        // Balls
        var slowM = (_slowTick > 0) ? 0.50 : 1.0;
        var anyOn = false;
        for (var bi = 0; bi < MAX_B; bi++) {
            if (!_bOn[bi]) { continue; }
            anyOn = true;
            _bX[bi] += _bVx[bi] * slowM;
            _bY[bi] += _bVy[bi] * slowM;
            var bx = _bX[bi]; var by = _bY[bi];
            var vx = _bVx[bi]; var vy = _bVy[bi];

            // Wall bounces
            if (bx < 5.0) {
                _bX[bi] = 5.0;
                if (vx < 0.0) { _bVx[bi] = -vx; }
            } else if (bx > _w.toFloat() - 5.0) {
                _bX[bi] = _w.toFloat() - 5.0;
                if (vx > 0.0) { _bVx[bi] = -vx; }
            }
            if (by < 30.0) {
                _bY[bi] = 30.0;
                if (vy < 0.0) { _bVy[bi] = -vy; }
            }

            // Paddle bounce
            if (vy > 0.0 && by >= padY - 6.0 && by <= padY + 8.0) {
                if (bx >= _padX - half - 4.0 && bx <= _padX + half + 4.0) {
                    var rel = (bx - _padX) / half;
                    if (rel < -1.0) { rel = -1.0; }
                    if (rel >  1.0) { rel =  1.0; }
                    var spd = Math.sqrt(vx * vx + vy * vy);
                    var angR = rel * 62.0 * 3.14159265 / 180.0;
                    _bVx[bi] = spd * Math.sin(angR);
                    _bVy[bi] = -spd * Math.cos(angR);
                    if (_bVy[bi] > -1.2) { _bVy[bi] = -1.2; }
                    _bY[bi] = padY - 6.0;
                    vibe(12, 18);
                }
            }

            // Brick collision
            brickBounce(bi);

            // Ball lost below screen
            if (_bY[bi] > _h.toFloat() + 8.0) { _bOn[bi] = false; }
        }

        if (!anyOn) {
            _lives--;
            vibe(80, 180);
            if (_lives <= 0) {
                if (_score > _bestScore) {
                    _bestScore = _score;
                    Application.Storage.setValue("bricksBest", _bestScore);
                }
                _gameState = BS_OVER;
            } else {
                spawnBall(-1);
            }
        }

        // Level clear?
        var anyBrick = false;
        for (var i = 0; i < N_BRK; i++) {
            if (_bkHp[i] > 0) { anyBrick = true; break; }
        }
        if (!anyBrick) {
            _level++; _score += 500 + _level * 80;
            vibe(60, 150); _gameState = BS_WIN;
        }
    }

    hidden function brickBounce(bi) {
        var bx = _bX[bi]; var by = _bY[bi];
        var bW = _w / COLS;
        var startY = 38;
        for (var i = 0; i < N_BRK; i++) {
            if (_bkHp[i] <= 0) { continue; }
            var r = i / COLS; var c = i % COLS;
            var x1 = c * bW + 1;
            var y1 = startY + r * 12;
            var x2 = x1 + bW - 2;
            var y2 = y1 + 10;
            // Broad phase
            if (bx < x1.toFloat() - 5.0 || bx > x2.toFloat() + 5.0 ||
                by < y1.toFloat() - 5.0 || by > y2.toFloat() + 5.0) { continue; }
            // Determine dominant penetration axis
            var dL = bx - x1.toFloat(); if (dL < 0.0) { dL = -dL; }
            var dR = bx - x2.toFloat(); if (dR < 0.0) { dR = -dR; }
            var dT = by - y1.toFloat(); if (dT < 0.0) { dT = -dT; }
            var dB = by - y2.toFloat(); if (dB < 0.0) { dB = -dB; }
            var minH = (dL < dR) ? dL : dR;
            var minV = (dT < dB) ? dT : dB;
            if (minH < minV) {
                _bVx[bi] = -_bVx[bi];
            } else {
                _bVy[bi] = -_bVy[bi];
            }
            hitBrick(i);
            return;  // one brick per tick
        }
    }

    hidden function checkLaserHit() {
        var bW = _w / COLS; var startY = 38;
        var lx = _laserX; var ly = _laserY.toNumber();
        for (var i = 0; i < N_BRK; i++) {
            if (_bkHp[i] <= 0) { continue; }
            var r = i / COLS; var c = i % COLS;
            var x1 = c * bW + 1; var y1 = startY + r * 12;
            if (lx >= x1 && lx <= x1 + bW - 2 && ly >= y1 && ly <= y1 + 10) {
                hitBrick(i); return true;
            }
        }
        return false;
    }

    hidden function hitBrick(i) {
        _bkHp[i]--;
        _shakeTick = 2;
        if (_bkHp[i] <= 0) {
            _score += 10 + _level * 4;
            vibe(18, 28);
            if (_bkPu[i] > 0) { dropPowerup(_bkPu[i], i); }
        } else {
            vibe(8, 12);
        }
    }

    hidden function dropPowerup(type, idx) {
        var bW = _w / COLS;
        var r = idx / COLS; var c = idx % COLS;
        for (var i = 0; i < MAX_PU; i++) {
            if (!_puOn[i]) {
                _puX[i] = (c * bW + bW / 2).toFloat();
                _puY[i] = (38 + r * 12 + 10).toFloat();
                _puT[i] = type; _puOn[i] = true;
                return;
            }
        }
    }

    hidden function applyPu(type) {
        vibe(28, 55);
        if (type == PU_MULTI) {
            for (var bi = 0; bi < MAX_B; bi++) {
                if (_bOn[bi]) { spawnBall(bi); break; }
            }
        } else if (type == PU_WIDE) {
            _padWide = 420;
        } else if (type == PU_SLOW) {
            _slowTick = 300;
        } else if (type == PU_LIFE) {
            if (_lives < 5) { _lives++; }
        } else if (type == PU_LASER) {
            _laserReady = true;
        }
    }

    hidden function vibe(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }

    // ── Public ───────────────────────────────────────────────────────────

    function doAction() {
        if (_gameState == BS_MENU) {
            _level = 1; _score = 0; _lives = 3;
            initLevel(); _gameState = BS_PLAY;
        } else if (_gameState == BS_WIN && _resultTick > 18) {
            initLevel(); _gameState = BS_PLAY;
        } else if (_gameState == BS_OVER && _resultTick > 18) {
            _gameState = BS_MENU;
        } else if (_gameState == BS_PLAY && _laserReady && !_laserOn) {
            _laserX = _padX.toNumber();
            _laserY = (_h - 20).toFloat();
            _laserOn = true; _laserReady = false;
            vibe(14, 22);
        }
    }

    // ── Rendering ────────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        dc.setColor(0x080D1A, 0x080D1A); dc.clear();
        if (_gameState == BS_MENU)  { drawMenu(dc);  return; }
        if (_gameState == BS_WIN)   { drawWin(dc);   return; }
        if (_gameState == BS_OVER)  { drawOver(dc);  return; }
        drawGame(dc);
    }

    hidden function drawGame(dc) {
        var ox = _shakeX; var oy = _shakeY;

        // HUD
        dc.setColor(0x0B1326, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, 33);
        dc.setColor(0x1C2D50, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, 33, _w, 33);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(5, 1, Graphics.FONT_SMALL, _score + "", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x445577, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, 4, Graphics.FONT_XTINY, "LVL " + _level, Graphics.TEXT_JUSTIFY_CENTER);
        drawLives(dc);

        // Active power-up tags
        var ix = _w - 5;
        if (_laserReady) {
            dc.setColor((_tick % 6 < 3) ? 0xFF6622 : 0xFF3300, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ix, 17, Graphics.FONT_XTINY, "L", Graphics.TEXT_JUSTIFY_RIGHT); ix -= 12;
        }
        if (_slowTick > 0) {
            dc.setColor(0x33FFAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ix, 17, Graphics.FONT_XTINY, "S", Graphics.TEXT_JUSTIFY_RIGHT); ix -= 12;
        }
        if (_padWide > 0) {
            dc.setColor(0x33CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ix, 17, Graphics.FONT_XTINY, "W", Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Bricks
        var bW = _w / COLS; var startY = 38;
        for (var i = 0; i < N_BRK; i++) {
            var hp = _bkHp[i]; if (hp <= 0) { continue; }
            var r = i / COLS; var c = i % COLS;
            var bx2 = c * bW + ox; var by2 = startY + r * 12 + oy;
            var col;
            if (hp == 1) {
                var rc = r % 6;
                if      (rc == 0) { col = 0x22DDFF; }
                else if (rc == 1) { col = 0x44FF88; }
                else if (rc == 2) { col = 0xFFFF44; }
                else if (rc == 3) { col = 0xFF9944; }
                else if (rc == 4) { col = 0xFF44AA; }
                else              { col = 0xBB44FF; }
            } else if (hp == 2) { col = 0xFF8822; }
            else if (hp == 3)   { col = 0xFF2233; }
            else                { col = 0xBB1166; }

            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx2 + 2, by2 + 2, bW - 2, 10);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx2 + 1, by2, bW - 2, 10);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx2 + 2, by2 + 1, bW - 7, 2);

            // HP pips
            if (hp >= 2) {
                var dotC = (hp >= 4) ? 0xFF88BB : 0xFFBB55;
                dc.setColor(dotC, Graphics.COLOR_TRANSPARENT);
                for (var d = 0; d < hp - 1; d++) {
                    dc.fillRectangle(bx2 + bW - 5 - d * 4, by2 + 6, 3, 3);
                }
            }
            // Power-up gem dot
            if (_bkPu[i] > 0) {
                dc.setColor(puColor(_bkPu[i]), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(bx2 + 4, by2 + 5, 2);
            }
        }

        // Falling power-ups
        for (var i = 0; i < MAX_PU; i++) {
            if (!_puOn[i]) { continue; }
            var px = _puX[i].toNumber() + ox;
            var py = _puY[i].toNumber() + oy;
            dc.setColor(puColor(_puT[i]), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(px - 7, py - 7, 14, 14, 4);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            var ltr;
            if      (_puT[i] == PU_MULTI) { ltr = "M"; }
            else if (_puT[i] == PU_WIDE)  { ltr = "W"; }
            else if (_puT[i] == PU_SLOW)  { ltr = "S"; }
            else if (_puT[i] == PU_LIFE)  { ltr = "+"; }
            else                           { ltr = "L"; }
            dc.drawText(px, py - 8, Graphics.FONT_XTINY, ltr, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Laser beam
        if (_laserOn) {
            var lx = _laserX + ox; var ly = _laserY.toNumber() + oy;
            dc.setColor(0xFF1100, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lx - 2, ly - 14, 4, 16);
            dc.setColor(0xFF7755, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lx - 1, ly - 14, 2, 16);
        }

        // Balls
        for (var bi = 0; bi < MAX_B; bi++) {
            if (!_bOn[bi]) { continue; }
            var bsx = _bX[bi].toNumber() + ox;
            var bsy = _bY[bi].toNumber() + oy;
            dc.setColor(0x112244, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bsx, bsy, 6);
            dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bsx, bsy, 4);
            dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(bsx - 1, bsy - 1, 2);
        }

        // Paddle
        var padW = (_padWide > 0) ? (_w * 35 / 100) : (_w * 22 / 100);
        var half2 = padW / 2;
        var ppx = _padX.toNumber() + ox; var ppy = _h - 16 + oy;
        var padBodyC = (_padWide > 0) ? 0x22AA44 : 0x1E4E8C;
        var padTopC  = (_padWide > 0) ? 0x55FF88 : 0x55AAFF;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ppx - half2, ppy - 1, padW, 9, 4);
        dc.setColor(padBodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ppx - half2, ppy - 2, padW, 8, 4);
        dc.setColor(padTopC, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ppx - half2 + 2, ppy - 1, padW - 4, 3, 2);
    }

    hidden function drawLives(dc) {
        var x = _w - 6;
        for (var i = 0; i < _lives; i++) {
            dc.setColor(0xFF2233, Graphics.COLOR_TRANSPARENT); dc.fillCircle(x - i * 11, 7, 5);
            dc.setColor(0xFF8899, Graphics.COLOR_TRANSPARENT); dc.fillCircle(x - i * 11 - 1, 5, 2);
        }
    }

    hidden function puColor(t) {
        if (t == PU_MULTI) { return 0xEE44FF; }
        if (t == PU_WIDE)  { return 0x33CCFF; }
        if (t == PU_SLOW)  { return 0x33FFAA; }
        if (t == PU_LIFE)  { return 0xFF2233; }
        return 0xFF8822;
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x060C18, 0x060C18); dc.clear();
        var tc = (_tick % 14 < 7) ? 0x44AAFF : 0x2277CC;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, _h * 5 / 100 + 1, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 5 / 100, Graphics.FONT_MEDIUM, "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 18 / 100, Graphics.FONT_LARGE, "BRICKS", Graphics.TEXT_JUSTIFY_CENTER);

        // Animated brick preview
        var bW2 = _w / COLS;
        var cols6 = [0x22DDFF, 0x44FF88, 0xFFFF44, 0xFF9944, 0xFF44AA, 0xBB44FF];
        for (var row = 0; row < 3; row++) {
            for (var col3 = 0; col3 < COLS; col3++) {
                var ci = (_tick / 5 + row * 3 + col3) % 6;
                dc.setColor(cols6[ci], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(col3 * bW2 + 1, _h * 36 / 100 + row * 12, bW2 - 2, 10);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(col3 * bW2 + 2, _h * 36 / 100 + row * 12 + 1, bW2 - 6, 2);
            }
        }
        if (_bestScore > 0) {
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 68 / 100, Graphics.FONT_XTINY, "BEST: " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor((_tick % 12 < 6) ? 0xFFCC44 : 0xCC8822, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 78 / 100, Graphics.FONT_SMALL, "Tap to play!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x1E2D40, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 90 / 100, Graphics.FONT_XTINY, "M+ball W+wide S+slow +life L=laser", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawWin(dc) {
        dc.setColor(0x081420, 0x081420); dc.clear();
        dc.setColor((_resultTick % 6 < 3) ? 0x44FF88 : 0x22CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_LARGE, "CLEARED!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 40 / 100, Graphics.FONT_MEDIUM, "Level " + (_level - 1), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 56 / 100, Graphics.FONT_SMALL, _score + " pts", Graphics.TEXT_JUSTIFY_CENTER);
        if (_resultTick > 22) {
            dc.setColor((_resultTick % 8 < 4) ? 0x44AAFF : 0x3388DD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 78 / 100, Graphics.FONT_XTINY, "Tap for level " + _level, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawOver(dc) {
        dc.setColor(0x10080A, 0x10080A); dc.clear();
        dc.setColor((_resultTick % 6 < 3) ? 0xFF3333 : 0xCC1111, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 18 / 100, Graphics.FONT_LARGE, "GAME", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 36 / 100, Graphics.FONT_LARGE, "OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 56 / 100, Graphics.FONT_SMALL, _score + " pts", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 68 / 100, Graphics.FONT_XTINY, "Best: " + _bestScore, Graphics.TEXT_JUSTIFY_CENTER);
        if (_resultTick > 22) {
            dc.setColor((_resultTick % 8 < 4) ? 0xFF8844 : 0xDD6622, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 83 / 100, Graphics.FONT_XTINY, "Tap to retry", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
