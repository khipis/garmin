using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum { AP_IDLE, AP_MENU, AP_FOCUS, AP_INTERRUPT, AP_END }

class AngryPomodoroView extends WatchUi.View {

    var gameState;

    hidden var _w;
    hidden var _h;
    hidden var _timer;
    hidden var _tick;

    hidden var _menuSel;        // 0=10min  1=25min  2=45min
    hidden var _menuLabels;
    hidden var _presets;        // seconds per preset

    hidden var _totalSecs;
    hidden var _secsLeft;

    hidden var _breathPhase;    // 0..2π for breathing ring

    hidden var _interruptLeft;  // ticks remaining in interrupt overlay

    hidden var _shakeOx;
    hidden var _shakeOy;
    hidden var _shakeLeft;

    hidden var _endTick;
    hidden var _endVibeTick;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;

        gameState     = AP_IDLE;
        _tick         = 0;
        _menuSel      = 1;
        _presets      = [60, 300, 900, 1800];   // 1 / 5 / 15 / 30 minutes
        _menuLabels   = ["1 min", "5 min", "15 min", "30 min"];
        _totalSecs    = 0;
        _secsLeft     = 0;
        _breathPhase  = 0.0;
        _interruptLeft = 0;
        _shakeOx = 0; _shakeOy = 0; _shakeLeft = 0;
        _endTick = 0; _endVibeTick = 0;
    }

    // onShow is called on app open AND on every wrist-raise while app is active.
    // During focus mode this IS the interruption trigger.
    function onShow() {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 50, true);
        }
        if (gameState == AP_FOCUS && _interruptLeft <= 0) {
            _triggerInterrupt();
        }
    }

    function onHide() {
        // Keep timer alive: focus countdown must continue while wrist is down.
        // Timer is only cleaned up when app exits.
    }

    function onTick() as Void {
        _tick++;

        if (_shakeLeft > 0) {
            _shakeOx = (Math.rand().abs() % 11) - 5;
            _shakeOy = (Math.rand().abs() % 9)  - 4;
            _shakeLeft--;
        } else { _shakeOx = 0; _shakeOy = 0; }

        if (gameState == AP_FOCUS) {
            _breathPhase += 0.04;
            if (_breathPhase >= 6.28318) { _breathPhase -= 6.28318; }
            if (_tick % 20 == 0 && _secsLeft > 0) {
                _secsLeft--;
                if (_secsLeft <= 0) { _secsLeft = 0; _triggerEnd(); return; }
            }
        } else if (gameState == AP_INTERRUPT) {
            _breathPhase += 0.04;
            if (_breathPhase >= 6.28318) { _breathPhase -= 6.28318; }
            _interruptLeft--;
            if (_interruptLeft <= 0) { gameState = AP_FOCUS; }
            // Countdown still ticks during interrupt
            if (_tick % 20 == 0 && _secsLeft > 0) {
                _secsLeft--;
                if (_secsLeft <= 0) { _secsLeft = 0; _triggerEnd(); return; }
            }
        } else if (gameState == AP_END) {
            _endTick++;
            _breathPhase += 0.1;
            if (_breathPhase >= 6.28318) { _breathPhase -= 6.28318; }
            _endVibeTick++;
            if (_endVibeTick >= 40) {
                _endVibeTick = 0;
                _doVibe(90, 280);
            }
        }

        WatchUi.requestUpdate();
    }

    hidden function _triggerInterrupt() {
        gameState = AP_INTERRUPT;
        _interruptLeft = 44;    // ~2.2 seconds at 50ms/tick
        _shakeLeft = 16;
        _doVibe(70, 180);
    }

    hidden function _triggerEnd() {
        gameState = AP_END;
        _endTick = 0; _endVibeTick = 0;
        _shakeLeft = 24;
        _doVibe(100, 500);
    }

    hidden function _doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate(
                    [new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }

    // ── Public input handlers ───────────────────────────────────────────────

    function doSelect() {
        if (gameState == AP_IDLE) {
            gameState = AP_MENU;
        } else if (gameState == AP_MENU) {
            _totalSecs = _presets[_menuSel];
            _secsLeft  = _totalSecs;
            _breathPhase = 0.0;
            gameState = AP_FOCUS;
            _doVibe(40, 100);
        } else if (gameState == AP_INTERRUPT) {
            _interruptLeft = 0;
            gameState = AP_FOCUS;
        } else if (gameState == AP_END) {
            gameState = AP_IDLE;
            _secsLeft = 0; _totalSecs = 0; _endTick = 0;
        }
    }

    function doUp() {
        if (gameState == AP_MENU) { _menuSel = (_menuSel + 3) % 4; }
    }

    function doDown() {
        if (gameState == AP_MENU) { _menuSel = (_menuSel + 1) % 4; }
    }

    function doBack() {
        if (gameState == AP_MENU) {
            gameState = AP_IDLE;
            return true;
        } else if (gameState == AP_FOCUS || gameState == AP_INTERRUPT) {
            gameState = AP_IDLE;
            _secsLeft = 0; _totalSecs = 0; _interruptLeft = 0;
            return true;
        } else if (gameState == AP_END) {
            gameState = AP_IDLE;
            _secsLeft = 0; _totalSecs = 0; _endTick = 0;
            return true;
        }
        // AP_IDLE — let the system exit the app
        return false;
    }

    // ── Rendering ───────────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        if      (gameState == AP_IDLE)      { _drawIdle(dc); }
        else if (gameState == AP_MENU)      { _drawMenu(dc); }
        else if (gameState == AP_FOCUS)     { _drawFocus(dc); }
        else if (gameState == AP_INTERRUPT) { _drawInterrupt(dc); }
        else if (gameState == AP_END)       { _drawEnd(dc); }
    }

    // ── IDLE ────────────────────────────────────────────────────────────────
    hidden function _drawIdle(dc) {
        dc.setColor(0x080C16, 0x080C16);
        dc.clear();

        // Title — FONT_XTINY + ~12% from top: safely inside circular watch boundary
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 12 / 100, Graphics.FONT_XTINY,
            "ANGRY POMODORO", Graphics.TEXT_JUSTIFY_CENTER);

        // Face — slightly above centre, radius tightened to leave room for hints
        var r = _w * 19 / 100;
        if (r > 42) { r = 42; }
        if (r < 20) { r = 20; }
        _drawFaceNeutral(dc, _w / 2, _h * 45 / 100, r);

        // Pulsing tap prompt
        var pc = (_tick % 16 < 8) ? 0x9999AA : 0x555566;
        dc.setColor(pc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 71 / 100, Graphics.FONT_XTINY,
            "Tap to start", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x2A3040, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 82 / 100, Graphics.FONT_XTINY,
            "1  5  15  30 min", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── MENU ────────────────────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        dc.setColor(0x060A12, 0x060A12);
        dc.clear();

        // Header — FONT_XTINY at ~13% keeps it inside the circular boundary
        dc.setColor(0xFF7744, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 13 / 100, Graphics.FONT_XTINY,
            "FOCUS FOR...", Graphics.TEXT_JUSTIFY_CENTER);

        var labels = _menuLabels;
        // Rows fill the safe zone between header and ~88% bottom margin
        var startY = _h * 27 / 100;
        if (startY < 36) { startY = 36; }
        var endY   = _h * 90 / 100;
        var rowH   = (endY - startY) / 4;
        if (rowH > 40) { rowH = 40; }
        if (rowH < 24) { rowH = 24; }

        for (var i = 0; i < 4; i++) {
            var ry = startY + i * rowH;
            if (i == _menuSel) {
                dc.setColor(0x1A2E48, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(_w * 10 / 100, ry, _w * 80 / 100, rowH - 2, 6);
                dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(_w * 10 / 100, ry, _w * 80 / 100, rowH - 2, 6);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(_w / 2, ry + (rowH - 20) / 2, Graphics.FONT_SMALL,
                labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Short hint well inside the safe bottom zone
        dc.setColor(0x222A38, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 92 / 100, Graphics.FONT_XTINY,
            "tap = start", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── FOCUS (calm breathing mode) ─────────────────────────────────────────
    hidden function _drawFocus(dc) {
        dc.setColor(0x020810, 0x020810);
        dc.clear();

        // Breathing ring — expands/contracts with sinusoidal phase
        var baseR = _w * 30 / 100;
        var br    = baseR + (Math.sin(_breathPhase) * (_w * 7 / 100)).toNumber();
        if (br < 10) { br = 10; }

        // Ring fill (inhale = bright, exhale = dim)
        var ringC = (_breathPhase < 3.14159) ? 0x0A3A5A : 0x071828;
        dc.setColor(ringC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w / 2, _h / 2, br);

        // Hollow center so timer is readable
        dc.setColor(0x020810, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w / 2, _h / 2, br - 6);

        // Outer glow
        dc.setColor(0x123A5A, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_w / 2, _h / 2, br + 4);
        dc.drawCircle(_w / 2, _h / 2, br + 7);

        // Centered countdown — inside the ring
        dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h / 2 - _h * 9 / 100, Graphics.FONT_NUMBER_HOT,
            _fmtTime(_secsLeft), Graphics.TEXT_JUSTIFY_CENTER);

        // Progress bar at bottom
        if (_totalSecs > 0) {
            var pW = _w * 70 / 100;
            var px = (_w - pW) / 2;
            var py = _h * 87 / 100;
            dc.setColor(0x0A1A28, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px, py, pW, 4);
            var done = _totalSecs - _secsLeft;
            var fill = pW * done / _totalSecs;
            if (fill > pW) { fill = pW; }
            dc.setColor(0x2266AA, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px, py, fill, 4);
        }

        dc.setColor(0x0C1A28, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 93 / 100, Graphics.FONT_XTINY,
            "Back = stop", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── INTERRUPT (wrist-raise / look-at-watch punishment) ─────────────────
    hidden function _drawInterrupt(dc) {
        var ox = _shakeOx; var oy = _shakeOy;

        // Flashing dark-red background
        var bgC = (_tick % 6 < 3) ? 0x1E0000 : 0x140000;
        dc.setColor(bgC, bgC);
        dc.clear();

        // Bright red header bar
        var hbc = (_tick % 4 < 2) ? 0xFF1100 : 0xFF3300;
        dc.setColor(hbc, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h * 24 / 100);

        // Header text
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + ox, _h * 4 / 100 + oy,
            Graphics.FONT_SMALL, "GO BACK TO", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFF00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + ox, _h * 14 / 100 + oy,
            Graphics.FONT_MEDIUM, "TASK!", Graphics.TEXT_JUSTIFY_CENTER);

        // Angry face
        _drawFaceAngry(dc, _w / 2 + ox, _h * 43 / 100 + oy, _w * 20 / 100);

        // Remaining timer — large + red (useful info while being scolded)
        var tc = (_tick % 4 < 2) ? 0xFF4444 : 0xFF6666;
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + ox, _h * 65 / 100 + oy,
            Graphics.FONT_NUMBER_HOT, _fmtTime(_secsLeft), Graphics.TEXT_JUSTIFY_CENTER);

        // Dismiss hint appears after 1 second
        if (_interruptLeft < 22) {
            dc.setColor(0x554444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 91 / 100, Graphics.FONT_XTINY,
                "Tap to dismiss", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── END / RAGE MODE ─────────────────────────────────────────────────────
    hidden function _drawEnd(dc) {
        var flash = (_endTick % 8 < 4);
        var bgC   = flash ? 0x220000 : 0x350800;
        dc.setColor(bgC, bgC);
        dc.clear();

        // Flashing header
        dc.setColor(flash ? 0xFF2200 : 0xFF5500, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h * 22 / 100);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 5 / 100, Graphics.FONT_MEDIUM,
            "TIME'S UP!", Graphics.TEXT_JUSTIFY_CENTER);

        // Rage face (large + animated)
        _drawFaceRage(dc, _w / 2, _h * 48 / 100, _w * 26 / 100);

        // Reward message
        dc.setColor(flash ? 0xFFFF00 : 0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 73 / 100, Graphics.FONT_SMALL,
            "GREAT FOCUS!", Graphics.TEXT_JUSTIFY_CENTER);

        if (_endTick > 40) {
            var rc = (_endTick % 10 < 5) ? 0xFF8844 : 0xCC5522;
            dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 84 / 100, Graphics.FONT_XTINY,
                "Tap to reset", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Face: NEUTRAL (idle state) ──────────────────────────────────────────
    hidden function _drawFaceNeutral(dc, cx, cy, r) {
        // Head — yellow tomato
        dc.setColor(0xFFCC33, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(0xCC9911, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);

        var eo = r * 28 / 100;
        var eyY = cy - r * 10 / 100;
        var eyR = r * 13 / 100;

        // Eyes
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - eo, eyY, eyR);
        dc.fillCircle(cx + eo, eyY, eyR);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - eo + 2, eyY - 2, eyR * 42 / 100);
        dc.fillCircle(cx + eo + 2, eyY - 2, eyR * 42 / 100);

        // Flat neutral mouth
        var mY = cy + r * 28 / 100;
        dc.setColor(0x884400, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - r * 20 / 100, mY, r * 40 / 100, 3);

        // Rosy cheeks
        dc.setColor(0xFF9977, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r * 42 / 100, cy + r * 14 / 100, r * 10 / 100);
        dc.fillCircle(cx + r * 42 / 100, cy + r * 14 / 100, r * 10 / 100);

        // Small green leaf on top
        dc.setColor(0x44AA33, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 3, cy - r + 2], [cx - r * 12 / 100, cy - r - r * 15 / 100],
                        [cx + 3, cy - r - 2]]);
        dc.fillPolygon([[cx + 3, cy - r + 2], [cx + r * 12 / 100, cy - r - r * 15 / 100],
                        [cx - 3, cy - r - 2]]);
    }

    // ── Face: ANGRY (interrupt state) ───────────────────────────────────────
    hidden function _drawFaceAngry(dc, cx, cy, r) {
        // Head — reddish tomato, pulsing
        var hc = (_tick % 6 < 3) ? 0xFF5533 : 0xFF7744;
        dc.setColor(hc, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(0xCC2200, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        dc.drawCircle(cx, cy, r + 1);

        var eo = r * 28 / 100;
        var eyY = cy - r * 10 / 100;
        var eyR = r * 13 / 100;

        // Angry V-shaped eyebrows (inward-descending polygons)
        dc.setColor(0x110000, Graphics.COLOR_TRANSPARENT);
        // Left brow: descends left→right toward center
        dc.fillPolygon([[cx - eo - eyR - 3, eyY - eyR - 7],
                        [cx - eo + eyR + 1,  eyY - eyR - 2],
                        [cx - eo + eyR + 1,  eyY - eyR + 2],
                        [cx - eo - eyR - 3,  eyY - eyR - 3]]);
        // Right brow: descends right→left toward center
        dc.fillPolygon([[cx + eo - eyR - 1,  eyY - eyR - 2],
                        [cx + eo + eyR + 3,  eyY - eyR - 7],
                        [cx + eo + eyR + 3,  eyY - eyR - 3],
                        [cx + eo - eyR - 1,  eyY - eyR + 2]]);

        // Eyes — squinted, red pupils
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - eo, eyY, eyR);
        dc.fillCircle(cx + eo, eyY, eyR);
        dc.setColor(0xFF1100, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - eo, eyY, eyR * 60 / 100);
        dc.fillCircle(cx + eo, eyY, eyR * 60 / 100);

        // Gritted-teeth mouth
        var mY = cy + r * 28 / 100;
        var mW = r * 55 / 100;
        var mH = r * 22 / 100;
        dc.setColor(0x110000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - mW, mY, mW * 2, mH);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var tw = mW * 2 / 3;
        for (var t = 0; t < 3; t++) {
            dc.fillRectangle(cx - mW + t * tw + 2, mY + 1, tw - 3, mH * 55 / 100);
        }

        // Steam puffs (animated, above head)
        var sC = (_tick % 4 < 2) ? 0xFF7744 : 0xFFAA66;
        dc.setColor(sC, Graphics.COLOR_TRANSPARENT);
        var sOff = (_tick / 4 % 3);
        dc.fillCircle(cx - r * 18 / 100, cy - r - r * 20 / 100 - sOff * 2, r * 7 / 100);
        dc.fillCircle(cx + r * 18 / 100, cy - r - r * 16 / 100 - sOff,     r * 6 / 100);
    }

    // ── Face: RAGE (end state) ───────────────────────────────────────────────
    hidden function _drawFaceRage(dc, cx, cy, r) {
        // Cycling hot colors
        var t = _endTick % 12;
        var hc;
        if (t < 4)       { hc = 0xFF3300; }
        else if (t < 8)  { hc = 0xFF5500; }
        else             { hc = 0xFF2200; }
        dc.setColor(hc, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);

        // Pulsing outer ring
        var rr = r + (_endTick % 6) + 1;
        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rr);
        dc.drawCircle(cx, cy, rr + 2);
        dc.drawCircle(cx, cy, rr + 4);

        var eo  = r * 30 / 100;
        var eyY = cy - r * 8  / 100;
        var eyR = r * 16 / 100;

        // Exaggerated V-brows (wider + thicker)
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - eo - eyR - 5, eyY - eyR - 10],
                        [cx - eo + eyR + 2,  eyY - eyR - 3],
                        [cx - eo + eyR + 2,  eyY - eyR + 3],
                        [cx - eo - eyR - 5,  eyY - eyR - 4]]);
        dc.fillPolygon([[cx + eo - eyR - 2,  eyY - eyR - 3],
                        [cx + eo + eyR + 5,  eyY - eyR - 10],
                        [cx + eo + eyR + 5,  eyY - eyR - 4],
                        [cx + eo - eyR - 2,  eyY - eyR + 3]]);

        // Glowing rage eyes
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - eo, eyY, eyR);
        dc.fillCircle(cx + eo, eyY, eyR);
        dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - eo, eyY, eyR * 72 / 100);
        dc.fillCircle(cx + eo, eyY, eyR * 72 / 100);
        var gC = (_endTick % 4 < 2) ? 0xFFAA00 : 0xFF4400;
        dc.setColor(gC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - eo, eyY, eyR * 35 / 100);
        dc.fillCircle(cx + eo, eyY, eyR * 35 / 100);

        // Wide open screaming mouth
        var mY = cy + r * 26 / 100;
        var mW = r * 62 / 100;
        var mH = r * 32 / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - mW, mY, mW * 2, mH);
        // Top teeth
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var tw = mW * 2 / 3;
        for (var tt = 0; tt < 3; tt++) {
            dc.fillRectangle(cx - mW + tt * tw + 2, mY + 1, tw - 3, mH / 3);
        }
        // Red tongue (waggling)
        var tongX = cx + (_endTick % 6 < 3 ? 3 : -3);
        dc.setColor(0xFF1133, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tongX, mY + mH * 65 / 100, r * 14 / 100);

        // Radial rage sparks (animated rotation)
        var sC = (_endTick % 6 < 3) ? 0xFF8800 : 0xFFCC00;
        dc.setColor(sC, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 6; i++) {
            var sa   = i * 60 + _endTick * 8;
            var srad = sa.toFloat() * 3.14159 / 180.0;
            var sd   = r + 8 + (_endTick % 5);
            var spx  = cx + (sd.toFloat() * Math.cos(srad)).toNumber();
            var spy  = cy + (sd.toFloat() * Math.sin(srad)).toNumber();
            dc.fillCircle(spx, spy, 3);
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    hidden function _fmtTime(secs) {
        var m  = secs / 60;
        var s  = secs % 60;
        var ss = (s < 10) ? ("0" + s) : ("" + s);
        return m + ":" + ss;
    }
}
