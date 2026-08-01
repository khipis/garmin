// ═══════════════════════════════════════════════════════════════════════════
// RivalRoster.mc — pulls the rival colonies the WAR page raids off the shared
// War leaderboard and hands them to ColonyModel as a cached roster.
//
// This is a luxury, never a dependency: the fetch is attempted at most once a
// calendar day, and everything downstream (raids, incoming attacks) runs off
// the cache, so a watch that never sees a phone plays the identical game with
// procedural opponents.
//
// Network discipline (all of it hard-won — breaking any of these terminates
// the host app on real hardware rather than failing politely):
//   • Garmin allows ONE in-flight makeWebRequest. We only fire when the
//     leaderboard channel is idle and the score queue has drained, and
//     re-check later instead of queueing a second request.
//   • The first attempt waits out the once-per-launch pipeline (launch ping →
//     messages → daily challenge) so it can't collide with it.
//   • Communications callbacks MUST be public: a method(:hidden_fn) reference
//     resolves at fire time OUTSIDE any try/catch and kills the app.
//   • No Timer of its own. The leaderboard pipeline already runs close to the
//     device timer budget and an extra one crashed the app on launch with
//     "Too Many Timers", so the delays are counted off the view's frame tick.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

class RivalRoster {
    hidden var _m;
    hidden var _fetch;
    hidden var _ticks;    // frames left before the next attempt, -1 = disarmed
    hidden var _waits;
    hidden var _alive;

    function initialize(model) {
        _m = model;
        _fetch = null;
        _ticks = -1; _waits = 0; _alive = false;
    }

    // Called once from the view. Cheap and silent when there is nothing to do.
    function schedule() {
        if (_alive || _m == null) { return; }
        try {
            if (!_m.rivalsStale()) { return; }
            if (!Leaderboard.isSupported()) { return; }
            if (!Leaderboard.isPhoneConnected()) { return; }
            _alive = true;
            _ticks = Sc.RIV_DELAY_TICKS;
        } catch (e) {}
    }

    function stop() {
        _alive = false;
        _ticks = -1;
    }

    // Driven by the view's animation tick — see the header note on timers.
    function poll() {
        if (!_alive || _ticks < 0) { return; }
        _ticks -= 1;
        if (_ticks > 0) { return; }
        _ticks = -1;
        try {
            if (!Leaderboard.isSupported() || !Leaderboard.isPhoneConnected()) {
                _alive = false;
                return;
            }
            // Wait out anything already on the wire rather than colliding.
            if (Leaderboard.isBusy() || !Leaderboard.scoreQueueIdle()) {
                _waits += 1;
                if (_waits > Sc.RIV_WAIT_MAX) { _alive = false; return; }
                _ticks = Sc.RIV_WAIT_TICKS;
                return;
            }
            _fetch = new LbFetch();
            _fetch.fetch(Sc.GAME_ID, Sc.LB_WAR, Leaderboard.loadUser(), "all", self, false);
        } catch (e) { _alive = false; }
    }

    // PUBLIC — LbFetch listener. Same response shape the boards read:
    // { top:[{r,u,s,c,m}], me, near:[...], ... }. The meta blob (m) arrives as
    // a raw JSON *string*, so it is ignored — the War score alone is the rival's
    // rating and Sc.rivalPower() turns it into a defense stat.
    function onLeaderboard(ok, data) {
        if (!_alive) { return; }
        if (!ok || !(data instanceof Lang.Dictionary)) { return; }
        try {
            // "near" first: those are the colonies rated closest to the player,
            // which is exactly the pool a fair raid band wants. "top" only fills
            // the remainder (and is all an anonymous player gets).
            var out = [];
            var user = Leaderboard.loadUser();
            _collect(out, data["near"], user);
            _collect(out, data["top"], user);
            _m.setRivals(out);
        } catch (e) {}
    }

    hidden function _collect(out, rows, user) {
        if (!(rows instanceof Lang.Array)) { return; }
        for (var i = 0; i < rows.size() && out.size() < Sc.RIV_MAX; i++) {
            var row = rows[i];
            if (!(row instanceof Lang.Dictionary)) { continue; }
            var u = row["u"];
            if (!(u instanceof Lang.String) || u.length() == 0) { continue; }
            if (user != null && u.equals(user)) { continue; }   // never raid yourself
            var name = u;
            if (name.length() > Sc.RIV_NAME_MAX) { name = name.substring(0, Sc.RIV_NAME_MAX); }
            if (_has(out, name)) { continue; }              // near/top overlap
            out.add([name, Sc.rivalPower(_score(row["s"]))]);
        }
    }
    hidden function _has(out, name) {
        for (var i = 0; i < out.size(); i++) {
            if (out[i][0].equals(name)) { return true; }
        }
        return false;
    }
    hidden function _score(s) {
        if (s instanceof Lang.Number) { return s; }
        if (s instanceof Lang.Long || s instanceof Lang.Float || s instanceof Lang.Double) {
            return s.toNumber();
        }
        return 0;
    }
}
