// ═══════════════════════════════════════════════════════════════════════════
// MineView.mc — The BITOCHI MINES gameplay view.
//
// A six-screen carousel over one MineModel:
//   OVERVIEW · DIG · UPGRADE · COLLECT · DAILY · LOG
//
// NAVIGATION (fully redundant — works by TAP or by physical buttons):
//   • A persistent TAB STRIP at the top shows the current page name plus one
//     tappable dot per page; tapping a dot jumps straight to that page.
//   • Large ◀ / ▶ chevron tap zones flank the screen edges to page prev/next.
//   • Physical UP/DOWN move the cursor inside list/grid pages and OVERFLOW into
//     the neighbouring page at the ends (top-row UP → prev page, bottom-row
//     DOWN → next page). On non-list pages UP/DOWN change the page directly.
//   • SELECT/ENTER activates the focused item (dig / upgrade / claim / toggle).
//   • Swipe + the page buttons still work as a bonus. BACK saves + exits.
//
// DEMO MODE: the OPTIONS menu "Demo Mode" toggle fast-tracks the mine — every
// ~0.8s it auto-descends, grants resources and buys the best affordable upgrade
// so the scene visibly deepens and fills within ~10-20s. A pulsing border + name
// prefix mark it active. Every auto-action is fully guarded.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;

const MV_OVER = 0;
const MV_DIG  = 1;
const MV_UPG  = 2;
const MV_COLL = 3;
const MV_DAILY = 4;
const MV_HIST = 5;
const MV_PAGES = 6;
const MV_UPG_ROWS = 11;   // Mn.B_N (9) buildings + pickaxe + cart
const MV_COLL_COLS = 5;

class MineView extends WatchUi.View {
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
    hidden var _digPulse;
    hidden var _tip;

    hidden var _demo; hidden var _demoAcc;

    hidden var _rows; hidden var _rowIds;
    hidden var _rBtnA; hidden var _rBtnB;
    hidden var _rTabs; hidden var _rPrev; hidden var _rNext; hidden var _rDemo;

    function initialize() {
        View.initialize();
        _m = new MineModel();
        _page = MV_OVER; _w = 0; _h = 0; _t = 0; _timer = null;
        _cur = 0; _scroll = 0;
        _popup = null; _popupT = 0;
        _welcome = false; _event = false; _evChoice = 0; _pendingWelcome = false; _digPulse = 0;
        _tip = false;
        _demo = false; _demoAcc = 0;
        _rows = []; _rowIds = []; _rBtnA = null; _rBtnB = null;
        _rTabs = []; _rPrev = null; _rNext = null; _rDemo = null;
        _loadFx();
        _loadDemo();

        _m.ensureStart();
        _m.collectOffline();
        _pendingWelcome = _hasGains() || _m.newDay || _m.gEvent != Mn.EV_NONE;
        if (_m.pendingEvent != Mn.EV_NONE) { _event = true; _evChoice = 0; }
        else if (_pendingWelcome) { _welcome = true; }
        // First-run "stats are the currency" explainer (once, unless demoing).
        if (!_demo && !_welcome && !_event) {
            try {
                var seen = Application.Storage.getValue("mn_tip");
                if (!(seen instanceof Lang.Number) || seen != 1) { _tip = true; }
            } catch (e) {}
        }
        // Demo starts clean (no overlay in the way).
        if (_demo) { _welcome = false; _pendingWelcome = false; _tip = false; }
        try { _m.submitScores(); } catch (e) {}
    }
    hidden function _saveTip() { try { Application.Storage.setValue("mn_tip", 1); } catch (e) {} }

    function model() { return _m; }

    hidden function _hasGains() {
        for (var i = 0; i < Mn.R_N; i++) { if (_m.gRes[i] > 0) { return true; } }
        return _m.gDepth > 0;
    }
    hidden function _loadFx() {
        _fxOn = true;
        try { var v = Application.Storage.getValue("mn_fx"); if (v instanceof Lang.Number) { _fxOn = (v == 0); } } catch (e) {}
    }
    hidden function _loadDemo() {
        _demo = false;
        if (!Mn.SHOW_DEMO) { return; }   // showcase-only; never active for users
        try { var v = Application.Storage.getValue("mn_demo"); if (v instanceof Lang.Number) { _demo = (v == 1); } } catch (e) {}
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
        if (_digPulse > 0) { _digPulse -= 1; }
        if (_popupT > 0) { _popupT -= 1; if (_popupT == 0) { _popup = null; } }
        if (_demo) { _runDemo(); }
        WatchUi.requestUpdate();
    }

    // ── DEMO fast-track ───────────────────────────────────────────────────────
    hidden function _runDemo() {
        // Never let an overlay stall the showcase.
        if (_event) { _resolveEvent(0); }
        if (_welcome) { _welcome = false; }
        if (_tip) { _tip = false; _saveTip(); }
        _demoAcc += 1;
        if (_demoAcc < 12) { return; }        // ~0.8s at 66ms ticks
        _demoAcc = 0;
        try { _m.demoTick(); } catch (e) {}
        _digPulse = 6;
        _tone(0); _vibe(8, 12);
    }
    hidden function _toggleDemo() {
        _demo = !_demo;
        _demoAcc = 0;
        try { Application.Storage.setValue("mn_demo", _demo ? 1 : 0); } catch (e) {}
        if (_demo) {
            _welcome = false; _tip = false;
            if (_event) { _resolveEvent(0); }
        }
        _popup = _demo ? "DEMO ON - auto mining" : "DEMO OFF"; _popupT = 26;
        _tone(_demo ? 4 : 0); _vibe(25, 35);
        WatchUi.requestUpdate();
    }

    // ── Feedback ──────────────────────────────────────────────────────────────
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
        if (_welcome) { _welcome = false; WatchUi.requestUpdate(); return true; }
        if (_tip) { _tip = false; _saveTip(); WatchUi.requestUpdate(); return true; }
        return false;
    }
    function pageMove(d) {
        if (_event) { return; }
        if (_dismiss()) { return; }
        _page = ((_page + d) % MV_PAGES + MV_PAGES) % MV_PAGES;
        _cur = 0; _scroll = 0;
        _tone(0); _vibe(12, 18);
        WatchUi.requestUpdate();
    }
    function setPage(p) {
        if (_event) { return; }
        if (_dismiss()) { return; }
        _page = ((p % MV_PAGES) + MV_PAGES) % MV_PAGES;
        _cur = 0; _scroll = 0;
        _tone(0); _vibe(10, 15);
        WatchUi.requestUpdate();
    }

    // UP/DOWN: move the cursor within a page, overflowing into the next/prev
    // page at the ends so the whole game is reachable with only two buttons.
    function cursorMove(d) {
        if (_event) { _evChoice = (_evChoice + 1) % 2; _tone(0); WatchUi.requestUpdate(); return; }
        if (_dismiss()) { return; }

        if (_page == MV_UPG) {
            var nc = _cur + d;
            if (nc < 0) { pageMove(-1); return; }
            if (nc >= MV_UPG_ROWS) { pageMove(1); return; }
            _cur = nc; _tone(0); WatchUi.requestUpdate(); return;
        }
        if (_page == MV_COLL) {
            var nc2 = _cur + d * MV_COLL_COLS;
            if (nc2 < 0) { pageMove(-1); return; }
            if (nc2 >= Mn.C_N) { pageMove(1); return; }
            _cur = nc2; _tone(0); WatchUi.requestUpdate(); return;
        }
        if (_page == MV_HIST) {
            var maxScroll = _m.history().size() - 6;
            if (maxScroll < 0) { maxScroll = 0; }
            var ns = _scroll + d;
            if (ns < 0) { pageMove(-1); return; }
            if (ns > maxScroll) { pageMove(1); return; }
            _scroll = ns; _tone(0); WatchUi.requestUpdate(); return;
        }
        // Non-list pages: page directly.
        pageMove(d);
    }

    function activate() {
        if (_event) { _resolveEvent(_evChoice); return; }
        if (_dismiss()) { return; }
        if (_page == MV_OVER)  { setPage(MV_DIG); return; }
        if (_page == MV_DIG)   { _doDig(); return; }
        if (_page == MV_UPG)   { _doUpgrade(_cur); return; }
        if (_page == MV_DAILY) { _doClaim(); return; }
        if (_page == MV_COLL) {
            var owned = _m.hasColl(_cur);
            _popup = Mn.cName(_cur) + " - " + (owned ? Mn.rarityName(Mn.cRarity(_cur)) : "undiscovered");
            _popupT = 28; _tone(0); WatchUi.requestUpdate(); return;
        }
    }

    hidden function _doDig() {
        var res = null;
        try { res = _m.dig(); } catch (e) { res = null; }
        _digPulse = 6;
        if (res != null) { _popup = res; _popupT = 22; }
        if (res != null && res.length() >= 4 && res.substring(0, 4).equals("DISC")) { _tone(4); _vibe(60, 120); }
        else { _tone(0); _vibe(18, 22); }
        WatchUi.requestUpdate();
    }
    hidden function _doUpgrade(row) {
        var res = null;
        try {
            if (row < Mn.B_N) { res = _m.upgradeBuilding(row); }
            else if (row == Mn.B_N) { res = _m.upgradePick(); }
            else { res = _m.upgradeCart(); }
        } catch (e) { res = null; }
        _do(res);
    }
    hidden function _do(res) {
        if (res == null) { WatchUi.requestUpdate(); return; }
        _popup = res; _popupT = 30;
        var bad = (res.length() >= 4 && res.substring(0, 4).equals("Need"))
               || (res.length() >= 6 && res.substring(0, 6).equals("Locked"))
               || (res.length() >= 4 && res.substring(0, 4).equals("Best"));
        if (bad) { _tone(2); _vibe(30, 40); } else { _tone(4); _vibe(35, 45); }
        WatchUi.requestUpdate();
    }
    hidden function _doClaim() {
        var ok = false;
        try { ok = _m.claimDaily(); } catch (e) { ok = false; }
        if (ok) { _popup = "Challenge reward claimed!"; _popupT = 34; _tone(4); _vibe(60, 120); }
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
        if (_pendingWelcome && !_demo) { _welcome = true; }
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
        if (_tip) { _dismiss(); return true; }
        // Rows / grid cells first (they overlap the edge chevron zones).
        for (var i = 0; i < _rows.size(); i++) {
            if (_inR(x, y, _rows[i])) { _cur = _rowIds[i]; activate(); return true; }
        }
        if (_inR(x, y, _rDemo)) { _toggleDemo(); return true; }
        if (_inR(x, y, _rBtnA)) { activate(); return true; }
        // Tab strip (jump straight to a page).
        for (var t = 0; t < _rTabs.size(); t++) {
            if (_inR(x, y, _rTabs[t])) { setPage(t); return true; }
        }
        // Edge chevrons (page prev/next).
        if (_inR(x, y, _rPrev)) { pageMove(-1); return true; }
        if (_inR(x, y, _rNext)) { pageMove(1); return true; }
        return true;
    }
    hidden function _inR(x, y, r) {
        if (r == null) { return false; }
        return x >= r[0] && x < r[0] + r[2] && y >= r[1] && y < r[1] + r[3];
    }

    // ═══ Rendering ═══════════════════════════════════════════════════════════
    function onUpdate(dc) {
        try { _draw(dc); } catch (e) { try { dc.setColor(Mn.BG, Mn.BG); dc.clear(); } catch (e2) {} }
    }
    hidden function _draw(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        _rows = []; _rowIds = []; _rBtnA = null; _rBtnB = null;
        _rTabs = []; _rDemo = null;
        var cx = _w / 2;

        dc.setColor(Mn.BG, Mn.BG); dc.clear();
        if (_w == _h) { dc.setColor(Mn.CIRCLE, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }

        if (_page == MV_OVER) { _drawOverview(dc); }
        else if (_page == MV_DIG) { _drawDig(dc); }
        else if (_page == MV_UPG) { _drawUpgrade(dc); }
        else if (_page == MV_COLL) { _drawCollection(dc); }
        else if (_page == MV_DAILY) { _drawDaily(dc); }
        else { _drawHistory(dc); }

        _drawChrome(dc);
        if (_demo) { _drawDemoBorder(dc); }
        if (_popup != null) { _drawPopup(dc); }
        if (_welcome) { _drawWelcome(dc); }
        if (_tip && !_welcome && !_event) { _drawTip(dc); }
        if (_event) { _drawEvent(dc); }
    }

    // ── Persistent top chrome: name + tab dots + edge chevrons ────────────────
    hidden function _pageName(p) {
        if (p == MV_OVER) { return "OVERVIEW"; }
        if (p == MV_DIG)  { return "DIG"; }
        if (p == MV_UPG)  { return "UPGRADE"; }
        if (p == MV_COLL) { return "COLLECT"; }
        if (p == MV_DAILY){ return "DAILY"; }
        return "MINE LOG";
    }
    hidden function _pageColor(p) {
        if (p == MV_UPG)  { return Mn.GOLD; }
        if (p == MV_COLL) { return 0xFFD24A; }
        if (p == MV_DAILY){ return Mn.GOLD; }
        if (p == MV_HIST) { return 0x9FB0C0; }
        return Mn.ACCENT;
    }
    hidden function _drawChrome(dc) {
        var cx = _w / 2;
        // Tiny pixel-font page title — dramatically smaller than the old
        // FONT_TINY header, shadowed for legibility, and white on OVERVIEW so
        // the name never blends into the bright mine diorama.
        var col = (_page == MV_OVER) ? 0xFFFFFF : _pageColor(_page);
        var name = _pageName(_page);
        if (_demo) { name = "DEMO - " + name; col = Mn.GOLD; }
        var hsc = _h / 190; if (hsc < 2) { hsc = 2; }
        Px.gshC(dc, name, cx, _h * 7 / 100, hsc, col);

        // Tab dots (each with a generous tap rect).
        var y = _h * 14 / 100;
        var gap = _w * 9 / 100;
        var x0 = cx - gap * (MV_PAGES - 1) / 2;
        for (var i = 0; i < MV_PAGES; i++) {
            var tx = x0 + i * gap;
            var on = (i == _page);
            dc.setColor(on ? col : 0x4A3A28, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tx, y, on ? 4 : 2);
            if (on) { dc.setColor(Mn.BG, Graphics.COLOR_TRANSPARENT); dc.fillCircle(tx, y, 1); }
            _rTabs.add([tx - gap / 2, y - _h * 6 / 100, gap, _h * 12 / 100]);
        }

        // Edge chevrons.
        _rPrev = [0, _h * 30 / 100, _w * 15 / 100, _h * 40 / 100];
        _rNext = [_w * 85 / 100, _h * 30 / 100, _w * 15 / 100, _h * 40 / 100];
        var chy = _h * 50 / 100;
        dc.setColor(0x6A5238, Graphics.COLOR_TRANSPARENT);
        var lxp = _w * 7 / 100;
        dc.fillPolygon([[lxp + _w * 4 / 100, chy - _h * 5 / 100], [lxp, chy], [lxp + _w * 4 / 100, chy + _h * 5 / 100]]);
        var rxp = _w * 93 / 100;
        dc.fillPolygon([[rxp - _w * 4 / 100, chy - _h * 5 / 100], [rxp, chy], [rxp - _w * 4 / 100, chy + _h * 5 / 100]]);
    }

    hidden function _drawDemoBorder(dc) {
        var cx = _w / 2;
        var pulse = (_t / 4) % 6;
        dc.setPenWidth(2);
        dc.setColor(Mn.GOLD, Graphics.COLOR_TRANSPARENT);
        if (_w == _h) { dc.drawCircle(cx, _h / 2, _w / 2 - 3 - pulse); }
        else { dc.drawRectangle(3 + pulse, 3 + pulse, _w - 6 - 2 * pulse, _h - 6 - 2 * pulse); }
        dc.setPenWidth(1);
    }

    // ── OVERVIEW — the pixel-art mine cross-section IS the screen ──────────────
    // The diorama fills the whole watch so the mine is the star. All numbers and
    // actions (resources, upgrades, daily, stats, demo toggle) live on the
    // sibling pages / OPTIONS menu; only one slim glanceable ribbon overlays the
    // very bottom. Mirrors ISLAND's _drawHome.
    hidden function _drawOverview(dc) {
        var cx = _w / 2;
        // Inset the diorama ~5% so it sits framed inside the display instead of
        // bursting the edges of small/round watches.
        var mx = _w * 25 / 1000; var my = _h * 25 / 1000;
        var R = (_w == _h) ? (_w / 2) : 0;
        // Scale the mine cross-section down to 85% (15% smaller) of the inset
        // box, kept centred on the display so the scene breathes and never
        // crowds the edges.
        var bw = (_w - mx * 2) * 85 / 100;
        var bh = (_h - my * 2) * 85 / 100;
        var bx = cx - bw / 2;
        var by = _h / 2 - bh / 2;
        try {
            MineArt.drawMine(dc, _m, bx, by, bw, bh, _t, cx, _h / 2, R);
        } catch (e) {
            try { MineArt.drawScene(dc, _m, cx, _h / 2, _h * 85 / 200, _t); } catch (e2) {}
        }
        try { _overOverlay(dc); } catch (e) {}
    }

    // Slim bottom ribbon on a dark scrim: hero Gold (left) · Lv/depth (centre) ·
    // steps stat (right). Kept ~15% slimmer than the old chips and positioned
    // from the real FONT_XTINY height so it never overlaps the screen bottom.
    hidden function _overOverlay(dc) {
        var cx = _w / 2;
        var round = (_w == _h);
        // Tiny pixel-font ribbon: dramatically smaller than FONT_XTINY, bright,
        // crisp, and short enough it never smothers the mine diorama. Mirrors
        // ISLAND's _homeOverlay geometry exactly.
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        var gh = 5 * sc;
        var barH = gh + sc * 4; if (barH < 13) { barH = 13; }
        var barW = round ? _w * 62 / 100 : _w * 80 / 100;
        var bx = cx - barW / 2;
        var by = round ? (_h * 85 / 100 - barH / 2) : (_h - barH - _h * 3 / 100);
        var midY = by + barH / 2;
        var gy = midY - gh / 2;
        var pad = barH / 4; if (pad < 3) { pad = 3; }

        dc.setColor(0x0A0704, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, barW, barH, barH / 3);
        dc.setColor(Mn.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, barW, barH, barH / 3);

        // Left: gold nugget icon + hero currency count.
        var isz = gh / 2; if (isz < 3) { isz = 3; }
        var ix = bx + pad + isz;
        try { MineArt.resIcon(dc, ix, midY, isz, Mn.R_GOLD); } catch (e) {}
        Px.gtxt(dc, _fmt(_m.res[Mn.R_GOLD]), ix + isz + sc, gy, sc, 0xFFE9A0);

        // Centre: level + current depth (short & bright).
        Px.gtxtC(dc, "LV " + _m.mineLevel() + " " + _m.depth + "M", cx, gy, sc, 0xEAF2FF);

        // Right: steps stat (the currency that grows the mine).
        var steps = 0;
        try { steps = Sensors.getStepsToday(); } catch (e) { steps = 0; }
        if (steps == null || steps < 0) { steps = 0; }
        var sstr = _fmt(steps) + " ST";
        Px.gtxt(dc, sstr, bx + barW - pad - Px.gtxtW(sstr, sc), gy, sc, 0x4CE0A0);
    }

    // Compact wallet strip (icon + count for all four resources) surfaced on the
    // DIG page header so the spendable currency counts stay reachable now that
    // the overview is pure diorama. Centred on y, height chipH.
    hidden function _resStrip(dc, y, chipH) {
        if (chipH < 12) { chipH = 12; }
        var cellW = _w * 22 / 100;
        var totalW = cellW * Mn.R_N;
        var x0 = _w / 2 - totalW / 2;
        for (var i = 0; i < Mn.R_N; i++) {
            var cxi = x0 + i * cellW;
            MineArt.resIcon(dc, cxi + chipH * 40 / 100, y, chipH * 30 / 100, i);
            _txt(dc, cxi + chipH * 80 / 100, y, Graphics.FONT_XTINY, Mn.resColor(i), _fmt(_m.res[i]),
                 Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ── DIG ───────────────────────────────────────────────────────────────────
    hidden function _drawDig(dc) {
        var cx = _w / 2;
        try { _resStrip(dc, _h * 185 / 1000, _h * 9 / 100); } catch (e) {}
        _txt(dc, cx, _h * 23 / 100, Graphics.FONT_XTINY, Mn.MUTED, Mn.zName(_m.zone()), Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 31 / 100, Graphics.FONT_NUMBER_MEDIUM, Mn.GOLD, "" + _m.depth, Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 47 / 100, Graphics.FONT_XTINY, Mn.MUTED, "meters deep", Graphics.TEXT_JUSTIFY_CENTER);

        var next = _nextMark();
        var prev = _prevMark();
        var pct = 100;
        if (next > prev) { pct = (_m.depth - prev) * 100 / (next - prev); }
        var bw = _w * 64 / 100; var bx = cx - bw / 2; var by = _h * 55 / 100;
        _bar(dc, bx, by, bw, 8, pct, 0x8C6CFF);
        var nlabel = (next > _m.depth) ? ("Next: " + _nextMarkName() + " @ " + next + "m") : "All layers found";
        _txt(dc, cx, by + _h * 6 / 100, Graphics.FONT_XTINY, Mn.MUTED, nlabel, Graphics.TEXT_JUSTIFY_CENTER);

        var bwr = _w * 54 / 100; var bxr = cx - bwr / 2; var byr = _h * 73 / 100; var bhr = _h * 14 / 100;
        _rBtnA = [bxr, byr, bwr, bhr];
        _button(dc, _rBtnA, "DIG  +" + (2 + _m.pickTier + _m.bLevel[Mn.B_SHAFT]) + "m", _digPulse > 0);

        // Depth pressure readout — the one line that explains why the idle dig
        // rate keeps falling below 1200m, and which building answers it.
        var pp = 100;
        try { pp = _m.pressurePct(); } catch (e) { pp = 100; }
        var hint = "SELECT / TAP to dig"; var hintCol = Mn.MUTED;
        if (pp < 100) { hint = "Pressure " + pp + "% - build Rig"; hintCol = 0xFF8A5A; }
        _txt(dc, cx, _h * 92 / 100, Graphics.FONT_XTINY, hintCol, hint, Graphics.TEXT_JUSTIFY_CENTER);
    }
    hidden function _nextMark() {
        for (var i = 0; i < Mn.D_N; i++) { if (Mn.dDepth(i) > _m.depth) { return Mn.dDepth(i); } }
        return Mn.dDepth(Mn.D_N - 1);
    }
    hidden function _prevMark() {
        var p = 0;
        for (var i = 0; i < Mn.D_N; i++) { if (Mn.dDepth(i) <= _m.depth) { p = Mn.dDepth(i); } }
        return p;
    }
    hidden function _nextMarkName() {
        for (var i = 0; i < Mn.D_N; i++) { if (Mn.dDepth(i) > _m.depth) { return Mn.dName(i); } }
        return "-";
    }

    // ── UPGRADE ──────────────────────────────────────────────────────────────
    hidden function _drawUpgrade(dc) {
        _drawListFrame(dc, MV_UPG_ROWS, method(:_drawUpgRow));
    }
    function _drawUpgRow(dc, id, x, y, w, rh, sel) {
        var icx = x + rh / 2;
        var icy = y + rh / 2;
        var isz = rh / 3;
        var tx = x + rh + 4;

        // Reserve a fixed right-hand column for the level pip bar so the name
        // and cost labels can never overlap it on narrow screens.
        var cap = 5;
        var pipSz = rh * 20 / 100; if (pipSz < 3) { pipSz = 3; }
        var pipGap = 2;
        var pad = 4;
        var colW = cap * pipSz + (cap - 1) * pipGap;
        var barLeft = x + w - colW - pad;
        var nameMax = barLeft - tx - 3; if (nameMax < 8) { nameMax = 8; }

        var nm = ""; var nmCol = Mn.TEXT;
        var sub = ""; var subCol = Mn.MUTED;
        var lvl = 0; var showPips = false;

        if (id < Mn.B_N) {
            var unlocked = _m.isUnlocked(id);
            lvl = _m.bLevel[id];
            MineArt.buildingIconEx(dc, icx, icy, isz, id, Mn.bColor(id), !unlocked);
            nm = Mn.bName(id);
            nmCol = unlocked ? Mn.TEXT : Mn.MUTED;
            if (!unlocked) {
                sub = "Dig to " + Mn.bUnlockDepth(id) + "m"; subCol = 0xB46CFF;
            } else {
                sub = _costStr(_m.bCost(id));
                subCol = _m.canAfford(_m.bCost(id)) ? 0x8FE080 : Mn.MUTED;
                showPips = (lvl > 0);
            }
        } else if (id == Mn.B_N) {
            MineArt.pickIcon(dc, icx, icy, isz, _m.pickTier);
            nm = Mn.pickName(_m.pickTier);
            lvl = _m.pickTier + 1; showPips = true;
            if (_m.pickTier >= Mn.PICK_N - 1) {
                sub = "MAX  (+ore +dig)"; subCol = Mn.GOLD;
            } else {
                sub = _costStr(_m.pickCost());
                subCol = _m.canAfford(_m.pickCost()) ? 0x8FE080 : Mn.MUTED;
            }
        } else {
            MineArt.cartIcon(dc, icx, icy, isz, _m.cartTier);
            nm = Mn.cartName(_m.cartTier);
            lvl = _m.cartTier + 1; showPips = true;
            if (_m.cartTier >= Mn.CART_N - 1) {
                sub = "MAX  (+haul)"; subCol = Mn.GOLD;
            } else {
                sub = _costStr(_m.cartCost());
                subCol = _m.canAfford(_m.cartCost()) ? 0x8FE080 : Mn.MUTED;
            }
        }

        _wrap1(dc, tx, y + rh * 18 / 100, nameMax, Graphics.FONT_XTINY, nmCol, nm);
        _wrap1(dc, tx, y + rh * 60 / 100, nameMax, Graphics.FONT_XTINY, subCol, sub);

        if (showPips && lvl > 0) {
            _txt(dc, x + w - pad, y + rh * 15 / 100, Graphics.FONT_XTINY, Mn.GOLD,
                 "L" + lvl, Graphics.TEXT_JUSTIFY_RIGHT);
            var pipY = y + rh * 64 / 100;
            var shown = lvl; if (shown > cap) { shown = cap; }
            for (var p = 0; p < cap; p++) {
                var pxp = barLeft + p * (pipSz + pipGap);
                dc.setColor(p < shown ? Mn.GOLD : 0x3A2E1E, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(pxp, pipY, pipSz, pipSz);
            }
        }
    }
    hidden function _costStr(cost) {
        var s = "";
        var ab = ["s", "i", "g", "m"];
        for (var i = 0; i < Mn.R_N; i++) {
            if (cost[i] > 0) { if (s.length() > 0) { s += " "; } s += _fmt(cost[i]) + ab[i]; }
        }
        return s.length() > 0 ? s : "free";
    }

    // ── COLLECTION ────────────────────────────────────────────────────────────
    hidden function _drawCollection(dc) {
        var cx = _w / 2;
        _txt(dc, cx, _h * 20 / 100, Graphics.FONT_XTINY, 0xFFD24A,
             _m.collectiblesOwned() + " / " + Mn.C_N + " found", Graphics.TEXT_JUSTIFY_CENTER);
        // The grid sizes itself from BOTH axes so appending collectibles adds
        // rows without ever pushing cells off the bottom of the display.
        var cols = MV_COLL_COLS;
        var rows = (Mn.C_N + cols - 1) / cols;
        if (rows < 1) { rows = 1; }
        var bandY = _h * 25 / 100;
        var bandH = _h * 56 / 100;
        var cell = _w * 80 / 100 / cols;
        if (bandH / rows < cell) { cell = bandH / rows; }
        if (cell < 6) { cell = 6; }
        var gx = cx - cell * cols / 2;
        var gy = bandY + (bandH - cell * rows) / 2;
        for (var i = 0; i < Mn.C_N; i++) {
            var rr = i / cols; var c = i % cols;
            var px = gx + c * cell + cell / 2;
            var py = gy + rr * cell + cell / 2;
            var owned = _m.hasColl(i);
            if (i == _cur) { dc.setColor(Mn.ACCENT, Graphics.COLOR_TRANSPARENT); dc.drawCircle(px, py, cell * 40 / 100); }
            if (owned) {
                MineArt.collectibleIcon(dc, px, py, cell * 30 / 100, Mn.cRarity(i));
            } else {
                dc.setColor(0x241E16, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, cell * 26 / 100);
            }
            _rows.add([px - cell / 2, py - cell / 2, cell, cell]);
            _rowIds.add(i);
        }
        var owned2 = _m.hasColl(_cur);
        _txt(dc, cx, _h * 84 / 100, Graphics.FONT_XTINY, owned2 ? Mn.cColor(_cur) : Mn.MUTED,
             Mn.cName(_cur) + (owned2 ? "" : " ?"), Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 91 / 100, Graphics.FONT_XTINY, Mn.GOLD,
             (owned2 ? Mn.rarityName(Mn.cRarity(_cur)) : "Legendary: " + _m.legendaryFinds()), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── DAILY ─────────────────────────────────────────────────────────────────
    hidden function _drawDaily(dc) {
        var cx = _w / 2;
        _wrap(dc, cx, _h * 24 / 100, _w * 78 / 100, Graphics.FONT_TINY, Mn.TEXT, _m.dailyText());

        var prog = _m.dailyProgress(); var tgt = _m.dailyTarget();
        var bw = _w * 60 / 100; var bx = cx - bw / 2; var by = _h * 45 / 100;
        _bar(dc, bx, by, bw, 10, (tgt > 0 ? prog * 100 / tgt : 100), Mn.ACCENT);
        _txt(dc, cx, by + _h * 6 / 100, Graphics.FONT_XTINY, Mn.MUTED, prog + " / " + tgt, Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, by + _h * 13 / 100, Graphics.FONT_XTINY, Mn.GOLD, _m.dailyRewardText(), Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, by + _h * 20 / 100, Graphics.FONT_XTINY, Mn.TEXT,
             "Streak " + _m.streak + "d  ·  " + _m.ageDayLabel(), Graphics.TEXT_JUSTIFY_CENTER);

        var bwr = _w * 46 / 100; var bxr = cx - bwr / 2; var byr = _h * 82 / 100; var bhr = _h * 12 / 100;
        _rBtnA = [bxr, byr, bwr, bhr];
        var can = _m.dailyComplete() && !_m.dailyClaimed;
        _button(dc, _rBtnA, _m.dailyClaimed ? "CLAIMED" : "CLAIM", can);
    }

    // ── HISTORY ──────────────────────────────────────────────────────────────
    hidden function _drawHistory(dc) {
        var cx = _w / 2;
        var lg = _m.history();
        var y = _h * 22 / 100; var step = _h * 10 / 100;
        if (lg.size() == 0) {
            _txt(dc, cx, _h * 46 / 100, Graphics.FONT_XTINY, Mn.MUTED, "No history yet", Graphics.TEXT_JUSTIFY_CENTER);
        }
        var shown = 0;
        for (var i = _scroll; i < lg.size() && shown < 6; i++) {
            var ry = y + shown * step;
            dc.setColor(Mn.ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_w * 13 / 100, ry + step / 3, 2);
            _wrap1(dc, _w * 17 / 100, ry, _w * 70 / 100, Graphics.FONT_XTINY, Mn.TEXT, lg[i]);
            shown++;
        }
        _txt(dc, cx, _h * 91 / 100, Graphics.FONT_XTINY, Mn.GOLD, Mn.zName(_m.zone()), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Overlays ──────────────────────────────────────────────────────────────
    hidden function _drawWelcome(dc) {
        var cx = _w / 2;
        dc.setColor(0x05040A, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) { dc.setColor(Mn.CIRCLE, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }
        _txt(dc, cx, _h * 13 / 100, Graphics.FONT_SMALL, Mn.ACCENT, "WELCOME BACK", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 22 / 100, Graphics.FONT_XTINY, Mn.MUTED, "MINER", Graphics.TEXT_JUSTIFY_CENTER);

        var y = _h * 31 / 100; var step = _h * 8 / 100; var n = 0;
        for (var i = 0; i < Mn.R_N; i++) {
            if (_m.gRes[i] > 0) {
                _txt(dc, cx, y + n * step, Graphics.FONT_TINY, Mn.resColor(i),
                     "+" + _fmt(_m.gRes[i]) + " " + Mn.resName(i), Graphics.TEXT_JUSTIFY_CENTER);
                n++;
            }
        }
        if (_m.gDepth > 0) { _txt(dc, cx, y + n * step, Graphics.FONT_TINY, Mn.GOLD, "Depth +" + _m.gDepth + "m", Graphics.TEXT_JUSTIFY_CENTER); n++; }
        if (n == 0) { _txt(dc, cx, y, Graphics.FONT_TINY, Mn.MUTED, "Miners idle", Graphics.TEXT_JUSTIFY_CENTER); }

        if (_m.newDay) {
            _txt(dc, cx, _h * 82 / 100, Graphics.FONT_XTINY, Mn.GOLD,
                 "Streak " + _m.streak + " day" + (_m.streak == 1 ? "" : "s"), Graphics.TEXT_JUSTIFY_CENTER);
        }
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Mn.MUTED, "tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // First-run explainer: makes the stats-as-currency idea explicit.
    hidden function _drawTip(dc) {
        var cx = _w / 2;
        dc.setColor(0x05040A, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) { dc.setColor(Mn.CIRCLE, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }

        // A chunky pixel gem crest so the tip feels part of the art.
        var u = _w / 26; if (u < 8) { u = 8; }
        try {
            var pal = { "M" => 0x4CE6E0, "W" => 0xE8FBFA, "G" => 0xFFC24A };
            var crest = ["..M..", ".MWM.", "MMMMM", ".GGG.", "..G.."];
            Px.spr(dc, crest, pal, cx - u * 5 / 2, _h * 12 / 100, u, false);
        } catch (e) {}

        _txt(dc, cx, _h * 36 / 100, Graphics.FONT_SMALL, Mn.ACCENT, "YOUR STATS", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 44 / 100, Graphics.FONT_XTINY, 0x8FE0B0, "are the currency", Graphics.TEXT_JUSTIFY_CENTER);
        _wrap(dc, cx, _h * 54 / 100, _w * 82 / 100, Graphics.FONT_XTINY, Mn.TEXT,
              "Move to dig deeper & strike gems.");
        _wrap(dc, cx, _h * 68 / 100, _w * 82 / 100, Graphics.FONT_XTINY, Mn.MUTED,
              "Steps -> depth & finds. Active min -> dig. Sleep -> night yield.");
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Mn.GOLD, "tap to start mining", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawEvent(dc) {
        var cx = _w / 2;
        dc.setColor(0x0A0705, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) { dc.setColor(0x1A130C, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx, _h / 2, _w / 2 - 1); }
        var e = _m.pendingEvent;
        _txt(dc, cx, _h * 14 / 100, Graphics.FONT_SMALL, Mn.ACCENT, Mn.evTitle(e), Graphics.TEXT_JUSTIFY_CENTER);
        _wrap(dc, cx, _h * 30 / 100, _w * 80 / 100, Graphics.FONT_XTINY, Mn.TEXT, Mn.evBody(e));

        var bw = _w * 58 / 100; var bx = cx - bw / 2; var bh = _h * 13 / 100;
        var y0 = _h * 54 / 100; var gap = _h * 3 / 100;
        _rBtnA = [bx, y0, bw, bh];
        _rBtnB = [bx, y0 + bh + gap, bw, bh];
        var a = (e == Mn.EV_CREATURE) ? "FIGHT" : "EXPLORE";
        var b = (e == Mn.EV_CREATURE) ? "FLEE" : "IGNORE";
        _button(dc, _rBtnA, a, _evChoice == 0);
        _button(dc, _rBtnB, b, _evChoice == 1);
    }

    // ── Chrome / helpers ──────────────────────────────────────────────────────
    hidden function _drawListFrame(dc, count, rowFn) {
        var top = _h * 19 / 100;
        var bottom = _h * 93 / 100;
        var rh = _h * 15 / 100;
        if (rh < 1) { rh = 1; }
        var maxRows = (bottom - top) / rh;
        if (maxRows < 1) { maxRows = 1; }
        if (_cur < 0) { _cur = 0; }
        if (_cur >= count) { _cur = (count > 0) ? count - 1 : 0; }
        if (_cur < _scroll) { _scroll = _cur; }
        if (_cur >= _scroll + maxRows) { _scroll = _cur - maxRows + 1; }
        if (_scroll < 0) { _scroll = 0; }

        var x = _w * 10 / 100; var w = _w * 80 / 100;
        for (var vi = 0; vi < maxRows; vi++) {
            var id = _scroll + vi;
            if (id >= count) { break; }
            var y = top + vi * rh;
            var sel = (id == _cur);
            dc.setColor(sel ? Mn.PANEL_HI : Mn.PANEL, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, rh - 3, 6);
            if (sel) { dc.setColor(Mn.ACCENT, Graphics.COLOR_TRANSPARENT); dc.drawRoundedRectangle(x, y, w, rh - 3, 6); }
            rowFn.invoke(dc, id, x + 4, y, w - 8, rh - 3, sel);
            _rows.add([x, y, w, rh - 3]);
            _rowIds.add(id);
        }
    }
    hidden function _button(dc, r, label, hot) {
        dc.setColor(hot ? 0x3A2410 : Mn.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(hot ? Mn.ACCENT : 0x3A2E1E, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(hot ? 0xFFE0B0 : 0xB2A48E, Graphics.COLOR_TRANSPARENT);
        dc.drawText(r[0] + r[2] / 2, r[1] + r[3] / 2, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    hidden function _drawPopup(dc) {
        var cx = _w / 2; var pw = _w * 84 / 100; var px = cx - pw / 2;
        var ph = _h * 12 / 100; var py = _h * 60 / 100;
        dc.setColor(0x05040A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, 8);
        dc.setColor(Mn.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, 8);
        _wrap(dc, cx, py + ph / 2 - _h * 3 / 100, pw - 12, Graphics.FONT_XTINY, Mn.TEXT, _popup);
    }
    hidden function _bar(dc, x, y, w, h, pct, col) {
        dc.setColor(Mn.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, h / 2);
        var fw = w * Mn._c(pct, 0, 100) / 100;
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
