// ═══════════════════════════════════════════════════════════════════════════
// LbViews.mc — Shared leaderboard UI: username entry, scores list, menu badge.
//
// SKELETON. These are pushable WatchUi views so a game only needs to:
//   1. add a "LEADERBOARD" row to its menu
//   2. on activate:  var v = new LbScoresView(GAME, VARIANT, TITLE);
//                   WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT)
//   3. on game over: Leaderboard.submitScore(GAME, score, VARIANT)
//
// LbScoresView auto-prompts for a username (LbNameEntryView) the first time
// if none has been stored yet.
// ═══════════════════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.PersistedContent;

// Palette (matches the web leaderboard at bitochi.com)
const LB_BG       = 0x080C10;
const LB_ACCENT   = 0x00D4FF;
const LB_GOLD     = 0xFBBF24;
const LB_SILVER   = 0x94A3B8;
const LB_BRONZE   = 0xCD7C3A;
const LB_MUTED    = 0x4A6278;
const LB_TEXT     = 0xD6E4F0;

// ═══════════════════════════════════════════════════════════════════════════
// Score submitter — POST /score with exponential backoff (max 3 retries).
// Retries on network errors (responseCode < 0) and 5xx server errors.
// 4xx are not retried (client/auth error — retrying won't help).
// Instance lives in Leaderboard._sender until the last attempt settles;
// from the calling game's perspective this is still fire-and-forget.
// ═══════════════════════════════════════════════════════════════════════════
class LbSubmitter {
    hidden var _game;
    hidden var _user;
    hidden var _score;
    hidden var _variant;
    hidden var _meta;
    hidden var _attempt;
    hidden var _timer;

    function initialize() { _attempt = 0; _timer = null; }

    // meta is an optional Lang.Dictionary of small extra fields (e.g. species,
    // rarity) stored alongside the score as a JSON blob — used by games that
    // want a richer "trophy" leaderboard entry. Pass null when not needed.
    function send(game, user, score, variant, meta) {
        _game = game; _user = user; _score = score; _variant = variant; _meta = meta;
        _attempt = 0;
        _doSend();
    }

    // Called directly on first attempt and via Timer on retries.
    function _doSend() {
        var body = {
            "game"  => _game,
            "user"  => _user,
            "score" => _score
        };
        if (_variant != null && _variant.length() > 0) {
            body["variant"] = _variant;
        }
        if (_meta != null) {
            body["meta"] = _meta;
        }
        var opts = {
            :method       => Communications.HTTP_REQUEST_METHOD_POST,
            :headers      => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "X-LB-Key"     => Leaderboard.SUBMIT_KEY
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        try {
            Communications.makeWebRequest(Leaderboard.API_BASE + "/score",
                                          body, opts, method(:_onDone));
        } catch (e) {}
    }

    function _onDone(responseCode as Lang.Number,
                     data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        if (responseCode == 200 || responseCode == 201) { return; }
        if (responseCode >= 400 && responseCode < 500) { return; }  // 4xx — don't retry
        if (_attempt >= 3) { return; }                              // exhausted
        var delay = [2000, 4000, 8000][_attempt];
        _attempt = _attempt + 1;
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_doSend), delay, false); } catch (e) {}
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Launch pinger — POST /launch with exponential backoff (max 3 retries).
// Same retry policy as LbSubmitter. Instance lives in Leaderboard._pinger.
// ═══════════════════════════════════════════════════════════════════════════
class LbPinger {
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
        var body = { "game" => _game };
        var opts = {
            :method       => Communications.HTTP_REQUEST_METHOD_POST,
            :headers      => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "X-LB-Key"     => Leaderboard.SUBMIT_KEY
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        try {
            Communications.makeWebRequest(Leaderboard.API_BASE + "/launch",
                                          body, opts, method(:_onDone));
        } catch (e) {}
    }

    function _onDone(responseCode as Lang.Number,
                     data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        if (responseCode == 200 || responseCode == 201) { return; }
        if (responseCode >= 400 && responseCode < 500) { return; }
        if (_attempt >= 3) { return; }
        var delay = [2000, 4000, 8000][_attempt];
        _attempt = _attempt + 1;
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_doSend), delay, false); } catch (e) {}
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Network fetch helper — notifies a listener implementing onLeaderboard(ok,data)
// where `data` is the full enriched /leaderboard dictionary:
//   { top:[{r,u,s,c}], me:{r,s}|null, near:[...], count, target, asc, period }
// ═══════════════════════════════════════════════════════════════════════════
class LbFetch {
    hidden var _listener;

    function initialize() { _listener = null; }

    function fetch(game, variant, user, period, listener, nocache) {
        _listener = listener;
        var params = {
            "game"   => game,
            "period" => (period != null) ? period : "all"
        };
        if (variant != null && variant.length() > 0) { params["variant"] = variant; }
        if (user != null && user.length() > 0)       { params["user"]    = user;    }
        // Cache-bust right after submitting so the player's fresh score/rank
        // is reflected instead of a stale CDN copy.
        if (nocache) { params["_"] = System.getTimer(); }
        var opts = {
            :method       => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        try {
            Communications.makeWebRequest(Leaderboard.API_BASE + "/leaderboard",
                                          params, opts, method(:_onResp));
        } catch (e) {
            _notify(false, null);
        }
    }

    function _onResp(responseCode as Lang.Number,
                     data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            _notify(true, data); return;
        }
        _notify(false, null);
    }

    hidden function _notify(ok, data) {
        if (_listener != null) { _listener.onLeaderboard(ok, data); }
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

        var fhn = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h - fhn - fhn / 2, Graphics.FONT_XTINY,
                    "UP/DN  SEL next",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, _h - fhn / 2, Graphics.FONT_XTINY,
                    "HOLD = save",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
// Scores list — fetches the enriched leaderboard for a game[/variant] and shows:
//   • TOP list (Global) or the ±5 window around the player (Near You)
//   • "YOU #r / N" with a rank tier (Elite / Pro / Solid)
//   • next target to beat, and the "beat this" score
//   • daily / weekly / all-time period toggle
//
// Controls:  UP/DOWN swipe = scroll · SELECT/tap = Global↔Near · MENU = period
//            HOLD = reset username · BACK = exit
// ═══════════════════════════════════════════════════════════════════════════
const LB_PERIODS = ["all", "week", "day"];
const LB_PERIOD_LBL = ["ALL", "WEEK", "TODAY"];

class LbScoresView extends WatchUi.View {
    hidden var _game;
    hidden var _variant;
    hidden var _title;
    hidden var _rows;         // top list
    hidden var _me;           // {r,s} or null
    hidden var _near;         // array around me, or null
    hidden var _count;        // total players
    hidden var _target;       // "beat this" score, or null
    hidden var _asc;          // lower-is-better game?
    hidden var _state;        // 0 loading, 1 ok, 2 error, 3 empty, 4 unsupported
    hidden var _scope;        // 0 global, 1 near
    hidden var _periodIdx;    // index into LB_PERIODS
    hidden var _user;
    hidden var _fetch;
    hidden var _scrollOff;
    hidden var _fitCount;
    hidden var _postGame;     // opened straight after a run → cache-bust + emphasis
    hidden var _retries;      // post-game: re-fetches left while the POST lands
    hidden var _retryTimer;
    hidden var _w;
    hidden var _h;

    function initialize(game, variant, title) {
        View.initialize();
        _game      = game;
        _variant   = variant;
        _title     = (title != null) ? title : "LEADERBOARD";
        _postGame  = false;
        _rows      = null;
        _me        = null;
        _near      = null;
        _count     = 0;
        _target    = null;
        _asc       = false;
        _state     = 0;
        _scope     = 0;
        _periodIdx = 0;
        _user      = null;
        _fetch     = null;
        _scrollOff = 0;
        _fitCount  = 0;
        _retries     = 0;
        _retryTimer  = null;
        _w = 0; _h = 0;
    }

    function onShow() {
        if (!Leaderboard.isSupported()) {
            _state = 4;
            WatchUi.requestUpdate();
            return;
        }
        if (!Leaderboard.hasUser()) {
            var nv = new LbNameEntryView();
            WatchUi.pushView(nv, new LbNameEntryDelegate(nv), WatchUi.SLIDE_LEFT);
            return;
        }
        _user = Leaderboard.loadUser();
        _doFetch();
    }

    // Call before pushing the view when opening it right after a run ends,
    // so the just-submitted score is fetched fresh (no stale CDN cache).
    function markPostGame() { _postGame = true; _retries = 4; }

    function onHide() {
        if (_retryTimer != null) { _retryTimer.stop(); _retryTimer = null; }
    }

    // Post-game only: the score POST is async and may not have committed to the
    // DB when our first GET lands, so we'd see me:null / empty. Re-fetch a few
    // times until the player's freshly-submitted row shows up.
    function _retryFetch() as Void {
        if (_retryTimer != null) { _retryTimer.stop(); _retryTimer = null; }
        _doFetch();
    }

    hidden function _doFetch() {
        _state     = 0;
        _scrollOff = 0;
        _fetch     = new LbFetch();
        _fetch.fetch(_game, _variant, _user, LB_PERIODS[_periodIdx], self, _postGame);
        WatchUi.requestUpdate();
    }

    // ── input intents ──
    function scroll(d) {
        var list = _activeList();
        if (list == null) { return; }
        var total = list.size(); if (total > 11) { total = 11; }
        _scrollOff = _scrollOff + d;
        if (_scrollOff < 0) { _scrollOff = 0; }
        var maxOff = total - _fitCount;
        if (maxOff < 0) { maxOff = 0; }
        if (_scrollOff > maxOff) { _scrollOff = maxOff; }
        WatchUi.requestUpdate();
    }

    function toggleScope() {
        // Near You only makes sense once we know where the player sits.
        if (_me == null || _near == null) { return; }
        _scope = (_scope == 0) ? 1 : 0;
        _scrollOff = 0;
        WatchUi.requestUpdate();
    }

    function cyclePeriod() {
        _periodIdx = (_periodIdx + 1) % LB_PERIODS.size();
        _scope = 0;
        _doFetch();
    }

    function resetName() {
        var nv = new LbNameEntryView();
        WatchUi.pushView(nv, new LbNameEntryDelegate(nv), WatchUi.SLIDE_LEFT);
    }

    hidden function _activeList() {
        if (_scope == 1 && _near != null && _near.size() > 0) { return _near; }
        return _rows;
    }

    // LbFetch listener callback — receives the full response dictionary.
    function onLeaderboard(ok, data) {
        if (!ok || !(data instanceof Lang.Dictionary)) {
            _state = 2; _scrollOff = 0; WatchUi.requestUpdate(); return;
        }
        var top = data["top"];
        _rows   = (top instanceof Lang.Array) ? top : null;
        _me     = (data["me"] instanceof Lang.Dictionary) ? data["me"] : null;
        _near   = (data["near"] instanceof Lang.Array) ? data["near"] : null;
        _count  = (data["count"] != null) ? data["count"] : 0;
        _target = data["target"];
        _asc    = (data["asc"] == true);

        // Post-game: if our just-submitted score hasn't surfaced yet (me still
        // null), the POST likely hasn't committed. Show "Loading..." and retry
        // shortly rather than flashing an empty board / no rank.
        if (_postGame && _me == null && _retries > 0) {
            _retries -= 1;
            _state = 0;
            if (_retryTimer != null) { _retryTimer.stop(); }
            _retryTimer = new Timer.Timer();
            _retryTimer.start(method(:_retryFetch), 1600, false);
            WatchUi.requestUpdate();
            return;
        }
        // Default scope: if the player exists but didn't crack the visible top
        // list, drop them straight into "Near You" so they SEE their position
        // among neighbours (the score to beat). Top-list players stay global
        // with their own row highlighted. This is the core engagement bit.
        if (_me == null) {
            _scope = 0;
        } else if (!_meInTop() && _near != null && _near.size() > 0) {
            _scope = 1;
        } else {
            _scope = 0;
        }
        _state  = (_rows == null || _rows.size() == 0) ? 3 : 1;
        _scrollOff = 0;
        WatchUi.requestUpdate();
    }

    // True when the player's rank appears in the fetched top list.
    hidden function _meInTop() {
        if (_me == null || _rows == null) { return false; }
        var myR = _me["r"];
        if (myR == null) { return false; }
        for (var i = 0; i < _rows.size(); i++) {
            if (_rows[i]["r"] == myR) { return true; }
        }
        return false;
    }

    // Rename hint text depends on input: touch watches long-press (onHold),
    // button-only watches reach rename through the MENU options menu.
    hidden function _renameHint() {
        var touch = false;
        try { touch = System.getDeviceSettings().isTouchScreen; } catch (e) {}
        return touch ? "HOLD = rename" : "MENU = options";
    }

    function scopeIsNear() { return _scope == 1; }
    function periodLabel() { return LB_PERIOD_LBL[_periodIdx]; }

    // ── rank tier, derived purely from rank + player count ──
    hidden function _tierLabel() {
        if (_me == null || _count <= 0) { return null; }
        var r = _me["r"];
        if (r == null) { return null; }
        if (r <= 100)          { return "ELITE"; }
        if (r <= _count / 10)  { return "PRO"; }
        if (r <= _count / 2)   { return "SOLID"; }
        return "RANKED";
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx = _w / 2;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var VC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(LB_BG, LB_BG); dc.clear();

        // ~10% smaller: keep all content inside a vertical inset so the top
        // title and the bottom hint/footer never hit the clipped chords of a
        // round screen (this is what kept the HOLD hint hidden before).
        var pad = (_h * 6) / 100; if (pad < fh / 2) { pad = fh / 2; }

        var footerCY = _h - pad - fh / 2;
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, footerCY, Graphics.FONT_XTINY, "bitochi.com", VC);

        // Title + period/scope status line.
        var titleCY = pad + fh / 2;
        dc.setColor(LB_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, titleCY, Graphics.FONT_XTINY, _title, VC);
        var headerBottom = titleCY + fh / 2;

        if (_state == 0) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h / 2, Graphics.FONT_XTINY, "Loading...", VC);
            return;
        }
        if (_state == 4) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h / 2 - fh, Graphics.FONT_XTINY, "Not available", VC);
            dc.drawText(cx, _h / 2 + fh, Graphics.FONT_XTINY, "on this watch", VC);
            return;
        }
        if (_state == 2) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h / 2 - fh, Graphics.FONT_XTINY, "No connection", VC);
            dc.drawText(cx, _h / 2 + fh, Graphics.FONT_XTINY, "try again later", VC);
            return;
        }

        // Status line: variant (if any) + period + scope. ASC games (fastest
        // time / fewest moves) get a "(LOW)" hint so seconds/move scores aren't
        // mistaken for higher-is-better.
        var status = LB_PERIOD_LBL[_periodIdx] + (_scope == 1 ? " NEAR" : " GLOBAL");
        if (_asc) { status = status + " (LOW)"; }
        if (_variant != null && _variant.length() > 0) { status = _variant + " " + status; }
        var statusCY = titleCY + fh;
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, statusCY, Graphics.FONT_XTINY, status, VC);
        headerBottom = statusCY + fh / 2;

        if (_state == 3) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h / 2 - fh, Graphics.FONT_XTINY, "No scores yet!", VC);
            dc.drawText(cx, _h / 2 + fh / 2, Graphics.FONT_XTINY, "Be the first!", VC);
            dc.setColor(0x4A6278, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, footerCY - fh, Graphics.FONT_XTINY, _renameHint(), VC);
            return;
        }

        // "YOU #r / N  TIER" + next-target / beat line.
        if (_me != null) {
            var r = _me["r"];
            var youCY = headerBottom + fh / 2 + 1;
            var tier  = _tierLabel();
            var youTxt = "YOU #" + r.toString() + "/" + _count.toString();
            dc.setColor(LB_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, youCY, Graphics.FONT_XTINY, youTxt, VC);
            headerBottom = youCY + fh / 2;

            var nextTxt = _nextTargetText();
            if (tier != null || nextTxt != null) {
                var lineCY = headerBottom + fh / 2 + 1;
                var combo  = "";
                if (tier != null)    { combo = tier; }
                if (nextTxt != null) { combo = (combo.length() > 0) ? combo + " " + nextTxt : nextTxt; }
                dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, lineCY, Graphics.FONT_XTINY, combo, VC);
                headerBottom = lineCY + fh / 2;
            }
        } else if (_target != null) {
            var beatCY = headerBottom + fh / 2 + 1;
            dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, beatCY, Graphics.FONT_XTINY,
                        "Beat " + _target.toString(), VC);
            headerBottom = beatCY + fh / 2;
        }

        // Controls hint — one line above the footer (a wider, safer band on
        // round screens than the very bottom chord).
        var hintCY = footerCY - fh;
        dc.setColor(0x4A6278, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, hintCY, Graphics.FONT_XTINY, _renameHint(), VC);

        // List viewport.
        var list = _activeList();
        var footerTop = hintCY - fh / 2;
        var lineH = fh + 3; if (lineH < 14) { lineH = 14; }
        var areaTop = headerBottom + 2;
        var areaH   = footerTop - 2 - areaTop;
        _fitCount = areaH / lineH;
        if (_fitCount < 1) { _fitCount = 1; }

        var total = list.size(); if (total > 11) { total = 11; }

        var rowsTop = areaTop;
        if (_scrollOff > 0) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, areaTop + fh / 2, Graphics.FONT_XTINY, "^", VC);
            rowsTop = areaTop + lineH;
            _fitCount = (footerTop - 2 - rowsTop) / lineH;
            if (_fitCount < 1) { _fitCount = 1; }
        }
        if (_scrollOff + _fitCount < total) {
            dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, footerTop - fh / 2, Graphics.FONT_XTINY, "v", VC);
        }

        var end = _scrollOff + _fitCount;
        if (end > total) { end = total; }

        var lcol = _w * 18 / 100;
        var rcol = _w * 82 / 100;

        for (var i = _scrollOff; i < end; i++) {
            var row  = list[i];
            var rank = row["r"];
            var u    = row["u"];
            var s    = row["s"];
            var mine = (u != null && _user != null && u.equals(_user));

            var clr  = LB_TEXT;
            if (mine)           { clr = LB_ACCENT; }
            else if (rank == 1) { clr = LB_GOLD; }
            else if (rank == 2) { clr = LB_SILVER; }
            else if (rank == 3) { clr = LB_BRONZE; }

            var cy = rowsTop + (i - _scrollOff) * lineH + lineH / 2;
            if (mine) {
                dc.setColor(0x10303C, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(0, cy - lineH / 2, _w, lineH);
            }
            dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lcol, cy, Graphics.FONT_XTINY,
                        rank.toString() + "  " + ((u != null) ? u : "anon"),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(rcol, cy, Graphics.FONT_XTINY,
                        (s != null) ? s.toString() : "0",
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Player ranked just above me (the closest score to beat).
    hidden function _nextTargetText() {
        if (_me == null || _near == null) { return null; }
        var myR = _me["r"];
        var myS = _me["s"];
        if (myR == null || myR <= 1) { return null; }
        for (var i = 0; i < _near.size(); i++) {
            if (_near[i]["r"] == myR - 1) {
                var ab = _near[i]["s"];
                if (ab == null || myS == null) { return null; }
                var diff = ab - myS; if (diff < 0) { diff = -diff; }
                return "+" + diff.toString();
            }
        }
        return null;
    }
}

class LbScoresDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(v) { BehaviorDelegate.initialize(); _view = v; }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP)   { _view.scroll(-1); return true; }
        if (k == WatchUi.KEY_DOWN) { _view.scroll(1);  return true; }
        if (k == WatchUi.KEY_MENU) { _openOptions();   return true; }
        return false;
    }
    function onNextPage()     { _view.scroll(1);  return true; }
    function onPreviousPage() { _view.scroll(-1); return true; }
    // MENU button → options (period, view, change name). This is the
    // button-only-watch path to renaming, since onHold is touch-only.
    function onMenu()         { _openOptions(); return true; }
    function onSelect()       { _view.toggleScope(); return true; }
    function onHold(evt)      { _view.resetName(); return true; }   // touch shortcut
    function onBack()         { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }

    hidden function _openOptions() {
        var m = new LbOptionsMenu(_view);
        WatchUi.pushView(m, new LbOptionsDelegate(_view), WatchUi.SLIDE_UP);
    }
}

// Options menu reachable from the MENU button on every device (the backup
// path for renaming on button-only watches that can't long-press the screen).
class LbOptionsMenu extends WatchUi.Menu2 {
    function initialize(view) {
        Menu2.initialize({:title => "OPTIONS"});
        addItem(new WatchUi.MenuItem("Change name", null, :rename, null));
        addItem(new WatchUi.MenuItem("View",
                (view.scopeIsNear() ? "Near you" : "Global"), :view, null));
        addItem(new WatchUi.MenuItem("Period", view.periodLabel(), :period, null));
    }
}

class LbOptionsDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _view;
    function initialize(view) { Menu2InputDelegate.initialize(); _view = view; }
    function onSelect(item) {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (id == :rename)      { _view.resetName();   }
        else if (id == :view)   { _view.toggleScope(); }
        else if (id == :period) { _view.cyclePeriod(); }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Post-game auto-display. A game calls Leaderboard.showPostGame(...) right
// after submitting its score at game-over; we wait briefly so the player sees
// their own result screen (and the score POST lands), then slide the global
// leaderboard up — showing YOU #rank/N, tier/achievement, nearest player to
// beat + the gap, and the Near-You list. Back returns to the game's screen.
// The Timer lives on a held instance so it survives the async delay.
// ═══════════════════════════════════════════════════════════════════════════
class LbPostGame {
    hidden var _t;
    hidden var _game;
    hidden var _variant;
    hidden var _title;
    function initialize(game, variant, title) {
        _game    = game;
        _variant = variant;
        _title   = (title != null) ? title : "LEADERBOARD";
        _t       = null;
    }
    function arm(delayMs) {
        _t = new Timer.Timer();
        _t.start(method(:_fire), delayMs, false);
    }
    function _fire() as Void {
        if (_t != null) { _t.stop(); _t = null; }
        var v = new LbScoresView(_game, _variant, _title);
        v.markPostGame();
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_UP);
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Menu badge helper — draws a hype-y "LEADERBOARD" row for a game's own menu.
// Returns nothing; the caller positions it. Gold-accented so it stands out.
// ═══════════════════════════════════════════════════════════════════════════
module LbBadge {
    // True when the leaderboard is usable on this watch. Games may call this to
    // skip the row from menu navigation entirely; drawRow also greys itself out.
    function isActive() {
        return Leaderboard.isSupported();
    }

    function drawRow(dc, x, y, w, rowH, selected) {
        // Inactive (no network capability) → flat grey, "unavailable" label.
        if (!Leaderboard.isSupported()) {
            dc.setColor(0x161616, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, w, rowH, 5);
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x, y, w, rowH, 5);
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + w / 2, y + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        "LEADERBOARD N/A", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

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
