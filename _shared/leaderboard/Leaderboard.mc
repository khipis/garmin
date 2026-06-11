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
//   <iq:permissions><iq:permission id="Communications"/></iq:permissions>
// ═══════════════════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;

module Leaderboard {

    // ── CONFIG ──────────────────────────────────────────────────────────────
    // Replace with the deployed Worker URL (or custom domain mapped to it).
    const API_BASE = "https://garmin-leaderboard.YOURSUBDOMAIN.workers.dev";

    const USER_KEY  = "lb_user";   // Application.Storage key for the username
    const NAME_LEN  = 8;           // max username characters
    // Character wheel: A-Z, 0-9, space (index 36 == space, shown as "_").
    const ALPHABET  = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ";
    const SPACE_IDX = 36;

    // ── Username persistence ─────────────────────────────────────────────────
    function loadUser() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue(USER_KEY);
            if (v instanceof Lang.String && v.length() > 0) { return v; }
        } catch (e) {}
        return null;
    }

    function saveUser(name as Lang.String) as Void {
        try { Application.Storage.setValue(USER_KEY, name); } catch (e) {}
    }

    function hasUser() as Lang.Boolean {
        return loadUser() != null;
    }

    // ── Score submission (fire-and-forget) ───────────────────────────────────
    // variant may be null or "" for games without sub-categories.
    function submitScore(game as Lang.String, score as Lang.Number,
                         variant as Lang.String or Null) as Void {
        var user = loadUser();
        if (user == null) { user = "anon"; }

        var body = {
            "game"  => game,
            "user"  => user,
            "score" => score
        };
        if (variant != null && variant.length() > 0) {
            body["variant"] = variant;
        }

        var opts = {
            :method       => Communications.HTTP_REQUEST_METHOD_POST,
            :headers      => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        try {
            Communications.makeWebRequest(API_BASE + "/score", body, opts,
                                          method(:_onSubmit));
        } catch (e) {}
    }

    function _onSubmit(code as Lang.Number, data) as Void {
        // Silent — never block or interrupt the player on a network result.
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
