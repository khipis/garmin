// ═══════════════════════════════════════════════════════════════════════════
// ZombieModel.mc — Persistent state and the daily clock.
//
// There is no "run" any more. There is a base that exists whether or not the
// app is open, a night counter that only moves forward when the base holds,
// and one wave per calendar day that resolves itself at WAVE_HOUR local.
//
// The model owns three things the rest of the game asks about constantly:
//   * scrap and the defence levels it buys
//   * whether tonight's wave is due, and how long until the next one
//   * the result of the last wave, kept until the player has actually seen it
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Time;

class ZombieModel {
    var scrap;
    var dLevel;        // [Zs.D_N] defence levels

    var night;         // the night the base must survive next (1-based)
    var lastWaveDay;   // local day index of the most recently resolved wave
    var wallPct;       // wall integrity carried between nights, 0..100
    // A wave that started but has not been recorded — the app was closed part
    // way through watching it. Non-zero means one is owed.
    var pendingNight;

    // Last result, held until shown. `rState` is 0 none / 1 unseen / 2 seen.
    var rState;
    var rWin; var rNight; var rKills; var rTotal; var rWallPct; var rScrap;

    // Records
    var bestNight;     // furthest night survived
    var nightsHeld;    // lifetime wins
    var losses;
    var kills;         // lifetime

    // Activity accounting
    var stepBase;      // steps already converted today
    var stepDay;       // calendar day of stepBase
    var actDay;        // day the workout bonus was claimed
    var dayScrap;      // scrap earned from activity today (capped)
    var seenIntro;

    // The compound between waves
    var itemMask;      // salvage found, one bit per Zs.IT_*
    var chapSeen;      // chapters already written into the journal
    var pendingEvent;  // a daytime event waiting on an answer, or Zs.EV_NONE
    var log;           // Array<String>, newest first, capped at LOG_MAX
    var bornDay;       // day index the compound was founded

    // Transient (session only)
    var gScrap; var gSteps; var gItem; var gEvent; var gEvText;

    static const LOG_MAX = 10;

    function initialize() { _load(); }

    hidden function _get(k, def) {
        try {
            var v = Application.Storage.getValue(k);
            if (v != null) { return v; }
        } catch (e) {}
        return def;
    }
    hidden function _set(k, v) { try { Application.Storage.setValue(k, v); } catch (e) {} }
    hidden function _del(k) { try { Application.Storage.deleteValue(k); } catch (e) {} }
    hidden function _num(k, def, lo, hi) {
        var v = _get(k, def);
        if (!(v instanceof Lang.Number)) { return def; }
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    hidden function _load() {
        scrap      = _num("zs_scrap", 0, 0, 2000000000);
        night      = _num("zs_night", 1, 1, 99999);
        wallPct    = _num("zs_wall", 100, 0, 100);
        bestNight  = _num("zs_best", 0, 0, 99999);
        nightsHeld = _num("zs_held", 0, 0, 2000000000);
        losses     = _num("zs_lost", 0, 0, 2000000000);
        kills      = _num("zs_kills", 0, 0, 2000000000);
        stepBase   = _num("zs_stepb", 0, 0, 2000000000);
        stepDay    = _num("zs_stepd", 0, 0, 9999999);
        actDay     = _num("zs_actd", 0, 0, 9999999);
        dayScrap   = _num("zs_dscrap", 0, 0, 999999);
        seenIntro  = _num("zs_intro", 0, 0, 1) == 1;
        pendingNight = _num("zs_pend", 0, 0, 99999);
        itemMask   = _num("zs_items", 0, 0, 0x7FFFFFFF);
        chapSeen   = _num("zs_chap", 0, 0, 0x7FFFFFFF);
        pendingEvent = _num("zs_ev", Zs.EV_NONE, -1, Zs.EV_N - 1);
        bornDay    = _num("zs_born", 0, 0, 9999999);
        log        = _strings(_get("zs_log", null));

        rState   = _num("zs_rst", 0, 0, 2);
        rWin     = _num("zs_rwin", 0, 0, 1) == 1;
        rNight   = _num("zs_rn", 0, 0, 99999);
        rKills   = _num("zs_rk", 0, 0, 99999);
        rTotal   = _num("zs_rt", 0, 0, 99999);
        rWallPct = _num("zs_rw", 0, 0, 100);
        rScrap   = _num("zs_rs", 0, 0, 999999);

        dLevel = new [Zs.D_N];
        for (var i = 0; i < Zs.D_N; i++) {
            dLevel[i] = _num("zs_d" + i, 0, 0, Zs.D_LVL_MAX);
        }

        // No wave day on record means either a fresh install or a save from
        // the arcade build. Either way the next wave is the next WAVE_HOUR:
        // dropping a player straight into a night they had no chance to
        // prepare for is a poor first thirty seconds.
        var stored = _get("zs_wday", null);
        if (stored instanceof Lang.Number) {
            lastWaveDay = stored;
        } else {
            lastWaveDay = _pastWaveHour() ? dayIndex() : dayIndex() - 1;
        }

        if (_num("zs_v", 0, 0, 99) < 2) { _migrate(); }
        if (bornDay == 0) {
            bornDay = dayIndex();
            _logAdd("Moved in. Boarded every window.");
            _set("zs_born", bornDay);
        }
        gScrap = 0; gSteps = 0; gItem = -1;
        gEvent = Zs.EV_NONE; gEvText = null;
    }

    // Storage hands back whatever was written, which after a bad shutdown can
    // be a half-written array. Anything that is not a string is dropped rather
    // than crashing the journal screen on open.
    hidden function _strings(v) {
        var out = [];
        if (v instanceof Lang.Array) {
            for (var i = 0; i < v.size() && out.size() < LOG_MAX; i++) {
                if (v[i] instanceof Lang.String) { out.add(v[i]); }
            }
        }
        return out;
    }

    // The arcade build sold weapons and six bunker modules. Those levels were
    // paid for with real walking, so they are carried across rather than
    // wiped: each old module maps onto its closest defence and every unlocked
    // weapon is refunded at what it cost.
    hidden function _migrate() {
        var old = new [6];
        var any = false;
        for (var i = 0; i < 6; i++) {
            old[i] = _num("zs_m" + i, 0, 0, Zs.D_LVL_MAX);
            if (old[i] > 0) { any = true; }
        }
        if (any) {
            _lift(Zs.D_MG, old[0]);        // FIREPOWER  → the nest
            _lift(Zs.D_WALL, old[1]);      // BARRICADE  → walls
            _lift(Zs.D_RIFLE, old[2]);     // AMMO BELT  → your rifle
            _lift(Zs.D_RIFLE, old[3]);     // STEADY HANDS
            _lift(Zs.D_REPAIR, old[4]);    // MEDKITS    → auto-repair
            _lift(Zs.D_SALVAGE, old[5]);   // SCAVENGING → salvage
        }
        var wpns = _num("zs_wpns", 1, 0, 255);
        var refund = [0, 900, 1600, 2600];
        for (var b = 1; b < 4; b++) {
            if ((wpns & (1 << b)) != 0) { scrap += refund[b]; }
        }
        var oldBest = _num("zs_bestw", 0, 0, 99999);
        if (oldBest > bestNight) { bestNight = oldBest; }

        // Night 1 has to be winnable, and a base with no guns at all cannot
        // kill anything: the horde would simply eat the wall on a long enough
        // timer, every time, forever. So everybody starts with a nest.
        if (fortScore() == 0) { dLevel[Zs.D_MG] = 1; }

        var dead = ["zs_wpns", "zs_load", "zs_combo", "zs_runs", "zs_waves",
                    "zs_bestw", "zs_lbday"];
        for (var k = 0; k < dead.size(); k++) { _del(dead[k]); }
        for (var u = 0; u < 6; u++) { _del("zs_m" + u); }
        _set("zs_v", 2);
        save();
    }

    hidden function _lift(idx, lvl) {
        if (lvl > dLevel[idx]) {
            dLevel[idx] = lvl > Zs.D_LVL_MAX ? Zs.D_LVL_MAX : lvl;
        }
    }

    // ── The journal ─────────────────────────────────────────────────────────
    // Ten lines, newest first. It is the only place the game keeps a record of
    // anything that is not a number, and it is what makes a week of play read
    // as one story rather than seven unrelated evenings.
    function logAdd(s) { _logAdd(s); }
    hidden function _logAdd(s) {
        if (!(s instanceof Lang.String)) { return; }
        var nl = ["D" + dayNo().format("%d") + " " + s];
        if (log != null) { nl.addAll(log); }
        if (nl.size() > LOG_MAX) { nl = nl.slice(0, LOG_MAX); }
        log = nl;
    }
    // Days since the compound was founded, 1-based, for journal datelines.
    function dayNo() {
        var d = dayIndex() - bornDay + 1;
        return d < 1 ? 1 : d;
    }

    // ── Chapters ────────────────────────────────────────────────────────────
    function chapter() { return Zs.chapterAt(night); }
    // Called after a night is recorded: if the wall held far enough to move
    // into a new band, the journal says so once and never again.
    hidden function _checkChapter() {
        var c = chapter();
        var bit = 1 << c;
        if ((chapSeen & bit) != 0) { return; }
        chapSeen = chapSeen | bit;
        if (c > 0) { _logAdd(Zs.chapterName(c) + " begins."); }
    }

    // ── Salvage ─────────────────────────────────────────────────────────────
    function hasItem(i) {
        if (i < 0 || i >= Zs.IT_N) { return false; }
        return (itemMask & (1 << i)) != 0;
    }
    function itemsFound() {
        var n = 0;
        for (var i = 0; i < Zs.IT_N; i++) { if (hasItem(i)) { n += 1; } }
        return n;
    }
    function grantItem(i) {
        if (i < 0 || i >= Zs.IT_N || hasItem(i)) { return false; }
        itemMask = itemMask | (1 << i);
        gItem = i;
        _logAdd("Found the " + Zs.itName(i) + ".");
        return true;
    }
    // Pick something not already on the shelf, no rarer than the band the
    // player has earned. Better finds are gated on nights survived rather than
    // luck alone, so a first week cannot hand out the serum.
    hidden function _rollFind(maxRarity) {
        var pool = [];
        for (var i = 0; i < Zs.IT_N; i++) {
            if (!hasItem(i) && Zs.itRarity(i) <= maxRarity) { pool.add(i); }
        }
        if (pool.size() == 0) { return false; }
        return grantItem(pool[_rand(pool.size())]);
    }
    hidden function _rarityBand() {
        if (bestNight >= 45) { return Zs.R_RELIC; }
        if (bestNight >= 25) { return Zs.R_RARE; }
        if (bestNight >= 10) { return Zs.R_UNCOMMON; }
        return Zs.R_COMMON;
    }

    // Total of one effect category across everything found, as a percentage
    // (or a flat number for plating). Every screen and the simulation read the
    // shelf through here, so an item can never be applied twice.
    function itemBonus(kind) {
        var s = 0;
        for (var i = 0; i < Zs.IT_N; i++) {
            if (hasItem(i) && Zs.itEffectKind(i) == kind) { s += Zs.itEffectAmt(i); }
        }
        return s;
    }

    hidden function _rand(n) {
        if (n <= 1) { return 0; }
        try { return Math.rand() % n; } catch (e) {}
        return 0;
    }

    // ── Daytime events ──────────────────────────────────────────────────────
    // Something happened while the app was shut. Two of the five ask a
    // question and wait; the rest have already happened by the time they are
    // read out at dawn.
    hidden function _rollEvent() {
        var e = _rand(Zs.EV_N);
        if (Zs.evHasChoice(e)) {
            pendingEvent = e;
            return;
        }
        gEvent = e;
        if (e == Zs.EV_CACHE) {
            var pay = 40 + _rand(60) + night * 3;
            scrap += pay; gScrap += pay;
            gEvText = "+" + pay.format("%d") + " scrap";
            _logAdd("A cache under the floor. +" + pay.format("%d") + ".");
        } else if (e == Zs.EV_RATS) {
            var loss = scrap / 12;
            if (loss > 120) { loss = 120; }
            scrap -= loss;
            if (scrap < 0) { scrap = 0; }
            gEvText = loss > 0 ? "-" + loss.format("%d") + " scrap" : "Nothing left to spoil";
            _logAdd("Rats in the stores. -" + loss.format("%d") + ".");
        } else {
            // The crew went scavenging. Usually scrap, sometimes something
            // that goes on the shelf instead.
            if (_rand(100) < 30 && _rollFind(_rarityBand())) {
                gEvText = "They brought back " + Zs.itName(gItem);
            } else {
                var got = 30 + _rand(50);
                scrap += got; gScrap += got;
                gEvText = "+" + got.format("%d") + " scrap";
                _logAdd("The crew came back with " + got.format("%d") + ".");
            }
        }
    }

    // Answer a pending event. `takeIt` is the first of the two options.
    function resolveEvent(takeIt) {
        var e = pendingEvent;
        pendingEvent = Zs.EV_NONE;
        gEvent = e;
        if (e == Zs.EV_STRANGER) {
            if (takeIt) {
                // Another pair of hands on the wall, paid for in stores.
                var cost = 60;
                if (cost > scrap) { cost = scrap; }
                scrap -= cost;
                wallPct += 12;
                if (wallPct > 100) { wallPct = 100; }
                gEvText = "He works. Wall shored up.";
                _logAdd("Took in a stranger. He can work.");
            } else {
                gEvText = "He walked back into the street.";
                _logAdd("Turned a man away at the gate.");
            }
        } else if (e == Zs.EV_SIGNAL) {
            if (takeIt) {
                // Going out is the only gamble in the game, and it is small.
                if (_rand(100) < 55 && _rollFind(_rarityBand())) {
                    gEvText = "She had the " + Zs.itName(gItem) + ".";
                } else {
                    var hurt = 10 + _rand(12);
                    wallPct -= hurt;
                    if (wallPct < 20) { wallPct = 20; }
                    gEvText = "Nobody there. Lost a day of work.";
                    _logAdd("Followed a voice. Found an empty room.");
                }
            } else {
                var pay = 25 + _rand(25);
                scrap += pay; gScrap += pay;
                gEvText = "Stayed in. Stripped the east wing.";
                _logAdd("Ignored the radio. Stripped the east wing.");
            }
        }
        save();
    }

    function save() {
        _set("zs_items", itemMask);
        _set("zs_chap", chapSeen);
        _set("zs_ev", pendingEvent);
        _set("zs_born", bornDay);
        _set("zs_log", log);
        _set("zs_scrap", scrap);
        _set("zs_night", night);
        _set("zs_wall", wallPct);
        _set("zs_best", bestNight);
        _set("zs_held", nightsHeld);
        _set("zs_lost", losses);
        _set("zs_kills", kills);
        _set("zs_stepb", stepBase);
        _set("zs_stepd", stepDay);
        _set("zs_actd", actDay);
        _set("zs_dscrap", dayScrap);
        _set("zs_intro", seenIntro ? 1 : 0);
        _set("zs_wday", lastWaveDay);
        _set("zs_pend", pendingNight);
        _set("zs_rst", rState);
        _set("zs_rwin", rWin ? 1 : 0);
        _set("zs_rn", rNight);
        _set("zs_rk", rKills);
        _set("zs_rt", rTotal);
        _set("zs_rw", rWallPct);
        _set("zs_rs", rScrap);
        for (var i = 0; i < Zs.D_N; i++) { _set("zs_d" + i, dLevel[i]); }
    }

    function resetAll() {
        var keys = ["zs_scrap", "zs_night", "zs_wall", "zs_best", "zs_held",
                    "zs_lost", "zs_kills", "zs_stepb", "zs_stepd", "zs_actd",
                    "zs_dscrap", "zs_intro", "zs_wday", "zs_v", "zs_pend",
                    "zs_rst", "zs_rwin", "zs_rn", "zs_rk", "zs_rt", "zs_rw",
                    "zs_rs", "zs_items", "zs_chap", "zs_ev", "zs_log",
                    "zs_born",
                    // arcade-era keys, in case a reset follows a migration
                    "zs_wpns", "zs_load", "zs_combo", "zs_runs", "zs_waves",
                    "zs_bestw", "zs_lbday"];
        for (var i = 0; i < keys.size(); i++) { _del(keys[i]); }
        for (var d = 0; d < Zs.D_N; d++) { _del("zs_d" + d); }
        for (var u = 0; u < 8; u++) { _del("zs_m" + u); }
        _load();
        _set("zs_v", 2);
    }

    // ── The clock ───────────────────────────────────────────────────────────
    // Day index and the wave moment are both taken from *local* midnight, so
    // the countdown lines up with the player's own evening rather than UTC.
    function dayIndex() {
        try { return Time.today().value() / 86400; } catch (e) {}
        return 0;
    }
    hidden function _waveAt() {
        try { return Time.today().value() + Zs.WAVE_HOUR * 3600; } catch (e) {}
        return 0;
    }
    hidden function _pastWaveHour() {
        try { return Time.now().value() >= _waveAt(); } catch (e) {}
        return false;
    }

    // Seconds until the next wave lands. Once tonight's has gone by, this
    // rolls to tomorrow's on its own.
    function secsToWave() {
        try {
            var now = Time.now().value();
            var at = _waveAt();
            if (now < at) { return at - now; }
            return at + 86400 - now;
        } catch (e) {}
        return 0;
    }

    // True when a wave has come due and has not been resolved yet. This is the
    // only thing that starts a night — there is no button.
    function waveDue() {
        if (!_pastWaveHour()) { return false; }
        return lastWaveDay < dayIndex();
    }

    // ── Shop ────────────────────────────────────────────────────────────────
    function upgradeCost(i) {
        var c = Zs.dCost(i, dLevel[i]);
        var off = itemBonus(Zs.EF_COST);
        if (off > 0) { c = c * (100 - off) / 100; }
        return c < 1 ? 1 : c;
    }
    function canUpgrade(i) {
        if (i < 0 || i >= Zs.D_N) { return false; }
        if (dLevel[i] >= Zs.D_LVL_MAX) { return false; }
        return scrap >= upgradeCost(i);
    }
    function upgrade(i) {
        if (!canUpgrade(i)) { return false; }
        scrap -= upgradeCost(i);
        dLevel[i] += 1;
        save();
        return true;
    }
    function fortScore() { return Zs.fortRating(dLevel); }

    // ── Activity → scrap ────────────────────────────────────────────────────
    // The only income in the game. Everything else is spending.
    function collectOffline() {
        gScrap = 0; gSteps = 0; gItem = -1;
        gEvent = Zs.EV_NONE; gEvText = null;
        var td = dayIndex();
        var newDay = (stepDay != td);
        if (newDay) {
            stepDay = td;
            stepBase = 0;
            dayScrap = 0;
        }
        var mul = Zs.salvagePct(dLevel[Zs.D_SALVAGE]) + itemBonus(Zs.EF_SALVAGE);
        var steps = Sensors.getStepsToday();
        if (steps < stepBase) { stepBase = 0; }
        var delta = steps - stepBase;
        if (delta > 0) {
            var gained = delta / Zs.STEPS_PER_SCRAP;
            if (gained > 0) {
                if (dayScrap + gained > Zs.DAILY_CAP) { gained = Zs.DAILY_CAP - dayScrap; }
                if (gained > 0) {
                    dayScrap += gained;
                    stepBase += gained * Zs.STEPS_PER_SCRAP;
                    gSteps += gained * Zs.STEPS_PER_SCRAP;
                    var paid = gained * mul / 100;
                    scrap += paid;
                    gScrap += paid;
                }
            }
        }
        if (actDay != td) {
            var mins = Sensors.getActivityMinutes();
            if (mins > 0) {
                var bonus = mins * Zs.ACT_MIN_BONUS;
                if (bonus > 200) { bonus = 200; }
                bonus = bonus * mul / 100;
                scrap += bonus;
                gScrap += bonus;
                actDay = td;
            }
        }
        // One thing happens in the compound per day, at most, and only if
        // nothing is already waiting on an answer. Tying it to the day rather
        // than to elapsed time means it cannot be farmed by reopening.
        if (newDay && pendingEvent == Zs.EV_NONE && seenIntro && _rand(100) < 55) {
            _rollEvent();
        }
        save();
    }

    // ── Resolving a night ───────────────────────────────────────────────────
    // Spend the day the moment the wave starts, before a single zombie has
    // been drawn. Otherwise watching a night go badly and force-quitting would
    // hand back a second attempt, and the tension the game runs on depends on
    // tonight being the only tonight.
    function beginWave() {
        lastWaveDay = dayIndex();
        pendingNight = night;
        save();
    }

    // `res` is whatever BattleSim produced.
    function recordWave(res) {
        lastWaveDay = dayIndex();
        pendingNight = 0;
        rState   = 1;
        rWin     = res.win;
        rNight   = night;
        rKills   = res.kills;
        rTotal   = res.total;
        rWallPct = res.wallPct;
        rScrap   = res.scrap;

        kills += res.kills;
        scrap += res.scrap;

        if (res.win) {
            nightsHeld += 1;
            if (night > bestNight) { bestNight = night; }
            night += 1;
            // A held wall is patched back up overnight; auto-repair decides
            // how much of the damage the crew gets to before dusk.
            var rep = Zs.repairPct(dLevel[Zs.D_REPAIR]) + itemBonus(Zs.EF_REPAIR);
            if (rep > 95) { rep = 95; }
            wallPct = res.wallPct + (100 - res.wallPct) * rep / 100;
            if (wallPct > 100) { wallPct = 100; }
            if (wallPct < 25) { wallPct = 25; }
            _logAdd("Held night " + rNight.format("%d") + ". "
                    + rKills.format("%d") + " down.");
            // Picking over what the horde left is the main way the shelf
            // fills. A night you did not survive pays nothing but scrap.
            if (_rand(100) < 34) { _rollFind(_rarityBand()); }
            _checkChapter();
        } else {
            losses += 1;
            // The crew has all day to rebuild, so a lost night costs the
            // night and nothing else. Sending the player back into the same
            // wave behind a half-ruined wall was the one thing that turned a
            // setback into a spiral: every retry was weaker than the attempt
            // that had already failed, and stalls ran for weeks instead of
            // days. Losing is supposed to cost you time, not compound.
            wallPct = 100;
            _logAdd("Overrun on night " + rNight.format("%d") + ". Rebuilt by dusk.");
        }
        save();
        submitScores();
    }

    // The result screen has been read; stop offering it.
    function ackResult() {
        if (rState == 1) { rState = 2; save(); }
    }

    function submitScores() {
        try {
            var meta = {
                "night" => bestNight,
                "fort"  => fortScore(),
                "kills" => kills,
                "waves" => nightsHeld
            };
            Leaderboard.submitScoreBatch(Zs.GAME_ID, [
                { :score => bestNight,  :variant => Zs.LB_DAY,   :meta => meta },
                { :score => fortScore(), :variant => Zs.LB_FORT,  :meta => meta },
                { :score => kills,      :variant => Zs.LB_KILLS, :meta => meta },
                { :score => nightsHeld, :variant => Zs.LB_WAVES, :meta => meta }
            ]);
        } catch (e) {}
    }
}
