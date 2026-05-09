// ShadowManager — records the current run and replays past runs as ghost clones.
//
// Storage layout (flat arrays, avoid nested allocation):
//   _runY / _runState are indexed as:  slot * MAX_FRAMES + frame
//
// Circular buffer:
//   _newest points to the most-recently-saved run slot.
//   runIdx 0 = newest run, 1 = second-newest, etc.
//
// MAX_RUNS and MAX_FRAMES are defined in GameView.mc.

class ShadowManager {
    // ── current-run recording ─────────────────────────────────────────────────
    hidden var _recY;
    hidden var _recState;
    hidden var _recLen;
    hidden var _isRecording;

    // ── stored past runs ──────────────────────────────────────────────────────
    hidden var _runY;
    hidden var _runState;
    hidden var _runLen;      // Array[MAX_RUNS] of lengths
    hidden var _runCount;    // 0..MAX_RUNS  — how many valid runs stored
    hidden var _newest;      // slot index of the most recently saved run

    // ── public notification timer ─────────────────────────────────────────────
    var newShadowTimer;

    function initialize() {
        _recY        = new [MAX_FRAMES];
        _recState    = new [MAX_FRAMES];
        _recLen      = 0;
        _isRecording = 0;

        _runY     = new [MAX_RUNS * MAX_FRAMES];
        _runState = new [MAX_RUNS * MAX_FRAMES];
        _runLen   = new [MAX_RUNS];
        _runCount = 0;
        _newest   = 0;

        newShadowTimer = 0;
        for (var i = 0; i < MAX_RUNS; i++) { _runLen[i] = 0; }
    }

    // ── recording API ─────────────────────────────────────────────────────────

    function startRec() {
        _recLen      = 0;
        _isRecording = 1;
    }

    function record(playerY, sc) {
        if (_isRecording == 0)    { return; }
        if (_recLen >= MAX_FRAMES) { return; }
        _recY[_recLen]     = playerY;
        _recState[_recLen] = sc;
        _recLen = _recLen + 1;
    }

    // Called on game-over — persists the current recording as a new clone.
    function saveRun() {
        if (_recLen < 10) { _isRecording = 0; return; }  // ignore trivially short runs
        _isRecording = 0;

        var slot;
        if (_runCount < MAX_RUNS) {
            slot     = _runCount;
            _runCount = _runCount + 1;
        } else {
            // overwrite oldest slot
            _newest = (_newest + 1) % MAX_RUNS;
            slot    = _newest;
        }
        _newest = slot;

        var base = slot * MAX_FRAMES;
        for (var i = 0; i < _recLen; i++) {
            _runY[base + i]     = _recY[i];
            _runState[base + i] = _recState[i];
        }
        _runLen[slot]  = _recLen;
        newShadowTimer = 90;
    }

    // ── playback API ──────────────────────────────────────────────────────────

    function runCount() { return _runCount; }

    // runIdx 0 = newest run, 1 = second-newest, etc.
    // Returns -9999 when the clone's run has ended (frame past its length).
    function cloneY(runIdx, frame) {
        if (runIdx >= _runCount) { return -9999; }
        var slot = (_newest - runIdx + MAX_RUNS) % MAX_RUNS;
        if (frame < 0 || frame >= _runLen[slot]) { return -9999; }
        return _runY[slot * MAX_FRAMES + frame];
    }

    function cloneState(runIdx, frame) {
        if (runIdx >= _runCount) { return STATE_RUN; }
        var slot = (_newest - runIdx + MAX_RUNS) % MAX_RUNS;
        if (frame < 0 || frame >= _runLen[slot]) { return STATE_RUN; }
        return _runState[slot * MAX_FRAMES + frame];
    }
}
