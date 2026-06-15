#!/usr/bin/env node
/**
 * Bitochi — Bot Seed CORRECTIONS
 *
 * Seeds the correct variants for all games where seed-bots.js used wrong
 * variant strings.  Safe to re-run: adds new rows, doesn't touch existing ones.
 *
 * Usage:  LB_KEY=<key> node seed-bots-fix.js
 *         LB_KEY=<key> node seed-bots-fix.js --dry-run
 *         LB_KEY=<key> node seed-bots-fix.js --game=skyroll
 */

const API  = 'https://api.bitochi.com/score';
const KEY  = process.env.LB_KEY;
const DRY  = process.argv.includes('--dry-run');
const ONLY = (process.argv.find(a => a.startsWith('--game=')) || '').replace('--game=', '');

if (!KEY && !DRY) { console.error('ERROR: set LB_KEY env variable'); process.exit(1); }

const BOTS = [
  { user: 'Marco',  country: 'IT' }, { user: 'Lukas',  country: 'DE' },
  { user: 'Pawel',  country: 'PL' }, { user: 'Anna',   country: 'FI' },
  { user: 'Tomasz', country: 'PL' }, { user: 'Elena',  country: 'ES' },
  { user: 'Nils',   country: 'NO' }, { user: 'Hana',   country: 'CZ' },
  { user: 'Radu',   country: 'RO' }, { user: 'Sven',   country: 'SE' },
  { user: 'Kira',   country: 'FR' }, { user: 'Jakub',  country: 'SK' },
  { user: 'Marta',  country: 'HR' }, { user: 'Mikkel', country: 'DK' },
  { user: 'Olivia', country: 'GB' }, { user: 'Diego',  country: 'BR' },
  { user: 'Yuki',   country: 'JP' }, { user: 'Igor',   country: 'UA' },
  { user: 'Clara',  country: 'NL' }, { user: 'Felix',  country: 'AT' },
];

function rnd(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }

// ── Corrections: games → correct variants → score ranges ──────────────────────
// asc: true means lower = better (bot should have HIGH score to be easy to beat)
const FIXES = [
  // "Norm" instead of "Normal"
  { game: 'skyroll',    variants: ['Norm'],              scores: [80,  280] },
  { game: 'archery',    variants: ['Norm'],              scores: [40,  140] },
  { game: 'starcombat', variants: ['Norm'],              scores: [80,  280] },
  { game: 'sniperscope',variants: ['Norm'],              scores: [40,  180] },

  // stacktower: was "Easy/Normal/Hard", should be "Slow/Norm/Fast"
  { game: 'stacktower', variants: ['Slow','Norm','Fast'],scores: [6,   14]  },

  // pongpro: "Medium" not "Normal"
  { game: 'pongpro',    variants: ['Medium'],            scores: [1,   3]   },

  // lowercase: checkers, chess, battleship
  { game: 'checkers',   variants: ['easy','medium','hard'], scores: [1, 3]  },
  { game: 'chess',      variants: ['easy','medium','hard'], scores: [1, 2]  },
  { game: 'battleship', asc: true, variants: ['easy','medium','hard'], scores: [55, 80] },

  // pixelinvaders: was lowercase, should be mixed
  { game: 'pixelinvaders', variants: ['Easy','Normal','Hard'], scores: [100, 450] },

  // hex_mini: CAPS
  { game: 'hex_mini',   variants: ['EASY','MED','HARD'],  scores: [1, 3]   },

  // makao_lite: "Med" not "Normal"
  { game: 'makao_lite', variants: ['Med'],               scores: [1,  3]   },

  // morris_classic: lowercase, "med" not "Normal"
  { game: 'morris_classic', variants: ['easy','med','hard'], scores: [1, 3] },

  // connect_four_lite: "Med" not "Normal"
  { game: 'connectfour',variants: ['Easy','Med','Hard'],  scores: [1,  3]   },

  // tic_tac_pro: "Med" not "Normal"
  { game: 'tictacpro',  variants: ['Easy','Med','Hard'],  scores: [1,  3]   },

  // dots_boxes: lowercase, "med"
  { game: 'dots_boxes', variants: ['easy','med','hard'],  scores: [1,  3]   },

  // hangman: all lowercase, "medium" not "normal", all 4 categories
  { game: 'hangman', variants: [
      'animals-easy','animals-medium','animals-hard',
      'food-easy','food-medium','food-hard',
      'technology-easy','technology-medium','technology-hard',
      'sports-easy','sports-medium','sports-hard',
    ], scores: [1, 3] },

  // minigolf: single variant "20-holes" (not "Course1/2/3")
  { game: 'minigolf', asc: true, variants: ['20-holes'], scores: [28, 50] },

  // minesweeper: correct sizes (16x16, 24x24, 32x32 not 15x10/15x15)
  { game: 'minesweeper', asc: true,
    variants: ['16x16','24x24','32x32'],
    scores: [180, 420] },

  // sudoku: "medium" not "normal"
  { game: 'sudoku', asc: true,
    variants: ['4x4-medium','9x9-medium'],
    scores: [280, 600] },

  // diceroyale: "classic", "quick", "daily" (not "Normal"/"Challenge")
  { game: 'diceroyale', variants: ['classic','quick','daily'], scores: [100, 220] },

  // gyromaze: was "5x5/7x7/9x9", should be "Easy/Med/Hard"
  { game: 'gyromaze',    variants: ['Easy','Med','Hard'],       scores: [1,   4]   },

  // akari: was empty variant, should be "6x6"/"7x7"
  { game: 'akari', asc: true, variants: ['6x6','7x7'],          scores: [250, 540] },

  // pinballpro: was "Table1..5", should be actual table names
  { game: 'pinballpro',
    variants: ['CLASSIC','NOVA','DERBY','STINGER','ECLIPSE'],   scores: [800, 4000] },

  // skijump: wrong venue names (Planica/Lillehammer don't exist in game)
  { game: 'skijump',
    variants: ['Zakopane','Innsbruck','Oberstdorf','Vikersund'], scores: [45,  85]  },

  // billiards: was missing from seed entirely
  { game: 'billiards',
    variants: ['3-ball','8-ball','9-ball','snooker'],            scores: [2,   6]   },

  // solitaire: was seeded under wrong ID "solitare" (typo)
  { game: 'solitaire', asc: true, variants: [''],               scores: [420, 900] },
];

const delay = ms => new Promise(r => setTimeout(r, ms));

async function submit(entry) {
  if (DRY) { console.log('[DRY]', JSON.stringify(entry)); return; }
  const resp = await fetch(API, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-LB-Key': KEY },
    body: JSON.stringify(entry),
  });
  const text = await resp.text();
  if (!resp.ok) {
    console.warn(`  WARN ${resp.status} ${entry.game}/${entry.variant} ${entry.user}: ${text}`);
  } else {
    console.log(`  OK  ${entry.game.padEnd(16)} v="${(entry.variant||'').padEnd(14)}" u=${entry.user.padEnd(8)} s=${entry.score}`);
  }
}

async function run() {
  let total = 0;
  for (const g of FIXES) {
    if (ONLY && g.game !== ONLY) continue;
    for (const variant of g.variants) {
      const bots = [...BOTS].sort(() => Math.random() - 0.5).slice(0, 6);
      for (const bot of bots) {
        await submit({ game: g.game, user: bot.user, score: rnd(g.scores[0], g.scores[1]),
                       variant, country: bot.country, is_bot: true });
        total++;
        if (!DRY) await delay(550);
      }
    }
  }
  console.log(`\nDone. Submitted ${total} correction entries.`);
}

run().catch(e => { console.error(e); process.exit(1); });
