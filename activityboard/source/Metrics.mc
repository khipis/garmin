// ═══════════════════════════════════════════════════════════════════════════
// Metrics.mc — Reads ONLY real, on-device activity data the user genuinely
// accumulated (Toybox.ActivityMonitor) and turns it into leaderboard values.
//
// Nothing here is faked or estimated: every number comes straight from the
// watch's own daily/weekly activity tracking. Missing fields on a given device
// simply read as 0 (fully guarded — reading stats can never crash the app).
//
// Leaderboard model: all metrics are HIGHER-IS-BETTER, so "activityboard" stays
// out of the backend's ASC_GAMES set. The backend keeps each user's best-ever
// value per variant, so a board becomes a personal-record flex wall, while the
// day / week period filters turn "Steps Today" into a live daily race.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.ActivityMonitor;
using Toybox.Lang;

module Metrics {

    // Variant ids — MUST match bitochi.com (prettyVariant / value formatting).
    const V_FLEX   = "flex";
    const V_STEPS  = "steps";
    const V_ACTIVE = "active";
    const V_FLOORS = "floors";
    const V_DIST   = "dist";
    const V_KCAL   = "kcal";
    const V_VIG    = "vig";    // vigorous intensity minutes (week) — the "sport/run effort" board
    const V_ELEV   = "elev";   // metres climbed today — hiking / trail / stairs

    // Order used for the dashboard rows and the flex menu (flex is the headline,
    // shown separately). Sport-forward ordering. Each entry: [variant, label].
    function catalog() as Lang.Array {
        return [
            [V_STEPS,  "Steps"],
            [V_DIST,   "Distance"],
            [V_VIG,    "Cardio"],
            [V_ELEV,   "Climb"],
            [V_FLOORS, "Floors"],
            [V_KCAL,   "Calories"],
            [V_ACTIVE, "Active wk"]
        ];
    }

    function _n(x) {
        if (x instanceof Lang.Number) { return x; }
        if (x instanceof Lang.Long)   { return x.toNumber(); }
        return 0;
    }

    // Pull a full snapshot of today's / this-week's real activity. Values are
    // plain Numbers; anything unavailable on the device stays 0.
    //   steps / kcal / floors / distM (metres) : today
    //   active                                  : active minutes THIS WEEK
    //   *Goal                                   : the device's own goals (or 0)
    function snapshot() as Lang.Dictionary {
        var d = {
            "steps" => 0, "active" => 0, "floors" => 0, "distM" => 0, "kcal" => 0,
            "vig" => 0, "elevM" => 0,
            "stepGoal" => 0, "floorGoal" => 0, "activeGoal" => 0
        };
        try {
            if (!(Toybox has :ActivityMonitor)) { return d; }
            var info = ActivityMonitor.getInfo();
            if (info == null) { return d; }

            if (info has :steps && info.steps != null) { d["steps"] = _n(info.steps); }
            if (info has :stepGoal && info.stepGoal != null) { d["stepGoal"] = _n(info.stepGoal); }
            if (info has :calories && info.calories != null) { d["kcal"] = _n(info.calories); }
            // ActivityMonitor.Info.distance is in centimetres → metres.
            if (info has :distance && info.distance != null) { d["distM"] = (_n(info.distance) / 100); }
            if (info has :floorsClimbed && info.floorsClimbed != null) { d["floors"] = _n(info.floorsClimbed); }
            if (info has :floorsClimbedGoal && info.floorsClimbedGoal != null) { d["floorGoal"] = _n(info.floorsClimbedGoal); }
            // Metres climbed today (elevation gained) — trail / hiking / stairs.
            if (info has :metersClimbed && info.metersClimbed != null) { d["elevM"] = _n(info.metersClimbed); }
            if (info has :activeMinutesWeek && info.activeMinutesWeek != null) {
                var am = info.activeMinutesWeek;
                if (am has :total && am.total != null) { d["active"] = _n(am.total); }
                // Vigorous intensity minutes — hard cardio / running effort.
                if (am has :vigorous && am.vigorous != null) { d["vig"] = _n(am.vigorous); }
            }
            if (info has :activeMinutesWeekGoal && info.activeMinutesWeekGoal != null) { d["activeGoal"] = _n(info.activeMinutesWeekGoal); }
        } catch (e) {}
        return d;
    }

    // The signature FLEX SCORE: one big, satisfying number that rewards being
    // an all-round mover. Transparent and derived purely from real data:
    //   steps + floors*250 + activeMin(week)*120 + vigMin*180 + metres/4
    //   + elevMetres*8 + kcal*3
    // Vigorous minutes and climbing are weighted hardest — real athletic effort
    // moves the needle most, so runners / climbers top the all-round flex board.
    function flexScore(s as Lang.Dictionary) as Lang.Number {
        var f = 0;
        f += _n(s["steps"]);
        f += _n(s["floors"]) * 250;
        f += _n(s["active"]) * 120;
        f += _n(s["vig"]) * 180;
        f += (_n(s["distM"]) / 4);
        f += _n(s["elevM"]) * 8;
        f += _n(s["kcal"]) * 3;
        if (f < 0) { f = 0; }
        return f;
    }

    // The raw leaderboard value (integer) submitted for a variant.
    function valueFor(v as Lang.String, s as Lang.Dictionary) as Lang.Number {
        if (v.equals(V_STEPS))  { return _n(s["steps"]); }
        if (v.equals(V_ACTIVE)) { return _n(s["active"]); }
        if (v.equals(V_FLOORS)) { return _n(s["floors"]); }
        if (v.equals(V_DIST))   { return _n(s["distM"]); }
        if (v.equals(V_KCAL))   { return _n(s["kcal"]); }
        if (v.equals(V_VIG))    { return _n(s["vig"]); }
        if (v.equals(V_ELEV))   { return _n(s["elevM"]); }
        return flexScore(s);
    }

    // Optional per-variant goal (0 when the device doesn't expose one).
    function goalFor(v as Lang.String, s as Lang.Dictionary) as Lang.Number {
        if (v.equals(V_STEPS))  { return _n(s["stepGoal"]); }
        if (v.equals(V_FLOORS)) { return _n(s["floorGoal"]); }
        if (v.equals(V_ACTIVE)) { return _n(s["activeGoal"]); }
        return 0;
    }

    // Human display of a value in a given variant (used on the watch UI).
    function display(v as Lang.String, val as Lang.Number) as Lang.String {
        if (v.equals(V_DIST))   { return kmStr(val); }
        if (v.equals(V_ACTIVE)) { return val.toString() + " min"; }
        if (v.equals(V_VIG))    { return val.toString() + " min"; }
        if (v.equals(V_ELEV))   { return groupNum(val) + " m"; }
        if (v.equals(V_FLOORS)) { return val.toString(); }
        if (v.equals(V_KCAL))   { return val.toString() + " kcal"; }
        return groupNum(val);   // steps / flex — grouped big number
    }

    // metres → "8.4 km" (one decimal). Small metre counts still read as km so
    // the unit is consistent on the board.
    function kmStr(meters as Lang.Number) as Lang.String {
        var tenths = (meters + 50) / 100;        // round to nearest 0.1 km
        var whole  = tenths / 10;
        var frac   = tenths % 10;
        return whole.toString() + "." + frac.toString() + " km";
    }

    // 12345 → "12 345" (thin thousands grouping for a punchy hero number).
    function groupNum(n as Lang.Number) as Lang.String {
        var neg = n < 0;
        if (neg) { n = -n; }
        var s = n.toString();
        var out = "";
        var count = 0;
        for (var i = s.length() - 1; i >= 0; i--) {
            out = s.substring(i, i + 1) + out;
            count += 1;
            if (count % 3 == 0 && i != 0) { out = " " + out; }
        }
        return neg ? "-" + out : out;
    }
}
