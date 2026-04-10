using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;

// ─────────────────────────────────────────────────────────────────────────────
//  ColonyView  –  all rendering and UI state
//
//  Pages / screens:
//    PAGE_DASH    – resource counters + production rates (main HUD)
//    PAGE_BUILD   – 4 build buttons with costs
//    PAGE_BOOST   – activate boost button + timer
//    PAGE_STATS   – lifetime stats + prestige option
//
//  Navigation: UP/DOWN move cursor, SELECT acts on selection.
// ─────────────────────────────────────────────────────────────────────────────

const PAGE_DASH  = 0;
const PAGE_BUILD = 1;
const PAGE_BOOST = 2;
const PAGE_STATS = 3;
const PAGE_COUNT = 4;

// Menu item indices on the BUILD page
const BUILD_ITEMS = 4;

class ColonyView extends WatchUi.View {

    hidden var _game;
    hidden var _timer;
    hidden var _tick;

    // UI state
    hidden var _page;       // current page index
    hidden var _cursor;     // selected row on build/boost pages
    hidden var _flashMsg;   // short notification string
    hidden var _flashTick;  // countdown ticks until flash clears

    // Notification from random event (displayed on dash)
    hidden var _eventMsgTick;

    function initialize(game) {
        View.initialize();
        _game  = game;
        _tick  = 0;
        _page  = PAGE_DASH;
        _cursor = 0;
        _flashMsg  = "";
        _flashTick = 0;
        _eventMsgTick = 0;
    }

    function onLayout(dc) {}

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() as Void {
        _tick++;
        _game.tick();

        if (_flashTick > 0) { _flashTick--; }

        // Detect new random event message
        if (!_game.lastEventMsg.equals("")) {
            _flashMsg  = _game.lastEventMsg;
            _flashTick = 5;
            _game.lastEventMsg = "";
        }

        if (_eventMsgTick > 0) { _eventMsgTick--; }

        WatchUi.requestUpdate();
    }

    // ── Input routing ─────────────────────────────────────────────────────────

    function scrollUp() {
        if (_page == PAGE_BUILD) {
            _cursor = (_cursor + BUILD_ITEMS - 1) % BUILD_ITEMS;
        } else if (_page == PAGE_STATS) {
            // no cursor on stats
        } else {
            _page = (_page + PAGE_COUNT - 1) % PAGE_COUNT;
            _cursor = 0;
        }
    }

    function scrollDown() {
        if (_page == PAGE_BUILD) {
            _cursor = (_cursor + 1) % BUILD_ITEMS;
        } else if (_page == PAGE_STATS) {
            // no cursor
        } else {
            _page = (_page + 1) % PAGE_COUNT;
            _cursor = 0;
        }
    }

    function onSelect() {
        if (_page == PAGE_DASH) {
            // Tap on dash → go to build page
            _page = PAGE_BUILD; _cursor = 0;
        } else if (_page == PAGE_BUILD) {
            var ok = _game.build(_cursor);
            if (ok) {
                setFlash("✓ Built Lv" + _game.bldLevel[_cursor]);
            } else {
                setFlash("✗ Need more " + ((_cursor == BLD_LAB) ? "energy" : "ore"));
            }
        } else if (_page == PAGE_BOOST) {
            if (_game.boostSecsLeft > 0) {
                setFlash("Boost active " + _game.boostSecsLeft + "s");
            } else {
                var ok2 = _game.activateBoost();
                if (ok2) { setFlash("⚡ BOOST ON! x2 for 20s"); }
                else     { setFlash("✗ Need " + _game.boostCost + " energy"); }
            }
        } else if (_page == PAGE_STATS) {
            if (_game.canPrestige()) {
                var ok3 = _game.prestige();
                if (ok3) { setFlash("★ PRESTIGE x" + _game.prestigeCount); }
            } else {
                setFlash("Need " + _game.fmt(50000.0) + " lifetime ore");
            }
        }
    }

    function onMenu() {
        // Toggle between pages or go to stats
        if (_page == PAGE_STATS) { _page = PAGE_DASH; }
        else { _page = PAGE_STATS; _cursor = 0; }
    }

    hidden function setFlash(msg) {
        _flashMsg  = msg;
        _flashTick = 4;
    }

    // ── Rendering ─────────────────────────────────────────────────────────────

    function onUpdate(dc) {
        var w = dc.getWidth(); var h = dc.getHeight();
        dc.setColor(0x050D18, 0x050D18); dc.clear();

        if      (_page == PAGE_DASH)  { drawDash(dc, w, h); }
        else if (_page == PAGE_BUILD) { drawBuild(dc, w, h); }
        else if (_page == PAGE_BOOST) { drawBoost(dc, w, h); }
        else                          { drawStats(dc, w, h); }

        // Flash notification strip at bottom
        if (_flashTick > 0) {
            var flashC = (_tick % 2 == 0) ? 0xFFDD44 : 0xFFAA00;
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, h - 16, w, 16);
            dc.setColor(flashC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 15, Graphics.FONT_XTINY, _flashMsg, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Page indicator dots at very bottom
        drawPageDots(dc, w, h);
    }

    // ── Dashboard ─────────────────────────────────────────────────────────────

    hidden function drawDash(dc, w, h) {
        // ── Title bar ────────────────────────────────────────────────────────
        dc.setColor(0x1A3A6A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 18);
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 1, Graphics.FONT_XTINY, "★ STAR COLONY ★", Graphics.TEXT_JUSTIFY_CENTER);

        var y = 24;

        // ── ORE ──────────────────────────────────────────────────────────────
        dc.setColor(0x997700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, y, Graphics.FONT_XTINY, "ORE", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 4, y, Graphics.FONT_XTINY, _game.fmt(_game.ore), Graphics.TEXT_JUSTIFY_RIGHT);
        y += 14;
        dc.setColor(0x664400, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, y, Graphics.FONT_XTINY, _game.fmtRate(_game.calcOrePs(true)), Graphics.TEXT_JUSTIFY_LEFT);

        // Ore progress bar toward next meaningful milestone
        y += 16;
        drawBar(dc, 4, y, w - 8, 6, _game.ore, nextMilestone(_game.ore), 0xFFDD44);

        y += 14;
        // ── ENERGY ───────────────────────────────────────────────────────────
        dc.setColor(0x005577, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, y, Graphics.FONT_XTINY, "ENERGY", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 4, y, Graphics.FONT_XTINY, _game.fmt(_game.energy), Graphics.TEXT_JUSTIFY_RIGHT);
        y += 14;
        dc.setColor(0x003344, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, y, Graphics.FONT_XTINY, _game.fmtRate(_game.calcEnergyPs(true)), Graphics.TEXT_JUSTIFY_LEFT);

        y += 18;
        // ── Boost indicator ──────────────────────────────────────────────────
        if (_game.boostSecsLeft > 0) {
            var bc = (_tick % 2 == 0) ? 0xFF8800 : 0xFFCC00;
            dc.setColor(bc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Graphics.FONT_XTINY, "⚡ BOOST " + _game.boostSecsLeft + "s", Graphics.TEXT_JUSTIFY_CENTER);
            y += 14;
        }

        // ── Colony level summary ──────────────────────────────────────────────
        dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
        var lvlStr = "D" + _game.bldLevel[BLD_DRONES] +
                     " R" + _game.bldLevel[BLD_REACTOR] +
                     " F" + _game.bldLevel[BLD_FARM] +
                     " L" + _game.bldLevel[BLD_LAB];
        dc.drawText(w / 2, y, Graphics.FONT_XTINY, lvlStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Prestige badge ────────────────────────────────────────────────────
        if (_game.prestigeCount > 0) {
            dc.setColor(0xFF44AA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 4, 1, Graphics.FONT_XTINY, "P" + _game.prestigeCount, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        // ── Nav hint ─────────────────────────────────────────────────────────
        if (_flashTick == 0) {
            dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 16, Graphics.FONT_XTINY, "↓ build  ↑ boost", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Build page ────────────────────────────────────────────────────────────

    hidden function drawBuild(dc, w, h) {
        dc.setColor(0x1A3A6A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 18);
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 1, Graphics.FONT_XTINY, "BUILD / UPGRADE", Graphics.TEXT_JUSTIFY_CENTER);

        var names  = ["⛏ DRONES", "⚡ REACTOR", "🌿 FARM", "🔬 LAB"];
        var y = 22;
        var rowH = (h - 38) / BUILD_ITEMS;
        if (rowH < 18) { rowH = 18; }

        for (var i = 0; i < BUILD_ITEMS; i++) {
            var isSelected = (i == _cursor);
            var cost       = _game.buildCost(i);
            var useEnergy  = (i == BLD_LAB);
            var canBuy     = _game.canAfford(i);
            var lvl        = _game.bldLevel[i];

            // Selection highlight
            if (isSelected) {
                dc.setColor(canBuy ? 0x1A3A5A : 0x3A1A1A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(0, y, w, rowH);
                dc.setColor(0x336699, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(0, y, w, rowH);
            }

            // Building name + level
            var nameC = isSelected ? 0xFFFFFF : (canBuy ? 0xAABBCC : 0x445566);
            dc.setColor(nameC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(4, y + 1, Graphics.FONT_XTINY, names[i] + " Lv" + lvl, Graphics.TEXT_JUSTIFY_LEFT);

            // Cost
            var costC = canBuy ? 0x44FF88 : 0xFF4444;
            dc.setColor(costC, Graphics.COLOR_TRANSPARENT);
            var costStr = _game.fmt(cost) + (useEnergy ? " ⚡" : " ore");
            dc.drawText(w - 4, y + 1, Graphics.FONT_XTINY, costStr, Graphics.TEXT_JUSTIFY_RIGHT);

            // Production preview on selected row
            if (isSelected && lvl > 0) {
                dc.setColor(0x336655, Graphics.COLOR_TRANSPARENT);
                var ps = buildPreviewPs(i);
                dc.drawText(w / 2, y + rowH - 13, Graphics.FONT_XTINY, ps, Graphics.TEXT_JUSTIFY_CENTER);
            }

            y += rowH;
        }

        if (_flashTick == 0) {
            dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 16, Graphics.FONT_XTINY, "↑↓ select  tap build", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function buildPreviewPs(bldIdx) {
        var nextLvl = _game.bldLevel[bldIdx] + 1;
        if (bldIdx == BLD_DRONES) {
            return "→ +" + (nextLvl.toFloat() * BASE_ORE_PS).format("%.1f") + " ore/s";
        } else if (bldIdx == BLD_REACTOR) {
            return "→ +" + (nextLvl.toFloat() * BASE_ENERGY_PS).format("%.1f") + " nrg/s";
        } else if (bldIdx == BLD_FARM) {
            return "→ +" + (nextLvl.toFloat() * BASE_FARM_PS).format("%.1f") + " ore/s";
        } else {
            return "→ mult x" + (1.0 + nextLvl.toFloat() * 0.08).format("%.2f");
        }
    }

    // ── Boost page ────────────────────────────────────────────────────────────

    hidden function drawBoost(dc, w, h) {
        dc.setColor(0x1A3A6A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 18);
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 1, Graphics.FONT_XTINY, "PRODUCTION BOOST", Graphics.TEXT_JUSTIFY_CENTER);

        var midY = h / 2;

        if (_game.boostSecsLeft > 0) {
            // Boost active — show countdown and animated bar
            var bc = (_tick % 2 == 0) ? 0xFF8800 : 0xFFCC00;
            dc.setColor(bc, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, midY - 24, Graphics.FONT_MEDIUM, "⚡ ACTIVE", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, midY, Graphics.FONT_SMALL, _game.boostSecsLeft + "s", Graphics.TEXT_JUSTIFY_CENTER);

            var pct = _game.boostSecsLeft.toFloat() / BOOST_DURATION.toFloat();
            drawBar(dc, 16, midY + 22, w - 32, 8, pct, 1.0, 0xFF8800);

            dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, midY + 38, Graphics.FONT_XTINY,
                "x2 all production", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // Boost available
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, midY - 24, Graphics.FONT_SMALL, "x2 for 20s", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x334455, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, midY, Graphics.FONT_XTINY,
                "Cost: " + _game.boostCost + " ⚡", Graphics.TEXT_JUSTIFY_CENTER);

            var canBoost = _game.energy >= _game.boostCost.toFloat();
            dc.setColor(canBoost ? 0x88FFAA : 0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, midY + 18, Graphics.FONT_XTINY,
                canBoost ? "[ TAP TO ACTIVATE ]" : "✗ need energy", Graphics.TEXT_JUSTIFY_CENTER);

            // Show current energy
            dc.setColor(0x44CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, midY + 34, Graphics.FONT_XTINY,
                "Energy: " + _game.fmt(_game.energy), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Stats page ────────────────────────────────────────────────────────────

    hidden function drawStats(dc, w, h) {
        dc.setColor(0x1A3A6A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 18);
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 1, Graphics.FONT_XTINY, "COLONY STATS", Graphics.TEXT_JUSTIFY_CENTER);

        var y = 24;

        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, y, Graphics.FONT_XTINY,
            "Life ore: " + _game.fmt(_game.lifeOre), Graphics.TEXT_JUSTIFY_LEFT);
        y += 14;
        dc.drawText(4, y, Graphics.FONT_XTINY,
            "Ore/s:  " + _game.fmtRate(_game.calcOrePs(false)), Graphics.TEXT_JUSTIFY_LEFT);
        y += 14;
        dc.drawText(4, y, Graphics.FONT_XTINY,
            "Nrg/s:  " + _game.fmtRate(_game.calcEnergyPs(false)), Graphics.TEXT_JUSTIFY_LEFT);
        y += 14;
        dc.drawText(4, y, Graphics.FONT_XTINY,
            "Multiplier: x" + _game.globalMult().format("%.2f"), Graphics.TEXT_JUSTIFY_LEFT);
        y += 14;
        dc.drawText(4, y, Graphics.FONT_XTINY,
            "Prestige: " + _game.prestigeCount + "  (+" +
            (_game.prestigeCount * 10) + "%)", Graphics.TEXT_JUSTIFY_LEFT);

        y += 20;
        // Prestige button
        var canP = _game.canPrestige();
        if (canP) {
            dc.setColor((_tick % 4 < 2) ? 0xFF44AA : 0xBB2277, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(w / 4, y, w / 2, 18, 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y + 1, Graphics.FONT_XTINY, "★ PRESTIGE ★", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
            dc.drawText(4, y, Graphics.FONT_XTINY,
                "Prestige at " + _game.fmt(50000.0) + " ore", Graphics.TEXT_JUSTIFY_LEFT);
            var pct2 = _game.lifeOre / 50000.0;
            if (pct2 > 1.0) { pct2 = 1.0; }
            y += 14;
            drawBar(dc, 4, y, w - 8, 5, pct2, 1.0, 0xFF44AA);
        }

        if (_flashTick == 0) {
            dc.setColor(0x223344, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 16, Graphics.FONT_XTINY, "Tap = prestige (if ready)", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    hidden function drawBar(dc, x, y, bw, bh, val, maxVal, color) {
        dc.setColor(0x0A1A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, bw, bh);
        var pct = (maxVal > 0.0) ? (val / maxVal) : 0.0;
        if (pct > 1.0) { pct = 1.0; }
        if (pct < 0.0) { pct = 0.0; }
        var filled = (bw.toFloat() * pct).toNumber();
        if (filled > 0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, filled, bh);
        }
        dc.setColor(0x1A3A5A, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, bw, bh);
    }

    hidden function drawPageDots(dc, w, h) {
        var dotY = h - 5;
        var spacing = 8;
        var startX = w / 2 - (PAGE_COUNT - 1) * spacing / 2;
        for (var i = 0; i < PAGE_COUNT; i++) {
            var dotC = (i == _page) ? 0x4488FF : 0x1A2E40;
            dc.setColor(dotC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(startX + i * spacing, dotY, (i == _page) ? 3 : 2);
        }
    }

    // Next round milestone for ore bar (nearest power of 10 above current)
    hidden function nextMilestone(val) {
        var v = val;
        if (v < 100.0)     { return 100.0; }
        if (v < 1000.0)    { return 1000.0; }
        if (v < 10000.0)   { return 10000.0; }
        if (v < 100000.0)  { return 100000.0; }
        return 1000000.0;
    }
}
