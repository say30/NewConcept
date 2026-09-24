// Procedural colouring: skin patterns, eyes, fixed materials.
// Colours are sRGB triplets in [0,1].

function hash3(i, j, k, s) {
  let h = Math.imul(i, 374761393) ^ Math.imul(j, 668265263) ^ Math.imul(k, 1274126177) ^ Math.imul(s | 0, 1911520717);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}

function fade(t) { return t * t * (3 - 2 * t); }

export function vnoise(x, y, z, s = 0) {
  const i = Math.floor(x), j = Math.floor(y), k = Math.floor(z);
  const fx = fade(x - i), fy = fade(y - j), fz = fade(z - k);
  let r = 0;
  for (let c = 0; c < 8; c++) {
    const dx = c & 1, dy = (c >> 1) & 1, dz = (c >> 2) & 1;
    const w = (dx ? fx : 1 - fx) * (dy ? fy : 1 - fy) * (dz ? fz : 1 - fz);
    r += w * hash3(i + dx, j + dy, k + dz, s);
  }
  return r;
}

export function fbm(x, y, z, s = 0) {
  return (vnoise(x, y, z, s) * 0.57 + vnoise(x * 2.03, y * 2.03, z * 2.03, s + 1) * 0.29 + vnoise(x * 4.1, y * 4.1, z * 4.1, s + 2) * 0.14);
}

// Worley noise: returns [F1, F2]
export function worley(x, y, z, s = 0) {
  const i = Math.floor(x), j = Math.floor(y), k = Math.floor(z);
  let f1 = 9, f2 = 9;
  for (let a = -1; a <= 1; a++)
    for (let b = -1; b <= 1; b++)
      for (let c = -1; c <= 1; c++) {
        const ci = i + a, cj = j + b, ck = k + c;
        const px = ci + hash3(ci, cj, ck, s), py = cj + hash3(ci, cj, ck, s + 7), pz = ck + hash3(ci, cj, ck, s + 13);
        const d = Math.hypot(px - x, py - y, pz - z);
        if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) f2 = d;
      }
  return [f1, f2];
}

function smoothstep(a, b, x) {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
}

function mix(a, b, t) {
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
}

export function hexToRgb(hex) {
  const h = hex.replace('#', '');
  const n = parseInt(h.length === 3 ? h.split('').map((c) => c + c).join('') : h, 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

export function rgbToHex(c) {
  return '#' + c.map((v) => Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2, '0')).join('');
}

export const PATTERNS = [
  ['none', 'Uni'],
  ['spots', 'Taches'],
  ['leopard', 'Léopard'],
  ['stripes', 'Rayures'],
  ['tiger', 'Tigre'],
  ['giraffe', 'Girafe'],
  ['scales', 'Écailles'],
  ['back', 'Dos foncé'],
  ['camo', 'Camouflage'],
];

// Resolve a creature's paint settings to numeric form (done once per build).
export function resolvePaint(paint, extra = {}) {
  return {
    base: hexToRgb(paint.base),
    secondary: hexToRgb(paint.secondary),
    detail: hexToRgb(paint.detail),
    claw: hexToRgb(paint.claw || '#efe6cf'),
    eye: hexToRgb(paint.eye || '#3a8f3a'),
    belly: hexToRgb(paint.bellyColor || '#f2e6c8'),
    bellyAmount: paint.usePattern ? paint.bellyAmount ?? 0.5 : 0,
    pattern: paint.usePattern ? paint.pattern || 'none' : 'none',
    patScale: Math.max(0.03, paint.patternScale ?? 0.25),
    patAmount: paint.patternAmount ?? 1,
    seed: paint.seed ?? 1,
    rough: paint.usePattern ? paint.texture ?? 0.5 : 0.15,
    bellyDir: extra.bellyDir || [0, -1, 0],
    axis: extra.axis || [0, 0, 1],
  };
}

function patternMask(P, p, n) {
  const s = 1 / P.patScale;
  const x = p[0] * s + P.seed * 17.3, y = p[1] * s + P.seed * 3.1, z = p[2] * s - P.seed * 9.7;
  const up = [-P.bellyDir[0], -P.bellyDir[1], -P.bellyDir[2]];
  const top = n[0] * up[0] + n[1] * up[1] + n[2] * up[2];
  switch (P.pattern) {
    case 'spots': {
      const [f1] = worley(x, y, z, P.seed);
      return 1 - smoothstep(0.26, 0.34, f1);
    }
    case 'leopard': {
      const [f1] = worley(x, y, z, P.seed);
      return smoothstep(0.18, 0.24, f1) * (1 - smoothstep(0.34, 0.4, f1));
    }
    case 'stripes': {
      const a = (p[0] * P.axis[0] + p[1] * P.axis[1] + p[2] * P.axis[2]) * s * Math.PI;
      const w = fbm(x * 0.7, y * 0.7, z * 0.7, P.seed) * 2.2;
      return smoothstep(0.35, 0.6, 0.5 + 0.5 * Math.sin(a + w));
    }
    case 'tiger': {
      const a = (p[0] * P.axis[0] + p[1] * P.axis[1] + p[2] * P.axis[2]) * s * Math.PI * 1.3;
      const w = fbm(x * 1.1, y * 1.1, z * 1.1, P.seed) * 4.5;
      const st = smoothstep(0.62, 0.8, 0.5 + 0.5 * Math.sin(a + w));
      return st * smoothstep(-0.55, 0.1, top);
    }
    case 'giraffe': {
      const [f1, f2] = worley(x * 0.8, y * 0.8, z * 0.8, P.seed);
      return smoothstep(0.07, 0.12, f2 - f1);
    }
    case 'scales': {
      const [f1, f2] = worley(x * 2.5, y * 2.5, z * 2.5, P.seed);
      return (1 - smoothstep(0.0, 0.14, f2 - f1)) * 0.75;
    }
    case 'back': {
      const w = fbm(x, y, z, P.seed) * 0.4;
      return smoothstep(-0.15, 0.55, top + w - 0.2);
    }
    case 'camo': {
      const v = fbm(x * 0.8, y * 0.8, z * 0.8, P.seed);
      return smoothstep(0.48, 0.53, v);
    }
  }
  return 0;
}

const WHITE = [0.96, 0.95, 0.92];
const BLACK = [0.03, 0.03, 0.035];

// mat: material of the dominant primitive; p: position; n: unit normal.
export function shade(P, mat, p, n) {
  const grain = 1 + (fbm(p[0] * 9, p[1] * 9, p[2] * 9, 5) - 0.5) * 0.18 * P.rough;
  switch (mat.kind) {
    case 'eye': {
      const c = mat.c;
      let vx = p[0] - c[0], vy = p[1] - c[1], vz = p[2] - c[2];
      const l = Math.hypot(vx, vy, vz) || 1;
      vx /= l; vy /= l; vz /= l;
      const d = mat.dir, up = mat.up;
      const side = [d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0]];
      const cosT = vx * d[0] + vy * d[1] + vz * d[2];
      const theta = Math.acos(Math.max(-1, Math.min(1, cosT)));
      // highlight
      const hl = [d[0] + up[0] * 0.45 + side[0] * 0.25, d[1] + up[1] * 0.45 + side[1] * 0.25, d[2] + up[2] * 0.45 + side[2] * 0.25];
      const hll = Math.hypot(hl[0], hl[1], hl[2]);
      const hcos = (vx * hl[0] + vy * hl[1] + vz * hl[2]) / hll;
      if (hcos > Math.cos(0.13 * (mat.irisSize || 0.6) * 1.6)) return [1, 1, 1];
      const irisA = 0.95 * (mat.irisSize || 0.6);
      const iris = mat.iris || P.eye;
      if (theta < irisA) {
        let pa;
        if (mat.slit) {
          const sx = vx * side[0] + vy * side[1] + vz * side[2];
          const sy = vx * up[0] + vy * up[1] + vz * up[2];
          pa = Math.hypot(Math.asin(sx) * 3.2, Math.asin(sy) * 0.85);
        } else pa = theta;
        if (pa < irisA * (mat.pupil ?? 0.45)) return BLACK;
        const t = theta / irisA;
        const ring = smoothstep(0.78, 1, t);
        const rays = 0.85 + 0.3 * vnoise(Math.atan2(vx * up[0] + vy * up[1] + vz * up[2], vx * side[0] + vy * side[1] + vz * side[2]) * 6, t * 3, 0, 3);
        return mix(iris.map((v) => Math.min(1, v * rays * (1.15 - 0.3 * t))), BLACK, ring * 0.8);
      }
      return mat.sclera || WHITE;
    }
    case 'compound': {
      const [f1, f2] = worley(p[0] * 40, p[1] * 40, p[2] * 40, 2);
      const e = smoothstep(0.0, 0.12, f2 - f1);
      const col = mat.color || [0.5, 0.05, 0.05];
      return mix(col.map((v) => v * 0.35), col, e);
    }
    case 'fixed':
      return mat.color.map((v) => v * grain);
    default: {
      let col;
      switch (mat.slot) {
        case 'secondary': col = P.secondary; break;
        case 'detail': col = P.detail; break;
        case 'claw': col = P.claw; break;
        case 'custom': col = mat.color || P.base; break;
        default: {
          col = P.base;
          const m = patternMask(P, p, n) * P.patAmount;
          if (m > 0) col = mix(col, P.secondary, Math.min(1, m));
          const b = n[0] * P.bellyDir[0] + n[1] * P.bellyDir[1] + n[2] * P.bellyDir[2];
          const bf = smoothstep(0.05, 0.7, b) * P.bellyAmount;
          if (bf > 0) col = mix(col, P.belly, bf);
        }
      }
      return col.map((v) => v * grain);
    }
  }
}
