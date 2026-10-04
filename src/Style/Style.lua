--!strict
-- Resolves theme links and converts plain project values (hex colours, number arrays) into
-- Roblox datatypes. The project itself never stores Color3 or UDim2, so it stays JSON.

local Themes = require(script.Parent.Themes)

local Style = {}

-- The tokens of a project's theme with its overrides applied.
function Style.tokens(project: any): { [string]: any }
	local theme = Themes.get(project.theme and project.theme.base)
	local tokens = table.clone(theme.tokens)
	for key, value in (project.theme and project.theme.overrides) or {} do
		tokens[key] = value
	end
	return tokens
end

function Style.isToken(value: any): boolean
	return type(value) == "string" and string.sub(value, 1, 1) == "$"
end

-- "$primary" -> the theme value; anything else is returned as is. Tables are resolved deeply.
function Style.resolve(value: any, tokens: { [string]: any }): any
	if Style.isToken(value) then
		local resolved = tokens[string.sub(value, 2)]
		if Style.isToken(resolved) then
			return nil -- no token chains
		end
		return resolved
	elseif type(value) == "table" then
		local copy = {}
		for key, child in value do
			copy[key] = Style.resolve(child, tokens)
		end
		return copy
	end
	return value
end

function Style.parseHex(hex: any): (number?, number?, number?)
	if type(hex) ~= "string" then
		return nil
	end
	local r, g, b = string.match(hex, "^#?(%x%x)(%x%x)(%x%x)$")
	if not r then
		return nil
	end
	return tonumber(r, 16) :: number, tonumber(g, 16) :: number, tonumber(b, 16) :: number
end

function Style.color(hex: any, fallback: Color3?): Color3
	local r, g, b = Style.parseHex(hex)
	if r then
		return Color3.fromRGB(r, g :: number, b :: number)
	end
	return fallback or Color3.new(1, 1, 1)
end

function Style.toHex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255)
	)
end

-- {xScale, xOffset, yScale, yOffset} -> UDim2
function Style.udim2(value: any, fallback: UDim2?): UDim2
	if type(value) == "table" and #value == 4 then
		return UDim2.new(value[1], value[2], value[3], value[4])
	end
	return fallback or UDim2.new()
end

function Style.vector2(value: any, fallback: Vector2?): Vector2
	if type(value) == "table" and #value == 2 then
		return Vector2.new(value[1], value[2])
	end
	return fallback or Vector2.zero
end

function Style.font(name: any): Enum.Font
	local ok, font = pcall(function()
		return (Enum.Font :: any)[name]
	end)
	if ok and font then
		return font
	end
	return Enum.Font.SourceSansBold
end

function Style.number(value: any, fallback: number): number
	if type(value) == "number" then
		return value
	end
	return fallback
end

return Style
