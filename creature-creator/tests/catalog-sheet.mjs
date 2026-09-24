// Dev tool: renders every part of a category, meshed alone, into one image.
// Usage: node tests/catalog-sheet.mjs <outdir> <category>
import { chromium } from 'playwright';
import fs from 'node:fs';
import { PARTS } from '../src/core/parts.js';
import { Ctx, frameFromNormal } from '../src/core/creature.js';
import { meshPiece } from '../src/core/pipeline.js';
import { slotHex, defaultPaint } from '../src/core/creature.js';

const out = process.argv[2] || 'test-output';
const cat = process.argv[3] || 'eyes';
const paint = Object.assign(defaultPaint(), { base: '#d98f5b', secondary: '#7a4a8c', detail: '#e8d9b0' });
const items = [];
for (const [type, def] of Object.entries(PARTS)) {
  if (def.cat !== cat) continue;
  const axes = def.ground ? frameFromNormal([0, -1, 0], 'fwd') : frameFromNormal(def.hint === 'up' ? [0, 0, -1] : [0, 1, 0], def.hint || 'fwd');
  const ctx = new Ctx(Object.assign({ o: [0, 0, 0] }, axes), 1, { owner: 'x', bw: [], slot: def.slot || 'base', k: def.k ?? 0.02, mainPiece: def.pieceName || def.name });
  def.build(ctx, Object.assign({}, def.params || {}));
  const meshes = [];
  for (const pc of ctx.pieces.values()) {
    if (!pc.prims.some((p) => p.op === 'add')) continue;
    const m = meshPiece(pc.prims, { quality: 'export' });
    meshes.push({ pos: [...m.positions], nor: [...m.normals], idx: [...m.indices], color: slotHex(paint, pc.slot), axes });
  }
  items.push({ name: def.name, meshes });
}
const html = `<!doctype html><html><head><meta charset="utf-8"></head><body style="margin:0;background:#2a2f45">
<script type="importmap">{"imports":{"three":"${new URL('../node_modules/three/build/three.module.js', import.meta.url).href}"}}</script>
<script type="module">
import * as THREE from 'three';
const items = ${JSON.stringify(items)};
const W = 260, cols = 5, rows = Math.ceil(items.length / cols);
const r = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true }); r.setSize(W * cols, W * rows); document.body.append(r.domElement);
r.setScissorTest(true);
items.forEach((it, i) => {
  const s = new THREE.Scene(); s.background = new THREE.Color(0x3a4060);
  s.add(new THREE.HemisphereLight(0xffffff, 0x445566, 1.4)); const d = new THREE.DirectionalLight(0xffffff, 2); d.position.set(2, 3, -2); s.add(d);
  const g = new THREE.Group();
  for (const m of it.meshes) {
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(m.pos, 3)); geo.setAttribute('normal', new THREE.Float32BufferAttribute(m.nor, 3)); geo.setIndex(m.idx);
    const mesh = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ color: m.color, roughness: 0.5 }));
    const a = m.axes; mesh.matrixAutoUpdate = false; mesh.matrix.set(a.x[0], a.y[0], a.z[0], 0, a.x[1], a.y[1], a.z[1], 0, a.x[2], a.y[2], a.z[2], 0, 0, 0, 0, 1);
    g.add(mesh);
  }
  s.add(g); g.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(g); const c = box.getCenter(new THREE.Vector3()); const sz = box.getSize(new THREE.Vector3()).length() || 1;
  const cam = new THREE.PerspectiveCamera(35, 1, 0.01, 50); cam.position.copy(c).add(new THREE.Vector3(0.8, 0.5, -1).normalize().multiplyScalar(sz * 1.5)); cam.lookAt(c);
  const x = (i % cols) * W, y = (rows - 1 - Math.floor(i / cols)) * W;
  r.setViewport(x, y, W, W); r.setScissor(x, y, W, W); r.render(s, cam);
  const lab = document.createElement('div'); lab.textContent = it.name; lab.style.cssText = 'position:absolute;color:#fff;font:13px sans-serif;left:' + (x + 6) + 'px;top:' + (Math.floor(i / cols) * W + 4) + 'px'; document.body.append(lab);
});
window.done = true;
</script></body></html>`;
const file = `${out}/sheet_${cat}.html`;
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(file, html);
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--allow-file-access-from-files'] });
const page = await browser.newPage({ viewport: { width: 1300, height: 260 * Math.ceil(items.length / 5) } });
page.on('pageerror', (e) => console.log('ERR', e.message));
await page.goto('file://' + fs.realpathSync(file));
await page.waitForFunction(() => window.done, null, { timeout: 120000 });
await page.screenshot({ path: `${out}/sheet_${cat}.png`, fullPage: true });
await browser.close();
console.log('ok', items.length);
