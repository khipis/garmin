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

class BallView extends WatchUi.View {

    var state;
    hidden var _answer;
    hidden var _animTick;
    hidden var _timer;
    hidden var _sparkles;

    hidden var _answers;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        state = STATE_ASK;
        _answer = "";
        _animTick = 0;
        _sparkles = new [8];

        _answers = [
            "Yes.", "No.", "Absolutely!", "No way.",
            "It is certain.", "Don't count on it.",
            "Without a doubt.", "My sources say no.",
            "Yes, definitely!", "Very doubtful.",
            "You may rely on it.", "Outlook not so good.",
            "As I see it, yes.", "Better not tell you now.",
            "Most likely.", "Cannot predict now.",
            "Signs point to yes.", "Concentrate and ask again.",
            "Ask again later.", "Reply hazy, try again.",
            "100%!", "Nope. Never.",
            "Obviously.", "In your dreams!",
            "Stars say YES.", "Stars say NOPE.",
            "Duh, of course!", "LOL no.",
            "Hell yeah!", "Hell no!",
            "Maybe... just kidding, YES!", "Maybe... nah.",
            "The universe says yes.", "The cosmos laughs at you.",
            "Fate smiles upon you.", "Fate is busy, try later."
        ];
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 60, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        if (state == STATE_ANIM) {
            _animTick++;
            if (_animTick >= 28) {
                state = STATE_ANSWER;
            }
        }
        if (state == STATE_ASK || state == STATE_SHAKE) {
            for (var i = 0; i < _sparkles.size(); i++) {
                if (Math.rand().abs() % 4 == 0) {
                    _sparkles[i] = Math.rand().abs() % 100;
                }
            }
        }
        WatchUi.requestUpdate();
    }

    function shake() {
        if (state == STATE_ASK || state == STATE_SHAKE) {
            state = STATE_ANIM;
            _animTick = 0;
            _answer = _answers[Math.rand().abs() % _answers.size()];
        } else if (state == STATE_ANSWER) {
            state = STATE_SHAKE;
            _answer = "";
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x111111, 0x111111);
        dc.clear();

        if (state == STATE_ASK) {
            drawAskScreen(dc, w, h);
        } else if (state == STATE_SHAKE) {
            drawShakeScreen(dc, w, h);
        } else if (state == STATE_ANIM) {
            drawAnimation(dc, w, h);
        } else {
            drawAnswerScreen(dc, w, h);
        }

        drawBorder(dc, w, h);
    }

    hidden function drawAskScreen(dc, w, h) {
        drawSmallBall(dc, w / 2, h / 2 - h / 10, w);
        drawStars(dc, w, h);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_SMALL, "Ask a question", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 75 / 100, Graphics.FONT_XTINY, "then shake or tap", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawShakeScreen(dc, w, h) {
        drawSmallBall(dc, w / 2, h / 2 - h / 10, w);
        drawStars(dc, w, h);

        dc.setColor(0x44DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_SMALL, "Shake or tap!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 75 / 100, Graphics.FONT_XTINY, "ask another question", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawAnimation(dc, w, h) {
        var cx = w / 2;
        var cy = h / 2;

        var phase = _animTick;
        var shake = 0;
        if (phase < 12) {
            shake = (phase % 4 < 2) ? (phase / 2 + 1) : -(phase / 2 + 1);
        }

        var ballSize = w * 30 / 100;
        if (phase >= 12) {
            var grow = (phase - 12);
            if (grow > 10) { grow = 10; }
            ballSize = w * (30 + grow * 3) / 100;
        }

        drawBallPixel(dc, cx + shake, cy - h / 12, ballSize);

        if (phase < 16) {
            dc.setColor(0x44DDFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + h / 4, Graphics.FONT_SMALL, "...", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (phase < 22) {
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            var dots = "";
            for (var i = 0; i < (phase - 15); i++) { dots = dots + "."; }
            dc.drawText(cx, cy + h / 4, Graphics.FONT_SMALL, dots, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (phase >= 8 && phase < 24) {
            for (var i = 0; i < 6; i++) {
                var angle = (i * 60 + phase * 30) % 360;
                var rad = angle * 3.14159 / 180.0;
                var dist = w * (10 + phase) / 100;
                var sx = cx + (dist * Math.cos(rad)).toNumber();
                var sy = cy - h / 12 + (dist * Math.sin(rad)).toNumber();
                var c = (i % 2 == 0) ? 0xFF44FF : 0x44FFFF;
                dc.setColor(c, Graphics.COLOR_TRANSPARENT);
                var ps = w / 60;
                if (ps < 2) { ps = 2; }
                dc.fillRectangle(sx, sy, ps, ps);
            }
        }
    }

    hidden function drawAnswerScreen(dc, w, h) {
        var cx = w / 2;
        var cy = h / 2;
        var ballR = w * 60 / 200;

        drawBallPixel(dc, cx, cy - h / 12, ballR);

        drawTriangleWindow(dc, cx, cy - h / 12, ballR);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + h / 5, Graphics.FONT_SMALL, _answer, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 85 / 100, Graphics.FONT_XTINY, "Tap to ask again", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawSmallBall(dc, cx, cy, w) {
        var r = w * 22 / 100;
        drawBallPixel(dc, cx, cy, r);
        drawTriangleWindow(dc, cx, cy, r);
    }

    hidden function drawBallPixel(dc, cx, cy, r) {
        var px = r / 8;
        if (px < 1) { px = 1; }

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r + px);

        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);

        dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 4, cy - r / 4, r * 3 / 4);

        dc.setColor(0x252525, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 3, cy - r / 3, r / 3);

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        var hlr = r / 6;
        if (hlr < 1) { hlr = 1; }
        dc.fillCircle(cx - r / 3, cy - r / 3, hlr);

        for (var ring = 0; ring < 3; ring++) {
            var rr = r - ring * px;
            if (rr <= 0) { break; }
            var col = (ring == 0) ? 0x333333 : 0x222222;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            for (var a = 0; a < 360; a += 8) {
                var rad = a * 3.14159 / 180.0;
                var xx = cx + (rr * Math.cos(rad)).toNumber();
                var yy = cy + (rr * Math.sin(rad)).toNumber();
                dc.fillRectangle(xx, yy, px, px);
            }
        }
    }

    hidden function drawTriangleWindow(dc, cx, cy, r) {
        var ts = r * 2 / 3;
        if (ts < 6) { ts = 6; }

        dc.setColor(0x000066, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ts);

        dc.setColor(0x000044, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ts - 2);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var fs = Graphics.FONT_MEDIUM;
        if (ts < 12) { fs = Graphics.FONT_XTINY; }
        else if (ts < 20) { fs = Graphics.FONT_TINY; }
        else if (ts < 30) { fs = Graphics.FONT_SMALL; }
        dc.drawText(cx, cy - dc.getFontHeight(fs) / 2, fs, "8", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawStars(dc, w, h) {
        for (var i = 0; i < _sparkles.size(); i++) {
            var v = _sparkles[i];
            if (v == null) { continue; }
            var sx = (v * 71 + i * 37) % w;
            var sy = (v * 53 + i * 89) % h;
            var brightness = 0x333333 + (v * 0x010101 % 0x666666);
            dc.setColor(brightness, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, sy, 2, 2);
        }
    }

    hidden function drawBorder(dc, w, h) {
        var px = 2;
        if (state == STATE_ANIM) {
            var phase = _animTick % 8;
            if (phase < 4) {
                dc.setColor(0x440088, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(0x220044, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawRectangle(0, 0, w, px);
            dc.drawRectangle(0, h - px, w, px);
            dc.drawRectangle(0, 0, px, h);
            dc.drawRectangle(w - px, 0, px, h);
        } else if (state == STATE_ANSWER) {
            var isPositive = isPositiveAnswer();
            var c = isPositive ? 0x004422 : 0x440022;
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(0, 0, w, px);
            dc.drawRectangle(0, h - px, w, px);
            dc.drawRectangle(0, 0, px, h);
            dc.drawRectangle(w - px, 0, px, h);
        }
    }

    hidden function isPositiveAnswer() {
        if (_answer.find("No") != null || _answer.find("no") != null ||
            _answer.find("not") != null || _answer.find("NOT") != null ||
            _answer.find("NOPE") != null || _answer.find("Nope") != null ||
            _answer.find("nah") != null || _answer.find("doubt") != null ||
            _answer.find("hazy") != null || _answer.find("later") != null ||
            _answer.find("again") != null || _answer.find("busy") != null ||
            _answer.find("LOL") != null || _answer.find("dreams") != null ||
            _answer.find("laughs") != null || _answer.find("Hell no") != null) {
            return false;
        }
        return true;
    }
}
