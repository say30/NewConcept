--!strict
-- What each kind of element is, what it can contain and its default look.
-- Values written "$name" follow the project's style pack (Style/Packs).

export type NodeType = {
	label: string,
	icon: string, -- icon id from Visual/Icons shown in the editor
	container: boolean,
	surface: boolean, -- drawn with fill, outline, pattern, shadow and shine
	canAdd: { string },
	defaults: { [string]: any },
}

local CHILDREN =
	{ "Button", "Text", "Input", "Icon", "Image", "Card", "Panel", "Grid", "List", "ScrollArea", "Window" }

local CENTER = { 0.5, 0, 0.5, 0 }

local function surface(fillColor: string, opts: any?): { [string]: any }
	opts = opts or {}
	return {
		fill = {
			kind = opts.fillKind or "Shade",
			color = fillColor,
			color2 = "$body",
			shade = "$shade",
			rotation = 90,
			transparency = 0,
			image = "",
			scaleType = "Stretch",
			tileSize = 64,
			tint = "#FFFFFF",
		},
		stroke = {
			enabled = opts.stroke ~= false,
			color = "$outline",
			thickness = "$outlineThickness",
			transparency = 0,
		},
		corner = opts.corner or "$radiusSmall",
		pattern = {
			kind = opts.pattern or "None",
			color = "$patternColor",
			transparency = "$patternTransparency",
			size = "$patternSize",
		},
		shadow = {
			kind = opts.shadow or "None",
			size = opts.shadowSize or "$depth",
			color = "$outline",
			transparency = 0.55,
		},
		shine = opts.shine or false,
	}
end

local function text(value: string, size: number, opts: any?): { [string]: any }
	opts = opts or {}
	return {
		value = value,
		font = opts.font or "$font",
		size = size,
		scaled = false,
		color = opts.color or "$text",
		alignX = opts.alignX or "Center",
		alignY = "Center",
		wrap = opts.wrap or false,
		transparency = 0,
		stroke = { enabled = "$textStroke", color = "$outline", thickness = opts.strokeThickness or 2 },
	}
end

local function merge(...: { [string]: any }): { [string]: any }
	local result = {}
	for _, part in { ... } do
		for key, value in part do
			result[key] = value
		end
	end
	return result
end

local function base(size: { number }, zIndex: number): { [string]: any }
	return {
		position = CENTER,
		size = size,
		anchor = { 0.5, 0.5 },
		rotation = 0,
		zIndex = zIndex,
		visible = true,
		clip = false,
		aspect = 0,
	}
end

local function layout(kind: string, opts: any?): { [string]: any }
	opts = opts or {}
	return {
		kind = kind,
		spacing = opts.spacing or 10,
		padding = opts.padding or 8,
		align = "Center",
		columns = opts.columns or 3,
		cellWidth = 120,
		cellHeight = opts.cellHeight or 150,
	}
end

local NodeTypes: { [string]: NodeType } = {
	Page = {
		label = "Page",
		icon = "Home",
		container = true,
		surface = false,
		canAdd = CHILDREN,
		defaults = {},
	},
	Window = {
		label = "Fenêtre",
		icon = "Shop",
		container = true,
		surface = true,
		canAdd = CHILDREN,
		defaults = merge(
			base({ 0, 560, 0, 380 }, 1),
			surface("$frame", { corner = "$radius", shadow = "Drop", shadowSize = 8 })
		),
	},
	Panel = {
		label = "Panneau",
		icon = "Calendar",
		container = true,
		surface = true,
		canAdd = CHILDREN,
		defaults = merge(
			base({ 0, 240, 0, 140 }, 1),
			surface("$body", { fillKind = "Color", pattern = "$bodyPattern" })
		),
	},
	Card = {
		label = "Carte",
		icon = "Gift",
		container = true,
		surface = true,
		canAdd = CHILDREN,
		defaults = merge(
			base({ 0, 150, 0, 190 }, 1),
			surface("$card", { pattern = "$cardPattern", shadow = "Depth" })
		),
	},
	Button = {
		label = "Bouton",
		icon = "ArrowRight",
		container = true,
		surface = true,
		canAdd = { "Icon", "Text", "Image" },
		defaults = merge(
			base({ 0, 170, 0, 56 }, 2),
			surface("$primary", { shadow = "Depth", shine = "$shine" }),
			{
				text = text("Bouton", 24, { color = "$textOnButton" }),
				icon = { id = "", image = "" },
			}
		),
	},
	Text = {
		label = "Texte",
		icon = "Ticket",
		container = false,
		surface = false,
		canAdd = {},
		defaults = merge(base({ 0, 240, 0, 44 }, 2), { text = text("Texte", 28) }),
	},
	Input = {
		label = "Zone de saisie",
		icon = "Ticket",
		container = false,
		surface = false,
		canAdd = {},
		defaults = merge(base({ 0, 300, 0, 52 }, 2), {
			text = merge(
				text("", 22, { color = "$textDark" }),
				{ placeholder = "Écris ici...", placeholderColor = "#8A8FA3" }
			),
			fill = { kind = "Color", color = "#FFFFFF", transparency = 0 },
			stroke = { enabled = true, color = "$outline", thickness = "$outlineThickness", transparency = 0 },
			corner = "$radiusSmall",
		}),
	},
	Icon = {
		label = "Icône",
		icon = "Coin",
		container = false,
		surface = false,
		canAdd = {},
		defaults = merge(
			base({ 0, 56, 0, 56 }, 2),
			{ aspect = 1, icon = { id = "Coin", image = "", color = "#FFFFFF" } }
		),
	},
	Image = {
		label = "Image",
		icon = "Pin",
		container = false,
		surface = false,
		canAdd = {},
		defaults = merge(
			base({ 0, 120, 0, 120 }, 2),
			{ image = { id = "", color = "#FFFFFF", transparency = 0, scaleType = "Fit" }, corner = 0 }
		),
	},
	Grid = {
		label = "Grille",
		icon = "Podium",
		container = true,
		surface = false,
		canAdd = CHILDREN,
		defaults = merge(base({ 0.9, 0, 0.6, 0 }, 1), { layout = layout("Grid", { spacing = 12 }) }),
	},
	List = {
		label = "Liste",
		icon = "ArrowUp",
		container = true,
		surface = false,
		canAdd = CHILDREN,
		defaults = merge(base({ 0, 260, 0, 280 }, 1), { layout = layout("Vertical") }),
	},
	ScrollArea = {
		label = "Zone défilante",
		icon = "ArrowUp",
		container = true,
		surface = false,
		canAdd = CHILDREN,
		defaults = merge(
			base({ 0.9, 0, 0.65, 0 }, 1),
			{ clip = true, layout = layout("Grid", { spacing = 12 }) }
		),
	},
}

local Schema = {}

Schema.types = NodeTypes

function Schema.get(typeName: string): NodeType
	return NodeTypes[typeName] or NodeTypes.Panel
end

local function isDict(value: any): boolean
	return type(value) == "table" and next(value) ~= nil and #value == 0
end

local function deepMerge(target: { [string]: any }, source: { [string]: any })
	for key, value in source do
		if isDict(value) and isDict(target[key]) then
			deepMerge(target[key], value)
		elseif type(value) == "table" then
			target[key] = table.clone(value)
		else
			target[key] = value
		end
	end
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

-- A node's props merged over its type defaults, at every depth.
function Schema.effectiveProps(node: any): { [string]: any }
	local result = deepCopy(Schema.get(node.type).defaults)
	deepMerge(result, node.props or {})
	return result
end

return Schema
