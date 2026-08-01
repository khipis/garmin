// ═══════════════════════════════════════════════════════════════════════════
// LeaderboardManager.mc — The only place that talks to the global board.
//
// Policy (deliberately strict, so the board stays meaningful):
//   • practice runs never submit
//   • a run abandoned before the clock expires never submits
//   • a completed ranked run submits only when it beats what was already
//     posted today, so replaying can improve a rank but cannot spam the board
//
// The variant is today's objective, which means the board a player sees is
// always populated by people who played exactly the same challenge. Switch the
// board to TODAY to read it as a pure daily leaderboard.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

module LeaderboardManager {

    // The board the shared menu opens, and the board a score lands on.
    function variant() as Lang.String {
        try { return ChallengeManager.today().variant(); } catch (e) {}
        return "basketball-sprint";
    }

    // Returns true when the score was actually sent.
    function submitRun(ch as DsChallenge, score as Lang.Number,
                       ranked as Lang.Boolean,
                       completed as Lang.Boolean) as Lang.Boolean {
        if (!ranked || !completed || score <= 0) { return false; }

        var d = ProgressionManager.day();
        if (score <= DsUtil.num(d, "sub", 0)) { return false; }
        d["sub"] = score;
        DsUtil.setDict(DS_K_DAY, d);

        try {
            Leaderboard.submitScore(DS_GAME_ID, score, ch.variant());
            Leaderboard.showPostGame(DS_GAME_ID, ch.variant(), ch.shortName());
        } catch (e) {
            return false;
        }
        return true;
    }
}
