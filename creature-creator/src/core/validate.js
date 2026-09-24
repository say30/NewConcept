// Topology checks: a watertight mesh has every edge shared by exactly two
// triangles with opposite orientation.
export function checkMesh(indices, nVerts) {
  const edges = new Map();
  const key = (a, b) => (a < b ? a * nVerts + b : b * nVerts + a);
  for (let t = 0; t < indices.length; t += 3) {
    for (let e = 0; e < 3; e++) {
      const a = indices[t + e], b = indices[t + ((e + 1) % 3)];
      const k = key(a, b);
      let r = edges.get(k);
      if (!r) { r = { n: 0, dir: 0 }; edges.set(k, r); }
      r.n++;
      r.dir += a < b ? 1 : -1;
    }
  }
  let boundary = 0, nonManifold = 0, flipped = 0;
  for (const r of edges.values()) {
    if (r.n === 1) boundary++;
    else if (r.n > 2) nonManifold++;
    else if (r.dir !== 0) flipped++;
  }
  return { triangles: indices.length / 3, vertices: nVerts, edges: edges.size, boundary, nonManifold, flipped, watertight: boundary === 0 && flipped === 0 };
}

// Signed volume (positive when normals point outward).
export function signedVolume(pos, idx) {
  let v = 0;
  for (let t = 0; t < idx.length; t += 3) {
    const a = idx[t] * 3, b = idx[t + 1] * 3, c = idx[t + 2] * 3;
    v += pos[a] * (pos[b + 1] * pos[c + 2] - pos[b + 2] * pos[c + 1])
       - pos[a + 1] * (pos[b] * pos[c + 2] - pos[b + 2] * pos[c])
       + pos[a + 2] * (pos[b] * pos[c + 1] - pos[b + 1] * pos[c]);
  }
  return v / 6;
}
