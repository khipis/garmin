// ═══════════════════════════════════════════════════════════════════════════
// ZsHud.mc — Every screen that is not the yard or the street.
//
// The furniture is lifted wholesale from FARM, because FARM's proportions are
// already tuned for a round dial: a tab strip in the top fifth (page name in
// the small pixel font, then a row of dots), a content band from 21% to 92%,
// list rows exactly 15% of the height in a column 80% wide, and every overlay
// built out of the same button, bar and wrap helpers. Only the palette is
// different — this compound never gets a nice day.
//
// Fonts, by role:
//   page title      pixel font, sc = h/190
//   ribbon / meta   pixel font, sc = h/220
//   big number      FONT_SMALL, occasionally FONT_MEDIUM for the countdown
//   card name       FONT_TINY
//   everything else FONT_XTINY
//
// Tap targets are recorded into `rows` / `rowIds` / `tabRects` as they are
// drawn, so the view never has to re-derive the geometry it is hit-testing.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;

module ZsHud {

    // ── Palette ─────────────────────────────────────────────────────────────
    // Every value comes out of the 00/55/AA/FF cube the panel quantises to, so
    // nothing drifts hue on the watch. Panels are black with a lit edge rather
    // than grey fills: a dark game should not have grey furniture.
    const PANEL    = 0x000000;
    const PANEL_HI = 0x550000;
    const EDGE     = 0x555555;
    const TEXT     = 0xFFFFFF;
    const MUTED    = 0xAAAAAA;
    const DIM      = 0x555555;

    // ── Tap registry, rebuilt every frame ───────────────────────────────────
    var rows = [];
    var rowIds = [];
    var tabRects = [];
    var btnA = null;

    function reset() { rows = []; rowIds = []; tabRects = []; btnA = null; }

    // ── Primitives ──────────────────────────────────────────────────────────
    function _col(dc, c) { dc.setColor(c, Graphics.COLOR_TRANSPARENT); }
    function _rect(dc, x, y, w, h, c) {
        if (w < 1) { w = 1; }
        if (h < 1) { h = 1; }
        _col(dc, c);
        dc.fillRectangle(x, y, w, h);
    }
    function _txt(dc, x, y, f, s, col, just) {
        _col(dc, col);
        dc.drawText(x, y, f, s, just);
    }
    // Hard black backing, so a caption survives being drawn over the yard.
    function _shadow(dc, x, y, f, s, col, just) {
        _col(dc, 0x000000);
        dc.drawText(x + 1, y + 1, f, s, just);
        _col(dc, col);
        dc.drawText(x, y, f, s, just);
    }
    function _psc(h) { var s = h / 190; return s < 2 ? 2 : s; }   // title scale
    function _msc(h) { var s = h / 220; return s < 2 ? 2 : s; }   // meta scale

    function _fmt(n) {
        if (n < 0) { n = 0; }
        if (n >= 1000000) { return (n / 1000000).format("%d") + "." + ((n / 100000) % 10).format("%d") + "M"; }
        if (n >= 10000)   { return (n / 1000).format("%d") + "K"; }
        if (n >= 1000)    { return (n / 1000).format("%d") + "." + ((n / 100) % 10).format("%d") + "K"; }
        return n.format("%d");
    }

    // "04h 12m" far out, "12m 30s" inside the last hour. Seconds only appear
    // when they mean something; a countdown nine hours out is just noise.
    function countdown(secs) {
        var s = secs;
        if (s < 0) { s = 0; }
        var hh = s / 3600;
        var mm = (s % 3600) / 60;
        var ss = s % 60;
        if (hh > 0) { return hh.format("%d") + "H " + mm.format("%02d") + "M"; }
        return mm.format("%d") + "M " + ss.format("%02d") + "S";
    }

    // ── Text fitting ────────────────────────────────────────────────────────
    function _split(s) {
        var out = [];
        var cur = "";
        for (var i = 0; i < s.length(); i++) {
            var ch = s.substring(i, i + 1);
            if (ch.equals(" ")) {
                if (cur.length() > 0) { out.add(cur); cur = ""; }
            } else { cur += ch; }
        }
        if (cur.length() > 0) { out.add(cur); }
        return out;
    }
    // One line, truncated with an ellipsis rather than spilling off the dial.
    function _wrap1(dc, x, y, maxw, font, col, s) {
        var str = s;
        while (str.length() > 4 && dc.getTextWidthInPixels(str, font) > maxw) {
            str = str.substring(0, str.length() - 2);
        }
        if (!str.equals(s)) { str = str + ".."; }
        _txt(dc, x, y, font, str, col, Graphics.TEXT_JUSTIFY_LEFT);
    }
    // Centred, word-wrapped, capped at maxLines. Returns the Y under the block
    // so callers can stack paragraphs without measuring anything themselves.
    function _wrapN(dc, cx, y, maxw, font, col, s, maxLines) {
        _col(dc, col);
        var fh = dc.getFontHeight(font) * 85 / 100;
        var words = _split(s);
        var i = 0;
        var line = 0;
        while (i < words.size() && line < maxLines) {
            var cur = words[i]; i++;
            while (i < words.size()) {
                var cand = cur + " " + words[i];
                if (dc.getTextWidthInPixels(cand, font) > maxw) { break; }
                cur = cand; i++;
            }
            while (cur.length() > 3 && dc.getTextWidthInPixels(cur, font) > maxw) {
                cur = cur.substring(0, cur.length() - 1);
            }
            if (line == maxLines - 1 && i < words.size()) {
                while (cur.length() > 3 && dc.getTextWidthInPixels(cur + "..", font) > maxw) {
                    cur = cur.substring(0, cur.length() - 1);
                }
                cur += "..";
            }
            dc.drawText(cx, y + line * fh, font, cur, Graphics.TEXT_JUSTIFY_CENTER);
            line++;
        }
        return y + line * fh;
    }
    // Drop a font size rather than truncate, then truncate if it still will
    // not fit. Used for anything the player wrote us a long string for.
    function _txtFit(dc, cx, y, f, col, s, maxw) {
        var fonts = [f, Graphics.FONT_TINY, Graphics.FONT_XTINY];
        var use = f;
        for (var i = 0; i < fonts.size(); i++) {
            use = fonts[i];
            if (dc.getTextWidthInPixels(s, use) <= maxw) { break; }
        }
        var str = s;
        while (str.length() > 3 && dc.getTextWidthInPixels(str, use) > maxw) {
            str = str.substring(0, str.length() - 1);
        }
        _shadow(dc, cx, y, use, str, col, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Components ──────────────────────────────────────────────────────────
    function _button(dc, r, label, hot) {
        _col(dc, hot ? PANEL_HI : PANEL);
        dc.fillRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        _col(dc, hot ? Zs.ACCENT : EDGE);
        dc.drawRoundedRectangle(r[0], r[1], r[2], r[3], 6);
        _col(dc, hot ? TEXT : MUTED);
        dc.drawText(r[0] + r[2] / 2, r[1] + r[3] / 2, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    function _bar(dc, x, y, w, h, pct, col) {
        var p = pct;
        if (p < 0) { p = 0; }
        if (p > 100) { p = 100; }
        _col(dc, 0x555555);
        dc.fillRoundedRectangle(x, y, w, h, h / 2);
        var fw = w * p / 100;
        if (fw > 0) {
            if (fw < h) { fw = h; }
            _col(dc, col);
            dc.fillRoundedRectangle(x, y, fw, h, h / 2);
        }
    }
    // The page background. Black, with the dial itself picked out a shade
    // above it so the screen has an edge on a round watch.
    function _bg(dc, w, h) {
        dc.setColor(0x000000, 0x000000);
        dc.clear();
        if (w == h) {
            _col(dc, 0x000000);
            dc.fillCircle(w / 2, h / 2, w / 2 - 1);
        }
    }

    // ── The tab strip ───────────────────────────────────────────────────────
    // Page name, then a dot per page. Both live in the top fifth, where a
    // round screen has the least to lose, and the dots double as tap targets.
    function pageName(p) {
        var a = ["COMPOUND", "BUILD", "TONIGHT", "JOURNAL", "SALVAGE"];
        return a[p < 0 ? 0 : (p > 4 ? 4 : p)];
    }
    function pageColor(p) {
        var a = [Zs.ACCENT, Zs.WARN, Zs.DANGER, 0xAAAAAA, 0xFFAA00];
        return a[p < 0 ? 0 : (p > 4 ? 4 : p)];
    }

    function tabStrip(dc, w, h, page, n) {
        var cx = w / 2;
        var sc = _psc(h);
        Px.gshC(dc, pageName(page), cx, h * 6 / 100, sc, pageColor(page));

        var y = h * 15 / 100;
        var gap = w * 8 / 100;
        var x0 = cx - gap * (n - 1) / 2;
        for (var i = 0; i < n; i++) {
            var dx = x0 + i * gap;
            _col(dc, i == page ? pageColor(page) : 0x555555);
            dc.fillCircle(dx, y, i == page ? 4 : 2);
            tabRects.add([dx - gap / 2, h * 10 / 100, gap, h * 9 / 100]);
        }
        // Chevrons, so the carousel is discoverable without a tutorial. Kept
        // well inside the bezel: at this height a round dial has already
        // started curving away.
        _col(dc, 0x555555);
        dc.fillPolygon([[w * 10 / 100, y], [w * 13 / 100, y - 4], [w * 13 / 100, y + 4]]);
        dc.fillPolygon([[w * 90 / 100, y], [w * 87 / 100, y - 4], [w * 87 / 100, y + 4]]);
    }

    // ── The list frame ──────────────────────────────────────────────────────
    // One geometry for every scrolling page: rows 15% of the height, in a
    // column 80% wide, between 21% and 92%. The selected row is kept inside
    // the window rather than centred, so a short list does not jump.
    const LIST_TOP = 21;
    const LIST_BOT = 88;
    const ROW_PCT  = 15;

    function listTop(count, cur, h) {
        var rh = h * ROW_PCT / 100;
        if (rh < 1) { rh = 1; }
        var maxRows = (h * LIST_BOT / 100 - h * LIST_TOP / 100) / rh;
        if (maxRows < 1) { maxRows = 1; }
        var top = cur - maxRows / 2;
        if (top > count - maxRows) { top = count - maxRows; }
        if (top < 0) { top = 0; }
        return top;
    }
    function listRows(h) {
        var rh = h * ROW_PCT / 100;
        if (rh < 1) { rh = 1; }
        var n = (h * LIST_BOT / 100 - h * LIST_TOP / 100) / rh;
        return n < 1 ? 1 : n;
    }

    // ── Screen: BUILD ───────────────────────────────────────────────────────
    function base(dc, w, h, m, sel, t) {
        _bg(dc, w, h);
        var rh = h * ROW_PCT / 100;
        var top = listTop(Zs.D_N, sel, h);
        var maxRows = listRows(h);
        var x = w * 11 / 100;
        var cw = w * 78 / 100;

        for (var vi = 0; vi < maxRows; vi++) {
            var id = top + vi;
            if (id >= Zs.D_N) { break; }
            var y = h * LIST_TOP / 100 + vi * rh;
            var on = (id == sel);
            _col(dc, on ? PANEL_HI : PANEL);
            dc.fillRoundedRectangle(x, y, cw, rh - 3, 6);
            _col(dc, on ? Zs.dColor(id) : 0x555555);
            dc.drawRoundedRectangle(x, y, cw, rh - 3, 6);
            _buildRow(dc, w, h, m, id, x + 4, y, cw - 8, rh - 3, on);
            rows.add([x, y, cw, rh - 3]);
            rowIds.add(id);
        }
        _scrollRail(dc, w, h, Zs.D_N, sel);
    }

    // Icon on the left, name and level on the top line, price or effect
    // underneath — the same two-line row FARM uses for its build list.
    function _buildRow(dc, w, h, m, id, x, y, rw, rh, on) {
        var lvl = m.dLevel[id];
        var cost = m.upgradeCost(id);
        var maxed = lvl >= Zs.D_LVL_MAX;
        var afford = !maxed && m.scrap >= cost;
        var col = Zs.dColor(id);

        _defIcon(dc, id, x + rh / 2, y + rh / 2, rh * 30 / 100,
                 lvl > 0 ? col : 0x555555);

        var tx = x + rh + 2;
        var nw = rw - rh - 4;
        var nm = Zs.dName(id) + (lvl > 0 ? "  L" + lvl.format("%d") : "");
        _wrap1(dc, tx, y + rh * 14 / 100, nw, Graphics.FONT_XTINY,
               on ? TEXT : (lvl > 0 ? MUTED : DIM), nm);

        var sub;
        var scol;
        if (maxed) {
            sub = "MAX  " + Zs.dDesc(id);
            scol = col;
        } else {
            sub = _fmt(cost) + " SCRAP";
            scol = afford ? Zs.WARN : 0x555500;
        }
        _wrap1(dc, tx, y + rh * 50 / 100, nw, Graphics.FONT_XTINY, scol, sub);
    }

    // Scroll position as a rail down the right edge of the dial.
    function _scrollRail(dc, w, h, count, cur) {
        var railY = h * LIST_TOP / 100;
        var railH = h * (LIST_BOT - LIST_TOP) / 100;
        _rect(dc, w * 95 / 100, railY, 2, railH, 0x555555);
        var knob = railH / count + 4;
        _rect(dc, w * 95 / 100, railY + railH * cur / count, 2, knob, Zs.ACCENT);
    }

    // One silhouette per defence, built from two or three shapes. At this size
    // a recognisable outline beats detail every time.
    function _defIcon(dc, id, cx, cy, u, col) {
        if (u < 3) { u = 3; }
        _col(dc, col);
        if (id == Zs.D_WALL) {
            for (var r = 0; r < 3; r++) {
                for (var c = 0; c < 2; c++) {
                    var ox = (r % 2) * u / 2;
                    dc.fillRectangle(cx - u + c * u + ox - u / 4, cy - u + r * u * 2 / 3,
                                     u * 9 / 10, u * 3 / 5);
                }
            }
        } else if (id == Zs.D_GATE) {
            // Two leaves in a frame, with a brace across each.
            dc.fillRectangle(cx - u, cy - u, u * 2, u * 2);
            _col(dc, 0x000000);
            dc.fillRectangle(cx - u / 8, cy - u, u / 4, u * 2);
            dc.fillRectangle(cx - u * 3 / 4, cy - u * 3 / 4, u / 2, u / 3);
            dc.fillRectangle(cx + u / 4, cy - u * 3 / 4, u / 2, u / 3);
            dc.fillRectangle(cx - u * 3 / 4, cy + u / 4, u / 2, u / 3);
            dc.fillRectangle(cx + u / 4, cy + u / 4, u / 2, u / 3);
        } else if (id == Zs.D_MG) {
            dc.fillRectangle(cx - u, cy, u * 2, u / 2);
            dc.fillRectangle(cx - u / 2, cy - u / 2, u, u / 2);
            dc.fillRectangle(cx - u / 4, cy - u, u * 3 / 2, u / 3);
        } else if (id == Zs.D_MORTAR) {
            dc.fillPolygon([[cx - u / 2, cy + u / 2], [cx, cy - u],
                            [cx + u / 2, cy - u * 2 / 3], [cx, cy + u / 2]]);
            dc.fillRectangle(cx - u, cy + u / 2, u * 2, u / 3);
        } else if (id == Zs.D_TESLA) {
            dc.fillRectangle(cx - u / 6, cy - u / 3, u / 3, u * 4 / 3);
            dc.fillCircle(cx, cy - u / 2, u / 2);
            dc.drawLine(cx - u, cy - u, cx + u, cy - u / 4);
        } else if (id == Zs.D_SPIKES) {
            for (var s = 0; s < 3; s++) {
                var sx = cx - u + s * u;
                dc.fillPolygon([[sx, cy - u], [sx - u / 3, cy + u], [sx + u / 3, cy + u]]);
            }
        } else if (id == Zs.D_WIRE) {
            dc.setPenWidth(1);
            for (var k = 0; k < 3; k++) { dc.drawCircle(cx - u + k * u, cy, u / 2 + 1); }
        } else if (id == Zs.D_REPAIR) {
            dc.fillRectangle(cx - u, cy - u / 4, u * 2, u / 2);
            dc.fillRectangle(cx - u / 4, cy - u, u / 2, u * 2);
            _col(dc, 0x000000);
            dc.fillCircle(cx, cy, u / 4);
        } else if (id == Zs.D_PLATING) {
            dc.fillPolygon([[cx, cy - u], [cx + u, cy - u / 3],
                            [cx, cy + u], [cx - u, cy - u / 3]]);
            _col(dc, 0x000000);
            dc.fillRectangle(cx - u / 3, cy - u / 3, u * 2 / 3, u * 2 / 3);
        } else if (id == Zs.D_SALVAGE) {
            dc.fillRectangle(cx - u, cy, u * 2, u * 2 / 3);
            dc.fillRectangle(cx - u * 2 / 3, cy - u * 2 / 3, u * 4 / 3, u * 2 / 3);
            dc.fillRectangle(cx - u / 3, cy - u * 4 / 3, u * 2 / 3, u * 2 / 3);
        } else {
            dc.fillRectangle(cx - u, cy - u / 6, u * 2, u / 3);
            dc.fillRectangle(cx + u / 3, cy - u / 2, u / 2, u);
            dc.fillRectangle(cx - u, cy - u / 2, u / 3, u / 3);
        }
        dc.setPenWidth(1);
    }

    // The hint strip. Sits inside the list band's bottom edge rather than off
    // the dial, and doubles as the toast for a purchase.
    function strip(dc, w, h, text, col) {
        // Pixel font, not XTINY: at this height the dial has curved in far
        // enough that a proper font loses its first and last word.
        var sc = _msc(h);
        var y = h * 89 / 100;
        var bh = 5 * sc + h * 4 / 100;
        _rect(dc, 0, y, w, bh, 0x000000);
        _rect(dc, w * 26 / 100, y, w * 48 / 100, 1, 0x555555);
        Px.gshC(dc, _wrapPx(text, sc, w * 52 / 100), w / 2, y + h * 2 / 100, sc, col);
    }

    // Truncate to whatever the pixel font can fit in the given chord.
    function _wrapPx(s, sc, maxW) {
        if (s == null) { return ""; }
        var n = maxW / (4 * sc);
        if (n < 3) { n = 3; }
        return s.length() <= n ? s : s.substring(0, n - 1) + ".";
    }
    function baseHint(dc, w, h, sel) { strip(dc, w, h, Zs.dDesc(sel), 0xAAAAAA); }

    // A toast in the middle of the screen, FARM's popup with a red edge.
    function popup(dc, w, h, text, col) {
        var cx = w / 2;
        var pw = w * 84 / 100;
        var px = cx - pw / 2;
        var ph = h * 13 / 100;
        var py = h * 44 / 100;
        _col(dc, 0x000000);
        dc.fillRoundedRectangle(px, py, pw, ph, 8);
        _col(dc, col);
        dc.drawRoundedRectangle(px, py, pw, ph, 8);
        _wrapN(dc, cx, py + ph / 2 - h * 4 / 100, pw - 14, Graphics.FONT_XTINY,
               TEXT, text, 2);
    }

    // ── Screen: TONIGHT ─────────────────────────────────────────────────────
    function preview(dc, w, h, m, wv, t) {
        _bg(dc, w, h);
        var cx = w / 2;
        var mod = wv["mod"];

        _shadow(dc, cx, h * 22 / 100, Graphics.FONT_NUMBER_MILD,
                wv["count"].format("%d"), Zs.DANGER, Graphics.TEXT_JUSTIFY_CENTER);
        Px.gshC(dc, wv["boss"] ? "DEAD + ABOMINATION" : "DEAD", cx, h * 40 / 100,
                _msc(h), wv["boss"] ? Zs.FIRE : 0xAAAAAA);

        _shadow(dc, cx, h * 44 / 100, Graphics.FONT_XTINY, Zs.modName(mod),
                Zs.modColor(mod), Graphics.TEXT_JUSTIFY_CENTER);
        _txtFit(dc, cx, h * 52 / 100, Graphics.FONT_XTINY, 0xAAAAAA,
                Zs.modDesc(mod), w * 84 / 100);

        // The countdown gets the room it deserves: it is the only number on
        // any screen in this game that moves on its own.
        _shadow(dc, cx, h * 61 / 100, Graphics.FONT_MEDIUM, countdown(m.secsToWave()),
                Zs.ACCENT, Graphics.TEXT_JUSTIFY_CENTER);

        // A reading, not a promise. The night wobbles by a tenth either way.
        var pct = readScore(m, wv) / 2;
        if (pct > 100) { pct = 100; }
        _bar(dc, w * 18 / 100, h * 79 / 100, w * 64 / 100, 5, pct, readCol(m, wv));
        Px.gshC(dc, readText(m, wv), cx, h * 83 / 100, _msc(h), readCol(m, wv));
        Px.gshC(dc, "WALL " + m.wallPct.format("%d") + "%  FORT "
                + m.fortScore().format("%d"), cx, h * 88 / 100, _msc(h), 0x555555);
    }

    // Rough defence-against-horde reading, deliberately vague. Anything more
    // precise would answer the question the whole game is built on asking.
    function readScore(m, wv) {
        var l = m.dLevel;
        var dps = Zs.mgDmg(l[Zs.D_MG]) * 10 / Zs.mgRate(l[Zs.D_MG])
                + Zs.mortarDmg(l[Zs.D_MORTAR]) * 10 / Zs.mortarRate(l[Zs.D_MORTAR])
                + Zs.teslaDmg(l[Zs.D_TESLA]) * 10 * Zs.teslaChain(l[Zs.D_TESLA])
                  / Zs.teslaRate(l[Zs.D_TESLA])
                + Zs.spikeDmg(l[Zs.D_SPIKES]) / 3;
        var wall = (Zs.wallHp(l[Zs.D_WALL]) + Zs.gateHp(l[Zs.D_GATE])) * m.wallPct / 100;
        var power = dps * 6 + wall / 4;
        var threat = wv["count"] * wv["hpPct"] / 40;
        if (wv["boss"]) { threat += 140; }
        if (threat < 1) { threat = 1; }
        return power * 100 / threat;
    }
    function readText(m, wv) {
        var s = readScore(m, wv);
        if (s < 70)  { return "WE WILL NOT HOLD"; }
        if (s < 95)  { return "IT WILL BE CLOSE"; }
        if (s < 140) { return "WE SHOULD HOLD"; }
        return "LET THEM COME";
    }
    function readCol(m, wv) {
        var s = readScore(m, wv);
        if (s < 70)  { return Zs.DANGER; }
        if (s < 95)  { return Zs.WARN; }
        return Zs.ACCENT;
    }

    // ── Screen: JOURNAL ─────────────────────────────────────────────────────
    // What happened, newest first, on the same row geometry as the build list
    // so the two pages feel like the same book.
    function journal(dc, w, h, m, top, t) {
        _bg(dc, w, h);
        var log = m.log;
        var cx = w / 2;
        if (log == null || log.size() == 0) {
            _shadow(dc, cx, h * 44 / 100, Graphics.FONT_XTINY,
                    "NOTHING WORTH WRITING", 0xAAAAAA, Graphics.TEXT_JUSTIFY_CENTER);
            _shadow(dc, cx, h * 53 / 100, Graphics.FONT_XTINY, "YET.",
                    0x555555, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        _txtFit(dc, cx, h * 21 / 100, Graphics.FONT_XTINY, 0xAAAAAA,
                Zs.chapterLine(m.chapter()), w * 84 / 100);

        var rowH = h * 13 / 100;
        var y0 = h * 32 / 100;
        var n = 4;
        for (var i = 0; i < n; i++) {
            var idx = top + i;
            if (idx >= log.size()) { break; }
            var y = y0 + i * rowH;
            // A dot-and-rule timeline down the left, so the entries read as a
            // run of days rather than one paragraph.
            _col(dc, (idx == 0) ? Zs.ACCENT : 0x555555);
            dc.fillCircle(w * 11 / 100, y + rowH / 4, 2);
            if (idx + 1 < log.size() && i + 1 < n) {
                _rect(dc, w * 11 / 100, y + rowH / 4, 1, rowH, 0x555555);
            }
            _wrapN(dc, w * 56 / 100, y - h * 2 / 100, w * 74 / 100,
                   Graphics.FONT_XTINY, idx == 0 ? TEXT : MUTED, log[idx], 2);
        }
        if (log.size() > n) {
            var shown = top + n;
            if (shown > log.size()) { shown = log.size(); }
            Px.gshC(dc, shown.format("%d") + "/" + log.size().format("%d"),
                    cx, h * 87 / 100, _msc(h), 0x555555);
        }
    }

    // ── Screen: SALVAGE ─────────────────────────────────────────────────────
    // A display case. Empty sockets matter as much as full ones: the gaps are
    // what make the next find worth hoping for.
    const IT_COLS = 4;

    function finds(dc, w, h, m, sel, t) {
        _bg(dc, w, h);
        var cx = w / 2;
        Px.gshC(dc, m.itemsFound().format("%d") + " OF " + Zs.IT_N.format("%d")
                + " FOUND", cx, h * 21 / 100, _msc(h), Zs.WARN);

        // Size off both axes, the way FARM's collection grid does, so adding
        // an item adds a row instead of pushing cells off the bottom.
        var rowsN = (Zs.IT_N + IT_COLS - 1) / IT_COLS;
        if (rowsN < 1) { rowsN = 1; }
        var bandY = h * 27 / 100;
        var bandH = h * 48 / 100;
        var cell = w * 76 / 100 / IT_COLS;
        if (bandH / rowsN < cell) { cell = bandH / rowsN; }
        if (cell < 8) { cell = 8; }
        var gx = cx - cell * IT_COLS / 2;
        var gy = bandY + (bandH - cell * rowsN) / 2;

        for (var i = 0; i < Zs.IT_N; i++) {
            var r = i / IT_COLS;
            var c = i % IT_COLS;
            var px = gx + c * cell + cell / 2;
            var py = gy + r * cell + cell / 2;
            var owned = m.hasItem(i);
            var rar = Zs.itRarity(i);
            // A rarity-tinted socket behind every slot, so the grid reads as a
            // case rather than a row of identical dots.
            _col(dc, owned ? Px.shade(Zs.rarityColor(rar), 30) : 0x000000);
            dc.fillRoundedRectangle(px - cell * 44 / 100, py - cell * 44 / 100,
                                    cell * 88 / 100, cell * 88 / 100, 4);
            _col(dc, owned ? Zs.rarityColor(rar) : 0x555555);
            dc.drawRoundedRectangle(px - cell * 44 / 100, py - cell * 44 / 100,
                                    cell * 88 / 100, cell * 88 / 100, 4);
            if (owned) {
                itemGlyph(dc, i, px, py, cell * 26 / 100, Zs.rarityColor(rar));
            } else {
                _txt(dc, px, py - cell * 32 / 100, Graphics.FONT_XTINY, "?",
                     0x555555, Graphics.TEXT_JUSTIFY_CENTER);
            }
            if (i == sel) {
                _col(dc, Zs.ACCENT);
                dc.drawRoundedRectangle(px - cell * 48 / 100, py - cell * 48 / 100,
                                        cell * 96 / 100, cell * 96 / 100, 5);
            }
            rows.add([px - cell / 2, py - cell / 2, cell, cell]);
            rowIds.add(i);
        }

        var own = m.hasItem(sel);
        _shadow(dc, cx, h * 78 / 100, Graphics.FONT_XTINY,
                own ? Zs.itName(sel) : "NOT FOUND",
                own ? Zs.rarityColor(Zs.itRarity(sel)) : 0x555555,
                Graphics.TEXT_JUSTIFY_CENTER);
        Px.gshC(dc, own ? Zs.itEffect(sel) : Zs.rarityName(Zs.itRarity(sel)),
                cx, h * 87 / 100, _msc(h), own ? Zs.ACCENT : 0x555555);
    }

    // One shape per item. Same rule as the defence icons: silhouette first.
    function itemGlyph(dc, i, cx, cy, u, col) {
        if (u < 3) { u = 3; }
        _col(dc, col);
        if (i == Zs.IT_CROWBAR) {
            dc.fillRectangle(cx - u, cy - u, u * 2, 2);
            dc.fillRectangle(cx + u - 2, cy - u, 2, u * 2);
        } else if (i == Zs.IT_TOOLBOX) {
            dc.fillRectangle(cx - u, cy - u / 2, u * 2, u);
            dc.fillRectangle(cx - u / 3, cy - u, u * 2 / 3, u / 2);
        } else if (i == Zs.IT_SANDBAGS) {
            dc.fillRectangle(cx - u, cy, u * 2, u * 2 / 3);
            dc.fillRectangle(cx - u * 2 / 3, cy - u * 2 / 3, u * 4 / 3, u * 2 / 3);
        } else if (i == Zs.IT_SCOPE) {
            dc.fillRectangle(cx - u, cy - u / 3, u * 2, u * 2 / 3);
            dc.fillRectangle(cx - u / 3, cy - u, u * 2 / 3, u * 2);
        } else if (i == Zs.IT_WELDER) {
            dc.fillRectangle(cx - u / 3, cy - u, u * 2 / 3, u * 3 / 2);
            _col(dc, 0x55AAFF);
            dc.fillRectangle(cx - u / 2, cy + u / 2, u, u / 2);
        } else if (i == Zs.IT_AMMOBOX) {
            dc.fillRectangle(cx - u, cy - u / 2, u * 2, u * 3 / 2);
            _col(dc, 0x000000);
            dc.fillRectangle(cx - u, cy, u * 2, 1);
        } else if (i == Zs.IT_GENERATOR) {
            dc.fillRectangle(cx - u, cy - u / 2, u * 2, u * 3 / 2);
            dc.fillRectangle(cx - u / 2, cy - u, u / 3, u / 2);
        } else if (i == Zs.IT_PLATE) {
            dc.fillRectangle(cx - u, cy - u, u * 2, u * 2);
            _col(dc, 0x000000);
            dc.fillRectangle(cx - u / 2, cy - u / 2, u, u);
        } else if (i == Zs.IT_RADIO) {
            dc.fillRectangle(cx - u, cy, u * 2, u);
            dc.fillRectangle(cx + u / 2, cy - u * 3 / 2, 1, u * 3 / 2);
        } else if (i == Zs.IT_MANUAL) {
            dc.fillRectangle(cx - u, cy - u, u * 2, u * 2);
            _col(dc, 0x000000);
            dc.fillRectangle(cx, cy - u, 1, u * 2);
        } else if (i == Zs.IT_ARMOURY) {
            dc.fillCircle(cx - u / 2, cy - u / 2, u / 2);
            dc.fillRectangle(cx - u / 4, cy - u / 4, u * 3 / 2, 2);
            dc.fillRectangle(cx + u, cy - u / 4, 2, u / 2);
        } else {
            dc.fillRectangle(cx - u / 2, cy - u, u, u * 2);
            _col(dc, 0x55FF55);
            dc.fillRectangle(cx - u / 2, cy - u / 3, u, u * 4 / 3);
        }
    }

    // ── Overlay: one item, in full ──────────────────────────────────────────
    // FARM's detail card, to the pixel: counter, portrait, name, provenance,
    // effect, and a button at 81%.
    function findCard(dc, w, h, m, i, t) {
        var cx = w / 2;
        var owned = m.hasItem(i);
        var rar = Zs.itRarity(i);
        var rcol = owned ? Zs.rarityColor(rar) : 0x555555;
        _bg(dc, w, h);

        Px.gshC(dc, "SALVAGE " + (i + 1).format("%d") + "/" + Zs.IT_N.format("%d"),
                cx, h * 6 / 100, _msc(h), 0x555555);
        Px.gshC(dc, Zs.rarityName(rar), cx, h * 12 / 100, _psc(h), rcol);

        // Portrait, in a socket, so the item has somewhere to be.
        var py = h * 24 / 100;
        var sock = h * 11 / 100;
        _col(dc, owned ? Px.shade(rcol, 25) : 0x000000);
        dc.fillRoundedRectangle(cx - sock, py - sock, sock * 2, sock * 2, 6);
        _col(dc, rcol);
        dc.drawRoundedRectangle(cx - sock, py - sock, sock * 2, sock * 2, 6);
        if (owned) { itemGlyph(dc, i, cx, py, sock * 45 / 100, rcol); }
        else {
            _txt(dc, cx, py - sock / 2, Graphics.FONT_SMALL, "?", 0x555555,
                 Graphics.TEXT_JUSTIFY_CENTER);
        }

        var yName = _wrapN(dc, cx, h * 39 / 100, w * 84 / 100, Graphics.FONT_TINY,
                           owned ? TEXT : 0xAAAAAA,
                           owned ? Zs.itName(i) : "NOT FOUND", 1);
        if (owned) {
            var yLore = _wrapN(dc, cx, yName + h * 1 / 100, w * 82 / 100,
                               Graphics.FONT_XTINY, 0xAAAAAA, Zs.itLore(i), 2);
            _wrapN(dc, cx, yLore + h * 1 / 100, w * 82 / 100, Graphics.FONT_XTINY,
                   Zs.ACCENT, Zs.itEffect(i), 1);
        } else {
            _wrapN(dc, cx, yName + h * 2 / 100, w * 82 / 100, Graphics.FONT_XTINY,
                   0x555555, "Hold a night. Send the crew past the wire.", 2);
        }
        var bw = w * 62 / 100;
        btnA = [cx - bw / 2, h * 81 / 100, bw, h * 12 / 100];
        _button(dc, btnA, "BACK", false);
    }

    // ── Overlay: a daytime event ────────────────────────────────────────────
    function eventPanel(dc, w, h, m, sel, t) {
        var e = m.pendingEvent;
        var cx = w / 2;
        _bg(dc, w, h);
        Px.gshC(dc, "DAY " + m.dayNo().format("%d"), cx, h * 6 / 100, _msc(h), 0x555555);
        _txtFit(dc, cx, h * 14 / 100, Graphics.FONT_TINY, Zs.WARN, Zs.evTitle(e),
                w * 86 / 100);
        _wrapN(dc, cx, h * 28 / 100, w * 82 / 100, Graphics.FONT_XTINY, 0xAAAAAA,
               Zs.evBody(e), 3);

        var opts = [Zs.evChoiceA(e), Zs.evChoiceB(e)];
        var bh = h * 13 / 100;
        var bw = w * 74 / 100;
        for (var i = 0; i < 2; i++) {
            var r = [cx - bw / 2, h * 54 / 100 + i * (bh + h * 3 / 100), bw, bh];
            _button(dc, r, opts[i], i == sel);
            rows.add(r);
            rowIds.add(i);
        }
    }

    // ── Overlay: dawn ───────────────────────────────────────────────────────
    // Everything that happened while the app was shut, in the order it would
    // be told to you: what you earned, what happened, what you found.
    function dawn(dc, w, h, m, t) {
        var cx = w / 2;
        _bg(dc, w, h);
        Px.gshC(dc, "DAWN", cx, h * 7 / 100, _psc(h), Zs.WARN);
        var y = h * 16 / 100;

        if (m.gScrap > 0) {
            _shadow(dc, cx, y, Graphics.FONT_NUMBER_MILD, "+" + m.gScrap.format("%d"),
                    Zs.WARN, Graphics.TEXT_JUSTIFY_CENTER);
            y += h * 15 / 100;
            Px.gshC(dc, m.gSteps > 0 ? "SCRAP FROM " + m.gSteps.format("%d") + " STEPS"
                                     : "SCRAP", cx, y, _msc(h), 0xAAAAAA);
            y += h * 7 / 100;
        }
        if (m.gEvent != Zs.EV_NONE) {
            _txtFit(dc, cx, y, Graphics.FONT_XTINY, TEXT, Zs.evTitle(m.gEvent),
                    w * 84 / 100);
            y += h * 8 / 100;
            if (m.gEvText != null) {
                y = _wrapN(dc, cx, y, w * 82 / 100, Graphics.FONT_XTINY, 0xAAAAAA,
                           m.gEvText, 2) + h * 1 / 100;
            }
        }
        if (m.gItem >= 0) {
            var rar = Zs.itRarity(m.gItem);
            var rcol = Zs.rarityColor(rar);
            var sock = h * 6 / 100;
            _col(dc, Px.shade(rcol, 25));
            dc.fillRoundedRectangle(w * 16 / 100, y, sock * 2, sock * 2, 5);
            _col(dc, rcol);
            dc.drawRoundedRectangle(w * 16 / 100, y, sock * 2, sock * 2, 5);
            itemGlyph(dc, m.gItem, w * 16 / 100 + sock, y + sock, sock * 45 / 100, rcol);
            _txt(dc, w * 33 / 100, y, Graphics.FONT_XTINY, Zs.itName(m.gItem), rcol,
                 Graphics.TEXT_JUSTIFY_LEFT);
            _txt(dc, w * 33 / 100, y + h * 7 / 100, Graphics.FONT_XTINY,
                 Zs.itEffect(m.gItem), Zs.ACCENT, Graphics.TEXT_JUSTIFY_LEFT);
        }
        strip(dc, w, h, "WAVE IN " + countdown(m.secsToWave()), Zs.ACCENT);
    }

    // ── Overlay: intro ──────────────────────────────────────────────────────
    function intro(dc, w, h, t) {
        var cx = w / 2;
        _bg(dc, w, h);
        _shadow(dc, cx, h * 11 / 100, Graphics.FONT_TINY, "LAST STAND", Zs.ACCENT,
                Graphics.TEXT_JUSTIFY_CENTER);
        _rect(dc, w * 30 / 100, h * 20 / 100, w * 40 / 100, 1, 0x555555);
        var lines = ["YOUR STEPS BUY SCRAP",
                     "SCRAP BUILDS THE BASE",
                     "EVERY NIGHT THEY COME",
                     "THE BASE FIGHTS ALONE"];
        for (var i = 0; i < 4; i++) {
            _shadow(dc, cx, h * (27 + i * 11) / 100, Graphics.FONT_XTINY, lines[i],
                    i == 3 ? Zs.DANGER : 0xAAAAAA, Graphics.TEXT_JUSTIFY_CENTER);
        }
        var bw = w * 54 / 100;
        btnA = [cx - bw / 2, h * 77 / 100, bw, h * 13 / 100];
        _button(dc, btnA, "START", ((t / 6) % 2) == 0);
    }

    // ── Overlay: settling a wave nobody watched ─────────────────────────────
    function resolving(dc, w, h, sim, t) {
        var cx = w / 2;
        _bg(dc, w, h);
        Px.gshC(dc, "THE NIGHT", cx, h * 22 / 100, _psc(h), Zs.DANGER);
        var dots = "";
        for (var i = 0; i < 1 + (t / 4) % 3; i++) { dots = dots + "."; }
        _shadow(dc, cx, h * 36 / 100, Graphics.FONT_SMALL, "REPORT IN" + dots,
                0xAAAAAA, Graphics.TEXT_JUSTIFY_CENTER);
        var pct = sim.total > 0 ? sim.kills * 100 / sim.total : 0;
        _bar(dc, w * 22 / 100, h * 54 / 100, w * 56 / 100, 6, pct, Zs.BLOOD2);
        Px.gshC(dc, sim.kills.format("%d") + " PUT DOWN", cx, h * 62 / 100,
                _msc(h), 0x555555);
    }

    // ── Overlay: what happened ──────────────────────────────────────────────
    function result(dc, w, h, m, t) {
        var cx = w / 2;
        var won = m.rWin;
        var col = won ? Zs.ACCENT : Zs.DANGER;
        _bg(dc, w, h);

        Px.gshC(dc, "NIGHT " + m.rNight.format("%d"), cx, h * 7 / 100, _msc(h), 0xAAAAAA);
        _shadow(dc, cx, h * 13 / 100, Graphics.FONT_SMALL, won ? "HELD" : "OVERRUN",
                col, Graphics.TEXT_JUSTIFY_CENTER);

        // Three numbers, on their own line each, in the order they matter.
        var y = h * 30 / 100;
        _statRow(dc, w, y, "PUT DOWN",
                 m.rKills.format("%d") + " / " + m.rTotal.format("%d"), TEXT);
        _statRow(dc, w, y + h * 10 / 100, "WALL", m.rWallPct.format("%d") + "%",
                 m.rWallPct > 40 ? Zs.STEEL : Zs.WARN);
        _statRow(dc, w, y + h * 20 / 100, "SCRAP", "+" + m.rScrap.format("%d"), Zs.WARN);

        // Losing takes nothing away, so the copy has to make clear that the
        // night simply comes again rather than that progress was lost.
        var line = won ? "NIGHT " + m.night.format("%d") + " IS NEXT"
                       : "NIGHT " + m.night.format("%d") + " COMES AGAIN";
        Px.gshC(dc, line, cx, h * 63 / 100, _msc(h), won ? Zs.ACCENT : Zs.WARN);
        _txtFit(dc, cx, h * 69 / 100, Graphics.FONT_XTINY, 0xAAAAAA, advice(m),
                w * 84 / 100);

        var bw = w * 58 / 100;
        btnA = [cx - bw / 2, h * 80 / 100, bw, h * 12 / 100];
        _button(dc, btnA, "NEXT IN " + countdown(m.secsToWave()), false);
    }

    function _statRow(dc, w, y, label, value, col) {
        _txt(dc, w * 16 / 100, y, Graphics.FONT_XTINY, label, 0x555555,
             Graphics.TEXT_JUSTIFY_LEFT);
        _txt(dc, w * 84 / 100, y, Graphics.FONT_XTINY, value, col,
             Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // One concrete thing to do before tomorrow. Generic encouragement is
    // useless on a screen this size — name the part that failed.
    function advice(m) {
        var l = m.dLevel;
        if (!m.rWin) {
            if (m.rWallPct <= 0 && l[Zs.D_WALL] < 4) { return "THE WALL IS TOO THIN"; }
            if (l[Zs.D_MG] == 0) { return "BUILD AN MG NEST"; }
            if (l[Zs.D_SPIKES] == 0) { return "A SPIKE PIT IS CHEAP"; }
            if (l[Zs.D_MORTAR] == 0 && m.night >= Zs.BOSS_EVERY) { return "BRUTES NEED A MORTAR"; }
            if (l[Zs.D_REPAIR] == 0) { return "AUTO-REPAIR BUYS A NIGHT"; }
            return "WALK MORE. BUILD MORE.";
        }
        if (m.rWallPct < 30) { return "THAT WAS TOO CLOSE"; }
        if (l[Zs.D_SALVAGE] == 0) { return "SALVAGE PAYS FOR ITSELF"; }
        return "THEY WILL BRING MORE";
    }

    // ── The compound ribbon ─────────────────────────────────────────────────
    // Drawn straight over the yard. Nothing gets a panel: the whole point of
    // the home page is that you are looking at the place, so the readout is a
    // single slim pill and one line of chapter text at the top.
    function homeRibbon(dc, w, h, m, t) {
        var cx = w / 2;
        var secs = m.secsToWave();
        var light = ZsCompound.lightOf(secs);
        var sc = _msc(h);

        // One line under the tab dots, which is the only strip of this screen
        // the tab strip has not already claimed.
        var chap = "NIGHT " + m.night.format("%d") + " - " + Zs.chapterName(m.chapter());
        var cw = Px.gtxtW(chap, sc);
        var cyy = h * 19 / 100;
        _col(dc, 0x000000);
        dc.fillRectangle(cx - cw / 2 - 3, cyy - 2, cw + 6, 5 * sc + 4);
        Px.gtxtC(dc, chap, cx, cyy, sc, Zs.ACCENT);

        var gh = 5 * sc;
        var barH = gh + sc * 4;
        if (barH < 13) { barH = 13; }
        var barW = (w == h) ? w * 62 / 100 : w * 84 / 100;
        var bx = cx - barW / 2;
        var by = (w == h) ? (h * 89 / 100 - barH / 2) : (h - barH - h * 3 / 100);
        var gy = by + barH / 2 - gh / 2;
        var pad = barH / 4;
        if (pad < 3) { pad = 3; }

        var ccol = [Zs.ACCENT, Zs.WARN, Zs.FIRE, Zs.DANGER][light];
        _col(dc, 0x000000);
        dc.fillRoundedRectangle(bx, by, barW, barH, barH / 3);
        _col(dc, ccol);
        dc.drawRoundedRectangle(bx, by, barW, barH, barH / 3);

        Px.gtxt(dc, _fmt(m.scrap), bx + pad, gy, sc, Zs.WARN);
        Px.gtxtC(dc, countdown(secs), cx, gy, sc, ccol);
        var wl = m.wallPct.format("%d") + "%";
        Px.gtxt(dc, wl, bx + barW - pad - Px.gtxtW(wl, sc), gy, sc,
                m.wallPct > 50 ? Zs.STEEL : Zs.WARN);
    }

    // ── Screen: the wave, watched ───────────────────────────────────────────
    // Thin on purpose. There is nothing to manage, so the overlay only answers
    // "how far in are we" and "is the wall going".
    function simHud(dc, w, h, sim, t) {
        var cx = w / 2;
        var cy = h / 2;
        var r = (w < h ? w : h) / 2;

        _waveArc(dc, cx, cy, r, sim);
        _wallArc(dc, cx, cy, r, sim);

        _shadow(dc, cx, h * 4 / 100, Graphics.FONT_TINY, "NIGHT " + sim.night.format("%d"),
                Zs.ACCENT, Graphics.TEXT_JUSTIFY_CENTER);
        if (sim.mod != Zs.MOD_NONE) {
            Px.gshC(dc, Zs.modName(sim.mod), cx, h * 14 / 100, _msc(h), Zs.modColor(sim.mod));
        }
        Px.gsh(dc, sim.kills.format("%d") + "/" + sim.total.format("%d"),
               w * 15 / 100, h * 22 / 100, _msc(h), 0xFFFFFF);

        if (sim.bossSpawned) { _bossBar(dc, w, h, sim); }

        if (sim.anyBreach()) {
            var on = ((t / 4) % 2) == 0;
            _shadow(dc, cx, h * 30 / 100, Graphics.FONT_XTINY, "BREACH",
                    on ? Zs.DANGER : 0x550000, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (sim.tickN < 150) {
            Px.gshC(dc, "TAP TO FIRE", cx, h * 31 / 100, _msc(h), 0x555555);
        }
    }

    function _waveArc(dc, cx, cy, r, sim) {
        var total = sim.total;
        if (total < 1) { total = 1; }
        var span = 100 * sim.kills / total;
        if (span > 100) { span = 100; }
        dc.setPenWidth(5);
        _col(dc, 0x555555);
        dc.drawArc(cx, cy, r - 3, Graphics.ARC_CLOCKWISE, 140, 40);
        if (span > 0) {
            _col(dc, Zs.ACCENT);
            var end = 140 - span;
            if (end < 40) { end = 40; }
            dc.drawArc(cx, cy, r - 3, Graphics.ARC_CLOCKWISE, 140, end);
        }
        dc.setPenWidth(1);
    }

    function _wallArc(dc, cx, cy, r, sim) {
        dc.setPenWidth(5);
        _col(dc, 0x555555);
        dc.drawArc(cx, cy, r - 3, Graphics.ARC_CLOCKWISE, 320, 220);
        var pct = sim.totalWallPct();
        var col = Zs.STEEL;
        if (pct < 55) { col = Zs.WARN; }
        if (pct < 28) { col = Zs.DANGER; }
        if (pct > 0) {
            _col(dc, col);
            var end = 220 + (320 - 220) * (100 - pct) / 100;
            dc.drawArc(cx, cy, r - 3, Graphics.ARC_CLOCKWISE, 320, end);
        }
        dc.setPenWidth(1);
    }

    function _bossBar(dc, w, h, sim) {
        var pct = 0;
        for (var i = 0; i < sim.ZMAX; i++) {
            if (sim.zAlive[i] && Zs.zIsBoss(sim.zType[i])) {
                pct = sim.zHp[i] * 100 / sim.zMax[i];
                break;
            }
        }
        if (pct <= 0) { return; }
        var bw = w * 54 / 100;
        _bar(dc, w / 2 - bw / 2, h * 19 / 100, bw, 6, pct, Zs.BLOOD2);
        Px.gshC(dc, "ABOMINATION", w / 2, h * 23 / 100, _msc(h), 0xFF5500);
    }
}
