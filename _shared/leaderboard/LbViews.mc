// ═══════════════════════════════════════════════════════════════════════════
// LbViews.mc — Shared leaderboard UI: username entry, scores list, menu badge.
//
// SKELETON. These are pushable WatchUi views so a game only needs to:
//   1. add a "LEADERBOARD" row to its menu
//   2. on activate:  WatchUi.pushView(new LbScoresView(GAME, VARIANT, TITLE),
//                                     new LbScoresDelegate(), WatchUi.SLIDE_LEFT)
//   3. on game over: Leaderboard.submitScore(GAME, score, VARIANT)
//
// LbScoresView auto-prompts for a username (LbNameEntryView) the first time
// if none has been stored yet.
// ═══════════════════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.Lang;

// Palette (matches the web leaderboard at bitochi.com)
const LB_BG       = 0x080C10;
const LB_ACCENT   = 0x00D4FF;
const LB_GOLD     = 0xFBBF24;
const LB_SILVER   = 0x94A3B8;
const LB_BRONZE   = 0xCD7C3A;
const LB_MUTED    = 0x4A6278;
const LB_TEXT     = 0xD6E4F0;

// ═══════════════════════════════════════════════════════════════════════════
// Network fetch helper — notifies a listener implementing onLeaderboard(ok,rows)
// ═══════════════════════════════════════════════════════════════════════════
class LbFetch {
    hidden var _listener;

    function initialize() { _listener = null; }

    function fetch(game, variant, listener) {
        _listener = listener;
        var url = Leaderboard.API_BASE + "/leaderboard?game=" + game;
        if (variant != null && variant.length() > 0) {
            url = url + "&variant=" + variant;
        }
        var opts = {
            :method       => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        try {
            Communications.makeWebRequest(url, null, opts, method(:_onResp));
        } catch (e) {
            _notify(false, null);
        }
    }

    function _onResp(code, data) {
        if (code == 200 && data instanceof Lang.Dictionary) {
            var top = data["top"];
            if (top instanceof Lang.Array) { _notify(true, top); return; }
        }
        _notify(false, null);
    }

    hidden function _notify(ok, rows) {
        if (_listener != null) { _listener.onLeaderboard(ok, rows); }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Username entry — vertical character wheel (UP/DOWN pick, SELECT next char,
// HOLD or last-char SELECT saves, BACK steps back / cancels).
// ═══════════════════════════════════════════════════════════════════════════
class LbNameEntryView extends WatchUi.View {
    hidden var _chars;
    hidden var _pos;
    hidden var _w;
    hidden var _h;

    function initialize() {
        View.initialize();
        _chars = new [Leaderboard.NAME_LEN];
        for (var i = 0; i < Leaderboard.NAME_LEN; i++) { _chars[i] = Leaderboard.SPACE_IDX; }
        var existing = Leaderboard.loadUser();
        if (existing != null) {
            var up = existing.toUpper();
            for (var i = 0; i < Leaderboard.NAME_LEN && i < up.length(); i++) {
                var idx = Leaderboard.ALPHABET.find(up.substring(i, i + 1));
                _chars[i] = (idx != null) ? idx : Leaderboard.SPACE_IDX;
            }
        }
        _pos = 0;
        _w = 0; _h = 0;
    }

    // ── intents called by the delegate ──
    function adj(d) {
        var n = Leaderboard.ALPHABET.length();
        _chars[_pos] = (_chars[_pos] + d + n) % n;
        WatchUi.requestUpdate();
    }
    function next()    { _pos = (_pos + 1) % Leaderboard.NAME_LEN; WatchUi.requestUpdate(); }
    function prev()    { _pos = (_pos + Leaderboard.NAME_LEN - 1) % Leaderboard.NAME_LEN; WatchUi.requestUpdate(); }
    function isLast()  { return _pos == Leaderboard.NAME_LEN - 1; }
    function atStart() { return _pos == 0; }
    function save()    { Leaderboard.saveUser(Leaderboard.buildName(_chars)); }

    hidden function _chAt(idx) {
        var ch = Leaderboard.ALPHABET.substring(idx, idx + 1);
        if (idx == Leaderboard.SPACE_IDX) { return "_"; }
        return ch;
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx = _w / 2;

        dc.setColor(LB_BG, LB_BG); dc.clear();

        dc.setColor(LB_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 8 / 100, Graphics.FONT_XTINY,
                    "ENTER NAME", Graphics.TEXT_JUSTIFY_CENTER);

        // Full name with cursor brackets on the active position
        var disp = "";
        for (var i = 0; i < Leaderboard.NAME_LEN; i++) {
            var ch = _chAt(_chars[i]);
            if (i == _pos) { disp = disp + "[" + ch + "]"; }
            else           { disp = disp + " " + ch + " "; }
        }
        dc.setColor(LB_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 22 / 100, Graphics.FONT_XTINY,
                    disp, Graphics.TEXT_JUSTIFY_CENTER);

        // Character wheel for the active position
        var ci   = _chars[_pos];
        var cLen = Leaderboard.ALPHABET.length();
        var midY = _h * 50 / 100;
        var step = _h * 11 / 100;

        dc.setColor(0x33414F, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, midY - step, Graphics.FONT_SMALL,
                    _chAt((ci + cLen - 1) % cLen), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, midY - step / 2, Graphics.FONT_LARGE,
                    _chAt(ci), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x33414F, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, midY + step, Graphics.FONT_SMALL,
                    _chAt((ci + 1) % cLen), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h - 16, Graphics.FONT_XTINY,
                    "UP/DN pick  SEL next", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class LbNameEntryDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(v) { BehaviorDelegate.initialize(); _v = v; }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP)    { _v.adj(1);  return true; }
        if (k == WatchUi.KEY_DOWN)  { _v.adj(-1); return true; }
        if (k == WatchUi.KEY_ENTER) { return _advance(); }
        if (k == WatchUi.KEY_ESC)   { return onBack(); }
        return false;
    }
    function onSelect()       { return _advance(); }
    function onNextPage()     { _v.adj(1);  return true; }
    function onPreviousPage() { _v.adj(-1); return true; }

    // Long-press = save & exit at any time.
    function onHold(evt)      { _v.save(); WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }

    hidden function _advance() {
        if (_v.isLast()) {
            _v.save();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            _v.next();
        }
        return true;
    }

    function onBack() {
        if (_v.atStart()) {
            // Cancel — still save what we have so the player isn't stuck nameless.
            _v.save();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            _v.prev();
        }
        return true;
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Scores list — fetches top-N for a game[/variant] and renders it.
// Auto-prompts for a username on first use.
// ═══════════════════════════════════════════════════════════════════════════
class LbScoresView extends WatchUi.View {
    hidden var _game;
    hidden var _variant;
    hidden var _title;
    hidden var _rows;
    hidden var _state;   // 0 loading, 1 ok, 2 error, 3 empty
    hidden var _fetch;
    hidden var _w;
    hidden var _h;

    function initialize(game, variant, title) {
        View.initialize();
        _game    = game;
        _variant = variant;
        _title   = (title != null) ? title : "LEADERBOARD";
        _rows    = null;
        _state   = 0;
        _fetch   = null;
        _w = 0; _h = 0;
    }

    function onShow() {
        // First-run: collect a username, then this view becomes visible again.
        if (!Leaderboard.hasUser()) {
            var nv = new LbNameEntryView();
            WatchUi.pushView(nv, new LbNameEntryDelegate(nv), WatchUi.SLIDE_LEFT);
            return;
        }
        _state = 0;
        _fetch = new LbFetch();
        _fetch.fetch(_game, _variant, self);
        WatchUi.requestUpdate();
    }

    // LbFetch listener callback
    function onLeaderboard(ok, rows) {
        if (!ok)                              { _state = 2; }
        else if (rows == null || rows.size() == 0) { _state = 3; }
        else { _rows = rows; _state = 1; }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx = _w / 2;

        dc.setColor(LB_BG, LB_BG); dc.clear();

        // Header
        dc.setColor(LB_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 6 / 100, Graphics.FONT_XTINY,
                    _title, Graphics.TEXT_JUSTIFY_CENTER);
        if (_variant != null && _variant.length() > 0) {
            dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 14 / 100, Graphics.FONT_XTINY,
                        _variant, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_state == 0) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h / 2, Graphics.FONT_XTINY,
                        "Loading...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        if (_state == 2) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h / 2 - 10, Graphics.FONT_XTINY,
                        "No connection", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, _h / 2 + 10, Graphics.FONT_XTINY,
                        "try again later", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        if (_state == 3) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h / 2, Graphics.FONT_XTINY,
                        "No scores yet -- be first!", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Rows (top 10)
        var top = (_variant != null && _variant.length() > 0) ? _h * 22 / 100 : _h * 18 / 100;
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY) + 2;
        var n = _rows.size(); if (n > 10) { n = 10; }
        for (var i = 0; i < n; i++) {
            var row  = _rows[i];
            var rank = row["r"];
            var u    = row["u"];
            var s    = row["s"];
            var clr  = LB_TEXT;
            if (rank == 1) { clr = LB_GOLD; }
            else if (rank == 2) { clr = LB_SILVER; }
            else if (rank == 3) { clr = LB_BRONZE; }

            var y = top + i * lineH;
            dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w * 10 / 100, y, Graphics.FONT_XTINY,
                        rank.toString(), Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(_w * 22 / 100, y, Graphics.FONT_XTINY,
                        (u != null) ? u : "anon", Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(_w * 90 / 100, y, Graphics.FONT_XTINY,
                        (s != null) ? s.toString() : "0", Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }
}

class LbScoresDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onBack()   { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onSelect() { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
}

// ═══════════════════════════════════════════════════════════════════════════
// Menu badge helper — draws a hype-y "LEADERBOARD" row for a game's own menu.
// Returns nothing; the caller positions it. Gold-accented so it stands out.
// ═══════════════════════════════════════════════════════════════════════════
module LbBadge {
    function drawRow(dc, x, y, w, rowH, selected) {
        dc.setColor(selected ? 0x4A3A10 : 0x2A2410, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, rowH, 5);
        dc.setColor(selected ? 0xFFD24A : 0xBB8A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, rowH, 5);

        if (selected) {
            var ay = y + rowH / 2;
            dc.fillPolygon([[x + 5, ay - 4], [x + 5, ay + 4], [x + 11, ay]]);
        }
        // Small trophy glyph drawn with primitives (no emoji dependency)
        var tx = x + 16;
        var tyc = y + rowH / 2;
        dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx - 4, tyc - 5, 8, 5);          // cup bowl
        dc.fillRectangle(tx - 1, tyc, 2, 4);              // stem
        dc.fillRectangle(tx - 4, tyc + 4, 8, 2);          // base

        var cx = x + w / 2 + 6;
        dc.setColor(selected ? 0xFFE49A : 0xE0B84A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + (rowH - 14) / 2, Graphics.FONT_XTINY,
                    "LEADERBOARD", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
