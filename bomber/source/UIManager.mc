// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Rendering for Bomber.
//
// Three screens:
//   drawMenu  — chess-style 4-row menu + "by Bitochi" subtitle
//   drawPlay  — top HUD + tile grid + flame/bomb overlays
//   drawEnd   — game-over OR level-cleared splash with stats
//
// Tile rendering:
//   WALL   solid dark-blue with a paler highlight (looks "metal")
//   BLOCK  amber rounded rectangle
//   FLAME  yellow-orange flickering square
//   BOMB   black circle with a tiny fuse spark
//   PU_*   colour-coded badge ("B","R","S","G")
//   PLAYER cyan disc with eyes; shield/ghost variant changes outline
//   ENEMY  magenta disc
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;

class UIManager {

    hidden static var _bx;
    hidden static var _by;
    hidden static var _bcell;
    hidden static var _bn;

    // ── Menu ────────────────────────────────────────────────────
    static function rowGeom(sw, sh) {
        var rowH = (sh * 10) / 100; if (rowH < 18) { rowH = 18; }
        var gap  = (sh *  2) / 100; if (gap  <  3) { gap  =  3; }
        var rowW = (sw * 70) / 100; if (rowW < 130) { rowW = 130; }
        var rowX = (sw - rowW) / 2;
        var rowY0 = (sh * 36) / 100;
        return [rowH, rowW, rowX, rowY0, gap];
    }

    static function drawMenu(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0x080404, 0x080404); dc.clear();
        if (sw == sh) {
            dc.setColor(0x140A0A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        dc.setColor(0xFF6633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 4 / 100, Graphics.FONT_MEDIUM,
                    "BOMBER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAA77, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 21 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        var rg   = rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];

        var labels = [
            "Enemies: " + ctrl.enemyCount.format("%d"),
            "Map:     " + ctrl.mapName(),
            "Speed:   " + ctrl.speedName(),
            "START"
        ];
        for (var i = 0; i < BM_MENU_ROWS; i++) {
            var ry      = rowY0 + i * (rowH + gap);
            var sel     = (i == ctrl.menuRow);
            var isStart = (i == BM_MENU_ROWS - 1);
            dc.setColor(sel ? (isStart ? 0x331100 : 0x1A1010) : 0x0A0808,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0xFF6633 : 0xFFAA77) : 0x442222,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xFF6633 : 0xFFEECC) : 0x99776B,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        var sub = "Hi " + ctrl.highScore.format("%d")
                + " · cleared " + ctrl.lifetimeLevels.format("%d");
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    sub, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Play ────────────────────────────────────────────────────
    static function drawPlay(dc, sw, sh, ctrl) {
        dc.setColor(0x080404, 0x080404); dc.clear();
        if (sw == sh) {
            dc.setColor(0x140A0A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sw / 2, sh / 2, sw / 2 - 1);
        }
        _drawHUD(dc, sw, sh, ctrl);
        _layoutAndDrawBoard(dc, sw, sh, ctrl);
        _drawFooter(dc, sw, sh, ctrl);
    }

    hidden static function _drawHUD(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        dc.setColor(0xFF6633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - sw / 3, sh * 7 / 100, Graphics.FONT_XTINY,
                    "L" + ctrl.level.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 7 / 100, Graphics.FONT_XTINY,
                    ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        // Bomb/range readout right.
        var rt = "B" + ctrl.maxBombs.format("%d")
               + "·R" + ctrl.bombRange.format("%d");
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + sw / 3, sh * 7 / 100, Graphics.FONT_XTINY,
                    rt, Graphics.TEXT_JUSTIFY_CENTER);
        // Active power-up timers under the score.
        if (ctrl.shieldMs > 0 || ctrl.ghostMs > 0) {
            var s = "";
            if (ctrl.shieldMs > 0) { s = "SHIELD " + ((ctrl.shieldMs + 999) / 1000).format("%d"); }
            else                    { s = "GHOST "  + ((ctrl.ghostMs  + 999) / 1000).format("%d"); }
            dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, sh * 14 / 100, Graphics.FONT_XTINY,
                        s, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden static function _drawFooter(dc, sw, sh, ctrl) {
        dc.setColor(0x668090, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sw / 2, sh - 14, Graphics.FONT_XTINY,
                    "UP/DN move  SEL bomb  swipe 4-way",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden static function _layoutAndDrawBoard(dc, sw, sh, ctrl) {
        var n = ctrl.grid.n;
        var topPad = (sh * 18) / 100;
        var botPad = (sh * 10) / 100;
        var inset  = (sw == sh) ? ((sw * 4) / 100) : 3;
        var availW = sw - inset * 2;
        var availH = sh - topPad - botPad;
        var cell   = (availW < availH ? availW : availH) / n;
        if (cell < 9) { cell = 9; }
        var boardSize = cell * n;
        _bx    = (sw - boardSize) / 2;
        _by    = topPad + (availH - boardSize) / 2;
        _bcell = cell;
        _bn    = n;

        // Backing.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(_bx - 1, _by - 1, boardSize + 2, boardSize + 2);

        for (var r = 0; r < n; r++) {
            for (var c = 0; c < n; c++) {
                _drawTile(dc, r, c, ctrl.grid.tileAt(r, c));
            }
        }
        // Bombs on top of tiles (they may share a cell with a powerup tile).
        var bombs = ctrl.bombSys.each();
        for (var i = 0; i < bombs.size(); i++) {
            _drawBomb(dc, bombs[i][0], bombs[i][1], bombs[i][2]);
        }
        // Flames overlay everything.
        var flames = ctrl.explSys.each();
        for (var i = 0; i < flames.size(); i++) {
            _drawFlame(dc, flames[i][0], flames[i][1]);
        }
        // Enemies.
        var es = ctrl.enemyMgr.enemies;
        for (var i = 0; i < es.size(); i++) {
            var e = es[i];
            if (e[2] != 0) { _drawEnemy(dc, e[0], e[1]); }
        }
        // Player.
        _drawPlayer(dc, ctrl.py, ctrl.px,
                    ctrl.shieldMs > 0, ctrl.ghostMs > 0);
    }

    hidden static function _drawTile(dc, r, c, v) {
        var x = _bx + c * _bcell;
        var y = _by + r * _bcell;
        var s = _bcell;
        if (v == BT_WALL) {
            dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, s, s);
            dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x, y, s, s);
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 2, y + 2, 3, 3);
        } else if (v == BT_BLOCK) {
            dc.setColor(0x0A0606, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, s, s);
            dc.setColor(0x885522, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 1, y + 1, s - 2, s - 2);
            dc.setColor(0xBB7733, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 2, y + 2, s - 4, 2);
        } else if (v >= BT_PU_BOMB && v <= BT_PU_GHOST) {
            // Background.
            dc.setColor(0x0A0606, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, s, s);
            var col; var letter;
            if      (v == BT_PU_BOMB)   { col = 0xFF6633; letter = "B"; }
            else if (v == BT_PU_RANGE)  { col = 0xFFCC22; letter = "R"; }
            else if (v == BT_PU_SHIELD) { col = 0x44CCFF; letter = "S"; }
            else                         { col = 0xCC44FF; letter = "G"; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + s / 2, y + s / 2, s / 2 - 2);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + s / 2, y + (s - 14) / 2, Graphics.FONT_XTINY,
                        letter, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x0A0606, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, s, s);
        }
    }

    hidden static function _drawBomb(dc, r, c, msLeft) {
        var x = _bx + c * _bcell;
        var y = _by + r * _bcell;
        var s = _bcell;
        var cx = x + s / 2;
        var cy = y + s / 2;
        // Pulse the radius as the bomb approaches detonation.
        var rd = s / 2 - 2;
        if (msLeft < 600 && (msLeft / 100) % 2 == 0) { rd = rd - 1; }
        if (rd < 3) { rd = 3; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, rd);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rd);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - rd, 2);
    }

    hidden static function _drawFlame(dc, r, c) {
        var x = _bx + c * _bcell;
        var y = _by + r * _bcell;
        var s = _bcell;
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 1, y + 1, s - 2, s - 2);
        dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + s / 4, y + s / 4, s / 2, s / 2);
    }

    hidden static function _drawEnemy(dc, r, c) {
        var x = _bx + c * _bcell;
        var y = _by + r * _bcell;
        var s = _bcell;
        var cx = x + s / 2; var cy = y + s / 2;
        var rd = s / 2 - 2;
        if (rd < 3) { rd = 3; }
        dc.setColor(0xCC44CC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, rd);
        dc.setColor(0xFFEEFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - rd / 3, cy - 1, 1);
        dc.fillCircle(cx + rd / 3, cy - 1, 1);
    }

    hidden static function _drawPlayer(dc, r, c, shield, ghost) {
        var x = _bx + c * _bcell;
        var y = _by + r * _bcell;
        var s = _bcell;
        var cx = x + s / 2; var cy = y + s / 2;
        var rd = s / 2 - 2;
        if (rd < 3) { rd = 3; }
        var col = ghost ? 0xCCCCFF : 0x44CCFF;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, rd);
        if (shield) {
            dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, rd + 1);
            dc.drawCircle(cx, cy, rd + 2);
        }
        dc.setColor(0x002030, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - rd / 3, cy - 1, 1);
        dc.fillCircle(cx + rd / 3, cy - 1, 1);
    }

    static function tapToCell(x, y) {
        if (_bcell <= 0) { return [-1, -1]; }
        var lx = x - _bx; var ly = y - _by;
        if (lx < 0 || ly < 0) { return [-1, -1]; }
        var c = lx / _bcell; var r = ly / _bcell;
        if (r < 0 || c < 0 || r >= _bn || c >= _bn) { return [-1, -1]; }
        return [r, c];
    }

    // ── End screens ───────────────────────────────────────────
    static function drawEnd(dc, sw, sh, ctrl) {
        var cx = sw / 2;
        var won = (ctrl.state == BS_WIN);
        dc.setColor(won ? 0x021018 : 0x180202, won ? 0x021018 : 0x180202);
        dc.clear();
        if (sw == sh) {
            dc.setColor(won ? 0x062236 : 0x280808, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, sh / 2, sw / 2 - 1);
        }
        dc.setColor(won ? 0x44CCFF : 0xFF6633, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 8 / 100, Graphics.FONT_MEDIUM,
                    won ? "LEVEL CLEAR" : "GAME OVER",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFEE66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 26 / 100, Graphics.FONT_SMALL,
                    "Score " + ctrl.score.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 40 / 100, Graphics.FONT_XTINY,
                    "Lvl " + ctrl.level.format("%d")
                  + "  Hi " + ctrl.highScore.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, sh * 52 / 100, Graphics.FONT_XTINY,
                    "Cleared " + ctrl.lifetimeLevels.format("%d") + " total",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(won ? 0x44CCFF : 0xFFAA77, Graphics.COLOR_TRANSPARENT);
        var hint = won ? "tap/SEL = next level" : "tap/SEL = retry";
        dc.drawText(cx, sh - 14, Graphics.FONT_XTINY,
                    hint, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
