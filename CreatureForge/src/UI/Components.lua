-- Components : petits composants d'interface (thème sombre, gros boutons simples).

local Components = {}

local Theme = {
	Bg = Color3.fromRGB(18, 20, 25),
	Panel = Color3.fromRGB(28, 31, 38),
	Panel2 = Color3.fromRGB(38, 42, 51),
	Border = Color3.fromRGB(50, 55, 67),
	Text = Color3.fromRGB(236, 238, 242),
	SubText = Color3.fromRGB(150, 158, 172),
	Muted = Color3.fromRGB(100, 106, 120),
	Accent = Color3.fromRGB(255, 138, 61),
	Primary = Color3.fromRGB(66, 133, 255),
	Success = Color3.fromRGB(72, 214, 138),
	Danger = Color3.fromRGB(255, 96, 96),
	Warn = Color3.fromRGB(255, 196, 71),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	FontLight = Enum.Font.Gotham,
}
Components.Theme = Theme

local BUTTON_STYLES = {
	accent = { bg = Theme.Accent, hover = Color3.fromRGB(255, 160, 95), text = Color3.fromRGB(25, 18, 10) },
	primary = { bg = Theme.Primary, hover = Color3.fromRGB(96, 155, 255), text = Color3.new(1, 1, 1) },
	secondary = { bg = Theme.Panel2, hover = Color3.fromRGB(52, 57, 69), text = Theme.Text },
	danger = { bg = Color3.fromRGB(90, 40, 44), hover = Color3.fromRGB(115, 50, 55), text = Theme.Text },
}

function Components.new(className: string, props, children)
	local inst = Instance.new(className)
	for k, v in props or {} do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local new = Components.new

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

local function padding(p)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, p),
		PaddingBottom = UDim.new(0, p),
		PaddingLeft = UDim.new(0, p),
		PaddingRight = UDim.new(0, p),
	})
end

local function listLayout(pad, horizontal)
	return new("UIListLayout", {
		Padding = UDim.new(0, pad or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	})
end

-- Compteur d'ordre d'affichage.
function Components.orderer()
	local n = 0
	return function()
		n += 1
		return n
	end
end

function Components.page(parent)
	return new("ScrollingFrame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 1, -84),
		Position = UDim2.fromOffset(0, 84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, { listLayout(10), padding(12) })
end

function Components.card(parent, order)
	return new("Frame", {
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
	}, {
		corner(10),
		new("UIStroke", { Color = Theme.Border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		padding(12),
		listLayout(8),
	})
end

function Components.label(parent, text: string, opts)
	opts = opts or {}
	return new("TextLabel", {
		Parent = parent,
		LayoutOrder = opts.order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		RichText = opts.rich or false,
		TextWrapped = true,
		TextXAlignment = opts.align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = opts.size or 14,
		Font = if opts.bold then Theme.FontBold elseif opts.light then Theme.FontLight else Theme.Font,
		TextColor3 = opts.color or Theme.Text,
		LineHeight = opts.lineHeight or 1.1,
	})
end

function Components.header(parent, text: string, order)
	return Components.label(parent, text, { order = order, size = 12, bold = true, color = Theme.Accent })
end

function Components.button(parent, text: string, opts)
	opts = opts or {}
	local style = BUTTON_STYLES[opts.style or "secondary"]
	local enabled = true
	local btn = new("TextButton", {
		Parent = parent,
		LayoutOrder = opts.order,
		Size = opts.size or UDim2.new(1, 0, 0, opts.height or 40),
		BackgroundColor3 = style.bg,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = text,
		TextSize = opts.textSize or 14,
		Font = Theme.FontBold,
		TextColor3 = style.text,
		TextWrapped = true,
	}, { corner(8) })
	btn.MouseEnter:Connect(function()
		if enabled then
			btn.BackgroundColor3 = style.hover
		end
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = style.bg
	end)
	btn.Activated:Connect(function()
		if enabled and opts.onClick then
			opts.onClick()
		end
	end)
	local handle = { instance = btn }
	function handle.setEnabled(v: boolean)
		enabled = v
		btn.Active = v
		btn.BackgroundTransparency = if v then 0 else 0.55
		btn.TextTransparency = if v then 0 else 0.5
		if not v then
			btn.BackgroundColor3 = style.bg
		end
	end
	function handle.setText(t: string)
		btn.Text = t
	end
	function handle.setVisible(v: boolean)
		btn.Visible = v
	end
	return handle
end

-- Ligne horizontale (enfants dimensionnés en proportion).
function Components.row(parent, order, height)
	return new("Frame", {
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height or 36),
		BackgroundTransparency = 1,
	}, { listLayout(6, true) })
end

-- Contrôle segmenté (ex. Faible | Moyenne | Forte).
function Components.segmented(parent, options, index: number, onChange, order)
	local frame = new("Frame", {
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
	}, { corner(8), padding(3), listLayout(3, true) })
	local buttons = {}
	local current = index
	local function refresh()
		for i, b in buttons do
			local on = i == current
			b.BackgroundColor3 = if on then Theme.Panel2 else Theme.Bg
			b.TextColor3 = if on then Theme.Accent else Theme.SubText
		end
	end
	local w = 1 / #options
	for i, opt in options do
		local b = new("TextButton", {
			Parent = frame,
			LayoutOrder = i,
			Size = UDim2.new(w, -3, 1, 0),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = opt,
			TextSize = 13,
			Font = Theme.FontBold,
		}, { corner(6) })
		b.Activated:Connect(function()
			if current ~= i then
				current = i
				refresh()
				onChange(i, opt)
			end
		end)
		buttons[i] = b
	end
	refresh()
	return {
		instance = frame,
		set = function(i)
			current = i
			refresh()
		end,
	}
end

-- Slider 0..100. onChange(value 0..1, phase "begin" | "move" | "end").
function Components.slider(parent, labelText: string, value: number, onChange, order)
	local frame = new("Frame", {
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
	})
	local title = new("TextLabel", {
		Parent = frame,
		Size = UDim2.new(1, -50, 0, 16),
		BackgroundTransparency = 1,
		Text = labelText,
		TextSize = 12,
		Font = Theme.Font,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local valueLabel = new("TextLabel", {
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 50, 0, 16),
		BackgroundTransparency = 1,
		TextSize = 12,
		Font = Theme.FontBold,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local track = new("Frame", {
		Parent = frame,
		Position = UDim2.new(0, 7, 0, 29),
		Size = UDim2.new(1, -14, 0, 6),
		BackgroundColor3 = Theme.Panel2,
		BorderSizePixel = 0,
	}, { corner(3) })
	local fill = new("Frame", {
		Parent = track,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	}, { corner(3) })
	local knob = new("Frame", {
		Parent = track,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.Text,
		BorderSizePixel = 0,
	}, { corner(8) })
	local hit = new("TextButton", {
		Parent = frame,
		Position = UDim2.new(0, 0, 0, 18),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})
	local current = value
	local function show(v)
		current = math.clamp(v, 0, 1)
		fill.Size = UDim2.fromScale(current, 1)
		knob.Position = UDim2.fromScale(current, 0.5)
		valueLabel.Text = tostring(math.floor(current * 100 + 0.5))
	end
	local function fromX(x)
		local rel = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		return math.clamp(rel, 0, 1)
	end
	local dragging = false
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			show(fromX(input.Position.X))
			onChange(current, "begin")
		end
	end)
	hit.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			show(fromX(input.Position.X))
			onChange(current, "move")
		end
	end)
	local function stop()
		if dragging then
			dragging = false
			onChange(current, "end")
		end
	end
	hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			stop()
		end
	end)
	hit.MouseLeave:Connect(stop)
	show(value)
	return {
		instance = frame,
		set = function(v)
			if not dragging then
				show(v)
			end
		end,
		setVisible = function(v)
			frame.Visible = v
		end,
		setTitle = function(t)
			title.Text = t
		end,
	}
end

function Components.textbox(parent, placeholder: string, text: string, onCommit, opts)
	opts = opts or {}
	local box = new("TextBox", {
		Parent = parent,
		LayoutOrder = opts.order,
		Size = opts.size or UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
		Text = text or "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = Theme.Muted,
		TextColor3 = Theme.Text,
		TextSize = 14,
		Font = Theme.Font,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, { corner(8), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
	box.FocusLost:Connect(function()
		onCommit(box.Text)
	end)
	return {
		instance = box,
		set = function(t)
			if not box:IsFocused() then
				box.Text = t
			end
		end,
		get = function()
			return box.Text
		end,
	}
end

-- Pastilles de couleur cliquables (Primary, Secondary, ...).
function Components.swatches(parent, slots, onClick, order)
	local frame = new("Frame", {
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
	}, { listLayout(6, true) })
	local items = {}
	local w = 1 / #slots
	for i, slot in slots do
		local cell = new("TextButton", {
			Parent = frame,
			LayoutOrder = i,
			Size = UDim2.new(w, -5, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
		})
		local chip = new("Frame", {
			Parent = cell,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = Theme.Panel2,
			BorderSizePixel = 0,
		}, { corner(6), new("UIStroke", { Color = Theme.Border, Thickness = 1 }) })
		new("TextLabel", {
			Parent = cell,
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = slot,
			TextSize = 10,
			Font = Theme.Font,
			TextColor3 = Theme.SubText,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		cell.Activated:Connect(function()
			onClick(slot)
		end)
		items[slot] = chip
	end
	return {
		instance = frame,
		setColors = function(palette)
			for slot, chip in items do
				chip.BackgroundColor3 = if palette and palette[slot] then palette[slot] else Theme.Panel2
			end
		end,
	}
end

-- Liste de statut : { { ok = true|false|nil, text } }.
function Components.status(parent, order)
	local frame = new("Frame", {
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, { listLayout(4) })
	local pool = {}
	return {
		instance = frame,
		set = function(lines)
			for i, line in lines do
				local l = pool[i]
				if not l then
					l = Components.label(frame, "", { order = i, size = 13 })
					l.RichText = true
					pool[i] = l
				end
				local icon, color
				if line.busy then
					icon, color = "●", Theme.Warn
				elseif line.ok == true then
					icon, color = "✓", Theme.Success
				elseif line.ok == false then
					icon, color = "✗", Theme.Danger
				else
					icon, color = "•", Theme.SubText
				end
				local safe = line.text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
				l.Text = string.format('<font color="#%s"><b>%s</b></font>  %s', color:ToHex(), icon, safe)
				l.Visible = true
			end
			for i = #lines + 1, #pool do
				pool[i].Visible = false
			end
		end,
	}
end

-- Section repliable (fermée par défaut).
function Components.collapsible(parent, title: string, order)
	local frame = new("Frame", {
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, { listLayout(6) })
	local open = false
	local toggle = new("TextButton", {
		Parent = frame,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = "▸  " .. title,
		TextSize = 13,
		Font = Theme.FontBold,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local body = Components.label(frame, "", { order = 2, size = 12, light = true, color = Theme.SubText })
	body.Visible = false
	toggle.Activated:Connect(function()
		open = not open
		body.Visible = open
		toggle.Text = (if open then "▾  " else "▸  ") .. title
	end)
	return {
		instance = frame,
		setText = function(t)
			body.Text = t
		end,
	}
end

return Components
