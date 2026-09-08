#!/usr/bin/env node
// Etape 5 — cartographie exhaustive d'un genre : interroge Roblox sur de nombreuses
// formulations, pagine chaque recherche, dedoublonne et enrichit.
//   node scripts/5_derives.js "motif" "requete 1" "requete 2" ...
const { getJson, writeData } = require('./lib');

const OMNI = 'https://apis.roblox.com/search-api/omni-search';
const PAGES = parseInt(process.env.PAGES || '4', 10);

const motif = new RegExp(process.argv[2], 'i');
const requetes = process.argv.slice(3);

async function chercher(q) {
  const trouves = [];
  let token = '';
  for (let p = 0; p < PAGES; p++) {
    const url = `${OMNI}?searchQuery=${encodeURIComponent(q)}&sessionId=s${p}&pageType=all`
              + (token ? `&pageToken=${encodeURIComponent(token)}` : '');
    let j;
    try { j = await getJson(url, { cacheKey: `der_${q}_${p}`, minDelay: 250 }); } catch (e) { break; }
    if (!j) break;
    for (const g of j.searchResults || []) {
      if (g.contentGroupType !== 'Game') continue;
      for (const c of g.contents || []) trouves.push(c);
    }
    token = j.nextPageToken;
    if (!token) break;
  }
  return trouves;
}

(async () => {
  const par = new Map();
  for (const q of requetes) {
    const r = await chercher(q);
    let neufs = 0;
    for (const c of r) {
      if (!c.universeId || !motif.test(c.name || '')) continue;
      if (!par.has(c.universeId)) { par.set(c.universeId, c); neufs++; }
    }
    console.log(`  "${q}" -> ${r.length} resultats, ${neufs} nouveaux (total ${par.size})`);
  }

  const ids = [...par.keys()];
  const info = {};
  for (let i = 0; i < ids.length; i += 50) {
    const b = ids.slice(i, i + 50);
    const g = await getJson(`https://games.roblox.com/v1/games?universeIds=${b.join(',')}`, { minDelay: 250 });
    for (const d of (g && g.data) || []) info[d.id] = d;
  }

  const out = ids.map(id => {
    const c = par.get(id), d = info[id] || {};
    const up = c.totalUpVotes || 0, down = c.totalDownVotes || 0;
    return {
      universeId: id, nom: d.name || c.name,
      createur: (d.creator && d.creator.name) || null,
      visites: d.visits ?? null, enLigne: d.playing ?? c.playerCount ?? null,
      favoris: d.favoritedCount ?? null,
      cree: d.created ? d.created.slice(0, 10) : null,
      maj: d.updated ? d.updated.slice(0, 10) : null,
      avisPositifs: up + down ? +(up / (up + down)).toFixed(3) : null,
      url: d.rootPlaceId || c.rootPlaceId ? `https://www.roblox.com/games/${d.rootPlaceId || c.rootPlaceId}/` : null,
    };
  }).sort((a, b) => (b.visites || 0) - (a.visites || 0));

  writeData('derives.json', out);
  console.log(`\n> data/derives.json — ${out.length} jeux`);
})().catch(e => { console.error('ERREUR:', e.message); process.exit(1); });
