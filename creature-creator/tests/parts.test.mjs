// Every part of the catalogue: each separate piece must mesh to a closed,
// manifold, non-empty surface (preview and export quality).
import { PARTS, LIMBS } from '../src/core/parts.js';
import { buildPreset } from '../src/core/presets.js';
import { buildCreature } from '../src/core/creature.js';
import { hitFromSpine, createPart, createLimb, symmetricHit } from '../src/core/edit.js';
import { meshPiece } from '../src/core/pipeline.js';
import { checkMesh, signedVolume } from '../src/core/validate.js';

const quality = process.argv[2] || 'export';
let fail = 0, n = 0;
const base = buildPreset('quadruped');
base.parts = [];
for (const [type, def] of Object.entries(PARTS)) {
  const c = JSON.parse(JSON.stringify(base));
  if (def.end) {
    c.limbs[0].end = type;
    c.limbs = [c.limbs[0]];
  } else {
    const hit = hitFromSpine(c, 0.4, [0.6, 0.7, -0.3]);
    const { p, n: nn } = symmetricHit(hit.p, hit.n);
    c.parts.push(createPart(c, type, p, nn));
  }
  const b = buildCreature(c);
  const owner = def.end ? 'limb:' + c.limbs[0].id : 'part:' + c.parts[0]?.id;
  const pieces = b.pieces.filter((pc) => pc.owner === owner && pc.mirror !== true);
  const fused = b.prims.some((p) => p.owner === owner && p.t === 7);
  if (!pieces.length && !fused && !def.end) { console.log('EMPTY', type); fail++; continue; }
  for (const pc of pieces) {
    n++;
    const m = meshPiece(pc.prims, { quality });
    const ch = checkMesh(m.indices, m.positions.length / 3);
    const vol = signedVolume(m.positions, m.indices);
    if (!ch.triangles || !ch.watertight || ch.nonManifold || vol <= 0) {
      fail++;
      console.log('FAIL', type, pc.piece, ch, 'vol', vol);
    }
  }
}
for (const kind of Object.keys(LIMBS)) {
  const c = JSON.parse(JSON.stringify(base));
  const hit = hitFromSpine(c, 2, [0.8, -0.5, 0]);
  const { p, n: nn } = symmetricHit(hit.p, hit.n);
  c.limbs = [createLimb(c, kind, p, nn)];
  const b = buildCreature(c);
  if (!b.prims.some((q) => q.owner === 'limb:' + c.limbs[0].id)) { console.log('LIMB EMPTY', kind); fail++; }
}
console.log(`${Object.keys(PARTS).length} parts, ${n} pieces meshed (${quality}): ${fail ? fail + ' FAIL' : 'all closed ✔'}`);
process.exit(fail ? 1 : 0);
