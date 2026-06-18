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
        var user = loadUser();
        if (user == null) { user = "anon"; }
        _sender = new LbSubmitter();
        _sender.send(game, user, score, variant);
    }

    // ── Launch ping (fire-and-forget) ─────────────────────────────────────────
    // Call once from a game's App.onStart so the backend can record that the
    // game was opened — even for games/sessions that never submit a score. This
    // powers the "games are being played" view on the admin stats page. Guarded
    // so it only fires once per process, and silent on unsupported watches.
    var _pinger      = null;
    var _launchLogged = false;
    function logLaunch(game as Lang.String) as Void {
        if (!isSupported()) { return; }
        if (_launchLogged) { return; }
        _launchLogged = true;
        _pinger = new LbPinger();
        _pinger.send(game);
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
