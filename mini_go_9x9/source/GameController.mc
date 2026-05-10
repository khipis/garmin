// GameController — manages turn order, pass counting, and end-of-game detection.
//
// Player = Black (STONE_BLACK = 1).   AI = White (STONE_WHITE = 2).
// Game ends when two consecutive passes occur (both players agree board is done).

class GameController {
    var board;          // Board instance
    var ai;             // AI instance
    var passCount;      // consecutive passes so far
    var gameOver;       // 1 when the game has ended
    var lastMoveIdx;    // index of last stone placed (-1 = none / last was pass)

    function initialize() {
        board       = new Board();
        ai          = new AI(board);
        passCount   = 0;
        gameOver    = 0;
        lastMoveIdx = -1;
    }

    function newGame() {
        board.newGame();
        passCount   = 0;
        gameOver    = 0;
        lastMoveIdx = -1;
    }

    // Player places a stone at (x,y). Returns true if the move was legal.
    function playerMove(x, y) {
        if (gameOver != 0) { return false; }
        if (!board.placeStone(x, y, STONE_BLACK)) { return false; }
        passCount   = 0;
        lastMoveIdx = y * 9 + x;
        _aiTurn();
        return true;
    }

    // Player passes. Triggers AI response.
    function playerPass() {
        if (gameOver != 0) { return; }
        passCount   = passCount + 1;
        lastMoveIdx = -1;
        if (!_checkGameOver()) { _aiTurn(); }
    }

    // AI makes the opening move (used when AI goes first).
    function aiFirstMove() {
        if (gameOver != 0) { return; }
        _aiTurn();
    }

    // AI plays its turn.
    hidden function _aiTurn() {
        var move = ai.chooseMove(STONE_WHITE);
        if (move >= 0) {
            var mx = move % 9; var my = move / 9;
            if (board.placeStone(mx, my, STONE_WHITE)) {
                passCount   = 0;
                lastMoveIdx = move;
                _checkGameOver();
                return;
            }
        }
        // AI passes
        passCount   = passCount + 1;
        lastMoveIdx = -1;
        _checkGameOver();
    }

    // Returns true if game is now over.
    hidden function _checkGameOver() {
        if (passCount >= 2) {
            gameOver = 1;
            board.calcScore();
            return true;
        }
        return false;
    }
}
