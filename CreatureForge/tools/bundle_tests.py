#!/usr/bin/env python3
"""Assemble les modules du plugin + mocks + un script de test en un seul fichier Luau
exécutable par le CLI `luau` (hors Roblox Studio).

Chaque module est enveloppé dans une fonction recevant un faux `script` dont
`.Parent` / enfants reproduisent l'arborescence src/, afin que
`require(script.Parent.X)` fonctionne comme dans Studio.

Usage : python3 tools/bundle_tests.py tests/test_pipeline.lua > /tmp/bundle.lua
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")


def collect():
    modules = {}
    for dirpath, _, files in os.walk(SRC):
        for f in sorted(files):
            if not f.endswith(".lua") or f.endswith(".server.lua"):
                continue
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, SRC)[:-4].replace(os.sep, "/")
            with open(full, encoding="utf-8") as fh:
                modules[rel] = fh.read()
    return modules


def main():
    test_file = sys.argv[1]
    out = []
    with open(os.path.join(ROOT, "tests", "mocks.lua"), encoding="utf-8") as fh:
        out.append(fh.read())
    out.append(
        """
local __sources = {}
local __cache = {}
local __nodes = {}
local function __node(path)
    if __nodes[path] then return __nodes[path] end
    local node = { __path = path }
    __nodes[path] = node
    setmetatable(node, { __index = function(t, k)
        if k == "Parent" then
            local parent = path:match("^(.*)/[^/]+$") or ""
            if path == "" then return nil end
            return __node(parent)
        end
        local child = (path == "" and k) or (path .. "/" .. k)
        return __node(child)
    end })
    return node
end
local function require(node)
    local path = node.__path
    if __cache[path] ~= nil then return __cache[path] end
    local src = __sources[path]
    if not src then error("module introuvable: " .. tostring(path)) end
    local result = src(__node(path), require)
    __cache[path] = result
    return result
end
ROOT_SCRIPT = __node("")
REQUIRE = require
"""
    )
    for rel, code in collect().items():
        out.append(f'__sources["{rel}"] = function(script, require)\n{code}\nend\n')
    with open(test_file, encoding="utf-8") as fh:
        out.append(fh.read())
    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main()
