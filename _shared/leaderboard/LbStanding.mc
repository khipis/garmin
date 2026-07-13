// ═══════════════════════════════════════════════════════════════════════════
// LbStanding.mc — post-game engagement card.
//
// After every run, before the leaderboard board, the player sees exactly where
// they stand and how close they are to glory:
//   • all-time rank (of N players)  +  gap to the Hall of Fame (#1 all-time)
//   • today's rank + gap to today's #1
//   • this week's rank + gap to the week's #1
//
// Powered by the compact GET /standing endpoint (one request, all three
// windows). Fully guarded: any network / parse / render failure silently falls
// through to the leaderboard board — it can NEVER crash the host game.
//
// Flow (chained, one active view at a time):
//   game over → LbStandingView → (dismiss) → [support msg if due] → board
// ═══════════════════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.PersistedContent;
using Toybox.Timer;

// ── Fetcher: GET /standing?game&variant&user → listener.onStanding(ok,data) ──
class LbStandingFetch {
    hidden var _listener;
    hidden var _game;
    hidden var _variant;
    hidden var _user;

    function initialize() { _listener = null; }

    function fetch(game, variant, user, listener) {
        _listener = listener;
        _game = game; _variant = variant; _user = user;
        var params = { "game" => game };
        if (variant != null && variant.length() > 0) { params["variant"] = variant; }
        if (user != null && user.length() > 0)       { params["user"]    = user;    }
        params["_"] = System.getTimer();   // cache-bust: reflect the fresh score
        var opts = {
            :method       => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        try {
            Communications.makeWebRequest(Leaderboard.API_BASE + "/standing",
                                          params, opts, method(:_onResp));
        } catch (e) {
            _notify(false, null);
        }
    }

    function _onResp(responseCode as Lang.Number,
                     data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        if (responseCode == 200 && data instanceof Lang.Dictionary) { _notify(true, data); return; }
        _notify(false, null);
    }

    hidden function _notify(ok, data) {
        if (_listener != null) { _listener.onStanding(ok, data); }
    }
}

// ── The engagement card ──────────────────────────────────────────────────────
class LbStandingView extends WatchUi.View {
    hidden var _game;
    hidden var _variant;
    hidden var _title;
    hidden var _data;         // /standing dict or null
    hidden var _asc;
    hidden var _state;        // 0 loading, 1 ok, 2 done-no-data
    hidden var _retries;
    hidden var _fetch;
    hidden var _timer;
    hidden var _alive;        // false once onHide fires — guards async callbacks
    hidden var _w;
    hidden var _h;

    function initialize(game, variant, title) {
        View.initialize();
        _game    = game;
        _variant = variant;
        _title   = (title != null) ? title : "YOUR STANDING";
        _data    = null;
        _asc     = false;
        _state   = 0;
        _retries = 3;
        _fetch   = null;
        _timer   = null;
        _alive   = false;
        _w = 0; _h = 0;
    }

    function onShow() { _alive = true; _doFetch(); }

    function onHide() {
        _alive = false;
        if (_timer != null) { try { _timer.stop(); } catch (e) {} _timer = null; }
    }

    hidden function _doFetch() {
        try {
            _state = 0;
            _fetch = new LbStandingFetch();
            _fetch.fetch(_game, _variant, Leaderboard.loadUser(), self);
        } catch (e) {
            _state = 2; WatchUi.requestUpdate();
        }
        WatchUi.requestUpdate();
    }

    function _retryFetch() as Void {
        if (_timer != null) { try { _timer.stop(); } catch (e) {} _timer = null; }
        if (!_alive) { return; }
        _doFetch();
    }

    // Listener callback.
    function onStanding(ok, data) {
        if (!_alive) { return; }
        if (!ok || !(data instanceof Lang.Dictionary)) {
            _state = 2; WatchUi.requestUpdate(); return;
        }
        _data = data;
        _asc  = (data["asc"] == true);
        // The just-submitted score may not be committed yet → all-time rank
        // missing. Retry a couple of times so the card shows a real position.
        var all = data["all"];
        var haveRank = (all instanceof Lang.Dictionary) && (all["myRank"] instanceof Lang.Number);
        if (!haveRank && _retries > 0) {
            _retries -= 1;
            _state = 0;
            if (_timer == null) { _timer = new Timer.Timer(); }
            try { _timer.start(method(:_retryFetch), 1500, false); } catch (e) {}
            WatchUi.requestUpdate();
            return;
        }
        _state = 1;
        WatchUi.requestUpdate();
    }

    // ── helpers ──
    hidden function _num(d, k) {
        if (d instanceof Lang.Dictionary && (d[k] instanceof Lang.Number || d[k] instanceof Lang.Long)) {
            return d[k];
        }
        return null;
    }

    // Gap magnitude to #1 for the given period dict (asc-aware), or null.
    hidden function _gap(pd) {
        var top1 = _num(pd, "top1");
        var mine = _num(pd, "myBest");
        if (top1 == null || mine == null) { return null; }
        var g = _asc ? (mine - top1) : (top1 - mine);
        if (g < 0) { g = 0; }
        return g;
    }

    // Build a one-line status string for a period, plus a colour.
    // Returns [text, color].
    hidden function _line(label, pd) {
        var rank = _num(pd, "myRank");
        if (rank == null) {
            return [label + "  play to rank", LB_MUTED];
        }
        var g = _gap(pd);
        if (rank == 1 || (g != null && g == 0)) {
            return [label + "  #1 - you lead!", LB_GREEN];
        }
        var tail = (g != null) ? ("  " + g.format("%d") + " to #1") : "";
        return [label + "  #" + rank.format("%d") + tail, LB_LINK];
    }

    hidden function _tier(rank, count) {
        if (rank == null || count == null || count <= 0) { return null; }
        if (rank <= 100)         { return "ELITE"; }
        if (rank <= count / 10)  { return "PRO"; }
        if (rank <= count / 2)   { return "SOLID"; }
        return "RANKED";
    }

    function onUpdate(dc) {
        try { _draw(dc); }
        catch (e) { try { dc.setColor(LB_BG, LB_BG); dc.clear(); } catch (e2) {} }
    }

    hidden function _draw(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx = _w / 2;
        var VC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var lineH = fh + 3;

        dc.setColor(LB_BG, LB_BG); dc.clear();

        var isRound = (_w == _h);
        var pad = isRound ? (_h * 12) / 100 : (_h * 8) / 100;
        if (pad < fh) { pad = fh; }

        // Title
        var y = pad + fh / 2;
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "YOUR STANDING", VC);
        y += fh;

        if (_state == 0) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h / 2, Graphics.FONT_XTINY, "Reading your rank...", VC);
            _footer(dc, cx, fh);
            return;
        }

        var all  = (_data instanceof Lang.Dictionary) ? _data["all"]  : null;
        var day  = (_data instanceof Lang.Dictionary) ? _data["day"]  : null;
        var week = (_data instanceof Lang.Dictionary) ? _data["week"] : null;
        var allRank  = _num(all, "myRank");
        var allCount = _num(all, "count");

        if (_state == 2 || allRank == null) {
            // No rank yet (brand-new / offline). Friendly nudge, still dismissable.
            dc.setColor(LB_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h / 2 - lineH, Graphics.FONT_SMALL, "You're on", VC);
            dc.drawText(cx, _h / 2, Graphics.FONT_SMALL, "the board!", VC);
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h / 2 + lineH + 2, Graphics.FONT_XTINY, "Keep playing to climb", VC);
            _footer(dc, cx, fh);
            return;
        }

        // Big rank line: "#12 of 340"
        var rankStr = "#" + allRank.format("%d");
        dc.setColor(LB_ACCENT, Graphics.COLOR_TRANSPARENT);
        var ry = y + dc.getFontHeight(Graphics.FONT_NUMBER_MILD) / 2 + 2;
        dc.drawText(cx, ry, Graphics.FONT_NUMBER_MILD, rankStr, VC);
        var afterRank = ry + dc.getFontHeight(Graphics.FONT_NUMBER_MILD) / 2;
        if (allCount != null) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, afterRank + fh / 2, Graphics.FONT_XTINY,
                        "of " + allCount.format("%d") + " players", VC);
            afterRank += fh;
        }

        var tier = _tier(allRank, allCount);
        if (tier != null) {
            dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, afterRank + fh / 2 + 2, Graphics.FONT_XTINY, tier, VC);
            afterRank += fh + 2;
        }

        // Three status lines, stacked upward from the footer.
        var footerCY = _h - pad - fh / 2;
        var lines = [
            _line("HALL OF FAME", all),
            _line("TODAY", day),
            _line("WEEK",  week)
        ];
        var blockH = lines.size() * lineH;
        var startY = footerCY - fh - blockH;      // leave a gap above the footer
        // don't collide with the rank block
        if (startY < afterRank + fh / 2) { startY = afterRank + fh / 2; }
        var ly = startY + lineH / 2;
        for (var i = 0; i < lines.size(); i++) {
            dc.setColor(lines[i][1], Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ly, Graphics.FONT_XTINY, lines[i][0], VC);
            ly += lineH;
        }

        _footer(dc, cx, fh);
    }

    hidden function _footer(dc, cx, fh) {
        var isRound = (_w == _h);
        var pad = isRound ? (_h * 12) / 100 : (_h * 8) / 100;
        if (pad < fh) { pad = fh; }
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h - pad - fh / 2, Graphics.FONT_XTINY, "press any key",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Dismiss → chain to the (occasional) support message, then the leaderboard.
class LbStandingDelegate extends WatchUi.BehaviorDelegate {
    hidden var _game;
    hidden var _variant;
    hidden var _title;

    function initialize(game, variant, title) {
        BehaviorDelegate.initialize();
        _game = game; _variant = variant; _title = title;
    }

    hidden function _close() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        try {
            var msg = Leaderboard.duePostGameMessage();
            if (msg != null) {
                var mv = new LbMessageView(msg);
                WatchUi.pushView(mv, new LbMsgThenBoardDelegate(mv, _game, _variant, _title),
                                 WatchUi.SLIDE_UP);
                return true;
            }
        } catch (e) {}
        // No message due → straight to the board.
        try {
            var b = new LbScoresView(_game, _variant, _title);
            b.markPostGame();
            WatchUi.pushView(b, new LbScoresDelegate(b), WatchUi.SLIDE_UP);
        } catch (e) {}
        return true;
    }

    function onSelect()       { return _close(); }
    function onBack()         { return _close(); }
    function onKey(evt)       { return _close(); }
    function onTap(evt)       { return _close(); }
    function onNextPage()     { return _close(); }
    function onPreviousPage() { return _close(); }
}
