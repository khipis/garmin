using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.System;
using Toybox.Application;

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
const FT_SAFE = 10;
const FT_RST  = 11;
const FT_PRO  = 12;

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

const BR_PAT = [[2, 0, 4, 0], [3, 0, 6, 0], [4, 4, 4, 4]];
const BR_LBL = ["Recovery 2-4", "Breathe-Up 3-6", "Box 4-4-4-4"];
const BR_INH = [2, 3, 4, 5, 6, 7, 8];
const BR_HLD = [0, 1, 2, 3, 4];
const BR_EXH = [3, 4, 5, 6, 7, 8, 10];
const BR_SES = [5, 10, 15, 20, 30];

const TBL_MX = [60, 90, 120, 150, 180, 210, 240, 300];
const TBL_RN = [6, 7, 8, 9, 10];
const NM_CH = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ";

class BreathTrainingView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick; hidden var _sub;
    hidden var _gs; hidden var _mode;

    hidden var _hSel; hidden var _mSel; hidden var _lastMode;

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
    hidden var _stBrC; hidden var _stBrT; hidden var _stApC;
    hidden var _stCoC; hidden var _stO2C; hidden var _stTotT;
    hidden var _exEarly;

    function initialize() {
        View.initialize();
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _tick = 0; _sub = 0;
        _gs = FT_HOME; _hSel = 0; _mSel = 0;
        _exEarly = false;

        var sfa = Application.Storage.getValue("usr_safe_ack");
        if (!(sfa instanceof Toybox.Lang.Boolean) || !sfa) { _gs = FT_SAFE; }

        var lm = Application.Storage.getValue("lst_md");
        _lastMode = (lm instanceof Number && lm >= 0 && lm <= 3) ? lm : FM_CO;
        _loadPresets();

        _brM = _svBrM; _brF = 0;
        _brII = _svBrII; _brHI = _svBrHI; _brEI = _svBrEI; _brXI = _svBrXI; _brSI = _svBrSI;
        _brPat = [4, 0, 6, 0];
        _brPh = BP_INH; _brPD = 4; _brPE = 0; _brPS = 0;
        _brRem = 0; _brSS = 0; _brBC = 0; _brTrans = 0;

        _tMxI = _svCoMx; _tRnI = _svCoRn; _tF = 0;
        _tRnd = 0; _tTR = 8;
        _tPh = BP_PRP; _tPS = 0; _tPE = 0; _tPSub = 0;
        _tH = new [10]; _tR = new [10];

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
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); _timer.start(method(:onTick), 100, true); }
    }

    function onHide() {}

    function onTick() as Void {
        _sub++;
        if (_gs == FT_ACT) {
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
                        // Natural pause between phases — session time still counts
                        _brTrans--; _brRem--;
                        if (_brRem <= 0) { _saveSt(FM_BR, _brSS); _vibeDone(); _gs = FT_DONE; WatchUi.requestUpdate(); return; }
                        if (_brTrans == 0) { _nxBrPh(); }
                    } else {
                        if (_brPE < _brPD) {
                            _brPE++; _brRem--;
                            if (_brRem <= 0) { _saveSt(FM_BR, _brSS); _vibeDone(); _gs = FT_DONE; WatchUi.requestUpdate(); return; }
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
                var td = 0; for (var ti = 0; ti < _tTR; ti++) { td += _tH[ti] + _tR[ti]; }
                _saveSt(_mode, td); _vibeDone(); _gs = FT_DONE;
            } else {
                _tPh = BP_RST; _tPS = _tR[_tRnd]; _tPE = 0; _tPSub = 0;
                _vibe(60, 140);
            }
        }
    }

    hidden function _genCO2(maxH, rounds) {
        var hold = maxH * 55 / 100; if (hold < 15) { hold = 15; }
        var rStart = hold * 2; if (rStart > 120) { rStart = 120; }
        var rEnd = 30;
        for (var i = 0; i < rounds; i++) {
            _tH[i] = hold;
            var rest = rStart - (rStart - rEnd) * i / (rounds - 1);
            if (rest < rEnd) { rest = rEnd; }
            _tR[i] = rest;
        }
    }

    hidden function _genO2(maxH, rounds) {
        var rest = 120;
        var hStart = maxH * 50 / 100; if (hStart < 15) { hStart = 15; }
        var hEnd = maxH * 85 / 100;
        for (var i = 0; i < rounds; i++) {
            _tR[i] = rest;
            var hold = hStart + (hEnd - hStart) * i / (rounds - 1);
            _tH[i] = hold;
        }
    }

    hidden function _chkApV(s) {
        if (s > 0 && s % 60 == 0) { _vibe(80, 280); }
        else if (s > 0 && s % 30 == 0) { _vibe(50, 110); }
        if (!_apWF && s >= _apWS) { _apWF = true; _vibeDouble(90, 150, 100); }
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
        if (_gs == FT_HOME) { _hSel = (_hSel + 5) % 6; }
        else if (_gs == FT_MORE) { _mSel = (_mSel + 6) % 7; }
        else if (_gs == FT_BCFG) { _adjBrF(-1); }
        else if (_gs == FT_TCFG) { _adjTF(-1); }
        else if (_gs == FT_CUST) { _cF = (_cF + 3) % 4; }
        else if (_gs == FT_NAME) { _adjNmCh(-1); }
    }

    function doDown() {
        if (_gs == FT_HOME) { _hSel = (_hSel + 1) % 6; }
        else if (_gs == FT_MORE) { _mSel = (_mSel + 1) % 7; }
        else if (_gs == FT_BCFG) { _adjBrF(1); }
        else if (_gs == FT_TCFG) { _adjTF(1); }
        else if (_gs == FT_CUST) { _cF = (_cF + 1) % 4; }
        else if (_gs == FT_NAME) { _adjNmCh(1); }
    }

    function doSelect() {
        if (_gs == FT_SAFE) {
            Application.Storage.setValue("usr_safe_ack", true);
            _gs = FT_HOME; _hSel = 0; return;
        }
        if (_gs == FT_HOME) {
            if (_hSel == 0) { _instantStart(_lastMode); }
            else if (_hSel == 1) { _quickBreathe(); }
            else if (_hSel == 2) { _instantStart(FM_CO); }
            else if (_hSel == 3) { _instantStart(FM_O2); }
            else if (_hSel == 4) { _instantStart(FM_AP); }
            else { _mSel = 0; _gs = FT_MORE; }
        } else if (_gs == FT_MORE) {
            if (_mSel == 0) {
                _mode = FM_BR; _brM = _svBrM; _brII = _svBrII; _brHI = _svBrHI;
                _brEI = _svBrEI; _brXI = _svBrXI; _brSI = _svBrSI;
                _brF = 0; _gs = FT_BCFG;
            } else if (_mSel == 1) {
                _mode = FM_CO; _tMxI = _svCoMx; _tRnI = _svCoRn; _tF = 0; _gs = FT_TCFG;
            } else if (_mSel == 2) {
                _mode = FM_O2; _tMxI = _svO2Mx; _tRnI = _svO2Rn; _tF = 0; _gs = FT_TCFG;
            } else if (_mSel == 3) { _gs = FT_STAT; }
            else if (_mSel == 4) { _cF = 0; _gs = FT_CUST; }
            else if (_mSel == 5) { _gs = FT_PRO; }
            else { _gs = FT_RST; }
        } else if (_gs == FT_RST) {
            _resetAll();
        } else if (_gs == FT_PRO) {
            _mSel = 5; _gs = FT_MORE;
        } else if (_gs == FT_BCFG) {
            var mx = _brFldCnt();
            if (_brF < mx - 1) { _brF++; }
            else { _startBr(true); }
        } else if (_gs == FT_TCFG) {
            if (_tF < 2) { _tF++; }
            else { _startTbl(); }
        } else if (_gs == FT_ACT) {
            if (_mode == FM_AP) { _stopAp(); }
            else { _gs = FT_PAU; }
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

    hidden function _actCustRow() {
        if (_cF == 0) { _thIdx = (_thIdx + 1) % 5; _applyTheme(); }
        else if (_cF == 1) { _nmPos = 0; _gs = FT_NAME; }
        else if (_cF == 2) { _vibOn = !_vibOn; if (_vibOn) { _vibe(60, 120); } }
        else { _saveCustom(); _gs = FT_HOME; }
    }

    function doBack() {
        if (_gs == FT_SAFE) {
            Application.Storage.setValue("usr_safe_ack", true);
            _gs = FT_HOME; _hSel = 0; return true;
        }
        if (_gs == FT_HOME) { return false; }
        if (_gs == FT_MORE) { _gs = FT_HOME; return true; }
        if (_gs == FT_BCFG) { if (_brF > 0) { _brF--; return true; } _gs = FT_HOME; return true; }
        if (_gs == FT_TCFG) { if (_tF > 0) { _tF--; return true; } _gs = FT_HOME; return true; }
        if (_gs == FT_ACT || _gs == FT_PAU) {
            if (_mode == FM_CO || _mode == FM_O2) { _exEarly = true; }
            _hSel = 0; _gs = FT_HOME; return true;
        }
        if (_gs == FT_DONE || _gs == FT_STAT) { _hSel = 0; _gs = FT_HOME; return true; }
        if (_gs == FT_RST) { _mSel = 6; _gs = FT_MORE; return true; }
        if (_gs == FT_PRO) { _mSel = 5; _gs = FT_MORE; return true; }
        if (_gs == FT_CUST) { _gs = FT_HOME; return true; }
        if (_gs == FT_NAME) {
            if (_nmPos > 0) { _nmPos--; return true; }
            _nmStr = _bldNm(); _gs = FT_CUST; return true;
        }
        return false;
    }

    function doTap(x, y) {
        if (_gs == FT_HOME) {
            if (y < _h * 58 / 100) {
                doSelect();
            } else if (y < _h * 74 / 100) {
                if (x < _w / 4) { _hSel = 1; }
                else if (x < _w / 2) { _hSel = 2; }
                else if (x < _w * 3 / 4) { _hSel = 3; }
                else { _hSel = 4; }
                doSelect();
            } else { _hSel = 5; doSelect(); }
        } else if (_gs == FT_MORE) {
            var fntH = Graphics.getFontHeight(Graphics.FONT_XTINY);
            var itemH = fntH + 4;
            var totalH = itemH * 7;
            var startY = (_h - totalH) / 2;
            for (var i = 0; i < 7; i++) {
                var ry = startY + i * itemH;
                if (y >= ry && y < ry + itemH) { _mSel = i; doSelect(); return; }
            }
        } else if (_gs == FT_PRO) {
            doSelect();
        } else if (_gs == FT_CUST) {
            var r = 0;
            if (_cstRowY3 > 0) {
                var m01 = (_cstRowY0 + _cstRowY1) / 2;
                var m12 = (_cstRowY1 + _cstRowY2) / 2;
                var m23 = (_cstRowY2 + _cstRowY3) / 2;
                if (y < m01) { r = 0; }
                else if (y < m12) { r = 1; }
                else if (y < m23) { r = 2; }
                else { r = 3; }
            } else {
                if (y < _h * 44 / 100) { r = 0; }
                else if (y < _h * 60 / 100) { r = 1; }
                else if (y < _h * 76 / 100) { r = 2; }
                else { r = 3; }
            }
            _cF = r;
            _actCustRow();
        } else if (_gs == FT_BCFG || _gs == FT_TCFG || _gs == FT_NAME) {
            if (y < _h / 2) { doUp(); } else { doDown(); }
        } else { doSelect(); }
    }

    hidden function _instantStart(md) {
        _mode = md;
        if (md == FM_CO) {
            _tMxI = _svCoMx; _tRnI = _svCoRn;
            _startTbl();
        } else if (md == FM_O2) {
            _tMxI = _svO2Mx; _tRnI = _svO2Rn;
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
        _brM = 0; _brSI = 1;
        _startBr(false);
    }

    hidden function _startBr(save) {
        if (save) { _savePreset(); }
        if (_brM < 3) {
            var mp = BR_PAT[_brM];
            _brPat = [mp[0], mp[1], mp[2], mp[3]];
        } else {
            _brPat = [BR_INH[_brII], BR_HLD[_brHI], BR_EXH[_brEI], BR_HLD[_brXI]];
        }
        _brSS = BR_SES[_brSI] * 60; _brRem = _brSS; _brBC = 0;
        _brPh = BP_INH; _brPD = _brPat[BP_INH]; _brPE = 0; _brPS = 0; _brTrans = 0;
        _gs = FT_ACT; _vibe(80, 300);
    }

    hidden function _startAp() {
        _savePreset();
        _apE = 0; _apPS = -1; _apNP = false; _apWF = false;
        _gs = FT_ACT; _vibe(40, 70);
    }

    hidden function _stopAp() {
        var s = _apE / 5; _apLS = s;
        _vibe(100, 600);
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
        }
        _saveSt(FM_AP, s);
        _gs = FT_DONE;
    }

    hidden function _startTbl() {
        _savePreset();
        _exEarly = false;
        var maxH = TBL_MX[_tMxI];
        _tTR = TBL_RN[_tRnI];
        if (_mode == FM_CO) { _genCO2(maxH, _tTR); }
        else { _genO2(maxH, _tTR); }
        _tRnd = 0; _tPh = BP_PRP; _tPS = 3; _tPE = 0; _tPSub = 0;
        _gs = FT_ACT; _vibe(80, 300);
    }

    hidden function _brFldCnt() { return (_brM == 3) ? 7 : 3; }

    hidden function _adjBrF(dir) {
        var nm = 4;
        if (_brM < 3) {
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
        if (_brM < 3 && _brF > 2) { _brF = 1; }
    }

    hidden function _adjTF(dir) {
        if (_tF == 0) { _tMxI = (_tMxI + dir + TBL_MX.size()) % TBL_MX.size(); }
        else if (_tF == 1) { _tRnI = (_tRnI + dir + TBL_RN.size()) % TBL_RN.size(); }
    }

    hidden function _adjCust(dir) {
        if (_cF == 0) { _thIdx = (_thIdx + dir + 5 + 5) % 5; _applyTheme(); }
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
        _svBrM  = (v instanceof Number && v >= 0 && v <= 3) ? v : 0;
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
    }

    hidden function _savePreset() {
        _lastMode = _mode;
        Application.Storage.setValue("lst_md", _mode);
        if (_mode == FM_CO) {
            Application.Storage.setValue("sv_co_mx", _tMxI);
            Application.Storage.setValue("sv_co_rn", _tRnI);
            _svCoMx = _tMxI; _svCoRn = _tRnI;
        } else if (_mode == FM_O2) {
            Application.Storage.setValue("sv_o2_mx", _tMxI);
            Application.Storage.setValue("sv_o2_rn", _tRnI);
            _svO2Mx = _tMxI; _svO2Rn = _tRnI;
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
        } else {                  // Neon — electric, no yellow-white
            _cINH=0xFF00CC; _cHI=0x00FF88; _cEXH=0xCC00FF; _cHE=0xFF0088;
            _cPRP=0xFF66FF; _cRST=0x00CCFF; _cHLD=0x66FF66;
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
    }

    hidden function _saveSt(mode, dur) {
        _stTotT += dur; Application.Storage.setValue("st_tot", _stTotT);
        if (mode == FM_BR) {
            _stBrC++; _stBrT += dur;
            Application.Storage.setValue("st_brc", _stBrC);
            Application.Storage.setValue("st_brt", _stBrT);
        } else if (mode == FM_AP) {
            _stApC++; Application.Storage.setValue("st_apc", _stApC);
        } else if (mode == FM_CO) {
            _stCoC++; Application.Storage.setValue("st_coc", _stCoC);
        } else {
            _stO2C++; Application.Storage.setValue("st_o2c", _stO2C);
        }
    }

    hidden function _thName() {
        if (_thIdx == 0) { return "Ocean"; }
        if (_thIdx == 1) { return "Sunset"; }
        if (_thIdx == 2) { return "Forest"; }
        if (_thIdx == 3) { return "Arctic"; }
        return "Neon";
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
            var hold = TBL_MX[_svCoMx] * 55 / 100;
            return "Hold " + _fmt(hold) + "  " + TBL_RN[_svCoRn] + " rnd";
        }
        if (m == FM_O2) {
            var hS = TBL_MX[_svO2Mx] * 50 / 100;
            var hE = TBL_MX[_svO2Mx] * 85 / 100;
            return _fmt(hS) + "-" + _fmt(hE) + "  " + TBL_RN[_svO2Rn] + " rnd";
        }
        if (m == FM_AP) {
            if (_apPB > 0) { return "PB " + _fmt(_apPB); }
            return "Ready";
        }
        if (_svBrM < 3) { return BR_LBL[_svBrM] + "  " + BR_SES[_svBrSI] + "m"; }
        return BR_INH[_svBrII] + "-" + BR_HLD[_svBrHI] + "-" + BR_EXH[_svBrEI] + "-" + BR_HLD[_svBrXI] + "  " + BR_SES[_svBrSI] + "m";
    }

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        dc.setColor(0x000000, 0x000000); dc.clear();
        if (_gs == FT_SAFE) { _drSafe(dc); return; }
        if (_gs == FT_HOME) { _drHome(dc); }
        else if (_gs == FT_MORE) { _drMore(dc); }
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
        else if (_gs == FT_PRO) { _drProUpsell(dc); }
        else { _drDone(dc); }
    }

    hidden function _drProUpsell(dc) {
        var cx = _w / 2;
        var fntX = dc.getFontHeight(Graphics.FONT_XTINY);

        // Headline — PRO badge (gold)
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 22 / 100, Graphics.FONT_SMALL, "PRO", Graphics.TEXT_JUSTIFY_CENTER);

        // Slogan — single line, white
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 32 / 100, Graphics.FONT_XTINY, "Train smarter. Dive deeper.", Graphics.TEXT_JUSTIFY_CENTER);

        // 3 short bullets, centered (was 4 — last one overlapped CTA)
        var by = _h * 42 / 100;
        var dy = fntX;
        var bullets = [
            "Coach + adaptive plans",
            "Session recommendations",
            "Readiness + progression"
        ];
        for (var i = 0; i < 3; i++) {
            var ry = by + i * dy;
            dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry, Graphics.FONT_XTINY, bullets[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // CTA — pulsing gold pill (smaller and lower)
        var ctaY = _h * 67 / 100;
        var pulseOn = (_tick % 14 < 7);
        var ctaC = pulseOn ? 0xFFCC44 : 0xCC9933;
        var ctaW = _w * 52 / 100; var ctaH = fntX + 4;
        var ctaX = (_w - ctaW) / 2;
        dc.setColor(0x442200, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ctaX, ctaY, ctaW, ctaH, 5);
        dc.setColor(ctaC, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(ctaX, ctaY, ctaW, ctaH, 5);
        dc.drawText(cx, ctaY + 1, Graphics.FONT_XTINY, "Connect IQ Store", Graphics.TEXT_JUSTIFY_CENTER);

        // Subhead under CTA — app name highlighted in gold to mark it as a product name
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 76 / 100, Graphics.FONT_XTINY, "Breath Training System", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drHome(dc) {
        var cx = _w / 2;
        var pm = _homePreviewMode();
        var active = (_hSel <= 4);

        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 6 / 100, Graphics.FONT_XTINY, _nmStr, Graphics.TEXT_JUSTIFY_CENTER);

        if (active) {
            dc.setColor(0x335555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 16 / 100, Graphics.FONT_XTINY, "QUICK START", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(active ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 24 / 100, Graphics.FONT_SMALL, _homeTitle(pm), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(active ? 0x888888 : 0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 35 / 100, Graphics.FONT_XTINY, _homeInfoFor(_hSel, pm), Graphics.TEXT_JUSTIFY_CENTER);

        if (active) {
            var sC = (_tick % 6 < 4) ? _cINH : _lighten(_cINH, 25);
            dc.setColor(sC, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, _h * 46 / 100, Graphics.FONT_SMALL, "START", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x181818, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 15 / 100, _h * 58 / 100, _w * 85 / 100, _h * 58 / 100);

        var pY = _h * 64 / 100;
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

        dc.setColor((_hSel == 5) ? _cINH : 0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 78 / 100, Graphics.FONT_XTINY, "More...", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drMore(dc) {
        var cx = _w / 2;
        var labels = ["Breathe", "CO2 Table", "O2 Table", "Stats", "Customize", "Upgrade to Pro", "Reset"];
        var fntH = dc.getFontHeight(Graphics.FONT_XTINY);
        var itemH = fntH + 4;
        var totalH = itemH * 7;
        var startY = (_h - totalH) / 2;

        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, startY - fntH - 4, Graphics.FONT_XTINY, "MORE", Graphics.TEXT_JUSTIFY_CENTER);

        for (var i = 0; i < 7; i++) {
            var y = startY + i * itemH;
            if (i == 6) {
                dc.setColor((i == _mSel) ? 0xFF6644 : 0x553322, Graphics.COLOR_TRANSPARENT);
            } else if (i == 5) {
                dc.setColor((i == _mSel) ? 0xFFCC44 : 0x886622, Graphics.COLOR_TRANSPARENT);
            } else if (i < 3) {
                dc.setColor((i == _mSel) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor((i == _mSel) ? _cINH : 0x444444, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx, y + 2, Graphics.FONT_XTINY, labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drRst(dc) {
        var cx = _w / 2;
        dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 22 / 100, Graphics.FONT_XTINY, "FACTORY RESET", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 36 / 100, Graphics.FONT_SMALL, "Erase all data?", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 50 / 100, Graphics.FONT_XTINY, "Stats, PB, name, theme", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, _h * 58 / 100, Graphics.FONT_XTINY, "will be cleared", Graphics.TEXT_JUSTIFY_CENTER);
        var pC = (_tick % 10 < 5) ? 0xFF6644 : 0xCC4422;
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 72 / 100, Graphics.FONT_XTINY, "SELECT = YES", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 80 / 100, Graphics.FONT_XTINY, "BACK = cancel", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _resetAll() {
        Application.Storage.clearValues();
        _svCoMx = 2; _svCoRn = 2;
        _svO2Mx = 2; _svO2Rn = 2;
        _svBrM = 0; _svBrII = 2; _svBrHI = 0; _svBrEI = 2; _svBrXI = 0; _svBrSI = 1;
        _brM = _svBrM; _brII = _svBrII; _brHI = _svBrHI;
        _brEI = _svBrEI; _brXI = _svBrXI; _brSI = _svBrSI;
        _tMxI = _svCoMx; _tRnI = _svCoRn;
        _apPB = 0; _apLS = 0; _apNP = false;
        for (var i = 0; i < 3; i++) { _apLog[i] = 0; }
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
        _lastMode = FM_CO;
        _exEarly = false;
        _vibeDouble(80, 120, 80);
        _gs = FT_SAFE; _hSel = 0; _mSel = 0;
    }

    hidden function _drBrCfg(dc) {
        var cx = _w / 2;
        var isCust = (_brM == 3);
        var rows = isCust ? 7 : 3;
        var fH = dc.getFontHeight(Graphics.FONT_XTINY);
        var rowH = _h * 58 / 100 / rows;
        if (rowH > 34) { rowH = 34; }
        if (rowH < 16) { rowH = 16; }
        var sY = (_h - rows * rowH) / 2;

        dc.setColor(0x00BBEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 8 / 100, Graphics.FONT_XTINY, "BREATHING", Graphics.TEXT_JUSTIFY_CENTER);

        var cLabels = ["MODE", "INHALE", "HOLD", "EXHALE", "HOLD EX", "SESSION", "START"];

        for (var i = 0; i < rows; i++) {
            var y = sY + i * rowH;
            var sel = (i == _brF);
            var lbl = "";
            var val = "";
            if (!isCust) {
                if (i == 0) { lbl = "MODE"; val = (_brM < 3) ? BR_LBL[_brM] : "Custom"; }
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
                dc.setColor(sel ? 0x00DDAA : 0x444444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, ty, Graphics.FONT_XTINY, "START", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 80 / 100, Graphics.FONT_XTINY, "UP/DN adjust  SEL next", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drTblCfg(dc) {
        var cx = _w / 2;
        var tag = (_mode == FM_CO) ? "CO2 TABLE" : "O2 TABLE";
        dc.setColor(0x00BBEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 10 / 100, Graphics.FONT_XTINY, tag, Graphics.TEXT_JUSTIFY_CENTER);

        var fH = dc.getFontHeight(Graphics.FONT_XTINY);
        var rowH = 34; if (rowH > _h / 7) { rowH = _h / 7; }
        var sY = (_h - 3 * rowH) / 2 - _h * 3 / 100;

        var labels = ["MAX HOLD", "ROUNDS", "START"];
        var vals = [_fmt(TBL_MX[_tMxI]), TBL_RN[_tRnI].toString(), ""];

        for (var i = 0; i < 3; i++) {
            var y = sY + i * rowH;
            var sel = (i == _tF);
            var ty = y + (rowH - fH) / 2;
            if (i < 2) {
                dc.setColor(sel ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, ty, Graphics.FONT_XTINY, labels[i] + "  " + vals[i], Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(sel ? 0x00DDAA : 0x444444, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, ty, Graphics.FONT_XTINY, "START", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        var maxH = TBL_MX[_tMxI];
        var preview = "";
        if (_mode == FM_CO) {
            var h = maxH * 55 / 100;
            preview = "Hold " + _fmt(h) + "  Rest " + _fmt(h * 2 > 120 ? 120 : h * 2) + "-0:30";
        } else {
            var hS = maxH * 50 / 100; var hE = maxH * 85 / 100;
            preview = "Hold " + _fmt(hS) + "-" + _fmt(hE) + "  Rest 2:00";
        }
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 74 / 100, Graphics.FONT_XTINY, preview, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 81 / 100, Graphics.FONT_XTINY, "UP/DN adjust  SEL next", Graphics.TEXT_JUSTIFY_CENTER);
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

        var rMax = _w * 36 / 100;
        if (rMax > _h * 36 / 100) { rMax = _h * 36 / 100; }

        // Outer glow rings around the whole circle
        var t6 = _sub / 3 % 6;
        var outerGlow = (t6 < 3) ? t6 / 3 : (6 - t6) / 3;
        dc.setColor(_lighten(pC, -80), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rMax + 5 + outerGlow);
        dc.setColor(_lighten(pC, -68), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rMax + 3);

        // Dark background ring
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

        // HOLD label — prominent, above timer
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

        // Big time display with drop shadow
        dc.setColor(_lighten(pC, -65), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 2, nY + 2, nF, _fmt(s), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, nY, nF, _fmt(s), Graphics.TEXT_JUSTIFY_CENTER);

        // PB reference below timer
        if (_apPB > 0) {
            dc.setColor(_lighten(pC, -50), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, nY + nH + 2, Graphics.FONT_XTINY, "PB " + _fmt(_apPB), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Stop hint
        dc.setColor(0x0C1826, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 83 / 100, Graphics.FONT_XTINY, "SELECT = stop", Graphics.TEXT_JUSTIFY_CENTER);
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

        // Outer thin ring (always full circle — decorative border)
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

        // Phase label with drop shadow — centered above countdown
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

    hidden function _fbMsg() {
        if (_mode == FM_AP && _apNP) { return "New PB"; }
        if (_exEarly) { return "Session ended"; }
        return "Session complete";
    }

    hidden function _drSafe(dc) {
        var cx = _w / 2;
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 14 / 100, Graphics.FONT_XTINY, "SAFETY", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 28 / 100, Graphics.FONT_XTINY, "TRAINING TOOL ONLY", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 44 / 100, Graphics.FONT_XTINY, "Not for in-water use", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, _h * 56 / 100, Graphics.FONT_XTINY, "Never train alone", Graphics.TEXT_JUSTIFY_CENTER);

        var hC = (_tick % 12 < 6) ? 0x00BBEE : 0x335566;
        dc.setColor(hC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 78 / 100, Graphics.FONT_XTINY, "SELECT = OK", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drDone(dc) {
        var cx = _w / 2;
        dc.setColor(0x00BBEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 12 / 100, Graphics.FONT_XTINY, "COMPLETE", Graphics.TEXT_JUSTIFY_CENTER);

        if (_mode == FM_AP) {
            var s = _apLS; var pC = _apColor(s);
            var nF = (_h >= 200) ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_MILD;
            var nH = dc.getFontHeight(nF);
            dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 22 / 100, nF, _fmt(s), Graphics.TEXT_JUSTIFY_CENTER);
            var midY = _h * 22 / 100 + nH + _h * 1 / 100;
            if (_apNP) {
                var flash = (_tick % 8 < 4) ? 0xFFDD00 : 0xFFAA00;
                dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, midY, Graphics.FONT_SMALL, "NEW PB!", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (_apPB > 0 && s < _apPB) {
                dc.setColor(0x1A3040, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, midY, Graphics.FONT_XTINY,
                    "PB: " + _fmt(_apPB) + "  (-" + (_apPB - s) + "s)", Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else if (_mode == FM_BR) {
            var flash = (_tick % 10 < 5) ? 0xFFDD00 : 0xFFAA00;
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
            var flash = (_tick % 10 < 5) ? 0xFFDD00 : 0xFFAA00;
            dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 24 / 100, Graphics.FONT_MEDIUM, "DONE!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x446666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 42 / 100, Graphics.FONT_XTINY, tag, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x3388AA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 52 / 100, Graphics.FONT_SMALL,
                _tTR + " rounds", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0xAACCBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 63 / 100, Graphics.FONT_XTINY, _fbMsg(), Graphics.TEXT_JUSTIFY_CENTER);

        var hC = (_tick % 12 < 6) ? 0x00BBEE : 0x333333;
        dc.setColor(hC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 85 / 100, Graphics.FONT_XTINY, "SELECT = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drStat(dc) {
        var cx = _w / 2;
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 6 / 100, Graphics.FONT_XTINY, _nmStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 16 / 100, Graphics.FONT_XTINY, "TRAINING STATS", Graphics.TEXT_JUSTIFY_CENTER);

        var totalS = _stBrC + _stApC + _stCoC + _stO2C;
        var fH = dc.getFontHeight(Graphics.FONT_XTINY);
        var gap = fH + 2;
        var y = _h * 28 / 100;

        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "Sessions: " + totalS, Graphics.TEXT_JUSTIFY_CENTER);
        y += gap;
        dc.drawText(cx, y, Graphics.FONT_XTINY, "Total: " + (_stTotT / 60) + " min", Graphics.TEXT_JUSTIFY_CENTER);
        y += gap + 4;

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "Breathe " + _stBrC + "x  " + (_stBrT / 60) + "m", Graphics.TEXT_JUSTIFY_CENTER);
        y += gap;
        dc.drawText(cx, y, Graphics.FONT_XTINY, "Apnea " + _stApC + "x  PB " + _fmt(_apPB), Graphics.TEXT_JUSTIFY_CENTER);
        y += gap;
        dc.drawText(cx, y, Graphics.FONT_XTINY, "CO2 " + _stCoC + "x  O2 " + _stO2C + "x", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 80 / 100, Graphics.FONT_XTINY, "BACK = menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drCust(dc) {
        var cx = _w / 2;
        var fntH = dc.getFontHeight(Graphics.FONT_XTINY);
        var itemH = fntH + 4;
        var dotsH = 12; // extra row for colour preview dots

        // Layout: theme + dots + name + vibration + save
        var totalH = itemH * 4 + dotsH;
        var startY = (_h - totalH) / 2;

        // Header — same style as MORE
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, startY - fntH - 4, Graphics.FONT_XTINY, "CUSTOMIZE", Graphics.TEXT_JUSTIFY_CENTER);

        // Row 0 — Theme
        _cstRowY0 = startY;
        dc.setColor((_cF == 0) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, startY + 2, Graphics.FONT_XTINY, "Theme  " + _thName(), Graphics.TEXT_JUSTIFY_CENTER);

        // Colour palette dots (always shown, compact)
        var dotsY = startY + itemH + dotsH / 2;
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 28, dotsY, 3);
        dc.setColor(_cHI,  Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 14, dotsY, 3);
        dc.setColor(_cEXH, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx,      dotsY, 3);
        dc.setColor(_cHE,  Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 14, dotsY, 3);
        dc.setColor(_cPRP, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 28, dotsY, 3);

        // Row 1 — Name
        var y1 = startY + itemH + dotsH;
        _cstRowY1 = y1;
        dc.setColor((_cF == 1) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y1 + 2, Graphics.FONT_XTINY, "Name  " + _nmStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Row 2 — Vibration (utility style = cINH when selected)
        var y2 = y1 + itemH;
        _cstRowY2 = y2;
        dc.setColor((_cF == 2) ? _cINH : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y2 + 2, Graphics.FONT_XTINY, "Vibration  " + (_vibOn ? "ON" : "OFF"), Graphics.TEXT_JUSTIFY_CENTER);

        // Row 3 — SAVE (accent teal, like Reset is red in MORE)
        var y3 = y2 + itemH;
        _cstRowY3 = y3;
        dc.setColor((_cF == 3) ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y3 + 2, Graphics.FONT_XTINY, "SAVE", Graphics.TEXT_JUSTIFY_CENTER);
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

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 76 / 100, Graphics.FONT_XTINY, "UP/DN letter  SEL next", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, _h * 84 / 100, Graphics.FONT_XTINY, "BACK = done", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
