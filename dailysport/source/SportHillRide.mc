// ═══════════════════════════════════════════════════════════════════════════
// SportHillRide.mc — The ski jump.
//
// The one sport in the rotation with no target to hit: there is only a hill,
// and the question is where on it you come down. The K-point is painted red,
// the safe line blue, and the ground rises to meet the jumper on a real
// landing-hill profile — steep off the lip, flattening into the outrun — so
// hanging on for another few metres genuinely gets harder the further out you
// go, exactly as it does on a real hill.
//
// Overshooting the K-point still scores. Falling short of the blue line does
// not. That asymmetry is the sport.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

class SportHillRide extends DsSportBase {

    var takeX;     // Float — the lip
    var takeY;     // Float
    var outX;      // Float — where the hill flattens into the outrun
    var outY;      // Float
    var kx;        // Float — the K-point
    var safeX;     // Float — the shortest landing that still scores
    var band;      // Float — how close to the K-point counts as perfect
    var venue;     // Number
    var why;       // String

    function initialize() {
        DsSportBase.initialize();
        takeX = 0.0; takeY = 0.0; outX = 0.0; outY = 0.0;
        kx = 0.0; safeX = 0.0; band = 0.0;
        venue = 0; why = "";
    }

    function id()         as Lang.String { return "hillride"; }
    function name()       as Lang.String { return "HILL RIDE"; }
    function actionWord() as Lang.String { return "JUMP"; }
    function aimMin()     as Lang.Float  { return 4.0; }
    function aimMax()     as Lang.Float  { return 42.0; }
    function refAngle()   as Lang.Float  { return 15.0; }

    function projectileR() as Lang.Float {
        var r = sh * 0.024;
        return (r < 3.0) ? 3.0 : r;
    }

    function _subSteps() as Lang.Number { return 3; }

    function _place(eng, w as Lang.Number, h as Lang.Number) as Void {
        venue = ProgressionManager.courtIndex();
        takeX = w * 0.26;
        takeY = h * 0.40;
        outX  = w * 0.88;
        outY  = h * 0.86;

        floorY = outY;
        lx     = takeX;
        ly     = takeY - h * 0.048;

        var ch = eng.ch;
        kx    = w * (ch.dist + 0.04);
        safeX = takeX + (kx - takeX) * 0.55;
        // Precision days narrow the K-point band rather than move the hill.
        var tight = 1.0 - ch.sway * 4.0;
        if (tight < 0.5) { tight = 0.5; }
        band = (kx - takeX) * 0.11 * tight;
    }

    function _refPoint() as Lang.Array { return [kx, hillY(kx)]; }

    function _surfaceY(x as Lang.Float) as Lang.Float { return hillY(x); }

    // The landing hill: steep off the lip, flattening into the outrun.
    function hillY(x as Lang.Float) as Lang.Float {
        if (x <= takeX) { return takeY; }
        if (x >= outX)  { return outY; }
        var t = (x - takeX) / (outX - takeX);
        return takeY + (outY - takeY) * (2.0 * t - t * t);
    }

    function beginShot(eng) as Void {
        DsSportBase.beginShot(eng);
        why = "";
    }

    // ── The verdict ─────────────────────────────────────────────────────────
    function _verdict(eng) as Lang.Number {
        if (ball.y + phys.r < hillY(ball.x)) { return DS_OUT_NONE; }
        var x = ball.x;
        ball.y = hillY(x) - phys.r;

        if (x < safeX)                  { why = "fell short";   return DS_OUT_MISS; }
        if (DsUtil.absF(x - kx) <= band) { why = "K-point";      return DS_OUT_SWISH; }
        if (x > kx)                     { why = "past the K";   return DS_OUT_BANK; }
        why = "safe landing";
        return DS_OUT_RIM;
    }

    function _deadEnd(eng) as Lang.Number {
        if (why.length() == 0) { why = "no distance"; }
        return DS_OUT_MISS;
    }

    function outcomeText(outcome as Lang.Number) as Lang.String {
        if (outcome == DS_OUT_SWISH) { return "K-POINT!"; }
        if (outcome == DS_OUT_BANK)  { return "BIG AIR"; }
        if (outcome == DS_OUT_RIM)   { return "LANDED"; }
        return "CRASHED OUT";
    }

    function outcomeHint() as Lang.String { return why; }

    // ── Paint ───────────────────────────────────────────────────────────────
    function _drawScene(dc, eng) as Void {
        DsSportArt.sky(dc, venue, sw, sh, (takeY * 0.92).toNumber(), frame);
        DsSportArt.skiBackdrop(dc, sw, sh, takeX.toNumber(), takeY.toNumber(),
                               outY.toNumber());
        _drawHill(dc);
        DsSportArt.skiInrun(dc, sh, takeX.toNumber(), takeY.toNumber());
    }

    // The hill surface, drawn from the same curve the verdict uses so the
    // jumper never lands in mid-air or inside the snow.
    hidden function _drawHill(dc) as Void {
        var steps = 10;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < steps; i++) {
            var x0 = takeX + (outX - takeX) * i / steps;
            var x1 = takeX + (outX - takeX) * (i + 1) / steps;
            dc.fillPolygon([[x0.toNumber(), hillY(x0).toNumber()],
                            [x1.toNumber(), hillY(x1).toNumber()],
                            [x1.toNumber(), sh],
                            [x0.toNumber(), sh]]);
        }
        dc.fillRectangle(0, takeY.toNumber(), takeX.toNumber(),
                         sh - takeY.toNumber());
        dc.fillRectangle(outX.toNumber(), outY.toNumber(),
                         sw - outX.toNumber(), sh - outY.toNumber());

        DsSportArt.hillMark(dc, safeX.toNumber(), hillY(safeX).toNumber(),
                            sh, 0x0055AA);
        DsSportArt.hillMark(dc, kx.toNumber(), hillY(kx).toNumber(),
                            sh, 0xFF0000);
    }

    function _drawProjectile(dc, eng) as Void {
        var s = (sh * 0.075).toNumber(); if (s < 7) { s = 7; }
        if (ball.flying) {
            DsArt.trailArt(dc, 1, trail, phys.r.toNumber());
            DsSportArt.jumper(dc, ball.x.toNumber(), ball.y.toNumber(),
                              ball.vx, ball.vy, s);
            return;
        }
        if (eng.state == DS_ST_FEEDBACK) {
            DsSportArt.jumper(dc, landX.toNumber(), landY.toNumber(),
                              1.0, 0.35, s);
            return;
        }
        // On the lip, crouched into the inrun, leaning further out as the
        // player winds the power up.
        var lean = 0.35;
        if (eng.state == DS_ST_POWER)        { lean = 0.35 - 0.30 * eng.power; }
        else if (eng.state == DS_ST_RELEASE) { lean = 0.05 - 0.20 * eng.relT; }
        DsSportArt.jumper(dc, lx.toNumber(), ly.toNumber(), 1.0, lean, s);
    }
}
