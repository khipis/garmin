using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Timer;

// ═══════════════════════════════════════════════════════════════════════════
// StyleView — cosmetic customization for the current pet.
//   • Live preview of the pet with palette + accessory applied
//   • Two editable rows: Palette (5) and Accessory (6)
//   • UP/DOWN (page)  → change the selected row's value
//   • SELECT / MENU   → switch which row is being edited (Palette ↔ Accessory)
//   • BACK            → done (changes are persisted live)
// Changes are cosmetic only and saved immediately by Pet.cyclePalette/Accessory.
// ═══════════════════════════════════════════════════════════════════════════
class StyleView extends WatchUi.View {
    hidden var _pet;
    hidden var _timer;
    hidden var _row;        // 0 = palette, 1 = accessory
    hidden var _frame;

    function initialize(pet) {
        View.initialize();
        _pet   = pet;
        _row   = 0;
        _frame = 0;
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 200, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTimer() as Void {
        _frame = (_frame + 1) % 1000;
        WatchUi.requestUpdate();
    }

    // ── intents from the delegate ──
    function changeValue(dir) {
        if (_row == 0) { _pet.cyclePalette(dir); }
        else           { _pet.cycleAccessory(dir); }
        WatchUi.requestUpdate();
    }

    function switchRow() {
        _row = (_row + 1) % 2;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(0x0F0F23, 0x0F0F23);
        dc.clear();

        // Title
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 8 / 100, Graphics.FONT_SMALL, "STYLE", Graphics.TEXT_JUSTIFY_CENTER);

        // Pet preview (gentle bob so it feels alive)
        var ps = w / 22;
        if (ps < 3) { ps = 3; }
        var bob = ((_frame % 8) < 4) ? 0 : ps / 3;
        _pet.drawStylePreview(dc, cx, h * 40 / 100 + bob, ps);

        // Option rows
        var palName = _pet.getPaletteName(_pet.getPaletteIdx());
        var accName = _pet.getAccessoryName(_pet.getAccessory());
        _drawRow(dc, w, h * 70 / 100, "Palette",   palName, _row == 0);
        _drawRow(dc, w, h * 82 / 100, "Accessory", accName, _row == 1);

        // Hint
        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 93 / 100, Graphics.FONT_XTINY,
                    "UP/DN change · SEL switch", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawRow(dc, w, y, label, value, selected) {
        var cx = w / 2;
        if (selected) {
            // Selection frame + arrows to signal this row is editable
            var bw = w * 72 / 100;
            var bx = (w - bw) / 2;
            dc.setColor(0x1A2A4A, 0x1A2A4A);
            dc.fillRectangle(bx, y - 1, bw, dc.getFontHeight(Graphics.FONT_TINY) + 2);
            dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx + 8, y, Graphics.FONT_TINY, "<", Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(bx + bw - 8, y, Graphics.FONT_TINY, ">", Graphics.TEXT_JUSTIFY_RIGHT);
        }
        dc.setColor(selected ? 0xFFFFFF : 0x8899AA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY, label + ": " + value, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class StyleDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onPreviousPage() { _view.changeValue(-1); return true; }  // UP
    function onNextPage()     { _view.changeValue(1);  return true; }  // DOWN
    function onSelect()       { _view.switchRow();     return true; }
    function onMenu()         { _view.switchRow();     return true; }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP)    { _view.changeValue(-1); return true; }
        if (k == WatchUi.KEY_DOWN)  { _view.changeValue(1);  return true; }
        if (k == WatchUi.KEY_ENTER) { _view.switchRow();     return true; }
        if (k == WatchUi.KEY_ESC)   { WatchUi.popView(WatchUi.SLIDE_DOWN); return true; }
        return false;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
