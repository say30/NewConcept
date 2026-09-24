// Quadric error metric mesh simplification (Garland & Heckbert).
//
// Edges are collapsed cheapest-first. Every collapse is checked so the mesh
// stays a closed 2-manifold: the link condition (the two endpoints share
// exactly the two opposite vertices), no triangle flips, no slivers. Sharp
// features (tips of teeth and horns, eye rims...) have a high quadric error,
// so they are kept while flat areas lose their extra triangles.

export function decimate(positions, indices, { targetTris = 0, maxError = Infinity, weighted = true } = {}) {
  const nV = positions.length / 3;
  const nF = indices.length / 3;
  const P = Float64Array.from(positions);
  const F = Int32Array.from(indices);
  const fAlive = new Uint8Array(nF).fill(1);
  const vAlive = new Uint8Array(nV).fill(1);
  const stamp = new Int32Array(nV);
  const vFaces = Array.from({ length: nV }, () => []);
  for (let f = 0; f < nF; f++) for (let k = 0; k < 3; k++) vFaces[F[f * 3 + k]].push(f);

  // quadrics: a2 ab ac ad b2 bc bd c2 cd d2
  const Q = new Float64Array(nV * 10);
  for (let f = 0; f < nF; f++) {
    const a = F[f * 3], b = F[f * 3 + 1], c = F[f * 3 + 2];
    const n = faceNormal(P, a, b, c);
    const area = Math.hypot(n[0], n[1], n[2]);
    if (area < 1e-20) continue;
    const nx = n[0] / area, ny = n[1] / area, nz = n[2] / area;
    const d = -(nx * P[a * 3] + ny * P[a * 3 + 1] + nz * P[a * 3 + 2]);
    const w = weighted ? area * 0.5 : 1;
    const q = [nx * nx, nx * ny, nx * nz, nx * d, ny * ny, ny * nz, ny * d, nz * nz, nz * d, d * d];
    for (const v of [a, b, c]) for (let i = 0; i < 10; i++) Q[v * 10 + i] += q[i] * w;
  }

  // binary min-heap of candidate collapses
  const heap = [];
  const push = (e) => {
    heap.push(e);
    let i = heap.length - 1;
    while (i > 0) {
      const p = (i - 1) >> 1;
      if (heap[p].cost <= e.cost) break;
      heap[i] = heap[p]; i = p;
    }
    heap[i] = e;
  };
  const pop = () => {
    const top = heap[0];
    const last = heap.pop();
    if (heap.length) {
      let i = 0;
      const n = heap.length;
      for (;;) {
        const l = 2 * i + 1, r = l + 1;
        let m = i;
        let mc = last.cost;
        if (l < n && heap[l].cost < mc) { m = l; mc = heap[l].cost; }
        if (r < n && heap[r].cost < mc) { m = r; }
        if (m === i) break;
        heap[i] = heap[m]; i = m;
      }
      heap[i] = last;
    }
    return top;
  };

  const qsum = new Float64Array(10);
  const evalQ = (q, x, y, z) =>
    q[0] * x * x + 2 * q[1] * x * y + 2 * q[2] * x * z + 2 * q[3] * x +
    q[4] * y * y + 2 * q[5] * y * z + 2 * q[6] * y + q[7] * z * z + 2 * q[8] * z + q[9];

  const candidate = (u, v) => {
    for (let i = 0; i < 10; i++) qsum[i] = Q[u * 10 + i] + Q[v * 10 + i];
    const q = qsum;
    // solve for the optimal position
    const A = [q[0], q[1], q[2], q[1], q[4], q[5], q[2], q[5], q[7]];
    const det = A[0] * (A[4] * A[8] - A[5] * A[7]) - A[1] * (A[3] * A[8] - A[5] * A[6]) + A[2] * (A[3] * A[7] - A[4] * A[6]);
    const opts = [];
    const ux = P[u * 3], uy = P[u * 3 + 1], uz = P[u * 3 + 2];
    const vx = P[v * 3], vy = P[v * 3 + 1], vz = P[v * 3 + 2];
    const scaleRef = Math.abs(ux - vx) + Math.abs(uy - vy) + Math.abs(uz - vz) + 1e-9;
    if (Math.abs(det) > 1e-12) {
      const b = [-q[3], -q[6], -q[8]];
      const inv = (r0, r1, r2) => r0 * (A[4] * A[8] - A[5] * A[7]) - A[1] * (r1 * A[8] - A[5] * r2) + A[2] * (r1 * A[7] - A[4] * r2);
      const x = inv(b[0], b[1], b[2]) / det;
      const y = (A[0] * (b[1] * A[8] - A[5] * b[2]) - b[0] * (A[3] * A[8] - A[5] * A[6]) + A[2] * (A[3] * b[2] - b[1] * A[6])) / det;
      const z = (A[0] * (A[4] * b[2] - b[1] * A[7]) - A[1] * (A[3] * b[2] - b[1] * A[6]) + b[0] * (A[3] * A[7] - A[4] * A[6])) / det;
      // only trust the optimum if it stays near the edge
      const mx = (ux + vx) / 2, my = (uy + vy) / 2, mz = (uz + vz) / 2;
      if (Math.abs(x - mx) + Math.abs(y - my) + Math.abs(z - mz) < scaleRef * 2) opts.push([x, y, z]);
    }
    opts.push([ux, uy, uz], [vx, vy, vz], [(ux + vx) / 2, (uy + vy) / 2, (uz + vz) / 2]);
    let best = null, bc = Infinity;
    for (const o of opts) {
      const c = evalQ(q, o[0], o[1], o[2]);
      if (c < bc) { bc = c; best = o; }
    }
    push({ cost: Math.max(0, bc), u, v, x: best[0], y: best[1], z: best[2], su: stamp[u], sv: stamp[v] });
  };

  const seen = new Set();
  for (let f = 0; f < nF; f++)
    for (let k = 0; k < 3; k++) {
      const a = F[f * 3 + k], b = F[f * 3 + ((k + 1) % 3)];
      const key = a < b ? a * nV + b : b * nV + a;
      if (seen.has(key)) continue;
      seen.add(key);
      candidate(a, b);
    }

  const neighbors = (v) => {
    const s = new Set();
    for (const f of vFaces[v]) {
      if (!fAlive[f]) continue;
      for (let k = 0; k < 3; k++) { const w = F[f * 3 + k]; if (w !== v) s.add(w); }
    }
    return s;
  };

  let alive = nF;
  const target = Math.max(4, targetTris | 0);
  while (heap.length && alive > target) {
    const e = pop();
    if (e.cost > maxError) break;
    const { u, v } = e;
    if (!vAlive[u] || !vAlive[v] || stamp[u] !== e.su || stamp[v] !== e.sv) continue;
    // faces shared by u and v
    const shared = [];
    for (const f of vFaces[u]) {
      if (!fAlive[f]) continue;
      if (F[f * 3] === v || F[f * 3 + 1] === v || F[f * 3 + 2] === v) shared.push(f);
    }
    if (shared.length !== 2) continue;
    // link condition
    const nu = neighbors(u), nv = neighbors(v);
    let common = 0;
    for (const w of nu) if (nv.has(w)) common++;
    if (common !== 2 || nu.size < 3 || nv.size < 3 || nu.size + nv.size - 2 < 5) continue;
    // flip / sliver check
    let ok = true;
    for (const vert of [u, v]) {
      for (const f of vFaces[vert]) {
        if (!fAlive[f] || shared.includes(f)) continue;
        const a = F[f * 3], b = F[f * 3 + 1], c = F[f * 3 + 2];
        const n0 = faceNormal(P, a, b, c);
        const save = [P[vert * 3], P[vert * 3 + 1], P[vert * 3 + 2]];
        P[vert * 3] = e.x; P[vert * 3 + 1] = e.y; P[vert * 3 + 2] = e.z;
        const n1 = faceNormal(P, a, b, c);
        P[vert * 3] = save[0]; P[vert * 3 + 1] = save[1]; P[vert * 3 + 2] = save[2];
        const l0 = Math.hypot(n0[0], n0[1], n0[2]), l1 = Math.hypot(n1[0], n1[1], n1[2]);
        if (l1 < 1e-14) { ok = false; break; }
        const dp = (n0[0] * n1[0] + n0[1] * n1[1] + n0[2] * n1[2]) / (l0 * l1 + 1e-30);
        if (dp < 0.35) { ok = false; break; }
        // reject slivers: compare area to squared perimeter
        if (quality(P, a, b, c, vert, e) < 0.08) { ok = false; break; }
      }
      if (!ok) break;
    }
    if (!ok) continue;
    // collapse v into u
    for (const f of shared) { fAlive[f] = 0; alive--; }
    for (const f of vFaces[v]) {
      if (!fAlive[f]) continue;
      for (let k = 0; k < 3; k++) if (F[f * 3 + k] === v) F[f * 3 + k] = u;
      vFaces[u].push(f);
    }
    vAlive[v] = 0;
    vFaces[v] = [];
    vFaces[u] = vFaces[u].filter((f) => fAlive[f]);
    P[u * 3] = e.x; P[u * 3 + 1] = e.y; P[u * 3 + 2] = e.z;
    for (let i = 0; i < 10; i++) Q[u * 10 + i] += Q[v * 10 + i];
    // only edges touching u changed (their quadric / position); others stay valid
    stamp[u]++;
    for (const w of neighbors(u)) candidate(u, w);
  }

  // compact
  const remap = new Int32Array(nV).fill(-1);
  const outP = [];
  const outI = [];
  for (let f = 0; f < nF; f++) {
    if (!fAlive[f]) continue;
    for (let k = 0; k < 3; k++) {
      const v = F[f * 3 + k];
      if (remap[v] < 0) { remap[v] = outP.length / 3; outP.push(P[v * 3], P[v * 3 + 1], P[v * 3 + 2]); }
      outI.push(remap[v]);
    }
  }
  return { positions: new Float32Array(outP), indices: new Uint32Array(outI), remap };
}

function faceNormal(P, a, b, c) {
  const ax = P[b * 3] - P[a * 3], ay = P[b * 3 + 1] - P[a * 3 + 1], az = P[b * 3 + 2] - P[a * 3 + 2];
  const bx = P[c * 3] - P[a * 3], by = P[c * 3 + 1] - P[a * 3 + 1], bz = P[c * 3 + 2] - P[a * 3 + 2];
  return [ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx];
}

// triangle quality in [0,1] (1 = equilateral) with vertex `vert` moved to e
function quality(P, a, b, c, vert, e) {
  const g = (i) => (i === vert ? [e.x, e.y, e.z] : [P[i * 3], P[i * 3 + 1], P[i * 3 + 2]]);
  const A = g(a), B = g(b), C = g(c);
  const ab = Math.hypot(B[0] - A[0], B[1] - A[1], B[2] - A[2]);
  const bc = Math.hypot(C[0] - B[0], C[1] - B[1], C[2] - B[2]);
  const ca = Math.hypot(A[0] - C[0], A[1] - C[1], A[2] - C[2]);
  const ux = B[0] - A[0], uy = B[1] - A[1], uz = B[2] - A[2];
  const vx = C[0] - A[0], vy = C[1] - A[1], vz = C[2] - A[2];
  const area = 0.5 * Math.hypot(uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx);
  const s = ab * ab + bc * bc + ca * ca;
  return s > 0 ? (4 * Math.sqrt(3) * area) / s : 0;
}
