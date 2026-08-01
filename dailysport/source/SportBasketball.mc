// ═══════════════════════════════════════════════════════════════════════════
// SportBasketball.mc — The first sport: a 2D jump shot with real ball flight.
//
// Geometry is derived from the day's challenge (distance, ring height, sway)
// and from the screen, then the power meter is normalised against the speed
// that would drop a 52° shot straight through the ring. The consequence is
// that "meter around 60%" is the honest answer on every watch and every day,
// and the player's learned feel transfers between devices.
//
// This class owns mechanics and staging. The scene itself — four arenas, the
// rig, the ball — is painted by DsArt, and the celebration by DsFxSys, so
// adding the next sport means writing new mechanics, not a new renderer.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

class SportBasketball extends DsSport {

    var phys;        // PhysicsEngine
    var ball;        // DsBall
    var hoop;        // DsHoop
    var fx;          // DsFxSys — confetti, sparks, pops, flashes
    var lx;          // Float — release point (the shooter's hands)
    var ly;          // Float
    var floorY;      // Float
    var refSpd;      // Float — speed that swishes a DS_AIM_REF shot
    var court;       // Number — cosmetic court index
    var skin;        // Number — cosmetic ball index
    var sw;          // Number — screen width
    var sh;          // Number — screen height
    var trail;       // Array of [x,y] — recent ball positions
    var frame;       // Number — free-running frame counter for ambient motion
    var wasRim;      // Boolean — rim contact seen on the previous frame
    var settling;    // Boolean — ball still dropping after the shot resolved

    function initialize() {
        DsSport.initialize();
        phys = new PhysicsEngine();
        ball = new DsBall();
        hoop = new DsHoop();
        fx   = new DsFxSys();
        lx = 0.0; ly = 0.0; floorY = 0.0; refSpd = 400.0;
        court = 0; skin = 0; sw = 240; sh = 240;
        trail = [];
        frame = 0; wasRim = false; settling = false;
    }

    function id()         as Lang.String { return "basketball"; }
    function name()       as Lang.String { return "BASKETBALL"; }
    function actionWord() as Lang.String { return "SHOOT"; }

    function outcomeText(outcome as Lang.Number) as Lang.String {
        if (outcome == DS_OUT_SWISH) { return "SWISH!"; }
        if (outcome == DS_OUT_BANK)  { return "OFF THE GLASS"; }
        if (outcome == DS_OUT_RIM)   { return "IN OFF THE RIM"; }
        return "MISS";
    }

    function bgColor() as Lang.Number { return DS_BG; }

    // ── Setup ───────────────────────────────────────────────────────────────
    function layout(eng, w as Lang.Number, h as Lang.Number) as Void {
        sw = w; sh = h;
        court = ProgressionManager.courtIndex();
        skin  = ProgressionManager.ballIndex();

        floorY = h * 0.855;
        lx     = w * 0.20;
        ly     = floorY - h * 0.30;

        var ch = eng.ch;
        hoop.baseX  = w * ch.dist;
        hoop.x      = hoop.baseX;
        hoop.y      = floorY - h * ch.height;
        hoop.w      = w * 0.155;
        hoop.sway   = w * ch.sway;
        hoop.frozen = false;

        phys.configure(w, h, floorY);
        refSpd = phys.refSpeed(lx, ly, hoop.baseX, hoop.y, DS_AIM_REF);
        trail = [];
        fx.reset();
    }

    function beginShot(eng) as Void {
        ball.flying = false;
        hoop.frozen = false;
        wasRim = false;
        settling = false;
        trail = [];
    }

    function updateField(runMs as Lang.Number) as Void {
        frame = (frame + 1) % 100000;
        hoop.update(runMs);
        fx.tick(DS_TICK_MS / 1000.0, phys.g);

        // The shot is decided the instant the ball crosses the ring, but a
        // ball that vanishes at that instant robs the make of its payoff. Let
        // it finish falling through the net while the outcome banner is up.
        if (settling) {
            var dt = DS_TICK_MS / 1000.0;
            ball.vy = ball.vy + phys.g * dt;
            ball.x  = ball.x + ball.vx * dt;
            ball.y  = ball.y + ball.vy * dt;
            ball.spin = ball.spin + ball.vx * dt * 0.05;
            if (ball.y > floorY - phys.r) {
                ball.y  = floorY - phys.r;
                ball.vy = -ball.vy * 0.35;
                ball.vx = ball.vx * 0.7;
                if (ball.vy > -20.0) { settling = false; }
            }
        }
    }

    function powerToSpeed(meter as Lang.Float) as Lang.Float {
        return refSpd * (DS_PWR_LO + meter * (DS_PWR_HI - DS_PWR_LO));
    }

    function fire(eng, angle as Lang.Float, meter as Lang.Float) as Void {
        hoop.frozen = true;          // the ring holds still once the ball is up
        trail = [];
        wasRim = false;
        phys.launch(ball, lx, ly, angle, powerToSpeed(meter));
    }

    function stepFlight(eng, dt as Lang.Float) as Lang.Number {
        var out = phys.step(ball, dt, hoop);
        trail.add([ball.x.toNumber(), ball.y.toNumber()]);
        if (trail.size() > 8) { trail = trail.slice(1, null); }
        // Iron rings the moment it is touched, not when the shot resolves.
        if (ball.hitRim && !wasRim) {
            wasRim = true;
            fx.onRimContact();
            fx.burst(ball.x.toNumber(), ball.y.toNumber(), 4, DS_P_SPARK, _sc());
        }
        return out;
    }

    // Pay the shot off where it happened: at the ring for a make, on the deck
    // for a brick.
    function onResolved(eng, outcome as Lang.Number, gained as Lang.Number) as Void {
        var x = ball.x.toNumber();
        var y = ball.y.toNumber();
        if (outcome != DS_OUT_MISS) {
            x = hoop.x.toNumber();
            y = hoop.y.toNumber();
        }
        fx.onOutcome(outcome, x, y, gained, _sc());
        settling = true;
    }

    // Particle speeds are authored against a 240 px screen like the physics.
    hidden function _sc() as Lang.Float { return sh / DS_REF_H; }

    // ── Field art ───────────────────────────────────────────────────────────
    function drawField(dc, eng) as Void {
        var fy = floorY.toNumber();
        DsArt.scene(dc, court, sw, sh, fy, frame);
        DsArt.hoopArt(dc, court, hoop, sw, sh, fy, fx.netWave, fx.rimFlash > 0);
        _drawShooter(dc, eng);
        _drawBall(dc, eng);
    }

    // Particles and the score pop sit above the court but below the HUD.
    function drawOverlay(dc, w as Lang.Number, h as Lang.Number) as Void {
        fx.draw(dc, w, h, phys.r.toNumber());
    }

    // The pose is read straight off the shot state: the shooter loads through
    // POWER, uncoils on RELEASE and holds the follow-through while the ball
    // is up. It is the same three beats the player is pressing.
    hidden function _drawShooter(dc, eng) as Void {
        var br = phys.r.toNumber();
        var hr = (sh * 0.028).toNumber();
        if (hr < 3) { hr = 3; }

        var crouch = 0.0;
        var arm    = 0.0;
        if (eng.state == DS_ST_AIM) {
            // Idle bounce, so the shooter is never a statue.
            crouch = 0.18 + 0.10 * Math.sin(frame * 0.22);
        } else if (eng.state == DS_ST_POWER) {
            crouch = 0.35 + 0.55 * eng.power;      // deeper load = more power
        } else if (eng.state == DS_ST_RELEASE) {
            crouch = 0.9 - 0.9 * eng.relT;
            arm    = eng.relT;
        } else {
            arm = 1.0;                              // follow-through, held
        }

        DsArt.shooterArt(dc, court, lx.toNumber(), ly.toNumber(),
                         floorY.toNumber(), br, hr, crouch, arm, frame);
    }

    hidden function _drawBall(dc, eng) as Void {
        var r = phys.r.toNumber();
        if (r < 3) { r = 3; }
        if (ball.flying || settling) {
            DsArt.trailArt(dc, skin, trail, r);
            DsArt.ballArt(dc, skin, ball.x.toNumber(), ball.y.toNumber(),
                          r, ball.spin);
            return;
        }
        // Held: the ball rides a slow idle spin so the seams stay alive.
        DsArt.ballArt(dc, skin, lx.toNumber(), ly.toNumber(), r, frame * 0.04);
    }

    // ── The aiming guide ────────────────────────────────────────────────────
    // Drawn from the same integrator that resolves the shot, so what the guide
    // shows is exactly what the ball will do if the release is clean.
    function drawGuide(dc, eng, angle as Lang.Float, meter as Lang.Float) as Void {
        var mode = DsUtil.optIndex(DS_K_GUIDE, 0, 3);
        if (mode == 2) { return; }
        var frac = (mode == 1) ? 1.0 : 0.45;

        var pts = phys.predict(lx, ly, angle, powerToSpeed(meter), frac);
        var n   = pts.size();
        var dot = sw * 10 / 1000; if (dot < 2) { dot = 2; }

        // The arc dims along its length: the near dots are the ones the player
        // is actually steering with, the far ones are context.
        for (var i = 0; i < n; i++) {
            var f = (n > 1) ? (i.toFloat() / (n - 1)) : 0.0;
            // Every step of the ramp has to survive both the black upper sky
            // and the lit band above the roofs, so it runs white to mid-cyan
            // rather than fading toward the background.
            dc.setColor(f < 0.4 ? 0xFFFFFF : (f < 0.75 ? DS_GUIDE : 0x00AAAA),
                        Graphics.COLOR_TRANSPARENT);
            var rr = (f < 0.6) ? dot : dot - 1; if (rr < 1) { rr = 1; }
            dc.fillCircle(pts[i][0], pts[i][1], rr);
        }

        // Apex marker: the top of the arc is what a shooter actually aims.
        if (n > 2) {
            var ai = 0;
            for (var i = 1; i < n; i++) {
                if (pts[i][1] < pts[ai][1]) { ai = i; }
            }
            dc.setColor(DS_GUIDE, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(pts[ai][0], pts[ai][1], dot + 3);
        }

        // Launch vector: an arrow starting clear of the ball, so it reads as
        // a direction rather than as another one of the shooter's limbs.
        var a  = angle * 0.0174532925;
        var ca = Math.cos(a);
        var sa = Math.sin(a);
        var r0 = phys.r + 5.0;
        var r1 = r0 + sh * 0.075;
        var x0 = (lx + ca * r0).toNumber();
        var y0 = (ly - sa * r0).toNumber();
        var x1 = (lx + ca * r1).toNumber();
        var y1 = (ly - sa * r1).toNumber();
        dc.setColor(0xFFFF55, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(x0, y0, x1, y1);
        dc.setPenWidth(1);
        dc.fillPolygon([[x1, y1],
                        [(x1 - ca * 7 - sa * 4).toNumber(),
                         (y1 + sa * 7 - ca * 4).toNumber()],
                        [(x1 - ca * 7 + sa * 4).toNumber(),
                         (y1 + sa * 7 + ca * 4).toNumber()]]);
    }
}
