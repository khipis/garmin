using Toybox.Graphics;
using Toybox.WatchUi;

class SetupView extends WatchUi.View {

    hidden var _pet;
    var phase;
    var selectedType;
    var selectedName;

    function initialize(pet) {
        View.initialize();
        _pet = pet;
        phase = 1;
        selectedType = 0;
        selectedName = 0;
    }

    function setPhase(p) {
        phase = p;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x0F0F23, 0x0F0F23);
        dc.clear();

        if (phase == 1) {
            drawTypeSelect(dc, w, h);
        } else {
            drawNameSelect(dc, w, h);
        }
    }

    hidden function drawTypeSelect(dc, w, h) {
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_TINY, "Choose Pet", Graphics.TEXT_JUSTIFY_CENTER);

        var ps = w / 30;
        if (ps < 3) { ps = 3; }
        var locked = _pet.isTypeLocked(selectedType);

        if (locked) {
            dc.setColor(0x0A0A15, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w / 2, h * 42 / 100, ps * 7);
            _pet.drawPreview(dc, w / 2, h * 42 / 100, ps, selectedType);

            dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(w / 2 - 5, h * 33 / 100 - ps * 2, 10, 8);
            dc.drawCircle(w / 2, h * 33 / 100 - ps * 2 - 2, 4);

            dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 56 / 100, Graphics.FONT_TINY, "LOCKED", Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 63 / 100, Graphics.FONT_SMALL, _pet.getTypeName(selectedType), Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_XTINY, _pet.getLockReason(selectedType), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            _pet.drawPreview(dc, w / 2, h * 42 / 100, ps, selectedType);

            var colors = _pet.getColors(selectedType);
            dc.setColor(colors[1], Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_MEDIUM, _pet.getTypeName(selectedType), Graphics.TEXT_JUSTIFY_CENTER);

            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 72 / 100, Graphics.FONT_XTINY, _pet.getTypeDesc(selectedType), Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 - w * 22 / 100, h * 63 / 100, Graphics.FONT_SMALL, "<", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2 + w * 22 / 100, h * 63 / 100, Graphics.FONT_SMALL, ">", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 88 / 100, Graphics.FONT_XTINY, "UP/DN browse  SEL pick", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        var dots = "";
        for (var i = 0; i < TYPE_COUNT; i++) {
            if (i == selectedType) { dots = dots + "O "; }
            else { dots = dots + "o "; }
        }
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY, dots, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawNameSelect(dc, w, h) {
        dc.setColor(0x66CCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_TINY, "Name Your Pet", Graphics.TEXT_JUSTIFY_CENTER);

        var ps = w / 35;
        if (ps < 2) { ps = 2; }
        _pet.drawPreview(dc, w / 2, h * 35 / 100, ps, selectedType);

        var names = _pet.getNames(selectedType);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 55 / 100, Graphics.FONT_MEDIUM, names[selectedName], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2 - w * 25 / 100, h * 56 / 100, Graphics.FONT_SMALL, "<", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2 + w * 25 / 100, h * 56 / 100, Graphics.FONT_SMALL, ">", Graphics.TEXT_JUSTIFY_CENTER);

        var prev = (selectedName - 1 + names.size()) % names.size();
        var next = (selectedName + 1) % names.size();
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 65 / 100, Graphics.FONT_XTINY, names[prev] + "  |  " + names[next], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 88 / 100, Graphics.FONT_XTINY, "UP/DN browse  SEL pick", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class SetupDelegate extends WatchUi.BehaviorDelegate {

    hidden var _pet;
    hidden var _view;

    function initialize(pet, view) {
        BehaviorDelegate.initialize();
        _pet = pet;
        _view = view;
    }

    function onPreviousPage() {
        if (_view.phase == 1) {
            _view.selectedType = (_view.selectedType - 1 + TYPE_COUNT) % TYPE_COUNT;
        } else {
            var names = _pet.getNames(_view.selectedType);
            _view.selectedName = (_view.selectedName - 1 + names.size()) % names.size();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        if (_view.phase == 1) {
            _view.selectedType = (_view.selectedType + 1) % TYPE_COUNT;
        } else {
            var names = _pet.getNames(_view.selectedType);
            _view.selectedName = (_view.selectedName + 1) % names.size();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() {
        if (_view.phase == 1) {
            if (_pet.isTypeLocked(_view.selectedType)) {
                WatchUi.requestUpdate();
                return true;
            }
            _view.selectedName = 0;
            _view.setPhase(2);
        } else {
            _pet.create(_view.selectedType, _view.selectedName);
            var view = new MainView(_pet);
            WatchUi.switchToView(view, new MainDelegate(_pet, view), WatchUi.SLIDE_UP);
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() {
        if (_view.phase == 2) {
            _view.setPhase(1);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}
