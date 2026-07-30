using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;

// "Bubble Pop!" — your pet blows a stream of confetti bubbles that drift up
// the screen. Hit SELECT while one is inside the glowing pop band and it
// bursts; let it float past the top and it is gone. Several bubbles are in
// flight at once, so unlike the single-target React/Peekaboo games this one
// is about picking the right moment out of a crowd.
//
// Positions live in a 0..1000 virtual space and are scaled at draw time, so
// the game behaves identically on every watch size.
const BUBBLE_TOTAL = 12;
const BUBBLE_SLOTS = 4;
const BUBBLE_BAND_TOP = 400;
const BUBBLE_BAND_BOT = 580;

class BubbleGameView extends WatchUi.View {

    hidden var _pet;
    hidden var _timer;
    hidden var _bx;
    hidden var _by;
    hidden var _bv;
    hidden var _bc;
    hidden var _bon;
    hidden var _spawned;
    hidden var _hits;
    hidden var _spawnCd;
    hidden var _state;      // 0 = playing, 1 = done
    hidden var _flash;      // countdown for the hit/miss caption
    hidden var _flashOk;
    hidden var _resultTicks;
    hidden var _shine;
    hidden var _intro;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        _bx = [0, 0, 0, 0];
        _by = [0, 0, 0, 0];
        _bv = [0, 0, 0, 0];
        _bc = [0, 0, 0, 0];
        _bon = [false, false, false, false];
        _spawned = 0;
        _hits = 0;
        _spawnCd = 2;
        _state = 0;
        _flash = 0;
        _flashOk = false;
        _resultTicks = 0;
        _shine = 0;
        _intro = 30;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onGameTimer), 80, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    hidden function bubbleColor(i) {
        var pal = [0xFF2FD0, 0x00E5FF, 0xFFE24A, 0x76FF03, 0xFF6B35, 0xB388FF];
        return pal[i % pal.size()];
    }

    hidden function liveCount() {
        var n = 0;
        for (var i = 0; i < BUBBLE_SLOTS; i++) {
            if (_bon[i]) { n++; }
        }
        return n;
    }

    hidden function spawnBubble() {
        for (var i = 0; i < BUBBLE_SLOTS; i++) {
            if (!_bon[i]) {
                _bon[i] = true;
                _bx[i] = 180 + Math.rand().abs() % 640;
                _by[i] = 1040;
                _bv[i] = 26 + Math.rand().abs() % 20;
                if (_pet.hasTrait(TRAIT_HYPER)) { _bv[i] += 6; }
                if (_pet.hasTrait(TRAIT_LAZY)) { _bv[i] -= 4; }
                _bc[i] = Math.rand().abs() % 6;
                _spawned++;
                return;
            }
        }
    }

    hidden function finish() {
        _state = 1;
        _resultTicks = 0;
        var score;
        if (_hits >= 10) { score = 3; }
        else if (_hits >= 7) { score = 2; }
        else if (_hits >= 4) { score = 1; }
        else { score = 0; }
        _pet.playResult(score);
    }

    function onGameTimer() as Void {
        _shine = (_shine + 1) % 10;
        if (_flash > 0) { _flash--; }
        if (_intro > 0) { _intro--; }

        if (_state == 1) {
            _resultTicks++;
            if (_resultTicks >= 25) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return;
            }
            WatchUi.requestUpdate();
            return;
        }

        // Bubbles that clear the band are gone; they are retired well before the
        // header so they never drift behind the title text.
        for (var i = 0; i < BUBBLE_SLOTS; i++) {
            if (_bon[i]) {
                _by[i] -= _bv[i];
                if (_by[i] < 230) { _bon[i] = false; }
            }
        }

        if (_spawnCd > 0) { _spawnCd--; }
        if (_spawned < BUBBLE_TOTAL && _spawnCd <= 0 && liveCount() < BUBBLE_SLOTS) {
            spawnBubble();
            _spawnCd = 5 + Math.rand().abs() % 7;
        }

        if (_spawned >= BUBBLE_TOTAL && liveCount() == 0) { finish(); }

        WatchUi.requestUpdate();
    }

    // Pop the bubble sitting closest to the middle of the band. Tapping with
    // nothing in range just costs the caption — no bubble is destroyed, so a
    // panicky player is never punished twice.
    function pop() {
        if (_state != 0) { return; }
        var best = -1;
        var bestDist = 99999;
        var mid = (BUBBLE_BAND_TOP + BUBBLE_BAND_BOT) / 2;
        for (var i = 0; i < BUBBLE_SLOTS; i++) {
            if (_bon[i] && _by[i] >= BUBBLE_BAND_TOP && _by[i] <= BUBBLE_BAND_BOT) {
                var d = _by[i] - mid;
                if (d < 0) { d = -d; }
                if (d < bestDist) { bestDist = d; best = i; }
            }
        }
        if (best >= 0) {
            _bon[best] = false;
            _hits++;
            _flash = 7;
            _flashOk = true;
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(60, 70)]);
            }
        } else {
            _flash = 7;
            _flashOk = false;
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(20, 120)]);
            }
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x14082A, 0x14082A);
        dc.clear();

        var petColors = _pet.getColors(_pet.petType);
        var bandTop = h * BUBBLE_BAND_TOP / 1000;
        var bandBot = h * BUBBLE_BAND_BOT / 1000;

        // Pop band
        dc.setColor(0x241247, 0x241247);
        dc.fillRectangle(0, bandTop, w, bandBot - bandTop);
        dc.setColor(0x8A2BE2, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, bandTop, w, bandTop);
        dc.drawLine(0, bandBot, w, bandBot);

        var r = w * 8 / 100;
        if (r < 8) { r = 8; }

        for (var i = 0; i < BUBBLE_SLOTS; i++) {
            if (!_bon[i]) { continue; }
            var bx = w * _bx[i] / 1000;
            var by = h * _by[i] / 1000;
            if (by < -r || by > h + r) { continue; }
            var clr = bubbleColor(_bc[i]);
            var inBand = (_by[i] >= BUBBLE_BAND_TOP && _by[i] <= BUBBLE_BAND_BOT);
            if (inBand) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(bx, by, r + 2);
            }
            dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, r);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx - r / 3, by - r / 3, r / 4);
        }

        // Title + NEW tag while the drop is fresh
        dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 4 / 100, Graphics.FONT_SMALL, "Bubble Pop!", Graphics.TEXT_JUSTIFY_CENTER);

        // The "new game" tag only greets the player for the first couple of
        // seconds, then the slot hands over to the live score.
        if (_state == 0) {
            var isNew = false;
            if (_intro > 0) {
                try { isNew = _pet.newDropActive(); } catch (e) {}
            }
            if (isNew) {
                dc.setColor(0xFFE24A, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h * 16 / 100, Graphics.FONT_XTINY, "* NEW GAME *", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(0x8888AA, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h * 16 / 100, Graphics.FONT_XTINY,
                    _hits + " / " + BUBBLE_TOTAL, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        if (_state == 1) {
            dc.setColor(petColors[3], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 66 / 100, Graphics.FONT_MEDIUM, "Done!", Graphics.TEXT_JUSTIFY_CENTER);
            var msg;
            if (_hits >= 10) { msg = "Bubble legend!"; }
            else if (_hits >= 7) { msg = "Poppin' off!"; }
            else if (_hits >= 4) { msg = "Not bad!"; }
            else { msg = "Bubbles won."; }
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_TINY,
                _hits + "/" + BUBBLE_TOTAL + " - " + msg, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_flash > 0) {
            if (_flashOk) {
                dc.setColor(0x76FF03, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_TINY, "POP!", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(0xFF6666, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_TINY, "whiff!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else {
            dc.setColor(0x6A5A8A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_XTINY, "SEL = pop", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class BubbleGameDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.pop();
        return true;
    }

    function onPreviousPage() {
        _view.pop();
        return true;
    }

    function onNextPage() {
        _view.pop();
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
