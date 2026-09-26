--[[
	SelectionAnalyzer
	Transforme la Selection de Studio en listes exploitables :
	  - cibles (BaseParts à analyser : Part, Model, Folder, combinaisons...)
	  - racines de bibliothèque d'assets
	  - zones d'exclusion / géométrie protégée
	Ne modifie jamais rien.
]]

local CollectionService = game:GetService("CollectionService")

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)

local SelectionAnalyzer = {}

local function isGeneratedContent(instance)
	local root = workspace:FindFirstChild(Config.Output.ROOT_NAME)
	return root ~= nil and (instance == root or instance:IsDescendantOf(root))
end

local function hasIgnoreTag(instance)
	for _, tag in ipairs({ Config.Tags.IGNORE, Config.Tags.EXCLUDE }) do
		local ok, tagged = pcall(CollectionService.HasTag, CollectionService, instance, tag)
		if ok and tagged then
			return true
		end
	end
	return false
end

function SelectionAnalyzer.getSelection()
	local ok, selection = pcall(function()
		return game:GetService("Selection"):Get()
	end)
	if ok then
		return selection
	end
	return {}
end

-- Collecte les BaseParts de plusieurs racines, sans doublon, ordre de parcours stable.
function SelectionAnalyzer.collectParts(roots, excludeRoots)
	local parts = {}
	local seen = {}
	excludeRoots = excludeRoots or {}

	local function excluded(instance)
		for _, ex in ipairs(excludeRoots) do
			if instance == ex or instance:IsDescendantOf(ex) then
				return true
			end
		end
		return false
	end

	local function consider(instance)
		if seen[instance] then
			return
		end
		if not instance:IsA("BasePart") or instance:IsA("Terrain") then
			return
		end
		if excluded(instance) or isGeneratedContent(instance) or hasIgnoreTag(instance) then
			return
		end
		seen[instance] = true
		table.insert(parts, instance)
	end

	for _, root in ipairs(roots) do
		if typeof(root) == "Instance" and root.Parent ~= nil then
			consider(root)
			for _, d in ipairs(root:GetDescendants()) do
				consider(d)
			end
		end
	end
	return parts
end

-- Cibles : toutes les BaseParts sous la sélection.
function SelectionAnalyzer.resolveTargets(selection, excludeRoots)
	local warnings = {}
	if #selection == 0 then
		return {}, { "Nothing is selected. Select a Part, Model or Folder that forms the zone to decorate." }
	end
	local parts = SelectionAnalyzer.collectParts(selection, excludeRoots)
	if #parts == 0 then
		table.insert(warnings, "The selection contains no BasePart (generated content and ignored parts are skipped).")
	end
	if #parts > Config.Performance.MAX_SURFACES then
		table.insert(warnings, string.format("Selection has %d parts; only the first %d are analysed.", #parts, Config.Performance.MAX_SURFACES))
		local trimmed = {}
		for i = 1, Config.Performance.MAX_SURFACES do
			trimmed[i] = parts[i]
		end
		parts = trimmed
	end
	return parts, warnings
end

-- Bibliothèque : on garde les racines telles quelles (Folder, Model, Part...).
-- Si un élément est déjà descendant d'une autre racine sélectionnée, il est ignoré.
function SelectionAnalyzer.resolveLibraryRoots(selection)
	local warnings = {}
	local roots = {}
	for _, instance in ipairs(selection) do
		if typeof(instance) == "Instance" and instance.Parent ~= nil and not isGeneratedContent(instance) then
			local nested = false
			for _, other in ipairs(selection) do
				if other ~= instance and instance:IsDescendantOf(other) then
					nested = true
					break
				end
			end
			if not nested then
				table.insert(roots, instance)
			end
		end
	end
	if #roots == 0 then
		table.insert(warnings, "Select one or more Folders / Models containing your assets.")
	end
	return roots, warnings
end

-- Zones d'exclusion et géométrie protégée : BaseParts sous la sélection.
function SelectionAnalyzer.resolveZoneParts(selection)
	return SelectionAnalyzer.collectParts(selection, nil)
end

-- Parts taguées dans la scène (ProceduralPlacementExclude / Protected).
function SelectionAnalyzer.getTaggedParts(tag)
	local parts = {}
	local ok, tagged = pcall(CollectionService.GetTagged, CollectionService, tag)
	if not ok then
		return parts
	end
	for _, instance in ipairs(tagged) do
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		elseif instance:IsA("Model") or instance:IsA("Folder") then
			for _, d in ipairs(instance:GetDescendants()) do
				if d:IsA("BasePart") then
					table.insert(parts, d)
				end
			end
		end
	end
	return parts
end

return SelectionAnalyzer
