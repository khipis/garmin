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
    var dTrips;           // scouting trips run today
    var dCatMask;         // categories upgraded today (bit per Fa.bCat)
    var mileDone;         // streak milestones already paid on this streak
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

    // Every loaded value is type-checked and clamped: a corrupt or legacy key
    // must never become a bad array index, an unbounded loop count, or a
    // non-number that throws the moment we do arithmetic on it.
    hidden function _num(k, def, lo, hi) {
        var v = _get(k, def);
        if (!(v instanceof Lang.Number)) { return def; }
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }
    hidden function _bool(k) {
        var v = _get(k, false);
        if (v instanceof Lang.Boolean) { return v; }
        if (v instanceof Lang.Number) { return v != 0; }
        return false;
    }

    hidden function _load() {
        started    = _bool("fa_started");
        bornSec    = _num("fa_born", 0, 0, 2000000000);
        lastSec    = _num("fa_last", 0, 0, 2000000000);
        population = _num("fa_pop", 0, 0, 9999999);
        visitors   = _num("fa_vis", 0, 0, 9999999);
        streak     = _num("fa_streak", 0, 0, 999999);
        lastDay    = _num("fa_lday", 0, 0, 9999999);
        dailyDay   = _num("fa_dday", 0, 0, 9999999);
        dUpgrades  = _num("fa_dup", 0, 0, 999999);
        dExpl      = _num("fa_dexp", 0, 0, 999999);
        dailyClaimed   = _bool("fa_dclaim");
        dailyCollected = _bool("fa_dcol");
        dTrips     = _num("fa_dtrip", 0, 0, 999999);
        dCatMask   = _num("fa_dcat", 0, 0, 15);
        mileDone   = _num("fa_dmile", 0, 0, Fa.MILE_N);
        discMask   = _num("fa_disc", 0, 0, 0x7FFFFFFF);
        collMask   = _num("fa_coll", 0, 0, 0x7FFFFFFF);
        pendingEvent = _num("fa_pev", Fa.EV_NONE, Fa.EV_NONE, Fa.EV_TRAVELER);

        res = new [Fa.R_N];
        for (var i = 0; i < Fa.R_N; i++) { res[i] = _num("fa_r" + i, 0, 0, 2000000000); }
        // New building/area slots simply aren't in old saves, so they load as 0.
        bLevel = new [Fa.B_N];
        for (var b = 0; b < Fa.B_N; b++) { bLevel[b] = _num("fa_b" + b, 0, 0, Fa.LVL_MAX); }
        arProg = new [Fa.AR_N];
        for (var a = 0; a < Fa.AR_N; a++) { arProg[a] = _num("fa_ar" + a, 0, 0, 100); }

        log = [];
        var lg = _get("fa_log", null);
        if (lg instanceof Lang.Array) {
            for (var j = 0; j < lg.size() && j < 8; j++) {
                if (lg[j] instanceof Lang.String) { log.add(lg[j]); }
            }
        }

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
        _set("fa_dtrip", dTrips);
        _set("fa_dcat", dCatMask);
        _set("fa_dmile", mileDone);
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
                    "fa_log", "fa_lbday", "fa_dtrip", "fa_dcat", "fa_dmile"];
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
    // Feed eaten by each new animal — a bigger herd is hungrier, so feed crops
    // stay worth building all the way through the late game.
    function feedPerAnimal() {
        var f = Fa.FEED_PER_ANIMAL + population / 20;
        if (f < 1) { f = 1; }
        return f;
    }

    // ── Barn (offline) capacity ───────────────────────────────────────────────
    // Idle production only banks for OFFLINE_CAP seconds. These read off the
    // last collection so the player can see when they left income on the table.
    function barnHours() { return Fa.OFFLINE_CAP / 3600; }
    function barnPct() {
        if (Fa.OFFLINE_CAP <= 0) { return 100; }
        var s = gSecs; if (s < 0) { s = 0; }
        var p = s * 100 / Fa.OFFLINE_CAP;
        return (p > 100) ? 100 : p;
    }
    function barnFull() { return gSecs >= Fa.OFFLINE_CAP; }
    function barnText() {
        if (barnFull()) { return "Barn was FULL!"; }
        return "Barn " + barnPct() + "% of " + barnHours() + "h";
    }

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
    // Category sums walk the whole table so appended structures count too.
    function catLevels(cat) {
        var s = 0;
        for (var i = 0; i < Fa.B_N; i++) { if (Fa.bCat(i) == cat) { s += bLevel[i]; } }
        return s;
    }
    function cropLevels() { return catLevels(1); }
    function specialLevels() { return catLevels(3); }
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
        if (l >= 600) { return "Eternal Harvest"; }
        if (l >= 400) { return "Mythic Homestead"; }
        if (l >= 250) { return "Moonlit Estate"; }
        if (l >= 175) { return "Storybook Manor"; }
        if (l >= 100) { return "Legendary Ranch"; }
        if (l >= 50)  { return "Prize Ranch"; }
        if (l >= 25)  { return "Busy Farmstead"; }
        if (l >= 10)  { return "Growing Farm"; }
        return "New Paddock";
    }

    // Which crowd the farm draws — livestock pulls families, crops pull
    // farmers, the market pulls foodies and the landmarks pull tourists.
    function guestTypeIndex() {
        var s = [0, 0, 0, 0];
        for (var i = 0; i < Fa.B_N; i++) {
            var w = bLevel[i] * Fa.bAttract(i);
            if (w <= 0) { continue; }
            var c = Fa.bCat(i);
            if (c == 0)      { s[1] += w; }
            else if (c == 1) { s[3] += w; }
            else if (c == 2) { s[2] += w; }
            else             { s[0] += w; }
        }
        var best = 0;
        for (var k = 1; k < 4; k++) { if (s[k] > s[best]) { best = k; } }
        return best;
    }
    function guestTypeName() { return Fa.visitorType(guestTypeIndex()); }

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
        var moonPct    = 100 + bLevel[Fa.B_HARVMOON] * 25;
        var v = base;
        v = _mul(v, popPct);
        v = _mul(v, greenPct);
        v = _mul(v, siloPct);
        v = _mul(v, moonPct);
        return v;
    }
    // Percentage multiply in 64-bit, clamped back into a Number. In plain 32-bit
    // maths a deep-late-game farm can wrap negative and drain resources.
    hidden function _mul(v, pct) {
        if (v <= 0 || pct <= 0) { return 0; }
        var r = v.toLong() * pct.toLong() / 100l;
        if (r > 1000000000l) { return 1000000000; }
        return r.toNumber();
    }
    // Add to a resource pool without ever wrapping negative. Returns the amount
    // actually banked.
    hidden function _addRes(r, amt) {
        if (r < 0 || r >= Fa.R_N || amt == null || amt <= 0) { return 0; }
        var before = res[r];
        var v = before + amt;
        if (v < 0 || v > Fa.RES_MAX) { v = Fa.RES_MAX; }
        res[r] = v;
        return v - before;
    }

    // ── Offline collection + daily rollover ──────────────────────────────────
    function collectOffline() {
        var now = nowSec();
        gRes = [0, 0, 0, 0]; gSecs = 0; gPop = 0; gVis = 0; newDay = false; gEvent = Fa.EV_NONE;

        var td = today();
        if (td != lastDay) {
            newDay = true;
            if (lastDay != 0 && td == lastDay + 1) { streak += 1; }
            // A broken streak also forfeits the milestone payouts it had banked.
            else { streak = 1; mileDone = 0; }
            lastDay = td;
        }
        if (streak < 1) { streak = 1; }
        if (dailyDay != td) {
            dailyDay = td; dUpgrades = 0; dExpl = 0; dailyClaimed = false; dailyCollected = false;
            dTrips = 0; dCatMask = 0;
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

        // Resource income (night bonus from sleep). 64-bit intermediate: hours of
        // idle time on a huge farm overflows a 32-bit product.
        var nightPct = 100;
        if (newDay) { var sl = Sensors.getSleepData(); if (sl > 0) { nightPct = 110; } }
        for (var r = 0; r < Fa.R_N; r++) {
            var g = hourlyRate(r).toLong() * elapsed.toLong() / 3600l;
            g = g * nightPct.toLong() / 100l;
            if (g > Fa.RES_MAX.toLong()) { g = Fa.RES_MAX.toLong(); }
            if (g > 0) { gRes[r] = _addRes(r, g.toNumber()); }
        }
        var any = false;
        for (var k = 0; k < Fa.R_N; k++) { if (gRes[k] > 0) { any = true; } }
        if (any) { dailyCollected = true; }

        // Animal growth — each new animal eats feed, so the feed economy keeps
        // mattering. No feed simply pauses growth (never a hard lock: the daily
        // reward and the feed crops always bring it back).
        var pcap = popCap();
        if (population < pcap && res[Fa.R_FEED] > 0) {
            var add = elapsed / Fa.POP_INTERVAL;
            if (add > 0) {
                var room = pcap - population;
                if (add > room) { add = room; }
                var per = feedPerAnimal();
                var afford = res[Fa.R_FEED] / per;
                if (add > afford) { add = afford; }
                if (add > 0) {
                    res[Fa.R_FEED] -= add * per;
                    if (res[Fa.R_FEED] < 0) { res[Fa.R_FEED] = 0; }
                    population += add;
                    gPop = add;
                }
            }
        }

        // Steps auto-advance the current expedition (once per new day). Later
        // areas need many more steps, so this takes several days each.
        if (newDay) {
            var steps = Sensors.getStepsToday();
            if (steps > 0) { _advanceChain(steps); }
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
            var c = 150 + _rand(300); _addRes(Fa.R_COIN, c); visitors += 10; gEvent = e;
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
                var c = 120 + _rand(280); _addRes(Fa.R_COIN, c);
                msg = "Crate opened! +" + c + " coins"; _logAdd("Lucky crate +" + c + " coins");
                if (_rand(100) < 45) { var gi = _grantRandomCollectible(); if (gi >= 0) { msg = "Found " + Fa.cName(gi) + "!"; } }
            } else { msg = "Left the crate."; }
        } else { // TRAVELER
            if (choice == 0) {
                if (res[Fa.R_COIN] >= 100) {
                    res[Fa.R_COIN] -= 100;
                    var gi2 = _grantRandomCollectible();
                    msg = (gi2 >= 0) ? ("Traded for " + Fa.cName(gi2)) : "Traded for 20 wood";
                    if (gi2 < 0) { _addRes(Fa.R_WOOD, 20); }
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
        if (bLevel[i] >= Fa.LVL_MAX) { return Fa.bName(i) + " is maxed"; }
        var cost = upgradeCost(i);
        if (!canAfford(cost)) { return "Need more resources"; }
        res[Fa.R_COIN] -= cost[0]; res[Fa.R_WOOD] -= cost[1]; res[Fa.R_GRAIN] -= cost[2];
        var wasNew = (bLevel[i] == 0);
        bLevel[i] += 1;
        dUpgrades += 1;
        dCatMask = dCatMask | (1 << Fa._c(Fa.bCat(i), 0, 3));
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
        if (i < 0 || i >= Fa.AR_N || isDiscovered(i)) { return false; }
        if (incPct == null || incPct <= 0) { return false; }
        arProg[i] += incPct;
        if (arProg[i] >= 100) {
            arProg[i] = 100;
            discMask = discMask | (1 << i);
            dExpl += 1;
            _addRes(Fa.R_COIN, 80);
            var b = Fa.arUnlockBuilding(i);
            var g = Fa.arGrantColl(i);
            if (b >= 0) { _logAdd("Explored " + Fa.arName(i) + " -> " + Fa.bName(b)); }
            else if (g >= 0) { _grantCollectible(g); _logAdd("Explored " + Fa.arName(i) + " -> " + Fa.cName(g)); }
            else { _logAdd("Explored " + Fa.arName(i)); }
            return true;
        }
        return false;
    }
    // Spend a step budget across successive areas so a big walking day never
    // stops dead the moment one expedition finishes.
    hidden function _advanceChain(steps) {
        if (steps == null || steps <= 0) { return; }
        for (var guard = 0; guard < Fa.AR_N; guard++) {
            var tgt = _nextArea();
            if (tgt < 0) { return; }
            var left = 100 - arProg[tgt];
            if (left < 1) { left = 1; }
            var need = Fa.stepsForArea(tgt) * left / 100;
            if (need < 1) { need = 1; }
            if (steps < need) { _advanceArea(tgt, Fa.pctForSteps(tgt, steps)); return; }
            steps -= need;
            _advanceArea(tgt, 100);
        }
    }
    function explore(i) {
        if (i < 0 || i >= Fa.AR_N) { return "Invalid area"; }
        if (isDiscovered(i)) { return Fa.arName(i) + " already explored"; }
        var cost = Fa.exploreCost(i);
        if (res[Fa.R_COIN] < cost) { return "Need " + cost + " coins"; }
        res[Fa.R_COIN] -= cost;
        dTrips += 1;
        // A trip covers a fixed amount of ground, so the bigger late areas need
        // many more of them.
        var step = Fa.pctForSteps(i, Fa.EXPLORE_TRIP_STEPS + Sensors.getActivityMinutes() * 50);
        if (step < 1) { step = 1; }
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
        if (l >= 10)  { _grantCollectible(0); }    // Flower Bed
        if (l >= 20)  { _grantCollectible(4); }    // Pond Ducks
        if (l >= 35)  { _grantCollectible(3); }    // Golden Egg
        if (l >= 60)  { _grantCollectible(5); }    // Rainbow Cow
        if (l >= 100) { _grantCollectible(8); }    // Harvest Feast
        if (l >= 150) { _grantCollectible(9); }    // Bee Hive
        if (l >= 220) { _grantCollectible(10); }   // Stone Bridge
        if (l >= 300) { _grantCollectible(12); }   // Sun Crown
        if (l >= 400) { _grantCollectible(13); }   // Moon Cart
        if (l >= 550) { _grantCollectible(14); }   // Golden Plow
    }

    // ── Daily challenge ─────────────────────────────────────────────────────────
    // Eight varieties on a day-number rotation, so a calendar week never repeats
    // the same task twice.
    function dailyId() { return Fa._c(dailyDay % Fa.DAILY_N, 0, Fa.DAILY_N - 1); }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Visit your farm"; }
        if (id == 1) { return "Collect farm income"; }
        if (id == 2) { return "Walk 3000 steps"; }
        if (id == 3) { return "Upgrade a structure"; }
        if (id == 4) { return "Upgrade twice today"; }
        if (id == 5) { return "Run 2 scouting trips"; }
        if (id == 6) { return "Host " + guestTarget() + " guests"; }
        return "Build in the CROPS row";
    }
    // The guest goal tracks the farm so it stays a stretch without ever being
    // impossible: it can never exceed the attraction the farm actually has.
    function guestTarget() {
        var t = 10 + farmLevel() * 2;
        var cap = visitorsCap();
        if (t > cap) { t = cap; }
        if (t < 5) { t = 5; }
        return t;
    }
    function dailyTarget() {
        var id = dailyId();
        if (id == 2) { return 3000; }
        if (id == 4) { return 2; }
        if (id == 5) { return 2; }
        if (id == 6) { return guestTarget(); }
        return 1;
    }
    function dailyProgress() {
        var id = dailyId();
        if (id == 0) { return 1; }                 // opening completes "visit"
        if (id == 1) { return dailyCollected ? 1 : 0; }
        if (id == 2) { var s = Sensors.getStepsToday(); return (s > 3000) ? 3000 : s; }
        if (id == 3) { return dUpgrades > 0 ? 1 : 0; }
        if (id == 4) { return (dUpgrades > 2) ? 2 : dUpgrades; }
        if (id == 5) { return (dTrips > 2) ? 2 : dTrips; }
        if (id == 6) { var t = guestTarget(); return (visitors > t) ? t : visitors; }
        return ((dCatMask & (1 << 1)) != 0) ? 1 : 0;
    }
    function dailyComplete() { return dailyProgress() >= dailyTarget(); }

    // ── Daily reward ──────────────────────────────────────────────────────────
    // Streak multiplier: +10% per consecutive day, capped at +100%.
    function streakPct() {
        var p = 100 + (streak - 1) * Fa.STREAK_STEP_PCT;
        if (p < 100) { p = 100; }
        if (p > Fa.STREAK_MAX_PCT) { p = Fa.STREAK_MAX_PCT; }
        return p;
    }
    // Base bundle before the streak bonus: a floor plus farm level plus half an
    // hour of the farm's own output, so it stays worth claiming late.
    hidden function _dailyBase(r) {
        var floorAmt; var perLvl;
        if (r == Fa.R_COIN)      { floorAmt = Fa.DAILY_BASE_COIN; perLvl = 40; }
        else if (r == Fa.R_WOOD) { floorAmt = Fa.DAILY_BASE_WOOD; perLvl = 12; }
        else                     { floorAmt = Fa.DAILY_BASE_FEED; perLvl = 5;  }
        var v = floorAmt.toLong() + farmLevel().toLong() * perLvl + hourlyRate(r).toLong() / 2l;
        if (v > Fa.RES_MAX.toLong()) { v = Fa.RES_MAX.toLong(); }
        return v.toNumber();
    }
    // Final payout -> [coins, wood, feed], streak multiplier already applied.
    function dailyReward() {
        var out = [0, 0, 0];
        var rs = [Fa.R_COIN, Fa.R_WOOD, Fa.R_FEED];
        var pct = streakPct().toLong();
        for (var i = 0; i < 3; i++) {
            var v = _dailyBase(rs[i]).toLong() * pct / 100l;
            if (v > Fa.RES_MAX.toLong()) { v = Fa.RES_MAX.toLong(); }
            out[i] = v.toNumber();
        }
        return out;
    }
    // Always includes feed so an empty-larder farm can restart herd growth.
    function dailyRewardText() {
        var r = dailyReward();
        return "+" + r[0] + "c +" + r[1] + "w +" + r[2] + "f";
    }
    // Next unpaid streak milestone, or -1 once they are all banked.
    function nextMilestone() {
        return (mileDone >= Fa.MILE_N) ? -1 : Fa._c(mileDone, 0, Fa.MILE_N - 1);
    }
    function milestoneText() {
        var i = nextMilestone();
        if (i < 0) { return "All streak rewards earned"; }
        var d = Fa.mileDay(i) - streak;
        if (d < 0) { d = 0; }
        return (d == 0) ? ("Day " + Fa.mileDay(i) + " bonus ready")
                        : (d + "d to the day " + Fa.mileDay(i) + " bonus");
    }
    function claimDaily() {
        if (dailyClaimed || !dailyComplete()) { return false; }
        dailyClaimed = true;
        var r = dailyReward();
        _addRes(Fa.R_COIN, r[0]); _addRes(Fa.R_WOOD, r[1]); _addRes(Fa.R_FEED, r[2]);
        if (_rand(100) < 20) { _grantRandomCollectible(); }
        _payMilestones(r);
        save();
        return true;
    }
    // Streak milestones at 3 / 7 / 14 / 30 days: one-off bundles on top of the
    // daily, with a guaranteed charm at 7 and 30.
    hidden function _payMilestones(base) {
        for (var i = mileDone; i < Fa.MILE_N; i++) {
            if (streak < Fa.mileDay(i)) { return; }
            var mult = Fa.mileMult(i);
            _addRes(Fa.R_COIN, _capMul(base[0], mult));
            _addRes(Fa.R_WOOD, _capMul(base[1], mult));
            _addRes(Fa.R_FEED, _capMul(base[2], mult));
            if (Fa.mileCharm(i)) { _grantRandomCollectible(); }
            mileDone = i + 1;
            _logAdd("Streak " + Fa.mileDay(i) + " days - bonus x" + mult);
        }
    }
    hidden function _capMul(v, mult) {
        var r = v.toLong() * mult.toLong();
        if (r > Fa.RES_MAX.toLong()) { r = Fa.RES_MAX.toLong(); }
        return r.toNumber();
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
        _addRes(Fa.R_COIN,  600);
        _addRes(Fa.R_WOOD,  300);
        _addRes(Fa.R_GRAIN, 180);
        _addRes(Fa.R_FEED,  140);
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
        var best = -1; var bestCost = 0l;
        for (var i = 0; i < Fa.B_N; i++) {
            if (!isUnlocked(i)) { continue; }
            var c = upgradeCost(i);
            if (!canAfford(c)) { continue; }
            // 64-bit: three capped costs summed in 32 bits can wrap negative.
            var tot = c[0].toLong() + c[1].toLong() + c[2].toLong();
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
