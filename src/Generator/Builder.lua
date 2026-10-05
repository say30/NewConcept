--!strict
-- Turns project nodes into real Roblox Instances, and updates Instances it built before.
--
-- The same code draws the live preview in the editor and writes the final interface into
-- the game, so what you see while editing is exactly what gets generated.
--
-- Every Instance that stands for a node carries the GuiCreatorId attribute. The look of a
-- surface (fill, outline, pattern, shadow, shine) is drawn by helper children named "GC_..."
-- that carry GuiCreatorDecor and sit below the real children (negative ZIndex). Anything
-- else a developer adds by hand is left alone.

local Icons = require(script.Parent.Parent.Visual.Icons)
local Ids = require(script.Parent.Parent.Core.Ids)
local Patterns = require(script.Parent.Parent.Visual.Patterns)
local Schema = require(script.Parent.Parent.Schema.NodeTypes)
local Style = require(script.Parent.Parent.Style.Style)

local Builder = {}

Builder.DECOR_ATTRIBUTE = "GuiCreatorDecor"
Builder.PROJECT_ATTRIBUTE = "GuiCreatorProject"
local SIGNATURE_ATTRIBUTE = "GuiCreatorSignature"

-- Screen size assumed when generating for the game, to know how much pattern to draw.
local GAME_SCREEN = Vector2.new(1920, 1080)

local Z_SHADOW, Z_FILL, Z_PATTERN, Z_SHINE = -4, -3, -2, -1

export type Context = {
	project: any,
	tokens: { [string]: any },
	mode: "preview" | "game",
	pageSize: Vector2?, -- preview only: the simulated screen size
	instances: { [string]: Instance }, -- filled while building: node id -> Instance
	previous: { [string]: Instance }, -- instances of the last build, to find moved nodes
	sizes: { [string]: Vector2 }, -- expected pixel size of each node
}

function Builder.newContext(
	project: any,
	mode: "preview" | "game",
	pageSize: Vector2?,
	previous: { [string]: Instance }?
): Context
	return {
		project = project,
		tokens = Style.tokens(project),
		mode = mode,
		pageSize = pageSize,
		instances = {},
		previous = previous or {},
		sizes = {},
	}
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function findChildById(parent: Instance, id: string): Instance?
	for _, child in parent:GetChildren() do
		if child:GetAttribute(Ids.ATTRIBUTE) == id then
			return child
		end
	end
	return nil
end

local function decor(parent: Instance, name: string, className: string): any
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		local created = Instance.new(className)
		created.Name = name
		created:SetAttribute(Builder.DECOR_ATTRIBUTE, true)
		created.Parent = parent
		existing = created
	end
	return existing
end

local function removeDecor(parent: Instance, name: string)
	local existing = parent:FindFirstChild(name)
	if existing and existing:GetAttribute(Builder.DECOR_ATTRIBUTE) then
		existing:Destroy()
	end
end

-- Runs `build` only when `signature` differs from the one stored on `holder`, so heavy
-- decorations (patterns, icons) are not rebuilt on every edit.
local function rebuildIfChanged(holder: Instance, signature: string, build: () -> ())
	if holder:GetAttribute(SIGNATURE_ATTRIBUTE) == signature then
		return
	end
	for _, child in holder:GetChildren() do
		child:Destroy()
	end
	build()
	holder:SetAttribute(SIGNATURE_ATTRIBUTE, signature)
end

local TEXT_X = {
	Left = Enum.TextXAlignment.Left,
	Center = Enum.TextXAlignment.Center,
	Right = Enum.TextXAlignment.Right,
}
local TEXT_Y = {
	Top = Enum.TextYAlignment.Top,
	Center = Enum.TextYAlignment.Center,
	Bottom = Enum.TextYAlignment.Bottom,
}
local ALIGN_X = {
	Start = Enum.HorizontalAlignment.Left,
	Center = Enum.HorizontalAlignment.Center,
	End = Enum.HorizontalAlignment.Right,
}
local ALIGN_Y = {
	Start = Enum.VerticalAlignment.Top,
	Center = Enum.VerticalAlignment.Center,
	End = Enum.VerticalAlignment.Bottom,
}
local SCALE_TYPES = {
	Stretch = Enum.ScaleType.Stretch,
	Fit = Enum.ScaleType.Fit,
	Crop = Enum.ScaleType.Crop,
	Tile = Enum.ScaleType.Tile,
}

local function assetId(value: any): string
	if type(value) == "number" then
		return "rbxassetid://" .. value
	elseif type(value) == "string" and value ~= "" then
		if string.match(value, "^%d+$") then
			return "rbxassetid://" .. value
		end
		return value
	end
	return ""
end

local function hasImageIcon(props: any): boolean
	return props.icon ~= nil and assetId(props.icon.image) ~= ""
end

function Builder.classFor(node: any, props: any, mode: string): string
	local nodeType = node.type
	if nodeType == "Page" then
		return if mode == "game" then "ScreenGui" else "Frame"
	elseif nodeType == "ScrollArea" then
		return "ScrollingFrame"
	elseif nodeType == "Text" then
		return "TextLabel"
	elseif nodeType == "Button" then
		return "TextButton"
	elseif nodeType == "Input" then
		return "TextBox"
	elseif nodeType == "Image" then
		return "ImageLabel"
	elseif nodeType == "Icon" and hasImageIcon(props) then
		return "ImageLabel"
	end
	return "Frame"
end

--------------------------------------------------------------------------------
-- Sizes
--------------------------------------------------------------------------------

-- Expected pixel size of a node, from its UDim2 size and its parent's size. Grid cells take
-- the size the grid gives them.
local function expectedSize(props: any, parentSize: Vector2, parentProps: any?): Vector2
	local layout = parentProps and parentProps.layout
	if layout and layout.kind == "Grid" then
		local columns = math.max(1, Style.number(layout.columns, 3))
		local spacing = Style.number(layout.spacing, 10)
		local inner = parentSize.X
		return Vector2.new((inner - spacing * (columns - 1)) / columns, Style.number(layout.cellHeight, 150))
	end
	local size = Style.udim2(props.size, UDim2.fromOffset(100, 100))
	local w = size.X.Scale * parentSize.X + size.X.Offset
	local h = size.Y.Scale * parentSize.Y + size.Y.Offset
	local ratio = Style.number(props.aspect, 0)
	if ratio > 0 then
		if w / math.max(h, 1) > ratio then
			w = h * ratio
		else
			h = w / ratio
		end
	end
	return Vector2.new(math.max(w, 1), math.max(h, 1))
end

--------------------------------------------------------------------------------
-- Property groups
--------------------------------------------------------------------------------

local function cornerRadius(props: any): UDim?
	local radius = Style.number(props.corner, 0)
	if radius < 0 then
		return UDim.new(0.5, 0)
	elseif radius > 0 then
		return UDim.new(0, radius)
	end
	return nil
end

local function applyCorner(target: Instance, radius: UDim?)
	if radius then
		decor(target, "GC_Corner", "UICorner").CornerRadius = radius
	else
		removeDecor(target, "GC_Corner")
	end
end

local function applyStroke(target: Instance, stroke: any)
	stroke = stroke or {}
	local thickness = Style.number(stroke.thickness, 1)
	if stroke.enabled and thickness > 0 then
		local s = decor(target, "GC_Stroke", "UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Color = Style.color(stroke.color, Color3.new(0, 0, 0))
		s.Thickness = thickness
		s.Transparency = Style.number(stroke.transparency, 0)
	else
		removeDecor(target, "GC_Stroke")
	end
end

local function setGradient(target: Instance, a: Color3?, b: Color3?, rotation: number)
	if a and b then
		local gradient = decor(target, "GC_Gradient", "UIGradient")
		gradient.Color = ColorSequence.new(a, b)
		gradient.Rotation = rotation
	else
		removeDecor(target, "GC_Gradient")
	end
end

local function luminance(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

-- Paints a GuiObject with the fill settings: plain colour, shaded colour, two-colour
-- gradient, image (ImageLabel only) or nothing.
local function applyFill(target: any, fill: any)
	fill = fill or {}
	local kind = fill.kind or "Color"
	local transparency = Style.number(fill.transparency, 0)
	local color = Style.color(fill.color)

	if kind == "Shade" then
		target.BackgroundColor3 = Color3.new(1, 1, 1)
		target.BackgroundTransparency = transparency
		-- Light colours turn grey quickly, so they are shaded less.
		local amount = Style.number(fill.shade, 0.25) * (1 - luminance(color) * 0.6)
		setGradient(target, Style.shade(color, -0.12), Style.shade(color, amount), 90)
	elseif kind == "Gradient" then
		target.BackgroundColor3 = Color3.new(1, 1, 1)
		target.BackgroundTransparency = transparency
		setGradient(target, color, Style.color(fill.color2), Style.number(fill.rotation, 90))
	elseif kind == "Color" then
		target.BackgroundColor3 = color
		target.BackgroundTransparency = transparency
		setGradient(target, nil, nil, 0)
	else
		target.BackgroundTransparency = 1
		setGradient(target, nil, nil, 0)
	end

	if target:IsA("ImageLabel") then
		target.Image = if kind == "Image" then assetId(fill.image) else ""
		target.ScaleType = SCALE_TYPES[fill.scaleType] or Enum.ScaleType.Stretch
		local tile = Style.number(fill.tileSize, 64)
		target.TileSize = UDim2.fromOffset(tile, tile)
		target.ImageColor3 = Style.color(fill.tint, Color3.new(1, 1, 1))
		target.ImageTransparency = transparency
		if kind == "Image" then
			target.BackgroundTransparency = 1
		end
	end
end

local function fillColor(fill: any): Color3
	return Style.color(fill and fill.color, Color3.new(0.5, 0.5, 0.5))
end

local function layer(target: Instance, name: string, className: string, z: number): any
	local f = decor(target, name, className)
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0, 0)
	f.Position = UDim2.new()
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	return f
end

-- Draws a surface (window, panel, card, button) with helper layers under its children.
local function applySurface(target: any, props: any, size: Vector2)
	target.BackgroundTransparency = 1
	local radius = cornerRadius(props)
	local fill = props.fill or {}

	-- Shadow: a dark copy below the surface ("Drop"), or a darker lip under it ("Depth").
	local shadow = props.shadow or {}
	local depth = Style.number(shadow.size, 4)
	if shadow.kind == "Drop" or shadow.kind == "Depth" and depth > 0 then
		local s = layer(target, "GC_Shadow", "Frame", Z_SHADOW)
		s.Position = UDim2.fromOffset(0, depth)
		if shadow.kind == "Drop" then
			s.BackgroundColor3 = Style.color(shadow.color, Color3.new(0, 0, 0))
			s.BackgroundTransparency = Style.number(shadow.transparency, 0.55)
			applyStroke(s, nil)
		else
			s.BackgroundColor3 = Style.shade(fillColor(fill), 0.45)
			s.BackgroundTransparency = if fill.kind == "None" then 1 else 0
			applyStroke(s, props.stroke)
		end
		applyCorner(s, radius)
	else
		removeDecor(target, "GC_Shadow")
	end

	local f = layer(target, "GC_Fill", if fill.kind == "Image" then "ImageLabel" else "Frame", Z_FILL)
	applyFill(f, fill)
	applyCorner(f, radius)
	applyStroke(f, props.stroke)

	local pattern = props.pattern or {}
	if pattern.kind and pattern.kind ~= "None" then
		local p = layer(target, "GC_Pattern", "CanvasGroup", Z_PATTERN)
		p.BackgroundTransparency = 1
		p.GroupTransparency = Style.number(pattern.transparency, 0.8)
		applyCorner(p, radius)
		local w, h = math.ceil(size.X / 50) * 50, math.ceil(size.Y / 50) * 50
		local step = Style.number(pattern.size, 26)
		local color = Style.color(pattern.color)
		local signature = table.concat({ pattern.kind, w, h, step, Style.toHex(color) }, "|")
		rebuildIfChanged(p, signature, function()
			applyCorner(p, radius)
			Patterns.build(p, pattern.kind, w, h, color, step)
		end)
		applyCorner(p, radius)
	else
		removeDecor(target, "GC_Pattern")
	end

	if props.shine then
		local s = decor(target, "GC_Shine", "Frame")
		s.BorderSizePixel = 0
		s.BackgroundColor3 = Color3.new(1, 1, 1)
		s.BackgroundTransparency = 0.72
		s.AnchorPoint = Vector2.new(0.5, 0)
		s.Position = UDim2.new(0.5, 0, 0, 4)
		s.Size = UDim2.new(1, -10, 0.4, -4)
		s.ZIndex = Z_SHINE
		applyCorner(s, if radius then UDim.new(radius.Scale, math.max(radius.Offset - 4, 0)) else nil)
	else
		removeDecor(target, "GC_Shine")
	end

	removeDecor(target, "GC_Corner")
	removeDecor(target, "GC_Stroke")
	removeDecor(target, "GC_Gradient")
end

local function applyText(target: any, text: any)
	text = text or {}
	target.Text = tostring(text.value or "")
	target.Font = Style.font(text.font)
	target.TextSize = Style.number(text.size, 20)
	target.TextScaled = text.scaled == true
	target.TextWrapped = text.wrap == true or text.scaled == true
	target.TextColor3 = Style.color(text.color)
	target.TextTransparency = Style.number(text.transparency, 0)
	target.TextXAlignment = TEXT_X[text.alignX] or Enum.TextXAlignment.Center
	target.TextYAlignment = TEXT_Y[text.alignY] or Enum.TextYAlignment.Center
	target.TextStrokeTransparency = 1
	local stroke = text.stroke or {}
	-- A dark outline around dark text only blurs it.
	local readable = luminance(target.TextColor3) > 0.4 or luminance(Style.color(stroke.color)) > 0.4
	if stroke.enabled and readable and Style.number(stroke.thickness, 2) > 0 then
		local s = decor(target, "GC_TextStroke", "UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Color = Style.color(stroke.color, Color3.new(0, 0, 0))
		s.Thickness = Style.number(stroke.thickness, 2)
	else
		removeDecor(target, "GC_TextStroke")
	end
end

-- Draws a built-in icon (or nothing) inside `holder`.
local function applyIcon(holder: Instance, id: string)
	rebuildIfChanged(holder, "icon|" .. id, function()
		if Icons.get(id) then
			Icons.build(id, holder, 1)
		end
	end)
end

local function applyImage(target: any, image: any)
	image = image or {}
	target.BackgroundTransparency = 1
	target.Image = assetId(image.id)
	target.ImageColor3 = Style.color(image.color, Color3.new(1, 1, 1))
	target.ImageTransparency = Style.number(image.transparency, 0)
	target.ScaleType = SCALE_TYPES[image.scaleType] or Enum.ScaleType.Fit
end

local function applyLayout(target: Instance, props: any)
	local layout = props.layout or {}
	local kind = layout.kind or "None"
	if kind == "None" then
		removeDecor(target, "GC_Layout")
		removeDecor(target, "GC_Padding")
		return
	end

	local spacing = Style.number(layout.spacing, 8)
	local alignX = ALIGN_X[layout.align] or Enum.HorizontalAlignment.Center
	local alignY = ALIGN_Y[layout.align] or Enum.VerticalAlignment.Center

	if kind == "Grid" then
		local columns = math.max(1, Style.number(layout.columns, 3))
		local grid = decor(target, "GC_Layout", "UIGridLayout")
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		-- One pixel less per cell so rounding never pushes the last column to a new row.
		grid.CellSize = UDim2.new(
			1 / columns,
			-spacing * (columns - 1) / columns - 1,
			0,
			Style.number(layout.cellHeight, 150)
		)
		grid.CellPadding = UDim2.fromOffset(spacing, spacing)
		grid.HorizontalAlignment = alignX
		grid.VerticalAlignment = Enum.VerticalAlignment.Top
	else
		local list = decor(target, "GC_Layout", "UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.FillDirection = if kind == "Horizontal"
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		list.Padding = UDim.new(0, spacing)
		if kind == "Horizontal" then
			list.HorizontalAlignment = alignX
			list.VerticalAlignment = Enum.VerticalAlignment.Center
		else
			list.HorizontalAlignment = Enum.HorizontalAlignment.Center
			list.VerticalAlignment = alignY
		end
	end

	-- Grids size their cells from the full container, so they get no inner padding.
	if kind == "Grid" then
		removeDecor(target, "GC_Padding")
		return
	end
	local padding = UDim.new(0, Style.number(layout.padding, 0))
	local pad = decor(target, "GC_Padding", "UIPadding")
	pad.PaddingTop = padding
	pad.PaddingBottom = padding
	pad.PaddingLeft = padding
	pad.PaddingRight = padding
end

local function applyAspect(target: Instance, props: any)
	local ratio = Style.number(props.aspect, 0)
	if ratio > 0 then
		decor(target, "GC_Aspect", "UIAspectRatioConstraint").AspectRatio = ratio
	else
		removeDecor(target, "GC_Aspect")
	end
end

local function applyGuiObject(ctx: Context, target: any, node: any, props: any, order: number)
	target.Position = Style.udim2(props.position, UDim2.fromScale(0.5, 0.5))
	target.Size = Style.udim2(props.size, UDim2.fromOffset(100, 100))
	target.AnchorPoint = Style.vector2(props.anchor, Vector2.new(0.5, 0.5))
	target.Rotation = Style.number(props.rotation, 0)
	target.ZIndex = Style.number(props.zIndex, 1)
	target.LayoutOrder = order
	target.BorderSizePixel = 0
	target.ClipsDescendants = props.clip == true
	if ctx.mode == "preview" then
		target.Visible = not node.editor.hidden
	else
		target.Visible = props.visible ~= false
	end
end

-- A button shows an optional icon on the left and its text, above its surface.
local function applyButton(target: any, props: any, size: Vector2)
	target.Text = ""
	target.AutoButtonColor = false

	local icon = props.icon or {}
	local hasIcon = Icons.get(icon.id or "") ~= nil or hasImageIcon(props)
	local text = props.text or {}
	local hasText = tostring(text.value or "") ~= ""
	local iconSize = math.floor(math.min(size.Y * 0.72, size.X - 8))
	local pad = math.floor(size.Y * 0.16)

	if hasIcon then
		local holder = decor(target, "GC_Icon", if hasImageIcon(props) then "ImageLabel" else "Frame")
		holder.BackgroundTransparency = 1
		holder.ZIndex = 0
		holder.Size = UDim2.fromOffset(iconSize, iconSize)
		if hasText then
			holder.AnchorPoint = Vector2.new(0, 0.5)
			holder.Position = UDim2.new(0, pad, 0.5, 0)
		else
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Position = UDim2.fromScale(0.5, 0.5)
		end
		if holder:IsA("ImageLabel") then
			holder.Image = assetId(icon.image)
		else
			applyIcon(holder, icon.id)
		end
	else
		removeDecor(target, "GC_Icon")
	end

	if hasText then
		local label = decor(target, "GC_Label", "TextLabel")
		label.BackgroundTransparency = 1
		label.ZIndex = 0
		local left = if hasIcon then pad + iconSize + 2 else 8
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = UDim2.new(0, left, 0.5, -1)
		label.Size = UDim2.new(1, -left - 8, 1, -6)
		applyText(label, text)
	else
		removeDecor(target, "GC_Label")
	end
end

--------------------------------------------------------------------------------
-- Sync
--------------------------------------------------------------------------------

local syncNode

local function syncChildren(ctx: Context, node: any, target: Instance)
	local wanted = {}
	for index, childId in node.children do
		wanted[childId] = true
		syncNode(ctx, childId, target, index)
	end
	for _, child in target:GetChildren() do
		local id = child:GetAttribute(Ids.ATTRIBUTE)
		if id and not wanted[id] then
			child:Destroy()
		end
	end
end

local function parentInfo(ctx: Context, node: any): (Vector2, any)
	local parent = node.parent and ctx.project.nodes[node.parent]
	if not parent then
		return ctx.pageSize or GAME_SCREEN, nil
	end
	local size = ctx.sizes[parent.id] or ctx.pageSize or GAME_SCREEN
	local parentProps = if parent.type == "Page"
		then nil
		else Style.resolve(Schema.effectiveProps(parent), ctx.tokens)
	return size, parentProps
end

-- Builds or updates the Instance for `nodeId` under `parent`. Returns it.
function syncNode(ctx: Context, nodeId: string, parent: Instance, order: number?): Instance
	local node = ctx.project.nodes[nodeId]
	local props = Style.resolve(Schema.effectiveProps(node), ctx.tokens)
	local className = Builder.classFor(node, props, ctx.mode)

	local target = findChildById(parent, nodeId)
	local cached = ctx.previous[nodeId]
	if not target and cached and cached.Parent ~= nil then
		target = cached -- the node moved to another parent
	end
	if target and target.ClassName ~= className then
		-- The kind of Instance changed (for example an image icon was set):
		-- rebuild it and carry over everything that is not a GuiCreator helper.
		local replacement = Instance.new(className)
		for _, child in target:GetChildren() do
			if not child:GetAttribute(Builder.DECOR_ATTRIBUTE) then
				child.Parent = replacement
			end
		end
		target:Destroy()
		target = replacement
	end
	if not target then
		target = Instance.new(className)
	end
	local instance = target :: any
	instance:SetAttribute(Ids.ATTRIBUTE, nodeId)
	instance.Name = node.name
	ctx.instances[nodeId] = instance

	if node.type == "Page" then
		local size = ctx.pageSize or GAME_SCREEN
		ctx.sizes[nodeId] = size
		if ctx.mode == "game" then
			instance.ResetOnSpawn = false
			instance.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			instance.IgnoreGuiInset = true
			instance:SetAttribute(Builder.PROJECT_ATTRIBUTE, ctx.project.id)
			local page = ctx.project.pages[node.pageId]
			instance.Enabled = page == nil or page.openByDefault ~= false
		else
			instance.Size = UDim2.fromOffset(size.X, size.Y)
			instance.BackgroundTransparency = 1
			instance.BorderSizePixel = 0
			instance.ClipsDescendants = true
		end
	else
		local parentSize, parentProps = parentInfo(ctx, node)
		local size = expectedSize(props, parentSize, parentProps)
		if ctx.mode == "game" then
			size *= 1.25 -- leave room for bigger screens
		end
		ctx.sizes[nodeId] = size

		applyGuiObject(ctx, instance, node, props, order or 0)
		local typeInfo = Schema.get(node.type)
		if typeInfo.surface then
			applySurface(instance, props, size)
		else
			instance.BackgroundTransparency = 1
		end
		if node.type == "Button" then
			applyButton(instance, props, size)
		elseif node.type == "Text" then
			applyText(instance, props.text)
		elseif node.type == "Input" then
			applyText(instance, props.text)
			removeDecor(instance, "GC_TextStroke")
			instance.PlaceholderText = tostring(props.text.placeholder or "")
			instance.PlaceholderColor3 = Style.color(props.text.placeholderColor)
			instance.ClearTextOnFocus = false
			applyFill(instance, props.fill)
			applyCorner(instance, cornerRadius(props))
			applyStroke(instance, props.stroke)
		elseif node.type == "Image" then
			applyImage(instance, props.image)
			applyCorner(instance, cornerRadius(props))
		elseif node.type == "Icon" then
			if instance:IsA("ImageLabel") then
				applyImage(instance, { id = props.icon.image, color = props.icon.color, scaleType = "Fit" })
				removeDecor(instance, "GC_Icon")
			else
				local holder = decor(instance, "GC_Icon", "Frame")
				holder.BackgroundTransparency = 1
				holder.Size = UDim2.fromScale(1, 1)
				holder.ZIndex = 0
				applyIcon(holder, props.icon.id or "")
			end
		end
		applyAspect(instance, props)
		if props.layout then
			applyLayout(instance, props)
		end
		if node.type == "ScrollArea" then
			local layoutKind = props.layout and props.layout.kind
			instance.ScrollBarThickness = 6
			instance.CanvasSize = UDim2.new()
			instance.AutomaticCanvasSize = if layoutKind == "Horizontal"
				then Enum.AutomaticSize.X
				else Enum.AutomaticSize.Y
			instance.ScrollingDirection = if layoutKind == "Horizontal"
				then Enum.ScrollingDirection.X
				else Enum.ScrollingDirection.Y
			instance.ClipsDescendants = true
		end
	end

	if instance.Parent ~= parent then
		instance.Parent = parent
	end
	syncChildren(ctx, node, instance)
	return instance
end

Builder.syncNode = syncNode

return Builder
