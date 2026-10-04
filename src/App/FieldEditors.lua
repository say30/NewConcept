--!strict
-- Draws one inspector field (colour, number, choice...) from its definition in Schema/Fields.

local Style = require(script.Parent.Parent.Style.Style)
local Table = require(script.Parent.Parent.Util.Table)
local Ui = require(script.Parent.Ui)

local FieldEditors = {}

local TOKEN_LABELS = {
	radius = "Arrondi du thème",
	radiusSmall = "Petit arrondi",
	strokeThickness = "Épaisseur du thème",
	font = "Police des titres",
	fontBody = "Police du texte",
}

local COLOR_TOKENS =
	{ "primary", "secondary", "accent", "success", "danger", "background", "surface", "text", "stroke" }

local function row(parent: Instance, order: number, height: number?): Frame
	return Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 26),
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.list("Horizontal", 4, Enum.VerticalAlignment.Center) })
end

local function formatNumber(value: number): string
	if math.floor(value) == value then
		return tostring(value)
	end
	return string.format("%.2f", value)
end

local function colorEditor(_field: any, value: any, tokens: any, onChange: (any) -> (), parent: Instance)
	local swatches = row(parent, 2, 22)
	for i, token in COLOR_TOKENS do
		local selected = value == "$" .. token
		local swatch = Ui.new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = Style.color(tokens[token]),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(20, 20),
			LayoutOrder = i,
			Parent = swatches,
		}, {
			Ui.corner(10),
			Ui.stroke(if selected then Color3.new(1, 1, 1) else Ui.colors.border, if selected then 2 else 1),
		})
		Ui.connect(swatch, "MouseButton1Click", function()
			onChange("$" .. token)
		end)
	end

	local controls = row(parent, 3)
	local resolved = Style.resolve(value, tokens)
	Ui.new("Frame", {
		BackgroundColor3 = Style.color(resolved),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(26, 26),
		LayoutOrder = 1,
		Parent = controls,
	}, { Ui.corner(5), Ui.stroke(Ui.colors.border) })
	Ui.textBox(if type(resolved) == "string" then resolved else "#FFFFFF", {
		size = UDim2.fromOffset(90, 26),
		order = 2,
		placeholder = "#RRGGBB",
		onCommit = function(text)
			local hex = string.upper((string.gsub(text, "%s", "")))
			if string.sub(hex, 1, 1) ~= "#" then
				hex = "#" .. hex
			end
			if Style.parseHex(hex) and hex ~= resolved then
				onChange(hex)
			end
		end,
	}).Parent =
		controls
	if Style.isToken(value) then
		Ui.label(
			"lié au thème",
			{
				Size = UDim2.fromOffset(90, 26),
				TextColor3 = Ui.colors.muted,
				TextSize = 12,
				LayoutOrder = 3,
				Parent = controls,
			}
		)
	end
end

local function numberEditor(field: any, value: any, tokens: any, onChange: (any) -> (), parent: Instance)
	local controls = row(parent, 2)
	local resolved = Style.number(Style.resolve(value, tokens), field.min or 0)
	local step = field.step or 1

	local function set(number: number)
		local clamped = math.clamp(number, field.min or -math.huge, field.max or math.huge)
		clamped = math.round(clamped / step) * step
		if clamped ~= resolved or Style.isToken(value) then
			onChange(clamped)
		end
	end

	Ui.textBox(formatNumber(resolved), {
		size = UDim2.fromOffset(64, 26),
		order = 1,
		onCommit = function(text)
			local number = tonumber((string.gsub(text, ",", ".")))
			if number then
				set(number)
			end
		end,
	}).Parent =
		controls
	Ui.button("-", {
		size = UDim2.fromOffset(26, 26),
		order = 2,
		parent = controls,
		onClick = function()
			set(resolved - step)
		end,
	})
	Ui.button("+", {
		size = UDim2.fromOffset(26, 26),
		order = 3,
		parent = controls,
		onClick = function()
			set(resolved + step)
		end,
	})
	for i, token in field.tokens or {} do
		local selected = value == "$" .. token
		Ui.button(TOKEN_LABELS[token] or token, {
			size = UDim2.fromOffset(118, 26),
			order = 3 + i,
			textSize = 12,
			color = if selected then Ui.colors.accentDark else Ui.colors.panelLight,
			parent = controls,
			onClick = function()
				onChange("$" .. token)
			end,
		})
	end
end

local function toggleEditor(_field: any, value: any, _tokens: any, onChange: (any) -> (), parent: Instance)
	local controls = row(parent, 2)
	local on = value == true
	Ui.button(if on then "Oui" else "Non", {
		size = UDim2.fromOffset(70, 26),
		color = if on then Ui.colors.success else Ui.colors.panelLight,
		parent = controls,
		onClick = function()
			onChange(not on)
		end,
	})
end

local function choiceEditor(field: any, value: any, tokens: any, onChange: (any) -> (), parent: Instance)
	local isFont = field.path[#field.path] == "font"
	local grid = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = parent,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(if isFont then 124 else 84, 26),
			CellPadding = UDim2.fromOffset(4, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local options = table.clone(field.options or {})
	for _, token in field.tokens or {} do
		table.insert(
			options,
			1,
			{
				value = "$" .. token,
				label = (TOKEN_LABELS[token] or token) .. " (" .. tostring(tokens[token]) .. ")",
			}
		)
	end
	for i, option in options do
		local selected = Table.deepEqual(option.value, value)
		local button = Ui.button(option.label, {
			order = i,
			textSize = 13,
			bold = false,
			color = if selected then Ui.colors.accentDark else Ui.colors.panelLight,
			parent = grid,
			onClick = function()
				onChange(Table.deepCopy(option.value))
			end,
		})
		if isFont then
			button.Font = Style.font(Style.resolve(option.value, tokens))
		end
	end
end

local function textEditor(field: any, value: any, _tokens: any, onChange: (any) -> (), parent: Instance)
	local multiline = field.kind == "multiline"
	local box = Ui.textBox(tostring(value or ""), {
		size = UDim2.new(1, 0, 0, if multiline then 52 else 26),
		order = 2,
		multiline = multiline,
		placeholder = if field.kind == "asset" then "rbxassetid://123456 ou 123456" else "",
		onCommit = function(text)
			if field.kind == "asset" then
				local digits = string.match(text, "(%d+)")
				text = if digits then "rbxassetid://" .. digits else ""
			end
			if text ~= value then
				onChange(text)
			end
		end,
	})
	box.Parent = parent
end

local function udim2Editor(field: any, value: any, _tokens: any, onChange: (any) -> (), parent: Instance)
	local current = if type(value) == "table" and #value == 4 then value else { 0, 0, 0, 0 }
	local isPosition = field.path[1] == "position"

	for axis = 1, 2 do
		local controls = row(parent, 1 + axis)
		Ui.label(
			if axis == 1
				then (if isPosition then "X" else "Largeur")
				else (if isPosition then "Y" else "Hauteur"),
			{
				Size = UDim2.fromOffset(56, 26),
				TextColor3 = Ui.colors.muted,
				LayoutOrder = 1,
				Parent = controls,
			}
		)
		local scaleIndex, offsetIndex = axis * 2 - 1, axis * 2
		Ui.textBox(formatNumber(current[scaleIndex] * 100), {
			size = UDim2.fromOffset(56, 26),
			order = 2,
			onCommit = function(text)
				local number = tonumber((string.gsub(text, ",", ".")))
				if number and number / 100 ~= current[scaleIndex] then
					local copy = table.clone(current)
					copy[scaleIndex] = math.round(number * 10) / 1000
					onChange(copy)
				end
			end,
		}).Parent =
			controls
		Ui.label(
			"%",
			{
				Size = UDim2.fromOffset(14, 26),
				TextColor3 = Ui.colors.muted,
				LayoutOrder = 3,
				Parent = controls,
			}
		)
		Ui.textBox(formatNumber(current[offsetIndex]), {
			size = UDim2.fromOffset(56, 26),
			order = 4,
			onCommit = function(text)
				local number = tonumber((string.gsub(text, ",", ".")))
				if number and number ~= current[offsetIndex] then
					local copy = table.clone(current)
					copy[offsetIndex] = math.round(number)
					onChange(copy)
				end
			end,
		}).Parent =
			controls
		Ui.label(
			"px",
			{
				Size = UDim2.fromOffset(20, 26),
				TextColor3 = Ui.colors.muted,
				LayoutOrder = 5,
				Parent = controls,
			}
		)
	end
end

local EDITORS = {
	color = colorEditor,
	number = numberEditor,
	slider = numberEditor,
	toggle = toggleEditor,
	choice = choiceEditor,
	text = textEditor,
	multiline = textEditor,
	asset = textEditor,
	udim2 = udim2Editor,
}

-- Draws a field: its label, then its controls. Returns the field's frame.
function FieldEditors.render(
	field: any,
	value: any,
	tokens: any,
	onChange: (any) -> (),
	parent: Instance,
	order: number
)
	local frame = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.list("Vertical", 4) })
	Ui.label(
		field.label,
		{
			TextColor3 = Ui.colors.muted,
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 1,
			Parent = frame,
		}
	)
	local editor = EDITORS[field.kind] or textEditor
	editor(field, value, tokens, onChange, frame)
	return frame
end

return FieldEditors
