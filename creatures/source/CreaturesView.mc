// ═══════════════════════════════════════════════════════════════════════════
// CreaturesView.mc — The BITOCHI CREATURES gameplay view.
//
// A five-screen carousel (HOME · ACTIONS · EVOLVE · DAILY · INDEX) over a single
// CreatureModel. NAVIGATION works three ways so it is robust on every device and
// the emulator:
//   • TAP a tab dot in the top strip to jump straight to a page.
//   • TAP the on-screen ◀ / ▶ chevrons (screen edges) to page prev/next.
//   • Physical UP/DOWN move the cursor on list pages and "overflow" to the
//     adjacent page at the ends; on non-list pages they page directly.
//     SELECT/ENTER activates the focused action. BACK saves + exits.
// A DEMO fast-track auto-develops a creature egg->apex for showcasing. Sound +
// haptics are gated by the shared "Sound & Haptics" option (cr_fx).
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;
using Toybox.System;

const CV_HOME = 0;
const CV_ACT  = 1;
const CV_EVO  = 2;
const CV_DAY  = 3;
const CV_COL  = 4;
const CV_PAGES = 5;

class CreaturesView extends WatchUi.View {
    hidden var _m;
    hidden var _page;
    hidden var _w; hidden var _h;
    hidden var _t;
    hidden var _timer;
    hidden var _fxOn;

    hidden var _popup; hidden var _popupT;
    hidden var _welcome;         // showing idle-summary overlay
    hidden var _hatchFlash;      // showing the just-hatched celebration
    hidden var _intro;           // first-run "stats are the currency" explainer
    hidden var _actCursor;       // 0=FEED 1=TRAIN 2=EXPLORE (actions page)
    hidden var _colScroll;

    hidden var _demo;            // DEMO fast-track active
    hidden var _demoCtr;         // sub-tick counter for demo pacing

    // Tap rects [x,y,w,h] recomputed each draw.
    hidden var _rBtnA; hidden var _rBtnB; hidden var _rBtnC;
    hidden var _rPrev; hidden var _rNext;
    hidden var _rTabs;           // array of 5 tab-dot hit rects
    hidden var _rDemo;           // DEMO toggle pill

    function initialize() {
        View.initialize();
        _m = new CreatureModel();
        _page = CV_HOME;
        _w = 0; _h = 0; _t = 0; _timer = null;
        _popup = null; _popupT = 0;
        _welcome = false; _hatchFlash = false; _intro = false;
        _actCursor = 0; _colScroll = 0;
        _demo = false; _demoCtr = 0;
        _rBtnA = null; _rBtnB = null; _rBtnC = null;
        _rPrev = null; _rNext = null; _rTabs = null; _rDemo = null;
        _loadFx();
        _loadDemo();

        // Boot the world: create the egg on first run, hatch if the timer is up,
        // then reconcile idle progress and (throttled) publish leaderboard scores.
        try { _m.ensureEgg(); } catch (e) {}
        var wasEgg = !_m.hatched;
        try { _m.maybeHatch(); } catch (e) {}
        try { _m.collectOffline(); } catch (e) {}
        if (wasEgg && _m.hatched) { _hatchFlash = true; }
        else if (_m.hatched && (_m.gXp > 0 || _m.gFood > 0 || _m.gMut > 0)) { _welcome = true; }
        try { _m.submitScores(); } catch (e) {}

        // One-time explainer: Garmin stats are the currency here.
        try {
            var seen = Application.Storage.getValue("cr_intro");
            if (!(seen instanceof Lang.Number) || seen != 1) { _intro = true; }
        } catch (e) { _intro = true; }
    }

    function model() { return _m; }

    hidden function _loadFx() {
        _fxOn = true;
        try {
            var v = Application.Storage.getValue("cr_fx");
            if (v instanceof Lang.Number) { _fxOn = (v == 0); }  // index 0 = ON
        } catch (e) {}
    }
    hidden function _loadDemo() {
        _demo = false;
        if (!Cr.SHOW_DEMO) { return; }   // showcase-only; never active for users
        try {
            var v = Application.Storage.getValue("cr_demo");
            if (v instanceof Lang.Number) { _demo = (v == 1); }  // index 1 = ON
        } catch (e) {}
    }
    hidden function _saveDemo() {
        try { Application.Storage.setValue("cr_demo", _demo ? 1 : 0); } catch (e) {}
    }
    hidden function _focus() {
        try {
            var v = Application.Storage.getValue("cr_focus");
            if (v instanceof Lang.Number) { return v; }
        } catch (e) {}
        return 0;
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

        if (_demo) {
            _demoCtr += 1;
            if (_demoCtr >= 10) {   // ~0.66s per demo step
                _demoCtr = 0;
                try {
                    var msg = _m.demoStep();
                    if (msg != null) { _popup = msg; _popupT = 22; }
                } catch (e) {}
            }
        } else if (!_m.hatched) {
            // Live-hatch an egg while the player watches.
            try {
                if (_m.maybeHatch()) { _hatchFlash = true; _tone(4); _vibe(80, 160); }
            } catch (e) {}
        }
        WatchUi.requestUpdate();
    }

    // ── Feedback (guarded) ────────────────────────────────────────────────────
    function _tone(kind) {
        if (!_fxOn) { return; }
        try {
            if (!(Attention has :playTone)) { return; }
            var t = Attention.TONE_KEY;
            if (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
            else if (kind == 2) { t = Attention.TONE_ERROR; }
            else if (kind == 3) { t = Attention.TONE_INTERVAL_ALERT; }
            else if (kind == 4) { t = Attention.TONE_SUCCESS; }
            Attention.playTone(t);
        } catch (e) {}
    }
    function _vibe(intensity, dur) {
        if (!_fxOn) { return; }
        try {
            if (!(Attention has :vibrate)) { return; }
            var p = [new Attention.VibeProfile(intensity, dur)];
            Attention.vibrate(p);
        } catch (e) {}
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    function pageMove(d) {
        if (_dismissOverlay()) { return; }
        _page = ((_page + d) % CV_PAGES + CV_PAGES) % CV_PAGES;
        _actCursor = 0; _colScroll = 0;
        _tone(0); _vibe(15, 20);
        WatchUi.requestUpdate();
    }
    function setPage(p) {
        if (_dismissOverlay()) { return; }
        _page = ((p % CV_PAGES) + CV_PAGES) % CV_PAGES;
        _actCursor = 0; _colScroll = 0;
        _tone(0); _vibe(12, 16);
        WatchUi.requestUpdate();
    }

    hidden function _dismissOverlay() {
        if (_welcome) { _welcome = false; WatchUi.requestUpdate(); return true; }
        if (_hatchFlash) { _hatchFlash = false; WatchUi.requestUpdate(); return true; }
        if (_intro) {
            _intro = false;
            try { Application.Storage.setValue("cr_intro", 1); } catch (e) {}
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    hidden function _colMaxScroll() {
        var over = Cr.SPECIES_N - 4;   // ~4 rows fit; allow scrolling the rest
        return (over > 0) ? over : 0;
    }

    // UP/DOWN: move a cursor where there is a list, else page. At a list's end,
    // "overflow" to the adjacent page so you can traverse the whole game.
    function cursorMove(d) {
        if (_dismissOverlay()) { return; }
        if (!_m.hatched) { return; }          // egg screen: nothing to scroll

        if (_page == CV_ACT) {
            var nc = _actCursor + d;
            if (nc < 0) { pageMove(-1); return; }
            if (nc > 2) { pageMove(1);  return; }
            _actCursor = nc; _tone(0); WatchUi.requestUpdate();
            return;
        }
        if (_page == CV_COL) {
            var ns = _colScroll + d;
            if (ns < 0) { pageMove(-1); return; }
            if (ns > _colMaxScroll()) { pageMove(1); return; }
            _colScroll = ns; _tone(0); WatchUi.requestUpdate();
            return;
        }
        pageMove(d);
    }

    // Context activation (SELECT / ENTER).
    function activate() {
        if (_dismissOverlay()) { return; }
        if (!_m.hatched) { doBoost(); return; }
        if (_page == CV_HOME) { setPage(CV_ACT); return; }
        if (_page == CV_ACT) {
            if (_actCursor == 0) { doFeed(); }
            else if (_actCursor == 1) { doTrain(); }
            else { doExplore(); }
            return;
        }
        if (_page == CV_DAY) { doClaim(); return; }
        if (_page == CV_EVO) {
            // SELECT on EVOLVE is the button-only route to ASCEND (it always
            // goes through the confirmation menu, so it can't wipe by accident).
            var canAsc = false;
            try { canAsc = _m.canAscend(); } catch (e) {}
            if (canAsc) { askAscend(); } else { setPage(CV_ACT); }
            return;
        }
        if (_page == CV_COL) { setPage(CV_HOME); return; }
    }

    // ── Ascension ─────────────────────────────────────────────────────────────
    // Always confirm: this trades the current creature for a new egg.
    function askAscend() {
        try {
            if (!_m.canAscend()) { return; }
            crOpenAscend(self);
        } catch (e) {}
    }
    // Called by CrAscendConfirmDelegate once the player confirms.
    function doAscend() as Void {
        try {
            if (!_m.canAscend()) { return; }
            _m.ascend();
            _page = CV_HOME;
            _welcome = false; _hatchFlash = false;
            _actCursor = 0; _colScroll = 0;
            _popup = "ASCENDED! A new egg awaits"; _popupT = 44;
            _tone(4); _vibe(80, 160);
            WatchUi.requestUpdate();
        } catch (e) {}
    }

    function toggleDemo() {
        _demo = !_demo;
        _demoCtr = 0;
        _saveDemo();
        _popup = _demo ? "DEMO ON" : "DEMO OFF";
        _popupT = 24;
        _tone(_demo ? 4 : 0); _vibe(30, 40);
        WatchUi.requestUpdate();
    }

    // ── Actions (all guarded) ──────────────────────────────────────────────────
    hidden function _act(res, evoBefore) {
        if (_m.evo > evoBefore) {
            _popup = "EVOLVED! " + Cr.stageName(_m.evo);
            _popupT = 40; _tone(4); _vibe(70, 140);
        } else {
            _popup = res; _popupT = 26;
        }
        WatchUi.requestUpdate();
    }
    function doFeed() {
        try {
            var e = _m.evo; var r = _m.feed();
            _tone(0); _vibe(20, 30); _act(r, e);
        } catch (ex) {}
    }
    function doTrain() {
        try {
            var e = _m.evo;
            var f = _focus();
            var focusTrait = -1;
            if (f == 1) { focusTrait = Cr.TR_SPD; }
            else if (f == 2) { focusTrait = Cr.TR_STR; }
            else if (f == 3) { focusTrait = Cr.TR_INT; }
            else if (f == 4) { focusTrait = Cr.TR_NRG; }
            var r = _m.train(focusTrait);
            _tone(1); _vibe(35, 45); _act(r, e);
        } catch (ex) {}
    }
    function doExplore() {
        try {
            var e = _m.evo; var r = _m.explore();
            _tone(3); _vibe(25, 35); _act(r, e);
        } catch (ex) {}
    }
    function doBoost() {
        try {
            _m.boost();
            if (_m.maybeHatch()) { _hatchFlash = true; _tone(4); _vibe(80, 160); }
            else { _popup = "Boosted! -30 min"; _popupT = 26; _tone(0); _vibe(20, 30); }
            WatchUi.requestUpdate();
        } catch (ex) {}
    }
    function doClaim() {
        try {
            if (_m.claimDaily()) {
                _popup = "Reward claimed!"; _popupT = 34; _tone(4); _vibe(60, 120);
            } else if (_m.dailyClaimed) {
                _popup = "Already claimed today"; _popupT = 24;
            } else {
                _popup = "Not complete yet"; _popupT = 24; _tone(2);
            }
            WatchUi.requestUpdate();
        } catch (ex) {}
    }

    // ── Tap hit-testing (called by delegate) ──────────────────────────────────
    function onTapXY(x, y) {
        if (_welcome || _hatchFlash || _intro) { _dismissOverlay(); return true; }

        // DEMO pill is always live.
        if (_inRect(x, y, _rDemo)) { toggleDemo(); return true; }

        if (!_m.hatched) {
            if (_inRect(x, y, _rBtnB)) { doBoost(); return true; }
            return true;
        }

        // Tab dots: jump straight to a page.
        if (_rTabs != null) {
            for (var i = 0; i < _rTabs.size(); i++) {
                if (_inRect(x, y, _rTabs[i])) { setPage(i); return true; }
            }
        }
        // Edge chevrons: prev / next.
        if (_inRect(x, y, _rPrev)) { pageMove(-1); return true; }
        if (_inRect(x, y, _rNext)) { pageMove(1);  return true; }

        if (_page == CV_ACT) {
            if (_inRect(x, y, _rBtnA)) { _actCursor = 0; doFeed(); return true; }
            if (_inRect(x, y, _rBtnB)) { _actCursor = 1; doTrain(); return true; }
            if (_inRect(x, y, _rBtnC)) { _actCursor = 2; doExplore(); return true; }
        }
        if (_page == CV_DAY) {
            if (_inRect(x, y, _rBtnA)) { doClaim(); return true; }
        }
        if (_page == CV_EVO) {
            if (_inRect(x, y, _rBtnA)) { askAscend(); return true; }
        }
        if (_page == CV_HOME) { setPage(CV_ACT); return true; }
        return true;
    }
    hidden function _inRect(x, y, r) {
        if (r == null) { return false; }
        return x >= r[0] && x < r[0] + r[2] && y >= r[1] && y < r[1] + r[3];
    }

    // ═══ Rendering ════════════════════════════════════════════════════════════
    function onUpdate(dc) {
        try { _draw(dc); }
        catch (e) { try { dc.setColor(Cr.BG, Cr.BG); dc.clear(); } catch (e2) {} }
    }

    hidden function _draw(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        var cx = _w / 2;
        _rBtnA = null; _rBtnB = null; _rBtnC = null;
        _rTabs = null; _rPrev = null; _rNext = null;

        dc.setColor(Cr.BG, Cr.BG); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }

        if (!_m.hatched) {
            _drawEggScreen(dc);
            _drawDemoPill(dc);
        } else if (_page == CV_HOME) {
            // HOME is the full-watch diorama: paint the scene first, then let
            // the tab strip + chevrons ride on top (with a text shadow so the
            // chrome stays legible over the bright scene). No demo pill / hint.
            _drawHome(dc);
            _drawTabStrip(dc);
            _drawChevrons(dc);
        } else {
            _drawTabStrip(dc);
            if (_page == CV_ACT) { _drawActions(dc); }
            else if (_page == CV_EVO) { _drawEvolution(dc); }
            else if (_page == CV_DAY) { _drawDaily(dc); }
            else { _drawCollection(dc); }
            _drawChevrons(dc);
            _drawHint(dc);
            _drawDemoPill(dc);
        }

        if (_popup != null) { _drawPopup(dc); }
        if (_welcome) { _drawWelcome(dc); }
        if (_hatchFlash) { _drawHatch(dc); }
        if (_intro && _m.hatched && !_welcome && !_hatchFlash) { _drawIntro(dc); }
    }

    // ── Small helpers ──────────────────────────────────────────────────────────
    hidden function _bar(dc, x, y, w, h, pct, col) {
        dc.setColor(Cr.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, h / 2);
        var fw = w * Cr._clamp(pct, 0, 100) / 100;
        if (fw < h && fw > 0) { fw = h; }
        if (fw > 0) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, fw, h, h / 2);
        }
    }
    hidden function _txt(dc, x, y, font, col, s, just) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, just);
    }

    // ── Top tab strip: page name + tappable dots (all pages) ─────────────────
    hidden function _pageName(p) {
        if (p == CV_HOME) { return "HOME"; }
        if (p == CV_ACT)  { return "ACTIONS"; }
        if (p == CV_EVO)  { return "EVOLVE"; }
        if (p == CV_DAY)  { return "DAILY"; }
        return "INDEX";
    }
    hidden function _pageColor(p) {
        if (p == CV_ACT) { return Cr.ACCENT; }
        if (p == CV_EVO) { return 0xB46CFF; }
        if (p == CV_DAY) { return Cr.GOLD; }
        if (p == CV_COL) { return 0x4CA8FF; }
        return Cr.TEXT;
    }
    hidden function _drawTabStrip(dc) {
        var cx = _w / 2;
        // Page name — tiny pixel font (drastically smaller than the old
        // FONT_TINY header), shadowed, and white on HOME so it never blends
        // into the bright full-screen diorama.
        var hsc = _h / 190; if (hsc < 2) { hsc = 2; }
        var hcol = (_page == CV_HOME) ? 0xFFFFFF : _pageColor(_page);
        Px.gshC(dc, _pageName(_page), cx, _h * 7 / 100, hsc, hcol);

        // Row of tappable dots.
        var y = _h * 15 / 100;
        var gap = _w * 9 / 100;
        var x0 = cx - gap * (CV_PAGES - 1) / 2;
        _rTabs = new [CV_PAGES];
        var hitW = gap * 90 / 100;
        for (var i = 0; i < CV_PAGES; i++) {
            var dx = x0 + i * gap;
            var on = (i == _page);
            dc.setColor(on ? _pageColor(i) : 0x33414F, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dx, y, on ? 4 : 3);
            if (on) {
                dc.setColor(_pageColor(i), Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(dx, y, 7);
            }
            _rTabs[i] = [dx - hitW / 2, y - _h * 6 / 100, hitW, _h * 12 / 100];
        }
    }

    // Visible + tappable edge chevrons.
    hidden function _drawChevrons(dc) {
        var w = _w * 12 / 100;
        var midY = _h * 50 / 100;
        var zh = _h * 24 / 100;
        _rPrev = [0, midY - zh / 2, w, zh];
        _rNext = [_w - w, midY - zh / 2, w, zh];

        var s = _h * 3 / 100;
        var lx = _w * 4 / 100;
        var rx = _w - _w * 4 / 100;
        dc.setColor(Cr.MUTED, Graphics.COLOR_TRANSPARENT);
        // ◀
        dc.fillPolygon([[lx + s, midY - s], [lx - s, midY], [lx + s, midY + s]]);
        // ▶
        dc.fillPolygon([[rx - s, midY - s], [rx + s, midY], [rx - s, midY + s]]);
    }

    hidden function _drawHint(dc) {
        _txt(dc, _w / 2, _h * 94 / 100, Graphics.FONT_XTINY, 0x5A6B7C,
             "TAP  ·  \u25B2\u25BC  ·  SELECT", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawDemoPill(dc) {
        // DEMO is a showcase-only fast-track — hidden from users in shipped
        // builds. When hidden, draw nothing and keep the hit-rect null so it
        // can never be toggled.
        if (!Cr.SHOW_DEMO) { _rDemo = null; return; }
        var pw = _w * 22 / 100; var ph = _h * 8 / 100;
        var px = _w * 76 / 100 - pw / 2;
        var py = _h * 2 / 100;
        _rDemo = [px, py, pw, ph];
        var on = _demo;
        dc.setColor(on ? 0x3A1030 : Cr.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, ph / 2);
        dc.setColor(on ? 0xFF4C7A : 0x2A3A4A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, ph / 2);
        dc.setColor(on ? 0xFFB0C8 : Cr.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(px + pw / 2, py + ph / 2, Graphics.FONT_XTINY, "DEMO",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── EGG SCREEN ──────────────────────────────────────────────────────────────
    hidden function _drawEggScreen(dc) {
        var cx = _w / 2;
        var hsc = _h / 190; if (hsc < 2) { hsc = 2; }
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        Px.gshC(dc, "EGG " + (_m.seed % 100000), cx, _h * 7 / 100, hsc, 0xFFFFFF);

        var r = _h * 18 / 100;   // ~10% smaller than before
        CreatureArt.drawEgg(dc, _m, cx, _h * 37 / 100, r, _t);

        // DNA progress.
        var by = _h * 64 / 100;
        var bw = _w * 60 / 100; var bx = cx - bw / 2;
        Px.gtxtC(dc, "DNA " + _m.hatchPct() + "%", cx, by - _h * 6 / 100, sc, Cr.TEXT);
        _bar(dc, bx, by, bw, 10, _m.hatchPct(), Cr.speciesColor(_m.species));

        // Countdown.
        _txt(dc, cx, by + _h * 7 / 100, Graphics.FONT_TINY, Cr.TEXT,
             _fmtHMS(_m.hatchRemaining()), Graphics.TEXT_JUSTIFY_CENTER);
        Px.gtxtC(dc, "UNTIL HATCH", cx, by + _h * 15 / 100, sc, Cr.MUTED);

        // BOOST button.
        var bwr = _w * 44 / 100; var bxr = cx - bwr / 2;
        var byr = _h * 84 / 100; var bhr = _h * 12 / 100;
        _rBtnB = [bxr, byr, bwr, bhr];
        _button(dc, _rBtnB, "BOOST", true);
    }

    // ── HOME — the pixel SANCTUARY fills the WHOLE watch ─────────────────────
    // The diorama is the star: it fills the entire screen (x0=0,y0=0,w=_w,h=_h)
    // and a single slim bottom ribbon overlays glanceable stats. Every number /
    // action lives on the sibling pages. Mirrors ISLAND's _drawHome exactly.
    hidden function _drawHome(dc) {
        var mx = _w * 25 / 1000; var my = _h * 25 / 1000;
        try { CreatureArt.drawSanctuary(dc, _m, mx, my, _w - mx * 2, _h - my * 2, _t, false); } catch (e) {}
        try { _homeOverlay(dc); } catch (e) {}
    }

    // Slim bottom ribbon on a dark scrim: banked FOOD (hero currency, left) ·
    // "Lv N · stage" (centre) · a rotating vital (right). Sized from the real
    // FONT_XTINY height so it can never overlap, and ~15% slimmer than the old
    // stacked plates (barH = fhX*1.28 vs the old plate's fhX*1.66).
    hidden function _homeOverlay(dc) {
        var cx = _w / 2;
        var round = (_w == _h);
        // Tiny pixel-font banner: dramatically smaller than FONT_XTINY, bright,
        // crisp, and short enough that it never smothers the diorama. Mirrors
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

        dc.setColor(0x05100A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, barW, barH, barH / 3);
        dc.setColor(Cr.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, barW, barH, barH / 3);

        // Left: banked FOOD with its small berry icon (the hero currency).
        var ipx = gh / 4; if (ipx < 2) { ipx = 2; }
        var ix = bx + pad;
        try { CreatureArt.drawBerryIcon(dc, ix, midY - 2 * ipx, ipx); } catch (e) {}
        Px.gtxt(dc, "" + _m.food, ix + 4 * ipx + sc, gy, sc, 0xFFD9B0);

        // Centre: level + evolution stage. On the narrower round chord the stage
        // is trimmed to 3 chars so it can't clip against the food / vital ends.
        var stage = Cr.stageName(_m.evo);
        if (round && stage.length() > 3) { stage = stage.substring(0, 3); }
        Px.gtxtC(dc, "LV " + _m.level + " " + stage, cx, gy, sc, Cr.TEXT);

        // Right: one rotating vital (energy / mood / xp%).
        var rs = _rotStat();
        Px.gtxt(dc, rs, bx + barW - pad - Px.gtxtW(rs, sc), gy, sc, 0x37D0C0);
    }

    // Rotating right-hand vital for the HOME ribbon. Veterans get a fourth slot
    // showing their ascension count — the centre "LV n stage" text has no room
    // left on a round chord.
    hidden function _rotStat() {
        var n = (_m.asc > 0) ? 4 : 3;
        var idx = (_t / 90) % n;
        if (idx == 0) { return "En " + _m.energy; }
        if (idx == 1) { return "Md " + _m.mood; }
        if (idx == 2) {
            var need = _m.xpNeeded(); if (need < 1) { need = 1; }
            return "XP " + (_m.xp * 100 / need) + "%";
        }
        return "ASC " + _m.asc;
    }

    // First-run explainer overlay: stats are the currency.
    hidden function _drawIntro(dc) {
        var cx = _w / 2;
        dc.setColor(0x050912, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }
        // A little pixel creature to set the tone.
        try { CreatureArt.drawHero(dc, _m, cx, _h * 38 / 100, _h * 20 / 100 / 8, _t); } catch (e) {}

        _txt(dc, cx, _h * 52 / 100, Graphics.FONT_SMALL, Cr.ACCENT,
             "YOUR STATS = FUEL", Graphics.TEXT_JUSTIFY_CENTER);
        _wrapText(dc, cx, _h * 62 / 100, _w * 82 / 100, Graphics.FONT_XTINY, Cr.TEXT,
                  "Your steps, heart rate & activity are the currency here \u2014 move to grow your menagerie.");
        _txt(dc, cx, _h * 82 / 100, Graphics.FONT_XTINY, Cr.GOLD,
             "steps \u2192 growth   HR \u2192 energy", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 91 / 100, Graphics.FONT_XTINY, Cr.MUTED,
             "tap to begin", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────────
    hidden function _drawActions(dc) {
        var cx = _w / 2;
        var fhX = dc.getFontHeight(Graphics.FONT_XTINY);
        var pad = fhX / 3; if (pad < 2) { pad = 2; }

        CreatureArt.drawHero(dc, _m, cx, _h * 20 / 100, _h * 10 / 100 / 8, _t);

        // Vitals block (relocated from HOME): Lv/xp row → xp bar → energy+mood
        // bars, plus the banked food count centred on the header row. Sized
        // from the real FONT_XTINY height so the text can never touch the bars.
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        var gh = 5 * sc;
        var barH = fhX * 42 / 100; if (barH < 4) { barH = 4; }
        var bw = _w * 62 / 100; var bx = cx - bw / 2;
        var need = _m.xpNeeded(); if (need < 1) { need = 1; }
        var rowY = _h * 30 / 100;
        // Tiny pixel-font labels so the vitals plate never smothers the hero.
        // Only two items on the top row (LV left, FOOD right) so long demo
        // numbers can never overlap; the xp fraction sits centred on its own
        // line just above the xp bar.
        Px.gtxt(dc, "LV " + _m.level, bx, rowY, sc, Cr.GOLD);
        var foodStr = "FOOD " + _m.food;
        Px.gtxt(dc, foodStr, bx + bw - Px.gtxtW(foodStr, sc), rowY, sc, 0xFF8A3A);
        var xpStr = _m.xp + "/" + need;
        var xpY = rowY + gh + pad;
        Px.gtxtC(dc, xpStr, cx, xpY, sc, Cr.MUTED);
        var bar1Y = xpY + gh + 2;
        _bar(dc, bx, bar1Y, bw, barH, _m.xp * 100 / need, Cr.ACCENT);
        var bar2Y = bar1Y + barH + pad;
        _bar(dc, bx, bar2Y, bw / 2 - 4, barH, _m.energy, 0xFF8A3A);
        _bar(dc, cx + 4, bar2Y, bw / 2 - 4, barH, _m.mood, 0xFF5A9A);

        var bwb = _w * 56 / 100; var bxb = cx - bwb / 2;
        var bh = _h * 12 / 100;
        var gap = _h * 2 / 100;
        var y0 = _h * 50 / 100;
        _rBtnA = [bxb, y0, bwb, bh];
        _rBtnB = [bxb, y0 + bh + gap, bwb, bh];
        _rBtnC = [bxb, y0 + (bh + gap) * 2, bwb, bh];
        _button(dc, _rBtnA, "FEED", _actCursor == 0);
        _button(dc, _rBtnB, "TRAIN", _actCursor == 1);
        _button(dc, _rBtnC, "EXPLORE", _actCursor == 2);
    }

    // ── EVOLUTION ───────────────────────────────────────────────────────────────
    hidden function _drawEvolution(dc) {
        var cx = _w / 2;
        // At Apex or beyond the page grows an ASCEND button; the trait rows tighten
        // by 1% each so the button always clears the bottom hint line.
        var canAsc = false;
        try { canAsc = _m.canAscend(); } catch (e) {}

        var yy = _h * 21 / 100;
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        var gh = 5 * sc;
        var hdr = Cr.stageName(_m.evo);
        if (_m.asc > 0) { hdr += " A" + _m.asc; }
        Px.gtxtC(dc, hdr, cx, yy, sc, Cr.TEXT);
        var ns = _m.nextStage();
        var lbl = (ns < 0) ? "FINAL FORM" : "NEXT " + Cr.stageName(ns);
        Px.gtxtC(dc, lbl, cx, yy + _h * 7 / 100, sc, 0xB46CFF);

        var bw = _w * 62 / 100; var bx = cx - bw / 2;
        var by = yy + _h * 14 / 100;
        _bar(dc, bx, by, bw, 9, _m.evoProgressPct(), 0xB46CFF);
        Px.gtxtC(dc, "DNA MUT " + _m.mutations, cx, by + _h * 5 / 100, sc, Cr.MUTED);

        // Trait bars (extra spacing). The label sits in a reserved left column so
        // it can never touch the bar that starts after it. Bars are scaled to
        // TRAIT_MAX so a maxed trait fills the box exactly instead of overflowing.
        var ty = by + _h * 12 / 100;
        var rowH = canAsc ? _h * 7 / 100 : _h * 8 / 100;
        var labW = _w * 18 / 100;
        for (var i = 0; i < Cr.TR_N; i++) {
            var ry = ty + i * rowH;
            Px.gtxt(dc, Cr.traitAbbr(i), bx, ry, sc, Cr.TEXT);
            var tv = Cr._clamp(_m.traits[i], 0, Cr.TRAIT_MAX);
            _bar(dc, bx + labW, ry + gh / 2 - 3, bw - labW, 6,
                 tv * 100 / Cr.TRAIT_MAX, Cr.speciesColor(_m.species));
        }

        if (canAsc) {
            var bwr = _w * 46 / 100; var bxr = cx - bwr / 2;
            var byr = _h * 82 / 100; var bhr = _h * 11 / 100;
            _rBtnA = [bxr, byr, bwr, bhr];
            _button(dc, _rBtnA, "ASCEND", true);
        }
    }

    // ── DAILY ───────────────────────────────────────────────────────────────────
    hidden function _drawDaily(dc) {
        var cx = _w / 2;

        var yy = _h * 23 / 100;
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        _wrapText(dc, cx, yy, _w * 78 / 100, Graphics.FONT_XTINY, Cr.TEXT, _m.dailyText());

        var prog = _m.dailyProgress(); var tgt = _m.dailyTarget();
        var bw = _w * 62 / 100; var bx = cx - bw / 2;
        var by = _h * 43 / 100;
        var pct = (tgt > 0) ? prog * 100 / tgt : 100;
        _bar(dc, bx, by, bw, 10, pct, Cr.ACCENT);
        Px.gtxtC(dc, prog + " / " + tgt, cx, by + _h * 7 / 100, sc, Cr.MUTED);

        Px.gtxtC(dc, _m.dailyRewardText(), cx, by + _h * 15 / 100, sc, Cr.GOLD);

        // Streak.
        Px.gtxtC(dc, "STREAK " + _m.streak + "D" + _streakMile(),
                 cx, by + _h * 23 / 100, sc, Cr.TEXT);

        // Claim button.
        var bwr = _w * 46 / 100; var bxr = cx - bwr / 2;
        var byr = _h * 80 / 100; var bhr = _h * 11 / 100;
        _rBtnA = [bxr, byr, bwr, bhr];
        var done = _m.dailyClaimed;
        var can = _m.dailyComplete() && !done;
        _button(dc, _rBtnA, done ? "CLAIMED" : "CLAIM", can);
    }

    hidden function _streakMile() {
        if (_m.streak >= 30) { return " D30"; }
        if (_m.streak >= 7)  { return " D7"; }
        return "";
    }

    // ── COLLECTION ──────────────────────────────────────────────────────────────
    hidden function _drawCollection(dc) {
        var cx = _w / 2;
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        var gh = 5 * sc;
        Px.gtxtC(dc, "DISCOVERED " + _m.seenCount() + "/" + Cr.SPECIES_N,
                 cx, _h * 22 / 100, sc, Cr.MUTED);

        var y = _h * 29 / 100;
        var rowH = _h * 11 / 100;
        var bx = _w * 14 / 100;
        var start = _colScroll;
        if (start < 0) { start = 0; }
        for (var i = 0; i < Cr.SPECIES_N; i++) {
            var idx = i + start;
            if (idx >= Cr.SPECIES_N) { break; }
            var ry = y + i * rowH;
            if (ry > _h * 80 / 100) { break; }
            var seen = _m.isSeen(idx);
            var name = seen ? Cr.speciesName(idx) : "LOCKED";
            var mpx = _h * 8 / 100 / 8; if (mpx < 2) { mpx = 2; }
            try { CreatureArt.drawMob(dc, idx, bx, ry + rowH * 7 / 10, mpx, _t, false, seen); } catch (e) {}
            var ly = ry + rowH * 35 / 100 - gh / 2;
            Px.gtxt(dc, name, bx + _w * 7 / 100, ly, sc, seen ? Cr.TEXT : Cr.MUTED);
            var rp = Cr.rarityPct(seen ? _m.rarityTier() : Cr.RA_COMMON);
            Px.gtxt(dc, rp, _w - bx - Px.gtxtW(rp, sc), ly, sc, Cr.MUTED);
        }

        // A rare "legendary" entry for aspiration.
        Px.gtxtC(dc, "ANCIENT FLAME DRAGON 0.4%", cx, _h * 86 / 100, sc, Cr.GOLD);
    }

    // ── Chrome: buttons / badges ──────────────────────────────────────────────
    hidden function _button(dc, r, label, hot) {
        var fill = hot ? 0x123016 : Cr.PANEL;
        var bord = hot ? Cr.ACCENT : 0x2A3A4A;
        var tcol = hot ? 0xCFF7DA : 0x9FB2C4;
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(bord, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(tcol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(r[0] + r[2] / 2, r[1] + r[3] / 2, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    hidden function _rarityBadge(dc, cx, cy, tier) {
        var c = Cr.rarityColor(tier);
        var s = Cr.rarityName(tier);
        var pw = _w * 40 / 100; var px = cx - pw / 2; var ph = _h * 7 / 100;
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, cy - ph / 2, pw, ph, ph / 2);
        dc.drawText(cx, cy, Graphics.FONT_XTINY, s,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function _drawPopup(dc) {
        var cx = _w / 2;
        var pw = _w * 82 / 100; var px = cx - pw / 2;
        var ph = _h * 12 / 100; var py = _h * 64 / 100;
        dc.setColor(0x0A0F16, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, 8);
        dc.setColor(_demo ? 0xFF4C7A : Cr.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, 8);
        _wrapText(dc, cx, py + ph / 2 - _h * 3 / 100, pw - 12,
                  Graphics.FONT_XTINY, Cr.TEXT, _popup);
    }

    hidden function _drawWelcome(dc) {
        var cx = _w / 2;
        dc.setColor(0x060A0F, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }
        _txt(dc, cx, _h * 16 / 100, Graphics.FONT_SMALL, Cr.ACCENT,
             "WELCOME BACK", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 27 / 100, Graphics.FONT_XTINY, Cr.MUTED,
             "explored while away", Graphics.TEXT_JUSTIFY_CENTER);

        var y = _h * 41 / 100; var step = _h * 11 / 100;
        _txt(dc, cx, y, Graphics.FONT_TINY, Cr.TEXT, "+" + _m.gXp + " XP", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, y + step, Graphics.FONT_TINY, 0xFF8A3A, "+" + _m.gFood + " food", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, y + step * 2, Graphics.FONT_TINY, 0xB46CFF, "+" + _m.gMut + " DNA", Graphics.TEXT_JUSTIFY_CENTER);
        if (_m.newDay) {
            _txt(dc, cx, y + step * 3, Graphics.FONT_XTINY, Cr.GOLD,
                 "Streak " + _m.streak + "d",
                 Graphics.TEXT_JUSTIFY_CENTER);
        }
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Cr.MUTED,
             "tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawHatch(dc) {
        var cx = _w / 2;
        dc.setColor(0x060A0F, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }
        _txt(dc, cx, _h * 14 / 100, Graphics.FONT_SMALL, Cr.GOLD,
             "IT HATCHED!", Graphics.TEXT_JUSTIFY_CENTER);
        CreatureArt.drawCreature(dc, _m, cx, _h * 45 / 100, _h * 15 / 100, _t);
        _txt(dc, cx, _h * 67 / 100, Graphics.FONT_SMALL, Cr.TEXT,
             _m.givenName(), Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 75 / 100, Graphics.FONT_XTINY, Cr.speciesColor(_m.species),
             Cr.speciesName(_m.species) + " · " + Cr.rarityName(_m.rarityTier()),
             Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Cr.MUTED,
             "tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Time + text utilities ────────────────────────────────────────────────
    hidden function _fmtHMS(sec) {
        var h = sec / 3600;
        var m = (sec % 3600) / 60;
        var s = sec % 60;
        return _pad(h) + ":" + _pad(m) + ":" + _pad(s);
    }
    hidden function _pad(n) { return (n < 10) ? "0" + n : "" + n; }

    // Very small word-wrap into up to 2 centred lines.
    hidden function _wrapText(dc, cx, y, maxw, font, col, s) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        if (dc.getTextWidthInPixels(s, font) <= maxw) {
            dc.drawText(cx, y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var words = _split(s);
        var l1 = ""; var l2 = ""; var i = 0;
        while (i < words.size()) {
            var cand = (l1.length() == 0) ? words[i] : l1 + " " + words[i];
            if (dc.getTextWidthInPixels(cand, font) <= maxw) { l1 = cand; }
            else { break; }
            i++;
        }
        while (i < words.size()) {
            l2 = (l2.length() == 0) ? words[i] : l2 + " " + words[i];
            i++;
        }
        var fh = dc.getFontHeight(font);
        dc.drawText(cx, y, font, l1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, y + fh * 85 / 100, font, l2, Graphics.TEXT_JUSTIFY_CENTER);
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
