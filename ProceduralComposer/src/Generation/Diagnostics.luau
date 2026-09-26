--[[
	Diagnostics
	Compteurs d'une génération (affichés dans le panneau Diagnostics) et
	enregistreur de données de debug visuel (points candidats, rejets, snaps,
	segmentation murale, zones...). L'enregistrement de debug n'est actif que
	si le mode Debug est activé, pour ne rien coûter sinon.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)

local Diagnostics = {}
Diagnostics.__index = Diagnostics

function Diagnostics.new(debugEnabled)
	local self = setmetatable({}, Diagnostics)
	self.Counters = {
		Surfaces = 0,
		Floors = 0,
		Walls = 0,
		Ceilings = 0,
		Corners = 0,
		Assets = 0,
		Placed = 0,
		Attempts = 0,
		Rejected = 0,
		OverlapsPrevented = 0,
		ExclusionRejected = 0,
		OutOfBounds = 0,
		SceneRejected = 0,
		TooLarge = 0,
		ModulesFitted = 0,
		GenerationTime = 0,
		PlanningTime = 0,
		InstantiationTime = 0,
	}
	self.PerPass = {}
	self.Warnings = {}
	self._warningSet = {}
	self.DebugEnabled = debugEnabled == true
	self.Debug = {
		Candidates = {},
		Rejected = {},
		Snaps = {},
		Segments = {},
		Zones = {},
		Corners = {},
		Bands = {},
	}
	return self
end

function Diagnostics:add(name, amount)
	self.Counters[name] = (self.Counters[name] or 0) + (amount or 1)
end

function Diagnostics:pass(name, amount)
	self.PerPass[name] = (self.PerPass[name] or 0) + (amount or 1)
end

function Diagnostics:warn(message)
	if not self._warningSet[message] then
		self._warningSet[message] = true
		table.insert(self.Warnings, message)
	end
end

-- Rejet d'un candidat : met à jour les compteurs par raison.
function Diagnostics:reject(reason, worldPosition)
	self.Counters.Rejected += 1
	if reason == "overlap" or reason == "protected" then
		self.Counters.OverlapsPrevented += 1
	elseif reason == "scene" then
		self.Counters.SceneRejected += 1
		self.Counters.OverlapsPrevented += 1
	elseif reason == "exclusion" then
		self.Counters.ExclusionRejected += 1
	elseif reason == "bounds" then
		self.Counters.OutOfBounds += 1
	end
	if self.DebugEnabled and worldPosition and #self.Debug.Rejected < Config.Debug.MAX_REJECTED then
		table.insert(self.Debug.Rejected, worldPosition)
	end
end

function Diagnostics:candidate(worldPosition)
	if self.DebugEnabled and #self.Debug.Candidates < Config.Debug.MAX_CANDIDATES then
		table.insert(self.Debug.Candidates, worldPosition)
	end
end

function Diagnostics:snap(worldPosition)
	if self.DebugEnabled then
		table.insert(self.Debug.Snaps, worldPosition)
	end
end

function Diagnostics:segment(a, b)
	if self.DebugEnabled then
		table.insert(self.Debug.Segments, { a, b })
	end
end

-- Zone 2D d'une surface (polygone) : convertie en points monde pour le debug.
function Diagnostics:zone(surface, polygon, kind)
	if self.DebugEnabled then
		table.insert(self.Debug.Zones, { Surface = surface, Polygon = polygon, Kind = kind })
	end
end

function Diagnostics:corner(corner)
	if self.DebugEnabled then
		table.insert(self.Debug.Corners, corner)
	end
end

function Diagnostics:summaryLines()
	local c = self.Counters
	return {
		{ "Surfaces", string.format("%d (floor %d, wall %d, ceiling %d)", c.Surfaces, c.Floors, c.Walls, c.Ceilings) },
		{ "Corners", tostring(c.Corners) },
		{ "Assets in library", tostring(c.Assets) },
		{ "Placed assets", tostring(c.Placed) },
		{ "Placement attempts", tostring(c.Attempts) },
		{ "Rejected attempts", tostring(c.Rejected) },
		{ "Overlaps prevented", tostring(c.OverlapsPrevented) },
		{ "Exclusion rejections", tostring(c.ExclusionRejected) },
		{ "Modules fitted", tostring(c.ModulesFitted) },
		{ "Generation time", string.format("%.2f s (plan %.2f s, build %.2f s)", c.GenerationTime, c.PlanningTime, c.InstantiationTime) },
	}
end

return Diagnostics
