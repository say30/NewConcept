// Export pipeline test (same code path as the web worker, without the browser):
// body + separate pieces, simplification, assembly, glTF validation.
import { PRESETS, buildPreset } from '../src/core/presets.js';
import { buildCreature } from '../src/core/creature.js';
import { resolvePaint } from '../src/core/paint.js';
import { meshBody, meshPiece } from '../src/core/pipeline.js';
import { bakeAtlas } from '../src/core/bake.js';
import { checkMesh } from '../src/core/validate.js';
import { assembleExport, makeGLB, makeOBJZip } from '../src/export/files.js';
import zlib from 'node:zlib';
import fs from 'node:fs';
import validator from 'gltf-validator';

function png(rgba, w, h) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1); }
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const crc = Buffer.alloc(4); crc.writeUInt32BE(zlib.crc32(td)); return Buffer.concat([len, td, crc]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return new Uint8Array(Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}

const out = process.argv[2] || 'test-output';
fs.mkdirSync(`${out}/out`, { recursive: true });
const keys = (process.argv[3] || Object.keys(PRESETS).join(',')).split(',');
const texture = process.argv.includes('--texture');
let fail = 0;
for (const key of keys) {
  const t0 = performance.now();
  const c = buildPreset(key);
  const b = buildCreature(c);
  const P = resolvePaint(c.paint, b);
  const aoScale = c.spine.reduce((s, v) => s + v.r, 0) / c.spine.length;
  const body = meshBody(b.prims, P, { quality: 'export', budget: 10000, aoScale });
  const tex = texture ? bakeAtlas(body.model, body, P, 1024) : null;
  const uniq = new Map();
  for (const pc of b.pieces) if (!uniq.has(pc.key)) {
    const m = meshPiece(pc.prims, { quality: 'export', detail: 1 });
    uniq.set(pc.key, { key: pc.key, ...m, check: checkMesh(m.indices, m.positions.length / 3) });
  }
  const res = { body: { ...body, check: body.check }, tex, pieces: [...uniq.values()] };
  const asm = assembleExport(res, b, c.paint, { height: 6 });
  const pngB = tex ? png(tex.rgba, tex.size, tex.size) : null;
  const glb = makeGLB(asm, key, true, pngB);
  fs.writeFileSync(`${out}/out/${key}.glb`, glb);
  fs.writeFileSync(`${out}/out/${key}_obj.zip`, makeOBJZip(asm, key, pngB));
  const report = await validator.validateBytes(glb);
  let bad = 0, tris = 0;
  for (const p of asm.parts) {
    const ch = p.check || checkMesh(p.indices, p.positions.length / 3);
    tris += ch.triangles;
    if (!ch.watertight || ch.nonManifold) { bad++; console.log('   not watertight:', p.name, ch); }
  }
  const errs = report.issues.numErrors;
  if (errs || bad) fail++;
  console.log(key.padEnd(10), 'meshes', asm.parts.length, 'body tris', body.check.triangles, 'total tris', tris, 'open/nm meshes', bad,
    'ms', Math.round(performance.now() - t0), 'studs', asm.size.map((v) => v.toFixed(1)).join('x'), 'KB', (glb.length / 1024) | 0, 'gltf errors', errs, 'warnings', report.issues.numWarnings);
  if (errs || report.issues.numWarnings) console.log(report.issues.messages.slice(0, 5));
}
console.log(fail ? `${fail} FAIL` : 'all exports OK');
process.exit(fail ? 1 : 0);
