// ═══════════════════════════════════════════════════════════════════════════
// GameMenu.mc — The shared, unified main menu for every Bitochi game.
//
// A single pushable root view (returned from a game's App.getInitialView) that
// renders an identical, premium three-row menu across all games:
//
//     ┌─────────────────────────┐
//     │        TITLE 1          │   ← per-game title + colours
//     │        TITLE 2          │
//     │       by Bitochi        │
//     │      · signature art ·  │   ← per-game GameHooks.drawArt (optional)
//     │   ▸ START               │   ← accent
//     │     OPTIONS             │
//     │   🏆 LEADERBOARD        │   ← shared LbBadge (gold)
//     │        footer           │   ← optional GameHooks.footerText
//     └─────────────────────────┘
//
// START     → GameHooks.startGame()      (push the gameplay view)
// OPTIONS   → GmOptionsMenu              (per-game settings + Unlock full ver.)
// LEADERBD  → LbScoresView               (shared global leaderboard)
//
// Consistency guarantees: same geometry, same fonts, same selection styling and
// the same gold leaderboard badge on every game. Games only supply colours,
// title, optional art and their settings list.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Timer;

// Row indices on the fixed 3-row main menu.
const GM_START = 0;
const GM_OPTS  = 1;
const GM_BOARD = 2;
const GM_ROWS  = 3;

class GameMenuView extends WatchUi.View {
    hidden var _cfg;
    hidden var _sel;
    hidden var _w;
    hidden var _h;
    hidden var _t;         // animation tick for subtle art motion
    hidden var _timer;
    hidden var _announced;

    function initialize(cfg as MenuConfig) {
        View.initialize();
        _cfg = cfg;
        _sel = GM_START;
        _w = 0; _h = 0;
        _t = 0; _timer = null;
        _announced = false;
    }

    function config() as MenuConfig { return _cfg; }

    function onShow() {
        // One launch announcement per session (server-driven cross-promo /
        // one-shot payment call-to-action). Fully guarded + throttled inside.
        if (!_announced) {
            _announced = true;
            try { Leaderboard.announce(_cfg.gameId, null); } catch (e) {}
        }
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_tick), 66, true); } catch (e) {}
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function _tick() as Void { _t = (_t + 1) % 1000000; WatchUi.requestUpdate(); }

    // Expose the animation phase to art callbacks.
    function phase() as Lang.Number { return _t; }

    // ── Selection / activation ─────────────────────────────────────────────
    function sel() as Lang.Number { return _sel; }
    function setSel(i as Lang.Number) as Void {
        _sel = ((i % GM_ROWS) + GM_ROWS) % GM_ROWS;
        WatchUi.requestUpdate();
    }
    function move(d as Lang.Number) as Void { setSel(_sel + d); }

    function activate() as Void {
        if (_sel == GM_START) {
            if (_cfg.hooks != null) { _cfg.hooks.startGame(); }
            return;
        }
        if (_sel == GM_OPTS) { _openOptions(); return; }
        _openBoard();
    }

    function openOptions() as Void { _openOptions(); }

    hidden function _openOptions() as Void {
        try {
            var m = new GmOptionsMenu(_cfg);
            WatchUi.pushView(m, new GmOptionsDelegate(_cfg), WatchUi.SLIDE_UP);
        } catch (e) {}
    }

    hidden function _openBoard() as Void {
        if (!Leaderboard.isSupported()) { return; }
        // A game may fully own the leaderboard entry point (e.g. push a
        // category picker for several boards). If it handled it, we're done.
        if (_cfg.hooks != null) {
            try { if (_cfg.hooks.openBoard()) { return; } } catch (e) {}
        }
        var variant = "";
        if (_cfg.hooks != null) { variant = _cfg.hooks.lbVariant(); }
        try {
            var v = new LbScoresView(_cfg.gameId, variant, _cfg.lbTitle);
            WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }

    // ── Rendering ───────────────────────────────────────────────────────────
    function onUpdate(dc) {
        try { _draw(dc); }
        catch (e) { try { dc.setColor(_cfg.bg, _cfg.bg); dc.clear(); } catch (e2) {} }
    }

    hidden function _draw(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx = _w / 2;
        var VC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(_cfg.bg, _cfg.bg);
        dc.clear();
        if (_w == _h) {
            dc.setColor(_cfg.circle, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }

        var fhT = dc.getFontHeight(Graphics.FONT_SMALL);
        var fhX = dc.getFontHeight(Graphics.FONT_XTINY);

        // ── Title block geometry (positions computed first, drawn LAST) ──
        // Some games (the idle builders) paint a full diorama in the art band
        // that reaches up behind the title. To keep the title readable we draw
        // the art FIRST, then stamp the title on top of it with a soft shadow.
        var yT1 = (_h * 11) / 100 + fhT / 2;
        var yT2 = yT1 + fhT * 78 / 100;
        var yBrand = (_cfg.title2 != null ? yT2 : yT1) + fhT * 78 / 100;
        var y = yBrand;
        if (_cfg.brand != null && _cfg.brand.length() > 0) { y += fhX; }

        // ── Signature art band (drawn behind the title) ──
        var rg    = rowGeom();
        var rowsTop = rg[3];
        var artTop  = y + 2;
        var artBot  = rowsTop - 4;
        if (_cfg.hooks != null && artBot - artTop > 10) {
            var artCy = (artTop + artBot) / 2;
            try { _cfg.hooks.drawArt(dc, cx, artCy, _w, _h); } catch (e) {}
        }

        // ── Title (on top of the art, with a legibility shadow) ──
        _titleLine(dc, cx, yT1, Graphics.FONT_SMALL, _cfg.col1, _cfg.title1, VC);
        if (_cfg.title2 != null) {
            _titleLine(dc, cx, yT2, Graphics.FONT_SMALL, _cfg.col2, _cfg.title2, VC);
        }
        if (_cfg.brand != null && _cfg.brand.length() > 0) {
            _titleLine(dc, cx, yBrand, Graphics.FONT_XTINY, LB_MUTED, _cfg.brand, VC);
        }

        // ── Rows ──
        var rowH = rg[0]; var rowW = rg[1]; var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < GM_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var isSel = (i == _sel);
            if (i == GM_BOARD) {
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, isSel);
                continue;
            }
            _drawRow(dc, rowX, ry, rowW, rowH, i, isSel, cx);
        }

        // ── Footer ──
        if (_cfg.hooks != null) {
            var ft = _cfg.hooks.footerText();
            if (ft != null && ft.length() > 0) {
                dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, _h - fhX, Graphics.FONT_XTINY, ft, VC);
            }
        }
    }

    // Title line with a soft dark drop-shadow so it stays legible even when a
    // bright signature diorama is painted behind it.
    hidden function _titleLine(dc, cx, y, font, col, s, just) {
        if (s == null) { return; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, y + 1, font, s, just);
        dc.drawText(cx - 1, y + 1, font, s, just);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, font, s, just);
    }

    hidden function _drawRow(dc, x, y, w, h, idx, sel, cx) {
        var isStart = (idx == GM_START);
        var fill    = sel ? (isStart ? 0x123016 : 0x14263A) : 0x111820;
        var border  = sel ? (isStart ? _cfg.accent : 0x55AAFF) : 0x2A3A4A;
        var text    = sel ? (isStart ? 0xCFF7DA : 0xCCEEFF) : 0x8497A8;

        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 5);
        dc.setColor(border, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 5);
        if (sel) {
            dc.setColor(border, Graphics.COLOR_TRANSPARENT);
            var ay = y + h / 2;
            dc.fillPolygon([[x + 6, ay - 4], [x + 6, ay + 4], [x + 12, ay]]);
        }
        var label = (idx == GM_START) ? "START" : "OPTIONS";
        dc.setColor(text, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + h / 2, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Space-aware geometry for the fixed three rows. Rows live in the lower
    // ~45% of the screen; height shrinks to fit small round watches and grows
    // (capped) on large ones so the layout looks intentional everywhere.
    //   [ rowH, rowW, rowX, rowY0, gap ]
    function rowGeom() as Lang.Array {
        var W = _w; var H = _h;
        if (W == 0) { W = 240; }
        if (H == 0) { H = 240; }
        var topZone      = (H * 55) / 100;
        var bottomMargin = (H * 12) / 100; if (bottomMargin < 14) { bottomMargin = 14; }
        var gap          = (H * 2)  / 100; if (gap < 4) { gap = 4; }
        var avail        = (H - bottomMargin) - topZone;
        var rowH         = (avail - gap * (GM_ROWS - 1)) / GM_ROWS;
        if (rowH > 30) { rowH = 30; }
        if (rowH < 18) { rowH = 18; }
        var rowW = (W * 62) / 100; if (rowW < 112) { rowW = 112; }
        if (rowW > W - 8) { rowW = W - 8; }
        var rowX = (W - rowW) / 2;
        var used = GM_ROWS * rowH + (GM_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // Hit-test a tap; returns the row index or -1.
    function rowAt(x, y) as Lang.Number {
        var rg = rowGeom();
        var rowH = rg[0]; var rowW = rg[1]; var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < GM_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) { return i; }
        }
        return -1;
    }
}

// ── Delegate: identical navigation on every game ─────────────────────────────
// UP/DOWN (buttons, page keys, swipes) move the selection; SELECT/ENTER/tap
// activate; BACK exits the app (this is the root view).
class GameMenuDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(v as GameMenuView) {
        BehaviorDelegate.initialize();
        _v = v;
    }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP)    { _v.move(-1); return true; }
        if (k == WatchUi.KEY_DOWN)  { _v.move(1);  return true; }
        if (k == WatchUi.KEY_ENTER) { _v.activate(); return true; }
        if (k == WatchUi.KEY_MENU)  { _v.openOptions(); return true; }
        return false;
    }
    function onSelect()       { _v.activate(); return true; }
    function onMenu()         { _v.openOptions(); return true; }
    function onNextPage()     { _v.move(1);  return true; }
    function onPreviousPage() { _v.move(-1); return true; }

    function onSwipe(evt) {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP)   { _v.move(1);  return true; }
        if (d == WatchUi.SWIPE_DOWN) { _v.move(-1); return true; }
        return true;
    }

    function onTap(evt) {
        var xy = evt.getCoordinates();
        var r  = _v.rowAt(xy[0], xy[1]);
        if (r >= 0) { _v.setSel(r); _v.activate(); }
        return true;
    }
}
