using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Game states ───────────────────────────────────────────────────────────────
const MG_MENU      = 0;
const MG_AIM       = 1;   // player rotating aim arrow + charging power
const MG_POWER     = 2;   // power bar filling
const MG_ROLLING   = 3;   // ball in motion
const MG_HOLED     = 4;   // ball sunk — show score, wait for tap
const MG_GAMEOVER  = 5;   // all 9 holes done

// ── Wall segment: [x1*10, y1*10, x2*10, y2*10] (coords in 0..1000 space) ────
// Course space is 0-1000 × 0-1000, rendered into game viewport at runtime.

class BitochiMinigolfView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    // Difficulty / level selection
    hidden var _difficulty;  // 0=Easy 1=Normal 2=Hard
    // 3 courses × 3 holes each = 9 holes total
    // Course 0 = holes 0-2, Course 1 = holes 3-5, Course 2 = holes 6-8
    hidden var _holeIdx;     // 0-8
    hidden var _strokes;     // strokes this hole
    hidden var _totalStrokes;
    hidden var _par;         // [9] par per hole

    // Ball state (in 0-1000 space ×10 = fixed-point 0-10000)
    hidden var _bx; hidden var _by;   // *10 fixed
    hidden var _vx; hidden var _vy;   // velocity *10
    hidden var _ballR;                // ball radius in course-space units (≈18)

    // Hole/cup position (course space)
    hidden var _hx; hidden var _hy;
    hidden var _holeR;   // hole radius

    // Tee (start) position
    hidden var _tx; hidden var _ty;

    // Aim
    hidden var _aimAngle;   // degrees 0-359
    hidden var _power;      // 0-100 (during power state, oscillates)
    hidden var _powerDir;   // 1 or -1

    // Walls: array of [x1,y1,x2,y2] in 0-1000 space (integers)
    hidden var _walls;

    // Course viewport mapping: course → screen
    hidden var _vpX; hidden var _vpY; hidden var _vpW; hidden var _vpH; hidden var _scale;

    // Obstacles (rect: [cx,cy,w,h] in 0-1000 space)
    hidden var _obstacles;

    // Water hazards ([cx,cy,r] in 0-1000 space)
    hidden var _water;

    // Post-hole state
    hidden var _holeMsg;
    hidden var _holeWait;

    // Score display per hole: [strokes] for holes 0-8
    hidden var _scoreCard;

    // ── COURSE DEFINITIONS ────────────────────────────────────────────────────
    // Each hole: [teeX,teeY, holeX,holeY, par, walls[], obstacles[], water[]]
    // Walls: [[x1,y1,x2,y2], ...] — boundary of the fairway

    // Course bounds always include outer boundary (auto-added in loadHole)

    // ── Initialize ────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _w = 0; _h = 0; _tick = 0;
        _gs = MG_MENU; _difficulty = 1;
        _holeIdx = 0; _strokes = 0; _totalStrokes = 0;
        _aimAngle = 0; _power = 0; _powerDir = 1;
        _ballR = 14; _holeR = 18;
        _par = [2, 2, 3, 2, 3, 3, 3, 3, 4];
        _scoreCard = new [9];
        for (var i = 0; i < 9; i++) { _scoreCard[i] = -1; }
        _walls = new [0]; _obstacles = new [0]; _water = new [0];
        _holeMsg = ""; _holeWait = 0;
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 50, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupVP();
    }

    hidden function setupVP() {
        // Leave HUD space: top ~22px, bottom ~20px
        var hudTop = 22; var hudBot = 20;
        _vpX = 4; _vpY = hudTop;
        _vpW = _w - 8; _vpH = _h - hudTop - hudBot;
        _scale = _vpW < _vpH ? _vpW : _vpH; // 1000 course units → _scale pixels
    }

    // ── Timer ─────────────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        if (_gs == MG_POWER) {
            _power += _powerDir * 4;
            if (_power >= 100) { _power = 100; _powerDir = -1; }
            if (_power <= 0)   { _power = 0;   _powerDir =  1; }
        }
        if (_gs == MG_ROLLING) { stepPhysics(); }
        if (_gs == MG_HOLED && _holeWait > 0) { _holeWait--; }
        WatchUi.requestUpdate();
    }

    // ── Physics ───────────────────────────────────────────────────────────────
    hidden function stepPhysics() {
        // Friction
        _vx = _vx * 97 / 100;
        _vy = _vy * 97 / 100;

        // Move
        _bx += _vx;
        _by += _vy;

        // Wall collisions
        for (var i = 0; i < _walls.size(); i++) {
            var w = _walls[i];
            resolveWall(w[0], w[1], w[2], w[3]);
        }

        // Obstacle collisions
        for (var i = 0; i < _obstacles.size(); i++) {
            var ob = _obstacles[i];
            resolveObstacle(ob[0]*10, ob[1]*10, ob[2]*10, ob[3]*10);
        }

        // Water hazard — reset to tee
        for (var i = 0; i < _water.size(); i++) {
            var wt = _water[i];
            var dx = _bx/10 - wt[0]; var dy = _by/10 - wt[1];
            if (dx*dx + dy*dy < (wt[2]+_ballR)*(wt[2]+_ballR)) {
                _bx = _tx * 10; _by = _ty * 10;
                _vx = 0; _vy = 0;
                _strokes++; // penalty
                _gs = MG_AIM; return;
            }
        }

        // Check if in hole
        var hdx = _bx/10 - _hx; var hdy = _by/10 - _hy;
        if (hdx*hdx + hdy*hdy < _holeR*_holeR) {
            _vx = 0; _vy = 0;
            sinkBall(); return;
        }

        // Stop if very slow
        var spd = _vx * _vx + _vy * _vy;
        if (spd < 4) {
            _vx = 0; _vy = 0;
            _gs = MG_AIM;
        }
    }

    // Wall segment collision (line segment reflection)
    hidden function resolveWall(x1, y1, x2, y2) {
        // Wall normal (outward)
        var wx = (x2 - x1); var wy = (y2 - y1);
        var len = Math.sqrt(wx*wx + wy*wy).toNumber();
        if (len == 0) { return; }
        // Unit normal (perpendicular, pointing left of direction)
        var nx = -wy * 10 / len; var ny = wx * 10 / len;

        // Distance from ball centre to wall line
        var dx = _bx/10 - x1; var dy = _by/10 - y1;
        var dist = (dx * nx + dy * ny) / 10;

        // Check if ball is near the segment (project onto segment)
        var t = (dx * wx + dy * wy); // dot
        if (t < 0 || t > len*len) { return; }

        if (dist < _ballR && dist > -4) {
            // Push out
            var overlap = _ballR - dist;
            _bx += nx * overlap;
            _by += ny * overlap;
            // Reflect velocity
            var vDotN = (_vx * nx + _vy * ny) / 100;
            _vx -= nx * vDotN * 2 / 10;
            _vy -= ny * vDotN * 2 / 10;
            // Dampen
            _vx = _vx * 85 / 100;
            _vy = _vy * 85 / 100;
        }
    }

    // Rect obstacle (axis-aligned box)
    hidden function resolveObstacle(cx10, cy10, hw10, hh10) {
        // AABB: find closest point, push out
        var bxc = _bx; var byc = _by;
        var left = cx10 - hw10; var right = cx10 + hw10;
        var top  = cy10 - hh10; var bot   = cy10 + hh10;

        var r10 = _ballR * 10;
        if (bxc + r10 < left || bxc - r10 > right) { return; }
        if (byc + r10 < top  || byc - r10 > bot)   { return; }

        // Find penetration depth on each axis
        var overL = bxc + r10 - left;
        var overR = right - (bxc - r10);
        var overT = byc + r10 - top;
        var overB = bot - (byc - r10);

        // Find minimum overlap axis
        var minO = overL;
        if (overR < minO) { minO = overR; }
        if (overT < minO) { minO = overT; }
        if (overB < minO) { minO = overB; }

        if (minO == overL) { _bx -= overL; _vx = -(_vx * 80 / 100); }
        else if (minO == overR) { _bx += overR; _vx = -(_vx * 80 / 100); }
        else if (minO == overT) { _by -= overT; _vy = -(_vy * 80 / 100); }
        else { _by += overB; _vy = -(_vy * 80 / 100); }
    }

    hidden function sinkBall() {
        _scoreCard[_holeIdx] = _strokes;
        _totalStrokes += _strokes;
        var diff = _strokes - _par[_holeIdx];
        if (diff <= -2)     { _holeMsg = "Eagle! \u2605\u2605"; }
        else if (diff == -1){ _holeMsg = "Birdie! \u2605"; }
        else if (diff == 0) { _holeMsg = "Par!"; }
        else if (diff == 1) { _holeMsg = "Bogey"; }
        else                { _holeMsg = "+" + diff; }
        _holeWait = 12;
        _gs = MG_HOLED;
    }

    // ── Input ─────────────────────────────────────────────────────────────────
    function doUp() {
        if (_gs == MG_MENU)     { _difficulty = (_difficulty + 2) % 3; return; }
        if (_gs == MG_GAMEOVER) { _gs = MG_MENU; return; }
        if (_gs == MG_AIM)      { _aimAngle = (_aimAngle + 355) % 360; }
        if (_gs == MG_POWER)    { commitShot(); }
    }

    function doDown() {
        if (_gs == MG_MENU)     { _difficulty = (_difficulty + 1) % 3; return; }
        if (_gs == MG_GAMEOVER) { _gs = MG_MENU; return; }
        if (_gs == MG_AIM)      { _aimAngle = (_aimAngle + 5) % 360; }
        if (_gs == MG_POWER)    { commitShot(); }
    }

    function doSelect() {
        if (_gs == MG_MENU)     { startGame(); return; }
        if (_gs == MG_GAMEOVER) { _gs = MG_MENU; return; }
        if (_gs == MG_AIM)      { _gs = MG_POWER; _power = 0; _powerDir = 1; return; }
        if (_gs == MG_POWER)    { commitShot(); return; }
        if (_gs == MG_HOLED)    { nextHole(); return; }
    }

    function doBack() {
        if (_gs != MG_MENU) { _gs = MG_MENU; }
    }

    function doMenu() { doBack(); }

    function doTap(tx, ty) {
        if (_gs == MG_MENU)     { startGame(); return; }
        if (_gs == MG_GAMEOVER) { _gs = MG_MENU; return; }
        if (_gs == MG_HOLED && _holeWait <= 0) { nextHole(); return; }
        if (_gs == MG_ROLLING)  { return; }

        if (_gs == MG_AIM) {
            // Tap away from ball → set aim direction toward tap
            var bsx = cToS_X(_bx / 10); var bsy = cToS_Y(_by / 10);
            var dx = tx - bsx; var dy = ty - bsy;
            if (dx*dx + dy*dy > 100) {
                _aimAngle = (Math.atan2(dy, dx) * 180 / Math.PI).toNumber();
                if (_aimAngle < 0) { _aimAngle += 360; }
                _gs = MG_POWER; _power = 0; _powerDir = 1;
            }
            return;
        }
        if (_gs == MG_POWER) { commitShot(); return; }
    }

    hidden function commitShot() {
        _strokes++;
        var rad = _aimAngle * Math.PI / 180;
        var spd = _power * 18 / 10 + 20; // min 20, max 200
        _vx = (Math.cos(rad) * spd).toNumber();
        _vy = (Math.sin(rad) * spd).toNumber();
        _gs = MG_ROLLING;
        _power = 0;
    }

    hidden function startGame() {
        _holeIdx = 0; _totalStrokes = 0; _strokes = 0;
        for (var i = 0; i < 9; i++) { _scoreCard[i] = -1; }
        loadHole(_holeIdx);
        _gs = MG_AIM;
    }

    hidden function nextHole() {
        _holeIdx++;
        if (_holeIdx >= 9) { _gs = MG_GAMEOVER; return; }
        _strokes = 0;
        loadHole(_holeIdx);
        _gs = MG_AIM;
    }

    // ── Hole definitions ──────────────────────────────────────────────────────
    // Course coords 0-1000 × 0-1000
    // Walls format: [x1,y1, x2,y2] — solid boundary segments
    // Obstacles: [cx,cy, halfW,halfH] — solid rectangles
    // Water: [cx,cy, r] — circular hazards (ball resets to tee +1 stroke)

    hidden function loadHole(idx) {
        _vx = 0; _vy = 0;

        if (idx == 0) {
            // Hole 1 — straight corridor
            _tx=120; _ty=500; _hx=880; _hy=500;
            _walls = [
                [100,350, 900,350],
                [900,350, 900,650],
                [900,650, 100,650],
                [100,650, 100,350]
            ];
            _obstacles = new [0]; _water = new [0];
        } else if (idx == 1) {
            // Hole 2 — L-shape
            _tx=120; _ty=200; _hx=820; _hy=800;
            _walls = [
                [100,100, 500,100],
                [500,100, 500,500],
                [500,500, 900,500],
                [900,500, 900,900],
                [900,900, 100,900],
                [100,900, 100,100]
            ];
            _obstacles = [[490,300, 20,200]]; _water = new [0];
        } else if (idx == 2) {
            // Hole 3 — dogleg with obstacle
            _tx=130; _ty=150; _hx=870; _hy=850;
            _walls = [
                [100,100, 400,100],
                [400,100, 400,500],
                [400,500, 900,500],
                [900,500, 900,900],
                [900,900, 600,900],
                [600,900, 600,500],  // inner corner
                [600,500, 100,500],
                [100,500, 100,100]
            ];
            _obstacles = [[250,300, 60,40]]; _water = new [0];
        } else if (idx == 3) {
            // Hole 4 — narrow Z corridor
            _tx=130; _ty=800; _hx=870; _hy=200;
            _walls = [
                [100,700, 600,700],
                [600,700, 600,900],
                [600,900, 100,900],
                [100,900, 100,700],
                // middle bridge
                [300,400, 700,400],
                [700,400, 700,700],
                [300,700, 300,400],
                // top section
                [400,100, 900,100],
                [900,100, 900,400],
                [400,400, 400,100]
            ];
            _obstacles = new [0]; _water = new [0];
        } else if (idx == 4) {
            // Hole 5 — island green with water
            _tx=130; _ty=500; _hx=870; _hy=500;
            _walls = [
                [100,300, 900,300],
                [900,300, 900,700],
                [900,700, 100,700],
                [100,700, 100,300]
            ];
            _obstacles = new [0];
            _water = [[500,500, 130]]; // pond in middle
        } else if (idx == 5) {
            // Hole 6 — windmill obstacle
            _tx=130; _ty=500; _hx=870; _hy=500;
            _walls = [
                [100,350, 900,350],
                [900,350, 900,650],
                [900,650, 100,650],
                [100,650, 100,350]
            ];
            // Windmill blades as obstacles that rotate... simplified: 4 rects in X
            _obstacles = [[500,500, 20,100], [500,500, 100,20]];
            _water = new [0];
        } else if (idx == 6) {
            // Hole 7 — multiple corridors
            _tx=130; _ty=150; _hx=870; _hy=850;
            _walls = [
                [100,100, 900,100],
                [900,100, 900,400],
                [900,400, 600,400],
                [600,400, 600,600],
                [600,600, 900,600],
                [900,600, 900,900],
                [900,900, 100,900],
                [100,900, 100,600],
                [100,600, 400,600],
                [400,600, 400,400],
                [400,400, 100,400],
                [100,400, 100,100]
            ];
            _obstacles = [[500,500, 30,30]];
            _water = new [0];
        } else if (idx == 7) {
            // Hole 8 — curved-ish with bumpers
            _tx=130; _ty=130; _hx=870; _hy=870;
            _walls = [
                [100,100, 900,100],
                [900,100, 900,900],
                [900,900, 100,900],
                [100,900, 100,100]
            ];
            _obstacles = [[350,350, 40,40], [650,350, 40,40],
                          [350,650, 40,40], [650,650, 40,40],
                          [500,500, 30,30]];
            _water = new [0];
        } else {
            // Hole 9 — grand finale with water and bumpers
            _tx=130; _ty=500; _hx=870; _hy=500;
            _walls = [
                [100,200, 900,200],
                [900,200, 900,800],
                [900,800, 100,800],
                [100,800, 100,200]
            ];
            _obstacles = [[350,400, 30,100], [650,400, 30,100]];
            _water = [[500,300, 80], [500,700, 80]];
        }

        _bx = _tx * 10; _by = _ty * 10;
        _aimAngle = computeAimTowardHole();
    }

    hidden function computeAimTowardHole() {
        var dx = _hx - _tx; var dy = _hy - _ty;
        var ang = (Math.atan2(dy, dx) * 180 / Math.PI).toNumber();
        if (ang < 0) { ang += 360; }
        return ang;
    }

    // ── Coordinate helpers ────────────────────────────────────────────────────
    // Course (0-1000) → screen pixel
    hidden function cToS_X(cx) { return _vpX + cx * _vpW / 1000; }
    hidden function cToS_Y(cy) { return _vpY + cy * _vpH / 1000; }
    hidden function cToS_R(cr) { return cr * _vpW / 1000; }

    // ── Rendering ─────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupVP(); }
        if (_gs == MG_MENU) { drawMenu(dc); return; }
        drawCourse(dc);
        drawBall(dc);
        drawAimArrow(dc);
        drawHUD(dc);
        if (_gs == MG_POWER)   { drawPowerBar(dc); }
        if (_gs == MG_HOLED)   { drawHoledOverlay(dc); }
        if (_gs == MG_GAMEOVER){ drawGameOver(dc); }
    }

    // ── Menu ─────────────────────────────────────────────────────────────────
    hidden function drawMenu(dc) {
        dc.setColor(0x0A1A08, 0x0A1A08); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0D3010, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);
        dc.setColor(0x144820, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 14);

        // Decorative mini-course hint
        dc.setColor(0x1A5028, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w/2 - 50, _h/2 + 28, 100, 30, 6);
        dc.setColor(0x2A7040, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_w/2 - 50, _h/2 + 28, 100, 30, 6);
        // Tiny ball
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_w/2 - 32, _h/2 + 43, 5);
        // Tiny flag
        dc.setColor(0x885522, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_w/2 + 30, _h/2 + 30, _w/2 + 30, _h/2 + 55);
        dc.setColor(0xFF3311, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_w/2 + 30, _h/2 + 30, 10, 7);

        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 56, Graphics.FONT_MEDIUM, "MINIGOLF", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 32, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        var diffLabels = ["Easy (9 holes)", "Normal", "Hard"];
        dc.setColor(0xCCEEBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 14, Graphics.FONT_XTINY, "Difficulty:", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 + 2, Graphics.FONT_XTINY, diffLabels[_difficulty], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x448833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 + 16, Graphics.FONT_XTINY, "\u25B2\u25BC change", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0x44FF88 : 0x228844, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 + 70, Graphics.FONT_XTINY, "Tap to tee off!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Course ────────────────────────────────────────────────────────────────
    hidden function drawCourse(dc) {
        dc.setColor(0x060E05, 0x060E05); dc.clear();

        // Green fairway fill — flood fill approximated by drawing a rect
        // for each hole's bounding area (simplified)
        dc.setColor(0x1A6030, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_vpX, _vpY, _vpW, _vpH);

        // Rough border
        dc.setColor(0x0E3A1A, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_vpX, _vpY, _vpW, _vpH);

        // Water hazards
        dc.setColor(0x1144AA, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _water.size(); i++) {
            var wt = _water[i];
            var sx = cToS_X(wt[0]); var sy = cToS_Y(wt[1]);
            var sr = cToS_R(wt[2]);
            dc.fillCircle(sx, sy, sr);
            dc.setColor(0x2266CC, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(sx, sy, sr);
            dc.setColor(0x1144AA, Graphics.COLOR_TRANSPARENT);
        }

        // Obstacles (dark blocks — concrete/wood)
        dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _obstacles.size(); i++) {
            var ob = _obstacles[i];
            var sx = cToS_X(ob[0] - ob[2]); var sy = cToS_Y(ob[1] - ob[3]);
            var sw = cToS_R(ob[2] * 2 + 1); var sh = cToS_R(ob[3] * 2 + 1);
            if (sw < 4) { sw = 4; } if (sh < 4) { sh = 4; }
            dc.fillRoundedRectangle(sx, sy, sw, sh, 2);
            dc.setColor(0x885533, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(sx, sy, sw, sh, 2);
            dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
        }

        // Walls (white-ish boundary lines)
        dc.setColor(0xCCDDBB, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _walls.size(); i++) {
            var wl = _walls[i];
            var sx1 = cToS_X(wl[0]); var sy1 = cToS_Y(wl[1]);
            var sx2 = cToS_X(wl[2]); var sy2 = cToS_Y(wl[3]);
            dc.drawLine(sx1, sy1, sx2, sy2);
            dc.drawLine(sx1+1, sy1, sx2+1, sy2);
        }

        // Tee marker
        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
        var tsx = cToS_X(_tx); var tsy = cToS_Y(_ty);
        dc.fillCircle(tsx, tsy, 4);
        dc.setColor(0xAA8833, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(tsx, tsy, 4);

        // Hole/cup
        drawHoleCup(dc);
    }

    hidden function drawHoleCup(dc) {
        var hsx = cToS_X(_hx); var hsy = cToS_Y(_hy);
        var hsr = cToS_R(_holeR);
        if (hsr < 4) { hsr = 4; }
        // Shadow
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hsx + 1, hsy + 1, hsr);
        // Hole
        dc.setColor(0x050A04, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hsx, hsy, hsr);
        dc.setColor(0x334433, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(hsx, hsy, hsr);
        // Flag pole
        dc.setColor(0x886633, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(hsx, hsy, hsx, hsy - hsr * 4);
        // Flag
        dc.setColor(0xFF3311, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(hsx, hsy - hsr * 4, hsr * 2, hsr * 3 / 2);
        // Hole number
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hsx + hsr + 2, hsy - hsr * 4 - 4, Graphics.FONT_XTINY,
            "" + (_holeIdx + 1), Graphics.TEXT_JUSTIFY_LEFT);
    }

    // ── Ball ─────────────────────────────────────────────────────────────────
    hidden function drawBall(dc) {
        if (_gs == MG_HOLED) { return; }
        var bsx = cToS_X(_bx / 10); var bsy = cToS_Y(_by / 10);
        var br  = cToS_R(_ballR);
        if (br < 3) { br = 3; }
        // Shadow
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bsx + 1, bsy + 1, br);
        // Ball body
        dc.setColor(0xF8F8F8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bsx, bsy, br);
        // Gloss
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bsx - br/3, bsy - br/3, br/3 + 1);
        // Dimple hint
        dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(bsx, bsy, br);
    }

    // ── Aim arrow ────────────────────────────────────────────────────────────
    hidden function drawAimArrow(dc) {
        if (_gs != MG_AIM && _gs != MG_POWER) { return; }
        var bsx = cToS_X(_bx / 10); var bsy = cToS_Y(_by / 10);
        var rad = _aimAngle * Math.PI / 180;
        var len = 28 + (_gs == MG_POWER ? _power / 5 : 0);

        var ex = bsx + (Math.cos(rad) * len).toNumber();
        var ey = bsy + (Math.sin(rad) * len).toNumber();

        dc.setColor((_tick % 6 < 3) ? 0xFFFF44 : 0xCC9900, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(bsx, bsy, ex, ey);
        // Arrow head
        var hrad = rad + Math.PI * 5 / 6;
        dc.drawLine(ex, ey, ex + (Math.cos(hrad)*8).toNumber(), ey + (Math.sin(hrad)*8).toNumber());
        hrad = rad - Math.PI * 5 / 6;
        dc.drawLine(ex, ey, ex + (Math.cos(hrad)*8).toNumber(), ey + (Math.sin(hrad)*8).toNumber());
    }

    // ── Power bar ────────────────────────────────────────────────────────────
    hidden function drawPowerBar(dc) {
        var bw = _vpW * 7 / 10; var bh = 8;
        var bx = _vpX + (_vpW - bw) / 2; var by = _h - 16;
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx - 1, by - 1, bw + 2, bh + 2, 3);
        var filled = bw * _power / 100;
        var clr = _power < 50 ? 0x44DD44 : (_power < 80 ? 0xFFCC00 : 0xFF3311);
        dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, filled, bh, 2);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 2);
        dc.drawText(_vpX + _vpW / 2, by - 12, Graphics.FONT_XTINY, "Power! Tap to shoot", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── HUD ───────────────────────────────────────────────────────────────────
    hidden function drawHUD(dc) {
        var hole = _holeIdx + 1;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _vpY);
        dc.setColor(0x88CCAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 4, Graphics.FONT_XTINY, "Hole " + hole + "/9", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, 4, Graphics.FONT_XTINY, "Par " + _par[_holeIdx], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 4, 4, Graphics.FONT_XTINY, "\u26F3 " + _strokes, Graphics.TEXT_JUSTIFY_RIGHT);

        // Aim hint bottom
        if (_gs == MG_AIM) {
            dc.setColor(0x44AA66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _h - 14, Graphics.FONT_XTINY, "Tap/\u25B2\u25BC aim  \u25CF shoot", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Holed overlay ────────────────────────────────────────────────────────
    hidden function drawHoledOverlay(dc) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_w/2 - 60, _h/2 - 32, 120, 64, 8);
        dc.setColor(0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_w/2 - 60, _h/2 - 32, 120, 64, 8);

        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 28, Graphics.FONT_MEDIUM, "HOLED!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 - 6, Graphics.FONT_XTINY, _holeMsg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h/2 + 10, Graphics.FONT_XTINY,
            "Strokes: " + _strokes + " / Par: " + _par[_holeIdx], Graphics.TEXT_JUSTIFY_CENTER);
        if (_holeWait <= 0) {
            dc.setColor((_tick % 8 < 4) ? 0x88CCFF : 0x4488AA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _h/2 + 24, Graphics.FONT_XTINY, "Tap \u25BA next hole", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Game over ─────────────────────────────────────────────────────────────
    hidden function drawGameOver(dc) {
        dc.setColor(0x050D04, 0x050D04); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0A2010, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);

        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 8 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        // Score card
        var par18 = 0; for (var i = 0; i < 9; i++) { par18 += _par[i]; }
        var diff = _totalStrokes - par18;
        var diffStr = diff == 0 ? "E" : (diff > 0 ? "+" + diff : "" + diff);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 22 / 100, Graphics.FONT_XTINY,
            "Total: " + _totalStrokes + " (" + diffStr + ")", Graphics.TEXT_JUSTIFY_CENTER);

        // Mini scorecard rows
        var rowH = _h * 44 / 100 / 9;
        if (rowH < 12) { rowH = 12; }
        for (var i = 0; i < 9; i++) {
            var ry = _h * 32 / 100 + i * rowH;
            if (ry + rowH > _h * 80 / 100) { break; }
            var sc = _scoreCard[i];
            var pd = (sc >= 0) ? sc - _par[i] : 0;
            var clr = 0xCCCCCC;
            if (pd < 0) { clr = 0x44FF88; }
            else if (pd == 0) { clr = 0xFFFFFF; }
            else if (pd == 1) { clr = 0xFFAA44; }
            else { clr = 0xFF5544; }
            dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
            var txt = "H" + (i+1) + ": " + (sc >= 0 ? "" + sc : "-") + " (par " + _par[i] + ")";
            dc.drawText(_w/2, ry, Graphics.FONT_XTINY, txt, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0x44FF88 : 0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 86 / 100, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
