using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Application;

// ─────────────────────────────────────────────────────────────────────────────
//  Bitochi Moon Lander — view + game logic
//
//  Physics tick: 50 ms  (20 fps)
//
//  Controls:
//    Button / tap   → main thruster (upward impulse, 7-tick burn)
//    Tilt watch L/R → side thrusters (accelerometer X-axis, gentle deadzone)
//
//  Win:  land on the bright green flat pad with low velocity
//  Lose: crash anywhere else, land too fast, or run out of fuel
// ─────────────────────────────────────────────────────────────────────────────

enum { MS_MENU, MS_PLAY, MS_WIN, MS_CRASH }

const ML_SEGS     = 12;    // terrain segments
const ML_FUEL_MAX = 1000;  // starting fuel (units)

class BitochiMoonView extends WatchUi.View {

    // Accelerometer values — set by delegate from sensor callbacks
    var accelX;
    var accelY;
    var accelZ;

    hidden var _w;
    hidden var _h;
    hidden var _timer;
    hidden var _tick;
    hidden var _gs;             // game state

    // Physics (float)
    hidden var _posX;           // lander centre X
    hidden var _posY;           // lander top Y (Y increases downward)
    hidden var _velX;
    hidden var _velY;
    hidden var _thrustTimer;    // remaining ticks of main thruster burn
    hidden var _smoothAx;       // smoothed accelerometer X

    // Fuel
    hidden var _fuel;

    // Terrain — ML_SEGS+1 vertices
    hidden var _terrX;
    hidden var _terrY;
    hidden var _padSeg;         // index of the flat landing-pad segment

    // Progress
    hidden var _level;
    hidden var _best;
    hidden var _resultTick;
    hidden var _crashFuel;      // true when crash was caused by empty fuel

    // Starfield (fixed per session)
    hidden var _starX;
    hidden var _starY;

    // ── Lander geometry constants (pixels) ─────────────────────────────────
    hidden var HW;   // hull half-width
    hidden var HH;   // hull height
    hidden var LH;   // leg height below hull bottom → total lander height = HH + LH

    // ─────────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        accelX = 0; accelY = 0; accelZ = 0;
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        // Scale lander to screen: reference is 260px
        var sc = _w.toFloat() / 260.0;
        HW = (8.0  * sc + 0.5).toNumber();   // hull half-width
        HH = (8.0  * sc + 0.5).toNumber();   // hull height
        LH = (5.0  * sc + 0.5).toNumber();   // leg height

        Math.srand(Time.now().value());
        _tick = 0;
        _gs = MS_MENU;
        _smoothAx = 0.0;
        _thrustTimer = 0;
        _posX = 0.0; _posY = 0.0;
        _velX = 0.0; _velY = 0.0;
        _fuel = ML_FUEL_MAX;
        _level = 1; _resultTick = 0; _crashFuel = false;

        var bs = Application.Storage.getValue("moonBest");
        _best = (bs != null) ? bs : 0;

        _terrX = new [ML_SEGS + 1];
        _terrY = new [ML_SEGS + 1];
        for (var i = 0; i <= ML_SEGS; i++) { _terrX[i] = 0; _terrY[i] = 0; }
        _padSeg = 0;

        // 20 random stars (Y within upper 60% of screen below HUD)
        _starX = new [20]; _starY = new [20];
        for (var i = 0; i < 20; i++) {
            _starX[i] = (Math.rand().abs() % _w).toNumber();
            _starY[i] = 24 + (Math.rand().abs() % (_h * 58 / 100)).toNumber();
        }
    }

    // ── Level start ──────────────────────────────────────────────────────────
    hidden function startLevel() {
        // Random horizontal start, always near top
        var xRange = _w / 2;
        _posX = (_w / 4 + (Math.rand().abs() % xRange).toNumber()).toFloat();
        _posY = 28.0;
        _velX = ((Math.rand().abs() % 5).toNumber() - 2).toFloat() * 0.12;
        _velY = 0.15;
        _thrustTimer = 0;
        _resultTick = 0; _crashFuel = false;

        // Fuel decreases each level
        var f = ML_FUEL_MAX - (_level - 1) * 70;
        if (f < 260) { f = 260; }
        _fuel = f;

        generateTerrain();
        _gs = MS_PLAY;
    }

    // ── Terrain generation ───────────────────────────────────────────────────
    hidden function generateTerrain() {
        // Pad segment: avoid very first and very last segment
        _padSeg = 1 + (Math.rand().abs() % (ML_SEGS - 2)).toNumber();

        // Evenly spaced X vertices
        var segW = _w / ML_SEGS;
        for (var i = 0; i <= ML_SEGS; i++) { _terrX[i] = i * segW; }
        _terrX[ML_SEGS] = _w;   // snap right edge

        // Bounds: terrain lives in the lower ~40% of the play area
        var playTop = _h * 47 / 100;
        var playBot = _h - 12;

        // Roughness increases with level
        var rough = 12 + _level * 4;
        if (rough > 52) { rough = 52; }

        // Bounded random walk for heights
        var curY = _h * 65 / 100;
        for (var i = 0; i <= ML_SEGS; i++) {
            var step = (Math.rand().abs() % (rough * 2 + 1)).toNumber() - rough;
            curY += step;
            if (curY < playTop) { curY = playTop; }
            if (curY > playBot) { curY = playBot; }
            _terrY[i] = curY;
        }

        // Override pad segment to be perfectly flat
        var padY = _terrY[_padSeg];
        if (padY < _h * 52 / 100) { padY = _h * 52 / 100; }
        if (padY > playBot - 5)    { padY = playBot - 5; }
        _terrY[_padSeg]     = padY;
        _terrY[_padSeg + 1] = padY;
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 50, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    // ── Game loop ─────────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        if (_gs == MS_PLAY) {
            update();
        } else {
            _resultTick++;
        }
        WatchUi.requestUpdate();
    }

    hidden function update() {
        // ── Accelerometer smoothing (heavy smooth = gentle response)
        _smoothAx = _smoothAx * 0.82 + accelX.toFloat() * 0.18;

        // ── Gravity (increases slightly with level)
        var grav = 0.036 + (_level - 1).toFloat() * 0.003;
        if (grav > 0.070) { grav = 0.070; }
        _velY += grav;

        // ── Main thruster (upward impulse, fuel-gated)
        if (_thrustTimer > 0) {
            _thrustTimer--;
            if (_fuel > 0) {
                _velY -= 0.105;
                _fuel -= 3;
                if (_fuel < 0) { _fuel = 0; }
            }
        }

        // ── Side thrusters from accelerometer X tilt
        var deadzone = 280.0;
        var ax = _smoothAx;
        if (ax > deadzone) {
            var force = (ax - deadzone) / 14000.0;
            _velX += force;
            if (_fuel > 0) { _fuel -= 1; if (_fuel < 0) { _fuel = 0; } }
        } else if (ax < -deadzone) {
            var force2 = (ax + deadzone) / 14000.0;
            _velX += force2;
            if (_fuel > 0) { _fuel -= 1; if (_fuel < 0) { _fuel = 0; } }
        }

        // ── Very slight air drag
        _velX = _velX * 0.993;

        // ── Integrate
        _posX += _velX;
        _posY += _velY;

        // ── Horizontal wrap
        if (_posX < -HW.toFloat()) { _posX = _w.toFloat() + HW.toFloat(); }
        if (_posX > _w.toFloat() + HW.toFloat()) { _posX = -HW.toFloat(); }

        // ── Top boundary
        if (_posY < 24.0) {
            _posY = 24.0;
            if (_velY < 0.0) { _velY = 0.0; }
        }

        // ── Terrain collision
        checkLanding();
    }

    hidden function checkLanding() {
        var lx   = _posX.toNumber();
        var botY = _posY.toNumber() + HH + LH;   // bottom of landing legs

        for (var i = 0; i < ML_SEGS; i++) {
            var tx1 = _terrX[i]; var tx2 = _terrX[i + 1];
            // Quick horizontal cull
            if (lx + HW < tx1 || lx - HW > tx2) { continue; }

            var ty1 = _terrY[i]; var ty2 = _terrY[i + 1];
            var sw = tx2 - tx1;
            if (sw <= 0) { continue; }

            // Interpolate terrain height under lander centre
            var frac = (lx - tx1).toFloat() / sw.toFloat();
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
            var terrH = ty1 + ((ty2 - ty1).toFloat() * frac).toNumber();

            if (botY >= terrH) {
                var vDown = _velY;
                var vSide = _velX; if (vSide < 0.0) { vSide = -vSide; }
                var onPad = (i == _padSeg);

                // Allowable speeds tighten each level
                var maxV = 1.60 - (_level - 1).toFloat() * 0.08;
                if (maxV < 0.70) { maxV = 0.70; }

                if (onPad && vDown < maxV && vSide < 0.55) {
                    // ── SOFT LANDING ─────────────────────────────────────────
                    _posY = (terrH - HH - LH).toFloat();
                    _velX = 0.0; _velY = 0.0;
                    _thrustTimer = 0;
                    _gs = MS_WIN;
                    if (_level > _best) {
                        _best = _level;
                        Application.Storage.setValue("moonBest", _best);
                    }
                    doVibe(1);
                } else {
                    // ── CRASH ─────────────────────────────────────────────────
                    _crashFuel = (_fuel <= 0);
                    _gs = MS_CRASH;
                    doVibe(2);
                }
                return;
            }
        }
    }

    // ── Input API (called from delegate) ─────────────────────────────────────
    function doAction() {
        if (_gs == MS_MENU) {
            _level = 1; startLevel();
        } else if (_gs == MS_PLAY) {
            // Each press gives ~350 ms of thrust
            if (_thrustTimer < 7) { _thrustTimer = 7; }
        } else if (_gs == MS_WIN && _resultTick > 14) {
            _level++;
            startLevel();
        } else if (_gs == MS_CRASH && _resultTick > 14) {
            startLevel();
        }
    }

    hidden function doVibe(pat) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(
                    80, (pat == 1) ? 50 : 220)]);
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  RENDERING
    // ═════════════════════════════════════════════════════════════════════════

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        dc.setColor(0x000814, 0x000814);
        dc.clear();

        if (_gs == MS_MENU) { drawMenu(dc); return; }

        drawStars(dc);
        drawTerrain(dc);

        if (_gs == MS_CRASH) {
            drawExplosion(dc);
        } else {
            drawLander(dc);
        }

        drawHUD(dc);

        if (_gs == MS_WIN)   { drawOverlay(dc, true); }
        if (_gs == MS_CRASH) { drawOverlay(dc, false); }
    }

    // ── Stars ─────────────────────────────────────────────────────────────────
    hidden function drawStars(dc) {
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 20; i++) {
            var big = (i % 5 == _tick % 5);
            var sz  = big ? 2 : 1;
            dc.fillRectangle(_starX[i], _starY[i], sz, sz);
        }
    }

    // ── HUD ──────────────────────────────────────────────────────────────────
    hidden function drawHUD(dc) {
        dc.setColor(0x030A14, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, 22);

        // Level (left)
        dc.setColor(0x6688AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 3, Graphics.FONT_XTINY, "Lv" + _level, Graphics.TEXT_JUSTIFY_LEFT);

        // Fuel bar (centre)
        var pct = _fuel.toFloat() / ML_FUEL_MAX.toFloat();
        if (pct > 1.0) { pct = 1.0; }
        var bw = _w * 38 / 100;
        var bx = (_w - bw) / 2;
        dc.setColor(0x081508, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, 7, bw, 8);
        var fc = (pct > 0.4) ? 0x44FF88 : ((pct > 0.2) ? 0xFFDD22 : 0xFF4433);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, 7, (bw.toFloat() * pct).toNumber(), 8);
        dc.setColor(0x1A3A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(bx, 7, bw, 8);

        // Vertical speed (right) — colour-coded: green=safe, yellow=risky, red=fatal
        var vy = _velY;
        var vc = (vy < 1.2) ? 0x44FF88 : ((vy < 2.2) ? 0xFFDD22 : 0xFF4433);
        dc.setColor(vc, Graphics.COLOR_TRANSPARENT);
        var vy10 = (vy * 10.0 + 0.5).toNumber();
        if (vy10 < 0) { vy10 = 0; }
        dc.drawText(_w - 4, 3, Graphics.FONT_XTINY,
            (vy10 / 10) + "." + (vy10 % 10), Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ── Terrain ───────────────────────────────────────────────────────────────
    hidden function drawTerrain(dc) {
        for (var i = 0; i < ML_SEGS; i++) {
            var x1 = _terrX[i]; var y1 = _terrY[i];
            var x2 = _terrX[i + 1]; var y2 = _terrY[i + 1];

            // Fill segment trapezoid to screen bottom
            if (i == _padSeg) {
                dc.setColor(0x556655, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x363636, Graphics.COLOR_TRANSPARENT);
            }
            dc.fillPolygon([[x1, y1], [x2, y2], [x2, _h], [x1, _h]]);

            // Surface line
            if (i == _padSeg) {
                dc.setColor(0x88FF88, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x707070, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawLine(x1, y1, x2, y2);
        }

        // Landing pad marker poles (yellow) + blinking lights
        var px1 = _terrX[_padSeg];
        var px2 = _terrX[_padSeg + 1];
        var py  = _terrY[_padSeg];
        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(px1, py - 8, px1, py);
        dc.drawLine(px2, py - 8, px2, py);
        if (_tick % 8 < 4) {
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px1 - 1, py - 10, 3, 3);
            dc.fillRectangle(px2 - 1, py - 10, 3, 3);
        }
    }

    // ── Lander ────────────────────────────────────────────────────────────────
    hidden function drawLander(dc) {
        var lx = _posX.toNumber();
        var ly = _posY.toNumber();

        // Hull body
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - HW, ly, HW * 2, HH);
        // Top highlight
        dc.setColor(0xEEF4FF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(lx - HW, ly, lx + HW, ly);

        // Cockpit window
        dc.setColor(0x1144AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - 3, ly + 1, 6, HH - 2);
        dc.setColor(0x88CCFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - 2, ly + 1, 3, 2);

        // Antenna stubs on top corners
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(lx - HW, ly + 2, lx - HW - 2, ly - 1);
        dc.drawLine(lx + HW, ly + 2, lx + HW + 2, ly - 1);

        // Landing legs
        var legOut = HW + 4;
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(lx - HW + 2, ly + HH, lx - legOut, ly + HH + LH - 1);
        dc.drawLine(lx + HW - 2, ly + HH, lx + legOut, ly + HH + LH - 1);
        // Feet pads
        dc.drawLine(lx - legOut - 2, ly + HH + LH, lx - legOut + 2, ly + HH + LH);
        dc.drawLine(lx + legOut - 2, ly + HH + LH, lx + legOut + 2, ly + HH + LH);

        // Main thruster flame
        if (_thrustTimer > 0) {
            var fh = 3 + (_tick % 4);
            dc.setColor(0xFF6600, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[lx - 3, ly + HH], [lx + 3, ly + HH], [lx, ly + HH + fh]]);
            dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lx - 2, ly + HH, 4, 2);
        }

        // Side thruster puffs
        var ax = _smoothAx;
        if (ax > 280.0) {
            dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(lx - HW - 1, ly + HH / 2, lx - HW - 5, ly + HH / 2);
        } else if (ax < -280.0) {
            dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(lx + HW + 1, ly + HH / 2, lx + HW + 5, ly + HH / 2);
        }
    }

    // ── Explosion ─────────────────────────────────────────────────────────────
    hidden function drawExplosion(dc) {
        var lx = _posX.toNumber();
        var ly = _posY.toNumber() + HH / 2;
        var r = 3 + _resultTick * 2;
        if (r > 34) { r = 34; }
        dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lx, ly, r);
        dc.setColor(0xFF9922, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lx, ly, r * 2 / 3);
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lx, ly, r / 3 + 1);
    }

    // ── Win / Crash overlay ───────────────────────────────────────────────────
    hidden function drawOverlay(dc, won) {
        if (won) {
            dc.setColor(0x33FF77, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 27 / 100, Graphics.FONT_MEDIUM,
                "LANDED!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 43 / 100, Graphics.FONT_XTINY,
                "Level " + _level + " clear", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x557799, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 53 / 100, Graphics.FONT_XTINY,
                "Fuel left: " + _fuel, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 27 / 100, Graphics.FONT_MEDIUM,
                _crashFuel ? "NO FUEL!" : "CRASH!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 43 / 100, Graphics.FONT_XTINY,
                _crashFuel ? "Fuel exhausted" : "Too fast or off pad",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(_w / 2, _h * 53 / 100, Graphics.FONT_XTINY,
                "Level " + _level, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_resultTick > 14) {
            var c1 = won ? 0x44AAFF : 0xFF8844;
            var c2 = won ? 0x2277CC : 0xCC6622;
            dc.setColor((_tick % 8 < 4) ? c1 : c2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 70 / 100, Graphics.FONT_XTINY,
                won ? "Tap for next level" : "Tap to retry",
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Menu screen ───────────────────────────────────────────────────────────
    hidden function drawMenu(dc) {
        // Stars
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 20; i++) {
            dc.fillRectangle(_starX[i], _starY[i], 2, 2);
        }

        // Earth (upper-right)
        dc.setColor(0x1133AA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 82 / 100, _h * 13 / 100, 22);
        dc.setColor(0x2255CC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 82 / 100, _h * 13 / 100, 20);
        dc.setColor(0x44AA33, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 76 / 100, _h * 9 / 100, 10, 7);
        dc.fillRectangle(_w * 84 / 100, _h * 16 / 100, 8, 5);
        dc.setColor(0xEEEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 78 / 100, _h * 7 / 100, 14, 3);

        // Moon surface at bottom
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h * 73 / 100, _w, _h);
        dc.setColor(0x5A5A5A, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, _h * 73 / 100, _w, _h * 73 / 100);

        // Craters
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 17 / 100, _h * 74 / 100, 12);
        dc.fillCircle(_w * 56 / 100, _h * 74 / 100, 9);
        dc.fillCircle(_w * 83 / 100, _h * 75 / 100, 15);

        // Landing pad on surface
        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w * 40 / 100, _h * 72 / 100, _w * 18 / 100, 3);
        dc.drawLine(_w * 40 / 100, _h * 69 / 100, _w * 40 / 100, _h * 72 / 100);
        dc.drawLine(_w * 58 / 100, _h * 69 / 100, _w * 58 / 100, _h * 72 / 100);

        // Lander hovering with tiny thruster flicker
        var lx = _w * 49 / 100;
        var ly = _h * 56 / 100 + ((_tick / 5) % 3);
        drawMenuLander(dc, lx, ly);

        // Title
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2 + 1, _h * 4 / 100 + 1, Graphics.FONT_MEDIUM,
            "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 4 / 100, Graphics.FONT_MEDIUM,
            "BITOCHI", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 16 / 100, Graphics.FONT_LARGE,
            "MOON", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88CCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 29 / 100, Graphics.FONT_SMALL,
            "LANDER", Graphics.TEXT_JUSTIFY_CENTER);

        // Controls hint
        dc.setColor(0x3A5060, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 43 / 100, Graphics.FONT_XTINY,
            "Tilt: side jets", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 52 / 100, Graphics.FONT_XTINY,
            "TAP: main thruster", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 61 / 100, Graphics.FONT_XTINY,
            "Land softly on flat pad", Graphics.TEXT_JUSTIFY_CENTER);

        // Best
        if (_best > 0) {
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 82 / 100, Graphics.FONT_XTINY,
                "BEST: Level " + _best, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Tap prompt (blinks)
        dc.setColor((_tick % 10 < 5) ? 0xFFDD22 : 0xAA9900, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 91 / 100, Graphics.FONT_XTINY,
            "Tap to launch!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawMenuLander(dc, lx, ly) {
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - HW, ly, HW * 2, HH);
        dc.setColor(0x1144AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - 3, ly + 1, 6, HH - 2);
        var legOut = HW + 4;
        dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(lx - HW + 2, ly + HH, lx - legOut, ly + HH + LH - 1);
        dc.drawLine(lx + HW - 2, ly + HH, lx + legOut, ly + HH + LH - 1);
        dc.drawLine(lx - legOut - 2, ly + HH + LH, lx - legOut + 2, ly + HH + LH);
        dc.drawLine(lx + legOut - 2, ly + HH + LH, lx + legOut + 2, ly + HH + LH);
        // Gentle thruster flicker
        if (_tick % 6 < 4) {
            dc.setColor(0xFF6600, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[lx - 3, ly + HH], [lx + 3, ly + HH], [lx, ly + HH + 4]]);
            dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(lx - 2, ly + HH, 4, 2);
        }
    }
}
