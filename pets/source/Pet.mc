using Toybox.Application;
using Toybox.Time;
using Toybox.Math;
using Toybox.Graphics;
using Toybox.ActivityMonitor;
using Toybox.System;

enum {
    TYPE_BLOBBY, TYPE_FLAMEY, TYPE_AQUA, TYPE_ROCKY,
    TYPE_GHOSTY, TYPE_SPARKY, TYPE_FROSTY, TYPE_SHROOMY,
    TYPE_EMILKA, TYPE_VEXOR, TYPE_CHIKKO, TYPE_DZIKKO,
    TYPE_POLACCO, TYPE_NOSACZ, TYPE_DONUT, TYPE_CACTUSO, TYPE_PIXELBOT, TYPE_OCTAVIO, TYPE_BATSY, TYPE_NUGGET,
    TYPE_FOCZKA, TYPE_RAINBOW, TYPE_DOGGO, TYPE_UNDEAD,
    TYPE_COUNT
}

enum {
    ACT_NONE, ACT_EATING, ACT_PLAYING, ACT_SLEEPING, ACT_CLEANING, ACT_HEALING
}

enum {
    TRAIT_GLUTTON, TRAIT_PICKY, TRAIT_PLAYFUL, TRAIT_LAZY,
    TRAIT_HARDY, TRAIT_FRAGILE, TRAIT_CHEERFUL, TRAIT_GRUMPY,
    TRAIT_HYPER, TRAIT_SLEEPY, TRAIT_COUNT
}

enum {
    ACC_NONE, ACC_HAT, ACC_BOW, ACC_GLASSES, ACC_CROWN, ACC_BANDANA, ACC_COUNT
}

const PALETTE_COUNT = 5;

class Pet {

    var hunger;
    var happiness;
    var energy;
    var health;
    var petType;
    var petName;
    var trait1;
    var trait2;
    var isCreated;
    var isAlive;
    var isSick;
    var poopCount;
    var animFrame;
    var action;
    var eventText;
    var debugMode;
    var lastInteraction;
    var paletteIdx;
    var accessory;
    var celebType;
    var pendingVibe;
    var dilemmaType;
    var dilemmaText;
    var hugStress;
    var careStreak;
    var vibeEnabled;
    var suggestedAction;
    var eventFlashType;

    hidden var _lastCareDay;
    hidden var _hugStressAcc;
    hidden var _actionTime;
    hidden var _eventTime;
    hidden var _lastUpdate;
    hidden var _birthTime;
    hidden var _sickTime;
    hidden var _lastBirthdayDay;
    hidden var _hungerAcc;
    hidden var _happyAcc;
    hidden var _energyAcc;
    hidden var _poopAcc;
    hidden var _sickCheckAcc;
    hidden var _eventCheckAcc;
    hidden var _thoughtAcc;
    hidden var _hardyAcc;
    hidden var _autoAcc;
    hidden var _saveAcc;
    hidden var _dilemmaTime;
    hidden var _bodyCache;
    hidden var _bodyCacheType;

    function initialize() {
        Math.srand(Time.now().value());
        hunger = 20;
        happiness = 80;
        energy = 80;
        health = 100;
        petType = TYPE_BLOBBY;
        petName = "Pixel";
        trait1 = -1;
        trait2 = -1;
        isCreated = false;
        isAlive = true;
        isSick = false;
        poopCount = 0;
        animFrame = 0;
        action = ACT_NONE;
        eventText = "";
        debugMode = false;
        paletteIdx = 0;
        accessory = ACC_NONE;
        celebType = 0;
        pendingVibe = 0;
        dilemmaType = 0;
        dilemmaText = "";
        hugStress = 0;
        careStreak = 0;
        vibeEnabled = true;
        suggestedAction = -1;
        eventFlashType = 0;
        _lastCareDay = -1;
        _hugStressAcc = 0;
        _actionTime = 0;
        var now = Time.now().value();
        lastInteraction = now;
        _eventTime = now;
        _lastUpdate = now;
        _birthTime = now;
        _sickTime = 0;
        _lastBirthdayDay = -1;
        _hungerAcc = 0;
        _happyAcc = 0;
        _energyAcc = 0;
        _poopAcc = 0;
        _sickCheckAcc = 0;
        _eventCheckAcc = 0;
        _thoughtAcc = 0;
        _hardyAcc = 0;
        _autoAcc = 0;
        _saveAcc = 0;
        _bodyCache = null;
        _bodyCacheType = -1;
    }

    function getNames(type) {
        var def = getTypeName(type);
        return [
            def,
            "Pixel", "Bloop", "Ziggy", "Mochi", "Nori",
            "Taco", "Bean", "Dot", "Pip", "Rex",
            "Kiki", "Bobo", "Gizmo", "Pogo", "Zazu",
            "Mimi", "Tofu", "Yuki", "Loki", "Coco",
            "Dodo", "Boba", "Mango", "Ollie", "Waffle",
            "Luna", "Bella", "Daisy", "Rosie"
        ];
    }

    function create(type, nameIndex) {
        petType = type;
        petName = getNames(type)[nameIndex];
        isCreated = true;
        isAlive = true;
        hunger = 20;
        happiness = 80;
        energy = 80;
        health = 100;
        isSick = false;
        poopCount = 0;
        animFrame = 0;
        action = ACT_NONE;
        eventText = "";
        celebType = 0;
        pendingVibe = 0;
        suggestedAction = -1;
        debugMode = false;
        paletteIdx = 0;
        accessory = ACC_NONE;
        trait1 = Math.rand().abs() % TRAIT_COUNT;
        trait2 = Math.rand().abs() % TRAIT_COUNT;
        while (trait2 == trait1 || traitsIncompatible(trait1, trait2)) { trait2 = Math.rand().abs() % TRAIT_COUNT; }
        var now = Time.now().value();
        _birthTime = now;
        _lastUpdate = now;
        _eventTime = now;
        lastInteraction = now;
        _sickTime = 0;
        _lastBirthdayDay = -1;
        _actionTime = 0;
        _hungerAcc = 0;
        _happyAcc = 0;
        _energyAcc = 0;
        _poopAcc = 0;
        _sickCheckAcc = 0;
        _eventCheckAcc = 0;
        _thoughtAcc = 0;
        _hardyAcc = 0;
        _autoAcc = 0;
        _saveAcc = 0;
        _hugStressAcc = 0;
        hugStress = 0;
        careStreak = 0;
        _lastCareDay = 0;
        dilemmaType = 0;
        dilemmaText = "";
        _bodyCache = null;
        _bodyCacheType = -1;
        save();
    }

    function load() {
        var created = Application.Storage.getValue("created");
        if (created != null && created) {
            isCreated = true;
            hunger = Application.Storage.getValue("hunger");
            happiness = Application.Storage.getValue("happiness");
            energy = Application.Storage.getValue("energy");
            health = Application.Storage.getValue("health");
            petType = Application.Storage.getValue("type");
            petName = Application.Storage.getValue("name");
            trait1 = Application.Storage.getValue("trait1");
            trait2 = Application.Storage.getValue("trait2");
            var a = Application.Storage.getValue("alive");
            isAlive = (a != null) ? a : true;
            var s = Application.Storage.getValue("sick");
            isSick = (s != null) ? s : false;
            var p = Application.Storage.getValue("poop");
            poopCount = (p != null) ? p : 0;
            _birthTime = Application.Storage.getValue("birth");
            var st = Application.Storage.getValue("sickTime");
            _sickTime = (st != null) ? st : 0;
            var li = Application.Storage.getValue("lastInt");
            lastInteraction = (li != null) ? li : Time.now().value();
            var pi = Application.Storage.getValue("paletteIdx");
            paletteIdx = (pi != null) ? pi : 0;
            var ac = Application.Storage.getValue("accessory");
            accessory = (ac != null) ? ac : ACC_NONE;
            var hs = Application.Storage.getValue("hugStress");
            hugStress = (hs != null) ? hs : 0;
            var cs = Application.Storage.getValue("careStreak");
            careStreak = (cs != null) ? cs : 0;
            var lcd = Application.Storage.getValue("lastCareDay");
            _lastCareDay = (lcd != null) ? lcd : -1;
            var ve = Application.Storage.getValue("vibeEnabled");
            vibeEnabled = (ve != null) ? ve : true;
            var saved = Application.Storage.getValue("lastUpdate");
            if (saved != null && isAlive) {
                var elapsed = Time.now().value() - saved;
                if (elapsed > 0) { applyOffline(elapsed); }
            }
        }
        var now = Time.now().value();
        _lastUpdate = now;
        _eventTime = now;
        _hungerAcc = 0;
        _happyAcc = 0;
        _energyAcc = 0;
        _poopAcc = 0;
        _sickCheckAcc = 0;
        _eventCheckAcc = 0;
        _thoughtAcc = 0;
        _hardyAcc = 0;
        _autoAcc = 0;
        _saveAcc = 0;
        _hugStressAcc = 0;
        _dilemmaTime = 0;
        action = ACT_NONE;
        eventText = "";
    }

    function save() {
        Application.Storage.setValue("created", isCreated);
        Application.Storage.setValue("hunger", hunger);
        Application.Storage.setValue("happiness", happiness);
        Application.Storage.setValue("energy", energy);
        Application.Storage.setValue("health", health);
        Application.Storage.setValue("type", petType);
        Application.Storage.setValue("name", petName);
        Application.Storage.setValue("trait1", trait1);
        Application.Storage.setValue("trait2", trait2);
        Application.Storage.setValue("alive", isAlive);
        Application.Storage.setValue("sick", isSick);
        Application.Storage.setValue("poop", poopCount);
        Application.Storage.setValue("birth", _birthTime);
        Application.Storage.setValue("lastUpdate", Time.now().value());
        Application.Storage.setValue("sickTime", _sickTime);
        Application.Storage.setValue("lastInt", lastInteraction);
        Application.Storage.setValue("paletteIdx", paletteIdx);
        Application.Storage.setValue("accessory", accessory);
        Application.Storage.setValue("hugStress", hugStress);
        Application.Storage.setValue("careStreak", careStreak);
        Application.Storage.setValue("lastCareDay", _lastCareDay);
        Application.Storage.setValue("vibeEnabled", vibeEnabled);
    }

    function resetPet() {
        Application.Storage.setValue("created", false);
        isCreated = false;
        isAlive = true;
        debugMode = false;
        paletteIdx = 0;
        accessory = ACC_NONE;
        hugStress = 0;
        careStreak = 0;
        _lastCareDay = -1;
        dilemmaType = 0;
        dilemmaText = "";
        _bodyCache = null;
        _bodyCacheType = -1;
    }

    function toggleVibe() {
        vibeEnabled = !vibeEnabled;
        eventText = vibeEnabled ? "Vibe: ON" : "Vibe: OFF";
        _eventTime = Time.now().value();
        save();
    }

    function toggleDebug() {
        debugMode = !debugMode;
        eventText = debugMode ? "DEBUG x300" : "Debug OFF";
        _eventTime = Time.now().value();
    }

    function debugAddHours() {
        if (!isAlive) { return; }
        _birthTime -= 10800;
        eventText = "+3h age (now " + getAgeString() + ")";
        _eventTime = Time.now().value();
        pendingVibe = 1;
    }

    hidden function applyOffline(elapsed) {
        hunger += elapsed / getHungerRate();
        happiness -= elapsed / getHappyRate();
        energy -= elapsed / getEnergyRate();
        poopCount += elapsed / 7200;
        if (poopCount > 5) { poopCount = 5; }
        if (poopCount > 2) { happiness -= (poopCount - 2) * (elapsed / 900); }
        if (isSick) {
            health -= elapsed / 300;
            if (_sickTime > 0 && Time.now().value() - _sickTime > 21600) { health = 0; }
        }
        if (hasTrait(TRAIT_HARDY) && !isSick) { health += elapsed / 7200; }
        hugStress -= elapsed / 1800;
        if (hugStress < 0) { hugStress = 0; }
        clamp();
        checkDeath();
    }

    function update() {
        if (!isAlive || !isCreated) { animFrame = 0; return; }

        var now = Time.now().value();
        var realElapsed = now - _lastUpdate;
        _lastUpdate = now;
        var ge = debugMode ? realElapsed * 300 : realElapsed;

        _hungerAcc += ge;
        _happyAcc += ge;
        _energyAcc += ge;
        _poopAcc += ge;
        _sickCheckAcc += ge;
        _eventCheckAcc += ge;

        var hr = getHungerRate();
        var hpr = getHappyRate();
        var er = getEnergyRate();
        if (isNightTime()) { hr = hr * 3 / 2; hpr = hpr * 3 / 2; er = er * 3 / 2; }
        var ageStage = getAgeStage();
        if (ageStage == 0) { hr = hr * 7 / 10; hpr = hpr * 3 / 2; }
        if (ageStage == 3) { er = er * 4 / 5; }
        if (_hungerAcc >= hr) { hunger += _hungerAcc / hr; _hungerAcc = _hungerAcc % hr; }
        if (_happyAcc >= hpr) { happiness -= _happyAcc / hpr; _happyAcc = _happyAcc % hpr; }
        if (_energyAcc >= er) { energy -= _energyAcc / er; _energyAcc = _energyAcc % er; }
        if (_poopAcc >= 7200) { poopCount += _poopAcc / 7200; if (poopCount > 5) { poopCount = 5; } _poopAcc = _poopAcc % 7200; }

        if (poopCount > 2) { happiness -= 1; }
        if (isSick) { health -= 1; }

        if (hasTrait(TRAIT_HARDY) && !isSick && health < 100) {
            _hardyAcc += ge;
            if (_hardyAcc >= 3600) { _hardyAcc = 0; health += 1; }
        }

        if (hugStress > 0) {
            _hugStressAcc += ge;
            if (_hugStressAcc >= 900) {
                hugStress -= _hugStressAcc / 900;
                _hugStressAcc = _hugStressAcc % 900;
                if (hugStress < 0) { hugStress = 0; }
            }
        } else { _hugStressAcc = 0; }

        var sickInterval = debugMode ? 300 : 1800;
        if (_sickCheckAcc >= sickInterval) {
            _sickCheckAcc = 0;
            if (!isSick) { checkSickness(); } else { checkSickRecovery(); }
            checkAgeDeath();
            checkUrgentNeeds();
        }
        checkBirthday(now);
        var eventInterval = debugMode ? 200 : 900;
        if (_eventCheckAcc >= eventInterval) { _eventCheckAcc = 0; if (Math.rand().abs() % 2 == 0) { triggerEvent(); } }

        clamp();
        checkDeath();

        var actionClear = debugMode ? 2 : 3;
        var napClear = debugMode ? 5 : 60;
        var eventClear = debugMode ? 2 : 4;
        if (action == ACT_SLEEPING && now - _actionTime > napClear) { action = ACT_NONE; }
        else if (action != ACT_NONE && action != ACT_SLEEPING && now - _actionTime > actionClear) { action = ACT_NONE; }
        if (eventText.length() > 0 && now - _eventTime > eventClear) { eventText = ""; _eventTime = now; }
        if (eventText.length() == 0) {
            _thoughtAcc += ge;
            var thoughtInterval = debugMode ? 15 : 40;
            if (_thoughtAcc >= thoughtInterval) { _thoughtAcc = 0; eventText = getThought(); _eventTime = now; }
        } else { _thoughtAcc = 0; }

        if (dilemmaType == 0 && action == ACT_NONE && getMoodState() != :calm) {
            var dilemmaChance = debugMode ? 10 : 120;
            if (Math.rand().abs() % dilemmaChance == 0) { triggerDilemma(); }
        }
        var dilemmaTimeout = debugMode ? 10 : 15;
        if (dilemmaType > 0 && _dilemmaTime > 0 && (now - _dilemmaTime) >= dilemmaTimeout) {
            autoResolveDilemma();
        }

        _autoAcc += ge;
        var autoThreshold = debugMode ? 120 : 900;
        if (_autoAcc >= autoThreshold) {
            _autoAcc = 0;
            if (action == ACT_NONE && eventText.length() == 0 && dilemmaType == 0 && Math.rand().abs() % 4 == 0) {
                doAutoAction();
            }
        }

        _saveAcc += realElapsed;
        if (_saveAcc >= 120) { _saveAcc = 0; save(); }

        animFrame = (animFrame + 1) % 8;
    }

    // ===== Autonomous actions =====

    hidden function doAutoAction() {
        var mood = getMoodState();
        if (mood != :calm) { doMoodAction(mood); return; }
        var roll = Math.rand().abs() % 7;
        if (roll == 0 && poopCount > 0) {
            poopCount -= 1;
            eventText = "Groomed itself!";
            action = ACT_CLEANING;
        } else if (roll == 1) {
            happiness += 8; energy -= 3;
            eventText = "Played alone!";
            action = ACT_PLAYING;
        } else if (roll == 2) {
            energy += 10;
            eventText = "Quick nap!";
            action = ACT_SLEEPING;
        } else if (roll == 3 && hunger > 30) {
            hunger -= 10;
            eventText = "Found a snack!";
            action = ACT_EATING;
        } else if (roll == 4) {
            happiness += 5;
            eventText = "Practiced a trick!";
            action = ACT_PLAYING;
        } else if (roll == 5) {
            happiness += 3; energy += 3;
            eventText = "Stretched a bit!";
        } else {
            happiness += 2;
            eventText = "Hummed a tune~";
        }
        _actionTime = Time.now().value();
        _eventTime = _actionTime;
        clamp();
    }

    hidden function doMoodAction(mood) {
        if (Math.rand().abs() % 5 < 2) {
            if (doTypeMoodAction(mood)) {
                _actionTime = Time.now().value();
                _eventTime = _actionTime;
                action = ACT_PLAYING;
                clamp();
                return;
            }
        }

        if (mood == :rage) {
            var roll = Math.rand().abs() % 4;
            if (roll == 0 && poopCount > 0) {
                eventText = "*ATE THE POOP*";
                poopCount -= 1; hunger -= 5; happiness -= 15;
            } else if (roll == 1) {
                eventText = "*SCREAMS AT VOID*";
                happiness += 3; energy -= 5;
            } else if (roll == 2) {
                eventText = "*kicks random pixel*";
                energy -= 5; health -= 3;
            } else {
                eventText = "*tries to flip watch*";
                energy -= 8;
            }
        } else if (mood == :love) {
            var roll = Math.rand().abs() % 4;
            if (roll == 0) { eventText = "*hugs your wrist*"; happiness += 5; }
            else if (roll == 1) { eventText = "*writes love letter*"; happiness += 3; }
            else if (roll == 2) { eventText = "*tattoos ur name*"; happiness += 8; }
            else { eventText = "*stares lovingly*"; }
        } else if (mood == :sugar_high) {
            var roll = Math.rand().abs() % 4;
            if (roll == 0) { eventText = "*runs into wall*"; energy -= 10; happiness += 5; }
            else if (roll == 1) { eventText = "*does backflip*"; energy -= 5; happiness += 10; }
            else if (roll == 2) { eventText = "*vibrates so hard*"; energy -= 8; }
            else { eventText = "*licks the screen*"; happiness += 3; }
        } else if (mood == :existential) {
            var roll = Math.rand().abs() % 4;
            if (roll == 0) { eventText = "*stares at a pixel*"; }
            else if (roll == 1) { eventText = "*questions reality*"; }
            else if (roll == 2) { eventText = "*writes sad poetry*"; happiness += 2; }
            else { eventText = "*googles 'am I real'*"; }
        } else if (mood == :paranoid) {
            var roll = Math.rand().abs() % 4;
            if (roll == 0) { eventText = "*hides in corner*"; }
            else if (roll == 1) { eventText = "*checks for bugs*"; happiness += 2; }
            else if (roll == 2) { eventText = "*builds tiny fort*"; happiness += 3; }
            else { eventText = "*scans for viruses*"; }
        } else if (mood == :feral) {
            var roll = Math.rand().abs() % 4;
            if (roll == 0 && poopCount > 0) {
                eventText = "*eats poop. WHY?!*";
                poopCount -= 1; hunger -= 8; happiness -= 20;
            } else if (roll == 1) {
                eventText = "*marks territory*";
                poopCount += 1; if (poopCount > 5) { poopCount = 5; }
            } else if (roll == 2) {
                eventText = "*howls at nothing*";
            } else {
                eventText = "*scratches screen*";
                health -= 2;
            }
        } else if (mood == :party) {
            var roll = Math.rand().abs() % 4;
            if (roll == 0) { eventText = "*does the worm*"; energy -= 5; happiness += 10; }
            else if (roll == 1) { eventText = "*breakdances*"; energy -= 8; happiness += 12; }
            else if (roll == 2) { eventText = "*DJ scratching*"; happiness += 8; }
            else { eventText = "*stage dives alone*"; energy -= 10; happiness += 5; }
        }
        _actionTime = Time.now().value();
        _eventTime = _actionTime;
        action = ACT_PLAYING;
        clamp();
    }

    hidden function doTypeMoodAction(mood) {
        if (petType == TYPE_FLAMEY) {
            if (mood == :rage) { eventText = "*sets watch on fire*"; energy -= 10; health -= 3; return true; }
            if (mood == :love) { eventText = "*warm candlelight*"; happiness += 6; return true; }
            if (mood == :sugar_high) { eventText = "*shoots fireworks*"; energy -= 8; happiness += 8; return true; }
        } else if (petType == TYPE_AQUA) {
            if (mood == :love) { eventText = "*love tsunami*"; happiness += 8; return true; }
            if (mood == :rage) { eventText = "*boils with fury*"; energy -= 8; return true; }
            if (mood == :existential) { eventText = "*evaporates a little*"; energy -= 3; return true; }
        } else if (petType == TYPE_ROCKY) {
            if (mood == :feral) { eventText = "*causes earthquake*"; health -= 5; return true; }
            if (mood == :rage) { eventText = "*throws boulders*"; energy -= 12; return true; }
            if (mood == :party) { eventText = "*ROCK N ROLL!*"; happiness += 10; energy -= 5; return true; }
        } else if (petType == TYPE_GHOSTY) {
            if (mood == :paranoid) { eventText = "*phases thru wall*"; energy -= 3; return true; }
            if (mood == :rage) { eventText = "*poltergeist mode!*"; happiness -= 5; return true; }
            if (mood == :love) { eventText = "*haunts u lovingly*"; happiness += 5; return true; }
            if (mood == :existential) { eventText = "*haunts itself*"; return true; }
        } else if (petType == TYPE_SPARKY) {
            if (mood == :sugar_high) { eventText = "*short circuits!*"; energy -= 15; health -= 3; return true; }
            if (mood == :party) { eventText = "*disco ball mode*"; happiness += 10; energy -= 5; return true; }
            if (mood == :rage) { eventText = "*zaps everything*"; energy -= 10; return true; }
        } else if (petType == TYPE_FROSTY) {
            if (mood == :love) { eventText = "*heart melts*"; happiness += 8; return true; }
            if (mood == :rage) { eventText = "*freezes screen*"; energy -= 5; return true; }
            if (mood == :feral) { eventText = "*ice age begins*"; health -= 3; return true; }
            if (mood == :existential) { eventText = "*melts slowly*"; health -= 2; return true; }
        } else if (petType == TYPE_SHROOMY) {
            if (mood == :party) { eventText = "*releases spores!*"; happiness += 10; return true; }
            if (mood == :sugar_high) { eventText = "*grows mushrooms*"; happiness += 5; hunger -= 5; return true; }
            if (mood == :existential) { eventText = "*decomposes a bit*"; health -= 2; return true; }
        } else if (petType == TYPE_BLOBBY) {
            if (mood == :existential) { eventText = "*loses all shape*"; return true; }
            if (mood == :rage) { eventText = "*engulfs pixels*"; hunger -= 3; return true; }
            if (mood == :love) { eventText = "*absorbs with love*"; happiness += 6; return true; }
        } else if (petType == TYPE_EMILKA) {
            if (mood == :rage) { eventText = "*checks ur history*"; happiness -= 5; energy -= 3; return true; }
            if (mood == :love) { eventText = "*draws hearts on u*"; happiness += 10; return true; }
            if (mood == :existential) { eventText = "*dramatic hair flip*"; happiness -= 3; return true; }
            if (mood == :sugar_high) { eventText = "*twirls hair fast*"; energy -= 5; happiness += 8; return true; }
            if (mood == :party) { eventText = "*selfie pose!*"; happiness += 8; energy -= 3; return true; }
        } else if (petType == TYPE_VEXOR) {
            if (mood == :rage) {
                var ra = ["*f*cking burns everything*", "*flips table to hell*", "*screams profanities*", "*curses your bloodline*"];
                eventText = ra[Math.rand().abs() % ra.size()]; energy -= 10; health -= 3; happiness += 10; return true;
            }
            if (mood == :feral) { eventText = "*devours a f*cking soul*"; hunger -= 15; happiness += 5; return true; }
            if (mood == :sugar_high) { eventText = "*opens portals everywhere*"; energy -= 15; happiness += 12; return true; }
            if (mood == :party) { eventText = "*death metal screaming*"; happiness += 15; energy -= 8; return true; }
            if (mood == :paranoid) { eventText = "*oh sh*t, the light!*"; energy -= 3; return true; }
        } else if (petType == TYPE_CHIKKO) {
            if (mood == :paranoid) { eventText = "*BAWK! hides in corner*"; energy -= 8; happiness -= 5; return true; }
            if (mood == :feral) { eventText = "*pecks EVERYTHING*"; hunger -= 10; energy -= 5; return true; }
            if (mood == :sugar_high) { eventText = "*lays surprise egg!*"; happiness += 15; energy -= 10; return true; }
            if (mood == :party) { eventText = "*chicken dance!*"; happiness += 10; energy -= 5; return true; }
            if (mood == :existential) { eventText = "*stares at egg...*"; happiness -= 5; return true; }
        } else if (petType == TYPE_DZIKKO) {
            if (mood == :rage) { eventText = "*CHARGES the wall!*"; health -= 5; happiness += 8; energy -= 10; return true; }
            if (mood == :feral) { eventText = "*digs up everything*"; hunger -= 12; energy -= 8; return true; }
            if (mood == :party) { eventText = "*mud wrestling!*"; happiness += 12; energy -= 6; return true; }
            if (mood == :existential) { eventText = "*stares into forest*"; happiness -= 3; return true; }
        } else if (petType == TYPE_POLACCO) {
            if (mood == :rage) {
                var ra = ["*rzuca pilotem*", "*kopie telewizor*", "*wali piescia w stol*", "*przekl*na sasiadow*"];
                eventText = ra[Math.rand().abs() % ra.size()]; happiness += 5; energy -= 5; return true;
            }
            if (mood == :party) {
                var pa = ["*odpala grilla*", "*otwiera browara*", "*stawia kolke*", "*wlacza disco polo*"];
                eventText = pa[Math.rand().abs() % pa.size()]; happiness += 12; hunger -= 8; return true;
            }
            if (mood == :feral) { eventText = "*szuka kielbasy*"; hunger -= 10; energy -= 6; return true; }
            if (mood == :existential) { eventText = "*wzdycha na dzialce*"; happiness -= 2; return true; }
            if (mood == :love) { eventText = "*niechcacy przytula*"; happiness += 8; return true; }
        } else if (petType == TYPE_NOSACZ) {
            if (mood == :paranoid) { eventText = "E E E!! *chowa nos*"; happiness -= 3; return true; }
            if (mood == :love) { eventText = "*nos ociera o ciebie*"; happiness += 10; return true; }
            if (mood == :rage) { eventText = "EEEEE!!! *macha nosem*"; happiness += 5; energy -= 5; return true; }
            if (mood == :party) { eventText = "E E!! *nos tanczy!*"; happiness += 10; energy -= 5; return true; }
            if (mood == :existential) { eventText = "*wpatruje sie w nos*"; happiness -= 2; return true; }
        } else if (petType == TYPE_DONUT) {
            if (mood == :sugar_high) { eventText = "*sprinkle explosion!*"; happiness += 15; energy -= 10; return true; }
            if (mood == :paranoid) { eventText = "*hides from fork*"; energy -= 5; happiness -= 3; return true; }
            if (mood == :party) { eventText = "*sweet rolling!*"; happiness += 10; energy -= 5; return true; }
        } else if (petType == TYPE_CACTUSO) {
            if (mood == :existential) { eventText = "*photosynthesizes*"; health += 2; return true; }
        } else if (petType == TYPE_PIXELBOT) {
            if (mood == :sugar_high) { eventText = "*OVERCLOCKS CPU*"; energy -= 12; happiness += 10; return true; }
            if (mood == :paranoid) { eventText = "*runs antivirus*"; energy -= 5; health += 3; return true; }
        } else if (petType == TYPE_OCTAVIO) {
            if (mood == :sugar_high) { eventText = "*8-arm juggling!*"; energy -= 10; happiness += 12; return true; }
            if (mood == :feral) { eventText = "*kraken rampage*"; hunger -= 10; energy -= 8; return true; }
            if (mood == :party) { eventText = "*ink art show!*"; happiness += 10; energy -= 5; return true; }
        } else if (petType == TYPE_BATSY) {
            if (mood == :paranoid) { eventText = "*hides from light*"; energy -= 3; return true; }
            if (mood == :party) { eventText = "*midnight flight!*"; happiness += 10; energy -= 8; return true; }
        } else if (petType == TYPE_NUGGET) {
            if (mood == :paranoid) { eventText = "*hides from plate*"; energy -= 5; happiness -= 5; return true; }
            if (mood == :existential) { eventText = "*questions breading*"; happiness -= 3; return true; }
        } else if (petType == TYPE_FOCZKA) {
            if (mood == :love) { eventText = "*does a happy trick!*"; happiness += 12; energy -= 5; return true; }
            if (mood == :party) { eventText = "*splashes everyone!*"; happiness += 10; energy -= 6; return true; }
            if (mood == :existential) { eventText = "*stares at ocean...*"; happiness -= 3; return true; }
        } else if (petType == TYPE_RAINBOW) {
            if (mood == :sugar_high) { eventText = "*GLITTER EXPLOSION!*"; happiness += 15; energy -= 10; return true; }
            if (mood == :love) { eventText = "*paints hearts*"; happiness += 12; return true; }
            if (mood == :party) { eventText = "*prismatic dance!*"; happiness += 10; energy -= 5; return true; }
            if (mood == :existential) { eventText = "*colors dim slowly*"; happiness -= 5; return true; }
        } else if (petType == TYPE_DOGGO) {
            if (mood == :party) {
                var da = ["*ZOOMIES!!*", "*chases own tail*", "*BORKS loudly*", "*brings stick*"];
                eventText = da[Math.rand().abs() % da.size()]; happiness += 15; energy -= 8; return true;
            }
            if (mood == :love) { eventText = "*licks your face!!*"; happiness += 12; energy -= 4; return true; }
            if (mood == :sugar_high) { eventText = "*MAXIMUM ZOOMIES*"; happiness += 18; energy -= 12; return true; }
            if (mood == :feral) { eventText = "*digs up the couch*"; hunger -= 8; energy -= 6; return true; }
        } else if (petType == TYPE_UNDEAD) {
            if (mood == :existential) {
                var ua = ["*shambles forward*", "*rattles bones*", "*stares vacantly*", "*moans softly*"];
                eventText = ua[Math.rand().abs() % ua.size()]; happiness -= 2; return true;
            }
        }
        return false;
    }

    hidden function checkReturn() {
        updateCareStreak();
        var since = Time.now().value() - lastInteraction;
        if (since > 14400) { eventText = getReturnText(4); happiness += 30; }
        else if (since > 7200) { eventText = getReturnText(3); happiness += 20; }
        else if (since > 3600) { eventText = getReturnText(2); happiness += 10; }
        else if (since > 1800) { eventText = getReturnText(1); happiness += 5; }
        else { return; }
        _eventTime = Time.now().value();
        action = ACT_PLAYING;
        _actionTime = _eventTime;
        celebType = 1;
        pendingVibe = 2;
        clamp();
    }

    hidden function getReturnText(level) {
        if (petType == TYPE_POLACCO) {
            if (level >= 4) { return "No nareszcie k*rwa!"; }
            if (level >= 3) { return "Mysl*lem ze zdechl*s"; }
            if (level >= 2) { return "O, zyjemy jeszcze"; }
            return "No elo";
        }
        if (petType == TYPE_EMILKA) {
            if (level >= 4) { return "GDZIE BYLES?! *placz*"; }
            if (level >= 3) { return "Myslalam ze mnie RZUCILES!"; }
            if (level >= 2) { return "Tesknil*m SO MUCH!"; }
            return "Hej kochanie~";
        }
        if (petType == TYPE_VEXOR) {
            if (level >= 4) { return "Thought you f*cking died"; }
            if (level >= 3) { return "Oh great, the a*shole's back"; }
            if (level >= 2) { return "Took you long enough d*ck"; }
            return "The f*ck you want?";
        }
        if (petType == TYPE_NUGGET) {
            if (level >= 4) { return "I thought I expired!"; }
            if (level >= 3) { return "Still not eaten??"; }
            return "I exist still...";
        }
        if (petType == TYPE_FOCZKA) {
            if (level >= 4) { return "*ARF ARF ARF!!!*"; }
            if (level >= 3) { return "*happy seal noises!*"; }
            if (level >= 2) { return "*excited flop!*"; }
            return "*arf!*";
        }
        if (petType == TYPE_CACTUSO) {
            if (level >= 4) { return "...oh. You're back."; }
            return "...";
        }
        if (petType == TYPE_DONUT) {
            if (level >= 4) { return "DON'T EAT ME! Oh wait YAY!"; }
            if (level >= 3) { return "I was getting STALE!"; }
            return "Sweet return!";
        }
        if (petType == TYPE_PIXELBOT) {
            if (level >= 4) { return "USER: reconnected!"; }
            if (level >= 3) { return "UPTIME: restored"; }
            return "INPUT: detected";
        }
        if (petType == TYPE_DOGGO) {
            if (level >= 4) { return "*ZOOMS INTO YOU!!!*"; }
            if (level >= 3) { return "YOOOU'RE BACK!!!! WOOF"; }
            if (level >= 2) { return "*tail blur* BORK!!!"; }
            return "*wags furiously*";
        }
        if (petType == TYPE_UNDEAD) {
            if (level >= 4) { return "Still here. As always."; }
            if (level >= 3) { return "Time means nothing."; }
            if (level >= 2) { return "You returned. Good."; }
            return "...";
        }
        if (level >= 4) { return "YOU'RE BACK!!!"; }
        if (level >= 3) { return "Missed you SO much!"; }
        if (level >= 2) { return "Yay, you're here!"; }
        return "Hi again!";
    }

    // ===== Actions (trait-enhanced, track interaction) =====

    function feed() {
        if (!isAlive) { return; }
        checkReturn();
        lastInteraction = Time.now().value();
        var wasHungry = hunger > 60;

        if (hunger < 10) {
            if (petType == TYPE_UNDEAD) {
                hunger = 50;
                eventText = "*undead absorb food*";
                _eventTime = lastInteraction;
                action = ACT_EATING;
                _actionTime = lastInteraction;
                pendingVibe = 1;
                return;
            }
            hunger = 15;
            happiness -= 15;
            health -= 5;
            energy -= 10;
            poopCount += 2;
            if (poopCount > 5) { poopCount = 5; }
            if (!isSick && Math.rand().abs() % 3 == 0) { isSick = true; _sickTime = Time.now().value(); }
            pendingVibe = 3;
            action = ACT_EATING;
            _actionTime = lastInteraction;
            eventText = getOverfedText();
            _eventTime = lastInteraction;
            clamp();
            checkDeath();
            return;
        }

        var amt = 30;
        if (hasTrait(TRAIT_GLUTTON)) { amt = 40; }
        if (hasTrait(TRAIT_PICKY)) { amt = 20; }
        hunger -= amt;
        var joy = 5;
        if (hasTrait(TRAIT_PICKY)) { joy = 15; }
        if (hasTrait(TRAIT_CHEERFUL)) { joy += 5; }
        happiness += joy;

        if (hunger < 5) {
            happiness -= 10;
            energy -= 10;
            poopCount += 1;
            if (poopCount > 5) { poopCount = 5; }
            pendingVibe = 2;
            eventText = getStuffedText();
            _eventTime = lastInteraction;
        } else {
            eventText = wasHungry ? "Yummy!" : "Nom~";
            _eventTime = lastInteraction;
            pendingVibe = 1;
        }

        clamp();
        action = ACT_EATING;
        _actionTime = lastInteraction;
        if (wasHungry) { celebType = 1; }
    }

    hidden function getOverfedText() {
        if (petType == TYPE_EMILKA) { return "*BLEEEURGH* WHY?!"; }
        if (petType == TYPE_FLAMEY) { return "*spits fire & lunch*"; }
        if (petType == TYPE_AQUA) { return "*fountains everywhere*"; }
        if (petType == TYPE_ROCKY) { return "*avalanche from mouth*"; }
        if (petType == TYPE_GHOSTY) { return "*ecto-vomit...*"; }
        if (petType == TYPE_BLOBBY) { return "*splat splat splat*"; }
        if (petType == TYPE_SPARKY) { return "*zap-puke!*"; }
        if (petType == TYPE_FROSTY) { return "*frozen barf!*"; }
        if (petType == TYPE_SHROOMY) { return "*spore explosion!*"; }
        if (petType == TYPE_VEXOR) { return "*pukes f*cking fire*"; }
        if (petType == TYPE_CHIKKO) { return "BAWK BAWK *egg?!*"; }
        if (petType == TYPE_DZIKKO) { return "*OINK* *mud puke*"; }
        if (petType == TYPE_POLACCO) { return "KURWA! Zaraz rzyge!"; }
        if (petType == TYPE_NOSACZ) { return "EEEEE *nos eksploduje*"; }
        if (petType == TYPE_DONUT) { return "*icing everywhere*"; }
        if (petType == TYPE_CACTUSO) { return "*spits needles*"; }
        if (petType == TYPE_PIXELBOT) { return "OVERFLOW ERROR!"; }
        if (petType == TYPE_OCTAVIO) { return "*8 arms vomiting*"; }
        if (petType == TYPE_BATSY) { return "*upside-down puke*"; }
        if (petType == TYPE_NUGGET) { return "*crumbs falling off*"; }
        if (petType == TYPE_FOCZKA) { return "*barfs fish*"; }
        if (petType == TYPE_RAINBOW) { return "*rainbow vomit!*"; }
        if (petType == TYPE_DOGGO) { return "*barfs & wags tail*"; }
        if (petType == TYPE_UNDEAD) { return "*rises from barf*"; }
        return "*BLEARGH!*";
    }

    hidden function getStuffedText() {
        if (petType == TYPE_EMILKA) { return "ugh... too much..."; }
        if (petType == TYPE_FLAMEY) { return "*burp* ...fire..."; }
        if (petType == TYPE_AQUA) { return "*gurgle gurgle*"; }
        if (petType == TYPE_ROCKY) { return "belly... heavy..."; }
        if (petType == TYPE_BLOBBY) { return "*wobble wobble*"; }
        if (petType == TYPE_SHROOMY) { return "shroom overload..."; }
        if (petType == TYPE_GHOSTY) { return "*ecto-burp*"; }
        if (petType == TYPE_SPARKY) { return "*static belly*"; }
        if (petType == TYPE_FROSTY) { return "*brain freeze...*"; }
        if (petType == TYPE_VEXOR) { return "This food is sh*t!"; }
        if (petType == TYPE_CHIKKO) { return "*panicked clucking*"; }
        if (petType == TYPE_DZIKKO) { return "*snort* more..."; }
        if (petType == TYPE_POLACCO) { return "Oj najalem sie..."; }
        if (petType == TYPE_NOSACZ) { return "E... nos pelny..."; }
        if (petType == TYPE_DONUT) { return "*sugar coma...*"; }
        if (petType == TYPE_CACTUSO) { return "...sufficient."; }
        if (petType == TYPE_PIXELBOT) { return "STORAGE: 99%"; }
        if (petType == TYPE_OCTAVIO) { return "*8 belches*"; }
        if (petType == TYPE_BATSY) { return "*hangs heavier*"; }
        if (petType == TYPE_NUGGET) { return "*getting soggy*"; }
        if (petType == TYPE_FOCZKA) { return "*happy belly flop*"; }
        if (petType == TYPE_RAINBOW) { return "*glitter burp~*"; }
        if (petType == TYPE_DOGGO) { return "*happy belch*"; }
        if (petType == TYPE_UNDEAD) { return "...undead dont eat"; }
        return "*urp* ...too full";
    }

    function playResult(score) {
        if (!isAlive) { return; }
        checkReturn();
        lastInteraction = Time.now().value();
        var joy;
        var cost;
        if (score >= 3) { joy = 40; cost = 15; eventText = "Perfect play!"; }
        else if (score >= 2) { joy = 30; cost = 12; eventText = "Great play!"; }
        else if (score >= 1) { joy = 20; cost = 10; eventText = "Nice try!"; }
        else { joy = 10; cost = 5; eventText = "Fun anyway!"; }
        if (hasTrait(TRAIT_HYPER)) { joy = joy * 3 / 2; cost += 5; }
        if (hasTrait(TRAIT_PLAYFUL)) { joy = joy * 5 / 4; }
        if (hasTrait(TRAIT_GRUMPY)) { joy = joy * 6 / 5; }
        if (hasTrait(TRAIT_CHEERFUL)) { joy += 5; }
        happiness += joy;
        energy -= cost;
        clamp();
        action = ACT_PLAYING;
        _actionTime = lastInteraction;
        _eventTime = _actionTime;
        pendingVibe = 1;
        if (score >= 3) { celebType = 2; }
    }

    function clean() {
        if (!isAlive) { return; }
        checkReturn();
        lastInteraction = Time.now().value();
        poopCount = 0;
        var joy = 10;
        if (hasTrait(TRAIT_CHEERFUL)) { joy += 5; }
        happiness += joy;
        clamp();
        action = ACT_CLEANING;
        _actionTime = lastInteraction;
        pendingVibe = 1;
    }

    function heal() {
        if (!isAlive) { return; }
        checkReturn();
        lastInteraction = Time.now().value();
        action = ACT_HEALING;
        _actionTime = lastInteraction;
        pendingVibe = 1;
        if (isSick) {
            isSick = false;
            celebType = 1;
            var amt = hasTrait(TRAIT_FRAGILE) ? 50 : 30;
            health += amt;
            var joy = 10;
            if (hasTrait(TRAIT_CHEERFUL)) { joy += 5; }
            happiness += joy;
            _sickTime = 0;
            clamp();
            eventText = "Feeling better!";
            _eventTime = lastInteraction;
        }
    }

    function nap() {
        if (!isAlive) { return; }
        checkReturn();
        lastInteraction = Time.now().value();
        var amt = 40;
        if (hasTrait(TRAIT_SLEEPY)) { amt = 60; }
        if (hasTrait(TRAIT_LAZY)) { amt = 55; }
        energy += amt;
        var joy = 5;
        if (hasTrait(TRAIT_CHEERFUL)) { joy += 5; }
        happiness += joy;
        clamp();
        action = ACT_SLEEPING;
        _actionTime = lastInteraction;
        pendingVibe = 1;
    }

    function punish() {
        if (!isAlive) { return; }
        updateCareStreak();
        lastInteraction = Time.now().value();
        var roll = Math.rand().abs() % 10;

        if (petType == TYPE_EMILKA) { roll -= 2; }
        else if (petType == TYPE_ROCKY) { roll += 2; }
        else if (petType == TYPE_GHOSTY) { roll -= 1; }
        else if (petType == TYPE_BLOBBY) { roll -= 1; }
        else if (petType == TYPE_FROSTY) { roll += 1; }
        else if (petType == TYPE_FLAMEY) { roll -= 1; }
        else if (petType == TYPE_VEXOR) { roll += 5; }
        else if (petType == TYPE_CHIKKO) { roll -= 3; }
        else if (petType == TYPE_DZIKKO) { roll += 4; }
        else if (petType == TYPE_POLACCO) { roll += 3; }
        else if (petType == TYPE_NOSACZ) { roll -= 1; }
        else if (petType == TYPE_DONUT) { roll -= 4; }
        else if (petType == TYPE_CACTUSO) { roll += 4; }
        else if (petType == TYPE_PIXELBOT) { roll += 2; }
        else if (petType == TYPE_OCTAVIO) { roll += 0; }
        else if (petType == TYPE_BATSY) { roll += 1; }
        else if (petType == TYPE_NUGGET) { roll -= 3; }
        else if (petType == TYPE_FOCZKA) { roll -= 1; }
        else if (petType == TYPE_RAINBOW) { roll -= 2; }

        if (hasTrait(TRAIT_HARDY)) { roll += 1; }
        if (hasTrait(TRAIT_FRAGILE)) { roll -= 2; }
        if (hasTrait(TRAIT_CHEERFUL)) { roll += 1; }
        if (hasTrait(TRAIT_GRUMPY)) { roll -= 1; }

        if (health < 30) { roll -= 1; }
        if (health < 15) { roll -= 2; }

        var mood = getMoodState();
        if (mood == :love) { roll -= 3; }
        else if (mood == :rage || mood == :feral) { roll -= 1; }
        else if (mood == :existential) { roll -= 1; }

        if (roll >= 8) {
            happiness += 20; hunger -= 10; energy += 10;
            if (poopCount > 0) { poopCount -= 1; }
            if (isSick && Math.rand().abs() % 3 == 0) { isSick = false; health += 10; }
            pendingVibe = 2; celebType = 1;
            eventText = getPunishGood();
        } else if (roll >= 5) {
            happiness -= 10; hunger -= 5;
            if (poopCount > 0) { poopCount -= 1; }
            pendingVibe = 1;
            eventText = getPunishOk();
        } else if (roll >= 2) {
            happiness -= 20; health -= 5; energy -= 8;
            pendingVibe = 3;
            eventText = getPunishBad();
        } else if (roll >= -1) {
            happiness -= 30; health -= 12; energy -= 15;
            if (!isSick && Math.rand().abs() % 4 == 0) { isSick = true; _sickTime = Time.now().value(); }
            pendingVibe = 4;
            suggestedAction = 3;
            eventText = getPunishTrauma();
        } else {
            happiness -= 45; health -= 25; energy -= 20;
            if (!isSick) { isSick = true; _sickTime = Time.now().value(); }
            pendingVibe = 4;
            suggestedAction = 3;
            eventText = getPunishDevastating();
        }

        action = ACT_PLAYING;
        _actionTime = lastInteraction;
        _eventTime = lastInteraction;
        clamp();
        checkDeath();
    }

    function hug() {
        if (!isAlive) { return; }
        checkReturn();
        lastInteraction = Time.now().value();

        hugStress += getHugStressRate();
        if (hugStress < 0) { hugStress = 0; }
        if (hugStress > 100) { hugStress = 100; }

        if (hugStress >= 95) {
            happiness -= 30; health -= 25; energy -= 20;
            if (!isSick) { isSick = true; _sickTime = Time.now().value(); }
            pendingVibe = 4;
            suggestedAction = 3;
            eventText = getHugLethalText();
            action = ACT_PLAYING;
            _actionTime = lastInteraction;
            _eventTime = lastInteraction;
            clamp(); checkDeath();
            return;
        }
        if (hugStress >= 75) {
            happiness -= 15; health -= 10; energy -= 10;
            pendingVibe = 3;
            suggestedAction = 3;
            eventText = getHugSevereText();
            action = ACT_PLAYING;
            _actionTime = lastInteraction;
            _eventTime = lastInteraction;
            clamp();
            return;
        }
        if (hugStress >= 55) {
            happiness += 3;
            pendingVibe = 2;
            eventText = getHugWarningText();
            action = ACT_PLAYING;
            _actionTime = lastInteraction;
            _eventTime = lastInteraction;
            clamp();
            return;
        }

        var roll = Math.rand().abs() % 10;
        if (petType == TYPE_EMILKA) { roll += 3; }
        else if (petType == TYPE_AQUA) { roll += 2; }
        else if (petType == TYPE_FROSTY) { roll += 1; }
        else if (petType == TYPE_ROCKY) { roll -= 2; }
        else if (petType == TYPE_FLAMEY) { roll -= 1; }
        else if (petType == TYPE_SPARKY) { roll -= 1; }
        else if (petType == TYPE_VEXOR) { roll -= 3; }
        else if (petType == TYPE_CHIKKO) { roll += 1; }
        else if (petType == TYPE_DZIKKO) { roll -= 4; }
        else if (petType == TYPE_POLACCO) { roll -= 2; }
        else if (petType == TYPE_NOSACZ) { roll += 1; }
        else if (petType == TYPE_DONUT) { roll += 3; }
        else if (petType == TYPE_CACTUSO) { roll -= 5; }
        else if (petType == TYPE_PIXELBOT) { roll -= 1; }
        else if (petType == TYPE_OCTAVIO) { roll += 2; }
        else if (petType == TYPE_BATSY) { roll -= 1; }
        else if (petType == TYPE_NUGGET) { roll += 1; }
        else if (petType == TYPE_FOCZKA) { roll += 2; }
        else if (petType == TYPE_RAINBOW) { roll += 3; }

        if (hasTrait(TRAIT_CHEERFUL)) { roll += 1; }
        if (hasTrait(TRAIT_GRUMPY)) { roll -= 2; }
        if (hasTrait(TRAIT_PLAYFUL)) { roll += 1; }

        var mood = getMoodState();
        if (mood == :love) { roll += 3; }
        else if (mood == :party) { roll += 2; }
        else if (mood == :rage) { roll -= 2; }
        else if (mood == :feral) { roll -= 3; }
        else if (mood == :existential) { roll += 1; }

        if (roll >= 9) {
            happiness += 30; energy += 15; health += 5;
            pendingVibe = 2; celebType = 2;
            eventText = getHugEcstasy();
        } else if (roll >= 6) {
            happiness += 20; energy += 10;
            pendingVibe = 2; celebType = 1;
            eventText = getHugLove();
        } else if (roll >= 3) {
            happiness += 10; energy += 5;
            pendingVibe = 1;
            eventText = getHugOk();
        } else if (roll >= 0) {
            happiness += 3;
            pendingVibe = 1;
            eventText = getHugCold();
        } else {
            happiness -= 10; energy -= 5;
            pendingVibe = 3;
            eventText = getHugReject();
        }

        action = ACT_PLAYING;
        _actionTime = lastInteraction;
        _eventTime = lastInteraction;
        clamp();
    }

    hidden function getHugStressRate() {
        var rate = 15;
        if (petType == TYPE_EMILKA) { rate = -10; }
        else if (petType == TYPE_VEXOR) { rate = 40; }
        else if (petType == TYPE_ROCKY) { rate = 35; }
        else if (petType == TYPE_FLAMEY) { rate = 28; }
        else if (petType == TYPE_FROSTY) { rate = 25; }
        else if (petType == TYPE_SPARKY) { rate = 22; }
        else if (petType == TYPE_GHOSTY) { rate = 18; }
        else if (petType == TYPE_AQUA) { rate = 14; }
        else if (petType == TYPE_BLOBBY) { rate = 14; }
        else if (petType == TYPE_SHROOMY) { rate = 16; }
        else if (petType == TYPE_CHIKKO) { rate = 20; }
        else if (petType == TYPE_DZIKKO) { rate = 38; }
        else if (petType == TYPE_POLACCO) { rate = 25; }
        else if (petType == TYPE_NOSACZ) { rate = 18; }
        else if (petType == TYPE_DONUT) { rate = -5; }
        else if (petType == TYPE_CACTUSO) { rate = 50; }
        else if (petType == TYPE_PIXELBOT) { rate = 20; }
        else if (petType == TYPE_OCTAVIO) { rate = 10; }
        else if (petType == TYPE_BATSY) { rate = 22; }
        else if (petType == TYPE_NUGGET) { rate = 15; }
        else if (petType == TYPE_FOCZKA) { rate = -3; }
        else if (petType == TYPE_RAINBOW) { rate = -8; }
        else if (petType == TYPE_DOGGO) { rate = -5; }
        else if (petType == TYPE_UNDEAD) { rate = -15; }
        if (hasTrait(TRAIT_CHEERFUL)) { rate -= 3; }
        if (hasTrait(TRAIT_GRUMPY)) { rate += 5; }
        if (hasTrait(TRAIT_PLAYFUL)) { rate -= 2; }
        return rate;
    }

    hidden function getHugWarningText() {
        if (petType == TYPE_ROCKY) { return "Personal space!"; }
        if (petType == TYPE_FLAMEY) { return "*getting too hot*"; }
        if (petType == TYPE_FROSTY) { return "I'm melting..."; }
        if (petType == TYPE_SPARKY) { return "*sparking...*"; }
        if (petType == TYPE_GHOSTY) { return "Too... solid..."; }
        if (petType == TYPE_AQUA) { return "*overflowing...*"; }
        if (petType == TYPE_BLOBBY) { return "*getting too big*"; }
        if (petType == TYPE_SHROOMY) { return "*spores intensify*"; }
        if (petType == TYPE_VEXOR) { return "F*CK OFF don't touch!"; }
        if (petType == TYPE_CHIKKO) { return "BAWK! P-PERSONAL SPACE!"; }
        if (petType == TYPE_DZIKKO) { return "*angry snort* BACK OFF"; }
        if (petType == TYPE_POLACCO) { return "Nie lap mnie k*rwa!"; }
        if (petType == TYPE_NOSACZ) { return "E! Nos nie chce!"; }
        if (petType == TYPE_DONUT) { return "Careful! I'm glazed!"; }
        if (petType == TYPE_CACTUSO) { return "*SPIKES EXTEND*"; }
        if (petType == TYPE_PIXELBOT) { return "WARNING: proximity!"; }
        if (petType == TYPE_OCTAVIO) { return "*ink warning shot*"; }
        if (petType == TYPE_BATSY) { return "*ultrasonic screech*"; }
        if (petType == TYPE_NUGGET) { return "U trying to EAT me?!"; }
        if (petType == TYPE_FOCZKA) { return "*arf arf!* gentle!"; }
        if (petType == TYPE_RAINBOW) { return "*sparkles dimming*"; }
        if (petType == TYPE_DOGGO) { return "*too excited to care*"; }
        if (petType == TYPE_UNDEAD) { return "*bones rattle...*"; }
        return "That's enough...";
    }

    hidden function getHugSevereText() {
        if (petType == TYPE_ROCKY) { return "*HEADBUTTS YOU*"; }
        if (petType == TYPE_FLAMEY) { return "*BURNS you badly*"; }
        if (petType == TYPE_FROSTY) { return "*cracking apart*"; }
        if (petType == TYPE_SPARKY) { return "*ELECTRIC SHOCK!*"; }
        if (petType == TYPE_GHOSTY) { return "*losing ghost form*"; }
        if (petType == TYPE_AQUA) { return "*flooding everything*"; }
        if (petType == TYPE_BLOBBY) { return "*unstable mass!*"; }
        if (petType == TYPE_SHROOMY) { return "*SPORE CLOUD!*"; }
        if (petType == TYPE_VEXOR) { return "I'LL F*CKING KILL YOU!"; }
        if (petType == TYPE_CHIKKO) { return "BAWKBAWKBAWK *PANICS*"; }
        if (petType == TYPE_DZIKKO) { return "*CHARGES at you*"; }
        if (petType == TYPE_POLACCO) { return "SPIERDAL*J JEBANY!"; }
        if (petType == TYPE_NOSACZ) { return "EEEEE!! *bije nosem*"; }
        if (petType == TYPE_DONUT) { return "*CRACKING apart!*"; }
        if (petType == TYPE_CACTUSO) { return "*IMPALES YOU*"; }
        if (petType == TYPE_PIXELBOT) { return "CRITICAL: OVERHEAT!"; }
        if (petType == TYPE_OCTAVIO) { return "*INK EXPLOSION!*"; }
        if (petType == TYPE_BATSY) { return "*BITES YOUR NECK!*"; }
        if (petType == TYPE_NUGGET) { return "*BREAKING APART!*"; }
        if (petType == TYPE_FOCZKA) { return "*LOUD BARKING!*"; }
        if (petType == TYPE_RAINBOW) { return "*COLORS FADING!*"; }
        if (petType == TYPE_DOGGO) { return "*LICKS YOU TO DEATH*"; }
        if (petType == TYPE_UNDEAD) { return "*UNDEAD SQUEEZE*"; }
        return "*pushes you HARD*";
    }

    hidden function getHugLethalText() {
        if (petType == TYPE_ROCKY) { return "*SMASHES EVERYTHING*"; }
        if (petType == TYPE_FLAMEY) { return "*COMBUSTION!!*"; }
        if (petType == TYPE_FROSTY) { return "*SHATTERS TO PIECES*"; }
        if (petType == TYPE_SPARKY) { return "*TOTAL OVERLOAD!*"; }
        if (petType == TYPE_GHOSTY) { return "*EXISTENTIAL COLLAPSE*"; }
        if (petType == TYPE_AQUA) { return "*EVAPORATES!!*"; }
        if (petType == TYPE_BLOBBY) { return "*ABOUT TO BURST!*"; }
        if (petType == TYPE_SHROOMY) { return "*SPORE APOCALYPSE!*"; }
        if (petType == TYPE_VEXOR) { return "YOU'RE F*CKING DEAD!"; }
        if (petType == TYPE_CHIKKO) { return "*DIES OF HEART ATTACK*"; }
        if (petType == TYPE_DZIKKO) { return "*GORES YOU WITH TUSKS*"; }
        if (petType == TYPE_POLACCO) { return "KURWA... serce..."; }
        if (petType == TYPE_NOSACZ) { return "NOS!! NOOOS!! E E E!!"; }
        if (petType == TYPE_DONUT) { return "*CRUSHED TO CRUMBS*"; }
        if (petType == TYPE_CACTUSO) { return "*TURNS INTO NEEDLES*"; }
        if (petType == TYPE_PIXELBOT) { return "FATAL: CORE MELTDOWN"; }
        if (petType == TYPE_OCTAVIO) { return "*TENTACLE OVERLOAD*"; }
        if (petType == TYPE_BATSY) { return "*DAYLIGHT EXPOSURE!*"; }
        if (petType == TYPE_NUGGET) { return "*EATEN ALIVE!*"; }
        if (petType == TYPE_FOCZKA) { return "*FLOPS INTO OCEAN*"; }
        if (petType == TYPE_RAINBOW) { return "*RAINBOW SHATTERED*"; }
        if (petType == TYPE_DOGGO) { return "*DIES OF HAPPINESS*"; }
        if (petType == TYPE_UNDEAD) { return "*BONES FLY OFF*"; }
        return "*CAN'T TAKE IT!*";
    }

    hidden function getHugEcstasy() {
        if (petType == TYPE_EMILKA) { return "BEST MOMENT EVER!!!"; }
        if (petType == TYPE_AQUA) { return "*melts into you*"; }
        if (petType == TYPE_FROSTY) { return "*ice heart shatters*"; }
        if (petType == TYPE_GHOSTY) { return "*becomes solid!*"; }
        if (petType == TYPE_VEXOR) { return "...the f*ck was that?!"; }
        if (petType == TYPE_CHIKKO) { return "I...I feel SAFE?! *egg*"; }
        if (petType == TYPE_DZIKKO) { return "*confused oinking*"; }
        if (petType == TYPE_POLACCO) { return "No...ch*j, dobre jest"; }
        if (petType == TYPE_NOSACZ) { return "EEEEE! *nos szczesliwy*"; }
        if (petType == TYPE_DONUT) { return "SWEET LOVE!!!"; }
        if (petType == TYPE_CACTUSO) { return "...didn't hurt?"; }
        if (petType == TYPE_PIXELBOT) { return "JOY.exe LAUNCHED!"; }
        if (petType == TYPE_OCTAVIO) { return "*8 ARMS HUG BACK!*"; }
        if (petType == TYPE_BATSY) { return "*wraps wings around*"; }
        if (petType == TYPE_NUGGET) { return "I'm NOT food! I'm LOVED!"; }
        if (petType == TYPE_FOCZKA) { return "*ARF ARF ARF!!* LOVE!"; }
        if (petType == TYPE_RAINBOW) { return "*DOUBLE RAINBOW!!!*"; }
        if (petType == TYPE_DOGGO) { return "*EXPLODES WITH JOY!!*"; }
        if (petType == TYPE_UNDEAD) { return "*FEELS ALIVE AGAIN*"; }
        var t = ["PURE LOVE!", "*crying happy*", "I'll NEVER forget!", "BEST HUG EVER!"];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getHugLove() {
        if (petType == TYPE_EMILKA) { return "*squeezes so tight*"; }
        if (petType == TYPE_BLOBBY) { return "*absorbs the warmth*"; }
        if (petType == TYPE_SHROOMY) { return "*releases happy spores*"; }
        if (petType == TYPE_VEXOR) { return "*WTF is happening*"; }
        if (petType == TYPE_CHIKKO) { return "*nervous purring?*"; }
        if (petType == TYPE_DZIKKO) { return "*tolerates...barely*"; }
        if (petType == TYPE_POLACCO) { return "*klepa niezrecznie*"; }
        if (petType == TYPE_NOSACZ) { return "*ociera nos o ciebie*"; }
        if (petType == TYPE_DONUT) { return "*warm & glazed*"; }
        if (petType == TYPE_CACTUSO) { return "*carefully leans in*"; }
        if (petType == TYPE_PIXELBOT) { return "WARM: +2 degrees"; }
        if (petType == TYPE_OCTAVIO) { return "*gentle tentacles*"; }
        if (petType == TYPE_BATSY) { return "*happy chirps*"; }
        if (petType == TYPE_NUGGET) { return "*warm & crispy*"; }
        if (petType == TYPE_FOCZKA) { return "*nuzzles your hand*"; }
        if (petType == TYPE_RAINBOW) { return "*glows brighter*"; }
        if (petType == TYPE_DOGGO) { return "*spins in circles*"; }
        if (petType == TYPE_UNDEAD) { return "*cold but cozy*"; }
        var t = ["So warm...", "*nuzzles*", "I love this!", "*purrs*"];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getHugOk() {
        if (petType == TYPE_ROCKY) { return "Hm. Not bad."; }
        if (petType == TYPE_FLAMEY) { return "*warm but confused*"; }
        if (petType == TYPE_VEXOR) { return "F*cking disgusting."; }
        if (petType == TYPE_CHIKKO) { return "*twitchy but ok*"; }
        if (petType == TYPE_DZIKKO) { return "Hmph. *snort*"; }
        if (petType == TYPE_POLACCO) { return "No...ujdzie w ch*j"; }
        if (petType == TYPE_NOSACZ) { return "E... ok"; }
        if (petType == TYPE_DONUT) { return "*soft squishy*"; }
        if (petType == TYPE_CACTUSO) { return "*very still*"; }
        if (petType == TYPE_PIXELBOT) { return "CONTACT: accepted"; }
        if (petType == TYPE_OCTAVIO) { return "*two arms pat*"; }
        if (petType == TYPE_BATSY) { return "*folds wings*"; }
        if (petType == TYPE_NUGGET) { return "*warm crunch*"; }
        if (petType == TYPE_FOCZKA) { return "*happy flop*"; }
        if (petType == TYPE_RAINBOW) { return "*soft glow*"; }
        if (petType == TYPE_DOGGO) { return "*tail wagging*"; }
        if (petType == TYPE_UNDEAD) { return "*skull nod*"; }
        var t = ["*small smile*", "Thanks...", "That's nice", "*relaxes*"];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getHugCold() {
        if (petType == TYPE_ROCKY) { return "*is a rock*"; }
        if (petType == TYPE_FLAMEY) { return "Don't touch me."; }
        if (petType == TYPE_SPARKY) { return "*zaps you*"; }
        if (petType == TYPE_VEXOR) { return "Touch me again, I dare u"; }
        if (petType == TYPE_CHIKKO) { return "*freezes in terror*"; }
        if (petType == TYPE_DZIKKO) { return "*completely ignores*"; }
        if (petType == TYPE_POLACCO) { return "Odpierdol sie."; }
        if (petType == TYPE_NOSACZ) { return "*odwraca nos*"; }
        if (petType == TYPE_DONUT) { return "*stale silence*"; }
        if (petType == TYPE_CACTUSO) { return "*prickle*"; }
        if (petType == TYPE_PIXELBOT) { return "INPUT: ignored"; }
        if (petType == TYPE_OCTAVIO) { return "*one arm shrug*"; }
        if (petType == TYPE_BATSY) { return "*sleeps through it*"; }
        if (petType == TYPE_NUGGET) { return "*cold nugget*"; }
        if (petType == TYPE_FOCZKA) { return "*rolls over*"; }
        if (petType == TYPE_RAINBOW) { return "*dim glow*"; }
        if (petType == TYPE_DOGGO) { return "*too distracted*"; }
        if (petType == TYPE_UNDEAD) { return "..."; }
        var t = ["*stiff*", "...ok", "*doesn't react*", "Hmph."];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getHugReject() {
        if (petType == TYPE_FLAMEY) { return "*BURNS you*"; }
        if (petType == TYPE_SPARKY) { return "*SHOCK!*"; }
        if (petType == TYPE_ROCKY) { return "*headbutts you*"; }
        if (petType == TYPE_FROSTY) { return "*frostbite!*"; }
        if (petType == TYPE_VEXOR) { return "EAT SH*T AND DIE!"; }
        if (petType == TYPE_CHIKKO) { return "*PECKS YOUR EYES*"; }
        if (petType == TYPE_DZIKKO) { return "*FULL CHARGE ATTACK*"; }
        if (petType == TYPE_POLACCO) { return "WON KURWA!!"; }
        if (petType == TYPE_NOSACZ) { return "E!! *wali nosem!*"; }
        if (petType == TYPE_DONUT) { return "I'LL CRUMBLE ON U!"; }
        if (petType == TYPE_CACTUSO) { return "*1000 NEEDLES!*"; }
        if (petType == TYPE_PIXELBOT) { return "FIREWALL: ACTIVE!"; }
        if (petType == TYPE_OCTAVIO) { return "*FULL INK BLAST!*"; }
        if (petType == TYPE_BATSY) { return "*SONIC BLAST!*"; }
        if (petType == TYPE_NUGGET) { return "*throws ketchup*"; }
        if (petType == TYPE_FOCZKA) { return "*SLAPS with flipper*"; }
        if (petType == TYPE_RAINBOW) { return "*blinding flash!*"; }
        var t = ["GET OFF ME!", "*bites*", "NOT NOW!", "*pushes away*"];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function autoResolveDilemma() {
        var dt = dilemmaType;
        dilemmaType = 0;
        dilemmaText = "";
        _dilemmaTime = 0;
        _eventTime = Time.now().value();

        var text = getDilemmaIgnoreText(dt);
        eventText = text;

        var delta = getDilemmaIgnoreDelta();
        happiness += delta[0];
        health += delta[1];
        energy += delta[2];
        hunger += delta[3];

        if (delta[1] < -5 && !isSick && Math.rand().abs() % 4 == 0) {
            isSick = true; _sickTime = Time.now().value();
            suggestedAction = 3;
        }

        if (delta[0] < -15 || delta[1] < -10) { pendingVibe = 2; }
        action = ACT_NONE;
        clamp();
        checkDeath();
    }

    hidden function getDilemmaIgnoreText(dt) {
        if (petType == TYPE_EMILKA) {
            var t = ["*cries alone*", "Nobody cares...", "You LEFT ME?!", "*sobs quietly*", "I hate you..."];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_VEXOR) {
            var t = ["*seethes in silence*", "Fine. F*ck you too.", "Ignore me?! BIG MISTAKE.", "*destroys something*"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_DOGGO) {
            var t = ["*resolves it alone!*", "*wags tail anyway*", "*figured it out!*", "*waits patiently*"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_UNDEAD) { return "...handled it."; }
        if (petType == TYPE_POLACCO) {
            var t = ["Sam se poradzilem k*rwa", "Gdzie Ciebie nosi?!", "Olal mnie ch*j", "*beka z rozczarowania*"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_NOSACZ) {
            var t = ["E E... sam.", "E? Czemu? E.", "*nos smutny*", "EEE!! Zostaw nos!"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_CHIKKO) {
            var t = ["BAWK! *hides*", "*panics alone*", "Nobody... *cluck*"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_FOCZKA) {
            var t = ["*sad arf...*", "*flopped alone*", "*quiet seal noise*"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_RAINBOW) {
            var t = ["*colors flicker*", "*dims alone...*", "*glitter fades*"];
            return t[Math.rand().abs() % t.size()];
        }
        if (dt == 4) {
            var t = ["*still staring...*", "Gave up waiting.", "*sigh* ok then..."];
            return t[Math.rand().abs() % t.size()];
        }
        if (dt == 1 || dt == 3) {
            var t = ["*calmed down... barely*", "*still fuming*", "*settles... kinda*"];
            return t[Math.rand().abs() % t.size()];
        }
        var t = ["*worked it out alone*", "Handled it I guess.", "*sighs*", "Fine, whatever."];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getDilemmaIgnoreDelta() {
        var dHappy = -10;
        var dHealth = 0;
        var dEnergy = -5;
        var dHunger = 0;

        if (petType == TYPE_EMILKA)   { dHappy = -25; dHealth = -5; }
        else if (petType == TYPE_VEXOR)    { dHappy = -20; dHealth = -8; dEnergy = -8; }
        else if (petType == TYPE_DOGGO)    { dHappy = 5; dHealth = 0; dEnergy = -3; }
        else if (petType == TYPE_UNDEAD)   { dHappy = 0; dHealth = 0; dEnergy = 0; }
        else if (petType == TYPE_POLACCO)  { dHappy = -15; dEnergy = -10; dHunger = 5; }
        else if (petType == TYPE_NOSACZ)   { dHappy = -12; dHealth = -3; }
        else if (petType == TYPE_CHIKKO)   { dHappy = -18; dHealth = -5; dEnergy = -8; }
        else if (petType == TYPE_DZIKKO)   { dHappy = -20; dHealth = -10; }
        else if (petType == TYPE_ROCKY)    { dHappy = -5; dHealth = 5; dEnergy = 5; }
        else if (petType == TYPE_FROSTY)   { dHappy = -8; }
        else if (petType == TYPE_AQUA)     { dHappy = -8; dEnergy = -3; }
        else if (petType == TYPE_GHOSTY)   { dHappy = -12; dHealth = -5; }
        else if (petType == TYPE_SPARKY)   { dHappy = -5; dEnergy = -15; }
        else if (petType == TYPE_RAINBOW)  { dHappy = -15; dHealth = -3; }
        else if (petType == TYPE_FOCZKA)   { dHappy = -12; dEnergy = -5; }
        else if (petType == TYPE_CACTUSO)  { dHappy = 0; dHealth = 3; }
        else if (petType == TYPE_DONUT)    { dHappy = -18; dHealth = -5; }
        else if (petType == TYPE_PIXELBOT) { dHappy = -5; }
        else if (petType == TYPE_BATSY)    { dHappy = -8; dEnergy = 10; }
        else if (petType == TYPE_OCTAVIO)  { dHappy = -10; dHealth = -5; }

        if (hasTrait(TRAIT_CHEERFUL)) { dHappy += 8; dHealth += 2; }
        if (hasTrait(TRAIT_GRUMPY))   { dHappy -= 8; dHealth -= 3; }
        if (hasTrait(TRAIT_HARDY))    { dHealth += 5; dEnergy += 3; }
        if (hasTrait(TRAIT_FRAGILE))  { dHealth -= 5; dHappy -= 5; }
        if (hasTrait(TRAIT_PLAYFUL))  { dHappy += 5; }
        if (hasTrait(TRAIT_LAZY))     { dEnergy += 5; dHappy -= 3; }
        if (hasTrait(TRAIT_HYPER))    { dEnergy -= 10; dHappy += 3; }

        return [dHappy, dHealth, dEnergy, dHunger];
    }

    function triggerDilemma() {
        var mood = getMoodState();
        if (mood == :rage) {
            var r = Math.rand().abs() % 4;
            if (r == 0) { dilemmaType = 1; dilemmaText = "is destroying everything!"; }
            else if (r == 1) { dilemmaType = 1; dilemmaText = "bit your finger!"; }
            else if (r == 2) { dilemmaType = 1; dilemmaText = "refuses to eat!"; }
            else { dilemmaType = 1; dilemmaText = "screams at you!"; }
        } else if (mood == :love) {
            var r = Math.rand().abs() % 4;
            if (r == 0) { dilemmaType = 2; dilemmaText = "won't let you leave!"; }
            else if (r == 1) { dilemmaType = 2; dilemmaText = "is obsessively clingy!"; }
            else if (r == 2) { dilemmaType = 2; dilemmaText = "demands ALL attention!"; }
            else { dilemmaType = 2; dilemmaText = "says 'ONLY ME!'"; }
        } else if (mood == :feral) {
            var r = Math.rand().abs() % 3;
            if (r == 0) { dilemmaType = 3; dilemmaText = "is eating the screen!"; }
            else if (r == 1) { dilemmaType = 3; dilemmaText = "bit another pet!"; }
            else { dilemmaType = 3; dilemmaText = "went completely wild!"; }
        } else if (mood == :existential) {
            var r = Math.rand().abs() % 3;
            if (r == 0) { dilemmaType = 4; dilemmaText = "asks: 'Why am I alive?'"; }
            else if (r == 1) { dilemmaType = 4; dilemmaText = "won't move at all..."; }
            else { dilemmaType = 4; dilemmaText = "stares into nothing..."; }
        } else if (mood == :sugar_high) {
            var r = Math.rand().abs() % 3;
            if (r == 0) { dilemmaType = 5; dilemmaText = "broke something!"; }
            else if (r == 1) { dilemmaType = 5; dilemmaText = "can't stop bouncing!"; }
            else { dilemmaType = 5; dilemmaText = "is out of control!"; }
        } else if (mood == :paranoid) {
            var r = Math.rand().abs() % 3;
            if (r == 0) { dilemmaType = 6; dilemmaText = "hides and won't come out!"; }
            else if (r == 1) { dilemmaType = 6; dilemmaText = "thinks you're the enemy!"; }
            else { dilemmaType = 6; dilemmaText = "is shaking in fear!"; }
        } else if (mood == :party) {
            var r = Math.rand().abs() % 3;
            if (r == 0) { dilemmaType = 7; dilemmaText = "won't stop dancing!"; }
            else if (r == 1) { dilemmaType = 7; dilemmaText = "is too loud!"; }
            else { dilemmaType = 7; dilemmaText = "keeps everyone awake!"; }
        } else {
            dilemmaType = 0;
            dilemmaText = "";
        }
        if (dilemmaType > 0) {
            pendingVibe = 3;
            _dilemmaTime = Time.now().value();
        }
    }

    function resolveDilemma(choice) {
        if (dilemmaType == 0) { return; }
        var dt = dilemmaType;
        dilemmaType = 0;
        dilemmaText = "";
        _dilemmaTime = 0;
        _eventTime = Time.now().value();

        if (choice == 1) {
            hug();
            if (dt == 1) {
                if (Math.rand().abs() % 3 == 0) {
                    eventText = "Love conquers rage!";
                    happiness += 15;
                    celebType = 2; pendingVibe = 2;
                } else {
                    eventText = "*bites harder*";
                    health -= 10; happiness -= 10;
                    pendingVibe = 3;
                }
            } else if (dt == 2) {
                eventText = "Love overload!";
                happiness += 20; energy -= 15;
                celebType = 1; pendingVibe = 2;
            } else if (dt == 3) {
                if (Math.rand().abs() % 4 == 0) {
                    eventText = "*calms down slowly*";
                    happiness += 10;
                    celebType = 1;
                } else {
                    eventText = "*BITES you!*";
                    health -= 15; happiness -= 5;
                    pendingVibe = 4;
                }
            } else if (dt == 4) {
                eventText = "You're here for me...";
                happiness += 25; energy += 10;
                celebType = 2; pendingVibe = 2;
            } else if (dt == 5) {
                if (Math.rand().abs() % 2 == 0) {
                    eventText = "*hugs and calms*";
                    happiness += 10; energy -= 10;
                } else {
                    eventText = "*too hyper to hug!*";
                    happiness += 3; energy -= 5;
                }
            } else if (dt == 6) {
                eventText = "You're safe with me";
                happiness += 20; health += 5;
                celebType = 1; pendingVibe = 2;
            } else if (dt == 7) {
                eventText = "Dance together!";
                happiness += 15; energy -= 10;
                celebType = 1;
            }
        } else {
            punish();
            if (dt == 1) {
                if (Math.rand().abs() % 3 == 0) {
                    eventText = "*stops, shocked*";
                    happiness -= 20;
                    hunger -= 10;
                } else {
                    eventText = "EVEN MORE RAGE!";
                    happiness -= 30; health -= 10;
                    pendingVibe = 4;
                }
            } else if (dt == 2) {
                eventText = "You DON'T love me?!";
                happiness -= 40; health -= 10;
                pendingVibe = 4;
            } else if (dt == 3) {
                if (Math.rand().abs() % 2 == 0) {
                    eventText = "*scared into obedience*";
                    happiness -= 25;
                    hunger -= 5;
                } else {
                    eventText = "*attacks back!*";
                    health -= 20; happiness -= 15;
                    pendingVibe = 4;
                }
            } else if (dt == 4) {
                eventText = "Now I REALLY want to die";
                happiness -= 35; health -= 15;
                pendingVibe = 4;
            } else if (dt == 5) {
                if (Math.rand().abs() % 3 == 0) {
                    eventText = "*snaps out of it*";
                    happiness -= 15; energy -= 20;
                } else {
                    eventText = "*starts crying*";
                    happiness -= 25; energy -= 10;
                }
            } else if (dt == 6) {
                eventText = "I KNEW you were evil!";
                happiness -= 35; health -= 10;
                if (!isSick) { isSick = true; _sickTime = Time.now().value(); }
                pendingVibe = 4;
            } else if (dt == 7) {
                if (Math.rand().abs() % 2 == 0) {
                    eventText = "Party's over...";
                    happiness -= 20; energy -= 15;
                } else {
                    eventText = "*keeps dancing HARDER*";
                    happiness += 5; energy -= 20;
                }
            }
        }
        action = ACT_PLAYING;
        _actionTime = Time.now().value();
        clamp();
        checkDeath();
    }

    hidden function getPunishGood() {
        if (petType == TYPE_EMILKA) { return "I'll be good! SORRY!"; }
        if (petType == TYPE_ROCKY) { return "*barely felt it*"; }
        if (petType == TYPE_GHOSTY) { return "...noted."; }
        if (petType == TYPE_FLAMEY) { return "*fire dims* ...fine"; }
        if (petType == TYPE_SHROOMY) { return "*absorbs lesson*"; }
        if (petType == TYPE_VEXOR) { return "F*CK YES! HARDER!"; }
        if (petType == TYPE_CHIKKO) { return "*BAWK* I-I'll be g-good!"; }
        if (petType == TYPE_DZIKKO) { return "*respects your power*"; }
        if (petType == TYPE_POLACCO) { return "Dobra dobra k*rwa!"; }
        if (petType == TYPE_NOSACZ) { return "E... nos smutny..."; }
        if (petType == TYPE_DONUT) { return "*sweetly sorry*"; }
        if (petType == TYPE_CACTUSO) { return "...noted."; }
        if (petType == TYPE_PIXELBOT) { return "BEHAVIOR: updated"; }
        if (petType == TYPE_OCTAVIO) { return "*8 arms surrender*"; }
        if (petType == TYPE_BATSY) { return "*hides in wings*"; }
        if (petType == TYPE_NUGGET) { return "*absorbs the lesson*"; }
        if (petType == TYPE_FOCZKA) { return "*sad arf* ...ok"; }
        if (petType == TYPE_RAINBOW) { return "*colors dim* sorry!"; }
        if (petType == TYPE_DOGGO) { return "*immediately forgives*"; }
        if (petType == TYPE_UNDEAD) { return "You can't hurt me."; }
        var t = ["I understand now!", "...lesson learned", "I'll be better!", "OK OK I get it!"];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getPunishOk() {
        if (petType == TYPE_EMILKA) { return "*crying* You hate me?!"; }
        if (petType == TYPE_GHOSTY) { return "*phases away*"; }
        if (petType == TYPE_FLAMEY) { return "*sizzles angrily*"; }
        if (petType == TYPE_ROCKY) { return "Hm. Whatever."; }
        if (petType == TYPE_VEXOR) { return "That all you got b*tch?"; }
        if (petType == TYPE_CHIKKO) { return "*shaking feathers*"; }
        if (petType == TYPE_DZIKKO) { return "*snorts dismissively*"; }
        if (petType == TYPE_POLACCO) { return "Za co ty ch*ju?!"; }
        if (petType == TYPE_NOSACZ) { return "E?! Za co?!"; }
        if (petType == TYPE_DONUT) { return "*dent in icing*"; }
        if (petType == TYPE_CACTUSO) { return "*unmoved*"; }
        if (petType == TYPE_PIXELBOT) { return "ANALYZING: input"; }
        if (petType == TYPE_OCTAVIO) { return "*3 arms flinch*"; }
        if (petType == TYPE_BATSY) { return "*hisses quietly*"; }
        if (petType == TYPE_NUGGET) { return "*crack in crust*"; }
        if (petType == TYPE_FOCZKA) { return "*whimpers softly*"; }
        if (petType == TYPE_RAINBOW) { return "*flickers*"; }
        if (petType == TYPE_DOGGO) { return "*still wags tail*"; }
        if (petType == TYPE_UNDEAD) { return "Noted. Still here."; }
        var t = ["*whimper* ...OK", "*flinches*", "...I'm sorry", "*lowers head*"];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getPunishBad() {
        if (petType == TYPE_EMILKA) { return "WHY?! I LOVED YOU!"; }
        if (petType == TYPE_GHOSTY) { return "*haunting stare*"; }
        if (petType == TYPE_FLAMEY) { return "I'LL BURN IT ALL!"; }
        if (petType == TYPE_AQUA) { return "*freezes up*"; }
        if (petType == TYPE_VEXOR) { return "Pathetic a*shole!"; }
        if (petType == TYPE_CHIKKO) { return "BAWK BAWK *runs away*"; }
        if (petType == TYPE_DZIKKO) { return "*headbutts you HARD*"; }
        if (petType == TYPE_POLACCO) { return "Ja ci ZAJEB*E!"; }
        if (petType == TYPE_NOSACZ) { return "EEEEE!! NOS BOLI!!"; }
        if (petType == TYPE_DONUT) { return "*sprinkles falling*"; }
        if (petType == TYPE_CACTUSO) { return "*drops a spine*"; }
        if (petType == TYPE_PIXELBOT) { return "ERROR: UNJUST INPUT"; }
        if (petType == TYPE_OCTAVIO) { return "*inks defensively*"; }
        if (petType == TYPE_BATSY) { return "*screams ultrasonic*"; }
        if (petType == TYPE_NUGGET) { return "Is this how I DIE?!"; }
        if (petType == TYPE_FOCZKA) { return "*LOUD SAD BARK!*"; }
        if (petType == TYPE_RAINBOW) { return "*colors bleeding!*"; }
        if (petType == TYPE_DOGGO) { return "*confused but loves u*"; }
        if (petType == TYPE_UNDEAD) { return "Pain is irrelevant."; }
        var t = ["That HURT!", "I didn't deserve that!", "STOP!", "*shaking*"];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getPunishTrauma() {
        if (petType == TYPE_EMILKA) { return "*won't look at you*"; }
        if (petType == TYPE_GHOSTY) { return "*becomes transparent*"; }
        if (petType == TYPE_BLOBBY) { return "*loses all shape*"; }
        if (petType == TYPE_FROSTY) { return "*cracks*"; }
        if (petType == TYPE_VEXOR) { return "Weak sh*t. Boring."; }
        if (petType == TYPE_CHIKKO) { return "*feathers falling off*"; }
        if (petType == TYPE_DZIKKO) { return "*FULL RAMPAGE MODE*"; }
        if (petType == TYPE_POLACCO) { return "*chleje na smutno*"; }
        if (petType == TYPE_NOSACZ) { return "*nos opada* E..."; }
        if (petType == TYPE_DONUT) { return "*icing melting...*"; }
        if (petType == TYPE_CACTUSO) { return "*loses needles*"; }
        if (petType == TYPE_PIXELBOT) { return "SYSTEM: corrupted"; }
        if (petType == TYPE_OCTAVIO) { return "*turns white*"; }
        if (petType == TYPE_BATSY) { return "*won't fly*"; }
        if (petType == TYPE_NUGGET) { return "*going stale...*"; }
        if (petType == TYPE_FOCZKA) { return "*won't come out of water*"; }
        if (petType == TYPE_RAINBOW) { return "*turning grey...*"; }
        if (petType == TYPE_DOGGO) { return "*licks your hand anyway*"; }
        if (petType == TYPE_UNDEAD) { return "I've survived worse."; }
        var t = ["*traumatized*", "*can't stop shaking*", "I'm scared of you...", "*silent*"];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getPunishDevastating() {
        if (petType == TYPE_EMILKA) { return "*breaks down sobbing*"; }
        if (petType == TYPE_GHOSTY) { return "*vanishes*"; }
        if (petType == TYPE_FLAMEY) { return "*flame goes out*"; }
        if (petType == TYPE_BLOBBY) { return "*dissolves*"; }
        if (petType == TYPE_FROSTY) { return "*shatters*"; }
        if (petType == TYPE_VEXOR) { return "NOW we're f*cking talking!"; }
        if (petType == TYPE_CHIKKO) { return "*lays final egg...*"; }
        if (petType == TYPE_DZIKKO) { return "*destroys EVERYTHING*"; }
        if (petType == TYPE_POLACCO) { return "Jebac to wszystko..."; }
        if (petType == TYPE_NOSACZ) { return "NOS... SPADL... E..."; }
        if (petType == TYPE_DONUT) { return "*crumbles apart*"; }
        if (petType == TYPE_CACTUSO) { return "*withers*"; }
        if (petType == TYPE_PIXELBOT) { return "FATAL: shutdown"; }
        if (petType == TYPE_OCTAVIO) { return "*all arms limp*"; }
        if (petType == TYPE_BATSY) { return "*falls to ground*"; }
        if (petType == TYPE_NUGGET) { return "*accepts being food*"; }
        if (petType == TYPE_FOCZKA) { return "*drifts away...*"; }
        if (petType == TYPE_RAINBOW) { return "*goes colorless*"; }
        if (petType == TYPE_DOGGO) { return "*whimpers but stays*"; }
        if (petType == TYPE_UNDEAD) { return "Death? Already been."; }
        var t = ["YOU MONSTER!", "Why do I exist?", "*broken*", "..."];
        return t[Math.rand().abs() % t.size()];
    }

    // ===== State =====

    function getState() {
        if (!isAlive) { return :dead; }
        if (action == ACT_EATING && hunger < 10) { return :stuffed; }
        if (action == ACT_EATING) { return :eating; }
        if (action == ACT_SLEEPING) { return :sleeping; }
        if (action == ACT_PLAYING || action == ACT_CLEANING || action == ACT_HEALING) { return :happy; }
        if (isSick && health >= 30) { return :sick; }
        var mood = getMoodState();
        if (mood == :rage) { return :rage; }
        if (mood == :love) { return :love; }
        if (mood == :feral) { return :feral; }
        if (mood == :existential) { return :sad; }
        if (mood == :paranoid) { return :desperate; }
        if (mood == :sugar_high || mood == :party) { return :happy; }
        if (isSick) { return :sick; }
        var nl = getNeglectLevel();
        var st = getNeglectSadThreshold();
        if (nl >= st + 1) { return :desperate; }
        if (nl >= st) { return :sad; }
        if (hunger > 80) { return :hungry; }
        if (happiness < 20 || energy < 15) { return :sad; }
        if (happiness > 60 && hunger < 40) { return :happy; }
        return :normal;
    }

    function getAgeDays() { return (Time.now().value() - _birthTime) / 86400; }
    function getAgeHours() { return ((Time.now().value() - _birthTime) % 86400) / 3600; }
    function hasTrait(t) { return (trait1 == t || trait2 == t); }

    function getWellbeing() {
        var food = 100 - hunger;
        return (food + happiness + energy + health) / 4;
    }

    function getNeglectLevel() {
        var since = Time.now().value() - lastInteraction;
        if (since > 14400) { return 4; }
        if (since > 7200) { return 3; }
        if (since > 3600) { return 2; }
        if (since > 1800) { return 1; }
        return 0;
    }

    function getNeglectSadThreshold() {
        var t = 2;
        if (petType == TYPE_EMILKA)   { t = 1; }
        else if (petType == TYPE_DOGGO)    { t = 1; }
        else if (petType == TYPE_DONUT)    { t = 1; }
        else if (petType == TYPE_RAINBOW)  { t = 1; }
        else if (petType == TYPE_FOCZKA)   { t = 1; }
        else if (petType == TYPE_CHIKKO)   { t = 1; }
        else if (petType == TYPE_NUGGET)   { t = 2; }
        else if (petType == TYPE_AQUA)     { t = 2; }
        else if (petType == TYPE_NOSACZ)   { t = 2; }
        else if (petType == TYPE_GHOSTY)   { t = 2; }
        else if (petType == TYPE_OCTAVIO)  { t = 2; }
        else if (petType == TYPE_SHROOMY)  { t = 2; }
        else if (petType == TYPE_FLAMEY)   { t = 2; }
        else if (petType == TYPE_SPARKY)   { t = 3; }
        else if (petType == TYPE_FROSTY)   { t = 3; }
        else if (petType == TYPE_ROCKY)    { t = 3; }
        else if (petType == TYPE_DZIKKO)   { t = 3; }
        else if (petType == TYPE_POLACCO)  { t = 3; }
        else if (petType == TYPE_BATSY)    { t = 3; }
        else if (petType == TYPE_PIXELBOT) { t = 3; }
        else if (petType == TYPE_VEXOR)    { t = 4; }
        else if (petType == TYPE_CACTUSO)  { t = 99; }
        else if (petType == TYPE_UNDEAD)   { t = 99; }

        if (hasTrait(TRAIT_CHEERFUL)) { t += 1; }
        if (hasTrait(TRAIT_GRUMPY))   { t -= 1; }
        if (hasTrait(TRAIT_FRAGILE))  { t -= 1; }
        if (hasTrait(TRAIT_HARDY))    { t += 1; }
        if (hasTrait(TRAIT_PLAYFUL))  { t += 1; }
        if (hasTrait(TRAIT_SLEEPY))   { t += 1; }
        if (t < 1)  { t = 1; }
        return t;
    }

    function getMoodState() {
        if (!isAlive || action != ACT_NONE) { return :calm; }

        if (petType == TYPE_FLAMEY && hunger > 75 && happiness < 25) { return :rage; }
        if (petType == TYPE_FLAMEY && happiness > 70 && energy > 80) { return :sugar_high; }
        if (petType == TYPE_AQUA && happiness > 85 && hunger < 30 && health > 60) { return :love; }
        if (petType == TYPE_AQUA && happiness < 15 && energy < 25) { return :existential; }
        if (petType == TYPE_ROCKY && hunger > 85 && energy < 15) { return :feral; }
        if (petType == TYPE_ROCKY && happiness > 80 && energy > 60) { return :party; }
        if (petType == TYPE_GHOSTY && health < 40 && isSick) { return :paranoid; }
        if (petType == TYPE_GHOSTY && happiness < 15 && energy < 25) { return :existential; }
        if (petType == TYPE_SPARKY && happiness > 70 && energy > 75) { return :sugar_high; }
        if (petType == TYPE_SPARKY && happiness > 75 && energy > 60) { return :party; }
        if (petType == TYPE_FROSTY && happiness > 88 && hunger < 25 && health > 70) { return :love; }
        if (petType == TYPE_FROSTY && hunger > 80 && happiness < 20) { return :rage; }
        if (petType == TYPE_SHROOMY && happiness > 72 && energy > 55) { return :party; }
        if (petType == TYPE_SHROOMY && happiness > 75 && energy > 80) { return :sugar_high; }
        if (petType == TYPE_BLOBBY && happiness < 18 && energy < 25) { return :existential; }
        if (petType == TYPE_BLOBBY && happiness > 90 && hunger < 25) { return :love; }
        if (petType == TYPE_EMILKA && happiness > 78 && hunger < 35 && health > 50) { return :love; }
        if (petType == TYPE_EMILKA && getNeglectLevel() >= 2 && happiness < 50) { return :rage; }
        if (petType == TYPE_EMILKA && happiness < 20 && energy < 30) { return :existential; }
        if (petType == TYPE_EMILKA && happiness > 75 && energy > 65) { return :party; }
        if (petType == TYPE_VEXOR && happiness < 40 && hunger > 50) { return :rage; }
        if (petType == TYPE_VEXOR && hunger > 70 && energy < 30) { return :feral; }
        if (petType == TYPE_VEXOR && happiness > 80 && energy > 60) { return :sugar_high; }
        if (petType == TYPE_VEXOR && happiness < 20 && health < 40) { return :paranoid; }
        if (petType == TYPE_VEXOR && happiness > 70 && energy > 70) { return :party; }
        if (petType == TYPE_CHIKKO && happiness < 30) { return :paranoid; }
        if (petType == TYPE_CHIKKO && hunger > 60 && energy < 40) { return :feral; }
        if (petType == TYPE_CHIKKO && happiness > 85 && energy > 70) { return :sugar_high; }
        if (petType == TYPE_CHIKKO && happiness < 15 && energy < 20) { return :existential; }
        if (petType == TYPE_CHIKKO && happiness > 75 && energy > 65) { return :party; }
        if (petType == TYPE_DZIKKO && happiness < 35 && hunger > 40) { return :rage; }
        if (petType == TYPE_DZIKKO && hunger > 55 && energy < 35) { return :feral; }
        if (petType == TYPE_DZIKKO && happiness > 85 && energy > 75) { return :party; }
        if (petType == TYPE_DZIKKO && health < 45 && isSick) { return :rage; }
        if (petType == TYPE_DZIKKO && happiness < 15 && energy < 25) { return :existential; }
        if (petType == TYPE_POLACCO && happiness < 35 && hunger > 50) { return :rage; }
        if (petType == TYPE_POLACCO && happiness > 75 && energy > 60) { return :party; }
        if (petType == TYPE_POLACCO && happiness < 20 && energy < 30) { return :existential; }
        if (petType == TYPE_NOSACZ && happiness < 30 && health > 50) { return :paranoid; }
        if (petType == TYPE_NOSACZ && happiness > 80 && hunger < 30) { return :love; }
        if (petType == TYPE_NOSACZ && happiness < 15 && energy < 25) { return :existential; }
        if (petType == TYPE_DONUT && happiness > 60 && energy > 50) { return :sugar_high; }
        if (petType == TYPE_DONUT && happiness < 25) { return :paranoid; }
        if (petType == TYPE_DONUT && happiness > 85 && hunger < 30) { return :love; }
        if (petType == TYPE_DONUT && happiness > 80 && energy > 70) { return :party; }
        if (petType == TYPE_CACTUSO && happiness < 10 && energy < 15) { return :existential; }
        if (petType == TYPE_PIXELBOT && happiness > 85 && energy > 80) { return :sugar_high; }
        if (petType == TYPE_PIXELBOT && happiness < 20 && health < 40) { return :paranoid; }
        if (petType == TYPE_OCTAVIO && happiness > 60 && energy > 70) { return :sugar_high; }
        if (petType == TYPE_OCTAVIO && happiness > 70 && energy > 60) { return :party; }
        if (petType == TYPE_OCTAVIO && hunger > 70 && energy < 30) { return :feral; }
        if (petType == TYPE_BATSY && happiness < 30 && energy > 60) { return :paranoid; }
        if (petType == TYPE_BATSY && happiness > 80 && energy > 70) { return :party; }
        if (petType == TYPE_NUGGET && happiness < 30) { return :paranoid; }
        if (petType == TYPE_NUGGET && happiness < 15 && energy < 20) { return :existential; }
        if (petType == TYPE_NUGGET && happiness > 85 && hunger < 25) { return :love; }
        if (petType == TYPE_FOCZKA && happiness > 80 && hunger < 30) { return :love; }
        if (petType == TYPE_FOCZKA && happiness > 75 && energy > 65) { return :party; }
        if (petType == TYPE_FOCZKA && happiness < 20 && energy < 25) { return :existential; }
        if (petType == TYPE_RAINBOW && happiness > 70 && energy > 60) { return :sugar_high; }
        if (petType == TYPE_RAINBOW && happiness > 80 && hunger < 30) { return :love; }
        if (petType == TYPE_RAINBOW && happiness > 85 && energy > 70) { return :party; }
        if (petType == TYPE_RAINBOW && happiness < 15 && energy < 20) { return :existential; }
        if (petType == TYPE_DOGGO && happiness > 50) { return :party; }
        if (petType == TYPE_DOGGO && happiness > 80 && energy > 60) { return :sugar_high; }
        if (petType == TYPE_DOGGO && happiness > 85 && hunger < 30) { return :love; }
        if (petType == TYPE_DOGGO && hunger > 70 && happiness < 30) { return :feral; }
        if (petType == TYPE_UNDEAD) { return :existential; }

        if (hunger > 90 && happiness < 15) { return :rage; }
        if (hunger > 95 && energy < 10) { return :feral; }
        if (happiness > 95 && hunger < 20 && health > 80) { return :love; }
        if (happiness > 80 && energy > 90) { return :sugar_high; }
        if (happiness < 10 && energy < 20 && !isSick) { return :existential; }
        if (health < 30 && isSick) { return :paranoid; }
        if (happiness > 85 && energy > 70) { return :party; }
        return :calm;
    }

    function getAgeString() {
        var totalSec = Time.now().value() - _birthTime;
        var days = totalSec / 86400;
        var hours = (totalSec % 86400) / 3600;
        if (days >= 365) { return (days / 365) + "yr " + (days % 365) + "d"; }
        if (days > 0) { return days + "d " + hours + "h"; }
        return hours + "h";
    }

    function getDeathAgeString() {
        var totalSec = Time.now().value() - _birthTime;
        var days = totalSec / 86400;
        if (days >= 365) { return petName + " - " + (days / 365) + "yr " + (days % 365) + "d"; }
        if (days > 0) { return petName + " - " + days + " days"; }
        return petName + " - " + ((totalSec % 86400) / 3600) + " hours";
    }

    function getTypeName(t) {
        if (t == TYPE_BLOBBY) { return "Blobby"; }
        if (t == TYPE_FLAMEY) { return "Flamey"; }
        if (t == TYPE_AQUA) { return "Aqua"; }
        if (t == TYPE_ROCKY) { return "Rocky"; }
        if (t == TYPE_GHOSTY) { return "Ghosty"; }
        if (t == TYPE_SPARKY) { return "Sparky"; }
        if (t == TYPE_FROSTY) { return "Frosty"; }
        if (t == TYPE_SHROOMY) { return "Shroomy"; }
        if (t == TYPE_EMILKA) { return "Emilka"; }
        if (t == TYPE_VEXOR) { return "Vexor"; }
        if (t == TYPE_CHIKKO) { return "Chikko"; }
        if (t == TYPE_DZIKKO) { return "Dzikko"; }
        if (t == TYPE_POLACCO) { return "Janusz"; }
        if (t == TYPE_NOSACZ) { return "Nosacz"; }
        if (t == TYPE_DONUT) { return "Donut"; }
        if (t == TYPE_CACTUSO) { return "Cactuso"; }
        if (t == TYPE_PIXELBOT) { return "Pixelbot"; }
        if (t == TYPE_OCTAVIO) { return "Octavio"; }
        if (t == TYPE_BATSY) { return "Batsy"; }
        if (t == TYPE_NUGGET) { return "Nugget"; }
        if (t == TYPE_FOCZKA) { return "Foczka"; }
        if (t == TYPE_RAINBOW) { return "Rainbow"; }
        if (t == TYPE_DOGGO) { return "Doggo"; }
        if (t == TYPE_UNDEAD) { return "Undead"; }
        return "???";
    }

    function getTypeDesc(t) {
        if (t == TYPE_BLOBBY) { return "Balanced & cute"; }
        if (t == TYPE_FLAMEY) { return "Fiery & bold"; }
        if (t == TYPE_AQUA) { return "Calm & flowing"; }
        if (t == TYPE_ROCKY) { return "Tough & steady"; }
        if (t == TYPE_GHOSTY) { return "Ethereal & sly"; }
        if (t == TYPE_SPARKY) { return "Electric & bright"; }
        if (t == TYPE_FROSTY) { return "Cool & elegant"; }
        if (t == TYPE_SHROOMY) { return "Quirky & wise"; }
        if (t == TYPE_EMILKA) { return "Sensitive & loving"; }
        if (t == TYPE_VEXOR) { return "Pure evil & chaos"; }
        if (t == TYPE_CHIKKO) { return "Neurotic chicken"; }
        if (t == TYPE_DZIKKO) { return "Unhinged wild boar"; }
        if (t == TYPE_POLACCO) { return "Polski Janusz"; }
        if (t == TYPE_NOSACZ) { return "E E E! Duzy nos!"; }
        if (t == TYPE_DONUT) { return "Sweet & terrified"; }
        if (t == TYPE_CACTUSO) { return "Don't touch me"; }
        if (t == TYPE_PIXELBOT) { return "Logic over feels"; }
        if (t == TYPE_OCTAVIO) { return "8 arms of chaos"; }
        if (t == TYPE_BATSY) { return "Nocturnal weirdo"; }
        if (t == TYPE_NUGGET) { return "Existential snack"; }
        if (t == TYPE_FOCZKA) { return "Adorable flopper"; }
        if (t == TYPE_RAINBOW) { return "Pure sparkle joy"; }
        if (t == TYPE_DOGGO) { return "Loyal chaos puppy"; }
        if (t == TYPE_UNDEAD) { return "Cannot be killed"; }
        return "???";
    }

    function getTraitName(t) {
        if (t == TRAIT_GLUTTON) { return "Glutton"; }
        if (t == TRAIT_PICKY) { return "Picky"; }
        if (t == TRAIT_PLAYFUL) { return "Playful"; }
        if (t == TRAIT_LAZY) { return "Lazy"; }
        if (t == TRAIT_HARDY) { return "Hardy"; }
        if (t == TRAIT_FRAGILE) { return "Fragile"; }
        if (t == TRAIT_CHEERFUL) { return "Cheerful"; }
        if (t == TRAIT_GRUMPY) { return "Grumpy"; }
        if (t == TRAIT_HYPER) { return "Hyper"; }
        if (t == TRAIT_SLEEPY) { return "Sleepy"; }
        return "?";
    }

    function getTraitColor(t) {
        if (t == TRAIT_GLUTTON) { return 0xFF8A65; }
        if (t == TRAIT_PICKY) { return 0xCE93D8; }
        if (t == TRAIT_PLAYFUL) { return 0xFFD54F; }
        if (t == TRAIT_LAZY) { return 0x90A4AE; }
        if (t == TRAIT_HARDY) { return 0xA5D6A7; }
        if (t == TRAIT_FRAGILE) { return 0xEF9A9A; }
        if (t == TRAIT_CHEERFUL) { return 0xFFF176; }
        if (t == TRAIT_GRUMPY) { return 0x8D6E63; }
        if (t == TRAIT_HYPER) { return 0x00E5FF; }
        if (t == TRAIT_SLEEPY) { return 0x7986CB; }
        return 0xAAAAAA;
    }

    // ===== Rates =====

    hidden function getHungerRate() {
        var r = 600;
        if (hasTrait(TRAIT_GLUTTON)) { r = 400; }
        if (petType == TYPE_FLAMEY) { r = r * 4 / 5; }
        else if (petType == TYPE_SPARKY) { r = r * 4 / 5; }
        else if (petType == TYPE_AQUA) { r = r * 6 / 5; }
        else if (petType == TYPE_ROCKY) { r = r * 7 / 5; }
        else if (petType == TYPE_GHOSTY) { r = r * 6 / 5; }
        else if (petType == TYPE_FROSTY) { r = r * 11 / 10; }
        else if (petType == TYPE_EMILKA) { r = r; }
        else if (petType == TYPE_VEXOR) { r = r * 4 / 5; }
        else if (petType == TYPE_CHIKKO) { r = r * 4 / 5; }
        else if (petType == TYPE_DZIKKO) { r = r * 3 / 4; }
        else if (petType == TYPE_POLACCO) { r = r * 6 / 5; }
        else if (petType == TYPE_NOSACZ) { r = r; }
        else if (petType == TYPE_DONUT) { r = r * 4 / 5; }
        else if (petType == TYPE_CACTUSO) { r = r * 2; }
        else if (petType == TYPE_PIXELBOT) { r = r; }
        else if (petType == TYPE_OCTAVIO) { r = r * 3 / 4; }
        else if (petType == TYPE_BATSY) { r = r * 4 / 5; }
        else if (petType == TYPE_NUGGET) { r = r * 4 / 5; }
        else if (petType == TYPE_FOCZKA) { r = r; }
        else if (petType == TYPE_RAINBOW) { r = r * 6 / 5; }
        else if (petType == TYPE_DOGGO) { r = r * 3 / 4; }
        else if (petType == TYPE_UNDEAD) { r = r * 3; }
        if (isSick) { r = r * 2 / 3; }
        var nl = getNeglectLevel();
        if (nl >= 4) { r = r / 2; }
        else if (nl >= 3) { r = r * 3 / 5; }
        else if (nl >= 2) { r = r * 4 / 5; }
        return r;
    }

    hidden function getHappyRate() {
        var r = 360;
        if (hasTrait(TRAIT_PLAYFUL)) { r = 480; }
        if (hasTrait(TRAIT_CHEERFUL)) { r = 440; }
        if (hasTrait(TRAIT_GRUMPY)) { r = 250; }
        if (petType == TYPE_FLAMEY) { r = r * 4 / 5; }
        else if (petType == TYPE_GHOSTY) { r = r * 4 / 5; }
        else if (petType == TYPE_AQUA) { r = r * 6 / 5; }
        else if (petType == TYPE_FROSTY) { r = r * 5 / 4; }
        else if (petType == TYPE_ROCKY) { r = r * 6 / 5; }
        else if (petType == TYPE_SHROOMY) { r = r * (9 + (animFrame % 3)) / 10; }
        else if (petType == TYPE_EMILKA) { r = r * 2 / 3; }
        else if (petType == TYPE_VEXOR) { r = r * 3 / 2; }
        else if (petType == TYPE_CHIKKO) { r = r * 2 / 3; }
        else if (petType == TYPE_DZIKKO) { r = r * 6 / 5; }
        else if (petType == TYPE_POLACCO) { r = r * 2 / 3; }
        else if (petType == TYPE_NOSACZ) { r = r * 4 / 5; }
        else if (petType == TYPE_DONUT) { r = r * 3 / 2; }
        else if (petType == TYPE_CACTUSO) { r = r * 2; }
        else if (petType == TYPE_PIXELBOT) { r = r; }
        else if (petType == TYPE_OCTAVIO) { r = r * 4 / 5; }
        else if (petType == TYPE_BATSY) { r = r; }
        else if (petType == TYPE_NUGGET) { r = r * 2 / 3; }
        else if (petType == TYPE_FOCZKA) { r = r * 6 / 5; }
        else if (petType == TYPE_RAINBOW) { r = r * 3 / 2; }
        else if (petType == TYPE_DOGGO) { r = r * 3 / 4; }
        else if (petType == TYPE_UNDEAD) { r = r * 4; }
        if (petType == TYPE_UNDEAD) { return r; }
        if (isSick) { r = r * 3 / 4; }
        var nl = getNeglectLevel();
        if (nl >= 4) { r = r / 2; }
        else if (nl >= 3) { r = r * 3 / 5; }
        else if (nl >= 2) { r = r * 3 / 4; }
        else if (nl >= 1) { r = r * 9 / 10; }
        return r;
    }

    hidden function getEnergyRate() {
        var r = 480;
        if (hasTrait(TRAIT_LAZY)) { r = 320; }
        if (hasTrait(TRAIT_HYPER)) { r = 380; }
        if (hasTrait(TRAIT_SLEEPY)) { r = 380; }
        if (petType == TYPE_SPARKY) { r = r * 4 / 5; }
        else if (petType == TYPE_FLAMEY) { r = r * 4 / 5; }
        else if (petType == TYPE_FROSTY) { r = r * 4 / 5; }
        else if (petType == TYPE_ROCKY) { r = r * 7 / 5; }
        else if (petType == TYPE_AQUA) { r = r * 6 / 5; }
        else if (petType == TYPE_SHROOMY) { r = r * 11 / 10; }
        else if (petType == TYPE_EMILKA) { r = r * 9 / 10; }
        else if (petType == TYPE_VEXOR) { r = r * 3 / 4; }
        else if (petType == TYPE_CHIKKO) { r = r * 3 / 4; }
        else if (petType == TYPE_DZIKKO) { r = r * 4 / 5; }
        else if (petType == TYPE_POLACCO) { r = r * 7 / 5; }
        else if (petType == TYPE_NOSACZ) { r = r; }
        else if (petType == TYPE_DONUT) { r = r * 4 / 5; }
        else if (petType == TYPE_CACTUSO) { r = r * 3 / 2; }
        else if (petType == TYPE_PIXELBOT) { r = r; }
        else if (petType == TYPE_OCTAVIO) { r = r * 3 / 4; }
        else if (petType == TYPE_BATSY) { r = r; }
        else if (petType == TYPE_NUGGET) { r = r * 4 / 5; }
        else if (petType == TYPE_FOCZKA) { r = r * 6 / 5; }
        else if (petType == TYPE_RAINBOW) { r = r; }
        else if (petType == TYPE_DOGGO) { r = r * 3 / 4; }
        else if (petType == TYPE_UNDEAD) { r = r * 3; }
        if (isSick) { r = r * 2 / 3; }
        var nl = getNeglectLevel();
        if (nl >= 4) { r = r / 2; }
        else if (nl >= 3) { r = r * 3 / 5; }
        return r;
    }

    hidden function clamp() {
        if (hunger > 100) { hunger = 100; }
        if (hunger < 0) { hunger = 0; }
        if (happiness > 100) { happiness = 100; }
        if (happiness < 0) { happiness = 0; }
        if (energy > 100) { energy = 100; }
        if (energy < 0) { energy = 0; }
        if (health > 100) { health = 100; }
        if (health < 0) { health = 0; }
    }

    hidden function checkDeath() {
        if (petType == TYPE_UNDEAD) {
            if (health < 5) { health = 5; }
            isAlive = true; isSick = false;
            return;
        }
        if (health <= 0) { eventText = deathCause(:health); isAlive = false; save(); pendingVibe = 4; return; }
        if (hunger >= 100 && happiness <= 0 && energy <= 0) { eventText = deathCause(:starvation); isAlive = false; save(); pendingVibe = 4; return; }
    }

    hidden function checkAgeDeath() {
        if (!isAlive) { return; }
        if (petType == TYPE_UNDEAD) { return; }
        var days = getAgeDays();
        var stage = getAgeStage();
        var wellbeing = getWellbeing();
        var neglect = getNeglectLevel();
        var deathChance = 0;

        if (stage == 2 && days > 21) {
            deathChance += (days - 21) / 2;
            if (wellbeing < 25) { deathChance += 5; }
            if (isSick) { deathChance += 8; }
        }
        if (stage == 3) {
            deathChance += 3 + (days - 30);
            if (wellbeing < 40) { deathChance += 10; }
            if (wellbeing < 20) { deathChance += 15; }
            if (isSick) { deathChance += 15; }
            if (neglect >= 3) { deathChance += 8; }
        }

        if (happiness <= 3 && neglect >= 4) { deathChance += 12; }
        if (hugStress >= 90) { deathChance += 10; }
        if (careStreak >= 7) { deathChance -= 3; }
        if (careStreak >= 14) { deathChance -= 5; }
        if (hasTrait(TRAIT_HARDY)) { deathChance -= 3; }
        if (hasTrait(TRAIT_FRAGILE)) { deathChance += 3; }

        if (deathChance < 1) { deathChance = 0; }
        if (deathChance > 0 && Math.rand().abs() % 100 < deathChance) {
            var cause = :old_age;
            if (happiness <= 5 && neglect >= 3) { cause = :loneliness; }
            else if (hugStress >= 80) { cause = :heartbreak; }
            else if (isSick && health < 40) { cause = :sickness; }
            else if (wellbeing < 20) { cause = :neglect; }
            eventText = deathCause(cause);
            isAlive = false;
            save();
            pendingVibe = 4;
        }
    }

    hidden function deathCause(cause) {
        if (cause == :health) { return petName + " died..."; }
        if (cause == :starvation) { return petName + " starved..."; }
        if (cause == :loneliness) { return petName + " died of loneliness"; }
        if (cause == :heartbreak) { return petName + "'s heart broke"; }
        if (cause == :sickness) { return petName + " lost to sickness"; }
        if (cause == :neglect) { return petName + " faded away..."; }
        if (cause == :old_age) { return petName + " passed peacefully"; }
        return petName + " is gone...";
    }

    hidden function checkUrgentNeeds() {
        if (!isAlive) { return; }
        if (pendingVibe > 0) { return; }
        if (isSick) {
            eventText = petName + " needs medicine!";
            _eventTime = Time.now().value();
            pendingVibe = 2;
            suggestedAction = 3;
        } else if (hunger >= 85) {
            eventText = petName + " is starving!";
            _eventTime = Time.now().value();
            pendingVibe = 2;
            suggestedAction = 0;
        } else if (poopCount >= 3) {
            eventText = "So much poop...";
            _eventTime = Time.now().value();
            pendingVibe = 1;
            suggestedAction = 2;
        } else if (energy <= 10) {
            eventText = petName + " is exhausted!";
            _eventTime = Time.now().value();
            pendingVibe = 1;
            suggestedAction = 4;
        } else if (health <= 30 && !isSick) {
            eventText = petName + " is very weak!";
            _eventTime = Time.now().value();
            pendingVibe = 2;
            suggestedAction = 3;
        } else if (happiness < 40 && petType != TYPE_UNDEAD && petType != TYPE_CACTUSO) {
            var pt = getPlayRequestThought();
            if (pt != null) {
                eventText = pt;
                _eventTime = Time.now().value();
                pendingVibe = 1;
            }
        }
    }

    hidden function checkSickness() {
        if (petType == TYPE_UNDEAD) { isSick = false; return; }
        var chance = 10;
        if (hunger > 70) { chance += 15; }
        if (happiness < 30) { chance += 10; }
        if (energy < 20) { chance += 10; }
        if (poopCount > 3) { chance += 20; }
        if (hasTrait(TRAIT_HARDY)) { chance = chance / 3; }
        if (hasTrait(TRAIT_FRAGILE)) { chance += 25; }
        if (Math.rand().abs() % 100 < chance) {
            isSick = true;
            health = 70;
            _sickTime = Time.now().value();
            eventText = petName + " is sick!";
            _eventTime = _sickTime;
            pendingVibe = 3;
            suggestedAction = 3;
        }
    }

    hidden function checkBirthday(now) {
        var days = (now - _birthTime) / 86400;
        if (days > 0 && days % 7 == 0 && days != _lastBirthdayDay) {
            _lastBirthdayDay = days;
            happiness += 30;
            clamp();
            eventText = "Happy Birthday!";
            celebType = 2;
            pendingVibe = 2;
            _eventTime = now;
        }
    }

    // ===== Utility =====

    hidden function traitsIncompatible(t1, t2) {
        if ((t1 == TRAIT_GLUTTON && t2 == TRAIT_PICKY) || (t1 == TRAIT_PICKY && t2 == TRAIT_GLUTTON)) { return true; }
        if ((t1 == TRAIT_HARDY && t2 == TRAIT_FRAGILE) || (t1 == TRAIT_FRAGILE && t2 == TRAIT_HARDY)) { return true; }
        if ((t1 == TRAIT_HYPER && t2 == TRAIT_SLEEPY) || (t1 == TRAIT_SLEEPY && t2 == TRAIT_HYPER)) { return true; }
        if ((t1 == TRAIT_PLAYFUL && t2 == TRAIT_LAZY) || (t1 == TRAIT_LAZY && t2 == TRAIT_PLAYFUL)) { return true; }
        if ((t1 == TRAIT_CHEERFUL && t2 == TRAIT_GRUMPY) || (t1 == TRAIT_GRUMPY && t2 == TRAIT_CHEERFUL)) { return true; }
        return false;
    }

    hidden function isNightTime() {
        var hour = System.getClockTime().hour;
        return (hour >= 23 || hour < 7);
    }

    function getAgeStage() {
        var days = getAgeDays();
        if (days < 1) { return 0; }
        if (days < 7) { return 1; }
        if (days < 30) { return 2; }
        return 3;
    }

    function getAgeStageLabel() {
        var s = getAgeStage();
        if (s == 0) { return "Baby "; }
        if (s == 3) { return "Elder "; }
        return "";
    }

    hidden function updateCareStreak() {
        var today = getAgeDays();
        if (today == _lastCareDay) { return; }
        if (today == _lastCareDay + 1) {
            careStreak += 1;
            _eventTime = Time.now().value();
            if (careStreak == 3) { eventText = "3-day streak!"; happiness += 10; celebType = 1; pendingVibe = 2; }
            else if (careStreak == 7) { eventText = "WEEK STREAK!"; happiness += 15; energy += 10; celebType = 2; pendingVibe = 2; }
            else if (careStreak == 14) { eventText = "2-WEEK STREAK!!"; happiness += 20; energy += 15; health += 10; celebType = 2; pendingVibe = 2; }
            else if (careStreak == 30) { eventText = "MONTH STREAK!!!"; happiness += 30; energy += 20; health += 20; hunger -= 20; celebType = 2; pendingVibe = 2; }
        } else if (today > _lastCareDay + 1) {
            careStreak = 1;
        }
        _lastCareDay = today;
        clamp();
    }

    hidden function checkSickRecovery() {
        if (!isSick) { return; }
        var sickDur = Time.now().value() - _sickTime;
        if (sickDur > 7200) { return; }
        if (health < 60) { return; }
        var chance = 12;
        if (hasTrait(TRAIT_HARDY)) { chance = 35; }
        if (hasTrait(TRAIT_FRAGILE)) { chance = 3; }
        if (getAgeStage() == 0) { chance += 10; }
        if (getAgeStage() == 3) { chance -= 5; }
        if (Math.rand().abs() % 100 < chance) {
            isSick = false;
            _sickTime = 0;
            eventText = "Recovered naturally!";
            _eventTime = Time.now().value();
            pendingVibe = 2;
            celebType = 1;
        }
    }

    // ===== Events =====

    hidden function triggerEvent() {
        if (Math.rand().abs() % 10 == 0) { triggerRareEvent(); return; }
        if (Math.rand().abs() % 4 == 0) { triggerTypeEvent(); return; }
        if (Math.rand().abs() % 5 < 3) { triggerTraitEvent(); return; }
        triggerGenericEvent();
    }

    hidden function triggerGenericEvent() {
        var roll = Math.rand().abs() % 16;
        if (roll == 0) { eventText = "Found a treasure map!"; happiness += 20; energy += 10; }
        else if (roll == 1) { eventText = "Ghost sighting!"; happiness -= 15; pendingVibe = 1; }
        else if (roll == 2) { eventText = "Made a new friend!"; happiness += 25; }
        else if (roll == 3) {
            eventText = "Ate something weird...";
            if (!isSick) { isSick = true; health = 80; _sickTime = Time.now().value(); pendingVibe = 3; suggestedAction = 3; }
            else { eventText = "Still eating weird stuff."; health -= 5; }
        }
        else if (roll == 4) { eventText = "Won a staring contest!"; happiness += 15; energy += 5; }
        else if (roll == 5) { eventText = "Slipped dramatically!"; health -= 10; happiness -= 10; pendingVibe = 1; }
        else if (roll == 6) { eventText = "Secret snack stash found!"; hunger -= 25; happiness += 10; }
        else if (roll == 7) { eventText = "Epic power nap!"; energy += 25; }
        else if (roll == 8) { eventText = "Street dance win!"; happiness += 20; energy -= 10; }
        else if (roll == 9) { eventText = "Nightmare last night!"; happiness -= 15; energy -= 10; }
        else if (roll == 10) { eventText = "Food fell from sky!"; hunger -= 20; happiness += 15; }
        else if (roll == 11) { eventText = "Dark witch appeared!"; happiness -= 25; health -= 15; pendingVibe = 2; }
        else if (roll == 12) { eventText = "Butterfly befriended!"; happiness += 15; energy += 5; }
        else if (roll == 13) { eventText = "STEPPED ON LEGO!!"; health -= 15; happiness -= 20; pendingVibe = 1; }
        else if (roll == 14) { eventText = "Received nice letter!"; happiness += 20; energy += 5; }
        else { eventText = "Mysterious wind blew!"; happiness += 5; health += 5; energy += 5; }
        _eventTime = Time.now().value();
        clamp();
    }

    hidden function triggerTypeEvent() {
        var r = Math.rand().abs() % 4;
        pendingVibe = 1;
        if (petType == TYPE_POLACCO) {
            if (r == 0) { eventText = "Grillowanie!!"; hunger -= 25; happiness += 20; }
            else if (r == 1) { eventText = "Sasiad! K*rwa!"; happiness -= 25; pendingVibe = 2; }
            else if (r == 2) { eventText = "Wygrales w karty!"; happiness += 25; energy += 10; }
            else { eventText = "Piwo za darmo!!"; hunger -= 10; happiness += 30; }
        } else if (petType == TYPE_NOSACZ) {
            if (r == 0) { eventText = "E! Nieznany zapach!"; happiness += 20; hunger -= 10; }
            else if (r == 1) { eventText = "Nos nr 1 w konwencji!"; happiness += 30; celebType = 1; }
            else if (r == 2) { eventText = "E! Wielkie kichnieccie!"; happiness += 15; energy += 10; }
            else { eventText = "Nos wyczul skarb!"; hunger -= 20; happiness += 15; }
        } else if (petType == TYPE_DOGGO) {
            if (r == 0) { eventText = "SQUIRREL SPOTTED!!"; happiness += 30; energy += 20; hunger += 10; pendingVibe = 2; }
            else if (r == 1) { eventText = "BELLY RUBS!!"; happiness += 35; celebType = 1; }
            else if (r == 2) { eventText = "Found the BEST STICK!"; happiness += 20; energy += 15; }
            else { eventText = "ZOOMIES ACTIVATED!!"; energy -= 25; happiness += 30; pendingVibe = 2; }
        } else if (petType == TYPE_EMILKA) {
            if (r == 0) { eventText = "Love letter received!"; happiness += 35; hugStress -= 10; celebType = 1; }
            else if (r == 1) { eventText = "Ghosted by crush..."; happiness -= 30; pendingVibe = 2; }
            else if (r == 2) { eventText = "Hair flip = iconic!"; happiness += 20; }
            else { eventText = "Got NOTICED!"; happiness += 30; celebType = 1; }
        } else if (petType == TYPE_VEXOR) {
            if (r == 0) { eventText = "Broke something precious!"; happiness += 25; energy += 10; }
            else if (r == 1) { eventText = "Made someone CRY!"; happiness += 25; energy += 10; }
            else if (r == 2) { eventText = "Spread chaos today!"; happiness += 15; health -= 5; pendingVibe = 2; }
            else { eventText = "Enemies suffered!!"; happiness += 30; celebType = 1; pendingVibe = 2; }
        } else if (petType == TYPE_CHIKKO) {
            if (r == 0) { eventText = "ESCAPED PREDATOR!!"; happiness += 20; energy -= 25; pendingVibe = 3; }
            else if (r == 1) { eventText = "PANIC MOLT!"; energy -= 20; happiness -= 15; health -= 5; pendingVibe = 2; }
            else if (r == 2) { eventText = "Hidden seeds found!"; hunger -= 25; happiness += 10; }
            else { eventText = "New safe hiding spot!"; happiness += 20; energy += 10; }
        } else if (petType == TYPE_DZIKKO) {
            if (r == 0) { eventText = "*CHARGES WALL*"; health -= 10; happiness += 25; pendingVibe = 2; }
            else if (r == 1) { eventText = "TERRITORY CLAIMED!"; happiness += 25; energy += 10; }
            else if (r == 2) { eventText = "Found massive truffles!"; hunger -= 25; happiness += 20; }
            else { eventText = "HEADBUTT WIN!!"; happiness += 25; health -= 5; pendingVibe = 2; }
        } else if (petType == TYPE_FLAMEY) {
            if (r == 0) { eventText = "Accidentally set fire!"; happiness += 20; health -= 5; pendingVibe = 2; }
            else if (r == 1) { eventText = "Everything is fuel!"; hunger -= 15; happiness += 15; energy += 10; }
            else { eventText = "Sizzled with PURPOSE!"; happiness += 20; energy += 15; }
        } else if (petType == TYPE_AQUA) {
            if (r == 0) { eventText = "Rain dance worked!"; happiness += 25; energy += 15; celebType = 1; }
            else if (r == 1) { eventText = "Merged with the ocean!"; health += 20; happiness += 15; celebType = 1; }
            else { eventText = "Tidal wave of JOY!"; happiness += 20; energy += 15; }
        } else if (petType == TYPE_GHOSTY) {
            if (r == 0) { eventText = "Haunted someone good!"; happiness += 25; energy += 10; }
            else if (r == 1) { eventText = "Phase-walked through WALL!"; energy += 20; happiness += 20; }
            else { eventText = "Spooky dream!"; happiness -= 15; energy -= 10; pendingVibe = 1; }
        } else if (petType == TYPE_SHROOMY) {
            if (r == 0) { eventText = "SPORE TRIP!!"; happiness += 30; energy -= 15; celebType = 2; }
            else if (r == 1) { eventText = "Underground network vision!"; health += 10; happiness += 25; }
            else { eventText = "Reality dissolving~"; happiness += 15; energy += 10; celebType = 2; }
        } else if (petType == TYPE_SPARKY) {
            if (r == 0) { eventText = "OVERCHARGED!!"; energy += 30; happiness += 10; health -= 10; pendingVibe = 2; }
            else if (r == 1) { eventText = "Zapped something!"; happiness += 20; energy += 10; }
            else { eventText = "Static explosion!"; happiness -= 10; health -= 5; energy += 20; pendingVibe = 2; }
        } else if (petType == TYPE_FROSTY) {
            if (r == 0) { eventText = "Froze an enemy solid!"; happiness += 25; health += 5; }
            else if (r == 1) { eventText = "Ice palace visit!"; happiness += 20; energy += 15; celebType = 1; }
            else { eventText = "Inner blizzard!"; happiness -= 15; energy -= 10; health -= 5; pendingVibe = 1; }
        } else if (petType == TYPE_ROCKY) {
            if (r == 0) { eventText = "Triggered avalanche!"; happiness += 20; health += 10; }
            else if (r == 1) { eventText = "Geological patience wins!"; energy += 25; health += 15; }
            else { eventText = "Ancient mineral found!"; health += 20; happiness += 15; }
        } else if (petType == TYPE_BLOBBY) {
            if (r == 0) { eventText = "Absorbed an entire chair!"; hunger -= 20; happiness += 20; }
            else if (r == 1) { eventText = "SHAPESHIFTED!"; happiness += 25; celebType = 2; }
            else { eventText = "Briefly split in two!"; happiness += 20; energy -= 10; }
        } else if (petType == TYPE_PIXELBOT) {
            if (r == 0) { eventText = "CRITICAL SYSTEM UPDATE!"; health += 25; energy += 20; pendingVibe = 1; }
            else if (r == 1) { eventText = "BUFFER OVERFLOW!!"; happiness -= 20; energy += 25; pendingVibe = 2; }
            else { eventText = "NEW ALGORITHM LOADED!"; happiness += 25; health += 10; }
        } else if (petType == TYPE_OCTAVIO) {
            if (r == 0) { eventText = "8-arm multitask VICTORY!"; happiness += 25; energy -= 15; }
            else if (r == 1) { eventText = "INK EXPLOSION!"; happiness += 20; pendingVibe = 1; }
            else { eventText = "Tentacle tangle!"; happiness -= 10; energy -= 10; health += 5; }
        } else if (petType == TYPE_BATSY) {
            if (r == 0) { eventText = "Found a perfect cave!"; happiness += 25; energy += 20; }
            else if (r == 1) { eventText = "Echolocated treasure!"; hunger -= 10; happiness += 25; }
            else { eventText = "Touched the sun. OOPS!"; health -= 20; happiness -= 25; pendingVibe = 3; }
        } else if (petType == TYPE_NUGGET) {
            if (r == 0) { eventText = "DODGED THE SAUCE!!"; happiness += 25; energy += 15; pendingVibe = 2; }
            else if (r == 1) { eventText = "WHO PUT KETCHUP NEARBY?!"; happiness -= 25; pendingVibe = 3; }
            else { eventText = "Another day unchewed!"; health += 5; happiness += 15; }
        } else if (petType == TYPE_DONUT) {
            if (r == 0) { eventText = "EXTRA SPRINKLES!!"; happiness += 30; celebType = 1; }
            else if (r == 1) { eventText = "Someone tried to EAT ME!"; happiness -= 25; health -= 10; pendingVibe = 3; }
            else { eventText = "Fresh glaze applied!"; happiness += 20; health += 5; }
        } else if (petType == TYPE_CACTUSO) {
            if (r == 0) { eventText = "Perfect sunny day."; happiness += 15; health += 15; }
            else if (r == 1) { eventText = "Spiked intruder. Good."; happiness += 20; }
            else { eventText = "Bloomed. Once. It counted."; happiness += 25; celebType = 1; }
        } else if (petType == TYPE_FOCZKA) {
            if (r == 0) { eventText = "ARF! Caught huge fish!"; hunger -= 25; happiness += 25; celebType = 1; }
            else if (r == 1) { eventText = "PERFECT belly flop!!"; happiness += 25; energy -= 10; celebType = 1; }
            else { eventText = "Ball balanced on nose!!"; happiness += 30; celebType = 1; }
        } else if (petType == TYPE_UNDEAD) {
            if (r == 0) { eventText = "Tried to die. Failed."; happiness += 5; }
            else if (r == 1) { eventText = "Dropped a limb. Found it."; energy -= 5; happiness += 3; }
            else { eventText = "Eternal monday continues."; happiness -= 5; }
        } else {
            if (r == 0) { eventText = "DOUBLE RAINBOW!!"; happiness += 35; celebType = 2; }
            else if (r == 1) { eventText = "Glitter explosion!"; happiness += 25; energy += 10; }
            else { eventText = "Pure sparkle moment!"; happiness += 20; health += 5; celebType = 1; }
        }
        _eventTime = Time.now().value();
        clamp();
    }

    hidden function triggerTraitEvent() {
        var t = (Math.rand().abs() % 2 == 0) ? trait1 : trait2;
        var good = (Math.rand().abs() % 2 == 0);
        if (t == TRAIT_GLUTTON) {
            if (good) { eventText = "RAIDED THE FRIDGE!"; hunger -= 30; happiness += 10; }
            else { eventText = "Ate WAY too much!"; energy -= 15; health -= 5; }
        } else if (t == TRAIT_PICKY) {
            if (good) { eventText = "Found a DELICACY!"; hunger -= 20; happiness += 25; }
            else { eventText = "Everything is WRONG!"; happiness -= 15; energy -= 5; }
        } else if (t == TRAIT_PLAYFUL) {
            if (good) { eventText = "INVENTED BEST GAME!!"; happiness += 30; energy += 5; }
            else { eventText = "Played waaaay too hard!"; energy -= 25; health -= 5; }
        } else if (t == TRAIT_LAZY) {
            if (good) { eventText = "Surprise energy burst!"; energy += 30; happiness += 10; }
            else { eventText = "Completely immovable!"; happiness -= 15; energy -= 10; }
        } else if (t == TRAIT_HARDY) {
            if (good) { eventText = "Flexed HARD!"; health += 20; energy += 10; }
            else { eventText = "Overexerted badly!"; energy -= 20; health -= 10; }
        } else if (t == TRAIT_FRAGILE) {
            if (good) { eventText = "Extra tender care!"; happiness += 20; health += 10; }
            else { eventText = "Catastrophic paper cut!"; health -= 15; happiness -= 10; pendingVibe = 1; }
        } else if (t == TRAIT_CHEERFUL) {
            if (good) { eventText = "Spread JOY EVERYWHERE!"; happiness += 25; energy += 5; }
            else { eventText = "TOO enthusiastic!!"; energy -= 15; health -= 5; }
        } else if (t == TRAIT_GRUMPY) {
            if (good) { eventText = "Smiled. Wait, no."; happiness += 8; }
            else { eventText = "KICKED A ROCK. Hard."; happiness -= 15; health -= 5; pendingVibe = 1; }
        } else if (t == TRAIT_HYPER) {
            if (good) { eventText = "SPEED BURST!!"; energy += 20; happiness += 20; }
            else { eventText = "CRASHED HARD!!"; energy -= 30; health -= 10; pendingVibe = 1; }
        } else {
            if (good) { eventText = "DREAM POWER SURGE!"; energy += 35; health += 5; }
            else { eventText = "Sleepwalked into wall!"; happiness -= 15; health -= 10; pendingVibe = 1; }
        }
        _eventTime = Time.now().value();
        clamp();
    }

    hidden function triggerRareEvent() {
        pendingVibe = 2;
        var roll = Math.rand().abs() % 14;
        if (roll == 0) {
            eventText = "GOLDEN FEAST!!";
            hunger = 0; happiness += 40; energy += 20; celebType = 2;
            eventFlashType = 1;
        } else if (roll == 1) {
            eventText = "GUARDIAN ANGEL!!";
            health = 100; isSick = false; _sickTime = 0; hugStress = 0; celebType = 2; pendingVibe = 3;
            eventFlashType = 2;
        } else if (roll == 2) {
            eventText = "ALIEN ABDUCTION!?";
            happiness += 50; energy += 30; celebType = 2; pendingVibe = 3;
            eventFlashType = 4;
        } else if (roll == 3) {
            eventText = "DOUBLE RAINBOW!!";
            happiness += 35; energy += 25; health += 20; celebType = 2;
            eventFlashType = 6;
        } else if (roll == 4) {
            eventText = "TIME WARP!!";
            hunger -= 40; happiness += 40; energy += 40; celebType = 2;
            eventFlashType = 6;
        } else if (roll == 5) {
            eventText = "MASSIVE EARTHQUAKE!!";
            happiness -= 40; energy -= 30; health -= 25; pendingVibe = 4;
            eventFlashType = 3;
        } else if (roll == 6) {
            eventText = "LEGENDARY TREASURE!!";
            hunger -= 25; happiness += 30; energy += 30; health += 30; celebType = 2;
            eventFlashType = 1;
        } else if (roll == 7) {
            eventText = "LEGENDARY POTION!!";
            var r2 = Math.rand().abs() % 4;
            if (r2 == 0) { hunger = 0; happiness += 20; }
            else if (r2 == 1) { happiness = 100; }
            else if (r2 == 2) { energy = 100; health += 20; }
            else { health = 100; isSick = false; _sickTime = 0; }
            celebType = 2;
            eventFlashType = 2;
        } else if (roll == 8) {
            eventText = "METEOR SHOWER!!";
            happiness -= 35; energy -= 25; health -= 30; pendingVibe = 4;
            eventFlashType = 3;
        } else if (roll == 9) {
            eventText = "ANCIENT CURSE!!";
            hugStress += 40; happiness -= 30; health -= 25; pendingVibe = 3;
            eventFlashType = 5;
        } else if (roll == 10) {
            eventText = "PET GOD VISITS!!";
            hunger = 0; happiness = 100; energy = 100; health = 100;
            isSick = false; _sickTime = 0; hugStress = 0;
            celebType = 2; pendingVibe = 3;
            eventFlashType = 2;
        } else if (roll == 11) {
            eventText = "BLACK HOLE NEARBY!!";
            happiness = happiness / 2; energy = energy / 2; health = health / 2; pendingVibe = 3;
            eventFlashType = 5;
        } else if (roll == 12) {
            eventText = "LOTTERY WIN!!!";
            happiness = 100; hunger = 0; energy += 30; celebType = 2; pendingVibe = 3;
            eventFlashType = 1;
        } else {
            eventText = "IDENTITY CRISIS!!";
            var temp = happiness;
            happiness = energy;
            energy = health;
            health = temp;
            pendingVibe = 2;
            eventFlashType = 7;
        }
        _eventTime = Time.now().value();
        clamp();
    }

    // ===== Thoughts =====

    hidden function getThought() {
        var mood = getMoodState();
        if (mood != :calm && Math.rand().abs() % 5 < 4) {
            var mt = getMoodThought();
            if (mt != null) { return mt; }
        }

        if (isNightTime() && Math.rand().abs() % 3 == 0) {
            if (petType == TYPE_BATSY) {
                var bt = ["*peak hours*", "Finally! Night!", "The dark is ALIVE!", "*echolocates joyfully*", "This is my time.", "Darkness = home~"];
                return bt[Math.rand().abs() % bt.size()];
            }
            if (petType == TYPE_UNDEAD) {
                var ut = ["Night means nothing.", "Dark. As always.", "*shuffles at 3am*", "Sleep is for living."];
                return ut[Math.rand().abs() % ut.size()];
            }
            if (petType == TYPE_POLACCO) {
                var pt = ["Spac pora k*rwa", "Noc, piwo, relaks", "*chrapie*", "Dobranoc k*rwa"];
                return pt[Math.rand().abs() % pt.size()];
            }
            if (petType == TYPE_DOGGO) {
                var dt = ["*snores loudly*", "Dreaming of balls~", "*kicks in sleep*", "ZzZz walkies ZzZz"];
                return dt[Math.rand().abs() % dt.size()];
            }
            var nt = ["*snoring*", "Zzz...", "Good night~", "*dreaming*", "So sleepy...", "*peaceful*", "Lights out~", "*curls up*", "Nighty night~", "Dreaming of better stats.", "*sleep twitches*", "Tomorrow will be better... maybe."];
            return nt[Math.rand().abs() % nt.size()];
        }

        if (isSick && _sickTime > 0) {
            var sickDur = Time.now().value() - _sickTime;
            if (sickDur > 14400 && Math.rand().abs() % 2 == 0) {
                if (petType == TYPE_POLACCO) { var t = ["Umre przez ta chorobe k*rwa", "Juz po mnie", "Doktor by sie przydal", "Koniec ch*j"]; return t[Math.rand().abs() % t.size()]; }
                if (petType == TYPE_NOSACZ) { var t = ["E... koniec. E.", "*nos blady*", "EEE... choroooba...", "E... help E."]; return t[Math.rand().abs() % t.size()]; }
                if (petType == TYPE_VEXOR) { return "I'm sick AND furious. Peak suffering."; }
                var st = ["I'm getting worse!", "HELP ME PLEASE!", "Cure me...", "I might die...", "Please... meds...", "*barely moving*", "This is the end, maybe.", "Why won't it stop?!"];
                return st[Math.rand().abs() % st.size()];
            }
            if (sickDur > 7200 && Math.rand().abs() % 3 == 0) {
                if (petType == TYPE_POLACCO) { var t = ["Zle sie czuje k*rwa", "Daj leki k*rwa!", "Choroba to nie przelewki"]; return t[Math.rand().abs() % t.size()]; }
                if (petType == TYPE_NOSACZ) { var t = ["E chory E", "*nos smaruje*", "Nos choruje. E."]; return t[Math.rand().abs() % t.size()]; }
                if (petType == TYPE_DOGGO) { var t = ["*sneezes sadly*", "No energy for ball...", "Sick doggo...", "*slow tail wag*"]; return t[Math.rand().abs() % t.size()]; }
                var st = ["Need medicine!", "Still sick...", "Getting bad!", "Please heal me!", "*coughs sadly*", "Day 2 of being sick...", "When does this end?!", "Heal me pls~"];
                return st[Math.rand().abs() % st.size()];
            }
        }

        if (careStreak >= 7 && Math.rand().abs() % 8 == 0) {
            return "Streak: " + careStreak + " days!";
        }

        var nl = getNeglectLevel();
        if (nl >= 1) {
            var nt = getNeglectThought(nl);
            if (nt != null) { return nt; }
        }

        if (Math.rand().abs() % 12 == 0) {
            var pt = getPlayRequestThought();
            if (pt != null) { return pt; }
        }

        if (Math.rand().abs() % 18 == 0) {
            var wt = getWaterThought();
            if (wt != null) { return wt; }
        }

        if (Math.rand().abs() % 10 == 0) {
            var st = getStepThought();
            if (st != null) { return st; }
        }
        var roll = Math.rand().abs() % 10;
        if (roll < 3) { return getTraitThought(); }
        if (roll < 5) { return getTypeThought(); }
        var t;
        if (poopCount > 2) {
            if (petType == TYPE_POLACCO) { t = ["Nasr*ne wszedzie!", "Posprzataj k*rwa!", "Cuchnie ja pierdole", "Co to za smrod k*rwa", "Smierdzace to tu", "Sanitarny koszmar!"]; }
            else if (petType == TYPE_NOSACZ) { t = ["E! Smrod! E!", "*nos obraca sie*", "E E kupka E", "Zly zapach. E."]; }
            else if (petType == TYPE_PIXELBOT) { t = ["HYGIENE: critical", "CLEAN.EXE required", "Biohazard detected.", "Sanitize immediately."]; }
            else if (petType == TYPE_VEXOR) { t = ["Clean this sh*t literally", "Disgusting. Fix it.", "*rages at smell*", "I LIVE IN FILTH?!"]; }
            else { t = ["Clean pls!", "Eww!", "Stinky...", "Gross...", "I live in filth!", "Send help", "The smell IS my life now.", "Biohazard situation.", "Please. I beg you.", "*covers nose*", "I have lost dignity.", "Poop count: excessive."]; }
        }
        else if (isSick) {
            if (petType == TYPE_POLACCO) { t = ["Zle sie czuje k*rwa", "Chyba zdychm...", "Daj leki ch*ju", "Boli mnie wszystko", "Umre przez ten styl zycia", "Choroba k*rwa"]; }
            else if (petType == TYPE_NOSACZ) { t = ["E... chory. E.", "*nos kicha*", "E! Bol! E!", "Nos choruje E."]; }
            else if (petType == TYPE_PIXELBOT) { t = ["HEALTH: degrading", "Virus detected?", "System failure risk.", "Repair needed ASAP."]; }
            else if (petType == TYPE_VEXOR) { t = ["Sick and FURIOUS.", "Illness makes me WORSE.", "*coughs angrily*", "Heal me. NOW."]; }
            else if (petType == TYPE_DOGGO) { t = ["*sad cough*", "No zoomies today...", "Feel icky...", "*lies down slowly*"]; }
            else { t = ["Ugh...", "*cough*", "Help me...", "Feel bad", "Am I dying?", "Need meds...", "*wheeze*", "My health is a scam.", "Can't get up...", "Fever dreams...", "*sneezes dramatically*", "The sickness grows.", "Everything hurts EVERYWHERE."]; }
        }
        else if (hunger > 70) {
            if (petType == TYPE_POLACCO) { t = ["ZERAC DAJ!", "Glodny jak ch*j!", "KIELBASA!", "Brzuch burczy k*rwa", "Pozre kogokolwiek!", "Gdzie ta kielbasa!", "Jestem w stanie zerac sciany!"]; }
            else if (petType == TYPE_NOSACZ) { t = ["E! Jesc! E!", "Glod. E.", "E E jedzenie E!", "*nos wącha jedzenie*"]; }
            else if (petType == TYPE_DOGGO) { t = ["FOOD?! FOOD?! FOOD?!", "*dramatic starving act*", "I can smell EVERYTHING.", "Feed or I eat the sofa."]; }
            else if (petType == TYPE_VEXOR) { t = ["FEED ME OR SUFFER.", "Starvation makes me WORSE.", "I'll eat your SOUL.", "Food. NOW. SERIOUSLY."]; }
            else if (petType == TYPE_EMILKA) { t = ["Feed me... please?", "Hunger + loneliness = tears", "My tummy is angry~", "Even food would show me love..."]; }
            else { t = ["Feed me!", "Hungry...", "*rumble*", "Food?", "I could eat a HORSE", "STARVING!", "*tummy growl*", "My stomach is plotting.", "Hunger level: feral.", "I'll eat literally anything.", "*eats air*", "FOOD IS ALL I THINK ABOUT", "Is that food? THAT'S FOOD.", "Feed or consequences."]; }
        }
        else if (happiness < 30) {
            if (petType == TYPE_POLACCO) { t = ["Jebac to...", "Nudno tu k*rwa", "Ch*j z tym", "Depresja...", "Wszystko bez sensu", "Polska przygnebila mnie", "Zyciem nie jest, jest wegetowaniem"]; }
            else if (petType == TYPE_NOSACZ) { t = ["E... smutno. E.", "*nos zwiesa sie*", "E...", "Brak radosci. E."]; }
            else if (petType == TYPE_EMILKA) { t = ["Nobody loves me...", "*dramatically lies on floor*", "Life is unfair and LONG.", "Why won't anyone notice me?"]; }
            else if (petType == TYPE_VEXOR) { t = ["Boredom fuels my rage.", "Entertain me or DIE.", "*destroys something out of boredom*", "I hate this. I hate all."]; }
            else if (petType == TYPE_DOGGO) { t = ["*sad puppy eyes*", "No one to play with...", "Is anyone there?", "*whimpers quietly*"]; }
            else { t = ["*sigh*", "Bored...", "Play?", "Lonely", "Life is pain", "Everything sucks", "Meh...", "Nothing matters.", "I stare. Void stares back.", "Is this it?", "Stimulate me pls.", "Boredom is suffering.", "*counts pixels*", "Someone. Anyone. Please."]; }
        }
        else if (energy < 20) {
            if (petType == TYPE_POLACCO) { t = ["Padne zaraz...", "Drzemka kurwa...", "*ziewa*", "Wykoncz*ny", "Nogi nie dzialaja", "Dajcie spokoj k*rwa", "Spac!"]; }
            else if (petType == TYPE_NOSACZ) { t = ["E... senny. E.", "*nos opada*", "Spac E.", "E... zmeczenie E."]; }
            else if (petType == TYPE_DOGGO) { t = ["*slow tail wag*", "Tired but still love you...", "*collapses softly*", "Nap... then walkies?"]; }
            else if (petType == TYPE_VEXOR) { t = ["Tired AND angry. Peak me.", "Energy low. Rage stays.", "Sleep is weakness. Yet.", "*angrily lies down*"]; }
            else { t = ["Sleepy...", "*yawn*", "Tired...", "Nap?", "Can't...move...", "5 more minutes", "Zzz...", "Battery at 3%.", "Legs? What legs.", "Everything is effort.", "*falls asleep mid-thought*", "Napping is self-care.", "Too tired to be tired.", "*boneless*"]; }
        }
        else if (happiness > 70) {
            if (petType == TYPE_POLACCO) { t = ["Niezle k*rwa!", "Zycie jest piekne!", "Dobre jest!", "*usmiech*", "Piwo smakuje!", "Kielbaska, zimne, dobre!", "Och, jest ok."]; }
            else if (petType == TYPE_NOSACZ) { t = ["E!! Dobrze! E!!", "*nos tanczy*", "E E szczescie E!", "Nos szczesliwy!"]; }
            else if (petType == TYPE_DOGGO) { t = ["BEST DAY EVER!!", "*spins from joy*", "I love EVERYTHING!", "THIS IS PERFECT!!"]; }
            else if (petType == TYPE_EMILKA) { t = ["Life is BEAUTIFUL!", "*twirls*", "I feel SO loved!", "Today is my day~"]; }
            else if (petType == TYPE_VEXOR) { t = ["...tolerable.", "Acceptable.", "I feel... less bad.", "Don't tell anyone."]; }
            else { t = ["Yay!", "Happy!", "Love you!", "Wheee!", "Best day!", "Life is GREAT!", "So blessed~", "Today is PERFECT.", "Nothing can stop me!", "HAPPINESS OVERLOAD", "Pure serotonin.", "*does a little dance*", "10/10 existence.", "I feel invincible~"]; }
        }
        else {
            if (petType == TYPE_POLACCO) { t = ["No...", "*beka*", "Eh...", "Hm", "Co jest?", "Leci cos?", "Nuda...", "Zycie plynie k*rwa", "Siedze tu.", "No i co?", "*drapie sie*"]; }
            else if (petType == TYPE_NOSACZ) { t = ["E.", "*wącha*", "E E.", "Nos.", "Siede.", "E?", "*oblizuje*", "E E E.", "Nos mysli."]; }
            else if (petType == TYPE_PIXELBOT) { t = ["Idle.", "Standby.", "No input.", "Processing...", "Status: nominal.", "...waiting."]; }
            else if (petType == TYPE_UNDEAD) { t = ["...", "*exists*", "Still.", "Cold.", "Forever.", "*stares*", "Eternal.", "Nothing changes."]; }
            else if (petType == TYPE_DOGGO) { t = ["*tail wag*", "Hi!!", "Bork~", "*sniffs*", "Good.", "Hehe.", "*licks screen*"]; }
            else if (petType == TYPE_EMILKA) { t = ["Heyyy~", "*checks phone*", "Am I cute?", "Thinking of you~", "La la la~", "*hair flip*"]; }
            else { t = ["Hmm...", "La la~", "Hi!", "Boop!", "...", "Hehe", "Vibing~", "*exists*", "Sup?", "Thinking... nothing.", "Just being.", "Tuesday energy.", "*stares at nothing*", "No thoughts. Head empty.", "Living mediocre best life."]; }
        }
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getPlayRequestThought() {
        if (happiness > 65 && Math.rand().abs() % 3 != 0) { return null; }
        if (petType == TYPE_UNDEAD)   { return null; }
        if (petType == TYPE_CACTUSO)  { return null; }
        if (petType == TYPE_PIXELBOT) {
            var t = ["QUERY: Play protocol?", "BOREDOM.EXE detected", "INPUT: Play required", "IDLE: Request minigame"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_EMILKA) {
            var t = ["Play with me?? Please?", "Pogramy? *puppy eyes*", "Chcesz sie pobawic?", "I'm SO bored..."];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_VEXOR) {
            var t = ["Entertain me. NOW.", "Play or I riot.", "PLAY. GAME. NOW.", "*taps foot impatiently*"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_DOGGO) {
            var t = ["PLAY?! PLEASE PLAY!", "*brings ball!*", "GAME! GAME! GAME!", "*spins excitedly*", "THROW THE BALL!!!"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_POLACCO) {
            var t = ["No co, nie pogramy?", "Nudno k*rwa, gra?", "Zagrajmy w cos ch*j", "Ej, gra, no!"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_NOSACZ) {
            var t = ["E? Bawic sie? E?", "E! Gra! E! E!", "*nos drga z podekscytowania*", "E E gra E E!"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_CHIKKO) {
            var t = ["BAWK! Play?? BAWK!", "*pecks your finger*", "GAME! CLUCK!", "*flaps wings*"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_FLAMEY) {
            var t = ["Let's BURN some time!", "Game? *fire crackle*", "Play or I explode!", "Bored... *sparks*"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_AQUA) {
            var t = ["Wanna splash around?", "Play? *ripple*", "Let's flow together~", "Games are calming~"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_FOCZKA) {
            var t = ["*arf arf!* PLAY?!", "Ball? Pleeease!", "*claps flippers*", "ARF! Game time!"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_ROCKY) {
            var t = ["Rock... wants to play.", "Wrestling match?", "Crush... some games."];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_GHOSTY) {
            var t = ["Boo! Play with me~", "Haunt a game together?", "*floats hopefully*", "Spooky games?"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_RAINBOW) {
            var t = ["Rainbow games! *sparkle*", "Play in color?!", "*glitter request*", "Let's shine together!"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_SHROOMY) {
            var t = ["*shakes spores* play?", "Trippy games?", "Fungal fun time~", "Spore-tacular game?"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_DONUT) {
            var t = ["Games > being eaten!", "Play? Don't eat me!", "*sprinkles excitement*", "Donut wanna sit still!"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_NUGGET) {
            var t = ["Play? I'm still here!", "Crispy fun time?", "Don't eat, just play!", "*nugget hops*"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_OCTAVIO) {
            var t = ["8 arms ready to play!", "Games? *tentacle wave*", "Ink-redible game time!", "Let's play, friend~"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_BATSY) {
            var t = ["Night games?~", "*echolocation ping*", "Dark room game?", "*hangs & requests*"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_DZIKKO) {
            var t = ["OINK! GAME! OINK!", "*charges at game*", "Play or be rammed!", "BOAR GAME TIME!"];
            suggestedAction = 1;
            return t[Math.rand().abs() % t.size()];
        }
        var t = ["Play with me?", "Game time?", "Let's play!", "Wanna play?", "Play pleeease!", "I'm bored..."];
        suggestedAction = 1;
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getWaterThought() {
        if (petType == TYPE_AQUA) {
            var t = ["Drink water, human!", "H2O time~", "Stay hydrated!", "*splashes reminder*", "Water is life~"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_FROSTY) {
            var t = ["Ice water?", "Stay hydrated, ok?", "Cold water is best.", "Drink something!"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_DONUT) {
            var t = ["Water goes with donuts!", "Drink water pls!", "Stay hydrated!", "H2O or glaze?"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_FOCZKA) {
            var t = ["*ARF* Drink water!", "Water! Like me! ARF!", "Splash splash, drink!"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_EMILKA) {
            var t = ["Pij wode, kochanie!", "Napilas/es sie dzis?", "Zdrowie, pij wode!", "Water = happy skin!"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_PIXELBOT) {
            var t = ["HYDRATION: LOW", "DRINK.EXE required", "H2O deficit detected", "WATER: recommended"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_NOSACZ) {
            var t = ["E... woda? E?", "Woda dobra. E.", "E E pij wode E", "*nos wskazuje na wode*"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_DOGGO) {
            var t = ["WATER!! DRINK IT!!", "*laps water loudly*", "Drink with me!!!", "BORK! Water time!"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_SHROOMY) {
            var t = ["Fungi need water~", "Drink water, grow~", "*absorbs moisture*", "Hydration = mycelium"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_RAINBOW) {
            var t = ["Water makes rainbows!", "*water sparkle*", "Drink! Rainbows need it!", "H2O = colors!"];
            return t[Math.rand().abs() % t.size()];
        }
        if (petType == TYPE_POLACCO) {
            return null;
        }
        if (petType == TYPE_VEXOR) {
            return null;
        }
        if (petType == TYPE_UNDEAD) {
            return null;
        }
        if (Math.rand().abs() % 3 != 0) { return null; }
        var t = ["Drink water!", "Stay hydrated~", "Water time!", "H2O check!"];
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getNeglectThought(nl) {
        if (petType == TYPE_POLACCO) {
            if (nl >= 4) { var t = ["Jebac, sam sobie dam rade", "No i ch*j z toba", "Spierdal*les co?", "K*rwa, sam jak palec"]; return t[Math.rand().abs() % t.size()]; }
            if (nl >= 3 && Math.rand().abs() % 4 < 3) { var t = ["Gdzie ty lazisz?", "Piwo stygnie k*rwa", "No wroc juz ch*ju", "Sam nic nie zrobie"]; return t[Math.rand().abs() % t.size()]; }
            if (nl >= 2 && Math.rand().abs() % 3 < 2) { var t = ["Ej, jestes tam?", "Nudzi mi sie k*rwa", "Daj piwko chociaz", "Eh..."]; return t[Math.rand().abs() % t.size()]; }
            if (Math.rand().abs() % 3 == 0) { var t = ["Halo?", "Ej...", "No co tam?", "Pusto tu"]; return t[Math.rand().abs() % t.size()]; }
            return null;
        }
        if (petType == TYPE_EMILKA) {
            if (nl >= 4) { var t = ["ZOSTAWILES MNIE!", "NIENAWIDZE CIE!", "*placz*", "Umieram z tesknoty!"]; return t[Math.rand().abs() % t.size()]; }
            if (nl >= 3 && Math.rand().abs() % 4 < 3) { var t = ["Pewnie z INNA jestes!", "Dlaczego mnie nie kochasz?!", "Jestes OKRUTNY!", "Wroc natychmiast!"]; return t[Math.rand().abs() % t.size()]; }
            if (nl >= 2 && Math.rand().abs() % 3 < 2) { var t = ["Tesknie za Toba...", "Czemu mnie zostawiles?", "Kocham Cie, wroc!", "Czekam na Ciebie..."]; return t[Math.rand().abs() % t.size()]; }
            return null;
        }
        if (petType == TYPE_NUGGET) {
            if (nl >= 4) { var t = ["Am I expired?", "Cold nugget...", "No dipping sauce...", "Forgotten food..."]; return t[Math.rand().abs() % t.size()]; }
            if (nl >= 3 && Math.rand().abs() % 4 < 3) { var t = ["Going stale...", "Left on counter...", "Nobody wants me", "Soggy..."]; return t[Math.rand().abs() % t.size()]; }
            return null;
        }
        if (petType == TYPE_CACTUSO) {
            if (nl >= 4) { return "...fine. Alone. As always."; }
            return null;
        }
        if (petType == TYPE_FOCZKA) {
            if (nl >= 4) { var t = ["*sad arf...*", "*lies flat*", "No belly rubs...", "*lonely bark*"]; return t[Math.rand().abs() % t.size()]; }
            if (nl >= 3 && Math.rand().abs() % 4 < 3) { var t = ["*whimper*", "Come swim...", "*waits by shore*"]; return t[Math.rand().abs() % t.size()]; }
            return null;
        }
        if (petType == TYPE_DOGGO) {
            if (nl >= 4) { var t = ["*howls*", "WHY DID YOU LEAVE?!", "*paws at door*", "*sad eyes*"]; return t[Math.rand().abs() % t.size()]; }
            if (nl >= 3 && Math.rand().abs() % 4 < 3) { var t = ["*whines*", "No walkies...", "*stares at leash*", "Where did u go?"]; return t[Math.rand().abs() % t.size()]; }
            if (nl >= 2 && Math.rand().abs() % 3 < 2) { var t = ["*puppy eyes*", "Bork? Please?", "*sits by door*"]; return t[Math.rand().abs() % t.size()]; }
            return null;
        }
        if (petType == TYPE_UNDEAD) {
            if (nl >= 4) { var t = ["Alone. Dead. Fine.", "The void is my friend.", "I do not need you.", "Eternity. Alone."]; return t[Math.rand().abs() % t.size()]; }
            return null;
        }
        if (nl >= 4) {
            var t = ["Don't let me die!", "I need you!", "Please...", "Help...", "*crying*", "Anyone..."];
            return t[Math.rand().abs() % t.size()];
        }
        if (nl >= 3 && Math.rand().abs() % 4 < 3) {
            var t = ["Why did you leave?", "Am I forgotten?", "So cold...", "I'm scared...", "Come back!", "Please..."];
            return t[Math.rand().abs() % t.size()];
        }
        if (nl >= 2 && Math.rand().abs() % 3 < 2) {
            var t = ["Please come back", "Don't forget me!", "I'm waiting...", "Miss you so much", "Lonely...", "Where are you?"];
            return t[Math.rand().abs() % t.size()];
        }
        if (nl >= 1 && Math.rand().abs() % 3 == 0) {
            var t = ["Miss you...", "Anyone there?", "So alone...", "Come back...", "Hello?", "Play with me?"];
            return t[Math.rand().abs() % t.size()];
        }
        return null;
    }

    hidden function getMoodThought() {
        var mood = getMoodState();
        if (mood == :calm) { return null; }

        if (Math.rand().abs() % 5 < 2) {
            var tt = getTypeMoodThought(mood);
            if (tt != null) { return tt; }
        }

        var t = null;
        if (mood == :rage) {
            t = ["RAAAGE!", "I'LL EAT THE WATCH!", "*flips table*", "HULK SMASH!",
                 "FEED ME OR ELSE!", "AAARGH!", "*bites screen*", "DESTRUCTION!",
                 "I WILL END YOU!", "*breathes fire*"];
        } else if (mood == :love) {
            t = ["MARRY ME!", "I LOVE YOU!!!", "*aggressive hug*", "You're MY HUMAN!",
                 "Never leave me!", "My heart is FULL!", "*happy crying*", "BEST OWNER!",
                 "Live in ur pocket?", "Don't uninstall me!",
                 "I'll rate u 5 stars!", "*smothers with love*"];
        } else if (mood == :sugar_high) {
            t = ["WHEEEEE!", "I CAN FLY!!", "ZOOOOOM!", "NOTHING STOPS ME!",
                 "*vibrating intensely*", "CATCH ME!", "THE PIXELS ARE ALIVE!",
                 "LOOK MA NO HANDS!", "SPEEEEED!", "AAAAAAA!"];
        } else if (mood == :existential) {
            t = ["Are we just pixels?", "What IS food really?", "Why do I poop?", "42.",
                 "*stares into void*", "Is happiness real?", "Am I... an app?!",
                 "Does Garmin know?", "What if I'm just code?", "...why?"];
        } else if (mood == :paranoid) {
            t = ["THEY'RE WATCHING!", "Trust NO ONE!", "Is that poison?!", "CONSPIRACY!",
                 "*looks around fast*", "I saw something!", "Was that a VIRUS?!",
                 "The walls have eyes!", "WHO'S THERE?!"];
        } else if (mood == :feral) {
            t = ["*GROWL*", "ME WANT FOOD!", "*bites everything*", "HUNT. EAT. SLEEP.",
                 "*wild eyes*", "FOOD. NOW.", "*chews on pixels*", "RAWR!",
                 "NO THINK ONLY EAT", "*scratches screen*"];
        } else if (mood == :party) {
            t = ["PARTY TIME!", "DJ PIXEL!", "LET'S DANCE!", "*sick moves*",
                 "WOOOO!", "Best day EVER!", "TURN IT UP!", "*moonwalk*",
                 "EVERYBODY DANCE!", "*crowd surfs alone*"];
        }
        if (t == null) { return null; }
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getTypeMoodThought(mood) {
        var t = null;
        if (petType == TYPE_FLAMEY) {
            if (mood == :rage) { t = ["I'M ON FIRE!", "BURN IT ALL!", "*volcanic eruption*", "FIRE EVERYWHERE!", "*melts screen*"]; }
            else if (mood == :love) { t = ["You warm my flame!", "Burning love!", "*hearted flames*", "My fire is for YOU!"]; }
            else if (mood == :sugar_high) { t = ["FIRE TORNADO!", "*shoots fireballs*", "HOT HOT HOT!", "WILDFIRE MODE!"]; }
        } else if (petType == TYPE_AQUA) {
            if (mood == :love) { t = ["Drowning in love!", "*love tsunami*", "Ocean of feelings!", "*happy bubbles*", "You make waves!"]; }
            else if (mood == :rage) { t = ["TIDAL WAVE!", "*boiling water*", "STEAM COMING!", "I'LL FLOOD ALL!"]; }
            else if (mood == :existential) { t = ["Am I drop or ocean?", "*evaporates sadly*", "Just a puddle...", "Water has no shape..."]; }
        } else if (petType == TYPE_ROCKY) {
            if (mood == :feral) { t = ["AVALANCHE!", "*throws boulders*", "ROCK SMASH!", "EARTHQUAKE!", "LANDSLIDE!"]; }
            else if (mood == :rage) { t = ["GRANITE FURY!", "*cracks ground*", "VOLCANO MODE!", "TECTONIC RAGE!"]; }
            else if (mood == :party) { t = ["ROCK N ROLL!", "*heavy metal*", "ROCK ON!", "WE WILL ROCK YOU!"]; }
            else if (mood == :existential) { t = ["I'm just a rock...", "Erosion is real...", "Stones don't dream..."]; }
        } else if (petType == TYPE_GHOSTY) {
            if (mood == :paranoid) { t = ["GHOST BUSTERS?!", "Holy water?!", "I hear chanting!", "*phases thru wall*", "AN EXORCIST?!"]; }
            else if (mood == :existential) { t = ["Am I alive or dead?", "*floats sadly*", "Boo... I guess...", "Haunting myself..."]; }
            else if (mood == :love) { t = ["I'll haunt u 4ever!", "Ghost of LOVE!", "*possesses with love*", "Boo-tiful human!"]; }
            else if (mood == :rage) { t = ["POLTERGEIST MODE!", "*rattles chains*", "CURSED!", "I'LL HAUNT YOU!"]; }
        } else if (petType == TYPE_SPARKY) {
            if (mood == :sugar_high) { t = ["ZAP ZAP ZAP!", "*short circuits*", "LIGHTNING MODE!", "1.21 GIGAWATTS!", "OVERLOADING!"]; }
            else if (mood == :rage) { t = ["THUNDER FURY!", "*electric storm*", "ZAP EVERYTHING!", "VOLTAGE MAX!"]; }
            else if (mood == :party) { t = ["ELECTRIC SLIDE!", "*disco ball mode*", "LIGHT SHOW!", "DJ SPARKY!"]; }
        } else if (petType == TYPE_FROSTY) {
            if (mood == :love) { t = ["Cold heart melts!", "*snowflake kiss*", "You thaw my soul!", "Warm inside!", "Frozen no more!"]; }
            else if (mood == :rage) { t = ["ICE AGE COMING!", "*freezes all*", "BLIZZARD MODE!", "COLD FURY!", "ABSOLUTE ZERO!"]; }
            else if (mood == :existential) { t = ["Will I melt someday?", "Just frozen water...", "*melts a little*", "Winter is forever..."]; }
        } else if (petType == TYPE_SHROOMY) {
            if (mood == :party) { t = ["SPORE RAVE!", "*party spores*", "MYCELIUM NETWORK!", "FUNGI FEST!", "TRIPPY VIBES!"]; }
            else if (mood == :sugar_high) { t = ["MAGIC MUSHROOM!", "*grows everywhere*", "SPORE EXPLOSION!", "I'M SPREADING!", "NATURE IS WILD!"]; }
            else if (mood == :existential) { t = ["Am I plant or animal?", "Just a fungus...", "Decomposing reality...", "Spore of the void..."]; }
        } else if (petType == TYPE_BLOBBY) {
            if (mood == :existential) { t = ["What shape AM I?", "Am I even a thing?", "I have no bones...", "Formless forever...", "Blob is not a species!"]; }
            else if (mood == :rage) { t = ["BLOB SMASH!", "*engulfs all*", "I'LL ABSORB YOU!", "ANGRY JELLY!"]; }
            else if (mood == :love) { t = ["*absorbs with love*", "Blob loves HARD!", "Let me engulf u!", "Blobby hug!"]; }
        } else if (petType == TYPE_EMILKA) {
            if (mood == :rage) { t = ["WHO IS SHE?!", "U were with OTHER pet?!", "I SAW U LOOKING!", "You don't love me!", "*checks ur apps*", "WHO TEXTED U?!", "JEALOUS RAGE!"]; }
            else if (mood == :love) { t = ["I LOVE U SO MUCH!", "*draws hearts*", "You're MINE forever!", "Never look at others!", "Tell me I'm pretty!", "SAY IT BACK!", "ONLY ME, OK?!", "*obsessive staring*"]; }
            else if (mood == :existential) { t = ["Nobody loves me...", "Am I not pretty?", "*dramatic crying*", "Life is SO unfair!", "WHY WON'T U LOOK?!", "*flips hair sadly*"]; }
            else if (mood == :sugar_high) { t = ["OMG OMG OMG!", "BESTIES FOREVER!", "*twirls hair*", "Let's take selfie!", "SQUEEEEE!", "SO EXCITING!"]; }
            else if (mood == :party) { t = ["THIS IS MY SONG!", "*hair flip*", "DANCE WITH ME!", "Girl's night out!", "I LOOK AMAZING!", "YAAAS!"]; }
        } else if (petType == TYPE_VEXOR) {
            if (mood == :rage) { t = ["F*CK THIS SH*T!", "I'LL F*CKING END YOU!", "BURN IN HELL!", "EAT SH*T AND DIE!", "MOTHERF*CKER!", "F*CK EVERYTHING!", "GO F*CK YOURSELF!"]; }
            else if (mood == :feral) { t = ["FEED ME B*TCH!", "I'LL EAT YOUR FACE!", "BLOOD! F*CKING BLOOD!", "KILL! KILL! KILL!", "RAAAAGE!"]; }
            else if (mood == :sugar_high) { t = ["HAHA F*CK YES!", "UNSTOPPABLE B*TCH!", "I'M A F*CKING GOD!", "CHAOS! MORE CHAOS!", "EAT MY DUST LOSERS!"]; }
            else if (mood == :paranoid) { t = ["SH*T is that light?!", "F*CK OFF holy water!", "THAT A*SHOLE exorcist!", "DON'T F*CKING TOUCH ME!", "OH SH*T OH F*CK!"]; }
            else if (mood == :party) { t = ["DEATH F*CKING METAL!", "HELL YEAH B*TCHES!", "MOSH PIT MOTHERF*CKER!", "LET'S F*CKING GO!", "PARTY IN HELL!"]; }
            else if (mood == :existential) { t = ["What's the f*cking point", "Even evil gets tired...", "F*ck it all...", "Who gives a sh*t"]; }
        } else if (petType == TYPE_CHIKKO) {
            if (mood == :paranoid) { t = ["THE SKY IS FALLING!", "I HEARD SOMETHING!", "THEY'RE COMING!", "Was that a FOX?!", "DANGER EVERYWHERE!", "HIDE HIDE HIDE!"]; }
            else if (mood == :feral) { t = ["MUST PECK! PECK!", "*pecks at air*", "SEED! WHERE SEED?!", "FERAL CHICKEN!", "NO CAGE HOLDS ME!"]; }
            else if (mood == :sugar_high) { t = ["BAWK BAWK BAWK!", "*runs in circles*", "I CAN FLY!! (no)", "ZOOMIES!", "EGG! ANOTHER EGG!"]; }
            else if (mood == :existential) { t = ["Why can't I fly?", "Am I just food?", "Egg or chicken...", "What came first?", "*sad cluck*"]; }
            else if (mood == :party) { t = ["CHICKEN DANCE!", "*flaps wings*", "BAWK PARTY!", "BEST DAY EVER!"]; }
        } else if (petType == TYPE_DZIKKO) {
            if (mood == :rage) { t = ["CHARGE!!!", "*destroys furniture*", "I'LL GORE YOU!", "OINK OF FURY!", "NOTHING STOPS ME!", "*tramples everything*"]; }
            else if (mood == :feral) { t = ["TRUFFLE! NOW!", "*digs up floor*", "EAT EVERYTHING!", "WILD AND FREE!", "HUNT OR BE HUNTED!"]; }
            else if (mood == :party) { t = ["MUD PARTY!", "*rolls in mud*", "OINK OINK!", "BOAR DANCE!"]; }
            else if (mood == :existential) { t = ["Am I just bacon?", "Wild or domestic?", "*stares at mud*", "The forest calls..."]; }
            else if (mood == :rage) { t = ["I'LL RAM THIS!", "*tusks out*", "TERRITORIAL!", "MY DOMAIN!"]; }
        } else if (petType == TYPE_POLACCO) {
            if (mood == :rage) { t = ["KURWA MAC!", "Ja pierdole!", "CO ZA ZYCIE K*RWA!", "JEBANE PODATKI!", "WSZYSTKO DROGO!", "K*RWA JEBANE CENY!", "WYJEBAC TO!", "POLSKA GINIE!"]; }
            else if (mood == :party) { t = ["GRILLUJEMY K*RWA!", "*otwiera 5te piwo*", "NALEWAJ CH*JU!", "KIELBASKA JEZDZI!", "MECZ LECI KURWA!", "ZIMNE PIWO JEST!", "NO TO JEDZIEMY!"]; }
            else if (mood == :existential) { t = ["Kiedys to bylo...", "Za moich czasow...", "Mlodziez dzisiaj...", "Jebac to zycie...", "Polska w ruinie...", "Eh, ch*j z tym...", "Nie ma po co zyc"]; }
            else if (mood == :feral) { t = ["GDZIE MOJE PIWO?!", "ZERAC!", "K*RWA GLODNY!", "KIELBASA ALBO SM*ERC!"]; }
            else if (mood == :love) { t = ["No...lubic cie ch*j", "*niechcacy sie usmiecha*", "Ej...*burp*...dzieki", "Stara by cie lubila"]; }
        } else if (petType == TYPE_NOSACZ) {
            if (mood == :paranoid) { t = ["E E E!! Patrzo!", "NOS OK! NOS OK!", "Czemu patrzo na nos?!", "E! Nie ruszac nos!", "ZOSTAWIC NOS!"]; }
            else if (mood == :love) { t = ["E! Lubisz nos?!", "*nos sie czerwieni*", "Nos piekny! E E!", "Nos daje buziaka!", "EEEE kocham!"]; }
            else if (mood == :existential) { t = ["Czemu nos taki?", "E... po co nos?", "Nos za duzy?", "*wpatruje sie w nos*", "E... co to zycie"]; }
            else if (mood == :rage) { t = ["EEEEE!! ZLY!!", "*macha nosem*", "NOS WSCIEKLY!", "E!! NIE!! E!!"]; }
            else if (mood == :party) { t = ["E E E! IMPREZA!", "*nos tańczy*", "NOS FAJNY! ZABAWA!", "EEEEE HEHEHE!"]; }
        } else if (petType == TYPE_DONUT) {
            if (mood == :sugar_high) { t = ["SUGAR RUSH!", "*sprinkles fly*", "SO SWEET!", "GLAZED GLORY!", "FROSTING FRENZY!"]; }
            else if (mood == :paranoid) { t = ["Someone's hungry!", "ARE YOU EATING?!", "I SAW A FORK!", "THEY WANT ME!", "IS THAT KETCHUP?!"]; }
            else if (mood == :love) { t = ["Sweetest love!", "*melts with joy*", "Sugar & love!", "Glazed in love!"]; }
            else if (mood == :party) { t = ["DONUT PARTY!", "*rolls around*", "SWEET RAVE!", "BAKERY BASH!"]; }
        } else if (petType == TYPE_CACTUSO) {
            if (mood == :existential) { t = ["Just standing here.", "Desert is quiet.", "Am I a plant?", "No one touches me."]; }
        } else if (petType == TYPE_PIXELBOT) {
            if (mood == :sugar_high) { t = ["OVERCLOCK MODE!", "*fans spinning*", "CPU: 200%!", "TURBO BOOST!", "RAM: UNLIMITED!"]; }
            else if (mood == :paranoid) { t = ["VIRUS DETECTED!", "FIREWALL BREACH!", "MALWARE?!", "BACKUP NOW!"]; }
            else if (mood == :rage) { t = ["RAGE.exe RUNNING!", "ANGER: MAXIMUM!", "*SPARKS FLY*", "LOGIC: FAILED!"]; }
        } else if (petType == TYPE_OCTAVIO) {
            if (mood == :sugar_high) { t = ["8 ARM FRENZY!", "*ink everywhere*", "TENTACLE TORNADO!", "CHAOS OCTOPUS!"]; }
            else if (mood == :party) { t = ["OCEAN RAVE!", "*dances x8*", "INK PARTY!", "TENTACLE WAVE!"]; }
            else if (mood == :feral) { t = ["KRAKEN MODE!", "*giant squid*", "DEVOUR ALL!", "OCEAN FURY!"]; }
        } else if (petType == TYPE_BATSY) {
            if (mood == :paranoid) { t = ["THE SUN!", "TOO BRIGHT!", "NEED DARKNESS!", "DAYLIGHT BURNS!", "WHERE'S MY CAVE?!"]; }
            else if (mood == :party) { t = ["NIGHT RAVE!", "*echolocation*", "BAT DANCE!", "MOON PARTY!"]; }
        } else if (petType == TYPE_NUGGET) {
            if (mood == :paranoid) { t = ["IS THAT SAUCE?!", "SOMEONE'S HUNGRY!", "I'M NOT FOOD!", "THE FRYER!", "KETCHUP!!!", "HELP!"]; }
            else if (mood == :existential) { t = ["Was I a chicken?", "What AM I?", "Born to be eaten?", "Breaded for what?", "Am I alive?"]; }
            else if (mood == :love) { t = ["I'm NOT just food!", "Someone LOVES me!", "*warm & happy*", "Not the fryer!"]; }
        } else if (petType == TYPE_FOCZKA) {
            if (mood == :love) { t = ["*arf arf!* LOVE U!", "*belly up for rubs*", "BEST HUMAN EVER!", "*happy clapping*", "Fish AND hugs?!"]; }
            else if (mood == :party) { t = ["SPLASH PARTY!", "*does tricks*", "ARF ARF ARF!", "*beach ball!*"]; }
            else if (mood == :existential) { t = ["Is ocean home?", "Why am I so round?", "*stares at waves*", "Where's my pod?"]; }
        } else if (petType == TYPE_RAINBOW) {
            if (mood == :sugar_high) { t = ["SPARKLE OVERDOSE!", "*glitter bomb!*", "ALL THE COLORS!", "SHINY SHINY!", "MAXIMUM SPARKLE!"]; }
            else if (mood == :love) { t = ["LOVE IS COLORFUL!", "*heart rainbows*", "You complete my spectrum!", "Double rainbow of love!"]; }
            else if (mood == :party) { t = ["RAINBOW RAVE!", "*prismatic dance*", "COLOR EXPLOSION!", "SPARKLE PARTY!"]; }
            else if (mood == :existential) { t = ["What if colors fade?", "Am I just light?", "After rain... what?", "Spectrum of sadness..."]; }
        } else if (petType == TYPE_DOGGO) {
            if (mood == :party) { t = ["WOOF WOOF WOOF!!", "*full zoomies*", "IS THAT A BALL?!", "WALKIES!! NOW!!", "BEST DAY EVERRR!", "PLAY PLAY PLAY!"]; }
            else if (mood == :love) { t = ["I LOVE YOU I LOVE YOU!", "*lick attack*", "BEST HUMAN ALIVE!", "Never leave me!!", "YOU'RE BACK!!! YESSS!"]; }
            else if (mood == :sugar_high) { t = ["*VIBRATING WITH JOY*", "TOO HAPPY TO THINK!", "ZOOM ZOOM ZOOM!", "BORK BORK BORK!!", "INFINITE ENERGY!!"]; }
            else if (mood == :feral) { t = ["FOOD NOW!!!", "HUNGRY BAD DOG!", "MUST EAT SHOE...", "FERAL MODE ACTIVATED"]; }
        } else if (petType == TYPE_UNDEAD) {
            if (mood == :existential) { t = ["Why do I still walk?", "Death was easier...", "The living exhaust me.", "Eternity is boring.", "Brains... just kidding.", "*decomposes slightly*"]; }
        }
        if (t == null) { return null; }
        return t[Math.rand().abs() % t.size()];
    }

    hidden function getTraitThought() {
        var t = (Math.rand().abs() % 2 == 0) ? trait1 : trait2;
        var opts;
        if (t == TRAIT_GLUTTON) { opts = ["Mmm food...", "Snacks?", "Always hungry!", "NOM", "Just one more bite...", "Is that a crumb?!", "FOOD IS MY RELIGION", "Hungry. So hungry. Always.", "I'd eat the watch if it had flavour.", "*imagines buffet*"]; }
        else if (t == TRAIT_PICKY) { opts = ["Ew, not that", "Want gourmet!", "Meh...", "Fancy?", "This is beneath me.", "Substandard.", "I HAVE STANDARDS.", "Not this trash.", "*sniffs disapprovingly*", "Chef? What chef?"]; }
        else if (t == TRAIT_PLAYFUL) { opts = ["Play play!", "Tag!", "Wheee!", "Let's go!", "CATCH ME IF U CAN!", "Ready? 3...2...1...GO!", "Games forever~", "*bounces off walls*", "Is everything a game? Yes.", "I turned napping into a sport."]; }
        else if (t == TRAIT_LAZY) { opts = ["Nah...", "5 more min", "*sprawl*", "Effort...", "Later. Much later.", "The floor is comfortable.", "Motivation? Never heard of her.", "*slides off couch*", "Why stand when you can lie?", "Napping is a lifestyle."]; }
        else if (t == TRAIT_HARDY) { opts = ["Strong!", "Tough!", "Bring it!", "No prob", "I CANNOT be stopped.", "Pain? What pain?", "I once ate a rock.", "Survived again.", "Unbreakable~", "Try me. Please."]; }
        else if (t == TRAIT_FRAGILE) { opts = ["Careful...", "Gentle!", "*sniffle*", "Ouch", "Everything hurts...", "So delicate...", "Handle with care pls!", "I bruise easily.", "*flinches at wind*", "Life is very sharp."]; }
        else if (t == TRAIT_CHEERFUL) { opts = ["Yippee!", "Sunshine!", "Love life!", "Joy!", "TODAY IS GREAT!", "Serotonin: MAX", "Every day is a gift!", "*skips happily*", "You are amazing!!", "Nothing can stop me~"]; }
        else if (t == TRAIT_GRUMPY) { opts = ["Hmph.", "Whatever.", "Ugh.", "Go away", "Leave me alone.", "Not in the mood.", "Everything sucks.", "Don't talk to me.", "*rolls eyes*", "Get off my lawn."]; }
        else if (t == TRAIT_HYPER) { opts = ["GOGO!", "ZOOM!", "Can't stop!", "!!!", "AAAAAAA!", "WHY IS EVERYTHING SO SLOW", "*vibrating*", "I have 47 ideas RIGHT NOW!", "MOVE MOVE MOVE!", "IS THIS FAST ENOUGH?!"]; }
        else { opts = ["*yawn*", "Zzz...", "So sleepy", "Bed?", "Just 5 more hours...", "*falls asleep standing*", "Consciousness is optional.", "Nap o'clock.", "*snores lightly*", "Sleep > everything, always."]; }
        return opts[Math.rand().abs() % opts.size()];
    }

    hidden function getTypeThought() {
        var t;
        if (petType == TYPE_BLOBBY) { t = ["Bloop!", "Squish~", "Bounce!", "Blob~", "Am I liquid?", "*absorbs air*", "Shape? What shape?", "I have no bones. Freedom.", "Blobbing around~", "Technically I'm a gel.", "Everything is blob.", "I once ate a chair. Whole.", "*jiggles for no reason*", "Formless and loving it."]; }
        else if (petType == TYPE_FLAMEY) { t = ["Hot hot!", "Sizzle!", "Burn~", "Flame on!", "Everything is fuel!", "*sets air on fire*", "WHO NEEDS EYEBROWS", "I am a fire hazard :)", "Toasty~", "No one can extinguish me!", "I ran out of marshmallows to ruin.", "Arson? Me? Never.", "*singes something nearby*", "Heat is my love language."]; }
        else if (petType == TYPE_AQUA) { t = ["Splash~", "Bubble!", "Flow~", "Drip drip", "I AM the ocean", "*evaporates slightly*", "Hydration queen~", "Water you doing?", "Current mood: wavy", "I'll outlast all of you.", "*flows around obstacle*", "Drop by drop~", "Tides in, vibes in~", "I once drowned a rock."]; }
        else if (petType == TYPE_ROCKY) { t = ["Solid.", "Rock on!", "Steady~", "Crunch", "I don't roll. I AM.", "Minerals!", "Been here 1000 yrs", "You think YOU'RE hard?", "Sedimentary, my dear.", "I have layers. Literally.", "My last friend was a fossil.", "Still here. Still solid.", "*casually exists for millennia*", "Erosion? lol."]; }
        else if (petType == TYPE_GHOSTY) { t = ["Boo!", "Whoosh~", "Spooky!", "Float~", "Can you see me?!", "*phases thru wall*", "I haunt therefore I am", "Death was just a restart.", "*goes 30% translucent*", "My therapist is also dead.", "Haunted? No. I haunt.", "Boo and I'll do it again.", "*casually walks through you*", "The living confuse me."]; }
        else if (petType == TYPE_SPARKY) { t = ["Bzzt!", "ZAP!", "Spark!", "Charge!", "UNLIMITED POWER!", "*shorts out*", "I AM the outlet!", "Grounded? Never.", "Please don't lick me.", "Voltage: maximum.", "*accidentally zaps self*", "Static is my love language.", "I once fried a microwave.", "CONDUCTIVITY!"]; }
        else if (petType == TYPE_FROSTY) { t = ["Brrr~", "Chill~", "Cool!", "Frost~", "Let it go~", "*freezes a tear mid-fall*", "Cold outside, colder inside", "Sub-zero mood.", "Ice to meet you.", "Permafrost personality.", "*breathes visible breath*", "Winter IS my personality.", "I freeze things by accident.", "Warmth is overrated."]; }
        else if (petType == TYPE_SHROOMY) { t = ["Spore!", "Fungi~", "Grow!", "Bloom~", "Reality is spores", "*trips on own spores*", "I see the TRUTH", "We are all connected. Via me.", "The underground network speaks.", "Mycology is art.", "*releases spore cloud*", "I grow in the dark. Relatable.", "My roots go everywhere.", "Decomposition is beautiful."]; }
        else if (petType == TYPE_EMILKA) { t = ["*hair flip*", "Heyyy~", "Love me!", "Cutie~", "U thinking of me?", "Am I pretty?!", "*checks mirror*", "NOTICE ME!", "Kto pisal?!", "Read receipts ON.", "*posts sad quote*", "I just want to be obsessed over.", "YOU WERE SUPPOSED TO TEXT BACK!", "We're SO meant to be.", "*dramatically sighs*", "One notification. That's all I ask."]; }
        else if (petType == TYPE_VEXOR) { t = ["F*ck off", "*spits*", "Die already", "Piece of sh*t", "Go to hell", "I hate everything", "Kiss my a*s", "Eat sh*t", "Worthless human", "You disgust me", "F*cking pathetic", "WHY ARE YOU STILL HERE", "*contemplates chaos*", "I dream of destruction.", "Get out of my sight.", "*destroys something small*", "Nothing brings me joy. Except suffering."]; }
        else if (petType == TYPE_CHIKKO) { t = ["BAWK!", "*pecks ground*", "Seed?", "*nervous cluck*", "W-what was that?!", "THE SKY IS FALLING!", "Is that a FOX?!", "*panic molt*", "DANGER! ALWAYS DANGER!", "My eggs... where?!", "I trust NO ONE.", "The farmer is coming.", "*clucks in Morse code*", "EVERY SHADOW IS A PREDATOR", "*runs in wrong direction*"]; }
        else if (petType == TYPE_DZIKKO) { t = ["*SNORT*", "OINK!", "*digs dirt*", "*charges wall*", "MY territory!", "I'll RAM you", "TRUFFLES OR DEATH", "*sharpens tusks*", "WHO WANTS IT?!", "I headbutted a tree. Tree lost.", "The forest fears ME.", "*roots up the floor*", "Oink first, ask never.", "My anger is my compass."]; }
        else if (petType == TYPE_POLACCO) { t = ["Piwo by sie...", "*beka*", "Grilla odpalic?", "Jebane podatki", "Kto pytal?", "Eh, k*rwa...", "Zimne?", "*drapie jaja*", "Mecz kiedy?", "Kielbasy daj", "Ty za to placisz", "A bo ja wiem...", "Co za kraj...", "Za Gierka lepiej bylo", "Sasiad ch*j", "Trawnik sam sie nie skosi", "Emisja CO2? G*wno mnie obchodzi.", "Dzieci dzisiaj to...", "Emerytury nie bedzie.", "Chleb za 10zl? SKANDAL!", "*zapala nieregulaminowo*", "W mojej wsi bylo lepiej.", "Europa nam nie bedzie mowic!"]; }
        else if (petType == TYPE_NOSACZ) { t = ["E E E!", "Nos!", "*wącha*", "E?", "EEEEE!", "Nos duzy!", "*drapie nos*", "Hehe nos", "E E!", "Nos najlepszy!", "*oblizuje nos*", "Duzy nos = madry!", "E! E! E! E!", "*nos wedrowny*", "Nos wie wszystko.", "E wszystko E.", "*wącha innych*", "Nos pamieta."]; }
        else if (petType == TYPE_DONUT) { t = ["Sprinkles!", "Sweet~", "*rolls*", "Glazed!", "Yummy me!", "Don't bite!", "Am I a snack?!", "FROSTING IS LIFE", "I'm a circle of JOY", "Donut worry~", "I have a hole in my heart. Literally.", "Round is a shape!", "*gets more sprinkles*", "Sugar rush incoming~", "Life is short. Eat donuts.", "I am the snack and the meal."]; }
        else if (petType == TYPE_CACTUSO) { t = ["...", "*stands*", "Don't.", "Sun.", "Water?", "No hug.", "Touch = pain.", "I have needs. Very few.", "I've been in this pot for years.", "The desert had personality.", "Thorns are just pointy hugs.", "Alone. Good.", "I bloom once. You missed it.", "*drops spine passive-aggressively*", "Solitude is optimal."]; }
        else if (petType == TYPE_PIXELBOT) { t = ["Beep.", "01001", "Process.", "Compute.", "Logic.", "EMOTION: undefined", "Beep boop.", "WHY: insufficient data", "COMPUTING...", "Error 404: fun not found", "My feelings are a subroutine.", "MEMORY: 99% existential dread", "Sleep.exe stopped working.", "*runs defrag*", "Recalibrating humanity expectations.", "I calculated your life choices. Poor."]; }
        else if (petType == TYPE_OCTAVIO) { t = ["*squish*", "Ink!", "Tentacle!", "*bubbles*", "8 arms!", "I multitask LITERALLY", "*juggles 6 things*", "Ocean vibes~", "I can open any jar.", "Eight hugs simultaneously.", "Ink is both art and defense.", "*accidentally inks self*", "My arms have their own opinions.", "I am my own crowd.", "Sea floor is underrated."]; }
        else if (petType == TYPE_BATSY) { t = ["*chirp*", "Zzz...", "*hangs*", "Night!", "*echo*", "Turn off the sun!", "Upside down is RIGHT", "I see in the dark~", "Echolocation is a vibe.", "Darkness is cozy.", "*sleeps 18 hours. You should too.*", "The day is the enemy.", "Caves > houses.", "*makes sound only dogs hear*", "Inverted is the correct orientation."]; }
        else if (petType == TYPE_NUGGET) { t = ["Am I food?", "*sweats*", "Crispy...", "*exists*", "Help...", "Is that SAUCE?!", "I was a CHICKEN", "WHY AM I BREADED", "Don't dip me!", "McDonald's is a nightmare.", "Every day is borrowed.", "Is this ketchup?!", "I have no future. Only sauce.", "*crunches with anxiety*", "Do I taste good? Don't tell me."]; }
        else if (petType == TYPE_FOCZKA) { t = ["Arf!", "*flop*", "Fish?", "*claps*", "Splash~", "*belly flop*", "Throw me a ball!", "*wiggles*", "Arf arf arf!", "*balances fish on nose*", "I am a professional flopper.", "ARF = love language.", "*spins on ice*", "Belly rubs: ALWAYS YES.", "The beach is home.", "*claps for no reason*"]; }
        else if (petType == TYPE_DOGGO) { t = ["WOOF!", "*tail wag*", "Ball?!", "*zoomies*", "Bork!", "WALKIES?!", "*spins*", "Squirrel!", "I LOVE YOU!", "*sniffs everything*", "WHO IS GOOD BOY?! ME!", "BEST DAY EVER. AGAIN.", "*digs inappropriate hole*", "Your face smells so good!", "I waited FOREVER (3 minutes).", "THE MAILMAN IS MY NEMESIS.", "*destroys sock out of pure love*", "You came back!!! You ALWAYS come back!!"]; }
        else if (petType == TYPE_UNDEAD) { t = ["...", "*exists*", "Still here.", "*rattles*", "Uuugh...", "Cold.", "Forever.", "*stares*", "Brains?", "Death is fine.", "Eternity is... fine.", "*decomposes slightly*", "I've seen empires fall.", "The living confuse me.", "Sleep is for the living.", "*drops a rib accidentally*"]; }
        else { t = ["Sparkle!", "*glows*", "Rainbow~", "Shine!", "Colors!", "DOUBLE RAINBOW!", "I am LIGHT!", "Glitter bomb~", "Love & sparkles!", "Roy G Biv is my spirit animal.", "Every color is valid!", "*leaves glitter trail*", "I am visible from space.", "Chromatic excellence!", "*vibing in spectrum*"]; }
        return t[Math.rand().abs() % t.size()];
    }

    function getSteps() {
        if (Toybox has :ActivityMonitor) {
            var info = ActivityMonitor.getInfo();
            if (info != null) { return info.steps; }
        }
        return -1;
    }

    hidden function getStepThought() {
        var steps = getSteps();
        if (steps < 0) { return null; }
        if (petType == TYPE_POLACCO) {
            if (steps >= 20000) { var t = ["Kurwa, maraton?!", "Nogi bola juz ch*j", "Biegasz jak pojeb*ny"]; return t[Math.rand().abs() % t.size()]; }
            if (steps >= 10000) { var t = ["10 tysiecy? Niezle", "Nogi nie bolom?", "Chodzisz duzo k*rwa"]; return t[Math.rand().abs() % t.size()]; }
            if (steps >= 5000) { var t = ["No ujdzie", "Chodzisz chodzisz", "Zaliczone k*rwa"]; return t[Math.rand().abs() % t.size()]; }
            if (steps < 500) { var t = ["Lezyocho co?", "Rusz dupe k*rwa!", "Kanapa king!", "Leniu jebany"]; return t[Math.rand().abs() % t.size()]; }
            return null;
        }
        if (petType == TYPE_NUGGET) {
            if (steps >= 20000) { return "Running from your DESTINY?!"; }
            if (steps >= 10000) { return "Running from FATE?"; }
            if (steps >= 5000) { return "That's a lot of steps for a snack..."; }
            if (steps < 500) { return "At least I'm not jogging..."; }
            return null;
        }
        if (petType == TYPE_CACTUSO) {
            if (steps >= 10000) { return "I don't have legs."; }
            if (steps >= 5000) { return "I watch you walk. Jealously."; }
            if (steps < 500) { return "Same."; }
            return null;
        }
        if (petType == TYPE_FOCZKA) {
            if (steps >= 20000) { var ft = ["MARATHON ARF!", "SO MANY STEPS ARF!!", "*claps flippers for you*"]; return ft[Math.rand().abs() % ft.size()]; }
            if (steps >= 10000) { return "*arf!* So many steps!"; }
            if (steps >= 5000) { return "Good waddle! ARF!"; }
            if (steps < 500) { return "*flop* No swim today?"; }
            return null;
        }
        if (petType == TYPE_DOGGO) {
            if (steps >= 20000) { var dt = ["WALKIES FOREVER!!!", "INFINITE WALK MODE!", "UNSTOPPABLE LEGS!!"]; return dt[Math.rand().abs() % dt.size()]; }
            if (steps >= 10000) { var dt = ["THIS IS THE BEST DAY", "10k?! I'M SO PROUD!!!", "WALK CHAMPION!!"]; return dt[Math.rand().abs() % dt.size()]; }
            if (steps >= 5000) { var dt = ["Good WALK! BORK!", "HALFWAY TO HEAVEN!", "Steps good!!! BORK!!"]; return dt[Math.rand().abs() % dt.size()]; }
            if (steps < 500) { var dt = ["*stares at leash*", "*sad leash look*", "Leash... gathering dust..."]; return dt[Math.rand().abs() % dt.size()]; }
            return null;
        }
        if (petType == TYPE_UNDEAD) {
            if (steps >= 10000) { return "Shambling forever."; }
            if (steps >= 5000) { return "Acceptable shambling."; }
            if (steps < 500) { return "Same as me."; }
            return null;
        }
        if (petType == TYPE_EMILKA) {
            if (steps >= 10000) { return "All this walking & u still don't text!"; }
            if (steps >= 5000) { return "Walk WITH me sometime?"; }
            if (steps < 500) { return "We could walk TOGETHER..."; }
            return null;
        }
        if (petType == TYPE_VEXOR) {
            if (steps >= 10000) { return "Running from your problems? Coward."; }
            if (steps >= 5000) { return "Trying to escape? Pathetic."; }
            if (steps < 500) { return "Good. Stay put. Easier to find you."; }
            return null;
        }
        if (petType == TYPE_PIXELBOT) {
            if (steps >= 20000) { return "STEPS: RECORD. PROUD.EXE"; }
            if (steps >= 10000) { return "PHYSICAL.EXE: OPTIMAL"; }
            if (steps >= 5000) { return "PROGRESS: ADEQUATE"; }
            if (steps < 500) { return "MOVEMENT: INSUFFICIENT"; }
            return null;
        }
        if (petType == TYPE_CHIKKO) {
            if (steps >= 10000) { return "Running from FOX! Still running!"; }
            if (steps >= 5000) { return "EXERCISE = less easy for fox!"; }
            if (steps < 500) { var ct = ["*nervous stillness*", "Staying still. Safer.", "No movement. No detection."]; return ct[Math.rand().abs() % ct.size()]; }
            return null;
        }
        if (petType == TYPE_FLAMEY) {
            if (steps >= 10000) { return "Burning calories LITERALLY!"; }
            if (steps >= 5000) { return "Hot pursuit of fitness!"; }
            if (steps < 500) { return "*fire dims slightly*"; }
            return null;
        }
        if (petType == TYPE_ROCKY) {
            if (steps >= 10000) { return "Even rocks move eventually."; }
            if (steps >= 5000) { return "Solid footwork."; }
            if (steps < 500) { return "I respect the stillness."; }
            return null;
        }
        var t;
        if (steps >= 20000) { t = ["Marathon king!", "Unstoppable!", "ULTRA LEGS!", "Are you OK?!", "Do you LIVE on a treadmill?!", "20k steps?! Please rest!", "Human speedrun!"]; }
        else if (steps >= 10000) { t = ["10k! Wow!", "Champion!", "So active!", "Go go go!", "Unstoppable human!", "Step king/queen!", "I'm proud of you!"]; }
        else if (steps >= 5000) { t = ["Good walking!", "Keep it up!", "Nice moves!", "Getting there!", "Halfway to legend!", "Not bad, not bad~", "Step by step~"]; }
        else if (steps < 500) { t = ["Walk more!", "Lazy day?", "Move it!", "Couch potato?", "Get up!", "Touch grass!", "Your legs are decorative today.", "Step 1: take a step."]; }
        else { return null; }
        return t[Math.rand().abs() % t.size()];
    }

    // ===== Drawing =====

    function draw(dc, cx, cy, ps) {
        var state = getState();
        var sx = cx - 6 * ps;
        var sy = cy - 6 * ps;
        var colors;
        if (isAlive) {
            colors = getColors(petType);
            if (action == ACT_NONE) {
                var wb = getWellbeing();
                if (wb < 50) { colors = desaturateColors(colors, wb); }
            }
        }
        else { colors = [0x333333, 0x555555, 0x777777, 0x999999]; }
        renderBody(dc, sx, sy, ps, petType, colors);
        drawFace(dc, sx, sy, ps, state);
        if (accessory != ACC_NONE) { drawAccessory(dc, cx, cy, ps); }
    }

    hidden function drawAccessory(dc, cx, cy, ps) {
        if (accessory == ACC_HAT) {
            dc.setColor(0x333333, 0x333333);
            dc.fillRectangle(cx - 4 * ps, cy - 7 * ps, 8 * ps, ps);
            dc.setColor(0x555555, 0x555555);
            dc.fillRectangle(cx - 2 * ps, cy - 9 * ps, 4 * ps, 2 * ps);
        } else if (accessory == ACC_BOW) {
            dc.setColor(0xFF6699, 0xFF6699);
            dc.fillRectangle(cx + 4 * ps, cy - 6 * ps, ps, 2 * ps);
            dc.setColor(0xFF3377, 0xFF3377);
            dc.fillRectangle(cx + 3 * ps, cy - 7 * ps, ps, ps);
            dc.fillRectangle(cx + 5 * ps, cy - 7 * ps, ps, ps);
            dc.fillRectangle(cx + 3 * ps, cy - 4 * ps, ps, ps);
            dc.fillRectangle(cx + 5 * ps, cy - 4 * ps, ps, ps);
        } else if (accessory == ACC_GLASSES) {
            dc.setColor(0x222222, 0x222222);
            dc.fillRectangle(cx - 4 * ps, cy - 3 * ps, 3 * ps, 2 * ps);
            dc.fillRectangle(cx + ps, cy - 3 * ps, 3 * ps, 2 * ps);
            dc.fillRectangle(cx - ps, cy - 2 * ps, 2 * ps, ps);
            dc.setColor(0x88BBFF, 0x88BBFF);
            dc.fillRectangle(cx - 3 * ps, cy - 2 * ps, ps, ps);
            dc.fillRectangle(cx + 2 * ps, cy - 2 * ps, ps, ps);
        } else if (accessory == ACC_CROWN) {
            dc.setColor(0xFFD700, 0xFFD700);
            dc.fillRectangle(cx - 3 * ps, cy - 7 * ps, 6 * ps, ps);
            dc.fillRectangle(cx - 3 * ps, cy - 9 * ps, ps, 2 * ps);
            dc.fillRectangle(cx - ps, cy - 8 * ps, ps, ps);
            dc.fillRectangle(cx + ps, cy - 8 * ps, ps, ps);
            dc.fillRectangle(cx + 2 * ps, cy - 9 * ps, ps, 2 * ps);
            dc.setColor(0xFF2222, 0xFF2222);
            dc.fillRectangle(cx, cy - 7 * ps, ps, ps);
        } else if (accessory == ACC_BANDANA) {
            dc.setColor(0xCC2222, 0xCC2222);
            dc.fillRectangle(cx - 5 * ps, cy - 6 * ps, 10 * ps, ps);
            dc.fillRectangle(cx + 5 * ps, cy - 5 * ps, ps, ps);
            dc.fillRectangle(cx + 5 * ps, cy - 4 * ps, ps, ps);
            dc.setColor(0xFFDD44, 0xFFDD44);
            dc.fillRectangle(cx - ps, cy - 6 * ps, ps, ps);
            dc.fillRectangle(cx + ps, cy - 6 * ps, ps, ps);
        }
    }

    function drawPreview(dc, cx, cy, ps, type) {
        var sx = cx - 6 * ps;
        var sy = cy - 6 * ps;
        renderBody(dc, sx, sy, ps, type, getColors(type));
        drawFace(dc, sx, sy, ps, :normal);
    }

    hidden function desaturateColors(colors, wb) {
        var factor = 30 + wb * 70 / 50;
        if (factor > 100) { factor = 100; }
        return [desatClr(colors[0], factor), desatClr(colors[1], factor),
                desatClr(colors[2], factor), desatClr(colors[3], factor)];
    }

    hidden function desatClr(c, factor) {
        var r = (c >> 16) & 0xFF;
        var g = (c >> 8) & 0xFF;
        var b = c & 0xFF;
        var gray = (r + g + b) / 3;
        r = gray + (r - gray) * factor / 100;
        g = gray + (g - gray) * factor / 100;
        b = gray + (b - gray) * factor / 100;
        if (r < 0) { r = 0; } if (r > 255) { r = 255; }
        if (g < 0) { g = 0; } if (g > 255) { g = 255; }
        if (b < 0) { b = 0; } if (b > 255) { b = 255; }
        return (r << 16) | (g << 8) | b;
    }

    hidden function renderBody(dc, sx, sy, ps, type, colors) {
        var body = getBody(type);
        var lastClr = -1;
        for (var r = 0; r < 12; r++) {
            for (var c = 0; c < 12; c++) {
                var v = body[r * 12 + c];
                if (v > 0) {
                    var clr = colors[v - 1];
                    if (clr != lastClr) { dc.setColor(clr, clr); lastClr = clr; }
                    dc.fillRectangle(sx + c * ps, sy + r * ps, ps, ps);
                }
            }
        }
    }

    hidden function drawFace(dc, sx, sy, ps, state) {
        var eye = 0x1A1A1A;
        var mouth = 0xCC3333;
        if (state == :dead) {
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+2*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+4*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+3*ps, sy+5*ps, ps, ps);
            dc.fillRectangle(sx+2*ps, sy+6*ps, ps, ps);
            dc.fillRectangle(sx+4*ps, sy+6*ps, ps, ps);
            dc.fillRectangle(sx+7*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+9*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+8*ps, sy+5*ps, ps, ps);
            dc.fillRectangle(sx+7*ps, sy+6*ps, ps, ps);
            dc.fillRectangle(sx+9*ps, sy+6*ps, ps, ps);
            dc.setColor(mouth, mouth);
            dc.fillRectangle(sx+4*ps, sy+8*ps, 4*ps, ps);
        } else if (state == :sick) {
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+2*ps, sy+4*ps, 3*ps, ps);
            dc.fillRectangle(sx+4*ps, sy+5*ps, ps, ps);
            dc.fillRectangle(sx+3*ps, sy+6*ps, 2*ps, ps);
            dc.fillRectangle(sx+7*ps, sy+4*ps, 3*ps, ps);
            dc.fillRectangle(sx+9*ps, sy+5*ps, ps, ps);
            dc.fillRectangle(sx+8*ps, sy+6*ps, 2*ps, ps);
            dc.setColor(mouth, mouth);
            dc.fillRectangle(sx+4*ps, sy+7*ps, ps, ps);
            dc.fillRectangle(sx+5*ps, sy+8*ps, ps, ps);
            dc.fillRectangle(sx+6*ps, sy+7*ps, ps, ps);
            dc.fillRectangle(sx+7*ps, sy+8*ps, ps, ps);
        } else if (state == :sleeping) {
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+2*ps, sy+5*ps, 3*ps, ps);
            dc.fillRectangle(sx+7*ps, sy+5*ps, 3*ps, ps);
            dc.setColor(mouth, mouth);
            dc.fillRectangle(sx+5*ps, sy+8*ps, 2*ps, ps);
        } else if (state == :happy || state == :eating) {
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+3*ps, sy+4*ps, 3*ps, ps);
            dc.fillRectangle(sx+7*ps, sy+4*ps, 3*ps, ps);
            dc.setColor(mouth, mouth);
            dc.fillRectangle(sx+3*ps, sy+6*ps, ps, ps);
            dc.fillRectangle(sx+4*ps, sy+7*ps, 4*ps, ps);
            dc.fillRectangle(sx+8*ps, sy+6*ps, ps, ps);
            dc.setColor(0xFFB6C1, 0xFFB6C1);
            dc.fillRectangle(sx+2*ps, sy+6*ps, ps, ps);
            dc.fillRectangle(sx+9*ps, sy+6*ps, ps, ps);
        } else if (state == :desperate) {
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+3*ps, sy+3*ps, 2*ps, 3*ps);
            dc.fillRectangle(sx+7*ps, sy+3*ps, 2*ps, 3*ps);
            dc.setColor(0x42A5F5, 0x42A5F5);
            dc.fillRectangle(sx+4*ps, sy+6*ps, ps, ps);
            dc.fillRectangle(sx+8*ps, sy+6*ps, ps, ps);
            dc.setColor(mouth, mouth);
            var mw = (animFrame % 4 < 2) ? 1 : 0;
            dc.fillRectangle(sx+4*ps, sy+8*ps+mw, 4*ps, ps);
            dc.fillRectangle(sx+3*ps, sy+7*ps+mw, ps, ps);
            dc.fillRectangle(sx+8*ps, sy+7*ps+mw, ps, ps);
        } else if (state == :rage) {
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+2*ps, sy+3*ps, ps, ps);
            dc.fillRectangle(sx+3*ps, sy+4*ps, 2*ps, ps);
            dc.fillRectangle(sx+9*ps, sy+3*ps, ps, ps);
            dc.fillRectangle(sx+7*ps, sy+4*ps, 2*ps, ps);
            dc.fillRectangle(sx+3*ps, sy+5*ps, 2*ps, ps);
            dc.fillRectangle(sx+7*ps, sy+5*ps, 2*ps, ps);
            dc.setColor(mouth, mouth);
            dc.fillRectangle(sx+3*ps, sy+7*ps, 6*ps, ps);
            dc.setColor(0xFFFFFF, 0xFFFFFF);
            dc.fillRectangle(sx+4*ps, sy+8*ps, ps, ps);
            dc.fillRectangle(sx+6*ps, sy+8*ps, ps, ps);
            dc.fillRectangle(sx+8*ps, sy+8*ps, ps, ps);
        } else if (state == :love) {
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+3*ps, sy+4*ps, 2*ps, ps);
            dc.fillRectangle(sx+7*ps, sy+4*ps, 2*ps, ps);
            dc.setColor(0xFF6B8A, 0xFF6B8A);
            dc.fillRectangle(sx+1*ps, sy+5*ps, 2*ps, 2*ps);
            dc.fillRectangle(sx+9*ps, sy+5*ps, 2*ps, 2*ps);
            dc.setColor(mouth, mouth);
            dc.fillRectangle(sx+2*ps, sy+6*ps, ps, ps);
            dc.fillRectangle(sx+3*ps, sy+7*ps, 6*ps, ps);
            dc.fillRectangle(sx+9*ps, sy+6*ps, ps, ps);
        } else if (state == :feral) {
            dc.setColor(0xFFFFFF, 0xFFFFFF);
            dc.fillRectangle(sx+2*ps, sy+3*ps, 3*ps, 3*ps);
            dc.fillRectangle(sx+7*ps, sy+3*ps, 3*ps, 3*ps);
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+3*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+8*ps, sy+4*ps, ps, ps);
            dc.setColor(mouth, mouth);
            dc.fillRectangle(sx+3*ps, sy+7*ps, ps, ps);
            dc.fillRectangle(sx+4*ps, sy+8*ps, ps, ps);
            dc.fillRectangle(sx+5*ps, sy+7*ps, ps, ps);
            dc.fillRectangle(sx+6*ps, sy+8*ps, ps, ps);
            dc.fillRectangle(sx+7*ps, sy+7*ps, ps, ps);
            dc.fillRectangle(sx+8*ps, sy+8*ps, ps, ps);
        } else if (state == :stuffed) {
            dc.setColor(0x55AA55, 0x55AA55);
            dc.fillRectangle(sx+1*ps, sy+6*ps, 2*ps, 2*ps);
            dc.fillRectangle(sx+9*ps, sy+6*ps, 2*ps, 2*ps);
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+2*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+4*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+3*ps, sy+5*ps, ps, ps);
            dc.fillRectangle(sx+7*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+9*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+8*ps, sy+5*ps, ps, ps);
            dc.setColor(0x88CC44, 0x88CC44);
            dc.fillRectangle(sx+4*ps, sy+7*ps, 4*ps, 2*ps);
            dc.fillRectangle(sx+5*ps, sy+9*ps, 2*ps, ps);
            dc.fillRectangle(sx+5*ps, sy+10*ps, ps, ps);
        } else if (state == :sad || state == :hungry) {
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+3*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+3*ps, sy+5*ps, 2*ps, 2*ps);
            dc.fillRectangle(sx+8*ps, sy+4*ps, ps, ps);
            dc.fillRectangle(sx+7*ps, sy+5*ps, 2*ps, 2*ps);
            dc.setColor(mouth, mouth);
            dc.fillRectangle(sx+3*ps, sy+7*ps, ps, ps);
            dc.fillRectangle(sx+4*ps, sy+8*ps, 4*ps, ps);
            dc.fillRectangle(sx+8*ps, sy+7*ps, ps, ps);
        } else {
            dc.setColor(eye, eye);
            dc.fillRectangle(sx+3*ps, sy+4*ps, 2*ps, 2*ps);
            dc.fillRectangle(sx+7*ps, sy+4*ps, 2*ps, 2*ps);
            dc.setColor(mouth, mouth);
            dc.fillRectangle(sx+4*ps, sy+7*ps, 4*ps, ps);
        }
    }

    // ===== Body data =====

    hidden function getBody(type) {
        if (type == _bodyCacheType && _bodyCache != null) { return _bodyCache; }
        var b;
        if (type == TYPE_BLOBBY) { b = bodyBlobby(); }
        else if (type == TYPE_FLAMEY) { b = bodyFlamey(); }
        else if (type == TYPE_AQUA) { b = bodyAqua(); }
        else if (type == TYPE_ROCKY) { b = bodyRocky(); }
        else if (type == TYPE_GHOSTY) { b = bodyGhosty(); }
        else if (type == TYPE_SPARKY) { b = bodySparky(); }
        else if (type == TYPE_FROSTY) { b = bodyFrosty(); }
        else if (type == TYPE_SHROOMY) { b = bodyShroomy(); }
        else if (type == TYPE_EMILKA) { b = bodyEmilka(); }
        else if (type == TYPE_VEXOR) { b = bodyVexor(); }
        else if (type == TYPE_CHIKKO) { b = bodyChikko(); }
        else if (type == TYPE_DZIKKO) { b = bodyDzikko(); }
        else if (type == TYPE_POLACCO) { b = bodyPolacco(); }
        else if (type == TYPE_NOSACZ) { b = bodyNosacz(); }
        else if (type == TYPE_DONUT) { b = bodyDonut(); }
        else if (type == TYPE_CACTUSO) { b = bodyCactuso(); }
        else if (type == TYPE_PIXELBOT) { b = bodyPixelbot(); }
        else if (type == TYPE_OCTAVIO) { b = bodyOctavio(); }
        else if (type == TYPE_BATSY) { b = bodyBatsy(); }
        else if (type == TYPE_NUGGET) { b = bodyNugget(); }
        else if (type == TYPE_FOCZKA) { b = bodyFoczka(); }
        else if (type == TYPE_DOGGO) { b = bodyDoggo(); }
        else if (type == TYPE_UNDEAD) { b = bodyUndead(); }
        else { b = bodyRainbow(); }
        if (type == petType) { _bodyCache = b; _bodyCacheType = type; }
        return b;
    }

    function getColors(type) {
        var base;
        if (type == TYPE_BLOBBY) { base = [0x1B5E20, 0x388E3C, 0x66BB6A, 0xA5D6A7]; }
        else if (type == TYPE_FLAMEY) { base = [0x8B1A00, 0xE65100, 0xFF9800, 0xFFEB3B]; }
        else if (type == TYPE_AQUA) { base = [0x0D47A1, 0x1976D2, 0x42A5F5, 0x80D8FF]; }
        else if (type == TYPE_ROCKY) { base = [0x3E2723, 0x6D4C41, 0xA1887F, 0xFFD54F]; }
        else if (type == TYPE_GHOSTY) { base = [0x311B92, 0x7C4DFF, 0xB388FF, 0xE8EAF6]; }
        else if (type == TYPE_SPARKY) { base = [0x827717, 0xF9A825, 0xFFEE58, 0x00E5FF]; }
        else if (type == TYPE_FROSTY) { base = [0x006064, 0x0097A7, 0x80DEEA, 0xE0F7FA]; }
        else if (type == TYPE_SHROOMY) { base = [0x6A1B9A, 0xAB47BC, 0xCE93D8, 0xFFF9C4]; }
        else if (type == TYPE_EMILKA) { base = [0xFFD4A8, 0xC89B30, 0xDAAF3A, 0xFF8FAA]; }
        else if (type == TYPE_VEXOR) { base = [0x660022, 0xFF2222, 0x330033, 0xFF6600]; }
        else if (type == TYPE_CHIKKO) { base = [0xF0F0F0, 0xFF2222, 0xFFAA33, 0xFF6677]; }
        else if (type == TYPE_DZIKKO) { base = [0x4A3520, 0x8B6914, 0xF0F0F0, 0x2A1A10]; }
        else if (type == TYPE_POLACCO) { base = [0xF5CBA7, 0x3D2B1F, 0xDDDDDD, 0x222222]; }
        else if (type == TYPE_NOSACZ) { base = [0xA0522D, 0xDEB887, 0xE8A088, 0x3D2B1F]; }
        else if (type == TYPE_DONUT) { base = [0xF4A460, 0xFF69B4, 0x8B4513, 0x00FF00]; }
        else if (type == TYPE_CACTUSO) { base = [0x228B22, 0x32CD32, 0xFF69B4, 0x8B4513]; }
        else if (type == TYPE_PIXELBOT) { base = [0x808080, 0x00BFFF, 0x404040, 0xFF8C00]; }
        else if (type == TYPE_OCTAVIO) { base = [0x9B59B6, 0xBB8FCE, 0xF5CBA7, 0x6C3483]; }
        else if (type == TYPE_BATSY) { base = [0x2C2C2C, 0x4A4A4A, 0xFFD700, 0xFF6B9D]; }
        else if (type == TYPE_NUGGET) { base = [0xDAA520, 0xB8860B, 0xFFF8DC, 0xFF4444]; }
        else if (type == TYPE_FOCZKA) { base = [0x7A8EA0, 0xBBCCDD, 0x1A1A1A, 0x5D6D7E]; }
        else if (type == TYPE_RAINBOW) { base = [0xFFFFFF, 0xFF4488, 0x44BBFF, 0xFFDD44]; }
        else if (type == TYPE_DOGGO) { base = [0xC68642, 0xFFDFBA, 0x222222, 0xFF4444]; }
        else if (type == TYPE_UNDEAD) { base = [0x4A7A4A, 0x8FBF8F, 0xFF0000, 0x1A1A1A]; }
        else { base = [0x1B5E20, 0x388E3C, 0x66BB6A, 0xA5D6A7]; }
        if (paletteIdx > 0 && type == petType) { base = applyPalette(base, paletteIdx); }
        return base;
    }

    hidden function applyPalette(colors, idx) {
        var result = [0, 0, 0, 0];
        for (var i = 0; i < 4; i++) {
            var c = colors[i];
            var r = (c >> 16) & 0xFF;
            var g = (c >> 8) & 0xFF;
            var b = c & 0xFF;
            if (idx == 1) {
                r = r + 50; if (r > 255) { r = 255; }
                g = g + 15; if (g > 255) { g = 255; }
                b = b - 35; if (b < 0) { b = 0; }
            } else if (idx == 2) {
                b = b + 50; if (b > 255) { b = 255; }
                g = g + 20; if (g > 255) { g = 255; }
                r = r - 35; if (r < 0) { r = 0; }
            } else if (idx == 3) {
                r = r + (255 - r) / 3;
                g = g + (255 - g) / 3;
                b = b + (255 - b) / 3;
            } else if (idx == 4) {
                r = r * 2 / 3;
                g = g * 2 / 3;
                b = b * 2 / 3;
            }
            result[i] = (r << 16) | (g << 8) | b;
        }
        return result;
    }

    function getPaletteName(idx) {
        if (idx == 0) { return "Original"; }
        if (idx == 1) { return "Sunset"; }
        if (idx == 2) { return "Ocean"; }
        if (idx == 3) { return "Pastel"; }
        if (idx == 4) { return "Shadow"; }
        return "Original";
    }

    function getAccessoryName(acc) {
        if (acc == ACC_NONE) { return "None"; }
        if (acc == ACC_HAT) { return "Hat"; }
        if (acc == ACC_BOW) { return "Bow"; }
        if (acc == ACC_GLASSES) { return "Glasses"; }
        if (acc == ACC_CROWN) { return "Crown"; }
        if (acc == ACC_BANDANA) { return "Bandana"; }
        return "None";
    }

    hidden function bodyBlobby() { return [
        0,0,0,1,1,1,1,1,1,0,0,0, 0,0,1,3,3,3,3,3,3,1,0,0,
        0,1,3,3,2,2,2,2,2,2,1,0, 1,3,2,2,2,2,2,2,2,2,2,1,
        1,2,2,2,2,2,2,2,2,2,2,1, 1,2,2,2,2,2,2,2,2,2,2,1,
        1,2,2,2,2,4,4,2,2,2,2,1, 1,2,2,2,4,4,4,4,2,2,2,1,
        1,2,2,2,2,4,4,2,2,2,2,1, 0,1,2,2,2,2,2,2,2,2,1,0,
        0,0,1,2,2,2,2,2,2,1,0,0, 0,0,0,1,1,1,1,1,1,0,0,0]; }

    hidden function bodyFlamey() { return [
        0,0,4,0,0,0,0,0,0,4,0,0, 0,4,3,4,0,4,4,0,4,3,4,0,
        0,1,3,3,1,3,3,1,3,3,1,0, 1,3,2,2,2,2,2,2,2,2,3,1,
        1,2,2,2,2,2,2,2,2,2,2,1, 1,2,2,2,2,2,2,2,2,2,2,1,
        1,2,2,2,2,3,3,2,2,2,2,1, 1,2,2,2,2,2,2,2,2,2,2,1,
        1,2,2,2,2,2,2,2,2,2,2,1, 0,1,2,2,2,2,2,2,2,2,1,0,
        0,0,1,2,2,2,2,2,2,1,0,0, 0,0,0,1,1,1,1,1,1,0,0,0]; }

    hidden function bodyAqua() { return [
        0,0,0,0,0,1,1,0,0,0,0,0, 0,0,0,1,1,4,4,1,1,0,0,0,
        0,0,1,4,3,3,3,3,4,1,0,0, 0,1,3,2,2,2,2,2,2,3,1,0,
        1,2,2,2,2,2,2,2,2,2,2,1, 1,2,2,2,2,3,2,2,2,2,2,1,
        1,2,2,2,2,2,2,2,2,2,2,1, 1,2,2,2,2,2,2,3,2,2,2,1,
        1,2,2,2,2,2,2,2,2,2,2,1, 0,1,2,2,2,2,2,2,2,2,1,0,
        0,0,1,3,2,2,2,2,3,1,0,0, 0,0,0,1,1,1,1,1,1,0,0,0]; }

    hidden function bodyRocky() { return [
        0,1,1,1,1,1,1,1,1,1,1,0, 1,3,3,2,2,2,2,2,2,3,3,1,
        1,3,2,2,2,4,2,2,2,2,3,1, 1,2,2,2,2,2,2,2,2,2,2,1,
        1,2,2,4,2,2,2,2,4,2,2,1, 1,2,2,2,2,2,2,2,2,2,2,1,
        1,2,2,2,2,2,2,2,2,2,2,1, 1,2,2,2,2,4,2,2,2,2,2,1,
        1,2,2,2,2,2,2,4,2,2,2,1, 1,3,2,2,2,2,2,2,2,2,3,1,
        1,3,3,2,2,2,2,2,2,3,3,1, 0,1,1,1,1,1,1,1,1,1,1,0]; }

    hidden function bodyGhosty() { return [
        0,0,0,1,1,1,1,1,1,0,0,0, 0,0,1,3,3,3,3,3,3,1,0,0,
        0,1,3,2,2,2,2,2,2,3,1,0, 1,2,2,2,2,2,2,2,2,2,2,1,
        1,2,2,2,2,2,2,2,2,2,2,1, 1,2,2,2,2,4,4,2,2,2,2,1,
        1,2,2,2,2,2,2,2,2,2,2,1, 1,2,2,2,2,2,2,2,2,2,2,1,
        1,3,2,2,2,2,2,2,2,2,3,1, 1,2,0,2,2,3,3,2,2,0,2,1,
        0,1,0,1,3,0,0,3,1,0,1,0, 0,0,0,0,1,0,0,1,0,0,0,0]; }

    hidden function bodySparky() { return [
        0,0,4,0,0,0,0,0,0,4,0,0, 0,1,4,1,0,0,0,0,1,4,1,0,
        1,4,2,2,1,1,1,1,2,2,4,1, 0,1,2,2,2,2,2,2,2,2,1,0,
        1,4,2,2,2,2,2,2,2,2,4,1, 0,1,2,2,2,3,3,2,2,2,1,0,
        1,4,2,2,2,3,3,2,2,2,4,1, 0,1,2,2,2,2,2,2,2,2,1,0,
        1,4,2,2,2,2,2,2,2,2,4,1, 0,1,2,2,2,2,2,2,2,2,1,0,
        0,0,1,2,2,2,2,2,2,1,0,0, 0,0,0,1,1,1,1,1,1,0,0,0]; }

    hidden function bodyFrosty() { return [
        0,0,0,0,0,1,1,0,0,0,0,0, 0,0,0,0,1,4,4,1,0,0,0,0,
        0,0,0,1,4,3,3,4,1,0,0,0, 0,0,1,3,3,2,2,3,3,1,0,0,
        0,1,3,2,2,2,2,2,2,3,1,0, 1,3,2,2,2,2,2,2,2,2,3,1,
        1,2,2,2,2,4,4,2,2,2,2,1, 1,3,2,2,2,2,2,2,2,2,3,1,
        0,1,3,2,2,2,2,2,2,3,1,0, 0,0,1,3,3,2,2,3,3,1,0,0,
        0,0,0,1,4,3,3,4,1,0,0,0, 0,0,0,0,1,1,1,1,0,0,0,0]; }

    hidden function bodyShroomy() { return [
        0,0,1,1,1,1,1,1,1,1,0,0, 0,1,3,4,3,3,3,3,4,3,1,0,
        1,3,3,3,4,3,3,4,3,3,3,1, 1,1,1,1,1,1,1,1,1,1,1,1,
        0,1,2,2,2,2,2,2,2,2,1,0, 0,1,2,2,2,2,2,2,2,2,1,0,
        0,1,2,2,2,2,2,2,2,2,1,0, 0,1,2,2,2,2,2,2,2,2,1,0,
        0,1,2,2,2,2,2,2,2,2,1,0, 0,1,2,2,2,2,2,2,2,2,1,0,
        0,0,1,2,2,2,2,2,2,1,0,0, 0,0,0,1,1,1,1,1,1,0,0,0]; }

    hidden function bodyChikko() { return [
        0,0,0,0,2,2,2,0,0,0,0,0, 0,0,0,2,2,2,2,2,0,0,0,0,
        0,0,0,1,1,1,1,1,1,0,0,0, 0,0,1,1,1,1,1,1,1,1,0,0,
        0,1,1,1,1,1,1,1,1,1,1,0, 0,1,1,1,1,1,1,1,1,1,1,0,
        0,1,1,1,1,3,3,1,1,1,1,0, 0,0,1,1,3,3,3,3,1,1,0,0,
        0,0,0,1,1,1,3,1,1,0,0,0, 0,0,0,0,1,4,4,1,0,0,0,0,
        0,0,0,0,0,1,1,0,0,0,0,0, 0,0,0,0,0,1,0,0,0,0,0,0]; }

    hidden function bodyDzikko() { return [
        0,0,0,0,0,0,0,0,0,0,0,0, 0,2,0,0,0,0,0,0,0,0,2,0,
        0,0,2,1,1,1,1,1,1,2,0,0, 0,1,1,1,1,1,1,1,1,1,1,0,
        0,1,1,2,1,1,1,1,2,1,1,0, 0,1,1,1,1,1,1,1,1,1,1,0,
        3,1,1,1,1,1,1,1,1,1,1,3, 0,1,1,1,4,1,1,4,1,1,0,0,
        0,0,1,1,1,1,1,1,1,1,0,0, 0,0,0,1,1,1,1,1,1,0,0,0,
        0,0,0,0,1,1,1,1,0,0,0,0, 0,0,0,0,0,1,1,0,0,0,0,0]; }

    hidden function bodyVexor() { return [
        0,0,2,0,0,0,0,0,0,2,0,0, 0,0,2,1,0,0,0,0,1,2,0,0,
        0,0,0,1,1,1,1,1,1,0,0,0, 0,0,1,1,2,1,1,2,1,1,0,0,
        0,1,1,1,1,1,1,1,1,1,1,0, 0,1,1,1,1,1,1,1,1,1,1,0,
        0,1,1,1,1,1,1,1,1,1,1,0, 0,0,1,1,1,1,1,1,1,1,0,0,
        3,0,0,1,1,1,1,1,1,0,0,3, 3,3,0,0,1,1,1,1,0,0,3,3,
        0,3,0,0,0,1,1,0,0,0,3,0, 0,0,0,0,0,0,1,2,0,0,0,0]; }

    hidden function bodyPolacco() { return [
        0,0,0,0,0,0,0,0,0,0,0,0, 0,0,2,0,0,0,0,0,0,2,0,0,
        0,2,1,1,1,1,1,1,1,1,2,0, 0,1,1,1,1,1,1,1,1,1,1,0,
        0,1,4,4,1,1,1,1,4,4,1,0, 0,1,1,1,1,4,4,1,1,1,1,0,
        2,2,2,2,2,2,2,2,2,2,2,2, 0,2,2,2,1,1,1,1,2,2,2,0,
        0,0,1,1,1,1,1,1,1,1,0,0, 0,0,3,3,3,3,3,3,3,3,0,0,
        0,0,3,3,3,3,3,3,3,3,0,0, 0,0,0,3,3,3,3,3,3,0,0,0]; }

    hidden function bodyNosacz() { return [
        0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,1,1,1,1,1,1,0,0,0,
        0,0,1,1,1,1,1,1,1,1,0,0, 0,1,2,2,2,2,2,2,2,2,1,0,
        0,1,2,4,2,2,2,2,4,2,1,0, 0,1,2,2,2,3,3,2,2,2,1,0,
        0,1,2,2,3,3,3,3,2,2,1,0, 0,0,1,2,3,3,3,3,2,1,0,0,
        0,0,1,2,2,3,3,2,2,1,0,0, 0,0,0,2,4,4,4,4,2,0,0,0,
        0,0,0,0,1,1,1,1,0,0,0,0, 0,0,0,0,0,1,1,0,0,0,0,0]; }

    hidden function bodyDonut() { return [
        0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,2,2,2,2,2,2,0,0,0,
        0,0,2,2,4,2,4,2,4,2,0,0, 0,2,1,1,1,1,1,1,1,1,2,0,
        2,1,1,1,1,1,1,1,1,1,1,2, 2,1,1,1,0,0,0,0,1,1,1,2,
        2,1,1,0,0,0,0,0,0,1,1,2, 2,1,1,1,0,0,0,0,1,1,1,2,
        0,1,1,1,1,1,1,1,1,1,1,0, 0,0,1,1,1,1,1,1,1,1,0,0,
        0,0,0,1,1,1,1,1,1,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0]; }

    hidden function bodyCactuso() { return [
        0,0,0,0,0,3,0,0,0,0,0,0, 0,0,0,0,1,1,1,0,0,0,0,0,
        0,0,0,0,1,1,1,0,0,0,0,0, 0,2,0,0,1,1,1,0,0,2,0,0,
        0,1,1,0,1,1,1,0,1,1,0,0, 0,0,1,1,1,1,1,1,1,0,0,0,
        0,0,0,1,1,1,1,1,0,0,0,0, 0,0,0,1,1,1,1,1,0,0,0,0,
        0,0,0,1,1,1,1,1,0,0,0,0, 0,0,0,1,1,1,1,1,0,0,0,0,
        0,0,4,4,4,4,4,4,4,0,0,0, 0,0,4,4,4,4,4,4,4,0,0,0]; }

    hidden function bodyPixelbot() { return [
        0,0,0,0,0,3,0,0,0,0,0,0, 0,0,0,0,0,3,0,0,0,0,0,0,
        0,0,1,1,1,1,1,1,1,1,0,0, 0,0,1,2,2,1,1,2,2,1,0,0,
        0,0,1,2,2,1,1,2,2,1,0,0, 0,0,1,1,1,1,1,1,1,1,0,0,
        0,0,1,1,4,4,4,4,1,1,0,0, 0,0,1,1,1,1,1,1,1,1,0,0,
        0,0,0,3,1,1,1,1,3,0,0,0, 0,0,0,1,1,1,1,1,1,0,0,0,
        0,0,0,1,0,0,0,0,1,0,0,0, 0,0,0,1,0,0,0,0,1,0,0,0]; }

    hidden function bodyOctavio() { return [
        0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,1,1,1,1,1,1,0,0,0,
        0,0,1,1,1,1,1,1,1,1,0,0, 0,1,1,2,2,1,1,2,2,1,1,0,
        0,1,1,1,1,1,1,1,1,1,1,0, 0,1,1,1,1,1,1,1,1,1,1,0,
        1,0,1,0,1,1,1,1,0,1,0,1, 0,1,0,1,0,1,1,0,1,0,1,0,
        1,0,1,0,1,0,0,1,0,1,0,1, 0,1,0,1,0,0,0,0,1,0,1,0,
        0,0,0,3,0,0,0,0,3,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0]; }

    hidden function bodyBatsy() { return [
        0,0,0,0,3,3,3,3,0,0,0,0, 3,0,0,3,3,3,3,3,3,0,0,3,
        3,0,3,3,3,3,3,3,3,3,0,3, 3,3,3,3,1,1,1,1,3,3,3,3,
        0,3,3,1,1,1,1,1,1,1,3,0, 0,0,1,1,2,2,1,2,2,1,0,0,
        0,0,1,1,1,1,1,1,1,1,0,0, 0,0,1,1,4,1,1,4,1,1,0,0,
        0,0,0,1,1,1,1,1,1,0,0,0, 0,0,0,1,1,3,3,1,1,0,0,0,
        0,0,0,0,1,1,1,1,0,0,0,0, 0,0,0,0,0,1,1,0,0,0,0,0]; }

    hidden function bodyFoczka() { return [
        0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,1,1,1,1,1,1,0,0,0,
        0,0,1,1,1,1,1,1,1,1,0,0, 0,1,1,1,1,1,1,1,1,1,1,0,
        0,1,3,3,1,1,1,1,3,3,1,0, 3,1,1,1,1,3,3,1,1,1,1,3,
        0,1,1,1,2,2,2,2,1,1,1,0, 4,1,1,2,2,2,2,2,2,1,1,4,
        4,4,1,2,2,2,2,2,2,1,4,4, 0,0,1,1,2,2,2,2,1,1,0,0,
        0,0,0,1,1,1,1,1,1,0,0,0, 0,0,0,0,4,4,4,4,0,0,0,0]; }

    hidden function bodyRainbow() { return [
        0,0,0,0,4,4,4,0,0,0,0,0, 0,0,0,4,3,3,3,4,0,0,0,0,
        0,0,4,3,2,2,2,3,4,0,0,0, 0,0,1,1,1,1,1,1,1,0,0,0,
        0,1,1,1,1,1,1,1,1,1,1,0, 0,1,1,1,1,1,1,1,1,1,1,0,
        0,1,1,1,1,1,1,1,1,1,1,0, 0,0,1,1,1,1,1,1,1,1,0,0,
        0,0,0,1,1,1,1,1,1,0,0,0, 0,0,0,0,1,1,1,1,0,0,0,0,
        0,0,0,0,0,1,1,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0]; }

    hidden function bodyNugget() { return [
        0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,1,1,2,1,1,0,0,0,0, 0,0,1,2,1,1,1,2,1,0,0,0,
        0,1,1,1,1,1,1,1,1,1,0,0, 0,1,2,1,1,1,1,1,2,1,0,0,
        0,1,1,1,1,1,1,1,1,1,0,0, 0,1,1,2,1,1,1,2,1,1,0,0,
        0,0,1,1,1,1,1,1,1,0,0,0, 0,0,0,1,1,2,1,1,0,0,0,0,
        0,0,0,0,1,1,1,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0]; }

    hidden function bodyEmilka() { return [
        0,0,3,3,3,3,3,3,3,3,0,0, 0,3,3,2,3,3,3,3,2,3,3,0,
        3,3,2,1,1,1,1,1,1,2,3,3, 3,2,1,1,1,1,1,1,1,1,2,3,
        3,2,1,1,1,1,1,1,1,1,2,3, 3,2,1,4,1,1,1,1,4,1,2,3,
        3,2,1,1,1,1,1,1,1,1,2,3, 3,3,2,1,1,1,1,1,1,2,3,3,
        3,3,3,2,1,1,1,1,2,3,3,3, 3,2,3,3,0,0,0,0,3,3,2,3,
        0,3,2,3,0,0,0,0,3,2,3,0, 0,3,3,0,0,0,0,0,0,3,3,0]; }

    hidden function bodyDoggo() { return [
        0,0,2,2,0,0,0,0,2,2,0,0, 0,2,2,2,0,0,0,0,2,2,2,0,
        0,1,1,1,1,1,1,1,1,1,1,0, 0,1,4,4,1,1,1,1,4,4,1,0,
        0,1,1,1,1,1,1,1,1,1,1,0, 0,1,1,3,1,1,1,1,3,1,1,0,
        0,1,1,1,1,3,3,1,1,1,1,0, 0,0,1,1,1,3,3,1,1,1,0,0,
        0,0,1,1,1,1,1,1,1,1,0,0, 0,3,1,1,1,1,1,1,1,1,3,0,
        0,0,1,2,0,0,0,0,2,1,0,0, 0,0,0,0,0,0,0,0,0,0,0,0]; }

    hidden function bodyUndead() { return [
        0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,1,1,1,1,1,1,0,0,0,
        0,0,1,1,1,1,1,1,1,1,0,0, 0,1,1,3,3,1,1,3,3,1,1,0,
        0,1,1,4,4,1,1,4,4,1,1,0, 0,1,1,1,1,1,1,1,1,1,1,0,
        0,1,1,2,2,2,2,2,2,1,1,0, 0,0,1,2,1,1,1,1,2,1,0,0,
        0,0,0,1,1,1,1,1,1,0,0,0, 0,0,3,0,1,1,1,1,0,3,0,0,
        0,0,3,0,0,0,0,0,0,3,0,0, 0,0,0,0,0,0,0,0,0,0,0,0]; }
}
