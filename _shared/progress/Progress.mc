// ═══════════════════════════════════════════════════════════════════════════
// Progress.mc — Shared, SHOP-READY meta-progression for Bitochi games.
//
// A tiny, fully-guarded economy/XP/ownership/streak layer that every game can
// opt into by adding `../_shared/progress` to its monkey.jungle sourcePath.
//
// Design goals:
//   • Never throws — every Storage access is wrapped; safe on any device.
//   • Per-app storage (each game compiles its own copy) → no game-id needed.
//   • SHOP-READY: currency is a first-class balance with spendCoins(); item
//     ownership is tracked separately from HOW it was obtained. A future in-app
//     shop just calls `Progress.spendCoins(price)` then `Progress.unlock(id)` —
//     the exact same ownership set the games already read. Nothing here blocks
//     adding a paid store later; progression unlocks and purchases coexist.
//
// What lives here:
//   • Coins (soft currency)      — earn by playing, spend in a future shop.
//   • XP / level / rank          — long-term progression + rank titles.
//   • Ownership set              — cosmetics / gear the player has unlocked.
//   • Login streak + daily bonus — retention driver, once-per-day check-in.
//
// What stays in the game:
//   • WHICH items exist, their unlock thresholds, and how they render.
//   • Cosmetic *selection* (usually a GmOption cycler); games clamp the choice
//     to what Progress.owns().
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

module Progress {

    // ── Storage keys (per-app) ───────────────────────────────────────────────
    const COINS_KEY  = "pg_coins";   // Number — soft-currency balance
    const XP_KEY     = "pg_xp";      // Number — lifetime XP
    const OWN_KEY    = "pg_own";     // Dictionary { itemId => true }
    const STREAK_KEY = "pg_streak";  // Dictionary { last:"YYYYMMDD", n:Number, best:Number }

    // XP required per level (flat, predictable). level = 1 + xp/XP_PER_LEVEL.
    const XP_PER_LEVEL = 150;

    // ── Low-level guarded storage ────────────────────────────────────────────
    function _getNum(key as Lang.String) as Lang.Number {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number) { return v; }
            if (v instanceof Lang.Float)  { return v.toNumber(); }
        } catch (e) {}
        return 0;
    }

    function _setNum(key as Lang.String, n as Lang.Number) as Void {
        try { Application.Storage.setValue(key, n); } catch (e) {}
    }

    function _getDict(key as Lang.String) as Lang.Dictionary {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Dictionary) { return v; }
        } catch (e) {}
        return {};
    }

    function _setDict(key as Lang.String, d as Lang.Dictionary) as Void {
        try { Application.Storage.setValue(key, d); } catch (e) {}
    }

    // ── Coins (soft currency) ────────────────────────────────────────────────
    function coins() as Lang.Number { return _getNum(COINS_KEY); }

    // Add coins (clamped at 0), returns the new balance.
    function addCoins(n as Lang.Number) as Lang.Number {
        var t = coins() + n;
        if (t < 0) { t = 0; }
        _setNum(COINS_KEY, t);
        return t;
    }

    // SHOP-READY: try to spend `n` coins. Returns true and deducts if the
    // player can afford it, false (no change) otherwise.
    function spendCoins(n as Lang.Number) as Lang.Boolean {
        if (n <= 0) { return true; }
        var c = coins();
        if (c < n) { return false; }
        _setNum(COINS_KEY, c - n);
        return true;
    }

    // ── XP / level / rank ────────────────────────────────────────────────────
    function xp() as Lang.Number { return _getNum(XP_KEY); }

    // Add XP (clamped at 0), returns the new lifetime XP total.
    function addXp(n as Lang.Number) as Lang.Number {
        var t = xp() + n;
        if (t < 0) { t = 0; }
        _setNum(XP_KEY, t);
        return t;
    }

    // 1-based level.
    function level() as Lang.Number { return 1 + (xp() / XP_PER_LEVEL); }

    // XP accumulated inside the current level (0 .. XP_PER_LEVEL-1).
    function xpIntoLevel() as Lang.Number { return xp() % XP_PER_LEVEL; }

    // XP span of one level (constant here, exposed for progress bars).
    function xpForLevel() as Lang.Number { return XP_PER_LEVEL; }

    // Generic rank title from level. Games may map level() to their own themed
    // titles instead; this is a sensible default.
    function rankName() as Lang.String {
        var l = level();
        if (l >= 25) { return "Legend"; }
        if (l >= 15) { return "Master"; }
        if (l >= 10) { return "Expert"; }
        if (l >= 6)  { return "Pro"; }
        if (l >= 3)  { return "Amateur"; }
        return "Rookie";
    }

    // ── Ownership (cosmetics / gear) ─────────────────────────────────────────
    function owns(id as Lang.String) as Lang.Boolean {
        var d = _getDict(OWN_KEY);
        try { return d.hasKey(id) && d[id] == true; } catch (e) {}
        return false;
    }

    // Grant an item (idempotent). Source-agnostic: progression OR a future shop
    // purchase both call this after their own checks.
    function unlock(id as Lang.String) as Void {
        if (owns(id)) { return; }
        var d = _getDict(OWN_KEY);
        d[id] = true;
        _setDict(OWN_KEY, d);
    }

    // Convenience: unlock `id` the first time `have >= need`. Returns true only
    // on the transition (so the game can show a one-time "NEW!" banner).
    function unlockIfReached(id as Lang.String, have as Lang.Number,
                             need as Lang.Number) as Lang.Boolean {
        if (owns(id)) { return false; }
        if (have >= need) { unlock(id); return true; }
        return false;
    }

    // How many ids from `list` are owned (for "3/6 skins" style summaries).
    function ownedIn(list as Lang.Array) as Lang.Number {
        var n = 0;
        for (var i = 0; i < list.size(); i++) {
            if (owns(list[i])) { n = n + 1; }
        }
        return n;
    }

    // ── Login streak + daily bonus ───────────────────────────────────────────
    function _todayKey() as Lang.String {
        try {
            var ci = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var mo = ci.month < 10 ? "0" + ci.month.toString() : ci.month.toString();
            var d  = ci.day   < 10 ? "0" + ci.day.toString()   : ci.day.toString();
            return ci.year.toString() + mo + d;
        } catch (e) {}
        return "00000000";
    }

    // Ordinal day number since a fixed epoch — used only to tell "yesterday"
    // from "older" for streak continuation. Robust across month/year edges.
    function _dayNumber() as Lang.Number {
        try {
            var secs = Time.now().value();   // unix seconds
            return secs / 86400;
        } catch (e) {}
        return 0;
    }

    function currentStreak() as Lang.Number {
        var d = _getDict(STREAK_KEY);
        try { if (d.hasKey("n") && d["n"] instanceof Lang.Number) { return d["n"]; } } catch (e) {}
        return 0;
    }

    function bestStreak() as Lang.Number {
        var d = _getDict(STREAK_KEY);
        try { if (d.hasKey("best") && d["best"] instanceof Lang.Number) { return d["best"]; } } catch (e) {}
        return 0;
    }

    // Call ONCE per app launch. Advances/repairs the login streak and, on the
    // first launch of a new day, grants a bonus (bigger with longer streaks).
    // Returns { first:Bool, streak:Number, best:Number, bonus:Number }.
    //   first  — true only on the day's first launch (show a bonus card then)
    //   bonus  — coins granted today (already added to the balance)
    function checkIn() as Lang.Dictionary {
        var d       = _getDict(STREAK_KEY);
        var todayS  = _todayKey();
        var todayN  = _dayNumber();

        var last   = null;
        var lastN  = -1;
        var n      = 0;
        var best   = 0;
        try { if (d.hasKey("last") && d["last"] instanceof Lang.String) { last  = d["last"]; } } catch (e) {}
        try { if (d.hasKey("ln")   && d["ln"]   instanceof Lang.Number) { lastN = d["ln"]; } } catch (e) {}
        try { if (d.hasKey("n")    && d["n"]    instanceof Lang.Number) { n     = d["n"]; } } catch (e) {}
        try { if (d.hasKey("best") && d["best"] instanceof Lang.Number) { best  = d["best"]; } } catch (e) {}

        // Already checked in today → no bonus, report current state.
        if (last != null && last.equals(todayS)) {
            return { "first" => false, "streak" => n, "best" => best, "bonus" => 0 };
        }

        // New day: continue the streak if the last check-in was yesterday,
        // otherwise reset to 1.
        if (lastN >= 0 && (todayN - lastN) == 1) { n = n + 1; }
        else                                     { n = 1; }
        if (n > best) { best = n; }

        // Bonus grows with the streak, capped so it stays a nudge, not a grind.
        var bonus = 10 + (n - 1) * 5;
        if (bonus > 60) { bonus = 60; }
        addCoins(bonus);

        _setDict(STREAK_KEY,
            { "last" => todayS, "ln" => todayN, "n" => n, "best" => best });

        return { "first" => true, "streak" => n, "best" => best, "bonus" => bonus };
    }
}
