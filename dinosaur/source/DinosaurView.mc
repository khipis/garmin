using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── game states ───────────────────────────────────────────────────────────────
const GS_TITLE = 0;
const GS_RUN   = 1;
const GS_OVER  = 2;

// obstacle types
const OT_CACTUS = 0;
const OT_PTERO  = 1;

const OBS_MAX = 4;
const CLD_MAX = 3;

// ─────────────────────────────────────────────────────────────────────────────
//  Phases
//  0 < 300  : single jump, ground only, slow
//  1 300–1499: double jump unlocked, ground only
//  2 ≥ 1500  : duck unlocked, pterodactyls appear
// ─────────────────────────────────────────────────────────────────────────────

class DinosaurView extends WatchUi.View {

    // ── timer / state ─────────────────────────────────────────────────────────
    hidden var _timer;
    hidden var _state;

    // ── layout ────────────────────────────────────────────────────────────────
    hidden var _sw;
    hidden var _sh;
    hidden var _grdY;    // ground top Y
    hidden var _dinoX;   // fixed dino left edge X
    hidden var _dw;      // dino bounding-box width
    hidden var _dh;      // dino bounding-box full height

    // ── dino physics ──────────────────────────────────────────────────────────
    hidden var _dy;          // dino top Y
    hidden var _vy;          // vertical velocity (+ = down)
    hidden var _onGrd;       // 1 when on ground
    hidden var _frame;       // animation counter
    hidden var _jumpsLeft;   // remaining mid-air jumps
    hidden var _crouching;   // 1 when crouching
    hidden var _crouchT;     // crouch auto-expire countdown

    // ── obstacles ─────────────────────────────────────────────────────────────
    hidden var _ox;     // left-edge X
    hidden var _ow;     // width
    hidden var _oh;     // height
    hidden var _oa;     // active: 1 / 0
    hidden var _ot;     // type: OT_CACTUS / OT_PTERO

    // ── clouds ────────────────────────────────────────────────────────────────
    hidden var _cx;
    hidden var _cy;
    hidden var _cw;

    // ── game counters ─────────────────────────────────────────────────────────
    hidden var _score;
    hidden var _hiScore;
    hidden var _spd;        // px / tick
    hidden var _nextObs;    // ticks until next spawn
    hidden var _phase;      // 0 / 1 / 2
    hidden var _scrollX;    // ground-texture scroll accumulator

    // ── effects / notifications ───────────────────────────────────────────────
    hidden var _flash;       // new-best glow timer
    hidden var _notifyStr;   // phase-unlock message
    hidden var _notifyT;     // notify display countdown
    hidden var _sparkT;      // double-jump sparkle timer
    hidden var _sparkX;
    hidden var _sparkY;

    // ── init ──────────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        _state     = GS_TITLE;
        _hiScore   = 0;
        _timer     = null;
        _flash     = 0;
        _notifyStr = "";
        _notifyT   = 0;
        _sparkT    = 0;
        _sparkX    = 0;
        _sparkY    = 0;

        _ox = new [OBS_MAX]; _ow = new [OBS_MAX];
        _oh = new [OBS_MAX]; _oa = new [OBS_MAX]; _ot = new [OBS_MAX];
        for (var i = 0; i < OBS_MAX; i++) { _oa[i] = 0; _ot[i] = 0; }

        _cx = new [CLD_MAX]; _cy = new [CLD_MAX]; _cw = new [CLD_MAX];
    }

    function onLayout(dc) {
        _sw   = dc.getWidth();
        _sh   = dc.getHeight();
        _grdY = _sh * 70 / 100;

        _dinoX = _sw * 17 / 100;
        _dw    = _sw * 7 / 100;
        if (_dw < 22) { _dw = 22; }
        _dh = _dw + _dw * 6 / 10;   // 1.6× wide → tall & chubby

        _cy[0] = _sh * 17 / 100; _cw[0] = 46;
        _cy[1] = _sh * 25 / 100; _cw[1] = 38;
        _cy[2] = _sh * 11 / 100; _cw[2] = 54;
        _cx[0] = _sw * 40 / 100;
        _cx[1] = _sw * 63 / 100;
        _cx[2] = _sw * 81 / 100;

        _resetGame();
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:gameTick), 33, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── timer callback ────────────────────────────────────────────────────────

    function gameTick() {
        if (_state == GS_RUN) { _step(); }
        if (_flash   > 0) { _flash   = _flash   - 1; }
        if (_notifyT > 0) { _notifyT = _notifyT - 1; }
        if (_sparkT  > 0) { _sparkT  = _sparkT  - 1; }
        WatchUi.requestUpdate();
    }

    // ── public controls ───────────────────────────────────────────────────────

    function doJump() {
        if (_state != GS_RUN) { _resetGame(); _state = GS_RUN; return; }
        // cancel crouch → stand up
        if (_crouching == 1 && _onGrd == 1) { _crouching = 0; _crouchT = 0; return; }
        if (_jumpsLeft > 0) {
            var dbl = (_onGrd == 0);
            _vy        = dbl ? -11 : -17;
            _onGrd     = 0;
            _jumpsLeft = _jumpsLeft - 1;
            if (dbl) {
                _sparkT = 14;
                _sparkX = _dinoX + _dw / 2;
                _sparkY = _dy + _dh / 4;
            }
        }
    }

    function doCrouch() {
        if (_state != GS_RUN) { _resetGame(); _state = GS_RUN; return; }
        if (_onGrd == 1 && _phase >= 2) {
            _crouching = 1;
            _crouchT   = 42;
        } else if (_onGrd == 0) {
            // ground pound — slam down
            if (_vy < 12) { _vy = 12; }
        }
    }

    function doBack() {
        if (_state == GS_RUN) { _state = GS_OVER; return true; }
        return false;
    }

    // ── game logic ────────────────────────────────────────────────────────────

    hidden function _resetGame() {
        _dy        = _grdY - _dh;
        _vy        = 0;
        _onGrd     = 1;
        _frame     = 0;
        _score     = 0;
        _spd       = 5;
        _nextObs   = 55;
        _phase     = 0;
        _jumpsLeft = 1;
        _crouching = 0;
        _crouchT   = 0;
        _scrollX   = 0;
        _notifyStr = "";
        _notifyT   = 0;
        for (var i = 0; i < OBS_MAX; i++) { _oa[i] = 0; }
    }

    hidden function _step() {
        _frame   = _frame + 1;
        _scrollX = _scrollX + _spd;
        if (_scrollX >= 3600) { _scrollX = _scrollX - 3600; }

        // crouch timer
        if (_crouching == 1) {
            _crouchT = _crouchT - 1;
            if (_crouchT <= 0) { _crouching = 0; }
        }

        // gravity
        _vy = _vy + 2;
        _dy = _dy + _vy;

        // ground contact — crouching compresses dino to 55 % height
        var floorDy = (_crouching == 1 && _vy >= 0) ? (_grdY - _dh * 55 / 100) : (_grdY - _dh);
        if (_dy >= floorDy) {
            _dy = floorDy;
            _vy = 0;
            if (_onGrd == 0) {
                // just landed — restore jumps
                _jumpsLeft = (_phase >= 1) ? 2 : 1;
            }
            _onGrd = 1;
        }

        // phase progression
        var nPhase = 0;
        if      (_score >= 1500) { nPhase = 2; }
        else if (_score >= 300)  { nPhase = 1; }
        if (nPhase > _phase) {
            _phase = nPhase;
            if (_phase == 1) { _notifyStr = "x2 JUMP!";  _notifyT = 110; }
            if (_phase == 2) { _notifyStr = "DUCK!  [v]"; _notifyT = 110; }
        }

        // speed: 5 at start → 15 at score 2000, no hard cap above that
        _spd = 5 + _score / 200;
        if (_spd > 16) { _spd = 16; }

        // move obstacles
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            _ox[i] = _ox[i] - _spd;
            if (_ox[i] + _ow[i] < 0) { _oa[i] = 0; }
        }

        // parallax clouds (slower)
        for (var i = 0; i < CLD_MAX; i++) {
            _cx[i] = _cx[i] - (_spd / 2 + 1);
            if (_cx[i] + _cw[i] < 0) { _cx[i] = _sw + 12; }
        }

        // spawn
        _nextObs = _nextObs - 1;
        if (_nextObs <= 0) { _spawnObs(); }

        // collision
        if (_collide()) {
            _state = GS_OVER;
            if (_score > _hiScore) { _hiScore = _score; _flash = 70; }
            return;
        }

        _score = _score + 1;
    }

    hidden function _spawnObs() {
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] != 0) { continue; }
            // phase 2: 35 % pterodactyl
            if (_phase >= 2 && Math.rand() % 100 < 35) {
                _ot[i] = OT_PTERO;
                _ow[i] = _dw * 14 / 10;
                _oh[i] = _dh * 50 / 100;
            } else {
                _ot[i] = OT_CACTUS;
                var t  = Math.rand() % 3;
                _ow[i] = _dw * (8 + t * 2) / 10;
                _oh[i] = _dh * (55 + t * 20) / 100;
            }
            _ox[i] = _sw + 8;
            _oa[i] = 1;
            break;
        }
        // gap shrinks with speed and phase
        var gap = 72 + Math.rand() % 46 - (_spd - 5) * 4;
        if (_phase >= 2) { gap = gap - 8; }
        if (gap < 28) { gap = 28; }
        _nextObs = gap;
    }

    hidden function _collide() {
        var effH  = (_crouching == 1 && _onGrd == 1) ? (_dh * 55 / 100) : _dh;
        var dx1   = _dinoX + 3;
        var dx2   = _dinoX + _dw - 3;
        var dy1   = _dy + effH / 4;
        var dy2   = _dy + effH - 2;
        // how high pterodactyls fly above ground
        var flyOff = _dh * 60 / 100;

        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            var ox1 = _ox[i] + 2;
            var ox2 = _ox[i] + _ow[i] - 2;
            var oy1;
            var oy2;
            if (_ot[i] == OT_PTERO) {
                oy1 = _grdY - _oh[i] - flyOff;
                oy2 = _grdY - flyOff;
            } else {
                oy1 = _grdY - _oh[i];
                oy2 = _grdY;
            }
            if (dx2 > ox1 && dx1 < ox2 && dy2 > oy1 && dy1 < oy2) { return true; }
        }
        return false;
    }

    // ── drawing ───────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        dc.setColor(0x0d0d0d, 0x0d0d0d);
        dc.clear();

        _drawClouds(dc);
        _drawGround(dc);
        _drawObstacles(dc);
        _drawDino(dc);
        _drawSparkle(dc);

        if (_state == GS_TITLE) {
            _drawTitle(dc);
        } else if (_state == GS_OVER) {
            _drawScore(dc);
            _drawOver(dc);
        } else {
            _drawScore(dc);
            _drawNotify(dc);
        }
    }

    hidden function _drawGround(dc) {
        dc.setColor(0x3c3c3c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _grdY, _sw, 2);
        // scrolling ground pebbles
        var off1 = (_scrollX / 10) % 38;
        var px   = -off1;
        var cnt  = 0;
        while (px < _sw && cnt < 16) {
            dc.setColor(0x282828, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px, _grdY + 4, 4, 1);
            dc.fillRectangle(px + 18, _grdY + 6, 2, 1);
            px = px + 38;
            cnt = cnt + 1;
        }
    }

    hidden function _drawClouds(dc) {
        dc.setColor(0x1c1c1c, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < CLD_MAX; i++) {
            var cx = _cx[i];
            var cy = _cy[i];
            var cw = _cw[i];
            dc.fillRoundedRectangle(cx,          cy + 7,  cw,          9, 5);
            dc.fillRoundedRectangle(cx + cw/5,   cy,      cw * 6 / 10, 14, 7);
        }
    }

    // ── dino ──────────────────────────────────────────────────────────────────

    hidden function _drawDino(dc) {
        var x    = _dinoX;
        var dw   = _dw;
        var dead = (_state == GS_OVER);

        // when crouching the dino squishes — bottom stays at ground
        var dh   = (_crouching == 1 && _onGrd == 1) ? (_dh * 55 / 100) : _dh;
        var y    = _dy + (_dh - dh);   // shift top down when squished

        var cBody  = dead ? 0xBB3333 : 0xDDDDDD;
        var cDark  = dead ? 0x882222 : 0x999999;
        var cLight = dead ? 0xDD6666 : 0xEEEEEE;

        // ── tail ──────────────────────────────────────────────────────────────
        dc.setColor(cDark, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - dw*14/100, y + dh*38/100,
                                dw*22/100, dh*13/100, 2);

        // ── body (chubby) ─────────────────────────────────────────────────────
        dc.setColor(cBody, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y + dh*28/100, dw*82/100, dh*62/100, 5);

        // ── belly highlight ───────────────────────────────────────────────────
        dc.setColor(cLight, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + dw*10/100, y + dh*40/100,
                                dw*50/100, dh*38/100, 4);

        // ── head (big round) ──────────────────────────────────────────────────
        dc.setColor(cBody, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + dw*26/100, y, dw*74/100, dh*50/100, 7);

        // ── snout ─────────────────────────────────────────────────────────────
        dc.fillRoundedRectangle(x + dw*82/100, y + dh*26/100,
                                dw*22/100, dh*17/100, 3);

        // ── tiny hilarious arm ────────────────────────────────────────────────
        dc.setColor(cDark, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + dw*56/100, y + dh*50/100,
                                dw*16/100, dh*7/100, 2);
        dc.fillRectangle(x + dw*68/100, y + dh*54/100, 2, 3);
        dc.fillRectangle(x + dw*72/100, y + dh*54/100, 2, 3);

        // ── eye ───────────────────────────────────────────────────────────────
        var eyeX = x + dw*56/100;
        var eyeY = y + dh*14/100;

        if (dead) {
            // X eyes
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(eyeX - 4, eyeY - 4, eyeX + 5, eyeY + 5);
            dc.drawLine(eyeX + 5, eyeY - 4, eyeX - 4, eyeY + 5);
            dc.drawLine(eyeX - 3, eyeY - 4, eyeX + 5, eyeY + 4);
            dc.drawLine(eyeX + 4, eyeY - 4, eyeX - 4, eyeY + 4);
        } else if (_crouching == 1) {
            // squinting determined eyes
            dc.setColor(cLight, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(eyeX - 4, eyeY - 2, 10, 6, 2);
            dc.setColor(0x0d0d0d, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(eyeX - 1, eyeY - 1, 6, 4, 1);
            // angry brow
            dc.setColor(cDark, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(eyeX - 3, eyeY - 5, eyeX + 5, eyeY - 4);
        } else {
            // normal big cute eye — surprised when jumping up
            var eyeR = (_onGrd == 0 && _vy < 0) ? 6 : 5;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(eyeX, eyeY, eyeR);
            var pShift = (_onGrd == 0 && _vy < 0) ? -1 : 1;
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(eyeX + 1, eyeY + pShift, 3);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(eyeX - 1, eyeY + pShift - 2, 1);
        }

        // ── mouth / expression ────────────────────────────────────────────────
        var mX = x + dw*90/100;
        var mY = y + dh*34/100;

        if (dead) {
            // tongue out
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(mX - 1, mY, 5, 5, 2);
            dc.fillRoundedRectangle(mX - 2, mY + 4, 7, 4, 2);
        } else if (_onGrd == 0 && _vy < 0) {
            // jumping: surprised O mouth
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mX + 1, mY + 2, 2);
        } else if (_crouching == 1) {
            // determined flat mouth
            dc.setColor(cDark, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(mX - 2, mY + 2, 6, 2);
        }

        // ── sweat drop when obstacle dangerously close ────────────────────────
        if (_state == GS_RUN && _onGrd == 1) {
            var closest = _sw;
            for (var i = 0; i < OBS_MAX; i++) {
                if (_oa[i] == 0) { continue; }
                var dist = _ox[i] - (_dinoX + _dw);
                if (dist >= 0 && dist < closest) { closest = dist; }
            }
            if (closest < 44) {
                dc.setColor(0x3399DD, Graphics.COLOR_TRANSPARENT);
                var swX = x + dw*18/100;
                var swY = y - 2;
                dc.fillCircle(swX, swY, 3);
                dc.fillRoundedRectangle(swX - 2, swY - 8, 4, 8, 1);
            }
        }

        // ── legs ──────────────────────────────────────────────────────────────
        dc.setColor(cDark, Graphics.COLOR_TRANSPARENT);
        var lg = (_frame / 4) % 2;
        if (_onGrd == 0) {
            // airborne — tucked
            dc.fillRoundedRectangle(x + dw*26/100, y + dh*80/100, dw*18/100, dh*11/100, 2);
            dc.fillRoundedRectangle(x + dw*52/100, y + dh*80/100, dw*18/100, dh*11/100, 2);
        } else if (_crouching == 1) {
            // crouching — wide stubby
            dc.fillRoundedRectangle(x + dw*12/100, y + dh*86/100, dw*24/100, dh*12/100, 2);
            dc.fillRoundedRectangle(x + dw*44/100, y + dh*86/100, dw*24/100, dh*12/100, 2);
        } else if (lg == 0) {
            dc.fillRoundedRectangle(x + dw*26/100, y + dh*78/100, dw*18/100, dh*22/100, 2);
            dc.fillRoundedRectangle(x + dw*52/100, y + dh*83/100, dw*18/100, dh*15/100, 2);
        } else {
            dc.fillRoundedRectangle(x + dw*26/100, y + dh*83/100, dw*18/100, dh*15/100, 2);
            dc.fillRoundedRectangle(x + dw*52/100, y + dh*78/100, dw*18/100, dh*22/100, 2);
        }
    }

    // ── sparkle on double jump ────────────────────────────────────────────────

    hidden function _drawSparkle(dc) {
        if (_sparkT <= 0) { return; }
        dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
        var r = _sparkT / 2 + 2;
        var sx = _sparkX;
        var sy = _sparkY;
        dc.fillCircle(sx - r,     sy,         2);
        dc.fillCircle(sx + r,     sy,         2);
        dc.fillCircle(sx,         sy - r,     2);
        dc.fillCircle(sx - r / 2, sy - r / 2, 2);
        dc.fillCircle(sx + r / 2, sy - r / 2, 2);
    }

    // ── obstacles ─────────────────────────────────────────────────────────────

    hidden function _drawObstacles(dc) {
        var flyOff = _dh * 60 / 100;
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            if (_ot[i] == OT_PTERO) {
                _drawPtero(dc, _ox[i], _ow[i], _oh[i], flyOff);
            } else {
                _drawCactus(dc, _ox[i], _ow[i], _oh[i]);
            }
        }
    }

    hidden function _drawCactus(dc, ox, ow, oh) {
        var oy = _grdY - oh;
        dc.setColor(0x30B348, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ox + ow / 4, oy, ow / 2, oh, 2);
        // tip spine
        dc.fillRoundedRectangle(ox + ow/4 - 1, oy - 3, ow/2 + 2, 5, 1);
        if (oh > _dh * 6 / 10) {
            dc.setColor(0x26883A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(ox, oy + oh/4, ow * 30/100, oh * 18/100, 2);
            dc.fillRoundedRectangle(ox + ow * 7/10, oy + oh*36/100, ow * 30/100, oh * 18/100, 2);
            // arm spine tips
            dc.setColor(0x30B348, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(ox - 1, oy + oh/4 - 2, ow * 30/100 + 2, 4, 1);
            dc.fillRoundedRectangle(ox + ow * 7/10 - 1, oy + oh*36/100 - 2, ow * 30/100 + 2, 4, 1);
        }
    }

    hidden function _drawPtero(dc, ox, ow, oh, flyOff) {
        var cx2 = ox + ow / 2;
        var cy2 = _grdY - flyOff - oh / 2;
        var ws  = ow / 2;
        // wing flap based on frame
        var flap = (_frame / 6) % 2;
        var wingDip = flap == 0 ? (-oh / 3) : (oh / 5);

        dc.setColor(0xAA44BB, Graphics.COLOR_TRANSPARENT);
        // left wing
        var lpts = [[cx2, cy2 + 2], [cx2 - ws, cy2 + wingDip], [cx2 - ws/2, cy2 + oh/2]];
        dc.fillPolygon(lpts);
        // right wing
        var rpts = [[cx2, cy2 + 2], [cx2 + ws, cy2 + wingDip], [cx2 + ws/2, cy2 + oh/2]];
        dc.fillPolygon(rpts);
        // body
        dc.setColor(0xCC55DD, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx2 - oh/4, cy2 - oh/4, oh/2, oh/2, 3);
        // beak
        dc.setColor(0xAA44BB, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx2 + oh/4, cy2 - oh/4, oh*4/10, oh/5, 2);
        // tiny eye
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx2 + oh/6, cy2 - oh/8, 2);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx2 + oh/6 + 1, cy2 - oh/8, 1);
    }

    // ── HUD ───────────────────────────────────────────────────────────────────

    hidden function _drawScore(dc) {
        // On a round watch the usable width at y≈12 % is ~234 px wide (radius 180).
        // Centering at x=73 % keeps the text well inside the bezel.
        var sx = _sw * 73 / 100;
        // score colour shifts grey → red as speed increases
        var spd10 = _spd - 5;
        if (spd10 < 0) { spd10 = 0; }
        var r = 96 + spd10 * 12;
        var g = 96 - spd10 * 5;
        if (r > 220) { r = 220; }
        if (g < 28)  { g = 28; }
        dc.setColor(r * 65536 + g * 256 + 28, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx, _sh * 13 / 100, Graphics.FONT_XTINY,
            _score.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        if (_hiScore > 0) {
            dc.setColor(0x3a3a3a, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx, _sh * 21 / 100, Graphics.FONT_XTINY,
                "HI " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drawNotify(dc) {
        if (_notifyT <= 0) { return; }
        var col = (_notifyT > 30) ? 0x44FF88 : 0x1A6635;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 9 / 100, Graphics.FONT_XTINY,
            _notifyStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawTitle(dc) {
        dc.setColor(0x30B348, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 24 / 100, Graphics.FONT_MEDIUM,
            "DINO RUN", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x4a4a4a, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 43 / 100, Graphics.FONT_XTINY,
            "any key = jump", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_sw / 2, _sh * 51 / 100, Graphics.FONT_XTINY,
            "DOWN = duck (lv3)", Graphics.TEXT_JUSTIFY_CENTER);
        if (_hiScore > 0) {
            dc.setColor(0x363636, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, _sh * 60 / 100, Graphics.FONT_XTINY,
                "best " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drawOver(dc) {
        var cx = _sw / 2;
        var bw = _sw * 40 / 100;
        var bh = _sh * 22 / 100;
        if (bw < 118) { bw = 118; }
        if (bh < 68)  { bh = 68; }
        var bx = cx - bw / 2;
        var by = _sh * 34 / 100;

        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 8);
        dc.setColor(0x2c2c2c, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 8);

        dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 5, Graphics.FONT_XTINY,  "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 21, Graphics.FONT_XTINY, _score.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);

        if (_flash > 0) {
            dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 37, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 37, Graphics.FONT_XTINY,
                "best " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // hint toward next phase
        var hintY = by + 53;
        if (_phase == 0) {
            dc.setColor(0x30B348, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "reach 300 for x2 jump!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_phase == 1) {
            dc.setColor(0x4488CC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "reach 1500 for duck!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
