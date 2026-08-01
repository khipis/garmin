// ═══════════════════════════════════════════════════════════════════════════
// SaveManager.mc — Persistent progression + mid-run resume (module `BrSave`).
//
// Records only what survives a run (bests, escapes, artifacts, unlocked
// floors). The mid-run blob is deliberately tiny: because MapGenerator is
// deterministic, storing the seed and the level rebuilds the exact floor, so a
// resume costs eight numbers instead of a serialised grid.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;

module BrSave {

    function _get(k, def) {
        try {
            var v = Application.Storage.getValue(k);
            if (v != null) { return v; }
        } catch (e) {}
        return def;
    }
    function _set(k, v) {
        try { Application.Storage.setValue(k, v); } catch (e) {}
    }
    function num(k, def) {
        var v = _get(k, def);
        if (v instanceof Lang.Number) { return v; }
        if (v instanceof Lang.Float) { return v.toNumber(); }
        return def;
    }

    function bestTime()   { return num("br_btime", 0); }
    function bestDepth()  { return num("br_bdepth", 0); }
    function escapes()    { return num("br_escapes", 0); }
    function relics()     { return num("br_relics", 0); }
    function roomsSeen()  { return num("br_rooms", 0); }
    function runs()       { return num("br_runs", 0); }
    function stalkerBias(){ return num("br_bias", 0); }
    function today()      { return Time.now().value() / 86400; }

    // Highest floor the player may start on (unlocked by escaping).
    function unlockedDepth() {
        var d = escapes();
        if (d > 7) { d = 7; }
        return d;
    }

    // Fold one finished run into the lifetime record. Returns true when any
    // personal best moved, so the view can celebrate it.
    function recordRun(secs, depth, escaped, gotRelics, rooms) {
        var best = false;
        _set("br_runs", runs() + 1);
        if (secs > bestTime())  { _set("br_btime", secs); best = true; }
        if (depth > bestDepth()){ _set("br_bdepth", depth); best = true; }
        if (escaped)            { _set("br_escapes", escapes() + 1); }
        if (gotRelics > 0)      { _set("br_relics", relics() + gotRelics); }
        if (rooms > 0)          { _set("br_rooms", roomsSeen() + rooms); }
        // The Stalker starts a little closer every few runs.
        var b = runs() / 4;
        if (b > 5) { b = 5; }
        _set("br_bias", b);
        return best;
    }

    function dailyDone(day)      { return num("br_dday", -1) == day; }
    function dailyBest()         { return num("br_dbest", 0); }
    function recordDaily(day, secs) {
        if (num("br_dday", -1) != day) {
            _set("br_dday", day);
            _set("br_dbest", secs);
            return;
        }
        if (secs > dailyBest()) { _set("br_dbest", secs); }
    }

    function resetAll() {
        var keys = ["br_btime", "br_bdepth", "br_escapes", "br_relics",
                    "br_rooms", "br_runs", "br_bias", "br_dday", "br_dbest",
                    "br_lbday", "br_seenintro"];
        for (var i = 0; i < keys.size(); i++) {
            try { Application.Storage.deleteValue(keys[i]); } catch (e) {}
        }
        try { SaveResume.clear(Br.GAME_ID); } catch (e) {}
    }

    // ── Leaderboard (throttled to one batch per day) ─────────────────────────
    function submitLifetime() {
        var td = today();
        if (num("br_lbday", -1) == td) { return; }
        if (runs() <= 0) { return; }
        _set("br_lbday", td);
        try {
            var meta = {
                "depth"  => bestDepth(),
                "time"   => bestTime(),
                "esc"    => escapes(),
                "relics" => relics()
            };
            Leaderboard.submitScoreBatch(Br.GAME_ID, [
                { :score => bestDepth(), :variant => Br.LB_DEPTH,  :meta => meta },
                { :score => bestTime(),  :variant => Br.LB_TIME,   :meta => meta },
                { :score => escapes(),   :variant => Br.LB_ESCAPE, :meta => meta }
            ]);
        } catch (e) {}
    }

    // End-of-run submit: lifetime bests (already folded in by recordRun) plus
    // today's daily score when the run was a seeded one.
    function submitRun(daily, dailySecs) {
        try {
            var meta = {
                "depth"  => bestDepth(),
                "time"   => bestTime(),
                "esc"    => escapes(),
                "relics" => relics()
            };
            var entries = [
                { :score => bestTime(),  :variant => Br.LB_TIME,   :meta => meta },
                { :score => bestDepth(), :variant => Br.LB_DEPTH,  :meta => meta },
                { :score => escapes(),   :variant => Br.LB_ESCAPE, :meta => meta }
            ];
            if (daily) {
                entries.add({ :score => dailySecs, :variant => Br.LB_DAILY, :meta => meta });
            }
            Leaderboard.submitScoreBatch(Br.GAME_ID, entries);
            _set("br_lbday", today());
        } catch (e) {}
    }

    // ── Mid-run resume blob ──────────────────────────────────────────────────
    function buildResume(seed, level, px, py, ang, sanity, secs, key, relics2,
                         daily, torch) {
        return {
            "tr" => torch,
            "sd" => seed,
            "lv" => level,
            "px" => (px * 100).toNumber(),
            "py" => (py * 100).toNumber(),
            "an" => (ang * 1000).toNumber(),
            "sn" => sanity,
            "se" => secs,
            "ky" => key ? 1 : 0,
            "rl" => relics2,
            "dl" => daily ? 1 : 0
        };
    }
}
