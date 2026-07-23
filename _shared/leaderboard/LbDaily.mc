// ═══════════════════════════════════════════════════════════════════════════
// LbDaily.mc — Daily Challenge system for all Bitochi games.
//
// One challenge per game per day, generated server-side from live leaderboard
// stats (so targets are always based on real player data). Shown once per day
// in the shared menu via Leaderboard.announce(). Completion is automatically
// detected inside Leaderboard.submitScore() — no per-game code changes needed.
//
// Storage keys (per-app Application.Storage, all auto-expire by date check):
//   dc_cache   { date:"YYYYMMDD", type:"score"|"score_asc"|"rounds",
//                target:N, label:"..." }
//   dc_shown   "YYYYMMDD" — challenge card was shown today
//   dc_done    "YYYYMMDD" — challenge was completed today
//   dc_rnd     { date:"YYYYMMDD", count:N } — rounds submitted today
// ═══════════════════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Application;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Timer;
using Toybox.PersistedContent;

module DailyChallenge {

    const CACHE_KEY  = "dc_cache";
    const SHOWN_KEY  = "dc_shown";
    const DONE_KEY   = "dc_done";
    const ROUNDS_KEY = "dc_rnd";

    var _fetcher   = null;
    var _completer = null;
    var _celebTimer = null;
    var _showTimer  = null;

    // ── Date helpers ───────────────────────────────────────────────────────
    // Returns today's date as compact "YYYYMMDD" string (local time, good
    // enough for daily granularity without depending on network time).
    function todayKey() as Lang.String {
        try {
            var ci = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var y  = ci.year.toString();
            var mo = ci.month < 10 ? "0" + ci.month.toString() : ci.month.toString();
            var d  = ci.day   < 10 ? "0" + ci.day.toString()   : ci.day.toString();
            return y + mo + d;
        } catch (e) {
            return "00000000";
        }
    }

    // Returns "YYYY-MM-DD" for the backend API.
    function todayApi() as Lang.String {
        try {
            var ci = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var y  = ci.year.toString();
            var mo = ci.month < 10 ? "0" + ci.month.toString() : ci.month.toString();
            var d  = ci.day   < 10 ? "0" + ci.day.toString()   : ci.day.toString();
            return y + "-" + mo + "-" + d;
        } catch (e) {
            return "0000-00-00";
        }
    }

    // ── Cache access ───────────────────────────────────────────────────────
    // Returns cached challenge for today, or null if missing/stale.
    function cached() as Lang.Dictionary or Null {
        try {
            var v = Application.Storage.getValue(CACHE_KEY);
            if (!(v instanceof Lang.Dictionary)) { return null; }
            var vd = v["date"];
            if (!(vd instanceof Lang.String)) { return null; }
            if (!vd.equals(todayKey())) { return null; }
            return v;
        } catch (e) {}
        return null;
    }

    // ── Public API ─────────────────────────────────────────────────────────

    // Fire-and-forget: fetch today's challenge for `game` from the backend
    // and cache it. Called from Leaderboard.logLaunch().
    function prefetch(game as Lang.String) as Void {
        if (!Leaderboard.isSupported())     { return; }
        if (!Leaderboard.isPhoneConnected()) { return; }
        if (cached() != null)               { return; }   // already fresh
        try {
            var user = Leaderboard.loadUser();
            _fetcher = new LbDailyFetcher();
            _fetcher.fetch(game, user);
        } catch (e) {}
    }

    // The main menu's first announce() call happens before the asynchronous
    // fetch can finish. Once fresh data is cached, schedule a second, lightweight
    // presentation attempt. This is what makes the card appear on first launch
    // instead of only on a later app run.
    function onFetched(game as Lang.String) as Void {
        _fetcher = null;
        try {
            _showTimer = new LbDailyShowTimer(game);
            _showTimer.arm();
        } catch (e) {}
    }

    // Show the daily challenge card if:
    //   • the challenge hasn't been shown today
    //   • the challenge hasn't been completed today
    //   • a cached challenge exists
    // Returns true if a view was pushed. Called from Leaderboard.announce().
    function showIfDue(game as Lang.String) as Lang.Boolean {
        if (!Leaderboard.isSupported()) { return false; }
        try {
            var today = todayKey();
            var done  = Application.Storage.getValue(DONE_KEY);
            if (done  instanceof Lang.String && done.equals(today))  { return false; }
            var shown = Application.Storage.getValue(SHOWN_KEY);
            if (shown instanceof Lang.String && shown.equals(today)) { return false; }

            var ch = cached();
            if (ch == null) { return false; }
            var label = ch["label"];
            if (!(label instanceof Lang.String) || label.length() == 0) { return false; }

            var v = new LbDailyView(label);
            WatchUi.pushView(v, new LbDailyDelegate(), WatchUi.SLIDE_UP);
            // Burn the once-per-day marker only after the view was pushed.
            // An OOM/navigation failure must remain retryable.
            Application.Storage.setValue(SHOWN_KEY, today);
            return true;
        } catch (e) {}
        return false;
    }

    // Called from Leaderboard.submitScore() after every score submission.
    // Silently checks if today's challenge is now complete.
    function onScoreSubmit(game as Lang.String, score as Lang.Number,
                           variant as Lang.String or Null) as Void {
        try {
            var today = todayKey();
            var done  = Application.Storage.getValue(DONE_KEY);
            if (done instanceof Lang.String && done.equals(today)) { return; }

            var ch = cached();
            if (ch == null) { return; }

            var ctype  = ch["type"];
            var target = ch["target"];
            if (!(ctype  instanceof Lang.String)) { return; }
            if (!(target instanceof Lang.Number))  { return; }

            if (ctype.equals("score")) {
                if (score >= target) { _complete(game, score); }
            } else if (ctype.equals("score_asc")) {
                // Lower is better (time/moves): challenge is to score <= target.
                if (target > 0 && score > 0 && score <= target) { _complete(game, score); }
            } else if (ctype.equals("rounds")) {
                var rnd = Application.Storage.getValue(ROUNDS_KEY);
                var cnt = 0;
                if (rnd instanceof Lang.Dictionary) {
                    var rd = rnd["date"]; var rc = rnd["count"];
                    if (rd instanceof Lang.String && rd.equals(today) &&
                        rc instanceof Lang.Number) { cnt = rc; }
                }
                cnt = cnt + 1;
                Application.Storage.setValue(ROUNDS_KEY,
                    { "date" => today, "count" => cnt });
                if (cnt >= target) { _complete(game, cnt); }
            }
        } catch (e) {}
    }

    // ── Internal ───────────────────────────────────────────────────────────
    // Mark done, show celebration card after a short delay, POST to backend.
    function _complete(game as Lang.String, score as Lang.Number) as Void {
        try {
            Application.Storage.setValue(DONE_KEY, todayKey());
            // Delay the celebration slightly so the game's own result screen
            // can appear first (this fires inside submitScore()).
            _celebTimer = new LbDailyCelebTimer(game, score);
            _celebTimer.arm();
        } catch (e) {}
    }
}

// ── Post-fetch presentation timer ─────────────────────────────────────────────
class LbDailyShowTimer {
    hidden var _t;
    hidden var _game;

    function initialize(game) { _game = game; _t = null; }

    function arm() as Void {
        try {
            _t = new Timer.Timer();
            // Leave room for the one-shot support card to be presented first.
            _t.start(method(:_fire), 2500, false);
        } catch (e) {}
    }

    function _fire() as Void {
        _t = null;
        try { DailyChallenge.showIfDue(_game); } catch (e) {}
        DailyChallenge._showTimer = null;
    }
}

// ── Celebration timer ─────────────────────────────────────────────────────────
// Arms a 1-second delay before pushing the celebration view, giving the game's
// own result screen time to show first. Also fires the backend POST.
class LbDailyCelebTimer {
    hidden var _t;
    hidden var _game;
    hidden var _score;

    function initialize(game, score) { _game = game; _score = score; _t = null; }

    function arm() {
        try {
            _t = new Timer.Timer();
            _t.start(method(:_fire), 1000, false);
        } catch (e) {}
    }

    function _fire() as Void {
        _t = null;
        try {
            var v = new LbDailyCelebView();
            WatchUi.pushView(v, new LbDailyCelebDelegate(), WatchUi.SLIDE_UP);
        } catch (e) {}
        // POST completion to backend (fire-and-forget).
        try {
            if (Leaderboard.isPhoneConnected()) {
                var user = Leaderboard.loadUser();
                if (user == null) { user = "anon"; }
                DailyChallenge._completer = new LbDailyCompleter();
                DailyChallenge._completer.post(_game, user, _score,
                                               DailyChallenge.todayApi());
            }
        } catch (e) {}
    }
}

// ── Fetcher ───────────────────────────────────────────────────────────────────
class LbDailyFetcher {
    hidden var _game;
    hidden var _user;
    hidden var _timer;
    hidden var _attempt;

    function initialize() { _attempt = 0; _timer = null; }

    function fetch(game, user) {
        _game = game;
        _user = (user != null) ? user : "anon";
        _attempt = 0;
        _doFetch();
    }

    function _doFetch() {
        var params = { "game" => _game, "user" => _user };
        var opts   = {
            :method       => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        try {
            Communications.makeWebRequest(Leaderboard.API_BASE + "/daily",
                                          params, opts, method(:_onDone));
        } catch (e) {}
    }

    function _onDone(code as Lang.Number,
                     data as Null or Lang.Dictionary or Lang.String
                          or PersistedContent.Iterator) as Void {
        if (code == 200 && data instanceof Lang.Dictionary) {
            try {
                var ctype  = data["type"];
                var asc    = (data["asc"] == true);
                // The watch uses "score_asc" internally for lower-is-better games.
                var wtype  = (ctype instanceof Lang.String && ctype.equals("score") && asc)
                             ? "score_asc" : ctype;
                var cache  = {
                    "date"   => DailyChallenge.todayKey(),
                    "type"   => wtype,
                    "target" => data["target"],
                    "label"  => data["label"]
                };
                Application.Storage.setValue(DailyChallenge.CACHE_KEY, cache);
            } catch (e) {}
            DailyChallenge.onFetched(_game);
            return;
        }
        if (code >= 400 && code < 500) { DailyChallenge._fetcher = null; return; }
        if (_attempt >= 2) { DailyChallenge._fetcher = null; return; }
        var delay = [8000, 20000][_attempt];
        _attempt = _attempt + 1;
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_doFetch), delay, false); } catch (e) {}
    }
}

// ── Completer ────────────────────────────────────────────────────────────────
class LbDailyCompleter {
    hidden var _game;
    hidden var _user;
    hidden var _score;
    hidden var _date;
    hidden var _timer;
    hidden var _attempt;

    function initialize() { _attempt = 0; _timer = null; }

    function post(game, user, score, date) {
        _game = game; _user = user; _score = score; _date = date;
        _attempt = 0;
        _doPost();
    }

    function _doPost() {
        var body = { "game" => _game, "user" => _user,
                     "score" => _score, "date" => _date };
        var opts = {
            :method       => Communications.HTTP_REQUEST_METHOD_POST,
            :headers      => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "X-LB-Key"     => Leaderboard.SUBMIT_KEY
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        try {
            Communications.makeWebRequest(Leaderboard.API_BASE + "/daily/complete",
                                          body, opts, method(:_onDone));
        } catch (e) {}
    }

    function _onDone(code, data) {
        if (code == 200 || code == 201) { return; }
        if (code >= 400 && code < 500)  { return; }
        if (_attempt >= 2) { return; }
        var delay = [5000, 12000][_attempt];
        _attempt = _attempt + 1;
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_doPost), delay, false); } catch (e) {}
    }
}

// ── Daily challenge card ───────────────────────────────────────────────────────
// Styled using the shared LB palette. Shows the challenge label with a
// sun/star icon and "press any key" footer.
class LbDailyView extends WatchUi.View {
    hidden var _label;
    hidden var _w;
    hidden var _h;

    function initialize(label as Lang.String) {
        View.initialize();
        _label = label;
        _w = 0; _h = 0;
    }

    function onUpdate(dc) {
        try { _draw(dc); }
        catch (e) { try { dc.setColor(LB_BG, LB_BG); dc.clear(); } catch (e2) {} }
    }

    hidden function _draw(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx   = _w / 2;
        var VC   = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var fh   = dc.getFontHeight(Graphics.FONT_XTINY);
        var fhS  = dc.getFontHeight(Graphics.FONT_SMALL);
        var isRd = (_w == _h);

        dc.setColor(LB_BG, LB_BG); dc.clear();

        var pad = isRd ? (_h * 10) / 100 : (_h * 7) / 100;
        if (pad < fh) { pad = fh; }

        // Warm gold background band at the top to distinguish from regular msgs.
        dc.setColor(0x2A1E00, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, pad + fhS + 4);

        // Sun icon: circle + 8 rays
        var icX = cx; var icY = pad / 2 + fhS / 2;
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(icX, icY, 5);
        var rays = [[0,1],[1,1],[1,0],[1,-1],[0,-1],[-1,-1],[-1,0],[-1,1]];
        for (var i = 0; i < 8; i++) {
            var rx = rays[i][0]; var ry = rays[i][1];
            dc.drawLine(icX + rx * 6, icY + ry * 6,
                        icX + rx * 9, icY + ry * 9);
        }

        // "DAILY CHALLENGE" header
        var titleY = pad + fhS / 2;
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, titleY, Graphics.FONT_SMALL, "DAILY", VC);

        var subY = titleY + fhS * 3 / 4;
        dc.setColor(0xE8A800, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, subY, Graphics.FONT_XTINY, "CHALLENGE", VC);

        // Separator line
        var sepY = subY + fh / 2 + 2;
        dc.setColor(0x3A2E00, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w * 15 / 100, sepY, _w * 85 / 100, sepY);

        // Footer
        var footY = _h - pad / 2;
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, footY, Graphics.FONT_XTINY, "press any key", VC);

        // Word-wrap the label in the central area
        var maxW  = isRd ? (_w * 76) / 100 : (_w * 88) / 100;
        var lines = _wrap(dc, _label, maxW);
        var lineH = fh + 2;
        var areaT = sepY + 4;
        var areaB = footY - fh / 2 - 2;
        var avail = areaB - areaT;
        var blockH = lines.size() * lineH;
        var bodyY  = areaT + (avail - blockH) / 2 + lineH / 2;
        if (bodyY < areaT + lineH / 2) { bodyY = areaT + lineH / 2; }
        dc.setColor(LB_TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, bodyY + i * lineH, Graphics.FONT_XTINY, lines[i], VC);
        }
    }

    hidden function _words(s) {
        var out = []; var cur = "";
        for (var i = 0; i < s.length(); i++) {
            var ch = s.substring(i, i + 1);
            if (ch.equals(" ")) { if (cur.length() > 0) { out.add(cur); cur = ""; } }
            else { cur = cur + ch; }
        }
        if (cur.length() > 0) { out.add(cur); }
        return out;
    }

    hidden function _wrap(dc, text, maxW) {
        var words = _words(text); var lines = []; var cur = "";
        for (var i = 0; i < words.size(); i++) {
            var word = words[i];
            var cand = (cur.length() == 0) ? word : cur + " " + word;
            if (cur.length() == 0 ||
                dc.getTextWidthInPixels(cand, Graphics.FONT_XTINY) <= maxW) {
                cur = cand;
            } else { lines.add(cur); cur = word; }
        }
        if (cur.length() > 0) { lines.add(cur); }
        return lines;
    }
}

class LbDailyDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    hidden function _close() { WatchUi.popView(WatchUi.SLIDE_DOWN); return true; }
    function onSelect()       { return _close(); }
    function onBack()         { return _close(); }
    function onKey(evt)       { return _close(); }
    function onTap(evt)       { return _close(); }
    function onNextPage()     { return _close(); }
    function onPreviousPage() { return _close(); }
}

// ── Challenge complete celebration ────────────────────────────────────────────
// Full-screen green success card. Auto-dismisses after 3 seconds.
class LbDailyCelebView extends WatchUi.View {
    hidden var _w;
    hidden var _h;
    hidden var _timer;

    function initialize() { View.initialize(); _w = 0; _h = 0; _timer = null; }

    function onShow() {
        try {
            _timer = new Timer.Timer();
            _timer.start(method(:_autoDismiss), 3000, false);
        } catch (e) {}
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function _autoDismiss() as Void {
        _timer = null;
        try { WatchUi.popView(WatchUi.SLIDE_DOWN); } catch (e) {}
    }

    function onUpdate(dc) {
        try { _draw(dc); }
        catch (e) { try { dc.setColor(0x0A1A0A, 0x0A1A0A); dc.clear(); } catch (e2) {} }
    }

    hidden function _draw(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx  = _w / 2;
        var VC  = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var fh  = dc.getFontHeight(Graphics.FONT_XTINY);
        var fhS = dc.getFontHeight(Graphics.FONT_SMALL);

        dc.setColor(0x061206, 0x061206); dc.clear();
        if (_w == _h) {
            dc.setColor(0x0C200C, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 2);
        }

        // Big ✓ checkmark with thick lines
        var ckCY  = _h * 38 / 100;
        var ckR   = fh + 4;
        var x1    = cx - ckR; var y1 = ckCY;
        var xMid  = cx - ckR / 4; var yMid = ckCY + ckR * 3 / 4;
        var x2    = cx + ckR;     var y2   = ckCY - ckR / 2;
        dc.setColor(LB_GREEN, Graphics.COLOR_TRANSPARENT);
        for (var t = -2; t <= 2; t++) {
            dc.drawLine(x1, y1 + t, xMid, yMid + t);
            dc.drawLine(xMid, yMid + t, x2, y2 + t);
        }

        // Text block
        var pad = (_h * 8) / 100;
        var t1Y = _h - pad - fhS - fh - fh / 2;
        var t2Y = t1Y + fhS;
        var t3Y = _h - pad - fh / 2;

        dc.setColor(LB_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, t1Y, Graphics.FONT_SMALL, "CHALLENGE", VC);
        dc.drawText(cx, t2Y, Graphics.FONT_SMALL, "COMPLETE!", VC);

        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, t3Y, Graphics.FONT_XTINY, "tap to close", VC);
    }
}

class LbDailyCelebDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    hidden function _close() { WatchUi.popView(WatchUi.SLIDE_DOWN); return true; }
    function onSelect()       { return _close(); }
    function onBack()         { return _close(); }
    function onKey(evt)       { return _close(); }
    function onTap(evt)       { return _close(); }
    function onNextPage()     { return _close(); }
    function onPreviousPage() { return _close(); }
}
