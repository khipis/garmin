// ═══════════════════════════════════════════════════════════════════════════
// ProgressionManager.mc — The long game: profile, streak, energy and unlocks.
//
// Two records live in Storage:
//   ds_prof  lifetime profile — challenges, baskets, swishes, best score,
//            day streak, yesterday's score
//   ds_day   today only — best score, attempts used, whether it was submitted
//
// The daily record rolls over on the first read of a new day, which is also
// where the day streak is resolved and yesterday's score is preserved for the
// "beat your yesterday" line.
//
// Coins / XP / cosmetic ownership are delegated to the shared Progress module
// so a future shop can sell exactly the same items this file grants for free.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;

// Cosmetics. The unlock ids are stable strings — never renumber them.
const DS_BALLS  = ["ball_classic", "ball_gold", "ball_flame"];
const DS_COURTS = ["court_street", "court_night", "court_beach", "court_arena"];

module ProgressionManager {

    // ── Records ─────────────────────────────────────────────────────────────
    function profile() as Lang.Dictionary { return DsUtil.getDict(DS_K_PROF); }

    // Today's record, rolling the day over when the date has changed.
    function day() as Lang.Dictionary {
        var d   = DsUtil.getDict(DS_K_DAY);
        var key = DsUtil.todayKey();
        if (DsUtil.str(d, "d").equals(key)) { return d; }

        // New day: carry the old best across as "yesterday" and reset.
        var p = profile();
        p["yb"] = DsUtil.num(d, "best", 0);
        DsUtil.setDict(DS_K_PROF, p);

        d = { "d" => key, "best" => 0, "used" => 0, "plays" => 0, "sub" => 0 };
        DsUtil.setDict(DS_K_DAY, d);
        return d;
    }

    function todayBest()  as Lang.Number { return DsUtil.num(day(), "best", 0); }
    function todayPlays() as Lang.Number { return DsUtil.num(day(), "plays", 0); }
    function yesterday()  as Lang.Number { return DsUtil.num(profile(), "yb", 0); }
    function bestEver()   as Lang.Number { return DsUtil.num(profile(), "bs", 0); }
    function streakDays() as Lang.Number { return DsUtil.num(profile(), "st", 0); }
    function bestStreak() as Lang.Number { return DsUtil.num(profile(), "sb", 0); }
    function completed()  as Lang.Number { return DsUtil.num(profile(), "ch", 0); }
    function baskets()    as Lang.Number { return DsUtil.num(profile(), "bk", 0); }
    function swishes()    as Lang.Number { return DsUtil.num(profile(), "sw", 0); }

    // ── Energy = attempts at today's ranked challenge ────────────────────────
    function energyMax()  as Lang.Number { return FitnessIntegration.dailyEnergy(); }

    function energyLeft() as Lang.Number {
        var left = energyMax() - DsUtil.num(day(), "used", 0);
        if (left < 0) { left = 0; }
        return left;
    }

    function spendEnergy() as Void {
        var d = day();
        d["used"] = DsUtil.num(d, "used", 0) + 1;
        DsUtil.setDict(DS_K_DAY, d);
    }

    // ── Cosmetics ───────────────────────────────────────────────────────────
    // Index 0 of each list is always free; the rest have to be earned. The
    // getters clamp the player's stored choice to what they actually own, so a
    // reset or a fresh install can never render a locked skin.
    function ownsItem(id as Lang.String) as Lang.Boolean {
        if (id.equals(DS_BALLS[0]) || id.equals(DS_COURTS[0])) { return true; }
        try { return Progress.owns(id); } catch (e) {}
        return false;
    }

    function ballIndex() as Lang.Number {
        var i = DsUtil.optIndex(DS_K_BALL, 0, DS_BALLS.size());
        if (!ownsItem(DS_BALLS[i])) { return 0; }
        return i;
    }

    function courtIndex() as Lang.Number {
        var i = DsUtil.optIndex(DS_K_COURT, 0, DS_COURTS.size());
        if (!ownsItem(DS_COURTS[i])) { return 0; }
        return i;
    }

    // If the player has picked a cosmetic they have not earned yet, say what
    // it costs. The getters above quietly fall back to the free skin, and a
    // silent fallback with no explanation reads as a broken setting.
    function lockHint() as Lang.String {
        var ci = DsUtil.optIndex(DS_K_COURT, 0, DS_COURTS.size());
        if (ci > 0 && !ownsItem(DS_COURTS[ci])) {
            if (ci == 1) { return "NIGHT VENUE: 3 day streak"; }
            if (ci == 2) { return "SUNSET VENUE: 7 challenges"; }
            return "STADIUM: 20 challenges";
        }
        var bi = DsUtil.optIndex(DS_K_BALL, 0, DS_BALLS.size());
        if (bi > 0 && !ownsItem(DS_BALLS[bi])) {
            return (bi == 1) ? "GOLDEN BALL: 25 perfect shots"
                             : "FLAME BALL: 150 scores";
        }
        return "";
    }

    // Trophy tier from lifetime completed challenges — the medal shelf.
    function trophy() as Lang.String {
        var c = completed();
        if (c >= 100) { return "PLATINUM"; }
        if (c >= 50)  { return "GOLD"; }
        if (c >= 20)  { return "SILVER"; }
        if (c >= 5)   { return "BRONZE"; }
        return "ROOKIE";
    }

    // ── Recording a finished run ────────────────────────────────────────────
    // Returns a Dictionary the result screen renders:
    //   { "newBest":Bool, "dayBest":Number, "streak":Number,
    //     "coins":Number, "unlocked":Array<String> }
    // `ranked` is false for practice: it still trains the player's stats but
    // never spends energy, never submits and never counts as a challenge.
    function recordRun(ch as DsChallenge, score as Lang.Number,
                       made as Lang.Number, swished as Lang.Number,
                       ranked as Lang.Boolean) as Lang.Dictionary {
        // Roll the day over FIRST: day() may itself rewrite the profile to
        // preserve yesterday's score, and a stale copy would undo that write.
        var today = day();

        var p = profile();
        p["bk"] = DsUtil.num(p, "bk", 0) + made;
        p["sw"] = DsUtil.num(p, "sw", 0) + swished;
        p["pl"] = DsUtil.num(p, "pl", 0) + 1;

        var newBest = false;
        var dayBest = 0;
        var streak  = DsUtil.num(p, "st", 0);

        if (ranked) {
            p["ch"] = DsUtil.num(p, "ch", 0) + 1;
            if (score > DsUtil.num(p, "bs", 0)) { p["bs"] = score; }

            // Day streak: one step per calendar day the challenge is played.
            var dn   = DsUtil.dayNumber();
            var lastN = DsUtil.num(p, "ln", -1);
            if (lastN != dn) {
                if (lastN >= 0 && (dn - lastN) == 1) { streak = streak + 1; }
                else                                 { streak = 1; }
                p["st"] = streak;
                p["ln"] = dn;
                p["ld"] = DsUtil.todayKey();
                if (streak > DsUtil.num(p, "sb", 0)) { p["sb"] = streak; }
            }

            var d = today;
            dayBest = DsUtil.num(d, "best", 0);
            if (score > dayBest) { dayBest = score; newBest = true; }
            d["best"]  = dayBest;
            d["plays"] = DsUtil.num(d, "plays", 0) + 1;
            DsUtil.setDict(DS_K_DAY, d);
        }

        DsUtil.setDict(DS_K_PROF, p);

        // Coins + XP: playing earns, shooting well earns more. Fitness adds a
        // once-a-day cosmetic bonus on top (never score).
        var coins = made * 2 + swished * 3;
        if (ranked) { coins = coins + 5; }
        try {
            Progress.addCoins(coins);
            Progress.addXp(made * 3 + swished * 5 + (ranked ? 10 : 0));
        } catch (e) {}

        return {
            "newBest"  => newBest,
            "dayBest"  => dayBest,
            "streak"   => streak,
            "coins"    => coins,
            "unlocked" => _checkUnlocks(p, streak)
        };
    }

    // Grant anything the player just earned. Returns the display names of the
    // items unlocked by THIS run so the result screen can celebrate them.
    //
    // The curve deliberately front-loads: something new lands on about day 3,
    // day 5 and day 7, then the tail stretches out to a few weeks. A reward
    // schedule whose first payout is two months away is not a reward
    // schedule, it is a wall.
    function _checkUnlocks(p as Lang.Dictionary,
                           streak as Lang.Number) as Lang.Array {
        var got = [];
        try {
            if (Progress.unlockIfReached("court_night", streak, 3)) {
                got.add("NIGHT VENUE");
            }
            if (Progress.unlockIfReached("ball_gold", DsUtil.num(p, "sw", 0), 25)) {
                got.add("GOLDEN BALL");
            }
            if (Progress.unlockIfReached("court_beach", DsUtil.num(p, "ch", 0), 7)) {
                got.add("SUNSET VENUE");
            }
            if (Progress.unlockIfReached("court_arena", DsUtil.num(p, "ch", 0), 20)) {
                got.add("STADIUM");
            }
            if (Progress.unlockIfReached("ball_flame", DsUtil.num(p, "bk", 0), 150)) {
                got.add("FLAME BALL");
            }
        } catch (e) {}
        return got;
    }

    // Claim the once-per-day fitness coin drop. Returns the amount granted
    // (0 when it has already been claimed today).
    function claimFitnessBonus() as Lang.Number {
        var d = day();
        if (DsUtil.num(d, "fit", 0) > 0) { return 0; }
        var c = FitnessIntegration.bonusCoins();
        if (c <= 0) { return 0; }
        try { Progress.addCoins(c); } catch (e) {}
        d["fit"] = c;
        DsUtil.setDict(DS_K_DAY, d);
        return c;
    }

    // Wipe everything the player has built — behind the OPTIONS confirmation.
    function resetAll() as Void {
        try { Application.Storage.deleteValue(DS_K_PROF); } catch (e) {}
        try { Application.Storage.deleteValue(DS_K_DAY); } catch (e) {}
        try {
            Application.Storage.deleteValue(Progress.OWN_KEY);
            Application.Storage.deleteValue(Progress.XP_KEY);
            Application.Storage.deleteValue(Progress.COINS_KEY);
        } catch (e) {}
        try {
            Application.Storage.setValue(DS_K_BALL, 0);
            Application.Storage.setValue(DS_K_COURT, 0);
        } catch (e) {}
    }
}
