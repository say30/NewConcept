--[[
	CollisionEngine
	Détection de collision performante entre la génération en cours, la
	géométrie cible et la géométrie protégée.

	  - Hash spatial 3D (grille uniforme) : une requête ne teste que les objets
	    des cellules touchées, jamais tous les objets de la scène.
	  - Phase large : OBB complète de l'asset (test SAT 15 axes).
	  - Phase fine (optionnelle) : sous-boîtes par part (ou grille d'occupation
	    pour les assets de centaines de parts) -> deux arbres peuvent entremêler
	    leurs feuillages sans que leurs parts se traversent.
	  - Contact exact autorisé (tolérance), espacement minimal optionnel.
	  - Géométrie de la scène : workspace:GetPartBoundsInBox + OverlapParams,
	    appelé seulement si les tests internes passent.
	  - Lancer de rayon sur la géométrie planifiée (pas encore instanciée),
	    utilisé pour poser des détails sur une façade générée.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local MathUtil = require(Core.MathUtil)
local PlacementMath = require(script.Parent.PlacementMath)

local CollisionEngine = {}
CollisionEngine.__index = CollisionEngine

local C = Config.Collision
local OFFSET = 65536
local KY = 131072
local KZ = 131072 * 131072

--[[
	opts = {
	  CellSize, Enabled, Precise, MinimumSpacing, Tolerance,
	  SceneQuery : bool, OverlapParams : OverlapParams?, World : WorldRoot?,
	}
]]
function CollisionEngine.new(opts)
	local self = setmetatable({}, CollisionEngine)
	self.CellSize = math.clamp(opts.CellSize or 8, C.MIN_CELL_SIZE, C.MAX_CELL_SIZE)
	self.Enabled = opts.Enabled ~= false
	self.Precise = opts.Precise ~= false
	self.MinimumSpacing = opts.MinimumSpacing or 0
	self.Tolerance = opts.Tolerance or Config.Precision.CONTACT_TOLERANCE
	self.SceneQuery = opts.SceneQuery == true
	self.OverlapParams = opts.OverlapParams
	self.World = opts.World
	self._cells = {}
	self._records = {}
	self._stamp = 0
	self.Stats = { Tests = 0, Overlaps = 0, SceneHits = 0, ProtectedHits = 0 }
	return self
end

function CollisionEngine:_cellRange(lo, hi)
	local s = self.CellSize
	return math.floor(lo.X / s), math.floor(lo.Y / s), math.floor(lo.Z / s),
		math.floor(hi.X / s), math.floor(hi.Y / s), math.floor(hi.Z / s)
end

local function key(x, y, z)
	return (x + OFFSET) + (y + OFFSET) * KY + (z + OFFSET) * KZ
end

function CollisionEngine:_insert(record)
	local lo, hi = MathUtil.obbAABB(record.BoxCFrame, record.BoxSize)
	record.AABBMin, record.AABBMax = lo, hi
	local x0, y0, z0, x1, y1, z1 = self:_cellRange(lo, hi)
	local count = (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1)
	if count > C.MAX_QUERY_CELLS then
		-- Objet gigantesque : stocké dans une liste globale testée à chaque requête.
		self._large = self._large or {}
		table.insert(self._large, record)
	else
		for z = z0, z1 do
			for y = y0, y1 do
				for x = x0, x1 do
					local k = key(x, y, z)
					local cell = self._cells[k]
					if not cell then
						cell = {}
						self._cells[k] = cell
					end
					cell[#cell + 1] = record
				end
			end
		end
	end
	table.insert(self._records, record)
	return record
end

-- Ajoute un objet planifié. record = { BoxCFrame, BoxSize, Pose?, Group, CanOverlap, MinSpacing, Id }
function CollisionEngine:addPlaced(record)
	record.Kind = "Placed"
	return self:_insert(record)
end

-- Ajoute une Part protégée (cible, géométrie protégée).
function CollisionEngine:addProtectedPart(part)
	return self:_insert({
		Kind = "Protected",
		Part = part,
		BoxCFrame = part.CFrame,
		BoxSize = part.Size,
	})
end

function CollisionEngine:_gather(lo, hi)
	self._stamp += 1
	local stamp = self._stamp
	local out = {}
	local x0, y0, z0, x1, y1, z1 = self:_cellRange(lo, hi)
	local count = (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1)
	if count > C.MAX_QUERY_CELLS then
		for _, r in ipairs(self._records) do
			out[#out + 1] = r
		end
		return out
	end
	for z = z0, z1 do
		for y = y0, y1 do
			for x = x0, x1 do
				local cell = self._cells[key(x, y, z)]
				if cell then
					for _, r in ipairs(cell) do
						if r._stamp ~= stamp then
							r._stamp = stamp
							out[#out + 1] = r
						end
					end
				end
			end
		end
	end
	if self._large then
		for _, r in ipairs(self._large) do
			if r._stamp ~= stamp then
				r._stamp = stamp
				out[#out + 1] = r
			end
		end
	end
	return out
end

local function aabbOverlap(aLo, aHi, bLo, bHi, margin)
	return aLo.X - margin <= bHi.X and aHi.X + margin >= bLo.X
		and aLo.Y - margin <= bHi.Y and aHi.Y + margin >= bLo.Y
		and aLo.Z - margin <= bHi.Z and aHi.Z + margin >= bLo.Z
end

function CollisionEngine:_subBoxesCollide(shapeBoxes, otherBoxes, gap)
	local tol = self.Tolerance
	for _, a in ipairs(shapeBoxes) do
		for _, b in ipairs(otherBoxes) do
			if MathUtil.obbIntersects(a.CFrame, a.Size, b.CFrame, b.Size, tol, gap) then
				return true
			end
		end
	end
	return false
end

local function boxesOf(entry)
	if entry.Pose then
		return PlacementMath.worldSubBoxes(entry.Pose)
	end
	return { { CFrame = entry.BoxCFrame, Size = entry.BoxSize } }
end

--[[
	Teste une forme candidate.
	shape = {
	  BoxCFrame, BoxSize, Pose?, Group ("Decor" | "Architecture"),
	  CanOverlap, MinSpacing, IgnoreParts = {[BasePart] = true},
	  AllowArchitectureOverlap : bool,
	}
	Renvoie (collision : bool, raison : string?, autre : record?)
]]
function CollisionEngine:test(shape)
	self.Stats.Tests += 1
	if not self.Enabled then
		return false
	end
	local tol = self.Tolerance
	local spacing = math.max(self.MinimumSpacing, shape.MinSpacing or 0)
	local lo, hi = MathUtil.obbAABB(shape.BoxCFrame, shape.BoxSize)
	shape.AABBMin, shape.AABBMax = lo, hi
	local margin = spacing + tol
	local candidates = self:_gather(lo - Vector3.new(margin, margin, margin), hi + Vector3.new(margin, margin, margin))
	local ignore = shape.IgnoreParts
	local shapeBoxes = nil
	local isDecor = shape.Group ~= "Architecture"

	for _, r in ipairs(candidates) do
		local skip = false
		local gap = 0
		if r.Kind == "Protected" then
			if ignore and ignore[r.Part] then
				skip = true
			end
		else
			local otherDecor = r.Group ~= "Architecture"
			if not isDecor and not otherDecor and shape.AllowArchitectureOverlap then
				skip = true
			elseif isDecor and otherDecor and (shape.CanOverlap or r.CanOverlap) then
				skip = true
			elseif isDecor and otherDecor then
				gap = math.max(spacing, r.MinSpacing or 0)
			end
		end
		if not skip and aabbOverlap(lo, hi, r.AABBMin, r.AABBMax, gap - tol) then
			if MathUtil.obbIntersects(shape.BoxCFrame, shape.BoxSize, r.BoxCFrame, r.BoxSize, tol, gap) then
				local collide = true
				if self.Precise then
					shapeBoxes = shapeBoxes or boxesOf(shape)
					local otherBoxes = boxesOf(r)
					if #shapeBoxes > 1 or #otherBoxes > 1 then
						collide = self:_subBoxesCollide(shapeBoxes, otherBoxes, gap)
					end
				end
				if collide then
					self.Stats.Overlaps += 1
					if r.Kind == "Protected" then
						self.Stats.ProtectedHits += 1
						return true, "protected", r
					end
					return true, "overlap", r
				end
			end
		end
	end

	if self.SceneQuery and self.World and self.OverlapParams then
		if self:sceneCollides(shape) then
			self.Stats.SceneHits += 1
			return true, "scene", nil
		end
	end
	return false
end

-- Requête sur la géométrie existante de la scène (hors cibles, hors génération courante).
function CollisionEngine:sceneCollides(shape)
	local tol = self.Tolerance
	local boxes
	if self.Precise then
		boxes = boxesOf(shape)
	else
		boxes = { { CFrame = shape.BoxCFrame, Size = shape.BoxSize } }
	end
	local ignore = shape.IgnoreParts
	for _, b in ipairs(boxes) do
		local size = b.Size - Vector3.new(tol, tol, tol) * 2
		if size.X > 0 and size.Y > 0 and size.Z > 0 then
			local ok, parts = pcall(self.World.GetPartBoundsInBox, self.World, b.CFrame, size, self.OverlapParams)
			if ok and parts then
				for _, p in ipairs(parts) do
					local relevant = true
					if ignore and ignore[p] then
						relevant = false
					elseif C.IGNORE_INVISIBLE_SCENE_PARTS and p.Transparency >= 0.999 and not p.CanCollide then
						relevant = false
					end
					if relevant then
						return true
					end
				end
			end
		end
	end
	return false
end

--[[
	Rayon contre la géométrie planifiée. filter(record) -> bool.
	Renvoie (distance, record) ou nil.
]]
function CollisionEngine:raycastPlanned(origin, direction, maxDistance, filter)
	local dir = MathUtil.safeUnit(direction, nil)
	if dir.Magnitude < 0.5 then
		return nil
	end
	local step = self.CellSize * C.RAY_STEP_FACTOR
	local best, bestRecord = math.huge, nil
	self._stamp += 1
	local stamp = self._stamp
	local t = 0
	local visited = {}
	while t <= maxDistance + step do
		local p = origin + dir * math.min(t, maxDistance)
		local s = self.CellSize
		local k = key(math.floor(p.X / s), math.floor(p.Y / s), math.floor(p.Z / s))
		if not visited[k] then
			visited[k] = true
			local cell = self._cells[k]
			if cell then
				for _, r in ipairs(cell) do
					if r._stamp ~= stamp then
						r._stamp = stamp
						if r.Kind == "Placed" and (not filter or filter(r)) then
							for _, b in ipairs(boxesOf(r)) do
								local d = MathUtil.rayOBB(origin, dir, b.CFrame, b.Size, maxDistance)
								if d and d < best then
									best, bestRecord = d, r
								end
							end
						end
					end
				end
			end
		end
		if best <= t then
			break
		end
		t += step
	end
	if self._large then
		for _, r in ipairs(self._large) do
			if r.Kind == "Placed" and (not filter or filter(r)) then
				for _, b in ipairs(boxesOf(r)) do
					local d = MathUtil.rayOBB(origin, dir, b.CFrame, b.Size, maxDistance)
					if d and d < best then
						best, bestRecord = d, r
					end
				end
			end
		end
	end
	if bestRecord then
		return best, bestRecord
	end
	return nil
end

function CollisionEngine:getRecords()
	return self._records
end

return CollisionEngine
