// ═══════════════════════════════════════════════════════════════
// MainView.mc — 25 ms tick driver + render loop.
//
// Render order (back → front):
//   1. Table backdrop + bezel
//   2. Drop targets (when not knocked down)
//   3. Slingshots (filled triangles + flash edges)
//   4. Bumpers
//   5. Flippers
//   6. Balls (up to MAX_BALLS in multi-ball)
//   7. HUD (score, lives, table name, MULTI-BALL indicator)
//
// All physics are amortised over a single 40 Hz tick — even with
// three balls + drops + slings, the per-tick cost is well below the
// watchdog budget on the slowest Garmin devices.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;

const TICK_MS = 25;

class MainView extends WatchUi.View {

    var _ctrl;
    hidden var _timer;
    hidden var _laidOut;
    hidden var _delegate;
    hidden var _started;   // auto-start the match on first layout
    // Safety: maximum frames a touch hold can keep flippers pressed
    // without a touch-up signal before we force-release them. Protects
    // against the device dropping the touch session (battery saver,
    // crashed touch driver, etc.) which would otherwise leave the
    // flippers stuck pointing skyward.
    hidden var _touchHoldFrames;
    static var TOUCH_HOLD_SAFETY_MAX = 40;  // 40 frames * 25 ms ≈ 1.0 s

    function initialize() {
        View.initialize();
        _ctrl    = new GameController();
        _timer   = null;
        _laidOut = false;
        _delegate = null;
        _touchHoldFrames = 0;
        _started = false;
    }

    function setDelegate(d) { _delegate = d; }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), TICK_MS, true);
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() {
        _ctrl.step();
        // Safety auto-release for stuck touch holds — if the delegate
        // says we've been holding flippers via touch for too long
        // without a touch-up signal, force a release. This makes the
        // "flippers stuck up" failure mode impossible regardless of
        // how badly the device's touch driver behaves.
        if (_delegate != null && _delegate.isTouchHoldingFlippers()) {
            _delegate.tickTouch();
            _touchHoldFrames = _touchHoldFrames + 1;
            if (_touchHoldFrames >= TOUCH_HOLD_SAFETY_MAX) {
                _ctrl.releaseBothFlippers();
                _delegate.clearTouchHoldingFlippers();
                _touchHoldFrames = 0;
            }
        } else {
            _touchHoldFrames = 0;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        if (!_laidOut) {
            _ctrl.setScreen(dc.getWidth(), dc.getHeight());
            _laidOut = true;
        }
        dc.setColor(0x000814, 0x000814); dc.clear();

        // Menu lives in the shared root view — drop straight into a match and
        // never render an in-game menu here.
        if (!_started || _ctrl.state == GS_MENU) {
            _ctrl.startMatch();
            _started = true;
        }

        // Screen shake — sample once so the whole field jolts together.
        var ox = _ctrl.shakeX();
        var oy = _ctrl.shakeY();

        _drawTable(dc, ox, oy);
        _drawDrops(dc, ox, oy);
        _drawSlings(dc, ox, oy);
        _drawBumpers(dc, ox, oy);
        _ctrl.fLeft.draw(dc, ox, oy);
        _ctrl.fRight.draw(dc, ox, oy);
        for (var i = 0; i < MAX_BALLS; i++) { _ctrl.balls[i].draw(dc, ox, oy); }
        _drawParticles(dc, ox, oy);
        _drawPopups(dc, ox, oy);
        _drawHUD(dc);
        _drawBanner(dc);

        if (_ctrl.state == GS_LAUNCH) { _drawLaunchPrompt(dc); }
        if (_ctrl.state == GS_OVER)   { _drawOver(dc);         }
    }

    // ── Table backdrop ──────────────────────────────────────────────
    hidden function _drawTable(dc, ox, oy) {
        var theme = TableLibrary.theme(_ctrl.tableIdx);
        var bg     = theme[0];
        var accent = theme[1];
        var x0 = _ctrl.playX0 + ox; var y0 = _ctrl.playY0 + oy;
        var x1 = _ctrl.playX1 + ox; var y1 = _ctrl.playY1 + oy;
        var pw = x1 - x0; var ph = y1 - y0;

        // Body
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0, y0, pw, ph);

        // Playfield lighting — a brighter band up top fading down, so
        // the table reads as lit from the backglass.
        var bands = 5;
        for (var g = 0; g < bands; g++) {
            var t = 16 - g * 3; if (t < 0) { t = 0; }
            dc.setColor(_mix(bg, 0xFFFFFF, t), Graphics.COLOR_TRANSPARENT);
            var bh = ph / (bands + 3);
            dc.fillRectangle(x0, y0 + g * bh, pw, bh);
        }

        // Per-table decorative inlay layer.
        _drawInlay(dc, x0, y0, x1, y1, accent);

        // Coloured bezel (double for a neon-tube feel)
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x0 - 1, y0 - 1, pw + 2, ph + 2);
        dc.setColor(_mix(accent, 0x000000, 40), Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x0 - 2, y0 - 2, pw + 4, ph + 4);

        // Neon lane guides funnelling toward the flippers.
        dc.setColor(_mix(accent, bg, 55), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var fy = _ctrl.fLeft.pivotY + oy;
        dc.drawLine(x0 + 3, y0 + ph * 55 / 100, _ctrl.fLeft.pivotX + ox - 6, fy - 6);
        dc.drawLine(x1 - 3, y0 + ph * 55 / 100, _ctrl.fRight.pivotX + ox + 6, fy - 6);
        dc.setPenWidth(1);

        // Drain triangles below the flipper line.
        dc.setColor(0x220305, Graphics.COLOR_TRANSPARENT);
        var dfy = fy + 8;
        dc.fillPolygon([[x0,     dfy], [x0 + 8, y1], [x0, y1]]);
        dc.fillPolygon([[x1,     dfy], [x1 - 8, y1], [x1, y1]]);

        // Launcher lane indicator.
        dc.setColor(_mix(accent, bg, 70), Graphics.COLOR_TRANSPARENT);
        var laneX = x1 - 6;
        dc.drawLine(laneX, y0 + 6, laneX, y1 - 12);
    }

    // Per-table decorative artwork — cheap vector inlays that make
    // each table read as a distinct machine.
    hidden function _drawInlay(dc, x0, y0, x1, y1, accent) {
        var pw = x1 - x0; var ph = y1 - y0;
        var cx = (x0 + x1) / 2; var cy = (y0 + y1) / 2;
        var faint = _mix(accent, 0x000000, 62);
        dc.setColor(faint, Graphics.COLOR_TRANSPARENT);
        var style = TableLibrary.artStyle(_ctrl.tableIdx);

        if (style == :dashes) {
            var y = y0 + 12;
            while (y < y1 - 30) { dc.fillRectangle(cx - 1, y, 2, 5); y = y + 14; }
        } else if (style == :diamond) {
            var dr = pw * 30 / 100;
            dc.drawLine(cx, cy - dr, cx + dr, cy);
            dc.drawLine(cx + dr, cy, cx, cy + dr);
            dc.drawLine(cx, cy + dr, cx - dr, cy);
            dc.drawLine(cx - dr, cy, cx, cy - dr);
        } else if (style == :bolts) {
            for (var b = 0; b < 3; b++) {
                var by = y0 + ph * (25 + b * 22) / 100;
                dc.drawLine(x0 + 6, by, cx - 6, by + 8);
                dc.drawLine(cx + 6, by + 8, x1 - 6, by);
            }
        } else if (style == :hive) {
            for (var h = 0; h < 3; h++) {
                var hy = y0 + ph * (22 + h * 16) / 100;
                var hx = (h % 2 == 0) ? cx - pw / 6 : cx + pw / 6;
                _hexOutline(dc, hx, hy, pw / 10);
                _hexOutline(dc, (h % 2 == 0) ? cx + pw / 6 : cx - pw / 6, hy, pw / 10);
            }
        } else if (style == :sun) {
            var rr = pw * 22 / 100;
            for (var s = 0; s < 12; s++) {
                var a = s * 3.14159 / 6.0;
                dc.drawLine(cx, y0 + ph * 28 / 100,
                            cx + rr * Math.cos(a),
                            (y0 + ph * 28 / 100) + rr * Math.sin(a));
            }
        } else if (style == :spiral) {
            var px = cx; var py = y0 + ph * 30 / 100;
            for (var i2 = 0; i2 < 22; i2++) {
                var ang = i2 * 0.6;
                var rad = 3 + i2 * (pw / 90);
                var nx = cx + rad * Math.cos(ang);
                var ny = (y0 + ph * 30 / 100) + rad * Math.sin(ang);
                dc.drawLine(px, py, nx, ny);
                px = nx; py = ny;
            }
        } else {
            // streak — diagonal speed lines.
            for (var k = 0; k < 5; k++) {
                var sx = x0 + pw * k / 5;
                dc.drawLine(sx, y0 + 8, sx + pw / 6, y0 + ph * 45 / 100);
            }
        }
    }

    hidden function _hexOutline(dc, hx, hy, r) {
        var pts = new [6];
        for (var i = 0; i < 6; i++) {
            var a = i * 3.14159 / 3.0;
            pts[i] = [hx + r * Math.cos(a), hy + r * Math.sin(a)];
        }
        for (var j = 0; j < 6; j++) {
            var n = (j + 1) % 6;
            dc.drawLine(pts[j][0], pts[j][1], pts[n][0], pts[n][1]);
        }
    }

    // Blend a→b by t/100 (integer channels, packed 0xRRGGBB).
    hidden function _mix(a, b, t) {
        if (t <= 0) { return a; }
        if (t >= 100) { return b; }
        var ar = (a >> 16) & 0xFF; var ag = (a >> 8) & 0xFF; var ab = a & 0xFF;
        var br = (b >> 16) & 0xFF; var bg = (b >> 8) & 0xFF; var bb = b & 0xFF;
        var rr = ar + (br - ar) * t / 100;
        var rg = ag + (bg - ag) * t / 100;
        var rb = ab + (bb - ab) * t / 100;
        return (rr << 16) | (rg << 8) | rb;
    }

    // ── Drop targets ────────────────────────────────────────────────
    hidden function _drawDrops(dc, ox, oy) {
        for (var i = 0; i < _ctrl.drops.size(); i++) {
            var d = _ctrl.drops[i];
            var dx = d.x + ox; var dy = d.y + oy;
            if (d.down) {
                dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(dx, dy, d.w, d.h);
                continue;
            }
            var col = (d.flash > 0) ? 0xFFFFFF : d.color;
            // Glow when freshly hit.
            if (d.flash > 0) {
                dc.setColor(_mix(d.color, 0xFFFFFF, 60), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(dx - 1, dy - 1, d.w + 2, d.h + 2);
            }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dx, dy, d.w, d.h);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dx + 1, dy + 1, d.w - 2, 1);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dx + 1, dy + d.h - 2, d.w - 2, 1);
        }
    }

    // ── Slingshots ──────────────────────────────────────────────────
    hidden function _drawSlings(dc, ox, oy) {
        for (var i = 0; i < _ctrl.slings.size(); i++) {
            var s = _ctrl.slings[i];
            var fillCol = (s.flash > 0) ? 0xFFFFFF : s.color;
            dc.setColor(fillCol, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[s.ax + ox, s.ay + oy],
                            [s.bx + ox, s.by + oy],
                            [s.cx + ox, s.cy + oy]]);
            var edgeCol = (s.flash > 0) ? 0xFFFFFF : _mix(s.color, 0xFFFFFF, 50);
            dc.setColor(edgeCol, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth((s.flash > 0) ? 3 : 2);
            dc.drawLine(s.ax + ox, s.ay + oy, s.bx + ox, s.by + oy);
            dc.setPenWidth(1);
        }
    }

    // ── Bumpers ─────────────────────────────────────────────────────
    hidden function _drawBumpers(dc, ox, oy) {
        for (var i = 0; i < _ctrl.bumpers.size(); i++) {
            var b   = _ctrl.bumpers[i];
            var bx  = b[0] + ox;
            var by  = b[1] + oy;
            var r   = b[2];
            var col = b[3];
            var flash = b[4];

            // Expanding shock ring on hit (uses the flash countdown).
            if (flash > 0) {
                dc.setColor(_mix(col, 0xFFFFFF, 70), Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(bx, by, r + 2 + (8 - flash));
            }
            // Soft outer glow.
            dc.setColor(_mix(col, 0x000000, 55), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, r + 2);
            // Body (brightens on hit).
            dc.setColor((flash > 0) ? _mix(col, 0xFFFFFF, 45) : col,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, r);
            // Inner cap + specular.
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, r / 2);
            dc.setColor(_mix(col, 0xFFFFFF, 25), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, r / 3);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx - r / 3, by - r / 3, r / 5 + 1);
        }
    }

    // ── Particles + score popups ────────────────────────────────────
    hidden function _drawParticles(dc, ox, oy) {
        var ps = _ctrl.fx.parts;
        for (var i = 0; i < FxSystem.PCAP; i++) {
            var p = ps[i];
            if (p.life <= 0) { continue; }
            var col = (p.life * 2 < p.maxLife)
                      ? _mix(p.color, 0x000000, 45) : p.color;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var pr = p.big ? 2 : 1;
            dc.fillCircle(p.x + ox, p.y + oy, pr);
        }
    }

    hidden function _drawPopups(dc, ox, oy) {
        var us = _ctrl.fx.pops;
        for (var i = 0; i < FxSystem.UCAP; i++) {
            var u = us[i];
            if (u.life <= 0) { continue; }
            var col = (u.life * 3 < u.maxLife)
                      ? _mix(u.color, 0x000000, 40) : u.color;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(u.x + ox, u.y + oy, Graphics.FONT_XTINY,
                        u.text, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── HUD ─────────────────────────────────────────────────────────
    hidden function _drawHUD(dc) {
        var cx = _ctrl.screenW / 2;
        var W  = _ctrl.screenW;
        var H  = _ctrl.screenH;
        var ty = (H * 3) / 100; if (ty < 3) { ty = 3; }

        // Score — centre top.
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ty, Graphics.FONT_MEDIUM,
                    _formatScore(_ctrl.score),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Multiplier badge under the score (only when boosted).
        if (_ctrl.multiplier > 1) {
            var mfh = dc.getFontHeight(Graphics.FONT_MEDIUM);
            dc.setColor(0xFFDD22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ty + mfh - 4, Graphics.FONT_XTINY,
                        "x" + _ctrl.multiplier.toString() + " COMBO",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Lives → small chrome balls top-right.
        dc.setColor(0xCCCCDD, Graphics.COLOR_TRANSPARENT);
        var lvX = W - 8;
        var maxShow = _ctrl.lives;
        if (maxShow > 5) { maxShow = 5; }
        for (var i = 0; i < maxShow; i++) {
            dc.fillCircle(lvX - i * 8, ty + 8, 3);
        }
        if (_ctrl.lives > 5) {
            dc.drawText(lvX - 5 * 8 - 4, ty + 4, Graphics.FONT_XTINY,
                        "+" + (_ctrl.lives - 5).toString(),
                        Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // Top-left: table name, or MULTI / JACKPOT while multiball.
        if (_ctrl.isMultiball()) {
            dc.setColor(0xFFEE00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, ty + 4, Graphics.FONT_XTINY,
                        "JACKPOT " + _ctrl.jackpot.toString(),
                        Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.setColor(0xAACCEE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(8, ty + 4, Graphics.FONT_XTINY,
                        TableLibrary.NAMES[_ctrl.tableIdx],
                        Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Mission objective — centred just above the flipper line.
        var missFh = dc.getFontHeight(Graphics.FONT_XTINY);
        var missY = H - missFh - 2;
        if (_ctrl.state == GS_PLAY) {
            dc.setColor(0x88DDBB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, missY, Graphics.FONT_XTINY,
                        _ctrl.missionLabel(), Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Ball-save ring indicator (bottom-left) while active.
        if (_ctrl.ballSaveTimer > 0 && _ctrl.state == GS_PLAY) {
            dc.setColor(0x44FFAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(10, missY, Graphics.FONT_XTINY, "SAVE",
                        Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Tilt meter (bottom-right) — fills as you nudge.
        if (_ctrl.tiltMeter > 0 && _ctrl.state == GS_PLAY) {
            var tmW = 26; var tmH = 4;
            var tmX = W - tmW - 8; var tmY = missY + missFh / 3;
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tmX, tmY, tmW, tmH);
            var fillW = tmW * _ctrl.tiltMeter / GameController.TILT_MAX;
            var tcol = (_ctrl.tiltMeter > 66) ? 0xFF3333 : 0xFFAA22;
            dc.setColor(tcol, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tmX, tmY, fillW, tmH);
        }
    }

    // ── Event banner ────────────────────────────────────────────────
    hidden function _drawBanner(dc) {
        if (_ctrl.bannerTimer <= 0) { return; }
        var cx = _ctrl.screenW / 2;
        var cy = _ctrl.screenH * 40 / 100;
        // Shadow plate.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 1, cy + 1, Graphics.FONT_SMALL, _ctrl.bannerText,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_ctrl.bannerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_SMALL, _ctrl.bannerText,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Launch / over overlays ──────────────────────────────────────
    // While the ball is parked we draw an oscillating power meter on
    // the launcher lane and a "TAP to launch" hint. The current bar
    // height = current power; colour shifts green→yellow→red as the
    // meter charges, so the player can time the release for a soft
    // skill shot or a full-power blast.
    hidden function _drawLaunchPrompt(dc) {
        var cx = _ctrl.screenW / 2;

        // Power meter geometry — narrow vertical bar in the launcher
        // lane, sized to the playfield.
        var ph = _ctrl.playY1 - _ctrl.playY0;
        var mH = (ph * 38) / 100; if (mH < 60) { mH = 60; }
        var mW = 6;
        var mX = _ctrl.playX1 - 12;
        var mY = _ctrl.playY1 - 18 - mH;
        // Frame
        dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mX - 1, mY - 1, mW + 2, mH + 2);
        dc.setColor(0x000814, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mX, mY, mW, mH);
        // Tick marks every 25%
        dc.setColor(0x445566, Graphics.COLOR_TRANSPARENT);
        for (var k = 1; k <= 3; k++) {
            var ty = mY + (mH * k) / 4;
            dc.drawLine(mX - 2, ty, mX + mW + 2, ty);
        }
        // Skill-shot band — the lit sweet-spot on the meter.
        var bandY0 = mY + mH - (mH * _ctrl.skillHi) / 100;
        var bandY1 = mY + mH - (mH * _ctrl.skillLo) / 100;
        dc.setColor(0x0A3A33, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mX, bandY0, mW, bandY1 - bandY0);
        dc.setColor(0x44FFEE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(mX - 1, bandY0, mW + 2, bandY1 - bandY0);

        // Charge bar — grows from the bottom up.
        var p   = _ctrl.launchPower;
        if (p < 0)   { p = 0; }
        if (p > 100) { p = 100; }
        var barH = (mH * p) / 100;
        var inBand = (p >= _ctrl.skillLo && p <= _ctrl.skillHi);
        var fill;
        if (inBand)      { fill = 0x44FFEE; }
        else if (p < 40) { fill = 0x44FF88; }
        else if (p < 75) { fill = 0xFFEE00; }
        else             { fill = 0xFF4422; }
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(mX, mY + mH - barH, mW, barH);

        // Plunger arrow tracking the current charge.
        var arrowY = mY + mH - barH;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[mX - 4, arrowY - 3],
                        [mX - 4, arrowY + 3],
                        [mX,     arrowY]]);

        // Hint label.
        dc.setColor(inBand ? 0x44FFEE : 0x44FFAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _ctrl.screenH - 18, Graphics.FONT_XTINY,
                    inBand ? "SKILL SHOT READY!"
                           : ("LAUNCH  -  " + p.format("%d") + "%"),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawOver(dc) {
        var col = (_ctrl.score >= _ctrl.hi && _ctrl.score > 0)
                  ? 0x44FF88 : 0xFF4466;
        var lines = [
            ["Score " + _formatScore(_ctrl.score), 0xFFFFFF],
            ["Table: " + TableLibrary.NAMES[_ctrl.tableIdx], 0xAACCEE]
        ];
        if (_ctrl.score > 0 && _ctrl.score >= _ctrl.hi) {
            lines.add(["NEW BEST!", 0x44FF88]);
        } else if (_ctrl.hi > 0) {
            lines.add(["Best " + _formatScore(_ctrl.hi), 0xFFCC22]);
        }
        if (_ctrl.bestCombo > 1) {
            lines.add(["Best combo x" + _ctrl.bestCombo.toString(), 0x88DDBB]);
        }
        GameOverCard.draw(dc, _ctrl.screenW, _ctrl.screenH,
            "GAME OVER", col, lines, "Tap = replay  ESC = menu", col);
    }

    // ── Menu ────────────────────────────────────────────────────────
    // Chess-style two-row menu: TABLE (cycle) + START.
    hidden function _drawMenu(dc) {
        var cx = _ctrl.screenW / 2;
        var W  = _ctrl.screenW;
        var H  = _ctrl.screenH;

        dc.setColor(0x080808, 0x080808); dc.clear();
        if (W == H) {
            dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, H / 2, W / 2 - 1);
        }

        // Title + Bitochi attribution
        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 12 / 100, Graphics.FONT_SMALL,
                    "PINBALL", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 22 / 100, Graphics.FONT_SMALL,
                    "PRO", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, H * 32 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Mini demo bumpers
        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 28, H * 42 / 100, 6);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx,      H * 42 / 100, 6);
        dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 28, H * 42 / 100, 6);

        // Chess-style rows — now THREE: Table + START + LEADERBOARD.
        // Whole menu is ~18% more compact than the two-row layout and
        // space-aware: row height shrinks to whatever fits between the
        // demo bumpers and the BEST line so nothing overlaps on small
        // round watches.
        var labels = [
            "Table: " + TableLibrary.NAMES[_ctrl.tableIdx],
            "START",
            ""
        ];
        var rg   = menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        var selRow = _ctrl.menuCursor;
        for (var i = 0; i < MI_ITEMS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            var sel = (i == selRow);

            if (i == MI_LB) {
                // Hype-y gold leaderboard row from the shared library.
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

        // Best score
        if (_ctrl.hi > 0) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, H * 87 / 100, Graphics.FONT_XTINY,
                        "BEST " + _formatScore(_ctrl.hi),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Space-aware geometry for the three-row chess menu. Rows live
    // below the demo bumpers and above the BEST line; the row height
    // shrinks to fit so the LEADERBOARD row never overlaps anything on
    // small round watches. All numbers ~18% smaller than the old
    // two-row layout. Returns [rowH, rowW, rowX, rowY0, gap].
    function menuRowGeom() {
        var W = _ctrl.screenW;
        var H = _ctrl.screenH;
        var topZone      = (H * 47) / 100;          // rows start below bumpers
        var bottomMargin = (H * 14) / 100; if (bottomMargin < 14) { bottomMargin = 14; }
        var gap          = (H * 2) / 100;  if (gap < 3) { gap = 3; }
        var avail        = (H - bottomMargin) - topZone;
        var rowH         = (avail - gap * (MI_ITEMS - 1)) / MI_ITEMS;
        if (rowH > 25) { rowH = 25; }               // ~10% more compact
        if (rowH < 13) { rowH = 13; }
        var rowW = (W * 58) / 100; if (rowW < 104) { rowW = 104; }
        var rowX = (W - rowW) / 2;
        var used = MI_ITEMS * rowH + (MI_ITEMS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // Comma-grouped thousands.
    hidden function _formatScore(n) {
        var s = n.format("%d");
        var len = s.length();
        if (len <= 3) { return s; }
        var out = "";
        for (var i = 0; i < len; i++) {
            if (i > 0 && (len - i) % 3 == 0) { out = out + ","; }
            out = out + s.substring(i, i + 1);
        }
        return out;
    }

    // ── Input intents ───────────────────────────────────────────────
    // Unified flipper hold (used by button + touch-hold paths).
    function flipBothPress()   { _ctrl.holdBothFlippers();    }
    function flipBothRelease() { _ctrl.releaseBothFlippers(); }
    // Tap-fallback pulse (used only when onTap fires without an
    // accompanying onDrag pair — Flipper.pulse self-releases).
    function tapPulseFlippers() { _ctrl.tapPulseFlippers(16); }
    // Launch and state nav (used by both onTap and onDrag-STOP path
    // when the player taps in launch/menu/over state).
    function launchBall() { _ctrl.launchBall(); }
    function gotoMenu()   { _ctrl.gotoMenu();   }
    function confirm() {
        // The LEADERBOARD row pushes a view, which the controller can't
        // do — intercept it here before delegating to the controller.
        if (_ctrl.state == GS_MENU && _ctrl.menuCursor == MI_LB) {
            openLeaderboard();
            return;
        }
        _ctrl.selectAction();
    }
    function menuPrev()   { _ctrl.menuPrev(); }
    function menuNext()   { _ctrl.menuNext(); }

    // Open the shared global leaderboard for the current table.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID,
                                 TableLibrary.NAMES[_ctrl.tableIdx],
                                 "PINBALL PRO");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function handleBack() {
        // Back to the shared menu.
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
