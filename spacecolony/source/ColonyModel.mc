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
    var res;              // [5] resource stockpiles
    var population;
    var bLevel;           // [10] building levels (0 = not built)
    var tech;             // [4] tech levels
    var rgProg;           // [5] exploration progress %
    var discMask;         // bitmask of discovered regions

    var streak; var lastDay;
    var dailyDay; var dUpgrades; var dExpl; var dailyClaimed; var dailyCollected;
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

    hidden function _load() {
        started  = _get("sc_started", false);
        bornSec  = _get("sc_born", 0);
        lastSec  = _get("sc_last", 0);
        population = _get("sc_pop", 1);
        streak   = _get("sc_streak", 0);
        lastDay  = _get("sc_lday", 0);
        dailyDay = _get("sc_dday", 0);
        dUpgrades= _get("sc_dup", 0);
        dExpl    = _get("sc_dexp", 0);
        dailyClaimed  = _get("sc_dclaim", false);
        dailyCollected= _get("sc_dcol", false);
        discMask = _get("sc_disc", 0);
        pendingEvent = _get("sc_pev", Sc.EV_NONE);

        res = new [Sc.R_N];
        for (var i = 0; i < Sc.R_N; i++) { res[i] = _get("sc_r" + i, 0); }
        bLevel = new [Sc.B_N];
        for (var b = 0; b < Sc.B_N; b++) { bLevel[b] = _get("sc_b" + b, 0); }
        tech = new [Sc.T_N];
        for (var t = 0; t < Sc.T_N; t++) { tech[t] = _get("sc_t" + t, 0); }
        rgProg = new [Sc.RG_N];
        for (var r = 0; r < Sc.RG_N; r++) { rgProg[r] = _get("sc_rg" + r, 0); }

        var lg = _get("sc_log", null);
        log = (lg instanceof Lang.Array) ? lg : [];

        gRes = [0, 0, 0, 0, 0]; gSecs = 0; gPop = 0; newDay = false; gEvent = Sc.EV_NONE;
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
                    "sc_dcol", "sc_disc", "sc_pev", "sc_log", "sc_lbday"];
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
    function hourlyRate(r) {
        var base = 0;
        for (var i = 0; i < Sc.B_N; i++) {
            if (Sc.bProdRes(i) == r) { base += Sc.prodAt(i, bLevel[i]); }
        }
        if (base <= 0) { return 0; }
        var popPct = 100 + (population - 1) * 4;
        var elePct = 100 + bLevel[Sc.B_ELEVATOR] * 10;
        var effPct = 100 + tech[Sc.T_EFF] * 8;
        var resPct = 100;
        if (r == Sc.R_MIN) { resPct = 100 + tech[Sc.T_EXTR] * 15; }
        else if (r == Sc.R_NRG) { resPct = 100 + tech[Sc.T_POWER] * 15; }
        else if (r == Sc.R_SCI) { resPct = 100 + tech[Sc.T_RES] * 15 + bLevel[Sc.B_ALIEN] * 12; }
        var v = base;
        v = v * popPct / 100;
        v = v * elePct / 100;
        v = v * effPct / 100;
        v = v * resPct / 100;
        return v;
    }

    // ── Offline collection + daily rollover ──────────────────────────────────
    function collectOffline() {
        var now = nowSec();
        gRes = [0, 0, 0, 0, 0]; gSecs = 0; gPop = 0; newDay = false; gEvent = Sc.EV_NONE;

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
            var gain = hourlyRate(r) * elapsed / 3600;
            if (gain > 0) { res[r] += gain; gRes[r] = gain; }
        }
        var any = false;
        for (var k = 0; k < Sc.R_N; k++) { if (gRes[k] > 0) { any = true; } }
        if (any) { dailyCollected = true; }

        // Population growth (needs water).
        if (population < popCap() && res[Sc.R_H2O] > 0) {
            var add = elapsed / Sc.POP_INTERVAL;
            if (add > 0) {
                var cap = popCap();
                var np = population + add;
                if (np > cap) { np = cap; }
                gPop = np - population;
                population = np;
            }
        }

        // Steps auto-advance the current expedition (once per new day).
        if (newDay) {
            var steps = Sensors.getStepsToday();
            if (steps > 0) {
                var tgt = _nextRegion();
                if (tgt >= 0) {
                    var inc = steps * 100 / Sc.STEPS_PER_REGION;
                    _advanceRegion(tgt, inc);
                }
            }
        }

        // Maybe fire a random event when enough time passed.
        if (elapsed > 2 * 3600 && pendingEvent == Sc.EV_NONE) {
            if (_rand(100) < 45) { _rollEvent(); }
        }

        lastSec = now;
        save();
    }

    hidden function _rollEvent() {
        var e = _rand(5);
        if (Sc.evHasChoice(e)) {
            pendingEvent = e;   // resolved by the player via resolveEvent()
            return;
        }
        // Auto-resolving events apply immediately.
        if (e == Sc.EV_METEOR) {
            var b = 120 + hourlyRate(Sc.R_MIN) * 2;
            res[Sc.R_MIN] += b; gEvent = e;
            _logAdd("Meteor shower +" + b + " minerals");
        } else if (e == Sc.EV_SOLAR) {
            var loss = res[Sc.R_NRG] * 15 / 100;
            loss = loss * (100 - bLevel[Sc.B_DEFENSE] * 15) / 100;
            if (loss < 0) { loss = 0; }
            res[Sc.R_NRG] -= loss; if (res[Sc.R_NRG] < 0) { res[Sc.R_NRG] = 0; }
            gEvent = e;
            _logAdd("Solar storm -" + loss + " energy");
        } else {
            var rr = _rand(Sc.R_N);
            var bb = 80 + _rand(160);
            res[rr] += bb; gEvent = e;
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
                    var s = 60 + _rand(120); res[Sc.R_SCI] += s;
                    msg = "Decoded! +" + s + " science"; _logAdd("Alien signal decoded +" + s + " science");
                } else {
                    var l = 40 + _rand(60); res[Sc.R_NRG] -= l; if (res[Sc.R_NRG] < 0) { res[Sc.R_NRG] = 0; }
                    msg = "It was a trap. -" + l + " energy"; _logAdd("Alien signal trap -" + l + " energy");
                }
            } else { msg = "Signal ignored."; }
        } else { // EV_LOST
            if (choice == 0) {
                if (_rand(100) < 60) {
                    population += 1; var c = 40 + _rand(80); res[Sc.R_CRE] += c;
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
        return res[Sc.R_MIN] >= cost[0] && res[Sc.R_NRG] >= cost[1] && res[Sc.R_SCI] >= cost[2];
    }
    function upgradeCost(i) {
        if (i < 0 || i >= Sc.B_N) { return [0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF]; }
        return Sc.costAt(i, bLevel[i] + 1);
    }

    // Build (first level) or upgrade a building. Returns a result string.
    function upgrade(i) {
        if (i < 0 || i >= Sc.B_N) { return "Invalid"; }
        if (!isUnlocked(i)) {
            var rg = Sc.bUnlockRegion(i);
            return "Locked - explore " + Sc.rgName(rg);
        }
        var cost = upgradeCost(i);
        if (!canAfford(cost)) { return "Need more resources"; }
        res[Sc.R_MIN] -= cost[0]; res[Sc.R_NRG] -= cost[1]; res[Sc.R_SCI] -= cost[2];
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
        if (i < 0 || isDiscovered(i)) { return false; }
        rgProg[i] += incPct;
        if (rgProg[i] >= 100) {
            rgProg[i] = 100;
            discMask = discMask | (1 << i);
            dExpl += 1;
            var b = Sc.rgUnlockBuilding(i);
            _logAdd("Discovered " + Sc.rgName(i) + " -> " + Sc.bName(b));
            // discovery reward
            res[Sc.R_SCI] += 60; res[Sc.R_CRE] += 40;
            return true;
        }
        return false;
    }
    // Manual expedition tick on a region (spends energy).
    function explore(i) {
        if (i < 0 || i >= Sc.RG_N) { return "Invalid"; }
        if (isDiscovered(i)) { return Sc.rgName(i) + " already mapped"; }
        if (res[Sc.R_NRG] < Sc.EXPLORE_COST_NRG) { return "Need " + Sc.EXPLORE_COST_NRG + " energy"; }
        res[Sc.R_NRG] -= Sc.EXPLORE_COST_NRG;
        var step = Sc.EXPLORE_STEP + Sensors.getActivityMinutes() / 5;   // workout bonus
        var done = _advanceRegion(i, step);
        save();
        if (done) {
            var b = Sc.rgUnlockBuilding(i);
            return "DISCOVERY! " + Sc.rgDiscovery(i) + " unlocks " + Sc.bName(b);
        }
        return "Explored " + Sc.rgName(i) + "  " + rgProg[i] + "%";
    }

    // ── Technology ─────────────────────────────────────────────────────────────
    function techCost(i) {
        if (i < 0 || i >= Sc.T_N) { return 0x7FFFFFFF; }
        return Sc.tCost(i, tech[i]);
    }
    function research(i) {
        if (i < 0 || i >= Sc.T_N) { return "Invalid"; }
        var c = techCost(i);
        if (res[Sc.R_SCI] < c) { return "Need " + c + " science"; }
        res[Sc.R_SCI] -= c;
        tech[i] += 1;
        _logAdd("Researched " + Sc.tName(i) + " Lv" + tech[i]);
        save();
        return Sc.tName(i) + " -> Lv" + tech[i];
    }

    // ── Daily mission ──────────────────────────────────────────────────────────
    function dailyId() { return dailyDay % 4; }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Collect offline output"; }
        if (id == 1) { return "Upgrade a building"; }
        if (id == 2) { return "Walk 5000 steps"; }
        return "Complete an expedition";
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
        res[Sc.R_SCI] += 120; res[Sc.R_MIN] += 200; res[Sc.R_CRE] += 50;
        save();
        return true;
    }

    // ── History / milestones ────────────────────────────────────────────────
    function milestoneLabel() {
        var d = daysAlive();
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
