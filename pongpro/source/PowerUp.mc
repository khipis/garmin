// ═══════════════════════════════════════════════════════════════
// PowerUp.mc — Floating pickup that spawns mid-court during a rally.
//
// Whichever ball touches it triggers an effect tied to `lastHitSide`
// (the paddle that most recently returned a ball) tracked by
// GameController:
//   MULTIBALL — spawns a second ball for the rest of the rally.
//   GROW      — the last hitter's paddle grows for a while.
//   SHRINK    — the last hitter's OPPONENT paddle shrinks for a while.
//
// The pickup itself is dumb: it just knows where it is, what kind it
// is, and whether a given AABB overlaps it. GameController owns all
// timing/spawn/effect logic.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

const PU_MULTIBALL = 0;
const PU_GROW      = 1;
const PU_SHRINK    = 2;
const PU_TYPES     = 3;

// Ticks (at 40 Hz) a grow/shrink buff lasts, and how long an uncollected
// pickup lingers before despawning + how long to wait before the next one.
const PU_BUFF_TICKS   = 320;   // ~8 s
const PU_LIFE_TICKS   = 440;   // ~11 s
const PU_COOLDOWN_MIN = 260;   // ~6.5 s
const PU_COOLDOWN_MAX = 420;   // ~10.5 s

class PowerUp {
    var active;
    var x;
    var y;
    var kind;
    var r;
    hidden var _pulse;

    function initialize() {
        active = false; x = 0; y = 0; kind = 0; r = 9; _pulse = 0;
    }

    function spawn(px, py, k) {
        x = px; y = py; kind = k; active = true; _pulse = 0;
    }

    function clear() { active = false; }

    function step() {
        if (active) { _pulse = (_pulse + 1) % 36; }
    }

    // AABB overlap test against a ball's bounding box.
    function hits(bx0, by0, bx1, by1) {
        if (!active) { return false; }
        return (bx1 > x - r && bx0 < x + r && by1 > y - r && by0 < y + r);
    }

    function draw(dc) {
        if (!active) { return; }
        var pr = r + ((_pulse < 18) ? _pulse / 4 : (36 - _pulse) / 4);
        var col;
        if      (kind == PU_MULTIBALL) { col = 0x33CCFF; }
        else if (kind == PU_GROW)      { col = 0x44FF66; }
        else                            { col = 0xFF4444; }

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, pr);
        dc.fillCircle(x, y, r - 3);

        dc.setColor(0x0A0A0A, Graphics.COLOR_TRANSPARENT);
        if (kind == PU_MULTIBALL) {
            dc.fillCircle(x - 3, y, 2);
            dc.fillCircle(x + 3, y, 2);
        } else if (kind == PU_GROW) {
            dc.fillPolygon([[x, y - 4], [x - 4, y + 3], [x + 4, y + 3]]);
        } else {
            dc.fillPolygon([[x, y + 4], [x - 4, y - 3], [x + 4, y - 3]]);
        }
    }

    function label() {
        if (kind == PU_MULTIBALL) { return "MULTIBALL!"; }
        if (kind == PU_GROW)      { return "PADDLE UP!"; }
        return "SHRINK RAY!";
    }
}
