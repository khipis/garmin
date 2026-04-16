// QuickDiveView.mc
// ─────────────────────────────────────────────────────────────────────────────
// Emergency Dive Quick Calculator
//
// Design contract:
//   • App opens DIRECTLY on a working calculator — zero screens to navigate
//   • Two swipeable pages (onPreviousPage / onNextPage):
//       Page 1 — GAS CHECK: gas + depth → PO2 + MOD + NDL + SAFE/WARNING/DANGER
//       Page 2 — BEST MIX:  depth       → optimal FO2, MOD, classification
//   • Background tints immediately to green/orange/red — glanceable at a distance
//   • No confirmation button — result is live as inputs change
//   • DANGER status pulses (500ms timer) for added urgency
// ─────────────────────────────────────────────────────────────────────────────

using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;

// ── Screen / page IDs ────────────────────────────────────────────────────────
enum { QC_CHECK, QC_BESTMIX }

// ── Presets ───────────────────────────────────────────────────────────────────
const QDC_FO2_VALS  = [0.21, 0.32, 0.36];
const QDC_FO2_LBLS  = ["Air 21%", "Nitrox 32", "Nitrox 36"];

// Depth range covers common recreational limits with fine granularity
const QDC_DEPTHS    = [5, 10, 12, 15, 18, 20, 22, 25, 28, 30, 33, 35, 40];

// NDL table — PADI RDP simplified (air)
const QDC_NDL_D     = [10, 15, 18, 20, 25, 30, 35, 40];
const QDC_NDL_T     = [219, 80, 56, 45, 29, 20, 14, 9];

// PO2 thresholds
const QDC_PO2_WORK  = 1.4;
const QDC_PO2_ABS   = 1.6;

// ── Verdict colours ───────────────────────────────────────────────────────────
// Background tints — dark but clearly tinted
const QC_BG_SAFE    = 0x021308;   // deep green
const QC_BG_WARN    = 0x110800;   // deep amber
const QC_BG_DANG    = 0x0E0202;   // deep red
const QC_BG_PULSE   = 0x1E0404;   // brighter red (danger pulse alternate)
const QC_BG_NEUTRAL = 0x040810;   // neutral dark (Best Mix screen)

// Verdict text colours
const QC_V_SAFE     = 0x00DD44;
const QC_V_WARN     = 0xFF9900;
const QC_V_DANG     = 0xFF2222;

// UI colours
const QC_WHITE      = 0xFFFFFF;
const QC_DIM        = 0x445566;
const QC_HINT       = 0x1A2E40;
const QC_SEL_BG     = 0x0A1E30;
const QC_CYAN       = 0x44CCFF;
const QC_DIVL       = 0x142030;

// ─────────────────────────────────────────────────────────────────────────────

class QuickDiveView extends WatchUi.View {

    var _page;   // current page: QC_CHECK or QC_BESTMIX

    hidden var _w;
    hidden var _h;
    hidden var _tick;
    hidden var _timer;

    // Shared inputs (both pages reference the same depth index for coherence)
    hidden var _fo2Idx;   // gas preset index
    hidden var _depIdx;   // depth preset index
    hidden var _field;    // 0=gas active, 1=depth active (QC_CHECK only)

    // ── Init ─────────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        var ds  = System.getDeviceSettings();
        _w      = ds.screenWidth;
        _h      = ds.screenHeight;
        _tick   = 0;
        _page   = QC_CHECK;

        _fo2Idx = 1;   // default: Nitrox 32 (most common dive gas)
        _depIdx = 7;   // default: 25m
        _field  = 1;   // depth field active — the most common first adjustment
    }

    // ── Timer for pulsing danger indicator ───────────────────────────────────

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

    // ── Input (called by delegate) ────────────────────────────────────────────

    // Toggle active field (gas ↔ depth on GAS CHECK page)
    function doSelect() {
        if (_page == QC_CHECK) {
            _field = 1 - _field;   // toggle between 0 (gas) and 1 (depth)
        }
        // On BEST MIX there is only depth — SELECT does nothing special
    }

    // Increment active value
    function doUp() {
        if (_page == QC_CHECK) {
            if (_field == 0) { _fo2Idx = (_fo2Idx - 1 + QDC_FO2_VALS.size()) % QDC_FO2_VALS.size(); }
            else             { _depIdx = (_depIdx - 1 + QDC_DEPTHS.size())    % QDC_DEPTHS.size(); }
        } else {
            _depIdx = (_depIdx - 1 + QDC_DEPTHS.size()) % QDC_DEPTHS.size();
        }
    }

    // Decrement active value
    function doDown() {
        if (_page == QC_CHECK) {
            if (_field == 0) { _fo2Idx = (_fo2Idx + 1) % QDC_FO2_VALS.size(); }
            else             { _depIdx = (_depIdx + 1) % QDC_DEPTHS.size(); }
        } else {
            _depIdx = (_depIdx + 1) % QDC_DEPTHS.size();
        }
    }

    // Swipe/page to Best Mix
    function doNextPage() {
        _page  = QC_BESTMIX;
        _field = 0;
    }

    // Swipe/page back to Gas Check
    function doPrevPage() {
        _page  = QC_CHECK;
        _field = 1;   // default to depth active
    }

    function doBack() {
        if (_page == QC_BESTMIX) { _page = QC_CHECK; _field = 1; return true; }
        return false;
    }

    // Touch: upper half = UP, lower half = DOWN
    function doTap(x, y) {
        if (y < _h / 2) { doUp(); }
        else             { doDown(); }
    }

    // ── Render ────────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();

        if (_page == QC_CHECK) { _drawCheck(dc); }
        else                   { _drawBestMix(dc); }
    }

    // ── PAGE 1: GAS CHECK ─────────────────────────────────────────────────────

    hidden function _drawCheck(dc) {
        var fo2  = QDC_FO2_VALS[_fo2Idx];
        var dep  = QDC_DEPTHS[_depIdx];
        var po2  = fo2 * (dep.toFloat() / 10.0 + 1.0);
        var modV = ((QDC_PO2_WORK / fo2 - 1.0) * 10.0).toNumber();
        var ndlV = _ndl(dep, fo2).toNumber();

        // Background tint = instant verdict
        var bgCol = _bgColor(po2);
        if (po2 > QDC_PO2_ABS && _tick % 2 == 0) { bgCol = QC_BG_PULSE; }
        dc.setColor(bgCol, bgCol);
        dc.clear();

        // Page label (top, tiny)
        dc.setColor(QC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 2 / 100, Graphics.FONT_XTINY, "GAS CHECK  1/2", Graphics.TEXT_JUSTIFY_CENTER);

        // ── Input rows ────────────────────────────────────────────────────────
        var mg  = _w * 9 / 100;
        var rH  = _h * 11 / 100;
        var y0  = _h * 10 / 100;
        var y1  = _h * 22 / 100;

        _drawRow(dc, y0, "GAS",   QDC_FO2_LBLS[_fo2Idx], _field == 0, mg, rH);
        _drawRow(dc, y1, "DEPTH", dep + "m",               _field == 1, mg, rH);

        // Divider
        dc.setColor(QC_DIVL, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 10 / 100, _h * 35 / 100, _w * 90 / 100, _h * 35 / 100);

        // PO2 value (colored, prominent)
        var vCol = _verdictColor(po2);
        dc.setColor(vCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 37 / 100, Graphics.FONT_MEDIUM,
                    "PO2 " + _f2(po2) + " ATA", Graphics.TEXT_JUSTIFY_CENTER);

        // ── VERDICT BOX ───────────────────────────────────────────────────────
        var bY  = _h * 48 / 100;
        var bH  = _h * 16 / 100;
        var bMg = _w * 12 / 100;
        dc.setColor(vCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bMg, bY, _w - bMg * 2, bH, 6);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, bY + bH * 5 / 100, Graphics.FONT_LARGE,
                    _verdictText(po2), Graphics.TEXT_JUSTIFY_CENTER);

        // MOD + NDL below verdict
        dc.setColor(QC_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 67 / 100, Graphics.FONT_SMALL,
                    "MOD " + modV + "m   NDL " + ndlV + "min", Graphics.TEXT_JUSTIFY_CENTER);

        // DANGER extra label (> absolute limit)
        if (po2 > QDC_PO2_ABS) {
            dc.setColor(QC_V_DANG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 76 / 100, Graphics.FONT_XTINY,
                        "EXCEEDS ABSOLUTE LIMIT", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Hints
        dc.setColor(QC_HINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 84 / 100, Graphics.FONT_XTINY,
                    "SEL: gas/depth  UP/DN: value", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 91 / 100, Graphics.FONT_XTINY,
                    "►  Best Mix", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── PAGE 2: BEST MIX ─────────────────────────────────────────────────────

    hidden function _drawBestMix(dc) {
        dc.setColor(QC_BG_NEUTRAL, QC_BG_NEUTRAL);
        dc.clear();

        dc.setColor(QC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 2 / 100, Graphics.FONT_XTINY, "BEST MIX  2/2", Graphics.TEXT_JUSTIFY_CENTER);

        var dep  = QDC_DEPTHS[_depIdx];
        var fo2  = 1.4 / (dep.toFloat() / 10.0 + 1.0);
        if (fo2 > 1.0)  { fo2 = 1.0; }
        if (fo2 < 0.21) { fo2 = 0.21; }
        var pct  = (fo2 * 100.0 + 0.5).toNumber();
        var modV = ((QDC_PO2_WORK / fo2 - 1.0) * 10.0).toNumber();
        var ndlV = _ndl(dep, fo2).toNumber();

        // Depth row
        var mg = _w * 9 / 100;
        var rH = _h * 11 / 100;
        _drawRow(dc, _h * 10 / 100, "DEPTH", dep + "m", true, mg, rH);

        // Divider
        dc.setColor(QC_DIVL, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 10 / 100, _h * 24 / 100, _w * 90 / 100, _h * 24 / 100);

        // Best mix percentage — dominant element
        dc.setColor(QC_CYAN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 26 / 100, Graphics.FONT_NUMBER_HOT,
                    pct + "%", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(QC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 55 / 100, Graphics.FONT_XTINY, "optimal FO2", Graphics.TEXT_JUSTIFY_CENTER);

        // Gas name
        var gasName;
        if      (pct <= 21) { gasName = "Air"; }
        else if (pct <= 36) { gasName = "Nitrox " + pct; }
        else                { gasName = "Nitrox " + pct + "*"; }
        dc.setColor(QC_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 63 / 100, Graphics.FONT_SMALL, gasName, Graphics.TEXT_JUSTIFY_CENTER);

        // MOD + NDL
        dc.setColor(QC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 73 / 100, Graphics.FONT_XTINY,
                    "MOD " + modV + "m   NDL " + ndlV + "min", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(QC_HINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 84 / 100, Graphics.FONT_XTINY, "UP/DN: depth", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_w / 2, _h * 91 / 100, Graphics.FONT_XTINY, "◄  Gas Check", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Drawing helpers ───────────────────────────────────────────────────────

    // Labeled input row with optional highlight
    hidden function _drawRow(dc, y, lbl, val, active, mg, rH) {
        if (active) {
            dc.setColor(QC_SEL_BG, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(mg, y, _w - mg * 2, rH, 4);
        }
        dc.setColor(active ? QC_CYAN : QC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mg + 5, y, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(active ? QC_WHITE : 0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - mg - 5, y, Graphics.FONT_XTINY,
                    val + (active ? " ◀▶" : ""), Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ── Math helpers ──────────────────────────────────────────────────────────

    hidden function _bgColor(po2) {
        if (po2 <= QDC_PO2_WORK) { return QC_BG_SAFE; }
        if (po2 <= QDC_PO2_ABS)  { return QC_BG_WARN; }
        return QC_BG_DANG;
    }

    hidden function _verdictColor(po2) {
        if (po2 <= QDC_PO2_WORK) { return QC_V_SAFE; }
        if (po2 <= QDC_PO2_ABS)  { return QC_V_WARN; }
        return QC_V_DANG;
    }

    hidden function _verdictText(po2) {
        if (po2 <= QDC_PO2_WORK) { return "SAFE"; }
        if (po2 <= QDC_PO2_ABS)  { return "WARNING"; }
        return "DANGER";
    }

    // NDL table lookup with linear interpolation + EAD benefit for nitrox
    hidden function _ndl(depth, fo2) {
        var effD = depth.toFloat();
        if (fo2 > 0.21) {
            var eadV = ((depth.toFloat() + 10.0) * (1.0 - fo2) / 0.79) - 10.0;
            if (eadV >= 0.0) { effD = eadV; }
        }
        var n = QDC_NDL_D.size();
        if (effD <= QDC_NDL_D[0].toFloat())       { return QDC_NDL_T[0].toFloat(); }
        if (effD >= QDC_NDL_D[n - 1].toFloat())   { return QDC_NDL_T[n - 1].toFloat(); }
        for (var i = 0; i < n - 1; i++) {
            var d0 = QDC_NDL_D[i].toFloat();
            var d1 = QDC_NDL_D[i + 1].toFloat();
            if (effD >= d0 && effD <= d1) {
                var t0 = QDC_NDL_T[i].toFloat();
                var t1 = QDC_NDL_T[i + 1].toFloat();
                return t0 + (t1 - t0) * (effD - d0) / (d1 - d0);
            }
        }
        return QDC_NDL_T[n - 1].toFloat();
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
