// ═══════════════════════════════════════════════════════════════════════════
// ZsArt.mc — All artwork for Zombie Survival: Last Stand.
//
// Everything is drawn from primitives so it scales from 208 px Vivoactive
// screens to 454 px Epix without a single bitmap. The scene is a three-lane
// perspective street: burning skyline and blood moon in the back, lanes of
// asphalt in the middle, a plank barricade at the front and the survivor on
// the left. Zombies are built from a shared humanoid skeleton with per-type
// proportions, so a Brute and a Runner read differently at a glance even at
// 30 px tall.
//
// Draw order is strictly back-to-front: sky → skyline → ground → for each lane
// (far → near) zombies then that lane's barricade → survivor → particles → HUD.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Lang;

module ZsArt {

    // ── Geometry ────────────────────────────────────────────────────────────
    // Lane ground lines and sprite scales, as percentages of screen height.
    function laneYs(h) {
        return [h * 85 / 100, h * 71 / 100, h * 60 / 100];
    }
    function laneScales() {
        return [100, 76, 57];
    }
    function wallXs(w) {
        return [w * 30 / 100, w * 36 / 100, w * 42 / 100];
    }
    function spawnXs(w) {
        return [w * 118 / 100, w * 106 / 100, w * 98 / 100];
    }
    function horizonY(h) { return h * 48 / 100; }
    function playerX(w)  { return w * 12 / 100; }

    // Base zombie height in pixels for a lane.
    function zHeight(h, scale, type) {
        var base = h * 17 / 100;
        return base * scale / 100 * Zs.zHeightPct(type) / 100;
    }

    function _rect(dc, x, y, w, h) {
        if (w < 1) { w = 1; }
        if (h < 1) { h = 1; }
        dc.fillRectangle(x, y, w, h);
    }
    function _col(dc, c) { dc.setColor(c, Graphics.COLOR_TRANSPARENT); }

    function _mix(a, b, t) {
        var ra = (a >> 16) & 0xFF; var ga = (a >> 8) & 0xFF; var ba = a & 0xFF;
        var rb = (b >> 16) & 0xFF; var gb = (b >> 8) & 0xFF; var bb = b & 0xFF;
        var r = (ra * (100 - t) + rb * t) / 100;
        var g = (ga * (100 - t) + gb * t) / 100;
        var bl = (ba * (100 - t) + bb * t) / 100;
        return (r << 16) | (g << 8) | bl;
    }

    // Cheap deterministic hash for scenery placement.
    function _h(n) {
        var x = (n * 1103515245 + 12345) & 0x7FFFFFFF;
        return (x >> 9) & 0xFFFF;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Background
    // ═══════════════════════════════════════════════════════════════════════
    // Sky ramps are explicit palette entries rather than interpolations: the
    // device would quantise a gradient into these five steps anyway, and
    // choosing them by hand keeps the hue under control.
    // [night, outer glow, mid glow, core]. Horizontal bands read as scanlines
    // on a 64-colour panel, so the light is painted as radial pools instead
    // and these are the three steps each pool ramps through.
    function skyRamp(mod) {
        if (mod == Zs.MOD_BLOOD) {
            return [0x000000, 0x550000, 0xAA0000, 0xFF5500];
        }
        if (mod == Zs.MOD_FOG) {
            return [0x000000, 0x000055, 0x005555, 0x555555];
        }
        return [0x000000, 0x550000, 0xAA5500, 0xFFAA00];
    }

    function drawSky(dc, w, h, mod, t, flash, detail) {
        var hz = horizonY(h);
        var ramp = skyRamp(mod);
        _col(dc, flash > 0 ? 0x555555 : ramp[0]);
        _rect(dc, 0, 0, w, hz + 1);
        if (detail && flash == 0) { _stars(dc, w, hz, t); }

        // Two districts still burning: a wide pool over the left of the
        // street, a tighter one behind the far end.
        var pulse = ((t / 9) % 3);
        _glow(dc, w * 30 / 100, hz, w * 92 / 100, h * (11 + pulse) / 100, ramp);
        _glow(dc, w * 94 / 100, hz, w * 30 / 100, h * (8 - pulse) / 100, ramp);

        _drawMoon(dc, w, h, mod, t);
        _drawSkyline(dc, w, h, detail);
    }

    function _glow(dc, cx, cy, rx, ry, ramp) {
        _col(dc, ramp[1]);
        dc.fillEllipse(cx, cy, rx, ry);
        _col(dc, ramp[2]);
        dc.fillEllipse(cx, cy, rx * 62 / 100, ry * 66 / 100);
        _col(dc, ramp[3]);
        dc.fillEllipse(cx, cy, rx * 26 / 100, ry * 30 / 100);
    }

    function _stars(dc, w, hz, t) {
        for (var i = 0; i < 16; i++) {
            var sx = _h(i * 37 + 11) % w;
            var sy = _h(i * 53 + 7) % (hz * 58 / 100);
            var tw = ((t / 7) + i) % 9;
            _col(dc, (tw == 0) ? 0xFFFFFF : ((tw < 4) ? 0xAAAAAA : 0x555555));
            _rect(dc, sx, sy, 1, 1);
        }
    }

    // A pale bone-white disc — the only cold light in the scene. Blood nights
    // swap it for a red one and the sky ramp follows.
    function _drawMoon(dc, w, h, mod, t) {
        var mx = w * 74 / 100;
        var my = h * 16 / 100;
        var r  = h * 6 / 100;
        var blood = (mod == Zs.MOD_BLOOD);
        _col(dc, blood ? 0x550000 : 0x555555);
        dc.fillCircle(mx, my, r * 118 / 100);
        _col(dc, blood ? 0xAA0000 : 0xAAAAAA);
        dc.fillCircle(mx, my, r);
        _col(dc, blood ? 0xFF0000 : 0xFFFFFF);
        dc.fillCircle(mx - r / 5, my - r / 5, r * 62 / 100);
        _col(dc, blood ? 0xAA0000 : 0xAAAAAA);
        dc.fillCircle(mx - r / 3, my - r / 4, r / 6);
        dc.fillCircle(mx - r / 12, my + r / 5, r / 9 + 1);
        // Cloud shreds cutting across the disc.
        var cx = ((t / 6) % (w + 260)) - 130;
        _col(dc, 0x000000);
        _rect(dc, cx, my - r / 3, r * 5 / 2, r * 2 / 5 + 1);
        _rect(dc, cx + r, my + r / 3, r * 2, r / 3 + 1);
    }

    function _drawSkyline(dc, w, h, detail) {
        var hz = horizonY(h);

        // Far ridge: warm shadow, low enough that the ember band still shows
        // above the roofline instead of being papered over.
        _col(dc, 0x550000);
        var x = -6;
        var i = 0;
        while (x < w) {
            var bw = 13 + (_h(i * 3 + 1) % 22);
            var bh = h * 2 / 100 + (_h(i * 7 + 5) % (h * 7 / 100));
            _rect(dc, x, hz - bh, bw, bh + 2);
            x += bw + 4;
            i += 1;
        }

        // Near ridge: pure black cut-outs, ember rim on the roofline, a few
        // rooms still lit.
        x = -12; i = 0;
        while (x < w) {
            var bw2 = 17 + (_h(i * 11 + 3) % 28);
            var bh2 = h * 4 / 100 + (_h(i * 13 + 9) % (h * 11 / 100));
            var by = hz - bh2;
            _col(dc, 0x000000);
            _rect(dc, x, by, bw2, bh2 + 2);
            _col(dc, 0x550000);
            _rect(dc, x, by, bw2, 1);
            if (detail && bw2 > 22 && bh2 > 16) {
                for (var k = 0; k < 3; k++) {
                    if ((_h(i * 29 + k * 7) % 100) < 58) { continue; }
                    var wx = x + 4 + k * (bw2 - 8) / 3;
                    var wy = by + 5 + (_h(i * 19 + k * 3) % (bh2 - 10));
                    _col(dc, ((_h(i * 23 + k) % 100) < 26) ? 0xFFAA00 : 0xAA5500);
                    _rect(dc, wx, wy, 2, 2);
                }
            }
            x += bw2 + 6;
            i += 1;
        }
    }

    // The street is a black stage. Only the ember line at the vanishing point,
    // the lane curbs and the scrolling centre dashes are lit, so every sprite
    // reads as a silhouette against it.
    // Dither steps for the asphalt ramp: one row painted in every Nth, so the
    // ember light dies out under the camera without any alpha blending.
    function drawGround(dc, w, h, ys, t, detail) {
        var hz = horizonY(h);
        var span = h - hz;
        _col(dc, 0x000000);
        _rect(dc, 0, hz, w, span);

        // The far end of the street still catches the fires; the light dies
        // out through a dithered ramp before it reaches the camera. Only the
        // strip nearest the vanishing point is solid — filling the whole band
        // turns the upper half of the screen into a flat red carpet and every
        // silhouette in front of it stops reading.
        _col(dc, 0xAA5500);
        _rect(dc, 0, hz, w, 2);
        _col(dc, 0x550000);
        _rect(dc, 0, hz + 2, w, (ys[2] - hz) * 42 / 100);
        var yy = ys[2];
        var step = 3;
        while (yy < ys[1]) {
            dc.drawLine(0, yy, w, yy);
            yy += step;
            step += 3;
        }

        // A few puddles catching the moon.
        if (detail) {
            for (var p = 0; p < 5; p++) {
                var px = _h(p * 71 + 3) % w;
                var py = hz + h * 8 / 100 + (_h(p * 97 + 13) % (h * 38 / 100));
                var pw2 = 6 + (_h(p * 41) % 18);
                _col(dc, 0x000055);
                _rect(dc, px, py, pw2, 2);
                _col(dc, 0x555555);
                _rect(dc, px + pw2 / 3, py, pw2 / 3, 1);
            }
        }

        for (var l = Zs.LANES - 1; l >= 0; l--) {
            var ly = ys[l];
            if (detail) {
                _col(dc, (l == 0) ? 0xAAAA55 : (l == 1 ? 0x555500 : 0x555500));
                var dw = 16 - l * 5;
                var gap = 26 - l * 6;
                var off = (t / 5) % (dw + gap);
                var dx = w * 42 / 100 - off;
                var dh = 3 - l;
                var dy = ly - (l == 0 ? h * 6 / 100 : h * 4 / 100);
                while (dx < w) {
                    _rect(dc, dx, dy, dw, dh);
                    dx += dw + gap;
                }
            }
            _col(dc, (l == 0) ? 0xAAAAAA : 0x555555);
            _rect(dc, 0, ly, w, (l == 0) ? 2 : 1);
            _col(dc, 0x000000);
            _rect(dc, 0, ly + ((l == 0) ? 2 : 1), w, 1);
        }
        if (detail) { _drawDebris(dc, w, h, ys); }
    }

    function _drawDebris(dc, w, h, ys) {
        for (var l = 0; l < Zs.LANES; l++) {
            var y = ys[l];
            var s = 4 - l;
            for (var i = 0; i < 3; i++) {
                var x = w * 50 / 100 + (_h(i * 31 + l * 7) % (w / 2));
                _col(dc, (i & 1) == 0 ? 0x555555 : 0x550000);
                _rect(dc, x, y - 2 - (i % 2), 4 + s, 2);
            }
        }
        // A burnt-out car hulk parked at the end of the far lane.
        var cy = ys[2];
        var cx = w * 86 / 100;
        var cw = w * 14 / 100;
        var ch = h * 5 / 100;
        _col(dc, 0x000000);
        _rect(dc, cx - cw / 2, cy - ch, cw, ch);
        _rect(dc, cx - cw / 3, cy - ch - ch / 2, cw * 2 / 3, ch / 2);
        _col(dc, 0x555555);
        _rect(dc, cx - cw / 2, cy - ch, cw, 1);
        _rect(dc, cx - cw / 3, cy - ch - ch / 2, cw * 2 / 3, 1);
        _col(dc, 0x550000);
        _rect(dc, cx - cw / 4, cy - ch - ch / 2, cw / 6, ch / 2);
    }

    function drawWeather(dc, w, h, mod, t, detail) {
        if (!detail) { return; }
        // Rain: sparse diagonal streaks, denser on fog nights.
        var n = (mod == Zs.MOD_FOG) ? 16 : 11;
        _col(dc, 0x5555AA);
        for (var i = 0; i < n; i++) {
            var sx = (_h(i * 41) % w);
            var sy = ((_h(i * 53) % h) + t * (5 + i % 4)) % h;
            dc.drawLine(sx, sy, sx - 3, sy + 9);
        }
        // Embers drifting up from the fires.
        _col(dc, Zs.FIRE);
        for (var e = 0; e < 5; e++) {
            var ex = (_h(e * 61) % w);
            var ey = h - ((_h(e * 71) % h) + t * 2) % h;
            _rect(dc, ex, ey, 2, 2);
        }
    }

    // Dithered fog band — Monkey C has no alpha, so scanlines fake the haze.
    function drawFog(dc, w, h, ys, t) {
        _col(dc, 0x555555);
        var top = horizonY(h);
        var y = top;
        while (y < h * 86 / 100) {
            if (((y + t / 4) % 6) < 1) { dc.drawLine(0, y, w, y); }
            y += 2;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Barricade
    // ═══════════════════════════════════════════════════════════════════════
    // A palisade of upright planks with a jagged top line, cross-braced and
    // sandbagged, with a sheet of corrugated steel nailed over one end. Damage
    // eats the planks from the outside in and widens the gaps, so a wall about
    // to fall is legible from across the screen.
    function drawBarricade(dc, w, h, lane, x, y, scale, pct, breached, t) {
        var hgt = h * 11 / 100 * scale / 100;
        var wide = h * 15 / 100 * scale / 100;
        if (hgt < 9) { hgt = 9; }
        if (wide < 12) { wide = 12; }
        var u = hgt / 9;
        if (u < 1) { u = 1; }
        var x0 = x - wide / 2;
        var top = y - hgt;

        if (breached) {
            _col(dc, 0x550000);
            _rect(dc, x0, y - u * 3, u * 2, u * 3);
            _rect(dc, x0 + wide - u * 2, y - u * 4, u * 2, u * 4);
            _rect(dc, x0 + wide / 2, y - u * 2, u, u * 2);
            _col(dc, ((t / 4) % 2) == 0 ? Zs.DANGER : 0x550000);
            _rect(dc, x0 - u, y - 2, wide + u * 2, 2);
            _col(dc, Zs.BLOOD);
            _rect(dc, x0 + u, y - u / 2, wide - u * 2, u / 2 + 1);
            return;
        }

        var dmg = 100 - pct;
        var pn = 7;
        var pw = wide / pn;
        if (pw < 2) { pw = 2; pn = wide / pw; }

        // Upright planks. Wear is highest at the edges so the wall collapses
        // inward, leaving a shrinking core.
        for (var i = 0; i < pn; i++) {
            var mid = pn / 2;
            var d = (i < mid) ? (mid - i) : (i - mid);
            if (dmg > 100 - d * 26) { continue; }
            var px = x0 + i * pw;
            var jag = _h(i * 13 + lane * 31) % (u * 2 + 1);
            var py = top + jag;
            var ph = y - py;
            _col(dc, ((i & 1) == 0) ? Zs.WOOD : 0x550000);
            _rect(dc, px, py, pw - 1, ph);
            _col(dc, 0xFFAA55);
            _rect(dc, px, py, pw - 1, 1);
            if (u >= 2) {
                _col(dc, 0x000000);
                _rect(dc, px + pw - 2, py + 1, 1, ph - 1);
            }
        }

        // Cross-braces holding it together.
        _col(dc, 0x550000);
        _rect(dc, x0, top + hgt * 34 / 100, wide, u);
        _rect(dc, x0, top + hgt * 68 / 100, wide, u);
        _col(dc, Zs.WOOD);
        _rect(dc, x0, top + hgt * 34 / 100, wide, 1);
        _rect(dc, x0, top + hgt * 68 / 100, wide, 1);

        // Corrugated steel sheet bolted over the far end.
        if (dmg < 74) {
            var sx = x0 + wide * 62 / 100;
            var sw = wide * 34 / 100;
            _col(dc, Zs.STEEL_D);
            _rect(dc, sx, top + u, sw, hgt - u * 2);
            _col(dc, Zs.STEEL);
            var rx = sx;
            while (rx < sx + sw) {
                _rect(dc, rx, top + u, 1, hgt - u * 2);
                rx += (u > 1) ? u + 1 : 2;
            }
            _col(dc, 0x000000);
            _rect(dc, sx, top + u, sw, 1);
        }

        // Sandbag footing.
        var bagW = wide / 3;
        if (bagW < 4) { bagW = 4; }
        for (var b = 0; b * bagW < wide + bagW; b++) {
            var bx = x0 - u + b * bagW;
            _col(dc, 0x550000);
            dc.fillEllipse(bx + bagW / 2, y - u, bagW * 55 / 100, u);
            _col(dc, Zs.WOOD);
            dc.fillEllipse(bx + bagW / 2, y - u - u / 3, bagW * 42 / 100, u * 50 / 100);
        }

        // Razor wire crowning the wall — only when there are pixels for it.
        if (u >= 3) {
            _col(dc, 0xAAAAAA);
            var wy = top - u / 2;
            for (var k = 0; k < 4; k++) {
                var kx = x0 + k * wide / 4;
                dc.drawLine(kx, wy + u / 2, kx + wide / 8, wy - u / 2);
                dc.drawLine(kx + wide / 8, wy - u / 2, kx + wide / 4, wy + u / 2);
            }
        }

        // Blood and claw marks once it has been chewed on.
        if (dmg > 40) {
            _col(dc, Zs.BLOOD);
            _rect(dc, x0 + wide / 5, top + hgt / 2, u * 2, u);
            _rect(dc, x0 + wide * 3 / 5, top + hgt / 3, u, u * 2);
        }
        if (dmg > 70) {
            _col(dc, Zs.BLOOD2);
            _rect(dc, x0 + wide / 3, top + hgt * 55 / 100, u, u * 3);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Zombies
    // ═══════════════════════════════════════════════════════════════════════
    // A shared humanoid skeleton with per-type proportions. All types walk
    // leftward, so limbs lead to the left of the body.
    function drawZombie(dc, type, x, gy, hgt, anim, flash, burning) {
        if (hgt < 8) { hgt = 8; }
        var u = hgt / 9;
        if (u < 1) { u = 1; }

        var body  = Zs.zColor(type);
        var dark  = Zs.zDark(type);
        var cloth = Zs.zCloth(type);
        var rim   = Zs.zRim(type);
        if (flash > 0) { body = 0xFFFFFF; dark = 0xFFAAAA; cloth = 0xFFFFFF; rim = 0xFFFFFF; }
        else if (burning > 0) {
            body = _mix(body, Zs.FIRE, 45);
            dark = _mix(dark, 0xAA0000, 55);
            rim  = 0xFFAA00;
        }

        var ph = (anim / 3) % 4;
        var stride = (ph == 0) ? 0 : (ph == 1 ? 1 : (ph == 2 ? 0 : -1));
        var bob = (ph == 1 || ph == 3) ? -u / 3 : 0;

        // Ground shadow anchors the sprite to the asphalt.
        _col(dc, 0x000000);
        dc.fillEllipse(x, gy + 1, hgt * 26 / 100, u * 2 / 3 + 1);

        if (type == Zs.Z_CRAWLER) {
            _crawler(dc, x, gy, u, body, dark, cloth, ph, type);
        } else if (type == Zs.Z_BOSS) {
            // The Abomination is built on a finer grid than the rest so its
            // bulk reads as a hunched mass rather than one green slab.
            var bu = hgt / 15;
            if (bu < 1) { bu = 1; }
            _boss(dc, x, gy, bu, body, dark, cloth, ph, anim, rim);
        } else {
            _humanoid(dc, type, x, gy + bob, u, body, dark, cloth, stride, anim, rim);
        }

        if (burning > 0) { _flames(dc, x, gy, hgt, anim); }
    }

    function _humanoid(dc, type, x, gy, u, body, dark, cloth, stride, anim, rim) {
        var lean = 0;
        var shoulder = u * 3;
        var headR = u;
        var armLen = u * 3;
        if (type == Zs.Z_RUNNER)   { lean = u; shoulder = u * 5 / 2; armLen = u * 3; }
        if (type == Zs.Z_BRUTE)    { shoulder = u * 9 / 2; headR = u * 3 / 4; armLen = u * 4; }
        if (type == Zs.Z_SPITTER)  { shoulder = u * 7 / 2; }
        if (type == Zs.Z_SCREAMER) { shoulder = u * 5 / 2; }

        var hipY = gy - u * 3;
        var chestY = hipY - u * 3;
        var headY = chestY - u * 2;

        // Legs — one plants, one drags.
        _col(dc, dark);
        _rect(dc, x - u + stride * u / 2, hipY, u, u * 3);
        _rect(dc, x + stride * u / 2 - u / 2, hipY, u, u * 3 - (stride > 0 ? u / 2 : 0));
        _col(dc, cloth);
        _rect(dc, x - u - lean / 2, hipY - u / 2, u * 2 + u / 2, u * 3 / 2);

        // Torso: ragged shirt over rotting flesh.
        _col(dc, cloth);
        _rect(dc, x - shoulder / 2 - lean, chestY, shoulder, u * 3);
        _col(dc, body);
        _rect(dc, x - shoulder / 2 - lean, chestY, shoulder, u);
        if (type == Zs.Z_SPITTER) {
            _col(dc, 0xAAFF00);
            dc.fillEllipse(x - lean, chestY + u * 2, shoulder / 2, u * 3 / 2);
        }
        if (type == Zs.Z_BRUTE) {
            // Exposed ribs.
            _col(dc, 0xFFFFAA);
            _rect(dc, x - shoulder / 4 - lean, chestY + u, shoulder / 2, u / 2);
            _rect(dc, x - shoulder / 4 - lean, chestY + u * 2, shoulder / 2, u / 2);
        }

        // Arms reaching forward (left), swaying with the stride.
        var armY = chestY + u - stride * u / 3;
        _col(dc, body);
        _rect(dc, x - shoulder / 2 - armLen - lean, armY, armLen, u);
        _rect(dc, x - shoulder / 2 - armLen * 3 / 4 - lean, armY + u + u / 2, armLen * 3 / 4, u);
        _col(dc, dark);
        _rect(dc, x - shoulder / 2 - armLen - lean - u / 2, armY, u / 2 + 1, u);

        // Head + jaw.
        var hx = x - lean - u / 2;
        _col(dc, body);
        dc.fillCircle(hx, headY, headR + u / 4);
        _col(dc, dark);
        _rect(dc, hx - headR, headY + headR / 2, headR * 2, u / 2 + 1);
        if (type == Zs.Z_SCREAMER) {
            // Jaw hanging wide open.
            _col(dc, 0x000000);
            dc.fillEllipse(hx - headR / 2, headY + headR, headR * 3 / 4, headR);
        }
        // Glowing eye.
        _col(dc, Zs.zEye(type));
        _rect(dc, hx - headR + (u > 3 ? 1 : 0), headY - u / 4, u / 2 + 1, u / 2 + 1);
        if (u >= 4) { _rect(dc, hx - headR / 4, headY - u / 4, u / 3 + 1, u / 3 + 1); }

        // Hair / gore on top for the bigger sprites.
        if (u >= 3) {
            _col(dc, dark);
            _rect(dc, hx - headR, headY - headR - u / 3, headR * 2, u / 2);
        }

        // Moon-side rim: a single lit column down the trailing edge lifts the
        // whole sprite off the black asphalt.
        var rx = x + shoulder / 2 - lean - 1;
        _col(dc, rim);
        _rect(dc, rx, chestY, 1, u * 3);
        _rect(dc, hx + headR - 1, headY - headR / 2, 1, headR + u / 2);
        _rect(dc, x + stride * u / 2 + u / 2 - 1, hipY, 1, u * 3);
    }

    function _crawler(dc, x, gy, u, body, dark, cloth, ph, type) {
        var y = gy - u * 2;
        var drag = (ph == 1 || ph == 2) ? u / 2 : 0;
        _col(dc, cloth);
        _rect(dc, x - u, y, u * 3, u * 3 / 2);
        _col(dc, body);
        _rect(dc, x - u * 2, y - u / 2, u * 2, u * 3 / 2);
        dc.fillCircle(x - u * 5 / 2 - drag, y, u);
        // Trailing legs.
        _col(dc, dark);
        _rect(dc, x + u * 2, y + u / 2, u * 2, u / 2 + 1);
        _rect(dc, x + u * 2, y + u, u * 5 / 2, u / 2);
        // Clawing arm.
        _rect(dc, x - u * 4 - drag, y + u / 2, u * 2, u / 2 + 1);
        _col(dc, Zs.zEye(type));
        _rect(dc, x - u * 3 - drag, y - u / 3, u / 2 + 1, u / 2 + 1);
    }

    // A hunched, top-heavy mass: short bowed legs, a barrel ribcage tapering
    // into shoulders that sit higher than the head, and one overgrown arm
    // dragging along the asphalt.
    function _boss(dc, x, gy, u, body, dark, cloth, ph, anim, rim) {
        var stride = (ph == 0 || ph == 2) ? 0 : ((ph == 1) ? 1 : -1);
        var hipY    = gy - u * 5;
        var chestY  = hipY - u * 6;
        var headY   = chestY + u * 2;      // head sunk between the shoulders
        var hipW    = u * 5;
        var shoulder = u * 8;

        // Bowed legs.
        _col(dc, dark);
        _rect(dc, x - hipW / 2 - u + stride * u / 2, hipY, u * 2, u * 5);
        _rect(dc, x + hipW / 2 - u - stride * u / 2, hipY, u * 2, u * 5);
        _col(dc, cloth);
        _rect(dc, x - hipW / 2 - u, gy - u, u * 2, u);
        _rect(dc, x + hipW / 2 - u, gy - u, u * 2, u);

        // Ribcage: widest at the shoulders, pinched at the waist.
        _col(dc, body);
        _rect(dc, x - hipW / 2, hipY - u, hipW, u * 2);
        _rect(dc, x - shoulder / 2, chestY, shoulder, u * 5);
        _col(dc, dark);
        _rect(dc, x - shoulder / 2, chestY + u * 4, shoulder, u);
        // Ribs showing through split skin.
        _col(dc, 0xFFFFAA);
        for (var i = 0; i < 3; i++) {
            _rect(dc, x - shoulder / 4, chestY + u + i * u * 3 / 2,
                  shoulder / 2, u / 2 + 1);
        }
        // Scrap armour bolted over the shoulders.
        _col(dc, Zs.STEEL_D);
        _rect(dc, x - shoulder / 2 - u / 2, chestY - u / 2, u * 3, u * 2);
        _rect(dc, x + shoulder / 2 - u * 5 / 2, chestY - u / 2, u * 3, u * 2);
        _col(dc, Zs.STEEL);
        _rect(dc, x - shoulder / 2 - u / 2, chestY - u / 2, u * 3, 1);
        _rect(dc, x + shoulder / 2 - u * 5 / 2, chestY - u / 2, u * 3, 1);

        // Furnace in the chest cavity.
        var pulse = ((anim / 4) % 2) == 0;
        _col(dc, pulse ? Zs.FIRE : 0x550000);
        dc.fillCircle(x, chestY + u * 5 / 2, u * 3 / 2);
        _col(dc, pulse ? 0xFFFF55 : Zs.FIRE);
        dc.fillCircle(x, chestY + u * 5 / 2, u * 3 / 4);

        // The big arm, hanging past the knee; the far one is a stump.
        _col(dc, body);
        _rect(dc, x - shoulder / 2 - u * 3, chestY + u, u * 3, u * 2);
        _rect(dc, x - shoulder / 2 - u * 4, chestY + u * 2, u * 2, u * 5);
        _col(dc, dark);
        _rect(dc, x - shoulder / 2 - u * 5, chestY + u * 6, u * 3, u * 2);
        _rect(dc, x + shoulder / 2 - u, chestY + u, u * 2, u * 3);

        // Sunken head with a split jaw.
        _col(dc, dark);
        dc.fillCircle(x - u, headY, u * 2);
        _col(dc, 0x000000);
        _rect(dc, x - u * 2, headY + u, u * 2, u);
        _col(dc, Zs.zEye(Zs.Z_BOSS));
        _rect(dc, x - u * 2, headY - u / 2, u, u);
        _rect(dc, x - u / 2, headY - u / 2, u, u);

        _col(dc, rim);
        _rect(dc, x + shoulder / 2 - 1, chestY, 1, u * 5);
        _rect(dc, x + hipW / 2 - 1, hipY, 1, u * 5);
    }

    function _flames(dc, x, gy, hgt, anim) {
        var f = (anim / 2) % 3;
        _col(dc, Zs.FIRE);
        _rect(dc, x - hgt / 6, gy - hgt - hgt / 8, hgt / 8, hgt / 5 + f);
        _rect(dc, x + hgt / 8, gy - hgt * 3 / 4, hgt / 10, hgt / 6 + f);
        _col(dc, Zs.FIRE2);
        _rect(dc, x - hgt / 12, gy - hgt - hgt / 6 - f, hgt / 14 + 1, hgt / 8);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Survivor
    // ═══════════════════════════════════════════════════════════════════════
    // Drawn on the near lane; the rifle elevates toward the targeted lane so
    // the player can always see where the next shot is going.
    function drawSurvivor(dc, x, gy, hgt, lane, recoil, reloading, adren, breathe) {
        var u = hgt / 10;
        if (u < 1) { u = 1; }
        var kick = recoil > 0 ? u / 2 : 0;
        var bob = ((breathe / 8) % 2) == 0 ? 0 : -1;
        var bx = x + kick;
        var gyy = gy + bob;

        _col(dc, 0x000000);
        dc.fillEllipse(x, gy + 1, u * 4, u);

        var hipY = gyy - u * 4;
        var chestY = hipY - u * 3;
        var headY = chestY - u * 2;

        // Boots and legs, braced.
        _col(dc, 0x555555);
        _rect(dc, bx - u * 2, hipY, u * 3 / 2, u * 4);
        _rect(dc, bx + u / 2, hipY, u * 3 / 2, u * 4);
        _col(dc, 0x000000);
        _rect(dc, bx - u * 5 / 2, gyy - u, u * 2, u);
        _rect(dc, bx + u / 2, gyy - u, u * 2, u);

        // Coat.
        _col(dc, adren ? 0xAA0000 : Zs.CLOTH);
        _rect(dc, bx - u * 2, chestY, u * 4, u * 4);
        _col(dc, adren ? 0xFF0055 : 0x55AAAA);
        _rect(dc, bx - u * 2, chestY, u * 4, u);
        // Backpack, slung on the shoulder away from the street.
        _col(dc, 0xAA5500);
        _rect(dc, bx - u * 7 / 2, chestY + u / 2, u * 3 / 2, u * 5 / 2);

        // Head, cap brim pointing downrange.
        _col(dc, Zs.SKIN);
        dc.fillCircle(bx, headY + u, u * 5 / 4);
        _col(dc, 0x005500);
        _rect(dc, bx - u * 3 / 2, headY, u * 3, u);
        _rect(dc, bx + u / 2, headY + u / 2, u * 2, u / 2 + 1);

        // Rifle, aimed downrange and elevated toward the chosen lane. The
        // dead come from the right, so everything the survivor points has to
        // point that way too.
        var aim = (lane == 0) ? 0 : (lane == 1 ? -u : -u * 2);
        var bl = u * 5;
        var by = chestY + u;
        var mx = bx + u + bl;
        var my = by + aim;
        _col(dc, 0x555555);
        dc.setPenWidth(u >= 3 ? 3 : 2);
        dc.drawLine(bx + u, by, mx, my);
        dc.setPenWidth(1);
        _col(dc, 0x000000);
        _rect(dc, bx - u / 2, by - u / 2, u * 2, u);
        // Arms out along the stock.
        _col(dc, adren ? 0xFF0055 : 0x55AAAA);
        _rect(dc, bx + u / 2, by - u / 4, u * 2, u * 3 / 4 + 1);

        if (reloading) {
            // Magazine swap: a bright mag drops away from the receiver.
            _col(dc, Zs.WARN);
            _rect(dc, bx + u / 2, by + u * 2, u, u * 3 / 2);
        }
        return [mx, my];
    }

    function drawMuzzleFlash(dc, mx, my, size, frame) {
        var s = size;
        _col(dc, Zs.FIRE2);
        dc.fillCircle(mx, my, s);
        _col(dc, 0xFFFFFF);
        dc.fillCircle(mx, my, s / 2);
        _col(dc, Zs.FIRE);
        _rect(dc, mx, my - s / 3, s * 2, s * 2 / 3 + 1);
        _rect(dc, mx + s / 2, my - s * 3 / 2, s / 2 + 1, s * 3);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Effects
    // ═══════════════════════════════════════════════════════════════════════
    function drawTracer(dc, x0, y0, x1, y1, life) {
        _col(dc, life > 1 ? 0xFFFFFF : Zs.FIRE2);
        dc.setPenWidth(life > 1 ? 2 : 1);
        dc.drawLine(x0, y0, x1, y1);
        dc.setPenWidth(1);
    }

    function drawParticles(dc, run) {
        for (var i = 0; i < BattleSim.PMAX; i++) {
            if (!run.pAlive[i]) { continue; }
            var x = run.pX[i] / 16;
            var y = run.pY[i] / 16;
            var k = run.pKind[i];
            var c = run.pCol[i];
            if (k == 3 && run.pLife[i] < 6) { c = 0x555555; }
            _col(dc, c);
            var s = (k == 1) ? 3 : 2;
            if (k == 3) { s = 3; }
            _rect(dc, x, y, s, s);
        }
    }

    function drawBurnPool(dc, w, x0, x1, y, t) {
        var n = 7;
        for (var i = 0; i < n; i++) {
            var fx = x0 + (x1 - x0) * i / n;
            var f = ((t / 2) + i) % 3;
            _col(dc, (i & 1) == 0 ? Zs.FIRE : 0xAA5500);
            _rect(dc, fx, y - 4 - f * 2, (x1 - x0) / n - 1, 4 + f * 2);
            _col(dc, Zs.FIRE2);
            _rect(dc, fx + 1, y - 2 - f, 2, 2 + f);
        }
        _col(dc, 0x550000);
        _rect(dc, x0, y - 1, x1 - x0, 2);
    }

    function drawSentry(dc, x, y, u, t) {
        _col(dc, Zs.STEEL_D);
        _rect(dc, x - u, y - u, u * 2, u);
        _col(dc, Zs.STEEL);
        _rect(dc, x - u / 2, y - u * 2, u, u);
        _col(dc, 0x55AAFF);
        _rect(dc, x - u * 2, y - u * 2 + 1, u * 2, u / 2 + 1);
        if (((t / 2) % 2) == 0) {
            _col(dc, 0xFFFFFF);
            _rect(dc, x - u * 3, y - u * 2, u, u / 2 + 1);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Emplacements
    // ═══════════════════════════════════════════════════════════════════════
    // Everything the player has bought, standing on the street where it will
    // actually be used. This is the only place the money goes on show: an idle
    // game where the base looks identical at level 1 and level 40 gives you
    // nothing to feel about the walking you did.

    // World X to screen X for a lane. The simulation owns the same mapping;
    // duplicating four lines of arithmetic here keeps the art module free of
    // any dependency on the engine.
    function roadX(w, wx, lane) {
        var t = wx;
        if (t < 0) { t = 0; }
        if (t > Zs.WX_SPAWN) { t = Zs.WX_SPAWN; }
        var a = wallXs(w)[lane];
        var b = spawnXs(w)[lane];
        return a + (b - a) * t / Zs.WX_SPAWN;
    }

    // Spike pit and razor wire, drawn on the road at the world X they bite at.
    function drawTraps(dc, w, h, spikeLvl, wireLvl) {
        var ys = laneYs(h);
        var sc = laneScales();
        for (var l = 0; l < Zs.LANES; l++) {
            var y = ys[l];
            var u = h * 3 / 100 * sc[l] / 100;
            if (u < 2) { u = 2; }

            if (wireLvl > 0) {
                var wx = roadX(w, Zs.WX_WIRE, l);
                _col(dc, Zs.STEEL_D);
                _rect(dc, wx - u * 2, y - u, u * 4, 1);
                _col(dc, Zs.STEEL);
                for (var b = 0; b < 4; b++) {
                    var bx = wx - u * 2 + u * 4 * b / 4;
                    _rect(dc, bx, y - u - 1, 1, u);
                    _rect(dc, bx - 1, y - u - 1, 3, 1);
                }
            }
            if (spikeLvl > 0) {
                var px = roadX(w, Zs.WX_SPIKES, l);
                _col(dc, 0x550000);
                _rect(dc, px - u * 2, y - 1, u * 4, 2);
                _col(dc, Zs.STEEL);
                for (var s = 0; s < 5; s++) {
                    var tx = px - u * 2 + u * 4 * s / 5;
                    dc.fillPolygon([[tx, y - 1], [tx + u / 2 + 1, y - u],
                                    [tx + u + 1, y - 1]]);
                }
            }
        }
    }

    // Turrets sit just behind the wall, one per lane so each is visibly
    // covering its own approach. They are kept clear of playerX: the survivor
    // stands on the near lane and an emplacement on top of him reads as one
    // unidentifiable pile of pixels at this size.
    // Called from inside the view's back-to-front lane loop so an emplacement
    // is occluded by its own barricade instead of being pasted over the whole
    // scene at the end.
    function drawTurretAt(dc, w, h, lane, lvl, t, firing) {
        var ys = laneYs(h);
        var xs = wallXs(w);
        var sc = laneScales();
        var u = h * 45 / 1000 * sc[lane] / 100;
        if (u < 3) { u = 3; }
        // Far enough behind the wall to stay clear of it, far enough ahead of
        // playerX not to sit on the survivor.
        var x = xs[lane] - u * 7 / 2;
        var y = ys[lane];

        if (lane == 0 && lvl[Zs.D_MG] > 0) {
            _mgNest(dc, x, y, u, t, firing);
        } else if (lane == 1 && lvl[Zs.D_TESLA] > 0) {
            _tesla(dc, x, y, u, t);
        } else if (lane == 2 && lvl[Zs.D_MORTAR] > 0) {
            _mortar(dc, x, y, u, t);
        }
    }

    function _mgNest(dc, x, y, u, t, firing) {
        if (u < 3) { u = 3; }
        _col(dc, 0x555500);                       // sandbags
        _rect(dc, x - u, y - u, u * 2, u);
        _col(dc, 0x005500);
        _rect(dc, x - u, y - u, u * 2, u / 3 + 1);
        _col(dc, Zs.STEEL_D);                     // mount
        _rect(dc, x - u / 3, y - u * 2, u * 2 / 3, u);
        _col(dc, Zs.STEEL);                       // barrel, pointing downrange
        _rect(dc, x, y - u * 2 + 1, u * 2, u / 3 + 1);
        if (firing && ((t / 2) % 2) == 0) {
            _col(dc, Zs.FIRE2);
            _rect(dc, x + u * 2, y - u * 2, u, u / 2 + 1);
        }
    }

    function _tesla(dc, x, y, u, t) {
        if (u < 3) { u = 3; }
        _col(dc, Zs.STEEL_D);
        _rect(dc, x - u / 2, y - u * 2, u, u * 2);
        _col(dc, 0x55AAFF);
        dc.fillCircle(x, y - u * 2 - u / 2, u / 2 + 1);
        // The coil idles with a crackle so it reads as live between shots.
        if (((t / 3) % 3) == 0) {
            _col(dc, 0xAAFFFF);
            _rect(dc, x - u, y - u * 2 - u / 2, u * 2, 1);
            _rect(dc, x, y - u * 3, 1, u);
        }
    }

    function _mortar(dc, x, y, u, t) {
        if (u < 3) { u = 3; }
        _col(dc, 0x555555);                       // baseplate
        _rect(dc, x - u, y - u / 2, u * 2, u / 2 + 1);
        _col(dc, Zs.STEEL_D);                     // tube, canted up
        dc.fillPolygon([[x - u / 2, y - u / 2],
                        [x + u / 3, y - u * 2],
                        [x + u, y - u * 2 + u / 2],
                        [x, y - u / 2]]);
        _col(dc, Zs.FIRE);
        _rect(dc, x + u / 3, y - u * 2, u / 2 + 1, u / 3 + 1);
    }

    // The wall itself, seen from the base screen: a compact elevation the
    // player can read at a glance while shopping.
    function drawBaseCard(dc, cx, y, w, h, pct, lvl, t) {
        var x0 = cx - w / 2;
        _col(dc, 0x000000);
        _rect(dc, x0, y, w, h);
        _col(dc, Zs.STEEL_D);
        _rect(dc, x0, y + h - 2, w, 2);

        // Wall blocks, filled to the current integrity.
        var cols = 9;
        var bw = w / cols;
        var lit = cols * pct / 100;
        for (var i = 0; i < cols; i++) {
            var bx = x0 + i * bw;
            var bh = h * 3 / 5;
            _col(dc, i < lit ? Zs.WOOD : 0x550000);
            _rect(dc, bx + 1, y + h - 2 - bh, bw - 2, bh);
            _col(dc, i < lit ? 0xFFAA55 : 0x000000);
            _rect(dc, bx + 1, y + h - 2 - bh, bw - 2, 1);
        }
        if (lvl[Zs.D_GATE] > 0) {
            _col(dc, Zs.STEEL);
            _rect(dc, cx - bw, y + h - 2 - h * 3 / 5, bw * 2, h * 3 / 5);
            _col(dc, Zs.STEEL_D);
            _rect(dc, cx - 1, y + h - 2 - h * 3 / 5, 2, h * 3 / 5);
        }
        // Whatever is emplaced, as silhouettes along the parapet.
        var u = h / 5;
        if (u < 2) { u = 2; }
        var slot = 0;
        if (lvl[Zs.D_MG] > 0)     { _mgNest(dc, x0 + w / 5, y + h - 2 - h * 3 / 5, u, t, false); slot += 1; }
        if (lvl[Zs.D_TESLA] > 0)  { _tesla(dc, x0 + w / 2, y + h - 2 - h * 3 / 5, u, t); slot += 1; }
        if (lvl[Zs.D_MORTAR] > 0) { _mortar(dc, x0 + w * 4 / 5, y + h - 2 - h * 3 / 5, u, t); slot += 1; }
    }

    function drawAcid(dc, x, y, r) {
        _col(dc, 0xAAFF00);
        dc.fillCircle(x, y, r);
        _col(dc, 0xFFFF55);
        dc.fillCircle(x - r / 3, y - r / 3, r / 2);
    }

    // Red damage vignette, drawn as concentric rings so it costs nothing.
    function drawVignette(dc, w, h, strength) {
        var c = _mix(0x550000, Zs.DANGER, strength * 5);
        _col(dc, c);
        var r = w / 2;
        dc.setPenWidth(3);
        for (var i = 0; i < 4; i++) {
            dc.drawCircle(w / 2, h / 2, r - i * 3);
        }
        dc.setPenWidth(1);
    }
}
