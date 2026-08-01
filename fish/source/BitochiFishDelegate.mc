using Toybox.WatchUi;

class BitochiFishDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        if (_view.inMenu()) { _view.menuActivate(); } else { _view.doAction(); }
        WatchUi.requestUpdate(); return true;
    }
    function onMenu() {
        if (_view.inMenu()) { _view.menuActivate(); } else { _view.doAction(); }
        WatchUi.requestUpdate(); return true;
    }
    function onPreviousPage() {
        if (_view.inMenu()) { _view.menuPrev(); } else { _view.doAction(); }
        WatchUi.requestUpdate(); return true;
    }
    function onNextPage() {
        if (_view.inMenu()) { _view.menuNext(); } else { _view.doAction(); }
        WatchUi.requestUpdate(); return true;
    }

    function onKey(evt) {
        if (_view.inMenu()) {
            var k = evt.getKey();
            if      (k == WatchUi.KEY_UP)   { _view.menuPrev(); }
            else if (k == WatchUi.KEY_DOWN) { _view.menuNext(); }
            else                            { _view.menuActivate(); }
            WatchUi.requestUpdate(); return true;
        }
        return false;
    }

    function onTap(evt) {
        if (_view.inMenu()) {
            var c = evt.getCoordinates();
            _view.handleMenuTap(c[0], c[1]);
        } else {
            _view.doAction();
        }
        WatchUi.requestUpdate(); return true;
    }

    function onBack() {
        // Fish-local exit prompt (not shared confirmExit): we must submit LB
        // progress only on a real quit, never when the save menu merely covers
        // the view (shared confirmExit + onHide submit locked the session to
        // the first BACK forever).
        var data = null;
        try { data = _view.exportSave(); } catch (e) { data = null; }
        if (data == null) {
            try { _view.confirmExitQuit(); } catch (e) {}
            try { WatchUi.popView(WatchUi.SLIDE_RIGHT); } catch (e) {}
            return true;
        }
        try {
            var m = new WatchUi.Menu2({ :title => "SAVE PROGRESS?" });
            m.addItem(new WatchUi.MenuItem("Cancel", "keep fishing", :cancel, null));
            m.addItem(new WatchUi.MenuItem("Yes, save", "resume later", :yes, null));
            m.addItem(new WatchUi.MenuItem("No, quit", "discard run", :no, null));
            WatchUi.pushView(m, new FishExitConfirmDelegate(_view, data), WatchUi.SLIDE_UP);
        } catch (e) {
            try { _view.confirmExitQuit(); } catch (e2) {}
            try { WatchUi.popView(WatchUi.SLIDE_RIGHT); } catch (e2) {}
        }
        return true;
    }
}

// Yes → save + submit + pop; No → clear + submit + pop; Cancel → stay.
class FishExitConfirmDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _view;
    hidden var _data;

    function initialize(view, data) {
        Menu2InputDelegate.initialize();
        _view = view;
        _data = data;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :cancel) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }
        if (id == :yes) {
            try { SaveResume.save("fish", _data); } catch (e) {}
        } else if (id == :no) {
            try { SaveResume.clear("fish"); } catch (e) {}
        }
        try { _view.confirmExitQuit(); } catch (e) {}
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        try { WatchUi.popView(WatchUi.SLIDE_RIGHT); } catch (e) {}
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
