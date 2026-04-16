// DiveGasBlenderView.mc
// ─────────────────────────────────────────────────────────────────────────────
// Dive Gas Blender — partial-pressure nitrox blending calculator
//
// Three tools:
//   PP Blend   — calculate O2 fill + air top-up pressures for a target nitrox mix
//   Mix Check  — verify actual blend achieved after filling
//   MOD Lookup — quick MOD / PO2 table for any FO2
//
// Design: same dark-blue palette as Dive Plan Toolkit for visual family.
// ─────────────────────────────────────────────────────────────────────────────

using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;
using Toybox.Application;

// ── States ────────────────────────────────────────────────────────────────────
enum {
    GB_DISC,   // safety disclaimer
    GB_MENU,   // main menu
    GB_PP,     // PP blending calculator
    GB_CHECK,  // mix verification
    GB_MOD     // MOD / PO2 lookup
}

// ── Preset tables ─────────────────────────────────────────────────────────────
const GB_FO2_VALS  = [0.21, 0.26, 0.27, 0.28, 0.29, 0.30, 0.31, 0.32, 0.34, 0.36, 0.40];
const GB_FO2_LBLS  = ["Air 21%", "26%", "27%", "28%", "29%", "30%", "31%", "Nitrox 32", "34%", "Nitrox 36", "40%"];

const GB_FILL_P    = [50, 80, 100, 120, 150, 160, 170, 180, 190, 200, 210, 220, 230, 232, 300];
const GB_START_P   = [0, 5, 10, 20, 30, 40, 50, 80, 100];
const GB_START_MIX = [0.21, 0.27, 0.28, 0.29, 0.30, 0.31, 0.32, 0.36];
const GB_START_LBL = ["Air 21%", "27%", "28%", "29%", "30%", "31%", "Nitrox 32", "Nitrox 36"];

const GB_BG      = 0x000000;
const GB_BLUE    = 0x0088CC;
const GB_DIM     = 0x333333;
const GB_DIMVAL  = 0x555555;
const GB_ACT_BG  = 0x0A1520;
const GB_ACT_LBL = 0x66AADD;
const GB_WHITE   = 0xFFFFFF;
const GB_GREEN   = 0x00CC44;
const GB_ORANGE  = 0xFFAA00;
const GB_RED     = 0xFF2222;
const GB_CYAN    = 0x44CCFF;
const GB_YELLOW  = 0xFFCC44;
const GB_DIV     = 0x111111;
const GB_HINT    = 0x222222;

// ─────────────────────────────────────────────────────────────────────────────

class DiveGasBlenderView extends WatchUi.View {

    var _state;

    hidden var _w;
    hidden var _h;
    hidden var _tick;
    hidden var _timer;

    // Menu
    hidden var _menuSel;
    hidden var _menuItems;

    // PP Blend inputs
    hidden var _ppFo2Idx;     // target FO2 preset index
    hidden var _ppFillIdx;    // target fill pressure
    hidden var _ppStartIdx;   // starting pressure in tank
    hidden var _ppStartMix;   // starting mix in tank

    // Mix Check inputs
    hidden var _chO2FillIdx;  // pressure after O2 fill step
    hidden var _chTotalIdx;   // final total fill pressure
    hidden var _chStartIdx;   // pressure before blending started
    hidden var _chStartMix;   // mix that was in tank before

    // MOD Lookup
    hidden var _modFo2Idx;

    // Active field within each calculator
    hidden var _field;

    // ── Init ─────────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        var ds   = System.getDeviceSettings();
        _w       = ds.screenWidth;
        _h       = ds.screenHeight;
        _tick    = 0;
        _menuItems = ["PP Blend", "Mix Check", "MOD Lookup", "About"];
        _menuSel = 0;
        _field   = 0;

        _ppFo2Idx   = 4;   // Nitrox 32
        _ppFillIdx  = 9;   // 200 bar
        _ppStartIdx = 0;   // 0 bar (empty)
        _ppStartMix = 0;   // Air

        _chO2FillIdx = 2;  // 30 bar
        _chTotalIdx  = 9;  // 200 bar
        _chStartIdx  = 0;  // 0 bar
        _chStartMix  = 0;  // Air

        _modFo2Idx = 4;    // Nitrox 32

        var ok = Application.Storage.getValue("gbAccept");
        _state = (ok == true) ? GB_MENU : GB_DISC;
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

    // ── Navigation ────────────────────────────────────────────────────────────

    function doSelect() {
        if (_state == GB_DISC) {
            Application.Storage.setValue("gbAccept", true);
            _state = GB_MENU;
        } else if (_state == GB_MENU) {
            var map = [GB_PP, GB_CHECK, GB_MOD];
            if (_menuSel < 3) { _state = map[_menuSel]; _field = 0; }
            else { Application.Storage.deleteValue("gbAccept"); _state = GB_DISC; }
        } else {
            var mx = _maxField();
            if (_field < mx - 1) { _field++; }
        }
    }

    function doBack() {
        if (_state == GB_DISC || _state == GB_MENU) { return false; }
        if (_field > 0) { _field--; } else { _state = GB_MENU; _field = 0; }
        return true;
    }

    function doUp() {
        if (_state == GB_MENU) { _menuSel = (_menuSel - 1 + 4) % 4; }
        else { _adjustField(-1); }
    }

    function doDown() {
        if (_state == GB_MENU) { _menuSel = (_menuSel + 1) % 4; }
        else { _adjustField(1); }
    }

    function doTap(x, y) {
        if (_state == GB_DISC) { doSelect(); return; }
        if (_state == GB_MENU) {
            var rH = _h * 13 / 100; if (rH < 22) { rH = 22; } if (rH > 34) { rH = 34; }
            var sY = (_h - 4 * rH) / 2;
            var minSY = _h * 22 / 100; if (sY < minSY) { sY = minSY; }
            for (var i = 0; i < 4; i++) {
                var ry = sY + i * rH;
                if (y >= ry && y < ry + rH) { _menuSel = i; doSelect(); return; }
            }
            return;
        }
        if (y < _h / 2) { _adjustField(-1); }
        else             { _adjustField(1); }
    }

    // ── Field helpers ─────────────────────────────────────────────────────────

    hidden function _maxField() {
        if (_state == GB_PP)    { return 4; }  // fo2, fill, startP, startMix
        if (_state == GB_CHECK) { return 4; }  // o2Fill, total, startP, startMix
        if (_state == GB_MOD)   { return 1; }
        return 1;
    }

    hidden function _adjustField(dir) {
        if (_state == GB_PP) {
            if      (_field == 0) { _ppFo2Idx   = _cyc(_ppFo2Idx,   dir, GB_FO2_VALS.size()); }
            else if (_field == 1) { _ppFillIdx  = _cyc(_ppFillIdx,  dir, GB_FILL_P.size()); }
            else if (_field == 2) { _ppStartIdx = _cyc(_ppStartIdx, dir, GB_START_P.size()); }
            else                  { _ppStartMix = _cyc(_ppStartMix, dir, GB_START_MIX.size()); }
        } else if (_state == GB_CHECK) {
            if      (_field == 0) { _chO2FillIdx = _cyc(_chO2FillIdx, dir, GB_START_P.size()); }
            else if (_field == 1) { _chTotalIdx  = _cyc(_chTotalIdx,  dir, GB_FILL_P.size()); }
            else if (_field == 2) { _chStartIdx  = _cyc(_chStartIdx,  dir, GB_START_P.size()); }
            else                  { _chStartMix  = _cyc(_chStartMix,  dir, GB_START_MIX.size()); }
        } else if (_state == GB_MOD) {
            _modFo2Idx = _cyc(_modFo2Idx, dir, GB_FO2_VALS.size());
        }
    }

    hidden function _cyc(idx, dir, sz) { return (idx + dir + sz) % sz; }

    // Format float to 2 decimal places
    hidden function _f2(v) {
        var i  = v.toNumber();
        var dv = ((v - i.toFloat()).abs() * 100.0 + 0.5).toNumber();
        if (dv >= 100) { i++; dv = 0; }
        if (dv < 10)   { return i + ".0" + dv; }
        return i + "." + dv;
    }

    // Format float to 1 decimal place
    hidden function _f1(v) {
        var i  = v.toNumber();
        var dv = ((v - i.toFloat()).abs() * 10.0 + 0.5).toNumber();
        if (dv >= 10) { i++; dv = 0; }
        return i + "." + dv;
    }

    // ── Layout helpers ────────────────────────────────────────────────────────

    hidden function _rowH() {
        var h = _h * 10 / 100; if (h < 17) { h = 17; } var hMax = _h * 6 / 100; if (hMax < 24) { hMax = 24; } if (h > hMax) { h = hMax; } return h;
    }
    hidden function _resH() {
        var h = _h * 11 / 100; if (h < 18) { h = 18; } var hMax = _h * 7 / 100; if (hMax < 26) { hMax = 26; } if (h > hMax) { h = hMax; } return h;
    }
    hidden function _sY() {
        var h = _h * 11 / 100; if (h < 18) { h = 18; } var hMax = _h * 6 / 100; if (hMax < 24) { hMax = 24; } if (h > hMax) { h = hMax; } return h;
    }

    hidden function _divider(dc, y) {
        var mg = _w * 8 / 100;
        dc.setColor(GB_DIV, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(mg, y, _w - mg, y);
    }

    // Input row: label left, value right, active = dive-blue label + white value
    hidden function _row(dc, y, rh, label, value, active) {
        var mg = _w * 7 / 100; if (mg < 6) { mg = 6; }
        var fXH = dc.getFontHeight(Graphics.FONT_XTINY);
        var ty = y + (rh - fXH) / 2;
        dc.setColor(active ? GB_BLUE : GB_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mg + 5, ty, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(active ? GB_WHITE : GB_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - mg - 5, ty, Graphics.FONT_XTINY,
                    value + (active ? " <>" : ""), Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Result row: colored left accent bar, dim label left, colored value right
    hidden function _outRow(dc, y, rh, label, value, col) {
        var mg = _w * 6 / 100; if (mg < 5) { mg = 5; }
        dc.setColor(GB_ACT_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mg, y, _w - mg * 2, rh, 3);
        var acW = _w * 10 / 1000; if (acW < 3) { acW = 3; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mg, y + 2, acW, rh - 4);
        var fXH = dc.getFontHeight(Graphics.FONT_XTINY);
        var ty = y + (rh - fXH) / 2;
        dc.setColor(GB_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mg + 8, ty, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - mg - 5, ty, Graphics.FONT_XTINY, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    hidden function _hint(dc, txt) {
        dc.setColor(GB_HINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h - _h * 5 / 100, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _title(dc, txt) {
        dc.setColor(GB_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 1 / 100, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Render dispatch ───────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth() * 9 / 10;
        _h = dc.getHeight() * 9 / 10;
        dc.setColor(GB_BG, GB_BG);
        dc.clear();

        if      (_state == GB_DISC)  { _drawDisc(dc); }
        else if (_state == GB_MENU)  { _drawMenu(dc); }
        else if (_state == GB_PP)    { _drawPP(dc); }
        else if (_state == GB_CHECK) { _drawCheck(dc); }
        else if (_state == GB_MOD)   { _drawMOD(dc); }
    }

    // ── DISCLAIMER ────────────────────────────────────────────────────────────

    hidden function _drawDisc(dc) {
        dc.setColor(GB_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 6 / 100, Graphics.FONT_LARGE, "!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(GB_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 22 / 100, Graphics.FONT_SMALL, "DIVE GAS",  Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 33 / 100, Graphics.FONT_SMALL, "BLENDER",   Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(GB_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 47 / 100, Graphics.FONT_XTINY, "Planning tool only.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 56 / 100, Graphics.FONT_XTINY, "Verify with O2 analyser.", Graphics.TEXT_JUSTIFY_CENTER);
        var blinkC = (_tick % 2 == 0) ? GB_CYAN : 0x1A5588;
        dc.setColor(blinkC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 76 / 100, Graphics.FONT_SMALL, "Tap to Accept", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── MAIN MENU ─────────────────────────────────────────────────────────────

    hidden function _drawMenu(dc) {
        dc.setColor(GB_BG, GB_BG);
        dc.clear();

        var titleY = _h * 3 / 100;
        dc.setColor(GB_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, titleY, Graphics.FONT_SMALL, "GAS BLENDER", Graphics.TEXT_JUSTIFY_CENTER);

        var items = _menuItems;
        var fTit = dc.getFontHeight(Graphics.FONT_SMALL);
        var fXt  = dc.getFontHeight(Graphics.FONT_XTINY);
        var rH   = _h * 11 / 100; if (rH < fXt + 4) { rH = fXt + 4; }
        var headBottom = titleY + fTit + _h * 3 / 100;
        var availH     = _h - headBottom - _h * 4 / 100;
        var blockH     = 4 * rH;
        var sY         = headBottom + (availH - blockH) / 2; if (sY < headBottom) { sY = headBottom; }

        for (var i = 0; i < items.size(); i++) {
            var y   = sY + i * rH;
            var sel = (i == _menuSel);
            dc.setColor(sel ? GB_WHITE : GB_DIM, Graphics.COLOR_TRANSPARENT);
            var ty = y + (rH - fXt) / 2;
            dc.drawText(_w / 2, ty, Graphics.FONT_XTINY, items[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── PP BLEND ─────────────────────────────────────────────────────────────
    // P_O2_added = ((FO2_t - 0.21)*P_total - (FO2_s - 0.21)*P_start) / 0.79

    hidden function _drawPP(dc) {
        var rH   = _rowH();
        var resH = _resH();
        var y    = _sY();

        _title(dc, "PP BLEND");

        var fo2t = GB_FO2_VALS[_ppFo2Idx];
        var ptot = GB_FILL_P[_ppFillIdx].toFloat();
        var pst  = GB_START_P[_ppStartIdx].toFloat();
        var fo2s = GB_START_MIX[_ppStartMix];

        _row(dc, y, rH, "TARGET",  GB_FO2_LBLS[_ppFo2Idx],          _field == 0); y += rH;
        _row(dc, y, rH, "FILL",    GB_FILL_P[_ppFillIdx] + " bar",   _field == 1); y += rH;
        _row(dc, y, rH, "IN TANK", GB_START_P[_ppStartIdx] + " bar", _field == 2); y += rH;
        _row(dc, y, rH, "TK MIX",  GB_START_LBL[_ppStartMix],        _field == 3); y += rH;

        _divider(dc, y + 1); y += 4;

        var po2Added = ((fo2t - 0.21) * ptot - (fo2s - 0.21) * pst) / 0.79;
        var fillToO2 = pst + po2Added;

        if (po2Added < 0.0) {
            var exfH = dc.getFontHeight(Graphics.FONT_XTINY);
            dc.setColor(GB_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, y + 2, Graphics.FONT_XTINY, "DUMP GAS FIRST", Graphics.TEXT_JUSTIFY_CENTER);
            var dumpTo = ((fo2t - 0.21) * ptot / (fo2s - 0.21 + 0.0001)).toNumber();
            if (dumpTo < 0) { dumpTo = 0; }
            dc.setColor(GB_DIMVAL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, y + exfH + 4, Graphics.FONT_XTINY,
                        "Dump to ~" + dumpTo + " bar", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (fillToO2 > ptot) {
            dc.setColor(GB_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, y + 2, Graphics.FONT_XTINY, "FO2 TOO HIGH", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            _outRow(dc, y, resH, "1 Fill O2", fillToO2.toNumber() + " bar", GB_CYAN);
            y += resH + 2;
            _outRow(dc, y, resH, "2 Top air", ptot.toNumber() + " bar",     GB_GREEN);
        }

        _hint(dc, "UP/DN <> SEL next");
    }

    // ── MIX CHECK ─────────────────────────────────────────────────────────────

    hidden function _drawCheck(dc) {
        var rH   = _rowH();
        var resH = _resH();
        var y    = _sY();

        _title(dc, "MIX CHECK");

        var pO2fill = GB_START_P[_chO2FillIdx].toFloat();
        var pTotal  = GB_FILL_P[_chTotalIdx].toFloat();
        var pStart  = GB_START_P[_chStartIdx].toFloat();
        var fo2s    = GB_START_MIX[_chStartMix];

        _row(dc, y, rH, "O2 TO",  GB_START_P[_chO2FillIdx] + " bar", _field == 0); y += rH;
        _row(dc, y, rH, "FILL",   GB_FILL_P[_chTotalIdx] + " bar",   _field == 1); y += rH;
        _row(dc, y, rH, "WAS IN", GB_START_P[_chStartIdx] + " bar",  _field == 2); y += rH;
        _row(dc, y, rH, "TK MIX", GB_START_LBL[_chStartMix],         _field == 3); y += rH;

        _divider(dc, y + 1); y += 4;

        if (pTotal <= 0.0 || pTotal <= pStart) {
            dc.setColor(GB_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, y + 2, Graphics.FONT_XTINY, "CHECK VALUES", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var po2Added  = pO2fill - pStart; if (po2Added < 0.0) { po2Added = 0.0; }
            var pAir      = pTotal - pO2fill; if (pAir < 0.0) { pAir = 0.0; }
            var fo2Actual = (fo2s * pStart + po2Added + 0.21 * pAir) / pTotal;
            var pct       = (fo2Actual * 100.0 + 0.5).toNumber();
            var po2at40   = fo2Actual * 5.0;
            var col = (po2at40 <= 1.4) ? GB_GREEN : ((po2at40 <= 1.6) ? GB_ORANGE : GB_RED);
            var modV = 0;
            if (fo2Actual > 0.01) { modV = ((1.4 / fo2Actual - 1.0) * 10.0).toNumber(); }

            _outRow(dc, y, resH, "FO2", pct + "% (" + _f2(fo2Actual) + ")", col);
            y += resH + 2;
            _outRow(dc, y, resH, "MOD @1.4", modV + " m", GB_CYAN);
        }

        _hint(dc, "UP/DN <> SEL next");
    }

    // ── MOD LOOKUP ────────────────────────────────────────────────────────────

    hidden function _drawMOD(dc) {
        var rH = _rowH();
        var y  = _sY();

        _title(dc, "MOD LOOKUP");

        _row(dc, y, rH, "GAS", GB_FO2_LBLS[_modFo2Idx], _field == 0);
        y += rH + 3;
        _divider(dc, y); y += 5;

        var fo2   = GB_FO2_VALS[_modFo2Idx];
        var mod14 = ((1.4 / fo2 - 1.0) * 10.0).toNumber();
        var mod16 = ((1.6 / fo2 - 1.0) * 10.0).toNumber();
        var po2_30 = _f2(fo2 * 4.0);
        var po2_40 = _f2(fo2 * 5.0);
        var col = (fo2 * 5.0 <= 1.4) ? GB_GREEN : ((fo2 * 5.0 <= 1.6) ? GB_ORANGE : GB_RED);

        // MOD at 1.4 — FONT_NUMBER_MILD keeps it readable without overflowing
        dc.setColor(GB_CYAN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y, Graphics.FONT_NUMBER_MILD, mod14 + "m", Graphics.TEXT_JUSTIFY_CENTER);
        y += _h * 22 / 100;

        var xfH = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(GB_DIMVAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y, Graphics.FONT_XTINY, "MOD at PO2 1.4 ATA", Graphics.TEXT_JUSTIFY_CENTER);
        y += xfH + 3;

        dc.setColor(GB_ACT_LBL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y, Graphics.FONT_XTINY, "MOD 1.6: " + mod16 + " m", Graphics.TEXT_JUSTIFY_CENTER);
        y += xfH + 3;

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y, Graphics.FONT_XTINY,
                    "PO2 @30m " + po2_30 + "  @40m " + po2_40, Graphics.TEXT_JUSTIFY_CENTER);

        _hint(dc, "UP/DN: change gas");
    }
}
