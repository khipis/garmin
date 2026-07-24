// ═══════════════════════════════════════════════════════════════════════════
// MineModel.mc — All BITOCHI MINES game state + logic.
//
// One class owns everything: save/load, idle mining (resources AND depth accrue
// offline), the underground base (7 buildings), equipment (pickaxe & cart
// tiers), the manual DIG action, depth-threshold discoveries, the rarity
// collection, random events, daily challenges, streaks, milestones and the five
// leaderboard scores. The view/delegate only read fields and call actions.
// Every Storage access is guarded so nothing here can throw into the UI.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Math;

class MineModel {
    var started;
    var bornSec; var lastSec;
    var res;              // [4] Stone, Iron, Gold, Gems
    var depth;            // meters
    var bLevel;           // [7] building levels
    var pickTier; var cartTier;
    var discMask;         // discovered depth-marks bitmask
    var collMask;         // owned collectibles bitmask
    var mileMask;         // achieved milestones bitmask

    var streak; var lastDay;
    var dailyDay; var dUpgrades; var dDepthStart; var dGained; var dailyClaimed; var dailyCollected;
    var log;
    var pendingEvent;

    // Idle summary (WELCOME BACK)
    var gRes; var gDepth; var gSecs; var newDay; var gEvent;

    function initialize() { _load(); }

    // ── Storage ───────────────────────────────────────────────────────────────
    hidden function _get(k, def) {
        try { var v = Application.Storage.getValue(k); if (v != null) { return v; } } catch (e) {}
        return def;
    }
    hidden function _set(k, v) { try { Application.Storage.setValue(k, v); } catch (e) {} }

    hidden function _load() {
        started    = _get("mn_started", false);
        bornSec    = _get("mn_born", 0);
        lastSec    = _get("mn_last", 0);
        depth      = _get("mn_depth", 12);
        pickTier   = _get("mn_pick", 0);
        cartTier   = _get("mn_cart", 0);
        streak     = _get("mn_streak", 0);
        lastDay    = _get("mn_lday", 0);
        dailyDay   = _get("mn_dday", 0);
        dUpgrades  = _get("mn_dup", 0);
        dDepthStart= _get("mn_dds", 12);
        dGained    = _get("mn_dg", 0);
        dailyClaimed   = _get("mn_dclaim", false);
        dailyCollected = _get("mn_dcol", false);
        discMask   = _get("mn_disc", 0);
        collMask   = _get("mn_coll", 0);
        mileMask   = _get("mn_mile", 0);
        pendingEvent = _get("mn_pev", Mn.EV_NONE);

        res = new [Mn.R_N];
        for (var i = 0; i < Mn.R_N; i++) { res[i] = _get("mn_r" + i, 0); }
        bLevel = new [Mn.B_N];
        for (var b = 0; b < Mn.B_N; b++) { bLevel[b] = _get("mn_b" + b, 0); }

        var lg = _get("mn_log", null);
        log = (lg instanceof Lang.Array) ? lg : [];

        gRes = [0, 0, 0, 0]; gDepth = 0; gSecs = 0; newDay = false; gEvent = Mn.EV_NONE;
    }

    function save() {
        _set("mn_started", started);
        _set("mn_born", bornSec);
        _set("mn_last", lastSec);
        _set("mn_depth", depth);
        _set("mn_pick", pickTier);
        _set("mn_cart", cartTier);
        _set("mn_streak", streak);
        _set("mn_lday", lastDay);
        _set("mn_dday", dailyDay);
        _set("mn_dup", dUpgrades);
        _set("mn_dds", dDepthStart);
        _set("mn_dg", dGained);
        _set("mn_dclaim", dailyClaimed);
        _set("mn_dcol", dailyCollected);
        _set("mn_disc", discMask);
        _set("mn_coll", collMask);
        _set("mn_mile", mileMask);
        _set("mn_pev", pendingEvent);
        for (var i = 0; i < Mn.R_N; i++) { _set("mn_r" + i, res[i]); }
        for (var b = 0; b < Mn.B_N; b++) { _set("mn_b" + b, bLevel[b]); }
        _set("mn_log", log);
    }

    // ── Full reset (OPTIONS → Reset mine) ─────────────────────────────────────
    // Wipes every progress key back to zero, keeping the player's settings
    // (sound/haptics, demo mode, first-run tip). Fully guarded.
    function resetAll() {
        var keys = ["mn_started", "mn_born", "mn_last", "mn_depth", "mn_pick",
                    "mn_cart", "mn_streak", "mn_lday", "mn_dday", "mn_dup",
                    "mn_dds", "mn_dg", "mn_dclaim", "mn_dcol", "mn_disc",
                    "mn_coll", "mn_mile", "mn_pev", "mn_log", "mn_lbday"];
        for (var i = 0; i < keys.size(); i++) { try { Application.Storage.deleteValue(keys[i]); } catch (e) {} }
        for (var r = 0; r < Mn.R_N; r++) { try { Application.Storage.deleteValue("mn_r" + r); } catch (e) {} }
        for (var b = 0; b < Mn.B_N; b++) { try { Application.Storage.deleteValue("mn_b" + b); } catch (e) {} }
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
        depth = 12;
        res[Mn.R_STONE] = 100; res[Mn.R_IRON] = 0; res[Mn.R_GOLD] = 0; res[Mn.R_GEM] = 0;
        pickTier = 0; cartTier = 0;
        lastDay = today(); dailyDay = today(); streak = 1; dDepthStart = depth;
        _logAdd("BITOCHI MINE #001 opened");
        save();
    }

    // ── Derived ─────────────────────────────────────────────────────────────
    function workers() { return 1 + bLevel[Mn.B_CAMP] * 2; }
    function zone() { return Mn.zoneOf(depth); }
    function daysAlive() {
        if (bornSec == 0) { return 0; }
        var d = (nowSec() - bornSec) / 86400;
        return (d < 0) ? 0 : d;
    }
    function ageDayLabel() { return "Day " + (daysAlive() + 1); }

    hidden function _labPct() { return 100 + bLevel[Mn.B_LAB] * 12; }

    function miningPowerPct() {
        var v = Mn.pickPowerPct(pickTier);
        v = v * Mn.cartMultPct(cartTier) / 100;
        v = v * (100 + bLevel[Mn.B_FORGE] * 15) / 100;
        v = v * (100 + (workers() - 1) * Mn.WORKER_BONUS) / 100;
        v = v * _labPct() / 100;
        return v;
    }
    function digRate() {   // meters per hour
        var v = Mn.DIG_BASE + bLevel[Mn.B_SHAFT] * 4;
        v = v * (100 + bLevel[Mn.B_ELEVATOR] * 15) / 100;
        v = v * (100 + (workers() - 1) * Mn.WORKER_BONUS) / 100;
        v = v * Mn.pickPowerPct(pickTier) / 100;
        v = v * _labPct() / 100;
        return v;
    }

    function hourlyRate(r) {
        var z = zone();
        var w = Mn.zWeight(z, r);
        if (w == 0) { return 0; }
        var sumw = 0;
        for (var k = 0; k < Mn.R_N; k++) { sumw += Mn.zWeight(z, k); }
        if (sumw == 0) { return 0; }
        var total = Mn.ORE_BASE * miningPowerPct() / 100;
        var rate = total * w / sumw;
        if (r == Mn.R_GEM) { rate = rate * (100 + bLevel[Mn.B_GEMWS] * 20) / 100; }
        return rate;
    }

    function isDiscovered(i) { return (discMask & (1 << i)) != 0; }
    function discoveries() {
        var c = 0;
        for (var i = 0; i < Mn.D_N; i++) { if (isDiscovered(i)) { c++; } }
        return c;
    }
    function hasColl(i) { return (collMask & (1 << i)) != 0; }
    function collectiblesOwned() {
        var c = 0;
        for (var i = 0; i < Mn.C_N; i++) { if (hasColl(i)) { c++; } }
        return c;
    }
    function legendaryFinds() {
        var c = 0;
        for (var i = 0; i < Mn.C_N; i++) { if (hasColl(i) && Mn.cLegendary(i)) { c++; } }
        return c;
    }
    function collectionScore() {
        var s = 0;
        for (var i = 0; i < Mn.C_N; i++) { if (hasColl(i)) { s += Mn.cWeight(i); } }
        return s;
    }
    function richest() {
        var s = 0;
        for (var i = 0; i < Mn.R_N; i++) { s += res[i] * Mn.resValue(i); }
        return s;
    }
    function totalBuildingLevels() {
        var s = 0;
        for (var i = 0; i < Mn.B_N; i++) { s += bLevel[i]; }
        return s;
    }
    function mineLevel() {
        var score = totalBuildingLevels() * 2 + pickTier * 4 + cartTier * 3
                  + collectiblesOwned() * 2 + depth / 25 + zone() * 3;
        return 1 + score / 8;
    }

    // ── Offline collection + daily rollover ──────────────────────────────────
    function collectOffline() {
        var now = nowSec();
        gRes = [0, 0, 0, 0]; gDepth = 0; gSecs = 0; newDay = false; gEvent = Mn.EV_NONE;

        var td = today();
        if (td != lastDay) {
            newDay = true;
            if (lastDay != 0 && td == lastDay + 1) { streak += 1; }
            else { streak = 1; }
            lastDay = td;
        }
        if (streak < 1) { streak = 1; }
        if (dailyDay != td) {
            dailyDay = td; dUpgrades = 0; dailyClaimed = false; dailyCollected = false;
            dDepthStart = depth; dGained = 0;
        }

        var elapsed = now - lastSec;
        if (elapsed < 0) { elapsed = 0; }
        if (elapsed > Mn.OFFLINE_CAP) { elapsed = Mn.OFFLINE_CAP; }
        gSecs = elapsed;

        var nightPct = 100;
        if (newDay) { var sl = Sensors.getSleepData(); if (sl > 0) { nightPct = 112; } }

        // Resources.
        for (var r = 0; r < Mn.R_N; r++) {
            var gain = hourlyRate(r) * elapsed / 3600;
            gain = gain * nightPct / 100;
            if (gain > 0) { res[r] += gain; gRes[r] = gain; dGained += gain; }
        }
        var any = false;
        for (var k = 0; k < Mn.R_N; k++) { if (gRes[k] > 0) { any = true; } }
        if (any) { dailyCollected = true; }

        // Depth.
        var dg = digRate() * elapsed / 3600;
        dg = dg * nightPct / 100;

        // Steps expedition bonus (once per new day).
        if (newDay) {
            var steps = Sensors.getStepsToday();
            if (steps > 0) {
                dg += steps / 100;                       // bonus depth
                if (steps >= 10000) { res[Mn.R_GOLD] += 30; gRes[Mn.R_GOLD] += 30; }
                if (steps >= 5000 && _rand(100) < 60) { _grantRandomCollectible(); }
            }
        }
        if (dg > 0) { depth += dg; gDepth = dg; }

        _checkDiscoveries();
        _checkMilestones();

        if (elapsed > 2 * 3600 && pendingEvent == Mn.EV_NONE) {
            if (_rand(100) < 45) { _rollEvent(); }
        }

        lastSec = now;
        save();
    }

    hidden function _rollEvent() {
        var e = _rand(5);
        if (Mn.evHasChoice(e)) { pendingEvent = e; return; }
        if (e == Mn.EV_CAVE) {
            var s = 100 + _rand(300); res[Mn.R_STONE] += s; res[Mn.R_IRON] += s / 5; gEvent = e;
            _logAdd("Hidden cave +" + s + " stone");
        } else if (e == Mn.EV_VEIN) {
            var g = 20 + _rand(60); res[Mn.R_GOLD] += g; res[Mn.R_GEM] += 1 + _rand(4); gEvent = e;
            _logAdd("Mineral vein +" + g + " gold");
        } else { // MACHINE
            gEvent = e;
            var gi = _grantRandomCollectible();
            _logAdd(gi >= 0 ? ("Machine yielded " + Mn.cName(gi)) : "Ancient machine humming");
        }
    }

    // choice: 0 = explore/fight, 1 = ignore/flee
    function resolveEvent(choice) {
        var e = pendingEvent;
        if (e == Mn.EV_NONE) { return ""; }
        pendingEvent = Mn.EV_NONE;
        var msg = "";
        if (e == Mn.EV_QUAKE) {
            if (choice == 0) {
                var d = 20 + _rand(60); depth += d; _checkDiscoveries();
                msg = "New tunnel! +" + d + "m depth"; _logAdd("Earthquake tunnel +" + d + "m");
            } else { msg = "Tunnel sealed off."; }
        } else { // CREATURE
            if (choice == 0) {
                if (_rand(100) < 60) {
                    var gi = _grantRandomCollectible();
                    msg = (gi >= 0) ? ("Defeated it! Found " + Mn.cName(gi)) : "Fought it off. +50 gems";
                    if (gi < 0) { res[Mn.R_GEM] += 50; }
                    _logAdd("Creature defeated");
                } else {
                    var l = 40 + _rand(80); res[Mn.R_IRON] -= l; if (res[Mn.R_IRON] < 0) { res[Mn.R_IRON] = 0; }
                    msg = "It raided the cart. -" + l + " iron"; _logAdd("Creature raid -" + l + " iron");
                }
            } else { msg = "Miners retreated."; }
        }
        _checkMilestones();
        save();
        return msg;
    }

    // ── Discoveries ─────────────────────────────────────────────────────────────
    hidden function _checkDiscoveries() {
        for (var i = 0; i < Mn.D_N; i++) {
            if (!isDiscovered(i) && depth >= Mn.dDepth(i)) {
                discMask = discMask | (1 << i);
                res[Mn.R_GOLD] += 40 + i * 20;
                _grantCollectible(Mn.dColl(i));
                _logAdd("Depth " + Mn.dDepth(i) + "m - " + Mn.dName(i));
            }
        }
    }
    // Returns the most recent freshly-crossed discovery name for popups, or null.
    function lastDiscoveryName() {
        for (var i = Mn.D_N - 1; i >= 0; i--) {
            if (isDiscovered(i) && depth >= Mn.dDepth(i) && depth < Mn.dDepth(i) + 30) { return Mn.dName(i); }
        }
        return null;
    }

    // ── Manual dig ──────────────────────────────────────────────────────────────
    function dig() {
        var add = 2 + pickTier + bLevel[Mn.B_SHAFT];
        var before = discoveries();
        depth += add;
        // small ore reward by zone.
        var z = zone();
        var sumw = 0;
        for (var k = 0; k < Mn.R_N; k++) { sumw += Mn.zWeight(z, k); }
        if (sumw > 0) {
            for (var r = 0; r < Mn.R_N; r++) {
                var g = Mn.zWeight(z, r) * (2 + pickTier) / sumw + (r == Mn.R_STONE ? 1 : 0);
                if (g > 0) { res[r] += g; dGained += g; }
            }
        }
        // scanner collectible chance.
        if (bLevel[Mn.B_SCANNER] > 0 && _rand(1000) < bLevel[Mn.B_SCANNER] * 8) { _grantRandomCollectible(); }
        _checkDiscoveries();
        _checkMilestones();
        save();
        if (discoveries() > before) { return "DISCOVERY! " + (lastDiscoveryName() != null ? lastDiscoveryName() : "New layer"); }
        return "Dug to " + depth + "m";
    }

    // ── Buildings ─────────────────────────────────────────────────────────────
    function isUnlocked(i) { return depth >= Mn.bUnlockDepth(i) || bLevel[i] > 0; }
    function bCost(i) { return Mn.bCostAt(i, bLevel[i] + 1); }
    hidden function _afford(cost) {
        return res[Mn.R_STONE] >= cost[0] && res[Mn.R_IRON] >= cost[1]
            && res[Mn.R_GOLD] >= cost[2] && res[Mn.R_GEM] >= cost[3];
    }
    function canAfford(cost) { return _afford(cost); }
    hidden function _pay(cost) {
        res[Mn.R_STONE] -= cost[0]; res[Mn.R_IRON] -= cost[1];
        res[Mn.R_GOLD]  -= cost[2]; res[Mn.R_GEM]  -= cost[3];
    }
    function upgradeBuilding(i) {
        if (!isUnlocked(i)) { return "Locked - dig to " + Mn.bUnlockDepth(i) + "m"; }
        var cost = bCost(i);
        if (!_afford(cost)) { return "Need more resources"; }
        _pay(cost);
        var wasNew = (bLevel[i] == 0);
        bLevel[i] += 1;
        dUpgrades += 1;
        if (wasNew) { _logAdd("Built " + Mn.bName(i)); }
        save();
        return (wasNew ? "Built " : "Upgraded ") + Mn.bName(i) + " Lv" + bLevel[i];
    }

    // ── Equipment ──────────────────────────────────────────────────────────────
    function pickCost() { return Mn.pickCost(pickTier); }
    function cartCost() { return Mn.cartCost(cartTier); }
    function upgradePick() {
        if (pickTier >= Mn.PICK_N - 1) { return "Best pickaxe owned"; }
        var cost = Mn.pickCost(pickTier);
        if (!_afford(cost)) { return "Need more resources"; }
        _pay(cost); pickTier += 1; dUpgrades += 1;
        _logAdd("Forged " + Mn.pickName(pickTier));
        save();
        return "Now wielding " + Mn.pickName(pickTier);
    }
    function upgradeCart() {
        if (cartTier >= Mn.CART_N - 1) { return "Best cart owned"; }
        var cost = Mn.cartCost(cartTier);
        if (!_afford(cost)) { return "Need more resources"; }
        _pay(cost); cartTier += 1; dUpgrades += 1;
        _logAdd("Upgraded to " + Mn.cartName(cartTier));
        save();
        return "Now hauling with " + Mn.cartName(cartTier);
    }

    // ── Collection ──────────────────────────────────────────────────────────────
    hidden function _grantCollectible(i) {
        if (i < 0 || i >= Mn.C_N || hasColl(i)) { return false; }
        collMask = collMask | (1 << i);
        _logAdd("Found " + Mn.cName(i) + " (" + Mn.rarityName(Mn.cRarity(i)) + ")");
        return true;
    }
    hidden function _grantRandomCollectible() {
        var avail = [];
        for (var i = 0; i < Mn.C_N; i++) { if (!hasColl(i)) { avail.add(i); } }
        if (avail.size() == 0) { return -1; }
        // weight toward rarer at greater depth: pick a few and keep the deepest-appropriate.
        var pick = avail[_rand(avail.size())];
        _grantCollectible(pick);
        return pick;
    }

    // ── Milestones ────────────────────────────────────────────────────────────
    hidden function _checkMilestones() {
        if ((mileMask & 1) == 0 && res[Mn.R_GOLD] > 0) { mileMask = mileMask | 1; _logAdd("Milestone: First Gold"); }
        if ((mileMask & 2) == 0 && hasColl(3)) { mileMask = mileMask | 2; _logAdd("Milestone: First Crystal"); }
        if ((mileMask & 4) == 0 && legendaryFinds() > 0) { mileMask = mileMask | 4; _logAdd("Milestone: First Legendary Find"); }
        if ((mileMask & 8) == 0 && depth >= 1000) { mileMask = mileMask | 8; _logAdd("Milestone: 1000m Depth"); }
    }

    // ── Daily challenge ─────────────────────────────────────────────────────────
    function dailyId() { return dailyDay % 4; }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Mine 500 meters"; }
        if (id == 1) { return "Collect 100 resources"; }
        if (id == 2) { return "Upgrade equipment"; }
        return "Walk 5000 steps";
    }
    function dailyTarget() {
        var id = dailyId();
        if (id == 0) { return 500; }
        if (id == 1) { return 100; }
        if (id == 3) { return 5000; }
        return 1;
    }
    function dailyProgress() {
        var id = dailyId();
        if (id == 0) { var m = depth - dDepthStart; return (m < 0) ? 0 : m; }
        if (id == 1) { return (dGained > 100) ? 100 : dGained; }
        if (id == 2) { return dUpgrades > 0 ? 1 : 0; }
        var s = Sensors.getStepsToday(); return (s > 5000) ? 5000 : s;
    }
    function dailyComplete() { return dailyProgress() >= dailyTarget(); }
    function dailyRewardText() { return "+400 STN  +60 IRN  +8 GLD"; }
    function claimDaily() {
        if (dailyClaimed || !dailyComplete()) { return false; }
        dailyClaimed = true;
        res[Mn.R_STONE] += 400; res[Mn.R_IRON] += 60; res[Mn.R_GOLD] += 8;
        if (_rand(100) < 22) { _grantRandomCollectible(); }
        save();
        return true;
    }

    // ── DEMO fast-track (fully guarded; uses existing mutators) ───────────────
    // Called ~once per second by the view when Demo Mode is on. Grants a scaling
    // resource infusion, descends quickly, auto-buys the best affordable upgrade
    // and occasionally drops a collectible so the mine visibly grows rich fast.
    function demoTick() {
        try {
            var scale = 1 + depth / 200;
            res[Mn.R_STONE] += 600 * scale;
            res[Mn.R_IRON]  += 180 * scale;
            res[Mn.R_GOLD]  += 90 * scale;
            res[Mn.R_GEM]   += 14 * scale;

            var step = 30 + pickTier * 6 + bLevel[Mn.B_SHAFT] * 4 + depth / 40;
            if (step < 20) { step = 20; }
            if (step > 400) { step = 400; }
            depth += step;
            if (depth < 0) { depth = 0; }

            _checkDiscoveries();
            _demoUpgrade();
            if (_rand(100) < 40) { _grantRandomCollectible(); }
            _checkMilestones();
            save();
        } catch (e) {}
    }

    hidden function _demoUpgrade() {
        try {
            for (var i = 0; i < Mn.B_N; i++) {
                if (isUnlocked(i) && _afford(bCost(i))) { upgradeBuilding(i); return; }
            }
            if (pickTier < Mn.PICK_N - 1 && _afford(Mn.pickCost(pickTier))) { upgradePick(); return; }
            if (cartTier < Mn.CART_N - 1 && _afford(Mn.cartCost(cartTier))) { upgradeCart(); return; }
        } catch (e) {}
    }

    function history() { return log; }

    // ── Leaderboard (throttled to once/day) ──────────────────────────────────
    function submitScores() {
        var td = today();
        if (_get("mn_lbday", 0) == td) { return; }
        if (!started) { return; }
        _set("mn_lbday", td);
        // Publish all five boards through a SERIAL batch: one request at a time
        // (Garmin allows only one in-flight makeWebRequest — firing them at once
        // dropped four of five and crashed the app on some firmware).
        try {
            // "z" is the numeric zone (tints the web emblem to match the
            // on-watch biome colour); depth/level/legend drive the crest badges.
            // Meta rides every board so the emblem shows regardless of tab.
            var meta = {
                "depth"  => depth,
                "level"  => mineLevel(),
                "zone"   => Mn.zName(zone()),
                "legend" => legendaryFinds(),
                "rich"   => richest(),
                "z"      => zone()
            };
            Leaderboard.submitScoreBatch(Mn.GAME_ID, [
                { :score => depth,            :variant => Mn.LB_DEPTH,  :meta => meta },
                { :score => richest(),        :variant => Mn.LB_RICH,   :meta => meta },
                { :score => legendaryFinds(), :variant => Mn.LB_LEGEND, :meta => meta },
                { :score => mineLevel(),      :variant => Mn.LB_LEVEL,  :meta => meta },
                { :score => daysAlive() + 1,  :variant => Mn.LB_AGE,    :meta => meta }
            ]);
        } catch (e) {}
    }
}
