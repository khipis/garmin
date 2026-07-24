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
//   • Island   — a pixel sand+grass landmass with speckled sand texture,
//                grass tufts and scattered rock outcrops (deterministic hash
//                scatter so it never looks repetitive).
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

        var horizon = y + h * 46 / 100;
        var groundY = y + h * 62 / 100;         // grass surface: land sprites sit here
        var islandHalf = w * 42 / 100; if (islandHalf < 4) { islandHalf = 4; }

        _sky(dc, x, y, w, horizon - y, tod, phase);
        _light(dc, x, y, w, h, tod, phase);
        _birds(dc, cx, y, w, h, p, phase);
        _ocean(dc, x, horizon, w, (y + h) - horizon, tod, phase);
        if (!mini) { try { _boats(dc, m, cx, horizon, islandHalf, p, phase); } catch (e) {} }
        if (!mini) { try { _fish(dc, cx, horizon, islandHalf, phase); } catch (e) {} }
        _island(dc, cx, horizon, groundY, y + h, islandHalf, tod, phase);
        _estate(dc, m, cx, groundY, islandHalf, p, phase, mini);
        if (!mini) { try { _villagers(dc, m, cx, groundY, islandHalf, p, phase); } catch (e) {} }
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
        if (tod == 3)      { top = 0x061024; bot = 0x1C3358; }   // night
        else if (tod == 2) { top = 0x274063; bot = 0xF29A5A; }   // sunset
        else if (tod == 0) { top = 0x3A4E7C; bot = 0xF0C39A; }   // dawn
        else               { top = 0x2E86C8; bot = 0xB6E6FF; }   // day
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
        else               { glow = 0xFFF3C4; core = 0xFFD98A; }   // day
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
        if (tod == 3)      { top = 0x123A5A; bot = 0x0A2238; foam = 0x3A6A8A; hi = 0x5A8AAA; }
        else if (tod == 2) { top = 0x2A5A8C; bot = 0x1A3A5A; foam = 0xE0A070; hi = 0xF4C8A0; }
        else if (tod == 0) { top = 0x2A6A8C; bot = 0x184A6A; foam = 0xBFD8E8; hi = 0xE0F0FA; }
        else               { top = 0x2AA0C8; bot = 0x1E7FA8; foam = 0x9EE0F4; hi = 0xFFFFFF; }
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

    function _boats(dc, m, cx, horizon, islandHalf, p, phase) {
        var vis = 0;
        try { vis = m.visitors; } catch (e) { vis = 0; }
        var n = vis / 10; if (n > 3) { n = 3; }
        if (vis > 0 && n == 0) { n = 1; }
        var sail = { "m" => 0xF4F4F4, "h" => 0x8A4A2A, "f" => 0xFF6FA0 };
        var rows = ["..f..", ".mmm.", "..m..", "hhhhh"];
        for (var i = 0; i < n; i++) {
            var side = (i % 2 == 0) ? -1 : 1;
            var lane = i / 2;
            var bx = cx + side * (islandHalf * (115 + lane * 34) / 100);
            var drift = (Math.sin(phase.toFloat() * 0.05 + i * 1.7) * islandHalf / 6).toNumber();
            bx += drift;
            var by = horizon + p * 3 + lane * p * 3;
            var bob = (Math.sin(phase.toFloat() * 0.12 + i) * 1).toNumber();
            _place(dc, rows, sail, bx, by + bob, p, side < 0);
        }
    }

    // ── Island landmass (pixel dome) ─────────────────────────────────────────
    function _island(dc, cx, horizon, groundY, bottom, islandHalf, tod, phase) {
        // Width profile top->bottom (percent of islandHalf).
        var prof  = [30, 52, 70, 84, 94, 100, 98, 88, 70];
        var grass = tod == 3 ? 0x1E6E3A : 0x46B255;
        var grass2= tod == 3 ? 0x175A2E : 0x2E8C3C;
        var sand  = tod == 3 ? 0xB89A62 : 0xE9D6A0;
        var sand2 = tod == 3 ? 0x9A7E4E : 0xD8B87A;
        var top = groundY - (groundY - horizon) * 55 / 100;   // grass crest above waterline
        var span = bottom - top; if (span < 1) { span = 1; }
        var bh = span / prof.size(); if (bh < 2) { bh = 2; }
        for (var i = 0; i < prof.size(); i++) {
            var hw = islandHalf * prof[i] / 100;
            var col;
            if (i == 0)      { col = grass; }
            else if (i == 1) { col = grass2; }
            else if (i == 2) { col = sand; }
            else             { col = (i % 2 == 0) ? sand : sand2; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - hw, top + i * bh, hw * 2, bh + 1);
        }
        // A little beach foam line at the waterline.
        dc.setColor(tod == 3 ? 0x6A8AA0 : 0xF4EAC6, Graphics.COLOR_TRANSPARENT);
        var fw = islandHalf * 98 / 100;
        dc.fillRectangle(cx - fw, groundY + (bottom - groundY) * 6 / 100, fw * 2, 2);

        // Sand speckle texture — deterministic scatter, never repeats the same
        // way twice across the island's width, never flickers frame-to-frame.
        var speck = tod == 3 ? 0x8A6E3E : 0xC8AC72;
        dc.setColor(speck, Graphics.COLOR_TRANSPARENT);
        var spanW = islandHalf * 2; if (spanW < 1) { spanW = 1; }
        var spanH = span * 55 / 100; if (spanH < 1) { spanH = 1; }
        for (var s = 0; s < 16; s++) {
            var hx = _hash(s * 7 + 3) % spanW;
            var hy = top + span * 42 / 100 + _hash(s * 13 + 9) % spanH;
            dc.fillRectangle(cx - islandHalf + hx, hy, 2, 2);
        }
        // Grass tufts for a little texture up top.
        dc.setColor(tod == 3 ? 0x134A24 : 0x1E7A34, Graphics.COLOR_TRANSPARENT);
        var tuftW = islandHalf * 130 / 100; if (tuftW < 1) { tuftW = 1; }
        for (var g = 0; g < 8; g++) {
            var gx = _hash(g * 19 + 5) % tuftW;
            var gy = top + _hash(g * 29 + 1) % (bh * 2);
            dc.fillRectangle(cx - islandHalf * 65 / 100 + gx, gy, 1, 3);
        }
        // Small rock outcrops along the flanks.
        var rockCol = tod == 3 ? 0x3A4048 : 0x6E7680;
        var rockHi  = tod == 3 ? 0x4A5058 : 0x8A9098;
        var spots = [-88, -58, 55, 82];
        for (var r = 0; r < spots.size(); r++) {
            var rx = cx + islandHalf * spots[r] / 100;
            var ry = top + span * (34 + (_hash(r * 31 + 2) % 40)) / 100;
            dc.setColor(rockCol, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx, ry, 6, 4);
            dc.fillRectangle(rx - 2, ry + 2, 10, 3);
            dc.setColor(rockHi, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx, ry, 3, 1);
        }
    }

    // ── The estate: buildings/trees/decor scaled by progress ─────────────────
    function _estate(dc, m, cx, groundY, islandHalf, p, phase, mini) {
        // Zero-filled first: a partial read must never leave nulls behind for
        // the sprite passes to compare against.
        var lv = new [Is.B_N];
        for (var z = 0; z < Is.B_N; z++) { lv[z] = 0; }
        var coll = 0; var built = 0; var topHouse = -1; var housingSum = 0;
        try {
            for (var i = 0; i < Is.B_N; i++) {
                var v = m.bLevel[i];
                if (v != null && v > 0) { lv[i] = v; }
            }
            for (var hi2 = Is.B_TENT; hi2 <= Is.B_CASTLE; hi2++) {
                housingSum += lv[hi2]; if (lv[hi2] > 0) { topHouse = hi2; }
            }
            coll = m.collMask;
            built = m.totalBuildingLevels();
        } catch (e) {}

        // Empty island → cosy starter camp so the scene is never bare.
        if (built == 0) { try { _camp(dc, cx, groundY, p); } catch (e) {} return; }

        try { _skyPalace(dc, lv[Is.B_SKY], cx, groundY, islandHalf, p, phase); } catch (e) {}
        try { _riftGate(dc, lv[Is.B_RIFT], cx, groundY, islandHalf, p, phase); } catch (e) {}
        try { _landmarks(dc, lv, cx, groundY, islandHalf, p, phase); } catch (e) {}
        try { _mythic(dc, lv, cx, groundY, islandHalf, p, phase); } catch (e) {}
        try { _housingCluster(dc, topHouse, housingSum, cx, groundY, islandHalf, p); } catch (e) {}
        try { _skyTower(dc, lv[Is.B_TOWER], cx, groundY, islandHalf, p); } catch (e) {}
        try { _natureFeatures(dc, lv, cx, groundY, islandHalf, p, phase); } catch (e) {}
        try { _funFeatures(dc, lv, cx, groundY, islandHalf, p, phase); } catch (e) {}
        try { _decor(dc, coll, cx, groundY, islandHalf, p, phase); } catch (e) {}
    }

    // Floating Sky Palace — drawn first, high in the sky behind everything.
    function _skyPalace(dc, lvSky, cx, groundY, islandHalf, p, phase) {
        if (lvSky <= 0) { return; }
        var palRows = ["..p.p..", ".ppppp.", "ppppppp", ".ppppp.", "..bbb..", "..bbb.."];
        var palPal = { "p" => 0xB8A0FF, "b" => 0xEAF4FA };
        var flo = (Math.sin(phase.toFloat() * 0.06) * p).toNumber();
        _place(dc, palRows, palPal, cx - islandHalf * 32 / 100, groundY - p * 8 + flo, _scaleP(p, lvSky), false);
    }

    // Rift Gate — a torn portal hanging opposite the Sky Palace, pulsing.
    function _riftGate(dc, lvRift, cx, groundY, islandHalf, p, phase) {
        if (lvRift <= 0) { return; }
        var rows = [".vvv.", "vv.vv", "v...v", "vv.vv", ".vvv."];
        var pal = { "v" => ((phase / 5) % 2 == 0) ? 0xD070FF : 0x9A4ADF };
        var flo = (Math.sin(phase.toFloat() * 0.05 + 2) * p).toNumber();
        _place(dc, rows, pal, cx + islandHalf * 34 / 100, groundY - p * 9 + flo, _scaleP(p, lvRift), false);
    }

    // MYTHIC ground structures — the reward for the late discovery areas.
    function _mythic(dc, lv, cx, groundY, islandHalf, p, phase) {
        var ob = lv[Is.B_OBELISK]; var sh = lv[Is.B_SHRINE];
        if (ob > 0) {
            var oRows = ["..y..", ".ooo.", ".ooo.", ".ooo.", ".ooo.", "ooooo"];
            var oPal = { "y" => 0xFFE9A0, "o" => 0xFFB03A };
            _place(dc, oRows, oPal, cx + islandHalf * 46 / 100, groundY, _scaleP(p, ob), false);
        }
        if (sh > 0) {
            var sRows = [".s.s.", "sssss", ".ggg.", ".ggg.", "sssss"];
            var sPal = { "s" => 0x3AE0A0, "g" => 0x14504A };
            _place(dc, sRows, sPal, cx - islandHalf * 40 / 100, groundY + p * 2, _scaleP(p, sh), false);
        }
    }

    // Sky Tower — a slim high-rise that visibly out-tops the housing skyline.
    function _skyTower(dc, lvTower, cx, groundY, islandHalf, p) {
        if (lvTower <= 0) { return; }
        var rows = ["..a..", ".ttt.", "twtwt", "ttttt", "twtwt", "ttttt", "twtwt", "ttttt"];
        var pal = { "t" => 0xA0C8FF, "w" => 0x2A5A80, "a" => 0xFFE9A0 };
        _place(dc, rows, pal, cx - islandHalf * 70 / 100, groundY, _scaleP(p, lvTower), false);
    }

    // SPECIAL landmarks around the centre-back.
    function _landmarks(dc, lv, cx, groundY, islandHalf, p, phase) {
        var lvTemple = lv[Is.B_TEMPLE]; var lvCrystal = lv[Is.B_CRYSTAL];
        var lvDragon = lv[Is.B_DRAGON];
        if (lvTemple > 0) {
            var tRows = ["..ggg..", ".ggggg.", "ggggggg", ".s.s.s.", ".s.s.s.", ".sssss.", "sssssss"];
            var tPal = { "g" => 0xE0C24A, "s" => 0xCFC7B0 };
            _place(dc, tRows, tPal, cx + islandHalf * 6 / 100, groundY, _scaleP(p, lvTemple), false);
        }
        if (lvCrystal > 0) {
            var cRows = ["..c..", ".ccc.", ".ccc.", "ccccc", ".ccc.", ".bbb.", ".bbb.", "bbbbb"];
            var cPal = { "c" => 0x8CE0FF, "b" => 0x5A7A9A };
            var cxp = cx - islandHalf * 14 / 100;
            _place(dc, cRows, cPal, cxp, groundY, _scaleP(p, lvCrystal), false);
            // Sparkle at the tip.
            if ((phase / 4) % 3 == 0) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                var sp = _scaleP(p, lvCrystal);
                dc.fillRectangle(cxp - 1, groundY - sp * 8 - 2, 3, 3);
            }
        }
        if (lvDragon > 0) {
            var dRows = [".r...", "rr.r.", ".rrrr", "..rr.", ".sss.", "sssss"];
            var dPal = { "r" => 0xFF5A5A, "s" => 0x9A8070 };
            _place(dc, dRows, dPal, cx + islandHalf * 30 / 100, groundY, p, false);
        }
    }

    // Housing skyline: descending tiers give an at-a-glance sense of scale —
    // the grandest built home leads, then a visibly different tier each slot.
    function _housingCluster(dc, topHouse, housingSum, cx, groundY, islandHalf, p) {
        if (topHouse < 0) { return; }
        var nHouse = housingSum; if (nHouse > 4) { nHouse = 4; }
        if (nHouse < 1) { nHouse = 1; }
        for (var hI = 0; hI < nHouse; hI++) {
            var tier = topHouse - hI; if (tier < 0) { tier = 0; } if (tier > 3) { tier = 3; }
            var hx = cx - islandHalf * (54 - hI * 20) / 100;
            var bob = (hI % 2) * p / 2;
            _houseTier(dc, tier, hx, groundY + bob, p);
        }
    }
    function _houseTier(dc, tier, hx, gy, p) {
        if (tier >= 3) {
            var kRows = ["k.k.k.k", "kkkkkkk", "kwwgwwk", "kwwwwwk", "kwgwgwk", "kwwdwwk", "kwwdwwk"];
            var kPal = { "k" => 0x8A8478, "w" => 0xC8C0B0, "g" => 0x6FC0E0, "d" => 0x4A3A2A };
            _place(dc, kRows, kPal, hx, gy, p, false);
        } else if (tier == 2) {
            var vRows = ["..hhhh..", ".hhhhhh.", "hhhhhhhh", "wwggwgww", "wwwwwwww", "wwddwwww"];
            var vPal = { "h" => 0xFFD27A, "w" => 0xF0DCA8, "g" => 0x8CE0FF, "d" => 0x6A3A22 };
            _place(dc, vRows, vPal, hx, gy, p, false);
        } else if (tier == 1) {
            var oRows = ["..hh..", ".hhhh.", "hhhhhh", "wwggww", "wwwwww", "wwddww"];
            var oPal = { "h" => 0xC24A3A, "w" => 0xF0DCA8, "g" => 0x8CE0FF, "d" => 0x6A3A22 };
            _place(dc, oRows, oPal, hx, gy, p, false);
        } else {
            var uRows = ["..t..", ".ttt.", "ttdtt", "t.d.t"];
            var uPal = { "t" => 0xC98A5A, "d" => 0x6A3A22 };
            _place(dc, uRows, uPal, hx, gy, p, false);
        }
    }

    // NATURE: Forest thickens the tree line, Garden adds crop rows, Lake adds
    // a reflective pond, Mountain Trail adds a stone path — each is its own
    // distinct feature, not just "more trees".
    function _natureFeatures(dc, lv, cx, groundY, islandHalf, p, phase) {
        var forest = lv[Is.B_FOREST]; var garden = lv[Is.B_GARDEN];
        var lake = lv[Is.B_LAKE]; var trail = lv[Is.B_TRAIL];
        var natureSum = forest + garden + lake + trail;

        var nTree = 1; if (natureSum > 0) { nTree = 1 + natureSum; } if (nTree > 5) { nTree = 5; }
        var palmVariants = [
            ["f.f.f", ".fff.", "fffff", "..t..", "..t.."],
            [".f.f.", "ffff.", ".fff.", "..t..", "..t..", "..t.."],
            ["f...f", ".fff.", "fffff", "...t.", "...t."]
        ];
        var palmPal = { "f" => 0x3FA85A, "t" => 0x8A5A2A };
        for (var pI = 0; pI < nTree; pI++) {
            var variant = palmVariants[_hash(pI * 17 + 5) % palmVariants.size()];
            var flip = (_hash(pI * 23 + 1) % 2) == 0;
            var px2 = cx + islandHalf * (34 + pI * 14) / 100;
            var sway = (Math.sin(phase.toFloat() * 0.08 + pI) * 1).toNumber();
            _place(dc, variant, palmPal, px2 + sway, groundY + (pI % 2) * p, p, flip);
        }

        if (garden > 0) {
            var gRows = ["g.g.g", ".g.g.", "g.g.g"];
            var gPal = { "g" => 0x8CD060 };
            _place(dc, gRows, gPal, cx - islandHalf * 20 / 100, groundY + p * 3, p, false);
        }
        if (lake > 0) {
            var lRows = [".lll.", "lllll", ".lll."];
            var lPal = { "l" => 0x5AC0E0 };
            var lx = cx - islandHalf * 2 / 100;
            _place(dc, lRows, lPal, lx, groundY + p * 4, p, false);
            if ((phase / 5) % 2 == 0) {
                dc.setColor(0xEAFBFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(lx - 1, groundY + p * 4 - p, 2, 1);
            }
        }
        if (trail > 0) {
            dc.setColor(0xB0A48C, Graphics.COLOR_TRANSPARENT);
            for (var s = 0; s < 4; s++) {
                dc.fillRectangle(cx + islandHalf * 12 / 100 + s * p, groundY + p * (2 + (s % 2)), p - 1, p - 1);
            }
        }
        if (lv[Is.B_MILL] > 0) {                 // Timber Mill — sawhouse + wheel
            var mRows = ["..r..", ".rrr.", "wwwww", "w.k.w", "wwwww"];
            var mPal = { "r" => 0x6A3A22, "w" => 0x8A6A3A, "k" => 0xC8B090 };
            _place(dc, mRows, mPal, cx - islandHalf * 56 / 100, groundY + p * 3,
                   _scaleP(p, lv[Is.B_MILL]), false);
        }
    }

    // ENTERTAINMENT: each building type gets its own silhouette.
    function _funFeatures(dc, lv, cx, groundY, islandHalf, p, phase) {
        var beach = lv[Is.B_BEACH]; var arena = lv[Is.B_ARENA];
        var fest = lv[Is.B_FESTIVAL]; var resort = lv[Is.B_RESORT];

        if (beach > 0) {
            var parRows = ["uuuuu", ".uuu.", "..s..", "..s..", "..s.."];
            var parPal = { "u" => 0xFF6FA0, "s" => 0xC8B090 };
            _place(dc, parRows, parPal, cx - islandHalf * 6 / 100, groundY + p * 3, _scaleP(p, beach), false);
        }
        if (arena > 0) {
            var aRows = ["aaaaaaa", "a.....a", "a.....a", "aaaaaaa"];
            var aPal = { "a" => 0xE0C89A };
            _place(dc, aRows, aPal, cx + islandHalf * 10 / 100, groundY + p * 3, _scaleP(p, arena), false);
        }
        if (fest > 0) {
            var fRows = ["r.r.r", "iiiii", "i...i", "i...i"];
            var fPal = { "r" => 0xFF6FA0, "i" => 0xFFE7C0 };
            _place(dc, fRows, fPal, cx - islandHalf * 18 / 100, groundY + p * 4, _scaleP(p, fest), false);
        }
        if (resort > 0) {
            var rRows = ["wwwwwww", "w.....w", "wwwwwww", ".bbbbb."];
            var rPal = { "w" => 0xF0DCC0, "b" => 0x5AC0E0 };
            _place(dc, rRows, rPal, cx + islandHalf * 22 / 100, groundY + p * 4, _scaleP(p, resort), false);
        }
        if (lv[Is.B_MARINA] > 0) {               // Grand Marina — jetty + moored yachts
            var yRows = ["s...s", "mm.mm", "ddddd", "..d.."];
            var yPal = { "s" => 0xEAF6F2, "m" => 0x4AE0C8, "d" => 0x8A6A4A };
            _place(dc, yRows, yPal, cx + islandHalf * 62 / 100, groundY + p * 6,
                   _scaleP(p, lv[Is.B_MARINA]), false);
        }
    }

    // Collection decorations — the original nine each have their own distinct
    // pixel sprite/effect; ids appended after them share a generic pedestal.
    function _decor(dc, coll, cx, groundY, islandHalf, p, phase) {
        if ((coll & (1 << 0)) != 0) {   // Palm Grove
            var pgRows = ["f.f", ".f.", "t.t"];
            var pgPal = { "f" => 0x3FA85A, "t" => 0x8A5A2A };
            _place(dc, pgRows, pgPal, cx - islandHalf * 62 / 100, groundY + p * 2, p, false);
        }
        if ((coll & (1 << 1)) != 0) {   // Seashell Set
            var shx = cx - islandHalf * 46 / 100;
            dc.setColor(0xFFD9E8, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(shx, groundY + p * 4, 3, 2);
            dc.setColor(0xFFC8DC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(shx + 4, groundY + p * 4 + 1, 2, 2);
        }
        if ((coll & (1 << 2)) != 0) {   // Tiki Totem
            var kRows = ["ttt", "tit", "ttt", "ttt"];
            var kPal = { "t" => 0x8A5A2A, "i" => 0xFFE0A0 };
            _place(dc, kRows, kPal, cx + islandHalf * 50 / 100, groundY + p, p, false);
        }
        if ((coll & (1 << 3)) != 0) {   // Golden Tree
            var gRows = ["..y..", ".yyy.", "yyyyy", ".yyy.", "..t..", "..t.."];
            var gPal = { "y" => 0xFFD24A, "t" => 0x8A5A2A };
            _place(dc, gRows, gPal, cx - islandHalf * 34 / 100, groundY + p, p, false);
        }
        if ((coll & (1 << 4)) != 0) {   // Coral Reef — colourful patch at the waterline.
            var crRows = ["c.o.p", "ccopo", ".oco."];
            var crPal = { "c" => 0xFF7FA0, "o" => 0xFF9A5A, "p" => 0xB46CFF };
            _place(dc, crRows, crPal, cx - islandHalf * 92 / 100, groundY + p * 6, p, false);
        }
        if ((coll & (1 << 5)) != 0) {   // Crystal Waterfall — trickling near the tower's cliff.
            var wfx = cx - islandHalf * 22 / 100;
            dc.setColor(0x8CE0FF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(wfx, groundY - p * 6, 3, p * 6);
            if ((phase / 4) % 2 == 0) {
                dc.setColor(0xEAFBFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(wfx, groundY + p, 3, 2);
            }
        }
        if ((coll & (1 << 6)) != 0) {   // Stone Idol
            var sRows = [".s.", "sss", ".s.", "sss"];
            var sPal = { "s" => 0x9A968C };
            _place(dc, sRows, sPal, cx + islandHalf * 66 / 100, groundY + p, p, false);
        }
        if ((coll & (1 << 7)) != 0) {   // Ancient Monument
            var mRows = ["mmmmm", ".mmm.", "mmmmm"];
            var mPal = { "m" => 0xE0C24A };
            _place(dc, mRows, mPal, cx + islandHalf * 76 / 100, groundY + p * 2, p, false);
        }
        if ((coll & (1 << 8)) != 0) {   // Rainbow Fountain
            var fRows = [".w.w.", "wwwww", ".sss.", "sssss"];
            var fPal = { "w" => 0x8CE0FF, "s" => 0xC8C0B0 };
            var fx = cx + islandHalf * 2 / 100;
            _place(dc, fRows, fPal, fx, groundY + p * 2, p, false);
            if ((phase / 3) % 2 == 0) {
                dc.setColor(0xEAFBFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(fx - 1, groundY + p * 2 - p * 5, 2, 2);
            }
        }
        // Every collectible appended past the nine hand-drawn ones gets a
        // generic gem pedestal tinted with its own palette colour, fanned along
        // the shore — new ids always place something instead of nothing.
        for (var ci = 9; ci < Is.C_N; ci++) {
            if ((coll & (1 << ci)) == 0) { continue; }
            var k = ci - 9;
            var gemRows = [".g.", "ggg", ".g.", ".b."];
            var gemPal = { "g" => Is.cColor(ci), "b" => 0x8A8478 };
            _place(dc, gemRows, gemPal, cx + islandHalf * (-84 + k * 28) / 100,
                   groundY + p * 5, p, (k % 2) == 1);
        }
    }

    // ── Villagers wandering the grass ─────────────────────────────────────────
    // Varied sprite silhouettes, varied stride speed & varied flip cadence so
    // the crowd never looks like clones marching in lockstep.
    function _villagers(dc, m, cx, groundY, islandHalf, p, phase) {
        var pop = 0;
        try { pop = m.population; } catch (e) { pop = 0; }
        var n = pop; if (n > 7) { n = 7; }
        var shirts = [0x37D0C0, 0xFFC24A, 0xFF6FA0, 0x6FB3FF, 0xB46CFF, 0x6FE08A, 0xFF9A5A];
        var vp = p * 6 / 10; if (vp < 2) { vp = 2; }
        var variants = [
            [".H.", "SSS", ".S.", "L.L"],
            [".HH", "SSS", ".S.", "L.L"],
            [".H.", ".SS", ".S.", ".L."]
        ];
        for (var i = 0; i < n; i++) {
            var rows = variants[_hash(i * 29 + 3) % variants.size()];
            var pal = { "H" => 0xF0C090, "S" => shirts[i % shirts.size()], "L" => 0x3A4A6A };
            var range = islandHalf * 80 / 100;
            var speedMil = 20 + (_hash(i * 11 + 7) % 30);
            var wx = cx + (Math.sin(phase.toFloat() * (0.02 + speedMil.toFloat() * 0.001) + i * 1.9) * range).toNumber() / 2
                     - islandHalf * 10 / 100;
            var wy = groundY + p * 3 + (i % 3) * vp;
            var flipEvery = 6 + (i % 4);
            _place(dc, rows, pal, wx, wy, vp, ((phase / flipEvery + i) % 2 == 0));
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
}
