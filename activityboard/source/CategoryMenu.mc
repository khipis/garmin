// ═══════════════════════════════════════════════════════════════════════════
// CategoryMenu.mc — "FLEX ON THE WORLD" chooser + the core addictive loop.
//
// Custom-drawn View + BehaviorDelegate (NOT WatchUi.Menu2). Activity Board's
// manifest reaches all the way back to button-only, pre-Menu2 hardware
// (fenix3, edge_520, fr230/235/630/920xt, original vivoactive, d2bravo, ...).
// WatchUi.Menu2 / the 4-arg WatchUi.MenuItem(title,subtitle,id,opts) / and
// WatchUi.ToggleMenuItem all require API 3.x+ and are simply absent on those
// devices — using them there throws at runtime the instant this screen opens,
// which is exactly the "crashes when I try to flex my stats" report. A plain
// View drawn with Graphics primitives has been supported since Connect IQ 1.x,
// so this menu now works identically on every device the manifest lists.
//
// Two submission modes:
//   Flex Score  → submits ALL variants in a sequential queue (one request per
//                 1400 ms so Garmin's single-in-flight limit is never hit), then
//                 shows the post-game standing for the flex board.
//   Any stat    → submits just that one variant, shows its standing.
//
// Garmin's Communications.makeWebRequest only allows one pending request at a
// time. Rapid-fire calls throw InvalidValueException (silently swallowed by
// LbSubmitter). The FlexBatchSender queues submissions 1400 ms apart and only
// opens the standing after the final request, avoiding overlapping fetches.
//
// _batchSender lives at module scope so the timer chain survives popView
// (otherwise the FlexMenuDelegate is GC'd before the queue finishes).
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Timer;
using Toybox.Application;

const FLEX_BOARD_ID  = "__board";
const FLEX_RENAME_ID = "__rename";
const FLEX_FX_ID     = "__fx";

// Module-level ref so the batch-timer chain isn't GC'd after popView.
var _batchSender = null;

// ── Sequential score submitter ────────────────────────────────────────────────
// Submits an array of [score, variant] pairs one at a time, 650 ms apart.
class FlexBatchSender {
    hidden var _items;   // Array of [score, variant] pairs
    hidden var _idx;
    hidden var _timer;

    function initialize(items as Lang.Array) {
        _items = items;
        _idx   = 0;
        _timer = null;
    }

    function start() as Void { _submit(); }

    function _submit() as Void {
        if (_idx >= _items.size()) { _finish(); return; }
        var item = _items[_idx];
        _idx++;
        if (_idx == 1) {
            // The headline flex score is the one Daily Challenge attempt for
            // this real-world snapshot.
            Leaderboard.submitScore(LB_GAME_ID, item[0], item[1]);
        } else {
            // Remaining category boards belong to the same play/session.
            Leaderboard.submitScoreAux(LB_GAME_ID, item[0], item[1]);
        }
        // Schedule the next item only if there are more to send.
        if (_idx < _items.size()) {
            if (_timer == null) { _timer = new Timer.Timer(); }
            // The first (flex) item may also complete today's challenge and
            // trigger its small completion POST. Give that path extra room.
            var delay = (_idx == 1) ? 2800 : 1400;
            _timer.start(method(:_submit), delay, false);
        } else {
            _finish();
        }
    }

    hidden function _finish() as Void {
        if (_timer != null) { try { _timer.stop(); } catch (e) {} _timer = null; }
        _items = [];
        // The shared post-game helper waits another 1.6 s before fetching,
        // leaving the final score request exclusive use of Communications.
        Leaderboard.showPostGame(LB_GAME_ID, Metrics.V_FLEX, "ACTIVITY BOARD");
        _batchSender = null;
    }
}

// ── Custom scrollable rows menu (Menu2-free — see header note) ──────────────
class FlexMenuView extends WatchUi.View {
    hidden var _snap;
    hidden var _rows;      // Array of [label, subtitleOrNull, id]
    hidden var _sel;       // button-nav cursor row index
    hidden var _scrollY;
    hidden var _maxScroll;
    hidden var _w;
    hidden var _h;
    hidden var _rowH;
    hidden var _titleH;

    function initialize(snap as Lang.Dictionary) {
        View.initialize();
        _snap = snap;
        _sel = 0;
        _scrollY = 0; _maxScroll = 0;
        _w = 0; _h = 0;
        var fh = 12;
        try { fh = Graphics.getFontHeight(Graphics.FONT_XTINY); } catch (e) {}
        _rowH   = fh + (fh * 9) / 10; if (_rowH < 24) { _rowH = 24; }
        _titleH = fh + fh / 2;
        _rows = [];
        // Fully guarded: this is the FIRST screen that ever touches the real
        // snapshot + catalog + username together (older/small-heap watches in
        // the manifest — fenix3, edge_520, fr230/235/630/920xt, original
        // vivoactive — have crashed here before on transient allocation /
        // formatting failures while a network callback is also in flight).
        // A failure here must fall back to a minimal, still-usable menu
        // instead of taking the whole app down.
        try { _buildRows(); } catch (e) {}
        if (_rows.size() == 0) { _buildFallbackRows(); }
    }

    hidden function _buildRows() as Void {
        var rows = [];
        var flex = Metrics.flexScore(_snap);
        rows.add(["Flex Score", Metrics.groupNum(flex) + " pts", Metrics.V_FLEX]);
        var cat = Metrics.catalog();
        for (var i = 0; i < cat.size(); i++) {
            var v = cat[i][0];
            rows.add([cat[i][1], Metrics.display(v, Metrics.valueFor(v, _snap)), v]);
        }
        rows.add(["Leaderboard", "browse the boards", FLEX_BOARD_ID]);
        var nm = null;
        try { nm = Leaderboard.loadUser(); } catch (e) {}
        rows.add(["Change name", (nm != null) ? nm : "set your tag", FLEX_RENAME_ID]);
        var fxOn = true;
        try { fxOn = AbFx.isOn(); } catch (e) {}
        rows.add(["Sound & Haptics", fxOn ? "ON" : "OFF", FLEX_FX_ID]);
        _rows = rows;
    }

    // Minimal, allocation-light menu used only if the full build above threw —
    // still lets the player reach the leaderboard / rename / fx toggle.
    hidden function _buildFallbackRows() as Void {
        _rows = [
            ["Leaderboard",      "browse the boards", FLEX_BOARD_ID],
            ["Change name",      "set your tag",       FLEX_RENAME_ID],
            ["Sound & Haptics",  "toggle",              FLEX_FX_ID]
        ];
    }

    function onShow() {}
    function onHide() {}

    function rowCount() as Lang.Number { return _rows.size(); }
    function selIndex() as Lang.Number { return _sel; }
    function idAt(i as Lang.Number) as Lang.String or Null {
        if (i < 0 || i >= _rows.size()) { return null; }
        return _rows[i][2];
    }

    // Re-render a single row's subtitle after a toggle/rename without
    // rebuilding the whole snapshot-derived list.
    function refreshRow(id as Lang.String) as Void {
        for (var i = 0; i < _rows.size(); i++) {
            if (_rows[i][2].equals(id)) {
                if (id.equals(FLEX_FX_ID)) {
                    _rows[i] = [_rows[i][0], AbFx.isOn() ? "ON" : "OFF", id];
                } else if (id.equals(FLEX_RENAME_ID)) {
                    var nm = Leaderboard.loadUser();
                    _rows[i] = [_rows[i][0], (nm != null) ? nm : "set your tag", id];
                }
                return;
            }
        }
    }

    function moveSel(d as Lang.Number) as Void {
        var n = _rows.size();
        if (n <= 0) { return; }
        _sel = (_sel + d + n) % n;
        _ensureVisible();
        WatchUi.requestUpdate();
    }

    hidden function _ensureVisible() as Void {
        var top = _sel * _rowH;
        var bot = top + _rowH;
        if (top < _scrollY) { _scrollY = top; }
        if (bot > _scrollY + (_h - _titleH)) { _scrollY = bot - (_h - _titleH); }
        if (_scrollY < 0) { _scrollY = 0; }
        if (_scrollY > _maxScroll) { _scrollY = _maxScroll; }
    }

    function scrollBy(dy as Lang.Number) as Void {
        _scrollY += dy;
        if (_scrollY < 0) { _scrollY = 0; }
        if (_scrollY > _maxScroll) { _scrollY = _maxScroll; }
        WatchUi.requestUpdate();
    }
    function pageStep() as Lang.Number {
        var s = _h / 2;
        return (s < 30) ? 30 : s;
    }

    // Hit-test a screen point against the (scrolled) row list. Returns -1 if
    // the point misses every row (e.g. it landed on the fixed title bar).
    function rowAt(x as Lang.Number, y as Lang.Number) as Lang.Number {
        if (_rowH <= 0 || y < _titleH) { return -1; }
        var idx = (y - _titleH + _scrollY) / _rowH;
        if (idx < 0 || idx >= _rows.size()) { return -1; }
        return idx;
    }

    // Fully guarded: a render failure must never surface as an IQ crash —
    // fall back to a plain cleared screen so BACK still works.
    function onUpdate(dc) {
        try { _draw(dc); }
        catch (e) { try { dc.setColor(LB_BG, LB_BG); dc.clear(); } catch (e2) {} }
    }

    hidden function _draw(dc) as Void {
        _w = dc.getWidth();
        _h = dc.getHeight();

        dc.setColor(LB_BG, LB_BG);
        dc.clear();

        _maxScroll = _rows.size() * _rowH - (_h - _titleH);
        if (_maxScroll < 0) { _maxScroll = 0; }
        if (_scrollY > _maxScroll) { _scrollY = _maxScroll; }
        if (_scrollY < 0) { _scrollY = 0; }

        var VC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var VL = Graphics.TEXT_JUSTIFY_LEFT   | Graphics.TEXT_JUSTIFY_VCENTER;
        var VR = Graphics.TEXT_JUSTIFY_RIGHT  | Graphics.TEXT_JUSTIFY_VCENTER;

        // Fixed title bar (never scrolls).
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _titleH / 2, Graphics.FONT_XTINY, "FLEX ON WORLD", VC);
        dc.setColor(0x1A2630, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, _titleH, _w, _titleH);

        var lPad = (_w * 4) / 100; if (lPad < 8) { lPad = 8; }
        var n = _rows.size();
        for (var i = 0; i < n; i++) {
            var ry = _titleH + i * _rowH - _scrollY;
            if (ry + _rowH < _titleH || ry > _h) { continue; }
            var cy  = ry + _rowH / 2;
            var sel = (i == _sel);
            if (sel) {
                dc.setColor(0x10303C, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(0, ry, _w, _rowH);
            }
            dc.setColor(sel ? LB_ACCENT : LB_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lPad, cy, Graphics.FONT_XTINY, _rows[i][0], VL);
            if (_rows[i][1] != null) {
                dc.setColor(sel ? LB_GOLD : LB_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w - lPad, cy, Graphics.FONT_XTINY, _rows[i][1], VR);
            }
        }

        _drawScrollbar(dc);
    }

    hidden function _drawScrollbar(dc) as Void {
        if (_maxScroll <= 0) { return; }
        var contentH = _rows.size() * _rowH;
        var trackH   = _h - _titleH - 4;
        var trackY   = _titleH + 2;
        var trackX   = _w - 4;

        var thumbH = (trackH * (_h - _titleH)) / contentH;
        if (thumbH < 10) { thumbH = 10; }
        if (thumbH > trackH) { thumbH = trackH; }
        var thumbY = trackY + ((trackH - thumbH) * _scrollY) / _maxScroll;

        dc.setColor(0x1A2630, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(trackX, trackY, 3, trackH, 1);
        dc.setColor(LB_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(trackX, thumbY, 3, thumbH, 1);
    }
}

// ── Delegate ─────────────────────────────────────────────────────────────────
class FlexMenuDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;
    hidden var _snap;

    function initialize(view as FlexMenuView, snap as Lang.Dictionary) {
        BehaviorDelegate.initialize();
        _view = view;
        _snap = snap;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP)   { _view.moveSel(-1); return true; }
        if (k == WatchUi.KEY_DOWN) { _view.moveSel(1);  return true; }
        if (k == WatchUi.KEY_ESC)  { return onBack(); }
        // ENTER / MENU / anything else activates the focused row.
        _activate(_view.selIndex());
        return true;
    }
    function onSelect()       { _activate(_view.selIndex()); return true; }
    function onMenu()         { _activate(_view.selIndex()); return true; }
    function onNextPage()     { _view.moveSel(1);  return true; }
    function onPreviousPage() { _view.moveSel(-1); return true; }
    function onBack()         { WatchUi.popView(WatchUi.SLIDE_DOWN); return true; }

    function onSwipe(evt) {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP)   { _view.scrollBy(_view.pageStep());  return true; }
        if (d == WatchUi.SWIPE_DOWN) { _view.scrollBy(-_view.pageStep()); return true; }
        return false;
    }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        if (xy == null) { return true; }
        var idx = _view.rowAt(xy[0], xy[1]);
        if (idx < 0) { return true; }
        _activate(idx);
        return true;
    }

    // Fully guarded top-to-bottom: this drives every row's navigation +
    // submission, so a single unguarded throw here (network, storage, or a
    // malformed snapshot value) must never surface as an IQ crash — it just
    // silently no-ops that tap instead of taking the whole app down.
    hidden function _activate(idx as Lang.Number) as Void {
        try { _activateImpl(idx); } catch (e) {}
    }

    hidden function _activateImpl(idx as Lang.Number) as Void {
        var id = _view.idAt(idx);
        if (id == null) { return; }

        // Sound & Haptics toggle — stay in the menu, just flip + persist + redraw.
        if (id.equals(FLEX_FX_ID)) {
            var newOn = !AbFx.isOn();
            try { Application.Storage.setValue(AB_FX_KEY, newOn ? 0 : 1); } catch (e) {}
            _view.refreshRow(FLEX_FX_ID);
            WatchUi.requestUpdate();
            if (newOn) { AbFx.tone(0); }
            return;
        }

        WatchUi.popView(WatchUi.SLIDE_DOWN);

        // ── Browse only (no submission) ──────────────────────────────────────
        if (id.equals(FLEX_BOARD_ID)) {
            _openBoard(Metrics.V_FLEX);
            return;
        }
        if (id.equals(FLEX_RENAME_ID)) {
            try {
                var nv = new LbNameEntryView();
                WatchUi.pushView(nv, new LbNameEntryDelegate(nv), WatchUi.SLIDE_LEFT);
            } catch (e) {}
            return;
        }

        // ── Flex Score: submit ALL variants sequentially ─────────────────────
        // Build the queue: flex first (so the standing query matches the
        // post-game card), then every individual metric.
        if (id.equals(Metrics.V_FLEX)) {
            var items = new [0] as Lang.Array;
            items.add([Metrics.flexScore(_snap), Metrics.V_FLEX]);
            var cat = Metrics.catalog();
            for (var i = 0; i < cat.size(); i++) {
                var v   = cat[i][0];
                var val = Metrics.valueFor(v, _snap);
                items.add([val, v]);
            }
            // Subtle confirm as the whole board is flexed to the world.
            AbFx.tone(0);
            AbFx.vibe(20, 25);
            _batchSender = new FlexBatchSender(items);
            _batchSender.start();
            return;
        }

        // ── Individual metric: submit only that variant ──────────────────────
        // Subtle confirm tick on submission.
        AbFx.tone(0);
        AbFx.vibe(20, 25);
        var val = Metrics.valueFor(id, _snap);
        Leaderboard.submitScore(LB_GAME_ID, val, id);
        Leaderboard.showPostGame(LB_GAME_ID, id, "ACTIVITY BOARD");
    }

    hidden function _openBoard(variant as Lang.String) as Void {
        try {
            var v = new LbScoresView(LB_GAME_ID, variant, "ACTIVITY BOARD");
            WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }
}
