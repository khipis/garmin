// ═══════════════════════════════════════════════════════════════════════════
// Leaderboard.mc — Shared global-leaderboard client for all Bitochi games.
//
// SKELETON. Drop-in module reused by every game via the jungle sourcePath:
//     base.sourcePath = source;../_shared/leaderboard
//
// Backend: Cloudflare Worker + D1 (see /leaderboard).  Endpoints used:
//   POST /score          { game, user, score, variant? }
//   GET  /leaderboard?game=X[&variant=Y]   -> { top:[ {r,u,s}, ... ] }
//
// Username:
//   Stored per-app in Application.Storage under USER_KEY.  Garmin has no
//   cross-app shared storage, so each game persists its own copy — entered
//   once, then remembered forever for that game.  (A future cloud-side
//   identity could unify these; out of scope for the skeleton.)
//
// Permission required in each game's manifest.xml:
//   <iq:permissions><iq:uses-permission id="Communications"/></iq:permissions>
// ═══════════════════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Time;
using Toybox.Timer;
using Toybox.WatchUi;

module Leaderboard {

    // ── CONFIG ──────────────────────────────────────────────────────────────
    // Replace with the deployed Worker URL (or custom domain mapped to it).
    const API_BASE = "https://api.bitochi.com";

    // Shared submit key sent as the X-LB-Key header on POST /score. The backend
    // rejects writes without it (403). NOTE: this ships inside every app binary,
    // so it is obfuscation-grade — it stops casual/script spam against the
    // public endpoint, not a determined attacker who extracts it. Rotate by
    // changing this value, `wrangler secret put LB_KEY`, and rebuilding apps.
    const SUBMIT_KEY = "a7f3c9e21d8b45069c2af7b4d80e1635";

    const USER_KEY  = "lb_user";   // Application.Storage key for the username
    const NAME_LEN  = 8;           // max username characters
    // Character wheel: A-Z, 0-9, space (index 36 == space, shown as "_").
    const ALPHABET  = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ";
    const SPACE_IDX = 36;

    // ── Capability check ─────────────────────────────────────────────────────
    // True only on watches that can make HTTPS requests. Older/limited devices
    // lack Communications.makeWebRequest — there the leaderboard is shown as
    // inactive and submissions are skipped instead of throwing.
    function isSupported() as Lang.Boolean {
        if (!(Toybox has :Communications)) { return false; }
        return Communications has :makeWebRequest;
    }

    // True when the paired phone (or a direct WiFi path) is currently reachable.
    // Web requests MUST NOT be attempted when this is false: on several Garmin
    // firmware versions makeWebRequest called while disconnected terminates the
    // host app instead of returning an error via callback. We gate every
    // fire-and-forget network call on this check so offline players always get a
    // clean, crash-free experience with cached data shown instead.
    function isPhoneConnected() as Lang.Boolean {
        try {
            if (!(Toybox.System has :getDeviceSettings)) { return false; }
            var s = System.getDeviceSettings();
            if (s == null) { return false; }
            // phoneConnected covers BT; connectionInfo covers WiFi on newer devices.
            if (s has :phoneConnected && s.phoneConnected == true) { return true; }
            if (s has :connectionInfo) {
                var ci = s.connectionInfo;
                if (ci instanceof Lang.Dictionary) {
                    var wifi = ci[:wifiConnected];
                    if (wifi == true) { return true; }
                }
            }
        } catch (e) {}
        return false;
    }

    // ── Username persistence ─────────────────────────────────────────────────
    function loadUser() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue(USER_KEY);
            if (v instanceof Lang.String && v.length() > 0) { return v; }
        } catch (e) {}
        return null;
    }

    function saveUser(name as Lang.String) as Void {
        // Store locally only. We deliberately do NOT re-send a previously
        // submitted "anon" score under the new name: the backend only INSERTs
        // (never updates/deletes), so re-sending produced a DUPLICATE — an
        // orphan "anon" row PLUS a named row with the same score. Scores played
        // while anonymous stay under "anon"; from the next game on they post
        // under the chosen name.
        try { Application.Storage.setValue(USER_KEY, name); } catch (e) {}
    }

    function hasUser() as Lang.Boolean {
        return loadUser() != null;
    }

    // ── Score submission (fire-and-forget) ───────────────────────────────────
    // variant may be null or "" for games without sub-categories.
    //
    // The actual request lives on LbSubmitter (a class) because Garmin's
    // makeWebRequest callback must be a bound method() and module functions
    // have no instance to bind to. We hold the sender in a module var so it
    // survives until the async response arrives.
    var _sender = null;

    function submitScore(game as Lang.String, score as Lang.Number,
                         variant as Lang.String or Null) as Void {
        if (!isSupported()) { return; }
        if (!isPhoneConnected()) { return; }
        var user = loadUser();
        if (user == null) { user = "anon"; }
        _sender = new LbSubmitter();
        _sender.send(game, user, score, variant, null);
    }

    // Same as submitScore(), but attaches a small JSON-serialisable dictionary
    // of extra fields (species, rarity, ...) that the web leaderboard can use
    // to render a richer "trophy" entry (e.g. fish/biggest-fish variant with a
    // graphical fish icon). Keep the dictionary small — the backend caps the
    // serialised meta blob at 512 chars.
    function submitScoreWithMeta(game as Lang.String, score as Lang.Number,
                                 variant as Lang.String or Null,
                                 meta as Lang.Dictionary or Null) as Void {
        if (!isSupported()) { return; }
        if (!isPhoneConnected()) { return; }
        var user = loadUser();
        if (user == null) { user = "anon"; }
        _sender = new LbSubmitter();
        _sender.send(game, user, score, variant, meta);
    }

    // ── Launch ping (fire-and-forget) ─────────────────────────────────────────
    // Call once from a game's App.onStart so the backend can record that the
    // game was opened — even for games/sessions that never submit a score. This
    // powers the "games are being played" view on the admin stats page. Guarded
    // so it only fires once per process, and silent on unsupported watches.
    //
    // Network calls are skipped when the phone is not connected: some Garmin
    // firmware versions crash the app instead of returning an error via callback
    // when makeWebRequest is called with no BT/WiFi link. The cached message
    // bundle and the 'once' call-to-action still work offline.
    var _pinger       = null;
    var _launchLogged = false;
    function logLaunch(game as Lang.String) as Void {
        if (!isSupported()) { return; }
        if (_launchLogged) { return; }
        _launchLogged = true;
        try {
            if (isPhoneConnected()) {
                _pinger = new LbPinger();
                _pinger.send(game);
                // Refresh the message bundle (shown from cache NEXT run; the
                // delay also ensures pinger is the only in-flight request now).
                fetchMessages(game);
            }
        } catch (e) {}
        // The 'once' card reads the cached bundle so it works offline too.
        try {
            _onceTimer = new LbOnceTimer(game);
            _onceTimer.start();
        } catch (e) {}
    }

    // ── Custom messages / announcements ───────────────────────────────────────
    // See LbMessages.mc for the views + fetcher, and COMMUNICATIONS.md for how
    // the whole thing is configured. All keys below live in Application.Storage
    // (per-app), so no game-id qualifier is needed.
    const MSG_LAUNCH    = "launch";
    const MSG_POSTGAME  = "postgame";
    const MSG_CACHE_KEY = "lb_msg_cache";    // last fetched bundle (Dictionary)
    const MSG_FETCH_KEY = "lb_msg_fetch";    // unix-sec of last successful fetch
    const MSG_RESET_ACK = "lb_msg_reset_ack";// reset_at (ms) we've already shown
    const MSG_ONCE_ACK  = "lb_msg_once_ack"; // once_at (ms) epoch we've already shown
    const MSG_SHOWN_PRE = "lb_msg_shown_";   // + placement → last shown unix-sec

    var _msgFetcher = null;
    var _onceTimer  = null;   // keeps the launch one-shot timer alive (see logLaunch)

    // Fire-and-forget: pull the resolved message bundle and cache it. Called
    // automatically by logLaunch(); games rarely need to call it directly.
    // Fully guarded: a failure to fetch NEVER affects the game — it just means
    // no (new) message is cached.
    function fetchMessages(game as Lang.String) as Void {
        if (!isSupported()) { return; }
        if (!isPhoneConnected()) { return; }
        try {
            _msgFetcher = new LbMessageFetcher();
            _msgFetcher.send(game);
        } catch (e) {}
    }

    function _cachedBundle() {
        try {
            var v = Application.Storage.getValue(MSG_CACHE_KEY);
            if (v instanceof Lang.Dictionary) { return v; }
        } catch (e) {}
        return null;
    }

    function _nowSec() { return Time.now().value(); }

    // Show the message configured for `placement` if one is cached and the
    // per-placement throttle (min_gap_s) has elapsed. `fallback` is an optional
    // Dictionary {title, body, url, url_label} used when nothing is cached yet
    // (offline / first launch) — great for a guaranteed static invite. Returns
    // true when a view was pushed.
    function showMessage(game as Lang.String, placement as Lang.String,
                         fallback as Lang.Dictionary or Null) as Lang.Boolean {
        if (!isSupported()) { return false; }
        // Wrap everything: nothing about messages may ever throw into the game.
        try {
            var bundle = _cachedBundle();
            var msg = null;
            if (bundle != null) { msg = bundle[placement]; }
            if (!(msg instanceof Lang.Dictionary)) { msg = fallback; }
            if (!(msg instanceof Lang.Dictionary)) { return false; }

            var gap = 21600;
            if (msg["min_gap_s"] instanceof Lang.Number) { gap = msg["min_gap_s"]; }
            var key = MSG_SHOWN_PRE + placement;
            var last = 0;
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number) { last = v; }
            var now = _nowSec();
            if (last > 0 && (now - last) < gap) { return false; }
            // Only record "shown" once the view was actually pushed — a failed
            // push must not silently burn the 12h throttle window.
            if (_pushMessage(msg)) {
                Application.Storage.setValue(key, now);
                return true;
            }
            return false;
        } catch (e) {
            return false;
        }
    }

    // Post-game helper: returns the message dict to show (server bundle first,
    // else the built-in fallback) when the throttle allows, marking it shown; or
    // null when nothing is due. The caller pushes the view (see LbPostGame), so
    // we DON'T push here — this keeps the "message → then board" flow to a single
    // active view at a time (two stacked pushView calls proved unreliable).
    function duePostGameMessage() as Lang.Dictionary or Null {
        if (!isSupported()) { return null; }
        try {
            var bundle = _cachedBundle();
            var msg = null;
            if (bundle != null) { msg = bundle[MSG_POSTGAME]; }
            if (!(msg instanceof Lang.Dictionary)) { msg = defaultPostGameMsg(); }
            if (!(msg instanceof Lang.Dictionary)) { return null; }

            var gap = 21600;
            if (msg["min_gap_s"] instanceof Lang.Number) { gap = msg["min_gap_s"]; }
            var key = MSG_SHOWN_PRE + MSG_POSTGAME;
            var last = 0;
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number) { last = v; }
            var now = _nowSec();
            if (last > 0 && (now - last) < gap) { return null; }
            Application.Storage.setValue(key, now);
            return msg;
        } catch (e) {
            return null;
        }
    }

    // Show the 'reset' message once, if the leaderboard was wiped since we last
    // acknowledged. Never fires on a fresh install (records a baseline instead),
    // so a first-time player isn't told about a "reset" they never lived through.
    function showResetMessageIfAny(game as Lang.String) as Lang.Boolean {
        if (!isSupported()) { return false; }
        try {
            var bundle = _cachedBundle();
            if (bundle == null) { return false; }
            var resetAt = bundle["reset_at"];
            if (!(resetAt instanceof Lang.Number) && !(resetAt instanceof Lang.Long)) { return false; }
            if (resetAt == 0) { return false; }

            var ack = 0;
            var v = Application.Storage.getValue(MSG_RESET_ACK);
            if (v instanceof Lang.Number || v instanceof Lang.Long) { ack = v; }
            if (resetAt <= ack) { return false; }
            Application.Storage.setValue(MSG_RESET_ACK, resetAt);
            if (ack == 0) { return false; }   // first run → just record the baseline

            var msg = bundle["reset"];
            if (!(msg instanceof Lang.Dictionary)) { return false; }
            _pushMessage(msg);
            return true;
        } catch (e) {
            return false;
        }
    }

    // Show the one-shot 'once' message a single time, ever, until it's re-armed
    // server-side. The bundle's `once_at` is the message's updated_at epoch;
    // editing / re-arming it from stats.html bumps that value, so a client that
    // already showed the previous epoch shows the new one once more. Unlike
    // `reset` this DOES fire on a fresh install (ack starts at 0), so every
    // player sees the payment call-to-action exactly once. Fully guarded.
    function showOnceIfDue(game as Lang.String) as Lang.Boolean {
        if (!isSupported()) { return false; }
        try {
            var bundle = _cachedBundle();
            if (bundle == null) { return false; }
            var onceAt = bundle["once_at"];
            if (!(onceAt instanceof Lang.Number) && !(onceAt instanceof Lang.Long)) { return false; }
            if (onceAt == 0) { return false; }

            var ack = 0;
            var v = Application.Storage.getValue(MSG_ONCE_ACK);
            if (v instanceof Lang.Number || v instanceof Lang.Long) { ack = v; }
            if (onceAt <= ack) { return false; }

            var msg = bundle["once"];
            if (!(msg instanceof Lang.Dictionary)) { return false; }
            // Record the epoch BEFORE pushing so a second near-simultaneous call
            // (e.g. announce + the launch timer) can't double-show it.
            Application.Storage.setValue(MSG_ONCE_ACK, onceAt);
            _pushMessage(msg);
            return true;
        } catch (e) {
            return false;
        }
    }

    // Convenience for a game's menu: prefer the one-shot 'once' call-to-action,
    // then the (once-only) reset message, otherwise the throttled launch message.
    // Call this when the main menu becomes visible. `fallback` covers
    // offline/first-run for the launch slot.
    function announce(game as Lang.String, fallback as Lang.Dictionary or Null) as Lang.Boolean {
        try {
            if (showOnceIfDue(game)) { return true; }
            if (showResetMessageIfAny(game)) { return true; }
            return showMessage(game, MSG_LAUNCH, fallback);
        } catch (e) {
            return false;
        }
    }

    function _pushMessage(msg) {
        try {
            var v = new LbMessageView(msg);
            WatchUi.pushView(v, new LbMessageDelegate(v), WatchUi.SLIDE_UP);
            return true;
        } catch (e) {
            return false;
        }
    }

    // Built-in default post-game card. Used as the `fallback` for showMessage so
    // the support/tip invite still appears on a cold cache (first run after
    // install) or fully offline. When the server bundle IS cached it wins over
    // this — so the owner can freely re-word the live message from stats.html.
    function defaultPostGameMsg() as Lang.Dictionary {
        return {
            "title"     => "Enjoying Bitochi?",
            "body"      => "All games are free & ad-free. A small tip keeps new ones coming!",
            "url"       => "https://bitochi.com/coffee",
            "url_label" => "bitochi.com/coffee",
            "min_gap_s" => 43200
        };
    }

    // ── Post-game leaderboard pop-up ──────────────────────────────────────────
    // Call right after submitScore() at a game-over / completion point. After a
    // short delay (so the game's own result screen shows first and the POST
    // lands) it slides the leaderboard up with the player's rank, tier and the
    // nearest score to beat. No-op on watches without web support. Debounced so
    // a game with two adjacent submit paths can't stack two pop-ups.
    var _pg     = null;
    var _pgLast = 0;
    function showPostGame(game as Lang.String, variant as Lang.String or Null,
                          title as Lang.String or Null) as Void {
        if (!isSupported()) { return; }
        var now = System.getTimer();
        if (_pg != null && (now - _pgLast) >= 0 && (now - _pgLast) < 2000) { return; }
        _pgLast = now;
        _pg = new LbPostGame(game, variant, title);
        _pg.arm(1600);
    }

    // ── Build a clean username from a wheel-index array ───────────────────────
    function buildName(chars as Lang.Array) as Lang.String {
        var s = "";
        for (var i = 0; i < NAME_LEN; i++) {
            s = s + ALPHABET.substring(chars[i], chars[i] + 1);
        }
        var len = NAME_LEN;
        while (len > 0 && chars[len - 1] == SPACE_IDX) { len--; }
        if (len == 0) { return "ANON"; }
        return s.substring(0, len);
    }
}
