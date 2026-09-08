#!/usr/bin/env node
// Etape 1 bis — convertit le JSON produit par collecte-navigateur.js au format
// attendu par la suite du pipeline.
//   node scripts/1b_import_navigateur.js /chemin/builtbybit-roblox.json
const fs = require('fs');
const { writeData } = require('./lib');

const src = process.argv[2];
if (!src || !fs.existsSync(src)) {
  console.error('Usage : node scripts/1b_import_navigateur.js <builtbybit-roblox.json>');
  process.exit(1);
}
const brut = JSON.parse(fs.readFileSync(src, 'utf8'));
const nb = s => { const m = String(s || '').replace(/[^\d]/g, ''); return m ? parseInt(m, 10) : 0; };

const out = brut.map(a => ({
  resource_id: a.id,
  title: a.titre,
  tag_line: a.accroche || '',
  description: a.extrait || '',
  price: a.prix ? parseFloat(String(a.prix).replace(/[^\d.]/g, '')) : 0,
  currency: 'USD',
  author_id: a.auteur || null,
  purchase_count: nb(a.ventes),
  review_count: nb(a.avis),
  review_average: parseFloat((String(a.note || '').match(/([0-5][.,]\d+)/) || [])[1] || 0),
  _url: a.url,
  // Metriques deja mesurees dans le navigateur : le scoreur les reprend telles quelles.
  _metrics: {
    words: a.mots || 0, media: (a.images || 0) + (a.videos || 0),
    headings: a.titres || 0, bullets: a.puces || 0,
    changelog: a.majs || 0,
  },
  _reviews: [], _updates: [],
  _erreur: a.erreur || null,
}));

const ok = out.filter(r => !r._erreur).length;
writeData('bbb_resources.json', out);
console.log(`> data/bbb_resources.json ecrit — ${out.length} annonces (${ok} avec detail complet)`);
