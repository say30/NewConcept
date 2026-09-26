--[[
	DebugVisualizer
	Visualisation de debug par HandleAdornments placés dans CoreGui :
	rien n'est ajouté à la place, rien n'entre dans l'historique d'annulation.

	Affiche (selon les réglages Debug*) :
	  - normales et contours des surfaces analysées ;
	  - boîtes englobantes des objets générés (architecture en orange) ;
	  - zones d'exclusion (rouge) et zone centrale protégée (jaune) ;
	  - points candidats (vert) et rejetés (rouge) ;
	  - points de snap (cyan) ;
	  - segmentation murale (magenta) et coins (orange).
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)

local DebugVisualizer = {}
DebugVisualizer.__index = DebugVisualizer

local D = Config.Debug
local MAX_BOXES = 1500

function DebugVisualizer.new()
	return setmetatable({ _folder = nil }, DebugVisualizer)
end

function DebugVisualizer:_getFolder()
	if self._folder and self._folder.Parent then
		return self._folder
	end
	local folder = Instance.new("Folder")
	folder.Name = D.FOLDER_NAME
	folder.Archivable = false
	local ok = pcall(function()
		folder.Parent = game:GetService("CoreGui")
	end)
	if not ok then
		folder.Parent = workspace.CurrentCamera
	end
	self._folder = folder
	return folder
end

function DebugVisualizer:clear()
	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
end

local function adornee()
	return workspace.Terrain
end

function DebugVisualizer:box(cf, size, color, transparency)
	local b = Instance.new("BoxHandleAdornment")
	b.Adornee = adornee()
	b.CFrame = cf
	b.Size = size
	b.Color3 = color
	b.Transparency = transparency or D.BOX_TRANSPARENCY
	b.AlwaysOnTop = false
	b.ZIndex = 1
	b.Parent = self:_getFolder()
	return b
end

function DebugVisualizer:point(position, color, radius)
	local s = Instance.new("SphereHandleAdornment")
	s.Adornee = adornee()
	s.CFrame = CFrame.new(position)
	s.Radius = radius or D.POINT_RADIUS
	s.Color3 = color
	s.Transparency = 0.15
	s.AlwaysOnTop = true
	s.ZIndex = 2
	s.Parent = self:_getFolder()
	return s
end

function DebugVisualizer:line(a, b, color, thickness)
	local length = (b - a).Magnitude
	if length < 1e-4 then
		return nil
	end
	local l = Instance.new("LineHandleAdornment")
	l.Adornee = adornee()
	l.CFrame = CFrame.lookAt(a, b)
	l.Length = length
	l.Thickness = thickness or D.LINE_THICKNESS
	l.Color3 = color
	l.AlwaysOnTop = true
	l.ZIndex = 2
	l.Parent = self:_getFolder()
	return l
end

function DebugVisualizer:arrow(origin, direction, length, color)
	local tip = origin + direction * length
	self:line(origin, tip, color, D.LINE_THICKNESS)
	local cone = Instance.new("ConeHandleAdornment")
	cone.Adornee = adornee()
	cone.CFrame = CFrame.lookAt(tip, tip + direction)
	cone.Height = length * 0.18
	cone.Radius = length * 0.07
	cone.Color3 = color
	cone.AlwaysOnTop = true
	cone.ZIndex = 2
	cone.Parent = self:_getFolder()
end

-- Polygone 2D d'une surface dessiné légèrement au-dessus du plan.
function DebugVisualizer:polygon(surface, poly, color, lift)
	lift = lift or 0.08
	for i = 1, #poly do
		local p = poly[i]
		local q = poly[(i % #poly) + 1]
		local a = surface.Frame:PointToWorldSpace(Vector3.new(p.X, lift, p.Y))
		local b = surface.Frame:PointToWorldSpace(Vector3.new(q.X, lift, q.Y))
		self:line(a, b, color, D.LINE_THICKNESS)
	end
end

function DebugVisualizer:drawAnalysis(analysis, settings)
	self:clear()
	if not settings.DebugEnabled then
		return
	end
	if settings.DebugNormals then
		for _, s in ipairs(analysis.Surfaces) do
			local center = s.Frame:PointToWorldSpace(Vector3.new((s.UMin + s.UMax) * 0.5, 0.05, (s.VMin + s.VMax) * 0.5))
			self:arrow(center, s.Normal, D.NORMAL_LENGTH, D.Colors.Normal)
			self:polygon(s, {
				Vector2.new(s.UMin, s.VMin), Vector2.new(s.UMax, s.VMin),
				Vector2.new(s.UMax, s.VMax), Vector2.new(s.UMin, s.VMax),
			}, D.Colors.Surface, 0.05)
		end
		for _, c in ipairs(analysis.Corners) do
			self:point(c.Position, D.Colors.Corner, D.POINT_RADIUS * 2)
			self:line(c.Position, c.Position + Vector3.new(0, c.Height, 0), D.Colors.Corner)
			self:arrow(c.Position + Vector3.new(0, 0.1, 0), c.Bisector, D.NORMAL_LENGTH * 0.6, D.Colors.Corner)
		end
	end
end

function DebugVisualizer:drawPlan(plan, analysis, settings)
	self:drawAnalysis(analysis, settings)
	if not settings.DebugEnabled then
		return
	end
	local dbg = plan.Diagnostics.Debug
	if settings.DebugBounds then
		for i, item in ipairs(plan.Items) do
			if i > MAX_BOXES then
				break
			end
			local color = if item.Group == "Architecture" then D.Colors.Architecture else D.Colors.Bounds
			self:box(item.BoxCFrame, item.BoxSize, color, D.BOX_TRANSPARENCY)
		end
	end
	if settings.DebugZones then
		for _, z in ipairs(dbg.Zones) do
			local color = if z.Kind == "CenterClear" then D.Colors.CenterClear else D.Colors.Exclusion
			self:polygon(z.Surface, z.Polygon, color, 0.12)
		end
	end
	if settings.DebugCandidates then
		for _, p in ipairs(dbg.Candidates) do
			self:point(p, D.Colors.Candidate, D.POINT_RADIUS * 0.6)
		end
	end
	if settings.DebugRejected then
		for _, p in ipairs(dbg.Rejected) do
			self:point(p, D.Colors.Rejected, D.POINT_RADIUS * 0.6)
		end
	end
	if settings.DebugSnaps then
		for _, p in ipairs(dbg.Snaps) do
			self:point(p, D.Colors.Snap, D.POINT_RADIUS * 0.8)
		end
	end
	if settings.DebugSegments then
		for _, seg in ipairs(dbg.Segments) do
			self:line(seg[1], seg[2], D.Colors.Segment, D.LINE_THICKNESS + 1)
		end
	end
end

return DebugVisualizer
