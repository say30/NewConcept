--!strict
-- GuiCreatorId: the stable identifier carried by every node and every generated Instance.
-- It never changes after creation, so regeneration can find what it already built.

local Ids = {}

Ids.ATTRIBUTE = "GuiCreatorId"
Ids.PREFIX = "gc_"

local HEX = "0123456789abcdef"
local LENGTH = 12

local rng = Random.new()

-- Lets tests make ids deterministic.
function Ids.setSeed(seed: number)
	rng = Random.new(seed)
end

function Ids.new(): string
	local chars = table.create(LENGTH)
	for i = 1, LENGTH do
		local n = rng:NextInteger(1, 16)
		chars[i] = string.sub(HEX, n, n)
	end
	return Ids.PREFIX .. table.concat(chars)
end

-- Returns an id that is not a key of `taken`.
function Ids.newUnique(taken: { [string]: any }): string
	local id = Ids.new()
	while taken[id] ~= nil do
		id = Ids.new()
	end
	return id
end

function Ids.isValid(value: any): boolean
	return type(value) == "string" and string.match(value, "^gc_%x+$") ~= nil
end

return Ids
