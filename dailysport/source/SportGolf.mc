// ═══════════════════════════════════════════════════════════════════════════
// SportGolf.mc — The chip.
//
// The only sport in the rotation with no wrong side to miss on: short and long
// are equally bad, and the reward falls off smoothly with distance from the
// pin rather than in a single pass/fail step. That makes it the most forgiving
// day on the calendar and the one where the leaderboard is decided by the
// difference between "close" and "very close".
//
// The ball is judged where it first pitches, then it is allowed to release and
// run, because a chip that finishes stone dead is the shot the player was
// picturing and it has to look like it happened.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

class SportGolf extends DsSportBase {

    var hx;        // Float — the hole
    var near;      // Float — tap-in radius
    var far;       // Float — on-the-green radius
    var pinH;      // Float — flagstick height
    var venue;     // Number
    var why;       // String

    function initialize() {
        DsSportBase.initialize();
        hx = 0.0; near = 0.0; far = 0.0; pinH = 0.0;
        venue = 0; why = "";
    }

    function id()         as Lang.String { return "golf"; }
    function name()       as Lang.String { return "GOLF"; }
    function actionWord() as Lang.String { return "CHIP"; }
    function aimMin()     as Lang.Float  { return 20.0; }
    function aimMax()     as Lang.Float  { return 66.0; }
    function refAngle()   as Lang.Float  { return 44.0; }

    function projectileR() as Lang.Float {
        var r = sh * 0.019;
        return (r < 3.0) ? 3.0 : r;
    }

    function _place(eng, w as Lang.Number, h as Lang.Number) as Void {
        venue  = ProgressionManager.courtIndex();
        floorY = h * 0.855;
        lx     = w * 0.13;
        ly     = floorY - h * 0.042;

        var ch = eng.ch;
        hx   = w * (ch.dist + 0.05);
        pinH = h * 0.15;

        // The precision days shrink the target instead of moving it: a hole
        // that slides around the green would be a joke rather than a
        // challenge.
        var tight = 1.0 - ch.sway * 4.0;
        if (tight < 0.55) { tight = 0.55; }
        near = w * 0.052 * tight;
        far  = w * 0.115 * tight;
    }

    function _refPoint() as Lang.Array { return [hx, floorY]; }

    function beginShot(eng) as Void {
        DsSportBase.beginShot(eng);
        why = "";
    }

    // Where it pitches is the shot. Everything after that is the run-out.
    function _onDeck(eng) as Lang.Number {
        ball.y  = floorY - phys.r;
        ball.vy = -ball.vy * 0.34;
        ball.vx = ball.vx * 0.55;

        var d = DsUtil.absF(ball.x - hx);
        if (d <= phys.r * 1.6) { why = "straight in";      return DS_OUT_SWISH; }
        if (d <= near)         { why = "inside the leather"; return DS_OUT_BANK; }
        if (d <= far)          { why = "on the green";     return DS_OUT_RIM; }
        why = (ball.x < hx) ? "left it short" : "ran through";
        return DS_OUT_MISS;
    }

    function _deadEnd(eng) as Lang.Number {
        if (why.length() == 0) { why = "never got there"; }
        return DS_OUT_MISS;
    }

    function _settlesAfter(outcome as Lang.Number) as Lang.Boolean {
        return outcome != DS_OUT_SWISH;      // a holed ball stays holed
    }

    function outcomeText(outcome as Lang.Number) as Lang.String {
        if (outcome == DS_OUT_SWISH) { return "HOLED IT!"; }
        if (outcome == DS_OUT_BANK)  { return "STONE DEAD"; }
        if (outcome == DS_OUT_RIM)   { return "ON THE GREEN"; }
        return "MISSED THE GREEN";
    }

    function outcomeHint() as Lang.String { return why; }

    // ── Paint ───────────────────────────────────────────────────────────────
    function _drawScene(dc, eng) as Void {
        var fy = floorY.toNumber();
        var hz = fy - (sh * 24) / 100;
        DsSportArt.sky(dc, venue, sw, sh, hz, frame);
        DsSportArt.turf(dc, venue, sw, sh, hz, fy);
        DsSportArt.greenBands(dc, hx.toNumber(), fy, near.toNumber(),
                              far.toNumber());
        DsSportArt.hole(dc, hx.toNumber(), fy, (phys.r * 1.6).toNumber());
        DsSportArt.pin(dc, hx.toNumber(), fy, pinH.toNumber(),
                       Math.sin(frame * 0.13), fx.rimFlash > 0);
        _drawGolfer(dc, eng);
    }

    hidden function _drawGolfer(dc, eng) as Void {
        var hr = (sh * 0.026).toNumber(); if (hr < 3) { hr = 3; }
        var crouch = 0.20;
        var arm    = 0.2;
        if (eng.state == DS_ST_POWER)        { crouch = 0.20; arm = -0.9 * eng.power; }
        else if (eng.state == DS_ST_RELEASE) { crouch = 0.16; arm = -0.9 + 1.9 * eng.relT; }
        else if (eng.state != DS_ST_AIM)     { crouch = 0.10; arm = 1.0; }

        DsSportArt.athlete(dc, (lx - hr * 2).toNumber(), floorY.toNumber(),
                           hr, 0xFFFFFF, 0xFF5500, crouch, arm);
    }

    function _drawProjectile(dc, eng) as Void {
        var r = phys.r.toNumber(); if (r < 3) { r = 3; }
        if (ball.flying || settling) {
            DsArt.trailArt(dc, 1, trail, r);
            DsSportArt.golfBall(dc, ball.x.toNumber(), ball.y.toNumber(), r);
            return;
        }
        if (eng.state == DS_ST_FEEDBACK) {
            DsSportArt.golfBall(dc, landX.toNumber(), landY.toNumber(), r);
            return;
        }
        DsSportArt.golfBall(dc, lx.toNumber(), ly.toNumber(), r);
    }
}
