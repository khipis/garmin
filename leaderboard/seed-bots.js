#!/usr/bin/env node
/**
 * Bitochi Leaderboard — Bot Seeder
 *
 * Populates all leaderboards with easy-to-beat bot entries so boards never
 * look empty for new real players.  All rows are tagged is_bot=1 and are
 * excluded from the private /stats?real=1 endpoint.
 *
 * Usage:
 *   LB_KEY=<your_key> node seed-bots.js
 *   LB_KEY=<your_key> node seed-bots.js --dry-run      # print only, no POST
 *   LB_KEY=<your_key> node seed-bots.js --game=serpent  # single game only
 */

const API   = 'https://api.bitochi.com/score';
const KEY   = process.env.LB_KEY;
const DRY   = process.argv.includes('--dry-run');
const ONLY  = (process.argv.find(a => a.startsWith('--game=')) || '').replace('--game=', '');

if (!KEY && !DRY) {
  console.error('ERROR: set LB_KEY env variable');
  process.exit(1);
}

// ── Bot personas ─────────────────────────────────────────────────────────────
// Short names (≤8 chars) that look like real Garmin watch names.
const BOTS = [
  { user: 'Marco',   country: 'IT' },
  { user: 'Lukas',   country: 'DE' },
  { user: 'Pawel',   country: 'PL' },
  { user: 'Anna',    country: 'FI' },
  { user: 'Tomasz',  country: 'PL' },
  { user: 'Elena',   country: 'ES' },
  { user: 'Nils',    country: 'NO' },
  { user: 'Hana',    country: 'CZ' },
  { user: 'Radu',    country: 'RO' },
  { user: 'Sven',    country: 'SE' },
  { user: 'Kira',    country: 'FR' },
  { user: 'Jakub',   country: 'SK' },
  { user: 'Marta',   country: 'HR' },
  { user: 'Mikkel',  country: 'DK' },
  { user: 'Olivia',  country: 'GB' },
  { user: 'Diego',   country: 'BR' },
  { user: 'Yuki',    country: 'JP' },
  { user: 'Igor',    country: 'UA' },
  { user: 'Clara',   country: 'NL' },
  { user: 'Felix',   country: 'AT' },
];

function rnd(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function pick(arr)      { return arr[Math.floor(Math.random() * arr.length)]; }

// ── Game catalogue ────────────────────────────────────────────────────────────
// Each entry: { game, variants, scores, asc }
//   variants : array of variant strings (empty string = no variant)
//   scores   : [min, max] for a SINGLE bot entry (easy-to-beat range)
//   asc      : true = lower is better (bot needs HIGH score to be beatable)
//   bots     : how many unique bot entries per variant (default 6)

const GAMES = [
  // ── Endless runners / reflexes ───────────────────────────────────────────
  { game: 'flappypidgeon',     variants: [''],          scores: [4, 12]   },
  { game: 'dinosaur',          variants: [''],          scores: [80, 250]  },
  { game: 'shadowclonerunner', variants: [''],          scores: [80, 220]  },
  { game: 'edgesurvivor',      variants: [''],          scores: [40, 130]  },
  { game: 'serpent',           variants: [''],          scores: [30, 120]  },
  { game: 'run',               variants: [''],          scores: [40, 150]  },
  { game: 'skyroll',           variants: ['Easy','Norm','Hard'],   scores: [80, 280] },
  { game: 'jumptower',         variants: [''],          scores: [80, 200]  },

  // ── Tower / builder ──────────────────────────────────────────────────────
  { game: 'stacktower',        variants: ['Slow','Norm','Fast'],   scores: [6, 14] },

  // ── Puzzle / casual ──────────────────────────────────────────────────────
  { game: 'gemmatch',          variants: [''],          scores: [180, 450] },
  { game: 'twentyfortyeight',  variants: [''],          scores: [400, 1800] },
  { game: 'hologrid',          variants: [''],          scores: [50, 200]  },
  { game: 'blocks',            variants: [''],          scores: [100, 500] },
  { game: 'bricks',            variants: [''],          scores: [100, 500] },
  { game: 'jazzball',          variants: [''],          scores: [8, 25]    },
  { game: 'gyromaze',          variants: ['Easy','Med','Hard'], scores: [1, 4] },
  { game: 'billiards',         variants: ['3-ball','8-ball','9-ball','snooker'], scores: [2, 6] },

  // ── Time-based (ASC — high bot score = easy to beat) ────────────────────
  { game: 'sudoku',  asc: true,
    variants: ['4x4-easy','4x4-medium','4x4-hard','9x9-easy','9x9-medium','9x9-hard'],
    scores: [280, 600] },
  { game: 'minesweeper', asc: true,
    variants: ['8x8','10x10','12x12','16x16','24x24','32x32'],
    scores: [180, 420] },
  { game: 'solitaire', asc: true,  variants: [''],  scores: [420, 900]  },
  { game: 'lightsout', asc: true,
    variants: ['3x3','4x4','5x5'],
    scores: [40, 90] },
  { game: 'akari',    asc: true,  variants: ['6x6','7x7'],  scores: [250, 540]  },
  { game: 'memo',     asc: true,
    variants: ['Easy','Normal','Hard'],
    scores: [40, 90] },

  // ── Minigolf / stroke games (ASC) ────────────────────────────────────────
  { game: 'minigolf',
    variants: ['easy', 'normal', 'hard'],
    scores: [1500, 4500] },

  // ── Arcade / action ──────────────────────────────────────────────────────
  { game: 'arcade',      variants: [''],          scores: [3, 10]    },
  { game: 'catapult',    variants: [''],          scores: [40, 130]  },
  { game: 'bomb',        variants: [''],          scores: [40, 130]  },
  { game: 'manpac',      variants: [''],          scores: [80, 280]  },
  { game: 'blobs',       variants: [''],          scores: [4, 14]    },
  { game: 'parachute',   variants: [''],          scores: [40, 140]  },
  { game: 'moon',        variants: [''],          scores: [80, 250]  },
  { game: 'pinballpro',
    variants: ['CLASSIC','NOVA','DERBY','STINGER','ECLIPSE'],
    scores: [800, 4000] },
  { game: 'pongpro',
    variants: ['Easy','Medium','Hard'],
    scores: [1, 3] },
  { game: 'pixelinvaders',
    variants: ['Easy','Normal','Hard'],
    scores: [100, 450] },
  { game: 'starcombat',
    variants: ['Easy','Norm','Hard'],
    scores: [80, 280] },
  { game: 'voidrocks',
    variants: ['Easy','Normal','Hard'],
    scores: [80, 400] },
  { game: 'starswarm',
    variants: ['Easy','Normal','Hard'],
    scores: [150, 480] },
  { game: 'sniperscope',
    variants: ['Easy','Norm','Hard'],
    scores: [40, 180] },
  { game: 'fish',        variants: [''],          scores: [40, 160]  },

  // ── Card / board games ───────────────────────────────────────────────────
  { game: 'blackjack',   variants: [''],          scores: [120, 280] },
  { game: 'poker',       variants: [''],          scores: [250, 700] },
  { game: 'diceroyale',
    variants: ['classic','quick','daily'],
    scores: [100, 220] },
  { game: 'makao_lite',
    variants: ['Easy','Med','Hard'],
    scores: [1, 3] },

  // ── Strategy / board ─────────────────────────────────────────────────────
  { game: 'checkers',
    variants: ['easy','medium','hard'],
    scores: [1, 3] },
  { game: 'chess',
    variants: ['easy','medium','hard'],
    scores: [1, 2] },
  { game: 'othello',
    variants: [''],
    scores: [8, 20] },
  { game: 'tictacpro',
    variants: ['Easy','Med','Hard'],
    scores: [1, 3] },
  { game: 'connectfour',
    variants: ['Easy','Med','Hard'],
    scores: [1, 3] },
  { game: 'hex_mini',
    variants: ['EASY','MED','HARD'],
    scores: [1, 3] },
  { game: 'dots_boxes',
    variants: ['easy','med','hard'],
    scores: [1, 3] },
  { game: 'morris_classic',
    variants: ['easy','med','hard'],
    scores: [1, 3] },

  // ── Hangman / word ───────────────────────────────────────────────────────
  // variant = category.toLower() + "-" + difficulty.toLower()
  // categories: animals, food, technology, sports
  // difficulties: easy, medium, hard
  { game: 'hangman',
    variants: [
      'animals-easy','animals-medium','animals-hard',
      'food-easy','food-medium','food-hard',
      'technology-easy','technology-medium','technology-hard',
      'sports-easy','sports-medium','sports-hard',
    ],
    scores: [1, 3] },

  // ── Boxing ───────────────────────────────────────────────────────────────
  { game: 'boxing',      variants: [''],          scores: [30, 120]  },

  // ── Archery ──────────────────────────────────────────────────────────────
  { game: 'archery',
    variants: ['Easy','Norm','Hard'],
    scores: [40, 140] },

  // ── Ski jump (per-hill leaderboard) ──────────────────────────────────────
  { game: 'skijump',
    variants: ['Zakopane','Innsbruck','Oberstdorf','Vikersund'],
    scores: [45, 85] },

  // ── Battleship (ASC — fewer shots = better) ──────────────────────────────
  { game: 'battleship', asc: true,
    variants: ['easy','medium','hard'],
    scores: [55, 80] },

  // ── Activity Board (real watch stats, higher-is-better) ──────────────────
  // Scores are purposely modest / easy-to-beat so real active users land
  // above them quickly. Units match what the watch submits:
  //   flex    — weighted composite (steps + floors*250 + vig*180 + …)
  //   steps   — steps today
  //   dist    — metres today
  //   vig     — vigorous intensity minutes this week
  //   elev    — metres climbed today
  //   floors  — floors climbed today
  //   kcal    — calories burned today
  //   active  — total active minutes this week
  { game: 'activityboard', variants: ['flex'],   scores: [8000,  22000], bots: 8 },
  { game: 'activityboard', variants: ['steps'],  scores: [3500,  7500],  bots: 8 },
  { game: 'activityboard', variants: ['dist'],   scores: [2800,  7200],  bots: 8 },
  { game: 'activityboard', variants: ['vig'],    scores: [20,    70],    bots: 8 },
  { game: 'activityboard', variants: ['elev'],   scores: [40,    180],   bots: 8 },
  { game: 'activityboard', variants: ['floors'], scores: [4,     14],    bots: 8 },
  { game: 'activityboard', variants: ['kcal'],   scores: [1200,  2200],  bots: 8 },
  { game: 'activityboard', variants: ['active'], scores: [50,    130],   bots: 8 },
];

// ── Submission logic ─────────────────────────────────────────────────────────
const delay = ms => new Promise(r => setTimeout(r, ms));

async function submit(entry) {
  if (DRY) {
    console.log('[DRY]', JSON.stringify(entry));
    return;
  }
  const resp = await fetch(API, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json', 'X-LB-Key': KEY },
    body:    JSON.stringify(entry),
  });
  const text = await resp.text();
  if (!resp.ok) {
    console.warn(`  WARN ${resp.status} ${entry.game}/${entry.variant} ${entry.user}: ${text}`);
  } else {
    console.log(`  OK   ${entry.game.padEnd(20)} v="${entry.variant.padEnd(12)}" u=${entry.user.padEnd(8)} s=${entry.score}`);
  }
}

async function run() {
  const total = { ok: 0, skip: 0 };

  for (const g of GAMES) {
    if (ONLY && g.game !== ONLY) continue;

    for (const variant of g.variants) {
      // Pick N distinct bots per variant (g.bots overrides default of 6)
      const bots = [...BOTS].sort(() => Math.random() - 0.5).slice(0, g.bots || 6);

      for (const bot of bots) {
        const score = rnd(g.scores[0], g.scores[1]);
        const entry = {
          game:    g.game,
          user:    bot.user,
          score,
          variant,
          country: bot.country,
          is_bot:  true,
        };

        await submit(entry);
        total.ok++;
        if (!DRY) await delay(550); // stay well under 20 req/10s rate limit
      }
    }
  }

  console.log(`\nDone. Submitted ${total.ok} bot entries.`);
}

run().catch(e => { console.error(e); process.exit(1); });
