// ═══════════════════════════════════════════════════════════════
// PlatformManager.mc — All platforms + collision + recycling.
//
// World model
//   The player's world-y grows upward. Platforms live in the same
//   space. The view's "camera floor" rises with the player, and any
//   platform that falls below the floor is recycled to the top with
//   a fresh y and (possibly) a different type. This avoids any
//   per-frame allocation during play.
//
// Platform types (id)
//   0 NORMAL    — solid, stable
//   1 MOVING    — slides horizontally with bounce off bounds
//   2 BREAKABLE — vanishes after first bounce
//   3 SPRING    — launches the player with a stronger jump (1.5×)
//   4 JETPACK   — grants a few seconds of flight straight through
//                 everything above (rare; only past the early
//                 tutorial difficulty bucket)
//
// Collision rule
//   Bounce only when the player is FALLING (vy >= 0) and the player's
//   feet are between the platform top and platform top + 6 px on the
//   tick that crosses the boundary. This matches Doodle Jump's feel
//   — the frog passes UP through platforms but lands on them when
//   coming back down.
//
// Coins
//   Each platform slot optionally carries ONE floating coin, parked
//   roughly at the apex of the jump arc leading up to it so it's
//   naturally in the player's path without any extra steering.
//   Collection uses the same swept-crossing idea as the platform
//   bounce test, checked independently of the falling/rising gate so
//   coins can be grabbed on the way up (the common case) as well as
//   the way down.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const MAX_PLATFORMS = 12;

const PT_NORMAL    = 0;
const PT_MOVING    = 1;
const PT_BREAKABLE = 2;
const PT_SPRING    = 3;
const PT_JETPACK   = 4;

class Platform {
    var x;         // left edge
    var y;         // world-y of top
    var w;
    var type;
    var alive;
    var vx;        // for moving platforms

    // Coin — floats above this platform; independent alive flag so it
    // can be collected without touching the platform itself.
    var coinAlive;
    var coinX;
    var coinY;

    function initialize() {
        x = 0; y = 0; w = 50; type = PT_NORMAL; alive = false; vx = 0.0;
        coinAlive = false; coinX = 0; coinY = 0;
    }
}

class PlatformManager {
    var plats;
    var screenW;
    var worldMinX;
    var worldMaxX;
    var platW;
    var platH;
    var verticalGap;   // average vertical spacing between platforms
    var coinR;         // coin collision/render radius

    function initialize() {
        plats = new [MAX_PLATFORMS];
        for (var i = 0; i < MAX_PLATFORMS; i++) { plats[i] = new Platform(); }
        screenW   = 240;
        worldMinX = 2; worldMaxX = 238;
        platW     = 50;
        platH     = 6;
        verticalGap = 42;
        coinR     = 5;
    }

    function setBounds(w, pW, pH, gap) {
        screenW   = w;
        worldMinX = 2;
        worldMaxX = w - 2;
        platW     = pW;
        platH     = pH;
        verticalGap = gap;
        coinR     = pH; if (coinR < 4) { coinR = 4; }
    }

    function reset() {
        for (var i = 0; i < MAX_PLATFORMS; i++) {
            plats[i].alive     = false;
            plats[i].coinAlive = false;
        }
    }

    // Spawn the initial ladder of platforms starting from a known
    // foundation y. Each subsequent platform is spawned ABOVE the
    // previous one (smaller screen-y) so the player has a tower to
    // climb. Returns the y of the highest spawned platform.
    function seed(baseY, difficulty) {
        var y = baseY;
        for (var i = 0; i < MAX_PLATFORMS; i++) {
            var p = plats[i];
            if (i == 0) {
                // Foundation platform — always normal & wide & centred.
                p.x = (worldMinX + worldMaxX) / 2 - platW / 2;
                p.y = y;
                p.w = platW;
                p.type = PT_NORMAL;
                p.alive = true;
                p.vx = 0.0;
                p.coinAlive = false;
            } else {
                _spawnAt(p, y, difficulty);
                // First few rungs are always NORMAL so the player has
                // a guaranteed early climb; difficulty kicks in after.
                if (i < 3) { p.type = PT_NORMAL; p.vx = 0.0; }
            }
            // Move UP one rung — screen-y decreases.
            y = y - verticalGap;
        }
        return y + verticalGap;
    }

    // Per-tick: move the moving-type platforms and bounce off bounds.
    function step() {
        for (var i = 0; i < MAX_PLATFORMS; i++) {
            var p = plats[i];
            if (!p.alive) { continue; }
            if (p.type == PT_MOVING) {
                p.x = p.x + p.vx;
                if (p.x < worldMinX) { p.x = worldMinX; p.vx = -p.vx; }
                if (p.x + p.w > worldMaxX) { p.x = worldMaxX - p.w; p.vx = -p.vx; }
            }
        }
    }

    // Collision: returns [hitType, platformTopY].
    //   hitType: 0 = no bounce, 1 = normal bounce, 2 = spring, 3 = jetpack.
    //   platformTopY: the y of the platform that was hit (used by
    //                 GameController to snap the player's feet so
    //                 the next tick starts cleanly above the rail).
    // Mutates breakable platforms (kills them after one bounce).
    // playerFeetPrev = player's feet y BEFORE this tick (used to ensure
    // we crossed the boundary downward — avoids snagging on rising frame).
    //
    // ── Tunneling fix ──────────────────────────────────────────────
    // The original test also required `playerFeet <= p.y + 8`, i.e.
    // the feet could only penetrate the platform by 8 px in one tick.
    // But `Physics.MAX_FALL_VY` is scaled per screen height, so on a
    // 416–448 px Garmin (s ≈ 1.87) terminal fall is ≈ 20 px/tick.
    // At terminal speed the feet routinely jump from `p.y − 4` to
    // `p.y + 16` in a single tick — the swept line clearly crosses
    // the platform, but the 8 px window rejected it and the frog
    // tunneled straight through.  The bracket has been removed:
    // `feetPrev <= p.y && feet >= p.y` alone is the correct swept
    // crossing test, and "already past this platform" cases are
    // already rejected because feetPrev becomes > p.y after passing.
    function tryBounce(playerLeft, playerRight, playerFeetPrev, playerFeet, falling) {
        if (!falling) { return [0, 0]; }
        // Iterate platforms; if the swept feet trajectory crosses any
        // platform top, pick the HIGHEST (smallest y) such platform so
        // that two stacked platforms can't both register a bounce on
        // the same tick.
        var bestY    = 0;
        var bestType = -1;
        var bestIdx  = -1;
        var found    = false;
        for (var i = 0; i < MAX_PLATFORMS; i++) {
            var p = plats[i];
            if (!p.alive) { continue; }
            if (p.x > playerRight || p.x + p.w < playerLeft) { continue; }
            if (playerFeetPrev <= p.y && playerFeet >= p.y) {
                if (!found || p.y < bestY) {
                    bestY    = p.y;
                    bestType = p.type;
                    bestIdx  = i;
                    found    = true;
                }
            }
        }
        if (!found) { return [0, 0]; }
        // Apply the consequences for the chosen platform.
        if (bestType == PT_BREAKABLE) {
            plats[bestIdx].alive = false;
            return [1, bestY];
        }
        if (bestType == PT_SPRING) {
            return [2, bestY];
        }
        if (bestType == PT_JETPACK) {
            return [3, bestY];
        }
        return [1, bestY];
    }

    // Coin collection — independent of the falling/rising gate so
    // coins are grabbable on the way up (the usual case, right at the
    // peak of a jump) as well as the way down. Swept against the
    // player's previous/current feet-y so fast ticks don't skip a
    // coin sitting between two frames. Returns the number collected
    // this tick (0 or 1 in virtually every real case).
    function collectCoins(playerLeft, playerRight, playerYPrev, playerYNow) {
        var lo = playerYPrev; var hi = playerYNow;
        if (lo > hi) { var t = lo; lo = hi; hi = t; }
        lo = lo - coinR; hi = hi + coinR;
        var got = 0;
        for (var i = 0; i < MAX_PLATFORMS; i++) {
            var p = plats[i];
            if (!p.alive || !p.coinAlive) { continue; }
            if (p.coinX + coinR < playerLeft || p.coinX - coinR > playerRight) { continue; }
            if (p.coinY >= lo && p.coinY <= hi) {
                p.coinAlive = false;
                got = got + 1;
            }
        }
        return got;
    }

    // Called by GameController when the camera scrolls upward — apply the
    // same delta to every platform's y so the world stays consistent with
    // the player's screen position. Then recycle any platform that fell
    // below the camera floor.
    function applyScroll(dy, topRecycleY, difficulty) {
        for (var i = 0; i < MAX_PLATFORMS; i++) {
            var p = plats[i];
            p.y = p.y + dy;
            // Recycle when far below the screen.
            if (p.y > topRecycleY) {
                _spawnAt(p, _highestY() - verticalGap, difficulty);
            }
        }
    }

    hidden function _highestY() {
        var y = 0; var first = true;
        for (var i = 0; i < MAX_PLATFORMS; i++) {
            var p = plats[i];
            if (!p.alive) { continue; }
            if (first || p.y < y) { y = p.y; first = false; }
        }
        return y;
    }

    // Spawn / recycle a platform at world-y. Type is biased by difficulty
    // (higher difficulty → more breakables and moving platforms).
    hidden function _spawnAt(p, y, difficulty) {
        var span = worldMaxX - worldMinX - platW;
        if (span < 4) { span = 4; }
        p.x     = worldMinX + (Math.rand() % span);
        p.y     = y;
        p.w     = platW;
        p.alive = true;
        p.vx    = 0.0;

        // Difficulty bucket: 0..10. Higher = more dangerous mix.
        var d   = difficulty;
        var r   = Math.rand() % 100;
        if (d <= 1) {
            // Easy: 90% normal, 10% spring (bonus)
            if (r < 90) { p.type = PT_NORMAL; }
            else        { p.type = PT_SPRING; }
        } else {
            // breakableChance grows ~3% per difficulty step (cap 30)
            var brk = 3 + d * 3;   if (brk > 30) { brk = 30; }
            var mov = 5 + d * 4;   if (mov > 35) { mov = 35; }
            var spr = 5;
            // Jetpack — rare treat, gated off the easy bucket so new
            // players see the core bounce loop before flight shows up.
            var jet = (d >= 3) ? 3 : 0;
            if (r < jet) {
                p.type = PT_JETPACK;
            } else if (r < jet + spr) {
                p.type = PT_SPRING;
            } else if (r < jet + spr + brk) {
                p.type = PT_BREAKABLE;
            } else if (r < jet + spr + brk + mov) {
                p.type = PT_MOVING;
                p.vx   = ((Math.rand() % 2 == 0) ? -1 : 1) * (1.0 + d * 0.1);
                if (p.vx >  2.4) { p.vx =  2.4; }
                if (p.vx < -2.4) { p.vx = -2.4; }
            } else {
                p.type = PT_NORMAL;
            }
        }

        // Coin — floats near the apex of the jump arc leading up to
        // this platform (roughly half the vertical gap above it), so
        // grabbing it is a natural side-effect of the climb rather
        // than a detour. ~38% of rungs carry one.
        if ((Math.rand() % 100) < 38) {
            p.coinAlive = true;
            var cSpan = p.w - coinR * 2; if (cSpan < 2) { cSpan = 2; }
            p.coinX = p.x + coinR + (Math.rand() % cSpan);
            p.coinY = p.y - (verticalGap / 2);
        } else {
            p.coinAlive = false;
        }
    }
}
