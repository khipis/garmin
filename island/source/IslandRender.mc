// ═══════════════════════════════════════════════════════════════════════════
// IslandRender.mc — CHUNKY PIXEL-ART view of YOUR ISLAND (module `IslandArt`).
//
// This is the star of the HOME screen: a dense, layered pixel diorama of the
// player's whole estate that visibly grows richer as they progress.
//
//   • Sky      — day/sunset/night/dawn gradient by time-of-day, sun or moon,
//                twinkling stars at night.
//   • Ocean    — animated shimmering wave rows with foam highlights, drifting
//                visitor boats, the odd jumping fish near shore.
//   • Island   — a pixel sand+grass landmass with a high wide grass crest,
//                speckled sand, grass tufts, low bushes, rock outcrops on both
//                flanks and a breathing shoreline foam line (deterministic hash
//                scatter so it never looks repetitive).
//   • Depth    — the land is split into three depth lanes (back ridge, middle
//                terrace, front shore) plus a sky lane. Back sprites paint at
//                80% pixel scale, middle at 90%, front at full size, strictly
//                back-to-front. An explicit (lane, xPercent) table places every
//                building id across the full width of its band, narrowed on
//                round displays so the top and bottom lanes stay inside the
//                inscribed circle.
//   • Estate   — every building tier gets its OWN distinct pixel sprite:
//                a Tent -> House -> Villa -> Castle skyline for Housing;
//                Forest/Garden/Lake/Trail each add a distinct nature feature;
//                Beach/Arena/Festival/Resort each add a distinct entertainment
//                feature; the SPECIAL landmarks appear once their area is
//                discovered — Ancient Temple, sparkling Crystal Tower, Dragon
//                Statue and a floating Sky Palace; the late-game Sky Tower,
//                Timber Mill, Grand Marina and the mythic Sun Obelisk, Sunken
//                Shrine and pulsing Rift Gate keep the skyline growing.
//   • Life     — villagers of varied sprite designs wander varied paths at
//                varied speed (count ~ population, capped for perf), birds
//                drift, fish jump, the crystal sparkles, waves shimmer — all
//                driven off a single cheap phase counter, no per-frame heap
//                churn beyond small literal sprite rows (same as before).
//   • Decor    — the first nine collectibles each have their OWN distinct pixel
//                decoration (grove, shells, totem, golden tree, coral,
//                waterfall, idol, monument, fountain); anything appended after
//                them falls back to a gem pedestal tinted with its own colour.
//
// Everything is drawn from cheap primitive fills, contained in a box, scales
// to any watch, and is fully guarded — the master render is wrapped in
// try/catch (drawBox), and every major new sub-feature is ALSO individually
// guarded so one bad calculation never blanks the rest of the scene.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;

module IslandArt {

    // ── Public entry points ────────────────────────────────────────────────
    // Legacy signature kept for the shared-menu preview band: centre + radius.
    function drawScene(dc, m, cx, cy, r, phase) {
        if (r < 8) { r = 8; }
        var w = r * 36 / 10;
        var h = r * 30 / 10;
        var x = cx - w / 2;
        var y = cy - h * 42 / 100;
        drawBox(dc, m, x, y, w, h, phase, true);
    }

    // Full pixel diorama inside an explicit rectangle (used by the HOME page).
    function drawBox(dc, m, x, y, w, h, phase, mini) {
        try { _render(dc, m, x, y, w, h, phase, mini); } catch (e) {}
    }

    // ── Master render ───────────────────────────────────────────────────────
    function _render(dc, m, x, y, w, h, phase, mini) {
        var p = w / 42; if (p < 2) { p = 2; }
        var cx = x + w / 2;
        var tod = _timeBucket();
        var round = false;
        try { round = (dc.getWidth() == dc.getHeight()); } catch (e) { round = false; }

        var horizon = y + h * 46 / 100;
        var groundY = y + h * 62 / 100;         // grass surface / reference waterline
        var islandHalf = w * 42 / 100; if (islandHalf < 4) { islandHalf = 4; }
        var L = _lanes(y, h, islandHalf, p, round);

        _sky(dc, x, y, w, horizon - y, tod, phase);
        _light(dc, x, y, w, h, tod, phase);
        _birds(dc, cx, y, w, h, p, phase);
        _ocean(dc, x, horizon, w, (y + h) - horizon, tod, phase);
        if (!mini) { try { _boats(dc, m, cx, horizon, w, islandHalf, p, phase, round); } catch (e) {} }
        if (!mini) { try { _fish(dc, cx, horizon, islandHalf, phase); } catch (e) {} }
        _island(dc, cx, horizon, groundY, y + h, islandHalf, tod, phase);
        _estate(dc, m, cx, L, phase, mini);
    }

    // ── Depth lanes ─────────────────────────────────────────────────────────
    // Every land object sits in one of three depth bands (plus a sky band) and
    // the whole scene is painted strictly back-to-front, so the island reads as
    // a diorama instead of one flat row of sprites bottom-anchored to a single
    // ground line. Lane geometry is derived once per frame and handed down.
    //
    // A round display clips the corners, so the high back band and the low shore
    // band get a much narrower usable width than the middle band — otherwise
    // their outermost sprites fall outside the inscribed circle.
    const LN_BACK  = 0;
    const LN_MID   = 1;
    const LN_FRONT = 2;
    const LN_SKY   = 3;

    function _lanes(y, h, islandHalf, p, round) {
        var ys = [y + h * 54 / 100,      // back  — upper slope of the dome
                  y + h * 66 / 100,      // mid   — the main terrace
                  y + h * 82 / 100,      // front — the beach apron
                  y + h * 36 / 100];     // sky   — floating structures
        // Usable width per band as a percent of islandHalf. The dome narrows as
        // it rises, so the back band gets far less room than the shore; a round
        // display tightens the top and bottom bands further still.
        var f = round ? [44, 70, 70, 52] : [52, 82, 80, 62];
        var ss = [islandHalf * f[0] / 100, islandHalf * f[1] / 100,
                  islandHalf * f[2] / 100, islandHalf * f[3] / 100];
        var pb = p * 8 / 10; if (pb < 2) { pb = 2; }
        var pm = p * 9 / 10; if (pm < 2) { pm = 2; }
        var pk = p * 7 / 10; if (pk < 2) { pk = 2; }
        return [ys, ss, [pb, pm, p, pk]];
    }
    function _ly(L, ln) { return L[0][Is._c(ln, 0, 3)]; }
    function _ls(L, ln) { return L[1][Is._c(ln, 0, 3)]; }
    function _lp(L, ln) { return L[2][Is._c(ln, 0, 3)]; }
    // Lane-relative horizontal position: xpct runs -100..100 across the lane.
    function _spot(L, ln, xpct, cx) { return cx + _ls(L, ln) * Is._c(xpct, -100, 100) / 100; }
    // Bottom-centre a sprite in a lane. lvl > 0 chunks the pixel size up so a
    // ranked-up structure visibly bulks out; dy nudges within the band.
    function _lplace(dc, rows, pal, L, ln, xpct, cx, lvl, dy, flip) {
        var px = _lp(L, ln);
        if (lvl > 0) { px = _scaleP(px, lvl); }
        _place(dc, rows, pal, _spot(L, ln, xpct, cx), _ly(L, ln) + dy, px, flip);
    }

    // ── Placement table ─────────────────────────────────────────────────────
    // Explicit (lane, xPercent) per building id, spread across the full usable
    // width of each band so structures never pile up in the middle. Ids are
    // save keys, so this table is index-aligned with Is.B_N and only appended.
    function bLane(i) {
        var a = [2, 1, 1, 0,   0, 2, 2, 1,   2, 1, 2, 1,
                 0, 0, 1, 3,   0, 1, 2, 0,   0, 3];
        return a[Is._c(i, 0, Is.B_N - 1)];
    }
    function bXPct(i) {
        var a = [-52, -58, 56, 34,   64, -20, 14, -2,   50, -30, -84, 88,
                 4, -26, 26, -40,   -88, -86, 86, 92,   -58, 44];
        return a[Is._c(i, 0, Is.B_N - 1)];
    }
    // Same idea for the collection decorations, tucked into the gaps.
    function cLane(i) {
        var a = [2, 2, 1, 0,   2, 0, 1, 0,   1, 2, 0, 2,   0, 1, 2];
        return a[Is._c(i, 0, Is.C_N - 1)];
    }
    function cXPct(i) {
        var a = [-70, -36, 72, -72,   96, 50, -46, 78,   8, 30, 20, -6,   -44, 42, 66];
        return a[Is._c(i, 0, Is.C_N - 1)];
    }

    // ── Deterministic scatter hash (position-based, never flickers) ──────────
    function _hash(seed) {
        var h = seed.toLong() * 2654435761l;
        h = h & 0x7FFFFFFFl;
        h = h ^ (h >> 13);
        h = h & 0x7FFFFFFFl;
        return h.toNumber();
    }

    // ── Time of day: 0 dawn · 1 day · 2 sunset · 3 night ──────────────────────
    function _timeBucket() {
        var hr = 13;
        try {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            if (info != null && info.hour != null) { hr = info.hour; }
        } catch (e) {}
        if (hr < 6)  { return 3; }
        if (hr < 8)  { return 0; }
        if (hr < 17) { return 1; }
        if (hr < 20) { return 2; }
        return 3;
    }

    // ── Sky ───────────────────────────────────────────────────────────────
    function _sky(dc, x, y, w, h, tod, phase) {
        if (h < 3) { h = 3; }
        var top; var bot;
        if (tod == 3)      { top = 0x000000; bot = 0x000055; }   // night
        else if (tod == 2) { top = 0x5555AA; bot = 0xFFAA55; }   // sunset
        else if (tod == 0) { top = 0x5555AA; bot = 0xFFAAAA; }   // dawn
        else               { top = 0x55AAFF; bot = 0xAAFFFF; }   // day
        Px.vgrad(dc, x, y, w, h, top, bot, 14);
        if (tod == 3) { _stars(dc, x, y, w, h, phase); }
    }

    function _stars(dc, x, y, w, h, phase) {
        dc.setColor(0xEAF2FF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            var sx = x + ((i * 37 + 11) % 100) * w / 100;
            var sy = y + ((i * 53 + 7) % 70) * h / 100;
            if (((phase / 6) + i) % 5 == 0) { continue; }   // gentle twinkle
            dc.fillRectangle(sx, sy, 2, 2);
        }
    }

    // ── Sun / Moon ──────────────────────────────────────────────────────────
    function _light(dc, x, y, w, h, tod, phase) {
        var lx = x + w * 74 / 100;
        var ly = y + h * 14 / 100;
        var rr = w / 16; if (rr < 5) { rr = 5; }
        if (tod == 3) {                              // moon
            dc.setColor(0xE8EEF6, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lx, ly, rr);
            dc.setColor(0x1C3358, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lx + rr / 2, ly - rr / 3, rr * 8 / 10);
            return;
        }
        var glow; var core;
        if (tod == 2)      { glow = 0xFFC98A; core = 0xFF9A5A; }   // sunset
        else if (tod == 0) { glow = 0xFFE7C0; core = 0xFFC98A; }   // dawn
        else               { glow = 0xFFFFAA; core = 0xFFAA00; }   // day
        dc.setColor(glow, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 8; i++) {
            var a = phase.toFloat() * 0.02 + i * 0.785;
            var x1 = lx + (Math.cos(a) * (rr + 3)).toNumber();
            var y1 = ly + (Math.sin(a) * (rr + 3)).toNumber();
            var x2 = lx + (Math.cos(a) * (rr + rr)).toNumber();
            var y2 = ly + (Math.sin(a) * (rr + rr)).toNumber();
            dc.drawLine(x1, y1, x2, y2);
        }
        dc.fillCircle(lx, ly, rr + 1);
        dc.setColor(core, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lx, ly, rr);
    }

    function _birds(dc, cx, y, w, h, p, phase) {
        dc.setColor(0x2A3540, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) {
            var span = w * 90 / 100;
            var bx = (cx - w * 45 / 100) + ((phase / 3 + i * 47) % span);
            var by = y + h * (14 + i * 7) / 100 + (Math.sin(phase.toFloat() * 0.1 + i) * 2).toNumber();
            var s = p < 3 ? 2 : p - 1;
            var flap = ((phase / 4 + i) % 2 == 0) ? 1 : 0;
            dc.fillRectangle(bx, by - flap, s, 1);
            dc.fillRectangle(bx + s, by - 1, s, 1);
            dc.fillRectangle(bx + s * 2, by - flap, s, 1);
        }
    }

    // ── Ocean ─────────────────────────────────────────────────────────────
    function _ocean(dc, x, y, w, h, tod, phase) {
        if (h < 3) { h = 3; }
        var top; var bot; var foam; var hi;
        if (tod == 3)      { top = 0x005555; bot = 0x000055; foam = 0x55AAAA; hi = 0xAAAAFF; }
        else if (tod == 2) { top = 0x0055AA; bot = 0x005555; foam = 0xFFAA55; hi = 0xFFFFAA; }
        else if (tod == 0) { top = 0x0055AA; bot = 0x005555; foam = 0xAAAAFF; hi = 0xFFFFFF; }
        else               { top = 0x00AAAA; bot = 0x005555; foam = 0xAAFFFF; hi = 0xFFFFFF; }
        Px.vgrad(dc, x, y, w, h, top, bot, 8);
        dc.setColor(foam, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var yy = y + h * (14 + i * 22) / 100;
            var shift = (phase / 5 + i * 7) % 14;
            for (var s = 0; s < 3; s++) {
                var wx = x + shift + s * w * 34 / 100 + (i % 2) * 10;
                dc.fillRectangle(wx, yy, w * 12 / 100, 2);
            }
        }
        // Bright foam-cap highlight, offset from the main bands for depth.
        dc.setColor(hi, Graphics.COLOR_TRANSPARENT);
        for (var i2 = 0; i2 < 4; i2++) {
            var yy2 = y + h * (14 + i2 * 22) / 100;
            var shift2 = (phase / 5 + i2 * 7 + 5) % 14;
            var wx2 = x + shift2 + w * 10 / 100 + i2 * w * 21 / 100;
            dc.fillRectangle(wx2, yy2, 3, 1);
        }
    }

    // Rare little fish arcing out of the water near shore.
    function _fish(dc, cx, horizon, islandHalf, phase) {
        dc.setColor(0x5AC0E0, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) {
            var cycle = (phase + i * 23) % 70;
            if (cycle > 6) { continue; }
            var arc = cycle < 3 ? cycle : (6 - cycle);
            var fx = cx + islandHalf * (60 - i * 45) / 100 + (_hash(i * 41 + 3) % 22) - 11;
            var fy = horizon + 8 - arc * 2;
            dc.fillRectangle(fx, fy, 2, 1);
            dc.fillRectangle(fx + 2, fy + 1, 1, 1);
        }
    }

    // Visitor boats out past the shore. The horizontal reach is clamped so a
    // drifting boat can never sail outside the inscribed circle of a round watch.
    function _boats(dc, m, cx, horizon, w, islandHalf, p, phase, round) {
        var vis = 0;
        try { vis = m.visitors; } catch (e) { vis = 0; }
        var n = vis / 10; if (n > 3) { n = 3; }
        if (vis > 0 && n == 0) { n = 1; }
        // A square sail over a one-row hull read as a flower on a plank at watch
        // size; a raked triangular sail and a deeper hull say "boat" instantly.
        var sail = { "m" => 0xFFFFFF, "h" => 0xAA5500, "d" => 0x550000, "f" => 0xFF5555 };
        var rows = ["...f.", "..mm.", ".mmmm", "..m..", "hhhhh", ".ddd."];
        var maxOff = (round ? (w * 44 / 100) : (w / 2)) - p * 3;
        if (maxOff < p) { maxOff = p; }
        for (var i = 0; i < n; i++) {
            var side = (i % 2 == 0) ? -1 : 1;
            var lane = i / 2;
            var off = islandHalf * (112 + lane * 26) / 100;
            var drift = (Math.sin(phase.toFloat() * 0.05 + i * 1.7) * islandHalf / 8).toNumber();
            off += drift;
            if (off > maxOff) { off = maxOff; }
            if (off < 0) { off = 0; }
            var by = horizon + p * 3 + lane * p * 3;
            var bob = (Math.sin(phase.toFloat() * 0.12 + i) * 1).toNumber();
            _place(dc, rows, sail, cx + side * off, by + bob, p, side < 0);
        }
    }

    // ── Island landmass (pixel dome) ─────────────────────────────────────────
    // The crest sits far higher than the waterline and stays wide up there, so
    // the back depth lane has real land under it rather than a narrow ridge.
    function _island(dc, cx, horizon, groundY, bottom, islandHalf, tod, phase) {
        // Width profile top->bottom (percent of islandHalf). Enough rows that
        // the silhouette curves instead of stepping like a pyramid, widest just
        // above the near shore and easing back in at the very front.
        var prof  = [42, 54, 64, 72, 79, 85, 89, 93, 96, 98,
                     100, 100, 100, 99, 97, 93, 88, 80];
        var grass = tod == 3 ? 0x005500 : 0x55AA00;
        var grass2= tod == 3 ? 0x005500 : 0x00AA00;
        var grass3= tod == 3 ? 0x000000 : 0x005500;
        var sand  = tod == 3 ? 0xAA5555 : 0xFFFFAA;
        var sand2 = tod == 3 ? 0x550000 : 0xFFAA55;
        var wet   = tod == 3 ? 0x550000 : 0xAA5500;
        var cols = [grass, grass, grass2, grass3, sand, sand2, wet];
        var top = groundY - (groundY - horizon) * 85 / 100;   // grass crest above waterline
        var span = bottom - top; if (span < 1) { span = 1; }
        // The tiny menu preview cannot fit one band per profile row, so the
        // profile is sampled across however many bands the box allows and the
        // dome always ends exactly on the box floor.
        var bh = span / prof.size(); if (bh < 2) { bh = 2; }
        var nb = span / bh; if (nb < 3) { nb = 3; }
        // Green covers the top half of the dome so the back and mid lanes stand
        // on land; the beach is only the front apron under the shore lane.
        var widths = new [nb];
        for (var i = 0; i < nb; i++) {
            var hw = islandHalf * prof[i * prof.size() / nb] / 100;
            widths[i] = hw;
            dc.setColor(cols[i * cols.size() / nb], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - hw, top + i * bh, hw * 2, bh + 1);
        }
        try { _terrain(dc, cx, top, span, bh, widths, tod, phase); } catch (e) {}
        try { _shore(dc, cx, groundY, bottom, islandHalf, tod, phase); } catch (e) {}
    }

    // Terrain dressing: sand speckle, grass tufts spread over the whole dome,
    // low bushes on the terraces and rock outcrops along both flanks. All from a
    // deterministic position hash, so it is dense but never flickers.
    function _terrain(dc, cx, top, span, bh, widths, tod, phase) {
        // Sand speckle over the beach apron only.
        var speck = tod == 3 ? 0x8A6E3E : 0xC8AC72;
        dc.setColor(speck, Graphics.COLOR_TRANSPARENT);
        var spanH = span * 40 / 100; if (spanH < 1) { spanH = 1; }
        for (var s = 0; s < 30; s++) {
            var sy = top + span * 52 / 100 + _hash(s * 13 + 9) % spanH;
            var sx = cx + _domeX(widths, top, bh, sy, _hash(s * 7 + 3) % 181 - 90);
            dc.fillRectangle(sx, sy, 2, 2);
        }
        // Grass tufts over the whole green half, hugging the dome edge.
        dc.setColor(tod == 3 ? 0x134A24 : 0x1E7A34, Graphics.COLOR_TRANSPARENT);
        var tuftH = bh * 9; if (tuftH < 2) { tuftH = 2; }
        for (var g = 0; g < 22; g++) {
            var gy = top + _hash(g * 29 + 1) % tuftH;
            var gx = cx + _domeX(widths, top, bh, gy, _hash(g * 19 + 5) % 173 - 86);
            dc.fillRectangle(gx, gy, 1, 3);
        }
        // Low bushes — chunkier than tufts, so the slopes have some volume.
        var bushRows = [".bb.", "bbbb", ".bb."];
        var bushPal = { "b" => tod == 3 ? 0x17512C : 0x349A46 };
        var bspots = [-84, -52, -14, 30, 66, 90];
        var bsz = bh / 2; if (bsz < 1) { bsz = 1; }
        for (var b = 0; b < bspots.size(); b++) {
            var by = top + bh * 2 + (_hash(b * 23 + 7) % (bh * 6));
            var bx = cx + _domeX(widths, top, bh, by, bspots[b]);
            _place(dc, bushRows, bushPal, bx, by, bsz, (b % 2) == 0);
        }
        // Rock outcrops along both flanks, from the slope down onto the sand.
        var rockCol = tod == 3 ? 0x3A4048 : 0x6E7680;
        var rockHi  = tod == 3 ? 0x4A5058 : 0x8A9098;
        var spots = [-94, -66, -22, 36, 70, 92];
        for (var r = 0; r < spots.size(); r++) {
            var ry = top + span * (26 + (_hash(r * 31 + 2) % 56)) / 100;
            var rx = cx + _domeX(widths, top, bh, ry, spots[r]);
            dc.setColor(rockCol, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx, ry, 6, 4);
            dc.fillRectangle(rx - 2, ry + 2, 10, 3);
            dc.setColor(rockHi, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx, ry, 3, 1);
        }
    }

    // Signed offset from the island centre for a scatter item that wants to sit
    // at xpct (-100..100) of the land available at height y. The dome narrows as
    // it rises, so a fixed spread would drop crest details into the ocean.
    function _domeX(widths, top, bh, y, xpct) {
        var hw = widths[Is._c((y - top) / bh, 0, widths.size() - 1)];
        return hw * Is._c(xpct, -96, 96) / 100;
    }

    // Shoreline: two foam bands that breathe with the wave phase so the island
    // meets the water instead of being pasted on top of it.
    function _shore(dc, cx, groundY, bottom, islandHalf, tod, phase) {
        var drop = bottom - groundY; if (drop < 4) { drop = 4; }
        var foam = tod == 3 ? 0x6A8AA0 : 0xF4EAC6;
        var foam2 = tod == 3 ? 0x86A6BC : 0xFFFDF0;
        // The near waterline is the front apron, well below the grass surface.
        var wl = bottom - drop * 30 / 100;
        var fw = islandHalf * 92 / 100;
        dc.setColor(foam, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - fw, wl, fw * 2, 2);
        // Broken crests riding the same phase counter as the ocean rows.
        dc.setColor(foam2, Graphics.COLOR_TRANSPARENT);
        var cw = islandHalf * 86 / 100;
        for (var i = 0; i < 9; i++) {
            var sx = cx - cw + ((i * 29 + (phase / 6)) % (cw * 2));
            var sy = wl + drop * (5 + (i % 4) * 5) / 100;
            dc.fillRectangle(sx, sy, islandHalf * 14 / 100, 1);
        }
    }

    // ── The estate: buildings/decor/life across the depth lanes ──────────────
    // One pass per lane, back to front, so a shore hut always overlaps the
    // terrace behind it and the terrace overlaps the ridge behind that.
    function _estate(dc, m, cx, L, phase, mini) {
        // Zero-filled first: a partial read must never leave nulls behind for
        // the sprite passes to compare against.
        var lv = new [Is.B_N];
        for (var z = 0; z < Is.B_N; z++) { lv[z] = 0; }
        var coll = 0; var built = 0; var pop = 0; var nature = 0;
        try {
            for (var i = 0; i < Is.B_N; i++) {
                var v = m.bLevel[i];
                if (v != null && v > 0) { lv[i] = v; }
            }
            for (var nI = Is.B_FOREST; nI <= Is.B_TRAIL; nI++) { nature += lv[nI]; }
            coll = m.collMask;
            built = m.totalBuildingLevels();
            pop = m.population;
        } catch (e) {}

        // Empty island → cosy starter camp so the scene is never bare.
        if (built == 0) {
            try { _camp(dc, cx, _ly(L, LN_MID), _lp(L, LN_MID)); } catch (e) {}
            return;
        }

        try { _skyLane(dc, lv, cx, L, phase); } catch (e) {}
        for (var ln = LN_BACK; ln <= LN_FRONT; ln++) {
            try { _bldLane(dc, lv, cx, L, ln, phase); } catch (e) {}
            try { _palmLane(dc, nature, cx, L, ln, phase); } catch (e) {}
            try { _decorLane(dc, coll, cx, L, ln, phase); } catch (e) {}
            if (!mini) { try { _villagerLane(dc, pop, cx, L, ln, phase); } catch (e) {} }
        }
    }

    // Floating structures: drawn first and high, so the island overlaps them.
    function _skyLane(dc, lv, cx, L, phase) {
        var px = _lp(L, LN_SKY);
        if (lv[Is.B_SKY] > 0) {
            var palRows = ["..p.p..", ".ppppp.", "ppppppp", ".ppppp.", "..bbb..", "..bbb.."];
            var palPal = { "p" => 0xB8A0FF, "b" => 0xEAF4FA };
            var flo = (Math.sin(phase.toFloat() * 0.06) * px).toNumber();
            _lplace(dc, palRows, palPal, L, LN_SKY, bXPct(Is.B_SKY), cx, lv[Is.B_SKY], flo, false);
        }
        if (lv[Is.B_RIFT] > 0) {
            var rRows = [".vvv.", "vv.vv", "v...v", "vv.vv", ".vvv."];
            var rPal = { "v" => ((phase / 5) % 2 == 0) ? 0xD070FF : 0x9A4ADF };
            var flo2 = (Math.sin(phase.toFloat() * 0.05 + 2) * px).toNumber();
            _lplace(dc, rRows, rPal, L, LN_SKY, bXPct(Is.B_RIFT), cx, lv[Is.B_RIFT], flo2, false);
        }
    }

    // Every built structure assigned to this lane, in id order.
    function _bldLane(dc, lv, cx, L, ln, phase) {
        for (var i = 0; i < Is.B_N; i++) {
            if (lv[i] <= 0 || bLane(i) != ln) { continue; }
            try { _bldScene(dc, i, lv[i], cx, L, ln, phase); } catch (e) {}
        }
    }
    // Dispatch by category so each sprite table stays readable.
    function _bldScene(dc, id, lvl, cx, L, ln, phase) {
        if (id == Is.B_TOWER) { _sprTower(dc, lvl, cx, L, ln); return; }
        var cat = Is.bCat(id);
        if (cat == 0) { _sprHouse(dc, id, lvl, cx, L, ln); return; }
        if (cat == 1) { _sprNature(dc, id, lvl, cx, L, ln, phase); return; }
        if (cat == 2) { _sprFun(dc, id, lvl, cx, L, ln, phase); return; }
        _sprSpecial(dc, id, lvl, cx, L, ln, phase);
    }

    // HOUSING — each tier keeps its own silhouette, and extra dwellings appear
    // beside it as the level climbs, so a high-level House reads as a hamlet.
    function _sprHouse(dc, id, lvl, cx, L, ln) {
        var rows; var pal;
        if (id == Is.B_CASTLE) {
            rows = ["k.k.k.k", "kkkkkkk", "kwwgwwk", "kwwwwwk", "kwgwgwk", "kwwdwwk", "kwwdwwk"];
            pal = { "k" => 0x8A8478, "w" => 0xC8C0B0, "g" => 0x6FC0E0, "d" => 0x4A3A2A };
        } else if (id == Is.B_VILLA) {
            rows = ["..hhhh..", ".hhhhhh.", "hhhhhhhh", "wwggwgww", "wwwwwwww", "wwddwwww"];
            pal = { "h" => 0xFFD27A, "w" => 0xF0DCA8, "g" => 0x8CE0FF, "d" => 0x6A3A22 };
        } else if (id == Is.B_HOUSE) {
            rows = ["..hh..", ".hhhh.", "hhhhhh", "wwggww", "wwwwww", "wwddww"];
            pal = { "h" => 0xC24A3A, "w" => 0xF0DCA8, "g" => 0x8CE0FF, "d" => 0x6A3A22 };
        } else {
            rows = ["..t..", ".ttt.", "ttdtt", "t.d.t"];
            pal = { "t" => 0xC98A5A, "d" => 0x6A3A22 };
        }
        var base = bXPct(id);
        var extra = lvl / 4; if (extra > 2) { extra = 2; }
        for (var k = extra; k >= 1; k--) {
            _lplace(dc, rows, pal, L, ln, base + k * 11, cx, 0, _lp(L, ln) * k / 2, (k % 2) == 0);
        }
        _lplace(dc, rows, pal, L, ln, base, cx, lvl, 0, false);
        // A pennant marks a genuinely developed home.
        if (lvl >= 6) {
            var px = _scaleP(_lp(L, ln), lvl);
            var hx = _spot(L, ln, base, cx);
            var ty = _ly(L, ln) - rows.size() * px - px * 2;
            dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(hx, ty, 1, px * 2);
            dc.fillRectangle(hx + 1, ty, px, px);
        }
    }

    // Sky Tower — literally gains floors as it ranks up.
    function _sprTower(dc, lvl, cx, L, ln) {
        var rows = ["..a..", ".ttt."];
        var floors = 2 + lvl / 2; if (floors > 7) { floors = 7; }
        for (var f = 0; f < floors; f++) { rows.add((f % 2 == 0) ? "twtwt" : "ttttt"); }
        var pal = { "t" => 0xA0C8FF, "w" => 0x2A5A80, "a" => 0xFFE9A0 };
        _lplace(dc, rows, pal, L, ln, bXPct(Is.B_TOWER), cx, lvl, 0, false);
    }

    // NATURE — Forest thickens, Garden gets tilled beds, Lake ripples, the
    // Mountain Trail lays more steps and the Timber Mill turns its wheel.
    function _sprNature(dc, id, lvl, cx, L, ln, phase) {
        var xp = bXPct(id);
        if (id == Is.B_FOREST) {
            var fRows = ["f.f.f.f", ".fffff.", "fffffff", "..t.t..", "..t.t.."];
            if (lvl >= 5) { fRows = ["f.f.f.f", "fffffff", ".fffff.", "fffffff", "..t.t..", "..t.t.."]; }
            var fPal = { "f" => 0x3FA85A, "t" => 0x8A5A2A };
            var sway = (Math.sin(phase.toFloat() * 0.08) * 1).toNumber();
            _lplace(dc, fRows, fPal, L, ln, xp, cx + sway, lvl, 0, false);
            return;
        }
        if (id == Is.B_GARDEN) {
            var gRows = ["g.g.g", ".g.g.", "g.g.g", "sssss"];
            var gPal = { "g" => 0x8CD060, "s" => 0x6A4A2A };
            _lplace(dc, gRows, gPal, L, ln, xp, cx, lvl, 0, false);
            return;
        }
        if (id == Is.B_LAKE) {
            var lRows = [".lll.", "lllll", ".lll."];
            var lPal = { "l" => 0x5AC0E0 };
            _lplace(dc, lRows, lPal, L, ln, xp, cx, lvl, 0, false);
            if ((phase / 5) % 2 == 0) {
                dc.setColor(0xEAFBFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_spot(L, ln, xp, cx) - 1, _ly(L, ln) - _lp(L, ln) * 3, 2, 1);
            }
            return;
        }
        if (id == Is.B_TRAIL) {
            var px = _lp(L, ln);
            var steps = 3 + lvl / 2; if (steps > 7) { steps = 7; }
            var tx = _spot(L, ln, xp, cx) - steps * px / 2;
            dc.setColor(0xB0A48C, Graphics.COLOR_TRANSPARENT);
            for (var s = 0; s < steps; s++) {
                dc.fillRectangle(tx + s * px, _ly(L, ln) - px * (1 + (s % 2)), px - 1, px - 1);
            }
            return;
        }
        var mRows = ["..r..", ".rrr.", "wwwww", "w.k.w", "wwwww"];
        var mPal = { "r" => 0x6A3A22, "w" => 0x8A6A3A, "k" => 0xC8B090 };
        _lplace(dc, mRows, mPal, L, ln, xp, cx, lvl, 0, false);
    }

    // ENTERTAINMENT — each venue has its own silhouette; the festival ground
    // lights its lanterns once it has been developed.
    function _sprFun(dc, id, lvl, cx, L, ln, phase) {
        var xp = bXPct(id);
        if (id == Is.B_BEACH) {
            var uRows = ["uuuuu", ".uuu.", "..s..", "..s..", "..s.."];
            var uPal = { "u" => 0xFF6FA0, "s" => 0xC8B090 };
            _lplace(dc, uRows, uPal, L, ln, xp, cx, lvl, 0, false);
            return;
        }
        if (id == Is.B_ARENA) {
            var aRows = ["aaaaaaa", "a.f.f.a", "a.....a", "aaaaaaa"];
            var aPal = { "a" => 0xE0C89A, "f" => 0xFF9A5A };
            _lplace(dc, aRows, aPal, L, ln, xp, cx, lvl, 0, false);
            return;
        }
        if (id == Is.B_FESTIVAL) {
            var vRows = ["r.r.r", "iiiii", "i...i", "i...i"];
            var vPal = { "r" => 0xFF6FA0, "i" => 0xFFE7C0 };
            _lplace(dc, vRows, vPal, L, ln, xp, cx, lvl, 0, false);
            if (lvl >= 3 && (phase / 4) % 2 == 0) {
                var px = _scaleP(_lp(L, ln), lvl);
                dc.setColor(0xFFF0B0, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_spot(L, ln, xp, cx) - px * 2, _ly(L, ln) - px * 5, px, px);
            }
            return;
        }
        if (id == Is.B_RESORT) {
            var wRows = ["wwwwwww", "w.g.g.w", "wwwwwww", ".bbbbb."];
            var wPal = { "w" => 0xF0DCC0, "g" => 0x8CE0FF, "b" => 0x5AC0E0 };
            _lplace(dc, wRows, wPal, L, ln, xp, cx, lvl, 0, false);
            return;
        }
        var yRows = ["s...s", "mm.mm", "ddddd", "..d.."];
        var yPal = { "s" => 0xEAF6F2, "m" => 0x4AE0C8, "d" => 0x8A6A4A };
        _lplace(dc, yRows, yPal, L, ln, xp, cx, lvl, 0, false);
    }

    // SPECIAL / MYTHIC landmarks — the reward for finishing the expeditions.
    function _sprSpecial(dc, id, lvl, cx, L, ln, phase) {
        var xp = bXPct(id);
        if (id == Is.B_TEMPLE) {
            var tRows = ["..ggg..", ".ggggg.", "ggggggg", ".s.s.s.", ".s.s.s.", ".sssss.", "sssssss"];
            var tPal = { "g" => 0xE0C24A, "s" => 0xCFC7B0 };
            _lplace(dc, tRows, tPal, L, ln, xp, cx, lvl, 0, false);
            return;
        }
        if (id == Is.B_CRYSTAL) {
            var cRows = ["..c..", ".ccc.", ".ccc.", "ccccc", ".ccc.", ".bbb.", ".bbb.", "bbbbb"];
            var cPal = { "c" => 0x8CE0FF, "b" => 0x5A7A9A };
            _lplace(dc, cRows, cPal, L, ln, xp, cx, lvl, 0, false);
            if ((phase / 4) % 3 == 0) {
                var sp = _scaleP(_lp(L, ln), lvl);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_spot(L, ln, xp, cx) - 1, _ly(L, ln) - sp * 8 - 2, 3, 3);
            }
            return;
        }
        if (id == Is.B_DRAGON) {
            var dRows = [".r...", "rr.r.", ".rrrr", "..rr.", ".sss.", "sssss"];
            var dPal = { "r" => 0xFF5A5A, "s" => 0x9A8070 };
            _lplace(dc, dRows, dPal, L, ln, xp, cx, lvl, 0, false);
            return;
        }
        if (id == Is.B_OBELISK) {
            var oRows = ["..y..", ".ooo.", ".ooo.", ".ooo.", ".ooo.", "ooooo"];
            var oPal = { "y" => 0xFFE9A0, "o" => 0xFFB03A };
            _lplace(dc, oRows, oPal, L, ln, xp, cx, lvl, 0, false);
            return;
        }
        var hRows = [".s.s.", "sssss", ".ggg.", ".ggg.", "sssss"];
        var hPal = { "s" => 0x3AE0A0, "g" => 0x14504A };
        _lplace(dc, hRows, hPal, L, ln, xp, cx, lvl, 0, false);
    }

    // Palms spread over all three lanes instead of one band; the grove thickens
    // as the nature buildings level up.
    function _palmLane(dc, nature, cx, L, ln, phase) {
        var n = 3 + nature; if (n > 9) { n = 9; }
        var pLane = [0, 1, 2, 0, 1, 2, 0, 1, 2];
        var pX    = [-46, 40, -90, 78, -74, 34, 22, 96, -30];
        var variants = [
            ["f.f.f", ".fff.", "fffff", "..t..", "..t.."],
            [".f.f.", "ffff.", ".fff.", "..t..", "..t..", "..t.."],
            ["f...f", ".fff.", "fffff", "...t.", "...t."]
        ];
        var pal = { "f" => 0x3FA85A, "t" => 0x8A5A2A };
        for (var i = 0; i < n; i++) {
            if (pLane[i] != ln) { continue; }
            var rows = variants[_hash(i * 17 + 5) % variants.size()];
            var flip = (_hash(i * 23 + 1) % 2) == 0;
            var sway = (Math.sin(phase.toFloat() * 0.08 + i) * 1).toNumber();
            _lplace(dc, rows, pal, L, ln, pX[i], cx + sway, 0, (i % 2) * 2, flip);
        }
    }

    // Collection decorations placed by the same lane table as the buildings.
    function _decorLane(dc, coll, cx, L, ln, phase) {
        for (var i = 0; i < Is.C_N; i++) {
            if ((coll & (1 << i)) == 0 || cLane(i) != ln) { continue; }
            try { _decorOne(dc, i, cx, L, ln, phase); } catch (e) {}
        }
    }
    // The first nine each have their own hand-drawn sprite; ids appended past
    // them get a gem pedestal tinted with their own palette colour, so a new
    // collectible always places something instead of nothing.
    function _decorOne(dc, id, cx, L, ln, phase) {
        var xp = cXPct(id);
        var rows; var pal;
        if (id == 0) {
            rows = ["f.f", ".f.", "t.t"]; pal = { "f" => 0x3FA85A, "t" => 0x8A5A2A };
        } else if (id == 1) {
            rows = [".s.p", "sspp", ".s.p"]; pal = { "s" => 0xFFD9E8, "p" => 0xFFC8DC };
        } else if (id == 2) {
            rows = ["ttt", "tit", "ttt", "ttt"]; pal = { "t" => 0x8A5A2A, "i" => 0xFFE0A0 };
        } else if (id == 3) {
            rows = ["..y..", ".yyy.", "yyyyy", ".yyy.", "..t..", "..t.."];
            pal = { "y" => 0xFFD24A, "t" => 0x8A5A2A };
        } else if (id == 4) {
            rows = ["c.o.p", "ccopo", ".oco."];
            pal = { "c" => 0xFF7FA0, "o" => 0xFF9A5A, "p" => 0xB46CFF };
        } else if (id == 5) {
            rows = ["ww", "ww", "ww", "wb", "bb"]; pal = { "w" => 0x8CE0FF, "b" => 0xEAFBFF };
        } else if (id == 6) {
            rows = [".s.", "sss", ".s.", "sss"]; pal = { "s" => 0x9A968C };
        } else if (id == 7) {
            rows = ["mmmmm", ".mmm.", "mmmmm"]; pal = { "m" => 0xE0C24A };
        } else if (id == 8) {
            rows = [".w.w.", "wwwww", ".sss.", "sssss"];
            pal = { "w" => 0x8CE0FF, "s" => 0xC8C0B0 };
        } else {
            rows = [".g.", "ggg", ".g.", ".b."];
            pal = { "g" => Is.cColor(id), "b" => 0x8A8478 };
        }
        _lplace(dc, rows, pal, L, ln, xp, cx, 0, 0, (id % 2) == 1);
        // The waterfall trickles and the fountain sprays on the phase counter.
        if (id == 5 && (phase / 4) % 2 == 0) {
            dc.setColor(0xEAFBFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_spot(L, ln, xp, cx), _ly(L, ln) + 1, 3, 2);
        }
        if (id == 8 && (phase / 3) % 2 == 0) {
            dc.setColor(0xEAFBFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(_spot(L, ln, xp, cx) - 1, _ly(L, ln) - _lp(L, ln) * 6, 2, 2);
        }
    }

    // ── Villagers wandering their lane ────────────────────────────────────────
    // Varied sprite silhouettes, varied stride speed & varied flip cadence so
    // the crowd never looks like clones marching in lockstep. Villagers are
    // spread over all three lanes, one in three per band.
    function _villagerLane(dc, pop, cx, L, ln, phase) {
        var n = pop; if (n > 9) { n = 9; }
        var shirts = [0x37D0C0, 0xFFC24A, 0xFF6FA0, 0x6FB3FF, 0xB46CFF, 0x6FE08A, 0xFF9A5A];
        var variants = [
            [".H.", "SSS", ".S.", "L.L"],
            [".HH", "SSS", ".S.", "L.L"],
            [".H.", ".SS", ".S.", ".L."]
        ];
        var vp = _lp(L, ln) * 6 / 10; if (vp < 2) { vp = 2; }
        for (var i = 0; i < n; i++) {
            if (i % 3 != ln) { continue; }
            var rows = variants[_hash(i * 29 + 3) % variants.size()];
            var pal = { "H" => 0xF0C090, "S" => shirts[i % shirts.size()], "L" => 0x3A4A6A };
            var speedMil = 20 + (_hash(i * 11 + 7) % 30);
            var wpct = (Math.sin(phase.toFloat() * (0.02 + speedMil.toFloat() * 0.001) + i * 1.9) * 86).toNumber();
            var flipEvery = 6 + (i % 4);
            _place(dc, rows, pal, _spot(L, ln, wpct, cx), _ly(L, ln) + (i % 2) * vp, vp,
                   ((phase / flipEvery + i) % 2 == 0));
        }
    }

    // ── Starter camp for an empty island ─────────────────────────────────────
    function _camp(dc, cx, groundY, p) {
        var tent = { "a" => 0xC98A5A, "d" => 0x6A3A22 };
        var rows = ["..a..", ".aaa.", "aadaa"];
        _place(dc, rows, tent, cx, groundY, p, false);
        var palm = { "f" => 0x3FA85A, "t" => 0x8A5A2A };
        var palmRows = ["f.f.f", ".fff.", "fffff", "..t..", "..t.."];
        _place(dc, palmRows, palm, cx + p * 4, groundY, p, false);
        // A tiny signpost of hope.
        dc.setColor(0xFFF0B0, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - p * 4, groundY - p * 2, p, p);
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    // Draw a sprite bottom-centred at (cxp, baseY).
    function _place(dc, rows, pal, cxp, baseY, px, flip) {
        if (rows == null || rows.size() == 0) { return; }
        var wc = rows[0].length();
        var hc = rows.size();
        var ox = cxp - wc * px / 2;
        var oy = baseY - hc * px;
        Px.spr(dc, rows, pal, ox, oy, px, flip);
    }
    // Grow the pixel size a little with level (chunkier landmarks as they rank up).
    function _scaleP(p, lvl) {
        var e = lvl / 3; if (e > 3) { e = 3; }
        return p + e;
    }

    // ── Info-card artwork ────────────────────────────────────────────────────
    // Chunky pixel portraits behind every detail card: a building, a discovery
    // area or a collectible, drawn large enough to actually read as an object.
    // The collectible table also feeds the collection grid at a smaller scale so
    // a piece looks identical wherever the player meets it.
    function _sprC(dc, rows, pal, cx, cy, px) {
        if (rows == null || rows.size() == 0) { return; }
        var cols = rows[0].length();
        Px.spr(dc, rows, pal, cx - cols * px / 2, cy - rows.size() * px / 2, px, false);
    }

    // 7x6 portrait per building id (0..Is.B_N-1).
    function bldArt(dc, id, cx, cy, px) {
        var rows; var pal;
        var k = Is._c(id, 0, Is.B_N - 1);
        if (k == Is.B_TENT) {
            pal = { "t" => 0xC98A5A, "d" => 0x6A3A22, "g" => 0x46B255 };
            rows = ["...t...", "..ttt..", ".ttttt.", "tttdttt", "ttddttt", "ggggggg"];
        } else if (k == Is.B_HOUSE) {
            pal = { "h" => 0xC24A3A, "w" => 0xF0DCA8, "g" => 0x8CE0FF, "d" => 0x6A3A22 };
            rows = ["..hhh..", ".hhhhh.", "hhhhhhh", "wwgggww", "wwwwwww", "wwwdwww"];
        } else if (k == Is.B_VILLA) {
            pal = { "h" => 0xFFD27A, "w" => 0xF0DCA8, "g" => 0x8CE0FF, "d" => 0x6A3A22 };
            rows = [".hhhhh.", "hhhhhhh", "wggwggw", "wwwwwww", "wggwdww", "wwwwdww"];
        } else if (k == Is.B_CASTLE) {
            pal = { "k" => 0x8A8478, "w" => 0xC8C0B0, "g" => 0x6FC0E0, "d" => 0x4A3A2A, "y" => 0xE6C24A };
            rows = ["y.y.y.y", "k.k.k.k", "kkkkkkk", "kwgwgwk", "kwwwwwk", "kwwdwwk"];
        } else if (k == Is.B_FOREST) {
            pal = { "f" => 0x3FA85A, "F" => 0x2E8C3C, "t" => 0x8A5A2A };
            rows = [".f.F.f.", "fffFFFf", "FFfffFF", ".t.t.t.", ".t.t.t.", "ttttttt"];
        } else if (k == Is.B_GARDEN) {
            pal = { "g" => 0x8CD060, "r" => 0xFF6FA0, "s" => 0x6A4A2A };
            rows = [".r.r.r.", "ggggggg", "sssssss", ".g.g.g.", "sssssss", "sssssss"];
        } else if (k == Is.B_LAKE) {
            pal = { "l" => 0x33AEE0, "w" => 0x8CE0FF, "s" => 0xE9D6A0 };
            rows = ["sssssss", "s.lll.s", "slwwwls", "sllllls", "s.lll.s", "sssssss"];
        } else if (k == Is.B_TRAIL) {
            pal = { "r" => 0x9FB0C0, "k" => 0x6E7680, "s" => 0xB0A48C };
            rows = ["....rr.", "...rkr.", "..rkr..", ".sks...", "sks....", "ss....."];
        } else if (k == Is.B_BEACH) {
            pal = { "u" => 0xFF6FA0, "s" => 0xC8B090, "d" => 0xE9D6A0 };
            rows = [".uuuuu.", "uuuuuuu", "..us...", "...s...", "...s...", "ddddddd"];
        } else if (k == Is.B_ARENA) {
            pal = { "a" => 0xFF9A5A, "w" => 0xE0C89A, "k" => 0x8A6A4A };
            rows = ["a.a.a.a", "wwwwwww", "w.....w", "w..k..w", "w.....w", "wwwwwww"];
        } else if (k == Is.B_FESTIVAL) {
            pal = { "r" => 0xFF6FA0, "i" => 0xFFE7C0, "y" => 0xFFD24A };
            rows = ["y.r.y.r", "iiiiiii", "i.....i", "i..y..i", "i.....i", "iiiiiii"];
        } else if (k == Is.B_RESORT) {
            pal = { "w" => 0xB46CFF, "c" => 0xF0DCC0, "b" => 0x5AC0E0 };
            rows = ["wwwwwww", "c.w.w.c", "ccccccc", "c.w.w.c", "ccccccc", ".bbbbb."];
        } else if (k == Is.B_TEMPLE) {
            pal = { "g" => 0xE0C24A, "s" => 0xCFC7B0, "d" => 0x8A7A4A };
            rows = ["..ggg..", ".ggggg.", "ggggggg", "s.s.s.s", "s.sds.s", "sssssss"];
        } else if (k == Is.B_CRYSTAL) {
            pal = { "c" => 0x8CE0FF, "w" => 0xFFFFFF, "b" => 0x5A7A9A };
            rows = ["...w...", "..ccc..", ".ccwcc.", "..ccc..", "..bbb..", ".bbbbb."];
        } else if (k == Is.B_DRAGON) {
            pal = { "r" => 0xFF5A5A, "y" => 0xFFE9A0, "s" => 0x9A8070 };
            rows = [".ry....", "rrr.r..", ".rrrrr.", "..rrr..", "..sss..", ".sssss."];
        } else if (k == Is.B_SKY) {
            pal = { "p" => 0xB8A0FF, "b" => 0xEAF4FA, "y" => 0xFFE9A0 };
            rows = ["..y.y..", ".ppppp.", "ppppppp", ".ppppp.", "..bbb..", ".bbbbb."];
        } else if (k == Is.B_TOWER) {
            pal = { "t" => 0xA0C8FF, "w" => 0x2A5A80, "a" => 0xFFE9A0 };
            rows = ["...a...", "..ttt..", ".twtwt.", ".ttttt.", ".twtwt.", "ttttttt"];
        } else if (k == Is.B_MILL) {
            pal = { "r" => 0x6A3A22, "w" => 0x8A6A3A, "k" => 0xC8B090, "b" => 0x5AC0E0 };
            rows = ["..rrr..", ".wwwww.", "wwwwwwb", "wwkwwwb", "wwwwwwb", "wwwwwww"];
        } else if (k == Is.B_MARINA) {
            pal = { "s" => 0xEAF6F2, "m" => 0x4AE0C8, "d" => 0x8A6A4A, "b" => 0x33AEE0 };
            rows = ["s...s..", "mm.mm..", "ddddddd", "b.b.b.b", "bbbbbbb", "bbbbbbb"];
        } else if (k == Is.B_OBELISK) {
            pal = { "y" => 0xFFE9A0, "o" => 0xFFB03A, "s" => 0xCFC7B0 };
            rows = ["...y...", "..ooo..", "..ooo..", "..ooo..", ".ooooo.", "sssssss"];
        } else if (k == Is.B_SHRINE) {
            pal = { "s" => 0x3AE0A0, "g" => 0x14504A, "w" => 0xEAF6F2 };
            rows = [".s...s.", "sssssss", ".gwwwg.", ".gwwwg.", "sssssss", "ggggggg"];
        } else {
            pal = { "v" => 0xD070FF, "w" => 0xEFE0FF, "k" => 0x2A1038 };
            rows = ["..vvv..", ".vkkkv.", "vk.w.kv", "vk...kv", ".vkkkv.", "..vvv.."];
        }
        _sprC(dc, rows, pal, cx, cy, px);
    }

    // 6x6 portrait per collectible id (0..Is.C_N-1).
    function collArt(dc, id, cx, cy, px) {
        var rows; var pal;
        var k = Is._c(id, 0, Is.C_N - 1);
        if (k == 0) {
            pal = { "f" => 0x3FA85A, "t" => 0x8A5A2A };
            rows = ["f.f.f.", ".fff..", "ffffff", "..t.t.", "..t.t.", ".tt.tt"];
        } else if (k == 1) {
            pal = { "s" => 0xFFB6C1, "w" => 0xFFF0F4 };
            rows = ["..ss..", ".swws.", "swwwws", "swswws", ".ssss.", "..ss.."];
        } else if (k == 2) {
            pal = { "t" => 0xC9A24A, "d" => 0x6A3A22, "i" => 0xFFE0A0 };
            rows = ["dttttd", "tiitit", "tttttt", "titiit", "tttttt", ".dttd."];
        } else if (k == 3) {
            pal = { "y" => 0xFFD24A, "w" => 0xFFF6C8, "t" => 0x8A5A2A };
            rows = ["..yy..", ".ywwy.", "yywwyy", ".yyyy.", "..tt..", "..tt.."];
        } else if (k == 4) {
            pal = { "c" => 0xFF7FA0, "o" => 0xFF9A5A, "p" => 0xB46CFF };
            rows = ["c...p.", "c.o.p.", "cco.pp", ".coopp", "..cop.", "..cc.."];
        } else if (k == 5) {
            pal = { "c" => 0x8CE0FF, "w" => 0xEAFBFF, "b" => 0x5A7A9A };
            rows = ["bccccb", "bcwwcb", "bcwwcb", ".cwwc.", ".cwwc.", "..ww.."];
        } else if (k == 6) {
            pal = { "s" => 0x9FB0C0, "k" => 0x6E7680 };
            rows = [".ssss.", "sksksk", "ssssss", ".ssss.", ".ssss.", "kssssk"];
        } else if (k == 7) {
            pal = { "m" => 0xE0C24A, "d" => 0x8A7A4A };
            rows = ["mmmmmm", ".mddm.", ".mmmm.", ".mddm.", "mmmmmm", "dmmmmd"];
        } else if (k == 8) {
            pal = { "w" => 0x9AE0FF, "r" => 0xFF6FA0, "s" => 0xC8C0B0 };
            rows = [".r..r.", "w.ww.w", "wwwwww", ".ssss.", "ssssss", ".ssss."];
        } else if (k == 9) {
            pal = { "p" => 0xFFE0F0, "g" => 0xFFD24A };
            rows = ["p.pp.p", "gppppg", "ggpggg", ".gggg.", "..gg..", "..gg.."];
        } else if (k == 10) {
            pal = { "b" => 0xBFD8E8, "k" => 0x5A7A9A, "w" => 0xFFFFFF };
            rows = ["..kk..", ".bbbb.", "bbwwbb", "bbbbbb", ".bbbb.", "..kk.."];
        } else if (k == 11) {
            pal = { "t" => 0x2AB0A0, "w" => 0xEAF6F2, "k" => 0x14504A };
            rows = [".tttt.", "tkwwkt", "twwwwt", "tkwwkt", ".tttt.", "..kk.."];
        } else if (k == 12) {
            pal = { "v" => 0xB8A0FF, "w" => 0xFFFFFF };
            rows = ["...v..", "..vv..", ".vwv..", "vwwv..", "vvv...", ".v...."];
        } else if (k == 13) {
            pal = { "w" => 0xEAF6F2, "h" => 0xFFFFFF, "s" => 0x9FB0C0 };
            rows = ["..ww..", ".whhw.", "whhhhw", "whhhhw", ".wwww.", ".ssss."];
        } else {
            pal = { "r" => 0xFF6FA0, "y" => 0xFFD24A, "g" => 0x4CC85A };
            rows = ["..rr..", ".ryyr.", "ryyyyr", ".ryyr.", "..gg..", ".gg.g."];
        }
        _sprC(dc, rows, pal, cx, cy, px);
    }

    // 7x6 scene per discovery area id (0..Is.AR_N-1).
    function areaArt(dc, id, cx, cy, px) {
        var rows; var pal;
        var k = Is._c(id, 0, Is.AR_N - 1);
        if (k == Is.AR_JUNGLE) {
            pal = { "f" => 0x2E8C3C, "F" => 0x4CC85A, "i" => 0xC9A24A };
            rows = ["fFfFfFf", "FfFfFfF", "ff.i.ff", "f.iii.f", "f..i..f", "fffffff"];
        } else if (k == Is.AR_CAVE) {
            pal = { "k" => 0x5A4A38, "c" => 0x8CE0FF, "d" => 0x2A2018 };
            rows = ["kkkkkkk", "kddddck", "kdc.cdk", "kdc.cdk", "kddddck", "kkkkkkk"];
        } else if (k == Is.AR_VOLCANO) {
            pal = { "k" => 0x5A3A2A, "o" => 0xFF6A3A, "y" => 0xFFD24A };
            rows = ["..y.y..", "..ooo..", ".kkokk.", ".kkkkk.", "kkkokkk", "kkkkkkk"];
        } else if (k == Is.AR_WATER) {
            pal = { "b" => 0x33C0FF, "w" => 0xEAFBFF, "k" => 0x6E7680 };
            rows = ["kk.b.kk", "kk.b.kk", "k.bwb.k", "k.bwb.k", ".bwwwb.", "bbbwbbb"];
        } else if (k == Is.AR_RUINS) {
            pal = { "s" => 0xC9A24A, "d" => 0x8A7A4A, "g" => 0x2E8C3C };
            rows = ["s.s...s", "sds..ds", "sds.sds", "sdsssds", "sddddds", "ggggggg"];
        } else if (k == Is.AR_CORAL) {
            pal = { "b" => 0x2A7FA8, "c" => 0xFF7FA0, "o" => 0xFF9A5A, "p" => 0xB46CFF };
            rows = ["bbbbbbb", "bc.b.pb", "bcobopb", "bccbppb", "bcobopb", "bbbbbbb"];
        } else if (k == Is.AR_PEAK) {
            pal = { "k" => 0x5A6A8A, "w" => 0xEAF2FF, "y" => 0xFFE9A0 };
            rows = ["...y...", "..www..", ".wkkkw.", ".kkkkk.", "kkkkkkk", "kkkkkkk"];
        } else if (k == Is.AR_SUNKEN) {
            pal = { "b" => 0x2A7FA8, "s" => 0x9FB0C0, "w" => 0x8CE0FF };
            rows = ["bbbwbbb", "b.sss.b", "bsswssb", "bsswssb", "bsssssb", "bbbbbbb"];
        } else {
            pal = { "v" => 0xB46CFF, "w" => 0xEFE0FF, "k" => 0x1A1030 };
            rows = ["kk.v.kk", "k.vwv.k", "k.vwv.k", "kk.v.kk", "k..v..k", "kkkkkkk"];
        }
        _sprC(dc, rows, pal, cx, cy, px);
    }
}
