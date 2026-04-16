using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.System;
using Toybox.Attention;

const FN_HOME      = 0;
const FN_CONFIG    = 1;
const FN_COUNTDOWN = 2;
const FN_FAKE      = 3;

const MOD_CALL  = 0;
const MOD_MSG   = 1;
const MOD_NOTIF = 2;
const NUM_MODS  = 3;
const SPM       = 4;
const MPM       = 4;

class FakeNotifView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    hidden var _curMod;
    hidden var _senderIdx;
    hidden var _msgIdx;
    hidden var _delayIdx;
    hidden var _configFocus;

    hidden var _countdownLeft;
    hidden var _fakeTick;
    hidden var _fakeDismiss;

    hidden var _modNames;
    hidden var _allSenders;
    hidden var _allMsgs;
    hidden var _delayLabels;
    hidden var _delayTicks;

    // Notification sub-type colors per sender index
    hidden var _notifColors;

    function initialize() {
        View.initialize();
        Math.srand(System.getTimer());
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth; _h = ds.screenHeight;
        _tick = 0; _gs = FN_HOME;
        _curMod = 0; _senderIdx = 0; _msgIdx = 0; _delayIdx = 0;
        _configFocus = 0;
        _countdownLeft = 0; _fakeTick = 0; _fakeDismiss = 100;

        _modNames = ["CALL", "MESSAGE", "NOTIFICATION"];

        // Notification icon colors: 0,1 = Slack (purple), 2,3 = Prod/PD (red)
        _notifColors = [0x611F69, 0x611F69, 0xCC3333, 0xCC3333];

        // 4 senders × 3 modes = 12
        _allSenders = [
            "Unknown",     "Mom",         "Boss",        "Dr. Smith",
            "Work Group",  "Mom",         "John D.",     "IT Security",
            "#general",    "#dev-ops",    "PROD-001",    "SEV-1 CRIT"
        ];

        // 4 messages × 3 modes = 12
        _allMsgs = [
            "Calling...",       "Incoming call",    "Answer now",       "Urgent call",
            "Are you free??",   "Call me ASAP!",    "Come NOW!",        "URGENT: Respond",
            "Need your help",   "Deploy in 5min",   "Production DOWN",  "API critical"
        ];

        _delayLabels = ["Now", "30s", "1'", "5'", "10'"];
        _delayTicks  = [0, 150, 300, 1500, 3000];

        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 200, true);
    }

    function onLayout(dc) { _w = dc.getWidth(); _h = dc.getHeight(); }

    // ── Timer ──────────────────────────────────────────────────────────────────

    function onTick() as Void {
        _tick++;
        if (_gs == FN_COUNTDOWN) {
            _countdownLeft--;
            if (_countdownLeft <= 0) {
                _gs = FN_FAKE; _fakeTick = 0;
                _fakeDismiss = (_curMod == MOD_CALL) ? 80 : (_curMod == MOD_NOTIF && _senderIdx >= 2) ? 65 : 45;
                _triggerVibe();
            }
        } else if (_gs == FN_FAKE) {
            _fakeTick++;
            if (_curMod == MOD_CALL && _fakeTick % 25 == 0) { _triggerVibe(); }
            if (_curMod == MOD_NOTIF && _senderIdx >= 2 && _fakeTick % 15 == 0) { _triggerVibePD(); }
            if (_fakeTick >= _fakeDismiss) { _gs = FN_HOME; }
        }
        WatchUi.requestUpdate();
    }

    // ── Vibration ──────────────────────────────────────────────────────────────

    hidden function _triggerVibe() {
        if (!(Toybox has :Attention)) { return; }
        if (!(Toybox.Attention has :vibrate)) { return; }
        var patterns;
        if (_curMod == MOD_CALL) {
            patterns = [new Toybox.Attention.VibeProfile(90, 400),
                        new Toybox.Attention.VibeProfile(0, 150),
                        new Toybox.Attention.VibeProfile(90, 400)];
        } else if (_curMod == MOD_MSG) {
            patterns = [new Toybox.Attention.VibeProfile(70, 80),
                        new Toybox.Attention.VibeProfile(0, 80),
                        new Toybox.Attention.VibeProfile(70, 80)];
        } else {
            patterns = [new Toybox.Attention.VibeProfile(100, 200),
                        new Toybox.Attention.VibeProfile(0, 60),
                        new Toybox.Attention.VibeProfile(100, 200)];
        }
        Toybox.Attention.vibrate(patterns);
    }

    hidden function _triggerVibePD() {
        if (!(Toybox has :Attention)) { return; }
        if (!(Toybox.Attention has :vibrate)) { return; }
        Toybox.Attention.vibrate([
            new Toybox.Attention.VibeProfile(100, 120),
            new Toybox.Attention.VibeProfile(0,   40),
            new Toybox.Attention.VibeProfile(100, 120),
            new Toybox.Attention.VibeProfile(0,   40),
            new Toybox.Attention.VibeProfile(100, 300)
        ]);
    }

    // ── Input ──────────────────────────────────────────────────────────────────

    function doNext() {
        if (_gs == FN_HOME)   { _curMod = (_curMod + 1) % NUM_MODS; return; }
        if (_gs == FN_CONFIG) {
            if (_configFocus == 0) { _senderIdx = (_senderIdx + 1) % SPM; _msgIdx = _senderIdx; }
            else                   { _delayIdx  = (_delayIdx  + 1) % 5; }
            return;
        }
    }

    function doPrev() {
        if (_gs == FN_HOME)   { _curMod = (_curMod + NUM_MODS - 1) % NUM_MODS; return; }
        if (_gs == FN_CONFIG) {
            if (_configFocus == 0) { _senderIdx = (_senderIdx + SPM - 1) % SPM; _msgIdx = _senderIdx; }
            else                   { _delayIdx  = (_delayIdx  + 4) % 5; }
            return;
        }
    }

    function doSelect() {
        if (_gs == FN_HOME) {
            _senderIdx = 0; _msgIdx = 0; _delayIdx = 0; _configFocus = 0;
            _gs = FN_CONFIG;
            return;
        }
        if (_gs == FN_CONFIG) {
            if (_configFocus == 0) { _configFocus = 1; }
            else                   { _trigger(); }
            return;
        }
        if (_gs == FN_FAKE || _gs == FN_COUNTDOWN) { _gs = FN_HOME; }
    }

    function doBack() {
        if (_gs == FN_CONFIG)   { _gs = FN_HOME; return true; }
        if (_gs == FN_FAKE || _gs == FN_COUNTDOWN) { _gs = FN_HOME; return true; }
        return false;
    }

    function doTap(tx, ty) {
        if (_gs == FN_HOME) {
            var fntH = 18;
            var itemH = fntH + 4;
            var totalH = itemH * NUM_MODS;
            var startY = (_h - totalH) / 2;
            if (ty < startY) { return; }
            var sel = (ty - startY) / itemH;
            if (sel >= 0 && sel < NUM_MODS) {
                _curMod = sel;
                _senderIdx = 0; _msgIdx = 0; _delayIdx = 0; _configFocus = 0;
                _gs = FN_CONFIG;
            }
            return;
        }
        if (_gs == FN_CONFIG) {
            var third = _h / 3;
            var mg = _w * 15 / 100;
            if (ty < third) {
                _configFocus = 0;
                if (tx < _w / 2) { _senderIdx = (_senderIdx + SPM - 1) % SPM; }
                else              { _senderIdx = (_senderIdx + 1) % SPM; }
                _msgIdx = _senderIdx;
            } else if (ty < third * 2) {
                _configFocus = 1;
                var btnW = (_w - mg * 2) / 5;
                if (btnW > 0 && tx >= mg) {
                    var di = (tx - mg) / btnW;
                    if (di >= 0 && di < 5) { _delayIdx = di; }
                }
            } else {
                _trigger();
            }
            return;
        }
        if (_gs == FN_FAKE || _gs == FN_COUNTDOWN) { _gs = FN_HOME; }
    }

    hidden function _trigger() {
        var delay = _delayTicks[_delayIdx];
        if (delay <= 0) {
            _gs = FN_FAKE; _fakeTick = 0;
            _fakeDismiss = (_curMod == MOD_CALL) ? 80 : (_curMod == MOD_NOTIF && _senderIdx >= 2) ? 65 : 45;
            _triggerVibe();
        } else {
            _countdownLeft = delay; _gs = FN_COUNTDOWN;
        }
    }

    // ── Rendering ──────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        if      (_gs == FN_HOME)      { _drawHome(dc); }
        else if (_gs == FN_CONFIG)    { _drawConfig(dc); }
        else if (_gs == FN_COUNTDOWN) { _drawCountdown(dc); }
        else if (_gs == FN_FAKE) {
            if (_curMod == MOD_CALL) { _drawFakeCall(dc); }
            else if (_curMod == MOD_MSG) { _drawFakeMsg(dc, 0x4488FF, "just now"); }
            else { _drawFakeNotif(dc); }
        }
    }

    // ── HOME ─────────────────────────────────────────────────────────────────

    hidden function _drawHome(dc) {
        dc.setColor(0x000000, 0x000000); dc.clear();
        var fntH = dc.getFontHeight(Graphics.FONT_XTINY);
        var itemH = fntH + 4;
        var totalH = itemH * NUM_MODS;
        var startY = (_h - totalH) / 2;

        for (var i = 0; i < NUM_MODS; i++) {
            var y = startY + i * itemH;
            dc.setColor((i == _curMod) ? 0xFFFFFF : 0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, y + 2, Graphics.FONT_XTINY,
                        _modNames[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── CONFIG ────────────────────────────────────────────────────────────────

    hidden function _drawConfig(dc) {
        var mg  = _w * 15 / 100;
        var fxH = dc.getFontHeight(Graphics.FONT_XTINY);
        var fsH = dc.getFontHeight(Graphics.FONT_SMALL);
        dc.setColor(0x000000, 0x000000); dc.clear();

        var third = _h / 3;

        // --- ROW 1: sender ---
        var sName = _allSenders[_curMod * SPM + _senderIdx];
        var focS = (_configFocus == 0);
        var sy = (third - fsH) / 2;
        dc.setColor(focS ? 0x666666 : 0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mg, sy, Graphics.FONT_XTINY, "<", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_w - mg, sy, Graphics.FONT_XTINY, ">", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(focS ? 0xFFFFFF : 0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, sy, Graphics.FONT_SMALL, sName, Graphics.TEXT_JUSTIFY_CENTER);

        // --- ROW 2: delay (5 buttons) ---
        var focD = (_configFocus == 1);
        var btnH = fxH + 4;
        var btnW = (_w - mg * 2) / 5;
        var btnY = third + (third - btnH) / 2;
        for (var dd = 0; dd < 5; dd++) {
            var dx = mg + dd * btnW;
            if (dd == _delayIdx) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(dx + 1, btnY, btnW - 2, btnH, 3);
            } else {
                dc.setColor(focD ? 0x555555 : 0x333333, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(dx + btnW / 2, btnY + 2,
                        Graphics.FONT_XTINY, _delayLabels[dd], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // --- ROW 3: go ---
        var goMg  = _w * 25 / 100;
        var fireBH = fxH + 4;
        var fireBY = third * 2 + (third - fireBH) / 2;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(goMg, fireBY, _w - goMg * 2, fireBH, 4);
        dc.drawText(_w / 2, fireBY + (fireBH - fxH) / 2,
                    Graphics.FONT_XTINY, "GO", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawCountdown(dc) {
        dc.setColor(0x000000, 0x000000); dc.clear();
        var ct = System.getClockTime();
        var mStr = ct.min < 10 ? "0" + ct.min.toString() : ct.min.toString();
        var fntH = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, (_h - fntH) / 2, Graphics.FONT_NUMBER_HOT,
                    ct.hour.toString() + ":" + mStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── FAKE CALL ──────────────────────────────────────────────────────────────

    hidden function _drawFakeCall(dc) {
        dc.setColor(0x000000, 0x000000); dc.clear();
        var sender = _allSenders[_curMod * SPM + _senderIdx];
        var fxH    = dc.getFontHeight(Graphics.FONT_XTINY);
        var cx     = _w / 2;

        var avR = _w * 8 / 100; if (avR < 10) { avR = 10; }
        var avY = _h * 28 / 100;
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, avY, avR);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, avY - fxH / 2, Graphics.FONT_XTINY,
                    sender.substring(0, 1).toUpper(), Graphics.TEXT_JUSTIFY_CENTER);

        var nameY = avY + avR + _h * 4 / 100;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var nameFont = (sender.length() <= 12) ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
        dc.drawText(cx, nameY, nameFont, sender, Graphics.TEXT_JUSTIFY_CENTER);

        var nameFH = dc.getFontHeight(nameFont);
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, nameY + nameFH + 2, Graphics.FONT_XTINY,
                    "Incoming Call", Graphics.TEXT_JUSTIFY_CENTER);

        var dBtnH = fxH + 6;
        var dBtnY = _h - _h * 14 / 100;
        var mg    = _w * 22 / 100;
        dc.setColor(0x661122, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(mg, dBtnY, _w - mg * 2, dBtnH, 3);
        dc.setColor(0x993344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, dBtnY + 3, Graphics.FONT_XTINY,
                    "Dismiss", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── FAKE MESSAGE — generic message notification ────────────────────────────

    hidden function _drawFakeMsg(dc, iconColor, footerText) {
        dc.setColor(0x000000, 0x000000); dc.clear();
        var sender = _allSenders[_curMod * SPM + _senderIdx];
        var msg    = _allMsgs[_curMod * MPM + _msgIdx];
        var cx     = _w / 2;
        var fxH    = dc.getFontHeight(Graphics.FONT_XTINY);
        var fsH    = dc.getFontHeight(Graphics.FONT_SMALL);

        var iconSz = _w * 4 / 100; if (iconSz < 5) { iconSz = 5; }
        var iconY  = _h * 14 / 100;
        dc.setColor(iconColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx - iconSz, iconY, iconSz * 2, iconSz * 2, 2);

        var nameY = _h * 36 / 100;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, nameY, Graphics.FONT_SMALL, sender, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, nameY + fsH + 3, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, nameY + fsH + fxH + 8, Graphics.FONT_XTINY,
                    footerText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── FAKE NOTIFICATION — Slack / PagerDuty / Prod with dynamic icon color ──

    hidden function _drawFakeNotif(dc) {
        var iconColor = _notifColors[_senderIdx];
        var footer = (_senderIdx >= 2) ? "High urgency" : "just now";
        _drawFakeMsg(dc, iconColor, footer);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    hidden function _darken(color) {
        var r = (color >> 16) & 0xFF;
        var g = (color >> 8)  & 0xFF;
        var b =  color        & 0xFF;
        r = r * 55 / 100; g = g * 55 / 100; b = b * 55 / 100;
        return (r << 16) | (g << 8) | b;
    }
}
