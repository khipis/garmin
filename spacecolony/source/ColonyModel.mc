// ═══════════════════════════════════════════════════════════════════════════
// ColonyModel.mc — All SPACE COLONY game state + logic.
//
// One class owns everything: save/load, idle (offline) production, the building
// tree (build/upgrade), planet exploration + discoveries, the tech tree, random
// events, daily missions, streaks, colony history, the war layer (marines,
// turrets, raids on real rival colonies, incoming attacks) and the seven
// leaderboard scores.
// The view/delegate only read fields and call action methods. Every Storage
// access is guarded so nothing here can throw into the UI.
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
    var artMask;          // bitmask of recovered alien artifacts
    var relicMask;        // bitmask of one-shot artifact grants already paid

    var streak; var lastDay; var streakPaid;
    var dailyDay; var dUpgrades; var dExpl; var dRes; var dailyClaimed; var dailyCollected;
    var dRaid;             // raids launched today
    var stepBase;         // steps already converted into expedition progress today
    var log;              // Array<String> history (newest first, cap 8)
    var pendingEvent;     // EV_* awaiting a choice, or EV_NONE

    // ── War (military economy + raids) ────────────────────────────────────
    var marines; var turrets;
    var warPts; var warWins; var warLosses; var warStreak;
    var warLog;            // Array<String> war-only history (newest first, cap 8)
    var raidStance;        // Sc.STANCE_*
    var defLog;            // Array<[day, held, name, ptsLost, minLost]>, newest first
    var rivals;            // Array<[name, power]> cached off the War board
    var rivalDay;          // calendar day the roster was last refreshed

    // Idle summary (for WELCOME BACK)
    var gRes; var gSecs; var gPop; var newDay; var gEvent; var gArt;
    var gDefN; var gDefHeld;   // incoming attacks resolved on this return
    var mailAlert;             // real inbox raids arrived this session (UI flag)
    hidden var _mailPending;   // waiting on /inbox (phone was up at collect)
    hidden var _mailElapsed;   // elapsed secs for offline RNG if inbox fails
    var lastClaimBonus;   // streak-milestone line from the last daily claim

    // Last raid outcome (transient — for the raid-result overlay only).
    var rWin; var rFoeName; var rPtsDelta; var rTip; var rCredit; var rSci;

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
    // The defence log and the rival roster persist as arrays of fixed-width
    // rows (numbers + strings). A corrupt or legacy row must never reach the
    // renderer, so anything off-shape is dropped here instead of being
    // defended against at every read site.
    hidden function _rowsOf(v, n, cap) {
        var out = [];
        if (!(v instanceof Lang.Array)) { return out; }
        for (var i = 0; i < v.size() && out.size() < cap; i++) {
            var r = v[i];
            if (!(r instanceof Lang.Array) || r.size() != n) { continue; }
            var ok = true;
            for (var k = 0; k < n; k++) {
                if (!(r[k] instanceof Lang.Number) && !(r[k] instanceof Lang.String)) { ok = false; }
            }
            if (ok) { out.add(r); }
        }
        return out;
    }
    hidden function _rNum(r, i) {
        if (!(r instanceof Lang.Array) || i >= r.size()) { return 0; }
        return (r[i] instanceof Lang.Number) ? r[i] : 0;
    }
    hidden function _rStr(r, i) {
        if (!(r instanceof Lang.Array) || i >= r.size()) { return "Unknown"; }
        if (r[i] instanceof Lang.String && r[i].length() > 0) { return r[i]; }
        return "Unknown";
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
        dRes     = _num("sc_dres", 0, 0, 100000);     // appended key -> 0 on old saves
        dailyClaimed  = _bool("sc_dclaim", false);
        dailyCollected= _bool("sc_dcol", false);
        dRaid    = _num("sc_draid", 0, 0, 100000);    // absent in old saves -> 0
        stepBase = _num("sc_stepb", 0, 0, 1000000);   // absent in old saves -> 0
        discMask = _num("sc_disc", 0, 0, (1 << Sc.RG_N) - 1);
        artMask  = _num("sc_art", 0, 0, (1 << Sc.A_N) - 1);
        relicMask= _num("sc_amile", 0, 0, 0x7FFFFFFF);
        streakPaid = _num("sc_spaid", 0, 0, 100000);
        pendingEvent = _num("sc_pev", Sc.EV_NONE, Sc.EV_NONE, Sc.EV_RARE);

        marines   = _num("sc_mar", 0, 0, Sc.MARINE_CAP_MAX);
        turrets   = _num("sc_tur", 0, 0, Sc.TURRET_CAP_MAX);
        warPts    = _num("sc_wpts", 0, 0, 0x7FFFFFFF);
        warWins   = _num("sc_wwin", 0, 0, 1000000);
        warLosses = _num("sc_wlos", 0, 0, 1000000);
        warStreak = _num("sc_wstr", 0, -1000000, 1000000);
        raidStance= _num("sc_stance", Sc.STANCE_BALANCED, 0, 2);

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
        var wl = _get("sc_wlog", null);
        warLog = [];
        if (wl instanceof Lang.Array) {
            for (var wi = 0; wi < wl.size() && wi < 8; wi++) {
                if (wl[wi] instanceof Lang.String) { warLog.add(wl[wi]); }
            }
        }
        // Defence log + rival roster are appended keys: absent on every save
        // written before the war layer, so both simply load empty.
        defLog = _rowsOf(_get("sc_dlog", null), 6, Sc.DLOG_MAX);
        rivals = _rowsOf(_get("sc_riv", null), 2, Sc.RIV_MAX);
        rivalDay = _num("sc_rivday", 0, 0, 0x7FFFFFFF);

        gRes = new [Sc.R_N];
        for (var g = 0; g < Sc.R_N; g++) { gRes[g] = 0; }
        gSecs = 0; gPop = 0; newDay = false; gEvent = Sc.EV_NONE; gArt = -1;
        gDefN = 0; gDefHeld = 0;
        mailAlert = false; _mailPending = false; _mailElapsed = 0;
        lastClaimBonus = "";
        rWin = false; rFoeName = ""; rPtsDelta = 0; rTip = ""; rCredit = 0; rSci = 0;
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
        _set("sc_dres", dRes);
        _set("sc_dclaim", dailyClaimed);
        _set("sc_dcol", dailyCollected);
        _set("sc_draid", dRaid);
        _set("sc_stepb", stepBase);
        _set("sc_disc", discMask);
        _set("sc_art", artMask);
        _set("sc_amile", relicMask);
        _set("sc_spaid", streakPaid);
        _set("sc_pev", pendingEvent);
        _set("sc_mar", marines);
        _set("sc_tur", turrets);
        _set("sc_wpts", warPts);
        _set("sc_wwin", warWins);
        _set("sc_wlos", warLosses);
        _set("sc_wstr", warStreak);
        _set("sc_stance", raidStance);
        for (var i = 0; i < Sc.R_N; i++) { _set("sc_r" + i, res[i]); }
        for (var b = 0; b < Sc.B_N; b++) { _set("sc_b" + b, bLevel[b]); }
        for (var t = 0; t < Sc.T_N; t++) { _set("sc_t" + t, tech[t]); }
        for (var r = 0; r < Sc.RG_N; r++) { _set("sc_rg" + r, rgProg[r]); }
        _set("sc_log", log);
        _set("sc_wlog", warLog);
        _set("sc_dlog", defLog);
    }

    // ── Full reset (OPTIONS → Reset colony) ──────────────────────────────────
    // Wipes every progress key back to zero, keeping the player's settings
    // (sound/haptics, demo mode, explainer-seen). Fully guarded.
    function resetAll() {
        var keys = ["sc_started", "sc_born", "sc_last", "sc_pop", "sc_streak",
                    "sc_lday", "sc_dday", "sc_dup", "sc_dexp", "sc_dclaim",
                    "sc_dcol", "sc_disc", "sc_pev", "sc_log", "sc_lbday", "sc_stepb",
                    "sc_dres", "sc_art", "sc_amile", "sc_spaid",
                    "sc_draid", "sc_mar", "sc_tur", "sc_wpts", "sc_wwin", "sc_wlos",
                    "sc_wstr", "sc_stance", "sc_wlog", "sc_dlog", "sc_riv", "sc_rivday"];
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

    // ── Alien artifacts ───────────────────────────────────────────────────────
    // The payoff for exploring: every mapped region hands over one relic, rare
    // events and civilisation milestones hand over the rest. Purely a score +
    // collection set, so granting one can never unbalance production.
    function hasArt(i) {
        if (i < 0 || i >= Sc.A_N) { return false; }
        return (artMask & (1 << i)) != 0;
    }
    function grantArt(i) {
        if (i < 0 || i >= Sc.A_N || hasArt(i)) { return false; }
        artMask = artMask | (1 << i);
        gArt = i;
        _logAdd("Recovered " + Sc.aName(i) + " (" + Sc.aRarityName(Sc.aRarity(i)) + ")");
        return true;
    }
    function artifactsOwned() {
        var c = 0;
        for (var i = 0; i < Sc.A_N; i++) { if (hasArt(i)) { c++; } }
        return c;
    }
    function artifactScore() {
        var s = 0;
        for (var i = 0; i < Sc.A_N; i++) { if (hasArt(i)) { s += Sc.aWeight(i); } }
        return s;
    }
    function legendaryRelics() {
        var c = 0;
        for (var i = 0; i < Sc.A_N; i++) { if (hasArt(i) && Sc.aLegendary(i)) { c++; } }
        return c;
    }
    // Hand over the rarest relic the colony has not found yet, preferring the
    // band the player has actually earned so a first find is never a Mythic.
    hidden function _grantRandomArt(maxRarity) {
        if (maxRarity < 0) { maxRarity = 0; }
        if (maxRarity > 4) { maxRarity = 4; }
        var avail = [];
        for (var i = 0; i < Sc.A_N; i++) {
            if (!hasArt(i) && Sc.aRarity(i) <= maxRarity) { avail.add(i); }
        }
        if (avail.size() == 0) {
            for (var j = 0; j < Sc.A_N; j++) { if (!hasArt(j)) { avail.add(j); } }
        }
        if (avail.size() == 0) { return -1; }
        var pick = avail[_rand(avail.size())];
        grantArt(pick);
        return pick;
    }
    // One-shot civilisation-level relic grants. Each bit is claimed once ever,
    // so a level that is later re-crossed cannot farm the same reward twice.
    hidden function _checkRelicMilestones() {
        var civ = civLevel();
        if ((relicMask & 1) == 0 && civ >= Sc.CIV_RELIC_1) {
            relicMask = relicMask | 1;
            grantArt(Sc.A_MASK);
        }
        if ((relicMask & 2) == 0 && civ >= Sc.CIV_RELIC_2) {
            relicMask = relicMask | 2;
            grantArt(Sc.A_ECHO);
        }
    }

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
        gSecs = 0; gPop = 0; newDay = false; gEvent = Sc.EV_NONE; gArt = -1;
        gDefN = 0; gDefHeld = 0;
        mailAlert = false; _mailPending = false; _mailElapsed = 0;

        var td = today();
        if (td != lastDay) {
            newDay = true;
            if (lastDay != 0 && td == lastDay + 1) { streak += 1; }
            else { streak = 1; streakPaid = 0; }   // a broken run re-earns its milestones
            lastDay = td;
        }
        if (streak < 1) { streak = 1; }
        if (dailyDay != td) {
            dailyDay = td; dUpgrades = 0; dExpl = 0; dRes = 0; dRaid = 0;
            dailyClaimed = false; dailyCollected = false;
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

        // Real rival raids arrive via /inbox when the phone is up; offline we
        // still roll the local defence RNG so a disconnected watch feels alive.
        // Rivals raid AFTER production banks, so the skim comes off a stockpile
        // the player has actually been credited with rather than a stale one.
        if (Leaderboard.isPhoneConnected() && Leaderboard.loadUser() != null) {
            _mailPending = true;
            _mailElapsed = elapsed;
        } else {
            _resolveIncoming(elapsed);
        }

        _creditSteps();

        // Maybe fire a random event when enough time passed.
        if (elapsed > 2 * 3600 && pendingEvent == Sc.EV_NONE) {
            if (_rand(100) < 45) { _rollEvent(); }
        }

        _checkRelicMilestones();

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
            // A rare survey strike is the only random source of a relic, and
            // the band it can roll widens with how much of the planet is mapped.
            if (_rand(100) < 30) {
                _grantRandomArt(1 + regionsDiscovered() / 3);
            }
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
        _checkRelicMilestones();
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
            grantArt(Sc.rgArtifact(i));
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
        dRes += 1;
        _logAdd("Researched " + Sc.tName(i) + " Lv" + tech[i]);
        _checkRelicMilestones();
        save();
        return Sc.tName(i) + " -> Lv" + tech[i];
    }

    // ── Daily mission ──────────────────────────────────────────────────────────
    // Eight varieties so a week-plus of daily visits never repeats too soon.
    // Ids 0..3 keep the meaning they shipped with; id 7 is the war layer's
    // addition — the rotation only ever grows, never renumbers.
    function dailyId() {
        var d = dailyDay % Sc.DAILY_N;
        return (d < 0) ? 0 : d;
    }
    function dailyText() {
        var id = dailyId();
        if (id == 0) { return "Collect offline output"; }
        if (id == 1) { return "Upgrade a building"; }
        if (id == 2) { return "Walk 5000 steps"; }
        if (id == 3) { return "Run an expedition"; }
        if (id == 4) { return "Upgrade 3 structures"; }
        if (id == 5) { return "Research a technology"; }
        if (id == 6) { return "Run 3 expeditions"; }
        return "Launch a raid";
    }
    function dailyTarget() {
        var id = dailyId();
        if (id == 2) { return 5000; }
        if (id == 4) { return 3; }
        if (id == 6) { return 3; }
        return 1;
    }
    function dailyProgress() {
        var id = dailyId();
        if (id == 0) { return dailyCollected ? 1 : 0; }
        if (id == 1) { return dUpgrades > 0 ? 1 : 0; }
        if (id == 2) { var s = Sensors.getStepsToday(); return (s > 5000) ? 5000 : s; }
        if (id == 3) { return dExpl > 0 ? 1 : 0; }
        if (id == 4) { return (dUpgrades > 3) ? 3 : dUpgrades; }
        if (id == 5) { return dRes > 0 ? 1 : 0; }
        if (id == 6) { return (dExpl > 3) ? 3 : dExpl; }
        return dRaid > 0 ? 1 : 0;
    }
    function dailyComplete() { return dailyProgress() >= dailyTarget(); }

    // Streak bonus as a percentage of the base reward: +10% per consecutive
    // day beyond the first, capped at +100%.
    function streakBonusPct() {
        var p = (streak - 1) * Sc.STREAK_STEP;
        if (p < 0) { p = 0; }
        if (p > Sc.STREAK_CAP) { p = Sc.STREAK_CAP; }
        return p;
    }
    // Base daily payout, scaled off real progress (civ level plus two hours of
    // current output) so the reward never turns into pocket change late on.
    hidden function _dailyBase(r, flat, perCiv) {
        var v = flat + civLevel() * perCiv + _accrue(hourlyRate(r), 2 * 3600);
        if (v > Sc.RES_CAP) { v = Sc.RES_CAP; }
        return v;
    }
    function dailyReward(r) {
        var v = 0;
        if (r == Sc.R_SCI)      { v = _dailyBase(r, 120, 30); }
        else if (r == Sc.R_MIN) { v = _dailyBase(r, 200, 50); }
        else if (r == Sc.R_CRE) { v = _dailyBase(r, 50, 15); }
        else { return 0; }
        return _pct(v, 100 + streakBonusPct());
    }
    // Next streak milestone still unpaid in this run, or 0 when all are done.
    function nextStreakMilestone() {
        if (streakPaid < Sc.STREAK_M1) { return Sc.STREAK_M1; }
        if (streakPaid < Sc.STREAK_M2) { return Sc.STREAK_M2; }
        if (streakPaid < Sc.STREAK_M3) { return Sc.STREAK_M3; }
        if (streakPaid < Sc.STREAK_M4) { return Sc.STREAK_M4; }
        return 0;
    }
    // Milestone payouts ride on the same civ scale as the daily reward, so a
    // 30-day streak is still worth claiming on a mature colony.
    hidden function _mileScale(v) { return _pct(v, 100 + civLevel() * 20); }
    hidden function _payStreakMilestone() {
        var msg = "";
        if (streak >= Sc.STREAK_M1 && streakPaid < Sc.STREAK_M1) {
            streakPaid = Sc.STREAK_M1;
            _addRes(Sc.R_MIN, _mileScale(600)); _addRes(Sc.R_SCI, _mileScale(300));
            _logAdd("Streak 3 days - supply bonus");
            msg = "3-day streak bonus!";
        } else if (streak >= Sc.STREAK_M2 && streakPaid < Sc.STREAK_M2) {
            streakPaid = Sc.STREAK_M2;
            _addRes(Sc.R_SCI, _mileScale(800)); _addRes(Sc.R_CRE, _mileScale(400));
            var a1 = _grantRandomArt(2);
            _logAdd("Streak 7 days - artifact recovered");
            msg = (a1 >= 0) ? ("7-day streak: " + Sc.aName(a1) + "!") : "7-day streak bonus!";
        } else if (streak >= Sc.STREAK_M3 && streakPaid < Sc.STREAK_M3) {
            streakPaid = Sc.STREAK_M3;
            _addRes(Sc.R_MIN, _mileScale(1500)); _addRes(Sc.R_CRE, _mileScale(900));
            _logAdd("Streak 14 days - trade windfall");
            msg = "14-day streak bonus!";
        } else if (streak >= Sc.STREAK_M4 && streakPaid < Sc.STREAK_M4) {
            streakPaid = Sc.STREAK_M4;
            _addRes(Sc.R_SCI, _mileScale(3000)); _addRes(Sc.R_CRE, _mileScale(2000));
            if (population < popCap()) { population += 1; }
            var a2 = grantArt(Sc.A_SPARK) ? Sc.A_SPARK : _grantRandomArt(4);
            _logAdd("Streak 30 days - Origin Spark");
            msg = (a2 >= 0) ? ("30-day streak: " + Sc.aName(a2) + "!") : "30-day streak bonus!";
        }
        return msg;
    }
    function claimDaily() {
        if (dailyClaimed || !dailyComplete()) { return false; }
        dailyClaimed = true;
        _addRes(Sc.R_SCI, dailyReward(Sc.R_SCI));
        _addRes(Sc.R_MIN, dailyReward(Sc.R_MIN));
        _addRes(Sc.R_CRE, dailyReward(Sc.R_CRE));
        lastClaimBonus = _payStreakMilestone();
        save();
        return true;
    }

    // ── Offline storage buffer ────────────────────────────────────────────────
    // Production only banks up to OFFLINE_CAP, so the player needs to see how
    // full that buffer is before it starts wasting output.
    function offlineSecs() {
        var s = nowSec() - lastSec;
        if (s < 0) { s = 0; }
        if (s > Sc.OFFLINE_CAP) { s = Sc.OFFLINE_CAP; }
        return s;
    }
    function offlinePct() {
        if (Sc.OFFLINE_CAP <= 0) { return 0; }
        return offlineSecs() * 100 / Sc.OFFLINE_CAP;
    }
    function offlineCapHours() { return Sc.OFFLINE_CAP / 3600; }
    // How full the buffer was on the visit that just banked it — the number
    // that tells the player whether they left output on the table.
    function collectedPct() {
        if (Sc.OFFLINE_CAP <= 0) { return 0; }
        var s = gSecs;
        if (s < 0) { s = 0; }
        if (s > Sc.OFFLINE_CAP) { s = Sc.OFFLINE_CAP; }
        return s * 100 / Sc.OFFLINE_CAP;
    }

    // ── War (military economy + raids) ────────────────────────────────────────
    // A win/loss layer on top of the colony, never a crushing resource loss:
    // marines and turrets are bought once and kept forever, and a raid only
    // ever risks the small energy toll it costs to launch.
    function marineCap() {
        var c = Sc.MARINE_CAP_BASE + bLevel[Sc.B_HABITAT] * Sc.MARINE_CAP_HAB
              + bLevel[Sc.B_DEFENSE] * Sc.MARINE_CAP_DEF;
        return (c > Sc.MARINE_CAP_MAX) ? Sc.MARINE_CAP_MAX : c;
    }
    function turretCap() {
        var c = Sc.TURRET_CAP_BASE + bLevel[Sc.B_DEFENSE] * Sc.TURRET_CAP_DEF;
        return (c > Sc.TURRET_CAP_MAX) ? Sc.TURRET_CAP_MAX : c;
    }
    // [minerals, energy] for the NEXT marine — escalates gently per marine
    // already enlisted, same overflow-safe curve the buildings use.
    function marineCost() {
        return [Sc.escalate(Sc.MARINE_COST_MIN, marines, Sc.MARINE_COST_PCT, Sc.MARINE_COST_PCT),
                Sc.escalate(Sc.MARINE_COST_NRG, marines, Sc.MARINE_COST_PCT, Sc.MARINE_COST_PCT)];
    }
    // [minerals, science] for the NEXT turret.
    function turretCost() {
        return [Sc.escalate(Sc.DEFENSE_COST_MIN, turrets, Sc.DEFENSE_COST_PCT, Sc.DEFENSE_COST_PCT),
                Sc.escalate(Sc.DEFENSE_COST_SCI, turrets, Sc.DEFENSE_COST_PCT, Sc.DEFENSE_COST_PCT)];
    }
    function canAffordMarine() {
        var c = marineCost();
        return res[Sc.R_MIN] >= c[0] && res[Sc.R_NRG] >= c[1];
    }
    function canAffordTurret() {
        var c = turretCost();
        return res[Sc.R_MIN] >= c[0] && res[Sc.R_SCI] >= c[1];
    }
    function trainMarine() {
        if (marines >= marineCap()) { return "Need Habitat or Defense Grid upgrade"; }
        var c = marineCost();
        if (!canAffordMarine()) { return "Need more resources"; }
        _subRes(Sc.R_MIN, c[0]); _subRes(Sc.R_NRG, c[1]);
        marines += 1;
        if (marines == 1) { _logAdd("First marine enlisted"); }
        save();
        return "Marine recruited (" + marines + "/" + marineCap() + ")";
    }
    function buildTurret() {
        if (turrets >= turretCap()) { return "Need Defense Grid upgrade"; }
        var c = turretCost();
        if (!canAffordTurret()) { return "Need more resources"; }
        _subRes(Sc.R_MIN, c[0]); _subRes(Sc.R_SCI, c[1]);
        turrets += 1;
        if (turrets == 1) { _logAdd("First turret installed"); }
        save();
        return "Turret online (" + turrets + "/" + turretCap() + ")";
    }

    // Cycled from the WAR page — one flat trade-off between this colony's own
    // attack and defense power, left in place until changed again.
    function cycleStance() {
        raidStance = (raidStance + 1) % 3;
        save();
        return "Stance: " + Sc.stanceName(raidStance);
    }

    function attackPower() {
        var p = marines * 12 + bLevel[Sc.B_LAUNCH] * 8 + bLevel[Sc.B_DEFENSE] * 4 + civLevel() * 5;
        return p + Sc.stanceAtkBonus(raidStance);
    }
    function defensePower() {
        var p = turrets * 14 + bLevel[Sc.B_DEFENSE] * 10 + population / 2 + bLevel[Sc.B_SAT] * 3;
        return p + Sc.stanceDefBonus(raidStance);
    }

    function raidsLeft() {
        var n = Sc.RAID_CAP_PER_DAY - dRaid;
        return (n < 0) ? 0 : n;
    }
    // ── Rival roster ──────────────────────────────────────────────────────
    // Real colonies read off the War board once a day and cached. Everything
    // below works on the cache alone, so a player who never connects a phone
    // gets the same game with procedural opponents.
    function rivalsStale() { return rivalDay != today(); }
    // Called from the async fetch. Storing the day even for an empty result
    // keeps a game with no rivals yet from re-fetching on every launch.
    function setRivals(list) {
        var out = [];
        if (list instanceof Lang.Array) {
            for (var i = 0; i < list.size() && out.size() < Sc.RIV_MAX; i++) {
                var r = list[i];
                if (r instanceof Lang.Array && r.size() == 2) { out.add(r); }
            }
        }
        rivals = out;
        rivalDay = today();
        _set("sc_riv", rivals);
        _set("sc_rivday", rivalDay);
    }
    // A rival whose power sits inside the band, or -1. Real rivals cluster
    // around the player's own rating (the roster is built from the "near"
    // rows first), so this hits most of the time on a connected watch.
    hidden function _pickRival(lo, hi) {
        var hits = [];
        for (var i = 0; i < rivals.size(); i++) {
            var p = _rNum(rivals[i], 1);
            if (p >= lo && p <= hi) { hits.add(i); }
        }
        if (hits.size() == 0) { return -1; }
        return hits[_rand(hits.size())];
    }
    // A rival colony sized off THIS colony's own attack power, so raids stay
    // winnable but are never a guaranteed win. band FAIR favours the player;
    // RISK is a harder fight for a richer payout.
    //
    // A cached rival inside the band is used as-is, name AND power. When the
    // roster holds nobody at the player's weight class a real colony's name is
    // still used but the fight is sized procedurally — being matched against
    // the #1 Overlord because nobody else is cached is a bug, not a feature.
    function makeFoe(band) {
        var atk = attackPower();
        if (atk < 10) { atk = 10; }
        var lo = atk * Sc.raidBandLo(band) / 100;
        var hi = atk * Sc.raidBandHi(band) / 100;
        var pick = _pickRival(lo, hi);
        if (pick >= 0) {
            var pdef = _rNum(rivals[pick], 1);
            if (pdef < 5) { pdef = 5; }
            return { :name => _rStr(rivals[pick], 0), :def => pdef, :real => true };
        }
        var pct = Sc.raidBandLo(band) + _rand(Sc.raidBandHi(band) - Sc.raidBandLo(band) + 1);
        var def = atk * pct / 100;
        if (def < 5) { def = 5; }
        // Prefer a real colony's name over the flavour list whenever one is cached.
        if (rivals.size() > 0) {
            return { :name => _rStr(rivals[_rand(rivals.size())], 0), :def => def, :real => true };
        }
        return { :name => Sc.warFoeName(_rand(Sc.WAR_FOE_N)), :def => def, :real => false };
    }
    // Prefer a real colony's name over the flavour list whenever one is cached.
    hidden function _foeName() {
        if (rivals.size() > 0) { return _rStr(rivals[_rand(rivals.size())], 0); }
        return Sc.warFoeName(_rand(Sc.WAR_FOE_N));
    }
    // Launch a raid: win/loss only, decided by attackPower vs. the foe's
    // defense with a little fog-of-war on both rolls. NEVER touches buildings,
    // population or the resource stockpile beyond the flat energy toll.
    function raid(band) {
        if (raidsLeft() <= 0) { return "Fleet resting - back tomorrow"; }
        if (res[Sc.R_NRG] < Sc.RAID_COST_NRG) { return "Need " + Sc.RAID_COST_NRG + " energy"; }
        _subRes(Sc.R_NRG, Sc.RAID_COST_NRG);
        dRaid += 1;

        var foe = makeFoe(band);
        var atk = attackPower();
        var atkRoll = atk + _rand(atk / 3 + 1);
        var foeDef = foe[:def];
        var defRoll = foeDef + _rand(foeDef / 3 + 1);
        var win = atkRoll >= defRoll;

        var beforePts = warPts;
        var riskBonus = (band == Sc.RAID_BAND_RISK) ? 6 : 0;
        rWin = win; rFoeName = foe[:name]; rCredit = 0; rSci = 0;
        if (win) {
            warWins += 1;
            warStreak = (warStreak >= 0) ? warStreak + 1 : 1;
            var streakBonus = warStreak; if (streakBonus > 5) { streakBonus = 5; }
            var ptsGain = 10 + civLevel() / 2 + riskBonus + streakBonus;
            warPts += ptsGain;
            rPtsDelta = ptsGain;
            var cre = 30 + civLevel() * 4 + (band == Sc.RAID_BAND_RISK ? 20 : 0);
            var sci = 10 + civLevel() * 2 + (band == Sc.RAID_BAND_RISK ? 10 : 0);
            rCredit = _addRes(Sc.R_CRE, cre);
            rSci = _addRes(Sc.R_SCI, sci);
            rTip = "Marines held the line and brought back supplies.";
            _warLogAdd("W raid " + foe[:name]);
            if (warStreak == 3 || warStreak == 5 || warStreak == 10) {
                _logAdd("War streak " + warStreak + " - " + Sc.warRankName(warPts));
            }
        } else {
            warLosses += 1;
            warStreak = (warStreak <= 0) ? warStreak - 1 : -1;
            var ptsLoss = 6 + (band == Sc.RAID_BAND_RISK ? 4 : 0);
            if (ptsLoss > warPts) { ptsLoss = warPts; }
            warPts -= ptsLoss;
            rPtsDelta = -ptsLoss;
            rTip = "Reinforce the fleet and try again.";
            _warLogAdd("L vs " + foe[:name]);
        }
        var rankBefore = Sc.warRankName(beforePts);
        var rankAfter = Sc.warRankName(warPts);
        if (!rankBefore.equals(rankAfter)) {
            _logAdd((win ? "Promoted to " : "Demoted to ") + rankAfter);
        }
        // Tell the named rival they were raided — async inbox, never blocks play.
        try {
            if (foe[:real]) {
                RaidMail.notify(Sc.GAME_ID, foe[:name], "raid", win);
            }
        } catch (e) {}
        save();
        return win ? ("Victory over " + foe[:name] + "!") : ("Repelled by " + foe[:name]);
    }
    hidden function _warLogAdd(s) {
        var nl = [s];
        nl.addAll(warLog);
        if (nl.size() > 8) { nl = nl.slice(0, 8); }
        warLog = nl;
    }
    function warRecent() { return warLog; }

    // ── Incoming attacks ──────────────────────────────────────────────────
    // Real raids arrive via RaidMail (/inbox) when the phone is connected.
    // Offline (or when the fetch fails) we still roll a local defence RNG so
    // the war layer stays alive without a network. defensePower() decides
    // hold vs loss. Deliberately kept out of warLog and the colony history:
    // both cap at 8 entries and a week away would flush them.

    // PUBLIC — LbRaidInbox callback. `events` is an Array of Dictionaries
    // {id, from, kind, won, ts}; won=1 means the attacker beat us.
    function onRaidInbox(ok, events) {
        if (!ok) {
            if (_mailPending) {
                _resolveIncoming(_mailElapsed);
                _mailPending = false;
                if (gDefN > 0) { mailAlert = true; }
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
                _applyMailRaid(from, awon);
                n += 1;
                var id = e["id"];
                if (id instanceof Lang.Number && id > maxId) { maxId = id; }
            }
        }
        if (maxId > 0) { RaidMail.saveAck(maxId); }
        // Empty inbox while online = nobody came calling. Do not invent raids.
        if (n > 0) { mailAlert = true; save(); }
    }

    hidden function _applyMailRaid(from, attackerWon) {
        var td = today();
        gDefN += 1;
        if (!attackerWon) {
            warPts += Sc.DEF_HELD_PTS;
            gDefHeld += 1;
            _defLogAdd([td, 1, from, 0, 0, 0]);
            return;
        }
        var ptsLoss = Sc.DEF_LOST_PTS;
        if (ptsLoss > warPts) { ptsLoss = warPts; }
        warPts -= ptsLoss;
        var skim = _pct(res[Sc.R_MIN], Sc.DEF_SKIM_PCT);
        if (skim > Sc.DEF_SKIM_CAP) { skim = Sc.DEF_SKIM_CAP; }
        _subRes(Sc.R_MIN, skim);
        var lostMar = 0;
        if (marines > Sc.DEF_MARINE_MIN && _rand(100) < Sc.DEF_MARINE_PCT) {
            marines -= 1; lostMar = 1;
        }
        _defLogAdd([td, 0, from, ptsLoss, skim, lostMar]);
    }

    hidden function _resolveIncoming(elapsed) {
        // A colony that has never fought and owns no garrison is not a target.
        if (warWins + warLosses == 0 && marines == 0 && turrets == 0) { return; }
        var per = Sc.DEF_ROLL_HOURS * 3600;
        var rolls = elapsed / per;
        if (rolls > Sc.DEF_MAX_ROLLS) { rolls = Sc.DEF_MAX_ROLLS; }
        var td = today();
        for (var i = 0; i < rolls; i++) {
            if (_rand(100) >= Sc.DEF_CHANCE_PCT) { continue; }
            _resolveDefence(td);
        }
    }
    hidden function _resolveDefence(td) {
        var def = defensePower();
        if (def < 5) { def = 5; }
        var foe = _makeAttacker(def);
        var apow = foe[:pow];
        var defRoll = def + _rand(def / 3 + 1);
        var atkRoll = apow + _rand(apow / 3 + 1);
        gDefN += 1;
        if (defRoll >= atkRoll) {
            warPts += Sc.DEF_HELD_PTS;
            gDefHeld += 1;
            _defLogAdd([td, 1, foe[:name], 0, 0, 0]);
            return;
        }
        var ptsLoss = Sc.DEF_LOST_PTS;
        if (ptsLoss > warPts) { ptsLoss = warPts; }
        warPts -= ptsLoss;
        // A percentage of the stockpile under a hard ceiling: enough to notice
        // on a young colony, never enough to undo real progress.
        var skim = _pct(res[Sc.R_MIN], Sc.DEF_SKIM_PCT);
        if (skim > Sc.DEF_SKIM_CAP) { skim = Sc.DEF_SKIM_CAP; }
        _subRes(Sc.R_MIN, skim);
        // A casualty is logged as well as taken: a marine that silently vanished
        // from the roster reads as a bug, not as a raid.
        var lostMar = 0;
        if (marines > Sc.DEF_MARINE_MIN && _rand(100) < Sc.DEF_MARINE_PCT) {
            marines -= 1; lostMar = 1;
        }
        _defLogAdd([td, 0, foe[:name], ptsLoss, skim, lostMar]);
    }
    // The attacker is drawn from the cached roster at this colony's own weight
    // class; with no roster the raid is sized off defensePower() instead.
    hidden function _makeAttacker(def) {
        var pick = _pickRival(def * Sc.DEF_BAND_LO / 100, def * Sc.DEF_BAND_HI / 100);
        if (pick >= 0) {
            var p = _rNum(rivals[pick], 1);
            if (p < 5) { p = 5; }
            return { :name => _rStr(rivals[pick], 0), :pow => p };
        }
        var pct = Sc.DEF_BAND_LO + _rand(Sc.DEF_BAND_HI - Sc.DEF_BAND_LO + 1);
        var pw = def * pct / 100;
        if (pw < 5) { pw = 5; }
        return { :name => _foeName(), :pow => pw };
    }
    hidden function _defLogAdd(row) {
        var nl = [row];
        nl.addAll(defLog);
        if (nl.size() > Sc.DLOG_MAX) { nl = nl.slice(0, Sc.DLOG_MAX); }
        defLog = nl;
    }
    function defenceRecent() { return defLog; }
    function defenceHeldAt(i) {
        if (i < 0 || i >= defLog.size()) { return false; }
        return _rNum(defLog[i], 1) != 0;
    }
    // "3d ago  HELD vs Vega-9". Only the day NUMBER is persisted, so the line
    // still reads correctly on a save that has been running for a year.
    function defenceText(i) {
        if (i < 0 || i >= defLog.size()) { return ""; }
        var r = defLog[i];
        var ago = today() - _rNum(r, 0);
        var when = "today";
        if (ago > 999) { when = "long ago"; }
        else if (ago > 0) { when = ago + "d ago"; }
        var who = _rStr(r, 2);
        if (_rNum(r, 1) != 0) { return when + "  HELD vs " + who; }
        var tail = (_rNum(r, 5) > 0) ? " -1 marine" : "";
        var lost = _rNum(r, 4);
        if (lost > 0) { return when + "  LOST " + lost + "M vs " + who + tail; }
        return when + "  LOST vs " + who + tail;
    }
    // One short line for the WELCOME BACK overlay, or "" when the colony was
    // left alone. Keep it short: it shares a slot with the header subtitle.
    function defenceSummary() {
        if (gDefN <= 0) { return ""; }
        var s = "Raided " + gDefN + "x - ";
        if (gDefHeld >= gDefN) { return s + "held"; }
        if (gDefHeld <= 0) { return s + ((gDefN > 1) ? "all lost" : "lost"); }
        return s + gDefHeld + " held";
    }
    function defenceAllHeld() { return gDefN > 0 && gDefHeld >= gDefN; }

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
                "regions"   => regionsDiscovered(),
                "relics"    => artifactsOwned(),
                "warWins"   => warWins,
                "warLosses" => warLosses
            };
            Leaderboard.submitScoreBatch(Sc.GAME_ID, [
                { :score => civLevel(),   :variant => Sc.LB_CIV,     :meta => meta },
                { :score => population,   :variant => Sc.LB_COLONY,  :meta => meta },
                { :score => totalTech() + bLevel[Sc.B_LAB], :variant => Sc.LB_TECH, :meta => meta },
                { :score => daysAlive() + 1, :variant => Sc.LB_AGE,  :meta => meta },
                { :score => regionsDiscovered() * 100 + _expPct(), :variant => Sc.LB_EXPLORE, :meta => meta },
                { :score => artifactScore(), :variant => Sc.LB_RELIC, :meta => meta },
                { :score => warPts, :variant => Sc.LB_WAR, :meta => meta }
            ]);
        } catch (e) {}
    }
    hidden function _expPct() {
        var s = 0;
        for (var i = 0; i < Sc.RG_N; i++) { s += rgProg[i]; }
        return s / Sc.RG_N;
    }
}
