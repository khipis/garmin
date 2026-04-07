using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;

enum {
    GS_READY,
    GS_PREVIEW,
    GS_ANGLE,
    GS_POWER,
    GS_FLIGHT,
    GS_HIT,
    GS_RESULT,
    GS_SHOP,
    GS_GAMEOVER
}

enum {
    PW_NONE,
    PW_MEGA,
    PW_FIRE,
    PW_TRIPLE,
    PW_PIERCE,
    PW_AMMO
}

const MAX_BLOCKS = 50;
const MAX_PARTS = 30;
const TRAIL_LEN = 14;

class BitochiCatapultView extends WatchUi.View {

    var gameState;

    hidden var _w;
    hidden var _h;

    hidden var _camX;
    hidden var _camTargetX;
    hidden var _worldScale;

    hidden var _catWX;
    hidden var _groundWY;

    hidden var _castleWX;

    hidden var _angle;
    hidden var _angleDir;
    hidden var _lockedAngle;
    hidden var _power;
    hidden var _powerDir;
    hidden var _lockedPower;

    hidden var _px;
    hidden var _py;
    hidden var _vx;
    hidden var _vy;
    hidden var _projAlive;
    hidden var _projColor;
    hidden var _maxAlt;

    hidden var _bx;
    hidden var _by;
    hidden var _bhp;
    hidden var _bkind;
    hidden var _numBlocks;
    hidden var _bw;

    hidden var _enemyWX;
    hidden var _enemyWY;
    hidden var _enemyVy;
    hidden var _enemyHp;
    hidden var _enemyMaxHp;
    hidden var _enemyColor;
    hidden var _enemyColor2;
    hidden var _enemyName;
    hidden var _enemyIdx;
    hidden var _enemyOnGround;

    hidden var _round;
    hidden var _shots;
    hidden var _totalShots;
    hidden var _score;
    hidden var _bestShots;
    hidden var _timer;
    hidden var _tick;
    hidden var _hitTick;
    hidden var _combo;

    hidden var _prtX;
    hidden var _prtY;
    hidden var _prtVx;
    hidden var _prtVy;
    hidden var _prtL;
    hidden var _prtC;

    hidden var _trailX;
    hidden var _trailY;
    hidden var _trailIdx;

    hidden var _wind;
    hidden var _windDisplay;
    hidden var _windGust;

    hidden var _shakeLeft;
    hidden var _shakeOx;
    hidden var _shakeOy;
    hidden var _hitEnemyDirect;
    hidden var _critHit;
    hidden var _beatGame;
    hidden var _resultTick;

    hidden var _debrisX;
    hidden var _debrisY;
    hidden var _debrisVx;
    hidden var _debrisVy;
    hidden var _debrisL;
    hidden var _debrisC;

    hidden var _flashTick;
    hidden var _previewTick;

    hidden var _skyC1;
    hidden var _skyC2;
    hidden var _skyC3;
    hidden var _groundC1;
    hidden var _groundC2;

    hidden var _gold;
    hidden var _shopSel;
    hidden var _activePow;
    hidden var _shopNames;
    hidden var _shopCosts;
    hidden var _shopPows;
    hidden var _roundGold;

    function initialize() {
        View.initialize();
        Math.srand(Time.now().value());

        var ds = System.getDeviceSettings();
        _w = ds.screenWidth;
        _h = ds.screenHeight;

        _catWX = 0.0;
        _groundWY = 200.0;
        _worldScale = 1.0;
        _bw = 12;

        _bx = new [MAX_BLOCKS];
        _by = new [MAX_BLOCKS];
        _bhp = new [MAX_BLOCKS];
        _bkind = new [MAX_BLOCKS];
        _prtX = new [MAX_PARTS];
        _prtY = new [MAX_PARTS];
        _prtVx = new [MAX_PARTS];
        _prtVy = new [MAX_PARTS];
        _prtL = new [MAX_PARTS];
        _prtC = new [MAX_PARTS];
        _trailX = new [TRAIL_LEN];
        _trailY = new [TRAIL_LEN];
        _debrisX = new [16];
        _debrisY = new [16];
        _debrisVx = new [16];
        _debrisVy = new [16];
        _debrisL = new [16];
        _debrisC = new [16];
        for (var i = 0; i < MAX_PARTS; i++) { _prtL[i] = 0; }
        for (var i = 0; i < 16; i++) { _debrisL[i] = 0; }

        _score = 0;
        _round = 0;
        _tick = 0;
        _combo = 0;
        _beatGame = false;
        _resultTick = 0;
        _flashTick = 0;
        _previewTick = 0;
        _bestShots = 99;
        _totalShots = 0;
        _enemyVy = 0.0;
        _enemyOnGround = true;

        _skyC1 = 0x1A3A6A; _skyC2 = 0x2A5A8A; _skyC3 = 0x4A7AAA;
        _groundC1 = 0x2A4828; _groundC2 = 0x3A6835;

        _gold = 0;
        _shopSel = 0;
        _activePow = PW_NONE;
        _roundGold = 0;

        _shopNames = ["MEGA BOMB", "FIRE SHOT", "PIERCER", "TRIPLE", "AMMO +3"];
        _shopCosts = [120, 180, 220, 250, 80];
        _shopPows = [PW_MEGA, PW_FIRE, PW_PIERCE, PW_TRIPLE, PW_AMMO];

        initRound();
    }

    hidden function initRound() {
        _round++;
        _shots = 4 + _round;
        if (_shots > 14) { _shots = 14; }
        _totalShots = 0;
        _windDisplay = (Math.rand().abs() % 19) - 9;
        _wind = _windDisplay.toFloat() * 0.018;
        _windGust = 0.0;

        _castleWX = 220.0 + (_round * 42).toFloat();
        if (_castleWX > 850.0) { _castleWX = 850.0; }

        _enemyIdx = _round - 1;
        if (_enemyIdx == 0)       { _enemyName = "GRUMBLOR";   _enemyColor = 0x44BB66; _enemyColor2 = 0x228844; _enemyMaxHp = 80; }
        else if (_enemyIdx == 1)  { _enemyName = "FLAMEPECK";  _enemyColor = 0xFF6622; _enemyColor2 = 0xCC4411; _enemyMaxHp = 120; }
        else if (_enemyIdx == 2)  { _enemyName = "TUSKLING";   _enemyColor = 0xBB8844; _enemyColor2 = 0x886633; _enemyMaxHp = 170; }
        else if (_enemyIdx == 3)  { _enemyName = "IRONHIDE";   _enemyColor = 0x8899BB; _enemyColor2 = 0x667799; _enemyMaxHp = 230; }
        else if (_enemyIdx == 4)  { _enemyName = "VEXOR";      _enemyColor = 0xDD2244; _enemyColor2 = 0xAA1133; _enemyMaxHp = 300; }
        else if (_enemyIdx == 5)  { _enemyName = "CRYSTALIS";  _enemyColor = 0xCC66EE; _enemyColor2 = 0x9944BB; _enemyMaxHp = 380; }
        else if (_enemyIdx == 6)  { _enemyName = "KING BATSO"; _enemyColor = 0x6644AA; _enemyColor2 = 0x443388; _enemyMaxHp = 460; }
        else if (_enemyIdx == 7)  { _enemyName = "MEGAVEX";    _enemyColor = 0xFF2222; _enemyColor2 = 0xCC0000; _enemyMaxHp = 550; }
        else if (_enemyIdx == 8)  { _enemyName = "FROSTFANG";  _enemyColor = 0x66CCFF; _enemyColor2 = 0x4488CC; _enemyMaxHp = 650; }
        else if (_enemyIdx == 9)  { _enemyName = "THORNVEX";   _enemyColor = 0x44AA44; _enemyColor2 = 0x228822; _enemyMaxHp = 760; }
        else if (_enemyIdx == 10) { _enemyName = "SANDWORM";   _enemyColor = 0xCCAA44; _enemyColor2 = 0xAA8822; _enemyMaxHp = 880; }
        else if (_enemyIdx == 11) { _enemyName = "CLOUDKING";  _enemyColor = 0xDDDDFF; _enemyColor2 = 0xAABBDD; _enemyMaxHp = 1000; }
        else if (_enemyIdx == 12) { _enemyName = "NECROS";     _enemyColor = 0x44AA66; _enemyColor2 = 0x226644; _enemyMaxHp = 1150; }
        else if (_enemyIdx == 13) { _enemyName = "PRISMADON";  _enemyColor = 0xFF88CC; _enemyColor2 = 0xDD66AA; _enemyMaxHp = 1300; }
        else if (_enemyIdx == 14) { _enemyName = "MAGMOTH";    _enemyColor = 0xFF4400; _enemyColor2 = 0xCC2200; _enemyMaxHp = 1500; }
        else                      { _enemyName = "DARKSTAR";   _enemyColor = 0x6622AA; _enemyColor2 = 0x441188; _enemyMaxHp = 1700; }
        _enemyHp = _enemyMaxHp;
        _enemyVy = 0.0;
        _enemyOnGround = true;

        applyTheme();
        buildCastle();
        resetShot();
        _camX = _catWX;
        _camTargetX = _catWX;
        gameState = GS_READY;
        _previewTick = 0;
    }

    hidden function applyTheme() {
        var t = (_round - 1) % 16;
        if (t == 0) {
            _skyC1 = 0x2255AA; _skyC2 = 0x4488CC; _skyC3 = 0x77BBEE;
            _groundC1 = 0x2A6828; _groundC2 = 0x4A8838;
        } else if (t == 1) {
            _skyC1 = 0x3A1A0A; _skyC2 = 0x6A3A1A; _skyC3 = 0x8A5A3A;
            _groundC1 = 0x4A3820; _groundC2 = 0x6A5830;
        } else if (t == 2) {
            _skyC1 = 0x0A0A2A; _skyC2 = 0x1A1A4A; _skyC3 = 0x2A2A5A;
            _groundC1 = 0x2A3828; _groundC2 = 0x3A4838;
        } else if (t == 3) {
            _skyC1 = 0x081828; _skyC2 = 0x0A2848; _skyC3 = 0x184868;
            _groundC1 = 0x0A3838; _groundC2 = 0x1A5858;
        } else if (t == 4) {
            _skyC1 = 0x2A0808; _skyC2 = 0x4A1010; _skyC3 = 0x6A2020;
            _groundC1 = 0x3A1818; _groundC2 = 0x5A2828;
        } else if (t == 5) {
            _skyC1 = 0x1A0A2A; _skyC2 = 0x2A1A4A; _skyC3 = 0x4A2A6A;
            _groundC1 = 0x28202A; _groundC2 = 0x48384A;
        } else if (t == 6) {
            _skyC1 = 0x050818; _skyC2 = 0x0A1028; _skyC3 = 0x141838;
            _groundC1 = 0x1A1A20; _groundC2 = 0x2A2A30;
        } else if (t == 7) {
            _skyC1 = 0x1A0808; _skyC2 = 0x3A1010; _skyC3 = 0x5A1818;
            _groundC1 = 0x2A1818; _groundC2 = 0x4A2828;
        } else if (t == 8) {
            _skyC1 = 0x88BBDD; _skyC2 = 0xAADDFF; _skyC3 = 0xCCEEFF;
            _groundC1 = 0xBBCCDD; _groundC2 = 0xDDEEFF;
        } else if (t == 9) {
            _skyC1 = 0x0A2A0A; _skyC2 = 0x1A3A1A; _skyC3 = 0x2A4A2A;
            _groundC1 = 0x1A3818; _groundC2 = 0x2A5828;
        } else if (t == 10) {
            _skyC1 = 0x886622; _skyC2 = 0xAA8844; _skyC3 = 0xCCAA66;
            _groundC1 = 0xAA9944; _groundC2 = 0xCCBB66;
        } else if (t == 11) {
            _skyC1 = 0x4488CC; _skyC2 = 0x66AAEE; _skyC3 = 0x88CCFF;
            _groundC1 = 0x99DDFF; _groundC2 = 0xBBEEFF;
        } else if (t == 12) {
            _skyC1 = 0x0A1A0A; _skyC2 = 0x142814; _skyC3 = 0x1A3818;
            _groundC1 = 0x222218; _groundC2 = 0x333328;
        } else if (t == 13) {
            _skyC1 = 0x1A1A4A; _skyC2 = 0x2A2A6A; _skyC3 = 0x4A4A8A;
            _groundC1 = 0x3A2848; _groundC2 = 0x5A4868;
        } else if (t == 14) {
            _skyC1 = 0x1A0808; _skyC2 = 0x3A0A0A; _skyC3 = 0x5A1515;
            _groundC1 = 0x2A1A10; _groundC2 = 0x4A2A18;
        } else {
            _skyC1 = 0x050510; _skyC2 = 0x0A0A18; _skyC3 = 0x141428;
            _groundC1 = 0x0A0A14; _groundC2 = 0x1A1A24;
        }
    }

    hidden function addBlock(wx, wy, kind) {
        if (_numBlocks >= MAX_BLOCKS) { return; }
        _bx[_numBlocks] = wx;
        _by[_numBlocks] = wy;
        _bkind[_numBlocks] = kind;
        _bhp[_numBlocks] = (kind == 1) ? 2 : 1;
        _numBlocks++;
    }

    hidden function buildCastle() {
        _numBlocks = 0;
        var cx = _castleWX;
        var gy = _groundWY;
        var bw = _bw.toFloat();

        var tier = _round;
        if (tier > 12) { tier = 12; }
        var cols = 3 + tier / 2;
        if (cols > 7) { cols = 7; }
        var rows = 2 + tier / 2;
        if (rows > 6) { rows = 6; }

        var startX = cx - (cols * bw) / 2.0;

        for (var r = 0; r < rows; r++) {
            var rc = cols - r / 2;
            if (rc < 2) { rc = 2; }
            var offX = startX + (cols - rc).toFloat() * bw / 2.0;
            for (var c = 0; c < rc; c++) {
                if (r > 0 && r < rows - 1 && c > 0 && c < rc - 1 && (c + r) % 3 == 0) { continue; }
                var rng = Math.rand().abs() % 100;
                var k = 0;
                if (rng < 10 + tier * 2) { k = 2; }
                else if (rng < 25 + tier * 3) { k = 1; }
                addBlock(offX + c.toFloat() * bw, gy - (r + 1).toFloat() * bw, k);
            }
        }

        if (tier >= 3) {
            for (var tr = 0; tr < rows + 1; tr++) {
                addBlock(startX - bw, gy - (tr + 1).toFloat() * bw, (tr % 3 == 0) ? 1 : 0);
                addBlock(startX + cols.toFloat() * bw, gy - (tr + 1).toFloat() * bw, (tr % 3 == 0) ? 1 : 0);
            }
        }

        if (tier >= 5) {
            var cw = cols - 2;
            if (cw < 2) { cw = 2; }
            var coff = startX + bw;
            for (var c = 0; c < cw; c++) {
                addBlock(coff + c.toFloat() * bw, gy - (rows + 1).toFloat() * bw, (c % 2 == 0) ? 1 : 2);
            }
        }

        _enemyWX = cx;
        _enemyWY = gy - (rows + 1).toFloat() * bw - bw * 1.5;
    }

    hidden function resetShot() {
        _angle = 45;
        _angleDir = 1;
        _power = 50;
        _powerDir = 1;
        _lockedAngle = 45;
        _lockedPower = 50;
        _projAlive = false;
        _hitTick = 0;
        _hitEnemyDirect = false;
        _critHit = false;
        _px = 0.0; _py = 0.0;
        _vx = 0.0; _vy = 0.0;
        _maxAlt = 0.0;
        _shakeLeft = 0; _shakeOx = 0; _shakeOy = 0;
        _trailIdx = 0;
        _flashTick = 0;
        for (var i = 0; i < TRAIL_LEN; i++) { _trailX[i] = 0.0; _trailY[i] = 0.0; }
        for (var i = 0; i < MAX_PARTS; i++) { _prtL[i] = 0; }
        for (var i = 0; i < 16; i++) { _debrisL[i] = 0; }

        var colors = [0x44DDFF, 0xFF4488, 0x44FF88, 0xFF8844, 0xFF44FF, 0x88FF44];
        _projColor = colors[Math.rand().abs() % 6];
    }

    function onShow() {
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 33, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); _timer = null; }
    }

    function onTick() as Void {
        _tick++;

        if (_shakeLeft > 0) {
            _shakeOx = (Math.rand().abs() % 9) - 4;
            _shakeOy = (Math.rand().abs() % 7) - 3;
            _shakeLeft--;
        } else { _shakeOx = 0; _shakeOy = 0; }

        if (_flashTick > 0) { _flashTick--; }

        if (gameState == GS_PREVIEW) {
            _previewTick++;
            if (_previewTick < 30) {
                _camTargetX = _catWX + (_castleWX - _catWX) * _previewTick.toFloat() / 30.0;
            } else if (_previewTick < 60) {
                _camTargetX = _castleWX;
            } else if (_previewTick < 90) {
                _camTargetX = _castleWX - (_castleWX - _catWX) * (_previewTick - 60).toFloat() / 30.0;
            } else {
                _camTargetX = _catWX;
                gameState = GS_ANGLE;
            }
        } else if (gameState == GS_ANGLE) {
            var spd = 2 + _round / 2;
            if (spd > 5) { spd = 5; }
            _angle += _angleDir * spd;
            if (_angle >= 78) { _angle = 78; _angleDir = -1; }
            if (_angle <= 15) { _angle = 15; _angleDir = 1; }
        } else if (gameState == GS_POWER) {
            var spd = 3 + _round / 2;
            if (spd > 6) { spd = 6; }
            _power += _powerDir * spd;
            if (_power >= 100) { _power = 100; _powerDir = -1; }
            if (_power <= 5) { _power = 5; _powerDir = 1; }
        } else if (gameState == GS_FLIGHT) {
            updateFlight();
            _camTargetX = _px;
        } else if (gameState == GS_HIT) {
            _hitTick++;
            updateParticles();
            updateDebris();
            updateEnemyPhysics();
            if (_hitTick >= 35) {
                if (_enemyHp <= 0) {
                    _beatGame = (_round >= 16);
                    _score += 200 + _shots * 60;
                    if (_totalShots < _bestShots) { _bestShots = _totalShots; }
                    _roundGold = 50 + _round * 20 + _shots * 15;
                    _gold += _roundGold;
                    gameState = GS_RESULT;
                    _resultTick = 0;
                } else if (_shots <= 0) {
                    _roundGold = 10 + _round * 5;
                    _gold += _roundGold;
                    gameState = GS_RESULT;
                    _resultTick = 0;
                } else {
                    resetShot();
                    gameState = GS_ANGLE;
                    _camTargetX = _catWX;
                }
            }
        } else if (gameState == GS_RESULT || gameState == GS_GAMEOVER || gameState == GS_SHOP) {
            _resultTick++;
        }

        var diff = _camTargetX - _camX;
        _camX += diff * 0.12;

        if (gameState == GS_FLIGHT || gameState == GS_HIT) {
            var dist = _castleWX - _catWX;
            var projProgress = (_px - _catWX) / dist;
            if (projProgress < 0.0) { projProgress = 0.0; }
            if (projProgress > 1.0) { projProgress = 1.0; }
            var targetScale = 0.35 + (1.0 - projProgress) * 0.25;
            _worldScale += (targetScale - _worldScale) * 0.08;
        } else if (gameState == GS_PREVIEW) {
            var targetScale = 0.32;
            _worldScale += (targetScale - _worldScale) * 0.06;
        } else {
            var targetScale = 0.55;
            _worldScale += (targetScale - _worldScale) * 0.1;
        }

        WatchUi.requestUpdate();
    }

    hidden function w2sx(wx) {
        return (_w / 2 + ((wx - _camX) * _worldScale).toNumber());
    }

    hidden function w2sy(wy) {
        return (_h * 72 / 100 + ((wy - _groundWY) * _worldScale).toNumber());
    }

    hidden function updateEnemyPhysics() {
        if (_enemyHp <= 0) { return; }
        var bwf = _bw.toFloat();
        var supported = false;
        var footY = _enemyWY + bwf * 1.5;

        if (footY >= _groundWY - 2.0) {
            supported = true;
            _enemyOnGround = true;
        } else {
            for (var i = 0; i < _numBlocks; i++) {
                if (_bhp[i] <= 0) { continue; }
                var bTop = _by[i];
                var bLeft = _bx[i] - bwf * 0.5;
                var bRight = _bx[i] + bwf * 1.5;
                if (_enemyWX >= bLeft && _enemyWX <= bRight) {
                    var diff = footY - bTop;
                    if (diff >= -3.0 && diff <= 5.0) {
                        supported = true;
                        break;
                    }
                }
            }
        }

        if (!supported) {
            _enemyOnGround = false;
            _enemyVy += 0.35;
            _enemyWY += _enemyVy;

            if (_enemyWY + bwf * 1.5 >= _groundWY) {
                _enemyWY = _groundWY - bwf * 1.5;
                _enemyVy = 0.0;
                _enemyOnGround = true;
                var fallDmg = 15 + _round * 5;
                _enemyHp -= fallDmg;
                _score += fallDmg;
                _shakeLeft += 6;
                doVibe(60, 100);
                spawnImpactParticles(_enemyWX, _groundWY, false);
            }
        } else {
            _enemyVy = 0.0;
        }
    }

    hidden function updateFlight() {
        if (!_projAlive) { return; }

        _windGust = _windGust * 0.95 + (Math.rand().abs() % 5 - 2).toFloat() * 0.002;

        var speed = Math.sqrt(_vx * _vx + _vy * _vy);
        var dragCoeff = 0.0004 + _round.toFloat() * 0.00003;
        if (dragCoeff > 0.001) { dragCoeff = 0.001; }
        var dragX = -dragCoeff * _vx * speed;
        var dragY = -dragCoeff * _vy * speed;

        _vx += _wind + _windGust + dragX;
        _vy += 0.28 + dragY;
        _px += _vx;
        _py += _vy;

        if (_py < _maxAlt) { _maxAlt = _py; }

        _trailX[_trailIdx] = _px;
        _trailY[_trailIdx] = _py;
        _trailIdx = (_trailIdx + 1) % TRAIL_LEN;

        if (_px > _castleWX + 200.0 || _py > _groundWY + 50.0 || _px < -100.0) {
            doHit(_px, _py);
            return;
        }

        if (_py >= _groundWY) {
            doHit(_px, _groundWY);
            return;
        }

        var bwf = _bw.toFloat();
        for (var i = 0; i < _numBlocks; i++) {
            if (_bhp[i] <= 0) { continue; }
            if (_px >= _bx[i] - 3.0 && _px <= _bx[i] + bwf + 3.0 &&
                _py >= _by[i] - 3.0 && _py <= _by[i] + bwf + 3.0) {
                doHit(_px, _py);
                return;
            }
        }

        if (_enemyHp > 0) {
            var dx = _px - _enemyWX;
            var dy = _py - _enemyWY;
            var er = bwf * 2.0;
            if (dx * dx + dy * dy < er * er) {
                var dmg = (speed * 18.0).toNumber();
                if (dmg < 20) { dmg = 20; }
                dmg = dmg * 2;
                _enemyHp -= dmg;
                _hitEnemyDirect = true;
                _critHit = true;
                _score += dmg * 2;
                doHit(_px, _py);
                return;
            }
        }
    }

    hidden function doHit(hx, hy) {
        _projAlive = false;
        _shots--;
        _totalShots++;
        gameState = GS_HIT;
        _hitTick = 0;
        _flashTick = 6;

        var splMul = 1.0;
        if (_activePow == PW_MEGA) { splMul = 2.2; }
        else if (_activePow == PW_FIRE) { splMul = 1.5; }
        var splR = _bw.toFloat() * 3.5 * splMul;
        var bwf = _bw.toFloat();
        var hitSomething = _hitEnemyDirect;

        for (var i = 0; i < _numBlocks; i++) {
            if (_bhp[i] <= 0) { continue; }
            var bcx = _bx[i] + bwf / 2.0;
            var bcy = _by[i] + bwf / 2.0;
            var dx = hx - bcx;
            var dy = hy - bcy;
            if (dx * dx + dy * dy < splR * splR) {
                var dmgToBlock = 1;
                if (_activePow == PW_MEGA) { dmgToBlock = 3; }
                else if (_activePow == PW_FIRE) { dmgToBlock = 2; }
                _bhp[i] -= dmgToBlock;
                if (_bhp[i] < 0) { _bhp[i] = 0; }
                hitSomething = true;
                if (_bhp[i] <= 0) {
                    _score += (_bkind[i] == 1) ? 20 : ((_bkind[i] == 2) ? 30 : 12);
                    if (_bkind[i] == 2 || _activePow == PW_FIRE) {
                        chainExplosion(_bx[i] + bwf / 2.0, _by[i] + bwf / 2.0);
                    }
                    spawnDebris(_bx[i] + bwf / 2.0, _by[i] + bwf / 2.0, _bkind[i]);
                }
            }
        }

        if (_enemyHp > 0 && !_hitEnemyDirect) {
            var enemySplR = splR * 2.5;
            if (_activePow == PW_PIERCE) { enemySplR = splR * 5.0; }
            var edx = hx - _enemyWX;
            var edy = hy - _enemyWY;
            if (edx * edx + edy * edy < enemySplR * enemySplR) {
                var dmg = 25 + _round * 4;
                if (_activePow == PW_PIERCE) { dmg = dmg * 3; }
                else if (_activePow == PW_MEGA) { dmg = dmg * 2; }
                _enemyHp -= dmg;
                _score += dmg;
                hitSomething = true;
            }
        }

        if (hitSomething) { _combo++; } else { _combo = 0; }

        spawnImpactParticles(hx, hy, _critHit || _activePow == PW_MEGA);
        var shk = _critHit ? 14 : 8;
        if (_activePow == PW_MEGA) { shk = 18; }
        _shakeLeft = shk;
        doVibe(_critHit ? 80 : 50, _critHit ? 250 : 150);

        if (_activePow != PW_NONE && _activePow != PW_AMMO) {
            _activePow = PW_NONE;
        }
    }

    hidden function chainExplosion(cx, cy) {
        var bwf = _bw.toFloat();
        var chainR = bwf * 4.0;
        for (var j = 0; j < _numBlocks; j++) {
            if (_bhp[j] <= 0) { continue; }
            var bcx = _bx[j] + bwf / 2.0;
            var bcy = _by[j] + bwf / 2.0;
            var dx = cx - bcx;
            var dy = cy - bcy;
            if (dx * dx + dy * dy < chainR * chainR) {
                _bhp[j]--;
                if (_bhp[j] <= 0) {
                    _score += 15;
                    spawnDebris(bcx, bcy, _bkind[j]);
                    if (_bkind[j] == 2) { chainExplosion(bcx, bcy); }
                }
            }
        }
        if (_enemyHp > 0) {
            var edx = cx - _enemyWX;
            var edy = cy - _enemyWY;
            if (edx * edx + edy * edy < chainR * chainR * 1.5) {
                _enemyHp -= 30;
                _score += 30;
            }
        }
        _shakeLeft += 4;
        spawnImpactParticles(cx, cy, false);
    }

    hidden function spawnDebris(wx, wy, kind) {
        for (var i = 0; i < 16; i++) {
            if (_debrisL[i] > 0) { continue; }
            _debrisX[i] = wx;
            _debrisY[i] = wy;
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var s = 0.8 + (Math.rand().abs() % 30).toFloat() / 10.0;
            _debrisVx[i] = s * Math.cos(a);
            _debrisVy[i] = -s * Math.sin(a) - 1.5;
            _debrisL[i] = 15 + Math.rand().abs() % 15;
            if (kind == 2) { _debrisC[i] = 0xFF4422; }
            else if (kind == 1) { _debrisC[i] = 0x8A5E3E; }
            else { _debrisC[i] = 0x99AABB; }
            break;
        }
    }

    hidden function updateDebris() {
        for (var i = 0; i < 16; i++) {
            if (_debrisL[i] <= 0) { continue; }
            _debrisVy[i] += 0.15;
            _debrisX[i] += _debrisVx[i];
            _debrisY[i] += _debrisVy[i];
            _debrisL[i]--;
        }
    }

    hidden function spawnImpactParticles(wx, wy, crit) {
        var palette;
        if (crit) {
            palette = [0xFFEE44, 0xFFFFFF, 0xFFCC00, 0xFFFFAA, 0xFFAA00, 0xFFDD66];
        } else {
            palette = [0xFF4422, 0xFF8833, 0xFFCC22, 0xFFFF66, 0xFF6622, 0xDD3311];
        }
        for (var i = 0; i < MAX_PARTS; i++) {
            _prtX[i] = wx;
            _prtY[i] = wy;
            var a = (Math.rand().abs() % 360).toFloat() * 3.14159 / 180.0;
            var s = 1.5 + (Math.rand().abs() % 60).toFloat() / 6.0;
            _prtVx[i] = s * Math.cos(a);
            _prtVy[i] = -s * Math.sin(a);
            _prtL[i] = 16 + Math.rand().abs() % 20;
            _prtC[i] = palette[Math.rand().abs() % 6];
        }
    }

    hidden function updateParticles() {
        for (var i = 0; i < MAX_PARTS; i++) {
            if (_prtL[i] <= 0) { continue; }
            _prtVy[i] += 0.15;
            _prtX[i] += _prtVx[i];
            _prtY[i] += _prtVy[i];
            _prtL[i]--;
        }
    }

    hidden function doVibe(intensity, duration) {
        if (Toybox has :Attention) {
            if (Toybox.Attention has :vibrate) {
                Toybox.Attention.vibrate([new Toybox.Attention.VibeProfile(intensity, duration)]);
            }
        }
    }

    function doAction() {
        if (gameState == GS_READY) {
            gameState = GS_PREVIEW;
            _previewTick = 0;
        } else if (gameState == GS_PREVIEW) {
            _previewTick = 90;
        } else if (gameState == GS_ANGLE) {
            _lockedAngle = _angle;
            gameState = GS_POWER;
        } else if (gameState == GS_POWER) {
            _lockedPower = _power;
            launchProjectile();
        } else if (gameState == GS_RESULT) {
            if (_enemyHp <= 0) {
                if (_round >= 16) {
                    _beatGame = true;
                    gameState = GS_GAMEOVER;
                    _resultTick = 0;
                } else {
                    gameState = GS_SHOP;
                    _shopSel = 5;
                    _resultTick = 0;
                }
            } else {
                _beatGame = false;
                gameState = GS_GAMEOVER;
                _resultTick = 0;
            }
        } else if (gameState == GS_SHOP) {
            shopBuy();
        } else if (gameState == GS_GAMEOVER) {
            _score = 0; _round = 0; _combo = 0; _beatGame = false; _bestShots = 99; _gold = 0;
            _activePow = PW_NONE;
            initRound();
        }
    }

    function doUp() {
        if (gameState == GS_SHOP) {
            _shopSel--;
            if (_shopSel < 0) { _shopSel = 5; }
        } else {
            doAction();
        }
    }

    function doDown() {
        if (gameState == GS_SHOP) {
            _shopSel++;
            if (_shopSel > 5) { _shopSel = 0; }
        } else {
            doAction();
        }
    }

    hidden function shopBuy() {
        if (_shopSel >= 5) {
            initRound();
            return;
        }
        var cost = _shopCosts[_shopSel];
        if (_gold >= cost) {
            _gold -= cost;
            var pow = _shopPows[_shopSel];
            if (pow == PW_AMMO) {
                _shots += 3;
            } else {
                _activePow = pow;
            }
            doVibe(40, 80);
            _shopSel = 5;
        } else {
            doVibe(20, 30);
        }
    }

    hidden function launchProjectile() {
        gameState = GS_FLIGHT;
        _projAlive = true;
        _hitEnemyDirect = false;
        _critHit = false;
        _trailIdx = 0;
        _maxAlt = _groundWY;

        var rad = _lockedAngle.toFloat() * 3.14159 / 180.0;
        var speed = 5.0 + _lockedPower.toFloat() * 12.0 / 100.0;
        _vx = speed * Math.cos(rad);
        _vy = -speed * Math.sin(rad);
        _px = _catWX + 30.0 * Math.cos(rad);
        _py = _groundWY - 25.0 - 30.0 * Math.sin(rad);

        if (_activePow == PW_MEGA) {
            _projColor = 0xFF4444;
        } else if (_activePow == PW_FIRE) {
            _projColor = 0xFF8800;
        } else if (_activePow == PW_PIERCE) {
            _projColor = 0x44DDFF;
        } else if (_activePow == PW_TRIPLE) {
            _projColor = 0xFFFF44;
        }
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();

        dc.setColor(0x0A0A1A, 0x0A0A1A);
        dc.clear();

        if (gameState == GS_READY) { drawReady(dc, _w, _h); return; }
        if (gameState == GS_GAMEOVER) { drawGameOver(dc, _w, _h); return; }
        if (gameState == GS_RESULT) { drawResult(dc, _w, _h); return; }
        if (gameState == GS_SHOP) { drawShop(dc, _w, _h); return; }

        drawScene(dc, _w, _h);

        if (_flashTick > 0) {
            dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(0, 0, _w, _h);
            dc.drawRectangle(1, 1, _w - 2, _h - 2);
        }
    }

    hidden function drawThemedBg(dc, w, gsy, ox, oy) {
        dc.setColor(_skyC1, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, gsy * 35 / 100);
        dc.setColor(_skyC2, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gsy * 35 / 100, w, gsy * 25 / 100);
        dc.setColor(_skyC3, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gsy * 60 / 100, w, gsy - gsy * 60 / 100);

        var t = (_round - 1) % 16;
        var i;
        var mx = 0;
        var my = 0;
        var ccx = 0;
        var ccy = 0;
        var g;
        var gc;
        var gh;
        var fc;

        if (t == 0) {
            dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 82 / 100 + ox, 14 + oy, 14);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 82 / 100 + ox, 14 + oy, 10);
            dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 82 / 100 + ox, 13 + oy, 6);
            for (i = 0; i < 8; i++) {
                mx = w * 82 / 100 + ox + ((18 * Math.cos((i * 45 + _tick * 2).toFloat() * 3.14159 / 180.0)).toNumber());
                my = 14 + oy + ((18 * Math.sin((i * 45 + _tick * 2).toFloat() * 3.14159 / 180.0)).toNumber());
                dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(mx, my, 2);
            }
            dc.setColor(0xFF66AA, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) {
                mx = (w * 20 / 100 + i * w * 25 / 100 + _tick * (i + 1)) % w;
                my = gsy * 30 / 100 + (i * 13 + _tick) % 20;
                dc.fillRectangle(mx + ox, my + oy, 3, 2);
                dc.fillRectangle(mx + ox + 1, my + oy - 1, 1, 1);
            }
        } else if (t == 1) {
            dc.setColor(0x221111, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[0, gsy], [w * 15 / 100 + ox, gsy * 30 / 100 + oy], [w * 30 / 100, gsy]]);
            dc.fillPolygon([[w * 25 / 100, gsy], [w * 50 / 100 + ox, gsy * 18 / 100 + oy], [w * 75 / 100, gsy]]);
            dc.fillPolygon([[w * 60 / 100, gsy], [w * 85 / 100 + ox, gsy * 35 / 100 + oy], [w, gsy]]);
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 50 / 100 + ox, gsy * 18 / 100 + oy - 2, 5);
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 50 / 100 + ox, gsy * 18 / 100 + oy, 3);
            dc.setColor(0xFF6622, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 6; i++) {
                mx = (i * 47 + _tick * 2) % w;
                my = gsy - 8 - (i * 19 + _tick) % (gsy > 2 ? gsy / 2 : 1);
                dc.fillRectangle(mx + ox, my + oy, 2, 2);
            }
        } else if (t == 2) {
            dc.setColor(0xEEEECC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 78 / 100 + ox, gsy * 18 / 100 + oy, 16);
            dc.setColor(0xDDDDBB, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 78 / 100 + ox, gsy * 18 / 100 + oy, 14);
            dc.setColor(_skyC1, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 78 / 100 + ox + 5, gsy * 18 / 100 + oy - 3, 13);
            dc.setColor(0x0A150A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(w * 10 / 100 + ox, gsy - 30 + oy, 3, 30);
            dc.fillCircle(w * 10 / 100 + ox + 1, gsy - 30 + oy, 8);
            dc.drawLine(w * 10 / 100 + ox - 5, gsy - 25 + oy, w * 10 / 100 + ox - 9, gsy - 5 + oy);
            dc.drawLine(w * 10 / 100 + ox + 7, gsy - 25 + oy, w * 10 / 100 + ox + 11, gsy - 5 + oy);
            dc.setColor(0xBBBBFF, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 8; i++) { dc.fillCircle((i * 37 + 12) % w + ox, (i * 11 + 4) % (gsy > 3 ? gsy / 3 : 1) + oy, 1); }
            dc.setColor(0x224433, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) {
                my = gsy - 4 + ((_tick + i * 9) % 6) - 3;
                dc.fillRectangle(w * i * 30 / 100 + ox, my + oy, w * 35 / 100, 2);
            }
        } else if (t == 3) {
            dc.setColor(0x113355, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(0, gsy * 40 / 100 + oy, w, gsy * 40 / 100 + oy + 2);
            dc.drawLine(0, gsy * 42 / 100 + oy, w, gsy * 42 / 100 + oy + 1);
            dc.setColor(0x224466, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 6; i++) {
                mx = (i * 53 + _tick) % w;
                my = (i * 29 + _tick / 3) % (gsy > 1 ? gsy : 1);
                dc.drawCircle(mx + ox, my + oy, 2 + i % 3);
            }
            dc.setColor(0x115533, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 5; i++) {
                mx = w * (10 + i * 18) / 100;
                dc.drawLine(mx + ox, gsy + oy, mx + ((_tick + i * 5) % 6) - 3 + ox, gsy - 20 + oy);
            }
            dc.setColor(0xFF8844, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) {
                mx = (i * 71 + _tick * 3) % w;
                dc.fillCircle(mx + ox, gsy - 12 + oy + (i * 3), 1);
            }
        } else if (t == 4) {
            dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) {
                mx = w * (18 + i * 30) / 100;
                my = gsy - 5 - ((_tick + i * 7) % 14);
                dc.fillRectangle(mx + ox, my + oy, 5, gsy - my);
                dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(mx + ox + 1, my + oy - 4, 3, 4);
                dc.setColor(0xFF2200, Graphics.COLOR_TRANSPARENT);
            }
            dc.setColor(0x660000, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(w * 30 / 100 + ox, gsy + oy, w * 36 / 100 + ox, gsy - 22 + oy);
            dc.drawLine(w * 65 / 100 + ox, gsy + oy, w * 58 / 100 + ox, gsy - 16 + oy);
            dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 50 / 100 + ox, gsy * 25 / 100 + oy, 8);
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 50 / 100 + ox, gsy * 25 / 100 + oy, 5);
        } else if (t == 5) {
            dc.setColor(0x331144, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 6; i++) {
                mx = w * (8 + i * 16) / 100;
                dc.fillPolygon([[mx - 4, 0], [mx, 16 + i * 5], [mx + 4, 0]]);
            }
            dc.setColor(0x442266, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w, 4);
            fc = (_tick % 6 < 3) ? 0xEEAAFF : 0xAA66DD;
            dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 5; i++) {
                mx = w * (15 + i * 18) / 100;
                my = gsy - 8 - i * 4;
                dc.fillPolygon([[mx - 3, my + 8], [mx, my], [mx + 3, my + 8]]);
                dc.setColor(0xFFCCFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(mx, my + 1, 1);
                dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
            }
        } else if (t == 6) {
            dc.setColor(0x050510, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(w * 4 / 100, gsy - 34, 8, 34);
            dc.fillRectangle(w * 2 / 100, gsy - 38, 12, 5);
            dc.fillRectangle(w * 14 / 100, gsy - 24, 6, 24);
            dc.fillRectangle(w * 7 / 100, gsy - 28, 18, 4);
            dc.fillPolygon([[w * 5 / 100, gsy - 38], [w * 8 / 100, gsy - 46], [w * 11 / 100, gsy - 38]]);
            dc.setColor(0xFFFF66, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(w * 7 / 100, gsy - 20, 2, 3);
            dc.fillRectangle(w * 11 / 100, gsy - 20, 2, 3);
            dc.fillRectangle(w * 15 / 100, gsy - 16, 2, 3);
            dc.setColor(0xBBBBEE, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 12; i++) { dc.fillCircle((i * 23 + 8) % w + ox, (i * 9 + 3) % (gsy > 3 ? gsy / 3 : 1) + oy, 1); }
            dc.setColor(0x111122, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) {
                mx = (w * 35 / 100 + i * w * 22 / 100 + _tick * (i + 1)) % w;
                my = gsy * 18 / 100 + i * 12;
                dc.drawLine(mx + ox - 4, my + oy + 2, mx + ox, my + oy);
                dc.drawLine(mx + ox, my + oy, mx + ox + 4, my + oy + 2);
            }
        } else if (t == 7) {
            dc.setColor(0x1A0808, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[0, 0], [w * 38 / 100, 0], [w * 28 / 100, gsy * 55 / 100], [0, gsy * 45 / 100]]);
            dc.fillPolygon([[w, 0], [w * 62 / 100, 0], [w * 72 / 100, gsy * 55 / 100], [w, gsy * 45 / 100]]);
            dc.setColor(0x110404, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 0, w * 5 / 100, gsy);
            dc.fillRectangle(w * 95 / 100, 0, w * 5 / 100, gsy);
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 5; i++) { dc.fillCircle(w * (33 + i * 8) / 100 + ox, gsy - 3 + oy, 2 + i % 2); }
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 42 / 100 + ox, gsy - 6 + oy, 3);
            dc.setColor(0x332211, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) {
                mx = w * (38 + i * 10) / 100;
                my = gsy * 30 / 100 + ((_tick + i * 11) % 18) - 9;
                dc.fillCircle(mx + ox, my + oy, 5 + i % 3);
            }
        } else if (t == 8) {
            dc.setColor(0xAADDFF, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 5; i++) {
                mx = w * (12 + i * 18) / 100;
                dc.fillPolygon([[mx - 4, gsy], [mx, gsy - 18 - i * 5], [mx + 4, gsy]]);
            }
            dc.setColor(0xCCEEFF, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 5; i++) {
                mx = w * (12 + i * 18) / 100;
                dc.fillPolygon([[mx - 2, gsy], [mx, gsy - 14 - i * 4], [mx + 2, gsy]]);
            }
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            my = gsy * 14 / 100 + ((_tick) % 6) - 3;
            dc.drawLine(w * 8 / 100 + ox, my + oy, w * 92 / 100 + ox, my + oy + ((_tick + 3) % 5) - 2);
            dc.setColor(0x22CCAA, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(w * 8 / 100 + ox, my + 9 + oy, w * 92 / 100 + ox, my + 9 + oy + ((_tick + 7) % 5) - 2);
            dc.setColor(0x44FFCC, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(w * 8 / 100 + ox, my + 18 + oy, w * 92 / 100 + ox, my + 18 + oy + ((_tick) % 4) - 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 8; i++) {
                mx = (i * 43 + _tick) % w;
                my = (i * 37 + _tick * 2) % (gsy > 1 ? gsy : 1);
                dc.fillCircle(mx + ox, my + oy, 1);
            }
        } else if (t == 9) {
            dc.setColor(0x082208, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) {
                mx = w * (6 + i * 38) / 100;
                dc.fillRectangle(mx + ox, gsy - 28 + oy, 5, 28);
                dc.fillCircle(mx + ox + 2, gsy - 32 + oy, 12 + i * 3);
            }
            dc.setColor(0x0A330A, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) {
                mx = w * (6 + i * 38) / 100;
                dc.fillCircle(mx + ox + 2, gsy - 32 + oy, 8 + i * 2);
            }
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) {
                mx = w * (6 + i * 38) / 100;
                dc.fillCircle(mx + ox + 2, gsy - 32 + oy, 2);
            }
            fc = (_tick % 4 < 2) ? 0xFFFF44 : 0xAAFF44;
            dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 7; i++) {
                mx = (i * 41 + _tick * 3) % w;
                my = gsy * 25 / 100 + (i * 23 + _tick) % (gsy > 2 ? gsy / 2 : 1);
                dc.fillCircle(mx + ox, my + oy, 1);
            }
        } else if (t == 10) {
            dc.setColor(0xCCBB66, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[w * 3 / 100, gsy], [w * 20 / 100, gsy - 35], [w * 37 / 100, gsy]]);
            dc.setColor(0xBBAA55, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[w * 3 / 100, gsy], [w * 20 / 100, gsy - 35], [w * 20 / 100, gsy]]);
            dc.setColor(0xDDCC77, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[w * 55 / 100, gsy], [w * 65 / 100, gsy - 20], [w * 75 / 100, gsy]]);
            dc.setColor(0xFFEE44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 82 / 100 + ox, 16 + oy, 16);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 82 / 100 + ox, 16 + oy, 12);
            dc.setColor(0xFFFFCC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 82 / 100 + ox, 15 + oy, 7);
        } else if (t == 11) {
            dc.setColor(0xFFEE88, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 5; i++) {
                mx = w * (i * 22 + 8) / 100;
                dc.drawLine(mx + ox, 0, mx + w * 4 / 100 + ox, gsy + oy);
                dc.drawLine(mx + ox + 1, 0, mx + w * 4 / 100 + ox + 1, gsy + oy);
            }
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 6; i++) {
                mx = (i * w / 5 + _tick / 3) % (w + 40) - 20;
                dc.fillCircle(mx + ox, gsy - 6 + oy, 14 + i * 2);
                dc.fillCircle(mx + 12 + ox, gsy - 4 + oy, 10 + i);
            }
            dc.setColor(0xEEF8FF, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 6; i++) {
                mx = (i * w / 5 + _tick / 3) % (w + 40) - 20;
                dc.fillCircle(mx + 5 + ox, gsy - 8 + oy, 8 + i);
            }
        } else if (t == 12) {
            dc.setColor(0x0A0A08, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(w * 6 / 100 + ox, gsy - 22 + oy, 3, 22);
            for (i = 0; i < 5; i++) {
                dc.drawLine(w * 7 / 100 + ox, gsy - 18 + oy, w * 7 / 100 + ox + 4 + i * 2, gsy - 12 + i * 4 + oy);
                dc.drawLine(w * 7 / 100 + ox, gsy - 16 + oy, w * 7 / 100 + ox - 3 - i, gsy - 10 + i * 3 + oy);
            }
            for (i = 0; i < 4; i++) {
                mx = w * (18 + i * 22) / 100;
                dc.fillRectangle(mx + ox, gsy - 12 + oy, 7, 12);
                dc.fillCircle(mx + ox + 3, gsy - 12 + oy, 4);
            }
            dc.setColor(0x115511, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx + ox + 3, gsy - 12 + oy, 2);
            dc.setColor(0x225522, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 4; i++) {
                my = gsy - 5 + ((_tick + i * 7) % 8) - 4;
                dc.fillRectangle(w * i * 25 / 100 + ox, my + oy, w * 25 / 100, 3);
            }
        } else if (t == 13) {
            fc = [0xFF0000, 0xFF8800, 0xFFFF00, 0x00FF00, 0x0088FF, 0x8800FF];
            for (i = 0; i < 6; i++) {
                dc.setColor(fc[i], Graphics.COLOR_TRANSPARENT);
                dc.drawLine(0, gsy - i * 4 + oy, w, gsy - 22 - i * 4 + oy);
                dc.drawLine(0, gsy - i * 4 + oy + 1, w, gsy - 22 - i * 4 + oy + 1);
            }
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 8; i++) {
                mx = (i * 37 + _tick * 4) % w;
                my = (i * 23 + _tick * 2) % (gsy > 1 ? gsy : 1);
                dc.fillCircle(mx + ox, my + oy, (_tick + i) % 3 == 0 ? 2 : 1);
            }
            dc.setColor(0xBBBBFF, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 10; i++) { dc.fillCircle((i * 29 + 7) % w + ox, (i * 13 + 2) % (gsy > 3 ? gsy / 3 : 1) + oy, 1); }
        } else if (t == 14) {
            dc.setColor(0x331111, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[0, gsy], [w * 18 / 100, gsy * 28 / 100], [w * 35 / 100, gsy]]);
            dc.fillPolygon([[w * 50 / 100, gsy], [w * 70 / 100, gsy * 22 / 100], [w * 90 / 100, gsy]]);
            dc.setColor(0xFF3300, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 18 / 100 + ox, gsy * 28 / 100 + oy - 3, 4);
            dc.fillCircle(w * 70 / 100 + ox, gsy * 22 / 100 + oy - 3, 5);
            dc.setColor(0xFF6600, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, gsy - 4, w, 4);
            dc.setColor(0xFF8800, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, gsy - 2, w, 2);
            dc.setColor(0x555544, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 10; i++) {
                mx = (i * 29 + _tick) % w;
                my = (i * 17 + _tick / 2) % (gsy > 100 ? gsy * 70 / 100 : 1);
                dc.fillRectangle(mx + ox, my + oy, 2, 1);
            }
        } else {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 20; i++) {
                dc.fillCircle((i * 17 + 5) % w + ox, (i * 11 + 3) % (gsy > 100 ? gsy * 85 / 100 : 1) + oy, (i % 5 == 0) ? 2 : 1);
            }
            dc.setColor(0xCCBBFF, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 4; i++) {
                mx = (i * 61 + _tick) % w;
                my = gsy * (20 + i * 15) / 100;
                dc.fillCircle(mx + ox, my + oy, 3);
            }
            dc.setColor(0x220044, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 40 / 100 + ox, gsy * 20 / 100 + oy, 22);
            dc.setColor(0x330066, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 40 / 100 + ox, gsy * 20 / 100 + oy, 18);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 40 / 100 + ox, gsy * 20 / 100 + oy, 13);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 40 / 100 + ox + 14, gsy * 20 / 100 + oy, 3);
            dc.setColor(0xFF44FF, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(w * 40 / 100 + ox, gsy * 20 / 100 + oy, 15);
            dc.drawCircle(w * 40 / 100 + ox, gsy * 20 / 100 + oy, 16);
        }

        if (t != 3 && t != 5 && t != 7 && t != 15) {
            for (i = 0; i < 4; i++) {
                ccx = ((_tick / 2 + i * 90) * (i + 1) / 3) % (w + 80) - 40;
                ccy = 10 + i * 12;
                dc.setColor(0xCCDDEE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ccx + 1 + ox, ccy + 2 + oy, 7);
                dc.setColor(0xDDE8F0, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ccx + ox, ccy + oy, 7);
                dc.fillCircle(ccx + 12 + ox, ccy + 1 + oy, 5);
                dc.fillCircle(ccx - 10 + ox, ccy + 2 + oy, 4);
                dc.setColor(0xEEF4FF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ccx - 3 + ox, ccy - 3 + oy, 3);
            }
        }

        dc.setColor(_groundC1, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gsy, w, _h - gsy);
        dc.setColor(_groundC2, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gsy, w, 3);
        dc.setColor(_groundC1, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gsy + 3, w, 2);

        for (g = 0; g < w; g += 5) {
            gc = (g % 3 == 0) ? _groundC2 : _groundC1;
            dc.setColor(gc, Graphics.COLOR_TRANSPARENT);
            gh = 3 + (g % 6);
            dc.drawLine(g, gsy + 5, g, gsy + 5 + gh);
            if (g % 10 == 0) { dc.drawLine(g + 1, gsy + 5, g - 1, gsy + 5 + gh); }
        }

        if (t == 0) {
            fc = [0xFF4488, 0xFFFF44, 0xFF88FF, 0x44BBFF, 0xFF8844];
            for (i = 0; i < 5; i++) {
                mx = w * (10 + i * 18) / 100;
                dc.setColor(0x226622, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(mx, gsy + 5, mx, gsy - 3);
                dc.setColor(fc[i], Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(mx, gsy - 4, 2);
            }
        } else if (t == 1) {
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(w * 18 / 100, gsy + 6, w * 36 / 100, gsy + 14);
            dc.drawLine(w * 50 / 100, gsy + 4, w * 68 / 100, gsy + 12);
        } else if (t == 2) {
            dc.setColor(0x334433, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 28 / 100, gsy + 8, 7);
            dc.fillCircle(w * 72 / 100, gsy + 10, 6);
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w * 28 / 100, gsy + 7, 1);
            dc.fillCircle(w * 72 / 100, gsy + 9, 1);
        } else if (t == 5) {
            dc.setColor(0xAA66DD, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 4; i++) {
                mx = w * (22 + i * 20) / 100;
                dc.fillPolygon([[mx - 2, gsy + 5], [mx, gsy - 3], [mx + 2, gsy + 5]]);
            }
        } else if (t == 8) {
            dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, gsy + 5, w, 4);
        } else if (t == 10) {
            dc.setColor(0xBBAA55, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 5; i++) {
                dc.drawLine(w * i * 20 / 100, gsy + 8 + i * 2, w * (i + 1) * 20 / 100, gsy + 6 + i * 2);
            }
        } else if (t == 12) {
            dc.setColor(0x333322, Graphics.COLOR_TRANSPARENT);
            for (i = 0; i < 3; i++) { dc.fillCircle(w * (20 + i * 30) / 100, gsy + 8, 3); }
        }
    }

    hidden function drawScene(dc, w, h) {
        var ox = _shakeOx;
        var oy = _shakeOy;
        var gsy = w2sy(_groundWY) + oy;

        drawThemedBg(dc, w, gsy, ox, oy);

        dc.setColor(0x556655, Graphics.COLOR_TRANSPARENT);
        for (var m = 100; m < _castleWX.toNumber() + 100; m += 100) {
            var mx = w2sx(m.toFloat()) + ox;
            if (mx > 5 && mx < w - 5) {
                dc.fillRectangle(mx, gsy - 3, 1, 6);
            }
        }

        var bwf = _bw.toFloat();
        for (var i = 0; i < _numBlocks; i++) {
            if (_bhp[i] <= 0) { continue; }
            var bsx = w2sx(_bx[i]) + ox;
            var bsy = w2sy(_by[i]) + oy;
            var bsw = (_bw.toFloat() * _worldScale).toNumber();
            if (bsw < 3) { bsw = 3; }
            if (bsx > w + 20 || bsx < -20) { continue; }

            var fillC;
            var highlC;
            if (_bkind[i] == 2) { fillC = 0xCC3322; highlC = 0xFF6644; }
            else if (_bkind[i] == 1) { fillC = 0x8A5E3E; highlC = 0xAA7E5E; }
            else { fillC = 0x667788; highlC = 0x8899AA; }
            dc.setColor(fillC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bsx, bsy, bsw, bsw);
            dc.setColor(highlC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bsx, bsy, bsw, 1);
            dc.fillRectangle(bsx, bsy, 1, bsw);
            dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(bsx, bsy, bsw, bsw);
            if (_bkind[i] == 1 && _bhp[i] == 1) {
                dc.setColor(0x332211, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(bsx + 1, bsy + 1, bsx + bsw - 1, bsy + bsw - 1);
            }
            if (_bkind[i] == 2) {
                dc.setColor((_tick % 6 < 3) ? 0xFFAA44 : 0xFF6622, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(bsx + bsw / 2, bsy + bsw / 2, 2);
            }
        }

        drawEnemy(dc, ox, oy);
        drawCatapult(dc, ox, oy);

        if (gameState == GS_POWER) {
            var trad = _lockedAngle.toFloat() * 3.14159 / 180.0;
            var tspd = 5.0 + _power.toFloat() * 12.0 / 100.0;
            var tvx = tspd * Math.cos(trad);
            var tvy = -tspd * Math.sin(trad);
            var tx = _catWX + 30.0 * Math.cos(trad);
            var ty = _groundWY - 25.0 - 30.0 * Math.sin(trad);
            dc.setColor(0x446688, Graphics.COLOR_TRANSPARENT);
            for (var t = 0; t < 120; t++) {
                tvx += _wind;
                tvy += 0.28;
                tx += tvx;
                ty += tvy;
                if (ty >= _groundWY || tx > _castleWX + 100.0 || tx < -50.0) { break; }
                if (t % 4 == 0) {
                    dc.fillRectangle(w2sx(tx) + ox, w2sy(ty) + oy, 2, 2);
                }
            }
        }

        if (_projAlive || (gameState == GS_HIT && _hitTick < 5)) {
            for (var k = 0; k < TRAIL_LEN; k++) {
                var idx = _trailIdx - 1 - k;
                if (idx < 0) { idx += TRAIL_LEN; }
                if (_trailX[idx] == 0.0 && _trailY[idx] == 0.0) { continue; }
                var tsx = w2sx(_trailX[idx]) + ox;
                var tsy = w2sy(_trailY[idx]) + oy;
                var c = (k < 2) ? 0xFFFF44 : ((k < 5) ? 0xFFAA22 : 0xFF6600);
                dc.setColor(c, Graphics.COLOR_TRANSPARENT);
                var sz = 3 - k / 5;
                if (sz < 1) { sz = 1; }
                dc.fillCircle(tsx, tsy, sz);
            }
        }

        if (_projAlive) {
            var psx = w2sx(_px) + ox;
            var psy = w2sy(_py) + oy;
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(psx, psy, 5);
            dc.setColor(_projColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(psx, psy, 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(psx - 1, psy - 2, 2, 1);
            dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(psx - 1, psy + 4, 2, 3);
            dc.setColor(0xFFFF66, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(psx - 2, psy + 3, 1, 2);
            dc.fillRectangle(psx + 2, psy + 3, 1, 2);
        }

        for (var i = 0; i < MAX_PARTS; i++) {
            if (_prtL[i] <= 0) { continue; }
            var psx = w2sx(_prtX[i]) + ox;
            var psy = w2sy(_prtY[i]) + oy;
            dc.setColor(_prtC[i], Graphics.COLOR_TRANSPARENT);
            var ps = (_prtL[i] > 12) ? 3 : ((_prtL[i] > 5) ? 2 : 1);
            dc.fillRectangle(psx, psy, ps, ps);
        }

        for (var i = 0; i < 16; i++) {
            if (_debrisL[i] <= 0) { continue; }
            var dsx = w2sx(_debrisX[i]) + ox;
            var dsy = w2sy(_debrisY[i]) + oy;
            dc.setColor(_debrisC[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dsx, dsy, 3, 3);
        }

        drawHUD(dc, w, h, ox, oy);
    }

    hidden function drawEnemy(dc, ox, oy) {
        if (_enemyHp <= 0) {
            drawDeadEnemy(dc, ox, oy);
            return;
        }
        var esx = w2sx(_enemyWX) + ox;
        var esy = w2sy(_enemyWY) + oy;
        var bwf = _bw.toFloat();
        var er = (bwf * 1.8 * _worldScale).toNumber();
        if (er < 6) { er = 6; }

        if (gameState == GS_HIT && _hitTick < 10) {
            esx += (_hitTick % 4 < 2) ? 3 : -3;
        }

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(esx + 2, esy + er + 2, er * 80 / 100);

        dc.setColor(_enemyColor2, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(esx, esy, er);
        dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(esx, esy - er / 6, er * 90 / 100);

        dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(esx, esy - er - er / 4, er * 70 / 100);
        dc.setColor(_enemyColor2, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(esx, esy - er - er / 4 + er / 5, er * 50 / 100);

        var eo = er / 3;
        if (eo < 2) { eo = 2; }
        var headY = esy - er - er / 4;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(esx - eo, headY - eo / 3, eo / 2 + 2);
        dc.fillCircle(esx + eo, headY - eo / 3, eo / 2 + 2);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(esx - eo + 1, headY - eo / 3, eo / 3 + 1);
        dc.fillCircle(esx + eo + 1, headY - eo / 3, eo / 3 + 1);

        if (_enemyIdx == 0) {
            dc.setColor(0x228844, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - eo, headY + eo / 2, eo * 2, 2);
        } else if (_enemyIdx == 1) {
            dc.setColor(0xFFDD00, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - 1, headY - er * 70 / 100 - 4, 2, 5);
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - 2, headY - er * 70 / 100 - 6, 4, 3);
            dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[esx - er / 2, headY + eo / 2], [esx, headY + eo], [esx + er / 2, headY + eo / 2]]);
        } else if (_enemyIdx == 2) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[esx - eo, headY + eo / 3], [esx - eo / 2, headY + eo], [esx - eo + 2, headY + eo / 3]]);
            dc.fillPolygon([[esx + eo - 2, headY + eo / 3], [esx + eo / 2, headY + eo], [esx + eo, headY + eo / 3]]);
        } else if (_enemyIdx == 3) {
            dc.setColor(0x99AABB, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - er - 2, esy - 2, 4, 4);
            dc.fillRectangle(esx + er - 2, esy - 2, 4, 4);
            dc.setColor(0x667799, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - eo, headY + eo / 2, eo * 2, 3);
        } else if (_enemyIdx == 4) {
            dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx - eo, headY - eo / 3, eo / 3 + 1);
            dc.fillCircle(esx + eo, headY - eo / 3, eo / 3 + 1);
            dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[esx - er / 2, headY - er * 60 / 100], [esx - er / 3, headY - er], [esx - er / 5, headY - er * 60 / 100]]);
            dc.fillPolygon([[esx + er / 5, headY - er * 60 / 100], [esx + er / 3, headY - er], [esx + er / 2, headY - er * 60 / 100]]);
        } else if (_enemyIdx == 5) {
            dc.setColor(0xEE88FF, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 6; sp++) {
                var sa = sp * 60 + _tick * 3;
                var srad = sa.toFloat() * 3.14159 / 180.0;
                var spx = esx + (er * 110 / 100 * Math.cos(srad)).toNumber();
                var spy = esy + (er * 110 / 100 * Math.sin(srad)).toNumber();
                dc.fillCircle(spx, spy, 2);
            }
        } else if (_enemyIdx == 6) {
            dc.setColor(0x443388, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[esx - er, headY - er / 2], [esx - er * 2, headY], [esx - er, headY + er / 3]]);
            dc.fillPolygon([[esx + er, headY - er / 2], [esx + er * 2, headY], [esx + er, headY + er / 3]]);
            dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx, headY - er * 70 / 100 - 3, 3);
        } else if (_enemyIdx == 7) {
            dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx - eo, headY - eo / 3, eo / 2);
            dc.fillCircle(esx + eo, headY - eo / 3, eo / 2);
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 8; sp++) {
                var sa = sp * 45 + _tick * 5;
                var srad = sa.toFloat() * 3.14159 / 180.0;
                var spx = esx + ((er + 4) * Math.cos(srad)).toNumber();
                var spy = esy + ((er + 4) * Math.sin(srad)).toNumber();
                dc.fillRectangle(spx, spy, 3, 3);
            }
        } else if (_enemyIdx == 8) {
            dc.setColor(0xAAEEFF, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 6; sp++) {
                var sa = sp * 60 + _tick * 2;
                var srad = sa.toFloat() * 3.14159 / 180.0;
                var spx = esx + ((er + 3) * Math.cos(srad)).toNumber();
                var spy = esy + ((er + 3) * Math.sin(srad)).toNumber();
                dc.fillPolygon([[spx - 2, spy + 3], [spx, spy - 3], [spx + 2, spy + 3]]);
            }
            dc.setColor(0x88DDFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - eo, headY + eo / 3, eo * 2, 2);
        } else if (_enemyIdx == 9) {
            dc.setColor(0x116611, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 8; sp++) {
                var sa = sp * 45;
                var srad = sa.toFloat() * 3.14159 / 180.0;
                var spx = esx + ((er + 2) * Math.cos(srad)).toNumber();
                var spy = esy + ((er + 2) * Math.sin(srad)).toNumber();
                dc.fillRectangle(spx - 1, spy - 1, 3, 3);
            }
            dc.setColor(0x88FF22, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx - eo, headY - eo / 3, eo / 3);
            dc.fillCircle(esx + eo, headY - eo / 3, eo / 3);
        } else if (_enemyIdx == 10) {
            dc.setColor(_enemyColor2, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 3; sp++) {
                dc.fillCircle(esx, esy + er / 2 + sp * er / 2, er * 60 / 100);
            }
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - 1, headY - er * 70 / 100 - 6, 2, 6);
            dc.fillRectangle(esx + 3, headY - er * 70 / 100 - 4, 2, 4);
        } else if (_enemyIdx == 11) {
            dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - eo, headY - er * 70 / 100 - 6, eo * 2, 4);
            dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(esx - eo + 1, headY - er * 70 / 100 - 5, eo * 2 - 2, 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 4; sp++) {
                var sa = sp * 90 + _tick * 2;
                var srad = sa.toFloat() * 3.14159 / 180.0;
                var spx = esx + ((er + 6) * Math.cos(srad)).toNumber();
                var spy = esy + ((er + 6) * Math.sin(srad)).toNumber();
                dc.fillCircle(spx, spy, 2);
            }
        } else if (_enemyIdx == 12) {
            dc.setColor(0x88FF44, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx - eo, headY - eo / 3, eo / 3 + 1);
            dc.fillCircle(esx + eo, headY - eo / 3, eo / 3 + 1);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(esx - eo / 2, headY + eo / 2, esx + eo / 2, headY + eo);
            dc.drawLine(esx + eo / 2, headY + eo / 2, esx - eo / 2, headY + eo);
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 4; sp++) {
                var spx = esx + (Math.rand().abs() % (er * 2)) - er;
                var spy = esy + (Math.rand().abs() % er) - er / 2;
                dc.fillCircle(spx, spy, 1);
            }
        } else if (_enemyIdx == 13) {
            var prc = [0xFF4488, 0xFFAA22, 0xFFFF44, 0x44FF88, 0x4488FF, 0xAA44FF];
            dc.setColor(prc[_tick % 6], Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(esx, esy, er + 3);
            dc.drawCircle(esx, esy, er + 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx - eo, headY - eo / 3, eo / 2 + 1);
            dc.fillCircle(esx + eo, headY - eo / 3, eo / 2 + 1);
        } else if (_enemyIdx == 14) {
            dc.setColor(0xFF6600, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[esx - er, esy - er / 3], [esx - er * 2, esy + er / 3], [esx - er, esy + er / 2]]);
            dc.fillPolygon([[esx + er, esy - er / 3], [esx + er * 2, esy + er / 3], [esx + er, esy + er / 2]]);
            dc.setColor(0xFF4400, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[esx - er - 2, esy - er / 4], [esx - er * 2 + 2, esy + er / 4], [esx - er, esy + er / 3]]);
            dc.fillPolygon([[esx + er + 2, esy - er / 4], [esx + er * 2 - 2, esy + er / 4], [esx + er, esy + er / 3]]);
            dc.setColor(0xFF0000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx - eo, headY - eo / 3, eo / 3 + 1);
            dc.fillCircle(esx + eo, headY - eo / 3, eo / 3 + 1);
        } else {
            dc.setColor(0x220044, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx, esy, er + 5);
            dc.setColor(0x330066, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx, esy, er + 3);
            dc.setColor(_enemyColor2, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx, esy, er);
            dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx, esy - er / 6, er * 90 / 100);
            dc.setColor(0xFF00FF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(esx - eo, headY - eo / 3, eo / 3 + 1);
            dc.fillCircle(esx + eo, headY - eo / 3, eo / 3 + 1);
            dc.setColor(0xAA44FF, Graphics.COLOR_TRANSPARENT);
            for (var sp = 0; sp < 6; sp++) {
                var sa = sp * 60 + _tick * 4;
                var srad = sa.toFloat() * 3.14159 / 180.0;
                var spx = esx + ((er + 6) * Math.cos(srad)).toNumber();
                var spy = esy + ((er + 6) * Math.sin(srad)).toNumber();
                dc.fillRectangle(spx - 1, spy - 1, 2, 2);
            }
        }

        dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
        var legOff = (_tick % 8 < 4) ? 2 : -2;
        dc.fillRectangle(esx - er / 2, esy + er - 2, er / 3, er / 2 + legOff);
        dc.fillRectangle(esx + er / 4, esy + er - 2, er / 3, er / 2 - legOff);

        var barW = er * 3;
        dc.setColor(0x440000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(esx - barW / 2, headY - er * 70 / 100 - 10, barW, 4);
        var hw = barW * _enemyHp / _enemyMaxHp;
        if (hw < 0) { hw = 0; }
        var hpC = (_enemyHp > _enemyMaxHp / 2) ? 0x44FF44 : ((_enemyHp > _enemyMaxHp / 4) ? 0xFFCC22 : 0xFF3333);
        dc.setColor(hpC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(esx - barW / 2, headY - er * 70 / 100 - 10, hw, 4);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(esx - barW / 2, headY - er * 70 / 100 - 10, barW, 4);
    }

    hidden function drawDeadEnemy(dc, ox, oy) {
        var esx = w2sx(_enemyWX) + ox;
        var esy = w2sy(_groundWY) + oy;
        var bwf = _bw.toFloat();
        var er = (bwf * 1.5 * _worldScale).toNumber();
        if (er < 4) { er = 4; }
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(esx, esy - er / 2, er);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(esx - er / 3, esy - er, esx - er / 3 - 3, esy - er - 3);
        dc.drawLine(esx - er / 3, esy - er, esx - er / 3 + 3, esy - er - 3);
        dc.drawLine(esx + er / 3, esy - er, esx + er / 3 - 3, esy - er - 3);
        dc.drawLine(esx + er / 3, esy - er, esx + er / 3 + 3, esy - er - 3);
    }

    hidden function drawCatapult(dc, ox, oy) {
        var csx = w2sx(_catWX) + ox;
        var csy = w2sy(_groundWY) + oy;
        var cs = (_worldScale * 12.0).toNumber();
        if (cs < 5) { cs = 5; }

        dc.setColor(0x442211, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(csx - cs * 3 / 2, csy - cs / 3, cs * 3, cs / 3 + 2);
        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(csx - cs * 3 / 2 + 1, csy - cs / 3 + 1, cs * 3 - 2, cs / 3);
        dc.setColor(0x664433, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(csx - cs * 3 / 2 + 2, csy - cs / 3 + 1, cs * 3 - 4, 1);

        dc.setColor(0x553311, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(csx - cs, csy + 2, cs / 3 + 1);
        dc.fillCircle(csx + cs, csy + 2, cs / 3 + 1);
        dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(csx - cs, csy + 1, cs / 3);
        dc.fillCircle(csx + cs, csy + 1, cs / 3);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(csx - cs, csy + 1, cs / 5);
        dc.fillCircle(csx + cs, csy + 1, cs / 5);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(csx - cs - 1, csy, 2, 1);
        dc.fillRectangle(csx + cs - 1, csy, 2, 1);

        dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT);
        var suppH = cs * 2;
        dc.fillRectangle(csx - 3, csy - suppH, 6, suppH - cs / 3);
        dc.setColor(0x664433, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(csx - 2, csy - suppH, 4, suppH - cs / 3);
        dc.setColor(0x775544, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(csx - 1, csy - suppH, 2, suppH - cs / 3);

        dc.setColor(0x443322, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(csx - cs, csy - suppH + 1, cs * 2, 4);
        dc.setColor(0x554433, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(csx - cs + 1, csy - suppH + 2, cs * 2 - 2, 2);

        dc.setColor(0x443322, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(csx - cs, csy - cs / 3, csx - 3, csy - suppH);
        dc.drawLine(csx + cs, csy - cs / 3, csx + 3, csy - suppH);

        var curAngle = (gameState == GS_ANGLE) ? _angle : _lockedAngle;
        if (gameState == GS_FLIGHT || gameState == GS_HIT) { curAngle = 10; }
        var rad = curAngle.toFloat() * 3.14159 / 180.0;
        var armLen = cs * 3;
        var tipX = csx + (armLen.toFloat() * Math.cos(rad)).toNumber();
        var tipY = csy - suppH + (-(armLen.toFloat()) * Math.sin(rad)).toNumber();

        dc.setColor(0x664422, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(csx, csy - suppH, tipX, tipY);
        dc.setPenWidth(1);
        dc.setColor(0x886644, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(csx, csy - suppH, tipX, tipY);
        dc.setPenWidth(1);
        dc.setColor(0xAA8866, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(csx + 1, csy - suppH + 1, tipX + 1, tipY + 1);

        dc.setColor(0x775533, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(csx, csy - suppH, 4);
        dc.setColor(0x886644, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(csx, csy - suppH, 3);
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(csx, csy - suppH, 1);

        if (gameState == GS_ANGLE || gameState == GS_POWER || gameState == GS_PREVIEW) {
            dc.setColor(0x553322, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tipX - 4, tipY - 2, 8, 5);
            dc.setColor(0x664433, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tipX - 3, tipY - 1, 6, 3);

            dc.setColor(_projColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tipX, tipY - 5, 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tipX - 1, tipY - 7, 2, 1);
        }
    }

    hidden function drawHUD(dc, w, h, ox, oy) {
        dc.setColor(0xDDEEFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 3, Graphics.FONT_XTINY, "R" + _round + " " + _enemyName, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 4, 3, Graphics.FONT_XTINY, "" + _score, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 4, 16, Graphics.FONT_XTINY, _gold + "g", Graphics.TEXT_JUSTIFY_RIGHT);
        if (_activePow != PW_NONE && _activePow != PW_AMMO) {
            var pwC = 0xFF4444;
            var pwN = "M";
            if (_activePow == PW_FIRE) { pwC = 0xFF8800; pwN = "F"; }
            else if (_activePow == PW_PIERCE) { pwC = 0x44DDFF; pwN = "P"; }
            else if (_activePow == PW_TRIPLE) { pwC = 0xFFFF44; pwN = "T"; }
            dc.setColor(pwC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, 14, Graphics.FONT_XTINY, "[" + pwN + "]", Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_combo > 1) {
            dc.setColor(0xFF66FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 4, 28, Graphics.FONT_XTINY, "x" + _combo, Graphics.TEXT_JUSTIFY_RIGHT);
        }

        var wt = "W:";
        if (_windDisplay > 0) { wt += ">>"; }
        else if (_windDisplay < 0) { wt += "<<"; }
        else { wt += "--"; }
        dc.setColor(0xAACCFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(4, 3, Graphics.FONT_XTINY, wt, Graphics.TEXT_JUSTIFY_LEFT);

        for (var i = 0; i < _shots; i++) {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w / 2 - (_shots - 1) * 7 / 2 + i * 7, h - 10, 3);
        }

        if (gameState == GS_FLIGHT && _projAlive) {
            var alt = (_groundWY - _py).toNumber();
            if (alt < 0) { alt = 0; }
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(4, h - 22, Graphics.FONT_XTINY, "H:" + alt, Graphics.TEXT_JUSTIFY_LEFT);
            var dist = _px.toNumber();
            dc.drawText(4, h - 12, Graphics.FONT_XTINY, "D:" + dist, Graphics.TEXT_JUSTIFY_LEFT);
        }

        if (gameState == GS_PREVIEW) {
            var flash = (_previewTick % 10 < 5) ? 0xFFFFFF : 0x88CCFF;
            dc.setColor(flash, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 85 / 100, Graphics.FONT_XTINY, "SCOUTING...", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 92 / 100, Graphics.FONT_XTINY, "Dist: " + _castleWX.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (gameState == GS_ANGLE) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_SMALL, _angle + "°", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 92 / 100, Graphics.FONT_XTINY, "SET ANGLE", Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (gameState == GS_POWER) {
            var barX = w * 82 / 100;
            var barY = h * 20 / 100;
            var barH = h * 55 / 100;
            dc.setColor(0x222233, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, 8, barH);
            var fillH = barH * _power / 100;
            var c = (_power > 75) ? 0xFF4422 : ((_power > 40) ? 0xFFCC22 : 0x44FF88);
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY + barH - fillH, 8, fillH);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(barX + 4, barY - 14, Graphics.FONT_XTINY, "" + _power, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 92 / 100, Graphics.FONT_XTINY, "SET POWER", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawReady(dc, w, h) {
        dc.setColor(_skyC1, _skyC1);
        dc.clear();

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 8 / 100, Graphics.FONT_MEDIUM, "ROUND " + _round, Graphics.TEXT_JUSTIFY_CENTER);

        var r = w * 14 / 100;
        if (r < 12) { r = 12; }
        var cy = h * 38 / 100;

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2 + 2, cy + r + 2, r * 80 / 100);

        dc.setColor(_enemyColor2, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, cy, r);
        dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, cy - r / 6, r * 88 / 100);

        dc.setColor(_enemyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, cy - r - r / 4, r * 65 / 100);

        var eo = r / 3;
        var headY = cy - r - r / 4;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2 - eo, headY - eo / 3, eo / 2 + 2);
        dc.fillCircle(w / 2 + eo, headY - eo / 3, eo / 2 + 2);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2 - eo + 1, headY - eo / 3, eo / 3 + 1);
        dc.fillCircle(w / 2 + eo + 1, headY - eo / 3, eo / 3 + 1);

        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 55 / 100, Graphics.FONT_SMALL, "vs " + _enemyName, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF6666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 66 / 100, Graphics.FONT_XTINY, "HP:" + _enemyMaxHp + " Dist:" + _castleWX.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAACCFF, Graphics.COLOR_TRANSPARENT);
        var wl = "Wind:" + ((_windDisplay >= 0) ? "+" : "") + _windDisplay;
        dc.drawText(w / 2, h * 74 / 100, Graphics.FONT_XTINY, wl, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 86 / 100, Graphics.FONT_XTINY, "Press to scout", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawResult(dc, w, h) {
        dc.setColor(_skyC1, _skyC1);
        dc.clear();

        var cleared = _enemyHp <= 0;
        var flash = (_resultTick % 8 < 4);
        if (cleared) {
            dc.setColor(flash ? 0x44FF88 : 0x22CC66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_MEDIUM, "VICTORY!", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(flash ? 0xFF6644 : 0xCC4422, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_MEDIUM, "DEFEATED", Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 28 / 100, Graphics.FONT_SMALL, "Score: " + _score, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 42 / 100, Graphics.FONT_XTINY, "+" + _roundGold + " gold", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 50 / 100, Graphics.FONT_XTINY, "Total: " + _gold + " gold", Graphics.TEXT_JUSTIFY_CENTER);

        if (cleared) {
            dc.setColor(0x44FF88, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 60 / 100, Graphics.FONT_XTINY, _enemyName + " down! " + _totalShots + " shots", Graphics.TEXT_JUSTIFY_CENTER);
            if (_totalShots <= _bestShots) {
                dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, h * 68 / 100, Graphics.FONT_XTINY, "NEW RECORD!", Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else {
            dc.setColor(0xFF6644, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 60 / 100, Graphics.FONT_XTINY, _enemyName + " HP: " + _enemyHp, Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_XTINY, "Press to continue", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawShop(dc, w, h) {
        dc.setColor(0x0A0A18, 0x0A0A18);
        dc.clear();

        dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 5 / 100, Graphics.FONT_SMALL, "SHOP", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFAA22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 15 / 100, Graphics.FONT_XTINY, "Gold: " + _gold, Graphics.TEXT_JUSTIFY_CENTER);

        var startY = h * 24 / 100;
        var rowH = h * 11 / 100;

        for (var i = 0; i < 5; i++) {
            var iy = startY + i * rowH;
            var sel = (i == _shopSel);
            var afford = (_gold >= _shopCosts[i]);

            if (sel) {
                var selC = afford ? 0x1A2A3A : 0x2A1A1A;
                dc.setColor(selC, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(w * 8 / 100, iy - 1, w * 84 / 100, rowH - 2);
                dc.setColor(afford ? 0x44AAFF : 0x664444, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(w * 8 / 100, iy - 1, w * 84 / 100, rowH - 2);
            }

            var nameC = afford ? 0xDDEEFF : 0x555555;
            if (sel && afford) { nameC = 0xFFFFFF; }
            dc.setColor(nameC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 12 / 100, iy + 1, Graphics.FONT_XTINY, _shopNames[i], Graphics.TEXT_JUSTIFY_LEFT);

            var costC = afford ? 0xFFDD44 : 0x554422;
            dc.setColor(costC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 88 / 100, iy + 1, Graphics.FONT_XTINY, "" + _shopCosts[i], Graphics.TEXT_JUSTIFY_RIGHT);
        }

        var exitY = startY + 5 * rowH;
        var exitSel = (_shopSel == 5);
        if (exitSel) {
            dc.setColor(0x1A3A1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(w * 8 / 100, exitY - 1, w * 84 / 100, rowH - 2);
            dc.setColor(0x44FF44, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(w * 8 / 100, exitY - 1, w * 84 / 100, rowH - 2);
        }
        dc.setColor(exitSel ? 0x44FF88 : 0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, exitY + 1, Graphics.FONT_XTINY, "NEXT ROUND >>", Graphics.TEXT_JUSTIFY_CENTER);

        if (_activePow != PW_NONE && _activePow != PW_AMMO) {
            dc.setColor(0x88FF88, Graphics.COLOR_TRANSPARENT);
            var pn = "?";
            if (_activePow == PW_MEGA) { pn = "MEGA"; }
            else if (_activePow == PW_FIRE) { pn = "FIRE"; }
            else if (_activePow == PW_PIERCE) { pn = "PIERCER"; }
            else if (_activePow == PW_TRIPLE) { pn = "TRIPLE"; }
            dc.drawText(w / 2, h * 90 / 100, Graphics.FONT_XTINY, "Loaded: " + pn, Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x556677, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 96 / 100, Graphics.FONT_XTINY, "Scroll to buy, Tap OK", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawGameOver(dc, w, h) {
        dc.setColor(0x0A0A1A, 0x0A0A1A);
        dc.clear();

        var flash = (_resultTick % 10 < 5);
        dc.setColor(flash ? 0xFFFFFF : 0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_MEDIUM, _beatGame ? "YOU WIN!" : "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 30 / 100, Graphics.FONT_MEDIUM, "" + _score, Graphics.TEXT_JUSTIFY_CENTER);
        var grade;
        if (_score >= 12000) { grade = "LEGENDARY!"; }
        else if (_score >= 8000) { grade = "MASTER!"; }
        else if (_score >= 5000) { grade = "GREAT!"; }
        else if (_score >= 2500) { grade = "GOOD"; }
        else { grade = "TRY AGAIN"; }
        dc.setColor(0x44FFCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 48 / 100, Graphics.FONT_SMALL, grade, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_XTINY, "Rounds: " + _round, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x88AACC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_XTINY, "Press to restart", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
