// ═══════════════════════════════════════════════════════════════
// WordList.mc — Static word banks per category × difficulty.
//
// Storage is a fixed 4 × 3 table of String arrays. Categories run
// horizontally (ANIMALS / FOOD / TECH / SPORTS); difficulties run
// vertically (EASY / MED / HARD). Picking a word is O(1) — choose
// a random index inside the relevant bank.
//
// All words are uppercase ASCII A..Z. The game only needs to
// compare against [A..Z] so we don't carry punctuation, spaces or
// localized characters.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

// Category codes
const CAT_ANIMALS = 0;
const CAT_FOOD    = 1;
const CAT_TECH    = 2;
const CAT_SPORTS  = 3;
const NUM_CATEGORIES = 4;

// Difficulty codes
const DIFF_EASY = 0;
const DIFF_MED  = 1;
const DIFF_HARD = 2;
const NUM_DIFFICULTIES = 3;

class WordList {
    // ── Animal bank ─────────────────────────────────────────────────
    static var _ANIM_EASY = ["CAT","DOG","COW","PIG","FOX","BEE",
                             "FROG","LION","BEAR","WOLF","FISH","BIRD"];
    static var _ANIM_MED  = ["MOUSE","TIGER","HORSE","EAGLE","ZEBRA",
                             "RABBIT","MONKEY","TURTLE","BADGER","BEAVER"];
    static var _ANIM_HARD = ["ELEPHANT","BUTTERFLY","ALLIGATOR",
                             "RHINOCEROS","KANGAROO","OCTOPUS",
                             "CHIMPANZEE","HEDGEHOG","GIRAFFE"];

    // ── Food bank ───────────────────────────────────────────────────
    static var _FOOD_EASY = ["PIE","JAM","EGG","RICE","MILK","BEAN",
                             "CAKE","TUNA","SOUP","TACO","CORN"];
    static var _FOOD_MED  = ["APPLE","BREAD","PIZZA","PASTA","BACON",
                             "CHEESE","BURGER","COOKIE","MANGO","SALMON"];
    static var _FOOD_HARD = ["SPAGHETTI","CHOCOLATE","HAMBURGER",
                             "SANDWICH","PINEAPPLE","WATERMELON",
                             "AVOCADO","STRAWBERRY"];

    // ── Tech bank ───────────────────────────────────────────────────
    static var _TECH_EASY = ["APP","WEB","USB","CPU","RAM","CHIP",
                             "CODE","DATA","BIT","BYTE","FILE","DISK"];
    static var _TECH_MED  = ["ROBOT","EMAIL","PIXEL","MODEM","ROUTER",
                             "LAPTOP","BROWSER","SERVER","DRIVER","SCREEN"];
    static var _TECH_HARD = ["KEYBOARD","COMPUTER","ALGORITHM",
                             "BLUETOOTH","INTERNET","SOFTWARE",
                             "NETWORK","DATABASE","FIREWALL"];

    // ── Sports bank ─────────────────────────────────────────────────
    static var _SPRT_EASY = ["SKI","GOLF","RUN","JUMP","SWIM","BIKE",
                             "YOGA","JUDO","DIVE","ROW","SURF"];
    static var _SPRT_MED  = ["SOCCER","TENNIS","HOCKEY","BOXING",
                             "RUGBY","KARATE","CRICKET","CYCLING","SKATING"];
    static var _SPRT_HARD = ["BASEBALL","BASKETBALL","VOLLEYBALL",
                             "GYMNASTICS","FOOTBALL","SWIMMING",
                             "ARCHERY","WRESTLING","TRIATHLON"];

    // Lookup the right bank, returns a random word from it.
    static function randomWord(category, difficulty) {
        var bank = _bankFor(category, difficulty);
        if (bank == null || bank.size() == 0) { return "WORD"; }
        return bank[Math.rand() % bank.size()];
    }

    static function categoryName(c) {
        if (c == CAT_ANIMALS) { return "Animals";    }
        if (c == CAT_FOOD)    { return "Food";       }
        if (c == CAT_TECH)    { return "Technology"; }
        return "Sports";
    }
    static function difficultyName(d) {
        if (d == DIFF_EASY) { return "Easy"; }
        if (d == DIFF_MED)  { return "Medium"; }
        return "Hard";
    }

    hidden static function _bankFor(c, d) {
        if (c == CAT_ANIMALS) {
            if (d == DIFF_EASY) { return _ANIM_EASY; }
            if (d == DIFF_MED)  { return _ANIM_MED;  }
            return _ANIM_HARD;
        }
        if (c == CAT_FOOD) {
            if (d == DIFF_EASY) { return _FOOD_EASY; }
            if (d == DIFF_MED)  { return _FOOD_MED;  }
            return _FOOD_HARD;
        }
        if (c == CAT_TECH) {
            if (d == DIFF_EASY) { return _TECH_EASY; }
            if (d == DIFF_MED)  { return _TECH_MED;  }
            return _TECH_HARD;
        }
        if (d == DIFF_EASY) { return _SPRT_EASY; }
        if (d == DIFF_MED)  { return _SPRT_MED;  }
        return _SPRT_HARD;
    }
}
