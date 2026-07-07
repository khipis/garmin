using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;

// ── game states ───────────────────────────────────────────────────────────────
const GS_TITLE = 0;
const GS_RUN   = 1;
const GS_OVER  = 2;
const GS_DEMO  = 3;   // AI auto-plays on title screen ("arcy-intelligence")

// obstacle types
const OT_CACTUS = 0;
const OT_PTERO  = 1;

const OBS_MAX  = 4;
const CLD_MAX  = 3;
const STAR_MAX = 12;  // background stars during night phase
const COIN_MAX = 2;   // concurrent floating coins

// near-miss tolerance — obstacle clears within this many px of dino → +5 bonus
const NEAR_MISS_PX = 12;
const NEAR_MISS_BONUS = 5;

// Coins: base points + combo bonus per consecutive collect (capped), and a
// max combo tier so the numbers don't run away.
const COIN_BASE = 20;
const COIN_COMBO_STEP = 5;
const COIN_COMBO_CAP  = 8;

// Storage keys
const SK_BEST = "dinoBest";

// ── Global leaderboard ────────────────────────────────────────────────────────
// Shared library (../_shared/leaderboard) game id — matches the web id.
const LB_GAME_ID = "dinosaur";

// Title-screen menu rows: START (begin a run) + LEADERBOARD (push shared view).
const DINO_ROW_START = 0;
const DINO_ROW_LB    = 1;
const DINO_MENU_ROWS = 2;

// ─────────────────────────────────────────────────────────────────────────────
//  Phases
//  0 < 300  : single jump, ground only, slow
//  1 300–1499: double jump unlocked, ground only
//  2 ≥ 1500  : duck unlocked, pterodactyls appear
// ─────────────────────────────────────────────────────────────────────────────

class DinosaurView extends WatchUi.View {

    // ── timer / state ─────────────────────────────────────────────────────────
    hidden var _timer;
    hidden var _state;

    // ── layout ────────────────────────────────────────────────────────────────
    hidden var _sw;
    hidden var _sh;
    hidden var _grdY;    // ground top Y
    hidden var _dinoX;   // fixed dino left edge X
    hidden var _dw;      // dino bounding-box width
    hidden var _dh;      // dino bounding-box full height

    // ── dino physics ──────────────────────────────────────────────────────────
    hidden var _dy;          // dino top Y
    hidden var _vy;          // vertical velocity (+ = down)
    hidden var _onGrd;       // 1 when on ground
    hidden var _frame;       // animation counter
    hidden var _jumpsLeft;   // remaining mid-air jumps
    hidden var _crouching;   // 1 when crouching
    hidden var _crouchT;     // crouch auto-expire countdown

    // ── obstacles ─────────────────────────────────────────────────────────────
    hidden var _ox;     // left-edge X
    hidden var _ow;     // width
    hidden var _oh;     // height
    hidden var _oa;     // active: 1 / 0
    hidden var _ot;     // type: OT_CACTUS / OT_PTERO

    // ── clouds ────────────────────────────────────────────────────────────────
    hidden var _cx;
    hidden var _cy;
    hidden var _cw;

    // ── game counters ─────────────────────────────────────────────────────────
    hidden var _score;
    hidden var _hiScore;
    hidden var _spd;        // px / tick
    hidden var _spdSel;     // OPTIONS speed index: 0=NORMAL 1=FAST 2=INSANE
    hidden var _baseSpd;    // starting scroll speed derived from _spdSel
    hidden var _nextObs;    // ticks until next spawn
    hidden var _phase;      // 0 / 1 / 2
    hidden var _scrollX;    // ground-texture scroll accumulator

    // ── effects / notifications ───────────────────────────────────────────────
    hidden var _flash;       // new-best glow timer
    hidden var _notifyStr;   // phase-unlock message
    hidden var _notifyT;     // notify display countdown
    hidden var _sparkT;      // double-jump sparkle timer
    hidden var _sparkX;
    hidden var _sparkY;

    // ── smart-spawner memory & ambient theme ──────────────────────────────────
    hidden var _lastObsType;    // last spawned obstacle (for pattern fairness)
    hidden var _lastObsHeight;  // last spawned height (heuristic for next gap)
    hidden var _theme;          // 0=day (clouds), 1=night (stars)
    hidden var _starsX;
    hidden var _starsY;
    hidden var _starsR;

    // ── near-miss bonus tracking ──────────────────────────────────────────────
    // Per-obstacle flag: 0 = not yet processed, 1 = already credited / collided
    hidden var _obsScored;
    hidden var _missTxtT;       // floating "+5" display countdown
    hidden var _missTxtX;
    hidden var _missTxtY;

    // ── game-over feedback ────────────────────────────────────────────────────
    hidden var _shakeT;         // brief screen shake on death

    // ── coins / combo ─────────────────────────────────────────────────────────
    hidden var _coinX; hidden var _coinY; hidden var _coinA;
    hidden var _nextCoin;
    hidden var _comboCoins;     // consecutive coins collected without a miss
    hidden var _bestCombo;      // best combo reached this run
    hidden var _coinsTotal;     // total coins collected this run
    hidden var _coinSparkT; hidden var _coinSparkX; hidden var _coinSparkY;
    hidden var _coinTxtT; hidden var _coinTxtX; hidden var _coinTxtY; hidden var _coinTxtV;
    hidden var _comboFlashT;    // screen-edge flash timer on combo milestones

    // ── landing dust puff ─────────────────────────────────────────────────────
    hidden var _dustT; hidden var _dustX; hidden var _dustY;

    // ── AUTO-AI demo (title screen) ──────────────────────────────────────────
    hidden var _demoIdle;       // ticks player has been idle on title

    // ── title-screen menu selection (START / LEADERBOARD) ─────────────────────
    hidden var _menuSel;

    // ── init ──────────────────────────────────────────────────────────────────

    function initialize() {
        View.initialize();
        _state     = GS_TITLE;
        _timer     = null;
        _flash     = 0;
        _notifyStr = "";
        _notifyT   = 0;
        _sparkT    = 0;
        _sparkX    = 0;
        _sparkY    = 0;
        _theme     = 0;
        _lastObsType   = -1;
        _lastObsHeight = 0;
        _missTxtT  = 0;
        _missTxtX  = 0;
        _missTxtY  = 0;
        _shakeT    = 0;
        _demoIdle  = 0;
        _menuSel   = DINO_ROW_START;

        // Restore best score from storage so it survives app restarts.
        var stored = Application.Storage.getValue(SK_BEST);
        _hiScore = (stored != null) ? stored : 0;

        // Base run/scroll speed comes from the shared OPTIONS screen
        // (dino_spd: 0=NORMAL 1=FAST 2=INSANE). NORMAL keeps today's feel.
        _spdSel = 0;
        var sp = Application.Storage.getValue("dino_spd");
        if (sp instanceof Number && sp >= 0 && sp <= 2) { _spdSel = sp; }
        _baseSpd = [5, 7, 9][_spdSel];

        _ox = new [OBS_MAX]; _ow = new [OBS_MAX];
        _oh = new [OBS_MAX]; _oa = new [OBS_MAX]; _ot = new [OBS_MAX];
        _obsScored = new [OBS_MAX];
        for (var i = 0; i < OBS_MAX; i++) {
            _oa[i] = 0; _ot[i] = 0; _obsScored[i] = 0;
        }

        _cx = new [CLD_MAX]; _cy = new [CLD_MAX]; _cw = new [CLD_MAX];

        _starsX = new [STAR_MAX];
        _starsY = new [STAR_MAX];
        _starsR = new [STAR_MAX];
        for (var i = 0; i < STAR_MAX; i++) {
            _starsX[i] = 0; _starsY[i] = 0; _starsR[i] = 1;
        }

        _coinX = new [COIN_MAX]; _coinY = new [COIN_MAX]; _coinA = new [COIN_MAX];
        for (var i = 0; i < COIN_MAX; i++) { _coinA[i] = 0; }
        _nextCoin    = 60;
        _comboCoins  = 0; _bestCombo = 0; _coinsTotal = 0;
        _coinSparkT  = 0; _coinTxtT  = 0; _comboFlashT = 0;
        _dustT       = 0;
    }

    function onLayout(dc) {
        _sw   = dc.getWidth();
        _sh   = dc.getHeight();
        _grdY = _sh * 70 / 100;

        _dinoX = _sw * 17 / 100;
        _dw    = _sw * 7 / 100;
        if (_dw < 22) { _dw = 22; }
        _dh = _dw + _dw * 6 / 10;   // 1.6× wide → tall & chubby

        _cy[0] = _sh * 17 / 100; _cw[0] = 46;
        _cy[1] = _sh * 25 / 100; _cw[1] = 38;
        _cy[2] = _sh * 11 / 100; _cw[2] = 54;
        _cx[0] = _sw * 40 / 100;
        _cx[1] = _sw * 63 / 100;
        _cx[2] = _sw * 81 / 100;

        // Scatter background stars in the sky portion of the screen.
        // (only drawn during night theme to give the long-run progression
        //  some visual variety on AMOLED-friendly dark backgrounds).
        for (var i = 0; i < STAR_MAX; i++) {
            _starsX[i] = (Math.rand() & 0x7FFFFFFF) % _sw;
            _starsY[i] = (Math.rand() & 0x7FFFFFFF) % (_grdY - 8);
            _starsR[i] = ((Math.rand() & 0x7FFFFFFF) % 3 == 0) ? 2 : 1;
        }

        _resetGame();
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:gameTick), 33, true);
        // The main menu is the shared root view; drop straight into a run.
        // Only auto-start from the initial title state so returning from the
        // post-game leaderboard card doesn't restart the run.
        if (_state == GS_TITLE) { _resetGame(); _state = GS_RUN; }
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── timer callback ────────────────────────────────────────────────────────

    function gameTick() {
        // (AI attract-demo removed — the title screen now stays a static menu.)
        if (_state == GS_RUN) {
            _step();
        }

        if (_flash    > 0) { _flash    = _flash    - 1; }
        if (_notifyT  > 0) { _notifyT  = _notifyT  - 1; }
        if (_sparkT   > 0) { _sparkT   = _sparkT   - 1; }
        if (_missTxtT > 0) { _missTxtT = _missTxtT - 1; }
        if (_shakeT   > 0) { _shakeT   = _shakeT   - 1; }
        if (_coinSparkT  > 0) { _coinSparkT  = _coinSparkT  - 1; }
        if (_coinTxtT    > 0) { _coinTxtT    = _coinTxtT    - 1; }
        if (_comboFlashT > 0) { _comboFlashT = _comboFlashT - 1; }
        if (_dustT       > 0) { _dustT       = _dustT       - 1; }
        WatchUi.requestUpdate();
    }

    // ── public controls ───────────────────────────────────────────────────────

    // Public input handlers. Any input on TITLE/DEMO/OVER starts a fresh
    // player-controlled run; in-game inputs perform jump/crouch actions.
    function doJump() {
        if (_state == GS_TITLE || _state == GS_DEMO || _state == GS_OVER) {
            _resetGame();
            _state = GS_RUN;
            return;
        }
        _performJump();
    }

    function doCrouch() {
        if (_state == GS_TITLE || _state == GS_DEMO || _state == GS_OVER) {
            _resetGame();
            _state = GS_RUN;
            return;
        }
        _performCrouch();
    }

    // Core actions used by both player input and the auto-AI demo.
    // Bug fix: crouch→jump combo now fires the jump in a SINGLE press
    //          (old code only cancelled the crouch and returned).
    hidden function _performJump() {
        if (_crouching == 1 && _onGrd == 1) {
            _crouching = 0;
            _crouchT   = 0;
            _dy        = _grdY - _dh;   // snap to standing floor
            // fall through and execute jump on same input
        }
        if (_jumpsLeft > 0) {
            var dbl = (_onGrd == 0);
            _vy        = dbl ? -11 : -17;
            _onGrd     = 0;
            _jumpsLeft = _jumpsLeft - 1;
            if (dbl) {
                _sparkT = 14;
                _sparkX = _dinoX + _dw / 2;
                _sparkY = _dy + _dh / 4;
            }
        }
    }

    hidden function _performCrouch() {
        if (_onGrd == 1 && _phase >= 2) {
            _crouching = 1;
            _crouchT   = 42;
            _dy = _grdY - _dh * 55 / 100;
        } else if (_onGrd == 0) {
            // ground pound — slam down
            _crouching = 0;
            if (_vy < 12) { _vy = 12; }
        }
    }

    function doBack() {
        if (_state == GS_RUN) {
            // Persist the best score if the player bails out of a real run.
            if (_score > _hiScore) {
                _hiScore = _score; _flash = 70; _saveHiScore();
            }
            // Bailing still ends the run — submit the score to the leaderboard.
            Leaderboard.submitScore(LB_GAME_ID, _score, _lbVariant());
            if (_coinsTotal > 0) { Leaderboard.submitScore(LB_GAME_ID, _coinsTotal, "coins"); }
            if (_bestCombo  > 0) { Leaderboard.submitScore(LB_GAME_ID, _bestCombo, "combo"); }
            Leaderboard.showPostGame(LB_GAME_ID, _lbVariant(), "DINOSAUR");
            _state = GS_OVER;
            return true;
        }
        if (_state == GS_DEMO) {
            // Exiting the attract loop just returns to the title — never
            // counts as game over, never touches hi-score.
            _state = GS_TITLE;
            _demoIdle = 0;
            return true;
        }
        return false;
    }

    // Persist hi-score to storage so it survives app restart.
    hidden function _saveHiScore() {
        Application.Storage.setValue(SK_BEST, _hiScore);
    }

    // Leaderboard variant = base speed, so NORMAL/FAST/INSANE rank separately.
    hidden function _lbVariant() {
        return ["s0", "s1", "s2"][_spdSel];
    }

    // ── title-screen menu (START / LEADERBOARD) ───────────────────────────────
    function inTitle() { return _state == GS_TITLE; }

    function menuPrev() {
        _menuSel  = (_menuSel + DINO_MENU_ROWS - 1) % DINO_MENU_ROWS;
        _demoIdle = 0;
    }
    function menuNext() {
        _menuSel  = (_menuSel + 1) % DINO_MENU_ROWS;
        _demoIdle = 0;
    }
    function menuActivate() {
        if (_menuSel == DINO_ROW_LB) { openLeaderboard(); return; }
        _resetGame();
        _state = GS_RUN;
    }

    // Tap routing on the title screen — hit-test the rows so touch watches
    // can select START or LEADERBOARD directly.
    function handleTap(x, y) {
        var rg   = menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1]; var rowX = rg[2];
        var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < DINO_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                _menuSel  = i;
                _demoIdle = 0;
                menuActivate();
                return;
            }
        }
    }

    // Open the shared global leaderboard view for the chosen speed variant.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _lbVariant(), "DINOSAUR");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Geometry for the title menu. Space-aware: row height is derived from the
    // free space below the title block divided by the row count, then clamped
    // (~18% smaller than a full-size button) so nothing overlaps on small round
    // watches.  Returns [rowH, rowW, rowX, rowY0, gap].
    function menuRowGeom() {
        var topZone      = (_sh * 50) / 100;          // rows live below title/best
        var bottomMargin = (_sh * 9) / 100; if (bottomMargin < 14) { bottomMargin = 14; }
        var gap          = (_sh * 3) / 100; if (gap < 4) { gap = 4; }
        var avail        = (_sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (DINO_MENU_ROWS - 1)) / DINO_MENU_ROWS;
        if (rowH > 22) { rowH = 22; }                 // clamp max (~18% smaller)
        if (rowH < 14) { rowH = 14; }
        var rowW = (_sw * 52) / 100; if (rowW < 94) { rowW = 94; }
        var rowX = (_sw - rowW) / 2;
        var used = DINO_MENU_ROWS * rowH + (DINO_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // ── game logic ────────────────────────────────────────────────────────────

    hidden function _resetGame() {
        _dy        = _grdY - _dh;
        _vy        = 0;
        _onGrd     = 1;
        _frame     = 0;
        _score     = 0;
        _spd       = _baseSpd;
        _nextObs   = 90;   // generous gap before very first obstacle
        _phase     = 0;
        _jumpsLeft = 1;
        _crouching = 0;
        _crouchT   = 0;
        _scrollX   = 0;
        _notifyStr = "";
        _notifyT   = 0;
        _sparkT    = 0;   // clear any stale sparkle from previous run
        _sparkX    = 0;
        _sparkY    = 0;
        _flash     = 0;   // bug fix: stale NEW BEST! from previous round must clear
        _missTxtT  = 0;
        _shakeT    = 0;
        _theme     = 0;
        _lastObsType   = -1;
        _lastObsHeight = 0;
        for (var i = 0; i < OBS_MAX; i++) { _oa[i] = 0; _obsScored[i] = 0; }

        for (var i = 0; i < COIN_MAX; i++) { _coinA[i] = 0; }
        _nextCoin    = 60;
        _comboCoins  = 0; _bestCombo = 0; _coinsTotal = 0;
        _coinSparkT  = 0; _coinTxtT  = 0; _comboFlashT = 0;
        _dustT       = 0;
    }

    hidden function _step() {
        _frame   = _frame + 1;
        _scrollX = _scrollX + _spd;
        // Wrap at 3800 = LCM(10, 38)*10 so pebble offset (_scrollX/10)%38 is seamless.
        if (_scrollX >= 3800) { _scrollX = _scrollX - 3800; }

        // crouch timer
        if (_crouching == 1) {
            _crouchT = _crouchT - 1;
            if (_crouchT <= 0) { _crouching = 0; }
        }

        // gravity — skip when on ground to prevent 2-px oscillation each tick
        if (_onGrd == 0) { _vy = _vy + 2; }
        _dy = _dy + _vy;

        // ground contact — crouching compresses dino to 55 % height
        var floorDy = (_crouching == 1 && _vy >= 0) ? (_grdY - _dh * 55 / 100) : (_grdY - _dh);
        if (_dy >= floorDy) {
            _dy = floorDy;
            _vy = 0;
            if (_onGrd == 0) {
                // just landed — restore jumps + a little dust puff for feedback
                _jumpsLeft = (_phase >= 1) ? 2 : 1;
                _dustT = 10;
                _dustX = _dinoX + _dw / 2;
                _dustY = _grdY;
            }
            _onGrd = 1;
        }

        // phase progression
        var nPhase = 0;
        if      (_score >= 1500) { nPhase = 2; }
        else if (_score >= 300)  { nPhase = 1; }
        if (nPhase > _phase) {
            _phase = nPhase;
            // Suppress unlock toast during the AI demo (those messages are
            // for the player, not the spectated AI).
            if (_state == GS_RUN) {
                if (_phase == 1) { _notifyStr = "x2 JUMP!";  _notifyT = 110; }
                if (_phase == 2) { _notifyStr = "DUCK!  [v]"; _notifyT = 110; }
            }
        }

        // Day → Sunset → Night → Dawn cycle, ~15s per stage, so the backdrop
        // keeps shifting throughout a long run instead of just flipping
        // between two looks. Day/Sunset show clouds, Night/Dawn show stars.
        _theme = (_score / 450) % 4;

        // speed: base at start → ramps with score, hard cap to keep physics
        // stable. Base + cap both scale with the chosen OPTIONS speed so
        // FAST/INSANE feel noticeably quicker from the very first stride.
        _spd = _baseSpd + _score / 200;
        var cap = _baseSpd + 11;
        if (_spd > cap) { _spd = cap; }

        // move obstacles + bookkeep near-miss bonuses
        var dinoRight = _dinoX + _dw;
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            _ox[i] = _ox[i] - _spd;

            // Near-miss bonus: obstacle just cleared the dino (its right edge
            // passed the dino's left edge) without colliding earlier in the
            // collision check — award a small bonus once per obstacle.
            if (_obsScored[i] == 0) {
                var obsRight = _ox[i] + _ow[i];
                if (obsRight < _dinoX) {
                    _obsScored[i] = 1;
                    // Only credit during real play (not demo) to keep score honest.
                    if (_state == GS_RUN) {
                        _score = _score + NEAR_MISS_BONUS;
                        _missTxtT = 22;
                        _missTxtX = dinoRight;
                        _missTxtY = _dy - 4;
                    }
                }
            }

            if (_ox[i] + _ow[i] < 0) { _oa[i] = 0; _obsScored[i] = 0; }
        }

        // parallax clouds (slower) — only during Day/Sunset (theme 0/1)
        if (_theme == 0 || _theme == 1) {
            for (var i = 0; i < CLD_MAX; i++) {
                _cx[i] = _cx[i] - (_spd / 2 + 1);
                if (_cx[i] + _cw[i] < 0) { _cx[i] = _sw + 12; }
            }
        }

        // spawn
        _nextObs = _nextObs - 1;
        if (_nextObs <= 0) { _spawnObs(); }

        // coins — independent spawn timer + movement/collection/miss handling
        _nextCoin = _nextCoin - 1;
        if (_nextCoin <= 0) { _spawnCoin(); }
        _updateCoins();

        // collision
        if (_collide()) {
            // Only credit hi-score when the PLAYER (not the AI demo) crashes,
            // so spectating the demo can never inflate the saved best.
            var wasDemo = (_state == GS_DEMO);
            _state  = GS_OVER;
            _shakeT = 8;
            if (!wasDemo) {
                if (_score > _hiScore) {
                    _hiScore = _score;
                    _flash   = 70;
                    _saveHiScore();
                }
                // Submit the finished run to the global leaderboard (once).
                Leaderboard.submitScore(LB_GAME_ID, _score, _lbVariant());
                if (_coinsTotal > 0) { Leaderboard.submitScore(LB_GAME_ID, _coinsTotal, "coins"); }
                if (_bestCombo  > 0) { Leaderboard.submitScore(LB_GAME_ID, _bestCombo, "combo"); }
                Leaderboard.showPostGame(LB_GAME_ID, _lbVariant(), "DINOSAUR");
            }
            return;
        }

        _score = _score + 1;
    }

    // Smart spawner.
    //
    // Pattern-fairness rules (avoid "impossible" sequences at high speed):
    //   • If last obstacle was a pterodactyl, next is biased toward CACTUS so
    //     the player isn't forced to duck twice in quick succession.
    //   • If last cactus was tall, next gap is widened so the player has time
    //     to land before the next decision.
    //   • Minimum gap scales with current speed: reaction_frames * spd must
    //     fit inside the gap, otherwise even a perfect player can't react.
    hidden function _spawnObs() {
        var slot = -1;
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { slot = i; break; }
        }
        // If all slots were full, retry quickly instead of silently resetting.
        if (slot < 0) { _nextObs = 8; return; }

        // Pick obstacle type — biased away from repeated pteros.
        var isPtero = false;
        if (_phase >= 2) {
            var pteroChance = 35;
            if (_lastObsType == OT_PTERO) { pteroChance = 12; } // suppress repeat
            if ((Math.rand() & 0x7FFFFFFF) % 100 < pteroChance) { isPtero = true; }
        }

        if (isPtero) {
            _ot[slot] = OT_PTERO;
            _ow[slot] = _dw * 14 / 10;
            _oh[slot] = _dh * 50 / 100;
        } else {
            _ot[slot] = OT_CACTUS;
            // Phase 0: cap to t=0/1 (max 75% dino height) so the player can
            // realistically reach score 300 and unlock the double jump.
            var tMax = (_phase == 0) ? 2 : 3;
            var t    = (Math.rand() & 0x7FFFFFFF) % tMax;
            _ow[slot] = _dw * (8 + t * 2) / 10;
            _oh[slot] = _dh * (55 + t * 20) / 100;
        }
        _ox[slot] = _sw + 8;
        _oa[slot] = 1;
        _obsScored[slot] = 0;

        _lastObsType   = _ot[slot];
        _lastObsHeight = _oh[slot];

        // Base random gap (ticks).
        var gap = 72 + (Math.rand() & 0x7FFFFFFF) % 46 - (_spd - 5) * 4;
        if (_phase >= 2) { gap = gap - 6; }

        // Pattern-aware adjustments.
        if (_lastObsType == OT_PTERO) { gap = gap + 8; }
        if (_lastObsType == OT_CACTUS && _lastObsHeight > _dh * 70 / 100) {
            gap = gap + 6;
        }

        // Speed-aware minimum (player needs ~12 frames to react + jump arc).
        var minGap = 12 + _spd;
        if (_phase == 0 && minGap < 42) { minGap = 42; }
        if (gap < minGap) { gap = minGap; }

        _nextObs = gap;
    }

    // Floating coins — spawned on their own timer, independent of obstacles.
    // Picked at one of two jump-reachable heights so grabbing one always
    // requires a deliberate (but doable) jump. Skips the spawn if it would
    // land right on top of an active obstacle, so it never forces an
    // impossible double-demand on the player.
    hidden function _spawnCoin() {
        var slot = -1;
        for (var i = 0; i < COIN_MAX; i++) {
            if (_coinA[i] == 0) { slot = i; break; }
        }
        if (slot < 0) { _nextCoin = 20; return; }

        var spawnX = _sw + 10;
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            var d = _ox[i] - spawnX;
            if (d > -40 && d < 40) { _nextCoin = 10; return; }
        }

        var high = ((Math.rand() & 0x7FFFFFFF) % 2) == 0;
        _coinX[slot] = spawnX;
        _coinY[slot] = high ? (_grdY - _dh * 145 / 100) : (_grdY - _dh * 55 / 100);
        _coinA[slot] = 1;

        _nextCoin = 130 + (Math.rand() & 0x7FFFFFFF) % 90;
    }

    // Advance coins, collect on overlap with the dino, and break the combo
    // when a coin scrolls off-screen uncollected.
    hidden function _updateCoins() {
        var dx1 = _dinoX + 2;
        var dx2 = _dinoX + _dw - 2;
        var dh  = (_crouching == 1 && _onGrd == 1) ? (_dh * 55 / 100) : _dh;
        var dy1 = _dy;
        var dy2 = _dy + dh;

        for (var i = 0; i < COIN_MAX; i++) {
            if (_coinA[i] == 0) { continue; }
            _coinX[i] = _coinX[i] - _spd;

            if (_coinX[i] > dx1 - 8 && _coinX[i] < dx2 + 8 &&
                _coinY[i] > dy1 - 8 && _coinY[i] < dy2 + 8) {
                _collectCoin(i);
                continue;
            }
            if (_coinX[i] < -8) {
                _coinA[i] = 0;
                if (_comboCoins > 0) { _comboCoins = 0; }
            }
        }
    }

    hidden function _collectCoin(i) {
        _coinA[i] = 0;
        if (_state != GS_RUN) { return; }

        _comboCoins = _comboCoins + 1;
        if (_comboCoins > _bestCombo) { _bestCombo = _comboCoins; }
        _coinsTotal = _coinsTotal + 1;

        var step = _comboCoins - 1;
        if (step > COIN_COMBO_CAP) { step = COIN_COMBO_CAP; }
        var bonus = COIN_BASE + step * COIN_COMBO_STEP;
        _score = _score + bonus;

        _coinSparkT = 12; _coinSparkX = _coinX[i]; _coinSparkY = _coinY[i];
        _coinTxtT = 20; _coinTxtX = _coinX[i]; _coinTxtY = _coinY[i]; _coinTxtV = bonus;

        // Milestone flash every 3rd consecutive coin — a bright, eye-catching payoff.
        if (_comboCoins % 3 == 0) { _comboFlashT = 16; }
    }

    // Hitboxes are intentionally tighter than the rendered sprite so the
    // game feels fair: only the dino's torso (not the head/tail outlines)
    // and the obstacle's solid mass register hits.
    hidden function _collide() {
        var effH  = (_crouching == 1 && _onGrd == 1) ? (_dh * 55 / 100) : _dh;
        var dx1   = _dinoX + 4;
        var dx2   = _dinoX + _dw - 4;
        var dy1   = _dy + effH * 30 / 100;   // skip head silhouette
        var dy2   = _dy + effH - 3;
        // how high pterodactyls fly above ground
        var flyOff = _dh * 60 / 100;

        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            var ox1 = _ox[i] + 3;
            var ox2 = _ox[i] + _ow[i] - 3;
            var oy1;
            var oy2;
            if (_ot[i] == OT_PTERO) {
                // Inset pterodactyl hitbox slightly — wings shouldn't kill you.
                oy1 = _grdY - _oh[i] - flyOff + 2;
                oy2 = _grdY - flyOff - 2;
            } else {
                oy1 = _grdY - _oh[i];
                oy2 = _grdY;
            }
            if (dx2 > ox1 && dx1 < ox2 && dy2 > oy1 && dy1 < oy2) {
                // Mark this obstacle as resolved so the near-miss pass skips it.
                _obsScored[i] = 1;
                return true;
            }
        }
        return false;
    }

    // ── AUTO-AI demo controller ──────────────────────────────────────────────
    // A simple but solid reactive policy that plays the same physics the player
    // does. No lookahead / no recursion → constant per-tick cost.
    //
    // Decision algorithm:
    //   1. Find the nearest obstacle ahead of the dino.
    //   2. If it's a pterodactyl and we're on the ground, crouch when in range.
    //   3. If it's a cactus, jump just in time based on speed and obstacle
    //      height (tall cactus → jump a bit earlier).
    //   4. If we cleared the first jump too early, double-jump in mid-air as
    //      a safety net before reaching a tall cactus.
    hidden function _aiAutoPlay() {
        var nearestI    = -1;
        var nearestDist = 9999;
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            var d = _ox[i] - (_dinoX + _dw);
            if (d < -16) { continue; }
            if (d < nearestDist) { nearestDist = d; nearestI = i; }
        }
        if (nearestI < 0) { return; }

        var type = _ot[nearestI];
        var oh   = _oh[nearestI];

        if (type == OT_PTERO) {
            // Trigger the duck early enough that we're already low when it
            // arrives. Trigger window scales mildly with speed.
            var duckAt = 50 + _spd * 2;
            if (_onGrd == 1 && _crouching == 0 && nearestDist < duckAt) {
                _performCrouch();
            }
        } else {
            // Cactus — primary jump trigger.
            var jumpAt = 38 + _spd * 5;
            if (oh > _dh * 70 / 100) { jumpAt = jumpAt + 8; }   // taller → earlier
            if (_onGrd == 1 && nearestDist < jumpAt) {
                _performJump();
                return;
            }
            // Safety double-jump — if we're falling toward a still-uncleared
            // cactus and have a jump in reserve, use it.
            if (_onGrd == 0 && _vy > -3 && _jumpsLeft > 0 && nearestDist < 22) {
                _performJump();
            }
        }
    }

    // ── drawing ───────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        // Background cycles Day → Sunset → Night → Dawn for continuous
        // visual variety across a long run — each stage gets its own palette
        // and horizon glow instead of just flipping between two looks.
        var bg;
        if      (_theme == 0) { bg = 0x0d0d0d; }        // day
        else if (_theme == 1) { bg = 0x241208; }        // sunset
        else if (_theme == 2) { bg = 0x080810; }        // night
        else                  { bg = 0x160f1e; }        // dawn
        dc.setColor(bg, bg);
        dc.clear();

        // Never render an in-game menu — the shared menu is the root view.
        if (_state == GS_TITLE || _state == GS_DEMO) { _resetGame(); _state = GS_RUN; }

        if (_theme == 0 || _theme == 1) { _drawClouds(dc); }
        else                            { _drawStars(dc); }
        _drawHorizonGlow(dc);

        _drawGround(dc);
        _drawObstacles(dc);
        _drawCoins(dc);
        _drawDust(dc);
        _drawDino(dc);
        _drawSparkle(dc);
        _drawCoinSpark(dc);
        _drawNearMiss(dc);
        _drawComboFlash(dc);

        if (_state == GS_OVER) {
            _drawScore(dc);
            _drawOver(dc);
        } else {
            _drawScore(dc);
            _drawNotify(dc);
            _drawComboHud(dc);
        }
    }

    // Background stars (Night/Dawn). Twinkle by toggling brightness based on
    // index parity and frame counter — cheap to render, no allocations.
    hidden function _drawStars(dc) {
        var twinkle = (_frame / 12) & 1;
        var bright1 = (_theme == 3) ? 0x886688 : 0x666688;   // dawn tints violet
        var bright2 = (_theme == 3) ? 0x442a44 : 0x33334a;
        for (var i = 0; i < STAR_MAX; i++) {
            var bright = ((i + twinkle) & 1) == 0;
            dc.setColor(bright ? bright1 : bright2, Graphics.COLOR_TRANSPARENT);
            if (_starsR[i] >= 2) {
                dc.fillRectangle(_starsX[i], _starsY[i], 2, 2);
            } else {
                dc.fillRectangle(_starsX[i], _starsY[i], 1, 1);
            }
        }
    }

    // Soft horizon-band glow — a couple of stacked translucent-feeling bars
    // right above the ground line, tinted per biome. Cheap (2 rectangles) but
    // reads as real atmosphere and makes each biome transition pop.
    hidden function _drawHorizonGlow(dc) {
        var c1; var c2;
        if      (_theme == 1) { c1 = 0x2a1a10; c2 = 0x40200c; }  // sunset
        else if (_theme == 3) { c1 = 0x201530; c2 = 0x2c1a3c; }  // dawn
        else { return; }
        dc.setColor(c1, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _grdY - 26, _sw, 14);
        dc.setColor(c2, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _grdY - 12, _sw, 12);
    }

    // Floating "+5" pop-up shown on near-miss bonus.
    hidden function _drawNearMiss(dc) {
        if (_missTxtT <= 0) { return; }
        var lift = 22 - _missTxtT;             // text drifts upward
        dc.setColor(0xFFE066, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_missTxtX, _missTxtY - lift, Graphics.FONT_XTINY,
            "+" + NEAR_MISS_BONUS, Graphics.TEXT_JUSTIFY_LEFT);
    }

    hidden function _drawGround(dc) {
        dc.setColor(0x3c3c3c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _grdY, _sw, 2);
        // scrolling ground pebbles
        var off1 = (_scrollX / 10) % 38;
        var px   = -off1;
        var cnt  = 0;
        while (px < _sw && cnt < 16) {
            dc.setColor(0x282828, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px, _grdY + 4, 4, 1);
            dc.fillRectangle(px + 18, _grdY + 6, 2, 1);
            px = px + 38;
            cnt = cnt + 1;
        }
    }

    hidden function _drawClouds(dc) {
        // Sunset tints the clouds warm orange instead of neutral grey.
        dc.setColor((_theme == 1) ? 0x3a2214 : 0x1c1c1c, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < CLD_MAX; i++) {
            var cx = _cx[i];
            var cy = _cy[i];
            var cw = _cw[i];
            dc.fillRoundedRectangle(cx,          cy + 7,  cw,          9, 5);
            dc.fillRoundedRectangle(cx + cw/5,   cy,      cw * 6 / 10, 14, 7);
        }
        if (_theme == 1) {
            // Low sun disc peeking behind the cloud layer.
            dc.setColor(0x663311, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_sw * 78 / 100, _sh * 22 / 100, 16);
        }
    }

    // ── coins ─────────────────────────────────────────────────────────────────

    hidden function _drawCoins(dc) {
        var spin = (_frame / 3) % 4;      // cheap rotation illusion
        for (var i = 0; i < COIN_MAX; i++) {
            if (_coinA[i] == 0) { continue; }
            var cx = _coinX[i]; var cy = _coinY[i];
            var w = (spin == 0 || spin == 2) ? 7 : 4;
            dc.setColor(0xC98A1E, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - w/2 - 1, cy - 7, w + 2, 14, 3);
            dc.setColor(0xFFD54A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - w/2, cy - 6, w, 12, 3);
            dc.setColor(0xFFF0A8, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 1, cy - 4, 1, 8);
        }
    }

    // Golden burst + floating "+N" when a coin is collected.
    hidden function _drawCoinSpark(dc) {
        if (_coinSparkT > 0) {
            dc.setColor(0xFFD54A, Graphics.COLOR_TRANSPARENT);
            var r = 12 - _coinSparkT;
            var sx = _coinSparkX; var sy = _coinSparkY;
            dc.fillCircle(sx - r,     sy,         2);
            dc.fillCircle(sx + r,     sy,         2);
            dc.fillCircle(sx,         sy - r,     2);
            dc.fillCircle(sx,         sy + r,     2);
            dc.fillCircle(sx - r*7/10, sy - r*7/10, 2);
            dc.fillCircle(sx + r*7/10, sy - r*7/10, 2);
        }
        if (_coinTxtT > 0) {
            var lift = 20 - _coinTxtT;
            dc.setColor(0xFFD54A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_coinTxtX, _coinTxtY - lift, Graphics.FONT_XTINY,
                "+" + _coinTxtV, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Small expanding dust puff at the dino's feet on landing.
    hidden function _drawDust(dc) {
        if (_dustT <= 0) { return; }
        var r = (10 - _dustT) / 2 + 2;
        dc.setColor(0x3a3a3a, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_dustX - r * 2, _dustY, 2);
        dc.fillCircle(_dustX + r * 2, _dustY, 2);
        dc.fillCircle(_dustX - r,     _dustY - 2, 2);
        dc.fillCircle(_dustX + r,     _dustY - 2, 2);
    }

    // Bright pulsing border flash on every 3rd consecutive coin — a big,
    // eye-catching payoff for keeping a combo alive.
    hidden function _drawComboFlash(dc) {
        if (_comboFlashT <= 0) { return; }
        dc.setPenWidth(3);
        dc.setColor(0xFFD54A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(2, 2, _sw - 4, _sh - 4, _sw / 2);
        dc.setPenWidth(1);
    }

    // In-run combo counter — only shown once a combo of 2+ is active, grows
    // brighter/bolder the higher it climbs.
    hidden function _drawComboHud(dc) {
        if (_comboCoins < 2) { return; }
        var col = (_comboCoins >= 6) ? 0xFF6622 : (_comboCoins >= 3 ? 0xFFD54A : 0xCCAA55);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 4 / 100, Graphics.FONT_XTINY,
            "COMBO x" + _comboCoins, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── dino ──────────────────────────────────────────────────────────────────

    hidden function _drawDino(dc) {
        var x    = _dinoX;
        var dw   = _dw;
        var dead = (_state == GS_OVER);

        // when crouching the dino squishes — bottom stays at ground
        var dh   = (_crouching == 1 && _onGrd == 1) ? (_dh * 55 / 100) : _dh;
        // y = _dy: physics already places _dy at the correct top of the bounding box.
        // Old formula `_dy + (_dh - dh)` shifted drawing DOWN when crouching,
        // causing the body/legs to be drawn 10–15 px below the ground line.
        var y    = _dy;

        var cBody  = dead ? 0xBB3333 : 0xDDDDDD;
        var cDark  = dead ? 0x882222 : 0x999999;
        var cLight = dead ? 0xDD6666 : 0xEEEEEE;

        // ── tail ──────────────────────────────────────────────────────────────
        dc.setColor(cDark, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - dw*14/100, y + dh*38/100,
                                dw*22/100, dh*13/100, 2);

        // ── body (chubby) ─────────────────────────────────────────────────────
        dc.setColor(cBody, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y + dh*28/100, dw*82/100, dh*62/100, 5);

        // ── belly highlight ───────────────────────────────────────────────────
        dc.setColor(cLight, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + dw*10/100, y + dh*40/100,
                                dw*50/100, dh*38/100, 4);

        // ── head (big round) ──────────────────────────────────────────────────
        dc.setColor(cBody, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + dw*26/100, y, dw*74/100, dh*50/100, 7);

        // ── snout ─────────────────────────────────────────────────────────────
        dc.fillRoundedRectangle(x + dw*82/100, y + dh*26/100,
                                dw*22/100, dh*17/100, 3);

        // ── tiny hilarious arm ────────────────────────────────────────────────
        dc.setColor(cDark, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + dw*56/100, y + dh*50/100,
                                dw*16/100, dh*7/100, 2);
        dc.fillRectangle(x + dw*68/100, y + dh*54/100, 2, 3);
        dc.fillRectangle(x + dw*72/100, y + dh*54/100, 2, 3);

        // ── eye ───────────────────────────────────────────────────────────────
        var eyeX = x + dw*56/100;
        var eyeY = y + dh*14/100;

        if (dead) {
            // X eyes
            dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(eyeX - 4, eyeY - 4, eyeX + 5, eyeY + 5);
            dc.drawLine(eyeX + 5, eyeY - 4, eyeX - 4, eyeY + 5);
            dc.drawLine(eyeX - 3, eyeY - 4, eyeX + 5, eyeY + 4);
            dc.drawLine(eyeX + 4, eyeY - 4, eyeX - 4, eyeY + 4);
        } else if (_crouching == 1 && _onGrd == 1) {
            // squinting determined eyes (only when crouching ON GROUND)
            dc.setColor(cLight, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(eyeX - 4, eyeY - 2, 10, 6, 2);
            dc.setColor(0x0d0d0d, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(eyeX - 1, eyeY - 1, 6, 4, 1);
            // angry brow
            dc.setColor(cDark, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(eyeX - 3, eyeY - 5, eyeX + 5, eyeY - 4);
        } else {
            // normal big cute eye — surprised when jumping up
            var eyeR = (_onGrd == 0 && _vy < 0) ? 6 : 5;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(eyeX, eyeY, eyeR);
            var pShift = (_onGrd == 0 && _vy < 0) ? -1 : 1;
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(eyeX + 1, eyeY + pShift, 3);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(eyeX - 1, eyeY + pShift - 2, 1);
        }

        // ── mouth / expression ────────────────────────────────────────────────
        var mX = x + dw*90/100;
        var mY = y + dh*34/100;

        if (dead) {
            // tongue out
            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(mX - 1, mY, 5, 5, 2);
            dc.fillRoundedRectangle(mX - 2, mY + 4, 7, 4, 2);
        } else if (_onGrd == 0 && _vy < 0) {
            // jumping: surprised O mouth
            dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mX + 1, mY + 2, 2);
        } else if (_crouching == 1 && _onGrd == 1) {
            // determined flat mouth (only when crouching ON GROUND)
            dc.setColor(cDark, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(mX - 2, mY + 2, 6, 2);
        }

        // ── sweat drop when obstacle dangerously close ────────────────────────
        // Bug fix: previously drawn over the back/tail at dw*18 — now it
        // hovers above the dino's HEAD (where a sweat drop belongs).
        if ((_state == GS_RUN || _state == GS_DEMO) && _onGrd == 1) {
            var closest = _sw;
            for (var i = 0; i < OBS_MAX; i++) {
                if (_oa[i] == 0) { continue; }
                var dist = _ox[i] - (_dinoX + _dw);
                if (dist >= 0 && dist < closest) { closest = dist; }
            }
            if (closest < 44) {
                dc.setColor(0x3399DD, Graphics.COLOR_TRANSPARENT);
                var swX = x + dw*72/100;
                var swY = y - 3;
                dc.fillCircle(swX, swY, 3);
                dc.fillRoundedRectangle(swX - 2, swY - 8, 4, 8, 1);
            }
        }

        // ── legs ──────────────────────────────────────────────────────────────
        dc.setColor(cDark, Graphics.COLOR_TRANSPARENT);
        var lg = (_frame / 4) % 2;
        if (_onGrd == 0) {
            // airborne — tucked
            dc.fillRoundedRectangle(x + dw*26/100, y + dh*80/100, dw*18/100, dh*11/100, 2);
            dc.fillRoundedRectangle(x + dw*52/100, y + dh*80/100, dw*18/100, dh*11/100, 2);
        } else if (_crouching == 1) {
            // crouching — wide stubby
            dc.fillRoundedRectangle(x + dw*12/100, y + dh*86/100, dw*24/100, dh*12/100, 2);
            dc.fillRoundedRectangle(x + dw*44/100, y + dh*86/100, dw*24/100, dh*12/100, 2);
        } else if (lg == 0) {
            dc.fillRoundedRectangle(x + dw*26/100, y + dh*78/100, dw*18/100, dh*22/100, 2);
            dc.fillRoundedRectangle(x + dw*52/100, y + dh*83/100, dw*18/100, dh*15/100, 2);
        } else {
            dc.fillRoundedRectangle(x + dw*26/100, y + dh*83/100, dw*18/100, dh*15/100, 2);
            dc.fillRoundedRectangle(x + dw*52/100, y + dh*78/100, dw*18/100, dh*22/100, 2);
        }
    }

    // ── sparkle on double jump ────────────────────────────────────────────────

    hidden function _drawSparkle(dc) {
        if (_sparkT <= 0) { return; }
        dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
        var r = _sparkT / 2 + 2;
        var sx = _sparkX;
        var sy = _sparkY;
        dc.fillCircle(sx - r,     sy,         2);
        dc.fillCircle(sx + r,     sy,         2);
        dc.fillCircle(sx,         sy - r,     2);
        dc.fillCircle(sx - r / 2, sy - r / 2, 2);
        dc.fillCircle(sx + r / 2, sy - r / 2, 2);
    }

    // ── obstacles ─────────────────────────────────────────────────────────────

    hidden function _drawObstacles(dc) {
        var flyOff = _dh * 60 / 100;
        for (var i = 0; i < OBS_MAX; i++) {
            if (_oa[i] == 0) { continue; }
            if (_ot[i] == OT_PTERO) {
                _drawPtero(dc, _ox[i], _ow[i], _oh[i], flyOff);
            } else {
                _drawCactus(dc, _ox[i], _ow[i], _oh[i]);
            }
        }
    }

    hidden function _drawCactus(dc, ox, ow, oh) {
        var oy = _grdY - oh;
        dc.setColor(0x30B348, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(ox + ow / 4, oy, ow / 2, oh, 2);
        // tip spine
        dc.fillRoundedRectangle(ox + ow/4 - 1, oy - 3, ow/2 + 2, 5, 1);
        if (oh > _dh * 6 / 10) {
            dc.setColor(0x26883A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(ox, oy + oh/4, ow * 30/100, oh * 18/100, 2);
            dc.fillRoundedRectangle(ox + ow * 7/10, oy + oh*36/100, ow * 30/100, oh * 18/100, 2);
            // arm spine tips
            dc.setColor(0x30B348, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(ox - 1, oy + oh/4 - 2, ow * 30/100 + 2, 4, 1);
            dc.fillRoundedRectangle(ox + ow * 7/10 - 1, oy + oh*36/100 - 2, ow * 30/100 + 2, 4, 1);
        }
    }

    hidden function _drawPtero(dc, ox, ow, oh, flyOff) {
        var cx2 = ox + ow / 2;
        var cy2 = _grdY - flyOff - oh / 2;
        var ws  = ow / 2;
        // wing flap based on frame
        var flap = (_frame / 6) % 2;
        var wingDip = flap == 0 ? (-oh / 3) : (oh / 5);

        dc.setColor(0xAA44BB, Graphics.COLOR_TRANSPARENT);
        // left wing
        var lpts = [[cx2, cy2 + 2], [cx2 - ws, cy2 + wingDip], [cx2 - ws/2, cy2 + oh/2]];
        dc.fillPolygon(lpts);
        // right wing
        var rpts = [[cx2, cy2 + 2], [cx2 + ws, cy2 + wingDip], [cx2 + ws/2, cy2 + oh/2]];
        dc.fillPolygon(rpts);
        // body
        dc.setColor(0xCC55DD, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx2 - oh/4, cy2 - oh/4, oh/2, oh/2, 3);
        // beak
        dc.setColor(0xAA44BB, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx2 + oh/4, cy2 - oh/4, oh*4/10, oh/5, 2);
        // tiny eye
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx2 + oh/6, cy2 - oh/8, 2);
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx2 + oh/6 + 1, cy2 - oh/8, 1);
    }

    // ── HUD ───────────────────────────────────────────────────────────────────

    hidden function _drawScore(dc) {
        // On a round watch the usable width at y≈12 % is ~234 px wide (radius 180).
        // Centering at x=73 % keeps the text well inside the bezel.
        var sx = _sw * 73 / 100;
        // score colour shifts grey → red as speed increases
        var spd10 = _spd - 5;
        if (spd10 < 0) { spd10 = 0; }
        var r = 96 + spd10 * 12;
        var g = 96 - spd10 * 5;
        if (r > 220) { r = 220; }
        if (g < 28)  { g = 28; }
        dc.setColor(r * 65536 + g * 256 + 28, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx, _sh * 13 / 100, Graphics.FONT_XTINY,
            _score.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        if (_hiScore > 0) {
            dc.setColor(0x3a3a3a, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx, _sh * 21 / 100, Graphics.FONT_XTINY,
                "HI " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drawNotify(dc) {
        if (_notifyT <= 0) { return; }
        var col = (_notifyT > 30) ? 0x44FF88 : 0x1A6635;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 9 / 100, Graphics.FONT_XTINY,
            _notifyStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawTitle(dc) {
        var cx = _sw / 2;
        dc.setColor(0x30B348, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 19 / 100, Graphics.FONT_MEDIUM,
            "DINO RUN", Graphics.TEXT_JUSTIFY_CENTER);

        if (_state == GS_DEMO) {
            // Attract loop — keep the AI-demo overlay & control hints; no menu.
            var on = (_frame / 14) % 2 == 0;
            dc.setColor(on ? 0xFF9933 : 0x553311, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh * 33 / 100, Graphics.FONT_XTINY,
                "AUTO-AI DEMO", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x4a4a4a, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh * 41 / 100, Graphics.FONT_XTINY,
                "any key = jump", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, _sh * 49 / 100, Graphics.FONT_XTINY,
                "DOWN = duck (lv3)", Graphics.TEXT_JUSTIFY_CENTER);
            if (_hiScore > 0) {
                dc.setColor(0x363636, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, _sh * 58 / 100, Graphics.FONT_XTINY,
                    "best " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
            }
            return;
        }

        // TITLE: best score, then the START / LEADERBOARD menu.
        if (_hiScore > 0) {
            dc.setColor(0x363636, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh * 35 / 100, Graphics.FONT_XTINY,
                "best " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x4a4a4a, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 42 / 100, Graphics.FONT_XTINY,
            "UP/DN  tap = act", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1]; var rowX = rg[2];
        var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < DINO_MENU_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _menuSel);

            if (i == DINO_ROW_LB) {
                // Gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            // START row.
            var bg; var bd; var fg;
            if (sel) { bg = 0x1A4400; bd = 0x44BB22; fg = 0xAAFF66; }
            else     { bg = 0x102010; bd = 0x224422; fg = 0x88AA88; }
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(bd, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                "START", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drawOver(dc) {
        var lines = [ [_score.format("%05d"), 0x888888] ];
        if (_flash > 0) {
            lines.add(["NEW BEST!", 0xFFCC00]);
        } else {
            lines.add(["best " + _hiScore.format("%05d"), 0x444444]);
        }
        if (_coinsTotal > 0 || _bestCombo > 0) {
            lines.add(["coins " + _coinsTotal + " · combo x" + _bestCombo, 0xFFD54A]);
        }
        if (_phase == 0) {
            lines.add(["reach 300 for x2 jump!", 0x30B348]);
        } else if (_phase == 1) {
            lines.add(["reach 1500 for duck!", 0x4488CC]);
        }
        GameOverCard.draw(dc, _sw, _sh, "GAME OVER", 0xCC3333, lines, "", 0x2c2c2c);
    }
}
