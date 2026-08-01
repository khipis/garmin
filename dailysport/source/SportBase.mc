// ═══════════════════════════════════════════════════════════════════════════
// SportBase.mc — What every sport after basketball has in common.
//
// Basketball resolves its shot inside PhysicsEngine, because the ring is the
// only target that needs solid geometry to bounce off. Everything else in the
// rotation — a goal mouth, a target face, a service box, a hole, a rack of
// pins — is a zone the projectile either enters or does not, so those sports
// share one flight loop and differ only in three answers:
//
//     _place()     where the release point, the deck and the target sit
//     _verdict()   what the last segment of flight just did to the target
//     _drawScene() what the field looks like
//
// The power meter is normalised the same way it is for basketball: against the
// speed that would put a reference-angle shot exactly on the target. That is
// what makes "around 60%" mean the same thing in archery as it does on the
// court, on every watch, so the feel the player builds up transfers between
// days instead of being relearned every morning.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

class DsSportBase extends DsSport {

    var phys;        // PhysicsEngine — the shared integrator and its tuning
    var ball;        // DsBall
    var fx;          // DsFxSys
    var lx;          // Float — release point
    var ly;          // Float
    var floorY;      // Float — the deck
    var refSpd;      // Float — speed that puts a reference shot on target
    var sw;          // Number — screen width
    var sh;          // Number — screen height
    var trail;       // Array of [x, y]
    var frame;       // Number — free-running counter for ambient motion
    var settling;    // Boolean — projectile still moving after the verdict
    var landX;       // Float — where the last shot came down, for the payoff
    var landY;       // Float

    function initialize() {
        DsSport.initialize();
        phys = new PhysicsEngine();
        ball = new DsBall();
        fx   = new DsFxSys();
        lx = 0.0; ly = 0.0; floorY = 0.0; refSpd = 400.0;
        sw = 240; sh = 240;
        trail = [];
        frame = 0; settling = false;
        landX = 0.0; landY = 0.0;
    }

    // ── Hooks ───────────────────────────────────────────────────────────────
    // Lay the field out. Must set floorY, lx and ly, plus the sport's own
    // target geometry.
    function _place(eng, w as Lang.Number, h as Lang.Number) as Void {}

    // The point the power meter is normalised against — usually the centre of
    // the scoring zone.
    function _refPoint() as Lang.Array { return [sw * 0.72, sh * 0.5]; }

    // Test the segment the projectile just travelled against the target.
    function _verdict(eng) as Lang.Number { return DS_OUT_NONE; }

    // The projectile ran out of road: off the screen, out of time, or settled
    // on the deck. Ground-target sports decide the shot here.
    function _deadEnd(eng) as Lang.Number { return DS_OUT_MISS; }

    function _drawScene(dc, eng) as Void {}
    function _drawProjectile(dc, eng) as Void {}

    // Height of the ground under `x`. Flat for everything except the ski hill.
    function _surfaceY(x as Lang.Float) as Lang.Float { return floorY; }

    // Bounce policy for the sports that do not resolve on the deck.
    function _maxBounces() as Lang.Number { return 1; }
    function _damp()       as Lang.Float  { return 0.42; }

    // Sub-steps per frame. A fast, small projectile against a small target
    // needs a finer step or it tunnels straight through it.
    function _subSteps() as Lang.Number { return 2; }

    // Where the last segment crossed a vertical plane, or a negative number
    // when it did not cross it travelling right. Every sport whose target is
    // a plane — a goal mouth, a target face, a net — is scored off this.
    function _crossY(planeX as Lang.Float) as Lang.Float {
        if (ball.px >= planeX || ball.x < planeX) { return -1.0; }
        var dx = ball.x - ball.px;
        if (dx < 0.0001) { return ball.y; }
        return ball.py + (ball.y - ball.py) * ((planeX - ball.px) / dx);
    }

    // ── Setup ───────────────────────────────────────────────────────────────
    function layout(eng, w as Lang.Number, h as Lang.Number) as Void {
        sw = w; sh = h;
        trail = [];
        settling = false;
        _place(eng, w, h);
        phys.configure(w, h, floorY);
        phys.r = projectileR();
        var ref = _refPoint();
        refSpd = phys.refSpeed(lx, ly, ref[0], ref[1], refAngle());
        fx.reset();
    }

    // Projectiles are not all basketballs: an arrow is a sliver and a golf
    // ball is a pebble, and the radius is what the collision tests use.
    function projectileR() as Lang.Float {
        var r = sh * 0.030;
        return (r < 3.0) ? 3.0 : r;
    }

    // The angle the power meter is normalised around. Flat sports override it
    // so that "half power" lands somewhere useful rather than in the deck.
    function refAngle() as Lang.Float { return DS_AIM_REF; }

    function beginShot(eng) as Void {
        ball.flying = false;
        ball.bounces = 0;
        settling = false;
        trail = [];
    }

    function updateField(runMs as Lang.Number) as Void {
        frame = (frame + 1) % 100000;
        fx.tick(DS_TICK_MS / 1000.0, phys.g);
        _ambient(runMs);
        if (settling) { _settle(); }
    }

    // Moving parts of the field — a keeper, a wind flag, a swaying target.
    function _ambient(runMs as Lang.Number) as Void {}

    // Let the projectile finish its journey while the outcome banner is up. A
    // ball that vanishes the instant it is judged robs the make of its payoff.
    function _settle() as Void {
        var dt = DS_TICK_MS / 1000.0;
        ball.vy = ball.vy + phys.g * dt;
        ball.x  = ball.x + ball.vx * dt;
        ball.y  = ball.y + ball.vy * dt;
        if (ball.y > floorY - phys.r) {
            ball.y  = floorY - phys.r;
            ball.vy = -ball.vy * 0.30;
            ball.vx = ball.vx * 0.65;
            if (ball.vy > -20.0) { settling = false; }
        }
    }

    // ── The shot ────────────────────────────────────────────────────────────
    function powerToSpeed(meter as Lang.Float) as Lang.Float {
        return refSpd * (DS_PWR_LO + meter * (DS_PWR_HI - DS_PWR_LO));
    }

    function fire(eng, angle as Lang.Float, meter as Lang.Float) as Void {
        trail = [];
        settling = false;
        phys.launch(ball, lx, ly, angle, powerToSpeed(meter));
        _onFire(eng);
    }

    function _onFire(eng) as Void {}

    function stepFlight(eng, dt as Lang.Float) as Lang.Number {
        var n   = _subSteps();
        var sub = dt / n;
        for (var i = 0; i < n; i++) {
            phys.integrateFree(ball, sub);

            var out = _verdict(eng);
            if (out != DS_OUT_NONE) { return _stop(out); }

            // Only a descending projectile can hit the deck. Without that
            // guard a ball struck from ground level is judged to have landed
            // on the frame it was struck.
            if (ball.vy > 0.0 && phys.onDeck(ball)) {
                out = _onDeck(eng);
                if (out != DS_OUT_NONE) { return _stop(out); }
            }
            if (phys.offScreen(ball)) { return _stop(_deadEnd(eng)); }
        }

        _pushTrail();
        ball.age = ball.age + dt;
        if (ball.age > 4.5) { return _stop(_deadEnd(eng)); }
        return DS_OUT_NONE;
    }

    // Deck contact. The default is basketball's: one bounce for feel, then the
    // shot is dead. Sports that score off the ground override this.
    function _onDeck(eng) as Lang.Number {
        ball.y = floorY - phys.r;
        ball.bounces = ball.bounces + 1;
        if (ball.bounces > _maxBounces()) { return _deadEnd(eng); }
        ball.vy = -ball.vy * _damp();
        ball.vx = ball.vx * 0.72;
        if (ball.vy > -25.0) { return _deadEnd(eng); }
        return DS_OUT_NONE;
    }

    hidden function _stop(out as Lang.Number) as Lang.Number {
        ball.flying = false;
        landX = ball.x;
        landY = ball.y;
        return out;
    }

    hidden function _pushTrail() as Void {
        trail.add([ball.x.toNumber(), ball.y.toNumber()]);
        if (trail.size() > 8) { trail = trail.slice(1, null); }
    }

    // ── Payoff ──────────────────────────────────────────────────────────────
    function onResolved(eng, outcome as Lang.Number, gained as Lang.Number) as Void {
        fx.onOutcome(outcome, landX.toNumber(), landY.toNumber(), gained, _sc());
        settling = _settlesAfter(outcome);
    }

    // Whether the projectile keeps moving once the verdict is in. A ball that
    // has come to rest on the green should stay there.
    function _settlesAfter(outcome as Lang.Number) as Lang.Boolean { return false; }

    function _sc() as Lang.Float { return sh / DS_REF_H; }

    // ── Paint ───────────────────────────────────────────────────────────────
    function drawField(dc, eng) as Void {
        _drawScene(dc, eng);
        _drawProjectile(dc, eng);
    }

    function drawOverlay(dc, w as Lang.Number, h as Lang.Number) as Void {
        fx.draw(dc, w, h, phys.r.toNumber());
    }

    // The guide comes off the same integrator that resolves the shot, so it
    // can never lie about where the projectile is going.
    function drawGuide(dc, eng, angle as Lang.Float, meter as Lang.Float) as Void {
        var mode = DsUtil.optIndex(DS_K_GUIDE, 0, 3);
        if (mode == 2) { return; }
        var frac = (mode == 1) ? 1.0 : 0.45;

        var pts = phys.predict(lx, ly, angle, powerToSpeed(meter), frac);
        var n   = pts.size();
        var dot = sw * 10 / 1000; if (dot < 2) { dot = 2; }

        for (var i = 0; i < n; i++) {
            // The predictor only knows about the flat deck. A sport whose
            // ground rises to meet the projectile stops the guide at its own
            // surface, so the arc never runs on underneath the scenery.
            if (pts[i][1] >= _surfaceY(pts[i][0].toFloat())) { break; }
            var f = (n > 1) ? (i.toFloat() / (n - 1)) : 0.0;
            dc.setColor(f < 0.4 ? 0xFFFFFF : (f < 0.75 ? DS_GUIDE : 0x00AAAA),
                        Graphics.COLOR_TRANSPARENT);
            var rr = (f < 0.6) ? dot : dot - 1; if (rr < 1) { rr = 1; }
            dc.fillCircle(pts[i][0], pts[i][1], rr);
        }

        DsSportArt.launchArrow(dc, lx, ly, angle, phys.r + 5.0, sh * 0.075);
    }
}
