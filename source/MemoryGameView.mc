using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;

const MEM_MAX = 16;
const MEM_SHOW_ON = 14;
const MEM_SHOW_GAP = 5;
const MEM_DIR_UP = 0;
const MEM_DIR_DOWN = 1;
const MEM_DIR_LEFT = 2;
const MEM_DIR_RIGHT = 3;

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
    hidden var _sparkles;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        _state = 0;
        _doneTicks = 0;
        _seqLen = 3;
        _bestLen = 0;
        _showPhaseTick = 0;
        _showIndex = 0;
        _inputIndex = 0;
        _sparkles = 0;
        _seq = new [MEM_MAX];
        for (var i = 0; i < _seqLen; i++) {
            _seq[i] = Math.rand().abs() % 4;
        }
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onGameTimer), 80, true);
    }

    function onHide() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    hidden function bestToPlayResult() {
        if (_bestLen <= 3) {
            return 0;
        } else if (_bestLen == 4) {
            return 1;
        } else if (_bestLen <= 6) {
            return 2;
        }
        return 3;
    }

    hidden function startShowPhase() {
        _state = 0;
        _showIndex = 0;
        _showPhaseTick = 0;
        _inputIndex = 0;
    }

    hidden function endGame() {
        _state = 2;
        _doneTicks = 0;
        _pet.playResult(bestToPlayResult());
        if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(20, 200)]);
        }
    }

    function onGameTimer() as Void {
        if (_state == 0) {
            _sparkles = (_sparkles + 1) % 8;
            _showPhaseTick++;
            var perStep = MEM_SHOW_ON + MEM_SHOW_GAP;
            var total = perStep * _seqLen;
            if (_showPhaseTick >= total) {
                _state = 1;
                _inputIndex = 0;
                _showIndex = -1;
            } else {
                var step = _showPhaseTick / perStep;
                var within = _showPhaseTick % perStep;
                if (within < MEM_SHOW_ON) {
                    _showIndex = step;
                } else {
                    _showIndex = -1;
                }
            }
        } else if (_state == 2) {
            _doneTicks++;
            if (_doneTicks >= 25) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return;
            }
        }
        WatchUi.requestUpdate();
    }

    function inputDirection(dir) {
        if (_state != 1) {
            return;
        }
        if (_seq[_inputIndex] != dir) {
            endGame();
            WatchUi.requestUpdate();
            return;
        }
        _inputIndex++;
        if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(30, 40)]);
        }
        if (_inputIndex >= _seqLen) {
            _bestLen = _seqLen;
            if (_seqLen >= MEM_MAX) {
                endGame();
                WatchUi.requestUpdate();
                return;
            }
            _seq[_seqLen] = Math.rand().abs() % 4;
            _seqLen++;
            startShowPhase();
        }
        WatchUi.requestUpdate();
    }

    hidden function dirLabel(dir) {
        if (dir == MEM_DIR_UP) {
            return "^";
        } else if (dir == MEM_DIR_DOWN) {
            return "v";
        } else if (dir == MEM_DIR_LEFT) {
            return "<";
        }
        return ">";
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x0F0F23, 0x0F0F23);
        dc.clear();

        var petColors = _pet.getColors(_pet.petType);

        dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_SMALL, "Memory", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 13 / 100, Graphics.FONT_XTINY,
            "Len " + _seqLen + "  Best " + _bestLen, Graphics.TEXT_JUSTIFY_CENTER);

        if (_state == 0) {
            dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
            var label = "Watch...";
            if (_showIndex >= 0 && _showIndex < _seqLen) {
                label = dirLabel(_seq[_showIndex]);
            }
            dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_LARGE, label, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x555577, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_XTINY, "Sequence", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == 1) {
            dc.setColor(0x66FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 38 / 100, Graphics.FONT_MEDIUM, "Repeat!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 52 / 100, Graphics.FONT_TINY,
                "" + _inputIndex + "/" + _seqLen, Graphics.TEXT_JUSTIFY_CENTER);
            drawArrowHints(dc, w, h, petColors);
        } else {
            dc.setColor(0xFF8888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 38 / 100, Graphics.FONT_MEDIUM, "Over!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(petColors[3], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 52 / 100, Graphics.FONT_TINY, "Best len " + _bestLen, Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawProgressDots(dc, w, h);
        drawDecorations(dc, w, h);
    }

    hidden function drawArrowHints(dc, w, h, petColors) {
        dc.setColor(0x666688, Graphics.COLOR_TRANSPARENT);
        var y = h * 68 / 100;
        dc.drawText(w / 2, y, Graphics.FONT_XTINY, "Sel^ Menuv <Pr Nx>", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawProgressDots(dc, w, h) {
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        var dots = "";
        var cap = _seqLen;
        if (cap > 8) {
            cap = 8;
        }
        for (var i = 0; i < cap; i++) {
            if (_state == 1 && i < _inputIndex) {
                dots = dots + "* ";
            } else {
                dots = dots + "o ";
            }
        }
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_TINY, dots, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawDecorations(dc, w, h) {
        var f = _sparkles;
        dc.setColor(0x222244, 0x222244);
        var topY = h * 24 / 100;
        dc.drawLine(w * 12 / 100, topY, w * 88 / 100, topY);
        dc.setColor(0x333355, 0x333355);
        if (f % 4 < 2) {
            dc.fillRectangle(w * 18 / 100, topY - 4, 2, 2);
            dc.fillRectangle(w * 82 / 100, topY - 4, 2, 2);
        }
    }
}
