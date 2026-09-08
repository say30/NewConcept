#!/usr/bin/env node
// Etape 1 — recupere toutes les annonces "Roblox > Game Setups" via l'API officielle
// BuiltByBit (le site web est protege par Cloudflare et inaccessible en scraping).
//
//   BBB_TOKEN="Private xxxxx" node scripts/1_bbb_fetch.js
//
// Variables optionnelles :
//   BBB_CATEGORY_ID  force l'id de categorie (sinon detection auto sur le libelle)
//   MAX_PAGES        nombre max de pages de listing (defaut 200)
const { getJson, writeData, sleep } = require('./lib');

const API = 'https://api.builtbybit.com/v1';
const TOKEN = process.env.BBB_TOKEN;
const MAX_PAGES = parseInt(process.env.MAX_PAGES || '200', 10);
const DELAY = parseInt(process.env.BBB_DELAY || '350', 10);

if (!TOKEN) {
  console.error('BBB_TOKEN manquant. Genere un token sur builtbybit.com (Account > API Credentials)');
  console.error('puis relance avec : BBB_TOKEN="Private <token>" node scripts/1_bbb_fetch.js');
  process.exit(1);
}
const H = { Authorization: TOKEN.startsWith('Private ') || TOKEN.startsWith('Shared ') ? TOKEN : `Private ${TOKEN}` };

const unwrap = r => (r && r.data !== undefined ? r.data : r);
const isGameSetup = r => {
  if (process.env.BBB_CATEGORY_ID) return String(r.category_id) === process.env.BBB_CATEGORY_ID;
  const label = `${r.category_title || ''} ${r.category || ''}`.toLowerCase();
  return label.includes('game setup') || label.includes('roblox');
};

(async () => {
  console.log('> Verification du token...');
  await getJson(`${API}/health`, { headers: H });
  console.log('  token OK');

  const listings = [];
  const seen = new Set();
  for (let page = 1; page <= MAX_PAGES; page++) {
    const url = `${API}/resources?sort=resource_date&order=desc&page=${page}`;
    const rows = unwrap(await getJson(url, { headers: H, minDelay: DELAY }));
    if (!Array.isArray(rows) || rows.length === 0) { console.log(`  fin du listing page ${page}`); break; }
    let kept = 0;
    for (const r of rows) {
      const id = r.resource_id ?? r.id;
      if (seen.has(id)) continue;
      seen.add(id);
      if (isGameSetup(r)) { listings.push(r); kept++; }
    }
    console.log(`  page ${page}: ${rows.length} annonces, ${kept} retenues (total ${listings.length})`);
  }

  console.log(`> ${listings.length} annonces retenues. Recuperation du detail...`);
  const out = [];
  for (let i = 0; i < listings.length; i++) {
    const base = listings[i];
    const id = base.resource_id ?? base.id;
    let detail = null, reviews = [], updates = [];
    try {
      detail = unwrap(await getJson(`${API}/resources/${id}`, { headers: H, cacheKey: `bbb_res_${id}`, minDelay: DELAY }));
    } catch (e) { console.warn(`  ! detail ${id}: ${e.message}`); }
    try {
      reviews = unwrap(await getJson(`${API}/resources/${id}/reviews?page=1`, { headers: H, cacheKey: `bbb_rev_${id}`, minDelay: DELAY })) || [];
    } catch (_) {}
    try {
      updates = unwrap(await getJson(`${API}/resources/${id}/updates?page=1`, { headers: H, cacheKey: `bbb_upd_${id}`, minDelay: DELAY })) || [];
    } catch (_) {}
    out.push({ ...base, ...(detail || {}), _reviews: reviews, _updates: updates,
               _url: `https://builtbybit.com/resources/${id}/` });
    if ((i + 1) % 10 === 0) console.log(`  detail ${i + 1}/${listings.length}`);
  }

  writeData('bbb_resources.json', out);
  console.log(`> data/bbb_resources.json ecrit (${out.length} annonces)`);
})().catch(e => { console.error('ERREUR:', e.message); process.exit(1); });
