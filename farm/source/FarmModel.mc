// ═══════════════════════════════════════════════════════════════════════════
// FarmModel.mc — All FARM game state + logic.
//
// One class owns everything: save/load, idle (offline) production, the
// structure tree (build/upgrade across Livestock/Crops/Market/Special), guests,
// land exploration, the collection of charms, random events, daily challenges,
// streaks, farm history and the four leaderboard scores. The view/delegate only
// read fields and call action methods. Every Storage access is guarded so
// nothing here can throw into the UI.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Math;

class FarmModel {
    var started;
    var bornSec; var lastSec;
    var res;              // [4] Coins, Wood, Grain, Feed
    var population;       // animals living on the farm
    var visitors;         // guests
    var bLevel;           // [16] structure levels
    var arProg;           // [5] exploration %
    var discMask;         // explored-areas bitmask
    var collMask;         // owned-charms bitmask

    var streak; var lastDay;
    var dailyDay; var dUpgrades; var dExpl; var dailyClaimed; var dailyCollected;
    var log;              // Array<String> history, newest first, cap 8
    var pendingEvent;

    // Idle summary (WELCOME BACK)
    var gRes; var gSecs; var gPop; var gVis; var newDay; var gEvent;

    function initialize() { _load(); }

    // ── Storage ───────────────────────────────────────────────────────────────
    hidden function _get(k, def) {
        try { var v = Application.Storage.getValue(k); if (v != null) { return v; } } catch (e) {}
        return def;
    }
    hidden function _set(k, v) { try { Application.Storage.setValue(k, v); } catch (e) {} }

    hidden function _load() {
        started    = _get("fa_started", false);
        bornSec    = _get("fa_born", 0);
        lastSec    = _get("fa_last", 0);
        population = _get("fa_pop", 0);
        visitors   = _get("fa_vis", 0);
        streak     = _get("fa_streak", 0);
        lastDay    = _get("fa_lday", 0);
        dailyDay   = _get("fa_dday", 0);
        dUpgrades  = _get("fa_dup", 0);
        dExpl      = _get("fa_dexp", 0);
        dailyClaimed   = _get("fa_dclaim", false);
        dailyCollected = _get("fa_dcol", false);
        discMask   = _get("fa_disc", 0);
        collMask   = _get("fa_coll", 0);
        pendingEvent = _get("fa_pev", Fa.EV_NONE);

        res = new [Fa.R_N];
        for (var i = 0; i < Fa.R_N; i++) { res[i] = _get("fa_r" + i, 0); }
        bLevel = new [Fa.B_N];
        for (var b = 0; b < Fa.B_N; b++) { bLevel[b] = _get("fa_b" + b, 0); }
        arProg = new [Fa.AR_N];
        for (var a = 0; a < Fa.AR_N; a++) { arProg[a] = _get("fa_ar" + a, 0); }

        var lg = _get("fa_log", null);
        log = (lg instanceof Lang.Array) ? lg : [];

        gRes = [0, 0, 0, 0]; gSecs = 0; gPop = 0; gVis = 0; newDay = false; gEvent = Fa.EV_NONE;
    }

    function save() {
        _set("fa_started", started);
        _set("fa_born", bornSec);
        _set("fa_last", lastSec);
        _set("fa_pop", population);
        _set("fa_vis", visitors);
        _set("fa_streak", streak);
        _set("fa_lday", lastDay);
        _set("fa_dday", dailyDay);
        _set("fa_dup", dUpgrades);
        _set("fa_dexp", dExpl);
        _set("fa_dclaim", dailyClaimed);
        _set("fa_dcol", dailyCollected);
        _set("fa_disc", discMask);
        _set("fa_coll", collMask);
        _set("fa_pev", pendingEvent);
        for (var i = 0; i < Fa.R_N; i++) { _set("fa_r" + i, res[i]); }
        for (var b = 0; b < Fa.B_N; b++) { _set("fa_b" + b, bLevel[b]); }
        for (var a = 0; a < Fa.AR_N; a++) { _set("fa_ar" + a, arProg[a]); }
        _set("fa_log", log);
    }

    // ── Full reset (OPTIONS → Reset farm) ─────────────────────────────────────
    // Wipes every progress key back to zero, keeping the player's settings
    // (sound/haptics, demo mode, intro-seen). Fully guarded.
    function resetAll() {
        var keys = ["fa_started", "fa_born", "fa_last", "fa_pop", "fa_vis",
                    "fa_streak", "fa_lday", "fa_dday", "fa_dup", "fa_dexp",
                    "fa_dclaim", "fa_dcol", "fa_disc", "fa_coll", "fa_pev",
                    "fa_log", "fa_lbday"];
        for (var i = 0; i < keys.size(); i++) { try { Application.Storage.deleteValue(keys[i]); } catch (e) {} }
        for (var r = 0; r < Fa.R_N; r++) { try { Application.Storage.deleteValue("fa_r" + r); } catch (e) {} }
        for (var b = 0; b < Fa.B_N; b++) { try { Application.Storage.deleteValue("fa_b" + b); } catch (e) {} }
        for (var a = 0; a < Fa.AR_N; a++) { try { Application.Storage.deleteValue("fa_ar" + a); } catch (e) {} }
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
        res[Fa.R_COIN] = 50; res[Fa.R_WOOD] = 20; res[Fa.R_GRAIN] = 0; res[Fa.R_FEED] = 15;
        population = 0; visitors = 0;
        lastDay = today(); dailyDay = today(); streak = 1;
        _logAdd("You started a little farm");
        save();
    }

    // ── Derived ─────────────────────────────────────────────────────────────
    function popCap() {
        var c = 3;
        for (var i = 0; i < Fa.B_N; i++) { c += bLevel[i] * Fa.bPopPer(i); }
        return c;
    }
    function attraction() {
        var a = 0;
        for (var i = 0; i < Fa.B_N; i++) { a += bLevel[i] * Fa.bAttract(i); }
        return a;
    }
    function visitorsCap() { return attraction() * 6 + 5; }

    function daysAlive() {
        if (bornSec == 0) { return 0; }
        var d = (nowSec() - bornSec) / 86400;
        return (d < 0) ? 0 : d;
    }
    function ageDayLabel() { return "Day " + (daysAlive() + 1); }

    function isDiscovered(i) { return (discMask & (1 << i)) != 0; }
    function areasDiscovered() {
        var c = 0;
        for (var i = 0; i < Fa.AR_N; i++) { if (isDiscovered(i)) { c++; } }
        return c;
    }
    function hasColl(i) { return (collMask & (1 << i)) != 0; }
    function collectiblesOwned() {
        var c = 0;
        for (var i = 0; i < Fa.C_N; i++) { if (hasColl(i)) { c++; } }
        return c;
    }
    function collectionScore() {
        var s = 0;
        for (var i = 0; i < Fa.C_N; i++) { if (hasColl(i)) { s += Fa.cWeight(i); } }
        return s;
    }

    function totalBuildingLevels() {
        var s = 0;
        for (var i = 0; i < Fa.B_N; i++) { s += bLevel[i]; }
        return s;
    }
    function cropLevels() {
        var s = 0;
        for (var i = Fa.B_WHEAT; i <= Fa.B_BERRY; i++) { s += bLevel[i]; }
        return s;
    }
    function specialLevels() {
        var s = 0;
        for (var i = Fa.B_GOLDBARN; i <= Fa.B_SILO; i++) { s += bLevel[i]; }
        return s;
    }
    function charmScore() {
        return collectionScore() * 4 + specialLevels() * 5 + cropLevels() * 2 + areasDiscovered() * 6;
    }

    function farmLevel() {
        var score = totalBuildingLevels() * 3 + areasDiscovered() * 8 + population
                  + collectiblesOwned() * 5 + visitors / 4;
        return 1 + score / 10;
    }
    function milestoneLabel() {
        var l = farmLevel();
        if (l >= 100) { return "Legendary Ranch"; }
        if (l >= 50)  { return "Prize Ranch"; }
        if (l >= 25)  { return "Busy Farmstead"; }
        if (l >= 10)  { return "Growing Farm"; }
        return "New Paddock";
    }

    // ── Production ─────────────────────────────────────────────────────────────
    function hourlyRate(r) {
        var base = 0;
        for (var i = 0; i < Fa.B_N; i++) {
            if (Fa.bProdRes(i) == r) { base += Fa.prodAt(i, bLevel[i]); }
        }
        if (r == Fa.R_COIN) { base += visitors * 2; }   // guest passive income
        if (base <= 0) { return 0; }
        var popPct     = 100 + population * 2;
        var greenPct   = 100 + bLevel[Fa.B_GREENHSE] * 10;
        var siloPct    = 100 + bLevel[Fa.B_SILO] * 15;
        var v = base;
        v = v * popPct / 100;
        v = v * greenPct / 100;
        v = v * siloPct / 100;
        return v;
    }

    // ── Offline collection + daily rollover ──────────────────────────────────
    function collectOffline() {
        var now = nowSec();
        gRes = [0, 0, 0, 0]; gSecs = 0; gPop = 0; gVis = 0; newDay = false; gEvent = Fa.EV_NONE;

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
        if (elapsed > Fa.OFFLINE_CAP) { elapsed = Fa.OFFLINE_CAP; }
        gSecs = elapsed;

        // Guests grow first (they feed coin income below).
        var vcap = visitorsCap();
        if (visitors < vcap) {
            var av = elapsed / Fa.VISITOR_INTERVAL;
            if (av > 0) {
                var nv = visitors + av; if (nv > vcap) { nv = vcap; }
                gVis = nv - visitors; visitors = nv;
            }
        }

        // Resource income (night bonus from sleep).
        var nightPct = 100;
        if (newDay) { var sl = Sensors.getSleepData(); if (sl > 0) { nightPct = 110; } }
        for (var r = 0; r < Fa.R_N; r++) {
            var gain = hourlyRate(r) * elapsed / 3600;
            gain = gain * nightPct / 100;
            if (gain > 0) { res[r] += gain; gRes[r] = gain; }
        }
        var any = false;
        for (var k = 0; k < Fa.R_N; k++) { if (gRes[k] > 0) { any = true; } }
        if (any) { dailyCollected = true; }

        // Animal growth (needs feed).
        if (population < popCap() && res[Fa.R_FEED] > 0) {
            var add = elapsed / Fa.POP_INTERVAL;
            if (add > 0) {
                var cap = popCap();
                var np = population + add; if (np > cap) { np = cap; }
                gPop = np - population; population = np;
            }
        }

        // Steps auto-advance the current expedition (once per new day).
        if (newDay) {
            var steps = Sensors.getStepsToday();
            if (steps > 0) {
                var tgt = _nextArea();
                if (tgt >= 0) { _advanceArea(tgt, steps * 100 / Fa.STEPS_PER_AREA); }
            }
        }

        _checkMilestoneCollectibles();

        if (elapsed > 2 * 3600 && pendingEvent == Fa.EV_NONE) {
            if (_rand(100) < 45) { _rollEvent(); }
        }

        lastSec = now;
        save();
    }

    hidden function _rollEvent() {
        var e = _rand(5);
        if (Fa.evHasChoice(e)) { pendingEvent = e; return; }
        if (e == Fa.EV_STORM) {
            var loss = res[Fa.R_GRAIN] * 10 / 100;
            res[Fa.R_GRAIN] -= loss; if (res[Fa.R_GRAIN] < 0) { res[Fa.R_GRAIN] = 0; }
            gEvent = e; _logAdd("Storm -" + loss + " grain");
        } else if (e == Fa.EV_ANIMAL) {
            var v = 8 + _rand(20); visitors += v; gEvent = e;
            _logAdd("Stray animal +" + v + " guests");
            if (_rand(100) < 40) { _grantRandomCollectible(); }
        } else { // FESTIVAL
            var c = 150 + _rand(300); res[Fa.R_COIN] += c; visitors += 10; gEvent = e;
            _logAdd("Festival +" + c + " coins");
        }
    }

    // choice: 0 = open/trade, 1 = ignore
    function resolveEvent(choice) {
        choice = (choice != 0) ? 1 : 0;
        var e = pendingEvent;
        if (e == Fa.EV_NONE) { return ""; }
        pendingEvent = Fa.EV_NONE;
        var msg = "";
        if (e == Fa.EV_TREASURE) {
            if (choice == 0) {
                var c = 120 + _rand(280); res[Fa.R_COIN] += c;
                msg = "Crate opened! +" + c + " coins"; _logAdd("Lucky crate +" + c + " coins");
                if (_rand(100) < 45) { var gi = _grantRandomCollectible(); if (gi >= 0) { msg = "Found " + Fa.cName(gi) + "!"; } }
            } else { msg = "Left the crate."; }
        } else { // TRAVELER
            if (choice == 0) {
                if (res[Fa.R_COIN] >= 100) {
                    res[Fa.R_COIN] -= 100;
                    var gi2 = _grantRandomCollectible();
                    msg = (gi2 >= 0) ? ("Traded for " + Fa.cName(gi2)) : "Traded for 20 wood";
                    if (gi2 < 0) { res[Fa.R_WOOD] += 20; }
                    _logAdd("Merchant trade");
                } else { msg = "Not enough coins to trade"; }
            } else { msg = "Merchant moved on."; }
        }
        save();
        return msg;
    }

    // ── Structures ────────────────────────────────────────────────────────────
    function isUnlocked(i) {
        var ar = Fa.bUnlockArea(i);
        return (ar < 0) || isDiscovered(ar);
    }
    function upgradeCost(i) { return Fa.costAt(i, bLevel[i] + 1); }
    function canAfford(cost) {
        return res[Fa.R_COIN] >= cost[0] && res[Fa.R_WOOD] >= cost[1] && res[Fa.R_GRAIN] >= cost[2];
    }
    function upgrade(i) {
        if (i < 0 || i >= Fa.B_N) { return "Invalid build"; }
        if (!isUnlocked(i)) {
            return "Locked - explore " + Fa.arName(Fa.bUnlockArea(i));
        }
        var cost = upgradeCost(i);
        if (!canAfford(cost)) { return "Need more resources"; }
        res[Fa.R_COIN] -= cost[0]; res[Fa.R_WOOD] -= cost[1]; res[Fa.R_GRAIN] -= cost[2];
        var wasNew = (bLevel[i] == 0);
        bLevel[i] += 1;
        dUpgrades += 1;
        if (wasNew) { _logAdd("Built " + Fa.bName(i)); }
        _checkMilestoneCollectibles();
        save();
        return (wasNew ? "Built " : "Upgraded ") + Fa.bName(i) + " Lv" + bLevel[i];
    }

    // ── Exploration ────────────────────────────────────────────────────────────
    hidden function _nextArea() {
        for (var i = 0; i < Fa.AR_N; i++) { if (!isDiscovered(i)) { return i; } }
        return -1;
    }
    hidden function _advanceArea(i, incPct) {
        if (i < 0 || isDiscovered(i)) { return false; }
        arProg[i] += incPct;
        if (arProg[i] >= 100) {
            arProg[i] = 100;
            discMask = discMask | (1 << i);
            dExpl += 1;
            res[Fa.R_COIN] += 80;
            var b = Fa.arUnlockBuilding(i);
            if (b >= 0) { _logAdd("Explored " + Fa.arName(i) + " -> " + Fa.bName(b)); }
            else { _grantCollectible(7); _logAdd("Explored " + Fa.arName(i) + " -> Prize Ribbon"); }
            return true;
        }
        return false;
    }
    function explore(i) {
        if (i < 0 || i >= Fa.AR_N) { return "Invalid area"; }
        if (isDiscovered(i)) { return Fa.arName(i) + " already explored"; }
        if (res[Fa.R_COIN] < Fa.EXPLORE_COST_COIN) { return "Need " + Fa.EXPLORE_COST_COIN + " coins"; }
        res[Fa.R_COIN] -= Fa.EXPLORE_COST_COIN;
        var step = Fa.EXPLORE_STEP + Sensors.getActivityMinutes() / 5;
        var done = _advanceArea(i, step);
        save();
        if (done) {
            var b = Fa.arUnlockBuilding(i);
            if (b >= 0) { return "FOUND! " + Fa.arDiscovery(i) + " unlocks " + Fa.bName(b); }
            return "FOUND! " + Fa.arDiscovery(i);
        }
        return "Explored " + Fa.arName(i) + "  " + arProg[i] + "%";
    }

    // ── Collection ──────────────────────────────────────────────────────────────
    hidden function _grantCollectible(i) {
        if (i < 0 || i >= Fa.C_N || hasColl(i)) { return false; }
        collMask = collMask | (1 << i);
        _logAdd("Collected " + Fa.cName(i));
        return true;
    }
    hidden function _grantRandomCollectible() {
        var avail = [];
        for (var i = 0; i < Fa.C_N; i++) { if (!hasColl(i)) { avail.add(i); } }
        if (avail.size() == 0) { return -1; }
        var pick = avail[_rand(avail.size())];
        _grantCollectible(pick);
        return pick;
    }
    // Grant milestone charms as the farm level climbs.
    hidden function _checkMilestoneCollectibles() {
        var l = farmLevel();
        if (l >= 10)  { _grantCollectible(0); }   // Flower Bed
        if (l >= 20)  { _grantCollectible(4); }   // Pond Ducks
        if (l >= 35)  { _grantCollectible(3); }   // Golden Egg
        if (l >= 60)  { _grantCollectible(5); }   // Rainbow Cow
        if (l >= 100) { _grantCollectible(8); }   // Harvest Feast
    }

    // ── Daily challenge ─────────────────────────────────────────────────────────
    function dailyId() { return dailyDay % 4; }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Visit your farm"; }
        if (id == 1) { return "Collect farm income"; }
        if (id == 2) { return "Walk 3000 steps"; }
        return "Upgrade a structure";
    }
    function dailyTarget() { return (dailyId() == 2) ? 3000 : 1; }
    function dailyProgress() {
        var id = dailyId();
        if (id == 0) { return 1; }                 // opening completes "visit"
        if (id == 1) { return dailyCollected ? 1 : 0; }
        if (id == 2) { var s = Sensors.getStepsToday(); return (s > 3000) ? 3000 : s; }
        return dUpgrades > 0 ? 1 : 0;
    }
    function dailyComplete() { return dailyProgress() >= dailyTarget(); }
    function dailyRewardText() { return "+250 Coins  +80 Wood"; }
    function claimDaily() {
        if (dailyClaimed || !dailyComplete()) { return false; }
        dailyClaimed = true;
        res[Fa.R_COIN] += 250; res[Fa.R_WOOD] += 80;
        if (_rand(100) < 20) { _grantRandomCollectible(); }
        save();
        return true;
    }

    function history() { return log; }

    // ── DEMO fast-track (showcase) ───────────────────────────────────────────
    // Every call is fully self-contained + guarded so it can NEVER crash, even
    // when spammed from the view tick loop. Injects a chunk of resources, nudges
    // herd/guests, then advances exploration + the best affordable build.
    function demoStep() {
        try { grantDemoResources(); } catch (e) {}
        try { demoExplore(); } catch (e) {}
        try { demoUpgrade(); } catch (e) {}
        try { demoUpgrade(); } catch (e) {}   // two builds/tick for lively growth
        try { _checkMilestoneCollectibles(); } catch (e) {}
        try { save(); } catch (e) {}
    }

    function grantDemoResources() {
        res[Fa.R_COIN]  += 600;
        res[Fa.R_WOOD]  += 300;
        res[Fa.R_GRAIN] += 180;
        res[Fa.R_FEED]  += 140;
        var pc = popCap();
        if (population < pc) { population += 1; if (population > pc) { population = pc; } }
        var vc = visitorsCap();
        if (visitors < vc) { visitors += 5; if (visitors > vc) { visitors = vc; } }
    }

    // Advance the next unexplored area by a big chunk (bypasses coin cost).
    function demoExplore() {
        var i = _nextArea();
        if (i < 0 || i >= Fa.AR_N) { return false; }
        return _advanceArea(i, 40);
    }

    // Upgrade the cheapest affordable unlocked structure. Returns true if built.
    function demoUpgrade() {
        var best = -1; var bestCost = 0;
        for (var i = 0; i < Fa.B_N; i++) {
            if (!isUnlocked(i)) { continue; }
            var c = upgradeCost(i);
            if (!canAfford(c)) { continue; }
            var tot = c[0] + c[1] + c[2];
            if (best < 0 || tot < bestCost) { best = i; bestCost = tot; }
        }
        if (best >= 0) { upgrade(best); return true; }
        return false;
    }

    // ── Leaderboard (throttled to once/day) ──────────────────────────────────
    function submitScores() {
        var td = today();
        if (_get("fa_lbday", 0) == td) { return; }
        if (!started) { return; }
        _set("fa_lbday", td);
        // Serial batch: one request at a time (see submitScoreBatch — Garmin
        // allows only one in-flight makeWebRequest; concurrent posts dropped
        // boards and crashed the app on some firmware).
        try {
            var meta = {
                "level"   => farmLevel(),
                "herd"    => population,
                "guests"  => visitors,
                "charm"   => charmScore(),
                "coll"    => collectiblesOwned()
            };
            Leaderboard.submitScoreBatch(Fa.GAME_ID, [
                { :score => farmLevel(),       :variant => Fa.LB_LEVEL,   :meta => meta },
                { :score => charmScore(),      :variant => Fa.LB_CHARM,   :meta => meta },
                { :score => population,        :variant => Fa.LB_HERD,    :meta => meta },
                { :score => collectionScore(), :variant => Fa.LB_COLLECT, :meta => meta }
            ]);
        } catch (e) {}
    }
}
