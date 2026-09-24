import { PRESETS, buildPreset } from '../src/core/presets.js';
import { buildCreature } from '../src/core/creature.js';
import { buildMesh } from '../src/core/mesher.js';
import { resolvePaint } from '../src/core/paint.js';
import { checkMesh, signedVolume } from '../src/core/validate.js';

let fail = 0;
for (const key of Object.keys(PRESETS)) {
  const t0 = performance.now();
  const c = buildPreset(key);
  const b = buildCreature(c);
  const P = resolvePaint(c.paint, b);
  const t1 = performance.now();
  for (const div of [70, 130]) {
    const ext = Math.max(...[0,1,2].map(i => Math.max(...b.prims.map(p => p.box?.mx?.[i] ?? 0))));
    const tm = performance.now();
    const model0 = null;
    // cell size from bounding extent
    const mesh0 = buildMesh(b.prims, P, 0.05, { bones: false, aoScale: 0 });
    const size = Math.max(...[0,1,2].map(i => mesh0.model.mx[i] - mesh0.model.mn[i]));
    const h = size / div;
    const mesh = buildMesh(b.prims, P, h, { bones: true, aoScale: 0.3 });
    const chk = checkMesh(mesh.indices, mesh.positions.length / 3);
    const vol = signedVolume(mesh.positions, mesh.indices);
    const ok = chk.watertight && chk.nonManifold === 0 && vol > 0;
    if (!ok) fail++;
    console.log(key.padEnd(10), 'div', div, 'prims', b.prims.length, 'bones', b.bones.length, 'limbs', c.limbs.length, 'parts', c.parts.length,
      'tris', chk.triangles, 'boundary', chk.boundary, 'nm', chk.nonManifold, 'flip', chk.flipped, 'vol', vol.toFixed(3),
      'ms', Math.round(performance.now() - tm), ok ? 'OK' : 'FAIL');
    void ext; void model0; void t0; void t1;
  }
}
// random creatures
const { randomCreature } = await import('../src/core/random.js');
for (let s = 1; s <= 15; s++) {
  const c = randomCreature(s * 104729);
  const b = buildCreature(c);
  const mesh = buildMesh(b.prims, resolvePaint(c.paint, b), 0.035, { bones: true, aoScale: 0.3, fast: true, iters: 1 });
  const chk = checkMesh(mesh.indices, mesh.positions.length / 3);
  const ok = chk.watertight && chk.nonManifold === 0 && signedVolume(mesh.positions, mesh.indices) > 0;
  if (!ok) { fail++; console.log('random', s, 'FAIL', chk); }
}
console.log(fail ? `${fail} FAIL` : 'all core checks OK');
process.exit(fail ? 1 : 0);
