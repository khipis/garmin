// DiveView.mc
// ─────────────────────────────────────────────────────────────────────────────
// Dive Gas & Planning Toolkit — UI + state machine
// ─────────────────────────────────────────────────────────────────────────────

using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;
using Toybox.Application;

// ── App states ───────────────────────────────────────────────────────────────
enum {
    DV_DISC,    // safety disclaimer (first launch)
    DV_MENU,    // main menu
    DV_MOD,     // MOD / PO2 calculator
    DV_BMIX,    // Best Mix calculator
    DV_EAD,     // EAD calculator
    DV_SAC,     // SAC / Gas consumption
    DV_NDL      // NDL limit
}

const DC_BG      = 0x000000;
const DC_BLUE    = 0x0088CC;
const DC_DIM     = 0x333333;
const DC_DIMVAL  = 0x555555;
const DC_ACT_BG  = 0x0A1520;
const DC_ACT_LBL = 0x66AADD;
const DC_WHITE   = 0xFFFFFF;
const DC_GREEN   = 0x00CC44;
const DC_ORANGE  = 0xFFAA00;
const DC_RED     = 0xFF2222;
const DC_CYAN    = 0x44CCFF;
const DC_YELLOW  = 0xFFCC44;
const DC_DIV     = 0x111111;
const DC_HINT    = 0x222222;

// ─────────────────────────────────────────────────────────────────────────────

class DiveView extends WatchUi.View {

    var _state;

    hidden var _w;
    hidden var _h;
    hidden var _tick;
    hidden var _timer;
    hidden var _math;

    // Menu
    hidden var _menuSel;
    hidden var _menuItems;

    // Shared calculator fields (MOD, EAD share gas/depth selectors)
    hidden var _fo2Idx;   // FO2 preset index
    hidden var _depIdx;   // depth preset index
    hidden var _field;    // currently active input field

    // NDL has independent selectors so it can differ from MOD/EAD
    hidden var _ndlFo2;
    hidden var _ndlDep;

    // SAC — five independent selectors
    hidden var _sTank;
    hidden var _sStartP;
    hidden var _sEndP;
    hidden var _sTime;
    hidden var _sDep;

    // ── Init ─────────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        _math    = new DiveMath();
        var ds   = System.getDeviceSettings();
        _w       = ds.screenWidth;
        _h       = ds.screenHeight;
        _tick    = 0;
        _menuItems = ["MOD / PO2", "Best Mix", "EAD Calc", "Gas Usage", "NDL Limit", "About"];
        _menuSel = 0;

        // Default: Nitrox 32 at 20m
        _fo2Idx  = 1;   // Nitrox 32
        _depIdx  = 3;   // 20m
        _field   = 0;

        _ndlFo2  = 0;   // Air
        _ndlDep  = 4;   // 25m

        _sTank   = 1;   // 12L
        _sStartP = 5;   // 200 bar
        _sEndP   = 2;   // 50 bar
        _sTime   = 4;   // 30 min
        _sDep    = 3;   // 20m

        // First-launch: show disclaimer unless already accepted
        var ok = Application.Storage.getValue("diveAccept");
        _state = (ok == true) ? DV_MENU : DV_DISC;
    }

    // ── Timer ─────────────────────────────────────────────────────────────────

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 500, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _tick++;
        WatchUi.requestUpdate();
    }

    // ── Navigation (called by DiveDelegate) ───────────────────────────────────

    function doSelect() {
        if (_state == DV_DISC) {
            Application.Storage.setValue("diveAccept", true);
            _state = DV_MENU;
        } else if (_state == DV_MENU) {
            var map = [DV_MOD, DV_BMIX, DV_EAD, DV_SAC, DV_NDL];
            if (_menuSel < 5) {
                _state = map[_menuSel];
                _field = 0;
            } else {
                // "About" resets disclaimer
                Application.Storage.deleteValue("diveAccept");
                _state = DV_DISC;
            }
        } else {
            // Advance to next input field
            var mx = _maxField();
            if (_field < mx - 1) { _field++; }
        }
    }

    function doBack() {
        if (_state == DV_DISC) { return false; }
        if (_state == DV_MENU) { return false; }
        if (_field > 0) {
            _field--;
        } else {
            _state = DV_MENU;
            _field = 0;
        }
        return true;
    }

    function doUp() {
        if (_state == DV_MENU) {
            _menuSel = (_menuSel - 1 + 6) % 6;
        } else {
            _adjustField(-1);
        }
    }

    function doDown() {
        if (_state == DV_MENU) {
            _menuSel = (_menuSel + 1) % 6;
        } else {
            _adjustField(1);
        }
    }

    function doTap(x, y) {
        if (_state == DV_DISC) {
            doSelect();
            return;
        }
        if (_state == DV_MENU) {
            var sY  = _h * 26 / 100;
            var rH  = _h * 12 / 100;
            for (var i = 0; i < 6; i++) {
                var ry = sY + i * rH;
                if (y >= ry && y < ry + rH) {
                    _menuSel = i;
                    doSelect();
                    return;
                }
            }
            return;
        }
        // Tap upper half → decrement, lower half → increment
        if (y < _h / 2) { _adjustField(-1); }
        else             { _adjustField(1); }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    hidden function _maxField() {
        if (_state == DV_MOD)  { return 2; }
        if (_state == DV_BMIX) { return 1; }
        if (_state == DV_EAD)  { return 2; }
        if (_state == DV_SAC)  { return 5; }
        if (_state == DV_NDL)  { return 2; }
        return 1;
    }

    hidden function _adjustField(dir) {
        if (_state == DV_MOD || _state == DV_EAD) {
            if (_field == 0) {
                _fo2Idx = _cycle(_fo2Idx, dir, DIVE_FO2_VALS.size());
            } else {
                _depIdx = _cycle(_depIdx, dir, DIVE_DEPTHS.size());
            }
        } else if (_state == DV_BMIX) {
            _depIdx = _cycle(_depIdx, dir, DIVE_DEPTHS.size());
        } else if (_state == DV_NDL) {
            if (_field == 0) {
                _ndlFo2 = _cycle(_ndlFo2, dir, DIVE_FO2_VALS.size());
            } else {
                _ndlDep = _cycle(_ndlDep, dir, DIVE_DEPTHS.size());
            }
        } else if (_state == DV_SAC) {
            if      (_field == 0) { _sTank   = _cycle(_sTank,   dir, DIVE_TANKS.size()); }
            else if (_field == 1) { _sStartP = _cycle(_sStartP, dir, DIVE_STARTP.size()); }
            else if (_field == 2) { _sEndP   = _cycle(_sEndP,   dir, DIVE_ENDP.size()); }
            else if (_field == 3) { _sTime   = _cycle(_sTime,   dir, DIVE_TIMES.size()); }
            else                  { _sDep    = _cycle(_sDep,    dir, DIVE_DEPTHS.size()); }
        }
    }

    hidden function _cycle(idx, dir, sz) {
        return (idx + dir + sz) % sz;
    }

    // Format float to 2 decimal places: 1.44
    hidden function _f2(v) {
        var i  = v.toNumber();
        if (v < 0.0 && i == 0) { i = 0; }
        var dv = ((v - i.toFloat()).abs() * 100.0 + 0.5).toNumber();
        if (dv >= 100) { i++; dv = 0; }
        if (dv < 10)   { return i + ".0" + dv; }
        return i + "." + dv;
    }

    // Format float to 1 decimal place: 18.5
    hidden function _f1(v) {
        var i  = v.toNumber();
        if (v < 0.0 && i == 0) { i = 0; }
        var dv = ((v - i.toFloat()).abs() * 10.0 + 0.5).toNumber();
        if (dv >= 10) { i++; dv = 0; }
        return i + "." + dv;
    }

    // Safety colour for PO2
    hidden function _po2Color(po2) {
        if (po2 <= DIVE_PO2_WORK) { return DC_GREEN; }
        if (po2 <= DIVE_PO2_ABS)  { return DC_ORANGE; }
        return DC_RED;
    }

    // Draw a horizontal divider line
    hidden function _divider(dc, y) {
        dc.setColor(DC_DIV, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 10 / 100, y, _w * 90 / 100, y);
    }

    // Draw a labelled input row (active = dive-blue label + white value)
    hidden function _row(dc, y, label, value, active) {
        var rh = _h * 12 / 100;
        var mg = _w * 8 / 100;
        var fXH = dc.getFontHeight(Graphics.FONT_XTINY);
        var tY  = y + (rh - fXH) / 2;
        dc.setColor(active ? DC_BLUE : DC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mg + 6, tY, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(active ? DC_WHITE : DC_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - mg - 6, tY, Graphics.FONT_XTINY, value + (active ? " <>" : ""), Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Bottom hint line
    hidden function _hint(dc, txt) {
        dc.setColor(DC_HINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 91 / 100, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Screen title
    hidden function _title(dc, txt) {
        dc.setColor(DC_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 2 / 100, Graphics.FONT_SMALL, txt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Render dispatch ───────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth() * 9 / 10;
        _h = dc.getHeight() * 9 / 10;
        dc.setColor(DC_BG, DC_BG);
        dc.clear();

        if      (_state == DV_DISC) { _drawDisc(dc); }
        else if (_state == DV_MENU) { _drawMenu(dc); }
        else if (_state == DV_MOD)  { _drawMOD(dc); }
        else if (_state == DV_BMIX) { _drawBMix(dc); }
        else if (_state == DV_EAD)  { _drawEAD(dc); }
        else if (_state == DV_SAC)  { _drawSAC(dc); }
        else if (_state == DV_NDL)  { _drawNDL(dc); }
    }

    // ── DISCLAIMER ────────────────────────────────────────────────────────────

    hidden function _drawDisc(dc) {
        dc.setColor(DC_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 5 / 100, Graphics.FONT_LARGE, "!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(DC_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 20 / 100, Graphics.FONT_SMALL,  "DIVE PLANNING", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 31 / 100, Graphics.FONT_SMALL,  "TOOLKIT", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(DC_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 45 / 100, Graphics.FONT_XTINY, "NOT a dive computer.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 54 / 100, Graphics.FONT_XTINY, "Informational use only.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 63 / 100, Graphics.FONT_XTINY, "Follow your training.", Graphics.TEXT_JUSTIFY_CENTER);

        var blinkC = (_tick % 2 == 0) ? DC_CYAN : 0x1A5588;
        dc.setColor(blinkC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 80 / 100, Graphics.FONT_SMALL, "Tap to Accept", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── MAIN MENU ─────────────────────────────────────────────────────────────

    hidden function _drawMenu(dc) {
        dc.setColor(DC_BG, DC_BG);
        dc.clear();

        var titleY = _h * 3 / 100;
        dc.setColor(DC_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, titleY, Graphics.FONT_SMALL, "DIVE", Graphics.TEXT_JUSTIFY_CENTER);

        var fSm = dc.getFontHeight(Graphics.FONT_SMALL);
        var subY = titleY + fSm + _h * 1 / 100;
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, subY, Graphics.FONT_XTINY, "TOOLKIT", Graphics.TEXT_JUSTIFY_CENTER);

        var items = _menuItems;
        var fXt = dc.getFontHeight(Graphics.FONT_XTINY);
        var rH  = _h * 10 / 100; if (rH < fXt + 2) { rH = fXt + 2; }
        var headBottom = subY + dc.getFontHeight(Graphics.FONT_XTINY) + _h * 4 / 100;
        var sY = headBottom;

        for (var i = 0; i < items.size(); i++) {
            var y   = sY + i * rH;
            var sel = (i == _menuSel);
            dc.setColor(sel ? DC_WHITE : 0x444444, Graphics.COLOR_TRANSPARENT);
            var ty = y + (rH - fXt) / 2;
            dc.drawText(_w / 2, ty, Graphics.FONT_XTINY, items[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── MOD / PO2 ─────────────────────────────────────────────────────────────

    hidden function _drawMOD(dc) {
        _title(dc, "MOD / PO2");

        var y1 = _h * 17 / 100;
        var y2 = _h * 31 / 100;
        _row(dc, y1, "GAS",   DIVE_FO2_LBLS[_fo2Idx],      _field == 0);
        _row(dc, y2, "DEPTH", DIVE_DEPTHS[_depIdx] + "m",   _field == 1);

        _divider(dc, _h * 46 / 100);

        var fo2  = DIVE_FO2_VALS[_fo2Idx];
        var dep  = DIVE_DEPTHS[_depIdx];
        var po2  = _math.po2(fo2, dep);
        var modV = _math.mod(fo2, DIVE_PO2_WORK);
        var col  = _po2Color(po2);

        // Large PO2 value
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_NUMBER_HOT, _f2(po2), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(DC_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 71 / 100, Graphics.FONT_XTINY, "PO2  (ATA)", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 79 / 100, Graphics.FONT_SMALL, "MOD " + modV.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        var safeStr = (po2 <= DIVE_PO2_WORK) ? "SAFE" : ((po2 <= DIVE_PO2_ABS) ? "WARNING" : "DANGER");
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, safeStr, Graphics.TEXT_JUSTIFY_CENTER);

        _hint(dc, "UP/DN: change  SEL: next");
    }

    // ── BEST MIX ──────────────────────────────────────────────────────────────

    hidden function _drawBMix(dc) {
        _title(dc, "BEST MIX");

        _row(dc, _h * 17 / 100, "DEPTH", DIVE_DEPTHS[_depIdx] + "m", _field == 0);
        _divider(dc, _h * 32 / 100);

        var dep  = DIVE_DEPTHS[_depIdx];
        var fo2  = _math.bestMix(dep);
        var pct  = (fo2 * 100.0 + 0.5).toNumber();

        dc.setColor(0x44DDAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 34 / 100, Graphics.FONT_NUMBER_HOT, pct + "%", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(DC_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 63 / 100, Graphics.FONT_XTINY, "optimal FO2", Graphics.TEXT_JUSTIFY_CENTER);

        // Descriptive label
        var label;
        if      (pct <= 21) { label = "Air"; }
        else if (pct <= 32) { label = "Nitrox " + pct; }
        else if (pct <= 36) { label = "Nitrox " + pct; }
        else                { label = "Nitrox " + pct + " (enriched)"; }
        dc.setColor(DC_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 72 / 100, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);

        // MOD for this mix
        var modV = _math.mod(fo2, DIVE_PO2_WORK);
        dc.setColor(DC_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 82 / 100, Graphics.FONT_XTINY, "MOD " + modV.toNumber() + "m @ 1.4", Graphics.TEXT_JUSTIFY_CENTER);

        _hint(dc, "UP/DN: change depth");
    }

    // ── EAD ───────────────────────────────────────────────────────────────────

    hidden function _drawEAD(dc) {
        _title(dc, "EAD");

        var y1 = _h * 17 / 100;
        var y2 = _h * 31 / 100;
        _row(dc, y1, "GAS",   DIVE_FO2_LBLS[_fo2Idx],    _field == 0);
        _row(dc, y2, "DEPTH", DIVE_DEPTHS[_depIdx] + "m", _field == 1);

        _divider(dc, _h * 46 / 100);

        var fo2  = DIVE_FO2_VALS[_fo2Idx];
        var dep  = DIVE_DEPTHS[_depIdx];
        var eadV = _math.ead(dep, fo2);

        dc.setColor(DC_CYAN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_NUMBER_HOT, eadV.toNumber() + "m", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(DC_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 71 / 100, Graphics.FONT_XTINY, "equivalent air depth", Graphics.TEXT_JUSTIFY_CENTER);

        var benefit = dep - eadV.toNumber();
        if (benefit > 0) {
            dc.setColor(DC_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 80 / 100, Graphics.FONT_XTINY, "N2 benefit: +" + benefit + "m", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(DC_DIMVAL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 80 / 100, Graphics.FONT_XTINY, "same as air", Graphics.TEXT_JUSTIFY_CENTER);
        }

        _hint(dc, "UP/DN: change  SEL: next");
    }

    // ── SAC / GAS USAGE ───────────────────────────────────────────────────────

    hidden function _drawSAC(dc) {
        _title(dc, "GAS USAGE");

        var rH = _h * 11 / 100;
        var sY = _h * 16 / 100;

        _row(dc, sY + 0 * rH, "TANK",  DIVE_TANKS[_sTank]   + " L",   _field == 0);
        _row(dc, sY + 1 * rH, "START", DIVE_STARTP[_sStartP] + " bar", _field == 1);
        _row(dc, sY + 2 * rH, "END",   DIVE_ENDP[_sEndP]     + " bar", _field == 2);
        _row(dc, sY + 3 * rH, "TIME",  DIVE_TIMES[_sTime]    + " min", _field == 3);
        _row(dc, sY + 4 * rH, "DEPTH", DIVE_DEPTHS[_sDep]    + " m",   _field == 4);

        var divY = sY + 5 * rH + 2;
        _divider(dc, divY);

        var sacV = _math.sac(DIVE_TANKS[_sTank], DIVE_STARTP[_sStartP],
                             DIVE_ENDP[_sEndP], DIVE_TIMES[_sTime], DIVE_DEPTHS[_sDep]);

        dc.setColor(DC_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, divY + 4, Graphics.FONT_LARGE, _f1(sacV), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(DC_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, divY + _h * 14 / 100, Graphics.FONT_XTINY, "SAC  L/min", Graphics.TEXT_JUSTIFY_CENTER);

        _hint(dc, "UP/DN: change  SEL: next");
    }

    // ── NDL ───────────────────────────────────────────────────────────────────

    hidden function _drawNDL(dc) {
        _title(dc, "NDL LIMIT");

        var y1 = _h * 17 / 100;
        var y2 = _h * 31 / 100;
        _row(dc, y1, "GAS",   DIVE_FO2_LBLS[_ndlFo2],    _field == 0);
        _row(dc, y2, "DEPTH", DIVE_DEPTHS[_ndlDep] + "m", _field == 1);

        _divider(dc, _h * 46 / 100);

        var fo2  = DIVE_FO2_VALS[_ndlFo2];
        var dep  = DIVE_DEPTHS[_ndlDep];
        var ndlV = _math.ndl(dep, fo2);

        var col;
        if (ndlV >= 20.0)       { col = DC_GREEN; }
        else if (ndlV >= 10.0)  { col = DC_ORANGE; }
        else                    { col = DC_RED; }

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 48 / 100, Graphics.FONT_NUMBER_HOT, ndlV.toNumber() + "min", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(DC_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 71 / 100, Graphics.FONT_XTINY, "no-deco limit", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 80 / 100, Graphics.FONT_XTINY, "(PADI RDP est.)", Graphics.TEXT_JUSTIFY_CENTER);

        // Show EAD benefit note for nitrox
        if (fo2 > 0.21) {
            var airNdlV = _math.ndl(dep, 0.21);
            var extMin  = (ndlV - airNdlV).toNumber();
            if (extMin > 0) {
                dc.setColor(DC_GREEN, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, _h * 88 / 100, Graphics.FONT_XTINY, "+" + extMin + "min vs air", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        _hint(dc, "UP/DN: change  SEL: next");
    }
}
