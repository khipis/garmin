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
    var dFeed; var dTrain; var dExpl; var dArena;
    var dailyClaimed; // Boolean — reward already granted today

    // ── Arena (TRAIN → EVOLVE → EQUIP → BATTLE → RANK UP) ─────────────────────
    var arenaPts;      // rank ladder points
    var arenaWins;     // lifetime arena wins (also gates equipment)
    var arenaLosses;   // lifetime arena losses
    var arenaStreak;   // current win streak (resets on any loss)
    var strategy;      // Cr.ST_* battle stance
    var eqWeapon;      // equipped Cr.EQ_* id, slot 0, or -1
    var eqArmor;       // equipped Cr.EQ_* id, slot 1, or -1
    var eqArt;         // equipped Cr.EQ_* id, slot 2, or -1
    var evoPts;        // evolution points earned from training/battling
    var warLog;        // Array<String>, most-recent-first, capped at 8
    var defLog;        // Array of [dayIndex, held01, attackerName], newest first
    hidden var _lastFight;   // last fight() result Dictionary, for the view
    hidden var _roster;      // cached rival records, lazily read from Storage

    // ── Last defence summary (for WELCOME BACK) ──────────────────────────────
    var defHits; var defHeld; var defPts;
    var mailAlert;             // real inbox fights arrived this session (UI flag)
    hidden var _mailPending;   // waiting on /inbox (phone was up at collect)
    hidden var _mailElapsed;   // elapsed secs for offline RNG if inbox fails

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
        dArena    = _getNum("cr_darena", 0);
        dailyClaimed = _getBool("cr_dclaim", false);
        asc       = _getNum("cr_asc", 0);
        perk      = _getNum("cr_perk", 0);
        relicMask = _getNum("cr_relic", 0);
        bondWeek  = _getNum("cr_bweek", 0);
        bondId    = _getNum("cr_bid", 0);
        bondProg  = _getNum("cr_bprog", 0);
        bondClaimed = _getBool("cr_bclaim", false);

        arenaPts    = _getNum("cr_apts", 0);
        arenaWins   = _getNum("cr_awins", 0);
        arenaLosses = _getNum("cr_aloss", 0);
        arenaStreak = _getNum("cr_astreak", 0);
        strategy    = _getNum("cr_strat", Cr.ST_BAL);
        eqWeapon    = _getNum("cr_eq0", -1);
        eqArmor     = _getNum("cr_eq1", -1);
        eqArt       = _getNum("cr_eq2", -1);
        evoPts      = _getNum("cr_ept", 0);
        warLog      = _get("cr_wlog", null);
        if (!(warLog instanceof Lang.Array)) { warLog = []; }
        defLog      = _get("cr_dlog", null);
        if (!(defLog instanceof Lang.Array)) { defLog = []; }
        _lastFight  = null;
        _roster     = null;

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
        if (dArena < 0) { dArena = 0; }
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

        if (arenaPts < 0) { arenaPts = 0; }
        if (arenaWins < 0) { arenaWins = 0; }
        if (arenaLosses < 0) { arenaLosses = 0; }
        if (arenaStreak < 0) { arenaStreak = 0; }
        if (evoPts < 0) { evoPts = 0; }
        strategy = Cr._clamp(strategy, 0, Cr.ST_N - 1);
        eqWeapon = Cr._clamp(eqWeapon, -1, Cr.EQ_N - 1);
        eqArmor  = Cr._clamp(eqArmor, -1, Cr.EQ_N - 1);
        eqArt    = Cr._clamp(eqArt, -1, Cr.EQ_N - 1);

        gXp = 0; gFood = 0; gMut = 0; gSecs = 0; newDay = false; justEvolved = false;
        defHits = 0; defHeld = 0; defPts = 0;
        mailAlert = false; _mailPending = false; _mailElapsed = 0;
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
        _set("cr_darena", dArena);
        _set("cr_dclaim", dailyClaimed);
        _set("cr_asc", asc);
        _set("cr_perk", perk);
        _set("cr_relic", relicMask);
        _set("cr_bweek", bondWeek);
        _set("cr_bid", bondId);
        _set("cr_bprog", bondProg);
        _set("cr_bclaim", bondClaimed);
        for (var i = 0; i < Cr.TR_N; i++) { _set("cr_t" + i, traits[i]); }

        _set("cr_apts", arenaPts);
        _set("cr_awins", arenaWins);
        _set("cr_aloss", arenaLosses);
        _set("cr_astreak", arenaStreak);
        _set("cr_strat", strategy);
        _set("cr_eq0", eqWeapon);
        _set("cr_eq1", eqArmor);
        _set("cr_eq2", eqArt);
        _set("cr_ept", evoPts);
        _set("cr_wlog", warLog);
        _set("cr_dlog", defLog);
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
                    "cr_bprog", "cr_bclaim", "cr_darena",
                    "cr_apts", "cr_awins", "cr_aloss", "cr_astreak", "cr_strat",
                    "cr_eq0", "cr_eq1", "cr_eq2", "cr_ept", "cr_wlog",
                    "cr_dlog", "cr_eqauto", "cr_roster", "cr_rosday"];
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
            dFeed = 0; dTrain = 0; dExpl = 0; dArena = 0; dailyClaimed = false;
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
        if (newDay) {
            gXp += Sensors.getStepsToday() / 60;   // once/day step bonus
            // Easy evolution-point trickle from movement — keeps EVOLVE
            // progressing even on days spent mostly idle in-app.
            var stepPts = Sensors.getStepsToday() / 800;
            if (stepPts > 6) { stepPts = 6; }
            evoPts += stepPts;
        }
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

        // Real rival fights arrive via /inbox when the phone is up; offline we
        // still roll the local defence RNG so a disconnected watch feels alive.
        if (Leaderboard.isPhoneConnected() && Leaderboard.loadUser() != null) {
            _mailPending = true;
            _mailElapsed = elapsed;
            defHits = 0; defHeld = 0; defPts = 0;
        } else {
            _rollDefences(elapsed);
        }

        lastSec = now;
        checkEvolution();
        save();
    }

    // ── Being attacked ────────────────────────────────────────────────────────
    // Real fights arrive via RaidMail (/inbox) when the phone is connected.
    // Offline (or when the fetch fails) we still roll a local defence RNG.
    // Resolved on the DEFENSIVE side only, and capped hard: a fortnight away
    // costs no more than a long weekend. Creature HP/equipment are never hurt.

    // PUBLIC — LbRaidInbox callback. won=1 means the attacker beat us.
    function onRaidInbox(ok, events) {
        if (!ok) {
            if (_mailPending) {
                _rollDefences(_mailElapsed);
                _mailPending = false;
                if (defHits > 0) { mailAlert = true; }
                save();
            }
            return;
        }
        _mailPending = false;
        var maxId = 0;
        var n = 0;
        if (events instanceof Lang.Array) {
            for (var i = 0; i < events.size(); i++) {
                var e = events[i];
                if (!(e instanceof Lang.Dictionary)) { continue; }
                var from = e["from"];
                if (!(from instanceof Lang.String) || from.length() == 0) { continue; }
                var awon = (e["won"] == 1 || e["won"] == true);
                _applyMailFight(from, awon);
                n += 1;
                var id = e["id"];
                if (id instanceof Lang.Number && id > maxId) { maxId = id; }
            }
        }
        if (maxId > 0) { RaidMail.saveAck(maxId); }
        if (n > 0) { mailAlert = true; save(); }
    }

    hidden function _applyMailFight(from, attackerWon) {
        var td = today();
        defHits += 1;
        if (!attackerWon) {
            defHeld += 1;
            arenaPts += Cr.DEF_HOLD_PTS;
            defPts += Cr.DEF_HOLD_PTS;
            _defAdd(td, true, from);
            return;
        }
        var loss = Cr.DEF_LOSS_PTS;
        if (loss > arenaPts) { loss = arenaPts; }
        arenaPts -= loss;
        defPts -= loss;
        _defAdd(td, false, from);
    }

    hidden function _rollDefences(elapsed) {
        defHits = 0; defHeld = 0; defPts = 0;
        if (arenaWins + arenaLosses < 1) { return; }   // never before a first fight
        var tries = elapsed / (Cr.DEF_HOURS_PER_TRY * 3600);
        if (tries > Cr.DEF_MAX_PER_RETURN) { tries = Cr.DEF_MAX_PER_RETURN; }
        if (tries < 1) { return; }

        var td = today();
        var guard = def();
        var hp = maxHp();
        var mySpd = spd();
        for (var i = 0; i < tries; i++) {
            if (_rand(100) >= Cr.DEF_CHANCE_PCT) { continue; }
            var foe = makeAiOpponent(0);
            if (foe == null) { continue; }
            var inc = foe.atk - guard / 2; if (inc < 3) { inc = 3; }
            var volleys = Cr.DEF_ROUNDS;
            if (mySpd >= foe.spd) { volleys -= 1; }   // a faster defender shrugs one volley off
            var held = (hp > inc * volleys);
            defHits += 1;
            if (held) {
                defHeld += 1;
                arenaPts += Cr.DEF_HOLD_PTS;
                defPts += Cr.DEF_HOLD_PTS;
            } else {
                var loss = Cr.DEF_LOSS_PTS;
                if (loss > arenaPts) { loss = arenaPts; }
                arenaPts -= loss;
                defPts -= loss;
            }
            _defAdd(td, held, foe.name);
        }
    }
    hidden function _defAdd(day, held, name) {
        var nl = [[day, held ? 1 : 0, name]];
        if (defLog != null) { nl.addAll(defLog); }
        if (nl.size() > Cr.DEF_LOG_MAX) { nl = nl.slice(0, Cr.DEF_LOG_MAX); }
        defLog = nl;
    }

    // "2d ago - HELD vs Ashen Roc". The log stores the day INDEX, never a
    // formatted date, so an entry still reads correctly whenever the player
    // next comes back to look at it.
    function defLine(i) {
        if (defLog == null || i < 0 || i >= defLog.size()) { return null; }
        var e = defLog[i];
        if (!(e instanceof Lang.Array) || e.size() < 3) { return null; }
        var ago = today() - _int(e[0], today());
        if (ago < 0) { ago = 0; }
        var when = (ago <= 0) ? "today" : (ago + "d ago");
        return when + " - " + ((e[1] == 1) ? "HELD" : "LOST") + " vs " + e[2];
    }
    // Same entry, short enough for the ARENA strip: a 240 px round face leaves
    // about seventeen pixel glyphs of chord down there, and losing the tail of a
    // rival's handle reads better than losing the verdict.
    function defShort(i) {
        if (defLog == null || i < 0 || i >= defLog.size()) { return null; }
        var e = defLog[i];
        if (!(e instanceof Lang.Array) || e.size() < 3) { return null; }
        var ago = today() - _int(e[0], today());
        if (ago < 0) { ago = 0; }
        return ((ago <= 0) ? "NOW " : (ago + "D ")) + ((e[1] == 1) ? "HELD " : "LOST ") + e[2];
    }

    // One line for the WELCOME BACK overlay, or null when nobody came calling.
    function defSummary() {
        if (defHits <= 0) { return null; }
        var s = defHits + ((defHits == 1) ? " raid" : " raids") + " while away - " + defHeld + " held";
        if (defPts != 0) { s += "  " + ((defPts > 0) ? "+" : "") + defPts + " pts"; }
        return s;
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
        evoPts += 2;
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

    // ═══════════════════════════════════════════════════════════════════════
    // ARENA — combat stats, equipment, strategy, AI opponents and fights.
    // HP is purely a per-fight simulation value (never persisted), so a fight
    // can never "kill" the creature or damage anything outside the Arena.
    // ═══════════════════════════════════════════════════════════════════════

    hidden function _gearAtk() {
        var g = 0;
        if (eqWeapon >= 0) { g += Cr.eqAtkPct(eqWeapon); }
        if (eqArmor  >= 0) { g += Cr.eqAtkPct(eqArmor); }
        if (eqArt    >= 0) { g += Cr.eqAtkPct(eqArt); }
        return g;
    }
    hidden function _gearDef() {
        var g = 0;
        if (eqWeapon >= 0) { g += Cr.eqDefPct(eqWeapon); }
        if (eqArmor  >= 0) { g += Cr.eqDefPct(eqArmor); }
        if (eqArt    >= 0) { g += Cr.eqDefPct(eqArt); }
        return g;
    }
    hidden function _gearSpd() {
        var g = 0;
        if (eqWeapon >= 0) { g += Cr.eqSpdPct(eqWeapon); }
        if (eqArmor  >= 0) { g += Cr.eqSpdPct(eqArmor); }
        if (eqArt    >= 0) { g += Cr.eqSpdPct(eqArt); }
        return g;
    }

    function atk()   { return level * 3 + traits[Cr.TR_STR] * 8 + evo * 5 + _gearAtk(); }
    function def()   { return level * 2 + traits[Cr.TR_NRG] * 6 + traits[Cr.TR_INT] * 2 + evo * 3 + _gearDef(); }
    function spd()   { return level + traits[Cr.TR_SPD] * 7 + _gearSpd(); }
    function maxHp() { return 80 + level * 12 + traits[Cr.TR_STR] * 4 + evo * 10; }
    function power() { return atk() * 2 + def() * 2 + spd() + maxHp() / 2 + arenaPts / 10; }

    // Equipment i is wearable once its species relic (i % RELIC_N) is found OR
    // enough arena wins have been banked — whichever comes first.
    function eqUnlocked(i) {
        i = Cr._clamp(i, 0, Cr.EQ_N - 1);
        if (hasRelic(i % Cr.RELIC_N)) { return true; }
        return arenaWins >= Cr.eqWinReq(i);
    }
    // Auto-equip the best unlocked item in every slot.
    function equipBest() {
        var bestW = -1; var bestWs = -1;
        var bestA = -1; var bestAs = -1;
        var bestT = -1; var bestTs = -1;
        for (var i = 0; i < Cr.EQ_N; i++) {
            if (!eqUnlocked(i)) { continue; }
            var score = Cr.eqAtkPct(i) + Cr.eqDefPct(i) + Cr.eqSpdPct(i);
            var slot = Cr.eqSlot(i);
            if (slot == Cr.EQ_SLOT_WEAPON && score > bestWs) { bestWs = score; bestW = i; }
            else if (slot == Cr.EQ_SLOT_ARMOR && score > bestAs) { bestAs = score; bestA = i; }
            else if (slot == Cr.EQ_SLOT_ART && score > bestTs) { bestTs = score; bestT = i; }
        }
        eqWeapon = bestW; eqArmor = bestA; eqArt = bestT;
        save();
    }
    // Manual equip: put item i in its slot, or take it off if it is already
    // worn. Slots the player has set are never touched by anything else.
    function equipItem(i) {
        i = Cr._clamp(i, 0, Cr.EQ_N - 1);
        if (!eqUnlocked(i)) { return false; }
        var slot = Cr.eqSlot(i);
        if (slot == Cr.EQ_SLOT_WEAPON)     { eqWeapon = (eqWeapon == i) ? -1 : i; }
        else if (slot == Cr.EQ_SLOT_ARMOR) { eqArmor  = (eqArmor  == i) ? -1 : i; }
        else                               { eqArt    = (eqArt    == i) ? -1 : i; }
        save();
        return true;
    }
    // One-time kindness so a first-timer never walks into the Arena bare-handed.
    // It runs once ever, because after that every slot belongs to the player and
    // silently re-equipping "the best" would throw their choice away.
    function equipDefaults() {
        if (_getNum("cr_eqauto", 0) == 1) { return; }
        _set("cr_eqauto", 1);
        equipBest();
    }
    function setStrategy(s) {
        strategy = Cr._clamp(s, 0, Cr.ST_N - 1);
        save();
    }

    function rank() { return Cr.rankOf(arenaPts); }
    // Live hash (nowSec + salt mixed with the DNA seed) so two fights fought a
    // second apart roll differently, but the SAME instant always resolves the
    // same way (deterministic, per the design brief).
    hidden function _fhash(nowS, salt) {
        // Golden-ratio odd multiplier that still fits a signed 32-bit Number —
        // Knuth's 2654435761 is above 2^31 and the compiler rejects the literal.
        var x = (seed ^ (nowS * 1640531527) ^ (salt * 40503)) & 0x7FFFFFFF;
        x = (x ^ (x >> 13)) & 0x7FFFFFFF;
        x = (x * 1103515245 + 12345) & 0x7FFFFFFF;
        x = (x ^ (x >> 16)) & 0x7FFFFFFF;
        return x;
    }

    hidden function _foeNames() {
        return ["Stone Beast", "Wisp Fang", "Iron Kai", "Marsh Fiend", "Ashen Roc",
                "Crag Howler", "Tide Serpent", "Storm Ram", "Night Adder",
                "Sky Talon", "Bog Wraith", "Ember Colt"];
    }

    // ── Live rival roster ─────────────────────────────────────────────────────
    // Real Arena players, fetched once a calendar day by ArenaRoster and kept as
    // flat Arrays so the whole roster is a single small Storage value:
    //   [name, level, species, evo, rarity, path, seed]
    // Everything here degrades to an empty list, which is exactly what offline
    // play needs: the procedural foe takes over and nothing else changes.
    function roster() {
        if (_roster == null) {
            var v = _get("cr_roster", null);
            _roster = (v instanceof Lang.Array) ? v : [];
        }
        return _roster;
    }
    function rosterStale() { return _getNum("cr_rosday", -1) != today(); }
    function markRosterTried() { _set("cr_rosday", today()); }
    function setRoster(list) {
        if (!(list instanceof Lang.Array)) { return; }
        var n = list;
        if (n.size() > Cr.ROSTER_MAX) { n = n.slice(0, Cr.ROSTER_MAX); }
        _roster = n;
        _set("cr_roster", n);
        _set("cr_rosday", today());
    }

    hidden function _int(v, def) {
        if (v instanceof Lang.Number) { return v; }
        return def;
    }

    // Traits are not published to the board, so a rival's three combat rolls are
    // derived from the DNA seed it DID publish: the same player always fights
    // the same way, and rarity stands in for the trait investment the meta blob
    // cannot carry. The stat shapes mirror atk()/def()/spd()/maxHp() exactly so
    // a rival is never accidentally on a different curve to the player.
    hidden function _rivalFoe(rec) {
        if (!(rec instanceof Lang.Array) || rec.size() < 7) { return null; }
        var nm = rec[0];
        if (!(nm instanceof Lang.String) || nm.length() == 0) { return null; }

        var foe = new ArenaFoe();
        foe.name    = nm;
        foe.level   = Cr._clamp(_int(rec[1], 1), 1, 999);
        foe.species = Cr._clamp(_int(rec[2], 0), 0, Cr.SPECIES_N - 1);
        foe.evo     = Cr._clamp(_int(rec[3], Cr.EV_HATCH), Cr.EV_HATCH, Cr.EV_MAX);
        foe.rarity  = Cr._clamp(_int(rec[4], 0), 0, Cr.RA_N - 1);
        foe.path    = Cr._clamp(_int(rec[5], Cr.PATH_NONE), Cr.PATH_NONE, Cr.PATH_ENERGY);
        foe.seed    = _int(rec[6], 12345) & 0x7FFFFFFF;
        foe.real    = true;

        var h = (foe.seed ^ (foe.level * 40503)) & 0x7FFFFFFF;
        h = (h ^ (h >> 13)) & 0x7FFFFFFF;
        var bump = foe.rarity;
        var rollA = 4 + (h % 6) + bump;
        var rollD = 4 + ((h / 7) % 5) + bump;
        var rollS = 4 + ((h / 13) % 7) + bump;
        foe.atk = foe.level * 3 + rollA * 8 + foe.evo * 5;
        foe.def = foe.level * 2 + rollD * 6 + foe.evo * 3;
        foe.spd = foe.level + rollS * 7;
        foe.hp  = 80 + foe.level * 12 + rollA * 4 + foe.evo * 10;
        foe.power = foe.atk * 2 + foe.def * 2 + foe.spd + foe.hp / 2;
        return foe;
    }

    // The strongest reason to fight a real player is that it IS a real player,
    // so a rival wins over a generated foe whenever one sits in the requested
    // band. Several matches roll live so repeat fights are not all the same face.
    hidden function _rosterFoe(band) {
        var list = roster();
        if (list == null || list.size() == 0) { return null; }
        var mine = power(); if (mine < 1) { mine = 1; }
        var lo; var hi;
        if (band > 0)      { lo = mine * 105 / 100; hi = mine * 220 / 100; }
        else if (band < 0) { lo = mine *  40 / 100; hi = mine *  95 / 100; }
        else               { lo = mine *  80 / 100; hi = mine * 120 / 100; }

        var hits = [];
        for (var i = 0; i < list.size(); i++) {
            var f = _rivalFoe(list[i]);
            if (f == null) { continue; }
            if (f.power < lo || f.power > hi) { continue; }
            hits.add(f);
        }
        if (hits.size() == 0) { return null; }
        return hits[_fhash(nowSec(), 991 + band * 17) % hits.size()];
    }

    // band: -1 weaker, 0 even, 1 stronger.
    function makeAiOpponent(band) {
        var real = null;
        try { real = _rosterFoe(band); } catch (e) {}
        if (real != null) { return real; }
        return _proceduralFoe(band);
    }

    // A single rival off the live roster, built the same way a matched one is.
    // The RIVALS page draws straight from these, so the caller is expected to
    // build them ONCE per roster change rather than per frame.
    function rivalAt(i) {
        var list = roster();
        if (list == null || i < 0 || i >= list.size()) { return null; }
        var f = null;
        try { f = _rivalFoe(list[i]); } catch (e) {}
        return f;
    }
    function rivalCount() {
        var list = roster();
        return (list == null) ? 0 : list.size();
    }

    // Which reward band a given opponent counts as. Picking a rival by hand
    // skips the FAIR/RISK choice, so the band — and with it the points at stake
    // — is read off the power gap instead of being chosen.
    function bandFor(foePower) {
        var mine = power(); if (mine < 1) { mine = 1; }
        if (foePower > mine * 105 / 100) { return 1; }
        if (foePower < mine * 90 / 100)  { return -1; }
        return 0;
    }

    hidden function _proceduralFoe(band) {
        var nowS = nowSec();
        var h = _fhash(nowS, 777 + band * 31);
        var names = _foeNames();
        var foe = new ArenaFoe();
        foe.name = names[h % names.size()];
        foe.species = (h / 97) % Cr.SPECIES_N;
        var lvlSwing = 2 + (h % 4);
        foe.level = level + band * lvlSwing;
        if (foe.level < 1) { foe.level = 1; }
        var rollA = 4 + (h % 6);
        var rollD = 4 + ((h / 7) % 5);
        var rollS = 4 + ((h / 13) % 7);
        var foeEvo = Cr._clamp(evo + band, Cr.EV_HATCH, Cr.EV_MAX);
        foe.evo    = foeEvo;
        foe.seed   = h;
        foe.rarity = Cr._clamp(band + 1, 0, Cr.RA_N - 1);
        foe.atk = foe.level * 3 + rollA * 8 + foeEvo * 5;
        foe.def = foe.level * 2 + rollD * 6 + foeEvo * 3;
        foe.spd = foe.level + rollS * 7;
        foe.hp  = 80 + foe.level * 12 + rollA * 4 + foeEvo * 10;
        foe.power = foe.atk * 2 + foe.def * 2 + foe.spd + foe.hp / 2;
        return foe;
    }

    hidden function _warAdd(line) {
        var nl = [line];
        if (warLog != null) { nl.addAll(warLog); }
        if (nl.size() > 8) { nl = nl.slice(0, 8); }
        warLog = nl;
    }

    // Simulate up to 8 rounds against an AI opponent. Never touches any
    // persisted HP (there isn't one) so the creature can never be "killed".
    // Returns a Dictionary the view renders straight into the battle overlay.
    function fight(band) {
        band = Cr._clamp(band, -1, 1);
        return _resolveFight(makeAiOpponent(band), band);
    }

    // Challenge one NAMED player off the Arena board. Everything after the
    // opponent is picked is the quick-fight path, so a hand-picked rival and a
    // matched one score, log and evolve identically.
    function fightRival(i) {
        var foe = rivalAt(i);
        if (foe == null) { return null; }
        return _resolveFight(foe, bandFor(foe.power));
    }

    hidden function _resolveFight(foe, band) {
        band = Cr._clamp(band, -1, 1);
        var nowS = nowSec();

        var myAtk = atk(); var myDef = def();
        if (strategy == Cr.ST_AGG) { myAtk = myAtk * 125 / 100; myDef = myDef * 85 / 100; }
        else if (strategy == Cr.ST_DEF) { myAtk = myAtk * 85 / 100; myDef = myDef * 125 / 100; }

        var myEdge  = (Cr.elementBeats(species) == foe.species);
        var foeEdge = (Cr.elementBeats(foe.species) == species);
        if (myEdge)  { myAtk = myAtk * 115 / 100; }
        if (foeEdge) { foe.atk = foe.atk * 115 / 100; }

        var myMax = maxHp(); var foeMax = foe.hp;
        var myHp = myMax; var foeHp = foeMax;
        var iWentFirst = spd() >= foe.spd;
        var rounds = [];
        // Parallel to `rounds`, one entry per strike, for the view's replay:
        //   [who (0 me / 1 foe), damage, my HP after, foe HP after, crit 0/1]
        var steps = [];
        var myCrit  = Cr._clamp(8 + traits[Cr.TR_LCK] * 2 + traits[Cr.TR_SPD], 0, Cr.CRIT_CAP_PCT);
        var foeCritPct = Cr._clamp(8 + foe.spd / 12, 0, Cr.CRIT_CAP_PCT);
        var won = false;
        var r = 0;
        while (r < 8) {
            r += 1;
            var critO = (_fhash(nowS, 300 + r) % 100) < myCrit;
            var critI = (_fhash(nowS, 400 + r) % 100) < foeCritPct;
            var dmgOut = myAtk - foe.def / 2; if (dmgOut < 3) { dmgOut = 3; }
            var dmgIn  = foe.atk - myDef / 2;  if (dmgIn < 3) { dmgIn = 3; }
            if (critO) { dmgOut = dmgOut * Cr.CRIT_MULT_PCT / 100; }
            if (critI) { dmgIn  = dmgIn  * Cr.CRIT_MULT_PCT / 100; }
            if (iWentFirst) {
                foeHp -= dmgOut; if (foeHp < 0) { foeHp = 0; }
                rounds.add("R" + r + " you hit " + dmgOut + (critO ? " CRIT" : ""));
                steps.add([0, dmgOut, myHp, foeHp, critO ? 1 : 0]);
                if (foeHp <= 0) { won = true; break; }
                myHp -= dmgIn; if (myHp < 0) { myHp = 0; }
                rounds.add("R" + r + " foe hits " + dmgIn + (critI ? " CRIT" : ""));
                steps.add([1, dmgIn, myHp, foeHp, critI ? 1 : 0]);
                if (myHp <= 0) { won = false; break; }
            } else {
                myHp -= dmgIn; if (myHp < 0) { myHp = 0; }
                rounds.add("R" + r + " foe hits " + dmgIn + (critI ? " CRIT" : ""));
                steps.add([1, dmgIn, myHp, foeHp, critI ? 1 : 0]);
                if (myHp <= 0) { won = false; break; }
                foeHp -= dmgOut; if (foeHp < 0) { foeHp = 0; }
                rounds.add("R" + r + " you hit " + dmgOut + (critO ? " CRIT" : ""));
                steps.add([0, dmgOut, myHp, foeHp, critO ? 1 : 0]);
                if (foeHp <= 0) { won = true; break; }
            }
        }
        // Ran the full 8 rounds without a knockout — the healthier side wins.
        if (myHp > 0 && foeHp > 0) { won = (myHp >= foeHp); }

        var xpGain = 0; var evoGain = 0; var ptsDelta = 0; var tip = "";
        var basePts = 15 + band * 10; if (basePts < 5) { basePts = 5; }
        if (won) {
            ptsDelta = basePts + ((arenaStreak >= 2) ? 5 : 0);
            arenaPts += ptsDelta;
            arenaWins += 1;
            arenaStreak += 1;
            xpGain = 30 + level * 2 + band * 15; if (xpGain < 5) { xpGain = 5; }
            evoGain = 4 + band * 2; if (evoGain < 1) { evoGain = 1; }
            _addXp(xpGain);
            evoPts += evoGain;
            _warAdd("W vs " + foe.name);
        } else {
            var lossPts = 8 + band * 4; if (lossPts < 0) { lossPts = 0; }
            ptsDelta = -lossPts;
            arenaPts += ptsDelta; if (arenaPts < 0) { arenaPts = 0; }
            arenaLosses += 1;
            arenaStreak = 0;
            xpGain = 8;
            evoGain = 1;
            _addXp(xpGain);
            evoPts += evoGain;
            tip = _lossDiag(steps, myMax, foeMax, iWentFirst, foeEdge, myDef, myAtk, foe);
            _warAdd("L vs " + foe.name);
        }

        dArena += 1;
        _bump(true);
        checkEvolution();
        // Tell the named rival they were fought — async inbox, never blocks play.
        try {
            if (foe.real) {
                RaidMail.notify(Cr.GAME_ID, foe.name, "fight", won);
            }
        } catch (e) {}
        save();

        _lastFight = {
            "won" => won, "rounds" => rounds, "steps" => steps, "xpGain" => xpGain,
            "evoGain" => evoGain, "ptsDelta" => ptsDelta, "foeName" => foe.name,
            "foeLevel" => foe.level, "foeSpecies" => foe.species,
            "foeEvo" => foe.evo, "foeReal" => foe.real,
            "foePower" => foe.power, "myPower" => power(),
            "myMax" => myMax, "foeMax" => foeMax,
            "tip" => tip, "band" => band
        };
        return _lastFight;
    }

    // One short line explaining a defeat, read off the fight that actually
    // happened. The generic "train STR" advice only surfaces when the round data
    // says nothing more interesting — a player who lost to a crit wants to hear
    // about the crit, not a stat sheet.
    hidden function _lossDiag(steps, myMax, foeMax, iWentFirst, foeEdge, myDef, myAtk, foe) {
        var mx = (myMax < 1) ? 1 : myMax;
        var fx = (foeMax < 1) ? 1 : foeMax;
        if (steps == null || steps.size() == 0) { return "Outmatched - train, then try FAIR"; }

        if (!iWentFirst && steps[0][1] * 100 / mx >= 20) {
            return "Speed lost you the opening round";
        }
        var inSum = 0; var inN = 0; var outSum = 0; var outN = 0; var foeCrit = false;
        for (var i = 0; i < steps.size(); i++) {
            var st = steps[i];
            if (st[0] == 1) { inSum += st[1]; inN += 1; if (st[4] == 1) { foeCrit = true; } }
            else { outSum += st[1]; outN += 1; }
        }
        if (inN > 0 && (inSum / inN) * 100 / mx >= 18) { return "Defence too low for that hitter"; }
        if (foeCrit) { return "A critical hit decided it"; }
        if (outN > 0 && (outSum / outN) * 100 / fx <= 10) { return "Your hits barely dented that armour"; }
        if (foeEdge) { return "Elemental disadvantage - try a FAIR foe"; }
        if (myDef < foe.atk / 2) { return "Train NRG/INT for more DEF"; }
        if (myAtk < foe.def) { return "Train STR for more ATK"; }
        return "Close one - more HP would have held";
    }

    // ── Daily challenge ───────────────────────────────────────────────────────
    function dailyId() { return dailyDay % 6; }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Walk 5000 steps"; }
        if (id == 1) { return "Train twice"; }
        if (id == 2) { return "Feed your creature 3x"; }
        if (id == 3) { return "Explore twice"; }
        if (id == 5) { return "Fight in the Arena"; }
        return "Come back tomorrow";
    }
    function dailyTarget() {
        var id = dailyId();
        if (id == 0) { return 5000; }
        if (id == 1) { return 2; }
        if (id == 2) { return 3; }
        if (id == 3) { return 2; }
        if (id == 5) { return 1; }
        return 1;
    }
    function dailyProgress() {
        var id = dailyId();
        if (id == 0) { var s = Sensors.getStepsToday(); return (s > 5000) ? 5000 : s; }
        if (id == 1) { return dTrain; }
        if (id == 2) { return dFeed; }
        if (id == 3) { return dExpl; }
        if (id == 5) { return dArena; }
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
                { :score => actions,         :variant => Cr.LB_TRAINER, :meta => meta },
                { :score => arenaPts,        :variant => Cr.LB_ARENA,   :meta => meta }
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

// ── A single arena opponent, built fresh per fight (never persisted) ────────
// evo/path/rarity/seed exist so the view can draw the opponent's ACTUAL
// creature rather than a generic blob; `real` marks the ones that came off the
// leaderboard, so the UI can say so.
class ArenaFoe {
    var name;
    var species;
    var level;
    var evo;
    var path;
    var rarity;
    var seed;
    var real;
    var atk;
    var def;
    var spd;
    var hp;
    var power;

    function initialize() {
        name = "Wild Beast"; species = 0; level = 1;
        evo = Cr.EV_HATCH; path = Cr.PATH_NONE; rarity = 0; seed = 12345; real = false;
        atk = 1; def = 1; spd = 1; hp = 1; power = 1;
    }
}
