// ═══════════════════════════════════════════════════════════════════════════
// ColonyView.mc — The SPACE COLONY gameplay view.
//
// A six-screen carousel over one ColonyModel:
//   OVERVIEW · BUILD · EXPLORE · MISSION · TECH · LOG
//
// Navigation is deliberately redundant so it works on EVERY watch + emulator:
//   • TAP a dot in the top tab strip to jump straight to any page.
//   • TAP the big ◀ / ▶ side chevrons to page prev/next.
//   • Physical UP/DOWN move the row cursor on list pages and OVERFLOW into the
//     previous/next page at the ends; on non-list pages they page directly.
//   • SELECT / START activates the focused item (build / upgrade / explore /
//     research / claim). Swipe left/right/up/down still work as a bonus.
//   • BACK saves + exits.
//
// A DEMO fast-track (top-left toggle, or the Demo option) auto-develops the
// colony from an emergency pod to a rich civilisation in ~10-20s for showcase.
// Every auto-action and every draw is guarded so it can never crash.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;

const SV_OVER = 0;
const SV_BLD  = 1;
const SV_EXP  = 2;
const SV_MIS  = 3;
const SV_TECH = 4;
const SV_HIST = 5;
const SV_PAGES = 6;

class ColonyView extends WatchUi.View {
    hidden var _m;
    hidden var _page;
    hidden var _w; hidden var _h;
    hidden var _t; hidden var _timer;
    hidden var _fxOn;

    hidden var _cur;             // list cursor (buildings/explore/tech)
    hidden var _scroll;
    hidden var _popup; hidden var _popupT;
    hidden var _welcome;
    hidden var _event;           // showing a choice event overlay
    hidden var _evChoice;
    hidden var _pendingWelcome;
    hidden var _explain;         // first-run stats-as-currency explainer

    hidden var _demo;            // demo fast-track running
    hidden var _demoT;           // demo sub-tick counter

    hidden var _rows;            // tap rects for list rows [x,y,w,h]
    hidden var _rowIds;          // parallel building/region/tech ids
    hidden var _tabs;            // tap rects for the top tab strip
    hidden var _rBtnA; hidden var _rBtnB;
    hidden var _rPrev; hidden var _rNext; hidden var _rDemo;

    function initialize() {
        View.initialize();
        _m = new ColonyModel();
        _page = SV_OVER; _w = 0; _h = 0; _t = 0; _timer = null;
        _cur = 0; _scroll = 0;
        _popup = null; _popupT = 0;
        _welcome = false; _event = false; _evChoice = 0; _pendingWelcome = false;
        _explain = false;
        _demo = false; _demoT = 0;
        _rows = []; _rowIds = []; _tabs = [];
        _rBtnA = null; _rBtnB = null; _rPrev = null; _rNext = null; _rDemo = null;
        _loadFx();
        _loadDemo();

        try { _m.ensureStart(); } catch (e) {}
        try { _m.collectOffline(); } catch (e) {}
        _pendingWelcome = _hasGains() || _m.newDay || _m.gEvent != Sc.EV_NONE;
        // Only surface the choice overlay for genuine choice events.
        if (_m.pendingEvent != Sc.EV_NONE && Sc.evHasChoice(_m.pendingEvent)) {
            _event = true; _evChoice = 0;
        } else {
            _m.pendingEvent = Sc.EV_NONE;
            if (_pendingWelcome) { _welcome = true; }
        }
        try { _m.submitScores(); } catch (e) {}
        try { if (Application.Storage.getValue("sc_expl_seen") == null) { _explain = true; } } catch (e) {}
    }

    function model() { return _m; }

    hidden function _hasGains() {
        try {
            for (var i = 0; i < Sc.R_N; i++) { if (_m.gRes[i] > 0) { return true; } }
            return _m.gPop > 0;
        } catch (e) { return false; }
    }

    hidden function _loadFx() {
        _fxOn = true;
        try { var v = Application.Storage.getValue("sc_fx"); if (v instanceof Lang.Number) { _fxOn = (v == 0); } } catch (e) {}
    }
    hidden function _loadDemo() {
        _demo = false;
        if (!Sc.SHOW_DEMO) { return; }   // showcase-only; never active for users
        try { var v = Application.Storage.getValue("sc_demo"); if (v instanceof Lang.Number) { _demo = (v == 1); } } catch (e) {}
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
        if (_demo && !_event && !_welcome) {
            _demoT += 1;
            if (_demoT >= 12) { _demoT = 0; _demoStep(); }
        }
        WatchUi.requestUpdate();
    }

    // ── Demo fast-track (all actions guarded; uses existing model methods) ─────
    hidden function _demoStep() {
        try {
            // Generous resource pulse (bounded so it can never overflow).
            for (var i = 0; i < Sc.R_N; i++) {
                if (_m.res[i] < 900000000) { _m.res[i] += 600; }
            }
            if (_m.population < _m.popCap()) { _m.population += 1; }
            // Push exploration so advanced buildings unlock quickly.
            for (var k = 0; k < 2; k++) {
                var rg = _demoNextRegion();
                if (rg >= 0) { _m.explore(rg); }
            }
            // Build / upgrade the best affordable structure (prefer new builds).
            _demoBuild();
            // Research the cheapest affordable tech.
            _demoResearch();
            try { _m.save(); } catch (e2) {}
        } catch (e) {}
        WatchUi.requestUpdate();
    }
    hidden function _demoNextRegion() {
        for (var i = 0; i < Sc.RG_N; i++) { if (!_m.isDiscovered(i)) { return i; } }
        return -1;
    }
    hidden function _demoBuild() {
        var bestId = -1; var bestScore = 0;
        for (var i = 0; i < Sc.B_N; i++) {
            if (!_m.isUnlocked(i)) { continue; }
            var c = _m.upgradeCost(i);
            if (!_m.canAfford(c)) { continue; }
            var score = c[0] + c[1] + c[2];
            if (_m.bLevel[i] == 0) { score -= 1000000; }   // prioritise NEW builds
            if (bestId < 0 || score < bestScore) { bestId = i; bestScore = score; }
        }
        if (bestId >= 0) { _m.upgrade(bestId); }
    }
    hidden function _demoResearch() {
        for (var t = 0; t < Sc.T_N; t++) {
            if (_m.res[Sc.R_SCI] >= _m.techCost(t)) { _m.research(t); return; }
        }
    }
    function toggleDemo() {
        _demo = !_demo;
        try { Application.Storage.setValue("sc_demo", _demo ? 1 : 0); } catch (e) {}
        if (_demo) { _page = SV_OVER; _cur = 0; _scroll = 0; _demoT = 0; }
        _tone(_demo ? 4 : 0); _vibe(30, 40);
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
        if (_event) { return false; }   // events must be answered
        if (_welcome) { _welcome = false; WatchUi.requestUpdate(); return true; }
        if (_explain) { _explain = false; _markExplainSeen(); WatchUi.requestUpdate(); return true; }
        return false;
    }
    hidden function _markExplainSeen() {
        try { Application.Storage.setValue("sc_expl_seen", 1); } catch (e) {}
    }
    function pageMove(d) {
        if (_event) { return; }
        if (_dismiss()) { return; }
        _page = ((_page + d) % SV_PAGES + SV_PAGES) % SV_PAGES;
        _cur = 0; _scroll = 0;
        _tone(0); _vibe(12, 18);
        WatchUi.requestUpdate();
    }
    function _listCount() {
        if (_page == SV_BLD)  { return Sc.B_N; }
        if (_page == SV_EXP)  { return Sc.RG_N; }
        if (_page == SV_TECH) { return Sc.T_N; }
        return 0;
    }
    // UP/DOWN: move the cursor on list pages and OVERFLOW into the neighbouring
    // page at the ends; page directly on non-list pages.
    function cursorMove(d) {
        if (_event) { _evChoice = (_evChoice + 1) % 2; _tone(0); WatchUi.requestUpdate(); return; }
        if (_dismiss()) { return; }
        var n = _listCount();
        if (n > 0) {
            var nc = _cur + d;
            if (nc < 0) { pageMove(-1); return; }
            if (nc >= n) { pageMove(1); return; }
            _cur = nc; _tone(0); _vibe(8, 12); WatchUi.requestUpdate();
            return;
        }
        pageMove(d);
    }
    function activate() {
        if (_event) { _resolveEvent(_evChoice); return; }
        if (_dismiss()) { return; }
        try {
            if (_page == SV_BLD)  { _do(_m.upgrade(_cur)); return; }
            if (_page == SV_EXP)  { _do(_m.explore(_cur)); return; }
            if (_page == SV_TECH) { _do(_m.research(_cur)); return; }
            if (_page == SV_MIS)  { _doClaim(); return; }
            if (_page == SV_OVER) { setPage(SV_BLD); return; }
        } catch (e) {}
    }
    function setPage(p) {
        if (_event || _dismiss()) { return; }
        _page = ((p % SV_PAGES) + SV_PAGES) % SV_PAGES;
        _cur = 0; _scroll = 0;
        _tone(0); _vibe(10, 15);
        WatchUi.requestUpdate();
    }

    hidden function _do(res) {
        if (res == null) { res = ""; }
        _popup = res; _popupT = 30;
        var bad = (res.length() >= 4 && res.substring(0, 4).equals("Need"))
               || (res.length() >= 6 && res.substring(0, 6).equals("Locked"));
        if (bad) { _tone(2); _vibe(30, 40); } else { _tone(4); _vibe(35, 45); }
        WatchUi.requestUpdate();
    }
    hidden function _doClaim() {
        try {
            if (_m.claimDaily()) { _popup = "Mission reward claimed!"; _popupT = 34; _tone(4); _vibe(60, 120); }
            else if (_m.dailyClaimed) { _popup = "Already claimed today"; _popupT = 24; }
            else { _popup = "Mission not complete"; _popupT = 24; _tone(2); }
        } catch (e) {}
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
        if (_welcome) { _dismiss(); return true; }
        if (_explain) { _dismiss(); return true; }
        if (_inR(x, y, _rDemo)) { toggleDemo(); return true; }
        if (_inR(x, y, _rPrev)) { pageMove(-1); return true; }
        if (_inR(x, y, _rNext)) { pageMove(1);  return true; }
        for (var i = 0; i < _tabs.size(); i++) {
            if (_inR(x, y, _tabs[i])) { setPage(i); return true; }
        }
        for (var r = 0; r < _rows.size(); r++) {
            if (_inR(x, y, _rows[r])) { _cur = _rowIds[r]; activate(); return true; }
        }
        if (_inR(x, y, _rBtnA)) { activate(); return true; }
        return true;
    }
    hidden function _inR(x, y, r) {
        if (r == null) { return false; }
        return x >= r[0] && x < r[0] + r[2] && y >= r[1] && y < r[1] + r[3];
    }

    // ═══ Rendering ═══════════════════════════════════════════════════════════
    function onUpdate(dc) {
        try { _draw(dc); } catch (e) { try { dc.setColor(Sc.BG, Sc.BG); dc.clear(); } catch (e2) {} }
    }
    hidden function _draw(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        _rows = []; _rowIds = []; _tabs = [];
        _rBtnA = null; _rBtnB = null;
        var cx = _w / 2;

        dc.setColor(Sc.BG, Sc.BG); dc.clear();
        if (_w == _h) { dc.setColor(Sc.CIRCLE, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }

        if (_page == SV_OVER) { _drawOverview(dc); }
        else if (_page == SV_BLD) { _drawBuildings(dc); }
        else if (_page == SV_EXP) { _drawExplore(dc); }
        else if (_page == SV_MIS) { _drawMissions(dc); }
        else if (_page == SV_TECH) { _drawTech(dc); }
        else { _drawHistory(dc); }

        _drawTabStrip(dc);
        if (_popup != null) { _drawPopup(dc); }
        if (_welcome) { _drawWelcome(dc); }
        else if (_explain) { _drawExplain(dc); }
        if (_event) { _drawEvent(dc); }
    }

    // ── Top tab strip: page name + tappable dots + side chevrons + DEMO ───────
    hidden function _pageName(p) {
        var a = ["OVERVIEW", "BUILD", "EXPLORE", "MISSION", "TECH", "LOG"];
        return a[Sc._c(p, 0, SV_PAGES - 1)];
    }
    hidden function _pageColor(p) {
        var a = [Sc.ACCENT, 0xFFC24A, 0xE0663A, Sc.GOLD, 0x4CE0C0, 0x9FB0C0];
        return a[Sc._c(p, 0, SV_PAGES - 1)];
    }
    hidden function _drawTabStrip(dc) {
        var cx = _w / 2;
        var col = _pageColor(_page);

        // Page name — tiny pixel font (drastically smaller than the old
        // FONT_TINY), shadowed, and white on OVERVIEW so it never blends into
        // the bright full-screen diorama.
        var hsc = _h / 190; if (hsc < 2) { hsc = 2; }
        var hcol = (_page == SV_OVER) ? 0xFFFFFF : col;
        Px.gshC(dc, _pageName(_page), cx, _h * 7 / 100, hsc, hcol);

        // Tappable dots.
        var y = _h * 16 / 100;
        var gap = _w * 6 / 100;
        var x0 = cx - gap * (SV_PAGES - 1) / 2;
        for (var i = 0; i < SV_PAGES; i++) {
            var dx = x0 + i * gap;
            var on = (i == _page);
            dc.setColor(on ? col : 0x2A3442, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dx, y, on ? 4 : 3);
            if (on) { dc.setColor(0x081018, Graphics.COLOR_TRANSPARENT); dc.fillCircle(dx, y, 1); }
            _tabs.add([dx - gap / 2, y - _h * 6 / 100, gap, _h * 12 / 100]);
        }

        // Side chevron tap zones (page prev/next).
        _rPrev = [0, _h * 24 / 100, _w * 10 / 100, _h * 52 / 100];
        _rNext = [_w * 90 / 100, _h * 24 / 100, _w * 10 / 100, _h * 52 / 100];
        var my = _h * 50 / 100;
        dc.setColor(0x33445A, Graphics.COLOR_TRANSPARENT);
        var lx = _w * 3 / 100;
        dc.fillPolygon([[lx + 9, my - 10], [lx + 9, my + 10], [lx - 1, my]]);
        var rx = _w * 97 / 100;
        dc.fillPolygon([[rx - 9, my - 10], [rx - 9, my + 10], [rx + 1, my]]);

        _drawDemoBtn(dc);
    }
    hidden function _drawDemoBtn(dc) {
        // DEMO is a showcase-only fast-track — hidden from users in shipped
        // builds. When hidden, draw nothing and keep the hit-rect null.
        if (!Sc.SHOW_DEMO) { _rDemo = null; return; }
        if (_demo) {
            var pulse = ((_t / 5) % 2) == 0;
            dc.setColor(pulse ? 0x33E07A : 0x1E7A46, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(_w * 2 / 100, _h * 3 / 100, _w * 26 / 100, _h * 9 / 100, 5);
            dc.setColor(0x04220F, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w * 15 / 100, _h * 7 / 100 + 1, Graphics.FONT_XTINY, "DEMO",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            _rDemo = [0, 0, _w * 30 / 100, _h * 14 / 100];
            // Animated showcase border.
            dc.setColor(0x33E07A, Graphics.COLOR_TRANSPARENT);
            if (_w == _h) { dc.drawCircle(_w / 2, _h / 2, _w / 2 - 2); }
            else { dc.drawRectangle(1, 1, _w - 2, _h - 2); }
        } else {
            var bcx = _w * 9 / 100; var bcy = _h * 7 / 100; var r = _h * 5 / 100;
            dc.setColor(Sc.PANEL_HI, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bcx, bcy, r);
            dc.setColor(0x2A3A4A, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(bcx, bcy, r);
            dc.setColor(Sc.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bcx, bcy + 1, Graphics.FONT_XTINY, "D",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            _rDemo = [0, 0, _w * 20 / 100, _h * 14 / 100];
        }
    }

    // ── OVERVIEW — the pixel-art colony IS the screen ────────────────────────
    // The diorama fills the whole watch so the player can watch their colony
    // live. Every number/action (resources, tech, missions, stats) lives on
    // the sibling pages; the overview keeps only ONE slim glanceable ribbon at
    // the very bottom (mirrors ISLAND's _drawHome/_homeOverlay).
    hidden function _drawOverview(dc) {
        var mx = _w * 25 / 1000; var my = _h * 25 / 1000;
        try { ColonyArt.drawPixelScene(dc, _m, mx, my, _w - mx * 2, _h - my * 2, _t); } catch (e) {}
        try { _drawMilestoneLabel(dc); } catch (e) {}
        try { _overviewOverlay(dc); } catch (e) {}
    }

    // Small milestone subtitle under the tab title. Rendered in the tiny pixel
    // font (smaller than the header), bright gold, and shadowed so it stays
    // clearly readable over the bright full-screen diorama — the old FONT_XTINY
    // gold text blended into the scene and was effectively invisible.
    hidden function _drawMilestoneLabel(dc) {
        var cx = _w / 2;
        var ssc = _h / 260; if (ssc < 2) { ssc = 2; }
        var s = "X-01 - " + _m.milestoneLabel();
        Px.gshC(dc, s, cx, _h * 20 / 100, ssc, 0xFFE9A0);
    }

    // Slim bottom ribbon on a dark rounded scrim, rendered entirely in the tiny
    // pixel font so it stays crisp & bright and never smothers the diorama.
    // Layout mirrors ISLAND's _homeOverlay exactly: hero Credits (pixel chip +
    // count) LEFT · "CIV n POP p" CENTRE · Energy secondary RIGHT — laid out
    // with real gaps so the values can never collide.
    hidden function _overviewOverlay(dc) {
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

        dc.setColor(0x04101A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, barW, barH, barH / 3);
        dc.setColor(Sc.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, barW, barH, barH / 3);

        // Left: pixel credit chip + count.
        var creRows = [".YY.", "YhhY", "YhhY", ".YY."];
        var crePal = { "Y" => Sc.resColor(Sc.R_CRE), "h" => 0xEAFFD8 };
        var ipx = gh / 4; if (ipx < 2) { ipx = 2; }
        var ix = bx + pad;
        try { Px.spr(dc, creRows, crePal, ix, midY - 2 * ipx, ipx, false); } catch (e) {}
        Px.gtxt(dc, _fmt(_m.res[Sc.R_CRE]), ix + 4 * ipx + sc, gy, sc, 0xCFF6C0);

        // Centre: civilisation level + population.
        Px.gtxtC(dc, "CIV " + _m.civLevel() + " POP " + _m.population, cx, gy, sc, 0xEAF2FF);

        // Right: Energy secondary stat, right-aligned inside the padding.
        var estr = _fmt(_m.res[Sc.R_NRG]) + " E";
        Px.gtxt(dc, estr, bx + barW - pad - Px.gtxtW(estr, sc), gy, sc, Sc.resColor(Sc.R_NRG));
    }

    // Compact one-line resource readout used at the top of the BUILD page — the
    // full stockpile (Energy/Minerals/Water/Science/Credits) is surfaced here,
    // where it's spent, now that the overview is pure diorama.
    hidden function _drawResBar(dc, y) {
        var round = (_w == _h);
        var x0 = round ? _w * 12 / 100 : _w * 6 / 100;
        var totw = round ? _w * 76 / 100 : _w * 88 / 100;
        var cw = totw / Sc.R_N;
        var sq = _h * 3 / 100; if (sq < 4) { sq = 4; }
        var midY = y + sq / 2;
        for (var i = 0; i < Sc.R_N; i++) {
            var cxx = x0 + cw * i;
            dc.setColor(Sc.resColor(i), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cxx, y, sq, sq);
            dc.setColor(Sc.TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cxx + sq + 2, midY, Graphics.FONT_XTINY, _fmt(_m.res[i]),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ── BUILD ─────────────────────────────────────────────────────────────────
    hidden function _drawBuildings(dc) {
        try { _drawResBar(dc, _h * 20 / 100); } catch (e) {}
        _drawListFrame(dc, Sc.B_N, method(:_drawBuildingRow), _h * 27 / 100);
    }
    function _drawBuildingRow(dc, id, x, y, w, rh, sel) {
        var col = Sc.bColor(id);
        var lvl = _m.bLevel[id];
        var unlocked = _m.isUnlocked(id);
        var dim = !unlocked;

        // Icon chip.
        dc.setColor(dim ? 0x2A3442 : Sc.bColorDark(id), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y + rh * 12 / 100, rh * 76 / 100, rh * 76 / 100, 4);
        dc.setColor(dim ? 0x3A4656 : col, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + 2, y + rh * 12 / 100 + 2, rh * 76 / 100 - 4, rh * 76 / 100 - 4, 3);
        dc.setColor(dim ? Sc.MUTED : 0x06110E, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + rh * 38 / 100, y + rh / 2, Graphics.FONT_XTINY, Sc.bGlyph(id),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Reserve a right-hand column for the level number + pip bar so the
        // name/cost labels can never touch it.
        var barLeft = (unlocked && lvl > 0) ? _drawLevelCol(dc, x, y, w, rh, lvl, col) : (x + w);

        var tx = x + rh + 4;
        var nameW = barLeft - tx - 3; if (nameW < 8) { nameW = 8; }
        _wrap1(dc, tx, y + rh * 16 / 100, nameW, Graphics.FONT_XTINY,
               dim ? Sc.MUTED : Sc.TEXT, Sc.bName(id));

        var sub;
        if (!unlocked) {
            sub = "Explore " + Sc.rgName(Sc.bUnlockRegion(id));
        } else {
            var c = _m.upgradeCost(id);
            var prod = "";
            var pr = Sc.bProdRes(id);
            if (pr >= 0) { prod = "+" + _fmt(Sc.prodAt(id, lvl + 1)) + Sc.resAbbr(pr) + "  "; }
            sub = prod + _fmt(c[0]) + "M " + _fmt(c[1]) + "E" + (c[2] > 0 ? " " + _fmt(c[2]) + "S" : "");
        }
        var afford = unlocked && _m.canAfford(_m.upgradeCost(id));
        _wrap1(dc, tx, y + rh * 60 / 100, nameW, Graphics.FONT_XTINY,
               !unlocked ? 0xB46CFF : (afford ? 0x6FE08A : Sc.MUTED), sub);
    }

    // Draw the level number + a pip bar flush against the row's right padding
    // and return the left edge of this reserved column (labels must end before
    // it). Pips run leftward from the right edge; the "Ln" label sits above.
    hidden function _drawLevelCol(dc, x, y, w, rh, lvl, col) {
        var right = x + w - 3;
        var barLeft = x + w - 34;
        var pipN = lvl > 6 ? 6 : lvl;
        var pipY = y + rh * 54 / 100;
        for (var p = 0; p < pipN; p++) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(right - 3 - p * 5, pipY, 3, 6);
        }
        _txt(dc, right, y + rh * 12 / 100, Graphics.FONT_XTINY, col, "L" + lvl, Graphics.TEXT_JUSTIFY_RIGHT);
        return barLeft;
    }

    // ── EXPLORE ─────────────────────────────────────────────────────────────
    hidden function _drawExplore(dc) {
        _drawListFrame(dc, Sc.RG_N, method(:_drawRegionRow), _h * 22 / 100);
    }
    function _drawRegionRow(dc, id, x, y, w, rh, sel) {
        var col = Sc.rgColor(id);
        var disc = _m.isDiscovered(id);
        dc.setColor(disc ? col : 0x2A3442, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + rh * 38 / 100, y + rh / 2, rh / 3);
        if (disc) {
            dc.setColor(0x06110E, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + rh * 38 / 100, y + rh / 2, Graphics.FONT_XTINY, "+",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        var tx = x + rh + 4;
        _txt(dc, tx, y + rh * 16 / 100, Graphics.FONT_XTINY, Sc.TEXT, Sc.rgName(id), Graphics.TEXT_JUSTIFY_LEFT);
        if (disc) {
            _txt(dc, tx, y + rh * 60 / 100, Graphics.FONT_XTINY, 0x6FE08A,
                 "Mapped - " + Sc.bName(Sc.rgUnlockBuilding(id)), Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            var bw = w - (tx - x) - 6;
            _bar(dc, tx, y + rh * 58 / 100, bw, 6, _m.rgProg[id], col);
            _txt(dc, x + w - 4, y + rh * 16 / 100, Graphics.FONT_XTINY, Sc.MUTED,
                 _m.rgProg[id] + "%", Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    // ── TECH ────────────────────────────────────────────────────────────────
    hidden function _drawTech(dc) {
        _drawListFrame(dc, Sc.T_N, method(:_drawTechRow), _h * 22 / 100);
    }
    function _drawTechRow(dc, id, x, y, w, rh, sel) {
        var lvl = _m.tech[id];
        dc.setColor(0x4CE0C0, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y + rh * 12 / 100, rh * 76 / 100, rh * 76 / 100, 4);
        dc.setColor(0x06110E, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + rh * 38 / 100, y + rh / 2, Graphics.FONT_XTINY, "T",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Level number + pip bar live in the reserved right-hand column.
        var barLeft = (lvl > 0) ? _drawLevelCol(dc, x, y, w, rh, lvl, 0x4CE0C0) : (x + w);
        var tx = x + rh + 4;
        var nameW = barLeft - tx - 3; if (nameW < 8) { nameW = 8; }
        _wrap1(dc, tx, y + rh * 16 / 100, nameW, Graphics.FONT_XTINY, Sc.TEXT, Sc.tName(id));

        var c = _m.techCost(id);
        var afford = _m.res[Sc.R_SCI] >= c;
        _wrap1(dc, tx, y + rh * 60 / 100, nameW, Graphics.FONT_XTINY, afford ? 0x6FE08A : Sc.MUTED,
               Sc.tDesc(id) + "  " + _fmt(c) + "S");
    }

    // Shared scrolling list frame with a selectable cursor.
    hidden function _drawListFrame(dc, count, rowFn, top) {
        var bottom = _h * 94 / 100;
        var rh = _h * 17 / 100;
        var maxRows = (bottom - top) / rh;
        if (maxRows < 1) { maxRows = 1; }
        if (_cur < _scroll) { _scroll = _cur; }
        if (_cur >= _scroll + maxRows) { _scroll = _cur - maxRows + 1; }
        if (_scroll < 0) { _scroll = 0; }

        var x = _w * 11 / 100;
        var w = _w * 78 / 100;
        for (var vi = 0; vi < maxRows; vi++) {
            var id = _scroll + vi;
            if (id >= count) { break; }
            var y = top + vi * rh;
            var sel = (id == _cur);
            dc.setColor(sel ? Sc.PANEL_HI : Sc.PANEL, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, rh - 4, 6);
            if (sel) {
                dc.setColor(Sc.ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(x, y, w, rh - 4, 6);
            }
            rowFn.invoke(dc, id, x + 5, y, w - 10, rh - 4, sel);
            _rows.add([x, y, w, rh - 4]);
            _rowIds.add(id);
        }
        // Scroll hint arrows if the list overflows.
        if (_scroll + maxRows < count) {
            dc.setColor(Sc.MUTED, Graphics.COLOR_TRANSPARENT);
            var ax = _w / 2;
            dc.fillPolygon([[ax - 5, bottom - 2], [ax + 5, bottom - 2], [ax, bottom + 4]]);
        }
    }

    // ── MISSION ─────────────────────────────────────────────────────────────
    hidden function _drawMissions(dc) {
        var cx = _w / 2;
        _wrap(dc, cx, _h * 24 / 100, _w * 80 / 100, Graphics.FONT_TINY, Sc.TEXT, _m.dailyText());

        var prog = _m.dailyProgress(); var tgt = _m.dailyTarget();
        var bw = _w * 62 / 100; var bx = cx - bw / 2; var by = _h * 44 / 100;
        _bar(dc, bx, by, bw, 10, (tgt > 0 ? prog * 100 / tgt : 100), Sc.ACCENT);
        _txt(dc, cx, by + _h * 6 / 100, Graphics.FONT_XTINY, Sc.MUTED, prog + " / " + tgt, Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, by + _h * 13 / 100, Graphics.FONT_XTINY, Sc.GOLD, _m.dailyRewardText(), Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, by + _h * 20 / 100, Graphics.FONT_XTINY, Sc.TEXT,
             "Streak " + _m.streak + "d" + _mileTag(), Graphics.TEXT_JUSTIFY_CENTER);

        var bwr = _w * 46 / 100; var bxr = cx - bwr / 2; var byr = _h * 82 / 100; var bhr = _h * 12 / 100;
        _rBtnA = [bxr, byr, bwr, bhr];
        var can = _m.dailyComplete() && !_m.dailyClaimed;
        _button(dc, _rBtnA, _m.dailyClaimed ? "CLAIMED" : "CLAIM", can);
    }
    hidden function _mileTag() {
        var d = _m.daysAlive();
        if (d >= 100) { return "  D100!"; }
        if (d >= 30) { return "  D30!"; }
        if (d >= 7) { return "  D7!"; }
        return "";
    }

    // ── LOG ─────────────────────────────────────────────────────────────────
    hidden function _drawHistory(dc) {
        var cx = _w / 2;
        var lg = _m.history();
        var y = _h * 24 / 100; var step = _h * 10 / 100;
        if (lg.size() == 0) {
            _txt(dc, cx, _h * 45 / 100, Graphics.FONT_XTINY, Sc.MUTED, "No events yet", Graphics.TEXT_JUSTIFY_CENTER);
        }
        for (var i = 0; i < lg.size() && i < 6; i++) {
            var ry = y + i * step;
            dc.setColor(Sc.ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_w * 13 / 100, ry + step / 3, 2);
            _wrap1(dc, _w * 17 / 100, ry, _w * 72 / 100, Graphics.FONT_XTINY, Sc.TEXT, lg[i]);
        }
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Sc.GOLD, _m.milestoneLabel(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Overlays ──────────────────────────────────────────────────────────────
    hidden function _drawWelcome(dc) {
        var cx = _w / 2;
        dc.setColor(0x040609, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) { dc.setColor(Sc.CIRCLE, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }
        _txt(dc, cx, _h * 13 / 100, Graphics.FONT_SMALL, Sc.ACCENT, "WELCOME BACK", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 23 / 100, Graphics.FONT_XTINY, Sc.MUTED, "COMMANDER", Graphics.TEXT_JUSTIFY_CENTER);

        var y = _h * 33 / 100; var step = _h * 8 / 100; var n = 0;
        for (var i = 0; i < Sc.R_N; i++) {
            if (_m.gRes[i] > 0) {
                _txt(dc, cx, y + n * step, Graphics.FONT_TINY, Sc.resColor(i),
                     "+" + _fmt(_m.gRes[i]) + " " + Sc.resName(i), Graphics.TEXT_JUSTIFY_CENTER);
                n++;
            }
        }
        if (_m.gPop > 0) { _txt(dc, cx, y + n * step, Graphics.FONT_TINY, 0x6FB3FF, "+" + _m.gPop + " colonists", Graphics.TEXT_JUSTIFY_CENTER); n++; }
        if (n == 0) { _txt(dc, cx, y, Graphics.FONT_TINY, Sc.MUTED, "Colony steady", Graphics.TEXT_JUSTIFY_CENTER); }

        if (_m.newDay) {
            _txt(dc, cx, _h * 82 / 100, Graphics.FONT_XTINY, Sc.GOLD,
                 "Streak " + _m.streak + " day" + (_m.streak == 1 ? "" : "s"), Graphics.TEXT_JUSTIFY_CENTER);
        }
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Sc.MUTED, "tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // First-run pixel-styled explainer: your body stats are the fuel.
    hidden function _drawExplain(dc) {
        var cx = _w / 2;
        dc.setColor(0x04070C, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) { dc.setColor(Sc.CIRCLE, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }

        _txt(dc, cx, _h * 12 / 100, Graphics.FONT_SMALL, Sc.GOLD, "STATS = FUEL", Graphics.TEXT_JUSTIFY_CENTER);

        // Little pixel motif: footsteps -> arrow -> glowing dome.
        try {
            var px = _w / 34; if (px < 4) { px = 4; }
            var pal = { "b" => 0x7FC8FF, "W" => 0xF2F6FF, "y" => 0xFFE79A, "G" => 0x3E4A5C, "o" => 0xFFA33A };
            var my = _h * 30 / 100;
            dc.setColor(0xFFA33A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - px * 6, my, px, px);
            dc.fillRectangle(cx - px * 6 + px + 1, my + px + 1, px, px);
            var dome = ["..bbb..", ".bWbbb.", "bbbbbbb", "GyGyGyG"];
            Px.spr(dc, dome, pal, cx + px * 2, my - px, px, false);
            dc.setColor(Sc.ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - px, my + px], [cx + px, my + px * 3 / 2], [cx - px, my + px * 2]]);
        } catch (e) {}

        _wrap(dc, cx, _h * 52 / 100, _w * 82 / 100, Graphics.FONT_XTINY, Sc.TEXT,
              "Your steps & activity are the currency - move to expand your colony.");
        _txt(dc, cx, _h * 74 / 100, Graphics.FONT_XTINY, Sc.MUTED,
             "steps map the planet", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 80 / 100, Graphics.FONT_XTINY, Sc.MUTED,
             "activity fuels expeditions", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Sc.ACCENT, "tap to begin", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawEvent(dc) {
        var cx = _w / 2;
        dc.setColor(0x0A0710, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) { dc.setColor(0x140C1E, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }
        var e = _m.pendingEvent;
        _txt(dc, cx, _h * 14 / 100, Graphics.FONT_SMALL, 0xB46CFF, Sc.evTitle(e), Graphics.TEXT_JUSTIFY_CENTER);
        _wrap(dc, cx, _h * 30 / 100, _w * 82 / 100, Graphics.FONT_XTINY, Sc.TEXT, Sc.evBody(e));

        var bw = _w * 60 / 100; var bx = cx - bw / 2; var bh = _h * 13 / 100;
        var y0 = _h * 54 / 100; var gap = _h * 3 / 100;
        _rBtnA = [bx, y0, bw, bh];
        _rBtnB = [bx, y0 + bh + gap, bw, bh];
        var a = (e == Sc.EV_LOST) ? "SEND RESCUE" : "INVESTIGATE";
        _button(dc, _rBtnA, a, _evChoice == 0);
        _button(dc, _rBtnB, "IGNORE", _evChoice == 1);
    }

    // ── Chrome / helpers ──────────────────────────────────────────────────────
    hidden function _button(dc, r, label, hot) {
        dc.setColor(hot ? 0x0E2A38 : Sc.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(hot ? Sc.ACCENT : 0x2A3A4A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(hot ? 0xCDEEFF : 0x9FB2C4, Graphics.COLOR_TRANSPARENT);
        dc.drawText(r[0] + r[2] / 2, r[1] + r[3] / 2, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    hidden function _drawPopup(dc) {
        var cx = _w / 2; var pw = _w * 84 / 100; var px = cx - pw / 2;
        var ph = _h * 12 / 100; var py = _h * 71 / 100;
        dc.setColor(0x081018, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, 8);
        dc.setColor(Sc.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, 8);
        _wrap(dc, cx, py + ph / 2 - _h * 3 / 100, pw - 12, Graphics.FONT_XTINY, Sc.TEXT, _popup);
    }
    hidden function _bar(dc, x, y, w, h, pct, col) {
        dc.setColor(Sc.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, h / 2);
        var fw = w * Sc._c(pct, 0, 100) / 100;
        if (fw > 0) {
            if (fw < h) { fw = h; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, fw, h, h / 2);
        }
    }
    hidden function _txt(dc, x, y, f, c, s, j) { dc.setColor(c, Graphics.COLOR_TRANSPARENT); dc.drawText(x, y, f, s, j); }

    // ── Numbers / text ─────────────────────────────────────────────────────────
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
    // Single-line clamp for the log rows (truncate with ellipsis).
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
