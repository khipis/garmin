// ═══════════════════════════════════════════════════════════════
// Paddle.mc — Vertical paddle with bounded movement.
//
// `x` is the LEFT edge of the paddle in screen pixels; `y` is the
// TOP edge. Both paddles share this class — the only difference is
// who's driving `vy` each tick (player or AIController).
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

class Paddle {
    var x;
    var y;
    var w;
    var h;
    var vy;
    var minY;
    var maxY;
    var color;

    function initialize(_color) {
        x = 0; y = 0; w = 4; h = 28; vy = 0.0; minY = 0; maxY = 100;
        color = _color;
    }

    function setBounds(px, pw, ph, ymin, ymax) {
        x    = px; w = pw; h = ph;
        minY = ymin;
        maxY = ymax;
        if (y < minY) { y = minY; }
        if (y + h > maxY) { y = maxY - h; }
    }

    function setCenterY(cy) {
        y = cy - h / 2;
        if (y < minY) { y = minY; }
        if (y + h > maxY) { y = maxY - h; }
    }

    function centerY() { return y + h / 2; }

    function step() {
        y = y + vy;
        if (y < minY)         { y = minY;        vy = 0.0; }
        if (y + h > maxY)     { y = maxY - h;    vy = 0.0; }
    }

    function draw(dc) {
        // Subtle glow under-rect
        dc.setColor((color & 0xFCFCFC) >> 2, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 1, y - 1, w + 2, h + 2);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);
        // bright "cap" pixels at top and bottom for a vector-display feel
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, 1);
        dc.fillRectangle(x, y + h - 1, w, 1);
    }
}
