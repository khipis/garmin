// ═══════════════════════════════════════════════════════════════════════════
// CreaturesView.mc — The BITOCHI CREATURES gameplay view.
//
// A five-screen carousel (HOME · ACTIONS · EVOLVE · DAILY · INDEX) over a single
// CreatureModel. NAVIGATION works three ways so it is robust on every device and
// the emulator:
//   • TAP a tab dot in the top strip to jump straight to a page.
//   • TAP the on-screen ◀ / ▶ chevrons (screen edges) to page prev/next.
//   • Physical UP/DOWN move the cursor on list pages and "overflow" to the
//     adjacent page at the ends; on non-list pages they page directly.
//     SELECT/ENTER activates the focused action. BACK saves + exits.
// A DEMO fast-track auto-develops a creature egg->apex for showcasing. Sound +
// haptics are gated by the shared "Sound & Haptics" option (cr_fx).
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;
using Toybox.System;

const CV_HOME  = 0;
const CV_ACT   = 1;
const CV_EVO   = 2;
const CV_ARENA = 3;
const CV_RIVAL = 4;
const CV_DAY   = 5;
const CV_COL   = 6;
const CV_PAGES = 7;

// View ticks per replayed strike, and how many of them the hit flash lasts.
const CV_STRIKE_TICKS = 7;
const CV_FLASH_TICKS  = 3;

// ARENA rows: AGG / BAL / DEF / GEAR / FAIR / RISK.
const CV_ARENA_ROWS = 6;
// Equipment rows visible at once in the gear card.
const CV_GEAR_FIT = 4;
// Rival rows visible at once on the RIVALS page. The list always carries one
// extra row after the players — the manual refresh.
const CV_RIVAL_FIT = 3;
// INDEX rows visible at once (section headers included).
const CV_COL_FIT = 5;

class CreaturesView extends WatchUi.View {
    hidden var _m;
    hidden var _page;
    hidden var _w; hidden var _h;
    hidden var _t;
    hidden var _timer;
    hidden var _fxOn;

    hidden var _popup; hidden var _popupT;
    hidden var _welcome;         // showing idle-summary overlay
    hidden var _hatchFlash;      // showing the just-hatched celebration
    hidden var _intro;           // first-run "stats are the currency" explainer
    hidden var _raidMail;        // async "you were fought" inbox overlay
    hidden var _actCursor;       // 0=FEED 1=TRAIN 2=QUEST (or dest when questing)
    hidden var _questPick;       // ACTIONS sub-mode: pick expedition destination
    hidden var _pathPick;        // overlay: choose evolution path
    hidden var _pathCursor;      // 0..3 → Runner..Dynamo
    hidden var _colScroll;

    hidden var _battle;          // overlay: arena battle in progress / result
    hidden var _battleData;      // last fight() result Dictionary
    hidden var _battleStep;      // strikes replayed so far
    hidden var _battleT;         // sub-tick counter for strike pacing

    hidden var _gearOpen;        // overlay: equipment picker
    hidden var _gearCur;         // 0 = AUTO, then one row per unlocked item
    hidden var _gearScroll;
    hidden var _gearIds;         // unlocked equipment ids, rebuilt on open/equip

    hidden var _roster;          // once-a-day rival fetch (fire and forget)
    hidden var _inbox;           // async raid-mail pull (never blocks play)
    hidden var _rivals;          // [rosterIndex, ArenaFoe] per rival, rebuilt on change
    hidden var _rivN;            // roster size _rivals was built from
    hidden var _rivCur;          // cursor on the RIVALS list (last row = refresh)
    hidden var _rivScroll;

    hidden var _demo;            // DEMO fast-track active
    hidden var _demoCtr;         // sub-tick counter for demo pacing

    // Tap rects [x,y,w,h] recomputed each draw.
    hidden var _rBtnA; hidden var _rBtnB; hidden var _rBtnC; hidden var _rBtnD;
    hidden var _rBtnE; hidden var _rBtnF;
    hidden var _rPrev; hidden var _rNext;
    hidden var _rTabs;           // array of tab-dot hit rects
    hidden var _rDemo;           // DEMO toggle pill

    function initialize() {
        View.initialize();
        _m = new CreatureModel();
        _page = CV_HOME;
        _w = 0; _h = 0; _t = 0; _timer = null;
        _popup = null; _popupT = 0;
        _welcome = false; _hatchFlash = false; _intro = false; _raidMail = false;
        _actCursor = 0; _questPick = false; _pathPick = false; _pathCursor = 0; _colScroll = 0;
        _battle = false; _battleData = null; _battleStep = 0; _battleT = 0;
        _gearOpen = false; _gearCur = 0; _gearScroll = 0; _gearIds = null;
        _roster = null; _inbox = null; _rivals = null; _rivN = -1; _rivCur = 0; _rivScroll = 0;
        _demo = false; _demoCtr = 0;
        _rBtnA = null; _rBtnB = null; _rBtnC = null; _rBtnD = null; _rBtnE = null;
        _rBtnF = null;
        _rPrev = null; _rNext = null; _rTabs = null; _rDemo = null;
        _loadFx();
        _loadDemo();

        // Boot the world: create the egg on first run, hatch if the timer is up,
        // then reconcile idle progress and (throttled) publish leaderboard scores.
        try { _m.ensureEgg(); } catch (e) {}
        var wasEgg = !_m.hatched;
        try { _m.maybeHatch(); } catch (e) {}
        try { _m.collectOffline(); } catch (e) {}
        if (wasEgg && _m.hatched) { _hatchFlash = true; }
        else if (_m.hatched && (_m.gXp > 0 || _m.gFood > 0 || _m.gMut > 0 || _m.defHits > 0)) { _welcome = true; }
        try { if (_m.needsPathPick()) { _pathPick = true; _pathCursor = _m.suggestedPath() - 1; if (_pathCursor < 0) { _pathCursor = 0; } } } catch (e) {}
        try { _m.submitScores(); } catch (e) {}
        try { _m.equipDefaults(); } catch (e) {}
        // Rivals are a bonus, never a dependency: this arms a delayed, guarded,
        // once-a-day GET and nothing downstream waits on it.
        try { _roster = new ArenaRoster(_m); _roster.arm(); } catch (e) {}
        try { _inbox = new LbRaidInbox(Cr.GAME_ID, _m); _inbox.arm(); } catch (e) {}

        // One-time explainer: Garmin stats are the currency here.
        try {
            var seen = Application.Storage.getValue("cr_intro");
            if (!(seen instanceof Lang.Number) || seen != 1) { _intro = true; }
        } catch (e) { _intro = true; }
    }

    function model() { return _m; }

    hidden function _loadFx() {
        _fxOn = true;
        try {
            var v = Application.Storage.getValue("cr_fx");
            if (v instanceof Lang.Number) { _fxOn = (v == 0); }  // index 0 = ON
        } catch (e) {}
    }
    hidden function _loadDemo() {
        _demo = false;
        if (!Cr.SHOW_DEMO) { return; }   // showcase-only; never active for users
        try {
            var v = Application.Storage.getValue("cr_demo");
            if (v instanceof Lang.Number) { _demo = (v == 1); }  // index 1 = ON
        } catch (e) {}
    }
    hidden function _saveDemo() {
        try { Application.Storage.setValue("cr_demo", _demo ? 1 : 0); } catch (e) {}
    }
    hidden function _focus() {
        try {
            var v = Application.Storage.getValue("cr_focus");
            if (v instanceof Lang.Number) { return v; }
        } catch (e) {}
        return 0;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:_tick), 66, true); } catch (e) {}
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
        try { if (_roster != null) { _roster.stop(); } } catch (e) {}
        try { if (_inbox != null) { _inbox.stop(); } } catch (e) {}
        try { _m.save(); } catch (e) {}
    }

    function _tick() as Void {
        _t = (_t + 1) % 1000000;
        if (_popupT > 0) { _popupT -= 1; if (_popupT == 0) { _popup = null; } }
        try { if (_roster != null) { _roster.poll(); } } catch (e) {}
        try { if (_inbox != null) { _inbox.poll(); } } catch (e) {}
        try { _checkRaidMail(); } catch (e) {}

        // Battle replay: the fight is already fully resolved, so the timer only
        // walks a cursor along it. CV_STRIKE_TICKS is short enough that eight
        // rounds stay watchable rather than becoming a wait.
        if (_battle && _battleData != null) {
            _battleT += 1;
            if (_battleT >= CV_STRIKE_TICKS) {
                _battleT = 0;
                var st = _battleSteps();
                if (_battleStep < st.size()) {
                    _battleStep += 1;
                    // Only crits and the verdict buzz: a beep on all sixteen
                    // strikes is a nuisance on the wrist, and every _vibe call
                    // allocates a VibeProfile.
                    var crit = false;
                    try { crit = (st[_battleStep - 1][4] == 1); } catch (e) {}
                    if (crit) { _tone(1); _vibe(45, 40); }
                    if (_battleStep >= st.size()) {
                        var won = false;
                        try { won = _battleData["won"]; } catch (e) {}
                        _tone(won ? 4 : 2); _vibe(won ? 60 : 40, won ? 120 : 80);
                    }
                }
            }
        }

        if (_demo) {
            _demoCtr += 1;
            if (_demoCtr >= 10) {   // ~0.66s per demo step
                _demoCtr = 0;
                try {
                    var msg = _m.demoStep();
                    if (msg != null) { _popup = msg; _popupT = 22; }
                } catch (e) {}
            }
        } else if (!_m.hatched) {
            // Live-hatch an egg while the player watches.
            try {
                if (_m.maybeHatch()) { _hatchFlash = true; _tone(4); _vibe(80, 160); }
            } catch (e) {}
        }
        WatchUi.requestUpdate();
    }

    // ── Feedback (guarded) ────────────────────────────────────────────────────
    function _tone(kind) {
        if (!_fxOn) { return; }
        try {
            if (!(Attention has :playTone)) { return; }
            var t = Attention.TONE_KEY;
            if (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
            else if (kind == 2) { t = Attention.TONE_ERROR; }
            else if (kind == 3) { t = Attention.TONE_INTERVAL_ALERT; }
            else if (kind == 4) { t = Attention.TONE_SUCCESS; }
            Attention.playTone(t);
        } catch (e) {}
    }
    function _vibe(intensity, dur) {
        if (!_fxOn) { return; }
        try {
            if (!(Attention has :vibrate)) { return; }
            var p = [new Attention.VibeProfile(intensity, dur)];
            Attention.vibrate(p);
        } catch (e) {}
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    function pageMove(d) {
        if (closeGear()) { return; }
        if (_dismissOverlay()) { return; }
        _page = ((_page + d) % CV_PAGES + CV_PAGES) % CV_PAGES;
        _actCursor = 0; _colScroll = 0;
        // The roster can be replaced by a fetch that finished while the page was
        // off screen, so entering RIVALS always rebuilds the rows from it.
        if (_page == CV_RIVAL) { _rivN = -1; }
        _tone(0); _vibe(15, 20);
        WatchUi.requestUpdate();
    }
    function setPage(p) {
        if (closeGear()) { return; }
        if (_dismissOverlay()) { return; }
        _page = ((p % CV_PAGES) + CV_PAGES) % CV_PAGES;
        _actCursor = 0; _colScroll = 0;
        if (_page == CV_RIVAL) { _rivN = -1; }
        _tone(0); _vibe(12, 16);
        WatchUi.requestUpdate();
    }

    hidden function _dismissOverlay() {
        if (_battle) {
            var st = _battleSteps();
            if (_battleStep < st.size()) {
                _battleStep = st.size();   // SELECT / tap skips straight to the result
            } else {
                _battle = false; _battleData = null;
            }
            WatchUi.requestUpdate();
            return true;
        }
        if (_raidMail) { _raidMail = false; WatchUi.requestUpdate(); return true; }
        if (_welcome) { _welcome = false; WatchUi.requestUpdate(); return true; }
        if (_hatchFlash) { _hatchFlash = false; WatchUi.requestUpdate(); return true; }
        if (_intro) {
            _intro = false;
            try { Application.Storage.setValue("cr_intro", 1); } catch (e) {}
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
    hidden function _battleRounds() { return _battleField("rounds"); }
    hidden function _battleSteps()  { return _battleField("steps"); }
    hidden function _battleField(key) {
        if (_battleData == null) { return []; }
        var r = null;
        try { r = _battleData[key]; } catch (e) {}
        if (!(r instanceof Lang.Array)) { return []; }
        return r;
    }
    hidden function _battleNum(key, def) {
        if (_battleData == null) { return def; }
        var v = null;
        try { v = _battleData[key]; } catch (e) {}
        if (!(v instanceof Lang.Number)) { return def; }
        return v;
    }

    // Scroll ceiling for the INDEX list. Read off the same builder the page
    // draws from, so section headers and a growing journal can never leave rows
    // that the cursor cannot reach.
    hidden function _colMaxScroll() {
        var n = 0;
        try { n = _colRows().size() - CV_COL_FIT; } catch (e) {}
        return (n < 0) ? 0 : n;
    }

    // UP/DOWN: move a cursor where there is a list, else page. At a list's end,
    // "overflow" to the adjacent page so you can traverse the whole game.
    function cursorMove(d) {
        if (_pathPick) {
            var np = _pathCursor + d;
            if (np < 0) { np = 3; }
            if (np > 3) { np = 0; }
            _pathCursor = np; _tone(0); WatchUi.requestUpdate();
            return;
        }
        if (_gearOpen) { _gearMove(d); return; }
        if (_dismissOverlay()) { return; }
        if (!_m.hatched) { return; }          // egg screen: nothing to scroll

        if (_page == CV_ACT) {
            var maxC = _questPick ? 3 : 2;
            var nc = _actCursor + d;
            if (nc < 0) {
                if (_questPick) { _questPick = false; _actCursor = 2; WatchUi.requestUpdate(); return; }
                pageMove(-1); return;
            }
            if (nc > maxC) {
                if (_questPick) { _questPick = false; pageMove(1); return; }
                pageMove(1);  return;
            }
            _actCursor = nc; _tone(0); WatchUi.requestUpdate();
            return;
        }
        if (_page == CV_COL) {
            var ns = _colScroll + d;
            if (ns < 0) { pageMove(-1); return; }
            if (ns > _colMaxScroll()) { pageMove(1); return; }
            _colScroll = ns; _tone(0); WatchUi.requestUpdate();
            return;
        }
        if (_page == CV_ARENA) {
            var na = _actCursor + d;
            if (na < 0) { pageMove(-1); return; }
            if (na > CV_ARENA_ROWS - 1) { pageMove(1); return; }
            _actCursor = na; _tone(0); WatchUi.requestUpdate();
            return;
        }
        if (_page == CV_RIVAL) {
            _rivalsEnsure();
            var nr = _rivCur + d;
            if (nr < 0) { pageMove(-1); return; }
            if (nr > _rivals.size() - 1) { pageMove(1); return; }
            _rivCur = nr;
            if (_rivCur < _rivScroll) { _rivScroll = _rivCur; }
            if (_rivCur >= _rivScroll + CV_RIVAL_FIT) { _rivScroll = _rivCur - CV_RIVAL_FIT + 1; }
            _tone(0); WatchUi.requestUpdate();
            return;
        }
        pageMove(d);
    }

    // Context activation (SELECT / ENTER).
    function activate() {
        if (_pathPick) { doPickPath(); return; }
        if (_gearOpen) { doGearSelect(); return; }
        if (_dismissOverlay()) { return; }
        if (!_m.hatched) { doBoost(); return; }
        if (_page == CV_HOME) { setPage(CV_ACT); return; }
        if (_page == CV_ACT) {
            if (_questPick) { doQuest(_actCursor); return; }
            if (_actCursor == 0) { doFeed(); }
            else if (_actCursor == 1) { doTrain(); }
            else { _questPick = true; _actCursor = 0; WatchUi.requestUpdate(); }
            return;
        }
        if (_page == CV_ARENA) {
            if (_actCursor <= 2) { doSetStrategy(_actCursor); return; }
            if (_actCursor == 3) { openGear(); return; }
            doFight(_actCursor == 4 ? 0 : 1);
            return;
        }
        if (_page == CV_RIVAL) { doFightRival(_rivCur); return; }
        if (_page == CV_DAY) {
            // Prefer bond claim when daily already claimed / incomplete.
            try {
                if (_m.bondComplete() && !_m.bondClaimed) { doClaimBond(); return; }
            } catch (e) {}
            doClaim(); return;
        }
        if (_page == CV_EVO) {
            // SELECT on EVOLVE is the button-only route to ASCEND (it always
            // goes through the confirmation menu, so it can't wipe by accident).
            var canAsc = false;
            try { canAsc = _m.canAscend(); } catch (e) {}
            if (canAsc) { askAscend(); } else { setPage(CV_ACT); }
            return;
        }
        if (_page == CV_COL) { setPage(CV_HOME); return; }
    }

    // ── Ascension ─────────────────────────────────────────────────────────────
    // Always confirm: this trades the current creature for a new egg.
    function askAscend() {
        try {
            if (!_m.canAscend()) { return; }
            crOpenAscend(self);
        } catch (e) {}
    }
    // Confirm → perk menu (askPerk) → doAscendWithPerk.
    function doAscend() as Void { askPerk(); }
    function askPerk() as Void {
        try { if (!_m.canAscend()) { return; } crOpenPerkPick(self); } catch (e) {}
    }
    function doAscendWithPerk(perkId) as Void {
        try {
            if (!_m.canAscend()) { return; }
            _m.ascendWithPerk(perkId);
            _page = CV_HOME;
            _welcome = false; _hatchFlash = false; _pathPick = false; _questPick = false;
            _actCursor = 0; _colScroll = 0;
            _popup = "ASCENDED! " + Cr.perkName(perkId); _popupT = 44;
            _tone(4); _vibe(80, 160);
            WatchUi.requestUpdate();
        } catch (e) {}
    }

    function toggleDemo() {
        _demo = !_demo;
        _demoCtr = 0;
        _saveDemo();
        _popup = _demo ? "DEMO ON" : "DEMO OFF";
        _popupT = 24;
        _tone(_demo ? 4 : 0); _vibe(30, 40);
        WatchUi.requestUpdate();
    }

    // ── Actions (all guarded) ──────────────────────────────────────────────────
    hidden function _act(res, evoBefore) {
        if (_m.evo > evoBefore) {
            _popup = "EVOLVED! " + Cr.stageName(_m.evo);
            _popupT = 40; _tone(4); _vibe(70, 140);
            try {
                if (_m.needsPathPick()) {
                    _pathPick = true;
                    _pathCursor = _m.suggestedPath() - 1;
                    if (_pathCursor < 0) { _pathCursor = 0; }
                }
            } catch (e) {}
        } else {
            _popup = res; _popupT = 26;
        }
        WatchUi.requestUpdate();
    }
    function doFeed() {
        try {
            var e = _m.evo; var r = _m.feed();
            _tone(0); _vibe(20, 30); _act(r, e);
        } catch (ex) {}
    }
    function doTrain() {
        try {
            var e = _m.evo;
            var f = _focus();
            var focusTrait = -1;
            if (f == 1) { focusTrait = Cr.TR_SPD; }
            else if (f == 2) { focusTrait = Cr.TR_STR; }
            else if (f == 3) { focusTrait = Cr.TR_INT; }
            else if (f == 4) { focusTrait = Cr.TR_NRG; }
            var r = _m.train(focusTrait);
            _tone(1); _vibe(35, 45); _act(r, e);
        } catch (ex) {}
    }
    function doQuest(dest) {
        try {
            var e = _m.evo; var r = _m.quest(dest);
            _questPick = false; _actCursor = 2;
            _tone(0); _vibe(20, 30); _act(r, e);
            try {
                if (_m.needsPathPick()) {
                    _pathPick = true;
                    _pathCursor = _m.suggestedPath() - 1;
                    if (_pathCursor < 0) { _pathCursor = 0; }
                }
            } catch (e2) {}
        } catch (ex) {}
    }
    function doPickPath() {
        try {
            var p = Cr.PATH_RUNNER + _pathCursor;
            if (_m.pickPath(p)) {
                _pathPick = false;
                _popup = Cr.pathName(p) + "! " + Cr.pathPower(p);
                _popupT = 40; _tone(4); _vibe(60, 120);
                WatchUi.requestUpdate();
            }
        } catch (e) {}
    }
    function doClaimBond() {
        try {
            if (_m.claimBond()) {
                _popup = "BOND REWARD! " + _m.bondRewardText();
                _popupT = 36; _tone(4); _vibe(50, 100);
                WatchUi.requestUpdate();
            }
        } catch (e) {}
    }
    function doBoost() {
        try {
            _m.boost();
            if (_m.maybeHatch()) { _hatchFlash = true; _tone(4); _vibe(80, 160); }
            else { _popup = "Boosted! -30 min"; _popupT = 26; _tone(0); _vibe(20, 30); }
            WatchUi.requestUpdate();
        } catch (ex) {}
    }
    function doClaim() {
        try {
            if (_m.claimDaily()) {
                _popup = "Reward claimed!"; _popupT = 34; _tone(4); _vibe(60, 120);
            } else if (_m.dailyClaimed) {
                _popup = "Already claimed today"; _popupT = 24;
            } else {
                _popup = "Not complete yet"; _popupT = 24; _tone(2);
            }
            WatchUi.requestUpdate();
        } catch (ex) {}
    }

    // ── Arena ─────────────────────────────────────────────────────────────────
    function doSetStrategy(s) {
        try {
            _m.setStrategy(s);
            _popup = Cr.strategyName(s) + " stance";
            _popupT = 22; _tone(0); _vibe(15, 20);
            WatchUi.requestUpdate();
        } catch (e) {}
    }
    function doFight(band) {
        try {
            var res = _m.fight(band);
            _battleData = res;
            _battleStep = 0; _battleT = 0;
            _battle = true;
            _tone(0); _vibe(25, 35);
            WatchUi.requestUpdate();
        } catch (e) {}
    }
    // Challenge the player on row `row` of the RIVALS list. The reward band is
    // the power gap, so picking the giant at the top of the board pays like
    // RISK without the player having to say so.
    function doFightRival(row) {
        try {
            _rivalsEnsure();
            if (row < 0 || row >= _rivals.size()) { return; }
            var res = _m.fightRival(_rivals[row][0]);
            if (res == null) {
                _popup = "That rival left the board"; _popupT = 26; _tone(2);
                _rivals = null; _rivN = -1;
                WatchUi.requestUpdate();
                return;
            }
            _battleData = res;
            _battleStep = 0; _battleT = 0;
            _battle = true;
            _tone(0); _vibe(25, 35);
            WatchUi.requestUpdate();
        } catch (e) {}
    }

    // ── Equipment picker ──────────────────────────────────────────────────────
    // Row 0 is AUTO (the old equipBest behaviour, kept as a one-tap shortcut);
    // every row after it is an unlocked item that SELECT equips into its slot,
    // or takes off if it is already worn. The id list is built when the card
    // opens rather than per draw.
    function openGear() {
        _buildGearIds();
        _gearOpen = true; _gearCur = 0; _gearScroll = 0;
        _tone(0); _vibe(14, 18);
        WatchUi.requestUpdate();
    }
    function closeGear() {
        if (!_gearOpen) { return false; }
        _gearOpen = false;
        _tone(0); _vibe(10, 14);
        WatchUi.requestUpdate();
        return true;
    }
    hidden function _buildGearIds() {
        var ids = [];
        for (var i = 0; i < Cr.EQ_N; i++) {
            var ok = false;
            try { ok = _m.eqUnlocked(i); } catch (e) {}
            if (ok) { ids.add(i); }
        }
        _gearIds = ids;
    }
    hidden function _gearRows() {
        return ((_gearIds == null) ? 0 : _gearIds.size()) + 1;
    }
    hidden function _gearMove(d) {
        var n = _gearRows();
        var nc = _gearCur + d;
        if (nc < 0) { nc = n - 1; }
        if (nc >= n) { nc = 0; }
        _gearCur = nc;
        if (_gearCur < _gearScroll) { _gearScroll = _gearCur; }
        if (_gearCur >= _gearScroll + CV_GEAR_FIT) { _gearScroll = _gearCur - CV_GEAR_FIT + 1; }
        _tone(0); _vibe(8, 12);
        WatchUi.requestUpdate();
    }
    function doGearSelect() {
        try {
            if (_gearCur == 0) {
                _m.equipBest();
                _popup = "AUTO: best gear equipped"; _popupT = 26;
                _tone(4); _vibe(30, 40);
                WatchUi.requestUpdate();
                return;
            }
            var idx = _gearCur - 1;
            if (_gearIds == null || idx < 0 || idx >= _gearIds.size()) { return; }
            var id = _gearIds[idx];
            var worn = _gearWorn(id);
            if (_m.equipItem(id)) {
                _popup = (worn ? "Removed " : "Equipped ") + Cr.eqName(id);
                _popupT = 26; _tone(0); _vibe(25, 30);
                WatchUi.requestUpdate();
            }
        } catch (e) {}
    }
    hidden function _gearWorn(id) {
        return _m.eqWeapon == id || _m.eqArmor == id || _m.eqArt == id;
    }
    // The card's four visible rows ride on the shared button rects, laid out by
    // _drawGear; CV_GEAR_FIT is what keeps the two in step.
    hidden function _gearRect(g) {
        if (g == 0) { return _rBtnA; }
        if (g == 1) { return _rBtnB; }
        if (g == 2) { return _rBtnC; }
        return _rBtnD;
    }
    // "+16A" / "+10D" / "+8S" — only the bonuses an item actually carries.
    hidden function _gearBonus(id) {
        var s = "";
        var a = Cr.eqAtkPct(id); if (a > 0) { s += "+" + a + "A "; }
        var d = Cr.eqDefPct(id); if (d > 0) { s += "+" + d + "D "; }
        var p = Cr.eqSpdPct(id); if (p > 0) { s += "+" + p + "S"; }
        return s;
    }

    // ── Tap hit-testing (called by delegate) ──────────────────────────────────
    function onTapXY(x, y) {
        if (_pathPick) {
            // Four path buttons A/B/C + reuse prev/next area as 4th via cursor cycle;
            // tap a row to select that path index.
            if (_inRect(x, y, _rBtnA)) { _pathCursor = 0; doPickPath(); return true; }
            if (_inRect(x, y, _rBtnB)) { _pathCursor = 1; doPickPath(); return true; }
            if (_inRect(x, y, _rBtnC)) { _pathCursor = 2; doPickPath(); return true; }
            if (_inRect(x, y, _rBtnD)) { _pathCursor = 3; doPickPath(); return true; }
            doPickPath(); return true;
        }
        if (_gearOpen) {
            if (_inRect(x, y, _rBtnF)) { closeGear(); return true; }
            for (var g = 0; g < CV_GEAR_FIT; g++) {
                var rr = _gearRect(g);
                if (_inRect(x, y, rr)) {
                    var row = _gearScroll + g;
                    if (row < _gearRows()) { _gearCur = row; doGearSelect(); }
                    return true;
                }
            }
            return true;
        }
        if (_battle || _welcome || _hatchFlash || _intro) { _dismissOverlay(); return true; }

        // DEMO pill is always live.
        if (_inRect(x, y, _rDemo)) { toggleDemo(); return true; }

        if (!_m.hatched) {
            if (_inRect(x, y, _rBtnB)) { doBoost(); return true; }
            return true;
        }

        // Tab dots: jump straight to a page.
        if (_rTabs != null) {
            for (var i = 0; i < _rTabs.size(); i++) {
                if (_inRect(x, y, _rTabs[i])) { setPage(i); return true; }
            }
        }
        // Edge chevrons: prev / next.
        if (_inRect(x, y, _rPrev)) { pageMove(-1); return true; }
        if (_inRect(x, y, _rNext)) { pageMove(1);  return true; }

        if (_page == CV_ACT) {
            if (_questPick) {
                if (_inRect(x, y, _rBtnA)) { _actCursor = 0; doQuest(0); return true; }
                if (_inRect(x, y, _rBtnB)) { _actCursor = 1; doQuest(1); return true; }
                if (_inRect(x, y, _rBtnC)) { _actCursor = 2; doQuest(2); return true; }
                if (_inRect(x, y, _rBtnD)) { _actCursor = 3; doQuest(3); return true; }
                return true;
            }
            if (_inRect(x, y, _rBtnA)) { _actCursor = 0; doFeed(); return true; }
            if (_inRect(x, y, _rBtnB)) { _actCursor = 1; doTrain(); return true; }
            if (_inRect(x, y, _rBtnC)) {
                _actCursor = 2; _questPick = true; _actCursor = 0;
                WatchUi.requestUpdate(); return true;
            }
        }
        if (_page == CV_ARENA) {
            if (_inRect(x, y, _rBtnA)) { _actCursor = 0; doSetStrategy(0); return true; }
            if (_inRect(x, y, _rBtnB)) { _actCursor = 1; doSetStrategy(1); return true; }
            if (_inRect(x, y, _rBtnC)) { _actCursor = 2; doSetStrategy(2); return true; }
            if (_inRect(x, y, _rBtnD)) { _actCursor = 3; openGear(); return true; }
            if (_inRect(x, y, _rBtnE)) { _actCursor = 4; doFight(0); return true; }
            if (_inRect(x, y, _rBtnF)) { _actCursor = 5; doFight(1); return true; }
        }
        if (_page == CV_RIVAL) {
            _rivalsEnsure();
            for (var g = 0; g < CV_RIVAL_FIT; g++) {
                var rr = (g == 0) ? _rBtnA : ((g == 1) ? _rBtnB : _rBtnC);
                if (!_inRect(x, y, rr)) { continue; }
                var row = _rivScroll + g;
                if (row >= _rivals.size()) { return true; }
                // First tap focuses the row, second commits: a fight moves the
                // ladder points, so it never fires from a stray tap.
                if (_rivCur != row) {
                    _rivCur = row; _tone(0); _vibe(12, 16);
                    WatchUi.requestUpdate();
                    return true;
                }
                doFightRival(row);
                return true;
            }
        }
        if (_page == CV_DAY) {
            if (_inRect(x, y, _rBtnA)) {
                try {
                    if (_m.bondComplete() && !_m.bondClaimed) { doClaimBond(); return true; }
                } catch (e) {}
                doClaim(); return true;
            }
            if (_inRect(x, y, _rBtnB)) { doClaimBond(); return true; }
        }
        if (_page == CV_EVO) {
            if (_inRect(x, y, _rBtnA)) { askAscend(); return true; }
        }
        if (_page == CV_HOME) { setPage(CV_ACT); return true; }
        return true;
    }
    hidden function _inRect(x, y, r) {
        if (r == null) { return false; }
        return x >= r[0] && x < r[0] + r[2] && y >= r[1] && y < r[1] + r[3];
    }

    // ═══ Rendering ════════════════════════════════════════════════════════════
    function onUpdate(dc) {
        try { _draw(dc); }
        catch (e) { try { dc.setColor(Cr.BG, Cr.BG); dc.clear(); } catch (e2) {} }
    }

    hidden function _draw(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
        var cx = _w / 2;
        _rBtnA = null; _rBtnB = null; _rBtnC = null; _rBtnD = null; _rBtnE = null;
        _rBtnF = null;
        _rTabs = null; _rPrev = null; _rNext = null;

        dc.setColor(Cr.BG, Cr.BG); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }

        if (!_m.hatched) {
            _drawEggScreen(dc);
            _drawDemoPill(dc);
        } else if (_page == CV_HOME) {
            // HOME is the full-watch diorama: paint the scene first, then let
            // the tab strip + chevrons ride on top (with a text shadow so the
            // chrome stays legible over the bright scene). No demo pill / hint.
            _drawHome(dc);
            _drawTabStrip(dc);
            _drawChevrons(dc);
        } else {
            _drawTabStrip(dc);
            if (_page == CV_ACT) { _drawActions(dc); }
            else if (_page == CV_EVO) { _drawEvolution(dc); }
            else if (_page == CV_ARENA) { _drawArena(dc); }
            else if (_page == CV_RIVAL) { _drawRivals(dc); }
            else if (_page == CV_DAY) { _drawDaily(dc); }
            else { _drawCollection(dc); }
            _drawChevrons(dc);
            _drawHint(dc);
            _drawDemoPill(dc);
        }

        if (_popup != null) { _drawPopup(dc); }
        if (_welcome) { _drawWelcome(dc); }
        if (_raidMail && !_welcome) { _drawRaidMail(dc); }
        if (_hatchFlash) { _drawHatch(dc); }
        if (_intro && _m.hatched && !_welcome && !_hatchFlash && !_raidMail) { _drawIntro(dc); }
        if (_pathPick && _m.hatched && !_welcome && !_hatchFlash && !_intro && !_raidMail) { _drawPathPick(dc); }
        if (_battle && _m.hatched && !_welcome && !_hatchFlash && !_intro && !_pathPick && !_raidMail) { _drawBattle(dc); }
        if (_gearOpen && _m.hatched && !_battle && !_welcome && !_hatchFlash && !_intro && !_pathPick && !_raidMail) { _drawGear(dc); }
    }

    // ── Round-screen safety ───────────────────────────────────────────────────
    // Half the drawable width at row y. Wide elements are measured against this
    // instead of the full screen width, or they run under the bezel on the
    // upper and lower chords. Integer sqrt so nothing in layout goes floating.
    hidden function _chordHalf(y) {
        if (_w != _h) { return _w / 2; }
        var r = _w / 2;
        var dy = y - _h / 2; if (dy < 0) { dy = -dy; }
        if (dy >= r) { return 0; }
        return _isqrt(r * r - dy * dy);
    }
    hidden function _isqrt(n) {
        if (n <= 0) { return 0; }
        var x = n; var y = (x + 1) / 2; var g = 0;
        while (y < x && g < 40) { x = y; y = (x + n / x) / 2; g += 1; }
        return x;
    }
    // Centred pixel-font text, truncated to whatever the chord allows at that
    // row. `pad` keeps it clear of the bezel rather than flush against it.
    hidden function _pxFit(dc, s, cx, y, sc, col, pad) {
        if (s == null) { return; }
        var glyph = 5 * sc;
        var maxw = _chordHalf(y + glyph) * 2 - pad * 2;
        if (maxw < 4 * sc) { return; }
        var str = s;
        while (str.length() > 2 && Px.gtxtW(str, sc) > maxw) {
            str = str.substring(0, str.length() - 1);
        }
        Px.gtxtC(dc, str, cx, y, sc, col);
    }

    // ── Small helpers ──────────────────────────────────────────────────────────
    hidden function _bar(dc, x, y, w, h, pct, col) {
        dc.setColor(Cr.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, h / 2);
        var fw = w * Cr._clamp(pct, 0, 100) / 100;
        if (fw < h && fw > 0) { fw = h; }
        if (fw > 0) {
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, fw, h, h / 2);
        }
    }
    hidden function _txt(dc, x, y, font, col, s, just) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, just);
    }

    // ── Top tab strip: page name + tappable dots (all pages) ─────────────────
    hidden function _pageName(p) {
        if (p == CV_HOME)  { return "HOME"; }
        if (p == CV_ACT)   { return "ACTIONS"; }
        if (p == CV_EVO)   { return "EVOLVE"; }
        if (p == CV_ARENA) { return "ARENA"; }
        if (p == CV_RIVAL) { return "RIVALS"; }
        if (p == CV_DAY)   { return "DAILY"; }
        return "INDEX";
    }
    hidden function _pageColor(p) {
        if (p == CV_ACT)   { return Cr.ACCENT; }
        if (p == CV_EVO)   { return 0xB46CFF; }
        if (p == CV_ARENA) { return 0xFF5A5A; }
        if (p == CV_RIVAL) { return 0xFF9A3A; }
        if (p == CV_DAY)   { return Cr.GOLD; }
        if (p == CV_COL)   { return 0x4CA8FF; }
        return Cr.TEXT;
    }
    hidden function _drawTabStrip(dc) {
        var cx = _w / 2;
        // Page name — tiny pixel font (drastically smaller than the old
        // FONT_TINY header), shadowed, and white on HOME so it never blends
        // into the bright full-screen diorama.
        var hsc = _h / 190; if (hsc < 2) { hsc = 2; }
        var hcol = (_page == CV_HOME) ? 0xFFFFFF : _pageColor(_page);
        Px.gshC(dc, _pageName(_page), cx, _h * 7 / 100, hsc, hcol);

        // Row of tappable dots.
        var y = _h * 15 / 100;
        var gap = _w * 9 / 100;
        var x0 = cx - gap * (CV_PAGES - 1) / 2;
        _rTabs = new [CV_PAGES];
        var hitW = gap * 90 / 100;
        for (var i = 0; i < CV_PAGES; i++) {
            var dx = x0 + i * gap;
            var on = (i == _page);
            dc.setColor(on ? _pageColor(i) : 0x33414F, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dx, y, on ? 4 : 3);
            if (on) {
                dc.setColor(_pageColor(i), Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(dx, y, 7);
            }
            _rTabs[i] = [dx - hitW / 2, y - _h * 6 / 100, hitW, _h * 12 / 100];
        }
    }

    // Visible + tappable edge chevrons.
    hidden function _drawChevrons(dc) {
        var w = _w * 12 / 100;
        var midY = _h * 50 / 100;
        var zh = _h * 24 / 100;
        _rPrev = [0, midY - zh / 2, w, zh];
        _rNext = [_w - w, midY - zh / 2, w, zh];

        var s = _h * 3 / 100;
        var lx = _w * 4 / 100;
        var rx = _w - _w * 4 / 100;
        dc.setColor(Cr.MUTED, Graphics.COLOR_TRANSPARENT);
        // ◀
        dc.fillPolygon([[lx + s, midY - s], [lx - s, midY], [lx + s, midY + s]]);
        // ▶
        dc.fillPolygon([[rx - s, midY - s], [rx + s, midY], [rx - s, midY + s]]);
    }

    hidden function _drawHint(dc) {
        _txt(dc, _w / 2, _h * 94 / 100, Graphics.FONT_XTINY, 0x5A6B7C,
             "TAP  ·  \u25B2\u25BC  ·  SELECT", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawDemoPill(dc) {
        // DEMO is a showcase-only fast-track — hidden from users in shipped
        // builds. When hidden, draw nothing and keep the hit-rect null so it
        // can never be toggled.
        if (!Cr.SHOW_DEMO) { _rDemo = null; return; }
        var pw = _w * 22 / 100; var ph = _h * 8 / 100;
        var px = _w * 76 / 100 - pw / 2;
        var py = _h * 2 / 100;
        _rDemo = [px, py, pw, ph];
        var on = _demo;
        dc.setColor(on ? 0x3A1030 : Cr.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, ph / 2);
        dc.setColor(on ? 0xFF4C7A : 0x2A3A4A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, ph / 2);
        dc.setColor(on ? 0xFFB0C8 : Cr.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(px + pw / 2, py + ph / 2, Graphics.FONT_XTINY, "DEMO",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── EGG SCREEN ──────────────────────────────────────────────────────────────
    hidden function _drawEggScreen(dc) {
        var cx = _w / 2;
        var hsc = _h / 190; if (hsc < 2) { hsc = 2; }
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        Px.gshC(dc, "EGG " + (_m.seed % 100000), cx, _h * 7 / 100, hsc, 0xFFFFFF);

        var r = _h * 18 / 100;   // ~10% smaller than before
        CreatureArt.drawEgg(dc, _m, cx, _h * 37 / 100, r, _t);

        // DNA progress.
        var by = _h * 64 / 100;
        var bw = _w * 60 / 100; var bx = cx - bw / 2;
        Px.gtxtC(dc, "DNA " + _m.hatchPct() + "%", cx, by - _h * 6 / 100, sc, Cr.TEXT);
        _bar(dc, bx, by, bw, 10, _m.hatchPct(), Cr.speciesColor(_m.species));

        // Countdown.
        _txt(dc, cx, by + _h * 7 / 100, Graphics.FONT_TINY, Cr.TEXT,
             _fmtHMS(_m.hatchRemaining()), Graphics.TEXT_JUSTIFY_CENTER);
        Px.gtxtC(dc, "UNTIL HATCH", cx, by + _h * 15 / 100, sc, Cr.MUTED);

        // BOOST button.
        var bwr = _w * 44 / 100; var bxr = cx - bwr / 2;
        var byr = _h * 84 / 100; var bhr = _h * 12 / 100;
        _rBtnB = [bxr, byr, bwr, bhr];
        _button(dc, _rBtnB, "BOOST", true);
    }

    // ── HOME — the pixel SANCTUARY fills the WHOLE watch ─────────────────────
    // The diorama is the star: it fills the entire screen (x0=0,y0=0,w=_w,h=_h)
    // and a single slim bottom ribbon overlays glanceable stats. Every number /
    // action lives on the sibling pages. Mirrors ISLAND's _drawHome exactly.
    hidden function _drawHome(dc) {
        var mx = _w * 25 / 1000; var my = _h * 25 / 1000;
        try { CreatureArt.drawSanctuary(dc, _m, mx, my, _w - mx * 2, _h - my * 2, _t, false); } catch (e) {}
        try { _homeOverlay(dc); } catch (e) {}
    }

    // Slim bottom ribbon on a dark scrim: banked FOOD (hero currency, left) ·
    // "Lv N · stage" (centre) · a rotating vital (right). Sized from the real
    // FONT_XTINY height so it can never overlap, and ~15% slimmer than the old
    // stacked plates (barH = fhX*1.28 vs the old plate's fhX*1.66).
    hidden function _homeOverlay(dc) {
        var cx = _w / 2;
        var round = (_w == _h);
        // Tiny pixel-font banner: dramatically smaller than FONT_XTINY, bright,
        // crisp, and short enough that it never smothers the diorama. Mirrors
        // ISLAND's _homeOverlay geometry exactly.
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        var gh = 5 * sc;
        var barH = gh + sc * 4; if (barH < 13) { barH = 13; }
        var barW = round ? _w * 62 / 100 : _w * 80 / 100;
        var bx = cx - barW / 2;
        var by = round ? (_h * 85 / 100 - barH / 2) : (_h - barH - _h * 3 / 100);
        var midY = by + barH / 2;
        var gy = midY - gh / 2;
        var pad = barH / 4; if (pad < 3) { pad = 3; }

        dc.setColor(0x05100A, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, barW, barH, barH / 3);
        dc.setColor(Cr.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, barW, barH, barH / 3);

        // Left: banked FOOD with its small berry icon (the hero currency).
        var ipx = gh / 4; if (ipx < 2) { ipx = 2; }
        var ix = bx + pad;
        try { CreatureArt.drawBerryIcon(dc, ix, midY - 2 * ipx, ipx); } catch (e) {}
        Px.gtxt(dc, "" + _m.food, ix + 4 * ipx + sc, gy, sc, 0xFFD9B0);

        // Centre: level + evolution stage. On the narrower round chord the stage
        // is trimmed to 3 chars so it can't clip against the food / vital ends.
        var stage = Cr.stageName(_m.evo);
        if (round && stage.length() > 3) { stage = stage.substring(0, 3); }
        Px.gtxtC(dc, "LV " + _m.level + " " + stage, cx, gy, sc, Cr.TEXT);

        // Right: one rotating vital (energy / mood / xp%).
        var rs = _rotStat();
        Px.gtxt(dc, rs, bx + barW - pad - Px.gtxtW(rs, sc), gy, sc, 0x37D0C0);
    }

    // Rotating right-hand vital for the HOME ribbon. Veterans get a fourth slot
    // showing their ascension count — the centre "LV n stage" text has no room
    // left on a round chord.
    hidden function _rotStat() {
        var n = (_m.asc > 0) ? 4 : 3;
        var idx = (_t / 90) % n;
        if (idx == 0) { return "En " + _m.energy; }
        if (idx == 1) { return "Md " + _m.mood; }
        if (idx == 2) {
            var need = _m.xpNeeded(); if (need < 1) { need = 1; }
            return "XP " + (_m.xp * 100 / need) + "%";
        }
        if (_m.path != Cr.PATH_NONE) { return Cr.pathName(_m.path); }
        return "ASC " + _m.asc;
    }

    // First-run explainer overlay: stats are the currency.
    hidden function _drawIntro(dc) {
        var cx = _w / 2;
        dc.setColor(0x050912, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }
        // A little pixel creature to set the tone.
        try { CreatureArt.drawHero(dc, _m, cx, _h * 38 / 100, _h * 20 / 100 / 8, _t); } catch (e) {}

        _txt(dc, cx, _h * 52 / 100, Graphics.FONT_SMALL, Cr.ACCENT,
             "YOUR STATS = FUEL", Graphics.TEXT_JUSTIFY_CENTER);
        _wrapText(dc, cx, _h * 62 / 100, _w * 82 / 100, Graphics.FONT_XTINY, Cr.TEXT,
                  "Feed, train, QUEST to relics. Pick a path at Juvenile. Mood matters.");
        _txt(dc, cx, _h * 82 / 100, Graphics.FONT_XTINY, Cr.GOLD,
             "steps \u2192 growth   HR \u2192 energy", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 91 / 100, Graphics.FONT_XTINY, Cr.MUTED,
             "tap to begin", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────────
    hidden function _drawActions(dc) {
        var cx = _w / 2;
        var fhX = dc.getFontHeight(Graphics.FONT_XTINY);
        var pad = fhX / 3; if (pad < 2) { pad = 2; }

        CreatureArt.drawHero(dc, _m, cx, _h * 20 / 100, _h * 10 / 100 / 8, _t);

        // Vitals block (relocated from HOME): Lv/xp row → xp bar → energy+mood
        // bars, plus the banked food count centred on the header row. Sized
        // from the real FONT_XTINY height so the text can never touch the bars.
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        var gh = 5 * sc;
        var barH = fhX * 42 / 100; if (barH < 4) { barH = 4; }
        var bw = _w * 62 / 100; var bx = cx - bw / 2;
        var need = _m.xpNeeded(); if (need < 1) { need = 1; }
        var rowY = _h * 30 / 100;
        // Tiny pixel-font labels so the vitals plate never smothers the hero.
        // Only two items on the top row (LV left, FOOD right) so long demo
        // numbers can never overlap; the xp fraction sits centred on its own
        // line just above the xp bar.
        Px.gtxt(dc, "LV " + _m.level, bx, rowY, sc, Cr.GOLD);
        var foodStr = "FOOD " + _m.food;
        Px.gtxt(dc, foodStr, bx + bw - Px.gtxtW(foodStr, sc), rowY, sc, 0xFF8A3A);
        var xpStr = _m.xp + "/" + need;
        var xpY = rowY + gh + pad;
        Px.gtxtC(dc, xpStr, cx, xpY, sc, Cr.MUTED);
        var bar1Y = xpY + gh + 2;
        _bar(dc, bx, bar1Y, bw, barH, _m.xp * 100 / need, Cr.ACCENT);
        var bar2Y = bar1Y + barH + pad;
        _bar(dc, bx, bar2Y, bw / 2 - 4, barH, _m.energy, 0xFF8A3A);
        _bar(dc, cx + 4, bar2Y, bw / 2 - 4, barH, _m.mood, 0xFF5A9A);

        var bwb = _w * 56 / 100; var bxb = cx - bwb / 2;
        var bh = _h * 11 / 100;
        var gap = _h * 15 / 1000;
        var y0 = _h * 48 / 100;
        if (_questPick) {
            // Compact 4-destination expedition picker.
            bh = _h * 9 / 100;
            y0 = _h * 46 / 100;
            _rBtnA = [bxb, y0, bwb, bh];
            _rBtnB = [bxb, y0 + bh + gap, bwb, bh];
            _rBtnC = [bxb, y0 + (bh + gap) * 2, bwb, bh];
            _rBtnD = [bxb, y0 + (bh + gap) * 3, bwb, bh];
            for (var d = 0; d < 4; d++) {
                var rr = (d == 0) ? _rBtnA : ((d == 1) ? _rBtnB : ((d == 2) ? _rBtnC : _rBtnD));
                var lab = Cr.destName(d) + " " + Cr.destHint(d);
                _button(dc, rr, lab, _actCursor == d);
            }
            Px.gtxtC(dc, "QUEST  energy cost shown in result", cx, _h * 92 / 100, sc, Cr.MUTED);
        } else {
            _rBtnA = [bxb, y0, bwb, bh];
            _rBtnB = [bxb, y0 + bh + gap, bwb, bh];
            _rBtnC = [bxb, y0 + (bh + gap) * 2, bwb, bh];
            _button(dc, _rBtnA, "FEED", _actCursor == 0);
            _button(dc, _rBtnB, "TRAIN", _actCursor == 1);
            _button(dc, _rBtnC, "QUEST", _actCursor == 2);
            var moodHint = "";
            if (_m.mood < Cr.MOOD_SULK) { moodHint = "SULKING — feed me"; }
            else if (_m.mood < Cr.MOOD_LOW) { moodHint = "Low mood — weaker quests"; }
            else if (_m.path != Cr.PATH_NONE) { moodHint = Cr.pathPower(_m.path); }
            if (moodHint.length() > 0) {
                var mcol = Cr.MUTED;
                if (_m.mood < Cr.MOOD_LOW) { mcol = 0xFF8A3A; }
                Px.gtxtC(dc, moodHint, cx, _h * 92 / 100, sc, mcol);
            }
        }
    }

    // ── EVOLUTION ───────────────────────────────────────────────────────────────
    hidden function _drawEvolution(dc) {
        var cx = _w / 2;
        // At Apex or beyond the page grows an ASCEND button; the trait rows tighten
        // by 1% each so the button always clears the bottom hint line.
        var canAsc = false;
        try { canAsc = _m.canAscend(); } catch (e) {}

        var yy = _h * 21 / 100;
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        var gh = 5 * sc;
        var hdr = Cr.stageName(_m.evo);
        if (_m.asc > 0) { hdr += " A" + _m.asc; }
        Px.gtxtC(dc, hdr, cx, yy, sc, Cr.TEXT);
        var ns = _m.nextStage();
        var lbl = (ns < 0) ? "FINAL FORM" : "NEXT " + Cr.stageName(ns);
        Px.gtxtC(dc, lbl, cx, yy + _h * 7 / 100, sc, 0xB46CFF);

        var bw = _w * 62 / 100; var bx = cx - bw / 2;
        var by = yy + _h * 14 / 100;
        _bar(dc, bx, by, bw, 9, _m.evoProgressPct(), 0xB46CFF);
        Px.gtxtC(dc, _m.evoProgressPct() + "% to next  ·  DNA " + _m.mutations,
                 cx, by + _h * 5 / 100, sc, Cr.MUTED);
        Px.gtxtC(dc, "EVO PTS " + _m.evoPts, cx, by + _h * 10 / 100, sc, 0xB46CFF);

        // Trait bars (extra spacing). The label sits in a reserved left column so
        // it can never touch the bar that starts after it. Bars are scaled to
        // TRAIT_MAX so a maxed trait fills the box exactly instead of overflowing.
        var ty = by + _h * 13 / 100;
        var rowH = canAsc ? _h * 64 / 1000 : _h * 82 / 1000;
        var labW = _w * 18 / 100;
        for (var i = 0; i < Cr.TR_N; i++) {
            var ry = ty + i * rowH;
            Px.gtxt(dc, Cr.traitAbbr(i), bx, ry, sc, Cr.TEXT);
            var tv = Cr._clamp(_m.traits[i], 0, Cr.TRAIT_MAX);
            _bar(dc, bx + labW, ry + gh / 2 - 3, bw - labW, 6,
                 tv * 100 / Cr.TRAIT_MAX, Cr.speciesColor(_m.species));
        }

        if (canAsc) {
            var bwr = _w * 46 / 100; var bxr = cx - bwr / 2;
            var byr = _h * 82 / 100; var bhr = _h * 11 / 100;
            _rBtnA = [bxr, byr, bwr, bhr];
            _button(dc, _rBtnA, "ASCEND", true);
        }
    }

    // ── ARENA — TRAIN → EVOLVE → EQUIP → BATTLE → RANK UP ──────────────────────
    // Compact "W2 A1 T-": which tier is worn in each slot. Full names live one
    // tap away in the gear card, so the summary only has to fit on a button.
    hidden function _eqSummary() {
        return _eqTag("W", _m.eqWeapon) + " " + _eqTag("A", _m.eqArmor)
             + " " + _eqTag("T", _m.eqArt);
    }
    hidden function _eqTag(letter, id) {
        if (id < 0) { return letter + "-"; }
        return letter + ((id % 4) + 1);
    }
    hidden function _drawArena(dc) {
        var cx = _w / 2;
        var sc = _h / 220; if (sc < 2) { sc = 2; }

        var rk = 0; var pw = 0;
        try { rk = _m.rank(); } catch (e) {}
        try { pw = _m.power(); } catch (e) {}

        var yy = _h * 13 / 100;
        Px.gtxtC(dc, "POWER " + pw, cx, yy, sc, Cr.TEXT);
        Px.gtxtC(dc, Cr.rankName(rk) + " " + _m.arenaPts + " PTS", cx, yy + _h * 6 / 100, sc, Cr.rankColor(rk));
        var rec = _m.arenaWins + "W-" + _m.arenaLosses + "L";
        if (_m.arenaStreak > 1) { rec += "  streak " + _m.arenaStreak; }
        Px.gtxtC(dc, rec, cx, yy + _h * 11 / 100, sc, Cr.MUTED);

        // GEAR row — opens the equipment picker.
        var gw = _w * 56 / 100; var gh = _h * 8 / 100;
        var gy = _h * 29 / 100;
        _rBtnD = [cx - gw / 2, gy, gw, gh];
        _button(dc, _rBtnD, "GEAR " + _eqSummary(), _actCursor == 3);

        // Strategy picker — 3 buttons.
        var sw = _w * 24 / 100; var sh = _h * 8 / 100; var sgap = _w * 3 / 100;
        var stripY = _h * 39 / 100;
        var sx0 = cx - (sw * 3 + sgap * 2) / 2;
        _rBtnA = [sx0, stripY, sw, sh];
        _rBtnB = [sx0 + sw + sgap, stripY, sw, sh];
        _rBtnC = [sx0 + (sw + sgap) * 2, stripY, sw, sh];
        var lblA = Cr.strategyAbbr(0); if (_m.strategy == 0) { lblA = "*" + lblA; }
        var lblB = Cr.strategyAbbr(1); if (_m.strategy == 1) { lblB = "*" + lblB; }
        var lblC = Cr.strategyAbbr(2); if (_m.strategy == 2) { lblC = "*" + lblC; }
        _button(dc, _rBtnA, lblA, _actCursor == 0);
        _button(dc, _rBtnB, lblB, _actCursor == 1);
        _button(dc, _rBtnC, lblC, _actCursor == 2);
        Px.gtxtC(dc, Cr.strategyHint(_m.strategy), cx, stripY + sh + _h * 3 / 100, sc, Cr.MUTED);

        // Opponent bands — FAIR (even) / RISK (stronger, better reward).
        var bw = _w * 32 / 100; var bh = _h * 9 / 100; var bgap = _w * 4 / 100;
        var by0 = _h * 55 / 100;
        _rBtnE = [cx - bw - bgap / 2, by0, bw, bh];
        _rBtnF = [cx + bgap / 2, by0, bw, bh];
        _button(dc, _rBtnE, "FAIR", _actCursor == 4);
        _button(dc, _rBtnF, "RISK", _actCursor == 5);
        var rivals = 0;
        try { rivals = _m.rivalCount(); } catch (e) {}
        // FAIR/RISK are the QUICK fight: the game picks the opponent. Naming the
        // RIVALS tab here is what tells a player the hand-picked route exists.
        var bandHint = (rivals > 0) ? ("quick fight  ·  " + rivals + " named on RIVALS")
                                    : "quick fight  ·  FAIR even, RISK stronger";
        _pxFit(dc, bandHint, cx, by0 + bh + _h * 3 / 100, sc, (rivals > 0) ? Cr.GOLD : Cr.MUTED, 6);

        // War log, then the most recent raid the player defended against. Three
        // rows fit between the FAIR/RISK strip and the bottom control hint.
        var logY = by0 + bh + _h * 8 / 100;
        var rowH = _h * 5 / 100;
        Px.gtxtC(dc, "WAR LOG", cx, logY, sc, 0xFF5555);
        var line = logY + rowH;
        var wl = _m.warLog;
        if (wl != null) {
            var shown = 0;
            for (var i = 0; i < wl.size() && shown < 2; i++) {
                var col = (wl[i].length() > 0 && wl[i].substring(0, 1).equals("W")) ? Cr.ACCENT : 0xFF5555;
                _pxFit(dc, wl[i], cx, line, sc, col, 6);
                line += rowH;
                shown += 1;
            }
        }
        var def = null;
        try { def = _m.defShort(0); } catch (e) {}
        if (def != null) { _pxFit(dc, def, cx, line, sc, 0xAAAAAA, 6); }
    }

    // ── RIVALS — challenge a NAMED player off the Arena leaderboard ───────────
    // The same roster the quick FAIR/RISK match draws from, except here the
    // player picks the face: every row carries the rival's own creature, their
    // level, species and the power gap, so a challenge is a decision instead of
    // a dice roll. Nothing on this page touches the network — the roster refills
    // itself once a calendar day through ArenaRoster.
    //
    // The roster index is carried alongside the foe rather than assumed to be
    // the row number: an unparseable entry is dropped from the list, and the
    // challenge has to hit the player the row actually shows.
    hidden function _rivalsEnsure() {
        var n = 0;
        try { n = _m.rivalCount(); } catch (e) {}
        if (_rivals != null && _rivN == n) { return; }
        _rivN = n;
        var out = [];
        for (var i = 0; i < n; i++) {
            var f = null;
            try { f = _m.rivalAt(i); } catch (e) {}
            if (f != null) { out.add([i, f]); }
        }
        _rivals = out;
        if (_rivCur >= out.size()) { _rivCur = out.size() - 1; }
        if (_rivCur < 0) { _rivCur = 0; }
        var max = out.size() - CV_RIVAL_FIT;
        if (max < 0) { max = 0; }
        if (_rivScroll > max) { _rivScroll = max; }
        if (_rivScroll < 0) { _rivScroll = 0; }
    }

    hidden function _drawRivals(dc) {
        var cx = _w / 2;
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        _rivalsEnsure();
        var n = _rivals.size();

        var myPw = 0; var rkc = Cr.TEXT;
        try { myPw = _m.power(); } catch (e) {}
        try { rkc = Cr.rankColor(_m.rank()); } catch (e) {}
        _pxFit(dc, "YOU  LV " + _m.level + "  POWER " + myPw, cx, _h * 21 / 100, sc, rkc, 6);

        // Empty roster: say why, and what still works without one.
        if (n == 0) {
            _pxFit(dc, "NO LIVE RIVALS YET", cx, _h * 34 / 100, sc, 0xFF9A3A, 6);
            _wrapN(dc, cx, _h * 44 / 100, _chordHalf(_h * 56 / 100) * 2 - 14,
                   Graphics.FONT_XTINY, Cr.TEXT,
                   "Board players load once a day with your phone in range.", 3);
            _pxFit(dc, "FAIR / RISK on ARENA works offline", cx, _h * 72 / 100, sc, Cr.MUTED, 6);
            return;
        }

        var rw = _w * 74 / 100; var rx = cx - rw / 2;
        var rh = _h * 17 / 100;
        var gap = _h * 15 / 1000;
        var y0 = _h * 27 / 100;
        for (var g = 0; g < CV_RIVAL_FIT; g++) {
            var row = _rivScroll + g;
            if (row >= n) { break; }
            var r = [rx, y0 + g * (rh + gap), rw, rh];
            if (g == 0) { _rBtnA = r; }
            else if (g == 1) { _rBtnB = r; }
            else { _rBtnC = r; }
            _rivalRow(dc, r, row, sc);
        }
        _pxFit(dc, (_rivCur + 1) + "/" + n + "   SELECT = FIGHT",
               cx, _h * 85 / 100, sc, Cr.MUTED, 6);
    }

    hidden function _rivalRow(dc, r, row, sc) {
        var f = _rivals[row][1];
        var hot = (_rivCur == row);
        dc.setColor(hot ? 0x2A1608 : Cr.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(hot ? 0xFF9A3A : 0x2A3A4A, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(r[0], r[1], r[2], r[3], 6);

        var pad = r[2] / 22; if (pad < 4) { pad = 4; }
        var px = r[3] / 12; if (px < 3) { px = 3; }
        var spriteW = 8 * px;
        // The rival's OWN creature, drawn from the species/stage they published.
        try {
            CreatureArt.drawFoe(dc, f.species, f.evo, r[0] + pad + spriteW / 2,
                                r[1] + r[3] - pad, px, _t, false);
        } catch (e) {}

        // Right column: how the fight is likely to go, then their raw power.
        var band = 0;
        try { band = _m.bandFor(f.power); } catch (e) {}
        var vt = (band > 0) ? "HARD" : ((band < 0) ? "EASY" : "EVEN");
        var vc = (band > 0) ? 0xFF5A5A : ((band < 0) ? Cr.ACCENT : Cr.GOLD);
        var pwStr = "PWR " + f.power;
        var topY = r[1] + r[3] * 22 / 100;
        var botY = r[1] + r[3] * 58 / 100;
        var colX = r[0] + r[2] - pad - Px.gtxtW(pwStr, sc);
        Px.gtxt(dc, vt, r[0] + r[2] - pad - Px.gtxtW(vt, sc), topY, sc, vc);
        Px.gtxt(dc, pwStr, colX, botY, sc, Cr.MUTED);

        // Left column: who they are. The name gets the readable system font —
        // it is the one thing on the row a player is actually choosing between.
        var tx = r[0] + pad * 2 + spriteW;
        var tw = colX - tx - pad;
        if (tw < 8) { return; }
        _txt(dc, tx, r[1] + r[3] * 12 / 100, Graphics.FONT_XTINY,
             hot ? 0xFFD9B0 : Cr.TEXT, _clip(dc, f.name, Graphics.FONT_XTINY, tw),
             Graphics.TEXT_JUSTIFY_LEFT);
        var sub = "LV " + f.level + " " + Cr.speciesElement(f.species);
        while (sub.length() > 3 && Px.gtxtW(sub, sc) > tw) {
            sub = sub.substring(0, sub.length() - 1);
        }
        Px.gtxt(dc, sub, tx, botY, sc, Cr.speciesColor(f.species));
    }

    hidden function _clip(dc, s, font, maxw) {
        if (s == null) { return ""; }
        var str = s;
        while (str.length() > 2 && dc.getTextWidthInPixels(str, font) > maxw) {
            str = str.substring(0, str.length() - 1);
        }
        return str;
    }

    // ── GEAR card — pick a weapon / armour / artifact per slot ────────────────
    // Same overlay convention as the sibling idle games: it owns the screen,
    // UP/DOWN walks every unlocked item without going back to the list, SELECT
    // acts and leaves the card up, BACK closes it. Row 0 is the old auto-equip.
    hidden function _drawGear(dc) {
        var cx = _w / 2;
        dc.setColor(0x060A0F, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        var n = _gearRows();

        Px.gshC(dc, "GEAR", cx, _h * 7 / 100, sc, Cr.TEXT);
        // The live stat line is the only feedback that matters here: every row
        // already flags what it is worn, so a separate loadout summary is noise.
        var stats = "";
        try { stats = "ATK " + _m.atk() + "  DEF " + _m.def() + "  SPD " + _m.spd(); } catch (e) {}
        _pxFit(dc, stats, cx, _h * 13 / 100, sc, Cr.GOLD, 6);

        var rw = _w * 74 / 100; var rx = cx - rw / 2;
        var rh = _h * 10 / 100;
        var gap = _h * 8 / 1000;
        var y0 = _h * 19 / 100;
        for (var g = 0; g < CV_GEAR_FIT; g++) {
            var row = _gearScroll + g;
            if (row >= n) { break; }
            var r = [rx, y0 + g * (rh + gap), rw, rh];
            if (g == 0) { _rBtnA = r; }
            else if (g == 1) { _rBtnB = r; }
            else if (g == 2) { _rBtnC = r; }
            else { _rBtnD = r; }
            _gearRow(dc, r, row, sc);
        }

        var hint = (n > CV_GEAR_FIT) ? "UP/DOWN TO SCROLL" : "SELECT TO EQUIP";
        _pxFit(dc, hint, cx, _h * 66 / 100, sc, Cr.MUTED, 6);
        // Item names vary from "Iron Fang" to "Star Map Ring", so the detail line
        // steps its font down instead of being clipped at a fixed size.
        var detail = "AUTO equips the best you own";
        if (_gearCur > 0 && _gearIds != null && _gearCur - 1 < _gearIds.size()) {
            var id = _gearIds[_gearCur - 1];
            detail = Cr.eqName(id) + "  " + _gearBonus(id)
                   + (_gearWorn(id) ? " - worn" : "");
        }
        var dy = _h * 71 / 100;
        _txtFit(dc, cx, dy, Graphics.FONT_TINY, 0x9FB2C4, detail,
                _chordHalf(dy + _h * 6 / 100) * 2 - 12);

        var cw = _w * 34 / 100;
        _rBtnF = [cx - cw / 2, _h * 83 / 100, cw, _h * 10 / 100];
        _button(dc, _rBtnF, "CLOSE", false);
    }

    hidden function _gearRow(dc, r, row, sc) {
        if (row == 0) {
            _button(dc, r, "AUTO", _gearCur == 0);
            return;
        }
        var id = _gearIds[row - 1];
        var worn = _gearWorn(id);
        var hot = (_gearCur == row);
        dc.setColor(hot ? 0x123016 : Cr.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(worn ? Cr.GOLD : (hot ? Cr.ACCENT : 0x2A3A4A), Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(r[0], r[1], r[2], r[3], 6);

        var pad = r[2] / 20; if (pad < 3) { pad = 3; }
        var gy = r[1] + r[3] / 2 - 5 * sc;
        Px.gtxt(dc, Cr.eqSlotName(Cr.eqSlot(id)), r[0] + pad, gy, sc,
                worn ? Cr.GOLD : Cr.MUTED);
        Px.gtxt(dc, Cr.eqName(id), r[0] + pad, gy + 6 * sc, sc,
                hot ? 0xCFF7DA : 0x9FB2C4);
        var bonus = _gearBonus(id);
        Px.gtxt(dc, bonus, r[0] + r[2] - pad - Px.gtxtW(bonus, sc), gy + 3 * sc, sc, Cr.ACCENT);
    }

    // ── Battle replay: fought from the ARENA page ────────────────────────────
    // fight() hands the whole fight back up front, so the replay is a cursor
    // walking a fixed array — nothing is simulated per frame and the draw path
    // allocates nothing beyond the result strings, which only exist once the
    // replay has finished. Both creatures are the REAL sprites: the player's
    // hero on the left, and on the right whatever the rival actually raised.
    hidden function _drawBattle(dc) {
        var cx = _w / 2;
        dc.setColor(0x05070C, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }
        if (_battleData == null) { return; }
        var sc = _h / 220; if (sc < 2) { sc = 2; }

        var foeName = "Foe"; var won = false; var real = false;
        try { foeName = _battleData["foeName"]; } catch (e) {}
        try { won = _battleData["won"]; } catch (e) {}
        try { real = (_battleData["foeReal"] == true); } catch (e) {}
        var foeLevel   = _battleNum("foeLevel", 1);
        var foeSpecies = _battleNum("foeSpecies", 0);
        var foeEvo     = _battleNum("foeEvo", Cr.EV_HATCH);
        var myMax      = _battleNum("myMax", 1);
        var foeMax     = _battleNum("foeMax", 1);
        if (myMax < 1) { myMax = 1; }
        if (foeMax < 1) { foeMax = 1; }

        var steps = _battleSteps();
        var shown = _battleStep; if (shown > steps.size()) { shown = steps.size(); }
        var done = (shown >= steps.size());

        // Everything the current frame needs comes off the last revealed strike.
        var who = -1; var crit = false;
        var myHp = myMax; var foeHp = foeMax;
        if (shown > 0) {
            var st = steps[shown - 1];
            who = st[0]; myHp = st[2]; foeHp = st[3]; crit = (st[4] == 1);
        }
        var flash = (!done && _battleT < CV_FLASH_TICKS && shown > 0);

        _pxFit(dc, "YOU vs " + foeName, cx, _h * 6 / 100, sc, Cr.TEXT, 6);
        _pxFit(dc, (real ? "RIVAL LV " : "LV ") + foeLevel + "  "
                 + Cr.speciesElement(foeSpecies),
               cx, _h * 11 / 100, sc, real ? Cr.GOLD : Cr.MUTED, 6);

        // Combatants. The striker lunges in and the struck side takes a ring
        // flash — two cheap primitives that read as a hit at any watch size.
        var hpx = _h * 9 / 100 / 8; if (hpx < 4) { hpx = 4; }
        var lunge = _w * 3 / 100;
        var heroX = cx - _w * 24 / 100;
        var foeX  = cx + _w * 24 / 100;
        if (flash && who == 0) { heroX += lunge; }
        if (flash && who == 1) { foeX  -= lunge; }
        var feetY = _h * 30 / 100;
        if (flash) {
            dc.setColor(crit ? 0xFFAA00 : 0xFF5555, Graphics.COLOR_TRANSPARENT);
            var hitX = (who == 0) ? foeX : heroX;
            dc.drawCircle(hitX, feetY - hpx * 4, hpx * 5);
            if (crit) { dc.drawCircle(hitX, feetY - hpx * 4, hpx * 6); }
        }
        try { CreatureArt.drawHero(dc, _m, heroX, feetY, hpx, _t); } catch (e) {}
        try { CreatureArt.drawFoe(dc, foeSpecies, foeEvo, foeX, feetY, hpx, _t, true); } catch (e) {}
        Px.gtxtC(dc, "VS", cx, _h * 24 / 100, sc, 0xFF5555);

        // HP bars, one under each fighter.
        var barW = _w * 30 / 100; var barH = _h * 3 / 100; if (barH < 5) { barH = 5; }
        var barY = _h * 34 / 100;
        _bar(dc, cx - _w * 24 / 100 - barW / 2, barY, barW, barH, myHp * 100 / myMax, Cr.ACCENT);
        _bar(dc, cx + _w * 24 / 100 - barW / 2, barY, barW, barH, foeHp * 100 / foeMax, 0xFF5555);

        // The strike line for the step on screen, plus a crit marker.
        var rn = _battleRounds();
        if (shown > 0 && shown <= rn.size()) {
            _pxFit(dc, rn[shown - 1], cx, _h * 41 / 100, sc, crit ? 0xFFAA00 : Cr.TEXT, 6);
        }

        if (done && steps.size() > 0) {
            var tip = "";
            try { tip = _battleData["tip"]; } catch (e) {}
            var xpGain   = _battleNum("xpGain", 0);
            var evoGain  = _battleNum("evoGain", 0);
            var ptsDelta = _battleNum("ptsDelta", 0);
            var resY = _h * 50 / 100;
            Px.gtxtC(dc, won ? "VICTORY!" : "DEFEAT", cx, resY, sc, won ? Cr.ACCENT : 0xFF5555);
            var pStr = (ptsDelta >= 0 ? "+" : "") + ptsDelta;
            _pxFit(dc, "+" + xpGain + " XP  +" + evoGain + " EVO  " + pStr + " PTS",
                   cx, resY + _h * 6 / 100, sc, Cr.GOLD, 6);
            if (tip != null && tip.length() > 0) {
                // A one-line diagnostic sits better nudged down into the gap; a
                // two-line one has to start high or it runs into the hint.
                var tipW = _chordHalf(resY + _h * 20 / 100) * 2 - 12;
                var tipY = resY + _h * 13 / 100;
                if (_lineCount(dc, tip, tipW, Graphics.FONT_XTINY) < 2) { tipY += _h * 4 / 100; }
                _wrapN(dc, cx, tipY, tipW, Graphics.FONT_XTINY,
                       won ? Cr.MUTED : 0xFFAAAA, tip, 2);
            }
            _pxFit(dc, "TAP TO CLOSE", cx, _h * 88 / 100, sc, Cr.MUTED, 6);
        } else {
            _pxFit(dc, "TAP TO SKIP", cx, _h * 88 / 100, sc, Cr.MUTED, 6);
        }
    }

    // ── DAILY + weekly BOND ─────────────────────────────────────────────────────
    hidden function _drawDaily(dc) {
        var cx = _w / 2;
        var yy = _h * 20 / 100;
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        Px.gtxtC(dc, "DAILY", cx, yy, sc, Cr.MUTED);
        _wrapText(dc, cx, yy + _h * 5 / 100, _w * 78 / 100, Graphics.FONT_XTINY, Cr.TEXT, _m.dailyText());

        var prog = _m.dailyProgress(); var tgt = _m.dailyTarget();
        var bw = _w * 62 / 100; var bx = cx - bw / 2;
        var by = _h * 36 / 100;
        var pct = (tgt > 0) ? prog * 100 / tgt : 100;
        _bar(dc, bx, by, bw, 8, pct, Cr.ACCENT);
        Px.gtxtC(dc, prog + "/" + tgt + "  " + _m.dailyRewardText(), cx, by + _h * 5 / 100, sc, Cr.GOLD);

        // Weekly bond contract.
        Px.gtxtC(dc, "BOND WEEK", cx, by + _h * 12 / 100, sc, 0xB46CFF);
        _wrapText(dc, cx, by + _h * 17 / 100, _w * 78 / 100, Graphics.FONT_XTINY, Cr.TEXT, _m.bondText());
        var bp = _m.bondProg; var bt = _m.bondTarget();
        var bpct = (bt > 0) ? bp * 100 / bt : 100;
        _bar(dc, bx, by + _h * 28 / 100, bw, 8, bpct, 0xB46CFF);
        Px.gtxtC(dc, bp + "/" + bt + "  streak " + _m.streak + "d", cx, by + _h * 33 / 100, sc, Cr.MUTED);

        var bwr = _w * 40 / 100; var bhr = _h * 10 / 100;
        var byr = _h * 78 / 100;
        _rBtnA = [cx - bwr - 4, byr, bwr, bhr];
        _rBtnB = [cx + 4, byr, bwr, bhr];
        var done = _m.dailyClaimed;
        var can = _m.dailyComplete() && !done;
        var bDone = _m.bondClaimed;
        var bCan = _m.bondComplete() && !bDone;
        _button(dc, _rBtnA, done ? "DAILY OK" : "CLAIM", can);
        _button(dc, _rBtnB, bDone ? "BOND OK" : "BOND", bCan);
    }

    // ── INDEX — what you have collected, in three labelled sections ───────────
    // One scrollable list, but every entry says what it is: a titled SPECIES /
    // RELICS / JOURNAL band with its own count, a marker per row for found vs
    // still missing, and the system font instead of the 10-pixel one — the old
    // page was a wall of tiny unlabelled words and read as noise.
    // Row kinds. Numbers rather than tag strings: this list is rebuilt on every
    // frame the page is up, and a string compare per row per frame is not worth
    // the readability on a watch.
    hidden function _colRows() {
        var rows = [];
        var seen = 0; var rel = 0;
        try { seen = _m.seenCount(); } catch (e) {}
        try { rel = _m.relicCount(); } catch (e) {}

        rows.add([0, "SPECIES " + seen + "/" + Cr.SPECIES_N, 0x4CA8FF]);
        for (var si = 0; si < Cr.SPECIES_N; si++) {
            var ok = false;
            try { ok = _m.isSeen(si); } catch (e) {}
            rows.add([ok ? 1 : 2, ok ? Cr.speciesName(si) : "not met yet",
                      ok ? Cr.speciesColor(si) : Cr.MUTED]);
        }

        rows.add([0, "RELICS " + rel + "/" + Cr.RELIC_N, Cr.GOLD]);
        for (var ri = 0; ri < Cr.RELIC_N; ri++) {
            var owned = false;
            try { owned = _m.hasRelic(ri); } catch (e) {}
            rows.add([owned ? 1 : 2, owned ? Cr.relicName(ri) : "undiscovered",
                      owned ? Cr.GOLD : Cr.MUTED]);
        }

        rows.add([0, "JOURNAL", Cr.ACCENT]);
        try {
            var jr = _m.journal();
            for (var ji = 0; ji < jr.size() && ji < 8; ji++) {
                rows.add([3, jr[ji][0] + " - " + jr[ji][1], 0x9FB2C4]);
            }
        } catch (e) {}
        return rows;
    }

    hidden function _drawCollection(dc) {
        var cx = _w / 2;
        var tier = 0;
        try { tier = _m.rarityTier(); } catch (e) {}

        // Identity block: the creature this index belongs to.
        _txtFit(dc, cx, _h * 19 / 100, Graphics.FONT_TINY, Cr.GOLD, _m.givenName(),
                _chordHalf(_h * 26 / 100) * 2 - 12);
        _txtFit(dc, cx, _h * 27 / 100, Graphics.FONT_XTINY, Cr.rarityColor(tier),
                _m.displayName() + " · " + Cr.rarityName(tier),
                _chordHalf(_h * 33 / 100) * 2 - 12);

        var rows = _colRows();
        var max = rows.size() - CV_COL_FIT; if (max < 0) { max = 0; }
        var start = _colScroll;
        if (start > max) { start = max; }
        if (start < 0) { start = 0; }
        _colScroll = start;

        var y0 = _h * 35 / 100;
        var rowH = _h * 98 / 1000;
        // Left edge is measured against the NARROWEST row of the block so no
        // entry runs under the bezel on the lower chord of a round screen.
        var left = cx - _w * 33 / 100;
        var wMax = _w * 66 / 100;
        var just = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        for (var i = 0; i < CV_COL_FIT; i++) {
            var idx = start + i;
            if (idx >= rows.size()) { break; }
            var row = rows[idx];
            var kind = row[0];
            var my = y0 + i * rowH + rowH / 2;
            var tx = left;
            dc.setColor(row[2], Graphics.COLOR_TRANSPARENT);
            if (kind != 0) {
                // Found entries get a filled dot, missing ones a hollow one, and
                // a journal line just an indent — so a glance says how much of
                // the section is still open.
                tx = left + 16;
                if (kind == 1)      { dc.fillCircle(left + 5, my, 4); }
                else if (kind == 2) { dc.drawCircle(left + 5, my, 4); }
            }
            _txt(dc, tx, my, Graphics.FONT_XTINY, row[2],
                 _clip(dc, row[1], Graphics.FONT_XTINY, wMax - (tx - left)), just);
        }

        // Scroll thumb: this list is 20+ rows on a five-row page.
        if (max > 0) {
            var h = rowH * CV_COL_FIT;
            var th = h * CV_COL_FIT / rows.size(); if (th < 8) { th = 8; }
            var sx = cx + _w * 34 / 100;
            dc.setColor(0x22303C, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, y0, 3, h);
            dc.setColor(0x4CA8FF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, y0 + (h - th) * start / max, 3, th);
        }
    }

    hidden function _drawPathPick(dc) {
        var cx = _w / 2;
        dc.setColor(0x060A0F, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }
        var sc = _h / 220; if (sc < 2) { sc = 2; }
        Px.gtxtC(dc, "CHOOSE PATH", cx, _h * 10 / 100, sc, Cr.ACCENT);
        Px.gtxtC(dc, "locks forever this life", cx, _h * 16 / 100, sc, Cr.MUTED);
        var bwb = _w * 70 / 100; var bxb = cx - bwb / 2;
        var bh = _h * 12 / 100; var gap = _h * 2 / 100;
        var y0 = _h * 24 / 100;
        _rBtnA = [bxb, y0, bwb, bh];
        _rBtnB = [bxb, y0 + bh + gap, bwb, bh];
        _rBtnC = [bxb, y0 + (bh + gap) * 2, bwb, bh];
        _rBtnD = [bxb, y0 + (bh + gap) * 3, bwb, bh];
        for (var i = 0; i < 4; i++) {
            var p = Cr.PATH_RUNNER + i;
            var rr = (i == 0) ? _rBtnA : ((i == 1) ? _rBtnB : ((i == 2) ? _rBtnC : _rBtnD));
            var lab = Cr.pathName(p);
            if (i == _pathCursor) { lab = "> " + lab; }
            _button(dc, rr, lab, i == _pathCursor);
        }
        Px.gtxtC(dc, Cr.pathPower(Cr.PATH_RUNNER + _pathCursor),
                 cx, _h * 88 / 100, sc, Cr.GOLD);
    }

    // ── Chrome: buttons / badges ──────────────────────────────────────────────
    hidden function _button(dc, r, label, hot) {
        var fill = hot ? 0x123016 : Cr.PANEL;
        var bord = hot ? Cr.ACCENT : 0x2A3A4A;
        var tcol = hot ? 0xCFF7DA : 0x9FB2C4;
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(bord, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        dc.setColor(tcol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(r[0] + r[2] / 2, r[1] + r[3] / 2, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    hidden function _drawPopup(dc) {
        var cx = _w / 2;
        var pw = _w * 82 / 100; var px = cx - pw / 2;
        var ph = _h * 12 / 100; var py = _h * 64 / 100;
        dc.setColor(0x0A0F16, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, 8);
        dc.setColor(_demo ? 0xFF4C7A : Cr.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(px, py, pw, ph, 8);
        _wrapText(dc, cx, py + ph / 2 - _h * 3 / 100, pw - 12,
                  Graphics.FONT_XTINY, Cr.TEXT, _popup);
    }

    // Inbox arrives ~12 s after open. If WELCOME BACK is still up the raid
    // lines update on the next frame; otherwise surface a short RAID ALERT.
    hidden function _checkRaidMail() {
        if (!_m.mailAlert) { return; }
        _m.mailAlert = false;
        if (_welcome || _battle || _raidMail || _hatchFlash || _pathPick) { return; }
        _raidMail = true;
        try { _tone(2); _vibe(40, 80); } catch (e) {}
    }

    hidden function _drawRaidMail(dc) {
        var cx = _w / 2;
        dc.setColor(0x14060A, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) {
            dc.setColor(0x241014, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }
        _txt(dc, cx, _h * 16 / 100, Graphics.FONT_SMALL, 0xFF6A6A,
             "RAID ALERT", Graphics.TEXT_JUSTIFY_CENTER);
        var raids = null; var who = null;
        try { raids = _m.defSummary(); who = _m.defLine(0); } catch (e) {}
        var y = _h * 32 / 100;
        if (raids != null) {
            var wrapW = _chordHalf(y + _h * 5 / 100) * 2 - 12;
            y = _wrapN(dc, cx, y, wrapW, Graphics.FONT_TINY, 0xFFAA00, raids, 2);
            if (who != null) {
                _wrapN(dc, cx, y, wrapW, Graphics.FONT_XTINY, Cr.TEXT, who, 2);
            }
        }
        _txt(dc, cx, _h * 70 / 100, Graphics.FONT_XTINY, Cr.GOLD,
             "Arena " + _m.arenaPts + " pts", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 80 / 100, Graphics.FONT_XTINY, Cr.MUTED,
             "check ARENA for the log", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Cr.MUTED,
             "tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawWelcome(dc) {
        var cx = _w / 2;
        dc.setColor(0x060A0F, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }
        _txt(dc, cx, _h * 16 / 100, Graphics.FONT_SMALL, Cr.ACCENT,
             "WELCOME BACK", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 27 / 100, Graphics.FONT_XTINY, Cr.MUTED,
             "explored while away", Graphics.TEXT_JUSTIFY_CENTER);

        var y = _h * 36 / 100; var step = _h * 9 / 100;
        _txt(dc, cx, y, Graphics.FONT_TINY, Cr.TEXT, "+" + _m.gXp + " XP", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, y + step, Graphics.FONT_TINY, 0xFF8A3A, "+" + _m.gFood + " food", Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, y + step * 2, Graphics.FONT_TINY, 0xB46CFF, "+" + _m.gMut + " DNA", Graphics.TEXT_JUSTIFY_CENTER);
        var nextY = y + step * 3;
        if (_m.newDay) {
            _txt(dc, cx, nextY, Graphics.FONT_XTINY, Cr.GOLD,
                 "Streak " + _m.streak + "d",
                 Graphics.TEXT_JUSTIFY_CENTER);
            nextY += _h * 7 / 100;
        }
        // Who came looking for a fight while the player was away. The overlay is
        // the only place wide enough for the full "2d ago - HELD vs Name" form.
        var raids = null; var who = null;
        try { raids = _m.defSummary(); who = _m.defLine(0); } catch (e) {}
        if (raids != null) {
            var wrapW = _chordHalf(nextY + _h * 5 / 100) * 2 - 12;
            nextY = _wrapN(dc, cx, nextY, wrapW, Graphics.FONT_XTINY, 0xFFAA00, raids, 2);
            if (who != null) {
                _wrapN(dc, cx, nextY, wrapW, Graphics.FONT_XTINY, 0xAAAAAA, who, 1);
            }
        }
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Cr.MUTED,
             "tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawHatch(dc) {
        var cx = _w / 2;
        dc.setColor(0x060A0F, Graphics.COLOR_TRANSPARENT); dc.clear();
        if (_w == _h) {
            dc.setColor(Cr.CIRCLE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }
        _txt(dc, cx, _h * 14 / 100, Graphics.FONT_SMALL, Cr.GOLD,
             "IT HATCHED!", Graphics.TEXT_JUSTIFY_CENTER);
        CreatureArt.drawCreature(dc, _m, cx, _h * 45 / 100, _h * 15 / 100, _t);
        _txt(dc, cx, _h * 67 / 100, Graphics.FONT_SMALL, Cr.TEXT,
             _m.givenName(), Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 75 / 100, Graphics.FONT_XTINY, Cr.speciesColor(_m.species),
             Cr.speciesName(_m.species) + " · " + Cr.rarityName(_m.rarityTier()),
             Graphics.TEXT_JUSTIFY_CENTER);
        _txt(dc, cx, _h * 90 / 100, Graphics.FONT_XTINY, Cr.MUTED,
             "tap to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Time + text utilities ────────────────────────────────────────────────
    hidden function _fmtHMS(sec) {
        var h = sec / 3600;
        var m = (sec % 3600) / 60;
        var s = sec % 60;
        return _pad(h) + ":" + _pad(m) + ":" + _pad(s);
    }
    hidden function _pad(n) { return (n < 10) ? "0" + n : "" + n; }

    // Very small word-wrap into up to 2 centred lines.
    hidden function _wrapText(dc, cx, y, maxw, font, col, s) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        if (dc.getTextWidthInPixels(s, font) <= maxw) {
            dc.drawText(cx, y, font, s, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        var words = _split(s);
        var l1 = ""; var l2 = ""; var i = 0;
        while (i < words.size()) {
            var cand = (l1.length() == 0) ? words[i] : l1 + " " + words[i];
            if (dc.getTextWidthInPixels(cand, font) <= maxw) { l1 = cand; }
            else { break; }
            i++;
        }
        while (i < words.size()) {
            l2 = (l2.length() == 0) ? words[i] : l2 + " " + words[i];
            i++;
        }
        var fh = dc.getFontHeight(font);
        dc.drawText(cx, y, font, l1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, y + fh * 85 / 100, font, l2, Graphics.TEXT_JUSTIFY_CENTER);
    }
    // How many lines a string needs at this font and width, uncapped.
    hidden function _lineCount(dc, s, maxw, font) {
        if (s == null || s.length() == 0) { return 0; }
        var words = _split(s);
        var i = 0; var n = 0;
        while (i < words.size()) {
            var cur = words[i]; i++;
            while (i < words.size()) {
                var cand = cur + " " + words[i];
                if (dc.getTextWidthInPixels(cand, font) > maxw) { break; }
                cur = cand; i++;
            }
            n++;
        }
        return n;
    }
    // Multi-line centred wrap that ELLIPSIZES rather than running the remainder
    // off both chords of a round screen — which is what the two-line _wrapText
    // does with the longer copy. Returns the y the block ended at, for stacking.
    hidden function _wrapN(dc, cx, y, maxw, font, col, s, maxLines) {
        if (s == null) { return y; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var fh = dc.getFontHeight(font) * 85 / 100;
        var words = _split(s);
        var i = 0; var line = 0;
        while (i < words.size() && line < maxLines) {
            var cur = words[i]; i++;
            while (i < words.size()) {
                var cand = cur + " " + words[i];
                if (dc.getTextWidthInPixels(cand, font) > maxw) { break; }
                cur = cand; i++;
            }
            while (cur.length() > 3 && dc.getTextWidthInPixels(cur, font) > maxw) {
                cur = cur.substring(0, cur.length() - 1);
            }
            if (line == maxLines - 1 && i < words.size()) {
                while (cur.length() > 3 && dc.getTextWidthInPixels(cur + "..", font) > maxw) {
                    cur = cur.substring(0, cur.length() - 1);
                }
                cur += "..";
            }
            dc.drawText(cx, y + line * fh, font, cur, Graphics.TEXT_JUSTIFY_CENTER);
            line++;
        }
        return y + line * fh;
    }
    // Centred title that steps down a font size (and finally truncates) rather
    // than running off the chord of a round screen.
    hidden function _txtFit(dc, cx, y, font, col, s, maxw) {
        var fonts = [font, Graphics.FONT_TINY, Graphics.FONT_XTINY];
        var use = font;
        for (var i = 0; i < fonts.size(); i++) {
            use = fonts[i];
            if (dc.getTextWidthInPixels(s, use) <= maxw) { break; }
        }
        var str = s;
        while (str.length() > 3 && dc.getTextWidthInPixels(str, use) > maxw) {
            str = str.substring(0, str.length() - 1);
        }
        _txt(dc, cx, y, use, col, str, Graphics.TEXT_JUSTIFY_CENTER);
    }
    hidden function _split(s) {
        var out = []; var cur = "";
        for (var i = 0; i < s.length(); i++) {
            var ch = s.substring(i, i + 1);
            if (ch.equals(" ")) { if (cur.length() > 0) { out.add(cur); cur = ""; } }
            else { cur += ch; }
        }
        if (cur.length() > 0) { out.add(cur); }
        return out;
    }
}
