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
    hidden var _starX;
    hidden var _starY;
    hidden var _starSpd;
    hidden var _answers;
    hidden var _ansCats;
    hidden var _streak;
    hidden var _ansPhase;
    hidden var _fc;
    hidden var _vibed;

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

        _starX = new [50];
        _starY = new [50];
        _starSpd = new [50];
        for (var i = 0; i < 50; i++) {
            _starX[i] = Math.rand().abs() % 1000;
            _starY[i] = Math.rand().abs() % 1000;
            _starSpd[i] = 1 + (Math.rand().abs() % 3);
        }

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
            "Plot twist: yes.", "Plot twist: no.",
            "Epic yes!", "Cringe. No.",
            "Full send!", "Void says no.",
            "Affirmative.", "Negative.",
            "The answer is yes.", "The answer is no.",
            "Yasss!", "Naaah.",
            "Without doubt.", "With all doubt.",
            "Trust me, yes.", "Trust me, no.",
            "Green light.", "Red light.",
            "Winner!", "Loser move.",
            "Approved.", "Rejected.",
            "Lucky you!", "Unlucky.",
            "The oracle nods.", "The oracle laughs.",
            "Champion vibes.", "Villain arc: no.",
            "Main character!", "Side quest: no.",
            "Critical yes!", "Critical fail.",
            "Destiny: yes.", "Destiny: nope.",
            "Golden answer!", "Dark answer.",
            "Pure fire!", "Cold ice. No.",
            "Legendary yes!", "Tragic no."
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
            if (_animTick >= 40) {
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
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x050510, 0x050510);
        dc.clear();

        drawStars(dc, w, h);

        if (state == STATE_ASK) {
            drawBall3D(dc, w / 2, h * 38 / 100, w * 28 / 100);
            drawWindow(dc, w / 2, h * 38 / 100, w * 28 / 100);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 65 / 100, Graphics.FONT_SMALL, "Ask me", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x667788, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_XTINY, "shake or tap", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (state == STATE_SHAKE) {
            drawBall3D(dc, w / 2, h * 38 / 100, w * 28 / 100);
            drawWindow(dc, w / 2, h * 38 / 100, w * 28 / 100);
            dc.setColor(0x44DDFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 65 / 100, Graphics.FONT_SMALL, "Ask again", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_XTINY, "shake or tap", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (state == STATE_ANIM) {
            drawAnimScene(dc, w, h);
        } else {
            drawAnswerScene(dc, w, h);
        }

        if (_streak > 0) {
            dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, 4, Graphics.FONT_XTINY, "#" + _streak, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawStars(dc, w, h) {
        for (var i = 0; i < 50; i++) {
            var sx = (_starX[i] * w / 1000 + _fc * _starSpd[i] / 2) % w;
            var sy = (_starY[i] * h / 1000 + _fc * _starSpd[i] / 3) % h;
            var bri = 0x222233 + (i * 23 % 0x444455);
            dc.setColor(bri, Graphics.COLOR_TRANSPARENT);
            var sz = (i % 4 == 0) ? 2 : 1;
            dc.fillRectangle(sx, sy, sz, sz);
        }
    }

    hidden function drawAnimScene(dc, w, h) {
        var cx = w / 2;
        var cy = h * 40 / 100;
        var ph = _animTick;

        var offX = 0;
        if (ph < 16) {
            offX = ((ph % 4 < 2) ? 1 : -1) * (4 + ph / 2);
        }

        var baseR = w * 24 / 100;
        var r = baseR;
        if (ph >= 14) {
            var grow = ph - 14;
            if (grow > 20) { grow = 20; }
            r = baseR + grow * w / 100;
        }

        drawBall3D(dc, cx + offX, cy, r);

        if (ph >= 12 && ph < 36) {
            var ringR = r + 8 + (ph - 12) * 2;
            for (var i = 0; i < 10; i++) {
                var a = (i * 36 + ph * 15) % 360;
                var rad = a * 3.14159 / 180.0;
                var sx = cx + offX + (ringR * Math.cos(rad)).toNumber();
                var sy = cy + (ringR * Math.sin(rad)).toNumber();
                var c = (i % 3 == 0) ? 0xFF66FF : ((i % 3 == 1) ? 0x66FFFF : 0xFFFF66);
                dc.setColor(c, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(sx - 1, sy - 1, 3, 3);
            }
        }

        if (ph < 18) {
            dc.setColor(0x44AADD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 75 / 100, Graphics.FONT_SMALL, "...", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (ph < 30) {
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            var n = ph - 17;
            if (n > 5) { n = 5; }
            var d = "";
            for (var k = 0; k < n; k++) { d = d + "."; }
            dc.drawText(cx, h * 75 / 100, Graphics.FONT_SMALL, d, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawAnswerScene(dc, w, h) {
        var cx = w / 2;
        var cy = h * 32 / 100;
        var r = w * 30 / 100;

        var gc = catColor();
        var pulse = (_fc % 16);
        if (pulse > 8) { pulse = 16 - pulse; }
        for (var ring = 3; ring > 0; ring--) {
            var rr = r + ring * 5 + pulse;
            var alpha = 3 - ring;
            var rc = blend(gc, 0x050510, alpha, 4);
            dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, rr);
            dc.drawCircle(cx, cy, rr + 1);
        }

        drawBall3D(dc, cx, cy, r);
        drawWindow(dc, cx, cy, r);

        var ansY = h * 60 / 100;
        var fade = _ansPhase;
        if (fade > 16) { fade = 16; }

        var fs = Graphics.FONT_SMALL;
        if (_answer.length() > 20) { fs = Graphics.FONT_TINY; }
        if (_answer.length() > 28) { fs = Graphics.FONT_XTINY; }

        if (fade >= 4) {
            var glow = blend(gc, 0x000000, 2, 3);
            dc.setColor(glow, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - 1, ansY, fs, _answer, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx + 1, ansY, fs, _answer, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, ansY - 1, fs, _answer, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, ansY + 1, fs, _answer, Graphics.TEXT_JUSTIFY_CENTER);
        }

        var fg = (fade >= 6) ? blend(0xFFFFFF, gc, fade, 20) : 0x333333;
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ansY, fs, _answer, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 88 / 100, Graphics.FONT_XTINY, "tap to ask", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function catColor() {
        if (_answerCat == 0) { return 0x33FF88; }
        if (_answerCat == 1) { return 0xFF3355; }
        if (_answerCat == 2) { return 0xAA66FF; }
        return 0xFFBB33;
    }

    hidden function blend(c1, c2, t, m) {
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

    // Premium 3D shaded billiard ball
    hidden function drawBall3D(dc, cx, cy, r) {
        if (r < 4) { r = 4; }

        // ambient shadow under ball
        dc.setColor(0x0A0A18, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 2, cy + 3, r + 2);

        // outer rim - darkest edge
        dc.setColor(0x0C0C0C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r + 1);

        // base sphere - very dark
        dc.setColor(0x101010, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);

        // layered gradient shading: bottom-right is darkest, top-left is brightest
        // layer 1: large off-center fill (slight upper-left bias for light source)
        dc.setColor(0x141414, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 10, cy - r / 10, r * 9 / 10);

        dc.setColor(0x181818, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 7, cy - r / 7, r * 8 / 10);

        dc.setColor(0x1D1D1D, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 5, cy - r / 5, r * 7 / 10);

        dc.setColor(0x232323, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 4, cy - r / 4, r * 6 / 10);

        dc.setColor(0x2A2A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r * 3 / 10, cy - r * 3 / 10, r * 5 / 10);

        dc.setColor(0x323232, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r * 3 / 10, cy - r * 3 / 10, r * 4 / 10);

        dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 3, cy - r / 3, r * 3 / 10);

        // specular highlight - main (large, diffuse)
        dc.setColor(0x484848, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 3, cy - r / 3, r * 22 / 100);

        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 3, cy - r / 3, r * 16 / 100);

        // specular highlight - bright core
        dc.setColor(0x6A6A6A, Graphics.COLOR_TRANSPARENT);
        var hr = r * 10 / 100;
        if (hr < 2) { hr = 2; }
        dc.fillCircle(cx - r / 3, cy - r / 3, hr);

        // specular pinpoint (white hot spot)
        dc.setColor(0x8A8A8A, Graphics.COLOR_TRANSPARENT);
        var pr = r * 5 / 100;
        if (pr < 1) { pr = 1; }
        dc.fillCircle(cx - r * 35 / 100, cy - r * 35 / 100, pr);

        // tiny secondary highlight (bottom-left rim light)
        dc.setColor(0x1E1E1E, Graphics.COLOR_TRANSPARENT);
        var sr = r * 6 / 100;
        if (sr < 1) { sr = 1; }
        dc.fillCircle(cx + r * 25 / 100, cy + r * 30 / 100, sr);

        // subtle edge rim at bottom for 3D pop
        var rimSteps = 8;
        for (var i = 0; i < rimSteps; i++) {
            var a = 110 + i * 160 / rimSteps;
            var rad = a * 3.14159 / 180.0;
            var rx = cx + (r * Math.cos(rad)).toNumber();
            var ry = cy + (r * Math.sin(rad)).toNumber();
            var rimC = 0x181818;
            if (i > rimSteps / 3 && i < rimSteps * 2 / 3) { rimC = 0x1C1C1C; }
            dc.setColor(rimC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rx, ry, 2, 2);
        }
    }

    // "8" window on the ball
    hidden function drawWindow(dc, cx, cy, r) {
        var ws = r * 45 / 100;
        if (ws < 5) { ws = 5; }

        // window outline
        dc.setColor(0x000044, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ws + 2);

        // window background gradient
        dc.setColor(0x000077, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ws + 1);

        dc.setColor(0x000099, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ws);

        dc.setColor(0x0000AA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ws - 1);

        dc.setColor(0x000088, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 1, cy + 1, ws - 2);

        // inner glow at top-left of window
        dc.setColor(0x0022BB, Graphics.COLOR_TRANSPARENT);
        var igr = ws * 4 / 10;
        if (igr < 2) { igr = 2; }
        dc.fillCircle(cx - ws / 4, cy - ws / 4, igr);

        // "8" number
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var fs = Graphics.FONT_MEDIUM;
        if (ws < 10) { fs = Graphics.FONT_XTINY; }
        else if (ws < 16) { fs = Graphics.FONT_TINY; }
        else if (ws < 24) { fs = Graphics.FONT_SMALL; }
        dc.drawText(cx, cy - dc.getFontHeight(fs) / 2, fs, "8", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
