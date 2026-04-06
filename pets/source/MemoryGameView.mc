using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;

const MEM_MAX = 16;
const MEM_DIR_UP    = 0;
const MEM_DIR_DOWN  = 1;
const MEM_DIR_LEFT  = 2;
const MEM_DIR_RIGHT = 3;

const MEM_STATE_SHOW    = 0;  // displaying sequence
const MEM_STATE_INPUT   = 1;  // waiting for player
const MEM_STATE_CORRECT = 2;  // round complete flash
const MEM_STATE_WRONG   = 3;  // wrong input flash
const MEM_STATE_DONE    = 4;  // game over

class MemoryGameView extends WatchUi.View {

    hidden var _pet;
    hidden var _timer;
    hidden var _state;
    hidden var _doneTicks;
    hidden var _seq;
    hidden var _seqLen;
    hidden var _bestLen;
    hidden var _showPhaseTick;
    hidden var _showIndex;
    hidden var _inputIndex;
    hidden var _flashTick;
    hidden var _sparkle;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        _state = MEM_STATE_SHOW;
        _doneTicks = 0;
        _seqLen = 3;
        _bestLen = 0;
        _showPhaseTick = 0;
        _showIndex = -1;
        _inputIndex = 0;
        _flashTick = 0;
        _sparkle = 0;
        _seq = new [MEM_MAX];
        for (var i = 0; i < _seqLen; i++) {
            _seq[i] = Math.rand().abs() % 4;
        }
    }

    // Speed increases with sequence length
    hidden function getShowOn() as Number {
        if (_seqLen >= 10) { return 6; }
        if (_seqLen >= 6)  { return 10; }
        return 14;
    }

    hidden function getShowGap() as Number {
        if (_seqLen >= 10) { return 3; }
        if (_seqLen >= 6)  { return 4; }
        return 5;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onGameTimer), 80, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    hidden function bestToPlayResult() as Number {
        if (_bestLen <= 3) { return 0; }
        if (_bestLen == 4) { return 1; }
        if (_bestLen <= 6) { return 2; }
        return 3;
    }

    hidden function startShowPhase() {
        _state = MEM_STATE_SHOW;
        _showIndex = -1;
        _showPhaseTick = 0;
        _inputIndex = 0;
    }

    hidden function endGame() {
        _state = MEM_STATE_DONE;
        _doneTicks = 0;
        _pet.playResult(bestToPlayResult());
        doVibe([new Toybox.Attention.VibeProfile(50, 300)]);
    }

    hidden function doVibe(profile) {
        if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate(profile);
        }
    }

    function onGameTimer() as Void {
        _sparkle = (_sparkle + 1) % 8;

        if (_state == MEM_STATE_SHOW) {
            _showPhaseTick++;
            var perStep = getShowOn() + getShowGap();
            var total = perStep * _seqLen;
            if (_showPhaseTick >= total) {
                _state = MEM_STATE_INPUT;
                _inputIndex = 0;
                _showIndex = -1;
            } else {
                var step = _showPhaseTick / perStep;
                var within = _showPhaseTick % perStep;
                _showIndex = (within < getShowOn()) ? step : -1;
            }
        } else if (_state == MEM_STATE_CORRECT) {
            _flashTick++;
            if (_flashTick >= 9) {
                if (_seqLen >= MEM_MAX) {
                    endGame();
                } else {
                    _seq[_seqLen] = Math.rand().abs() % 4;
                    _seqLen++;
                    startShowPhase();
                }
            }
        } else if (_state == MEM_STATE_WRONG) {
            _flashTick++;
            if (_flashTick >= 14) {
                endGame();
            }
        } else if (_state == MEM_STATE_DONE) {
            _doneTicks++;
            if (_doneTicks >= 30) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return;
            }
        }
        WatchUi.requestUpdate();
    }

    function inputDirection(dir as Number) {
        if (_state != MEM_STATE_INPUT) { return; }
        if (_seq[_inputIndex] != dir) {
            _state = MEM_STATE_WRONG;
            _flashTick = 0;
            doVibe([new Toybox.Attention.VibeProfile(100, 500)]);
            WatchUi.requestUpdate();
            return;
        }
        doVibe([new Toybox.Attention.VibeProfile(20, 40)]);
        _inputIndex++;
        if (_inputIndex >= _seqLen) {
            _bestLen = _seqLen;
            _state = MEM_STATE_CORRECT;
            _flashTick = 0;
            doVibe([
                new Toybox.Attention.VibeProfile(30, 80),
                new Toybox.Attention.VibeProfile(0, 40),
                new Toybox.Attention.VibeProfile(50, 120)
            ]);
        }
        WatchUi.requestUpdate();
    }

    hidden function dirSymbol(dir as Number) as String {
        if (dir == MEM_DIR_UP)   { return "^"; }
        if (dir == MEM_DIR_DOWN) { return "v"; }
        if (dir == MEM_DIR_LEFT) { return "<"; }
        return ">";
    }

    hidden function dirBtnName(dir as Number) as String {
        if (dir == MEM_DIR_UP)   { return "UP"; }
        if (dir == MEM_DIR_DOWN) { return "DOWN"; }
        if (dir == MEM_DIR_LEFT) { return "MENU"; }
        return "SEL";
    }

    hidden function dirColor(dir as Number) as Number {
        if (dir == MEM_DIR_UP)   { return 0x33DD66; }
        if (dir == MEM_DIR_DOWN) { return 0x3388FF; }
        if (dir == MEM_DIR_LEFT) { return 0xFF8833; }
        return 0xFF3399;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x080818, 0x080818);
        dc.clear();

        var petColors = _pet.getColors(_pet.petType);

        // Title
        dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 3 / 100, Graphics.FONT_SMALL, "MEMORY", Graphics.TEXT_JUSTIFY_CENTER);

        // Stats row
        dc.setColor(0x667788, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_XTINY,
            "Len:" + _seqLen + "  Best:" + _bestLen, Graphics.TEXT_JUSTIFY_CENTER);

        if (_state == MEM_STATE_SHOW) {
            drawShowPhase(dc, w, h);
        } else if (_state == MEM_STATE_INPUT) {
            drawInputPhase(dc, w, h);
        } else if (_state == MEM_STATE_CORRECT) {
            drawCorrectFlash(dc, w, h, petColors);
        } else if (_state == MEM_STATE_WRONG) {
            drawWrongFlash(dc, w, h);
        } else {
            drawDoneScreen(dc, w, h, petColors);
        }

        if (_state != MEM_STATE_DONE) {
            drawProgressDots(dc, w, h);
        }
    }

    hidden function drawShowPhase(dc, w, h) {
        var stepStr = (_showIndex >= 0 && _showIndex < _seqLen)
            ? ((_showIndex + 1) + " / " + _seqLen)
            : "---";
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 21 / 100, Graphics.FONT_XTINY, "WATCH  " + stepStr, Graphics.TEXT_JUSTIFY_CENTER);

        var activeDir = (_showIndex >= 0 && _showIndex < _seqLen) ? _seq[_showIndex] : -1;
        drawCross(dc, w, h, activeDir, false);
    }

    hidden function drawInputPhase(dc, w, h) {
        dc.setColor(0x44EE88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 21 / 100, Graphics.FONT_XTINY,
            "YOUR TURN  " + _inputIndex + "/" + _seqLen, Graphics.TEXT_JUSTIFY_CENTER);
        drawCross(dc, w, h, -1, true);
    }

    hidden function drawCorrectFlash(dc, w, h, petColors) {
        dc.setColor(0x33CC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 21 / 100, Graphics.FONT_SMALL, "NICE! +1", Graphics.TEXT_JUSTIFY_CENTER);
        var col = (_flashTick % 2 == 0) ? 0x44FF88 : 0x228844;
        drawAllBoxes(dc, w, h, col);
    }

    hidden function drawWrongFlash(dc, w, h) {
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 21 / 100, Graphics.FONT_SMALL, "WRONG!", Graphics.TEXT_JUSTIFY_CENTER);
        // Show expected direction
        var expDir = _seq[_inputIndex];
        dc.setColor(0xFFDD88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 32 / 100, Graphics.FONT_XTINY,
            "Expected: " + dirBtnName(expDir) + " " + dirSymbol(expDir), Graphics.TEXT_JUSTIFY_CENTER);
        drawCross(dc, w, h, expDir, false);
    }

    hidden function drawDoneScreen(dc, w, h, petColors) {
        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 27 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 44 / 100, Graphics.FONT_SMALL, "Best: " + _bestLen, Graphics.TEXT_JUSTIFY_CENTER);
        var grade = "Keep trying!";
        if      (_bestLen >= 12) { grade = "MEMORY MASTER!"; }
        else if (_bestLen >= 9)  { grade = "LEGENDARY!"; }
        else if (_bestLen >= 7)  { grade = "Impressive!"; }
        else if (_bestLen >= 5)  { grade = "Not bad!"; }
        else if (_bestLen >= 4)  { grade = "Good start!"; }
        dc.setColor(0x889999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 59 / 100, Graphics.FONT_XTINY, grade, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Draw the 4-direction cross.
    // activeDir: highlight this direction (-1 = none)
    // showBtnLabels: show button name hint instead of large arrow
    hidden function drawCross(dc, w, h, activeDir, showBtnLabels) {
        var midX = w / 2;
        var midY = h * 58 / 100;
        var bs   = w * 20 / 100;  // box side length
        var gap  = h * 3  / 100;  // gap between boxes and center

        // UP — above center
        drawBox(dc, midX - bs / 2, midY - bs - gap, bs, bs,
                MEM_DIR_UP, activeDir, showBtnLabels);
        // DOWN — below center
        drawBox(dc, midX - bs / 2, midY + gap, bs, bs,
                MEM_DIR_DOWN, activeDir, showBtnLabels);
        // LEFT — left of center
        drawBox(dc, midX - bs - gap, midY - bs / 2, bs, bs,
                MEM_DIR_LEFT, activeDir, showBtnLabels);
        // RIGHT — right of center
        drawBox(dc, midX + gap, midY - bs / 2, bs, bs,
                MEM_DIR_RIGHT, activeDir, showBtnLabels);
    }

    hidden function drawBox(dc, x, y, bw, bh, dir, activeDir, showBtnLabel) {
        var isActive = (dir == activeDir);
        var bgCol  = isActive ? dirColor(dir) : 0x141E2E;
        var rimCol = isActive ? 0xFFFFFF      : 0x2A3A4A;

        dc.setColor(bgCol, bgCol);
        dc.fillRectangle(x, y, bw, bh);
        dc.setColor(rimCol, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, bw, bh);

        if (showBtnLabel) {
            // Input phase: show arrow symbol + button name
            var textCol = 0x8899AA;
            dc.setColor(textCol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + bw / 2, y + bh / 6,
                Graphics.FONT_XTINY, dirSymbol(dir), Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(x + bw / 2, y + bh * 11 / 20,
                Graphics.FONT_XTINY, dirBtnName(dir), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // Show phase: large arrow, lit up if active
            var textCol = isActive ? 0xFFFFFF : 0x2A3A4A;
            dc.setColor(textCol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + bw / 2, y + bh / 5,
                Graphics.FONT_MEDIUM, dirSymbol(dir), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawAllBoxes(dc, w, h, col) {
        var midX = w / 2;
        var midY = h * 58 / 100;
        var bs   = w * 20 / 100;
        var gap  = h * 3  / 100;
        dc.setColor(col, col);
        dc.fillRectangle(midX - bs / 2, midY - bs - gap, bs, bs);
        dc.fillRectangle(midX - bs / 2, midY + gap,      bs, bs);
        dc.fillRectangle(midX - bs - gap, midY - bs / 2, bs, bs);
        dc.fillRectangle(midX + gap,      midY - bs / 2, bs, bs);
    }

    hidden function drawProgressDots(dc, w, h) {
        var cap = (_seqLen > 8) ? 8 : _seqLen;
        var dots = "";
        for (var i = 0; i < cap; i++) {
            if (_state == MEM_STATE_INPUT && i < _inputIndex) {
                dots = dots + "* ";
            } else {
                dots = dots + "o ";
            }
        }
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 88 / 100, Graphics.FONT_XTINY, dots, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
