// ═══════════════════════════════════════════════════════════════════════════
// BitochiDungeonMasterView.mc — GameEngine: ties the systems together and owns
// every screen (explore / combat / loot / level-up / pack / shrine / shop /
// death) plus all the game feel — particles, floating damage, screen shake,
// low-health vignette and haptics.
//
// One expedition = descend as deep as you can, 15 floors to the way out. The
// engine is turn based, so rays are only re-cast when the camera actually
// changes (`_dirty`) and the timer only repaints when something visually
// changed. Every buffer is pre-allocated in initialize().
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;
using Toybox.Lang;
using Toybox.ActivityMonitor;
using Toybox.Attention;

// Pack rows — one flat list so UP / DOWN / SELECT reaches everything on a
// button-only watch.
const PACK_POTION = 0;
const PACK_ETHER  = 1;
const PACK_SCROLL = 2;
const PACK_MEND   = 3;
const PACK_WARD   = 4;
const PACK_SHEET  = 5;
const PACK_MAP    = 6;
const PACK_CLOSE  = 7;
const PACK_ROWS   = 8;

const DM_PART = 14;      // particle pool
const DM_NUMS = 3;       // floating damage numbers

class BitochiDungeonMasterView extends WatchUi.View {

    hidden var _w;
    hidden var _h;
    hidden var _cx;
    hidden var _cy;
    hidden var _small;        // tiny round screens get a leaner HUD

    hidden var _timer;
    hidden var _tick;
    hidden var _torch;

    hidden var _phase;
    hidden var _skipStart;
    hidden var _lbHandled;

    // Systems
    hidden var _hero;
    hidden var _map;
    hidden var _cam;
    hidden var _rc;
    hidden var _renderer;
    hidden var _combat;

    // Run state
    hidden var _seed;
    hidden var _floor;
    hidden var _diff;
    hidden var _daily;
    hidden var _deepest;
    hidden var _secrets;
    hidden var _discovered;
    hidden var _kills;
    hidden var _bossKills;
    hidden var _steps;
    hidden var _won;
    hidden var _dirty;
    hidden var _deathCause;

    // UI state
    hidden var _msg;
    hidden var _msgTick;
    hidden var _lootIdx;
    hidden var _lootMsg;
    hidden var _lootKind;
    hidden var _lootRar;
    hidden var _lvlSel;
    hidden var _packSel;
    hidden var _packPage;     // 0 items, 1 character sheet, 2 map
    hidden var _descendTick;
    hidden var _featIdx;
    hidden var _featSel;
    hidden var _featMsg;
    hidden var _shopSel;

    // Feel
    hidden var _shake;
    hidden var _shakeX;
    hidden var _shakeY;
    hidden var _pX;
    hidden var _pY;
    hidden var _pVX;
    hidden var _pVY;
    hidden var _pLife;
    hidden var _pCol;
    hidden var _dnX;
    hidden var _dnY;
    hidden var _dnLife;
    hidden var _dnTxt;
    hidden var _dnCol;

    function initialize() {
        View.initialize();
        _tick = 0;
        _torch = 0;
        _skipStart = false;
        _lbHandled = false;
        _phase = DM_EXPLORE;
        _timer = null;
        _seed = 1;
        _floor = 1;
        _diff = 1;
        _daily = false;
        _deepest = 1;
        _secrets = 0;
        _discovered = 0;
        _kills = 0;
        _bossKills = 0;
        _steps = 0;
        _won = false;
        _dirty = true;
        _deathCause = "";
        _msg = "";
        _msgTick = 0;
        _lootIdx = -1;
        _lootMsg = "";
        _lootKind = LOOT_GOLD;
        _lootRar = RAR_COMMON;
        _lvlSel = UP_HP;
        _packSel = 0;
        _packPage = 0;
        _descendTick = 0;
        _featIdx = -1;
        _featSel = 0;
        _featMsg = "";
        _shopSel = 0;
        _shake = 0;
        _shakeX = 0;
        _shakeY = 0;
        _small = false;

        _pX = new [DM_PART];
        _pY = new [DM_PART];
        _pVX = new [DM_PART];
        _pVY = new [DM_PART];
        _pLife = new [DM_PART];
        _pCol = new [DM_PART];
        for (var i = 0; i < DM_PART; i++) { _pLife[i] = 0; _pX[i] = 0; _pY[i] = 0;
            _pVX[i] = 0; _pVY[i] = 0; _pCol[i] = 0xFFFFFF; }
        _dnX = new [DM_NUMS];
        _dnY = new [DM_NUMS];
        _dnLife = new [DM_NUMS];
        _dnTxt = new [DM_NUMS];
        _dnCol = new [DM_NUMS];
        for (var i = 0; i < DM_NUMS; i++) { _dnLife[i] = 0; _dnX[i] = 0; _dnY[i] = 0;
            _dnTxt[i] = ""; _dnCol[i] = 0xFFFFFF; }

        _combat = new CombatSystem();
        _hero = new Character(DmConst.heroClass());
    }

    // The input delegate scales its flick threshold to the panel.
    function width() { return (_w == null) ? 0 : _w; }

    function onLayout(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _small = (_w < 230);
        if (_rc == null) {
            _rc = new Raycaster(_w);
            _renderer = new DungeonRenderer(_rc);
        }
        _renderer.setViewport(0, 0, _w, _h);
        _dirty = true;
    }

    function onShow() {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTimer), 90, true);
        }
        if (!_skipStart) { _beginRun(); }
        _skipStart = false;
    }

    function onHide() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    // The dungeon is turn based: this only advances effects, and it repaints
    // solely when one of them actually changed.
    function onTimer() as Void {
        _tick++;
        var changed = false;

        // Torch flicker is the idle heartbeat — 5 ticks apart so a still frame
        // costs one repaint every ~450ms instead of eleven.
        if (_tick % 5 == 0) {
            var t = ((_tick / 5) % 3) * 4;
            if (t != _torch) { _torch = t; changed = true; }
        }

        if (_msgTick > 0) { _msgTick--; changed = true; }
        if (_shake > 0) {
            _shake--;
            _shakeX = ((_tick % 2) == 0) ? _shake : -_shake;
            _shakeY = ((_tick % 3) == 0) ? _shake / 2 : -(_shake / 2);
            if (_shake == 0) { _shakeX = 0; _shakeY = 0; }
            changed = true;
        }
        if (_combat.flashPlayer > 0 || _combat.flashMon > 0 || _combat.fxTick > 0 ||
            _combat.lunge > 0) {
            _combat.tickFlash();
            changed = true;
        }
        if (_stepParticles()) { changed = true; }
        if (_stepNumbers()) { changed = true; }
        if (_phase == DM_DESCEND) {
            _descendTick--;
            if (_descendTick <= 0) { _phase = DM_EXPLORE; }
            changed = true;
        }
        if (_phase == DM_DEAD && !_lbHandled) {
            _finishOnce();
            changed = true;
        }

        if (changed) { WatchUi.requestUpdate(); }
    }

    // ── Feel: particles, damage numbers, shake, haptics ──────────────────────

    hidden function _spawn(x as Lang.Number, y as Lang.Number, n as Lang.Number,
                           col as Lang.Number, up as Lang.Number) as Void {
        var made = 0;
        for (var i = 0; i < DM_PART && made < n; i++) {
            if (_pLife[i] > 0) { continue; }
            var r = (_tick * 7 + i * 13 + made * 29) % 11;
            _pX[i] = x;
            _pY[i] = y;
            _pVX[i] = r - 5;
            _pVY[i] = -(up + (r % 4));
            _pLife[i] = 6 + (r % 4);
            _pCol[i] = col;
            made++;
        }
    }

    hidden function _stepParticles() as Lang.Boolean {
        var alive = false;
        for (var i = 0; i < DM_PART; i++) {
            if (_pLife[i] <= 0) { continue; }
            _pX[i] += _pVX[i];
            _pY[i] += _pVY[i];
            _pVY[i] += 2;
            _pLife[i]--;
            alive = true;
        }
        return alive;
    }

    hidden function _number(x as Lang.Number, y as Lang.Number, txt as Lang.String,
                            col as Lang.Number) as Void {
        var slot = 0;
        var worst = 999;
        for (var i = 0; i < DM_NUMS; i++) {
            if (_dnLife[i] < worst) { worst = _dnLife[i]; slot = i; }
        }
        _dnX[slot] = x;
        _dnY[slot] = y;
        _dnTxt[slot] = txt;
        _dnCol[slot] = col;
        _dnLife[slot] = 12;
    }

    hidden function _stepNumbers() as Lang.Boolean {
        var alive = false;
        for (var i = 0; i < DM_NUMS; i++) {
            if (_dnLife[i] <= 0) { continue; }
            _dnY[i] -= 2;
            _dnLife[i]--;
            alive = true;
        }
        return alive;
    }

    hidden function _kick(mag as Lang.Number) as Void {
        if (!DmConst.shakeOn()) { return; }
        if (mag > _shake) { _shake = mag; }
    }

    hidden function _vibe(ms as Lang.Number, pct as Lang.Number) as Void {
        if (!DmConst.hapticOn()) { return; }
        try {
            if (Toybox has :Attention && Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(pct, ms)]);
            }
        } catch (e) {}
    }

    // ── Run setup ───────────────────────────────────────────────────────────

    hidden function _beginRun() as Void {
        _diff = DmConst.difficulty();
        _daily = DmConst.isDaily();
        _floor = 1;
        _deepest = 1;
        _secrets = 0;
        _discovered = 0;
        _kills = 0;
        _bossKills = 0;
        _steps = 0;
        _won = false;
        _lbHandled = false;
        _deathCause = "";
        _hero = new Character(DmConst.heroClass());

        if (_daily) {
            _seed = DmConst.dayIndex();
        } else {
            var r = 0;
            try { r = Math.rand(); } catch (e) { r = 4242; }
            if (r < 0) { r = -r; }
            _seed = r % 1000000 + 1;
        }

        _applyFitnessBonus();
        _loadFloor();
        _phase = DM_EXPLORE;

        try {
            var dm = Application.Storage.getValue("dm_daily_msg");
            if (dm instanceof Lang.String) {
                _flash(dm);
                Application.Storage.deleteValue("dm_daily_msg");
            }
        } catch (e) {}
    }

    // Garmin activity → "Adventure Energy". A leg up, never a replacement for
    // playing well (Character caps the bonus).
    hidden function _applyFitnessBonus() as Void {
        try {
            if (!(Toybox has :ActivityMonitor)) { return; }
            var info = ActivityMonitor.getInfo();
            if (info == null) { return; }
            var steps = 0;
            var mins = 0;
            if (info has :steps && info.steps != null) { steps = info.steps; }
            if (info has :activeMinutesDay && info.activeMinutesDay != null) {
                var am = info.activeMinutesDay;
                if (am has :total && am.total != null) { mins = am.total; }
            }
            var m = _hero.applyAdventureEnergy(steps, mins);
            if (m != null) { _flash(m); }
        } catch (e) {}
    }

    hidden function _loadFloor() as Void {
        _map = DungeonGenerator.build(_seed, _floor, _diff);
        if (_cam == null) { _cam = new Camera(); }
        _cam.moveTo(_map.startX, _map.startY);
        _cam.setDir(_map.startDir);
        _map.markNear(_map.startX, _map.startY);
        if (_renderer != null) { _renderer.setFloor(_floor); }
        _dirty = true;
    }

    hidden function _flash(text as Lang.String) as Void {
        _msg = text;
        _msgTick = 22;
    }

    // ── Input ───────────────────────────────────────────────────────────────

    // Context-sensitive primary action: attack what blocks you, open what can
    // be opened, descend when standing on stairs, otherwise step forward.
    function advance() as Void {
        if (_phase == DM_DEAD)    { _retry(); return; }
        if (_phase == DM_DESCEND) { _phase = DM_EXPLORE; return; }
        if (_phase == DM_LOOT)    { _phase = DM_EXPLORE; return; }
        if (_phase == DM_LEVELUP) { _confirmUpgrade(); return; }
        if (_phase == DM_PACK)    { _usePackRow(); return; }
        if (_phase == DM_FEATURE) { _useFeatureRow(); return; }
        if (_phase == DM_SHOP)    { _useShopRow(); return; }
        if (_phase == DM_COMBAT)  { _resolveCombat(); return; }

        var ax = _cam.aheadX();
        var ay = _cam.aheadY();

        var mi = _map.monsterAt(ax, ay);
        if (mi >= 0) {
            _startCombat(mi);
            return;
        }

        var t = _map.at(ax, ay);
        if (t == T_DOOR) {
            _map.set(ax, ay, T_DOOR_OPEN);
            _flash("THE DOOR CREAKS OPEN");
            _dirty = true;
            return;
        }
        if (t == T_LOCKED) {
            _map.set(ax, ay, T_DOOR_OPEN);
            _dirty = true;
            if (_hero.keys > 0) {
                _hero.keys--;
                _flash("THE KEY TURNS");
                return;
            }
            // No key: force it. Costs blood, never progress — a locked door can
            // never seal off the only route to the stairs.
            var cost = 4 + _floor;
            _hero.hurt(cost);
            _kick(5);
            _vibe(140, 40);
            _spawn(_cx, _cy, 6, 0xCC3322, 4);
            _number(_cx, _cy - 10, "-" + cost.format("%d"), 0xFF5544);
            _flash("YOU SHOULDER IT OPEN");
            if (!_hero.isAlive()) { _die("The door held. You did not."); }
            return;
        }
        if (t == T_SECRET) {
            _openSecret(ax, ay);
            return;
        }
        if (t == T_PILLAR) {
            _flash("A CARVED PILLAR");
            return;
        }

        if (_map.at(_cam.tileX(), _cam.tileY()) == T_STAIRS) {
            _descend();
            return;
        }

        if (!_map.isWalkable(ax, ay)) {
            _flash("SOLID STONE");
            return;
        }
        _step(ax, ay);
    }

    // Explicit search (swipe down / long-ish): sound the wall ahead, take the
    // stairs, or read the room.
    function interact() as Void {
        if (_phase != DM_EXPLORE) { advance(); return; }
        if (_map.at(_cam.tileX(), _cam.tileY()) == T_STAIRS) { _descend(); return; }
        var ax = _cam.aheadX();
        var ay = _cam.aheadY();
        var t = _map.at(ax, ay);
        if (t == T_SECRET) { _openSecret(ax, ay); return; }
        if (t == T_DOOR || t == T_LOCKED) { advance(); return; }

        // Sounding the walls: a keen adventurer hears the hollow one nearby.
        var x = _cam.tileX();
        var y = _cam.tileY();
        for (var i = 0; i < _map.secN; i++) {
            if (_map.secFound[i] != 0) { continue; }
            var dx = _map.secX[i] - x;
            var dy = _map.secY[i] - y;
            if (dx < 0) { dx = -dx; }
            if (dy < 0) { dy = -dy; }
            if (dx + dy <= 2) {
                _flash("THE STONE SOUNDS HOLLOW");
                return;
            }
        }
        if (t == T_WALL) { _flash("ONLY COLD STONE"); return; }
        _flash("NOTHING HERE");
    }

    hidden function _openSecret(ax as Lang.Number, ay as Lang.Number) as Void {
        var si = _map.openSecret(ax, ay);
        _dirty = true;
        if (si < 0) {
            _map.set(ax, ay, T_FLOOR);
            _flash("THE WALL GIVES WAY");
            return;
        }
        _secrets++;
        _vibe(90, 30);
        _spawn(_cx, _cy - 10, 8, 0xFFDD66, 5);
        var st = _map.secType[si];
        if (st == SEC_PASSAGE) {
            _gainXp(18);
            _flash("A HIDDEN PASSAGE!");
            return;
        }
        _lootIdx = -1;
        _lootKind = _map.secKind[si];
        _lootRar = DmConst.lootRarity(_lootKind, _map.secVal[si]);
        if (st == SEC_VAULT) { _lootRar = RAR_RARE; }
        _lootMsg = _hero.takeLoot(_lootKind, _map.secVal[si]);
        _gainXp(22);
        if (_phase != DM_LEVELUP) { _phase = DM_LOOT; }
    }

    function turn(delta as Lang.Number) as Void {
        if (_phase == DM_COMBAT)  { _combat.navigate(delta); return; }
        if (_phase == DM_LEVELUP) {
            _lvlSel = ((_lvlSel + delta) % UP_COUNT + UP_COUNT) % UP_COUNT;
            return;
        }
        if (_phase == DM_PACK) {
            if (_packPage != 0) { _packPage = 0; }
            _packSel = ((_packSel + delta) % PACK_ROWS + PACK_ROWS) % PACK_ROWS;
            return;
        }
        if (_phase == DM_FEATURE) {
            var n = _featRows();
            _featSel = ((_featSel + delta) % n + n) % n;
            return;
        }
        if (_phase == DM_SHOP) {
            _shopSel = ((_shopSel + delta) % 6 + 6) % 6;
            return;
        }
        if (_phase != DM_EXPLORE) { return; }
        _cam.turn(delta);
        _dirty = true;
    }

    function toggleInventory() as Void {
        if (_phase == DM_PACK) {
            // MENU cycles pages, then closes — everything with one button.
            _packPage = (_packPage + 1) % 3;
            if (_packPage == 0) { _phase = DM_EXPLORE; }
            return;
        }
        if (_phase != DM_EXPLORE) { return; }
        _phase = DM_PACK;
        _packSel = 0;
        _packPage = 0;
    }

    function closeOverlay() as Lang.Boolean {
        if (_phase == DM_COMBAT) { return _combat.cancel(); }
        if (_phase == DM_PACK || _phase == DM_LOOT || _phase == DM_FEATURE ||
            _phase == DM_SHOP) {
            _phase = DM_EXPLORE;
            return true;
        }
        return false;
    }

    // ── Exploration ─────────────────────────────────────────────────────────

    hidden function _step(nx as Lang.Number, ny as Lang.Number) as Void {
        _cam.moveTo(nx, ny);
        _dirty = true;
        _steps++;
        _hero.stepRegen(_steps);

        var fresh = _map.markNear(nx, ny);
        if (fresh > 0) {
            _discovered += fresh;
            // Mapping unknown ground is worth experience — exploring pays.
            if (_discovered % 10 < fresh) { _gainXp(5); }
        }

        var ti = _map.trapAt(nx, ny);
        if (ti >= 0) {
            _map.trapArmed[ti] = 0;
            if (_springTrap(_map.trapKind[ti])) { return; }
        }

        var fi = _map.featAt(nx, ny);
        if (fi >= 0 && _map.featUsed[fi] == 0) {
            _featIdx = fi;
            _featSel = 0;
            _featMsg = "";
            if (_map.featKind[fi] == FEAT_MERCHANT) {
                _shopSel = 0;
                _phase = DM_SHOP;
            } else {
                _phase = DM_FEATURE;
            }
            return;
        }

        var li = _map.lootAt(nx, ny);
        if (li >= 0) {
            _map.lootTaken[li] = 1;
            _lootIdx = li;
            _lootKind = _map.lootKind[li];
            _lootRar = DmConst.lootRarity(_lootKind, _map.lootVal[li]);
            _lootMsg = _hero.takeLoot(_lootKind, _map.lootVal[li]);
            if (_lootRar != RAR_COMMON) {
                _vibe(120, 45);
                _spawn(_cx, _cy - 12, 10, DmConst.rarityColor(_lootRar), 6);
            }
            _gainXp(4);
            if (_phase != DM_LEVELUP) { _phase = DM_LOOT; }
            return;
        }

        _moveMonsters();
    }

    // Returns true when the run ended on the trap.
    hidden function _springTrap(kind as Lang.Number) as Lang.Boolean {
        var dmg = 4 + _floor + _diff * 2 - _hero.totalDefense() / 2;
        var label = "SPIKES!";
        if (kind == TRAP_DART) {
            dmg = dmg * 3 / 4;
            if (_hero.poison <= 0) { _hero.poison = 3; }
            label = "DARTS - POISONED";
        } else if (kind == TRAP_PIT) {
            dmg = dmg * 3 / 2;
            label = "YOU FALL INTO A PIT";
        } else if (kind == TRAP_RUNE) {
            dmg = dmg * 5 / 4;
            _hero.spendMana(8);
            label = "A GLYPH FLARES";
        }
        if (dmg < 2) { dmg = 2; }
        _hero.hurt(dmg);
        _kick(kind == TRAP_PIT ? 7 : 5);
        _vibe(160, 55);
        _spawn(_cx, _cy + _h / 8, 8, kind == TRAP_RUNE ? 0xAA77FF : 0xCC3322, 5);
        _number(_cx, _cy, "-" + dmg.format("%d"), 0xFF5544);
        _flash(label);
        if (!_hero.isAlive()) {
            _die(DmConst.trapName(kind) + " on floor " + _floor.format("%d"));
            return true;
        }
        return false;
    }

    // Monsters shuffle one tile toward the hero when they can smell him, and
    // ambush the moment they are adjacent.
    hidden function _moveMonsters() as Void {
        var hx = _cam.tileX();
        var hy = _cam.tileY();
        for (var i = 0; i < _map.monN; i++) {
            if (!_map.monAlive[i]) { continue; }
            var mx = _map.monX[i];
            var my = _map.monY[i];
            var dx = hx - mx;
            var dy = hy - my;
            var adx = dx < 0 ? -dx : dx;
            var ady = dy < 0 ? -dy : dy;

            if (adx + ady == 1) {
                _cam.setDir(_faceToward(dx, dy));
                _dirty = true;
                _startCombat(i);
                return;
            }
            // Bosses hold their ground; everything else hunts.
            if (DmConst.isBossType(_map.monType[i])) { continue; }
            var range = (_map.monType[i] == MON_RAT) ? 7 : 5;
            if (adx + ady > range) { continue; }

            var tx = mx;
            var ty = my;
            if (adx >= ady) { tx += (dx > 0) ? 1 : -1; }
            else            { ty += (dy > 0) ? 1 : -1; }
            if (!_map.isWalkable(tx, ty)) { continue; }
            if (tx == hx && ty == hy) { continue; }
            if (_map.monsterAt(tx, ty) >= 0) { continue; }
            _map.monX[i] = tx;
            _map.monY[i] = ty;

            dx = hx - tx;
            dy = hy - ty;
            adx = dx < 0 ? -dx : dx;
            ady = dy < 0 ? -dy : dy;
            if (adx + ady == 1) {
                _cam.setDir(_faceToward(dx, dy));
                _dirty = true;
                _startCombat(i);
                return;
            }
        }
    }

    hidden function _faceToward(dx as Lang.Number, dy as Lang.Number) as Lang.Number {
        // dx/dy point from the monster to the hero, so invert to face it.
        if (dx == 1)  { return DIR_W; }
        if (dx == -1) { return DIR_E; }
        if (dy == 1)  { return DIR_N; }
        return DIR_S;
    }

    hidden function _descend() as Void {
        if (_floor >= DM_MAX_FLOOR) {
            _won = true;
            _gainXp(220);
            _die("You climbed back into daylight.");
            return;
        }
        _floor++;
        if (_floor > _deepest) { _deepest = _floor; }
        _gainXp(12 + _floor * 3);
        _hero.heal(8);
        _hero.restoreMana(6);
        _loadFloor();
        _descendTick = 16;
        if (_phase != DM_LEVELUP) { _phase = DM_DESCEND; }
        _vibe(70, 25);
        _checkpoint();
    }

    hidden function _gainXp(n as Lang.Number) as Void {
        if (_hero.addXp(n)) {
            _lvlSel = UP_HP;
            _phase = DM_LEVELUP;
            _vibe(200, 60);
            _spawn(_cx, _cy, 12, 0xFFDD66, 7);
        }
    }

    hidden function _confirmUpgrade() as Void {
        var label = _hero.applyUpgrade(_lvlSel);
        _flash(label);
        _phase = DM_EXPLORE;
        _checkpoint();
    }

    // ── Combat ──────────────────────────────────────────────────────────────

    hidden function _startCombat(idx as Lang.Number) as Void {
        _combat.begin(_map, idx, _floor, _diff);
        _phase = DM_COMBAT;
        if (_combat.isBoss) { _vibe(300, 70); }
    }

    hidden function _resolveCombat() as Void {
        var out = _combat.confirm(_hero, _map, _floor);
        if (out.equals("menu")) { return; }

        // Spawn the feedback the fight just earned.
        var monX = _cx;
        var monY = _cy - _h / 12;
        if (_combat.lastMonDmg >= 0) {
            var mc = _combat.lastCrit ? 0xFFEE66 : 0xFFFFFF;
            _number(monX, monY, _combat.lastMonDmg.format("%d"), mc);
            _spawn(monX, monY + 8, _combat.lastCrit ? 9 : 6, 0xCC2222, 5);
            _vibe(_combat.lastCrit ? 130 : 60, _combat.lastCrit ? 50 : 25);
        }
        if (_combat.lastHeroDmg >= 0) {
            _number(_cx - _w / 5, _cy + _h / 5, "-" + _combat.lastHeroDmg.format("%d"), 0xFF5544);
            _spawn(_cx, _cy + _h / 6, 7, 0x992222, 4);
            _vibe(120, 45);
        }
        if (_combat.shakeMag > 0) { _kick(_combat.shakeMag); }

        if (out.equals("win")) {
            _kills++;
            var t = _combat.monType;
            if (DmConst.isBossType(t)) { _bossKills++; }
            var gold = DmConst.monGold(t, _floor);
            if (_combat.monElite != EL_NONE) { gold = gold * 2; }
            _hero.gold += gold;
            _hero.restoreMana(3);
            _spawn(monX, monY, 10, 0xFFCC44, 6);
            _number(monX, monY - 14, "+" + gold.format("%d") + "g", 0xFFCC44);
            _flash("SLAIN  +" + gold.format("%d") + "g");
            _phase = DM_EXPLORE;
            var xp = DmConst.monXp(t, _floor);
            if (_combat.monElite != EL_NONE) { xp = xp * 2; }
            _gainXp(xp);
            _checkpoint();
            return;
        }
        if (out.equals("dead")) {
            _die("Slain by " + _combat.fullName().toLower() + " on floor " + _floor.format("%d"));
        }
    }

    // ── Pack ────────────────────────────────────────────────────────────────

    hidden function _packLabel(i as Lang.Number) as Lang.String {
        if (i == PACK_POTION) { return "POTION x" + _hero.potions.format("%d"); }
        if (i == PACK_ETHER)  { return "ETHER x" + _hero.ethers.format("%d"); }
        if (i == PACK_SCROLL) { return "SCROLL x" + _hero.scrolls.format("%d"); }
        if (i == PACK_MEND)   { return "MEND  " + _hero.spellCost(SP_HEAL).format("%d") + "mp"; }
        if (i == PACK_WARD)   { return "WARD  " + _hero.spellCost(SP_WARD).format("%d") + "mp"; }
        if (i == PACK_SHEET)  { return "CHARACTER"; }
        if (i == PACK_MAP)    { return "FLOOR MAP"; }
        return "CLOSE PACK";
    }

    hidden function _usePackRow() as Void {
        if (_packPage != 0) {
            _packPage = 0;
            return;
        }
        var i = _packSel;
        if (i == PACK_POTION) {
            if (_hero.potions <= 0) { _flash("NO POTIONS"); return; }
            _hero.potions--;
            var healed = _hero.heal(26 + _hero.totalMagic());
            _number(_cx, _cy, "+" + healed.format("%d"), 0x66EE99);
            _flash("POTION +" + healed.format("%d") + "HP");
            _phase = DM_EXPLORE;
            return;
        }
        if (i == PACK_ETHER) {
            if (_hero.ethers <= 0) { _flash("NO ETHER"); return; }
            _hero.ethers--;
            var mp = _hero.restoreMana(16 + _hero.totalMagic());
            _flash("ETHER +" + mp.format("%d") + "MP");
            _phase = DM_EXPLORE;
            return;
        }
        if (i == PACK_SCROLL) {
            if (_hero.scrolls <= 0) { _flash("NO SCROLLS"); return; }
            _hero.scrolls--;
            _readScroll();
            return;
        }
        if (i == PACK_MEND) {
            if (!_hero.canCast(SP_HEAL)) { _flash("NOT ENOUGH MANA"); return; }
            _hero.spendMana(_hero.spellCost(SP_HEAL));
            var h2 = _hero.heal(16 + _hero.totalMagic() * 2);
            if (_hero.poison > 0) { _hero.poison = 0; }
            _spawn(_cx, _cy, 8, 0x66EE99, 5);
            _flash("MEND +" + h2.format("%d") + "HP");
            _phase = DM_EXPLORE;
            return;
        }
        if (i == PACK_WARD) {
            if (!_hero.canCast(SP_WARD)) { _flash("NOT ENOUGH MANA"); return; }
            _hero.spendMana(_hero.spellCost(SP_WARD));
            _hero.ward = 3;
            _spawn(_cx, _cy, 8, 0xFFDD55, 5);
            _flash("WARD RAISED");
            _phase = DM_EXPLORE;
            return;
        }
        if (i == PACK_SHEET) { _packPage = 1; return; }
        if (i == PACK_MAP)   { _packPage = 2; return; }
        _phase = DM_EXPLORE;
    }

    // A scroll of sight lays the floor bare: every secret, trap and stair.
    hidden function _readScroll() as Void {
        var found = 0;
        for (var i = 0; i < _map.secN; i++) {
            if (_map.secFound[i] != 0) { continue; }
            _map.markVisited(_map.secX[i], _map.secY[i]);
            found++;
        }
        for (var i = 0; i < _map.trapN; i++) {
            if (_map.trapArmed[i] == 0) { continue; }
            _map.markVisited(_map.trapX[i], _map.trapY[i]);
        }
        for (var y = 0; y < DM_H; y++) {
            for (var x = 0; x < DM_W; x++) {
                if (_map.at(x, y) == T_STAIRS) { _map.markVisited(x, y); }
            }
        }
        _map.markVisited(_map.stairX, _map.stairY);
        _dirty = true;
        _packPage = 2;
        if (found > 0) {
            _flash("THE SCROLL MARKS " + found.format("%d") + " SECRET");
        } else {
            _flash("THE FLOOR IS LAID BARE");
        }
    }

    // ── Shrines and fountains ───────────────────────────────────────────────

    hidden function _featRows() as Lang.Number {
        if (_featIdx < 0) { return 1; }
        if (_map.featKind[_featIdx] == FEAT_FOUNTAIN) { return 2; }
        return 3;
    }

    hidden function _featLabel(i as Lang.Number) as Lang.String {
        if (_featIdx < 0) { return "LEAVE"; }
        if (_map.featKind[_featIdx] == FEAT_FOUNTAIN) {
            if (i == 0) { return "DRINK DEEP"; }
            return "LEAVE IT";
        }
        if (i == 0) { return "PRAY"; }
        if (i == 1) { return "OFFER " + _offerPrice().format("%d") + "g"; }
        return "WALK AWAY";
    }

    hidden function _offerPrice() as Lang.Number { return 30 + _floor * 6; }

    hidden function _useFeatureRow() as Void {
        if (!_featMsg.equals("")) {
            _phase = DM_EXPLORE;
            return;
        }
        if (_featIdx < 0) { _phase = DM_EXPLORE; return; }
        var kind = _map.featKind[_featIdx];

        if (kind == FEAT_FOUNTAIN) {
            if (_featSel == 1) { _phase = DM_EXPLORE; return; }
            _map.featUsed[_featIdx] = 1;
            if (_roll(100) < 22) {
                var d = 6 + _floor;
                _hero.hurt(d);
                if (_hero.poison <= 0) { _hero.poison = 3; }
                _featMsg = "TAINTED  -" + d.format("%d") + "HP";
                _kick(4);
                _vibe(150, 50);
                if (!_hero.isAlive()) { _die("A poisoned fountain on floor " + _floor.format("%d")); }
            } else {
                var hh = _hero.heal(_hero.maxHpTotal() / 3 + 8);
                var mm = _hero.restoreMana(_hero.maxManaTotal());
                _hero.poison = 0;
                _featMsg = "+" + hh.format("%d") + "HP  +" + mm.format("%d") + "MP";
                _spawn(_cx, _cy, 10, 0x88CCFF, 6);
                _vibe(80, 30);
            }
            return;
        }

        // Shrine
        if (_featSel == 2) { _phase = DM_EXPLORE; return; }
        var good = 55;
        if (_featSel == 1) {
            var price = _offerPrice();
            if (_hero.gold < price) { _featMsg = "NOT ENOUGH GOLD"; return; }
            _hero.gold -= price;
            good = 82;
        }
        _map.featUsed[_featIdx] = 1;
        if (_roll(100) < good) {
            var pick = _roll(4);
            if (pick == 0) {
                _hero.maxHp += 10;
                _hero.heal(_hero.maxHpTotal());
                _featMsg = "BLESSED  +10 MAX HP";
            } else if (pick == 1) {
                _hero.str += 2;
                _featMsg = "BLESSED  +2 STRENGTH";
            } else if (pick == 2) {
                _hero.def += 2;
                _featMsg = "BLESSED  +2 DEFENSE";
            } else {
                _hero.mag += 2;
                _hero.maxMana += 6;
                _hero.restoreMana(_hero.maxManaTotal());
                _featMsg = "BLESSED  +2 MAGIC";
            }
            _spawn(_cx, _cy, 12, 0xFFDD66, 7);
            _vibe(120, 40);
        } else {
            var curse = _roll(3);
            if (curse == 0) {
                var d2 = 8 + _floor * 2;
                _hero.hurt(d2);
                _featMsg = "CURSED  -" + d2.format("%d") + "HP";
            } else if (curse == 1) {
                _hero.poison = 4;
                _featMsg = "CURSED  VENOM IN YOUR VEINS";
            } else {
                _hero.spendMana(_hero.maxManaTotal());
                _featMsg = "CURSED  MANA DRAINED";
            }
            _kick(6);
            _vibe(200, 60);
            _spawn(_cx, _cy, 10, 0x8833AA, 5);
            if (!_hero.isAlive()) { _die("A cursed shrine on floor " + _floor.format("%d")); }
        }
    }

    // ── Merchant ────────────────────────────────────────────────────────────

    hidden function _shopPrice(i as Lang.Number) as Lang.Number {
        if (i == 0) { return 30 + _floor * 2; }
        if (i == 1) { return 34 + _floor * 2; }
        if (i == 2) { return 24 + _floor * 2; }
        if (i == 3) { return 44 + _floor * 3; }
        if (i == 4) { return 110 + _floor * 12; }
        return 0;
    }

    hidden function _shopLabel(i as Lang.Number) as Lang.String {
        if (i == 5) { return "LEAVE"; }
        var p = _shopPrice(i).format("%d") + "g";
        if (i == 0) { return "POTION  " + p; }
        if (i == 1) { return "ETHER  " + p; }
        if (i == 2) { return "IRON KEY  " + p; }
        if (i == 3) { return "FIRE BOMB  " + p; }
        if (_hero.weapon >= 5) { return "NOTHING LEFT TO SELL"; }
        return "SHARPEN  " + p;
    }

    hidden function _useShopRow() as Void {
        if (_shopSel == 5) { _phase = DM_EXPLORE; return; }
        if (_shopSel == 4 && _hero.weapon >= 5) { _featMsg = "HE HAS NOTHING BETTER"; return; }
        var price = _shopPrice(_shopSel);
        if (_hero.gold < price) {
            _featMsg = "NOT ENOUGH GOLD";
            return;
        }
        _hero.gold -= price;
        if (_shopSel == 0)      { _hero.potions++; _featMsg = "POTION x" + _hero.potions.format("%d"); }
        else if (_shopSel == 1) { _hero.ethers++;  _featMsg = "ETHER x" + _hero.ethers.format("%d"); }
        else if (_shopSel == 2) { _hero.keys++;    _featMsg = "KEYS x" + _hero.keys.format("%d"); }
        else if (_shopSel == 3) { _hero.bombs++;   _featMsg = "BOMBS x" + _hero.bombs.format("%d"); }
        else {
            _hero.weapon++;
            _featMsg = DmConst.weaponName(_hero.weapon);
            _spawn(_cx, _cy, 8, 0xCCDDEE, 5);
        }
        _vibe(60, 25);
    }

    hidden function _roll(n as Lang.Number) as Lang.Number {
        if (n <= 1) { return 0; }
        var r = 0;
        try { r = Math.rand(); } catch (e) { r = _tick * 13 + 7; }
        if (r < 0) { r = -r; }
        return r % n;
    }

    // ── Death / victory / leaderboard ───────────────────────────────────────

    hidden function _die(cause as Lang.String) as Void {
        _deathCause = cause;
        _phase = DM_DEAD;
        if (!_won) {
            _kick(8);
            _vibe(500, 80);
        } else {
            _vibe(400, 60);
        }
    }

    hidden function _retry() as Void {
        try { SaveResume.clear(DM_LB_ID); } catch (e) {}
        _beginRun();
    }

    hidden function _score() as Lang.Number {
        var s = _deepest * 1000 + _hero.gold + _hero.level * 60 + _kills * 25 +
                _secrets * 80 + _bossKills * 400;
        if (_won) { s += 2500; }
        return s;
    }

    hidden function _finishOnce() as Void {
        if (_lbHandled) { return; }
        _lbHandled = true;
        try { SaveResume.clear(DM_LB_ID); } catch (e) {}

        var best = 0;
        try {
            var b = Application.Storage.getValue("dm_best");
            if (b instanceof Lang.Number) { best = b; }
        } catch (e) {}
        if (_deepest > best) {
            try { Application.Storage.setValue("dm_best", _deepest); } catch (e) {}
        }

        var variant = DmConst.lbVariant();
        try {
            // Meta rides along so the web board can show how the run ended.
            Leaderboard.submitScoreWithMeta(DM_LB_ID, _score(), variant, {
                "floor" => _deepest,
                "cls" => DmConst.className(_hero.cls),
                "escaped" => _won ? 1 : 0
            });
            Leaderboard.showPostGame(DM_LB_ID, variant, "DUNGEON MASTER");
        } catch (e) {}
        try {
            Progress.addXp(_deepest * 8);
            Progress.addCoins(_hero.gold / 10);
        } catch (e) {}
    }

    // ── SaveResume ──────────────────────────────────────────────────────────
    // Only the seed plus the "what changed" flags are stored — the geometry,
    // the monster roster and every stat table are rebuilt deterministically.

    function exportSave() as Lang.Dictionary or Null {
        if (_phase == DM_DEAD) { return null; }
        if (_map == null) { return null; }
        if (_floor <= 1 && _discovered <= 9 && _hero.gold == 0) { return null; }
        var mk = [];
        var mh = [];
        var mx = [];
        var my = [];
        for (var i = 0; i < _map.monN; i++) {
            mk.add(_map.monAlive[i] ? 1 : 0);
            mh.add(_map.monHp[i]);
            mx.add(_map.monX[i]);
            my.add(_map.monY[i]);
        }
        var lt = [];
        for (var i = 0; i < _map.lootN; i++) { lt.add(_map.lootTaken[i]); }
        var sf = [];
        for (var i = 0; i < _map.secN; i++) { sf.add(_map.secFound[i]); }
        var tr = [];
        for (var i = 0; i < _map.trapN; i++) { tr.add(_map.trapArmed[i]); }
        var fu = [];
        for (var i = 0; i < _map.featN; i++) { fu.add(_map.featUsed[i]); }
        var vis = [];
        for (var y = 0; y < DM_H; y++) { vis.add(_map.visitedRow(y)); }

        return {
            "vis" => vis,
            "sd" => _seed,
            "fl" => _floor,
            "dp" => _deepest,
            "df" => _diff,
            "dy" => _daily ? 1 : 0,
            "tx" => _cam.tileX(),
            "ty" => _cam.tileY(),
            "dr" => _cam.dir,
            "hero" => _hero.toDict(),
            "mk" => mk, "mh" => mh, "mx" => mx, "my" => my,
            "lt" => lt, "sf" => sf, "tr" => tr, "fu" => fu,
            "sec" => _secrets,
            "dis" => _discovered,
            "kil" => _kills,
            "bos" => _bossKills,
            "stp" => _steps
        };
    }

    function loadResume(data) as Void {
        if (data == null) { return; }
        _skipStart = true;
        try {
            _seed = _n(data["sd"], 1);
            _floor = _n(data["fl"], 1);
            _deepest = _n(data["dp"], _floor);
            _diff = _n(data["df"], DmConst.difficulty());
            _daily = _n(data["dy"], 0) == 1;
            _secrets = _n(data["sec"], 0);
            _discovered = _n(data["dis"], 0);
            _kills = _n(data["kil"], 0);
            _bossKills = _n(data["bos"], 0);
            _steps = _n(data["stp"], 0);
            _lbHandled = false;
            _won = false;
            _deathCause = "";

            _hero = new Character(DmConst.heroClass());
            var hd = data["hero"];
            if (hd instanceof Lang.Dictionary) { _hero.fromDict(hd); }

            _map = DungeonGenerator.build(_seed, _floor, _diff);
            if (_cam == null) { _cam = new Camera(); }
            if (_renderer != null) { _renderer.setFloor(_floor); }

            var mk = data["mk"];
            var mh = data["mh"];
            var mx = data["mx"];
            var my = data["my"];
            if (mk instanceof Lang.Array) {
                for (var i = 0; i < _map.monN && i < mk.size(); i++) {
                    _map.monAlive[i] = (_n(mk[i], 1) != 0);
                    if (mh instanceof Lang.Array && i < mh.size()) { _map.monHp[i] = _n(mh[i], _map.monHp[i]); }
                    if (mx instanceof Lang.Array && i < mx.size()) { _map.monX[i] = _n(mx[i], _map.monX[i]); }
                    if (my instanceof Lang.Array && i < my.size()) { _map.monY[i] = _n(my[i], _map.monY[i]); }
                }
            }
            var lt = data["lt"];
            if (lt instanceof Lang.Array) {
                for (var i = 0; i < _map.lootN && i < lt.size(); i++) {
                    _map.lootTaken[i] = _n(lt[i], 0);
                }
            }
            var sf = data["sf"];
            if (sf instanceof Lang.Array) {
                for (var i = 0; i < _map.secN && i < sf.size(); i++) {
                    var v = _n(sf[i], 0);
                    _map.secFound[i] = v;
                    // A found secret left its wall broken open.
                    if (v != 0 && _map.at(_map.secX[i], _map.secY[i]) == T_SECRET) {
                        _map.set(_map.secX[i], _map.secY[i], T_FLOOR);
                    }
                }
            }
            var tr = data["tr"];
            if (tr instanceof Lang.Array) {
                for (var i = 0; i < _map.trapN && i < tr.size(); i++) {
                    _map.trapArmed[i] = _n(tr[i], 1);
                }
            }
            var fu = data["fu"];
            if (fu instanceof Lang.Array) {
                for (var i = 0; i < _map.featN && i < fu.size(); i++) {
                    _map.featUsed[i] = _n(fu[i], 0);
                }
            }

            var vis = data["vis"];
            if (vis instanceof Lang.Array) {
                for (var y = 0; y < DM_H && y < vis.size(); y++) {
                    _map.setVisitedRow(y, _n(vis[y], 0));
                }
            }

            var tx = _n(data["tx"], _map.startX);
            var ty = _n(data["ty"], _map.startY);
            if (!_map.isWalkable(tx, ty)) { tx = _map.startX; ty = _map.startY; }
            _cam.moveTo(tx, ty);
            _cam.setDir(_n(data["dr"], _map.startDir));
            _map.markNear(tx, ty);

            _phase = DM_EXPLORE;
            _dirty = true;
            _flash("EXPEDITION RESUMED");
        } catch (e) {
            _skipStart = false;
        }
    }

    hidden function _checkpoint() as Void {
        try {
            var d = exportSave();
            if (d != null) { SaveResume.save(DM_LB_ID, d); }
        } catch (e) {}
    }

    hidden function _n(v, def as Lang.Number) as Lang.Number {
        if (v instanceof Lang.Number) { return v; }
        return def;
    }

    // ── Draw ────────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        if (_w == null || _w == 0) { onLayout(dc); }
        if (_map == null) { _beginRun(); }

        if (_dirty) {
            _rc.cast(_map, _cam);
            _dirty = false;
        }

        if (_phase == DM_DEAD) {
            _drawDead(dc);
            return;
        }

        // Screen shake rides on the viewport, so the world moves and the HUD
        // stays welded to the bezel.
        _renderer.setViewport(_shakeX, _shakeY, _w, _h);
        _renderer.setPhase(_tick / 3);
        var hide = -1;
        if (_phase == DM_COMBAT) { hide = _combat.monIdx; }
        _renderer.render(dc, _map, _cam, _torch, hide);

        if (_phase == DM_COMBAT) { _drawCombat(dc); }
        else if (_phase == DM_LOOT)    { _drawLoot(dc); }
        else if (_phase == DM_LEVELUP) { _drawLevelUp(dc); }
        else if (_phase == DM_PACK)    { _drawPack(dc); }
        else if (_phase == DM_FEATURE) { _drawFeature(dc); }
        else if (_phase == DM_SHOP)    { _drawShop(dc); }
        else {
            _drawHud(dc);
            if (_phase == DM_DESCEND) { _drawDescend(dc); }
            else { _drawPrompt(dc); }
        }

        _drawParticles(dc);
        _drawNumbers(dc);
        _drawVignette(dc);

        if (_msgTick > 0 && _phase != DM_LOOT && _phase != DM_PACK) {
            _banner(dc, _msg, _cy + _h / 4);
        }
    }

    hidden function _drawParticles(dc) as Void {
        for (var i = 0; i < DM_PART; i++) {
            if (_pLife[i] <= 0) { continue; }
            var f = _pLife[i] * 100 / 10;
            if (f > 100) { f = 100; }
            dc.setColor(_renderer.shade(_pCol[i], f), Graphics.COLOR_TRANSPARENT);
            var r = (_pLife[i] > 6) ? 2 : 1;
            dc.fillRectangle(_pX[i], _pY[i], r + 1, r + 1);
        }
    }

    hidden function _drawNumbers(dc) as Void {
        for (var i = 0; i < DM_NUMS; i++) {
            if (_dnLife[i] <= 0) { continue; }
            var f = _dnLife[i] * 100 / 12;
            dc.setColor(_renderer.shade(0x000000, 0), Graphics.COLOR_TRANSPARENT);
            dc.drawText(_dnX[i] + 1, _dnY[i] + 1, Graphics.FONT_XTINY, _dnTxt[i],
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(_renderer.shade(_dnCol[i], f), Graphics.COLOR_TRANSPARENT);
            dc.drawText(_dnX[i], _dnY[i], Graphics.FONT_XTINY, _dnTxt[i],
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Blood in the eyes: a red frame that tightens as you bleed out.
    hidden function _drawVignette(dc) as Void {
        if (_hero == null) { return; }
        var maxHp = _hero.maxHpTotal();
        if (maxHp <= 0) { return; }
        if (_hero.hp * 3 > maxHp) { return; }
        var sev = 100 - (_hero.hp * 300 / maxHp);
        if (sev < 0) { sev = 0; }
        var pulse = ((_tick / 4) % 3) * 6;
        var bands = 3;
        for (var i = 0; i < bands; i++) {
            var f = (sev + pulse) * (bands - i) / (bands * 2);
            if (f > 60) { f = 60; }
            dc.setColor(_renderer.shade(0xCC1111, f), Graphics.COLOR_TRANSPARENT);
            var t = 3 - i;
            var o = i * 3;
            dc.fillRectangle(o, o, _w - o * 2, t);
            dc.fillRectangle(o, _h - o - t, _w - o * 2, t);
            dc.fillRectangle(o, o, t, _h - o * 2);
            dc.fillRectangle(_w - o - t, o, t, _h - o * 2);
        }
    }

    hidden function _banner(dc, text as Lang.String, y as Lang.Number) as Void {
        var bw = _w - _w / 5;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_cx - bw / 2, y - 10, bw, 21, 5);
        dc.setColor(0x4A3A20, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(_cx - bw / 2, y - 10, bw, 21, 5);
        dc.setColor(0xFFDD99, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── HUD ─────────────────────────────────────────────────────────────────

    hidden function _drawHud(dc) as Void {
        // Top plate: floor, compass needle, level.
        var ty = _h / 22 + 2;
        dc.setColor(0x0A0806, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_cx - _w / 4, ty - 2, _w / 2, 17, 4);
        dc.setColor(0xC8A868, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx - _w / 8, ty, Graphics.FONT_XTINY,
            "F" + _floor.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx + _w / 8, ty, Graphics.FONT_XTINY,
            "L" + _hero.level.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        _drawCompass(dc, _cx, ty + 7);

        // Bottom plate: health and mana.
        var bw = _w / 2;
        var bx = _cx - bw / 2;
        var by = _h - _h / 7;
        dc.setColor(0x1A0E06, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx - 1, by - 1, bw + 2, 8);
        var pct = _hero.hp * bw / _hero.maxHpTotal();
        if (pct < 0) { pct = 0; }
        var hpCol = 0x44CC66;
        if (_hero.hp * 3 <= _hero.maxHpTotal()) { hpCol = 0xEE3322; }
        else if (_hero.hp * 2 <= _hero.maxHpTotal()) { hpCol = 0xEEAA22; }
        dc.setColor(hpCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, by, pct, 6);
        if (_hero.ward > 0) {
            dc.setColor(0xFFDD55, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, by, pct, 2);
        }

        var mm = _hero.maxManaTotal();
        if (mm > 0) {
            dc.setColor(0x0A1020, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx - 1, by + 8, bw + 2, 6);
            var mp = _hero.mana * bw / mm;
            if (mp < 0) { mp = 0; }
            dc.setColor(0x4488DD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, by + 9, mp, 4);
        }

        dc.setColor(0xCCBB99, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + 14, Graphics.FONT_XTINY,
            _hero.hp.format("%d") + "/" + _hero.maxHpTotal().format("%d") +
            "   " + _hero.gold.format("%d") + "g",
            Graphics.TEXT_JUSTIFY_CENTER);

        if (_hero.poison > 0) {
            dc.setColor(0x66DD44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx - 8, by + 3, 3);
        }
        if (_hero.keys > 0) {
            dc.setColor(0xDDBB66, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx + bw + 8, by + 3, 3);
        }

        _drawMinimap(dc);
    }

    // A needle that always points north — the cheapest way to stop a crawler
    // from feeling like a maze of identical corridors.
    hidden function _drawCompass(dc, x as Lang.Number, y as Lang.Number) as Void {
        var r = 6;
        dc.setColor(0x2A2218, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        var d = _cam.dir;
        // North relative to facing: N is up when facing north, and rotates with you.
        var nx = 0;
        var ny = 0;
        if (d == DIR_N)      { nx = 0;  ny = -1; }
        else if (d == DIR_E) { nx = -1; ny = 0; }
        else if (d == DIR_S) { nx = 0;  ny = 1; }
        else                 { nx = 1;  ny = 0; }
        dc.setColor(0xEE4433, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + nx * (r - 3) - 1, y + ny * (r - 3) - 1, 3, 3);
        dc.setColor(0x8A7A60, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - nx * (r - 3) - 1, y - ny * (r - 3) - 1, 2, 2);
    }

    // Corner memory map. Inset from the bezel so it survives round screens.
    hidden function _drawMinimap(dc) as Void {
        var cell = _small ? 2 : 3;
        var side = cell * DM_W;
        var ox = _cx - (_w * 25) / 100 - side / 2;
        var oy = _cy - (_h * 25) / 100 - side / 2;
        if (ox < 2) { ox = 2; }
        if (oy < 2) { oy = 2; }

        dc.setColor(0x08080A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ox - 2, oy - 2, side + 4, side + 4);
        for (var y = 0; y < DM_H; y++) {
            for (var x = 0; x < DM_W; x++) {
                if (!_map.seen(x, y)) { continue; }
                var t = _map.at(x, y);
                var col = 0x000000;
                if (t == T_FLOOR)           { col = 0x3A3228; }
                else if (t == T_STAIRS)     { col = 0x44CC88; }
                else if (t == T_DOOR_OPEN)  { col = 0x8A5A2C; }
                else if (t == T_DOOR)       { col = 0xAA7A3C; }
                else if (t == T_LOCKED)     { col = 0xCCAA44; }
                else if (t == T_SECRET)     { col = 0x8844AA; }
                else                        { col = 0x1A1814; }
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ox + x * cell, oy + y * cell, cell, cell);
            }
        }
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ox + _cam.tileX() * cell - 1, oy + _cam.tileY() * cell - 1,
            cell + 2, cell + 2);
    }

    // One line telling the player what the primary action will do.
    hidden function _drawPrompt(dc) as Void {
        var text = null;
        var ax = _cam.aheadX();
        var ay = _cam.aheadY();
        var mi = _map.monsterAt(ax, ay);
        if (mi >= 0) {
            text = "FIGHT " + DmConst.eliteName(_map.monElite[mi]) +
                   DmConst.monName(_map.monType[mi]);
        } else {
            var t = _map.at(ax, ay);
            if (t == T_DOOR)   { text = "DOOR - OPEN"; }
            if (t == T_LOCKED) {
                if (_hero.keys > 0) { text = "LOCKED - USE KEY (" + _hero.keys.format("%d") + ")"; }
                else { text = "LOCKED - FORCE IT"; }
            }
            var fi = _map.featAt(ax, ay);
            if (fi >= 0 && _map.featUsed[fi] == 0) { text = DmConst.featName(_map.featKind[fi]); }
            if (_map.at(_cam.tileX(), _cam.tileY()) == T_STAIRS) {
                if (_floor >= DM_MAX_FLOOR) { text = "THE WAY OUT - CLIMB"; }
                else { text = "STAIRS - DESCEND"; }
            }
        }
        if (text == null) { return; }
        var bw = _w - _w / 4;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_cx - bw / 2, _cy - _h / 4 - 10, bw, 20, 4);
        dc.setColor(0xFFCC66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy - _h / 4, Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function _drawDescend(dc) as Void {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _cy - 34, _w, 68);
        dc.setColor(0x66DDAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy - 18, Graphics.FONT_SMALL, "FLOOR " + _floor.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0xC8A868, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy + 4, Graphics.FONT_XTINY, DmConst.zoneName(_floor),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x8A7A60, Graphics.COLOR_TRANSPARENT);
        var sub = "DEEPER INTO THE DARK";
        if (_floor % 5 == 0) { sub = "SOMETHING VAST STIRS"; }
        if (_floor == DM_MAX_FLOOR) { sub = "THE WAY OUT IS ABOVE"; }
        dc.drawText(_cx, _cy + 20, Graphics.FONT_XTINY, sub,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── Combat screen ───────────────────────────────────────────────────────

    hidden function _drawCombat(dc) as Void {
        // The fighter is drawn by hand (not as a corridor billboard) so it can
        // flash, bob and lunge with the round.
        var size = _h * 42 / 100;
        var baseY = _cy + _h / 10;
        if (_combat.flashMon > 0) {
            // Hit flash: blow out the silhouette for a frame or two.
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cx, baseY - size / 2, size / 2);
        }
        _renderer.drawMonsterArt(dc, _combat.monType, _combat.monElite, _cx, baseY, size,
            100, _combat.lunge);

        _drawCombatFx(dc, _cx, baseY - size / 2, size);

        // Enemy nameplate.
        var top = _h / 12;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_cx - _w * 2 / 5, top - 2, _w * 4 / 5, 26, 4);
        var mcol = DmConst.monColor(_combat.monType);
        if (_combat.monElite != EL_NONE) { mcol = DmConst.eliteColor(_combat.monElite); }
        if (_combat.flashMon > 0) { mcol = 0xFFFFFF; }
        dc.setColor(mcol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, top - 2, Graphics.FONT_XTINY, _combat.fullName(),
            Graphics.TEXT_JUSTIFY_CENTER);

        var bw = _w / 2;
        var bx = _cx - bw / 2;
        dc.setColor(0x2A0E0A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, top + 16, bw, 6);
        var mp = _combat.monHp * bw / _combat.monMaxHp;
        if (mp < 0) { mp = 0; }
        dc.setColor(_combat.isBoss ? 0xEE4422 : 0xCC3322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, top + 16, mp, 6);
        if (_combat.monShield > 0) {
            dc.setColor(0xBBCCDD, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, top + 16, bw, 2);
        }

        // Action wheel: previous / current / next, so five options fit anywhere.
        var wy = _h - _h * 30 / 100;
        var n = ACT_COUNT;
        var cur = _combat.sel;
        var lblPrev = "";
        var lblCur = "";
        var lblNext = "";
        var col = 0xFFCC44;
        if (_combat.mode == CS_ACTIONS) {
            lblPrev = _combat.actionLabel((cur + n - 1) % n, _hero);
            lblCur  = _combat.actionLabel(cur, _hero);
            lblNext = _combat.actionLabel((cur + 1) % n, _hero);
            if (cur == ACT_POWER && _combat.powerCd > 0) { col = 0x776650; }
        } else if (_combat.mode == CS_SPELLS) {
            n = SP_COUNT + 1;
            cur = _combat.spellSel;
            lblPrev = _combat.spellLabel((cur + n - 1) % n, _hero);
            lblCur  = _combat.spellLabel(cur, _hero);
            lblNext = _combat.spellLabel((cur + 1) % n, _hero);
            col = (cur < SP_COUNT) ? DmConst.spellColor(cur) : 0xAAAAAA;
            if (cur < SP_COUNT && !_hero.canCast(cur)) { col = 0x775544; }
        } else {
            n = 4;
            cur = _combat.itemSel;
            lblPrev = _combat.itemLabel((cur + n - 1) % n, _hero);
            lblCur  = _combat.itemLabel(cur, _hero);
            lblNext = _combat.itemLabel((cur + 1) % n, _hero);
        }
        _wheel(dc, wy, lblPrev, lblCur, lblNext, col);

        // Log line + hero vitals.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, _h - _h / 8 - 12, _w, _h / 8 + 12);
        dc.setColor(0xEEDDBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h - _h / 8 - 12, Graphics.FONT_XTINY, _combat.msg,
            Graphics.TEXT_JUSTIFY_CENTER);
        if (_combat.mode == CS_SPELLS && cur < SP_COUNT) {
            // While the spell wheel is open the vitals line becomes the tell for
            // whatever is highlighted — you pick a spell knowing what it does.
            dc.setColor(0x99AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h - _h / 8 + 2, Graphics.FONT_XTINY,
                DmConst.spellHint(cur), Graphics.TEXT_JUSTIFY_CENTER);
        } else if (!_combat.msg2.equals("")) {
            dc.setColor(0xEE8866, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h - _h / 8 + 2, Graphics.FONT_XTINY, _combat.msg2,
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var hcol = (_combat.flashPlayer > 0) ? 0xFF6644 : 0xAACC88;
            dc.setColor(hcol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h - _h / 8 + 2, Graphics.FONT_XTINY,
                "HP " + _hero.hp.format("%d") + "   MP " + _hero.mana.format("%d"),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _wheel(dc, y as Lang.Number, prev as Lang.String, cur as Lang.String,
                           next as Lang.String, col as Lang.Number) as Void {
        dc.setColor(0x6A5C48, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y - 15, Graphics.FONT_XTINY, prev, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_cx, y + 16, Graphics.FONT_XTINY, next, Graphics.TEXT_JUSTIFY_CENTER);
        var bw = _w - _w / 4;
        dc.setColor(0x3A2A08, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_cx - bw / 2, y - 2, bw, 18, 4);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y - 1, Graphics.FONT_XTINY, cur, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Weapon arcs, spell blooms and impact sparks.
    hidden function _drawCombatFx(dc, x as Lang.Number, y as Lang.Number, size as Lang.Number) as Void {
        var fx = _combat.fx;
        if (fx == FX_NONE || _combat.fxTick <= 0) { return; }
        var t = _combat.fxTick;

        if (fx == FX_SLASH || fx == FX_HEAVY) {
            var r = size / 2 + t * 3;
            dc.setPenWidth(fx == FX_HEAVY ? 5 : 3);
            dc.setColor(fx == FX_HEAVY ? 0xFFDD66 : 0xEEEEFF, Graphics.COLOR_TRANSPARENT);
            var a0 = 300 - t * 12;
            dc.drawArc(x, y, r, Graphics.ARC_CLOCKWISE, a0 + 70, a0);
            dc.setPenWidth(1);
            return;
        }
        if (fx == FX_FIRE || fx == FX_BOMB) {
            var r2 = size / 5 + (7 - t) * size / 12;
            dc.setColor(0xFF7722, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r2);
            dc.setColor(0xFFDD55, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r2 * 2 / 3);
            dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r2 / 3);
            return;
        }
        if (fx == FX_FROST) {
            dc.setColor(0x88DDFF, Graphics.COLOR_TRANSPARENT);
            var r3 = size / 3 + (7 - t) * 3;
            for (var i = 0; i < 6; i++) {
                var dx = ((i % 3) - 1) * r3;
                var dy = ((i / 3) * 2 - 1) * r3 / 2;
                dc.fillRectangle(x + dx - 1, y + dy - 4, 3, 9);
                dc.fillRectangle(x + dx - 4, y + dy - 1, 9, 3);
            }
            return;
        }
        if (fx == FX_HEAL || fx == FX_WARD) {
            var c = (fx == FX_HEAL) ? 0x66EE99 : 0xFFDD55;
            dc.setPenWidth(3);
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(_cx, _cy, _w / 3 + (6 - t) * 4);
            dc.setPenWidth(1);
            return;
        }
        if (fx == FX_MISS) {
            dc.setColor(0x99AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y - 10, Graphics.FONT_XTINY, "MISS",
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        // Enemy blow: claw streaks across the player's view.
        dc.setPenWidth(3);
        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 3; i++) {
            var ox = (i - 1) * _w / 8;
            dc.drawLine(_cx + ox - _w / 6, _cy - _h / 5, _cx + ox + _w / 8, _cy + _h / 4);
        }
        dc.setPenWidth(1);
    }

    // ── Loot card ───────────────────────────────────────────────────────────

    hidden function _drawLoot(dc) as Void {
        var pw = _w - _w / 6;
        var ph = _h * 52 / 100;
        var px = _cx - pw / 2;
        var py = _cy - ph / 2;
        var rc = DmConst.rarityColor(_lootRar);

        // Light rays behind the item for anything better than common.
        if (_lootRar != RAR_COMMON) {
            dc.setColor(_renderer.shade(rc, 30), Graphics.COLOR_TRANSPARENT);
            var spin = (_tick / 3) % 8;
            for (var i = 0; i < 8; i++) {
                var a = i * 45 + spin * 5;
                var dx = _rayX(a);
                var dy = _rayY(a);
                dc.drawLine(_cx, _cy - ph / 8, _cx + dx, _cy - ph / 8 + dy);
            }
        }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, 8);
        dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, 8);

        dc.drawText(_cx, py + 6, Graphics.FONT_XTINY, DmConst.rarityName(_lootRar),
            Graphics.TEXT_JUSTIFY_CENTER);
        _renderer.drawItemIcon(dc, _lootKind, 1, _cx, py + ph / 2 - 6, ph / 8);
        dc.setColor(DmConst.lootColor(_lootKind), Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, py + ph / 2 + 4, Graphics.FONT_XTINY, DmConst.lootName(_lootKind),
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, py + ph / 2 + 20, Graphics.FONT_XTINY, _lootMsg,
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x8A7A60, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, py + ph - 18, Graphics.FONT_XTINY, "SELECT continue",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Eight fixed ray directions without trig.
    hidden function _rayX(a as Lang.Number) as Lang.Number {
        var i = (a / 45) % 8;
        var r = _w / 2;
        if (i == 0) { return r; }
        if (i == 1) { return r * 7 / 10; }
        if (i == 2) { return 0; }
        if (i == 3) { return -r * 7 / 10; }
        if (i == 4) { return -r; }
        if (i == 5) { return -r * 7 / 10; }
        if (i == 6) { return 0; }
        return r * 7 / 10;
    }

    hidden function _rayY(a as Lang.Number) as Lang.Number {
        var i = (a / 45) % 8;
        var r = _h / 2;
        if (i == 0) { return 0; }
        if (i == 1) { return r * 7 / 10; }
        if (i == 2) { return r; }
        if (i == 3) { return r * 7 / 10; }
        if (i == 4) { return 0; }
        if (i == 5) { return -r * 7 / 10; }
        if (i == 6) { return -r; }
        return -r * 7 / 10;
    }

    // ── Level up ────────────────────────────────────────────────────────────

    hidden function _drawLevelUp(dc) as Void {
        var pw = _w - _w / 8;
        var ph = _h * 68 / 100;
        var px = _cx - pw / 2;
        var py = _cy - ph / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, 8);
        dc.setColor(0xFFDD66, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, 8);
        dc.drawText(_cx, py + 5, Graphics.FONT_XTINY,
            "LEVEL " + _hero.level.format("%d") + "!", Graphics.TEXT_JUSTIFY_CENTER);

        var y = py + 26;
        var step = (ph - 44) / UP_COUNT;
        if (step < 14) { step = 14; }
        for (var i = 0; i < UP_COUNT; i++) {
            var sel = (i == _lvlSel);
            if (sel) {
                dc.setColor(0x3A2A08, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(px + 4, y - 1, pw - 8, step - 1, 3);
            }
            dc.setColor(sel ? 0xFFCC44 : 0x8A7A60, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, y, Graphics.FONT_XTINY, _hero.upgradeLabel(i),
                Graphics.TEXT_JUSTIFY_CENTER);
            y += step;
        }
    }

    // ── Pack ────────────────────────────────────────────────────────────────

    hidden function _drawPack(dc) as Void {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h);
        if (_packPage == 1) { _drawSheet(dc); return; }
        if (_packPage == 2) { _drawMapPage(dc); return; }

        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h / 14, Graphics.FONT_XTINY, "PACK", Graphics.TEXT_JUSTIFY_CENTER);

        // Window of five rows around the selection keeps it readable at 208px.
        var show = 5;
        var first = _packSel - 2;
        if (first < 0) { first = 0; }
        if (first > PACK_ROWS - show) { first = PACK_ROWS - show; }
        var step = 17;
        var y = _cy - (show * step) / 2 + 4;
        for (var i = first; i < first + show; i++) {
            var sel = (i == _packSel);
            if (sel) {
                dc.setColor(0x3A2A08, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(_cx - _w * 2 / 5, y - 1, _w * 4 / 5, step - 1, 3);
            }
            var col = sel ? 0xFFDD88 : 0x8A7A60;
            if (i == PACK_MEND && !_hero.canCast(SP_HEAL)) { col = sel ? 0xAA7755 : 0x5A4A38; }
            if (i == PACK_WARD && !_hero.canCast(SP_WARD)) { col = sel ? 0xAA7755 : 0x5A4A38; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, y, Graphics.FONT_XTINY, _packLabel(i), Graphics.TEXT_JUSTIFY_CENTER);
            y += step;
        }

        dc.setColor(0x6A5C48, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h - _h / 9, Graphics.FONT_XTINY,
            "MP " + _hero.mana.format("%d") + "/" + _hero.maxManaTotal().format("%d") +
            "   MENU pages", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawSheet(dc) as Void {
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h / 14, Graphics.FONT_XTINY,
            DmConst.className(_hero.cls) + "  LV" + _hero.level.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);

        // XP bar.
        var bw = _w / 2;
        var bx = _cx - bw / 2;
        var by = _h / 14 + 18;
        dc.setColor(0x1A1810, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, by, bw, 4);
        var need = DmConst.xpForLevel(_hero.level);
        var p = (need > 0) ? _hero.xp * bw / need : 0;
        if (p > bw) { p = bw; }
        dc.setColor(0x66AAEE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx, by, p, 4);

        var y = by + 10;
        var step = 15;
        dc.setColor(0xAACC88, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY,
            "STR " + _hero.totalStr().format("%d") + "  DEF " + _hero.totalDefense().format("%d") +
            "  MAG " + _hero.totalMagic().format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        y += step;
        dc.setColor(0x99AAEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY,
            "LUCK " + _hero.totalLuck().format("%d") + "  MANA " + _hero.mana.format("%d") +
            "/" + _hero.maxManaTotal().format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        y += step;
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY, DmConst.weaponName(_hero.weapon),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += step;
        dc.setColor(0x99AABB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY, DmConst.armorName(_hero.armor),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += step;
        dc.setColor(0xFFAA33, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY, DmConst.ringName(_hero.ring),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += step;
        dc.setColor(0xCC66FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY, DmConst.amuletName(_hero.amulet),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += step;
        dc.setColor(0x8A7A60, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY,
            "KEYS " + _hero.keys.format("%d") + "  BOMBS " + _hero.bombs.format("%d") +
            "  " + _hero.gold.format("%d") + "g", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Explored-tiles map — the reward for walking the halls.
    hidden function _drawMapPage(dc) as Void {
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h / 16, Graphics.FONT_XTINY,
            "FLOOR " + _floor.format("%d") + " / " + DM_MAX_FLOOR.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);
        var cell = (_h * 62) / 100 / DM_H;
        if (cell < 3) { cell = 3; }
        var ox = _cx - (cell * DM_W) / 2;
        var oy = _cy - (cell * DM_H) / 2 + 4;
        for (var y = 0; y < DM_H; y++) {
            for (var x = 0; x < DM_W; x++) {
                if (!_map.seen(x, y)) { continue; }
                var t = _map.at(x, y);
                var col = 0x1A1814;
                if (t == T_FLOOR)          { col = 0x3A3228; }
                else if (t == T_STAIRS)    { col = 0x44CC88; }
                else if (t == T_DOOR_OPEN) { col = 0x8A5A2C; }
                else if (t == T_DOOR)      { col = 0xAA7A3C; }
                else if (t == T_LOCKED)    { col = 0xCCAA44; }
                else if (t == T_SECRET)    { col = 0x8844AA; }
                else if (t == T_PILLAR)    { col = 0x5A5248; }
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ox + x * cell, oy + y * cell, cell - 1, cell - 1);
            }
        }
        // Live entities you have already seen.
        for (var i = 0; i < _map.trapN; i++) {
            if (_map.trapArmed[i] == 0 || !_map.seen(_map.trapX[i], _map.trapY[i])) { continue; }
            dc.setColor(0xEE5533, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ox + _map.trapX[i] * cell + 1, oy + _map.trapY[i] * cell + 1,
                cell - 3 > 1 ? cell - 3 : 1, cell - 3 > 1 ? cell - 3 : 1);
        }
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(ox + _cam.tileX() * cell, oy + _cam.tileY() * cell, cell, cell);
        dc.setColor(0x6A5C48, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h - _h / 9, Graphics.FONT_XTINY,
            _secrets.format("%d") + " secrets   SELECT close", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Shrine / fountain ───────────────────────────────────────────────────

    hidden function _drawFeature(dc) as Void {
        var kind = (_featIdx >= 0) ? _map.featKind[_featIdx] : FEAT_SHRINE;
        var pw = _w - _w / 7;
        var ph = _h * 60 / 100;
        var px = _cx - pw / 2;
        var py = _cy - ph / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, 8);
        dc.setColor(kind == FEAT_FOUNTAIN ? 0x66AADD : 0xCC88FF, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, 8);
        dc.drawText(_cx, py + 5, Graphics.FONT_XTINY, DmConst.featName(kind),
            Graphics.TEXT_JUSTIFY_CENTER);

        _renderer.drawFeature(dc, _cx, py + ph / 2 - 4, ph / 2, kind, 0, 100);

        if (!_featMsg.equals("")) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, py + ph - 42, Graphics.FONT_XTINY, _featMsg,
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x8A7A60, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, py + ph - 22, Graphics.FONT_XTINY, "SELECT continue",
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var n = _featRows();
        var step = 16;
        var y = py + ph - 6 - n * step;
        for (var i = 0; i < n; i++) {
            var sel = (i == _featSel);
            if (sel) {
                dc.setColor(0x2A2038, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(px + 4, y - 1, pw - 8, step - 1, 3);
            }
            dc.setColor(sel ? 0xFFDD88 : 0x8A7A60, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, y, Graphics.FONT_XTINY, _featLabel(i), Graphics.TEXT_JUSTIFY_CENTER);
            y += step;
        }
    }

    hidden function _drawShop(dc) as Void {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h / 16, Graphics.FONT_XTINY, "TRADER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCBB99, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h / 16 + 15, Graphics.FONT_XTINY,
            _hero.gold.format("%d") + " GOLD", Graphics.TEXT_JUSTIFY_CENTER);

        var show = 4;
        var first = _shopSel - 1;
        if (first < 0) { first = 0; }
        if (first > 6 - show) { first = 6 - show; }
        var step = 17;
        var y = _cy - 14;
        for (var i = first; i < first + show; i++) {
            var sel = (i == _shopSel);
            if (sel) {
                dc.setColor(0x3A2A08, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(_cx - _w * 2 / 5, y - 1, _w * 4 / 5, step - 1, 3);
            }
            var afford = (i == 5) || (_hero.gold >= _shopPrice(i));
            var col = 0x5A4A38;
            if (sel && afford) { col = 0xFFDD88; }
            else if (sel) { col = 0xAA6655; }
            else if (afford) { col = 0x8A7A60; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, y, Graphics.FONT_XTINY, _shopLabel(i), Graphics.TEXT_JUSTIFY_CENTER);
            y += step;
        }
        if (!_featMsg.equals("")) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _h - _h / 8, Graphics.FONT_XTINY, _featMsg,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── End of run ──────────────────────────────────────────────────────────

    hidden function _drawDead(dc) as Void {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, _h);

        // A last piece of art: your own tomb, or the mouth of the dungeon.
        if (_won) {
            dc.setColor(0x223A2A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, _cy - _h / 8, _w, _h / 4);
            dc.setColor(0x66DDAA, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 5; i++) {
                dc.drawLine(_cx - _w / 3 + i * _w / 7, _cy + _h / 8, _cx, _cy - _h / 8);
            }
        }

        dc.setColor(_won ? 0x66DDAA : 0xCC3322, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h / 8, Graphics.FONT_SMALL,
            _won ? "ESCAPED!" : "YOU DIED", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x9A8A70, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h / 8 + 24, Graphics.FONT_XTINY, _deathCause,
            Graphics.TEXT_JUSTIFY_CENTER);

        var y = _cy - 8;
        dc.setColor(0xEEDDBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY,
            "FLOOR " + _deepest.format("%d") + "/" + DM_MAX_FLOOR.format("%d") +
            "   LV " + _hero.level.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        y += 16;
        dc.drawText(_cx, y, Graphics.FONT_XTINY,
            _hero.gold.format("%d") + "g   " + _kills.format("%d") + " slain   " +
            _bossKills.format("%d") + " bosses", Graphics.TEXT_JUSTIFY_CENTER);
        y += 16;
        dc.setColor(0x99CCEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY,
            _secrets.format("%d") + " secrets   " + _discovered.format("%d") + " tiles",
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 20;
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, Graphics.FONT_XTINY, "SCORE " + _score().format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x8A7A60, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _h - _h / 7, Graphics.FONT_XTINY, "SELECT delve again",
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}
