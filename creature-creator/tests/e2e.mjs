import { chromium } from 'playwright';
import fs from 'node:fs';
import validator from 'gltf-validator';
const SP = process.argv[2] || 'test-output';
fs.mkdirSync(SP, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const ctx = await browser.newContext({ viewport: { width: 1440, height: 860 }, acceptDownloads: true });
const page = await ctx.newPage();
const errs = [];
page.on('pageerror', (e) => errs.push('PAGEERROR ' + e.message));
page.on('console', (m) => m.type() === 'error' && errs.push('console ' + m.text()));
await page.goto(new URL('../dist/index.html', import.meta.url).href);
await page.evaluate(() => localStorage.clear());
await page.reload();
await page.waitForTimeout(5000);
const count = () => page.evaluate(() => window.creatureApp.creature.parts.length);
const c0 = await count();
// place a horn by clicking card then clicking creature
await page.click('text=Cornes & antennes');
await page.click('.card:has-text("Corne droite")');
const box = await page.locator('#viewport canvas').boundingBox();
// find creature on screen: sample points until a placement happens
let placed = false;
for (const [fx, fy] of [[0.5, 0.5], [0.55, 0.48], [0.45, 0.5], [0.5, 0.55], [0.6, 0.5]]) {
  await page.mouse.click(box.x + box.width * fx, box.y + box.height * fy);
  await page.waitForTimeout(300);
  if ((await count()) > c0) { placed = { fx, fy }; break; }
}
console.log('placed', placed, 'parts', c0, '->', await count());
await page.waitForTimeout(2500);
// drag the part
const before = await page.evaluate(() => JSON.stringify(window.creatureApp.creature.parts.at(-1).anchor));
const x = box.x + box.width * placed.fx, y = box.y + box.height * placed.fy;
await page.mouse.move(x, y); await page.mouse.down();
for (let i = 1; i <= 10; i++) { await page.mouse.move(x + i * 4, y - i * 2); await page.waitForTimeout(30); }
await page.mouse.up();
await page.waitForTimeout(1500);
const after = await page.evaluate(() => JSON.stringify(window.creatureApp.creature.parts.at(-1).anchor));
console.log('drag moved part:', before !== after);
// wheel scale
const sel = await page.evaluate(() => document.querySelector('#right h2')?.textContent);
console.log('inspector:', sel);
await page.screenshot({ path: SP + '/e2e_placed.png' });
// undo
await page.keyboard.press('Control+z'); await page.keyboard.press('Control+z');
await page.waitForTimeout(500);
console.log('after 2 undo parts', await count());
// paint mode
await page.click('#modes button[data-mode=paint]');
await page.click('.patterns button:has-text("Tigre")');
await page.waitForTimeout(2500);
await page.screenshot({ path: SP + '/e2e_paint.png' });
// test mode
await page.click('#modes button[data-mode=test]');
await page.waitForTimeout(2000);
await page.screenshot({ path: SP + '/e2e_test.png' });
await page.click('#modes button[data-mode=build]');
// random
await page.click('#btn-random'); await page.waitForTimeout(3000);
await page.screenshot({ path: SP + '/e2e_random.png' });
// export
await page.click('#btn-export');
await page.click('text=Générer le modèle');
await page.waitForSelector('text=Terminé', { timeout: 120000 });
await page.screenshot({ path: SP + '/e2e_export.png' });
const [dl] = await Promise.all([page.waitForEvent('download'), page.click('.modal-card button.primary:has-text(".glb")')]);
const p = SP + '/dl.glb'; await dl.saveAs(p);
const rep = await validator.validateBytes(new Uint8Array(fs.readFileSync(p)));
console.log('downloaded', dl.suggestedFilename(), fs.statSync(p).size, 'errors', rep.issues.numErrors, 'warnings', rep.issues.numWarnings);
const [dl2] = await Promise.all([page.waitForEvent('download'), page.click('text=OBJ + texture')]);
console.log('zip', dl2.suggestedFilename());
console.log(errs.join('\n') || 'no errors');
await browser.close();
