// ═══════════════════════════════════════════════════════════════════════════
// FarmView.mc — The FARM gameplay view.
//
// A six-screen carousel over one FarmModel:
//   HOME · BUILD · RESOURCES · EXPLORE · COLLECTION · LOG
//
// NAVIGATION (works fully with EITHER touch OR physical buttons):
//   • A persistent TAB STRIP at the top shows the current page name, ◀ ▶ chevron
//     tap-zones, and a row of tappable page dots.
//   • Physical UP/DOWN move the cursor within list pages (overflow-paging at the
//     ends). On non-list pages UP/DOWN change page. SELECT/ENTER activates.
//   • BACK saves and exits.
//
// DEMO MODE rapidly auto-develops the farm for showcasing. A gold DEMO badge
// shows while active. A WELCOME BACK overlay summarises idle income on open;
// random events prompt a choice. Sound/haptics gated by the shared option.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;

const IV_HOME = 0;
const IV_BUILD = 1;
const IV_RES = 2;
const IV_DISC = 3;
const IV_COLL = 4;
const IV_HIST = 5;
const IV_PAGES = 6;

class FarmView extends WatchUi.View {
    hidden var _m;
    hidden var _page;
    hidden var _w; hidden var _h;
    hidden var _t; hidden var _timer;
    hidden var _fxOn;

    hidden var _cur; hidden var _scroll;
    hidden var _popup; hidden var _popupT;
    hidden var _welcome;
    hidden var _event; hidden var _evChoice;
    hidden var _pendingWelcome;

    hidden var _demo; hidden var _demoT;
    hidden var _intro;

    hidden var _rows; hidden var _rowIds;
    hidden var _rBtnA; hidden var _rBtnB;
    hidden var _rPrev; hidden var _rNext; hidden var _rDemo;
    hidden var _tabRects;

    function initialize() {
        View.initialize();
        _m = new FarmModel();
        _page = IV_HOME; _w = 0; _h = 0; _t = 0; _timer = null;
        _cur = 0; _scroll = 0;
        _popup = null; _popupT = 0;
        _welcome = false; _event = false; _evChoice = 0; _pendingWelcome = false;
        _demo = false; _demoT = 0; _intro = false;
        _rows = []; _rowIds = []; _rBtnA = null; _rBtnB = null;
        _rPrev = null; _rNext = null; _rDemo = null; _tabRects = [];
        _loadFx();
        _loadDemo();
        _loadIntro();

        _m.ensureStart();
        _m.collectOffline();
        _pendingWelcome = _hasGains() || _m.newDay || _m.gEvent != Fa.EV_NONE;
        if (_m.pendingEvent != Fa.EV_NONE) { _event = true; _evChoice = 0; }
        else if (_pendingWelcome) { _welcome = true; }
        try { _m.submitScores(); } catch (e) {}
    }

    function model() { return _m; }

    hidden function _hasGains() {
        for (var i = 0; i < Fa.R_N; i++) { if (_m.gRes[i] > 0) { return true; } }
        return _m.gPop > 0 || _m.gVis > 0;
    }
    hidden function _loadFx() {
        _fxOn = true;
        try { var v = Application.Storage.getValue("fa_fx"); if (v instanceof Lang.Number) { _fxOn = (v == 0); } } catch (e) {}
    }
    hidden function _loadDemo() {
        _demo = false;
        if (!Fa.SHOW_DEMO) { return; }   // showcase-only; never active for users
        try { var v = Application.Storage.getValue("fa_demo"); if (v instanceof Lang.Number) { _demo = (v == 1); } } catch (e) {}
    }
    hidden function _loadIntro() {
        _intro = true;
        try { var v = Application.Storage.getValue("fa_seenintro"); if (v instanceof Lang.Number && v == 1) { _intro = false; } } catch (e) {}
    }
    hidden function _seenIntro() {
        _intro = false;
        try { Application.Storage.setValue("fa_seenintro", 1); } catch (e) {}
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_tick), 66, true); } catch (e) {}
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
        try { _m.save(); } catch (e) {}
    }
    function _tick() as Void {
        _t = (_t + 1) % 1000000;
        if (_popupT > 0) { _popupT -= 1; if (_popupT == 0) { _popup = null; } }
        // DEMO auto-development (~0.8s cadence). Fully guarded — never crashes.
        if (_demo && !_event && !_welcome) {
            _demoT += 1;
            if (_demoT >= 12) {
                _demoT = 0;
                try { _m.demoStep(); } catch (e) {}
            }
        }
        WatchUi.requestUpdate();
    }

    // ── Feedback ────────────────────────────────────────────────────────────
    function _tone(kind) {
        if (!_fxOn) { return; }
        try {
            if (!(Attention has :playTone)) { return; }
            var t = Attention.TONE_KEY;
            if (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
            else if (kind == 2) { t = Attention.TONE_ERROR; }
            else if (kind == 4) { t = Attention.TONE_SUCCESS; }
            Attention.playTone(t);
        } catch (e) {}
    }
    function _vibe(inten, dur) {
        if (!_fxOn) { return; }
        try {
            if (!(Attention has :vibrate)) { return; }
            Attention.vibrate([new Attention.VibeProfile(inten, dur)]);
        } catch (e) {}
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    hidden function _dismiss() {
        if (_event) { return false; }
        if (_intro) { _seenIntro(); WatchUi.requestUpdate(); return true; }
        if (_welcome) { _welcome = false; WatchUi.requestUpdate(); return true; }
        return false;
    }
    function pageMove(d) {
        if (_event) { return; }
        if (_dismiss()) { return; }
        _page = ((_page + d) % IV_PAGES + IV_PAGES) % IV_PAGES;
        _cur = 0; _scroll = 0;
        _tone(0); _vibe(12, 18);
        WatchUi.requestUpdate();
    }
    // Jump directly to a page (tapped tab dot).
    function jumpTo(p) {
        if (_event) { return; }
        if (_intro) { _seenIntro(); return; }
        if (_welcome) { _welcome = false; }
        _page = ((p % IV_PAGES) + IV_PAGES) % IV_PAGES;
        _cur = 0; _scroll = 0;
        _tone(0); _vibe(10, 15);
        WatchUi.requestUpdate();
    }
    function _listCount() {
        if (_page == IV_BUILD) { return Fa.B_N; }
        if (_page == IV_DISC)  { return Fa.AR_N; }
        if (_page == IV_COLL)  { return Fa.C_N; }
        return 0;
    }
    // UP/DOWN: move cursor on list pages (with overflow paging), else page.
    function cursorMove(d) {
        if (_event) { _evChoice = (_evChoice + 1) % 2; _tone(0); WatchUi.requestUpdate(); return; }
        if (_dismiss()) { return; }
        var n = _listCount();
        if (n > 0) {
            var nc = _cur + d;
            if (nc < 0)  { pageMove(-1); return; }   // overflow up  -> prev page
            if (nc >= n) { pageMove(1);  return; }   // overflow down -> next page
            _cur = nc; _tone(0); WatchUi.requestUpdate();
            return;
        }
        pageMove(d);
    }
    function activate() {
        if (_event) { _resolveEvent(_evChoice); return; }
        if (_dismiss()) { return; }
        if (_page == IV_BUILD) { _do(_m.upgrade(_cur)); return; }
        if (_page == IV_DISC)  { _do(_m.explore(_cur)); return; }
        if (_page == IV_HOME)  {
            if (_m.dailyComplete() && !_m.dailyClaimed) { _doClaim(); } else { setPage(IV_BUILD); }
            return;
        }
        if (_page == IV_RES)   { _doClaim(); return; }
        if (_page == IV_COLL)  {
            var owned = _m.hasColl(_cur);
            _popup = Fa.cName(_cur) + (owned ? " - owned" : " - locked"); _popupT = 26;
            WatchUi.requestUpdate();
            return;
        }
    }
    function setPage(p) {
        if (_event || _dismiss()) { return; }
        _page = ((p % IV_PAGES) + IV_PAGES) % IV_PAGES;
        _cur = 0; _scroll = 0;
        WatchUi.requestUpdate();
    }

    function toggleDemo() {
        _demo = !_demo;
        _demoT = 0;
        try { Application.Storage.setValue("fa_demo", _demo ? 1 : 0); } catch (e) {}
        _popup = _demo ? "DEMO ON - auto-building" : "DEMO OFF";
        _popupT = 28;
        _tone(_demo ? 4 : 0); _vibe(30, 40);
        WatchUi.requestUpdate();
    }

    hidden function _do(res) {
        if (res == null) { res = ""; }
        _popup = res; _popupT = 30;
        var bad = false;
        if (res.length() >= 4 && res.substring(0, 4).equals("Need")) { bad = true; }
        else if (res.length() >= 6 && res.substring(0, 6).equals("Locked")) { bad = true; }
        else if (res.length() >= 7 && res.substring(0, 7).equals("Invalid")) { bad = true; }
        if (bad) { _tone(2); _vibe(30, 40); } else { _tone(4); _vibe(35, 45); }
        WatchUi.requestUpdate();
    }
    hidden function _doClaim() {
        if (_m.claimDaily()) { _popup = "Challenge reward claimed!"; _popupT = 34; _tone(4); _vibe(60, 120); }
        else if (_m.dailyClaimed) { _popup = "Already claimed today"; _popupT = 24; }
        else { _popup = "Challenge not complete"; _popupT = 24; _tone(2); }
        WatchUi.requestUpdate();
    }
    hidden function _resolveEvent(choice) {
        var msg = "";
        try { msg = _m.resolveEvent(choice); } catch (e) { msg = ""; }
        _event = false;
        _tone(choice == 0 ? 4 : 0); _vibe(40, 60);
        if (msg != null && msg.length() > 0) { _popup = msg; _popupT = 36; }
        if (_pendingWelcome) { _welcome = true; }
        WatchUi.requestUpdate();
    }

    // ── Tap ─────────────────────────────────────────────────────────────────
    function onTapXY(x, y) {
        if (_event) {
            if (_inR(x, y, _rBtnA)) { _resolveEvent(0); return true; }
            if (_inR(x, y, _rBtnB)) { _resolveEvent(1); return true; }
            return true;
        }
        if (_intro || _welcome) { _dismiss(); return true; }
        // Tab dots — jump straight to a page.
        for (var i = 0; i < _tabRects.size(); i++) {
            if (_inR(x, y, _tabRects[i])) { jumpTo(i); return true; }
        }
        // Chevron edge zones — page prev/next.
        if (_inR(x, y, _rPrev)) { pageMove(-1); return true; }
        if (_inR(x, y, _rNext)) { pageMove(1);  return true; }
        // DEMO toggle (HOME).
        if (_page == IV_HOME && _inR(x, y, _rDemo)) { toggleDemo(); return true; }
        // Rows / grid cells.
        for (var j = 0; j < _rows.size(); j++) {
            if (_inR(x, y, _rows[j])) { _cur = _rowIds[j]; activate(); return true; }
        }
        // Primary action button (e.g. CLAIM).
        if (_inR(x, y, _rBtnA)) { activate(); return true; }
        return true;
    }
    hidden function _inR(x, y, r) {
        if (r == null) { return false; }
        return x >= r[0] && x < r[0] + r[2] && y >= r[1] && y < r[1] + r[3];
    }

    // ═══ Rendering ═══════════════════════════════════════════════════════════
    function onUpdate(dc) {
        try { _draw(dc); } catch (e) { try { dc.setColor(Fa.BG, Fa.BG); dc.clear(); } catch (e2) {} }
    }
    hidden function _draw(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        _rows = []; _rowIds = []; _rBtnA = null; _rBtnB = null;
        _rDemo = null; _tabRects = [];
        var cx = _w / 2;

        dc.setColor(Fa.BG, Fa.BG); dc.clear();
        if (_w == _h) { dc.setColor(Fa.CIRCLE, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }

        if (_page == IV_HOME) { _drawHome(dc); }
        else if (_page == IV_BUILD) { _drawBuild(dc); }
        else if (_page == IV_RES) { _drawResources(dc); }
        else if (_page == IV_DISC) { _drawExplore(dc); }
        else if (_page == IV_COLL) { _drawCollection(dc); }
        else { _drawHistory(dc); }

        _drawTabStrip(dc);
        if (_popup != null) { _drawPopup(dc); }
        if (_welcome) { _drawWelcome(dc); }
        if (_intro) { _drawIntro(dc); }
        if (_event) { _drawEvent(dc); }
    }

    hidden function _pageName(p) {
        if (p == IV_HOME) { return "FARM"; }
        if (p == IV_BUILD) { return "BUILD"; }
        if (p == IV_RES) { return "RESOURCES"; }
        if (p == IV_DISC) { return "EXPLORE"; }
        if (p == IV_COLL) { return "COLLECTION"; }
        return "FARM LOG";
    }
    hidden function _pageColor(p) {
        if (p == IV_BUILD) { return Fa.GOLD; }
        if (p == IV_DISC) { return 0x8CD060; }
        if (p == IV_COLL) { return 0xFFD24A; }
        if (p == IV_HIST) { return 0x9FB0C0; }
        return Fa.ACCENT;
    }

    // ── HOME ────────────────────────────────────────────────────────────────
    // The pixel-art farm IS the screen — the diorama fills nearly the whole
    // page. Only a single slim glanceable ribbon overlays the very bottom.
    hidden function _drawHome(dc) {
        var mx = _w * 25 / 1000; var my = _h * 25 / 1000;
        try { FarmArt.drawBox(dc, _m, mx, my, _w - mx * 2, _h - my * 2, _t, false); } catch (e) {}
        try { _homeOverlay(dc); } catch (e) {}
    }

    // Slim bottom ribbon: hero coins (left) · Lv/Herd (centre) · steps or a
    // pulsing CLAIM pill (right). Tiny pixel font so it never smothers the scene.
    hidden function _homeOverlay(dc) {
        var cx = _w / 2;
        var round = (_w == _h);
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        var gh = 5 * sc;
        var barH = gh + sc * 4; if (barH < 13) { barH = 13; }
        var barW = round ? _w * 62 / 100 : _w * 80 / 100;
        var bx = cx - barW / 2;
        var by = round ? (_h * 85 / 100 - barH / 2) : (_h - barH - _h * 3 / 100);
        var midY = by + barH / 2;
        var gy = midY - gh / 2;
        var pad = barH / 4; if (pad < 3) { pad = 3; }

        dc.setColor(0x08170A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, barW, barH, barH / 3);
        dc.setColor(Fa.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, barW, barH, barH / 3);

        // Left: pixel coin icon + count.
        var coinRows = [".YY.", "YhhY", "YhhY", ".YY."];
        var coinPal = { "Y" => 0xFFD24A, "h" => 0xFFF0B0 };
        var ipx = gh / 4; if (ipx < 2) { ipx = 2; }
        var ix = bx + pad;
        Px.spr(dc, coinRows, coinPal, ix, midY - 2 * ipx, ipx, false);
        Px.gtxt(dc, _fmt(_m.res[Fa.R_COIN]), ix + 4 * ipx + sc, gy, sc, 0xFFE9A0);

        // Centre: LV n  HERD n.
        Px.gtxtC(dc, "LV " + _m.farmLevel() + " HERD " + _m.population, cx, gy, sc, 0xEAF6E6);

        // Right: CLAIM pill when the daily reward is ready, else steps.
        var can = _m.dailyComplete() && !_m.dailyClaimed;
        if (can) {
            var cw = Px.gtxtW("CLAIM", sc) + pad * 2;
            var px = bx + barW - cw - pad;
            var ph = barH - pad; var py = by + pad / 2;
            _rBtnA = [px, py, cw, ph];
            var hot = ((_t / 6) % 2 == 0);
            dc.setColor(hot ? 0xFFD24A : 0xC79A2A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(px, py, cw, ph, ph / 2);
            Px.gtxtC(dc, "CLAIM", px + cw / 2, midY - gh / 2, sc, 0x1A1400);
        } else {
            _rBtnA = null;
            var sstr = _fmt(_steps()) + " ST";
            Px.gtxt(dc, sstr, bx + barW - pad - Px.gtxtW(sstr, sc), gy, sc, 0x8CD060);
        }
    }

    hidden function _steps() {
        var s = 0;
        try { s = Sensors.getStepsToday(); } catch (e) { s = 0; }
        if (s == null || s < 0) { s = 0; }
        return s;
    }
    hidden function _comma(n) {
        if (n < 0) { n = 0; }
        var s = "" + n; var out = ""; var c = 0;
        for (var i = s.length() - 1; i >= 0; i--) {
            out = s.substring(i, i + 1) + out; c++;
            if (c % 3 == 0 && i > 0) { out = "," + out; }
        }
        return out;
    }
    // ── BUILD ─────────────────────────────────────────────────────────────────
    hidden function _drawBuild(dc) {
        _drawListFrame(dc, Fa.B_N, method(:_drawBuildRow));
    }
    function _drawBuildRow(dc, id, x, y, w, rh, sel) {
        var col = Fa.bColor(id);
        var lvl = _m.bLevel[id];
        var unlocked = _m.isUnlocked(id);
        var dim = !unlocked;
        _catIcon(dc, Fa.bCat(id), dim ? 0x2A3A2C : col, x + rh / 2, y + rh / 2, rh / 3);

        var tx = x + rh + 4;
        var nm = Fa.bName(id) + (lvl > 0 ? "  L" + lvl : "");
        _txt(dc, tx, y + rh * 18 / 100, Graphics.FONT_XTINY, dim ? Fa.MUTED : Fa.TEXT, nm, Graphics.TEXT_JUSTIFY_LEFT);

        var sub;
        if (!unlocked) {
            sub = "Explore " + Fa.arName(Fa.bUnlockArea(id));
        } else {
            var c = _m.upgradeCost(id);
            var prod = "";
            var pr = Fa.bProdRes(id);
            if (pr >= 0) { prod = "+" + _fmt(Fa.prodAt(id, lvl + 1)) + Fa.resAbbr(pr).substring(0, 1) + "/h  "; }
            else if (Fa.bPopPer(id) > 0) { prod = "+herd  "; }
            else { prod = "+mult  "; }
            sub = prod + _fmt(c[0]) + "c " + _fmt(c[1]) + "w" + (c[2] > 0 ? " " + _fmt(c[2]) + "g" : "");
        }
        var afford = unlocked && _m.canAfford(_m.upgradeCost(id));
        _txt(dc, tx, y + rh * 60 / 100, Graphics.FONT_XTINY,
             !unlocked ? 0xB46CFF : (afford ? 0x9AE070 : Fa.MUTED), sub, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // ── RESOURCES ───────────────────────────────────────────────────────────
    hidden function _drawResources(dc) {
        var cx = _w / 2;
        var y = _h * 22 / 100; var rowH = _h * 11 / 100;
        var lx = _w * 16 / 100; var rx = _w - _w * 10 / 100;
        for (var i = 0; i < Fa.R_N; i++) {
            var ry = y + i * rowH;
            dc.setColor(Fa.resColor(i), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_w * 11 / 100, ry + rowH * 22 / 100, 5);
            _txt(dc, lx, ry, Graphics.FONT_XTINY, Fa.resColor(i), Fa.resAbbr(i), Graphics.TEXT_JUSTIFY_LEFT);
            _txt(dc, cx + _w * 10 / 100, ry, Graphics.FONT_XTINY, Fa.TEXT, _fmt(_m.res[i]), Graphics.TEXT_JUSTIFY_RIGHT);
            var rate = _m.hourlyRate(i);
            _txt(dc, rx, ry, Graphics.FONT_XTINY, rate > 0 ? 0x9AE070 : Fa.MUTED,
                 (rate > 0 ? "+" + _fmt(rate) : "-") + "/h", Graphics.TEXT_JUSTIFY_RIGHT);
        }
        var yy = y + Fa.R_N * rowH + _h * 2 / 100;
        dc.setColor(0xF0C060, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 11 / 100, yy + rowH * 22 / 100, 5);
        _txt(dc, lx, yy, Graphics.FONT_XTINY, 0xF0C060, "Herd", Graphics.TEXT_JUSTIFY_LEFT);
        _txt(dc, rx, yy, Graphics.FONT_XTINY, Fa.TEXT, _m.population + "/" + _m.popCap(), Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(0xFF9AC0, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w * 11 / 100, yy + rowH + rowH * 22 / 100, 5);
        _txt(dc, lx, yy + rowH, Graphics.FONT_XTINY, 0xFF9AC0, "Guests", Graphics.TEXT_JUSTIFY_LEFT);
        _txt(dc, rx, yy + rowH, Graphics.FONT_XTINY, Fa.TEXT, _m.visitors + "/" + _m.visitorsCap(), Graphics.TEXT_JUSTIFY_RIGHT);

        // Daily challenge card (relocated off HOME so HOME is pure diorama).
        try { _drawDailyCard(dc, yy + rowH * 2 + _h * 2 / 100); } catch (e) {}
    }

    // Compact daily card used on the RESOURCES page. Sets _rBtnA so SELECT/tap
    // claims the reward when it's ready.
    hidden function _drawDailyCard(dc, cardY) {
        var cx = _w / 2;
        var fhX = dc.getFontHeight(Graphics.FONT_XTINY);
        var pad = fhX / 3; if (pad < 2) { pad = 2; }
        var cw = _w * 84 / 100; var cxx = cx - cw / 2;
        var cardH = fhX * 3 + pad * 4;
        if (cardY + cardH > _h * 96 / 100) { cardY = _h * 96 / 100 - cardH; }
        dc.setColor(Fa.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cxx, cardY, cw, cardH, 8);
        _txt(dc, cxx + 10, cardY + pad, Graphics.FONT_XTINY, Fa.GOLD, "DAILY", Graphics.TEXT_JUSTIFY_LEFT);
        _txt(dc, cxx + cw - 10, cardY + pad, Graphics.FONT_XTINY, Fa.MUTED,
             "Streak " + _m.streak + "d", Graphics.TEXT_JUSTIFY_RIGHT);
        _txt(dc, cx, cardY + pad + fhX + pad / 2, Graphics.FONT_XTINY, Fa.TEXT, _m.dailyText(), Graphics.TEXT_JUSTIFY_CENTER);
        var prog = _m.dailyProgress(); var tgt = _m.dailyTarget();
        var barY = cardY + pad + fhX * 2 + pad;
        _bar(dc, cxx + 12, barY, cw - 24, 4, (tgt > 0 ? prog * 100 / tgt : 100), Fa.ACCENT);
        var can = _m.dailyComplete() && !_m.dailyClaimed;
        var pw = cw * 40 / 100; var px = cx - pw / 2;
        var py = barY + 6; var ph = cardY + cardH - py - pad / 2;
        if (ph < fhX) { ph = fhX; }
        _rBtnA = [px, py, pw, ph];
        _button(dc, _rBtnA, _m.dailyClaimed ? "CLAIMED" : "CLAIM", can);
    }

    // ── EXPLORE ─────────────────────────────────────────────────────────────
    hidden function _drawExplore(dc) {
        _drawListFrame(dc, Fa.AR_N, method(:_drawAreaRow));
    }
    function _drawAreaRow(dc, id, x, y, w, rh, sel) {
        var col = Fa.arColor(id);
        var disc = _m.isDiscovered(id);
        dc.setColor(disc ? col : 0x2A3A2C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + rh / 2, y + rh / 2, rh / 3);
        if (disc) {
            dc.setColor(0x0A1E10, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + rh / 2, y + rh / 2, Graphics.FONT_XTINY, "*",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        // Font-metric layout: name on the top line, the progress bar strictly
        // BELOW it (using the real glyph height) so text never sits on the bar.
        var fhX = dc.getFontHeight(Graphics.FONT_XTINY);
        var tx = x + rh + 4;
        _txt(dc, tx, y + 2, Graphics.FONT_XTINY, Fa.TEXT, Fa.arName(id), Graphics.TEXT_JUSTIFY_LEFT);
        if (disc) {
            var b = Fa.arUnlockBuilding(id);
            _txt(dc, tx, y + rh - fhX - 2, Graphics.FONT_XTINY, 0x9AE070,
                 b >= 0 ? "Found - " + Fa.bName(b) : "Found - Prize Ribbon", Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            _txt(dc, x + w - 4, y + 2, Graphics.FONT_XTINY, Fa.MUTED,
                 _m.arProg[id] + "%", Graphics.TEXT_JUSTIFY_RIGHT);
            var bw = w - (tx - x) - 6;
            var barY = y + fhX + 4;
            if (barY + 5 <= y + rh - 2) { _bar(dc, tx, barY, bw, 4, _m.arProg[id], col); }
        }
    }

    // ── COLLECTION (grid) ─────────────────────────────────────────────────────
    hidden function _drawCollection(dc) {
        var cx = _w / 2;
        _txt(dc, cx, _h * 20 / 100, Graphics.FONT_XTINY, 0xFFD24A,
             _m.collectiblesOwned() + " / " + Fa.C_N + " found", Graphics.TEXT_JUSTIFY_CENTER);
        var cols = 3;
        var gx = _w * 18 / 100; var gy = _h * 26 / 100;
        var cw = _w * 64 / 100; var cell = cw / cols;
        for (var i = 0; i < Fa.C_N; i++) {
            var r = i / cols; var c = i % cols;
            var px = gx + c * cell + cell / 2;
            var py = gy + r * cell + cell / 2;
            var owned = _m.hasColl(i);
            var sel = (i == _cur);
            if (sel) {
                dc.setColor(Fa.ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(px, py, cell * 40 / 100);
            }
            dc.setColor(owned ? Fa.cColor(i) : 0x243425, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, cell * 30 / 100);
            if (owned && Fa.cRare(i)) {
                dc.setColor(0xFFF0B0, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, cell * 10 / 100);
            }
            _rows.add([px - cell / 2, py - cell / 2, cell, cell]);
            _rowIds.add(i);
        }
        var name = Fa.cName(_cur) + (_m.hasColl(_cur) ? "" : " (locked)");
        _txt(dc, cx, _h * 84 / 100, Graphics.FONT_XTINY, _m.hasColl(_cur) ? Fa.TEXT : Fa.MUTED, name, Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Fa.GOLD, "Charm " + _m.charmScore(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── HISTORY ─────────────────────────────────────────────────────────────
    hidden function _drawHistory(dc) {
        var cx = _w / 2;
        var lg = _m.history();
        var y = _h * 22 / 100; var step = _h * 10 / 100;
        if (lg.size() == 0) {
            _txt(dc, cx, _h * 45 / 100, Graphics.FONT_XTINY, Fa.MUTED, "No history yet", Graphics.TEXT_JUSTIFY_CENTER);
        }
        for (var i = 0; i < lg.size() && i < 6; i++) {
            var ry = y + i * step;
            dc.setColor(Fa.ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_w * 12 / 100, ry + step / 3, 2);
            _wrap1(dc, _w * 16 / 100, ry, _w * 74 / 100, Graphics.FONT_XTINY, Fa.TEXT, lg[i]);
        }
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Fa.GOLD, _m.milestoneLabel(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Overlays ──────────────────────────────────────────────────────────────
    hidden function _drawWelcome(dc) {
        var cx = _w / 2;
        dc.setColor(0x081408, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) { dc.setColor(Fa.CIRCLE, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }
        _txt(dc, cx, _h * 15 / 100, Graphics.FONT_SMALL, Fa.ACCENT, "WELCOME BACK", Graphics.TEXT_JUSTIFY_CENTER);

        var y = _h * 30 / 100; var step = _h * 8 / 100; var n = 0;
        for (var i = 0; i < Fa.R_N; i++) {
            if (_m.gRes[i] > 0) {
                _txt(dc, cx, y + n * step, Graphics.FONT_TINY, Fa.resColor(i),
                     "+" + _fmt(_m.gRes[i]) + " " + Fa.resName(i), Graphics.TEXT_JUSTIFY_CENTER);
                n++;
            }
        }
        if (_m.gVis > 0) { _txt(dc, cx, y + n * step, Graphics.FONT_TINY, 0xFF9AC0, "+" + _m.gVis + " guests", Graphics.TEXT_JUSTIFY_CENTER); n++; }
        if (_m.gPop > 0) { _txt(dc, cx, y + n * step, Graphics.FONT_TINY, 0xF0C060, "+" + _m.gPop + " animals", Graphics.TEXT_JUSTIFY_CENTER); n++; }
        if (n == 0) { _txt(dc, cx, y, Graphics.FONT_TINY, Fa.MUTED, "Farm is quiet", Graphics.TEXT_JUSTIFY_CENTER); }

        if (_m.newDay) {
            _txt(dc, cx, _h * 82 / 100, Graphics.FONT_XTINY, Fa.GOLD,
                 "Streak " + _m.streak + " day" + (_m.streak == 1 ? "" : "s"), Graphics.TEXT_JUSTIFY_CENTER);
        }
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Fa.MUTED, "tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // First-run explainer: makes STATS = CURRENCY unmistakable.
    hidden function _drawIntro(dc) {
        var cx = _w / 2;
        dc.setColor(0x081408, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) { dc.setColor(Fa.CIRCLE, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }
        try { FarmArt.drawScene(dc, _m, cx, _h * 17 / 100, _h * 8 / 100, _t); } catch (e) {}

        _txt(dc, cx, _h * 32 / 100, Graphics.FONT_SMALL, Fa.GOLD, "STATS = CURRENCY", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 40 / 100, Graphics.FONT_XTINY, Fa.TEXT, "Your steps, activity & sleep", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 455 / 1000, Graphics.FONT_XTINY, Fa.TEXT, "grow the farm - move to earn!", Graphics.TEXT_JUSTIFY_CENTER);

        var y = _h * 56 / 100; var step = _h * 8 / 100;
        _mapLine(dc, cx, y,            0x8CD060, "STEPS", "explore the land");
        _mapLine(dc, cx, y + step,     0xFFC24A, "ACTIVE MIN", "scouting boost");
        _mapLine(dc, cx, y + step * 2, 0x6FB3FF, "SLEEP", "night harvest");

        _txt(dc, cx, _h * 88 / 100, Graphics.FONT_XTINY, Fa.MUTED, "tap to begin", Graphics.TEXT_JUSTIFY_CENTER);
    }
    hidden function _mapLine(dc, cx, y, col, a, b) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - _w * 37 / 100, y + 3, 7, 7);
        _txt(dc, cx - _w * 32 / 100, y, Graphics.FONT_XTINY, col, a, Graphics.TEXT_JUSTIFY_LEFT);
        _txt(dc, cx + _w * 37 / 100, y, Graphics.FONT_XTINY, Fa.TEXT, b, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    hidden function _drawEvent(dc) {
        var cx = _w / 2;
        dc.setColor(0x0A140A, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) { dc.setColor(0x14301A, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }
        var e = _m.pendingEvent;
        _txt(dc, cx, _h * 14 / 100, Graphics.FONT_SMALL, Fa.GOLD, Fa.evTitle(e), Graphics.TEXT_JUSTIFY_CENTER);
        _wrap(dc, cx, _h * 30 / 100, _w * 82 / 100, Graphics.FONT_XTINY, Fa.TEXT, Fa.evBody(e));

        var bw = _w * 60 / 100; var bx = cx - bw / 2; var bh = _h * 13 / 100;
        var y0 = _h * 54 / 100; var gap = _h * 3 / 100;
        _rBtnA = [bx, y0, bw, bh];
        _rBtnB = [bx, y0 + bh + gap, bw, bh];
        var a = (e == Fa.EV_TREASURE) ? "OPEN CRATE" : "TRADE";
        _button(dc, _rBtnA, a, _evChoice == 0);
        _button(dc, _rBtnB, "IGNORE", _evChoice == 1);
    }

    // ── Tab strip (persistent, top) ───────────────────────────────────────────
    hidden function _drawTabStrip(dc) {
        var cx = _w / 2;

        // DEMO badge (top, when active).
        if (_demo) {
            var pulse = ((_t / 8) % 2 == 0);
            var bw = _w * 26 / 100; var bx = cx - bw / 2; var by = _h * 1 / 100; var bh = _h * 7 / 100;
            dc.setColor(pulse ? 0xFFD24A : 0xE0A020, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx, by, bw, bh, bh / 2);
            dc.setColor(0x1A1400, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + bh / 2, Graphics.FONT_XTINY, "DEMO",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Page name — tiny pixel font, shadowed, white on HOME so "FARM" pops
        // over the sky.
        var hsc = _h / 190; if (hsc < 2) { hsc = 2; }
        var hcol = (_page == IV_HOME) ? 0xFFFFFF : _pageColor(_page);
        Px.gshC(dc, _pageName(_page), cx, _h * 7 / 100, hsc, hcol);

        // Chevron edge tap-zones (page prev/next) + glyphs.
        _rPrev = [0, 0, _w * 20 / 100, _h * 22 / 100];
        _rNext = [_w * 80 / 100, 0, _w * 20 / 100, _h * 22 / 100];
        var chy = _h * 11 / 100;
        dc.setColor(Fa.MUTED, Graphics.COLOR_TRANSPARENT);
        var cxl = _w * 7 / 100; var cxr = _w - _w * 7 / 100; var s = _w * 3 / 100;
        dc.fillPolygon([[cxl + s, chy - s], [cxl - s, chy], [cxl + s, chy + s]]);
        dc.fillPolygon([[cxr - s, chy - s], [cxr + s, chy], [cxr - s, chy + s]]);

        // Tappable dots.
        var y = _h * 15 / 100; var gap = _w * 9 / 100;
        var x0 = cx - gap * (IV_PAGES - 1) / 2;
        for (var i = 0; i < IV_PAGES; i++) {
            var dx = x0 + i * gap;
            dc.setColor(i == _page ? _pageColor(_page) : 0x334033, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dx, y, i == _page ? 4 : 2);
            _tabRects.add([dx - gap / 2, _h * 10 / 100, gap, _h * 9 / 100]);
        }
    }

    hidden function _catIcon(dc, cat, col, cx, cy, rad) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        if (cat == 1) {            // CROPS -> sprout
            dc.fillCircle(cx, cy - 1, rad);
            dc.setColor(0x6A3A22, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 1, cy + rad - 2, 2, rad);
        } else if (cat == 2) {     // MARKET -> stall roof
            dc.fillPolygon([[cx, cy - rad], [cx - rad, cy], [cx + rad, cy]]);
        } else if (cat == 3) {     // SPECIAL -> star/diamond
            dc.fillPolygon([[cx, cy - rad], [cx + rad, cy], [cx, cy + rad], [cx - rad, cy]]);
        } else {                   // LIVESTOCK -> animal head (round + ears)
            dc.fillCircle(cx, cy + 1, rad * 8 / 10);
            dc.fillRectangle(cx - rad, cy - rad, rad * 6 / 10, rad * 6 / 10);
            dc.fillRectangle(cx + rad * 4 / 10, cy - rad, rad * 6 / 10, rad * 6 / 10);
        }
    }

    // ── Chrome / helpers ──────────────────────────────────────────────────────
    hidden function _drawListFrame(dc, count, rowFn) {
        var top = _h * 21 / 100;
        var bottom = _h * 92 / 100;
        var rh = _h * 15 / 100;
        var maxRows = (bottom - top) / rh;
        if (maxRows < 1) { maxRows = 1; }
        if (_cur < _scroll) { _scroll = _cur; }
        if (_cur >= _scroll + maxRows) { _scroll = _cur - maxRows + 1; }
        if (_scroll < 0) { _scroll = 0; }

        var x = _w * 10 / 100; var w = _w * 80 / 100;
        for (var vi = 0; vi < maxRows; vi++) {
            var id = _scroll + vi;
            if (id >= count) { break; }
            var y = top + vi * rh;
            var sel = (id == _cur);
            dc.setColor(sel ? Fa.PANEL_HI : Fa.PANEL, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, rh - 3, 6);
            if (sel) { dc.setColor(Fa.ACCENT, Graphics.COLOR_TRANSPARENT); dc.drawRoundedRectangle(x, y, w, rh - 3, 6); }
            rowFn.invoke(dc, id, x + 4, y, w - 8, rh - 3, sel);
            _rows.add([x, y, w, rh - 3]);
            _rowIds.add(id);
        }
    }

    hidden function _button(dc, r, label, hot) {
        dc.setColor(hot ? 0x14401A : Fa.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(hot ? Fa.ACCENT : 0x2A3A2C, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(hot ? 0xD8F6C8 : 0x9FB2A0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(r[0] + r[2] / 2, r[1] + r[3] / 2, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    hidden function _drawPopup(dc) {
        var cx = _w / 2; var pw = _w * 84 / 100; var px = cx - pw / 2;
        var ph = _h * 12 / 100; var py = _h * 44 / 100;
        dc.setColor(0x081408, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, 8);
        dc.setColor(Fa.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, 8);
        _wrap(dc, cx, py + ph / 2 - _h * 3 / 100, pw - 12, Graphics.FONT_XTINY, Fa.TEXT, _popup);
    }
    hidden function _bar(dc, x, y, w, h, pct, col) {
        dc.setColor(Fa.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, h / 2);
        var fw = w * Fa._c(pct, 0, 100) / 100;
        if (fw > 0) {
            if (fw < h) { fw = h; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, fw, h, h / 2);
        }
    }
    hidden function _txt(dc, x, y, f, c, s, j) { dc.setColor(c, Graphics.COLOR_TRANSPARENT); dc.drawText(x, y, f, s, j); }

    hidden function _fmt(n) {
        if (n < 0) { n = 0; }
        if (n >= 1000000) { return (n / 1000000) + "." + ((n / 100000) % 10) + "M"; }
        if (n >= 10000)   { return (n / 1000) + "k"; }
        if (n >= 1000)    { return (n / 1000) + "." + ((n / 100) % 10) + "k"; }
        return "" + n;
    }
    hidden function _wrap(dc, cx, y, maxw, font, col, s) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        if (dc.getTextWidthInPixels(s, font) <= maxw) { dc.drawText(cx, y, font, s, Graphics.TEXT_JUSTIFY_CENTER); return; }
        var words = _split(s); var l1 = ""; var l2 = ""; var i = 0;
        while (i < words.size()) {
            var cand = (l1.length() == 0) ? words[i] : l1 + " " + words[i];
            if (dc.getTextWidthInPixels(cand, font) <= maxw) { l1 = cand; } else { break; }
            i++;
        }
        while (i < words.size()) { l2 = (l2.length() == 0) ? words[i] : l2 + " " + words[i]; i++; }
        var fh = dc.getFontHeight(font);
        dc.drawText(cx, y, font, l1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, y + fh * 85 / 100, font, l2, Graphics.TEXT_JUSTIFY_CENTER);
    }
    hidden function _wrap1(dc, x, y, maxw, font, col, s) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var str = s;
        while (str.length() > 4 && dc.getTextWidthInPixels(str, font) > maxw) {
            str = str.substring(0, str.length() - 2);
        }
        if (!str.equals(s)) { str = str + ".."; }
        dc.drawText(x, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
    }
    hidden function _split(s) {
        var out = []; var cur = "";
        for (var i = 0; i < s.length(); i++) {
            var ch = s.substring(i, i + 1);
            if (ch.equals(" ")) { if (cur.length() > 0) { out.add(cur); cur = ""; } }
            else { cur += ch; }
        }
        if (cur.length() > 0) { out.add(cur); }
        return out;
    }
}
