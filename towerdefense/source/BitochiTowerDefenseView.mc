// ═══════════════════════════════════════════════════════════════════════════
// BitochiTowerDefenseView.mc — Simulation + presentation for the whole run.
//
// Layout order: map · pads/towers · enemies · projectiles · particles · HUD.
// Every pool is allocated once in initialize(); the tick and the draw pass
// never call new. Positions derive from the playfield square (_ox/_oy/_side)
// and all design numbers are percentages of it, so a 208px fr235 and a 454px
// fenix run an identical game at different pixel densities.
//
// The terrain scatter and the path cobbles are baked into flat arrays at map
// load — redrawing them is then a tight fillRectangle loop instead of
// thousands of hash calls per frame.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;
using Toybox.Lang;
using Toybox.System;

class BitochiTowerDefenseView extends WatchUi.View {

    // ── Layout ──────────────────────────────────────────────────────────────
    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;
    hidden var _ox;
    hidden var _oy;
    hidden var _side;
    hidden var _rad;        // vignette radius
    hidden var _sc;         // pixels per map unit (side / 100.0)
    hidden var _u;          // enemy size unit
    hidden var _tu;         // tower size unit
    hidden var _pw;         // path width
    hidden var _fine;       // false on tiny screens: fewer decorations
    hidden var _round;      // bezel clips the corners: panels must fit a chord

    // ── Run plumbing ────────────────────────────────────────────────────────
    hidden var _timer;
    hidden var _tick;
    hidden var _phase;
    hidden var _skipStart;
    hidden var _lbHandled;
    hidden var _configured;

    hidden var _mapIdx;
    hidden var _diff;
    hidden var _daily;
    hidden var _seed;
    hidden var _paceN;
    hidden var _hints;

    hidden var _wave;
    hidden var _coins;
    hidden var _baseHp;
    hidden var _baseMax;
    hidden var _score;
    hidden var _kills;
    hidden var _leaks;
    hidden var _dmgDealt;
    hidden var _bestWave;
    hidden var _won;

    // ── Feel ────────────────────────────────────────────────────────────────
    hidden var _shake;      // remaining shake ticks
    hidden var _shx;
    hidden var _shy;
    hidden var _edge;       // red screen-edge flash ticks
    hidden var _coinPop;    // coin counter pop ticks
    hidden var _toast;
    hidden var _toastTick;
    hidden var _banner;     // wave-modifier announcement
    hidden var _bannerTick;

    // ── Path ────────────────────────────────────────────────────────────────
    hidden var _pathN;
    hidden var _pathX;
    hidden var _pathY;
    hidden var _pathLen;    // cumulative length at each waypoint
    hidden var _pathDx;     // unit direction of the segment ENDING at i
    hidden var _pathDy;
    hidden var _pathTotal;
    hidden var _flyLen;
    hidden var _flyDx;
    hidden var _flyDy;
    hidden var _flyMul;     // flyer speed so the shortcut is an edge, not a win

    // ── Pads ────────────────────────────────────────────────────────────────
    hidden var _padN;
    hidden var _padX;
    hidden var _padY;
    hidden var _padTower;

    // ── Baked terrain ───────────────────────────────────────────────────────
    hidden var _decoN;
    hidden var _decoX;
    hidden var _decoY;
    hidden var _decoS;
    hidden var _decoC;
    hidden var _propN;
    hidden var _propX;
    hidden var _propY;
    hidden var _propS;
    hidden var _propK;
    hidden var _cobN;
    hidden var _cobX;
    hidden var _cobY;
    hidden var _cobS;
    hidden var _cobC;

    // ── Towers ──────────────────────────────────────────────────────────────
    hidden var _twAlive;
    hidden var _twType;
    hidden var _twTier;
    hidden var _twPad;
    hidden var _twX;
    hidden var _twY;
    hidden var _twCd;
    hidden var _twDx;
    hidden var _twDy;
    hidden var _twRecoil;
    hidden var _twHot;
    hidden var _twTgt;      // targeting mode
    hidden var _twLock;     // current target enemy index (-1 none)
    hidden var _twSpent;
    hidden var _twKills;
    hidden var _twDmg;
    hidden var _twWk;       // kills this wave
    hidden var _twWd;       // damage this wave

    // ── Enemies ─────────────────────────────────────────────────────────────
    hidden var _enAlive;
    hidden var _enType;
    hidden var _enHp;
    hidden var _enMax;
    hidden var _enProg;
    hidden var _enSlow;
    hidden var _enX;
    hidden var _enY;
    hidden var _enDx;
    hidden var _enDy;
    hidden var _enFlash;
    hidden var _enArmor;
    hidden var _enAux;      // healer / boss ability timer
    hidden var _enBuff;     // remaining ticks of the boss buff
    hidden var _enBurn;     // flamethrower burn stacks

    // ── Projectiles ─────────────────────────────────────────────────────────
    hidden var _shAlive;
    hidden var _shKind;
    hidden var _shX;
    hidden var _shY;
    hidden var _shDx;
    hidden var _shDy;
    hidden var _shGone;     // distance travelled
    hidden var _shTot;      // distance to the impact point
    hidden var _shDmg;
    hidden var _shSplash;
    hidden var _shOwner;

    // ── Particles ───────────────────────────────────────────────────────────
    hidden var _fxKind;
    hidden var _fxLife;
    hidden var _fxMax;
    hidden var _fxX;
    hidden var _fxY;
    hidden var _fxX2;
    hidden var _fxY2;
    hidden var _fxCol;
    hidden var _fxText;

    // ── Wave state ──────────────────────────────────────────────────────────
    hidden var _spawnLeft;
    hidden var _spawnIdx;
    hidden var _spawnTimer;
    hidden var _spawnGap;
    hidden var _waveMod;
    hidden var _waveTotal;
    hidden var _waveKills;
    hidden var _waveDmg;
    hidden var _waveLeaks;
    hidden var _waveArmorSoak;   // damage lost to armour this wave
    hidden var _waveAirLeak;
    hidden var _clearBonus;
    hidden var _interest;
    hidden var _summaryTick;
    hidden var _tip;

    // ── Abilities ───────────────────────────────────────────────────────────
    hidden var _abCd;
    hidden var _abHit;      // enemies already bombed by the current airstrike

    // ── UI ──────────────────────────────────────────────────────────────────
    hidden var _ui;
    hidden var _cursor;     // pad index, or _padN for the START slot
    hidden var _row;        // selection inside the open sheet
    hidden var _selTower;

    function initialize() {
        View.initialize();
        _skipStart  = false;
        _lbHandled  = false;
        _configured = false;
        _timer      = null;
        _tick       = 0;
        _phase      = TD_BUILD;
        _w = 0; _h = 0; _cx = 0; _cy = 0;
        _ox = 0; _oy = 0; _side = 0; _rad = 0;
        _sc = 1.0; _u = 4; _tu = 6; _pw = 8; _fine = true; _round = true;
        _mapIdx = 0; _diff = 1; _daily = false; _seed = 1;
        _paceN = 10; _hints = true;
        _wave = 1; _coins = 130; _baseHp = 18; _baseMax = 18;
        _score = 0; _kills = 0; _leaks = 0; _dmgDealt = 0;
        _bestWave = 0; _won = false;
        _shake = 0; _shx = 0; _shy = 0; _edge = 0; _coinPop = 0;
        _toast = null; _toastTick = 0; _banner = null; _bannerTick = 0;
        _pathN = 0; _pathTotal = 1.0; _flyLen = 1.0;
        _flyDx = 1.0; _flyDy = 0.0; _flyMul = 1.0;
        _padN = 0; _decoN = 0; _propN = 0; _cobN = 0;
        _spawnLeft = 0; _spawnIdx = 0; _spawnTimer = 0; _spawnGap = 10;
        _waveMod = TDW_NONE; _waveTotal = 0;
        _waveKills = 0; _waveDmg = 0; _waveLeaks = 0;
        _waveArmorSoak = 0; _waveAirLeak = 0;
        _clearBonus = 0; _interest = 0;
        _summaryTick = 0; _tip = "";
        _ui = TDUI_MAP; _cursor = 0; _row = 0; _selTower = -1;
        _alloc();
        TdArt.prep();
    }

    hidden function _alloc() as Void {
        _pathX = new [TD_MAX_PATH];
        _pathY = new [TD_MAX_PATH];
        _pathLen = new [TD_MAX_PATH];
        _pathDx = new [TD_MAX_PATH];
        _pathDy = new [TD_MAX_PATH];

        _padX = new [TD_MAX_PADS];
        _padY = new [TD_MAX_PADS];
        _padTower = new [TD_MAX_PADS];

        _decoX = new [TD_MAX_DECO];
        _decoY = new [TD_MAX_DECO];
        _decoS = new [TD_MAX_DECO];
        _decoC = new [TD_MAX_DECO];
        _propX = new [TD_MAX_PROP];
        _propY = new [TD_MAX_PROP];
        _propS = new [TD_MAX_PROP];
        _propK = new [TD_MAX_PROP];
        _cobX = new [TD_MAX_STONE];
        _cobY = new [TD_MAX_STONE];
        _cobS = new [TD_MAX_STONE];
        _cobC = new [TD_MAX_STONE];

        _twAlive = new [TD_MAX_TOWERS];
        _twType  = new [TD_MAX_TOWERS];
        _twTier  = new [TD_MAX_TOWERS];
        _twPad   = new [TD_MAX_TOWERS];
        _twX     = new [TD_MAX_TOWERS];
        _twY     = new [TD_MAX_TOWERS];
        _twCd    = new [TD_MAX_TOWERS];
        _twDx    = new [TD_MAX_TOWERS];
        _twDy    = new [TD_MAX_TOWERS];
        _twRecoil= new [TD_MAX_TOWERS];
        _twHot   = new [TD_MAX_TOWERS];
        _twTgt   = new [TD_MAX_TOWERS];
        _twLock  = new [TD_MAX_TOWERS];
        _twSpent = new [TD_MAX_TOWERS];
        _twKills = new [TD_MAX_TOWERS];
        _twDmg   = new [TD_MAX_TOWERS];
        _twWk    = new [TD_MAX_TOWERS];
        _twWd    = new [TD_MAX_TOWERS];

        _enAlive = new [TD_MAX_ENEMIES];
        _enType  = new [TD_MAX_ENEMIES];
        _enHp    = new [TD_MAX_ENEMIES];
        _enMax   = new [TD_MAX_ENEMIES];
        _enProg  = new [TD_MAX_ENEMIES];
        _enSlow  = new [TD_MAX_ENEMIES];
        _enX     = new [TD_MAX_ENEMIES];
        _enY     = new [TD_MAX_ENEMIES];
        _enDx    = new [TD_MAX_ENEMIES];
        _enDy    = new [TD_MAX_ENEMIES];
        _enFlash = new [TD_MAX_ENEMIES];
        _enArmor = new [TD_MAX_ENEMIES];
        _enAux   = new [TD_MAX_ENEMIES];
        _enBuff  = new [TD_MAX_ENEMIES];
        _enBurn  = new [TD_MAX_ENEMIES];

        _shAlive  = new [TD_MAX_SHOTS];
        _shKind   = new [TD_MAX_SHOTS];
        _shX      = new [TD_MAX_SHOTS];
        _shY      = new [TD_MAX_SHOTS];
        _shDx     = new [TD_MAX_SHOTS];
        _shDy     = new [TD_MAX_SHOTS];
        _shGone   = new [TD_MAX_SHOTS];
        _shTot    = new [TD_MAX_SHOTS];
        _shDmg    = new [TD_MAX_SHOTS];
        _shSplash = new [TD_MAX_SHOTS];
        _shOwner  = new [TD_MAX_SHOTS];

        _fxKind = new [TD_MAX_FX];
        _fxLife = new [TD_MAX_FX];
        _fxMax  = new [TD_MAX_FX];
        _fxX    = new [TD_MAX_FX];
        _fxY    = new [TD_MAX_FX];
        _fxX2   = new [TD_MAX_FX];
        _fxY2   = new [TD_MAX_FX];
        _fxCol  = new [TD_MAX_FX];
        _fxText = new [TD_MAX_FX];

        _abCd = new [TDA_COUNT];
        _abHit = new [TD_STRIKE_HITS];

        for (var i = 0; i < TD_MAX_TOWERS; i++) { _twAlive[i] = false; }
        for (var i = 0; i < TD_MAX_ENEMIES; i++) { _enAlive[i] = false; }
        for (var i = 0; i < TD_MAX_SHOTS; i++) { _shAlive[i] = false; }
        for (var i = 0; i < TD_MAX_FX; i++) { _fxLife[i] = 0; }
        for (var i = 0; i < TD_MAX_PADS; i++) { _padTower[i] = -1; }
        for (var i = 0; i < TDA_COUNT; i++) { _abCd[i] = 0; }
    }

    // ── Lifecycle ───────────────────────────────────────────────────────────

    function onLayout(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        var m = _w;
        if (_h < m) { m = _h; }
        _rad = m / 2 - 2;
        _round = true;
        try {
            var sh = System.getDeviceSettings().screenShape;
            _round = (sh != System.SCREEN_SHAPE_RECTANGLE);
        } catch (e) {}
        // A square inscribed in the bezel can only be 70% of the diameter, and
        // the HUD needs the top and bottom of the disc, so the board takes 64%
        // and sits slightly high — the bottom sheet is taller than the wave
        // chip above it.
        _side = (m * 64) / 100;
        _ox = _cx - _side / 2;
        _oy = _cy - _side / 2 - m / 60;
        _sc = _side / 100.0;
        _fine = (_side >= 150);

        _u = _side / 28;
        if (_u < 3) { _u = 3; }
        _tu = _side / 24;
        if (_tu < 4) { _tu = 4; }
        _pw = _side * 7 / 100;
        if (_pw < 5) { _pw = 5; }
        if (_configured) { _loadMap(); }
    }

    function onShow() {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTimer), TD_TICK_MS, true);
        }
        if (!_skipStart) { _beginRun(); }
        if (_configured) { _loadMap(); }
        _skipStart = false;
    }

    function onHide() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTimer() as Void {
        _tick++;
        if (_toastTick > 0)  { _toastTick--; }
        if (_bannerTick > 0) { _bannerTick--; }
        if (_coinPop > 0)    { _coinPop--; }
        if (_edge > 0)       { _edge--; }
        if (_shake > 0) {
            _shake--;
            var a = _shake;
            if (a > 4) { a = 4; }
            var s = (_tick % 2 == 0) ? a : -a;
            _shx = s;
            _shy = (_tick % 4 < 2) ? s / 2 : -s / 2;
        } else {
            _shx = 0;
            _shy = 0;
        }
        for (var i = 0; i < TDA_COUNT; i++) {
            if (_abCd[i] > 0) { _abCd[i]--; }
        }

        if (_phase == TD_WAVE) {
            _tickWave();
        } else if (_phase == TD_SUMMARY) {
            _summaryTick++;
            _tickFx();
        } else if (_phase == TD_BUILD) {
            _tickFx();
            _idleTowers();
        } else if (_phase == TD_OVER) {
            _tickFx();
            _finishOnce();
        }
        WatchUi.requestUpdate();
    }

    // ── Run setup ───────────────────────────────────────────────────────────

    hidden function _beginRun() as Void {
        _mapIdx = TdUtil.mapIndex();
        _diff   = TdUtil.difficulty();
        _daily  = TdUtil.isDaily();
        _paceN  = TdUtil.pace();
        _hints  = TdUtil.hintsOn();
        _seed   = _daily ? TdUtil.dailySeed() : (_mapIdx * 97 + _diff * 31 + 7);

        _wave = 1;
        _kills = 0; _leaks = 0; _dmgDealt = 0; _score = 0;
        _won = false; _lbHandled = false;
        _waveKills = 0; _waveDmg = 0; _waveLeaks = 0;
        _waveArmorSoak = 0; _waveAirLeak = 0;
        _clearBonus = 0; _interest = 0;

        for (var i = 0; i < TD_MAX_TOWERS; i++) { _twAlive[i] = false; }
        for (var i = 0; i < TD_MAX_ENEMIES; i++) { _enAlive[i] = false; }
        for (var i = 0; i < TD_MAX_SHOTS; i++) { _shAlive[i] = false; }
        for (var i = 0; i < TD_MAX_FX; i++) { _fxLife[i] = 0; }
        for (var i = 0; i < TDA_COUNT; i++) { _abCd[i] = 0; }

        _baseMax = TD_BASE_HP_NORMAL;
        if (_diff == 0)      { _baseMax = TD_BASE_HP_EASY; }
        else if (_diff == 2) { _baseMax = TD_BASE_HP_HARD; }
        _baseHp = _baseMax;
        _coins = 150 - _diff * 20;

        _grantDailyBonus();
        try {
            var b = Application.Storage.getValue("td_best");
            if (b instanceof Lang.Number) { _bestWave = b; }
        } catch (e) {}

        _configured = true;
        _loadMap();
        _phase = TD_BUILD;
        _ui = TDUI_MAP;
        _cursor = 0;
        _row = 0;
        _selTower = -1;
        _announceWave();
    }

    // The shared Progress check-in leaves a message for us; turn the streak
    // into a real starting advantage rather than just a popup.
    hidden function _grantDailyBonus() as Void {
        try {
            var msg = Application.Storage.getValue("td_daily_msg");
            if (!(msg instanceof Lang.String)) { return; }
            var bonus = 15;
            try {
                var ci = Application.Storage.getValue("pg_streak");
                if (ci instanceof Lang.Dictionary && ci["n"] instanceof Lang.Number) {
                    bonus = 15 + TdUtil.clamp(ci["n"], 0, 10) * 3;
                }
            } catch (e2) {}
            _coins += bonus;
            _toast = msg;
            _toastTick = 40;
            Application.Storage.deleteValue("td_daily_msg");
        } catch (e) {}
    }

    hidden function _loadMap() as Void {
        if (_side == null || _side <= 0) { return; }
        var raw = TdMap.path(_mapIdx);
        _pathN = raw.size() / 2;
        if (_pathN > TD_MAX_PATH) { _pathN = TD_MAX_PATH; }
        for (var i = 0; i < _pathN; i++) {
            _pathX[i] = _ox + (raw[i * 2] * _side) / 100;
            _pathY[i] = _oy + (raw[i * 2 + 1] * _side) / 100;
        }
        _pathLen[0] = 0.0;
        _pathDx[0] = 1.0;
        _pathDy[0] = 0.0;
        for (var i = 1; i < _pathN; i++) {
            var dx = _pathX[i] - _pathX[i - 1];
            var dy = _pathY[i] - _pathY[i - 1];
            var len = Math.sqrt(dx * dx + dy * dy).toFloat();
            if (len < 0.5) { len = 0.5; }
            _pathLen[i] = _pathLen[i - 1] + len;
            _pathDx[i] = dx / len;
            _pathDy[i] = dy / len;
        }
        _pathTotal = _pathLen[_pathN - 1];
        if (_pathTotal < 1.0) { _pathTotal = 1.0; }

        // Straight-line air route. Flyer speed is rescaled per map so the
        // shortcut is worth roughly a 40% time saving everywhere instead of
        // being a free win on the switchback map.
        var fx = _pathX[_pathN - 1] - _pathX[0];
        var fy = _pathY[_pathN - 1] - _pathY[0];
        _flyLen = Math.sqrt(fx * fx + fy * fy).toFloat();
        if (_flyLen < 1.0) { _flyLen = 1.0; }
        _flyDx = fx / _flyLen;
        _flyDy = fy / _flyLen;
        _flyMul = (_flyLen / _pathTotal) / 0.60;
        if (_flyMul < 0.25) { _flyMul = 0.25; }
        if (_flyMul > 1.60) { _flyMul = 1.60; }

        var pads = TdMap.pads(_mapIdx);
        _padN = pads.size() / 2;
        if (_padN > TD_MAX_PADS) { _padN = TD_MAX_PADS; }
        for (var i = 0; i < _padN; i++) {
            _padX[i] = _ox + (pads[i * 2] * _side) / 100;
            _padY[i] = _oy + (pads[i * 2 + 1] * _side) / 100;
        }
        for (var i = 0; i < _padN; i++) { _padTower[i] = -1; }
        for (var i = 0; i < TD_MAX_TOWERS; i++) {
            if (!_twAlive[i]) { continue; }
            var p = _twPad[i];
            if (p >= 0 && p < _padN) {
                _padTower[p] = i;
                _twX[i] = _padX[p];
                _twY[i] = _padY[p];
            }
        }
        if (_cursor > _padN) { _cursor = 0; }
        _bakeTerrain();
    }

    // ── Terrain baking ──────────────────────────────────────────────────────

    hidden function _bakeTerrain() as Void {
        var want = _fine ? TD_MAX_DECO : 18;
        var px = _side / 40;
        if (px < 2) { px = 2; }
        var n = 0;
        for (var i = 0; i < want && n < TD_MAX_DECO; i++) {
            var hx = TdUtil.hash3(_mapIdx, i, 3) % 100;
            var hy = TdUtil.hash3(_mapIdx, i, 19) % 100;
            var x = _ox + (hx * _side) / 100;
            var y = _oy + (hy * _side) / 100;
            // Keep the scatter off the road and inside the bezel.
            if (_distToPath(x, y) < _pw) { continue; }
            var ddx = x - _cx;
            var ddy = y - _cy;
            if (ddx * ddx + ddy * ddy > (_rad - px * 2) * (_rad - px * 2)) { continue; }
            var kind = TdUtil.hash3(i, _mapIdx, 41) % 10;
            var col = TD_C_GRASS3;
            var s = px;
            if (kind < 3)      { col = TdUtil.mix(TD_C_GRASS2, 0x4E8A52, 45); }
            else if (kind < 5) { col = TdUtil.shade(TD_C_GRASS, 62); s = px + px / 2; }
            else if (kind < 7) { col = 0x6E7466; s = px - 1; }
            else if (kind < 9) { col = TdUtil.shade(TD_C_GRASS2, 130); s = px - 1; }
            if (s < 2) { s = 2; }
            _decoX[n] = x - s / 2;
            _decoY[n] = y - s / 2;
            _decoS[n] = s;
            _decoC[n] = col;
            n++;
        }
        _decoN = n;
        _bakeProps();
        _bakeCobbles();
    }

    // Trees and boulders. The size is derived from how much clear ground the
    // candidate actually has rather than rolled: sizing first and rejecting
    // afterwards fills the map with the smallest prop, because that is the one
    // that fits. Rocks are the fallback for tight gaps, and stay rare — they
    // are grey discs, and so are the empty build pads.
    hidden function _bakeProps() as Void {
        var want = _fine ? TD_MAX_PROP : 5;
        var base = _side / 14;
        if (base < 4) { base = 4; }
        var n = 0;
        for (var i = 0; i < 48 && n < want; i++) {
            var hx = TdUtil.hash3(_mapIdx, i, 53) % 100;
            var hy = TdUtil.hash3(_mapIdx, i, 71) % 100;
            var x = _ox + (hx * _side) / 100;
            var y = _oy + (hy * _side) / 100;

            var room = _distToPath(x, y) - _pw / 2 - 3;
            for (var p = 0; p < _padN; p++) {
                var dd = TdUtil.dist2(x, y, _padX[p], _padY[p]);
                var gap = Math.sqrt(dd.toFloat()).toNumber() - (_tu * 3) / 2;
                if (gap < room) { room = gap; }
            }
            var ddx = x - _cx;
            var ddy = y - _cy;
            var edge = _rad - Math.sqrt((ddx * ddx + ddy * ddy).toFloat()).toNumber();
            if (edge < room) { room = edge; }

            var s = (room * 70) / 100;
            if (s > base) { s = base; }
            var small = (base * 50) / 100;
            // Anything below half size is clutter at this scale, so a cramped
            // spot gets a boulder or nothing at all.
            if (s < small) {
                if (s < 5) { continue; }
                _propX[n] = x; _propY[n] = y; _propS[n] = s; _propK[n] = 1;
                n++;
                continue;
            }
            var rock = (TdUtil.hash3(i, _mapIdx, 89) % 5 == 0);
            if (rock) { s = (s * 60) / 100; }

            _propX[n] = x;
            _propY[n] = y;
            _propS[n] = s;
            _propK[n] = rock ? 1 : 0;
            n++;
        }
        _propN = n;
    }

    // Walk the path and drop paired cobbles either side of the centre line.
    // Baked once so the road never costs trigonometry at draw time.
    hidden function _bakeCobbles() as Void {
        var cs = _pw / 3;
        if (cs < 2) { cs = 2; }
        var step = cs + 2;
        var m = 0;
        var d = step;
        var seg = 1;
        while (d < _pathTotal && m < TD_MAX_STONE - 1) {
            while (seg < _pathN && _pathLen[seg] < d) { seg++; }
            if (seg >= _pathN) { break; }
            var t = (d - _pathLen[seg - 1]) / (_pathLen[seg] - _pathLen[seg - 1]);
            var bx = _pathX[seg - 1] + (_pathX[seg] - _pathX[seg - 1]) * t;
            var by = _pathY[seg - 1] + (_pathY[seg] - _pathY[seg - 1]) * t;
            var nx = -_pathDy[seg];
            var ny = _pathDx[seg];
            var lane = (m % 3) - 1;      // -1, 0, +1 across the road
            var off = (lane * _pw) / 3;
            var jitter = (TdUtil.hash3(m, _mapIdx, 7) % 3) - 1;
            var sz = cs + (TdUtil.hash3(m, _mapIdx, 13) % 2);
            var shadeP = 78 + (TdUtil.hash3(m, _mapIdx, 29) % 45);
            _cobX[m] = (bx + nx * off).toNumber() - sz / 2 + jitter;
            _cobY[m] = (by + ny * off).toNumber() - sz / 2;
            _cobS[m] = sz;
            _cobC[m] = TdUtil.shade(TD_C_STONE, shadeP);
            m++;
            d += step;
        }
        _cobN = m;
    }

    hidden function _distToPath(x, y) as Lang.Float {
        var best = 99999.0;
        for (var i = 1; i < _pathN; i++) {
            var ax = _pathX[i - 1];
            var ay = _pathY[i - 1];
            var bx = _pathX[i] - ax;
            var by = _pathY[i] - ay;
            var l2 = (bx * bx + by * by).toFloat();
            if (l2 < 1.0) { continue; }
            var t = ((x - ax) * bx + (y - ay) * by) / l2;
            if (t < 0.0) { t = 0.0; }
            if (t > 1.0) { t = 1.0; }
            var px = ax + bx * t - x;
            var py = ay + by * t - y;
            var d = Math.sqrt(px * px + py * py).toFloat();
            if (d < best) { best = d; }
        }
        return best;
    }

    // ── Save / resume ───────────────────────────────────────────────────────

    function exportSave() as Lang.Dictionary or Null {
        if (_phase == TD_OVER) { return null; }
        if (_wave <= 1 && !_anyTower() && _phase == TD_BUILD) { return null; }
        var tt = [];
        var tp = [];
        var tl = [];
        var tg = [];
        var ts = [];
        for (var i = 0; i < TD_MAX_TOWERS; i++) {
            if (!_twAlive[i]) { continue; }
            tt.add(_twType[i]);
            tp.add(_twPad[i]);
            tl.add(_twTier[i]);
            tg.add(_twTgt[i]);
            ts.add(_twSpent[i]);
        }
        return {
            "wave"  => _wave,
            "coins" => _coins,
            "hp"    => _baseHp,
            "kills" => _kills,
            "leaks" => _leaks,
            "dmg"   => _dmgDealt,
            "score" => _score,
            "map"   => _mapIdx,
            "diff"  => _diff,
            "daily" => _daily ? 1 : 0,
            "seed"  => _seed,
            "ab0"   => _abCd[TDA_STRIKE],
            "ab1"   => _abCd[TDA_FREEZE],
            "twT"   => tt,
            "twP"   => tp,
            "twL"   => tl,
            "twG"   => tg,
            "twS"   => ts
        };
    }

    function loadResume(data) as Void {
        if (data == null) { return; }
        _skipStart = true;
        try {
            _wave     = _num(data["wave"], 1);
            _coins    = _num(data["coins"], 120);
            _baseHp   = _num(data["hp"], 18);
            _kills    = _num(data["kills"], 0);
            _leaks    = _num(data["leaks"], 0);
            _dmgDealt = _num(data["dmg"], 0);
            _score    = _num(data["score"], 0);
            _mapIdx   = _num(data["map"], TdUtil.mapIndex());
            _diff     = _num(data["diff"], TdUtil.difficulty());
            _daily    = _num(data["daily"], 0) == 1;
            _seed     = _num(data["seed"], _mapIdx * 97 + _diff * 31 + 7);
            _paceN    = TdUtil.pace();
            _hints    = TdUtil.hintsOn();

            _baseMax = TD_BASE_HP_NORMAL;
            if (_diff == 0)      { _baseMax = TD_BASE_HP_EASY; }
            else if (_diff == 2) { _baseMax = TD_BASE_HP_HARD; }
            if (_baseHp > _baseMax) { _baseHp = _baseMax; }

            _configured = true;
            for (var i = 0; i < TD_MAX_TOWERS; i++) { _twAlive[i] = false; }
            for (var i = 0; i < TD_MAX_ENEMIES; i++) { _enAlive[i] = false; }
            for (var i = 0; i < TD_MAX_SHOTS; i++) { _shAlive[i] = false; }
            for (var i = 0; i < TD_MAX_FX; i++) { _fxLife[i] = 0; }
            for (var i = 0; i < TD_MAX_PADS; i++) { _padTower[i] = -1; }
            _loadMap();

            _abCd[TDA_STRIKE] = _num(data["ab0"], 0);
            _abCd[TDA_FREEZE] = _num(data["ab1"], 0);

            var tt = data["twT"];
            var tp = data["twP"];
            var tl = data["twL"];
            var tg = data["twG"];
            var ts = data["twS"];
            if (tt instanceof Lang.Array && tp instanceof Lang.Array) {
                var n = tt.size();
                for (var i = 0; i < n && i < TD_MAX_TOWERS; i++) {
                    var pad = -1;
                    if (tp[i] instanceof Lang.Number) { pad = tp[i]; }
                    var typ = TW_GUN;
                    if (tt[i] instanceof Lang.Number) { typ = tt[i]; }
                    if (pad < 0 || pad >= _padN) { continue; }
                    var ti = _allocTower(typ, pad);
                    if (ti < 0) { continue; }
                    if (tl instanceof Lang.Array && tl[i] instanceof Lang.Number) {
                        _twTier[ti] = TdUtil.clamp(tl[i], 1, 4);
                    }
                    if (tg instanceof Lang.Array && tg[i] instanceof Lang.Number) {
                        _twTgt[ti] = TdUtil.clamp(tg[i], 0, TDT_COUNT - 1);
                    }
                    if (ts instanceof Lang.Array && ts[i] instanceof Lang.Number) {
                        _twSpent[ti] = ts[i];
                    }
                }
            }
            _phase = TD_BUILD;
            _ui = TDUI_MAP;
            _cursor = 0;
            _announceWave();
            _toast = "RESUMED W" + _wave.format("%d");
            _toastTick = 25;
        } catch (e) {
            _skipStart = false;
        }
    }

    hidden function _num(v, def as Lang.Number) as Lang.Number {
        if (v instanceof Lang.Number) { return v; }
        return def;
    }

    hidden function _checkpoint() as Void {
        try {
            var d = exportSave();
            if (d != null) { SaveResume.save("towerdefense", d); }
        } catch (e) {}
    }

    hidden function _anyTower() as Lang.Boolean {
        for (var i = 0; i < TD_MAX_TOWERS; i++) {
            if (_twAlive[i]) { return true; }
        }
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INPUT
    // ═══════════════════════════════════════════════════════════════════════

    function navigate(dir as Lang.Number) as Void {
        if (_phase == TD_SUMMARY) { _leaveSummary(); return; }
        if (_phase == TD_OVER)    { return; }

        if (_ui == TDUI_MAP) {
            var n = _slotCount();
            _cursor = (_cursor + dir + n) % n;
            if (_cursor < _padN && _padTower[_cursor] >= 0) {
                _selTower = _padTower[_cursor];
            } else {
                _selTower = -1;
            }
            return;
        }
        var rows = _sheetRows();
        _row = (_row + dir + rows) % rows;
    }

    function doAction() as Void {
        if (_phase == TD_SUMMARY) { _leaveSummary(); return; }
        if (_phase == TD_OVER)    { _retry(); return; }

        if (_ui == TDUI_MAP) {
            if (_cursor >= _padN) { _startWave(); return; }
            if (_padTower[_cursor] >= 0) {
                _selTower = _padTower[_cursor];
                _ui = TDUI_TOWER;
                _row = 0;
            } else {
                _ui = TDUI_BUY;
                _row = 0;
            }
            return;
        }
        if (_ui == TDUI_BUY)     { _actBuy(); return; }
        if (_ui == TDUI_TOWER)   { _actTower(); return; }
        if (_ui == TDUI_ABILITY) { _actAbility(); return; }
    }

    // MENU is the "second button": it opens the ability sheet from the map and
    // backs out of any sheet, so a button-only watch never gets stranded.
    function toggleMenu() as Void {
        if (_phase == TD_SUMMARY) { _leaveSummary(); return; }
        if (_phase == TD_OVER)    { _retry(); return; }
        if (_ui == TDUI_MAP) {
            _ui = TDUI_ABILITY;
            _row = 0;
        } else {
            _ui = TDUI_MAP;
            _row = 0;
        }
    }

    function cancel() as Void {
        if (_ui != TDUI_MAP) {
            _ui = TDUI_MAP;
            _row = 0;
        }
    }

    // Touch. Pads are hit-tested directly so tapping the map is the fast path;
    // the ability chips and the bottom sheet are explicit rectangles.
    function tap(x as Lang.Number, y as Lang.Number) as Void {
        if (_phase == TD_SUMMARY) { _leaveSummary(); return; }
        if (_phase == TD_OVER)    { _retry(); return; }

        var chipR = _chipR();
        var chipY = _cy;
        if (TdUtil.dist2(x, y, _chipX(0), chipY) <= chipR * chipR * 2) {
            _castAbility(TDA_STRIKE);
            return;
        }
        if (TdUtil.dist2(x, y, _chipX(1), chipY) <= chipR * chipR * 2) {
            _castAbility(TDA_FREEZE);
            return;
        }

        var sheetTop = _sheetTop();
        if (y >= sheetTop) {
            doAction();
            return;
        }
        if (_ui != TDUI_MAP) {
            cancel();
            return;
        }

        // Nearest pad within a generous finger radius.
        var best = -1;
        var bestD = (_tu * 4) * (_tu * 4);
        for (var i = 0; i < _padN; i++) {
            var d = TdUtil.dist2(x, y, _padX[i], _padY[i]);
            if (d < bestD) { bestD = d; best = i; }
        }
        if (best >= 0) {
            _cursor = best;
            doAction();
            return;
        }
        if (_phase == TD_BUILD) {
            _cursor = _padN;   // tapping empty ground arms START
        }
    }

    hidden function _slotCount() as Lang.Number {
        if (_phase == TD_BUILD) { return _padN + 1; }
        return _padN;
    }

    hidden function _sheetRows() as Lang.Number {
        if (_ui == TDUI_BUY)     { return TW_COUNT + 1; }
        if (_ui == TDUI_TOWER)   { return 4; }
        if (_ui == TDUI_ABILITY) { return TDA_COUNT + 1; }
        return 1;
    }

    hidden function _leaveSummary() as Void {
        _phase = TD_BUILD;
        _ui = TDUI_MAP;
        _cursor = _padN;      // land on START so a fast player can chain waves
        _announceWave();
        _checkpoint();
    }

    hidden function _retry() as Void {
        try { SaveResume.clear("towerdefense"); } catch (e) {}
        _beginRun();
    }

    // ── Build actions ───────────────────────────────────────────────────────

    hidden function _actBuy() as Void {
        if (_row >= TW_COUNT) { cancel(); return; }
        var pad = _cursor;
        if (pad < 0 || pad >= _padN || _padTower[pad] >= 0) { cancel(); return; }
        var cost = TdUtil.towerCost(_row);
        if (_coins < cost) {
            _flash("NEED " + cost.format("%d") + "c");
            return;
        }
        var ti = _allocTower(_row, pad);
        if (ti < 0) { _flash("NO SLOTS"); return; }
        _coins -= cost;
        _twSpent[ti] = cost;
        _selTower = ti;
        _flash(TdUtil.towerName(_row) + " BUILT");
        _spawnFx(TDFX_RING, _padX[pad], _padY[pad], 0, 0, 10, TdUtil.towerColor(_row), null);
        _ui = TDUI_MAP;
        _checkpoint();
    }

    hidden function _actTower() as Void {
        var ti = _selTower;
        if (ti < 0 || !_twAlive[ti]) { cancel(); return; }
        if (_row == 0) {
            var tier = _twTier[ti];
            if (tier >= 4) { _flash("MAX TIER"); return; }
            var cost = TdUtil.upgradeCost(_twType[ti], tier);
            if (_coins < cost) {
                _flash("NEED " + cost.format("%d") + "c");
                return;
            }
            _coins -= cost;
            _twSpent[ti] += cost;
            _twTier[ti] = tier + 1;
            _flash("TIER " + (tier + 1).format("%d"));
            _spawnFx(TDFX_RING, _twX[ti], _twY[ti], 0, 0, 10,
                     TdUtil.towerColor(_twType[ti]), null);
            _checkpoint();
        } else if (_row == 1) {
            _twTgt[ti] = (_twTgt[ti] + 1) % TDT_COUNT;
            _twLock[ti] = -1;
            _checkpoint();
        } else if (_row == 2) {
            var refund = (_twSpent[ti] * 60) / 100;
            _coins += refund;
            _coinPop = 8;
            _spawnFx(TDFX_SMOKE, _twX[ti], _twY[ti], 0, 0, 12, 0x8A8A8A, null);
            _padTower[_twPad[ti]] = -1;
            _twAlive[ti] = false;
            _selTower = -1;
            _flash("SOLD +" + refund.format("%d") + "c");
            _ui = TDUI_MAP;
            _checkpoint();
        } else {
            cancel();
        }
    }

    hidden function _actAbility() as Void {
        if (_row >= TDA_COUNT) { cancel(); return; }
        _castAbility(_row);
    }

    hidden function _castAbility(a as Lang.Number) as Void {
        if (_abCd[a] > 0) {
            _flash("COOLING " + ((_abCd[a] * TD_TICK_MS) / 1000 + 1).format("%d") + "s");
            return;
        }
        var cost = TdUtil.abilityCost(a);
        if (_coins < cost) {
            _flash("NEED " + cost.format("%d") + "c");
            return;
        }
        var used = false;
        if (a == TDA_STRIKE) { used = _doStrike(); }
        else                 { used = _doFreeze(); }
        if (!used) {
            _flash("NO TARGETS");
            return;
        }
        _coins -= cost;
        _abCd[a] = TdUtil.abilityCd(a);
        _ui = TDUI_MAP;
    }

    // Bombs the handful of enemies closest to the base — the pack that is
    // actually about to leak, which is what you reach for the ability to fix.
    hidden function _doStrike() as Lang.Boolean {
        var hit = 0;
        var dmg = 45 + _wave * 14;
        for (var i = 0; i < TD_STRIKE_HITS; i++) { _abHit[i] = -1; }
        for (var pass = 0; pass < TD_STRIKE_HITS; pass++) {
            var best = -1;
            var bestP = -1.0;
            for (var e = 0; e < TD_MAX_ENEMIES; e++) {
                if (!_enAlive[e]) { continue; }
                var taken = false;
                for (var k = 0; k < pass; k++) {
                    if (_abHit[k] == e) { taken = true; }
                }
                if (taken) { continue; }
                if (_enProg[e] > bestP) { bestP = _enProg[e]; best = e; }
            }
            if (best < 0) { break; }
            _abHit[pass] = best;
            if (hit < 4) {
                _spawnFx(TDFX_BOOM, _enX[best].toNumber(), _enY[best].toNumber(),
                         0, 0, 14, 0xFF9A3A, null);
            }
            _hit(best, dmg, -1, true, true);
            hit++;
        }
        if (hit > 0) { _shake = 8; }
        return hit > 0;
    }

    hidden function _doFreeze() as Lang.Boolean {
        var hit = 0;
        for (var e = 0; e < TD_MAX_ENEMIES; e++) {
            if (!_enAlive[e]) { continue; }
            _enSlow[e] = 70;
            _hit(e, 12 + _wave * 2, -1, true, false);
            hit++;
        }
        if (hit > 0) {
            _spawnFx(TDFX_RING, _cx, _cy, 0, 0, 16, 0x66DCEE, null);
        }
        return hit > 0;
    }

    hidden function _allocTower(typ as Lang.Number, pad as Lang.Number) as Lang.Number {
        for (var i = 0; i < TD_MAX_TOWERS; i++) {
            if (_twAlive[i]) { continue; }
            _twAlive[i]  = true;
            _twType[i]   = typ;
            _twTier[i]   = 1;
            _twPad[i]    = pad;
            _twX[i]      = _padX[pad];
            _twY[i]      = _padY[pad];
            _twCd[i]     = 0;
            _twDx[i]     = 1.0;
            _twDy[i]     = 0.0;
            _twRecoil[i] = 0;
            _twHot[i]    = 0;
            _twTgt[i]    = TDT_FIRST;
            _twLock[i]   = -1;
            _twSpent[i]  = TdUtil.towerCost(typ);
            _twKills[i]  = 0;
            _twDmg[i]    = 0;
            _twWk[i]     = 0;
            _twWd[i]     = 0;
            _padTower[pad] = i;
            return i;
        }
        return -1;
    }

    hidden function _flash(msg as Lang.String) as Void {
        _toast = msg;
        _toastTick = 18;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // WAVE FLOW
    // ═══════════════════════════════════════════════════════════════════════

    hidden function _announceWave() as Void {
        _waveMod = TdUtil.waveMod(_seed, _wave);
        _waveTotal = TdUtil.waveCount(_seed, _wave, _diff);
        if (_waveMod != TDW_NONE) {
            _banner = TdUtil.modName(_waveMod);
            _bannerTick = 34;
        } else {
            _banner = null;
            _bannerTick = 0;
        }
    }

    hidden function _startWave() as Void {
        _phase = TD_WAVE;
        _ui = TDUI_MAP;
        if (_cursor >= _padN) { _cursor = 0; }
        _waveKills = 0;
        _waveDmg = 0;
        _waveLeaks = 0;
        _waveArmorSoak = 0;
        _waveAirLeak = 0;
        _spawnLeft = _waveTotal;
        _spawnIdx = 0;
        _spawnGap = TdUtil.clamp(20 - _wave / 2, 7, 20);
        if (_waveMod == TDW_SWARM) { _spawnGap = (_spawnGap * 60) / 100; }
        if (_spawnGap < 4) { _spawnGap = 4; }
        _spawnTimer = 6;
        for (var i = 0; i < TD_MAX_TOWERS; i++) {
            _twWk[i] = 0;
            _twWd[i] = 0;
        }
        _flash("WAVE " + _wave.format("%d"));
    }

    hidden function _tickWave() as Void {
        if (_spawnLeft > 0) {
            _spawnTimer--;
            if (_spawnTimer <= 0) {
                var t = TdUtil.waveEnemy(_seed, _wave, _spawnIdx, _waveMod, _waveTotal);
                _spawnEnemy(t);
                _spawnIdx++;
                _spawnLeft--;
                _spawnTimer = _spawnGap;
            }
        }
        _moveEnemies();
        _towerThink();
        _moveShots();
        _tickFx();

        if (_baseHp <= 0) {
            _baseHp = 0;
            _won = false;
            _phase = TD_OVER;
            _tip = _diagnose(true);
            _score = _finalScore();
            return;
        }
        if (_spawnLeft <= 0 && !_anyEnemy()) { _endWave(); }
    }

    hidden function _anyEnemy() as Lang.Boolean {
        for (var i = 0; i < TD_MAX_ENEMIES; i++) {
            if (_enAlive[i]) { return true; }
        }
        return false;
    }

    hidden function _endWave() as Void {
        _clearBonus = 18 + _wave * 4;
        if (_diff == 2) { _clearBonus += 6; }
        // Interest on the bank: hoarding is a real strategy, but capped so it
        // can never outrun the cost curve.
        _interest = (_coins * 6) / 100;
        if (_interest > 45) { _interest = 45; }
        _coins += _clearBonus + _interest;
        _coinPop = 10;
        _score = _finalScore();
        _tip = _diagnose(false);
        _summaryTick = 0;

        for (var i = 0; i < TD_MAX_SHOTS; i++) { _shAlive[i] = false; }

        if (_wave >= TD_MAX_WAVES) {
            _won = true;
            _phase = TD_OVER;
            _score = _finalScore();
            return;
        }
        _wave++;
        _phase = TD_SUMMARY;
        try { Progress.addCoins(4); Progress.addXp(8); } catch (e) {}
    }

    hidden function _finalScore() as Lang.Number {
        var s = _wave * 1000 + _kills * 12 + _coins + _dmgDealt / 10;
        if (_won) { s += 6000; }
        return s;
    }

    // Reads the wave that just happened and names the actual failure, rather
    // than printing a generic tip. Ordered most-specific first.
    hidden function _diagnose(fatal as Lang.Boolean) as Lang.String {
        var air = 0;
        var pierce = 0;
        var slow = 0;
        var idle = -1;
        var n = 0;
        for (var i = 0; i < TD_MAX_TOWERS; i++) {
            if (!_twAlive[i]) { continue; }
            n++;
            if (TdUtil.towerHitsAir(_twType[i]))  { air++; }
            if (TdUtil.towerPierces(_twType[i]))  { pierce++; }
            if (_twType[i] == TW_FROST)           { slow++; }
            if (_twWd[i] == 0 && idle < 0)        { idle = i; }
        }
        if (n == 0) { return "Build a tower on a pad"; }
        if (_waveAirLeak > 0 && air < 2)   { return "Flyers got through - add ARCHER"; }
        if (_waveArmorSoak > _waveDmg / 3 && pierce == 0) {
            return "Armor ate your damage - SNIPER";
        }
        if (fatal && _waveLeaks > 0 && slow == 0) { return "Too fast - FROST buys time"; }
        if (_waveLeaks > 2)                { return "Stack towers at one corner"; }
        if (_waveLeaks > 0)                { return "Leak at wave " + _wave.format("%d") + " - tier up"; }
        if (idle >= 0) {
            return TdUtil.towerName(_twType[idle]) + " never fired - sell it";
        }
        if (_coins > 260)                  { return "Banking " + _coins.format("%d") + "c - spend some"; }
        if (_wave % 5 == 0)                { return "Boss next - stack raw damage"; }
        if (n < 4)                         { return "More towers beats more tiers"; }
        return "Clean sweep - tier up your best";
    }

    // ── Enemies ─────────────────────────────────────────────────────────────

    hidden function _spawnEnemy(typ as Lang.Number) as Void {
        for (var i = 0; i < TD_MAX_ENEMIES; i++) {
            if (_enAlive[i]) { continue; }
            var hp = TdUtil.enemyHp(typ, _wave, _diff);
            if (_waveMod == TDW_SWARM) { hp = (hp * 70) / 100; }
            _enAlive[i] = true;
            _enType[i]  = typ;
            _enHp[i]    = hp;
            _enMax[i]   = hp;
            _enProg[i]  = 0.0;
            _enSlow[i]  = 0;
            _enFlash[i] = 0;
            _enBuff[i]  = 0;
            _enBurn[i]  = 0;
            _enAux[i]   = 0;
            var ar = TdUtil.enemyArmor(typ, _wave);
            if (_waveMod == TDW_ARMORED) { ar += 4 + _wave / 6; }
            _enArmor[i] = ar;
            _enX[i] = _pathX[0];
            _enY[i] = _pathY[0];
            if (TdUtil.isFlying(typ)) {
                _enDx[i] = _flyDx;
                _enDy[i] = _flyDy;
            } else {
                _enDx[i] = _pathDx[1];
                _enDy[i] = _pathDy[1];
            }
            _spawnFx(TDFX_SPARK, _pathX[0], _pathY[0], 0, 0, 6, 0xC898FF, null);
            return;
        }
    }

    hidden function _moveEnemies() as Void {
        var base = (1.4 + _wave * 0.02) * _paceN / 10.0 * _sc;
        for (var i = 0; i < TD_MAX_ENEMIES; i++) {
            if (!_enAlive[i]) { continue; }
            if (_enFlash[i] > 0) { _enFlash[i]--; }
            var typ = _enType[i];
            var spd = TdUtil.enemySpeed(typ) * base;
            if (TdUtil.isFlying(typ)) { spd = _flyMul * base; }
            if (_waveMod == TDW_SPEED) { spd *= 1.35; }
            if (typ == EN_BOSS && _enBuff[i] > 0 && TdUtil.bossAbility(_wave) == 0) {
                spd *= 1.6;
            }
            if (_enSlow[i] > 0) {
                spd *= 0.42;
                _enSlow[i]--;
            }
            if (_enBurn[i] > 0) {
                _enBurn[i]--;
                if (_tick % 4 == 0) { _hit(i, 2 + _wave / 4, -1, true, false); }
                if (!_enAlive[i]) { continue; }
            }
            _enProg[i] = _enProg[i] + spd;
            var total = _pathTotal;
            if (TdUtil.isFlying(typ)) { total = _flyLen; }
            if (_enProg[i] >= total) {
                _leak(i);
                continue;
            }
            _place(i);
            if (typ == EN_HEALER) { _healerTick(i); }
            else if (typ == EN_BOSS) { _bossTick(i); }
        }
    }

    hidden function _place(i as Lang.Number) as Void {
        if (TdUtil.isFlying(_enType[i])) {
            _enX[i] = _pathX[0] + _flyDx * _enProg[i];
            _enY[i] = _pathY[0] + _flyDy * _enProg[i];
            return;
        }
        var p = _enProg[i];
        var seg = 1;
        while (seg < _pathN && _pathLen[seg] < p) { seg++; }
        if (seg >= _pathN) { seg = _pathN - 1; }
        var a = _pathLen[seg - 1];
        var b = _pathLen[seg];
        var t = 0.0;
        if (b > a) { t = (p - a) / (b - a); }
        _enX[i] = _pathX[seg - 1] + (_pathX[seg] - _pathX[seg - 1]) * t;
        _enY[i] = _pathY[seg - 1] + (_pathY[seg] - _pathY[seg - 1]) * t;
        _enDx[i] = _pathDx[seg];
        _enDy[i] = _pathDy[seg];
    }

    hidden function _leak(i as Lang.Number) as Void {
        var typ = _enType[i];
        _enAlive[i] = false;
        var d = TdUtil.enemyLeakDmg(typ);
        _baseHp -= d;
        if (_baseHp < 0) { _baseHp = 0; }
        _leaks++;
        _waveLeaks++;
        if (TdUtil.isFlying(typ)) { _waveAirLeak++; }
        _shake = 7 + d;
        _edge = 9;
        var bx = _pathX[_pathN - 1];
        var by = _pathY[_pathN - 1];
        _spawnFx(TDFX_TEXT, bx, by - _u * 2, 0, 0, 14, TD_C_DANGER, "-" + d.format("%d"));
        _spawnFx(TDFX_RING, bx, by, 0, 0, 10, TD_C_DANGER, null);
    }

    // Healers top up the two most wounded neighbours; the beam is the tell
    // that says "kill this one first".
    hidden function _healerTick(i as Lang.Number) as Void {
        _enAux[i]++;
        if (_enAux[i] < 26) { return; }
        _enAux[i] = 0;
        var r = (_sc * 22).toNumber();
        var r2 = r * r;
        var done = 0;
        for (var e = 0; e < TD_MAX_ENEMIES && done < 2; e++) {
            if (!_enAlive[e] || e == i) { continue; }
            if (_enHp[e] >= _enMax[e]) { continue; }
            if (TdUtil.dist2(_enX[i], _enY[i], _enX[e], _enY[e]) > r2) { continue; }
            var heal = _enMax[e] / 12 + 3;
            _enHp[e] += heal;
            if (_enHp[e] > _enMax[e]) { _enHp[e] = _enMax[e]; }
            _spawnFx(TDFX_BOLT, _enX[i].toNumber(), _enY[i].toNumber(),
                     _enX[e].toNumber(), _enY[e].toNumber(), 4, 0x6FE3A6, null);
            done++;
        }
    }

    hidden function _bossTick(i as Lang.Number) as Void {
        var ab = TdUtil.bossAbility(_wave);
        _enAux[i]++;
        if (_enBuff[i] > 0) { _enBuff[i]--; }
        if (ab == 0) {
            // RAGE: permanently enraged once badly hurt.
            if (_enHp[i] * 2 < _enMax[i]) { _enBuff[i] = 2; }
        } else if (ab == 1) {
            // WARD: cycles a heavy armour shell on and off.
            if (_enAux[i] >= 55) {
                _enAux[i] = 0;
                _enBuff[i] = 26;
                _spawnFx(TDFX_RING, _enX[i].toNumber(), _enY[i].toNumber(),
                         0, 0, 10, 0x2A6AA8, null);
            }
        } else if (ab == 2) {
            // SUMMON: escorts spawn beside it, already down the path.
            if (_enAux[i] >= 45) {
                _enAux[i] = 0;
                for (var k = 0; k < 2; k++) { _summonAt(_enProg[i]); }
                _spawnFx(TDFX_RING, _enX[i].toNumber(), _enY[i].toNumber(),
                         0, 0, 10, 0x6A2A9A, null);
            }
        } else {
            // REGEN: a steady trickle that punishes a slow kill.
            if (_enAux[i] >= 9) {
                _enAux[i] = 0;
                _enHp[i] += _enMax[i] / 90 + 2;
                if (_enHp[i] > _enMax[i]) { _enHp[i] = _enMax[i]; }
                _spawnFx(TDFX_SPARK, _enX[i].toNumber(), _enY[i].toNumber() - _u,
                         0, 0, 5, 0x6FE3A6, null);
            }
        }
    }

    hidden function _summonAt(prog as Lang.Float) as Void {
        for (var i = 0; i < TD_MAX_ENEMIES; i++) {
            if (_enAlive[i]) { continue; }
            var hp = (TdUtil.enemyHp(EN_GRUNT, _wave, _diff) * 70) / 100;
            _enAlive[i] = true;
            _enType[i]  = EN_GRUNT;
            _enHp[i]    = hp;
            _enMax[i]   = hp;
            _enProg[i]  = prog;
            _enSlow[i]  = 0;
            _enFlash[i] = 0;
            _enBuff[i]  = 0;
            _enBurn[i]  = 0;
            _enAux[i]   = 0;
            _enArmor[i] = 0;
            _place(i);
            return;
        }
    }

    // ── Towers ──────────────────────────────────────────────────────────────

    // Between waves towers slowly sweep back to a rest pose so the field is
    // not frozen mid-aim while you shop.
    hidden function _idleTowers() as Void {
        for (var i = 0; i < TD_MAX_TOWERS; i++) {
            if (!_twAlive[i]) { continue; }
            if (_twRecoil[i] > 0) { _twRecoil[i] = _twRecoil[i] * 2 / 3; }
            if (_twHot[i] > 0) { _twHot[i]--; }
            _aimAt(i, _pathX[_pathN / 2], _pathY[_pathN / 2], 8);
        }
    }

    hidden function _towerThink() as Void {
        for (var i = 0; i < TD_MAX_TOWERS; i++) {
            if (!_twAlive[i]) { continue; }
            if (_twRecoil[i] > 0) { _twRecoil[i] = _twRecoil[i] * 2 / 3; }
            if (_twHot[i] > 0) { _twHot[i]--; }

            var typ = _twType[i];
            var rng = (TdUtil.towerRangePct(typ, _twTier[i]) * _side) / 100;
            var rng2 = rng * rng;

            // Keep tracking the locked target while reloading; only pay for a
            // full scan when the tower can actually shoot or has lost its mark.
            var lock = _twLock[i];
            var valid = false;
            if (lock >= 0 && _enAlive[lock]) {
                if (!(TdUtil.isFlying(_enType[lock]) && !TdUtil.towerHitsAir(typ))) {
                    if (TdUtil.dist2(_twX[i], _twY[i], _enX[lock], _enY[lock]) <= rng2) {
                        valid = true;
                    }
                }
            }
            if (_twCd[i] > 0) {
                _twCd[i]--;
                if (valid) { _aimAt(i, _enX[lock], _enY[lock], 3); }
                continue;
            }
            if (!valid) {
                lock = _acquire(i, typ, rng2);
                _twLock[i] = lock;
            }
            if (lock < 0) { continue; }
            _aimAt(i, _enX[lock], _enY[lock], 2);
            _fire(i, lock, rng);
            _twCd[i] = TdUtil.towerCooldown(typ, _twTier[i]);
        }
    }

    hidden function _acquire(ti as Lang.Number, typ as Lang.Number,
                             rng2 as Lang.Number) as Lang.Number {
        var mode = _twTgt[ti];
        var best = -1;
        var bestV = -1;
        var air = TdUtil.towerHitsAir(typ);
        for (var e = 0; e < TD_MAX_ENEMIES; e++) {
            if (!_enAlive[e]) { continue; }
            if (!air && TdUtil.isFlying(_enType[e])) { continue; }
            var d2 = TdUtil.dist2(_twX[ti], _twY[ti], _enX[e], _enY[e]);
            if (d2 > rng2) { continue; }
            var v = 0;
            if (mode == TDT_FIRST)       { v = _enProg[e].toNumber(); }
            else if (mode == TDT_STRONG) { v = _enHp[e]; }
            else                         { v = 1000000 - d2; }
            if (v > bestV) { bestV = v; best = e; }
        }
        return best;
    }

    // Turrets swing toward their mark instead of snapping, which is most of
    // what makes them read as machines rather than sprites. `lag` is the
    // divisor: smaller turns faster.
    hidden function _aimAt(ti as Lang.Number, tx, ty, lag as Lang.Number) as Void {
        var dx = tx - _twX[ti];
        var dy = ty - _twY[ti];
        var d = Math.sqrt(dx * dx + dy * dy).toFloat();
        if (d < 0.5) { return; }
        var nx = dx / d;
        var ny = dy / d;
        var cx2 = _twDx[ti] + (nx - _twDx[ti]) / lag;
        var cy2 = _twDy[ti] + (ny - _twDy[ti]) / lag;
        var m = Math.sqrt(cx2 * cx2 + cy2 * cy2).toFloat();
        if (m < 0.01) { return; }
        _twDx[ti] = cx2 / m;
        _twDy[ti] = cy2 / m;
    }

    hidden function _fire(ti as Lang.Number, ei as Lang.Number, rng as Lang.Number) as Void {
        var typ = _twType[ti];
        var tier = _twTier[ti];
        var dmg = TdUtil.towerDmg(typ, tier);
        _twHot[ti] = 2;

        if (typ == TW_FROST) {
            var r2 = rng * rng;
            var chill = 22;
            if (tier >= 4) { chill = 40; }
            for (var e = 0; e < TD_MAX_ENEMIES; e++) {
                if (!_enAlive[e]) { continue; }
                if (TdUtil.dist2(_twX[ti], _twY[ti], _enX[e], _enY[e]) > r2) { continue; }
                if (_enSlow[e] < chill) { _enSlow[e] = chill; }
                _hit(e, dmg, ti, false, false);
            }
            _spawnFx(TDFX_RING, _twX[ti], _twY[ti], 0, 0, 9, 0x66DCEE, null);
            return;
        }

        if (typ == TW_TESLA) {
            var hops = 1;
            if (tier >= 2) { hops = 2; }
            if (tier >= 3) { hops = 3; }
            if (tier >= 4) { hops = 4; }
            var fromX = _twX[ti];
            var fromY = _twY[ti];
            var cur = ei;
            var d = dmg;
            var prev = -1;
            for (var k = 0; k < hops && cur >= 0; k++) {
                _spawnFx(TDFX_BOLT, fromX.toNumber(), fromY.toNumber(),
                         _enX[cur].toNumber(), _enY[cur].toNumber(), 4, 0xC98CFF, null);
                fromX = _enX[cur];
                fromY = _enY[cur];
                _hit(cur, d, ti, true, k == 0);
                d = (d * 70) / 100;
                prev = cur;
                cur = _nearestExcept(fromX, fromY, (rng * 55) / 100, prev);
            }
            return;
        }

        if (typ == TW_FLAME) {
            // Cone: everything within range whose bearing is inside ~60 deg of
            // the nozzle. Dot product against the aim vector, no trig.
            var r2b = rng * rng;
            var tipX = _twX[ti] + _twDx[ti] * rng;
            var tipY = _twY[ti] + _twDy[ti] * rng;
            _spawnFx(TDFX_FLAME, _twX[ti], _twY[ti],
                     tipX.toNumber(), tipY.toNumber(), 5, 0xFF8A3A, null);
            for (var e = 0; e < TD_MAX_ENEMIES; e++) {
                if (!_enAlive[e]) { continue; }
                if (TdUtil.isFlying(_enType[e])) { continue; }
                var ex = _enX[e] - _twX[ti];
                var ey = _enY[e] - _twY[ti];
                var dd = ex * ex + ey * ey;
                if (dd > r2b || dd < 1) { continue; }
                var dl = Math.sqrt(dd).toFloat();
                if ((ex * _twDx[ti] + ey * _twDy[ti]) / dl < 0.5) { continue; }
                _hit(e, dmg, ti, false, false);
                if (tier >= 4 && _enAlive[e]) { _enBurn[e] = 30; }
            }
            return;
        }

        if (typ == TW_SNIPER) {
            var crit = false;
            if (tier >= 4 && (TdUtil.hash3(_tick, ti, ei) % 100) < 30) { crit = true; }
            var out = dmg;
            if (crit) { out = dmg * 2; }
            _spawnFx(TDFX_TRACER, _twX[ti], _twY[ti],
                     _enX[ei].toNumber(), _enY[ei].toNumber(), 5, 0xFFF0B0, null);
            _spawnFx(TDFX_MUZZLE,
                     (_twX[ti] + _twDx[ti] * _tu * 2).toNumber(),
                     (_twY[ti] + _twDy[ti] * _tu * 2).toNumber(), 0, 0, 4, 0xFFFFFF, null);
            _twRecoil[ti] = _tu;
            _hit(ei, out, ti, true, true);
            return;
        }

        // Travelling projectiles lead the target by its current velocity so
        // fast movers do not eat free misses at long range.
        var shots = 1;
        if (typ == TW_ARCHER && tier >= 4) { shots = 2; }
        for (var s = 0; s < shots; s++) {
            var kind = 0;                       // 0 bullet, 1 arrow, 2 shell
            if (typ == TW_ARCHER)      { kind = 1; }
            else if (typ == TW_CANNON) { kind = 2; }
            var splash = 0;
            if (typ == TW_CANNON) {
                splash = ((14 + tier * 3) * _side) / 100 / 4;
                if (tier >= 4) { splash = (splash * 150) / 100; }
            }
            _launch(ti, ei, kind, dmg, splash, s);
        }
        if (typ == TW_CANNON) {
            _twRecoil[ti] = _tu * 3 / 2;
            _shake = 3;
        } else {
            _twRecoil[ti] = _tu / 2;
        }
        _spawnFx(TDFX_MUZZLE,
                 (_twX[ti] + _twDx[ti] * _tu * 15 / 10).toNumber(),
                 (_twY[ti] + _twDy[ti] * _tu * 15 / 10).toNumber(),
                 0, 0, 3, 0xFFF3C0, null);
    }

    hidden function _launch(ti, ei, kind, dmg, splash, spread) as Void {
        for (var s = 0; s < TD_MAX_SHOTS; s++) {
            if (_shAlive[s]) { continue; }
            var lead = 6.0;
            if (kind == 2) { lead = 12.0; }
            var tx = _enX[ei] + _enDx[ei] * lead * _sc * 0.2;
            var ty = _enY[ei] + _enDy[ei] * lead * _sc * 0.2;
            var dx = tx - _twX[ti];
            var dy = ty - _twY[ti];
            var d = Math.sqrt(dx * dx + dy * dy).toFloat();
            if (d < 1.0) { d = 1.0; }
            var nx = dx / d;
            var ny = dy / d;
            if (spread > 0) {
                // Second arrow fans out slightly instead of stacking exactly.
                var ox = -ny * 0.16;
                var oy = nx * 0.16;
                nx += ox;
                ny += oy;
                var m = Math.sqrt(nx * nx + ny * ny).toFloat();
                nx = nx / m;
                ny = ny / m;
            }
            _shAlive[s]  = true;
            _shKind[s]   = kind;
            _shX[s]      = _twX[ti] + nx * _tu;
            _shY[s]      = _twY[ti] + ny * _tu;
            _shDx[s]     = nx;
            _shDy[s]     = ny;
            _shGone[s]   = 0.0;
            _shTot[s]    = d;
            _shDmg[s]    = dmg;
            _shSplash[s] = splash;
            _shOwner[s]  = ti;
            return;
        }
    }

    hidden function _moveShots() as Void {
        var unit = _sc * _paceN / 10.0;
        for (var s = 0; s < TD_MAX_SHOTS; s++) {
            if (!_shAlive[s]) { continue; }
            var spd = 9.0 * unit;
            if (_shKind[s] == 1)      { spd = 8.0 * unit; }
            else if (_shKind[s] == 2) { spd = 5.0 * unit; }
            _shGone[s] = _shGone[s] + spd;
            _shX[s] = _shX[s] + _shDx[s] * spd;
            _shY[s] = _shY[s] + _shDy[s] * spd;
            if (_shGone[s] < _shTot[s] - spd / 2) {
                // Still in flight, but a body in the way stops a flat shot.
                if (_shKind[s] != 2) {
                    var e = _nearestExcept(_shX[s], _shY[s], _u + 2, -1);
                    if (e >= 0) { _impact(s, e); }
                }
                continue;
            }
            _impact(s, _nearestExcept(_shX[s], _shY[s], _u * 3, -1));
        }
    }

    hidden function _impact(s as Lang.Number, e as Lang.Number) as Void {
        var ti = _shOwner[s];
        var x = _shX[s].toNumber();
        var y = _shY[s].toNumber();
        _shAlive[s] = false;
        if (_shKind[s] == 2) {
            _spawnFx(TDFX_BOOM, x, y, 0, 0, 12, 0xFF9A3A, null);
            _spawnFx(TDFX_SMOKE, x, y, 0, 0, 14, 0x7A6A5A, null);
            var r = _shSplash[s];
            var r2 = r * r;
            var any = false;
            for (var k = 0; k < TD_MAX_ENEMIES; k++) {
                if (!_enAlive[k]) { continue; }
                if (TdUtil.isFlying(_enType[k])) { continue; }
                if (TdUtil.dist2(x, y, _enX[k], _enY[k]) > r2) { continue; }
                _hit(k, _shDmg[s], ti, false, !any);
                any = true;
            }
            return;
        }
        if (e < 0) { return; }
        _spawnFx(TDFX_SPARK, x, y, 0, 0, 5, 0xFFF0C0, null);
        _hit(e, _shDmg[s], ti, false, _shDmg[s] >= 12);
    }

    hidden function _nearestExcept(x, y, maxR, skip as Lang.Number) as Lang.Number {
        var best = -1;
        var bestD = maxR * maxR;
        for (var e = 0; e < TD_MAX_ENEMIES; e++) {
            if (!_enAlive[e] || e == skip) { continue; }
            var d2 = TdUtil.dist2(x, y, _enX[e], _enY[e]);
            if (d2 < bestD) { bestD = d2; best = e; }
        }
        return best;
    }

    // Central damage funnel: armour, attribution, feedback and death all live
    // here so no caller can forget one of them.
    hidden function _hit(ei as Lang.Number, dmg as Lang.Number, ti as Lang.Number,
                         pierce as Lang.Boolean, show as Lang.Boolean) as Void {
        if (ei < 0 || ei >= TD_MAX_ENEMIES || !_enAlive[ei]) { return; }
        var armor = _enArmor[ei];
        if (_enType[ei] == EN_BOSS && _enBuff[ei] > 0 && TdUtil.bossAbility(_wave) == 1) {
            armor = armor * 3;
        }
        if (pierce) { armor = armor / 3; }
        var eff = dmg - armor;
        if (eff < 1) { eff = 1; }
        var soak = dmg - eff;
        if (soak > 0) { _waveArmorSoak += soak; }

        _enHp[ei] -= eff;
        _enFlash[ei] = 2;
        _dmgDealt += eff;
        _waveDmg += eff;
        if (ti >= 0 && ti < TD_MAX_TOWERS && _twAlive[ti]) {
            _twDmg[ti] += eff;
            _twWd[ti] += eff;
        }
        if (show) {
            var col = 0xFFFFFF;
            if (soak > eff) { col = 0x9AA8B4; }
            _spawnFx(TDFX_TEXT, _enX[ei].toNumber(),
                     _enY[ei].toNumber() - _u, 0, 0, 12, col, eff.format("%d"));
        }
        if (_enHp[ei] > 0) { return; }

        var typ = _enType[ei];
        _enAlive[ei] = false;
        var reward = TdUtil.enemyReward(typ);
        if (_diff == 0) { reward += 1; }
        _coins += reward;
        _coinPop = 7;
        _kills++;
        _waveKills++;
        if (ti >= 0 && ti < TD_MAX_TOWERS && _twAlive[ti]) {
            _twKills[ti]++;
            _twWk[ti]++;
        }
        var ex = _enX[ei].toNumber();
        var ey = _enY[ei].toNumber();
        _spawnFx(TDFX_COIN, ex, ey, 0, 0, 14, TD_C_GOLD, null);
        _spawnFx(TDFX_SPARK, ex, ey, 0, 0, 7, TdUtil.enemyColor(typ), null);
        if (typ == EN_BOSS) {
            _spawnFx(TDFX_BOOM, ex, ey, 0, 0, 16, 0xFF3D77, null);
            _spawnFx(TDFX_TEXT, ex, ey - _u * 2, 0, 0, 16, TD_C_GOLD,
                     "+" + reward.format("%d"));
            _shake = 10;
        }
        // Clear stale locks so towers retarget on the same tick.
        for (var t = 0; t < TD_MAX_TOWERS; t++) {
            if (_twLock[t] == ei) { _twLock[t] = -1; }
        }
    }

    // ── Particles ───────────────────────────────────────────────────────────

    hidden function _spawnFx(kind, x, y, x2, y2, life, col, text) as Void {
        var slot = -1;
        var worst = 9999;
        for (var i = 0; i < TD_MAX_FX; i++) {
            if (_fxLife[i] <= 0) { slot = i; break; }
            if (_fxLife[i] < worst) { worst = _fxLife[i]; slot = i; }
        }
        if (slot < 0) { return; }
        _fxKind[slot] = kind;
        _fxLife[slot] = life;
        _fxMax[slot]  = life;
        _fxX[slot]    = x.toNumber();
        _fxY[slot]    = y.toNumber();
        _fxX2[slot]   = x2;
        _fxY2[slot]   = y2;
        _fxCol[slot]  = col;
        _fxText[slot] = text;
    }

    hidden function _tickFx() as Void {
        for (var i = 0; i < TD_MAX_FX; i++) {
            if (_fxLife[i] > 0) { _fxLife[i]--; }
        }
    }

    // ── Finish ──────────────────────────────────────────────────────────────

    hidden function _finishOnce() as Void {
        if (_lbHandled) { return; }
        _lbHandled = true;
        try { SaveResume.clear("towerdefense"); } catch (e) {}
        if (_wave > _bestWave) {
            _bestWave = _wave;
            try { Application.Storage.setValue("td_best", _bestWave); } catch (e) {}
        }
        _score = _finalScore();
        var variant = TdUtil.lbVariant();
        if (_daily) { variant = "daily"; }
        try {
            Leaderboard.submitScore(TD_LB_ID, _score, variant);
            Leaderboard.submitScore(TD_LB_ID, _wave, variant + "-wave");
            Leaderboard.showPostGame(TD_LB_ID, variant, "TOWER DEFENSE");
        } catch (e) {}
        try { Progress.addXp(_wave * 5); Progress.addCoins(_kills / 2); } catch (e) {}
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DRAW
    // ═══════════════════════════════════════════════════════════════════════

    function onUpdate(dc) {
        if (_w == null || _w == 0) { onLayout(dc); }
        TdArt.prep();
        TdArt.frame(_tick, _u);

        TdArt.ground(dc, _cx, _cy, _rad);
        TdArt.deco(dc, _decoN, _decoX, _decoY, _decoS, _decoC, _shx, _shy);
        TdArt.pathBody(dc, _pathN, _pathX, _pathY, _pw, _shx, _shy);
        TdArt.cobbles(dc, _cobN, _cobX, _cobY, _cobS, _cobC, _shx, _shy);
        TdArt.props(dc, _propN, _propX, _propY, _propS, _propK, _shx, _shy);
        TdArt.portal(dc, _pathX[0] + _shx, _pathY[0] + _shy, _tu);
        var hpPct = (_baseHp * 100) / _baseMax;
        TdArt.keep(dc, _pathX[_pathN - 1] + _shx, _pathY[_pathN - 1] + _shy, _tu, hpPct);

        _drawPads(dc);
        _drawRangePreview(dc);
        _drawTowers(dc);
        _drawEnemies(dc);
        _drawShots(dc);
        _drawFx(dc);

        _drawTopHud(dc);
        _drawChips(dc);
        _drawSheet(dc);

        if (_edge > 0) { _drawEdgeFlash(dc); }
        if (_bannerTick > 0 && _phase == TD_BUILD) { _drawBanner(dc); }
        if (_phase == TD_SUMMARY) { _drawSummary(dc); }
        else if (_phase == TD_OVER) { _drawOver(dc); }
        if (_toast != null && _toastTick > 0) { _drawToast(dc); }
    }

    hidden function _drawPads(dc) as Void {
        for (var i = 0; i < _padN; i++) {
            if (_padTower[i] >= 0) { continue; }
            var sel = (_ui != TDUI_ABILITY && i == _cursor);
            TdArt.pad(dc, _padX[i] + _shx, _padY[i] + _shy, _tu, sel);
        }
    }

    // One ring at a time: either the tower you are inspecting, or a preview of
    // what the highlighted shop entry would cover on this pad.
    hidden function _drawRangePreview(dc) as Void {
        if (_ui == TDUI_BUY && _cursor < _padN && _row < TW_COUNT) {
            var r = (TdUtil.towerRangePct(_row, 1) * _side) / 100;
            TdArt.rangeRing(dc, _padX[_cursor] + _shx, _padY[_cursor] + _shy, r,
                            TdUtil.shade(TdUtil.towerColor(_row), 75));
            return;
        }
        var ti = -1;
        if (_ui == TDUI_TOWER) { ti = _selTower; }
        else if (_ui == TDUI_MAP && _cursor < _padN) { ti = _padTower[_cursor]; }
        if (ti < 0 || !_twAlive[ti]) { return; }
        var rr = (TdUtil.towerRangePct(_twType[ti], _twTier[ti]) * _side) / 100;
        TdArt.rangeRing(dc, _twX[ti] + _shx, _twY[ti] + _shy, rr,
                        TdUtil.shade(TdUtil.towerColor(_twType[ti]), 75));
    }

    hidden function _drawTowers(dc) as Void {
        for (var i = 0; i < TD_MAX_TOWERS; i++) {
            if (!_twAlive[i]) { continue; }
            TdArt.aim(_twDx[i], _twDy[i]);
            TdArt.tower(dc, _twType[i], _twTier[i], _twX[i] + _shx, _twY[i] + _shy,
                        _tu, _twRecoil[i], _twHot[i] > 0);
            if (_ui != TDUI_ABILITY && _cursor < _padN && _padTower[_cursor] == i) {
                dc.setPenWidth(2);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(_twX[i] + _shx, _twY[i] + _shy, _tu * 3 / 2 + 2);
                dc.setPenWidth(1);
            }
        }
    }

    hidden function _drawEnemies(dc) as Void {
        for (var i = 0; i < TD_MAX_ENEMIES; i++) {
            if (!_enAlive[i]) { continue; }
            var typ = _enType[i];
            var r = TdUtil.enemyRadius(typ, _u);
            var x = _enX[i].toNumber() + _shx;
            var y = _enY[i].toNumber() + _shy;
            var pct = (_enHp[i] * 100) / _enMax[i];
            var extra = 0;
            if (typ == EN_SHIELD && _enFlash[i] > 0) { extra = 1; }
            else if (typ == EN_BOSS) { extra = TdUtil.bossAbility(_wave); }
            TdArt.aim(_enDx[i], _enDy[i]);
            TdArt.enemy(dc, typ, x, y, r, _enFlash[i], _enSlow[i], pct, extra);
            // Flyers draw their body two radii above the ground marker.
            var dy = y;
            if (typ == EN_FLYER) { dy = y - r * 2; }
            if (_enBurn[i] > 0) {
                dc.setColor(0xFF8A3A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x - 1, dy - r - 3, 2, 2);
            }
            // Slim HP bar for anything that survives more than a couple of hits.
            if ((typ == EN_TANK || typ == EN_SHIELD || typ == EN_HEALER) && pct < 100) {
                var bw = r * 2;
                dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x - bw / 2, dy - r - 4, bw, 2);
                dc.setColor(TD_C_HP, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x - bw / 2, dy - r - 4, (bw * pct) / 100, 2);
            }
        }
    }

    hidden function _drawShots(dc) as Void {
        for (var i = 0; i < TD_MAX_SHOTS; i++) {
            if (!_shAlive[i]) { continue; }
            var x = _shX[i].toNumber() + _shx;
            var y = _shY[i].toNumber() + _shy;
            if (_shKind[i] == 1) {
                TdArt.arrow(dc, x, y, _shDx[i], _shDy[i], _u);
            } else if (_shKind[i] == 2) {
                // Lob height peaks halfway to the impact point.
                var t = 0.0;
                if (_shTot[i] > 1.0) { t = _shGone[i] / _shTot[i]; }
                var hgt = (_u * 4 * (t - t * t) * 4).toNumber();
                TdArt.shell(dc, x, y, hgt, _u);
            } else {
                TdArt.bullet(dc, x, y, _shDx[i], _shDy[i], _u, 0xFFE9A0);
            }
        }
    }

    hidden function _drawFx(dc) as Void {
        for (var i = 0; i < TD_MAX_FX; i++) {
            if (_fxLife[i] <= 0) { continue; }
            var k = ((_fxMax[i] - _fxLife[i]) * 100) / _fxMax[i];
            TdArt.fx(dc, _fxKind[i], _fxX[i] + _shx, _fxY[i] + _shy,
                     _fxX2[i] + _shx, _fxY2[i] + _shy, k, _fxCol[i], _fxText[i]);
        }
    }

    hidden function _drawEdgeFlash(dc) as Void {
        var p = 10 - _edge;
        var col = TdUtil.mix(0xFF2A2A, TD_C_GRASS, p * 9);
        dc.setPenWidth(_rad / 9 + 3);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, _rad - 1);
        dc.setPenWidth(1);
    }

    // ── HUD ─────────────────────────────────────────────────────────────────

    // Widest a centred panel spanning y0..y1 can be and still sit inside the
    // bezel. Every HUD box is clamped through here, because a panel sized as a
    // percentage of the width is only safe across the middle of a round watch
    // — near the top and bottom the glass is a good deal narrower than that.
    hidden function _bandW(y0 as Lang.Number, y1 as Lang.Number) as Lang.Number {
        if (!_round) { return _w - 8; }
        var d0 = y0 - _cy;
        if (d0 < 0) { d0 = -d0; }
        var d1 = y1 - _cy;
        if (d1 < 0) { d1 = -d1; }
        var d = (d0 > d1) ? d0 : d1;
        var lim = _rad - 3;
        if (d >= lim) { return 16; }
        var half = Math.sqrt((lim * lim - d * d).toFloat()).toNumber();
        return half * 2;
    }

    hidden function _fitW(want as Lang.Number, y0 as Lang.Number,
                          y1 as Lang.Number) as Lang.Number {
        var lim = _bandW(y0, y1);
        return (want > lim) ? lim : want;
    }

    hidden function _drawTopHud(dc) as Void {
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var ph = fh + 10;
        var py = _round ? (_h * 9) / 100 : _h / 40 + 1;
        var pw = _fitW((_w * 58) / 100, py, py + ph);
        var px = _cx - pw / 2;
        TdArt.panel(dc, px, py, pw, ph, 0x0B1520, 0x243544);

        dc.setColor(TD_C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, py + 2, Graphics.FONT_XTINY,
                    "W" + _wave.format("%d") + "/" + TD_MAX_WAVES.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Wave progress: spawned vs total, killed shown as the filled part.
        var by = py + ph - 5;
        var bw = pw - 16;
        if (_phase == TD_WAVE) {
            var done = _waveTotal - _spawnLeft - _liveCount();
            var pct = 0;
            if (_waveTotal > 0) { pct = (done * 100) / _waveTotal; }
            TdArt.bar(dc, px + 8, by, bw, 3, pct, 0x22303C, TdUtil.modColor(_waveMod));
        } else {
            TdArt.bar(dc, px + 8, by, bw, 3, 0, 0x22303C, TD_C_MUTED);
        }

        // Map / modifier chip sits just below so it never crowds the number.
        var cy2 = py + ph + 2;
        dc.setColor(TdUtil.modColor(_waveMod), Graphics.COLOR_TRANSPARENT);
        var label = TdMap.mapName(_mapIdx);
        if (_waveMod != TDW_NONE) { label = TdUtil.modName(_waveMod); }
        if (_daily) { label = "DAILY " + label; }
        dc.drawText(_cx, cy2, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);

        // Between waves, preview what is coming.
        if (_phase == TD_BUILD) { _drawPreview(dc, cy2 + fh - 2); }
    }

    hidden function _liveCount() as Lang.Number {
        var n = 0;
        for (var i = 0; i < TD_MAX_ENEMIES; i++) {
            if (_enAlive[i]) { n++; }
        }
        return n;
    }

    // Up to six distinct enemy glyphs from the wave that is about to spawn.
    hidden function _drawPreview(dc, y) as Void {
        var seen = 0;
        var mask = 0;
        var s = _u;
        if (s < 3) { s = 3; }
        var slots = 6;
        var step = s * 3;
        // First pass counts distinct types so the strip can be centred.
        for (var i = 0; i < _waveTotal && seen < slots; i++) {
            var t = TdUtil.waveEnemy(_seed, _wave, i, _waveMod, _waveTotal);
            var bit = 1 << t;
            if ((mask & bit) != 0) { continue; }
            mask = mask | bit;
            seen++;
        }
        if (seen == 0) { return; }
        var x = _cx - (seen - 1) * step / 2;
        mask = 0;
        var k = 0;
        for (var i = 0; i < _waveTotal && k < slots; i++) {
            var t = TdUtil.waveEnemy(_seed, _wave, i, _waveMod, _waveTotal);
            var bit = 1 << t;
            if ((mask & bit) != 0) { continue; }
            mask = mask | bit;
            TdArt.enemyIcon(dc, t, x + k * step, y + s, s);
            k++;
        }
    }

    hidden function _chipR() as Lang.Number {
        var r = (_w * 7) / 100;
        if (r < 8) { r = 8; }
        return r;
    }

    hidden function _chipX(i as Lang.Number) as Lang.Number {
        var r = _chipR() + (_w * 2) / 100;
        if (i == 0) { return r; }
        return _w - r;
    }

    hidden function _drawChips(dc) as Void {
        var r = _chipR();
        for (var a = 0; a < TDA_COUNT; a++) {
            var x = _chipX(a);
            var y = _cy;
            var ready = (_abCd[a] == 0 && _coins >= TdUtil.abilityCost(a));
            var col = TdUtil.abilityColor(a);
            dc.setColor(0x0B1520, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r);
            dc.setColor(ready ? col : 0x2E3A46, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, r);
            if (a == TDA_STRIKE) {
                // Falling bomb glyph.
                dc.setColor(ready ? col : 0x46525E, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y + 1, r / 3);
                dc.fillRectangle(x - 1, y - r / 2, 2, r / 3);
            } else {
                TdArt.diamond(dc, x, y, r / 3, r / 2,
                              ready ? col : 0x46525E);
            }
            if (_abCd[a] > 0) {
                var pct = (_abCd[a] * 100) / TdUtil.abilityCd(a);
                TdArt.cdSweep(dc, x, y, r - 1, pct, TdUtil.shade(col, 45));
            }
            dc.setColor(ready ? TD_C_GOLD : 0x46525E, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y + r, Graphics.FONT_XTINY,
                        TdUtil.abilityCost(a).format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
            if (_ui == TDUI_ABILITY && _row == a) {
                dc.setPenWidth(2);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(x, y, r + 2);
                dc.setPenWidth(1);
            }
        }
    }

    // The sheet floats clear of the bottom of the glass instead of sitting on
    // it: at the very bottom of a round watch the usable chord is only a few
    // dozen pixels, which is not enough for a line of text.
    hidden function _sheetBot() as Lang.Number {
        if (!_round) { return _h - 3; }
        return _h - (_h * 12) / 100;
    }

    hidden function _sheetTop() as Lang.Number {
        var fh = _fontH();
        if (_ui == TDUI_MAP) { return _sheetBot() - fh * 2 - 8; }
        return _sheetBot() - fh * 3 - 10;
    }

    hidden function _fontH() as Lang.Number {
        var f = (_h * 8) / 100;
        if (f < 12) { f = 12; }
        if (f > 20) { f = 20; }
        return f;
    }

    // Bottom sheet: always tells you exactly what SELECT does right now, and
    // becomes a one-row-at-a-time carousel when a menu is open.
    hidden function _drawSheet(dc) as Void {
        if (_phase == TD_SUMMARY || _phase == TD_OVER) { return; }
        var fh = _fontH();
        var top = _sheetTop();
        var sh = _sheetBot() - top;
        var sw = _fitW((_w * 84) / 100, top, top + sh);
        var sx = _cx - sw / 2;
        TdArt.panel(dc, sx, top, sw, sh, 0x0B1520, 0x243544);

        var l1 = top + 2;
        var l2 = top + fh + 1;
        var l3 = top + fh * 2;

        if (_ui == TDUI_MAP) {
            // Row 1: economy. Row 2: the action under the cursor.
            var cr = fh / 3;
            TdArt.coin(dc, sx + 10 + cr, l1 + fh / 2, cr);
            var cc = TD_C_GOLD;
            if (_coinPop > 0) { cc = 0xFFFFFF; }
            dc.setColor(cc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx + 14 + cr * 2, l1, Graphics.FONT_XTINY,
                        _coins.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
            var hcol = TD_C_HP;
            if (_baseHp * 3 <= _baseMax) { hcol = TD_C_DANGER; }
            TdArt.heart(dc, sx + sw - 12 - cr, l1 + fh / 2, cr, hcol);
            dc.setColor(hcol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx + sw - 16 - cr * 2, l1, Graphics.FONT_XTINY,
                        _baseHp.format("%d"), Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(TD_C_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, l2, Graphics.FONT_XTINY, _mapHint(),
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var rows = _sheetRows();
        var name = "";
        var sub = "";
        var col = TD_C_TEXT;
        var icon = -1;

        if (_ui == TDUI_BUY) {
            if (_row < TW_COUNT) {
                icon = _row;
                col = TdUtil.towerColor(_row);
                name = TdUtil.towerName(_row) + "  " + TdUtil.towerCost(_row).format("%d") + "c";
                sub = TdUtil.towerBlurb(_row);
                if (_coins < TdUtil.towerCost(_row)) { sub = "not enough coins"; }
            } else {
                name = "BACK";
                sub = "keep your coins";
            }
        } else if (_ui == TDUI_TOWER) {
            var ti = _selTower;
            if (ti < 0 || !_twAlive[ti]) { cancel(); return; }
            icon = _twType[ti];
            col = TdUtil.towerColor(icon);
            var tier = _twTier[ti];
            if (_row == 0) {
                if (tier >= 4) {
                    name = "MAX TIER 4";
                    sub = TdUtil.towerSpecial(icon) + " active";
                } else {
                    name = "UPGRADE T" + (tier + 1).format("%d") + "  "
                         + TdUtil.upgradeCost(icon, tier).format("%d") + "c";
                    if (tier == 3) { sub = "unlocks " + TdUtil.towerSpecial(icon); }
                    else { sub = "dmg " + TdUtil.towerDmg(icon, tier).format("%d")
                                + " to " + TdUtil.towerDmg(icon, tier + 1).format("%d"); }
                }
            } else if (_row == 1) {
                name = "TARGET " + TdUtil.targetName(_twTgt[ti]);
                sub = "kills " + _twKills[ti].format("%d")
                    + "  dmg " + _twDmg[ti].format("%d");
            } else if (_row == 2) {
                name = "SELL  +" + ((_twSpent[ti] * 60) / 100).format("%d") + "c";
                sub = "60% of " + _twSpent[ti].format("%d") + "c invested";
            } else {
                name = "BACK";
                sub = TdUtil.towerName(icon) + " T" + tier.format("%d");
            }
        } else {
            if (_row < TDA_COUNT) {
                col = TdUtil.abilityColor(_row);
                name = TdUtil.abilityName(_row) + "  "
                     + TdUtil.abilityCost(_row).format("%d") + "c";
                if (_abCd[_row] > 0) {
                    sub = "ready in "
                        + ((_abCd[_row] * TD_TICK_MS) / 1000 + 1).format("%d") + "s";
                } else {
                    sub = TdUtil.abilityBlurb(_row);
                }
            } else {
                name = "BACK";
                sub = "return to the map";
            }
        }

        var tx = sx + 8;
        if (icon >= 0) {
            TdArt.towerIcon(dc, icon, sx + 12, l1 + fh / 2, fh / 3);
            tx = sx + 12 + fh / 2 + 4;
        }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx, l1, Graphics.FONT_XTINY, name, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(TD_C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, l2, Graphics.FONT_XTINY, sub, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x5A6E80, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, l3, Graphics.FONT_XTINY,
                    (_row + 1).format("%d") + "/" + rows.format("%d")
                    + "  UP/DN  SELECT",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Kept short on purpose: the sheet is only as wide as the chord across the
    // bottom of the glass allows, and a clipped instruction is worse than a
    // terse one.
    hidden function _mapHint() as Lang.String {
        if (_cursor >= _padN) { return "START WAVE " + _wave.format("%d"); }
        var ti = _padTower[_cursor];
        if (ti < 0) { return "BUILD  pad " + (_cursor + 1).format("%d"); }
        return TdUtil.towerName(_twType[ti]) + " T" + _twTier[ti].format("%d")
             + "  MANAGE";
    }

    hidden function _drawBanner(dc) as Void {
        var fh = _fontH();
        var y = (_h * 32) / 100;
        var bh = fh * 2 + 6;
        var bw = _fitW((_w * 74) / 100, y, y + bh);
        TdArt.panel(dc, _cx - bw / 2, y, bw, bh, 0x0B1520,
                    TdUtil.modColor(_waveMod));
        dc.setColor(TdUtil.modColor(_waveMod), Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y + 2, Graphics.FONT_XTINY, _banner,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(TD_C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y + fh + 2, Graphics.FONT_XTINY, TdUtil.modHint(_waveMod),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawToast(dc) as Void {
        var fh = _fontH();
        var y = (_h * 60) / 100;
        var tw = _fitW((_w * 66) / 100, y, y + fh + 4);
        TdArt.panel(dc, _cx - tw / 2, y, tw, fh + 4, 0x08101A, 0x2E4256);
        dc.setColor(TD_C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y + 2, Graphics.FONT_XTINY, _toast,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Overlays ────────────────────────────────────────────────────────────

    // Post-wave: the money you just made, the two towers that actually earned
    // it, and one concrete instruction.
    hidden function _drawSummary(dc) as Void {
        var fh = _fontH();
        var bh = fh * 6 + 10;
        var by = _cy - bh / 2;
        var bw = _fitW((_w * 82) / 100, by, by + bh);
        var bx = _cx - bw / 2;
        TdArt.panel(dc, bx, by, bw, bh, 0x081018, 0x2E4256);

        dc.setColor(TD_C_HP, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + 2, Graphics.FONT_XTINY,
                    "WAVE " + (_wave - 1).format("%d") + " CLEAR",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(TD_C_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + fh, Graphics.FONT_XTINY,
                    "+" + _clearBonus.format("%d") + "c  interest +"
                    + _interest.format("%d") + "c",
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Two best towers of the wave, by damage.
        var y = by + fh * 2;
        var shown = 0;
        var used = -1;
        for (var pass = 0; pass < 2; pass++) {
            var best = -1;
            var bestV = 0;
            for (var i = 0; i < TD_MAX_TOWERS; i++) {
                if (!_twAlive[i] || i == used) { continue; }
                if (_twWd[i] > bestV) { bestV = _twWd[i]; best = i; }
            }
            if (best < 0) { break; }
            used = best;
            TdArt.towerIcon(dc, _twType[best], bx + 14, y + fh / 2, fh / 3);
            dc.setColor(TdUtil.towerColor(_twType[best]), Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx + 24, y, Graphics.FONT_XTINY,
                        TdUtil.towerName(_twType[best]) + " T" + _twTier[best].format("%d"),
                        Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(TD_C_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx + bw - 8, y, Graphics.FONT_XTINY,
                        _twWk[best].format("%d") + "k " + _twWd[best].format("%d") + "d",
                        Graphics.TEXT_JUSTIFY_RIGHT);
            y += fh;
            shown++;
        }
        if (shown == 0) {
            dc.setColor(TD_C_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, y, Graphics.FONT_XTINY, "no towers built",
                        Graphics.TEXT_JUSTIFY_CENTER);
            y += fh;
        }

        dc.setColor(TD_C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + bh - fh * 2 - 2, Graphics.FONT_XTINY,
                    "leaks " + _waveLeaks.format("%d") + "   kills "
                    + _waveKills.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (_hints) {
            dc.setColor(TD_C_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, by + bh - fh - 2, Graphics.FONT_XTINY, _tip,
                        Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x5A6E80, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, by + bh - fh - 2, Graphics.FONT_XTINY, "SELECT continue",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drawOver(dc) as Void {
        var fh = _fontH();
        var bh = fh * 6 + 10;
        var by = _cy - bh / 2;
        var bw = _fitW((_w * 84) / 100, by, by + bh);
        var bx = _cx - bw / 2;
        TdArt.panel(dc, bx, by, bw, bh, 0x081018, _won ? TD_C_HP : TD_C_DANGER);

        dc.setColor(_won ? TD_C_HP : TD_C_DANGER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + 2, Graphics.FONT_XTINY,
                    _won ? "ALL 30 WAVES CLEAR" : "BASE OVERRUN",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(TD_C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + fh, Graphics.FONT_XTINY,
                    "Wave " + _wave.format("%d") + " on " + TdMap.mapName(_mapIdx),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(TD_C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + fh * 2, Graphics.FONT_XTINY,
                    _kills.format("%d") + " killed   " + _leaks.format("%d") + " leaked",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(TD_C_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + fh * 3, Graphics.FONT_XTINY, _tip,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(TD_C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + fh * 4, Graphics.FONT_XTINY,
                    "SCORE " + _score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x5A6E80, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + fh * 5, Graphics.FONT_XTINY,
                    "SELECT retry   BACK exit",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
