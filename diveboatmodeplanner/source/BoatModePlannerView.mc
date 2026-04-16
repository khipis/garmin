// BoatModePlannerView.mc
// ─────────────────────────────────────────────────────────────────────────────
// Boat Mode Dive Planner — 3-mode dive planning tool for outdoor boat deck use
//
// Design contract:
//   • Outdoor glare optimised: near-black background, maximum-brightness text
//   • Verdict boxes use BRIGHT fill + large text — readable at arm's length
//   • Mode select = 3 large tap targets, one screen
//   • Each mode: inputs at top (large), full-width GO/NO GO verdict at bottom
//   • 2-3 button presses from launch to final answer
//
// ── Modes ─────────────────────────────────────────────────────────────────────
//   Quick Plan   — gas + depth + time → combined GO / REVIEW / NO GO
//   Safety Check — gas + depth        → PO2 + SAFE / WARNING / DANGER
//   Gas Check    — fill + tank + depth + time → ENOUGH / SHORT
// ─────────────────────────────────────────────────────────────────────────────

using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;

// ── States ────────────────────────────────────────────────────────────────────
enum { BM_MODE_SEL, BM_QUICK, BM_SAFETY, BM_GAS }

// ── Presets ───────────────────────────────────────────────────────────────────
const BM_FO2_VALS   = [0.21, 0.27, 0.28, 0.29, 0.30, 0.31, 0.32, 0.36];
const BM_FO2_LBLS   = ["Air 21%", "EAN 27", "EAN 28", "EAN 29", "EAN 30", "EAN 31", "Nitrox 32", "Nitrox 36"];
const BM_DEPTHS     = [5, 10, 12, 15, 18, 20, 22, 25, 28, 30, 33, 35, 40];
const BM_TIMES      = [5, 10, 15, 20, 25, 30, 40, 50, 60, 80];
const BM_FILLS      = [100, 120, 140, 160, 180, 200, 210, 220, 230, 240];
const BM_TANKS      = [10, 12, 15];

const BM_SAC_DFLT   = 18.0;   // typical SAC L/min
const BM_RESERVE    = 50;     // bar — standard reserve

const BM_NDL_D      = [10, 15, 18, 20, 25, 30, 35, 40];
const BM_NDL_T      = [219, 80, 56, 45, 29, 20, 14, 9];

const BM_BG         = 0x000000;
const BM_WHITE      = 0xFFFFFF;
const BM_DIM        = 0x555555;
const BM_SEL_BG     = 0x0A1520;
const BM_SEL_LBL    = 0x66AADD;
const BM_DIVL       = 0x111111;

const BM_VFILL_GO   = 0x00CC44;
const BM_VFILL_REV  = 0xFFAA00;
const BM_VFILL_NOGO = 0xFF2222;
const BM_VFILL_SAFE = 0x00CC44;
const BM_VFILL_WARN = 0xFFAA00;
const BM_VFILL_DANG = 0xFF2222;
const BM_VFILL_ENO  = 0x00CC44;
const BM_VFILL_SHT  = 0xFF2222;

// ─────────────────────────────────────────────────────────────────────────────

class BoatModePlannerView extends WatchUi.View {

    var _state;

    hidden var _w;
    hidden var _h;
    hidden var _tick;
    hidden var _timer;

    // Mode select cursor
    hidden var _mSel;

    // Active input field within each mode
    hidden var _field;

    // Shared inputs (Quick Plan + Safety share gas/depth)
    hidden var _fo2Idx;
    hidden var _depIdx;
    hidden var _timeIdx;
    hidden var _fillIdx;
    hidden var _tankIdx;
    hidden var _modeLabels;
    hidden var _modeSubs;

    // ── Init ─────────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        var ds  = System.getDeviceSettings();
        _w      = ds.screenWidth;
        _h      = ds.screenHeight;
        _tick   = 0;
        _state  = BM_MODE_SEL;
        _mSel   = 0;
        _field  = 0;

        _fo2Idx  = 1;   // Nitrox 32 default
        _depIdx  = 7;   // 25m
        _timeIdx = 5;   // 30 min
        _fillIdx = 5;   // 200 bar
        _tankIdx = 1;   // 12L
        _modeLabels = ["QUICK PLAN", "SAFETY CHECK", "GAS CHECK"];
        _modeSubs = ["gas / depth / time", "gas / depth  -> PO2", "fill / tank / depth"];
    }

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
        if (_state == BM_MODE_SEL) {
            var modes = [BM_QUICK, BM_SAFETY, BM_GAS];
            _state = modes[_mSel];
            _field = 0;
        } else {
            var mx = _maxField();
            if (_field < mx - 1) { _field++; }
        }
    }

    function doBack() {
        if (_state == BM_MODE_SEL) { return false; }
        if (_field > 0) { _field--; return true; }
        _state = BM_MODE_SEL;
        return true;
    }

    function doUp() {
        if (_state == BM_MODE_SEL) {
            _mSel = (_mSel - 1 + 3) % 3;
        } else {
            _adjustField(-1);
        }
    }

    function doDown() {
        if (_state == BM_MODE_SEL) {
            _mSel = (_mSel + 1) % 3;
        } else {
            _adjustField(1);
        }
    }

    function doTap(x, y) {
        if (_state == BM_MODE_SEL) {
            var tileH = _h / 3;
            var tMaxT = _h * 24 / 100; if (tMaxT < 90) { tMaxT = 90; }
            if (tileH > tMaxT) { tileH = tMaxT; }
            var startY = (_h - tileH * 3) / 2; if (startY < 0) { startY = 0; }
            var mode = (y - startY) / tileH;
            if (mode < 0) { mode = 0; }
            if (mode > 2) { mode = 2; }
            _mSel = mode;
            doSelect();
        } else {
            if (y < _h / 2) { _adjustField(-1); }
            else             { _adjustField(1); }
        }
    }

    hidden function _maxField() {
        if (_state == BM_QUICK)  { return 5; }   // gas, depth, time, fill, tank
        if (_state == BM_SAFETY) { return 2; }   // gas, depth
        if (_state == BM_GAS)    { return 4; }   // fill, tank, depth, time
        return 1;
    }

    hidden function _adjustField(dir) {
        if (_state == BM_QUICK) {
            if      (_field == 0) { _fo2Idx  = (_fo2Idx  + dir + BM_FO2_VALS.size()) % BM_FO2_VALS.size(); }
            else if (_field == 1) { _depIdx  = (_depIdx  + dir + BM_DEPTHS.size())   % BM_DEPTHS.size(); }
            else if (_field == 2) { _timeIdx = (_timeIdx + dir + BM_TIMES.size())    % BM_TIMES.size(); }
            else if (_field == 3) { _fillIdx = (_fillIdx + dir + BM_FILLS.size())    % BM_FILLS.size(); }
            else                  { _tankIdx = (_tankIdx + dir + BM_TANKS.size())    % BM_TANKS.size(); }
        } else if (_state == BM_SAFETY) {
            if (_field == 0) { _fo2Idx = (_fo2Idx + dir + BM_FO2_VALS.size()) % BM_FO2_VALS.size(); }
            else             { _depIdx = (_depIdx + dir + BM_DEPTHS.size())   % BM_DEPTHS.size(); }
        } else if (_state == BM_GAS) {
            if      (_field == 0) { _fillIdx = (_fillIdx + dir + BM_FILLS.size())  % BM_FILLS.size(); }
            else if (_field == 1) { _tankIdx = (_tankIdx + dir + BM_TANKS.size())  % BM_TANKS.size(); }
            else if (_field == 2) { _depIdx  = (_depIdx  + dir + BM_DEPTHS.size()) % BM_DEPTHS.size(); }
            else                  { _timeIdx = (_timeIdx + dir + BM_TIMES.size())  % BM_TIMES.size(); }
        }
    }

    // ── Render dispatch ───────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth() * 9 / 10;
        _h = dc.getHeight() * 9 / 10;
        dc.setColor(BM_BG, BM_BG);
        dc.clear();

        if      (_state == BM_MODE_SEL) { _drawModeSel(dc); }
        else if (_state == BM_QUICK)    { _drawQuick(dc); }
        else if (_state == BM_SAFETY)   { _drawSafety(dc); }
        else if (_state == BM_GAS)      { _drawGas(dc); }
    }

    // ── MODE SELECT ────────────────────────────────────────────────────────────

    hidden function _drawModeSel(dc) {
        var labels = _modeLabels;
        var subs   = _modeSubs;

        var tileH  = _h / 3;
        var tMax = _h * 24 / 100; if (tMax < 90) { tMax = 90; }
        if (tileH > tMax) { tileH = tMax; }
        var startY = (_h - tileH * 3) / 2; if (startY < 0) { startY = 0; }

        var lblH = dc.getFontHeight(Graphics.FONT_SMALL);
        var subH = dc.getFontHeight(Graphics.FONT_XTINY);
        var gap  = _h * 1 / 100;
        if (gap < 2) { gap = 2; }
        var blockH = lblH + gap + subH;

        for (var i = 0; i < 3; i++) {
            var y   = startY + i * tileH;
            var sel = (i == _mSel);

            var blockY = y + (tileH - blockH) / 2;
            dc.setColor(sel ? BM_WHITE : BM_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, blockY, Graphics.FONT_SMALL, labels[i], Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(sel ? 0x888888 : 0x333333, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, blockY + lblH + gap, Graphics.FONT_XTINY,
                        subs[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Layout helpers ─────────────────────────────────────────────────────────

    // Compact row height: proportional to screen, capped for readability
    hidden function _rH() {
        var h = _h * 10 / 100; if (h < 16) { h = 16; } var hMax = _h * 6 / 100; if (hMax < 24) { hMax = 24; } if (h > hMax) { h = hMax; } return h;
    }

    // ── QUICK PLAN ────────────────────────────────────────────────────────────

    hidden function _drawQuick(dc) {
        var fo2  = BM_FO2_VALS[_fo2Idx];
        var dep  = BM_DEPTHS[_depIdx];
        var time = BM_TIMES[_timeIdx];
        var fill = BM_FILLS[_fillIdx];
        var tank = BM_TANKS[_tankIdx];

        var po2  = _po2(fo2, dep);
        var ndlV = _ndl(dep, fo2).toNumber();
        var gasT = _gasTime(fill, BM_RESERVE, tank, BM_SAC_DFLT, dep).toNumber();

        var pSt = (po2 <= 1.4) ? 0 : ((po2 <= 1.6) ? 1 : 2);
        var nSt = (time <= ndlV) ? 0 : ((time <= ndlV + 5) ? 1 : 2);
        var gSt = (gasT >= time) ? 0 : ((gasT >= time - 5) ? 1 : 2);
        var worst = pSt;
        if (nSt > worst) { worst = nSt; }
        if (gSt > worst) { worst = gSt; }

        var mg   = _w * 8 / 100;
        var rH   = _rH();
        var topY = _h * 5 / 100;

        dc.setColor(BM_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 1 / 100, Graphics.FONT_XTINY, "QUICK PLAN", Graphics.TEXT_JUSTIFY_CENTER);

        _row(dc, topY + 0 * rH, "GAS",   BM_FO2_LBLS[_fo2Idx], _field == 0, mg, rH);
        _row(dc, topY + 1 * rH, "DEPTH", dep + "m",              _field == 1, mg, rH);
        _row(dc, topY + 2 * rH, "TIME",  time + " min",           _field == 2, mg, rH);
        _row(dc, topY + 3 * rH, "FILL",  fill + " bar",           _field == 3, mg, rH);
        _row(dc, topY + 4 * rH, "TANK",  tank + "L",              _field == 4, mg, rH);

        var divY = topY + 5 * rH + 2;
        dc.setColor(BM_DIVL, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 5 / 100, divY, _w * 95 / 100, divY);

        var vbY = divY + 4;
        var hintOff = _h * 5 / 100;
        var vbH = _h - hintOff - vbY - 4; if (vbH < 30) { vbH = 30; }

        var vTexts = ["GO", "REVIEW", "NO GO"];
        var vFills = [BM_VFILL_GO, BM_VFILL_REV, BM_VFILL_NOGO];
        var vCols  = [0x000000, 0x000000, BM_WHITE];
        var sub = "PO2:" + _f2(po2) + " NDL:" + ndlV + "m GAS:" + gasT + "m";
        _verdictBox(dc, vbY, vbH, vTexts[worst], sub, vFills[worst], vCols[worst]);

        dc.setColor(BM_DIVL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h - _h * 4 / 100, Graphics.FONT_XTINY,
                    "UP/DN <>  SEL next  SAC 18L", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── SAFETY CHECK ──────────────────────────────────────────────────────────

    hidden function _drawSafety(dc) {
        var fo2  = BM_FO2_VALS[_fo2Idx];
        var dep  = BM_DEPTHS[_depIdx];
        var po2  = _po2(fo2, dep);
        var modV = ((1.4 / fo2 - 1.0) * 10.0).toNumber();
        var ndlV = _ndl(dep, fo2).toNumber();

        var mg   = _w * 8 / 100;
        var rH   = _rH();
        var topY = _h * 5 / 100;

        dc.setColor(BM_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 1 / 100, Graphics.FONT_XTINY, "SAFETY CHECK", Graphics.TEXT_JUSTIFY_CENTER);

        _row(dc, topY,       "GAS",   BM_FO2_LBLS[_fo2Idx], _field == 0, mg, rH);
        _row(dc, topY + rH,  "DEPTH", dep + "m",              _field == 1, mg, rH);

        var divY = topY + 2 * rH + 2;
        dc.setColor(BM_DIVL, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 5 / 100, divY, _w * 95 / 100, divY);

        var vbY = divY + 4;
        var hintOff2 = _h * 5 / 100;
        var vbH = _h - hintOff2 - vbY - 4; if (vbH < 30) { vbH = 30; }

        var vTxt = (po2 <= 1.4) ? "SAFE" : ((po2 <= 1.6) ? "WARNING" : "DANGER");
        var vFil = (po2 <= 1.4) ? BM_VFILL_SAFE : ((po2 <= 1.6) ? BM_VFILL_WARN : BM_VFILL_DANG);
        var vTxC = (po2 > 1.6)  ? BM_WHITE : 0x000000;
        var sub  = "PO2:" + _f2(po2) + "  MOD:" + modV + "m  NDL:" + ndlV + "m";
        _verdictBox(dc, vbY, vbH, vTxt, sub, vFil, vTxC);

        dc.setColor(BM_DIVL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h - _h * 4 / 100, Graphics.FONT_XTINY,
                    "UP/DN <>  SEL next", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── GAS CHECK ─────────────────────────────────────────────────────────────

    hidden function _drawGas(dc) {
        var fill = BM_FILLS[_fillIdx];
        var tank = BM_TANKS[_tankIdx];
        var dep  = BM_DEPTHS[_depIdx];
        var time = BM_TIMES[_timeIdx];

        var gasT  = _gasTime(fill, BM_RESERVE, tank, BM_SAC_DFLT, dep).toNumber();
        var avail = (fill - BM_RESERVE) * tank;
        var need  = (BM_SAC_DFLT * time.toFloat() * (dep.toFloat() / 10.0 + 1.0)).toNumber();

        var mg   = _w * 8 / 100;
        var rH   = _rH();
        var topY = _h * 5 / 100;

        dc.setColor(BM_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 1 / 100, Graphics.FONT_XTINY, "GAS CHECK", Graphics.TEXT_JUSTIFY_CENTER);

        _row(dc, topY + 0 * rH, "FILL",  fill + " bar", _field == 0, mg, rH);
        _row(dc, topY + 1 * rH, "TANK",  tank + " L",   _field == 1, mg, rH);
        _row(dc, topY + 2 * rH, "DEPTH", dep  + "m",    _field == 2, mg, rH);
        _row(dc, topY + 3 * rH, "TIME",  time + " min", _field == 3, mg, rH);

        var divY = topY + 4 * rH + 2;
        dc.setColor(BM_DIVL, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 5 / 100, divY, _w * 95 / 100, divY);

        var vbY = divY + 4;
        var hintOff3 = _h * 5 / 100;
        var vbH = _h - hintOff3 - vbY - 4; if (vbH < 30) { vbH = 30; }

        var isEnough = (gasT >= time);
        var vTxt = isEnough ? "ENOUGH" : "SHORT";
        var vFil = isEnough ? BM_VFILL_ENO : BM_VFILL_SHT;
        var vTxC = isEnough ? 0x000000 : BM_WHITE;
        var sub  = isEnough
            ? (gasT + "min  " + avail + "L/" + need + "L")
            : (gasT + "min  " + (time - gasT) + "min short");
        _verdictBox(dc, vbY, vbH, vTxt, sub, vFil, vTxC);

        dc.setColor(BM_DIVL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h - _h * 4 / 100, Graphics.FONT_XTINY,
                    "UP/DN <>  SEL next  SAC 18L", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Drawing helpers ────────────────────────────────────────────────────────

    // Input row: label left, value right, active = highlight + chevrons
    hidden function _row(dc, y, lbl, val, active, mg, rH) {
        var fXH = dc.getFontHeight(Graphics.FONT_XTINY);
        var ty = y + (rH - fXH) / 2;
        dc.setColor(active ? 0x0088CC : 0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mg + 5, ty, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(active ? BM_WHITE : BM_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - mg - 5, ty, Graphics.FONT_XTINY,
                    val + (active ? " <>" : ""), Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Verdict box: fills remaining space, picks font based on available height.
    // sub="" → verdict only; sub!="" → verdict + compact sub-line inside box.
    hidden function _verdictBox(dc, y, h, text, sub, fillCol, textCol) {
        var mg = _w * 6 / 100;
        dc.setColor(fillCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(mg, y, _w - mg * 2, h, 5);

        // Adaptive verdict font
        var vFont  = (h >= 60) ? Graphics.FONT_LARGE  :
                     (h >= 40) ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
        var vFontH = dc.getFontHeight(vFont);

        dc.setColor(textCol, Graphics.COLOR_TRANSPARENT);
        if (sub.length() == 0) {
            dc.drawText(_w / 2, y + (h - vFontH) / 2, vFont, text, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var subH   = dc.getFontHeight(Graphics.FONT_XTINY);
            var gap    = 3;
            var totalH = vFontH + gap + subH;
            var startY = y + (h - totalH) / 2;
            dc.drawText(_w / 2, startY, vFont, text, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(_w / 2, startY + vFontH + gap, Graphics.FONT_XTINY,
                        sub, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Math helpers ──────────────────────────────────────────────────────────

    hidden function _po2(fo2, depth) {
        return fo2 * (depth.toFloat() / 10.0 + 1.0);
    }

    hidden function _po2Col(po2) {
        if (po2 <= 1.4) { return BM_VFILL_SAFE; }
        if (po2 <= 1.6) { return BM_VFILL_WARN; }
        return BM_VFILL_DANG;
    }

    // Gas duration in minutes given tank + pressures + SAC + depth
    hidden function _gasTime(fill, reserve, tank, sac, depth) {
        var avail  = (fill - reserve).toFloat() * tank.toFloat();
        var ambP   = depth.toFloat() / 10.0 + 1.0;
        var denom  = sac * ambP;
        if (denom <= 0.0) { return 0.0; }
        return avail / denom;
    }

    // NDL table lookup with EAD benefit for nitrox
    hidden function _ndl(depth, fo2) {
        var effD = depth.toFloat();
        if (fo2 > 0.21) {
            var eadV = ((depth.toFloat() + 10.0) * (1.0 - fo2) / 0.79) - 10.0;
            if (eadV >= 0.0) { effD = eadV; }
        }
        var n = BM_NDL_D.size();
        if (effD <= BM_NDL_D[0].toFloat())     { return BM_NDL_T[0].toFloat(); }
        if (effD >= BM_NDL_D[n-1].toFloat())   { return BM_NDL_T[n-1].toFloat(); }
        for (var i = 0; i < n - 1; i++) {
            var d0 = BM_NDL_D[i].toFloat();
            var d1 = BM_NDL_D[i + 1].toFloat();
            if (effD >= d0 && effD <= d1) {
                var t0 = BM_NDL_T[i].toFloat();
                var t1 = BM_NDL_T[i + 1].toFloat();
                return t0 + (t1 - t0) * (effD - d0) / (d1 - d0);
            }
        }
        return BM_NDL_T[n-1].toFloat();
    }

    // Format float to 2 decimal places
    hidden function _f2(v) {
        var i  = v.toNumber();
        var dv = ((v - i.toFloat()).abs() * 100.0 + 0.5).toNumber();
        if (dv >= 100) { i++; dv = 0; }
        if (dv < 10)   { return i + ".0" + dv; }
        return i + "." + dv;
    }
}
