// ═══════════════════════════════════════════════════════════════════════════
// Raycaster.mc — Camera + lightweight Wolfenstein-style DDA raycaster.
//
// Grid movement keeps the camera on tile centres facing a cardinal direction,
// so the direction and camera-plane vectors are exact integers/constants and
// the whole cast runs without a single trig call. Results are cached by the
// view and only recomputed when the camera actually changes — the dungeon is
// turn based, so most frames are free.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;
using Toybox.Math;

const RC_MAX_STEPS = 22;      // ray abort distance in tiles
const RC_PLANE = 0.66;        // ~60° field of view

class Camera {
    var px;      // Float world position (tile centre)
    var py;
    var dir;     // DIR_N / DIR_E / DIR_S / DIR_W
    var dirX;    // facing vector (integers)
    var dirY;
    var planeX;  // camera plane (perpendicular, scaled by FOV)
    var planeY;

    function initialize() {
        px = 1.5;
        py = 1.5;
        setDir(DIR_E);
    }

    function moveTo(tx as Lang.Number, ty as Lang.Number) as Void {
        px = tx + 0.5;
        py = ty + 0.5;
    }

    function tileX() as Lang.Number { return px.toNumber(); }
    function tileY() as Lang.Number { return py.toNumber(); }

    function setDir(d as Lang.Number) as Void {
        dir = ((d % 4) + 4) % 4;
        if (dir == DIR_N)      { dirX =  0.0; dirY = -1.0; planeX =  RC_PLANE; planeY = 0.0; }
        else if (dir == DIR_E) { dirX =  1.0; dirY =  0.0; planeX =  0.0; planeY = RC_PLANE; }
        else if (dir == DIR_S) { dirX =  0.0; dirY =  1.0; planeX = -RC_PLANE; planeY = 0.0; }
        else                   { dirX = -1.0; dirY =  0.0; planeX =  0.0; planeY = -RC_PLANE; }
    }

    function turn(delta as Lang.Number) as Void { setDir(dir + delta); }

    // Tile directly ahead.
    function aheadX() as Lang.Number { return tileX() + dirX.toNumber(); }
    function aheadY() as Lang.Number { return tileY() + dirY.toNumber(); }
}

class Raycaster {

    var cols;      // number of sampled columns
    var colW;      // pixel width of one column
    var dist;      // Array<Float> perpendicular wall distance
    var side;      // 0 = x-side hit, 1 = y-side hit (used for shading)
    var kind;      // tile code that stopped the ray
    var wallX;     // Float 0..1 hit offset along the wall (brick seams / doors)
    var hitX;      // tile coords of the face that stopped the ray — the renderer
    var hitY;      // hashes these to place torches, moss, banners and cracks
    var projRatio; // last project() result — see project()
    var projDist;

    function initialize(screenW as Lang.Number) {
        // 5px columns: fine enough to read as a corridor, coarse enough that a
        // full cast stays cheap on the slowest supported hardware.
        colW = 5;
        cols = screenW / colW + 1;
        if (cols < 8) { cols = 8; }
        dist = new [cols];
        side = new [cols];
        kind = new [cols];
        wallX = new [cols];
        hitX = new [cols];
        hitY = new [cols];
        for (var i = 0; i < cols; i++) {
            dist[i] = 99.0;
            side[i] = 0;
            kind[i] = T_WALL;
            wallX[i] = 0.0;
            hitX[i] = 0;
            hitY[i] = 0;
        }
        projRatio = 0.0;
        projDist = 99.0;
    }

    function cast(map as DungeonMap, cam as Camera) as Void {
        var px = cam.px;
        var py = cam.py;
        for (var c = 0; c < cols; c++) {
            var camX = 2.0 * c / (cols - 1) - 1.0;
            var rdx = cam.dirX + cam.planeX * camX;
            var rdy = cam.dirY + cam.planeY * camX;

            var mapX = px.toNumber();
            var mapY = py.toNumber();

            var deltaX = 1.0e6;
            var deltaY = 1.0e6;
            if (rdx != 0.0) { deltaX = (1.0 / rdx).abs(); }
            if (rdy != 0.0) { deltaY = (1.0 / rdy).abs(); }

            var stepX = 1;
            var stepY = 1;
            var sideDistX;
            var sideDistY;
            if (rdx < 0.0) { stepX = -1; sideDistX = (px - mapX) * deltaX; }
            else           { stepX =  1; sideDistX = (mapX + 1.0 - px) * deltaX; }
            if (rdy < 0.0) { stepY = -1; sideDistY = (py - mapY) * deltaY; }
            else           { stepY =  1; sideDistY = (mapY + 1.0 - py) * deltaY; }

            var hitSide = 0;
            var hitKind = T_WALL;
            var hit = false;
            for (var s = 0; s < RC_MAX_STEPS && !hit; s++) {
                if (sideDistX < sideDistY) {
                    sideDistX += deltaX;
                    mapX += stepX;
                    hitSide = 0;
                } else {
                    sideDistY += deltaY;
                    mapY += stepY;
                    hitSide = 1;
                }
                if (map.isSolid(mapX, mapY)) {
                    hit = true;
                    hitKind = map.at(mapX, mapY);
                }
            }

            var perp;
            if (hitSide == 0) { perp = sideDistX - deltaX; }
            else              { perp = sideDistY - deltaY; }
            if (perp < 0.05) { perp = 0.05; }

            dist[c] = hit ? perp : 99.0;
            side[c] = hitSide;
            kind[c] = hitKind;
            hitX[c] = mapX;
            hitY[c] = mapY;

            // Where along the wall face the ray landed — drives brick seams and
            // keeps door panels centred.
            var wx;
            if (hitSide == 0) { wx = py + perp * rdy; }
            else              { wx = px + perp * rdx; }
            wallX[c] = wx - wx.toNumber();
        }
    }

    // Billboard projection for a sprite standing on tile centre (sx, sy).
    // Results land in projRatio (-1..1 across the view) and projDist rather than
    // a returned array, because this runs inside onUpdate and must not allocate.
    // Returns false when the sprite is behind the camera or off screen.
    function project(cam as Camera, sx as Lang.Number, sy as Lang.Number) as Lang.Boolean {
        var relX = (sx + 0.5) - cam.px;
        var relY = (sy + 0.5) - cam.py;
        var det = cam.planeX * cam.dirY - cam.dirX * cam.planeY;
        if (det == 0.0) { return false; }
        var inv = 1.0 / det;
        var tX = inv * (cam.dirY * relX - cam.dirX * relY);
        var tY = inv * (-cam.planeY * relX + cam.planeX * relY);
        if (tY < 0.25) { return false; }          // behind or on top of the camera
        var ratio = tX / tY;
        if (ratio < -1.6 || ratio > 1.6) { return false; }
        projRatio = ratio;
        projDist = tY;
        return true;
    }
}
