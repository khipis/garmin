// ═══════════════════════════════════════════════════════════════════════════
// Entitlement.mc — Full-version unlock foundation for all Bitochi games.
//
// A tiny, fully-offline licensing layer. Each game can gate content (extra
// modes, removal of a play-count limit, etc.) behind Entitlement.isUnlocked().
// The player types a code once in OPTIONS → "Unlock full version"; we verify it
// LOCALLY (no network) and persist the unlocked flag in Application.Storage.
//
// Code scheme (obfuscation-grade, like the leaderboard SUBMIT_KEY):
//   code = base32( hash(SECRET + ":" + gameId) )  truncated to CODE_LEN chars.
// It is deterministic per game, so codes can be minted offline later with the
// same algorithm (see tools/gen-unlock-codes for the generator). This is NOT
// cryptographically strong — it stops casual sharing/guessing, not a determined
// attacker who reverse-engineers the binary. Rotate by bumping SECRET.
//
// Storage keys (per-app; Garmin has no cross-app storage):
//   ent_<gameId>  => true once unlocked for this game
//   ent_ALL       => true unlocks every game on this watch (master code)
//
// Nothing here ever throws into the host game: every access is guarded.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;

module Entitlement {

    // Bump this to invalidate every previously-issued code.
    const SECRET   = "btchi-unlock-v1";
    const CODE_LEN = 8;                       // characters the player types
    // Crockford-ish base32 minus ambiguous chars (no I, L, O, U) → matches the
    // code-entry wheel alphabet so every mintable code is typeable.
    const ALPHABET = "ABCDEFGHJKMNPQRSTVWXYZ0123456789";

    const KEY_PRE  = "ent_";
    const KEY_ALL  = "ent_ALL";

    // ── Public API ────────────────────────────────────────────────────────────

    // True when this game (or the master code) has been unlocked on this watch.
    function isUnlocked(gameId as Lang.String) as Lang.Boolean {
        try {
            if (Application.Storage.getValue(KEY_ALL) == true) { return true; }
            if (Application.Storage.getValue(KEY_PRE + gameId) == true) { return true; }
        } catch (e) {}
        return false;
    }

    // Try to redeem a typed code for a game. Accepts either the game's own code
    // or the master ("unlock everything") code. Persists + returns true on match.
    function tryRedeem(gameId as Lang.String, code as Lang.String) as Lang.Boolean {
        if (code == null) { return false; }
        var c = _clean(code);
        if (c.length() == 0) { return false; }
        if (c.equals(_codeFor("ALL"))) {
            _store(KEY_ALL);
            return true;
        }
        if (c.equals(_codeFor(gameId))) {
            _store(KEY_PRE + gameId);
            return true;
        }
        return false;
    }

    // Admin/testing: force (un)lock without a code.
    function setUnlocked(gameId as Lang.String, on as Lang.Boolean) as Void {
        try { Application.Storage.setValue(KEY_PRE + gameId, on); } catch (e) {}
    }

    // The canonical code for a game id (exposed so a generator can print it).
    function codeFor(gameId as Lang.String) as Lang.String { return _codeFor(gameId); }

    // ── Internals ───────────────────────────────────────────────────────────────

    function _store(key as Lang.String) as Void {
        try { Application.Storage.setValue(key, true); } catch (e) {}
    }

    // Strip spaces + upper-case + drop characters not on the alphabet so the
    // player can type with or without separators.
    function _clean(s as Lang.String) as Lang.String {
        var up  = s.toUpper();
        var out = "";
        for (var i = 0; i < up.length(); i++) {
            var ch = up.substring(i, i + 1);
            if (ALPHABET.find(ch) != null) { out = out + ch; }
        }
        return out;
    }

    // Deterministic per-id code. FNV-1a-style rolling hash over SECRET:gameId,
    // re-hashed per output character so all CODE_LEN chars depend on the whole
    // input (avoids trivially-related codes across similar game ids).
    function _codeFor(gameId as Lang.String) as Lang.String {
        var seed = SECRET + ":" + gameId;
        var h = _hash(seed);
        var out = "";
        var n = ALPHABET.length();
        for (var i = 0; i < CODE_LEN; i++) {
            h = _hash(seed + ":" + i.toString() + ":" + h.toString());
            var idx = h % n;
            if (idx < 0) { idx = -idx; }
            out = out + ALPHABET.substring(idx, idx + 1);
        }
        return out;
    }

    // 31-bit FNV-1a; kept positive and within Number range.
    function _hash(s as Lang.String) as Lang.Number {
        var h = 0x811c9dc5;
        var b = s.toUtf8Array();
        for (var i = 0; i < b.size(); i++) {
            h = (h ^ b[i]) & 0x7fffffff;
            // h * 16777619, masked to 31 bits to stay in Number range.
            h = ((h * 16777619) & 0x7fffffff);
        }
        if (h < 0) { h = -h; }
        return h;
    }
}
