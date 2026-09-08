#!/usr/bin/env node
// Etape 3 bis — telecharge les vignettes Roblox des jeux affiches et les encode en
// data: URI. La page publiee ne peut pas charger d'images externes : elles doivent
// voyager avec elle.
const { execFile } = require('child_process');
const { readData, writeData } = require('./lib');

const TOP = parseInt(process.env.TOP || '20', 10);
const tele = url => new Promise(res => {
  execFile('curl', ['-sS', '-m', '30', '--compressed', url], { encoding: 'buffer', maxBuffer: 32e6 },
    (e, out) => res(e || !out || !out.length ? null : out));
});

(async () => {
  const top = readData('classement.json').slice(0, TOP);
  const urls = new Set();
  for (const g of top) {
    const retenus = g.roblox.filter(v => v.concurrent);
    const autres = g.roblox.filter(v => !v.concurrent && (v.visits || 0) > 500000);
    for (const v of [...retenus, ...autres].slice(0, 6)) if (v.icon) urls.add(v.icon);
  }
  console.log(`> ${urls.size} vignettes a recuperer`);

  const map = {};
  let i = 0, poids = 0;
  for (const u of urls) {
    // 150x150 suffit pour une vignette de 72 px et garde la page legere.
    const buf = await tele(u.replace(/\/512\/512\//, '/150/150/'));
    if (buf) { map[u] = `data:image/png;base64,${buf.toString('base64')}`; poids += buf.length; }
    if (++i % 25 === 0) console.log(`  ${i}/${urls.size}`);
  }
  writeData('vignettes.json', map);
  console.log(`> data/vignettes.json — ${Object.keys(map).length} vignettes, ${Math.round(poids / 1024)} Ko`);
})();
