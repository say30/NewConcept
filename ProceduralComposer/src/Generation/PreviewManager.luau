--[[
	PreviewManager
	Cycle de vie du résultat dans la scène : Preview -> Regenerate -> Accept /
	Cancel, et Clear Generated.

	Sans état caché : la preview est retrouvée dans la scène par son attribut
	PCP_IsPreview, ce qui reste juste après un Ctrl+Z / Ctrl+Y.
	Toutes les modifications passent par HistoryManager (annulables).
]]

local HttpService = game:GetService("HttpService")

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local OutputBuilder = require(script.Parent.OutputBuilder)
local HistoryManager = require(script.Parent.HistoryManager)

local PreviewManager = {}
PreviewManager.__index = PreviewManager

local ATTR = Config.Attr

function PreviewManager.new()
	return setmetatable({}, PreviewManager)
end

function PreviewManager:getRoot()
	return OutputBuilder.getRoot(false)
end

function PreviewManager:getPreview()
	local root = self:getRoot()
	if not root then
		return nil
	end
	for _, child in ipairs(root:GetChildren()) do
		if child:GetAttribute(ATTR.IsPreview) == true then
			return child
		end
	end
	return nil
end

function PreviewManager:hasPreview()
	return self:getPreview() ~= nil
end

function PreviewManager:getGenerations()
	local list = {}
	local root = self:getRoot()
	if root then
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("Folder") and child:GetAttribute(ATTR.GeneratedBy) == Config.Output.GENERATED_BY and child:GetAttribute(ATTR.IsPreview) ~= true then
				table.insert(list, child)
			end
		end
	end
	return list
end

local function destroyPreviewFolder(folder)
	OutputBuilder.restoreWalls(folder)
	folder:Destroy()
end

--[[
	Affiche un plan comme preview (remplace la preview existante).
	meta = { Seed, SettingsJson, AnchorClones, StripScripts, OnProgress }
	Renvoie (ok, message, created)
]]
function PreviewManager:showPlan(plan, meta)
	local regenerate = self:hasPreview()
	local mode = if regenerate and HistoryManager.lastIsPreview() then "Append" else "Commit"
	local generationId = HttpService:GenerateGUID(false)
	local created, errors = 0, {}
	local ok, err = HistoryManager.run(HistoryManager.PREVIEW, mode, function()
		local existing = self:getPreview()
		if existing then
			destroyPreviewFolder(existing)
		end
		local root = OutputBuilder.getRoot(true)
		local folder, subfolders = OutputBuilder.createGenerationFolder(Config.Output.PREVIEW_NAME, {
			GenerationId = generationId,
			Seed = meta.Seed,
			SettingsJson = meta.SettingsJson,
		})
		folder:SetAttribute(ATTR.IsPreview, true)
		created, errors = OutputBuilder.instantiate(plan.Items, subfolders, {
			Seed = meta.Seed,
			GenerationId = generationId,
			AnchorClones = meta.AnchorClones,
			StripScripts = meta.StripScripts,
			OnProgress = meta.OnProgress,
		})
		OutputBuilder.hideWalls(folder, plan.HiddenWalls or {})
		folder.Parent = root
	end)
	if not ok then
		return false, tostring(err), 0, {}
	end
	return true, nil, created, errors
end

-- Valide la preview : elle devient Generation_NNN.
function PreviewManager:accept()
	local folder = self:getPreview()
	if not folder then
		return false, "There is no preview to accept."
	end
	local mode = if HistoryManager.lastIsPreview() then "Append" else "Commit"
	local name
	local ok, err = HistoryManager.run(HistoryManager.ACCEPT, mode, function()
		local root = self:getRoot()
		local index = OutputBuilder.nextGenerationIndex(root)
		name = OutputBuilder.generationName(index)
		folder.Name = name
		folder:SetAttribute(ATTR.IsPreview, nil)
		folder:SetAttribute(ATTR.GenerationIndex, index)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, name
end

function PreviewManager:cancel()
	local folder = self:getPreview()
	if not folder then
		return false, "There is no preview to cancel."
	end
	local ok, err = HistoryManager.run(HistoryManager.CANCEL, "Commit", function()
		destroyPreviewFolder(folder)
		local root = self:getRoot()
		if root and #root:GetChildren() == 0 then
			root:Destroy()
		end
	end)
	if not ok then
		return false, tostring(err)
	end
	return true
end

-- Supprime tout le contenu généré (preview + générations), murs restaurés.
function PreviewManager:clearGenerated()
	local root = self:getRoot()
	if not root then
		return false, "Nothing has been generated."
	end
	local count = 0
	local ok, err = HistoryManager.run(HistoryManager.CLEAR, "Commit", function()
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("Folder") then
				OutputBuilder.restoreWalls(child)
				count += 1
			end
		end
		root:Destroy()
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, count
end

return PreviewManager
