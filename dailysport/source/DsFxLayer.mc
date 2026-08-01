// ═══════════════════════════════════════════════════════════════════════════
// DsFxLayer.mc — Confetti, sparks, score pops and the flash on a make.
//
// Feedback is what turns a correct simulation into a game that feels good, so
// every resolved shot pays out immediately and differently: a swish throws
// confetti and rings the screen gold, a rattle throws sparks off the iron, a
// brick kicks dust off the deck.
//
// The whole system is a fixed-size array of sixteen particles with no
// allocation after construction — it costs the same on a frame where nothing
// happens as on the frame after a swish.
//
// There is no alpha on these displays, so "fading" means stepping a colour
// down the 0xFF → 0xAA → 0x55 ramp. On a MIP panel that reads as a fade.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

const DS_P_MAX  = 16;

// Particle kinds.
const DS_P_CONFETTI = 0;   // a swish: bright, slow, drifting down
const DS_P_SPARK    = 1;   // iron: fast, hot, short-lived
const DS_P_DUST     = 2;   // the deck: grey, low, spreading

class DsFxSys {

    // Particles are flat arrays [x, y, vx, vy, life, kind]; life counts down
    // in seconds and doubles as the "slot is free" flag at <= 0.
    var p;
    var popText;
    var popX;
    var popY;
    var popAge;     // Float seconds
    var popCol;
    var ringCol;    // edge flash colour, 0 when idle
    var ringAge;
    var netWave;    // 1.0 right after a make, decaying to 0
    var rimFlash;   // frames of white-hot rim left

    function initialize() {
        p = new [DS_P_MAX];
        for (var i = 0; i < DS_P_MAX; i++) { p[i] = [0.0, 0.0, 0.0, 0.0, 0.0, 0]; }
        reset();
    }

    function reset() as Void {
        for (var i = 0; i < DS_P_MAX; i++) { p[i][4] = 0.0; }
        popText = null; popX = 0; popY = 0; popAge = 0.0; popCol = DS_TEXT;
        ringCol = 0; ringAge = 0.0; netWave = 0.0; rimFlash = 0;
    }

    // ── Emitters ────────────────────────────────────────────────────────────
    function burst(x as Lang.Number, y as Lang.Number, n as Lang.Number,
                   kind as Lang.Number, scale as Lang.Float) as Void {
        var made = 0;
        for (var i = 0; i < DS_P_MAX && made < n; i++) {
            if (p[i][4] > 0.0) { continue; }
            // Deterministic fan-out: cheap, and it never clumps.
            var a = (made * 2.399963) + (kind * 0.7);
            var sp = scale * ((kind == DS_P_SPARK) ? 150.0 : 70.0);
            var mag = sp * (0.45 + 0.55 * ((made % 3) / 2.0));
            p[i][0] = x.toFloat();
            p[i][1] = y.toFloat();
            p[i][2] = Math.cos(a) * mag;
            p[i][3] = Math.sin(a) * mag - ((kind == DS_P_DUST) ? mag * 0.6 : 0.0);
            p[i][4] = (kind == DS_P_SPARK) ? 0.35 : 0.75;
            p[i][5] = kind;
            made = made + 1;
        }
    }

    function pop(text as Lang.String, x as Lang.Number, y as Lang.Number,
                 col as Lang.Number) as Void {
        popText = text; popX = x; popY = y; popAge = 0.0; popCol = col;
    }

    function ring(col as Lang.Number) as Void { ringCol = col; ringAge = 0.0; }

    // One call covers everything a resolved shot should feel like.
    function onOutcome(outcome as Lang.Number, x as Lang.Number,
                       y as Lang.Number, gained as Lang.Number,
                       scale as Lang.Float) as Void {
        if (outcome == DS_OUT_SWISH) {
            burst(x, y, 10, DS_P_CONFETTI, scale);
            ring(DS_GOLD);
            netWave = 1.0;
            if (gained > 0) { pop("+" + gained.toString(), x, y, DS_GOLD); }
        } else if (outcome == DS_OUT_RIM || outcome == DS_OUT_BANK) {
            burst(x, y, 7, DS_P_SPARK, scale);
            ring(DS_GREEN);
            netWave = 0.8;
            rimFlash = 4;
            if (gained > 0) { pop("+" + gained.toString(), x, y, DS_GREEN); }
        } else {
            burst(x, y, 5, DS_P_DUST, scale);
        }
    }

    function onRimContact() as Void { rimFlash = 3; }

    // ── Frame ───────────────────────────────────────────────────────────────
    function tick(dt as Lang.Float, gravity as Lang.Float) as Void {
        for (var i = 0; i < DS_P_MAX; i++) {
            if (p[i][4] <= 0.0) { continue; }
            p[i][4] = p[i][4] - dt;
            p[i][0] = p[i][0] + p[i][2] * dt;
            p[i][1] = p[i][1] + p[i][3] * dt;
            p[i][3] = p[i][3] + gravity * dt * 0.5;
            p[i][2] = p[i][2] * 0.96;
        }
        if (popText != null) {
            popAge = popAge + dt;
            if (popAge > 0.85) { popText = null; }
        }
        if (ringCol != 0) {
            ringAge = ringAge + dt;
            if (ringAge > 0.4) { ringCol = 0; }
        }
        if (netWave > 0.0) {
            netWave = netWave - dt * 2.2;
            if (netWave < 0.0) { netWave = 0.0; }
        }
        if (rimFlash > 0) { rimFlash = rimFlash - 1; }
    }

    // ── Paint ───────────────────────────────────────────────────────────────
    function draw(dc, w as Lang.Number, h as Lang.Number, r as Lang.Number) as Void {
        for (var i = 0; i < DS_P_MAX; i++) {
            var life = p[i][4];
            if (life <= 0.0) { continue; }
            var kind = p[i][5];
            var f = life / ((kind == DS_P_SPARK) ? 0.35 : 0.75);
            dc.setColor(_pcol(kind, f), Graphics.COLOR_TRANSPARENT);
            var sz = (kind == DS_P_CONFETTI) ? 3 : 2;
            if (f < 0.4) { sz = sz - 1; }
            if (sz < 1) { sz = 1; }
            var px = p[i][0].toNumber();
            var py = p[i][1].toNumber();
            if (kind == DS_P_CONFETTI) { dc.fillRectangle(px, py, sz + 1, sz); }
            else                       { dc.fillCircle(px, py, sz); }
        }

        if (popText != null) {
            var rise = (popAge * 46.0).toNumber();
            var col  = (popAge < 0.5) ? popCol : _fade(popCol);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(popX, popY - rise, Graphics.FONT_SMALL, popText,
                        Graphics.TEXT_JUSTIFY_CENTER |
                        Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // The edge flash is drawn last of all, over the HUD, so a swish lights up
    // the whole bezel for a moment.
    function drawRing(dc, w as Lang.Number, h as Lang.Number) as Void {
        if (ringCol == 0) { return; }
        var col = (ringAge < 0.2) ? ringCol : _fade(ringCol);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        if (w == h) { dc.drawCircle(w / 2, h / 2, w / 2 - 2); }
        else        { dc.drawRectangle(1, 1, w - 2, h - 2); }
        dc.setPenWidth(1);
    }

    hidden function _pcol(kind as Lang.Number, f as Lang.Float) as Lang.Number {
        if (kind == DS_P_CONFETTI) {
            if (f > 0.66) { return 0xFFFF55; }
            if (f > 0.33) { return 0xFFAA00; }
            return 0xAA5500;
        }
        if (kind == DS_P_SPARK) {
            if (f > 0.5) { return 0xFFFFFF; }
            return 0xFFAA55;
        }
        return (f > 0.5) ? 0xAAAAAA : 0x555555;
    }

    // One step down the MIP ramp — the only fade these panels can express.
    hidden function _fade(col as Lang.Number) as Lang.Number {
        var r = (col >> 16) & 0xFF;
        var g = (col >> 8) & 0xFF;
        var b = col & 0xFF;
        return (_down(r) << 16) | (_down(g) << 8) | _down(b);
    }

    hidden function _down(c as Lang.Number) as Lang.Number {
        if (c >= 0xFF) { return 0xAA; }
        if (c >= 0xAA) { return 0x55; }
        return 0x00;
    }
}
