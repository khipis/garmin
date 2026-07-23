// ═══════════════════════════════════════════════════════════════
// Effects.mc — Juice layer: spark particles + floating score popups.
//
// Both live in fixed-size, pre-allocated pools (no per-frame
// allocation in the hot path — critical on the slowest Garmin
// devices). The GameController owns one FxSystem, ticks it once per
// frame, and MainView reads the pools to draw them (offset by the
// current screen-shake so the FX shake with the playfield).
//
// A dead particle/popup has life <= 0 and is skipped by both the
// updater and the renderer; spawning recycles the first dead slot.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

class Particle {
    var x; var y;
    var vx; var vy;
    var life;      // frames remaining
    var maxLife;
    var color;
    var big;       // true → 2px spark, false → 1px

    function initialize() {
        x = 0.0; y = 0.0; vx = 0.0; vy = 0.0;
        life = 0; maxLife = 1; color = 0xFFFFFF; big = false;
    }
}

class ScorePopup {
    var x; var y;
    var vy;
    var life;
    var maxLife;
    var color;
    var text;

    function initialize() {
        x = 0; y = 0; vy = -0.8;
        life = 0; maxLife = 1; color = 0xFFFFFF; text = "";
    }
}

class FxSystem {
    static var PCAP = 30;      // particle pool size
    static var UCAP = 6;       // popup pool size
    static var PGRAV = 0.22;   // spark gravity px/tick^2

    var parts;
    var pops;

    function initialize() {
        parts = new [PCAP];
        for (var i = 0; i < PCAP; i++) { parts[i] = new Particle(); }
        pops = new [UCAP];
        for (var j = 0; j < UCAP; j++) { pops[j] = new ScorePopup(); }
    }

    function reset() {
        for (var i = 0; i < PCAP; i++) { parts[i].life = 0; }
        for (var j = 0; j < UCAP; j++) { pops[j].life = 0; }
    }

    // Non-negative random in [0, n). Math.rand() may be negative, and
    // Number %-operator on a negative operand is legal but yields a
    // negative result — we want a clean positive index here.
    hidden function _rnd(n) {
        var r = Math.rand();
        if (r < 0) { r = -r; }
        return r % n;
    }

    // Emit `n` sparks bursting outward from (x,y) at ~speed px/tick.
    function burst(x, y, color, n, speed, big) {
        var made = 0;
        for (var i = 0; i < PCAP && made < n; i++) {
            var p = parts[i];
            if (p.life > 0) { continue; }
            var ang = (made * 6.2831853) / n + _rnd(100) * 0.01;
            var sp  = speed * (0.55 + _rnd(60) * 0.01);
            p.x = x; p.y = y;
            p.vx = sp * Math.cos(ang);
            p.vy = sp * Math.sin(ang) - 0.6;
            p.maxLife = 12 + _rnd(10);
            p.life = p.maxLife;
            p.color = color;
            p.big = big;
            made = made + 1;
        }
    }

    // Directional spark cone (e.g. off a flipper) — biased toward
    // (dirx,diry).
    function spray(x, y, dirx, diry, color, n, speed) {
        var made = 0;
        for (var i = 0; i < PCAP && made < n; i++) {
            var p = parts[i];
            if (p.life > 0) { continue; }
            var jx = (_rnd(100) - 50) * 0.02;
            var jy = (_rnd(100) - 50) * 0.02;
            var sp = speed * (0.5 + _rnd(60) * 0.01);
            p.x = x; p.y = y;
            p.vx = (dirx + jx) * sp;
            p.vy = (diry + jy) * sp;
            p.maxLife = 10 + _rnd(8);
            p.life = p.maxLife;
            p.color = color;
            p.big = false;
            made = made + 1;
        }
    }

    function popup(text, x, y, color) {
        for (var i = 0; i < UCAP; i++) {
            var u = pops[i];
            if (u.life > 0) { continue; }
            u.text = text; u.x = x; u.y = y;
            u.vy = -0.9; u.maxLife = 40; u.life = 40; u.color = color;
            return;
        }
        // Pool full — overwrite the oldest (lowest remaining life).
        var minI = 0; var minL = pops[0].life;
        for (var k = 1; k < UCAP; k++) {
            if (pops[k].life < minL) { minL = pops[k].life; minI = k; }
        }
        var o = pops[minI];
        o.text = text; o.x = x; o.y = y;
        o.vy = -0.9; o.maxLife = 40; o.life = 40; o.color = color;
    }

    function step() {
        for (var i = 0; i < PCAP; i++) {
            var p = parts[i];
            if (p.life <= 0) { continue; }
            p.x = p.x + p.vx;
            p.y = p.y + p.vy;
            p.vy = p.vy + PGRAV;
            p.vx = p.vx * 0.96;
            p.life = p.life - 1;
        }
        for (var j = 0; j < UCAP; j++) {
            var u = pops[j];
            if (u.life <= 0) { continue; }
            u.y = u.y + u.vy;
            u.life = u.life - 1;
        }
    }
}
