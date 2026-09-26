#!/usr/bin/env python3
"""
Assemble un fichier Luau autonome pour exécuter les modules du plugin avec la
CLI `luau` : mock de l'API Roblox + modules (enveloppés dans des fonctions
recevant un faux `script`) + helpers + specs de test.

Usage : python3 tests/bundle.py > build/test_bundle.luau && luau build/test_bundle.luau
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "src")


def collect_modules():
    modules = []
    for dirpath, _, files in os.walk(SRC):
        for f in sorted(files):
            if not f.endswith(".luau") or f.startswith("init."):
                continue
            rel = os.path.relpath(os.path.join(dirpath, f), SRC)
            path = rel[: -len(".luau")].replace(os.sep, "/")
            with open(os.path.join(dirpath, f), encoding="utf-8") as fh:
                modules.append((path, fh.read()))
    modules.sort()
    return modules


def main():
    out = []
    with open(os.path.join(HERE, "mocks", "Roblox.luau"), encoding="utf-8") as fh:
        mock = fh.read()
    out.append("local __mock = (function()\n" + mock + "\nend)()")
    out.append(
        """
local typeof = __mock.typeof
local Vector3, Vector2, CFrame, Color3, Enum, Instance = __mock.Vector3, __mock.Vector2, __mock.CFrame, __mock.Color3, __mock.Enum, __mock.Instance
local game, workspace, task, Random = __mock.game, __mock.workspace, __mock.task, __mock.Random
local OverlapParams, RaycastParams = __mock.OverlapParams, __mock.RaycastParams
local warn = function(...) print("[warn]", ...) end
local UDim, UDim2 = __mock.UDim, __mock.UDim2

-- Arborescence de faux `script` (comme Rojo : dossiers + ModuleScripts).
local __NodeMT = {}
__NodeMT.__index = function(node, key)
	if key == "Parent" then
		return rawget(node, "__parent")
	end
	local child = rawget(node, "__children")[key]
	if child == nil then
		error("Mock script tree: no child '" .. tostring(key) .. "' under '" .. rawget(node, "__path") .. "'", 2)
	end
	return child
end
local function __newNode(name, parent, path)
	local node = setmetatable({ __name = name, __parent = parent, __children = {}, __path = path }, __NodeMT)
	if parent then
		rawget(parent, "__children")[name] = node
	end
	return node
end
local ROOT = __newNode("ProceduralComposer", nil, "")
local function __ensure(path)
	local node = ROOT
	local acc = ""
	for part in string.gmatch(path, "[^/]+") do
		acc = if acc == "" then part else acc .. "/" .. part
		local children = rawget(node, "__children")
		node = children[part] or __newNode(part, node, acc)
	end
	return node
end
local __modules = {}
local __cache = {}
local function require(node)
	local path = rawget(node, "__path")
	local cached = __cache[path]
	if cached ~= nil then
		return cached
	end
	local fn = __modules[path]
	if not fn then
		error("Module not found: " .. tostring(path))
	end
	local result = fn(node)
	__cache[path] = result
	return result
end
"""
    )
    for path, source in collect_modules():
        out.append(f'__ensure("{path}")')
        out.append(f'__modules["{path}"] = function(script)\n{source}\nend')
    for name in ["helpers.luau"]:
        with open(os.path.join(HERE, name), encoding="utf-8") as fh:
            out.append(fh.read())
    specs_dir = os.path.join(HERE, "specs")
    for f in sorted(os.listdir(specs_dir)):
        if f.endswith(".luau"):
            with open(os.path.join(specs_dir, f), encoding="utf-8") as fh:
                out.append("do -- " + f + "\n" + fh.read() + "\nend")
    out.append("runAllTests()")
    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main()
