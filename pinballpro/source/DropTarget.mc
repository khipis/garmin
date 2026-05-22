// ═══════════════════════════════════════════════════════════════
// DropTarget.mc — Small rectangular target that vanishes when hit.
//
// Pinball "drop targets" are the rectangular plastic flags arranged
// in a bank. Each hit knocks one down (becomes invisible + stops
// colliding) and awards points. Clearing the entire bank awards a
// big bonus AND triggers multiball.
//
// The state of a drop is just a single boolean (`down`), plus a
// short `flash` counter that the renderer uses to highlight the
// target for a few ticks right after a hit.
// ═══════════════════════════════════════════════════════════════

class DropTarget {
    var x;          // top-left
    var y;
    var w;
    var h;
    var color;
    var down;       // true → knocked down, ignore in collisions + draw
    var flash;      // ticks remaining of post-hit highlight

    function initialize() {
        x = 0; y = 0; w = 0; h = 0;
        color = 0x44FF88;
        down = false;
        flash = 0;
    }

    function configure(px, py, pw, ph, col) {
        x = px; y = py; w = pw; h = ph;
        color = col;
        down = false;
        flash = 0;
    }

    function reset() { down = false; flash = 0; }

    function knockDown() {
        down = true;
        flash = 6;
    }

    function tickFlash() {
        if (flash > 0) { flash = flash - 1; }
    }
}
