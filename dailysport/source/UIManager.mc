// ═══════════════════════════════════════════════════════════════════════════
// UIManager.mc — Everything the player reads: briefing, HUD, meters, result.
//
// Layout is derived from dc.getFontHeight() and screen percentages rather than
// fixed pixel offsets, so the same code reads correctly on a 208 px vívoactive
// and a 416 px fēnix, and nothing spills past the round chords.
//
// The controls live on one bar at the bottom of the court. Whatever beat of
// the shot you are on, that bar is what you are acting against — and after the
// shot the same strip tells you why it went in or out.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;

module UIManager {

    // ── Text helpers ────────────────────────────────────────────────────────
    function words(s as Lang.String) as Lang.Array {
        var out = []; var cur = "";
        for (var i = 0; i < s.length(); i++) {
            var chr = s.substring(i, i + 1);
            if (chr.equals(" ")) { if (cur.length() > 0) { out.add(cur); cur = ""; } }
            else { cur = cur + chr; }
        }
        if (cur.length() > 0) { out.add(cur); }
        return out;
    }

    function wrap(dc, text as Lang.String, maxW as Lang.Number,
                  font) as Lang.Array {
        var ws = words(text); var lines = []; var cur = "";
        for (var i = 0; i < ws.size(); i++) {
            var cand = (cur.length() == 0) ? ws[i] : cur + " " + ws[i];
            if (cur.length() == 0 ||
                dc.getTextWidthInPixels(cand, font) <= maxW) { cur = cand; }
            else { lines.add(cur); cur = ws[i]; }
        }
        if (cur.length() > 0) { lines.add(cur); }
        return lines;
    }

    // ── Briefing card ───────────────────────────────────────────────────────
    // Shown before every run: what the world is playing today, how many ranked
    // attempts your day has earned you, and what you have to beat.
    function drawBrief(dc, w as Lang.Number, h as Lang.Number, eng) as Void {
        var cx  = w / 2;
        var VC  = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var fhX = dc.getFontHeight(Graphics.FONT_XTINY);
        var fhS = dc.getFontHeight(Graphics.FONT_SMALL);
        var ch  = eng.ch;

        dc.setColor(DS_BG, DS_BG);
        dc.clear();
        if (w == h) {
            dc.setColor(DS_INSET, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawCircle(cx, h / 2, w / 2 - 3);
            dc.setPenWidth(1);
        }

        // The sport is the headline, because it is the thing that changed
        // overnight; the objective is the subtitle under it. Practice can be
        // on a different sport entirely, so the name comes off the sport that
        // is actually loaded rather than off the calendar.
        var y = (h * 11) / 100 + fhX / 2;
        dc.setColor(DS_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY,
                    eng.ranked ? "TODAY'S SPORT" : "PRACTICE", VC);

        y = y + fhX / 2 + fhS / 2 + 2;
        dc.setColor(DS_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL, eng.sport.name(), VC);

        y = y + fhS / 2 + fhX / 2;
        dc.setColor(DS_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, ch.objectiveName(), VC);

        // The brief itself. Two lines: the sport and the objective above it
        // have already taken the room the third one used to have.
        var maxW  = (w == h) ? (w * 74) / 100 : (w * 88) / 100;
        var lines = wrap(dc, ch.label(), maxW, Graphics.FONT_XTINY);
        y = y + fhX / 2;
        dc.setColor(DS_TEXT, Graphics.COLOR_TRANSPARENT);
        var n = lines.size(); if (n > 2) { n = 2; }
        for (var i = 0; i < n; i++) {
            y = y + fhX * 82 / 100;
            dc.drawText(cx, y, Graphics.FONT_XTINY, lines[i], VC);
        }

        // Energy pips = ranked attempts left today (fitness tops these up).
        var left = ProgressionManager.energyLeft();
        var max  = ProgressionManager.energyMax();
        y = y + fhX * 80 / 100;
        var pipR = h * 2 / 100; if (pipR < 3) { pipR = 3; }
        var step = pipR * 3;
        var x0   = cx - (max - 1) * step / 2;
        for (var i = 0; i < max; i++) {
            if (i < left) { dc.setColor(DS_GREEN, Graphics.COLOR_TRANSPARENT);
                            dc.fillCircle(x0 + i * step, y, pipR); }
            else          { dc.setColor(DS_EDGE, Graphics.COLOR_TRANSPARENT);
                            dc.drawCircle(x0 + i * step, y, pipR); }
        }

        // The two numbers that pull people back: today's best and yesterday's.
        y = y + pipR + fhX * 70 / 100;
        var stat = "BEST " + ProgressionManager.todayBest().toString();
        var yd = ProgressionManager.yesterday();
        if (yd > 0) { stat = stat + "   YDAY " + yd.toString(); }
        var sd = ProgressionManager.streakDays();
        if (sd > 0) { stat = stat + "   " + sd.toString() + "d"; }
        dc.setColor(DS_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, stat, VC);

        // Footer, in priority order: what a chosen-but-unearned skin costs,
        // then the practice warning, then today's fitness read-out.
        var foot = ProgressionManager.lockHint();
        var col  = DS_GOLD;
        if (foot.length() == 0) {
            foot = (left > 0) ? FitnessIntegration.summary()
                              : "no energy - practice only";
            col  = (left > 0) ? DS_GREEN : DS_GOLD;
        }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - fhX, Graphics.FONT_XTINY, foot, VC);
    }

    // ── In-play HUD ─────────────────────────────────────────────────────────
    // The clock is the bezel itself: a ring that empties as the run does. It
    // costs one draw call, never collides with the court, and is readable from
    // the corner of the eye while the player is watching the ball.
    function drawClockRing(dc, w as Lang.Number, h as Lang.Number, eng) as Void {
        if (!eng.ranked || eng.ch.timeMs <= 0) { return; }
        var f = eng.timeLeft.toFloat() / eng.ch.timeMs;
        if (f < 0.0) { f = 0.0; }
        if (f > 1.0) { f = 1.0; }

        var col = DS_GREEN;
        if (f < 0.45) { col = DS_GOLD; }
        if (f < 0.20) { col = DS_RED; }

        var r = ((w < h ? w : h) / 2) - 3;
        dc.setPenWidth(4);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(w / 2, h / 2, r);
        if (f > 0.004) {
            var end = 90 - (359.0 * f).toNumber();
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(w / 2, h / 2, r, Graphics.ARC_CLOCKWISE, 90, end);
        }
        dc.setPenWidth(1);
    }

    function drawHud(dc, w as Lang.Number, h as Lang.Number, eng) as Void {
        var cx  = w / 2;
        var VC  = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var fhX = dc.getFontHeight(Graphics.FONT_XTINY);

        // Objective, then the number the whole run is about.
        // Just the objective up here: which sport it is, the field is already
        // saying at a glance.
        var head = eng.ranked ? eng.ch.objectiveName() : "PRACTICE";
        if (eng.ranked) {
            var secs = eng.secondsLeft();
            head = head + "  " + secs.toString() + "s";
        }
        dc.setColor(eng.ranked && eng.secondsLeft() <= 10 ? DS_RED : DS_DIM,
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 75) / 1000 + fhX / 2, Graphics.FONT_XTINY, head, VC);

        var scoreY = (h * 19) / 100;
        var big    = Graphics.FONT_NUMBER_MILD;
        var fhN    = dc.getFontHeight(big);
        dc.setColor(eng.beatTarget() ? DS_GREEN : DS_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, scoreY, big, eng.score.toString(), VC);

        // Target, hung off the big number so progress is always in frame.
        if (eng.ranked) {
            var tw = dc.getTextWidthInPixels(eng.score.toString(), big);
            dc.setColor(DS_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + tw / 2 + 4, scoreY + fhN / 6, Graphics.FONT_XTINY,
                        "/" + eng.ch.target.toString(),
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Live streak beads: the streak challenge, and the fire under a run.
        var cnt = eng.streakNow; if (cnt > 7) { cnt = 7; }
        if (cnt > 0) {
            var pr = h * 16 / 1000; if (pr < 2) { pr = 2; }
            var sx = cx - (cnt - 1) * pr * 3 / 2;
            var y  = scoreY + fhN / 2 + pr;
            for (var i = 0; i < cnt; i++) {
                dc.setColor(i >= 2 ? DS_ACCENT : DS_GOLD, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(sx + i * pr * 3, y, pr);
            }
        }
    }

    // ── Control bar ─────────────────────────────────────────────────────────
    // One strip, three jobs: read the angle, set the power, hit the release.
    function drawMeter(dc, w as Lang.Number, h as Lang.Number, eng) as Void {
        var cx  = w / 2;
        var VC  = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        var barW = (w * 44) / 100;
        var barX = cx - barW / 2;
        var barH = (h * 45) / 1000; if (barH < 7) { barH = 7; }
        var barY = (h * 88) / 100;
        var lblY = (h * 795) / 1000;

        var label = "";
        var col   = DS_TEXT;

        if (eng.state == DS_ST_AIM) {
            label = "ANGLE  " + eng.angle.toNumber().toString() + "\u00B0";
            col   = DS_GOLD;
            // The meter spans the sport's own aim band, so a full sweep is a
            // full sweep whether the day is a chip or a free kick.
            var lo   = eng.sport.aimMin();
            var span = eng.aimSpan();
            var ghost = (eng.goodAngle < 0.0) ? -1.0 : (eng.goodAngle - lo) / span;
            _bar(dc, barX, barY, barW, barH, (eng.angle - lo) / span,
                 DS_GOLD, -1.0, 0.0, ghost);
        } else if (eng.state == DS_ST_POWER) {
            label = "POWER  " + (eng.power * 100.0).toNumber().toString() + "%";
            col   = DS_ACCENT;
            _bar(dc, barX, barY, barW, barH, eng.power, DS_ACCENT, -1.0, 0.0,
                 eng.goodPower);
        } else if (eng.state == DS_ST_RELEASE) {
            label = eng.sport.actionWord() + "!";
            col   = DS_GREEN;
            _bar(dc, barX, barY, barW, barH, 0.0, DS_GREEN,
                 eng.relT, DS_RELEASE_DEAD / 2.0, -1.0);
        } else if (eng.state == DS_ST_FEEDBACK) {
            label = eng.outcomeHint();
            col   = DS_DIM;
        } else {
            return;
        }

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, lblY, Graphics.FONT_XTINY, label, VC);
    }

    // `fill` draws a proportional fill; `marker` >= 0 draws a sweeping needle
    // with a highlighted sweet band of half-width `dead` around the centre;
    // `ghost` >= 0 chalks the setting that last went in, so the player is
    // aiming at their own best shot rather than at nothing.
    function _bar(dc, x, y, bw, bh, fill as Lang.Float, col as Lang.Number,
                  marker as Lang.Float, dead as Lang.Float,
                  ghost as Lang.Float) as Void {
        dc.setColor(DS_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, bw, bh, 3);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i < 4; i++) {
            dc.fillRectangle(x + (bw * i) / 4, y + bh / 3, 1, bh / 3);
        }

        if (dead > 0.0) {
            var dw = (bw * dead * 2).toNumber(); if (dw < 4) { dw = 4; }
            dc.setColor(0x005500, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + bw / 2 - dw / 2, y, dw, bh);
            dc.setColor(DS_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + bw / 2 - dw / 2, y, 1, bh);
            dc.fillRectangle(x + bw / 2 + dw / 2, y, 1, bh);
        }
        if (fill > 0.0) {
            var fw = (bw * fill).toNumber();
            if (fw > bw) { fw = bw; }
            if (fw > 2) {
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x, y, fw, bh, 3);
                // Gloss line: one row of highlight turns a block into a meter.
                dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + 2, y + 1, fw - 4, 1);
            }
        }
        if (ghost >= 0.0) {
            var gx = x + (bw * ghost).toNumber();
            if (gx > x + bw - 1) { gx = x + bw - 1; }
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(gx, y - 4, 1, bh + 8);
            dc.fillRectangle(gx - 2, y - 6, 5, 2);
        }
        if (marker >= 0.0) {
            var mx = x + (bw * marker).toNumber();
            if (mx > x + bw - 2) { mx = x + bw - 2; }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(mx - 1, y - 3, 3, bh + 6);
        }
        dc.setColor(DS_EDGE, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, bw, bh, 3);
    }

    // ── Shot outcome flash ──────────────────────────────────────────────────
    // Called out on a banner rather than as loose text: it has to punch
    // through a lit arena or a sand court without becoming unreadable.
    function drawFeedback(dc, w as Lang.Number, h as Lang.Number, eng) as Void {
        if (eng.state != DS_ST_FEEDBACK) { return; }
        var VC   = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var text = eng.outcomeText();
        var col  = eng.outcomeColor();
        var fhS  = dc.getFontHeight(Graphics.FONT_SMALL);
        var tw   = dc.getTextWidthInPixels(text, Graphics.FONT_SMALL) + 16;
        var y    = (h * 33) / 100;

        dc.setColor(DS_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(w / 2 - tw / 2, y - fhS / 2, tw, fhS, 4);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(w / 2 - tw / 2, y - fhS / 2, tw, fhS, 4);
        dc.drawText(w / 2, y, Graphics.FONT_SMALL, text, VC);
    }

    // ── Run summary ─────────────────────────────────────────────────────────
    // The card the whole loop is built around: where you landed, what you have
    // to beat, and what drops tomorrow.
    function drawResult(dc, w as Lang.Number, h as Lang.Number, eng) as Void {
        var ch    = eng.ch;
        var lines = [];

        lines.add([eng.score.toString() + " " + ch.unit(),
                   eng.beatTarget() ? DS_GREEN : DS_TEXT]);

        if (eng.ranked) {
            var best = ProgressionManager.todayBest();
            var newBest = (eng.result != null && eng.result["newBest"] == true);
            lines.add([(newBest ? "NEW BEST " : "BEST ") + best.toString(),
                       newBest ? DS_GOLD : DS_DIM]);
            var streak = ProgressionManager.streakDays();
            lines.add(["STREAK " + streak.toString() + "d   " +
                       ProgressionManager.trophy(), DS_DIM]);
        } else {
            lines.add([eng.made.toString() + " of " + eng.attempts.toString() +
                       " made", DS_DIM]);
            lines.add(["practice - not ranked", DS_DIM]);
        }

        // Celebrate an unlock, otherwise point at tomorrow.
        var tail = "TOMORROW: " + ChallengeManager.tomorrowName();
        var tailCol = DS_DIM;
        if (eng.result != null) {
            var un = eng.result["unlocked"];
            if (un instanceof Lang.Array && un.size() > 0) {
                tail = "UNLOCKED " + un[0];
                tailCol = DS_GOLD;
            }
        }
        lines.add([tail, tailCol]);

        var title = eng.ranked
            ? (eng.completed ? "TODAY'S RESULT" : "RUN ENDED")
            : "PRACTICE";
        GameOverCard.draw(dc, w, h, title,
                          eng.completed ? DS_ACCENT : DS_DIM,
                          lines,
                          eng.submitted ? "ranking..." : "tap to close",
                          eng.completed ? DS_ACCENT : DS_EDGE);
    }
}
