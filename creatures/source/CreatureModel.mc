// ═══════════════════════════════════════════════════════════════════════════
// CreatureModel.mc — All BITOCHI CREATURES game state + logic.
//
// One class owns everything: procedural generation, save/load, offline (idle)
// progression, the daily challenge, streaks, actions (feed/train/explore),
// evolution and the four leaderboard scores. The view/delegate only read fields
// and call action methods; every Storage access is guarded so it can never
// throw into the UI.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Math;
using Toybox.System;

class CreatureModel {
    // ── Identity / generation ────────────────────────────────────────────────
    var seed;         // unique 31-bit DNA seed (set once at egg creation)
    var hatched;      // Boolean
    var species;      // 0..4
    var traits;       // [5] each 1..10
    var path;         // PATH_* evolution path (set at first evolution)

    // ── Life-cycle ───────────────────────────────────────────────────────────
    var bornSec;      // epoch sec of egg creation
    var lastSec;      // epoch sec of last collect (idle anchor)
    var boostSec;     // total seconds shaved off the hatch timer

    // ── Vitals / progression ─────────────────────────────────────────────────
    var level;
    var xp;
    var food;
    var energy;       // 0..100
    var mood;         // 0..100
    var evo;          // EV_* current evolution stage
    var mutations;    // DNA mutation count

    // ── Retention ─────────────────────────────────────────────────────────────
    var streak;       // consecutive-day streak
    var lastDay;      // day index of last visit
    var seenMask;     // bitmask of discovered species
    var actions;      // lifetime actions (trainer leaderboard)
    var trains;       // lifetime trainings

    // ── Daily challenge (per-day counters) ────────────────────────────────────
    var dailyDay;     // day index the current challenge belongs to
    var dFeed; var dTrain; var dExpl;
    var dailyClaimed; // Boolean — reward already granted today

    // ── Last idle summary (for WELCOME BACK) ─────────────────────────────────
    var gXp; var gFood; var gMut; var gSecs;
    var newDay;       // did a new calendar day begin on this open?

    function initialize() {
        _load();
    }

    // ── Storage ───────────────────────────────────────────────────────────────
    hidden function _get(k, def) {
        try {
            var v = Application.Storage.getValue(k);
            if (v != null) { return v; }
        } catch (e) {}
        return def;
    }
    hidden function _set(k, v) {
        try { Application.Storage.setValue(k, v); } catch (e) {}
    }

    hidden function _load() {
        seed      = _get("cr_seed", 0);
        hatched   = _get("cr_hatch", false);
        species   = _get("cr_spec", 0);
        path      = _get("cr_path", Cr.PATH_NONE);
        bornSec   = _get("cr_born", 0);
        lastSec   = _get("cr_last", 0);
        boostSec  = _get("cr_boost", 0);
        level     = _get("cr_lvl", 1);
        xp        = _get("cr_xp", 0);
        food      = _get("cr_food", 5);
        energy    = _get("cr_en", Cr.ENERGY_MAX);
        mood      = _get("cr_mood", 70);
        evo       = _get("cr_evo", Cr.EV_EGG);
        mutations = _get("cr_mut", 0);
        streak    = _get("cr_streak", 0);
        lastDay   = _get("cr_lday", 0);
        seenMask  = _get("cr_seen", 0);
        actions   = _get("cr_act", 0);
        trains    = _get("cr_train", 0);
        dailyDay  = _get("cr_dday", 0);
        dFeed     = _get("cr_dfeed", 0);
        dTrain    = _get("cr_dtrain", 0);
        dExpl     = _get("cr_dexpl", 0);
        dailyClaimed = _get("cr_dclaim", false);

        traits = new [Cr.TR_N];
        for (var i = 0; i < Cr.TR_N; i++) {
            var tv = _get("cr_t" + i, 3);
            traits[i] = Cr._clamp((tv instanceof Lang.Number) ? tv : 3, 1, 10);
        }
        // Defensive clamps so downstream math (xpNeeded, bars) can never break.
        if (!(level instanceof Lang.Number) || level < 1) { level = 1; }
        if (!(xp instanceof Lang.Number) || xp < 0) { xp = 0; }
        if (!(food instanceof Lang.Number) || food < 0) { food = 0; }
        energy = Cr._clamp(energy, 0, Cr.ENERGY_MAX);
        mood   = Cr._clamp(mood, 0, Cr.MOOD_MAX);
        evo    = Cr._clamp(evo, Cr.EV_EGG, Cr.EV_APEX);
        gXp = 0; gFood = 0; gMut = 0; gSecs = 0; newDay = false;
    }

    function save() {
        _set("cr_seed", seed);
        _set("cr_hatch", hatched);
        _set("cr_spec", species);
        _set("cr_path", path);
        _set("cr_born", bornSec);
        _set("cr_last", lastSec);
        _set("cr_boost", boostSec);
        _set("cr_lvl", level);
        _set("cr_xp", xp);
        _set("cr_food", food);
        _set("cr_en", energy);
        _set("cr_mood", mood);
        _set("cr_evo", evo);
        _set("cr_mut", mutations);
        _set("cr_streak", streak);
        _set("cr_lday", lastDay);
        _set("cr_seen", seenMask);
        _set("cr_act", actions);
        _set("cr_train", trains);
        _set("cr_dday", dailyDay);
        _set("cr_dfeed", dFeed);
        _set("cr_dtrain", dTrain);
        _set("cr_dexpl", dExpl);
        _set("cr_dclaim", dailyClaimed);
        for (var i = 0; i < Cr.TR_N; i++) { _set("cr_t" + i, traits[i]); }
    }

    // ── Full reset (OPTIONS → Reset creature) ────────────────────────────────
    // Wipes every progress key back to zero, keeping the player's settings
    // (training focus, sound/haptics, demo mode, intro-seen). Fully guarded.
    function resetAll() {
        var keys = ["cr_seed", "cr_hatch", "cr_spec", "cr_path", "cr_born",
                    "cr_last", "cr_boost", "cr_lvl", "cr_xp", "cr_food",
                    "cr_en", "cr_mood", "cr_evo", "cr_mut", "cr_streak",
                    "cr_lday", "cr_seen", "cr_act", "cr_train", "cr_dday",
                    "cr_dfeed", "cr_dtrain", "cr_dexpl", "cr_dclaim", "cr_lbday"];
        for (var i = 0; i < keys.size(); i++) {
            try { Application.Storage.deleteValue(keys[i]); } catch (e) {}
        }
        for (var t = 0; t < Cr.TR_N; t++) {
            try { Application.Storage.deleteValue("cr_t" + t); } catch (e) {}
        }
        _load();
    }

    // ── Time helpers ──────────────────────────────────────────────────────────
    function nowSec() { return Time.now().value(); }
    function today()  { return nowSec() / 86400; }

    // ── RNG (deterministic hash off the DNA seed) ─────────────────────────────
    hidden function _hash(salt) {
        var x = (seed ^ (salt * 1597334677)) & 0x7FFFFFFF;
        x = (x ^ (x >> 13)) & 0x7FFFFFFF;
        x = (x * 1103515245 + 12345) & 0x7FFFFFFF;
        x = (x ^ (x >> 16)) & 0x7FFFFFFF;
        return x;
    }
    // Live random 0..(n-1) (non-deterministic — for offline rolls/mutations).
    hidden function _rand(n) {
        if (n <= 1) { return 0; }
        return (Math.rand() & 0x7FFFFFFF) % n;
    }

    // ── First run: create the mysterious egg ─────────────────────────────────
    function ensureEgg() {
        if (seed != 0) { return; }
        var t = nowSec();
        var s = (t ^ (System.getTimer() * 1597334677)
                   ^ (Sensors.getStepsToday() * 40503)
                   ^ (Sensors.getHeartRate() * 131071)) & 0x7FFFFFFF;
        if (s == 0) { s = 12345; }
        seed = s;
        hatched = false;
        evo = Cr.EV_EGG;
        bornSec = t;
        lastSec = t;
        boostSec = 0;
        lastDay = today();
        dailyDay = today();
        save();
    }

    // ── Egg phase ─────────────────────────────────────────────────────────────
    function hatchTargetSec() { return bornSec + Cr.HATCH_SECONDS - boostSec; }
    function hatchRemaining() {
        var r = hatchTargetSec() - nowSec();
        return (r < 0) ? 0 : r;
    }
    function hatchPct() {
        var done = nowSec() - bornSec + boostSec;
        var p = done * 100 / Cr.HATCH_SECONDS;
        return Cr._clamp(p, 0, 100);
    }
    // BOOST action while an egg: shave time off (encourages a second look today).
    function boost() {
        if (hatched) { return; }
        boostSec += Cr.BOOST_SECONDS;
        // a little movement helps too
        var steps = Sensors.getStepsToday();
        if (steps > 0) { boostSec += steps / 20; }
        maybeHatch();
        save();
    }
    function maybeHatch() {
        if (hatched) { return false; }
        if (nowSec() < hatchTargetSec()) { return false; }
        _hatch();
        return true;
    }

    // Generate the creature deterministically from the DNA seed, nudged by the
    // player's current Garmin activity so it feels personal.
    hidden function _hatch() {
        species = _hash(1) % Cr.SPECIES_N;
        traits = new [Cr.TR_N];
        for (var i = 0; i < Cr.TR_N; i++) {
            traits[i] = 2 + (_hash(10 + i) % 8);   // 2..9
        }
        // Activity-driven bias at birth.
        var dom = Sensors.dominantPath();
        if (dom != Cr.PATH_NONE) {
            var ti = Cr.pathTrait(dom);
            traits[ti] = Cr._clamp(traits[ti] + 2, 1, 10);
        }
        path = Cr.PATH_NONE;
        hatched = true;
        evo = Cr.EV_HATCH;
        level = 1; xp = 0;
        energy = Cr.ENERGY_MAX; mood = 80;
        food = food + 3;
        _markSeen(species);
        save();
    }

    hidden function _markSeen(sp) {
        seenMask = seenMask | (1 << sp);
    }
    function isSeen(sp) { return (seenMask & (1 << sp)) != 0; }
    function seenCount() {
        var c = 0;
        for (var i = 0; i < Cr.SPECIES_N; i++) { if (isSeen(i)) { c++; } }
        return c;
    }

    // ── Offline / idle progression + daily rollover ──────────────────────────
    // Call once when the game view opens. Fills g* summary fields.
    function collectOffline() {
        var now = nowSec();
        gXp = 0; gFood = 0; gMut = 0; gSecs = 0; newDay = false;

        // Daily rollover (streak + challenge reset) — runs for egg and creature.
        var td = today();
        if (td != lastDay) {
            newDay = true;
            if (lastDay != 0 && td == lastDay + 1) { streak += 1; }
            else if (lastDay == 0) { streak = 1; }
            else { streak = 1; }
            lastDay = td;
        }
        if (streak < 1) { streak = 1; }
        if (dailyDay != td) {
            dailyDay = td;
            dFeed = 0; dTrain = 0; dExpl = 0; dailyClaimed = false;
        }

        if (!hatched) {
            lastSec = now;
            save();
            return;
        }

        var elapsed = now - lastSec;
        if (elapsed < 0) { elapsed = 0; }
        if (elapsed > Cr.OFFLINE_CAP) { elapsed = Cr.OFFLINE_CAP; }
        gSecs = elapsed;

        // XP + food scale with time and level; energy slowly refills.
        gXp   = elapsed * (5 + level) / 3600;
        gFood = elapsed * 3 / 3600;
        if (newDay) { gXp += Sensors.getStepsToday() / 60; }   // once/day step bonus

        // DNA mutation rolls (bounded, luck-weighted).
        var slots = elapsed / (5 * 3600);
        if (slots > 3) { slots = 3; }
        var chance = 28 + traits[Cr.TR_LCK] * 5;   // %
        for (var i = 0; i < slots; i++) {
            if (_rand(100) < chance) { gMut += 1; }
        }

        // Apply.
        food += gFood;
        energy = Cr._clamp(energy + elapsed * 9 / 3600, 0, Cr.ENERGY_MAX);
        if (gMut > 0) { _applyMutations(gMut); }
        _addXp(gXp);

        // Mood drifts toward contentment, dented by empty energy.
        var target = (energy > 25) ? 72 : 40;
        if (mood < target) { mood += 4; } else if (mood > target) { mood -= 2; }
        mood = Cr._clamp(mood, 0, Cr.MOOD_MAX);

        lastSec = now;
        checkEvolution();
        save();
    }

    hidden function _applyMutations(n) {
        mutations += n;
        for (var i = 0; i < n; i++) {
            var t = _rand(Cr.TR_N);
            traits[t] = Cr._clamp(traits[t] + 1, 1, 10);
        }
    }

    // ── XP / level ────────────────────────────────────────────────────────────
    hidden function _addXp(n) {
        if (n <= 0) { return; }
        xp += n;
        // Guard the level loop against a zero/negative requirement (never freeze).
        var guard = 0;
        while (xp >= Cr.xpForLevel(level)) {
            var need = Cr.xpForLevel(level);
            if (need <= 0) { break; }
            xp -= need;
            level += 1;
            guard += 1;
            if (level >= 999 || guard > 5000) { break; }
        }
    }
    function xpNeeded() {
        var n = Cr.xpForLevel(level);
        return (n < 1) ? 1 : n;
    }

    // ── Actions ───────────────────────────────────────────────────────────────
    // Each returns a short result string for the on-screen popup.
    function feed() {
        if (food < Cr.FEED_COST) { return "No food. EXPLORE to find some."; }
        food -= Cr.FEED_COST;
        energy = Cr._clamp(energy + 22, 0, Cr.ENERGY_MAX);
        mood   = Cr._clamp(mood + 10, 0, Cr.MOOD_MAX);
        _addXp(15);
        _bump(true); dFeed += 1;
        checkEvolution();
        save();
        return "Yum! +22 energy  +15 XP";
    }

    function train(focus) {
        if (energy < Cr.TRAIN_ENERGY) { return "Too tired. FEED first."; }
        energy -= Cr.TRAIN_ENERGY;
        _addXp(35);
        mood = Cr._clamp(mood + 4, 0, Cr.MOOD_MAX);
        trains += 1; dTrain += 1;
        // Grow the focused trait (or a live-activity-driven one on AUTO).
        var ti = focus;
        if (ti < 0) {
            var dom = Sensors.dominantPath();
            ti = (dom != Cr.PATH_NONE) ? Cr.pathTrait(dom) : _rand(Cr.TR_N);
        }
        traits[ti] = Cr._clamp(traits[ti] + 1, 1, 10);
        _bump(true);
        checkEvolution();
        save();
        return "Trained " + Cr.traitName(ti) + "!  +35 XP";
    }

    function explore() {
        if (energy < Cr.EXPLORE_ENERGY) { return "Too tired. FEED first."; }
        energy -= Cr.EXPLORE_ENERGY;
        var f = 2 + _rand(4 + traits[Cr.TR_LCK] / 2);
        food += f;
        _addXp(20);
        dExpl += 1;
        var extra = "";
        // Lucky DNA fragment find.
        if (_rand(100) < 15 + traits[Cr.TR_LCK] * 4) {
            _applyMutations(1);
            extra = "  +1 DNA!";
        }
        _bump(true);
        checkEvolution();
        save();
        return "Found +" + f + " food" + extra;
    }

    hidden function _bump(counts) {
        if (counts) { actions += 1; }
    }

    // ── Evolution ─────────────────────────────────────────────────────────────
    // Advances stage based on days alive + level; locks a path at first evolve.
    function checkEvolution() {
        if (!hatched) { return false; }
        var d = daysAlive();
        var target = Cr.EV_HATCH;
        if (d >= 30 && level >= 25) { target = Cr.EV_APEX; }
        else if (d >= 7 && level >= 12) { target = Cr.EV_ADULT; }
        else if (d >= 1 && level >= 5) { target = Cr.EV_JUV; }

        if (target > evo) {
            evo = target;
            if (path == Cr.PATH_NONE) { _lockPath(); }
            return true;
        }
        return false;
    }

    hidden function _lockPath() {
        // Player's Options focus wins; otherwise live Garmin activity decides.
        var focus = _get("cr_focus", 0);   // 0=AUTO,1=SPEED,2=STR,3=MIND,4=NRG
        if (focus == 1) { path = Cr.PATH_RUNNER; return; }
        if (focus == 2) { path = Cr.PATH_WARRIOR; return; }
        if (focus == 3) { path = Cr.PATH_DREAM; return; }
        if (focus == 4) { path = Cr.PATH_ENERGY; return; }
        var dom = Sensors.dominantPath();
        path = (dom != Cr.PATH_NONE) ? dom : (Cr.PATH_RUNNER + (_hash(3) % 4));
    }

    // The next stage the creature is working toward, or -1 at apex.
    function nextStage() { return (evo >= Cr.EV_APEX) ? -1 : evo + 1; }
    function evoProgressPct() {
        if (evo >= Cr.EV_APEX) { return 100; }
        var d = daysAlive();
        var needD; var needL;
        if (evo == Cr.EV_HATCH) { needD = 1;  needL = 5;  }
        else if (evo == Cr.EV_JUV) { needD = 7;  needL = 12; }
        else { needD = 30; needL = 25; }
        var pd = (needD == 0) ? 100 : d * 100 / needD;
        var pl = level * 100 / needL;
        var p = (pd < pl) ? pd : pl;
        return Cr._clamp(p, 0, 100);
    }

    // ── Derived / display ─────────────────────────────────────────────────────
    function daysAlive() {
        if (bornSec == 0) { return 0; }
        var d = (nowSec() - bornSec) / 86400;
        return (d < 0) ? 0 : d;
    }
    function ageDayLabel() { return "Day " + (daysAlive() + 1); }

    function dominantTrait() {
        var bi = 0; var bv = -1;
        for (var i = 0; i < Cr.TR_N; i++) {
            if (traits[i] > bv) { bv = traits[i]; bi = i; }
        }
        return bi;
    }

    function rarityScore() {
        var sum = 0;
        for (var i = 0; i < Cr.TR_N; i++) { sum += traits[i]; }
        return sum * 10 + traits[Cr.TR_LCK] * 15 + mutations * 18 + evo * 45;
    }
    function rarityTier() {
        var s = rarityScore();
        if (s >= 560) { return Cr.RA_MYTHIC; }
        if (s >= 440) { return Cr.RA_LEGEND; }
        if (s >= 330) { return Cr.RA_EPIC; }
        if (s >= 220) { return Cr.RA_RARE; }
        return Cr.RA_COMMON;
    }

    // Unique given name from the DNA seed (syllable stitching + serial number).
    function givenName() {
        var a = ["Zy", "Ka", "Vor", "Lu", "Ny", "Rha", "Ta", "Bo", "Ix", "Su"];
        var b = ["x", "ra", "mi", "on", "el", "ka", "us", "ith", "ar", "oo"];
        var i1 = _hash(21) % a.size();
        var i2 = _hash(22) % b.size();
        return a[i1] + b[i2];
    }
    // Full display name: [title] Species [pathSuffix]
    function displayName() {
        var s = "";
        var t = Cr.stageTitle(evo);
        if (t.length() > 0) { s = t + " "; }
        s += Cr.speciesName(species);
        if (evo >= Cr.EV_JUV && path != Cr.PATH_NONE) {
            s += " " + Cr.pathName(path);
        }
        return s;
    }

    // ── Daily challenge ───────────────────────────────────────────────────────
    function dailyId() { return dailyDay % 5; }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Walk 5000 steps"; }
        if (id == 1) { return "Train twice"; }
        if (id == 2) { return "Feed your creature 3x"; }
        if (id == 3) { return "Explore twice"; }
        return "Come back tomorrow";
    }
    function dailyTarget() {
        var id = dailyId();
        if (id == 0) { return 5000; }
        if (id == 1) { return 2; }
        if (id == 2) { return 3; }
        if (id == 3) { return 2; }
        return 1;
    }
    function dailyProgress() {
        var id = dailyId();
        if (id == 0) { var s = Sensors.getStepsToday(); return (s > 5000) ? 5000 : s; }
        if (id == 1) { return dTrain; }
        if (id == 2) { return dFeed; }
        if (id == 3) { return dExpl; }
        return streak >= 1 ? 1 : 0;   // "come back" completes just by returning
    }
    function dailyComplete() { return dailyProgress() >= dailyTarget(); }
    function dailyRewardText() { return "+80 XP  +6 food  +1 DNA"; }
    // Grant the daily reward once. Returns true if granted now.
    function claimDaily() {
        if (dailyClaimed || !dailyComplete()) { return false; }
        dailyClaimed = true;
        _addXp(80);
        food += 6;
        _applyMutations(1);
        checkEvolution();
        save();
        return true;
    }

    // ── Journal (derived from milestones) ────────────────────────────────────
    // Returns an Array of [dayLabel, text] rows.
    function journal() {
        var rows = [];
        rows.add(["Day 1", "Hatched from egg #" + (seed % 100000)]);
        if (mutations > 0) { rows.add(["Mutations", mutations + " DNA shift(s)"]); }
        if (evo >= Cr.EV_JUV) { rows.add(["Day 1+", "Evolved to " + Cr.stageName(Cr.EV_JUV)]); }
        if (evo >= Cr.EV_ADULT) { rows.add(["Day 7+", "Grew into an " + Cr.stageName(Cr.EV_ADULT)]); }
        if (evo >= Cr.EV_APEX) { rows.add(["Day 30+", "Reached " + Cr.stageName(Cr.EV_APEX) + " form"]); }
        if (streak >= 7) { rows.add(["Streak", streak + "-day bond"]); }
        return rows;
    }

    // ── Leaderboard ───────────────────────────────────────────────────────────
    // Submit all four categories, throttled to once per calendar day so the
    // boards stay clean (backend only INSERTs). Rarity carries a rich meta blob.
    function submitScores() {
        var td = today();
        var lb = _get("cr_lbday", 0);
        if (lb == td) { return; }
        if (!hatched) { return; }
        _set("cr_lbday", td);
        // Serial batch: one request at a time (see submitScoreBatch — Garmin
        // allows only one in-flight makeWebRequest; concurrent posts dropped
        // boards and crashed the app on some firmware).
        try {
            // Human-readable fields (species/rarity/name/level/path) drive the
            // web caption; the compact numeric fields (sp/ev/rt/pa/mo/sd) let
            // bitochi.com redraw the EXACT creature avatar the player sees on the
            // wrist. Attached to every board so the avatar shows on all of them.
            var meta = {
                "species" => Cr.speciesName(species),
                "rarity"  => Cr.rarityName(rarityTier()),
                "name"    => givenName(),
                "level"   => level,
                "path"    => Cr.pathName(path),
                "sp" => species, "ev" => evo, "rt" => rarityTier(),
                "pa" => path, "mo" => mood, "sd" => seed
            };
            Leaderboard.submitScoreBatch(Cr.GAME_ID, [
                { :score => rarityScore(),   :variant => Cr.LB_RARITY,  :meta => meta },
                { :score => daysAlive() + 1, :variant => Cr.LB_AGE,     :meta => meta },
                { :score => evo * 1000 + level, :variant => Cr.LB_EVO,  :meta => meta },
                { :score => actions,         :variant => Cr.LB_TRAINER, :meta => meta }
            ]);
        } catch (e) {}
    }

    // ── DEMO fast-track ───────────────────────────────────────────────────────
    // Called repeatedly (~1/sec) by the view when DEMO mode is on. Rapidly walks
    // a creature egg -> hatch -> adult -> apex/rare, then spawns a fresh egg so
    // the showcase loop repeats. Fully guarded: it must NEVER throw or freeze.
    function demoStep() {
        try {
            if (!hatched) {
                // Accelerate incubation so the egg visibly cracks then hatches.
                boostSec += Cr.HATCH_SECONDS / 3;
                if (nowSec() >= hatchTargetSec()) {
                    _hatch();
                    return "Hatched!";
                }
                save();
                return "Incubating " + hatchPct() + "%";
            }

            // Keep vitals maxed so nothing is ever "too tired" / "no food".
            food = food + 12;
            energy = Cr.ENERGY_MAX;
            mood = Cr._clamp(mood + 25, 0, Cr.MOOD_MAX);

            // Pump traits + DNA for a high rarity tier.
            for (var i = 0; i < Cr.TR_N; i++) {
                traits[i] = Cr._clamp(traits[i] + 1, 1, 10);
            }
            _applyMutations(1);
            actions += 3; trains += 1;
            dFeed += 1; dTrain += 1; dExpl += 1;

            // Level + age fast enough to satisfy evolution gates in ~10 steps.
            _addXp(4000);
            if (bornSec > 0) { bornSec -= 6 * 86400; }

            var before = evo;
            checkEvolution();

            // Fully evolved + rare -> restart the loop with a brand new egg.
            if (evo >= Cr.EV_APEX && rarityTier() >= Cr.RA_LEGEND) {
                var sp = Cr.speciesName(species);
                demoNewEgg();
                return "Apex " + sp + "! New egg";
            }

            save();
            if (evo > before) { return "Evolved: " + Cr.stageName(evo); }
            return "Growing... Lv " + level;
        } catch (e) {
            return null;
        }
    }

    // Reset to a fresh egg (keeps streak + discovery history) for the demo loop.
    function demoNewEgg() {
        try {
            seed = 0;
            hatched = false;
            boostSec = 0;
            evo = Cr.EV_EGG;
            level = 1;
            xp = 0;
            mutations = 0;
            path = Cr.PATH_NONE;
            energy = Cr.ENERGY_MAX;
            mood = 80;
            traits = new [Cr.TR_N];
            for (var i = 0; i < Cr.TR_N; i++) { traits[i] = 3; }
            ensureEgg();
        } catch (e) {}
    }
}
