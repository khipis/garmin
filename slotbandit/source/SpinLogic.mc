// ═══════════════════════════════════════════════════════════════
// SpinLogic.mc — "Skill slot" timing mechanic + win evaluation.
//
// This is what makes stop TIMING matter. Real skill-stop (pachislot)
// machines use a "pull-in" window: pressing stop doesn't lock the
// reel on the exact symbol under the payline that frame — it can
// travel a few more symbols FORWARD (never backward) to grab a
// nearby winning symbol, if one exists within the window. A player
// who reads the reel and times their press so a target symbol is
// just approaching the payline gets rewarded; press too early or
// too late and the window won't reach it.
//
// SLOT_PULLIN_MAX controls how forgiving that window is — bigger
// pulls in from further away (easier), smaller demands tighter
// timing (harder, more "skill").
// ═══════════════════════════════════════════════════════════════

module SpinLogic {

    // Called when the player commits to stopping `idx`. Looks a few
    // symbols ahead on that reel's strip and lands on whichever one
    // gives the best outcome given reels that are already stopped —
    // chasing a rarer symbol on the first stop, then chasing a MATCH
    // with already-locked reels on the following stops.
    function requestStop(reelSys, idx) {
        var r = reelSys.reels[idx];
        if (r.state != REEL_SPINNING) { return; }

        var others = [];
        for (var i = 0; i < 3; i++) {
            if (i != idx && reelSys.reels[i].state == REEL_STOPPED) {
                others.add(reelSys.reels[i].paylineSymbol());
            }
        }

        var n = SymbolManager.STRIP_LEN;
        var base = r.position.toNumber();
        var bestOff = 0;
        var bestScore = -1;
        for (var off = 0; off <= SLOT_PULLIN_MAX; off++) {
            var sym = r.strip[(base + off) % n];
            var score = _scoreCandidate(sym, others);
            if (score > bestScore) {
                bestScore = score;
                bestOff   = off;
            }
        }
        r.beginStop(bestOff, SLOT_DECEL_TICKS);
    }

    // Higher score = more desirable landing symbol given what's
    // already locked on the other reels.
    function _scoreCandidate(sym, others) {
        if (others.size() == 2) {
            // Final reel: a 3-way match is worth chasing above all else.
            if (others[0] == others[1] && sym == others[0]) { return 10000 + sym; }
            if (sym == others[0] || sym == others[1])       { return 1000  + sym; }
            return sym;
        }
        if (others.size() == 1) {
            if (sym == others[0]) { return 1000 + sym; }
            return sym;
        }
        // Nothing locked yet — chase rarity (id doubles as rank).
        return sym;
    }

    // Evaluates the 3 payline symbols once every reel is stopped.
    // Returns a dict: { "kind"->"NONE"/"PAIR"/"TRIPLE"/"JACKPOT",
    //                    "payout"->Number, "label"->String, "sym"->Number }
    function evaluate(symbols) {
        var a = symbols[0]; var b = symbols[1]; var c = symbols[2];

        if (a == b && b == c) {
            if (a == SYM_SEVEN) {
                return { "kind" => "JACKPOT", "payout" => SymbolManager.PAYOUT_3[a],
                         "label" => "JACKPOT!", "sym" => a };
            }
            return { "kind" => "TRIPLE", "payout" => SymbolManager.PAYOUT_3[a],
                     "label" => "WIN!", "sym" => a };
        }
        if (a == b || b == c || a == c) {
            var sym = (a == b) ? a : ((b == c) ? b : a);
            return { "kind" => "PAIR", "payout" => SymbolManager.PAYOUT_2,
                     "label" => "pair!", "sym" => sym };
        }
        return { "kind" => "NONE", "payout" => 0, "label" => "", "sym" => -1 };
    }
}
