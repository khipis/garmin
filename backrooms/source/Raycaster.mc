// ═══════════════════════════════════════════════════════════════════════════
// Raycaster.mc — Wolfenstein-style DDA grid caster.
//
// One ray per screen column-band (20/30/42 depending on the DETAIL option).
// Every output array is allocated once and rewritten in place: a horror game
// that stutters is a comedy, and per-frame allocation is what makes Monkey C
// stutter.
//
// Outputs, parallel per column:
//   dist  perpendicular distance (fisheye-corrected)
//   side  0 = we entered through an N/S face, 1 = an E/W face
//   texX  where along the wall face we hit, 0..1 (seams, panels)
//   cx/cy the grid cell that stopped the ray
//   dark  1 when that cell is an unlit zone
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

class Raycaster {
    var cols;
    var dist;
    var side;
    var texX;
    var cx;
    var cy;
    var dark;

    function initialize(n) {
        cols = 0;
        resize(n);
    }

    function resize(n) {
        if (n < 8) { n = 8; }
        if (n == cols) { return; }
        cols = n;
        dist = new [n];
        side = new [n];
        texX = new [n];
        cx = new [n];
        cy = new [n];
        dark = new [n];
        for (var i = 0; i < n; i++) {
            dist[i] = 99.0; side[i] = 0; texX[i] = 0.0;
            cx[i] = 0; cy[i] = 0; dark[i] = 0;
        }
    }

    // Cast the whole frame. dirX/dirY is the view vector, planeX/planeY the
    // camera plane (its length sets the FOV).
    function cast(map, px, py, dirX, dirY, planeX, planeY) as Void {
        var n = cols;
        var last = n - 1;
        if (last < 1) { last = 1; }

        for (var c = 0; c < n; c++) {
            // -1 at the left edge of the screen, +1 at the right.
            var camX = 2.0 * c / last - 1.0;
            var rdx = dirX + planeX * camX;
            var rdy = dirY + planeY * camX;

            var mx = px.toNumber();
            var my = py.toNumber();

            var ddx = 1000000.0;
            if (rdx != 0.0) { ddx = (rdx < 0.0) ? -1.0 / rdx : 1.0 / rdx; }
            var ddy = 1000000.0;
            if (rdy != 0.0) { ddy = (rdy < 0.0) ? -1.0 / rdy : 1.0 / rdy; }

            var stepX; var sdx;
            if (rdx < 0.0) { stepX = -1; sdx = (px - mx) * ddx; }
            else           { stepX =  1; sdx = (mx + 1.0 - px) * ddx; }
            var stepY; var sdy;
            if (rdy < 0.0) { stepY = -1; sdy = (py - my) * ddy; }
            else           { stepY =  1; sdy = (my + 1.0 - py) * ddy; }

            var hit = false;
            var sd = 0;
            var guard = 0;
            while (!hit && guard < Br.MAX_DDA) {
                guard += 1;
                if (sdx < sdy) { sdx += ddx; mx += stepX; sd = 0; }
                else           { sdy += ddy; my += stepY; sd = 1; }
                if (map.isWall(mx, my)) { hit = true; }
            }

            var perp;
            if (sd == 0) { perp = sdx - ddx; }
            else         { perp = sdy - ddy; }
            if (perp < 0.06) { perp = 0.06; }
            if (!hit) { perp = 60.0; }

            // Where along the face the ray landed — drives panel seams.
            var wx;
            if (sd == 0) { wx = py + perp * rdy; }
            else         { wx = px + perp * rdx; }
            wx = wx - wx.toNumber();
            if (wx < 0.0) { wx += 1.0; }

            dist[c] = perp;
            side[c] = sd;
            texX[c] = wx;
            cx[c] = mx;
            cy[c] = my;
            dark[c] = map.isDark(mx, my) ? 1 : 0;
        }
    }

    // Distance to the wall straight ahead — used for footstep echo and to stop
    // entities from spawning inside geometry.
    function centerDist() {
        if (dist == null || cols <= 0) { return 99.0; }
        return dist[cols / 2];
    }
}
