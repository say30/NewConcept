--!strict
-- Style packs. A pack is a set of named values (tokens) that every built-in model uses:
-- any property written as "$frame" or "$radius" follows the project's pack, so switching
-- pack re-skins the whole interface at once while keeping its layout.

export type Pack = {
	name: string,
	label: string,
	tokens: { [string]: any },
}

local function pack(name: string, label: string, tokens: { [string]: any }): Pack
	return { name = name, label = label, tokens = tokens }
end

-- Values every pack shares unless it says otherwise.
local BASE = {
	font = "FredokaOne",
	fontTitle = "FredokaOne",
	outline = "#1F1A2E",
	outlineThickness = 3,
	radius = 16,
	radiusSmall = 10,
	text = "#FFFFFF",
	textDark = "#1F1A2E",
	textMuted = "#D9E2EC",
	textStroke = true,
	textOnButton = "#FFFFFF",
	patternTransparency = 0.82,
	patternSize = 26,
	cardPattern = "None",
	shade = 0.28,
	shine = true,
	depth = 4,
	slot = "#2A2440",
	primary = "#3FA9F5",
	success = "#5ED65A",
	danger = "#FF4D4D",
	warning = "#FFC531",
	accent1 = "#7ED957",
	accent2 = "#FFA43B",
	accent3 = "#B76BFF",
	accent4 = "#4FC3F7",
	backdrop = "#8FD3F5",
}

local function with(values: { [string]: any }): { [string]: any }
	local tokens = table.clone(BASE)
	for key, value in values do
		tokens[key] = value
	end
	return tokens
end

local PACKS: { Pack } = {
	pack(
		"Studs",
		"Studs",
		with({
			fontTitle = "LuckiestGuy",
			frame = "#2F7BEA",
			body = "#5AA9F7",
			bodyPattern = "Studs",
			patternColor = "#FFFFFF",
			patternTransparency = 0.72,
			header = "#FFC531",
			card = "#E8F3FF",
			cardText = "#1F1A2E",
			primary = "#2F7BEA",
			backdrop = "#9AD7F7",
		})
	),
	pack(
		"Garden",
		"Jardin",
		with({
			frame = "#9A6332",
			body = "#5C3A1E",
			bodyPattern = "Diamonds",
			patternColor = "#000000",
			patternTransparency = 0.8,
			header = "#8FE04A",
			card = "#5DBB3F",
			cardPattern = "Diamonds",
			cardText = "#FFFFFF",
			primary = "#8FE04A",
			radius = 10,
			radiusSmall = 6,
			backdrop = "#7FC8E8",
		})
	),
	pack(
		"Cartoon",
		"Cartoon",
		with({
			frame = "#3FA9F5",
			body = "#DDF1FF",
			bodyPattern = "Dots",
			patternColor = "#3FA9F5",
			patternTransparency = 0.8,
			header = "#FF8A3D",
			card = "#FFFFFF",
			cardText = "#1F1A2E",
			primary = "#3FA9F5",
			radius = 20,
			radiusSmall = 14,
		})
	),
	pack(
		"Candy",
		"Bonbon",
		with({
			frame = "#FF5FAE",
			body = "#FFE1F0",
			bodyPattern = "Checker",
			patternColor = "#FF9FCF",
			patternTransparency = 0.7,
			header = "#B76BFF",
			card = "#FFFFFF",
			cardText = "#5A2147",
			primary = "#FF5FAE",
			outline = "#5A2147",
			radius = 22,
			radiusSmall = 14,
			backdrop = "#FFC9E4",
		})
	),
	pack(
		"Ocean",
		"Océan",
		with({
			frame = "#3D8FB8",
			body = "#7CC6DE",
			bodyPattern = "Stripes",
			patternColor = "#FFFFFF",
			patternTransparency = 0.85,
			header = "#2B6F96",
			card = "#5AB0CC",
			cardText = "#FFFFFF",
			primary = "#2B6F96",
			outline = "#123247",
			radius = 22,
			radiusSmall = 16,
			backdrop = "#A8E3F5",
		})
	),
	pack(
		"Neon",
		"Néon",
		with({
			font = "GothamBold",
			fontTitle = "Michroma",
			frame = "#1A2147",
			body = "#0D1230",
			bodyPattern = "Grid",
			patternColor = "#39E6FF",
			patternTransparency = 0.86,
			header = "#7A3CFF",
			card = "#202A5C",
			cardText = "#FFFFFF",
			primary = "#00C2FF",
			outline = "#39E6FF",
			outlineThickness = 2,
			accent1 = "#00E6A8",
			accent2 = "#FF3DB8",
			accent3 = "#7A3CFF",
			accent4 = "#00C2FF",
			textStroke = false,
			radius = 8,
			radiusSmall = 6,
			backdrop = "#05081C",
		})
	),
	pack(
		"Dark",
		"Sombre",
		with({
			font = "GothamBold",
			fontTitle = "GothamBlack",
			frame = "#2C2F3A",
			body = "#1D1F27",
			bodyPattern = "None",
			patternColor = "#FFFFFF",
			header = "#3A3E4D",
			card = "#2C2F3A",
			cardText = "#FFFFFF",
			primary = "#5865F2",
			outline = "#0E0F14",
			outlineThickness = 2,
			textStroke = false,
			shine = false,
			radius = 12,
			radiusSmall = 8,
			backdrop = "#3B4152",
		})
	),
	pack(
		"Minimal",
		"Minimal",
		with({
			font = "GothamBold",
			fontTitle = "GothamBlack",
			frame = "#FFFFFF",
			body = "#F2F4F7",
			bodyPattern = "None",
			patternColor = "#000000",
			header = "#FFFFFF",
			card = "#FFFFFF",
			cardText = "#1F2430",
			text = "#1F2430",
			textMuted = "#6B7280",
			primary = "#2563EB",
			outline = "#D4D9E1",
			outlineThickness = 2,
			textStroke = false,
			shade = 0,
			shine = false,
			depth = 0,
			slot = "#E5E9F0",
			radius = 14,
			radiusSmall = 10,
			backdrop = "#CBD5E1",
		})
	),
}

local BY_NAME: { [string]: Pack } = {}
local ORDER = {}
for _, p in PACKS do
	BY_NAME[p.name] = p
	table.insert(ORDER, p.name)
end

local Packs = {}

Packs.ORDER = ORDER
Packs.DEFAULT = "Studs"

function Packs.list(): { Pack }
	return PACKS
end

function Packs.get(name: string?): Pack
	return BY_NAME[name or Packs.DEFAULT] or BY_NAME[Packs.DEFAULT]
end

return Packs
