-- Test runner for the plugin's pure-Luau modules, run with Lune: `lune run tests/run`
--
-- Plugin modules use Roblox-style requires (`require(script.Parent.Document)`). The loader
-- below gives each module a fake `script` that maps to the src/ folder, so the same files
-- run unchanged here and in Studio.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local loader = require("./loader")
local src, requireModule, roblox = loader.src, loader.require, loader.roblox

--------------------------------------------------------------------------------
-- Tiny test framework
--------------------------------------------------------------------------------

local passed, failed = 0, 0
local currentGroup = ""

local function describe(name: string, body: () -> ())
	currentGroup = name
	body()
	currentGroup = ""
end

local function it(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		print(string.format("FAIL  %s > %s\n      %s", currentGroup, name, tostring(err)))
	end
end

local function expect(actual: any)
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				error(string.format("expected %s, got %s", tostring(expected), tostring(actual)), 2)
			end
		end,
		toBeTruthy = function()
			if not actual then
				error("expected a truthy value, got " .. tostring(actual), 2)
			end
		end,
		toBeNil = function()
			if actual ~= nil then
				error("expected nil, got " .. tostring(actual), 2)
			end
		end,
		toThrow = function(fragment: string?)
			local ok, err = pcall(actual)
			if ok then
				error("expected an error", 2)
			end
			if fragment and not string.find(tostring(err), fragment, 1, true) then
				error(string.format("expected error containing %q, got %s", fragment, tostring(err)), 2)
			end
		end,
	}
end

local context = {
	src = src,
	require = requireModule,
	describe = describe,
	it = it,
	expect = expect,
	roblox = roblox,
}

local specs = {}
for _, entry in fs.readDir("tests/specs") do
	if string.match(entry, "%.spec%.luau$") then
		table.insert(specs, entry)
	end
end
table.sort(specs)

for _, spec in specs do
	local chunk = luau.load(fs.readFile("tests/specs/" .. spec), { debugName = spec })
	chunk()(context)
end

print(string.format("\n%d passed, %d failed", passed, failed))
process.exit(if failed == 0 then 0 else 1)
