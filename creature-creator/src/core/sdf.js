// Signed distance primitives used to describe a creature.
// A creature is the smooth union of many primitives; the final mesh is the
// zero iso-surface of that field, which is by construction a closed surface.
//
// Primitives are plain objects (structured-clone friendly) so they can be sent
// to the worker. `prepPrim` adds precomputed data used by `primDist`.

export const T_SPHERE = 0;
export const T_CONE = 1; // round cone (capsule when ra == rb)
export const T_ELL = 2; // ellipsoid (oriented)
export const T_BOX = 3; // rounded box (oriented)
export const T_TRI = 4; // triangle slab (for membranes / fins)

export const UNSET = 1e9;

export function smin(a, b, k) {
  if (k <= 0) return a < b ? a : b;
  const h = Math.max(k - Math.abs(a - b), 0) / k;
  return (a < b ? a : b) - h * h * k * 0.25;
}

export function smax(a, b, k) {
  return -smin(-a, -b, k);
}

// ---------------------------------------------------------------- prepare

// minR: minimum thickness (inflates primitives thinner than the voxel size so
// thin parts never break into fragments).
export function prepPrim(src, minR = 0) {
  const p = Object.assign({}, src);
  switch (p.t) {
    case T_SPHERE:
      p.r = Math.max(p.r, minR);
      break;
    case T_CONE: {
      p.ra = Math.max(p.ra, minR);
      p.rb = Math.max(p.rb, minR);
      const bx = p.b[0] - p.a[0], by = p.b[1] - p.a[1], bz = p.b[2] - p.a[2];
      p.bx = bx; p.by = by; p.bz = bz;
      p.l2 = bx * bx + by * by + bz * bz;
      p.rr = p.ra - p.rb;
      p.a2 = p.l2 - p.rr * p.rr;
      p.il2 = p.l2 > 0 ? 1 / p.l2 : 0;
      p.degen = p.a2 <= 1e-9 || p.l2 < 1e-12;
      break;
    }
    case T_ELL:
      p.h = p.h.map((v) => Math.max(v, minR));
      break;
    case T_BOX:
      p.h = p.h.map((v) => Math.max(v, minR * 0.5));
      p.rr = Math.min(p.rr || 0, Math.min(p.h[0], p.h[1], p.h[2]));
      break;
    case T_TRI: {
      p.th = Math.max(p.th, minR);
      const [a, b, c] = [p.a, p.b, p.c];
      const ba = sub(b, a), cb = sub(c, b), ac = sub(a, c);
      const nor = cross(ba, ac);
      p.ba = ba; p.cb = cb; p.ac = ac; p.nor = nor;
      p.cba = cross(ba, nor); p.ccb = cross(cb, nor); p.cac = cross(ac, nor);
      p.dba = dot(ba, ba) || 1e-12; p.dcb = dot(cb, cb) || 1e-12; p.dac = dot(ac, ac) || 1e-12;
      p.dnor = dot(nor, nor) || 1e-12;
      break;
    }
  }
  p.box = primAABB(p);
  return p;
}

export function primAABB(p) {
  let mn, mx;
  switch (p.t) {
    case T_SPHERE:
      mn = [p.c[0] - p.r, p.c[1] - p.r, p.c[2] - p.r];
      mx = [p.c[0] + p.r, p.c[1] + p.r, p.c[2] + p.r];
      break;
    case T_CONE:
      mn = [0, 1, 2].map((i) => Math.min(p.a[i] - p.ra, p.b[i] - p.rb));
      mx = [0, 1, 2].map((i) => Math.max(p.a[i] + p.ra, p.b[i] + p.rb));
      break;
    case T_ELL:
    case T_BOX: {
      const m = p.m;
      const ext = [0, 0, 0];
      for (let i = 0; i < 3; i++) {
        let e = 0;
        for (let j = 0; j < 3; j++) {
          const v = m[j * 3 + i] * p.h[j];
          e += p.t === T_ELL ? v * v : Math.abs(v);
        }
        ext[i] = p.t === T_ELL ? Math.sqrt(e) : e;
      }
      mn = [0, 1, 2].map((i) => p.c[i] - ext[i]);
      mx = [0, 1, 2].map((i) => p.c[i] + ext[i]);
      break;
    }
    case T_TRI:
      mn = [0, 1, 2].map((i) => Math.min(p.a[i], p.b[i], p.c[i]) - p.th);
      mx = [0, 1, 2].map((i) => Math.max(p.a[i], p.b[i], p.c[i]) + p.th);
      break;
  }
  return { mn, mx };
}

// ---------------------------------------------------------------- distance

export function primDist(p, x, y, z) {
  switch (p.t) {
    case T_SPHERE: {
      const dx = x - p.c[0], dy = y - p.c[1], dz = z - p.c[2];
      return Math.sqrt(dx * dx + dy * dy + dz * dz) - p.r;
    }
    case T_CONE: {
      const ax = x - p.a[0], ay = y - p.a[1], az = z - p.a[2];
      if (p.degen) {
        const d1 = Math.sqrt(ax * ax + ay * ay + az * az) - p.ra;
        const bx = x - p.b[0], by = y - p.b[1], bz = z - p.b[2];
        const d2 = Math.sqrt(bx * bx + by * by + bz * bz) - p.rb;
        return Math.min(d1, d2);
      }
      const l2 = p.l2;
      const yy = ax * p.bx + ay * p.by + az * p.bz;
      const zz = yy - l2;
      const qx = ax * l2 - p.bx * yy, qy = ay * l2 - p.by * yy, qz = az * l2 - p.bz * yy;
      const x2 = qx * qx + qy * qy + qz * qz;
      const y2 = yy * yy * l2;
      const z2 = zz * zz * l2;
      const rr = p.rr;
      const k = Math.sign(rr) * rr * rr * x2;
      if (Math.sign(zz) * p.a2 * z2 > k) return Math.sqrt(x2 + z2) * p.il2 - p.rb;
      if (Math.sign(yy) * p.a2 * y2 < k) return Math.sqrt(x2 + y2) * p.il2 - p.ra;
      return (Math.sqrt(x2 * p.a2 * p.il2) + yy * rr) * p.il2 - p.ra;
    }
    case T_ELL: {
      const dx = x - p.c[0], dy = y - p.c[1], dz = z - p.c[2];
      const m = p.m;
      const lx = m[0] * dx + m[1] * dy + m[2] * dz;
      const ly = m[3] * dx + m[4] * dy + m[5] * dz;
      const lz = m[6] * dx + m[7] * dy + m[8] * dz;
      const rx = p.h[0], ry = p.h[1], rz = p.h[2];
      const k0 = Math.sqrt((lx / rx) ** 2 + (ly / ry) ** 2 + (lz / rz) ** 2);
      const k1 = Math.sqrt((lx / (rx * rx)) ** 2 + (ly / (ry * ry)) ** 2 + (lz / (rz * rz)) ** 2);
      if (k1 < 1e-12) return -Math.min(rx, ry, rz);
      return (k0 * (k0 - 1)) / k1;
    }
    case T_BOX: {
      const dx = x - p.c[0], dy = y - p.c[1], dz = z - p.c[2];
      const m = p.m;
      const r = p.rr;
      const qx = Math.abs(m[0] * dx + m[1] * dy + m[2] * dz) - p.h[0] + r;
      const qy = Math.abs(m[3] * dx + m[4] * dy + m[5] * dz) - p.h[1] + r;
      const qz = Math.abs(m[6] * dx + m[7] * dy + m[8] * dz) - p.h[2] + r;
      const ox = Math.max(qx, 0), oy = Math.max(qy, 0), oz = Math.max(qz, 0);
      return Math.sqrt(ox * ox + oy * oy + oz * oz) + Math.min(Math.max(qx, qy, qz), 0) - r;
    }
    case T_TRI: {
      const pa = [x - p.a[0], y - p.a[1], z - p.a[2]];
      const pb = [x - p.b[0], y - p.b[1], z - p.b[2]];
      const pc = [x - p.c[0], y - p.c[1], z - p.c[2]];
      const s =
        Math.sign(dot(p.cba, pa)) + Math.sign(dot(p.ccb, pb)) + Math.sign(dot(p.cac, pc));
      let d2;
      if (s < 2) {
        d2 = Math.min(
          segD2(p.ba, pa, p.dba),
          segD2(p.cb, pb, p.dcb),
          segD2(p.ac, pc, p.dac)
        );
      } else {
        const dn = dot(p.nor, pa);
        d2 = (dn * dn) / p.dnor;
      }
      return Math.sqrt(d2) - p.th;
    }
  }
  return UNSET;
}

function segD2(e, pv, de) {
  const t = Math.min(1, Math.max(0, dot(e, pv) / de));
  const x = e[0] * t - pv[0], y = e[1] * t - pv[1], z = e[2] * t - pv[2];
  return x * x + y * y + z * z;
}

// Field of a list of prepared prims (additive prims must come before
// subtractive ones). `list` optionally restricts to a subset of indices.
export function fieldAt(prims, x, y, z, list, skipOwner) {
  let f = UNSET;
  const n = list ? list.length : prims.length;
  for (let i = 0; i < n; i++) {
    const p = prims[list ? list[i] : i];
    if (skipOwner !== undefined && p.owner === skipOwner) continue;
    const d = primDist(p, x, y, z);
    if (!p.sub) f = f >= UNSET ? d : smin(f, d, p.k);
    else if (f < UNSET) f = smax(f, -d, p.k);
  }
  return f;
}

// ------------------------------------------------------------ small vec ops
export function sub(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
export function add(a, b) { return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]; }
export function scale(a, s) { return [a[0] * s, a[1] * s, a[2] * s]; }
export function dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
export function cross(a, b) {
  return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
}
export function len(a) { return Math.hypot(a[0], a[1], a[2]); }
export function norm(a) {
  const l = len(a);
  return l > 1e-12 ? [a[0] / l, a[1] / l, a[2] / l] : [0, 1, 0];
}
export function lerp3(a, b, t) {
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
}
