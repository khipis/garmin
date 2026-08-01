// ═══════════════════════════════════════════════════════════════════════════
// GameMenu.mc — The shared, unified main menu for every Bitochi games.
//
// Rows (dynamic):
//   [RESUME]     ← only when GameHooks.hasResume() (SaveResume blob exists)
//    START       ← always a fresh run
//    OPTIONS
//    LEADERBOARD
//
// START     → GameHooks.startGame()
// RESUME    → GameHooks.resumeGame()
// OPTIONS   → GmOptionsMenu
// LEADERBD  → LbScoresView (or hooks.openBoard())
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Timer;

class GameMenuView extends WatchUi.View {
    hidden var _cfg;
    hidden var _sel;
    hidden var _w;
    hidden var _h;
    hidden var _t;
    hidden var _timer;
    hidden var _announced;
    hidden var _ids;    // Array of row ids: :resume / :start / :opts / :board
    hidden var _nRows;

    function initialize(cfg as MenuConfig) {
        View.initialize();
        _cfg = cfg;
        _sel = 0;
        _w = 0; _h = 0;
        _t = 0; _timer = null;
        _announced = false;
        _rebuildRows();
    }

    function config() as MenuConfig { return _cfg; }

    hidden function _rebuildRows() as Void {
        _ids = [];
        var hasR = false;
        try {
            if (_cfg.hooks != null) { hasR = _cfg.hooks.hasResume(); }
        } catch (e) { hasR = false; }
        if (hasR) { _ids.add(:resume); }
        _ids.add(:start);
        _ids.add(:opts);
        _ids.add(:board);
        _nRows = _ids.size();
        if (_sel >= _nRows) { _sel = 0; }
    }

    function onShow() {
        _rebuildRows();   // pick up a save created since last show
        if (!_announced) {
            _announced = true;
            try { Leaderboard.announce(_cfg.gameId, null); } catch (e) {}
        }
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_tick), 66, true); } catch (e) {}
        WatchUi.requestUpdate();
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function _tick() as Void { _t = (_t + 1) % 1000000; WatchUi.requestUpdate(); }
    function phase() as Lang.Number { return _t; }

    function sel() as Lang.Number { return _sel; }
    function setSel(i as Lang.Number) as Void {
        if (_nRows <= 0) { return; }
        _sel = ((i % _nRows) + _nRows) % _nRows;
        WatchUi.requestUpdate();
    }
    function move(d as Lang.Number) as Void { setSel(_sel + d); }

    function activate() as Void {
        if (_nRows <= 0 || _sel < 0 || _sel >= _nRows) { return; }
        var id = _ids[_sel];
        if (id == :resume) {
            if (_cfg.hooks != null) {
                try { _cfg.hooks.resumeGame(); } catch (e) {}
            }
            return;
        }
        if (id == :start) {
            if (_cfg.hooks != null) { _cfg.hooks.startGame(); }
            return;
        }
        if (id == :opts) { _openOptions(); return; }
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

        var yT1 = (_h * 11) / 100 + fhT / 2;
        var yT2 = yT1 + fhT * 78 / 100;
        var yBrand = (_cfg.title2 != null ? yT2 : yT1) + fhT * 78 / 100;
        var y = yBrand;
        if (_cfg.brand != null && _cfg.brand.length() > 0) { y += fhX; }

        var rg = rowGeom();
        var rowsTop = rg[3];
        var artTop  = y + 2;
        var artBot  = rowsTop - 4;
        if (_cfg.hooks != null && artBot - artTop > 10) {
            var artCy = (artTop + artBot) / 2;
            try { _cfg.hooks.drawArt(dc, cx, artCy, _w, _h); } catch (e) {}
        }

        _titleLine(dc, cx, yT1, Graphics.FONT_SMALL, _cfg.col1, _cfg.title1, VC);
        if (_cfg.title2 != null) {
            _titleLine(dc, cx, yT2, Graphics.FONT_SMALL, _cfg.col2, _cfg.title2, VC);
        }
        if (_cfg.brand != null && _cfg.brand.length() > 0) {
            _titleLine(dc, cx, yBrand, Graphics.FONT_XTINY, LB_MUTED, _cfg.brand, VC);
        }

        var rowH = rg[0]; var rowW = rg[1]; var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < _nRows; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var isSel = (i == _sel);
            var id = _ids[i];
            if (id == :board) {
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, isSel);
                continue;
            }
            _drawRow(dc, rowX, ry, rowW, rowH, id, isSel, cx);
        }

        if (_cfg.hooks != null) {
            var ft = _cfg.hooks.footerText();
            if (ft != null && ft.length() > 0) {
                // The footer sits one line off the bottom, where a round display
                // is barely half as wide as it is at the centre. Games kept
                // shipping status lines that ran under the bezel, so trim here
                // rather than relying on every caller to guess a safe length.
                var fy = _h - fhX;
                var fw = _chord(fy) * 94 / 100;
                while (ft.length() > 4 && dc.getTextWidthInPixels(ft, Graphics.FONT_XTINY) > fw) {
                    ft = ft.substring(0, ft.length() - 2);
                }
                // Footers are separator-joined, so a trim usually lands mid-join
                // and leaves a dangling bullet or dash hanging off the end.
                while (ft.length() > 1) {
                    var tail = ft.substring(ft.length() - 1, ft.length());
                    if (!tail.equals(" ") && !tail.equals("\u00b7") && !tail.equals("-")) { break; }
                    ft = ft.substring(0, ft.length() - 1);
                }
                dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, fy, Graphics.FONT_XTINY, ft, VC);
            }
        }
    }

    // Width the display actually offers at this y. Square screens get the lot.
    hidden function _chord(y) {
        if (_w != _h) { return _w; }
        var r = _w / 2;
        var dy = y - r;
        var q = r * r - dy * dy;
        return (q > 0) ? Math.sqrt(q).toNumber() * 2 : _w;
    }

    hidden function _titleLine(dc, cx, y, font, col, s, just) {
        if (s == null) { return; }
        // Titles are centred near the top of a round display, where the chord is
        // already well short of the full width. A two-word game name at
        // FONT_SMALL runs under the bezel, so step the font down until it fits.
        var f = font;
        var maxw = _chord(y) * 90 / 100;
        var fonts = [font, Graphics.FONT_TINY, Graphics.FONT_XTINY];
        for (var i = 0; i < fonts.size(); i++) {
            f = fonts[i];
            if (dc.getTextWidthInPixels(s, f) <= maxw) { break; }
        }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, y + 1, f, s, just);
        dc.drawText(cx - 1, y + 1, f, s, just);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, f, s, just);
    }

    hidden function _drawRow(dc, x, y, w, h, id, sel, cx) {
        var isHi = (id == :start || id == :resume);
        var fill    = sel ? (isHi ? 0x123016 : 0x14263A) : 0x111820;
        var border  = sel ? (isHi ? _cfg.accent : 0x55AAFF) : 0x2A3A4A;
        var text    = sel ? (isHi ? 0xCFF7DA : 0xCCEEFF) : 0x8497A8;
        if (id == :resume && sel) {
            fill = 0x1A2030; border = 0xFBBF24; text = 0xFFE9A8;
        }

        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 5);
        dc.setColor(border, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 5);
        if (sel) {
            dc.setColor(border, Graphics.COLOR_TRANSPARENT);
            var ay = y + h / 2;
            dc.fillPolygon([[x + 6, ay - 4], [x + 6, ay + 4], [x + 12, ay]]);
        }
        var label = "OPTIONS";
        if (id == :resume) { label = "RESUME"; }
        else if (id == :start) { label = "START"; }
        dc.setColor(text, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + h / 2, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function rowGeom() as Lang.Array {
        var W = _w; var H = _h;
        if (W == 0) { W = 240; }
        if (H == 0) { H = 240; }
        var n = _nRows; if (n < 1) { n = 3; }
        // With RESUME (4 rows) pull the block up a bit so everything fits.
        var topPct = (n >= 4) ? 48 : 55;
        var topZone      = (H * topPct) / 100;
        var bottomMargin = (H * 10) / 100; if (bottomMargin < 12) { bottomMargin = 12; }
        var gap          = (H * 15) / 1000; if (gap < 3) { gap = 3; }
        var avail        = (H - bottomMargin) - topZone;
        var rowH         = (avail - gap * (n - 1)) / n;
        if (rowH > 28) { rowH = 28; }
        if (rowH < 16) { rowH = 16; }
        var rowW = (W * 62) / 100; if (rowW < 112) { rowW = 112; }
        if (rowW > W - 8) { rowW = W - 8; }
        var rowX = (W - rowW) / 2;
        var used = n * rowH + (n - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    function rowAt(x, y) as Lang.Number {
        var rg = rowGeom();
        var rowH = rg[0]; var rowW = rg[1]; var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < _nRows; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) { return i; }
        }
        return -1;
    }
}

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
