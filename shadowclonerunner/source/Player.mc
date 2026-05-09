// Player — physics, state, hitbox.
// All shared constants (STATE_RUN, STATE_JUMP, STATE_DUCK) are defined
// in GameView.mc at module level and visible here.

class Player {
    var x;
    var y;
    var vy;
    var onGround;
    var isDucking;
    var dw;
    var dh;
    hidden var _duckTimer;

    function initialize(px, pDw, pDh) {
        x  = px;
        dw = pDw;
        dh = pDh;
        y        = 0;
        vy       = 0;
        onGround = 1;
        isDucking  = 0;
        _duckTimer = 0;
    }

    function reset(groundY) {
        y          = groundY - dh;
        vy         = 0;
        onGround   = 1;
        isDucking  = 0;
        _duckTimer = 0;
    }

    function doJump() {
        if (isDucking == 1) { isDucking = 0; _duckTimer = 0; }
        if (onGround == 1) {
            vy       = -17;
            onGround = 0;
        }
    }

    function doDuck(groundY) {
        if (onGround == 1) {
            isDucking  = 1;
            _duckTimer = 40;
            y = groundY - effHeight();
        } else {
            // ground-pound while airborne
            if (vy < 12) { vy = 12; }
        }
    }

    function update(groundY) {
        // duck auto-expire
        if (_duckTimer > 0) {
            _duckTimer = _duckTimer - 1;
            if (_duckTimer == 0) {
                isDucking = 0;
                if (onGround == 1) { y = groundY - dh; }
            }
        }
        // gravity
        vy = vy + 2;
        y  = y  + vy;
        // floor
        var floor = groundY - effHeight();
        if (y >= floor) {
            y        = floor;
            vy       = 0;
            onGround = 1;
        }
    }

    function effHeight() {
        return isDucking == 1 ? (dh * 55 / 100) : dh;
    }

    function stateCode() {
        if (isDucking == 1) { return STATE_DUCK; }
        if (onGround == 0)  { return STATE_JUMP; }
        return STATE_RUN;
    }

    // Hit-box corners (inset for forgiving collision)
    function hitX1() { return x + 2; }
    function hitX2() { return x + dw - 2; }
    function hitY1() { return y + effHeight() / 4; }
    function hitY2() { return y + effHeight() - 2; }
}
