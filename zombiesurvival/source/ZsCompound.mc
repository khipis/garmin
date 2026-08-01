// ═══════════════════════════════════════════════════════════════════════════
// ZsCompound.mc — The yard, by daylight. The screen the game lives on.
//
// Built the same way FARM's diorama is: a strict back-to-front stack of bands,
// a three-lane depth system for everything standing in the yard, chunky pixel
// sprites placed on their own footprint, and a rim highlight on every edge
// that has to separate from the band behind it. The difference is the light —
// this compound never gets a nice day.
//
// Everything on screen is a readout. The wall's material, height and joint
// spacing are D_WALL. The gate panel is D_GATE, the coils are D_WIRE, the
// towers are their own tracks, the heap is D_SALVAGE, the shed is D_REPAIR,
// and every prop in the yard is an item on the salvage shelf. Nothing is here
// for decoration alone, so the picture is worth reading before you spend.
//
// Draw order:
//   sky → light → smoke → far skyline → near skyline → crows → treeline
//   → wasteland → spikes → wall → towers → yard floor
//   → lane 2 → lane 1 → lane 0 → fire → foreground
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Lang;

module ZsCompound {

    // ── The light ───────────────────────────────────────────────────────────
    // Four states, driven by how long is left before the wave. DUSK is the
    // shortest and the loudest: the last hours before a night should not look
    // like the rest of the day.
    const L_DAY   = 0;
    const L_AFT   = 1;
    const L_DUSK  = 2;
    const L_NIGHT = 3;

    function lightOf(secs) {
        if (secs > 6 * 3600) { return L_DAY; }
        if (secs > 2 * 3600) { return L_AFT; }
        if (secs > 20 * 60)  { return L_DUSK; }
        return L_NIGHT;
    }

    // ── Depth ───────────────────────────────────────────────────────────────
    // Three lanes inside the wall, back to front, exactly as FARM lays out its
    // fields: a base line, a sprite scale and how far off centre a lane is
    // allowed to spread. Lane 0 is nearest the player.
    const LN_N = 3;
    function laneY(l)      { var a = [86, 76, 66];  return a[_c(l, 0, LN_N - 1)]; }
    function laneScale(l)  { var a = [110, 88, 70]; return a[_c(l, 0, LN_N - 1)]; }
    function laneSpread(l) { var a = [78, 92, 98];  return a[_c(l, 0, LN_N - 1)]; }

    function _c(i, lo, hi) { if (i < lo) { return lo; } if (i > hi) { return hi; } return i; }

    // ── Geometry ────────────────────────────────────────────────────────────
    // Percentages of the scene box. The wall crest floats with D_WALL so a
    // fifteenth level plainly stands taller than a first.
    function horizonY(h) { return h * 30 / 100; }
    function crestY(h)   { return h * 41 / 100; }
    function baseY(h)    { return h * 58 / 100; }
    // The wall's crest floats with its level, so a fifteenth wall plainly
    // stands taller than a first. Towers hang off this too.
    function wallTop(y, h, wl) {
        var top = y + crestY(h) - wl * h / 260;
        if (top < y + horizonY(h) + 5) { top = y + horizonY(h) + 5; }
        return top;
    }

    // Screen-space helpers used by callers that only know width and height.
    function screenBaseY(h) { return h * 25 / 1000 + (h - h * 50 / 1000) * 58 / 100; }

    function _rect(dc, x, y, w, h, c) {
        if (w < 1) { w = 1; }
        if (h < 1) { h = 1; }
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);
    }
    function _col(dc, c) { dc.setColor(c, Graphics.COLOR_TRANSPARENT); }
    // Deterministic scatter. Rubble that moves between frames reads as noise,
    // so every scattered thing on this screen is hashed off its own index.
    function _hash(n) {
        var x = (n * 1103515245 + 12345) & 0x7FFFFFFF;
        return (x >> 9) & 0xFFFF;
    }

    // ── Shading, on the panel's own colour cube ─────────────────────────────
    // The display quantises every channel to 00/55/AA/FF, so a blend of two
    // colours does not land where it was aimed: darkening a brown by a third
    // rounds the blue channel to zero and the "shadow" comes back olive. That
    // is exactly what went wrong the first time this scene was drawn.
    //
    // So nothing here blends. Shading moves each channel a whole step along
    // the cube instead, which means every colour on screen is a colour the
    // panel can actually show and a shadow is always the same hue as its body.
    function _step(v, d) {
        var i = 0;
        if (v >= 0xD5)      { i = 3; }
        else if (v >= 0x80) { i = 2; }
        else if (v >= 0x2B) { i = 1; }
        i += d;
        if (i < 0) { i = 0; }
        if (i > 3) { i = 3; }
        var a = [0x00, 0x55, 0xAA, 0xFF];
        return a[i];
    }
    function _shift(c, d) {
        return (_step((c >> 16) & 0xFF, d) << 16)
             | (_step((c >> 8) & 0xFF, d) << 8)
             | _step(c & 0xFF, d);
    }
    // A body colour for the hour: after dark everything drops one step.
    function _lit(c, light) { return light == L_NIGHT ? _shift(c, -1) : c; }
    // Rim light. The edge of a thing, one step above its body, is what stops
    // the yard reading as a heap of flat rectangles.
    function _rim(c, light) { return _shift(_lit(c, light), 1); }
    function _dark(c, light) { return _shift(_lit(c, light), -1); }

    // ═══════════════════════════════════════════════════════════════════════
    // Entry points
    // ═══════════════════════════════════════════════════════════════════════
    function draw(dc, w, h, m, t, detail) {
        dc.setColor(0x000000, 0x000000);
        dc.clear();
        var mx = w * 25 / 1000;
        var my = h * 25 / 1000;
        drawBox(dc, mx, my, w - mx * 2, h - my * 2, m, t, detail, false);
    }

    // The whole scene in an arbitrary box, so the menu preview and the hero
    // shot can reuse it at a fraction of the size.
    function drawBox(dc, x, y, w, h, m, t, detail, mini) {
        var light = lightOf(m.secsToWave());
        var lvl = m.dLevel;
        var p = w / 32;
        if (p < 2) { p = 2; }
        var cx = x + w / 2;

        _sky(dc, x, y, w, h, light, t, detail && !mini);
        _light(dc, x, y, w, h, light, t);
        if (!mini) { _smoke(dc, x, y, w, h, light, t); }
        _skyline(dc, x, y, w, h, light, t);
        if (!mini && detail) { _crows(dc, x, y, w, h, t); }
        _treeline(dc, x, y, w, h, light);
        _wasteland(dc, x, y, w, h, light, t);
        _spikes(dc, x, y, w, h, lvl[Zs.D_SPIKES], light);
        _wall(dc, x, y, w, h, m, light, t);
        _towers(dc, x, y, w, h, cx, p, lvl, light, t);
        _yard(dc, x, y, w, h, light);
        for (var l = LN_N - 1; l >= 0; l--) {
            _lane(dc, x, y, w, h, cx, p, l, m, light, t, mini);
        }
        _fire(dc, x, y, w, h, cx, p, light, t);
        if (!mini) { _foreground(dc, x, y, w, h, p, light); }
    }

    // ── Sky ─────────────────────────────────────────────────────────────────
    // Fourteen bands, the same as FARM. A 64-colour panel collapses them into
    // four or five steps anyway, but the steps land in the right places.
    // Nothing here is a nice sky. Day is a cold overcast, afternoon is smoke
    // held under cloud, dusk is the only saturated hour and it is the one that
    // means the horde is close.
    function _skyTop(light) {
        var a = [0x5555AA, 0x555555, 0x550055, 0x000000];
        return a[_c(light, 0, 3)];
    }
    function _skyBot(light) {
        var a = [0xAAAAAA, 0xAA5555, 0xFF5500, 0x550000];
        return a[_c(light, 0, 3)];
    }

    function _sky(dc, x, y, w, h, light, t, detail) {
        var hz = horizonY(h);
        Px.vgrad(dc, x, y, w, hz, _skyTop(light), _skyBot(light), 14);
        if (light == L_NIGHT) { _stars(dc, x, y, w, hz, t); }
        // Ash. It falls on every screen in this game and it is the cheapest
        // thing on it that makes the air feel like it has something in it.
        if (detail) {
            var col = light == L_NIGHT ? 0x555555 : 0xAAAAAA;
            _col(dc, col);
            for (var i = 0; i < 16; i++) {
                var ax = (_hash(i * 29 + 3) % w + (t / 6 + i * 3) % 9) % w;
                var ay = (_hash(i * 41 + 7) + t * 2 + i * 13) % (h * 62 / 100);
                dc.fillRectangle(x + ax, y + ay, 1, 2);
            }
        }
    }

    function _stars(dc, x, y, w, hz, t) {
        for (var i = 0; i < 16; i++) {
            if (((t / 7) + i) % 6 == 0) { continue; }
            var sx = _hash(i * 7 + 3) % w;
            var sy = _hash(i * 13 + 5) % (hz * 8 / 10);
            _col(dc, (i % 5) == 0 ? 0xFFFFFF : 0xAAAAAA);
            dc.fillRectangle(x + sx, y + sy, 1, 1);
        }
    }

    // Sun or moon, with a glow disc under it. By dusk it is sitting on the
    // rooftops and it is the clearest signal on the screen that time is short.
    function _light(dc, x, y, w, h, light, t) {
        var hz = horizonY(h);
        var lx = x + w * 76 / 100;
        var ly = y + [hz * 26 / 100, hz * 48 / 100, hz * 80 / 100, hz * 26 / 100][_c(light, 0, 3)];
        var r = w / 17;
        if (r < 5) { r = 5; }

        if (light == L_NIGHT) {
            _col(dc, 0x000055); dc.fillCircle(lx, ly, r * 175 / 100);
            _col(dc, 0x555555); dc.fillCircle(lx, ly, r * 118 / 100);
            _col(dc, 0xAAAAAA); dc.fillCircle(lx, ly, r);
            _col(dc, 0x555555); dc.fillCircle(lx + r / 3, ly - r / 3, r * 70 / 100);
            return;
        }
        var glow = [0xAAAAAA, 0xFFAA55, 0xFF5500][_c(light, 0, 2)];
        var core = [0xFFFFFF, 0xFFFF55, 0xFFAA00][_c(light, 0, 2)];
        _col(dc, _shift(glow, -1));
        dc.fillCircle(lx, ly, r * 200 / 100);
        _col(dc, glow); dc.fillCircle(lx, ly, r * 135 / 100);
        _col(dc, core); dc.fillCircle(lx, ly, r);
        // A pale corona that breathes, so the disc is never a dead sticker.
        if ((t / 10) % 2 == 0) {
            _col(dc, core);
            dc.drawCircle(lx, ly, r * 160 / 100);
        }
    }

    // Columns of smoke standing over the city. They lean with the same slow
    // drift as the ash, which is what ties the two together.
    function _smoke(dc, x, y, w, h, light, t) {
        var hz = horizonY(h);
        var col = light == L_NIGHT ? 0x000000 : _shift(_skyBot(light), -1);
        _col(dc, col);
        for (var i = 0; i < 3; i++) {
            var sx = x + w * [18, 47, 88][i] / 100;
            var top = y + hz * [22, 8, 34][i] / 100;
            var yy = top;
            while (yy < y + hz) {
                var lean = (Math.sin((yy + t).toFloat() / 26.0) * (w * 3 / 100)).toNumber();
                var puff = 2 + (hz - (yy - y)) / 14;
                dc.fillRectangle(sx + lean - puff / 2, yy, puff, 3);
                yy += 3;
            }
        }
    }

    // The dead city, in two layers. The far one is hazed into the sky so the
    // near one has something to be black against; that gap is the whole trick.
    function _skyline(dc, x, y, w, h, light, t) {
        var hz = y + horizonY(h);
        var far = _shift(_skyBot(light), -1);
        var near = light == L_NIGHT ? 0x000000 : _shift(_skyBot(light), -2);

        _col(dc, far);
        var fx = x - 8;
        var i = 0;
        while (fx < x + w) {
            var fw = 7 + (_hash(i * 11 + 2) % (w * 10 / 100));
            var fh = h * 4 / 100 + (_hash(i * 17 + 7) % (h * 13 / 100));
            dc.fillRectangle(fx, hz - fh, fw, fh + 2);
            fx += fw + 4 + (_hash(i * 5) % 6);
            i += 1;
        }

        _col(dc, near);
        var nx = x - 5;
        var j = 0;
        var tops = [];
        var lefts = [];
        var widths = [];
        while (nx < x + w) {
            var bw = 9 + (_hash(j * 23 + 5) % (w * 12 / 100));
            var bh = h * 2 / 100 + (_hash(j * 31 + 13) % (h * 9 / 100));
            // Every third block is a broken tooth rather than a flat roof.
            if ((_hash(j * 3) % 3) == 0) {
                dc.fillPolygon([[nx, hz + 2], [nx, hz - bh],
                                [nx + bw / 2, hz - bh * 60 / 100],
                                [nx + bw, hz - bh], [nx + bw, hz + 2]]);
            } else {
                dc.fillRectangle(nx, hz - bh, bw, bh + 2);
            }
            tops.add(hz - bh); lefts.add(nx); widths.add(bw);
            nx += bw + 3 + (_hash(j * 7) % 5);
            j += 1;
        }
        // A handful of windows still burning out there. Only after dark: a lit
        // window by day would read as somebody being fine.
        if (light >= L_DUSK) {
            for (var k = 0; k < lefts.size(); k++) {
                if ((_hash(k * 19 + 1) % 4) != 0) { continue; }
                var on = ((t / 20 + k) % 7) != 0;
                _col(dc, on ? (light == L_NIGHT ? 0xFFAA00 : 0xFFFF55) : 0x550000);
                dc.fillRectangle(lefts[k] + widths[k] / 3, tops[k] + 4, 2, 2);
            }
        }
    }

    // Three crows on a slow circuit. Movement above the horizon is what keeps
    // a still picture from looking like a screenshot.
    function _crows(dc, x, y, w, h, t) {
        _col(dc, 0x000000);
        for (var i = 0; i < 3; i++) {
            var span = w + 40;
            var bx = x - 20 + ((t / 2 + i * 140) % span);
            var by = y + h * (9 + i * 4) / 100
                     + (Math.sin((t + i * 60).toFloat() / 18.0) * (h * 2 / 100)).toNumber();
            var up = ((t / 4 + i) % 2) == 0;
            dc.fillRectangle(bx - 3, by + (up ? 0 : 1), 3, 1);
            dc.fillRectangle(bx + 1, by + (up ? 0 : 1), 3, 1);
            dc.fillRectangle(bx, by + 1, 1, 1);
        }
    }

    // Dead trees on the ridge. Bare, uneven, and dark enough to sit the wall
    // in a landscape rather than on a blank strip.
    function _treeline(dc, x, y, w, h, light) {
        var hz = y + horizonY(h);
        // Hard black. A silhouette is the only thing that reads at this size,
        // and anything with a colour in it turns into a row of fence posts.
        _col(dc, 0x000000);
        var k = 0;
        var tx = x - 4;
        while (tx < x + w) {
            var s = _hash(k * 13 + 5);
            var th = h * 3 / 100 + (s % (h * 7 / 100));
            dc.fillRectangle(tx, hz - th, 2, th + 3);
            // Limbs, near the crown, uneven and never paired: a tree that has
            // one branch each side at the same height is a crucifix.
            var l1 = th * (40 + s % 30) / 100;
            dc.fillRectangle(tx - 4, hz - th + l1, 4, 1);
            dc.fillRectangle(tx - 5, hz - th + l1 - 2, 1, 3);
            if ((s % 3) != 0) {
                var l2 = th * (15 + s % 25) / 100;
                dc.fillRectangle(tx + 2, hz - th + l2, 3, 1);
                dc.fillRectangle(tx + 4, hz - th + l2 - 2, 1, 3);
            }
            tx += 5 + (s % (w * 9 / 100));
            k += 1;
        }
    }

    // ── Outside the wire ────────────────────────────────────────────────────
    // Two deliberate bands rather than a ramp, then scatter on top: cracks,
    // rubble, a burnt-out car. This is the ground the horde walks in on.
    function _wasteland(dc, x, y, w, h, light, t) {
        var hz = y + horizonY(h);
        var cy = y + crestY(h);
        // Dead ground: ash grey by day, rust by dusk, black at night. Never
        // green — the moment this band goes olive the scene reads as a field.
        var far  = [0xAAAAAA, 0xAA5500, 0x555500, 0x555555][_c(light, 0, 3)];
        var near = [0x555555, 0x555500, 0x550000, 0x000000][_c(light, 0, 3)];
        var mid = (hz + cy) / 2;
        _rect(dc, x, hz, w, mid - hz, far);
        _rect(dc, x, mid, w, cy - mid + 2, near);
        // A haze line right on the horizon, which is what makes the far band
        // read as distance rather than as a second floor.
        _rect(dc, x, hz, w, 1, _shift(far, 1));

        var crack = _shift(far, -1);
        for (var i = 0; i < 9; i++) {
            var sx = x + _hash(i * 31 + 9) % w;
            var sy = hz + 3 + (_hash(i * 19) % (cy - hz - 4));
            _rect(dc, sx, sy, 5 + (_hash(i * 7) % 13), 1, crack);
        }
        // Rubble, with a lit top pixel so each lump has a shape.
        for (var r = 0; r < 11; r++) {
            var rx = x + _hash(r * 53 + 17) % w;
            var ry = hz + 4 + (_hash(r * 37) % (cy - hz - 6));
            var rw = 3 + (_hash(r * 11) % 5);
            _rect(dc, rx, ry, rw, 2, _lit(0x555555, light));
            _rect(dc, rx, ry, rw, 1, _rim(0x555555, light));
        }
        _wreck(dc, x + w * 22 / 100, cy - h * 3 / 100, w * 13 / 100, light);
    }

    // A burnt-out car, side on. Drawn small and dark: it is a landmark in the
    // wasteland, not a feature, and the only silhouette out there that has to
    // be recognisable at a glance.
    function _wreck(dc, x, gy, bw, light) {
        var body = _lit(0x550000, light);
        var bh = bw * 26 / 100;
        if (bh < 3) { bh = 3; }
        // Body, then a cabin sitting back from the bonnet.
        _rect(dc, x - bw / 2, gy - bh, bw, bh, body);
        _col(dc, body);
        dc.fillPolygon([[x - bw / 4, gy - bh], [x - bw / 6, gy - bh * 2],
                        [x + bw / 5, gy - bh * 2], [x + bw / 3, gy - bh]]);
        _rect(dc, x - bw / 6, gy - bh * 2 + 1, bw * 2 / 5, bh - 1, 0x000000);
        _rect(dc, x - bw / 4, gy - bh * 2, bw / 2, 1, _rim(0x550000, light));
        // Wheels, one burnt off its rim.
        _col(dc, 0x000000);
        dc.fillCircle(x - bw / 3, gy, bh / 2 + 1);
        _rect(dc, x + bw / 4, gy - 1, bh, 2, 0x000000);
    }

    // The spike pit is the one defence that lives outside the wall, and the
    // only thing the horde meets before the timber.
    function _spikes(dc, x, y, w, h, lv, light) {
        if (lv <= 0) { return; }
        var cy = y + crestY(h);
        var n = 6 + lv;
        if (n > 18) { n = 18; }
        var ph = h * 3 / 100 + lv / 3;
        _rect(dc, x, cy - 2, w, 2, _lit(0x555500, light));
        var body = _lit(0xAAAAAA, light);
        var rim = _rim(0xAAAAAA, light);
        for (var s = 0; s < n; s++) {
            var sx = x + w * (3 + s * 94 / n) / 100;
            _col(dc, body);
            dc.fillPolygon([[sx, cy - ph], [sx - 2, cy], [sx + 2, cy]]);
            _rect(dc, sx - 1, cy - ph + 1, 1, ph - 1, rim);
        }
    }

    // ── The wall ────────────────────────────────────────────────────────────
    function _wall(dc, x, y, w, h, m, light, t) {
        var lvl = m.dLevel;
        var wl = lvl[Zs.D_WALL];
        var by = y + baseY(h);
        var top = wallTop(y, h, wl);

        // Three tiers. Timber, then poured concrete, then plated concrete —
        // the clearest single readout of progress anywhere on the screen.
        // Creosoted timber, then poured concrete, then plate. Each tier is a
        // whole step lighter than the one before, so the wall visibly gets
        // heavier as it goes up without any of them needing a label.
        var body;
        if (wl >= 10)     { body = 0xAAAAAA; }
        else if (wl >= 5) { body = 0x555555; }
        else              { body = 0x550000; }
        body = _lit(body, light);
        var dark = _shift(body, -1);

        _rect(dc, x, top, w, by - top, body);
        // Crest cap and a lit lip: the wall's edge against the wasteland.
        _rect(dc, x, top, w, 2, _shift(body, -1));
        _rect(dc, x, top, w, 1, _rim(body, light));
        // Footing shadow so the wall stands on the yard rather than floating.
        _rect(dc, x, by - 3, w, 3, dark);

        // Joints: planks, then panels, then plate seams.
        var step = wl >= 10 ? w * 20 / 100 : (wl >= 5 ? w * 14 / 100 : w * 9 / 100);
        for (var jx = step; jx < w; jx += step) {
            _rect(dc, x + jx, top + 3, 1, by - top - 5, dark);
        }
        // Buttresses. Four of them, clear of the gate, each with a lit face
        // and a shadow down its far side. Without these the wall is a slab
        // painted across the middle of the picture.
        var bp = [10, 30, 70, 90];
        var bw2 = w * 5 / 100;
        for (var b = 0; b < 4; b++) {
            var bx = x + w * bp[b] / 100 - bw2 / 2;
            _rect(dc, bx, top + 1, bw2, by - top - 1, body);
            _rect(dc, bx, top + 1, bw2 / 3 + 1, by - top - 1, _shift(body, 1));
            _rect(dc, bx + bw2, top + 3, 2, by - top - 3, dark);
            // A cap, so the buttress reads as standing proud of the wall.
            _rect(dc, bx - 1, top - 1, bw2 + 2, 3, _shift(body, 1));
            _rect(dc, bx - 1, top - 2, bw2 + 2, 1, _rim(body, light));
        }
        // Streaks down the face. Concrete that has stood one winter under a
        // burning city does not stay one flat tone.
        for (var s = 0; s < 7; s++) {
            var sx = x + _hash(s * 43 + 5) % w;
            var sh = (by - top) * (30 + _hash(s * 13) % 60) / 100;
            _rect(dc, sx, top + 2, 1, sh, _shift(body, -1));
        }

        // Battle damage. The crest is notched wherever the wall is not whole,
        // and you can see the wasteland through the gap.
        var gaps = (100 - m.wallPct) / 11;
        for (var g = 0; g < gaps; g++) {
            var gx = x + (_hash(g * 37 + 11) % (w - 24)) + 12;
            var gw = 5 + (_hash(g * 13) % 8);
            var gh = h * 2 / 100 + (_hash(g * 17) % (h * 3 / 100));
            _rect(dc, gx, top, gw, gh, _lit(0x550000, light));
            _rect(dc, gx, top + gh, gw, 1, dark);
        }

        if (lvl[Zs.D_PLATING] > 0) {
            var pw = 1 + lvl[Zs.D_PLATING] / 4;
            _rect(dc, x, top + 2, w, pw, _lit(0x55AAAA, light));
            _rect(dc, x, top + 2, w, 1, _rim(0x55AAAA, light));
        }
        _gate(dc, x, y, w, h, lvl[Zs.D_GATE], top, by, light, t);
        if (lvl[Zs.D_WIRE] > 0) { _wire(dc, x, w, top, lvl[Zs.D_WIRE], light); }
    }

    function _gate(dc, x, y, w, h, lv, top, by, light, t) {
        var gw = w * 24 / 100;
        var gx = x + w / 2 - gw / 2;
        if (lv <= 0) {
            // Nothing bought: the opening is boarded over, and it looks it.
            _rect(dc, gx, top + 2, gw, by - top - 2, _shift(_lit(Zs.WOOD_D, light), -1));
            for (var b = 0; b < 4; b++) {
                var byy = top + 5 + b * (by - top) / 5;
                _rect(dc, gx - 2, byy, gw + 4, 3, _lit(Zs.WOOD_D, light));
                _rect(dc, gx - 2, byy, gw + 4, 1, _lit(Zs.WOOD, light));
            }
            return;
        }
        var steel = _lit(lv >= 8 ? 0xAAAAAA : 0x555555, light);
        _rect(dc, gx, top + 2, gw, by - top - 2, steel);
        _rect(dc, gx, top + 2, gw, 1, _rim(steel, light));
        _rect(dc, gx + gw / 2, top + 2, 1, by - top - 2, _shift(steel, -1));
        var braces = 1 + lv / 4;
        var bcol = _lit(lv >= 8 ? 0xFFAA00 : 0xAA5500, light);
        for (var i = 0; i < braces; i++) {
            var iy = top + 6 + i * (by - top - 8) / braces;
            _rect(dc, gx, iy, gw, 2, bcol);
            _rect(dc, gx, iy, gw, 1, _rim(bcol, light));
        }
        _rect(dc, gx + 2, by - 9, 3, 4, 0x000000);
        _rect(dc, gx + gw - 5, by - 9, 3, 4, 0x000000);
        // A lamp over the gate, on once the light goes.
        if (light >= L_DUSK) {
            var on = ((t / 30) % 11) != 0;
            _rect(dc, x + w / 2 - 2, top - 4, 4, 3, on ? 0xFFAA00 : 0x555500);
            if (on) {
                _col(dc, 0x550000);
                dc.fillPolygon([[x + w / 2 - 2, top - 1], [x + w / 2 + 2, top - 1],
                                [x + w / 2 + gw / 3, by], [x + w / 2 - gw / 3, by]]);
            }
        }
    }

    function _wire(dc, x, w, top, lv, light) {
        var loops = 6 + lv;
        if (loops > 22) { loops = 22; }
        var r = 3 + lv / 5;
        dc.setPenWidth(1);
        _col(dc, _lit(0xAAAAAA, light));
        for (var i = 0; i < loops; i++) {
            dc.drawCircle(x + w * (3 + i * 94 / loops) / 100, top - r + 2, r);
        }
        _col(dc, _rim(0xAAAAAA, light));
        for (var k = 0; k < loops; k++) {
            dc.drawPoint(x + w * (3 + k * 94 / loops) / 100, top - r * 2 + 2);
        }
    }

    // ── Towers ──────────────────────────────────────────────────────────────
    // Each turret track has a fixed plot on the wall line, so the player learns
    // the shape of the compound instead of re-reading it every morning.
    // Every tower stands in the back of the yard and rises past the crest, so
    // its head is a silhouette against the sky rather than a detail lost on
    // the face of the wall. Nothing about a turret should need hunting for.
    function _towers(dc, x, y, w, h, cx, p, lvl, light, t) {
        var foot = y + baseY(h) + h * 3 / 100;
        var crest = wallTop(y, h, lvl[Zs.D_WALL]);
        if (lvl[Zs.D_MORTAR] > 0) { _mortarPit(dc, x + w * 64 / 100, foot, h, lvl[Zs.D_MORTAR], p, light, t); }
        if (lvl[Zs.D_TESLA] > 0)  { _teslaMast(dc, x + w * 87 / 100, foot, crest, h, lvl[Zs.D_TESLA], p, light, t); }
        if (lvl[Zs.D_MG] > 0)     { _mgNest(dc, x + w * 15 / 100, foot, crest, w, h, lvl[Zs.D_MG], p, light, t); }
    }

    function _mgNest(dc, tx, by, crest, w, h, lv, p, light, t) {
        // The deck clears the crest by a margin that grows with the level.
        var ty = crest - h * (3 + lv / 2) / 100;
        if (ty < by - h * 34 / 100) { ty = by - h * 34 / 100; }
        var th = by - ty;
        var tw = w * 13 / 100;
        var wood = _lit(Zs.WOOD_D, light);

        var leg = p / 2 + 1;
        // Legs, splayed slightly, with cross-bracing between them.
        _rect(dc, tx - tw / 2, ty, leg, th, wood);
        _rect(dc, tx + tw / 2 - leg, ty, leg, th, wood);
        for (var i = 1; i < 4; i++) {
            _rect(dc, tx - tw / 2, ty + th * i / 4, tw, leg / 2 + 1, wood);
        }
        // Deck, overhanging the legs, with a lit leading edge.
        var deck = _lit(Zs.WOOD, light);
        var dh = p * 2 / 3 + 1;
        _rect(dc, tx - tw / 2 - p / 2, ty - dh, tw + p, dh, deck);
        _rect(dc, tx - tw / 2 - p / 2, ty - dh, tw + p, 1, _rim(deck, light));
        // Sandbag parapet, three humps so it is not a box.
        var bag = _lit(0x555500, light);
        var bh = p * 5 / 4;
        for (var b = 0; b < 3; b++) {
            var bx = tx - tw / 2 + b * tw / 3;
            _rect(dc, bx, ty - dh - bh, tw / 3 + 1, bh, bag);
            _rect(dc, bx, ty - dh - bh, tw / 3 + 1, 1, _rim(bag, light));
        }
        // The gunner, and the gun sweeping the street on a slow idle.
        var head = ty - dh - bh;
        Px.place(dc, _sprites().get("gunner"), _crewPal(light),
                 tx - tw / 5, head + bh / 2, p * 45 / 100, false);
        var sweep = ((t / 24) % 3) - 1;
        _rect(dc, tx - p / 2, head - p, p, p * 3 / 2, _lit(Zs.STEEL_D, light));
        _rect(dc, tx + sweep, head - p / 2, tw * 66 / 100, p / 3 + 1, _lit(Zs.STEEL, light));
        if (lv >= 8) {
            _rect(dc, tx + sweep, head - p / 2 + p / 2 + 1, tw * 50 / 100, p / 3 + 1,
                  _lit(Zs.STEEL, light));
        }
    }

    function _teslaMast(dc, tx, by, crest, h, lv, p, light, t) {
        var my = crest - h * (4 + lv) / 100;
        if (my < by - h * 40 / 100) { my = by - h * 40 / 100; }
        var mh = by - my;
        var steel = _lit(Zs.STEEL_D, light);
        var half = p * 3 / 4 + 1;
        // A latticed mast rather than a pole: two uprights, cross-braced, and
        // narrowing as it goes up so it reads as a pylon.
        for (var i = 0; i < 7; i++) {
            var yy = my + mh * i / 7;
            var wd = half + (half * i / 7);
            _rect(dc, tx - wd, yy, wd * 2, 1, steel);
            _rect(dc, tx - wd, yy, 2, mh / 7 + 1, steel);
            _rect(dc, tx + wd - 2, yy, 2, mh / 7 + 1, steel);
        }
        var core = p + lv / 3;
        if (light >= L_DUSK) { _col(dc, 0x005555); dc.fillCircle(tx, my - core, core * 3); }
        _col(dc, 0x005555); dc.fillCircle(tx, my - core, core + 2);
        _col(dc, 0x55AAFF); dc.fillCircle(tx, my - core, core);
        _col(dc, 0xAAFFFF); dc.fillCircle(tx - core / 3, my - core - core / 3, core / 2);
        // Idle crackle. Live, but plainly not shooting at anything.
        if (((t / 5) % 4) == 0) {
            _col(dc, 0xAAFFFF);
            dc.drawLine(tx - core * 2, my - core - 3, tx + core * 2, my - core + 2);
            dc.drawLine(tx + 2, my - core * 3, tx - 2, my - core);
        }
    }

    function _mortarPit(dc, tx, gy, h, lv, p, light, t) {
        var u = h * 3 / 100 + lv / 4;
        // Sandbag ring, drawn as an ellipse with a lit upper edge.
        _col(dc, _lit(0x555500, light));
        dc.fillEllipse(tx, gy, u * 2, u * 3 / 4);
        _col(dc, _rim(0x555500, light));
        dc.drawArc(tx, gy, u * 2, Graphics.ARC_COUNTER_CLOCKWISE, 20, 160);
        // The tube.
        _col(dc, _lit(Zs.STEEL_D, light));
        dc.fillPolygon([[tx - u / 2, gy], [tx + u / 3, gy - u * 2],
                        [tx + u, gy - u * 2 + u / 2], [tx + u / 4, gy]]);
        _rect(dc, tx + u / 3, gy - u * 2, u / 2 + 1, u / 3 + 1, Zs.FIRE);
        // Crated shells, one stack per three levels.
        var st = 1 + lv / 3;
        if (st > 4) { st = 4; }
        for (var i = 0; i < st; i++) {
            Px.place(dc, _sprites().get("crate"), _cratePal(light), tx + u * 2 + i * p, gy + 1, p * 35 / 100, false);
        }
    }

    // ── The yard floor ──────────────────────────────────────────────────────
    // Three bands, one per lane, exactly the way FARM sells depth: the eye
    // reads the steps as ground receding, not as stripes.
    function _yard(dc, x, y, w, h, light) {
        var by = y + baseY(h);
        // Packed dirt, not grass. Each band nearer the player is a shade
        // warmer, which is the whole reason the steps read as ground.
        // One ground colour, not three. Three bands of flat colour turn the
        // yard into a layer cake; depth comes from the lit seam at each lane
        // line and from gravel that gets coarser as it comes towards the eye.
        var g = [0x555555, 0x555555, 0x550000, 0x000000][_c(light, 0, 3)];
        var b1 = y + h * laneY(2) / 100 + h * 4 / 100;
        var b2 = y + h * laneY(1) / 100 + h * 5 / 100;
        _rect(dc, x, by, w, y + h - by, g);
        // Lane seams, broken into segments of uneven length. Drawn edge to edge
        // they are three stripes across the picture; broken up they are cracks
        // in a concrete yard, which is what they were meant to be.
        for (var s = 0; s < 2; s++) {
            var sy = (s == 0) ? b1 : b2;
            var sx = x + (s * 9);
            while (sx < x + w) {
                var sw = 4 + _hash(sx + s * 31) % (w * 12 / 100);
                _rect(dc, sx, sy, sw, 1, _shift(g, 1));
                _rect(dc, sx, sy + 1, sw, 1, _shift(g, -1));
                sx += sw + 3 + _hash(sx * 7) % (w * 8 / 100);
            }
        }
        // Gravel. Deterministic, and larger towards the front so the same
        // texture doubles as a depth cue.
        var lo = _shift(g, -1);
        var hi = _shift(g, 1);
        for (var k = 0; k < 46; k++) {
            var kx = x + _hash(k * 71 + 3) % w;
            var ky = by + 2 + (_hash(k * 53 + 7) % (y + h - by - 3));
            var big = (ky - by) > (y + h - by) / 2 ? 2 : 1;
            _rect(dc, kx, ky, big, 1, (k % 3) == 0 ? hi : lo);
        }

        // The worn path between the gate and the fire. Only a shade off the
        // dirt either side of it — a track people walk, not a carpet.
        _col(dc, _shift(g, -1));
        dc.fillPolygon([[x + w / 2 - w * 2 / 100, by],
                        [x + w / 2 + w * 2 / 100, by],
                        [x + w * 57 / 100, y + h],
                        [x + w * 43 / 100, y + h]]);
        // The odd weed pushing through, and a tyre track either side of the
        // path where something heavy was dragged in.
        for (var i = 0; i < 12; i++) {
            var wx = x + _hash(i * 61 + 13) % w;
            var wy = by + 4 + (_hash(i * 47) % (h - baseY(h) - 5));
            _rect(dc, wx, wy, 1, 2, _lit(0x005500, light));
        }
    }

    // ── One lane of the yard ────────────────────────────────────────────────
    // Everything standing inside the wall belongs to a lane, and a lane knows
    // how big things are and how far off centre they may sit. Drawing them in
    // one pass per lane is what makes the near heap overlap the far shed.
    function _lane(dc, x, y, w, h, cx, p, l, m, light, t, mini) {
        var gy = y + h * laneY(l) / 100;
        var sp = p * laneScale(l) / 100;
        if (sp < 2) { sp = 2; }
        var half = w * 46 / 100;
        var lvl = m.dLevel;

        // Furniture that is here whether or not anything has been bought. A
        // compound on night one still has to look lived in, or the first
        // evening of the game is a picture of an empty field.
        if (l == 2) {
            _shelter(dc, _laneX(cx, half, l, 84), gy, sp, light, t);
        } else if (l == 1) {
            _waterTank(dc, _laneX(cx, half, l, -92), gy, sp, light);
        } else {
            _pallets(dc, _laneX(cx, half, l, 52), gy, sp, light);
        }

        if (l == 2) {
            if (lvl[Zs.D_REPAIR] > 0) {
                _workshop(dc, _laneX(cx, half, l, -52), gy, sp, lvl[Zs.D_REPAIR], m, light, t);
            }
            if (lvl[Zs.D_SALVAGE] > 0) {
                _heap(dc, _laneX(cx, half, l, 58), gy, sp, lvl[Zs.D_SALVAGE], light);
            }
            if (m.hasItem(Zs.IT_RADIO)) {
                _radioMast(dc, _laneX(cx, half, l, 12), gy, sp, light, t);
            }
        } else if (l == 1) {
            if (lvl[Zs.D_RIFLE] > 0) {
                _rifleRack(dc, _laneX(cx, half, l, -66), gy, sp, lvl[Zs.D_RIFLE], light);
            }
            if (m.hasItem(Zs.IT_GENERATOR)) {
                _generator(dc, _laneX(cx, half, l, 70), gy, sp, light, t);
            }
            if (m.hasItem(Zs.IT_SANDBAGS)) {
                _sandbags(dc, _laneX(cx, half, l, 34), gy, sp, light);
            }
            if (m.hasItem(Zs.IT_TOOLBOX)) {
                Px.place(dc, _sprites().get("crate"), _cratePal(light), _laneX(cx, half, l, -18), gy, sp * 55 / 100, false);
            }
            if (!mini) { _crew(dc, x, w, gy, sp, m, light, t, 1); }
        } else {
            if (m.hasItem(Zs.IT_AMMOBOX)) {
                Px.place(dc, _sprites().get("crate"), _cratePal(light), _laneX(cx, half, l, -78), gy, sp * 70 / 100, false);
                Px.place(dc, _sprites().get("crate"), _cratePal(light), _laneX(cx, half, l, -62), gy, sp * 70 / 100, true);
            }
            if (m.hasItem(Zs.IT_PLATE)) {
                _steelPlate(dc, _laneX(cx, half, l, 80), gy, sp, light);
            }
            if (!mini) { _crew(dc, x, w, gy, sp, m, light, t, 0); }
        }
    }

    function _laneX(cx, half, l, slot) {
        return cx + half * _c(slot, -100, 100) * laneSpread(l) / 10000;
    }

    // ── Sprites ─────────────────────────────────────────────────────────────
    // String rows, one char per cell, blitted through a palette. Kept as
    // module constants so they are built once rather than every frame.
    var _S = null;
    function _sprites() {
        if (_S != null) { return _S; }
        _S = {
            "gunner" => [".hh.", "cccc", ".cc.", ".ll."],
            "crate"  => ["bbbb", "bkkb", "bkkb", "bbbb"],
            "person" => [".hh.", ".hh.", "cccc", "cccc", ".cc.", ".c.c", ".l.l"],
            "watch"  => [".hh.", "cccc", "cccc", ".cc.", ".l.l", ".l.l"]
        };
        return _S;
    }

    function _crewPal(light) {
        return { "h" => _lit(Zs.SKIN, light), "c" => _lit(Zs.CLOTH, light),
                 "l" => _lit(0x555555, light) };
    }
    function _cratePal(light) {
        return { "b" => _lit(Zs.WOOD, light), "k" => _lit(Zs.WOOD_D, light) };
    }

    // The workshop. Corrugated roof, a lit bench through the doorway, and the
    // sparks that say somebody is still welding the gate back together.
    function _workshop(dc, x, gy, sp, lv, m, light, t) {
        var bw = sp * 11 + lv * sp / 8;
        var bh = sp * 6 + lv * sp / 12;
        var wall = _lit(0x555500, light);
        var roof = _lit(0x555555, light);
        var ty = gy - bh;

        _col(dc, 0x000000);
        dc.fillEllipse(x, gy + 1, bw * 60 / 100, sp / 2 + 1);
        _rect(dc, x - bw / 2, ty, bw, bh, wall);
        // Corrugation: alternating verticals down the face.
        for (var i = 0; i < bw / (sp / 2 + 1); i++) {
            _rect(dc, x - bw / 2 + i * (sp / 2 + 1), ty, 1, bh, _shift(wall, -1));
        }
        // Pitched roof with a bright leading edge.
        _col(dc, roof);
        dc.fillPolygon([[x - bw / 2 - sp / 2, ty], [x + bw / 2 + sp / 2, ty],
                        [x + bw / 2 - sp / 3, ty - sp * 3],
                        [x - bw / 2 + sp / 3, ty - sp * 3]]);
        _rect(dc, x - bw / 2 - sp / 2, ty, bw + sp, 1, _rim(roof, light));
        // The doorway, and the work light behind it.
        var dw = bw / 4;
        _rect(dc, x + bw / 6, gy - bh * 62 / 100, dw, bh * 62 / 100, 0x000000);
        _rect(dc, x - bw / 2 + sp / 2, ty + sp, sp * 3 / 2, sp, 0xFFAA00);
        _rect(dc, x - bw / 2 + sp / 2, ty + sp, sp * 3 / 2, 1, 0xFFFF55);
        if (light >= L_DUSK) {
            _col(dc, 0x550000);
            dc.fillPolygon([[x + bw / 6, gy], [x + bw / 6 + dw, gy],
                            [x + bw / 6 + dw * 2, gy + sp * 2],
                            [x + bw / 6 - dw, gy + sp * 2]]);
        }
        // Sparks off the bench.
        if (((t / 6) % 5) == 0) {
            _rect(dc, x + bw / 6 + 2, gy - bh * 34 / 100, 2, 2, 0xFFFFFF);
            _rect(dc, x + bw / 6 + 5, gy - bh * 30 / 100, 1, 1, 0xFFFF55);
        }
    }

    // The salvage heap. It is the only building that grows sideways as well as
    // up, because a scrap yard that is doing well is one you cannot walk past.
    function _heap(dc, x, gy, sp, lv, light) {
        var rows = 1 + lv / 4;
        if (rows > 4) { rows = 4; }
        var cols = 2 + lv / 3;
        if (cols > 6) { cols = 6; }
        var u = sp * 4 / 3;
        _col(dc, 0x000000);
        dc.fillEllipse(x, gy + 1, cols * u * 3 / 4, sp / 2 + 1);
        for (var r = 0; r < rows; r++) {
            var n = cols - r;
            if (n < 1) { n = 1; }
            for (var c = 0; c < n; c++) {
                var bx = x - n * u * 3 / 5 + c * u * 6 / 5;
                var byy = gy - r * u * 4 / 5;
                var tone = (_hash(r * 7 + c * 13) % 3);
                var col = _lit([0xAA5500, 0x555555, 0xAAAAAA][tone], light);
                _rect(dc, bx, byy - u, u * 6 / 5, u, col);
                _rect(dc, bx, byy - u, u * 6 / 5, 1, _rim(col, light));
                _rect(dc, bx, byy - 1, u * 6 / 5, 1, _shift(col, -1));
            }
        }
    }

    function _rifleRack(dc, x, gy, sp, lv, light) {
        var u = sp * 4;
        var wood = _lit(Zs.WOOD_D, light);
        _col(dc, 0x000000);
        dc.fillEllipse(x, gy + 1, u * 70 / 100, sp / 2 + 1);
        _rect(dc, x - u / 2, gy - u, 2, u, wood);
        _rect(dc, x + u / 2, gy - u, 2, u, wood);
        _rect(dc, x - u / 2, gy - u, u + 2, 2, wood);
        _rect(dc, x - u / 2, gy - u, u + 2, 1, _rim(wood, light));
        var n = 1 + lv / 3;
        if (n > 5) { n = 5; }
        for (var i = 0; i < n; i++) {
            var rx = x - u / 2 + 3 + i * (u - 4) / n;
            _rect(dc, rx, gy - u + 2, 1, u - 3, _lit(Zs.STEEL, light));
            _rect(dc, rx - 1, gy - u * 45 / 100, 3, 3, _lit(Zs.WOOD, light));
        }
    }

    function _generator(dc, x, gy, sp, light, t) {
        var bw = sp * 5;
        var bh = sp * 3;
        var body = _lit(0x005555, light);
        _col(dc, 0x000000);
        dc.fillEllipse(x, gy + 1, bw * 60 / 100, sp / 2 + 1);
        _rect(dc, x - bw / 2, gy - bh, bw, bh, body);
        _rect(dc, x - bw / 2, gy - bh, bw, 1, _rim(body, light));
        _rect(dc, x - bw / 2 + 2, gy - bh - sp, 3, sp + 1, _lit(0x555555, light));
        var on = ((t / 6) % 3) != 0;
        _rect(dc, x + bw / 3, gy - bh + 2, 2, 2, on ? 0x55FF55 : 0x005500);
        // Exhaust puff.
        if (((t / 9) % 4) == 0) {
            _rect(dc, x - bw / 2 + 2, gy - bh - sp - 2, 3, 2, 0x555555);
        }
    }

    function _sandbags(dc, x, gy, sp, light) {
        var u = sp * 5 / 4;
        var bag = _lit(0x555500, light);
        for (var r = 0; r < 3; r++) {
            var n = 4 - r;
            for (var c = 0; c < n; c++) {
                var bx = x - n * u / 2 + c * u + r * u / 2;
                var byy = gy - r * (u * 3 / 5) - u * 3 / 5;
                _rect(dc, bx, byy, u - 1, u * 3 / 5, bag);
                _rect(dc, bx, byy, u - 1, 1, _rim(bag, light));
            }
        }
    }

    function _steelPlate(dc, x, gy, sp, light) {
        var pw = sp * 5;
        var ph = sp * 4;
        var col = _lit(0xAAAAAA, light);
        _col(dc, 0x000000);
        dc.fillEllipse(x, gy + 1, pw * 55 / 100, sp / 2 + 1);
        // Leant against something, so it is a shape and not a square.
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x - pw / 2, gy], [x - pw / 3, gy - ph],
                        [x + pw / 2, gy - ph], [x + pw / 2, gy]]);
        _rect(dc, x - pw / 3, gy - ph, pw * 5 / 6, 1, _rim(col, light));
        for (var i = 0; i < 3; i++) {
            _rect(dc, x - pw / 4 + i * pw / 4, gy - ph + 3, 2, 2, _shift(col, -2));
        }
    }

    // A tarp stretched off two poles. The only thing in the yard that moves
    // on its own without being on fire.
    function _shelter(dc, x, gy, sp, light, t) {
        var pw = sp * 6;
        var ph = sp * 4;
        var pole = _lit(0x550000, light);
        _rect(dc, x - pw / 2, gy - ph, 2, ph, pole);
        _rect(dc, x + pw / 2, gy - ph * 3 / 4, 2, ph * 3 / 4, pole);
        var tarp = _lit(0x005555, light);
        var sag = ((t / 12) % 2);
        _col(dc, tarp);
        dc.fillPolygon([[x - pw / 2, gy - ph], [x + pw / 2 + 2, gy - ph * 3 / 4],
                        [x + pw / 2 + 2, gy - ph * 3 / 4 + sp], [x - pw / 2, gy - ph + sp + sag]]);
        _rect(dc, x - pw / 2, gy - ph, pw / 2, 1, _rim(0x005555, light));
        // Two bedrolls under it.
        _rect(dc, x - pw / 3, gy - sp, pw / 3, sp, _lit(0x555500, light));
        _rect(dc, x + sp / 2, gy - sp, pw / 3, sp, _lit(0x555555, light));
    }

    // A tank on a stand, patched. Reads as water, which is the other thing a
    // compound needs and the one nobody buys.
    function _waterTank(dc, x, gy, sp, light) {
        var r = sp * 3 / 2;
        var stand = _lit(0x555555, light);
        _rect(dc, x - r, gy - sp, 2, sp, stand);
        _rect(dc, x + r - 2, gy - sp, 2, sp, stand);
        _col(dc, _lit(0x005555, light));
        dc.fillRectangle(x - r, gy - sp - r * 2, r * 2, r * 2);
        _rect(dc, x - r, gy - sp - r * 2, r * 2, 1, _rim(0x005555, light));
        _rect(dc, x - r, gy - sp - r, r * 2, 1, _shift(_lit(0x005555, light), -1));
        _rect(dc, x + r / 3, gy - sp - 2, 2, 3, stand);
    }

    // Pallets and a tyre, stacked against nothing in particular.
    function _pallets(dc, x, gy, sp, light) {
        var wood = _lit(0xAA5500, light);
        for (var i = 0; i < 3; i++) {
            _rect(dc, x - sp * 2, gy - sp / 2 - i * (sp / 2 + 1), sp * 4, sp / 2, wood);
            _rect(dc, x - sp * 2, gy - sp / 2 - i * (sp / 2 + 1), sp * 4, 1, _rim(0xAA5500, light));
        }
        _col(dc, 0x000000);
        dc.fillCircle(x + sp * 3, gy - sp, sp);
        _col(dc, _lit(0x555555, light));
        dc.drawCircle(x + sp * 3, gy - sp, sp);
    }

    function _radioMast(dc, x, gy, sp, light, t) {
        var mh = sp * 12;
        var col = _lit(Zs.STEEL_D, light);
        _rect(dc, x - 1, gy - mh, 2, mh, col);
        for (var i = 0; i < 5; i++) {
            var yy = gy - mh + i * mh / 5;
            var wdt = 3 + i;
            _rect(dc, x - wdt / 2, yy, wdt, 1, col);
        }
        _rect(dc, x - sp, gy - mh, sp * 2, 1, col);
        if (((t / 14) % 2) == 0) {
            _rect(dc, x - 1, gy - mh - 3, 2, 2, 0xFF0000);
        }
    }

    // ── Whoever is left ─────────────────────────────────────────────────────
    // Crew size is the fort rating, coarsely. They walk a slow loop so the
    // yard is never a still frame, and they carry a shadow so they are
    // standing on the ground rather than pasted over it.
    function _crew(dc, x, w, gy, sp, m, light, t, lane) {
        var n = 1 + m.fortScore() / 45;
        if (n > 5) { n = 5; }
        var here = lane == 0 ? (n + 1) / 2 : n / 2;
        if (here < 1) { here = 1; }
        var pal = _crewPal(light);
        for (var i = 0; i < here; i++) {
            var seed = i + lane * 7;
            var span = w * 56 / 100;
            var phase = (t / 3 + seed * 97) % 360;
            var px = x + w * 22 / 100 + (phase < 180
                     ? span * phase / 180
                     : span * (360 - phase) / 180);
            var flip = phase < 180;
            var bob = ((t / 5 + seed) % 2) == 0 ? 0 : 1;
            _col(dc, 0x000000);
            dc.fillEllipse(px, gy + 1, sp, sp / 2 + 1);
            // Every third body stands still with a rifle instead of pacing.
            var rows = _sprites().get((seed % 3) == 0 ? "watch" : "person");
            Px.place(dc, rows, pal, px, gy + bob, sp * 60 / 100, flip);
            if ((seed % 3) == 0) {
                _rect(dc, flip ? px + sp / 2 : px - sp * 3 / 2,
                      gy - sp * 5 / 2, sp, 1, _lit(Zs.STEEL, light));
            }
        }
    }

    // ── The fire ────────────────────────────────────────────────────────────
    // The one thing in the yard that is not a defence. A compound of guns and
    // nothing else reads as an emplacement; the fire is what makes it a home.
    function _fire(dc, x, y, w, h, cx, p, light, t) {
        // Left of the track rather than on it, and high enough that the
        // countdown pill at the foot of the screen never sits on the flames.
        var fx = cx - w * 21 / 100;
        var gy = y + h * 88 / 100;
        var u = p;
        if (u < 2) { u = 2; }

        // Pool of light on the ground, before anything is drawn on top of it.
        if (light >= L_DUSK) {
            _col(dc, light == L_NIGHT ? 0x550000 : 0xAA5500);
            dc.fillEllipse(fx, gy, u * 5, u * 2);
            _col(dc, light == L_NIGHT ? 0xAA5500 : 0xFFAA00);
            dc.fillEllipse(fx, gy, u * 3, u * 5 / 4);
        }
        // The barrel it burns in.
        var drum = _lit(0x555555, light);
        _rect(dc, fx - u * 3 / 2, gy - u * 5 / 2, u * 3, u * 5 / 2, drum);
        _rect(dc, fx - u * 3 / 2, gy - u * 5 / 2, u * 3, 1, _rim(drum, light));
        _rect(dc, fx - u * 3 / 2, gy - u, u * 3, 1, _shift(drum, -1));

        var f = (t / 3) % 3;
        _col(dc, Zs.FIRE);
        dc.fillPolygon([[fx - u * 3 / 2, gy - u * 5 / 2],
                        [fx + (f - 1) * 2, gy - u * 5 / 2 - u * 5 / 2 - f],
                        [fx + u * 3 / 2, gy - u * 5 / 2]]);
        _col(dc, Zs.FIRE2);
        dc.fillPolygon([[fx - u, gy - u * 5 / 2],
                        [fx + (f - 1), gy - u * 4],
                        [fx + u, gy - u * 5 / 2]]);
        _rect(dc, fx - 1, gy - u * 7 / 2, 2, u, 0xFFFF55);
        // Embers and smoke going up.
        for (var s = 0; s < 5; s++) {
            var sy = gy - u * 4 - ((t * 2 + s * 37) % (h * 22 / 100));
            var sx = fx - 3 + ((t / 8 + s * 3) % 7);
            _rect(dc, sx, sy, 1, 2, s % 2 == 0 ? 0xFFAA00 : 0x555555);
        }
    }

    // ── Foreground ──────────────────────────────────────────────────────────
    // Two oil drums flanking the near edge of the yard, hard black because
    // anything this close to the eye is out of focus. They are what turn the
    // three lanes from a set of stripes into a space with a near edge.
    function _foreground(dc, x, y, w, h, p, light) {
        var by = y + h * 97 / 100;
        var u = p * 5 / 4;
        for (var i = 0; i < 2; i++) {
            var dx = i == 0 ? x + w * 13 / 100 : x + w * 88 / 100;
            _rect(dc, dx - u, by - u * 3, u * 2, u * 3, 0x000000);
            _rect(dc, dx - u, by - u * 3, u * 2, 1, _lit(0x555555, light));
            _rect(dc, dx - u, by - u * 2, u * 2, 1, _dark(0x555555, light));
        }
    }
}
