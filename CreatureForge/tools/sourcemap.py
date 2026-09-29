#!/usr/bin/env python3
"""Génère sourcemap.json (format Rojo) pour l'analyse statique avec luau-lsp."""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")


def node(path):
    rel = os.path.relpath(path, ROOT)
    if os.path.isdir(path):
        children = [node(os.path.join(path, n)) for n in sorted(os.listdir(path)) if not n.startswith(".")]
        return {"name": os.path.basename(path), "className": "Folder", "filePaths": [rel], "children": children}
    name = os.path.basename(path)
    if name.endswith(".server.lua"):
        return {"name": name[: -len(".server.lua")], "className": "Script", "filePaths": [rel]}
    return {"name": name[:-4], "className": "ModuleScript", "filePaths": [rel]}


tree = node(SRC)
tree["name"] = "CreatureForge"
with open(os.path.join(ROOT, "sourcemap.json"), "w") as fh:
    json.dump(tree, fh, indent=1)
