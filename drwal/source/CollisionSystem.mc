// ═══════════════════════════════════════════════════════════════
// CollisionSystem.mc — Branch-vs-player hit test.
// ═══════════════════════════════════════════════════════════════
class CollisionSystem {
    // True when standing on `side` while `segType` is the segment
    // currently level with the player means a branch strikes the
    // lumberjack on the very chop that reveals it.
    static function hits(segType, side) {
        if (segType == SEG_LEFT  && side == SIDE_LEFT)  { return true; }
        if (segType == SEG_RIGHT && side == SIDE_RIGHT) { return true; }
        return false;
    }
}
