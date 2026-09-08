#!/usr/bin/env node
// Etape 1 bis — convertit le JSON de collecte-navigateur.js au format du pipeline.
//   node scripts/1b_import_navigateur.js /chemin/builtbybit-roblox.json
//
// Le champ "listing" reprend le resume affiche sur la page de recherche et se lit
// beaucoup plus surement que les selecteurs de la fiche :
//   "$19.99 $24.99 20% OFF <titre> <auteur> <accroche> 5.00 star(s) 2 ratings 28 purchases"
const fs = require('fs');
const { writeData } = require('./lib');

const src = process.argv[2];
if (!src || !fs.existsSync(src)) {
  console.error('Usage : node scripts/1b_import_navigateur.js <builtbybit-roblox.json>');
  process.exit(1);
}
const brut = JSON.parse(fs.readFileSync(src, 'utf8'));

const out = brut.map(a => {
  const L = a.listing || '';
  const prix = (L.match(/\$\s?([\d,]+(?:\.\d{1,2})?)/) || [])[1];
  return {
    resource_id: a.id,
    title: a.titre,
    tag_line: a.accroche || '',
    description: a.extrait || '',
    price: prix ? parseFloat(prix.replace(/,/g, '')) : 0,
    currency: 'USD',
    promo: (L.match(/(\d+%\s*OFF)/i) || [])[1] || null,
    author_id: a.auteur || null,
    // Ventes, note et nombre d'avis relus depuis le resume du listing.
    purchase_count: parseInt(((L.match(/([\d,]+)\s*(?:purchases?|downloads?)/i) || [])[1] || '0').replace(/,/g, ''), 10),
    review_count: parseInt((L.match(/(\d+)\s*ratings?/i) || [])[1] || '0', 10),
    review_average: parseFloat((L.match(/([\d.]+)\s*star\(s\)/i) || [])[1] || '0'),
    _url: a.url.split('?')[0],
    _metrics: {
      words: a.mots || 0,
      media: (a.images || 0) + (a.videos || 0),
      headings: a.titres || 0,
      bullets: a.puces || 0,
    },
    _reviews: [], _updates: [],
  };
});

const notees = out.filter(r => r.review_count > 0).length;
const vendues = out.filter(r => r.purchase_count > 0).length;
writeData('bbb_resources.json', out);
console.log(`> data/bbb_resources.json — ${out.length} annonces, ${notees} notees, ${vendues} avec au moins une vente`);
