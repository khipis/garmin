// DiveRiskView.mc
// ─────────────────────────────────────────────────────────────────────────────
// Dive Risk Indicator — simplified risk assessment tool
//
// Design contract:
//   • Single screen, always live — no state machines, no navigation
//   • Four inputs (depth, time, gas, repetitive) adjusted via UP/DOWN/SELECT
//   • Risk score (0–100) dominates the screen with color-coded background
//   • Clarity over precision — communicates risk level instantly
//
// ── Scoring model ─────────────────────────────────────────────────────────────
//   Depth component  (0–25 pts):  linear, 40m = max
//   NDL saturation   (0–40 pts):  how close to no-deco limit (key driver)
//   Gas component    (0–8  pts):  Air +8, Nitrox 32 +4, Nitrox 36 +1
//   Repetitive dive  (0–15 pts):  first dive = 0, repetitive = +15
//   ─────────────────────────────────────────────────────────────────
//   Total max = 88 pts (padded to 100 at extreme NDL overshoot)
//
// ── Risk thresholds ────────────────────────────────────────────────────────────
//   0–35  → LOW     "Safe recreational dive"
//   36–65 → MEDIUM  "Approaching limits"
//   66+   → HIGH    "High risk profile"
// ─────────────────────────────────────────────────────────────────────────────

using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;

// ── Presets ───────────────────────────────────────────────────────────────────
const DRI_DEPTHS     = [5, 10, 12, 15, 18, 20, 22, 25, 28, 30, 33, 35, 40];
const DRI_TIMES      = [5, 10, 15, 20, 25, 30, 40, 50, 60, 80];
const DRI_GAS_FO2    = [0.21, 0.27, 0.28, 0.29, 0.30, 0.31, 0.32, 0.36];
const DRI_GAS_LBL    = ["Air 21%", "EAN 27", "EAN 28", "EAN 29", "EAN 30", "EAN 31", "Nitrox 32", "Nitrox 36"];
const DRI_GAS_PTS    = [8, 6, 6, 5, 5, 4, 4, 1];

const DRI_NDL_D      = [10, 15, 18, 20, 25, 30, 35, 40];
const DRI_NDL_T      = [219, 80, 56, 45, 29, 20, 14, 9];

const DR_BG_LOW      = 0x000000;
const DR_BG_MED      = 0x000000;
const DR_BG_HIGH     = 0x0A0000;
const DR_BG_PULSE    = 0x120000;

const DR_C_LOW       = 0x00CC44;
const DR_C_MED       = 0xFFAA00;
const DR_C_HIGH      = 0xFF2222;

const DR_WHITE       = 0xFFFFFF;
const DR_DIM         = 0x333333;
const DR_HINT        = 0x222222;
const DR_ACCENT      = 0x0088CC;
const DR_DIVL        = 0x111111;

// ─────────────────────────────────────────────────────────────────────────────

class DiveRiskView extends WatchUi.View {

    hidden var _w;
    hidden var _h;
    hidden var _tick;
    hidden var _timer;

    // ── Inputs
    hidden var _depIdx;    // index into DRI_DEPTHS
    hidden var _timeIdx;   // index into DRI_TIMES
    hidden var _gasIdx;    // 0=Air, 1=N32, 2=N36
    hidden var _repIdx;    // 0=first dive, 1=repetitive
    hidden var _field;     // active input field 0-3

    // Pre-allocated result slots (avoid new array every frame)
    hidden var _rScore; hidden var _rNdlRat; hidden var _rNdlMins;

    // ── Init ─────────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        var ds  = System.getDeviceSettings();
        _w      = ds.screenWidth;
        _h      = ds.screenHeight;
        _tick   = 0;

        _depIdx  = 9;    // 30m default
        _timeIdx = 5;    // 30 min default
        _gasIdx  = 0;    // Air default
        _repIdx  = 0;    // first dive default
        _field   = 0;    // depth field active
        _rScore = 0; _rNdlRat = 0; _rNdlMins = 0;
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
        _field = (_field + 1) % 4;
    }

    function doBack() {
        if (_field > 0) { _field--; return true; }
        return false;
    }

    function doUp() {
        _cycleField(-1);
    }

    function doDown() {
        _cycleField(1);
    }

    function doTap(x, y) {
        if (y < _h / 2) { _cycleField(-1); }
        else             { _cycleField(1); }
    }

    hidden function _cycleField(dir) {
        if      (_field == 0) { _depIdx  = (_depIdx  + dir + DRI_DEPTHS.size()) % DRI_DEPTHS.size(); }
        else if (_field == 1) { _timeIdx = (_timeIdx + dir + DRI_TIMES.size())  % DRI_TIMES.size(); }
        else if (_field == 2) { _gasIdx  = (_gasIdx  + dir + 3) % 3; }
        else                  { _repIdx  = (_repIdx  + dir + 2) % 2; }
    }

    // ── Render ────────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth() * 9 / 10;
        _h = dc.getHeight() * 9 / 10;

        var depth = DRI_DEPTHS[_depIdx];
        var time  = DRI_TIMES[_timeIdx];
        var fo2   = DRI_GAS_FO2[_gasIdx];
        var rep   = (_repIdx == 1);

        _calcScore(depth, time, fo2, rep);
        var score   = _rScore;
        var ndlRat  = _rNdlRat;
        var ndlMins = _rNdlMins;

        // Background tint — instant verdict before reading
        var bgCol = _bgColor(score);
        if (score >= 66 && _tick % 2 == 0) { bgCol = DR_BG_PULSE; }
        dc.setColor(bgCol, bgCol);
        dc.clear();

        // ── Input rows (top half) ─────────────────────────────────────────────
        var divY = _h / 2;
        var mg   = _w * 8 / 100;
        // Row height fills from y=16 to divider, 4 rows, uncapped for big screens
        var rH = (divY - 18) / 4;
        if (rH < 14) { rH = 14; }

        dc.setColor(DR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 1 / 100, Graphics.FONT_XTINY, "DIVE RISK", Graphics.TEXT_JUSTIFY_CENTER);

        var sY = _h * 4 / 100;
        _drawRow(dc, sY + 0 * rH, "DEPTH", depth + "m",                      _field == 0, mg, rH);
        _drawRow(dc, sY + 1 * rH, "TIME",  time  + " min",                    _field == 1, mg, rH);
        _drawRow(dc, sY + 2 * rH, "GAS",   DRI_GAS_LBL[_gasIdx],              _field == 2, mg, rH);
        _drawRow(dc, sY + 3 * rH, "PREV",  rep ? "Repetitive" : "1st dive",   _field == 3, mg, rH);

        // Divider
        dc.setColor(DR_DIVL, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 10 / 100, divY, _w * 90 / 100, divY);

        // ── Score + verdict (bottom half) — fully responsive ─────────────────
        // Use FONT_NUMBER_HOT only when there's enough room (≥ 210px screens).
        var isLarge   = (_h >= 210);
        var scoreFont = isLarge ? Graphics.FONT_NUMBER_HOT  : Graphics.FONT_NUMBER_MILD;
        var scoreFH   = dc.getFontHeight(scoreFont);
        var levelFont = isLarge ? Graphics.FONT_MEDIUM      : Graphics.FONT_SMALL;
        var levelFH   = dc.getFontHeight(levelFont);

        // Vertically centre [score + level + info] in the bottom half
        var totalH = scoreFH + 3 + levelFH + 3 + 13;
        var topGap = ((_h - divY) - totalH) / 2;
        if (topGap < 2) { topGap = 2; }

        var scoreY = divY + topGap;
        var levelY = scoreY + scoreFH + 3;
        var infoY  = levelY + levelFH + 3;

        var scoreCol = _riskColor(score);
        dc.setColor(scoreCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, scoreY, scoreFont, score.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(scoreCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, levelY, levelFont, _riskLevel(score), Graphics.TEXT_JUSTIFY_CENTER);

        // Single info line: NDL value + brief context
        dc.setColor(DR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, infoY, Graphics.FONT_XTINY,
                    "NDL " + ndlMins + "min  " + _riskExplain(score, ndlRat, rep, depth),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Scoring engine ────────────────────────────────────────────────────────

    // Returns [score(0-100), ndlRatio(float), ndlMins(int)]
    hidden function _calcScore(depth, time, fo2, rep) {
        var ndlV    = _ndl(depth, fo2);
        var ndlMins = ndlV.toNumber();
        if (ndlMins < 1) { ndlMins = 1; }

        // Depth component: 0–25 pts (linear, 40m = max)
        var depScore = (depth.toFloat() / 40.0 * 25.0);
        if (depScore > 25.0) { depScore = 25.0; }

        // NDL saturation: 0–40 pts — the primary risk driver
        // If time exceeds NDL, score is capped at 40 + overflow bonus (max 60 total)
        var ndlRatio = time.toFloat() / ndlV;
        var ndlScore;
        if (ndlRatio >= 1.0) {
            // Past NDL — scale up beyond 40
            ndlScore = 40.0 + (ndlRatio - 1.0) * 30.0;
            if (ndlScore > 70.0) { ndlScore = 70.0; }
        } else {
            ndlScore = ndlRatio * 40.0;
        }

        // Gas component: Air=8, Nitrox32=4, Nitrox36=1
        var gasScore = DRI_GAS_PTS[_gasIdx].toFloat();

        // Repetitive dive: +15 pts
        var repScore = rep ? 15.0 : 0.0;

        var total = depScore + ndlScore + gasScore + repScore;
        var score = total.toNumber();
        if (score > 100) { score = 100; }
        if (score < 0)   { score = 0; }

        _rScore = score; _rNdlRat = ndlRatio; _rNdlMins = ndlMins;
        return null;
    }

    // ── Risk classification ───────────────────────────────────────────────────

    hidden function _bgColor(score) {
        if (score <= 35) { return DR_BG_LOW; }
        if (score <= 65) { return DR_BG_MED; }
        return DR_BG_HIGH;
    }

    hidden function _riskColor(score) {
        if (score <= 35) { return DR_C_LOW; }
        if (score <= 65) { return DR_C_MED; }
        return DR_C_HIGH;
    }

    hidden function _riskLevel(score) {
        if (score <= 35) { return "LOW RISK"; }
        if (score <= 65) { return "MEDIUM RISK"; }
        return "HIGH RISK";
    }

    hidden function _riskExplain(score, ndlRatio, rep, depth) {
        // Short strings — must fit inline with "NDL Xm  " prefix on FONT_XTINY
        if (ndlRatio >= 1.0)     { return "DECO req!"; }
        if (score <= 35)         { return "Safe"; }
        if (score <= 65) {
            if (ndlRatio > 0.75) { return "Near limit"; }
            if (rep)             { return "Rep. N2 high"; }
            return "Moderate";
        }
        if (depth > 35)          { return "Deep limit"; }
        if (ndlRatio > 0.85)     { return "Near NDL!"; }
        return "High risk";
    }

    // ── Drawing helpers ───────────────────────────────────────────────────────

    hidden function _drawRow(dc, y, lbl, val, active, mg, rH) {
        var fXH = dc.getFontHeight(Graphics.FONT_XTINY);
        var ty = y + (rH - fXH) / 2;
        dc.setColor(active ? DR_ACCENT : DR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mg + 7, ty, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(active ? DR_WHITE : 0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - mg - 5, ty, Graphics.FONT_XTINY,
                    val + (active ? " <>" : ""), Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ── NDL table (PADI RDP, air) with EAD benefit for nitrox ────────────────
    hidden function _ndl(depth, fo2) {
        var effD = depth.toFloat();
        if (fo2 > 0.21) {
            var eadV = ((depth.toFloat() + 10.0) * (1.0 - fo2) / 0.79) - 10.0;
            if (eadV >= 0.0) { effD = eadV; }
        }
        var n = DRI_NDL_D.size();
        if (effD <= DRI_NDL_D[0].toFloat())     { return DRI_NDL_T[0].toFloat(); }
        if (effD >= DRI_NDL_D[n-1].toFloat())   { return DRI_NDL_T[n-1].toFloat(); }
        for (var i = 0; i < n - 1; i++) {
            var d0 = DRI_NDL_D[i].toFloat();
            var d1 = DRI_NDL_D[i + 1].toFloat();
            if (effD >= d0 && effD <= d1) {
                var t0 = DRI_NDL_T[i].toFloat();
                var t1 = DRI_NDL_T[i + 1].toFloat();
                return t0 + (t1 - t0) * (effD - d0) / (d1 - d0);
            }
        }
        return DRI_NDL_T[n-1].toFloat();
    }
}
