// ═══════════════════════════════════════════════════════════════════════════
// MemoView.mc  —  Memory Match ("Memo") for Garmin watches
//
// GAME LOOP
//   Hidden grid of tile-pairs.  Player flips two tiles; if symbols match
//   they stay open (MATCHED), otherwise they flip back after ~1.5 s.
//   Goal: reveal all pairs in fewest moves and shortest time.
//
// GRID SIZES  (small dense tiles — see battleship 10×10 for the inset model)
//   Easy   4×4 = 16 tiles (8 pairs)
//   Normal 6×4 = 24 tiles (12 pairs)
//   Hard   6×6 = 36 tiles (18 pairs)
//   Grid is laid out inside a centred square region (≈63 % of min(w,h)) so it
//   fits fully inside a round bezel — symmetric top/bottom, no clipping.
//
// SYMBOLS  (18 procedurally drawn shapes, each its own color)
//   0 Heart 1 Diamond 2 Club 3 Star 4 Crescent 5 Sun 6 Bolt 7 Flower
//   8 Fish 9 Crown 10 Triangle 11 Square 12 Circle 13 Ring 14 Plus
//   15 Spade 16 Hexagon 17 Drop
//
// INPUT  (see MemoDelegate)
//   Tap a hidden tile        → flip it immediately
//   Tap an open/matched tile → just move cursor there (no effect)
//   Double-tap               → skip the mismatch wait and re-enable flipping
//   Left-MIDDLE button (UP)  → move cursor VERTICALLY  (row+1, wrap)
//   Left-BOTTOM button (DOWN)→ move cursor HORIZONTALLY (col+1, wrap)
//   Swipe U/D/L/R            → move cursor in that direction (wrap)
//   SELECT                   → flip cursor tile / confirm menu
//   BACK                     → exit to menu
//
// SCORING
//   ★★★  moves ≤ pairs + 1     ★★  moves ≤ pairs ×1.4     ★  all else
// ═══════════════════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.System;
using Toybox.Application;

// ── Game states ─────────────────────────────────────────────────────────────
const MG_MENU   = 0;
const MG_PLAY   = 1;
const MG_RESULT = 2;

// ── Difficulty ───────────────────────────────────────────────────────────────
const MG_EASY   = 0;   // 4×4 = 16
const MG_NORMAL = 1;   // 6×4 = 24
const MG_HARD   = 2;   // 6×6 = 36

// ── Tile display state ───────────────────────────────────────────────────────
const MG_HIDDEN  = 0;
const MG_OPEN    = 1;
const MG_MATCHED = 2;

// ── Menu rows (chess-style) ──────────────────────────────────────────────────
const MG_ROW_DIFF  = 0;
const MG_ROW_START = 1;
const MG_ROW_LB    = 2;
const MG_ROWS      = 3;

const MG_LB_GAME_ID = "memo";

const MG_MAX_TILES = 36;
const MG_NUM_SYMS  = 18;

// ── Symbol accent colors (indices 0..17) ─────────────────────────────────────
const MG_COLORS = [
    0xDD2222,  // 0  Heart    red
    0x22BBDD,  // 1  Diamond  cyan
    0x22CC44,  // 2  Club     green
    0xDDCC00,  // 3  Star     yellow
    0xBB44EE,  // 4  Crescent purple
    0xFF8822,  // 5  Sun      orange
    0xAAFF22,  // 6  Bolt     lime
    0xFF66BB,  // 7  Flower   pink
    0x44AAFF,  // 8  Fish     sky
    0xFFCC44,  // 9  Crown    gold
    0xFF3355,  // 10 Triangle rose
    0x33FFAA,  // 11 Square   mint
    0xAA66FF,  // 12 Circle   violet
    0xEEEEEE,  // 13 Ring     white
    0x00CCBB,  // 14 Plus     teal
    0xFF7733,  // 15 Spade    coral
    0x88AAFF,  // 16 Hexagon  periwinkle
    0xCCEE33   // 17 Drop     chartreuse
];

class MemoView extends WatchUi.View {

    hidden var _w; hidden var _h;
    hidden var _timer; hidden var _tick;

    hidden var _gs;        // MG_MENU / MG_PLAY / MG_RESULT
    hidden var _diff;      // MG_EASY / MG_NORMAL / MG_HARD
    hidden var _menuRow;

    // Grid
    hidden var _cols; hidden var _rows; hidden var _n;
    hidden var _sym; hidden var _state; hidden var _anim;

    // Cursor
    hidden var _cr; hidden var _cc;

    // Match machine
    hidden var _fst; hidden var _snd;
    hidden var _flipBack; hidden var _matchFlash;

    // Stats
    hidden var _moves; hidden var _matched; hidden var _elapsed; hidden var _isNewBest;

    // Persistent best [3]
    hidden var _bstT; hidden var _bstM;

    // Leaderboard
    hidden var _submitted;
    hidden var _diffVariants;

    // Layout cache
    hidden var _tW; hidden var _tH; hidden var _gap; hidden var _gx; hidden var _gy;

    // Double-tap
    hidden var _dtR; hidden var _dtC; hidden var _dtMs;

    // ─────────────────────────────────────────────────────────────────────────
    function initialize() {
        View.initialize();
        _w = 260; _h = 260;
        _tick = 0;
        _gs      = MG_MENU;
        _diff    = MG_NORMAL;
        _menuRow = MG_ROW_START;

        _sym   = new [MG_MAX_TILES];
        _state = new [MG_MAX_TILES];
        _anim  = new [MG_MAX_TILES];
        _cols = 6; _rows = 4; _n = 24;
        for (var i = 0; i < MG_MAX_TILES; i++) {
            _sym[i] = 0; _state[i] = MG_HIDDEN; _anim[i] = 0;
        }

        _cr = 0; _cc = 0;
        _fst = -1; _snd = -1;
        _flipBack = 0; _matchFlash = 0;
        _moves = 0; _matched = 0; _elapsed = 0; _isNewBest = false;

        _bstT = new [3]; _bstM = new [3];
        for (var i = 0; i < 3; i++) { _bstT[i] = 0; _bstM[i] = 0; }

        _dtR = -1; _dtC = -1; _dtMs = 0;
        _tW = 30; _tH = 30; _gap = 3; _gx = 24; _gy = 40;

        _submitted = false;
        _diffVariants = ["Easy", "Normal", "Hard"];

        _loadBest();

        // Difficulty now comes from the shared OPTIONS screen (memo_diff: 0/1/2).
        var dv = Application.Storage.getValue("memo_diff");
        if (dv instanceof Number && dv >= 0 && dv <= 2) { _diff = dv; }
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 100, true);
        // The main menu is the shared root view; drop straight into a game.
        // Only auto-start from a fresh launch (MG_MENU) so returning from the
        // post-game leaderboard card doesn't restart the game.
        if (_gs == MG_MENU) { _startGame(); }
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onLayout(dc) {
        _w = dc.getWidth(); _h = dc.getHeight();
    }

    // ── Persistence ──────────────────────────────────────────────────────────
    hidden function _loadBest() {
        for (var i = 0; i < 3; i++) {
            var v;
            v = Application.Storage.getValue("mgT" + i.toString());
            _bstT[i] = (v instanceof Number) ? v : 0;
            v = Application.Storage.getValue("mgM" + i.toString());
            _bstM[i] = (v instanceof Number) ? v : 0;
        }
    }

    hidden function _saveBest() {
        for (var i = 0; i < 3; i++) {
            Application.Storage.setValue("mgT" + i.toString(), _bstT[i]);
            Application.Storage.setValue("mgM" + i.toString(), _bstM[i]);
        }
    }

    // ── Layout ───────────────────────────────────────────────────────────────
    // Grid lives in a centred square region so it is symmetric about the screen
    // centre → fits fully inside a round display.  Region ≈63 % of min(w,h),
    // which is ~7 % tighter than the earlier full-bleed layout that overflowed.
    hidden function _layout() {
        var minDim = (_w < _h) ? _w : _h;
        var region = minDim * 63 / 100;
        _gap = (minDim >= 200) ? 3 : 2;

        var cw = (region - (_cols - 1) * _gap) / _cols;
        var ch = (region - (_rows - 1) * _gap) / _rows;
        _tW = (cw < ch) ? cw : ch;
        if (_tW < 6) { _tW = 6; }
        _tH = _tW;

        var totW = _cols * _tW + (_cols - 1) * _gap;
        var totH = _rows * _tH + (_rows - 1) * _gap;
        _gx = (_w - totW) / 2;
        _gy = (_h - totH) / 2;
        // Nudge down a hair so the top HUD never clips the first row.
        var minTop = _h * 13 / 100;
        if (_gy < minTop) { _gy = minTop; }
    }

    // ── Timer tick ───────────────────────────────────────────────────────────
    function onTick() as Void {
        _tick++;
        if (_gs == MG_PLAY) {
            _elapsed++;
            if (_matchFlash > 0) { _matchFlash--; }
            if (_flipBack > 0) {
                _flipBack--;
                if (_flipBack == 0 && _snd >= 0) {
                    _state[_fst] = MG_HIDDEN; _anim[_fst] = 5;
                    _state[_snd] = MG_HIDDEN; _anim[_snd] = 5;
                    _fst = -1; _snd = -1;
                }
            }
            for (var i = 0; i < _n; i++) {
                if (_anim[i] > 0) { _anim[i]--; }
            }
        }
        WatchUi.requestUpdate();
    }

    // ── Grid setup ───────────────────────────────────────────────────────────
    hidden function _startGame() {
        if (_diff == MG_EASY)      { _cols = 4; _rows = 4; }
        else if (_diff == MG_NORMAL) { _cols = 6; _rows = 4; }
        else                       { _cols = 6; _rows = 6; }
        _n = _cols * _rows;
        var pairs = _n / 2;

        var pool = new [_n];
        for (var i = 0; i < pairs; i++) {
            var s = i % MG_NUM_SYMS;
            pool[i * 2]     = s;
            pool[i * 2 + 1] = s;
        }
        for (var i = _n - 1; i > 0; i--) {
            var j = Math.rand() % (i + 1);
            if (j < 0) { j += i + 1; }
            var t = pool[i]; pool[i] = pool[j]; pool[j] = t;
        }
        for (var i = 0; i < _n; i++) {
            _sym[i] = pool[i]; _state[i] = MG_HIDDEN; _anim[i] = 0;
        }

        _cr = 0; _cc = 0;
        _fst = -1; _snd = -1;
        _flipBack = 0; _matchFlash = 0;
        _moves = 0; _matched = 0; _elapsed = 0; _isNewBest = false;
        _submitted = false;
        _dtR = -1; _dtC = -1; _dtMs = 0;
        _layout();
        _gs = MG_PLAY;
    }

    // ── Game logic ───────────────────────────────────────────────────────────
    hidden function _canFlip() {
        if (_flipBack > 0)          { return false; }
        if (_fst >= 0 && _snd >= 0) { return false; }
        return true;
    }

    hidden function _flip(idx) {
        if (!_canFlip())              { return; }
        if (idx < 0 || idx >= _n)     { return; }
        if (_state[idx] != MG_HIDDEN) { return; }

        _state[idx] = MG_OPEN; _anim[idx] = 5;

        if (_fst < 0) {
            _fst = idx;
        } else {
            _snd = idx; _moves++;
            if (_sym[_fst] == _sym[_snd]) {
                _state[_fst] = MG_MATCHED; _state[_snd] = MG_MATCHED;
                _matchFlash = 12; _matched++;
                _fst = -1; _snd = -1;
                if (_matched == _n / 2) { _endGame(); }
            } else {
                _flipBack = 15;
            }
        }
    }

    hidden function _endGame() {
        var t = _elapsed; var m = _moves;
        _isNewBest = false;
        if (_bstT[_diff] == 0 || t < _bstT[_diff]) { _bstT[_diff] = t; _isNewBest = true; }
        if (_bstM[_diff] == 0 || m < _bstM[_diff]) { _bstM[_diff] = m; _isNewBest = true; }
        _saveBest();
        // Submit moves to the global leaderboard (lower = better, per difficulty).
        if (!_submitted) {
            _submitted = true;
            var variant = _diffVariants[_diff];
            Leaderboard.submitScore(MG_LB_GAME_ID, m, variant);
            Leaderboard.showPostGame(MG_LB_GAME_ID, variant, variant + " MEMO");
        }
        _gs = MG_RESULT;
    }

    hidden function _stars() {
        var p = _n / 2;
        if (_moves <= p + 1)          { return 3; }
        if (_moves <= p + p * 4 / 10) { return 2; }
        return 1;
    }

    // ── Input — buttons ──────────────────────────────────────────────────────
    // Left-MIDDLE button (onPreviousPage): vertical move (row+1, wrap)
    function btnVert() {
        if (_gs == MG_MENU) { _menuRow = (_menuRow + MG_ROWS - 1) % MG_ROWS; return; }
        if (_gs != MG_PLAY) { return; }
        _cr = (_cr + 1) % _rows;
    }

    // Left-BOTTOM button (onNextPage): horizontal move (col+1, wrap)
    function btnHoriz() {
        if (_gs == MG_MENU) { _menuRow = (_menuRow + 1) % MG_ROWS; return; }
        if (_gs != MG_PLAY) { return; }
        _cc = (_cc + 1) % _cols;
    }

    // ── Input — swipes (full directional, wrap) ───────────────────────────────
    function swipe(dir) {
        if (_gs != MG_PLAY) { return; }
        if      (dir == WatchUi.SWIPE_UP)    { _cr = (_cr + _rows - 1) % _rows; }
        else if (dir == WatchUi.SWIPE_DOWN)  { _cr = (_cr + 1) % _rows; }
        else if (dir == WatchUi.SWIPE_LEFT)  { _cc = (_cc + _cols - 1) % _cols; }
        else if (dir == WatchUi.SWIPE_RIGHT) { _cc = (_cc + 1) % _cols; }
    }

    function doSelect() {
        if (_gs == MG_MENU) {
            if (_menuRow == MG_ROW_DIFF)  { _diff = (_diff + 1) % 3; return; }
            if (_menuRow == MG_ROW_START) { _startGame(); return; }
            if (_menuRow == MG_ROW_LB)    { _openLeaderboard(); return; }
            return;
        }
        if (_gs == MG_RESULT) { _gs = MG_MENU; return; }
        if (_gs == MG_PLAY)   { _flip(_cr * _cols + _cc); return; }
    }

    // BACK returns to the shared menu (framework pops this pushed view).
    function doBack() {
        return false;
    }

    // ── Input — touch ──────────────────────────────────────────────────────────
    function doTap(tx, ty) {
        if (_gs == MG_MENU)   { _menuTap(tx, ty); return; }
        if (_gs == MG_RESULT) { _gs = MG_MENU;    return; }
        if (_gs != MG_PLAY)   { return; }

        var tr = -1; var tc = -1;
        for (var r = 0; r < _rows && tr < 0; r++) {
            for (var c = 0; c < _cols && tr < 0; c++) {
                var x0 = _gx + c * (_tW + _gap);
                var y0 = _gy + r * (_tH + _gap);
                if (tx >= x0 && tx < x0 + _tW && ty >= y0 && ty < y0 + _tH) {
                    tr = r; tc = c;
                }
            }
        }
        if (tr < 0) { return; }

        var now = System.getTimer();
        var dbl = (tr == _dtR && tc == _dtC &&
                   (now - _dtMs) > 0 && (now - _dtMs) < 500);
        _dtR = tr; _dtC = tc; _dtMs = now;

        // Double-tap during a mismatch wait → clear the wait so the player can
        // keep going without the 1.5 s pause.
        if (dbl && _flipBack > 0) {
            _state[_fst] = MG_HIDDEN; _anim[_fst] = 5;
            _state[_snd] = MG_HIDDEN; _anim[_snd] = 5;
            _fst = -1; _snd = -1; _flipBack = 0;
        }

        _cr = tr; _cc = tc;
        var idx = tr * _cols + tc;
        if (_state[idx] == MG_HIDDEN) { _flip(idx); }
    }

    hidden function _menuTap(tx, ty) {
        var g = _menuGeo();
        for (var i = 0; i < MG_ROWS; i++) {
            var ry = g[1] + i * (g[3] + g[4]);
            if (tx >= g[0] && tx < g[0] + g[2] && ty >= ry && ty < ry + g[3]) {
                _menuRow = i;
                if (i == MG_ROW_DIFF)  { _diff = (_diff + 1) % 3; }
                else if (i == MG_ROW_START) { _startGame(); }
                else if (i == MG_ROW_LB)   { _openLeaderboard(); }
                return;
            }
        }
    }

    hidden function _openLeaderboard() {
        var v = new LbScoresView(MG_LB_GAME_ID, _diffVariants[_diff], _diffVariants[_diff] + " MEMO");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // [rowX, rowY0, rowW, rowH, gap]  — space-aware to fit 3 rows
    hidden function _menuGeo() {
        var rowH = _h * 11 / 100; if (rowH < 22) { rowH = 22; } if (rowH > 30) { rowH = 30; }
        var rowW = _w * 78 / 100; if (rowW < 120) { rowW = 120; }
        var rowX = (_w - rowW) / 2;
        var gap  = _h * 2 / 100;  if (gap < 4) { gap = 4; }
        var rowY0 = _h * 46 / 100;
        return [rowX, rowY0, rowW, rowH, gap];
    }

    // ── Rendering ────────────────────────────────────────────────────────────
    function onUpdate(dc) {
        if (_w != dc.getWidth()) { _w = dc.getWidth(); _h = dc.getHeight(); }
        dc.setColor(0x080818, 0x080818); dc.clear();
        // Never render an in-game menu — the shared menu is the root view.
        if (_gs == MG_MENU)   { _startGame(); }
        if (_gs == MG_PLAY)   { _drPlay(dc);   return; }
        if (_gs == MG_RESULT) { _drResult(dc); return; }
    }

    // ── Menu (chess style) ────────────────────────────────────────────────────
    hidden function _drMenu(dc) {
        var cx = _w / 2;

        // Round-screen backing disc
        if (_w == _h) {
            dc.setColor(0x0E1020, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _h / 2, _w / 2 - 1);
        }

        // Title
        dc.setColor(0x44DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 9 / 100, Graphics.FONT_MEDIUM,
            "MEMO", Graphics.TEXT_JUSTIFY_CENTER);

        // by Bitochi
        dc.setColor(0x66788A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 25 / 100, Graphics.FONT_XTINY,
            "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Symbol-color preview dots
        var dotY  = _h * 37 / 100;
        var dotSp = _w * 9 / 100;
        for (var i = 0; i < 5; i++) {
            dc.setColor(MG_COLORS[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 2 * dotSp + i * dotSp, dotY, 4);
        }

        // Rows (chess-style rounded buttons)
        var diffLabels = ["Easy  4x4", "Norm  6x4", "Hard  6x6"];
        var rowLabels  = ["Diff: " + diffLabels[_diff], "START"];
        var g = _menuGeo();
        var rowX = g[0]; var rowY0 = g[1]; var rowW = g[2]; var rowH = g[3]; var gap = g[4];

        for (var i = 0; i < MG_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _menuRow);
            var isStart = (i == MG_ROW_START);

            if (i == MG_ROW_LB) {
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            dc.setColor(sel ? (isStart ? 0x0A3A1A : 0x143055) : 0x111820,
                Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x44CC66 : 0x44AADD) : 0x2A3A4A,
                Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);

            if (sel) {
                dc.setColor(isStart ? 0x44CC66 : 0x44AADD, Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4], [rowX + 5, ay + 4], [rowX + 11, ay]]);
            }

            dc.setColor(sel ? (isStart ? 0xAAFF99 : 0xCCEEFF) : 0x778899,
                Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 16) / 2, Graphics.FONT_XTINY,
                rowLabels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Best line
        if (_bstT[_diff] > 0) {
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 90 / 100, Graphics.FONT_XTINY,
                "Best " + (_bstT[_diff] / 10) + "s / " + _bstM[_diff] + "mv",
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Footer hint
        dc.setColor(0x33424E, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h - 14, Graphics.FONT_XTINY,
            "UP/DN move  SELECT act", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Play ─────────────────────────────────────────────────────────────────
    hidden function _drPlay(dc) {
        var cx    = _w / 2;
        var pairs = _n / 2;
        var secs  = _elapsed / 10;

        // HUD bar (top)
        dc.setColor(0x335566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 8 / 100, _h * 3 / 100, Graphics.FONT_XTINY,
            secs + "s", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor((_matched == pairs) ? 0x44FF88 : 0x44AA66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 3 / 100, Graphics.FONT_XTINY,
            _matched + "/" + pairs, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x886622, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w * 92 / 100, _h * 3 / 100, Graphics.FONT_XTINY,
            _moves + "m", Graphics.TEXT_JUSTIFY_RIGHT);

        for (var r = 0; r < _rows; r++) {
            for (var c = 0; c < _cols; c++) {
                var idx = r * _cols + c;
                var tx  = _gx + c * (_tW + _gap);
                var ty  = _gy + r * (_tH + _gap);
                _drTile(dc, tx, ty, idx, (r == _cr && c == _cc));
            }
        }
    }

    hidden function _drTile(dc, tx, ty, idx, isCursor) {
        var st = _state[idx];
        var an = _anim[idx];

        // Horizontal-squeeze flip animation (an: 5→0)
        var dw = _tW; var dx = tx;
        if (an > 0) {
            var pct;
            if      (an >= 4) { pct = 100; }
            else if (an == 3) { pct =  55; }
            else if (an == 2) { pct =  18; }
            else              { pct =  55 + (3 - an) * 22; }  // 1→77, 0→100
            dw = _tW * pct / 100;
            if (dw < 2) { dw = 2; }
            dx = tx + (_tW - dw) / 2;
        }

        var rad = (_tW >= 16) ? 3 : 2;

        if (st == MG_HIDDEN) {
            dc.setColor(0x1A2255, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(dx, ty, dw, _tH, rad);
            dc.setColor(0x2A3A77, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(dx, ty, dw, _tH, rad);
            if (dw > _tW / 2 && _tW >= 14) {
                var mx = dx + dw / 2; var my = ty + _tH / 2;
                var ds = _tW / 6; if (ds < 2) { ds = 2; }
                dc.setColor(0x3A4A99, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[mx, my - ds], [mx + ds, my],
                                [mx, my + ds], [mx - ds, my]]);
            }
        } else {
            var isMatch = (st == MG_MATCHED);
            var flash   = isMatch && _matchFlash > 0 && (_tick % 4 < 2);
            dc.setColor(flash ? 0x0A4A20 : (isMatch ? 0x0A2218 : 0x0C1020),
                Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(dx, ty, dw, _tH, rad);
            dc.setColor(isMatch ? 0x22AA44 : 0x1A2A44, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(dx, ty, dw, _tH, rad);

            if (dw > _tW * 5 / 10) {
                var ss = _tW * 36 / 100; if (ss < 4) { ss = 4; }
                dc.setColor(MG_COLORS[_sym[idx]], Graphics.COLOR_TRANSPARENT);
                _drSym(dc, dx + dw / 2, ty + _tH / 2, _sym[idx], ss);
            }
        }

        if (isCursor) {
            var cc = (_tick % 6 < 3) ? 0x44DDFF : 0x2299BB;
            dc.setColor(cc, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRoundedRectangle(tx - 2, ty - 2, _tW + 4, _tH + 4, rad + 1);
            dc.setPenWidth(1);
        }
    }

    // ── Result screen ─────────────────────────────────────────────────────────
    hidden function _drResult(dc) {
        var cx = _w / 2;
        var gc = (_tick % 16 < 8) ? 0x44FF88 : 0x22CC66;

        dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 12 / 100, Graphics.FONT_LARGE,
            "MATCHED!", Graphics.TEXT_JUSTIFY_CENTER);

        var s  = _stars();
        var sp = _w * 14 / 100;
        for (var i = 0; i < 3; i++) {
            dc.setColor((i < s) ? 0xFFCC00 : 0x333322, Graphics.COLOR_TRANSPARENT);
            _drSym(dc, cx - sp + i * sp, _h * 33 / 100, 3, (i < s) ? 13 : 9);
        }

        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 47 / 100, Graphics.FONT_SMALL,
            "Time: " + (_elapsed / 10) + "." + (_elapsed % 10) + "s",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, _h * 58 / 100, Graphics.FONT_SMALL,
            "Moves: " + _moves, Graphics.TEXT_JUSTIFY_CENTER);

        if (_isNewBest) {
            dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _h * 70 / 100, Graphics.FONT_XTINY,
                "* NEW BEST *", Graphics.TEXT_JUSTIFY_CENTER);
        }

        var pc = (_tick % 20 < 10) ? 0x447766 : 0x225544;
        dc.setColor(pc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 84 / 100, Graphics.FONT_XTINY,
            "Tap to play again", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Symbol drawing ────────────────────────────────────────────────────────
    // cx,cy = centre;  s = half-size.  Color is set before calling.
    hidden function _drSym(dc, cx, cy, sym, s) {
        if (s < 3) { s = 3; }
        var r  = s * 5 / 10; if (r < 2) { r = 2; }
        var h6 = s * 6 / 10;
        var h3 = s * 3 / 10; if (h3 < 1) { h3 = 1; }
        var h2 = s * 2 / 10; if (h2 < 1) { h2 = 1; }

        if (sym == 0) {
            // Heart
            dc.fillCircle(cx - r + 1, cy - s / 4, r);
            dc.fillCircle(cx + r - 1, cy - s / 4, r);
            dc.fillPolygon([[cx - s, cy - s / 6], [cx, cy + s * 8 / 10], [cx + s, cy - s / 6]]);

        } else if (sym == 1) {
            // Diamond
            dc.fillPolygon([[cx, cy - s], [cx + h6, cy], [cx, cy + s], [cx - h6, cy]]);

        } else if (sym == 2) {
            // Club
            dc.fillCircle(cx, cy - r, r);
            dc.fillCircle(cx - r, cy + r / 2, r);
            dc.fillCircle(cx + r, cy + r / 2, r);
            var stH = s / 2; if (stH < 2) { stH = 2; }
            dc.fillRectangle(cx - 2, cy + r / 2 + r - 1, 4, stH);

        } else if (sym == 3) {
            // Star (8-point)
            dc.fillPolygon([[cx, cy - s], [cx + h3, cy - h3], [cx + s, cy],
                             [cx + h3, cy + h3], [cx, cy + s], [cx - h3, cy + h3],
                             [cx - s, cy], [cx - h3, cy - h3]]);

        } else if (sym == 4) {
            // Crescent
            dc.fillPolygon([[cx + h2, cy - s], [cx + h6, cy - h6], [cx + s, cy],
                             [cx + h6, cy + h6], [cx + h2, cy + s], [cx - h3, cy + h6],
                             [cx - h2, cy], [cx - h3, cy - h6]]);

        } else if (sym == 5) {
            // Sun
            dc.fillCircle(cx, cy, r);
            var rLen = s - r - 1; if (rLen < 2) { rLen = 2; }
            dc.fillPolygon([[cx - 2, cy - r], [cx, cy - r - rLen], [cx + 2, cy - r]]);
            dc.fillPolygon([[cx - 2, cy + r], [cx, cy + r + rLen], [cx + 2, cy + r]]);
            dc.fillPolygon([[cx + r, cy - 2], [cx + r + rLen, cy], [cx + r, cy + 2]]);
            dc.fillPolygon([[cx - r, cy - 2], [cx - r - rLen, cy], [cx - r, cy + 2]]);

        } else if (sym == 6) {
            // Bolt
            var w3 = s * 3 / 10;
            dc.fillPolygon([[cx + w3, cy - s], [cx + s * 5 / 10, cy - s / 10],
                             [cx + s / 10, cy - s / 10], [cx - w3, cy + s],
                             [cx - s * 5 / 10, cy + s / 10], [cx - s / 10, cy + s / 10]]);

        } else if (sym == 7) {
            // Flower
            dc.fillCircle(cx, cy, r);
            var pd = s * 6 / 10;
            dc.fillCircle(cx, cy - pd, r);
            dc.fillCircle(cx + pd, cy, r);
            dc.fillCircle(cx, cy + pd, r);
            dc.fillCircle(cx - pd, cy, r);

        } else if (sym == 8) {
            // Fish
            dc.fillPolygon([[cx - s * 6 / 10, cy], [cx - s * 2 / 10, cy - s * 4 / 10],
                             [cx + s * 5 / 10, cy - s * 2 / 10], [cx + s * 5 / 10, cy + s * 2 / 10],
                             [cx - s * 2 / 10, cy + s * 4 / 10]]);
            dc.fillPolygon([[cx + s * 5 / 10, cy - s * 4 / 10], [cx + s, cy],
                             [cx + s * 5 / 10, cy + s * 4 / 10]]);

        } else if (sym == 9) {
            // Crown
            dc.fillPolygon([[cx - s, cy + s * 3 / 10], [cx - s, cy - s / 10],
                             [cx - s * 5 / 10, cy - s * 7 / 10], [cx - s * 2 / 10, cy - s * 2 / 10],
                             [cx, cy - s], [cx + s * 2 / 10, cy - s * 2 / 10],
                             [cx + s * 5 / 10, cy - s * 7 / 10], [cx + s, cy - s / 10],
                             [cx + s, cy + s * 3 / 10]]);

        } else if (sym == 10) {
            // Triangle (up)
            dc.fillPolygon([[cx, cy - s], [cx + s, cy + s * 7 / 10], [cx - s, cy + s * 7 / 10]]);

        } else if (sym == 11) {
            // Square
            var sq = s * 14 / 10;
            dc.fillRectangle(cx - s * 7 / 10, cy - s * 7 / 10, sq, sq);

        } else if (sym == 12) {
            // Circle (filled)
            dc.fillCircle(cx, cy, s * 8 / 10);

        } else if (sym == 13) {
            // Ring (thick outline)
            var pw = s * 3 / 10; if (pw < 2) { pw = 2; }
            dc.setPenWidth(pw);
            dc.drawCircle(cx, cy, s * 7 / 10);
            dc.setPenWidth(1);

        } else if (sym == 14) {
            // Plus / cross
            var t2 = s * 3 / 10; if (t2 < 2) { t2 = 2; }
            dc.fillRectangle(cx - t2, cy - s, t2 * 2, s * 2);
            dc.fillRectangle(cx - s, cy - t2, s * 2, t2 * 2);

        } else if (sym == 15) {
            // Spade
            dc.fillPolygon([[cx, cy - s], [cx - s, cy + s / 4], [cx + s, cy + s / 4]]);
            dc.fillCircle(cx - r + 1, cy + s / 6, r);
            dc.fillCircle(cx + r - 1, cy + s / 6, r);
            dc.fillRectangle(cx - 2, cy + s / 3, 4, s * 4 / 10);

        } else if (sym == 16) {
            // Hexagon (flat-top)
            dc.fillPolygon([[cx - s * 5 / 10, cy - h6], [cx + s * 5 / 10, cy - h6],
                             [cx + s, cy], [cx + s * 5 / 10, cy + h6],
                             [cx - s * 5 / 10, cy + h6], [cx - s, cy]]);

        } else {
            // 17 Drop / teardrop
            dc.fillCircle(cx, cy + s * 3 / 10, s * 6 / 10);
            dc.fillPolygon([[cx, cy - s], [cx - s * 6 / 10, cy + s * 3 / 10],
                             [cx + s * 6 / 10, cy + s * 3 / 10]]);
        }
    }
}
