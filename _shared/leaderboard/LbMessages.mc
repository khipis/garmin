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
// A full-screen card: title, word-wrapped body, and — when a URL is set — the
// full URL printed as plain text with link styling (colour + underline).
//
// NB: this is a watch, not a browser. The URL is NOT tappable/openable; it is
// simply written out so the user can type it on their phone. Any key/tap closes
// the card.
class LbMessageView extends WatchUi.View {
    hidden var _title;
    hidden var _body;
    hidden var _url;      // display form (scheme stripped), e.g. "bitochi.com/coffee"
    hidden var _w;
    hidden var _h;

    function initialize(msg) {
        View.initialize();
        _title = _str(msg, "title", "");
        _body  = _str(msg, "body", "");
        _url   = _displayUrl(_str(msg, "url", null));
        _w = 0; _h = 0;
    }

    hidden function _str(d, k, def) {
        if (d instanceof Lang.Dictionary && d[k] instanceof Lang.String && d[k].length() > 0) {
            return d[k];
        }
        return def;
    }

    // Strip the scheme + a trailing slash so the URL reads cleanly on-glass:
    // "https://bitochi.com/coffee/" → "bitochi.com/coffee".
    hidden function _displayUrl(u) {
        if (u == null || u.length() == 0) { return null; }
        if (u.length() >= 8 && u.substring(0, 8).equals("https://")) {
            u = u.substring(8, u.length());
        } else if (u.length() >= 7 && u.substring(0, 7).equals("http://")) {
            u = u.substring(7, u.length());
        }
        while (u.length() > 1 && u.substring(u.length() - 1, u.length()).equals("/")) {
            u = u.substring(0, u.length() - 1);
        }
        return u;
    }

    function hasUrl() { return _url != null && _url.length() > 0; }

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
        // Bulletproof: a rendering hiccup must never crash the host game.
        try {
            _draw(dc);
        } catch (e) {
            try { dc.setColor(LB_BG, LB_BG); dc.clear(); } catch (e2) {}
        }
    }

    hidden function _draw(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx = _w / 2;
        var VC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var lineH = fh + 2;

        dc.setColor(LB_BG, LB_BG); dc.clear();

        // Round screens clip the corners hard: keep a generous inset so the top
        // title and the bottom hint stay fully on-glass, and wrap text narrow.
        var isRound = (_w == _h);
        var pad  = isRound ? (_h * 15) / 100 : (_h * 9) / 100;
        if (pad < fh) { pad = fh; }
        var maxW = isRound ? (_w * 72) / 100 : (_w * 86) / 100;

        // Title (fall back to XTINY if the SMALL title would be too wide).
        var titleFont = Graphics.FONT_SMALL;
        if (dc.getTextWidthInPixels(_title, titleFont) > maxW) { titleFont = Graphics.FONT_XTINY; }
        var titleH  = dc.getFontHeight(titleFont);
        var titleCY = pad + titleH / 2;
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, titleCY, titleFont, _title, VC);

        // Bottom hint (always: tells the user any press dismisses the card).
        var footerCY = _h - pad - fh / 2;
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, footerCY, Graphics.FONT_XTINY, "press any key", VC);

        var contentBottom = footerCY - fh;

        // Full URL as plain, link-styled text (colour + underline). Not tappable.
        if (hasUrl()) {
            var linkFont = Graphics.FONT_XTINY;
            var linkLines = _wrap(dc, _url, linkFont, maxW);
            var linkBlockH = linkLines.size() * lineH;
            var linkTop = contentBottom - linkBlockH;
            var ly = linkTop + lineH / 2;
            for (var i = 0; i < linkLines.size(); i++) {
                var seg = linkLines[i];
                dc.setColor(LB_LINK, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, ly, linkFont, seg, VC);
                var tw = dc.getTextWidthInPixels(seg, linkFont);
                var uy = ly + fh / 2 - 1;
                dc.drawLine(cx - tw / 2, uy, cx + tw / 2, uy);
                ly = ly + lineH;
            }
            contentBottom = linkTop - lineH / 2;
        }

        // Word-wrapped body, vertically centred in the remaining space.
        var lines = _wrap(dc, _body, Graphics.FONT_XTINY, maxW);
        var areaTop = titleCY + titleH / 2 + 2;
        var areaBot = contentBottom;
        var blockH = lines.size() * lineH;
        var y = areaTop + ((areaBot - areaTop) - blockH) / 2 + lineH / 2;
        if (y < areaTop + lineH / 2) { y = areaTop + lineH / 2; }
        dc.setColor(LB_TEXT, Graphics.COLOR_TRANSPARENT);
        for (var j = 0; j < lines.size(); j++) {
            dc.drawText(cx, y, Graphics.FONT_XTINY, lines[j], VC);
            y = y + lineH;
        }
    }
}

// The URL is display-only text, so there is nothing to "open" — any interaction
// simply dismisses the card.
class LbMessageDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(v) { BehaviorDelegate.initialize(); _v = v; }

    hidden function _close() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect()   { return _close(); }
    function onBack()     { return _close(); }
    function onNextPage() { return _close(); }
    function onPreviousPage() { return _close(); }
    function onKey(evt)   { return _close(); }
    function onTap(evt)   { return _close(); }
}
