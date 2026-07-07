// ═══════════════════════════════════════════════════════════════
// BilliardGame.mc  —  PhysicsEngine + AIController + GameController
// ═══════════════════════════════════════════════════════════════
using Toybox.Math;
using Toybox.Application;
using Toybox.Lang;

// ── Leaderboard (win-streak vs AI; variant = game type) ──────
const LB_GAME_ID    = "billiards";
const LB_STREAK_KEY = "billiards_streak";

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

// ── Game types ───────────────────────────────────────────────
// Different popular pool games — each uses a different ball count and rack.
const GT_3BALL     = 0;  // 1 cue + 3 colored balls, mini-triangle (quickest)
const GT_9BALL     = 1;  // 1 cue + 9 numbered (diamond rack; 9-ball = black key)
const GT_8BALL     = 2;  // 1 cue + 15 numbered (triangle rack; 8-ball = black key)
const GT_SNOOKER   = 3;  // 1 cue + 6 reds + 1 black — must-hit-red + point scoring
// TIME ATTACK — solo arcade mode: full 15-ball rack, no opponent/turns,
// pot as many balls as possible before the clock runs out. The DIFF
// selector doubles as the time-limit selector in this mode (see
// _timeAttackLimit()). Its own leaderboard variant ("timeattack") is a
// pure high-score board, not a win-streak, so it fits the existing
// per-game-type leaderboard split perfectly.
const GT_TIMEATTACK = 4;
const GT_COUNT     = 5;

// ── Physics constants ────────────────────────────────────────
const MAX_BALLS = 16;    // upper bound — 8-ball uses all 16 (cue + 15)
const BALL_R    = 26;    // ball radius in course units
const BALL_D    = 52;    // 2*BALL_R — collision diameter
// Pocket capture: trimmed once more for an even tighter, more
// realistic pocket footprint (diameter ≈ 1.42× ball diameter).
// The "rail-open" radius around each pocket is slightly larger so
// a ball approaching the corner can roll past the cushion line
// into the capture zone instead of being deflected by it. Capture
// margin (POCKET_R − BALL_R = 11) is still ~42 % of the ball
// radius — comfortable forgiveness on off-centre approaches
// without looking cartoonish.
const POCKET_R       = 37;
const POCKET_OPEN_R  = 49;
const NUM_POCKETS = 6;

// Cushion-impact flash — small ring-fx queue the View draws at rail
// bounce points, purely cosmetic (juice) but capped tiny so it's cheap.
const BOUNCE_FX_MAX = 6;
const BOUNCE_FX_LIFE = 10;

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
    var gs;       // game state (BS_*)
    var diff;     // difficulty (DIFF_*)
    var turn;     // TURN_PLAYER or TURN_AI
    var gameType; // GT_3BALL / GT_9BALL / GT_8BALL / GT_SNOOKER
    var numBalls; // active ball count for current mode (4, 8, 10, or 16)
    var menuSel;  // menu cursor: 0=mode, 1=vs, 2=difficulty, 3=leaderboard, 4=START
    var pvpMode;  // false = P vs AI, true = P vs P (Player 2 uses same controls)
    var lbRequested;  // set true when the menu LEADERBOARD row is activated (View opens it)
    hidden var _lbHandled;  // guard so a finished game submits its result only once

    // ── Per-shot tracking (rules engine) ─────────────────────
    var firstHit;          // index of first non-cue ball cue contacted; -1 = miss
    var cueScratched;      // cue ball was pocketed this shot
    var pottedList;        // int[16] — indices of balls pocketed this shot
    var pottedCnt;         // count of entries in pottedList
    var lowestPreShot;     // lowest live numbered ball at start of shot (9-ball)

    // ── 8-ball group assignment ──────────────────────────────
    // 0 = unassigned, 1 = SOLID (balls 1-7), 2 = STRIPE (balls 9-15)
    // playerGroup[0] = player; playerGroup[1] = AI
    var playerGroup;       // int[2]

    // Game result reason — used for game-over screen text.
    // 0 = none, 1 = player win, 2 = AI win, 3 = player lost (potted 8 illegally),
    // 4 = AI lost (potted 8 illegally)
    var winReason;

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
    // Progressive aim controls: each consecutive aim press in the same
    // direction (within _AIM_RPT_IDLE_MAX ticks) accelerates the step.
    // Lone presses or direction changes go back to the finest 1° step.
    hidden var _aimRptDir;     // -1 / 0 / +1
    hidden var _aimRptStreak;  // consecutive same-direction presses
    hidden var _aimRptIdle;    // ticks since last aim press

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

    // ── Cushion-impact flash queue (cosmetic; View renders these) ────
    var bounceFxX; var bounceFxY; var bounceFxLife;   // parallel arrays
    hidden var _bounceFxNext;

    // ── TIME ATTACK arcade mode ───────────────────────────────
    var arcadeTicks;  // countdown, in ~33 ms ticks, while gameType == GT_TIMEATTACK

    // ─────────────────────────────────────────────────────────
    function initialize() {
        gs = BS_MENU; diff = DIFF_MED; turn = TURN_PLAYER;
        gameType = GT_9BALL; numBalls = 10; menuSel = 0; pvpMode = false;
        lbRequested = false; _lbHandled = false;
        aimAngle = 0.0; power = 50; powerDir = 1;
        _aimRptDir = 0; _aimRptStreak = 0; _aimRptIdle = 0;
        playerScore = 0; aiScore = 0;
        aiDelay = 0; aiAimAngle = 0.0; aiPower = 50;
        msg = ""; msgT = 0; pocketedThisTurn = false;
        sw = 260; sh = 260; aimHitT = -1.0; aimHitBall = -1;
        firstHit = -1; cueScratched = false;
        pottedList = new [16]; pottedCnt = 0;
        lowestPreShot = -1;
        playerGroup = [0, 0];
        winReason = 0;

        // Pre-allocate ball arrays sized for the largest mode (8-ball, 16 balls).
        // Unused indices stay bAlive=false and are skipped by physics/AI/render loops.
        bx = new [MAX_BALLS]; by = new [MAX_BALLS];
        bvx = new [MAX_BALLS]; bvy = new [MAX_BALLS];
        bAlive = new [MAX_BALLS];
        bCol   = new [MAX_BALLS];
        for (var i = 0; i < MAX_BALLS; i++) {
            bx[i] = 0.0; by[i] = 0.0;
            bvx[i] = 0.0; bvy[i] = 0.0;
            bAlive[i] = false;
            bCol[i] = 0xFFFFFF;
        }

        // Pockets: top-left, top-mid, top-right, bot-left, bot-mid, bot-right
        pX = [TL, 500, TR, TL, 500, TR];
        pY = [TT, TT,  TT, TB, TB,  TB];

        bounceFxX = new [BOUNCE_FX_MAX]; bounceFxY = new [BOUNCE_FX_MAX];
        bounceFxLife = new [BOUNCE_FX_MAX];
        for (var bf = 0; bf < BOUNCE_FX_MAX; bf++) {
            bounceFxX[bf] = 0.0; bounceFxY[bf] = 0.0; bounceFxLife[bf] = 0;
        }
        _bounceFxNext = 0;
        arcadeTicks = 0;

        var sd = Application.Storage.getValue("billDiff");
        if (sd instanceof Lang.Number && sd >= 0 && sd <= DIFF_HARD) { diff = sd; }
        var sgt = Application.Storage.getValue("billGT");
        if (sgt instanceof Lang.Number && sgt >= 0 && sgt < GT_COUNT) { gameType = sgt; }
        // VS mode now comes from the shared OPTIONS screen (numeric index).
        var svs = Application.Storage.getValue("bill_vs");
        if (svs instanceof Lang.Number) { pvpMode = (svs == 1); }

        _applyGameType();
        _setupVP(260, 260);
    }

    // ── Game-type palette + ball count ───────────────────────
    // Called both on init and at start of every game so that
    // bCol/numBalls always reflect the selected gameType.
    hidden function _applyGameType() {
        if (gameType == GT_3BALL) {
            numBalls = 4;
            bCol[0] = 0xFFFFFF;  // cue
            bCol[1] = 0xFFDD00;  // yellow
            bCol[2] = 0xDD2222;  // red
            bCol[3] = 0x44AACC;  // cyan
        } else if (gameType == GT_8BALL) {
            numBalls = 16;
            bCol[0]  = 0xFFFFFF;  // cue
            // Solids 1..7
            bCol[1]  = 0xFFDD00;  // 1 yellow
            bCol[2]  = 0x2255DD;  // 2 blue
            bCol[3]  = 0xDD2222;  // 3 red
            bCol[4]  = 0x882299;  // 4 purple
            bCol[5]  = 0xFF7700;  // 5 orange
            bCol[6]  = 0x228833;  // 6 green
            bCol[7]  = 0xAA2200;  // 7 maroon
            bCol[8]  = 0x111111;  // 8 BLACK (key ball)
            // Stripes 9..15 — same hues but lighter shades for visual distinction
            bCol[9]  = 0xFFEE66;  // 9 striped yellow
            bCol[10] = 0x55AAFF;  // 10 striped blue
            bCol[11] = 0xFF6677;  // 11 striped red
            bCol[12] = 0xBB66CC;  // 12 striped purple
            bCol[13] = 0xFFAA55;  // 13 striped orange
            bCol[14] = 0x66BB66;  // 14 striped green
            bCol[15] = 0xCC6644;  // 15 striped maroon
        } else if (gameType == GT_TIMEATTACK) {
            // Full 15-ball rack, chaos-rainbow palette (no solids/stripes
            // meaning — every ball is just a target against the clock).
            numBalls = 16;
            bCol[0]  = 0xFFFFFF;
            bCol[1]  = 0xFFDD00; bCol[2]  = 0xFF9900; bCol[3]  = 0xFF4444;
            bCol[4]  = 0xFF44AA; bCol[5]  = 0xCC44FF; bCol[6]  = 0x7755FF;
            bCol[7]  = 0x4488FF; bCol[8]  = 0x44CCFF; bCol[9]  = 0x44FFCC;
            bCol[10] = 0x55FF66; bCol[11] = 0xAAFF33; bCol[12] = 0xEEEE33;
            bCol[13] = 0xFFAA66; bCol[14] = 0xDD8888; bCol[15] = 0xBB88FF;
        } else if (gameType == GT_SNOOKER) {
            // 1 cue + 6 reds (1pt each) + 1 black (7pt key ball) = 8 balls.
            numBalls = 8;
            bCol[0] = 0xFFFFFF;  // cue
            bCol[1] = 0xDD2222;
            bCol[2] = 0xDD2222;
            bCol[3] = 0xDD2222;
            bCol[4] = 0xDD2222;
            bCol[5] = 0xDD2222;
            bCol[6] = 0xDD2222;
            bCol[7] = 0x111111;  // BLACK (key ball — 7 points, wins after reds cleared)
        } else { // GT_9BALL (default)
            numBalls = 10;
            bCol[0] = 0xFFFFFF;
            bCol[1] = 0xFFDD00;
            bCol[2] = 0x2255DD;
            bCol[3] = 0xDD2222;
            bCol[4] = 0x882299;
            bCol[5] = 0xFF7700;
            bCol[6] = 0x228833;
            bCol[7] = 0xAA2200;
            bCol[8] = 0x44AACC;
            bCol[9] = 0x111111;  // 9 = BLACK (key ball)
        }
    }

    // True if the given target ball index is the "key" (black) ball
    // for the current game mode. Used purely for visual emphasis.
    function isKeyBall(idx) {
        if (gameType == GT_9BALL   && idx == 9) { return true; }
        if (gameType == GT_8BALL   && idx == 8) { return true; }
        if (gameType == GT_SNOOKER && idx == 7) { return true; }
        return false;
    }

    // True for stripes group in 8-ball (balls 9..15). Used by renderer to
    // draw a classic white-ball + coloured-equator-band look so the player
    // can instantly tell solids from stripes.
    function isStripe(idx) {
        return (gameType == GT_8BALL && idx >= 9 && idx <= 15);
    }

    // True for solids group in 8-ball (balls 1..7). The cue (0) and the
    // 8-ball (8) are neither solids nor stripes.
    function isSolid(idx) {
        return (gameType == GT_8BALL && idx >= 1 && idx <= 7);
    }

    // Display label for current game mode.
    function gameTypeLabel() {
        if (gameType == GT_3BALL)     { return "3-BALL"; }
        if (gameType == GT_8BALL)     { return "8-BALL"; }
        if (gameType == GT_SNOOKER)   { return "SNOOKER"; }
        if (gameType == GT_TIMEATTACK){ return "TIME ATK"; }
        return "9-BALL";
    }

    // Time-limit table for TIME ATTACK, indexed by the (repurposed) diff
    // selector: EASY = most forgiving = most time.
    function timeAttackLimitSecs() {
        if (diff == DIFF_EASY) { return 90; }
        if (diff == DIFF_HARD) { return 40; }
        return 60;
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
        // Fit 1000×700 course uniformly into vpW×vpH, then scale to 83%
        // of available area (was 80% — +3% per user request).  The
        // table is now also biased toward the TOP of the viewport
        // (offset = 28% of the slack instead of centred 50%), which
        // shifts it noticeably upward on the screen and frees up room
        // for the (newly narrowed) power bar at the bottom on round
        // watch faces.
        var sW = vpW;
        var sH = vpH * 1000 / 700;
        vpScale = (sW < sH ? sW : sH) * 83 / 100;
        vpOffX = (vpW - vpScale) / 2;
        vpOffY = (vpH - vpScale * 700 / 1000) * 28 / 100;
    }

    // ── Coordinate helpers (course → screen, integer result) ──
    function csx(cx) { return vpX + vpOffX + cx * vpScale / 1000; }
    function csy(cy) { return vpY + vpOffY + cy * vpScale / 1000; }
    function csr(cr) { return cr * vpScale / 1000; }

    // ── Game control ──────────────────────────────────────────
    function startGame() {
        _applyGameType();  // sync bCol & numBalls before rack setup

        // Cue ball — left side (baulk area)
        bx[0] = 230.0; by[0] = 350.0;
        bvx[0] = 0.0;  bvy[0] = 0.0;  bAlive[0] = true;

        // Reset all 16 ball slots first (clears any leftovers from prior modes).
        for (var i = 1; i < MAX_BALLS; i++) {
            bx[i] = 0.0; by[i] = 0.0;
            bvx[i] = 0.0; bvy[i] = 0.0;
            bAlive[i] = false;
        }

        if      (gameType == GT_3BALL)     { _setupRack3Ball(); }
        else if (gameType == GT_8BALL)     { _setupRack8Ball(); }
        else if (gameType == GT_TIMEATTACK){ _setupRack8Ball(); }  // reuse the 15-ball triangle geometry
        else if (gameType == GT_SNOOKER)   { _setupRackSnooker(); }
        else                                { _setupRack9Ball(); }

        // Mark all rack balls alive.
        for (var i = 1; i < numBalls; i++) { bAlive[i] = true; }

        playerScore = 0; aiScore = 0;
        turn = TURN_PLAYER; pocketedThisTurn = false;
        aimAngle = 0.0; power = 50; powerDir = 1;
        msg = ""; msgT = 0; aiDelay = 0;
        firstHit = -1; cueScratched = false; pottedCnt = 0;
        playerGroup[0] = 0; playerGroup[1] = 0;
        winReason = 0;
        _lbHandled = false;
        arcadeTicks = timeAttackLimitSecs() * 30;  // ~30 ticks/sec (33 ms loop)
        gs = BS_AIM;
        _computeAimIntersect();
    }

    // ── Leaderboard helpers ───────────────────────────────────
    // Variant = current game type (e.g. "9-ball"), so each pool game has its
    // own win-streak ranking.
    function lbVariant() {
        if (gameType == GT_3BALL)      { return "3-ball"; }
        if (gameType == GT_8BALL)      { return "8-ball"; }
        if (gameType == GT_SNOOKER)    { return "snooker"; }
        if (gameType == GT_TIMEATTACK) { return "timeattack"; }
        return "9-ball";
    }

    hidden function _loadStreak() {
        var v = Application.Storage.getValue(LB_STREAK_KEY);
        if (v instanceof Lang.Number) { return v; }
        return 0;
    }

    hidden function _saveStreak(n) {
        try { Application.Storage.setValue(LB_STREAK_KEY, n); } catch (e) {}
    }

    // Called by the View once the game reaches BS_GAMEOVER. Win streak counts
    // consecutive player wins vs the AI; P-vs-P matches are never submitted.
    // winReason: 1/3 = player win, 2/4 = AI win.
    function reportResult() {
        if (_lbHandled) { return; }
        _lbHandled = true;
        if (gameType == GT_TIMEATTACK) {
            // Arcade high-score board — every run with a non-zero score
            // is worth submitting (no win/lose framing here).
            if (playerScore > 0) {
                Leaderboard.submitScore(LB_GAME_ID, playerScore, "timeattack");
                Leaderboard.showPostGame(LB_GAME_ID, "timeattack", "BILLIARDS");
            }
            return;
        }
        if (pvpMode) { return; }
        var playerWon = (winReason == 1 || winReason == 3);
        if (playerWon) {
            var s = _loadStreak() + 1;
            _saveStreak(s);
            Leaderboard.submitScore(LB_GAME_ID, s, lbVariant());
            Leaderboard.showPostGame(LB_GAME_ID, lbVariant(), "BILLIARDS");
        } else {
            _saveStreak(0);
        }
    }

    // ── Ball-group classification (8-ball mode) ─────────────
    // Returns 1 = SOLID (balls 1-7), 2 = STRIPE (balls 9-15),
    // 0 = neither (cue=0 or 8 or out-of-range).
    function ballGroup(b) {
        if (b >= 1 && b <= 7) { return 1; }
        if (b >= 9 && b <= 15) { return 2; }
        return 0;
    }

    // Human-readable group label for HUD.
    function groupLabel(g) {
        if (g == 1) { return "SOLIDS"; }
        if (g == 2) { return "STRIPES"; }
        return "OPEN";
    }

    // Return shooter label for messages — "You"/"AI" in PvAI, "P1"/"P2" in PvP.
    hidden function _shooterLabel(t) {
        if (pvpMode) {
            return (t == TURN_PLAYER) ? "P1" : "P2";
        }
        return (t == TURN_PLAYER) ? "You" : "AI";
    }
    hidden function _opponentLabel(t) {
        if (pvpMode) {
            return (t == TURN_PLAYER) ? "P2" : "P1";
        }
        return (t == TURN_PLAYER) ? "AI" : "You";
    }

    // ── Rack layouts ──────────────────────────────────────────
    // All racks place balls so they touch (BALL_D=52 pitch); column step ≈ 45.

    // 3-Ball: small triangle, apex pointing left (toward cue).
    hidden function _setupRack3Ball() {
        bx[1] = 700.0; by[1] = 350.0;  // apex
        bx[2] = 745.0; by[2] = 324.0;
        bx[3] = 745.0; by[3] = 376.0;
    }

    // Snooker: 6 reds in a triangle (apex left) + BLACK behind on long axis.
    // Slots 1-6 = reds (1 pt each), slot 7 = black (7 pt, wins after reds).
    hidden function _setupRackSnooker() {
        bx[1] = 680.0; by[1] = 350.0;  // red apex
        bx[2] = 725.0; by[2] = 324.0;
        bx[3] = 725.0; by[3] = 376.0;
        bx[4] = 770.0; by[4] = 298.0;
        bx[5] = 770.0; by[5] = 350.0;
        bx[6] = 770.0; by[6] = 402.0;
        bx[7] = 850.0; by[7] = 350.0;  // BLACK on long spot behind the pack
    }

    // 9-Ball: diamond rack, apex pointing left, BLACK 9 at centre.
    hidden function _setupRack9Ball() {
        bx[1] = 680.0; by[1] = 350.0;  // apex
        bx[2] = 725.0; by[2] = 324.0;
        bx[3] = 725.0; by[3] = 376.0;
        bx[4] = 770.0; by[4] = 298.0;
        bx[9] = 770.0; by[9] = 350.0;  // BLACK key ball
        bx[6] = 770.0; by[6] = 402.0;
        bx[7] = 815.0; by[7] = 324.0;
        bx[8] = 815.0; by[8] = 376.0;
        bx[5] = 860.0; by[5] = 350.0;
    }

    // 8-Ball: standard 15-ball triangle, BLACK 8 at centre of 3rd row.
    // Layout (apex at left):
    //   Row 1: 1
    //   Row 2: 2 3
    //   Row 3: 4 8 5   ← black 8 in the middle
    //   Row 4: 9 6 7 10
    //   Row 5: 11 12 13 14 15
    hidden function _setupRack8Ball() {
        bx[1]  = 660.0; by[1]  = 350.0;
        bx[2]  = 705.0; by[2]  = 324.0;
        bx[3]  = 705.0; by[3]  = 376.0;
        bx[4]  = 750.0; by[4]  = 298.0;
        bx[8]  = 750.0; by[8]  = 350.0;  // BLACK key ball
        bx[5]  = 750.0; by[5]  = 402.0;
        bx[9]  = 795.0; by[9]  = 272.0;
        bx[6]  = 795.0; by[6]  = 324.0;
        bx[7]  = 795.0; by[7]  = 376.0;
        bx[10] = 795.0; by[10] = 428.0;
        bx[11] = 840.0; by[11] = 246.0;
        bx[12] = 840.0; by[12] = 298.0;
        bx[13] = 840.0; by[13] = 350.0;
        bx[14] = 840.0; by[14] = 402.0;
        bx[15] = 840.0; by[15] = 454.0;
    }

    // ── Input handlers ────────────────────────────────────────
    // Menu controls (3 rows: MODE, DIFF, START):
    //   UP      — move menu cursor UP (wraps)
    //   DN      — move menu cursor DOWN (wraps) — primary navigation
    //   SEL/TAP — activate current row:
    //               • MODE row : cycle game type
    //               • DIFF row : cycle difficulty
    //               • START row: begin the game
    // In game:
    //   UP/DN aim with progressive precision: a single tap nudges aim by
    //   exactly 1° (ultra-fine). Hold / spam in the same direction and the
    //   step accelerates: 1° → 2° → 4° → 6° (max). A direction change or
    //   ~200ms idle resets back to the finest 1° step.
    //   SEL/TAP commits power / starts charging.
    function doUp() {
        if (gs == BS_MENU) {
            menuSel = (menuSel + 4) % 5;  // -1 mod 5
            return;
        }
        if (gs == BS_GAMEOVER) { gs = BS_MENU; return; }
        if (gs == BS_AIM && (turn == TURN_PLAYER || pvpMode)) { _aimStep(-1); }
        if (gs == BS_POWER) { _commitShot(); }
    }

    function doDown() {
        if (gs == BS_MENU) {
            menuSel = (menuSel + 1) % 5;
            return;
        }
        if (gs == BS_GAMEOVER) { gs = BS_MENU; return; }
        if (gs == BS_AIM && (turn == TURN_PLAYER || pvpMode)) { _aimStep(1); }
        if (gs == BS_POWER) { _commitShot(); }
    }

    // Progressive aim helper. dir = -1 (CCW) / +1 (CW).
    hidden function _aimStep(dir) {
        if (dir != _aimRptDir || _aimRptIdle > 6) {
            // direction change or long pause → restart the streak
            _aimRptDir    = dir;
            _aimRptStreak = 0;
        }
        var st;
        if      (_aimRptStreak < 3) { st = 1.0; }
        else if (_aimRptStreak < 6) { st = 2.0; }
        else if (_aimRptStreak < 9) { st = 4.0; }
        else                         { st = 6.0; }
        aimAngle += dir * st;
        while (aimAngle <  0.0)   { aimAngle += 360.0; }
        while (aimAngle >= 360.0) { aimAngle -= 360.0; }
        _aimRptStreak = _aimRptStreak + 1;
        _aimRptIdle   = 0;
        _computeAimIntersect();
    }

    function doSelect() {
        if (gs == BS_MENU)    { _menuActivate(); return; }
        if (gs == BS_GAMEOVER){ gs = BS_MENU; return; }
        if (gs == BS_AIM  && (turn == TURN_PLAYER || pvpMode)) { gs = BS_POWER; power = 0; powerDir = 1; return; }
        if (gs == BS_POWER)   { _commitShot(); return; }
    }

    // Apply the action of the currently focused menu row.
    hidden function _menuActivate() {
        if (menuSel == 0) {
            gameType = (gameType + 1) % GT_COUNT;
            Application.Storage.setValue("billGT", gameType);
            _applyGameType();
        } else if (menuSel == 1) {
            pvpMode = !pvpMode;
            Application.Storage.setValue("billPvP", pvpMode);
        } else if (menuSel == 2) {
            diff = (diff + 1) % 3;
            Application.Storage.setValue("billDiff", diff);
        } else if (menuSel == 3) {
            lbRequested = true;   // View opens the leaderboard panel
        } else {
            startGame();
        }
    }

    function doBack() {
        // Root menu is the shared view now; let the framework pop us back to it.
        return false;
    }

    function doTap(tx, ty) {
        if (gs == BS_MENU)     { _menuActivate(); return; }
        if (gs == BS_GAMEOVER) { gs = BS_MENU; return; }
        if (gs == BS_POWER)    { _commitShot(); return; }
        if (gs != BS_AIM || (turn != TURN_PLAYER && !pvpMode)) { return; }

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
        // Tick the aim auto-reset (back to 1° step after a brief idle).
        if (_aimRptIdle < 1000) { _aimRptIdle = _aimRptIdle + 1; }
        for (var bf = 0; bf < BOUNCE_FX_MAX; bf++) {
            if (bounceFxLife[bf] > 0) { bounceFxLife[bf]--; }
        }
        // TIME ATTACK countdown — ticks whenever a round is actually in
        // progress (aiming / charging / rolling). If time runs out while
        // the player is mid-aim or mid-charge (no ball moving), end the
        // run immediately; if a shot is already rolling, let it finish
        // and _onRollingComplete() ends the run right after — a fair
        // "the last shot always counts" rule.
        if (gameType == GT_TIMEATTACK && (gs == BS_AIM || gs == BS_POWER || gs == BS_ROLLING)) {
            if (arcadeTicks > 0) { arcadeTicks--; }
            if (arcadeTicks <= 0 && (gs == BS_AIM || gs == BS_POWER)) { _finishTimeAttack(); }
        }
        if (gs == BS_ROLLING) { _stepPhysics(); }
        if (gs == BS_AI_WAIT) {
            aiDelay--;
            if (aiDelay <= 0) { _executeAiShot(); }
        }
    }

    // ── PhysicsEngine ────────────────────────────────────────
    // Loops iterate over numBalls (active balls only) so 8-ball mode with 16
    // balls runs as smoothly as 9-ball (per-tick cost ∝ numBalls²).
    //
    // Substeps: 4 per tick (dt=0.25). With the shot speeds pushed by the
    // _commitShot formula (max ≈137 course units/tick), that caps the
    // per-substep move at ≈34 — well under BALL_D=52 (35% margin, up from
    // the previous 3-substep ≈46/12% margin) — extra tunneling headroom
    // for the hardest break shots without any change to how a shot feels,
    // since the physics still resolves to the same speeds/restitution.
    //
    // Pocket-aware walls: near each pocket the rail is "open" so a ball
    // approaching the cushion right next to a pocket isn't deflected — it
    // rolls past the rail line into the capture zone. This fixes the
    // long-standing feel where a ball had to be hit "perfectly clean" to
    // drop and would otherwise bounce off the corner.
    //
    // Pocket check now runs once per substep (not just once per tick) so
    // a fast-moving ball passing through the capture zone in mid-substep
    // is still caught instead of escaping past the pocket.
    hidden function _stepPhysics() {
        var subDt = 1.0 / 4.0;
        for (var s = 0; s < 4; s++) {
            for (var i = 0; i < numBalls; i++) {
                if (!bAlive[i]) { continue; }
                bx[i] += bvx[i] * subDt;
                by[i] += bvy[i] * subDt;
                // Wall bounce — but only when this ball isn't currently
                // inside the open-rail zone of any pocket.  Bounce
                // restitution bumped from 0.85 → 0.90 so the table
                // plays livelier (per user request: "mocniejsze
                // odbijanie się od bandy"). Hard impacts (>8 c.u./tick
                // into the rail) also queue a cushion-flash fx point for
                // the View to render — purely cosmetic feedback.
                if (!_nearPocketOpen(i)) {
                    if (bx[i] < WL.toFloat()) {
                        bx[i] = WL.toFloat();
                        if (bvx[i] < 0.0) {
                            if (-bvx[i] > 8.0) { _addBounceFx(bx[i], by[i]); }
                            bvx[i] = -bvx[i] * 0.90;
                        }
                    }
                    if (bx[i] > WR.toFloat()) {
                        bx[i] = WR.toFloat();
                        if (bvx[i] > 0.0) {
                            if (bvx[i] > 8.0) { _addBounceFx(bx[i], by[i]); }
                            bvx[i] = -bvx[i] * 0.90;
                        }
                    }
                    if (by[i] < WT.toFloat()) {
                        by[i] = WT.toFloat();
                        if (bvy[i] < 0.0) {
                            if (-bvy[i] > 8.0) { _addBounceFx(bx[i], by[i]); }
                            bvy[i] = -bvy[i] * 0.90;
                        }
                    }
                    if (by[i] > WB.toFloat()) {
                        by[i] = WB.toFloat();
                        if (bvy[i] > 0.0) {
                            if (bvy[i] > 8.0) { _addBounceFx(bx[i], by[i]); }
                            bvy[i] = -bvy[i] * 0.90;
                        }
                    }
                }
            }
            _resolveBallCollisions();
            _checkPockets();
        }
        // Speed-tiered friction.  Fast balls (the meaty travel phase)
        // get an even gentler 0.974 so big shots — especially the
        // glancing/angled cue-ball rolls after an off-centre contact
        // — carry a noticeable extra stretch across the table.
        // Medium balls also decay a touch slower (0.948 vs 0.930) so
        // the satisfying mid-roll phase after a clean angled hit
        // doesn't die just as the ball lines up with a pocket.  Slow
        // balls still die quickly so the simulation wraps up cleanly
        // instead of dragging out with sub-perceptible trickling.
        for (var i = 0; i < numBalls; i++) {
            if (!bAlive[i]) { continue; }
            var v2 = bvx[i]*bvx[i] + bvy[i]*bvy[i];
            var f;
            if      (v2 > 25.0) { f = 0.974; }   // fast — long carry
            else if (v2 > 4.0)  { f = 0.948; }   // medium — extra roll
            else                 { f = 0.860; }   // slow / settling
            bvx[i] *= f;
            bvy[i] *= f;
        }
        // Stop when all balls slow enough.  Threshold raised from 0.09
        // to 0.50 so we end the shot before each ball reaches the
        // imperceptible 0.3 c.u./tick trickle.
        var allStopped = true;
        for (var i = 0; i < numBalls; i++) {
            if (!bAlive[i]) { continue; }
            if (bvx[i]*bvx[i] + bvy[i]*bvy[i] > 0.50) { allStopped = false; break; }
        }
        if (allStopped) {
            for (var i = 0; i < numBalls; i++) { bvx[i] = 0.0; bvy[i] = 0.0; }
            _onRollingComplete();
        }
    }

    // Queue a cushion-impact flash at (x,y) in a small ring buffer — no
    // allocation per call, just overwrites the oldest slot.
    hidden function _addBounceFx(x, y) {
        bounceFxX[_bounceFxNext] = x; bounceFxY[_bounceFxNext] = y;
        bounceFxLife[_bounceFxNext] = BOUNCE_FX_LIFE;
        _bounceFxNext = (_bounceFxNext + 1) % BOUNCE_FX_MAX;
    }

    // True iff ball `i`'s centre is inside the open-rail zone of any
    // pocket. While inside, wall bouncing is suppressed so the ball
    // can actually enter the pocket instead of being deflected by the
    // cushion right next to it.
    hidden function _nearPocketOpen(i) {
        var r2 = POCKET_OPEN_R.toFloat() * POCKET_OPEN_R.toFloat();
        for (var p = 0; p < NUM_POCKETS; p++) {
            var dx = bx[i] - pX[p].toFloat();
            var dy = by[i] - pY[p].toFloat();
            if (dx*dx + dy*dy < r2) { return true; }
        }
        return false;
    }

    // Ball-ball elastic collision (equal mass).
    // Also records `firstHit` — the first non-cue ball the cue (idx 0) contacts
    // during a shot. Used by the rules engine (9-ball "hit lowest first",
    // 8-ball "hit own group first").
    hidden function _resolveBallCollisions() {
        for (var i = 0; i < numBalls - 1; i++) {
            if (!bAlive[i]) { continue; }
            for (var j = i + 1; j < numBalls; j++) {
                if (!bAlive[j]) { continue; }
                var dx = bx[j] - bx[i]; var dy = by[j] - by[i];
                var dist2 = dx*dx + dy*dy;
                if (dist2 >= BALL_D * BALL_D || dist2 < 0.01) { continue; }
                var dist = Math.sqrt(dist2);
                var nx = dx / dist; var ny = dy / dist;
                var dvx = bvx[j] - bvx[i]; var dvy = bvy[j] - bvy[i];
                var dvn = dvx * nx + dvy * ny;
                if (dvn < 0.0) {  // approaching
                    // Equal-mass collision with a small spin-aware
                    // restitution shortfall (k=0.97) — i.e. only 97 %
                    // of the normal-component velocity transfers
                    // from cue to target.  The remaining 3 % stays
                    // with the striking ball as residual roll along
                    // the line of impact.  Effect: a glancing/angled
                    // hit no longer dead-stops the cue's
                    // line-of-impact component, so the cue keeps
                    // travelling a touch further along its original
                    // trajectory — the way a real cue ball does
                    // thanks to natural top-spin.  Head-on hits
                    // still look right (cue almost stops; target
                    // sprints off with ~97 % of the energy and a
                    // tiny bit of follow-through), and the
                    // tangential component is preserved exactly,
                    // which is what gives angled shots their
                    // satisfying "carry" after contact.
                    var k = 0.97;
                    var jn = dvn * k;
                    bvx[i] += jn * nx; bvy[i] += jn * ny;
                    bvx[j] -= jn * nx; bvy[j] -= jn * ny;
                    // First-hit tracking for rules engine
                    if (firstHit == -1) {
                        if (i == 0)      { firstHit = j; }
                        else if (j == 0) { firstHit = i; }
                    }
                }
                var overlap = (BALL_D.toFloat() - dist) * 0.52;
                bx[i] -= nx * overlap; by[i] -= ny * overlap;
                bx[j] += nx * overlap; by[j] += ny * overlap;
            }
        }
    }

    hidden function _checkPockets() {
        var capR2 = POCKET_R.toFloat() * POCKET_R.toFloat();
        for (var i = 0; i < numBalls; i++) {
            if (!bAlive[i]) { continue; }
            // Standard pocket capture
            for (var p = 0; p < NUM_POCKETS; p++) {
                var pdx = bx[i] - pX[p]; var pdy = by[i] - pY[p];
                if (pdx*pdx + pdy*pdy < capR2) {
                    _pocketBall(i); break;
                }
            }
            if (!bAlive[i]) { continue; }
            // Safety net: with the rail-open zone around pockets, a
            // very fast ball could in theory squirt past a pocket and
            // out beyond the table edge before _checkPockets sees it.
            // If that happens, just drop it into the nearest pocket
            // — physically equivalent ("it went off the table where
            // the pocket is") and keeps the game state consistent.
            if (bx[i] < TL - 4 || bx[i] > TR + 4
             || by[i] < TT - 4 || by[i] > TB + 4) {
                _pocketBall(i);
            }
        }
    }

    // A ball entered a pocket. Cue ball stays OFF the table (dead) until
    // all balls finish rolling — _respawnCue() puts it back at the baulk
    // line with zero velocity in _onRollingComplete. This avoids the
    // confusing behaviour where the cue used to teleport onto the foul
    // line while the rack was still in motion and could be pushed by
    // still-rolling balls.
    hidden function _pocketBall(i) {
        bAlive[i] = false; bvx[i] = 0.0; bvy[i] = 0.0;
        if (i == 0) {
            cueScratched = true;
        } else {
            if (pottedCnt < 16) {
                pottedList[pottedCnt] = i;
                pottedCnt++;
            }
        }
    }

    // Place a scratched cue ball back at the baulk area with zero velocity,
    // picking the first candidate spot that isn't overlapping another ball.
    hidden function _respawnCue() {
        // Candidate baulk positions, tried left-to-right / top-to-bottom.
        var spotsX = [230.0, 210.0, 250.0, 195.0, 265.0, 180.0];
        var spotsY = [350.0, 290.0, 290.0, 410.0, 410.0, 350.0];
        var minD2 = (BALL_R.toFloat() * 2.1) * (BALL_R.toFloat() * 2.1);
        var s = 0;
        while (s < 6) {
            var nx = spotsX[s]; var ny = spotsY[s];
            var clear = true;
            for (var k = 1; k < numBalls; k++) {
                if (!bAlive[k]) { continue; }
                var dx = bx[k] - nx; var dy = by[k] - ny;
                if (dx*dx + dy*dy < minD2) { clear = false; break; }
            }
            if (clear) { bx[0] = nx; by[0] = ny; break; }
            s = s + 1;
        }
        if (s >= 6) {
            // All candidate slots are occupied — fall back to original spot.
            bx[0] = 230.0; by[0] = 350.0;
        }
        bvx[0] = 0.0; bvy[0] = 0.0;
        bAlive[0] = true;
    }

    hidden function _onRollingComplete() {
        // Bring the cue back onto the table ONLY now that everything is
        // at rest. _evaluateShot reads cueScratched (already set), not
        // bAlive[0], so respawning first is safe and keeps later aiming
        // / AI logic consistent.
        if (cueScratched) { _respawnCue(); }
        _evaluateShot();
        if (gs == BS_GAMEOVER) { return; }
        // TIME ATTACK is solo — the player always shoots again, turn
        // never switches to an "opponent" that doesn't exist here.
        if (!pocketedThisTurn && gameType != GT_TIMEATTACK) {
            turn = (turn == TURN_PLAYER) ? TURN_AI : TURN_PLAYER;
        }
        pocketedThisTurn = false;
        // Reset per-shot trackers for the next shot
        firstHit = -1; cueScratched = false; pottedCnt = 0;

        if (gameType == GT_TIMEATTACK) {
            if (arcadeTicks <= 0) { _finishTimeAttack(); return; }
            gs = BS_AIM;
            _computeAimIntersect();
            return;
        }

        if (turn == TURN_PLAYER) {
            gs = BS_AIM;
            _computeAimIntersect();
        } else {
            if (pvpMode) {
                // P vs P — Player 2 uses the same aim/shoot controls
                gs = BS_AIM;
                _computeAimIntersect();
            } else {
                _aiThink();
                gs = BS_AI_WAIT;
            }
        }
    }

    // ── Rules engine ─────────────────────────────────────────
    // Called after physics stops. Computes per-mode legality, awards
    // points, decides if shooter continues or turn switches, and detects
    // win/loss. Sets: playerScore, aiScore, pocketedThisTurn, gs, winReason,
    // msg, msgT, playerGroup (8-ball).
    hidden function _evaluateShot() {
        if      (gameType == GT_3BALL)      { _eval3Ball(); }
        else if (gameType == GT_9BALL)      { _eval9Ball(); }
        else if (gameType == GT_SNOOKER)    { _evalSnooker(); }
        else if (gameType == GT_TIMEATTACK) { _evalTimeAttack(); }
        else                                 { _eval8Ball(); }
    }

    // TIME ATTACK: every ball potted (any ball, any order) is +1 point,
    // no fouls, no legality checks — pure fast-paced arcade potting. A
    // scratch just costs a small time penalty (risk/reward for going for
    // a risky shot) instead of losing a turn (there's no one to lose it
    // to). Clearing the whole rack early pays out a time-remaining bonus
    // and ends the run right there.
    hidden function _evalTimeAttack() {
        if (cueScratched) {
            msg = "Scratch! -2s"; msgT = 40;
            pocketedThisTurn = false;
            arcadeTicks -= 60;
            if (arcadeTicks < 0) { arcadeTicks = 0; }
            return;
        }
        if (pottedCnt > 0) {
            playerScore += pottedCnt;
            msg = "+" + pottedCnt + "!"; msgT = 30;
            pocketedThisTurn = true;
        } else {
            pocketedThisTurn = false;
        }
        var allGone = true;
        for (var b = 1; b < numBalls; b++) {
            if (bAlive[b]) { allGone = false; break; }
        }
        if (allGone) {
            var bonus = arcadeTicks / 15;  // ~2 pts per second remaining
            playerScore += bonus;
            msg = "CLEARED! +" + bonus; msgT = 70;
            winReason = 6;
            gs = BS_GAMEOVER;
        }
    }

    hidden function _finishTimeAttack() {
        winReason = 5;
        msg = "Time's up!"; msgT = 60;
        gs = BS_GAMEOVER;
    }

    // 3-BALL: simple race. Any pot scores. Cue scratch = lose turn, no score
    // change. When all 3 balls are potted, highest score wins (tie = player).
    hidden function _eval3Ball() {
        var k;
        if (cueScratched) {
            msg = "Scratch!"; msgT = 50;
            pocketedThisTurn = false;
        } else {
            for (k = 0; k < pottedCnt; k++) {
                if (turn == TURN_PLAYER) { playerScore++; }
                else                     { aiScore++;    }
            }
            if (pottedCnt > 0) {
                msg = _shooterLabel(turn) + " scored!";
                msgT = 40;
                pocketedThisTurn = true;
            } else {
                pocketedThisTurn = false;
            }
        }
        // Game-over when all 3 target balls pocketed
        var allGone = true;
        for (var b = 1; b < numBalls; b++) {
            if (bAlive[b]) { allGone = false; break; }
        }
        if (allGone) {
            if      (playerScore > aiScore) { winReason = 1; }
            else if (aiScore > playerScore) { winReason = 2; }
            else                            { winReason = 1; } // tie → player wins
            gs = BS_GAMEOVER;
        }
    }

    // 9-BALL: must hit lowest-numbered live ball first. Pot ANY ball = legal
    // continuation. Pot 9 = INSTANT WIN. Cue scratch or wrong-first-hit = foul
    // (turn switches; no penalty in this simplified version).
    hidden function _eval9Ball() {
        // Was 9 potted?
        var pot9 = false;
        var k;
        for (k = 0; k < pottedCnt; k++) {
            if (pottedList[k] == 9) { pot9 = true; break; }
        }

        // Cue scratch → foul. If 9 was also potted, respot it (ball comes back).
        if (cueScratched) {
            if (pot9) {
                // Respot 9 at footspot (we use the centre of the rack apex area)
                bAlive[9] = true; bx[9] = 770.0; by[9] = 350.0;
                bvx[9] = 0.0; bvy[9] = 0.0;
            }
            msg = "Scratch! Foul"; msgT = 55;
            pocketedThisTurn = false;
            return;
        }
        // Wrong first hit → foul (lowestPreShot was captured in _commitShot)
        if (firstHit != lowestPreShot) {
            // If 9 was potted illegally, respot it
            if (pot9) {
                bAlive[9] = true; bx[9] = 770.0; by[9] = 350.0;
                bvx[9] = 0.0; bvy[9] = 0.0;
            }
            msg = "Foul - hit " + lowestPreShot + " first"; msgT = 55;
            pocketedThisTurn = false;
            return;
        }
        // Legal shot: pot 9 = instant win
        if (pot9) {
            winReason = (turn == TURN_PLAYER) ? 1 : 2;
            gs = BS_GAMEOVER;
            return;
        }
        // Score per ball potted, continue if any
        for (k = 0; k < pottedCnt; k++) {
            if (turn == TURN_PLAYER) { playerScore++; }
            else                     { aiScore++;    }
        }
        if (pottedCnt > 0) {
            msg = _shooterLabel(turn) + " scored!";
            msgT = 40;
            pocketedThisTurn = true;
        } else {
            pocketedThisTurn = false;
        }
    }

    // 8-BALL: assign groups (SOLIDS 1-7 vs STRIPES 9-15) on first pot.
    // Each player pots only their own group. Pot 8 with group cleared = WIN;
    // pot 8 early or scratch on 8 = LOSS. Hitting opp's group first = foul.
    hidden function _eval8Ball() {
        var myG = playerGroup[turn];
        var oppT = (turn == TURN_PLAYER) ? TURN_AI : TURN_PLAYER;

        // Detect 8-ball pot
        var pot8 = false;
        var k;
        for (k = 0; k < pottedCnt; k++) {
            if (pottedList[k] == 8) { pot8 = true; break; }
        }

        // === 8-ball pot resolution (game-over conditions) ===
        if (pot8) {
            // Did shooter clear their group BEFORE this shot (i.e., no more own-group balls)?
            var cleared = true;
            if (myG == 0) {
                cleared = false; // never legal to pot 8 before assignment
            } else {
                for (var b = 1; b < numBalls; b++) {
                    if (b == 8) { continue; }
                    if (!bAlive[b]) { continue; }
                    if (ballGroup(b) == myG) { cleared = false; break; }
                }
            }
            if (cleared && !cueScratched) {
                msg = _shooterLabel(turn) + " wins!";
                msgT = 60;
                winReason = (turn == TURN_PLAYER) ? 1 : 2;
            } else {
                msg = "8-ball foul - " + _opponentLabel(turn) + " wins";
                msgT = 60;
                winReason = (turn == TURN_PLAYER) ? 4 : 3;
            }
            gs = BS_GAMEOVER;
            return;
        }

        // === Cue scratch (no 8-ball) → foul, switch turn, balls stay potted ===
        if (cueScratched) {
            _eight_recountScores();
            msg = "Scratch! Foul"; msgT = 50;
            pocketedThisTurn = false;
            return;
        }

        // === Group assignment on first legal pot ===
        // If groups not yet assigned and at least one numbered ball was potted,
        // the shooter takes the group of the FIRST potted ball.
        if (myG == 0 && pottedCnt > 0) {
            var firstPotGroup = ballGroup(pottedList[0]);
            if (firstPotGroup != 0) {
                playerGroup[turn] = firstPotGroup;
                playerGroup[oppT] = (firstPotGroup == 1) ? 2 : 1;
                myG = firstPotGroup;
                msg = (turn == TURN_PLAYER ? "You: " : "AI: ") + groupLabel(myG);
                msgT = 55;
            }
        }

        // === First-hit legality ===
        // After assignment, cue must contact own-group ball first (or 8 if cleared).
        // Hitting nothing = foul.
        if (firstHit == -1) {
            _eight_recountScores();
            msg = "Miss - foul"; msgT = 50;
            pocketedThisTurn = false;
            return;
        }
        if (myG != 0) {
            var hitG = ballGroup(firstHit);
            // Hitting opp's group first = foul (unless own group is cleared and we hit 8)
            if (hitG != myG && firstHit != 8) {
                _eight_recountScores();
                msg = "Foul - wrong ball"; msgT = 50;
                pocketedThisTurn = false;
                return;
            }
        }

        // === Score & continuation ===
        // Score = own-group balls potted by this player (cumulative).
        // Continue turn only if AT LEAST ONE own-group ball was potted AND no opp-group balls were potted.
        // (Potting opp's = legal hit but ends turn — common house rule.)
        var myPotted = 0;
        var oppPotted = 0;
        for (k = 0; k < pottedCnt; k++) {
            var g = ballGroup(pottedList[k]);
            if (g == myG && myG != 0) { myPotted++; }
            else if (g != 0 && g != myG && myG != 0) { oppPotted++; }
        }
        _eight_recountScores();
        if (myPotted > 0 && oppPotted == 0) {
            pocketedThisTurn = true;
            if (msgT == 0) { msg = _shooterLabel(turn) + " scored!"; msgT = 40; }
        } else if (oppPotted > 0) {
            pocketedThisTurn = false;
            msg = "Wrong group potted"; msgT = 45;
        } else {
            pocketedThisTurn = false;
        }
    }

    // Score helper for 8-ball — recompute from scratch based on group state.
    // playerScore = #balls of player's group already pocketed.
    // aiScore = #balls of AI's group already pocketed.
    hidden function _eight_recountScores() {
        playerScore = 0; aiScore = 0;
        var pg = playerGroup[0]; var ag = playerGroup[1];
        if (pg == 0) { return; }
        for (var b = 1; b < numBalls; b++) {
            if (b == 8) { continue; }
            if (bAlive[b]) { continue; }
            var g = ballGroup(b);
            if (g == pg) { playerScore++; }
            else if (g == ag) { aiScore++; }
        }
    }

    // SNOOKER: simplified ruleset (1 cue + 6 reds + 1 black).
    //   • Must hit a RED first if any red is alive (slots 1-6).
    //   • If all reds are gone, must hit the BLACK (slot 7).
    //   • Pot a red          → +1 pt, continue.
    //   • Pot black + reds gone → +7 pt, GAME WINS (highest score).
    //   • Pot black with reds remaining → FOUL: respot black at long spot,
    //     no points, switch turn.
    //   • Wrong first hit / cue scratch  → FOUL: switch turn.
    hidden function _evalSnooker() {
        var k;

        // Find lowest live red (slots 1..6)
        var anyRed = false;
        for (k = 1; k <= 6; k++) {
            if (bAlive[k]) { anyRed = true; break; }
        }

        var potBlack = false;
        var potRedCnt = 0;
        for (k = 0; k < pottedCnt; k++) {
            if (pottedList[k] == 7) { potBlack = true; }
            else if (pottedList[k] >= 1 && pottedList[k] <= 6) { potRedCnt = potRedCnt + 1; }
        }

        // Scratch is always a foul. Respot black if it was potted too.
        if (cueScratched) {
            if (potBlack) {
                bAlive[7] = true; bx[7] = 850.0; by[7] = 350.0;
                bvx[7] = 0.0; bvy[7] = 0.0;
            }
            msg = "Scratch! Foul"; msgT = 55;
            pocketedThisTurn = false;
            return;
        }
        // First-hit legality: red required if any red alive, else black.
        var requireRed = anyRed;
        var legalHit = (requireRed)
            ? (firstHit >= 1 && firstHit <= 6)
            : (firstHit == 7);
        if (!legalHit) {
            if (potBlack) {
                bAlive[7] = true; bx[7] = 850.0; by[7] = 350.0;
                bvx[7] = 0.0; bvy[7] = 0.0;
            }
            msg = requireRed ? "Foul - hit red first" : "Foul - hit black";
            msgT = 55;
            pocketedThisTurn = false;
            return;
        }
        // Legal shot — apply scoring.
        // Black potted before reds cleared → foul, respot, no points.
        if (potBlack && anyRed && potRedCnt == 0) {
            bAlive[7] = true; bx[7] = 850.0; by[7] = 350.0;
            bvx[7] = 0.0; bvy[7] = 0.0;
            msg = "Foul - black early"; msgT = 55;
            pocketedThisTurn = false;
            return;
        }
        // Award red pots first
        if (potRedCnt > 0) {
            if (turn == TURN_PLAYER) { playerScore = playerScore + potRedCnt; }
            else                     { aiScore     = aiScore     + potRedCnt; }
        }
        // Black after all reds cleared = game over (+7 pts)
        if (potBlack) {
            // anyRed was true before THIS shot, but those reds may have been
            // potted on the same shot. Recompute "still any red" post-pot.
            var stillRed = false;
            for (k = 1; k <= 6; k++) {
                if (bAlive[k]) { stillRed = true; break; }
            }
            if (stillRed) {
                // Potted black while reds remaining (only possible via foul we
                // already trapped above) — defensive guard, treat as foul.
                bAlive[7] = true; bx[7] = 850.0; by[7] = 350.0;
                bvx[7] = 0.0; bvy[7] = 0.0;
                msg = "Foul - black early"; msgT = 55;
                pocketedThisTurn = false;
                return;
            }
            if (turn == TURN_PLAYER) { playerScore = playerScore + 7; }
            else                     { aiScore     = aiScore     + 7; }
            // Highest score wins (in equal scores, the player who potted black wins).
            if (playerScore >= aiScore) { winReason = 1; }
            else                        { winReason = 2; }
            msg = _shooterLabel(turn) + " wins!";
            msgT = 60;
            gs = BS_GAMEOVER;
            return;
        }
        // Any legal pot = continue, no pots = switch turn.
        if (pottedCnt > 0) {
            msg = _shooterLabel(turn) + " scored!";
            msgT = 40;
            pocketedThisTurn = true;
        } else {
            pocketedThisTurn = false;
        }
    }

    // ── Shot mechanics ────────────────────────────────────────
    hidden function _commitShot() {
        var rad = aimAngle * Math.PI / 180.0;
        // Significantly stronger shot than before — user feedback was
        // that shots felt weak even at max power.  New range:
        //   power=0   → spd ≈ 12  (gentle tap)
        //   power=50  → spd ≈ 74
        //   power=100 → spd ≈ 137 (booming break-shot)
        // Per-substep move (3 substeps) = spd/3 ≤ 46 < BALL_D(52)
        // so ball-ball tunneling is still impossible.
        var spd = power.toFloat() * 1.25 + 12.0;
        bvx[0] = Math.cos(rad) * spd;
        bvy[0] = Math.sin(rad) * spd;
        // Reset per-shot trackers
        firstHit = -1; cueScratched = false; pottedCnt = 0;
        // For 9-ball: snapshot the lowest live ball BEFORE the shot
        // (firstHit must equal this for the shot to be legal).
        lowestPreShot = -1;
        for (var b = 1; b < numBalls; b++) {
            if (bAlive[b]) { lowestPreShot = b; break; }
        }
        pocketedThisTurn = false;
        gs = BS_ROLLING;
    }

    // ── AIController ─────────────────────────────────────────
    // True if ball b is a legal first-hit target for the AI right now.
    //   3-BALL: any live ball.
    //   9-BALL: must be the lowest live numbered ball.
    //   8-BALL: must be in AI's group (or 8 if AI cleared its group).
    //           If unassigned, any ball except 8 is legal.
    hidden function _isLegalTargetForAI(b) {
        if (!bAlive[b]) { return false; }
        if (gameType == GT_9BALL) {
            return (b == lowestPreShot);
        }
        if (gameType == GT_8BALL) {
            var ag = playerGroup[TURN_AI];
            if (ag == 0) { return (b != 8); }
            if (b == 8) {
                // Legal only if AI cleared its group already
                for (var k = 1; k < numBalls; k++) {
                    if (k == 8) { continue; }
                    if (!bAlive[k]) { continue; }
                    if (ballGroup(k) == ag) { return false; }
                }
                return true;
            }
            return (ballGroup(b) == ag);
        }
        if (gameType == GT_SNOOKER) {
            // Must hit a red if any red alive; else must hit black.
            var anyRed = false;
            for (var k2 = 1; k2 <= 6; k2++) {
                if (bAlive[k2]) { anyRed = true; break; }
            }
            if (anyRed) { return (b >= 1 && b <= 6); }
            return (b == 7);
        }
        return true; // GT_3BALL
    }

    // Refresh the lowestPreShot snapshot just before AI plans its shot
    // (so the AI evaluator can use it to filter legal targets).
    hidden function _refreshLowestPreShot() {
        lowestPreShot = -1;
        for (var b = 1; b < numBalls; b++) {
            if (bAlive[b]) { lowestPreShot = b; break; }
        }
    }

    // Finds nearest surviving target ball that the AI is allowed to hit.
    // Falls back to nearest live ball if no legal target exists (safety).
    hidden function _nearestTargetBall() {
        var nearB = -1; var nearD2 = 9999999.0;
        for (var b = 1; b < numBalls; b++) {
            if (!_isLegalTargetForAI(b)) { continue; }
            var dx = bx[b] - bx[0]; var dy = by[b] - by[0];
            var d2 = dx*dx + dy*dy;
            if (d2 < nearD2) { nearD2 = d2; nearB = b; }
        }
        if (nearB >= 0) { return nearB; }
        // Fallback: nearest alive ball
        for (var c = 1; c < numBalls; c++) {
            if (!bAlive[c]) { continue; }
            var ddx = bx[c] - bx[0]; var ddy = by[c] - by[0];
            var dd2 = ddx*ddx + ddy*ddy;
            if (dd2 < nearD2) { nearD2 = dd2; nearB = c; }
        }
        return nearB;
    }

    hidden function _aiThink() {
        _refreshLowestPreShot();
        var target = _nearestTargetBall();
        if (target < 0) { aiDelay = 5; aiAimAngle = 0.0; aiPower = 50; return; }

        var ang = 0.0; var pwr = 60;

        if (diff == DIFF_EASY) {
            var baseDx = bx[target] - bx[0]; var baseDy = by[target] - by[0];
            ang = Math.atan2(baseDy, baseDx) * 180.0 / Math.PI;
            ang += (Math.rand().abs() % 121 - 60).toFloat(); // ±60°
            pwr = 25 + Math.rand().abs() % 40;

        } else if (diff == DIFF_MED) {
            var baseDx2 = bx[target] - bx[0]; var baseDy2 = by[target] - by[0];
            ang = Math.atan2(baseDy2, baseDx2) * 180.0 / Math.PI;
            ang += (Math.rand().abs() % 41 - 20).toFloat(); // ±20°
            pwr = 48 + Math.rand().abs() % 28;

        } else {
            // HARD: search ALL alive balls × ALL pockets, pick best pocketing shot
            // with obstruction awareness and pocket-distance-aware power tuning.
            // Iterative; no recursion. Max 9 balls × 6 pockets = 54 candidates.
            var bestShot = _aiHardBestShot();
            ang = bestShot[0];
            // Tune power by required ball travel distance (pocket distance).
            // Far pocket → more power, near pocket → less. Range 45..82.
            var travel = bestShot[1];
            pwr = 48 + (travel / 12).toNumber();
            if (pwr < 50) { pwr = 50; }
            if (pwr > 82) { pwr = 82; }
        }

        if (ang < 0.0)    { ang += 360.0; }
        if (ang >= 360.0) { ang -= 360.0; }
        aiAimAngle = ang; aiPower = pwr;
        aiDelay = 28 + Math.rand().abs() % 18;
    }

    // HARD: evaluate every (alive ball, pocket) pair via ghost-ball geometry
    // with obstruction penalty. Returns [angle, ball-to-pocket distance].
    // Iterative — pure loops, no recursion.
    // Cost scales with numBalls: 9-ball ~54 evals, 8-ball ~90 evals.
    hidden function _aiHardBestShot() {
        var bestAng    = 0.0;
        var bestScore  = -1.0;
        var bestTravel = 200.0;
        var found      = false;
        var bd = BALL_D.toFloat();

        for (var t = 1; t < numBalls; t++) {
            // Only consider balls that are LEGAL targets for the AI (mode-aware).
            // This makes Hard 9-ball play "lowest first" and Hard 8-ball play
            // its own group without committing fouls.
            if (!_isLegalTargetForAI(t)) { continue; }
            for (var p = 0; p < NUM_POCKETS; p++) {
                var pdx = pX[p].toFloat() - bx[t];
                var pdy = pY[p].toFloat() - by[t];
                var pdist = Math.sqrt(pdx*pdx + pdy*pdy);
                if (pdist < 1.0) { continue; }
                var pnx = pdx / pdist; var pny = pdy / pdist;
                // Ghost-ball position behind target along pocket line.
                var gx = bx[t] - pnx * bd;
                var gy = by[t] - pny * bd;
                if (gx < WL || gx > WR || gy < WT || gy > WB) { continue; }
                var gdx = gx - bx[0]; var gdy = gy - by[0];
                var gdist2 = gdx*gdx + gdy*gdy;
                if (gdist2 < 1.0) { continue; }
                // Reject shots requiring a sharp cut > ~70° (cut angle = angle between
                // ball-to-pocket vector and cue-to-ball-vector). Very steep cuts are
                // unreliable.
                var cbdx = bx[t] - bx[0]; var cbdy = by[t] - by[0];
                var cblen = Math.sqrt(cbdx*cbdx + cbdy*cbdy);
                if (cblen < 1.0) { continue; }
                var dotCB = (cbdx * pnx + cbdy * pny) / cblen;
                if (dotCB < 0.35) { continue; }  // cut angle > ~70°
                // Score: prefer near shots & short ball→pocket distance.
                var score = 600.0 / (gdist2 + 100.0) + 250.0 / (pdist + 10.0);
                // Obstruction penalty: if any OTHER ball lies near the cue→ghost
                // line, reduce score significantly. Iterative O(MAX_BALLS).
                var ang = Math.atan2(gdy, gdx);
                var dxn = Math.cos(ang); var dyn = Math.sin(ang);
                var cgDist = Math.sqrt(gdist2);
                var obstructed = false;
                for (var o = 1; o < numBalls; o++) {
                    if (o == t || !bAlive[o]) { continue; }
                    var ox = bx[o] - bx[0]; var oy = by[o] - by[0];
                    var proj = ox * dxn + oy * dyn;
                    if (proj <= bd * 0.4 || proj >= cgDist - bd * 0.4) { continue; }
                    var perp2 = ox*ox + oy*oy - proj*proj;
                    if (perp2 < (bd * 0.95) * (bd * 0.95)) { obstructed = true; break; }
                }
                if (obstructed) { score = score * 0.15; }
                if (score > bestScore) {
                    bestScore  = score;
                    bestAng    = ang * 180.0 / Math.PI;
                    bestTravel = pdist;
                    found      = true;
                }
            }
        }
        if (!found) {
            // No clean shot — break aim at nearest ball.
            var nb = _nearestTargetBall();
            if (nb >= 0) {
                var fdx = bx[nb] - bx[0]; var fdy = by[nb] - by[0];
                bestAng = Math.atan2(fdy, fdx) * 180.0 / Math.PI;
                bestTravel = Math.sqrt(fdx*fdx + fdy*fdy);
            }
        }
        bestAng += (Math.rand().abs() % 5 - 2).toFloat(); // ±2° residual error
        return [bestAng, bestTravel];
    }

    // Kept for backward compatibility — single-target ghost-ball aim.
    hidden function _aiHardAngle(targetBall) {
        var bestAng  = 0.0; var bestScore = -1.0; var found = false;
        for (var p = 0; p < NUM_POCKETS; p++) {
            var pdx = pX[p].toFloat() - bx[targetBall];
            var pdy = pY[p].toFloat() - by[targetBall];
            var pdist = Math.sqrt(pdx*pdx + pdy*pdy);
            if (pdist < 1.0) { continue; }
            var pnx = pdx / pdist; var pny = pdy / pdist;
            var gx = bx[targetBall] - pnx * BALL_D.toFloat();
            var gy = by[targetBall] - pny * BALL_D.toFloat();
            if (gx < WL || gx > WR || gy < WT || gy > WB) { continue; }
            var gdx = gx - bx[0]; var gdy = gy - by[0];
            var gdist2 = gdx*gdx + gdy*gdy;
            if (gdist2 < 1.0) { continue; }
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
        bestAng += (Math.rand().abs() % 9 - 4).toFloat();
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
        for (var b = 1; b < numBalls; b++) {
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
