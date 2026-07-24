// ═══════════════════════════════════════════════════════════════════════════
// IslandModel.mc — All ISLAND game state + logic.
//
// One class owns everything: save/load, idle (offline) income, the building
// tree (build/upgrade across Housing/Nature/Entertainment/Special), visitors,
// hidden-area discovery, the collection of decorations, random events, daily
// challenges, streaks, island history and the four leaderboard scores. The
// view/delegate only read fields and call action methods. Every Storage access
// is guarded so nothing here can throw into the UI.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Math;

class IslandModel {
    var started;
    var bornSec; var lastSec;
    var res;              // [4] Coins, Wood, Stone, Food
    var population;
    var visitors;
    var bLevel;           // [16] building levels
    var arProg;           // [5] area exploration %
    var discMask;         // discovered-areas bitmask
    var collMask;         // owned-collectibles bitmask

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
        started    = _get("is_started", false);
        bornSec    = _get("is_born", 0);
        lastSec    = _get("is_last", 0);
        population = _get("is_pop", 0);
        visitors   = _get("is_vis", 0);
        streak     = _get("is_streak", 0);
        lastDay    = _get("is_lday", 0);
        dailyDay   = _get("is_dday", 0);
        dUpgrades  = _get("is_dup", 0);
        dExpl      = _get("is_dexp", 0);
        dailyClaimed   = _get("is_dclaim", false);
        dailyCollected = _get("is_dcol", false);
        discMask   = _get("is_disc", 0);
        collMask   = _get("is_coll", 0);
        pendingEvent = _get("is_pev", Is.EV_NONE);

        res = new [Is.R_N];
        for (var i = 0; i < Is.R_N; i++) { res[i] = _get("is_r" + i, 0); }
        bLevel = new [Is.B_N];
        for (var b = 0; b < Is.B_N; b++) { bLevel[b] = _get("is_b" + b, 0); }
        arProg = new [Is.AR_N];
        for (var a = 0; a < Is.AR_N; a++) { arProg[a] = _get("is_ar" + a, 0); }

        var lg = _get("is_log", null);
        log = (lg instanceof Lang.Array) ? lg : [];

        gRes = [0, 0, 0, 0]; gSecs = 0; gPop = 0; gVis = 0; newDay = false; gEvent = Is.EV_NONE;
    }

    function save() {
        _set("is_started", started);
        _set("is_born", bornSec);
        _set("is_last", lastSec);
        _set("is_pop", population);
        _set("is_vis", visitors);
        _set("is_streak", streak);
        _set("is_lday", lastDay);
        _set("is_dday", dailyDay);
        _set("is_dup", dUpgrades);
        _set("is_dexp", dExpl);
        _set("is_dclaim", dailyClaimed);
        _set("is_dcol", dailyCollected);
        _set("is_disc", discMask);
        _set("is_coll", collMask);
        _set("is_pev", pendingEvent);
        for (var i = 0; i < Is.R_N; i++) { _set("is_r" + i, res[i]); }
        for (var b = 0; b < Is.B_N; b++) { _set("is_b" + b, bLevel[b]); }
        for (var a = 0; a < Is.AR_N; a++) { _set("is_ar" + a, arProg[a]); }
        _set("is_log", log);
    }

    // ── Full reset (OPTIONS → Reset island) ──────────────────────────────────
    // Wipes every progress key back to zero, keeping the player's settings
    // (sound/haptics, demo mode, intro-seen). Fully guarded.
    function resetAll() {
        var keys = ["is_started", "is_born", "is_last", "is_pop", "is_vis",
                    "is_streak", "is_lday", "is_dday", "is_dup", "is_dexp",
                    "is_dclaim", "is_dcol", "is_disc", "is_coll", "is_pev",
                    "is_log", "is_lbday"];
        for (var i = 0; i < keys.size(); i++) { try { Application.Storage.deleteValue(keys[i]); } catch (e) {} }
        for (var r = 0; r < Is.R_N; r++) { try { Application.Storage.deleteValue("is_r" + r); } catch (e) {} }
        for (var b = 0; b < Is.B_N; b++) { try { Application.Storage.deleteValue("is_b" + b); } catch (e) {} }
        for (var a = 0; a < Is.AR_N; a++) { try { Application.Storage.deleteValue("is_ar" + a); } catch (e) {} }
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
        res[Is.R_COIN] = 50; res[Is.R_WOOD] = 20; res[Is.R_STONE] = 0; res[Is.R_FOOD] = 15;
        population = 0; visitors = 0;
        lastDay = today(); dailyDay = today(); streak = 1;
        _logAdd("You discovered an unknown island");
        save();
    }

    // ── Derived ─────────────────────────────────────────────────────────────
    function popCap() {
        var c = 3;
        for (var i = 0; i < Is.B_N; i++) { c += bLevel[i] * Is.bPopPer(i); }
        return c;
    }
    function attraction() {
        var a = 0;
        for (var i = 0; i < Is.B_N; i++) { a += bLevel[i] * Is.bAttract(i); }
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
        for (var i = 0; i < Is.AR_N; i++) { if (isDiscovered(i)) { c++; } }
        return c;
    }
    function hasColl(i) { return (collMask & (1 << i)) != 0; }
    function collectiblesOwned() {
        var c = 0;
        for (var i = 0; i < Is.C_N; i++) { if (hasColl(i)) { c++; } }
        return c;
    }
    function collectionScore() {
        var s = 0;
        for (var i = 0; i < Is.C_N; i++) { if (hasColl(i)) { s += Is.cWeight(i); } }
        return s;
    }

    function totalBuildingLevels() {
        var s = 0;
        for (var i = 0; i < Is.B_N; i++) { s += bLevel[i]; }
        return s;
    }
    function natureLevels() {
        var s = 0;
        for (var i = Is.B_FOREST; i <= Is.B_TRAIL; i++) { s += bLevel[i]; }
        return s;
    }
    function specialLevels() {
        var s = 0;
        for (var i = Is.B_TEMPLE; i <= Is.B_SKY; i++) { s += bLevel[i]; }
        return s;
    }
    function beautyScore() {
        return collectionScore() * 4 + specialLevels() * 5 + natureLevels() * 2 + areasDiscovered() * 6;
    }

    function islandLevel() {
        var score = totalBuildingLevels() * 3 + areasDiscovered() * 8 + population
                  + collectiblesOwned() * 5 + visitors / 4;
        return 1 + score / 10;
    }
    function milestoneLabel() {
        var l = islandLevel();
        if (l >= 100) { return "Mythical Kingdom"; }
        if (l >= 50)  { return "Legendary Island"; }
        if (l >= 25)  { return "Tourist Paradise"; }
        if (l >= 10)  { return "Small Village"; }
        return "Empty Island";
    }

    // ── Production ─────────────────────────────────────────────────────────────
    function hourlyRate(r) {
        var base = 0;
        for (var i = 0; i < Is.B_N; i++) {
            if (Is.bProdRes(i) == r) { base += Is.prodAt(i, bLevel[i]); }
        }
        if (r == Is.R_COIN) { base += visitors * 2; }   // visitor passive income
        if (base <= 0) { return 0; }
        var popPct     = 100 + population * 2;
        var crystalPct = 100 + bLevel[Is.B_CRYSTAL] * 10;
        var skyPct     = 100 + bLevel[Is.B_SKY] * 15;
        var v = base;
        v = v * popPct / 100;
        v = v * crystalPct / 100;
        v = v * skyPct / 100;
        return v;
    }

    // ── Offline collection + daily rollover ──────────────────────────────────
    function collectOffline() {
        var now = nowSec();
        gRes = [0, 0, 0, 0]; gSecs = 0; gPop = 0; gVis = 0; newDay = false; gEvent = Is.EV_NONE;

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
        if (elapsed > Is.OFFLINE_CAP) { elapsed = Is.OFFLINE_CAP; }
        gSecs = elapsed;

        // Visitors grow first (they feed coin income below).
        var vcap = visitorsCap();
        if (visitors < vcap) {
            var av = elapsed / Is.VISITOR_INTERVAL;
            if (av > 0) {
                var nv = visitors + av; if (nv > vcap) { nv = vcap; }
                gVis = nv - visitors; visitors = nv;
            }
        }

        // Resource income (night bonus from sleep).
        var nightPct = 100;
        if (newDay) { var sl = Sensors.getSleepData(); if (sl > 0) { nightPct = 110; } }
        for (var r = 0; r < Is.R_N; r++) {
            var gain = hourlyRate(r) * elapsed / 3600;
            gain = gain * nightPct / 100;
            if (gain > 0) { res[r] += gain; gRes[r] = gain; }
        }
        var any = false;
        for (var k = 0; k < Is.R_N; k++) { if (gRes[k] > 0) { any = true; } }
        if (any) { dailyCollected = true; }

        // Population growth (needs food).
        if (population < popCap() && res[Is.R_FOOD] > 0) {
            var add = elapsed / Is.POP_INTERVAL;
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
                if (tgt >= 0) { _advanceArea(tgt, steps * 100 / Is.STEPS_PER_AREA); }
            }
        }

        _checkMilestoneCollectibles();

        if (elapsed > 2 * 3600 && pendingEvent == Is.EV_NONE) {
            if (_rand(100) < 45) { _rollEvent(); }
        }

        lastSec = now;
        save();
    }

    hidden function _rollEvent() {
        var e = _rand(5);
        if (Is.evHasChoice(e)) { pendingEvent = e; return; }
        if (e == Is.EV_STORM) {
            var loss = res[Is.R_WOOD] * 10 / 100;
            res[Is.R_WOOD] -= loss; if (res[Is.R_WOOD] < 0) { res[Is.R_WOOD] = 0; }
            gEvent = e; _logAdd("Storm -" + loss + " wood");
        } else if (e == Is.EV_ANIMAL) {
            var v = 8 + _rand(20); visitors += v; gEvent = e;
            _logAdd("Rare animal +" + v + " visitors");
            if (_rand(100) < 40) { _grantRandomCollectible(); }
        } else { // FESTIVAL
            var c = 150 + _rand(300); res[Is.R_COIN] += c; visitors += 10; gEvent = e;
            _logAdd("Festival +" + c + " coins");
        }
    }

    // choice: 0 = open/trade, 1 = ignore
    function resolveEvent(choice) {
        choice = (choice != 0) ? 1 : 0;
        var e = pendingEvent;
        if (e == Is.EV_NONE) { return ""; }
        pendingEvent = Is.EV_NONE;
        var msg = "";
        if (e == Is.EV_TREASURE) {
            if (choice == 0) {
                var c = 120 + _rand(280); res[Is.R_COIN] += c;
                msg = "Chest opened! +" + c + " coins"; _logAdd("Treasure +" + c + " coins");
                if (_rand(100) < 45) { var gi = _grantRandomCollectible(); if (gi >= 0) { msg = "Found " + Is.cName(gi) + "!"; } }
            } else { msg = "Left the chest."; }
        } else { // TRAVELER
            if (choice == 0) {
                if (res[Is.R_COIN] >= 100) {
                    res[Is.R_COIN] -= 100;
                    var gi2 = _grantRandomCollectible();
                    msg = (gi2 >= 0) ? ("Traded for " + Is.cName(gi2)) : "Traded for 20 wood";
                    if (gi2 < 0) { res[Is.R_WOOD] += 20; }
                    _logAdd("Traveler trade");
                } else { msg = "Not enough coins to trade"; }
            } else { msg = "Traveler moved on."; }
        }
        save();
        return msg;
    }

    // ── Buildings ─────────────────────────────────────────────────────────────
    function isUnlocked(i) {
        var ar = Is.bUnlockArea(i);
        return (ar < 0) || isDiscovered(ar);
    }
    function upgradeCost(i) { return Is.costAt(i, bLevel[i] + 1); }
    function canAfford(cost) {
        return res[Is.R_COIN] >= cost[0] && res[Is.R_WOOD] >= cost[1] && res[Is.R_STONE] >= cost[2];
    }
    function upgrade(i) {
        if (i < 0 || i >= Is.B_N) { return "Invalid build"; }
        if (!isUnlocked(i)) {
            return "Locked - explore " + Is.arName(Is.bUnlockArea(i));
        }
        var cost = upgradeCost(i);
        if (!canAfford(cost)) { return "Need more resources"; }
        res[Is.R_COIN] -= cost[0]; res[Is.R_WOOD] -= cost[1]; res[Is.R_STONE] -= cost[2];
        var wasNew = (bLevel[i] == 0);
        bLevel[i] += 1;
        dUpgrades += 1;
        if (wasNew) { _logAdd("Built " + Is.bName(i)); }
        _checkMilestoneCollectibles();
        save();
        return (wasNew ? "Built " : "Upgraded ") + Is.bName(i) + " Lv" + bLevel[i];
    }

    // ── Discovery ──────────────────────────────────────────────────────────────
    hidden function _nextArea() {
        for (var i = 0; i < Is.AR_N; i++) { if (!isDiscovered(i)) { return i; } }
        return -1;
    }
    hidden function _advanceArea(i, incPct) {
        if (i < 0 || isDiscovered(i)) { return false; }
        arProg[i] += incPct;
        if (arProg[i] >= 100) {
            arProg[i] = 100;
            discMask = discMask | (1 << i);
            dExpl += 1;
            res[Is.R_COIN] += 80;
            var b = Is.arUnlockBuilding(i);
            if (b >= 0) { _logAdd("Discovered " + Is.arName(i) + " -> " + Is.bName(b)); }
            else { _grantCollectible(7); _logAdd("Discovered " + Is.arName(i) + " -> Ancient Monument"); }
            return true;
        }
        return false;
    }
    function explore(i) {
        if (i < 0 || i >= Is.AR_N) { return "Invalid area"; }
        if (isDiscovered(i)) { return Is.arName(i) + " already explored"; }
        if (res[Is.R_COIN] < Is.EXPLORE_COST_COIN) { return "Need " + Is.EXPLORE_COST_COIN + " coins"; }
        res[Is.R_COIN] -= Is.EXPLORE_COST_COIN;
        var step = Is.EXPLORE_STEP + Sensors.getActivityMinutes() / 5;
        var done = _advanceArea(i, step);
        save();
        if (done) {
            var b = Is.arUnlockBuilding(i);
            if (b >= 0) { return "DISCOVERY! " + Is.arDiscovery(i) + " unlocks " + Is.bName(b); }
            return "DISCOVERY! " + Is.arDiscovery(i);
        }
        return "Explored " + Is.arName(i) + "  " + arProg[i] + "%";
    }

    // ── Collection ──────────────────────────────────────────────────────────────
    hidden function _grantCollectible(i) {
        if (i < 0 || i >= Is.C_N || hasColl(i)) { return false; }
        collMask = collMask | (1 << i);
        _logAdd("Collected " + Is.cName(i));
        return true;
    }
    hidden function _grantRandomCollectible() {
        var avail = [];
        for (var i = 0; i < Is.C_N; i++) { if (!hasColl(i)) { avail.add(i); } }
        if (avail.size() == 0) { return -1; }
        var pick = avail[_rand(avail.size())];
        _grantCollectible(pick);
        return pick;
    }
    // Grant milestone decorations as the island level climbs.
    hidden function _checkMilestoneCollectibles() {
        var l = islandLevel();
        if (l >= 10)  { _grantCollectible(0); }   // Palm Grove
        if (l >= 20)  { _grantCollectible(4); }   // Coral Reef
        if (l >= 35)  { _grantCollectible(3); }   // Golden Tree
        if (l >= 60)  { _grantCollectible(5); }   // Crystal Waterfall
        if (l >= 100) { _grantCollectible(8); }   // Rainbow Fountain
    }

    // ── Daily challenge ─────────────────────────────────────────────────────────
    function dailyId() { return dailyDay % 4; }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Visit your island"; }
        if (id == 1) { return "Collect island income"; }
        if (id == 2) { return "Walk 3000 steps"; }
        return "Upgrade a building";
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
        res[Is.R_COIN] += 250; res[Is.R_WOOD] += 80;
        if (_rand(100) < 20) { _grantRandomCollectible(); }
        save();
        return true;
    }

    function history() { return log; }

    // ── DEMO fast-track (showcase) ───────────────────────────────────────────
    // Every call is fully self-contained + guarded so it can NEVER crash, even
    // when spammed from the view tick loop. Injects a chunk of resources, nudges
    // population/visitors, then advances discovery + the best affordable build.
    function demoStep() {
        try { grantDemoResources(); } catch (e) {}
        try { demoExplore(); } catch (e) {}
        try { demoUpgrade(); } catch (e) {}
        try { demoUpgrade(); } catch (e) {}   // two builds/tick for lively growth
        try { _checkMilestoneCollectibles(); } catch (e) {}
        try { save(); } catch (e) {}
    }

    function grantDemoResources() {
        res[Is.R_COIN]  += 600;
        res[Is.R_WOOD]  += 300;
        res[Is.R_STONE] += 180;
        res[Is.R_FOOD]  += 140;
        var pc = popCap();
        if (population < pc) { population += 1; if (population > pc) { population = pc; } }
        var vc = visitorsCap();
        if (visitors < vc) { visitors += 5; if (visitors > vc) { visitors = vc; } }
    }

    // Advance the next undiscovered area by a big chunk (bypasses coin cost).
    function demoExplore() {
        var i = _nextArea();
        if (i < 0 || i >= Is.AR_N) { return false; }
        return _advanceArea(i, 40);
    }

    // Upgrade the cheapest affordable unlocked building. Returns true if built.
    function demoUpgrade() {
        var best = -1; var bestCost = 0;
        for (var i = 0; i < Is.B_N; i++) {
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
        if (_get("is_lbday", 0) == td) { return; }
        if (!started) { return; }
        _set("is_lbday", td);
        // Serial batch: one request at a time (see submitScoreBatch — Garmin
        // allows only one in-flight makeWebRequest; concurrent posts dropped
        // boards and crashed the app on some firmware).
        try {
            var meta = {
                "level"   => islandLevel(),
                "pop"     => population,
                "visitors"=> visitors,
                "beauty"  => beautyScore(),
                "coll"    => collectiblesOwned()
            };
            Leaderboard.submitScoreBatch(Is.GAME_ID, [
                { :score => islandLevel(),     :variant => Is.LB_LEVEL,   :meta => meta },
                { :score => beautyScore(),     :variant => Is.LB_BEAUTY,  :meta => meta },
                { :score => population,        :variant => Is.LB_POP,     :meta => meta },
                { :score => collectionScore(), :variant => Is.LB_COLLECT, :meta => meta }
            ]);
        } catch (e) {}
    }
}
