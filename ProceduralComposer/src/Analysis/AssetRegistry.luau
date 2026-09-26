--[[
	AssetRegistry
	Scanne récursivement une ou plusieurs bibliothèques (Folder, Model,
	sous-dossiers...), analyse chaque asset une seule fois (cache), classe les
	assets par taille (Small / Medium / Large / Hero) et par rôle, et fournit
	des requêtes rapides aux moteurs de placement.

	Règles de parcours :
	  - Folder (ou tout conteneur non-Model)  -> parcouru récursivement ;
	  - Model  -> un asset (jamais découpé), sauf une racine sélectionnée
	    qui ne contient aucune BasePart directe ni PrimaryPart : elle est alors
	    traitée comme un conteneur ;
	  - BasePart isolée -> un asset.
	L'ordre des assets est stable (chemin + index) : indispensable au déterminisme.
]]

local CollectionService = game:GetService("CollectionService")

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local Utilities = require(Core.Utilities)
local AssetAnalyzer = require(script.Parent.AssetAnalyzer)

local AssetRegistry = {}
AssetRegistry.__index = AssetRegistry

local A = Config.Assets

function AssetRegistry.new()
	local self = setmetatable({}, AssetRegistry)
	self.Assets = {}
	self.Roots = {}
	self.Categories = {}
	self.Warnings = {}
	self._cache = setmetatable({}, { __mode = "k" })
	self._byRole = {}
	return self
end

local function isIgnored(instance)
	local ok, tagged = pcall(CollectionService.HasTag, CollectionService, instance, Config.Tags.IGNORE)
	return ok and tagged
end

local function modelLooksLikeAsset(model)
	if model.PrimaryPart then
		return true
	end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			return true
		end
	end
	return false
end

-- Signature légère pour invalider le cache si l'asset source a changé.
local function signature(instance)
	local ok, pivot = pcall(function()
		return (instance :: any):GetPivot()
	end)
	local count = #instance:GetDescendants()
	local p = if ok then pivot.Position else Vector3.new()
	return string.format("%d|%.3f|%.3f|%.3f", count, p.X, p.Y, p.Z)
end

function AssetRegistry:_collect(roots)
	local entries = {}
	local usedKeys = {}

	local function addAsset(instance, root, path, category)
		if #entries >= Config.Performance.MAX_LIBRARY_ASSETS then
			return
		end
		local key = path
		local n = usedKeys[key] or 0
		usedKeys[key] = n + 1
		if n > 0 then
			key = key .. "#" .. tostring(n + 1)
		end
		table.insert(entries, { Instance = instance, Root = root, Key = key, Category = category })
	end

	local function visit(instance, root, path, category, depth)
		if isIgnored(instance) then
			return
		end
		if instance:IsA("Model") then
			if depth == 0 and not modelLooksLikeAsset(instance) then
				for _, child in ipairs(instance:GetChildren()) do
					visit(child, root, path .. "/" .. child.Name, category, depth + 1)
				end
			else
				addAsset(instance, root, path, category)
			end
		elseif instance:IsA("BasePart") then
			addAsset(instance, root, path, category)
		elseif not instance:IsA("LuaSourceContainer") and #instance:GetChildren() > 0 then
			for _, child in ipairs(instance:GetChildren()) do
				-- La catégorie par défaut est le premier sous-dossier sous la racine.
				local childCategory = category
				if depth == 0 and child:IsA("Folder") then
					childCategory = child.Name
				end
				visit(child, root, path .. "/" .. child.Name, childCategory, depth + 1)
			end
		end
	end

	for _, root in ipairs(roots) do
		if typeof(root) == "Instance" and root.Parent ~= nil then
			visit(root, root, root.Name, root.Name, 0)
		end
	end
	return entries
end

function AssetRegistry:_assignSizeClasses()
	local assets = self.Assets
	local sizes = {}
	for _, a in ipairs(assets) do
		table.insert(sizes, a.CharacteristicSize)
	end
	table.sort(sizes)
	local function percentile(p)
		if #sizes == 0 then
			return 0
		end
		local idx = math.clamp(math.floor(p * (#sizes - 1) + 0.5) + 1, 1, #sizes)
		return sizes[idx]
	end
	local usePercentile = #assets >= A.PERCENTILE_MIN_ASSETS
	local tSmall, tMedium, tLarge
	if usePercentile then
		tSmall = percentile(A.PERCENTILE_THRESHOLDS.Small)
		tMedium = percentile(A.PERCENTILE_THRESHOLDS.Medium)
		tLarge = percentile(A.PERCENTILE_THRESHOLDS.Large)
	else
		tSmall = A.ABSOLUTE_SIZE_THRESHOLDS.Small
		tMedium = A.ABSOLUTE_SIZE_THRESHOLDS.Medium
		tLarge = A.ABSOLUTE_SIZE_THRESHOLDS.Large
	end
	self.SizeThresholds = { Small = tSmall, Medium = tMedium, Large = tLarge, Percentile = usePercentile }
	for _, a in ipairs(assets) do
		if a.Meta.SizeClass then
			a.SizeClass = a.Meta.SizeClass
		else
			local c = a.CharacteristicSize
			if usePercentile then
				if c <= tSmall then
					a.SizeClass = "Small"
				elseif c <= tMedium then
					a.SizeClass = "Medium"
				elseif c < tLarge then
					a.SizeClass = "Large"
				else
					a.SizeClass = "Hero"
				end
			else
				if c < tSmall then
					a.SizeClass = "Small"
				elseif c < tMedium then
					a.SizeClass = "Medium"
				elseif c < tLarge then
					a.SizeClass = "Large"
				else
					a.SizeClass = "Hero"
				end
			end
		end
		a.Importance = a.Meta.Importance or A.SIZE_CLASS_IMPORTANCE[a.SizeClass] or A.DEFAULT_IMPORTANCE
	end
end

-- Détermine les scores de rôle finaux (métadonnées > analyse automatique > sol par défaut).
function AssetRegistry:finalizeRoles(autoClassify)
	local moduleWidths = {}
	for _, a in ipairs(self.Assets) do
		if a.AutoRoleScores.WallModule and a.AutoRoleScores.WallModule >= A.ROLE_SCORE_THRESHOLD then
			table.insert(moduleWidths, if a.WallYaw == 0 then a.Size.X else a.Size.Z)
		end
	end
	table.sort(moduleWidths)
	local medianModule = if #moduleWidths > 0 then moduleWidths[math.ceil(#moduleWidths / 2)] else 0

	for _, a in ipairs(self.Assets) do
		local scores
		if a.Meta.ExplicitRoles then
			scores = {}
			for role in pairs(a.Meta.Roles) do
				scores[role] = 1
			end
			if scores.LargeStructure and not scores.Floor then
				scores.Floor = 1
			end
		elseif autoClassify then
			scores = table.clone(a.AutoRoleScores)
			if a.SizeClass == "Hero" then
				scores.LargeStructure = 1
			end
			if (scores.WallModule or 0) >= A.ROLE_SCORE_THRESHOLD and medianModule > 0 then
				local width = if a.WallYaw == 0 then a.Size.X else a.Size.Z
				if width <= medianModule * 0.5 then
					scores.Filler = 0.8
				end
			end
		else
			scores = { Floor = 1 }
		end
		a.RoleScores = scores
	end
	self:_indexRoles()
end

function AssetRegistry:_indexRoles()
	self._byRole = {}
	for _, role in ipairs(Config.Roles) do
		local list = {}
		for _, a in ipairs(self.Assets) do
			local s = a.RoleScores[role] or 0
			if s >= A.ROLE_SCORE_THRESHOLD then
				table.insert(list, a)
			end
		end
		table.sort(list, function(x, y)
			local sx, sy = x.RoleScores[role] or 0, y.RoleScores[role] or 0
			if math.abs(sx - sy) > 1e-6 then
				return sx > sy
			end
			return x.Order < y.Order
		end)
		self._byRole[role] = list
	end
end

--[[
	Scanne les racines. `onProgress(fraction, text)` optionnel.
	Renvoie un résumé.
]]
function AssetRegistry:scan(roots, autoClassify, onProgress)
	self.Roots = roots
	self.Assets = {}
	self.Warnings = {}
	self.Categories = {}
	local entries = self:_collect(roots)
	if #entries >= Config.Performance.MAX_LIBRARY_ASSETS then
		table.insert(self.Warnings, string.format("Library truncated to %d assets.", Config.Performance.MAX_LIBRARY_ASSETS))
	end
	local yielder = Utilities.createYielder()
	local categorySet = {}
	local scriptAssets = 0
	for i, entry in ipairs(entries) do
		local cached = self._cache[entry.Instance]
		local sig = signature(entry.Instance)
		local data, reason
		if cached and cached.Signature == sig and cached.Root == entry.Root then
			data = cached.Data
		else
			data, reason = AssetAnalyzer.analyze(entry.Instance, {
				LibraryRoot = entry.Root,
				Key = entry.Key,
				Order = i,
				Category = entry.Category,
			})
			if data then
				self._cache[entry.Instance] = { Signature = sig, Root = entry.Root, Data = data }
			end
		end
		if data then
			data.Order = i
			data.Key = entry.Key
			table.insert(self.Assets, data)
			if not categorySet[data.Category] then
				categorySet[data.Category] = true
				table.insert(self.Categories, data.Category)
			end
			if data.ScriptCount > 0 then
				scriptAssets += 1
			end
		else
			table.insert(self.Warnings, string.format("Asset '%s' skipped: %s.", entry.Key, tostring(reason)))
		end
		if onProgress and i % 10 == 0 then
			onProgress(i / #entries, string.format("Analysing assets %d/%d", i, #entries))
		end
		yielder()
	end
	table.sort(self.Categories)
	if scriptAssets > 0 then
		table.insert(self.Warnings, string.format("%d asset(s) contain scripts. Enable 'Strip scripts from clones' if they should not run in generated copies.", scriptAssets))
	end
	if #self.Assets == 0 then
		table.insert(self.Warnings, "The library contains no usable asset (a usable asset must contain at least one BasePart).")
	end
	self:_assignSizeClasses()
	self:finalizeRoles(autoClassify)
	return self:summary()
end

-- Retire les assets dont la source a été supprimée depuis le scan.
function AssetRegistry:validate()
	local alive = {}
	local removed = 0
	for _, a in ipairs(self.Assets) do
		if Utilities.isAlive(a.Instance) then
			table.insert(alive, a)
		else
			removed += 1
		end
	end
	if removed > 0 then
		self.Assets = alive
		self:_indexRoles()
	end
	return removed
end

function AssetRegistry:getByRole(role)
	return self._byRole[role] or {}
end

function AssetRegistry:count()
	return #self.Assets
end

function AssetRegistry:summary()
	local roleCounts = {}
	for _, role in ipairs(Config.Roles) do
		roleCounts[role] = #(self._byRole[role] or {})
	end
	local sizeCounts = { Small = 0, Medium = 0, Large = 0, Hero = 0 }
	for _, a in ipairs(self.Assets) do
		sizeCounts[a.SizeClass] = (sizeCounts[a.SizeClass] or 0) + 1
	end
	return {
		Count = #self.Assets,
		Categories = self.Categories,
		RoleCounts = roleCounts,
		SizeCounts = sizeCounts,
		Warnings = self.Warnings,
	}
end

return AssetRegistry
