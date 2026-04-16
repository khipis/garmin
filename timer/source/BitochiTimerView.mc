using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;
using Toybox.Application;

enum { TS_MENU, TS_ROUND, TS_LAST10, TS_REST, TS_PAUSED, TS_DONE }

// Preset values for quick cycling via SELECT
const ROUND_PRESETS = [60, 120, 180, 240, 300, 360, 480, 600, 900];
const REST_PRESETS  = [15, 30, 45, 60, 90, 120, 180, 300];
const ROUNDS_PRESETS = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20];

class BitochiTimerView extends WatchUi.View {

    var gameState;

    hidden var _w; hidden var _h;
    hidden var _timer;
    hidden var _tick;

    // Configuration
    hidden var _roundSec;
    hidden var _restSec;
    hidden var _totalRounds;

    // Runtime state
    hidden var _currentRound;
    hidden var _remaining;
    hidden var _menuSel;       // 0=round, 1=rest, 2=rounds, 3=START
    hidden var _pausedState;
    hidden var _totalElapsed;  // total seconds elapsed across all rounds
    hidden var _menuLabels;

    function initialize() {
        View.initialize();
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _tick = 0;
        _menuLabels = ["ROUND", "REST", "ROUNDS"];

        var rs = Application.Storage.getValue("tRound");
        _roundSec = (rs != null) ? rs : 300;
        var re = Application.Storage.getValue("tRest");
        _restSec = (re != null) ? re : 60;
        var tr = Application.Storage.getValue("tRounds");
        _totalRounds = (tr != null) ? tr : 5;

        _currentRound = 1;
        _remaining = _roundSec;
        _menuSel = 3;
        _pausedState = TS_ROUND;
        _totalElapsed = 0;
        gameState = TS_MENU;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _tick++;

        if (gameState == TS_ROUND || gameState == TS_LAST10) {
            _remaining--;
            _totalElapsed++;

            if (_remaining <= 10 && _remaining > 0 && gameState == TS_ROUND) {
                gameState = TS_LAST10;
                vibeWarning();
            } else if (gameState == TS_LAST10 && _remaining > 0 && _remaining < 10) {
                vibeTick();
            }

            if (_remaining <= 0) {
                vibeRoundEnd();
                if (_currentRound >= _totalRounds) {
                    gameState = TS_DONE;
                    vibeDone();
                } else {
                    _remaining = _restSec;
                    gameState = TS_REST;
                    vibeRestStart();
                }
            }
        } else if (gameState == TS_REST) {
            _remaining--;
            _totalElapsed++;

            if (_remaining <= 0) {
                _currentRound++;
                _remaining = _roundSec;
                gameState = TS_ROUND;
                vibeRoundStart();
            }
        }

        WatchUi.requestUpdate();
    }

    // ─── Vibration patterns ───
    // Strong single pulse: round start / rest end
    hidden function vibeRoundStart() {
        doVibe([new Toybox.Attention.VibeProfile(100, 600)]);
    }

    // Long strong pulse: round end
    hidden function vibeRoundEnd() {
        doVibe([new Toybox.Attention.VibeProfile(100, 1000)]);
    }

    // Double pulse: rest start
    hidden function vibeRestStart() {
        doVibe([
            new Toybox.Attention.VibeProfile(100, 250),
            new Toybox.Attention.VibeProfile(0, 150),
            new Toybox.Attention.VibeProfile(100, 250)
        ]);
    }

    // Double quick pulse: 10-second warning
    hidden function vibeWarning() {
        doVibe([
            new Toybox.Attention.VibeProfile(100, 200),
            new Toybox.Attention.VibeProfile(0, 100),
            new Toybox.Attention.VibeProfile(100, 200)
        ]);
    }

    // Short tick: each second in last 10
    hidden function vibeTick() {
        doVibe([new Toybox.Attention.VibeProfile(80, 120)]);
    }

    // Triple pulse: all done
    hidden function vibeDone() {
        doVibe([
            new Toybox.Attention.VibeProfile(100, 500),
            new Toybox.Attention.VibeProfile(0, 200),
            new Toybox.Attention.VibeProfile(100, 500),
            new Toybox.Attention.VibeProfile(0, 200),
            new Toybox.Attention.VibeProfile(100, 500)
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
        if (gameState == TS_MENU) {
            if (_menuSel == 3) {
                saveSettings();
                _currentRound = 1;
                _remaining = _roundSec;
                _totalElapsed = 0;
                gameState = TS_ROUND;
                vibeRoundStart();
            } else {
                cyclePreset();
            }
        } else if (gameState == TS_ROUND || gameState == TS_LAST10) {
            _pausedState = gameState;
            gameState = TS_PAUSED;
        } else if (gameState == TS_REST) {
            _pausedState = TS_REST;
            gameState = TS_PAUSED;
        } else if (gameState == TS_PAUSED) {
            gameState = _pausedState;
        } else if (gameState == TS_DONE) {
            gameState = TS_MENU;
        }
    }

    function doBack() {
        if (gameState == TS_MENU) {
            return false;
        }
        gameState = TS_MENU;
        _currentRound = 1;
        _remaining = _roundSec;
        _totalElapsed = 0;
        return true;
    }

    function doUp() {
        if (gameState == TS_MENU) {
            _menuSel = (_menuSel - 1 + 4) % 4;
        }
    }

    function doDown() {
        if (gameState == TS_MENU) {
            _menuSel = (_menuSel + 1) % 4;
        }
    }

    function doTap(x, y) {
        if (gameState == TS_MENU) {
            // Tap on left half = previous preset, right half = next preset
            var startY = _h * 32 / 100;
            var rowH = _h * 14 / 100;
            for (var i = 0; i < 4; i++) {
                var ry = startY + i * rowH;
                if (y >= ry && y < ry + rowH) {
                    _menuSel = i;
                    if (i == 3) {
                        doSelect();
                    } else if (x < _w / 2) {
                        cyclePresetRev();
                    } else {
                        cyclePreset();
                    }
                    return;
                }
            }
        } else {
            doSelect();
        }
    }

    hidden function cyclePreset() {
        if (_menuSel == 0) {
            _roundSec = nextInArray(ROUND_PRESETS, _roundSec);
        } else if (_menuSel == 1) {
            _restSec = nextInArray(REST_PRESETS, _restSec);
        } else if (_menuSel == 2) {
            _totalRounds = nextInArray(ROUNDS_PRESETS, _totalRounds);
        }
    }

    hidden function cyclePresetRev() {
        if (_menuSel == 0) {
            _roundSec = prevInArray(ROUND_PRESETS, _roundSec);
        } else if (_menuSel == 1) {
            _restSec = prevInArray(REST_PRESETS, _restSec);
        } else if (_menuSel == 2) {
            _totalRounds = prevInArray(ROUNDS_PRESETS, _totalRounds);
        }
    }

    hidden function nextInArray(arr, val) {
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i] == val) {
                return arr[(i + 1) % arr.size()];
            }
        }
        // Value not in presets — find nearest
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i] > val) { return arr[i]; }
        }
        return arr[0];
    }

    hidden function prevInArray(arr, val) {
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i] == val) {
                return arr[(i - 1 + arr.size()) % arr.size()];
            }
        }
        for (var i = arr.size() - 1; i >= 0; i--) {
            if (arr[i] < val) { return arr[i]; }
        }
        return arr[arr.size() - 1];
    }

    hidden function saveSettings() {
        Application.Storage.setValue("tRound", _roundSec);
        Application.Storage.setValue("tRest", _restSec);
        Application.Storage.setValue("tRounds", _totalRounds);
    }

    hidden function fmtTime(sec) {
        var m = sec / 60;
        var s = sec % 60;
        if (s < 10) { return m + ":0" + s; }
        return m + ":" + s;
    }

    // ─── Rendering ───
    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();

        if (gameState == TS_MENU) { drawMenu(dc); }
        else if (gameState == TS_DONE) { drawDone(dc); }
        else { drawTimer(dc); }
    }

    hidden function drawMenu(dc) {
        dc.setColor(0x0A0A0A, 0x0A0A0A); dc.clear();

        // Title block
        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 4 / 100, Graphics.FONT_MEDIUM, "SPARING", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 17 / 100, Graphics.FONT_SMALL, "TIMER", Graphics.TEXT_JUSTIFY_CENTER);

        // Settings rows
        var labels = _menuLabels;
        var values = [fmtTime(_roundSec), fmtTime(_restSec), _totalRounds.toString()];

        var startY = _h * 32 / 100;
        var rowH = _h * 14 / 100;
        var mg = _w * 12 / 100;

        for (var i = 0; i < 3; i++) {
            var y = startY + i * rowH;
            var sel = (i == _menuSel);

            if (sel) {
                dc.setColor(0x1A2A3A, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(mg, y - 2, _w - mg * 2, rowH - 2, 6);
            }

            dc.setColor(sel ? 0xFFFFFF : 0x667788, Graphics.COLOR_TRANSPARENT);
            dc.drawText(mg + 8, y + 2, Graphics.FONT_XTINY, labels[i], Graphics.TEXT_JUSTIFY_LEFT);

            dc.setColor(sel ? 0x44FF88 : 0x99AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w - mg - 8, y + 2, Graphics.FONT_XTINY, values[i], Graphics.TEXT_JUSTIFY_RIGHT);

            if (sel) {
                dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
                dc.drawText(mg + 2, y + 2, Graphics.FONT_XTINY, "<", Graphics.TEXT_JUSTIFY_LEFT);
                dc.drawText(_w - mg - 2, y + 2, Graphics.FONT_XTINY, ">", Graphics.TEXT_JUSTIFY_RIGHT);
            }
        }

        // START button
        var sy = startY + 3 * rowH;
        var btnSel = (_menuSel == 3);
        if (btnSel) {
            var bc = (_tick % 4 < 2) ? 0x00CC00 : 0x00AA00;
            dc.setColor(bc, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(_w * 20 / 100, sy - 2, _w * 60 / 100, rowH, 10);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0x228833, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(_w / 2, sy + 2, Graphics.FONT_SMALL, "START", Graphics.TEXT_JUSTIFY_CENTER);

        // Hint
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 92 / 100, Graphics.FONT_XTINY, "SEL:cycle  UP/DN:nav", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawTimer(dc) {
        // Full-screen background color based on state — instant, bold, no gradients
        var bg; var fg; var label;

        if (gameState == TS_PAUSED) {
            bg = 0x181818;
            fg = 0xAAAAAA;
            label = "PAUSED";
        } else if (gameState == TS_LAST10) {
            // Hard alternating flash: bright yellow ↔ bright green every second
            bg = (_tick % 2 == 0) ? 0xFFDD00 : 0x00DD00;
            fg = 0x000000;
            label = "LAST 10!";
        } else if (gameState == TS_REST) {
            bg = 0xDD0000;
            fg = 0xFFFFFF;
            label = "REST";
        } else {
            bg = 0x00BB00;
            fg = 0x000000;
            label = "FIGHT!";
        }

        dc.setColor(bg, bg); dc.clear();

        // Round info (top)
        var roundStr = "R" + _currentRound + "/" + _totalRounds;
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 6 / 100, Graphics.FONT_SMALL, roundStr, Graphics.TEXT_JUSTIFY_CENTER);

        // State label
        dc.drawText(_w / 2, _h * 18 / 100, Graphics.FONT_MEDIUM, label, Graphics.TEXT_JUSTIFY_CENTER);

        // Large countdown — use biggest number font available
        var timeStr = fmtTime(_remaining);
        dc.drawText(_w / 2, _h * 32 / 100, Graphics.FONT_NUMBER_THAI_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Progress bar at bottom
        var barH = _h * 6 / 100; if (barH < 8) { barH = 8; }
        var barY = _h - barH;
        var totalSec = (gameState == TS_REST || (gameState == TS_PAUSED && _pausedState == TS_REST)) ? _restSec : _roundSec;
        var progress = 0;
        if (totalSec > 0) { progress = _w * _remaining / totalSec; }
        if (progress > _w) { progress = _w; }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, barY, _w, barH);

        var barC;
        if (gameState == TS_REST || (gameState == TS_PAUSED && _pausedState == TS_REST)) {
            barC = 0xFF4444;
        } else if (gameState == TS_LAST10 || (gameState == TS_PAUSED && _pausedState == TS_LAST10)) {
            barC = 0xFFDD00;
        } else if (gameState == TS_PAUSED) {
            barC = 0x555555;
        } else {
            barC = 0x44FF44;
        }
        dc.setColor(barC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, barY, progress, barH);

        // Elapsed total time (bottom area above bar)
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        if (gameState == TS_PAUSED) {
            // Flashing PAUSED indicator
            if (_tick % 3 < 2) {
                dc.drawText(_w / 2, _h * 72 / 100, Graphics.FONT_SMALL, "|| PAUSED ||", Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.drawText(_w / 2, _h * 84 / 100, Graphics.FONT_XTINY, "Sel:resume  Back:reset", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(_w / 2, _h * 78 / 100, Graphics.FONT_XTINY, "Total: " + fmtTime(_totalElapsed), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawDone(dc) {
        dc.setColor(0x080808, 0x080808); dc.clear();

        // Big checkmark area
        dc.setColor(0x00DD00, Graphics.COLOR_TRANSPARENT);
        var okW = _w * 25 / 100;
        var okH = _h * 21 / 100;
        dc.fillRoundedRectangle(_w / 2 - okW / 2, _h * 8 / 100, okW, okH, 12);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 10 / 100, Graphics.FONT_LARGE, "OK", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 30 / 100, Graphics.FONT_LARGE, "DONE!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_SMALL, _totalRounds + " rounds", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 60 / 100, Graphics.FONT_SMALL, fmtTime(_totalElapsed), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 72 / 100, Graphics.FONT_XTINY, "total time", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 4 < 2) ? 0x44FF88 : 0x22CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 86 / 100, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
