--[[
	PlacementContext
	État partagé d'une génération : plan des objets à créer, moteur de
	collision, zones d'exclusion, index de voisinage 2D par surface,
	compteurs d'usage des assets, façades construites, diagnostics.

	Tous les moteurs (sol, murs, architecture, coins, plafond) passent par
	`tryCommit` pour valider un placement : budget, collision, puis
	enregistrement. La planification est 100 % en données ; les clones ne sont
	créés qu'à la fin par OutputBuilder.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local PlacementMath = require(script.Parent.PlacementMath)

local PlacementContext = {}
PlacementContext.__index = PlacementContext

-- Index de voisinage 2D (grille) --------------------------------------------------

local NeighborIndex = {}
NeighborIndex.__index = NeighborIndex

function NeighborIndex.new(cellSize)
	return setmetatable({ CellSize = cellSize, Cells = {}, Entries = {} }, NeighborIndex)
end

local function cellKey(x, y)
	return x * 1000003 + y
end

function NeighborIndex:insert(entry)
	local s = self.CellSize
	local x0 = math.floor((entry.Pos.X - entry.Radius) / s)
	local x1 = math.floor((entry.Pos.X + entry.Radius) / s)
	local y0 = math.floor((entry.Pos.Y - entry.Radius) / s)
	local y1 = math.floor((entry.Pos.Y + entry.Radius) / s)
	for x = x0, x1 do
		for y = y0, y1 do
			local k = cellKey(x, y)
			local cell = self.Cells[k]
			if not cell then
				cell = {}
				self.Cells[k] = cell
			end
			cell[#cell + 1] = entry
		end
	end
	table.insert(self.Entries, entry)
end

-- Entrées dont le centre est à moins de `radius` (+ leur rayon) du point.
function NeighborIndex:query(pos, radius)
	local s = self.CellSize
	local out = {}
	local seen = {}
	local x0 = math.floor((pos.X - radius) / s)
	local x1 = math.floor((pos.X + radius) / s)
	local y0 = math.floor((pos.Y - radius) / s)
	local y1 = math.floor((pos.Y + radius) / s)
	if (x1 - x0 + 1) * (y1 - y0 + 1) > 4096 then
		for _, e in ipairs(self.Entries) do
			if (e.Pos - pos).Magnitude - e.Radius <= radius then
				out[#out + 1] = e
			end
		end
		return out
	end
	for x = x0, x1 do
		for y = y0, y1 do
			local cell = self.Cells[cellKey(x, y)]
			if cell then
				for _, e in ipairs(cell) do
					if not seen[e] then
						seen[e] = true
						if (e.Pos - pos).Magnitude - e.Radius <= radius then
							out[#out + 1] = e
						end
					end
				end
			end
		end
	end
	return out
end

PlacementContext.NeighborIndex = NeighborIndex

-- Contexte -------------------------------------------------------------------------

--[[
	params = {
	  Settings, Analysis, Registry, Collision, Zones, Rng, Diagnostics,
	  Yield, MaxAssets, SceneIgnoreParts
	}
]]
function PlacementContext.new(params)
	local self = setmetatable({}, PlacementContext)
	self.Settings = params.Settings
	self.Analysis = params.Analysis
	self.Registry = params.Registry
	self.Collision = params.Collision
	self.Zones = params.Zones
	self.Rng = params.Rng
	self.Diagnostics = params.Diagnostics
	self.Yield = params.Yield or function() end
	self.MaxAssets = params.MaxAssets or 600
	self.Items = {}
	self.Surfaces = {}
	self.Facades = {}
	self.AssetCounts = {}
	self.Epsilon = params.Settings.SurfaceEpsilon
	self._nextId = 0
	return self
end

function PlacementContext:remaining()
	return self.MaxAssets - #self.Items
end

function PlacementContext:surfaceState(surface)
	local state = self.Surfaces[surface]
	if not state then
		state = {
			Index = NeighborIndex.new(Config.Collision.NEIGHBOR_CELL_SIZE),
			Items = {},
			Recent = {},
			MassPositive = 0,
			MassNegative = 0,
			Clusters = {},
		}
		self.Surfaces[surface] = state
	end
	return state
end

function PlacementContext:assetCount(asset)
	return self.AssetCounts[asset] or 0
end

-- L'asset peut-il encore être utilisé (UniqueAsset / RepeatLimit) ?
function PlacementContext:assetAvailable(asset)
	local n = self:assetCount(asset)
	if asset.Meta.UniqueAsset and n >= 1 then
		return false
	end
	if asset.Meta.RepeatLimit and n >= asset.Meta.RepeatLimit then
		return false
	end
	return true
end

function PlacementContext:facadeDepth(surface)
	local f = self.Facades[surface]
	return if f then f.Depth else 0
end

--[[
	Valide et enregistre un placement.
	meta = {
	  Surface, Role, Folder, PlacementType, Group ("Decor" | "Architecture"),
	  Layer, IgnoreParts, SkipCollision, AllowArchitectureOverlap,
	  Pos2D, Radius, ClusterId, CrossCoord, Mass
	}
	Renvoie (item, nil) ou (nil, raison).
]]
function PlacementContext:tryCommit(pose, meta)
	if #self.Items >= self.MaxAssets then
		return nil, "budget"
	end
	local asset = pose.Asset
	self.Diagnostics:add("Attempts")
	local shape = {
		BoxCFrame = pose.BoxCFrame,
		BoxSize = pose.BoxSize,
		Pose = pose,
		Group = meta.Group or "Decor",
		CanOverlap = asset.Meta.CanOverlapDecoration,
		MinSpacing = if meta.Group == "Architecture" then 0 else (asset.Meta.MinSpacing or 0),
		IgnoreParts = meta.IgnoreParts,
		AllowArchitectureOverlap = meta.AllowArchitectureOverlap,
	}
	if not meta.SkipCollision then
		local hit, reason = self.Collision:test(shape)
		if hit then
			self.Diagnostics:reject(reason, pose.BoxCFrame.Position)
			return nil, reason
		end
	end
	self._nextId += 1
	local item = {
		Id = self._nextId,
		Asset = asset,
		Pose = pose,
		Scale = pose.Scale,
		Stretch = pose.Stretch,
		RefCFrame = pose.RefCFrame,
		Pivot = PlacementMath.pivotFor(asset, pose),
		BoxCFrame = pose.BoxCFrame,
		BoxSize = pose.BoxSize,
		Surface = meta.Surface,
		Role = meta.Role,
		Folder = meta.Folder or meta.Role,
		PlacementType = meta.PlacementType or meta.Role,
		Group = shape.Group,
		Layer = meta.Layer or 0,
		SizeClass = asset.SizeClass,
		ClusterId = meta.ClusterId,
		Pass = meta.Pass,
		IgnoreParts = meta.IgnoreParts,
	}
	self.Collision:addPlaced({
		BoxCFrame = pose.BoxCFrame,
		BoxSize = pose.BoxSize,
		Pose = pose,
		Group = shape.Group,
		CanOverlap = shape.CanOverlap,
		MinSpacing = shape.MinSpacing,
		Id = item.Id,
		Item = item,
		Surface = meta.Surface,
	})
	table.insert(self.Items, item)
	self.AssetCounts[asset] = (self.AssetCounts[asset] or 0) + 1
	if meta.Surface then
		local state = self:surfaceState(meta.Surface)
		table.insert(state.Items, item)
		if meta.Pos2D then
			local mass = meta.Mass or (asset.Importance or 1) * pose.Scale
			state.Index:insert({
				Pos = meta.Pos2D,
				Radius = meta.Radius or asset.FootprintRadius * pose.Scale,
				SizeClass = asset.SizeClass,
				Asset = asset,
				ClusterId = meta.ClusterId,
				Mass = mass,
				Item = item,
			})
			if meta.CrossCoord then
				if meta.CrossCoord >= 0 then
					state.MassPositive += mass
				else
					state.MassNegative += mass
				end
			end
		end
		table.insert(state.Recent, asset)
		if #state.Recent > Config.Composition.RECENT_HISTORY then
			table.remove(state.Recent, 1)
		end
	end
	self.Diagnostics:add("Placed")
	if meta.Pass then
		self.Diagnostics:pass(meta.Pass)
	end
	return item, nil
end

return PlacementContext
