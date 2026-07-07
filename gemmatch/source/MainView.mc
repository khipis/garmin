// ═══════════════════════════════════════════════════════════════
// MainView.mc — WatchUi.View — owns layout + rendering.
//
// 50 ms tick (20 fps) drives both the animation state machine and
// the round clock. The clock is delta-time based so the period
// does not affect timing accuracy.
//
// Menu (GS_MENU):
//   Chess-style 3 rows — MODE / PARAM / START.
//   Tap hit-tests individual rows; UP/DOWN navigate rows.
//
// Play rendering:
//   ANIM_SWAP  — two gems drawn at interpolated positions.
//   ANIM_FLASH — matched gems rendered with drawFlash().
//
// HUD is mode-aware:
//   GM_TIME  — countdown timer (left) | score (centre) | best (right)
//   GM_ZEN   — elapsed time +  (left) | score (centre) | best (right)
//   GM_MOVES — moves remaining (left) | score (centre) | best (right)
//
// Game-over overlay is also mode-aware.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _timer;

    // Cached layout (recomputed on every onUpdate).
    hidden var _sw;
    hidden var _sh;
    hidden var _cellPx;
    hidden var _bx;
    hidden var _by;

    function initialize() {
        View.initialize();
        _ctrl = new GameController();
        _timer = null;
        _sw = 0; _sh = 0; _cellPx = 0; _bx = 0; _by = 0;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 50, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() {
        _ctrl.tick50ms();
        WatchUi.requestUpdate();
    }

    // ── Drawing ──────────────────────────────────────────────────────
    function onUpdate(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();

        dc.setColor(0x000000, 0x000000); dc.clear();

        // Menu lives in the shared root view — drop straight into play and
        // never render an in-game menu here.
        if (_ctrl.state == GS_MENU) { _ctrl.startGame(); }

        _layoutBoard();
        if (_ctrl.shakeT > 0) {
            var amt = 2 + (_ctrl.shakeT / 5);
            if (amt > 5) { amt = 5; }
            _bx = _bx + (((_ctrl.shakeT & 1) == 0) ? amt : -amt);
            _by = _by + (((_ctrl.shakeT % 3) == 0) ? amt : -amt);
        }
        _drawBoard(dc);
        _drawHUD(dc);
        _drawChainFx(dc);
        if (_ctrl.state == GS_OVER) { _drawOver(dc); }
    }

    // ── Chain-reaction feedback overlays ────────────────────────────────
    hidden function _drawChainFx(dc) {
        var cx = _sw / 2;
        var cy = _by + (_cellPx * _ctrl.grid.rows) / 2;

        // Floating "+score" popup for the current cascade step.
        if (_ctrl.chainPopT > 0 && _ctrl.lastClearScore > 0) {
            var rise = (700 - _ctrl.chainPopT) / 12;
            var col  = (_ctrl.cascadeDepth >= 3) ? 0xFFCC22 : 0x66DDFF;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var label = "+" + _ctrl.lastClearScore.format("%d");
            if (_ctrl.cascadeDepth >= 2) { label = label + "  x" + _ctrl.cascadeDepth.format("%d"); }
            dc.drawText(cx, cy - rise, Graphics.FONT_TINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Big "BOOM!" banner when a bomb detonates.
        if (_ctrl.boomT > 0) {
            var flick = ((_ctrl.boomT / 90) % 2 == 0) ? 0xFF6600 : 0xFFEE44;
            dc.setColor(flick, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _by - 16, Graphics.FONT_SMALL, "BOOM!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Layout helper ────────────────────────────────────────────────
    hidden function _layoutBoard() {
        var grid = _ctrl.grid;
        var topPad = _sh * 13 / 100; if (topPad < 22) { topPad = 22; }
        var botPad = _sh * 8  / 100; if (botPad < 14) { botPad = 14; }
        var maxH   = _sh - topPad - botPad;
        var maxW   = _sw - 8;
        var cellW  = maxW / grid.cols;
        var cellH  = maxH / grid.rows;
        _cellPx    = (cellW < cellH) ? cellW : cellH;
        if (_cellPx < 12) { _cellPx = 12; }
        var boardW = _cellPx * grid.cols;
        var boardH = _cellPx * grid.rows;
        _bx = (_sw - boardW) / 2;
        _by = topPad + (maxH - boardH) / 2;
    }

    // ── Menu geometry (shared by render + hit-test) ───────────────────
    // Space-aware: the row height is derived from the space available
    // between the title/best band and the footer, divided by the row
    // count, then clamped. Everything is ~18% smaller than before so all
    // four rows (incl. LEADERBOARD) fit on small round watches.
    hidden function _menuRowGeom() {
        var topZone      = _sh * 32 / 100;                 // rows live below title + best
        var bottomMargin = _sh * 17 / 100; if (bottomMargin < 25) { bottomMargin = 25; }
        var gap          = _sh * 2 / 100;  if (gap < 3) { gap = 3; }
        var avail        = (_sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (MENU_ROW_COUNT - 1)) / MENU_ROW_COUNT;
        if (rowH > 25) { rowH = 25; }
        if (rowH < 13) { rowH = 13; }
        var rowW = _sw * 58 / 100; if (rowW < 99) { rowW = 99; }
        var rowX = (_sw - rowW) / 2;
        var used  = MENU_ROW_COUNT * rowH + (MENU_ROW_COUNT - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // Open the shared global leaderboard. Pushed from the view layer
    // because the controller can't push WatchUi views.
    function openLeaderboard() {
        var v = new LbScoresView("gemmatch", "", "GEM MATCH");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // ── Menu screen ──────────────────────────────────────────────────
    hidden function _drawMenu(dc) {
        var cx = _sw / 2;

        // Background
        dc.setColor(0x080808, 0x080808); dc.clear();
        if (_sw == _sh) {
            dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, _sh / 2, _sw / 2 - 1);
        }

        // Title
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 12 / 100, Graphics.FONT_SMALL,
                    "GEM MATCH", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 21 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Best score for current mode — sits in the title band, above the
        // rows, so the space-aware row block stays clear of it.
        var best = _ctrl.currentBest();
        if (best > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh * 28 / 100, Graphics.FONT_XTINY,
                        "BEST " + best.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        var rowGeom = _menuRowGeom();
        var rowH  = rowGeom[0];
        var rowW  = rowGeom[1];
        var rowX  = rowGeom[2];
        var rowY0 = rowGeom[3];
        var gap   = rowGeom[4];

        // Row labels (LEADERBOARD row is drawn via the shared badge below)
        var labels = [_ctrl.modeLabel(), _ctrl.paramLabel(), "START", ""];
        // ROW colors: focused = bright, others = dim
        for (var i = 0; i < MENU_ROW_COUNT; i++) {
            var ry     = rowY0 + i * (rowH + gap);
            var focused = (i == _ctrl.menuRow);

            if (i == MENU_LB) {
                // Hype-y gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, focused);
                continue;
            }

            var isStart = (i == MENU_START);
            var paramInert = (i == MENU_PARAM && _ctrl.gameMode == GM_ZEN);

            // Background fill
            if (isStart) {
                dc.setColor(focused ? 0x1A4400 : 0x0C2200, Graphics.COLOR_TRANSPARENT);
            } else if (paramInert) {
                dc.setColor(focused ? 0x1A1A1A : 0x111111, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(focused ? 0x0E2040 : 0x081020, Graphics.COLOR_TRANSPARENT);
            }
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);

            // Border
            if (isStart) {
                dc.setColor(focused ? 0x44BB22 : 0x225511, Graphics.COLOR_TRANSPARENT);
            } else if (paramInert) {
                dc.setColor(focused ? 0x334455 : 0x223344, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(focused ? 0x4488CC : 0x224466, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);

            // Arrow indicator on left for non-inert rows
            if (!paramInert) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 4, ay - 4],
                                [rowX + 4, ay + 4],
                                [rowX + 10, ay]]);
            }

            // Label text
            if (isStart) {
                dc.setColor(focused ? 0xAAFF66 : 0x558833, Graphics.COLOR_TRANSPARENT);
            } else if (paramInert) {
                dc.setColor(0x446677, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(focused ? 0xDDEEFF : 0x6699AA, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Footer hint
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh - 14, Graphics.FONT_XTINY,
                    "UP/DN row  tap row = act",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Board ────────────────────────────────────────────────────────
    hidden function _drawBoard(dc) {
        var g       = _ctrl.grid;
        var aState  = _ctrl.animState;
        var isSwap  = (aState == ANIM_SWAP);
        var isFlash = (aState == ANIM_FLASH);
        var isFall  = (aState == ANIM_FALL);
        var flashOn = isFlash && (_ctrl.animFrame % 2 == 0);

        // Cell backgrounds — subtle checkerboard for a touch of depth.
        for (var r = 0; r < g.rows; r++) {
            for (var c = 0; c < g.cols; c++) {
                var px = _bx + c * _cellPx;
                var py = _by + r * _cellPx;
                dc.setColor(((r + c) % 2 == 0) ? 0x0A0A18 : 0x0D0D22, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(px + 1, py + 1, _cellPx - 2, _cellPx - 2);
            }
        }

        // Selected tile background
        if (_ctrl.selR >= 0) {
            var px = _bx + _ctrl.selC * _cellPx;
            var py = _by + _ctrl.selR * _cellPx;
            dc.setColor(0x222800, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(px + 1, py + 1, _cellPx - 2, _cellPx - 2);
        }

        // Cursor highlight
        if (_ctrl.state == GS_PLAY) {
            var cx0 = _bx + _ctrl.curC * _cellPx;
            var cy0 = _by + _ctrl.curR * _cellPx;
            var col = (_ctrl.invalidFlash > 0) ? 0xFF3333 : 0x44CCFF;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(cx0, cy0, _cellPx, _cellPx);
            dc.drawRectangle(cx0 + 1, cy0 + 1, _cellPx - 2, _cellPx - 2);
        }

        // Live drag preview — the grabbed gem plus the neighbour it will
        // swap into, so the move reads clearly before the finger lifts.
        if (_ctrl.state == GS_PLAY && _ctrl.dragR >= 0) {
            var dsx = _bx + _ctrl.dragC * _cellPx;
            var dsy = _by + _ctrl.dragR * _cellPx;
            dc.setColor(0x664400, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dsx + 1, dsy + 1, _cellPx - 2, _cellPx - 2);

            if (_ctrl.dragDR != 0 || _ctrl.dragDC != 0) {
                var tr = _ctrl.dragR + _ctrl.dragDR;
                var tc = _ctrl.dragC + _ctrl.dragDC;
                var tx = _bx + tc * _cellPx;
                var ty = _by + tr * _cellPx;
                dc.setColor(0x33FF88, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(tx, ty, _cellPx, _cellPx);
                dc.drawRectangle(tx + 1, ty + 1, _cellPx - 2, _cellPx - 2);
                _drawDragArrow(dc, tx, ty, _ctrl.dragDR, _ctrl.dragDC);
            }
        }

        // Gems — skip the two animating cells during ANIM_SWAP
        var marks = _ctrl.animMarks;
        for (var r2 = 0; r2 < g.rows; r2++) {
            for (var c2 = 0; c2 < g.cols; c2++) {
                if (isSwap &&
                    ((r2 == _ctrl.animR1 && c2 == _ctrl.animC1) ||
                     (r2 == _ctrl.animR2 && c2 == _ctrl.animC2))) {
                    continue;
                }
                var t  = g.get(r2, c2);
                var gx = _bx + c2 * _cellPx + _cellPx / 2;
                var gy = isFall ? _fallGy(r2, c2) : (_by + r2 * _cellPx + _cellPx / 2);
                var picked = (_ctrl.selR == r2 && _ctrl.selC == c2) ||
                             (_ctrl.dragR == r2 && _ctrl.dragC == c2);
                if (flashOn && marks != null && marks[r2 * g.cols + c2]) {
                    Tile.drawFlash(dc, t, gx, gy, _cellPx);
                } else {
                    Tile.draw(dc, t, gx, gy, _cellPx, picked);
                }
            }
        }

        if (isSwap) { _drawSwapGems(dc); }

        // Board border
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(_bx - 1, _by - 1,
                         _cellPx * g.cols + 2, _cellPx * g.rows + 2);
    }

    // Small arrow inside the drag-preview target cell, pointing in the
    // swap direction (dr, dc) so the intended move is unmistakable.
    hidden function _drawDragArrow(dc, cellX, cellY, dr, dcc) {
        var cx = cellX + _cellPx / 2;
        var cy = cellY + _cellPx / 2;
        var s  = _cellPx / 5; if (s < 3) { s = 3; }
        dc.setColor(0x33FF88, Graphics.COLOR_TRANSPARENT);
        if (dcc > 0) {        // →
            dc.fillPolygon([[cx + s, cy], [cx - s, cy - s], [cx - s, cy + s]]);
        } else if (dcc < 0) { // ←
            dc.fillPolygon([[cx - s, cy], [cx + s, cy - s], [cx + s, cy + s]]);
        } else if (dr > 0) {  // ↓
            dc.fillPolygon([[cx, cy + s], [cx - s, cy - s], [cx + s, cy - s]]);
        } else {              // ↑
            dc.fillPolygon([[cx, cy - s], [cx - s, cy + s], [cx + s, cy + s]]);
        }
    }

    // Interpolated Y for a gem currently tumbling into place during
    // ANIM_FALL — eased-in (accelerating) to read like real gravity.
    // Freshly-spawned gems have a negative fallFrom row so they drop in
    // from above the visible board top.
    hidden function _fallGy(r, c) {
        var g = _ctrl.grid;
        var fromRow = _ctrl.fallFrom[r * g.cols + c];
        var f = _ctrl.animFrame;
        if (f > ANIM_FALL_FRAMES) { f = ANIM_FALL_FRAMES; }
        var t256 = f * 256 / ANIM_FALL_FRAMES;
        var p256 = (t256 * t256) / 256;
        var fromY = _by + fromRow * _cellPx + _cellPx / 2;
        var toY   = _by + r * _cellPx + _cellPx / 2;
        return fromY + (toY - fromY) * p256 / 256;
    }

    hidden function _drawSwapGems(dc) {
        var r1 = _ctrl.animR1; var c1 = _ctrl.animC1;
        var r2 = _ctrl.animR2; var c2 = _ctrl.animC2;
        var f  = _ctrl.animFrame;
        if (f < 0) { f = 0; }
        if (f > ANIM_SWAP_FRAMES) { f = ANIM_SWAP_FRAMES; }
        var p256 = (f * 256) / ANIM_SWAP_FRAMES;

        var x1s; var y1s; var x1e; var y1e;
        var x2s; var y2s; var x2e; var y2e;
        if (!_ctrl.animReverse) {
            x1s = _bx + c1 * _cellPx + _cellPx / 2;
            y1s = _by + r1 * _cellPx + _cellPx / 2;
            x1e = _bx + c2 * _cellPx + _cellPx / 2;
            y1e = _by + r2 * _cellPx + _cellPx / 2;
            x2s = x1e; y2s = y1e; x2e = x1s; y2e = y1s;
        } else {
            x1s = _bx + c2 * _cellPx + _cellPx / 2;
            y1s = _by + r2 * _cellPx + _cellPx / 2;
            x1e = _bx + c1 * _cellPx + _cellPx / 2;
            y1e = _by + r1 * _cellPx + _cellPx / 2;
            x2s = x1e; y2s = y1e; x2e = x1s; y2e = y1s;
        }
        var gx1 = x1s + (x1e - x1s) * p256 / 256;
        var gy1 = y1s + (y1e - y1s) * p256 / 256;
        var gx2 = x2s + (x2e - x2s) * p256 / 256;
        var gy2 = y2s + (y2e - y2s) * p256 / 256;
        Tile.draw(dc, _ctrl.animGem1, gx1, gy1, _cellPx, false);
        Tile.draw(dc, _ctrl.animGem2, gx2, gy2, _cellPx, false);
    }

    // ── HUD ──────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var cx = _sw / 2;
        var ty = _sh * 2 / 100; if (ty < 3) { ty = 3; }

        // Left — mode-specific status
        if (_ctrl.gameMode == GM_TIME) {
            dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(6, ty, Graphics.FONT_XTINY,
                        _ctrl.fmtSec(_ctrl.timeLeftMs()),
                        Graphics.TEXT_JUSTIFY_LEFT);
        } else if (_ctrl.gameMode == GM_ZEN) {
            dc.setColor(0x44CC88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(6, ty, Graphics.FONT_XTINY,
                        "+" + _ctrl.fmtSec(_ctrl.elapsedMs),
                        Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            // GM_MOVES
            dc.setColor(0xFF9922, Graphics.COLOR_TRANSPARENT);
            dc.drawText(6, ty, Graphics.FONT_XTINY,
                        _ctrl.movesLeft.format("%d") + "mv",
                        Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Centre — score
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ty, Graphics.FONT_XTINY,
                    _ctrl.score.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);

        // Right — best for current mode
        var best = _ctrl.currentBest();
        if (best > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_sw - 6, ty, Graphics.FONT_XTINY,
                        "B " + best.format("%d"),
                        Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Bottom — transient message or hint
        if (_ctrl.msgT > 0 && _ctrl.msg.length() > 0) {
            var mc = 0xFF66AA;
            if (_ctrl.lastCascade >= 6)      { mc = 0xFF3333; }
            else if (_ctrl.lastCascade >= 4) { mc = 0xFF9922; }
            else if (_ctrl.lastCascade >= 2) { mc = 0x66DDFF; }
            dc.setColor(mc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh - 16, Graphics.FONT_XTINY,
                        _ctrl.msg, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            var hint;
            if (_ctrl.selR < 0) {
                hint = "swipe gem = move";
            } else {
                hint = "tap next gem = swap";
            }
            dc.drawText(cx, _sh - 16, Graphics.FONT_XTINY,
                        hint, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Game-over overlay ────────────────────────────────────────────
    hidden function _drawOver(dc) {
        var hasStats = (_ctrl.bestChainRun >= 2 || _ctrl.bombsPopped > 0);
        var bw = _sw * 64 / 100; if (bw < 150) { bw = 150; }
        var bh = _sh * (hasStats ? 48 : 34) / 100; if (bh < (hasStats ? 118 : 100)) { bh = hasStats ? 118 : 100; }
        var bx = (_sw - bw) / 2;
        var by = (_sh - bh) / 2;
        dc.setColor(0x0A0A14, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);

        var cx = _sw / 2;

        // Title line (mode-specific)
        var title;
        if (_ctrl.gameMode == GM_TIME) {
            title = "TIME UP";
        } else if (_ctrl.gameMode == GM_ZEN) {
            title = "ZEN " + _ctrl.fmtSec(_ctrl.elapsedMs);
        } else {
            title = "MOVES: 0";
        }
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 6, Graphics.FONT_SMALL,
                    title, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + 30, Graphics.FONT_XTINY,
                    "Score " + _ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);

        var best = _ctrl.currentBest();
        if (_ctrl.score > 0 && _ctrl.score == best) {
            dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 46, Graphics.FONT_XTINY,
                        "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (best > 0) {
            dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, by + 46, Graphics.FONT_XTINY,
                        "Best " + best.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (hasStats) {
            var statsY = by + 64;
            if (_ctrl.bestChainRun >= 2) {
                dc.setColor(0x66DDFF, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, statsY, Graphics.FONT_XTINY,
                            "Best chain x" + _ctrl.bestChainRun.format("%d"),
                            Graphics.TEXT_JUSTIFY_CENTER);
                statsY = statsY + 15;
            }
            if (_ctrl.bombsPopped > 0) {
                dc.setColor(0xFF9922, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, statsY, Graphics.FONT_XTINY,
                            "Bombs popped " + _ctrl.bombsPopped.format("%d"),
                            Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        dc.setColor(0x88AABB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, by + bh - 14, Graphics.FONT_XTINY,
                    "Any key for menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Input intents ────────────────────────────────────────────────
    // navUp: menu → go to previous row; play → move cursor left (col-wrap)
    function navUp() {
        if (_ctrl.state == GS_MENU) {
            _ctrl.menuPrev();
        } else if (_ctrl.state == GS_OVER) {
            _ctrl.gotoMenu();
        } else {
            _ctrl.moveCursor(0, -1);
        }
    }

    // navDown: menu → go to next row; play → move cursor down (row-wrap)
    function navDown() {
        if (_ctrl.state == GS_MENU) {
            _ctrl.menuNext();
        } else if (_ctrl.state == GS_OVER) {
            _ctrl.gotoMenu();
        } else {
            _ctrl.moveCursor(1, 0);
        }
    }

    // Swipe a specific gem (r,c) in direction (dr,dc) — the primary touch
    // gesture. The gem the finger started on is the one that moves.
    function swapFrom(r, c, dr, dc) {
        if (_ctrl.state != GS_PLAY || _ctrl.isAnimating()) { return; }
        var tr = r + dr;
        var tc = c + dc;
        if (tr < 0 || tr >= _ctrl.grid.rows ||
            tc < 0 || tc >= _ctrl.grid.cols) { return; }
        _ctrl.beginSwap(r, c, tr, tc);
    }

    // onSwipe fallback (no start cell available): act on the picked gem,
    // or the cursor gem if nothing is picked.
    function handleSwipeSwap(dr, dc) {
        if (_ctrl.state != GS_PLAY || _ctrl.isAnimating()) { return; }
        var r = (_ctrl.selR >= 0) ? _ctrl.selR : _ctrl.curR;
        var c = (_ctrl.selR >= 0) ? _ctrl.selC : _ctrl.curC;
        var tr = r + dr;
        var tc = c + dc;
        if (tr < 0 || tr >= _ctrl.grid.rows ||
            tc < 0 || tc >= _ctrl.grid.cols) { return; }
        _ctrl.beginSwap(r, c, tr, tc);
    }

    // Tap-pick on a known board cell (used by the drag pipeline when a
    // gesture ends without enough travel to count as a swipe).
    function pickCell(r, c) { _ctrl.tapCell(r, c); }

    // Live drag-preview passthroughs (touch feedback).
    function startDrag(r, c)      { _ctrl.startDrag(r, c); }
    function updateDragDir(dr, dc) { _ctrl.updateDragDir(dr, dc); }
    function cancelDrag()          { _ctrl.cancelDrag(); }

    function navSelect() {
        if (_ctrl.state == GS_MENU && _ctrl.menuRow == MENU_LB) {
            openLeaderboard();
            return;
        }
        _ctrl.selectAction();
    }

    function navBack() {
        // ZEN: back ends the session (shows + submits the score) instead of
        // popping, so the run still counts. A second back then pops.
        if (_ctrl.state == GS_PLAY && _ctrl.gameMode == GM_ZEN) {
            _ctrl.endZen();
            return true;
        }
        // Everything else: pop back to the shared menu.
        return false;
    }

    // cellAt: converts screen pixel (x, y) → [row, col] on the board,
    // or null if the point is outside the grid. Used by drag-to-cursor.
    function cellAt(x, y) {
        if (_cellPx <= 0) { return null; }
        if (x < _bx || y < _by) { return null; }
        var col = (x - _bx) / _cellPx;
        var row = (y - _by) / _cellPx;
        if (col < 0 || col >= _ctrl.grid.cols) { return null; }
        if (row < 0 || row >= _ctrl.grid.rows) { return null; }
        return [row, col];
    }

    // setCursor: thin wrapper used by the input handler during live drag.
    function setCursor(r, c) { _ctrl.setCursor(r, c); }

    // handleTap: menu hit-tests rows; play moves cursor to tapped cell.
    function handleTap(x, y) {        if (_ctrl.state == GS_MENU) {
            var rowGeom = _menuRowGeom();
            var rowH  = rowGeom[0];
            var rowW  = rowGeom[1];
            var rowX  = rowGeom[2];
            var rowY0 = rowGeom[3];
            var gap   = rowGeom[4];
            for (var i = 0; i < MENU_ROW_COUNT; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    _ctrl.setMenuRow(i);
                    if (i == MENU_LB) { openLeaderboard(); }
                    else { _ctrl.menuActivate(); }
                    return;
                }
            }
            return;   // tap missed all rows
        }
        if (_ctrl.state == GS_OVER) { _ctrl.gotoMenu(); return; }
        // Play: tap moves cursor to the tapped cell
        if (_cellPx <= 0) { return; }
        if (x < _bx || y < _by) { return; }
        var c = (x - _bx) / _cellPx;
        var r = (y - _by) / _cellPx;
        if (c < 0 || c >= _ctrl.grid.cols) { return; }
        if (r < 0 || r >= _ctrl.grid.rows) { return; }
        _ctrl.tapCell(r, c);
    }
}
