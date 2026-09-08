#!/usr/bin/env node
// Etape 2 — pour chaque annonce BuiltByBit, cherche les jeux Roblox correspondants
// (et leurs variantes), avec stats de trafic et vignettes.
//
//   node scripts/2_roblox_match.js            (lit data/bbb_resources.json)
//   node scripts/2_roblox_match.js --demo "Anime Fighting Simulator" "Prison Tycoon"
const fs = require('fs');
const path = require('path');
const { getJson, writeData, sleep, DATA } = require('./lib');

const OMNI = 'https://apis.roblox.com/search-api/omni-search';
const GAMES = 'https://games.roblox.com/v1/games';
const THUMBS = 'https://thumbnails.roblox.com/v1/games';
const VOTES = 'https://games.roblox.com/v1/games/votes';

// Mots parasites des titres BuiltByBit ("[FREE] ...", "Roblox Game System | ...").
const NOISE = /\b(roblox|game|system|setup|template|script|scripts|source|code|kit|pack|premium|cheap|best|new|updated?|v\d+(\.\d+)*|full|complete|advanced|optimized|uncopylocked|open ?source|fe|r6|r15)\b/gi;

function keywords(title) {
  return String(title || '')
    .replace(/\[[^\]]*\]|\([^)]*\)|\{[^}]*\}/g, ' ')   // tags entre crochets
    .replace(/[|/\\+_—–-]+/g, ' ')
    .replace(NOISE, ' ')
    .replace(/[^\w\s']/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// Similarite par tokens (Dice) — assez robuste pour des titres courts.
function similarity(a, b) {
  const tok = s => new Set(String(s).toLowerCase().match(/[a-z0-9]{3,}/g) || []);
  const A = tok(a), B = tok(b);
  if (!A.size || !B.size) return 0;
  let inter = 0;
  for (const t of A) if (B.has(t)) inter++;
  return (2 * inter) / (A.size + B.size);
}

async function searchRoblox(query) {
  const url = `${OMNI}?searchQuery=${encodeURIComponent(query)}&sessionId=${Math.random().toString(36).slice(2)}&pageType=all`;
  const j = await getJson(url, { cacheKey: `rbx_search_${query}`, minDelay: 250 });
  const out = [];
  for (const grp of (j && j.searchResults) || []) {
    if (grp.contentGroupType !== 'Game') continue;
    for (const c of grp.contents || []) {
      out.push({
        universeId: c.universeId, placeId: c.rootPlaceId, name: c.name,
        playing: c.playerCount, up: c.totalUpVotes, down: c.totalDownVotes,
        creator: c.creatorName || null,
      });
    }
  }
  return out;
}

async function enrich(universeIds) {
  const info = {}, icons = {};
  for (let i = 0; i < universeIds.length; i += 50) {
    const batch = universeIds.slice(i, i + 50);
    const g = await getJson(`${GAMES}?universeIds=${batch.join(',')}`, { minDelay: 250 });
    for (const d of (g && g.data) || []) info[d.id] = d;
    const t = await getJson(`${THUMBS}/icons?universeIds=${batch.join(',')}&size=512x512&format=Png&returnPolicy=PlaceHolder`, { minDelay: 250 });
    for (const d of (t && t.data) || []) icons[d.targetId] = d.imageUrl;
  }
  return { info, icons };
}

async function matchesFor(title) {
  const q = keywords(title) || String(title).slice(0, 40);
  let cands = [];
  try { cands = await searchRoblox(q); } catch (e) { return { query: q, error: e.message, variants: [] }; }
  // dedoublonne + garde les 12 plus proches du titre
  const byId = new Map();
  for (const c of cands) if (c.universeId && !byId.has(c.universeId)) byId.set(c.universeId, c);
  const ranked = [...byId.values()]
    .map(c => ({ ...c, sim: similarity(q, c.name) }))
    .sort((a, b) => (b.sim - a.sim) || (b.playing - a.playing))
    .slice(0, 12);
  if (!ranked.length) return { query: q, variants: [] };

  const { info, icons } = await enrich(ranked.map(r => r.universeId));
  const variants = ranked.map(r => {
    const d = info[r.universeId] || {};
    const up = r.up ?? 0, down = r.down ?? 0;
    return {
      universeId: r.universeId,
      name: d.name || r.name,
      creator: (d.creator && d.creator.name) || r.creator,
      visits: d.visits ?? null,
      playing: d.playing ?? r.playing ?? null,
      favorites: d.favoritedCount ?? null,
      created: d.created || null,
      updated: d.updated || null,
      likeRatio: up + down ? +(up / (up + down)).toFixed(3) : null,
      similarity: +r.sim.toFixed(3),
      icon: icons[r.universeId] || null,
      url: d.rootPlaceId || r.placeId ? `https://www.roblox.com/games/${d.rootPlaceId || r.placeId}/` : null,
    };
  });
  return { query: q, variants };
}

(async () => {
  const argv = process.argv.slice(2);
  let titles;
  if (argv[0] === '--demo') {
    titles = argv.slice(1);
  } else {
    const f = path.join(DATA, 'bbb_resources.json');
    if (!fs.existsSync(f)) { console.error('data/bbb_resources.json absent — lance d abord 1_bbb_fetch.js'); process.exit(1); }
    titles = JSON.parse(fs.readFileSync(f, 'utf8')).map(r => r.title || r.name);
    // On ne croise avec Roblox que les meilleures annonces : 1350 recherches seraient
    // inutilement longues alors que seul le haut du classement compte.
    const pre = path.join(DATA, 'classement.json');
    const N = parseInt(process.env.TOP_N || '0', 10);
    if (N && fs.existsSync(pre)) {
      titles = JSON.parse(fs.readFileSync(pre, 'utf8')).slice(0, N).map(r => r.titre);
      console.log(`  restreint aux ${titles.length} meilleures annonces`);
    }
  }
  const out = {};
  for (let i = 0; i < titles.length; i++) {
    out[titles[i]] = await matchesFor(titles[i]);
    console.log(`  [${i + 1}/${titles.length}] ${titles[i]} -> ${out[titles[i]].variants.length} variantes`);
  }
  if (argv[0] === '--demo') console.log(JSON.stringify(out, null, 2));
  else { writeData('roblox_matches.json', out); console.log('> data/roblox_matches.json ecrit'); }
})().catch(e => { console.error('ERREUR:', e.message); process.exit(1); });
