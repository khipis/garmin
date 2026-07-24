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
    hidden var _continued;

    function initialize() { _attempt = 0; _timer = null; _continued = false; }

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
            Leaderboard.markBusy();
            Communications.makeWebRequest(Leaderboard.API_BASE + "/messages",
                                          params, opts, method(:_onDone));
        } catch (e) {
            Leaderboard.clearBusy();
            _continuePipeline();
        }
    }

    function _onDone(responseCode as Lang.Number,
                     data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        Leaderboard.clearBusy();
        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            try {
                Application.Storage.setValue(Leaderboard.MSG_CACHE_KEY, data);
                Application.Storage.setValue(Leaderboard.MSG_FETCH_KEY, Time.now().value());
            } catch (e) {}
            _continuePipeline();
            return;
        }
        if (responseCode >= 400 && responseCode < 500) { _continuePipeline(); return; }
        if (_attempt >= 2) { _continuePipeline(); return; }
        var delay = [3000, 8000][_attempt];
        _attempt = _attempt + 1;
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_doSend), delay, false); } catch (e) {}
    }

    hidden function _continuePipeline() as Void {
        if (_continued) { return; }
        _continued = true;
        if (_timer != null) { try { _timer.stop(); } catch (e) {} _timer = null; }
        // Start Daily Challenge only after this callback has returned, otherwise
        // older firmware may still report the message request as pending.
        try {
            _timer = new Timer.Timer();
            _timer.start(method(:_advancePipeline), 250, false);
        } catch (e) { _advancePipeline(); }
    }

    // NOTE: must be a public (non-hidden) function — used as a
    // method(:_advancePipeline) timer callback. See LbViews.mc for why a
    // hidden method() target crashes the app shortly after launch.
    function _advancePipeline() as Void {
        _timer = null;
        try { Leaderboard.afterMessages(_game); } catch (e) {}
    }
}

// ── One-shot launch timer ────────────────────────────────────────────────────
// Started from Leaderboard.logLaunch() (which every game calls in onStart). A
// short delay lets the game's initial view come up first, then we offer the
// one-shot 'once' call-to-action over it — giving EVERY game the message at
// start without editing each game. Fires at most once (ack-gated server-side +
// locally). Fully guarded so it can never disturb the host game.
class LbOnceTimer {
    hidden var _t;
    hidden var _game;

    function initialize(game) { _game = game; _t = null; }

    function start() {
        try {
            _t = new Timer.Timer();
            _t.start(method(:_tick), 1500, false);
        } catch (e) {}
    }

    function _tick() as Void {
        _t = null;
        try { Leaderboard.showOnceIfDue(_game); } catch (e) {}
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

        // Round screens clip the corners hard: keep an inset so the top title and
        // the bottom hint stay on-glass, but not so large that the body has to be
        // truncated. Body text sits in the vertical middle where a round screen is
        // widest, so we can wrap fairly wide there.
        var isRound = (_w == _h);
        var pad  = isRound ? (_h * 10) / 100 : (_h * 7) / 100;
        if (pad < fh) { pad = fh; }
        var maxW = isRound ? (_w * 78) / 100 : (_w * 88) / 100;

        // Title — extra side margin (so it clears the round bezel) and, on round
        // screens, nudged down into the wider part of the circle. Falls back to
        // XTINY if the SMALL title would still be too wide for its narrower band.
        var titleMaxW = isRound ? (_w * 66) / 100 : maxW;
        var titleFont = Graphics.FONT_SMALL;
        if (dc.getTextWidthInPixels(_title, titleFont) > titleMaxW) { titleFont = Graphics.FONT_XTINY; }
        var titleH  = dc.getFontHeight(titleFont);
        var titleCY = pad + titleH / 2;
        if (isRound) { titleCY += fh; }
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, titleCY, titleFont, _title, VC);

        // Bottom hint (always: tells the user any press dismisses the card).
        var footerCY = _h - pad - fh / 2;
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, footerCY, Graphics.FONT_XTINY, "press any key", VC);

        // Bottom of the area the body may use. Reserve space for the footer plus,
        // when present, the link block — each separated by a half-line gap so
        // nothing collides while still leaving the body plenty of room.
        var gap = fh / 2 + 2;
        var contentBottom = footerCY - fh / 2 - gap;

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
                var uy = ly + fh / 2;
                dc.drawLine(cx - tw / 2, uy, cx + tw / 2, uy);
                dc.drawLine(cx - tw / 2, uy + 1, cx + tw / 2, uy + 1);
                ly = ly + lineH;
            }
            // Clear separation between the body and the link.
            contentBottom = linkTop - gap;
        }

        // Word-wrapped body, vertically centred in the remaining space. Lines that
        // would spill past contentBottom are dropped rather than drawn over the
        // link/footer — a hard guarantee against overlap.
        var lines = _wrap(dc, _body, Graphics.FONT_XTINY, maxW);
        var areaTop = titleCY + titleH / 2 + lineH / 2;
        var areaBot = contentBottom;
        var avail = areaBot - areaTop;
        var maxLines = avail / lineH;
        if (maxLines < 1) { maxLines = 1; }
        if (lines.size() > maxLines) {
            var trimmed = [];
            for (var k = 0; k < maxLines; k++) { trimmed.add(lines[k]); }
            lines = trimmed;
        }
        var blockH = lines.size() * lineH;
        var y = areaTop + (avail - blockH) / 2 + lineH / 2;
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
