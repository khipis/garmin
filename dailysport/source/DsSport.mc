// ═══════════════════════════════════════════════════════════════════════════
// DsSport.mc — The seam the whole rotation hangs off.
//
// GameEngine owns the meta layer: the clock, the daily objective, the score
// and the aim / power / release state machine. It never knows what sport it is
// running. A sport supplies the geometry, the simulation and the field art:
//
//     layout()       lay the field out for this screen and today's challenge
//     aimMin/Max()   the angles this sport is played at
//     powerToSpeed() map the 0..1 power meter onto a launch speed
//     fire()         start the projectile
//     stepFlight()   advance it, returning DS_OUT_* once the shot resolves
//     drawField()    the field, the target, the projectile
//     drawGuide()    the honest predicted arc
//     outcomeText()  what the sport calls what just happened
//
// The four outcomes mean the same thing everywhere even though every sport
// has its own word for them: SWISH is the perfect result, BANK and RIM are the
// two lesser ways of scoring, MISS is nothing. Keeping that vocabulary fixed
// is what lets one challenge manager, one scoring table and one leaderboard
// serve a ski hill and a free kick without knowing about either.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

class DsSport {
    function initialize() {}

    function id()   as Lang.String { return "sport"; }
    function name() as Lang.String { return "SPORT"; }

    // Verb shown on the release ring, e.g. "SHOOT".
    function actionWord() as Lang.String { return "GO"; }

    // The angles the aim meter sweeps between. A free kick and a chip are not
    // played from the same band, and pretending they are would spend most of
    // the meter on shots nobody would take.
    function aimMin() as Lang.Float { return DS_AIM_MIN; }
    function aimMax() as Lang.Float { return DS_AIM_MAX; }

    function layout(eng, w as Lang.Number, h as Lang.Number) as Void {}
    function beginShot(eng) as Void {}
    function updateField(runMs as Lang.Number) as Void {}
    function bgColor() as Lang.Number { return DS_BG; }
    function powerToSpeed(meter as Lang.Float) as Lang.Float { return 0.0; }
    function fire(eng, angle as Lang.Float, meter as Lang.Float) as Void {}
    function stepFlight(eng, dt as Lang.Float) as Lang.Number { return DS_OUT_MISS; }
    function drawField(dc, eng) as Void {}
    function drawGuide(dc, eng, angle as Lang.Float, meter as Lang.Float) as Void {}

    // What the sport calls the result, and — when it knows something the
    // release timing does not — why it happened. An empty hint lets the
    // engine fall back to its own reading of the release.
    function outcomeText(outcome as Lang.Number) as Lang.String {
        if (outcome == DS_OUT_SWISH) { return "PERFECT!"; }
        if (outcome == DS_OUT_BANK)  { return "SCORED"; }
        if (outcome == DS_OUT_RIM)   { return "SCORED"; }
        return "MISS";
    }

    function outcomeHint() as Lang.String { return ""; }

    // Celebration hooks. The engine decides what a shot was worth; the sport
    // knows where on the field it happened and what that should look like.
    function onResolved(eng, outcome as Lang.Number, gained as Lang.Number) as Void {}
    function drawOverlay(dc, w as Lang.Number, h as Lang.Number) as Void {}
}

module DsSports {

    // The rotation, in its canonical order. Index into this and IDS with the
    // same number — the briefing card shows one and the leaderboard variant
    // is built from the other.
    const ROSTER = ["BASKETBALL", "FOOTBALL", "ARCHERY",
                    "TENNIS", "GOLF", "HILL RIDE"];
    const IDS    = ["basketball", "football", "archery",
                    "tennis", "golf", "hillride"];

    function count() as Lang.Number { return 6; }

    // Which sport the whole planet plays on day `dn`.
    //
    // A plain hash would happily serve archery four days running. Instead each
    // six-day cycle is a permutation of the roster — a stride coprime with six
    // plus an offset — so every sport comes round exactly once per cycle and
    // the order still changes from week to week.
    function indexForDay(dn as Lang.Number) as Lang.Number {
        var cycle = dn / 6;
        var slot  = dn % 6;
        var step  = ((DsUtil.hash(cycle, 137) % 2) == 0) ? 1 : 5;
        var off   = DsUtil.hash(cycle, 131) % 6;
        return (slot * step + off) % 6;
    }

    function idForDay(dn as Lang.Number) as Lang.String {
        return IDS[indexForDay(dn)];
    }

    function nameForDay(dn as Lang.Number) as Lang.String {
        return ROSTER[indexForDay(dn)];
    }

    function create(sportId as Lang.String) as DsSport {
        if (sportId.equals("football")) { return new SportFootball(); }
        if (sportId.equals("archery"))  { return new SportArchery(); }
        if (sportId.equals("tennis"))   { return new SportTennis(); }
        if (sportId.equals("golf"))     { return new SportGolf(); }
        if (sportId.equals("hillride")) { return new SportHillRide(); }
        return new SportBasketball();
    }

    // The words the briefing and the result card need, without paying for a
    // whole sport object just to render a sentence.
    //
    //   name    what the day is called
    //   scored  plural noun for a result that counted
    //   perfect plural noun for the best possible result
    //   verb    what the player is being asked to do
    function nouns(sportId as Lang.String) as Lang.Dictionary {
        if (sportId.equals("football")) {
            return { "name" => "FOOTBALL", "scored" => "goals",
                     "perfect" => "top corners", "verb" => "Score" };
        }
        if (sportId.equals("archery")) {
            return { "name" => "ARCHERY", "scored" => "hits",
                     "perfect" => "golds", "verb" => "Shoot" };
        }
        if (sportId.equals("tennis")) {
            return { "name" => "TENNIS", "scored" => "serves in",
                     "perfect" => "aces", "verb" => "Land" };
        }
        if (sportId.equals("golf")) {
            return { "name" => "GOLF", "scored" => "greens",
                     "perfect" => "holed chips", "verb" => "Chip" };
        }
        if (sportId.equals("hillride")) {
            return { "name" => "HILL RIDE", "scored" => "landings",
                     "perfect" => "K-points", "verb" => "Ride" };
        }
        return { "name" => "BASKETBALL", "scored" => "baskets",
                 "perfect" => "swishes", "verb" => "Score" };
    }
}
