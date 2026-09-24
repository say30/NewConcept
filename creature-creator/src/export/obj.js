// Wavefront OBJ + MTL (shared positions -> topologically watertight) and a
// tiny "store" ZIP writer to bundle obj/mtl/png together.

export function writeOBJ({ name, positions, normals, cornerUVs, indices }) {
  const f = (v) => (Math.abs(v) < 1e-7 ? '0' : v.toFixed(5));
  const lines = [`# ${name} - Creature Creator`, `mtllib ${name}.mtl`, `o ${name}`];
  for (let i = 0; i < positions.length; i += 3) lines.push(`v ${f(positions[i])} ${f(positions[i + 1])} ${f(positions[i + 2])}`);
  for (let i = 0; i < normals.length; i += 3) lines.push(`vn ${f(normals[i])} ${f(normals[i + 1])} ${f(normals[i + 2])}`);
  for (let i = 0; i < cornerUVs.length; i += 2) lines.push(`vt ${f(cornerUVs[i])} ${f(1 - cornerUVs[i + 1])}`);
  lines.push(`usemtl ${name}Material`, 's 1');
  for (let t = 0; t < indices.length; t += 3) {
    const a = indices[t] + 1, b = indices[t + 1] + 1, c = indices[t + 2] + 1;
    const ta = t + 1, tb = t + 2, tc = t + 3;
    lines.push(`f ${a}/${ta}/${a} ${b}/${tb}/${b} ${c}/${tc}/${c}`);
  }
  const mtl = [
    `newmtl ${name}Material`,
    'Ka 1 1 1', 'Kd 1 1 1', 'Ks 0 0 0', 'd 1', 'illum 1',
    `map_Kd ${name}.png`,
  ].join('\n');
  return { obj: lines.join('\n') + '\n', mtl: mtl + '\n' };
}

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(bytes) {
  let c = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

export function writeZip(files) {
  const enc = new TextEncoder();
  const parts = [];
  const central = [];
  let offset = 0;
  for (const { name, data } of files) {
    const bytes = typeof data === 'string' ? enc.encode(data) : data;
    const nameB = enc.encode(name);
    const crc = crc32(bytes);
    const local = new Uint8Array(30 + nameB.length);
    const dv = new DataView(local.buffer);
    dv.setUint32(0, 0x04034b50, true);
    dv.setUint16(4, 20, true);
    dv.setUint16(8, 0, true);
    dv.setUint32(14, crc, true);
    dv.setUint32(18, bytes.length, true);
    dv.setUint32(22, bytes.length, true);
    dv.setUint16(26, nameB.length, true);
    local.set(nameB, 30);
    parts.push(local, bytes);
    const cen = new Uint8Array(46 + nameB.length);
    const cv = new DataView(cen.buffer);
    cv.setUint32(0, 0x02014b50, true);
    cv.setUint16(4, 20, true);
    cv.setUint16(6, 20, true);
    cv.setUint32(16, crc, true);
    cv.setUint32(20, bytes.length, true);
    cv.setUint32(24, bytes.length, true);
    cv.setUint16(28, nameB.length, true);
    cv.setUint32(42, offset, true);
    cen.set(nameB, 46);
    central.push(cen);
    offset += local.length + bytes.length;
  }
  const cenSize = central.reduce((s, c) => s + c.length, 0);
  const end = new Uint8Array(22);
  const ev = new DataView(end.buffer);
  ev.setUint32(0, 0x06054b50, true);
  ev.setUint16(8, files.length, true);
  ev.setUint16(10, files.length, true);
  ev.setUint32(12, cenSize, true);
  ev.setUint32(16, offset, true);
  const all = [...parts, ...central, end];
  const total = all.reduce((s, c) => s + c.length, 0);
  const out = new Uint8Array(total);
  let o = 0;
  for (const c of all) { out.set(c, o); o += c.length; }
  return out;
}
