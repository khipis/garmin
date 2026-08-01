// ═══════════════════════════════════════════════════════════════════════════
// SportFootball.mc — The free kick.
//
// The goal is a plane with four bands across it, and the keeper is a solid
// stretch of that plane you have to shoot around. The keeper freezes the
// moment the ball is struck, exactly as the ring freezes in basketball: the
// player is allowed to see the gap before committing, so a goal is something
// they aimed at rather than something they were awarded.
//
// The top corner is the perfect strike. It is the smallest band, it sits
// directly under the bar, and clipping the bar on the way in still counts —
// which is what makes going for it the interesting decision rather than the
// stupid one.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

class SportFootball extends DsSportBase {

    var gx;         // Float — the goal line
    var gTop;       // Float — the underside of the bar
    var depth;      // Float — how far the net runs back
    var kx;         // Float — keeper's line
    var kBase;      // Float — keeper's resting centre
    var kY;         // Float — keeper's live centre
    var kH;         // Float — keeper's height
    var kTravel;    // Float — how far the keeper patrols
    var kFrozen;    // Boolean
    var venue;      // Number — cosmetic
    var why;        // String — why the last shot ended the way it did

    function initialize() {
        DsSportBase.initialize();
        gx = 0.0; gTop = 0.0; depth = 0.0;
        kx = 0.0; kBase = 0.0; kY = 0.0; kH = 0.0; kTravel = 0.0;
        kFrozen = false;
        venue = 0;
        why = "";
    }

    function id()         as Lang.String { return "football"; }
    function name()       as Lang.String { return "FOOTBALL"; }
    function actionWord() as Lang.String { return "STRIKE"; }
    function aimMin()     as Lang.Float  { return 8.0; }
    function aimMax()     as Lang.Float  { return 54.0; }
    function refAngle()   as Lang.Float  { return 26.0; }

    function _place(eng, w as Lang.Number, h as Lang.Number) as Void {
        venue  = ProgressionManager.courtIndex();
        floorY = h * 0.855;
        lx     = w * 0.13;
        ly     = floorY - h * 0.052;

        var ch = eng.ch;
        gx    = w * (ch.dist + 0.06);
        gTop  = floorY - h * (ch.height + 0.06);
        depth = w * 0.10;

        // The keeper stands off the line and covers the middle of the mouth,
        // so both corners are always live and the player picks one.
        kH      = (floorY - gTop) * 0.38;
        kx      = gx - w * 0.035;
        kBase   = floorY - kH / 2 - (floorY - gTop) * 0.06;
        kY      = kBase;
        kTravel = h * (ch.sway * 1.6);
        kFrozen = false;
    }

    // Aim the power meter at the middle of the mouth: an honest 60% has to be
    // a shot on target, not one into the deck or over the stand.
    function _refPoint() as Lang.Array {
        return [gx, gTop + (floorY - gTop) * 0.45];
    }

    function _ambient(runMs as Lang.Number) as Void {
        if (kTravel <= 0.0 || kFrozen) { return; }
        var ph = (runMs % 2600) / 2600.0;
        kY = kBase + kTravel * Math.sin(ph * 6.2831853);
    }

    function beginShot(eng) as Void {
        DsSportBase.beginShot(eng);
        kFrozen = false;
        why = "";
    }

    function _onFire(eng) as Void { kFrozen = true; }

    // ── The verdict ─────────────────────────────────────────────────────────
    function _verdict(eng) as Lang.Number {
        var y = _crossY(gx);
        if (y < 0.0) { return DS_OUT_NONE; }

        var r     = phys.r;
        var mouth = floorY - gTop;

        if (y + r < gTop) { why = "over the bar";  return DS_OUT_MISS; }

        // The keeper's reach is his body plus a glove at each end.
        var reach = kH / 2.0 + r * 0.6 + mouth * 0.03;
        if (DsUtil.absF(y - kY) < reach) { why = "keeper got there"; return DS_OUT_MISS; }

        if (y - r < gTop + mouth * 0.05) { why = "in off the bar"; return DS_OUT_BANK; }
        if (y < gTop + mouth * 0.32)     { why = "top corner";     return DS_OUT_SWISH; }
        why = "buried it";
        return DS_OUT_RIM;
    }

    function _deadEnd(eng) as Lang.Number {
        if (why.length() == 0) { why = "never troubled him"; }
        return DS_OUT_MISS;
    }

    function _settlesAfter(outcome as Lang.Number) as Lang.Boolean { return true; }
    function _maxBounces() as Lang.Number { return 2; }

    function outcomeText(outcome as Lang.Number) as Lang.String {
        if (outcome == DS_OUT_SWISH) { return "TOP CORNER!"; }
        if (outcome == DS_OUT_BANK)  { return "OFF THE BAR, IN"; }
        if (outcome == DS_OUT_RIM)   { return "GOAL!"; }
        return why.equals("keeper got there") ? "SAVED" : "NO GOAL";
    }

    function outcomeHint() as Lang.String { return why; }

    // ── Paint ───────────────────────────────────────────────────────────────
    function _drawScene(dc, eng) as Void {
        var fy = floorY.toNumber();
        var hz = fy - (sh * 22) / 100;
        DsSportArt.sky(dc, venue, sw, sh, hz, frame);
        DsSportArt.turf(dc, venue, sw, sh, hz, fy);
        DsSportArt.goal(dc, gx.toNumber(), gTop.toNumber(), fy,
                        depth.toNumber(), fx.rimFlash > 0);
        DsSportArt.keeper(dc, kx.toNumber(), kY.toNumber(), kH.toNumber(),
                          kFrozen ? 1.0 : 0.35 + 0.25 * Math.sin(frame * 0.2));
        _drawTaker(dc, eng);
    }

    // The run-up is the shot state: the taker loads through POWER, swings
    // through RELEASE and holds the follow-through while the ball is away.
    hidden function _drawTaker(dc, eng) as Void {
        var hr = (sh * 0.026).toNumber(); if (hr < 3) { hr = 3; }
        var crouch = 0.0;
        var arm    = 0.0;
        if (eng.state == DS_ST_AIM)          { crouch = 0.16 + 0.08 * Math.sin(frame * 0.22); }
        else if (eng.state == DS_ST_POWER)   { crouch = 0.30 + 0.50 * eng.power; }
        else if (eng.state == DS_ST_RELEASE) { crouch = 0.8 - 0.8 * eng.relT; arm = eng.relT; }
        else                                 { arm = 1.0; }

        DsSportArt.athlete(dc, (lx - phys.r * 2.2).toNumber(), floorY.toNumber(),
                           hr, 0xFF0000, 0xFFFFFF, crouch, arm);
    }

    function _drawProjectile(dc, eng) as Void {
        var r = phys.r.toNumber(); if (r < 3) { r = 3; }
        if (ball.flying || settling) {
            DsArt.trailArt(dc, 0, trail, r);
            DsSportArt.soccerBall(dc, ball.x.toNumber(), ball.y.toNumber(),
                                  r, ball.spin);
            return;
        }
        DsSportArt.soccerBall(dc, lx.toNumber(), ly.toNumber(), r, frame * 0.02);
    }
}
