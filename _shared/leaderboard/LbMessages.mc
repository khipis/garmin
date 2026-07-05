// ═══════════════════════════════════════════════════════════════════════════
// LbMessages.mc — Custom in-app messages / announcements.
//
// The owner configures messages server-side (D1 `messages` table, edited from
// stats.html). Each game fetches its resolved bundle on launch and shows the
// right one at the right moment:
//   • launch   — a pre-game nudge (discover other games, promote a paid app…)
//   • postgame — after a run ends (support Bitochi / Buy Me a Coffee…)
//   • reset    — shown once after the leaderboard was wiped (re-engagement)
//
// Flow:
//   Leaderboard.logLaunch(game)           → also fetches + caches the bundle
//   Leaderboard.announce(game, fallback)  → shows reset-or-launch when a game's
//                                            menu appears (throttled)
//   Leaderboard.showPostGame(...)         → shows the postgame message (if due)
//                                            on top of the leaderboard pop-up
//
// The bundle is cached in Application.Storage so a message can be shown from the
// PREVIOUS session's data without waiting on the network at startup; this run's
// fetch simply refreshes it for next time. Works on any game (even ones without
// a leaderboard, e.g. breathtrainingtool) as long as Communications is granted.
// ═══════════════════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Application;
using Toybox.PersistedContent;
using Toybox.Timer;
using Toybox.Time;

// ── Network fetch: GET /messages?game=X → cache the resolved bundle ──────────
class LbMessageFetcher {
    hidden var _game;
    hidden var _attempt;
    hidden var _timer;

    function initialize() { _attempt = 0; _timer = null; }

    function send(game) {
        _game = game;
        _attempt = 0;
        _doSend();
    }

    function _doSend() {
        var params = { "game" => _game };
        var opts = {
            :method       => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        try {
            Communications.makeWebRequest(Leaderboard.API_BASE + "/messages",
                                          params, opts, method(:_onDone));
        } catch (e) {}
    }

    function _onDone(responseCode as Lang.Number,
                     data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            try {
                Application.Storage.setValue(Leaderboard.MSG_CACHE_KEY, data);
                Application.Storage.setValue(Leaderboard.MSG_FETCH_KEY, Time.now().value());
            } catch (e) {}
            return;
        }
        if (responseCode >= 400 && responseCode < 500) { return; }
        if (_attempt >= 2) { return; }
        var delay = [3000, 8000][_attempt];
        _attempt = _attempt + 1;
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_doSend), delay, false); } catch (e) {}
    }
}

// ── Message card view ────────────────────────────────────────────────────────
// A full-screen card: title, word-wrapped body, an optional link "button" that
// opens the URL on the paired phone (Communications.openWebPage), and footer
// hints. SELECT opens the link (if any); BACK closes.
class LbMessageView extends WatchUi.View {
    hidden var _title;
    hidden var _body;
    hidden var _url;
    hidden var _urlLabel;
    hidden var _w;
    hidden var _h;

    function initialize(msg) {
        View.initialize();
        _title    = _str(msg, "title", "");
        _body     = _str(msg, "body", "");
        _url      = _str(msg, "url", null);
        _urlLabel = _str(msg, "url_label", "Open link");
        _w = 0; _h = 0;
    }

    hidden function _str(d, k, def) {
        if (d instanceof Lang.Dictionary && d[k] instanceof Lang.String && d[k].length() > 0) {
            return d[k];
        }
        return def;
    }

    function hasUrl() { return _url != null && _url.length() > 0; }

    function openUrl() {
        if (!hasUrl()) { return; }
        if (Communications has :openWebPage) {
            try { Communications.openWebPage(_url, {}, {}); } catch (e) {}
        }
    }

    // Split on single spaces (Monkey C has no String.split).
    hidden function _words(s) {
        var out = [];
        var cur = "";
        for (var i = 0; i < s.length(); i++) {
            var ch = s.substring(i, i + 1);
            if (ch.equals(" ")) {
                if (cur.length() > 0) { out.add(cur); cur = ""; }
            } else {
                cur = cur + ch;
            }
        }
        if (cur.length() > 0) { out.add(cur); }
        return out;
    }

    hidden function _wrap(dc, text, font, maxW) {
        var words = _words(text);
        var lines = [];
        var cur = "";
        for (var i = 0; i < words.size(); i++) {
            var word = words[i];
            var cand = (cur.length() == 0) ? word : cur + " " + word;
            if (cur.length() == 0 || dc.getTextWidthInPixels(cand, font) <= maxW) {
                cur = cand;
            } else {
                lines.add(cur);
                cur = word;
            }
        }
        if (cur.length() > 0) { lines.add(cur); }
        return lines;
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx = _w / 2;
        var VC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(LB_BG, LB_BG); dc.clear();

        var pad = (_h * 8) / 100; if (pad < fh / 2) { pad = fh / 2; }
        var maxW = _w * 82 / 100;

        // Title (fall back to XTINY if the SMALL title would be too wide).
        var titleFont = Graphics.FONT_SMALL;
        if (dc.getTextWidthInPixels(_title, titleFont) > maxW) { titleFont = Graphics.FONT_XTINY; }
        var titleH = dc.getFontHeight(titleFont);
        var titleCY = pad + titleH / 2;
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, titleCY, titleFont, _title, VC);

        // Footer.
        var footerCY = _h - pad - fh / 2;
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, footerCY, Graphics.FONT_XTINY, "bitochi.com", VC);

        // Optional link button just above the footer.
        var contentBottom = footerCY - fh;
        if (hasUrl()) {
            var btnH = fh + 8;
            var btnW = _w * 66 / 100;
            var btnX = (_w - btnW) / 2;
            var btnY = footerCY - fh / 2 - fh - btnH;
            if (btnY < titleCY + titleH) { btnY = titleCY + titleH; }
            dc.setColor(0x4A3A10, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(btnX, btnY, btnW, btnH, 6);
            dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(btnX, btnY, btnW, btnH, 6);
            dc.setColor(0xFFE49A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, btnY + btnH / 2, Graphics.FONT_XTINY, _urlLabel, VC);

            var hintY = btnY - fh / 2 - 1;
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "SELECT = open on phone", VC);
            contentBottom = hintY - fh / 2;
        } else {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, contentBottom, Graphics.FONT_XTINY, "BACK = close", VC);
            contentBottom = contentBottom - fh;
        }

        // Word-wrapped body, vertically centred in the remaining space.
        var lines = _wrap(dc, _body, Graphics.FONT_XTINY, maxW);
        var lineH = fh + 2;
        var areaTop = titleCY + titleH / 2 + 2;
        var areaBot = contentBottom;
        var blockH = lines.size() * lineH;
        var y = areaTop + ((areaBot - areaTop) - blockH) / 2 + lineH / 2;
        if (y < areaTop + lineH / 2) { y = areaTop + lineH / 2; }
        dc.setColor(LB_TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, y, Graphics.FONT_XTINY, lines[i], VC);
            y = y + lineH;
        }
    }
}

class LbMessageDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(v) { BehaviorDelegate.initialize(); _v = v; }

    function onSelect() {
        if (_v.hasUrl()) { _v.openUrl(); }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ENTER) { return onSelect(); }
        if (k == WatchUi.KEY_ESC)   { return onBack(); }
        return false;
    }
    function onTap(evt) {
        if (_v.hasUrl()) { _v.openUrl(); }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
