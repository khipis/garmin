// ═══════════════════════════════════════════════════════════════════════════
// SportArchery.mc — The flattest shot in the rotation.
//
// Everything that makes basketball forgiving is gone: the arrow leaves almost
// flat, it crosses the range in a third of a second, and the scoring bands are
// concentric rings a few pixels wide. What is left is the release. A perfect
// release is a gold; a tenth of the window late is a red.
//
// The verdict is read off the exact radius the target face is drawn at, so
// what the player sees is what is scored — there is no hidden hitbox anywhere
// in this file.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

class SportArchery extends DsSportBase {

    var tx;        // Float — target centre
    var tyBase;    // Float — resting height of the centre
    var ty;        // Float — live height (the moving-target challenge)
    var tr;        // Float — face radius, the radius the rings are drawn at
    var travel;    // Float — how far the face rides
    var frozen;    // Boolean — held still once the arrow is away
    var venue;     // Number
    var why;       // String

    function initialize() {
        DsSportBase.initialize();
        tx = 0.0; tyBase = 0.0; ty = 0.0; tr = 0.0; travel = 0.0;
        frozen = false; venue = 0; why = "";
    }

    function id()         as Lang.String { return "archery"; }
    function name()       as Lang.String { return "ARCHERY"; }
    function actionWord() as Lang.String { return "LOOSE"; }
    function aimMin()     as Lang.Float  { return 2.0; }
    function aimMax()     as Lang.Float  { return 30.0; }
    function refAngle()   as Lang.Float  { return 11.0; }

    // An arrow is a sliver, not a ball. The radius is what the ring bands are
    // measured against, so it has to be honest about how thin the shaft is.
    function projectileR() as Lang.Float {
        var r = sh * 0.013;
        return (r < 2.0) ? 2.0 : r;
    }

    // Four sub-steps: at this speed a two-step frame can put the arrow in
    // front of the face on one sample and behind it on the next.
    function _subSteps() as Lang.Number { return 4; }

    function _place(eng, w as Lang.Number, h as Lang.Number) as Void {
        venue  = ProgressionManager.courtIndex();
        floorY = h * 0.86;
        lx     = w * 0.13;
        ly     = floorY - h * 0.21;

        var ch = eng.ch;
        tx     = w * (ch.dist + 0.08);
        tr     = w * 0.105;
        tyBase = floorY - h * (ch.height * 0.72);
        ty     = tyBase;
        travel = h * (ch.sway * 1.9);
        frozen = false;
    }

    function _refPoint() as Lang.Array { return [tx, tyBase]; }

    function _ambient(runMs as Lang.Number) as Void {
        if (travel <= 0.0 || frozen) { return; }
        var ph = (runMs % 3000) / 3000.0;
        ty = tyBase + travel * Math.sin(ph * 6.2831853);
    }

    function beginShot(eng) as Void {
        DsSportBase.beginShot(eng);
        frozen = false;
        why = "";
    }

    function _onFire(eng) as Void { frozen = true; }

    // ── The verdict ─────────────────────────────────────────────────────────
    function _verdict(eng) as Lang.Number {
        var y = _crossY(tx);
        if (y < 0.0) { return DS_OUT_NONE; }

        var d = DsUtil.absF(y - ty) - phys.r;
        if (d < 0.0) { d = 0.0; }

        if (d <= tr * 0.22) { why = "gold";            return DS_OUT_SWISH; }
        if (d <= tr * 0.55) { why = "red ring";        return DS_OUT_BANK; }
        if (d <= tr * 0.92) { why = "outer ring";      return DS_OUT_RIM; }
        why = (y < ty) ? "high and clear" : "low and clear";
        return DS_OUT_MISS;
    }

    function _deadEnd(eng) as Lang.Number {
        if (why.length() == 0) { why = "dropped short"; }
        return DS_OUT_MISS;
    }

    function _maxBounces() as Lang.Number { return 0; }

    function outcomeText(outcome as Lang.Number) as Lang.String {
        if (outcome == DS_OUT_SWISH) { return "GOLD! 10"; }
        if (outcome == DS_OUT_BANK)  { return "RED  8"; }
        if (outcome == DS_OUT_RIM)   { return "BLUE  6"; }
        return "OFF THE FACE";
    }

    function outcomeHint() as Lang.String { return why; }

    // ── Paint ───────────────────────────────────────────────────────────────
    function _drawScene(dc, eng) as Void {
        var fy = floorY.toNumber();
        var hz = fy - (sh * 20) / 100;
        DsSportArt.sky(dc, venue, sw, sh, hz, frame);
        DsSportArt.turf(dc, venue, sw, sh, hz, fy);

        // Shooting line, so the range reads as a measured distance rather
        // than as an empty field with a disc floating in it.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((sw * 20) / 100, fy + 4, 2, (sh * 4) / 100);

        DsSportArt.targetFace(dc, tx.toNumber(), ty.toNumber(), tr.toNumber(),
                              fx.rimFlash > 0);
        _drawArcher(dc, eng);
    }

    hidden function _drawArcher(dc, eng) as Void {
        var hr = (sh * 0.026).toNumber(); if (hr < 3) { hr = 3; }
        var draw = 0.0;
        if (eng.state == DS_ST_POWER)        { draw = eng.power; }
        else if (eng.state == DS_ST_RELEASE) { draw = 1.0 - eng.relT; }
        else if (eng.state == DS_ST_AIM)     { draw = 0.25; }

        DsSportArt.athlete(dc, (lx - hr * 2).toNumber(), floorY.toNumber(),
                           hr, 0x00AA55, 0xFFFFFF, 0.10, 0.75);

        // The bow, and the string pulled back by however much of the power
        // meter the player has taken.
        var bx = lx.toNumber();
        var by = ly.toNumber();
        var bh = (sh * 0.10).toNumber();
        dc.setColor(0xAA5500, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawArc(bx, by, bh, Graphics.ARC_CLOCKWISE, 300, 60);
        dc.setPenWidth(1);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var pull = (draw * bh * 0.55).toNumber();
        dc.drawLine(bx + (bh / 2), by - bh, bx - pull, by);
        dc.drawLine(bx + (bh / 2), by + bh, bx - pull, by);
    }

    function _drawProjectile(dc, eng) as Void {
        var len = (sh * 0.10).toNumber(); if (len < 8) { len = 8; }
        if (ball.flying || settling) {
            DsSportArt.arrow(dc, ball.x.toNumber(), ball.y.toNumber(),
                             ball.vx, ball.vy, len);
            return;
        }
        // Between shots the arrow is either standing in whatever it hit or
        // nocked on the string, never nowhere.
        if (eng.state == DS_ST_FEEDBACK) {
            DsSportArt.arrow(dc, landX.toNumber(), landY.toNumber(),
                             1.0, 0.12, len);
            return;
        }
        DsSportArt.arrow(dc, lx.toNumber(), ly.toNumber(), 1.0, 0.0, len);
    }
}
