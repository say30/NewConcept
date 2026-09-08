// Petites briques communes : HTTP via curl (respecte le proxy sortant), cache disque,
// limitation de debit et retries. Aucune dependance npm.
const { execFile } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const DATA = path.join(ROOT, 'data');
const CACHE = path.join(DATA, 'cache');
fs.mkdirSync(CACHE, { recursive: true });

const sleep = ms => new Promise(r => setTimeout(r, ms));

function curl(url, { headers = {}, timeout = 40 } = {}) {
  const args = ['-sS', '-m', String(timeout), '-w', '\n__HTTP__%{http_code}', '--compressed'];
  for (const [k, v] of Object.entries(headers)) args.push('-H', `${k}: ${v}`);
  args.push(url);
  return new Promise(resolve => {
    execFile('curl', args, { maxBuffer: 64 * 1024 * 1024 }, (err, stdout, stderr) => {
      if (err && !stdout) return resolve({ status: 0, body: '', error: stderr || err.message });
      const i = stdout.lastIndexOf('\n__HTTP__');
      const status = i === -1 ? 0 : parseInt(stdout.slice(i + 9), 10);
      resolve({ status, body: i === -1 ? stdout : stdout.slice(0, i) });
    });
  });
}

// GET JSON avec retries (429/5xx -> backoff exponentiel) et cache disque optionnel.
async function getJson(url, { headers, cacheKey, tries = 5, minDelay = 0 } = {}) {
  const cf = cacheKey ? path.join(CACHE, cacheKey.replace(/[^\w.-]/g, '_') + '.json') : null;
  if (cf && fs.existsSync(cf)) {
    try { return JSON.parse(fs.readFileSync(cf, 'utf8')); } catch (_) { /* cache corrompu */ }
  }
  let wait = 1000;
  for (let t = 0; t < tries; t++) {
    if (minDelay) await sleep(minDelay);
    const r = await curl(url, { headers });
    if (r.status >= 200 && r.status < 300) {
      let json;
      try { json = JSON.parse(r.body); } catch (e) { throw new Error(`JSON invalide depuis ${url}`); }
      if (cf) fs.writeFileSync(cf, JSON.stringify(json));
      return json;
    }
    if (r.status === 404) return null;
    if (r.status === 401 || r.status === 403) {
      throw new Error(`HTTP ${r.status} sur ${url} — token invalide ou acces refuse: ${r.body.slice(0, 200)}`);
    }
    await sleep(wait);
    wait = Math.min(wait * 2, 20000);
  }
  throw new Error(`Echec apres ${tries} tentatives: ${url}`);
}

const readData = f => JSON.parse(fs.readFileSync(path.join(DATA, f), 'utf8'));
const writeData = (f, obj) => fs.writeFileSync(path.join(DATA, f), JSON.stringify(obj, null, 2));

module.exports = { curl, getJson, sleep, readData, writeData, DATA, ROOT };
