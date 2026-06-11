// ═══════════════════════════════════════════════════════════════
// GameController.mc — PixelInvaders game flow.
//
// States: PI_MENU → PI_PLAY → PI_WIN | PI_OVER → PI_MENU
//
// Chess-style menu (3 rows):
//   0  Difficulty (Easy / Normal / Hard)
//   1  Lives (1..5)
//   2  START
//
// Difficulty controls:
//   • starting `stepInterval` for the formation
//     Easy 14 / Normal 11 / Hard 8 ticks
//   • probability each tick that the formation fires (Easy 6 % /
//     Normal 10 % / Hard 16 %)
//
// Each wave the start `stepInterval` is reduced by 1 (cap at 5)
// and fire rate ticks up — classic SI escalation.
//
// Tick (80 ms, MainView):
//   1. Player glide.
//   2. Bullets travel.
//   3. Player bullets → enemies (collide + score).
//   4. Enemy bullets  → player (collide + lose life).
//   5. Formation march (every stepInterval ticks).
//   6. Enemy fire chance (random alive column).
//   7. Lose: any enemy in the player row.
//   8. Win: no enemies alive → next wave.
//
// Persistence:  pi_diff, pi_lives, pi_best
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Math;

const PI_MENU = 0;
const PI_PLAY = 1;
const PI_WIN  = 2;     // unused — endless waves, but kept for clarity
const PI_OVER = 3;

// Chess-style menu rows. Row 3 is the global LEADERBOARD (split by
// difficulty variant); it pushes a view from the View layer.
const PI_MENU_ROWS = 4;
const PI_ROW_DIFF  = 0;
const PI_ROW_LIVES = 1;
const PI_ROW_START = 2;
const PI_ROW_LB    = 3;

// Global leaderboard game id (matches _LOGOS / web id).
const PI_LB_GAME_ID = "pixelinvaders";

const PI_BEST_KEY  = "pi_best";
const PI_DIFF_KEY  = "pi_diff";
const PI_LIVES_KEY = "pi_lives";

const PI_DIFF_EASY   = 0;
const PI_DIFF_NORMAL = 1;
const PI_DIFF_HARD   = 2;

class GameController {
    var state;
    var menuRow;
    var menuDiff;
    var menuLives;

    var player;
    var bullets;
    var swarm;

    var wave;
    var lives;
    var score;
    var bestScore;

    function initialize() {
        state     = PI_MENU;
        menuRow   = 0;
        menuDiff  = PI_DIFF_NORMAL;
        menuLives = 3;

        player  = new Player();
        bullets = new ProjectileSystem();
        swarm   = new EnemyManager();

        wave = 1; lives = 3; score = 0; bestScore = 0;
        _loadAll();
    }

    // ── Persistence ─────────────────────────────────────────────
    hidden function _loadAll() {
        try {
            var b = Application.Storage.getValue(PI_BEST_KEY);
            if (b != null) { bestScore = b; }
        } catch (e) {}
        try {
            var d = Application.Storage.getValue(PI_DIFF_KEY);
            if (d instanceof Number && d >= 0 && d <= 2) { menuDiff = d; }
        } catch (e) {}
        try {
            var l = Application.Storage.getValue(PI_LIVES_KEY);
            if (l instanceof Number && l >= 1 && l <= 5) { menuLives = l; }
        } catch (e) {}
    }
    hidden function _saveBest() {
        try { Application.Storage.setValue(PI_BEST_KEY, bestScore); } catch (e) {}
    }
    hidden function _saveSettings() {
        try { Application.Storage.setValue(PI_DIFF_KEY,  menuDiff);  } catch (e) {}
        try { Application.Storage.setValue(PI_LIVES_KEY, menuLives); } catch (e) {}
    }

    // ── Menu ────────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % PI_MENU_ROWS; }
    function menuPrev() { menuRow = (menuRow + PI_MENU_ROWS - 1) % PI_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < PI_MENU_ROWS) { menuRow = i; } }
    function menuActivate() {
        if (menuRow == PI_ROW_DIFF) {
            menuDiff = (menuDiff + 1) % 3;
            _saveSettings();
        } else if (menuRow == PI_ROW_LIVES) {
            menuLives = (menuLives % 5) + 1;
            _saveSettings();
        } else if (menuRow == PI_ROW_START) {
            _startGame();
        }
        // PI_ROW_LB is handled by MainView.openLeaderboard().
    }

    function gotoMenu() { state = PI_MENU; }

    function difficultyName() {
        if (menuDiff == PI_DIFF_EASY)   { return "Easy";   }
        if (menuDiff == PI_DIFF_NORMAL) { return "Normal"; }
        return "Hard";
    }

    hidden function _baseInterval() {
        var iv;
        if      (menuDiff == PI_DIFF_EASY)   { iv = 14; }
        else if (menuDiff == PI_DIFF_NORMAL) { iv = 11; }
        else                                  { iv = 8;  }
        iv = iv - (wave - 1);
        if (iv < 5) { iv = 5; }
        return iv;
    }

    // Enemy fire chance per tick (in percent).
    hidden function _firePct() {
        var pct;
        if      (menuDiff == PI_DIFF_EASY)   { pct = 6;  }
        else if (menuDiff == PI_DIFF_NORMAL) { pct = 10; }
        else                                  { pct = 16; }
        pct = pct + (wave - 1) * 2;
        if (pct > 35) { pct = 35; }
        return pct;
    }

    // ── Lifecycle ───────────────────────────────────────────────
    hidden function _startGame() {
        wave  = 1;
        lives = menuLives;
        score = 0;
        _spawnWave();
        state = PI_PLAY;
    }

    hidden function _spawnWave() {
        player.spawn();
        bullets.reset();
        swarm.populate(wave, _baseInterval());
    }

    // ── Input intents ───────────────────────────────────────────
    function moveLeft()  { if (state == PI_PLAY) { player.nudge(-1); } }
    function moveRight() { if (state == PI_PLAY) { player.nudge( 1); } }
    function fire() {
        if (state != PI_PLAY) { return; }
        bullets.playerFire(player.col, PI_PLAYER_ROW);
    }

    // ── Tick (80 ms) ────────────────────────────────────────────
    function tick() {
        if (state != PI_PLAY) { return; }

        // 1. Player glide.
        player.tickGlide();

        // 2. Bullets advance.
        bullets.tick();

        // 3. Player bullets → enemies.
        var pts = CollisionSystem.playerBulletsVsEnemies(bullets.pShots,
                                                          swarm.enemies);
        if (pts > 0) { score = score + pts; }

        // 4. Enemy bullets → player.
        if (CollisionSystem.enemyBulletsVsPlayer(bullets.eShots, player)) {
            _onPlayerHit();
            return;
        }

        // 5. Formation march.
        swarm.tick();

        // 6. Enemy fire chance.
        if ((Math.rand() % 100) < _firePct()) {
            var p = swarm.lowestInRandomColumn();
            if (p != null) { bullets.enemyFire(p[0], p[1]); }
        }

        // 7. Lose: enemy reached player row (or below).
        if (swarm.lowestRow() >= PI_PLAYER_ROW) {
            _gameOver();
            return;
        }

        // 8. Wave clear?
        if (swarm.allDead()) {
            score = score + 100 + wave * 50;
            wave  = wave + 1;
            _spawnWave();
        }
    }

    hidden function _onPlayerHit() {
        lives = lives - 1;
        if (lives <= 0) { _gameOver(); return; }
        // Soft restart: respawn ship + clear bullets.  Formation
        // keeps marching (much more tense than a full reset).
        player.spawn();
        bullets.reset();
    }

    hidden function _gameOver() {
        state = PI_OVER;
        if (score > bestScore) { bestScore = score; _saveBest(); }
        // Submit to the global leaderboard, split by difficulty variant.
        Leaderboard.submitScore(PI_LB_GAME_ID, score, difficultyName());
    }
}
