// ═══════════════════════════════════════════════════════════════════════════
// ColonyModel.mc — All SPACE COLONY game state + logic.
//
// One class owns everything: save/load, idle (offline) production, the building
// tree (build/upgrade), planet exploration + discoveries, the tech tree, random
// events, daily missions, streaks, colony history and the five leaderboard
// scores. The view/delegate only read fields and call action methods. Every
// Storage access is guarded so nothing here can throw into the UI.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Math;

class ColonyModel {
    var started;          // Boolean — colony bootstrapped
    var bornSec; var lastSec;
    var res;              // [R_N] resource stockpiles
    var population;
    var bLevel;           // [B_N] building levels (0 = not built)
    var tech;             // [T_N] tech levels
    var rgProg;           // [RG_N] exploration progress %
    var discMask;         // bitmask of discovered regions

    var streak; var lastDay;
    var dailyDay; var dUpgrades; var dExpl; var dailyClaimed; var dailyCollected;
    var stepBase;         // steps already converted into expedition progress today
    var log;              // Array<String> history (newest first, cap 8)
    var pendingEvent;     // EV_* awaiting a choice, or EV_NONE

    // Idle summary (for WELCOME BACK)
    var gRes; var gSecs; var gPop; var newDay; var gEvent;

    function initialize() { _load(); }

    // ── Storage ───────────────────────────────────────────────────────────────
    hidden function _get(k, def) {
        try { var v = Application.Storage.getValue(k); if (v != null) { return v; } } catch (e) {}
        return def;
    }
    hidden function _set(k, v) { try { Application.Storage.setValue(k, v); } catch (e) {} }

    // Numeric load that survives a corrupt / legacy / wrong-typed value and
    // clamps it into a sane band. Any value read from Storage may end up being
    // used as an array index or a loop bound, so nothing loads unvalidated.
    hidden function _num(k, def, lo, hi) {
        var v = _get(k, def);
        var n = def;
        if (v instanceof Lang.Number) { n = v; }
        else if (v instanceof Lang.Float || v instanceof Lang.Double) { n = v.toNumber(); }
        else if (v instanceof Lang.Long) { n = v.toNumber(); }
        if (n < lo) { n = lo; }
        if (n > hi) { n = hi; }
        return n;
    }
    hidden function _bool(k, def) {
        var v = _get(k, def);
        if (v instanceof Lang.Boolean) { return v; }
        if (v instanceof Lang.Number) { return v != 0; }
        return def;
    }

    hidden function _load() {
        started  = _bool("sc_started", false);
        bornSec  = _num("sc_born", 0, 0, 0x7FFFFFFF);
        lastSec  = _num("sc_last", 0, 0, 0x7FFFFFFF);
        population = _num("sc_pop", 1, 1, 100000);
        streak   = _num("sc_streak", 0, 0, 100000);
        lastDay  = _num("sc_lday", 0, 0, 0x7FFFFFFF);
        dailyDay = _num("sc_dday", 0, 0, 0x7FFFFFFF);
        dUpgrades= _num("sc_dup", 0, 0, 100000);
        dExpl    = _num("sc_dexp", 0, 0, 100000);
        dailyClaimed  = _bool("sc_dclaim", false);
        dailyCollected= _bool("sc_dcol", false);
        stepBase = _num("sc_stepb", 0, 0, 1000000);   // absent in old saves -> 0
        discMask = _num("sc_disc", 0, 0, (1 << Sc.RG_N) - 1);
        pendingEvent = _num("sc_pev", Sc.EV_NONE, Sc.EV_NONE, Sc.EV_RARE);

        // New indices simply aren't in old saves — they default to 0 here.
        res = new [Sc.R_N];
        for (var i = 0; i < Sc.R_N; i++) { res[i] = _num("sc_r" + i, 0, 0, Sc.RES_CAP); }
        bLevel = new [Sc.B_N];
        for (var b = 0; b < Sc.B_N; b++) { bLevel[b] = _num("sc_b" + b, 0, 0, Sc.LVL_CAP); }
        tech = new [Sc.T_N];
        for (var t = 0; t < Sc.T_N; t++) { tech[t] = _num("sc_t" + t, 0, 0, Sc.LVL_CAP); }
        rgProg = new [Sc.RG_N];
        for (var r = 0; r < Sc.RG_N; r++) { rgProg[r] = _num("sc_rg" + r, 0, 0, 100); }
        // A region flagged discovered must read as 100% (and vice-versa) so the
        // UI can never show a "mapped" region stuck at 40%.
        for (var d = 0; d < Sc.RG_N; d++) { if (isDiscovered(d)) { rgProg[d] = 100; } }

        // Only keep genuine strings: a corrupt entry would blow up the log page.
        var lg = _get("sc_log", null);
        log = [];
        if (lg instanceof Lang.Array) {
            for (var l = 0; l < lg.size() && l < 8; l++) {
                if (lg[l] instanceof Lang.String) { log.add(lg[l]); }
            }
        }

        gRes = new [Sc.R_N];
        for (var g = 0; g < Sc.R_N; g++) { gRes[g] = 0; }
        gSecs = 0; gPop = 0; newDay = false; gEvent = Sc.EV_NONE;
    }

    // Clamped stockpile add — keeps every resource inside 32-bit range so a
    // long-lived colony can never wrap negative.
    hidden function _addRes(r, amt) {
        if (r < 0 || r >= Sc.R_N || amt <= 0) { return 0; }
        var room = Sc.RES_CAP - res[r];
        if (room < 0) { room = 0; }
        if (amt > room) { amt = room; }
        res[r] += amt;
        return amt;
    }
    hidden function _subRes(r, amt) {
        if (r < 0 || r >= Sc.R_N || amt <= 0) { return; }
        res[r] -= amt;
        if (res[r] < 0) { res[r] = 0; }
    }

    function save() {
        _set("sc_started", started);
        _set("sc_born", bornSec);
        _set("sc_last", lastSec);
        _set("sc_pop", population);
        _set("sc_streak", streak);
        _set("sc_lday", lastDay);
        _set("sc_dday", dailyDay);
        _set("sc_dup", dUpgrades);
        _set("sc_dexp", dExpl);
        _set("sc_dclaim", dailyClaimed);
        _set("sc_dcol", dailyCollected);
        _set("sc_stepb", stepBase);
        _set("sc_disc", discMask);
        _set("sc_pev", pendingEvent);
        for (var i = 0; i < Sc.R_N; i++) { _set("sc_r" + i, res[i]); }
        for (var b = 0; b < Sc.B_N; b++) { _set("sc_b" + b, bLevel[b]); }
        for (var t = 0; t < Sc.T_N; t++) { _set("sc_t" + t, tech[t]); }
        for (var r = 0; r < Sc.RG_N; r++) { _set("sc_rg" + r, rgProg[r]); }
        _set("sc_log", log);
    }

    // ── Full reset (OPTIONS → Reset colony) ──────────────────────────────────
    // Wipes every progress key back to zero, keeping the player's settings
    // (sound/haptics, demo mode, explainer-seen). Fully guarded.
    function resetAll() {
        var keys = ["sc_started", "sc_born", "sc_last", "sc_pop", "sc_streak",
                    "sc_lday", "sc_dday", "sc_dup", "sc_dexp", "sc_dclaim",
                    "sc_dcol", "sc_disc", "sc_pev", "sc_log", "sc_lbday", "sc_stepb"];
        for (var i = 0; i < keys.size(); i++) { try { Application.Storage.deleteValue(keys[i]); } catch (e) {} }
        for (var r = 0; r < Sc.R_N; r++)  { try { Application.Storage.deleteValue("sc_r" + r); } catch (e) {} }
        for (var b = 0; b < Sc.B_N; b++)  { try { Application.Storage.deleteValue("sc_b" + b); } catch (e) {} }
        for (var t = 0; t < Sc.T_N; t++)  { try { Application.Storage.deleteValue("sc_t" + t); } catch (e) {} }
        for (var g = 0; g < Sc.RG_N; g++) { try { Application.Storage.deleteValue("sc_rg" + g); } catch (e) {} }
        _load();
    }

    // ── Time / RNG ──────────────────────────────────────────────────────────
    function nowSec() { return Time.now().value(); }
    function today()  { return nowSec() / 86400; }
    hidden function _rand(n) { if (n <= 1) { return 0; } return (Math.rand() & 0x7FFFFFFF) % n; }

    hidden function _logAdd(s) {
        var nl = [s];
        nl.addAll(log);
        if (nl.size() > 8) { nl = nl.slice(0, 8); }
        log = nl;
    }

    // ── First run ─────────────────────────────────────────────────────────────
    function ensureStart() {
        if (started) { return; }
        var t = nowSec();
        started = true;
        bornSec = t; lastSec = t;
        res[Sc.R_NRG] = 100; res[Sc.R_MIN] = 50; res[Sc.R_H2O] = 30;
        res[Sc.R_SCI] = 0;   res[Sc.R_CRE] = 0;
        population = 1;
        lastDay = today(); dailyDay = today(); streak = 1;
        _logAdd("Day 1 - First colony on X-01");
        save();
    }

    // ── Derived ─────────────────────────────────────────────────────────────
    function popCap() { return 3 + bLevel[Sc.B_HABITAT] * 4; }
    function daysAlive() {
        if (bornSec == 0) { return 0; }
        var d = (nowSec() - bornSec) / 86400;
        return (d < 0) ? 0 : d;
    }
    function ageDayLabel() { return "Day " + (daysAlive() + 1); }

    function regionsDiscovered() {
        var c = 0;
        for (var i = 0; i < Sc.RG_N; i++) { if (isDiscovered(i)) { c++; } }
        return c;
    }
    function isDiscovered(i) { return (discMask & (1 << i)) != 0; }

    function buildingsBuilt() {
        var c = 0;
        for (var i = 0; i < Sc.B_N; i++) { if (bLevel[i] > 0) { c++; } }
        return c;
    }
    function totalBuildingLevels() {
        var s = 0;
        for (var i = 0; i < Sc.B_N; i++) { s += bLevel[i]; }
        return s;
    }
    function totalTech() {
        var s = 0;
        for (var i = 0; i < Sc.T_N; i++) { s += tech[i]; }
        return s;
    }

    function civScore() {
        return totalBuildingLevels() + regionsDiscovered() * 8 + totalTech() * 4 + population * 2;
    }
    function civLevel() { return 1 + civScore() / 12; }

    // ── Production ─────────────────────────────────────────────────────────────
    // Percentage scale that can't overflow: both operands are clamped and the
    // multiply is split when the value is large.
    hidden function _pct(v, p) {
        if (v <= 0) { return 0; }
        if (v > Sc.RATE_CAP) { v = Sc.RATE_CAP; }
        if (p < 0) { p = 0; }
        if (p > 10000) { p = 10000; }
        if (v > 100000) { return v / 100 * p; }
        return v * p / 100;
    }

    function hourlyRate(r) {
        var base = 0;
        for (var i = 0; i < Sc.B_N; i++) {
            if (Sc.bProdRes(i) == r) { base += Sc.prodAt(i, bLevel[i]); }
        }
        if (base <= 0) { return 0; }
        var popPct = 100 + (population - 1) * 4;
        var elePct = 100 + bLevel[Sc.B_ELEVATOR] * 10 + bLevel[Sc.B_QUANTUM] * 18;
        var effPct = 100 + tech[Sc.T_EFF] * 8;
        var resPct = 100;
        if (r == Sc.R_MIN)      { resPct = 100 + tech[Sc.T_EXTR] * 15; }
        else if (r == Sc.R_NRG) { resPct = 100 + tech[Sc.T_POWER] * 15; }
        else if (r == Sc.R_SCI) { resPct = 100 + tech[Sc.T_RES] * 15 + bLevel[Sc.B_ALIEN] * 12; }
        else if (r == Sc.R_H2O) { resPct = 100 + tech[Sc.T_HYDRO] * 15; }
        else if (r == Sc.R_CRE) { resPct = 100 + tech[Sc.T_TRADE] * 15; }
        var v = base;
        v = _pct(v, popPct);
        v = _pct(v, elePct);
        v = _pct(v, effPct);
        v = _pct(v, resPct);
        if (v > Sc.RATE_CAP) { v = Sc.RATE_CAP; }
        return v;
    }

    // rate-per-hour applied over `secs` without overflowing the multiply.
    hidden function _accrue(rate, secs) {
        if (rate <= 0 || secs <= 0) { return 0; }
        if (rate > Sc.RATE_CAP) { rate = Sc.RATE_CAP; }
        var hrs = secs / 3600;
        var rem = secs % 3600;
        var g = rate * hrs;
        if (rate > 500000) { g += rate / 3600 * rem; } else { g += rate * rem / 3600; }
        return g;
    }

    // Seconds between colonist arrivals — Gene Therapy shortens it. The divisor
    // is always >= 100 and the result is floored, so this can never divide by
    // zero nor collapse to an instant-growth loop.
    function popInterval() {
        var boost = 100 + tech[Sc.T_GENE] * 20;
        if (boost < 100) { boost = 100; }
        var iv = Sc.POP_INTERVAL / boost * 100;
        if (iv < Sc.POP_MIN_IVL) { iv = Sc.POP_MIN_IVL; }
        return iv;
    }

    // ── Offline collection + daily rollover ──────────────────────────────────
    function collectOffline() {
        var now = nowSec();
        for (var z = 0; z < Sc.R_N; z++) { gRes[z] = 0; }
        gSecs = 0; gPop = 0; newDay = false; gEvent = Sc.EV_NONE;

        var td = today();
        if (td != lastDay) {
            newDay = true;
            if (lastDay != 0 && td == lastDay + 1) { streak += 1; }
            else { streak = 1; }
            lastDay = td;
        }
        if (streak < 1) { streak = 1; }
        if (dailyDay != td) {
            dailyDay = td; dUpgrades = 0; dExpl = 0; dailyClaimed = false; dailyCollected = false;
        }

        var elapsed = now - lastSec;
        if (elapsed < 0) { elapsed = 0; }
        if (elapsed > Sc.OFFLINE_CAP) { elapsed = Sc.OFFLINE_CAP; }
        gSecs = elapsed;

        // Resource production.
        for (var r = 0; r < Sc.R_N; r++) {
            var gain = _accrue(hourlyRate(r), elapsed);
            if (gain > 0) { gRes[r] = _addRes(r, gain); }
        }
        var any = false;
        for (var k = 0; k < Sc.R_N; k++) { if (gRes[k] > 0) { any = true; } }
        if (any) { dailyCollected = true; }

        // Population growth — every new colonist DRINKS water, so the Farm (and
        // later the Ice Works) stays relevant forever. Running dry pauses growth
        // rather than breaking it: production is untouched, water keeps flowing
        // in, and a credit-funded supply drop can always restart it.
        _growPopulation(elapsed);

        _creditSteps();

        // Maybe fire a random event when enough time passed.
        if (elapsed > 2 * 3600 && pendingEvent == Sc.EV_NONE) {
            if (_rand(100) < 45) { _rollEvent(); }
        }

        lastSec = now;
        save();
    }

    // Steps map the planet. Progress is credited from the DELTA since the last
    // check rather than once on the first open of a new day, so it no longer
    // matters what time you open the app. Steps that don't add up to a whole
    // percent are left on the counter and carry over — with 100k-step regions
    // that carry-over is the difference between progress and none at all.
    hidden function _creditSteps() {
        if (newDay) { stepBase = 0; }
        var steps = Sensors.getStepsToday();
        if (steps < 0) { steps = 0; }
        if (steps < stepBase) { stepBase = steps; }   // midnight / device reset
        var delta = steps - stepBase;
        if (delta <= 0) { return; }
        var tgt = _nextRegion();
        if (tgt < 0) { stepBase = steps; return; }    // planet fully mapped
        var need = Sc.stepsForRegion(tgt);
        if (need < 1) { need = 1; }
        var inc = delta * 100 / need;
        if (inc <= 0) { return; }
        if (inc > 100) { inc = 100; }
        stepBase += inc * need / 100;
        _advanceRegion(tgt, inc);
    }

    // Colonists arrive one interval at a time and each one consumes water.
    hidden function _growPopulation(elapsed) {
        var cap = popCap();
        if (population >= cap || elapsed <= 0) { return; }
        var iv = popInterval();
        if (iv < 1) { iv = 1; }
        var add = elapsed / iv;
        if (add <= 0) { return; }
        if (population + add > cap) { add = cap - population; }
        var wpp = Sc.WATER_PER_POP;
        if (wpp < 1) { wpp = 1; }
        var affordable = res[Sc.R_H2O] / wpp;   // wpp is a positive constant
        if (add > affordable) { add = affordable; }
        if (add <= 0) { return; }
        _subRes(Sc.R_H2O, add * wpp);
        population += add;
        gPop = add;
    }

    hidden function _rollEvent() {
        var e = _rand(5);
        if (Sc.evHasChoice(e)) {
            pendingEvent = e;   // resolved by the player via resolveEvent()
            return;
        }
        // Auto-resolving events apply immediately.
        if (e == Sc.EV_METEOR) {
            var b = 120 + _pct(hourlyRate(Sc.R_MIN), 200);
            b = _addRes(Sc.R_MIN, b); gEvent = e;
            _logAdd("Meteor shower +" + b + " minerals");
        } else if (e == Sc.EV_SOLAR) {
            var shield = bLevel[Sc.B_DEFENSE] * 15;
            if (shield > 90) { shield = 90; }          // never a negative loss
            var loss = _pct(_pct(res[Sc.R_NRG], 15), 100 - shield);
            if (loss < 0) { loss = 0; }
            _subRes(Sc.R_NRG, loss);
            gEvent = e;
            _logAdd("Solar storm -" + loss + " energy");
        } else {
            var rr = _rand(Sc.R_N);
            var bb = _addRes(rr, 80 + _rand(160)); gEvent = e;
            _logAdd("Rare find +" + bb + " " + Sc.resName(rr));
        }
    }

    // Player answers a choice event. choice: 0 = investigate/rescue, 1 = ignore.
    function resolveEvent(choice) {
        var e = pendingEvent;
        pendingEvent = Sc.EV_NONE;
        if (e == Sc.EV_NONE || !Sc.evHasChoice(e)) { save(); return ""; }
        var msg = "";
        if (e == Sc.EV_SIGNAL) {
            if (choice == 0) {
                if (_rand(100) < 65) {
                    var s = _addRes(Sc.R_SCI, 60 + _rand(120));
                    msg = "Decoded! +" + s + " science"; _logAdd("Alien signal decoded +" + s + " science");
                } else {
                    var l = 40 + _rand(60); _subRes(Sc.R_NRG, l);
                    msg = "It was a trap. -" + l + " energy"; _logAdd("Alien signal trap -" + l + " energy");
                }
            } else { msg = "Signal ignored."; }
        } else { // EV_LOST
            if (choice == 0) {
                if (_rand(100) < 60) {
                    population += 1; var c = _addRes(Sc.R_CRE, 40 + _rand(80));
                    msg = "Rescued! +1 pop  +" + c + " credits"; _logAdd("Expedition rescued +1 colonist");
                } else {
                    msg = "Team was lost to the storm."; _logAdd("Expedition lost");
                }
            } else { msg = "Search called off."; }
        }
        save();
        return msg;
    }

    // ── Buildings ─────────────────────────────────────────────────────────────
    function isUnlocked(i) {
        var rg = Sc.bUnlockRegion(i);
        return (rg < 0) || isDiscovered(rg);
    }
    function canAfford(cost) {
        return res[Sc.R_MIN] >= cost[0] && res[Sc.R_NRG] >= cost[1]
            && res[Sc.R_SCI] >= cost[2] && res[Sc.R_CRE] >= cost[3];
    }
    function upgradeCost(i) {
        if (i < 0 || i >= Sc.B_N) { return [0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF]; }
        return Sc.costAt(i, bLevel[i] + 1);
    }

    // Build (first level) or upgrade a building. Returns a result string.
    function upgrade(i) {
        if (i < 0 || i >= Sc.B_N) { return "Invalid"; }
        if (!isUnlocked(i)) {
            var rg = Sc.bUnlockRegion(i);
            return "Locked - explore " + Sc.rgName(rg);
        }
        if (bLevel[i] >= Sc.LVL_CAP) { return Sc.bName(i) + " is maxed"; }
        var cost = upgradeCost(i);
        if (!canAfford(cost)) { return "Need more resources"; }
        _subRes(Sc.R_MIN, cost[0]); _subRes(Sc.R_NRG, cost[1]);
        _subRes(Sc.R_SCI, cost[2]);  _subRes(Sc.R_CRE, cost[3]);
        var wasNew = (bLevel[i] == 0);
        bLevel[i] += 1;
        dUpgrades += 1;
        if (wasNew) { _logAdd("Built " + Sc.bName(i)); }
        save();
        var verb = wasNew ? "Built " : "Upgraded ";
        return verb + Sc.bName(i) + " Lv" + bLevel[i];
    }

    // ── Exploration ────────────────────────────────────────────────────────────
    hidden function _nextRegion() {
        for (var i = 0; i < Sc.RG_N; i++) { if (!isDiscovered(i)) { return i; } }
        return -1;
    }
    hidden function _advanceRegion(i, incPct) {
        if (i < 0 || i >= Sc.RG_N || isDiscovered(i)) { return false; }
        if (incPct <= 0) { return false; }
        rgProg[i] += incPct;
        if (rgProg[i] >= 100) {
            rgProg[i] = 100;
            discMask = discMask | (1 << i);
            var b = Sc.rgUnlockBuilding(i);
            _logAdd("Discovered " + Sc.rgName(i) + " -> " + Sc.bName(b));
            // Discovery reward scales with how deep into the planet you are.
            _addRes(Sc.R_SCI, 60 + i * 90);
            _addRes(Sc.R_CRE, 40 + i * 70);
            return true;
        }
        return false;
    }
    // How many manual expeditions the colony can mount in one day. Without a
    // cap a player can tap a whole region open in one sitting, which is what
    // made the planet run out in a week; the Launch Pad buys more sorties.
    function expeditionCap() {
        var c = 4 + bLevel[Sc.B_LAUNCH] / 2;
        return (c > 9) ? 9 : c;
    }
    function expeditionsLeft() {
        var n = expeditionCap() - dExpl;
        return (n < 0) ? 0 : n;
    }

    // Manual expedition tick on a region (spends energy). Deeper regions cost
    // more energy per tick AND cover less ground per tick.
    function explore(i) {
        if (i < 0 || i >= Sc.RG_N) { return "Invalid"; }
        if (isDiscovered(i)) { return Sc.rgName(i) + " already mapped"; }
        if (expeditionsLeft() <= 0) { return "Crew resting - back tomorrow"; }
        var cost = Sc.exploreCostNrg(i);
        if (res[Sc.R_NRG] < cost) { return "Need " + cost + " energy"; }
        _subRes(Sc.R_NRG, cost);
        dExpl += 1;
        // Base ground covered + a workout bonus + the Launch Pad's expedition
        // boost (the pad finally does what its description promised).
        var step = Sc.exploreStepPct(i);
        var bonusPct = Sensors.getActivityMinutes() / 5 + bLevel[Sc.B_LAUNCH] * 6;
        step += Sc.exploreStepPct(i) * bonusPct / 100;
        if (step < 1) { step = 1; }
        var done = _advanceRegion(i, step);
        save();
        if (done) {
            var b = Sc.rgUnlockBuilding(i);
            return "DISCOVERY! " + Sc.rgDiscovery(i) + " unlocks " + Sc.bName(b);
        }
        return "Explored " + Sc.rgName(i) + "  " + rgProg[i] + "%";
    }

    // ── Trade (the Credits sink) ──────────────────────────────────────────────
    // Buys an emergency supply drop: credits in, water + minerals out. Water is
    // the one resource population growth burns, so this doubles as the escape
    // hatch that guarantees a dry colony can always restart growth.
    function tradeCost() {
        var c = 120 + population * 20 + totalBuildingLevels() * 12;
        if (c > Sc.RES_CAP) { c = Sc.RES_CAP; }
        return c;
    }
    function tradeYield() { return 200 + bLevel[Sc.B_TRADE] * 180; }
    function supplyDrop() {
        var c = tradeCost();
        if (res[Sc.R_CRE] < c) { return "Need " + c + " credits"; }
        _subRes(Sc.R_CRE, c);
        var w = _addRes(Sc.R_H2O, tradeYield());
        _addRes(Sc.R_MIN, tradeYield() / 2);
        save();   // deliberately not logged: trades are frequent and would
                  // flush the 8-entry colony history of real milestones

        return "Supply drop! +" + w + " water";
    }

    // ── Technology ─────────────────────────────────────────────────────────────
    function techCost(i) {
        if (i < 0 || i >= Sc.T_N) { return 0x7FFFFFFF; }
        return Sc.tCost(i, tech[i]);
    }
    function research(i) {
        if (i < 0 || i >= Sc.T_N) { return "Invalid"; }
        if (tech[i] >= Sc.LVL_CAP) { return Sc.tName(i) + " is maxed"; }
        var c = techCost(i);
        if (res[Sc.R_SCI] < c) { return "Need " + c + " science"; }
        _subRes(Sc.R_SCI, c);
        tech[i] += 1;
        _logAdd("Researched " + Sc.tName(i) + " Lv" + tech[i]);
        save();
        return Sc.tName(i) + " -> Lv" + tech[i];
    }

    // ── Daily mission ──────────────────────────────────────────────────────────
    function dailyId() {
        var d = dailyDay % 4;
        return (d < 0) ? 0 : d;
    }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Collect offline output"; }
        if (id == 1) { return "Upgrade a building"; }
        if (id == 2) { return "Walk 5000 steps"; }
        return "Run an expedition";
    }
    function dailyTarget() {
        var id = dailyId();
        if (id == 2) { return 5000; }
        return 1;
    }
    function dailyProgress() {
        var id = dailyId();
        if (id == 0) { return dailyCollected ? 1 : 0; }
        if (id == 1) { return dUpgrades > 0 ? 1 : 0; }
        if (id == 2) { var s = Sensors.getStepsToday(); return (s > 5000) ? 5000 : s; }
        return dExpl > 0 ? 1 : 0;
    }
    function dailyComplete() { return dailyProgress() >= dailyTarget(); }
    function dailyRewardText() { return "+120 SCI  +200 MIN  +50 CR"; }
    function claimDaily() {
        if (dailyClaimed || !dailyComplete()) { return false; }
        dailyClaimed = true;
        _addRes(Sc.R_SCI, 120); _addRes(Sc.R_MIN, 200); _addRes(Sc.R_CRE, 50);
        save();
        return true;
    }

    // ── History / milestones ────────────────────────────────────────────────
    function milestoneLabel() {
        var d = daysAlive();
        if (d >= 700) { return "Eternal Dominion"; }
        if (d >= 365) { return "Interstellar Age"; }
        if (d >= 200) { return "Core Worlds"; }
        if (d >= 100) { return "Galactic Empire"; }
        if (d >= 30)  { return "Space Civilization"; }
        if (d >= 7)   { return "First Expansion"; }
        return "First Colony";
    }
    function history() { return log; }

    // ── Leaderboard (throttled to once/day) ──────────────────────────────────
    function submitScores() {
        var td = today();
        if (_get("sc_lbday", 0) == td) { return; }
        if (!started) { return; }
        _set("sc_lbday", td);
        // Serial batch: one request at a time (see submitScoreBatch — Garmin
        // allows only one in-flight makeWebRequest; concurrent posts dropped
        // boards and crashed the app on some firmware).
        try {
            var meta = {
                "planet" => "X-01",
                "civ"    => civLevel(),
                "pop"    => population,
                "buildings" => totalBuildingLevels(),
                "regions"   => regionsDiscovered()
            };
            Leaderboard.submitScoreBatch(Sc.GAME_ID, [
                { :score => civLevel(),   :variant => Sc.LB_CIV,     :meta => meta },
                { :score => population,   :variant => Sc.LB_COLONY,  :meta => meta },
                { :score => totalTech() + bLevel[Sc.B_LAB], :variant => Sc.LB_TECH, :meta => meta },
                { :score => daysAlive() + 1, :variant => Sc.LB_AGE,  :meta => meta },
                { :score => regionsDiscovered() * 100 + _expPct(), :variant => Sc.LB_EXPLORE, :meta => meta }
            ]);
        } catch (e) {}
    }
    hidden function _expPct() {
        var s = 0;
        for (var i = 0; i < Sc.RG_N; i++) { s += rgProg[i]; }
        return s / Sc.RG_N;
    }
}
