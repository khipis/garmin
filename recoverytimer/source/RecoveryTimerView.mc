// RecoveryTimerView.mc
// ─────────────────────────────────────────────────────────────────────────────
// Cold Exposure / Recovery Timer — full state machine + UI
// ─────────────────────────────────────────────────────────────────────────────

using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;
using Toybox.Application;
using Toybox.Attention;

// ── States ───────────────────────────────────────────────────────────────────
enum { RT_MENU, RT_INT_CFG, RT_RUNNING, RT_PAUSED, RT_REST, RT_DONE }

// ── Presets ───────────────────────────────────────────────────────────────────
const RT_PRESETS      = [120, 180, 300, 600];
const RT_PRESET_LBL   = ["2 min", "3 min", "5 min", "10 min"];

const RT_WORK_VALS    = [60, 120, 180, 300];
const RT_WORK_LBL     = ["1 min", "2 min", "3 min", "5 min"];

const RT_REST_VALS    = [30, 60, 90, 120];
const RT_REST_LBL     = ["30 sec", "1 min", "90 sec", "2 min"];

const RT_CYCLE_VALS   = [2, 3, 4, 5, 8];

const C_BG         = 0x000000;
const C_COLD_LBL   = 0xFFFFFF;
const C_REST_LBL   = 0x888888;
const C_DONE       = 0xFFFFFF;
const C_DIM        = 0x333333;
const C_HINT       = 0x222222;
const C_SEL_BG     = 0x111111;
const C_SEL        = 0xFFFFFF;
const C_UNSEL      = 0x555555;
const C_DIV        = 0x111111;

// ─────────────────────────────────────────────────────────────────────────────

class RecoveryTimerView extends WatchUi.View {

    var _state;

    hidden var _w;
    hidden var _h;
    hidden var _tick;
    hidden var _timer;

    // ── Menu
    hidden var _menuSel;   // 0-3 = presets, 4 = interval
    hidden var _menuLabels;

    // ── Interval config
    hidden var _intWorkIdx;
    hidden var _intRestIdx;
    hidden var _intCycleIdx;
    hidden var _intField;    // 0=cold, 1=rest, 2=cycles (SELECT advances)

    // ── Active session
    hidden var _remaining;
    hidden var _total;
    hidden var _isInterval;
    hidden var _cycle;
    hidden var _totalCycles;
    hidden var _workSec;
    hidden var _restSec;
    hidden var _elapsed;
    hidden var _warned10;
    hidden var _prePause;  // state to restore on resume

    // ── Init ─────────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        var ds   = System.getDeviceSettings();
        _w       = ds.screenWidth;
        _h       = ds.screenHeight;
        _tick    = 0;
        _menuLabels = ["2 min", "3 min", "5 min", "10 min", "Interval \u25B6"];
        _menuSel = 0;

        _intWorkIdx  = 1;  // 2 min
        _intRestIdx  = 1;  // 1 min
        _intCycleIdx = 1;  // 3 cycles
        _intField    = 0;

        _state     = RT_MENU;
        _remaining = 0;
        _total     = 0;
        _elapsed   = 0;
        _warned10  = false;
        _prePause  = RT_RUNNING;
        _isInterval = false;
        _cycle = 0; _totalCycles = 0;
        _workSec = 0; _restSec = 0;
    }

    // ── Timer ─────────────────────────────────────────────────────────────────

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _tick++;
        if (_state == RT_RUNNING || _state == RT_REST) {
            _elapsed++;
            if (_remaining > 0) {
                _remaining--;
                if (_remaining == 10 && !_warned10) {
                    _warned10 = true;
                    _vibeWarn10();
                }
                if (_remaining == 0) {
                    _phaseEnd();
                    return;
                }
            }
        }
        WatchUi.requestUpdate();
    }

    // ── Phase transitions ─────────────────────────────────────────────────────

    hidden function _phaseEnd() {
        if (_state == RT_RUNNING && _isInterval) {
            _vibePhaseChange();
            _state      = RT_REST;
            _remaining  = _restSec;
            _total      = _restSec;
            _warned10   = false;
        } else if (_state == RT_REST) {
            _cycle++;
            if (_cycle >= _totalCycles) {
                _vibeDone();
                _state = RT_DONE;
            } else {
                _vibePhaseChange();
                _state     = RT_RUNNING;
                _remaining = _workSec;
                _total     = _workSec;
                _warned10  = false;
            }
        } else {
            _vibeDone();
            _state = RT_DONE;
        }
        WatchUi.requestUpdate();
    }

    // ── Session start helpers ─────────────────────────────────────────────────

    hidden function _startSingle(secs) {
        _isInterval = false;
        _remaining  = secs;
        _total      = secs;
        _elapsed    = 0;
        _warned10   = false;
        _state      = RT_RUNNING;
        _vibeStart();
    }

    hidden function _startInterval() {
        _isInterval  = true;
        _workSec     = RT_WORK_VALS[_intWorkIdx];
        _restSec     = RT_REST_VALS[_intRestIdx];
        _totalCycles = RT_CYCLE_VALS[_intCycleIdx];
        _cycle       = 0;
        _remaining   = _workSec;
        _total       = _workSec;
        _elapsed     = 0;
        _warned10    = false;
        _state       = RT_RUNNING;
        _vibeStart();
    }

    // ── Haptic patterns ───────────────────────────────────────────────────────

    // Single strong pulse — session start confirmation
    hidden function _vibeStart() {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, 400)]);
        }
    }

    // 2 quick pulses — last 10 seconds warning
    hidden function _vibeWarn10() {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(90, 150),
                new Attention.VibeProfile(0,  80),
                new Attention.VibeProfile(90, 150)
            ]);
        }
    }

    // Double medium pulses — phase change (cold→rest, rest→cold)
    hidden function _vibePhaseChange() {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 250),
                new Attention.VibeProfile(0,  120),
                new Attention.VibeProfile(100, 250)
            ]);
        }
    }

    // Long + short + long — session complete
    hidden function _vibeDone() {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 500),
                new Attention.VibeProfile(0,  150),
                new Attention.VibeProfile(100, 200),
                new Attention.VibeProfile(0,  100),
                new Attention.VibeProfile(100, 500)
            ]);
        }
    }

    // ── Navigation (called by RecoveryTimerDelegate) ──────────────────────────

    function doSelect() {
        if (_state == RT_MENU) {
            if (_menuSel == 4) {
                _state    = RT_INT_CFG;
                _intField = 0;
            } else {
                _startSingle(RT_PRESETS[_menuSel]);
            }
        } else if (_state == RT_INT_CFG) {
            if (_intField < 2) {
                _intField++;
            } else {
                _startInterval();
            }
        } else if (_state == RT_RUNNING || _state == RT_REST) {
            _prePause = _state;
            _state    = RT_PAUSED;
        } else if (_state == RT_PAUSED) {
            _state = _prePause;
        } else if (_state == RT_DONE) {
            _state = RT_MENU;
        }
    }

    function doBack() {
        if (_state == RT_MENU)  { return false; }
        if (_state == RT_INT_CFG) {
            if (_intField > 0) { _intField--; }
            else               { _state = RT_MENU; }
            return true;
        }
        _state = RT_MENU;
        return true;
    }

    function doUp() {
        if (_state == RT_MENU) {
            _menuSel = (_menuSel - 1 + 5) % 5;
        } else if (_state == RT_INT_CFG) {
            _cycleIntField(-1);
        }
    }

    function doDown() {
        if (_state == RT_MENU) {
            _menuSel = (_menuSel + 1) % 5;
        } else if (_state == RT_INT_CFG) {
            _cycleIntField(1);
        }
    }

    function doTap(x, y) {
        if (_state == RT_MENU) {
            var sY = _h * 27 / 100;
            var rH = _h * 13 / 100;
            for (var i = 0; i < 5; i++) {
                var ry = sY + i * rH;
                if (y >= ry && y < ry + rH) {
                    _menuSel = i;
                    doSelect();
                    return;
                }
            }
        } else if (_state == RT_INT_CFG) {
            // Tap upper half = dec, lower = inc
            if (y < _h / 2) { _cycleIntField(-1); }
            else             { _cycleIntField(1); }
        } else if (_state == RT_RUNNING || _state == RT_REST) {
            _prePause = _state;
            _state    = RT_PAUSED;
        } else if (_state == RT_PAUSED) {
            _state = _prePause;
        } else if (_state == RT_DONE) {
            _state = RT_MENU;
        }
    }

    hidden function _cycleIntField(dir) {
        if (_intField == 0) {
            _intWorkIdx  = (_intWorkIdx  + dir + RT_WORK_VALS.size())  % RT_WORK_VALS.size();
        } else if (_intField == 1) {
            _intRestIdx  = (_intRestIdx  + dir + RT_REST_VALS.size())  % RT_REST_VALS.size();
        } else {
            _intCycleIdx = (_intCycleIdx + dir + RT_CYCLE_VALS.size()) % RT_CYCLE_VALS.size();
        }
    }

    // ── Render dispatch ───────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        dc.setColor(C_BG, C_BG);
        dc.clear();

        if      (_state == RT_MENU)    { _drawMenu(dc); }
        else if (_state == RT_INT_CFG) { _drawIntCfg(dc); }
        else if (_state == RT_RUNNING) { _drawActive(dc, false); }
        else if (_state == RT_REST)    { _drawActive(dc, true); }
        else if (_state == RT_PAUSED)  { _drawPaused(dc); }
        else if (_state == RT_DONE)    { _drawDone(dc); }
    }

    // ── MENU ──────────────────────────────────────────────────────────────────

    hidden function _drawMenu(dc) {
        dc.setColor(C_COLD_LBL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 4 / 100, Graphics.FONT_SMALL, "COLD TIMER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 14 / 100, Graphics.FONT_XTINY, "select duration", Graphics.TEXT_JUSTIFY_CENTER);

        var labels = _menuLabels;
        var sY     = _h * 25 / 100;
        var rH     = _h * 13 / 100;
        var mg     = _w * 14 / 100;

        for (var i = 0; i < labels.size(); i++) {
            var y   = sY + i * rH;
            var sel = (i == _menuSel);
            if (sel) {
                dc.setColor(C_SEL_BG, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(mg, y, _w - mg * 2, rH - 2, 4);
            }
            var col = sel ? C_SEL : C_UNSEL;
            if (i == 4 && sel) { col = C_REST_LBL; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, y + 1, Graphics.FONT_SMALL,
                        (sel ? "> " : "  ") + labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(C_HINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 93 / 100, Graphics.FONT_XTINY,
                    "Cold exposure – not medical advice", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── INTERVAL CONFIG ───────────────────────────────────────────────────────

    hidden function _drawIntCfg(dc) {
        dc.setColor(C_COLD_LBL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 3 / 100, Graphics.FONT_SMALL, "INTERVAL", Graphics.TEXT_JUSTIFY_CENTER);

        var mg  = _w * 10 / 100;
        var rH  = _h * 14 / 100;
        var sY  = _h * 16 / 100;
        var lbls = ["COLD", "REST", "CYCLES"];
        var vals = [RT_WORK_LBL[_intWorkIdx], RT_REST_LBL[_intRestIdx],
                    RT_CYCLE_VALS[_intCycleIdx] + " rounds"];

        for (var i = 0; i < 3; i++) {
            var y   = sY + i * rH;
            var sel = (i == _intField);
            if (sel) {
                dc.setColor(C_SEL_BG, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(mg, y, _w - mg * 2, rH - 2, 4);
            }
            dc.setColor(sel ? C_COLD_LBL : C_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(mg + 6, y + 1, Graphics.FONT_XTINY, lbls[i], Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(sel ? C_SEL : C_UNSEL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w - mg - 6, y + 1, Graphics.FONT_XTINY,
                        vals[i] + (sel ? " ◀▶" : ""), Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Divider + START prompt
        var divY = sY + 3 * rH + 4;
        dc.setColor(C_DIV, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 12 / 100, divY, _w * 88 / 100, divY);

        // Estimated total
        var totalMin = (RT_WORK_VALS[_intWorkIdx] + RT_REST_VALS[_intRestIdx]) *
                       RT_CYCLE_VALS[_intCycleIdx] / 60;
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, divY + 6, Graphics.FONT_XTINY,
                    "Total ~" + totalMin + " min", Graphics.TEXT_JUSTIFY_CENTER);

        var startCol = (_intField == 2) ? C_DONE : C_UNSEL;
        dc.setColor(startCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 74 / 100, Graphics.FONT_LARGE, "START", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(C_HINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 90 / 100, Graphics.FONT_XTINY,
                    "UP/DN: value  SEL: next  last=START", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── ACTIVE TIMER (cold or rest) ───────────────────────────────────────────

    hidden function _drawActive(dc, isRest) {
        var phaseCol   = isRest ? C_REST_LBL : C_COLD_LBL;
        var phaseLabel = isRest ? "REST" : "COLD";

        // Phase label
        dc.setColor(phaseCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 4 / 100, Graphics.FONT_LARGE, phaseLabel, Graphics.TEXT_JUSTIFY_CENTER);

        // Round indicator (interval mode)
        if (_isInterval) {
            dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
            var roundDisp = isRest ? _cycle : _cycle + 1;
            dc.drawText(_w / 2, _h * 16 / 100, Graphics.FONT_XTINY,
                        "Round " + roundDisp + " / " + _totalCycles, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Huge countdown
        dc.setColor(C_SEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_NUMBER_HOT,
                    _fmtTime(_remaining), Graphics.TEXT_JUSTIFY_CENTER);

        // Last-10 pulse overlay: dim the number if < 10 and tick is odd
        if (_remaining <= 10 && _tick % 2 == 0) {
            dc.setColor(phaseCol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_NUMBER_HOT,
                        _fmtTime(_remaining), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Progress bar
        _drawBar(dc, phaseCol);

        dc.setColor(C_HINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 90 / 100, Graphics.FONT_XTINY,
                    "SEL: pause   BACK: stop", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── PAUSED ────────────────────────────────────────────────────────────────

    hidden function _drawPaused(dc) {
        var isRest   = (_prePause == RT_REST);
        var phaseCol = isRest ? C_REST_LBL : C_COLD_LBL;

        var blinkC = (_tick % 2 == 0) ? C_DIM : 0x556677;
        dc.setColor(blinkC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 5 / 100, Graphics.FONT_LARGE, "PAUSED", Graphics.TEXT_JUSTIFY_CENTER);

        // Dimmed time
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 24 / 100, Graphics.FONT_NUMBER_HOT,
                    _fmtTime(_remaining), Graphics.TEXT_JUSTIFY_CENTER);

        _drawBar(dc, phaseCol);

        dc.setColor(C_HINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 83 / 100, Graphics.FONT_XTINY, "SEL: resume", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 90 / 100, Graphics.FONT_XTINY, "BACK: stop", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── DONE ──────────────────────────────────────────────────────────────────

    hidden function _drawDone(dc) {
        dc.setColor(C_DONE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 25 / 100, Graphics.FONT_LARGE, "DONE!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(C_SEL, Graphics.COLOR_TRANSPARENT);
        if (_isInterval) {
            dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_MEDIUM,
                        _totalCycles + " rounds", Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(_w / 2, _h * 60 / 100, Graphics.FONT_MEDIUM,
                    _fmtTime(_elapsed), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 70 / 100, Graphics.FONT_XTINY, "total time", Graphics.TEXT_JUSTIFY_CENTER);

        var blinkC = (_tick % 2 == 0) ? C_COLD_LBL : C_DIM;
        dc.setColor(blinkC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 85 / 100, Graphics.FONT_SMALL, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    // Progress bar at bottom of screen
    hidden function _drawBar(dc, fillCol) {
        var bY = _h * 78 / 100;
        var bH = _h * 15 / 1000; if (bH < 4) { bH = 4; }
        var mg = _w * 8 / 100;
        var bW = _w - mg * 2;
        // Background track
        dc.setColor(C_DIV, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mg, bY, bW, bH, 2);
        // Fill
        var pct = (_total > 0) ? bW * (_total - _remaining) / _total : bW;
        if (pct > 0) {
            dc.setColor(fillCol, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(mg, bY, pct, bH, 2);
        }
    }

    // Format seconds as mm:ss
    hidden function _fmtTime(secs) {
        var m = secs / 60;
        var s = secs % 60;
        if (s < 10) { return m + ":0" + s; }
        return m + ":" + s;
    }
}
