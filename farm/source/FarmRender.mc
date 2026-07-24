// ═══════════════════════════════════════════════════════════════════════════
// FarmRender.mc — CHUNKY PIXEL-ART view of YOUR FARM (module `FarmArt`).
//
// The star of the HOME screen: a cosy, layered pixel diorama of the player's
// whole homestead that visibly grows richer as they progress.
//
//   • Sky     — day/sunset/night/dawn gradient by time-of-day, sun or moon,
//               drifting puffy clouds, twinkling stars at night, birds.
//   • Land    — rolling green pastures with speckled grass, wildflowers, a dirt
//               path and a rustic perimeter fence.
//   • Farm    — every structure tier gets its OWN distinct pixel sprite: a red
//               Cow Barn, Chicken Coop, Duck Pond, Pig Pen for Livestock; Wheat
//               rows, a Carrot Patch, an Orchard and Berry Bushes for Crops; a
//               Farm Stand, spinning Windmill, Bakery and Petting Zoo for the
//               Market; and the SPECIAL landmarks appear once explored — a
//               gleaming Golden Barn, glass Greenhouse, Prize Bull statue and a
//               towering Rainbow Silo. LATE GAME adds sunflowers, a Creamery,
//               an Alpaca pen, the Cider Mill, a silver Moonlit Barn and the
//               Harvest Moon itself hanging over the ridge.
//   • Life    — cute animals (chickens, ducks, pigs, cows, alpacas) wander the
//               field, their species matching what you've built, count ~ herd.
//   • Decor   — the first 9 collectibles each have their OWN pixel charm; every
//               later charm gets a compact generic trinket in its own colour,
//               so new collectibles always show up in the world.
//
// Everything is drawn from cheap primitive fills, contained in a box, scales to
// any watch, and is fully guarded — the master render is wrapped in try/catch
// (drawBox) and every major sub-feature is ALSO individually guarded.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Time;
using Toybox.Time.Gregorian;

module FarmArt {

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

        var horizon = y + h * 44 / 100;         // where sky meets the far hills
        var groundY = y + h * 66 / 100;          // foreground ground line: sprites sit here
        var fieldHalf = w * 46 / 100;

        _sky(dc, x, y, w, horizon - y, tod, phase);
        _light(dc, x, y, w, h, tod, phase);
        if (!mini) { try { _clouds(dc, x, y, w, h, tod, phase); } catch (e) {} }
        _birds(dc, cx, y, w, h, p, phase);
        _hills(dc, x, horizon, w, (y + h) - horizon, tod, phase);
        _pasture(dc, x, horizon, groundY, y + h, w, tod, phase);
        if (!mini) { try { _fence(dc, cx, groundY, fieldHalf, p); } catch (e) {} }
        _estate(dc, m, cx, groundY, fieldHalf, p, phase, mini);
        if (!mini) { try { _animals(dc, m, cx, groundY, fieldHalf, p, phase); } catch (e) {} }
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
        if (tod == 3)      { top = 0x0A1430; bot = 0x24406A; }   // night
        else if (tod == 2) { top = 0x3A4E78; bot = 0xF6B26A; }   // sunset
        else if (tod == 0) { top = 0x4A5E8C; bot = 0xF6D0A6; }   // dawn
        else               { top = 0x4FA8E0; bot = 0xC6ECFF; }   // day
        Px.vgrad(dc, x, y, w, h, top, bot, 14);
        if (tod == 3) { _stars(dc, x, y, w, h, phase); }
    }

    function _stars(dc, x, y, w, h, phase) {
        dc.setColor(0xEAF2FF, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            var sx = x + ((i * 37 + 11) % 100) * w / 100;
            var sy = y + ((i * 53 + 7) % 70) * h / 100;
            if (((phase / 6) + i) % 5 == 0) { continue; }
            dc.fillRectangle(sx, sy, 2, 2);
        }
    }

    // ── Sun / Moon ──────────────────────────────────────────────────────────
    function _light(dc, x, y, w, h, tod, phase) {
        var lx = x + w * 74 / 100;
        var ly = y + h * 13 / 100;
        var rr = w / 16; if (rr < 5) { rr = 5; }
        if (tod == 3) {                              // moon
            dc.setColor(0xF0F4FA, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lx, ly, rr);
            dc.setColor(0x24406A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lx + rr / 2, ly - rr / 3, rr * 8 / 10);
            return;
        }
        var glow; var core;
        if (tod == 2)      { glow = 0xFFCB8A; core = 0xFF9A5A; }
        else if (tod == 0) { glow = 0xFFE7C0; core = 0xFFC98A; }
        else               { glow = 0xFFF3C4; core = 0xFFD54A; }
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

    // Soft puffy clouds drifting across the sky.
    function _clouds(dc, x, y, w, h, tod, phase) {
        var col = (tod == 3) ? 0x2A3A5A : 0xF4FAFF;
        var rows = [".ccc.", "ccccc", "ccccc"];
        var pal = { "c" => col };
        var span = w * 120 / 100;
        for (var i = 0; i < 2; i++) {
            var cxp = x - w * 10 / 100 + ((phase / 8 + i * 90) % span);
            var cyp = y + h * (10 + i * 12) / 100;
            var cp = w / 30; if (cp < 2) { cp = 2; }
            Px.spr(dc, rows, pal, cxp, cyp, cp, false);
        }
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

    // ── Far rolling hills behind the farm ─────────────────────────────────────
    function _hills(dc, x, horizon, w, h, tod, phase) {
        var far  = tod == 3 ? 0x1C4A2A : 0x6FC46A;
        var far2 = tod == 3 ? 0x164024 : 0x5BB25A;
        // Two overlapping hill bands.
        dc.setColor(far, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            var hw = w * 30 / 100;
            var hx = x - w * 5 / 100 + i * w * 24 / 100;
            var hy = horizon - h * 6 / 100;
            dc.fillCircle(hx, hy + h * 8 / 100, hw / 2);
        }
        dc.setColor(far2, Graphics.COLOR_TRANSPARENT);
        for (var j = 0; j < 6; j++) {
            var hw2 = w * 24 / 100;
            var hx2 = x + j * w * 20 / 100;
            dc.fillCircle(hx2, horizon + h * 3 / 100, hw2 / 2);
        }
    }

    // ── Foreground pasture ─────────────────────────────────────────────────
    function _pasture(dc, x, horizon, groundY, bottom, w, tod, phase) {
        var g1 = tod == 3 ? 0x235A2E : 0x5BB84E;   // near grass
        var g2 = tod == 3 ? 0x1C4A26 : 0x4BA23F;
        var soil= tod == 3 ? 0x5A3A22 : 0x8A5A34;
        // Grass fill from the horizon down.
        Px.vgrad(dc, x, horizon, w, bottom - horizon, g2, g1, 10);

        // A slim, gently winding dirt path down the middle.
        var soilHi = tod == 3 ? 0x6E4A2E : 0xA6764A;
        var cxp = x + w / 2;
        var steps = 9;
        for (var s = 0; s < steps; s++) {
            var py = horizon + (bottom - horizon) * s / steps;
            var pw = w * (5 + s) / 100;               // slim trail, widens softly
            var wob = (Math.sin(s.toFloat() * 0.7) * w * 7 / 100).toNumber();
            var seg = (bottom - horizon) / steps + 2;
            dc.setColor(soil, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cxp - pw / 2 + wob, py, pw, seg);
            dc.setColor(soilHi, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cxp - pw / 2 + wob, py, 2, seg);
        }

        // Wildflowers scattered across the field.
        var fl = [0xFFFFFF, 0xFFE24A, 0xFF7FA0, 0xB46CFF];
        for (var f = 0; f < 12; f++) {
            var fx = x + _hash(f * 19 + 5) % w;
            var fy = horizon + (bottom - horizon) * (18 + _hash(f * 29 + 1) % 78) / 100;
            dc.setColor(tod == 3 ? 0x2E6E38 : 0x3E8E36, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx, fy, 1, 3);
            dc.setColor(fl[_hash(f * 31 + 2) % fl.size()], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx - 1, fy - 1, 2, 2);
        }
    }

    // ── Rustic perimeter fence ────────────────────────────────────────────────
    function _fence(dc, cx, groundY, fieldHalf, p) {
        var col = 0xC8A06A; var colHi = 0xE0BE86;
        var fy = groundY - p * 2;
        var n = 7;
        for (var i = 0; i <= n; i++) {
            var fx = cx - fieldHalf * 96 / 100 + fieldHalf * 192 / 100 * i / n;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx, fy, p < 3 ? 2 : 3, p * 4);
            dc.setColor(colHi, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(fx, fy, p < 3 ? 2 : 3, 1);
        }
        // Two horizontal rails.
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - fieldHalf * 96 / 100, fy + p, fieldHalf * 192 / 100, 2);
        dc.fillRectangle(cx - fieldHalf * 96 / 100, fy + p * 3, fieldHalf * 192 / 100, 2);
    }

    // ── The homestead: structures scaled by progress ──────────────────────────
    function _estate(dc, m, cx, groundY, fieldHalf, p, phase, mini) {
        var lv = new [Fa.B_N];
        var coll = 0; var built = 0;
        // Zeroed first: a half-filled level array must never leave nulls behind.
        for (var z = 0; z < Fa.B_N; z++) { lv[z] = 0; }
        try {
            for (var i = 0; i < Fa.B_N; i++) { lv[i] = m.bLevel[i]; }
            coll = m.collMask;
            built = m.totalBuildingLevels();
        } catch (e) {}

        // Empty farm → cosy starter paddock so the scene is never bare.
        if (built == 0) { try { _starter(dc, cx, groundY, p); } catch (e) {} return; }

        try { _lateBack(dc, lv, cx, groundY, fieldHalf, p, phase); } catch (e) {}
        try { _silo(dc, lv[Fa.B_SILO], cx, groundY, fieldHalf, p, phase); } catch (e) {}
        try { _specials(dc, lv, cx, groundY, fieldHalf, p, phase); } catch (e) {}
        try { _crops(dc, lv, cx, groundY, fieldHalf, p, phase); } catch (e) {}
        try { _livestockPens(dc, lv, cx, groundY, fieldHalf, p); } catch (e) {}
        try { _market(dc, lv, cx, groundY, fieldHalf, p, phase); } catch (e) {}
        try { _lateFront(dc, lv, cx, groundY, fieldHalf, p, phase); } catch (e) {}
        try { _decor(dc, coll, cx, groundY, fieldHalf, p, phase); } catch (e) {}
        try { _decorExtra(dc, coll, cx, groundY, fieldHalf, p); } catch (e) {}
    }

    // ── LATE-GAME structures ─────────────────────────────────────────────────
    // Back row: the Harvest Moon hanging over the ridge, the silver Moonlit Barn
    // and the Cider Mill.
    function _lateBack(dc, lv, cx, groundY, fieldHalf, p, phase) {
        var moon = lv[Fa.B_HARVMOON];
        if (moon > 0) {
            var mr = p * 2 + moon; if (mr > p * 6) { mr = p * 6; }
            var mx = cx - fieldHalf * 60 / 100;
            var my = groundY - p * 13;
            dc.setColor(0xF0C860, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx, my, mr + 2);
            dc.setColor(0xFFF3C4, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx, my, mr);
            dc.setColor(0xF0D890, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx + mr / 3, my - mr / 3, mr / 4);
        }
        var barn = lv[Fa.B_MOONBARN];
        if (barn > 0) {
            var rows = [".sssss.", "sssssss", "bwbbbwb", "bbbdbbb", "bbbdbbb"];
            var pal = { "s" => 0x6A7AB0, "b" => 0x9AB0FF, "w" => 0xEAF0FF, "d" => 0x3A4A7A };
            _place(dc, rows, pal, cx - fieldHalf * 70 / 100, groundY + p, _scaleP(p, barn), false);
        }
        var cider = lv[Fa.B_CIDER];
        if (cider > 0) {
            var rows2 = ["..r..", "rrrrr", "cwcwc", "ccdcc"];
            var pal2 = { "r" => 0x8A3A2A, "c" => 0xC86A3A, "w" => 0xFFD8A0, "d" => 0x5A2A1A };
            var bx = cx + fieldHalf * 62 / 100;
            _place(dc, rows2, pal2, bx, groundY + p * 2, _scaleP(p, cider), false);
            dc.setColor(0x8A5A3A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx + p * 2, groundY + p, p * 2, p * 2);
        }
    }

    // Front row: Sunflowers, the Creamery and the Alpaca pen.
    function _lateFront(dc, lv, cx, groundY, fieldHalf, p, phase) {
        var sun = lv[Fa.B_SUNFLR];
        if (sun > 0) {
            var n = 3 + sun / 2; if (n > 5) { n = 5; }
            var sway = (Math.sin(phase.toFloat() * 0.06) * 1).toNumber();
            for (var i = 0; i < n; i++) {
                var sx = cx - fieldHalf * 58 / 100 + i * p * 3 + sway;
                var sy = groundY + p * 5;
                dc.setColor(0x3E8E36, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(sx, sy - p * 4, 2, p * 4);
                dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(sx + 1, sy - p * 4, p);
                dc.setColor(0x8A5A1A, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(sx + 1, sy - p * 4, p / 3);
            }
        }
        var cream = lv[Fa.B_CREAMRY];
        if (cream > 0) {
            var rows = ["..b..", "bbbbb", "wwdww", "wwdww"];
            var pal = { "b" => 0x6FA8D0, "w" => 0xEAF2F0, "d" => 0x8A9AA0 };
            _place(dc, rows, pal, cx - fieldHalf * 26 / 100, groundY + p * 6, _scaleP(p, cream), false);
        }
        var alp = lv[Fa.B_ALPACA];
        if (alp > 0) {
            var ax = cx + fieldHalf * 28 / 100;
            var ay = groundY + p * 7;
            dc.setColor(0xC8A06A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ax - p * 3, ay - 1, p * 6, 2);
            var rows2 = [".ff", "fff", "ff.", "l.l"];
            var pal2 = { "f" => 0xE8D8B0, "l" => 0xC0A880 };
            _place(dc, rows2, pal2, ax, ay, p, false);
        }
    }

    // Rainbow Silo — tall back structure, drawn first behind everything.
    function _silo(dc, lvSilo, cx, groundY, fieldHalf, p, phase) {
        if (lvSilo <= 0) { return; }
        var rows = ["ccc", "rrr", "ooo", "yyy", "ggg", "bbb", "www", "www"];
        var pal = { "c" => 0xC0C6CC, "r" => 0xFF6A6A, "o" => 0xFF9A4A, "y" => 0xFFD24A,
                    "g" => 0x8CD060, "b" => 0x6FB3FF, "w" => 0xE6ECEA };
        _place(dc, rows, pal, cx + fieldHalf * 40 / 100, groundY - p * 2, _scaleP(p, lvSilo), false);
    }

    // SPECIAL landmarks around the centre-back.
    function _specials(dc, lv, cx, groundY, fieldHalf, p, phase) {
        var gold = lv[Fa.B_GOLDBARN]; var green = lv[Fa.B_GREENHSE]; var bull = lv[Fa.B_PRIZEBULL];
        if (gold > 0) {   // Golden Barn
            var rows = [".ggggg.", "ggggggg", "GwGGGwG", "GGGdGGG", "GGGdGGG"];
            var pal = { "g" => 0xE0A82A, "G" => 0xFFD24A, "w" => 0xFFF0B0, "d" => 0x8A5A1A };
            _place(dc, rows, pal, cx - fieldHalf * 30 / 100, groundY, _scaleP(p, gold), false);
        }
        if (green > 0) {  // Greenhouse (glass dome)
            var rows2 = ["..ggg..", ".ggggg.", "GbGbGbG", "GbGbGbG", "GGGGGGG"];
            var pal2 = { "g" => 0xBFF0D0, "G" => 0xCFEFE0, "b" => 0x6FD06A };
            _place(dc, rows2, pal2, cx - fieldHalf * 8 / 100, groundY, _scaleP(p, green), false);
            if ((phase / 4) % 3 == 0) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                var sp = _scaleP(p, green);
                dc.fillRectangle(cx - fieldHalf * 8 / 100 - sp * 2, groundY - sp * 5, 2, 2);
            }
        }
        if (bull > 0) {   // Prize Bull statue on a plinth
            var rows3 = ["h...h", "bbbbb", "bbbbb", ".b.b.", "sssss"];
            var pal3 = { "b" => 0x8A5A3A, "h" => 0xD8D0C0, "s" => 0xB0A890 };
            _place(dc, rows3, pal3, cx + fieldHalf * 20 / 100, groundY, p, false);
        }
    }

    // CROPS: Wheat rows, Carrot patch, Orchard trees, Berry bushes.
    function _crops(dc, lv, cx, groundY, fieldHalf, p, phase) {
        var wheat = lv[Fa.B_WHEAT]; var carrot = lv[Fa.B_CARROT];
        var orchard = lv[Fa.B_ORCHARD]; var berry = lv[Fa.B_BERRY];

        if (wheat > 0) {   // swaying golden wheat rows
            var sway = (Math.sin(phase.toFloat() * 0.08) * 1).toNumber();
            dc.setColor(0xE8C24A, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 6; i++) {
                var wx = cx - fieldHalf * 44 / 100 + i * p * 2;
                dc.fillRectangle(wx + sway, groundY - p * 3, p - 1, p * 3);
                dc.setColor(0xFFE07A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(wx + sway - 1, groundY - p * 3 - 1, p + 1, 2);
                dc.setColor(0xE8C24A, Graphics.COLOR_TRANSPARENT);
            }
        }
        if (carrot > 0) {   // carrot patch (green tops + orange)
            var rows = ["g.g.g", "ooooo"];
            var pal = { "g" => 0x6FD06A, "o" => 0xFF9A4A };
            _place(dc, rows, pal, cx - fieldHalf * 18 / 100, groundY + p * 2, p, false);
        }
        if (orchard > 0) {  // apple trees
            var nTree = 1 + orchard; if (nTree > 3) { nTree = 3; }
            var tRows = [".fff.", "fffff", "fffff", "..t..", "..t.."];
            var tPal = { "f" => 0x3FA85A, "t" => 0x7A4A2A };
            for (var t = 0; t < nTree; t++) {
                var tx = cx + fieldHalf * (26 + t * 16) / 100;
                _place(dc, tRows, tPal, tx, groundY + (t % 2) * p, p, false);
                // apples
                dc.setColor(0xFF5A5A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(tx - p, groundY - p * 4, 2, 2);
                dc.fillRectangle(tx + p, groundY - p * 3, 2, 2);
            }
        }
        if (berry > 0) {    // berry bushes
            var bRows = ["bgb", "ggg", "bgb"];
            var bPal = { "g" => 0x2E8C3C, "b" => 0xB46CFF };
            _place(dc, bRows, bPal, cx - fieldHalf * 4 / 100, groundY + p * 4, p, false);
        }
    }

    // LIVESTOCK: little pens/barns for each animal house.
    function _livestockPens(dc, lv, cx, groundY, fieldHalf, p) {
        var cow = lv[Fa.B_COW]; var pig = lv[Fa.B_PIG];
        var duck = lv[Fa.B_DUCK]; var coop = lv[Fa.B_COOP];

        if (cow > 0) {   // classic red barn
            var rows = [".rrrrr.", "rrrrrrr", "bwbbbwb", "bbbdbbb", "bbbdbbb"];
            var pal = { "r" => 0x8A2A2A, "b" => 0xD24A3A, "w" => 0xF0E0C0, "d" => 0x5A2A1A };
            _place(dc, rows, pal, cx - fieldHalf * 52 / 100, groundY, _scaleP(p, cow), false);
        }
        if (coop > 0) {  // small chicken coop
            var rows2 = ["..a..", ".aaa.", "cwwwc", "cwdwc"];
            var pal2 = { "a" => 0xC85A3A, "w" => 0xF0E0C0, "d" => 0x6A3A22, "c" => 0x8A5A3A };
            _place(dc, rows2, pal2, cx - fieldHalf * 34 / 100, groundY + p, p, false);
        }
        if (duck > 0) {  // duck pond
            var px = cx + fieldHalf * 6 / 100;
            dc.setColor(0x4FB0E0, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, groundY + p * 4, p * 2);
            dc.setColor(0x7FD0F0, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - 1, groundY + p * 4 - 1, p);
        }
        if (pig > 0) {   // mud pig pen (fenced mud patch)
            var mx = cx + fieldHalf * 2 / 100;
            dc.setColor(0x8A5A34, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(mx - p * 2, groundY + p * 2, p * 4, p * 2);
            dc.setColor(0xC8A06A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(mx - p * 2, groundY + p * 2, p * 4, 1);
        }
    }

    // MARKET: Farm Stand, Windmill, Bakery, Petting Zoo.
    function _market(dc, lv, cx, groundY, fieldHalf, p, phase) {
        var stand = lv[Fa.B_STAND]; var mill = lv[Fa.B_WINDMILL];
        var bakery = lv[Fa.B_BAKERY]; var zoo = lv[Fa.B_PETZOO];

        if (stand > 0) {   // striped market stall
            var rows = ["rwrwr", "wwwww", "p...p", "p...p"];
            var pal = { "r" => 0xE05A5A, "w" => 0xF4EAD0, "p" => 0x8A5A3A };
            _place(dc, rows, pal, cx + fieldHalf * 8 / 100, groundY + p * 2, _scaleP(p, stand), false);
        }
        if (mill > 0) {    // windmill with spinning blades
            var mx = cx - fieldHalf * 44 / 100;
            var my = groundY - p * 2;
            var tRows = [".www.", ".www.", ".www.", ".www."];
            var tPal = { "w" => 0xE8D8B0 };
            _place(dc, tRows, tPal, mx, my, _scaleP(p, mill), false);
            // Rotating blades (4 spokes).
            var sp = _scaleP(p, mill);
            var bl = sp * 4;
            var ang = phase.toFloat() * 0.15;
            dc.setColor(0x8A5A3A, Graphics.COLOR_TRANSPARENT);
            var hubY = my - 4 * sp;
            for (var k = 0; k < 4; k++) {
                var a = ang + k * 1.5708;
                var ex = mx + (Math.cos(a) * bl).toNumber();
                var ey = hubY + (Math.sin(a) * bl).toNumber();
                dc.drawLine(mx, hubY, ex, ey);
            }
            dc.setColor(0xF0E0C0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(mx - 1, hubY - 1, 3, 3);
        }
        if (bakery > 0) {  // bakery (chimney + smoke)
            var rows2 = ["..h..", "bbbbb", "bwbwb", "bbdbb"];
            var pal2 = { "b" => 0xC88A5A, "w" => 0xFFE7C0, "d" => 0x6A3A22, "h" => 0x8A5A3A };
            var bx = cx + fieldHalf * 34 / 100;
            _place(dc, rows2, pal2, bx, groundY + p * 3, _scaleP(p, bakery), false);
            if ((phase / 5) % 2 == 0) {
                dc.setColor(0xD8D8D8, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx + p, groundY + p * 3 - p * 6, 2, 2);
            }
        }
        if (zoo > 0) {     // petting-zoo banner
            var zx = cx + fieldHalf * 16 / 100;
            dc.setColor(0xFF7FA0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(zx - p * 2, groundY - p * 3, p * 4, p);
            dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(zx - p * 2, groundY - p * 3, 2, p * 3);
            dc.fillRectangle(zx + p * 2, groundY - p * 3, 2, p * 3);
        }
    }

    // Collection charms — each of the 9 collectibles has its own pixel sprite.
    function _decor(dc, coll, cx, groundY, fieldHalf, p, phase) {
        if ((coll & (1 << 0)) != 0) {   // Flower Bed
            var rows = ["ror", "ggg", "byb"];
            var pal = { "r" => 0xFF7FA0, "o" => 0xFFD24A, "b" => 0x6FB3FF, "y" => 0xFFE24A, "g" => 0x3E8E36 };
            _place(dc, rows, pal, cx - fieldHalf * 64 / 100, groundY + p * 3, p, false);
        }
        if ((coll & (1 << 1)) != 0) {   // Scarecrow
            var sRows = [".h.", "shs", ".s.", "sss", ".s."];
            var sPal = { "h" => 0xE8C24A, "s" => 0x8A5A3A };
            _place(dc, sRows, sPal, cx + fieldHalf * 44 / 100, groundY, p, false);
        }
        if ((coll & (1 << 2)) != 0) {   // Hay Bales
            var hRows = ["yyy", "yYy", "yyy"];
            var hPal = { "y" => 0xE8C24A, "Y" => 0xC79A2A };
            _place(dc, hRows, hPal, cx - fieldHalf * 12 / 100, groundY + p * 5, p, false);
        }
        if ((coll & (1 << 3)) != 0) {   // Golden Egg
            var eRows = [".g.", "ggg", "ggg", ".g."];
            var ePal = { "g" => 0xFFD24A };
            _place(dc, eRows, ePal, cx + fieldHalf * 58 / 100, groundY + p * 2, p, false);
        }
        if ((coll & (1 << 4)) != 0) {   // Pond Ducks
            var px = cx + fieldHalf * 6 / 100;
            dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px - 2, groundY + p * 3, 2, 2);
            dc.fillRectangle(px + 2, groundY + p * 3 + 1, 2, 2);
        }
        if ((coll & (1 << 5)) != 0) {   // Rainbow Cow
            var rcRows = ["r.r", "ggg", "obm", ".l."];
            var rcPal = { "r" => 0xFF6A6A, "g" => 0xF0F0F0, "o" => 0xFF9A4A, "b" => 0x6FB3FF, "m" => 0xB46CFF, "l" => 0x5A3A2A };
            _place(dc, rcRows, rcPal, cx + fieldHalf * 30 / 100, groundY + p * 4, p, false);
        }
        if ((coll & (1 << 6)) != 0) {   // Wishing Well
            var wRows = [".r.", "rrr", "sws", "sss"];
            var wPal = { "r" => 0x8A2A2A, "s" => 0x9A968C, "w" => 0x6FD0E0 };
            _place(dc, wRows, wPal, cx - fieldHalf * 40 / 100, groundY + p * 3, p, false);
        }
        if ((coll & (1 << 7)) != 0) {   // Prize Ribbon
            var pRows = [".y.", "yyy", ".y.", "b.b"];
            var pPal = { "y" => 0xFFD24A, "b" => 0x6FB3FF };
            _place(dc, pRows, pPal, cx + fieldHalf * 68 / 100, groundY + p, p, false);
        }
        if ((coll & (1 << 8)) != 0) {   // Harvest Feast (table)
            var tRows = ["ror", "www", "b.b"];
            var tPal = { "r" => 0xFF6A6A, "o" => 0xFFD24A, "w" => 0xF4EAD0, "b" => 0x8A5A3A };
            var fx = cx + fieldHalf * 2 / 100;
            _place(dc, tRows, tPal, fx, groundY + p * 6, p, false);
        }
    }

    // Charms 9+ share one generic trinket on a little plinth, tinted with the
    // charm's own colour and placed by formula — no per-id table to outgrow.
    function _decorExtra(dc, coll, cx, groundY, fieldHalf, p) {
        var rows = [".c.", "ccc", "sss"];
        for (var i = 9; i < Fa.C_N; i++) {
            if ((coll & (1 << i)) == 0) { continue; }
            var k = i - 9;
            var side = ((k % 2) == 0) ? -1 : 1;
            var off = 26 + (k / 2) * 14; if (off > 74) { off = 74; }
            var pal = { "c" => Fa.cColor(i), "s" => 0x6A5A3A };
            _place(dc, rows, pal, cx + side * fieldHalf * off / 100,
                   groundY + p * (2 + (k % 3) * 2), p, false);
        }
    }

    // ── Animals wandering the field ───────────────────────────────────────────
    // Species match what the player has built; count ~ herd size (capped).
    function _animals(dc, m, cx, groundY, fieldHalf, p, phase) {
        var pop = 0; var lv = null;
        try { pop = m.population; lv = m.bLevel; } catch (e) { pop = 0; }
        var n = pop; if (n > 8) { n = 8; }
        if (n <= 0) { return; }

        // Which species can appear (default chickens if nothing specific yet).
        var species = [];
        try {
            if (lv != null) {
                if (lv[Fa.B_COOP] > 0) { species.add(0); }
                if (lv[Fa.B_DUCK] > 0) { species.add(1); }
                if (lv[Fa.B_PIG]  > 0) { species.add(2); }
                if (lv[Fa.B_COW]  > 0) { species.add(3); }
                if (lv[Fa.B_ALPACA] > 0) { species.add(4); }
            }
        } catch (e) {}
        if (species.size() == 0) { species = [0]; }

        // Sprite table: 0 chicken, 1 duck, 2 pig, 3 cow, 4 alpaca.
        var sprites = [
            [".c.", "www", "ww.", "l.l"],   // chicken
            [".y.", "yyo", "yyy", "f.f"],   // duck
            ["...", "ppp", "ppp", "l.l"],   // pig
            ["b.b", "www", "wbw", "l.l"],   // cow
            [".ff", "fff", "ff.", "l.l"]    // alpaca
        ];
        var pals = [
            { "c" => 0xFF5A5A, "w" => 0xF4F4F4, "l" => 0xE0A020 },
            { "y" => 0xF4D24A, "o" => 0xFF9A4A, "f" => 0xE0A020 },
            { "p" => 0xFF9AB0, "l" => 0xD07A90 },
            { "w" => 0xF4F4F4, "b" => 0x2A2A2A, "l" => 0x8A6A4A },
            { "f" => 0xE8D8B0, "l" => 0xC0A880 }
        ];
        var vp = p * 6 / 10; if (vp < 2) { vp = 2; }
        var range = fieldHalf * 80 / 100;
        for (var i = 0; i < n; i++) {
            var sp = species[_hash(i * 13 + 3) % species.size()];
            var rows = sprites[sp];
            var pal = pals[sp];
            var speedMil = 16 + (_hash(i * 11 + 7) % 26);
            var wx = cx + (Math.sin(phase.toFloat() * (0.015 + speedMil.toFloat() * 0.001) + i * 1.9) * range).toNumber() / 2
                     - fieldHalf * 6 / 100;
            var wy = groundY + p * 3 + (i % 3) * vp;
            var flipEvery = 6 + (i % 4);
            _place(dc, rows, pal, wx, wy, vp, ((phase / flipEvery + i) % 2 == 0));
        }
    }

    // ── Starter paddock for an empty farm ─────────────────────────────────────
    function _starter(dc, cx, groundY, p) {
        // A cosy little coop + a sprout + a hopeful sign so it's never bare.
        var coop = { "a" => 0xC85A3A, "w" => 0xF0E0C0, "d" => 0x6A3A22, "c" => 0x8A5A3A };
        var rows = ["..a..", ".aaa.", "cwwwc", "cwdwc"];
        _place(dc, rows, coop, cx, groundY, p, false);
        // A single hen out front.
        var hen = { "c" => 0xFF5A5A, "w" => 0xF4F4F4, "l" => 0xE0A020 };
        var henRows = [".c.", "www", "ww.", "l.l"];
        _place(dc, henRows, hen, cx + p * 4, groundY + p, p * 6 / 10, false);
        // A sprout of hope.
        var sprout = { "g" => 0x6FD06A, "t" => 0x7A4A2A };
        var sRows = ["g.g", ".g.", ".t."];
        _place(dc, sRows, sprout, cx - p * 4, groundY, p, false);
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
