// ═══════════════════════════════════════════════════════════════════════════
// ZombieView.mc — Screen flow and scene assembly.
//
// Five pages sit side by side and the player swipes between them:
//
//   COMPOUND ⇄ BASE ⇄ TONIGHT ⇄ JOURNAL ⇄ SALVAGE
//
// Everything else is an overlay that takes the screen for as long as it has
// something to say: the intro, the dawn report, a daytime event waiting on an
// answer, the night itself, and the result.
//
// Nothing in this file starts a wave. The clock does. `_tick` checks whether
// the model says a wave has come due and, if it has, the night begins whether
// the player was reaching for the upgrade list or not — which is the entire
// point of the game.
//
// The view also owns the frame clock and paints the street back-to-front.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;

class ZombieView extends WatchUi.View {

    // Pages, in swipe order.
    static const ST_HOME    = 0;
    static const ST_BASE    = 1;
    static const ST_PREVIEW = 2;
    static const ST_JOURNAL = 3;
    static const ST_FINDS   = 4;
    static const PAGE_N     = 5;
    // Overlays.
    static const ST_INTRO   = 5;
    static const ST_DAWN    = 6;
    static const ST_EVENT   = 7;
    static const ST_CARD    = 8;
    static const ST_WAVE    = 9;
    static const ST_RESULT  = 10;
    static const ST_RESOLVE = 11;

    // Simulation steps per rendered frame. A night is a couple of thousand
    // steps; at one per frame it would take minutes to watch, and the player
    // has no input to fill them with.
    static const SIM_SPEED = 3;
    // A wave that came due within this many seconds of the app opening is
    // still shown live. Being fifteen minutes late to your own siege should
    // not cost you the only spectacle in the game.
    static const LIVE_GRACE = 900;
    // Sim steps per frame while settling a wave nobody watched. A long night
    // is several thousand steps and running them in one call trips the
    // watchdog, so the same engine is walked across a handful of frames
    // behind a report screen instead.
    static const RESOLVE_CHUNK = 120;

    hidden var _m; hidden var _sim;
    hidden var _st; hidden var _t; hidden var _timer;
    hidden var _w; hidden var _h;
    hidden var _ys; hidden var _scales; hidden var _wx; hidden var _sx;
    hidden var _sel; hidden var _msg; hidden var _msgT;
    hidden var _banner; hidden var _bannerT;
    hidden var _fx; hidden var _detail;
    hidden var _muzzle; hidden var _flashT;
    hidden var _order; hidden var _holding;
    hidden var _wv; hidden var _wvNight;
    hidden var _item;      // cursor on the salvage shelf
    hidden var _jTop;      // first journal line on screen
    hidden var _evSel;     // which answer is highlighted

    function initialize() {
        View.initialize();
        _m = new ZombieModel();
        _t = 0; _timer = null; _w = 0; _h = 0;
        _sel = 0; _msg = null; _msgT = 0;
        _banner = null; _bannerT = 0;
        _muzzle = null; _flashT = 0; _holding = false;
        _sim = null; _wv = null; _wvNight = -1;
        _item = 0; _jTop = 0; _evSel = 0;
        _order = new [16];
        _loadOptions();
        try { _m.collectOffline(); } catch (e) {}
        _catchUp();
        _st = _openingScreen();
    }

    function model() { return _m; }
    function state() { return _st; }

    hidden function _loadOptions() {
        _fx = true; _detail = true;
        try {
            var v = Application.Storage.getValue("zs_fx");
            if (v instanceof Lang.Number) { _fx = (v == 0); }
            var d = Application.Storage.getValue("zs_detail");
            if (d instanceof Lang.Number) { _detail = (d == 0); }
        } catch (e) {}
    }

    // ── Settling whatever happened while we were away ───────────────────────
    // Two cases end up here: a wave that ran to completion with the app shut,
    // and a wave the player started watching and then walked away from. Both
    // are resolved by the same headless run, because the wave is the wave.
    hidden function _catchUp() {
        var owed = 0;
        if (_m.pendingNight > 0) {
            owed = _m.pendingNight;
        } else if (_m.waveDue() && !_liveWindow()) {
            _m.beginWave();
            owed = _m.night;
        }
        if (owed <= 0) { return; }
        try {
            _sim = new BattleSim(_m, owed);
            _sim.visual = false;
        } catch (e) {
            // A night that cannot even be set up must not strand the player
            // on a day they can never spend: give it to them and move on.
            _sim = null;
            _m.pendingNight = 0;
            _m.save();
        }
    }

    // Did tonight's wave land recently enough that the player can still watch?
    hidden function _liveWindow() {
        var left = _m.secsToWave();
        // secsToWave has already rolled to tomorrow, so time since the wave
        // landed is a full day minus what is left.
        return (86400 - left) <= LIVE_GRACE;
    }

    // Order matters: the night takes priority over anything that happened in
    // daylight, and a question waiting on an answer takes priority over the
    // report that would otherwise bury it.
    hidden function _openingScreen() {
        if (_sim != null) { return ST_RESOLVE; }
        if (!_m.seenIntro) { return ST_INTRO; }
        if (_m.rState == 1) { return ST_RESULT; }
        if (_m.waveDue()) { return ST_HOME; }   // _tick starts it within a frame
        if (_m.pendingEvent != Zs.EV_NONE) { return ST_EVENT; }
        if (_hasNews()) { return ST_DAWN; }
        return ST_HOME;
    }

    hidden function _hasNews() {
        return _m.gScrap > 0 || _m.gItem >= 0 || _m.gEvent != Zs.EV_NONE;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_tick), Zs.TICK_MS, true); } catch (e) {}
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
        try { _m.save(); } catch (e) {}
    }

    // ── Clock ───────────────────────────────────────────────────────────────
    function _tick() as Void {
        _t = (_t + 1) % 1000000;
        if (_msgT > 0) { _msgT -= 1; if (_msgT == 0) { _msg = null; } }
        if (_bannerT > 0) { _bannerT -= 1; if (_bannerT == 0) { _banner = null; } }
        if (_flashT > 0) { _flashT -= 1; }

        if (_st == ST_WAVE) {
            if (_holding) { _assist(); }
            for (var i = 0; i < SIM_SPEED && _sim.state == _sim.ST_FIGHT; i++) {
                _sim.tick();
            }
            _drain();
            if (_sim.state != _sim.ST_FIGHT) { _endWave(); }
        } else if (_st == ST_RESOLVE) {
            var n = 0;
            while (n < RESOLVE_CHUNK && _sim.state == _sim.ST_FIGHT) {
                _sim.tick();
                n += 1;
            }
            _sim.clearEvents();
            if (_sim.state != _sim.ST_FIGHT) { _endWave(); }
        } else if (_st != ST_INTRO && _m.waveDue()) {
            // Dusk, wherever the player happens to be standing in the UI.
            _startWave();
        }
        WatchUi.requestUpdate();
    }

    // Turn simulation events into sound and haptics.
    hidden function _drain() {
        var n = _sim.events();
        for (var i = 0; i < n; i++) {
            var e = _sim.eventAt(i);
            if (e == _sim.EV_SHOT)        { _flashT = 2; }
            else if (e == _sim.EV_BREACH) { _tone(2); _vibe(100, 250); }
            else if (e == _sim.EV_BOSS)   { _tone(1); _vibe(90, 300); }
            else if (e == _sim.EV_END)    { _tone(4); _vibe(60, 200); }
        }
        _sim.clearEvents();
    }

    hidden function _tone(kind) {
        if (!_fx) { return; }
        try {
            if (!(Attention has :playTone)) { return; }
            var t = Attention.TONE_KEY;
            if (kind == 2) { t = Attention.TONE_ERROR; }
            else if (kind == 4) { t = Attention.TONE_SUCCESS; }
            Attention.playTone(t);
        } catch (e) {}
    }
    hidden function _vibe(inten, dur) {
        if (!_fx) { return; }
        try {
            if (!(Attention has :vibrate)) { return; }
            Attention.vibrate([new Attention.VibeProfile(inten, dur)]);
        } catch (e) {}
    }
    hidden function _toast(s) { _msg = s; _msgT = 26; }

    // ── The night ───────────────────────────────────────────────────────────
    hidden function _startWave() {
        _m.beginWave();
        _sim = new BattleSim(_m, _m.night);
        _layout();
        _sim.setGeometry(_w, _h);
        _banner = "THEY ARE HERE";
        _bannerT = 30;
        _st = ST_WAVE;
        _tone(2);
        _vibe(90, 400);
    }

    hidden function _endWave() {
        try { _m.recordWave(_sim.result()); } catch (e) {}
        _st = ST_RESULT;
    }

    // Skip the rest of the replay. The night still resolves in full; the
    // remaining steps just run behind the report screen instead of being
    // drawn, at the same chunked pace as a wave nobody watched.
    hidden function _skipWave() {
        _sim.visual = false;
        _st = ST_RESOLVE;
    }

    // ── Input ───────────────────────────────────────────────────────────────
    function activate() {
        if (_st == ST_INTRO) {
            _m.seenIntro = true; _m.save();
            _st = _hasNews() ? ST_DAWN : ST_HOME;
            return;
        }
        if (_st == ST_DAWN)   { _st = ST_HOME; return; }
        if (_st == ST_RESULT) { _m.ackResult(); _st = ST_HOME; _sel = 0; return; }
        if (_st == ST_EVENT)  { _answer(); return; }
        if (_st == ST_CARD)   { _st = ST_FINDS; return; }
        if (_st == ST_FINDS)  { _st = ST_CARD; return; }
        if (_st == ST_HOME)   { _st = ST_BASE; return; }
        if (_st == ST_PREVIEW || _st == ST_JOURNAL) { _st = ST_HOME; return; }
        if (_st == ST_BASE)   { _buy(); return; }
        if (_st == ST_WAVE)   { _assist(); return; }
    }

    hidden function _answer() {
        _m.resolveEvent(_evSel == 0);
        _evSel = 0;
        _st = ST_DAWN;
        _tone(1); _vibe(40, 60);
    }

    // The one thing a present player can do. Deliberately unaimed.
    hidden function _assist() {
        if (_sim.assist()) {
            _flashT = 2;
            _vibe(15, 15);
        }
    }

    function move(d) {
        if (_st == ST_BASE) {
            _sel = (_sel + d + Zs.D_N) % Zs.D_N;
        } else if (_st == ST_FINDS) {
            _item = (_item + d + Zs.IT_N) % Zs.IT_N;
        } else if (_st == ST_CARD) {
            // Browse the whole shelf without stepping back out to the grid.
            _item = (_item + d + Zs.IT_N) % Zs.IT_N;
        } else if (_st == ST_JOURNAL) {
            var n = _m.log == null ? 0 : _m.log.size();
            var maxTop = n - 4;
            if (maxTop < 0) { maxTop = 0; }
            _jTop += d;
            if (_jTop < 0) { _jTop = 0; }
            if (_jTop > maxTop) { _jTop = maxTop; }
        } else if (_st == ST_EVENT) {
            _evSel = (_evSel + 1) % 2;
        } else if (_st == ST_DAWN) {
            _st = ST_HOME;
        }
    }

    // Watching a wave is the only state where holding the button means
    // anything, and even then it just fires at the rifle's own rate.
    function isWatching() { return _st == ST_WAVE; }

    function holdFire(on) {
        _holding = (_st == ST_WAVE) && on;
    }

    // BACK: step out of a screen, or skip the rest of the replay. Only the
    // compound lets BACK fall through and close the app, so the way out is
    // always "keep going back until you are looking at the yard".
    function back() {
        if (_st == ST_WAVE) { _skipWave(); return true; }
        if (_st == ST_RESOLVE) { return true; }   // a second or two, let it run
        if (_st == ST_RESULT) { _m.ackResult(); _st = ST_HOME; _sel = 0; return true; }
        if (_st == ST_EVENT) { return true; }     // has to be answered
        if (_st == ST_CARD) { _st = ST_FINDS; return true; }
        if (_st == ST_INTRO || _st == ST_DAWN) { _st = ST_HOME; return true; }
        if (_st != ST_HOME && _st < PAGE_N) { _st = ST_HOME; return true; }
        return false;
    }

    // Sideways swipe walks the carousel. Overlays ignore it.
    function page(d) {
        if (_st >= PAGE_N) { return false; }
        _st = (_st + d + PAGE_N) % PAGE_N;
        if (_st == ST_JOURNAL) { _jTop = 0; }
        return true;
    }

    hidden function _in(r, x, y) {
        return r != null && x >= r[0] && x < r[0] + r[2]
                         && y >= r[1] && y < r[1] + r[3];
    }

    // Everything tappable registered itself while the frame was being drawn,
    // so this is a walk over that list rather than a second copy of the layout.
    function onTapXY(x, y) {
        if (_st == ST_WAVE) { _assist(); return true; }

        if (_st < PAGE_N) {
            for (var i = 0; i < ZsHud.tabRects.size(); i++) {
                if (_in(ZsHud.tabRects[i], x, y)) { _goto(i); return true; }
            }
        }
        if (_in(ZsHud.btnA, x, y)) { activate(); return true; }

        for (var r = 0; r < ZsHud.rows.size(); r++) {
            if (!_in(ZsHud.rows[r], x, y)) { continue; }
            var id = ZsHud.rowIds[r];
            if (_st == ST_BASE) {
                // Tapping a row selects it; tapping the selected row buys it.
                if (id == _sel) { _buy(); } else { _sel = id; }
            } else if (_st == ST_FINDS) {
                if (id == _item) { _st = ST_CARD; } else { _item = id; }
            } else if (_st == ST_EVENT) {
                _evSel = id;
                _answer();
            }
            return true;
        }
        activate();
        return true;
    }

    hidden function _goto(p) {
        _st = p;
        if (_st == ST_JOURNAL) { _jTop = 0; }
    }

    hidden function _buy() {
        if (_m.upgrade(_sel)) {
            _toast(Zs.dName(_sel) + " L" + _m.dLevel[_sel].format("%d"));
            _tone(1); _vibe(40, 40);
        } else if (_m.dLevel[_sel] >= Zs.D_LVL_MAX) {
            _toast("MAXED OUT");
        } else {
            _toast("NEED " + _m.upgradeCost(_sel).format("%d") + " SCRAP");
            _tone(2);
        }
    }

    // Tonight's wave, built once per night rather than once per frame: the
    // schedule is an array three times the size of the horde and the preview
    // screen would otherwise churn one every 55 ms.
    hidden function _forecast() {
        if (_wv == null || _wvNight != _m.night) {
            _wv = WaveGen.forNight(_m.night);
            _wvNight = _m.night;
        }
        return _wv;
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    hidden function _layout() {
        _ys = ZsArt.laneYs(_h);
        _scales = ZsArt.laneScales();
        _wx = ZsArt.wallXs(_w);
        _sx = ZsArt.spawnXs(_w);
    }

    // ── Paint ───────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        var neww = dc.getWidth();
        var newh = dc.getHeight();
        if (neww != _w || newh != _h) {
            _w = neww; _h = newh;
            _layout();
            if (_sim != null) { _sim.setGeometry(_w, _h); }
        }

        // Tap targets are recorded as the screen is painted, so the registry
        // has to be emptied before anything is drawn into it.
        ZsHud.reset();

        if (_st == ST_WAVE) { _drawWave(dc); return; }
        if (_st == ST_RESOLVE) { ZsHud.resolving(dc, _w, _h, _sim, _t); return; }
        if (_st == ST_INTRO)   { ZsHud.intro(dc, _w, _h, _t); return; }
        if (_st == ST_DAWN)    { ZsHud.dawn(dc, _w, _h, _m, _t); return; }
        if (_st == ST_EVENT)   { ZsHud.eventPanel(dc, _w, _h, _m, _evSel, _t); return; }
        if (_st == ST_CARD)    { ZsHud.findCard(dc, _w, _h, _m, _item, _t); return; }
        if (_st == ST_RESULT)  { ZsHud.result(dc, _w, _h, _m, _t); return; }

        if (_st == ST_HOME) {
            ZsCompound.draw(dc, _w, _h, _m, _t, _detail);
            ZsHud.homeRibbon(dc, _w, _h, _m, _t);
        } else if (_st == ST_PREVIEW) {
            ZsHud.preview(dc, _w, _h, _m, _forecast(), _t);
        } else if (_st == ST_JOURNAL) {
            ZsHud.journal(dc, _w, _h, _m, _jTop, _t);
        } else if (_st == ST_FINDS) {
            ZsHud.finds(dc, _w, _h, _m, _item, _t);
        } else {
            ZsHud.base(dc, _w, _h, _m, _sel, _t);
            if (_msg == null) { ZsHud.baseHint(dc, _w, _h, _sel); }
        }
        ZsHud.tabStrip(dc, _w, _h, _st, PAGE_N);
        if (_msg != null) { ZsHud.popup(dc, _w, _h, _msg, Zs.ACCENT); }
    }

    hidden function _drawWave(dc) {
        var s = _sim;
        var mod = s.mod;

        // Camera shake nudges the street, not the overlay.
        var dx = 0; var dy = 0;
        if (s.shake > 0) {
            var k = s.shake > 6 ? 3 : (s.shake > 3 ? 2 : 1);
            dx = ((_t % 2) == 0) ? k : -k;
            dy = ((_t % 3) == 0) ? k / 2 : -(k / 2);
        }

        dc.setColor(Zs.BG, Zs.BG);
        dc.clear();
        ZsArt.drawSky(dc, _w, _h, mod, _t, s.flashW, _detail);
        ZsArt.drawGround(dc, _w, _h, _shifted(_ys, dy), _t, _detail);
        if (mod == Zs.MOD_FOG) { ZsArt.drawFog(dc, _w, _h, _ys, _t); }
        ZsArt.drawTraps(dc, _w, _h, s.lvl[Zs.D_SPIKES], s.lvl[Zs.D_WIRE]);

        for (var l = Zs.LANES - 1; l >= 0; l--) {
            var gy = _ys[l] + dy;
            var sc = _scales[l];
            _drawLaneZombies(dc, l, gy, sc, dx);
            if (l == 0) { _drawPlayer(dc, dx, dy); }
            ZsArt.drawTurretAt(dc, _w, _h, l, s.lvl, _t, true);
            ZsArt.drawBarricade(dc, _w, _h, l, _wx[l] + dx, gy, sc,
                                s.wallPctAt(l), s.breach[l], _t);
        }

        _drawTracers(dc, dx, dy);
        ZsArt.drawParticles(dc, s);
        ZsArt.drawWeather(dc, _w, _h, mod, _t, _detail);

        ZsHud.simHud(dc, _w, _h, s, _t);
        if (_banner != null) { _drawBanner(dc); }
    }

    hidden function _shifted(ys, dy) {
        if (dy == 0) { return ys; }
        return [ys[0] + dy, ys[1] + dy, ys[2] + dy];
    }

    // Back-to-front inside a lane so nearer zombies overlap the ones behind.
    hidden function _drawLaneZombies(dc, l, gy, sc, dx) {
        var s = _sim;
        var n = 0;
        for (var i = 0; i < s.ZMAX; i++) {
            if (s.zAlive[i] && s.zLane[i] == l) { _order[n] = i; n += 1; }
        }
        for (var a = 1; a < n; a++) {
            var key = _order[a];
            var b = a - 1;
            while (b >= 0 && s.zX[_order[b]] < s.zX[key]) {
                _order[b + 1] = _order[b];
                b -= 1;
            }
            _order[b + 1] = key;
        }
        for (var k = 0; k < n; k++) {
            var z = _order[k];
            var ty = s.zType[z];
            var x = s.screenX(s.zX[z], l) + dx;
            if (x < -40 || x > _w + 60) { continue; }
            var hgt = ZsArt.zHeight(_h, sc, ty);
            ZsArt.drawZombie(dc, ty, x, gy, hgt, s.zAnim[z], s.zFlash[z], 0);
            // A slim health pip above anything tougher than a walker.
            if (s.zHp[z] < s.zMax[z] && !Zs.zIsBoss(ty) && s.zMax[z] > 40) {
                var bw = hgt * 40 / 100;
                var by = gy - hgt - 4;
                dc.setColor(0x550000, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x - bw / 2, by, bw, 2);
                dc.setColor(Zs.BLOOD2, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x - bw / 2, by, bw * s.zHp[z] / s.zMax[z], 2);
            }
        }
    }

    // You are on the wall whether or not you fire. The muzzle flash is the
    // only thing that marks the difference between watching and helping.
    hidden function _drawPlayer(dc, dx, dy) {
        var px = ZsArt.playerX(_w) + dx;
        var gy = _ys[0] + dy;
        _muzzle = ZsArt.drawSurvivor(dc, px, gy, _h * 18 / 100, 0, _sim.muzzle,
                                     false, false, _t);
        if (_flashT > 0 && _muzzle != null) {
            ZsArt.drawMuzzleFlash(dc, _muzzle[0], _muzzle[1], _h * 3 / 100, _flashT);
        }
    }

    // Tracers leave from the emplacement covering that lane, not from the
    // player: almost every round fired on a given night is fired by a turret,
    // and lines converging on one shoulder would read as a man doing the work.
    hidden function _drawTracers(dc, dx, dy) {
        var s = _sim;
        for (var i = 0; i < s.TMAX; i++) {
            if (s.tLife[i] <= 0) { continue; }
            var l = s.tLane[i];
            var y = _ys[l] + dy - _h * 7 / 100;
            ZsArt.drawTracer(dc, _wx[l] - _w * 8 / 100 + dx, y,
                             s.screenX(s.tX[i], l) + dx, y, s.tLife[i]);
        }
    }

    hidden function _drawBanner(dc) {
        var y = _h * 40 / 100;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, y - 4, _w, _h * 12 / 100);
        dc.setColor(Zs.DANGER, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, y - 5, _w, 2);
        dc.fillRectangle(0, y + _h * 12 / 100 - 4, _w, 2);
        dc.setColor(_bannerT > 12 || (_bannerT % 4) < 2 ? 0xFFFFFF : Zs.DANGER,
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, y + 2, Graphics.FONT_SMALL, _banner,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
