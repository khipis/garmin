using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;
using Toybox.Attention;
using Toybox.ActivityMonitor;

class MainView extends WatchUi.View {

    hidden var _pet;
    hidden var _timer;
    hidden var _bounceTable;
    var actionIdx;
    var confirmReset;
    hidden var _actions;
    hidden var _celebType;
    hidden var _celebTimer;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        actionIdx = 0;
        confirmReset = false;
        _actions = ["Feed", "Play", "Clean", "Heal", "Nap", "Hug", "Punish", "Reset", "Debug", "+3h", "Vibe"];
        _bounceTable = [0, -1, -2, -2, -1, 0, 0, 0];
        _celebType = 0;
        _celebTimer = 0;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 250, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTimer() as Void {
        _pet.update();
        if (_pet.celebType > 0 && _celebTimer <= 0) {
            _celebType = _pet.celebType;
            _celebTimer = 24;
            _pet.celebType = 0;
        }
        if (_celebTimer > 0) { _celebTimer -= 1; }
        if (_pet.pendingVibe > 0) {
            doVibrate(_pet.pendingVibe);
            _pet.pendingVibe = 0;
            if (_pet.suggestedAction >= 0 && _pet.isAlive) {
                actionIdx = _pet.suggestedAction;
                _pet.suggestedAction = -1;
            }
        }
        WatchUi.requestUpdate();
    }

    function cycleAction(dir) {
        actionIdx = (actionIdx + dir + _actions.size()) % _actions.size();
    }

    function getActionName() {
        if (actionIdx == 8) { return _pet.debugMode ? "Dbg:ON" : "Debug"; }
        if (actionIdx == 9) { return "+3h Age"; }
        if (actionIdx == 10) { return _pet.vibeEnabled ? "Vibe:ON" : "Vibe:OFF"; }
        return _actions[actionIdx];
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var bg = getMoodBg();
        dc.setColor(bg, bg);
        dc.clear();

        if (!_pet.isAlive) { drawDeath(dc, w, h); return; }

        drawTime(dc, w, h);
        drawHeader(dc, w, h);
        drawStatBars(dc, w, h);
        drawNeglectWarning(dc, w, h);
        drawPetArea(dc, w, h);
        drawNeglectEffects(dc, w, h);
        drawMoodEffects(dc, w, h);
        drawEffects(dc, w, h);
        drawEvent(dc, w, h);

        if (_pet.dilemmaType > 0) {
            drawDilemma(dc, w, h);
        } else if (confirmReset) {
            drawConfirmReset(dc, w, h);
        } else {
            drawActionBar(dc, w, h);
        }

        drawBottomInfo(dc, w, h);
        drawCelebration(dc, w, h);
    }

    // --- Bottom info (steps / debug) ---

    hidden function drawBottomInfo(dc, w, h) {
        if (confirmReset || _pet.dilemmaType > 0) { return; }
        var y = h * 93 / 100;
        if (_pet.debugMode) {
            dc.setColor(0xFF3333, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Graphics.FONT_XTINY, "DBG x300", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var steps = _pet.getSteps();
            if (steps >= 0) {
                dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y, Graphics.FONT_XTINY, formatSteps(steps), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    hidden function formatSteps(steps) {
        if (steps >= 10000) { return (steps / 1000) + "k steps"; }
        if (steps >= 1000) { return (steps / 1000) + "." + ((steps % 1000) / 100) + "k steps"; }
        return steps + " steps";
    }

    hidden function doVibrate(type) {
        if (!_pet.vibeEnabled) { return; }
        if (Attention has :vibrate) {
            var p;
            if (type == 1) {
                p = [new Attention.VibeProfile(40, 100)];
            } else if (type == 2) {
                p = [new Attention.VibeProfile(50, 100), new Attention.VibeProfile(0, 80), new Attention.VibeProfile(50, 100)];
            } else if (type == 3) {
                p = [new Attention.VibeProfile(60, 100), new Attention.VibeProfile(0, 50), new Attention.VibeProfile(60, 100), new Attention.VibeProfile(0, 50), new Attention.VibeProfile(60, 100)];
            } else if (type == 4) {
                p = [new Attention.VibeProfile(100, 800)];
            } else {
                p = [new Attention.VibeProfile(40, 100)];
            }
            Attention.vibrate(p);
        }
    }

    hidden function drawCelebration(dc, w, h) {
        if (_celebTimer <= 0) { return; }
        var f = _pet.animFrame;
        if (_celebType == 1) {
            for (var i = 0; i < 8; i++) {
                var hx = (w * ((i * 31 + 7) % 97)) / 100;
                var phase = (24 - _celebTimer + i * 3) * h / 24;
                var hy = h - phase;
                if (hy < -10 || hy > h + 10) { continue; }
                var col = (i % 3 == 0) ? 0xFF6B8A : ((i % 3 == 1) ? 0xFF99AA : 0xFFCCDD);
                dc.setColor(col, col);
                drawPixelHeart(dc, hx, hy, 2 + (i % 2));
            }
        } else if (_celebType == 2) {
            for (var i = 0; i < 12; i++) {
                var sx = (w * ((i * 23 + 11) % 97)) / 100;
                var sy = (h * ((i * 37 + 13) % 97)) / 100;
                if ((f + i) % 3 == 0) { continue; }
                var col = (i % 2 == 0) ? 0xFFDD55 : 0xFFFFAA;
                dc.setColor(col, col);
                var s = 1 + (i % 2);
                dc.fillRectangle(sx, sy - s, s, s * 2 + 1);
                dc.fillRectangle(sx - s, sy, s * 2 + 1, s);
            }
        }
    }

    hidden function drawPixelHeart(dc, x, y, s) {
        dc.fillRectangle(x + s, y, s, s);
        dc.fillRectangle(x + 3 * s, y, s, s);
        dc.fillRectangle(x, y + s, 5 * s, s);
        dc.fillRectangle(x + s, y + 2 * s, 3 * s, s);
        dc.fillRectangle(x + 2 * s, y + 3 * s, s, s);
    }

    hidden function getMoodBg() {
        if (!_pet.isAlive) { return 0x080810; }
        var mood = _pet.getMoodState();
        if (mood == :rage) { return (_pet.animFrame % 2 == 0) ? 0x1A0505 : 0x150505; }
        if (mood == :love) { return 0x1A0F15; }
        if (mood == :feral) { return 0x150A05; }
        if (mood == :existential) { return 0x080808; }
        if (mood == :paranoid) { return 0x0A150A; }
        if (mood == :party) { return 0x101025; }
        var nl = _pet.getNeglectLevel();
        if (nl >= 4) { return 0x050508; }
        if (nl >= 3) { return 0x0A0508; }
        if (_pet.isSick) { return 0x0F1510; }
        if (nl >= 2) { return 0x0A0A12; }
        if (_pet.happiness > 80 && _pet.hunger < 30 && _pet.health > 70) { return 0x111128; }
        if (_pet.happiness > 60) { return 0x0F1025; }
        if (_pet.happiness < 20) { return 0x0A0A15; }
        if (nl >= 1) { return 0x0D0D1E; }
        return 0x0F0F23;
    }

    // --- Clock ---

    hidden function drawTime(dc, w, h) {
        var ct = System.getClockTime();
        var hr = ct.hour;
        var mn = ct.min;
        var ds = System.getDeviceSettings();
        if (!ds.is24Hour) {
            if (hr == 0) { hr = 12; }
            else if (hr > 12) { hr -= 12; }
        }
        var hs = (hr < 10) ? "0" + hr : "" + hr;
        var ms = (mn < 10) ? "0" + mn : "" + mn;
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 4 / 100, Graphics.FONT_TINY, hs + ":" + ms, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- Header ---

    hidden function drawHeader(dc, w, h) {
        var petColors = _pet.getColors(_pet.petType);
        dc.setColor(petColors[2], Graphics.COLOR_TRANSPARENT);
        var ageLabel = _pet.getAgeStageLabel();
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_XTINY,
            ageLabel + _pet.petName + " " + _pet.getAgeString(), Graphics.TEXT_JUSTIFY_CENTER);

        var t1 = _pet.getTraitName(_pet.trait1);
        var t2 = _pet.getTraitName(_pet.trait2);
        var sep = " + ";
        var fullW = dc.getTextWidthInPixels(t1 + sep + t2, Graphics.FONT_XTINY);
        var t1W = dc.getTextWidthInPixels(t1, Graphics.FONT_XTINY);
        var sepW = dc.getTextWidthInPixels(sep, Graphics.FONT_XTINY);
        var startX = w / 2 - fullW / 2;
        var ty = h * 18 / 100;

        dc.setColor(_pet.getTraitColor(_pet.trait1), Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, ty, Graphics.FONT_XTINY, t1, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + t1W, ty, Graphics.FONT_XTINY, sep, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(_pet.getTraitColor(_pet.trait2), Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + t1W + sepW, ty, Graphics.FONT_XTINY, t2, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // --- Stat bars ---

    hidden function drawStatBars(dc, w, h) {
        var bw = w * 15 / 100;
        var bh = h * 3 / 100;
        if (bh < 4) { bh = 4; }
        var gap = w * 2 / 100;
        var total = 4 * bw + 3 * gap;
        var sx = (w - total) / 2;
        var y = h * 25 / 100;

        var food = 100 - _pet.hunger;
        drawMiniBar(dc, sx, y, bw, bh, food, 0x4CAF50);
        drawMiniBar(dc, sx + bw + gap, y, bw, bh, _pet.happiness, 0xFFD700);
        drawMiniBar(dc, sx + 2 * (bw + gap), y, bw, bh, _pet.energy, 0x42A5F5);
        drawMiniBar(dc, sx + 3 * (bw + gap), y, bw, bh, _pet.health, 0xE040FB);

        var ly = y + bh + 1;
        dc.setColor(0x555566, Graphics.COLOR_TRANSPARENT);
        var fnt = Graphics.FONT_XTINY;
        dc.drawText(sx + bw / 2, ly, fnt, "F", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(sx + bw + gap + bw / 2, ly, fnt, "H", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(sx + 2 * (bw + gap) + bw / 2, ly, fnt, "E", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(sx + 3 * (bw + gap) + bw / 2, ly, fnt, "HP", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawMiniBar(dc, x, y, bw, bh, val, color) {
        dc.setColor(0x1A1A2E, 0x1A1A2E);
        dc.fillRectangle(x, y, bw, bh);
        if (val < 0) { val = 0; }
        if (val > 100) { val = 100; }
        if (val < 25) {
            color = (_pet.animFrame % 4 < 2) ? 0xFF4444 : 0xFF7777;
        }
        dc.setColor(color, color);
        dc.fillRectangle(x, y, bw * val / 100, bh);
        dc.setColor(0x333344, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, bw, bh);
    }

    // --- Neglect warning ---

    hidden function drawNeglectWarning(dc, w, h) {
        var nl = _pet.getNeglectLevel();
        var st = _pet.getNeglectSadThreshold();
        if (nl < st) { return; }
        var msg;
        var nlColor;
        if (nl >= 4) {
            msg = getNeglectMsg(3);
            nlColor = (_pet.animFrame % 2 == 0) ? 0xFF0000 : 0xFF3333;
        } else if (nl >= st + 1) {
            msg = getNeglectMsg(2);
            nlColor = (_pet.animFrame % 4 < 2) ? 0xFF3333 : 0xFF5555;
        } else {
            msg = getNeglectMsg(1);
            nlColor = 0xFFAA33;
        }
        dc.setColor(nlColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 33 / 100, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function getNeglectMsg(severity) {
        var t = _pet.petType;
        if (t == TYPE_EMILKA) {
            if (severity >= 3) { return "ZOSTAWILES MNIE!!!"; }
            if (severity >= 2) { return "Gdzie jestes??"; }
            return "Tesknie za Toba...";
        }
        if (t == TYPE_DOGGO) {
            if (severity >= 3) { return "*HOWLING*"; }
            if (severity >= 2) { return "COME BACK PLZ!"; }
            return "*stares at door*";
        }
        if (t == TYPE_VEXOR) {
            if (severity >= 3) { return "YOU'RE DEAD TO ME"; }
            if (severity >= 2) { return "WHERE THE F*CK R U"; }
            return "*seething*";
        }
        if (t == TYPE_POLACCO) {
            if (severity >= 3) { return "CH*J Z TYM WSZYSTKIM!"; }
            if (severity >= 2) { return "No gdzie lazisz k*rwa?"; }
            return "Ej.. jest tam ktos?";
        }
        if (t == TYPE_NOSACZ) {
            if (severity >= 3) { return "EEE!! ZOSTAW NOS!!"; }
            if (severity >= 2) { return "E E... gdzie?"; }
            return "E?";
        }
        if (t == TYPE_CHIKKO) {
            if (severity >= 3) { return "*PANICS LOUDLY*"; }
            if (severity >= 2) { return "ABANDONED! CLUCK!"; }
            return "Hello?? BAWK??";
        }
        if (t == TYPE_FOCZKA) {
            if (severity >= 3) { return "*sad seal sounds*"; }
            if (severity >= 2) { return "*ARF... ARF...*"; }
            return "*quiet arf*";
        }
        if (t == TYPE_DONUT) {
            if (severity >= 3) { return "AM I GOING STALE?!"; }
            if (severity >= 2) { return "Still here... alone.."; }
            return "Hello?";
        }
        if (t == TYPE_RAINBOW) {
            if (severity >= 3) { return "*colors fading...*"; }
            if (severity >= 2) { return "Sparkle... dimming..."; }
            return "Where did u go?";
        }
        if (t == TYPE_ROCKY) {
            if (severity >= 3) { return "EVEN ROCKS CRY."; }
            return "...you gone?";
        }
        if (t == TYPE_PIXELBOT) {
            if (severity >= 3) { return "USER: DISCONNECTED"; }
            return "IDLE: TIMEOUT WARN";
        }
        if (severity >= 3) { return "I NEED YOU!"; }
        if (severity >= 2) { return "Please come back!"; }
        return "Missing you...";
    }

    // --- Pet ---

    hidden function drawPetArea(dc, w, h) {
        var ps = w / 30;
        if (ps < 3) { ps = 3; }
        var cx = w / 2;
        var cy = h / 2;

        var state = _pet.getState();
        var mood = _pet.getMoodState();
        var bounce = 0;
        if (state != :dead && state != :sleeping) {
            var bidx = _pet.animFrame % 8;
            if (_pet.hasTrait(TRAIT_HYPER)) { bidx = (_pet.animFrame * 2) % 8; }
            else if (_pet.hasTrait(TRAIT_SLEEPY)) { bidx = (_pet.animFrame / 2) % 8; }
            if (mood == :sugar_high || mood == :party) { bidx = (_pet.animFrame * 3) % 8; }
            bounce = _bounceTable[bidx] * ps / 2;
            if (mood == :sugar_high) { bounce = bounce * 2; }
            if (mood == :existential) { bounce = 0; }
        }

        var tremble = 0;
        if (_pet.health < 25 && _pet.action == ACT_NONE) {
            tremble = (_pet.animFrame % 2 == 0) ? 1 : -1;
        }
        if (mood == :rage) { tremble = (_pet.animFrame % 2 == 0) ? 3 : -3; }
        else if (mood == :paranoid) { tremble = (_pet.animFrame % 3) - 1; }
        else if (mood == :feral) { tremble = (_pet.animFrame % 2 == 0) ? 2 : -2; }

        _pet.draw(dc, cx + tremble, cy + bounce, ps);

        if (_pet.getState() == :stuffed) { drawVomit(dc, cx, cy, ps); }
        if (_pet.poopCount > 0) { drawPoop(dc, cx, cy + 7 * ps + bounce, ps); }

        if (_pet.isSick) {
            dc.setColor(0x00FF00, Graphics.COLOR_TRANSPARENT);
            var wobble = (_pet.animFrame % 4 < 2) ? 1 : -1;
            dc.drawText(cx + 7 * ps + wobble, cy - 4 * ps, Graphics.FONT_XTINY, "SICK", Graphics.TEXT_JUSTIFY_LEFT);
        }

        if (_pet.hasTrait(TRAIT_SLEEPY) && _pet.action == ACT_NONE && !_pet.isSick && _pet.animFrame % 8 < 2) {
            dc.setColor(0x7986CB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 6 * ps, cy - 5 * ps + bounce, Graphics.FONT_XTINY, "z", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    hidden function drawVomit(dc, cx, cy, ps) {
        var f = _pet.animFrame;
        var colors = [0x88CC44, 0x66AA33, 0xAADD55];
        for (var i = 0; i < 6; i++) {
            var vx = cx + ((i % 2 == 0) ? -1 : 1) * (1 + i) * ps;
            var drop = (f + i * 2) % 8;
            var vy = cy + 4 * ps + drop * ps;
            var sz = ps / 2;
            if (sz < 2) { sz = 2; }
            dc.setColor(colors[i % 3], colors[i % 3]);
            dc.fillRectangle(vx, vy, sz, sz + 1);
            if (drop > 4) {
                dc.fillRectangle(vx - 1, vy + sz + 1, sz + 2, sz / 2 + 1);
            }
        }
    }

    hidden function drawPoop(dc, cx, bottomY, ps) {
        var count = _pet.poopCount;
        if (count > 5) { count = 5; }
        var totalW = count * ps * 2;
        var sx = cx - totalW / 2;
        var p = ps * 3 / 4;
        if (p < 2) { p = 2; }
        for (var i = 0; i < count; i++) {
            var px = sx + i * ps * 2;
            dc.setColor(0x6D4C41, 0x6D4C41);
            dc.fillRectangle(px + ps / 4, bottomY, p, p / 2);
            dc.setColor(0x8D6E63, 0x8D6E63);
            dc.fillRectangle(px, bottomY + p / 2, ps, p / 2);
        }
        if (count >= 3) {
            dc.setColor(0x7B8B3A, 0x7B8B3A);
            var f = _pet.animFrame;
            for (var i = 0; i < count && i < 3; i++) {
                var px = sx + i * ps * 2 + ps / 2;
                var wb = ((f + i * 2) % 4 < 2) ? ps / 3 : -(ps / 3);
                var dsz = ps / 3;
                if (dsz < 1) { dsz = 1; }
                dc.fillRectangle(px + wb, bottomY - ps / 2, dsz, dsz);
                dc.fillRectangle(px - wb, bottomY - ps, dsz, dsz);
            }
        }
    }

    // --- Neglect visual effects ---

    hidden function drawNeglectEffects(dc, w, h) {
        var ps = w / 30;
        if (ps < 3) { ps = 3; }
        var cx = w / 2;
        var cy = h / 2;
        var f = _pet.animFrame;

        drawTears(dc, cx, cy, ps, f);
        drawSweat(dc, cx, cy, ps, f);
        drawHungerRumble(dc, cx, cy, ps, f);
        drawFlies(dc, cx, cy + 7 * ps, ps, f);
    }

    hidden function drawTears(dc, cx, cy, ps, f) {
        var nl = _pet.getNeglectLevel();
        var st = _pet.getNeglectSadThreshold();
        var showFromNeglect = (st < 99) && (nl >= st);
        var show = (_pet.happiness < 30) || showFromNeglect;
        if (!show || _pet.action != ACT_NONE) { return; }
        dc.setColor(0x42A5F5, 0x42A5F5);
        var dotSz = ps / 2;
        if (dotSz < 1) { dotSz = 1; }
        var t1y = cy - ps + (f % 8) * ps * 3 / 4;
        var t2y = cy - ps + ((f + 4) % 8) * ps * 3 / 4;
        dc.fillRectangle(cx - 3 * ps, t1y, dotSz, dotSz + 1);
        dc.fillRectangle(cx + 2 * ps, t2y, dotSz, dotSz + 1);
        if (nl >= st + 1) {
            var t3y = cy - ps + ((f + 2) % 8) * ps * 3 / 4;
            dc.fillRectangle(cx - 2 * ps, t3y, dotSz, dotSz + 1);
            dc.fillRectangle(cx + 3 * ps, t3y, dotSz, dotSz + 1);
        }
    }

    hidden function drawSweat(dc, cx, cy, ps, f) {
        if (_pet.energy >= 20 || _pet.action == ACT_SLEEPING) { return; }
        dc.setColor(0x42A5F5, 0x42A5F5);
        var dotSz = ps / 2;
        if (dotSz < 1) { dotSz = 1; }
        var sy = cy - 5 * ps + (f % 3) * ps / 2;
        dc.fillRectangle(cx + 5 * ps, sy, dotSz, dotSz + 1);
        dc.fillRectangle(cx + 5 * ps, sy + dotSz + 1, dotSz / 2, dotSz);
    }

    hidden function drawHungerRumble(dc, cx, cy, ps, f) {
        if (_pet.hunger < 70 || _pet.action == ACT_EATING) { return; }
        dc.setColor(0x888844, Graphics.COLOR_TRANSPARENT);
        var wobble = (f % 2 == 0) ? 1 : -1;
        dc.drawText(cx + wobble, cy + 5 * ps, Graphics.FONT_XTINY, "~", Graphics.TEXT_JUSTIFY_CENTER);
        if (_pet.hunger >= 85) {
            dc.drawText(cx - ps * 2 - wobble, cy + 5 * ps, Graphics.FONT_XTINY, "~", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx + ps * 2 + wobble, cy + 5 * ps, Graphics.FONT_XTINY, "~", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawFlies(dc, cx, bottomY, ps, f) {
        if (_pet.poopCount < 3) { return; }
        dc.setColor(0x333322, 0x333322);
        var dotSz = ps / 3;
        if (dotSz < 1) { dotSz = 1; }
        var offsets = [[-3, -2], [2, -1], [0, -3], [-1, -1]];
        var count = (_pet.poopCount >= 5) ? 4 : 2;
        for (var i = 0; i < count; i++) {
            var ox = offsets[i][0] * ps + ((f + i * 2) % 4 - 2) * ps / 2;
            var oy = offsets[i][1] * ps + (((f + i) % 3) - 1) * ps / 2;
            dc.fillRectangle(cx + ox, bottomY + oy, dotSz, dotSz);
        }
    }

    // --- Mood Effects ---

    hidden function drawMoodEffects(dc, w, h) {
        var mood = _pet.getMoodState();
        if (mood == :calm) { return; }
        var f = _pet.animFrame;
        var cx = w / 2;
        var cy = h / 2;
        var ps = w / 30;
        if (ps < 3) { ps = 3; }

        if (mood == :rage) {
            dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
            if (f % 4 < 2) {
                dc.drawText(cx - 6*ps, cy - 5*ps, Graphics.FONT_XTINY, "!", Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(cx + 6*ps, cy - 3*ps, Graphics.FONT_XTINY, "!", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawText(cx - 4*ps, cy - 6*ps, Graphics.FONT_XTINY, "!", Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(cx + 5*ps, cy - 5*ps, Graphics.FONT_XTINY, "!", Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.setColor(0xFF4444, 0xFF4444);
            var vx = cx + 5*ps;
            var vy = cy - 6*ps;
            dc.fillRectangle(vx, vy, ps, ps/2 + 1);
            dc.fillRectangle(vx + ps/2, vy - ps/2, ps/2 + 1, ps);
        } else if (mood == :love) {
            for (var i = 0; i < 5; i++) {
                var hx = cx + ((f + i * 3) % 9 - 4) * ps * 2;
                var hy = cy - (3 + (f + i * 2) % 6) * ps;
                var col = (i % 2 == 0) ? 0xFF6B8A : 0xFFAACC;
                dc.setColor(col, col);
                dc.fillRectangle(hx, hy, ps/2 + 1, ps/2 + 1);
                dc.fillRectangle(hx + ps, hy, ps/2 + 1, ps/2 + 1);
                dc.fillRectangle(hx - ps/4, hy + ps/2, ps + ps/2 + 1, ps/2 + 1);
                dc.fillRectangle(hx + ps/4, hy + ps, ps, ps/2 + 1);
            }
        } else if (mood == :sugar_high) {
            var colors = [0xFF4444, 0x44FF44, 0x4444FF, 0xFFFF44, 0xFF44FF, 0x44FFFF];
            for (var i = 0; i < 6; i++) {
                var sx = cx + ((f * 7 + i * 13) % 15 - 7) * ps;
                var sy = cy + ((f * 11 + i * 17) % 11 - 5) * ps;
                dc.setColor(colors[i], colors[i]);
                dc.fillRectangle(sx, sy, ps/2 + 1, ps/2 + 1);
            }
        } else if (mood == :existential) {
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 7*ps, cy - 2*ps, Graphics.FONT_XTINY, "...", Graphics.TEXT_JUSTIFY_LEFT);
        } else if (mood == :paranoid) {
            dc.setColor(0x88FF88, Graphics.COLOR_TRANSPARENT);
            var t1 = (f % 4 < 2) ? "?" : "!";
            var t2 = (f % 4 < 2) ? "!" : "?";
            dc.drawText(cx - 7*ps, cy - 3*ps + (f % 3), Graphics.FONT_XTINY, t1, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx + 7*ps, cy - 4*ps - (f % 3), Graphics.FONT_XTINY, t2, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (mood == :feral) {
            dc.setColor(0x884422, 0x884422);
            if (f % 4 < 2) {
                for (var i = 0; i < 3; i++) {
                    dc.fillRectangle(cx - 8*ps + i * ps, cy - 3*ps - i * ps, ps/2 + 1, ps*2);
                }
            }
        } else if (mood == :party) {
            dc.setColor(0xFFDD55, Graphics.COLOR_TRANSPARENT);
            var noteY = cy - (4 + f % 3) * ps;
            dc.drawText(cx - 7*ps, noteY, Graphics.FONT_XTINY, "~", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx + 7*ps, noteY - ps, Graphics.FONT_XTINY, "~", Graphics.TEXT_JUSTIFY_CENTER);
            if (f % 3 == 0) {
                dc.setColor(0xAA88FF, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx + 4*ps, cy - 7*ps, Graphics.FONT_XTINY, "*", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    // --- Effects ---

    hidden function drawEffects(dc, w, h) {
        var act = _pet.action;
        if (act == ACT_NONE) { return; }
        var cx = w / 2;
        var ps = w / 30;
        if (ps < 3) { ps = 3; }
        var cy = h / 2;
        var f = _pet.animFrame;
        var p = ps * 3 / 4;
        if (p < 2) { p = 2; }
        var petColors = _pet.getColors(_pet.petType);

        if (act == ACT_EATING) {
            dc.setColor(0x66BB6A, 0x66BB6A);
            var d = (7 - f) * ps;
            dc.fillRectangle(cx - d - ps, cy + ps, p, p);
            dc.fillRectangle(cx + d, cy + ps, p, p);
            dc.setColor(0xA5D6A7, 0xA5D6A7);
            dc.fillRectangle(cx - d / 2, cy - ps, p / 2, p / 2);
        } else if (act == ACT_PLAYING) {
            dc.setColor(petColors[3], petColors[3]);
            dc.fillRectangle(cx - 5 * ps, cy - (2 + f) * ps, p, p);
            dc.fillRectangle(cx + 4 * ps, cy - (4 + f) * ps, p, p);
            dc.setColor(petColors[2], petColors[2]);
            dc.fillRectangle(cx - ps, cy - (3 + f) * ps, p / 2, p / 2);
            dc.fillRectangle(cx + 2 * ps, cy - (5 + f) * ps, p / 2, p / 2);
        } else if (act == ACT_SLEEPING) {
            dc.setColor(0x9999FF, Graphics.COLOR_TRANSPARENT);
            var wb = (f % 4 < 2) ? ps : -ps;
            dc.drawText(cx + 7 * ps + wb / 2, cy - 3 * ps - f * ps / 2,
                Graphics.FONT_TINY, "Z", Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(cx + 8 * ps - wb / 2, cy - 5 * ps - f * ps / 3,
                Graphics.FONT_XTINY, "z", Graphics.TEXT_JUSTIFY_LEFT);
        } else if (act == ACT_CLEANING) {
            dc.setColor(0x80DEEA, 0x80DEEA);
            var d = (f + 2) * ps;
            var s = p / 2;
            if (s < 1) { s = 1; }
            dc.fillRectangle(cx - d, cy - d / 3, s, s);
            dc.fillRectangle(cx + d, cy - d / 3, s, s);
            dc.fillRectangle(cx, cy - d, s, s);
            dc.fillRectangle(cx - d / 2, cy + d / 2, s, s);
            dc.fillRectangle(cx + d / 2, cy + d / 2, s, s);
        } else if (act == ACT_HEALING) {
            dc.setColor(0xFF80AB, 0xFF80AB);
            var y1 = cy - (3 + f) * ps;
            var y2 = cy - (5 + f) * ps;
            dc.fillRectangle(cx - 4 * ps, y1, ps, ps * 3 / 2);
            dc.fillRectangle(cx - 4 * ps - ps / 4, y1 + ps / 4, ps * 3 / 2, ps);
            dc.fillRectangle(cx + 3 * ps, y2, ps, ps * 3 / 2);
            dc.fillRectangle(cx + 3 * ps - ps / 4, y2 + ps / 4, ps * 3 / 2, ps);
        }
    }

    // --- Event bubble ---

    hidden function drawEvent(dc, w, h) {
        if (_pet.eventText.length() == 0) { return; }
        var y = h * 73 / 100;
        var bh = h * 9 / 100;
        if (bh < 18) { bh = 18; }
        var tw = dc.getTextWidthInPixels(_pet.eventText, Graphics.FONT_XTINY);
        var maxW = w * 80 / 100;
        if (tw > maxW) { tw = maxW; }
        var pad = w * 3 / 100;
        if (pad < 4) { pad = 4; }
        dc.setColor(0x1A1A33, 0x1A1A33);
        dc.fillRoundedRectangle(w / 2 - tw / 2 - pad, y, tw + pad * 2, bh, 5);

        var state = _pet.getState();
        var color = 0xDDDDDD;
        if (state == :hungry || state == :sad) { color = 0xFFAA44; }
        if (state == :desperate) { color = 0xFF5555; }
        if (state == :rage) { color = 0xFF2222; }
        if (state == :love) { color = 0xFF99CC; }
        if (state == :feral) { color = 0xCC6633; }
        if (state == :sick) { color = 0x88FF88; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y + (bh - dc.getFontHeight(Graphics.FONT_XTINY)) / 2, Graphics.FONT_XTINY, _pet.eventText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- Confirm Reset ---

    hidden function drawConfirmReset(dc, w, h) {
        var panelH = h * 22 / 100;
        var y0 = h - panelH;
        var pulse = (_pet.animFrame % 4 < 2) ? 0x1A0505 : 0x120303;
        dc.setColor(pulse, pulse);
        dc.fillRectangle(0, y0, w, panelH);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y0 + panelH * 8 / 100, Graphics.FONT_XTINY, "Delete " + _pet.petName + " forever?", Graphics.TEXT_JUSTIFY_CENTER);

        var btnH = h * 8 / 100;
        if (btnH < 18) { btnH = 18; }
        var btnW = w * 30 / 100;
        var btnY = y0 + panelH * 45 / 100;

        dc.setColor(0xFF3333, 0xFF3333);
        dc.fillRoundedRectangle(w / 2 - btnW - w * 3 / 100, btnY, btnW, btnH, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 - btnW / 2 - w * 3 / 100, btnY + (btnH - dc.getFontHeight(Graphics.FONT_XTINY)) / 2, Graphics.FONT_XTINY, "YES", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x336633, 0x336633);
        dc.fillRoundedRectangle(w / 2 + w * 3 / 100, btnY, btnW, btnH, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + btnW / 2 + w * 3 / 100, btnY + (btnH - dc.getFontHeight(Graphics.FONT_XTINY)) / 2, Graphics.FONT_XTINY, "NO", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- Dilemma ---

    hidden function drawDilemma(dc, w, h) {
        var panelH = h * 26 / 100;
        var y0 = h - panelH;
        var pulse = (_pet.animFrame % 4 < 2) ? 0 : 1;

        dc.setColor(0x110000 + pulse * 0x050000, 0x110000 + pulse * 0x050000);
        dc.fillRectangle(0, y0, w, panelH);

        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y0 + panelH * 5 / 100, Graphics.FONT_XTINY, _pet.petName + " " + _pet.dilemmaText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y0 + panelH * 30 / 100, Graphics.FONT_XTINY, "What do you do?", Graphics.TEXT_JUSTIFY_CENTER);

        var btnH = h * 8 / 100;
        if (btnH < 18) { btnH = 18; }
        var btnW = w * 34 / 100;
        var btnY = y0 + panelH * 58 / 100;

        dc.setColor(0xFF88CC, 0xFF88CC);
        dc.fillRoundedRectangle(w / 2 - btnW - w * 2 / 100, btnY, btnW, btnH, 4);
        dc.setColor(0x0F0F23, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 - btnW / 2 - w * 2 / 100, btnY + (btnH - dc.getFontHeight(Graphics.FONT_XTINY)) / 2, Graphics.FONT_XTINY, "< HUG", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFF6644, 0xFF6644);
        dc.fillRoundedRectangle(w / 2 + w * 2 / 100, btnY, btnW, btnH, 4);
        dc.setColor(0x0F0F23, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + btnW / 2 + w * 2 / 100, btnY + (btnH - dc.getFontHeight(Graphics.FONT_XTINY)) / 2, Graphics.FONT_XTINY, "PUNISH >", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- Action bar ---

    hidden function drawActionBar(dc, w, h) {
        var y = h * 85 / 100;
        var name = getActionName();
        var arrowX = w * 20 / 100;
        dc.setColor(0x333355, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 - arrowX, y + 1, Graphics.FONT_SMALL, "<", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2 + arrowX, y + 1, Graphics.FONT_SMALL, ">", Graphics.TEXT_JUSTIFY_CENTER);
        var nameColor = 0xFFFFFF;
        if (actionIdx == 5) { nameColor = 0xFF88CC; }
        if (actionIdx == 6) { nameColor = 0xFF8844; }
        if (actionIdx == 7) { nameColor = 0xFF6666; }
        if (actionIdx == 8) { nameColor = _pet.debugMode ? 0xFF8800 : 0x88AAFF; }
        dc.setColor(nameColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, Graphics.FONT_SMALL, name, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- Death screen ---

    hidden function drawDeath(dc, w, h) {
        dc.setColor(0x060610, 0x060610);
        dc.clear();

        var f = _pet.animFrame;

        dc.setColor(0x151525, 0x151525);
        for (var i = 0; i < 10; i++) {
            var rx = (w * ((i * 37 + 11) % 97)) / 100;
            var ry = ((f * 3 + i * 29) % (h + 10)) - 5;
            dc.fillRectangle(rx, ry, 1, h * 2 / 100 + 1);
        }

        drawTime(dc, w, h);

        var ps = w / 34;
        if (ps < 3) { ps = 3; }
        var ghostY = h * 34 / 100 - (f % 4);
        _pet.draw(dc, w / 2, ghostY, ps);

        var ripPulse = (f % 4 < 2) ? 0xFF4444 : 0xFF6666;
        dc.setColor(ripPulse, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 50 / 100, Graphics.FONT_LARGE, "R.I.P.", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_TINY, _pet.getDeathAgeString(), Graphics.TEXT_JUSTIFY_CENTER);

        if (_pet.careStreak > 1) {
            dc.setColor(0x555577, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 71 / 100, Graphics.FONT_XTINY, "Streak: " + _pet.careStreak + " days", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x666688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY, "SELECT: New Pet", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
