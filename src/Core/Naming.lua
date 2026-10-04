--!strict
-- Readable, unique names. The name a developer types is the name the generated Instance gets,
-- so "Buy button!" becomes "BuyButton" and a second one becomes "BuyButton2".

local Naming = {}

local MAX_LENGTH = 50

-- Turns any user input into a clean PascalCase identifier.
function Naming.sanitize(raw: string, fallback: string?): string
	local words = {}
	for word in string.gmatch(raw, "[%w]+") do
		table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	local name = table.concat(words)
	if string.match(name, "^%d") then
		name = "_" .. name
	end
	name = string.sub(name, 1, MAX_LENGTH)
	if name == "" then
		return fallback or "Element"
	end
	return name
end

-- Appends 2, 3, ... until the name is not in `taken` (a set of names).
function Naming.unique(base: string, taken: { [string]: boolean }): string
	if not taken[base] then
		return base
	end
	local stem = string.match(base, "^(.-)%d+$") or base
	if stem == "" then
		stem = base
	end
	local index = 2
	while taken[stem .. index] do
		index += 1
	end
	return stem .. index
end

return Naming
