using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.System;
using Toybox.Application;

const FT_MENU = 0;
const FT_BCFG = 1;
const FT_TCFG = 2;
const FT_ACT  = 3;
const FT_PAU  = 4;
const FT_DONE = 5;
const FT_CUST = 6;
const FT_STAT = 7;
const FT_NAME = 8;

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

class FreedivingTrainingView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick; hidden var _sub;
    hidden var _gs; hidden var _mode; hidden var _mSel;

    hidden var _brM; hidden var _brF;
    hidden var _brII; hidden var _brHI; hidden var _brEI; hidden var _brXI; hidden var _brSI;
    hidden var _brPat;
    hidden var _brPh; hidden var _brPD; hidden var _brPE; hidden var _brPS;
    hidden var _brRem; hidden var _brSS; hidden var _brBC;

    hidden var _tMxI; hidden var _tRnI; hidden var _tF;
    hidden var _tRnd; hidden var _tTR;
    hidden var _tPh; hidden var _tPS; hidden var _tPE; hidden var _tPSub;
    hidden var _tH; hidden var _tR;

    hidden var _apE; hidden var _apPS; hidden var _apPB; hidden var _apLS;
    hidden var _apNP; hidden var _apLog; hidden var _apWS; hidden var _apCS; hidden var _apWF;

    hidden var _cF; hidden var _nmPos; hidden var _nmChrs; hidden var _thIdx; hidden var _nmStr;
    hidden var _cINH; hidden var _cHI; hidden var _cEXH; hidden var _cHE;
    hidden var _cPRP; hidden var _cRST; hidden var _cHLD;
    hidden var _stBrC; hidden var _stBrT; hidden var _stApC;
    hidden var _stCoC; hidden var _stO2C; hidden var _stTotT;

    function initialize() {
        View.initialize();
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _tick = 0; _sub = 0;
        _gs = FT_MENU; _mode = FM_BR; _mSel = 0;

        _brM = 0; _brF = 0;
        _brII = 2; _brHI = 0; _brEI = 2; _brXI = 0; _brSI = 1;
        _brPat = [4, 0, 6, 0];
        _brPh = BP_INH; _brPD = 4; _brPE = 0; _brPS = 0;
        _brRem = 0; _brSS = 0; _brBC = 0;

        _tMxI = 2; _tRnI = 2; _tF = 0;
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
        var th = Application.Storage.getValue("usr_thm");
        _thIdx = (th instanceof Number) ? th : 0;
        _nmChrs = new [8];
        var nm = Application.Storage.getValue("usr_nm");
        if (!(nm instanceof Toybox.Lang.String)) { nm = "DIVER"; }
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
                    _brPS = 0; _brPE++; _brRem--;
                    if (_brRem <= 0) { _saveSt(FM_BR, _brSS); _vibeDone(); _gs = FT_DONE; WatchUi.requestUpdate(); return; }
                    if (_brPE >= _brPD) { _nxBrPh(); }
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
        return 0x22CC55;
    }

    hidden function _vibe(inten, dur) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(inten, dur)]);
            }
        }
    }

    hidden function _vibeDouble(inten, dur, gap) {
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
        if (_gs == FT_MENU) { _mSel = (_mSel + 5) % 6; }
        else if (_gs == FT_BCFG) { _adjBrF(-1); }
        else if (_gs == FT_TCFG) { _adjTF(-1); }
        else if (_gs == FT_CUST) { _adjCust(-1); }
        else if (_gs == FT_NAME) { _adjNmCh(-1); }
    }

    function doDown() {
        if (_gs == FT_MENU) { _mSel = (_mSel + 1) % 6; }
        else if (_gs == FT_BCFG) { _adjBrF(1); }
        else if (_gs == FT_TCFG) { _adjTF(1); }
        else if (_gs == FT_CUST) { _adjCust(1); }
        else if (_gs == FT_NAME) { _adjNmCh(1); }
    }

    function doSelect() {
        if (_gs == FT_MENU) {
            if (_mSel < 4) {
                _mode = _mSel;
                if (_mode == FM_BR) { _brF = 0; _gs = FT_BCFG; }
                else if (_mode == FM_AP) { _startAp(); }
                else { _tF = 0; _gs = FT_TCFG; }
            } else if (_mSel == 4) { _gs = FT_STAT; }
            else { _cF = 0; _gs = FT_CUST; }
        } else if (_gs == FT_BCFG) {
            var mx = _brFldCnt();
            if (_brF < mx - 1) { _brF++; }
            else { _startBr(); }
        } else if (_gs == FT_TCFG) {
            if (_tF < 2) { _tF++; }
            else { _startTbl(); }
        } else if (_gs == FT_ACT) {
            if (_mode == FM_AP) { _stopAp(); }
            else { _gs = FT_PAU; }
        } else if (_gs == FT_PAU) {
            _gs = FT_ACT;
        } else if (_gs == FT_DONE || _gs == FT_STAT) {
            _gs = FT_MENU;
        } else if (_gs == FT_CUST) {
            if (_cF == 0) { _cF = 1; }
            else if (_cF == 1) { _nmPos = 0; _gs = FT_NAME; }
            else { _saveCustom(); _gs = FT_MENU; }
        } else if (_gs == FT_NAME) {
            if (_nmPos < 7) { _nmPos++; }
            else { _nmStr = _bldNm(); _gs = FT_CUST; }
        }
    }

    function doBack() {
        if (_gs == FT_BCFG) { if (_brF > 0) { _brF--; return true; } _gs = FT_MENU; return true; }
        if (_gs == FT_TCFG) { if (_tF > 0) { _tF--; return true; } _gs = FT_MENU; return true; }
        if (_gs == FT_ACT || _gs == FT_PAU) { _gs = FT_MENU; return true; }
        if (_gs == FT_DONE || _gs == FT_STAT) { _gs = FT_MENU; return true; }
        if (_gs == FT_CUST) { if (_cF > 0) { _cF--; return true; } _gs = FT_MENU; return true; }
        if (_gs == FT_NAME) {
            if (_nmPos > 0) { _nmPos--; return true; }
            _nmStr = _bldNm(); _gs = FT_CUST; return true;
        }
        return false;
    }

    function doTap(x, y) {
        if (_gs == FT_MENU) {
            var fntH = Graphics.getFontHeight(Graphics.FONT_XTINY);
            var itemH = fntH + 4;
            var totalH = itemH * 6;
            var startY = (_h - totalH) / 2;
            for (var i = 0; i < 6; i++) {
                var ry = startY + i * itemH;
                if (y >= ry && y < ry + itemH) { _mSel = i; doSelect(); return; }
            }
        } else if (_gs == FT_BCFG || _gs == FT_TCFG || _gs == FT_CUST || _gs == FT_NAME) {
            if (y < _h / 2) { doUp(); } else { doDown(); }
        } else { doSelect(); }
    }

    hidden function _startBr() {
        if (_brM < 3) {
            var mp = BR_PAT[_brM];
            _brPat = [mp[0], mp[1], mp[2], mp[3]];
        } else {
            _brPat = [BR_INH[_brII], BR_HLD[_brHI], BR_EXH[_brEI], BR_HLD[_brXI]];
        }
        _brSS = BR_SES[_brSI] * 60; _brRem = _brSS; _brBC = 0;
        _brPh = BP_INH; _brPD = _brPat[BP_INH]; _brPE = 0; _brPS = 0;
        _gs = FT_ACT; _vibe(80, 300);
    }

    hidden function _startAp() {
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
    }

    hidden function _adjNmCh(dir) {
        var len = NM_CH.length();
        _nmChrs[_nmPos] = (_nmChrs[_nmPos] + dir + len) % len;
    }

    hidden function _applyTheme() {
        if (_thIdx == 0) {
            _cINH=0x00BBEE; _cHI=0x00DDAA; _cEXH=0x8866EE; _cHE=0xEE8844;
            _cPRP=0xFFBB33; _cRST=0x3399DD; _cHLD=0x00CCAA;
        } else if (_thIdx == 1) {
            _cINH=0xFF7744; _cHI=0xFFBB33; _cEXH=0xCC4466; _cHE=0xDD6633;
            _cPRP=0xFFDD44; _cRST=0xFF8855; _cHLD=0xFFBB66;
        } else if (_thIdx == 2) {
            _cINH=0x33CC66; _cHI=0x88BB33; _cEXH=0x55AA44; _cHE=0x77CC22;
            _cPRP=0xCCDD44; _cRST=0x44BB77; _cHLD=0x66CC44;
        } else if (_thIdx == 3) {
            _cINH=0x88DDFF; _cHI=0xAAEEFF; _cEXH=0x6699FF; _cHE=0x88BBDD;
            _cPRP=0xDDEEFF; _cRST=0x77CCEE; _cHLD=0xAADDFF;
        } else {
            _cINH=0xFF00CC; _cHI=0x00FF88; _cEXH=0xFFFF00; _cHE=0xFF6600;
            _cPRP=0xFF66FF; _cRST=0x00CCFF; _cHLD=0x66FF66;
        }
    }

    hidden function _bldNm() {
        var s = "";
        for (var i = 0; i < 8; i++) { s = s + NM_CH.substring(_nmChrs[i], _nmChrs[i] + 1); }
        var len = 8;
        while (len > 0 && _nmChrs[len - 1] == 36) { len--; }
        if (len == 0) { return "DIVER"; }
        return s.substring(0, len);
    }

    hidden function _saveCustom() {
        _nmStr = _bldNm();
        Application.Storage.setValue("usr_nm", _nmStr);
        Application.Storage.setValue("usr_thm", _thIdx);
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
        r = r + (255 - r) * pct / 100; g = g + (255 - g) * pct / 100; b = b + (255 - b) * pct / 100;
        if (r > 255) { r = 255; } if (g > 255) { g = 255; } if (b > 255) { b = 255; }
        return (r << 16) | (g << 8) | b;
    }

    hidden function _brPhColor() {
        if (_brPh == BP_INH) { return _cINH; }
        if (_brPh == BP_HI)  { return _cHI; }
        if (_brPh == BP_EXH) { return _cEXH; }
        return _cHE;
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

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        dc.setColor(0x000000, 0x000000); dc.clear();
        if (_gs == FT_MENU) { _drMenu(dc); }
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
        else { _drDone(dc); }
    }

    hidden function _drMenu(dc) {
        var cx = _w / 2;
        var labels = ["Breathe", "Static Apnea", "CO2 Table", "O2 Table", "Stats", "Customize"];
        var fntH = dc.getFontHeight(Graphics.FONT_XTINY);
        var itemH = fntH + 4;
        var totalH = itemH * 6;
        var startY = (_h - totalH) / 2;

        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, startY - fntH - 4, Graphics.FONT_XTINY, _nmStr, Graphics.TEXT_JUSTIFY_CENTER);

        for (var i = 0; i < 6; i++) {
            var y = startY + i * itemH;
            if (i < 4) {
                dc.setColor((i == _mSel) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor((i == _mSel) ? 0x00DDAA : 0x444444, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx, y + 2, Graphics.FONT_XTINY, labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
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
        var cx = _w / 2; var cy = _h * 46 / 100;
        var frac = 0.0;
        if (_brPD > 0) {
            frac = (_brPE.toFloat() + _brPS.toFloat() / 10.0) / _brPD.toFloat();
            if (frac > 1.0) { frac = 1.0; }
        }
        var eF = frac;
        if (_brPh == BP_INH) { eF = 1.0 - (1.0 - frac) * (1.0 - frac); }
        else if (_brPh == BP_EXH) { eF = frac * frac; }

        var rMin = _h * 7 / 100; if (rMin < 10) { rMin = 10; }
        var rMax = _h * 30 / 100;
        var r;
        if      (_brPh == BP_INH) { r = rMin + ((rMax - rMin).toFloat() * eF).toNumber(); }
        else if (_brPh == BP_HI)  { r = rMax; }
        else if (_brPh == BP_EXH) { r = rMax - ((rMax - rMin).toFloat() * eF).toNumber(); }
        else                      { r = rMin; }

        var pC = _brPhColor();

        var arcR = _h * 38 / 100;
        var sessR = 0.0;
        if (_brSS > 0) { sessR = 1.0 - (_brRem.toFloat() / _brSS.toFloat()); }
        dc.setPenWidth(3);
        dc.setColor(0x0A1520, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, arcR);
        if (sessR > 0.01) {
            dc.setColor(0x005577, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, 90, 90 - (sessR * 360).toNumber());
        }
        dc.setPenWidth(1);

        var glowR = r + 10;
        dc.setColor(0x002838, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, glowR + 5);
        dc.setColor(0x003848, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, glowR + 2);
        dc.setColor(0x005060, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, glowR);

        dc.setColor(pC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r);
        if (r > 20) {
            dc.setColor(_lighten(pC, 15), Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r * 80 / 100);
            dc.setColor(_lighten(pC, 30), Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r * 55 / 100);
            dc.setColor(_lighten(pC, 55), Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r * 30 / 100);
            dc.setColor(0xEEF6FF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, cy, r * 12 / 100);
        }

        var phRem = _brPD - _brPE;
        var inC = (r > rMin + 20);
        var sfH = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var xfH = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(inC ? 0xFFFFFF : pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - sfH / 2 - xfH / 2, Graphics.FONT_MEDIUM, phRem.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(inC ? 0xCCEEFF : pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + sfH / 2 - xfH / 2, Graphics.FONT_XTINY, _brPhLbl(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x556666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 7 / 100, Graphics.FONT_XTINY, _fmt(_brRem), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x446666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 80 / 100, Graphics.FONT_XTINY, "#" + (_brBC + 1), Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drApAct(dc) {
        var cx = _w / 2; var cy = _h * 45 / 100;
        var s = _apE / 5;
        var pC = _apColor(s);

        var rMax = _w * 36 / 100;
        if (rMax > _h * 36 / 100) { rMax = _h * 36 / 100; }
        var ringR = rMax;
        var pulse = (_sub / 2 % 4 < 2) ? 0 : 1;
        dc.setColor(0x081828, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, ringR + pulse);

        if (_apPB > 0 && s > 0) {
            var arcR = ringR - 5; if (arcR < 8) { arcR = 8; }
            dc.setColor(0x1A3040, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, arcR);
            var pct = s * 360 / _apPB;
            if (pct >= 360) {
                dc.setColor(pC, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, arcR); dc.drawCircle(cx, cy, arcR + 1);
            } else {
                dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, 90, 90 - pct);
                dc.drawArc(cx, cy, arcR + 1, Graphics.ARC_CLOCKWISE, 90, 90 - pct);
            }
        }

        var nF = (_h >= 200) ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_MILD;
        var nH = dc.getFontHeight(nF);
        var nY = cy - nH / 2 - _h * 2 / 100;
        if (nY < _h * 18 / 100) { nY = _h * 18 / 100; }
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, nY, nF, _fmt(s), Graphics.TEXT_JUSTIFY_CENTER);

        var lY = nY - _h * 8 / 100;
        if (lY < _h * 10 / 100) { lY = _h * 10 / 100; }
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, lY, Graphics.FONT_XTINY, "HOLD", Graphics.TEXT_JUSTIFY_CENTER);

        if (_apPB > 0) {
            dc.setColor(0x1A3040, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, nY + nH + _h * 1 / 100, Graphics.FONT_XTINY, "PB " + _fmt(_apPB), Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x0C1826, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 80 / 100, Graphics.FONT_XTINY, "SELECT = stop", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drTblAct(dc) {
        var cx = _w / 2; var cy = _h * 44 / 100;
        var pC = _tblPhColor();
        var arcR = _w * 33 / 100;
        if (arcR > _h * 33 / 100) { arcR = _h * 33 / 100; }
        if (arcR > _w / 2 - 4) { arcR = _w / 2 - 4; }

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, arcR);

        var prog = 0;
        if (_tPS > 0) { prog = _tPE * 360 / _tPS; }
        if (prog >= 360) {
            dc.setColor(pC, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx, cy, arcR); dc.drawCircle(cx, cy, arcR + 1);
        } else if (prog > 0) {
            dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, 90, 90 - prog);
            dc.drawArc(cx, cy, arcR + 1, Graphics.ARC_CLOCKWISE, 90, 90 - prog);
        }

        var rem = _tPS - _tPE; if (rem < 0) { rem = 0; }
        var nF = (_h >= 200) ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_MILD;
        var nH = dc.getFontHeight(nF);
        var nY = cy - nH / 2 - _h * 2 / 100;
        if (nY < _h * 18 / 100) { nY = _h * 18 / 100; }

        var lY = nY - _h * 8 / 100;
        if (lY < _h * 11 / 100) { lY = _h * 11 / 100; }
        dc.setColor(pC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, lY, Graphics.FONT_XTINY, _tblPhLbl(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, nY, nF, _fmt(rem), Graphics.TEXT_JUSTIFY_CENTER);

        var tag = (_mode == FM_CO) ? "CO2" : "O2 ";
        dc.setColor(0x446666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 70 / 100, Graphics.FONT_XTINY,
            tag + "  Round " + (_tRnd + 1) + "/" + _tTR, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x223333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 79 / 100, Graphics.FONT_XTINY, "SELECT = pause", Graphics.TEXT_JUSTIFY_CENTER);
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

        var hC = (_tick % 12 < 6) ? 0x00BBEE : 0x333333;
        dc.setColor(hC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 78 / 100, Graphics.FONT_XTINY, "SELECT = menu", Graphics.TEXT_JUSTIFY_CENTER);
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
        dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 8 / 100, Graphics.FONT_XTINY, "CUSTOMIZE", Graphics.TEXT_JUSTIFY_CENTER);

        var fH = dc.getFontHeight(Graphics.FONT_XTINY);
        var rowH = fH + 14; if (rowH > _h / 5) { rowH = _h / 5; }
        var sY = _h * 26 / 100;

        dc.setColor((_cF == 0) ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sY, Graphics.FONT_XTINY, "THEME  " + _thName(), Graphics.TEXT_JUSTIFY_CENTER);

        if (_cF == 0) {
            var dotY = sY + fH + 6;
            dc.setColor(_cINH, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 30, dotY, 5);
            dc.setColor(_cHI, Graphics.COLOR_TRANSPARENT);  dc.fillCircle(cx - 15, dotY, 5);
            dc.setColor(_cEXH, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, dotY, 5);
            dc.setColor(_cHE, Graphics.COLOR_TRANSPARENT);  dc.fillCircle(cx + 15, dotY, 5);
            dc.setColor(_cPRP, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 30, dotY, 5);
        }

        sY += rowH + 8;
        dc.setColor((_cF == 1) ? 0xFFFFFF : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sY, Graphics.FONT_XTINY, "NAME  " + _nmStr, Graphics.TEXT_JUSTIFY_CENTER);

        sY += rowH;
        dc.setColor((_cF == 2) ? 0x00DDAA : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sY, Graphics.FONT_XTINY, "SAVE", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 80 / 100, Graphics.FONT_XTINY, "UP/DN adjust  SEL next", Graphics.TEXT_JUSTIFY_CENTER);
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
