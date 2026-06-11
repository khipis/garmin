// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Stateless drawing helpers.
//
// One entry point per controller state:
//   drawMenu, drawSetup, drawAim, drawInfo, drawOverlay
//
// Layout strategy
// ---------------
// Every draw routine computes its own anchors from (w, h) each frame
// so the layout adapts to every Garmin screen size and shape. No
// caching, no animations: redraws only happen when InputHandler
// fires `WatchUi.requestUpdate()` in response to a real input.
//
// All anchors target the inscribed safe-square of a round watch and
// are deliberately pulled ~13% inward compared to the v1 layout so
// the entire UI fits on a fenix 8 / forerunner 51 mm dial.
//
// Grid layout (SETUP / AIM):
//   • Square inscribed in the screen, centred horizontally and
//     biased slightly upward so the bottom hint never collides
//     with the round bezel.
//   • Side = min(w * 0.70, h * 0.58)
//   • 8 cells with hair-line gutters drawn as the cell background
//   • A bright cursor frame (3 px) is drawn on top of the active cell
//
// The grid layout returned by `_layoutGrid()` is surfaced to MainView
// so InputHandler.onTap can translate (px, py) → (r, c).
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.WatchUi;

// Theme — modern naval palette (deeper background, electric accents)
const COL_BG          = 0x081C36;    // deep midnight navy
const COL_BG_HL       = 0x0F2A52;    // panel background highlight
const COL_SEA         = 0x143A6D;    // grid cell unknown
const COL_SEA_ALT     = 0x183F76;    // alternating cell for checker tint
const COL_GRID_LINE   = 0x2E5797;    // separators
const COL_TEXT        = 0xF2F8FF;    // primary text
const COL_TEXT_DIM    = 0x7FA3CC;    // secondary
const COL_CURSOR      = 0xFFD23F;    // bright amber cursor
const COL_CURSOR_GLOW = 0xFFEFA0;    // soft halo for cursor
const COL_HIT         = 0xFF3B47;    // hit red
const COL_HIT_DEEP    = 0xB1242C;    // hit shadow
const COL_MISS        = 0xCFE3FA;    // miss light blue-white
const COL_SHIP        = 0x4FA0E6;    // friendly ship body
const COL_SHIP_EDGE   = 0x2D6BAF;    // ship outline shade
const COL_GHOST_OK    = 0x52E0A5;    // vivid green ghost-preview
const COL_GHOST_BAD   = 0xFF5765;    // red ghost-preview when invalid
const COL_ACCENT      = 0x32D4FF;    // electric cyan
const COL_WIN         = 0x52E0A5;
const COL_LOSE        = 0xFF5765;

// Grid layout returned by _layoutGrid() — used by MainView for tap
// hit-testing.
class GridLayout {
    var x0;
    var y0;
    var side;
    var cell;
    function initialize() { x0 = 0; y0 = 0; side = 0; cell = 0; }
    function cellRect(r, c) {
        return [x0 + c * cell, y0 + r * cell, cell, cell];
    }
    function cellAt(px, py) {
        if (px < x0 || py < y0)                 { return null; }
        if (px >= x0 + side || py >= y0 + side) { return null; }
        var c = (px - x0) / cell;
        var r = (py - y0) / cell;
        if (r < 0 || c < 0 || r >= GRID_SIZE || c >= GRID_SIZE) { return null; }
        return [r, c];
    }
}

class UIManager {

    // ── MENU ────────────────────────────────────────────────────────
    // Chess-style two-row menu: Difficulty (cycle) + START. "by
    // Bitochi" attribution under the title.
    static function drawMenu(dc, ctrl, w, h) {
        var cx = w / 2;
        dc.setColor(0x080808, 0x080808); dc.clear();
        if (w == h) {
            dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, h / 2, w / 2 - 1);
        }

        // Title + Bitochi attribution
        dc.setColor(COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 9 / 100, Graphics.FONT_SMALL,
                    "BATTLESHIP", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 21 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 33 / 100, Graphics.FONT_XTINY,
                    "Hunt - Sink - Conquer",
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (ctrl.winsTotal > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 43 / 100, Graphics.FONT_XTINY,
                        "Wins: " + ctrl.winsTotal.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Chess-style rows.  Four rows now (Diff, Shots, START + the gold
        // LEADERBOARD badge).  The dial budget is tight, so each row is
        // ~18 % shorter than the old 3-row layout and the whole block is
        // centred in the band between the title and the bottom hint so
        // nothing overlaps on small round dials.
        var labels = [
            "Diff:  " + ctrl.difficultyName(),
            "Shots: " + ctrl.shotsName(),
            "START"
        ];
        var rowH = (h * 9) / 100; if (rowH < 18) { rowH = 18; } if (rowH > 25) { rowH = 25; }
        var rowW = (w * 78) / 100; if (rowW < 140) { rowW = 140; }
        var rowX = (w - rowW) / 2;
        var gap  = (h * 2) / 100;  if (gap < 3) { gap = 3; }
        var bandTop = h * 46 / 100;
        var bandBot = h * 87 / 100;
        var blockH  = MI_ITEMS * rowH + (MI_ITEMS - 1) * gap;
        var rowY0   = bandTop + ((bandBot - bandTop) - blockH) / 2;
        if (rowY0 < bandTop) { rowY0 = bandTop; }
        for (var i = 0; i < MI_ITEMS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            var sel = (ctrl.menuCursor == i);

            // Gold shared "LEADERBOARD" badge row.
            if (i == MI_LEADERBOARD) {
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == MI_START);

            dc.setColor(sel ? (isStart ? 0x1A4400 : 0x1A3A6A) : 0x111820,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x44BB22 : 0x55AAFF) : 0x2A3A4A,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);

            if (sel) {
                dc.setColor(isStart ? 0x44BB22 : 0x55AAFF,
                            Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xAAFF66 : 0xCCEEFF) : 0x778899,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 91 / 100, Graphics.FONT_XTINY,
                    "UP/DN move  SEL act",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── SETUP ───────────────────────────────────────────────────────
    static function drawSetup(dc, ctrl, w, h) {
        dc.setColor(COL_BG, COL_BG);
        dc.clear();

        var cx   = w / 2;
        var len  = SHIP_LENS[ctrl.setupIdx];
        var name = SHIP_NAMES[ctrl.setupIdx];

        // HUD — header + step + orientation chip (kept short so two
        // lines don't collide on small dials).
        dc.setColor(COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 7 / 100, Graphics.FONT_XTINY,
                    name + " (" + len.toString() + ")",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        var sub = (ctrl.setupIdx + 1).toString() + "/"
                  + NUM_SHIPS.toString() + "  "
                  + (ctrl.setupHoriz ? "HORIZ" : "VERT");
        dc.drawText(cx, h * 14 / 100, Graphics.FONT_XTINY,
                    sub, Graphics.TEXT_JUSTIFY_CENTER);

        // Grid + ship preview
        var gl = _layoutGrid(w, h);
        _drawGridBg(dc, gl);
        _drawPlayerCells(dc, ctrl.playerGrid, gl, true /* show ships */, false);
        _drawSetupPreview(dc, ctrl, gl);

        // Hint
        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 88 / 100, Graphics.FONT_XTINY,
                    "swipe=rot  UP/DN=mv  TAP=set",
                    Graphics.TEXT_JUSTIFY_CENTER);
        return gl;
    }

    // ── AIM ─────────────────────────────────────────────────────────
    static function drawAim(dc, ctrl, w, h) {
        dc.setColor(COL_BG, COL_BG);
        dc.clear();

        var cx = w / 2;
        dc.setColor(COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 7 / 100, Graphics.FONT_XTINY,
                    "AIM  -  AI " + _aiShortName(ctrl.difficulty),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 14 / 100, Graphics.FONT_XTINY,
                    ctrl.enemyShips.sunkCount().toString()
                        + "/" + NUM_SHIPS.toString() + " sunk",
                    Graphics.TEXT_JUSTIFY_CENTER);
        // Burst badge — only when the salvo mode is active.  Tells
        // the player which shot of the burst they are about to fire,
        // since 3 shots without an AI response in between is
        // unfamiliar territory for a Battleship player.
        if (ctrl.shotsPerTurn > 1) {
            var taken = ctrl.shotsPerTurn - ctrl.playerShotsLeft + 1;
            if (taken < 1) { taken = 1; }
            if (taken > ctrl.shotsPerTurn) { taken = ctrl.shotsPerTurn; }
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 21 / 100, Graphics.FONT_XTINY,
                        "Shot " + taken.toString()
                            + "/" + ctrl.shotsPerTurn.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        var gl = _layoutGrid(w, h);
        _drawGridBg(dc, gl);
        _drawEnemyCells(dc, ctrl.enemyGrid, gl);
        _drawCursor(dc, ctrl.cursor, gl);
        _drawShipStatus(dc, ctrl, w, h);

        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 88 / 100, Graphics.FONT_XTINY,
                    "UP/DOWN move - SEL fire",
                    Graphics.TEXT_JUSTIFY_CENTER);
        return gl;
    }

    // Short label used in tight HUD strips.
    hidden static function _aiShortName(d) {
        if (d == AI_EASY)   { return "EZ"; }
        if (d == AI_MEDIUM) { return "MED"; }
        return "HARD";
    }

    // ── FIRE PLAYER (animation on enemy board) ──────────────────────
    // Mirrors drawAim() but replaces the steady cursor with the
    // shot-impact overlay on the player's just-fired cell.  The
    // hit/miss mark underneath is already painted by
    // `_drawEnemyCells` so the animation visually transitions from
    // a reticle onto the resolved cell state.
    static function drawFirePlayer(dc, ctrl, w, h) {
        dc.setColor(COL_BG, COL_BG);
        dc.clear();
        var cx = w / 2;
        dc.setColor(COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 7 / 100, Graphics.FONT_XTINY,
                    "FIRE!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 14 / 100, Graphics.FONT_XTINY,
                    "Enemy waters", Graphics.TEXT_JUSTIFY_CENTER);

        var gl = _layoutGrid(w, h);
        _drawGridBg(dc, gl);
        _drawEnemyCells(dc, ctrl.enemyGrid, gl);
        _drawShipStatus(dc, ctrl, w, h);

        var ps = ctrl.lastPlayerShot;
        if (ps != null) {
            _drawShotAnim(dc, gl, ps[0], ps[1], ps[2], ctrl.animTick);
        }
        return gl;
    }

    // ── FIRE AI (animation on player board) ─────────────────────────
    // Mirrors drawInfo() — switches us to the player's board so the
    // user sees the AI's shot land on their own ships.
    static function drawFireAI(dc, ctrl, w, h) {
        dc.setColor(COL_BG, COL_BG);
        dc.clear();
        var cx = w / 2;
        dc.setColor(COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 7 / 100, Graphics.FONT_XTINY,
                    "INCOMING", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 14 / 100, Graphics.FONT_XTINY,
                    "Your fleet", Graphics.TEXT_JUSTIFY_CENTER);

        var gl = _layoutGrid(w, h);
        _drawGridBg(dc, gl);
        _drawPlayerCells(dc, ctrl.playerGrid, gl, true, true /* show shots */);

        var la = ctrl.lastAIShot;
        if (la != null) {
            _drawShotAnim(dc, gl, la[0], la[1], la[2], ctrl.animTick);
        }
        return gl;
    }

    // Shot animation overlay (3 phases):
    //   CHARGE  (t = 0..4)  — yellow reticle pulsing inward + cross
    //                         hair, the "missile is on its way"
    //   IMPACT  (t = 5..7)  — bright white/orange or white/cyan flash
    //                         filling the cell, with a star burst
    //   SETTLE  (t = 8..13) — expanding ring fading out, sparks for
    //                         a hit or droplets for a splash
    hidden static function _drawShotAnim(dc, gl, r, c, hit, t) {
        var x  = gl.x0 + c * gl.cell;
        var y  = gl.y0 + r * gl.cell;
        var s  = gl.cell;
        if (s < 6) { s = 6; }
        var ax = x + s / 2;
        var ay = y + s / 2;

        if (t < 5) {
            // CHARGE — three converging rectangles + crosshair
            var k    = (t < 0) ? 0 : t;
            var mult = 14 - k * 2;        // 14, 12, 10, 8, 6
            var half = s * mult / 20;
            if (half < 2) { half = 2; }
            // Outer dark ring for contrast against the sea
            dc.setColor(0x331100, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(ax - half - 1, ay - half - 1,
                             half * 2 + 2,  half * 2 + 2);
            dc.setColor(0xFFDD33, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(ax - half, ay - half, half * 2, half * 2);
            // Inner crosshair (brightens as we close in)
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            var ch = (s / 4) + k;
            if (ch < 3) { ch = 3; }
            dc.drawLine(ax - ch, ay,      ax + ch, ay);
            dc.drawLine(ax,      ay - ch, ax,      ay + ch);
        } else if (t < 8) {
            // IMPACT — fill the cell with a flashing burst
            var phase = t - 5;
            var bright;
            if (hit) {
                bright = (phase == 0) ? 0xFFFFFF
                       : (phase == 1) ? 0xFFCC22 : 0xFF6622;
            } else {
                bright = (phase == 0) ? 0xFFFFFF
                       : (phase == 1) ? 0xBBEEFF : 0x66BBEE;
            }
            dc.setColor(bright, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, s, s, 3);
            // Cross-shaped burst spokes
            var sp = (s * 7) / 10;
            dc.setColor(hit ? 0xFF8822 : 0x4488CC,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawLine(ax - sp, ay,      ax + sp, ay);
            dc.drawLine(ax,      ay - sp, ax,      ay + sp);
            dc.drawLine(ax - sp + 2, ay - sp + 2,
                        ax + sp - 2, ay + sp - 2);
            dc.drawLine(ax - sp + 2, ay + sp - 2,
                        ax + sp - 2, ay - sp + 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax, ay, (s / 5) + 1);
        } else {
            // SETTLE — expanding ring + sparks / droplets
            var k2  = t - 8;          // 0..5
            var rad = s * (4 + k2 * 4) / 10;
            if (rad < 2) { rad = 2; }
            var col2;
            if (hit) {
                col2 = (k2 < 2) ? 0xFFAA22
                     : (k2 < 4) ? 0xFF6622 : 0xCC3311;
            } else {
                col2 = (k2 < 2) ? 0xCCEEFF
                     : (k2 < 4) ? 0x66BBEE : 0x4488CC;
            }
            dc.setColor(col2, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(ax, ay, rad);
            if (k2 < 3) {
                dc.drawCircle(ax, ay, rad - 1);
            }
            // Particles — deterministic offsets so they don't jitter.
            if (hit) {
                dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
                var sp2 = rad * 7 / 10;
                dc.fillCircle(ax - sp2 + 2, ay - sp2 / 2, 1);
                dc.fillCircle(ax + sp2 - 1, ay - sp2 / 3, 1);
                dc.fillCircle(ax - sp2 / 2, ay + sp2 - 1, 1);
                dc.fillCircle(ax + sp2 / 3, ay + sp2 - 2, 1);
            } else {
                dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
                var sp3 = rad * 8 / 10;
                dc.fillCircle(ax - sp3 + 1, ay - sp3 / 3, 1);
                dc.fillCircle(ax + sp3 - 1, ay + sp3 / 4, 1);
                dc.fillCircle(ax - sp3 / 4, ay + sp3 - 1, 1);
            }
        }
    }

    // ── INFO (between-turn summary) ─────────────────────────────────
    static function drawInfo(dc, ctrl, w, h) {
        dc.setColor(COL_BG, COL_BG);
        dc.clear();
        var cx = w / 2;
        dc.setColor(COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 7 / 100, Graphics.FONT_XTINY,
                    "YOUR BOARD", Graphics.TEXT_JUSTIFY_CENTER);

        var lp = ctrl.lastPlayerShot;
        var la = ctrl.lastAIShot;
        var line1 = _shotSummary("YOU", lp);
        var line2 = _shotSummary("AI ", la);
        dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 13 / 100, Graphics.FONT_XTINY,
                    line1, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 17 / 100, Graphics.FONT_XTINY,
                    line2, Graphics.TEXT_JUSTIFY_CENTER);

        var gl = _layoutGrid(w, h);
        _drawGridBg(dc, gl);
        _drawPlayerCells(dc, ctrl.playerGrid, gl, true, true /* show shots */);
        if (la != null) { _drawCursor(dc, [la[0], la[1]], gl); }

        if (ctrl.lastSinkText.length() > 0) {
            dc.setColor(COL_CURSOR, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 82 / 100, Graphics.FONT_XTINY,
                        ctrl.lastSinkText,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 88 / 100, Graphics.FONT_XTINY,
                    "Press any key", Graphics.TEXT_JUSTIFY_CENTER);
        return gl;
    }

    hidden static function _shotSummary(prefix, shot) {
        if (shot == null) { return prefix + " --"; }
        var coord = _coordName(shot[0], shot[1]);
        var verdict = shot[2] ? "HIT" : "miss";
        if (shot[3] >= 0) { verdict = "SUNK"; }
        return prefix + " " + coord + " " + verdict;
    }

    // 10×10 board → labels A..J (rows) × 1..10 (cols).
    hidden static function _coordName(r, c) {
        var letters = ['A','B','C','D','E','F','G','H','I','J'];
        var L = (r >= 0 && r < GRID_SIZE) ? letters[r].toString() : "?";
        return L + (c + 1).toString();
    }

    // ── OVERLAY (WIN/LOSE) ──────────────────────────────────────────
    static function drawOverlay(dc, ctrl, w, h) {
        dc.setColor(COL_BG, COL_BG);
        dc.clear();
        var cx = w / 2;
        var win = (ctrl.state == GS_WIN);
        var titleCol = win ? COL_WIN : COL_LOSE;
        var titleStr = win ? "VICTORY"   : "DEFEAT";
        var subStr   = win ? "Fleet sunk!" : "Your fleet sank.";

        dc.setColor(titleCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 25 / 100, Graphics.FONT_LARGE,
                    titleStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 44 / 100, Graphics.FONT_SMALL,
                    subStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 56 / 100, Graphics.FONT_XTINY,
                    "Difficulty: " + ctrl.difficultyName(),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 63 / 100, Graphics.FONT_XTINY,
                    "Wins: " + ctrl.winsTotal.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(cx, h * 73 / 100, Graphics.FONT_XTINY,
                    "You sank " + ctrl.enemyShips.sunkCount().toString()
                        + " / " + NUM_SHIPS.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 79 / 100, Graphics.FONT_XTINY,
                    "AI sank "  + ctrl.playerShips.sunkCount().toString()
                        + " / " + NUM_SHIPS.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 88 / 100, Graphics.FONT_XTINY,
                    "Press any key", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Layout + draw primitives ────────────────────────────────────
    static function _layoutGrid(w, h) {
        var gl = new GridLayout();
        // Slightly larger viewport for the 10×10 board, sized to fit
        // a round 51 mm dial with room for HUD + fleet bar + hint.
        var maxW = (w * 76) / 100;
        var maxH = (h * 60) / 100;
        var side = (maxW < maxH) ? maxW : maxH;
        var cell = side / GRID_SIZE;
        if (cell < 6) { cell = 6; }
        side = cell * GRID_SIZE;
        gl.side = side;
        gl.cell = cell;
        gl.x0   = (w - side) / 2;
        gl.y0   = h * 20 / 100;          // below the HUD
        return gl;
    }

    hidden static function _drawGridBg(dc, gl) {
        // Subtle frame
        dc.setColor(COL_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(gl.x0 - 2, gl.y0 - 2,
                                gl.side + 4, gl.side + 4, 4);
        // Water
        dc.setColor(COL_SEA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(gl.x0, gl.y0, gl.side, gl.side);
        // Checker-tint alternating cells for subtle depth
        dc.setColor(COL_SEA_ALT, Graphics.COLOR_TRANSPARENT);
        for (var r = 0; r < GRID_SIZE; r++) {
            for (var c = 0; c < GRID_SIZE; c++) {
                if (((r + c) & 1) == 0) { continue; }
                var x = gl.x0 + c * gl.cell;
                var y = gl.y0 + r * gl.cell;
                dc.fillRectangle(x, y, gl.cell, gl.cell);
            }
        }
        // Grid lines
        dc.setColor(COL_GRID_LINE, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i < GRID_SIZE; i++) {
            var x2 = gl.x0 + i * gl.cell;
            var y2 = gl.y0 + i * gl.cell;
            dc.drawLine(x2, gl.y0, x2, gl.y0 + gl.side);
            dc.drawLine(gl.x0, y2, gl.x0 + gl.side, y2);
        }
    }

    // Enemy grid: only show what player has shot at.
    hidden static function _drawEnemyCells(dc, grid, gl) {
        for (var r = 0; r < GRID_SIZE; r++) {
            for (var c = 0; c < GRID_SIZE; c++) {
                if (!grid.isShot(r, c)) { continue; }
                var x = gl.x0 + c * gl.cell;
                var y = gl.y0 + r * gl.cell;
                if (grid.isHit(r, c)) {
                    dc.setColor(COL_HIT_DEEP, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, gl.cell, gl.cell);
                    dc.setColor(COL_HIT, Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(x + 1, y + 1,
                                            gl.cell - 2, gl.cell - 2, 2);
                    _drawMark(dc, x, y, gl.cell, "X", 0xFFFFFF);
                } else {
                    dc.setColor(COL_MISS, Graphics.COLOR_TRANSPARENT);
                    var cx2 = x + gl.cell / 2;
                    var cy2 = y + gl.cell / 2;
                    var rad = gl.cell / 5; if (rad < 2) { rad = 2; }
                    dc.fillCircle(cx2, cy2, rad);
                }
            }
        }
    }

    // Player grid: show own ships always; show shots when requested.
    hidden static function _drawPlayerCells(dc, grid, gl, showShips, showShots) {
        for (var r = 0; r < GRID_SIZE; r++) {
            for (var c = 0; c < GRID_SIZE; c++) {
                var x = gl.x0 + c * gl.cell;
                var y = gl.y0 + r * gl.cell;
                var hasShip = grid.hasShip(r, c);
                var shot    = grid.isShot(r, c);
                if (hasShip && showShips && !shot) {
                    // Ship body with subtle inner shading
                    dc.setColor(COL_SHIP_EDGE, Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(x + 1, y + 1,
                                            gl.cell - 2, gl.cell - 2, 2);
                    dc.setColor(COL_SHIP, Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(x + 2, y + 2,
                                            gl.cell - 4, gl.cell - 4, 2);
                }
                if (shot && showShots) {
                    if (hasShip) {
                        dc.setColor(COL_HIT_DEEP, Graphics.COLOR_TRANSPARENT);
                        dc.fillRectangle(x, y, gl.cell, gl.cell);
                        dc.setColor(COL_HIT, Graphics.COLOR_TRANSPARENT);
                        dc.fillRoundedRectangle(x + 1, y + 1,
                                                gl.cell - 2, gl.cell - 2, 2);
                        _drawMark(dc, x, y, gl.cell, "X", 0xFFFFFF);
                    } else {
                        dc.setColor(COL_MISS, Graphics.COLOR_TRANSPARENT);
                        var cx2 = x + gl.cell / 2;
                        var cy2 = y + gl.cell / 2;
                        var rad = gl.cell / 5; if (rad < 2) { rad = 2; }
                        dc.fillCircle(cx2, cy2, rad);
                    }
                }
            }
        }
    }

    // Tint cells under the current setup ship preview in green/red.
    hidden static function _drawSetupPreview(dc, ctrl, gl) {
        var len = SHIP_LENS[ctrl.setupIdx];
        var ok  = ctrl.setupCanPlace();
        var fill   = ok ? COL_GHOST_OK  : COL_GHOST_BAD;
        for (var i = 0; i < len; i++) {
            var r = ctrl.setupHoriz ? ctrl.cursor[0] : ctrl.cursor[0] + i;
            var c = ctrl.setupHoriz ? ctrl.cursor[1] + i : ctrl.cursor[1];
            if (!GridManager.inBoundsRC(r, c)) { continue; }
            var x = gl.x0 + c * gl.cell;
            var y = gl.y0 + r * gl.cell;
            // Filled tint at low effective alpha — we fake it by drawing
            // an outline + an inner tinted rect.
            dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + 2, y + 2,
                                    gl.cell - 4, gl.cell - 4, 2);
            dc.setPenWidth(2);
            dc.drawRectangle(x + 1, y + 1, gl.cell - 2, gl.cell - 2);
        }
        dc.setPenWidth(1);
    }

    hidden static function _drawCursor(dc, cursor, gl) {
        var r = cursor[0];
        var c = cursor[1];
        var x = gl.x0 + c * gl.cell;
        var y = gl.y0 + r * gl.cell;
        // Outer glow
        dc.setColor(COL_CURSOR_GLOW, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(x - 1, y - 1, gl.cell + 2, gl.cell + 2);
        // Inner bright frame
        dc.setColor(COL_CURSOR, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawRectangle(x + 1, y + 1, gl.cell - 2, gl.cell - 2);
        dc.setPenWidth(1);
    }

    // Centred single-character mark in a cell.
    hidden static function _drawMark(dc, x, y, cell, ch, col) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var font = Graphics.FONT_XTINY;
        var fh = dc.getFontHeight(font);
        dc.drawText(x + cell / 2, y + cell / 2 - fh / 2, font, ch,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Bottom-of-screen mini fleet status — 10 bars sized by length,
    // grouped by class with small gaps between classes so the player
    // can read the fleet composition at a glance.
    //   ▰▰▰▰  ▰▰▰ ▰▰▰  ▰▰ ▰▰ ▰▰  ▰ ▰ ▰ ▰
    hidden static function _drawShipStatus(dc, ctrl, w, h) {
        var unit = 3;     // px per cell of ship length
        var gap  = 2;     // px between ships of the same class
        var gapC = 5;     // px between classes
        // Compute total width first so we can centre the row.
        var totalW = 0;
        var prevLen = SHIP_LENS[0];
        for (var i = 0; i < NUM_SHIPS; i++) {
            var ww = SHIP_LENS[i] * unit;
            totalW = totalW + ww;
            if (i > 0) {
                totalW = totalW + (SHIP_LENS[i] == prevLen ? gap : gapC);
            }
            prevLen = SHIP_LENS[i];
        }
        var bx = w / 2 - totalW / 2;
        var by = (h * 82) / 100;
        prevLen = SHIP_LENS[0];
        for (var j = 0; j < NUM_SHIPS; j++) {
            if (j > 0) {
                bx = bx + (SHIP_LENS[j] == prevLen ? gap : gapC);
            }
            var live = !ctrl.enemyShips.get(j).sunk;
            dc.setColor(live ? COL_ACCENT : COL_HIT_DEEP,
                        Graphics.COLOR_TRANSPARENT);
            var ww2 = SHIP_LENS[j] * unit;
            dc.fillRoundedRectangle(bx, by, ww2, 4, 1);
            bx = bx + ww2;
            prevLen = SHIP_LENS[j];
        }
    }
}
