// ═══════════════════════════════════════════════════════════════════════════
// ArenaRoster.mc — pulls a small roster of REAL Arena players off the shared
// leaderboard so the Arena fights people instead of inventions.
//
// The whole file is written around one hard constraint: Garmin allows exactly
// ONE in-flight makeWebRequest, and a second one issued while another is
// pending does not fail cleanly — on several firmware versions it terminates
// the app a moment later. So this:
//   • never fires until Leaderboard reports supported + phone connected +
//     not busy + the score FIFO drained,
//   • defers instead of racing when the channel is taken,
//   • fires ~10 s after the view opens, behind the launch ping → messages →
//     daily → score-batch pipeline,
//   • runs at most once per calendar day.
// The delays are counted off the view's animation tick rather than a Timer of
// this class's own: the leaderboard pipeline already sits at the device timer
// budget and one more allocation kills the app on launch.
// Every callback reachable from Communications is PUBLIC: a method(:hidden_fn)
// reference resolves at fire time outside any try/catch and crashes (the same
// bug documented in LbViews' LbPinger).
//
// Nothing here is allowed to matter. A failed or skipped fetch simply leaves
// the cached roster alone, and CreatureModel falls back to procedural foes, so
// an offline player sees no difference at all.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;
class ArenaRoster {
    hidden var _m;
    hidden var _fetch;
    hidden var _waits;
    hidden var _ticks;   // frames left before the next attempt, -1 = disarmed

    function initialize(m) {
        _m = m; _fetch = null; _waits = 0; _ticks = -1;
    }

    // Arm the once-a-day refresh. The day stamp is deliberately NOT written
    // here: a player who opens the game with no phone in range would otherwise
    // burn their one attempt for the day without a request ever leaving.
    function arm() {
        try {
            if (_m == null || !_m.hatched) { return; }
            if (!_m.rosterStale()) { return; }
            if (!Leaderboard.isSupported()) { return; }
            if (!Leaderboard.isPhoneConnected()) { return; }
            _ticks = Cr.ROSTER_DELAY_TICKS;
        } catch (e) {}
    }

    function stop() { _ticks = -1; }

    // Driven by the view's animation tick rather than a Timer of its own: the
    // leaderboard pipeline already sits at the device timer budget, and one
    // more allocation terminates the app on launch with "Too Many Timers".
    function poll() {
        if (_ticks < 0) { return; }
        _ticks -= 1;
        if (_ticks > 0) { return; }
        _ticks = -1;
        try {
            if (Leaderboard.isBusy() || !Leaderboard.scoreQueueIdle()) {
                // The busy flag auto-expires at 15 s; keep the deferral count
                // above that so a dropped callback can't wedge us forever, and
                // bounded so we can't poll for the rest of the session.
                if (_waits >= Cr.ROSTER_WAIT_MAX) { return; }
                _waits += 1;
                _ticks = Cr.ROSTER_WAIT_TICKS;
                return;
            }
            if (!Leaderboard.isPhoneConnected()) { return; }
            _m.markRosterTried();
            _fetch = new LbFetch();
            _fetch.fetch(Cr.GAME_ID, Cr.LB_ARENA, Leaderboard.loadUser(), "all", self, false);
        } catch (e) {}
    }

    // PUBLIC — LbFetch listener.
    function onLeaderboard(ok, data) as Void {
        _fetch = null;
        if (!ok) { return; }
        try {
            var list = _parse(data);
            if (list.size() > 0) { _m.setRoster(list); }
        } catch (e) {}
    }

    // ── Response parsing ─────────────────────────────────────────────────────
    // Rows come back as { r, u, s, c, m } where `m` is the meta blob as a JSON
    // STRING (the API stores it serialised, capped at 512 chars). Only the
    // compact numeric avatar fields are wanted, so the string is scanned for
    // "key":<int> rather than parsed — a full JSON parse of eleven rows is far
    // more work than this needs, and every field has an obvious default.
    hidden function _parse(data) {
        var out = [];
        if (!(data instanceof Lang.Dictionary)) { return out; }
        var mine = Leaderboard.loadUser();
        _collect(out, data["top"], mine);
        _collect(out, data["near"], mine);
        return out;
    }

    hidden function _collect(out, rows, mine) {
        if (!(rows instanceof Lang.Array)) { return; }
        for (var i = 0; i < rows.size() && out.size() < Cr.ROSTER_MAX; i++) {
            var row = rows[i];
            if (!(row instanceof Lang.Dictionary)) { continue; }
            var u = row["u"];
            if (!(u instanceof Lang.String) || u.length() == 0) { continue; }
            if (mine != null && u.equals(mine)) { continue; }
            // top and near overlap for mid-table players.
            if (_has(out, u)) { continue; }
            var blob = row["m"];
            // Scores posted before the avatar fields existed carry no meta;
            // there is nothing to draw for them, so they are not rivals.
            if (!(blob instanceof Lang.String) || blob.length() == 0) { continue; }
            out.add([u,
                     _num(blob, "\"level\":", 1),
                     _num(blob, "\"sp\":", 0),
                     _num(blob, "\"ev\":", Cr.EV_HATCH),
                     _num(blob, "\"rt\":", 0),
                     _num(blob, "\"pa\":", Cr.PATH_NONE),
                     _num(blob, "\"sd\":", 12345)]);
        }
    }

    hidden function _has(out, u) {
        for (var i = 0; i < out.size(); i++) {
            if (u.equals(out[i][0])) { return true; }
        }
        return false;
    }

    hidden function _num(s, key, def) {
        try {
            var i = s.find(key);
            if (i == null) { return def; }
            var j = i + key.length();
            var n = 0; var got = false;
            while (j < s.length()) {
                var d = "0123456789".find(s.substring(j, j + 1));
                if (d == null) { break; }
                // DNA seeds run to 2^31-1, so stop before the next multiply can
                // overflow rather than wrapping into a negative seed.
                if (n > 214748363) { break; }
                n = n * 10 + d;
                j += 1; got = true;
            }
            if (!got) { return def; }
            return n;
        } catch (e) { return def; }
    }
}
