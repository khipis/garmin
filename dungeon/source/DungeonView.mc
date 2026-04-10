using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Attention;

// ─────────────────────────────────────────────────────────────────────────────
//  DungeonView  –  all rendering + input coordination
// ─────────────────────────────────────────────────────────────────────────────

class DungeonView extends WatchUi.View {

    hidden var _g;       // DungeonGame instance
    hidden var _timer;
    hidden var _tick;
    hidden var _w; hidden var _h;
    hidden var _wobble;  // menu animation phase

    // Corridor scroll state
    hidden var _corridorScroll;  // 0-39 (pixel offset for depth lines)

    function initialize() {
        View.initialize();
        _g      = new DungeonGame();
        _tick   = 0;
        _w      = 0; _h = 0;
        _wobble = 0.0;
        _corridorScroll = 0;
    }

    function onLayout(dc) {}

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 100, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() as Void {
        _tick++;
        _wobble += 0.08;

        // Animate corridor only while running/combat
        if (_g.state == DS_RUN || _g.state == DS_COMBAT) {
            _corridorScroll = (_corridorScroll + 3) % 40;
        }

        if (_g.state != DS_MENU && _g.state != DS_DEAD) {
            _g.step();
        }

        WatchUi.requestUpdate();
    }

    // ── Input ─────────────────────────────────────────────────────────────────

    function onActionA() {
        var s = _g.state;
        if (s == DS_MENU)    { _g.resetRun(); _g.state = DS_RUN; vibe(0); }
        else if (s == DS_CHOICE)  { _g.resolveChoice(0); vibe(0); }
        else if (s == DS_POWERUP) { _g.pickPowerup(0); vibe(1); }
        else if (s == DS_DANGER)  { _g.resolveDanger(); vibe(0); }
        else if (s == DS_DEAD)    { _g.state = DS_MENU; }
        else if (s == DS_COMBAT)  { /* nothing — just watch auto-fight */ }
    }

    function onActionB() {
        var s = _g.state;
        if (s == DS_MENU)    { _g.resetRun(); _g.state = DS_RUN; vibe(0); }
        else if (s == DS_CHOICE)  { _g.resolveChoice(1); vibe(0); }
        else if (s == DS_POWERUP) { _g.pickPowerup(1); vibe(1); }
        else if (s == DS_DANGER)  { /* B does nothing in danger (A only dodge) */ }
        else if (s == DS_DEAD)    { _g.state = DS_MENU; }
    }

    function onUp() {
        if (_g.state == DS_MENU) {
            _g.selectedClass = (_g.selectedClass + 2) % 3;
        }
    }

    function onDown() {
        if (_g.state == DS_MENU) {
            _g.selectedClass = (_g.selectedClass + 1) % 3;
        }
    }

    function onBack() {
        if (_g.state == DS_DEAD || _g.state == DS_RUN ||
            _g.state == DS_COMBAT || _g.state == DS_CHOICE ||
            _g.state == DS_POWERUP || _g.state == DS_DANGER) {
            _g.state = DS_MENU;
            return true;
        }
        return false;
    }

    hidden function vibe(pat) {
        if (Toybox has :Attention) {
            if (Attention has :vibrate) {
                var dur = (pat == 0) ? 20 : 50;
                Attention.vibrate([new Attention.VibeProfile(80, dur)]);
            }
        }
    }

    // ── Rendering dispatch ────────────────────────────────────────────────────

    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth(); _h = dc.getHeight(); }

        var s = _g.state;
        if (s == DS_MENU)         { drawMenu(dc); }
        else if (s == DS_DEAD)    { drawDead(dc); }
        else if (s == DS_POWERUP) { drawPowerup(dc); }
        else if (s == DS_CHOICE)  { drawChoice(dc); }
        else {
            // RUN, COMBAT, DANGER all share the dungeon background
            drawDungeon(dc);
            if (s == DS_COMBAT || s == DS_DANGER) { drawCombat(dc); }
            drawHUD(dc);
            if (s == DS_CHOICE)  { drawChoiceOverlay(dc); }
            if (s == DS_DANGER)  { drawDangerOverlay(dc); }
        }
    }

    // ── Menu ─────────────────────────────────────────────────────────────────

    hidden function drawMenu(dc) {
        var w = _w; var h = _h;
        dc.setColor(0x060810, 0x060810); dc.clear();

        // Dungeon torch flicker at top corners
        var torchC = (_tick % 6 < 3) ? 0xFF8800 : 0xFFCC44;
        dc.setColor(torchC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(14, 20, 6);
        dc.fillCircle(w - 14, 20, 6);
        dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(14, 20, 3);
        dc.fillCircle(w - 14, 20, 3);

        // Title
        dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 8 / 100, Graphics.FONT_MEDIUM, "DUNGEON", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x664400, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 21 / 100, Graphics.FONT_XTINY, "BITOCHI GAMES", Graphics.TEXT_JUSTIFY_CENTER);

        // Class selection
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 31 / 100, Graphics.FONT_XTINY, "CLASS:", Graphics.TEXT_JUSTIFY_CENTER);

        var classes = [CLS_WARRIOR, CLS_ROGUE, CLS_MAGE];
        var clsY = [h * 39 / 100, h * 51 / 100, h * 63 / 100];
        for (var i = 0; i < 3; i++) {
            var c = classes[i];
            var selected = (_g.selectedClass == c);
            if (selected) {
                dc.setColor(_g.clsColor(c), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(w / 4, clsY[i] - 2, w / 2, 16, 3);
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
            }
            var label = _g.clsName(c);
            if (c == CLS_WARRIOR) { label = label + " HP100 D8"; }
            else if (c == CLS_ROGUE) { label = label + " HP70 D12"; }
            else { label = label + " HP60 D18"; }
            dc.drawText(w / 2, clsY[i], Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_g.bestDepth > 0) {
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 74 / 100, Graphics.FONT_XTINY,
                "BEST: depth " + _g.bestDepth, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor((_tick % 10 < 5) ? 0xFF8800 : 0xCC5500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 84 / 100, Graphics.FONT_XTINY,
            "TAP to enter dungeon", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 92 / 100, Graphics.FONT_XTINY,
            "A=pick  B=choose right", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Dungeon background (corridor + depth scroll) ──────────────────────────

    hidden function drawDungeon(dc) {
        var w = _w; var h = _h;
        dc.setColor(0x060810, 0x060810); dc.clear();

        // Ceiling and floor slabs
        dc.setColor(0x0E1825, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h * 28 / 100);          // ceiling
        dc.fillRectangle(0, h * 72 / 100, w, h - h * 72 / 100);  // floor

        // Wall gradient (dark sides)
        dc.setColor(0x0A1420, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 28 / 100, w * 12 / 100, h * 44 / 100);
        dc.fillRectangle(w * 88 / 100, h * 28 / 100, w * 12 / 100, h * 44 / 100);

        // Corridor center (lighter)
        dc.setColor(0x101D2E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w * 12 / 100, h * 28 / 100, w * 76 / 100, h * 44 / 100);

        // Perspective depth lines (scrolling = motion illusion)
        dc.setColor(0x182635, Graphics.COLOR_TRANSPARENT);
        var cx = w / 2; var cy = h / 2;
        var scroll = _corridorScroll;
        var numLines = 5;
        for (var i = 0; i < numLines; i++) {
            var t = (i.toFloat() * 40.0 / numLines.toFloat() + scroll.toFloat()) / 40.0;
            var x1 = cx - (t * w.toFloat() / 2.0).toNumber();
            var x2 = cx + (t * w.toFloat() / 2.0).toNumber();
            var ly = (h * 28 / 100 + (t * h.toFloat() * 22.0 / 100.0).toNumber()).toNumber();
            dc.drawLine(x1, ly, x2, ly);  // floor line
            ly = (h * 72 / 100 - (t * h.toFloat() * 22.0 / 100.0).toNumber()).toNumber();
            dc.drawLine(x1, ly, x2, ly);  // ceiling line
        }

        // Converging wall lines from vanishing point
        dc.setColor(0x1A2E42, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, cy, 0, h * 28 / 100);
        dc.drawLine(cx, cy, 0, h * 72 / 100);
        dc.drawLine(cx, cy, w, h * 28 / 100);
        dc.drawLine(cx, cy, w, h * 72 / 100);

        // Torch flickering on walls
        var tc = (_tick % 6 < 3) ? 0xFF8800 : 0xFF6600;
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 15 / 100, h * 35 / 100, 4);
        dc.fillCircle(w * 85 / 100, h * 35 / 100, 4);
        dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w * 15 / 100, h * 35 / 100, 2);
        dc.fillCircle(w * 85 / 100, h * 35 / 100, 2);

        // Player character (left side, ~1/3 from left)
        drawPlayer(dc, w * 30 / 100, h / 2);
    }

    hidden function drawPlayer(dc, px, py) {
        var col = _g.clsColor(_g.cls);
        // Body
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px - 8, py - 14, 16, 28, 3);
        // Head
        dc.fillCircle(px, py - 18, 7);
        // Eyes
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px - 2, py - 19, 1);
        dc.fillCircle(px + 2, py - 19, 1);
        // Shield glow if active
        if (_g.shieldCharges > 0) {
            dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(px, py - 8, 16);
            dc.drawCircle(px, py - 8, 17);
        }
    }

    // ── Combat overlay ────────────────────────────────────────────────────────

    hidden function drawCombat(dc) {
        var w = _w; var h = _h;
        if (_g.enCount == 0) { return; }

        // Draw primary enemy (right side)
        var enType0 = _g.enType[0];
        drawEnemy(dc, w * 68 / 100, h / 2, enType0, 0);

        // Draw secondary enemies (smaller, behind)
        for (var i = 1; i < _g.enCount && i < 3; i++) {
            drawEnemy(dc, w * (72 + i * 8) / 100, h * 45 / 100, _g.enType[i], i);
        }

        // Enemy HP bar
        var ehPct = _g.enHp[0].toFloat() / _g.enMaxHp[0].toFloat();
        drawBar(dc, w * 50 / 100, h * 80 / 100, w * 45 / 100, 6, ehPct, _g.enemyColor(enType0));
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 50 / 100, h * 81 / 100, Graphics.FONT_XTINY,
            _g.enemyName(enType0) + " " + _g.enHp[0], Graphics.TEXT_JUSTIFY_LEFT);

        // Multiple enemies indicator
        if (_g.enCount > 1) {
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 4, h * 81 / 100, Graphics.FONT_XTINY,
                "×" + _g.enCount, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Damage number flash
        if (_g.dmgTick > 0) {
            if (_g.lastDmgDealt != 0) {
                var isCrit = (_g.lastDmgDealt < 0);
                var dmgVal = isCrit ? (_g.lastDmgDealt * -1) : _g.lastDmgDealt;
                var dc2 = isCrit ? ((_tick % 2 == 0) ? 0xFFFF44 : 0xFFAA00) : 0xFF8866;
                dc.setColor(dc2, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w * 65 / 100, h * 38 / 100, Graphics.FONT_SMALL,
                    (isCrit ? "★" : "") + dmgVal, Graphics.TEXT_JUSTIFY_CENTER);
            }
            if (_g.lastDmgTaken > 0) {
                dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w * 30 / 100, h * 38 / 100, Graphics.FONT_SMALL,
                    "-" + _g.lastDmgTaken, Graphics.TEXT_JUSTIFY_CENTER);
            } else if (_g.lastDmgTaken == 0 && _g.shieldCharges >= 0) {
                dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w * 30 / 100, h * 38 / 100, Graphics.FONT_XTINY,
                    "BLOCKED!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden function drawEnemy(dc, ex, ey, etype, idx) {
        var col  = _g.enemyColor(etype);
        var size = (idx == 0) ? 1 : 0;  // primary enemy bigger

        if (etype == EN_GOBLIN) {
            // Small green menace
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex, ey - 8 - size * 4, 6 + size * 2);  // head
            dc.fillRoundedRectangle(ex - 7 - size * 2, ey - 2, 14 + size * 4, 16 + size * 4, 2);
            dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex - 2, ey - 9 - size * 4, 2);
            dc.fillCircle(ex + 2, ey - 9 - size * 4, 2);

        } else if (etype == EN_SKELETON) {
            // White bony figure
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex, ey - 12 - size * 4, 7 + size * 2);  // skull
            dc.drawLine(ex, ey - 5 - size * 4, ex, ey + 10 + size * 4);  // spine
            dc.drawLine(ex - 8 - size * 2, ey, ex + 8 + size * 2, ey);  // arms
            dc.drawLine(ex, ey + 10, ex - 7, ey + 22 + size * 4);
            dc.drawLine(ex, ey + 10, ex + 7, ey + 22 + size * 4);
            // X eyes
            dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(ex - 4, ey - 14 - size * 4, ex - 2, ey - 12 - size * 4);
            dc.drawLine(ex - 2, ey - 14 - size * 4, ex - 4, ey - 12 - size * 4);
            dc.drawLine(ex + 2, ey - 14 - size * 4, ex + 4, ey - 12 - size * 4);
            dc.drawLine(ex + 4, ey - 14 - size * 4, ex + 2, ey - 12 - size * 4);

        } else if (etype == EN_DEMON) {
            // Red spiky demon
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(ex - 10 - size * 3, ey - 20 - size * 5, 20 + size * 6, 36 + size * 8, 3);
            // Horns
            dc.drawLine(ex - 8, ey - 20 - size * 5, ex - 14, ey - 30 - size * 5);
            dc.drawLine(ex + 8, ey - 20 - size * 5, ex + 14, ey - 30 - size * 5);
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex - 3, ey - 12 - size * 3, 2);
            dc.fillCircle(ex + 3, ey - 12 - size * 3, 2);

        } else if (etype == EN_ELITE) {
            // Orange glowing elite
            var pulse = (_tick % 6 < 3) ? 2 : 0;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(ex - 12 - size * 4, ey - 22 - size * 6, 24 + size * 8, 40 + size * 10, 4);
            dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(ex - 12 - size * 4 - pulse, ey - 22 - size * 6 - pulse,
                24 + size * 8 + pulse * 2, 40 + size * 10 + pulse * 2, 4);
            dc.fillCircle(ex - 3, ey - 15 - size * 4, 2);
            dc.fillCircle(ex + 3, ey - 15 - size * 4, 2);

        } else {
            // BOSS: large pulsing magenta monstrosity
            var bPulse = (_tick % 4 < 2) ? 3 : 0;
            dc.setColor(0x880044, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex, ey - 10, 18 + bPulse);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex, ey - 10, 14 + bPulse);
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex - 5, ey - 15, 3);
            dc.fillCircle(ex + 5, ey - 15, 3);
            // Crown
            dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(ex - 10, ey - 28, ex - 10, ey - 34);
            dc.drawLine(ex,      ey - 28, ex,      ey - 36);
            dc.drawLine(ex + 10, ey - 28, ex + 10, ey - 34);
        }
    }

    // ── HUD ──────────────────────────────────────────────────────────────────

    hidden function drawHUD(dc) {
        var w = _w; var h = _h;

        // Top bar background
        dc.setColor(0x060810, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 22);

        // Player HP bar (left)
        var hpPct = _g.hp.toFloat() / _g.maxHp.toFloat();
        var hpColor = (hpPct < 0.30) ? 0xFF2222 : ((hpPct < 0.60) ? 0xFFAA00 : 0x44FF88);
        drawBar(dc, 2, 4, w * 45 / 100, 10, hpPct, hpColor);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 3, Graphics.FONT_XTINY, _g.hp + "/" + _g.maxHp, Graphics.TEXT_JUSTIFY_LEFT);

        // Depth (center)
        dc.setColor(0x668899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 3, Graphics.FONT_XTINY, "D" + _g.depth, Graphics.TEXT_JUSTIFY_CENTER);

        // Buff icons (right — up to 6 small dots)
        var dotX = w - 4; var dotY = 5;
        for (var i = _g.puCount - 1; i >= 0 && i >= _g.puCount - 6; i--) {
            if (_g.puList[i] < 0) { continue; }
            dc.setColor(_g.puColor(_g.puList[i]), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dotX, dotY, 3);
            dotX -= 8;
        }

        // Shield indicator
        if (_g.shieldCharges > 0) {
            dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, 3, Graphics.FONT_XTINY, "🛡" + _g.shieldCharges, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Bottom state bar
        dc.setColor(0x060810, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h - 20, w, 20);
        if (_g.state == DS_RUN) {
            dc.setColor(0x2A4A5A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 19, Graphics.FONT_XTINY, "running...", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_g.state == DS_COMBAT) {
            dc.setColor(0x662222, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 19, Graphics.FONT_XTINY, "fighting!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Choice screen ─────────────────────────────────────────────────────────

    hidden function drawChoice(dc) {
        var w = _w; var h = _h;
        drawDungeon(dc);
        drawHUD(dc);

        // Overlay
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 55 / 100, w, h * 36 / 100);

        // Timer bar
        var tPct = _g.choiceTimer.toFloat() / 22.0;
        drawBar(dc, 0, h * 55 / 100, w, 3, tPct, 0xFF8800);

        // LEFT (A)
        dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(4, h * 59 / 100, w / 2 - 8, h * 15 / 100, 4);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 4, h * 61 / 100, Graphics.FONT_XTINY, "A: LEFT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 4, h * 69 / 100, Graphics.FONT_XTINY, _g.choiceLeft, Graphics.TEXT_JUSTIFY_CENTER);

        // RIGHT (B)
        dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(w / 2 + 4, h * 59 / 100, w / 2 - 8, h * 15 / 100, 4);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 3 / 4, h * 61 / 100, Graphics.FONT_XTINY, "B: RIGHT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 3 / 4, h * 69 / 100, Graphics.FONT_XTINY, _g.choiceRight, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Inline overlay version used from drawDungeon flow
    hidden function drawChoiceOverlay(dc) { /* handled by drawChoice */ }

    // ── Danger QTE overlay ────────────────────────────────────────────────────

    hidden function drawDangerOverlay(dc) {
        var w = _w; var h = _h;
        var tPct = _g.dangerTimer.toFloat() / 12.0;
        var isDodge = (_g.dangerType == DNG_DODGE);

        // Flash background
        var flashC = isDodge ? 0x660000 : 0x004400;
        dc.setColor(flashC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 60 / 100, w, h * 28 / 100);

        // Timer bar
        var barC = isDodge ? 0xFF2222 : 0x44FF44;
        drawBar(dc, 4, h * 61 / 100, w - 8, 5, tPct, barC);

        // Main text
        var pulse = (_tick % 3 < 2) ? 0xFFFFFF : barC;
        dc.setColor(pulse, Graphics.COLOR_TRANSPARENT);
        var txt = isDodge ? "!! DODGE !!" : "** STRIKE **";
        dc.drawText(w / 2, h * 67 / 100, Graphics.FONT_SMALL, txt, Graphics.TEXT_JUSTIFY_CENTER);

        var hint = isDodge ? "TAP A to dodge!" : "TAP A for crit!";
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY, hint, Graphics.TEXT_JUSTIFY_CENTER);

        if (_g.dangerResolved) {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 67 / 100, Graphics.FONT_XTINY, "NICE!", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Power-up pick screen ──────────────────────────────────────────────────

    hidden function drawPowerup(dc) {
        var w = _w; var h = _h;
        dc.setColor(0x0A0A1A, 0x0A0A1A); dc.clear();

        // Chest glow
        var gc = (_tick % 6 < 3) ? 0xFFDD44 : 0xAA8800;
        dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(w / 2 - 14, h * 8 / 100, 28, 22, 4);
        dc.setColor(0x8B6914, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(w / 2 - 12, h * 9 / 100 + 8, 24, 12, 2);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 25 / 100, Graphics.FONT_XTINY, "POWER UP!", Graphics.TEXT_JUSTIFY_CENTER);

        // Timer bar
        var tPct = _g.puTimer.toFloat() / 30.0;
        drawBar(dc, w / 4, h * 32 / 100, w / 2, 3, tPct, 0xFF8800);

        // Option A
        var pa = _g.puOpts[0];
        var pb = _g.puOpts[1];
        dc.setColor(_g.puColor(pa), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(4, h * 36 / 100, w / 2 - 8, h * 24 / 100, 5);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 4, h * 38 / 100, Graphics.FONT_XTINY, "A:", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 4, h * 46 / 100, Graphics.FONT_XTINY, _g.puName(pa), Graphics.TEXT_JUSTIFY_CENTER);

        // Option B
        dc.setColor(_g.puColor(pb), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(w / 2 + 4, h * 36 / 100, w / 2 - 8, h * 24 / 100, 5);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 3 / 4, h * 38 / 100, Graphics.FONT_XTINY, "B:", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w * 3 / 4, h * 46 / 100, Graphics.FONT_XTINY, _g.puName(pb), Graphics.TEXT_JUSTIFY_CENTER);

        // Current buffs
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 64 / 100, Graphics.FONT_XTINY, "Current build:", Graphics.TEXT_JUSTIFY_CENTER);
        var bx = 6;
        for (var i = 0; i < _g.puCount && i < 8; i++) {
            if (_g.puList[i] < 0) { continue; }
            dc.setColor(_g.puColor(_g.puList[i]), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx, h * 70 / 100, w / 5 - 2, 14, 2);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx + (w / 5 - 2) / 2, h * 71 / 100, Graphics.FONT_XTINY,
                _g.puName(_g.puList[i]).substring(0, 4), Graphics.TEXT_JUSTIFY_CENTER);
            bx += w / 5;
            if (bx > w - w / 5) { break; }
        }

        // Stats
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 83 / 100, Graphics.FONT_XTINY,
            "D" + _g.dmg + " DEF" + _g.def + " CRIT" + _g.critChance + "%",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 90 / 100, Graphics.FONT_XTINY,
            "HP " + _g.hp + "/" + _g.maxHp, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Death screen ──────────────────────────────────────────────────────────

    hidden function drawDead(dc) {
        var w = _w; var h = _h;
        dc.setColor(0x0A0000, 0x0A0000); dc.clear();

        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 8 / 100, Graphics.FONT_MEDIUM, "YOU DIED", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xAA4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 23 / 100, Graphics.FONT_XTINY,
            "Depth: " + _g.depth, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 31 / 100, Graphics.FONT_XTINY,
            "Kills: " + _g.killedCount, Graphics.TEXT_JUSTIFY_CENTER);

        if (_g.depth >= _g.bestDepth) {
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, h * 38 / 100 - 1, w, 18);
            dc.setColor((_tick % 8 < 4) ? 0xFFDD22 : 0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 38 / 100, Graphics.FONT_XTINY,
                "★ NEW BEST: " + _g.depth + " ★", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x664444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 38 / 100, Graphics.FONT_XTINY,
                "Best: depth " + _g.bestDepth, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Final build display
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 48 / 100, Graphics.FONT_XTINY, "Build:", Graphics.TEXT_JUSTIFY_CENTER);
        var bx = 4;
        for (var i = 0; i < _g.puCount && i < 6; i++) {
            if (_g.puList[i] < 0) { continue; }
            dc.setColor(_g.puColor(_g.puList[i]), Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx + (w / 6) / 2, h * 55 / 100, Graphics.FONT_XTINY,
                _g.puName(_g.puList[i]).substring(0, 4), Graphics.TEXT_JUSTIFY_CENTER);
            bx += w / 6;
        }

        // Class
        dc.setColor(_g.clsColor(_g.cls), Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 64 / 100, Graphics.FONT_XTINY,
            _g.clsName(_g.cls) + "  D" + _g.dmg + " DEF" + _g.def,
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((_tick % 10 < 5) ? 0xFF8800 : 0xCC5500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_XTINY,
            "TAP for another run", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 87 / 100, Graphics.FONT_XTINY,
            "BACK = class select", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Shared helpers ────────────────────────────────────────────────────────

    hidden function drawBar(dc, x, y, bw, bh, pct, color) {
        dc.setColor(0x0A0A18, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, bw, bh);
        var filled = (bw.toFloat() * pct).toNumber();
        if (filled > 0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, filled, bh);
        }
        dc.setColor(0x1A2A3A, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, bw, bh);
    }
}
