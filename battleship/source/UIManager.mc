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
const COL_LAST_SHOT   = 0xFFD23F;    // last-shot highlight (amber)

// 8-direction unit vectors ×100 — integer particle math (no trig, so
// the effects stay cheap enough to run every animation frame).
var _DIRX8 = [100,  71,   0, -71, -100, -71,   0,  71];
var _DIRY8 = [  0,  71, 100,  71,    0, -71, -100, -71];

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
        dc.drawText(cx, h * 13 / 100, Graphics.FONT_SMALL,
                    "BATTLESHIP", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 24 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 35 / 100, Graphics.FONT_XTINY,
                    "Hunt - Sink - Conquer",
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (ctrl.winsTotal > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 44 / 100, Graphics.FONT_XTINY,
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
        var rowH = (h * 8) / 100; if (rowH < 16) { rowH = 16; } if (rowH > 22) { rowH = 22; }
        var rowW = (w * 70) / 100; if (rowW < 126) { rowW = 126; }
        var rowX = (w - rowW) / 2;
        var gap  = (h * 2) / 100;  if (gap < 3) { gap = 3; }
        var bandTop = h * 46 / 100;
        var bandBot = h * 83 / 100;
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
        dc.drawText(cx, h * 87 / 100, Graphics.FONT_XTINY,
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
        var body = ctrl.fleetColor();
        var edge = _scaleCol(body, 55);
        var gl = _layoutGrid(w, h);
        _drawGridBg(dc, gl);
        _drawPlayerCells(dc, ctrl.playerGrid, gl, true /* show ships */, false,
                         body, edge);
        _drawSetupPreview(dc, ctrl, gl);

        // Hint (or the daily toast, if one is pending).
        _drawBottomLine(dc, ctrl, w, h, "swipe=rot  UP/DN=mv  TAP=set");
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
        _drawLastShot(dc, gl, ctrl.lastPlayerShot);
        _drawCursor(dc, ctrl.cursor, gl);
        _drawShipStatus(dc, ctrl, w, h);

        _drawBottomLine(dc, ctrl, w, h, "UP/DOWN move - SEL fire");
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

        var ps = ctrl.lastPlayerShot;
        var hit  = (ps != null) && ps[2];
        var sunk = (ps != null) && ps[3] >= 0;

        var gl = _layoutGrid(w, h);
        _applyShake(gl, ctrl.animTick, hit, sunk);
        _drawGridBg(dc, gl);
        _drawEnemyCells(dc, ctrl.enemyGrid, gl);
        _drawShipStatus(dc, ctrl, w, h);

        if (ps != null) {
            _drawShotAnim(dc, gl, ps[0], ps[1], ps[2], sunk, ctrl.animTick);
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

        var la = ctrl.lastAIShot;
        var hit  = (la != null) && la[2];
        var sunk = (la != null) && la[3] >= 0;
        var body = ctrl.fleetColor();
        var edge = _scaleCol(body, 55);

        var gl = _layoutGrid(w, h);
        _applyShake(gl, ctrl.animTick, hit, sunk);
        _drawGridBg(dc, gl);
        _drawPlayerCells(dc, ctrl.playerGrid, gl, true, true /* show shots */,
                         body, edge);

        if (la != null) {
            _drawShotAnim(dc, gl, la[0], la[1], la[2], sunk, ctrl.animTick);
        }
        return gl;
    }

    // Screen-shake: nudges the whole board a few px on hits/sinks during
    // the IMPACT + SETTLE phases, decaying to zero. Misses don't shake.
    hidden static function _applyShake(gl, t, hit, sunk) {
        if (!hit || t < 5) { return; }
        var amp = (sunk ? 6 : 3) - (t - 5);
        if (amp <= 0) { return; }
        var sx = ((t & 1) == 0) ? amp : -amp;
        var sy = ((t & 2) == 0) ? amp : -amp;
        gl.x0 = gl.x0 + sx;
        gl.y0 = gl.y0 + sy;
    }

    // Shot animation overlay (3 phases):
    //   CHARGE  (t = 0..4)  — yellow reticle pulsing inward + cross
    //                         hair, the "missile is on its way"
    //   IMPACT  (t = 5..7)  — bright white/orange or white/cyan flash
    //                         filling the cell, with a star burst
    //   SETTLE  (t = 8..13) — expanding ring fading out, sparks for
    //                         a hit or droplets for a splash
    hidden static function _drawShotAnim(dc, gl, r, c, hit, sunk, t) {
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
            dc.setColor(0x331100, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(ax - half - 1, ay - half - 1,
                             half * 2 + 2,  half * 2 + 2);
            dc.setColor(0xFFDD33, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(ax - half, ay - half, half * 2, half * 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            var ch = (s / 4) + k;
            if (ch < 3) { ch = 3; }
            dc.drawLine(ax - ch, ay,      ax + ch, ay);
            dc.drawLine(ax,      ay - ch, ax,      ay + ch);
        } else if (t < 8) {
            // IMPACT — brilliant flash filling the cell + radial spikes.
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
            // 8-way radial spikes shooting out past the cell.
            var sp = (s * 9) / 10 + phase * 2;
            dc.setColor(hit ? 0xFF8822 : 0x4488CC, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 8; i++) {
                dc.drawLine(ax, ay,
                            ax + _DIRX8[i] * sp / 100,
                            ay + _DIRY8[i] * sp / 100);
            }
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ax, ay, (s / 4) + 1);
        } else {
            // SETTLE — hit: explosion debris; miss: water ripples.
            var k2 = t - 8;          // 0..5
            if (hit) { _hitParticles(dc, ax, ay, s, k2); }
            else     { _missParticles(dc, ax, ay, s, k2); }
        }

        // A destroyed ship gets a bold "SUNK!" flourish + a big shockwave
        // ring sweeping outward across the board (drawn over everything).
        if (sunk && t >= 5) {
            _sunkFlourish(dc, gl, ax, ay, s, t);
        }
    }

    // Explosion — expanding fireball ring, fading from white→orange→red,
    // with sparks flinging out in all 8 directions.
    hidden static function _hitParticles(dc, ax, ay, s, k2) {
        var rad = s * (5 + k2 * 5) / 10;
        if (rad < 2) { rad = 2; }
        var ring = (k2 < 1) ? 0xFFFFAA
                 : (k2 < 3) ? 0xFF8822 : 0xCC3311;
        dc.setColor(ring, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ax, ay, rad);
        if (k2 < 3) { dc.drawCircle(ax, ay, rad - 1); }
        // Sparks — travel farther each frame, shrinking as they cool.
        var dist = s * (6 + k2 * 4) / 10;
        var pr   = (k2 < 3) ? 2 : 1;
        var col  = (k2 < 2) ? 0xFFDD44 : 0xFF7722;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 8; i++) {
            var px = ax + _DIRX8[i] * dist / 100;
            var py = ay + _DIRY8[i] * dist / 100;
            dc.fillCircle(px, py, pr);
        }
    }

    // Splash — two light-blue concentric ripples + a crown of droplets
    // arcing outward, so a miss reads as water, not a dud.
    hidden static function _missParticles(dc, ax, ay, s, k2) {
        var rad = s * (4 + k2 * 4) / 10;
        if (rad < 2) { rad = 2; }
        var col = (k2 < 2) ? 0xCCEEFF : (k2 < 4) ? 0x66BBEE : 0x4488CC;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ax, ay, rad);
        if (rad > 5) { dc.drawCircle(ax, ay, rad - 3); }
        // Droplets rise then fall (crown), only the outward 5 dirs used.
        var dist = s * (5 + k2 * 3) / 10;
        dc.setColor(0xEAF6FF, Graphics.COLOR_TRANSPARENT);
        var idx = [7, 0, 1, 5, 4];   // upward-ish spray
        for (var i = 0; i < idx.size(); i++) {
            var d = idx[i];
            var px = ax + _DIRX8[d] * dist / 100;
            var py = ay + _DIRY8[d] * dist / 100 - (2 - k2);
            dc.fillCircle(px, py, 1);
        }
    }

    // "SUNK!" flourish — a large shockwave ring + a bold banner. Kept
    // brief (rides the fire animation) and clamped so it stays readable
    // on round dials.
    hidden static function _sunkFlourish(dc, gl, ax, ay, s, t) {
        var k = t - 5;                 // 0..8
        var rad = s * (8 + k * 6) / 10;
        var col = (k < 2) ? 0xFFFFFF : (k < 5) ? 0xFF9933 : 0xCC3311;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(ax, ay, rad);
        if (k < 4) { dc.drawCircle(ax, ay, rad - 2); }
        // Banner across the board centre — dark plate for legibility.
        var cx = gl.x0 + gl.side / 2;
        var cy = gl.y0 + gl.side / 2;
        dc.setColor(0x220000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 44, cy - 12, 88, 24, 5);
        dc.setColor(0xFF5544, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx - 44, cy - 12, 88, 24, 5);
        dc.setColor((t & 1) == 0 ? 0xFFFFFF : 0xFFCC55,
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 8, Graphics.FONT_SMALL, "SUNK!",
                    Graphics.TEXT_JUSTIFY_CENTER);
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

        var body = ctrl.fleetColor();
        var edge = _scaleCol(body, 55);
        var gl = _layoutGrid(w, h);
        _drawGridBg(dc, gl);
        _drawPlayerCells(dc, ctrl.playerGrid, gl, true, true /* show shots */,
                         body, edge);
        if (la != null) { _drawLastShot(dc, gl, la); }

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
    // Animated result screen: a short victory/defeat flourish plays over
    // the first ~1s (driven by ctrl.overlayTick), followed by the stats
    // and a compact meta-progression card.
    static function drawOverlay(dc, ctrl, w, h) {
        dc.setColor(COL_BG, COL_BG);
        dc.clear();
        var cx  = w / 2;
        var win = (ctrl.state == GS_WIN);
        var tk  = ctrl.overlayTick;

        // Flourish behind / around the title.
        if (win) { _victoryFx(dc, w, h, tk); }
        else     { _defeatFx(dc, w, h, tk); }

        // Title pops in: small → large over the first few frames.
        var titleCol = win ? COL_WIN : COL_LOSE;
        var titleStr = win ? "VICTORY" : "DEFEAT";
        var tFont = (tk < 3) ? Graphics.FONT_MEDIUM
                  : (tk < 6) ? Graphics.FONT_LARGE : Graphics.FONT_LARGE;
        dc.setColor(titleCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 18 / 100, tFont, titleStr,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 33 / 100, Graphics.FONT_XTINY,
                    win ? "Enemy fleet sunk!" : "Your fleet sank.",
                    Graphics.TEXT_JUSTIFY_CENTER);

        // ── Meta-progression card ──
        dc.setColor(0xBFE0FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 44 / 100, Graphics.FONT_XTINY,
                    "Lv " + ctrl.pgLevel.toString() + " "
                        + ctrl.rankName() + " - "
                        + ctrl.pgCoins.toString() + "c",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 51 / 100, Graphics.FONT_XTINY,
                    "Streak " + ctrl.pgStreak.toString()
                        + "  -  Acc " + ctrl.pgAcc.toString() + "%",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 58 / 100, Graphics.FONT_XTINY,
                    "Sunk " + ctrl.enemyShips.sunkCount().toString()
                        + "/" + NUM_SHIPS.toString()
                        + "  AI " + ctrl.playerShips.sunkCount().toString()
                        + "/" + NUM_SHIPS.toString()
                        + "  " + _aiShortName(ctrl.difficulty),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h * 65 / 100, Graphics.FONT_XTINY,
                    "Wins " + ctrl.winsTotal.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // One-shot cosmetic-unlock banner (blinks for emphasis).
        if (ctrl.pgUnlockMsg != null) {
            dc.setColor((tk % 10 < 5) ? 0xFFD24A : 0xA8862A,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 73 / 100, Graphics.FONT_XTINY,
                        ctrl.pgUnlockMsg, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 88 / 100, Graphics.FONT_XTINY,
                    "Press any key", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Victory flourish — celebratory expanding rings from behind the
    // title plus rising sparks that fan upward and out.
    hidden static function _victoryFx(dc, w, h, tk) {
        var cx = w / 2;
        var cy = h * 18 / 100 + 6;
        var rings = 3;
        for (var i = 0; i < rings; i++) {
            var age = tk - i * 4;
            if (age < 0 || age > 16) { continue; }
            var rad = 8 + age * 5;
            var sh  = 0xC0 - age * 9; if (sh < 0) { sh = 0; }
            dc.setColor((sh << 16) | (0xFF00) | 0x88, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, rad);
        }
        // Rising confetti sparks — deterministic fan, drift upward.
        if (tk < 40) {
            var idx = [7, 0, 1, 6, 2, 5, 3];
            for (var j = 0; j < idx.size(); j++) {
                var d  = idx[j];
                var ph = (tk + j * 3) % 24;
                var dist = 10 + ph * 4;
                var px = cx + _DIRX8[d] * dist / 100;
                var py = cy + _DIRY8[d] * dist / 100 - ph;
                var col = ((j & 1) == 0) ? 0x52E0A5 : 0xFFD24A;
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 2);
            }
        }
    }

    // Defeat flourish — an initial red screen wash that fades, then a
    // simple hull slipping beneath a waterline.
    hidden static function _defeatFx(dc, w, h, tk) {
        if (tk < 4) {
            // Quick crimson flash, fading out over 4 frames.
            var a = 4 - tk;
            dc.setColor((0x33 * a / 4) << 16, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w, h);
        }
        // Hull slips beneath the waterline only during the flourish, then
        // clears so it never collides with the stats text.
        if (tk < 45) {
            var cx = w / 2;
            var wl = h * 8 / 100;               // high waterline, above title
            var sink = tk; if (sink > 22) { sink = 22; }
            var sy = wl + sink;
            dc.setColor(0x3A5570, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx - 20, sy], [cx + 20, sy],
                            [cx + 12, sy + 7], [cx - 16, sy + 7]]);
            dc.setColor(0x24384D, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 5, sy - 6, 10, 6);
            dc.setColor(0x8FB4D8, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 4; i++) {
                var ph = (tk + i * 5) % 20;
                dc.fillCircle(cx - 12 + i * 8, sy - ph, (ph < 10) ? 2 : 1);
            }
        }
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
                    _drawHitMark(dc, x, y, gl.cell);
                } else {
                    _drawMissMark(dc, x, y, gl.cell);
                }
            }
        }
    }

    // Player grid: show own ships always; show shots when requested.
    // bodyCol / edgeCol drive the (cosmetic) fleet skin.
    hidden static function _drawPlayerCells(dc, grid, gl, showShips, showShots,
                                            bodyCol, edgeCol) {
        for (var r = 0; r < GRID_SIZE; r++) {
            for (var c = 0; c < GRID_SIZE; c++) {
                var x = gl.x0 + c * gl.cell;
                var y = gl.y0 + r * gl.cell;
                var hasShip = grid.hasShip(r, c);
                var shot    = grid.isShot(r, c);
                if (hasShip && showShips && !shot) {
                    // Ship body with subtle inner shading + a bright rivet
                    // so the hull reads clearly at small cell sizes.
                    dc.setColor(edgeCol, Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(x + 1, y + 1,
                                            gl.cell - 2, gl.cell - 2, 2);
                    dc.setColor(bodyCol, Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(x + 2, y + 2,
                                            gl.cell - 4, gl.cell - 4, 2);
                    if (gl.cell >= 12) {
                        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                        dc.fillCircle(x + gl.cell / 2, y + gl.cell / 2, 1);
                    }
                }
                if (shot && showShots) {
                    if (hasShip) {
                        _drawHitMark(dc, x, y, gl.cell);
                    } else {
                        _drawMissMark(dc, x, y, gl.cell);
                    }
                }
            }
        }
    }

    // Crisp HIT marker — beveled red cell with a white "X".
    hidden static function _drawHitMark(dc, x, y, cell) {
        dc.setColor(COL_HIT_DEEP, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, cell, cell);
        dc.setColor(COL_HIT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x + 1, y + 1, cell - 2, cell - 2, 2);
        // Charred inner core for depth.
        dc.setColor(COL_HIT_DEEP, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + cell / 2, y + cell / 2, cell / 4 + 1);
        _drawMark(dc, x, y, cell, "X", 0xFFFFFF);
    }

    // Crisp MISS marker — a hollow light-blue ripple ring with a dot,
    // clearly distinct from the solid hit cell.
    hidden static function _drawMissMark(dc, x, y, cell) {
        var cx2 = x + cell / 2;
        var cy2 = y + cell / 2;
        var rad = cell / 3; if (rad < 3) { rad = 3; }
        dc.setColor(COL_MISS, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx2, cy2, rad);
        dc.fillCircle(cx2, cy2, 1);
    }

    // Static highlight ring around the most-recent shot cell so the
    // player can instantly spot where the last salvo landed.
    hidden static function _drawLastShot(dc, gl, shot) {
        if (shot == null) { return; }
        var r = shot[0];
        var c = shot[1];
        if (r < 0 || c < 0 || r >= GRID_SIZE || c >= GRID_SIZE) { return; }
        var x = gl.x0 + c * gl.cell;
        var y = gl.y0 + r * gl.cell;
        dc.setColor(COL_LAST_SHOT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(x, y, gl.cell, gl.cell);
        dc.setPenWidth(1);
    }

    // Halve-ish a colour's brightness by a percentage (0..100 kept).
    hidden static function _scaleCol(col, pct) {
        var r = ((col >> 16) & 0xFF) * pct / 100;
        var g = ((col >> 8)  & 0xFF) * pct / 100;
        var b = (col & 0xFF) * pct / 100;
        return (r << 16) | (g << 8) | b;
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

    // Bottom-of-screen line: shows the pending toast (gold chip) when one
    // is active, otherwise the normal control hint. Non-blocking.
    hidden static function _drawBottomLine(dc, ctrl, w, h, hint) {
        var y = h * 88 / 100;
        if (ctrl.toastT > 0 && ctrl.toast != null) {
            var tw = w * 78 / 100;
            var tx = (w - tw) / 2;
            dc.setColor(0x1A1400, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(tx, y - 9, tw, 20, 5);
            dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(tx, y - 9, tw, 20, 5);
            dc.drawText(w / 2, y - 8, Graphics.FONT_XTINY, ctrl.toast,
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        dc.setColor(COL_TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, Graphics.FONT_XTINY, hint,
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
