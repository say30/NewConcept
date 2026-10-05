--!strict
-- Original game icons drawn with plain GUI objects (Frames, UICorner, UIGradient), in the
-- chunky cartoon style of popular Roblox games: thick dark outline, bright gradient fill,
-- a white shine. They need no uploaded image, so they work in any game and are ours to sell.
--
-- Each icon is drawn on a 100 x 100 grid. A drawing is a list of layers; inside a layer,
-- the outlines of every shape are drawn first and the fills on top, so touching shapes share
-- one outer outline. A new layer starts with `d:layer()`, for shapes that sit in front of
-- others with their own outline.

local Icons = {}

local OUTLINE = Color3.fromRGB(31, 26, 46)
local OUTLINE_WIDTH = 6
local SQRT2 = math.sqrt(2)

local function rgb(hex: string): Color3
	local n = tonumber(hex, 16) :: number
	return Color3.fromRGB(bit32.rshift(n, 16), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
end

-- Colours used by the icons: a light top and a darker bottom for each.
local C = {
	gold = { rgb("FFE45C"), rgb("F59F00") },
	goldDark = { rgb("F7B500"), rgb("E08600") },
	green = { rgb("8CF05A"), rgb("2FA84F") },
	cash = { rgb("A6EB7F"), rgb("3DA35D") },
	cashDark = { rgb("5BBF6A"), rgb("2E7D45") },
	blue = { rgb("6FD6FF"), rgb("1E88E5") },
	cyan = { rgb("9AF5FF"), rgb("13B5D6") },
	red = { rgb("FF7A7A"), rgb("D62828") },
	redDark = { rgb("E04848"), rgb("A61B1B") },
	purple = { rgb("C99BFF"), rgb("7B2FF7") },
	pink = { rgb("FFA3E0"), rgb("E0459B") },
	orange = { rgb("FFC078"), rgb("F76707") },
	brown = { rgb("D99A5B"), rgb("8B4F22") },
	brownDark = { rgb("A86B37"), rgb("6B3A17") },
	white = { rgb("FFFFFF"), rgb("D5DEE8") },
	gray = { rgb("D0D8E0"), rgb("7A8794") },
	grayDark = { rgb("8C99A6"), rgb("4D5866") },
	cream = { rgb("FFF4D6"), rgb("F2D49B") },
	glass = { rgb("D8F3FF"), rgb("8ED1F0") },
	dark = { OUTLINE, OUTLINE },
}
Icons.colors = C

--------------------------------------------------------------------------------
-- Drawing description
--------------------------------------------------------------------------------

type Shape = {
	kind: string, -- "box" | "tri" | "text" | "clip"
	x: number,
	y: number,
	w: number,
	h: number,
	r: number?, -- corner radius in grid units, or -1 for a pill
	rot: number?,
	dir: string?, -- triangles: "up" | "down" | "left" | "right"
	color: { Color3 },
	outline: boolean,
	transparency: number?,
	text: string?,
	shapes: { Shape }?, -- clip groups
}

local Drawing = {}
Drawing.__index = Drawing

local function newDrawing()
	local self = setmetatable({ layers = { {} }, target = nil :: { Shape }? }, Drawing)
	return self
end

function Drawing:add(shape: Shape)
	local list = self.target or self.layers[#self.layers]
	table.insert(list, shape)
	return shape
end

function Drawing:layer()
	table.insert(self.layers, {})
end

-- Rounded box. `r` in grid units; -1 makes a pill (or a circle when square).
function Drawing:box(x, y, w, h, color, opts: any?)
	opts = opts or {}
	return self:add({
		kind = "box",
		x = x,
		y = y,
		w = w,
		h = h,
		r = opts.r or 6,
		rot = opts.rot,
		color = color,
		outline = opts.outline ~= false,
		transparency = opts.t,
	})
end

function Drawing:circle(cx, cy, d, color, opts: any?)
	opts = opts or {}
	opts.r = -1
	return self:box(cx - d / 2, cy - d / 2, d, d, color, opts)
end

-- Pill centred on (cx, cy), useful for rotated bars.
function Drawing:bar(cx, cy, length, thickness, rot, color, opts: any?)
	opts = opts or {}
	opts.r = opts.r or -1
	opts.rot = rot
	return self:box(cx - length / 2, cy - thickness / 2, length, thickness, color, opts)
end

-- Right-angled triangle. (cx, base) is the middle of its long side; `w` is that side's
-- length and the tip is w/2 away in direction `dir`.
function Drawing:tri(cx, base, w, dir, color, opts: any?)
	opts = opts or {}
	return self:add({
		kind = "tri",
		x = cx,
		y = base,
		w = w,
		h = w / 2,
		r = opts.r or 3,
		dir = dir,
		color = color,
		outline = opts.outline ~= false,
		transparency = opts.t,
	})
end

function Drawing:text(x, y, w, h, value, color, opts: any?)
	opts = opts or {}
	return self:add({
		kind = "text",
		x = x,
		y = y,
		w = w,
		h = h,
		text = value,
		color = color,
		outline = false,
		transparency = opts.t,
	})
end

-- Shapes drawn inside `fn` are cut to the rounded box (x, y, w, h).
function Drawing:clip(x, y, w, h, r, fn)
	local group = self:add({
		kind = "clip",
		x = x,
		y = y,
		w = w,
		h = h,
		r = r,
		color = C.dark,
		outline = false,
		shapes = {},
	})
	local previous = self.target
	self.target = group.shapes
	fn()
	self.target = previous
end

-- A soft white shine, drawn on top of everything before it.
function Drawing:shine(cx, cy, length, thickness, rot)
	return self:bar(cx, cy, length, thickness, rot or -35, C.white, { outline = false, t = 0.35 })
end

--------------------------------------------------------------------------------
-- Turning a drawing into Instances
--------------------------------------------------------------------------------

local function corner(frame: Instance, radius: number?, w: number, h: number, grow: number)
	if radius == nil or radius == 0 then
		return
	end
	local c = Instance.new("UICorner")
	if radius < 0 then
		c.CornerRadius = UDim.new(0.5, 0)
	else
		c.CornerRadius = UDim.new(math.min(0.5, (radius + grow) / math.min(w, h)), 0)
	end
	c.Parent = frame
end

local function paint(frame: any, color: { Color3 }, rotation: number, transparency: number?)
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = transparency or 0
	if color[1] == color[2] then
		frame.BackgroundColor3 = color[1]
		return
	end
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(color[1], color[2])
	g.Rotation = rotation
	g.Parent = frame
end

-- Frame placed with scale values inside a box of the given size (in grid units).
local function place(frame: any, x, y, w, h, space: { number })
	local sx, sy, sw, sh = space[1], space[2], space[3], space[4]
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale((x + w / 2 - sx) / sw, (y + h / 2 - sy) / sh)
	frame.Size = UDim2.fromScale(w / sw, h / sh)
end

local TRI_DIRS = {
	up = { 0, -1 },
	down = { 0, 1 },
	left = { -1, 0 },
	right = { 1, 0 },
}

local drawShape

local function drawBox(shape: Shape, parent: Instance, z: number, grow: number, space, color)
	local f = Instance.new("Frame")
	f.Name = "Shape"
	local w, h = shape.w + grow * 2, shape.h + grow * 2
	place(f, shape.x - grow, shape.y - grow, w, h, space)
	f.Rotation = shape.rot or 0
	f.ZIndex = z
	paint(f, color, 90 - (shape.rot or 0), if grow > 0 then nil else shape.transparency)
	corner(f, shape.r, shape.w, shape.h, grow)
	f.Parent = parent
end

-- A triangle is a rotated square seen through a clipping frame that hides half of it.
local function drawTri(shape: Shape, parent: Instance, z: number, grow: number, space, color)
	local d = TRI_DIRS[shape.dir or "up"]
	local half = shape.w / 2 + grow * SQRT2 -- half of the long side, grown
	local depth = shape.h + grow * SQRT2 -- distance from the base to the tip, grown
	local back = grow -- how far the clip extends behind the base
	local cx, cy = shape.x, shape.y
	local x0, y0, x1, y1
	if d[2] ~= 0 then
		x0, x1 = cx - half, cx + half
		if d[2] < 0 then
			y0, y1 = cy - depth, cy + back
		else
			y0, y1 = cy - back, cy + depth
		end
	else
		y0, y1 = cy - half, cy + half
		if d[1] < 0 then
			x0, x1 = cx - depth, cx + back
		else
			x0, x1 = cx - back, cx + depth
		end
	end
	local clip = Instance.new("Frame")
	clip.Name = "Tri"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.ZIndex = z
	place(clip, x0, y0, x1 - x0, y1 - y0, space)
	clip.Parent = parent

	local side = half * SQRT2
	local diamond = Instance.new("Frame")
	diamond.Name = "Shape"
	diamond.Rotation = 45
	diamond.ZIndex = z
	place(diamond, cx - side / 2, cy - side / 2, side, side, { x0, y0, x1 - x0, y1 - y0 })
	paint(diamond, color, 45, if grow > 0 then nil else shape.transparency)
	if shape.r and shape.r > 0 then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(math.min(0.5, (shape.r + grow) / side), 0)
		c.Parent = diamond
	end
	diamond.Parent = clip
end

local function drawText(shape: Shape, parent: Instance, z: number, space)
	local label = Instance.new("TextLabel")
	label.Name = "Glyph"
	label.BackgroundTransparency = 1
	label.Text = shape.text or ""
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = shape.color[1]
	label.TextTransparency = shape.transparency or 0
	label.ZIndex = z
	place(label, shape.x, shape.y, shape.w, shape.h, space)
	label.Parent = parent
end

local function drawLayer(shapes: { Shape }, parent: Instance, z: number, space): number
	for _, shape in shapes do
		if shape.outline then
			z += 1
			drawShape(shape, parent, z, OUTLINE_WIDTH, space, C.dark)
		end
	end
	for _, shape in shapes do
		z += 1
		drawShape(shape, parent, z, 0, space, shape.color)
	end
	return z
end

function drawShape(shape: Shape, parent: Instance, z: number, grow: number, space, color)
	if shape.kind == "box" then
		drawBox(shape, parent, z, grow, space, color)
	elseif shape.kind == "tri" then
		drawTri(shape, parent, z, grow, space, color)
	elseif shape.kind == "text" then
		drawText(shape, parent, z, space)
	elseif shape.kind == "clip" then
		local group = Instance.new("CanvasGroup")
		group.Name = "Clip"
		group.BackgroundTransparency = 1
		group.ZIndex = z
		place(group, shape.x, shape.y, shape.w, shape.h, space)
		corner(group, shape.r, shape.w, shape.h, 0)
		group.Parent = parent
		drawLayer(shape.shapes :: { Shape }, group, 0, { shape.x, shape.y, shape.w, shape.h })
	end
end

--------------------------------------------------------------------------------
-- The icons
--------------------------------------------------------------------------------

type IconDef = { id: string, label: string, category: string, draw: (any) -> () }

local DEFS: { IconDef } = {}

local function icon(id: string, label: string, category: string, draw: (any) -> ())
	table.insert(DEFS, { id = id, label = label, category = category, draw = draw })
end

-- Currency -------------------------------------------------------------------

icon("Coin", "Pièce", "Monnaie", function(d)
	d:circle(50, 50, 82, C.gold)
	d:circle(50, 50, 56, { C.goldDark[2], C.goldDark[1] }, { outline = false })
	d:circle(50, 52, 50, C.gold, { outline = false })
	d:bar(50, 52, 30, 12, 90, C.goldDark, { outline = false })
	d:shine(32, 28, 22, 9)
end)

icon("Coins", "Tas de pièces", "Monnaie", function(d)
	d:box(8, 64, 52, 22, C.goldDark, { r = -1 })
	d:box(8, 52, 52, 22, C.gold, { r = -1 })
	d:layer()
	d:circle(62, 52, 58, C.gold)
	d:circle(62, 52, 38, { C.goldDark[2], C.goldDark[1] }, { outline = false })
	d:circle(62, 54, 32, C.gold, { outline = false })
	d:shine(50, 34, 16, 7)
end)

icon("Cash", "Billets", "Monnaie", function(d)
	d:box(6, 36, 84, 46, C.cashDark, { r = 6, rot = -10 })
	d:layer()
	d:box(10, 24, 84, 46, C.cash, { r = 6, rot = 6 })
	d:box(18, 32, 68, 30, C.cashDark, { r = 4, rot = 6, outline = false, t = 0.55 })
	d:circle(52, 47, 22, C.cash, { outline = false })
	d:bar(52, 47, 10, 6, 96, C.cashDark, { outline = false })
	d:box(64, 18, 12, 58, C.cream, { r = 2, rot = 6 })
end)

icon("Gem", "Gemme", "Monnaie", function(d)
	d:box(14, 22, 72, 24, C.cyan, { r = 5 })
	d:tri(50, 46, 72, "down", C.blue, { r = 4 })
	d:tri(50, 46, 36, "down", C.cyan, { outline = false, r = 2 })
	d:box(30, 22, 40, 24, { C.white[1], C.cyan[1] }, { r = 2, outline = false, t = 0.3 })
	d:shine(30, 30, 14, 6, -30)
end)

icon("Ticket", "Ticket", "Monnaie", function(d)
	d:box(8, 26, 84, 48, C.orange, { r = 8, rot = -12 })
	d:box(18, 34, 64, 32, C.cream, { r = 4, rot = -12, outline = false })
	d:bar(50, 50, 24, 8, -12, C.orange, { outline = false })
	d:circle(50, 50, 6, C.orange, { outline = false })
end)

-- Shop & items -------------------------------------------------------------

icon("Shop", "Boutique", "Boutique", function(d)
	d:box(14, 40, 72, 52, C.cream, { r = 4 })
	d:box(8, 16, 84, 28, C.red, { r = 6 })
	for i = 0, 4 do
		d:circle(16.4 + i * 16.8, 44, 17, if i % 2 == 1 then C.white else C.red)
	end
	for i = 1, 3, 2 do
		d:box(8 + i * 16.8, 16, 16.8, 28, C.white, { r = 0, outline = false })
	end
	d:box(41, 62, 20, 30, C.brown, { r = 3, outline = false })
	d:box(20, 62, 14, 14, C.glass, { r = 3, outline = false })
	d:box(68, 62, 12, 14, C.glass, { r = 3, outline = false })
end)

icon("Basket", "Panier", "Boutique", function(d)
	d:box(24, 10, 11, 40, C.gray, { r = -1 })
	d:box(65, 10, 11, 40, C.gray, { r = -1 })
	d:box(24, 10, 52, 11, C.gray, { r = -1 })
	d:layer()
	d:box(14, 46, 72, 44, C.red, { r = 10 })
	d:box(8, 38, 84, 16, C.red, { r = 8 })
	for i = 0, 3 do
		d:box(25 + i * 15, 58, 6, 24, C.redDark, { r = -1, outline = false })
	end
	d:shine(26, 44, 18, 5, 0)
end)

icon("Bag", "Sac", "Boutique", function(d)
	d:box(30, 6, 10, 40, C.brownDark, { r = -1 })
	d:box(60, 6, 10, 40, C.brownDark, { r = -1 })
	d:box(30, 6, 40, 10, C.brownDark, { r = -1 })
	d:layer()
	d:box(14, 30, 72, 62, C.orange, { r = 10 })
	d:circle(35, 42, 8, C.brownDark, { outline = false })
	d:circle(65, 42, 8, C.brownDark, { outline = false })
	d:box(26, 60, 48, 16, C.cream, { r = 4, outline = false })
	d:shine(24, 50, 16, 6, -80)
end)

icon("Backpack", "Sac à dos", "Boutique", function(d)
	d:box(40, 6, 20, 16, C.brownDark, { r = 6 })
	d:box(18, 16, 64, 78, C.brown, { r = 22 })
	d:layer()
	d:box(24, 14, 52, 34, C.brownDark, { r = 18 })
	d:layer()
	d:box(28, 58, 44, 28, C.brown, { r = 8 })
	d:box(44, 62, 12, 8, C.brownDark, { r = 2, outline = false })
	d:shine(32, 26, 14, 6, 0)
end)

icon("Chest", "Coffre", "Boutique", function(d)
	d:box(8, 46, 84, 44, C.brown, { r = 6 })
	d:box(8, 18, 84, 34, C.brownDark, { r = 16 })
	d:box(20, 18, 10, 72, C.gold, { r = 2, outline = false })
	d:box(70, 18, 10, 72, C.gold, { r = 2, outline = false })
	d:box(8, 46, 84, 6, C.dark, { r = 0, outline = false })
	d:layer()
	d:box(41, 40, 18, 22, C.gold, { r = 4 })
	d:box(48, 48, 4, 8, C.dark, { r = 2, outline = false })
end)

icon("Gift", "Cadeau", "Boutique", function(d)
	d:bar(36, 22, 30, 18, 25, C.gold)
	d:bar(64, 22, 30, 18, -25, C.gold)
	d:layer()
	d:box(14, 46, 72, 46, C.red, { r = 6 })
	d:box(8, 32, 84, 20, C.red, { r = 6 })
	d:box(43, 32, 14, 60, C.gold, { r = 0, outline = false })
	d:box(14, 46, 72, 6, C.redDark, { r = 0, outline = false, t = 0.2 })
	d:layer()
	d:circle(50, 28, 16, C.gold)
	d:shine(22, 40, 10, 5, 0)
end)

icon("Potion", "Potion", "Boutique", function(d)
	d:box(38, 18, 24, 26, C.glass, { r = 2 })
	d:circle(50, 62, 64, C.glass)
	d:box(34, 6, 32, 14, C.brown, { r = 4 })
	d:clip(18, 30, 64, 64, -1, function()
		d:box(18, 52, 64, 44, C.purple, { r = 0, outline = false })
	end)
	d:circle(40, 68, 10, C.pink, { outline = false, t = 0.2 })
	d:circle(58, 78, 6, C.pink, { outline = false, t = 0.2 })
	d:shine(32, 48, 16, 7, -50)
end)

icon("Egg", "Œuf", "Boutique", function(d)
	d:box(20, 8, 60, 86, C.cream, { r = -1 })
	d:circle(38, 36, 14, C.orange, { outline = false })
	d:circle(62, 58, 18, C.orange, { outline = false })
	d:circle(40, 74, 10, C.orange, { outline = false })
	d:shine(34, 24, 14, 6, -60)
end)

icon("LuckyBlock", "Bloc chance", "Boutique", function(d)
	d:box(10, 10, 80, 80, C.gold, { r = 12 })
	d:box(18, 18, 64, 64, C.goldDark, { r = 8, outline = false, t = 0.5 })
	d:text(24, 16, 52, 68, "?", { C.white[1], C.white[1] })
	d:shine(24, 22, 14, 6, 0)
end)

-- Rewards ------------------------------------------------------------------

icon("Trophy", "Trophée", "Récompense", function(d)
	d:box(10, 16, 26, 30, C.gold, { r = -1 })
	d:box(64, 16, 26, 30, C.gold, { r = -1 })
	d:box(43, 50, 14, 22, C.goldDark, { r = 0 })
	d:box(22, 10, 56, 18, C.gold, { r = 4 })
	d:box(22, 12, 56, 46, C.gold, { r = 26 })
	d:box(28, 70, 44, 12, C.brownDark, { r = 4 })
	d:box(22, 80, 56, 12, C.brown, { r = 4 })
	d:box(26, 12, 6, 34, C.white, { r = -1, outline = false, t = 0.35 })
end)

icon("Crown", "Couronne", "Récompense", function(d)
	d:tri(22, 56, 30, "up", C.gold, { r = 3 })
	d:tri(50, 56, 34, "up", C.gold, { r = 3 })
	d:tri(78, 56, 30, "up", C.gold, { r = 3 })
	d:box(12, 48, 76, 34, C.gold, { r = 6 })
	d:circle(22, 38, 11, C.gold)
	d:circle(50, 34, 11, C.gold)
	d:circle(78, 38, 11, C.gold)
	d:circle(50, 64, 14, C.red, { outline = false })
	d:circle(28, 66, 9, C.blue, { outline = false })
	d:circle(72, 66, 9, C.green, { outline = false })
end)

icon("Medal", "Médaille", "Récompense", function(d)
	d:bar(38, 22, 40, 16, 70, C.red)
	d:bar(62, 22, 40, 16, -70, C.blue)
	d:layer()
	d:circle(50, 62, 56, C.gold)
	d:circle(50, 62, 36, C.goldDark, { outline = false })
	d:text(36, 46, 28, 32, "1", { C.white[1], C.white[1] })
end)

icon("Podium", "Classement", "Récompense", function(d)
	d:box(36, 30, 28, 62, C.gold, { r = 4 })
	d:box(8, 48, 28, 44, C.gray, { r = 4 })
	d:box(64, 60, 28, 32, C.orange, { r = 4 })
	d:text(40, 38, 20, 22, "1", { C.white[1], C.white[1] })
	d:text(12, 54, 20, 20, "2", { C.white[1], C.white[1] })
	d:text(68, 64, 20, 20, "3", { C.white[1], C.white[1] })
end)

icon("Calendar", "Quotidien", "Récompense", function(d)
	d:box(10, 18, 80, 74, C.white, { r = 10 })
	d:box(10, 18, 80, 24, C.red, { r = 10 })
	d:box(10, 32, 80, 10, C.red, { r = 0, outline = false })
	d:box(26, 8, 10, 20, C.grayDark, { r = -1 })
	d:box(64, 8, 10, 20, C.grayDark, { r = -1 })
	d:text(24, 46, 52, 40, "7", { C.red[2], C.red[2] })
end)

icon("Clock", "Minuteur", "Récompense", function(d)
	d:box(40, 4, 20, 14, C.redDark, { r = 4 })
	d:circle(50, 56, 80, C.red)
	d:circle(50, 56, 58, C.white, { outline = false })
	d:bar(50, 46, 24, 8, 90, C.dark, { outline = false })
	d:bar(58, 56, 20, 8, 0, C.dark, { outline = false })
	d:circle(50, 56, 10, C.dark, { outline = false })
end)

icon("Wheel", "Roue", "Récompense", function(d)
	d:circle(50, 54, 80, C.red)
	d:clip(14, 18, 72, 72, -1, function()
		d:bar(50, 54, 110, 22, 45, C.gold, { outline = false })
		d:bar(50, 54, 110, 22, -45, C.gold, { outline = false })
	end)
	d:circle(50, 54, 18, C.white)
	d:tri(50, 4, 28, "down", C.white, { r = 3 })
end)

-- Pets ---------------------------------------------------------------------

icon("Paw", "Patte", "Animaux", function(d)
	d:box(24, 46, 52, 44, C.brown, { r = 22 })
	d:circle(18, 40, 20, C.brown)
	d:circle(37, 22, 20, C.brown)
	d:circle(63, 22, 20, C.brown)
	d:circle(82, 40, 20, C.brown)
	d:box(34, 56, 32, 24, C.pink, { r = 12, outline = false })
end)

icon("Heart", "Cœur", "Animaux", function(d)
	d:circle(31, 38, 42, C.red)
	d:circle(69, 38, 42, C.red)
	d:tri(50, 46, 82, "down", C.red, { r = 6 })
	d:shine(28, 32, 14, 7, -45)
end)

-- Interface ----------------------------------------------------------------

icon("Close", "Fermer", "Interface", function(d)
	d:bar(50, 50, 80, 22, 45, C.white)
	d:bar(50, 50, 80, 22, -45, C.white)
end)

icon("Check", "Valider", "Interface", function(d)
	d:bar(32, 58, 40, 20, 45, C.green)
	d:bar(58, 48, 66, 20, -50, C.green)
end)

icon("Plus", "Plus", "Interface", function(d)
	d:bar(50, 50, 80, 24, 0, C.green)
	d:bar(50, 50, 80, 24, 90, C.green)
end)

icon("Minus", "Moins", "Interface", function(d)
	d:bar(50, 50, 80, 24, 0, C.red)
end)

icon("ArrowUp", "Flèche haut", "Interface", function(d)
	d:tri(50, 50, 84, "up", C.green, { r = 5 })
	d:box(32, 44, 36, 48, C.green, { r = 6 })
	d:shine(34, 32, 14, 6, -45)
end)

icon("ArrowRight", "Flèche droite", "Interface", function(d)
	d:tri(50, 50, 84, "right", C.blue, { r = 5 })
	d:box(8, 32, 48, 36, C.blue, { r = 6 })
end)

icon("ArrowLeft", "Flèche gauche", "Interface", function(d)
	d:tri(50, 50, 84, "left", C.blue, { r = 5 })
	d:box(44, 32, 48, 36, C.blue, { r = 6 })
end)

icon("Boost", "Boost", "Interface", function(d)
	d:tri(50, 46, 76, "up", C.green, { r = 5 })
	d:layer()
	d:tri(50, 88, 76, "up", C.green, { r = 5 })
end)

icon("Gear", "Paramètres", "Interface", function(d)
	for i = 0, 3 do
		d:bar(50, 50, 88, 18, i * 45, C.gray, { r = 4 })
	end
	d:circle(50, 50, 64, C.gray)
	d:circle(50, 50, 26, C.grayDark, { outline = false })
	d:shine(36, 34, 12, 6, -45)
end)

icon("Lock", "Cadenas", "Interface", function(d)
	d:box(26, 8, 12, 44, C.gray, { r = -1 })
	d:box(62, 8, 12, 44, C.gray, { r = -1 })
	d:box(26, 8, 48, 12, C.gray, { r = -1 })
	d:layer()
	d:box(16, 42, 68, 50, C.gold, { r = 10 })
	d:circle(50, 62, 14, C.dark, { outline = false })
	d:box(46, 64, 8, 16, C.dark, { r = 2, outline = false })
end)

icon("Home", "Accueil", "Interface", function(d)
	d:box(64, 14, 12, 26, C.redDark, { r = 2 })
	d:box(18, 44, 64, 48, C.cream, { r = 4 })
	d:tri(50, 50, 96, "up", C.red, { r = 5 })
	d:box(42, 62, 18, 30, C.brown, { r = 3, outline = false })
end)

icon("Person", "Profil", "Interface", function(d)
	d:box(14, 54, 72, 40, C.blue, { r = 30 })
	d:circle(50, 32, 40, C.cream)
	d:shine(40, 22, 10, 5, -45)
end)

icon("Pin", "Lieu", "Interface", function(d)
	d:tri(50, 54, 60, "down", C.red, { r = 4 })
	d:circle(50, 38, 66, C.red)
	d:circle(50, 38, 26, C.white, { outline = false })
end)

icon("Sword", "Épée", "Combat", function(d)
	d:bar(58, 42, 74, 18, -45, C.white, { r = 6 })
	d:bar(31, 69, 40, 13, 45, C.goldDark)
	d:bar(22, 78, 26, 12, -45, C.brown)
	d:circle(13, 87, 14, C.gold)
	d:bar(60, 40, 56, 5, -45, C.gray, { outline = false })
end)

icon("Shield", "Bouclier", "Combat", function(d)
	d:box(16, 8, 68, 52, C.blue, { r = 10 })
	d:tri(50, 52, 68, "down", C.blue, { r = 8 })
	d:box(44, 18, 12, 50, C.white, { r = 3, outline = false })
	d:box(28, 30, 44, 12, C.white, { r = 3, outline = false })
end)

icon("Lightning", "Énergie", "Combat", function(d)
	d:bar(50, 28, 54, 26, -61, C.gold, { r = 4 })
	d:box(24, 40, 52, 20, C.gold, { r = 4 })
	d:bar(52, 72, 54, 22, -61, C.goldDark, { r = 4 })
	d:shine(52, 22, 20, 6, -61)
end)

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local BY_ID: { [string]: IconDef } = {}
for _, def in DEFS do
	BY_ID[def.id] = def
end

Icons.list = DEFS

function Icons.get(id: string): IconDef?
	return BY_ID[id]
end

function Icons.categories(): { string }
	local seen, out = {}, {}
	for _, def in DEFS do
		if not seen[def.category] then
			seen[def.category] = true
			table.insert(out, def.category)
		end
	end
	return out
end

-- Draws icon `id` into `parent`, filling it. Returns the holder frame. Shapes get ZIndex
-- values from `zBase` up so they stack in the right order.
function Icons.build(id: string, parent: Instance?, zBase: number?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = zBase or 1
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = holder

	local def = BY_ID[id] or BY_ID.Coin
	local drawing = newDrawing()
	def.draw(drawing)
	local z = zBase or 1
	for _, shapes in drawing.layers do
		z = drawLayer(shapes, holder, z, { 0, 0, 100, 100 })
	end
	holder.Parent = parent
	return holder
end

return Icons
