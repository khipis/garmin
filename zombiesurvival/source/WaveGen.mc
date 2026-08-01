// ═══════════════════════════════════════════════════════════════════════════
// WaveGen.mc — Deterministic wave director.
//
// build(wave, seed) returns a flat spawn schedule the engine walks through:
//   sched = [tick, type, lane, tick, type, lane, ...]  (sorted by tick)
// A flat Number array keeps the allocation cost of a 50-zombie night at one
// object instead of fifty, which matters on the 64 kB watches.
//
// The seed is derived from the night number alone (see `seedFor`), never from
// the clock. The preview screen shows the player exactly what is coming hours
// before it arrives, and a night that is lost has to come back unchanged the
// following evening — both need the same schedule to fall out of the same
// night number every time it is asked for.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

module WaveGen {

    function _next(s) { return (s * 1103515245 + 12345) & 0x7FFFFFFF; }

    // Stable per-night seed.
    function seedFor(night) {
        var n = night < 1 ? 1 : night;
        return (n * 40503 + 1013904223) & 0x7FFFFFFF;
    }

    // Everything about tonight, from the night number alone.
    function forNight(night) {
        return build(night, seedFor(night));
    }

    // Nightly modifier: nights 1-2 are always clear so the loop can be learnt.
    function modFor(wave, seed) {
        if (wave < 3) { return Zs.MOD_NONE; }
        var s = _next(seed + wave * 7919);
        var roll = s % 100;
        if (roll < 44) { return Zs.MOD_NONE; }
        if (roll < 58) { return Zs.MOD_FOG; }
        if (roll < 72) { return Zs.MOD_RAGE; }
        if (roll < 88) { return Zs.MOD_HORDE; }
        return Zs.MOD_BLOOD;
    }

    function isBossWave(wave) {
        return wave > 0 && (wave % Zs.BOSS_EVERY) == 0;
    }

    // Weighted type pick for a given wave.
    function _pickType(wave, roll) {
        if (wave <= 1) { return Zs.Z_WALKER; }
        var r = roll % 100;
        if (wave < 3) {
            return (r < 76) ? Zs.Z_WALKER : Zs.Z_RUNNER;
        }
        if (wave < 5) {
            if (r < 54) { return Zs.Z_WALKER; }
            if (r < 78) { return Zs.Z_RUNNER; }
            return Zs.Z_CRAWLER;
        }
        if (wave < 8) {
            if (r < 40) { return Zs.Z_WALKER; }
            if (r < 62) { return Zs.Z_RUNNER; }
            if (r < 76) { return Zs.Z_CRAWLER; }
            if (r < 92) { return Zs.Z_BRUTE; }
            return Zs.Z_SPITTER;
        }
        if (wave < 13) {
            if (r < 30) { return Zs.Z_WALKER; }
            if (r < 52) { return Zs.Z_RUNNER; }
            if (r < 64) { return Zs.Z_CRAWLER; }
            if (r < 80) { return Zs.Z_BRUTE; }
            if (r < 92) { return Zs.Z_SPITTER; }
            return Zs.Z_SCREAMER;
        }
        if (r < 20) { return Zs.Z_WALKER; }
        if (r < 44) { return Zs.Z_RUNNER; }
        if (r < 54) { return Zs.Z_CRAWLER; }
        if (r < 74) { return Zs.Z_BRUTE; }
        if (r < 88) { return Zs.Z_SPITTER; }
        return Zs.Z_SCREAMER;
    }

    // Body count plateaus deliberately. Only sixteen of the dead can be on
    // the street at once and the player has to be able to sit through the
    // replay, so a night that never ends is worse than a night that is merely
    // hard. Past the cap the pressure comes from HP, not from more bodies.
    function count(wave, mod) {
        var n = 6 + wave * 2 + wave * wave / 10;
        if (mod == Zs.MOD_HORDE) { n = n * 15 / 10; }
        if (n > 64) { n = 64; }
        return n;
    }

    // ...which makes this the real difficulty curve, and it never flattens.
    // A base that has bought everything still meets a wave it cannot quite
    // kill eventually, and that night becomes its high-water mark.
    function hpPct(wave, mod) {
        var p = 100 + (wave - 1) * 14 + wave * wave / 6;
        if (mod == Zs.MOD_BLOOD) { p = p * 125 / 100; }
        if (mod == Zs.MOD_HORDE) { p = p * 80 / 100; }
        if (p > 6000) { p = 6000; }
        return p;
    }

    function speedPct(wave, mod) {
        var p = 100 + (wave - 1) * 3;
        if (mod == Zs.MOD_RAGE) { p += 30; }
        if (p > 210) { p = 210; }
        return p;
    }

    // Flat [tick, type, lane] schedule.
    function build(wave, seed) as Lang.Dictionary {
        var w = wave < 1 ? 1 : wave;
        var mod = modFor(w, seed);
        var n = count(w, mod);
        var s = (seed + w * 10007 + 4242) & 0x7FFFFFFF;

        var gap = 30 - w;
        if (gap < 9) { gap = 9; }
        if (mod == Zs.MOD_HORDE) { gap = gap * 7 / 10; }
        if (gap < 6) { gap = 6; }

        var sched = new [n * 3];
        var t = 14;
        var lane = 0;
        for (var i = 0; i < n; i++) {
            s = _next(s);
            var type = _pickType(w, s / 7);
            s = _next(s);
            // Lanes rotate with a nudge so pressure never sits in one place.
            lane = (lane + 1 + (s % 3)) % Zs.LANES;
            sched[i * 3]     = t;
            sched[i * 3 + 1] = type;
            sched[i * 3 + 2] = lane;

            s = _next(s);
            var step = gap * (70 + (s % 70)) / 100;
            // Every few spawns a tight burst arrives together.
            if ((i % 7) == 6) { step = step / 3; }
            if (step < 3) { step = 3; }
            t += step;
        }

        var bossHp = 0;
        if (isBossWave(w)) {
            bossHp = Zs.zHp(Zs.Z_BOSS) * (100 + (w - Zs.BOSS_EVERY) * 34) / 100;
        }

        return {
            "wave"  => w,
            "mod"   => mod,
            "count" => n,
            "sched" => sched,
            "hpPct" => hpPct(w, mod),
            "spPct" => speedPct(w, mod),
            "boss"  => isBossWave(w),
            "bossHp"=> bossHp,
            "last"  => t
        };
    }

    function summary(wv) as Lang.String {
        if (wv == null) { return ""; }
        var n = wv["count"];
        var s = n.format("%d") + " DEAD";
        if (wv["boss"]) { s = s + " + ABOMINATION"; }
        return s;
    }
}
