using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;

enum {
    STATE_ASK,
    STATE_SHAKE,
    STATE_ANIM,
    STATE_ANSWER
}

class Bitochi8BallView extends WatchUi.View {

    var state;
    hidden var _answer;
    hidden var _answerCat;
    hidden var _animTick;
    hidden var _timer;
    hidden var _answers;
    hidden var _ansCats;
    hidden var _streak;
    hidden var _ansPhase;
    hidden var _fc;
    hidden var _vibed;
    hidden var _w;
    hidden var _h;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        state = STATE_ASK;
        _answer = "";
        _answerCat = 0;
        _animTick = 0;
        _streak = 0;
        _ansPhase = 0;
        _fc = 0;
        _vibed = false;
        _w = 260;
        _h = 260;

        _answers = [
            "Yes!", "No.", "Absolutely!", "No way.",
            "Hell yeah!", "Hell no!", "Obviously.", "Nope.",
            "100%!", "Never.", "Definitely!", "Doubtful.",
            "Count on it.", "Don't bet on it.",
            "For sure.", "Not a chance.",
            "You bet!", "LOL no.",
            "Oh yes.", "Oh no.",
            "Yep!", "Nah.",
            "Duh!", "Bruh. No.",
            "Go for it!", "Bad idea.",
            "Send it!", "Hard pass.",
            "Yes, legend!", "Denied.",
            "Stars say yes.", "Stars say no.",
            "Big yes!", "Big no.",
            "It is certain.", "Very doubtful.",
            "Signs say yes.", "Signs say no.",
            "Ask later.", "Try again.",
            "Maybe...", "Who knows?",
            "Unclear.", "Hazy.",
            "Concentrate.", "Not now.",
            "Ask your mom.", "Ask Google.",
            "Bold. No.", "Bold. Yes!",
            "YEET!", "Nope nope.",
            "Certified yes.", "Cosmic no.",
            "In your dreams!", "Fate says yes.",
            "Error 404.", "No comment.",
            "Vibes say yes.", "Vibes say no.",
            "Plot twist: yes", "Plot twist: no",
            "Epic yes!", "Cringe. No.",
            "Full send!", "Void says no.",
            "Affirmative.", "Negative.",
            "Yasss!", "Naaah.",
            "Without doubt.", "With all doubt.",
            "Trust me, yes.", "Trust me, no.",
            "Green light.", "Red light.",
            "Winner!", "Loser move.",
            "Approved.", "Rejected.",
            "Lucky you!", "Unlucky.",
            "Oracle nods.", "Oracle laughs.",
            "Champion!", "Villain arc.",
            "Main character!", "Side quest.",
            "Critical yes!", "Critical fail.",
            "Destiny: yes.", "Destiny: nope.",
            "Golden!", "Dark answer.",
            "Pure fire!", "Cold ice.",
            "Legendary!", "Tragic no."
        ];

        _ansCats = [
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1,
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1,
            0, 1, 0, 1, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3,
            3, 3, 0, 1, 0, 1, 1, 0, 2, 3, 0, 1, 0, 1, 0, 1,
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1,
            0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1,
            0, 1, 0, 1
        ];
    }

    hidden function doVibe() {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(50, 200)]);
            }
        }
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 50, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _fc++;
        if (state == STATE_ANIM) {
            _animTick++;
            if (_animTick >= 35) {
                state = STATE_ANSWER;
                _ansPhase = 0;
                _vibed = false;
            }
        }
        if (state == STATE_ANSWER) {
            if (_ansPhase < 20) { _ansPhase++; }
            if (!_vibed && _ansPhase >= 3) {
                doVibe();
                _vibed = true;
            }
        }
        WatchUi.requestUpdate();
    }

    function shake() {
        if (state == STATE_ASK || state == STATE_SHAKE) {
            state = STATE_ANIM;
            _animTick = 0;
            _streak++;
            var idx = Math.rand().abs() % _answers.size();
            _answer = _answers[idx];
            _answerCat = (idx < _ansCats.size()) ? _ansCats[idx] : 2;
            doVibe();
        } else if (state == STATE_ANSWER) {
            state = STATE_SHAKE;
            _answer = "";
            _ansPhase = 0;
            _vibed = false;
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var w = _w;
        var h = _h;

        drawBackground(dc, w, h);

        if (state == STATE_ASK) {
            drawBilliardBall(dc, w / 2, h * 36 / 100, w * 30 / 100);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 68 / 100, Graphics.FONT_SMALL, "Ask me", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x88AA88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY, "shake or tap", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (state == STATE_SHAKE) {
            drawBilliardBall(dc, w / 2, h * 36 / 100, w * 30 / 100);
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 68 / 100, Graphics.FONT_SMALL, "Ask again!", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x88AA88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY, "shake or tap", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (state == STATE_ANIM) {
            drawAnimScene(dc, w, h);
        } else {
            drawAnswerScene(dc, w, h);
        }

        if (_streak > 0) {
            dc.setColor(0x446644, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, 4, Graphics.FONT_XTINY, "#" + _streak, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawBackground(dc, w, h) {
        dc.setColor(0x0A2A12, 0x0A2A12);
        dc.clear();

        dc.setColor(0x0D3316, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, h / 2, w * 48 / 100);
        dc.setColor(0x103D1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, h / 2, w * 40 / 100);
        dc.setColor(0x13461E, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, h / 2, w * 30 / 100);

        dc.setColor(0x082008, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(w / 2, h / 2, w * 48 / 100);
        dc.drawCircle(w / 2, h / 2, w * 49 / 100);

        var feltSeed = 42;
        dc.setColor(0x0B2E10, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 30; i++) {
            var fx = ((feltSeed + i * 97) % w);
            var fy = ((feltSeed + i * 53) % h);
            dc.fillRectangle(fx, fy, 1, 1);
        }
    }

    hidden function drawBilliardBall(dc, cx, cy, r) {
        if (r < 6) { r = 6; }

        dc.setColor(0x050A05, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 3, cy + 4, r + 3);
        dc.fillCircle(cx + 2, cy + 3, r + 2);

        dc.setColor(0x0A0A0A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r + 1);

        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);

        dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 12, cy - r / 12, r * 92 / 100);

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 8, cy - r / 8, r * 82 / 100);

        dc.setColor(0x2C2C2C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 6, cy - r / 6, r * 70 / 100);

        dc.setColor(0x363636, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 5, cy - r / 5, r * 55 / 100);

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 4, cy - r / 4, r * 40 / 100);

        dc.setColor(0x585858, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r * 28 / 100, cy - r * 28 / 100, r * 28 / 100);

        dc.setColor(0x707070, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r * 30 / 100, cy - r * 30 / 100, r * 18 / 100);

        dc.setColor(0x909090, Graphics.COLOR_TRANSPARENT);
        var hr = r * 12 / 100;
        if (hr < 2) { hr = 2; }
        dc.fillCircle(cx - r * 32 / 100, cy - r * 32 / 100, hr);

        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        var pr = r * 7 / 100;
        if (pr < 2) { pr = 2; }
        dc.fillCircle(cx - r * 33 / 100, cy - r * 33 / 100, pr);

        dc.setColor(0xEEEEEE, Graphics.COLOR_TRANSPARENT);
        var pp = r * 4 / 100;
        if (pp < 1) { pp = 1; }
        dc.fillCircle(cx - r * 34 / 100, cy - r * 34 / 100, pp);

        dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
        var rr2 = r * 5 / 100;
        if (rr2 < 1) { rr2 = 1; }
        dc.fillCircle(cx + r * 22 / 100, cy + r * 26 / 100, rr2);

        dc.setColor(0x161616, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            var a = 100 + i * 180 / 12;
            var rad = a * 3.14159 / 180.0;
            var rx = cx + ((r + 1) * Math.cos(rad)).toNumber();
            var ry = cy + ((r + 1) * Math.sin(rad)).toNumber();
            dc.fillRectangle(rx, ry, 1, 1);
        }

        drawEightCircle(dc, cx, cy, r);
    }

    hidden function drawEightCircle(dc, cx, cy, r) {
        var wr = r * 42 / 100;
        if (wr < 5) { wr = 5; }

        dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, wr + 2);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, wr);

        dc.setColor(0xF0F0F0, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 1, cy + 1, wr - 1);

        dc.setColor(0xE8E8E8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + wr / 4, cy + wr / 4, wr * 6 / 10);

        dc.setColor(0xF4F4F4, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - wr / 5, cy - wr / 5, wr * 4 / 10);

        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        var fs = Graphics.FONT_MEDIUM;
        if (wr < 12) { fs = Graphics.FONT_XTINY; }
        else if (wr < 18) { fs = Graphics.FONT_TINY; }
        else if (wr < 26) { fs = Graphics.FONT_SMALL; }
        dc.drawText(cx, cy - dc.getFontHeight(fs) / 2, fs, "8", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, wr + 1);
    }

    hidden function drawAnimScene(dc, w, h) {
        var cx = w / 2;
        var cy = h * 38 / 100;
        var ph = _animTick;

        var offX = 0;
        if (ph < 14) {
            offX = ((ph % 4 < 2) ? 1 : -1) * (3 + ph / 3);
        }
        var offY = 0;
        if (ph < 14) {
            offY = ((ph % 3 < 1) ? 1 : -1) * (ph / 4);
        }

        var baseR = w * 28 / 100;
        var r = baseR;

        if (ph >= 14 && ph < 28) {
            var sc = ph - 14;
            r = baseR + sc * w / 160;
        } else if (ph >= 28) {
            r = baseR + 14 * w / 160;
        }

        drawBilliardBall(dc, cx + offX, cy + offY, r);

        if (ph >= 18) {
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            var dots = (ph - 18) / 3;
            if (dots > 3) { dots = 3; }
            var txt = "";
            for (var k = 0; k < dots + 1; k++) { txt = txt + "."; }
            dc.drawText(cx, h * 75 / 100, Graphics.FONT_SMALL, txt, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x88AA88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 75 / 100, Graphics.FONT_SMALL, "...", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawAnswerScene(dc, w, h) {
        var cx = w / 2;
        var cy = h * 30 / 100;
        var r = w * 28 / 100;

        var gc = catColor();
        var pulse = (_fc % 20);
        if (pulse > 10) { pulse = 20 - pulse; }
        var glowAlpha = pulse;

        for (var ring = 2; ring > 0; ring--) {
            var rr = r + ring * 4 + glowAlpha / 2;
            var rc = blendColor(gc, 0x0A2A12, ring, 3);
            dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, rr);
        }

        drawBilliardBall(dc, cx, cy, r);

        var ansY = h * 62 / 100;
        var fade = _ansPhase;
        if (fade > 16) { fade = 16; }

        var fs = Graphics.FONT_SMALL;
        if (_answer.length() > 18) { fs = Graphics.FONT_TINY; }
        if (_answer.length() > 26) { fs = Graphics.FONT_XTINY; }

        if (fade >= 4) {
            var shadowC = blendColor(gc, 0x000000, 3, 4);
            dc.setColor(shadowC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 1, ansY + 1, fs, _answer, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (fade >= 2) {
            var fg = 0xFFFFFF;
            if (fade < 8) {
                fg = blendColor(0x446644, 0xFFFFFF, fade, 8);
            }
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ansY, fs, _answer, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x557755, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 88 / 100, Graphics.FONT_XTINY, "tap to ask", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function catColor() {
        if (_answerCat == 0) { return 0x33DD66; }
        if (_answerCat == 1) { return 0xDD3344; }
        if (_answerCat == 2) { return 0x8855CC; }
        return 0xDDAA22;
    }

    hidden function blendColor(c1, c2, t, m) {
        if (t <= 0) { return c1; }
        if (t >= m) { return c2; }
        var r1 = (c1 >> 16) & 0xFF;
        var g1 = (c1 >> 8) & 0xFF;
        var b1 = c1 & 0xFF;
        var r2 = (c2 >> 16) & 0xFF;
        var g2 = (c2 >> 8) & 0xFF;
        var b2 = c2 & 0xFF;
        var rr = r1 + (r2 - r1) * t / m;
        var gg = g1 + (g2 - g1) * t / m;
        var bb = b1 + (b2 - b1) * t / m;
        return (rr << 16) | (gg << 8) | bb;
    }
}
