import { buildPreset } from '../src/core/presets.js';
import { buildCreature } from '../src/core/creature.js';
import { resolvePaint } from '../src/core/paint.js';
import { exportMesh } from '../src/core/bake.js';
import { prepareExport, makeGLB, makeOBJZip } from '../src/export/files.js';
import { checkMesh } from '../src/core/validate.js';
import zlib from 'node:zlib';
import fs from 'node:fs';
import validator from 'gltf-validator';

function png(rgba, w, h) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1); }
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const crc = Buffer.alloc(4); crc.writeUInt32BE(zlib.crc32(td)); return Buffer.concat([len, td, crc]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return new Uint8Array(Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}

const out = process.argv[2] || 'test-out';
fs.mkdirSync(out, { recursive: true });
let fail = 0;
for (const key of (process.argv[3] || 'dragon,humanoid').split(',')) {
  const c = buildPreset(key);
  const b = buildCreature(c);
  const P = resolvePaint(c.paint, b);
  const t0 = performance.now();
  const res = exportMesh(b.prims, P, { budget: 15000, texSize: 1024, aoScale: 0.35 });
  const t1 = performance.now();
  const prep = prepareExport(res, b.bones, { height: 6 });
  const pngB = png(res.tex.rgba, res.tex.size, res.tex.size);
  const glb = makeGLB(prep, key, pngB, true);
  const zip = makeOBJZip(prep, key, pngB);
  fs.writeFileSync(`${out}/${key}.glb`, glb);
  fs.writeFileSync(`${out}/${key}_obj.zip`, zip);
  fs.writeFileSync(`${out}/${key}.png`, pngB);
  const chk = checkMesh(res.mesh.indices, res.mesh.positions.length / 3);
  const report = await validator.validateBytes(glb);
  const errs = report.issues.numErrors;
  if (errs || !chk.watertight || chk.nonManifold || chk.triangles > 15000) fail++;
  console.log(key, 'tris', chk.triangles, 'boundary', chk.boundary, 'nm', chk.nonManifold, 'ms', Math.round(t1 - t0), 'tex', res.tex.size, 'size studs', prep.X.size.map(v=>v.toFixed(1)).join('x'),
    'glb KB', (glb.length/1024).toFixed(0), 'gltf errors', errs, 'warnings', report.issues.numWarnings);
  if (errs || report.issues.numWarnings) console.log(report.issues.messages.slice(0, 8));
}
process.exit(fail ? 1 : 0);
