// ═══════════════════════════════════════════════════════════════════════════
// MapGenerator.mc — Procedural Backrooms floors from a single seed.
//
// The same seed always builds the same floor, which is what makes the daily
// challenge fair and lets a saved run be restored from ~8 numbers instead of a
// whole grid. Rows are stored as bitmasks (one Number per row) so a 24×24 floor
// costs 48 Numbers, not 576.
//
// Layout recipe: scatter overlapping rooms, thread L-corridors between them,
// drop pillars, then place the exit far from the spawn, a mimic that wears the
// same face, a locked door with its key stranded somewhere else, and pickups.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

class BrMap {
    var w; var h;
    var walls;        // Array<Number> — bit x set = solid
    var dark;         // Array<Number> — bit x set = unlit zone
    var sp;           // Array<Array> — [x, y, kind, taken]
    var rooms;        // Array<Array> — [x, y, w, h]
    var seenRooms;    // bitmask of visited rooms
    var startX; var startY; var startAng;
    var seed; var level;

    function initialize(ww, hh) {
        w = ww; h = hh;
        walls = new [h];
        dark = new [h];
        for (var y = 0; y < h; y++) { walls[y] = 0; dark[y] = 0; }
        sp = []; rooms = []; seenRooms = 0;
        startX = 1; startY = 1; startAng = 0.0;
        seed = 0; level = 0;
    }

    function isWall(x, y) {
        if (x < 0 || y < 0 || x >= w || y >= h) { return true; }
        return (walls[y] & (1 << x)) != 0;
    }
    function setWall(x, y) {
        if (x < 0 || y < 0 || x >= w || y >= h) { return; }
        walls[y] = walls[y] | (1 << x);
    }
    function clearWall(x, y) {
        if (x < 0 || y < 0 || x >= w || y >= h) { return; }
        walls[y] = walls[y] & ~(1 << x);
    }
    function isDark(x, y) {
        if (x < 0 || y < 0 || x >= w || y >= h) { return false; }
        return (dark[y] & (1 << x)) != 0;
    }
    function setDark(x, y) {
        if (x < 0 || y < 0 || x >= w || y >= h) { return; }
        dark[y] = dark[y] | (1 << x);
    }

    // Index into `sp` for a still-untaken special on this cell, or -1.
    function specialAt(x, y) {
        for (var i = 0; i < sp.size(); i++) {
            var s = sp[i];
            if (s[0] == x && s[1] == y && s[3] == 0) { return i; }
        }
        return -1;
    }

    // Mark the room containing (x,y) as discovered. Returns true the first time.
    function visit(x, y) {
        for (var i = 0; i < rooms.size() && i < 16; i++) {
            var r = rooms[i];
            if (x >= r[0] && x < r[0] + r[2] && y >= r[1] && y < r[1] + r[3]) {
                var bit = 1 << i;
                if ((seenRooms & bit) == 0) { seenRooms = seenRooms | bit; return true; }
                return false;
            }
        }
        return false;
    }
    function roomsSeen() {
        var n = 0; var m = seenRooms;
        while (m != 0) { n += m & 1; m = m >> 1; }
        return n;
    }
}

module MapGen {

    // 32-bit LCG. Kept module-level so map, waves and events can share one
    // reproducible stream from the run seed.
    function nextRand(s) {
        return (s * 1103515245 + 12345) & 0x7FFFFFFF;
    }

    // Deterministic seed for a calendar day (daily challenge).
    function dailySeed(dayNumber) {
        return (dayNumber * 7919 + 104729) & 0x7FFFFFFF;
    }

    function generate(seed, level) as BrMap {
        var m = new BrMap(Br.MAP_W, Br.MAP_H);
        m.seed = seed;
        m.level = level;

        // Solid rock to start with.
        var full = (1 << Br.MAP_W) - 1;
        for (var y = 0; y < m.h; y++) { m.walls[y] = full; }

        var s = (seed ^ (level * 68917 + 13)) & 0x7FFFFFFF;

        // One room per sector of a 3×3 grid. Scattering them this way (rather
        // than at random) is what makes the connecting corridors long: you walk
        // for a while between rooms, which is the whole point of the Backrooms.
        var roomN = 7 + level / 3;
        if (roomN > 9) { roomN = 9; }
        var sec = m.w / 3;

        var px = 0; var py = 0;
        for (var i = 0; i < roomN; i++) {
            var sx0 = (i % 3) * sec;
            var sy0 = (i / 3) * sec;
            if (sy0 > m.h - sec) { sy0 = m.h - sec; }

            s = nextRand(s); var rw = 3 + (s % 4);
            s = nextRand(s); var rh = 3 + (s % 3);
            s = nextRand(s); var rx = sx0 + 1 + (s % (sec - rw));
            s = nextRand(s); var ry = sy0 + 1 + (s % (sec - rh));
            if (rx + rw > m.w - 1) { rx = m.w - 1 - rw; }
            if (ry + rh > m.h - 1) { ry = m.h - 1 - rh; }
            if (rx < 1) { rx = 1; }
            if (ry < 1) { ry = 1; }

            for (var yy = ry; yy < ry + rh; yy++) {
                for (var xx = rx; xx < rx + rw; xx++) { m.clearWall(xx, yy); }
            }
            m.rooms.add([rx, ry, rw, rh]);

            var cx = rx + rw / 2; var cy = ry + rh / 2;
            if (i > 0) { _corridor(m, px, py, cx, cy, s); }
            px = cx; py = cy;

            // A lone pillar makes a room read as a *space* rather than a box.
            s = nextRand(s);
            if (rw >= 4 && rh >= 4 && (s % 100) < 55) {
                m.setWall(rx + 1, ry + 1);
            }
        }

        // Unlit zones — the Shadow's hunting ground.
        var darkN = 1 + level / 2;
        if (darkN > 4) { darkN = 4; }
        for (var d = 0; d < darkN && m.rooms.size() > 1; d++) {
            s = nextRand(s);
            var ri = 1 + (s % (m.rooms.size() - 1));
            var r = m.rooms[ri];
            for (var dy = r[1]; dy < r[1] + r[3]; dy++) {
                for (var dx = r[0]; dx < r[0] + r[2]; dx++) { m.setDark(dx, dy); }
            }
        }

        // Spawn in the first room, facing whichever cardinal has the longest
        // open run — waking up nose-first against wallpaper reads as a bug even
        // when it is technically correct.
        var r0 = m.rooms[0];
        m.startX = r0[0] + r0[2] / 2;
        m.startY = r0[1] + r0[3] / 2;
        var bestD = 0; var bestLen = -1;
        for (var d = 0; d < 4; d++) {
            var dx = 0; var dy = 0;
            if (d == 0) { dx = 1; }
            else if (d == 1) { dy = 1; }
            else if (d == 2) { dx = -1; }
            else { dy = -1; }
            var len = 0;
            var tx = m.startX; var ty = m.startY;
            while (len < 12) {
                tx += dx; ty += dy;
                if (m.isWall(tx, ty)) { break; }
                len += 1;
            }
            if (len > bestLen) { bestLen = len; bestD = d; }
        }
        m.startAng = bestD * 1.5708;

        // One extra link back to an earlier room turns the snake into a loop,
        // so there is always a shortcut you have not found yet.
        if (m.rooms.size() >= 4) {
            s = nextRand(s);
            var ra = m.rooms[s % 2];
            var rb = m.rooms[m.rooms.size() - 1 - (s % 2)];
            _corridor(m, ra[0] + ra[2] / 2, ra[1] + ra[3] / 2,
                         rb[0] + rb[2] / 2, rb[1] + rb[3] / 2, s);
        }

        // The way out sits in the last room carved — the far corner of the map.
        var rl = m.rooms[m.rooms.size() - 1];
        _addSp(m, rl[0] + rl[2] / 2, rl[1] + rl[3] / 2, Br.SP_EXIT);

        // A mimic wears the same sign somewhere in the middle of the floor.
        if (level >= 1 && m.rooms.size() >= 3) {
            s = nextRand(s);
            var rm = m.rooms[1 + (s % (m.rooms.size() - 2))];
            _addSp(m, rm[0], rm[1] + rm[3] / 2, Br.SP_MIMIC);
        }

        // A locked door in front of the exit room, key stranded elsewhere.
        if (level >= 2 && m.rooms.size() >= 3) {
            var dx2 = rl[0] - 1;
            var dy2 = rl[1] + rl[3] / 2;
            if (!m.isWall(dx2, dy2)) {
                m.setWall(dx2, dy2);
                _addSp(m, dx2, dy2, Br.SP_DOOR);
                s = nextRand(s);
                var rk = m.rooms[s % (m.rooms.size() - 1)];
                _addSp(m, rk[0] + rk[2] / 2, rk[1], Br.SP_KEY);
            }
        }

        // Almond water keeps you standing; artifacts are why you came.
        var waterN = 2 + level / 3;
        if (waterN > 4) { waterN = 4; }
        for (var wi = 0; wi < waterN && m.rooms.size() > 1; wi++) {
            s = nextRand(s);
            var rwr = m.rooms[1 + (s % (m.rooms.size() - 1))];
            s = nextRand(s);
            var wx = rwr[0] + (s % rwr[2]);
            s = nextRand(s);
            var wy = rwr[1] + (s % rwr[3]);
            if (!m.isWall(wx, wy) && m.specialAt(wx, wy) < 0) {
                _addSp(m, wx, wy, Br.SP_SANITY);
            }
        }
        // Spare cells for the torch. Deliberately thin on the ground: the beam
        // is meant to be a decision, not a default.
        var cellN = 1 + level / 3;
        if (cellN > 3) { cellN = 3; }
        for (var ci = 0; ci < cellN && m.rooms.size() > 1; ci++) {
            s = nextRand(s);
            var rcl = m.rooms[1 + (s % (m.rooms.size() - 1))];
            var bx2 = rcl[0] + rcl[2] - 1;
            var by2 = rcl[1];
            if (!m.isWall(bx2, by2) && m.specialAt(bx2, by2) < 0) {
                _addSp(m, bx2, by2, Br.SP_CELL);
            }
        }

        s = nextRand(s);
        if ((s % 100) < 45 + level * 5 && m.rooms.size() > 2) {
            s = nextRand(s);
            var rr = m.rooms[1 + (s % (m.rooms.size() - 1))];
            var ax = rr[0] + rr[2] - 1; var ay = rr[1] + rr[3] - 1;
            if (!m.isWall(ax, ay) && m.specialAt(ax, ay) < 0) {
                _addSp(m, ax, ay, Br.SP_RELIC);
            }
        }

        return m;
    }

    function _addSp(m, x, y, kind) {
        if (x < 1) { x = 1; }
        if (y < 1) { y = 1; }
        if (x > m.w - 2) { x = m.w - 2; }
        if (y > m.h - 2) { y = m.h - 2; }
        if (kind != Br.SP_DOOR) { m.clearWall(x, y); }
        m.sp.add([x, y, kind, 0]);
    }

    // L-shaped corridor, horizontal or vertical leg first depending on the seed.
    function _corridor(m, x0, y0, x1, y1, s) {
        if ((s & 1) == 0) {
            _carveH(m, x0, x1, y0);
            _carveV(m, y0, y1, x1);
        } else {
            _carveV(m, y0, y1, x0);
            _carveH(m, x0, x1, y1);
        }
    }
    function _carveH(m, xa, xb, y) {
        var lo = (xa < xb) ? xa : xb;
        var hi = (xa < xb) ? xb : xa;
        for (var x = lo; x <= hi; x++) { m.clearWall(x, y); }
    }
    function _carveV(m, ya, yb, x) {
        var lo = (ya < yb) ? ya : yb;
        var hi = (ya < yb) ? yb : ya;
        for (var y = lo; y <= hi; y++) { m.clearWall(x, y); }
    }

    // A wall the floor can rearrange mid-run (the EV_SHIFT event). Opens one
    // solid cell next to the player and seals a different one further off, so
    // the map you memorised stops being the map you are standing in.
    function shiftWalls(m, px, py, s) {
        var opened = false;
        for (var t = 0; t < 8 && !opened; t++) {
            s = nextRand(s);
            var dx = px - 2 + (s % 5);
            s = nextRand(s);
            var dy = py - 2 + (s % 5);
            if (dx > 0 && dy > 0 && dx < m.w - 1 && dy < m.h - 1 && m.isWall(dx, dy)) {
                m.clearWall(dx, dy);
                opened = true;
            }
        }
        for (var t2 = 0; t2 < 8; t2++) {
            s = nextRand(s);
            var ex = 1 + (s % (m.w - 2));
            s = nextRand(s);
            var ey = 1 + (s % (m.h - 2));
            var far = (ex - px) * (ex - px) + (ey - py) * (ey - py);
            if (far > 25 && !m.isWall(ex, ey) && m.specialAt(ex, ey) < 0) {
                m.setWall(ex, ey);
                return s;
            }
        }
        return s;
    }
}
