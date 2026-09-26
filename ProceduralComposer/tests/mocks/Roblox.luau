--[[
	Mock minimal de l'API Roblox pour exécuter les modules du plugin avec la
	CLI `luau` (hors Studio). Fidèle aux conventions Roblox pour ce que le
	moteur utilise : Vector3, Vector2, CFrame (matrices, Angles XYZ,
	fromMatrix, lookAt, espaces objet/monde), Instances (hiérarchie, attributs,
	pivots, Clone, ScaleTo), services, task, Enum.
]]

local mockTypeName = {}

local function typeofMock(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt and mockTypeName[mt] then
			return mockTypeName[mt]
		end
	end
	return type(v)
end

-- Vector3 -----------------------------------------------------------------------------
local Vector3 = {}
local V3 = {}
mockTypeName[V3] = "Vector3"
local V3methods = {}

local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
Vector3.new = v3
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	end
	return V3methods[k]
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%.4f, %.4f, %.4f", a.X, a.Y, a.Z)
end
function V3methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3methods.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3methods.Lerp(a, b, t)
	return a + (b - a) * t
end
function V3methods.Min(a, b)
	return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function V3methods.Max(a, b)
	return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function V3methods.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function V3methods.FuzzyEq(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-5)
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)

-- Vector2 -------------------------------------------------------------------------------
local Vector2 = {}
local V2 = {}
mockTypeName[V2] = "Vector2"
local V2methods = {}
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
Vector2.new = v2
V2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return v2(v.X / m, v.Y / m)
	end
	return V2methods[k]
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a)
	return v2(-a.X, -a.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
function V2methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y
end
function V2methods.Lerp(a, b, t)
	return a + (b - a) * t
end

-- CFrame ----------------------------------------------------------------------------------
local CFrame = {}
local CF = {}
mockTypeName[CF] = "CFrame"
local CFmethods = {}

-- m = { r00, r01, r02, r10, r11, r12, r20, r21, r22 } (lignes), colonnes = axes X, Y, Z.
local function cf(px, py, pz, m)
	return setmetatable({ _p = v3(px, py, pz), _m = m or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end

function CFrame.new(a, b, c, ...)
	local extra = { ... }
	if a == nil then
		return cf(0, 0, 0)
	elseif type(a) == "number" then
		if #extra == 9 then
			return cf(a, b, c, extra)
		end
		return cf(a, b or 0, c or 0)
	elseif b ~= nil then
		return CFrame.lookAt(a, b)
	end
	return cf(a.X, a.Y, a.Z)
end

function CFrame.fromMatrix(pos, vX, vY, vZ)
	vZ = vZ or vX:Cross(vY).Unit
	return cf(pos.X, pos.Y, pos.Z, { vX.X, vY.X, vZ.X, vX.Y, vY.Y, vZ.Y, vX.Z, vY.Z, vZ.Z })
end

local function mulM(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end

function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local mx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local my = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local mz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(0, 0, 0, mulM(mulM(mx, my), mz))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles

function CFrame.lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at).Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(v3(0, 0, 1))
	end
	right = right.Unit
	local upv = right:Cross(look).Unit
	return CFrame.fromMatrix(at, right, upv, -look)
end

local function transformVector(m, v)
	return v3(
		m[1] * v.X + m[2] * v.Y + m[3] * v.Z,
		m[4] * v.X + m[5] * v.Y + m[6] * v.Z,
		m[7] * v.X + m[8] * v.Y + m[9] * v.Z
	)
end
local function transpose(m)
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end

CF.__index = function(c, k)
	local m = c._m
	if k == "Position" or k == "p" then
		return c._p
	elseif k == "X" then
		return c._p.X
	elseif k == "Y" then
		return c._p.Y
	elseif k == "Z" then
		return c._p.Z
	elseif k == "XVector" or k == "RightVector" then
		return v3(m[1], m[4], m[7])
	elseif k == "YVector" or k == "UpVector" then
		return v3(m[2], m[5], m[8])
	elseif k == "ZVector" then
		return v3(m[3], m[6], m[9])
	elseif k == "LookVector" then
		return v3(-m[3], -m[6], -m[9])
	elseif k == "Rotation" then
		return cf(0, 0, 0, m)
	end
	return CFmethods[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local p = a._p + transformVector(a._m, b._p)
		return cf(p.X, p.Y, p.Z, mulM(a._m, b._m))
	end
	return a._p + transformVector(a._m, b)
end
CF.__add = function(a, v)
	return cf(a._p.X + v.X, a._p.Y + v.Y, a._p.Z + v.Z, a._m)
end
CF.__sub = function(a, v)
	return cf(a._p.X - v.X, a._p.Y - v.Y, a._p.Z - v.Z, a._m)
end
CF.__tostring = function(a)
	return "CFrame(" .. tostring(a._p) .. ")"
end
function CFmethods.Inverse(c)
	local t = transpose(c._m)
	local p = -transformVector(t, c._p)
	return cf(p.X, p.Y, p.Z, t)
end
function CFmethods.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function CFmethods.ToWorldSpace(a, b)
	return a * b
end
function CFmethods.PointToObjectSpace(a, v)
	return transformVector(transpose(a._m), v - a._p)
end
function CFmethods.PointToWorldSpace(a, v)
	return a._p + transformVector(a._m, v)
end
function CFmethods.VectorToObjectSpace(a, v)
	return transformVector(transpose(a._m), v)
end
function CFmethods.VectorToWorldSpace(a, v)
	return transformVector(a._m, v)
end
function CFmethods.GetComponents(a)
	local m = a._m
	return a._p.X, a._p.Y, a._p.Z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
end

-- Color3 / UDim (usage limité) -------------------------------------------------------------
local Color3 = {}
local C3 = {}
mockTypeName[C3] = "Color3"
function Color3.new(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end

local UDim = {}
function UDim.new(scale, offset)
	return { Scale = scale or 0, Offset = offset or 0 }
end
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end

-- Enum -----------------------------------------------------------------------------------------
local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, category)
		local cat = enumCache[category]
		if not cat then
			cat = setmetatable({}, {
				__index = function(t, name)
					local item = { Name = name, EnumType = category }
					rawset(t, name, item)
					return item
				end,
			})
			enumCache[category] = cat
		end
		return cat
	end,
})

-- Signals ----------------------------------------------------------------------------------------
local function newSignal()
	local s = { _handlers = {} }
	function s:Connect(fn)
		table.insert(self._handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, h in ipairs(self._handlers) do
			h(...)
		end
	end
	return s
end

-- Instances ---------------------------------------------------------------------------------------
local CLASS_TREE = {
	Instance = {},
	PVInstance = { "Instance" },
	BasePart = { "PVInstance", "Instance" },
	Part = { "BasePart", "PVInstance", "Instance" },
	WedgePart = { "BasePart", "PVInstance", "Instance" },
	MeshPart = { "BasePart", "PVInstance", "Instance" },
	UnionOperation = { "BasePart", "PVInstance", "Instance" },
	Terrain = { "BasePart", "PVInstance", "Instance" },
	Model = { "PVInstance", "Instance" },
	Workspace = { "Model", "PVInstance", "Instance" },
	Folder = { "Instance" },
	Configuration = { "Instance" },
	Attachment = { "Instance" },
	ObjectValue = { "Instance" },
	Script = { "LuaSourceContainer", "Instance" },
	LocalScript = { "LuaSourceContainer", "Instance" },
	ModuleScript = { "LuaSourceContainer", "Instance" },
	SpecialMesh = { "DataModelMesh", "Instance" },
	DataModel = { "Instance" },
}

local AUTO_SIGNALS = {
	MouseEnter = true, MouseLeave = true, Activated = true, InputBegan = true, InputChanged = true,
	InputEnded = true, FocusLost = true, MouseButton1Up = true, MouseButton1Click = true, Changed = true,
}
local InstanceMT = {}
mockTypeName[InstanceMT] = "Instance"
local InstanceMethods = {}
local allInstances = setmetatable({}, { __mode = "k" })

local function isBasePart(inst)
	return inst:IsA("BasePart")
end

InstanceMT.__index = function(inst, k)
	local props = rawget(inst, "_props")
	if k == "Parent" then
		return rawget(inst, "_parent")
	elseif k == "Position" and props.CFrame then
		return props.CFrame.Position
	elseif k == "WorldCFrame" and inst.ClassName == "Attachment" then
		local parent = rawget(inst, "_parent")
		if parent and parent:IsA("BasePart") then
			return parent.CFrame * props.CFrame
		end
		return props.CFrame
	elseif k == "Position" and inst.ClassName == "Attachment" then
		return props.CFrame.Position
	end
	local v = props[k]
	if v ~= nil then
		return v
	end
	local m = InstanceMethods[k]
	if m then
		return m
	end
	if AUTO_SIGNALS[k] then
		local sig = newSignal()
		props[k] = sig
		return sig
	end
	local children = rawget(inst, "_children")
	for _, c in ipairs(children) do
		if c.Name == k then
			return c
		end
	end
	return nil
end

InstanceMT.__newindex = function(inst, k, v)
	local props = rawget(inst, "_props")
	if k == "Parent" then
		local old = rawget(inst, "_parent")
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, inst)
			if i then
				table.remove(list, i)
			end
		end
		rawset(inst, "_parent", v)
		if v then
			table.insert(rawget(v, "_children"), inst)
		end
		return
	elseif k == "Position" and props.CFrame then
		props.CFrame = CFrame.new(v) * props.CFrame.Rotation
		return
	end
	props[k] = v
end

InstanceMT.__tostring = function(inst)
	return inst.Name
end

local Instance = {}
function Instance.new(className, parent)
	local inst = setmetatable({ _props = {}, _children = {}, _parent = nil, _attributes = {}, _tags = {} }, InstanceMT)
	local props = rawget(inst, "_props")
	props.ClassName = className
	props.Name = className
	props.Archivable = true
	if CLASS_TREE[className] and table.find(CLASS_TREE[className], "BasePart") then
		props.CFrame = CFrame.new()
		props.Size = v3(4, 1, 2)
		props.Transparency = 0
		props.Anchored = false
		props.CanCollide = true
		props.PivotOffset = CFrame.new()
		props.Shape = Enum.PartType.Block
	elseif className == "Attachment" then
		props.CFrame = CFrame.new()
	elseif className == "SpecialMesh" then
		props.Scale = v3(1, 1, 1)
		props.Offset = v3(0, 0, 0)
		props.MeshType = Enum.MeshType.FileMesh
	elseif className == "Model" then
		props._scale = 1
	elseif className == "Frame" or className == "TextButton" or className == "TextLabel" or className == "TextBox" or className == "ScrollingFrame" then
		props.AbsolutePosition = Vector2.new(0, 0)
		props.AbsoluteSize = Vector2.new(360, 24)
		props.Visible = true
		props.Text = ""
	end
	allInstances[inst] = true
	if parent then
		inst.Parent = parent
	end
	return inst
end

function InstanceMethods.IsA(inst, className)
	if inst.ClassName == className then
		return true
	end
	local tree = CLASS_TREE[inst.ClassName]
	return tree ~= nil and table.find(tree, className) ~= nil
end
function InstanceMethods.GetChildren(inst)
	return table.clone(rawget(inst, "_children"))
end
function InstanceMethods.GetDescendants(inst)
	local out = {}
	local function walk(i)
		for _, c in ipairs(rawget(i, "_children")) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(inst)
	return out
end
function InstanceMethods.FindFirstChild(inst, name)
	for _, c in ipairs(rawget(inst, "_children")) do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function InstanceMethods.FindFirstChildWhichIsA(inst, className)
	for _, c in ipairs(rawget(inst, "_children")) do
		if c:IsA(className) then
			return c
		end
	end
	return nil
end
function InstanceMethods.IsDescendantOf(inst, ancestor)
	local p = rawget(inst, "_parent")
	while p do
		if p == ancestor then
			return true
		end
		p = rawget(p, "_parent")
	end
	return false
end
function InstanceMethods.GetFullName(inst)
	local names = { inst.Name }
	local p = rawget(inst, "_parent")
	while p and p.ClassName ~= "DataModel" do
		table.insert(names, 1, p.Name)
		p = rawget(p, "_parent")
	end
	return table.concat(names, ".")
end
function InstanceMethods.GetAttribute(inst, name)
	return rawget(inst, "_attributes")[name]
end
function InstanceMethods.SetAttribute(inst, name, value)
	rawget(inst, "_attributes")[name] = value
end
function InstanceMethods.GetAttributes(inst)
	return table.clone(rawget(inst, "_attributes"))
end
function InstanceMethods.Destroy(inst)
	inst.Parent = nil
	for _, c in ipairs(inst:GetChildren()) do
		c:Destroy()
	end
end
function InstanceMethods.ClearAllChildren(inst)
	for _, c in ipairs(inst:GetChildren()) do
		c:Destroy()
	end
end
function InstanceMethods.GetPropertyChangedSignal()
	return newSignal()
end

local function bboxOf(inst)
	local lo = v3(math.huge, math.huge, math.huge)
	local hi = v3(-math.huge, -math.huge, -math.huge)
	local parts = {}
	if isBasePart(inst) then
		table.insert(parts, inst)
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if isBasePart(d) then
			table.insert(parts, d)
		end
	end
	for _, p in ipairs(parts) do
		local h = p.Size * 0.5
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local c = p.CFrame * v3(h.X * sx, h.Y * sy, h.Z * sz)
					lo = lo:Min(c)
					hi = hi:Max(c)
				end
			end
		end
	end
	return lo, hi, #parts
end

function InstanceMethods.GetPivot(inst)
	if inst:IsA("BasePart") then
		return inst.CFrame * inst.PivotOffset
	end
	local props = rawget(inst, "_props")
	if props.PrimaryPart then
		return props.PrimaryPart.CFrame * props.PrimaryPart.PivotOffset
	end
	if props.WorldPivot then
		return props.WorldPivot
	end
	local lo, hi, n = bboxOf(inst)
	if n == 0 then
		return CFrame.new()
	end
	return CFrame.new((lo + hi) * 0.5)
end

function InstanceMethods.PivotTo(inst, target)
	local current = inst:GetPivot()
	local delta = target * current:Inverse()
	if inst:IsA("BasePart") then
		inst.CFrame = delta * inst.CFrame
		for _, d in ipairs(inst:GetDescendants()) do
			if isBasePart(d) then
				d.CFrame = delta * d.CFrame
			end
		end
		return
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if isBasePart(d) then
			d.CFrame = delta * d.CFrame
		end
	end
	local props = rawget(inst, "_props")
	if props.WorldPivot and not props.PrimaryPart then
		props.WorldPivot = target
	end
end

function InstanceMethods.GetScale(inst)
	return rawget(inst, "_props")._scale or 1
end

function InstanceMethods.ScaleTo(inst, newScale)
	local props = rawget(inst, "_props")
	local factor = newScale / (props._scale or 1)
	local pivot = inst:GetPivot()
	for _, d in ipairs(inst:GetDescendants()) do
		if isBasePart(d) then
			local rel = pivot:ToObjectSpace(d.CFrame)
			d.Size = d.Size * factor
			d.CFrame = pivot * (CFrame.new(rel.Position * factor) * rel.Rotation)
		elseif d.ClassName == "Attachment" then
			d.Position = d.Position * factor
		end
	end
	props._scale = newScale
end

function InstanceMethods.GetBoundingBox(inst)
	local lo, hi = bboxOf(inst)
	return CFrame.new((lo + hi) * 0.5), hi - lo
end

function InstanceMethods.Clone(inst)
	if not inst.Archivable then
		return nil
	end
	local map = {}
	local function copy(src)
		local c = Instance.new(src.ClassName)
		map[src] = c
		for k, v in pairs(rawget(src, "_props")) do
			rawget(c, "_props")[k] = v
		end
		for k, v in pairs(rawget(src, "_attributes")) do
			rawget(c, "_attributes")[k] = v
		end
		for k, v in pairs(rawget(src, "_tags")) do
			rawget(c, "_tags")[k] = v
		end
		for _, child in ipairs(rawget(src, "_children")) do
			local cc = copy(child)
			cc.Parent = c
		end
		return c
	end
	local root = copy(inst)
	-- Références internes (PrimaryPart) remappées.
	for src, dst in pairs(map) do
		local pp = rawget(src, "_props").PrimaryPart
		if pp and map[pp] then
			rawget(dst, "_props").PrimaryPart = map[pp]
		end
	end
	return root
end

-- DataModel / services ---------------------------------------------------------------------------
local game = Instance.new("DataModel")
game.Name = "Game"
local workspace = Instance.new("Workspace", game)
workspace.Name = "Workspace"
local terrain = Instance.new("Terrain", workspace)
terrain.Name = "Terrain"
rawget(workspace, "_props").Terrain = terrain
rawget(workspace, "_props").CurrentCamera = nil

local function obbIntersectsMock(cfA, sizeA, cfB, sizeB)
	local hA, hB = sizeA * 0.5, sizeB * 0.5
	local A = { cfA.XVector, cfA.YVector, cfA.ZVector }
	local B = { cfB.XVector, cfB.YVector, cfB.ZVector }
	local d = cfB.Position - cfA.Position
	local function sep(axis)
		local len = axis.Magnitude
		if len < 1e-6 then
			return false
		end
		local n = axis / len
		local ra = math.abs(n:Dot(A[1])) * hA.X + math.abs(n:Dot(A[2])) * hA.Y + math.abs(n:Dot(A[3])) * hA.Z
		local rb = math.abs(n:Dot(B[1])) * hB.X + math.abs(n:Dot(B[2])) * hB.Y + math.abs(n:Dot(B[3])) * hB.Z
		return math.abs(d:Dot(n)) >= ra + rb
	end
	for i = 1, 3 do
		if sep(A[i]) or sep(B[i]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if sep(A[i]:Cross(B[j])) then
				return false
			end
		end
	end
	return true
end

rawget(workspace, "_props").GetPartBoundsInBox = function(self, boxCf, size, params)
	local out = {}
	local exclude = (params and params.FilterDescendantsInstances) or {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.ClassName ~= "Terrain" then
			local skip = false
			for _, ex in ipairs(exclude) do
				if d == ex or d:IsDescendantOf(ex) then
					skip = true
					break
				end
			end
			if not skip and obbIntersectsMock(boxCf, size, d.CFrame, d.Size) then
				table.insert(out, d)
			end
		end
	end
	return out
end
rawget(workspace, "_props").Raycast = function()
	return nil
end

local recordingLog = {}
local lastWaypoint = nil
local services = {
	Workspace = workspace,
	CollectionService = {
		HasTag = function(_, inst, tag)
			return rawget(inst, "_tags")[tag] == true
		end,
		GetTags = function(_, inst)
			local out = {}
			for t in pairs(rawget(inst, "_tags")) do
				table.insert(out, t)
			end
			table.sort(out)
			return out
		end,
		GetTagged = function(_, tag)
			local out = {}
			for _, d in ipairs(game:GetDescendants()) do
				if rawget(d, "_tags")[tag] then
					table.insert(out, d)
				end
			end
			return out
		end,
		AddTag = function(_, inst, tag)
			rawget(inst, "_tags")[tag] = true
		end,
	},
	Selection = {
		_sel = {},
		Get = function(self)
			return table.clone(self._sel)
		end,
		Set = function(self, list)
			self._sel = list
		end,
	},
	ChangeHistoryService = {
		OnUndo = newSignal(),
		OnRedo = newSignal(),
		TryBeginRecording = function(_, name)
			table.insert(recordingLog, { Op = "Begin", Name = name })
			return "rec_" .. #recordingLog
		end,
		FinishRecording = function(_, id, op)
			table.insert(recordingLog, { Op = "Finish", Id = id, Mode = op.Name })
			-- Le nom du dernier waypoint est celui du premier enregistrement non fusionné.
			if op.Name == "Commit" then
				for i = #recordingLog, 1, -1 do
					if recordingLog[i].Op == "Begin" then
						lastWaypoint = recordingLog[i].Name
						break
					end
				end
			end
		end,
		GetCanUndo = function()
			return lastWaypoint ~= nil, lastWaypoint
		end,
	},
	HttpService = {
		_n = 0,
		GenerateGUID = function(self)
			self._n += 1
			return "GUID-" .. self._n
		end,
		JSONEncode = function()
			return "{}"
		end,
	},
	RunService = {
		IsEdit = function()
			return true
		end,
	},
}
rawget(game, "_props").GetService = function(_, name)
	local s = services[name]
	if not s then
		error("Mock service not implemented: " .. tostring(name))
	end
	return s
end

local task = {
	wait = function()
		return 0
	end,
	spawn = function(fn, ...)
		fn(...)
	end,
	defer = function(fn, ...)
		fn(...)
	end,
	delay = function() end,
}

local Random = {}
function Random.new(seed)
	local r = { _state = seed or 12345 }
	function r:NextInteger(a, b)
		self._state = (self._state * 1103515245 + 12345) % 2147483648
		return a + self._state % (b - a + 1)
	end
	function r:NextNumber()
		self._state = (self._state * 1103515245 + 12345) % 2147483648
		return self._state / 2147483648
	end
	return r
end

local OverlapParams = {
	new = function()
		return { FilterDescendantsInstances = {}, FilterType = nil }
	end,
}
local RaycastParams = OverlapParams

return {
	typeof = typeofMock,
	UDim = UDim,
	UDim2 = UDim2,
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = CFrame,
	Color3 = Color3,
	Enum = Enum,
	Instance = Instance,
	game = game,
	workspace = workspace,
	task = task,
	Random = Random,
	OverlapParams = OverlapParams,
	RaycastParams = RaycastParams,
	services = services,
	recordingLog = recordingLog,
	resetHistory = function()
		table.clear(recordingLog)
		lastWaypoint = nil
	end,
}
