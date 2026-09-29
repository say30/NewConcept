#!/usr/bin/env python3
"""Construit CreatureForge.rbxmx (plugin local Roblox Studio) à partir de src/.

  src/Main.server.lua   -> Script "Main"
  src/<Dossier>/        -> Folder
  src/**/<Nom>.lua      -> ModuleScript

Usage : python3 tools/build_plugin.py [sortie.rbxmx]
Puis copiez le fichier dans le dossier Plugins de Studio
(Studio > onglet Plugins > « Plugins Folder »).
Équivalent Rojo : rojo build default.project.json -o CreatureForge.rbxmx
"""
import itertools
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
_ids = itertools.count(1)


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, source=None, children=()):
    ref = "RBX%08X" % next(_ids)
    props = [f'<string name="Name">{escape(name)}</string>']
    if source is not None:
        props.append(f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>')
    inner = "".join(children)
    return f'<Item class="{cls}" referent="{ref}"><Properties>{"".join(props)}</Properties>{inner}</Item>'


def build_dir(path, name):
    children = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if entry.startswith("."):
            continue
        if os.path.isdir(full):
            children.append(build_dir(full, entry))
        elif entry.endswith(".server.lua"):
            with open(full, encoding="utf-8") as fh:
                children.append(item("Script", entry[: -len(".server.lua")], fh.read()))
        elif entry.endswith(".lua"):
            with open(full, encoding="utf-8") as fh:
                children.append(item("ModuleScript", entry[:-4], fh.read()))
    return item("Folder", name, None, children)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "CreatureForge.rbxmx")
    body = build_dir(SRC, "CreatureForge")
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        f"{body}</roblox>"
    )
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(xml)
    print("OK ->", out)


if __name__ == "__main__":
    main()
