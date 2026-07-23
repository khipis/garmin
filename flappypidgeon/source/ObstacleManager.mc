// ═══════════════════════════════════════════════════════════════
// ObstacleManager.mc — Pipe pairs: spawn, scroll, score, collide.
//
// Each pipe is a vertical pair (top + bottom) with a gap in the
// middle. The manager keeps a small list (max 4 on screen at any
// time), recycling them as they leave the left edge.
//
// Performance notes
//   • Pipes are POD — just (x, gapTopY, gapBotY, scored). No allocation
//     happens during gameplay after the initial preallocation.
//   • Collision is an AABB-vs-AABB test that checks only the pipes
//     within the bird's x range (typically 0–2 pipes per tick).
//
// Difficulty grows with score:
//   • Gap shrinks 1.2 px per +5 score, floored at GAP_MIN.
//   • Scroll speed grows 0.04 px/tick per point, capped at MAX_SCROLL.
//   • Horizontal spacing between pipes shrinks slightly so the bird
//     gets less recovery time between gaps.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const MAX_PIPES = 4;

class Pipe {
    var x;
    var w;
    var gapTopY;    // bottom of the top pipe (y of gap top)
    var gapBotY;    // top of the bottom pipe (y of gap bottom)
    var scored;     // 1 once the bird has passed this pipe

    function initialize() {
        x = 0; w = 18; gapTopY = 0; gapBotY = 0; scored = 0;
    }
}

class ObstacleManager {
    var pipes;
    var screenW;
    var ceilY;          // top of playable area
    var floorY;         // bottom of playable area
    var pipeWidth;
    var spawnX;         // x to (re)spawn newly-recycled pipes at
    var spacing;        // horizontal distance between pipe centers
    // Gap size bias (px on the 240 reference), set from the OPTIONS "Gap"
    // setting: WIDE = +, NORMAL = 0 (default feel), TIGHT = -.
    var gapBias;

    // Near-miss telemetry — set during step() on the tick a pipe is scored
    // if the bird squeezed through with tight clearance. The controller
    // reads these to award a small bonus + spawn a spark. Reset each step.
    var nearMiss;     // 1 when the just-scored pass was a tight squeeze
    var nearMissY;    // bird y at that moment (for the spark origin)

    function initialize() {
        pipes = new [MAX_PIPES];
        for (var i = 0; i < MAX_PIPES; i++) { pipes[i] = new Pipe(); }
        screenW   = 240;
        ceilY     = 0;
        floorY    = 240;
        pipeWidth = 22;
        spawnX    = 240;
        spacing   = 110;
        gapBias   = 0;
        nearMiss  = 0;
        nearMissY = 0;
    }

    function setGapBias(b) { gapBias = b; }

    function setBounds(w, top, bottom, pipeW) {
        screenW   = w;
        ceilY     = top;
        floorY    = bottom;
        pipeWidth = pipeW;
        // Spacing scales with screen width — roughly 50% of width.
        spacing   = (w * 56) / 100;
        if (spacing < 90)  { spacing = 90;  }
    }

    function reset() {
        // Deactivate all pipes by parking them off-screen to the right
        // so they're available for the first 4 spawns.
        for (var i = 0; i < MAX_PIPES; i++) {
            pipes[i].x = screenW + 10000;
            pipes[i].scored = 0;
        }
    }

    // Seed the first 3 pipes at uniform spacing past the right edge.
    function prime(curGap) {
        var x = screenW + 30;
        for (var i = 0; i < 3; i++) {
            _setupPipe(pipes[i], x, curGap);
            x = x + spacing;
        }
        // 4th pipe sits parked further off-screen until needed.
        _setupPipe(pipes[3], x + spacing, curGap);
    }

    hidden function _setupPipe(p, x, gapH) {
        p.x       = x;
        p.w       = pipeWidth;
        p.scored  = 0;
        var minTop = ceilY + 16;             // never spawn a hugging-ceiling gap
        var maxTop = floorY - gapH - 16;     // never spawn hugging-floor gap
        if (maxTop < minTop) { maxTop = minTop + 1; }
        var gT    = minTop + (Math.rand() % (maxTop - minTop));
        p.gapTopY = gT;
        p.gapBotY = gT + gapH;
    }

    // Compute the gap height the next pipe should have for a given
    // score. Shrinks slowly per Physics.GAP_SHRINK.
    function gapForScore(score, scaleNum, scaleDen) {
        var g = Physics.GAP_BASE + gapBias - ((score / 5) * Physics.GAP_SHRINK).toNumber();
        var minG = Physics.GAP_MIN + gapBias;
        if (minG < 40) { minG = 40; }   // absolute safety floor (bird still fits)
        if (g < minG) { g = minG; }
        // Scale gap to screen size (scaleNum/scaleDen ~= screenH / 240).
        return (g * scaleNum) / scaleDen;
    }

    // Compute current scroll speed for given score.
    function scrollForScore(score) {
        var s = Physics.BASE_SCROLL + score * Physics.SCROLL_GAIN;
        if (s > Physics.MAX_SCROLL) { s = Physics.MAX_SCROLL; }
        return s;
    }

    // Advance all pipes left by dx. Recycle off-screen pipes to the
    // right of the rightmost active pipe. Returns number of new
    // points scored this tick (bird must have already crossed each).
    function step(dx, birdX, birdY, birdR, score, scaleNum, scaleDen) {
        nearMiss = 0;
        // Near-miss clearance threshold (screen px), scaled from the 240 ref.
        var thr = (10 * scaleNum) / scaleDen; if (thr < 6) { thr = 6; }
        // Find current rightmost x so we can recycle past it.
        var rightMost = -10000;
        for (var i = 0; i < MAX_PIPES; i++) {
            if (pipes[i].x > rightMost) { rightMost = pipes[i].x; }
        }
        var added = 0;
        for (var i = 0; i < MAX_PIPES; i++) {
            var p = pipes[i];
            p.x = p.x - dx;
            // Score when bird's leading edge has crossed pipe's trailing edge.
            if (p.scored == 0 && p.x + p.w < birdX) {
                p.scored = 1;
                added    = added + 1;
                // Measure how tight the squeeze was: distance from the bird's
                // top/bottom edge to the nearest gap edge. A small clearance
                // on either side is a "near miss" worth rewarding.
                var clearTop = (birdY - birdR) - p.gapTopY;
                var clearBot = p.gapBotY - (birdY + birdR);
                var minClear = (clearTop < clearBot) ? clearTop : clearBot;
                if (minClear >= 0 && minClear < thr) {
                    nearMiss  = 1;
                    nearMissY = birdY;
                }
            }
            // Recycle once fully off-screen left
            if (p.x + p.w < -4) {
                _setupPipe(p, rightMost + spacing,
                           gapForScore(score + added, scaleNum, scaleDen));
                rightMost = p.x;
            }
        }
        return added;
    }

    // AABB-vs-AABB hit test against every active pipe + ground / ceiling.
    function collides(birdBbox) {
        var bx0 = birdBbox[0];
        var by0 = birdBbox[1];
        var bx1 = birdBbox[2];
        var by1 = birdBbox[3];
        if (by1 > floorY)  { return true; }
        if (by0 < ceilY)   { return true; }
        for (var i = 0; i < MAX_PIPES; i++) {
            var p = pipes[i];
            // Quick reject by x range
            if (p.x > bx1 || p.x + p.w < bx0) { continue; }
            // Top pipe spans [ceilY .. p.gapTopY]
            if (by0 < p.gapTopY) { return true; }
            // Bottom pipe spans [p.gapBotY .. floorY]
            if (by1 > p.gapBotY) { return true; }
        }
        return false;
    }
}
