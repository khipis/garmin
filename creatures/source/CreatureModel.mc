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
    var traits;       // [5] each 1..Cr.TRAIT_MAX
    var path;         // PATH_* evolution path (set at first evolution)
    var asc;          // ascensions completed (permanent legacy, survives rebirth)

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

    // ── Depth systems (paths / perks / relics / bond) ─────────────────────────
    var perk;         // Cr.PERK_* permanent ascension perk (survives rebirth)
    var relicMask;    // bitmask of found relics (0..RELIC_N)
    var bondWeek;     // week index of current bond contract
    var bondId;       // which contract (0..BOND_N-1)
    var bondProg;     // progress toward bond target
    var bondClaimed;  // Boolean

    // ── Daily challenge (per-day counters) ────────────────────────────────────
    var dailyDay;     // day index the current challenge belongs to
    var dFeed; var dTrain; var dExpl;
    var dailyClaimed; // Boolean — reward already granted today

    // ── Last idle summary (for WELCOME BACK) ─────────────────────────────────
    var gXp; var gFood; var gMut; var gSecs;
    var newDay;       // did a new calendar day begin on this open?
    var justEvolved;  // set when checkEvolution advances a stage (UI flash)

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
    // Numeric load: a corrupt or legacy non-Number value must never reach
    // _clamp (comparing a String to a Number throws) or an array index.
    hidden function _getNum(k, def) {
        var v = _get(k, def);
        if (!(v instanceof Lang.Number)) { return def; }
        return v;
    }
    hidden function _getBool(k, def) {
        var v = _get(k, def);
        if (v instanceof Lang.Boolean) { return v; }
        if (v instanceof Lang.Number)  { return v != 0; }
        return def;
    }

    hidden function _load() {
        seed      = _getNum("cr_seed", 0);
        hatched   = _getBool("cr_hatch", false);
        species   = _getNum("cr_spec", 0);
        path      = _getNum("cr_path", Cr.PATH_NONE);
        bornSec   = _getNum("cr_born", 0);
        lastSec   = _getNum("cr_last", 0);
        boostSec  = _getNum("cr_boost", 0);
        level     = _getNum("cr_lvl", 1);
        xp        = _getNum("cr_xp", 0);
        food      = _getNum("cr_food", 5);
        energy    = _getNum("cr_en", Cr.ENERGY_MAX);
        mood      = _getNum("cr_mood", 70);
        evo       = _getNum("cr_evo", Cr.EV_EGG);
        mutations = _getNum("cr_mut", 0);
        streak    = _getNum("cr_streak", 0);
        lastDay   = _getNum("cr_lday", 0);
        seenMask  = _getNum("cr_seen", 0);
        actions   = _getNum("cr_act", 0);
        trains    = _getNum("cr_train", 0);
        dailyDay  = _getNum("cr_dday", 0);
        dFeed     = _getNum("cr_dfeed", 0);
        dTrain    = _getNum("cr_dtrain", 0);
        dExpl     = _getNum("cr_dexpl", 0);
        dailyClaimed = _getBool("cr_dclaim", false);
        asc       = _getNum("cr_asc", 0);
        perk      = _getNum("cr_perk", 0);
        relicMask = _getNum("cr_relic", 0);
        bondWeek  = _getNum("cr_bweek", 0);
        bondId    = _getNum("cr_bid", 0);
        bondProg  = _getNum("cr_bprog", 0);
        bondClaimed = _getBool("cr_bclaim", false);

        traits = new [Cr.TR_N];
        for (var i = 0; i < Cr.TR_N; i++) {
            var tv = _getNum("cr_t" + i, 3);
            traits[i] = Cr._clamp(tv, 1, Cr.TRAIT_MAX);
        }
        // Defensive clamps so downstream math (xpNeeded, bars) and every table
        // lookup can never break, even on a corrupt or hand-edited save.
        if (level < 1) { level = 1; }
        if (level > 999) { level = 999; }
        if (xp < 0) { xp = 0; }
        if (food < 0) { food = 0; }
        if (bornSec < 0) { bornSec = 0; }
        if (lastSec < 0) { lastSec = 0; }
        if (boostSec < 0) { boostSec = 0; }
        if (mutations < 0) { mutations = 0; }
        if (streak < 0) { streak = 0; }
        if (lastDay < 0) { lastDay = 0; }
        if (dailyDay < 0) { dailyDay = 0; }
        if (dFeed < 0) { dFeed = 0; }
        if (dTrain < 0) { dTrain = 0; }
        if (dExpl < 0) { dExpl = 0; }
        if (actions < 0) { actions = 0; }
        if (trains < 0) { trains = 0; }
        if (asc < 0) { asc = 0; }
        if (asc > 9999) { asc = 9999; }
        if (seenMask < 0) { seenMask = 0; }
        if (relicMask < 0) { relicMask = 0; }
        if (bondWeek < 0) { bondWeek = 0; }
        if (bondProg < 0) { bondProg = 0; }
        species  = Cr._clamp(species, 0, Cr.SPECIES_N - 1);
        path     = Cr._clamp(path, Cr.PATH_NONE, Cr.PATH_ENERGY);
        perk     = Cr._clamp(perk, 0, Cr.PERK_N - 1);
        bondId   = Cr._clamp(bondId, 0, Cr.BOND_N - 1);
        energy = Cr._clamp(energy, 0, Cr.ENERGY_MAX);
        mood   = Cr._clamp(mood, 0, Cr.MOOD_MAX);
        evo    = Cr._clamp(evo, Cr.EV_EGG, Cr.EV_COSMIC);
        gXp = 0; gFood = 0; gMut = 0; gSecs = 0; newDay = false; justEvolved = false;
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
        _set("cr_asc", asc);
        _set("cr_perk", perk);
        _set("cr_relic", relicMask);
        _set("cr_bweek", bondWeek);
        _set("cr_bid", bondId);
        _set("cr_bprog", bondProg);
        _set("cr_bclaim", bondClaimed);
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
                    "cr_dfeed", "cr_dtrain", "cr_dexpl", "cr_dclaim", "cr_lbday",
                    "cr_asc", "cr_perk", "cr_relic", "cr_bweek", "cr_bid",
                    "cr_bprog", "cr_bclaim"];
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
    function hatchTargetSec() {
        var need = Cr.HATCH_SECONDS;
        if (perk == Cr.PERK_HATCH) { need = need * 2 / 3; }  // Swift Nest: ~4h
        return bornSec + need - boostSec;
    }
    function hatchRemaining() {
        var r = hatchTargetSec() - nowSec();
        return (r < 0) ? 0 : r;
    }
    function hatchPct() {
        var need = Cr.HATCH_SECONDS;
        if (perk == Cr.PERK_HATCH) { need = need * 2 / 3; }
        if (need < 1) { need = 1; }
        var done = nowSec() - bornSec + boostSec;
        var p = done * 100 / need;
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
        // Legacy: every ascension raises the FLOOR of the starting roll, so a
        // veteran's newborn is measurably better than a first-timer's.
        var lo = 2 + ascTraitBonus();
        for (var i = 0; i < Cr.TR_N; i++) {
            traits[i] = Cr._clamp(lo + (_hash(10 + i) % 8), 1, Cr.TRAIT_MAX);
        }
        if (perk == Cr.PERK_LUCK) {
            traits[Cr.TR_LCK] = Cr._clamp(traits[Cr.TR_LCK] + 2, 1, Cr.TRAIT_MAX);
        }
        // Activity-driven bias at birth.
        var dom = Sensors.dominantPath();
        if (dom != Cr.PATH_NONE) {
            var ti = Cr._clamp(Cr.pathTrait(dom), 0, Cr.TR_N - 1);
            traits[ti] = Cr._clamp(traits[ti] + 2, 1, Cr.TRAIT_MAX);
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
    function hasRelic(i) { return (relicMask & (1 << i)) != 0; }
    function relicCount() {
        var c = 0;
        for (var i = 0; i < Cr.RELIC_N; i++) { if (hasRelic(i)) { c++; } }
        return c;
    }
    hidden function _grantRelic(i) {
        i = Cr._clamp(i, 0, Cr.RELIC_N - 1);
        if (hasRelic(i)) { return false; }
        relicMask = relicMask | (1 << i);
        return true;
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
        _rollBondWeek();

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
        gXp   = elapsed * Cr.idleXpPerHour(level) / 3600;
        gFood = elapsed * 3 / 3600;
        if (newDay) { gXp += Sensors.getStepsToday() / 60; }   // once/day step bonus
        // Path + perk idle multipliers — Dreamer / Deep Dreams / Runner steps.
        if (path == Cr.PATH_DREAM) { gXp = gXp * 135 / 100; }
        if (perk == Cr.PERK_IDLE)  { gXp = gXp * 125 / 100; }
        if (path == Cr.PATH_RUNNER && newDay) {
            gXp += Sensors.getStepsToday() / 40;
        }

        // DNA mutation rolls (bounded, luck-weighted).
        var slots = elapsed / (5 * 3600);
        if (slots > 3) { slots = 3; }
        var chance = 28 + traits[Cr.TR_LCK] * 5;
        if (path == Cr.PATH_NONE) { chance += 8; }   // Wild: luckier DNA
        if (chance > 85) { chance = 85; }
        for (var i = 0; i < slots; i++) {
            if (_rand(100) < chance) { gMut += 1; }
        }

        // Apply.
        food += gFood;
        var enRegen = elapsed * 9 / 3600;
        if (path == Cr.PATH_DREAM) { enRegen = enRegen * 5 / 4; }
        energy = Cr._clamp(energy + enRegen, 0, Cr.ENERGY_MAX);
        if (gMut > 0) { _applyMutations(gMut); }
        _addXp(gXp);
        gXp = ascXpGain(gXp);

        // Mood drifts — neglect (empty energy) hurts; care recovers.
        var target = (energy > 25) ? 72 : 35;
        if (mood < target) { mood += 3; } else if (mood > target) { mood -= 3; }
        // Long absence without energy: sulk.
        if (elapsed > 8 * 3600 && energy < 30) { mood -= 8; }
        mood = Cr._clamp(mood, 0, Cr.MOOD_MAX);

        lastSec = now;
        checkEvolution();
        save();
    }

    hidden function _applyMutations(n) {
        var k = n;
        if (!(k instanceof Lang.Number) || k <= 0) { return; }
        if (k > 50) { k = 50; }          // bound the loop no matter the caller
        mutations += k;
        for (var i = 0; i < k; i++) {
            var t = Cr._clamp(_rand(Cr.TR_N), 0, Cr.TR_N - 1);
            traits[t] = Cr._clamp(traits[t] + 1, 1, Cr.TRAIT_MAX);
        }
    }

    // ── Ascension legacy multipliers ─────────────────────────────────────────
    // Bonuses stop scaling past ASC_BONUS_CAP so nothing can overflow or trivialise
    // the curve after dozens of rebirths.
    function ascBonus() { return Cr._clamp(asc, 0, Cr.ASC_BONUS_CAP); }
    function ascTraitBonus() { return Cr._clamp(asc, 0, Cr.ASC_TRAIT_CAP); }
    // Legacy: +15% XP per ascension. Also used to REPORT gains so the numbers on
    // screen match what was actually granted.
    function ascXpGain(n) {
        var b = ascBonus();
        if (b <= 0) { return n; }
        return n * (100 + Cr.ASC_XP_PCT * b) / 100;
    }

    // ── XP / level ────────────────────────────────────────────────────────────
    hidden function _addXp(n) {
        if (n <= 0) { return; }
        xp += ascXpGain(n);
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
    function feedCost() {
        var c = Cr.FEED_COST;
        if (path == Cr.PATH_ENERGY || perk == Cr.PERK_FEED) { c = 2; }
        if (c < 2) { c = 2; }
        return c;
    }
    function feed() {
        var cost = feedCost();
        if (food < cost) { return "No food. QUEST to find some."; }
        food -= cost;
        var en = 22;
        if (path == Cr.PATH_ENERGY) { en += 8; }
        if (perk == Cr.PERK_FEED)   { en += 6; }
        energy = Cr._clamp(energy + en, 0, Cr.ENERGY_MAX);
        mood   = Cr._clamp(mood + 12, 0, Cr.MOOD_MAX);
        _addXp(15);
        _bump(true); dFeed += 1;
        _bondBump(0);   // feed-type bond
        checkEvolution();
        save();
        return "Yum! +" + en + " energy  +15 XP";
    }

    function train(focus) {
        if (mood < Cr.MOOD_SULK) {
            return "Sulking. FEED to cheer it up.";
        }
        if (energy < Cr.TRAIN_ENERGY) { return "Too tired. FEED first."; }
        energy -= Cr.TRAIN_ENERGY;
        var xpGain = 35;
        if (path == Cr.PATH_WARRIOR) { xpGain = 50; }
        if (mood >= Cr.MOOD_HIGH) { xpGain = xpGain * 110 / 100; }
        _addXp(xpGain);
        // Training is effort — mild mood cost unless Warrior path.
        if (path == Cr.PATH_WARRIOR) { mood = Cr._clamp(mood + 3, 0, Cr.MOOD_MAX); }
        else { mood = Cr._clamp(mood - 2, 0, Cr.MOOD_MAX); }
        trains += 1; dTrain += 1;
        var ti = focus;
        if (!(ti instanceof Lang.Number) || ti < 0) {
            if (path != Cr.PATH_NONE) { ti = Cr.pathTrait(path); }
            else {
                var dom = Sensors.dominantPath();
                ti = (dom != Cr.PATH_NONE) ? Cr.pathTrait(dom) : _rand(Cr.TR_N);
            }
        }
        ti = Cr._clamp(ti, 0, Cr.TR_N - 1);
        var grow = 1;
        if (path == Cr.PATH_WARRIOR && _rand(100) < 35) { grow = 2; }
        traits[ti] = Cr._clamp(traits[ti] + grow, 1, Cr.TRAIT_MAX);
        _bump(true);
        _bondBump(1);
        checkEvolution();
        save();
        var gTxt = (grow > 1) ? " x2!" : "!";
        return "Trained " + Cr.traitName(ti) + gTxt + "  +" + xpGain + " XP";
    }

    // Legacy flat explore → Forest quest (keeps old callers working).
    function explore() { return quest(Cr.DEST_FOREST); }

    // Destination quest — the real explore depth.
    function quest(dest) {
        dest = Cr._clamp(dest, 0, Cr.DEST_N - 1);
        if (mood < Cr.MOOD_SULK && dest != Cr.DEST_NIGHT) {
            return "Won't go. FEED first.";
        }
        var cost = Cr.destEnergy(dest);
        if (path == Cr.PATH_RUNNER) { cost -= 3; }
        if (cost < 5) { cost = 5; }
        if (energy < cost) { return "Too tired. FEED first."; }
        energy -= cost;

        var low = mood < Cr.MOOD_LOW;
        var high = mood >= Cr.MOOD_HIGH;
        var luck = traits[Cr.TR_LCK];
        if (path == Cr.PATH_NONE) { luck += 2; }

        var msg = Cr.destName(dest) + ": ";
        var foundRelic = false;

        if (dest == Cr.DEST_FOREST) {
            var f = 3 + _rand(4 + luck / 2);
            if (low) { f = f * 7 / 10; }
            if (f < 1) { f = 1; }
            food += f;
            _addXp(low ? 14 : 22);
            msg += "+" + f + " food";
        } else if (dest == Cr.DEST_PEAK) {
            var px = high ? 40 : 28;
            if (path == Cr.PATH_WARRIOR) { px += 10; }
            if (low) { px = px * 7 / 10; }
            _addXp(px);
            var ti = Cr.pathTrait(path != Cr.PATH_NONE ? path : Cr.PATH_RUNNER);
            if (_rand(100) < (high ? 55 : 30)) {
                traits[ti] = Cr._clamp(traits[ti] + 1, 1, Cr.TRAIT_MAX);
                msg += Cr.traitAbbr(ti) + "+ +" + px + " XP";
            } else {
                msg += "+" + px + " XP";
            }
            mood = Cr._clamp(mood - 3, 0, Cr.MOOD_MAX);
        } else if (dest == Cr.DEST_RUINS) {
            _addXp(low ? 16 : 24);
            var find = 22 + luck * 4;
            if (high) { find += 15; }
            if (find > 90) { find = 90; }
            if (_rand(100) < find) {
                _applyMutations(1);
                msg += "+1 DNA";
            } else {
                msg += "dusty ruins";
            }
            // Relic chance — species-linked first, then random empty slot.
            var rChance = 12 + luck * 2 + (high ? 10 : 0);
            if (_rand(100) < rChance) {
                var ri = species;   // prefer matching element relic 0..4
                if (hasRelic(ri) || _rand(100) < 40) {
                    ri = _rand(Cr.RELIC_N);
                }
                // Dragon Scale only after Apex + 4 other relics.
                if (ri == 7 && (evo < Cr.EV_APEX || relicCount() < 4)) {
                    ri = _rand(7);
                }
                if (_grantRelic(ri)) {
                    foundRelic = true;
                    msg += " +" + Cr.relicName(ri) + "!";
                }
            }
            mood = Cr._clamp(mood - 2, 0, Cr.MOOD_MAX);
        } else { // DEST_NIGHT
            _addXp(high ? 30 : 20);
            mood = Cr._clamp(mood + 18, 0, Cr.MOOD_MAX);
            var nf = 18 + luck * 5;
            if (path == Cr.PATH_NONE) { nf += 12; }
            if (_rand(100) < nf) {
                _applyMutations(1);
                msg += "bond+ +1 DNA";
            } else {
                msg += "bond+ moonlit";
            }
            _bondBump(2);
        }

        dExpl += 1;
        _bump(true);
        _bondBump(3);   // any quest
        checkEvolution();
        save();
        if (foundRelic) { return msg; }
        return msg;
    }

    hidden function _bump(counts) {
        if (counts) { actions += 1; }
    }

    // True once the creature is Juvenile+ and still pathless — UI must offer pick.
    function needsPathPick() {
        return hatched && evo >= Cr.EV_JUV && path == Cr.PATH_NONE;
    }
    function suggestedPath() {
        var focus = _get("cr_focus", 0);
        if (focus == 1) { return Cr.PATH_RUNNER; }
        if (focus == 2) { return Cr.PATH_WARRIOR; }
        if (focus == 3) { return Cr.PATH_DREAM; }
        if (focus == 4) { return Cr.PATH_ENERGY; }
        var dom = Sensors.dominantPath();
        if (dom != Cr.PATH_NONE) { return dom; }
        return Cr.PATH_RUNNER + (_hash(3) % 4);
    }
    function pickPath(p) {
        if (!needsPathPick()) { return false; }
        path = Cr._clamp(p, Cr.PATH_RUNNER, Cr.PATH_ENERGY);
        // Instant path-trait bump so the choice feels real.
        var ti = Cr.pathTrait(path);
        traits[ti] = Cr._clamp(traits[ti] + 2, 1, Cr.TRAIT_MAX);
        save();
        return true;
    }

    // ── Evolution ─────────────────────────────────────────────────────────────
    // Advances stage based on days alive + level, straight off the Cr.evoDays /
    // Cr.evoLevel gate tables; locks a path at first evolve. Walking DOWN from the
    // last stage means a returning player who blew past several gates while away
    // lands on the highest one they've actually earned.
    function checkEvolution() {
        if (!hatched) { return false; }
        var d = daysAlive();
        var target = Cr.EV_HATCH;
        for (var s = Cr.EV_MAX; s > Cr.EV_HATCH; s--) {
            if (d >= Cr.evoDays(s) && level >= Cr.evoLevel(s)) { target = s; break; }
        }

        if (target > evo) {
            evo = target;
            justEvolved = true;
            // Path is NOT auto-locked — Juvenile+ triggers needsPathPick() so the
            // player chooses Runner/Warrior/Dreamer/Dynamo intentionally.
            return true;
        }
        return false;
    }

    // Kept for Options focus → soft suggestion only (no longer force-locks).
    hidden function _lockPath() {
        path = suggestedPath();
    }

    // The next stage the creature is working toward, or -1 at the final stage.
    function nextStage() { return (evo >= Cr.EV_MAX) ? -1 : evo + 1; }
    // Progress toward the NEXT stage, read from the same gate tables so the bar
    // is correct at every stage (and never divides by a zero gate).
    function evoProgressPct() {
        var ns = nextStage();
        if (ns < 0) { return 100; }
        var needD = Cr.evoDays(ns);
        var needL = Cr.evoLevel(ns);
        var pd = (needD <= 0) ? 100 : daysAlive() * 100 / needD;
        var pl = (needL <= 0) ? 100 : level * 100 / needL;
        var p = (pd < pl) ? pd : pl;
        return Cr._clamp(p, 0, 100);
    }

    // ── Ascension: rebirth into a new egg, keeping a permanent legacy ─────────
    // Unlocked at Apex. Rolls a brand new seed (so a new species / name / DNA)
    // and resets stats + level, but PRESERVES the ascension count (+1), the
    // species-seen mask, the lifetime trainer totals, the streak, and every
    // settings key. Nothing here deletes storage, so a failure mid-way leaves a
    // playable creature rather than a wiped save.
    function canAscend() { return hatched && evo >= Cr.EV_APEX; }

    // Rebirth. `newPerk` is the permanent perk chosen in the perk menu (0..PERK_N-1).
    function ascend() { return ascendWithPerk(perk); }

    function ascendWithPerk(newPerk) {
        if (!canAscend()) { return false; }
        var next = asc + 1;
        if (next > 9999) { next = 9999; }
        perk = Cr._clamp(newPerk, 0, Cr.PERK_N - 1);

        seed = 0;
        hatched = false;
        evo = Cr.EV_EGG;
        boostSec = 0;
        level = 1; xp = 0;
        mutations = 0;
        path = Cr.PATH_NONE;
        food = 5;
        energy = Cr.ENERGY_MAX;
        mood = 80;
        traits = new [Cr.TR_N];
        for (var i = 0; i < Cr.TR_N; i++) { traits[i] = 3; }
        asc = next;
        bornSec = 0;
        lastSec = nowSec();
        // Relics + seen mask + streak + trainer totals survive.
        ensureEgg();
        save();
        return true;
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
        return sum * 10 + traits[Cr.TR_LCK] * 15 + mutations * 18
             + evo * 60 + asc * Cr.ASC_RARITY + relicCount() * 35;
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
    // The reward scales gently with level so a daily still feels worth claiming
    // at level 90 — it stays a small fraction of a day's idle income, so it can
    // never short-circuit the long haul.
    function dailyXpReward() {
        var n = 80 + level * 6;
        if (n > 900) { n = 900; }
        return n;
    }
    function dailyRewardText() {
        if (perk == Cr.PERK_DAILY) {
            return "+" + ascXpGain(dailyXpReward()) + " XP +6 food +2 DNA";
        }
        return "+" + ascXpGain(dailyXpReward()) + " XP +6 food +1 DNA";
    }
    function claimDaily() {
        if (dailyClaimed || !dailyComplete()) { return false; }
        dailyClaimed = true;
        _addXp(dailyXpReward());
        food += 6;
        _applyMutations(1);
        if (perk == Cr.PERK_DAILY) { _applyMutations(1); }
        checkEvolution();
        save();
        return true;
    }

    // ── Weekly bond contract ──────────────────────────────────────────────────
    function weekIndex() { return nowSec() / (7 * 86400); }
    hidden function _rollBondWeek() {
        var w = weekIndex();
        if (bondWeek == w) { return; }
        bondWeek = w;
        bondId = (w + seed) % Cr.BOND_N;
        if (bondId < 0) { bondId = 0; }
        bondProg = 0;
        bondClaimed = false;
    }
    function bondText() {
        if (bondId == 0) { return "Feed 8 times"; }
        if (bondId == 1) { return "Train 6 times"; }
        if (bondId == 2) { return "Night quest x3"; }
        return "Any quest x10";
    }
    function bondTarget() {
        if (bondId == 0) { return 8; }
        if (bondId == 1) { return 6; }
        if (bondId == 2) { return 3; }
        return 10;
    }
    function bondComplete() { return bondProg >= bondTarget(); }
    // kind: 0=feed 1=train 2=night 3=any quest
    hidden function _bondBump(kind) {
        if (bondClaimed) { return; }
        if (bondId == 0 && kind == 0) { bondProg += 1; }
        else if (bondId == 1 && kind == 1) { bondProg += 1; }
        else if (bondId == 2 && kind == 2) { bondProg += 1; }
        else if (bondId == 3 && kind == 3) { bondProg += 1; }
    }
    function claimBond() {
        if (bondClaimed || !bondComplete()) { return false; }
        bondClaimed = true;
        _addXp(120 + level * 8);
        food += 10;
        _applyMutations(2);
        mood = Cr._clamp(mood + 15, 0, Cr.MOOD_MAX);
        // Guaranteed relic roll on bond claim.
        var ri = _rand(Cr.RELIC_N);
        if (ri == 7 && (evo < Cr.EV_APEX || relicCount() < 4)) { ri = _rand(7); }
        var extra = "";
        if (_grantRelic(ri)) { extra = " +" + Cr.relicName(ri); }
        checkEvolution();
        save();
        return true;
    }
    function bondRewardText() {
        return "+XP +10 food +2 DNA +relic?";
    }

    // ── Journal (derived from milestones) ────────────────────────────────────
    function journal() {
        var rows = [];
        rows.add([givenName(), displayName()]);
        rows.add(["Rarity", Cr.rarityName(rarityTier()) + " · " + rarityScore()]);
        if (path != Cr.PATH_NONE) {
            rows.add([Cr.pathName(path), Cr.pathPower(path)]);
        }
        if (asc > 0) {
            rows.add(["Perk", Cr.perkName(perk)]);
            rows.add(["Legacy", asc + " ascension(s)"]);
        }
        if (mutations > 0) { rows.add(["Mutations", mutations + " DNA shift(s)"]); }
        for (var s = Cr.EV_JUV; s <= Cr.EV_MAX; s++) {
            if (evo >= s) {
                rows.add(["Day " + Cr.evoDays(s) + "+", "Reached " + Cr.stageName(s)]);
            }
        }
        if (relicCount() > 0) {
            rows.add(["Relics", relicCount() + "/" + Cr.RELIC_N + " found"]);
        }
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
                "pa" => path, "mo" => mood, "sd" => seed,
                // Appended (never remove/rename the keys above): ascension count
                // so the site can badge veterans.
                "asc" => asc,
                "relics" => relicCount()
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
                traits[i] = Cr._clamp(traits[i] + 1, 1, Cr.TRAIT_MAX);
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
