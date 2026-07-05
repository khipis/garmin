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

// ── Global leaderboard ─────────────────────────────────────────────────────
// Metric submitted = a POSITIVE points total (HIGHER is better). The old
// "total strokes for 20 holes" board had no fail state — every player could
// grind every hole, so the board never really meant anything. Now you have a
// limited number of balls per hole (shrinking with hole number AND difficulty)
// and 3 lives: run out of balls on a hole → lose a life; lose all lives → the
// run ends. You bank points for every hole you sink (plus a leftover-ball
// efficiency bonus), so the board ranks how FAR you got and how CLEANLY you
// played. Variant = difficulty so Easy/Normal/Hard rank separately.
const LB_GAME_ID = "minigolf";

// Lives the player starts a run with.
const MG_START_LIVES = 3;

// Points banked for sinking a hole, before the leftover-ball bonus.
const MG_HOLE_POINTS = 500;

// Menu focus rows. UP/DOWN edits the focused selector (difficulty) or moves
// focus between the action rows; SELECT activates the focused row.
const MG_ROW_DIFF = 0;
const MG_ROW_PLAY = 1;
const MG_ROW_LB   = 2;
const MG_MENU_ROWS = 3;

// ── Wall segment: [x1, y1, x2, y2] (coords in 0..1000 space) ────────────────
// Course space is 0-1000 × 0-1000, rendered into game viewport at runtime.

class BitochiMinigolfView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;
    hidden var _gs;

    // Difficulty / level selection
    hidden var _difficulty;  // 0=Easy 1=Normal 2=Hard
    hidden var _menuRow;     // focused menu row (MG_ROW_*)
    // 20 holes total. Difficulty multiplies the target par allowance only,
    // not the level layout (every player faces the same 20 designs).
    hidden var _holeIdx;     // 0..MG_HOLES-1
    hidden var _strokes;     // strokes this hole
    hidden var _totalStrokes;
    hidden var _par;         // [MG_HOLES] par per hole

    // ── Lives / balls / score ──────────────────────────────────────────────
    hidden var _lives;        // remaining lives (0 → game over)
    hidden var _ballsThisHole;// max strokes allowed to sink the current hole
    hidden var _score;        // running points total (submitted to leaderboard)
    hidden var _holesSunk;    // count of holes successfully completed
    hidden var _outOfLives;   // true if the run ended by losing all lives

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

    // Sand traps ([cx,cy,r] in 0-1000 space) — heavy extra friction while the
    // ball's centre is inside, no reset (unlike water). Pure additive hazard.
    hidden var _sand;

    // Boost pads ([cx,cy,r,dirDeg] in 0-1000 space) — conveyor-style constant
    // push while the ball's centre is inside, direction in degrees.
    hidden var _boost;

    // Post-hole state
    hidden var _holeMsg;
    hidden var _holeWait;

    // Ball trail — short fading history of recent positions while rolling.
    const MG_TRAIL_LEN = 8;
    hidden var _trailX; hidden var _trailY; hidden var _trailN;

    // Hole-in-one tracking (this run) — mirrored to a secondary "aces"
    // leaderboard variant, and a screen-shake celebration.
    hidden var _aceCount;
    hidden var _shakeT;

    // True if the run finished all 20 holes without ever losing a life —
    // shown + bonus-scored on the game-over screen.
    hidden var _flawless;

    // Static course background cache (fairway, border, water, sand, boost
    // pads, walls, tee, cup) — rebuilt only when the hole or screen size
    // changes, since none of these elements move frame-to-frame. Animated
    // obstacles (windmill/pendulum) and the ball/aim/HUD stay live on top.
    hidden var _courseBmp; hidden var _courseBmpW; hidden var _courseBmpH; hidden var _courseBmpHole;

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
        _gs = MG_MENU; _difficulty = 1; _menuRow = MG_ROW_PLAY;
        _holeIdx = 0; _strokes = 0; _totalStrokes = 0;
        _lives = MG_START_LIVES; _ballsThisHole = 0; _score = 0;
        _holesSunk = 0; _outOfLives = false;
        _aimAngle = 0; _power = 0; _powerDir = 1;
        _ballR = 14; _holeR = 20;
        // Par tuned per layout difficulty (warm-up → finale).
        _par = [
            2, 3, 3, 4, 3,    // 1-5  intro / L-bend / U-block / Z-corridor / island
            3, 3, 3, 4, 3,    // 6-10 windmill / diamond / bumpers / hourglass / funnel
            3, 4, 3, 4, 4,    // 11-15 slalom / eye / tunnel / pinball / cross-turn
            4, 3, 4, 4, 5     // 16-20 volcano / snake / triangle / spiral / boss
        ];
        _scoreCard = new [MG_HOLES];
        for (var i = 0; i < MG_HOLES; i++) { _scoreCard[i] = -1; }
        _walls = new [0]; _obstacles = new [0]; _water = new [0];
        _sand = new [0]; _boost = new [0];
        _holeMsg = ""; _holeWait = 0; _animPhase = 0;
        _brownWalls = false;
        _timer = null;

        _trailX = new [MG_TRAIL_LEN]; _trailY = new [MG_TRAIL_LEN]; _trailN = 0;
        for (var i = 0; i < MG_TRAIL_LEN; i++) { _trailX[i] = 0; _trailY[i] = 0; }
        _aceCount = 0; _shakeT = 0; _flawless = false;
        _courseBmp = null; _courseBmpW = 0; _courseBmpH = 0; _courseBmpHole = -1;
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        setupVP();
    }

    // Run the 50 ms game loop only while the view is on screen, and stop
    // it when hidden (e.g. the leaderboard is pushed on top, or the app is
    // backgrounded) so we never leave a timer firing requestUpdate() and
    // stepping physics after teardown.
    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 50, true);
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
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
        if (_gs == MG_ROLLING) {
            // Push current position into the fading trail before stepping.
            for (var i = MG_TRAIL_LEN - 1; i > 0; i--) {
                _trailX[i] = _trailX[i-1]; _trailY[i] = _trailY[i-1];
            }
            _trailX[0] = _bx; _trailY[0] = _by;
            if (_trailN < MG_TRAIL_LEN) { _trailN++; }
            stepPhysics();
        } else if (_trailN > 0) {
            _trailN--;
        }
        if (_shakeT > 0) { _shakeT--; }
        if (_gs == MG_HOLED && _holeWait > 0) { _holeWait--; }
        WatchUi.requestUpdate();
    }

    // ── Physics ───────────────────────────────────────────────────────────────
    // Realistic-feel rolling: low rolling friction (94% retention), elastic
    // walls (~90%), high substep count to avoid tunneling on fast shots, and
    // velocity-based sub-step subdivision so slow balls aren't over-processed.
    hidden function stepPhysics() {
        // Rolling friction — 96% retention for a lively, satisfying roll.
        _vx = _vx * 96 / 100;
        _vy = _vy * 96 / 100;

        // ── Tunneling-proof adaptive substep ──────────────────────────
        // The wall-collision routine only inspects the ball's position
        // AFTER each substep.  If the per-substep displacement ever
        // exceeds the ball radius, a fast-moving ball can leap over a
        // thin wall without the test ever seeing the ball within range
        // of the segment — i.e. it tunnels through.  Players read this
        // as "white lines can be crossed with a hard enough shot".
        //
        // We pick SUB so per-substep displacement is well under HALF
        // the ball radius — that's a 2× safety margin over the bare
        // minimum (radius).  In course-space×10 fixed units that means
        // step ≤ _ballR · 5 = 70 for the default _ballR = 14.  Max
        // possible shot speed at full power ≈ 2522 → SUB ≈ 37, capped
        // at 40 to keep per-tick cost bounded.  The extra margin makes
        // bounces against thin white rails feel as solid as the chunky
        // brown bumper walls — they catch the ball even at a glancing
        // angle near a corner where a tighter substep budget could
        // squeeze a fast ball through the seam.
        var spd2 = _vx * _vx + _vy * _vy;
        var safeStepFixed = _ballR * 5;   // = 70 for default ballR
        var SUB = 3;
        if (spd2 > safeStepFixed * safeStepFixed * 9) {
            var spdF = Math.sqrt(spd2.toFloat());
            SUB = (spdF / safeStepFixed.toFloat() + 1.0).toNumber();
            if (SUB < 3)  { SUB = 3;  }
            if (SUB > 40) { SUB = 40; }
        }
        var svx = _vx / SUB; var svy = _vy / SUB;

        for (var s = 0; s < SUB; s++) {
            // Stash the pre-step position so `resolveWall` can do
            // side-aware collision (i.e. detect a tunneling pass and
            // bounce the ball back to the side it CAME FROM, not the
            // side it currently happens to be on after over-shooting).
            var pbx = _bx;
            var pby = _by;
            _bx += svx;
            _by += svy;

            for (var i = 0; i < _walls.size(); i++) {
                var w = _walls[i];
                resolveWall(w[0], w[1], w[2], w[3], pbx, pby);
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
                    settleAfterShot(); return;
                }
            }

            // Sand trap — heavy extra drag while the ball's centre is inside;
            // the ball keeps rolling, it just bleeds speed much faster.
            for (var i = 0; i < _sand.size(); i++) {
                var sd = _sand[i];
                var sdx = _bx/10 - sd[0]; var sdy = _by/10 - sd[1];
                if (sdx*sdx + sdy*sdy < sd[2]*sd[2]) {
                    _vx = _vx * 82 / 100; _vy = _vy * 82 / 100;
                    break;
                }
            }

            // Boost pad — conveyor-style constant push in a fixed direction
            // while the ball's centre is inside.
            for (var i = 0; i < _boost.size(); i++) {
                var bp = _boost[i];
                var bdx = _bx/10 - bp[0]; var bdy = _by/10 - bp[1];
                if (bdx*bdx + bdy*bdy < bp[2]*bp[2]) {
                    var brad = bp[3] * Math.PI / 180;
                    _vx += (Math.cos(brad) * 55).toNumber();
                    _vy += (Math.sin(brad) * 55).toNumber();
                    break;
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

        // Course-perimeter safety net — invisible bouncy fence around
        // the entire 0-1000 play area.  If a ball ever squeezes past
        // a corner of the hole's walls, it ricochets back inward
        // instead of disappearing off-screen and respawning at the
        // tee.  Players expect the white visible edges of the play
        // area to bounce the ball just like a solid wall, and this
        // guarantees that — even on holes whose `_walls` don't fully
        // hug the green's outline.
        var rFixed = _ballR * 10;
        if (_bx < rFixed) {
            _bx = rFixed;
            if (_vx < 0) { _vx = -_vx * 97 / 100; }
        } else if (_bx > 10000 - rFixed) {
            _bx = 10000 - rFixed;
            if (_vx > 0) { _vx = -_vx * 97 / 100; }
        }
        if (_by < rFixed) {
            _by = rFixed;
            if (_vy < 0) { _vy = -_vy * 97 / 100; }
        } else if (_by > 10000 - rFixed) {
            _by = 10000 - rFixed;
            if (_vy > 0) { _vy = -_vy * 97 / 100; }
        }

        // Stop threshold — slightly higher so ball settles cleanly near hole
        var spdEnd = _vx * _vx + _vy * _vy;
        if (spdEnd < 36) {
            _vx = 0; _vy = 0;
            settleAfterShot();
        }
    }

    // Wall segment collision — TUNNEL-PROOF, billiards-style reflection.
    //
    // Units bible (this is where the old code was secretly broken):
    //   _bx, _by   : course units × 10        (fixed-point position)
    //   _vx, _vy   : course units × 10 / tick (fixed-point velocity)
    //   wx, wy     : course units             (wall direction vector)
    //   len        : course units             (wall length, integer)
    //   nx, ny     : unit_vector × 10         (wall normal, ×10 scale)
    //
    // Dot product of velocity with the UNIT normal (n_unit = n / 10):
    //   v · n_unit = (_vx + _vy) · (nx/10, ny/10)
    //              = (_vx · nx + _vy · ny) / 10
    // Reflection in FIXED units:
    //   _vx_new = _vx − 2 · (v · n_unit) · nx_unit
    //           = _vx − 2 · ((_vx*nx + _vy*ny)/10) · (nx/10)
    //           = _vx − 2 · (_vx*nx + _vy*ny) * nx / 100
    //
    // So the canonical billiards-style reflection here is:
    //   var vd = (_vx*nxOut + _vy*nyOut);   // ×100 of v·n_unit
    //   _vx -= nxOut * vd / 50;             //  ÷50 = ÷100 × 2
    //   _vy -= nyOut * vd / 50;
    //
    // The old code used `vd / 100` for the dot and then `* 2 / 10`
    // for the reflection — that's 10× weaker than physically
    // correct.  Players saw the ball lose the perpendicular
    // component asymptotically over many substeps with the parallel
    // component fully preserved → it "slid" along the wall instead
    // of bouncing off.  Fixed below.
    //
    // Side tracking (tunnel-proof): `pbx, pby` is the ball position
    // BEFORE this substep.  We compute the signed perp distance
    // before/after and detect sign flips — if it flipped while
    // inside the segment, the ball tunneled; we push it back to the
    // ORIGINAL side and reflect velocity.
    //
    // Both white rails and brown bumpers: 97 % restitution.
    hidden function resolveWall(x1, y1, x2, y2, pbx, pby) {
        var wx = (x2 - x1); var wy = (y2 - y1);
        var lenSq = wx * wx + wy * wy;
        if (lenSq == 0) { return; }
        var len = Math.sqrt(lenSq).toNumber();
        if (len == 0) { return; }

        // Wall normal × 10 (CCW perpendicular).
        var nx = -wy * 10 / len; var ny = wx * 10 / len;

        var bcx = _bx / 10; var bcy = _by / 10;
        var pcx = pbx / 10; var pcy = pby / 10;

        // Signed perp distance × 10  (sign-only checks below).
        var sdNowS  = (bcx - x1) * nx + (bcy - y1) * ny;
        var sdPrevS = (pcx - x1) * nx + (pcy - y1) * ny;

        // Find nearest point on segment to the CURRENT ball.
        var dx = bcx - x1; var dy = bcy - y1;
        var t = dx * wx + dy * wy;
        var px; var py;
        var inSegment = (t > 0 && t < lenSq);
        if (t <= 0)         { px = x1; py = y1; }
        else if (t >= lenSq) { px = x2; py = y2; }
        else {
            px = x1 + (wx * t / lenSq);
            py = y1 + (wy * t / lenSq);
        }
        var rx = bcx - px; var ry = bcy - py;
        var dist2 = rx * rx + ry * ry;

        // Tunnel: sign flipped between substeps & crossing inside segment.
        var tunneled = (inSegment && sdPrevS != 0 && sdNowS != 0
                        && ((sdPrevS > 0) != (sdNowS > 0)));
        var normalCollide = (dist2 < _ballR * _ballR);
        if (!tunneled && !normalCollide) { return; }

        // Outward direction = toward the side the ball came from.
        var fromPlus = (sdPrevS >= 0);

        // Endcap fallback (ball nearer an endpoint than the wall line)
        if (!inSegment && !tunneled) {
            var dist = Math.sqrt(dist2).toNumber();
            if (dist == 0) {
                // Exactly on endpoint — push along the prev-side normal.
                var ex = fromPlus ? nx : -nx;
                var ey = fromPlus ? ny : -ny;
                _bx += ex * _ballR;
                _by += ey * _ballR;
                // Reflect along ex, ey (×10 unit vector).
                var ved = (_vx * ex + _vy * ey);
                if (ved < 0) {
                    // Reflection: subtract 2·(v·n_unit)·n_unit, scaled
                    // to fixed:  ved / 50  (see units bible above).
                    _vx -= ex * ved / 50;
                    _vy -= ey * ved / 50;
                    _vx = _vx * 97 / 100;
                    _vy = _vy * 97 / 100;
                }
                return;
            }
            // Radial push from endpoint (×10 unit vector toward ball).
            var ux = rx * 10 / dist; var uy = ry * 10 / dist;
            var overlap = _ballR - dist;
            _bx += ux * overlap;
            _by += uy * overlap;
            var vdu = (_vx * ux + _vy * uy);
            if (vdu < 0) {
                _vx -= ux * vdu / 50;
                _vy -= uy * vdu / 50;
                _vx = _vx * 97 / 100;
                _vy = _vy * 97 / 100;
            }
            return;
        }

        // In-segment resolution — push along the WALL NORMAL toward
        // the prev side, regardless of whether the ball tunneled or
        // is just inside R.  Then reflect velocity along that normal.
        var nxOut = fromPlus ? nx : -nx;
        var nyOut = fromPlus ? ny : -ny;

        // Signed distance in course units; positive on the prev side.
        var sdNowCu = sdNowS / 10;
        var signedFromPrev = fromPlus ? sdNowCu : -sdNowCu;
        var pushAmt = _ballR - signedFromPrev;
        if (pushAmt < 0) { pushAmt = 0; }
        // nxOut/nyOut are ×10, pushAmt is course units → product is
        // in fixed (course × 10), same scale as _bx/_by.
        _bx += nxOut * pushAmt;
        _by += nyOut * pushAmt;

        // Billiards-style reflection.  vdn = (_vx*nxOut + _vy*nyOut)
        // is 100× the actual v·n_unit; the reflection is
        // 2·(v·n_unit)·n_unit_fixed = vdn / 50 along nxOut, nyOut.
        var vdn = (_vx * nxOut + _vy * nyOut);
        if (vdn < 0) {
            _vx -= nxOut * vdn / 50;
            _vy -= nyOut * vdn / 50;
            _vx = _vx * 97 / 100;
            _vy = _vy * 97 / 100;
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

        // Obstacles act like real pinball bumpers — ~95% retention.
        if (minO == overL && _vx > -1)       { _bx -= overL; _vx = -(_vx * 95 / 100); }
        else if (minO == overR && _vx < 1)   { _bx += overR; _vx = -(_vx * 95 / 100); }
        else if (minO == overT && _vy > -1)  { _by -= overT; _vy = -(_vy * 95 / 100); }
        else if (minO == overB && _vy < 1)   { _by += overB; _vy = -(_vy * 95 / 100); }
        else if (minO == overL)              { _bx -= overL; _vx = -(_vx * 95 / 100); }
        else if (minO == overR)              { _bx += overR; _vx = -(_vx * 95 / 100); }
        else if (minO == overT)              { _by -= overT; _vy = -(_vy * 95 / 100); }
        else                                 { _by += overB; _vy = -(_vy * 95 / 100); }
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
        _holesSunk++;

        // Points: flat reward for sinking + a bonus for every ball you had
        // left in the tank. Sinking quickly (birdie/eagle) leaves more balls
        // unused → more points, so cleaner play scores higher.
        var leftover = _ballsThisHole - _strokes;
        if (leftover < 0) { leftover = 0; }
        _score += MG_HOLE_POINTS + leftover * 100;

        if (_strokes == 1) {
            // HOLE IN ONE — a big bonus plus a screen-shake celebration.
            _aceCount++;
            _score += 750;
            _holeMsg = "HOLE IN ONE!!!";
            _shakeT = 14;
            doVibe(90, 300);
        } else {
            var diff = _strokes - _par[_holeIdx];
            if (diff <= -2)     { _holeMsg = "Eagle! **"; }
            else if (diff == -1){ _holeMsg = "Birdie! *"; }
            else if (diff == 0) { _holeMsg = "Par!"; }
            else if (diff == 1) { _holeMsg = "Bogey"; }
            else                { _holeMsg = "+" + diff; }
        }
        _holeWait = 12;
        _gs = MG_HOLED;
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) { if (Toybox.Attention has :vibrate) {
            Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
        } }
    }

    // Called whenever the ball comes to rest in play without sinking. If the
    // player has used up their ball allowance for this hole, they lose a life
    // and the hole is abandoned (DNF); otherwise play continues.
    hidden function settleAfterShot() {
        if (_strokes >= _ballsThisHole) {
            failHole();
        } else {
            _gs = MG_AIM;
        }
    }

    // Out of balls on this hole → lose a life, mark the hole DNF, and show the
    // result overlay. Tapping advances (or ends the run) via nextHole().
    hidden function failHole() {
        _lives--;
        _scoreCard[_holeIdx] = -2;   // DNF marker
        _vx = 0; _vy = 0;
        _holeMsg = "Out of balls!";
        _holeWait = 12;
        _gs = MG_HOLED;
    }

    // Ball allowance for a hole: par plus a difficulty margin that tightens as
    // the course progresses. Floored at par so flawless play always survives.
    //   Easy +3 / Normal +2 / Hard +1, minus 1 ball per ~7 holes reached.
    hidden function ballsForHole(idx) {
        var margin = [3, 2, 1][_difficulty];
        var shrink = idx / 7;             // 0 (holes 1-7), 1 (8-14), 2 (15-20)
        var balls = _par[idx] + margin - shrink;
        if (balls < _par[idx]) { balls = _par[idx]; }
        return balls;
    }

    // Leaderboard variant = difficulty, so Easy/Normal/Hard rank separately.
    hidden function _diffVariant() {
        return ["easy", "normal", "hard"][_difficulty];
    }

    // ── Input ─────────────────────────────────────────────────────────────────
    function doUp() {
        if (_gs == MG_MENU)     { menuNav(-1); return; }
        if (_gs == MG_GAMEOVER) { _gs = MG_MENU; return; }
        if (_gs == MG_AIM)      { _aimAngle = (_aimAngle + 350) % 360; }  // -10° per step
        if (_gs == MG_POWER)    { commitShot(); }
    }

    function doDown() {
        if (_gs == MG_MENU)     { menuNav(1); return; }
        if (_gs == MG_GAMEOVER) { _gs = MG_MENU; return; }
        if (_gs == MG_AIM)      { _aimAngle = (_aimAngle + 10) % 360; }   // +10° per step
        if (_gs == MG_POWER)    { commitShot(); }
    }

    // UP/DOWN in the menu: when the difficulty row is focused, change the
    // difficulty; otherwise move focus between the action rows.
    hidden function menuNav(dir) {
        if (_menuRow == MG_ROW_DIFF) {
            _difficulty = (_difficulty + dir + 3) % 3;
        } else {
            _menuRow = (_menuRow + dir + MG_MENU_ROWS) % MG_MENU_ROWS;
        }
    }

    function doSelect() {
        if (_gs == MG_MENU)     { menuActivate(); return; }
        if (_gs == MG_GAMEOVER) { _gs = MG_MENU; return; }
        if (_gs == MG_AIM)      { _gs = MG_POWER; _power = 0; _powerDir = 1; return; }
        if (_gs == MG_POWER)    { commitShot(); return; }
        if (_gs == MG_HOLED)    { nextHole(); return; }
    }

    hidden function menuActivate() {
        if (_menuRow == MG_ROW_DIFF)      { _menuRow = MG_ROW_PLAY; }
        else if (_menuRow == MG_ROW_PLAY) { startGame(); }
        else if (_menuRow == MG_ROW_LB)   { openLeaderboard(); }
    }

    // Open the shared global leaderboard for the selected difficulty.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _diffVariant(), "MINIGOLF");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function doBack() {
        if (_gs != MG_MENU) { _gs = MG_MENU; return true; }
        return false;
    }

    function doMenu() { return doBack(); }

    function doTap(tx, ty) {
        if (_gs == MG_MENU)     { menuTap(tx, ty); return; }
        if (_gs == MG_GAMEOVER) { _gs = MG_MENU; return; }
        if (_gs == MG_HOLED && _holeWait <= 0) { nextHole(); return; }
        if (_gs == MG_ROLLING)  { return; }

        if (_gs == MG_AIM) {
            // Tap away from ball → set aim direction only (does NOT start power bar).
            // Press SELECT / O button to start charging. Two-step flow: aim → charge → fire.
            var bsx = cToS_X(_bx / 10); var bsy = cToS_Y(_by / 10);
            var dx = tx - bsx; var dy = ty - bsy;
            if (dx*dx + dy*dy > 100) {
                _aimAngle = (Math.atan2(dy, dx) * 180 / Math.PI).toNumber();
                if (_aimAngle < 0) { _aimAngle += 360; }
                // Stay in MG_AIM so player can fine-tune angle before shooting
            } else {
                // Tap directly on ball → start power bar (shortcut for experienced players)
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

    // Shared menu layout — returns [diffRect, playRect, lbRect], each [x,y,w,h].
    // Buttons are ~18% smaller than the original single-button menu so the
    // extra LEADERBOARD row never overlaps neighbours on round watch faces.
    hidden function menuLayout() {
        var diffW = _w * 45 / 100; var diffH = 22;
        var diffX = (_w - diffW) / 2; var diffY = _h * 41 / 100;
        var playW = _w * 41 / 100; var playH = 22;
        var playX = (_w - playW) / 2; var playY = _h * 55 / 100;
        var lbW = _w * 56 / 100; var lbH = 22;
        var lbX = (_w - lbW) / 2; var lbY = _h * 71 / 100;
        return [
            [diffX, diffY, diffW, diffH],
            [playX, playY, playW, playH],
            [lbX, lbY, lbW, lbH]
        ];
    }

    hidden function hitRect(tx, ty, r) {
        return tx >= r[0] && tx <= r[0] + r[2] && ty >= r[1] && ty <= r[1] + r[3];
    }

    hidden function menuTap(tx, ty) {
        var L = menuLayout();
        if (hitRect(tx, ty, L[MG_ROW_DIFF])) {
            _menuRow = MG_ROW_DIFF;
            _difficulty = (_difficulty + 1) % 3;
            return;
        }
        if (hitRect(tx, ty, L[MG_ROW_LB])) {
            _menuRow = MG_ROW_LB;
            openLeaderboard();
            return;
        }
        // Anywhere else (including the PLAY button) starts the round.
        _menuRow = MG_ROW_PLAY;
        startGame();
    }

    hidden function startGame() {
        _holeIdx = 0; _totalStrokes = 0; _strokes = 0;
        _lives = MG_START_LIVES; _score = 0; _holesSunk = 0; _outOfLives = false;
        _aceCount = 0; _flawless = false; _trailN = 0;
        for (var i = 0; i < MG_HOLES; i++) { _scoreCard[i] = -1; }
        loadHole(_holeIdx);
        _gs = MG_AIM;
    }

    hidden function nextHole() {
        // Run ends the moment the player is out of lives…
        if (_lives <= 0) {
            _outOfLives = true;
            endRun();
            return;
        }
        _holeIdx++;
        // …or when all holes have been played.
        if (_holeIdx >= MG_HOLES) {
            endRun();
            return;
        }
        _strokes = 0;
        loadHole(_holeIdx);
        _gs = MG_AIM;
    }

    // Submit the points total (HIGHER is better) for this difficulty and show
    // the post-game leaderboard.
    hidden function endRun() {
        // Flawless Round — finished every hole without ever losing a life.
        if (!_outOfLives && _lives == MG_START_LIVES) {
            _flawless = true;
            _score += 1000;
        }
        var variant = _diffVariant();
        Leaderboard.submitScore(LB_GAME_ID, _score, variant);
        if (_aceCount > 0) { Leaderboard.submitScore(LB_GAME_ID, _aceCount, "aces"); }
        Leaderboard.showPostGame(LB_GAME_ID, variant, "MINIGOLF");
        _gs = MG_GAMEOVER;
    }

    // ── Hole definitions ──────────────────────────────────────────────────────
    // Course coords 0-1000 × 0-1000
    // Walls format: [x1,y1, x2,y2] — solid boundary segments
    // Obstacles: [cx,cy, halfW,halfH] — solid rectangles
    // Water: [cx,cy, r] — circular hazards (ball resets to tee +1 stroke)

    hidden function loadHole(idx) {
        _vx = 0; _vy = 0;
        _walls = new [0]; _obstacles = new [0]; _water = new [0];
        _sand = new [0]; _boost = new [0];
        _brownWalls = false;
        _trailN = 0;

        if (idx == 0) {
            // 1. Straight corridor — easy intro with two angled deflectors
            _tx=120; _ty=500; _hx=880; _hy=500;
            _walls = [
                [100,400, 900,400],
                [900,400, 900,600],
                [900,600, 100,600],
                [100,600, 100,400]
            ];
            _obstacles = [[380,440, 14,40], [620,520, 14,40]];
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
            // 3. U-Turn — central block sticking up from the bottom
            //    rail forces the player to loft the ball OVER the
            //    obstacle (or thread the narrow lane along one side).
            //    Cleaner geometry than the old inverted-U dogleg —
            //    just a closed outer rectangle with a 3-walled inner
            //    "tongue" rooted on the bottom rail.
            _tx=140; _ty=800; _hx=860; _hy=800;
            _walls = [
                [100,200, 900,200],     // outer top
                [900,200, 900,900],     // outer right
                [900,900, 100,900],     // outer bottom
                [100,900, 100,200],     // outer left
                [350,420, 650,420],     // block top
                [650,420, 650,900],     // block right (touches outer bottom)
                [350,900, 350,420]      // block left (touches outer bottom)
            ];
        } else if (idx == 3) {
            // 4. Z-Corridor — three connected lanes shaped like a Z.
            //    Bottom lane (full width) → vertical bridge on the
            //    right → top lane (full width).  Tee and hole sit on
            //    opposite ends of the LEFT edge so the ball has to
            //    trace the full Z: right ⇒ up ⇒ left.
            _tx=180; _ty=800; _hx=180; _hy=200;
            _walls = [
                // outer rect
                [100,100, 900,100],
                [900,100, 900,900],
                [900,900, 100,900],
                [100,900, 100,100],
                // inner Z dividers (each leaves the right 1/3 open
                // so balls transition between lanes via the bridge)
                [100,400, 600,400],     // top divider (gap at x=600..900)
                [600,400, 600,700],     // bridge left wall
                [100,700, 600,700]      // bottom divider (gap at x=600..900)
            ];
            // Sand patch on the bridge — punishes a too-hard power shot
            // through the narrow vertical passage.
            _sand = [[750, 550, 65]];
        } else if (idx == 4) {
            // 5. Island Green — water lake, two channels around it (top & bottom)
            _tx=140; _ty=500; _hx=860; _hy=500;
            _walls = [
                [100,250, 900,250],
                [900,250, 900,750],
                [900,750, 100,750],
                [100,750, 100,250]
            ];
            _water = [[500,500, 110]];  // slightly smaller so top/bottom lanes are playable
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
            // 9. Hourglass — two trapezoid bowls joined by a narrow
            //    waist.  Must thread the 60-wide waist (~3 ball
            //    diameters) without scraping the converging walls.
            //
            //    Bowls widened from x=150 → x=100 (and 850 → 900) vs
            //    the earlier design.  The previous geometry placed
            //    the tee at (200, 200), but the left slope at that y
            //    sat at x ≈ 208 — i.e. the tee was actually ~8 px
            //    *outside* the bowl.  The resolver pushed the ball
            //    sideways on frame 1 and the hole started with the
            //    ball glued against the diagonal wall.
            _tx=200; _ty=220; _hx=800; _hy=780;
            _brownWalls = true;
            _walls = [
                // top bowl
                [100,140, 900,140],   // top
                [900,140, 530,470],   // right slope
                [100,140, 470,470],   // left slope
                // waist (vertical channel — 60 c.u. wide ≈ 3 ball Ø)
                [470,470, 470,530],
                [530,470, 530,530],
                // bottom bowl
                [470,530, 100,860],
                [530,530, 900,860],
                [100,860, 900,860]    // bottom
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
            // Boost pad in the throat — a satisfying kick straight toward
            // the pocket once you've threaded the narrow gap.
            _boost = [[750, 500, 55, 0]];
        } else if (idx == 10) {
            // 11. Slalom — alternating pegs, shorter so there is room to thread through.
            _tx=140; _ty=500; _hx=860; _hy=500;
            _walls = [
                [100,280, 900,280],
                [900,280, 900,720],
                [900,720, 100,720],
                [100,720, 100,280]
            ];
            _obstacles = [
                [310,360, 20,80],   // top peg — gap below (y 440..720)
                [460,580, 20,80],   // bottom peg — gap above (y 280..500)
                [610,360, 20,80],
                [760,580, 20,80]
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
            // 15. Crossroads — plus-shaped fairway, but the hole is
            //     now in the TOP arm (was at the far end of the
            //     horizontal arm).  Tee in the left arm, hole in the
            //     top arm, so the player has to make a clean 90° turn
            //     at the centre using bumper-deflected bank shots.
            _tx=160; _ty=500; _hx=500; _hy=200;
            _walls = [
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
            _obstacles = [[500,500, 24,24]];
        } else if (idx == 15) {
            // 16. Volcano — hole sits inside a water ring, narrow north approach lane
            _tx=140; _ty=500; _hx=580; _hy=500;
            _brownWalls = true;
            _walls = [
                [100,200, 900,200],
                [900,200, 900,800],
                [900,800, 100,800],
                [100,800, 100,200]
            ];
            // Water moat — gap on WEST side (x<500) for clear approach from tee
            _water = [
                [580, 640, 65],   // south
                [580, 360, 65],   // north (behind hole)
                [700, 500, 55],   // east
                [680, 580, 40],   // SE
                [680, 420, 40]    // NE
            ];
            _obstacles = [[800,500, 20,80]];
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
            // Sand along the base — punishes a lazy straight shot instead of
            // arcing around the central block.
            _sand = [[330, 760, 55]];
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
            // Finale flourish: a sand trap to punish a sloppy approach near
            // the top obstacle, and a boost pad in the LEFT passage (clear
            // of the centre water pond) that kicks the ball down toward
            // the bottom half once threaded.
            _sand = [[350, 250, 50]];
            _boost = [[150, 500, 35, 90]];
        }

        _bx = _tx * 10; _by = _ty * 10;
        _lastBx = _bx; _lastBy = _by;
        _ballsThisHole = ballsForHole(idx);
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

        var ox = 0; var oy = 0;
        if (_shakeT > 0) {
            ox = (Math.rand().abs() % 5) - 2;
            oy = (Math.rand().abs() % 5) - 2;
        }

        _drawCourseCached(dc, ox, oy);
        drawObstacles(dc);
        drawTrail(dc);
        drawBall(dc);
        drawAimArrow(dc);
        drawHUD(dc);
        if (_gs == MG_POWER) { drawPowerBar(dc); }
        if (_gs == MG_HOLED) { drawHoledOverlay(dc); }
    }

    // Fading trail of small dots behind the ball while it rolls — cheap
    // visual polish, purely additive on top of the cached background.
    hidden function drawTrail(dc) {
        for (var i = 0; i < _trailN; i++) {
            var tsx = cToS_X(_trailX[i] / 10); var tsy = cToS_Y(_trailY[i] / 10);
            var age = i.toFloat() / MG_TRAIL_LEN.toFloat();
            var shade = (0xFF - (age * 0xB0).toNumber());
            var col = (shade << 16) | (shade << 8) | shade;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var r = 2 - (i / 4);
            if (r < 1) { r = 1; }
            dc.fillCircle(tsx, tsy, r);
        }
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
        dc.drawText(_w/2, _h * 15 / 100, Graphics.FONT_MEDIUM, "MINIGOLF", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 28 / 100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        var L = menuLayout();

        // Difficulty selector row
        var diffSel = (_menuRow == MG_ROW_DIFF);
        var diffLabels = ["Easy +3 balls", "Normal +2 balls", "Hard +1 ball"];
        dc.setColor(0xCCEEBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, L[MG_ROW_DIFF][1] - _h * 7 / 100, Graphics.FONT_XTINY,
            "Difficulty:", Graphics.TEXT_JUSTIFY_CENTER);
        var d = L[MG_ROW_DIFF];
        dc.setColor(diffSel ? 0x256838 : 0x1A5028, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(d[0], d[1], d[2], d[3], 6);
        dc.setColor(diffSel ? 0x55CC77 : 0x2A7040, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(d[0], d[1], d[2], d[3], 6);
        dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, d[1] + (d[3] - 14) / 2, Graphics.FONT_XTINY,
            diffLabels[_difficulty], Graphics.TEXT_JUSTIFY_CENTER);

        // PLAY action row
        var playSel = (_menuRow == MG_ROW_PLAY);
        var p = L[MG_ROW_PLAY];
        dc.setColor(playSel ? 0x2E7000 : 0x225500, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(p[0], p[1], p[2], p[3], 8);
        dc.setColor(playSel ? 0x66DD33 : 0x44AA22, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(p[0], p[1], p[2], p[3], 8);
        dc.setColor((_tick % 10 < 5) ? 0x88FF44 : 0x55CC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, p[1] + (p[3] - 14) / 2, Graphics.FONT_XTINY,
            playSel ? "> PLAY <" : "PLAY", Graphics.TEXT_JUSTIFY_CENTER);

        // LEADERBOARD row (shared gold badge)
        var lb = L[MG_ROW_LB];
        LbBadge.drawRow(dc, lb[0], lb[1], lb[2], lb[3], _menuRow == MG_ROW_LB);
    }

    // ── Course ────────────────────────────────────────────────────────────────
    // Renders every course element that never changes frame-to-frame for a
    // given hole (fairway, border, water, sand, boost pads, walls, tee, cup).
    // Obstacles are drawn separately (see drawObstacles) since a couple of
    // holes animate them every tick — everything here is safe to cache into
    // a bitmap and blit instead of redrawn from scratch every frame.
    hidden function drawCourseStatic(dc) {
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

        // Sand traps — khaki fill with speckled texture dots
        for (var i = 0; i < _sand.size(); i++) {
            var sd = _sand[i];
            var ssx = cToS_X(sd[0]); var ssy = cToS_Y(sd[1]);
            var ssr = cToS_R(sd[2]);
            dc.setColor(0xC7A85A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ssx, ssy, ssr);
            dc.setColor(0x9A8040, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(ssx, ssy, ssr);
            dc.setColor(0xAA8F48, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 7; sp++) {
                var pa = (sp * 51 + i * 23) * Math.PI / 180;
                var pr = ssr * (0.3 + (sp % 3).toFloat() * 0.2);
                dc.fillCircle(ssx + (Math.cos(pa) * pr).toNumber(),
                              ssy + (Math.sin(pa) * pr).toNumber(), 1);
            }
        }

        // Boost pads — glowing pad with a chevron arrow pointing in its
        // push direction, plus a second faint chevron behind it for motion feel.
        for (var i = 0; i < _boost.size(); i++) {
            var bp = _boost[i];
            var bsx = cToS_X(bp[0]); var bsy = cToS_Y(bp[1]);
            var bsr = cToS_R(bp[2]);
            dc.setColor(0x113344, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bsx, bsy, bsr);
            dc.setColor(0x2288CC, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(bsx, bsy, bsr);
            var brad = bp[3] * Math.PI / 180;
            var fx = Math.cos(brad); var fy = Math.sin(brad);
            var px = -fy; var py = fx;   // perpendicular unit vector
            for (var ch = 0; ch < 2; ch++) {
                var tipOff = (bsr.toFloat() * (0.55 - ch.toFloat() * 0.4));
                var backOff = (bsr.toFloat() * (0.05 - ch.toFloat() * 0.4));
                var tipX = bsx + (fx * tipOff).toNumber();
                var tipY = bsy + (fy * tipOff).toNumber();
                var wingX = bsx + (fx * backOff).toNumber();
                var wingY = bsy + (fy * backOff).toNumber();
                var spread = bsr.toFloat() * 0.4;
                dc.setColor(ch == 0 ? 0x88FFFF : 0x2288AA, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([
                    [tipX, tipY],
                    [wingX + (px * spread).toNumber(), wingY + (py * spread).toNumber()],
                    [wingX - (px * spread).toNumber(), wingY - (py * spread).toNumber()]
                ]);
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

    // Obstacles are drawn live every frame (not cached) since a couple of
    // holes rebuild them each tick via updateAnimated() (windmill/pendulum).
    // Roughly-square obstacles render as round bumper pegs (with inner
    // highlight) for that pinball look; rectangular ones stay as wooden planks.
    hidden function drawObstacles(dc) {
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
    }

    // Blit the cached static course bitmap, rebuilding it only when the hole
    // or screen dimensions change — cuts the per-frame draw-call count
    // (walls, water, sand, boost, tee, cup) down to a single drawBitmap on
    // every tick where nothing about the course itself has changed.
    hidden function _drawCourseCached(dc, ox, oy) {
        var sizeChanged = (_courseBmp == null || _courseBmpW != _w || _courseBmpH != _h);
        var needRepaint = sizeChanged || (_courseBmpHole != _holeIdx);

        if (needRepaint) {
            if (sizeChanged) {
                _courseBmp = null;
                try {
                    var ref = Graphics.createBufferedBitmap({ :width => _w, :height => _h });
                    _courseBmp = (ref has :get) ? ref.get() : ref;
                } catch (e) {
                    _courseBmp = null;
                }
                _courseBmpW = _w; _courseBmpH = _h;
            }
            if (_courseBmp != null) {
                drawCourseStatic(_courseBmp.getDc());
                _courseBmpHole = _holeIdx;
            }
        }

        if (_courseBmp != null) {
            // Shake is applied purely as a blit-position shift so the cached
            // bitmap itself never needs to be redrawn just to wobble it.
            dc.drawBitmap(ox, oy, _courseBmp);
        } else {
            // BufferedBitmap unavailable on this CIQ version/device — fall
            // back to drawing straight to the screen every frame (no shake).
            drawCourseStatic(dc);
        }
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
    // Top band, two rows:
    //   row 1: Hole x/20 (left) · lives ♥ (centre) · balls used/allowed (right)
    //   row 2: Par n (left) · Score (right)
    hidden function drawHUD(dc) {
        var hole = _holeIdx + 1;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _vpY);

        // Row 1 — hole / lives / balls
        dc.setColor(0x88CCAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 2, Graphics.FONT_XTINY, "H" + hole + "/" + MG_HOLES, Graphics.TEXT_JUSTIFY_LEFT);

        drawLives(dc, _w / 2, 9);

        // Balls left this hole; turns amber then red as the player nears the cap.
        var left = _ballsThisHole - _strokes;
        if (left < 0) { left = 0; }
        var ballClr = 0x66DD66;
        if (left <= 0)      { ballClr = 0xFF4444; }
        else if (left == 1) { ballClr = 0xFFAA33; }
        dc.setColor(ballClr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 4, 2, Graphics.FONT_XTINY,
            "B " + _strokes + "/" + _ballsThisHole, Graphics.TEXT_JUSTIFY_RIGHT);

        // Row 2 — par / score
        var row2 = 2 + _vpY * 42 / 100;
        if (row2 < 18) { row2 = 18; }
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, row2, Graphics.FONT_XTINY, "Par " + _par[_holeIdx], Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x99DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w - 4, row2, Graphics.FONT_XTINY, "" + _score + " pts", Graphics.TEXT_JUSTIFY_RIGHT);

        // Aim hint bottom
        if (_gs == MG_AIM) {
            dc.setColor(0x44AA66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _h - _h * 10 / 100, Graphics.FONT_XTINY, "Tap=aim  O/ball=shoot", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Draw the remaining lives as small filled hearts (●), centred on cx.
    hidden function drawLives(dc, cx, cy) {
        var n = MG_START_LIVES;
        var r = 4;
        var gap = 4;
        var totalW = n * (r * 2) + (n - 1) * gap;
        var x = cx - totalW / 2 + r;
        for (var i = 0; i < n; i++) {
            if (i < _lives) { dc.setColor(0xFF4466, Graphics.COLOR_TRANSPARENT); }
            else            { dc.setColor(0x553333, Graphics.COLOR_TRANSPARENT); }
            dc.fillCircle(x, cy, r);
            x += r * 2 + gap;
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

        // Failed hole (out of balls) vs successful sink get different headers.
        var failed = (_scoreCard[_holeIdx] == -2);
        if (failed) {
            dc.setColor(0xFF5544, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, oy + oh * 4 / 100, Graphics.FONT_MEDIUM, "MISSED!", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, oy + oh * 4 / 100, Graphics.FONT_MEDIUM, "HOLED!", Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, oy + oh * 36 / 100, Graphics.FONT_XTINY,
            failed ? ("Out of balls  -1 life") : _holeMsg, Graphics.TEXT_JUSTIFY_CENTER);
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

        if (_outOfLives) {
            dc.setColor(0xFF5544, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _h * 6 / 100, Graphics.FONT_MEDIUM, "OUT OF LIVES", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _h * 6 / 100, Graphics.FONT_MEDIUM, "COURSE DONE!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Headline = the leaderboard score.
        dc.setColor(0x99DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 17 / 100, Graphics.FONT_SMALL,
            _score + " pts", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCEEBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 25 / 100, Graphics.FONT_XTINY,
            _holesSunk + "/" + MG_HOLES + " holed · " + _diffVariant(),
            Graphics.TEXT_JUSTIFY_CENTER);

        if (_flawless || _aceCount > 0) {
            var badge = "";
            if (_flawless) { badge = "FLAWLESS ROUND! "; }
            if (_aceCount > 0) { badge = badge + "Aces: " + _aceCount; }
            dc.setColor((_tick % 10 < 5) ? 0xFFDD44 : 0xFF8822, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w/2, _h * 31 / 100, Graphics.FONT_XTINY, badge, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Two columns × 10 rows
        var topY  = _h * 37 / 100;
        var botY  = _h * 82 / 100;
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
            var label = "-";
            if (sc >= 0) {
                if (pd < 0)        { clr = 0x44FF88; }
                else if (pd == 0)  { clr = 0xFFFFFF; }
                else if (pd == 1)  { clr = 0xFFAA44; }
                else               { clr = 0xFF5544; }
                label = sc.toString();
            } else if (sc == -2) {
                clr = 0xFF5544;   // DNF — out of balls
                label = "X";
            }
            dc.setColor(clr, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rx, ry, Graphics.FONT_XTINY,
                "H" + (i + 1) + " " + label, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0x44FF88 : 0x226633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w/2, _h * 92 / 100, Graphics.FONT_XTINY, "Tap for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
