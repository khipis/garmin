// ═══════════════════════════════════════════════════════════════════════════
// MineModel.mc — All BITOCHI MINES game state + logic.
//
// One class owns everything: save/load, idle mining (resources AND depth accrue
// offline), the underground base (9 buildings), equipment (pickaxe & cart
// tiers), the manual DIG action, depth-threshold discoveries, the rarity
// collection, random events, daily challenges, streaks, milestones and the five
// leaderboard scores. The view/delegate only read fields and call actions.
// Every Storage access is guarded so nothing here can throw into the UI.
//
// DEPTH PRESSURE is the pacing spine below 1200m: pressurePct() decays
// hyperbolically with depth and multiplies digRate(), so the surface game is
// bit-for-bit unchanged while the deep world takes weeks. The Hydraulic Rig
// (B_RIG) is the counter-upgrade.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Math;

class MineModel {
    // Saturation limits for anything read back from Storage. They exist purely
    // so a corrupt, hand-edited or legacy value can never overflow 32-bit
    // arithmetic (which wraps negative and would break costs, bars and scores).
    const MAX_SEC   = 0x7FFFFFFF;
    const MAX_DAY   = 24855;          // MAX_SEC / 86400
    const MAX_DEPTH = 10000000;
    const MAX_RES   = 8000000;        // * resValue(GEM)=120 still fits in a Number
    const MAX_LEVEL = 200;
    const MAX_RATE  = 2000000;        // ceiling for any per-hour rate / percent

    var started;
    var bornSec; var lastSec;
    var res;              // [4] Stone, Iron, Gold, Gems
    var depth;            // meters
    var bLevel;           // [B_N] building levels
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

    // Numeric storage reader. A key that was never written, or that holds a
    // value of the wrong type / an out-of-range legacy number, resolves to a
    // safe in-range Number so nothing downstream can index or divide with junk.
    hidden function _num(k, def, lo, hi) {
        var v = _get(k, def);
        if (!(v instanceof Lang.Number)) {
            if (v instanceof Lang.Float || v instanceof Lang.Long || v instanceof Lang.Double) {
                try { v = v.toNumber(); } catch (e) { v = def; }
            } else { v = def; }
        }
        if (v < lo) { v = lo; }
        if (v > hi) { v = hi; }
        return v;
    }
    hidden function _bool(k) { var v = _get(k, false); return (v instanceof Lang.Boolean) ? v : false; }

    hidden function _load() {
        started    = _bool("mn_started");
        bornSec    = _num("mn_born", 0, 0, MAX_SEC);
        lastSec    = _num("mn_last", 0, 0, MAX_SEC);
        depth      = _num("mn_depth", 12, 0, MAX_DEPTH);
        pickTier   = _num("mn_pick", 0, 0, Mn.PICK_N - 1);
        cartTier   = _num("mn_cart", 0, 0, Mn.CART_N - 1);
        streak     = _num("mn_streak", 0, 0, 100000);
        lastDay    = _num("mn_lday", 0, 0, MAX_DAY);
        dailyDay   = _num("mn_dday", 0, 0, MAX_DAY);
        dUpgrades  = _num("mn_dup", 0, 0, 1000000);
        dDepthStart= _num("mn_dds", 12, 0, MAX_DEPTH);
        dGained    = _num("mn_dg", 0, 0, MAX_RES);
        dailyClaimed   = _bool("mn_dclaim");
        dailyCollected = _bool("mn_dcol");
        discMask   = _num("mn_disc", 0, 0, 0x7FFFFFFF);
        collMask   = _num("mn_coll", 0, 0, 0x7FFFFFFF);
        mileMask   = _num("mn_mile", 0, 0, 0x7FFFFFFF);
        pendingEvent = _num("mn_pev", Mn.EV_NONE, Mn.EV_NONE, 4);

        res = new [Mn.R_N];
        for (var i = 0; i < Mn.R_N; i++) { res[i] = _num("mn_r" + i, 0, 0, MAX_RES); }
        bLevel = new [Mn.B_N];
        for (var b = 0; b < Mn.B_N; b++) { bLevel[b] = _num("mn_b" + b, 0, 0, MAX_LEVEL); }

        var lg = _get("mn_log", null);
        log = [];
        if (lg instanceof Lang.Array) {
            for (var q = 0; q < lg.size() && q < 8; q++) {
                if (lg[q] instanceof Lang.String) { log.add(lg[q]); }
            }
        }

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

    // v * pct/100, saturating. Late-game multiplier stacks used to be able to
    // push the intermediate product past a 32-bit Number, which wraps negative
    // and turns every rate/bar/score into garbage. Divides first once v is big
    // enough that precision loss is irrelevant.
    hidden function _mulPct(v, pct) {
        if (v <= 0 || pct <= 0) { return 0; }
        if (v > MAX_RATE) { v = MAX_RATE; }
        if (pct > 10000) { pct = 10000; }
        var r = (v <= 20000) ? (v * pct / 100) : (v / 100 * pct);
        if (r > MAX_RATE) { r = MAX_RATE; }
        return r;
    }

    function miningPowerPct() {
        var v = Mn.pickPowerPct(pickTier);
        v = _mulPct(v, Mn.cartMultPct(cartTier));
        v = _mulPct(v, 100 + bLevel[Mn.B_FORGE] * 15);
        v = _mulPct(v, 100 + (workers() - 1) * Mn.WORKER_BONUS);
        v = _mulPct(v, _labPct());
        return v;
    }
    // Depth pressure: the rock fights back the deeper you are. 100% above
    // 1200m (so the whole early game is untouched), then a hyperbolic falloff
    // that the Hydraulic Rig pushes back against. Never below 5%.
    function pressurePct() {
        var over = depth - 1200;
        if (over < 0) { over = 0; }
        var den = 3000 + over;
        if (den < 1) { den = 1; }
        var p = 100 * 3000 / den;
        var rig = bLevel[Mn.B_RIG];
        if (rig < 0) { rig = 0; }
        if (rig > 40) { rig = 40; }
        p = p * (100 + rig * 25) / 100;
        if (p < 5) { p = 5; }
        if (p > 100) { p = 100; }
        return p;
    }

    function digRate() {   // meters per hour
        var v = Mn.DIG_BASE + bLevel[Mn.B_SHAFT] * 4 + bLevel[Mn.B_BORE] * 12;
        v = _mulPct(v, 100 + bLevel[Mn.B_ELEVATOR] * 15);
        v = _mulPct(v, 100 + (workers() - 1) * Mn.WORKER_BONUS);
        v = _mulPct(v, Mn.pickPowerPct(pickTier));
        v = _mulPct(v, _labPct());
        v = _mulPct(v, pressurePct());
        if (v < 1) { v = 1; }   // never stall the mine completely
        return v;
    }

    function hourlyRate(r) {
        var z = zone();
        var w = Mn.zWeight(z, r);
        if (w <= 0) { return 0; }
        var sumw = 0;
        for (var k = 0; k < Mn.R_N; k++) { sumw += Mn.zWeight(z, k); }
        if (sumw <= 0) { return 0; }
        var total = Mn.ORE_BASE * miningPowerPct() / 100;
        var rate = (total <= 20000) ? (total * w / sumw) : (total / sumw * w);
        if (r == Mn.R_GEM) { rate = _mulPct(rate, 100 + bLevel[Mn.B_GEMWS] * 20); }
        return rate;
    }

    // Saturating mutators — every resource/depth gain in the game funnels
    // through these so no path can ever push a stored value past the limits
    // the loader (and all the downstream arithmetic) assumes.
    hidden function _addRes(r, amt) {
        if (r < 0 || r >= Mn.R_N) { return; }
        var v = res[r] + amt;
        if (v < 0) { v = 0; }
        if (v > MAX_RES) { v = MAX_RES; }
        res[r] = v;
    }
    hidden function _addDepth(amt) {
        var v = depth + amt;
        if (v < 0) { v = 0; }
        if (v > MAX_DEPTH) { v = MAX_DEPTH; }
        depth = v;
    }

    // Rate-per-hour applied over `elapsed` seconds without overflowing the
    // intermediate product at late-game rates (24h offline * a huge rate).
    hidden function _accrue(rate, elapsed) {
        if (rate <= 0 || elapsed <= 0) { return 0; }
        if (rate <= 20000) { return rate * elapsed / 3600; }
        return rate / 60 * (elapsed / 60);
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
        for (var i = 0; i < Mn.R_N; i++) {
            s += res[i] * Mn.resValue(i);
            if (s > 1000000000) { return 1000000000; }
        }
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
            var gain = _accrue(hourlyRate(r), elapsed) * nightPct / 100;
            if (gain > 0) { _addRes(r, gain); gRes[r] = gain; dGained += gain; }
        }
        if (dGained > MAX_RES) { dGained = MAX_RES; }
        var any = false;
        for (var k = 0; k < Mn.R_N; k++) { if (gRes[k] > 0) { any = true; } }
        if (any) { dailyCollected = true; }

        // Depth.
        var dg = _accrue(digRate(), elapsed) * nightPct / 100;

        // Steps expedition bonus (once per new day).
        if (newDay) {
            var steps = Sensors.getStepsToday();
            if (steps > 0) {
                dg += steps / 100;                       // bonus depth
                if (steps >= 10000) { _addRes(Mn.R_GOLD, 30); gRes[Mn.R_GOLD] += 30; }
                if (steps >= 5000 && _rand(100) < 60) { _grantRandomCollectible(); }
            }
        }
        if (dg > 0) { _addDepth(dg); gDepth = dg; }

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
            var s = 100 + _rand(300); _addRes(Mn.R_STONE, s); _addRes(Mn.R_IRON, s / 5); gEvent = e;
            _logAdd("Hidden cave +" + s + " stone");
        } else if (e == Mn.EV_VEIN) {
            var g = 20 + _rand(60); _addRes(Mn.R_GOLD, g); _addRes(Mn.R_GEM, 1 + _rand(4)); gEvent = e;
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
                var d = 20 + _rand(60); _addDepth(d); _checkDiscoveries();
                msg = "New tunnel! +" + d + "m depth"; _logAdd("Earthquake tunnel +" + d + "m");
            } else { msg = "Tunnel sealed off."; }
        } else { // CREATURE
            if (choice == 0) {
                if (_rand(100) < 60) {
                    var gi = _grantRandomCollectible();
                    msg = (gi >= 0) ? ("Defeated it! Found " + Mn.cName(gi)) : "Fought it off. +50 gems";
                    if (gi < 0) { _addRes(Mn.R_GEM, 50); }
                    _logAdd("Creature defeated");
                } else {
                    var l = 40 + _rand(80); _addRes(Mn.R_IRON, -l);
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
                _addRes(Mn.R_GOLD, 40 + i * 20);
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
        if (add < 1) { add = 1; }
        var before = discoveries();
        _addDepth(add);
        // small ore reward by zone.
        var z = zone();
        var sumw = 0;
        for (var k = 0; k < Mn.R_N; k++) { sumw += Mn.zWeight(z, k); }
        if (sumw > 0) {
            for (var r = 0; r < Mn.R_N; r++) {
                var g = Mn.zWeight(z, r) * (2 + pickTier) / sumw + (r == Mn.R_STONE ? 1 : 0);
                if (g > 0) { _addRes(r, g); dGained += g; }
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
    function bLvl(i) { return bLevel[Mn._c(i, 0, Mn.B_N - 1)]; }
    function isUnlocked(i) { return depth >= Mn.bUnlockDepth(i) || bLvl(i) > 0; }
    function bCost(i) { return Mn.bCostAt(Mn._c(i, 0, Mn.B_N - 1), bLvl(i) + 1); }
    hidden function _afford(cost) {
        return res[Mn.R_STONE] >= cost[0] && res[Mn.R_IRON] >= cost[1]
            && res[Mn.R_GOLD] >= cost[2] && res[Mn.R_GEM] >= cost[3];
    }
    function canAfford(cost) { return _afford(cost); }
    hidden function _pay(cost) {
        for (var i = 0; i < Mn.R_N; i++) { _addRes(i, -cost[i]); }
    }
    function upgradeBuilding(i) {
        i = Mn._c(i, 0, Mn.B_N - 1);
        if (!isUnlocked(i)) { return "Locked - dig to " + Mn.bUnlockDepth(i) + "m"; }
        if (bLevel[i] >= MAX_LEVEL) { return "Best " + Mn.bName(i) + " owned"; }
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
    // Random drops are gated by depth: each zone pair unlocks one more rarity
    // band, so the eight deep collectibles stay genuine end-game chase items
    // instead of falling out of a surface-level earthquake. Falls back to the
    // full pool once everything in-band is already owned.
    hidden function _grantRandomCollectible() {
        var maxR = 1 + zone() / 2;
        if (maxR > 4) { maxR = 4; }
        var avail = [];
        for (var i = 0; i < Mn.C_N; i++) {
            if (!hasColl(i) && Mn.cRarity(i) <= maxR) { avail.add(i); }
        }
        if (avail.size() == 0) {
            for (var j = 0; j < Mn.C_N; j++) { if (!hasColl(j)) { avail.add(j); } }
        }
        if (avail.size() == 0) { return -1; }
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
        // Appended deep-layer bits — never reuse 1/2/4/8.
        if ((mileMask & 16) == 0 && depth >= 5000)  { mileMask = mileMask | 16;  _logAdd("Milestone: 5000m Depth"); }
        if ((mileMask & 32) == 0 && depth >= 10000) { mileMask = mileMask | 32;  _logAdd("Milestone: 10000m Depth"); }
        if ((mileMask & 64) == 0 && depth >= 25000) { mileMask = mileMask | 64;  _logAdd("Milestone: 25000m Depth"); }
        if ((mileMask & 128) == 0 && depth >= 50000){ mileMask = mileMask | 128; _logAdd("Milestone: 50000m Depth"); }
    }

    // ── Daily challenge ─────────────────────────────────────────────────────────
    function dailyId() { var d = dailyDay % 4; return (d < 0) ? 0 : d; }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Mine " + dailyTarget() + " meters"; }
        if (id == 1) { return "Collect 100 resources"; }
        if (id == 2) { return "Upgrade equipment"; }
        return "Walk 5000 steps";
    }
    function dailyTarget() {
        var id = dailyId();
        // The dig target scales with the zone — 500m is a rounding error at
        // 20km down, where a day's progress is measured in thousands.
        if (id == 0) { return 500 * (1 + zone()); }
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
        _addRes(Mn.R_STONE, 400); _addRes(Mn.R_IRON, 60); _addRes(Mn.R_GOLD, 8);
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
            if (scale > 2000) { scale = 2000; }
            _addRes(Mn.R_STONE, 600 * scale);
            _addRes(Mn.R_IRON,  180 * scale);
            _addRes(Mn.R_GOLD,   90 * scale);
            _addRes(Mn.R_GEM,    14 * scale);

            var step = 30 + pickTier * 6 + bLevel[Mn.B_SHAFT] * 4 + depth / 40;
            if (step < 20) { step = 20; }
            if (step > 4000) { step = 4000; }
            _addDepth(step);

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
