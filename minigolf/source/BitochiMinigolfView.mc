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
const MG_GAMEOVER  = 5;   // all holes done

// 20 holes total — see loadHole() for individual designs
const MG_HOLES = 20;

// ── Wall segment: [x1, y1, x2, y2] (coords in 0..1000 space) ────────────────
// Course space is 0-1000 × 0-1000, rendered into game viewport at runtime.

class BitochiMinigolfView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    // Difficulty / level selection
    hidden var _difficulty;  // 0=Easy 1=Normal 2=Hard
    // 20 holes total. Difficulty multiplies the target par allowance only,
    // not the level layout (every player faces the same 20 designs).
    hidden var _holeIdx;     // 0..MG_HOLES-1
    hidden var _strokes;     // strokes this hole
    hidden var _totalStrokes;
    hidden var _par;         // [MG_HOLES] par per hole

    // Animated obstacle helper (windmill, moving bumpers).
    // Stored as separate state so the obstacle list can be regenerated each frame.
    hidden var _animPhase;

    // Per-level rendering / physics theme.
    //   false = thin "rail" white walls (90% bounce, default)
    //   true  = chunky brown bumper walls (95% bounce, more pinball-feel)
    hidden var _brownWalls;

    // Ball state (in 0-1000 space ×10 = fixed-point 0-10000)
    hidden var _bx; hidden var _by;   // *10 fixed
    hidden var _vx; hidden var _vy;   // velocity *10
    hidden var _ballR;                // ball radius in course-space units (≈18)

    // Hole/cup position (course space)
    hidden var _hx; hidden var _hy;
    hidden var _holeR;   // hole radius

    // Tee (start) position
    hidden var _tx; hidden var _ty;

    // Last valid ball position (before shot — used when ball goes out of bounds)
    hidden var _lastBx; hidden var _lastBy;

    // Aim
    hidden var _aimAngle;   // degrees 0-359
    hidden var _power;      // 0-100 (during power state, oscillates)
    hidden var _powerDir;   // 1 or -1

    // Walls: array of [x1,y1,x2,y2] in 0-1000 space (integers)
    hidden var _walls;

    // Course viewport mapping: course → screen
    hidden var _vpX; hidden var _vpY; hidden var _vpW; hidden var _vpH; hidden var _scale;
    hidden var _offX; hidden var _offY;  // centering offsets within viewport

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
        _ballR = 14; _holeR = 20;
        // Par tuned per layout difficulty (warm-up → finale).
        _par = [
            2, 3, 3, 3, 3,    // 1-5  intro / shapes / hazards
            3, 3, 3, 4, 3,    // 6-10 windmill / pinball / lake / funnel
            3, 4, 3, 4, 3,    // 11-15 slalom / eye / tunnel / pinball / cross
            4, 3, 4, 4, 5     // 16-20 volcano / snake / triangle / spiral / boss
        ];
        _scoreCard = new [MG_HOLES];
        for (var i = 0; i < MG_HOLES; i++) { _scoreCard[i] = -1; }
        _walls = new [0]; _obstacles = new [0]; _water = new [0];
        _holeMsg = ""; _holeWait = 0; _animPhase = 0;
        _brownWalls = false;
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 50, true);
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupVP();
    }

    hidden function setupVP() {
        // HUD proportional to screen size
        var hudTop = _h * 22 / 100; if (hudTop < 20) { hudTop = 20; }
        var hudBot = _h * 16 / 100; if (hudBot < 16) { hudBot = 16; }
        _vpX = 4; _vpY = hudTop;
        _vpW = _w - 8; _vpH = _h - hudTop - hudBot;
        // Uniform scale so course is never distorted on non-square screens
        _scale = _vpW < _vpH ? _vpW : _vpH;
        // Center the course square within the viewport
        _offX = (_vpW - _scale) / 2;
        _offY = (_vpH - _scale) / 2;
    }

    // ── Timer ─────────────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        _animPhase = (_animPhase + 1) % 360;
        if (_gs == MG_POWER) {
            _power += _powerDir * 4;
            if (_power >= 100) { _power = 100; _powerDir = -1; }
            if (_power <= 0)   { _power = 0;   _powerDir =  1; }
        }
        // Refresh animated obstacles for the current hole (windmill, sliders…)
        updateAnimated();
        if (_gs == MG_ROLLING) { stepPhysics(); }
        if (_gs == MG_HOLED && _holeWait > 0) { _holeWait--; }
        WatchUi.requestUpdate();
    }

    // ── Physics ───────────────────────────────────────────────────────────────
    // Realistic-feel rolling: low rolling friction (94% retention), elastic
    // walls (~90%), high substep count to avoid tunneling on fast shots, and
    // velocity-based sub-step subdivision so slow balls aren't over-processed.
    hidden function stepPhysics() {
        // Rolling friction — exponential decay, applied once per tick.
        // 94% retention ≈ ball loses ~6% per 50ms tick → natural roll length.
        _vx = _vx * 94 / 100;
        _vy = _vy * 94 / 100;

        // Adaptive substep: faster ball → more steps so we never miss a wall
        var spd2 = _vx * _vx + _vy * _vy;
        var SUB = 3;
        if (spd2 > 90000)   { SUB = 4; }
        if (spd2 > 250000)  { SUB = 5; }
        if (spd2 > 500000)  { SUB = 6; }
        var svx = _vx / SUB; var svy = _vy / SUB;

        for (var s = 0; s < SUB; s++) {
            _bx += svx;
            _by += svy;

            for (var i = 0; i < _walls.size(); i++) {
                var w = _walls[i];
                resolveWall(w[0], w[1], w[2], w[3]);
            }
            for (var i = 0; i < _obstacles.size(); i++) {
                var ob = _obstacles[i];
                resolveObstacle(ob[0]*10, ob[1]*10, ob[2]*10, ob[3]*10);
            }

            // Water hazard — drop in, reset to last valid position +1 stroke
            for (var i = 0; i < _water.size(); i++) {
                var wt = _water[i];
                var dx = _bx/10 - wt[0]; var dy = _by/10 - wt[1];
                if (dx*dx + dy*dy < (wt[2]+_ballR/2)*(wt[2]+_ballR/2)) {
                    _bx = _lastBx; _by = _lastBy;
                    _vx = 0; _vy = 0;
                    _strokes++; // splash penalty
                    _gs = MG_AIM; return;
                }
            }

            // In hole? ball must also be slow enough — fast balls bounce out.
            var hdx = _bx/10 - _hx; var hdy = _by/10 - _hy;
            var dist2 = hdx*hdx + hdy*hdy;
            if (dist2 < _holeR*_holeR) {
                if (spd2 < 360000 || dist2 < (_holeR/2)*(_holeR/2)) {
                    _vx = 0; _vy = 0;
                    sinkBall(); return;
                }
                // Lip-out: pull ball slightly toward centre (gravity into cup)
                _vx = _vx * 80 / 100; _vy = _vy * 80 / 100;
                if (hdx != 0) { _vx -= hdx; }
                if (hdy != 0) { _vy -= hdy; }
            }
        }

        // Out-of-bounds check (course space 0-1000) — restore last shot origin
        var cx = _bx / 10; var cy = _by / 10;
        if (cx < -50 || cx > 1050 || cy < -50 || cy > 1050) {
            _bx = _lastBx; _by = _lastBy;
            _vx = 0; _vy = 0;
            _gs = MG_AIM;
            return;
        }

        // Stop threshold — slightly higher so ball settles cleanly near hole
        var spdEnd = _vx * _vx + _vy * _vy;
        if (spdEnd < 36) {
            _vx = 0; _vy = 0;
            _gs = MG_AIM;
        }
    }

    // Wall segment collision (line segment reflection).
    // Handles ball arriving from EITHER side of the wall — normal is flipped
    // based on which side the ball is on, so inner walls bounce correctly.
    hidden function resolveWall(x1, y1, x2, y2) {
        var wx = (x2 - x1); var wy = (y2 - y1);
        var lenSq = wx * wx + wy * wy;
        if (lenSq == 0) { return; }
        var len = Math.sqrt(lenSq).toNumber();
        // Unit normal × 10 (CCW perpendicular)
        var nx = -wy * 10 / len; var ny = wx * 10 / len;

        // Project ball onto the segment — clamp t to [0, lenSq] so endcaps
        // are handled like a rounded capsule (push from nearest endpoint).
        var dx = _bx / 10 - x1; var dy = _by / 10 - y1;
        var t = dx * wx + dy * wy;
        var px; var py;
        if (t <= 0) {
            px = x1; py = y1;
        } else if (t >= lenSq) {
            px = x2; py = y2;
        } else {
            // Project to interior of segment
            px = x1 + (wx * t / lenSq);
            py = y1 + (wy * t / lenSq);
        }
        var rx = _bx / 10 - px; var ry = _by / 10 - py;
        var dist2 = rx * rx + ry * ry;
        if (dist2 >= _ballR * _ballR) { return; }

        var dist = Math.sqrt(dist2).toNumber();
        if (dist == 0) {
            // Degenerate — push along the wall normal arbitrarily
            rx = nx; ry = ny; dist = 10;
        }
        // Outward unit vector toward ball centre × 10 (scaled like nx/ny)
        var ux = rx * 10 / dist; var uy = ry * 10 / dist;
        // Push out so ball just touches the wall
        var overlap = _ballR - dist;
        _bx += ux * overlap;
        _by += uy * overlap;

        // Reflect velocity only if moving toward the wall
        var vDotU = (_vx * ux + _vy * uy) / 100;
        if (vDotU < 0) {
            _vx -= ux * vDotU * 2 / 10;
            _vy -= uy * vDotU * 2 / 10;
            // White rails lose ~10%; brown bumper walls only ~5% (springier).
            var keep = _brownWalls ? 95 : 90;
            _vx = _vx * keep / 100;
            _vy = _vy * keep / 100;
        }
    }

    // Rect obstacle (axis-aligned box) — small dampening, normal reflection
    hidden function resolveObstacle(cx10, cy10, hw10, hh10) {
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

        // Resolve along the axis with the smallest overlap (prefer the side
        // the ball is *moving toward* when overlaps are equal)
        var minO = overL;
        if (overR < minO) { minO = overR; }
        if (overT < minO) { minO = overT; }
        if (overB < minO) { minO = overB; }

        // Brown obstacles act like real pinball bumpers — ~92% retention.
        if (minO == overL && _vx > -1)       { _bx -= overL; _vx = -(_vx * 92 / 100); }
        else if (minO == overR && _vx < 1)   { _bx += overR; _vx = -(_vx * 92 / 100); }
        else if (minO == overT && _vy > -1)  { _by -= overT; _vy = -(_vy * 92 / 100); }
        else if (minO == overB && _vy < 1)   { _by += overB; _vy = -(_vy * 92 / 100); }
        else if (minO == overL)              { _bx -= overL; _vx = -(_vx * 92 / 100); }
        else if (minO == overR)              { _bx += overR; _vx = -(_vx * 92 / 100); }
        else if (minO == overT)              { _by -= overT; _vy = -(_vy * 92 / 100); }
        else                                 { _by += overB; _vy = -(_vy * 92 / 100); }
    }

    // Update obstacles that animate per-tick (windmill, slider, pendulum…).
    // For the most part it rebuilds _obstacles for the relevant hole index.
    hidden function updateAnimated() {
        if (_holeIdx == 5) {
            // Windmill: cross-shaped blade rotating about (500,500)
            var ang = _animPhase * 4;   // ~14°/tick → full revolution per ~25 ticks
            var rad = ang * Math.PI / 180;
            var c = Math.cos(rad); var s = Math.sin(rad);
            // Two perpendicular blades, length 180 / thickness 18
            var L = 170; var T = 14;
            var ax = (c * L).toNumber(); var ay = (s * L).toNumber();
            // Blade A: full rectangle from (-ax,-ay) to (ax,ay) — too thin to hit,
            // so we approximate with 5 small hubs along the blade
            _obstacles = [
                [500,         500,         T, T],
                [500 + ax/2,  500 + ay/2,  T, T],
                [500 - ax/2,  500 - ay/2,  T, T],
                [500 + ax,    500 + ay,    T, T],
                [500 - ax,    500 - ay,    T, T],
                // Perpendicular blade
                [500 + (-ay)/2, 500 + ax/2,  T, T],
                [500 - (-ay)/2, 500 - ax/2,  T, T],
                [500 - ay,      500 + ax,    T, T],
                [500 + ay,      500 - ax,    T, T]
            ];
        } else if (_holeIdx == 16) {
            // Snake: two pendulum bumpers swinging horizontally
            var ph = _animPhase * 2;
            var off1 = (Math.sin(ph * Math.PI / 180) * 140).toNumber();
            var off2 = (Math.sin((ph + 180) * Math.PI / 180) * 140).toNumber();
            _obstacles = [
                [500 + off1, 380, 28, 18],
                [500 + off2, 620, 28, 18]
            ];
        }
    }

    hidden function sinkBall() {
        _scoreCard[_holeIdx] = _strokes;
        _totalStrokes += _strokes;
        var diff = _strokes - _par[_holeIdx];
        if (diff <= -2)     { _holeMsg = "Eagle! **"; }
        else if (diff == -1){ _holeMsg = "Birdie! *"; }
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
        if (_gs != MG_MENU) { _gs = MG_MENU; return true; }
        return false;
    }

    function doMenu() { return doBack(); }

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
        _lastBx = _bx; _lastBy = _by;
        _strokes++;
        var rad = _aimAngle * Math.PI / 180;
        // -30% from previous value (was 324/360, now 227/252)
        var spd = _power * 227 / 10 + 252;
        _vx = (Math.cos(rad) * spd).toNumber();
        _vy = (Math.sin(rad) * spd).toNumber();
        _gs = MG_ROLLING;
        _power = 0;
    }

    hidden function startGame() {
        _holeIdx = 0; _totalStrokes = 0; _strokes = 0;
        for (var i = 0; i < MG_HOLES; i++) { _scoreCard[i] = -1; }
        loadHole(_holeIdx);
        _gs = MG_AIM;
    }

    hidden function nextHole() {
        _holeIdx++;
        if (_holeIdx >= MG_HOLES) { _gs = MG_GAMEOVER; return; }
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
        _walls = new [0]; _obstacles = new [0]; _water = new [0];
        _brownWalls = false;

        if (idx == 0) {
            // 1. Straight corridor — easy intro
            _tx=120; _ty=500; _hx=880; _hy=500;
            _walls = [
                [100,400, 900,400],
                [900,400, 900,600],
                [900,600, 100,600],
                [100,600, 100,400]
            ];
        } else if (idx == 1) {
            // 2. L-shape — first bend with a free-standing nub
            _tx=160; _ty=180; _hx=830; _hy=830;
            _walls = [
                [100,100, 600,100],
                [600,100, 600,520],
                [600,520, 900,520],
                [900,520, 900,900],
                [900,900, 100,900],
                [100,900, 100,100]
            ];
            _obstacles = [[470,300, 18,160]];
        } else if (idx == 2) {
            // 3. Dogleg (inverted U) — go up, around, then down
            _tx=140; _ty=820; _hx=860; _hy=820;
            _walls = [
                [100,200, 900,200],     // top wall
                [900,200, 900,900],     // right outer
                [900,900, 600,900],     // bottom right
                [600,900, 600,400],     // inner divider right
                [600,400, 400,400],     // inner divider top
                [400,400, 400,900],     // inner divider left
                [400,900, 100,900],     // bottom left
                [100,900, 100,200]      // left outer
            ];
            _obstacles = [[250,300, 50,30], [750,300, 50,30]];
        } else if (idx == 3) {
            // 4. Z-corridor — three connected lanes with proper openings
            // Bottom lane (x100..700, y700..900) opens up at x300..700 → bridge.
            // Bridge (x300..700, y400..700) opens up at x300..700 to top lane.
            // Top lane (x300..900, y100..400).
            _tx=160; _ty=820; _hx=840; _hy=180;
            _walls = [
                [100,700, 300,700],   // bottom lane top (left half — opening x300..700)
                [700,700, 700,900],   // bottom lane right
                [700,900, 100,900],   // bottom lane bottom
                [100,900, 100,700],   // bottom lane left
                [300,400, 300,700],   // bridge left
                [700,400, 700,700],   // bridge right
                [300,100, 300,400],   // top lane left
                [300,100, 900,100],   // top lane top
                [900,100, 900,400],   // top lane right
                [700,400, 900,400]    // top lane bottom (right half — opening x300..700)
            ];
        } else if (idx == 4) {
            // 5. Island Green — water lake spanning corridor centre
            _tx=140; _ty=500; _hx=860; _hy=500;
            _walls = [
                [100,300, 900,300],
                [900,300, 900,700],
                [900,700, 100,700],
                [100,700, 100,300]
            ];
            _water = [[500,500, 140]];
        } else if (idx == 5) {
            // 6. Windmill — animated rotating cross blocks centre (see updateAnimated)
            _tx=140; _ty=500; _hx=860; _hy=500;
            _brownWalls = true;
            _walls = [
                [100,330, 900,330],
                [900,330, 900,670],
                [900,670, 100,670],
                [100,670, 100,330]
            ];
            // _obstacles populated each tick by updateAnimated()
            _obstacles = [[500,500, 14,14]];
        } else if (idx == 6) {
            // 7. Diamond Court — diamond-shaped fairway of bouncy bumper rails.
            // Tee on the west point, hole on the east point, central bumper
            // forces the ball to deflect off a diagonal wall to score.
            _tx=200; _ty=500; _hx=820; _hy=500;
            _brownWalls = true;
            _walls = [
                [500,120, 880,500],   // top-right slope
                [880,500, 500,880],   // bottom-right slope
                [500,880, 120,500],   // bottom-left slope
                [120,500, 500,120]    // top-left slope
            ];
            _obstacles = [
                [500,500, 26,26],   // centre bumper
                [380,380, 18,18],   // NW kicker
                [620,620, 18,18]    // SE kicker
            ];
        } else if (idx == 7) {
            // 8. Bumper field — open arena with quincunx of bumpers
            _tx=160; _ty=160; _hx=840; _hy=840;
            _brownWalls = true;
            _walls = [
                [100,100, 900,100],
                [900,100, 900,900],
                [900,900, 100,900],
                [100,900, 100,100]
            ];
            _obstacles = [
                [320,320, 38,38], [680,320, 38,38],
                [320,680, 38,38], [680,680, 38,38],
                [500,500, 32,32]
            ];
        } else if (idx == 8) {
            // 9. Bowtie / Hourglass — two trapezoid bowls joined by a narrow waist.
            // Must thread the 60-wide waist (~3 ball diameters) without scraping.
            _tx=200; _ty=200; _hx=800; _hy=800;
            _brownWalls = true;
            _walls = [
                // top bowl
                [150,140, 850,140],   // top
                [850,140, 530,470],   // right wall slopes inward
                [150,140, 470,470],   // left wall slopes inward
                // waist (vertical channel)
                [470,470, 470,530],
                [530,470, 530,530],
                // bottom bowl
                [470,530, 150,860],
                [530,530, 850,860],
                [150,860, 850,860]    // bottom
            ];
            _obstacles = new [0];
            _water = new [0];
        } else if (idx == 9) {
            // 10. Funnel — wide tee narrowing to hole, with two angled rails
            _tx=160; _ty=500; _hx=860; _hy=500;
            _brownWalls = true;
            _walls = [
                // outer corridor
                [100,180, 900,400],     // top angled wall
                [900,400, 900,600],     // hole pocket right
                [900,600, 100,820],     // bottom angled wall
                [100,820, 100,180]      // left tee wall
            ];
            _obstacles = [[600,400, 8,40], [600,600, 8,40]];
        } else if (idx == 10) {
            // 11. Slalom — alternating pegs hang halfway across the corridor,
            // forcing the ball to weave above/below to pass.
            _tx=140; _ty=500; _hx=860; _hy=500;
            _walls = [
                [100,300, 900,300],
                [900,300, 900,700],
                [900,700, 100,700],
                [100,700, 100,300]
            ];
            _obstacles = [
                [320,400, 22,100],  // top peg (hangs y 300..500)
                [460,600, 22,100],  // bottom peg (hangs y 500..700)
                [600,400, 22,100],
                [740,600, 22,100]
            ];
        } else if (idx == 11) {
            // 12. The Eye — circular wall around hole, single entrance gap
            _tx=140; _ty=500; _hx=620; _hy=500;
            _brownWalls = true;
            _walls = [
                [100,200, 900,200],
                [900,200, 900,800],
                [900,800, 100,800],
                [100,800, 100,200],
                // ring approximated by 12 segments around (620,500) r=180,
                // with a gap on the WEST side (facing the tee)
                [620 + 180,        500,                   620 + 156,  500 + 90],
                [620 + 156,  500 + 90,    620 + 90,   500 + 156],
                [620 + 90,   500 + 156,   620 + 0,    500 + 180],
                [620 + 0,    500 + 180,   620 - 90,   500 + 156],
                [620 - 90,   500 + 156,   620 - 156,  500 + 90],
                // gap from y=590 to y=410 on west side — entrance
                [620 - 156,  500 - 90,    620 - 90,   500 - 156],
                [620 - 90,   500 - 156,   620 + 0,    500 - 180],
                [620 + 0,    500 - 180,   620 + 90,   500 - 156],
                [620 + 90,   500 - 156,   620 + 156,  500 - 90],
                [620 + 156,  500 - 90,    620 + 180,  500 + 0]
            ];
        } else if (idx == 12) {
            // 13. Tunnel — narrow channel between water hazards
            _tx=140; _ty=500; _hx=860; _hy=500;
            _walls = [
                [100,200, 900,200],
                [900,200, 900,800],
                [900,800, 100,800],
                [100,800, 100,200]
            ];
            _water = [
                [500,260, 50],
                [500,740, 50],
                [350,500, 35],
                [650,500, 35]
            ];
        } else if (idx == 13) {
            // 14. Pinball — dense bumper cluster, must thread the needle
            _tx=160; _ty=160; _hx=840; _hy=840;
            _brownWalls = true;
            _walls = [
                [100,100, 900,100],
                [900,100, 900,900],
                [900,900, 100,900],
                [100,900, 100,100]
            ];
            _obstacles = [
                [280,280, 24,24], [500,280, 24,24], [720,280, 24,24],
                [380,440, 24,24], [620,440, 24,24],
                [280,560, 24,24], [500,560, 24,24], [720,560, 24,24],
                [380,720, 24,24], [620,720, 24,24]
            ];
        } else if (idx == 14) {
            // 15. Cross — 4 arms meeting at centre, hole at far end
            _tx=160; _ty=500; _hx=840; _hy=500;
            _walls = [
                // Horizontal arm
                [100,400, 400,400],
                [400,400, 400,150],
                [400,150, 600,150],
                [600,150, 600,400],
                [600,400, 900,400],
                [900,400, 900,600],
                [900,600, 600,600],
                [600,600, 600,850],
                [600,850, 400,850],
                [400,850, 400,600],
                [400,600, 100,600],
                [100,600, 100,400]
            ];
            _obstacles = [[500,500, 30,30]];
        } else if (idx == 15) {
            // 16. Volcano — hole sits inside ring of water, must drop in via top gap
            _tx=140; _ty=500; _hx=620; _hy=500;
            _brownWalls = true;
            _walls = [
                [100,200, 900,200],
                [900,200, 900,800],
                [900,800, 100,800],
                [100,800, 100,200]
            ];
            // Water moat surrounding the hole — leave one approach lane (north)
            _water = [
                [620, 620, 70],   // south
                [520, 540, 60],   // south-west
                [720, 540, 60],   // south-east
                [520, 460, 40],   // sliver west
                [720, 460, 40]    // sliver east
            ];
            _obstacles = [[820,500, 18,90]];
        } else if (idx == 16) {
            // 17. Snake — sinuous path with two animated pendulum bumpers
            _tx=140; _ty=500; _hx=860; _hy=500;
            _brownWalls = true;
            _walls = [
                [100,260, 900,260],
                [900,260, 900,740],
                [900,740, 100,740],
                [100,740, 100,260]
            ];
            // _obstacles populated by updateAnimated()
            _obstacles = [[500,380, 28,18], [500,620, 28,18]];
        } else if (idx == 17) {
            // 18. Triangle — triangular fairway, hole tucked in far corner
            _tx=180; _ty=820; _hx=820; _hy=820;
            _brownWalls = true;
            _walls = [
                [120,860, 880,860],     // base
                [880,860, 500,140],     // right slope
                [500,140, 120,860]      // left slope
            ];
            _obstacles = [[500,580, 32,80]];
        } else if (idx == 18) {
            // 19. Spiral — concentric rings with offset gaps lead inward to centre.
            // Tee starts in the outermost corridor, must thread three openings
            // to reach the cup at (500,500).
            _tx=140; _ty=160; _hx=500; _hy=500;
            _brownWalls = true;
            _walls = [
                // outer box (fully closed)
                [100,100, 900,100],
                [900,100, 900,900],
                [900,900, 100,900],
                [100,100, 100,900],
                // first inner ring — gap on LEFT (y 220..360)
                [220,220, 800,220],
                [800,220, 800,800],
                [800,800, 220,800],
                [220,800, 220,360],
                // second inner ring — gap on RIGHT (y 540..660), forces a half-lap
                [340,340, 660,340],
                [660,340, 660,540],
                [660,660, 340,660],
                [340,340, 340,660]
            ];
        } else if (idx == 19) {
            // 20. Boss Finale — combo: water + obstacles + bumpers + tight pocket
            _tx=140; _ty=140; _hx=860; _hy=860;
            _brownWalls = true;
            _walls = [
                [100,100, 900,100],
                [900,100, 900,900],
                [900,900, 100,900],
                [100,900, 100,100],
                // mid divider with two passages
                [200,500, 380,500],
                [620,500, 800,500]
            ];
            _obstacles = [
                [500,300, 30,90],
                [500,700, 30,90],
                [300,720, 28,28],
                [700,300, 28,28]
            ];
            _water = [[500,500, 60], [200,800, 50], [800,200, 50]];
        }

        _bx = _tx * 10; _by = _ty * 10;
        _lastBx = _bx; _lastBy = _by;
        _aimAngle = computeAimTowardHole();
        // Rebuild animated obstacles immediately so first frame looks correct
        updateAnimated();
    }

    hidden function computeAimTowardHole() {
        var dx = _hx - _tx; var dy = _hy - _ty;
        var ang = (Math.atan2(dy, dx) * 180 / Math.PI).toNumber();
        if (ang < 0) { ang += 360; }
        return ang;
    }

    // ── Coordinate helpers ────────────────────────────────────────────────────
    // Course (0-1000) → screen pixel — uniform scale, centered
    hidden function cToS_X(cx) { return _vpX + _offX + cx * _scale / 1000; }
    hidden function cToS_Y(cy) { return _vpY + _offY + cy * _scale / 1000; }
    hidden function cToS_R(cr) { return cr * _scale / 1000; }

    // ── Rendering ─────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); setupVP(); }
        if (_gs == MG_MENU)     { drawMenu(dc); return; }
        // Handle GAMEOVER before drawHUD — _holeIdx is 9 at this point (out of _par bounds)
        if (_gs == MG_GAMEOVER) { drawGameOver(dc); return; }
        drawCourse(dc);
        drawBall(dc);
        drawAimArrow(dc);
        drawHUD(dc);
        if (_gs == MG_POWER) { drawPowerBar(dc); }
        if (_gs == MG_HOLED) { drawHoledOverlay(dc); }
    }

    // ── Menu ─────────────────────────────────────────────────────────────────
    hidden function drawMenu(dc) {
        dc.setColor(0x0A1A08, 0x0A1A08); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0D3010, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);
        dc.setColor(0x144820, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 14);

        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 14 / 100, Graphics.FONT_MEDIUM, "MINIGOLF", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 28 / 100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        var diffLabels = ["Easy (20 holes)", "Normal", "Hard"];
        dc.setColor(0xCCEEBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 40 / 100, Graphics.FONT_XTINY, "Difficulty:", Graphics.TEXT_JUSTIFY_CENTER);

        var btnW = _w * 60 / 100; var btnH = 28; var btnX = (_w - btnW) / 2;
        var btnY = _h * 48 / 100;
        dc.setColor(0x1A5028, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(btnX, btnY, btnW, btnH, 6);
        dc.setColor(0x2A7040, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(btnX, btnY, btnW, btnH, 6);
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, btnY + 6, Graphics.FONT_XTINY, diffLabels[_difficulty], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x448833, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 62 / 100, Graphics.FONT_XTINY, "UP/DOWN change", Graphics.TEXT_JUSTIFY_CENTER);

        var sBtnW = _w * 55 / 100; var sBtnH = 30;
        var sBtnX = (_w - sBtnW) / 2; var sBtnY = _h * 72 / 100;
        dc.setColor(0x225500, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(sBtnX, sBtnY, sBtnW, sBtnH, 8);
        dc.setColor(0x44AA22, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(sBtnX, sBtnY, sBtnW, sBtnH, 8);
        dc.setColor((_tick % 10 < 5) ? 0x88FF44 : 0x55CC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, sBtnY + 7, Graphics.FONT_XTINY, "TAP TO PLAY", Graphics.TEXT_JUSTIFY_CENTER);
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

        // Obstacles. Roughly-square obstacles render as round bumper pegs (with
        // inner highlight) for that pinball look; rectangular ones stay as
        // wooden planks.
        for (var i = 0; i < _obstacles.size(); i++) {
            var ob = _obstacles[i];
            var minSide = ob[2] < ob[3] ? ob[2] : ob[3];
            if (minSide < 1) { minSide = 1; }
            var maxSide = ob[2] > ob[3] ? ob[2] : ob[3];
            var ratio = maxSide * 100 / minSide;
            if (ratio <= 130) {
                var cxp = cToS_X(ob[0]); var cyp = cToS_Y(ob[1]);
                var rp  = cToS_R((ob[2] + ob[3]) / 2 + 1);
                if (rp < 4) { rp = 4; }
                // Outer ring
                dc.setColor(0x442211, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cxp, cyp, rp + 1);
                // Brown body
                dc.setColor(0x884422, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cxp, cyp, rp);
                // Highlight (top-left)
                dc.setColor(0xCC8855, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cxp - rp/3, cyp - rp/3, rp/3 + 1);
                // Centre spark
                dc.setColor(0xFFCC88, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cxp - rp/3, cyp - rp/3, rp/6);
            } else {
                var sx = cToS_X(ob[0] - ob[2]); var sy = cToS_Y(ob[1] - ob[3]);
                var sw = cToS_R(ob[2] * 2 + 1); var sh = cToS_R(ob[3] * 2 + 1);
                if (sw < 4) { sw = 4; } if (sh < 4) { sh = 4; }
                dc.setColor(0x442211, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(sx - 1, sy - 1, sw + 2, sh + 2, 2);
                dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(sx, sy, sw, sh, 2);
                dc.setColor(0xAA7744, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(sx, sy, sw, sh, 2);
            }
        }

        // Walls — two visual themes:
        //   white (default): thin painted "rail" lines (CCDDBB)
        //   brown: chunky pinball-bumper rails drawn with setPenWidth so
        //   diagonal walls also look correct.
        if (_brownWalls) {
            // Dark outer outline
            dc.setPenWidth(7);
            dc.setColor(0x442211, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < _walls.size(); i++) {
                var wl = _walls[i];
                dc.drawLine(cToS_X(wl[0]), cToS_Y(wl[1]),
                            cToS_X(wl[2]), cToS_Y(wl[3]));
            }
            // Brown body
            dc.setPenWidth(5);
            dc.setColor(0x885533, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < _walls.size(); i++) {
                var wl = _walls[i];
                dc.drawLine(cToS_X(wl[0]), cToS_Y(wl[1]),
                            cToS_X(wl[2]), cToS_Y(wl[3]));
            }
            // Bright centre highlight
            dc.setPenWidth(1);
            dc.setColor(0xBB8855, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < _walls.size(); i++) {
                var wl = _walls[i];
                dc.drawLine(cToS_X(wl[0]), cToS_Y(wl[1]),
                            cToS_X(wl[2]), cToS_Y(wl[3]));
            }
        } else {
            dc.setPenWidth(2);
            dc.setColor(0xCCDDBB, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < _walls.size(); i++) {
                var wl = _walls[i];
                dc.drawLine(cToS_X(wl[0]), cToS_Y(wl[1]),
                            cToS_X(wl[2]), cToS_Y(wl[3]));
            }
            dc.setPenWidth(1);
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
        var bw = _w * 7 / 10; var bh = _h * 5 / 100; if (bh < 7) { bh = 7; }
        var bx = (_w - bw) / 2; var by = _h - bh - _h * 6 / 100;
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx - 1, by - 1, bw + 2, bh + 2, 3);
        var filled = bw * _power / 100;
        var clr = _power < 50 ? 0x44DD44 : (_power < 80 ? 0xFFCC00 : 0xFF3311);
        dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, filled, bh, 2);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 2);
        dc.drawText(_w / 2, by - _h * 4 / 100, Graphics.FONT_XTINY, "Power! Tap to shoot", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── HUD ───────────────────────────────────────────────────────────────────
    hidden function drawHUD(dc) {
        var hole = _holeIdx + 1;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _vpY);
        dc.setColor(0x88CCAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 4, Graphics.FONT_XTINY, "Hole " + hole + "/" + MG_HOLES, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, 4, Graphics.FONT_XTINY, "Par " + _par[_holeIdx], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 4, 4, Graphics.FONT_XTINY, "H " + _strokes, Graphics.TEXT_JUSTIFY_RIGHT);

        // Aim hint bottom
        if (_gs == MG_AIM) {
            dc.setColor(0x44AA66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _h - _h * 10 / 100, Graphics.FONT_XTINY, "Tap/^v aim  O shoot", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Holed overlay ────────────────────────────────────────────────────────
    hidden function drawHoledOverlay(dc) {
        var ow = _w * 68 / 100; var oh = _h * 36 / 100;
        var ox = (_w - ow) / 2; var oy = _h / 2 - oh / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ox, oy, ow, oh, 8);
        dc.setColor(0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(ox, oy, ow, oh, 8);

        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, oy + oh * 4 / 100, Graphics.FONT_MEDIUM, "HOLED!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, oy + oh * 36 / 100, Graphics.FONT_XTINY, _holeMsg, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, oy + oh * 56 / 100, Graphics.FONT_XTINY,
            "Strokes: " + _strokes + " / Par: " + _par[_holeIdx], Graphics.TEXT_JUSTIFY_CENTER);
        if (_holeWait <= 0) {
            dc.setColor((_tick % 8 < 4) ? 0x88CCFF : 0x4488AA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, oy + oh * 76 / 100, Graphics.FONT_XTINY, "Tap > next hole", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Game over ─────────────────────────────────────────────────────────────
    // Two-column scorecard so all 20 holes fit even on small displays.
    hidden function drawGameOver(dc) {
        dc.setColor(0x050D04, 0x050D04); dc.clear();
        var r = _w / 2;
        dc.setColor(0x0A2010, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(r, r, r - 2);

        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 6 / 100, Graphics.FONT_MEDIUM, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        var totalPar = 0; for (var i = 0; i < MG_HOLES; i++) { totalPar += _par[i]; }
        var diff = _totalStrokes - totalPar;
        var diffStr = diff == 0 ? "E" : (diff > 0 ? "+" + diff : "" + diff);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 18 / 100, Graphics.FONT_XTINY,
            "Total " + _totalStrokes + " / par " + totalPar + " (" + diffStr + ")",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Two columns × 10 rows
        var topY  = _h * 26 / 100;
        var botY  = _h * 80 / 100;
        var rowsH = botY - topY;
        var rowH  = rowsH / 10;
        if (rowH < 10) { rowH = 10; }
        var colLX = _w * 28 / 100;
        var colRX = _w * 72 / 100;

        for (var i = 0; i < MG_HOLES; i++) {
            var col = (i < 10) ? 0 : 1;
            var row = i % 10;
            var rx = (col == 0) ? colLX : colRX;
            var ry = topY + row * rowH;
            if (ry + rowH > _h - 4) { break; }

            var sc = _scoreCard[i];
            var pd = (sc >= 0) ? sc - _par[i] : 0;
            var clr = 0x888888;
            if (sc >= 0) {
                if (pd < 0)        { clr = 0x44FF88; }
                else if (pd == 0)  { clr = 0xFFFFFF; }
                else if (pd == 1)  { clr = 0xFFAA44; }
                else               { clr = 0xFF5544; }
            }
            dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
            var label = (sc >= 0) ? sc.toString() : "-";
            dc.drawText(rx, ry, Graphics.FONT_XTINY,
                "H" + (i + 1) + " " + label, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0x44FF88 : 0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 92 / 100, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
