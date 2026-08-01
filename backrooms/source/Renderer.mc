// ═══════════════════════════════════════════════════════════════════════════
// Renderer.mc — Painting the raycast frame (module `BrRender`).
//
// Everything here is flat fillRectangle work: no bitmaps, no per-pixel loops,
// no allocation inside the frame. Texture comes from three cheap tricks —
//
//   1. perspective grids   ceiling tiles and carpet seams converge on the
//                          vanishing point, which is what actually sells depth
//   2. per-column shading  a hash of (cell, u-bucket) nudges the ramp index, so
//                          adjacent wall columns differ and the face reads as a
//                          surface instead of a slab of colour
//   3. horizontal trim     picture rail, wainscot and skirting split every wall
//                          vertically, and a dark line marks each corner
//
// The three planes also sit in different hues (grey tiles / yellow wallpaper /
// brown carpet) because on a four-level panel, three warm greys become one.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;

module BrRender {

    // Perspective grid: how many rows between the horizon and the near edge,
    // and how wide one tile is at that near edge (screen width / GRID_K).
    const GRID_ROWS = 7;
    const GRID_K    = 4;

    // Depths of the four ceiling fittings, refreshed once per frame.
    var _lampD = null;

    // Pick a colour `steps` deep into a ramp, clamped at both ends.
    function ramp(r, steps) {
        if (steps < 0) { steps = 0; }
        var n = r.size() - 1;
        if (steps > n) { steps = n; }
        return r[steps];
    }

    function rect(dc, x, y, w, h, col) {
        if (w <= 0 || h <= 0) { return; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);
    }

    // Horizontal-scanline fill — our stand-in for alpha on devices without it.
    function ditherRect(dc, x, y, w, h, col, step) {
        if (w <= 0 || h <= 0) { return; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        for (var yy = y; yy < y + h; yy += step) {
            dc.fillRectangle(x, yy, w, 1);
        }
    }

    // Depth of the k-th perspective row as a fraction of the plane, squared so
    // rows bunch up toward the horizon the way real ones do.
    function _row(k, n, span) {
        return span * k * k / (n * n);
    }

    // ── Ceiling ──────────────────────────────────────────────────────────────
    // Acoustic tiles in grey, a converging seam grid, and the fluorescent
    // fittings receding down the hall for as long as the power holds.
    function drawCeiling(dc, w, h, horizon, lightPct, tex) {
        if (horizon <= 0) { return; }
        var r = Br.ceilRamp();
        var dim = Br.lightStep(lightPct);
        var bands = r.size();
        var cx = w / 2;

        // Bands follow the perspective rows rather than dividing the screen
        // evenly: near the horizon a lot of ceiling is packed into very few
        // pixels, and shading it linearly is what made the old frame look like
        // a striped awning instead of a corridor.
        for (var i = 0; i < bands; i++) {
            var yFar = horizon - _row(i, bands, horizon);
            var yNear = horizon - _row(i + 1, bands, horizon);
            if (yNear < 0) { yNear = 0; }
            rect(dc, 0, yNear, w, yFar - yNear, ramp(r, bands - 1 - i + dim));
        }

        if (tex >= 1 && dim < 4) {
            // Seam grid. Rows measured up from the horizon, verticals fanning
            // out from the vanishing point at the same rate. GRID_K sets the
            // tile size: too large and the first seam is already off the edge
            // of the screen, which is a lot of arithmetic for no picture.
            for (var k = 1; k <= GRID_ROWS; k++) {
                var d = _row(k, GRID_ROWS, horizon);
                var y = horizon - d;
                if (y < 0) { break; }
                var segH = d - _row(k - 1, GRID_ROWS, horizon);
                if (segH < 1) { segH = 1; }
                rect(dc, 0, y, w, 1, Br.CEIL_GRID);
                for (var j = 1; j <= 3; j++) {
                    var off = j * w * d / (horizon * GRID_K);
                    if (off > w / 2) { break; }
                    rect(dc, cx - off, y, 1, segH, Br.CEIL_GRID);
                    rect(dc, cx + off, y, 1, segH, Br.CEIL_GRID);
                }
            }
        }

        // Fluorescent fittings: bright tube in a dark housing, shrinking away.
        if (lightPct > 30) {
            var tube = (lightPct > 55) ? Br.PANEL : Br.PANEL_D;
            for (var p = 1; p <= 4; p++) {
                var dp = _row(p, 5, horizon);
                var py = horizon - dp;
                var pw = w * dp / (horizon * 2);
                if (pw < 5) { continue; }
                var ph = dp / 9 + 2;
                rect(dc, cx - pw / 2 - 1, py - 1, pw + 2, ph + 2, Br.CEIL_HOUS);
                rect(dc, cx - pw / 2, py, pw, ph, tube);
            }
        }
    }

    // ── Floor ────────────────────────────────────────────────────────────────
    // Damp brown carpet, banded by distance, with the same converging grid so
    // the two planes agree about where the vanishing point is.
    function drawFloor(dc, w, h, horizon, lightPct, tex) {
        var fh = h - horizon;
        if (fh <= 0) { return; }
        var r = Br.floorRamp();
        var r2 = Br.floorRamp2();
        var dim = Br.lightStep(lightPct);
        var bands = r.size();
        var cx = w / 2;

        for (var j = 0; j < bands; j++) {
            var g0 = horizon + _row(j, bands, fh);
            var g1 = horizon + _row(j + 1, bands, fh);
            if (g1 > h) { g1 = h; }
            // Ramp runs far → near, so darkness eats it from the horizon back.
            rect(dc, 0, g0, w, g1 - g0, ramp(r, j - dim));
        }

        if (tex >= 1 && dim < 4) {
            for (var k = 1; k <= GRID_ROWS; k++) {
                var d = _row(k, GRID_ROWS, fh);
                var y = horizon + d;
                if (y >= h) { break; }
                var segH = d - _row(k - 1, GRID_ROWS, fh);
                if (segH < 1) { segH = 1; }
                rect(dc, 0, y, w, 1, Br.FLOOR_GRID);
                // Pile: a woven scanline in the darker tone, only close enough
                // to the camera that the rows are actually resolvable.
                if (tex >= 2 && segH > 5) {
                    ditherRect(dc, 0, y + 1, w, segH - 1,
                               ramp(r2, bands * k / GRID_ROWS - dim), 3);
                }
                for (var j2 = 1; j2 <= 3; j2++) {
                    var off = j2 * w * d / (fh * GRID_K);
                    if (off > w / 2) { break; }
                    rect(dc, cx - off, y, 1, segH, Br.FLOOR_GRID);
                    rect(dc, cx + off, y, 1, segH, Br.FLOOR_GRID);
                }
            }
        }

        // Every fitting overhead drops a pool of light on the carpet under it,
        // at the same depths the fittings are drawn at. Without them the two
        // planes are unrelated and the hall has no rhythm to walk down — you
        // cannot tell you are covering ground, which is the one thing the
        // corridor has to communicate.
        if (lightPct > 30 && dim < 3) {
            var glow = (lightPct > 55) ? 0xFFAA55 : 0xAA5500;
            // Stops short of the very bottom: the last pool would otherwise be
            // a slab of light across the whole near carpet, and the HUD sits
            // on top of it.
            var last = horizon + fh * 74 / 100;
            for (var p = 1; p <= 4; p++) {
                var dp = _row(p, 5, fh);
                var py = horizon + dp;
                if (py >= last) { break; }
                var pw = w * dp / (fh * 2) * 8 / 5;
                var ph = dp / 6 + 2;
                if (pw < 6) { continue; }
                if (py + ph > last) { ph = last - py; }
                ditherRect(dc, cx - pw / 2, py, pw, ph, glow, 4);
                ditherRect(dc, cx - pw / 4, py, pw / 2, ph, glow, 2);
            }
        }
    }

    // ── Walls ────────────────────────────────────────────────────────────────
    // One to five rects per column. `torch` is the beam half-width in columns
    // (0 = off) and brightens the middle of the view by up to two ramp steps.
    function drawWalls(dc, w, h, horizon, rc, level, lightPct, stretch, tex, torch) {
        var cols = rc.cols;
        var wr = Br.wallRamp(level);
        var dim = Br.lightStep(lightPct);
        var baseH = h * Br.WALL_SCALE * (100 + stretch) / 10000;
        var cap = h * Br.WALL_CAP / 100;
        var mid = cols / 2;
        var prevFace = -99999;
        var prevDrop = -1;

        // World depth of each ceiling fitting, from the screen row it is drawn
        // at: a plane at eye height projects to dy = baseH / (2 * depth), so
        // inverting the row that drawCeiling used gives the depth back.
        var lit = (lightPct > 30 && dim < 3);
        if (lit) {
            if (_lampD == null) { _lampD = new [4]; }
            for (var p = 0; p < 4; p++) {
                var dy = _row(p + 1, 5, horizon);
                _lampD[p] = (dy < 1) ? 99.0 : baseH / (2.0 * dy);
            }
        }

        for (var c = 0; c < cols; c++) {
            var perp = rc.dist[c];
            if (perp >= 55.0) { prevFace = -99999; continue; }

            var x0 = c * w / cols;
            var x1 = (c + 1) * w / cols;
            var cw = x1 - x0;
            if (cw < 1) { cw = 1; }

            var lh = (baseH / perp).toNumber();
            if (lh > cap) { lh = cap; }
            var y0 = horizon - lh / 2;
            var y1 = horizon + lh / 2;
            var dy0 = (y0 < 0) ? 0 : y0;
            var dy1 = (y1 > h) ? h : y1;
            if (dy1 <= dy0) { prevFace = -99999; continue; }

            // Distance fog, then face shading, then local darkness.
            var step = Br.fogStep(perp) + dim;
            if (rc.side[c] == 1) { step += 1; }
            if (rc.dark[c] == 1) { step += 3; }

            // Torch beam: strongest dead ahead, and only reaches so far.
            if (torch > 0) {
                var d = c - mid;
                if (d < 0) { d = -d; }
                if (d < torch && perp < 9.0) {
                    step -= (d < torch / 2) ? 2 : 1;
                }
            }

            // Is this column standing under one of the fittings? Without it the
            // walls fade smoothly with distance while the floor pulses under
            // each lamp, and the two planes look like they were lit by
            // different suns.
            var lamp = false;
            if (lit && perp < 12.0) {
                for (var p = 0; p < 4; p++) {
                    var gap = perp - _lampD[p];
                    if (gap < 0) { gap = -gap; }
                    if (gap < _lampD[p] / 4 + 0.35) { lamp = true; break; }
                }
            }

            var gx = rc.cx[c];
            var gy = rc.cy[c];
            var wx = rc.texX[c];
            var face = gx * 961 + gy * 31 + rc.side[c];

            // Wallpaper hangs in three vertical drops per cell face. Alternate
            // drops sit a shade apart, and the join between them is drawn on
            // the single column where the drop index changes — deriving it
            // from "is the offset small" instead puts the seam on two
            // neighbouring columns, which reads as a stripe rather than a join.
            var drop = (wx * 3).toNumber();
            if (drop > 2) { drop = 2; }
            var seam = (tex >= 1 && perp < 8.0)
                    && (face != prevFace || drop != prevDrop);
            if (tex >= 1 && perp < 7.0 && ((drop + gx + gy) & 1) == 0) {
                step += 1;
            }
            // Grain: a stable per-patch speckle keyed off the cell, so it sticks
            // to the wall as you walk instead of crawling across the screen.
            if (tex >= 2 && perp < 5.0) {
                if (((gx * 73 + gy * 151 + drop * 29) & 7) == 0) { step += 1; }
            }

            var body = ramp(wr, step);
            var rail = y0 + lh * 34 / 100;
            var skirt = y1 - lh / 9;

            if (lh < 22 || tex < 1) {
                rect(dc, x0, dy0, cw, dy1 - dy0, body);
            } else {
                // Picture rail sits about a third down, skirting at the bottom;
                // the band between them is the wainscot and takes a shade more.
                var lineH = lh / 26;
                if (lineH < 1) { lineH = 1; }

                _band(dc, x0, cw, dy0, rail, h, body);
                _band(dc, x0, cw, rail, rail + lineH, h, ramp(wr, step + 3));
                _band(dc, x0, cw, rail + lineH, skirt, h, ramp(wr, step + 1));
                _band(dc, x0, cw, skirt, dy1, h, ramp(wr, step + 3));

                // Spill from the fitting overhead, brightest where the wall
                // meets the ceiling and gone by the rail. Lifting the whole
                // column instead makes a lamp look like a doorway.
                if (lamp) {
                    _band(dc, x0, cw, dy0, y0 + lh / 6, h, ramp(wr, step - 2));
                    _band(dc, x0, cw, y0 + lh / 6, y0 + lh / 3, h,
                          ramp(wr, step - 1));
                }

                // The wainscot is boarded, not papered. Three battens across it
                // give the lower wall the fine structure that the blank drop
                // above the rail deliberately lacks, so the two read as
                // different materials rather than as one slab in two tones.
                if (tex >= 1 && perp < 7.0 && skirt - rail > 24) {
                    var bt = lineH;
                    if (bt > 3) { bt = 3; }
                    for (var b = 1; b < 4; b++) {
                        var by = rail + (skirt - rail) * b / 4;
                        _band(dc, x0, cw, by, by + bt, h, ramp(wr, step + 2));
                    }
                }
            }

            // Water damage, high on the wall where it belongs. Kept to a single
            // ramp step: any darker and it reads as a doorway, which on a floor
            // where doorways matter is a genuinely cruel thing to draw.
            if (tex >= 1 && ((gx * 7 + gy * 13) % 5) == 0 && lh > 26 && lh < cap) {
                var stH = lh / 7;
                var stY = y0 + lh / 8;
                _band(dc, x0, cw, stY, stY + stH, h, ramp(wr, step + 1));
            }

            if (tex >= 1 && lh > 30 && perp < 6.0) {
                _fixture(dc, x0, cw, h, y0, y1, lh, rail, skirt, wx,
                         gx * 131 + gy * 47 + rc.side[c] * 7, wr, step);
            }

            if (seam) {
                rect(dc, x0, dy0, 1, dy1 - dy0, ramp(wr, step + 2));
            }
            // Corner: the column where the ray switched to a different face.
            // A single dark pixel line here does more for readability than any
            // amount of shading, because it restores the silhouette.
            if (prevFace != -99999 && face != prevFace) {
                rect(dc, x0, dy0, 1, dy1 - dy0, ramp(wr, step + 4));
            }
            prevFace = face;
            prevDrop = drop;
        }
    }

    // One piece of wall furniture per cell face, placed by a hash of the cell.
    // Blank wallpaper is the whole point of the setting, but a corridor with
    // nothing on it at all also has nothing for the eye to measure movement
    // against — these are what make one hallway distinguishable from the next.
    function _fixture(dc, x0, cw, h, y0, y1, lh, rail, skirt, wx, key, wr, step) {
        var kind = key % 17;

        if (kind == 3) {
            // Air vent, sitting just under the picture rail.
            if (wx < 0.30 || wx > 0.60) { return; }
            var vh = lh / 9;
            if (vh < 4) { return; }
            var vy = rail - vh - lh / 22;
            _band(dc, x0, cw, vy, vy + vh, h, ramp(wr, step + 4));
            _band(dc, x0, cw, vy, vy + 1, h, ramp(wr, step + 2));
            for (var s = 1; s < 4; s++) {
                var sy = vy + vh * s / 4;
                _band(dc, x0, cw, sy, sy + 1, h, ramp(wr, step + 1));
            }

        } else if (kind == 7) {
            // Socket on the skirting.
            if (wx < 0.46 || wx > 0.54) { return; }
            var oh = lh / 16;
            if (oh < 3) { return; }
            var oy = skirt - oh - lh / 40;
            _band(dc, x0, cw, oy, oy + oh, h, ramp(wr, step + 4));

        } else if (kind == 11) {
            // Wallpaper peeling off the wall. The flap is a wedge, so its lower
            // edge slides down as the column walks across the face — that is
            // what stops it reading as another rectangle of trim.
            if (wx < 0.55 || wx > 0.85) { return; }
            var t = ((wx - 0.55) * 100).toNumber();       // 0..30 across the flap
            var ph = lh * (30 - t) / 220;
            if (ph < 3) { return; }
            var py2 = y0 + lh / 5;
            _band(dc, x0, cw, py2, py2 + ph, h, ramp(wr, step + 5));
            _band(dc, x0, cw, py2 + ph, py2 + ph + 1, h, ramp(wr, step + 2));

        } else if (kind == 14) {
            // Scuffs where trolleys have clipped the skirting for decades.
            if (wx < 0.20 || wx > 0.80) { return; }
            var sh = lh / 20;
            if (sh < 2) { return; }
            _band(dc, x0, cw, skirt - sh, skirt, h, ramp(wr, step + 2));
        }
    }

    // Clipped horizontal slice of a wall column.
    function _band(dc, x, w, ya, yb, h, col) {
        if (ya < 0) { ya = 0; }
        if (yb > h) { yb = h; }
        if (yb <= ya) { return; }
        rect(dc, x, ya, w, yb - ya, col);
    }

    // ── Billboards ───────────────────────────────────────────────────────────
    // Returns null when the thing is behind you or hidden by a wall.
    function project(w, h, rc, p, ex, ey) {
        var sx = ex - p.x;
        var sy = ey - p.y;
        var det = p.planeX * p.dirY - p.dirX * p.planeY;
        if (det == 0.0) { return null; }
        var inv = 1.0 / det;
        var tx = inv * (p.dirY * sx - p.dirX * sy);
        var ty = inv * (-p.planeY * sx + p.planeX * sy);
        if (ty < 0.30) { return null; }

        var scrX = ((w / 2) * (1.0 + tx / ty)).toNumber();
        if (scrX < -w || scrX > w * 2) { return null; }

        var col = scrX * rc.cols / w;
        if (col < 0) { col = 0; }
        if (col >= rc.cols) { col = rc.cols - 1; }
        if (ty > rc.dist[col] + 0.15) { return null; }

        var size = (h * 78 / 100 / ty).toNumber();
        return [scrX, size, ty];
    }

    // Exit and mimic share this sprite on purpose — you cannot tell them apart
    // until you touch one.
    function drawDoor(dc, x, y0, size, lightPct) {
        var dw = size * 44 / 100;
        if (dw < 5) { dw = 5; }
        var dh = size * 78 / 100;
        if (dh < 7) { dh = 7; }
        var dx = x - dw / 2;
        var dy = y0 + size - dh;
        var jamb = dw / 7;
        if (jamb < 1) { jamb = 1; }

        // Frame, then the dark of the doorway itself.
        rect(dc, dx - jamb, dy - jamb, dw + jamb * 2, dh + jamb, 0xAAAA55);
        rect(dc, dx, dy, dw, dh, 0x000000);
        // Light spilling out around the edges of whatever is beyond.
        rect(dc, dx, dy, dw, dh / 14 + 1, 0x555500);

        // EXIT sign in its housing, and the glow it throws on the carpet.
        var sw = dw * 76 / 100;
        var sh = dh / 7;
        if (sh < 2) { sh = 2; }
        var sy = dy - jamb - sh - 2;
        rect(dc, x - sw / 2 - 1, sy - 1, sw + 2, sh + 2, 0x000000);
        rect(dc, x - sw / 2, sy, sw, sh, 0x55FF55);
        if (size > 40) {
            ditherRect(dc, dx - jamb, y0 + size, dw + jamb * 2, size / 12,
                       0x55AA55, 2);
        }
    }

    function drawEntity(dc, kind, x, y0, size, fade, state, lightPct, t) {
        if (fade < 22) { return; }
        var step = (fade >= 95) ? 1 : ((fade >= 55) ? 2 : 3);

        var bw = size * 26 / 100;
        if (bw < 3) { bw = 3; }
        var bh = size * 70 / 100;
        if (bh < 6) { bh = 6; }
        var bx = x - bw / 2;
        var by = y0 + size - bh;

        if (kind == Br.E_SHADOW) {
            // A hole in the picture with tendrils, wider at the floor.
            ditherRect(dc, bx, by, bw, bh, 0x000000, step);
            ditherRect(dc, bx - bw / 3, by + bh / 2, bw * 5 / 3, bh / 2,
                       0x000000, step);
            var tw = bw / 4;
            if (tw < 1) { tw = 1; }
            for (var i = -2; i <= 2; i++) {
                var tl = bh / 3 + ((i * 7 + t / 3) % 5) * bh / 24;
                ditherRect(dc, x + i * bw / 2 - tw / 2, by + bh - tl, tw, tl,
                           0x000000, step);
            }
            if (state == 1) {
                var ew = bw / 5;
                if (ew < 1) { ew = 1; }
                rect(dc, bx + bw / 4 - ew / 2, by + bh / 10, ew, ew, 0xFF5555);
                rect(dc, bx + bw * 3 / 4 - ew / 2, by + bh / 10, ew, ew, 0xFF5555);
            }
            return;
        }

        if (kind == Br.E_MIMIC) {
            drawDoor(dc, x, y0, size, lightPct);
            // The frame is wrong. It was always wrong.
            var mw = size * 50 / 100;
            var mh = size * 86 / 100;
            ditherRect(dc, x - mw / 2, y0 + size - mh, mw, mh, 0x000000, 3);
            return;
        }

        // The Stalker: a person-shaped absence at the end of the hall. Drawn
        // limb by limb, because a plain rectangle reads as scenery and this
        // must read as somebody.
        var sway = ((t / 4) % 3) - 1;
        var hr = bw / 2;
        if (hr < 2) { hr = 2; }
        var torsoH = bh * 52 / 100;
        var legH = bh - torsoH - hr;
        if (legH < 2) { legH = 2; }

        ditherRect(dc, bx, by + hr, bw, torsoH, 0x000000, step);          // torso
        var aw = bw / 4;
        if (aw < 1) { aw = 1; }
        ditherRect(dc, bx - aw, by + hr + torsoH / 6, aw, torsoH * 3 / 4,
                   0x000000, step);                                        // arms
        ditherRect(dc, bx + bw, by + hr + torsoH / 6, aw, torsoH * 3 / 4,
                   0x000000, step);
        var lw = bw * 2 / 5;
        if (lw < 1) { lw = 1; }
        ditherRect(dc, bx + sway, by + hr + torsoH, lw, legH, 0x000000, step);
        ditherRect(dc, bx + bw - lw - sway, by + hr + torsoH, lw, legH,
                   0x000000, step);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, by + hr, hr);                                     // head
    }

    function drawPickup(dc, kind, x, y0, size, lightPct, t) {
        var s = size * 20 / 100;
        if (s < 3) { s = 3; }
        // Everything on the floor breathes a little, so it catches the eye.
        var lift = ((t / 5) % 2);
        var yy = y0 + size - s * 2 - lift;

        if (kind == Br.SP_KEY) {
            rect(dc, x - s / 3, yy + s / 2, s * 3 / 2, s / 3 + 1, 0xFFAA00);
            rect(dc, x + s, yy + s / 2, s / 3 + 1, s, 0xFFAA00);
            rect(dc, x + s / 2, yy + s / 2, s / 4 + 1, s * 2 / 3, 0xFFAA00);
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - s / 2, yy + s * 2 / 3, s / 2 + 1);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - s / 2, yy + s * 2 / 3, s / 4);

        } else if (kind == Br.SP_SANITY) {
            // Almond water: white bottle, blue cap, a band for the label.
            rect(dc, x - s / 2, yy + s / 3, s, s * 5 / 3, 0xFFFFFF);
            rect(dc, x - s / 4, yy, s / 2, s / 2, 0x55AAFF);
            rect(dc, x - s / 2, yy + s, s, s / 2, 0x55AAFF);

        } else if (kind == Br.SP_CELL) {
            // Spare cell for the torch.
            rect(dc, x - s / 2, yy + s / 3, s, s * 3 / 2, 0x00AA00);
            rect(dc, x - s / 2, yy + s / 3, s, s / 2, 0x555555);
            rect(dc, x - s / 6, yy + s / 6, s / 3, s / 5 + 1, 0xAAAAAA);

        } else if (kind == Br.SP_RELIC) {
            // Artifact: a small impossible object that will not stay still.
            dc.setColor(0xAA55FF, Graphics.COLOR_TRANSPARENT);
            var q = s * 3 / 4;
            if (q < 2) { q = 2; }
            dc.fillPolygon([[x, yy], [x + q, yy + q], [x, yy + q * 2],
                            [x - q, yy + q]]);
            if ((t / 4) % 3 != 0) {
                rect(dc, x - 1, yy - s / 2, 2, s / 3 + 1, 0xFFAAFF);
                rect(dc, x - q - s / 3, yy + q - 1, s / 3 + 1, 2, 0xFFAAFF);
            }
        }
    }

    // ── Post effects ─────────────────────────────────────────────────────────
    function drawGlitch(dc, w, h, amount, t) {
        if (amount <= 0) { return; }
        var bands = amount / 22 + 1;
        var s = t * 7919 + amount;
        for (var i = 0; i < bands; i++) {
            s = MapGen.nextRand(s);
            var y = s % h;
            s = MapGen.nextRand(s);
            var bh = 1 + (s % 4);
            s = MapGen.nextRand(s);
            var off = (s % 17) - 8;
            rect(dc, off, y, w, bh, 0x000000);
            s = MapGen.nextRand(s);
            if ((s % 3) == 0) {
                rect(dc, off + 6, y + bh, w, 1, 0x555500);
            }
        }
    }

    // Interlace the view. Cheap, and it makes the whole frame feel like it is
    // coming off a dying CRT. Spaced at six rather than four: at four the lines
    // land close enough together to swallow the ceiling tile seams, and the
    // ceiling stops reading as a grid at all.
    function drawScanlines(dc, w, h) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        for (var y = 0; y < h; y += 6) {
            dc.fillRectangle(0, y, w, 1);
        }
    }


    // Cheap CRT falloff so the round bezel reads as darkness, not a cut-off.
    function drawVignette(dc, w, h) {
        var cx = w / 2; var cy = h / 2;
        var r = (w < h) ? w / 2 : h / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(10);
        dc.drawCircle(cx, cy, r - 2);
        dc.setPenWidth(6);
        dc.drawCircle(cx, cy, r - 11);
        dc.setPenWidth(3);
        dc.drawCircle(cx, cy, r - 16);
        dc.setPenWidth(1);
    }
}
