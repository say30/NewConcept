-- Test runner for the plugin's pure-Luau modules, run with Lune: `lune run tests/run`
--
-- Plugin modules use Roblox-style requires (`require(script.Parent.Document)`). The loader
-- below gives each module a fake `script` that maps to the src/ folder, so the same files
-- run unchanged here and in Studio.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local SRC = "src"

--------------------------------------------------------------------------------
-- Globals Roblox has and Lune does not
--------------------------------------------------------------------------------

-- Deterministic stand-in for Roblox's Random.
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed: number?)
	return setmetatable({ state = (seed or 12345) % 2147483647 }, RandomShim)
end
function RandomShim:NextInteger(min: number, max: number): number
	self.state = (self.state * 48271) % 2147483647
	return min + self.state % (max - min + 1)
end

local globals = {
	Random = RandomShim,
	task = require("@lune/task"),
}
for _, name in
	{
		"Instance",
		"Enum",
		"Color3",
		"ColorSequence",
		"ColorSequenceKeypoint",
		"NumberSequence",
		"UDim",
		"UDim2",
		"Vector2",
		"Vector3",
		"Rect",
		"Font",
	}
do
	globals[name] = (roblox :: any)[name]
end

--------------------------------------------------------------------------------
-- Module loader
--------------------------------------------------------------------------------

local cache = {}
local proxies = {}

-- fs calls yield, and metamethods cannot yield, so the src tree is listed up front.
local dirs, files = {}, {}
local function scan(path: string)
	dirs[path] = true
	for _, entry in fs.readDir(path) do
		local child = path .. "/" .. entry
		if fs.isDir(child) then
			scan(child)
		else
			files[child] = true
		end
	end
end
scan(SRC)

local function moduleFile(path: string, isDir: boolean): string?
	if isDir then
		for _, candidate in { path .. "/init.lua", path .. "/init.luau" } do
			if files[candidate] then
				return candidate
			end
		end
		return nil
	end
	for _, candidate in { path .. ".lua", path .. ".luau" } do
		if files[candidate] then
			return candidate
		end
	end
	return nil
end

local function proxyFor(path: string, name: string, isDir: boolean, parent: any)
	if proxies[path] then
		return proxies[path]
	end
	local proxy = setmetatable({}, {
		__index = function(_, key)
			if key == "Parent" then
				return parent
			elseif key == "Name" then
				return name
			end
			local childPath = path .. "/" .. key
			if isDir and dirs[childPath] then
				return proxyFor(childPath, key, true, proxies[path])
			elseif isDir and moduleFile(childPath, false) then
				return proxyFor(childPath, key, false, proxies[path])
			end
			error(string.format("%s is not a valid member of %s", key, path), 2)
		end,
		__tostring = function()
			return path
		end,
	})
	proxies[path] = proxy
	rawset(proxy, "__path", path)
	rawset(proxy, "__isDir", isDir)
	return proxy
end

local requireModule

function requireModule(target: any)
	local path = rawget(target, "__path")
	assert(path, "require expects a module from src")
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = moduleFile(path, rawget(target, "__isDir"))
	assert(file, "No module at " .. path)

	local env = { script = target, require = requireModule }
	for key, value in globals do
		env[key] = value
	end
	local chunk = luau.load(fs.readFile(file), { debugName = file, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

local src = proxyFor(SRC, "GuiCreator", true, nil)

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
