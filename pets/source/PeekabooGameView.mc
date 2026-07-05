using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;

// "Peekaboo!" — your pet pops up out of one of 3 burrows for a split
// second; move the cursor onto the right burrow and boop it (SELECT)
// before it ducks back down. Tests precision + reflex together, unlike the
// single-target ReactGame or the mash-fest RushGame.
const PEEKABOO_ROUNDS = 8;
const PEEKABOO_BURROWS = 3;
const PEEKABOO_PEEK_TICKS = 11;

class PeekabooGameView extends WatchUi.View {

    hidden var _pet;
    hidden var _timer;
    hidden var _cursor;
    hidden var _target;
    hidden var _state; // 0=wait 1=peeking 2=hit 3=miss 4=done
    hidden var _waitTicks;
    hidden var _targetWait;
    hidden var _peekTicks;
    hidden var _resultTicks;
    hidden var _round;
    hidden var _hits;
    hidden var _sparkles;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        _cursor = 1;
        _round = 0;
        _hits = 0;
        _sparkles = 0;
        setupRound();
    }

    hidden function setupRound() {
        _state = 0;
        _waitTicks = 0;
        _targetWait = 8 + Math.rand().abs() % 14;
        _peekTicks = 0;
        _resultTicks = 0;
        _target = Math.rand().abs() % PEEKABOO_BURROWS;
        if (_pet.hasTrait(TRAIT_HYPER)) { _targetWait -= 3; }
        if (_targetWait < 4) { _targetWait = 4; }
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onGameTimer), 80, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    hidden function finish() {
        _state = 4;
        _resultTicks = 0;
        var score;
        if (_hits >= 7) { score = 3; }
        else if (_hits >= 5) { score = 2; }
        else if (_hits >= 3) { score = 1; }
        else { score = 0; }
        _pet.playResult(score);
    }

    function onGameTimer() as Void {
        _sparkles = (_sparkles + 1) % 8;
        if (_state == 0) {
            _waitTicks++;
            if (_waitTicks >= _targetWait) {
                _state = 1;
                _peekTicks = 0;
                if (Toybox.Attention has :vibrate) {
                    Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(30, 60)]);
                }
            }
        } else if (_state == 1) {
            _peekTicks++;
            if (_peekTicks > PEEKABOO_PEEK_TICKS) {
                _state = 3;
                _resultTicks = 0;
            }
        } else if (_state == 2 || _state == 3) {
            _resultTicks++;
            if (_resultTicks >= 10) {
                _round++;
                if (_round >= PEEKABOO_ROUNDS) { finish(); }
                else { setupRound(); }
            }
        } else if (_state == 4) {
            _resultTicks++;
            if (_resultTicks >= 25) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return;
            }
        }
        WatchUi.requestUpdate();
    }

    function moveCursor(delta) {
        if (_state != 0 && _state != 1) { return; }
        _cursor = (_cursor + delta + PEEKABOO_BURROWS) % PEEKABOO_BURROWS;
    }

    function boop() {
        if (_state == 1 && _cursor == _target) {
            _hits++;
            _state = 2;
            _resultTicks = 0;
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(70, 80)]);
            }
        } else if (_state == 0 || _state == 1) {
            _state = 3;
            _resultTicks = 0;
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(20, 150)]);
            }
        }
    }

    hidden function burrowX(dc, i) {
        var w = dc.getWidth();
        return w * (25 + i * 25) / 100;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x122016, 0x122016);
        dc.clear();

        var petColors = _pet.getColors(_pet.petType);

        dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 4 / 100, Graphics.FONT_SMALL, "Peekaboo!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_XTINY,
            "Round " + (_round + 1) + "/" + PEEKABOO_ROUNDS, Graphics.TEXT_JUSTIFY_CENTER);

        var groundY = h * 58 / 100;
        var moundR = w * 11 / 100;
        if (moundR < 14) { moundR = 14; }

        for (var i = 0; i < PEEKABOO_BURROWS; i++) {
            var bx = burrowX(dc, i);
            dc.setColor(0x2E4A2E, 0x2E4A2E);
            dc.fillCircle(bx, groundY, moundR);
            dc.setColor(0x0A0A0A, 0x0A0A0A);
            dc.fillCircle(bx, groundY, moundR * 6 / 10);

            if (_state == 1 && _target == i) {
                var ps = w / 40;
                if (ps < 2) { ps = 2; }
                _pet.drawPreview(dc, bx, groundY - moundR * 3 / 10, ps, _pet.petType);
                dc.setColor(0xFFEE88, Graphics.COLOR_TRANSPARENT);
                var pct = 100 - (_peekTicks * 100 / PEEKABOO_PEEK_TICKS);
                dc.drawArc(bx, groundY - moundR * 3 / 10, moundR, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * pct / 100));
            }

            if (_cursor == i) {
                var cclr = (_state == 2) ? 0x66FF66 : ((_state == 3) ? 0xFF4444 : 0xFFDD55);
                dc.setColor(cclr, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx - 5, groundY + moundR + 4, 10, 3);
                dc.drawText(bx, groundY + moundR + 10, Graphics.FONT_XTINY, "^", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (_state == 2) {
            dc.setColor(0x66FF66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 76 / 100, Graphics.FONT_MEDIUM, "BOOP!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == 3) {
            dc.setColor(0xFF6666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 76 / 100, Graphics.FONT_MEDIUM, "Missed!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_state == 4) {
            dc.setColor(petColors[3], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 68 / 100, Graphics.FONT_MEDIUM, "Done!", Graphics.TEXT_JUSTIFY_CENTER);
            var msg;
            if (_hits >= 7) { msg = "Amazing reflexes!"; }
            else if (_hits >= 5) { msg = "Great job!"; }
            else if (_hits >= 3) { msg = "Not bad!"; }
            else { msg = "Fun times!"; }
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_TINY, _hits + "/" + PEEKABOO_ROUNDS + " - " + msg, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x556655, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 90 / 100, Graphics.FONT_XTINY, "prv/nxt move  SEL boop", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class PeekabooGameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.boop();
        return true;
    }

    function onPreviousPage() {
        _view.moveCursor(-1);
        return true;
    }

    function onNextPage() {
        _view.moveCursor(1);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
