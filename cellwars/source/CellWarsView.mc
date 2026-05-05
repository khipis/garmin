using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.System;

// ── Integer constants (safe at module level) ───────────────────────────────────
const GS_RUN  = 0;
const GS_PAU  = 1;
const GS_MENU = 2;
const GS_INFO = 3;

const MD_BATTLE = 0;
const MD_RUMBLE = 1;
const MD_CONWAY = 2;
const MD_HLIFE  = 3;
const MD_DNITE  = 4;
const MD_MAZE   = 5;
const MD_SEEDS  = 6;
const MD_COUNT  = 7;

const TH_COUNT = 4;
const MENU_N   = 7;

// Grid: 28 × 28 = 784 cells.
// We process N rows per timer tick to stay within the 200ms watchdog budget.
const GW = 28;
const GH = 28;
const GN = 784; // GW * GH

class CellWarsView extends WatchUi.View {

    // ── state ─────────────────────────────────────────────────────────────────
    hidden var _gs;
    hidden var _mode;
    hidden var _speed;
    hidden var _density;
    hidden var _theme;
    hidden var _nTeams;

    // ── grid ──────────────────────────────────────────────────────────────────
    // _grid always holds the LAST COMPLETE generation (used for drawing).
    // _buf accumulates the NEXT generation row by row.
    hidden var _grid;
    hidden var _buf;
    hidden var _cnt;       // scratch neighbour counts  Array[8]

    hidden var _gen;
    hidden var _stale;
    hidden var _prevAlive;

    // ── batch-step state ──────────────────────────────────────────────────────
    // Processing happens N rows per tick. _procRow tracks where we are within
    // the current (incomplete) next generation.
    hidden var _procRow;       // 0..GH, next row to compute into _buf
    hidden var _tCntBuf;       // Array[4] team counts accumulating for _buf

    // ── timer ─────────────────────────────────────────────────────────────────
    hidden var _timer;

    // ── layout ────────────────────────────────────────────────────────────────
    hidden var _w;
    hidden var _h;
    hidden var _csz;
    hidden var _gox;
    hidden var _goy;
    hidden var _menuRowH;

    // ── menu ──────────────────────────────────────────────────────────────────
    hidden var _mSel;

    // ── team data (for the CURRENT complete generation) ───────────────────────
    hidden var _tAlgo;   // Array[4] which algorithm each team uses
    hidden var _tCnt;    // Array[4] alive cell count — synced after each generation

    hidden var _winFlash;

    // ── lookup tables ─────────────────────────────────────────────────────────
    hidden var _algoB;
    hidden var _algoS;
    hidden var _algoTag;
    hidden var _thBg;
    hidden var _thName;
    hidden var _thCols;   // flattened [theme*8 + teamIdx]
    hidden var _mnames;
    hidden var _fillLbl;
    // rows-per-tick per speed level  [speed-1]
    hidden var _bRows;

    function initialize() {
        View.initialize();

        _gs       = GS_MENU;
        _mode     = MD_BATTLE;
        _speed    = 3;
        _density  = 1;
        _theme    = 0;
        _nTeams   = 3;
        _gen      = 0;
        _stale    = 0;
        _prevAlive = -1;
        _mSel     = 0;
        _winFlash = 0;
        _procRow  = 0;
        _timer    = null;
        _menuRowH = 20;

        _grid    = new [GN];
        _buf     = new [GN];
        _cnt     = new [8];
        _tAlgo   = new [4];
        _tCnt    = new [4];
        _tCntBuf = new [4];

        for (var i = 0; i < GN; i++) { _grid[i] = 0; _buf[i] = 0; }
        for (var i = 0; i < 8;  i++) { _cnt[i]  = 0; }
        _tAlgo[0] = 0; _tAlgo[1] = 1; _tAlgo[2] = 4; _tAlgo[3] = 3;
        for (var t = 0; t < 4; t++) { _tCnt[t] = 0; _tCntBuf[t] = 0; }

        // Rows per tick per speed — max 14 rows keeps each tick ≤150 ms
        // even on the slowest simulator. More rows = faster evolution.
        _bRows = new [5];
        _bRows[0] = 2;  // speed 1 — ~14 ticks/gen  ~1 gen/sec
        _bRows[1] = 4;  // speed 2 — ~7  ticks/gen  ~2 gens/sec
        _bRows[2] = 7;  // speed 3 — ~4  ticks/gen  ~3 gens/sec
        _bRows[3] = 10; // speed 4 — ~3  ticks/gen  ~4 gens/sec
        _bRows[4] = 14; // speed 5 — ~2  ticks/gen  ~6 gens/sec

        // ── algorithm bitmasks ───────────────────────────────────────────────
        _algoB = new [8];
        _algoB[0]=8;   _algoB[1]=72;  _algoB[2]=456; _algoB[3]=8;
        _algoB[4]=4;   _algoB[5]=8;   _algoB[6]=170; _algoB[7]=168;

        _algoS = new [8];
        _algoS[0]=12;  _algoS[1]=12;  _algoS[2]=472; _algoS[3]=62;
        _algoS[4]=0;   _algoS[5]=496; _algoS[6]=170; _algoS[7]=298;

        _algoTag = new [8];
        _algoTag[0]="CONWAY"; _algoTag[1]="HLIFE"; _algoTag[2]="D+N";
        _algoTag[3]="MAZE";   _algoTag[4]="SEEDS"; _algoTag[5]="CORAL";
        _algoTag[6]="REPLI";  _algoTag[7]="AMOEBA";

        // ── theme data ───────────────────────────────────────────────────────
        _thBg = new [4];
        _thBg[0]=0x000000; _thBg[1]=0x00080f; _thBg[2]=0x080100; _thBg[3]=0x010800;

        _thName = new [4];
        _thName[0]="NEON"; _thName[1]="OCEAN"; _thName[2]="FIRE"; _thName[3]="FOREST";

        _thCols = new [32];
        _thCols[ 0]=0x00EEFF; _thCols[ 1]=0xFF6600; _thCols[ 2]=0xCC22FF; _thCols[ 3]=0x00FF88;
        _thCols[ 4]=0xFF2288; _thCols[ 5]=0xFFDD00; _thCols[ 6]=0xFF4444; _thCols[ 7]=0x44AAFF;
        _thCols[ 8]=0x0088FF; _thCols[ 9]=0x00DDFF; _thCols[10]=0x44BBFF; _thCols[11]=0x0066CC;
        _thCols[12]=0x88CCFF; _thCols[13]=0x00FFCC; _thCols[14]=0x4488FF; _thCols[15]=0x22CCEE;
        _thCols[16]=0xFF4400; _thCols[17]=0xFF8800; _thCols[18]=0xFFCC00; _thCols[19]=0xFF1100;
        _thCols[20]=0xFFAA44; _thCols[21]=0xFF6622; _thCols[22]=0xFFEE88; _thCols[23]=0xFFDD44;
        _thCols[24]=0x00CC44; _thCols[25]=0x88FF00; _thCols[26]=0x44FF88; _thCols[27]=0xAACC00;
        _thCols[28]=0x66FF44; _thCols[29]=0x00FFAA; _thCols[30]=0x228844; _thCols[31]=0xCCFF44;

        _mnames = new [7];
        _mnames[0]="BATTLE"; _mnames[1]="RUMBLE"; _mnames[2]="CONWAY";
        _mnames[3]="HIGHLIFE"; _mnames[4]="DAY+N"; _mnames[5]="MAZE";
        _mnames[6]="SEEDS";

        _fillLbl = new [3];
        _fillLbl[0]="LOW"; _fillLbl[1]="MED"; _fillLbl[2]="HIGH";
    }

    // ── lifecycle ──────────────────────────────────────────────────────────────

    function onLayout(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();

        var gridPx = _h * 86 / 100;
        _csz = gridPx / GH;
        if (_csz < 3) { _csz = 3; }
        _gox = (_w - _csz * GW) / 2;
        _goy = (_h - _csz * GH) / 2;
        _menuRowH = dc.getFontHeight(Graphics.FONT_XTINY) + 4;
        _randomize();
    }

    function onShow() { _startTimer(); }
    function onHide() { if (_timer != null) { _timer.stop(); } }

    // ── timer ──────────────────────────────────────────────────────────────────

    hidden function _startTimer() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.stop();
        // Fixed 80ms period; generation speed is controlled by rows-per-tick
        _timer.start(method(:cwTick), 80, true);
    }

    // Public so method(:cwTick) resolves reliably
    function cwTick() {
        if (_gs == GS_RUN) {
            _doStepBatch();
            if (_winFlash > 0) { _winFlash--; }
        }
        WatchUi.requestUpdate();
    }

    // ── batch step ─────────────────────────────────────────────────────────────

    hidden function _doStepBatch() {
        // Reset accumulators at start of each new generation
        if (_procRow == 0) {
            for (var t = 0; t < 4; t++) { _tCntBuf[t] = 0; }
        }

        var br  = _bRows[_speed - 1];
        var end = _procRow + br;
        if (end > GH) { end = GH; }

        // Process rows [_procRow .. end) into _buf, reading neighbours from _grid
        if (_isMulti()) {
            _rowsMulti(_procRow, end);
        } else {
            _rowsSingle(_procRow, end);
        }

        _procRow = end;

        if (_procRow >= GH) {
            // Generation complete — commit _buf as the new displayed state
            var tmp = _grid; _grid = _buf; _buf = tmp;
            for (var t = 0; t < 4; t++) { _tCnt[t] = _tCntBuf[t]; }
            _gen++;
            _procRow = 0;
            if (_gen % 6 == 0) { _checkStale(); }
        }
    }

    // ── single-species row batch ────────────────────────────────────────────────

    hidden function _rowsSingle(rowStart, rowEnd) {
        var bm = 0; var sm = 0;
        if      (_mode == MD_CONWAY) { bm=8;   sm=12;  }
        else if (_mode == MD_HLIFE)  { bm=72;  sm=12;  }
        else if (_mode == MD_DNITE)  { bm=456; sm=472; }
        else if (_mode == MD_MAZE)   { bm=8;   sm=62;  }
        else if (_mode == MD_SEEDS)  { bm=4;   sm=0;   }

        var nc = 0;
        var alive = 0;
        for (var y = rowStart; y < rowEnd; y++) {
            var row  = y * GW;
            var pRow = (y > 0)      ? (y - 1) * GW : -1;
            var nRow = (y < GH - 1) ? (y + 1) * GW : -1;
            for (var x = 0; x < GW; x++) {
                var px = (x > 0)      ? x - 1 : -1;
                var nx = (x < GW - 1) ? x + 1 : -1;
                var n  = 0;
                if (pRow >= 0) {
                    if (px >= 0) { nc=_grid[pRow+px]; if (nc != 0) { n++; } }
                    nc=_grid[pRow+x]; if (nc != 0) { n++; }
                    if (nx >= 0) { nc=_grid[pRow+nx]; if (nc != 0) { n++; } }
                }
                if (px >= 0) { nc=_grid[row+px]; if (nc != 0) { n++; } }
                if (nx >= 0) { nc=_grid[row+nx]; if (nc != 0) { n++; } }
                if (nRow >= 0) {
                    if (px >= 0) { nc=_grid[nRow+px]; if (nc != 0) { n++; } }
                    nc=_grid[nRow+x]; if (nc != 0) { n++; }
                    if (nx >= 0) { nc=_grid[nRow+nx]; if (nc != 0) { n++; } }
                }
                var c = _grid[row + x];
                var nv = 0;
                if (c != 0) {
                    nv = ((sm & (1 << n)) != 0) ? 1 : 0;
                } else {
                    nv = ((bm & (1 << n)) != 0) ? 1 : 0;
                }
                _buf[row + x] = nv;
                if (nv != 0) { alive++; }
            }
        }
        // Accumulate alive count into slot 0
        _tCntBuf[0] = _tCntBuf[0] + alive;
    }

    // ── multi-team row batch ────────────────────────────────────────────────────

    hidden function _rowsMulti(rowStart, rowEnd) {
        var nT    = _nTeams;
        var isBat = (_mode == MD_BATTLE);
        var bm    = 8;
        var sm    = 12;
        var nc    = 0;

        for (var y = rowStart; y < rowEnd; y++) {
            var row  = y * GW;
            var pRow = (y > 0)      ? (y - 1) * GW : -1;
            var nRow = (y < GH - 1) ? (y + 1) * GW : -1;
            for (var x = 0; x < GW; x++) {
                var px = (x > 0)      ? x - 1 : -1;
                var nx = (x < GW - 1) ? x + 1 : -1;

                for (var ci = 0; ci < nT; ci++) { _cnt[ci] = 0; }
                var total = 0;

                // 8 unrolled neighbours
                if (pRow >= 0) {
                    if (px >= 0) { nc=_grid[pRow+px]; if (nc>0 && nc<=nT) { total++; _cnt[nc-1]++; } }
                    nc=_grid[pRow+x];  if (nc>0 && nc<=nT) { total++; _cnt[nc-1]++; }
                    if (nx >= 0) { nc=_grid[pRow+nx]; if (nc>0 && nc<=nT) { total++; _cnt[nc-1]++; } }
                }
                if (px >= 0) { nc=_grid[row+px]; if (nc>0 && nc<=nT) { total++; _cnt[nc-1]++; } }
                if (nx >= 0) { nc=_grid[row+nx]; if (nc>0 && nc<=nT) { total++; _cnt[nc-1]++; } }
                if (nRow >= 0) {
                    if (px >= 0) { nc=_grid[nRow+px]; if (nc>0 && nc<=nT) { total++; _cnt[nc-1]++; } }
                    nc=_grid[nRow+x];  if (nc>0 && nc<=nT) { total++; _cnt[nc-1]++; }
                    if (nx >= 0) { nc=_grid[nRow+nx]; if (nc>0 && nc<=nT) { total++; _cnt[nc-1]++; } }
                }

                var cell = _grid[row + x];
                var next = 0;

                if (cell > 0 && cell <= nT) {
                    var rs = isBat ? sm : _algoS[_tAlgo[cell - 1]];
                    next = ((rs & (1 << total)) != 0) ? cell : 0;
                } else {
                    var born    = 0;
                    var bestCnt = 0;
                    if (isBat) {
                        if ((bm & (1 << total)) != 0) {
                            for (var bt = 0; bt < nT; bt++) {
                                if (_cnt[bt] > bestCnt) { bestCnt=_cnt[bt]; born=bt+1; }
                            }
                        }
                    } else {
                        for (var rt = 0; rt < nT; rt++) {
                            var rb = _algoB[_tAlgo[rt]];
                            var tc = _cnt[rt];
                            if ((rb & (1 << tc)) != 0 && tc > bestCnt) {
                                bestCnt=tc; born=rt+1;
                            }
                        }
                    }
                    next = born;
                }

                _buf[row + x] = next;
                if (next > 0 && next <= nT) { _tCntBuf[next - 1]++; }
            }
        }
    }

    // ── stale / extinction detection ───────────────────────────────────────────

    hidden function _checkStale() {
        var nT    = _isMulti() ? _nTeams : 1;
        var alive = 0;
        for (var t = 0; t < nT; t++) { alive += _tCnt[t]; }

        if (alive < 5) {
            _stale++;
            if (_stale > 8) { _randomize(); return; }
        } else if (alive == _prevAlive) {
            _stale++;
            if (_stale > 30) { _randomize(); return; }
        } else {
            _stale = 0;
        }
        _prevAlive = alive;

        if (_isMulti() && alive > 30) {
            for (var wt = 0; wt < nT; wt++) {
                if (_tCnt[wt] * 100 / alive > 96) {
                    _winFlash = 20;
                    _stale    = 28;
                }
            }
        }
    }

    // ── randomisation ──────────────────────────────────────────────────────────

    hidden function _randomize() {
        Math.srand(System.getTimer());
        var pct = (_density == 0) ? 28 : ((_density == 1) ? 44 : 64);
        var nT  = _isMulti() ? _nTeams : 1;

        if (_mode == MD_RUMBLE) {
            var pool = new [8];
            for (var i = 0; i < 8; i++) { pool[i] = i; }
            for (var i = 0; i < 4; i++) {
                var j = i + Math.rand() % (8 - i);
                var tmp = pool[i]; pool[i] = pool[j]; pool[j] = tmp;
            }
            for (var i = 0; i < 4; i++) { _tAlgo[i] = pool[i]; }
        }

        for (var i = 0; i < GN; i++) {
            _grid[i] = (Math.rand() % 100 < pct) ? ((Math.rand() % nT) + 1) : 0;
        }
        _gen = 0; _stale = 0; _prevAlive = -1; _winFlash = 0; _procRow = 0;
        for (var t = 0; t < 4; t++) { _tCnt[t] = 0; _tCntBuf[t] = 0; }
    }

    hidden function _isMulti() {
        return (_mode == MD_BATTLE || _mode == MD_RUMBLE);
    }

    // ── drawing ────────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        var bg = _thBg[_theme];
        dc.setColor(bg, bg);
        dc.clear();

        if (_gs == GS_MENU) { _drawMenu(dc); return; }
        if (_gs == GS_INFO) { _drawInfo(dc); return; }

        _drawGrid(dc);
        _drawHUD(dc);

        if (_winFlash > 0 && _winFlash % 4 < 2) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h * 44 / 100, Graphics.FONT_XTINY,
                "VICTORY!", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_gs == GS_PAU) {
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(_w / 2 - 28, _h / 2 - 12, 56, 24, 8);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h / 2 - 1, Graphics.FONT_XTINY,
                "PAUSED",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    hidden function _colOf(teamIdx) {
        return _thCols[_theme * 8 + teamIdx];
    }

    hidden function _drawGrid(dc) {
        var cz  = _csz;
        var ox  = _gox;
        var oy  = _goy;
        var isM = _isMulti();

        if (!isM) {
            dc.setColor(_colOf(0), Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < GN; i++) {
                if (_grid[i] == 0) { continue; }
                dc.fillRectangle(ox + (i % GW) * cz, oy + (i / GW) * cz, cz, cz);
            }
        } else {
            for (var i = 0; i < GN; i++) {
                var cell = _grid[i];
                if (cell == 0) { continue; }
                dc.setColor(_colOf(cell - 1), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ox + (i % GW) * cz, oy + (i / GW) * cz, cz, cz);
            }
        }
    }

    hidden function _drawHUD(dc) {
        var cx  = _w / 2;
        var isM = _isMulti();

        // Top strip — pushed down enough to stay inside the round bezel
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 7 / 100, Graphics.FONT_XTINY,
            _mnames[_mode] + " " + _gen.format("%d"),
            Graphics.TEXT_JUSTIFY_CENTER);

        if (!isM) { return; }

        var nT    = _nTeams;
        var total = 0;
        for (var t = 0; t < nT; t++) { total += _tCnt[t]; }
        if (total == 0) { return; }

        var barY = _h - 9;
        var barW = _w - 20;
        var bx   = 10;

        for (var t = 0; t < nT; t++) {
            var bw = _tCnt[t] * barW / total;
            if (bw < 1 && _tCnt[t] > 0) { bw = 1; }
            if (bw > 0) {
                dc.setColor(_colOf(t), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx, barY, bw, 6);
                bx += bw;
            }
        }

        var dotY  = barY - 13;
        var slotW = barW / nT;
        for (var t = 0; t < nT; t++) {
            var lx  = 10 + t * slotW + slotW / 2;
            var pct = _tCnt[t] * 100 / total;
            dc.setColor(_colOf(t), Graphics.COLOR_TRANSPARENT);
            var lbl = "";
            if (_mode == MD_RUMBLE) {
                lbl = _algoTag[_tAlgo[t]] + " " + pct.format("%d") + "%";
            } else {
                lbl = pct.format("%d") + "%";
            }
            dc.drawText(lx, dotY, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drawMenu(dc) {
        var cx = _w / 2;

        // Title — compact, a bit inside the bezel
        dc.setColor(_colOf(0), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 8 / 100, Graphics.FONT_XTINY,
            "BITOCHI CELL WARS", Graphics.TEXT_JUSTIFY_CENTER);

        var isM     = _isMulti();
        var teamStr = isM ? ("TEAMS: " + _nTeams.format("%d")) : "TEAMS: --";

        var labels = new [MENU_N];
        labels[0] = "MODE:  " + _mnames[_mode];
        labels[1] = teamStr;
        labels[2] = "SPEED: " + _speed.format("%d") + "/5";
        labels[3] = "FILL:  " + _fillLbl[_density];
        labels[4] = "THEME: " + _thName[_theme];
        labels[5] = "RESET";
        labels[6] = "START";

        // Pack 7 rows between 18% and 88% of screen height
        var startY = _h * 18 / 100;
        var endY   = _h * 87 / 100;
        var rH     = (endY - startY) / MENU_N;
        var hlW    = _w * 60 / 100;   // highlight width scales with screen

        for (var i = 0; i < MENU_N; i++) {
            var ly  = startY + i * rH + rH / 2;
            var sel = (i == _mSel);
            if (sel) {
                dc.setColor(0x252535, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx - hlW / 2, ly - rH / 2, hlW, rH, 5);
            }
            dc.setColor(sel ? 0xFFFFFF : 0x777777, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ly, Graphics.FONT_XTINY, labels[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        dc.setColor(0x404040, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 93 / 100, Graphics.FONT_XTINY,
            "SEL=ok  UP/DN=nav", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawInfo(dc) {
        var cx = _w / 2;
        dc.setColor(_colOf(0), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 7 / 100, Graphics.FONT_XTINY,
            "ALGORITHMS", Graphics.TEXT_JUSTIFY_CENTER);

        var lines = new [8];
        lines[0]="CONWAY  B3/S23";    lines[1]="HLIFE   B36/S23";
        lines[2]="D+N     B3678/S34678"; lines[3]="MAZE    B3/S12345";
        lines[4]="SEEDS   B2/S-- burst"; lines[5]="CORAL   B3/S45678";
        lines[6]="REPLI   B1357/S1357";  lines[7]="AMOEBA  B357/S1358";

        var y  = _h * 18 / 100;
        var lh = dc.getFontHeight(Graphics.FONT_XTINY) + 4;
        for (var i = 0; i < 8; i++) {
            dc.setColor(_colOf(i), Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + i * lh, Graphics.FONT_XTINY,
                lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h - 13, Graphics.FONT_XTINY,
            "BACK=return", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── controls ──────────────────────────────────────────────────────────────

    function doSelect() {
        if (_gs == GS_RUN || _gs == GS_PAU) {
            _gs = GS_MENU; _mSel = 0;
        } else if (_gs == GS_MENU) {
            _menuAct();
        } else if (_gs == GS_INFO) {
            _gs = GS_MENU;
        }
    }

    hidden function _menuAct() {
        if (_mSel == 0) {
            _mode = (_mode + 1) % MD_COUNT;
        } else if (_mSel == 1) {
            if (_isMulti()) {
                _nTeams = (_nTeams < 4) ? (_nTeams + 1) : 2;
            }
        } else if (_mSel == 2) {
            _speed = (_speed < 5) ? (_speed + 1) : 1;
        } else if (_mSel == 3) {
            _density = (_density + 1) % 3;
        } else if (_mSel == 4) {
            _theme = (_theme + 1) % TH_COUNT;
        } else if (_mSel == 5) {
            _randomize(); _gs = GS_RUN;
        } else if (_mSel == 6) {
            if (_gen == 0) { _randomize(); }
            _gs = GS_RUN;
        }
    }

    function doUp() {
        if (_gs == GS_MENU) {
            _mSel = (_mSel + MENU_N - 1) % MENU_N;
        } else if (_gs == GS_RUN || _gs == GS_PAU) {
            if (_speed < 5) { _speed++; }
        }
    }

    function doDown() {
        if (_gs == GS_MENU) {
            _mSel = (_mSel + 1) % MENU_N;
        } else if (_gs == GS_RUN || _gs == GS_PAU) {
            if (_speed > 1) { _speed--; }
        }
    }

    function doBack() {
        // From menu: only go back to simulation if one is already running
        if (_gs == GS_MENU) { if (_gen > 0) { _gs = GS_RUN; return true; } return false; }
        if (_gs == GS_PAU)  { _gs = GS_RUN;  return true; }
        if (_gs == GS_INFO) { _gs = GS_MENU; return true; }
        return false;
    }

    function doTap(x, y) {
        if (_gs == GS_MENU) {
            var startY = _h * 18 / 100;
            var endY   = _h * 87 / 100;
            var rH     = (endY - startY) / MENU_N;
            for (var i = 0; i < MENU_N; i++) {
                var rowTop = startY + i * rH;
                if (y >= rowTop && y < rowTop + rH) {
                    _mSel = i; _menuAct(); return;
                }
            }
        } else {
            _gs = (_gs == GS_RUN) ? GS_PAU : GS_RUN;
        }
    }
}
