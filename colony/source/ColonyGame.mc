using Toybox.Application;
using Toybox.Time;
using Toybox.Math;

// ─────────────────────────────────────────────────────────────────────────────
//  ColonyGame  –  all game-state, production logic, upgrades, offline calc
//
//  Buildings (4 slots):
//    0 – Mining Drone Bay   → produces Ore / sec
//    1 – Energy Reactor     → produces Energy / sec
//    2 – Bio Farm           → produces bonus Ore / sec (food multiplier)
//    3 – Research Lab       → global production multiplier
//
//  Resources:
//    Ore    – primary currency; spent on buildings 0,1,2
//    Energy – secondary currency; spent on Research Lab & Boost
//
//  Boost:  player taps "BOOST" → x2 production for BOOST_DURATION seconds
//  Events: random small events every ~120 s (small ore/energy gift)
//  Prestige: available when total ore ever mined > PRESTIGE_THRESHOLD;
//            resets buildings but grants +10% permanent multiplier
// ─────────────────────────────────────────────────────────────────────────────

// Building indices
const BLD_DRONES  = 0;
const BLD_REACTOR = 1;
const BLD_FARM    = 2;
const BLD_LAB     = 3;
const BLD_COUNT   = 4;

// Base production per second per building level
const BASE_ORE_PS    = 1.0;   // drones
const BASE_ENERGY_PS = 0.5;   // reactor
const BASE_FARM_PS   = 0.4;   // farm (adds to ore)
// Lab: each level adds +8% global multiplier

// Base build cost (Ore for 0-2, Energy for 3)
const BASE_COST_DRONES  = 10.0;
const BASE_COST_REACTOR = 8.0;
const BASE_COST_FARM    = 15.0;
const BASE_COST_LAB     = 20.0;   // Energy cost

// Cost growth exponent per level
const COST_EXP = 1.45;

// Boost
const BOOST_DURATION   = 20;   // seconds
const BOOST_MULTIPLIER = 2.0;

// Prestige threshold (lifetime ore mined)
const PRESTIGE_THRESHOLD = 50000.0;

// Max offline time credited (4 hours)
const MAX_OFFLINE_SECS = 14400;

// Random event interval (seconds)
const EVENT_INTERVAL = 120;

class ColonyGame {

    // ── Resources ─────────────────────────────────────────────────────────────
    var ore;
    var energy;
    var lifeOre;       // lifetime ore mined (for prestige check)

    // ── Buildings  [level_0 .. level_3] ───────────────────────────────────────
    var bldLevel;

    // ── Multipliers ───────────────────────────────────────────────────────────
    var prestigeMult;  // permanent +10% per prestige (stored as float, e.g. 1.30)
    var prestigeCount;

    // ── Boost state ───────────────────────────────────────────────────────────
    var boostSecsLeft;
    var boostCost;     // energy cost to activate boost (scales with level)

    // ── Timestamps (unix seconds) ─────────────────────────────────────────────
    var lastTimestamp;

    // ── Random event ─────────────────────────────────────────────────────────
    var eventSecsLeft;   // countdown to next random event
    var lastEventMsg;    // short message to display ("★ ORE SURGE!")

    // ── Tick accumulator (for sub-second production) ──────────────────────────
    var oreAccum;
    var energyAccum;

    function initialize() {
        ore          = 0.0;
        energy       = 0.0;
        lifeOre      = 0.0;
        bldLevel     = [0, 0, 0, 0];
        prestigeMult = 1.0;
        prestigeCount = 0;
        boostSecsLeft = 0;
        boostCost     = 5;
        lastTimestamp = 0;
        eventSecsLeft = EVENT_INTERVAL;
        lastEventMsg  = "";
        oreAccum      = 0.0;
        energyAccum   = 0.0;

        load();
    }

    // ── Persistence ───────────────────────────────────────────────────────────

    function save() {
        var s = Application.Storage;
        s.setValue("sc_ore",     ore.toNumber());
        s.setValue("sc_energy",  energy.toNumber());
        s.setValue("sc_life",    lifeOre.toNumber());
        s.setValue("sc_l0",      bldLevel[BLD_DRONES]);
        s.setValue("sc_l1",      bldLevel[BLD_REACTOR]);
        s.setValue("sc_l2",      bldLevel[BLD_FARM]);
        s.setValue("sc_l3",      bldLevel[BLD_LAB]);
        s.setValue("sc_pmult",   (prestigeMult * 100.0).toNumber());
        s.setValue("sc_pcnt",    prestigeCount);
        s.setValue("sc_ts",      Time.now().value());
    }

    hidden function load() {
        var s = Application.Storage;
        var v;
        v = s.getValue("sc_ore");     if (v != null) { ore     = v.toFloat(); }
        v = s.getValue("sc_energy");  if (v != null) { energy  = v.toFloat(); }
        v = s.getValue("sc_life");    if (v != null) { lifeOre = v.toFloat(); }
        v = s.getValue("sc_l0");      if (v != null) { bldLevel[BLD_DRONES]  = v; }
        v = s.getValue("sc_l1");      if (v != null) { bldLevel[BLD_REACTOR] = v; }
        v = s.getValue("sc_l2");      if (v != null) { bldLevel[BLD_FARM]    = v; }
        v = s.getValue("sc_l3");      if (v != null) { bldLevel[BLD_LAB]     = v; }
        v = s.getValue("sc_pmult");   if (v != null) { prestigeMult = v.toFloat() / 100.0; }
        v = s.getValue("sc_pcnt");    if (v != null) { prestigeCount = v; }
        v = s.getValue("sc_ts");      if (v != null) { lastTimestamp = v; }
    }

    // ── Offline calculation ───────────────────────────────────────────────────

    function onResume() {
        if (lastTimestamp == 0) {
            lastTimestamp = Time.now().value();
            return;
        }
        var now     = Time.now().value();
        var elapsed = now - lastTimestamp;
        if (elapsed < 0) { elapsed = 0; }
        if (elapsed > MAX_OFFLINE_SECS) { elapsed = MAX_OFFLINE_SECS; }
        lastTimestamp = now;

        if (elapsed > 5) {
            // Credit offline production (no boost during offline)
            var orePs    = calcOrePs(false);
            var energyPs = calcEnergyPs(false);
            ore    += orePs    * elapsed.toFloat();
            energy += energyPs * elapsed.toFloat();
            lifeOre += orePs   * elapsed.toFloat();
        }
    }

    // ── Production formulas ───────────────────────────────────────────────────

    // Global multiplier: prestige * research lab
    function globalMult() {
        var labMult = 1.0 + bldLevel[BLD_LAB].toFloat() * 0.08;
        return prestigeMult * labMult;
    }

    // Ore per second (drones + farm), optional boost
    function calcOrePs(withBoost) {
        var drones = bldLevel[BLD_DRONES].toFloat() * BASE_ORE_PS;
        var farm   = bldLevel[BLD_FARM].toFloat()   * BASE_FARM_PS;
        var total  = (drones + farm) * globalMult();
        if (withBoost && boostSecsLeft > 0) { total = total * BOOST_MULTIPLIER; }
        return total;
    }

    // Energy per second (reactor)
    function calcEnergyPs(withBoost) {
        var total = bldLevel[BLD_REACTOR].toFloat() * BASE_ENERGY_PS * globalMult();
        if (withBoost && boostSecsLeft > 0) { total = total * BOOST_MULTIPLIER; }
        return total;
    }

    // ── Build cost calculation ─────────────────────────────────────────────────

    function buildCost(bldIdx) {
        var base;
        var lvl = bldLevel[bldIdx].toFloat();
        if      (bldIdx == BLD_DRONES)  { base = BASE_COST_DRONES; }
        else if (bldIdx == BLD_REACTOR) { base = BASE_COST_REACTOR; }
        else if (bldIdx == BLD_FARM)    { base = BASE_COST_FARM; }
        else                            { base = BASE_COST_LAB; }
        // cost = base * COST_EXP ^ level  (approximated without pow)
        var cost = base;
        for (var i = 0; i < lvl.toNumber() && i < 30; i++) {
            cost = cost * COST_EXP;
        }
        return cost;
    }

    // Returns true if player can afford the building
    function canAfford(bldIdx) {
        var cost = buildCost(bldIdx);
        if (bldIdx == BLD_LAB) { return energy >= cost; }
        return ore >= cost;
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    // Build / upgrade a module. Returns true on success.
    function build(bldIdx) {
        if (!canAfford(bldIdx)) { return false; }
        var cost = buildCost(bldIdx);
        if (bldIdx == BLD_LAB) { energy -= cost; }
        else                   { ore    -= cost; }
        bldLevel[bldIdx]++;
        save();
        return true;
    }

    // Activate production boost (costs energy, scales with total colony level)
    function activateBoost() {
        boostCost = 5 + totalLevel() * 2;
        if (energy < boostCost.toFloat()) { return false; }
        energy -= boostCost.toFloat();
        boostSecsLeft = BOOST_DURATION;
        save();
        return true;
    }

    // Prestige: reset buildings, keep ore/energy bonus
    function prestige() {
        if (!canPrestige()) { return false; }
        prestigeCount++;
        prestigeMult = 1.0 + prestigeCount.toFloat() * 0.10;
        for (var i = 0; i < BLD_COUNT; i++) { bldLevel[i] = 0; }
        ore    = 0.0;
        energy = 0.0;
        save();
        return true;
    }

    function canPrestige() {
        return lifeOre >= PRESTIGE_THRESHOLD;
    }

    // ── Per-tick update (called every 1 second from timer) ────────────────────

    function tick() {
        var orePs    = calcOrePs(true);
        var energyPs = calcEnergyPs(true);

        ore    += orePs;
        energy += energyPs;
        lifeOre += orePs;

        if (boostSecsLeft > 0) { boostSecsLeft--; }

        // Random event countdown
        eventSecsLeft--;
        if (eventSecsLeft <= 0) {
            triggerRandomEvent();
            eventSecsLeft = EVENT_INTERVAL + (Math.rand() % 60).toNumber();
        }

        // Persist every 30 ticks
        if ((Time.now().value() % 30) == 0) { save(); }
    }

    // ── Random events ─────────────────────────────────────────────────────────

    hidden function triggerRandomEvent() {
        var roll = (Math.rand() % 4).toNumber();
        if (roll == 0) {
            var bonus = calcOrePs(false) * 30.0;
            ore += bonus;
            lifeOre += bonus;
            lastEventMsg = "★ ORE SURGE! +" + bonus.toNumber() + " ore";
        } else if (roll == 1) {
            var bonus2 = calcEnergyPs(false) * 30.0;
            energy += bonus2;
            lastEventMsg = "⚡ ENERGY BURST! +" + bonus2.toNumber();
        } else if (roll == 2) {
            boostSecsLeft += 10;
            lastEventMsg = "★ MYSTERY BOOST +10s";
        } else {
            lastEventMsg = "★ SOLAR WIND: colony stable";
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function totalLevel() {
        var t = 0;
        for (var i = 0; i < BLD_COUNT; i++) { t += bldLevel[i]; }
        return t;
    }

    // Human-readable number formatting  (1234 → "1.2K", 1000000 → "1.0M")
    function fmt(val) {
        var n = val.toNumber();
        if (n >= 1000000) {
            return (val / 1000000.0).format("%.1f") + "M";
        } else if (n >= 1000) {
            return (val / 1000.0).format("%.1f") + "K";
        } else {
            return n + "";
        }
    }

    // Format production rate with /s suffix
    function fmtRate(ps) {
        if (ps < 0.1) { return "0.0/s"; }
        if (ps >= 100.0) { return ps.toNumber() + "/s"; }
        return ps.format("%.1f") + "/s";
    }
}
