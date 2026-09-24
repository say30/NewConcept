// Dev tool: render exported .glb files (from tests/export.test.mjs) with three.js GLTFLoader.
// Usage: node tests/render-glb.mjs <dir containing out/> dragon humanoid
import { chromium } from 'playwright';
import http from 'node:http'; import fs from 'node:fs'; import path from 'node:path';
const root = process.cwd(); const SP = process.argv[2];
const srv = http.createServer((q, s) => { let p = decodeURIComponent(q.url.split('?')[0]); p = p.startsWith('/sp/') ? path.join(SP, p.slice(4)) : path.join(root, p); try { const b = fs.readFileSync(p); s.setHeader('Content-Type', p.endsWith('.js') ? 'text/javascript' : p.endsWith('.html') ? 'text/html' : 'application/octet-stream'); s.end(b); } catch { s.statusCode = 404; s.end(); } }).listen(8765);
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 900, height: 600 } });
page.on('pageerror', e => console.log('ERR', e.message)); page.on('console', m => m.type()==='error' && console.log('console', m.text()));
for (const f of process.argv.slice(3)) {
  const [nm, opt] = f.split(':');
  await page.goto(`http://localhost:8765/tests/viewer/viewer.html?f=/sp/out/${nm}.glb${opt ? '&' + opt + '=1' : ''}`);
  await page.waitForFunction(() => window.done, null, { timeout: 60000 });
  console.log(f, JSON.stringify(await page.evaluate(() => window.info)));
  await page.screenshot({ path: `${SP}/glb_${f.replace(':', '_')}.png` });
}
await browser.close(); srv.close();
