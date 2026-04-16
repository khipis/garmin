using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Attention;

const DS_MAIN  = 0;
const DS_GEAR  = 1;
const DS_GDONE = 2;
const DS_DISCL = 3;
const DS_EMER  = 4;
const DS_EDONE = 5;

const GEAR_N = 8;
const EMER_N = 6;

class DiveSafetyView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tk; hidden var _gs;

    hidden var _mSel;   // main menu: 0=gear 1=emergency
    hidden var _step;   // current step in active flow
    hidden var _stTk;   // tick when step entered

    // Gear check data
    hidden var _gN;     // names
    hidden var _gS;     // subtexts

    // Emergency data
    hidden var _eL1;    // action verb
    hidden var _eL2;    // object
    hidden var _eS;     // instruction

    function initialize() {
        View.initialize();
        _tk = 0; _gs = DS_MAIN;
        _mSel = 0; _step = 0; _stTk = 0;
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;

        _gN = ["MASK", "FINS", "BCD", "REGULATOR",
               "TANK", "WEIGHTS", "COMPUTER", "BUDDY"];
        _gS = ["Clean, no fog, strap OK",
               "Fit secure, straps tight",
               "Inflate + deflate test",
               "Breathe test, octo check",
               "Check PSI/bar reading",
               "Correct amount, secure",
               "Battery, settings, mode",
               "Review all together"];

        _eL1 = ["CHECK", "CALL", "CHECK", "RESCUE", "BEGIN", "DO NOT"];
        _eL2 = ["RESPONSE", "FOR HELP", "BREATHING", "BREATHING", "CPR", "STOP"];
        _eS  = ["Tap shoulder. Shout.",
                "Dial 112/911. Alert.",
                "Look. Listen. Feel. 10s.",
                "If trained: 5 breaths.",
                "If trained: 30:2 ratio.",
                "Continue until EMS."];

        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 200, true);
    }

    function onLayout(dc) { _w = dc.getWidth(); _h = dc.getHeight(); }

    function onTick() as Void { _tk++; WatchUi.requestUpdate(); }

    // ─── Public Input ───────────────────────────────────────────────────────────

    function doSelect() {
        if (_gs == DS_MAIN) {
            if (_mSel == 0) {
                _gs = DS_GEAR; _step = 0; _stTk = _tk; _buzz(30);
            } else {
                _gs = DS_DISCL; _stTk = _tk;
            }
            return;
        }
        if (_gs == DS_GEAR) {
            _step++; _stTk = _tk;
            if (_step >= GEAR_N) { _gs = DS_GDONE; _buzz(100); }
            else { _buzz(30); }
            return;
        }
        if (_gs == DS_GDONE || _gs == DS_EDONE) { _gs = DS_MAIN; return; }
        if (_gs == DS_DISCL) {
            _gs = DS_EMER; _step = 0; _stTk = _tk; _buzz(80); return;
        }
        if (_gs == DS_EMER) {
            _step++; _stTk = _tk;
            if (_step >= EMER_N) { _gs = DS_EDONE; _buzz(100); }
            else { _buzz(50); }
            return;
        }
    }

    function doBack() {
        if (_gs == DS_MAIN) { return false; }
        if (_gs == DS_GEAR) {
            if (_step > 0) { _step--; _stTk = _tk; return true; }
            _gs = DS_MAIN; return true;
        }
        if (_gs == DS_EMER) {
            if (_step > 0) { _step--; _stTk = _tk; return true; }
            _gs = DS_MAIN; return true;
        }
        _gs = DS_MAIN; return true;
    }

    function doUp()   { if (_gs == DS_MAIN) { _mSel = 1 - _mSel; } }
    function doDown() { if (_gs == DS_MAIN) { _mSel = 1 - _mSel; } }

    function doTap(tx, ty) {
        if (_gs == DS_MAIN) {
            _mSel = (ty < _h / 2) ? 0 : 1;
        }
        doSelect();
    }

    hidden function _buzz(dur) {
        if (Attention has :vibrate) {
            try { Attention.vibrate([new Attention.VibeProfile(50, dur)]); }
            catch (e) {}
        }
    }

    // ─── Rendering ──────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth() * 9 / 10; _h = dc.getHeight() * 9 / 10;
        if      (_gs == DS_MAIN)  { _drMain(dc); }
        else if (_gs == DS_GEAR)  { _drGear(dc); }
        else if (_gs == DS_GDONE) { _drGDone(dc); }
        else if (_gs == DS_DISCL) { _drDiscl(dc); }
        else if (_gs == DS_EMER)  { _drEmer(dc); }
        else                      { _drEDone(dc); }
    }

    // ─── Main Menu ──────────────────────────────────────────────────────────────

    hidden function _drMain(dc) {
        dc.setColor(0x000000, 0x000000); dc.clear();

        var titleY = _h * 4 / 100;
        dc.setColor(0x0088CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, titleY, Graphics.FONT_SMALL,
            "DIVE SAFETY", Graphics.TEXT_JUSTIFY_CENTER);

        var fTit = dc.getFontHeight(Graphics.FONT_SMALL);
        var subY = titleY + fTit + _h * 1 / 100;
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, subY, Graphics.FONT_XTINY,
            "TOOLKIT", Graphics.TEXT_JUSTIFY_CENTER);

        var fSm = dc.getFontHeight(Graphics.FONT_SMALL);
        var gap = _h * 3 / 100;
        var pairH = fSm + gap + fSm;
        var headBottom = subY + dc.getFontHeight(Graphics.FONT_XTINY) + _h * 4 / 100;
        var hintTop = _h * 88 / 100;
        var midY = headBottom + (hintTop - headBottom - pairH) / 2;
        var y1 = midY;
        var y2 = midY + fSm + gap;

        dc.setColor(_mSel == 0 ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y1, Graphics.FONT_SMALL,
            "GEAR CHECK", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_mSel == 1 ? 0xFF4444 : 0x2A1111, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y2, Graphics.FONT_SMALL,
            "EMERGENCY", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 91 / 100, Graphics.FONT_XTINY,
            "UP/DN select  SEL enter", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ─── Gear Check Step ────────────────────────────────────────────────────────

    hidden function _drGear(dc) {
        dc.setColor(0x060E16, 0x060E16); dc.clear();
        var age = _tk - _stTk;

        // Step counter
        dc.setColor(0x003355, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*4/100, Graphics.FONT_XTINY,
            (_step+1) + " / " + GEAR_N, Graphics.TEXT_JUSTIFY_CENTER);

        // Gear icon
        var icx = _w / 2;
        var icy = _h * 26 / 100;
        var ics = _w / 6;
        dc.setColor(0x00AAAA, Graphics.COLOR_TRANSPARENT);
        _drGIcon(dc, _step, icx, icy, ics);

        // Expanding pulse ring on step entry
        if (age < 4) {
            dc.setColor(0x003344, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(icx, icy, ics + 4 + age * 6);
        }

        // Item name with fade-in
        var nc = 0xFFFFFF;
        if (age == 0) { nc = 0x444444; }
        else if (age == 1) { nc = 0xAAAAAA; }
        dc.setColor(nc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*44/100, Graphics.FONT_MEDIUM,
            _gN[_step], Graphics.TEXT_JUSTIFY_CENTER);

        // Sub text
        dc.setColor(0x4488AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*60/100, Graphics.FONT_XTINY,
            _gS[_step], Graphics.TEXT_JUSTIFY_CENTER);

        // Checkmark appears after delay
        if (age >= 2) {
            _drChk(dc, _w/2, _h*74/100, _w/12, 0x00CC44);
        }

        // Progress bar
        var bH = _h * 15 / 1000; if (bH < 4) { bH = 4; }
        var bY = _h - bH - _h * 3 / 100;
        var bW = _w * 60 / 100;
        var bX = (_w - bW) / 2;
        dc.setColor(0x0A1A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bX, bY, bW, bH, 2);
        dc.setColor(0x00AAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bX, bY, bW * (_step + 1) / GEAR_N, bH, 2);

        // Hint
        dc.setColor(0x1A2A3A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*86/100, Graphics.FONT_XTINY,
            "SEL \u2192 next", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ─── Gear Done ──────────────────────────────────────────────────────────────

    hidden function _drGDone(dc) {
        dc.setColor(0x060E16, 0x060E16); dc.clear();

        var gc = (_tk % 8 < 4) ? 0x00CC44 : 0x00AA33;
        _drChk(dc, _w/2, _h*26/100, _w/6, gc);

        dc.setColor(0x00CC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*46/100, Graphics.FONT_LARGE,
            "ALL CLEAR", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x4488AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*64/100, Graphics.FONT_XTINY,
            GEAR_N + "/" + GEAR_N + " checked", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*78/100, Graphics.FONT_XTINY,
            "Tap to return", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ─── Disclaimer ─────────────────────────────────────────────────────────────

    hidden function _drDiscl(dc) {
        dc.setColor(0x000000, 0x000000); dc.clear();

        // Warning header
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        _drTriangle(dc, _w/2, _h*10/100, _w/14);
        dc.drawText(_w/2, _h*18/100, Graphics.FONT_SMALL,
            "WARNING", Graphics.TEXT_JUSTIFY_CENTER);

        // Disclaimer lines
        var f = Graphics.FONT_XTINY;
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*32/100, f,
            "REMINDER AID ONLY", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*42/100, f,
            "Not medical advice.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w/2, _h*50/100, f,
            "Not CPR training.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w/2, _h*58/100, f,
            "Always follow certified", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w/2, _h*66/100, f,
            "rescue procedures.", Graphics.TEXT_JUSTIFY_CENTER);

        // Blinking continue
        var pc = (_tk % 6 < 3) ? 0xFF4444 : 0xAA2222;
        dc.setColor(pc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*82/100, Graphics.FONT_SMALL,
            "SEL \u2192 continue", Graphics.TEXT_JUSTIFY_CENTER);

        // Red borders
        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, 2);
        dc.fillRectangle(0, _h - 2, _w, 2);
    }

    // ─── Emergency Step ─────────────────────────────────────────────────────────

    hidden function _drEmer(dc) {
        // Red pulse background
        var p = _tk % 16;
        var t = p < 8 ? p : 16 - p;
        var bg = t * 3;
        dc.setColor(bg * 0x10000, bg * 0x10000); dc.clear();

        var age = _tk - _stTk;

        // Step counter
        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*3/100, Graphics.FONT_XTINY,
            "STEP " + (_step+1) + " / " + EMER_N, Graphics.TEXT_JUSTIFY_CENTER);

        // Emergency icon
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        _drEIcon(dc, _step, _w/2, _h*18/100, _w/8);

        // Action verb — instant fade-in
        var tc = (age == 0) ? 0x888888 : 0xFFFFFF;
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*32/100, Graphics.FONT_LARGE,
            _eL1[_step], Graphics.TEXT_JUSTIFY_CENTER);

        // Object
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*50/100, Graphics.FONT_MEDIUM,
            _eL2[_step], Graphics.TEXT_JUSTIFY_CENTER);

        // Instruction
        dc.setColor(0xAA5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h*66/100, Graphics.FONT_XTINY,
            _eS[_step], Graphics.TEXT_JUSTIFY_CENTER);

        // Next hint
        if (age >= 2) {
            dc.setColor(0x442222, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _h*82/100, Graphics.FONT_XTINY,
                _step < EMER_N - 1 ? "SEL \u2192 next" : "SEL \u2192 done",
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Red border accent
        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, 2);
        dc.fillRectangle(0, _h - 2, _w, 2);
    }

    // ─── Emergency Done ─────────────────────────────────────────────────────────

    hidden function _drEDone(dc) {
        dc.setColor(0x000000, 0x000000); dc.clear();

        // Pulsing medical cross
        var cx = _w / 2;
        var s = _w / 7;
        var my = _h * 18 / 100;
        var cr = (_tk % 8 < 4) ? 0xFF4444 : 0xCC2222;
        dc.setColor(cr, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - s/6, my, s/3, s);
        dc.fillRectangle(cx - s/2, my + s/3, s, s/3);

        var tc = (_tk % 8 < 4) ? 0xFFFFFF : 0xDDDDDD;
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h*42/100, Graphics.FONT_MEDIUM,
            "STAY WITH", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, _h*54/100, Graphics.FONT_MEDIUM,
            "PATIENT", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAA3333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h*70/100, Graphics.FONT_XTINY,
            "Until EMS arrives", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h*84/100, Graphics.FONT_XTINY,
            "Tap to return", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, 2);
        dc.fillRectangle(0, _h - 2, _w, 2);
    }

    // ─── Gear Icons (geometric line art) ────────────────────────────────────────

    hidden function _drGIcon(dc, step, cx, cy, s) {
        if (step == 0) {
            // Mask: two lenses + bridge + strap
            var r = s * 3 / 8;
            dc.drawCircle(cx - s*4/10, cy, r);
            dc.drawCircle(cx + s*4/10, cy, r);
            dc.drawLine(cx - s/10, cy - r/3, cx + s/10, cy - r/3);
            dc.drawLine(cx - s, cy, cx - s*7/10, cy);
            dc.drawLine(cx + s*7/10, cy, cx + s, cy);
        } else if (step == 1) {
            // Fins: blade shape
            dc.fillPolygon([[cx - s/4, cy - s*4/10], [cx + s/4, cy - s*4/10],
                            [cx + s/2, cy + s*4/10], [cx - s/2, cy + s*4/10]]);
        } else if (step == 2) {
            // BCD: vest outline
            dc.drawRoundedRectangle(cx - s*3/10, cy - s*4/10,
                s*6/10, s*8/10, s/8);
            dc.drawLine(cx - s*3/10, cy - s/10, cx + s*3/10, cy - s/10);
            dc.fillCircle(cx, cy - s*5/10, s/10);
        } else if (step == 3) {
            // Regulator: demand valve + hose
            dc.drawCircle(cx, cy, s*3/10);
            dc.fillCircle(cx, cy, s/10);
            dc.drawLine(cx + s*3/10, cy, cx + s*7/10, cy - s*3/10);
            dc.drawCircle(cx + s*7/10, cy - s*3/10, s/8);
        } else if (step == 4) {
            // Tank: cylinder with valve
            dc.drawRoundedRectangle(cx - s*2/10, cy - s*3/10,
                s*4/10, s*7/10, s/10);
            dc.fillRoundedRectangle(cx - s/10, cy - s*4/10,
                s/5, s/10, 2);
        } else if (step == 5) {
            // Weights: belt blocks
            dc.fillRectangle(cx - s*4/10, cy - s/8, s*8/10, s/4);
            dc.drawRectangle(cx - s*4/10, cy - s/8, s*8/10, s/4);
            dc.drawLine(cx - s/8, cy - s/8, cx - s/8, cy + s/8);
            dc.drawLine(cx + s/8, cy - s/8, cx + s/8, cy + s/8);
        } else if (step == 6) {
            // Computer: screen device
            dc.drawRoundedRectangle(cx - s*3/10, cy - s*3/10,
                s*6/10, s*6/10, s/10);
            dc.fillRoundedRectangle(cx - s/5, cy - s/5,
                s*2/5, s*3/10, 2);
        } else {
            // Buddy: two divers
            dc.fillCircle(cx - s*3/10, cy - s*3/10, s/8);
            dc.drawLine(cx - s*3/10, cy - s/5, cx - s*3/10, cy + s/5);
            dc.drawLine(cx - s*5/10, cy, cx - s/10, cy);
            dc.fillCircle(cx + s*3/10, cy - s*3/10, s/8);
            dc.drawLine(cx + s*3/10, cy - s/5, cx + s*3/10, cy + s/5);
            dc.drawLine(cx + s/10, cy, cx + s*5/10, cy);
            dc.drawLine(cx - s/10, cy - s/10, cx + s/10, cy - s/10);
        }
    }

    // ─── Emergency Icons ────────────────────────────────────────────────────────

    hidden function _drEIcon(dc, step, cx, cy, s) {
        if (step == 0) {
            // Eye: check response
            dc.drawCircle(cx, cy, s*4/10);
            dc.fillCircle(cx, cy, s/6);
        } else if (step == 1) {
            // Warning triangle: call help
            _drTriangle(dc, cx, cy - s/4, s*4/10);
            dc.fillCircle(cx, cy + s/10, 2);
            dc.drawLine(cx, cy - s*3/10, cx, cy);
        } else if (step == 2) {
            // Lungs: check breathing
            dc.drawCircle(cx - s/4, cy, s*3/10);
            dc.drawCircle(cx + s/4, cy, s*3/10);
            dc.drawLine(cx, cy - s*3/10, cx, cy + s/4);
        } else if (step == 3) {
            // Air flow: rescue breathing
            dc.drawCircle(cx, cy + s/8, s*3/10);
            dc.drawLine(cx, cy - s/4, cx, cy - s*5/10);
            dc.drawLine(cx - s/5, cy - s*4/10, cx, cy - s*5/10);
            dc.drawLine(cx + s/5, cy - s*4/10, cx, cy - s*5/10);
        } else if (step == 4) {
            // Medical cross: CPR
            dc.fillRectangle(cx - s/8, cy - s*4/10, s/4, s*8/10);
            dc.fillRectangle(cx - s*4/10, cy - s/8, s*8/10, s/4);
        } else {
            // Clock: continue
            dc.drawCircle(cx, cy, s*4/10);
            dc.drawLine(cx, cy, cx, cy - s*3/10);
            dc.drawLine(cx, cy, cx + s*2/10, cy + s/10);
        }
    }

    // ─── Drawing Helpers ────────────────────────────────────────────────────────

    hidden function _drChk(dc, cx, cy, s, col) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        for (var t = -1; t <= 1; t++) {
            dc.drawLine(cx - s/2, cy + t, cx - s/6, cy + s/3 + t);
            dc.drawLine(cx - s/6, cy + s/3 + t, cx + s/2, cy - s/3 + t);
        }
    }

    hidden function _drTriangle(dc, cx, cy, s) {
        dc.drawLine(cx, cy - s, cx - s, cy + s*2/3);
        dc.drawLine(cx - s, cy + s*2/3, cx + s, cy + s*2/3);
        dc.drawLine(cx + s, cy + s*2/3, cx, cy - s);
    }
}
