--[[
	AssetSelector
	Choix des assets, pensé comme un level designer :
	  - palette par surface : on n'utilise qu'une partie cohérente de la
	    bibliothèque sur une même zone (fraction pilotée par Variation), en
	    conservant au moins un asset par classe de taille disponible ;
	  - tirage pondéré : Weight × score de rôle × fréquence de la classe de
	    taille × pénalité de répétition récente ;
	  - respect de UniqueAsset / RepeatLimit ;
	  - filtre de taille : un asset plus grand que l'espace disponible n'est
	    jamais proposé (surface minuscule, asset gigantesque).
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local Utilities = require(Core.Utilities)

local AssetSelector = {}
AssetSelector.__index = AssetSelector

local COMP = Config.Composition

function AssetSelector.new(ctx)
	local self = setmetatable({}, AssetSelector)
	self.Ctx = ctx
	self._palettes = {}
	return self
end

function AssetSelector:sizeFrequency(sizeClass)
	local s = self.Ctx.Settings
	if sizeClass == "Small" then
		return s.SmallAssetFrequency
	elseif sizeClass == "Medium" then
		return s.MediumAssetFrequency
	elseif sizeClass == "Large" then
		return s.LargeAssetFrequency
	elseif sizeClass == "Hero" then
		return s.LargeAssetFrequency * 0.8
	end
	return 1
end

--[[
	Palette d'une surface pour un rôle (mise en cache, déterministe).
	roles : un rôle ou une liste de rôles (union).
]]
function AssetSelector:palette(surface, roles, rng)
	if type(roles) == "string" then
		roles = { roles }
	end
	local cacheKey = (surface and surface.Id or "global") .. ":" .. table.concat(roles, "+")
	local cached = self._palettes[cacheKey]
	if cached then
		return cached
	end
	local registry = self.Ctx.Registry
	local seen = {}
	local all = {}
	for _, role in ipairs(roles) do
		for _, a in ipairs(registry:getByRole(role)) do
			if not seen[a] then
				seen[a] = true
				table.insert(all, a)
			end
		end
	end
	table.sort(all, function(a, b)
		return a.Order < b.Order
	end)
	local n = #all
	if n == 0 then
		self._palettes[cacheKey] = all
		return all
	end
	local variation = self.Ctx.Settings.Variation
	local fraction = Utilities.lerp(COMP.PALETTE_MIN_FRACTION, 1, variation)
	local target = math.max(math.min(COMP.PALETTE_MIN_COUNT, n), math.ceil(n * fraction))
	if target >= n then
		self._palettes[cacheKey] = all
		return all
	end
	-- Un représentant par classe de taille, puis complément pondéré.
	local chosen = {}
	local chosenSet = {}
	local function weightOf(a)
		local best = 0
		for _, role in ipairs(roles) do
			best = math.max(best, a.RoleScores[role] or 0)
		end
		return math.max(1e-3, a.Meta.Weight * best)
	end
	for _, sizeClass in ipairs(Config.Assets.SIZE_CLASS_ORDER) do
		local group, weights = {}, {}
		for _, a in ipairs(all) do
			if a.SizeClass == sizeClass then
				table.insert(group, a)
				table.insert(weights, weightOf(a))
			end
		end
		if #group > 0 and #chosen < target then
			local i = rng:weightedIndex(weights)
			if i then
				table.insert(chosen, group[i])
				chosenSet[group[i]] = true
			end
		end
	end
	while #chosen < target do
		local pool, weights = {}, {}
		for _, a in ipairs(all) do
			if not chosenSet[a] then
				table.insert(pool, a)
				table.insert(weights, weightOf(a))
			end
		end
		local i = rng:weightedIndex(weights)
		if not i then
			break
		end
		table.insert(chosen, pool[i])
		chosenSet[pool[i]] = true
	end
	table.sort(chosen, function(a, b)
		return a.Order < b.Order
	end)
	self._palettes[cacheKey] = chosen
	return chosen
end

--[[
	Tirage d'un asset dans une liste.
	opts = {
	  Role, SizeClasses = {Small = true, ...}?, Surface, Rng,
	  MaxRadius, MaxWidth, MaxHeight, MaxDepth, Filter = function(asset) -> bool,
	  IgnoreFrequency : bool, Exclude = {[asset] = true}
	}
]]
function AssetSelector:pick(list, opts)
	local ctx = self.Ctx
	local rng = opts.Rng
	local variation = ctx.Settings.Variation
	local gamma = Utilities.lerp(1.3, 0.6, variation)
	local recent = if opts.Surface then ctx:surfaceState(opts.Surface).Recent else {}
	local last = recent[#recent]
	local candidates, weights = {}, {}
	for _, a in ipairs(list) do
		local ok = ctx:assetAvailable(a)
		if ok and opts.Exclude and opts.Exclude[a] then
			ok = false
		end
		if ok and opts.SizeClasses and not opts.SizeClasses[a.SizeClass] then
			ok = false
		end
		local minScale = a.Meta.MinScale or 1
		if not a.Meta.AllowScale then
			minScale = 1
		end
		minScale = math.min(minScale, 1)
		if ok and opts.MaxRadius and a.FootprintRadius * minScale > opts.MaxRadius then
			ok = false
		end
		if ok and opts.MaxWidth and math.min(a.Size.X, a.Size.Z) * minScale > opts.MaxWidth then
			ok = false
		end
		if ok and opts.MaxHeight and a.Size.Y * minScale > opts.MaxHeight then
			ok = false
		end
		if ok and opts.Filter and not opts.Filter(a) then
			ok = false
		end
		if ok then
			local roleScore = if opts.Role then (a.RoleScores[opts.Role] or 0) else 1
			local w = (math.max(a.Meta.Weight, 1e-3) ^ gamma) * (roleScore ^ 1.5)
			if not opts.IgnoreFrequency then
				w *= self:sizeFrequency(a.SizeClass)
			end
			if a == last then
				w *= COMP.REPEAT_LAST_FACTOR
			elseif table.find(recent, a) then
				w *= COMP.REPEAT_RECENT_FACTOR
			end
			if w > 0 then
				table.insert(candidates, a)
				table.insert(weights, w)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	local i = rng:weightedIndex(weights)
	return if i then candidates[i] else nil
end

return AssetSelector
