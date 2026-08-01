// ═══════════════════════════════════════════════════════════════════════════
// SportTennis.mc — The serve.
//
// Two failure modes sit on either side of a narrow corridor: too flat and the
// ball is in the net, too much and it is long. The whole sport is that
// corridor, and the deep strip at the back of the service box — the ace — is
// the part of it closest to going long.
//
// The ball is judged where it first lands, like a real serve, so the bounce
// afterwards is decoration and the line call is never ambiguous.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

class SportTennis extends DsSportBase {

    var netX;       // Float
    var netTop;     // Float
    var boxNear;    // Float — service line
    var boxFar;     // Float — baseline of the box
    var boxDeep;    // Float — start of the ace strip
    var clipped;    // Boolean — the ball came off the net cord
    var venue;      // Number
    var why;        // String

    function initialize() {
        DsSportBase.initialize();
        netX = 0.0; netTop = 0.0;
        boxNear = 0.0; boxFar = 0.0; boxDeep = 0.0;
        clipped = false; venue = 0; why = "";
    }

    function id()         as Lang.String { return "tennis"; }
    function name()       as Lang.String { return "TENNIS"; }
    function actionWord() as Lang.String { return "SERVE"; }
    function aimMin()     as Lang.Float  { return 3.0; }
    function aimMax()     as Lang.Float  { return 34.0; }
    function refAngle()   as Lang.Float  { return 10.0; }

    function projectileR() as Lang.Float {
        var r = sh * 0.022;
        return (r < 3.0) ? 3.0 : r;
    }

    function _subSteps() as Lang.Number { return 3; }

    function _place(eng, w as Lang.Number, h as Lang.Number) as Void {
        venue  = ProgressionManager.courtIndex();
        floorY = h * 0.855;
        lx     = w * 0.12;
        ly     = floorY - h * 0.34;          // contact point, above the head

        var ch = eng.ch;
        netX   = w * 0.42;
        netTop = floorY - h * 0.115;

        // A tighter box on the days the challenge asks for precision: the
        // "moving target" seed narrows the corridor instead of sliding it.
        var pad = ch.sway * 0.9;
        boxNear = w * (0.52 + pad);
        boxFar  = w * (ch.dist + 0.06);
        boxDeep = boxFar - (boxFar - boxNear) * 0.34;
    }

    function _refPoint() as Lang.Array {
        return [(boxNear + boxFar) / 2.0, floorY];
    }

    function beginShot(eng) as Void {
        DsSportBase.beginShot(eng);
        clipped = false;
        why = "";
    }

    // ── The verdict ─────────────────────────────────────────────────────────
    // Only one thing can happen in the air: the net. Clearing it by a hair
    // still counts, and it is worth calling out — a serve off the cord that
    // drops in is the luckiest point in tennis.
    function _verdict(eng) as Lang.Number {
        var y = _crossY(netX);
        if (y < 0.0) { return DS_OUT_NONE; }
        if (y + phys.r > netTop) { why = "into the net"; return DS_OUT_MISS; }
        if (y + phys.r * 2.0 > netTop) {
            clipped = true;
            ball.vx = ball.vx * 0.90;
            fx.onRimContact();
        }
        return DS_OUT_NONE;
    }

    // Where it first lands is the call.
    function _onDeck(eng) as Lang.Number {
        ball.y  = floorY - phys.r;
        ball.vy = -ball.vy * 0.48;
        ball.vx = ball.vx * 0.86;

        var x = ball.x;
        if (x < boxNear) { why = "short of the line"; return DS_OUT_MISS; }
        if (x > boxFar)  { why = "long";              return DS_OUT_MISS; }
        if (clipped)      { why = "off the cord"; return DS_OUT_BANK; }
        if (x >= boxDeep) { why = "on the line";  return DS_OUT_SWISH; }
        why = "good serve";
        return DS_OUT_RIM;
    }

    function _deadEnd(eng) as Lang.Number {
        if (why.length() == 0) { why = "never crossed"; }
        return DS_OUT_MISS;
    }

    function _settlesAfter(outcome as Lang.Number) as Lang.Boolean { return true; }

    function outcomeText(outcome as Lang.Number) as Lang.String {
        if (outcome == DS_OUT_SWISH) { return "ACE!"; }
        if (outcome == DS_OUT_BANK)  { return "CLIPPED IN"; }
        if (outcome == DS_OUT_RIM)   { return "IN"; }
        return why.equals("into the net") ? "NET" : "FAULT";
    }

    function outcomeHint() as Lang.String { return why; }

    // ── Paint ───────────────────────────────────────────────────────────────
    function _drawScene(dc, eng) as Void {
        var fy = floorY.toNumber();
        var hz = fy - (sh * 20) / 100;
        DsSportArt.sky(dc, venue, sw, sh, hz, frame);
        _drawCourt(dc, hz, fy);
        DsSportArt.serviceBox(dc, boxNear.toNumber(), boxFar.toNumber(), fy,
                              boxDeep.toNumber(), sh);
        DsSportArt.tennisNet(dc, netX.toNumber(), netTop.toNumber(), fy);
        _drawServer(dc, eng);
    }

    hidden function _drawCourt(dc, hz as Lang.Number, fy as Lang.Number) as Void {
        var surface = 0x0055AA;
        var apron   = 0x005555;
        if (venue == 1) { surface = 0x005555; apron = 0x000055; }
        if (venue == 2) { surface = 0xAA5500; apron = 0x550000; }   // clay
        if (venue == 3) { surface = 0x00AA00; apron = 0x005500; }   // grass

        dc.setColor(apron, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, hz, sw, sh - hz);
        dc.setColor(surface, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, hz + (sh * 3) / 100, sw, sh);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, fy, sw, 2);
    }

    hidden function _drawServer(dc, eng) as Void {
        var hr = (sh * 0.026).toNumber(); if (hr < 3) { hr = 3; }
        var crouch = 0.0;
        var arm    = 0.4;
        if (eng.state == DS_ST_AIM)          { crouch = 0.12; arm = 0.5 + 0.1 * Math.sin(frame * 0.2); }
        else if (eng.state == DS_ST_POWER)   { crouch = 0.25 + 0.45 * eng.power; arm = 0.7; }
        else if (eng.state == DS_ST_RELEASE) { crouch = 0.7 - 0.7 * eng.relT; arm = 1.0; }
        else                                 { crouch = 0.0; arm = 1.0; }

        var ax = (lx - hr).toNumber();
        DsSportArt.athlete(dc, ax, floorY.toNumber(), hr, 0xFFFFFF, 0x00AAAA,
                           crouch, arm);
        // Racket head, held at the contact point the ball is served from.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(lx.toNumber(), ly.toNumber(), (hr * 4) / 3);
        dc.setPenWidth(1);
    }

    function _drawProjectile(dc, eng) as Void {
        var r = phys.r.toNumber(); if (r < 3) { r = 3; }
        if (ball.flying || settling) {
            DsArt.trailArt(dc, 1, trail, r);
            DsSportArt.tennisBall(dc, ball.x.toNumber(), ball.y.toNumber(),
                                  r, ball.spin);
            return;
        }
        DsSportArt.tennisBall(dc, lx.toNumber(), ly.toNumber(), r, 0.0);
    }
}
