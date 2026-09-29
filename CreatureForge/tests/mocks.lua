-- Mocks minimalistes des types Roblox pour tester la logique pure hors Studio.
-- (Vector3, Vector2, CFrame, Color3, Random, Enum, typeof, task, Instance simplifié)

local mt3 = {}
mt3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return v
		end
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return mt3[k]
end
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __type = "Vector3" }, mt3)
end
mt3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
mt3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
mt3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
mt3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
mt3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
mt3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
mt3.__tostring = function(a)
	return string.format("%.3f, %.3f, %.3f", a.X, a.Y, a.Z)
end
function mt3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function mt3.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function mt3.Lerp(a, b, t)
	return a + (b - a) * t
end
function mt3.Min(a, b)
	return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function mt3.Max(a, b)
	return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function mt3.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function mt3.FuzzyEq(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-5)
end

Vector3 = {
	new = v3,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}

local mt2 = {}
mt2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return Vector2.new(v.X / m, v.Y / m)
	end
	return mt2[k]
end
local function v2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0, __type = "Vector2" }, mt2)
end
mt2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
mt2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
mt2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(b.X * a, b.Y * a)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
mt2.__div = function(a, b)
	return v2(a.X / b, a.Y / b)
end
function mt2.Lerp(a, b, t)
	return a + (b - a) * t
end
function mt2.Dot(a, b)
	return a.X * b.X + a.Y * b.Y
end
Vector2 = { new = v2, zero = v2(0, 0) }

-- CFrame : position p + matrice 3x3 (colonnes = axes X, Y, Z)
local mtc = {}
local function cf(p, r)
	return setmetatable({ p = p, r = r, __type = "CFrame" }, mtc)
end
local function ident()
	return { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
end
local function mulR(a, b)
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
local function rotV(r, v)
	return v3(
		r[1] * v.X + r[2] * v.Y + r[3] * v.Z,
		r[4] * v.X + r[5] * v.Y + r[6] * v.Z,
		r[7] * v.X + r[8] * v.Y + r[9] * v.Z
	)
end
local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
mtc.__index = function(c, k)
	local r = c.r
	if k == "Position" then
		return c.p
	elseif k == "RightVector" or k == "XVector" then
		return v3(r[1], r[4], r[7])
	elseif k == "UpVector" or k == "YVector" then
		return v3(r[2], r[5], r[8])
	elseif k == "LookVector" then
		return v3(-r[3], -r[6], -r[9])
	elseif k == "ZVector" then
		return v3(r[3], r[6], r[9])
	elseif k == "Rotation" then
		return cf(Vector3.zero, r)
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	end
	return mtc[k]
end
mtc.__mul = function(a, b)
	if b.__type == "CFrame" then
		return cf(a.p + rotV(a.r, b.p), mulR(a.r, b.r))
	end
	return a.p + rotV(a.r, b)
end
mtc.__add = function(a, v)
	return cf(a.p + v, a.r)
end
mtc.__sub = function(a, v)
	return cf(a.p - v, a.r)
end
function mtc.Inverse(c)
	local rt = transpose(c.r)
	return cf(-rotV(rt, c.p), rt)
end
function mtc.PointToWorldSpace(c, v)
	return c * v
end
function mtc.PointToObjectSpace(c, v)
	return rotV(transpose(c.r), v - c.p)
end
function mtc.VectorToWorldSpace(c, v)
	return rotV(c.r, v)
end
function mtc.VectorToObjectSpace(c, v)
	return rotV(transpose(c.r), v)
end
function mtc.ToObjectSpace(c, o)
	return c:Inverse() * o
end
function mtc.ToWorldSpace(c, o)
	return c * o
end
function mtc.GetComponents(c)
	local r = c.r
	return c.p.X, c.p.Y, c.p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end
function mtc.Lerp(a, b, t)
	return cf(a.p:Lerp(b.p, t), a.r)
end
function mtc.ToEulerAnglesXYZ(c)
	return 0, 0, 0
end

local function angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local RX = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local RY = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local RZ = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(Vector3.zero, mulR(mulR(RX, RY), RZ))
end

CFrame = {
	new = function(x, y, z, ...)
		if x == nil then
			return cf(Vector3.zero, ident())
		end
		if type(x) == "table" then
			if y then -- CFrame.new(pos, lookAt)
				local look = (y - x).Unit
				local right = look:Cross(Vector3.yAxis).Unit
				local up = right:Cross(look)
				local b = -look
				return cf(x, { right.X, up.X, b.X, right.Y, up.Y, b.Y, right.Z, up.Z, b.Z })
			end
			return cf(x, ident())
		end
		local extra = { ... }
		if #extra == 9 then
			return cf(v3(x, y, z), extra)
		end
		return cf(v3(x, y, z), ident())
	end,
	Angles = angles,
	fromEulerAnglesXYZ = angles,
	fromMatrix = function(pos, vx, vy, vz)
		vz = vz or vx:Cross(vy)
		return cf(pos, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
	end,
	lookAt = function(at, target, up)
		return CFrame.new(at, target)
	end,
	identity = cf(Vector3.zero, ident()),
}

-- Color3
local mtcol = {}
mtcol.__index = mtcol
local function col(r, g, b)
	return setmetatable({ R = r, G = g, B = b, __type = "Color3" }, mtcol)
end
function mtcol.Lerp(a, b, t)
	return col(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function mtcol.ToHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, (mx == 0) and 0 or d / mx, mx
end
function mtcol.ToHex(c)
	return string.format("%02X%02X%02X", c.R * 255 + 0.5, c.G * 255 + 0.5, c.B * 255 + 0.5)
end
mtcol.__tostring = function(c)
	return string.format("%.3f, %.3f, %.3f", c.R, c.G, c.B)
end
mtcol.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3 = {
	new = col,
	fromRGB = function(r, g, b)
		return col(r / 255, g / 255, b / 255)
	end,
	fromHSV = function(h, s, v)
		h = (h % 1) * 6
		local i = math.floor(h)
		local f = h - i
		local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
		local rgb = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i % 6 + 1]
		return col(rgb[1], rgb[2], rgb[3])
	end,
}

-- Random déterministe (LCG)
local mtr = {}
mtr.__index = mtr
function mtr.NextNumber(r, a, b)
	r.s = (r.s * 1103515245 + 12345) % 2147483648
	local u = r.s / 2147483648
	if a == nil then
		return u
	end
	return a + (b - a) * u
end
function mtr.NextInteger(r, a, b)
	return math.floor(r:NextNumber(a, b + 1 - 1e-9))
end
Random = {
	new = function(seed)
		return setmetatable({ s = math.floor(math.abs(seed or 1)) % 2147483648 + 1 }, mtr)
	end,
}

-- Enum : tout accès renvoie un pseudo-EnumItem.
local enumCache = {}
local function enumItem(path)
	if enumCache[path] then
		return enumCache[path]
	end
	local item
	item = setmetatable({ Name = path:match("[^%.]+$"), __path = path }, {
		__index = function(t, k)
			return enumItem(path .. "." .. k)
		end,
		__tostring = function()
			return "Enum." .. path
		end,
		__eq = function(a, b)
			return a.__path == b.__path
		end,
	})
	enumCache[path] = item
	return item
end
Enum = setmetatable({}, {
	__index = function(_, k)
		return enumItem(k)
	end,
})

function typeof(v)
	if type(v) == "table" and v.__type then
		return v.__type
	end
	if type(v) == "table" and v.ClassName then
		return "Instance"
	end
	return type(v)
end

task = {
	wait = function()
		return 0
	end,
	spawn = function(f, ...)
		f(...)
	end,
	defer = function(f, ...)
		f(...)
	end,
}

---------------------------------------------------------------------
-- Instance simplifiée (suffisante pour l'analyse et les modules Studio)
---------------------------------------------------------------------
local ISA = {
	Part = { "Part", "BasePart", "PVInstance", "Instance" },
	MeshPart = { "MeshPart", "BasePart", "PVInstance", "Instance" },
	Model = { "Model", "PVInstance", "Instance" },
	Motor6D = { "Motor6D", "JointInstance", "Instance" },
	Weld = { "Weld", "JointInstance", "Instance" },
	Bone = { "Bone", "Attachment", "Instance" },
	Color3Value = { "Color3Value", "ValueBase", "Instance" },
	MaterialVariant = { "MaterialVariant", "Instance" },
}

local function signal()
	local conns = {}
	return {
		Connect = function(_, fn)
			local c = { fn = fn }
			table.insert(conns, c)
			return {
				Disconnect = function()
					c.fn = nil
				end,
			}
		end,
		Fire = function(_, ...)
			for _, c in conns do
				if c.fn then
					c.fn(...)
				end
			end
		end,
	}
end

local instMt = {}
local methods = {}
instMt.__index = function(t, k)
	if methods[k] then
		return methods[k]
	end
	local props = rawget(t, "_props")
	if k == "Parent" then
		return rawget(t, "_parent")
	elseif k == "Position" and props.CFrame then
		return props.CFrame.Position
	elseif k == "Changed" or k == "AncestryChanged" or k == "MouseEnter" or k == "MouseLeave" or k == "Activated"
		or k == "InputBegan" or k == "InputChanged" or k == "InputEnded" or k == "FocusLost" then
		local sig = props["_sig_" .. k]
		if not sig then
			sig = signal()
			props["_sig_" .. k] = sig
		end
		return sig
	end
	local v = props[k]
	if v == nil then
		local defaults = { Transparency = 0, MaterialVariant = "", MeshId = "", TextureID = "", Anchored = false }
		v = defaults[k]
	end
	if v == nil then
		for _, child in rawget(t, "_children") do
			if child.Name == k then
				return child
			end
		end
	end
	return v
end
instMt.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_parent")
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, t)
			if i then
				table.remove(list, i)
			end
		end
		rawset(t, "_parent", v)
		if v then
			table.insert(rawget(v, "_children"), t)
		end
		return
	end
	local props = rawget(t, "_props")
	local old = props[k]
	props[k] = v
	if k == "Value" and old ~= v then
		t.Changed:Fire(v)
	end
end
function methods.IsA(self, cls)
	for _, c in ISA[self.ClassName] or { self.ClassName, "Instance" } do
		if c == cls then
			return true
		end
	end
	return false
end
function methods.GetChildren(self)
	return table.clone(rawget(self, "_children"))
end
function methods.GetDescendants(self)
	local out = {}
	local function rec(i)
		for _, c in rawget(i, "_children") do
			out[#out + 1] = c
			rec(c)
		end
	end
	rec(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "_children") do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "_children") do
			local r = c:FindFirstChild(name, true)
			if r then
				return r
			end
		end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(self, cls)
	for _, c in rawget(self, "_children") do
		if c:IsA(cls) then
			return c
		end
	end
	return nil
end
function methods.FindFirstAncestorWhichIsA(self, cls)
	local p = self.Parent
	while p do
		if p:IsA(cls) then
			return p
		end
		p = p.Parent
	end
	return nil
end
function methods.IsDescendantOf(self, other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods.GetAttribute(self, k)
	return rawget(self, "_attrs")[k]
end
function methods.SetAttribute(self, k, v)
	rawget(self, "_attrs")[k] = v
end
function methods.GetFullName(self)
	return self.Name
end
function methods.Destroy(self)
	self.Parent = nil
	self.AncestryChanged:Fire(self, nil)
end
function methods.GetPivot(self)
	if self:IsA("BasePart") then
		return self.CFrame
	end
	local pp = self.PrimaryPart
	if pp then
		return pp.CFrame * (pp.PivotOffset or CFrame.new())
	end
	return self.WorldPivot or self._pivot or CFrame.new()
end
function methods.GetBoundingBox(self)
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") and d.CFrame then
			local p = d.CFrame.Position
			mn = mn:Min(p - d.Size * 0.5)
			mx = mx:Max(p + d.Size * 0.5)
		end
	end
	if mn.X == math.huge then
		return self:GetPivot(), Vector3.one
	end
	return CFrame.new((mn + mx) * 0.5), mx - mn
end
function methods.ApplyMesh(self, other)
	self.MeshId = other.MeshId
	self.MeshContent = other.MeshContent
end
function methods.GetPropertyChangedSignal(self)
	return signal()
end

function MockInstance(className, props, parent)
	local inst = setmetatable({ _props = { ClassName = className, Name = className }, _children = {}, _attrs = {} }, instMt)
	for k, v in props or {} do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

Instance = {
	new = function(className)
		return MockInstance(className)
	end,
}

workspace = MockInstance("Workspace", { Name = "Workspace" })

Content = {
	fromObject = function(o)
		return { SourceType = Enum.ContentSourceType.Object, Object = o }
	end,
	fromAssetId = function(id)
		return { SourceType = Enum.ContentSourceType.Uri, Uri = "rbxassetid://" .. tostring(id) }
	end,
}

DateTime = {
	now = function()
		return { UnixTimestampMillis = os.clock() * 1000 }
	end,
}

-- Mini décodeur JSON (pour MeshRegistry.ensureForPart)
local function jsonDecode(str)
	local pos = 1
	local function ws()
		pos = string.find(str, "[^%s]", pos) or #str + 1
	end
	local value
	local function parseString()
		local out = {}
		pos += 1
		while true do
			local c = string.sub(str, pos, pos)
			if c == '"' then
				pos += 1
				break
			elseif c == "\\" then
				local n = string.sub(str, pos + 1, pos + 1)
				out[#out + 1] = ({ n = "\n", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" })[n] or n
				pos += 2
			else
				out[#out + 1] = c
				pos += 1
			end
		end
		return table.concat(out)
	end
	function value()
		ws()
		local c = string.sub(str, pos, pos)
		if c == "{" then
			local t = {}
			pos += 1
			ws()
			if string.sub(str, pos, pos) == "}" then
				pos += 1
				return t
			end
			while true do
				ws()
				local k = parseString()
				ws()
				pos += 1 -- :
				t[k] = value()
				ws()
				local sep = string.sub(str, pos, pos)
				pos += 1
				if sep == "}" then
					return t
				end
			end
		elseif c == "[" then
			local t = {}
			pos += 1
			ws()
			if string.sub(str, pos, pos) == "]" then
				pos += 1
				return t
			end
			while true do
				t[#t + 1] = value()
				ws()
				local sep = string.sub(str, pos, pos)
				pos += 1
				if sep == "]" then
					return t
				end
			end
		elseif c == '"' then
			return parseString()
		elseif string.sub(str, pos, pos + 3) == "true" then
			pos += 4
			return true
		elseif string.sub(str, pos, pos + 4) == "false" then
			pos += 5
			return false
		elseif string.sub(str, pos, pos + 3) == "null" then
			pos += 4
			return nil
		else
			local num = string.match(str, "^-?[%d%.eE+-]+", pos)
			pos += #num
			return tonumber(num)
		end
	end
	return value()
end
JSON_DECODE = jsonDecode

-- Services minimalistes
local function jsonEncode(v)
	local t = type(v)
	if t == "table" then
		if #v > 0 then
			local out = {}
			for _, x in v do
				out[#out + 1] = jsonEncode(x)
			end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local keys = {}
		for k in v do
			keys[#keys + 1] = tostring(k)
		end
		table.sort(keys)
		local out = {}
		for _, k in keys do
			out[#out + 1] = string.format("%q", k) .. ":" .. jsonEncode(v[k])
		end
		return "{" .. table.concat(out, ",") .. "}"
	elseif t == "string" then
		return string.format("%q", v)
	elseif t == "number" then
		return string.format("%.17g", v)
	end
	return tostring(v)
end
local services = {
	HttpService = {
		JSONEncode = function(_, v)
			return jsonEncode(v)
		end,
		JSONDecode = function(_, str)
			return jsonDecode(str)
		end,
	},
	AssetService = {
		_uploads = 0,
		_meshes = 0,
		CreateEditableMesh = function(self)
			self._meshes += 1
			local em = { verts = 0, faces = 0, normals = 0, uvs = 0 }
			function em:AddVertex(p)
				self.verts += 1
				return self.verts
			end
			function em:AddTriangle(a, b, c)
				assert(a and b and c, "AddTriangle nil")
				self.faces += 1
				return self.faces
			end
			function em:AddNormal(n)
				self.normals += 1
				return self.normals
			end
			function em:AddUV(uv)
				assert(uv.X == uv.X, "UV NaN")
				self.uvs += 1
				return self.uvs
			end
			function em:SetFaceNormals(f, ids)
				assert(#ids == 3)
			end
			function em:SetFaceUVs(f, ids)
				assert(#ids == 3)
			end
			function em:RemoveUnused() end
			return em
		end,
		CreateMeshPartAsync = function(_, content, opts)
			local mp = MockInstance("MeshPart", { Size = Vector3.one, MeshContent = content })
			mp.MeshId = content.Uri or ""
			return mp
		end,
		CreateAssetAsync = function(self, obj, assetType, params)
			assert(obj.faces and obj.faces > 0, "upload d'un objet qui n'est pas un EditableMesh généré")
			self._uploads += 1
			if FAIL_UPLOADS and self._uploads <= FAIL_UPLOADS then
				error("HTTP 429 (Too Many Requests)")
			end
			if FAIL_PERMISSION then
				return Enum.CreateAssetResult.PermissionDenied, "User is not authorized"
			end
			return Enum.CreateAssetResult.Success, 900000 + self._uploads
		end,
	},
	ChangeHistoryService = {
		_recordings = 0,
		TryBeginRecording = function(self, name, display)
			if self._open then
				return nil
			end
			self._open = true
			self._recordings += 1
			return "rec" .. self._recordings
		end,
		FinishRecording = function(self, id, op)
			self._open = false
		end,
		SetWaypoint = function() end,
	},
	MaterialService = MockInstance("MaterialService"),
	Selection = {
		_sel = {},
		Set = function(self, list)
			self._sel = list
		end,
		Get = function(self)
			return self._sel
		end,
	},
}
MockInstance("MaterialVariant", { Name = "Studs", BaseMaterial = Enum.Material.Plastic }, services.MaterialService)
game = {
	GetService = function(_, name)
		return services[name] or {}
	end,
}
warn = function(...) print("WARN", ...) end
local function ctor(kind)
	return function(...)
		return { __type = kind, args = { ... } }
	end
end
UDim = { new = ctor("UDim") }
UDim2 = { new = ctor("UDim2"), fromOffset = ctor("UDim2"), fromScale = ctor("UDim2") }
ColorSequence = { new = ctor("ColorSequence") }
NumberSequence = { new = ctor("NumberSequence") }

DockWidgetPluginGuiInfo = { new = ctor("DockWidgetPluginGuiInfo") }
function methods.IsFocused()
	return false
end
