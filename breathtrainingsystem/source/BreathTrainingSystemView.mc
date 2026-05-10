using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.System;
using Toybox.Application;
using Toybox.Time;
using Toybox.Sensor;
using Toybox.Activity;
using Toybox.SensorHistory;
using Toybox.ActivityRecording;
using Toybox.FitContributor;

// ── Debug flag ────────────────────────────────────────────────────────────────
// Set to false to completely hide the "Gen Test User" option from Customize menu
const DBG_ENABLED = true;

const FT_HOME = 0;
const FT_BCFG = 1;
const FT_TCFG = 2;
const FT_ACT  = 3;
const FT_PAU  = 4;
const FT_DONE = 5;
const FT_CUST = 6;
const FT_STAT = 7;
const FT_NAME = 8;
const FT_MORE = 9;
const FT_PLAN = 10;
const FT_READY = 11;
const FT_RST   = 12;
const FT_HELP  = 13;
const FT_GTU   = 14;

const RD_REST  = 0;
const RD_LIGHT = 1;
const RD_READY = 2;

const RP_BREATHE = 0;
const RP_APNEA   = 1;
const RP_RESULT  = 2;

const PO_NORMAL = 0;
const PO_REPEAT = 1;
const PO_SKIP   = 2;

const FM_BR = 0;
const FM_AP = 1;
const FM_CO = 2;
const FM_O2 = 3;

const BP_INH = 0;
const BP_HI  = 1;
const BP_EXH = 2;
const BP_HE  = 3;
const BP_RST = 4;
const BP_HLD = 5;
const BP_PRP = 6;

// 5 presets + index 5 = Custom
//   0  Recovery 2-0-4-0      — slow recovery
//   1  Breathe-Up 3-0-6-0    — pre-dive prep
//   2  Box 4-4-4-4           — calm focus
//   3  Wim Hof Power 2-0-1-0 — power breathing (oxygenation)
//   4  Pranayama 4-7-8       — yogic relaxation (sleep / down-regulation)
const BR_PAT = [[2, 0, 4, 0], [3, 0, 6, 0], [4, 4, 4, 4], [2, 0, 1, 0], [4, 7, 8, 0]];
const BR_LBL = ["Recovery 2-4", "Breathe-Up 3-6", "Box 4-4-4-4", "Wim Hof Power", "Pranayama 4-7-8"];
const BR_PRESETS = 5;
const BR_INH = [2, 3, 4, 5, 6, 7, 8];
const BR_HLD = [0, 1, 2, 3, 4];
const BR_EXH = [3, 4, 5, 6, 7, 8, 10];
const BR_SES = [5, 10, 15, 20, 30];

const TBL_MX = [60, 90, 120, 150, 180, 210, 240, 300];
const TBL_RN = [6, 7, 8, 9, 10];
const NM_CH = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ";

const DP_EASY = 0;
const DP_STD  = 1;
const DP_HARD = 2;
const DP_LBL = ["Easy", "Standard", "Hard"];

const PL_NONE = -1;
const PL_BEG  = 0;
const PL_CO2  = 1;
const PL_APN  = 2;
const PL_O2   = 3;
const PL_BRTH = 4;
const PL_MIX  = 5;
const PL_STA  = 6;   // Static Apnea Performance — heavy holds, low CO2 noise
const PL_REC  = 7;   // Active Recovery — light breathing + short holds
const PL_COUNT = 8;
const PL_LBL  = ["Beginner",      "CO2 Tolerance",       "Apnea Progression",
                 "O2 Adaptation", "Breathwork Mastery",  "Endurance Mix",
                 "Static PB",     "Active Recovery"];
const PL_DESC = ["4 weeks intro", "Build CO2 tolerance", "Grow your hold",
                 "Hypoxia adapt", "Wim Hof + Pranayama", "Full spectrum",
                 "Push static PB","Light week reset"];

// ── HELP / LEGEND content ─────────────────────────────────────────────────
// Each entry is one text line.  Lines starting with "# " are section headers
// — the "# " prefix is stripped before rendering (only used for detection).
// Lines starting with "  " are indented sub-items.
const HLP_N = 65;
const HLP = [
    "# NAVIGATION",
    "SELECT: start / confirm",
    "UP / DOWN: scroll / change",
    "BACK: return / cancel",
    "HOME upper: quick-start mode",
    "HOME lower: Readiness / More",
    "# TRAINING MODES",
    "BR: Breathwork (relaxation)",
    "CO2: CO2 Table (tolerance)",
    "O2: O2 Table (adaptation)",
    "APNEA: timed hold + PB",
    "TABLE: set of BR+hold rounds",
    "# STATS PAGES  (TAP = next)",
    "P1 TRAINING: totals & PB",
    "P2 PROGRESSION: trend bars",
    "P3 PHYSIOLOGY: CO2/O2/REC",
    "P4 WEEKLY: week-by-week",
    "P5 SENSOR TRENDS: biometrics",
    "# SYMBOLS & ACRONYMS",
    "PB: Personal Best hold time",
    "^: score improving trend",
    "v: score declining trend",
    "Xd: streak (days in a row)",
    "Wk: current week summary",
    "# PHYSIOLOGY SCORES",
    "CO2 0-100: CO2 tolerance",
    "O2 0-100: O2 hypoxia adapt",
    "REC 0-100: recovery quality",
    "PLATEAU: no progress lately",
    "  -> vary your training",
    "DECLINE: scores dropping",
    "  -> rest day recommended",
    "OVERTRAIN: too much load",
    "  -> mandatory recovery",
    "PB 1:23 +5s: predicted PB",
    "# DIVER CLASSES",
    "BEGINNER: basics building",
    "CO2 FOCUSED: CO2 dominant",
    "O2 FOCUSED: hypoxia dominant",
    "BALANCED: even CO2 + O2",
    "ADVANCED: all metrics high",
    "# LIVE SENSOR CHIP",
    "Shown top-right in training",
    "72-8: HR=72, dropped 8 bpm",
    "  -> dive reflex active!",
    "72+5: HR=72, rose 5 bpm",
    "  -> elevated load",
    "Green pulse: reflex strong",
    "# SENSOR TRENDS PAGE",
    "DIVE REFLEX: HR drop/apnea",
    "PB -X: best HR drop ever",
    "CALM XX/100: breathup effect",
    "  Excellent>=70  Good>=45",
    "Dots: Body Battery at start",
    "  Green>=60  Gold>=30  Red<30",
    "RHR: resting heart rate",
    "SpO2: blood oxygen (>=96%ok)",
    "# READINESS CHECK",
    "30s calm breath + max hold",
    "READY: full intensity OK",
    "LIGHT SESSION: easy today",
    "REST: skip training today",
    "# TRAINING PLAN",
    "Adaptive multi-week program",
    "Plan adjusts to your results",
    "Access via More -> Train Plan"];

const TS_RECOVERY = 0;
const TS_BUILDING = 1;
const TS_STABLE   = 2;
const TS_PEAK     = 3;
const TS_LBL = ["RECOVERY", "BUILDING", "STABLE", "PEAK"];

// Plan sessions encoded as [mode, p1, p2, p3]
// BR: [0, brM, brSI, 0]   where brM<3 uses preset
// AP: [1, 0, 0, 0]
// CO: [2, mxI, rnI, diff]
// O2: [3, mxI, rnI, diff]
const PL_BEG_S = [
    [0, 0, 0, 0], [0, 2, 0, 0], [1, 0, 0, 0], [2, 2, 0, 0],
    [0, 1, 1, 0], [2, 2, 1, 0], [1, 0, 0, 0], [2, 2, 2, 1],
    [3, 2, 0, 0], [1, 0, 0, 0]
];
const PL_CO2_S = [
    [2, 1, 0, 0], [2, 1, 1, 0], [2, 1, 2, 1], [2, 2, 1, 1],
    [0, 0, 0, 0], [2, 2, 2, 1], [2, 2, 2, 2], [2, 4, 1, 2],
    [0, 1, 1, 0], [2, 4, 2, 2]
];
const PL_APN_S = [
    [0, 1, 1, 0], [1, 0, 0, 0], [3, 1, 0, 0], [1, 0, 0, 0],
    [0, 2, 1, 0], [3, 2, 1, 1], [1, 0, 0, 0], [3, 4, 1, 1],
    [0, 1, 1, 0], [1, 0, 0, 0]
];
// O2 Adaptation: hypoxia-focused — heavy O2 tables + apnea
// ── Demo tour ───────────────────────────────────────────────────────────
// Marketing tour: 8 slides, ~30s, mixes intelligence, live training, and
// stats dashboards. Any input cancels and returns to HOME.
//   0 HOME (overlay) | 1 BREATHE | 2 APNEA | 3 CO2 TABLE
//   4 STATS prog     | 5 STATS physio | 6 STATS weekly | 7 HOME (outro)
const DEMO_LEN = [30, 40, 35, 35, 30, 35, 35, 30, 20];   // ticks (10/sec)
const DEMO_COUNT = 9;

const PL_O2_S = [
    [0, 1, 1, 0], [3, 1, 1, 0], [3, 2, 1, 1], [1, 0, 0, 0],
    [3, 2, 2, 1], [0, 0, 0, 0], [3, 3, 1, 1], [1, 0, 0, 0],
    [3, 4, 2, 2], [3, 4, 2, 2]
];
// Breathwork Mastery: 5 presets cycled, plus apnea finishers
const PL_BRTH_S = [
    [0, 0, 0, 0], [0, 1, 1, 0], [0, 2, 2, 0], [0, 3, 1, 0],
    [0, 4, 1, 0], [1, 0, 0, 0], [0, 3, 2, 0], [0, 4, 2, 0],
    [0, 2, 3, 0], [1, 0, 0, 0]
];
// Endurance Mix: full spectrum — covers BR/CO2/O2/AP equally
const PL_MIX_S = [
    [0, 1, 1, 0], [2, 2, 1, 0], [3, 2, 1, 0], [1, 0, 0, 0],
    [0, 3, 1, 0], [2, 3, 1, 1], [3, 3, 1, 1], [1, 0, 0, 0],
    [0, 4, 2, 0], [2, 4, 2, 2]
];
// Static Apnea PB: minimal CO2 chatter, heavy max-effort holds + recovery breathing
const PL_STA_S = [
    [0, 1, 1, 0], [1, 0, 0, 0], [0, 0, 0, 0], [1, 0, 0, 0],
    [0, 4, 1, 0], [1, 0, 0, 0], [0, 1, 2, 0], [1, 0, 0, 0],
    [0, 4, 2, 0], [1, 0, 0, 0]
];
// Active Recovery: gentle week — light breathwork + sub-max holds, no high CO2
const PL_REC_S = [
    [0, 0, 0, 0], [0, 1, 1, 0], [0, 3, 1, 0], [3, 1, 0, 0],
    [0, 0, 1, 0], [0, 4, 1, 0], [3, 1, 1, 0], [0, 2, 1, 0],
    [0, 1, 2, 0], [0, 0, 1, 0]
];

class BreathTrainingSystemView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick; hidden var _sub;
    hidden var _gs; hidden var _mode;

    hidden var _hSel; hidden var _mSel; hidden var _hlSel; hidden var _lastMode;

    hidden var _svCoMx; hidden var _svCoRn;
    hidden var _svO2Mx; hidden var _svO2Rn;
    hidden var _svBrM; hidden var _svBrII; hidden var _svBrHI;
    hidden var _svBrEI; hidden var _svBrXI; hidden var _svBrSI;

    hidden var _brM; hidden var _brF;
    hidden var _brII; hidden var _brHI; hidden var _brEI; hidden var _brXI; hidden var _brSI;
    hidden var _brPat;
    hidden var _brPh; hidden var _brPD; hidden var _brPE; hidden var _brPS;
    hidden var _brRem; hidden var _brSS; hidden var _brBC; hidden var _brTrans;

    hidden var _tMxI; hidden var _tRnI; hidden var _tF;
    hidden var _tRnd; hidden var _tTR;
    hidden var _tPh; hidden var _tPS; hidden var _tPE; hidden var _tPSub;
    hidden var _tH; hidden var _tR;

    hidden var _apE; hidden var _apPS; hidden var _apPB; hidden var _apLS;
    hidden var _apNP; hidden var _apLog; hidden var _apWS; hidden var _apCS; hidden var _apWF;

    hidden var _cF; hidden var _nmPos; hidden var _nmChrs; hidden var _thIdx; hidden var _nmStr;
    hidden var _vibOn;
    hidden var _cstRowY0; hidden var _cstRowY1; hidden var _cstRowY2; hidden var _cstRowY3;
    hidden var _cINH; hidden var _cHI; hidden var _cEXH; hidden var _cHE;
    hidden var _cPRP; hidden var _cRST; hidden var _cHLD;
    hidden var _actSes;  // ActivityRecording session (null = inactive)
    hidden var _stBrC; hidden var _stBrT; hidden var _stApC;
    hidden var _stCoC; hidden var _stO2C; hidden var _stTotT;
    hidden var _stPg;

    hidden var _tDiff;
    hidden var _svCoDf; hidden var _svO2Df;

    hidden var _plAct; hidden var _plDay; hidden var _plSel;
    hidden var _plFromPlan;

    hidden var _stSucCo; hidden var _stFailCo;
    hidden var _stSucO2; hidden var _stFailO2;
    hidden var _stSucAp; hidden var _stFailAp;
    hidden var _stStreak; hidden var _stLastDay;
    hidden var _stHoldT;

    hidden var _apHist;

    hidden var _rdLast;
    hidden var _rdPh; hidden var _rdT; hidden var _rdSub;
    hidden var _rdApE; hidden var _rdBrPh;

    hidden var _pauseCnt;
    hidden var _plLastOut;
    hidden var _rdDowngrade;

    // ── PHYSIO LAYER (PRO++) ─────────────────────────────────────────────────
    // CO2 tolerance
    hidden var _coTolScore; hidden var _coLastLoad; hidden var _coTrend;
    // O2 adaptation
    hidden var _o2AdaptScore; hidden var _o2PeakRatio; hidden var _o2Trend;
    // Recovery (breathe)
    hidden var _brRecScore; hidden var _brEffectLast;
    // Session quality score
    hidden var _stScoreLast; hidden var _stScoreAvg;
    // PB prediction
    hidden var _pbPredicted; hidden var _pbConfidence;
    // Diver profile
    hidden var _diverCo2; hidden var _diverO2; hidden var _diverRecovery;
    // Pattern flags
    hidden var _ptPlateauFlag; hidden var _ptDeclineFlag; hidden var _ptOvertrainFlag;
    // Last-load history for trend (3 entries — used by _trend3())
    hidden var _coLoadHist; hidden var _o2LoadHist;
    // Visual trend history (5 entries each, oldest..newest = idx 4..0) for histograms
    hidden var _coVHist; hidden var _o2VHist; hidden var _brVHist;
    // Pre-session apnea PB snapshot (for delta tracking)
    hidden var _apPrevPB;
    // Micro-feedback latch (apnea phase)
    hidden var _mfFlags;

    // ── SENSOR HUB (PRO++ v5) ────────────────────────────────────────
    // Live Garmin-sensor integration with graceful fallback. Every call is
    // wrapped in try/catch — when a sensor is unavailable (older watch, perm
    // denied, no chest strap) the app behaves exactly like before.
    //
    //   _snOn         — user toggle (Customize → Sensors). Persisted as `usr_sn`.
    //   _snAvail      — bitmap of detected capabilities at runtime:
    //                     0x01 HR  0x02 BodyBattery  0x04 Stress
    //                     0x08 SpO2  0x10 RestingHR
    //   _snHrCur      — current live HR (0 = no reading)
    //   _snHrStart    — HR snapshot at session start (apnea baseline)
    //   _snHrMin      — lowest HR observed during current apnea
    //   _snHrPeak     — highest HR observed during current session
    //   _snBodyBatt   — Body Battery 0..100 (-1 = unavailable)
    //   _snStress     — Stress 0..100 (-1 = unavailable)
    //   _snSpo2       — SpO2 % (-1 = unavailable)
    //   _snRestHr     — Resting HR baseline (last 24h average)
    //   _snBradLast   — Bradycardia delta (BPM drop) of last apnea
    //   _snBradBest   — All-time best bradycardia delta
    //   _snHrEnabled  — true when Sensor.setEnabledSensors([HR]) succeeded
    //   _snLastReadT  — _tick of last sensor poll (rate-limit to ~1Hz)
    //
    // ── Sensor TREND data (persisted, used by SENSOR TRENDS stats page) ──
    //   _snBradHist   — Array[5] of last apnea brad-deltas (newest last)
    //   _snCalmLast   — Calm score of last breathe session (0..100)
    //   _snCalmAvg    — EMA calm score across all breathe sessions (0..100)
    //   _snBbAtStart  — Array[5] of Body Battery values at session start
    //   _snHrDropAvg  — EMA of HR drop during breathe-up (resting→min, BPM)
    hidden var _snOn; hidden var _snAvail;
    hidden var _snHrCur; hidden var _snHrStart;
    hidden var _snHrMin; hidden var _snHrPeak;
    hidden var _snBodyBatt; hidden var _snStress;
    hidden var _snSpo2; hidden var _snRestHr;
    hidden var _snBradLast; hidden var _snBradBest;
    hidden var _snHrEnabled; hidden var _snLastReadT;
    hidden var _snBradHist; hidden var _snCalmLast;
    hidden var _snCalmAvg;  hidden var _snBbAtStart;
    hidden var _snHrDropAvg;

    // ── WEEKLY STATS (8-week rolling buckets) ────────────────────────
    // _wkSes[0]  = current week sessions count, [7] = oldest
    // _wkHold[0] = current week hold seconds (apnea + table holds)
    // _wkBaseDay = epoch day index when wk[0] started (week anchor)
    // _wkBestSes = best single-week session count ever
    hidden var _wkSes; hidden var _wkHold;
    hidden var _wkBaseDay; hidden var _wkBestSes;
    // 14-day rolling activity bitmap; bit 0 = today, bit i = i days ago.
    // Used to compute 7d / 14d consistency (% of days with ≥1 session).
    hidden var _dayBits; hidden var _dayBitsRef;

    // ── DEMO MODE (marketing tour after Gen Test User) ───────────────────
    hidden var _demoMode;   // 0 = off, 1 = active
    hidden var _demoT;      // ticks elapsed (100ms each)
    hidden var _demoSlide;  // current slide index (0..N-1)

    function initialize() {
        View.initialize();
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _tick = 0; _sub = 0;
        _actSes = null;
        _gs = FT_HOME; _hSel = 0; _mSel = 0; _hlSel = 0;

        var lm = Application.Storage.getValue("lst_md");
        _lastMode = (lm instanceof Number && lm >= 0 && lm <= 3) ? lm : FM_CO;
        _loadPresets();

        _brM = _svBrM; _brF = 0;
        _brII = _svBrII; _brHI = _svBrHI; _brEI = _svBrEI; _brXI = _svBrXI; _brSI = _svBrSI;
        _brPat = [4, 0, 6, 0];
        _brPh = BP_INH; _brPD = 4; _brPE = 0; _brPS = 0;
        _brRem = 0; _brSS = 0; _brBC = 0; _brTrans = 0;

        _tMxI = _svCoMx; _tRnI = _svCoRn; _tF = 0; _tDiff = DP_STD;
        _tRnd = 0; _tTR = 8;
        _tPh = BP_PRP; _tPS = 0; _tPE = 0; _tPSub = 0;
        _tH = new [10]; _tR = new [10];
        _plFromPlan = false; _stPg = 0;

        _apE = 0; _apPS = -1; _apLS = 0; _apNP = false; _apWF = false;
        var sp = Application.Storage.getValue("ap_pb");
        _apPB = (sp instanceof Number) ? sp : 0;
        _apLog = new [3];
        for (var i = 0; i < 3; i++) {
            var v = Application.Storage.getValue("ap_lg" + i.toString());
            _apLog[i] = (v instanceof Number) ? v : 0;
        }
        _calcApTh();

        _cF = 0; _nmPos = 0;
        _cstRowY0 = 0; _cstRowY1 = 0; _cstRowY2 = 0; _cstRowY3 = 0;
        var th = Application.Storage.getValue("usr_thm");
        _thIdx = (th instanceof Number) ? th : 0;
        var vb = Application.Storage.getValue("usr_vib");
        _vibOn = (vb instanceof Toybox.Lang.Boolean) ? vb : true;
        _nmChrs = new [8];
        var nm = Application.Storage.getValue("usr_nm");
        if (!(nm instanceof Toybox.Lang.String)) { nm = "USER"; }
        for (var ni = 0; ni < 8; ni++) {
            if (ni < nm.length()) {
                var idx = NM_CH.find(nm.substring(ni, ni + 1));
                _nmChrs[ni] = (idx != null) ? idx : 36;
            } else { _nmChrs[ni] = 36; }
        }
        _nmStr = _bldNm();
        _applyTheme();
        var sv;
        sv = Application.Storage.getValue("st_brc"); _stBrC = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_brt"); _stBrT = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_apc"); _stApC = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_coc"); _stCoC = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_o2c"); _stO2C = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_tot"); _stTotT = (sv instanceof Number) ? sv : 0;

        sv = Application.Storage.getValue("st_suc_co"); _stSucCo = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_fail_co"); _stFailCo = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_suc_o2"); _stSucO2 = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_fail_o2"); _stFailO2 = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_suc_ap"); _stSucAp = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_fail_ap"); _stFailAp = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_streak"); _stStreak = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_lastday"); _stLastDay = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("st_holdt"); _stHoldT = (sv instanceof Number) ? sv : 0;

        _apHist = new [5];
        for (var hi = 0; hi < 5; hi++) {
            var hv = Application.Storage.getValue("ap_h" + hi.toString());
            _apHist[hi] = (hv instanceof Number) ? hv : 0;
        }

        sv = Application.Storage.getValue("pl_act");
        _plAct = (sv instanceof Number && sv >= -1 && sv < PL_COUNT) ? sv : PL_NONE;
        sv = Application.Storage.getValue("pl_day");
        _plDay = (sv instanceof Number && sv >= 0 && sv < 10) ? sv : 0;
        _plSel = 0;

        sv = Application.Storage.getValue("rd_last");
        _rdLast = (sv instanceof Number && sv >= 0 && sv <= 2) ? sv : -1;

        _pauseCnt = 0; _plLastOut = PO_NORMAL;
        _rdPh = 0; _rdT = 0; _rdSub = 0; _rdApE = 0; _rdBrPh = 0;
        _rdDowngrade = false;

        _loadPhysio();
        _snInit();
    }

    // ── PHYSIO LAYER ─────────────────────────────────────────────────────────
    hidden function _loadPhysio() {
        var v;
        // Defaults are 0 (true blank slate). Models clamp 0..100 and accumulate
        // from there as the user trains; renderer treats 0 as "no data yet" and
        // shows cold-start hints instead of misleading mid-range bars.
        v = Application.Storage.getValue("co_tol_score");   _coTolScore   = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("co_last_load");   _coLastLoad   = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("co_trend");       _coTrend      = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("o2_adapt_score"); _o2AdaptScore = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("o2_peak_ratio");  _o2PeakRatio  = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("o2_trend");       _o2Trend      = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("br_rec_score");   _brRecScore   = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("br_effect_last"); _brEffectLast = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("st_score_last");  _stScoreLast  = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("st_score_avg");   _stScoreAvg   = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("pb_predicted");   _pbPredicted  = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("pb_confidence");  _pbConfidence = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("diver_co2");      _diverCo2     = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("diver_o2");       _diverO2      = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("diver_rec");      _diverRecovery= (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("pt_plateau");     _ptPlateauFlag= (v instanceof Boolean) ? v : false;
        v = Application.Storage.getValue("pt_decline");     _ptDeclineFlag= (v instanceof Boolean) ? v : false;
        v = Application.Storage.getValue("pt_overtrain");   _ptOvertrainFlag= (v instanceof Boolean) ? v : false;

        _coLoadHist = new [3];
        _o2LoadHist = new [3];
        for (var i = 0; i < 3; i++) {
            v = Application.Storage.getValue("co_lh" + i.toString());
            _coLoadHist[i] = (v instanceof Number) ? v : 0;
            v = Application.Storage.getValue("o2_lh" + i.toString());
            _o2LoadHist[i] = (v instanceof Number) ? v : 0;
        }
        _coVHist = new [5]; _o2VHist = new [5]; _brVHist = new [5];
        for (var k = 0; k < 5; k++) {
            v = Application.Storage.getValue("co_vh" + k.toString());
            _coVHist[k] = (v instanceof Number) ? v : 0;
            v = Application.Storage.getValue("o2_vh" + k.toString());
            _o2VHist[k] = (v instanceof Number) ? v : 0;
            v = Application.Storage.getValue("br_vh" + k.toString());
            _brVHist[k] = (v instanceof Number) ? v : 0;
        }
        _apPrevPB = _apPB;
        _mfFlags = 0;
        _demoMode = 0; _demoT = 0; _demoSlide = 0;

        _loadWeekly();
    }

    // ── WEEKLY ROLLING BUCKETS ───────────────────────────────────────────
    hidden function _curEpochDay() {
        return Time.now().value() / 86400;
    }

    hidden function _loadWeekly() {
        var v;
        _wkSes  = new [8];
        _wkHold = new [8];
        for (var i = 0; i < 8; i++) {
            v = Application.Storage.getValue("wk_s" + i.toString());
            _wkSes[i]  = (v instanceof Number) ? v : 0;
            v = Application.Storage.getValue("wk_h" + i.toString());
            _wkHold[i] = (v instanceof Number) ? v : 0;
        }
        v = Application.Storage.getValue("wk_base");  _wkBaseDay = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("wk_best");  _wkBestSes = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("dy_bits");  _dayBits   = (v instanceof Number) ? v : 0;
        v = Application.Storage.getValue("dy_ref");   _dayBitsRef= (v instanceof Number) ? v : 0;
    }

    hidden function _persistWeekly() {
        for (var i = 0; i < 8; i++) {
            Application.Storage.setValue("wk_s" + i.toString(), _wkSes[i]);
            Application.Storage.setValue("wk_h" + i.toString(), _wkHold[i]);
        }
        Application.Storage.setValue("wk_base", _wkBaseDay);
        Application.Storage.setValue("wk_best", _wkBestSes);
        Application.Storage.setValue("dy_bits", _dayBits);
        Application.Storage.setValue("dy_ref",  _dayBitsRef);
    }

    // Roll the week buckets so wk[0] always represents the week containing `today`.
    hidden function _advanceWeeks(today) {
        if (_wkBaseDay <= 0) { _wkBaseDay = today; return; }
        var delta = today - _wkBaseDay;
        if (delta < 7) { return; }
        var shift = delta / 7;
        if (shift >= 8) {
            for (var i = 0; i < 8; i++) { _wkSes[i] = 0; _wkHold[i] = 0; }
        } else {
            for (var i = 7; i >= shift; i--) {
                _wkSes[i]  = _wkSes[i - shift];
                _wkHold[i] = _wkHold[i - shift];
            }
            for (var j = 0; j < shift; j++) { _wkSes[j] = 0; _wkHold[j] = 0; }
        }
        _wkBaseDay = _wkBaseDay + shift * 7;
    }

    // Roll the 14-day bitmap so bit 0 always refers to `today`.
    hidden function _advanceDayBits(today) {
        if (_dayBitsRef <= 0) { _dayBitsRef = today; _dayBits = 0; return; }
        var d = today - _dayBitsRef;
        if (d <= 0) { return; }
        if (d >= 14) { _dayBits = 0; }
        else { _dayBits = (_dayBits << d) & 0x3FFF; }
        _dayBitsRef = today;
    }

    // Called when ANY session ends (BR/AP/CO2/O2). Bumps current week + marks today active.
    hidden function _bumpWeekly(holdSec) {
        var today = _curEpochDay();
        _advanceWeeks(today);
        _advanceDayBits(today);
        _wkSes[0]  = _wkSes[0] + 1;
        _wkHold[0] = _wkHold[0] + holdSec;
        if (_wkSes[0] > _wkBestSes) { _wkBestSes = _wkSes[0]; }
        _dayBits = _dayBits | 1;
        _persistWeekly();
    }

    // Count low N bits of the day bitmap (active days in last N).
    hidden function _activeDays(n) {
        var c = 0;
        for (var i = 0; i < n; i++) {
            if (((_dayBits >> i) & 1) == 1) { c++; }
        }
        return c;
    }

    hidden function _wkSesTotal() {
        var t = 0;
        for (var i = 0; i < 8; i++) { t += _wkSes[i]; }
        return t;
    }

    hidden function _wkSesMax() {
        var m = 0;
        for (var i = 0; i < 8; i++) { if (_wkSes[i] > m) { m = _wkSes[i]; } }
        return m;
    }

    // ── SENSOR HUB ───────────────────────────────────────────────────
    // Self-contained Garmin-sensor integration. All API calls are wrapped
    // in try/catch — any unsupported sensor / older watch falls back to
    // the same baseline UX as v4 (no badges, no HR overlays).
    //
    // Sensor surface used:
    //   • Live HR via Sensor.setEnabledSensors([SENSOR_HEARTRATE]) +
    //     Activity.getActivityInfo().currentHeartRate (lightweight)
    //   • SensorHistory for body battery / stress / SpO2 / resting HR
    //
    // Detection runs once at app start; downstream code reads `_snAvail`
    // bitmap to decide whether to render a badge / take a measurement.
    hidden function _snInit() {
        var sv = Application.Storage.getValue("usr_sn");
        _snOn = (sv instanceof Boolean) ? sv : true;
        sv = Application.Storage.getValue("sn_brad_best");
        _snBradBest = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("sn_brad_last");
        _snBradLast = (sv instanceof Number) ? sv : 0;

        // Sensor trend history — 5-slot ring arrays
        sv = Application.Storage.getValue("sn_brad_hist");
        _snBradHist = (sv instanceof Array) ? sv : [0, 0, 0, 0, 0];
        sv = Application.Storage.getValue("sn_calm_last");
        _snCalmLast = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("sn_calm_avg");
        _snCalmAvg  = (sv instanceof Number) ? sv : 0;
        sv = Application.Storage.getValue("sn_bb_start");
        _snBbAtStart = (sv instanceof Array) ? sv : [-1, -1, -1, -1, -1];
        sv = Application.Storage.getValue("sn_hr_drop_avg");
        _snHrDropAvg = (sv instanceof Number) ? sv : 0;

        _snHrCur = 0; _snHrStart = 0; _snHrMin = 0; _snHrPeak = 0;
        _snBodyBatt = -1; _snStress = -1; _snSpo2 = -1; _snRestHr = 0;
        _snAvail = 0; _snHrEnabled = false; _snLastReadT = -100;

        if (!_snOn) { return; }

        // Try enabling HR sensor — fail silently if perm denied / unsupported
        try {
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
            _snHrEnabled = true;
        } catch (e) {
            _snHrEnabled = false;
        }

        _snDetectAvailability();
    }

    // Probe each sensor source once; record what works in `_snAvail`.
    hidden function _snDetectAvailability() {
        // Live HR — try Activity.Info first (most reliable on watches)
        var hr = _snReadHrRaw();
        if (hr > 0) { _snAvail = _snAvail | 0x01; _snHrCur = hr; }

        // Body Battery
        var bb = _snReadBodyBatt();
        if (bb >= 0) { _snAvail = _snAvail | 0x02; _snBodyBatt = bb; }

        // Stress
        var st = _snReadStress();
        if (st >= 0) { _snAvail = _snAvail | 0x04; _snStress = st; }

        // SpO2
        var ox = _snReadSpo2();
        if (ox >= 0) { _snAvail = _snAvail | 0x08; _snSpo2 = ox; }

        // Resting HR
        var rh = _snReadRestingHr();
        if (rh > 0) { _snAvail = _snAvail | 0x10; _snRestHr = rh; }
    }

    // Defensive HR read — returns BPM or 0.
    hidden function _snReadHrRaw() {
        // 1. Activity.Info — works if the watch is in an active fitness
        //    recording, but returns null in plain watch apps most of the time.
        try {
            var info = Activity.getActivityInfo();
            if (info != null && info.currentHeartRate != null && info.currentHeartRate > 0) {
                return info.currentHeartRate;
            }
        } catch (e) {}
        // 2. Sensor.getInfo() — works when setEnabledSensors([HEARTRATE])
        //    succeeded; most reliable on-wrist live source.
        try {
            var sinfo = Sensor.getInfo();
            if (sinfo != null && sinfo.heartRate != null && sinfo.heartRate > 0) {
                return sinfo.heartRate;
            }
        } catch (e) {}
        // 3. SensorHistory fallback — returns the last recorded HR (usually
        //    ≤ 30 s old on Garmin optical HR watches). Works without needing
        //    setEnabledSensors to have succeeded — just needs SensorHistory perm.
        try {
            if (SensorHistory has :getHeartRateHistory) {
                var it = SensorHistory.getHeartRateHistory({ :period => 1 });
                if (it != null) {
                    var sample = it.next();
                    if (sample != null && sample.data != null) {
                        var hr = sample.data.toNumber();
                        if (hr > 0) { return hr; }
                    }
                }
            }
        } catch (e) {}
        return 0;
    }

    // Generic SensorHistory single-sample read (latest value).
    hidden function _snLatestSample(iter) {
        if (iter == null) { return null; }
        try {
            var s = iter.next();
            if (s != null && s.data != null) { return s.data; }
        } catch (e) {}
        return null;
    }

    hidden function _snReadBodyBatt() {
        try {
            if (SensorHistory has :getBodyBatteryHistory) {
                var it = SensorHistory.getBodyBatteryHistory({ :period => 1 });
                var v = _snLatestSample(it);
                if (v != null) { return v.toNumber(); }
            }
        } catch (e) {}
        return -1;
    }

    hidden function _snReadStress() {
        try {
            if (SensorHistory has :getStressHistory) {
                var it = SensorHistory.getStressHistory({ :period => 1 });
                var v = _snLatestSample(it);
                if (v != null) { return v.toNumber(); }
            }
        } catch (e) {}
        return -1;
    }

    hidden function _snReadSpo2() {
        try {
            if (SensorHistory has :getOxygenSaturationHistory) {
                var it = SensorHistory.getOxygenSaturationHistory({ :period => 1 });
                var v = _snLatestSample(it);
                if (v != null) { return v.toNumber(); }
            }
        } catch (e) {}
        return -1;
    }

    // Resting HR baseline = avg of last 24h HR samples (rough, but free).
    hidden function _snReadRestingHr() {
        try {
            if (SensorHistory has :getHeartRateHistory) {
                var it = SensorHistory.getHeartRateHistory({ :period => 1 });
                var v = _snLatestSample(it);
                if (v != null && v > 0) { return v.toNumber(); }
            }
        } catch (e) {}
        return 0;
    }

    // Called every tick during active sessions — rate-limited to ~1Hz so
    // we don't beat the API or the battery. Tracks min HR (bradycardia)
    // and peak HR throughout the session. Polls regardless of whether
    // setEnabledSensors succeeded — Activity.getActivityInfo() may still
    // return a usable currentHeartRate on watches with native HR.
    hidden function _snTick() {
        if (!_snOn) { return; }
        if (_tick - _snLastReadT < 5) { return; }   // ≤ 1Hz reads
        _snLastReadT = _tick;

        var hr = _snReadHrRaw();
        if (hr <= 0) { return; }
        _snHrCur = hr;
        _snAvail = _snAvail | 0x01;   // mark HR available lazily on first reading
        if (_snHrMin == 0 || hr < _snHrMin) { _snHrMin = hr; }
        if (hr > _snHrPeak) { _snHrPeak = hr; }
    }

    // Called at the start of any active session — snapshots HR baseline.
    // Preserves any pre-existing _snHrCur (e.g. seeded by Gen Test User
    // OR last reading from HOME idle loop) so simulator / no-HR watches
    // still display SOMETHING during training instead of a blank chip.
    hidden function _snSessionStart() {
        if (!_snOn) { _snHrStart = 0; _snHrMin = 0; _snHrPeak = 0; return; }
        var hr = _snReadHrRaw();
        if (hr <= 0) { hr = _snHrCur; }   // fall back to last-known
        if (hr > 0) {
            _snHrStart = hr;
            _snHrCur   = hr;
            _snHrMin   = hr;
            _snHrPeak  = hr;
        } else {
            _snHrStart = 0; _snHrMin = 0; _snHrPeak = 0;
        }
        _snLastReadT = _tick;
    }

    // Called at end of an apnea — computes bradycardia delta (start − min)
    // and persists best-ever value. Apnea-only because that's where the
    // mammalian dive reflex actually shows up.
    hidden function _snSessionEndAp() {
        _snBradLast = 0;
        if (!_snOn || !_snHrEnabled || _snHrStart <= 0 || _snHrMin <= 0) { return; }
        var d = _snHrStart - _snHrMin;
        if (d < 0) { d = 0; }
        _snBradLast = d;
        if (d > _snBradBest) {
            _snBradBest = d;
            Application.Storage.setValue("sn_brad_best", _snBradBest);
        }
        Application.Storage.setValue("sn_brad_last", _snBradLast);

        // Push to 5-slot brad history (shift left, append newest)
        _snBradHist[0] = _snBradHist[1];
        _snBradHist[1] = _snBradHist[2];
        _snBradHist[2] = _snBradHist[3];
        _snBradHist[3] = _snBradHist[4];
        _snBradHist[4] = _snBradLast;
        Application.Storage.setValue("sn_brad_hist", _snBradHist);

        // Also record body battery at session start for the SENSOR TRENDS page
        _snBbAtStart[0] = _snBbAtStart[1];
        _snBbAtStart[1] = _snBbAtStart[2];
        _snBbAtStart[2] = _snBbAtStart[3];
        _snBbAtStart[3] = _snBbAtStart[4];
        _snBbAtStart[4] = (_snBodyBatt >= 0) ? _snBodyBatt : -1;
        Application.Storage.setValue("sn_bb_start", _snBbAtStart);
    }

    // Push current Body Battery into the 5-slot at-start history.
    // Called by CO2/O2 table endings so the SENSOR TRENDS page can show
    // readiness-at-training across all session types.
    hidden function _snPushBbAtStart() {
        if (!_snOn) { return; }
        _snBbAtStart[0] = _snBbAtStart[1];
        _snBbAtStart[1] = _snBbAtStart[2];
        _snBbAtStart[2] = _snBbAtStart[3];
        _snBbAtStart[3] = _snBbAtStart[4];
        _snBbAtStart[4] = (_snBodyBatt >= 0) ? _snBodyBatt : -1;
        Application.Storage.setValue("sn_bb_start", _snBbAtStart);
    }

    // Called at end of a BREATHE session. Calculates calm score (0..100)
    // from how much HR dropped during the breathe-up relative to baseline.
    // Score = min(100, hrDrop * 8) — a 12-BPM drop = 96/100, which is
    // excellent breathwork response. Updates EMA calm avg (α=0.3) and
    // persists everything. Also records Body Battery at session end.
    hidden function _snSessionEndBr() {
        if (!_snOn) { return; }
        var drop = (_snHrStart > 0 && _snHrMin > 0) ? (_snHrStart - _snHrMin) : 0;
        if (drop < 0) { drop = 0; }

        // HR drop trend avg (EMA α=0.35, ignores sessions with no HR data)
        if (drop > 0) {
            if (_snHrDropAvg == 0) { _snHrDropAvg = drop; }
            else { _snHrDropAvg = (_snHrDropAvg * 65 + drop * 35) / 100; }
            Application.Storage.setValue("sn_hr_drop_avg", _snHrDropAvg);
        }

        // Calm score: how well the breathe-up suppressed HR (0..100)
        var score = drop * 8;
        if (score > 100) { score = 100; }
        _snCalmLast = score;
        if (_snCalmAvg == 0) { _snCalmAvg = score; }
        else { _snCalmAvg = (_snCalmAvg * 70 + score * 30) / 100; }
        Application.Storage.setValue("sn_calm_last", _snCalmLast);
        Application.Storage.setValue("sn_calm_avg", _snCalmAvg);

        _snPushBbAtStart();
    }

    // True when ANY sensor reading is available right now.
    hidden function _snAnyAvail() {
        return _snOn && _snAvail != 0;
    }

    // ── Sensor UI helpers ────────────────────────────────────────────
    // ALL training/home screens render sensor data in a unified vertical
    // RIGHT-EDGE column (or single right-edge chip for active screens).
    //
    // Round-watch geometry: at x=88% (offset 38 from center 50%), the
    // safe y-range is roughly [17%, 83%], so we keep all chips inside
    // y∈[28,68]%. Each chip is FONT_XTINY, right-justified at x=88%,
    // color-coded so users can read a sensor at a glance even peripherally.
    //
    // Chip color legend (uniform across modes/themes for muscle memory):
    //   HR   — pink-red  0xFF6688
    //   BB   — green     0x66DD88   (orange when low)
    //   SpO2 — cyan      0x66CCDD
    //   Brad — violet    0xAA88FF
    hidden function _snColX() { return _w * 88 / 100; }

    // Heart icon — a compact 5x4 pixel cluster forming a heart shape.
    // Drawn left of an HR chip so the sensor is visible peripherally.
    hidden function _snDrHeart(dc, x, y, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 2, y, 2);
        dc.fillCircle(x + 2, y, 2);
        dc.fillRectangle(x - 3, y, 7, 2);
        dc.fillCircle(x, y + 3, 2);
    }

    // Single live-HR chip on the right edge — used by ACTIVE training
    // screens (apnea / breathe / table). Placed at y=18% (top strip) so it
    // never overlaps the central circle/ball/timer on any screen.
    //
    // Format: just the BPM value (e.g. "72"). Delta only shown when ≥5 BPM
    // to avoid numeric noise — "-8" = HR dropping (calm/dive), "+6" = rising.
    // Tiny filled circle replaces the 5-primitive heart shape to reduce clutter.
    // `calmMode=true` (BREATHE phase) lowers the green threshold to 5 BPM drop.
    hidden function _snDrLive(dc, y, calmMode) {
        if (!_snOn || _snHrCur <= 0) { return false; }
        var rx = _snColX();
        var dlt = (_snHrStart > 0) ? (_snHrStart - _snHrCur) : 0;
        var calmThresh = calmMode ? 5 : 10;

        var c = 0xFF6688;
        if (dlt >= calmThresh) {
            c = (_tick % 10 < 5) ? _cHLD : _lighten(_cHLD, 25);
        } else if (dlt <= -5) {
            c = 0xFFA060;
        }

        // BPM text right-justified at rx
        var s = _snHrCur.toString();
        if (dlt >= 5)       { s = s + "-" + dlt; }
        else if (dlt <= -5) { s = s + "+" + (-dlt); }
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rx, y, Graphics.FONT_XTINY, s, Graphics.TEXT_JUSTIFY_RIGHT);

        // Tiny dot indicator placed RIGHT of the text (rx+8) so it can never
        // overlap the text characters — previous position rx-22 landed inside
        // the text area for longer strings like "80-17" causing the "-" to
        // visually merge with the dot and look like a garbled character.
        dc.fillCircle(rx + 8, y + 5, 2);
        return true;
    }

    // Full vertical sensor column — used by HOME (and any place we want
    // a complete bio dashboard). Renders up to 4 chips top-to-bottom.
    // Caller picks the starting y; each chip auto-skips if its sensor
    // isn't available, so the column collapses naturally on watches
    // missing Body Battery / SpO2 / etc.
    hidden function _snDrCol(dc, yStart) {
        if (!_snAnyAvail()) { return; }
        var rx = _snColX();
        var step = _h * 9 / 100;
        var y = yStart;
        var hF = Graphics.FONT_XTINY;

        if ((_snAvail & 0x01) != 0 && _snHrCur > 0) {
            var hC = 0xFF6688;
            if (_snBradActive()) { hC = _cHLD; }
            _snDrHeart(dc, rx - 28, y + 6, hC);
            dc.setColor(hC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rx, y, hF, _snHrCur.toString(), Graphics.TEXT_JUSTIFY_RIGHT);
            y += step;
        }
        if ((_snAvail & 0x02) != 0 && _snBodyBatt >= 0) {
            var bbC = (_snBodyBatt >= 60) ? 0x66DD88
                    : ((_snBodyBatt >= 30) ? 0xCCAA44 : 0xFFA060);
            dc.setColor(bbC, Graphics.COLOR_TRANSPARENT);
            // Mini battery icon: 6x4 outline + variable fill
            var bx = rx - 28; var by = y + 5;
            dc.drawRectangle(bx, by, 8, 4);
            dc.fillRectangle(bx + 8, by + 1, 1, 2);
            var fillW = _snBodyBatt * 6 / 100;
            if (fillW > 0) { dc.fillRectangle(bx + 1, by + 1, fillW, 2); }
            dc.drawText(rx, y, hF, _snBodyBatt.toString(), Graphics.TEXT_JUSTIFY_RIGHT);
            y += step;
        }
        if ((_snAvail & 0x08) != 0 && _snSpo2 >= 0) {
            var spC = 0x66CCDD;
            // Tiny "O2" droplet icon: filled circle
            dc.setColor(spC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(rx - 25, y + 6, 3);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(rx - 25, y + 6, 1);
            dc.setColor(spC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rx, y, hF, _snSpo2.toString(), Graphics.TEXT_JUSTIFY_RIGHT);
            y += step;
        }
        if (_snBradBest > 0) {
            var brC = 0xAA88FF;
            dc.setColor(brC, Graphics.COLOR_TRANSPARENT);
            // Down-chevron icon
            var ax = rx - 25; var ay = y + 4;
            dc.fillRectangle(ax - 3, ay,     7, 2);
            dc.fillRectangle(ax - 2, ay + 2, 5, 2);
            dc.fillRectangle(ax - 1, ay + 4, 3, 2);
            dc.drawText(rx, y, hF, _snBradBest.toString(), Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    // Bradycardia detection during apnea: HR dropped ≥10 BPM from baseline.
    // Surfaced as a positive cue ("DIVE REFLEX").
    hidden function _snBradActive() {
        if (!_snOn || _snHrStart <= 0 || _snHrCur <= 0) { return false; }
        return (_snHrStart - _snHrCur) >= 10;
    }

    // Compact sensor badge for active screens. Returns "" when nothing useful.
    hidden function _snBadgeText() {
        if (!_snOn || _snHrCur <= 0) { return ""; }
        var d = (_snHrStart > 0) ? (_snHrStart - _snHrCur) : 0;
        if (d > 0) { return _snHrCur + "  -" + d; }
        if (d < 0) { return _snHrCur + "  +" + (-d); }
        return _snHrCur + " bpm";
    }

    // Color-coded HR badge: green if bradycardia (drop), orange if rising
    // hard, theme-dim otherwise.
    hidden function _snBadgeColor() {
        if (!_snOn || _snHrCur <= 0) { return _lighten(_cINH, -50); }
        var d = (_snHrStart > 0) ? (_snHrStart - _snHrCur) : 0;
        if (d >= 10) { return _cHLD; }       // bradycardia — strong positive
        if (d <= -15) { return 0xFFA060; }   // HR climbing fast — load high
        return _lighten(_cINH, -10);
    }

    hidden function _clamp(v, lo, hi) {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    // Trend on a 3-entry history: returns 1 (rising), -1 (falling), 0 (flat)
    hidden function _trend3(hist) {
        var h0 = hist[0]; var h1 = hist[1]; var h2 = hist[2];
        if (h0 == 0 || h1 == 0 || h2 == 0) { return 0; }
        // newest=h0, oldest=h2 — rising means h0 > h1 > h2
        if (h0 > h1 && h1 > h2) { return 1; }
        if (h0 < h1 && h1 < h2) { return -1; }
        return 0;
    }

    hidden function _pushLoad(hist, val) {
        hist[2] = hist[1]; hist[1] = hist[0]; hist[0] = val;
    }

    // 5-entry rolling buffer; index 0 = newest, 4 = oldest
    hidden function _push5(hist, val) {
        hist[4] = hist[3]; hist[3] = hist[2]; hist[2] = hist[1]; hist[1] = hist[0];
        hist[0] = val;
    }

    hidden function _persistVHist(prefix, hist) {
        for (var i = 0; i < 5; i++) {
            Application.Storage.setValue(prefix + i.toString(), hist[i]);
        }
    }

    // ── CO2 tolerance ─────────────────────────────────────────────────────
    // diffFactor: easy=8 std=10 hard=13 (integer)
    hidden function _updateCo2Model(completed, roundsCompleted, totalRounds, pauses, diff) {
        var df = 10;
        if (diff == DP_EASY) { df = 8; }
        else if (diff == DP_HARD) { df = 13; }
        var raw = roundsCompleted * df - pauses * 6;
        if (raw < 0) { raw = 0; }
        var maxRaw = totalRounds * 13;
        var load = (maxRaw > 0) ? (raw * 100 / maxRaw) : 0;
        load = _clamp(load, 0, 100);
        _coLastLoad = load;

        var d = 0;
        if (completed && pauses == 0) { d = 4; }
        else if (completed && pauses == 1) { d = 1; }
        if (pauses >= 2) { d -= 4; }
        if (load >= 70) { d += 2; }
        _coTolScore = _clamp(_coTolScore + d, 0, 100);

        _pushLoad(_coLoadHist, load);
        _coTrend = _trend3(_coLoadHist);
        _push5(_coVHist, _coTolScore);
        _persistVHist("co_vh", _coVHist);
        _persistCo2();
    }

    hidden function _persistCo2() {
        Application.Storage.setValue("co_tol_score", _coTolScore);
        Application.Storage.setValue("co_last_load", _coLastLoad);
        Application.Storage.setValue("co_trend", _coTrend);
        for (var i = 0; i < 3; i++) {
            Application.Storage.setValue("co_lh" + i.toString(), _coLoadHist[i]);
        }
    }

    // ── O2 adaptation ─────────────────────────────────────────────────────
    hidden function _updateO2Model(firstHold, lastHold, pb) {
        var peakR = (pb > 0) ? (lastHold * 100 / pb) : 0;
        peakR = _clamp(peakR, 0, 100);
        _o2PeakRatio = peakR;

        var prog = lastHold - firstHold;
        var d = 0;
        if (prog > 0) { d += 3; }
        if (peakR > 80) { d += 4; }
        if (lastHold * 10 < firstHold * 9) { d -= 4; }  // early collapse
        _o2AdaptScore = _clamp(_o2AdaptScore + d, 0, 100);

        _pushLoad(_o2LoadHist, peakR);
        _o2Trend = _trend3(_o2LoadHist);
        _push5(_o2VHist, _o2AdaptScore);
        _persistVHist("o2_vh", _o2VHist);

        Application.Storage.setValue("o2_adapt_score", _o2AdaptScore);
        Application.Storage.setValue("o2_peak_ratio", _o2PeakRatio);
        Application.Storage.setValue("o2_trend", _o2Trend);
        for (var i = 0; i < 3; i++) {
            Application.Storage.setValue("o2_lh" + i.toString(), _o2LoadHist[i]);
        }
    }

    // ── Recovery (breathe) ────────────────────────────────────────────────
    // perfDelta: +1 if next session improved, -1 if worse, 0 unknown
    hidden function _updateRecoveryModel(durationSec, perfDelta) {
        var d = 0;
        if (perfDelta > 0) { d += 4; }
        else if (perfDelta < 0) { d -= 4; }
        if (durationSec >= 600) { d += 2; }   // long session bonus
        _brRecScore = _clamp(_brRecScore + d, 0, 100);
        _brEffectLast = perfDelta;
        _push5(_brVHist, _brRecScore);
        _persistVHist("br_vh", _brVHist);
        Application.Storage.setValue("br_rec_score", _brRecScore);
        Application.Storage.setValue("br_effect_last", _brEffectLast);
    }

    // ── Session quality score 0..100 ─────────────────────────────────────
    // For Apnea: hold/PB ratio + pacing
    // For CO2/O2: completion + pauses + consistency
    // For Breathe: duration + effect
    hidden function _calcSessionScore(mode, metricA, metricB, metricC) {
        var sc = 50;
        if (mode == FM_AP) {
            var hold = metricA; var pb = (_apPrevPB > 0) ? _apPrevPB : metricA;
            sc = (pb > 0) ? (hold * 100 / pb) : 50;
            if (hold < 15) { sc -= 30; }
            // pacing bonus: if newest is within 90% of recent best
            if (_apHist[0] > 0 && _apHist[1] > 0 && _apHist[0] * 10 >= _apHist[1] * 9) { sc += 5; }
        } else if (mode == FM_CO || mode == FM_O2) {
            var roundsDone = metricA; var totalRounds = metricB; var pauses = metricC;
            sc = (totalRounds > 0) ? (roundsDone * 100 / totalRounds) : 0;
            sc -= pauses * 8;
        } else {
            // FM_BR: duration in seconds + effect
            var dur = metricA;
            sc = 40 + dur / 60 * 4;          // 1 min = 4 pts above 40
            if (_brEffectLast > 0) { sc += 10; }
        }
        sc = _clamp(sc, 0, 100);
        _stScoreLast = sc;
        // EMA: 30% new / 70% old
        _stScoreAvg = (_stScoreAvg * 7 + sc * 3) / 10;
        Application.Storage.setValue("st_score_last", _stScoreLast);
        Application.Storage.setValue("st_score_avg", _stScoreAvg);
    }

    // ── PB prediction ─────────────────────────────────────────────────────
    hidden function _updatePbPrediction() {
        if (_apPB <= 0) {
            _pbPredicted = 0; _pbConfidence = 0;
        } else {
            var trend = _apTrend();
            var base = _apPB;
            var pct = 100;
            if (trend > 0) { pct = 108; }       // +8%
            else if (trend < 0) { pct = 96; }   // -4%
            else { pct = 102; }                  // plateau small bump
            _pbPredicted = base * pct / 100;

            // Confidence: how many of last 5 hist entries are populated
            var pop = 0;
            for (var i = 0; i < 5; i++) { if (_apHist[i] > 0) { pop++; } }
            _pbConfidence = pop * 18 + _stScoreAvg / 5;  // 0..~110 → clamp
            _pbConfidence = _clamp(_pbConfidence, 0, 100);
        }
        Application.Storage.setValue("pb_predicted", _pbPredicted);
        Application.Storage.setValue("pb_confidence", _pbConfidence);
    }

    // ── Pattern detection ────────────────────────────────────────────────
    hidden function _detectPatterns() {
        // Plateau: last 5 within ±5% of mean (need all 5 populated)
        var plateau = false; var decline = false;
        var allFilled = true;
        var sum = 0;
        for (var i = 0; i < 5; i++) {
            if (_apHist[i] <= 0) { allFilled = false; }
            sum += _apHist[i];
        }
        if (allFilled) {
            var mean = sum / 5;
            var within = true;
            for (var j = 0; j < 5; j++) {
                var diff = _apHist[j] - mean; if (diff < 0) { diff = -diff; }
                if (diff * 100 > mean * 5) { within = false; }
            }
            plateau = within;
        }
        // Decline: newest 3 strictly decreasing
        if (_apHist[0] > 0 && _apHist[1] > 0 && _apHist[2] > 0
            && _apHist[0] < _apHist[1] && _apHist[1] < _apHist[2]) {
            decline = true;
        }
        var overtrain = (_stStreak >= 4 && decline);

        _ptPlateauFlag = plateau;
        _ptDeclineFlag = decline;
        _ptOvertrainFlag = overtrain;
        Application.Storage.setValue("pt_plateau", _ptPlateauFlag);
        Application.Storage.setValue("pt_decline", _ptDeclineFlag);
        Application.Storage.setValue("pt_overtrain", _ptOvertrainFlag);
    }

    // ── Diver profile ────────────────────────────────────────────────────
    hidden function _updateDiverProfile() {
        _diverCo2 = _coTolScore;
        _diverO2 = _o2AdaptScore;
        _diverRecovery = _brRecScore;
        Application.Storage.setValue("diver_co2", _diverCo2);
        Application.Storage.setValue("diver_o2", _diverO2);
        Application.Storage.setValue("diver_rec", _diverRecovery);
    }

    hidden function _diverClass() {
        if (_diverRecovery < 40) { return "RECOVERY LIMITED"; }
        if (_diverCo2 > _diverO2 + 15) { return "CO2 DOMINANT"; }
        if (_diverO2 > _diverCo2 + 15) { return "O2 LIMITED"; }
        return "BALANCED";
    }

    // Single entry point called at end of any session — runs all updates
    hidden function _physioSessionEnd(mode) {
        _updatePbPrediction();
        _detectPatterns();
        _updateDiverProfile();
    }

    hidden function _endBrPhysio() {
        // Heuristic perfDelta: recent score_avg vs earlier baseline
        var dur = _brSS - _brRem;
        if (dur < 0) { dur = _brSS; }
        var delta = 0;
        if (_stScoreLast >= _stScoreAvg + 5) { delta = 1; }
        else if (_stScoreLast + 5 < _stScoreAvg) { delta = -1; }
        _updateRecoveryModel(dur, delta);
        _calcSessionScore(FM_BR, dur, 0, 0);
        _physioSessionEnd(FM_BR);
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); _timer.start(method(:onTick), 100, true); }
    }

    function onHide() {}

    function onTick() as Void {
        _sub++;
        if (_demoMode > 0) {
            _demoTickTour();
            if (_demoMode == 0) { return; }
            // Allow live training animations on slides 1/2/3 (FT_ACT)
            // by falling through to normal tick logic below.
            if (_gs != FT_ACT) { WatchUi.requestUpdate(); return; }
        }
        if (_gs == FT_READY) {
            if (_rdPh == RP_BREATHE) {
                _rdSub++;
                if (_rdSub >= 10) {
                    _rdSub = 0; _rdT++;
                    if (_rdT >= 30) {
                        _rdPh = RP_APNEA; _rdT = 0; _rdApE = 0; _vibe(80, 200);
                    } else {
                        var inPh = _rdT % 8;
                        if (inPh == 0) { _vibe(60, 120); _rdBrPh = 0; }
                        else if (inPh == 4) { _vibe(50, 80); _rdBrPh = 1; }
                    }
                }
            } else if (_rdPh == RP_APNEA) {
                _rdApE++;
                if (_rdApE >= 900) { _rdFinish(); }
            }
            WatchUi.requestUpdate(); return;
        }
        if (_gs == FT_ACT) {
            _snTick();
            if (_mode == FM_AP) {
                if (_sub % 2 == 0) {
                    _apE++;
                    var s = _apE / 5;
                    if (s != _apPS) { _apPS = s; _chkApV(s); }
                }
            } else if (_mode == FM_BR) {
                _brPS++;
                if (_brPS >= 10) {
                    _brPS = 0;
                    if (_brTrans > 0) {
                        _brTrans--; _brRem--;
                        if (_brRem <= 0) {
                            _saveSt(FM_BR, _brSS, 0); _endBrPhysio(); _updStreak();
                            if (_plFromPlan) { _planAdvanceWith(PO_NORMAL); _plFromPlan = false; }
                            _vibeDone(); _gs = FT_DONE; WatchUi.requestUpdate(); return;
                        }
                        if (_brTrans == 0) { _nxBrPh(); }
                    } else {
                        if (_brPE < _brPD) {
                            _brPE++; _brRem--;
                            if (_brRem <= 0) {
                                _saveSt(FM_BR, _brSS, 0); _endBrPhysio(); _updStreak();
                                if (_plFromPlan) { _planAdvanceWith(PO_NORMAL); _plFromPlan = false; }
                                _vibeDone(); _gs = FT_DONE; WatchUi.requestUpdate(); return;
                            }
                        }
                        if (_brPE >= _brPD) { _brTrans = 1; }
                    }
                }
            } else {
                _tPSub++;
                if (_tPSub >= 10) {
                    _tPSub = 0; _tPE++;
                    if (_tPE >= _tPS) { _nxTblPh(); }
                }
            }
        } else {
            if (_sub % 5 == 0) { _tick++; }
            // Refresh historical sensor reads while idle on HOME (every ~5s)
            if (_gs == FT_HOME && _snOn && _tick - _snLastReadT >= 50) {
                _snLastReadT = _tick;
                // Always probe HR — don't gate on _snAvail bit. On many watches
                // the optical sensor isn't ready at app launch; the SensorHistory
                // fallback will succeed even then, and we lazily set the bit here.
                var hr = _snReadHrRaw();
                if (hr > 0) { _snHrCur = hr; _snAvail = _snAvail | 0x01; }
                if ((_snAvail & 0x02) != 0) { var bb = _snReadBodyBatt(); if (bb >= 0) { _snBodyBatt = bb; } }
                if ((_snAvail & 0x04) != 0) { var st = _snReadStress(); if (st >= 0) { _snStress = st; } }
                if ((_snAvail & 0x10) != 0) { var rh = _snReadRestingHr(); if (rh > 0) { _snRestHr = rh; } }
            }
        }
        WatchUi.requestUpdate();
    }

    hidden function _nxBrPh() {
        var nx = (_brPh + 1) % 4;
        var nd = _brPat[nx]; var g = 0;
        while (nd == 0 && g < 4) { nx = (nx + 1) % 4; nd = _brPat[nx]; g++; }
        if (nx == BP_INH) { _brBC++; }
        _brPh = nx; _brPD = nd; _brPE = 0; _brPS = 0;
        _vibePh(_brPh);
    }

    hidden function _nxTblPh() {
        if (_tPh == BP_PRP) {
            _tPh = BP_RST; _tPS = _tR[_tRnd]; _tPE = 0; _tPSub = 0;
            _vibe(60, 140);
        } else if (_tPh == BP_RST) {
            _tPh = BP_HLD; _tPS = _tH[_tRnd]; _tPE = 0; _tPSub = 0;
            _vibe(100, 260);
        } else {
            _vibeDouble(80, 120, 80);
            _tRnd++;
            if (_tRnd >= _tTR) {
                var td = 0; var thd = 0;
                for (var ti = 0; ti < _tTR; ti++) { td += _tH[ti] + _tR[ti]; thd += _tH[ti]; }
                _stHoldT += thd; Application.Storage.setValue("st_holdt", _stHoldT);
                _saveSt(_mode, td, thd);
                if (_mode == FM_CO) {
                    _updateCo2Model(true, _tTR, _tTR, _pauseCnt, _tDiff);
                } else if (_mode == FM_O2) {
                    _updateO2Model(_tH[0], _tH[_tTR - 1], _apPB);
                }
                _calcSessionScore(_mode, _tTR, _tTR, _pauseCnt);
                _physioSessionEnd(_mode);
                _trackSuccess(_mode);
                _progressCheck();
                _updStreak();
                if (_plFromPlan) {
                    var out = (_pauseCnt == 0) ? PO_SKIP : PO_NORMAL;
                    _planAdvanceWith(out); _plFromPlan = false;
                }
                _vibeDone(); _gs = FT_DONE;
            } else {
                _tPh = BP_RST; _tPS = _tR[_tRnd]; _tPE = 0; _tPSub = 0;
                _vibe(60, 140);
            }
        }
    }

    hidden function _genCO2(maxH, rounds) {
        var holdPct = 55; var rEnd = 30; var rMax = 120;
        if (_tDiff == DP_EASY) { holdPct = 45; rEnd = 45; rMax = 150; }
        else if (_tDiff == DP_HARD) { holdPct = 65; rEnd = 20; rMax = 100; }
        var hold = maxH * holdPct / 100; if (hold < 15) { hold = 15; }
        var rStart = hold * 2; if (rStart > rMax) { rStart = rMax; }
        for (var i = 0; i < rounds; i++) {
            _tH[i] = hold;
            var rest;
            if (_tDiff == DP_HARD) {
                var f = i.toFloat() / (rounds - 1).toFloat();
                f = f * f;
                rest = (rStart - (rStart - rEnd) * f).toNumber();
            } else if (_tDiff == DP_EASY) {
                var f2 = i.toFloat() / (rounds - 1).toFloat();
                f2 = 1.0 - (1.0 - f2) * (1.0 - f2);
                rest = (rStart - (rStart - rEnd) * f2).toNumber();
            } else {
                rest = rStart - (rStart - rEnd) * i / (rounds - 1);
            }
            if (rest < rEnd) { rest = rEnd; }
            _tR[i] = rest;
        }
    }

    hidden function _genO2(maxH, rounds) {
        var rest = 120; var hStartPct = 50; var hEndPct = 85;
        if (_tDiff == DP_EASY) { rest = 150; hStartPct = 40; hEndPct = 70; }
        else if (_tDiff == DP_HARD) { rest = 100; hStartPct = 55; hEndPct = 95; }
        var hStart = maxH * hStartPct / 100; if (hStart < 15) { hStart = 15; }
        var hEnd = maxH * hEndPct / 100;
        for (var i = 0; i < rounds; i++) {
            _tR[i] = rest;
            var hold;
            if (_tDiff == DP_HARD) {
                var f = i.toFloat() / (rounds - 1).toFloat();
                f = 1.0 - (1.0 - f) * (1.0 - f);
                hold = (hStart + (hEnd - hStart) * f).toNumber();
            } else if (_tDiff == DP_EASY) {
                var f2 = i.toFloat() / (rounds - 1).toFloat();
                f2 = f2 * f2;
                hold = (hStart + (hEnd - hStart) * f2).toNumber();
            } else {
                hold = hStart + (hEnd - hStart) * i / (rounds - 1);
            }
            _tH[i] = hold;
        }
    }

    hidden function _chkApV(s) {
        if (s > 0 && s % 60 == 0) { _vibe(80, 280); }
        else if (s > 0 && s % 30 == 0) { _vibe(50, 110); }
        if (!_apWF && s >= _apWS) { _apWF = true; _vibeDouble(90, 150, 100); }
        // Micro-feedback latches (only fire once per session, mfFlags bitmask)
        if (_apPB > 0) {
            if ((_mfFlags & 1) == 0 && s * 100 >= _apPB * 50) {
                _mfFlags = _mfFlags | 1; _vibe(40, 60);
            }
            if ((_mfFlags & 2) == 0 && s * 100 >= _apPB * 75) {
                _mfFlags = _mfFlags | 2; _vibe(50, 80);
            }
        }
    }

    hidden function _calcApTh() {
        if (_apPB > 0) { _apWS = _apPB * 75 / 100; _apCS = _apPB * 90 / 100; }
        else { _apWS = 90; _apCS = 150; }
        if (_apWS < 20) { _apWS = 20; }
        if (_apCS <= _apWS) { _apCS = _apWS + 30; }
    }

    hidden function _apColor(s) {
        if (s >= _apCS) { return 0xFF3322; }
        if (s >= _apWS) { return 0xFFCC00; }
        return _cINH;
    }

    hidden function _vibe(inten, dur) {
        if (!_vibOn) { return; }
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(inten, dur)]);
            }
        }
    }

    hidden function _vibeDouble(inten, dur, gap) {
        if (!_vibOn) { return; }
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([
                    new Toybox.Attention.VibeProfile(inten, dur),
                    new Toybox.Attention.VibeProfile(0, gap),
                    new Toybox.Attention.VibeProfile(inten, dur)]);
            }
        }
    }

    hidden function _vibeDone() {
        if (!_vibOn) { return; }
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([
                    new Toybox.Attention.VibeProfile(100, 600),
                    new Toybox.Attention.VibeProfile(0, 150),
                    new Toybox.Attention.VibeProfile(80, 200)]);
            }
        }
    }

    hidden function _vibePh(ph) {
        if (ph == BP_INH)  { _vibe(70, 150); }
        else if (ph == BP_EXH)  { _vibeDouble(70, 120, 80); }
        else if (ph == BP_HI || ph == BP_HE) { _vibe(90, 200); }
    }

    function doUp() {
        if (_demoMode > 0) { _stopDemo(); _gs = FT_HOME; _hSel = 0; return; }
        if (_gs == FT_HOME) { _hSel = (_hSel + 6) % 7; }
        else if (_gs == FT_MORE) { _mSel = (_mSel + 7) % 8; }
        else if (_gs == FT_HELP) { _hlSel = (_hlSel + HLP_N - 1) % HLP_N; }
        else if (_gs == FT_PLAN) { _plSel = (_plSel + _planMenuMax()) % (_planMenuMax() + 1); }
        else if (_gs == FT_BCFG) { _adjBrF(-1); }
        else if (_gs == FT_TCFG) { _adjTF(-1); }
        else if (_gs == FT_CUST) { var cr = _custRows(); _cF = (_cF + cr - 1) % cr; }
        else if (_gs == FT_NAME) { _adjNmCh(-1); }
        else if (_gs == FT_STAT) { _stPg = (_stPg + 1) % 5; }
    }

    function doDown() {
        if (_demoMode > 0) { _stopDemo(); _gs = FT_HOME; _hSel = 0; return; }
        if (_gs == FT_HOME) { _hSel = (_hSel + 1) % 7; }
        else if (_gs == FT_MORE) { _mSel = (_mSel + 1) % 8; }
        else if (_gs == FT_HELP) { _hlSel = (_hlSel + 1) % HLP_N; }
        else if (_gs == FT_PLAN) { _plSel = (_plSel + 1) % (_planMenuMax() + 1); }
        else if (_gs == FT_BCFG) { _adjBrF(1); }
        else if (_gs == FT_TCFG) { _adjTF(1); }
        else if (_gs == FT_CUST) { _cF = (_cF + 1) % _custRows(); }
        else if (_gs == FT_NAME) { _adjNmCh(1); }
        else if (_gs == FT_STAT) { _stPg = (_stPg + 1) % 5; }
    }

    function doSelect() {
        if (_demoMode > 0) { _stopDemo(); _gs = FT_HOME; _hSel = 0; return; }
        if (_gs == FT_HOME) {
            if (_hSel == 0) { _instantStart(_lastMode); }
            else if (_hSel == 1) { _quickBreathe(); }
            else if (_hSel == 2) { _instantStart(FM_CO); }
            else if (_hSel == 3) { _instantStart(FM_O2); }
            else if (_hSel == 4) { _instantStart(FM_AP); }
            else if (_hSel == 5) { _rdStart(); }
            else { _mSel = 0; _gs = FT_MORE; }
        } else if (_gs == FT_READY) {
            if (_rdPh == RP_BREATHE) { _rdPh = RP_APNEA; _rdT = 0; _rdApE = 0; _vibe(80, 200); }
            else if (_rdPh == RP_APNEA) { _rdFinish(); }
            else { _hSel = 0; _gs = FT_HOME; }
        } else if (_gs == FT_PLAN) {
            if (_plAct == PL_NONE) {
                if (_plSel < PL_COUNT) { _planStartPlan(_plSel); _plSel = 0; }
                else { _gs = FT_HOME; _hSel = 0; }
            } else {
                if (_plSel == 0) { _planStartCurrent(); }
                else if (_plSel == 1) { _planAdvance(); _plSel = 0; }
                else { _planAbandon(); _plSel = 0; }
            }
        } else if (_gs == FT_MORE) {
            if (_mSel == 0) {
                _mode = FM_BR; _brM = _svBrM; _brII = _svBrII; _brHI = _svBrHI;
                _brEI = _svBrEI; _brXI = _svBrXI; _brSI = _svBrSI;
                _plFromPlan = false; _brF = 0; _gs = FT_BCFG;
            } else if (_mSel == 1) {
                _mode = FM_CO; _tMxI = _svCoMx; _tRnI = _svCoRn; _tDiff = _svCoDf;
                _plFromPlan = false; _tF = 0; _gs = FT_TCFG;
            } else if (_mSel == 2) {
                _mode = FM_O2; _tMxI = _svO2Mx; _tRnI = _svO2Rn; _tDiff = _svO2Df;
                _plFromPlan = false; _tF = 0; _gs = FT_TCFG;
            } else if (_mSel == 3) { _plSel = 0; _gs = FT_PLAN; }
            else if (_mSel == 4) { _stPg = 0; _gs = FT_STAT; }
            else if (_mSel == 5) { _cF = 0; _gs = FT_CUST; }
            else if (_mSel == 6) { _hlSel = 0; _gs = FT_HELP; }
            else { _gs = FT_RST; }
        } else if (_gs == FT_RST) {
            _resetAll();
        } else if (_gs == FT_GTU) {
            _gs = FT_HOME; _hSel = 0;
            try { _genTestUser(); } catch (e) {}
        } else if (_gs == FT_BCFG) {
            var mx = _brFldCnt();
            if (_brF < mx - 1) { _brF++; }
            else { _startBr(true); }
        } else if (_gs == FT_TCFG) {
            if (_tF < 3) { _tF++; }
            else { _startTbl(); }
        } else if (_gs == FT_ACT) {
            if (_mode == FM_AP) { _stopAp(); }
            else { _pauseCnt++; _gs = FT_PAU; }
        } else if (_gs == FT_PAU) {
            _gs = FT_ACT;
        } else if (_gs == FT_DONE || _gs == FT_STAT) {
            _hSel = 0; _gs = FT_HOME;
        } else if (_gs == FT_CUST) {
            _actCustRow();
        } else if (_gs == FT_NAME) {
            if (_nmPos < 7) { _nmPos++; }
            else { _nmStr = _bldNm(); _cF = 2; _gs = FT_CUST; }
        }
    }

    hidden function _custRows() {
        return DBG_ENABLED ? 6 : 5;
    }

    hidden function _actCustRow() {
        if (_cF == 0) { _thIdx = (_thIdx + 1) % 10; _applyTheme(); }
        else if (_cF == 1) { _nmPos = 0; _gs = FT_NAME; }
        else if (_cF == 2) { _vibOn = !_vibOn; if (_vibOn) { _vibe(60, 120); } }
        else if (_cF == 3) {
            _snOn = !_snOn;
            Application.Storage.setValue("usr_sn", _snOn);
            if (_snOn) {
                try { Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]); _snHrEnabled = true; }
                catch (e) { _snHrEnabled = false; }
                _snDetectAvailability();
            } else {
                try { Sensor.setEnabledSensors([]); } catch (e) {}
                _snHrEnabled = false; _snHrCur = 0; _snAvail = 0;
            }
        }
        else if (DBG_ENABLED && _cF == 4) { _gs = FT_GTU; }
        else { _saveCustom(); _gs = FT_HOME; }
    }

    hidden function _genTestUser() {
        // Generate plausible pseudo-random training history for UI testing.
        // Uses _tick as seed so each call produces slightly different data.
        var t = _tick;
        var pb = 75 + (t % 7) * 12;   // PB between 75–147 s
        _apPB = pb;
        // 5 history entries, oldest→newest: gradual approach to PB with noise
        _apHist[4] = pb * 44 / 100;
        _apHist[3] = pb * 53 / 100;
        _apHist[2] = pb * 63 / 100;
        _apHist[1] = pb * 71 / 100;
        // Newest bar alternates between good (≥80%) and mediocre (≈62%)
        _apHist[0] = pb * ((t % 3 == 0) ? 62 : 83) / 100;

        _stApC = 12 + (t % 9);
        _stBrC = 8  + (t % 5);
        _stCoC = 6  + (t % 4);
        _stO2C = 4  + (t % 3);
        _stTotT = _stApC * 190 + _stBrC * 290 + _stCoC * 240 + _stO2C * 230;
        _stStreak = 3 + (t % 6);
        _stHoldT = _stApC * 85;

        // Persist so stats page shows data immediately
        Application.Storage.setValue("ap_pb", _apPB);
        for (var j = 0; j < 5; j++) {
            Application.Storage.setValue("ap_h" + j.toString(), _apHist[j]);
        }

        // Seed PRO++ physio scores so SYSTEM STATUS page looks alive
        _coTolScore   = 60 + (t % 25);    // 60..84
        _o2AdaptScore = 55 + (t % 30);    // 55..84
        _brRecScore   = 50 + (t % 35);    // 50..84
        _coLastLoad   = 65 + (t % 20);
        _o2PeakRatio  = 75 + (t % 20);
        _coTrend      = ((t % 3) == 0) ? -1 : 1;
        _o2Trend      = 1;
        _brEffectLast = 1;
        _stScoreLast  = 70 + (t % 25);
        _stScoreAvg   = 65 + (t % 20);
        _pbPredicted  = pb * (105 + (t % 8)) / 100;  // PB + 5..12%
        _pbConfidence = 70 + (t % 20);
        _diverCo2 = _coTolScore; _diverO2 = _o2AdaptScore; _diverRecovery = _brRecScore;
        _ptPlateauFlag = ((t % 5) == 0);
        _ptDeclineFlag = false;
        _ptOvertrainFlag = false;
        _coLoadHist[0] = _coLastLoad;   _coLoadHist[1] = _coLastLoad - 6; _coLoadHist[2] = _coLastLoad - 14;
        _o2LoadHist[0] = _o2PeakRatio;  _o2LoadHist[1] = _o2PeakRatio - 4; _o2LoadHist[2] = _o2PeakRatio - 11;

        // Seed visual trend histograms (oldest=idx4, newest=idx0)
        // for CO2 / O2 / Recovery so PHYSIOLOGY page renders bars instead of "------".
        _coVHist[4] = _coTolScore   * 60 / 100;
        _coVHist[3] = _coTolScore   * 72 / 100;
        _coVHist[2] = _coTolScore   * 80 / 100;
        _coVHist[1] = _coTolScore   * 92 / 100;
        _coVHist[0] = _coTolScore;
        _o2VHist[4] = _o2AdaptScore * 55 / 100;
        _o2VHist[3] = _o2AdaptScore * 68 / 100;
        _o2VHist[2] = _o2AdaptScore * 79 / 100;
        _o2VHist[1] = _o2AdaptScore * 90 / 100;
        _o2VHist[0] = _o2AdaptScore;
        _brVHist[4] = _brRecScore   * 50 / 100;
        _brVHist[3] = _brRecScore   * 65 / 100;
        _brVHist[2] = _brRecScore   * 78 / 100;
        _brVHist[1] = _brRecScore   * 88 / 100;
        _brVHist[0] = _brRecScore;
        for (var vi = 0; vi < 5; vi++) {
            Application.Storage.setValue("co_vh" + vi.toString(), _coVHist[vi]);
            Application.Storage.setValue("o2_vh" + vi.toString(), _o2VHist[vi]);
            Application.Storage.setValue("br_vh" + vi.toString(), _brVHist[vi]);
        }

        Application.Storage.setValue("co_tol_score", _coTolScore);
        Application.Storage.setValue("co_last_load", _coLastLoad);
        Application.Storage.setValue("co_trend", _coTrend);
        Application.Storage.setValue("o2_adapt_score", _o2AdaptScore);
        Application.Storage.setValue("o2_peak_ratio", _o2PeakRatio);
        Application.Storage.setValue("o2_trend", _o2Trend);
        Application.Storage.setValue("br_rec_score", _brRecScore);
        Application.Storage.setValue("br_effect_last", _brEffectLast);
        Application.Storage.setValue("st_score_last", _stScoreLast);
        Application.Storage.setValue("st_score_avg", _stScoreAvg);
        Application.Storage.setValue("pb_predicted", _pbPredicted);
        Application.Storage.setValue("pb_confidence", _pbConfidence);
        Application.Storage.setValue("diver_co2", _diverCo2);
        Application.Storage.setValue("diver_o2", _diverO2);
        Application.Storage.setValue("diver_rec", _diverRecovery);
        Application.Storage.setValue("pt_plateau", _ptPlateauFlag);
        Application.Storage.setValue("pt_decline", _ptDeclineFlag);
        Application.Storage.setValue("pt_overtrain", _ptOvertrainFlag);

        // Seed weekly buckets so WEEKLY page renders a real 8-week chart
        // instead of "no data". Pattern: build-up → peak → mild deload.
        var wkPattern = [5, 6, 4, 7, 6, 8, 5, 3];   // [0]=now, [7]=oldest
        for (var wi = 0; wi < 8; wi++) {
            _wkSes[wi]  = wkPattern[wi] + (t % 3);
            _wkHold[wi] = _wkSes[wi] * (60 + (t % 30));   // ~60-90s/session
        }
        _wkBaseDay = _curEpochDay();
        _wkBestSes = 0;
        for (var wj = 0; wj < 8; wj++) {
            if (_wkSes[wj] > _wkBestSes) { _wkBestSes = _wkSes[wj]; }
        }
        // Activity bitmap: trained 5 of last 7 days, 9 of last 14
        _dayBits    = 0x0DEB;   // 0000 1101 1110 1011  → mixed pattern
        _dayBitsRef = _curEpochDay();
        _persistWeekly();

        // Seed sensor metrics so PHYSIOLOGY/DONE/SENSOR-TRENDS pages render
        // badges even when run inside the simulator (no live HR available).
        _snBradLast = 12 + (t % 8);
        _snBradBest = 18 + (t % 12);
        _snHrCur    = 56 + (t % 12);
        _snHrStart  = 62 + (t % 8);
        _snRestHr   = 54 + (t % 8);
        _snBodyBatt = 60 + (t % 35);
        _snStress   = 18 + (t % 25);
        _snSpo2     = 95 + (t % 4);
        // Pretend full sensor suite is available
        _snAvail = 0x1F;
        // Seed bradycardia history (realistic improving trend)
        _snBradHist[0] = 6  + (t % 4);
        _snBradHist[1] = 8  + (t % 5);
        _snBradHist[2] = 10 + (t % 5);
        _snBradHist[3] = 12 + (t % 6);
        _snBradHist[4] = _snBradLast;
        // Seed calm history (realistic improving trend)
        _snCalmLast  = 58 + (t % 30);
        _snCalmAvg   = 52 + (t % 18);
        _snHrDropAvg = 6  + (t % 5);
        // Seed BB-at-start (varying readiness)
        _snBbAtStart[0] = 45 + (t % 30);
        _snBbAtStart[1] = 60 + (t % 25);
        _snBbAtStart[2] = 55 + (t % 20);
        _snBbAtStart[3] = 70 + (t % 20);
        _snBbAtStart[4] = _snBodyBatt;
        Application.Storage.setValue("sn_brad_best", _snBradBest);
        Application.Storage.setValue("sn_brad_last", _snBradLast);
        Application.Storage.setValue("sn_brad_hist", _snBradHist);
        Application.Storage.setValue("sn_calm_last", _snCalmLast);
        Application.Storage.setValue("sn_calm_avg",  _snCalmAvg);
        Application.Storage.setValue("sn_hr_drop_avg", _snHrDropAvg);
        Application.Storage.setValue("sn_bb_start",  _snBbAtStart);

        // Kick off the marketing demo (~15s auto-tour)
        _startDemo();
    }

    // ── DEMO TOUR (marketing showcase) ──────────────────────────────────
    // 5 slides × 3s = 15s. Any user input cancels.
    //   0: HOME (overlay shows REC + intelligence)
    //   1: STATS page 0  — TRAINING STATS
    //   2: STATS page 1  — PROGRESSION + apnea histogram
    //   3: STATS page 2  — SYSTEM STATUS (PRO++ physio dashboard)
    //   4: HOME with Readiness Check highlighted
    hidden function _startDemo() {
        _demoMode = 1; _demoT = 0; _demoSlide = -1;
        _demoApply(0);
        _vibeDouble(60, 100, 80);
    }

    hidden function _stopDemo() {
        _demoMode = 0;
        // Exit any training state we may have set up so we don't accidentally
        // save partial sessions later.
        _plFromPlan = false;
    }

    hidden function _demoTickTour() {
        if (_demoMode == 0) { return; }
        _demoT++;
        // Compute total elapsed → which slide we're on
        var acc = 0;
        var ns = 0;
        for (var i = 0; i < DEMO_COUNT; i++) {
            acc += DEMO_LEN[i];
            if (_demoT < acc) { ns = i; break; }
            ns = i + 1;
        }
        if (ns >= DEMO_COUNT) {
            _stopDemo();
            _gs = FT_HOME; _hSel = 0;
            _vibe(80, 200);
            return;
        }
        if (ns != _demoSlide) {
            _demoApply(ns);
            _vibe(40, 60);
        }
    }

    hidden function _demoApply(slide) {
        _demoSlide = slide;
        if (slide == 0) {
            _gs = FT_HOME; _hSel = 0;
        } else if (slide == 1) {
            // BREATHE active — Box 4-4-4-4, pre-positioned mid-inhale
            _mode = FM_BR;
            _brM = 2;
            _brPat = [4, 4, 4, 4];
            _brPh = BP_INH; _brPD = 4; _brPE = 1; _brPS = 2; _brTrans = 0;
            _brSS = 600; _brRem = 600; _brBC = 0;
            _gs = FT_ACT;
        } else if (slide == 2) {
            // APNEA active — start counter at a meaningful moment (>50% PB)
            _mode = FM_AP;
            var seed = (_apPB > 0) ? (_apPB * 60 / 100) : 90;
            _apE = seed * 5;        // _apE counts in 0.2s units
            _apPS = seed; _apLS = seed; _apNP = 0;
            _apWS = (_apPB > 0) ? (_apPB * 70 / 100) : 105;
            _apCS = (_apPB > 0) ? (_apPB * 90 / 100) : 135;
            _apWF = false;
            _gs = FT_ACT;
        } else if (slide == 3) {
            // CO2 TABLE active — mid-session for visual interest
            _mode = FM_CO;
            _tMxI = 3; _tRnI = 2; _tDiff = 1; _tF = 0;
            // Build simple CO2 table: hold = const max, rests shrink
            for (var k = 0; k < 10; k++) {
                _tH[k] = TBL_MX[_tMxI];
                _tR[k] = 90 - k * 10;
                if (_tR[k] < 20) { _tR[k] = 20; }
            }
            _tTR = TBL_RN[_tRnI];
            _tRnd = 2;             // already on round 3
            _tPh = BP_HLD;
            _tPS = _tH[_tRnd]; _tPE = _tPS / 3; _tPSub = 0;
            _gs = FT_ACT;
        } else if (slide == 4) {
            _gs = FT_STAT; _stPg = 1;
        } else if (slide == 5) {
            _gs = FT_STAT; _stPg = 2;
        } else if (slide == 6) {
            _gs = FT_STAT; _stPg = 3;
        } else if (slide == 7) {
            _gs = FT_STAT; _stPg = 4;   // SENSOR TRENDS
        } else if (slide == 8) {
            _gs = FT_HOME; _hSel = 0;
        }
    }

    function doBack() {
        if (_demoMode > 0) { _stopDemo(); _gs = FT_HOME; _hSel = 0; return true; }
        if (_gs == FT_HOME) { return false; }
        if (_gs == FT_READY) { _gs = FT_HOME; _hSel = 0; return true; }
        if (_gs == FT_MORE) { _gs = FT_HOME; return true; }
        if (_gs == FT_RST) { _mSel = 7; _gs = FT_MORE; return true; }
        if (_gs == FT_GTU) { _gs = FT_CUST; return true; }
        if (_gs == FT_HELP) { _gs = FT_MORE; return true; }
        if (_gs == FT_PLAN) { _gs = FT_MORE; return true; }
        if (_gs == FT_BCFG) { if (_brF > 0) { _brF--; return true; } _gs = FT_HOME; return true; }
        if (_gs == FT_TCFG) { if (_tF > 0) { _tF--; return true; } _gs = FT_HOME; return true; }
        if (_gs == FT_ACT || _gs == FT_PAU) {
            if (_mode == FM_CO || _mode == FM_O2) { _trackFail(_mode); }
            if (_plFromPlan) { _planAdvanceWith(PO_REPEAT); _plFromPlan = false; }
            _actDiscard();
            _hSel = 0; _gs = FT_HOME; return true;
        }
        if (_gs == FT_DONE || _gs == FT_STAT) { _hSel = 0; _gs = FT_HOME; return true; }
        if (_gs == FT_CUST) { _gs = FT_HOME; return true; }
        if (_gs == FT_NAME) {
            if (_nmPos > 0) { _nmPos--; return true; }
            _nmStr = _bldNm(); _gs = FT_CUST; return true;
        }
        return false;
    }

    function doTap(x, y) {
        if (_demoMode > 0) { _stopDemo(); _gs = FT_HOME; _hSel = 0; return; }
        if (_gs == FT_HOME) {
            if (y < _h * 51 / 100) { _hSel = 0; doSelect(); }
            else if (y < _h * 64 / 100) {
                if (x < _w / 4) { _hSel = 1; }
                else if (x < _w / 2) { _hSel = 2; }
                else if (x < _w * 3 / 4) { _hSel = 3; }
                else { _hSel = 4; }
                doSelect();
            }
            else if (y < _h * 78 / 100) { _hSel = 5; doSelect(); }
            else { _hSel = 6; doSelect(); }
        } else if (_gs == FT_MORE) {
            var fntH = Graphics.getFontHeight(Graphics.FONT_XTINY);
            var itemH = fntH + 4;
            var totalH = itemH * 8;
            var startY = (_h - totalH) / 2;
            for (var i = 0; i < 8; i++) {
                var ry = startY + i * itemH;
                if (y >= ry && y < ry + itemH) { _mSel = i; doSelect(); return; }
            }
        } else if (_gs == FT_PLAN) {
            if (y < _h / 2) { doUp(); } else { doDown(); }
        } else if (_gs == FT_CUST) {
            var r = 0;
            var nRows = _custRows();
            if (_cstRowY3 > 0) {
                var rowStep = _cstRowY3 - _cstRowY2; // pixel height of one row (consistent)
                var m01 = (_cstRowY0 + _cstRowY1) / 2;
                var m12 = (_cstRowY1 + _cstRowY2) / 2;
                var m23 = (_cstRowY2 + _cstRowY3) / 2;
                var m34 = _cstRowY3 + rowStep / 2;
                var m45 = _cstRowY3 + rowStep + rowStep / 2;
                if (y < m01)             { r = 0; }
                else if (y < m12)        { r = 1; }
                else if (y < m23)        { r = 2; }
                else if (y < m34)        { r = 3; }
                else if (nRows > 5 && y < m45) { r = 4; }
                else                     { r = nRows - 1; }
            } else {
                var rowPct = 100 / nRows;
                r = nRows - 1;
                for (var ri = 0; ri < nRows - 1; ri++) {
                    if (y < _h * (rowPct * (ri + 1)) / 100) { r = ri; ri = nRows; }
                }
            }
            _cF = r;
            _actCustRow();
        } else if (_gs == FT_BCFG || _gs == FT_TCFG || _gs == FT_NAME) {
            if (y < _h / 2) { doUp(); } else { doDown(); }
        } else if (_gs == FT_STAT) {
            _stPg = (_stPg + 1) % 5;
        } else { doSelect(); }
    }

    hidden function _startBr(save) {
        if (save) { _savePreset(); }
        _pauseCnt = 0;
        if (_brM < BR_PRESETS) {
            var mp = BR_PAT[_brM];
            _brPat = [mp[0], mp[1], mp[2], mp[3]];
        } else {
            _brPat = [BR_INH[_brII], BR_HLD[_brHI], BR_EXH[_brEI], BR_HLD[_brXI]];
        }
        _brSS = BR_SES[_brSI] * 60; _brRem = _brSS; _brBC = 0;
        _brPh = BP_INH; _brPD = _brPat[BP_INH]; _brPE = 0; _brPS = 0; _brTrans = 0;
        _actStart("Breathwork");
        _gs = FT_ACT; _vibe(80, 300);
        _snSessionStart();
    }

    hidden function _startAp() {
        _savePreset();
        _pauseCnt = 0;
        _apE = 0; _apPS = -1; _apNP = false; _apWF = false;
        _apPrevPB = _apPB;
        _mfFlags = 0;
        _actStart("Apnea Hold");
        _gs = FT_ACT; _vibe(40, 70);
        _snSessionStart();
    }

    hidden function _stopAp() {
        var s = _apE / 5; _apLS = s;
        _vibe(100, 600);
        _snSessionEndAp();
        if (s >= 5) {
            _apLog[2] = _apLog[1]; _apLog[1] = _apLog[0]; _apLog[0] = s;
            Application.Storage.setValue("ap_lg0", _apLog[0]);
            Application.Storage.setValue("ap_lg1", _apLog[1]);
            Application.Storage.setValue("ap_lg2", _apLog[2]);
            if (s > _apPB) {
                _apPB = s; _apNP = true;
                Application.Storage.setValue("ap_pb", _apPB);
                _calcApTh();
            }
            _pushApHist(s);
            _stHoldT += s; Application.Storage.setValue("st_holdt", _stHoldT);
        }
        _saveSt(FM_AP, s, s);
        _calcSessionScore(FM_AP, s, 0, 0);
        _physioSessionEnd(FM_AP);
        if (s >= 30) { _trackSuccess(FM_AP); } else if (s < 15) { _trackFail(FM_AP); }
        _updStreak();
        if (_plFromPlan) {
            var apOut = PO_NORMAL;
            if (s < 15) { apOut = PO_REPEAT; }
            else if (_apPB > 0 && s * 10 >= _apPB * 11) { apOut = PO_SKIP; }
            _planAdvanceWith(apOut); _plFromPlan = false;
        }
        _gs = FT_DONE;
    }

    hidden function _startTbl() {
        _savePreset();
        _pauseCnt = 0;
        var maxH = TBL_MX[_tMxI];
        _tTR = TBL_RN[_tRnI];
        if (_mode == FM_CO) { _genCO2(maxH, _tTR); }
        else { _genO2(maxH, _tTR); }
        _tRnd = 0; _tPh = BP_PRP; _tPS = 3; _tPE = 0; _tPSub = 0;
        _actStart(_mode == FM_CO ? "CO2 Table" : "O2 Table");
        _gs = FT_ACT; _vibe(80, 300);
        _snSessionStart();
    }

    hidden function _brFldCnt() { return (_brM == BR_PRESETS) ? 7 : 3; }

    hidden function _adjBrF(dir) {
        var nm = BR_PRESETS + 1;   // 5 presets + custom
        if (_brM < BR_PRESETS) {
            if (_brF == 0) { _brM = (_brM + dir + nm) % nm; }
            else if (_brF == 1) { _brSI = (_brSI + dir + BR_SES.size()) % BR_SES.size(); }
        } else {
            if      (_brF == 0) { _brM = (_brM + dir + nm) % nm; }
            else if (_brF == 1) { _brII = (_brII + dir + BR_INH.size()) % BR_INH.size(); }
            else if (_brF == 2) { _brHI = (_brHI + dir + BR_HLD.size()) % BR_HLD.size(); }
            else if (_brF == 3) { _brEI = (_brEI + dir + BR_EXH.size()) % BR_EXH.size(); }
            else if (_brF == 4) { _brXI = (_brXI + dir + BR_HLD.size()) % BR_HLD.size(); }
            else if (_brF == 5) { _brSI = (_brSI + dir + BR_SES.size()) % BR_SES.size(); }
        }
        if (_brM < BR_PRESETS && _brF > 2) { _brF = 1; }
    }

    hidden function _adjTF(dir) {
        if (_tF == 0) { _tMxI = (_tMxI + dir + TBL_MX.size()) % TBL_MX.size(); }
        else if (_tF == 1) { _tRnI = (_tRnI + dir + TBL_RN.size()) % TBL_RN.size(); }
        else if (_tF == 2) { _tDiff = (_tDiff + dir + 3) % 3; }
    }

    hidden function _adjCust(dir) {
        if (_cF == 0) { _thIdx = (_thIdx + dir + 10 + 10) % 10; _applyTheme(); }
        else if (_cF == 2) { _vibOn = !_vibOn; if (_vibOn) { _vibe(60, 120); } }
    }

    hidden function _adjNmCh(dir) {
        var len = NM_CH.length();
        _nmChrs[_nmPos] = (_nmChrs[_nmPos] + dir + len) % len;
    }

    hidden function _loadPresets() {
        var v;
        v = Application.Storage.getValue("sv_co_mx");
        _svCoMx = (v instanceof Number && v >= 0 && v < 8) ? v : 2;
        v = Application.Storage.getValue("sv_co_rn");
        _svCoRn = (v instanceof Number && v >= 0 && v < 5) ? v : 2;
        v = Application.Storage.getValue("sv_o2_mx");
        _svO2Mx = (v instanceof Number && v >= 0 && v < 8) ? v : 2;
        v = Application.Storage.getValue("sv_o2_rn");
        _svO2Rn = (v instanceof Number && v >= 0 && v < 5) ? v : 2;
        v = Application.Storage.getValue("sv_br_m");
        _svBrM  = (v instanceof Number && v >= 0 && v <= BR_PRESETS) ? v : 0;
        v = Application.Storage.getValue("sv_br_ii");
        _svBrII = (v instanceof Number && v >= 0 && v < 7) ? v : 2;
        v = Application.Storage.getValue("sv_br_hi");
        _svBrHI = (v instanceof Number && v >= 0 && v < 5) ? v : 0;
        v = Application.Storage.getValue("sv_br_ei");
        _svBrEI = (v instanceof Number && v >= 0 && v < 7) ? v : 2;
        v = Application.Storage.getValue("sv_br_xi");
        _svBrXI = (v instanceof Number && v >= 0 && v < 5) ? v : 0;
        v = Application.Storage.getValue("sv_br_si");
        _svBrSI = (v instanceof Number && v >= 0 && v < 5) ? v : 1;
        v = Application.Storage.getValue("sv_co_df");
        _svCoDf = (v instanceof Number && v >= 0 && v <= 2) ? v : DP_STD;
        v = Application.Storage.getValue("sv_o2_df");
        _svO2Df = (v instanceof Number && v >= 0 && v <= 2) ? v : DP_STD;
    }

    hidden function _savePreset() {
        _lastMode = _mode;
        Application.Storage.setValue("lst_md", _mode);
        if (_mode == FM_CO) {
            Application.Storage.setValue("sv_co_mx", _tMxI);
            Application.Storage.setValue("sv_co_rn", _tRnI);
            Application.Storage.setValue("sv_co_df", _tDiff);
            _svCoMx = _tMxI; _svCoRn = _tRnI; _svCoDf = _tDiff;
        } else if (_mode == FM_O2) {
            Application.Storage.setValue("sv_o2_mx", _tMxI);
            Application.Storage.setValue("sv_o2_rn", _tRnI);
            Application.Storage.setValue("sv_o2_df", _tDiff);
            _svO2Mx = _tMxI; _svO2Rn = _tRnI; _svO2Df = _tDiff;
        } else if (_mode == FM_BR) {
            Application.Storage.setValue("sv_br_m", _brM);
            Application.Storage.setValue("sv_br_ii", _brII);
            Application.Storage.setValue("sv_br_hi", _brHI);
            Application.Storage.setValue("sv_br_ei", _brEI);
            Application.Storage.setValue("sv_br_xi", _brXI);
            Application.Storage.setValue("sv_br_si", _brSI);
            _svBrM = _brM; _svBrII = _brII; _svBrHI = _brHI;
            _svBrEI = _brEI; _svBrXI = _brXI; _svBrSI = _brSI;
        }
    }

    hidden function _planSessions(pl) {
        if (pl == PL_BEG)  { return PL_BEG_S; }
        if (pl == PL_CO2)  { return PL_CO2_S; }
        if (pl == PL_APN)  { return PL_APN_S; }
        if (pl == PL_O2)   { return PL_O2_S; }
        if (pl == PL_BRTH) { return PL_BRTH_S; }
        if (pl == PL_MIX)  { return PL_MIX_S; }
        if (pl == PL_STA)  { return PL_STA_S; }
        return PL_REC_S;
    }

    hidden function _planLen(pl) { return _planSessions(pl).size(); }

    hidden function _planCurSes() {
        if (_plAct == PL_NONE) { return null; }
        var ss = _planSessions(_plAct);
        if (_plDay >= ss.size()) { return null; }
        return ss[_plDay];
    }

    hidden function _planStartPlan(pl) {
        _plAct = pl; _plDay = 0;
        Application.Storage.setValue("pl_act", _plAct);
        Application.Storage.setValue("pl_day", _plDay);
    }

    hidden function _planAbandon() {
        _plAct = PL_NONE; _plDay = 0;
        Application.Storage.setValue("pl_act", _plAct);
        Application.Storage.setValue("pl_day", _plDay);
    }

    hidden function _planAdvance() { _planAdvanceWith(PO_NORMAL); }

    hidden function _planAdvanceWith(outcome) {
        _plLastOut = outcome;
        if (outcome == PO_REPEAT) {
            Application.Storage.setValue("pl_act", _plAct);
            Application.Storage.setValue("pl_day", _plDay);
            return;
        }
        var step = (outcome == PO_SKIP) ? 2 : 1;
        _plDay += step;
        if (_plDay >= _planLen(_plAct)) {
            _plAct = PL_NONE; _plDay = 0;
        }
        Application.Storage.setValue("pl_act", _plAct);
        Application.Storage.setValue("pl_day", _plDay);
    }

    // Estimate days remaining for the current plan based on weekly pace.
    // Returns "" when there's not enough signal yet.
    hidden function _planEtaLabel() {
        if (_plAct == PL_NONE) { return ""; }
        var remaining = _planLen(_plAct) - _plDay;
        if (remaining <= 0) { return ""; }
        // Use last 7d active days as the proxy for weekly cadence.
        var today = _curEpochDay();
        _advanceDayBits(today);
        var d7 = _activeDays(7);
        if (d7 < 2) { return ""; }
        // Daily rate (sessions/day) — clamp to [0.3, 1.5] to avoid silly extremes
        var ratePer10 = d7 * 10 / 7;
        if (ratePer10 < 3)  { ratePer10 = 3; }
        if (ratePer10 > 15) { ratePer10 = 15; }
        var days = remaining * 10 / ratePer10;
        if (days <= 1) { return "~1 day left"; }
        return "~" + days + " days left";
    }

    hidden function _planMenuMax() {
        // returns last selectable index (0..max)
        // PL_NONE → PL_COUNT entries + Cancel = indices 0..PL_COUNT
        if (_plAct == PL_NONE) { return PL_COUNT; }
        return 2;
    }

    hidden function _planSesLabel(s) {
        if (s == null) { return ""; }
        var m = s[0];
        if (m == FM_BR) {
            if (s[1] < BR_PRESETS) { return BR_LBL[s[1]] + " " + BR_SES[s[2]] + "m"; }
            return "Custom breathe";
        }
        if (m == FM_AP) { return "Static Apnea"; }
        if (m == FM_CO) { return "CO2 " + _fmt(TBL_MX[s[1]]) + " " + TBL_RN[s[2]] + "r " + DP_LBL[s[3]]; }
        return "O2 " + _fmt(TBL_MX[s[1]]) + " " + TBL_RN[s[2]] + "r " + DP_LBL[s[3]];
    }

    hidden function _planApply(s) {
        var m = s[0];
        _mode = m;
        if (m == FM_BR) {
            _brM = s[1]; _brSI = s[2];
            _brII = _svBrII; _brHI = _svBrHI; _brEI = _svBrEI; _brXI = _svBrXI;
        } else if (m == FM_CO || m == FM_O2) {
            _tMxI = s[1]; _tRnI = s[2]; _tDiff = s[3];
        }
    }

    hidden function _planStartCurrent() {
        var s = _planCurSes();
        if (s == null) { _plAct = PL_NONE; return; }
        _planApply(s);
        _plLastOut = PO_NORMAL;
        _plFromPlan = true;
        if (_mode == FM_BR) { _startBr(true); }
        else if (_mode == FM_AP) { _startAp(); }
        else { _startTbl(); }
    }

    hidden function _trState() {
        if (_coachFatigueHigh() || _rdLast == RD_REST) { return TS_RECOVERY; }
        if (_stStreak >= 4) { return TS_PEAK; }
        if (_stSucCo >= 2 || _stSucO2 >= 2 || _stStreak >= 2) { return TS_BUILDING; }
        return TS_STABLE;
    }

    hidden function _coachFatigueHigh() {
        if (_stStreak >= 3) { return true; }
        if (_apHist[0] > 0 && _apHist[1] > 0 && _apHist[2] > 0
            && _apHist[0] < _apHist[1] && _apHist[1] < _apHist[2]) { return true; }
        return false;
    }

    hidden function _coachConfidenceLow() {
        var suc = _stSucCo + _stSucO2;
        var fail = _stFailCo + _stFailO2;
        return (fail >= 2 && fail >= suc);
    }

    hidden function _applyCoachModifiers() {
        var fatigue = _coachFatigueHigh();
        var lowConf = _coachConfidenceLow();

        if (fatigue) {
            if (_mode == FM_AP) {
                _mode = FM_BR; _brM = 0; _brSI = 1;
                _brII = _svBrII; _brHI = _svBrHI; _brEI = _svBrEI; _brXI = _svBrXI;
                return;
            }
            if (_mode == FM_O2 && _tDiff == DP_HARD) { _tDiff = DP_EASY; }
            else if (_mode == FM_CO && _tDiff == DP_HARD) { _tDiff = DP_STD; }
            if (_mode == FM_CO) { _tDiff = DP_EASY; }
        }

        if (lowConf) {
            if (_mode == FM_CO && _tDiff > DP_EASY) { _tDiff--; }
            if (_mode == FM_O2 && _tDiff > DP_EASY) { _tDiff--; }
            if (_mode == FM_CO && _tMxI > 0) { _tMxI--; }
        }

        _rdDowngrade = false;
        if (_rdLast == RD_REST) {
            _mode = FM_BR; _brM = 0; _brSI = 0;
            _brII = _svBrII; _brHI = _svBrHI; _brEI = _svBrEI; _brXI = _svBrXI;
            _rdDowngrade = true;
        } else if (_rdLast == RD_LIGHT) {
            if (_mode == FM_AP) {
                _mode = FM_BR; _brM = 1; _brSI = 1;
                _rdDowngrade = true;
            } else if (_mode == FM_CO || _mode == FM_O2) {
                _tDiff = DP_EASY;
                _rdDowngrade = true;
            }
        }
        if (_rdLast >= 0) {
            _rdLast = -1;
            Application.Storage.setValue("rd_last", _rdLast);
        }
    }

    hidden function _recModeAndApply() {
        if (_plAct != PL_NONE) {
            var s = _planCurSes();
            if (s != null) {
                _planApply(s); _plFromPlan = true;
                _applyCoachModifiers();
                return;
            }
        }
        _plFromPlan = false;
        if (_lastMode == FM_CO) {
            var succ = _stSucCo; var fail = _stFailCo;
            if (fail >= 2 && fail >= succ) {
                _mode = FM_BR; _brM = 0; _brSI = 0;
            } else if (succ >= 3) {
                _mode = FM_O2; _tMxI = _svCoMx; _tRnI = _svCoRn; _tDiff = _svCoDf;
            } else {
                _mode = FM_CO; _tMxI = _svCoMx; _tRnI = _svCoRn; _tDiff = _svCoDf;
            }
        } else if (_lastMode == FM_O2) {
            if (_stSucO2 >= 3) {
                _mode = FM_AP;
            } else {
                _mode = FM_O2; _tMxI = _svO2Mx; _tRnI = _svO2Rn; _tDiff = _svO2Df;
            }
        } else if (_lastMode == FM_AP) {
            _mode = FM_CO; _tMxI = _svCoMx; _tRnI = _svCoRn; _tDiff = _svCoDf;
        } else {
            _mode = FM_BR; _brM = _svBrM; _brSI = _svBrSI;
            _brII = _svBrII; _brHI = _svBrHI; _brEI = _svBrEI; _brXI = _svBrXI;
        }
        _applyPhysioOverride();
        _applyCoachModifiers();
    }

    // Physio priority layer: overrides only the suggestion (never blocks).
    hidden function _applyPhysioOverride() {
        if (_brRecScore < 40) {
            _mode = FM_BR; _brM = 0; _brSI = 1;
            return;
        }
        if (_coTolScore < 50 && _mode != FM_BR) {
            _mode = FM_CO; _tMxI = _svCoMx; _tRnI = _svCoRn; _tDiff = _svCoDf;
            return;
        }
        if (_o2AdaptScore < 50 && _mode != FM_BR && _mode != FM_CO) {
            _mode = FM_O2; _tMxI = _svO2Mx; _tRnI = _svO2Rn; _tDiff = _svO2Df;
        }
    }

    hidden function _recLabel() {
        if (_plAct != PL_NONE) {
            var s = _planCurSes();
            if (s != null) {
                return "Plan " + (_plDay + 1) + "/" + _planLen(_plAct);
            }
        }
        return "Recommended session";
    }

    hidden function _recDetail() {
        if (_plAct != PL_NONE) {
            var s = _planCurSes();
            if (s != null) { return _planSesLabel(s); }
        }
        if (_mode == FM_CO) { return "CO2 " + _fmt(TBL_MX[_tMxI]) + " " + DP_LBL[_tDiff]; }
        if (_mode == FM_O2) { return "O2 " + _fmt(TBL_MX[_tMxI]) + " " + DP_LBL[_tDiff]; }
        if (_mode == FM_AP) { return "Static Apnea"; }
        if (_brM < BR_PRESETS) { return BR_LBL[_brM] + " " + BR_SES[_brSI] + "m"; }
        return "Custom breathe";
    }

    hidden function _recStart() {
        _recModeAndApply();
        if (_mode == FM_BR) { _startBr(true); }
        else if (_mode == FM_AP) { _startAp(); }
        else { _startTbl(); }
    }

    hidden function _instantStart(md) {
        _mode = md;
        _plFromPlan = false;
        if (md == FM_CO) {
            _tMxI = _svCoMx; _tRnI = _svCoRn; _tDiff = _svCoDf;
            _startTbl();
        } else if (md == FM_O2) {
            _tMxI = _svO2Mx; _tRnI = _svO2Rn; _tDiff = _svO2Df;
            _startTbl();
        } else if (md == FM_AP) {
            _startAp();
        } else {
            _brM = _svBrM; _brII = _svBrII; _brHI = _svBrHI;
            _brEI = _svBrEI; _brXI = _svBrXI; _brSI = _svBrSI;
            _startBr(true);
        }
    }

    hidden function _quickBreathe() {
        _mode = FM_BR;
        _plFromPlan = false;
        _brM = 0; _brSI = 1;
        _startBr(false);
    }

    hidden function _rdStart() {
        _gs = FT_READY;
        _rdPh = RP_BREATHE; _rdT = 0; _rdSub = 0; _rdApE = 0; _rdBrPh = 0;
        _vibe(70, 150);
    }

    hidden function _rdFinish() {
        var s = _rdApE / 10;
        if (s >= 30 && (_apPB == 0 || s * 100 >= _apPB * 50)) { _rdLast = RD_READY; }
        else if (s >= 15) { _rdLast = RD_LIGHT; }
        else { _rdLast = RD_REST; }
        Application.Storage.setValue("rd_last", _rdLast);
        _vibe(100, 400);
        _rdPh = RP_RESULT;
    }

    hidden function _trackSuccess(md) {
        if (md == FM_CO) { _stSucCo++; Application.Storage.setValue("st_suc_co", _stSucCo); }
        else if (md == FM_O2) { _stSucO2++; Application.Storage.setValue("st_suc_o2", _stSucO2); }
        else if (md == FM_AP) { _stSucAp++; Application.Storage.setValue("st_suc_ap", _stSucAp); }
    }

    hidden function _trackFail(md) {
        if (md == FM_CO) { _stFailCo++; Application.Storage.setValue("st_fail_co", _stFailCo); }
        else if (md == FM_O2) { _stFailO2++; Application.Storage.setValue("st_fail_o2", _stFailO2); }
        else if (md == FM_AP) { _stFailAp++; Application.Storage.setValue("st_fail_ap", _stFailAp); }
    }

    hidden function _progressCheck() {
        if (_stSucCo >= 3 && _svCoMx < 6) {
            _svCoMx++; _stSucCo = 0;
            Application.Storage.setValue("sv_co_mx", _svCoMx);
            Application.Storage.setValue("st_suc_co", _stSucCo);
        } else if (_stFailCo >= 2 && _svCoMx > 0) {
            _svCoMx--; _stFailCo = 0;
            Application.Storage.setValue("sv_co_mx", _svCoMx);
            Application.Storage.setValue("st_fail_co", _stFailCo);
        }
        if (_stSucO2 >= 3 && _svO2Mx < 6) {
            _svO2Mx++; _stSucO2 = 0;
            Application.Storage.setValue("sv_o2_mx", _svO2Mx);
            Application.Storage.setValue("st_suc_o2", _stSucO2);
        } else if (_stFailO2 >= 2 && _svO2Mx > 0) {
            _svO2Mx--; _stFailO2 = 0;
            Application.Storage.setValue("sv_o2_mx", _svO2Mx);
            Application.Storage.setValue("st_fail_o2", _stFailO2);
        }
    }

    hidden function _pushApHist(s) {
        for (var i = 4; i > 0; i--) { _apHist[i] = _apHist[i - 1]; }
        _apHist[0] = s;
        for (var j = 0; j < 5; j++) {
            Application.Storage.setValue("ap_h" + j.toString(), _apHist[j]);
        }
    }

    hidden function _updStreak() {
        var now = Time.now().value() / 86400;
        if (_stLastDay == 0) {
            _stStreak = 1;
        } else if (now == _stLastDay) {
        } else if (now == _stLastDay + 1) {
            _stStreak++;
        } else {
            _stStreak = 1;
        }
        _stLastDay = now;
        Application.Storage.setValue("st_streak", _stStreak);
        Application.Storage.setValue("st_lastday", _stLastDay);
    }

    hidden function _apTrend() {
        var a = 0; var b = 0; var ac = 0; var bc = 0;
        for (var i = 0; i < 2; i++) { if (_apHist[i] > 0) { a += _apHist[i]; ac++; } }
        for (var j = 2; j < 5; j++) { if (_apHist[j] > 0) { b += _apHist[j]; bc++; } }
        if (ac == 0 || bc == 0) { return 0; }
        var av = a / ac; var bv = b / bc;
        if (av > bv + 2) { return 1; }
        if (av < bv - 2) { return -1; }
        return 0;
    }

    hidden function _applyTheme() {
        if (_thIdx == 0) {       // Ocean — blues/teals only, no warm tones
            _cINH=0x00BBEE; _cHI=0x00DDAA; _cEXH=0x8866EE; _cHE=0x3A88BB;
            _cPRP=0x44AACC; _cRST=0x3399DD; _cHLD=0x00CCAA;
        } else if (_thIdx == 1) { // Sunset — warm but no pure yellow
            _cINH=0xFF7744; _cHI=0xFF9966; _cEXH=0xCC4466; _cHE=0xBB4433;
            _cPRP=0xFF5533; _cRST=0xFF8855; _cHLD=0xFFBB66;
        } else if (_thIdx == 2) { // Forest — greens only, no yellow-green
            _cINH=0x33CC66; _cHI=0x55CC66; _cEXH=0x55AA44; _cHE=0x338844;
            _cPRP=0x44BB88; _cRST=0x44BB77; _cHLD=0x66CC44;
        } else if (_thIdx == 3) { // Arctic — ice blues, unchanged
            _cINH=0x88DDFF; _cHI=0xAAEEFF; _cEXH=0x6699FF; _cHE=0x88BBDD;
            _cPRP=0xDDEEFF; _cRST=0x77CCEE; _cHLD=0xAADDFF;
        } else if (_thIdx == 4) { // Neon — electric, no yellow-white
            _cINH=0xFF00CC; _cHI=0x00FF88; _cEXH=0xCC00FF; _cHE=0xFF0088;
            _cPRP=0xFF66FF; _cRST=0x00CCFF; _cHLD=0x66FF66;
        } else if (_thIdx == 5) { // Midnight — cool purples/blues, unchanged
            _cINH=0x6677FF; _cHI=0x99AAFF; _cEXH=0x3344CC; _cHE=0x4455DD;
            _cPRP=0xBBCCFF; _cRST=0x5566EE; _cHLD=0x7788FF;
        } else if (_thIdx == 6) { // Magma — reds/oranges, no yellow
            _cINH=0xFF4422; _cHI=0xFF6633; _cEXH=0xDD2200; _cHE=0xCC3311;
            _cPRP=0xFF8844; _cRST=0xFF6644; _cHLD=0xFF8833;
        } else if (_thIdx == 7) { // Reef — teal + coral, no peach-yellow
            _cINH=0x00CCAA; _cHI=0xFF8866; _cEXH=0x00AA88; _cHE=0x00AA88;
            _cPRP=0x44DDCC; _cRST=0x44DDBB; _cHLD=0x66FFDD;
        } else if (_thIdx == 8) { // Aurora — purples/greens, unchanged
            _cINH=0x44EE99; _cHI=0xCC66FF; _cEXH=0x22CC77; _cHE=0xAA44DD;
            _cPRP=0xDDAAFF; _cRST=0x66FFAA; _cHLD=0x88DDBB;
        } else {                  // Mono — greys/whites, unchanged
            _cINH=0xDDDDDD; _cHI=0xFFFFFF; _cEXH=0x888888; _cHE=0xAAAAAA;
            _cPRP=0xEEEEEE; _cRST=0xCCCCCC; _cHLD=0xBBBBBB;
        }
    }

    hidden function _bldNm() {
        var s = "";
        for (var i = 0; i < 8; i++) { s = s + NM_CH.substring(_nmChrs[i], _nmChrs[i] + 1); }
        var len = 8;
        while (len > 0 && _nmChrs[len - 1] == 36) { len--; }
        if (len == 0) { return "USER"; }
        return s.substring(0, len);
    }

    hidden function _saveCustom() {
        _nmStr = _bldNm();
        Application.Storage.setValue("usr_nm", _nmStr);
        Application.Storage.setValue("usr_thm", _thIdx);
        Application.Storage.setValue("usr_vib", _vibOn);
        Application.Storage.setValue("usr_sn", _snOn);
    }

    // dur = total session time (sec) — what gets added to lifetime totals
    // holdSec = actual breath-hold seconds — what gets credited to weekly hold buckets
    //   (caller passes the right number; table sessions split rest from hold themselves)
    // ── Activity Recording ────────────────────────────────────────────────
    hidden function _actStart(name) {
        if (_actSes != null) {
            try { _actSes.stop(); _actSes.discard(); } catch (e) {}
            _actSes = null;
        }
        try {
            _actSes = ActivityRecording.createSession({
                :name     => name,
                :sport    => ActivityRecording.SPORT_GENERIC,
                :subSport => ActivityRecording.SUB_SPORT_GENERIC
            });
            _actSes.start();
        } catch (e) { _actSes = null; }
    }

    // Stop & save/discard; write FIT custom fields before stopping.
    // mode, dur: same as _saveSt; breathCount for BR, holdSec for AP/CO2/O2.
    hidden function _actStop(mode, dur, breathCount, holdSec, calmScore) {
        if (_actSes == null) { return; }
        try {
            // Field IDs: 0=Duration(s) 1=Breaths 2=MaxHold(s) 3=CalmScore
            var f;
            f = _actSes.createField("Duration", 0, FitContributor.DATA_TYPE_UINT32,
                { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => "s" });
            f.setData(dur > 0 ? dur : 0);

            if (mode == FM_BR && breathCount > 0) {
                f = _actSes.createField("Breaths", 1, FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => "br" });
                f.setData(breathCount);
            }
            if ((mode == FM_AP || mode == FM_CO || mode == FM_O2) && holdSec > 0) {
                f = _actSes.createField("MaxHold", 2, FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => "s" });
                f.setData(holdSec);
            }
            if (mode == FM_BR && calmScore > 0) {
                f = _actSes.createField("CalmScore", 3, FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_SESSION });
                f.setData(calmScore > 100 ? 100 : calmScore);
            }
            _actSes.stop();
            if (dur >= 60) { _actSes.save(); }
            else           { _actSes.discard(); }
        } catch (e) {}
        _actSes = null;
    }

    hidden function _actDiscard() {
        if (_actSes == null) { return; }
        try { _actSes.stop(); _actSes.discard(); } catch (e) {}
        _actSes = null;
    }

    hidden function _saveSt(mode, dur, holdSec) {
        _actStop(mode, dur,
            (mode == FM_BR) ? _brBC : 0,
            holdSec,
            (mode == FM_BR) ? _snCalmLast : 0);
        _stTotT += dur; Application.Storage.setValue("st_tot", _stTotT);
        if (mode == FM_BR) {
            _stBrC++; _stBrT += dur;
            Application.Storage.setValue("st_brc", _stBrC);
            Application.Storage.setValue("st_brt", _stBrT);
            _snSessionEndBr();   // record calm score + BB-at-start
        } else if (mode == FM_AP) {
            _stApC++; Application.Storage.setValue("st_apc", _stApC);
        } else if (mode == FM_CO) {
            _stCoC++; Application.Storage.setValue("st_coc", _stCoC);
            _snPushBbAtStart();
        } else {
            _stO2C++; Application.Storage.setValue("st_o2c", _stO2C);
            _snPushBbAtStart();
        }
        _bumpWeekly(holdSec);
    }

    hidden function _thName() {
        if (_thIdx == 0) { return "Ocean"; }
        if (_thIdx == 1) { return "Sunset"; }
        if (_thIdx == 2) { return "Forest"; }
        if (_thIdx == 3) { return "Arctic"; }
        if (_thIdx == 4) { return "Neon"; }
        if (_thIdx == 5) { return "Midnight"; }
        if (_thIdx == 6) { return "Magma"; }
        if (_thIdx == 7) { return "Reef"; }
        if (_thIdx == 8) { return "Aurora"; }
        return "Mono";
    }

    hidden function _fmt(s) {
        if (s < 0) { s = 0; }
        var m = s / 60; var r = s % 60;
        if (r < 10) { return m + ":0" + r; }
        return m + ":" + r;
    }

    hidden function _lighten(c, pct) {
        var r = (c >> 16) & 0xFF; var g = (c >> 8) & 0xFF; var b = c & 0xFF;
        if (pct >= 0) {
            r = r + (255 - r) * pct / 100; g = g + (255 - g) * pct / 100; b = b + (255 - b) * pct / 100;
        } else {
            r = r * (100 + pct) / 100; g = g * (100 + pct) / 100; b = b * (100 + pct) / 100;
        }
        if (r > 255) { r = 255; } if (g > 255) { g = 255; } if (b > 255) { b = 255; }
        if (r < 0) { r = 0; } if (g < 0) { g = 0; } if (b < 0) { b = 0; }
        return (r << 16) | (g << 8) | b;
    }

    hidden function _brPhColor() {
        if (_brPh == BP_INH) { return _cINH; }
        if (_brPh == BP_HI)  { return _cHI; }
        if (_brPh == BP_EXH) { return _cEXH; }
        return _lighten(_cEXH, -38);  // hold-exhale + prep: darkened exhale tone, never warm/yellow
    }

    hidden function _brPhLbl() {
        if (_brPh == BP_INH) { return "INHALE"; }
        if (_brPh == BP_HI)  { return "HOLD"; }
        if (_brPh == BP_EXH) { return "EXHALE"; }
        return "HOLD";
    }

    hidden function _tblPhColor() {
        if (_tPh == BP_PRP) { return _cPRP; }
        if (_tPh == BP_RST) { return _cRST; }
        return _cHLD;
    }

    hidden function _tblPhLbl() {
        if (_tPh == BP_PRP) { return "PREP"; }
        if (_tPh == BP_RST) { return "BREATHE"; }
        return "HOLD";
    }

    hidden function _homePreviewMode() {
        if (_hSel == 1) { return FM_BR; }
        if (_hSel == 2) { return FM_CO; }
        if (_hSel == 3) { return FM_O2; }
        if (_hSel == 4) { return FM_AP; }
        return _lastMode;
    }

    hidden function _homeInfoFor(hSel, m) {
        if (hSel == 1) { return BR_LBL[0] + "  " + BR_SES[1] + "m"; }
        return _homeInfo(m);
    }

    hidden function _homeTitle(m) {
        if (m == FM_CO) { return "CO2 TABLE"; }
        if (m == FM_O2) { return "O2 TABLE"; }
        if (m == FM_AP) { return "STATIC APNEA"; }
        return "BREATHE";
    }

    hidden function _homeInfo(m) {
        if (m == FM_CO) {
            var holdPct = 55;
            if (_svCoDf == DP_EASY) { holdPct = 45; }
            else if (_svCoDf == DP_HARD) { holdPct = 65; }
            var hold = TBL_MX[_svCoMx] * holdPct / 100;
            return "Hold " + _fmt(hold) + "  " + TBL_RN[_svCoRn] + "r " + DP_LBL[_svCoDf];
        }
        if (m == FM_O2) {
            var sp = 50; var ep = 85;
            if (_svO2Df == DP_EASY) { sp = 40; ep = 70; }
            else if (_svO2Df == DP_HARD) { sp = 55; ep = 95; }
            var hS = TBL_MX[_svO2Mx] * sp / 100;
            var hE = TBL_MX[_svO2Mx] * ep / 100;
            return _fmt(hS) + "-" + _fmt(hE) + "  " + DP_LBL[_svO2Df];
        }
        if (m == FM_AP) {
            if (_apPB > 0) { return "PB " + _fmt(_apPB); }
            return "Ready";
        }
        if (_svBrM < 3) { return BR_LBL[_svBrM] + "  " + BR_SES[_svBrSI] + "m"; }
        return BR_INH[_svBrII] + "-" + BR_HLD[_svBrHI] + "-" + BR_EXH[_svBrEI] + "-" + BR_HLD[_svBrXI] + "  " + BR_SES[_svBrSI] + "m";
    }

    hidden function _recOverlay() {
        if (_plAct != PL_NONE) {
            return "PLAN  D" + (_plDay + 1) + "/" + _planLen(_plAct);
        }
        if (_ptOvertrainFlag) { return "OVERTRAINING RISK"; }
        if (_ptPlateauFlag)   { return "PLATEAU DETECTED"; }
        if (_brRecScore < 40) { return "REC  BREATHE  RECOVERY"; }
        if (_rdLast == RD_REST) { return "REST ADVISED"; }
        if (_coTolScore < 50)   { return "REC  CO2  LOW TOL"; }
        if (_o2AdaptScore < 50) { return "REC  O2  ADAPT LOW"; }
        var pv = _previewRecommendation();
        var t = pv[0]; var info = pv[1];
        var short;
        if (t.equals("CO2 TABLE")) { short = "CO2"; }
        else if (t.equals("O2 TABLE")) { short = "O2"; }
        else if (t.equals("STATIC APNEA")) { short = "APNEA"; }
        else { short = "BREATHE"; }
        var diff = "";
        if (short.equals("CO2") || short.equals("O2")) {
            if (info.find("Hard") != null) { diff = " HARD"; }
            else if (info.find("Easy") != null) { diff = " EASY"; }
            else if (info.find("Standard") != null) { diff = " STD"; }
        }
        if (_rdLast == RD_LIGHT) { return "REC  " + short + diff + "  LIGHT"; }
        return "REC  " + short + diff;
    }

    hidden function _previewRecommendation() {
        if (_plAct != PL_NONE) {
            var s = _planCurSes();
            if (s != null) {
                var m = s[0];
                var t;
                if (m == FM_CO) { t = "CO2 TABLE"; }
                else if (m == FM_O2) { t = "O2 TABLE"; }
                else if (m == FM_AP) { t = "STATIC APNEA"; }
                else { t = "BREATHE"; }
                return [t, _planSesLabel(s)];
            }
        }

        var pMode; var pTMxI = _svCoMx; var pTRnI = _svCoRn; var pTDiff = _svCoDf;
        var pBrM = _svBrM; var pBrSI = _svBrSI;

        if (_lastMode == FM_CO) {
            if (_stFailCo >= 2 && _stFailCo >= _stSucCo) {
                pMode = FM_BR; pBrM = 0; pBrSI = 0;
            } else if (_stSucCo >= 3) {
                pMode = FM_O2; pTMxI = _svCoMx; pTRnI = _svCoRn; pTDiff = _svCoDf;
            } else {
                pMode = FM_CO;
            }
        } else if (_lastMode == FM_O2) {
            if (_stSucO2 >= 3) { pMode = FM_AP; }
            else { pMode = FM_O2; pTMxI = _svO2Mx; pTRnI = _svO2Rn; pTDiff = _svO2Df; }
        } else if (_lastMode == FM_AP) {
            pMode = FM_CO; pTMxI = _svCoMx; pTRnI = _svCoRn; pTDiff = _svCoDf;
        } else {
            pMode = FM_BR; pBrM = _svBrM; pBrSI = _svBrSI;
        }

        // Physio override (preview)
        if (_brRecScore < 40) {
            pMode = FM_BR; pBrM = 0; pBrSI = 1;
        } else if (_coTolScore < 50 && pMode != FM_BR) {
            pMode = FM_CO; pTMxI = _svCoMx; pTRnI = _svCoRn; pTDiff = _svCoDf;
        } else if (_o2AdaptScore < 50 && pMode != FM_BR && pMode != FM_CO) {
            pMode = FM_O2; pTMxI = _svO2Mx; pTRnI = _svO2Rn; pTDiff = _svO2Df;
        }

        var fatigue = _coachFatigueHigh();
        var lowConf = _coachConfidenceLow();

        if (fatigue) {
            if (pMode == FM_AP) { pMode = FM_BR; pBrM = 0; pBrSI = 1; }
            else if (pMode == FM_CO) { pTDiff = DP_EASY; }
            else if (pMode == FM_O2 && pTDiff == DP_HARD) { pTDiff = DP_EASY; }
        }
        if (lowConf) {
            if (pMode == FM_CO && pTDiff > DP_EASY) { pTDiff--; }
            if (pMode == FM_O2 && pTDiff > DP_EASY) { pTDiff--; }
            if (pMode == FM_CO && pTMxI > 0) { pTMxI--; }
        }
        if (_rdLast == RD_REST) {
            pMode = FM_BR; pBrM = 0; pBrSI = 0;
        } else if (_rdLast == RD_LIGHT) {
            if (pMode == FM_AP) { pMode = FM_BR; pBrM = 1; pBrSI = 1; }
            else if (pMode == FM_CO || pMode == FM_O2) { pTDiff = DP_EASY; }
        }

        var title; var info;
        if (pMode == FM_CO) {
            title = "CO2 TABLE";
            var holdPct = 55;
            if (pTDiff == DP_EASY) { holdPct = 45; }
            else if (pTDiff == DP_HARD) { holdPct = 65; }
            var hold = TBL_MX[pTMxI] * holdPct / 100;
            info = "Hold " + _fmt(hold) + "  " + TBL_RN[pTRnI] + "r " + DP_LBL[pTDiff];
        } else if (pMode == FM_O2) {
            title = "O2 TABLE";
            var sp = 50; var ep = 85;
            if (pTDiff == DP_EASY) { sp = 40; ep = 70; }
            else if (pTDiff == DP_HARD) { sp = 55; ep = 95; }
            var hS = TBL_MX[pTMxI] * sp / 100; var hE = TBL_MX[pTMxI] * ep / 100;
            info = _fmt(hS) + "-" + _fmt(hE) + "  " + DP_LBL[pTDiff];
        } else if (pMode == FM_AP) {
            title = "STATIC APNEA";
            info = (_apPB > 0) ? ("PB " + _fmt(_apPB)) : "Ready";
        } else {
            title = "BREATHE";
            if (pBrM < 3) { info = BR_LBL[pBrM] + "  " + BR_SES[pBrSI] + "m"; }
            else { info = "Custom  " + BR_SES[pBrSI] + "m"; }
        }

        return [title, info];
    }

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        dc.setColor(0x000000, 0x000000); dc.clear();
        if (_gs == FT_HOME) { _drHome(dc); }
        else if (_gs == FT_MORE) { _drMore(dc); }
        else if (_gs == FT_PLAN) { _drPlan(dc); }
        else if (_gs == FT_HELP) { _drHelp(dc); }
        else if (_gs == FT_READY) { _drReady(dc); }
        else if (_gs == FT_BCFG) { _drBrCfg(dc); }
        else if (_gs == FT_TCFG) { _drTblCfg(dc); }
        else if (_gs == FT_ACT) {
            if (_mode == FM_BR) { _drBrAct(dc); }
            else if (_mode == FM_AP) { _drApAct(dc); }
            else { _drTblAct(dc); }
        } else if (_gs == FT_PAU) { _drPaused(dc); }
        else if (_gs == FT_STAT) { _drStat(dc); }
        else if (_gs == FT_CUST) { _drCust(dc); }
        else if (_gs == FT_NAME) { _drNameEd(dc); }
        else if (_gs == FT_RST) { _drRst(dc); }
        else if (_gs == FT_GTU) { _drGtu(dc); }
        else { _drDone(dc); }

        if (_demoMode > 0) { _drDemoBadge(dc); }
    }

    // Minimal demo overlay — only tiny progress dots at bottom of screen.
    // No "DEMO" label, no slide title (the live screens speak for themselves).
    hidden function _drDemoBadge(dc) {
        var cx = _w / 2;
        var dotR = 2;
        var dotGap = 7;
        var totalW = (DEMO_COUNT - 1) * dotGap;
        var dx0 = cx - totalW / 2;
        var dy = _h * 96 / 100;
        // dim row of dots; current one accents in theme color
        for (var i = 0; i < DEMO_COUNT; i++) {
            if (i == _demoSlide) {
                dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dx0 + i * dotGap, dy, dotR + 1);
            } else if (i < _demoSlide) {
                dc.setColor(_lighten(_cINH, -55), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dx0 + i * dotGap, dy, dotR - 1);
            } else {
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dx0 + i * dotGap, dy, dotR - 1);
            }
        }
    }

    hidden function _drHome(dc) {
        var cx = _w / 2;
        var pm = _homePreviewMode();
        var active = (_hSel <= 4);

        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 5 / 100, Graphics.FONT_XTINY, _nmStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Sensors are shown ONLY during active training sessions.
        // HOME screen stays clean — no sensor overlay here.

        var ovC = _lighten(_cHLD, -10);
        if (_rdLast == RD_REST) { ovC = 0xFF8844; }
        else if (_plAct != PL_NONE) { ovC = _lighten(_cHLD, 15); }
        dc.setColor(ovC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 13 / 100, Graphics.FONT_XTINY, _recOverlay(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(active ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 22 / 100, Graphics.FONT_SMALL, _homeTitle(pm), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(active ? 0x888888 : 0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 33 / 100, Graphics.FONT_XTINY, _homeInfoFor(_hSel, pm), Graphics.TEXT_JUSTIFY_CENTER);

        if (active) {
            var sC = (_tick % 6 < 4) ? _cINH : _lighten(_cINH, 25);
            dc.setColor(sC, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, _h * 44 / 100, Graphics.FONT_SMALL, "START", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x181818, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 15 / 100, _h * 54 / 100, _w * 85 / 100, _h * 54 / 100);

        var pY = _h * 60 / 100;
        var xs = [14, 38, 62, 86];
        var lbs = ["BR", "CO2", "O2", "AP"];
        for (var i = 0; i < 4; i++) {
            dc.setColor((_hSel == i + 1) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w * xs[i] / 100, pY, Graphics.FONT_XTINY, lbs[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_hSel >= 1 && _hSel <= 4) {
            var fH = dc.getFontHeight(Graphics.FONT_XTINY);
            var dotX = _w * xs[_hSel - 1] / 100;
            dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dotX, pY + fH + 3, 2);
        }

        dc.setColor((_hSel == 5) ? _cHLD : _lighten(_cHLD, -60), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 72 / 100, Graphics.FONT_XTINY, "Readiness check", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_hSel == 6) ? _cINH : 0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 83 / 100, Graphics.FONT_XTINY, "More...", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drMore(dc) {
        var cx = _w / 2;
        var labels = ["Breathe", "CO2 Table", "O2 Table", "Training Plan", "Stats", "Customize", "Guide", "Reset"];
        var fntH = dc.getFontHeight(Graphics.FONT_XTINY);
        var itemH = fntH + 4;
        var totalH = itemH * 8;
        var startY = (_h - totalH) / 2;

        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, startY - fntH - 4, Graphics.FONT_XTINY, "MORE", Graphics.TEXT_JUSTIFY_CENTER);

        for (var i = 0; i < 8; i++) {
            var y = startY + i * itemH;
            if (i < 3) {
                dc.setColor((i == _mSel) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
            } else if (i == 3) {
                dc.setColor((i == _mSel) ? _cHI : _lighten(_cHI, -55), Graphics.COLOR_TRANSPARENT);
            } else if (i == 6) {
                dc.setColor((i == _mSel) ? _lighten(_cINH, 20) : 0x336644, Graphics.COLOR_TRANSPARENT);
            } else if (i == 7) {
                dc.setColor((i == _mSel) ? 0xFF6644 : 0x442222, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor((i == _mSel) ? _cINH : 0x444444, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx, y + 2, Graphics.FONT_XTINY, labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── GUIDE / LEGEND ────────────────────────────────────────────────────
    // Scrollable glossary of every symbol, acronym and screen in the app.
    // Mirrors the _drPlan scrolling pattern: UP/DOWN move _hlSel, a window
    // of VISIBLE entries is shown, scroll-indicator dots on the right edge.
    //
    // Lines starting with "── " are section headers (accent colour).
    // All other lines are body text (dimmed white, indented by 2 spaces if
    // the line starts with "  ").
    hidden function _drHelp(dc) {
        var cx = _w / 2;
        var fH  = dc.getFontHeight(Graphics.FONT_XTINY);
        var rowH = fH + 5;
        var visible = 5;

        // Title
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 6 / 100, Graphics.FONT_XTINY, "GUIDE", Graphics.TEXT_JUSTIFY_CENTER);

        // Progress fraction (e.g. "12 / 65")
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 13 / 100, Graphics.FONT_XTINY,
            (_hlSel + 1).toString() + " / " + HLP_N, Graphics.TEXT_JUSTIFY_CENTER);

        // Compute first visible entry — keep selected item in middle of window
        var listTop = _h * 20 / 100;
        var first = _hlSel - visible / 2;
        if (first < 0) { first = 0; }
        if (first > HLP_N - visible) { first = HLP_N - visible; }
        if (first < 0) { first = 0; }

        // Highlight bar behind selected row
        var selRow = _hlSel - first;
        if (selRow >= 0 && selRow < visible) {
            dc.setColor(_lighten(_cINH, -82), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(_w * 5 / 100, listTop + selRow * rowH - 1,
                _w * 82 / 100, rowH, 3);
        }

        // Draw visible entries
        for (var k = 0; k < visible; k++) {
            var idx = first + k;
            if (idx >= HLP_N) { break; }
            var line = HLP[idx];
            var rowY = listTop + k * rowH;
            var sel  = (idx == _hlSel);

            if (line.substring(0, 2).equals("# ")) {
                // Section header — strip the "# " marker before display
                var displayLine = line.substring(2, line.length());
                dc.setColor(sel ? _cHLD : _lighten(_cINH, -20), Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, rowY, Graphics.FONT_XTINY, displayLine, Graphics.TEXT_JUSTIFY_CENTER);
            } else if (line.substring(0, 2).equals("  ")) {
                // Continuation / sub-text (indented)
                dc.setColor(sel ? _lighten(_cINH, -10) : 0x555555, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w * 14 / 100, rowY, Graphics.FONT_XTINY, line, Graphics.TEXT_JUSTIFY_LEFT);
            } else {
                // Normal item
                dc.setColor(sel ? 0xFFFFFF : 0x888888, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w * 10 / 100, rowY, Graphics.FONT_XTINY, line, Graphics.TEXT_JUSTIFY_LEFT);
            }
        }

        // Scroll-indicator dots on right edge (same as _drPlan)
        var dotX  = _w * 95 / 100;
        var dotY0 = listTop;
        var dotH  = visible * rowH;
        for (var di = 0; di < HLP_N; di++) {
            var dy = dotY0 + di * dotH / HLP_N;
            if (di == _hlSel) {
                dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dotX, dy, 2);
            } else {
                dc.setColor(0x2A2A2A, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dotX, dy, 1);
            }
        }

        // Navigation hint at bottom
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 90 / 100, Graphics.FONT_XTINY, "BACK = More", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drRst(dc) {
        var cx = _w / 2;
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 20 / 100, Graphics.FONT_XTINY, "FACTORY RESET", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 32 / 100, Graphics.FONT_SMALL, "Erase all data?", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 46 / 100, Graphics.FONT_XTINY, "Stats, PB, plan,", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, _h * 53 / 100, Graphics.FONT_XTINY, "name, theme cleared", Graphics.TEXT_JUSTIFY_CENTER);
        var pC = (_tick % 10 < 5) ? 0xFF6644 : 0xCC4422;
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 70 / 100, Graphics.FONT_XTINY, "SELECT = YES", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 80 / 100, Graphics.FONT_XTINY, "BACK = cancel", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drGtu(dc) {
        var cx = _w / 2;
        dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 18 / 100, Graphics.FONT_XTINY, "GEN TEST USER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 30 / 100, Graphics.FONT_SMALL, "Load demo data?", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 43 / 100, Graphics.FONT_XTINY, "Fills stats, PB, physio,", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, _h * 51 / 100, Graphics.FONT_XTINY, "sensor trends + demo tour.", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 61 / 100, Graphics.FONT_XTINY, "Your real training data", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, _h * 69 / 100, Graphics.FONT_XTINY, "will be overwritten!", Graphics.TEXT_JUSTIFY_CENTER);
        var pC = (_tick % 10 < 5) ? 0xFFAA00 : 0xCC8800;
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 81 / 100, Graphics.FONT_XTINY, "SELECT = YES", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 89 / 100, Graphics.FONT_XTINY, "BACK = cancel", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _resetAll() {
        Application.Storage.clearValues();
        _svCoMx = 2; _svCoRn = 2; _svCoDf = DP_STD;
        _svO2Mx = 2; _svO2Rn = 2; _svO2Df = DP_STD;
        _svBrM = 0; _svBrII = 2; _svBrHI = 0; _svBrEI = 2; _svBrXI = 0; _svBrSI = 1;
        _brM = _svBrM; _brII = _svBrII; _brHI = _svBrHI;
        _brEI = _svBrEI; _brXI = _svBrXI; _brSI = _svBrSI;
        _tMxI = _svCoMx; _tRnI = _svCoRn; _tDiff = DP_STD;
        _apPB = 0; _apLS = 0; _apNP = false;
        for (var i = 0; i < 3; i++) { _apLog[i] = 0; }
        for (var hi = 0; hi < 5; hi++) { _apHist[hi] = 0; }
        _calcApTh();
        _thIdx = 0;
        var dn = "USER";
        for (var ni = 0; ni < 8; ni++) {
            if (ni < dn.length()) {
                var idx = NM_CH.find(dn.substring(ni, ni + 1));
                _nmChrs[ni] = (idx != null) ? idx : 36;
            } else { _nmChrs[ni] = 36; }
        }
        _nmStr = _bldNm();
        _applyTheme();
        _vibOn = true;
        _stBrC = 0; _stBrT = 0; _stApC = 0; _stCoC = 0; _stO2C = 0; _stTotT = 0;
        _stSucCo = 0; _stFailCo = 0; _stSucO2 = 0; _stFailO2 = 0;
        _stSucAp = 0; _stFailAp = 0; _stStreak = 0; _stLastDay = 0; _stHoldT = 0;
        for (var wi = 0; wi < 8; wi++) { _wkSes[wi] = 0; _wkHold[wi] = 0; }
        _wkBaseDay = 0; _wkBestSes = 0;
        _dayBits = 0; _dayBitsRef = 0;
        // PRO++ physiology — reset in-memory state to match fresh-install defaults.
        // Storage was already wiped by clearValues(); without these, the PROGRESSION
        // and PHYSIOLOGY pages would keep rendering pre-reset histograms / scores
        // until the app restarts (because variables live in RAM independently).
        _coTolScore = 0; _coLastLoad = 0; _coTrend = 0;
        _o2AdaptScore = 0; _o2PeakRatio = 0; _o2Trend = 0;
        _brRecScore = 0; _brEffectLast = 0;
        _stScoreLast = 0; _stScoreAvg = 0;
        _pbPredicted = 0; _pbConfidence = 0;
        _diverCo2 = 0; _diverO2 = 0; _diverRecovery = 0;
        _ptPlateauFlag = false; _ptDeclineFlag = false; _ptOvertrainFlag = false;
        for (var li = 0; li < 3; li++) { _coLoadHist[li] = 0; _o2LoadHist[li] = 0; }
        for (var vi = 0; vi < 5; vi++) { _coVHist[vi] = 0; _o2VHist[vi] = 0; _brVHist[vi] = 0; }
        // Sensor state — keep toggle ON, wipe all accumulated stats and re-detect.
        _snOn = true; _snBradLast = 0; _snBradBest = 0;
        _snHrCur = 0; _snHrStart = 0; _snHrMin = 0; _snHrPeak = 0;
        _snBodyBatt = -1; _snStress = -1; _snSpo2 = -1; _snRestHr = 0;
        _snAvail = 0; _snLastReadT = -100;
        _snBradHist = [0, 0, 0, 0, 0];
        _snCalmLast = 0; _snCalmAvg = 0; _snHrDropAvg = 0;
        _snBbAtStart = [-1, -1, -1, -1, -1];
        try { Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]); _snHrEnabled = true; }
        catch (e) { _snHrEnabled = false; }
        _snDetectAvailability();
        _plAct = PL_NONE; _plDay = 0; _plSel = 0; _plFromPlan = false; _plLastOut = PO_NORMAL;
        _rdLast = -1; _rdDowngrade = false;
        _pauseCnt = 0;
        _lastMode = FM_CO;
        _vibeDouble(80, 120, 80);
        _gs = FT_HOME; _hSel = 0; _mSel = 0;
    }

    hidden function _drPlan(dc) {
        var cx = _w / 2;
        var fH = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 7 / 100, Graphics.FONT_XTINY, "TRAINING PATH", Graphics.TEXT_JUSTIFY_CENTER);

        if (_plAct == PL_NONE) {
            // Compact list: show 4 rows around _plSel, each row = label+desc inline
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 16 / 100, Graphics.FONT_XTINY, "Choose a path", Graphics.TEXT_JUSTIFY_CENTER);

            var rowH = fH + 4;
            var visible = 4;
            var listTop = _h * 26 / 100;
            // window-of-visible-items so selection is always shown
            var first = _plSel - visible / 2;
            if (first < 0) { first = 0; }
            if (first > PL_COUNT + 1 - visible) { first = PL_COUNT + 1 - visible; }
            if (first < 0) { first = 0; }

            // selected highlight bar
            var selRow = _plSel - first;
            if (selRow >= 0 && selRow < visible) {
                dc.setColor(_lighten(_cINH, -78), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(_w * 6 / 100, listTop + selRow * rowH * 2 - 2,
                    _w * 88 / 100, rowH * 2, 4);
            }

            for (var k = 0; k < visible; k++) {
                var idx = first + k;
                if (idx > PL_COUNT) { break; }
                var rowY = listTop + k * rowH * 2;
                var sel = (idx == _plSel);
                if (idx < PL_COUNT) {
                    dc.setColor(sel ? 0xFFFFFF : 0x999999, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(cx, rowY, Graphics.FONT_XTINY, PL_LBL[idx], Graphics.TEXT_JUSTIFY_CENTER);
                    dc.setColor(sel ? _cINH : 0x444444, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(cx, rowY + rowH, Graphics.FONT_XTINY, PL_DESC[idx], Graphics.TEXT_JUSTIFY_CENTER);
                } else {
                    // Cancel row
                    dc.setColor(sel ? 0xFF5533 : 0x442222, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(cx, rowY + rowH / 2, Graphics.FONT_XTINY, "Cancel", Graphics.TEXT_JUSTIFY_CENTER);
                }
            }

            // Scroll indicator dots on right
            var dotX = _w * 95 / 100;
            var dotY0 = _h * 30 / 100;
            var dotGap = (_h * 40 / 100) / (PL_COUNT + 1);
            for (var di = 0; di <= PL_COUNT; di++) {
                if (di == _plSel) {
                    dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(dotX, dotY0 + di * dotGap, 2);
                } else {
                    dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
                    dc.fillCircle(dotX, dotY0 + di * dotGap, 1);
                }
            }
        } else {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 16 / 100, Graphics.FONT_SMALL, PL_LBL[_plAct], Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 27 / 100, Graphics.FONT_XTINY,
                "Session " + (_plDay + 1) + " / " + _planLen(_plAct), Graphics.TEXT_JUSTIFY_CENTER);

            if (_plLastOut == PO_REPEAT) {
                dc.setColor(0xFFA060, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, _h * 33 / 100, Graphics.FONT_XTINY, "Adjusted schedule", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (_plLastOut == PO_SKIP) {
                dc.setColor(_cHLD, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, _h * 33 / 100, Graphics.FONT_XTINY, "Adjusted schedule", Graphics.TEXT_JUSTIFY_CENTER);
            }

            var frac = (_plDay.toFloat() / _planLen(_plAct).toFloat());
            var barW = _w * 60 / 100; var barX = (_w - barW) / 2; var barY = _h * 39 / 100;
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, barW, 4);
            dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, (barW * frac).toNumber(), 4);

            var s = _planCurSes();
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 44 / 100, Graphics.FONT_XTINY, "Next session:", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 51 / 100, Graphics.FONT_XTINY, _planSesLabel(s), Graphics.TEXT_JUSTIFY_CENTER);

            // ETA estimate based on rolling 7-day pace; only show when enough
            // signal exists (≥2 sessions in last week) and the estimate is non-trivial.
            var etaTxt = _planEtaLabel();
            if (etaTxt.length() > 0) {
                dc.setColor(_lighten(_cINH, -15), Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, _h * 58 / 100, Graphics.FONT_XTINY, etaTxt, Graphics.TEXT_JUSTIFY_CENTER);
            }

            var actY = _h * 64 / 100;
            var actH = fH + 4;
            var acts = ["START NEXT", "Skip session", "End path"];
            for (var i = 0; i < 3; i++) {
                if (i == 0) {
                    dc.setColor((i == _plSel) ? _cHLD : _lighten(_cHLD, -55), Graphics.COLOR_TRANSPARENT);
                } else if (i == 2) {
                    dc.setColor((i == _plSel) ? 0xFF6644 : 0x442222, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor((i == _plSel) ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
                }
                dc.drawText(cx, actY + i * actH, Graphics.FONT_XTINY, acts[i], Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden function _drBrCfg(dc) {
        var cx = _w / 2;
        var isCust = (_brM == BR_PRESETS);
        var rows = isCust ? 7 : 3;
        var fH = dc.getFontHeight(Graphics.FONT_XTINY);
        var rowH = _h * 58 / 100 / rows;
        if (rowH > 34) { rowH = 34; }
        if (rowH < 16) { rowH = 16; }
        var sY = (_h - rows * rowH) / 2;

        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 8 / 100, Graphics.FONT_XTINY, "BREATHING", Graphics.TEXT_JUSTIFY_CENTER);

        var cLabels = ["MODE", "INHALE", "HOLD", "EXHALE", "HOLD EX", "SESSION", "START"];

        for (var i = 0; i < rows; i++) {
            var y = sY + i * rowH;
            var sel = (i == _brF);
            var lbl = "";
            var val = "";
            if (!isCust) {
                if (i == 0) { lbl = "MODE"; val = (_brM < BR_PRESETS) ? BR_LBL[_brM] : "Custom"; }
                else if (i == 1) { lbl = "SESSION"; val = BR_SES[_brSI] + " min"; }
                else { lbl = ""; val = ""; }
            } else {
                lbl = cLabels[i];
                if (i == 0) { val = "Custom"; }
                else if (i == 1) { val = BR_INH[_brII] + "s"; }
                else if (i == 2) { val = BR_HLD[_brHI] + "s"; }
                else if (i == 3) { val = BR_EXH[_brEI] + "s"; }
                else if (i == 4) { val = BR_HLD[_brXI] + "s"; }
                else if (i == 5) { val = BR_SES[_brSI] + " min"; }
                else { val = ""; }
            }
            var ty = y + (rowH - fH) / 2;
            if (val.length() > 0) {
                dc.setColor(sel ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, ty, Graphics.FONT_XTINY, lbl + "  " + val, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(sel ? _cHLD : 0x444444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, ty, Graphics.FONT_XTINY, "START", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

    }

    hidden function _drTblCfg(dc) {
        var cx = _w / 2;
        var tag = (_mode == FM_CO) ? "CO2 TABLE" : "O2 TABLE";
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 8 / 100, Graphics.FONT_XTINY, tag, Graphics.TEXT_JUSTIFY_CENTER);

        var fH = dc.getFontHeight(Graphics.FONT_XTINY);
        var rowH = fH + 8; if (rowH > _h / 9) { rowH = _h / 9; }
        var sY = _h * 22 / 100;

        var labels = ["MAX HOLD", "ROUNDS", "PROFILE", "START"];
        var vals = [_fmt(TBL_MX[_tMxI]), TBL_RN[_tRnI].toString(), DP_LBL[_tDiff], ""];

        for (var i = 0; i < 4; i++) {
            var y = sY + i * rowH;
            var sel = (i == _tF);
            if (i < 3) {
                dc.setColor(sel ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, y, Graphics.FONT_XTINY, labels[i] + "  " + vals[i], Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(sel ? _cHLD : 0x444444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, y, Graphics.FONT_XTINY, "START", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        var maxH = TBL_MX[_tMxI];
        var preview = "";
        if (_mode == FM_CO) {
            var hp = 55; var rm = 120; var re = 30;
            if (_tDiff == DP_EASY) { hp = 45; rm = 150; re = 45; }
            else if (_tDiff == DP_HARD) { hp = 65; rm = 100; re = 20; }
            var h = maxH * hp / 100; var rs = h * 2; if (rs > rm) { rs = rm; }
            preview = "Hold " + _fmt(h) + " Rest " + _fmt(rs) + "-" + _fmt(re);
        } else {
            var r = 120; var sp = 50; var ep = 85;
            if (_tDiff == DP_EASY) { r = 150; sp = 40; ep = 70; }
            else if (_tDiff == DP_HARD) { r = 100; sp = 55; ep = 95; }
            preview = "Hold " + _fmt(maxH * sp / 100) + "-" + _fmt(maxH * ep / 100) + " R " + _fmt(r);
        }
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 78 / 100, Graphics.FONT_XTINY, preview, Graphics.TEXT_JUSTIFY_CENTER);

    }

    hidden function _drBrAct(dc) {
        var cx = _w / 2;
        // Ball is centered at 57% so the top portion of screen is free for labels
        var cy = _h * 57 / 100;

        var frac = 0.0;
        if (_brPD > 0) {
            frac = (_brPE.toFloat() + _brPS.toFloat() / 10.0) / _brPD.toFloat();
            if (frac > 1.0) { frac = 1.0; }
        }
        var eF = frac;
        if (_brPh == BP_INH) { eF = 1.0 - (1.0 - frac) * (1.0 - frac); }
        else if (_brPh == BP_EXH) { eF = frac * frac; }

        var rMin = _h * 7 / 100; if (rMin < 9) { rMin = 9; }
        var rMax = _h * 20 / 100;
        var r;
        if      (_brPh == BP_INH) { r = rMin + ((rMax - rMin).toFloat() * eF).toNumber(); }
        else if (_brPh == BP_HI)  { r = rMax; }
        else if (_brPh == BP_EXH) { r = rMax - ((rMax - rMin).toFloat() * eF).toNumber(); }
        else                      { r = rMin; }

        var pC = _brPhColor();

        // Full-screen dark background first
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, _h / 2, _h / 2 + 2);

        // Atmospheric bloom around ball
        var bgR = rMax + 28; if (bgR > _h / 2) { bgR = _h / 2; }
        dc.setColor(_lighten(pC, -91), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, bgR);

        // ── TOP ZONE (above ball): info + phase label ──────────────────
        // At cy=57%, rMax=20%, max halo = rMax+10 = 30% above cy → top of halo = 57%-30% = 27%
        // Info text at 10% and phase label at 20% are both ABOVE the halo zone.

        // Info line: "#3  9:43"
        dc.setColor(0x4A6070, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 10 / 100, Graphics.FONT_XTINY,
            "#" + (_brBC + 1) + "  " + _fmt(_brRem),
            Graphics.TEXT_JUSTIFY_CENTER);

        // Session progress bar — thin, centered, below info
        var fntH = dc.getFontHeight(Graphics.FONT_XTINY);
        var barY = _h * 10 / 100 + fntH + 1;
        var barW = _w * 36 / 100; var barX = (_w - barW) / 2;
        var sessR = 0.0;
        if (_brSS > 0) { sessR = 1.0 - (_brRem.toFloat() / _brSS.toFloat()); }
        if (sessR > 1.0) { sessR = 1.0; }
        dc.setColor(0x0A1A20, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, 2);
        if (sessR > 0.01) {
            dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, (barW.toFloat() * sessR).toNumber(), 2);
        }

        // Phase label: INHALE / EXHALE / HOLD — safely above ball halo
        var lblY = _h * 20 / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, lblY + 1, Graphics.FONT_SMALL, _brPhLbl(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, lblY, Graphics.FONT_SMALL, _brPhLbl(), Graphics.TEXT_JUSTIFY_CENTER);

        // ── BALL ZONE ──────────────────────────────────────────────────
        // Tight halo rings (max r+10) — do NOT reach the phase label above
        var t12 = _tick % 12;
        var hPulse = (t12 < 6) ? (t12 / 3) : ((11 - t12) / 3);
        dc.setColor(_lighten(pC, -84), Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, r + 10 + hPulse);
        dc.setColor(_lighten(pC, -70), Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, r + 7);
        dc.setColor(_lighten(pC, -50), Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, r + 4);
        dc.setColor(_lighten(pC, -28), Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, r + 2);

        // Main ball: 6-layer gradient + specular highlight
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r);
        if (r > 12) {
            dc.setColor(_lighten(pC, 20), Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r * 80 / 100);
            dc.setColor(_lighten(pC, 40), Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r * 60 / 100);
            dc.setColor(_lighten(pC, 58), Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r * 38 / 100);
            dc.setColor(_lighten(pC, 74), Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r * 20 / 100);
            var hiOff = r / 6; var hiR = r * 11 / 100 + 1;
            var coreP = (_tick % 10 < 5) ? 0 : 1;
            dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - hiOff, cy - hiOff, hiR + coreP + 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - hiOff, cy - hiOff, hiR + coreP);
        }

        // Phase progress arc — drawn at fixed radius just outside halo
        var arcRad = rMax + 14;
        var phProg = 0;
        if (_brPD > 0) { phProg = _brPE * 360 / _brPD; if (phProg > 360) { phProg = 360; } }
        dc.setPenWidth(2);
        dc.setColor(_lighten(pC, -80), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, arcRad);
        if (phProg > 0) {
            dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, arcRad, Graphics.ARC_CLOCKWISE, 90, 90 - phProg);
        }
        dc.setPenWidth(1);

        // ── BOTTOM ZONE: countdown below ball ─────────────────────────
        var phRem = _brPD - _brPE;
        var cntY = cy + rMax + 16;
        if (cntY > _h * 88 / 100) { cntY = _h * 88 / 100; }
        dc.setColor(0x000E1A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, cntY + 1, Graphics.FONT_LARGE, phRem.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cntY, Graphics.FONT_LARGE, phRem.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // ── Live HR — right-side column ────────────────────────────────
        // Goal during breathe-up: lower HR. calmMode=true so the chip
        // turns green at a softer 5 BPM drop (vs 10 for full bradycardia).
        _snDrLive(dc, _h * 18 / 100, true);
    }

    hidden function _drApAct(dc) {
        var cx = _w / 2; var cy = _h * 46 / 100;
        var s = _apE / 5;
        var pC = _apColor(s);

        // Underwater gradient background — 12 horizontal bands
        var nbands = 12;
        var bh = _h / nbands + 1;
        for (var i = 0; i < nbands; i++) {
            var rv = 0x06 + i / 3;
            var gv = 0x0E + i / 2;
            var bv = 0x1A + i * 2;
            if (rv > 0x0F) { rv = 0x0F; }
            if (gv > 0x18) { gv = 0x18; }
            if (bv > 0x34) { bv = 0x34; }
            dc.setColor((rv << 16) | (gv << 8) | bv, (rv << 16) | (gv << 8) | bv);
            dc.fillRectangle(0, i * bh, _w, bh);
        }

        // Slightly smaller than v5 (was 36%) so the apnea ring matches the
        // visual proportions of BREATHE / TABLE rings and leaves clean
        // margin for the right-side sensor column.
        var rMax = _w * 31 / 100;
        if (rMax > _h * 31 / 100) { rMax = _h * 31 / 100; }

        // Outer glow rings
        var t6 = _sub / 3 % 6;
        var outerGlow = (t6 < 3) ? t6 / 3 : (6 - t6) / 3;
        dc.setColor(_lighten(pC, -80), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rMax + 5 + outerGlow);
        dc.setColor(_lighten(pC, -68), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rMax + 3);

        dc.setColor(0x060E18, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rMax);
        dc.drawCircle(cx, cy, rMax - 1);

        // PB progress arc — thick pen
        if (_apPB > 0 && s > 0) {
            var arcR = rMax - 6; if (arcR < 8) { arcR = 8; }
            dc.setColor(0x0A1828, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, arcR);
            var pct = s * 360 / _apPB;
            if (pct > 360) { pct = 360; }
            dc.setPenWidth(3);
            if (pct >= 360) {
                dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(cx, cy, arcR);
            } else if (pct > 0) {
                dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, 90, (90 - pct).toNumber());
            }
            dc.setPenWidth(1);
        }

        // HOLD label with shadow
        var nF = Graphics.FONT_NUMBER_HOT;
        var nH = dc.getFontHeight(nF);
        var nY = cy - nH / 2;
        if (nY < _h * 18 / 100) { nY = _h * 18 / 100; }
        var lY = nY - _h * 8 / 100;
        if (lY < _h * 10 / 100) { lY = _h * 10 / 100; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, lY + 1, Graphics.FONT_SMALL, "HOLD", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_lighten(pC, -10), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, lY, Graphics.FONT_SMALL, "HOLD", Graphics.TEXT_JUSTIFY_CENTER);

        // Big time with drop shadow
        dc.setColor(_lighten(pC, -65), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 2, nY + 2, nF, _fmt(s), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, nY, nF, _fmt(s), Graphics.TEXT_JUSTIFY_CENTER);

        if (_apPB > 0) {
            dc.setColor(_lighten(pC, -50), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, nY + nH + 2, Graphics.FONT_XTINY, "PB " + _fmt(_apPB), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Micro-feedback (PRO++ physio cue) — minimal, no spam ──────────
        var mfTxt = _apMicroFeedback(s);
        if (mfTxt != null) {
            dc.setColor(_lighten(pC, 12), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 75 / 100, Graphics.FONT_XTINY, mfTxt, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── Live HR — right-side column ────────────────────────────────
        // Mammalian dive reflex causes HR to drop during breath-hold.
        // Drawn as the unified right-edge chip so the heart rate is
        // always visible peripherally without overlapping the central
        // HOLD timer. Pulses theme color when bradycardia delta ≥ 10 BPM.
        _snDrLive(dc, _h * 18 / 100, false);

        dc.setColor(0x0C1826, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 83 / 100, Graphics.FONT_XTINY, "SELECT = stop", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Returns short cue or null. Each cue shows briefly after threshold crossing.
    hidden function _apMicroFeedback(s) {
        if (_apPB <= 0) { return null; }
        var prevAvg = 0; var pCount = 0;
        for (var i = 0; i < 3; i++) {
            if (_apHist[i] > 0) { prevAvg += _apHist[i]; pCount++; }
        }
        if (pCount > 0) { prevAvg = prevAvg / pCount; }

        // 75% PB threshold (window: 75–80%)
        if (s * 100 >= _apPB * 75 && s * 100 < _apPB * 82) { return "Stay calm"; }
        // 50% PB threshold (window: 50–58%)
        if (s * 100 >= _apPB * 50 && s * 100 < _apPB * 58) { return "Relax"; }
        // Pace warning: well past prev average but still early relative to PB
        if (prevAvg > 0 && s > prevAvg && s * 100 < _apPB * 50 && s * 100 >= _apPB * 35) {
            return "Too fast";
        }
        return null;
    }

    hidden function _drTblAct(dc) {
        var cx = _w / 2; var cy = _h * 52 / 100;
        var pC = _tblPhColor();
        var arcR = _w * 28 / 100;
        if (arcR > _h * 28 / 100) { arcR = _h * 28 / 100; }
        if (arcR > _w / 2 - 10) { arcR = _w / 2 - 10; }

        // Subtle phase-tinted ambient glow
        dc.setColor(_lighten(pC, -93), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, arcR + 26);

        // Round counter — prominent pill at top
        var tag = (_mode == FM_CO) ? "CO2" : "O2";
        var rdStr = tag + "  " + (_tRnd + 1) + " / " + _tTR;
        var fH = dc.getFontHeight(Graphics.FONT_SMALL);
        var pillW = _w * 44 / 100; var pillH = fH + 6;
        var pillX = (_w - pillW) / 2; var pillY = _h * 6 / 100;
        dc.setColor(0x0D1E2E, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(pillX, pillY, pillW, pillH, 6);
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(pillX, pillY, pillW, pillH, 6);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, pillY + 2, Graphics.FONT_SMALL, rdStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Outer thin ring (decorative border)
        dc.setColor(_lighten(pC, -72), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, arcR + 6);
        dc.setColor(_lighten(pC, -80), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, arcR + 5);

        // Inner background ring track
        dc.setColor(0x111E2C, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, arcR);
        dc.drawCircle(cx, cy, arcR - 1);
        dc.setColor(0x0A131F, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, arcR - 2);

        // Phase progress arc — thick
        var prog = 0;
        if (_tPS > 0) { prog = _tPE * 360 / _tPS; }
        dc.setPenWidth(4);
        if (prog >= 360) {
            dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, arcR);
        } else if (prog > 0) {
            dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, 90, 90 - prog);
        }
        dc.setPenWidth(1);

        // Phase label with drop shadow
        var rem = _tPS - _tPE; if (rem < 0) { rem = 0; }
        var nF = Graphics.FONT_NUMBER_MILD;
        var nH = dc.getFontHeight(nF);
        var nY = cy - nH / 2 + _h * 2 / 100;
        var lY = cy - nH / 2 - _h * 7 / 100;
        if (lY < _h * 24 / 100) { lY = _h * 24 / 100; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, lY + 1, Graphics.FONT_SMALL, _tblPhLbl(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, lY, Graphics.FONT_SMALL, _tblPhLbl(), Graphics.TEXT_JUSTIFY_CENTER);

        // Countdown with drop shadow
        dc.setColor(0x000E1A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, nY + 1, nF, _fmt(rem), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, nY, nF, _fmt(rem), Graphics.TEXT_JUSTIFY_CENTER);

        // ── Live HR — right-side column ────────────────────────────────
        // calmMode=true during BREATHE/REST phase (lower threshold for
        // green tint), false during HOLD phase (full bradycardia threshold).
        _snDrLive(dc, _h * 18 / 100, _tPh != BP_HLD);

        // Pause hint
        dc.setColor(0x1E3446, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 88 / 100, Graphics.FONT_XTINY, "SEL = pause", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drPaused(dc) {
        var cx = _w / 2;
        dc.setColor(0x00BBEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 14 / 100, Graphics.FONT_XTINY, "PAUSED", Graphics.TEXT_JUSTIFY_CENTER);

        if (_mode == FM_BR) {
            dc.setColor(_brPhColor(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 28 / 100, Graphics.FONT_SMALL, _brPhLbl(), Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 40 / 100, Graphics.FONT_LARGE, _fmt(_brRem), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(_tblPhColor(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 28 / 100, Graphics.FONT_SMALL, _tblPhLbl(), Graphics.TEXT_JUSTIFY_CENTER);
            var rem = _tPS - _tPE; if (rem < 0) { rem = 0; }
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 40 / 100, Graphics.FONT_LARGE, _fmt(rem), Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x446666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 56 / 100, Graphics.FONT_XTINY,
                "Round " + (_tRnd + 1) + "/" + _tTR, Graphics.TEXT_JUSTIFY_CENTER);
        }

        var hC = (_tick % 12 < 6) ? 0x00BBEE : 0x333333;
        dc.setColor(hC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 68 / 100, Graphics.FONT_XTINY, "SELECT = resume", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 78 / 100, Graphics.FONT_XTINY, "BACK = exit", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drReady(dc) {
        var cx = _w / 2;
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 8 / 100, Graphics.FONT_XTINY, "READINESS CHECK", Graphics.TEXT_JUSTIFY_CENTER);

        if (_rdPh == RP_BREATHE) {
            var rem = 30 - _rdT;
            if (rem < 0) { rem = 0; }
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 22 / 100, Graphics.FONT_XTINY, "Breathe calmly", Graphics.TEXT_JUSTIFY_CENTER);

            var lblC = (_rdBrPh == 0) ? _cINH : _cEXH;
            var lbl = (_rdBrPh == 0) ? "INHALE" : "EXHALE";
            dc.setColor(lblC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 35 / 100, Graphics.FONT_SMALL, lbl, Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 50 / 100, Graphics.FONT_NUMBER_MEDIUM, rem.toString(), Graphics.TEXT_JUSTIFY_CENTER);

            // Live HR chip — shows relaxation trend during breathe-up
            _snDrLive(dc, _h * 18 / 100, true);

            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 78 / 100, Graphics.FONT_XTINY, "SELECT = skip", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, _h * 85 / 100, Graphics.FONT_XTINY, "BACK = cancel", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_rdPh == RP_APNEA) {
            var s = _rdApE / 10;
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 22 / 100, Graphics.FONT_XTINY, "Hold breath", Graphics.TEXT_JUSTIFY_CENTER);

            var pC = _cHLD;
            if (s >= 45) { pC = 0xFFA060; }
            if (s >= 75) { pC = 0xFF5533; }
            dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
            var nF = (_h >= 200) ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_MILD;
            dc.drawText(cx, _h * 38 / 100, nF, _fmt(s), Graphics.TEXT_JUSTIFY_CENTER);

            // Live HR — dive reflex visible as HR drops
            _snDrLive(dc, _h * 18 / 100, false);

            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 78 / 100, Graphics.FONT_XTINY, "SELECT = stop", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var resLbl; var resC;
            if (_rdLast == RD_READY) { resLbl = "READY"; resC = _cHLD; }
            else if (_rdLast == RD_LIGHT) { resLbl = "LIGHT SESSION"; resC = 0xFFA060; }
            else { resLbl = "REST"; resC = 0xFF5533; }

            var flash = (_tick % 10 < 5) ? resC : _lighten(resC, -65);
            dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 28 / 100, Graphics.FONT_MEDIUM, resLbl, Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 48 / 100, Graphics.FONT_XTINY,
                "Hold " + _fmt(_rdApE / 10), Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(_lighten(resC, -25), Graphics.COLOR_TRANSPARENT);
            var hint = (_rdLast == RD_READY) ? "Recommended: normal" :
                       (_rdLast == RD_LIGHT) ? "Recommended: light" : "Recommended: recovery";
            dc.drawText(cx, _h * 58 / 100, Graphics.FONT_XTINY, hint, Graphics.TEXT_JUSTIFY_CENTER);

            // Sensor snapshot — BB + HR give extra confidence in the verdict
            if (_snOn && (_snBodyBatt >= 0 || _snHrCur > 0)) {
                var snTxt = "";
                if (_snHrCur > 0) { snTxt = "HR " + _snHrCur; }
                if (_snBodyBatt >= 0) {
                    if (snTxt.length() > 0) { snTxt = snTxt + "  "; }
                    snTxt = snTxt + "BB " + _snBodyBatt + "%";
                }
                dc.setColor(_lighten(_cINH, -35), Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, _h * 68 / 100, Graphics.FONT_XTINY, snTxt, Graphics.TEXT_JUSTIFY_CENTER);
            }

            var hC = (_tick % 12 < 6) ? _cINH : _lighten(_cINH, -50);
            dc.setColor(hC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 78 / 100, Graphics.FONT_XTINY, "SELECT = start", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 86 / 100, Graphics.FONT_XTINY, "BACK = home", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drDone(dc) {
        var cx = _w / 2;
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 12 / 100, Graphics.FONT_XTINY, "COMPLETE", Graphics.TEXT_JUSTIFY_CENTER);

        if (_mode == FM_AP) {
            var s = _apLS; var pC = _apColor(s);
            var nF = (_h >= 200) ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_MILD;
            var nH = dc.getFontHeight(nF);
            dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 22 / 100, nF, _fmt(s), Graphics.TEXT_JUSTIFY_CENTER);
            var midY = _h * 22 / 100 + nH + _h * 1 / 100;
            if (_apNP) {
                var flash = (_tick % 8 < 4) ? _cHI : _lighten(_cHI, -20);
                dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, midY, Graphics.FONT_SMALL, "NEW PB!", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (_apPB > 0 && s < _apPB) {
                dc.setColor(0x1A3040, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, midY, Graphics.FONT_XTINY,
                    "PB: " + _fmt(_apPB) + "  (-" + (_apPB - s) + "s)", Graphics.TEXT_JUSTIFY_CENTER);
            }
            // Bradycardia readout — positive cue when HR dropped during hold.
            // Placed at 62% (below PB text which can reach ~56% on large fonts).
            if (_snOn && _snBradLast > 0) {
                var bC = (_snBradLast >= 15) ? _cHLD :
                         ((_snBradLast >= 8) ? _lighten(_cINH, -10) : _lighten(_cINH, -30));
                dc.setColor(bC, Graphics.COLOR_TRANSPARENT);
                var bTxt = "HR -" + _snBradLast + " bpm";
                if (_snBradLast >= _snBradBest) { bTxt = bTxt + "  PB"; }
                dc.drawText(cx, _h * 62 / 100, Graphics.FONT_XTINY, bTxt, Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else if (_mode == FM_BR) {
            var flash = (_tick % 10 < 5) ? _cHI : _lighten(_cHI, -20);
            dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 24 / 100, Graphics.FONT_MEDIUM, "DONE!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 40 / 100, Graphics.FONT_LARGE,
                BR_SES[_brSI] + " min", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 54 / 100, Graphics.FONT_SMALL,
                _brBC + " breaths", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var tag = (_mode == FM_CO) ? "CO2 TABLE" : "O2 TABLE";
            var flash = (_tick % 10 < 5) ? _cHI : _lighten(_cHI, -20);
            dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 24 / 100, Graphics.FONT_MEDIUM, "DONE!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(_lighten(_cINH, -40), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 42 / 100, Graphics.FONT_XTINY, tag, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(_lighten(_cINH, -20), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 52 / 100, Graphics.FONT_SMALL,
                _tTR + " rounds", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Feedback lines pushed down to 70/78% so they don't collide with the
        // bradycardia readout (62%) or PB text (~50-56%) on any screen size.
        var l1 = _fbLine1();
        var l2 = _fbLine2();
        if (l1.length() > 0) {
            dc.setColor(_lighten(_cINH, -25), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 70 / 100, Graphics.FONT_XTINY, l1, Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (l2.length() > 0) {
            dc.setColor(_lighten(_cINH, -45), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 78 / 100, Graphics.FONT_XTINY, l2, Graphics.TEXT_JUSTIFY_CENTER);
        }

        var hC = (_tick % 12 < 6) ? _cINH : _lighten(_cINH, -50);
        dc.setColor(hC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 87 / 100, Graphics.FONT_XTINY, "SELECT = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _fbLine1() {
        if (_mode == FM_AP) {
            var s = _apLS;
            if (_apNP) { return "Peak performance"; }
            if (_ptPlateauFlag) { return "Plateau detected"; }
            if (_pbConfidence >= 60 && _pbPredicted > _apPB) { return "Potential unlocked"; }
            if (_apPB > 0 && s * 10 >= _apPB * 9) { return "Strong session"; }
            if (s < 20 || (_apPB > 0 && s * 10 < _apPB * 6)) { return "Light session"; }
            return "Stable session";
        }
        if (_mode == FM_BR) {
            if (_brEffectLast > 0) { return "Recovery effective"; }
            if (_brEffectLast < 0) { return "Recovery insufficient"; }
            return "Recovery session";
        }
        if (_mode == FM_CO) {
            if (_coTrend > 0)        { return "Tolerance improving"; }
            if (_coLastLoad >= 70)   { return "High CO2 load"; }
            if (_pauseCnt >= 2)      { return "High load session"; }
            if (_stSucCo >= 2)       { return "Strong progression"; }
            return "Stable session";
        }
        if (_mode == FM_O2) {
            if (_o2Trend > 0)        { return "Adaptation building"; }
            if (_o2PeakRatio >= 90)  { return "Hypoxia stress high"; }
            if (_pauseCnt >= 2)      { return "High load session"; }
            if (_stSucO2 >= 2)       { return "Strong progression"; }
            return "Stable session";
        }
        return "";
    }

    hidden function _fbLine2() {
        if (_mode == FM_AP) {
            if (_apNP) { return "Recovery recommended"; }
            if (_ptOvertrainFlag) { return "Reduce intensity"; }
            if (_apPB > 0 && _apLS * 10 >= _apPB * 9) { return "Recovery recommended"; }
            if (_apLS < 20) { return "Build gradually"; }
            if (_pbPredicted > 0 && _pbConfidence >= 50) {
                return "Pred PB " + _fmt(_pbPredicted);
            }
            return "Continue progression";
        }
        if (_mode == FM_BR) {
            if (_brRecScore < 40) { return "Rest advised"; }
            if (_plFromPlan) { return "Path continues"; }
            return "Continue progression";
        }
        if (_mode == FM_CO || _mode == FM_O2) {
            if (_pauseCnt >= 2) { return "Rest advised"; }
            if (_plFromPlan) { return "Path continues"; }
            return "Continue progression";
        }
        return "Continue progression";
    }

    // Score-to-color helper used by physio rows
    hidden function _physioColor(val) {
        if (val < 40)      { return 0xFF5533; }
        else if (val < 65) { return 0xFFA060; }
        return _cHLD;
    }

    // Generic mini-trend row: [LABEL]  [5-bar histogram]  [trend  value]
    //   mode = 0 → physio (0..100 scale, _physioColor for newest)
    //   mode = 1 → apnea (PB-scaled, % of PB color tiers)
    //   scaleMax: bar-height denominator. 0 = use 100.
    //   valTxt:   string to render on right; valC: color for that string.
    //   When the newest hist slot is 0 but `val` > 0, renders `val` as the
    //   newest bar so users see something instead of "------".
    hidden function _drTrendRow(dc, y, lbl, val, valTxt, valC, trend, hist, scaleMax, mode) {
        var lblX = _w * 8 / 100;
        var valX = _w * 92 / 100;

        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lblX, y - 6, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_LEFT);

        var hW = _w * 32 / 100;
        var hH = 14;
        var hx = (_w - hW) / 2 + 6;
        var hy = y - hH / 2;
        var sp = 2;
        var bW = (hW - sp * 4) / 5;
        var sMax = (scaleMax > 0) ? scaleMax : 100;

        dc.setColor(_lighten(_cINH, -78), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(hx, hy + hH, hx + hW, hy + hH);

        for (var i = 0; i < 5; i++) {
            var v = hist[4 - i];   // oldest left, newest right
            // Fallback: empty newest slot but we have a current value → use it
            if (i == 4 && (v == null || v <= 0) && val > 0) { v = val; }
            var bx = hx + i * (bW + sp);
            if (v == null || v <= 0) {
                dc.setColor(_lighten(_cINH, -82), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, hy + hH - 2, bW, 2);
            } else {
                var bH = v * hH / sMax;
                if (bH < 2)  { bH = 2; }
                if (bH > hH) { bH = hH; }
                var clr;
                if (i == 4) {
                    if (mode == 1) {
                        var pct = v * 100 / sMax;
                        if (pct >= 80)      { clr = _cHLD; }
                        else if (pct >= 60) { clr = 0xFFA060; }
                        else                { clr = 0xFF5533; }
                    } else {
                        clr = _physioColor(v);
                    }
                } else {
                    clr = _lighten(_cINH, -55);
                }
                dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, hy + hH - bH, bW, bH);
            }
        }

        // Render arrow + value as a single right-justified string so there
        // is no chance of the trend glyph overlapping the value text.
        var arrow = "";
        var aC = 0x888888;
        if (trend > 0) { arrow = "^"; aC = _cHLD; }
        else if (trend < 0) { arrow = "v"; aC = 0xFF5533; }
        // Draw combined string: trend color for arrow prefix, value color for rest.
        // Simplest legible approach on small FONT_XTINY: single color, arrow+space+value.
        var combined = arrow + valTxt;
        var textC = (trend != 0) ? aC : valC;
        dc.setColor(textC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(valX, y - 6, Graphics.FONT_XTINY, combined, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Compact physio row (0..100 scale)
    hidden function _drPhysioRow(dc, y, lbl, val, trend, hist) {
        _drTrendRow(dc, y, lbl, val, val.toString(), _physioColor(val), trend, hist, 100, 0);
    }

    // Apnea row — PB-scaled, value rendered as M:SS
    hidden function _drApRow(dc, y, lbl, val, trend, hist) {
        var pb = (_apPB > 0) ? _apPB : 100;
        var pct = (_apPB > 0) ? (val * 100 / _apPB) : 0;
        var c;
        if (pct >= 80)      { c = _cHLD; }
        else if (pct >= 60) { c = 0xFFA060; }
        else                { c = (val > 0) ? 0xFF5533 : 0x888888; }
        _drTrendRow(dc, y, lbl, val, _fmt(val), c, trend, hist, pb, 1);
    }

    // Trend over a 5-entry history (newest at idx 0). Returns -1/0/+1.
    hidden function _hist5Trend(hist) {
        var a = 0; var b = 0; var ac = 0; var bc = 0;
        for (var i = 0; i < 2; i++) { if (hist[i] > 0) { a += hist[i]; ac++; } }
        for (var j = 2; j < 5; j++) { if (hist[j] > 0) { b += hist[j]; bc++; } }
        if (ac == 0 || bc == 0) { return 0; }
        var av = a / ac; var bv = b / bc;
        if (av > bv + 2) { return 1; }
        if (av < bv - 2) { return -1; }
        return 0;
    }

    // Legacy — kept for any external callers; routes to new row renderer with empty hist
    hidden function _drSysRow(dc, lx, rx, y, lbl, val, trend) {
        var empty = [0, 0, 0, 0, 0];
        _drPhysioRow(dc, y, lbl, val, trend, empty);
    }

    // ── WEEKLY STATS PAGE ────────────────────────────────────────────
    // Layout: 8-week bar chart + 14-day activity dot strip + descriptive
    // insights (this week, vs last, best week ever, 7d consistency).
    hidden function _drStatWeekly(dc) {
        var cx = _w / 2;

        // Render-time advance: keep buckets aligned to "today" even if the
        // user hasn't completed a session this week. Cheap (no I/O unless
        // a rollover actually happens) — but only persist when something
        // changed to avoid touching flash on every redraw.
        var today = _curEpochDay();
        var prevBase = _wkBaseDay;
        var prevRef  = _dayBitsRef;
        // Check for cold-start BEFORE _advanceWeeks — that function sets
        // _wkBaseDay = today when it is 0, which would mask the reset state.
        var totalEver = _wkSesTotal();
        var coldStart = (totalEver == 0 && _wkBaseDay == 0);
        _advanceWeeks(today);
        _advanceDayBits(today);
        if (_wkBaseDay != prevBase || _dayBitsRef != prevRef) { _persistWeekly(); }

        if (coldStart) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 38 / 100, Graphics.FONT_XTINY, "No sessions yet", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(_lighten(_cINH, -30), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 50 / 100, Graphics.FONT_XTINY, "Train to build", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, _h * 58 / 100, Graphics.FONT_XTINY, "your weekly chart", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // ── 8-week bar chart ───────────────────────────────────────────
        // Bars: oldest left (idx 7), newest right (idx 0). Label "8w  …  now".
        var chW = _w * 70 / 100;
        var chH = _h * 22 / 100;
        var chX = (_w - chW) / 2;
        var chY = _h * 27 / 100;
        var sp  = 2;
        var bW  = (chW - sp * 7) / 8;
        if (bW < 4) { bW = 4; }

        // Y-axis baseline
        dc.setColor(_lighten(_cINH, -78), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(chX, chY + chH, chX + chW, chY + chH);

        var maxV = _wkSesMax();
        if (maxV < 3) { maxV = 3; }   // ensure short bars don't fill the chart

        for (var i = 0; i < 8; i++) {
            var v = _wkSes[7 - i];
            var bx = chX + i * (bW + sp);
            var clr;
            if (i == 7) {
                // current week — color by trend vs prev week
                var prev = _wkSes[1];
                if (v > prev)      { clr = _cHLD; }       // up
                else if (v < prev) { clr = 0xFFA060; }     // down
                else               { clr = _lighten(_cINH, 5); }
            } else {
                clr = _lighten(_cINH, -45 - i * 3);   // older = dimmer
            }
            if (v <= 0) {
                dc.setColor(_lighten(_cINH, -82), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, chY + chH - 2, bW, 2);
            } else {
                var bH = v * chH / maxV;
                if (bH < 3)   { bH = 3; }
                if (bH > chH) { bH = chH; }
                dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, chY + chH - bH, bW, bH);
            }
        }

        // Axis labels: "8w" left, "now" right, max value above the rightmost bar
        dc.setColor(_lighten(_cINH, -55), Graphics.COLOR_TRANSPARENT);
        dc.drawText(chX, chY + chH + 1, Graphics.FONT_XTINY, "8w", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(chX + chW, chY + chH + 1, Graphics.FONT_XTINY, "now", Graphics.TEXT_JUSTIFY_RIGHT);

        // ── This-week summary line ─────────────────────────────────────
        var ses0 = _wkSes[0];
        var min0 = _wkHold[0] / 60;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 56 / 100, Graphics.FONT_XTINY,
            ses0 + " ses  " + min0 + "m hold", Graphics.TEXT_JUSTIFY_CENTER);

        // Δ vs last week (only when both populated)
        var delta = "";
        var deltaC = 0x888888;
        if (_wkSes[1] > 0) {
            var d = ses0 - _wkSes[1];
            var pct = d * 100 / _wkSes[1];
            if (d > 0)      { delta = "+" + pct + "% vs last wk"; deltaC = _cHLD; }
            else if (d < 0) { delta = pct + "% vs last wk";       deltaC = 0xFFA060; }
            else            { delta = "= last wk";                deltaC = 0x888888; }
        } else if (ses0 > 0 && _wkBaseDay > 0) {
            delta = "first week";
        }
        if (delta.length() > 0) {
            dc.setColor(deltaC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 64 / 100, Graphics.FONT_XTINY, delta, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── 14-day activity dot strip ──────────────────────────────────
        // 14 dots, oldest left, today right. Filled = active, hollow = idle.
        // Newest dot pulses subtly so users can find "today" at a glance.
        var dotR = 2;
        var dotG = 5;
        var stripW = 14 * dotR * 2 + 13 * dotG;
        if (stripW > _w * 90 / 100) { dotG = 4; stripW = 14 * dotR * 2 + 13 * dotG; }
        var dx0 = cx - stripW / 2 + dotR;
        var dyS = _h * 73 / 100;
        for (var k = 0; k < 14; k++) {
            var bit = (_dayBits >> (13 - k)) & 1;     // oldest left
            var isToday = (k == 13);
            var dx = dx0 + k * (dotR * 2 + dotG);
            if (bit == 1) {
                var c = _lighten(_cINH, -10);
                if (isToday) {
                    var pulseHi = (_tick % 12 < 6);
                    c = pulseHi ? _cINH : _lighten(_cINH, 25);
                }
                dc.setColor(c, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dx, dyS, dotR + (isToday ? 1 : 0));
            } else {
                dc.setColor(_lighten(_cINH, -75), Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(dx, dyS, dotR);
            }
        }

        // ── Footer: best week + 7d consistency ────────────────────────
        // Pulled up from y=83/90 → y=80/87 so both lines stay inside the
        // round-watch safe zone (the previous y=90 line was getting
        // clipped by the bezel on user devices).
        var d7 = _activeDays(7);
        dc.setColor(_lighten(_cINH, -25), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 80 / 100, Graphics.FONT_XTINY,
            "Best " + _wkBestSes + "/wk", Graphics.TEXT_JUSTIFY_CENTER);
        var d7C = (d7 >= 5) ? _cHLD : ((d7 >= 3) ? _lighten(_cINH, -10) : 0xFFA060);
        dc.setColor(d7C, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 87 / 100, Graphics.FONT_XTINY,
            d7 + "/7 days", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── SENSOR TRENDS PAGE ───────────────────────────────────────────────
    // Strict vertical separation rule: text windows and graphic windows
    // never overlap in Y.  Each element is assigned an exclusive Y slot.
    //
    //  y=24%  Section A header "DIVE REFLEX" (text, ~6% tall)
    //  y=32%  Sparkline bars bottom             (graphic, 8% above = tops at 24%)
    //  y=42%  "PB -X bpm   Last -Y" line        (text, gap below bars)
    //
    //  y=50%  Section B "CALM   XX/100"          (text)
    //  y=57%  AVG bar (4% tall)
    //  y=62%  LAST bar (4% tall)
    //  y=68%  Verdict label                      (text)
    //
    //  y=74%  Section C "READINESS   RHR X O2 Y" (text)
    //  y=82%  Dots row (centered)                (graphic)
    hidden function _drStatSensor(dc) {
        var cx = _w / 2;
        var noData = (_snBradBest <= 0 && _snCalmAvg <= 0 && _snBbAtStart[4] < 0);
        if (noData) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 38 / 100, Graphics.FONT_XTINY, "No sensor data yet", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(_lighten(_cINH, -30), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 50 / 100, Graphics.FONT_XTINY, "Train with Sensors ON", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, _h * 59 / 100, Graphics.FONT_XTINY, "to build your trends", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Pixel-based layout — ALL positions derived from actual font height so
        // nothing ever overlaps regardless of screen size (200–390px range).
        var fH  = dc.getFontHeight(Graphics.FONT_XTINY);
        var gap = 4;                         // guaranteed clear pixels between elements
        var sparkBarH = 8;                   // sparkline bar height in px
        var calmBarH  = 4;                   // calm-index bar height in px
        var dotR      = 3;                   // readiness dot radius in px
        var secGap    = _h * 4 / 100;        // visual gap between sections (scales with screen)
        var barBX     = _w * 12 / 100;
        var barBW     = _w * 76 / 100;

        // ─────── SECTION A: DIVE REFLEX ────────────────────────────────────
        var aHeaderY = _h * 21 / 100;
        dc.setColor(0xAA88FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, aHeaderY, Graphics.FONT_XTINY, "DIVE REFLEX", Graphics.TEXT_JUSTIFY_CENTER);

        // Bars — top starts at aHeaderY + fH + gap, bottom at +sparkBarH
        var aBarsBot = aHeaderY + fH + gap + sparkBarH;
        var barW  = _w * 5 / 100; if (barW < 6) { barW = 6; }
        var barGap = 3;
        var totalBW = 5 * barW + 4 * barGap;
        var barsX0  = cx - totalBW / 2;
        var sparkMax = 0;
        for (var i = 0; i < 5; i++) { if (_snBradHist[i] > sparkMax) { sparkMax = _snBradHist[i]; } }
        if (sparkMax < 5) { sparkMax = 5; }
        for (var i = 0; i < 5; i++) {
            var v = _snBradHist[i];
            var bh = (v > 0) ? (v * sparkBarH / sparkMax) : 1;
            var bx = barsX0 + i * (barW + barGap);
            var bC = (v >= 15) ? _cHLD : ((v >= 8) ? _lighten(_cHLD, -40) : 0x444444);
            dc.setColor(bC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, aBarsBot - bh, barW, bh);
        }

        // PB / Last line — gap pixels below bars bottom
        var aBradY = aBarsBot + gap;
        var bradLine = "";
        if (_snBradBest > 0) { bradLine = "PB -" + _snBradBest + " bpm"; }
        if (_snBradLast > 0) {
            if (bradLine.length() > 0) { bradLine = bradLine + "   "; }
            bradLine = bradLine + "Last -" + _snBradLast;
        }
        if (bradLine.length() > 0) {
            dc.setColor(_lighten(_cINH, -20), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, aBradY, Graphics.FONT_XTINY, bradLine, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ─────── SECTION B: CALM INDEX ─────────────────────────────────────
        // Header: fH below the PB line + section gap
        var bHeaderY = aBradY + fH + secGap;
        dc.setColor(0x66CCAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 12 / 100, bHeaderY, Graphics.FONT_XTINY, "CALM", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 88 / 100, bHeaderY, Graphics.FONT_XTINY,
            _snCalmAvg.toString() + "/100", Graphics.TEXT_JUSTIFY_RIGHT);

        // AVG bar: fH + gap below header
        var bAvgBarY  = bHeaderY + fH + gap;
        dc.setColor(_lighten(0x66CCAA, -72), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barBX, bAvgBarY, barBW, calmBarH);
        if (_snCalmAvg > 0) {
            dc.setColor(_lighten(0x66CCAA, -35), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barBX, bAvgBarY, _snCalmAvg * barBW / 100, calmBarH);
        }

        // LAST bar: gap below AVG bar
        var bLastBarY = bAvgBarY + calmBarH + gap;
        dc.setColor(_lighten(0x66CCAA, -72), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barBX, bLastBarY, barBW, calmBarH);
        if (_snCalmLast > 0) {
            var lC = (_snCalmLast > _snCalmAvg) ? 0x66CCAA
                   : ((_snCalmLast >= _snCalmAvg - 10) ? _lighten(0x66CCAA, -20) : 0xFFA060);
            dc.setColor(lC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barBX, bLastBarY, _snCalmLast * barBW / 100, calmBarH);
        }

        // Verdict: gap below LAST bar
        var bVerdictY = bLastBarY + calmBarH + gap;
        if (_snCalmAvg > 0) {
            var lbl = (_snCalmAvg >= 70) ? "Excellent calm"
                    : (_snCalmAvg >= 45) ? "Good progress"
                    : (_snCalmAvg >= 20) ? "Building"
                    : "Keep practicing";
            var lC2 = (_snCalmLast > _snCalmAvg) ? _cHLD : _lighten(_cINH, -30);
            dc.setColor(lC2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, bVerdictY, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ─────── SECTION C: READINESS ──────────────────────────────────────
        // Header: fH below verdict + section gap
        var cHeaderY = bVerdictY + fH + secGap;
        dc.setColor(0x66DD88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 12 / 100, cHeaderY, Graphics.FONT_XTINY, "READINESS", Graphics.TEXT_JUSTIFY_LEFT);
        var snap = "";
        if (_snRestHr > 0) { snap = "RHR " + _snRestHr; }
        if (_snSpo2 > 0) {
            if (snap.length() > 0) { snap = snap + "  "; }
            snap = snap + "O2 " + _snSpo2 + "%";
        }
        if (snap.length() > 0) {
            dc.setColor(_lighten(_cINH, -30), Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w * 88 / 100, cHeaderY, Graphics.FONT_XTINY, snap, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Dots: dot center at fH + gap below header top, plus dotR offset
        var cDotsY = cHeaderY + fH + gap + dotR;
        var dotStep = dotR * 2 + 6;
        var dotsW   = 5 * dotStep - 6;
        var dotX0   = cx - dotsW / 2 + dotR;
        for (var i = 0; i < 5; i++) {
            var bb  = _snBbAtStart[i];
            var ddx = dotX0 + i * dotStep;
            if (bb >= 0) {
                var dC = (bb >= 60) ? 0x66DD88 : ((bb >= 30) ? 0xCCAA44 : 0xFFA060);
                dc.setColor(dC, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ddx, cDotsY, dotR);
            } else {
                dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(ddx, cDotsY, dotR);
            }
        }
    }

    hidden function _drStat(dc) {
        var cx = _w / 2;
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 4 / 100, Graphics.FONT_XTINY, _nmStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        var title;
        if      (_stPg == 0) { title = "TRAINING STATS"; }
        else if (_stPg == 1) { title = "PROGRESSION"; }
        else if (_stPg == 2) { title = "PHYSIOLOGY"; }
        else if (_stPg == 3) { title = "WEEKLY"; }
        else                 { title = "SENSOR TRENDS"; }
        dc.drawText(cx, _h * 13 / 100, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);

        // Page indicator: 5 tiny dots tucked just under the title
        var dotY = _h * 21 / 100;
        var dotXs = [cx - 16, cx - 8, cx, cx + 8, cx + 16];
        dc.setColor(_lighten(_cINH, -75), Graphics.COLOR_TRANSPARENT);
        for (var di = 0; di < 5; di++) {
            dc.fillCircle(dotXs[di], dotY, 1);
        }
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotXs[_stPg], dotY, 2);

        // Cold-start gate: zero training history → no real scores to show.
        // Match WEEKLY's "No sessions yet" pattern instead of rendering
        // misleading empty bars or default-zero scores on PROGRESSION /
        // PHYSIOLOGY pages.
        var totalSesAll = _stBrC + _stApC + _stCoC + _stO2C;
        if ((_stPg == 1 || _stPg == 2) && totalSesAll == 0) {
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 38 / 100, Graphics.FONT_XTINY, "No sessions yet", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(_lighten(_cINH, -30), Graphics.COLOR_TRANSPARENT);
            var line = (_stPg == 1) ? "Train to build" : "Physiology data";
            var line2 = (_stPg == 1) ? "your trends" : "appears here";
            dc.drawText(cx, _h * 50 / 100, Graphics.FONT_XTINY, line, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, _h * 58 / 100, Graphics.FONT_XTINY, line2, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        if (_stPg == 4) {
            _drStatSensor(dc);
        } else if (_stPg == 3) {
            _drStatWeekly(dc);
        } else if (_stPg == 2) {
            // ── PHYSIOLOGY ─────────────────────────────────────────────────
            // 3 metric rows with 12% gap (was 14%) so the footer lands well
            // within the round-watch safe zone.
            // Sensor strip removed — all sensor data lives on SENSOR TRENDS (page 5).
            var ry = _h * 28 / 100;
            var rowGap = _h * 12 / 100;

            _drPhysioRow(dc, ry, "CO2",  _coTolScore,    _coTrend,      _coVHist);
            ry += rowGap;
            _drPhysioRow(dc, ry, "O2",   _o2AdaptScore,  _o2Trend,      _o2VHist);
            ry += rowGap;
            _drPhysioRow(dc, ry, "REC",  _brRecScore,    _brEffectLast, _brVHist);

            // Diver class label
            dc.setColor(_lighten(_cINH, 8), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 63 / 100, Graphics.FONT_XTINY, _diverClass(), Graphics.TEXT_JUSTIFY_CENTER);

            // Pattern flag / PB prediction — at 73% (safe zone on all round watches)
            var flagTxt = "";
            var flagC = _cHLD;
            if      (_ptOvertrainFlag) { flagTxt = "OVERTRAIN";       flagC = 0xFF5533; }
            else if (_ptDeclineFlag)   { flagTxt = "DECLINE";         flagC = 0xFFA060; }
            else if (_ptPlateauFlag)   { flagTxt = "PLATEAU";         flagC = 0x888888; }
            else if (_pbPredicted > 0 && _apPB > 0) {
                var dlt = _pbPredicted - _apPB;
                var sign = (dlt >= 0) ? "+" : "";
                flagTxt = "PB " + _fmt(_pbPredicted) + " " + sign + dlt + "s";
                flagC = (_pbConfidence >= 60) ? _cHLD
                      : ((_pbConfidence >= 35) ? 0xFFA060 : 0x888888);
            }
            if (flagTxt.length() > 0) {
                dc.setColor(flagC, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, _h * 73 / 100, Graphics.FONT_XTINY, flagTxt, Graphics.TEXT_JUSTIFY_CENTER);
            }

            // Compact sensor snapshot on one safe line (y=82%) — only RHR and SpO2
            // (the full sensor history is on SENSOR TRENDS, page 5).
            if (_snAnyAvail()) {
                var snap = "";
                if ((_snAvail & 0x10) != 0 && _snRestHr > 0) { snap = "RHR " + _snRestHr; }
                if ((_snAvail & 0x08) != 0 && _snSpo2 >= 0) {
                    if (snap.length() > 0) { snap = snap + "  "; }
                    snap = snap + "SpO2 " + _snSpo2 + "%";
                }
                if (snap.length() > 0) {
                    dc.setColor(_lighten(_cINH, -45), Graphics.COLOR_TRANSPARENT);
                    dc.drawText(cx, _h * 82 / 100, Graphics.FONT_XTINY, snap, Graphics.TEXT_JUSTIFY_CENTER);
                }
            }
        } else if (_stPg == 0) {
            // ── TRAINING STATS — clean three-zone layout ──────────────────
            // Zone 1 (top): big "X sessions  Yh Zm" hero block
            // Zone 2 (mid): per-mode counts (BR/AP, CO2/O2)
            // Zone 3 (bot): PB highlight + streak/hold totals
            var totalS = _stBrC + _stApC + _stCoC + _stO2C;
            var totMin = _stTotT / 60;
            var totH   = totMin / 60;
            var totMm  = totMin - totH * 60;
            var hms    = (totH > 0) ? (totH + "h " + totMm + "m") : (totMm + "m");

            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 28 / 100, Graphics.FONT_SMALL, totalS.toString(), Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 41 / 100, Graphics.FONT_XTINY, "sessions", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(_lighten(_cINH, -10), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 49 / 100, Graphics.FONT_XTINY, hms + " total", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 60 / 100, Graphics.FONT_XTINY,
                "BR " + _stBrC + "    AP " + _stApC, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, _h * 68 / 100, Graphics.FONT_XTINY,
                "CO2 " + _stCoC + "    O2 " + _stO2C, Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(_cHLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 78 / 100, Graphics.FONT_XTINY, "PB " + _fmt(_apPB), Graphics.TEXT_JUSTIFY_CENTER);

            // This week mini-summary (auto-rolls bucket alignment first).
            // Moved from y=89 → y=86 so the round-watch bezel doesn't
            // clip the descenders on small-screen devices.
            var today0 = _curEpochDay();
            _advanceWeeks(today0); _advanceDayBits(today0);
            dc.setColor(_lighten(_cINH, -25), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 86 / 100, Graphics.FONT_XTINY,
                "Wk " + _wkSes[0] + " ses  " + _activeDays(7) + "/7d",
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // ── PROGRESSION — 4 mini-trend rows, all metrics at a glance ──
            // APNEA (PB-scaled) + CO2 / O2 / BREATHE (0..100 physio scale)
            var ry = _h * 30 / 100;
            var rowGap = _h * 14 / 100;

            _drApRow(dc, ry, "APNEA", _apHist[0], _apTrend(), _apHist);
            ry += rowGap;
            _drPhysioRow(dc, ry, "CO2",
                (_coTolScore > 0) ? _coTolScore : _coVHist[0],
                _hist5Trend(_coVHist), _coVHist);
            ry += rowGap;
            _drPhysioRow(dc, ry, "O2",
                (_o2AdaptScore > 0) ? _o2AdaptScore : _o2VHist[0],
                _hist5Trend(_o2VHist), _o2VHist);
            ry += rowGap;
            _drPhysioRow(dc, ry, "BR",
                (_brRecScore > 0) ? _brRecScore : _brVHist[0],
                _hist5Trend(_brVHist), _brVHist);

            // Footer: streak + 7d consistency + lifetime hold minutes.
            // Moved up to y=86 to clear the bezel.
            var today2 = _curEpochDay();
            _advanceDayBits(today2);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 86 / 100, Graphics.FONT_XTINY,
                _stStreak + "d  " + _activeDays(7) + "/7  " + (_stHoldT / 60) + "m",
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drCust(dc) {
        var cx = _w / 2;
        var fntH = dc.getFontHeight(Graphics.FONT_XTINY);
        var itemH = fntH + 4;
        var dotsH = 12;

        var totalH = itemH * _custRows() + dotsH;
        var startY = (_h - totalH) / 2;

        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, startY - fntH - 4, Graphics.FONT_XTINY, "CUSTOMIZE", Graphics.TEXT_JUSTIFY_CENTER);

        _cstRowY0 = startY;
        dc.setColor((_cF == 0) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, startY + 2, Graphics.FONT_XTINY, "Theme  " + _thName(), Graphics.TEXT_JUSTIFY_CENTER);

        var dotsY = startY + itemH + dotsH / 2;
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 28, dotsY, 3);
        dc.setColor(_cHI,  Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 14, dotsY, 3);
        dc.setColor(_cEXH, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx,      dotsY, 3);
        dc.setColor(_cHE,  Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 14, dotsY, 3);
        dc.setColor(_cPRP, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 28, dotsY, 3);

        var y1 = startY + itemH + dotsH;
        _cstRowY1 = y1;
        dc.setColor((_cF == 1) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y1 + 2, Graphics.FONT_XTINY, "Name  " + _nmStr, Graphics.TEXT_JUSTIFY_CENTER);

        var y2 = y1 + itemH;
        _cstRowY2 = y2;
        dc.setColor((_cF == 2) ? _cINH : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y2 + 2, Graphics.FONT_XTINY, "Vibration  " + (_vibOn ? "ON" : "OFF"), Graphics.TEXT_JUSTIFY_CENTER);

        var y3 = y2 + itemH;
        _cstRowY3 = y3;
        // Sensors row — shows ON/OFF + tiny availability hint when ON
        var snLbl = "Sensors  " + (_snOn ? "ON" : "OFF");
        if (_snOn && _snAvail == 0) { snLbl = "Sensors  N/A"; }
        dc.setColor((_cF == 3) ? _cINH : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y3 + 2, Graphics.FONT_XTINY, snLbl, Graphics.TEXT_JUSTIFY_CENTER);

        var y4 = y3 + itemH;
        if (DBG_ENABLED) {
            dc.setColor((_cF == 4) ? 0xFF8833 : 0x442211, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y4 + 2, Graphics.FONT_XTINY, "Gen Test User", Graphics.TEXT_JUSTIFY_CENTER);
            var y5 = y4 + itemH;
            dc.setColor((_cF == 5) ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y5 + 2, Graphics.FONT_XTINY, "SAVE", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor((_cF == 4) ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y4 + 2, Graphics.FONT_XTINY, "SAVE", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drNameEd(dc) {
        var cx = _w / 2;
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 8 / 100, Graphics.FONT_XTINY, "EDIT NAME", Graphics.TEXT_JUSTIFY_CENTER);

        var nameDisp = "";
        for (var i = 0; i < 8; i++) {
            var ch = NM_CH.substring(_nmChrs[i], _nmChrs[i] + 1);
            if (_nmChrs[i] == 36) { ch = "_"; }
            if (i == _nmPos) { nameDisp = nameDisp + "[" + ch + "]"; }
            else { nameDisp = nameDisp + " " + ch + " "; }
        }
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 20 / 100, Graphics.FONT_XTINY, nameDisp, Graphics.TEXT_JUSTIFY_CENTER);

        var ci = _nmChrs[_nmPos];
        var cLen = NM_CH.length();
        var p2i = (ci + cLen - 2) % cLen; var p1i = (ci + cLen - 1) % cLen;
        var n1i = (ci + 1) % cLen; var n2i = (ci + 2) % cLen;

        var midY = _h * 46 / 100;
        var step = _h * 10 / 100;

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        var c2 = NM_CH.substring(p2i, p2i + 1); if (p2i == 36) { c2 = "_"; }
        dc.drawText(cx, midY - step * 2, Graphics.FONT_XTINY, c2, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        var c1 = NM_CH.substring(p1i, p1i + 1); if (p1i == 36) { c1 = "_"; }
        dc.drawText(cx, midY - step, Graphics.FONT_SMALL, c1, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var cc = NM_CH.substring(ci, ci + 1); if (ci == 36) { cc = "_"; }
        dc.drawText(cx, midY, Graphics.FONT_LARGE, cc, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        var cn1 = NM_CH.substring(n1i, n1i + 1); if (n1i == 36) { cn1 = "_"; }
        dc.drawText(cx, midY + step + 6, Graphics.FONT_SMALL, cn1, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        var cn2 = NM_CH.substring(n2i, n2i + 1); if (n2i == 36) { cn2 = "_"; }
        dc.drawText(cx, midY + step * 2 + 6, Graphics.FONT_XTINY, cn2, Graphics.TEXT_JUSTIFY_CENTER);

    }
}
