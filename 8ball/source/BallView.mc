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

// _answerCat: 0 positive, 1 negative, 2 cryptic, 3 sassy (parallel _ansCats)

class BallView extends WatchUi.View {

    var state;
    hidden var _answer;
    hidden var _answerCat;
    hidden var _animTick;
    hidden var _timer;
    hidden var _sparkles;
    hidden var _starX;
    hidden var _starY;
    hidden var _starSpd;
    hidden var _answers;
    hidden var _ansCats;
    hidden var _streakCount;
    hidden var _answerPhase;
    hidden var _frameClock;
    hidden var _vibratedReveal;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());
        state = STATE_ASK;
        _answer = "";
        _answerCat = 2;
        _animTick = 0;
        _sparkles = new [20];
        _streakCount = 0;
        _answerPhase = 0;
        _frameClock = 0;
        _vibratedReveal = false;

        _starX = new [72];
        _starY = new [72];
        _starSpd = new [72];
        for (var i = 0; i < _starX.size(); i++) {
            _starX[i] = Math.rand().abs() % 1000;
            _starY[i] = Math.rand().abs() % 1000;
            _starSpd[i] = 1 + (Math.rand().abs() % 4);
        }

        _answers = [
            "Absolutely freakin' yes!",
            "Bruh. No.",
            "The stars are drunk, ask later",
            "Ask your mom",
            "Signs point to YEET",
            "My lawyer says no comment",
            "Error 404: answer not found",
            "Wow. Bold question. Still no.",
            "Heck yes, obviously.",
            "Nope. Never. Nu-uh.",
            "In another universe, yes",
            "Did you really just ask that?",
            "Without a doubt, legend.",
            "Hard pass. Universe agrees.",
            "Schrodinger's maybe — both",
            "I'm a ball, not a therapist.",
            "The cosmos high-fives you.",
            "Even the void said 'nah'",
            "Reply hazy, Mercury retrograde",
            "Yikes. But... fine, maybe.",
            "100% certified yes.",
            "LOL no. Next question.",
            "The moon is on PTO, ask later",
            "Figure it out, chief.",
            "Fate says: send it.",
            "Outlook grim, cape optional.",
            "Signs point to …maybe?",
            "Bold. Wrong, but bold.",
            "Yes, and twice on Sunday.",
            "Don't count on it, chief.",
            "Purple smoke, no peeking.",
            "Your mom said ask me anyway.",
            "Magic 8-ball who? Yes.",
            "My sources say 'absolutely not'",
            "Concentrate… still nothing.",
            "Cringe question, elite answer: no.",
            "Stars aligned — proceed.",
            "The universe LOL'd. No.",
            "Tunnel says: wrong exit.",
            "Aight, aight… yes.",
            "Obliterated doubt. It's yes.",
            "Denied. Cosmic veto.",
            "Ask again when Saturn chills",
            "That was a choice. Yes.",
            "Yeet cannon loaded: YES",
            "Negative ghost rider",
            "404 prophecy not found",
            "Skill issue (jk… no)",
            "Obviously. Obviously!",
            "Not in this timeline",
            "The oracle took a nap",
            "Okay oracle mode: try again",
            "Radiant YES energy",
            "Doubt is the answer",
            "Cloudy with a chance of vibes",
            "Bruh moment = certified yes",
            "Full send approved",
            "Veto from the void",
            "Yes — the simulation agrees",
            "No — try turning it off and on",
            "Cryptic mode: ask the cat",
            "Sassy oracle says: obviously no",
            "Destiny speedrun: any%",
            "The fates shrugged. Maybe.",
            "Absolutely not, bestie",
            "Positive vibes only (it's yes)",
            "Negative Nancy says: hard no",
            "The void whispers… 'later'",
            "Main character energy: YES",
            "Side quest failed: no",
            "Ancient runes say: ¯\\_(ツ)_/¯",
            "Premium sass: ask Google",
            "Epic loot drop: YES",
            "Critical fail: natural 1, no",
            "Timeline fork: unclear path",
            "Chaos goblin says: yeet maybe",
            "Certified fresh: yes",
            "Expired prophecy: no",
            "Mystic fog — try again sober",
            "That question had audacity: no",
            "Galaxy brain: affirmative",
            "Cosmic cringe: denied",
            "Tarot said 'idk lol'",
            "Oracle fatigue — yes anyway",
            "Stars point to 'no cap' no",
            "Enigma machine: maybe yes",
            "Dramatic pause… still no",
            "Hero arc unlocked: yes",
            "Plot twist: it was no all along",
            "Nebula says ask your therapist",
            "Sass level 9000: try again",
            "Big yes energy, small watch face",
            "Tiny no, huge consequences",
            "Riddle wrapped in a maybe",
            "Bold strategy — let's see no",
            "Fortune favors: you, yes",
            "RNGesus rolled: critical no",
            "Holographic answer: unclear",
            "Peak comedy: yes, actually",
            "Deadpan ball: no."
        ];

        _ansCats = [
            0, 1, 2, 3, 0, 3, 2, 1, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3,
            0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3,
            0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 0, 1,
            2, 3, 3, 2, 1, 0, 1, 2, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3,
            0, 1, 2, 0, 1, 2, 1, 0, 1, 3, 3, 0, 1, 2, 1, 0, 1, 2, 0, 1
        ];
    }

    hidden function doVibrate() as Void {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(50, 200)]);
            }
        }
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 60, true);
    }

    function onHide() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        _frameClock++;

        if (state == STATE_ANIM) {
            _animTick++;
            if (_animTick >= 46) {
                state = STATE_ANSWER;
                _answerPhase = 0;
                _vibratedReveal = false;
            }
        }

        if (state == STATE_ANSWER) {
            if (_answerPhase < 32) {
                _answerPhase++;
            }
            if (!_vibratedReveal && _answerPhase >= 4) {
                doVibrate();
                _vibratedReveal = true;
            }
        }

        if (state == STATE_ASK || state == STATE_SHAKE) {
            for (var i = 0; i < _sparkles.size(); i++) {
                if (Math.rand().abs() % 3 == 0) {
                    _sparkles[i] = Math.rand().abs() % 1000;
                }
            }
        }

        WatchUi.requestUpdate();
    }

    function shake() {
        if (state == STATE_ASK || state == STATE_SHAKE) {
            state = STATE_ANIM;
            _animTick = 0;
            _streakCount++;
            var idx = Math.rand().abs() % _answers.size();
            _answer = _answers[idx];
            if (idx < _ansCats.size()) {
                _answerCat = _ansCats[idx];
            } else {
                _answerCat = 2;
            }
            doVibrate();
        } else if (state == STATE_ANSWER) {
            state = STATE_SHAKE;
            _answer = "";
            _answerPhase = 0;
            _vibratedReveal = false;
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var ox = 0;
        var oy = 0;
        if (state == STATE_ANIM) {
            var ph = _animTick;
            if (ph < 18) {
                var swing = w / 9;
                if (swing < 8) {
                    swing = 8;
                }
                var step = ph % 6;
                if (step < 3) {
                    ox = swing + (ph * 2);
                } else {
                    ox = -swing - (ph * 2);
                }
                if (ox > swing * 2) {
                    ox = swing * 2;
                }
                if (ox < -swing * 2) {
                    ox = -swing * 2;
                }
                oy = ((ph % 5) - 2) * (h / 50);
                var jitter = (ph * 11) % 7 - 3;
                ox += jitter;
            } else if (ph < 46) {
                ox = ((ph * 5) % 5) - 2;
                oy = ((ph * 3) % 3) - 1;
            }
        }

        dc.setColor(0x0A0A12, 0x0A0A12);
        dc.clear();

        drawStarfield(dc, w, h, ox, oy);

        if (state == STATE_ASK) {
            drawAskScreen(dc, w, h, ox, oy);
        } else if (state == STATE_SHAKE) {
            drawShakeScreen(dc, w, h, ox, oy);
        } else if (state == STATE_ANIM) {
            drawAnimation(dc, w, h, ox, oy);
        } else {
            drawAnswerScreen(dc, w, h, ox, oy);
        }

        drawBorder(dc, w, h);
        drawStreak(dc, w, h);
    }

    hidden function drawStreak(dc, w, h) {
        var label = "Q#" + _streakCount;
        dc.setColor(0x556688, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 6 / 100, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawStarfield(dc, w, h, ox, oy) {
        var scroll = (_frameClock * 2) % 2000;
        for (var i = 0; i < _starX.size(); i++) {
            var sx = ((_starX[i] * w) / 1000 + ox + scroll / _starSpd[i]) % (w + 4) - 2;
            var sy = ((_starY[i] * h) / 1000 + oy + (_frameClock * _starSpd[i] / 3) % (h + 4)) % (h + 4) - 2;
            var tw = (i % 3) + 1;
            var base = 0x222244 + ((i * 37) % 0x444466);
            dc.setColor(base, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(sx, sy, tw, tw);
        }
        if (state == STATE_ASK || state == STATE_SHAKE) {
            for (var j = 0; j < _sparkles.size(); j++) {
                var v = _sparkles[j];
                if (v == null) {
                    continue;
                }
                var px = (v * 71 + j * 37) % w;
                var py = (v * 53 + j * 89) % h;
                var br = 0x6666AA + ((v * 3) % 0x333344);
                dc.setColor(br, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(px + ox, py + oy, 2, 2);
            }
        }
    }

    hidden function drawAskScreen(dc, w, h, ox, oy) {
        drawSmallBall(dc, w / 2 + ox, h / 2 - h / 10 + oy, w);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + ox, h * 62 / 100 + oy, Graphics.FONT_SMALL, "Ask a question", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + ox, h * 75 / 100 + oy, Graphics.FONT_XTINY, "then shake or tap", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawShakeScreen(dc, w, h, ox, oy) {
        drawSmallBall(dc, w / 2 + ox, h / 2 - h / 10 + oy, w);
        dc.setColor(0x44DDFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + ox, h * 62 / 100 + oy, Graphics.FONT_SMALL, "Shake or tap!", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x667788, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 + ox, h * 75 / 100 + oy, Graphics.FONT_XTINY, "ask another question", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawAnimation(dc, w, h, ox, oy) {
        var cx = w / 2 + ox;
        var cy = h / 2 + oy;
        var phase = _animTick;

        var ballOffX = 0;
        if (phase < 18) {
            var mag = w / 7;
            if (mag < 10) {
                mag = 10;
            }
            var wave = (phase * 17) % 360;
            var rad = wave * 3.14159 / 180.0;
            ballOffX = (mag * Math.cos(rad)).toNumber();
            if (phase % 2 == 0) {
                ballOffX = -ballOffX;
            }
        }

        var ballSize = w * 30 / 100;
        if (phase >= 14) {
            var grow = phase - 14;
            if (grow > 22) {
                grow = 22;
            }
            ballSize = w * (30 + grow * 4) / 100;
        }

        drawBallPixel(dc, cx + ballOffX, cy - h / 12, ballSize);

        if (phase >= 14) {
            var ringR = ballSize + w / 14 + (phase - 14) * 2;
            var count = 14;
            for (var i = 0; i < count; i++) {
                var ang = (i * 360 / count + phase * 14) % 360;
                var rad2 = ang * 3.14159 / 180.0;
                var dist = ringR;
                var sx = cx + ballOffX + (dist * Math.cos(rad2)).toNumber();
                var sy = cy - h / 12 + (dist * Math.sin(rad2)).toNumber();
                var c = (i % 3 == 0) ? 0xFF66FF : ((i % 3 == 1) ? 0x66FFFF : 0xFFFF66);
                dc.setColor(c, Graphics.COLOR_TRANSPARENT);
                var ps = w / 45;
                if (ps < 2) {
                    ps = 2;
                }
                dc.fillRectangle(sx - ps / 2, sy - ps / 2, ps, ps);
            }
        }

        if (phase < 20) {
            dc.setColor(0x44DDFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + h / 4, Graphics.FONT_SMALL, "...", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (phase < 30) {
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            var dots = "";
            var n = phase - 19;
            if (n > 6) {
                n = 6;
            }
            for (var d = 0; d < n; d++) {
                dots = dots + ".";
            }
            dc.drawText(cx, cy + h / 4, Graphics.FONT_SMALL, dots, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawAnswerScreen(dc, w, h, ox, oy) {
        var cx = w / 2 + ox;
        var cy = h / 2 + oy;
        var ballR = w * 62 / 200;

        var glowCol = categoryGlowColor();
        var pulse = (_frameClock % 20);
        if (pulse > 10) {
            pulse = 20 - pulse;
        }
        var rings = 3 + (pulse / 3);
        for (var r = rings; r > 0; r--) {
            var rr = ballR + r * (w / 35);
            var ringCol = 0x221133;
            if (_answerCat == 0) {
                ringCol = blendToward(0x003322, glowCol, pulse, 10);
            } else if (_answerCat == 1) {
                ringCol = blendToward(0x331122, glowCol, pulse, 10);
            } else if (_answerCat == 2) {
                ringCol = blendToward(0x220044, glowCol, pulse, 10);
            } else {
                ringCol = blendToward(0x332211, glowCol, pulse, 10);
            }
            ringCol = blendToward(ringCol, 0x000000, r * 3, rings * 4 + 6);
            dc.setColor(ringCol, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy - h / 12, rr);
        }

        drawBallPixel(dc, cx, cy - h / 12, ballR);
        drawTriangleWindow(dc, cx, cy - h / 12, ballR);

        dc.setColor(0xCCAAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + h / 9, Graphics.FONT_XTINY, "The Oracle says:", Graphics.TEXT_JUSTIFY_CENTER);

        var catLabel = categoryLabel();
        dc.setColor(glowCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + h / 9 + dc.getFontHeight(Graphics.FONT_XTINY) + 2, Graphics.FONT_XTINY, catLabel, Graphics.TEXT_JUSTIFY_CENTER);

        var fade = _answerPhase;
        if (fade > 24) {
            fade = 24;
        }
        drawGlowingAnswer(dc, cx, cy + h / 5 + 6, fade, glowCol, _answer);

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 86 / 100, Graphics.FONT_XTINY, "Tap to ask again", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function categoryGlowColor() {
        if (_answerCat == 0) {
            return 0x33FF99;
        }
        if (_answerCat == 1) {
            return 0xFF4466;
        }
        if (_answerCat == 2) {
            return 0xBB77FF;
        }
        return 0xFFCC55;
    }

    hidden function categoryLabel() {
        if (_answerCat == 0) {
            return "[ Positive ]";
        }
        if (_answerCat == 1) {
            return "[ Cold truth ]";
        }
        if (_answerCat == 2) {
            return "[ Cryptic ]";
        }
        return "[ Sassy ]";
    }

    hidden function drawGlowingAnswer(dc, cx, cy, fade, glowHex, text) {
        var dim = 0x222222;
        var fg = blendToward(glowHex, 0xFFFFFF, fade, 24);
        if (fade < 6) {
            fg = dim;
        }

        var fs = Graphics.FONT_SMALL;
        if (text.length() > 42) {
            fs = Graphics.FONT_XTINY;
        } else if (text.length() > 28) {
            fs = Graphics.FONT_TINY;
        }

        var off = 2;
        if (fade < 8) {
            off = 1;
        }
        var halo = blendToward(glowHex, 0x000000, 12, 24);
        dc.setColor(halo, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - off, cy, fs, text, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + off, cy, fs, text, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy - off, fs, text, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy + off, fs, text, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, fs, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function blendToward(fromC, toC, t, maxT) {
        if (t <= 0) {
            return fromC;
        }
        if (t >= maxT) {
            return toC;
        }
        var fr = (fromC >> 16) & 0xFF;
        var fg = (fromC >> 8) & 0xFF;
        var fb = fromC & 0xFF;
        var tr = (toC >> 16) & 0xFF;
        var tg = (toC >> 8) & 0xFF;
        var tb = toC & 0xFF;
        var rr = fr + (tr - fr) * t / maxT;
        var gg = fg + (tg - fg) * t / maxT;
        var bb = fb + (tb - fb) * t / maxT;
        return (rr << 16) | (gg << 8) | bb;
    }

    hidden function drawSmallBall(dc, cx, cy, w) {
        var r = w * 22 / 100;
        drawBallPixel(dc, cx, cy, r);
        drawTriangleWindow(dc, cx, cy, r);
    }

    hidden function drawBallPixel(dc, cx, cy, r) {
        var px = r / 10;
        if (px < 1) {
            px = 1;
        }

        dc.setColor(0x1A1A1A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r + px * 2);

        dc.setColor(0x0D0D0D, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r + px);

        dc.setColor(0x080808, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);

        dc.setColor(0x151515, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 5, cy - r / 5, r * 4 / 5);

        dc.setColor(0x1F1F1F, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 4, cy - r / 4, r * 2 / 3);

        dc.setColor(0x2A2A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r / 3, cy - r / 3, r / 2);

        dc.setColor(0x3D3D3D, Graphics.COLOR_TRANSPARENT);
        var hlr = r / 5;
        if (hlr < 2) {
            hlr = 2;
        }
        dc.fillCircle(cx - r / 3, cy - r / 3, hlr);

        dc.setColor(0x505050, Graphics.COLOR_TRANSPARENT);
        var hlr2 = r / 10;
        if (hlr2 < 1) {
            hlr2 = 1;
        }
        dc.fillCircle(cx - r / 3 - r / 14, cy - r / 3 - r / 14, hlr2);

        for (var ring = 0; ring < 5; ring++) {
            var rr = r - ring * px;
            if (rr <= 2) {
                break;
            }
            var col = 0x2C2C2C;
            if (ring == 1) {
                col = 0x242424;
            } else if (ring == 2) {
                col = 0x1C1C1C;
            } else if (ring == 3) {
                col = 0x181818;
            } else if (ring >= 4) {
                col = 0x141414;
            }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            for (var a = 0; a < 360; a += 6) {
                var rad = a * 3.14159 / 180.0;
                var xx = cx + (rr * Math.cos(rad)).toNumber();
                var yy = cy + (rr * Math.sin(rad)).toNumber();
                dc.fillRectangle(xx, yy, px, px);
            }
        }

        dc.setColor(0x0A0A0A, Graphics.COLOR_TRANSPARENT);
        for (var a2 = 0; a2 < 360; a2 += 9) {
            var rad3 = a2 * 3.14159 / 180.0;
            var xx2 = cx + ((r - px) * Math.cos(rad3)).toNumber();
            var yy2 = cy + ((r - px) * Math.sin(rad3)).toNumber();
            dc.fillRectangle(xx2, yy2, px, px);
        }
    }

    hidden function drawTriangleWindow(dc, cx, cy, r) {
        var ts = r * 2 / 3;
        if (ts < 6) {
            ts = 6;
        }

        dc.setColor(0x000055, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ts + 1);

        dc.setColor(0x000088, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ts);

        dc.setColor(0x000044, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 1, cy + 1, ts - 2);

        dc.setColor(0x001133, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, ts - 3);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        var fs = Graphics.FONT_MEDIUM;
        if (ts < 12) {
            fs = Graphics.FONT_XTINY;
        } else if (ts < 20) {
            fs = Graphics.FONT_TINY;
        } else if (ts < 30) {
            fs = Graphics.FONT_SMALL;
        }
        dc.drawText(cx, cy - dc.getFontHeight(fs) / 2, fs, "8", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawBorder(dc, w, h) {
        var px = 3;
        if (px > w / 20) {
            px = 2;
        }
        var pulse = (_frameClock % 14);
        if (pulse > 7) {
            pulse = 14 - pulse;
        }

        var c1 = 0x332266;
        var c2 = 0x6644AA;
        if (state == STATE_ANIM) {
            c1 = 0x440088 + pulse * 0x080008;
            c2 = 0x8800CC - pulse * 0x060006;
        } else if (state == STATE_ANSWER) {
            var g = categoryGlowColor();
            c1 = blendToward(0x111111, g, pulse + 4, 12);
            c2 = blendToward(g, 0xFFFFFF, pulse, 12);
        } else if (state == STATE_SHAKE) {
            c1 = 0x224466;
            c2 = 0x4488CC;
        }

        var useBright = ((_frameClock / 2) % 2) == 0;
        dc.setColor(useBright ? c2 : c1, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(0, 0, w, px);
        dc.drawRectangle(0, h - px, w, px);
        dc.drawRectangle(0, 0, px, h);
        dc.drawRectangle(w - px, 0, px, h);

        dc.setColor(useBright ? c1 : c2, Graphics.COLOR_TRANSPARENT);
        var px2 = px - 1;
        if (px2 < 1) {
            px2 = 1;
        }
        dc.drawRectangle(1, 1, w - 2, px2);
        dc.drawRectangle(1, h - 1 - px2, w - 2, px2);
        dc.drawRectangle(1, 1, px2, h - 2);
        dc.drawRectangle(w - 1 - px2, 1, px2, h - 2);
    }
}
