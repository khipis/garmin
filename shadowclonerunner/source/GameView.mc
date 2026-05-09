using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

// ── Module-level constants (accessible across all source files) ───────────────
const GS_TITLE = 0;
const GS_RUN   = 1;
const GS_OVER  = 2;

const STATE_RUN  = 0;
const STATE_JUMP = 1;
const STATE_DUCK = 2;

const MAX_RUNS   = 3;    // shadow clone slots
const MAX_FRAMES = 800;  // max frames recorded per run (~26 s @ 30 fps)
const OBS_MAX    = 4;    // max simultaneous obstacles
const CLONE_GRACE = 80;  // ticks before clone-player collision is checked

// ── GameView ──────────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // game state
    hidden var _state;
    hidden var _timer;

    // layout (set in onLayout)
    hidden var _sw, _sh;
    hidden var _grdY;   // Y of ground line
    hidden var _pDx;    // player fixed X
    hidden var _pDw;    // player width
    hidden var _pDh;    // player full height

    // game objects
    hidden var _player;
    hidden var _obsMgr;
    hidden var _shadows;

    // counters
    hidden var _score;
    hidden var _hiScore;
    hidden var _spd;
    hidden var _tick;     // current-run tick (used as replay frame index)

    // effects
    hidden var _flash;    // white-flash countdown after death
    hidden var _scrollX;  // ground-dot scroll offset

    function initialize() {
        View.initialize();
        _state   = GS_TITLE;
        _hiScore = 0;
        _timer   = null;
        _flash   = 0;
        _scrollX = 0;
        _score   = 0;
        _spd     = 5;
        _tick    = 0;
        _pDw     = 0;
        _pDh     = 0;
        _pDx     = 0;
    }

    function onLayout(dc) {
        _sw   = dc.getWidth();
        _sh   = dc.getHeight();
        _grdY = _sh * 70 / 100;
        _pDx  = _sw * 17 / 100;
        _pDw  = _sw * 6 / 100;
        if (_pDw < 20) { _pDw = 20; }
        _pDh  = _pDw + _pDw * 70 / 100;   // ~1.7 × width

        _player  = new Player(_pDx, _pDw, _pDh);
        _obsMgr  = new ObstacleManager();
        _shadows = new ShadowManager();
        _player.reset(_grdY);
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:gameTick), 33, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── timer callback (called every 33 ms) ──────────────────────────────────
    function gameTick() {
        if (_state == GS_RUN) { _step(); }
        if (_flash > 0) { _flash = _flash - 1; }
        if (_shadows.newShadowTimer > 0) {
            _shadows.newShadowTimer = _shadows.newShadowTimer - 1;
        }
        WatchUi.requestUpdate();
    }

    // ── public controls ───────────────────────────────────────────────────────
    function doJump() {
        if (_state != GS_RUN) { _startRun(); return; }
        _player.doJump();
    }

    function doDuck() {
        if (_state != GS_RUN) { _startRun(); return; }
        _player.doDuck(_grdY);
    }

    function doBack() {
        if (_state == GS_RUN) { _endRun(); return true; }
        return false;
    }

    // ── game-loop internals ───────────────────────────────────────────────────
    hidden function _startRun() {
        _player.reset(_grdY);
        _obsMgr.reset();
        _shadows.startRec();
        _score   = 0;
        _spd     = 5;
        _tick    = 0;
        _scrollX = 0;
        _state   = GS_RUN;
    }

    hidden function _endRun() {
        _shadows.saveRun();
        if (_score > _hiScore) { _hiScore = _score; }
        _state = GS_OVER;
    }

    hidden function _step() {
        _tick    = _tick + 1;
        _scrollX = _scrollX + _spd;
        if (_scrollX > 3600) { _scrollX = _scrollX - 3600; }

        _player.update(_grdY);
        _spd = 5 + _score / 250;
        if (_spd > 14) { _spd = 14; }

        _obsMgr.update(_spd, _sw, _pDw, _pDh);

        // record current frame (frame index = _tick - 1 stored in _recY[_recLen])
        _shadows.record(_player.y, _player.stateCode());

        // ── obstacle collision ────────────────────────────────────────────────
        if (_obsMgr.collides(
                _player.hitX1(), _player.hitY1(),
                _player.hitX2(), _player.hitY2(), _grdY)) {
            _flash = 12;
            _endRun();
            return;
        }

        // ── clone collision (after grace period) ─────────────────────────────
        // frame of clone to test = _tick - 1 (the frame just recorded)
        if (_tick > CLONE_GRACE) {
            var frame = _tick - 1;
            var nc    = _shadows.runCount();
            for (var ci = 0; ci < nc; ci++) {
                var cY = _shadows.cloneY(ci, frame);
                if (cY == -9999) { continue; }  // this clone's run already ended
                var cS    = _shadows.cloneState(ci, frame);
                var cEffH = (cS == STATE_DUCK) ? (_pDh * 55 / 100) : _pDh;
                var cYtop = cY + cEffH / 4;
                var cYbot = cY + cEffH - 2;
                if (_player.hitY2() > cYtop && _player.hitY1() < cYbot) {
                    _flash = 12;
                    _endRun();
                    return;
                }
            }
        }

        _score = _score + 1;
    }

    // ── rendering ─────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        // white collision flash (alternating frames)
        if (_flash > 0 && _flash % 2 == 0) {
            dc.setColor(0xFFFFFF, 0xFFFFFF);
            dc.clear();
            return;
        }

        // background
        dc.setColor(0x050510, 0x050510);
        dc.clear();

        _drawAtmosphere(dc);
        _drawGround(dc);
        _drawObstacles(dc);
        _drawClones(dc);
        _drawPlayer(dc);
        _drawJumpParticles(dc);

        if (_state == GS_TITLE) {
            _drawTitle(dc);
        } else if (_state == GS_OVER) {
            _drawOver(dc);
        } else {
            _drawHUD(dc);
        }
    }

    hidden function _drawAtmosphere(dc) {
        // subtle dim "city" silhouette shapes in background
        dc.setColor(0x0e0e1e, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_sw * 18/100, _grdY - _sh * 25/100, _sw * 10/100, _sh * 25/100, 3);
        dc.fillRoundedRectangle(_sw * 32/100, _grdY - _sh * 18/100, _sw * 8/100,  _sh * 18/100, 3);
        dc.fillRoundedRectangle(_sw * 60/100, _grdY - _sh * 22/100, _sw * 9/100,  _sh * 22/100, 3);
        dc.fillRoundedRectangle(_sw * 73/100, _grdY - _sh * 14/100, _sw * 7/100,  _sh * 14/100, 3);
    }

    hidden function _drawGround(dc) {
        dc.setColor(0x1a1a3a, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _grdY, _sw, 2);
        // scrolling ground texture
        var off  = (_scrollX / 8) % 44;
        var px   = -(off);
        var cnt  = 0;
        while (px < _sw && cnt < 16) {
            dc.setColor(0x141428, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px, _grdY + 4, 4, 1);
            px  = px + 44;
            cnt = cnt + 1;
        }
    }

    hidden function _drawObstacles(dc) {
        _obsMgr.draw(dc, _grdY, _pDh);
    }

    hidden function _drawClones(dc) {
        var nc    = _shadows.runCount();
        var frame = _tick - 1;
        if (frame < 0) { frame = 0; }
        for (var ci = 0; ci < nc; ci++) {
            var cY = _shadows.cloneY(ci, frame);
            if (cY == -9999) { continue; }
            var cS    = _shadows.cloneState(ci, frame);
            var cEffH = (cS == STATE_DUCK) ? (_pDh * 55 / 100) : _pDh;
            var col;
            if      (ci == 0) { col = 0x1133AA; }
            else if (ci == 1) { col = 0x771199; }
            else              { col = 0x117733; }
            // ghost outline rendering (isFilled = false)
            _drawRunner(dc, _pDx, cY, _pDw, cEffH, cS, col, false);
        }
    }

    hidden function _drawPlayer(dc) {
        var effH = _player.effHeight();
        _drawRunner(dc, _player.x, _player.y, _pDw, effH,
                    _player.stateCode(), 0xDDDDDD, true);
    }

    // Dust/spark particles when jumping at start of leap
    hidden function _drawJumpParticles(dc) {
        if (_state != GS_RUN)           { return; }
        if (_player.onGround != 0)      { return; }
        if (_player.vy > -8)            { return; }
        dc.setColor(0x2244AA, Graphics.COLOR_TRANSPARENT);
        var px = _player.x + _pDw / 2;
        var py = _player.y + _player.effHeight() + 2;
        dc.fillCircle(px - 5, py, 2);
        dc.fillCircle(px,     py, 2);
        dc.fillCircle(px + 5, py, 2);
        dc.setColor(0x113388, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px - 8, py + 2, 1);
        dc.fillCircle(px + 8, py + 2, 1);
    }

    // ── character drawing ─────────────────────────────────────────────────────
    // isFilled=true  → solid white player
    // isFilled=false → ghost outline (clones)
    hidden function _drawRunner(dc, rx, ry, rdw, rdh, state, col, isFilled) {
        var headR  = rdw * 36 / 100;
        if (headR < 4) { headR = 4; }
        var headCX = rx + rdw / 2;
        var headCY = ry + rdh * 20 / 100;

        var bodyX  = rx + rdw * 2 / 10;
        var bodyY  = ry + rdh * 38 / 100;
        var bodyW  = rdw * 6 / 10;
        var bodyH  = rdh * 32 / 100;
        if (bodyW < 4) { bodyW = 4; }
        if (bodyH < 3) { bodyH = 3; }

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);

        if (isFilled) {
            dc.fillCircle(headCX, headCY, headR);
            dc.fillRoundedRectangle(bodyX, bodyY, bodyW, bodyH, 3);
        } else {
            dc.drawCircle(headCX, headCY, headR);
            dc.drawRoundedRectangle(bodyX, bodyY, bodyW, bodyH, 3);
        }

        // Red headband (player only)
        if (isFilled) {
            dc.setColor(0xFF2211, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(headCX - headR, headCY - 2, headR * 2, 3, 1);
            // eyes
            dc.setColor(0x050510, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(headCX - 3, headCY - 1, 2, 2);
            dc.fillRectangle(headCX + 1, headCY - 1, 2, 2);
        }

        // Legs
        var legX1  = rx + rdw * 22 / 100;
        var legX2  = rx + rdw * 52 / 100;
        var legW   = rdw * 20 / 100;
        var legTop = bodyY + bodyH;
        if (legW < 3) { legW = 3; }

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);

        if (state == STATE_DUCK) {
            // wide squat
            var lh = rdh * 14 / 100;
            if (lh < 3) { lh = 3; }
            if (isFilled) {
                dc.fillRoundedRectangle(legX1 - legW / 2, legTop, legW + legW / 2, lh, 2);
                dc.fillRoundedRectangle(legX2 - legW / 2, legTop, legW + legW / 2, lh, 2);
            } else {
                dc.drawRoundedRectangle(legX1 - legW / 2, legTop, legW + legW / 2, lh, 2);
                dc.drawRoundedRectangle(legX2 - legW / 2, legTop, legW + legW / 2, lh, 2);
            }
        } else if (state == STATE_JUMP) {
            // tucked
            var lh = rdh * 11 / 100;
            if (lh < 3) { lh = 3; }
            if (isFilled) {
                dc.fillRoundedRectangle(legX1, legTop, legW, lh, 2);
                dc.fillRoundedRectangle(legX2, legTop, legW, lh, 2);
            } else {
                dc.drawRoundedRectangle(legX1, legTop, legW, lh, 2);
                dc.drawRoundedRectangle(legX2, legTop, legW, lh, 2);
            }
        } else {
            // running — alternate legs every 4 ticks
            var lg  = (_tick / 4) % 2;
            var lh1 = (lg == 0) ? rdh * 27 / 100 : rdh * 14 / 100;
            var lh2 = (lg == 0) ? rdh * 14 / 100 : rdh * 27 / 100;
            if (lh1 < 3) { lh1 = 3; }
            if (lh2 < 3) { lh2 = 3; }
            if (isFilled) {
                dc.fillRoundedRectangle(legX1, legTop, legW, lh1, 2);
                dc.fillRoundedRectangle(legX2, legTop, legW, lh2, 2);
            } else {
                dc.drawRoundedRectangle(legX1, legTop, legW, lh1, 2);
                dc.drawRoundedRectangle(legX2, legTop, legW, lh2, 2);
            }
        }
    }

    // ── HUD ───────────────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        // score (upper-left safe zone, inset from bezel)
        dc.setColor(0x505070, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw * 27 / 100, _sh * 13 / 100, Graphics.FONT_XTINY,
            _score.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        if (_hiScore > 0) {
            dc.setColor(0x303050, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw * 27 / 100, _sh * 21 / 100, Graphics.FONT_XTINY,
                "HI " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
        // clone count indicator (upper-right)
        var nc = _shadows.runCount();
        if (nc > 0) {
            var col;
            if      (nc == 1) { col = 0x1133AA; }
            else if (nc == 2) { col = 0x771199; }
            else              { col = 0x117733; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw * 73 / 100, _sh * 13 / 100, Graphics.FONT_XTINY,
                "x" + nc.format("%d") + " clones", Graphics.TEXT_JUSTIFY_CENTER);
        }
        // "NEW CLONE!" notification (fades after game over entry)
        if (_shadows.newShadowTimer > 0) {
            var nc2 = _shadows.runCount();
            var notifCol;
            if      (nc2 == 1) { notifCol = 0x2255CC; }
            else if (nc2 == 2) { notifCol = 0x882299; }
            else               { notifCol = 0x229944; }
            dc.setColor(notifCol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, _sh * 56 / 100, Graphics.FONT_XTINY,
                "NEW CLONE!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── title screen ──────────────────────────────────────────────────────────
    hidden function _drawTitle(dc) {
        // Title
        dc.setColor(0x2255CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 20 / 100, Graphics.FONT_SMALL,
            "SHADOW", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x882299, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 31 / 100, Graphics.FONT_SMALL,
            "CLONE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x229944, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 42 / 100, Graphics.FONT_SMALL,
            "RUNNER", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x303055, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_sw / 2, _sh * 56 / 100, Graphics.FONT_XTINY,
            "any key to start", Graphics.TEXT_JUSTIFY_CENTER);

        if (_shadows.runCount() > 0) {
            dc.setColor(0x1a1a44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, _sh * 64 / 100, Graphics.FONT_XTINY,
                _shadows.runCount().format("%d") + " clone(s) waiting",
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_hiScore > 0) {
            dc.setColor(0x252535, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw / 2, _sh * 72 / 100, Graphics.FONT_XTINY,
                "best " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── game-over screen ──────────────────────────────────────────────────────
    hidden function _drawOver(dc) {
        var cx = _sw / 2;
        var bw = _sw * 44 / 100;
        var bh = _sh * 24 / 100;
        if (bw < 120) { bw = 120; }
        if (bh < 76)  { bh = 76; }
        var bx = cx - bw / 2;
        var by = _sh * 33 / 100;

        // panel
        dc.setColor(0x0a0a18, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 8);
        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 8);

        // GAME OVER
        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 5, Graphics.FONT_XTINY, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);

        // score
        dc.setColor(0x8888AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 21, Graphics.FONT_XTINY,
            _score.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);

        // best / new best
        if (_score >= _hiScore && _hiScore > 0) {
            dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 37, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_hiScore > 0) {
            dc.setColor(0x383855, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 37, Graphics.FONT_XTINY,
                "best " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // clone notification
        var nc = _shadows.runCount();
        if (nc > 0) {
            var col;
            if      (nc == 1) { col = 0x2255CC; }
            else if (nc == 2) { col = 0x882299; }
            else              { col = 0x229944; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 53, Graphics.FONT_XTINY,
                "+" + nc.format("%d") + " shadow clone(s)", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x222244, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 12, Graphics.FONT_XTINY,
            "any key to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
