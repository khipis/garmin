// ═══════════════════════════════════════════════════════════════════════════
// TdArt.mc — Every pixel in the game, drawn from Dc primitives.
//
// There are no bitmaps on this platform and no alpha, so depth comes from
// pre-darkened palette constants, a drop shadow under everything that stands
// on the ground, and silhouettes that change shape as a tower tiers up.
//
// Rotation is done without trigonometry: the caller sets a unit aim vector
// with aim() and quad() extrudes a rectangle along it using the perpendicular
// (-dy, dx). The animation phase and the entity unit are frame state set once
// by frame(), which also keeps every signature inside the 9-argument ceiling
// that pre-CIQ-4 virtual machines enforce.
//
// The two polygon buffers are allocated once and mutated in place: nothing in
// here allocates during a frame.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Lang;

// Barrels are gunmetal, not a dark tint of the tower colour: a 55%-shaded
// blue on a grey plinth is mud at this size. The type colour identifies the
// tower through its dome and its muzzle collar instead.
const TD_BARREL = 0x23282E;

module TdArt {

    var _q4 = null;    // reusable quad buffer
    var _t3 = null;    // reusable triangle buffer
    var _ph = 0;       // animation phase (game tick)
    var _uu = 4;       // entity unit for this frame
    var _ax = 1.0;     // aim direction
    var _ay = 0.0;

    function prep() as Void {
        if (_q4 == null) {
            _q4 = [[0, 0], [0, 0], [0, 0], [0, 0]];
            _t3 = [[0, 0], [0, 0], [0, 0]];
        }
    }

    function frame(phase as Lang.Number, u as Lang.Number) as Void {
        _ph = phase;
        _uu = u;
    }

    function aim(dx, dy) as Void {
        _ax = dx;
        _ay = dy;
    }

    // ── Primitive helpers ────────────────────────────────────────────────────

    // Rectangle extruded along the unit vector (dx,dy), from distance l0 to l1,
    // `hw` pixels to each side. This is how every barrel, tread and wing is
    // oriented without a single sin/cos call.
    function quad(dc, x, y, dx, dy, l0, l1, hw, col) as Void {
        var ax = x + dx * l0;
        var ay = y + dy * l0;
        var bx = x + dx * l1;
        var by = y + dy * l1;
        var ppx = -dy * hw;
        var ppy = dx * hw;
        _q4[0][0] = (ax + ppx).toNumber();  _q4[0][1] = (ay + ppy).toNumber();
        _q4[1][0] = (bx + ppx).toNumber();  _q4[1][1] = (by + ppy).toNumber();
        _q4[2][0] = (bx - ppx).toNumber();  _q4[2][1] = (by - ppy).toNumber();
        _q4[3][0] = (ax - ppx).toNumber();  _q4[3][1] = (ay - ppy).toNumber();
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(_q4);
    }

    // Same, along the current aim vector.
    function abar(dc, x, y, l0, l1, hw, col) as Void {
        quad(dc, x, y, _ax, _ay, l0, l1, hw, col);
    }

    // Isoceles triangle with its tip `len` along (dx,dy) and a base of 2*hw.
    function tri(dc, x, y, dx, dy, back, len, hw, col) as Void {
        var bx = x + dx * back;
        var by = y + dy * back;
        var ppx = -dy * hw;
        var ppy = dx * hw;
        _t3[0][0] = (x + dx * len).toNumber();  _t3[0][1] = (y + dy * len).toNumber();
        _t3[1][0] = (bx + ppx).toNumber();      _t3[1][1] = (by + ppy).toNumber();
        _t3[2][0] = (bx - ppx).toNumber();      _t3[2][1] = (by - ppy).toNumber();
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(_t3);
    }

    function diamond(dc, x, y, rx, ry, col) as Void {
        _q4[0][0] = x;       _q4[0][1] = y - ry;
        _q4[1][0] = x + rx;  _q4[1][1] = y;
        _q4[2][0] = x;       _q4[2][1] = y + ry;
        _q4[3][0] = x - rx;  _q4[3][1] = y;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(_q4);
    }

    // Squashed shadow. Real ellipses do not exist, so two overlapping circles
    // read as one wide blob for a fraction of the cost of a polygon.
    function shadow(dc, x, y, r, col) as Void {
        var rr = r;
        if (rr < 1) { rr = 1; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - rr / 2, y, rr);
        dc.fillCircle(x + rr / 2, y, rr);
    }

    // Offset for one of eight compass directions at distance d. Used wherever
    // something radiates (shards, static, portal swirl) so those effects never
    // need trigonometry either.
    function ringX(slot, d) {
        var a = slot % 8;
        if (a == 0) { return d; }
        if (a == 1) { return (d * 7) / 10; }
        if (a == 2) { return 0; }
        if (a == 3) { return (-d * 7) / 10; }
        if (a == 4) { return -d; }
        if (a == 5) { return (-d * 7) / 10; }
        if (a == 6) { return 0; }
        return (d * 7) / 10;
    }

    function ringY(slot, d) {
        var a = slot % 8;
        if (a == 0) { return 0; }
        if (a == 1) { return (-d * 7) / 10; }
        if (a == 2) { return -d; }
        if (a == 3) { return (-d * 7) / 10; }
        if (a == 4) { return 0; }
        if (a == 5) { return (d * 7) / 10; }
        if (a == 6) { return d; }
        return (d * 7) / 10;
    }

    // ── Terrain ──────────────────────────────────────────────────────────────

    // Meadow. Concentric fills are the obvious way to shade a round screen and
    // the wrong one: with no dithering each step shows as a hard ring. These
    // are off-centre overlapping blobs instead, so the lighter ground reads as
    // sunlight falling across the field rather than as a target.
    function ground(dc, cx, cy, rad) as Void {
        dc.setColor(TD_C_GRASS, TD_C_GRASS);
        dc.clear();
        dc.setColor(TD_C_GRASS2, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - rad / 5, cy - rad / 4, (rad * 66) / 100);
        dc.fillCircle(cx + rad / 4, cy + rad / 7, (rad * 58) / 100);
        dc.fillCircle(cx - rad / 7, cy + rad / 3, (rad * 44) / 100);
        var lit = TdUtil.mix(TD_C_GRASS2, 0x3A6A42, 55);
        dc.setColor(lit, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + rad / 8, cy - rad / 8, (rad * 36) / 100);
        dc.fillCircle(cx - rad / 3, cy + rad / 10, (rad * 24) / 100);
        // Vignette: several thin rings instead of two fat ones, so the falloff
        // to the bezel is a ramp and the square corners stay hidden.
        var pw = rad / 9 + 2;
        dc.setPenWidth(pw);
        for (var k = 0; k < 5; k++) {
            dc.setColor(TdUtil.shade(TD_C_GRASS, 76 - k * 15),
                        Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, (rad * 88) / 100 + (k * pw * 9) / 10);
        }
        dc.setPenWidth(1);
    }

    // Props. A tree is the cheapest thing that makes a top-down field read as
    // terrain instead of a colour: trunk, two canopy tones and a cast shadow
    // all lit from the upper left, same as every other object here.
    // The canopy tones have to sit well clear of the grass either side of them
    // or the tree disappears: a mid-green leaf over a mid-green field is one
    // flat shape. Hence the near-black outer ring and the bright top light.
    function tree(dc, x, y, s) as Void {
        if (s < 3) { s = 3; }
        shadow(dc, x + s / 3, y + s / 2, (s * 4) / 5, TdUtil.shade(TD_C_GRASS, 40));
        dc.setColor(0x3A2A18, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - s / 6, y - s / 3, s / 3 + 1, (s * 2) / 3);
        dc.setColor(0x0A1A0E, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - s / 2, s + 1);
        dc.setColor(0x18461F, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - s / 2, s);
        dc.setColor(0x2C7233, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s / 4, y - (s * 3) / 4, (s * 70) / 100);
        dc.setColor(0x5CAE52, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s / 3, y - s, (s * 36) / 100);
    }

    function rock(dc, x, y, s) as Void {
        if (s < 2) { s = 2; }
        shadow(dc, x + s / 3, y + s / 3, (s * 2) / 3, TdUtil.shade(TD_C_GRASS, 46));
        dc.setColor(0x474C46, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, s);
        dc.setColor(0x6A7068, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s / 4, y - s / 4, (s * 66) / 100);
        dc.setColor(0x8B928A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s / 3, y - s / 3, (s * 34) / 100);
    }

    // Cached props, drawn back to front by the caller's bake order.
    function props(dc, n, xs, ys, ss, ks, shx, shy) as Void {
        for (var i = 0; i < n; i++) {
            if (ks[i] == 0) { tree(dc, xs[i] + shx, ys[i] + shy, ss[i]); }
            else            { rock(dc, xs[i] + shx, ys[i] + shy, ss[i]); }
        }
    }

    // Cached scatter: grass tufts, pebbles and dark patches, all positioned
    // once at map load so the per-frame cost is one fillRectangle each.
    function deco(dc, n, xs, ys, ss, cs, shx, shy) as Void {
        for (var i = 0; i < n; i++) {
            dc.setColor(cs[i], Graphics.COLOR_TRANSPARENT);
            var s = ss[i];
            dc.fillRectangle(xs[i] + shx, ys[i] + shy, s, s);
        }
    }

    // Path, laid down in four widening-to-narrowing passes: trench shadow,
    // stone kerb, packed dirt, then the worn strip the enemies actually walk.
    // Each pass rounds its own corners, otherwise every bend shows a notch.
    function _stroke(dc, n, px, py, w, col, shx, shy) as Void {
        if (w < 1) { return; }
        dc.setPenWidth(w);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i < n; i++) {
            dc.drawLine(px[i - 1] + shx, py[i - 1] + shy, px[i] + shx, py[i] + shy);
        }
        for (var i = 1; i < n - 1; i++) {
            dc.fillCircle(px[i] + shx, py[i] + shy, w / 2);
        }
    }

    function pathBody(dc, n, px, py, pw, shx, shy) as Void {
        if (n < 2) { return; }
        _stroke(dc, n, px, py, pw + 6, TdUtil.shade(TD_C_DIRT_D, 62), shx, shy);
        _stroke(dc, n, px, py, pw + 3, 0x796A50, shx, shy);
        _stroke(dc, n, px, py, pw, TD_C_DIRT, shx, shy);
        _stroke(dc, n, px, py, (pw * 46) / 100,
                TdUtil.mix(TD_C_DIRT, 0x9A8058, 55), shx, shy);
        dc.setPenWidth(1);
    }

    function cobbles(dc, n, xs, ys, ss, cs, shx, shy) as Void {
        for (var i = 0; i < n; i++) {
            var s = ss[i];
            dc.setColor(TdUtil.shade(cs[i], 55), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(xs[i] + shx, ys[i] + shy + 1, s, s);
            dc.setColor(cs[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(xs[i] + shx, ys[i] + shy, s, s);
        }
    }

    // ── Landmarks ────────────────────────────────────────────────────────────

    // Spawn portal: a stone ring around a void that swirls with the phase.
    function portal(dc, x, y, u) as Void {
        var r = (u * 175) / 100;
        if (r < 5) { r = 5; }
        shadow(dc, x, y + r / 2, r * 2 / 3, TdUtil.shade(TD_C_GRASS, 45));
        dc.setColor(0x2A2438, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(0x6A5A88, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(x, y, r);
        dc.setPenWidth(1);
        dc.setColor(0x120A20, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (r * 70) / 100);
        var sw = (_ph / 2) % 8;
        var d = (r * 45) / 100;
        for (var k = 0; k < 3; k++) {
            var slot = sw + k * 3;
            dc.setColor((k == 0) ? 0xC898FF : 0x7A5AB0, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + ringX(slot, d), y + ringY(slot, d), (u * 30) / 100 + 1);
        }
    }

    // Base keep: a walled castle with corner turrets, a gate, and a core that
    // pulses faster and redder as the base takes damage. This is the thing the
    // player is protecting, so it gets more silhouette than anything else on
    // the board.
    function keep(dc, x, y, u, hpPct) as Void {
        var r = (u * 200) / 100;
        if (r < 6) { r = 6; }
        var cw = r / 2;
        if (cw < 2) { cw = 2; }
        shadow(dc, x, y + r / 2, (r * 4) / 5, TdUtil.shade(TD_C_GRASS, 42));

        dc.setColor(0x232932, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - r - 1, y - r - 1, r * 2 + 2, r * 2 + 2);
        dc.setColor(0x4A5260, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - r, y - r, r * 2, r * 2);
        dc.setColor(0x6B7683, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - r, y - r, r * 2, (r * 45) / 100);
        // Merlons along the parapet, and a gate on the near face.
        dc.setColor(0x7C8794, Graphics.COLOR_TRANSPARENT);
        var mw = cw / 2;
        if (mw < 1) { mw = 1; }
        for (var k = 0; k < 4; k++) {
            dc.fillRectangle(x - r + k * (r / 2) + mw / 2, y - r - mw, mw + 1, mw + 1);
        }
        dc.setColor(0x1B2028, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - cw / 2, y + r - cw, cw + 1, cw + 1);
        // Corner turrets read the outline even at 8px across.
        dc.setColor(0x59626F, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - r, y - r, cw / 2 + 1);
        dc.fillCircle(x + r, y - r, cw / 2 + 1);
        dc.fillCircle(x - r, y + r, cw / 2 + 1);
        dc.fillCircle(x + r, y + r, cw / 2 + 1);

        var speed = 8 - (hpPct * 5) / 100;
        if (speed < 2) { speed = 2; }
        var beat = (_ph / speed) % 3;
        var core = TD_C_HP;
        if (hpPct < 35)      { core = TD_C_DANGER; }
        else if (hpPct < 70) { core = TD_C_GOLD; }
        dc.setColor(TdUtil.shade(core, 40), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r / 2 + beat);
        dc.setColor(core, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r / 3 + beat / 2);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - r / 8, y - r / 8, r / 8 + 1);

        dc.setColor(0x2A3038, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y - r - cw, x, y - r - cw * 3);
        var fw = cw;
        if ((_ph / 5) % 2 != 0) { fw = (cw * 3) / 4; }
        dc.setColor(core, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 1, y - r - cw * 3, fw, cw);
    }

    // Build pad: a stone plate. Empty pads breathe faintly so they read as
    // interactive; the selected one gets a bright ring.
    function pad(dc, x, y, u, sel) as Void {
        var r = (u * 105) / 100;
        if (r < 4) { r = 4; }
        dc.setColor(TdUtil.shade(TD_C_GRASS, 50), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y + 1, r);
        dc.setColor(0x50564A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(0x6E766A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (r * 65) / 100);
        var glow = ((_ph / 4) % 6 < 3);
        dc.setColor(glow ? 0x8FA37E : 0x6E7A62, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r);
        if (sel) {
            dc.setPenWidth(2);
            dc.setColor(0xEFFFC8, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, r + 2);
            dc.setPenWidth(1);
        }
    }

    // Range preview. Four rotating arcs instead of a circle: same cost, and it
    // never buries the road it is drawn over.
    function rangeRing(dc, x, y, r, col) as Void {
        if (r < 3) { return; }
        var sp = (_ph * 4) % 90;
        // Two pixels wide, and a dark pass underneath: a one-pixel arc over
        // mixed grass and dirt reads as a scratch rather than a boundary.
        dc.setPenWidth(3);
        dc.setColor(0x101A14, Graphics.COLOR_TRANSPARENT);
        for (var k = 0; k < 4; k++) {
            var a0 = sp + k * 90;
            dc.drawArc(x, y, r, Graphics.ARC_COUNTER_CLOCKWISE, a0, a0 + 58);
        }
        dc.setPenWidth(2);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        for (var k = 0; k < 4; k++) {
            var a0 = sp + k * 90;
            dc.drawArc(x, y, r, Graphics.ARC_COUNTER_CLOCKWISE, a0, a0 + 58);
        }
        dc.setPenWidth(1);
    }

    // ── Towers ───────────────────────────────────────────────────────────────

    // One entry point. Call aim() first; `recoil` is how far the barrel is
    // pushed back this frame and `hot` means it just fired.
    function tower(dc, t, tier, x, y, u, recoil, hot) as Void {
        var col = TdUtil.towerColor(t);
        shadow(dc, x, y + u / 2, (u * 85) / 100, TdUtil.shade(TD_C_GRASS, 42));
        // Shared stone plinth; it widens by tier so progress reads at a glance.
        // The dark ring under it is what stops a tower merging into the grass
        // it stands on — there is no outline pass anywhere else in the frame.
        var pr = (u * (95 + tier * 8)) / 100;
        dc.setColor(0x1E2A1C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, pr + 1);
        dc.setColor(0x4A4E46, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, pr);
        dc.setColor(0x767D70, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (pr * 78) / 100);
        dc.setColor(0x8E958A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - pr / 5, y - pr / 5, (pr * 40) / 100);
        if (tier >= 2) {
            dc.setColor(TdUtil.shade(col, 60), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, pr);
        }

        if (t == TW_GUN)         { _gun(dc, tier, x, y, u, recoil, col, hot); }
        else if (t == TW_CANNON) { _cannon(dc, tier, x, y, u, recoil, col, hot); }
        else if (t == TW_ARCHER) { _archer(dc, tier, x, y, u, col); }
        else if (t == TW_FROST)  { _frost(dc, tier, x, y, u, col); }
        else if (t == TW_TESLA)  { _tesla(dc, tier, x, y, u, col, hot); }
        else if (t == TW_FLAME)  { _flame(dc, tier, x, y, u, col); }
        else                     { _sniper(dc, tier, x, y, u, recoil, col); }

        // Tier pips ring the plinth so you can count level without selecting.
        if (tier > 1) {
            dc.setColor(TD_C_GOLD, Graphics.COLOR_TRANSPARENT);
            var pip = u / 4;
            if (pip < 1) { pip = 1; }
            for (var k = 0; k < tier - 1; k++) {
                dc.fillRectangle(x - pr + k * (pip * 2 + 1), y + pr - pip, pip + 1, pip + 1);
            }
        }
    }

    function _gun(dc, tier, x, y, u, recoil, col, hot) as Void {
        var blen = (u * (150 + tier * 14)) / 100;
        var back = -recoil;
        var dark = TD_BARREL;
        if (tier >= 4) {
            var off = (u * 3) / 10;
            abar(dc, x - _ay * off, y + _ax * off, back, blen, u * 18 / 100 + 1, dark);
            abar(dc, x + _ay * off, y - _ax * off, back, blen, u * 18 / 100 + 1, dark);
        } else {
            abar(dc, x, y, back, blen, u * 22 / 100 + 1, dark);
        }
        // Muzzle collar in the tower colour: the only part of a thin dark
        // barrel that is still legible against grass at 2px wide.
        abar(dc, x, y, blen - u / 4, blen, u * 38 / 100 + 1, TdUtil.shade(col, 85));
        dc.setColor(TdUtil.shade(col, 80), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 58) / 100 + 1);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 40) / 100 + 1);
        if (hot) {
            dc.setColor(0xFFF3C0, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((x + _ax * (blen + 2)).toNumber(),
                          (y + _ay * (blen + 2)).toNumber(), u / 4 + 1);
        }
    }

    function _cannon(dc, tier, x, y, u, recoil, col, hot) as Void {
        var dark = TD_BARREL;
        // Carriage wheels sit across the aim line.
        if (tier >= 2) {
            var wo = (u * 85) / 100;
            dc.setColor(0x3A2A1E, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((x - _ay * wo).toNumber(), (y + _ax * wo).toNumber(), u / 3 + 1);
            dc.fillCircle((x + _ay * wo).toNumber(), (y - _ax * wo).toNumber(), u / 3 + 1);
        }
        var blen = (u * (150 + tier * 10)) / 100;
        var back = -recoil - u / 3;
        if (tier >= 4) {
            var off = (u * 4) / 10;
            abar(dc, x - _ay * off, y + _ax * off, back, blen, u * 24 / 100 + 1, dark);
            abar(dc, x + _ay * off, y - _ax * off, back, blen, u * 24 / 100 + 1, dark);
        } else {
            abar(dc, x, y, back, blen, u * 36 / 100 + 1, dark);
        }
        // Reinforcing band near the muzzle.
        abar(dc, x, y, blen - u / 3, blen - u / 6, u * 46 / 100 + 1, TdUtil.shade(col, 70));
        dc.setColor(TdUtil.shade(col, 62), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 72) / 100 + 1);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 48) / 100 + 1);
        if (hot) {
            var mx = (x + _ax * (blen + u / 3)).toNumber();
            var my = (y + _ay * (blen + u / 3)).toNumber();
            dc.setColor(0xFFE08A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx, my, u / 2 + 1);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx, my, u / 4 + 1);
        }
    }

    function _archer(dc, tier, x, y, u, col) as Void {
        // Timber platform with corner posts.
        dc.setColor(0x6B4A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 78) / 100 + 1);
        dc.setColor(0x8A6136, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 58) / 100 + 1);
        var post = u / 3;
        if (post < 1) { post = 1; }
        dc.setColor(0x4A3220, Graphics.COLOR_TRANSPARENT);
        var pr2 = (u * 70) / 100;
        dc.fillRectangle(x - pr2, y - pr2, post, post);
        dc.fillRectangle(x + pr2 - post, y - pr2, post, post);
        dc.fillRectangle(x - pr2, y + pr2 - post, post, post);
        dc.fillRectangle(x + pr2 - post, y + pr2 - post, post, post);
        // Bow, belly facing the target. The one place trig earns its keep.
        var ang = Math.atan2(-_ay, _ax) * 57.2958;
        var bx = (x + _ax * u * 45 / 100).toNumber();
        var by = (y + _ay * u * 45 / 100).toNumber();
        var br = (u * 70) / 100;
        if (br < 3) { br = 3; }
        dc.setPenWidth(2);
        dc.setColor(0xC9A86A, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(bx, by, br, Graphics.ARC_COUNTER_CLOCKWISE,
                   (ang - 62).toNumber(), (ang + 62).toNumber());
        dc.setPenWidth(1);
        // Nocked arrow.
        abar(dc, x, y, -u / 4, u * 110 / 100, 1, 0xE8DCC0);
        tri(dc, x, y, _ax, _ay, u * 95 / 100, u * 135 / 100, u * 22 / 100 + 1, col);
        if (tier >= 3) {
            var bob = ((_ph / 4) % 2);
            dc.setColor(0x3E6B34, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((x - _ax * u * 55 / 100).toNumber(),
                          (y - _ay * u * 55 / 100 + bob).toNumber(), u / 4 + 1);
        }
        if (tier >= 4) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 1, y - (u * 150) / 100, 2, u);
            tri(dc, x, y - (u * 145) / 100, 1.0, 0.0, 0.0,
                u * 60 / 100, u * 30 / 100 + 1, col);
        }
    }

    function _frost(dc, tier, x, y, u, col) as Void {
        var pulse = (_ph / 3) % 6;
        var amp = pulse;
        if (amp > 3) { amp = 6 - pulse; }
        dc.setColor(0x2A4E5E, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 80) / 100 + 1);
        dc.setColor(0x3E6E82, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, (u * 90) / 100 + amp);
        // Shard crown: one more spike per tier.
        var shards = 3 + tier;
        var sr = (u * 110) / 100;
        dc.setColor(TdUtil.shade(col, 70), Graphics.COLOR_TRANSPARENT);
        for (var k = 0; k < shards; k++) {
            var slot = (k * 8) / shards;
            dc.fillRectangle(x + ringX(slot, sr) / 2 - 1, y + ringY(slot, sr) / 2 - 1, 3, 3);
        }
        var cr = (u * 62) / 100 + 1;
        diamond(dc, x, y, cr * 3 / 4, cr, TdUtil.shade(col, 70));
        diamond(dc, x, y, cr / 2, cr * 3 / 4, col);
        dc.setColor(0xE8FCFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 1, y - cr / 2, 2, cr / 2);
    }

    function _tesla(dc, tier, x, y, u, col, hot) as Void {
        // Copper coil, read top-down as concentric windings.
        dc.setColor(0x7A5A38, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 88) / 100 + 1);
        dc.setColor(0xA8794A, Graphics.COLOR_TRANSPARENT);
        var rings = 2 + tier / 2;
        for (var k = 0; k < rings; k++) {
            var rr = (u * (85 - k * 18)) / 100;
            if (rr < 2) { break; }
            dc.drawCircle(x, y, rr);
        }
        dc.setColor(TdUtil.shade(col, 55), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 42) / 100 + 1);
        dc.setColor(0xF0E4FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 26) / 100 + 1);
        // Static forks jumping off the terminal; more of them while firing.
        var forks = hot ? 4 : 2;
        var d = (u * 95) / 100;
        dc.setColor(hot ? 0xFFFFFF : col, Graphics.COLOR_TRANSPARENT);
        for (var f = 0; f < forks; f++) {
            var slot = _ph * 3 + f * 5 + f * f;
            var ox = ringX(slot, d);
            var oy = ringY(slot, d);
            dc.drawLine(x, y, x + ox / 2, y + oy / 2);
            dc.drawLine(x + ox / 2, y + oy / 2, x + ox, y + oy - 1);
        }
    }

    function _flame(dc, tier, x, y, u, col) as Void {
        // Fuel drums straddling the nozzle.
        var fo = (u * 75) / 100;
        var fr = (u * (26 + tier * 4)) / 100 + 1;
        dc.setColor(0x54391F, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((x - _ay * fo).toNumber(), (y + _ax * fo).toNumber(), fr);
        dc.fillCircle((x + _ay * fo).toNumber(), (y - _ax * fo).toNumber(), fr);
        dc.setColor(0x6E4A28, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 70) / 100 + 1);
        abar(dc, x, y, 0, (u * (110 + tier * 8)) / 100, u * 22 / 100 + 1, 0x3A2A1E);
        // Pilot light flickers between two warm tones.
        var tip = (u * (115 + tier * 8)) / 100;
        var hotf = ((_ph / 2) % 3 != 0);
        dc.setColor(hotf ? 0xFFC24A : 0xFF6A3A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((x + _ax * tip).toNumber(), (y + _ay * tip).toNumber(), u / 4 + 1);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 34) / 100 + 1);
    }

    function _sniper(dc, tier, x, y, u, recoil, col) as Void {
        var blen = (u * (190 + tier * 22)) / 100;
        if (tier >= 2) {
            var lo = (u * 60) / 100;
            abar(dc, x, y, u / 2, u * 110 / 100, 1, 0x3A3A32);
            abar(dc, x - _ay * lo, y + _ax * lo, u / 2, u, 1, 0x3A3A32);
            abar(dc, x + _ay * lo, y - _ax * lo, u / 2, u, 1, 0x3A3A32);
        }
        abar(dc, x, y, -recoil, blen, u * 14 / 100 + 1, 0x3E3E36);
        if (tier >= 3) {
            abar(dc, x, y, blen - u / 3, blen, u * 28 / 100 + 1, TdUtil.shade(col, 70));
        }
        dc.setColor(0x55554A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 60) / 100 + 1);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (u * 34) / 100 + 1);
        // Scope glint: a rare white blink sells the "sniper" read instantly.
        var glint = ((_ph / 3) % 9 == 0);
        dc.setColor(glint ? 0xFFFFFF : 0x9AA8B4, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((x - _ax * u * 55 / 100).toNumber() - 1,
                         (y - _ay * u * 55 / 100).toNumber() - 1, 3, 3);
    }

    // Compact tower glyph for the shop rows and the post-wave summary.
    function towerIcon(dc, t, x, y, s) as Void {
        var col = TdUtil.towerColor(t);
        dc.setColor(0x1E2630, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, s);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        if (t == TW_GUN) {
            dc.fillCircle(x, y, s / 2);
            dc.fillRectangle(x, y - 1, s, 2);
        } else if (t == TW_CANNON) {
            dc.fillCircle(x - s / 4, y, s / 2);
            dc.fillRectangle(x, y - 2, s, 4);
        } else if (t == TW_ARCHER) {
            dc.drawArc(x - s / 3, y, s * 3 / 4, Graphics.ARC_COUNTER_CLOCKWISE, 300, 60);
            dc.fillRectangle(x - s / 2, y - 1, s * 3 / 2, 2);
        } else if (t == TW_FROST) {
            diamond(dc, x, y, s / 2, s, col);
        } else if (t == TW_TESLA) {
            dc.drawCircle(x, y, s * 2 / 3);
            dc.drawLine(x, y, x + s, y - s);
            dc.fillCircle(x, y, s / 3);
        } else if (t == TW_FLAME) {
            tri(dc, x - s / 2, y, 1.0, 0.0, 0.0, s * 3 / 2, s * 2 / 3, col);
        } else {
            dc.fillRectangle(x - s, y - 1, s * 2, 2);
            dc.fillCircle(x - s / 2, y, s / 3);
        }
    }

    // ── Enemies ──────────────────────────────────────────────────────────────

    // (x,y) is where the unit stands on the ground; flyers lift their own body
    // above it and keep the shadow behind. Call aim() with the travel
    // direction first. `flash` > 0 blanches the body for a couple of frames on
    // every hit, which is most of what makes shooting feel connected on a
    // screen this small.
    function enemy(dc, t, x, y, r, flash, slow, hpPct, extra) as Void {
        var col = TdUtil.enemyColor(t);
        if (flash > 0)     { col = TdUtil.mix(col, 0xFFFFFF, 70); }
        else if (slow > 0) { col = TdUtil.mix(col, 0x66DCEE, 35); }

        var by = y;
        if (t == EN_FLYER) {
            shadow(dc, x, y, r * 2 / 3, TdUtil.shade(TD_C_GRASS, 40));
            by = y - r * 2;
        } else {
            shadow(dc, x, y + r / 2, r * 3 / 4, TdUtil.shade(TD_C_GRASS, 44));
        }
        // Rim under the body. Enemies spend the whole run on brown dirt and
        // half of them are warm-coloured; without this they smear into it. It
        // is a dark tint of the unit's own colour rather than black, so it
        // reads as a shaded edge instead of a halo.
        dc.setColor(TdUtil.shade(col, 26), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, by, r + 1);

        if (t == EN_GRUNT)       { _grunt(dc, x, by, r, col); }
        else if (t == EN_RUNNER) { _runner(dc, x, by, r, col); }
        else if (t == EN_TANK)   { _tank(dc, x, by, r, col); }
        else if (t == EN_FLYER)  { _flyer(dc, x, by, r, col); }
        else if (t == EN_SHIELD) { _shield(dc, x, by, r, col, extra); }
        else if (t == EN_HEALER) { _healer(dc, x, by, r, col); }
        else                     { _boss(dc, x, by, r, col, hpPct, extra); }

        if (slow > 0) {
            dc.setColor(0x8AE8FA, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, by, r + 2);
            dc.fillRectangle(x - r, by - r - 1, 2, 2);
            dc.fillRectangle(x + r - 1, by + r - 1, 2, 2);
        }
    }

    function _legs(dc, x, y, r, col) as Void {
        var s = (r * 3) / 5;
        if (s < 1) { s = 1; }
        var f = ((_ph / 2) % 2 == 0) ? 1 : -1;
        var side = (r * 6) / 10;
        var stride = (r * f) / 2;
        dc.setColor(TdUtil.shade(col, 55), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((x - _ay * side + _ax * stride).toNumber() - s / 2,
                         (y + _ax * side + _ay * stride).toNumber(), s, s);
        dc.fillRectangle((x + _ay * side - _ax * stride).toNumber() - s / 2,
                         (y - _ax * side - _ay * stride).toNumber(), s, s);
    }

    // Seen from above a humanoid is torso, two shoulders and a head, and that
    // triangle is what makes it read as a soldier rather than a dot. The
    // shoulders sit across the aim axis, so the unit also visibly turns.
    function _grunt(dc, x, y, r, col) as Void {
        _legs(dc, x, y, r, col);
        // Shoulders sit proud of the torso, otherwise they vanish inside it.
        var so = (r * 95) / 100;
        dc.setColor(TdUtil.shade(col, 46), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((x - _ay * so).toNumber(), (y + _ax * so).toNumber(),
                      (r * 42) / 100 + 1);
        dc.fillCircle((x + _ay * so).toNumber(), (y - _ax * so).toNumber(),
                      (r * 42) / 100 + 1);
        dc.setColor(TdUtil.shade(col, 70), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((x - _ax * r / 6).toNumber(), (y - _ay * r / 6).toNumber(),
                      (r * 76) / 100);
        // Spear held forward, then the head over it.
        var sw = r / 6;
        if (sw < 1) { sw = 1; }
        abar(dc, x, y, (r * 6) / 10, (r * 19) / 10, sw, 0x2C2116);
        abar(dc, x, y, (r * 17) / 10, (r * 19) / 10, sw + 1, 0xB9BEC4);
        dc.setColor(TdUtil.mix(col, 0xFFFFFF, 42), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((x + _ax * r * 52 / 100).toNumber(),
                      (y + _ay * r * 52 / 100).toNumber(), (r * 44) / 100 + 1);
        dc.setColor(0x1A0E0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((x + _ax * r * 82 / 100).toNumber() - 1,
                         (y + _ay * r * 82 / 100).toNumber() - 1, 2, 2);
    }

    function _runner(dc, x, y, r, col) as Void {
        // Motion streaks behind the body sell the speed. They have to be
        // lighter than the unit, not darker: a runner spends its whole life on
        // brown dirt, and a dark streak there is invisible.
        dc.setPenWidth(2);
        dc.setColor(TdUtil.mix(col, 0xFFFFFF, 45), Graphics.COLOR_TRANSPARENT);
        var so = (r * 7) / 10;
        dc.drawLine((x - _ax * r * 25 / 10 - _ay * so).toNumber(),
                    (y - _ay * r * 25 / 10 + _ax * so).toNumber(),
                    (x - _ax * r * 11 / 10 - _ay * so).toNumber(),
                    (y - _ay * r * 11 / 10 + _ax * so).toNumber());
        dc.drawLine((x - _ax * r * 25 / 10 + _ay * so).toNumber(),
                    (y - _ay * r * 25 / 10 - _ax * so).toNumber(),
                    (x - _ax * r * 11 / 10 + _ay * so).toNumber(),
                    (y - _ay * r * 11 / 10 - _ax * so).toNumber());
        dc.setPenWidth(1);
        _legs(dc, x, y, r, col);
        abar(dc, x, y, -r * 9 / 10, r * 9 / 10, r * 62 / 100, TdUtil.shade(col, 62));
        abar(dc, x, y, -r * 6 / 10, r * 8 / 10, r * 42 / 100, col);
        dc.setColor(TdUtil.mix(col, 0xFFFFFF, 50), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((x + _ax * r * 78 / 100).toNumber(),
                      (y + _ay * r * 78 / 100).toNumber(), (r * 50) / 100 + 1);
        dc.setColor(0x2A1A08, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((x + _ax * r * 110 / 100).toNumber() - 1,
                         (y + _ay * r * 110 / 100).toNumber() - 1, 2, 2);
    }

    function _tank(dc, x, y, r, col) as Void {
        // Treads: two dark bars flanking the hull with light teeth that step
        // along as it crawls. The teeth are the animation — the bars alone
        // just read as an outline.
        var to = (r * 85) / 100;
        abar(dc, x - _ay * to, y + _ax * to, -r, r, r * 3 / 10, 0x241B14);
        abar(dc, x + _ay * to, y - _ax * to, -r, r, r * 3 / 10, 0x241B14);
        var step = ((_ph / 3) % 2 == 0) ? 0 : (r * 4) / 10;
        for (var k = 0; k < 3; k++) {
            var d = -r + step + (k * r * 8) / 10;
            if (d > r - 2) { continue; }
            quad(dc, x - _ay * to, y + _ax * to, _ax, _ay, d, d + 2,
                 r * 3 / 10, 0x5E4B37);
            quad(dc, x + _ay * to, y - _ax * to, _ax, _ay, d, d + 2,
                 r * 3 / 10, 0x5E4B37);
        }
        abar(dc, x, y, -r * 9 / 10, r * 9 / 10, r * 7 / 10, TdUtil.shade(col, 70));
        abar(dc, x, y, -r * 6 / 10, r * 6 / 10, r * 5 / 10, col);
        // Bolted frontal plate — the visual promise that chip damage will fail.
        abar(dc, x, y, r * 75 / 100, r * 115 / 100, r * 8 / 10, 0x9AA2AA);
        dc.setColor(0x50565C, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((x + _ax * r).toNumber() - 1, (y + _ay * r).toNumber() - 1, 2, 2);
    }

    function _flyer(dc, x, y, r, col) as Void {
        // Wings flap between a wide and a folded pose.
        var up = ((_ph / 2) % 2 == 0);
        var span = (r * 17) / 10;
        var sweep = (r * 7) / 10;
        if (!up) { span = (r * 11) / 10; sweep = (r * 2) / 10; }
        dc.setColor(TdUtil.shade(col, 62), Graphics.COLOR_TRANSPARENT);
        _t3[0][0] = x;                                        _t3[0][1] = y;
        _t3[2][0] = (x - _ax * r).toNumber();                 _t3[2][1] = (y - _ay * r).toNumber();
        _t3[1][0] = (x - _ay * span - _ax * sweep).toNumber();
        _t3[1][1] = (y + _ax * span - _ay * sweep).toNumber();
        dc.fillPolygon(_t3);
        _t3[1][0] = (x + _ay * span - _ax * sweep).toNumber();
        _t3[1][1] = (y - _ax * span - _ay * sweep).toNumber();
        dc.fillPolygon(_t3);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (r * 65) / 100 + 1);
        dc.setColor(0xFFF0C0, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((x + _ax * r * 5 / 10).toNumber() - 1,
                         (y + _ay * r * 5 / 10).toNumber() - 1, 2, 2);
    }

    function _shield(dc, x, y, r, col, hitGlow) as Void {
        _legs(dc, x, y, r, col);
        dc.setColor(TdUtil.shade(col, 60), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (r * 80) / 100);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (r * 58) / 100);
        // Tower shield: a slab across the front plus a bubble that lights up
        // whenever armour just absorbed a hit.
        abar(dc, x, y, r * 6 / 10, r * 105 / 100, r * 105 / 100, 0xD6DCE4);
        abar(dc, x, y, r * 75 / 100, r * 9 / 10, r * 105 / 100, 0x8A929C);
        if (hitGlow > 0) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, r + 2);
        } else {
            dc.setColor(0x5A6470, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, r + 1);
        }
    }

    function _healer(dc, x, y, r, col) as Void {
        var pulse = (_ph / 2) % 8;
        var amp = pulse;
        if (amp > 4) { amp = 8 - pulse; }
        dc.setColor(TdUtil.shade(col, 40), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r + amp);
        dc.setColor(TdUtil.shade(col, 55), Graphics.COLOR_TRANSPARENT);
        _t3[0][0] = x;      _t3[0][1] = y - r - r / 2;
        _t3[1][0] = x - r;  _t3[1][1] = y + r;
        _t3[2][0] = x + r;  _t3[2][1] = y + r;
        dc.fillPolygon(_t3);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (r * 55) / 100 + 1);
        // Cross glyph so the support role is unmistakable.
        dc.setColor(0xEAFFF4, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 1, y - r / 2, 2, r);
        dc.fillRectangle(x - r / 2, y - 1, r, 2);
    }

    function _boss(dc, x, y, r, col, hpPct, ability) as Void {
        var aura = 0x7A1030;
        if (ability == 1)      { aura = 0x2A6AA8; }
        else if (ability == 2) { aura = 0x6A2A9A; }
        else if (ability == 3) { aura = 0x1F7A4A; }
        var beat = (_ph / 3) % 4;
        dc.setColor(aura, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r + beat);
        dc.setColor(TdUtil.shade(col, 55), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, (r * 76) / 100);
        var cw = r / 2;
        if (cw < 2) { cw = 2; }
        dc.setColor(TD_C_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - r, y - r - cw / 2, r * 2, cw / 2 + 1);
        tri(dc, x - r + cw / 2, y - r, 0.0, -1.0, 0.0, cw, cw / 2 + 1, TD_C_GOLD);
        tri(dc, x, y - r, 0.0, -1.0, 0.0, cw * 3 / 2, cw / 2 + 1, TD_C_GOLD);
        tri(dc, x + r - cw / 2, y - r, 0.0, -1.0, 0.0, cw, cw / 2 + 1, TD_C_GOLD);
        // Eyes track the travel direction.
        dc.setColor(0xFFF0A0, Graphics.COLOR_TRANSPARENT);
        var ex = x + _ax * r * 45 / 100;
        var ey = y + _ay * r * 45 / 100;
        var eo = (r * 35) / 100;
        dc.fillRectangle((ex - _ay * eo).toNumber() - 1, (ey + _ax * eo).toNumber() - 1, 3, 3);
        dc.fillRectangle((ex + _ay * eo).toNumber() - 1, (ey - _ax * eo).toNumber() - 1, 3, 3);
        // Dedicated HP bar — the only enemy that gets one.
        var bw = r * 2;
        dc.setColor(0x1A1014, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - bw / 2, y - r - cw * 2, bw, 3);
        dc.setColor(TD_C_DANGER, Graphics.COLOR_TRANSPARENT);
        var fw = (bw * hpPct) / 100;
        if (fw < 1 && hpPct > 0) { fw = 1; }
        dc.fillRectangle(x - bw / 2, y - r - cw * 2, fw, 3);
    }

    // Enemy glyph for the "next wave" preview strip.
    function enemyIcon(dc, t, x, y, s) as Void {
        var col = TdUtil.enemyColor(t);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        if (t == EN_FLYER) {
            dc.fillCircle(x, y, s / 2);
            dc.drawLine(x - s * 3 / 2, y - s / 2, x, y);
            dc.drawLine(x + s * 3 / 2, y - s / 2, x, y);
        } else if (t == EN_TANK) {
            dc.fillRectangle(x - s, y - s / 2, s * 2, s);
        } else if (t == EN_SHIELD) {
            dc.fillCircle(x, y, s / 2);
            dc.setColor(0xD6DCE4, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + s / 2, y - s, 2, s * 2);
        } else if (t == EN_HEALER) {
            dc.fillCircle(x, y, s / 2);
            dc.setColor(0xEAFFF4, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 1, y - s / 2, 2, s);
            dc.fillRectangle(x - s / 2, y - 1, s, 2);
        } else if (t == EN_BOSS) {
            dc.fillCircle(x, y, s);
            dc.setColor(TD_C_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - s, y - s - 2, s * 2, 2);
        } else if (t == EN_RUNNER) {
            dc.fillCircle(x, y, s / 2);
            dc.drawLine(x - s * 3 / 2, y, x - s / 2, y);
        } else {
            dc.fillCircle(x, y, (s * 2) / 3);
        }
    }

    // ── Projectiles ──────────────────────────────────────────────────────────

    function arrow(dc, x, y, dx, dy, u) as Void {
        var l = (u * 3) / 2;
        if (l < 3) { l = 3; }
        quad(dc, x, y, dx, dy, -l, l / 2, 1, 0xE8DCC0);
        tri(dc, x, y, dx, dy, l / 3, l, 2, 0xFFF6D8);
        dc.setColor(0xB8464A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((x - dx * l - dy * 2).toNumber(),
                         (y - dy * l + dx * 2).toNumber(), 2, 2);
        dc.fillRectangle((x - dx * l + dy * 2).toNumber(),
                         (y - dy * l - dx * 2).toNumber(), 2, 2);
    }

    function bullet(dc, x, y, dx, dy, u, col) as Void {
        quad(dc, x, y, dx, dy, -u, u / 2, 1, col);
        dc.setColor(0xFFF6D8, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 1, y - 1, 2, 2);
    }

    // Cannonball with a real lob: the shadow stays on the ground while the ball
    // rides an arc above it, which is the cheapest possible sense of height.
    function shell(dc, x, y, hgt, u) as Void {
        shadow(dc, x, y, u / 2 + 1, TdUtil.shade(TD_C_GRASS, 40));
        dc.setColor(0x2A2A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y - hgt, u / 2 + 2);
        dc.setColor(0x5A5A5A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - 1, y - hgt - 1, u / 3 + 1);
    }

    // ── Effects ──────────────────────────────────────────────────────────────

    // One dispatcher for the whole particle pool. `k` is 0..100 progress
    // through the particle's life, so every effect animates from a single int.
    function fx(dc, kind, x, y, x2, y2, k, col, text) as Void {
        var u = _uu * 2;
        if (kind == TDFX_TEXT) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y - (k * u) / 50, Graphics.FONT_XTINY, text,
                        Graphics.TEXT_JUSTIFY_CENTER);
        } else if (kind == TDFX_SPARK) {
            var sr = 2 - k / 50;
            if (sr < 1) { sr = 1; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, sr);
        } else if (kind == TDFX_RING) {
            dc.setPenWidth(2);
            dc.setColor(TdUtil.mix(col, TD_C_GRASS, k), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, (u * (60 + k * 2)) / 100);
            dc.setPenWidth(1);
        } else if (kind == TDFX_SMOKE) {
            dc.setColor(TdUtil.mix(col, TD_C_GRASS, k), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - (k * u) / 100, u / 3 + k / 40);
        } else if (kind == TDFX_COIN) {
            // Coins pop up and fall back — a parabola from one integer.
            var t = k - 50;
            var lift = (u * (2500 - t * t)) / 4000;
            dc.setColor(0xB88A20, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - lift, 2);
            dc.setColor(TD_C_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y - lift - 1, 1);
        } else if (kind == TDFX_BOLT) {
            _bolt(dc, x, y, x2, y2, col, k);
        } else if (kind == TDFX_TRACER) {
            dc.setPenWidth(2 - k / 60);
            dc.setColor(TdUtil.mix(col, TD_C_GRASS, k), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x, y, x2, y2);
            dc.setPenWidth(1);
        } else if (kind == TDFX_FLAME) {
            _tongue(dc, x, y, x2, y2, k, u);
        } else if (kind == TDFX_MUZZLE) {
            dc.setColor(0xFFF3C0, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, (u * (60 - k / 2)) / 100 + 1);
        } else {
            _boom(dc, x, y, k, u);
        }
    }

    // Jagged four-segment arc between two points. The kink offsets come from
    // the life counter so the bolt visibly crackles across its short life.
    function _bolt(dc, x, y, x2, y2, col, k) as Void {
        var dx = x2 - x;
        var dy = y2 - y;
        var j = 4 + (k % 5);
        var nx = -dy / 8;
        var ny = dx / 8;
        if (nx > j)  { nx = j; }
        if (nx < -j) { nx = -j; }
        if (ny > j)  { ny = j; }
        if (ny < -j) { ny = -j; }
        var ax = x + dx / 4 - nx;
        var ay = y + dy / 4 - ny;
        var bx = x + dx / 2 + nx;
        var by = y + dy / 2 + ny;
        var cx2 = x + (dx * 3) / 4 - nx / 2;
        var cy2 = y + (dy * 3) / 4 - ny / 2;
        dc.setPenWidth(3);
        dc.setColor(TdUtil.shade(col, 55), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y, ax, ay);
        dc.drawLine(ax, ay, bx, by);
        dc.drawLine(bx, by, cx2, cy2);
        dc.drawLine(cx2, cy2, x2, y2);
        dc.setPenWidth(1);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y, ax, ay);
        dc.drawLine(ax, ay, bx, by);
        dc.drawLine(bx, by, cx2, cy2);
        dc.drawLine(cx2, cy2, x2, y2);
    }

    function _tongue(dc, x, y, x2, y2, k, u) as Void {
        var dx = x2 - x;
        var dy = y2 - y;
        for (var i = 1; i <= 3; i++) {
            var px = x + (dx * i) / 3;
            var py = y + (dy * i) / 3;
            var rr = (u * (30 + i * 22)) / 100 + 1;
            var c = 0xFFC24A;
            if (i == 2)      { c = 0xFF8A3A; }
            else if (i == 3) { c = 0xD8452A; }
            if (k > 50) { c = TdUtil.mix(c, TD_C_GRASS, (k - 50) * 2); }
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, rr);
        }
    }

    function _boom(dc, x, y, k, u) as Void {
        dc.setPenWidth(3);
        dc.setColor(TdUtil.mix(0xFF9A3A, TD_C_GRASS, k), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, (u * (50 + k * 3)) / 100 + 1);
        dc.setPenWidth(1);
        if (k < 55) {
            dc.setColor(TdUtil.mix(0xFFF0B0, 0xE85A2A, k * 2), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, (u * (70 - k)) / 100 + 1);
        }
    }

    // ── HUD widgets ──────────────────────────────────────────────────────────

    function panel(dc, x, y, w, h, fill, border) as Void {
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 5);
        dc.setColor(border, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, w, h, 5);
    }

    function bar(dc, x, y, w, h, pct, bg, fg) as Void {
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);
        var f = (w * pct) / 100;
        if (f < 0) { f = 0; }
        if (f > w) { f = w; }
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, f, h);
    }

    function coin(dc, x, y, r) as Void {
        dc.setColor(0xB88A20, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(TD_C_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r - 1);
        dc.setColor(0x8A6410, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 1, y - r / 2, 2, r);
    }

    function heart(dc, x, y, r, col) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - r / 2, y - r / 3, (r * 2) / 3);
        dc.fillCircle(x + r / 2, y - r / 3, (r * 2) / 3);
        _t3[0][0] = x - r;  _t3[0][1] = y - r / 4;
        _t3[1][0] = x + r;  _t3[1][1] = y - r / 4;
        _t3[2][0] = x;      _t3[2][1] = y + r;
        dc.fillPolygon(_t3);
    }

    // Radial cooldown wedge on an ability button.
    function cdSweep(dc, x, y, r, pct, col) as Void {
        if (pct <= 0) { return; }
        var deg = (360 * pct) / 100;
        if (deg > 359) { deg = 359; }
        dc.setPenWidth(3);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(x, y, r, Graphics.ARC_CLOCKWISE, 90, 90 - deg);
        dc.setPenWidth(1);
    }
}
