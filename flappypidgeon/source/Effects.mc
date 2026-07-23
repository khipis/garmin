// ═══════════════════════════════════════════════════════════════
// Effects.mc — Tiny, allocation-free particle system (juice).
//
// A fixed-size pool of particles used for the death feather burst,
// the near-miss sparks, and any other quick flourish. Everything is
// preallocated once; spawning overwrites the oldest slot so gameplay
// never allocates and the cost stays bounded no matter how spammy
// the effects get. Rendering is primitives-only (small filled
// circles) so it's cheap and asset-free on every device.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;
using Toybox.Graphics;

class Particles {
    // Pool capacity — small so the per-tick step/draw stays trivial even
    // on the slowest watch. A death burst uses ~12, near-miss ~4.
    hidden const CAP = 30;

    var px; var py;        // position (screen px, Float)
    var pvx; var pvy;      // velocity (px/tick, Float)
    var plife; var pmax;   // remaining / initial life in ticks
    var pcol; var psz;     // colour + base radius
    var pgrav;             // per-particle gravity (feathers fall, sparks float)
    hidden var _next;

    function initialize() {
        px    = new [CAP]; py    = new [CAP];
        pvx   = new [CAP]; pvy   = new [CAP];
        plife = new [CAP]; pmax  = new [CAP];
        pcol  = new [CAP]; psz   = new [CAP];
        pgrav = new [CAP];
        _next = 0;
        reset();
    }

    function reset() {
        for (var i = 0; i < CAP; i++) {
            px[i] = 0.0; py[i] = 0.0; pvx[i] = 0.0; pvy[i] = 0.0;
            plife[i] = 0; pmax[i] = 1; pcol[i] = 0xFFFFFF; psz[i] = 2;
            pgrav[i] = 0.0;
        }
    }

    hidden function _emit(x, y, vx, vy, life, col, sz, grav) {
        var i = _next;
        _next = (_next + 1) % CAP;
        px[i] = x; py[i] = y; pvx[i] = vx; pvy[i] = vy;
        plife[i] = life; pmax[i] = life; pcol[i] = col; psz[i] = sz;
        pgrav[i] = grav;
    }

    // Radial feather burst — outward in all directions with a slight
    // upward bias, tumbling to the ground under gravity. `col` is the
    // dominant feather colour (usually the bird's skin body colour).
    function burst(x, y, n, col) {
        for (var k = 0; k < n; k++) {
            var a  = (Math.rand().abs() % 360).toFloat() * Math.PI / 180.0;
            var sp = 1.6 + (Math.rand().abs() % 34) / 10.0;
            var vx = Math.cos(a) * sp;
            var vy = Math.sin(a) * sp - 1.4;            // upward pop
            var life = 16 + Math.rand().abs() % 14;
            // Alternate between the skin colour and off-white "down".
            var c = (k % 3 == 0) ? 0xF2F2F2 : col;
            var sz = 2 + Math.rand().abs() % 2;
            _emit(x, y, vx, vy, life, c, sz, 0.34);
        }
    }

    // Quick bright sparks for a near-miss squeeze through a gap.
    function spark(x, y, col) {
        for (var k = 0; k < 5; k++) {
            var a  = (Math.rand().abs() % 360).toFloat() * Math.PI / 180.0;
            var sp = 1.0 + (Math.rand().abs() % 22) / 10.0;
            var vx = Math.cos(a) * sp;
            var vy = Math.sin(a) * sp;
            var life = 6 + Math.rand().abs() % 6;
            _emit(x, y, vx, vy, life, col, 2, 0.05);
        }
    }

    // Advance every live particle one tick.
    function step() {
        for (var i = 0; i < CAP; i++) {
            if (plife[i] <= 0) { continue; }
            pvy[i] = pvy[i] + pgrav[i];
            px[i]  = px[i] + pvx[i];
            py[i]  = py[i] + pvy[i];
            plife[i] = plife[i] - 1;
        }
    }

    // True if any particle is still alive (lets the view keep redrawing).
    function alive() {
        for (var i = 0; i < CAP; i++) {
            if (plife[i] > 0) { return true; }
        }
        return false;
    }

    // Draw with an optional screen-shake offset (ox, oy).
    function draw(dc, ox, oy) {
        for (var i = 0; i < CAP; i++) {
            var life = plife[i];
            if (life <= 0) { continue; }
            // Fade brightness with remaining life.
            var f = (life * 100) / pmax[i];
            if (f > 100) { f = 100; }
            var col = _fade(pcol[i], f);
            var r = psz[i];
            if (f < 40) { r = r - 1; }
            if (r < 1) { r = 1; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((px[i]).toNumber() + ox, (py[i]).toNumber() + oy, r);
        }
    }

    // Scale a colour's channels by pct (0..100) for a cheap fade-to-black.
    hidden function _fade(col, pct) {
        var r = ((col >> 16) & 0xFF) * pct / 100;
        var g = ((col >> 8)  & 0xFF) * pct / 100;
        var b = (col & 0xFF) * pct / 100;
        return (r << 16) | (g << 8) | b;
    }
}
