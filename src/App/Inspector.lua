--!strict
-- The right panel. Select something and change its look by clicking pictures: colour,
-- effect, pattern, corners, outline, shadow, icon, font... Exact values stay available in
-- "Avancé", drawn from Schema/Fields.

local Commands = require(script.Parent.Parent.Core.Commands)
local Fields = require(script.Parent.Parent.Schema.Fields)
local Icons = require(script.Parent.Parent.Visual.Icons)
local NodeTypes = require(script.Parent.Parent.Schema.NodeTypes)
local Patterns = require(script.Parent.Parent.Visual.Patterns)
local Style = require(script.Parent.Parent.Style.Style)
local Table = require(script.Parent.Parent.Util.Table)
local FieldEditors = require(script.Parent.FieldEditors)
local Ui = require(script.Parent.Ui)

local Inspector = {}
Inspector.__index = Inspector

function Inspector.new(editor: any, parent: Instance)
	local self = setmetatable({}, Inspector)
	self.editor = editor
	self.advanced = false
	self.frame = Ui.new("Frame", {
		Name = "Inspector",
		BackgroundColor3 = Ui.colors.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	self.scroll = Ui.scroll({ Parent = self.frame })
	Ui.list("Vertical", 14).Parent = self.scroll
	Ui.padding(12, 10).Parent = self.scroll
	return self
end

--------------------------------------------------------------------------------
-- Building blocks
--------------------------------------------------------------------------------

local function section(parent: Instance, order: number, title: string): Frame
	local block = Ui.stack(parent, 6, order)
	Ui.title(title, 17, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 22), Parent = block })
	return block
end

-- A row of picture tiles. `options` = { { value, label?, draw(picture) } }.
local function gallery(parent: Instance, cell: Vector2, options: { any }, current: any, onPick: (any) -> ())
	local grid = Ui.grid(parent, cell, 6, 1)
	for i, option in options do
		local _, picture = Ui.tile({
			order = i,
			label = option.label,
			selected = Table.deepEqual(option.value, current),
			parent = grid,
			onClick = function()
				onPick(option.value)
			end,
		})
		if option.draw then
			option.draw(picture)
		end
	end
	return grid
end

local function shape(parent: Instance, color: Color3, props: { [string]: any }?): Frame
	local f = Ui.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.7),
		Parent = parent,
	})
	for key, value in props or {} do
		(f :: any)[key] = value
	end
	return f
end

local PALETTE = {
	"#FFFFFF",
	"#1F1A2E",
	"#FF4D4D",
	"#FF8A3D",
	"#FFC531",
	"#7ED957",
	"#2FA84F",
	"#3FA9F5",
	"#2F5BEA",
	"#B76BFF",
	"#FF5FAE",
	"#8B5A2B",
	"#9AA3BF",
	"#4A4F63",
}
local PACK_COLORS = {
	"frame",
	"body",
	"card",
	"header",
	"primary",
	"accent1",
	"accent2",
	"accent3",
	"accent4",
	"success",
	"danger",
	"warning",
	"slot",
}

-- Colour swatches: the pack's colours first (they follow the style), then fixed colours.
local function colorPicker(parent: Instance, tokens: any, current: any, onPick: (any) -> ())
	local grid = Ui.grid(parent, Vector2.new(32, 32), 6, 1)
	local values = {}
	for _, token in PACK_COLORS do
		table.insert(values, "$" .. token)
	end
	for _, hex in PALETTE do
		table.insert(values, hex)
	end
	for i, value in values do
		local selected = value == current
		local swatch = Ui.new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = Style.color(Style.resolve(value, tokens)),
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = grid,
		}, {
			Ui.corner(if Style.isToken(value) then 16 else 8),
			Ui.stroke(if selected then Ui.colors.selection else Ui.colors.outline, if selected then 3 else 1),
		})
		Ui.connect(swatch, "MouseButton1Click", function()
			onPick(value)
		end)
	end
	local hex = Ui.textBox(if Style.isToken(current) then "" else tostring(current or ""), {
		size = UDim2.fromOffset(110, 28),
		order = 2,
		placeholder = "#FFAA00",
		onCommit = function(text)
			local r = Style.parseHex(text)
			if r then
				onPick(string.upper(if string.sub(text, 1, 1) == "#" then text else "#" .. text))
			end
		end,
	})
	hex.Parent = parent
end

--------------------------------------------------------------------------------
-- Sections
--------------------------------------------------------------------------------

function Inspector:_set(path: { string }, value: any)
	self.editor:setProps({ { path = path, value = value } })
end

function Inspector:_surface(props: any, raw: any, tokens: any, order: number): number
	local fill = props.fill or {}
	local fillColor = Style.color(fill.color)

	order += 1
	local colorBlock = section(self.scroll, order, "Couleur")
	colorPicker(
		colorBlock,
		tokens,
		raw.fill and raw.fill.color or NodeTypes.get(self.nodeType).defaults.fill.color,
		function(value)
			self:_set({ "fill", "color" }, value)
		end
	)

	order += 1
	local effect = section(self.scroll, order, "Effet")
	gallery(
		effect,
		Vector2.new(92, 74),
		{
			{
				value = "Color",
				label = "Uni",
				draw = function(p)
					shape(p, fillColor)
				end,
			},
			{
				value = "Shade",
				label = "Ombré",
				draw = function(p)
					local f = shape(p, Color3.new(1, 1, 1))
					Ui.new("UIGradient", {
						Color = ColorSequence.new(Style.shade(fillColor, -0.12), Style.shade(fillColor, 0.3)),
						Rotation = 90,
						Parent = f,
					})
				end,
			},
			{
				value = "Gradient",
				label = "Dégradé",
				draw = function(p)
					local f = shape(p, Color3.new(1, 1, 1))
					Ui.new("UIGradient", {
						Color = ColorSequence.new(fillColor, Style.color(fill.color2)),
						Rotation = 0,
						Parent = f,
					})
				end,
			},
			{
				value = "None",
				label = "Invisible",
				draw = function(p)
					shape(p, fillColor, { BackgroundTransparency = 1 }).Parent = p
					Ui.stroke(Ui.colors.muted, 1).Parent = p:FindFirstChildOfClass("Frame")
				end,
			},
		},
		fill.kind,
		function(value)
			self:_set({ "fill", "kind" }, value)
		end
	)

	order += 1
	local patternBlock = section(self.scroll, order, "Motif")
	local patternOptions = {}
	for _, def in Patterns.list do
		table.insert(patternOptions, {
			value = def.id,
			label = def.label,
			draw = function(p)
				local base = Ui.new("CanvasGroup", {
					BackgroundColor3 = fillColor,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					Parent = p,
				}, { Ui.corner(6) })
				local layer = Ui.new("CanvasGroup", {
					BackgroundTransparency = 1,
					GroupTransparency = 0.55,
					Size = UDim2.fromScale(1, 1),
					Parent = base,
				})
				if def.id ~= "None" then
					Patterns.build(
						layer,
						def.id,
						90,
						60,
						Style.color(props.pattern and props.pattern.color or "#FFFFFF"),
						14
					)
				end
			end,
		})
	end
	gallery(
		patternBlock,
		Vector2.new(92, 74),
		patternOptions,
		props.pattern and props.pattern.kind,
		function(value)
			self:_set({ "pattern", "kind" }, value)
		end
	)

	order += 1
	local cornerBlock = section(self.scroll, order, "Coins")
	local corners = {}
	for _, c in
		{
			{ 0, "Carrés" },
			{ 6, "Doux" },
			{ 14, "Ronds" },
			{ 26, "Très ronds" },
			{ -1, "Pilule" },
			{ "$radius", "Du style" },
		}
	do
		local radius = Style.number(Style.resolve(c[1], tokens), 0)
		table.insert(corners, {
			value = c[1],
			label = c[2],
			draw = function(p)
				local f = shape(p, fillColor)
				Ui.new("UICorner", {
					CornerRadius = if radius < 0 then UDim.new(0.5, 0) else UDim.new(0, radius * 0.6),
					Parent = f,
				})
			end,
		})
	end
	gallery(
		cornerBlock,
		Vector2.new(92, 74),
		corners,
		raw.corner or NodeTypes.get(self.nodeType).defaults.corner,
		function(value)
			self:_set({ "corner" }, value)
		end
	)

	order += 1
	local strokeBlock = section(self.scroll, order, "Contour")
	local strokes = {}
	for _, s in { { false, 0, "Aucun" }, { true, 2, "Fin" }, { true, 3, "Moyen" }, { true, 5, "Épais" } } do
		table.insert(strokes, {
			value = { s[1], s[2] },
			label = s[3],
			draw = function(p)
				local f = shape(p, fillColor)
				Ui.corner(8).Parent = f
				if s[1] then
					Ui.stroke(Style.color(tokens.outline), s[2]).Parent = f
				end
			end,
		})
	end
	local stroke = props.stroke or {}
	local currentStroke =
		{ stroke.enabled == true, if stroke.enabled then Style.number(stroke.thickness, 0) else 0 }
	gallery(strokeBlock, Vector2.new(92, 74), strokes, currentStroke, function(value)
		self.editor:setProps({
			{ path = { "stroke", "enabled" }, value = value[1] },
			{ path = { "stroke", "thickness" }, value = if value[1] then value[2] else nil },
		})
	end)

	order += 1
	local shadowBlock = section(self.scroll, order, "Ombre")
	gallery(
		shadowBlock,
		Vector2.new(92, 74),
		{
			{
				value = "None",
				label = "Aucune",
				draw = function(p)
					Ui.corner(8).Parent = shape(p, fillColor)
				end,
			},
			{
				value = "Drop",
				label = "Portée",
				draw = function(p)
					local s = shape(
						p,
						Color3.new(0, 0, 0),
						{ BackgroundTransparency = 0.5, Position = UDim2.new(0.5, 0, 0.5, 5) }
					)
					Ui.corner(8).Parent = s
					Ui.corner(8).Parent = shape(p, fillColor)
				end,
			},
			{
				value = "Depth",
				label = "Relief",
				draw = function(p)
					local s = shape(p, Style.shade(fillColor, 0.45), { Position = UDim2.new(0.5, 0, 0.5, 5) })
					Ui.corner(8).Parent = s
					Ui.corner(8).Parent = shape(p, fillColor)
				end,
			},
		},
		props.shadow and props.shadow.kind,
		function(value)
			self:_set({ "shadow", "kind" }, value)
		end
	)

	order += 1
	local shineBlock = section(self.scroll, order, "Brillance")
	gallery(
		shineBlock,
		Vector2.new(92, 74),
		{
			{
				value = false,
				label = "Mate",
				draw = function(p)
					Ui.corner(8).Parent = shape(p, fillColor)
				end,
			},
			{
				value = true,
				label = "Brillante",
				draw = function(p)
					local f = shape(p, fillColor)
					Ui.corner(8).Parent = f
					Ui.new("Frame", {
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.6,
						BorderSizePixel = 0,
						Position = UDim2.new(0, 3, 0, 3),
						Size = UDim2.new(1, -6, 0.4, 0),
						Parent = f,
					}, { Ui.corner(6) })
				end,
			},
		},
		props.shine == true,
		function(value)
			self:_set({ "shine" }, value)
		end
	)
	return order
end

local FONT_TILES = {
	"$font",
	"$fontTitle",
	"FredokaOne",
	"LuckiestGuy",
	"Bangers",
	"GothamBlack",
	"Cartoon",
	"Arcade",
	"Michroma",
}

function Inspector:_text(props: any, tokens: any, order: number, withColor: boolean): number
	local text = props.text or {}
	order += 1
	local block = section(self.scroll, order, "Texte")
	Ui.textBox(tostring(text.value or ""), {
		size = UDim2.new(1, 0, 0, 34),
		order = 1,
		onCommit = function(value)
			if value ~= text.value then
				self:_set({ "text", "value" }, value)
			end
		end,
	}).Parent =
		block

	order += 1
	local fontBlock = section(self.scroll, order, "Police")
	local fonts = {}
	for _, font in FONT_TILES do
		table.insert(fonts, {
			value = font,
			label = if font == "$font" then "Du style" elseif font == "$fontTitle" then "Titres" else nil,
			draw = function(p)
				Ui.label("Abc", {
					Font = Style.font(Style.resolve(font, tokens)),
					TextSize = 24,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromScale(1, 1),
					Parent = p,
				})
			end,
		})
	end
	gallery(
		fontBlock,
		Vector2.new(92, 60),
		fonts,
		(self.raw.text and self.raw.text.font) or text.font,
		function(value)
			self:_set({ "text", "font" }, value)
		end
	)

	order += 1
	local sizeBlock = section(self.scroll, order, "Taille du texte")
	local sizes = {}
	for _, s in { { 16, "S" }, { 22, "M" }, { 30, "L" }, { 42, "XL" } } do
		table.insert(sizes, {
			value = s[1],
			draw = function(p)
				Ui.title(
					s[2],
					12 + s[1] / 2,
					{ TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = p }
				)
			end,
		})
	end
	gallery(sizeBlock, Vector2.new(68, 48), sizes, text.size, function(value)
		self:_set({ "text", "size" }, value)
	end)

	if withColor then
		order += 1
		local colorBlock = section(self.scroll, order, "Couleur du texte")
		colorPicker(colorBlock, tokens, (self.raw.text and self.raw.text.color) or "$text", function(value)
			self:_set({ "text", "color" }, value)
		end)
	end

	order += 1
	local strokeBlock = section(self.scroll, order, "Contour des lettres")
	local strokeOn = text.stroke and text.stroke.enabled == true
	gallery(
		strokeBlock,
		Vector2.new(92, 54),
		{
			{
				value = false,
				label = "Sans",
				draw = function(p)
					Ui.title("Abc", 22, {
						TextXAlignment = Enum.TextXAlignment.Center,
						Size = UDim2.fromScale(1, 1),
						Parent = p,
					})
				end,
			},
			{
				value = true,
				label = "Avec",
				draw = function(p)
					local l = Ui.title("Abc", 22, {
						TextXAlignment = Enum.TextXAlignment.Center,
						Size = UDim2.fromScale(1, 1),
						Parent = p,
					})
					Ui.new("UIStroke", {
						Color = Color3.new(0, 0, 0),
						Thickness = 2,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						Parent = l,
					})
				end,
			},
		},
		strokeOn,
		function(value)
			self:_set({ "text", "stroke", "enabled" }, value)
		end
	)
	return order
end

function Inspector:_icons(current: string?, allowNone: boolean, order: number, path: { string }): number
	order += 1
	local block = section(self.scroll, order, "Icône")
	local options = {}
	if allowNone then
		table.insert(options, {
			value = "",
			draw = function(p)
				Ui.title(
					"Aucune",
					12,
					{ TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = p }
				)
			end,
		})
	end
	for _, def in Icons.list do
		table.insert(options, {
			value = def.id,
			draw = function(p)
				Icons.build(def.id, p, 1)
			end,
		})
	end
	gallery(block, Vector2.new(52, 52), options, current or "", function(value)
		self:_set(path, value)
	end)
	return order
end

function Inspector:_layout(props: any, order: number): number
	local layout = props.layout or {}
	order += 1
	local block = section(self.scroll, order, "Rangement")
	gallery(
		block,
		Vector2.new(92, 54),
		{
			{ value = "Grid", label = "Grille" },
			{ value = "Vertical", label = "Colonne" },
			{ value = "Horizontal", label = "Ligne" },
		},
		layout.kind,
		function(value)
			self:_set({ "layout", "kind" }, value)
		end
	)
	if layout.kind == "Grid" then
		order += 1
		local columns = section(self.scroll, order, "Cases par ligne")
		local options = {}
		for n = 1, 6 do
			table.insert(options, {
				value = n,
				draw = function(p)
					Ui.title(tostring(n), 22, {
						TextXAlignment = Enum.TextXAlignment.Center,
						Size = UDim2.fromScale(1, 1),
						Parent = p,
					})
				end,
			})
		end
		gallery(columns, Vector2.new(44, 44), options, layout.columns, function(value)
			self:_set({ "layout", "columns" }, value)
		end)
	end
	order += 1
	local spacing = section(self.scroll, order, "Espace entre")
	gallery(
		spacing,
		Vector2.new(68, 44),
		{
			{ value = 4, label = "Serré" },
			{ value = 10, label = "Normal" },
			{ value = 18, label = "Aéré" },
			{ value = 28, label = "Large" },
		},
		layout.spacing,
		function(value)
			self:_set({ "layout", "spacing" }, value)
		end
	)
	return order
end

-- Nine dots to snap the element to a side or corner of its parent.
local PLACES = {
	{ 0, 0 },
	{ 0.5, 0 },
	{ 1, 0 },
	{ 0, 0.5 },
	{ 0.5, 0.5 },
	{ 1, 0.5 },
	{ 0, 1 },
	{ 0.5, 1 },
	{ 1, 1 },
}

function Inspector:_place(props: any, order: number): number
	order += 1
	local block = section(self.scroll, order, "Placer")
	local row = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 96),
		LayoutOrder = 1,
		Parent = block,
	})
	local dots = Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.field,
		Size = UDim2.fromOffset(96, 96),
		Parent = row,
	}, { Ui.corner(8), Ui.padding(6) })
	Ui.new(
		"UIGridLayout",
		{ CellSize = UDim2.fromOffset(24, 24), CellPadding = UDim2.fromOffset(6, 6), Parent = dots }
	)
	local anchor = props.anchor or { 0.5, 0.5 }
	for i, place in PLACES do
		local selected = anchor[1] == place[1] and anchor[2] == place[2]
		local dot = Ui.new("TextButton", {
			Text = "",
			BackgroundColor3 = if selected then Ui.colors.selection else Ui.colors.panelLight,
			LayoutOrder = i,
			Parent = dots,
		}, { Ui.corner(12) })
		Ui.connect(dot, "MouseButton1Click", function()
			local margin = 16
			local ox = if place[1] == 0 then margin elseif place[1] == 1 then -margin else 0
			local oy = if place[2] == 0 then margin elseif place[2] == 1 then -margin else 0
			self.editor:setProps({
				{ path = { "anchor" }, value = { place[1], place[2] } },
				{ path = { "position" }, value = { place[1], ox, place[2], oy } },
			})
		end)
	end
	-- Bigger / smaller.
	local sizeButtons = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(110, 0),
		Size = UDim2.new(1, -110, 1, 0),
		Parent = row,
	}, { Ui.list("Vertical", 8) })
	for i, step in { { "Plus grand", 1.1 }, { "Plus petit", 1 / 1.1 } } do
		Ui.bigButton(step[1], {
			order = i,
			color = Ui.colors.panelLight,
			size = UDim2.new(1, 0, 0, 40),
			textSize = 15,
			parent = sizeButtons,
			onClick = function()
				local size = props.size
				self:_set({ "size" }, {
					math.round(size[1] * step[2] * 1000) / 1000,
					math.round(size[2] * step[2]),
					math.round(size[3] * step[2] * 1000) / 1000,
					math.round(size[4] * step[2]),
				})
			end,
		})
	end
	return order
end

function Inspector:_header(node: any, order: number): number
	local editor = self.editor
	order += 1
	local block = Ui.stack(self.scroll, 8, order)
	local top = Ui.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 1, Parent = block }
	)
	local holder =
		Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(44, 44), Parent = top })
	Icons.build(NodeTypes.get(node.type).icon, holder, 1)
	Ui.textBox(node.name, {
		size = UDim2.new(1, -54, 0, 30),
		onCommit = function(text)
			if text ~= node.name then
				editor:dispatch(Commands.Rename.new(node.id, text))
			end
		end,
	}).Parent =
		top
	local nameBox = top:FindFirstChildOfClass("TextBox") :: TextBox
	nameBox.Position = UDim2.fromOffset(54, 0)
	Ui.label(NodeTypes.get(node.type).label, {
		TextColor3 = Ui.colors.muted,
		Position = UDim2.fromOffset(56, 30),
		Size = UDim2.new(1, -56, 0, 18),
		Parent = top,
	})
	local actions = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 2,
		Parent = block,
	}, { Ui.list("Horizontal", 6) })
	for i, action in
		{
			{
				"Dupliquer",
				function()
					editor:duplicateSelection()
				end,
			},
			{
				"Supprimer",
				function()
					editor:deleteSelection()
				end,
			},
			{
				"↑",
				function()
					editor:moveSelection(-1)
				end,
			},
			{
				"↓",
				function()
					editor:moveSelection(1)
				end,
			},
		}
	do
		Ui.button(action[1], {
			order = i,
			size = UDim2.fromOffset(if (utf8.len(action[1]) or 0) > 2 then 92 else 40, 30),
			color = if action[1] == "Supprimer" then Ui.colors.danger else Ui.colors.panelLight,
			parent = actions,
			onClick = action[2],
		})
	end
	return order
end

function Inspector:_advanced(node: any, props: any, tokens: any, order: number): number
	order += 1
	Ui.button(
		if self.advanced then "Masquer les réglages avancés" else "Réglages avancés (valeurs exactes)",
		{
			order = order,
			size = UDim2.new(1, 0, 0, 34),
			parent = self.scroll,
			onClick = function()
				self.advanced = not self.advanced
				self:render()
			end,
		}
	)
	if not self.advanced then
		return order
	end
	for _, sectionId in Fields.byType[node.type] or {} do
		local sectionDef = Fields.sections[sectionId]
		order += 1
		local block = section(self.scroll, order, sectionDef.label)
		for i, field in sectionDef.fields do
			if not field.showIf or field.showIf(props) then
				local value = Table.getPath(self.raw, field.path)
				if value == nil then
					value = Table.getPath(NodeTypes.get(node.type).defaults, field.path)
				end
				FieldEditors.render(field, value, tokens, function(newValue)
					self:_set(field.path, newValue)
				end, block, i)
			end
		end
	end
	return order
end

-- Nothing selected: the page and how to start.
function Inspector:_empty(order: number)
	order += 1
	local block = Ui.stack(self.scroll, 10, order)
	local holder = Ui.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromOffset(80, 80), LayoutOrder = 1, Parent = block }
	)
	Icons.build("ArrowLeft", holder, 1)
	Ui.title("Clique sur un élément", 20, { LayoutOrder = 2, Parent = block })
	Ui.label(
		"pour changer sa couleur, son motif, ses coins, son icône... ou ajoute-en un depuis la galerie à gauche.",
		{
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextColor3 = Ui.colors.muted,
			TextSize = 15,
			Size = UDim2.new(1, 0, 0, 60),
			LayoutOrder = 3,
			Parent = block,
		}
	)
	Ui.bigButton("Changer de style", {
		order = 4,
		color = Ui.colors.purple,
		size = UDim2.new(1, 0, 0, 46),
		parent = block,
		onClick = function()
			self.editor.popup:openPacks()
		end,
	})
	Ui.bigButton("Ajouter une fenêtre avec l'assistant", {
		order = 5,
		color = Ui.colors.accent,
		size = UDim2.new(1, 0, 0, 46),
		textSize = 15,
		parent = block,
		onClick = function()
			self.editor:showWizard(nil)
		end,
	})
end

function Inspector:render()
	Ui.clear(self.scroll)
	local editor = self.editor
	local store = editor.store
	local id = store.selection:primary()
	local node = id and store.project.nodes[id]
	local order = 0
	if not node or not node.parent then
		self:_empty(order)
		return
	end
	local tokens = Style.tokens(store.project)
	local props = Style.resolve(NodeTypes.effectiveProps(node), tokens)
	self.raw = node.props
	self.nodeType = node.type
	local typeInfo = NodeTypes.get(node.type)

	order = self:_header(node, order)
	if node.type == "Button" then
		order = self:_text(props, tokens, order, false)
		order = self:_icons(props.icon and props.icon.id, true, order, { "icon", "id" })
	elseif node.type == "Text" then
		order = self:_text(props, tokens, order, true)
	elseif node.type == "Icon" then
		order = self:_icons(props.icon and props.icon.id, false, order, { "icon", "id" })
	end
	if typeInfo.surface then
		order = self:_surface(props, node.props, tokens, order)
	end
	if props.layout then
		order = self:_layout(props, order)
	end
	order = self:_place(props, order)
	self:_advanced(node, props, tokens, order)
end

return Inspector
