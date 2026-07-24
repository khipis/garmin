// ═══════════════════════════════════════════════════════════════════════════
// CreatureRender.mc — Procedural egg + creature artwork.
//
// Everything is drawn from primitives (circles, polygons, arcs) so it scales to
// any watch and costs almost nothing to render. The look is driven entirely by
// the creature's species colour, evolution stage, rarity (glow) and path
// (runner/warrior/dreamer/dynamo accents). A gentle bob + blink comes from the
// view's animation phase — no sprite sheets, no heavy animation.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;

module CreatureArt {

    // ── Egg ────────────────────────────────────────────────────────────────────
    function drawEgg(dc, m, cx, cy, r, phase) {
        var col  = Cr.speciesColor(m.species);
        var dark = Cr.speciesDark(m.species);
        var bob  = (Math.sin(phase * 0.10) * (r / 22)).toNumber();
        var ey   = cy + bob;
        var rw   = r * 78 / 100;   // egg is a touch narrower than tall

        // Soft shadow.
        dc.setColor(0x0A0F16, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, cy + r + 4, rw, r / 5);

        // Shell body.
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, ey, rw + 2, r + 2);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, ey, rw, r);

        // Speckles (deterministic, seed-based).
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 6; i++) {
            var a = (m.seed >> (i * 3)) & 7;
            var sx = cx + ((a - 3) * rw / 6);
            var sy = ey + (((m.seed >> (i * 2 + 1)) & 7) - 3) * r / 6;
            dc.fillCircle(sx, sy, r / 14 + 1);
        }
        // Glossy highlight.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx - rw / 3, ey - r / 3, rw / 7, r / 5);

        // Progressive crack as it nears hatching.
        var pct = m.hatchPct();
        if (pct > 55) {
            dc.setColor(0x0A0F16, Graphics.COLOR_TRANSPARENT);
            var zx = cx - rw / 2;
            var zy = ey - r / 3;
            var seg = (pct - 55) / 9;   // 0..5 zig segments
            for (var s = 0; s < seg && s < 6; s++) {
                var nx = zx + rw / 6;
                var ny = zy + ((s % 2 == 0) ? r / 5 : -r / 6);
                dc.drawLine(zx, zy, nx, ny);
                dc.drawLine(zx, zy + 1, nx, ny + 1);
                zx = nx; zy = ny;
            }
        }
    }

    // ── Creature ────────────────────────────────────────────────────────────────
    function drawCreature(dc, m, cx, cy, r, phase) {
        var col  = Cr.speciesColor(m.species);
        var dark = Cr.speciesDark(m.species);
        var rare = Cr.rarityColor(m.rarityTier());
        var tier = m.rarityTier();

        // Size grows with evolution stage, but the ears/horns/fins reach up to
        // 1.5*sz beyond the body, so sz must never exceed the frame radius r.
        // Apex (evo 4) already hits that ceiling; the post-Apex stages express
        // themselves through extra aura rings below instead of more pixels.
        var g = 56 + m.evo * 11;
        if (g > 100) { g = 100; }
        var sz = r * g / 100;
        var bob = (Math.sin(phase * 0.11) * (r / 20)).toNumber();
        var by  = cy + bob;

        // Rarity aura (Epic+): concentric glow rings.
        if (tier >= Cr.RA_EPIC) {
            dc.setColor(rare, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, by, sz + 6);
            if (tier >= Cr.RA_LEGEND) { dc.drawCircle(cx, by, sz + 10); }
            if (tier >= Cr.RA_MYTHIC) { dc.drawCircle(cx, by, sz + 14); }
        }
        // Post-Apex stages: a gold halo per stage beyond Apex, so Mythic ->
        // Cosmic still reads as a visible upgrade without growing the body.
        if (m.evo > Cr.EV_APEX) {
            dc.setColor(Cr.GOLD, Graphics.COLOR_TRANSPARENT);
            var halos = Cr._clamp(m.evo - Cr.EV_APEX, 0, 3);
            for (var hi = 0; hi < halos; hi++) {
                dc.drawCircle(cx, by, sz + 4 + hi * 4);
            }
        }

        // Ground shadow.
        dc.setColor(0x0A0F16, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, cy + sz + 4, sz * 8 / 10, sz / 5);

        // Path-based back accents (drawn behind the body).
        _drawPathAccent(dc, m, cx, by, sz, phase);

        // Body.
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, by, sz + 2);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, by, sz);

        // Belly patch.
        dc.setColor(_lighten(col), Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, by + sz / 4, sz * 6 / 10, sz / 2);

        // Species-specific head features.
        _drawEars(dc, m, cx, by, sz, dark, col);

        // Feet.
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx - sz / 2, by + sz - 1, sz / 4, sz / 6);
        dc.fillEllipse(cx + sz / 2, by + sz - 1, sz / 4, sz / 6);

        // Face.
        _drawFace(dc, m, cx, by, sz, phase);

        // Mythic sparkle.
        if (tier >= Cr.RA_MYTHIC) { _sparkle(dc, cx, by, sz, phase, rare); }
    }

    // ── Ears / horns / crest per species ─────────────────────────────────────
    function _drawEars(dc, m, cx, cy, sz, dark, col) {
        var sp = m.species;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        if (sp == Cr.SP_FLAME) {
            // Twin flame crests.
            dc.fillPolygon([[cx - sz / 2, cy - sz + 2], [cx - sz / 6, cy - sz - sz / 2], [cx, cy - sz + 4]]);
            dc.fillPolygon([[cx + sz / 2, cy - sz + 2], [cx + sz / 6, cy - sz - sz / 2], [cx, cy - sz + 4]]);
        } else if (sp == Cr.SP_AQUA) {
            // Side fins.
            dc.fillPolygon([[cx - sz, cy], [cx - sz - sz / 2, cy - sz / 3], [cx - sz + sz / 6, cy - sz / 4]]);
            dc.fillPolygon([[cx + sz, cy], [cx + sz + sz / 2, cy - sz / 3], [cx + sz - sz / 6, cy - sz / 4]]);
        } else if (sp == Cr.SP_VOLT) {
            // Lightning ears.
            dc.fillPolygon([[cx - sz / 2, cy - sz / 2], [cx - sz / 2 - sz / 4, cy - sz - sz / 3], [cx - sz / 6, cy - sz + 2]]);
            dc.fillPolygon([[cx + sz / 2, cy - sz / 2], [cx + sz / 2 + sz / 4, cy - sz - sz / 3], [cx + sz / 6, cy - sz + 2]]);
        } else if (sp == Cr.SP_FOREST) {
            // Leafy pointed ears.
            dc.fillEllipse(cx - sz / 2, cy - sz + 2, sz / 5, sz / 3);
            dc.fillEllipse(cx + sz / 2, cy - sz + 2, sz / 5, sz / 3);
        } else {
            // Shadow horns.
            dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - sz / 2, cy - sz + 4], [cx - sz / 3, cy - sz - sz / 2], [cx - sz / 6, cy - sz + 6]]);
            dc.fillPolygon([[cx + sz / 2, cy - sz + 4], [cx + sz / 3, cy - sz - sz / 2], [cx + sz / 6, cy - sz + 6]]);
        }
    }

    // ── Face: eyes (blink) + mouth (mood) ────────────────────────────────────
    function _drawFace(dc, m, cx, cy, sz, phase) {
        var eyeY = cy - sz / 6;
        var eyeDx = sz / 3;
        var blink = ((phase / 8) % 40) == 0;   // occasional blink

        if (blink) {
            dc.setColor(0x101820, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - eyeDx - sz / 6, eyeY, cx - eyeDx + sz / 6, eyeY);
            dc.drawLine(cx + eyeDx - sz / 6, eyeY, cx + eyeDx + sz / 6, eyeY);
        } else {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - eyeDx, eyeY, sz / 5);
            dc.fillCircle(cx + eyeDx, eyeY, sz / 5);
            dc.setColor(0x101820, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - eyeDx + sz / 12, eyeY, sz / 10);
            dc.fillCircle(cx + eyeDx + sz / 12, eyeY, sz / 10);
        }

        // Mouth reflects mood.
        var my = cy + sz / 3;
        dc.setColor(0x101820, Graphics.COLOR_TRANSPARENT);
        if (m.mood >= 60) {
            dc.drawArc(cx, my - sz / 6, sz / 4, Graphics.ARC_CLOCKWISE, 200, 340);
        } else if (m.mood >= 35) {
            dc.drawLine(cx - sz / 5, my, cx + sz / 5, my);
        } else {
            dc.drawArc(cx, my + sz / 5, sz / 4, Graphics.ARC_COUNTER_CLOCKWISE, 20, 160);
        }
    }

    // ── Evolution-path accents (behind body) ─────────────────────────────────
    function _drawPathAccent(dc, m, cx, cy, sz, phase) {
        if (m.evo < Cr.EV_JUV || m.path == Cr.PATH_NONE) { return; }
        if (m.path == Cr.PATH_RUNNER) {
            // Speed lines.
            dc.setColor(0x8FE3FF, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 3; i++) {
                var y = cy - sz / 2 + i * sz / 2;
                dc.drawLine(cx - sz - sz / 2, y, cx - sz / 2, y);
            }
        } else if (m.path == Cr.PATH_WARRIOR) {
            // Shoulder spikes.
            var c = Cr.speciesDark(m.species);
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - sz, cy - sz / 4], [cx - sz - sz / 3, cy], [cx - sz + sz / 6, cy + sz / 6]]);
            dc.fillPolygon([[cx + sz, cy - sz / 4], [cx + sz + sz / 3, cy], [cx + sz - sz / 6, cy + sz / 6]]);
        } else if (m.path == Cr.PATH_DREAM) {
            // Floating stars.
            dc.setColor(0xCBB6FF, Graphics.COLOR_TRANSPARENT);
            for (var s = 0; s < 3; s++) {
                var a = phase * 0.05 + s * 2;
                var px = cx + (Math.cos(a) * (sz + 8)).toNumber();
                var py = cy - sz + (Math.sin(a) * (sz / 2)).toNumber();
                dc.fillCircle(px, py, 2);
            }
        } else {
            // Energy bolts.
            dc.setColor(0xFFE45A, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx + sz, cy - sz], [cx + sz + 6, cy - sz], [cx + sz + 1, cy - sz / 3], [cx + sz + 8, cy - sz / 3], [cx + sz - 2, cy + sz / 4]]);
        }
    }

    function _sparkle(dc, cx, cy, sz, phase, col) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var a = phase * 0.08 + i * 1.57;
            var px = cx + (Math.cos(a) * (sz + 12)).toNumber();
            var py = cy + (Math.sin(a) * (sz + 12)).toNumber();
            dc.fillPolygon([[px, py - 3], [px + 2, py], [px, py + 3], [px - 2, py]]);
        }
    }

    function _lighten(c) {
        var r = (c >> 16) & 0xFF; var g = (c >> 8) & 0xFF; var b = c & 0xFF;
        r = r + (255 - r) / 3; g = g + (255 - g) / 3; b = b + (255 - b) / 3;
        return (r << 16) | (g << 8) | b;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PIXEL-ART SANCTUARY
    //
    // A chunky pixel biome that IS the home screen: sky (time-of-day), hills,
    // pond, grass, trees/plants/rocks that grow in with progress, and — the
    // point — your whole collection ROAMING. The active species is the big hero;
    // every OTHER species appears as a little wandering mob (coloured once seen,
    // a grey silhouette while still undiscovered) so it reads as a living
    // habitat, not a single pet.
    // ═══════════════════════════════════════════════════════════════════════

    // 8-wide cute silhouettes, one per species (distinct crest/fins/ears/horns).
    function _mobRows(sp) {
        if (sp == Cr.SP_FLAME) {
            return [".B....B.", ".BB..BB.", "..BBBB..", ".BBBBBB.",
                    ".BWBBWB.", ".BKBBKB.", ".BLLLLB.", "..D..D.."];
        } else if (sp == Cr.SP_AQUA) {
            return ["........", "..BBBB..", ".BBBBBB.", "DBWBBWBD",
                    ".BKBBKB.", ".BBBBBB.", ".BLLLLB.", "..D..D.."];
        } else if (sp == Cr.SP_VOLT) {
            return [".B....B.", ".B....B.", "..BBBB..", ".BBBBBB.",
                    ".BWBBWB.", ".BKBBKB.", ".BBBBBB.", "..D..D.."];
        } else if (sp == Cr.SP_FOREST) {
            return [".D....D.", ".DB..BD.", "..BBBB..", ".BBBBBB.",
                    ".BWBBWB.", ".BKBBKB.", ".BLLLLB.", "..D..D.."];
        }
        return ["D......D", ".D....D.", "..BBBB..", ".BBBBBB.",
                ".BWBBWB.", ".BKBBKB.", ".BBBBBB.", "..D..D.."];
    }
    function _mobPal(sp) {
        var col = Cr.speciesColor(sp);
        return { "B" => col, "D" => Cr.speciesDark(sp), "L" => _lighten(col),
                 "W" => 0xFFFFFF, "K" => 0x0B1016 };
    }
    // Undiscovered species: a dim slate silhouette ("there's more to find").
    function _ghostPal() {
        return { "B" => 0x2C3A48, "D" => 0x222E3A, "L" => 0x33414F,
                 "W" => 0x2C3A48, "K" => 0x222E3A };
    }

    // A small roaming creature (coloured if seen, ghost if not).
    function drawMob(dc, sp, cx, cy, px, phase, flip, seen) {
        var rows = _mobRows(sp);
        var h = rows.size();
        var ox = cx - 4 * px;              // sprites are 8 cells wide
        var oy = cy - h * px;              // stand on (cx,cy)
        // little contact shadow
        dc.setColor(0x0A0F16, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, cy, px * 3, px);
        Px.spr(dc, rows, seen ? _mobPal(sp) : _ghostPal(), ox, oy, px, flip);
    }

    // The hero: the active creature, big, with idle-animated bob/hop/blink,
    // a tail-wag, a soft ground-glow spotlight, rarity/apex aura + shadow.
    // The APEX stage (full evolution) is deliberately made to look dramatically
    // more spectacular than an early stage — a slow sunburst + gold aura ring —
    // so the player visibly feels how much their creature has grown.
    function drawHero(dc, m, cx, cy, px, phase) {
        var rows = _mobRows(m.species);
        var h = rows.size();
        var seedOff = 0;
        try { seedOff = m.seed % 97; } catch (e) { seedOff = 0; }

        // Occasional hop — a short eased bounce, on its own per-creature cadence.
        var hopCycle = (phase + seedOff) % 150;
        var hop = 0;
        if (hopCycle < 12) {
            var tt = hopCycle - 6;
            var amt = 36 - tt * tt; if (amt < 0) { amt = 0; }
            hop = amt * px / 40;
        }
        var bob = (Math.sin(phase * 0.11) * px * 4 / 10).toNumber();
        var by  = cy + bob - hop;
        var tier = m.rarityTier();
        var apex = false;
        try { apex = (m.evo >= Cr.EV_APEX); } catch (e) {}

        // Ground shadow — squashes a touch while airborne, for a sense of weight.
        dc.setColor(0x0A0F16, Graphics.COLOR_TRANSPARENT);
        var shSq = 100 - hop * 30 / (px + 1); if (shSq < 55) { shSq = 55; }
        dc.fillEllipse(cx, cy + 2, px * 5 * shSq / 100, px + px / 2);

        // Soft ground-glow spotlight beneath the hero (species-tinted, grows
        // with level) — draws the eye to the creature even on a busy diorama.
        try { _heroGlow(dc, m, cx, cy + px / 2, px); } catch (e) {}

        // Rarity aura (Epic+) — or full Apex grandeur, whichever is grander.
        if (tier >= Cr.RA_EPIC || apex) {
            var rr = px * 5;
            dc.setColor(apex ? Cr.GOLD : Cr.rarityColor(tier), Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, by - px * 3, rr);
            if (tier >= Cr.RA_LEGEND || apex) { dc.drawCircle(cx, by - px * 3, rr + px); }
            if (tier >= Cr.RA_MYTHIC) { dc.drawCircle(cx, by - px * 3, rr + px * 2); }
            if (apex) {
                dc.setColor(Cr.GOLD, Graphics.COLOR_TRANSPARENT);
                // Two extra sunburst rays per stage past Apex, so Mythic ->
                // Cosmic keeps escalating on the home diorama.
                var rays = 6;
                try { rays = 6 + Cr._clamp(m.evo - Cr.EV_APEX, 0, 3) * 2; } catch (e) { rays = 6; }
                for (var ri = 0; ri < rays; ri++) {
                    var ang = phase * 0.02 + ri * 6.283 / rays;
                    var r0 = rr + px * 2; var r1 = rr + px * 3;
                    var rx0 = cx + (Math.cos(ang) * r0).toNumber();
                    var ry0 = by - px * 3 + (Math.sin(ang) * r0).toNumber();
                    var rx1 = cx + (Math.cos(ang) * r1).toNumber();
                    var ry1 = by - px * 3 + (Math.sin(ang) * r1).toNumber();
                    dc.drawLine(rx0, ry0, rx1, ry1);
                }
            }
        }

        var ox = cx - 4 * px;
        var oy = by - h * px;

        // Idle tail-wag — a small triangle behind the body, swaying with phase
        // on its own per-creature cadence (drawn first so the body overlaps it).
        try {
            var wag = (Math.sin(phase * 0.15 + seedOff) * (px * 6 / 10)).toNumber();
            dc.setColor(Cr.speciesDark(m.species), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[ox, oy + (h - 2) * px],
                            [ox - px - wag, oy + (h - 3) * px + wag / 2],
                            [ox, oy + (h - 1) * px]]);
        } catch (e) {}

        // Occasional blink — swap the eye rows to a shut-eye palette.
        var blink = (((phase / 5) + seedOff) % 130) < 6;
        Px.spr(dc, rows, blink ? _mobPalBlink(m.species) : _mobPal(m.species), ox, oy, px, false);

        // DNA-mutation embellishment — a visible, ever-growing sign of every
        // mutation earned, independent of rarity (so a common but heavily
        // mutated creature still visibly stands out).
        var muts = 0;
        try { muts = m.mutations; } catch (e) { muts = 0; }
        _mutationFx(dc, cx, by - px * 3, px * 3, phase, muts);

        if (tier >= Cr.RA_MYTHIC) { _sparklePix(dc, cx, by - px * 3, px * 5, phase, Cr.rarityColor(tier)); }
    }

    // A dim, species-tinted patch of "light" on the ground beneath the hero —
    // no true alpha blending is needed since it's mixed toward the grass tone
    // at draw time; it reads as a soft glow/vignette drawing the eye in.
    function _heroGlow(dc, m, cx, cy, px) {
        var lvl = 1;
        try { lvl = m.level; } catch (e) { lvl = 1; }
        if (lvl > 12) { lvl = 12; }
        var col = _blend(Cr.speciesColor(m.species), 0x2A6E44, 74);
        var gw = px * (10 + lvl);
        var gh = px * 3 + px * lvl / 6;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, cy, gw / 2, gh / 2);
    }

    // Linear RGB blend toward tPct% of c1 (0 = pure c0, 100 = pure c1).
    function _blend(c0, c1, tPct) {
        var r0 = (c0 >> 16) & 0xFF; var g0 = (c0 >> 8) & 0xFF; var b0 = c0 & 0xFF;
        var r1 = (c1 >> 16) & 0xFF; var g1 = (c1 >> 8) & 0xFF; var b1 = c1 & 0xFF;
        var r = (r0 * (100 - tPct) + r1 * tPct) / 100;
        var g = (g0 * (100 - tPct) + g1 * tPct) / 100;
        var b = (b0 * (100 - tPct) + b1 * tPct) / 100;
        return (r << 16) | (g << 8) | b;
    }

    // Shut-eye variant of the mob palette — the "W"/"K" eye cells go dark.
    function _mobPalBlink(sp) {
        var col = Cr.speciesColor(sp);
        var dark = Cr.speciesDark(sp);
        return { "B" => col, "D" => dark, "L" => _lighten(col), "W" => dark, "K" => dark };
    }

    // ── DNA-mutation embellishment (independent of rarity) ───────────────────
    // Tier 1 (3+): a couple of drifting violet DNA motes.
    // Tier 2 (8+): + a faint violet ring.
    // Tier 3 (15+): + a second, brighter ring — visibly "mutated to the max".
    function _mutationFx(dc, cx, cy, r, phase, mutations) {
        var tier = 0;
        if (mutations >= 15)     { tier = 3; }
        else if (mutations >= 8) { tier = 2; }
        else if (mutations >= 3) { tier = 1; }
        if (tier <= 0) { return; }

        var col = 0xCBB6FF;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var n = tier + 1;
        for (var i = 0; i < n; i++) {
            var a = phase * 0.07 + i * (6.283 / n);
            var mx = cx + (Math.cos(a) * (r + 3)).toNumber();
            var my = cy + (Math.sin(a) * (r * 6 / 10)).toNumber();
            dc.fillRectangle(mx - 1, my - 1, 2, 2);
        }
        if (tier >= 2) { dc.drawCircle(cx, cy, r + 2); }
        if (tier >= 3) { dc.drawCircle(cx, cy, r + 5); }
    }

    // ── Currency glyph: a small pixel berry (food) icon for the HUD ──────────
    function drawBerryIcon(dc, x, y, px) {
        var rows = [".rr.", "rrrr", "rrrr", ".gg."];
        var pal = { "r" => 0xFF4C5A, "g" => 0x3FA85A };
        Px.spr(dc, rows, pal, x, y, px, false);
    }

    function _sparklePix(dc, cx, cy, r, phase, col) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var a = phase * 0.08 + i * 1.57;
            var sx = cx + (Math.cos(a) * r).toNumber();
            var sy = cy + (Math.sin(a) * r).toNumber();
            dc.fillRectangle(sx - 1, sy - 1, 3, 3);
        }
    }

    // ── Time-of-day sky colours [top, bottom] from the current hour ──────────
    function _skyPair(hour) {
        if (hour < 5 || hour >= 21) { return [0x0B1030, 0x27204A]; }   // night
        if (hour < 8)  { return [0x3B4A7A, 0xFFB27A]; }                // dawn
        if (hour < 17) { return [0x2E8FD6, 0xBDE8FF]; }                // day
        if (hour < 19) { return [0x2A3A66, 0xFF9E6B]; }                // dusk
        return [0x1E2650, 0x5A3E6E];                                    // twilight
    }

    // ── The full sanctuary (drawn INSIDE a bounding box [x0,y0,w,h]) ─────────
    // The scene is inset by the caller so it never collides with the tab strip
    // or the HUD; a clip keeps every layer neatly inside the frame. Layers,
    // back to front: sky → sky bodies (sun/moon, clouds, stars) → parallax
    // hills → grass → water → props (grow with progress) → element ambience →
    // the roaming collection → the hero → rarity sparkle → a tidy frame.
    function drawSanctuary(dc, m, x0, y0, w, h, phase, frame) {
        var hour = 12;
        try { hour = System.getClockTime().hour; } catch (e) {}
        var night = (hour < 5 || hour >= 21);
        var groundY = y0 + h * 60 / 100;

        try { dc.setClip(x0, y0, w, h); } catch (e) {}

        // ── Sky ──────────────────────────────────────────────────────────────
        var sky = _skyPair(hour);
        try { Px.vgrad(dc, x0, y0, w, groundY - y0, sky[0], sky[1], 12); } catch (e) {}

        // Stars (night) — deterministic from seed so they don't jitter.
        if (night) {
            try {
                dc.setColor(0xE8ECF4, Graphics.COLOR_TRANSPARENT);
                var sd = (m.seed | 1);
                for (var s = 0; s < 12; s++) {
                    var sx = x0 + ((sd >> (s * 2 + 1)) & 0xFF) * w / 256;
                    var sy = y0 + ((sd >> (s + 2)) & 0x3F) * (groundY - y0) / 72;
                    var tw = ((phase / 6 + s) % 5 == 0) ? 3 : 2;   // subtle twinkle
                    dc.fillRectangle(sx, sy + 3, tw, tw);
                }
            } catch (e) {}
        } else {
            // Drifting clouds (day) — two chunky puffs sliding slowly.
            try {
                for (var ci = 0; ci < 2; ci++) {
                    var span = w + w * 40 / 100;
                    var cxp = x0 - w * 20 / 100
                            + ((phase / 3 + ci * 140) % span);
                    var cyp = y0 + h * (10 + ci * 9) / 100;
                    _cloud(dc, cxp, cyp, h * 6 / 100, night);
                }
            } catch (e) {}
        }

        // ── Sun / moon (+ streak halos) ───────────────────────────────────────
        var celX = x0 + w * 76 / 100; var celY = y0 + h * 13 / 100;
        try {
            if (night) {
                dc.setColor(0xD6DCEA, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(celX, celY, h * 6 / 100);
                dc.setColor(sky[0], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(celX + h * 3 / 100, celY - h * 2 / 100, h * 5 / 100);
            } else {
                var pulse = h * 7 / 100 + ((phase / 10) % 2);
                dc.setColor(0xFFE07A, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(celX, celY, pulse);
                dc.setColor(0xFFF3C0, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(celX, celY, h * 5 / 100);
            }
            var streak0 = 0;
            try { streak0 = m.streak; } catch (e) { streak0 = 0; }
            if (streak0 >= 7) {
                dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(celX, celY, h * 8 / 100);
            }
            if (streak0 >= 30) {
                dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(celX, celY, h * 9 / 100);
            }
        } catch (e) {}

        // ── Parallax hills (three layered mounds for depth) ───────────────────
        try {
            dc.setColor(night ? 0x122A22 : 0x2A6E44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x0 + w * 50 / 100, groundY + h * 10 / 100, h * 26 / 100);
            dc.setColor(night ? 0x1B3A2E : 0x2F7A4A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x0 + w * 22 / 100, groundY + h * 7 / 100, h * 20 / 100);
            dc.setColor(night ? 0x143026 : 0x256B3E, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x0 + w * 78 / 100, groundY + h * 6 / 100, h * 17 / 100);
        } catch (e) {}

        // ── Grass ground ──────────────────────────────────────────────────────
        try {
            Px.vgrad(dc, x0, groundY, w, (y0 + h) - groundY, 0x3EA85A, 0x1C6E36, 8);
            Px.rect(dc, x0, groundY, w, h * 2 / 100, 0x59C46E);   // bright lip
        } catch (e) {}

        // How much the biome has "grown in".
        var deco = 0;
        try { deco = m.level + m.evo * 3 + m.seenCount() * 2; } catch (e) {}

        // ── Pond (layered water + ripples + reflection glints) ────────────────
        try {
            var pw = w * 26 / 100 + deco; if (pw > w * 42 / 100) { pw = w * 42 / 100; }
            var px2 = x0 + w * 24 / 100; var py2 = y0 + h * 86 / 100;
            dc.setColor(0x14465E, Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(px2, py2, pw / 2 + 3, h * 6 / 100 + 3);
            dc.setColor(0x1C5E7A, Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(px2, py2, pw / 2, h * 6 / 100);
            dc.setColor(0x2E93C4, Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(px2, py2 - 1, pw * 4 / 10, h * 4 / 100);
            dc.setColor(0x8FD6F0, Graphics.COLOR_TRANSPARENT);
            var rip = (Math.sin(phase * 0.09) * (pw / 8)).toNumber();
            dc.fillRectangle(px2 - pw / 6 + rip, py2 - 2, pw / 5, 2);
            dc.fillRectangle(px2 + pw / 8 - rip, py2 + 1, pw / 8, 1);

            // Streak fireflies dance over the pond (livelier the longer the bond).
            var motes = 0;
            try { motes = m.streak / 3; } catch (e) { motes = 0; }
            if (motes > 5) { motes = 5; }
            if (motes > 0) {
                dc.setColor(night ? 0xFFE9A0 : 0xBFF2FF, Graphics.COLOR_TRANSPARENT);
                for (var fi = 0; fi < motes; fi++) {
                    var fa = phase * 0.04 + fi * 2.4;
                    var fx = px2 + (Math.cos(fa) * (pw / 2 + 6)).toNumber();
                    var fy = py2 - h * 4 / 100 + (Math.sin(fa) * (h * 4 / 100)).toNumber();
                    dc.fillRectangle(fx, fy, 2, 2);
                }
            }
        } catch (e) {}

        // ── Props (grow with progress) ────────────────────────────────────────
        try { _drawDen(dc, x0 + w * 85 / 100, groundY + h * 2 / 100, h * 9 / 100); } catch (e) {}
        try {
            var tpx = h * 8 / 100 / 5; if (tpx < 3) { tpx = 3; }
            var tpx2 = (tpx - 1 < 3) ? 3 : tpx - 1;
            _drawTree(dc, x0 + w * 12 / 100, groundY + h * 3 / 100, tpx);
            if (deco >= 8)  { _drawTree(dc, x0 + w * 63 / 100, groundY + h * 4 / 100, tpx2); }
            _drawBush(dc, x0 + w * 40 / 100, groundY + h * 6 / 100, tpx);
            if (deco >= 5)  { _drawBush(dc, x0 + w * 92 / 100, groundY + h * 9 / 100, (tpx - 1 < 2) ? 2 : tpx - 1); }
            if (deco >= 6)  { _drawFlower(dc, x0 + w * 30 / 100, groundY + h * 12 / 100, tpx, 0xFF6FA8); }
            if (deco >= 10) { _drawFlower(dc, x0 + w * 55 / 100, groundY + h * 15 / 100, tpx, 0xFFD24A); }
            if (deco >= 14) { _drawFlower(dc, x0 + w * 70 / 100, groundY + h * 11 / 100, tpx, 0x8FB0FF); }
            if (deco >= 4)  { _drawRock(dc, x0 + w * 48 / 100, groundY + h * 18 / 100, tpx); }
            if (deco >= 12) { _drawRock(dc, x0 + w * 8 / 100, groundY + h * 20 / 100, tpx); }
            if (deco >= 18) { _drawMushroom(dc, x0 + w * 36 / 100, groundY + h * 20 / 100, tpx); }
            if (deco >= 24) { _drawMushroom(dc, x0 + w * 80 / 100, groundY + h * 22 / 100, tpx); }
            // Higher tiers keep visibly "multiplying" the habitat, not just
            // recolouring it — a second den and a banner mark real growth.
            if (deco >= 28) { _drawBanner(dc, x0 + w * 5 / 100, groundY + h * 1 / 100, tpx); }
            if (deco >= 34) { _drawDen(dc, x0 + w * 20 / 100, groundY + h * 5 / 100, h * 6 / 100); }
            if (deco >= 40) { _drawFlower(dc, x0 + w * 46 / 100, groundY + h * 24 / 100, tpx, 0xFFFFFF); }
        } catch (e) {}

        // ── Element ambience — species-tinted idle particles (cheap, ephemeral) ─
        try { _ambient(dc, m, x0, y0, w, h, groundY, phase, night); } catch (e) {}

        // ── The collection roams ─────────────────────────────────────────────
        // Every OTHER discovered species gets 1-3 small roaming sprites so the
        // habitat visibly gets busier the more you find. Undiscovered species
        // show a single dim silhouette as a "there's more out there" teaser.
        try {
            var mobPx = h * 12 / 100 / 8; if (mobPx < 3) { mobPx = 3; }
            var xsPct = [24, 66, 84, 44, 14, 90, 55, 32, 74, 38];
            var ysPct = [74, 70, 80, 88, 84, 76, 90, 68, 88, 80];
            var slot = 0;
            var maxMobs = xsPct.size();
            for (var i = 0; i < Cr.SPECIES_N; i++) {
                if (i == m.species) { continue; }
                var seen = false;
                try { seen = m.isSeen(i); } catch (e) {}
                var count = seen ? (1 + ((i * 7 + 3) % 3)) : 1;
                for (var c = 0; c < count; c++) {
                    if (slot >= maxMobs) { break; }
                    var drift = (Math.sin(phase * 0.05 + slot * 1.7 + c * 0.6) * (w * 5 / 100)).toNumber();
                    var mx = x0 + w * xsPct[slot] / 100 + drift;
                    var my = y0 + h * ysPct[slot] / 100;
                    drawMob(dc, i, mx, my, mobPx, phase, drift < 0, seen);
                    slot += 1;
                }
            }
        } catch (e) {}

        // ── Hero (active creature), front and centre on the grass ─────────────
        try {
            var heroPx = h * 32 / 100 / 8; if (heroPx < 5) { heroPx = 5; }
            drawHero(dc, m, x0 + w * 50 / 100, groundY + h * 15 / 100, heroPx, phase);
        } catch (e) {}

        // A sprinkle of ambient sparkle for rare owners — Apex creatures get
        // their own wider, golden shower so the fully-grown state unmistakably
        // reads as "more spectacular" than an early one.
        try {
            var tier2 = Cr.RA_COMMON;
            try { tier2 = m.rarityTier(); } catch (e) {}
            var apex2 = false;
            try { apex2 = (m.evo >= Cr.EV_APEX); } catch (e) {}
            if (tier2 >= Cr.RA_EPIC || apex2) {
                dc.setColor(apex2 ? Cr.GOLD : Cr.rarityColor(tier2), Graphics.COLOR_TRANSPARENT);
                var sparkN = apex2 ? 5 : 3;
                for (var k = 0; k < sparkN; k++) {
                    var a2 = phase * 0.04 + k * 2.1;
                    var fx2 = x0 + w * 50 / 100 + (Math.cos(a2) * w * 30 / 100).toNumber();
                    var fy2 = y0 + h * 34 / 100 + (Math.sin(a2 * 1.3) * h * 10 / 100).toNumber();
                    dc.fillRectangle(fx2, fy2, 2, 2);
                }
            }
        } catch (e) {}

        try { dc.clearClip(); } catch (e) {}

        // Tidy frame around the diorama — escalates with evolution stage so
        // the fully-grown Apex form visibly looks the most spectacular.
        try {
            if (frame) {
                var evoF = 0;
                try { evoF = m.evo; } catch (e) {}
                var frameCol = 0x24303C;
                if (evoF >= Cr.EV_ADULT)   { frameCol = 0x3D4E60; }
                if (evoF >= Cr.EV_APEX)    { frameCol = Cr.GOLD; }
                if (evoF >= Cr.EV_MYTH)    { frameCol = 0xFF4C7A; }
                if (evoF >= Cr.EV_ETERNAL) { frameCol = 0x8FE3FF; }
                if (evoF >= Cr.EV_COSMIC)  { frameCol = 0xB46CFF; }
                dc.setColor(frameCol, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(x0, y0, w, h, 10);
                if (evoF >= Cr.EV_APEX) { dc.drawRoundedRectangle(x0 + 2, y0 + 2, w - 4, h - 4, 9); }
                if (evoF >= Cr.EV_ETERNAL) { dc.drawRoundedRectangle(x0 + 4, y0 + 4, w - 8, h - 8, 8); }
            }
        } catch (e) {}
    }

    // A chunky drifting cloud (day sky). Kept to a few overlapping puffs.
    function _cloud(dc, cx, cy, r, night) {
        dc.setColor(night ? 0x2A3350 : 0xEAF2FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.fillCircle(cx + r, cy + r / 4, r * 8 / 10);
        dc.fillCircle(cx - r, cy + r / 4, r * 7 / 10);
        dc.fillRectangle(cx - r, cy, r * 2, r);
    }

    // A little spotted toadstool that appears as the biome matures.
    function _drawMushroom(dc, cx, baseY, px) {
        var rows = [".ccc.", "ccccc", ".www.", ".www."];
        var pal = { "c" => 0xE0563C, "w" => 0xF3E8D0 };
        Px.spr(dc, rows, pal, cx - 2 * px, baseY - 4 * px, px, false);
    }

    // ── Element ambience: species-flavoured idle particles ───────────────────
    // FLAME embers rise, AQUA bubbles float up, VOLT sparks flick, FOREST
    // leaves fall, SHADOW wisps drift — a cheap, recomputed-per-frame signature
    // that keeps CREATURES visually its own thing (not the pets game).
    function _ambient(dc, m, x0, y0, w, h, groundY, phase, night) {
        var sp = 0;
        try { sp = m.species; } catch (e) { sp = 0; }
        var n = 5;
        for (var i = 0; i < n; i++) {
            var seedf = i * 1.9 + 0.4;
            var bx = x0 + w * (12 + ((i * 37) % 76)) / 100;
            if (sp == Cr.SP_FLAME) {
                dc.setColor((i % 2 == 0) ? 0xFF7A2A : 0xFFC24A, Graphics.COLOR_TRANSPARENT);
                var fy = groundY - ((phase * 2 + i * 33) % (h * 40 / 100));
                var fx = bx + (Math.sin(phase * 0.08 + seedf) * (w * 3 / 100)).toNumber();
                dc.fillRectangle(fx, fy, 2, 2);
            } else if (sp == Cr.SP_AQUA) {
                dc.setColor(0x9FE4FF, Graphics.COLOR_TRANSPARENT);
                var by = (y0 + h) - ((phase + i * 40) % (h * 55 / 100));
                var bxo = bx + (Math.sin(phase * 0.06 + seedf) * (w * 2 / 100)).toNumber();
                dc.drawCircle(bxo, by, 2);
            } else if (sp == Cr.SP_VOLT) {
                if ((phase / 4 + i) % 6 == 0) {
                    dc.setColor(0xFFF06A, Graphics.COLOR_TRANSPARENT);
                    var vy = y0 + h * (20 + ((i * 29) % 40)) / 100;
                    dc.fillRectangle(bx, vy, 2, 4);
                    dc.fillRectangle(bx + 1, vy + 4, 2, 3);
                }
            } else if (sp == Cr.SP_FOREST) {
                dc.setColor((i % 2 == 0) ? 0x8FD65A : 0xE0C24A, Graphics.COLOR_TRANSPARENT);
                var ly = y0 + h * 14 / 100 + ((phase + i * 44) % (h * 55 / 100));
                var lx = bx + (Math.sin(phase * 0.05 + seedf) * (w * 6 / 100)).toNumber();
                dc.fillRectangle(lx, ly, 3, 2);
            } else {
                dc.setColor(night ? 0xB49CFF : 0x8A74D6, Graphics.COLOR_TRANSPARENT);
                var wy = y0 + h * 22 / 100 + (Math.sin(phase * 0.05 + seedf) * (h * 12 / 100)).toNumber();
                var wx = bx + (Math.cos(phase * 0.04 + seedf) * (w * 8 / 100)).toNumber();
                dc.fillRectangle(wx, wy, 3, 3);
            }
        }
    }

    function _drawTree(dc, cx, baseY, px) {
        var rows = ["..GGG..", ".GGGGG.", "GGGGGGG", "GGgGGgG",
                    ".GGGGG.", "...T...", "...T...", "..TTT.."];
        var pal = { "G" => 0x4CC85A, "g" => 0x2E7D3A, "T" => 0x6B4A2A };
        Px.spr(dc, rows, pal, cx - 3 * px, baseY - 8 * px, px, false);
    }
    function _drawBush(dc, cx, baseY, px) {
        var rows = [".GGG.", "GGGGG", "GgGgG", ".GGG."];
        var pal = { "G" => 0x54B85E, "g" => 0x2E7D3A };
        Px.spr(dc, rows, pal, cx - 2 * px, baseY - 4 * px, px, false);
    }
    function _drawFlower(dc, cx, baseY, px, petal) {
        var rows = [".p.", "pYp", ".s.", ".s."];
        var pal = { "p" => petal, "Y" => 0xFFE07A, "s" => 0x2E7D3A };
        Px.spr(dc, rows, pal, cx - px, baseY - 4 * px, px, false);
    }
    function _drawRock(dc, cx, baseY, px) {
        var rows = ["..RR..", ".RRRRR", "RRRRRR"];
        var pal = { "R" => 0x8A94A0 };
        Px.spr(dc, rows, pal, cx - 3 * px, baseY - 3 * px, px, false);
    }
    // A little pennant banner — appears once the habitat is well-grown, a
    // visible sign of "upgrade" rather than just a palette shift.
    function _drawBanner(dc, cx, baseY, px) {
        var rows = [".P.", ".P.", "FFP", "FFP", ".P.", ".P.", ".P."];
        var pal = { "P" => 0x6B4A2A, "F" => 0xFFC24A };
        Px.spr(dc, rows, pal, cx - px, baseY - 7 * px, px, false);
    }
    function _drawDen(dc, cx, baseY, r) {
        // A little rounded burrow the creatures can nest in.
        dc.setColor(0x4A3A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, baseY, r);
        dc.setColor(0x2A2018, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, baseY + r / 4, r * 6 / 10);
        dc.setColor(0x6B5A3A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - r, baseY, r * 2, r / 3);
    }
}
