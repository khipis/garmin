// ═══════════════════════════════════════════════════════════════
// BilliardGame.mc  —  PhysicsEngine + AIController + GameController
// ═══════════════════════════════════════════════════════════════
using Toybox.Math;
using Toybox.Application;

// ── Game states ──────────────────────────────────────────────
const BS_MENU     = 0;
const BS_AIM      = 1;   // player rotating aim arrow
const BS_POWER    = 2;   // power bar oscillating
const BS_ROLLING  = 3;   // balls in motion
const BS_AI_WAIT  = 4;   // AI "thinking" pause before shot
const BS_GAMEOVER = 5;

const TURN_PLAYER = 0;
const TURN_AI     = 1;

const DIFF_EASY = 0;
const DIFF_MED  = 1;
const DIFF_HARD = 2;

// ── Physics constants ────────────────────────────────────────
const MAX_BALLS = 10;    // 1 cue + 9 target (diamond 9-ball rack + black)
const BALL_R    = 26;    // ball radius in course units
const BALL_D    = 52;    // 2*BALL_R — collision diameter
const POCKET_R  = 42;    // pocket capture radius
const NUM_POCKETS = 6;

// ── Table geometry (course space 0-1000 × 0-700) ────────────
// Visual table boundary:
const TL = 28;  const TR = 972;  const TT = 90;  const TB = 610;
// Wall edge (ball centre must stay within):
const WL = TL + BALL_R;  // 54
const WR = TR - BALL_R;  // 946
const WT = TT + BALL_R;  // 116
const WB = TB - BALL_R;  // 584

// ─────────────────────────────────────────────────────────────
// BilliardGame  —  pure game-logic class, no UI dependencies
// ─────────────────────────────────────────────────────────────
class BilliardGame {

    // ── State ─────────────────────────────────────────────────
    var gs;    // game state (BS_*)
    var diff;  // difficulty (DIFF_*)
    var turn;  // TURN_PLAYER or TURN_AI

    // ── Ball arrays (Float) ───────────────────────────────────
    var bx; var by;    // position
    var bvx; var bvy;  // velocity (course units / tick)
    var bAlive;        // Boolean — false when pocketed
    var bCol;          // display colours

    // ── Pockets ───────────────────────────────────────────────
    var pX; var pY;

    // ── Aiming & power ───────────────────────────────────────
    var aimAngle;   // Float degrees 0-359
    var power;      // Integer 0-100 (oscillates in BS_POWER)
    var powerDir;   // +1 / -1

    // ── Score ─────────────────────────────────────────────────
    var playerScore; var aiScore;

    // ── AI ────────────────────────────────────────────────────
    var aiDelay;     // ticks before AI executes its shot
    var aiAimAngle;  // pre-computed aim for the AI shot
    var aiPower;     // pre-computed power

    // ── Notifications ─────────────────────────────────────────
    var msg; var msgT;

    // ── Extra-turn flag ───────────────────────────────────────
    var pocketedThisTurn;

    // ── Viewport params (set by view after layout) ────────────
    var sw; var sh;
    var vpX; var vpY; var vpW; var vpH;
    var vpScale; var vpOffX; var vpOffY;

    // ── Aim-intersect cache (updated on each angle change) ────
    var aimHitT;    // float distance along ray to contact (-1 = none)
    var aimHitBall; // index of ball hit (-1 = none)

    // ─────────────────────────────────────────────────────────
    function initialize() {
        gs = BS_MENU; diff = DIFF_MED; turn = TURN_PLAYER;
        aimAngle = 0.0; power = 50; powerDir = 1;
        playerScore = 0; aiScore = 0;
        aiDelay = 0; aiAimAngle = 0.0; aiPower = 50;
        msg = ""; msgT = 0; pocketedThisTurn = false;
        sw = 260; sh = 260; aimHitT = -1.0; aimHitBall = -1;

        // Ball colours: white (cue), 8 colours, black (ball 9 = the key ball)
        bCol = [0xFFFFFF, 0xFFDD00, 0x2255DD, 0xDD2222,
                0x882299, 0xFF7700, 0x228833, 0xAA2200,
                0x44AACC, 0x111111];

        bx = new [MAX_BALLS]; by = new [MAX_BALLS];
        bvx = new [MAX_BALLS]; bvy = new [MAX_BALLS];
        bAlive = new [MAX_BALLS];
        for (var i = 0; i < MAX_BALLS; i++) {
            bx[i] = 0.0; by[i] = 0.0;
            bvx[i] = 0.0; bvy[i] = 0.0;
            bAlive[i] = false;
        }

        // Pockets: top-left, top-mid, top-right, bot-left, bot-mid, bot-right
        pX = [TL, 500, TR, TL, 500, TR];
        pY = [TT, TT,  TT, TB, TB,  TB];

        var sd = Application.Storage.getValue("billDiff");
        if (sd != null) { diff = sd; }

        _setupVP(260, 260);
    }

    // ── Viewport setup ────────────────────────────────────────
    function setScreenSize(w, h) {
        sw = w; sh = h;
        _setupVP(w, h);
    }

    hidden function _setupVP(w, h) {
        var hudH = h * 18 / 100; if (hudH < 18) { hudH = 18; }
        var botH = h * 9  / 100; if (botH < 9)  { botH = 9; }
        vpX = 4; vpY = hudH;
        vpW = w - 8; vpH = h - hudH - botH;
        // Fit 1000×700 course uniformly into vpW×vpH
        var sW = vpW;
        var sH = vpH * 1000 / 700;
        vpScale = sW < sH ? sW : sH;
        vpOffX = (vpW - vpScale) / 2;
        vpOffY = (vpH - vpScale * 700 / 1000) / 2;
    }

    // ── Coordinate helpers (course → screen, integer result) ──
    function csx(cx) { return vpX + vpOffX + cx * vpScale / 1000; }
    function csy(cy) { return vpY + vpOffY + cy * vpScale / 1000; }
    function csr(cr) { return cr * vpScale / 1000; }

    // ── Game control ──────────────────────────────────────────
    function startGame() {
        // Cue ball — left side (baulk area)
        bx[0] = 230.0; by[0] = 350.0;
        bvx[0] = 0.0;  bvy[0] = 0.0;  bAlive[0] = true;

        // Diamond rack — 9 target balls (standard 9-ball layout)
        // Horizontal pitch ≈ 45 course units, vertical pitch = 52 (BALL_D)
        // Black ball (index 9, bCol[9]=0x111111) is placed at the diamond centre
        // Col 1 (apex):
        bx[1] = 680.0; by[1] = 350.0;
        // Col 2:
        bx[2] = 725.0; by[2] = 324.0;
        bx[3] = 725.0; by[3] = 376.0;
        // Col 3 (centre row): ball 9 (BLACK) is in the exact middle
        bx[4] = 770.0; by[4] = 298.0;
        bx[9] = 770.0; by[9] = 350.0;  // BLACK ball at diamond centre
        bx[6] = 770.0; by[6] = 402.0;
        // Col 4:
        bx[7] = 815.0; by[7] = 324.0;
        bx[8] = 815.0; by[8] = 376.0;
        // Col 5 (back):
        bx[5] = 860.0; by[5] = 350.0;

        for (var i = 1; i < MAX_BALLS; i++) { bvx[i] = 0.0; bvy[i] = 0.0; bAlive[i] = true; }

        playerScore = 0; aiScore = 0;
        turn = TURN_PLAYER; pocketedThisTurn = false;
        aimAngle = 0.0; power = 50; powerDir = 1;
        msg = ""; msgT = 0; aiDelay = 0;
        gs = BS_AIM;
        _computeAimIntersect();
    }

    // ── Input handlers ────────────────────────────────────────
    function doUp() {
        if (gs == BS_MENU)  { diff = (diff + 2) % 3; Application.Storage.setValue("billDiff", diff); return; }
        if (gs == BS_GAMEOVER) { gs = BS_MENU; return; }
        if (gs == BS_AIM && turn == TURN_PLAYER) {
            // float % not supported in Monkey C — use explicit wrap
            aimAngle -= 10.0;
            if (aimAngle < 0.0) { aimAngle += 360.0; }
            _computeAimIntersect();
        }
        if (gs == BS_POWER) { _commitShot(); }
    }

    function doDown() {
        if (gs == BS_MENU)  { diff = (diff + 1) % 3; Application.Storage.setValue("billDiff", diff); return; }
        if (gs == BS_GAMEOVER) { gs = BS_MENU; return; }
        if (gs == BS_AIM && turn == TURN_PLAYER) {
            aimAngle += 10.0;
            if (aimAngle >= 360.0) { aimAngle -= 360.0; }
            _computeAimIntersect();
        }
        if (gs == BS_POWER) { _commitShot(); }
    }

    function doSelect() {
        if (gs == BS_MENU)    { startGame(); return; }
        if (gs == BS_GAMEOVER){ gs = BS_MENU; return; }
        if (gs == BS_AIM  && turn == TURN_PLAYER) { gs = BS_POWER; power = 0; powerDir = 1; return; }
        if (gs == BS_POWER)   { _commitShot(); return; }
    }

    function doBack() {
        if (gs != BS_MENU) { gs = BS_MENU; return true; }
        return false;
    }

    function doTap(tx, ty) {
        if (gs == BS_MENU)     { startGame(); return; }
        if (gs == BS_GAMEOVER) { gs = BS_MENU; return; }
        if (gs == BS_POWER)    { _commitShot(); return; }
        if (gs != BS_AIM || turn != TURN_PLAYER) { return; }

        // Tap away from cue ball → set aim direction (touch-to-aim)
        var csx0 = csx(bx[0]); var csy0 = csy(by[0]);
        var ddx = tx - csx0; var ddy = ty - csy0;
        var dist2 = ddx * ddx + ddy * ddy;
        if (dist2 < 36) { return; } // ignore taps right on ball

        var a = Math.atan2(ddy.toFloat(), ddx.toFloat()) * 180.0 / Math.PI;
        if (a < 0.0) { a += 360.0; }
        aimAngle = a;
        _computeAimIntersect();

        // Tap far from ball → just set aim; tap near (within ~40px) → start power
        if (dist2 > 1600) { return; }
        gs = BS_POWER; power = 0; powerDir = 1;
    }

    // ── Game tick ─────────────────────────────────────────────
    function step() {
        if (gs == BS_POWER) {
            power += powerDir * 4;
            if (power >= 100) { power = 100; powerDir = -1; }
            if (power <= 0)   { power = 0;   powerDir =  1; }
        }
        if (msgT > 0) { msgT--; }
        if (gs == BS_ROLLING) { _stepPhysics(); }
        if (gs == BS_AI_WAIT) {
            aiDelay--;
            if (aiDelay <= 0) { _executeAiShot(); }
        }
    }

    // ── PhysicsEngine ────────────────────────────────────────
    hidden function _stepPhysics() {
        // Two substeps per tick to avoid tunneling at high speeds
        for (var s = 0; s < 2; s++) {
            for (var i = 0; i < MAX_BALLS; i++) {
                if (!bAlive[i]) { continue; }
                bx[i] += bvx[i] * 0.5;
                by[i] += bvy[i] * 0.5;
                // Elastic wall bounce with ~15% energy loss
                if (bx[i] < WL.toFloat()) {
                    bx[i] = WL.toFloat();
                    if (bvx[i] < 0.0) { bvx[i] = -bvx[i] * 0.85; }
                }
                if (bx[i] > WR.toFloat()) {
                    bx[i] = WR.toFloat();
                    if (bvx[i] > 0.0) { bvx[i] = -bvx[i] * 0.85; }
                }
                if (by[i] < WT.toFloat()) {
                    by[i] = WT.toFloat();
                    if (bvy[i] < 0.0) { bvy[i] = -bvy[i] * 0.85; }
                }
                if (by[i] > WB.toFloat()) {
                    by[i] = WB.toFloat();
                    if (bvy[i] > 0.0) { bvy[i] = -bvy[i] * 0.85; }
                }
            }
            _resolveBallCollisions();
        }
        // Rolling friction (once per full tick)
        for (var i = 0; i < MAX_BALLS; i++) {
            if (!bAlive[i]) { continue; }
            bvx[i] *= 0.972;
            bvy[i] *= 0.972;
        }
        _checkPockets();

        // Stop when all balls slow enough
        var allStopped = true;
        for (var i = 0; i < MAX_BALLS; i++) {
            if (!bAlive[i]) { continue; }
            if (bvx[i]*bvx[i] + bvy[i]*bvy[i] > 0.09) { allStopped = false; break; }
        }
        if (allStopped) {
            for (var i = 0; i < MAX_BALLS; i++) { bvx[i] = 0.0; bvy[i] = 0.0; }
            _onRollingComplete();
        }
    }

    // Ball-ball elastic collision (equal mass)
    hidden function _resolveBallCollisions() {
        for (var i = 0; i < MAX_BALLS - 1; i++) {
            if (!bAlive[i]) { continue; }
            for (var j = i + 1; j < MAX_BALLS; j++) {
                if (!bAlive[j]) { continue; }
                var dx = bx[j] - bx[i]; var dy = by[j] - by[i];
                var dist2 = dx*dx + dy*dy;
                if (dist2 >= BALL_D * BALL_D || dist2 < 0.01) { continue; }
                var dist = Math.sqrt(dist2);
                var nx = dx / dist; var ny = dy / dist;
                // Exchange velocity component along normal (elastic, equal mass)
                var dvx = bvx[j] - bvx[i]; var dvy = bvy[j] - bvy[i];
                var dvn = dvx * nx + dvy * ny;
                if (dvn < 0.0) {  // approaching
                    // 97% restitution (tiny energy loss per collision)
                    bvx[i] += dvn * nx * 0.97; bvy[i] += dvn * ny * 0.97;
                    bvx[j] -= dvn * nx * 0.97; bvy[j] -= dvn * ny * 0.97;
                }
                // Separate overlapping balls
                var overlap = (BALL_D.toFloat() - dist) * 0.52;
                bx[i] -= nx * overlap; by[i] -= ny * overlap;
                bx[j] += nx * overlap; by[j] += ny * overlap;
            }
        }
    }

    hidden function _checkPockets() {
        for (var i = 0; i < MAX_BALLS; i++) {
            if (!bAlive[i]) { continue; }
            for (var p = 0; p < NUM_POCKETS; p++) {
                var pdx = bx[i] - pX[p]; var pdy = by[i] - pY[p];
                if (pdx*pdx + pdy*pdy < POCKET_R.toFloat() * POCKET_R.toFloat()) {
                    _pocketBall(i); break;
                }
            }
        }
    }

    hidden function _pocketBall(i) {
        bAlive[i] = false; bvx[i] = 0.0; bvy[i] = 0.0;

        if (i == 0) {
            // Cue ball scratch — penalty + respawn behind baulk line
            msg = "Scratch! Penalty"; msgT = 55;
            if (turn == TURN_PLAYER) { if (playerScore > 0) { playerScore--; } }
            else                     { if (aiScore > 0)     { aiScore--;     } }
            bx[0] = 230.0; by[0] = 350.0; bAlive[0] = true;
            pocketedThisTurn = false; // scratch forfeits extra turn
        } else {
            if (turn == TURN_PLAYER) { playerScore++; msg = "You scored!"; }
            else                     { aiScore++;      msg = "AI scored!"; }
            msgT = 45;
            pocketedThisTurn = true;
        }

        // Game over when all target balls pocketed
        var allGone = true;
        for (var b = 1; b < MAX_BALLS; b++) {
            if (bAlive[b]) { allGone = false; break; }
        }
        if (allGone) { gs = BS_GAMEOVER; }
    }

    hidden function _onRollingComplete() {
        if (gs == BS_GAMEOVER) { return; }
        if (!pocketedThisTurn) {
            turn = (turn == TURN_PLAYER) ? TURN_AI : TURN_PLAYER;
        }
        pocketedThisTurn = false;

        if (turn == TURN_PLAYER) {
            gs = BS_AIM;
            _computeAimIntersect();
        } else {
            _aiThink();
            gs = BS_AI_WAIT;
        }
    }

    // ── Shot mechanics ────────────────────────────────────────
    hidden function _commitShot() {
        var rad = aimAngle * Math.PI / 180.0;
        var spd = power.toFloat() * 0.23 + 2.5;
        bvx[0] = Math.cos(rad) * spd;
        bvy[0] = Math.sin(rad) * spd;
        pocketedThisTurn = false;
        gs = BS_ROLLING;
    }

    // ── AIController ─────────────────────────────────────────
    // Finds nearest surviving target ball from the cue ball
    hidden function _nearestTargetBall() {
        var nearB = -1; var nearD2 = 9999999.0;
        for (var b = 1; b < MAX_BALLS; b++) {
            if (!bAlive[b]) { continue; }
            var dx = bx[b] - bx[0]; var dy = by[b] - by[0];
            var d2 = dx*dx + dy*dy;
            if (d2 < nearD2) { nearD2 = d2; nearB = b; }
        }
        return nearB;
    }

    hidden function _aiThink() {
        var target = _nearestTargetBall();
        if (target < 0) { aiDelay = 5; aiAimAngle = 0.0; aiPower = 50; return; }

        var ang = 0.0; var pwr = 60;

        if (diff == DIFF_EASY) {
            // Randomised direction around cue-to-ball (±60° error), random power
            var baseDx = bx[target] - bx[0]; var baseDy = by[target] - by[0];
            ang = Math.atan2(baseDy, baseDx) * 180.0 / Math.PI;
            ang += (Math.rand().abs() % 121 - 60).toFloat(); // ±60°
            pwr = 25 + Math.rand().abs() % 40;

        } else if (diff == DIFF_MED) {
            // Aim toward nearest ball with ±20° error
            var baseDx2 = bx[target] - bx[0]; var baseDy2 = by[target] - by[0];
            ang = Math.atan2(baseDy2, baseDx2) * 180.0 / Math.PI;
            ang += (Math.rand().abs() % 41 - 20).toFloat(); // ±20°
            pwr = 48 + Math.rand().abs() % 28;

        } else {
            // Hard: ghost-ball method — pocket the best target ball
            ang = _aiHardAngle(target);
            pwr = 58 + Math.rand().abs() % 22;
        }

        if (ang < 0.0)    { ang += 360.0; }
        if (ang >= 360.0) { ang -= 360.0; }
        aiAimAngle = ang; aiPower = pwr;
        // "Thinking" delay: 0.9–1.5 s
        aiDelay = 28 + Math.rand().abs() % 18;
    }

    // Ghost-ball method: find angle to send target ball into best pocket
    hidden function _aiHardAngle(targetBall) {
        var bestAng  = 0.0; var bestScore = -1.0; var found = false;
        for (var p = 0; p < NUM_POCKETS; p++) {
            var pdx = pX[p].toFloat() - bx[targetBall];
            var pdy = pY[p].toFloat() - by[targetBall];
            var pdist = Math.sqrt(pdx*pdx + pdy*pdy);
            if (pdist < 1.0) { continue; }
            var pnx = pdx / pdist; var pny = pdy / pdist;
            // Ghost-ball position: where cue ball must be to drive target → pocket
            var gx = bx[targetBall] - pnx * BALL_D.toFloat();
            var gy = by[targetBall] - pny * BALL_D.toFloat();
            // Reject ghost balls outside playable area
            if (gx < WL || gx > WR || gy < WT || gy > WB) { continue; }
            // Angle from cue ball to ghost ball
            var gdx = gx - bx[0]; var gdy = gy - by[0];
            var gdist2 = gdx*gdx + gdy*gdy;
            if (gdist2 < 1.0) { continue; }
            // Prefer shorter cue-to-ghost distance + shorter ball-to-pocket
            var score = 500.0 / (gdist2 + 100.0) + 200.0 / (pdist + 10.0);
            if (score > bestScore) {
                bestScore = score;
                bestAng = Math.atan2(gdy, gdx) * 180.0 / Math.PI;
                found = true;
            }
        }
        if (!found) {
            var dx = bx[targetBall] - bx[0]; var dy = by[targetBall] - by[0];
            bestAng = Math.atan2(dy, dx) * 180.0 / Math.PI;
        }
        bestAng += (Math.rand().abs() % 9 - 4).toFloat(); // ±4° residual error
        return bestAng;
    }

    hidden function _executeAiShot() {
        aimAngle = aiAimAngle; power = aiPower;
        _commitShot();
    }

    // ── Aim-intersect cache ───────────────────────────────────
    // Computes the first target ball hit along the aim ray and caches
    // t (distance) and ball index so the view can draw the aim preview.
    function _computeAimIntersect() {
        var rad = aimAngle * Math.PI / 180.0;
        var dx = Math.cos(rad); var dy = Math.sin(rad);
        aimHitT = -1.0; aimHitBall = -1;
        var minT = 9999.0;
        for (var b = 1; b < MAX_BALLS; b++) {
            if (!bAlive[b]) { continue; }
            var ox = bx[b] - bx[0]; var oy = by[b] - by[0];
            var proj = ox * dx + oy * dy;
            if (proj < BALL_R.toFloat()) { continue; } // behind cue ball
            var perp2 = ox*ox + oy*oy - proj*proj;
            var bd2   = BALL_D.toFloat() * BALL_D.toFloat();
            if (perp2 >= bd2) { continue; } // misses
            var t = proj - Math.sqrt(bd2 - perp2);
            if (t > 0.0 && t < minT) { minT = t; aimHitBall = b; }
        }
        if (aimHitBall >= 0) { aimHitT = minT; }
    }
}
