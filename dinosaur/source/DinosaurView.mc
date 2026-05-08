using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── game states ───────────────────────────────────────────────────────────────
const GS_TITLE = 0;
const GS_RUN   = 1;
const GS_OVER  = 2;

// max simultaneous obstacles
const OBS_MAX  = 3;
// max cloud sprites
const CLD_MAX  = 3;

class DinosaurView extends WatchUi.View {

    // ── timer ─────────────────────────────────────────────────────────────────
    hidden var _timer;
    hidden var _state;

    // ── layout (set in onLayout) ──────────────────────────────────────────────
    hidden var _sw;       // screen width
    hidden var _sh;       // screen height
    hidden var _grdY;     // ground Y (top of ground line)
    hidden var _dinoX;    // fixed dino left edge
    hidden var _dw;       // dino bounding-box width
    hidden var _dh;       // dino bounding-box height

    // ── dino physics ──────────────────────────────────────────────────────────
    hidden var _dy;       // dino top Y
    hidden var _vy;       // vertical velocity (positive = down)
    hidden var _onGrd;    // 1 when on ground, 0 airborne
    hidden var _frame;    // animation tick counter

    // ── obstacles (parallel arrays, OBS_MAX slots) ───────────────────────────
    hidden var _ox;       // x position (left edge)
    hidden var _ow;       // width
    hidden var _oh;       // height
    hidden var _oa;       // active: 1 or 0

    // ── clouds (decorative, CLD_MAX slots) ───────────────────────────────────
    hidden var _cx;       // cloud x
    hidden var _cy;       // cloud y (fixed per slot)
    hidden var _cw;       // cloud width

    // ── game counters ─────────────────────────────────────────────────────────
    hidden var _score;
    hidden var _hiScore;
    hidden var _spd;      // px/tick
    hidden var _nextObs;  // ticks until next spawn

    // ── flash counter (shows "NEW BEST!" briefly) ─────────────────────────────
    hidden var _flash;

    function initialize() {
        View.initialize();
        _state   = GS_TITLE;
        _hiScore = 0;
        _timer   = null;
        _flash   = 0;

        _ox = new [OBS_MAX]; _ow = new [OBS_MAX];
        _oh = new [OBS_MAX]; _oa = new [OBS_MAX];
        for (var i = 0; i < OBS_MAX; i++) { _oa[i] = 0; }

        _cx = new [CLD_MAX]; _cy = new [CLD_MAX]; _cw = new [CLD_MAX];
    }

    function onLayout(dc) {
        _sw   = dc.getWidth();
        _sh   = dc.getHeight();
        _grdY = _sh * 70 / 100;

        _dinoX = _sw * 17 / 100;
        _dw    = _sw * 7 / 100;
        if (_dw < 22) { _dw = 22; }
        _dh = _dw + _dw / 2;   // 1.5× width

        // initial cloud positions
        _cy[0] = _sh * 18 / 100;
        _cy[1] = _sh * 26 / 100;
        _cy[2] = _sh * 12 / 100;
        _cw[0] = 44; _cw[1] = 36; _cw[2] = 50;
        _cx[0] = _sw * 40 / 100;
        _cx[1] = _sw * 62 / 100;
        _cx[2] = _sw * 80 / 100;

        _resetGame();
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:gameTick), 33, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── public timer callback ─────────────────────────────────────────────────

    function gameTick() {
        if (_state == GS_RUN) { _step(); }
        if (_flash > 0) { _flash = _flash - 1; }
        WatchUi.requestUpdate();
    }

    // ── controls ──────────────────────────────────────────────────────────────

    function doAction() {
        if (_state == GS_TITLE || _state == GS_OVER) {
            _resetGame();
            _state = GS_RUN;
            return;
        }
        // jump only from ground
        if (_onGrd == 1) {
            _vy    = -17;
            _onGrd = 0;
        }
    }

    function doBack() {
        if (_state == GS_RUN) { _state = GS_OVER; return true; }
        return false;
    }

    // ── game logic ────────────────────────────────────────────────────────────

    hidden function _resetGame() {
        _dy      = _grdY - _dh;
        _vy      = 0;
        _onGrd   = 1;
        _frame   = 0;
        _score   = 0;
        _spd     = 5;
        _nextObs = 55;
        for (var i = 0; i < OBS_MAX; i++) { _oa[i] = 0; }
    }

    hidden function _step() {
        _frame = _frame + 1;

        // gravity
        _vy = _vy + 2;
        _dy = _dy + _vy;
        if (_dy >= _grdY - _dh) {
            _dy    = _grdY - _dh;
            _vy    = 0;
            _onGrd = 1;
        }

        // speed ramp: 5 → 13 px/tick over ~2000 score
        _spd = 5 + _score / 250;
        if (_spd > 13) { _spd = 13; }

        // move obstacles
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            _ox[i] = _ox[i] - _spd;
            if (_ox[i] + _ow[i] < 0) { _oa[i] = 0; }
        }

        // move clouds at half speed (parallax)
        for (var i = 0; i < CLD_MAX; i++) {
            _cx[i] = _cx[i] - (_spd / 2 + 1);
            if (_cx[i] + _cw[i] < 0) { _cx[i] = _sw + 10; }
        }

        // spawn next obstacle
        _nextObs = _nextObs - 1;
        if (_nextObs <= 0) { _spawnObs(); }

        // collision check
        if (_collide()) {
            _state = GS_OVER;
            if (_score > _hiScore) {
                _hiScore = _score;
                _flash   = 60;
            }
            return;
        }

        _score = _score + 1;
    }

    hidden function _spawnObs() {
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] != 0) { continue; }
            var t  = Math.rand() % 3;          // 0 small · 1 medium · 2 large
            _ow[i] = _dw * (8 + t * 2) / 10;  // 0.8 / 1.0 / 1.2 × dw
            _oh[i] = _dh * (55 + t * 20) / 100; // 55 / 75 / 95 % dh
            _ox[i] = _sw + 8;
            _oa[i] = 1;
            break;
        }
        // gap shrinks as speed grows
        var gap = 68 + Math.rand() % 48 - (_spd - 5) * 4;
        if (gap < 32) { gap = 32; }
        _nextObs = gap;
    }

    hidden function _collide() {
        // dino hit box (inset a few px for forgiveness)
        var dx1 = _dinoX + 3;
        var dx2 = _dinoX + _dw - 3;
        var dy1 = _dy + _dh / 4;    // upper body only (head area)
        var dy2 = _dy + _dh - 2;    // feet

        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            var ox1 = _ox[i] + 2;
            var ox2 = _ox[i] + _ow[i] - 2;
            var oy1 = _grdY - _oh[i];
            // collision when boxes overlap
            if (dx2 > ox1 && dx1 < ox2 && dy2 > oy1) { return true; }
        }
        return false;
    }

    // ── drawing ───────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        dc.setColor(0x0e0e0e, 0x0e0e0e);
        dc.clear();

        _drawClouds(dc);
        _drawGround(dc);
        _drawObstacles(dc);
        _drawDino(dc);

        if (_state == GS_TITLE) {
            _drawTitle(dc);
        } else if (_state == GS_OVER) {
            _drawScore(dc);
            _drawOver(dc);
        } else {
            _drawScore(dc);
        }
    }

    hidden function _drawGround(dc) {
        dc.setColor(0x383838, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _grdY, _sw, 2);
        dc.setColor(0x262626, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _grdY + 4, _sw, 1);
    }

    hidden function _drawClouds(dc) {
        dc.setColor(0x1c1c1c, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < CLD_MAX; i++) {
            var cx = _cx[i];
            var cy = _cy[i];
            var cw = _cw[i];
            dc.fillRoundedRectangle(cx, cy + 6, cw, 8, 4);
            dc.fillRoundedRectangle(cx + cw / 5, cy, cw * 6 / 10, 12, 6);
        }
    }

    hidden function _drawDino(dc) {
        var x  = _dinoX;
        var y  = _dy;
        var dw = _dw;
        var dh = _dh;
        var dead = (_state == GS_OVER);
        var col  = dead ? 0xBB3333 : 0xDDDDDD;
        var col2 = dead ? 0x992222 : 0xAAAAAA;

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);

        // body
        dc.fillRoundedRectangle(x, y + dh * 36 / 100, dw * 76 / 100, dh * 54 / 100, 3);

        // head
        dc.fillRoundedRectangle(x + dw * 36 / 100, y + dh * 4 / 100, dw * 64 / 100, dh * 40 / 100, 3);

        // tail
        dc.fillRoundedRectangle(x - dw * 10 / 100, y + dh * 40 / 100, dw * 16 / 100, dh * 18 / 100, 2);

        // eye
        dc.setColor(0x0e0e0e, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + dw * 85 / 100, y + dh * 11 / 100, 3, 3);

        // legs
        dc.setColor(col2, Graphics.COLOR_TRANSPARENT);
        var lg = (_frame / 4) % 2;
        if (_onGrd == 0) {
            // airborne — both legs tucked back
            dc.fillRectangle(x + dw * 22 / 100, y + dh * 76 / 100, dw * 20 / 100, dh * 14 / 100);
            dc.fillRectangle(x + dw * 50 / 100, y + dh * 76 / 100, dw * 20 / 100, dh * 14 / 100);
        } else if (lg == 0) {
            dc.fillRectangle(x + dw * 22 / 100, y + dh * 74 / 100, dw * 18 / 100, dh * 26 / 100);
            dc.fillRectangle(x + dw * 50 / 100, y + dh * 80 / 100, dw * 18 / 100, dh * 18 / 100);
        } else {
            dc.fillRectangle(x + dw * 22 / 100, y + dh * 80 / 100, dw * 18 / 100, dh * 18 / 100);
            dc.fillRectangle(x + dw * 50 / 100, y + dh * 74 / 100, dw * 18 / 100, dh * 26 / 100);
        }
    }

    hidden function _drawObstacles(dc) {
        dc.setColor(0x2EAA44, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            var ox = _ox[i];
            var ow = _ow[i];
            var oh = _oh[i];
            var oy = _grdY - oh;
            // main stem
            dc.fillRoundedRectangle(ox + ow / 4, oy, ow / 2, oh, 2);
            // arms on medium/large
            if (oh > _dh * 6 / 10) {
                dc.fillRoundedRectangle(ox, oy + oh / 4, ow * 28 / 100, oh * 18 / 100, 2);
                dc.fillRoundedRectangle(ox + ow * 7 / 10, oy + oh * 36 / 100, ow * 28 / 100, oh * 18 / 100, 2);
            }
        }
    }

    hidden function _drawScore(dc) {
        dc.setColor(0x606060, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw * 78 / 100, _sh * 8 / 100, Graphics.FONT_XTINY,
            _score.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        if (_hiScore > 0) {
            dc.setColor(0x404040, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw * 78 / 100, _sh * 16 / 100, Graphics.FONT_XTINY,
                "HI " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drawTitle(dc) {
        // Title
        dc.setColor(0x2EAA44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 25 / 100, Graphics.FONT_MEDIUM,
            "DINO RUN", Graphics.TEXT_JUSTIFY_CENTER);

        // Subtitle
        dc.setColor(0x4a4a4a, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 44 / 100, Graphics.FONT_XTINY,
            "any key to start", Graphics.TEXT_JUSTIFY_CENTER);

        // Hi score
        if (_hiScore > 0) {
            dc.setColor(0x383838, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, _sh * 52 / 100, Graphics.FONT_XTINY,
                "best " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drawOver(dc) {
        var cx = _sw / 2;
        var bw = _sw * 38 / 100;
        var bh = _sh * 18 / 100;
        if (bw < 110) { bw = 110; }
        if (bh < 56)  { bh = 56;  }
        var bx = cx - bw / 2;
        var by = _sh * 36 / 100;

        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 8);
        dc.setColor(0x303030, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 8);

        dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 5, Graphics.FONT_XTINY,
            "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 21, Graphics.FONT_XTINY,
            _score.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);

        if (_flash > 0) {
            dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 37, Graphics.FONT_XTINY,
                "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 37, Graphics.FONT_XTINY,
                "best " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
