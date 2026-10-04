--!strict
-- Turns project nodes into real Roblox Instances, and updates Instances it built before.
--
-- The same code draws the live preview in the editor and writes the final interface into
-- the game, so what you see while editing is exactly what gets generated.
--
-- Every Instance that stands for a node carries the GuiCreatorId attribute. Helper objects
-- (UICorner, UIStroke...) are named "GC_..." and carry GuiCreatorDecor. Anything else a
-- developer adds by hand is left alone.

local Ids = require(script.Parent.Parent.Core.Ids)
local Schema = require(script.Parent.Parent.Schema.NodeTypes)
local Style = require(script.Parent.Parent.Style.Style)

local Builder = {}

Builder.DECOR_ATTRIBUTE = "GuiCreatorDecor"
Builder.PROJECT_ATTRIBUTE = "GuiCreatorProject"

export type Context = {
	project: any,
	tokens: { [string]: any },
	mode: "preview" | "game",
	pageSize: Vector2?, -- preview only: the simulated screen size
	instances: { [string]: Instance }, -- filled while building: node id -> Instance
	previous: { [string]: Instance }, -- instances of the last build, to find moved nodes
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
local TEXT_X = {
	Left = Enum.TextXAlignment.Left,
	Center = Enum.TextXAlignment.Center,
	Right = Enum.TextXAlignment.Right,
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

local IMAGE_TYPES = { Image = true, Icon = true }
local FRAME_TYPES = { Window = true, Panel = true, Card = true, Grid = true, List = true }

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
	elseif IMAGE_TYPES[nodeType] then
		return "ImageLabel"
	elseif FRAME_TYPES[nodeType] and props.fill and props.fill.kind == "Image" then
		return "ImageLabel"
	end
	return "Frame"
end

--------------------------------------------------------------------------------
-- Property groups
--------------------------------------------------------------------------------

local function applyCorner(target: Instance, props: any)
	local radius = Style.number(props.corner, 0)
	if radius > 0 then
		decor(target, "GC_Corner", "UICorner").CornerRadius = UDim.new(0, radius)
	else
		removeDecor(target, "GC_Corner")
	end
end

local function applyStroke(target: Instance, props: any)
	local stroke = props.stroke or {}
	local thickness = Style.number(stroke.thickness, 1)
	if stroke.enabled and thickness > 0 then
		local s = decor(target, "GC_Stroke", "UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = Style.color(stroke.color, Color3.new(0, 0, 0))
		s.Thickness = thickness
		s.Transparency = Style.number(stroke.transparency, 0)
	else
		removeDecor(target, "GC_Stroke")
	end
end

-- Background of a GuiObject: plain colour, gradient, image (ImageLabel only) or nothing.
local function applyFill(target: any, props: any, allowImage: boolean)
	local fill = props.fill or {}
	local kind = fill.kind or "Color"
	local transparency = Style.number(fill.transparency, 0)

	if kind == "Gradient" then
		target.BackgroundColor3 = Color3.new(1, 1, 1)
		target.BackgroundTransparency = transparency
		local gradient = decor(target, "GC_Gradient", "UIGradient")
		gradient.Color = ColorSequence.new(Style.color(fill.color), Style.color(fill.color2))
		gradient.Rotation = Style.number(fill.rotation, 90)
	else
		removeDecor(target, "GC_Gradient")
		if kind == "Color" then
			target.BackgroundColor3 = Style.color(fill.color)
			target.BackgroundTransparency = transparency
		else
			target.BackgroundTransparency = 1
		end
	end

	if allowImage and target:IsA("ImageLabel") then
		if kind == "Image" then
			target.Image = assetId(fill.image)
			target.ScaleType = SCALE_TYPES[fill.scaleType] or Enum.ScaleType.Stretch
			local tile = Style.number(fill.tileSize, 64)
			target.TileSize = UDim2.fromOffset(tile, tile)
			target.ImageColor3 = Style.color(fill.tint, Color3.new(1, 1, 1))
			target.ImageTransparency = transparency
		else
			target.Image = ""
		end
	end
end

local function applyText(target: any, props: any)
	local text = props.text or {}
	target.Text = tostring(text.value or "")
	target.Font = Style.font(text.font)
	target.TextSize = Style.number(text.size, 20)
	target.TextScaled = text.scaled == true
	target.TextWrapped = text.wrap == true
	target.TextColor3 = Style.color(text.color)
	target.TextTransparency = Style.number(text.transparency, 0)
	target.TextXAlignment = TEXT_X[text.alignX] or Enum.TextXAlignment.Center
	target.TextYAlignment = Enum.TextYAlignment.Center
	target.TextStrokeColor3 = Style.color(text.strokeColor, Color3.new(0, 0, 0))
	target.TextStrokeTransparency = if text.strokeEnabled then 0 else 1
end

local function applyImage(target: any, props: any)
	local image = props.image or {}
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
		local grid = decor(target, "GC_Layout", "UIGridLayout")
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.CellSize =
			UDim2.fromOffset(Style.number(layout.cellWidth, 100), Style.number(layout.cellHeight, 100))
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

-- Buttons draw their background and text in two helper children, so gradients and images
-- never tint the label and the text always stays on top.
local function applyButton(target: any, props: any)
	target.Text = ""
	target.AutoButtonColor = false
	target.BackgroundTransparency = 1

	local fillKind = props.fill and props.fill.kind
	local fill = decor(target, "GC_Fill", if fillKind == "Image" then "ImageLabel" else "Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.ZIndex = 0
	applyFill(fill, props, true)
	applyCorner(fill, props)
	applyStroke(fill, props)
	removeDecor(target, "GC_Corner")
	removeDecor(target, "GC_Stroke")
	removeDecor(target, "GC_Gradient")

	local label = decor(target, "GC_Label", "TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.ZIndex = 1
	applyText(label, props)
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
		-- The kind of Instance changed (for example a background image was added):
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
		if ctx.mode == "game" then
			instance.ResetOnSpawn = false
			instance.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			instance:SetAttribute(Builder.PROJECT_ATTRIBUTE, ctx.project.id)
			local page = ctx.project.pages[node.pageId]
			instance.Enabled = page == nil or page.openByDefault ~= false
		else
			local size = ctx.pageSize or Vector2.new(1280, 720)
			instance.Size = UDim2.fromOffset(size.X, size.Y)
			instance.BackgroundTransparency = 1
			instance.BorderSizePixel = 0
			instance.ClipsDescendants = true
		end
	else
		applyGuiObject(ctx, instance, node, props, order or 0)
		if node.type == "Button" then
			applyButton(instance, props)
		else
			applyFill(instance, props, not IMAGE_TYPES[node.type])
			applyCorner(instance, props)
			applyStroke(instance, props)
			if node.type == "Text" then
				applyText(instance, props)
			elseif IMAGE_TYPES[node.type] then
				applyImage(instance, props)
			end
		end
		applyAspect(instance, props)
		if Schema.get(node.type).container and node.type ~= "Button" then
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
