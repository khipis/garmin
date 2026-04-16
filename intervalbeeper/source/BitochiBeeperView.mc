using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;
using Toybox.Application;

enum { IB_MENU, IB_WORK, IB_REST, IB_PAUSED, IB_DONE }

const WORK_PRESETS   = [10, 15, 20, 30, 45, 60, 90, 120, 180];
const REST_PRESETS   = [5, 10, 15, 20, 30, 45, 60, 90, 120];
const CYCLES_PRESETS = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 30];

const IBC_BG     = 0x000000;
const IBC_WORK   = 0xFFFFFF;
const IBC_REST   = 0x888888;
const IBC_DONE   = 0xFFFFFF;
const IBC_DIM    = 0x333333;
const IBC_HINT   = 0x222222;
const IBC_SEL_BG = 0x111111;
const IBC_SEL    = 0xFFFFFF;
const IBC_UNSEL  = 0x555555;
const IBC_DIV    = 0x1A1A1A;

class BitochiBeeperView extends WatchUi.View {

    var gameState;

    hidden var _w; hidden var _h;
    hidden var _timer;
    hidden var _tick;

    // Config
    hidden var _workSec;
    hidden var _restSec;
    hidden var _totalCycles;

    // Runtime
    hidden var _currentCycle;
    hidden var _remaining;
    hidden var _menuSel;       // 0=work, 1=rest, 2=cycles, 3=GO
    hidden var _pausedState;
    hidden var _totalElapsed;
    hidden var _menuLabels;

    function initialize() {
        View.initialize();
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _tick = 0;
        _menuLabels = ["WORK", "REST", "CYCLES"];

        var ws = Application.Storage.getValue("ibWork");
        _workSec = (ws != null) ? ws : 30;
        var rs = Application.Storage.getValue("ibRest");
        _restSec = (rs != null) ? rs : 30;
        var tc = Application.Storage.getValue("ibCycles");
        _totalCycles = (tc != null) ? tc : 10;

        _currentCycle = 1;
        _remaining = _workSec;
        _menuSel = 3;
        _pausedState = IB_WORK;
        _totalElapsed = 0;
        gameState = IB_MENU;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    // ─── Interval engine ───
    function onTick() as Void {
        _tick++;

        if (gameState == IB_WORK) {
            _remaining--;
            _totalElapsed++;

            // Last 5 seconds of WORK → quick pulse every second
            if (_remaining > 0 && _remaining <= 5) {
                vibeCountdown();
            }

            if (_remaining <= 0) {
                // WORK ended → switch to REST
                vibeRestStart();
                _remaining = _restSec;
                gameState = IB_REST;
            }
        } else if (gameState == IB_REST) {
            _remaining--;
            _totalElapsed++;

            if (_remaining <= 0) {
                // REST ended
                if (_currentCycle >= _totalCycles) {
                    // All cycles done
                    gameState = IB_DONE;
                    vibeAllDone();
                } else {
                    // Next cycle
                    _currentCycle++;
                    _remaining = _workSec;
                    gameState = IB_WORK;
                    vibeWorkStart();
                }
            }
        }

        WatchUi.requestUpdate();
    }

    // ─── Haptic patterns ───
    // Designed to be distinguishable blind, at max intensity for movement

    // Workout start: long strong buzz (unmistakable "go" signal)
    hidden function vibeBegin() {
        doVibe([new Toybox.Attention.VibeProfile(100, 800)]);
    }

    // WORK interval start: 1 short strong pulse
    hidden function vibeWorkStart() {
        doVibe([new Toybox.Attention.VibeProfile(100, 300)]);
    }

    // REST interval start: 2 quick pulses (clearly different from single)
    hidden function vibeRestStart() {
        doVibe([
            new Toybox.Attention.VibeProfile(100, 200),
            new Toybox.Attention.VibeProfile(0, 120),
            new Toybox.Attention.VibeProfile(100, 200)
        ]);
    }

    // Last 5s countdown: short tick each second
    hidden function vibeCountdown() {
        doVibe([new Toybox.Attention.VibeProfile(80, 100)]);
    }

    // All done: long-short-long pattern (unmistakable finish signal)
    hidden function vibeAllDone() {
        doVibe([
            new Toybox.Attention.VibeProfile(100, 600),
            new Toybox.Attention.VibeProfile(0, 150),
            new Toybox.Attention.VibeProfile(100, 200),
            new Toybox.Attention.VibeProfile(0, 150),
            new Toybox.Attention.VibeProfile(100, 600)
        ]);
    }

    hidden function doVibe(pattern) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate(pattern);
            }
        }
    }

    // ─── Actions ───
    function doSelect() {
        if (gameState == IB_MENU) {
            if (_menuSel == 3) {
                // GO
                saveSettings();
                _currentCycle = 1;
                _remaining = _workSec;
                _totalElapsed = 0;
                gameState = IB_WORK;
                vibeBegin();
            } else {
                cyclePreset(1);
            }
        } else if (gameState == IB_WORK || gameState == IB_REST) {
            _pausedState = gameState;
            gameState = IB_PAUSED;
        } else if (gameState == IB_PAUSED) {
            gameState = _pausedState;
        } else if (gameState == IB_DONE) {
            gameState = IB_MENU;
        }
    }

    function doBack() {
        if (gameState == IB_MENU) { return false; }
        gameState = IB_MENU;
        _currentCycle = 1;
        _remaining = _workSec;
        _totalElapsed = 0;
        return true;
    }

    function doUp() {
        if (gameState == IB_MENU) { _menuSel = (_menuSel - 1 + 4) % 4; }
    }

    function doDown() {
        if (gameState == IB_MENU) { _menuSel = (_menuSel + 1) % 4; }
    }

    function doTap(x, y) {
        if (gameState == IB_MENU) {
            if (y < _h / 2) {
                if (x < _w / 2) { cyclePreset(-1); } else { cyclePreset(1); }
            } else {
                _menuSel = 3;
                doSelect();
            }
        } else {
            doSelect();
        }
    }

    hidden function cyclePreset(dir) {
        if (_menuSel == 0) {
            _workSec = (dir > 0) ? nextIn(WORK_PRESETS, _workSec) : prevIn(WORK_PRESETS, _workSec);
        } else if (_menuSel == 1) {
            _restSec = (dir > 0) ? nextIn(REST_PRESETS, _restSec) : prevIn(REST_PRESETS, _restSec);
        } else if (_menuSel == 2) {
            _totalCycles = (dir > 0) ? nextIn(CYCLES_PRESETS, _totalCycles) : prevIn(CYCLES_PRESETS, _totalCycles);
        }
    }

    hidden function nextIn(arr, val) {
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i] == val) { return arr[(i + 1) % arr.size()]; }
        }
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i] > val) { return arr[i]; }
        }
        return arr[0];
    }

    hidden function prevIn(arr, val) {
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i] == val) { return arr[(i - 1 + arr.size()) % arr.size()]; }
        }
        for (var i = arr.size() - 1; i >= 0; i--) {
            if (arr[i] < val) { return arr[i]; }
        }
        return arr[arr.size() - 1];
    }

    hidden function saveSettings() {
        Application.Storage.setValue("ibWork", _workSec);
        Application.Storage.setValue("ibRest", _restSec);
        Application.Storage.setValue("ibCycles", _totalCycles);
    }

    hidden function fmtSec(sec) {
        if (sec >= 60) {
            var m = sec / 60;
            var s = sec % 60;
            if (s < 10) { return m + ":0" + s; }
            return m + ":" + s;
        }
        return sec + "s";
    }

    // ─── Rendering ───────────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        dc.setColor(IBC_BG, IBC_BG);
        dc.clear();

        if      (gameState == IB_MENU) { _drawMenu(dc); }
        else if (gameState == IB_DONE) { _drawDone(dc); }
        else                           { _drawActive(dc); }
    }

    hidden function _drawMenu(dc) {
        var fxH = dc.getFontHeight(Graphics.FONT_XTINY);
        var fsH = dc.getFontHeight(Graphics.FONT_SMALL);
        var labels = _menuLabels;
        var values = [fmtSec(_workSec), fmtSec(_restSec), _totalCycles.toString()];
        var mg = _w * 15 / 100;
        var rH = fxH + 6;
        var totalH = rH * 3 + rH + 8 + fxH;
        var sY = (_h - totalH) / 2;

        for (var i = 0; i < 3; i++) {
            var y = sY + i * rH;
            var sel = (i == _menuSel);
            dc.setColor(sel ? IBC_SEL : IBC_UNSEL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(mg, y + 3, Graphics.FONT_XTINY, labels[i], Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(_w - mg, y + 3, Graphics.FONT_XTINY, values[i], Graphics.TEXT_JUSTIFY_RIGHT);
            if (sel) {
                dc.setColor(IBC_DIM, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(mg, y + rH - 1, _w - mg, y + rH - 1);
            }
        }

        var gy = sY + 3 * rH + 8;
        var goSel = (_menuSel == 3);
        dc.setColor(goSel ? IBC_SEL : IBC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mg, gy, _w - mg * 2, fsH + 4, 4);
        dc.setColor(IBC_BG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, gy + 2, Graphics.FONT_SMALL, "GO", Graphics.TEXT_JUSTIFY_CENTER);

        var totalSec = (_workSec + _restSec) * _totalCycles - _restSec;
        dc.setColor(IBC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, gy + fsH + 8, Graphics.FONT_XTINY, fmtSec(totalSec), Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawActive(dc) {
        var isWork      = (gameState == IB_WORK) || (gameState == IB_PAUSED && _pausedState == IB_WORK);
        var isPaused    = (gameState == IB_PAUSED);
        var inCountdown = (isWork && !isPaused && _remaining <= 5 && _remaining > 0);

        var fxH = dc.getFontHeight(Graphics.FONT_XTINY);
        var fnH = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        var safeT = _h * 12 / 100;
        var safeB = _h * 88 / 100;

        var label;
        if (isPaused) { label = "PAUSED"; }
        else if (isWork) { label = "WORK"; }
        else { label = "REST"; }

        var labelC;
        if (isPaused) { labelC = IBC_DIM; }
        else { labelC = IBC_SEL; }
        dc.setColor(labelC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, safeT, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(IBC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, safeT + fxH + 2, Graphics.FONT_XTINY,
            _currentCycle + "/" + _totalCycles, Graphics.TEXT_JUSTIFY_CENTER);

        var timeStr;
        if (_remaining >= 60) {
            var m = _remaining / 60; var s = _remaining % 60;
            if (s < 10) { timeStr = m + ":0" + s; } else { timeStr = m + ":" + s; }
        } else {
            timeStr = _remaining.toString();
        }

        var numC;
        if (inCountdown) { numC = (_tick % 2 == 0) ? IBC_SEL : IBC_DIM; }
        else if (isPaused) { numC = IBC_DIM; }
        else { numC = IBC_SEL; }

        var numY = (_h - fnH) / 2 - fxH / 2;
        dc.setColor(numC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, numY, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        var mg = _w * 12 / 100;
        var barY = numY + fnH + 4;
        var barH = _h * 15 / 1000; if (barH < 3) { barH = 3; }
        var barW = _w - mg * 2;
        var phaseTotal = isWork ? _workSec : _restSec;
        var elapsed = phaseTotal - _remaining;
        dc.setColor(IBC_DIV, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mg, barY, barW, barH, 1);
        if (phaseTotal > 0 && elapsed > 0) {
            var fill = barW * elapsed / phaseTotal;
            if (fill > barW) { fill = barW; }
            dc.setColor(IBC_SEL, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(mg, barY, fill, barH, 1);
        }

        var dotY = barY + barH + _h * 3 / 100;
        var maxDots = _totalCycles;
        var dotR = _w * 8 / 1000; if (dotR < 2) { dotR = 2; }
        var dotGap = _w * 3 / 100; if (dotGap < 7) { dotGap = 7; }
        if (maxDots > 20) { maxDots = 20; dotGap = _w * 2 / 100; if (dotGap < 5) { dotGap = 5; } }
        var dotsW = (maxDots - 1) * dotGap;
        var dotX0 = (_w - dotsW) / 2;
        for (var i = 0; i < maxDots; i++) {
            var dx = dotX0 + i * dotGap;
            if (i < _currentCycle - 1) {
                dc.setColor(IBC_SEL, Graphics.COLOR_TRANSPARENT);
            } else if (i == _currentCycle - 1) {
                dc.setColor(IBC_UNSEL, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(IBC_DIV, Graphics.COLOR_TRANSPARENT);
            }
            dc.fillCircle(dx, dotY, dotR);
        }

        dc.setColor(IBC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, safeB - fxH, Graphics.FONT_XTINY, fmtSec(_totalElapsed), Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawDone(dc) {
        var fxH = dc.getFontHeight(Graphics.FONT_XTINY);
        var fmH = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var totalH = fmH + 4 + fxH + 8 + fmH + 4 + fxH;
        var y0 = (_h - totalH) / 2;

        dc.setColor(IBC_SEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y0, Graphics.FONT_MEDIUM, "DONE", Graphics.TEXT_JUSTIFY_CENTER);
        y0 += fmH + 4;

        dc.setColor(IBC_UNSEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y0, Graphics.FONT_XTINY,
            _totalCycles + "x " + fmtSec(_workSec) + "/" + fmtSec(_restSec), Graphics.TEXT_JUSTIFY_CENTER);
        y0 += fxH + 8;

        dc.setColor(IBC_SEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y0, Graphics.FONT_MEDIUM, fmtSec(_totalElapsed), Graphics.TEXT_JUSTIFY_CENTER);
        y0 += fmH + 4;

        dc.setColor(IBC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y0, Graphics.FONT_XTINY, "total", Graphics.TEXT_JUSTIFY_CENTER);
    }

}
