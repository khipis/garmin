// ═══════════════════════════════════════════════════════════════════════════
// LbEvents.mc — async raid/fight inbox between named players.
//
// Attacker (after a local fight vs a real rival):
//   RaidMail.notify(game, foeName, "raid"|"fight", won)
// Victim (on next launch, ~12 s after open):
//   new LbRaidInbox(game, sink).arm() + .poll() from the view tick
//   sink.onRaidInbox(ok, events)  — events: Array of {id,from,kind,won,ts}
//
// Same network discipline as ArenaRoster / RivalRoster: one makeWebRequest at
// a time, tick-counted delays (no extra Timer on the pull path), public
// Communications callbacks. A failure is silent — games keep the offline
// defence RNG as fallback.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.PersistedContent;

module RaidMail {
    const ACK_KEY = "lb_raid_ack";   // last consumed event id (per app)

    // ~12 s on the 66 ms view tick — lands after launch ping → messages →
    // daily → roster (~10 s).
    const DELAY_TICKS = 180;
    const WAIT_TICKS  = 8;
    const WAIT_MAX    = 30;

    var _poster = null;

    function loadAck() as Lang.Number {
        try {
            var v = Application.Storage.getValue(ACK_KEY);
            if (v instanceof Lang.Number && v > 0) { return v; }
        } catch (e) {}
        return 0;
    }

    function saveAck(id as Lang.Number) as Void {
        if (!(id instanceof Lang.Number) || id <= 0) { return; }
        try {
            var cur = loadAck();
            if (id > cur) { Application.Storage.setValue(ACK_KEY, id); }
        } catch (e) {}
    }

    // Fire-and-forget: tell `toUser` they were raided/fought. No-ops when the
    // player has no name, the phone is away, or the target is empty/self.
    function notify(game as Lang.String, toUser as Lang.String,
                    kind as Lang.String, won as Lang.Boolean) as Void {
        if (!Leaderboard.isSupported()) { return; }
        if (!Leaderboard.isPhoneConnected()) { return; }
        var from = Leaderboard.loadUser();
        if (from == null || toUser == null) { return; }
        if (from.length() == 0 || toUser.length() == 0) { return; }
        if (from.equals(toUser)) { return; }
        try {
            _poster = new LbRaidPoster();
            _poster.send(game, from, toUser, kind, won ? 1 : 0);
        } catch (e) {}
    }
}

// ── Poster (attacker → server) ───────────────────────────────────────────────
class LbRaidPoster {
    hidden var _game;
    hidden var _from;
    hidden var _to;
    hidden var _kind;
    hidden var _won;
    hidden var _timer;
    hidden var _attempt;
    hidden var _waits;

    function initialize() {
        _attempt = 0; _waits = 0; _timer = null;
    }

    function send(game, from, to, kind, won) {
        _game = game; _from = from; _to = to; _kind = kind; _won = won;
        _attempt = 0; _waits = 0;
        _trySend();
    }

    function _trySend() as Void {
        if (!Leaderboard.isPhoneConnected()) { return; }
        if (Leaderboard.isBusy() || !Leaderboard.scoreQueueIdle()) {
            if (_waits >= 20) { return; }
            _waits += 1;
            if (_timer == null) { _timer = new Timer.Timer(); }
            try { _timer.start(method(:_trySend), 500, false); } catch (e) {}
            return;
        }
        var body = {
            "game" => _game,
            "from" => _from,
            "to"   => _to,
            "kind" => _kind,
            "won"  => _won
        };
        var opts = {
            :method       => Communications.HTTP_REQUEST_METHOD_POST,
            :headers      => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "X-LB-Key"     => Leaderboard.SUBMIT_KEY
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        try {
            Leaderboard.markBusy();
            Communications.makeWebRequest(Leaderboard.API_BASE + "/event",
                                          body, opts, method(:_onDone));
        } catch (e) { Leaderboard.clearBusy(); }
    }

    // PUBLIC — makeWebRequest callback.
    function _onDone(code as Lang.Number,
                     data as Null or Lang.Dictionary or Lang.String
                          or PersistedContent.Iterator) as Void {
        Leaderboard.clearBusy();
        if (code == 200 || code == 201) { return; }
        if (code >= 400 && code < 500) { return; }
        if (_attempt >= 2) { return; }
        var delay = [5000, 12000][_attempt];
        _attempt = _attempt + 1;
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_trySend), delay, false); } catch (e) {}
    }
}

// ── Inbox pull (victim ← server) ─────────────────────────────────────────────
// `sink` must expose onRaidInbox(ok, events) as a PUBLIC method. Driven by the
// view's animation tick — same reason ArenaRoster has no Timer of its own.
class LbRaidInbox {
    hidden var _game;
    hidden var _sink;
    hidden var _ticks;
    hidden var _waits;
    hidden var _alive;

    function initialize(game, sink) {
        _game = game; _sink = sink;
        _ticks = -1; _waits = 0; _alive = false;
    }

    function arm() {
        try {
            if (_alive) { return; }
            if (!Leaderboard.isSupported()) { return; }
            if (!Leaderboard.isPhoneConnected()) { return; }
            if (Leaderboard.loadUser() == null) { return; }
            _alive = true;
            _ticks = RaidMail.DELAY_TICKS;
            _waits = 0;
        } catch (e) {}
    }

    function stop() {
        _alive = false;
        _ticks = -1;
    }

    function poll() {
        if (!_alive || _ticks < 0) { return; }
        _ticks -= 1;
        if (_ticks > 0) { return; }
        _ticks = -1;
        try {
            if (!Leaderboard.isSupported() || !Leaderboard.isPhoneConnected()) {
                _alive = false;
                _fail();
                return;
            }
            if (Leaderboard.isBusy() || !Leaderboard.scoreQueueIdle()) {
                _waits += 1;
                if (_waits > RaidMail.WAIT_MAX) {
                    _alive = false;
                    _fail();
                    return;
                }
                _ticks = RaidMail.WAIT_TICKS;
                return;
            }
            var user = Leaderboard.loadUser();
            if (user == null) { _alive = false; _fail(); return; }
            var params = {
                "game"  => _game,
                "user"  => user,
                "since" => RaidMail.loadAck()
            };
            var opts = {
                :method       => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            };
            Leaderboard.markBusy();
            Communications.makeWebRequest(Leaderboard.API_BASE + "/inbox",
                                          params, opts, method(:_onDone));
        } catch (e) {
            Leaderboard.clearBusy();
            _alive = false;
            _fail();
        }
    }

    // PUBLIC — makeWebRequest callback.
    function _onDone(code as Lang.Number,
                     data as Null or Lang.Dictionary or Lang.String
                          or PersistedContent.Iterator) as Void {
        Leaderboard.clearBusy();
        _alive = false;
        if (code != 200 || !(data instanceof Lang.Dictionary)) {
            _fail();
            return;
        }
        var list = [];
        try {
            var raw = data["events"];
            if (raw instanceof Lang.Array) {
                for (var i = 0; i < raw.size(); i++) {
                    var e = raw[i];
                    if (e instanceof Lang.Dictionary) { list.add(e); }
                }
            }
        } catch (ex) {}
        try {
            if (_sink != null) { _sink.onRaidInbox(true, list); }
        } catch (ex2) {}
    }

    hidden function _fail() {
        try {
            if (_sink != null) { _sink.onRaidInbox(false, []); }
        } catch (e) {}
    }
}
