using Toybox.Math;
using Toybox.Graphics;

// Manages the pool of on-screen obstacles.
// OBS_MAX is defined in GameView.mc.

class ObstacleManager {
    hidden var _ox;
    hidden var _ow;
    hidden var _oh;
    hidden var _oa;        // active flag: 1 / 0
    hidden var _nextSpawn; // ticks until next spawn

    function initialize() {
        _ox = new [OBS_MAX]; _ow = new [OBS_MAX];
        _oh = new [OBS_MAX]; _oa = new [OBS_MAX];
        for (var i = 0; i < OBS_MAX; i++) { _oa[i] = 0; }
        _nextSpawn = 55;
    }

    function reset() {
        for (var i = 0; i < OBS_MAX; i++) { _oa[i] = 0; }
        _nextSpawn = 55;
    }

    function update(spd, screenW, pDw, pDh) {
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            _ox[i] = _ox[i] - spd;
            if (_ox[i] + _ow[i] < 0) { _oa[i] = 0; }
        }
        _nextSpawn = _nextSpawn - 1;
        if (_nextSpawn <= 0) { _spawn(screenW, pDw, pDh, spd); }
    }

    hidden function _spawn(sw, pDw, pDh, spd) {
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] != 0) { continue; }
            var t  = Math.rand() % 3;
            _ow[i] = pDw * (8 + t * 2) / 10;
            _oh[i] = pDh * (55 + t * 20) / 100;
            _ox[i] = sw + 8;
            _oa[i] = 1;
            break;
        }
        var gap = 72 + Math.rand() % 46 - (spd - 5) * 4;
        if (gap < 28) { gap = 28; }
        _nextSpawn = gap;
    }

    // Returns true if the given hit-box overlaps any active obstacle.
    function collides(hx1, hy1, hx2, hy2, groundY) {
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            var ox1 = _ox[i] + 2;
            var ox2 = _ox[i] + _ow[i] - 2;
            var oy1 = groundY - _oh[i];
            if (hx2 > ox1 && hx1 < ox2 && hy2 > oy1) { return true; }
        }
        return false;
    }

    function draw(dc, groundY, pDh) {
        dc.setColor(0xCC4422, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            var ox = _ox[i];
            var ow = _ow[i];
            var oh = _oh[i];
            var oy = groundY - oh;
            // Stem
            dc.fillRoundedRectangle(ox + ow / 4, oy, ow / 2, oh, 2);
            // Spine tip
            dc.fillRoundedRectangle(ox + ow / 4 - 1, oy - 3, ow / 2 + 2, 5, 1);
            // Side arms on medium/large
            if (oh > pDh * 6 / 10) {
                dc.setColor(0xAA3311, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(ox, oy + oh / 3, ow * 3 / 10, oh / 5, 2);
                dc.fillRoundedRectangle(ox + ow * 7 / 10, oy + oh * 4 / 10, ow * 3 / 10, oh / 5, 2);
                dc.setColor(0xCC4422, Graphics.COLOR_TRANSPARENT);
            }
        }
    }
}
