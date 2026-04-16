using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.System;

// ── States ──────────────────────────────────────────────────────────────────
const DC_HOME = 0;  // category grid
const DC_LIST = 1;  // message list within category
const DC_SHOW = 2;  // full-screen message (buddy reads this)

// ── Category indices ─────────────────────────────────────────────────────────
const CAT_OK    = 0;
const CAT_AIR   = 1;
const CAT_MOVE  = 2;
const CAT_ISSUE = 3;
const CAT_SOS   = 4;

class DiverCommView extends WatchUi.View {

    hidden var _w;
    hidden var _h;
    hidden var _timer;
    hidden var _tick;

    hidden var _gs;
    hidden var _catIdx;
    hidden var _msgIdx;

    hidden var _cats;
    hidden var _catColors;
    hidden var _msgCounts;
    hidden var _msgs;

    function initialize() {
        View.initialize();
        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;
        _tick   = 0;
        _gs     = DC_HOME;
        _catIdx = 0;
        _msgIdx = 0;

        // Categories ordered strictly by frequency of use underwater.
        // OK first (most common signal), SOS last (rare but critical).
        _cats = ["OK", "AIR", "MOVE", "ISSUE", "SOS"];

        _catColors = [0x00CC44, 0x0088CC, 0xFFAA00, 0xFF6600, 0xFF2222];

        // Messages ordered by real-world frequency within each category.
        // Max 4 per category → all visible at once on LIST screen without scroll.
        // First message in each category = most common = fewest total clicks.
        _msgs = [
            // OK (0) — acknowledgement + basic replies (used every few minutes)
            ["OK", "YES", "NO", "WAIT"],
            // AIR (1) — gas checks (critical, done regularly)
            ["AIR OK?", "LOW AIR!", "SHARE AIR?"],
            // MOVE (2) — directional commands
            ["UP NOW", "FOLLOW ME", "STOP!", "TURN BACK"],
            // ISSUE (3) — problems that need attention but aren't SOS yet
            ["CHECK ME", "NOT OK", "EQUIP FAIL", "SAY AGAIN"],
            // SOS (4) — life-threatening emergencies only
            ["HELP!", "OUT OF AIR!", "ABORT DIVE", "COME NOW!"]
        ];

        _msgCounts = [4, 3, 4, 4, 4];
    }

    function onShow() {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 100, true);
        }
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onLayout(dc) {
        _w = dc.getWidth() * 9 / 10;
        _h = dc.getHeight() * 9 / 10;
    }

    function onTick() as Void {
        _tick++;
        WatchUi.requestUpdate();
    }

    // ── Public input interface ───────────────────────────────────────────────

    function doUp() {
        if (_gs == DC_HOME) {
            _catIdx = (_catIdx + 4) % 5;
            _msgIdx = 0;
        } else if (_gs == DC_LIST || _gs == DC_SHOW) {
            var n = _msgCounts[_catIdx];
            _msgIdx = (_msgIdx + n - 1) % n;
        }
    }

    function doDown() {
        if (_gs == DC_HOME) {
            _catIdx = (_catIdx + 1) % 5;
            _msgIdx = 0;
        } else if (_gs == DC_LIST || _gs == DC_SHOW) {
            var n = _msgCounts[_catIdx];
            _msgIdx = (_msgIdx + 1) % n;
        }
    }

    function doSelect() {
        if (_gs == DC_HOME) {
            _msgIdx = 0;
            _gs = DC_LIST;
        } else if (_gs == DC_LIST) {
            _gs = DC_SHOW;
            _vibeForCat(_catIdx);
        } else if (_gs == DC_SHOW) {
            _gs = DC_LIST;
        }
    }

    function doBack() {
        if (_gs == DC_SHOW) { _gs = DC_LIST; return true; }
        if (_gs == DC_LIST) { _gs = DC_HOME; return true; }
        return false;
    }

    // Long press → instant HELP! from anywhere
    function doEmergency() {
        _catIdx = CAT_SOS;
        _msgIdx = 0;
        _gs = DC_SHOW;
        _vibeEmergency();
    }

    function doTap(tx, ty) {
        if (_gs == DC_HOME) {
            var tileH = (_h - 13) / 5;
            if (tileH < 1) { tileH = 1; }
            var tapped = ty / tileH;
            if (tapped >= 0 && tapped < 5) {
                _catIdx = tapped;
                _msgIdx = 0;
                _gs = DC_LIST;
            }
        } else if (_gs == DC_LIST) {
            var hdrH = _listHdrH();
            var n    = _msgCounts[_catIdx];
            var rowH = (_h - hdrH - 14) / n;
            if (rowH < 1) { rowH = 1; }
            if (ty < hdrH) { _gs = DC_HOME; return; }
            var row = (ty - hdrH) / rowH;
            if (row >= 0 && row < n) {
                _msgIdx = row;
                _gs = DC_SHOW;
                _vibeForCat(_catIdx);
            }
        } else if (_gs == DC_SHOW) {
            _gs = DC_LIST;
        }
    }

    // ── Rendering ────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        if (_w == 0) { _w = dc.getWidth() * 9 / 10; _h = dc.getHeight() * 9 / 10; }
        if      (_gs == DC_HOME) { _drawHome(dc); }
        else if (_gs == DC_LIST) { _drawList(dc); }
        else if (_gs == DC_SHOW) { _drawShow(dc); }
    }

    // ── HOME — category selection ─────────────────────────────────────────────

    hidden function _drawHome(dc) {
        dc.setColor(0x000000, 0x000000);
        dc.clear();

        // tileH fills exactly (_h - 14) leaving room for the hint strip.
        var tileH    = (_h - 13) / 5;
        var fntSel   = (tileH >= 70) ? Graphics.FONT_LARGE  : (tileH >= 38) ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
        var fntUnsel = (tileH >= 70) ? Graphics.FONT_MEDIUM : (tileH >= 38) ? Graphics.FONT_SMALL  : Graphics.FONT_XTINY;
        var hSel     = dc.getFontHeight(fntSel);
        var hUnsel   = dc.getFontHeight(fntUnsel);

        for (var i = 0; i < 5; i++) {
            var ty  = i * tileH;
            var col = _catColors[i];
            var sel = (i == _catIdx);
            var tY  = ty + (tileH - (sel ? hSel : hUnsel)) / 2;

            if (sel) {
                // Selected: full-colour fill, black text
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(0, ty, _w, tileH - 1);
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w / 2, tY, fntSel, _cats[i], Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                // Unselected: coloured left strip + dim text + count
                dc.setColor(_darken(col), Graphics.COLOR_TRANSPARENT);
                var stripW = _w * 15 / 1000; if (stripW < 3) { stripW = 3; }
                dc.fillRectangle(0, ty, stripW, tileH - 1);
                dc.setColor(_darken(col), Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w * 10 / 100, tY, fntUnsel, _cats[i], Graphics.TEXT_JUSTIFY_LEFT);
                dc.setColor(0x2A2A2A, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_w - 6, tY, fntUnsel, "" + _msgCounts[i], Graphics.TEXT_JUSTIFY_RIGHT);
            }

            if (i < 4) {
                dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(0, ty + tileH - 1, _w, ty + tileH - 1);
            }
        }

        dc.setColor(0x1E1E1E, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h - _h * 5 / 100, Graphics.FONT_XTINY, "HOLD=SOS", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── LIST — messages within category ──────────────────────────────────────

    // All messages fit at once (max 4) → no scroll, giant tap targets.
    hidden function _drawList(dc) {
        dc.setColor(0x000000, 0x000000);
        dc.clear();

        var col  = _catColors[_catIdx];
        var n    = _msgCounts[_catIdx];
        var hdrH = _listHdrH();
        var rowH = (_h - hdrH - 14) / n;

        // Adaptive font based on available row height
        var fnt;
        var fntH;
        if      (rowH >= 70) { fnt = Graphics.FONT_LARGE;  }
        else if (rowH >= 38) { fnt = Graphics.FONT_MEDIUM; }
        else if (rowH >= 26) { fnt = Graphics.FONT_SMALL;  }
        else                 { fnt = Graphics.FONT_XTINY;  }
        fntH = dc.getFontHeight(fnt);

        // Header
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, _w, hdrH);
        var hdrFont = (hdrH >= 40) ? Graphics.FONT_SMALL : Graphics.FONT_XTINY;
        var hdrFH = dc.getFontHeight(hdrFont);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, (hdrH - hdrFH) / 2, hdrFont,
                    _cats[_catIdx], Graphics.TEXT_JUSTIFY_CENTER);

        // Message rows — all visible, no scroll needed
        for (var i = 0; i < n; i++) {
            var ry  = hdrH + i * rowH;
            var sel = (i == _msgIdx);
            var msg = _msgs[_catIdx][i];
            var tY  = ry + (rowH - fntH) / 2;

            if (sel) {
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(_w * 3 / 100, ry + 2, _w * 94 / 100, rowH - 4, 4);
                dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(_darken(col), Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(_w / 2, tY, fnt, msg, Graphics.TEXT_JUSTIFY_CENTER);

            if (i < n - 1) {
                dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(0, ry + rowH - 1, _w, ry + rowH - 1);
            }
        }

        dc.setColor(0x1E1E1E, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h - _h * 5 / 100, Graphics.FONT_XTINY,
                    "SEL=show  BACK=menu", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── SHOW — full screen, buddy reads this ─────────────────────────────────

    hidden function _drawShow(dc) {
        var col   = _catColors[_catIdx];
        var isSOS = (_catIdx == CAT_SOS);
        var flash = (_tick % 5 < 2);

        if (isSOS && flash) {
            dc.setColor(0xFF0000, 0xFF0000);
        } else {
            dc.setColor(0x000000, 0x000000);
        }
        dc.clear();

        // Thick coloured border — visible at arm's length
        var bC = isSOS ? (flash ? 0xFFFFFF : 0xFF2222) : col;
        dc.setColor(bC, Graphics.COLOR_TRANSPARENT);
        var bW = _w * 15 / 1000; if (bW < 3) { bW = 3; }
        for (var b = 0; b < bW; b++) {
            dc.drawRectangle(b, b, _w - b * 2, _h - b * 2);
        }

        dc.setColor(_darken(bC), Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h * 3 / 100, Graphics.FONT_XTINY, _cats[_catIdx], Graphics.TEXT_JUSTIFY_CENTER);

        // Message — maximum readable size, dynamically centered
        var textC = isSOS ? (flash ? 0xFFFFFF : 0xFF2222) : col;
        dc.setColor(textC, Graphics.COLOR_TRANSPARENT);
        _drawMsgLarge(dc, _msgs[_catIdx][_msgIdx]);

        // Message counter (N / M)
        var n = _msgCounts[_catIdx];
        dc.setColor(0x2A2A2A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_w / 2, _h - _h * 8 / 100, Graphics.FONT_XTINY,
                    "" + (_msgIdx + 1) + " / " + n, Graphics.TEXT_JUSTIFY_CENTER);

        if (_tick % 18 > 9) {
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_w / 2, _h - _h * 4 / 100, Graphics.FONT_XTINY,
                        "^/v msg  tap=back", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Large-text renderer ──────────────────────────────────────────────────
    // Centres the message in the safe zone between category label and counter.
    hidden function _drawMsgLarge(dc, msg) {
        var len   = msg.length();
        var line1 = msg;
        var line2 = "";

        // Split at nearest space to midpoint
        if (len > 6) {
            var mid      = len / 2;
            var bestI    = -1;
            var bestDist = len + 1;
            for (var i = 0; i < len; i++) {
                if (msg.substring(i, i + 1).equals(" ")) {
                    var d = (i - mid).abs();
                    if (d < bestDist) { bestDist = d; bestI = i; }
                }
            }
            if (bestI > 0) {
                line1 = msg.substring(0, bestI);
                line2 = msg.substring(bestI + 1, len);
            }
        }

        // Usable zone: below category label (y≈22), above counter (y≈_h-29)
        var zoneTop = _h * 7 / 100;
        var zoneBot = _h - _h * 9 / 100;
        var zoneMid = (zoneTop + zoneBot) / 2;

        if (line2.equals("")) {
            var fnt;
            var fntH;
            if      (len <= 5)  { fnt = Graphics.FONT_LARGE;  }
            else if (len <= 10) { fnt = Graphics.FONT_MEDIUM; }
            else                { fnt = Graphics.FONT_SMALL;  }
            fntH = dc.getFontHeight(fnt);
            dc.drawText(_w / 2, zoneMid - fntH / 2, fnt, line1, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var maxL = line1.length() > line2.length() ? line1.length() : line2.length();
            var fnt;
            var fntH;
            if      (maxL <= 5) { fnt = Graphics.FONT_LARGE;  }
            else if (maxL <= 8) { fnt = Graphics.FONT_MEDIUM; }
            else                { fnt = Graphics.FONT_SMALL;  }
            fntH = dc.getFontHeight(fnt);
            var gap = fntH + 4;
            dc.drawText(_w / 2, zoneMid - gap, fnt, line1, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(_w / 2, zoneMid + 4,   fnt, line2, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    hidden function _listHdrH() {
        var h = _h * 13 / 100;
        if (h < 18) { h = 18; }
        return h;
    }

    hidden function _darken(col) {
        return (col >> 1) & 0x7F7F7F;
    }

    hidden function _vibeForCat(cat) {
        if (!(Toybox has :Attention) || !(Toybox.Attention has :vibrate)) { return; }
        var p;
        if (cat == CAT_SOS) {
            p = [new Toybox.Attention.VibeProfile(100, 300),
                 new Toybox.Attention.VibeProfile(0,   100),
                 new Toybox.Attention.VibeProfile(100, 300)];
        } else if (cat == CAT_AIR) {
            p = [new Toybox.Attention.VibeProfile(80, 200),
                 new Toybox.Attention.VibeProfile(0,  100),
                 new Toybox.Attention.VibeProfile(80, 200)];
        } else {
            p = [new Toybox.Attention.VibeProfile(60, 150)];
        }
        Toybox.Attention.vibrate(p);
    }

    hidden function _vibeEmergency() {
        if (!(Toybox has :Attention) || !(Toybox.Attention has :vibrate)) { return; }
        Toybox.Attention.vibrate([
            new Toybox.Attention.VibeProfile(100, 400),
            new Toybox.Attention.VibeProfile(0,   100),
            new Toybox.Attention.VibeProfile(100, 400),
            new Toybox.Attention.VibeProfile(0,   100),
            new Toybox.Attention.VibeProfile(100, 400)
        ]);
    }
}
