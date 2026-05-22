// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Stateless drawing helpers for the text UI.
//
// Layout (all screens follow it):
//   ┌─────────────────────────────────┐
//   │ HP 42/60   F12   G 285          │ ← status row (always)
//   ├─────────────────────────────────┤
//   │ Headline (title)                │ ← logTitle
//   │ line 1                          │ ← logLine1
//   │ line 2                          │ ← logLine2
//   ├─────────────────────────────────┤
//   │ ▶ Option 1                      │ ← option list with cursor
//   │   Option 2                      │
//   │   Option 3                      │
//   └─────────────────────────────────┘
//
// Functions are static — no instance state — so we don't pay for
// allocations when re-laying out per frame. The view caches the
// option-row y-coordinates so InputHandler taps can be mapped back
// to option indices.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

class UIManager {
    // Returns [statusY, bodyY0, bodyY1, optY0, optStride] in screen px.
    // The view uses the option-row coordinates to detect taps.
    static function layout(screenW, screenH) {
        var statusY  = (screenH * 3) / 100; if (statusY < 3) { statusY = 3; }
        var bodyY0   = (screenH * 18) / 100;
        var bodyY1   = (screenH * 50) / 100;
        var optY0    = (screenH * 56) / 100;
        var optStride= (screenH * 11) / 100;
        if (optStride < 14) { optStride = 14; }
        return [statusY, bodyY0, bodyY1, optY0, optStride];
    }

    // ── Status row (HP + Floor + Gold), always visible ──────────────
    static function drawStatus(dc, screenW, statusY, player, floor, hiColor) {
        var H = player.hp;
        var maxH = player.maxHp;
        var col = 0x44FF66;
        if (H * 2 < maxH) { col = 0xFFCC22; }
        if (H * 4 < maxH) { col = 0xFF4466; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(6, statusY, Graphics.FONT_XTINY,
                    "HP " + H.format("%d") + "/" + maxH.format("%d"),
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(hiColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenW / 2, statusY, Graphics.FONT_XTINY,
                    "F" + floor.format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenW - 6, statusY, Graphics.FONT_XTINY,
                    "G " + player.gold.format("%d"),
                    Graphics.TEXT_JUSTIFY_RIGHT);
        // Separator line
        dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, statusY + 16, screenW, 1);
    }

    // ── Body block: title in colour + up to two lines below ─────────
    static function drawBody(dc, screenW, bodyY0, bodyY1,
                             logTitle, logLine1, logLine2, accent) {
        var cx = screenW / 2;
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, bodyY0, Graphics.FONT_SMALL,
                    logTitle, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        if (logLine1 != null && logLine1.length() > 0) {
            dc.drawText(cx, bodyY0 + 22, Graphics.FONT_XTINY,
                        logLine1, Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (logLine2 != null && logLine2.length() > 0) {
            dc.setColor(0xCCCCDD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, bodyY0 + 38, Graphics.FONT_XTINY,
                        logLine2, Graphics.TEXT_JUSTIFY_CENTER);
        }
        // Separator line below the body
        dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, bodyY1, screenW, 1);
    }

    // ── Options list with cursor caret ──────────────────────────────
    static function drawOptions(dc, screenW, optY0, optStride,
                                labels, cursor) {
        var n = labels.size();
        // For ≤2 options, centre them horizontally; for ≥3 keep left-aligned
        // with caret for easier scanning on small round watches.
        var centred = n <= 1;
        for (var i = 0; i < n; i++) {
            var y    = optY0 + i * optStride;
            var on   = (i == cursor);
            var col  = on ? 0xFFCC22 : 0x99AABB;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var text = labels[i];
            if (n > 1) {
                text = (on ? "> " : "  ")
                     + (i + 1).format("%d") + ") " + text;
            }
            if (centred) {
                dc.drawText(screenW / 2, y, Graphics.FONT_XTINY,
                            text, Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawText(12, y, Graphics.FONT_XTINY,
                            text, Graphics.TEXT_JUSTIFY_LEFT);
            }
        }
    }
}
