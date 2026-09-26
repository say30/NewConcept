--[[
	Widgets
	Bibliothèque de composants d'interface pour DockWidgetPluginGui, cohérente
	avec le thème de Studio : sections repliables, boutons, cases à cocher,
	sliders avec saisie numérique, listes déroulantes, champs numériques,
	lignes clé/valeur, barre de progression, boîte de confirmation, infobulles.

	Chaque contrôle renvoie une petite API { Instance, Set(value), ... }.
	Set() ne rappelle jamais le callback (pas de boucle avec les Settings).
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)

local Widgets = {}
Widgets.__index = Widgets

local UI = Config.UI
local ROW = UI.ROW_HEIGHT
local PAD = UI.PADDING

local function create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
Widgets.create = create

local function decimalsForStep(step)
	if not step or step >= 1 then
		return 0
	elseif step >= 0.1 then
		return 1
	elseif step >= 0.01 then
		return 2
	end
	return 3
end

local function formatNumber(value, decimals)
	return string.format("%." .. tostring(decimals) .. "f", value)
end

function Widgets.new(theme, overlay)
	local self = setmetatable({}, Widgets)
	self.Theme = theme
	self.Overlay = overlay
	self._order = 0
	return self
end

function Widgets:nextOrder()
	self._order += 1
	return self._order
end

function Widgets:corner(inst, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = inst })
end

function Widgets:stroke(inst, colorName)
	local s = create("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inst })
	self.Theme:bind(s, "Color", colorName or "Border")
	return s
end

-- Texte ---------------------------------------------------------------------------

function Widgets:label(parent, text, opts)
	opts = opts or {}
	local l = create("TextLabel", {
		Name = opts.Name or "Label",
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.new(1, 0, 0, ROW),
		AutomaticSize = if opts.Wrap then Enum.AutomaticSize.Y else Enum.AutomaticSize.None,
		Font = if opts.Bold then UI.FONT_BOLD else UI.FONT,
		TextSize = opts.TextSize or UI.TEXT_SIZE,
		Text = text,
		TextWrapped = opts.Wrap == true,
		TextXAlignment = opts.Align or Enum.TextXAlignment.Left,
		TextYAlignment = if opts.Wrap then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		TextTruncate = if opts.Wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		LayoutOrder = opts.Order or self:nextOrder(),
		RichText = opts.Rich == true,
		Parent = parent,
	})
	self.Theme:bind(l, "TextColor3", opts.Color or "Text")
	return l
end

function Widgets:info(parent, text, colorName)
	local l = self:label(parent, text, { Wrap = true, Color = colorName or "DimText" })
	create("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), Parent = l })
	local api = { Instance = l }
	function api.Set(newText, newColor)
		l.Text = newText
		if newColor then
			l.TextColor3 = if typeof(newColor) == "Color3" then newColor else self.Theme:color(newColor)
		end
	end
	return api
end

-- Infobulle simple dans l'overlay.
function Widgets:tooltip(target, text)
	if not text or text == "" then
		return
	end
	local tip
	target.MouseEnter:Connect(function()
		if tip then
			tip:Destroy()
		end
		local overlay = self.Overlay
		local pos = target.AbsolutePosition - overlay.AbsolutePosition
		tip = create("TextLabel", {
			Name = "Tooltip",
			Size = UDim2.new(0, math.min(260, overlay.AbsoluteSize.X - 16), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(math.clamp(pos.X, 4, math.max(4, overlay.AbsoluteSize.X - 264)), pos.Y + target.AbsoluteSize.Y + 2),
			Font = UI.FONT,
			TextSize = UI.TEXT_SIZE - 1,
			TextWrapped = true,
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 50,
			Parent = overlay,
		})
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = tip,
		})
		tip.BackgroundColor3 = self.Theme:color("Header")
		tip.TextColor3 = self.Theme:color("Text")
		self:stroke(tip, "Border")
		self:corner(tip, 3)
	end)
	target.MouseLeave:Connect(function()
		if tip then
			tip:Destroy()
			tip = nil
		end
	end)
end

-- Section repliable -------------------------------------------------------------------

function Widgets:section(parent, title, expanded)
	local container = create("Frame", {
		Name = "Section_" .. title,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self:nextOrder(),
		Parent = parent,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) }),
	})
	local header = create("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, ROW + 4),
		AutoButtonColor = false,
		Font = UI.FONT_BOLD,
		TextSize = UI.HEADER_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		LayoutOrder = 1,
		Parent = container,
	})
	self.Theme:bind(header, "BackgroundColor3", "Section")
	self.Theme:bind(header, "TextColor3", "Text")
	header.BorderSizePixel = 0
	local arrow = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 18, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		Font = UI.FONT_BOLD,
		TextSize = UI.TEXT_SIZE,
		Text = if expanded then "▼" else "▶",
		Parent = header,
	})
	self.Theme:bind(arrow, "TextColor3", "DimText")
	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.fromOffset(26, 0),
		Font = UI.FONT_BOLD,
		TextSize = UI.HEADER_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(title),
		Parent = header,
	})
	self.Theme:bind(titleLabel, "TextColor3", "Text")
	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = expanded,
		LayoutOrder = 2,
		Parent = container,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
		create("UIPadding", {
			PaddingLeft = UDim.new(0, PAD + 2), PaddingRight = UDim.new(0, PAD + 2),
			PaddingTop = UDim.new(0, PAD), PaddingBottom = UDim.new(0, PAD + 2),
		}),
	})
	header.MouseEnter:Connect(function()
		header.BackgroundColor3 = self.Theme:color("SectionHover")
	end)
	header.MouseLeave:Connect(function()
		header.BackgroundColor3 = self.Theme:color("Section")
	end)
	header.Activated:Connect(function()
		content.Visible = not content.Visible
		arrow.Text = if content.Visible then "▼" else "▶"
	end)
	return content, container
end

-- Ligne libellé + contrôle.
function Widgets:row(parent, labelText, tooltip, labelWidth)
	local row = create("Frame", {
		Name = "Row_" .. labelText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW),
		LayoutOrder = self:nextOrder(),
		Parent = parent,
	})
	local lw = labelWidth or 0.46
	local l = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(lw, -4, 1, 0),
		Font = UI.FONT,
		TextSize = UI.TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = labelText,
		Parent = row,
	})
	self.Theme:bind(l, "TextColor3", "Text")
	self:tooltip(l, tooltip)
	local control = create("Frame", {
		Name = "Control",
		BackgroundTransparency = 1,
		Size = UDim2.new(1 - lw, 0, 1, 0),
		Position = UDim2.new(lw, 0, 0, 0),
		Parent = row,
	})
	return row, control, l
end

-- Boutons ---------------------------------------------------------------------------------

function Widgets:button(parent, text, callback, opts)
	opts = opts or {}
	local primary = opts.Primary == true
	local b = create("TextButton", {
		Name = "Button_" .. text,
		Size = opts.Size or UDim2.new(1, 0, 0, ROW + 2),
		AutoButtonColor = false,
		Font = if primary then UI.FONT_BOLD else UI.FONT,
		TextSize = UI.TEXT_SIZE,
		Text = text,
		LayoutOrder = opts.Order or self:nextOrder(),
		Parent = parent,
	})
	b.BorderSizePixel = 0
	self:corner(b, 4)
	self:stroke(b, "Border")
	local enabled = true
	local hovering = false
	local function refresh()
		if not enabled then
			b.BackgroundColor3 = self.Theme:color("ButtonDisabled")
			b.TextColor3 = self.Theme:color("ButtonTextDisabled")
		elseif primary then
			b.BackgroundColor3 = self.Theme:color(if hovering then "PrimaryHover" else "Primary")
			b.TextColor3 = self.Theme:color("PrimaryText")
		else
			b.BackgroundColor3 = self.Theme:color(if hovering then "ButtonHover" else "Button")
			b.TextColor3 = self.Theme:color("ButtonText")
		end
	end
	refresh()
	self.Theme:onApply(refresh)
	b.MouseEnter:Connect(function()
		hovering = true
		refresh()
	end)
	b.MouseLeave:Connect(function()
		hovering = false
		refresh()
	end)
	b.Activated:Connect(function()
		if enabled and callback then
			task.spawn(callback)
		end
	end)
	self:tooltip(b, opts.Tooltip)
	local api = { Instance = b }
	function api.SetEnabled(value)
		enabled = value
		refresh()
	end
	function api.SetText(value)
		b.Text = value
	end
	api.Refresh = refresh
	return api
end

-- Rangée de boutons de largeur égale.
function Widgets:buttonRow(parent, defs)
	local row = create("Frame", {
		Name = "ButtonRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW + 2),
		LayoutOrder = self:nextOrder(),
		Parent = parent,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})
	local apis = {}
	local n = #defs
	for i, def in ipairs(defs) do
		local api = self:button(row, def.Text, def.Callback, {
			Primary = def.Primary,
			Tooltip = def.Tooltip,
			Order = i,
			Size = UDim2.new(1 / n, -math.ceil(4 * (n - 1) / n), 1, 0),
		})
		apis[def.Key or def.Text] = api
	end
	return apis, row
end

-- Case à cocher --------------------------------------------------------------------------

function Widgets:toggle(parent, label, value, onChange, tooltip)
	local _, control = self:row(parent, label, tooltip, 0.8)
	local box = create("TextButton", {
		Name = "Toggle",
		Size = UDim2.new(0, ROW - 4, 0, ROW - 4),
		Position = UDim2.new(1, -(ROW - 4), 0.5, -(ROW - 4) / 2),
		AutoButtonColor = false,
		Font = UI.FONT_BOLD,
		TextSize = UI.TEXT_SIZE,
		Text = "",
		Parent = control,
	})
	box.BorderSizePixel = 0
	self:corner(box, 3)
	self:stroke(box, "InputBorder")
	local current = value == true
	local function refresh()
		box.Text = if current then "✓" else ""
		box.BackgroundColor3 = self.Theme:color(if current then "Primary" else "Input")
		box.TextColor3 = self.Theme:color("PrimaryText")
	end
	refresh()
	self.Theme:onApply(refresh)
	box.Activated:Connect(function()
		current = not current
		refresh()
		if onChange then
			onChange(current)
		end
	end)
	local api = { Instance = box }
	function api.Set(v)
		current = v == true
		refresh()
	end
	return api
end

-- Champ texte numérique (utilisé seul ou avec un slider).
function Widgets:_numberBox(parent, value, decimals, size, position)
	local box = create("TextBox", {
		Name = "NumberBox",
		Size = size,
		Position = position or UDim2.new(),
		ClearTextOnFocus = false,
		Font = UI.FONT,
		TextSize = UI.TEXT_SIZE,
		Text = formatNumber(value, decimals),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = parent,
	})
	box.BorderSizePixel = 0
	self.Theme:bind(box, "BackgroundColor3", "Input")
	self.Theme:bind(box, "TextColor3", "Text")
	self:corner(box, 3)
	self:stroke(box, "InputBorder")
	return box
end

function Widgets:numberInput(parent, label, value, onChange, opts)
	opts = opts or {}
	local _, control = self:row(parent, label, opts.Tooltip)
	local decimals = if opts.Integer then 0 else decimalsForStep(opts.Step)
	local box = self:_numberBox(control, value, decimals, UDim2.new(1, 0, 1, -2), UDim2.fromOffset(0, 1))
	local current = value
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			if opts.Integer then
				n = math.floor(n + 0.5)
			end
			if opts.Min then
				n = math.max(opts.Min, n)
			end
			if opts.Max then
				n = math.min(opts.Max, n)
			end
			current = n
			if onChange then
				onChange(n)
			end
		end
		box.Text = formatNumber(current, decimals)
	end)
	local api = { Instance = box }
	function api.Set(v)
		current = v
		box.Text = formatNumber(v, decimals)
	end
	return api
end

-- Slider -------------------------------------------------------------------------------------

function Widgets:slider(parent, label, minValue, maxValue, step, value, onChange, tooltip)
	local _, control = self:row(parent, label, tooltip)
	local decimals = decimalsForStep(step)
	local boxWidth = 52
	local track = create("TextButton", {
		Name = "Track",
		Size = UDim2.new(1, -(boxWidth + 8), 0, 6),
		Position = UDim2.new(0, 0, 0.5, -3),
		AutoButtonColor = false,
		Text = "",
		Parent = control,
	})
	track.BorderSizePixel = 0
	self.Theme:bind(track, "BackgroundColor3", "Track")
	self:corner(track, 3)
	local fill = create("Frame", { Name = "Fill", Size = UDim2.new(0, 0, 1, 0), Parent = track })
	fill.BorderSizePixel = 0
	self.Theme:bind(fill, "BackgroundColor3", "Primary")
	self:corner(fill, 3)
	local knob = create("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Parent = track,
	})
	knob.BorderSizePixel = 0
	self.Theme:bind(knob, "BackgroundColor3", "Text")
	self:corner(knob, 6)
	local box = self:_numberBox(control, value, decimals, UDim2.new(0, boxWidth, 1, -2), UDim2.new(1, -boxWidth, 0, 1))

	local current = value
	local function quantize(v)
		v = math.clamp(v, minValue, maxValue)
		if step and step > 0 then
			v = minValue + math.floor((v - minValue) / step + 0.5) * step
			v = math.clamp(v, minValue, maxValue)
		end
		return tonumber(formatNumber(v, math.max(decimals, 3))) or v
	end
	local function render()
		local t = if maxValue > minValue then (current - minValue) / (maxValue - minValue) else 0
		t = math.clamp(t, 0, 1)
		fill.Size = UDim2.new(t, 0, 1, 0)
		knob.Position = UDim2.new(t, 0, 0.5, 0)
		box.Text = formatNumber(current, decimals)
	end
	render()
	local function setFromX(x)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local t = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		local v = quantize(minValue + t * (maxValue - minValue))
		if v ~= current then
			current = v
			render()
			if onChange then
				onChange(v)
			end
		end
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		setFromX(input.Position.X)
		-- Capture plein écran pendant le glisser (la souris peut sortir du slider).
		local capture = create("TextButton", {
			Name = "DragCapture",
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 100,
			Parent = self.Overlay,
		})
		local function finish()
			if capture then
				capture:Destroy()
				capture = nil
			end
		end
		capture.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement then
				setFromX(i.Position.X)
			end
		end)
		capture.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				finish()
			end
		end)
		capture.MouseButton1Up:Connect(finish)
		capture.MouseLeave:Connect(finish)
	end)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			local v = quantize(n)
			if v ~= current then
				current = v
				if onChange then
					onChange(v)
				end
			end
		end
		render()
	end)
	local api = { Instance = track }
	function api.Set(v)
		current = v
		render()
	end
	return api
end

-- Liste déroulante ----------------------------------------------------------------------------

function Widgets:dropdown(parent, label, options, value, onChange, tooltip, labelWidth)
	local control
	if label then
		local _, c = self:row(parent, label, tooltip, labelWidth)
		control = c
	else
		control = parent
	end
	local button = create("TextButton", {
		Name = "Dropdown",
		Size = UDim2.new(1, 0, 1, -2),
		Position = UDim2.fromOffset(0, 1),
		AutoButtonColor = false,
		Font = UI.FONT,
		TextSize = UI.TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = control,
	})
	button.BorderSizePixel = 0
	self.Theme:bind(button, "BackgroundColor3", "Input")
	self.Theme:bind(button, "TextColor3", "Text")
	self:corner(button, 3)
	self:stroke(button, "InputBorder")
	create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 18), Parent = button })
	local caret = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 14, 1, 0),
		Position = UDim2.new(1, 2, 0, 0),
		Font = UI.FONT,
		TextSize = UI.TEXT_SIZE - 2,
		Text = "▼",
		Parent = button,
	})
	self.Theme:bind(caret, "TextColor3", "DimText")
	local current = value
	local opts = options
	button.Text = tostring(current)

	local popup
	local function close()
		if popup then
			popup:Destroy()
			popup = nil
		end
	end
	button.Activated:Connect(function()
		if popup then
			close()
			return
		end
		local overlay = self.Overlay
		popup = create("TextButton", {
			Name = "DropdownBlocker",
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 60,
			Parent = overlay,
		})
		popup.Activated:Connect(close)
		local rowH = ROW
		local visible = math.min(#opts, 10)
		local pos = button.AbsolutePosition - overlay.AbsolutePosition
		local height = visible * rowH + 4
		local y = pos.Y + button.AbsoluteSize.Y + 2
		if y + height > overlay.AbsoluteSize.Y then
			y = math.max(0, pos.Y - height - 2)
		end
		local list = create("ScrollingFrame", {
			Name = "List",
			Position = UDim2.fromOffset(pos.X, y),
			Size = UDim2.fromOffset(math.max(button.AbsoluteSize.X, 120), height),
			CanvasSize = UDim2.fromOffset(0, #opts * rowH + 4),
			ScrollBarThickness = 6,
			ZIndex = 61,
			Parent = popup,
		}, {
			create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			create("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }),
		})
		list.BorderSizePixel = 0
		list.BackgroundColor3 = self.Theme:color("Input")
		self:stroke(list, "Border")
		for i, option in ipairs(opts) do
			local item = create("TextButton", {
				Name = "Option",
				Size = UDim2.new(1, 0, 0, rowH),
				AutoButtonColor = false,
				Font = if option == current then UI.FONT_BOLD else UI.FONT,
				TextSize = UI.TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "  " .. tostring(option),
				LayoutOrder = i,
				ZIndex = 62,
				Parent = list,
			})
			item.BorderSizePixel = 0
			item.BackgroundColor3 = self.Theme:color(if option == current then "Selected" else "Item")
			item.TextColor3 = self.Theme:color("Text")
			item.MouseEnter:Connect(function()
				if option ~= current then
					item.BackgroundColor3 = self.Theme:color("ItemHover")
				end
			end)
			item.MouseLeave:Connect(function()
				item.BackgroundColor3 = self.Theme:color(if option == current then "Selected" else "Item")
			end)
			item.Activated:Connect(function()
				close()
				if option ~= current then
					current = option
					button.Text = tostring(option)
					if onChange then
						onChange(option)
					end
				end
			end)
		end
	end)
	local api = { Instance = button }
	function api.Set(v)
		current = v
		button.Text = tostring(v)
	end
	function api.SetOptions(newOptions)
		opts = newOptions
	end
	return api
end

-- Clé / valeur ------------------------------------------------------------------------------------

function Widgets:keyValue(parent, key)
	local _, control = self:row(parent, key, nil, 0.5)
	local v = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = UI.FONT_BOLD,
		TextSize = UI.TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "-",
		Parent = control,
	})
	self.Theme:bind(v, "TextColor3", "Text")
	local api = { Instance = v }
	function api.Set(value)
		v.Text = tostring(value)
	end
	return api
end

-- Barre de progression + statut ----------------------------------------------------------------

function Widgets:progress(parent)
	local frame = create("Frame", {
		Name = "Status",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self:nextOrder(),
		Parent = parent,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
	})
	local bar = create("Frame", { Name = "Bar", Size = UDim2.new(1, 0, 0, 4), LayoutOrder = 2, Visible = false, Parent = frame })
	bar.BorderSizePixel = 0
	self.Theme:bind(bar, "BackgroundColor3", "Track")
	self:corner(bar, 2)
	local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), Parent = bar })
	fill.BorderSizePixel = 0
	self.Theme:bind(fill, "BackgroundColor3", "Primary")
	self:corner(fill, 2)
	local text = create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = UI.FONT,
		TextSize = UI.TEXT_SIZE,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		LayoutOrder = 1,
		Parent = frame,
	})
	self.Theme:bind(text, "TextColor3", "DimText")
	local api = { Instance = frame }
	function api.Set(fraction, message, level)
		text.Text = message or ""
		if level == "Error" then
			text.TextColor3 = self.Theme:color("Error")
		elseif level == "Warning" then
			text.TextColor3 = self.Theme:color("Warning")
		elseif level == "Success" then
			text.TextColor3 = self.Theme.SuccessColor
		else
			text.TextColor3 = self.Theme:color("DimText")
		end
		if fraction then
			bar.Visible = true
			fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
		else
			bar.Visible = false
		end
	end
	return api
end

-- Boîte de confirmation modale ---------------------------------------------------------------------

function Widgets:confirm(title, message, confirmText, onConfirm)
	local overlay = self.Overlay
	local blocker = create("TextButton", {
		Name = "ConfirmBlocker",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 80,
		Parent = overlay,
	})
	local dialog = create("Frame", {
		Name = "Dialog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 81,
		Parent = blocker,
	}, {
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
		}),
	})
	dialog.BackgroundColor3 = self.Theme:color("Background")
	self:stroke(dialog, "Border")
	self:corner(dialog, 6)
	local t = self:label(dialog, title, { Bold = true, Order = 1, TextSize = UI.HEADER_TEXT_SIZE })
	t.ZIndex = 82
	local m = self:label(dialog, message, { Wrap = true, Order = 2 })
	m.ZIndex = 82
	local apis, row = self:buttonRow(dialog, {
		{ Text = "Cancel", Key = "No", Callback = function()
			blocker:Destroy()
		end },
		{ Text = confirmText or "Confirm", Key = "Yes", Primary = true, Callback = function()
			blocker:Destroy()
			onConfirm()
		end },
	})
	row.LayoutOrder = 3
	for _, api in pairs(apis) do
		api.Instance.ZIndex = 82
	end
end

return Widgets
