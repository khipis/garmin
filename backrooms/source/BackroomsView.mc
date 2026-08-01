// ═══════════════════════════════════════════════════════════════════════════
// BackroomsView.mc — The run: game loop, HUD and the two ways it can end.
//
// One frame = advance the player, let the floor have its mood swing, move the
// entities, spend sanity, then raycast and paint. Sanity is the clock: it
// always drains, faster in the dark and faster while something is looking at
// you. Reaching the exit does not end the run, it drops you a floor deeper.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;
using Toybox.Math;

const BR_FRAME_MS = 80;

const ST_INTRO = 0;
const ST_PLAY  = 1;
const ST_END   = 2;

class BackroomsView extends WatchUi.View {
    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _t;

    hidden var _map; hidden var _p; hidden var _rc;
    hidden var _ents; hidden var _ev;

    hidden var _state;
    hidden var _level; hidden var _seed; hidden var _runSeed;
    hidden var _san;            // sanity in hundredths (0..10000)
    hidden var _frames;
    hidden var _relics; hidden var _rooms;
    hidden var _floorsCleared;
    hidden var _daily;

    hidden var _diff; hidden var _detail; hidden var _fxOn; hidden var _tex;
    hidden var _msg; hidden var _msgT;
    hidden var _endWin; hidden var _endBest;
    hidden var _flick;          // fluorescent flicker, 0..100
    hidden var _hurt;           // red flash frames
    hidden var _torch;          // battery, hundredths of a percent
    hidden var _torchOn;
    hidden var _stam;           // sprint stamina, hundredths
    hidden var _cells;          // spare cells collected this run

    // Sprite scratch — reused every frame so the loop never allocates.
    hidden var _sprN; hidden var _sprX; hidden var _sprS;
    hidden var _sprD; hidden var _sprK; hidden var _sprF; hidden var _sprE;

    function initialize(daily, resumeBlob) {
        View.initialize();
        _w = 0; _h = 0; _timer = null; _t = 0;
        _state = ST_PLAY;
        _msg = null; _msgT = 0;
        _endWin = false; _endBest = false;
        _flick = 100; _hurt = 0;
        _relics = 0; _rooms = 0; _floorsCleared = 0;
        _torch = Br.TORCH_START; _torchOn = false;
        _stam = Br.STAM_MAX; _cells = 0;
        _daily = daily;

        _loadOptions();

        _sprX = new [10]; _sprS = new [10]; _sprD = new [10];
        _sprK = new [10]; _sprF = new [10]; _sprE = new [10];
        _sprN = 0;

        _rc = new Raycaster(Br.rayCount(_detail));
        _p = new PlayerController();

        if (resumeBlob != null) {
            _restore(resumeBlob);
        } else {
            _newRun();
        }

        if (!_seenIntro()) { _state = ST_INTRO; }
    }

    hidden function _loadOptions() {
        _diff = _opt("br_diff", 1, 2);
        _detail = _opt("br_detail", 1, 2);
        _tex = Br.texLevel(_detail);
        var fx = _opt("br_fx", 0, 1);
        _fxOn = (fx == 0);
    }
    hidden function _opt(key, def, hi) {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number && v >= 0 && v <= hi) { return v; }
        } catch (e) {}
        return def;
    }
    hidden function _seenIntro() {
        try {
            var v = Application.Storage.getValue("br_seenintro");
            return (v instanceof Lang.Number && v == 1);
        } catch (e) {}
        return false;
    }
    hidden function _markIntro() {
        try { Application.Storage.setValue("br_seenintro", 1); } catch (e) {}
    }

    // ── Run setup ────────────────────────────────────────────────────────────
    hidden function _newRun() {
        if (_daily) {
            _runSeed = MapGen.dailySeed(BrSave.today());
        } else {
            _runSeed = Math.rand() & 0x7FFFFFFF;
            if (_runSeed == 0) { _runSeed = 991; }
        }
        _level = 0;
        _san = Br.SANITY_MAX * 100;
        _torch = Br.TORCH_START;
        _torchOn = false;
        _stam = Br.STAM_MAX;
        _frames = 0;
        _buildFloor();
    }

    hidden function _buildFloor() {
        _seed = MapGen.nextRand(_runSeed + _level * 7717);
        _map = MapGen.generate(_seed, _level);
        _p.placeAt(_map.startX, _map.startY, _map.startAng);
        _ents = new EntityManager(_seed ^ 0x2A3B4C, BrSave.stalkerBias());
        _ev = new EventManager(_seed ^ 0x5F1E33);
        _map.visit(_p.cellX(), _p.cellY());
    }

    hidden function _restore(b) {
        try {
            _runSeed = b["sd"];
            _level = b["lv"];
            _daily = (b["dl"] == 1);
            _san = b["sn"];
            _frames = b["se"] * 1000 / BR_FRAME_MS;
            _relics = b["rl"];
            var tr = b["tr"];    // absent in blobs written before the torch
            _torch = (tr instanceof Lang.Number) ? tr : Br.TORCH_START;
            _torchOn = false;
            _stam = Br.STAM_MAX;
            _buildFloor();
            _p.x = b["px"] / 100.0;
            _p.y = b["py"] / 100.0;
            _p.ang = b["an"] / 1000.0;
            _p.hasKey = (b["ky"] == 1);
            _p._updateVectors();
        } catch (e) {
            _newRun();
        }
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_tick), BR_FRAME_MS, true); } catch (e) {}
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── Feedback ─────────────────────────────────────────────────────────────
    hidden function _tone(kind) {
        if (!_fxOn) { return; }
        try {
            if (!(Attention has :playTone)) { return; }
            var t = Attention.TONE_KEY;
            if (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
            else if (kind == 2) { t = Attention.TONE_ERROR; }
            else if (kind == 4) { t = Attention.TONE_SUCCESS; }
            Attention.playTone(t);
        } catch (e) {}
    }
    hidden function _vibe(inten, dur) {
        if (!_fxOn) { return; }
        try {
            if (!(Attention has :vibrate)) { return; }
            Attention.vibrate([new Attention.VibeProfile(inten, dur)]);
        } catch (e) {}
    }
    hidden function _toast(s) { _msg = s; _msgT = 26; }

    // Math.rand() is signed — never index or modulo with it raw.
    hidden function _rnd(n) {
        if (n <= 1) { return 0; }
        var r = Math.rand();
        if (r < 0) { r = -r; }
        return r % n;
    }

    // ── Loop ─────────────────────────────────────────────────────────────────
    function _tick() as Void {
        _t = (_t + 1) % 100000;
        if (_state == ST_PLAY) {
            try { _step(); } catch (e) {}
        }
        WatchUi.requestUpdate();
    }

    hidden function _step() {
        _frames += 1;
        if (_msgT > 0) { _msgT -= 1; if (_msgT == 0) { _msg = null; } }
        if (_hurt > 0) { _hurt -= 1; }

        _p.update(_map);
        _ev.update(_map, _p, _ents, _level, Br.diffEventPct(_diff));

        var cellDark = _map.isDark(_p.cellX(), _p.cellY());
        var darkNow = _ev.darkOn || cellDark;

        // The torch only burns while it is actually lit, and dies quietly.
        if (_torchOn) {
            _torch -= Br.TORCH_DRAIN;
            if (_torch <= 0) {
                _torch = 0;
                _torchOn = false;
                _toast("BATTERY DEAD");
                _tone(2); _vibe(70, 160);
            }
        }
        if (_stam < Br.STAM_MAX) {
            _stam += Br.STAM_REGEN;
            if (_stam > Br.STAM_MAX) { _stam = Br.STAM_MAX; }
        }

        var drain = _ents.update(_map, _p, darkNow, _level, _torchOn);
        var cue = _ev.takeTone();
        if (cue == 1) { _vibe(25, 60); }
        else if (cue == 2) { _tone(2); _vibe(70, 140); }

        // Sanity: the resource that never stops falling. The dark takes it
        // three times faster, which is exactly what the torch is for.
        var rate = darkNow ? Br.DRAIN_DARK : Br.DRAIN_BASE;
        if (darkNow && _torchOn) { rate = Br.DRAIN_BASE + 4; }
        rate = rate * Br.diffDrainPct(_diff) / 100;
        rate += _level * 2;
        _san -= rate;
        if (drain > 0) {
            _san -= drain;
            if (drain > 300) { _hurt = 8; _vibe(90, 180); _tone(2); }
        }

        if (_ents.contact == 1) { _teleportScare(); }

        if (_map.visit(_p.cellX(), _p.cellY())) { _rooms += 1; }
        _checkCell();

        if (_san <= 0) { _san = 0; _endRun(false); return; }
        if (secs() >= Br.RUN_SECS_CAP) { _endRun(true); return; }

        // Fluorescent flicker — mostly steady, occasionally not.
        if (_ev.darkOn) {
            _flick = 16;
        } else {
            var r = _rnd(100);
            if (r < 4) { _flick = 45 + _rnd(30); }
            else if (_flick < 100) { _flick += 12; if (_flick > 100) { _flick = 100; } }
        }
    }

    function secs() { return _frames * BR_FRAME_MS / 1000; }
    function sanityPts() { return _san / 100; }

    // Walked onto something.
    hidden function _checkCell() {
        var i = _map.specialAt(_p.cellX(), _p.cellY());
        if (i < 0) { return; }
        var s = _map.sp[i];
        var kind = s[2];

        if (kind == Br.SP_EXIT) {
            s[3] = 1;
            _descend();
        } else if (kind == Br.SP_MIMIC) {
            s[3] = 1;
            _mimicTrap();
        } else if (kind == Br.SP_KEY) {
            s[3] = 1;
            _p.hasKey = true;
            _toast("KEY");
            _tone(1); _vibe(35, 60);
        } else if (kind == Br.SP_SANITY) {
            s[3] = 1;
            _san += Br.SANITY_PICK * 100;
            if (_san > Br.SANITY_MAX * 100) { _san = Br.SANITY_MAX * 100; }
            _toast("ALMOND WATER");
            _tone(4); _vibe(30, 50);
        } else if (kind == Br.SP_CELL) {
            s[3] = 1;
            _cells += 1;
            _torch += Br.TORCH_CELL;
            if (_torch > Br.TORCH_MAX) { _torch = Br.TORCH_MAX; }
            _toast("SPARE CELL");
            _tone(1); _vibe(30, 50);
        } else if (kind == Br.SP_RELIC) {
            s[3] = 1;
            _relics += 1;
            _san += Br.RELIC_SANITY * 100;
            if (_san > Br.SANITY_MAX * 100) { _san = Br.SANITY_MAX * 100; }
            _toast("ARTIFACT FOUND");
            _tone(4); _vibe(50, 90);
        }
    }

    hidden function _descend() {
        _floorsCleared += 1;
        _level += 1;
        _san += 3000;
        if (_san > Br.SANITY_MAX * 100) { _san = Br.SANITY_MAX * 100; }
        _tone(4); _vibe(60, 140);
        _buildFloor();
        _toast(Br.levelName(_level));
    }

    // The mimic opens. You are somewhere else now.
    hidden function _mimicTrap() {
        _san -= 3500;
        _hurt = 14;
        _ev.glitch = 100;
        _ev.shake = 6;
        _tone(2); _vibe(100, 300);
        _toast("IT WAS NOT A DOOR");
        _teleportScare();
    }

    hidden function _teleportScare() {
        if (_map.rooms.size() < 2) { return; }
        var r = _map.rooms[_rnd(_map.rooms.size())];
        _p.placeAt(r[0] + r[2] / 2, r[1] + r[3] / 2, _rnd(4) * 1.5708);
        _ev.glitch = 90;
    }

    // ── Input intents (called by the delegate) ───────────────────────────────
    function doForward() {
        if (_state == ST_INTRO) { _markIntro(); _state = ST_PLAY; return; }
        if (_state != ST_PLAY) { return; }
        _p.pushForward();
    }
    function doTurn(d) {
        if (_state != ST_PLAY) { return; }
        _p.pushTurn(d);
    }
    function doSprint() {
        if (_state == ST_INTRO) { _markIntro(); _state = ST_PLAY; return; }
        if (_state != ST_PLAY) { return; }
        if (_stam < Br.STAM_COST) {
            _toast("NO BREATH LEFT");
            return;
        }
        _stam -= Br.STAM_COST;
        _p.pushSprint();
        _san -= 120;             // panic still costs, just less than the wind
        _vibe(45, 70);
    }

    // The LIGHT button. Thematically the only correct binding there is.
    function doTorch() {
        if (_state == ST_INTRO) { _markIntro(); _state = ST_PLAY; return; }
        if (_state != ST_PLAY) { return; }
        if (!_torchOn && _torch <= 0) {
            _toast("BATTERY DEAD");
            _tone(2);
            return;
        }
        _torchOn = !_torchOn;
        _toast(_torchOn ? "TORCH ON" : "TORCH OFF");
        _vibe(25, 40);
    }

    // Swipe down: use whatever is in front of you.
    function doInteract() {
        if (_state == ST_INTRO) { _markIntro(); _state = ST_PLAY; return; }
        if (_state == ST_END) { return; }

        var fx = (_p.x + _p.dirX * 0.9).toNumber();
        var fy = (_p.y + _p.dirY * 0.9).toNumber();

        var i = _map.specialAt(fx, fy);
        if (i >= 0) {
            var s = _map.sp[i];
            if (s[2] == Br.SP_DOOR) {
                if (_p.hasKey) {
                    s[3] = 1;
                    _map.clearWall(fx, fy);
                    _p.hasKey = false;
                    _toast("DOOR OPENS");
                    _tone(4); _vibe(50, 90);
                } else {
                    _toast("LOCKED");
                    _tone(2);
                }
                return;
            }
        }
        // Nothing to use — listening is still an action.
        if (_ents.watched(_p)) {
            _toast("SOMETHING IS CLOSE");
            _vibe(80, 160);
        } else {
            _toast("ONLY HUM");
        }
    }

    function isPlaying() { return _state == ST_PLAY; }
    function isEnded() { return _state == ST_END; }
    function width() { return _w; }
    function height() { return _h; }

    // ── Ending ───────────────────────────────────────────────────────────────
    hidden function _endRun(timeUp) {
        if (_state == ST_END) { return; }
        _state = ST_END;
        _endWin = timeUp;
        var sc = secs();

        try {
            _endBest = BrSave.recordRun(sc, _level, _floorsCleared > 0, _relics, _rooms);
            if (_daily) { BrSave.recordDaily(BrSave.today(), sc); }
            BrSave.submitRun(_daily, sc);
        } catch (e) {}
        try { SaveResume.clear(Br.GAME_ID); } catch (e) {}

        _tone(timeUp ? 4 : 2);
        _vibe(timeUp ? 60 : 100, 250);

        try {
            var variant = _daily ? Br.LB_DAILY : Br.LB_TIME;
            Leaderboard.showPostGame(Br.GAME_ID, variant, "BACKROOMS");
        } catch (e) {}
    }

    // Mid-run save blob for the shared exit prompt (null = nothing worth saving).
    function exportSave() as Lang.Dictionary or Null {
        if (_state != ST_PLAY) { return null; }
        if (_frames < 40) { return null; }
        return BrSave.buildResume(_runSeed, _level, _p.x, _p.y, _p.ang,
                                  _san, secs(), _p.hasKey, _relics, _daily,
                                  _torch);
    }

    // ── Paint ────────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        dc.setColor(Br.BG, Br.BG);
        dc.clear();

        if (_state == ST_INTRO) { _drawIntro(dc); return; }

        var shakeY = 0;
        if (_ev.shake > 0) {
            shakeY = _rnd(_ev.shake * 2 + 1) - _ev.shake;
        }
        var horizon = _h / 2 + _p.bobY + shakeY;
        if (horizon < _h / 5) { horizon = _h / 5; }
        if (horizon > _h * 4 / 5) { horizon = _h * 4 / 5; }

        var light = _flick;
        if (_ev.darkOn) { light = 14; }
        if (_map.isDark(_p.cellX(), _p.cellY()) && light > 40) { light = 40; }

        // The beam lifts the room floor-wide a little and the middle of the
        // view a lot — the cone itself is applied per column in drawWalls.
        var cone = 0;
        if (_torchOn && _torch > 0) {
            if (light < Br.TORCH_LIGHT) { light = Br.TORCH_LIGHT; }
            cone = _rc.cols * Br.TORCH_CONE / 100;
            if (cone < 2) { cone = 2; }
        }

        try {
            _rc.cast(_map, _p.x, _p.y, _p.dirX, _p.dirY, _p.planeX, _p.planeY);
            BrRender.drawCeiling(dc, _w, _h, horizon, light, _tex);
            BrRender.drawFloor(dc, _w, _h, horizon, light, _tex);
            BrRender.drawWalls(dc, _w, _h, horizon, _rc, _level, light,
                               _ev.stretch, _tex, cone);
            _drawSprites(dc, horizon, light);
        } catch (e) {}

        if (_ev.glitch > 0) { BrRender.drawGlitch(dc, _w, _h, _ev.glitch, _t); }
        if (_hurt > 0) { _drawHurt(dc); }
        if (_tex >= 2) { BrRender.drawScanlines(dc, _w, _h); }
        BrRender.drawVignette(dc, _w, _h);

        if (_state == ST_END) { _drawEnd(dc); return; }
        _drawHud(dc);
    }

    hidden function _drawSprites(dc, horizon, light) {
        _sprN = 0;

        // Static things on the floor.
        for (var i = 0; i < _map.sp.size() && _sprN < 10; i++) {
            var s = _map.sp[i];
            if (s[3] != 0) { continue; }
            if (s[2] == Br.SP_DOOR) { continue; }     // a door is a wall until it is not
            if (_p.dist2To(s[0], s[1]) > 169.0) { continue; }
            var pr = BrRender.project(_w, _h, _rc, _p, s[0] + 0.5, s[1] + 0.5);
            if (pr == null) { continue; }
            _sprX[_sprN] = pr[0]; _sprS[_sprN] = pr[1]; _sprD[_sprN] = pr[2];
            _sprK[_sprN] = s[2]; _sprF[_sprN] = 100; _sprE[_sprN] = 0;
            _sprN += 1;
        }

        // Things that move.
        for (var e = 0; e < _ents.list.size() && _sprN < 10; e++) {
            var en = _ents.list[e];
            if (en.fade <= 0) { continue; }
            var pe = BrRender.project(_w, _h, _rc, _p, en.x, en.y);
            if (pe == null) { continue; }
            _sprX[_sprN] = pe[0]; _sprS[_sprN] = pe[1]; _sprD[_sprN] = pe[2];
            _sprK[_sprN] = en.kind; _sprF[_sprN] = en.fade; _sprE[_sprN] = 1;
            if (en.kind == Br.E_SHADOW && en.state == 1) { _sprE[_sprN] = 2; }
            _sprN += 1;
        }

        // Farthest first (insertion sort — never more than ten items).
        for (var a = 1; a < _sprN; a++) {
            var b = a;
            while (b > 0 && _sprD[b - 1] < _sprD[b]) {
                _swap(b - 1, b);
                b -= 1;
            }
        }

        for (var k = 0; k < _sprN; k++) {
            var y0 = horizon - _sprS[k] / 2;
            if (_sprE[k] == 0) {
                if (_sprK[k] == Br.SP_EXIT || _sprK[k] == Br.SP_MIMIC) {
                    BrRender.drawDoor(dc, _sprX[k], y0, _sprS[k], light);
                } else {
                    BrRender.drawPickup(dc, _sprK[k], _sprX[k], y0, _sprS[k],
                                        light, _t);
                }
            } else {
                var st = (_sprE[k] == 2) ? 1 : 0;
                BrRender.drawEntity(dc, _sprK[k], _sprX[k], y0, _sprS[k],
                                    _sprF[k], st, light, _t);
            }
        }
    }

    hidden function _swap(i, j) {
        var t;
        t = _sprX[i]; _sprX[i] = _sprX[j]; _sprX[j] = t;
        t = _sprS[i]; _sprS[i] = _sprS[j]; _sprS[j] = t;
        t = _sprD[i]; _sprD[i] = _sprD[j]; _sprD[j] = t;
        t = _sprK[i]; _sprK[i] = _sprK[j]; _sprK[j] = t;
        t = _sprF[i]; _sprF[i] = _sprF[j]; _sprF[j] = t;
        t = _sprE[i]; _sprE[i] = _sprE[j]; _sprE[j] = t;
    }

    hidden function _drawHurt(dc) {
        BrRender.ditherRect(dc, 0, 0, _w, _h, Br.HURT, 4);
    }

    hidden function _drawHud(dc) {
        var cx = _w / 2;
        var pct = sanityPts();

        // ── Top plate: where you are. Kept clear of the top of a round screen,
        // where the bezel and our own vignette would eat the caps. The plate is
        // solid and cut to the width of the caption: a dithered one sits over
        // the pale ceiling as a patch of corduroy, which is the single most
        // conspicuous thing in the frame and it is a label.
        var name = (_daily ? "DAILY  " : "") + Br.levelName(_level);
        var tw = dc.getTextWidthInPixels(name, Graphics.FONT_XTINY);
        var tplH = dc.getFontHeight(Graphics.FONT_XTINY);
        var ty = _h * 8 / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - tw / 2 - 9, ty, tw + 18, tplH + 5, 4);
        dc.setColor(Br.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ty + 2, Graphics.FONT_XTINY, name,
                    Graphics.TEXT_JUSTIFY_CENTER);

        // ── Bottom cluster: sanity over stamina, both on a dark plate
        var bw = _w * 44 / 100;
        var bh = 7;
        var bx = cx - bw / 2;
        var by = _h * 79 / 100;

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx - 15, by - 5, bw + 30, bh + 26, 5);

        var col = Br.SANE;
        if (pct < 45) { col = 0xFFFF55; }
        if (pct < 22) { col = Br.DANGER; }
        BrRender.rect(dc, bx - 1, by - 1, bw + 2, bh + 2, 0x000000);
        BrRender.rect(dc, bx, by, bw * pct / Br.SANITY_MAX, bh, col);
        // Ten notches, so the bar reads as a gauge rather than a smear.
        for (var n = 1; n < 10; n++) {
            BrRender.rect(dc, bx + bw * n / 10, by, 1, bh, 0x000000);
        }

        // Breath, directly under it and half the height.
        var sw2 = bw * _stam / Br.STAM_MAX;
        BrRender.rect(dc, bx, by + bh + 2, bw, 3, 0x000000);
        BrRender.rect(dc, bx, by + bh + 2, sw2, 3,
                      (_stam >= Br.STAM_COST) ? 0x55AAFF : 0x555555);

        // ── Torch: a cell drawn as a cell, filling from the bottom
        var tx = bx - 12;
        var th = bh + 5;
        BrRender.rect(dc, tx, by, 7, th, 0x000000);
        BrRender.rect(dc, tx + 2, by - 2, 3, 2, 0x555555);
        var fill = th * _torch / Br.TORCH_MAX;
        var tcol = 0x00AA00;
        if (_torch < Br.TORCH_MAX / 4) { tcol = 0xFFAA00; }
        if (_torch <= 0) { tcol = 0x550000; }
        BrRender.rect(dc, tx + 1, by + th - fill, 5, fill, tcol);
        if (_torchOn) {
            BrRender.rect(dc, tx - 4, by + th / 2 - 1, 3, 3, 0xFFFFAA);
        }

        // ── Carried: key on one side, artifacts on the other
        if (_p.hasKey) {
            BrRender.rect(dc, bx + bw + 6, by + 2, 7, 3, 0xFFAA00);
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx + bw + 5, by + 3, 3);
        }
        if (_relics > 0) {
            dc.setColor(0xAA55FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + bh + 6, Graphics.FONT_XTINY,
                _relics.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Br.COL2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 86 / 100, Graphics.FONT_XTINY,
            _fmtTime(secs()) + "   " + _p.facing(), Graphics.TEXT_JUSTIFY_CENTER);

        // ── A pulse on the bezel once sanity is nearly gone
        if (pct < 25 && ((_t / 3) % 4) < 2) {
            dc.setColor(Br.DANGER, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            var rr = ((_w < _h) ? _w / 2 : _h / 2) - 4;
            dc.drawCircle(cx, _h / 2, rr);
            dc.setPenWidth(1);
        }

        // Event line, then the toast — never both.
        if (_ev.msg != null) {
            BrRender.ditherRect(dc, cx - _w * 34 / 100, _h * 21 / 100,
                                _w * 68 / 100, _h * 9 / 100, 0x000000, 2);
            dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 22 / 100, Graphics.FONT_XTINY, _ev.msg,
                Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_msg != null) {
            BrRender.ditherRect(dc, cx - _w * 34 / 100, _h * 21 / 100,
                                _w * 68 / 100, _h * 9 / 100, 0x000000, 2);
            dc.setColor(Br.ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 22 / 100, Graphics.FONT_XTINY, _msg,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _fmtTime(s) {
        var m = s / 60;
        var ss = s % 60;
        return m.format("%d") + ":" + ss.format("%02d");
    }

    hidden function _drawEnd(dc) {
        var cx = _w / 2;
        BrRender.ditherRect(dc, 0, 0, _w, _h, 0x000000, 2);

        dc.setColor(_endWin ? Br.ACCENT : Br.DANGER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 20 / 100, Graphics.FONT_SMALL,
            _endWin ? "YOU HELD ON" : "LOST", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 38 / 100, Graphics.FONT_XTINY,
            "SURVIVED " + _fmtTime(secs()), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, _h * 47 / 100, Graphics.FONT_XTINY,
            "DEPTH " + _level.format("%d") + "   ROOMS " + _rooms.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);
        if (_relics > 0) {
            dc.setColor(0xC89AFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 56 / 100, Graphics.FONT_XTINY,
                "ARTIFACTS " + _relics.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_floorsCleared > 0) {
            dc.setColor(0x55FF55, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 56 / 100, Graphics.FONT_XTINY,
                "EXITS " + _floorsCleared.format("%d"),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_endBest) {
            dc.setColor(Br.ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 65 / 100, Graphics.FONT_XTINY,
                "NEW BEST", Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x8A8268, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 80 / 100, Graphics.FONT_XTINY,
            "BACK to leave", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawIntro(dc) {
        var cx = _w / 2;
        dc.setColor(Br.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 15 / 100, Graphics.FONT_TINY, "BACKROOMS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var lines = [
            "SWIPE UP  walk",
            "SWIPE L/R  turn",
            "SWIPE DOWN  use",
            "LIGHT  torch",
            "MENU  run",
            "Find the exit before",
            "your sanity runs out."
        ];
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, _h * 27 / 100 + i * (_h * 75 / 1000), Graphics.FONT_XTINY,
                lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x8A8268, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 88 / 100, Graphics.FONT_XTINY,
            "TAP to enter", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
