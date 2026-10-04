--!strict
-- What each kind of element is, what it can contain and which inspector sections it shows.
-- Adding a new kind of element means adding an entry here; the inspector follows.

export type NodeType = {
	label: string,
	glyph: string,
	container: boolean,
	canAdd: { string },
	sections: { string },
	quick: { { string } }, -- property paths shown in "Style rapide"
	defaults: { [string]: any },
}

local CHILDREN =
	{ "Button", "Text", "Image", "Icon", "Card", "Panel", "Grid", "List", "ScrollArea", "Window" }

local CENTER = { 0.5, 0, 0.5, 0 }

local NodeTypes: { [string]: NodeType } = {
	Page = {
		label = "Page",
		glyph = "▣",
		container = true,
		canAdd = CHILDREN,
		sections = {},
		quick = {},
		defaults = {},
	},
	Window = {
		label = "Fenêtre",
		glyph = "▢",
		container = true,
		canAdd = CHILDREN,
		sections = { "Fill", "Stroke", "Corner", "Transform", "Layout", "Display" },
		quick = { { "fill", "color" }, { "corner" }, { "stroke", "enabled" } },
		defaults = {
			position = CENTER,
			size = { 0, 520, 0, 360 },
			anchor = { 0.5, 0.5 },
			fill = {
				kind = "Color",
				color = "$background",
				color2 = "$surface",
				rotation = 90,
				transparency = 0,
			},
			corner = "$radius",
			stroke = { enabled = true, color = "$stroke", thickness = "$strokeThickness", transparency = 0 },
			layout = {
				kind = "None",
				spacing = 10,
				padding = 12,
				align = "Center",
				cellWidth = 120,
				cellHeight = 150,
			},
			visible = true,
			zIndex = 1,
			clip = false,
		},
	},
	Panel = {
		label = "Panneau",
		glyph = "▭",
		container = true,
		canAdd = CHILDREN,
		sections = { "Fill", "Stroke", "Corner", "Transform", "Layout", "Display" },
		quick = { { "fill", "color" }, { "corner" } },
		defaults = {
			position = CENTER,
			size = { 0, 220, 0, 120 },
			anchor = { 0.5, 0.5 },
			fill = {
				kind = "Color",
				color = "$surface",
				color2 = "$background",
				rotation = 90,
				transparency = 0,
			},
			corner = "$radiusSmall",
			stroke = { enabled = false, color = "$stroke", thickness = "$strokeThickness", transparency = 0 },
			layout = {
				kind = "None",
				spacing = 8,
				padding = 8,
				align = "Center",
				cellWidth = 100,
				cellHeight = 100,
			},
			visible = true,
			zIndex = 1,
			clip = false,
		},
	},
	Card = {
		label = "Carte",
		glyph = "▤",
		container = true,
		canAdd = CHILDREN,
		sections = { "Fill", "Stroke", "Corner", "Transform", "Layout", "Display" },
		quick = { { "fill", "color" }, { "corner" }, { "stroke", "color" } },
		defaults = {
			position = CENTER,
			size = { 0, 140, 0, 180 },
			anchor = { 0.5, 0.5 },
			fill = {
				kind = "Color",
				color = "$surface",
				color2 = "$background",
				rotation = 90,
				transparency = 0,
			},
			corner = "$radiusSmall",
			stroke = { enabled = true, color = "$stroke", thickness = "$strokeThickness", transparency = 0 },
			layout = {
				kind = "None",
				spacing = 6,
				padding = 8,
				align = "Center",
				cellWidth = 100,
				cellHeight = 100,
			},
			visible = true,
			zIndex = 1,
			clip = false,
		},
	},
	Text = {
		label = "Texte",
		glyph = "T",
		container = false,
		canAdd = {},
		sections = { "Text", "Fill", "Stroke", "Corner", "Transform", "Display" },
		quick = { { "text", "value" }, { "text", "color" }, { "text", "size" } },
		defaults = {
			position = CENTER,
			size = { 0, 220, 0, 44 },
			anchor = { 0.5, 0.5 },
			text = {
				value = "Texte",
				font = "$font",
				size = 26,
				scaled = false,
				color = "$text",
				alignX = "Center",
				wrap = true,
				transparency = 0,
				strokeEnabled = false,
				strokeColor = "$stroke",
			},
			fill = {
				kind = "None",
				color = "$surface",
				color2 = "$background",
				rotation = 90,
				transparency = 0,
			},
			corner = 0,
			stroke = { enabled = false, color = "$stroke", thickness = 1, transparency = 0 },
			visible = true,
			zIndex = 2,
			clip = false,
		},
	},
	Button = {
		label = "Bouton",
		glyph = "◉",
		container = true,
		canAdd = { "Icon", "Image", "Text" },
		sections = { "Text", "Fill", "Stroke", "Corner", "Transform", "Display" },
		quick = { { "text", "value" }, { "fill", "color" }, { "corner" } },
		defaults = {
			position = CENTER,
			size = { 0, 170, 0, 54 },
			anchor = { 0.5, 0.5 },
			text = {
				value = "Bouton",
				font = "$font",
				size = 24,
				scaled = false,
				color = "$textOnPrimary",
				alignX = "Center",
				wrap = false,
				transparency = 0,
				strokeEnabled = false,
				strokeColor = "$stroke",
			},
			fill = { kind = "Color", color = "$primary", color2 = "$accent", rotation = 90, transparency = 0 },
			corner = "$radiusSmall",
			stroke = { enabled = true, color = "$stroke", thickness = "$strokeThickness", transparency = 0 },
			visible = true,
			zIndex = 2,
			clip = false,
		},
	},
	Image = {
		label = "Image",
		glyph = "▨",
		container = false,
		canAdd = {},
		sections = { "Image", "Fill", "Stroke", "Corner", "Transform", "Display" },
		quick = { { "image", "id" }, { "image", "color" } },
		defaults = {
			position = CENTER,
			size = { 0, 120, 0, 120 },
			anchor = { 0.5, 0.5 },
			image = { id = "", color = "#FFFFFF", transparency = 0, scaleType = "Fit" },
			fill = {
				kind = "None",
				color = "$surface",
				color2 = "$background",
				rotation = 90,
				transparency = 0,
			},
			corner = 0,
			stroke = { enabled = false, color = "$stroke", thickness = 1, transparency = 0 },
			visible = true,
			zIndex = 2,
			clip = false,
		},
	},
	Icon = {
		label = "Icône",
		glyph = "★",
		container = false,
		canAdd = {},
		sections = { "Image", "Fill", "Stroke", "Corner", "Transform", "Display" },
		quick = { { "image", "id" }, { "image", "color" } },
		defaults = {
			position = CENTER,
			size = { 0, 48, 0, 48 },
			anchor = { 0.5, 0.5 },
			image = { id = "", color = "#FFFFFF", transparency = 0, scaleType = "Fit" },
			fill = {
				kind = "None",
				color = "$surface",
				color2 = "$background",
				rotation = 90,
				transparency = 0,
			},
			corner = 0,
			stroke = { enabled = false, color = "$stroke", thickness = 1, transparency = 0 },
			visible = true,
			zIndex = 3,
			clip = false,
			aspect = 1,
		},
	},
	Grid = {
		label = "Grille",
		glyph = "▦",
		container = true,
		canAdd = CHILDREN,
		sections = { "Layout", "Fill", "Stroke", "Corner", "Transform", "Display" },
		quick = { { "layout", "cellWidth" }, { "layout", "spacing" } },
		defaults = {
			position = CENTER,
			size = { 0.9, 0, 0.6, 0 },
			anchor = { 0.5, 0.5 },
			fill = {
				kind = "None",
				color = "$surface",
				color2 = "$background",
				rotation = 90,
				transparency = 0,
			},
			corner = 0,
			stroke = { enabled = false, color = "$stroke", thickness = 1, transparency = 0 },
			layout = {
				kind = "Grid",
				spacing = 12,
				padding = 8,
				align = "Center",
				cellWidth = 120,
				cellHeight = 150,
			},
			visible = true,
			zIndex = 1,
			clip = false,
		},
	},
	List = {
		label = "Liste",
		glyph = "☰",
		container = true,
		canAdd = CHILDREN,
		sections = { "Layout", "Fill", "Stroke", "Corner", "Transform", "Display" },
		quick = { { "layout", "kind" }, { "layout", "spacing" } },
		defaults = {
			position = CENTER,
			size = { 0, 240, 0, 260 },
			anchor = { 0.5, 0.5 },
			fill = {
				kind = "None",
				color = "$surface",
				color2 = "$background",
				rotation = 90,
				transparency = 0,
			},
			corner = 0,
			stroke = { enabled = false, color = "$stroke", thickness = 1, transparency = 0 },
			layout = {
				kind = "Vertical",
				spacing = 8,
				padding = 4,
				align = "Center",
				cellWidth = 100,
				cellHeight = 100,
			},
			visible = true,
			zIndex = 1,
			clip = false,
		},
	},
	ScrollArea = {
		label = "Zone défilante",
		glyph = "⇕",
		container = true,
		canAdd = CHILDREN,
		sections = { "Layout", "Fill", "Stroke", "Corner", "Transform", "Display" },
		quick = { { "layout", "kind" }, { "layout", "cellWidth" } },
		defaults = {
			position = CENTER,
			size = { 0.9, 0, 0.65, 0 },
			anchor = { 0.5, 0.5 },
			fill = {
				kind = "None",
				color = "$surface",
				color2 = "$background",
				rotation = 90,
				transparency = 0,
			},
			corner = 0,
			stroke = { enabled = false, color = "$stroke", thickness = 1, transparency = 0 },
			layout = {
				kind = "Grid",
				spacing = 12,
				padding = 8,
				align = "Center",
				cellWidth = 120,
				cellHeight = 150,
			},
			visible = true,
			zIndex = 1,
			clip = true,
		},
	},
}

local Schema = {}

Schema.types = NodeTypes

function Schema.get(typeName: string): NodeType
	return NodeTypes[typeName] or NodeTypes.Panel
end

-- Merges a node's props over its type defaults (one level deep for grouped props).
function Schema.effectiveProps(node: any): { [string]: any }
	local defaults = Schema.get(node.type).defaults
	local result = {}
	for key, value in defaults do
		if type(value) == "table" and not (#value > 0) then
			result[key] = table.clone(value)
		else
			result[key] = value
		end
	end
	for key, value in node.props or {} do
		if type(value) == "table" and type(result[key]) == "table" and not (#value > 0) then
			for subKey, subValue in value do
				result[key][subKey] = subValue
			end
		else
			result[key] = value
		end
	end
	return result
end

return Schema
