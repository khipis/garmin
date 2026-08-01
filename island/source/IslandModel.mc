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
    var dExpTry;          // manual expeditions launched today
    var msDone;           // highest streak milestone already paid out
    var log;              // Array<String> history, newest first, cap 8
    var pendingEvent;

    // Idle summary (WELCOME BACK)
    var gRes; var gSecs; var gPop; var gVis; var newDay; var gEvent;

    function initialize() { _load(); }

    // ── Storage ───────────────────────────────────────────────────────────────
    // Saturation limits. Everything the player can accumulate is bounded so no
    // arithmetic path (idle income, multipliers, costs) can wrap a 32-bit int.
    const RES_MAX  = 1000000000;
    const RATE_MAX = 100000000;
    const LVL_MAX  = 2000;
    const VIS_MAX  = 10000000;
    const POP_MAX  = 200000;

    hidden function _get(k, def) {
        try { var v = Application.Storage.getValue(k); if (v != null) { return v; } } catch (e) {}
        return def;
    }
    hidden function _set(k, v) { try { Application.Storage.setValue(k, v); } catch (e) {} }

    // Read a saved value as a clamped Number. A corrupt or legacy entry (wrong
    // type, negative, absurdly large) can never reach the game logic.
    hidden function _getNum(k, def, lo, hi) {
        var v = _get(k, def);
        if (v instanceof Lang.Float || v instanceof Lang.Double || v instanceof Lang.Long) {
            try { v = v.toNumber(); } catch (e) { return def; }
        }
        if (!(v instanceof Lang.Number)) { return def; }
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    hidden function _load() {
        started    = (_get("is_started", false) == true);
        bornSec    = _getNum("is_born", 0, 0, 2000000000);
        lastSec    = _getNum("is_last", 0, 0, 2000000000);
        population = _getNum("is_pop", 0, 0, POP_MAX);
        visitors   = _getNum("is_vis", 0, 0, VIS_MAX);
        streak     = _getNum("is_streak", 0, 0, 100000);
        lastDay    = _getNum("is_lday", 0, 0, 1000000);
        dailyDay   = _getNum("is_dday", 0, 0, 1000000);
        dUpgrades  = _getNum("is_dup", 0, 0, 100000);
        dExpl      = _getNum("is_dexp", 0, 0, 100000);
        dailyClaimed   = (_get("is_dclaim", false) == true);
        dailyCollected = (_get("is_dcol", false) == true);
        // Appended keys: a save written before them simply reads 0.
        dExpTry    = _getNum("is_dexpt", 0, 0, 100000);
        msDone     = _getNum("is_sms", 0, 0, 100000);
        discMask   = _getNum("is_disc", 0, 0, 0x7FFFFFFF);
        collMask   = _getNum("is_coll", 0, 0, 0x7FFFFFFF);
        pendingEvent = _getNum("is_pev", Is.EV_NONE, Is.EV_NONE, 4);

        res = new [Is.R_N];
        for (var i = 0; i < Is.R_N; i++) { res[i] = _getNum("is_r" + i, 0, 0, RES_MAX); }
        // Sized by B_N / AR_N: ids appended since the save was written simply
        // default to 0, so older saves load straight into the longer tables.
        bLevel = new [Is.B_N];
        for (var b = 0; b < Is.B_N; b++) { bLevel[b] = _getNum("is_b" + b, 0, 0, LVL_MAX); }
        arProg = new [Is.AR_N];
        for (var a = 0; a < Is.AR_N; a++) { arProg[a] = _getNum("is_ar" + a, 0, 0, 100); }

        log = [];
        var lg = _get("is_log", null);
        if (lg instanceof Lang.Array) {
            for (var j = 0; j < lg.size() && j < 8; j++) {
                if (lg[j] instanceof Lang.String) { log.add(lg[j]); }
            }
        }

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
        _set("is_dexpt", dExpTry);
        _set("is_sms", msDone);
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
                    "is_log", "is_lbday", "is_dexpt", "is_sms"];
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

    // ── Saturating arithmetic ────────────────────────────────────────────────
    hidden function _addRes(r, n) {
        if (n <= 0) { return; }
        var v = res[r] + n;
        if (v > RES_MAX || v < 0) { v = RES_MAX; }
        res[r] = v;
    }
    hidden function _addVis(n) {
        if (n <= 0) { return; }
        visitors += n;
        if (visitors > VIS_MAX || visitors < 0) { visitors = VIS_MAX; }
    }
    // Percentage multiply in 64-bit, saturated back into a safe Number. The
    // stacked pop/crystal/sky bonuses used to overflow at high island levels.
    hidden function _mulPct(v, pct) {
        if (v <= 0 || pct <= 0) { return 0; }
        var out = v.toLong() * pct / 100;
        if (out > RATE_MAX) { return RATE_MAX; }
        return out.toNumber();
    }

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
        if (l >= 600) { return "Cosmic Paradise"; }
        if (l >= 400) { return "Eternal Dominion"; }
        if (l >= 250) { return "Ascended Realm"; }
        if (l >= 175) { return "Divine Isles"; }
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
        var v = base;
        v = _mulPct(v, 100 + population * 2);
        v = _mulPct(v, 100 + bLevel[Is.B_CRYSTAL] * 10);
        v = _mulPct(v, 100 + bLevel[Is.B_SKY] * 15);
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
            else { streak = 1; msDone = 0; }   // broken streak re-arms the milestones
            lastDay = td;
        }
        if (streak < 1) { streak = 1; }
        if (dailyDay != td) {
            dailyDay = td; dUpgrades = 0; dExpl = 0; dExpTry = 0;
            dailyClaimed = false; dailyCollected = false;
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

        // Resource income (night bonus from sleep). Computed in 64-bit: rate can
        // reach eight figures late game and rate*elapsed overflows a Number.
        var nightPct = 100;
        if (newDay) { var sl = Sensors.getSleepData(); if (sl > 0) { nightPct = 110; } }
        for (var r = 0; r < Is.R_N; r++) {
            var rate = hourlyRate(r);
            if (rate <= 0) { continue; }
            var g = rate.toLong() * elapsed / 3600 * nightPct / 100;
            if (g > RES_MAX) { g = RES_MAX; }
            var gain = g.toNumber();
            if (gain > 0) { _addRes(r, gain); gRes[r] = gain; }
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
                if (tgt >= 0) { _advanceArea(tgt, steps * 100 / Is.stepsForArea(tgt)); }
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
            var v = 8 + _rand(20); _addVis(v); gEvent = e;
            _logAdd("Rare animal +" + v + " visitors");
            if (_rand(100) < 40) { _grantRandomCollectible(); }
        } else { // FESTIVAL
            var c = 150 + _rand(300); _addRes(Is.R_COIN, c); _addVis(10); gEvent = e;
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
                var c = 120 + _rand(280); _addRes(Is.R_COIN, c);
                msg = "Chest opened! +" + c + " coins"; _logAdd("Treasure +" + c + " coins");
                if (_rand(100) < 45) { var gi = _grantRandomCollectible(); if (gi >= 0) { msg = "Found " + Is.cName(gi) + "!"; } }
            } else { msg = "Left the chest."; }
        } else { // TRAVELER
            if (choice == 0) {
                if (res[Is.R_COIN] >= 100) {
                    res[Is.R_COIN] -= 100;
                    var gi2 = _grantRandomCollectible();
                    msg = (gi2 >= 0) ? ("Traded for " + Is.cName(gi2)) : "Traded for 20 wood";
                    if (gi2 < 0) { _addRes(Is.R_WOOD, 20); }
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
        if (bLevel[i] >= LVL_MAX) { return Is.bName(i) + " is maxed"; }
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
        if (i < 0 || i >= Is.AR_N || isDiscovered(i)) { return false; }
        if (incPct <= 0) { return false; }
        arProg[i] += incPct;
        if (arProg[i] >= 100) {
            arProg[i] = 100;
            discMask = discMask | (1 << i);
            dExpl += 1;
            _addRes(Is.R_COIN, 80);
            var b = Is.arUnlockBuilding(i);
            if (b >= 0) { _logAdd("Discovered " + Is.arName(i) + " -> " + Is.bName(b)); }
            else {
                var gc = Is.arGrantColl(i);
                _grantCollectible(gc);
                _logAdd("Discovered " + Is.arName(i) + " -> " + Is.cName(gc));
            }
            return true;
        }
        return false;
    }
    function explore(i) {
        if (i < 0 || i >= Is.AR_N) { return "Invalid area"; }
        if (isDiscovered(i)) { return Is.arName(i) + " already explored"; }
        var fee = Is.exploreCost(i);
        if (res[Is.R_COIN] < fee) { return "Need " + fee + " coins"; }
        res[Is.R_COIN] -= fee;
        dExpTry += 1;
        var step = Is.exploreStep(i, Sensors.getActivityMinutes() / 5);
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
    // Grant milestone decorations as the island level climbs. The late tiers
    // stretch the ladder far past the old level-100 finish line.
    hidden function _checkMilestoneCollectibles() {
        var l = islandLevel();
        if (l >= 10)  { _grantCollectible(0); }   // Palm Grove
        if (l >= 20)  { _grantCollectible(4); }   // Coral Reef
        if (l >= 35)  { _grantCollectible(3); }   // Golden Tree
        if (l >= 60)  { _grantCollectible(5); }   // Crystal Waterfall
        if (l >= 100) { _grantCollectible(8); }   // Rainbow Fountain
        if (l >= 150) { _grantCollectible(10); }  // Storm Bell
        if (l >= 220) { _grantCollectible(11); }  // Sunken Relic
        if (l >= 300) { _grantCollectible(12); }  // Sky Shard
        if (l >= 400) { _grantCollectible(13); }  // Titan Pearl
        if (l >= 550) { _grantCollectible(14); }  // Eternal Bloom
    }

    // ── Daily challenge ─────────────────────────────────────────────────────────
    // Seven varieties, derived from the day number so a week never repeats and
    // no new value has to be stored.
    function dailyId() { return dailyDay % Is.DAILY_N; }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Visit your island"; }
        if (id == 1) { return "Collect island income"; }
        if (id == 2) { return "Walk 3000 steps"; }
        if (id == 3) { return "Upgrade a building"; }
        if (id == 4) { return "Upgrade 3 buildings"; }
        if (id == 5) { return "Walk 6000 steps"; }
        return "Send out an expedition";
    }
    function dailyTarget() {
        var id = dailyId();
        if (id == 2) { return 3000; }
        if (id == 4) { return 3; }
        if (id == 5) { return 6000; }
        return 1;
    }
    function dailyProgress() {
        var id = dailyId();
        if (id == 0) { return 1; }                 // opening completes "visit"
        // A challenge must never be unwinnable, or one bad day silently ends a
        // long streak: a brand new island has no income to collect yet, and a
        // fully explored one has nowhere left to send an expedition.
        if (id == 1) { return (dailyCollected || hourlyRate(Is.R_COIN) <= 0) ? 1 : 0; }
        if (id == 2) { var s = Sensors.getStepsToday(); return (s > 3000) ? 3000 : s; }
        if (id == 3) { return dUpgrades > 0 ? 1 : 0; }
        if (id == 4) { return (dUpgrades > 3) ? 3 : dUpgrades; }
        if (id == 5) { var s6 = Sensors.getStepsToday(); return (s6 > 6000) ? 6000 : s6; }
        if (areasDiscovered() >= Is.AR_N) { return 1; }
        return dExpTry > 0 ? 1 : 0;
    }
    function dailyComplete() { return dailyProgress() >= dailyTarget(); }

    // ── Daily reward ───────────────────────────────────────────────────────────
    // The old flat +250/+80 stopped mattering within a week. The payout now
    // tracks island progress (level floor, or half an hour of real income —
    // whichever is larger) and compounds with the streak.
    function streakPct() {
        var s = streak - 1;
        if (s < 0) { s = 0; }
        var p = s * Is.DAILY_STREAK_PCT;
        if (p > Is.DAILY_STREAK_MAX) { p = Is.DAILY_STREAK_MAX; }
        return p;
    }
    hidden function _dailyBase(r, flat, perLevel) {
        var base = flat + islandLevel() * perLevel;
        var half = hourlyRate(r) / 2;
        if (half > base) { base = half; }
        return base;
    }
    function dailyCoinReward() {
        return _mulPct(_dailyBase(Is.R_COIN, Is.DAILY_COIN, 60), 100 + streakPct());
    }
    function dailyWoodReward() {
        return _mulPct(_dailyBase(Is.R_WOOD, Is.DAILY_WOOD, 20), 100 + streakPct());
    }
    function dailyRewardText() {
        return "+" + _short(dailyCoinReward()) + " Coins  +" + _short(dailyWoodReward()) + " Wood";
    }
    // Next unpaid streak milestone, or -1 once every tier is behind the player.
    function nextMilestoneDay() {
        for (var i = 0; i < Is.MS_N; i++) {
            if (Is.msDay(i) > msDone) { return Is.msDay(i); }
        }
        return -1;
    }
    function claimDaily() {
        if (dailyClaimed || !dailyComplete()) { return false; }
        dailyClaimed = true;
        _addRes(Is.R_COIN, dailyCoinReward());
        _addRes(Is.R_WOOD, dailyWoodReward());
        if (_rand(100) < 20) { _grantRandomCollectible(); }
        try { _payStreakMilestones(); } catch (e) {}
        save();
        return true;
    }
    // Lump-sum payouts as the streak crosses 3 / 7 / 14 / 30 days. msDone keeps
    // each tier to a single payout per unbroken run.
    hidden function _payStreakMilestones() {
        for (var i = 0; i < Is.MS_N; i++) {
            var d = Is.msDay(i);
            if (streak < d || msDone >= d) { continue; }
            msDone = d;
            var coin = _mulPct(_dailyBase(Is.R_COIN, Is.DAILY_COIN, 60), d * 30);
            var stone = d * 12 + islandLevel() * 4;
            _addRes(Is.R_COIN, coin);
            _addRes(Is.R_STONE, stone);
            var extra = "";
            if (Is.msGrantsColl(i)) {
                var gi = _grantRandomCollectible();
                if (gi >= 0) { extra = " + " + Is.cName(gi); }
            }
            _logAdd(d + "-day streak +" + _short(coin) + " coins" + extra);
        }
    }

    // ── Idle storage ───────────────────────────────────────────────────────────
    // How full the 24h idle store was when the player walked back in. 100% means
    // production was being thrown away, which is the nudge to return sooner.
    function offlineCapHours() { return Is.OFFLINE_CAP / 3600; }
    function offlineFillPct() {
        var p = gSecs * 100 / Is.OFFLINE_CAP;
        return Is._c(p, 0, 100);
    }
    function offlineGapHours() { return gSecs / 3600; }

    // Compact number text for reward strings (the view has its own _fmt).
    hidden function _short(n) {
        if (n < 0) { n = 0; }
        if (n >= 1000000) { return (n / 1000000) + "." + ((n / 100000) % 10) + "M"; }
        if (n >= 10000)   { return (n / 1000) + "k"; }
        if (n >= 1000)    { return (n / 1000) + "." + ((n / 100) % 10) + "k"; }
        return "" + n;
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
        _addRes(Is.R_COIN,  600);
        _addRes(Is.R_WOOD,  300);
        _addRes(Is.R_STONE, 180);
        _addRes(Is.R_FOOD,  140);
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
