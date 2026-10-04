--!strict
-- Table helpers for the plain-data project model.

local Table = {}

function Table.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[Table.deepCopy(key)] = Table.deepCopy(child)
	end
	return copy :: any
end

function Table.deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not Table.deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- Reads a nested value: getPath(t, {"text", "size"}) == t.text.size
function Table.getPath(root: any, path: { string }): any
	local current = root
	for _, key in path do
		if type(current) ~= "table" then
			return nil
		end
		current = current[key]
	end
	return current
end

-- Writes a nested value, creating intermediate tables. A nil value removes the key.
function Table.setPath(root: any, path: { string }, value: any)
	assert(#path > 0, "setPath needs a non-empty path")
	local current = root
	for i = 1, #path - 1 do
		local key = path[i]
		if type(current[key]) ~= "table" then
			current[key] = {}
		end
		current = current[key]
	end
	current[path[#path]] = value
end

return Table
