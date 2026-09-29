#!/usr/bin/env python3
"""Rendu de prévisualisation (outil de développement, hors plugin).

Lit sur stdin des blocs émis par les tests Luau :
  #OBJ nom [r g b]
  v x y z
  f a b c
  #END
Mode --grid : une vignette par objet. Sinon : scène unique (créature complète),
vue sous plusieurs angles.
"""
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from mpl_toolkits.mplot3d.art3d import Poly3DCollection  # noqa: E402


def parse(stream):
    objs = []
    cur = None
    for line in stream:
        line = line.strip()
        if line.startswith("#OBJ"):
            parts = line.split()
            color = (0.8, 0.6, 0.3)
            if len(parts) >= 5:
                color = tuple(float(x) for x in parts[2:5])
            cur = {"name": parts[1], "v": [], "f": [], "color": color}
        elif line.startswith("#END") and cur:
            objs.append(cur)
            cur = None
        elif cur is not None and line.startswith("v "):
            cur["v"].append([float(x) for x in line.split()[1:4]])
        elif cur is not None and line.startswith("f "):
            cur["f"].append([int(x) - 1 for x in line.split()[1:4]])
    return objs


def to_plot(p):
    # Roblox : Y haut, -Z avant  ->  matplotlib : Z haut
    return np.stack([p[..., 0], p[..., 2], p[..., 1]], axis=-1)


def draw(ax, objs, elev, azim):
    light = np.array([0.4, -0.5, 0.8])
    light /= np.linalg.norm(light)
    allp, allc = [], []
    for o in objs:
        v = np.array(o["v"])
        f = np.array(o["f"])
        if len(f) == 0:
            continue
        tris = to_plot(v[f])
        # (x,y,z)->(x,z,y) est une réflexion : on inverse la normale
        n = -np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
        n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-9
        shade = 0.35 + 0.65 * np.clip(n @ light, 0, 1)
        base = np.array(o["color"])
        allc.append(np.clip(base[None, :] * shade[:, None], 0, 1))
        allp.append(tris)
    if allp:
        # Une seule collection : tri de profondeur par triangle (pas par objet).
        pc = Poly3DCollection(np.concatenate(allp), facecolors=np.concatenate(allc), edgecolors=(0, 0, 0, 0.15), linewidths=0.2)
        ax.add_collection3d(pc)
        allp = [np.concatenate(allp).reshape(-1, 3)]
    if not allp:
        return
    pts = np.concatenate(allp)
    mn, mx = pts.min(0), pts.max(0)
    ext = np.maximum(mx - mn, 1e-3)
    ax.set_xlim(mn[0], mx[0])
    ax.set_ylim(mn[1], mx[1])
    ax.set_zlim(mn[2], mx[2])
    ax.set_box_aspect(tuple(ext))
    ax.view_init(elev=elev, azim=azim)
    ax.set_axis_off()


def main():
    out = sys.argv[1]
    grid = "--grid" in sys.argv
    objs = parse(sys.stdin)
    if grid:
        n = len(objs)
        cols = 6
        rows = (n + cols - 1) // cols
        fig = plt.figure(figsize=(cols * 2.6, rows * 2.6))
        for i, o in enumerate(objs):
            ax = fig.add_subplot(rows, cols, i + 1, projection="3d")
            draw(ax, [o], 20, -60)
            ax.set_title(o["name"], fontsize=8)
    else:
        fig = plt.figure(figsize=(16, 11))
        for i, (e, a) in enumerate([(15, -60), (5, 0), (5, -90), (70, -90)]):
            ax = fig.add_subplot(2, 2, i + 1, projection="3d")
            draw(ax, objs, e, a)
    plt.tight_layout()
    plt.savefig(out, dpi=90)


if __name__ == "__main__":
    main()
