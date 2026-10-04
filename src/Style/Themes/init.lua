--!strict
-- The three V1 themes. A theme is a set of named values (tokens); any property written as
-- "$primary" or "$radius" follows the current theme.

local Themes = {
	Cartoon = require(script.Cartoon),
	Flat = require(script.Flat),
	Studs = require(script.Studs),
}

local ORDER = { "Cartoon", "Flat", "Studs" }

local function list()
	local result = {}
	for _, name in ORDER do
		table.insert(result, Themes[name])
	end
	return result
end

local function get(name: string?)
	return Themes[name or "Cartoon"] or Themes.Cartoon
end

return {
	list = list,
	get = get,
	ORDER = ORDER,
}
